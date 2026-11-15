import 'micro_etude_validation.dart';

/// MusicXML score-partwise doğrulayıcısı (el yazısı küçük XML ayrıştırıcıyla;
/// pubspec'e bağımlılık eklenmez).
///
/// Denetler: iyi biçimli XML (eşleşen etiketler, tırnaklı öznitelikler, tek
/// kök, varlık çözümü), kök `score-partwise`, `version`, part-list ↔ part
/// eşleşmesi, `divisions`/`time` varlığı, her ölçüde süre toplamı = zaman
/// imzası, geçerli step/alter/octave/duration/type. Süre: ölçü uzunlukları ve
/// `sound tempo` (çeyrek başına bpm; yoksa 120) ile; tempo değişimi ölçü
/// başında beklenir, ölçü sonundaki tempo ile hesaplanır.
ValidationReport validateMusicXml(String xml) {
  final issues = <ValidationIssue>[];
  void err(String code, String message) =>
      issues.add(ValidationIssue(code, message));

  final _XmlNode root;
  try {
    root = _XmlParser(xml).parseDocument();
  } on _XmlError catch (e) {
    err(e.code, e.message);
    return ValidationReport(issues: issues);
  }
  if (root.name != 'score-partwise') {
    err('musicxml.root', 'Root must be score-partwise: ${root.name}');
    return ValidationReport(issues: issues);
  }
  const knownVersions = {'3.0', '3.1', '4.0'};
  final version = root.attrs['version'];
  if (version == null) {
    err('musicxml.version_missing', 'version attribute missing');
  } else if (!knownVersions.contains(version)) {
    err('musicxml.version', 'Bilinmeyen sürüm: $version');
  }

  final partList = root.firstChild('part-list');
  final scoreIds = <String>[];
  if (partList == null) {
    err('musicxml.part_list_missing', 'part-list missing');
  } else {
    for (final sp in partList.childrenNamed('score-part')) {
      final id = sp.attrs['id'];
      if (id == null || id.isEmpty) {
        err('musicxml.score_part_id', 'score-part id missing');
      } else if (scoreIds.contains(id)) {
        err('musicxml.score_part_duplicate', 'Yinelenen score-part: $id');
      } else {
        scoreIds.add(id);
      }
    }
    if (scoreIds.isEmpty) err('musicxml.part_list_empty', 'no score-part');
  }
  final parts = root.childrenNamed('part').toList();
  final partIds = <String>[];
  for (final p in parts) {
    final id = p.attrs['id'];
    if (id == null || !scoreIds.contains(id)) {
      err('musicxml.part_unlisted', 'part-list\'te olmayan part: $id');
    } else if (partIds.contains(id)) {
      err('musicxml.part_duplicate', 'Yinelenen part: $id');
    } else {
      partIds.add(id);
    }
  }
  for (final id in scoreIds) {
    if (!partIds.contains(id)) {
      err('musicxml.part_missing', 'no part for score-part $id');
    }
  }

  var noteCount = 0;
  int? minNote, maxNote;
  double? duration;
  for (final part in parts) {
    int? divisions, beats, beatType;
    var tempo = 120.0;
    var seconds = 0.0;
    final numbers = <String>{};
    final measures = part.childrenNamed('measure').toList();
    if (measures.isEmpty) {
      err('musicxml.no_measures', 'part ${part.attrs['id']} has no measures');
    }
    for (final m in measures) {
      final number = m.attrs['number'];
      if (number == null || number.isEmpty) {
        err('musicxml.measure_number', 'Measure number missing');
      } else if (!numbers.add(number)) {
        err('musicxml.measure_duplicate', 'Duplicate measure: $number');
      }
      var cursor = 0;
      var maxCursor = 0;
      for (final c in m.children) {
        switch (c.name) {
          case 'attributes':
            final d = c.firstChild('divisions');
            if (d != null) {
              final v = int.tryParse(d.text.trim());
              if (v == null || v <= 0) {
                err(
                  'musicxml.divisions',
                  'divisions must be a positive integer',
                );
              } else {
                divisions = v;
              }
            }
            final t = c.firstChild('time');
            if (t != null) {
              final b = int.tryParse(t.firstChild('beats')?.text.trim() ?? '');
              final bt = int.tryParse(
                t.firstChild('beat-type')?.text.trim() ?? '',
              );
              if (b == null || bt == null || b <= 0 || bt <= 0) {
                err('musicxml.time', 'time beats/beat-type invalid');
              } else {
                beats = b;
                beatType = bt;
              }
            }
          case 'direction':
            final s = c.firstChild('sound');
            if (s != null) tempo = _tempoOf(s, tempo, err);
          case 'sound':
            tempo = _tempoOf(c, tempo, err);
          case 'backup' || 'forward':
            final v = int.tryParse(c.firstChild('duration')?.text.trim() ?? '');
            if (v == null || v <= 0) {
              err('musicxml.duration', '${c.name} duration invalid');
            } else {
              cursor += c.name == 'backup' ? -v : v;
              if (cursor < 0) {
                err(
                  'musicxml.cursor_negative',
                  'backup went past measure start',
                );
                cursor = 0;
              }
              if (cursor > maxCursor) maxCursor = cursor;
            }
          case 'note':
            final isChord = c.firstChild('chord') != null;
            final isGrace = c.firstChild('grace') != null;
            final isRest = c.firstChild('rest') != null;
            final pitch = c.firstChild('pitch');
            if (!isRest && pitch == null && c.firstChild('unpitched') == null) {
              err('musicxml.note_kind', 'Note has no pitch/rest/unpitched');
            }
            if (pitch != null) {
              final midi = _midiOf(pitch, err);
              if (midi != null) {
                noteCount++;
                minNote = minNote == null || midi < minNote ? midi : minNote;
                maxNote = maxNote == null || midi > maxNote ? midi : maxNote;
              }
            }
            final type = c.firstChild('type')?.text.trim();
            if (type != null && !_noteTypes.contains(type)) {
              err('musicxml.note_type', 'Bilinmeyen nota türü: $type');
            }
            final durNode = c.firstChild('duration');
            if (isGrace) break;
            final dur = int.tryParse(durNode?.text.trim() ?? '');
            if (dur == null || dur <= 0) {
              err(
                'musicxml.duration',
                'Note duration must be a positive integer',
              );
            } else if (!isChord) {
              cursor += dur;
              if (cursor > maxCursor) maxCursor = cursor;
            }
        }
      }
      if (divisions == null || beats == null || beatType == null) {
        err(
          'musicxml.attributes_missing',
          'Measure ${m.attrs['number']}: used before divisions/time defined',
        );
        continue;
      }
      final expectedTimes = divisions * 4 * beats;
      if (expectedTimes % beatType != 0) {
        err(
          'musicxml.measure_unfittable',
          'divisions does not fit the time signature',
        );
        continue;
      }
      final expected = expectedTimes ~/ beatType;
      if (maxCursor != expected) {
        err(
          'musicxml.measure_duration',
          'Measure ${m.attrs['number']}: duration sum $maxCursor, expected $expected',
        );
      }
      seconds += expected / divisions * 60 / tempo;
    }
    if (duration == null || seconds > duration) duration = seconds;
  }
  return ValidationReport(
    issues: issues,
    durationSeconds: issues.isEmpty ? duration : null,
    noteCount: noteCount,
    minNote: minNote,
    maxNote: maxNote,
  );
}

const _noteTypes = {
  '1024th', '512th', '256th', '128th', '64th', '32nd', '16th', 'eighth',
  'quarter', 'half', 'whole', 'breve', 'long', 'maxima', //
};

const _stepSemitone = {'C': 0, 'D': 2, 'E': 4, 'F': 5, 'G': 7, 'A': 9, 'B': 11};

double _tempoOf(_XmlNode sound, double current, _ErrFn err) {
  final raw = sound.attrs['tempo'];
  if (raw == null) return current;
  final v = double.tryParse(raw);
  if (v == null || v <= 0) {
    err('musicxml.tempo', 'sound tempo must be a positive number: $raw');
    return current;
  }
  return v;
}

int? _midiOf(_XmlNode pitch, _ErrFn err) {
  final step = pitch.firstChild('step')?.text.trim();
  final semitone = _stepSemitone[step];
  if (semitone == null) {
    err('musicxml.step', 'Invalid step: $step');
    return null;
  }
  var alter = 0;
  final alterNode = pitch.firstChild('alter');
  if (alterNode != null) {
    final a = int.tryParse(alterNode.text.trim());
    if (a == null || a < -2 || a > 2) {
      err('musicxml.alter', 'Invalid alter: ${alterNode.text.trim()}');
      return null;
    }
    alter = a;
  }
  final octave = int.tryParse(pitch.firstChild('octave')?.text.trim() ?? '');
  if (octave == null || octave < 0 || octave > 9) {
    err(
      'musicxml.octave',
      'Invalid octave: ${pitch.firstChild('octave')?.text}',
    );
    return null;
  }
  final midi = 12 * (octave + 1) + semitone + alter;
  if (midi < 0 || midi > 127) {
    err('musicxml.pitch_range', 'Outside MIDI range: $midi');
    return null;
  }
  return midi;
}

typedef _ErrFn = void Function(String code, String message);

// ---------------------------------------------------------------------------
// Küçük XML ayrıştırıcı
// ---------------------------------------------------------------------------

final class _XmlError implements Exception {
  _XmlError(this.code, this.message);
  final String code, message;
}

final class _XmlNode {
  _XmlNode(this.name, this.attrs);

  final String name;
  final Map<String, String> attrs;
  final List<_XmlNode> children = [];
  final StringBuffer _text = StringBuffer();

  String get text => _text.toString();

  _XmlNode? firstChild(String n) {
    for (final c in children) {
      if (c.name == n) return c;
    }
    return null;
  }

  Iterable<_XmlNode> childrenNamed(String n) =>
      children.where((c) => c.name == n);
}

final class _XmlParser {
  _XmlParser(this.s);

  final String s;
  var i = 0;

  _XmlError _fail(String code, String message) =>
      _XmlError(code, '$message (konum $i)');

  bool _at(String t) => s.startsWith(t, i);

  void _skipWs() {
    while (i < s.length && _isWs(s.codeUnitAt(i))) {
      i++;
    }
  }

  static bool _isWs(int c) => c == 0x20 || c == 0x09 || c == 0x0A || c == 0x0D;

  /// Prolog/sonrası: boşluk, `<?…?>`, `<!--…-->`; prologda ayrıca DOCTYPE.
  void _skipMisc({required bool allowDoctype}) {
    while (true) {
      _skipWs();
      if (_at('<?')) {
        final end = s.indexOf('?>', i + 2);
        if (end < 0) throw _fail('xml.unterminated_pi', 'Kapanmayan <?');
        i = end + 2;
      } else if (_at('<!--')) {
        _skipComment();
      } else if (allowDoctype && _at('<!DOCTYPE')) {
        var depth = 0;
        i += 9;
        while (i < s.length) {
          final c = s[i];
          if (c == '[') depth++;
          if (c == ']') depth--;
          if (c == '>' && depth <= 0) break;
          i++;
        }
        if (i >= s.length) {
          throw _fail('xml.unterminated_doctype', 'DOCTYPE açık');
        }
        i++;
      } else {
        return;
      }
    }
  }

  void _skipComment() {
    final end = s.indexOf('-->', i + 4);
    if (end < 0) throw _fail('xml.unterminated_comment', 'Kapanmayan yorum');
    i = end + 3;
  }

  _XmlNode parseDocument() {
    if (s.isNotEmpty && s.codeUnitAt(0) == 0xFEFF) i = 1;
    _skipMisc(allowDoctype: true);
    if (i >= s.length || s[i] != '<') {
      throw _fail('xml.no_root', 'Kök öğe yok');
    }
    final root = _parseElement(0);
    _skipMisc(allowDoctype: false);
    if (i < s.length) {
      throw _fail('xml.trailing_content', 'Kök öğeden sonra içerik var');
    }
    return root;
  }

  String _parseName() {
    final start = i;
    while (i < s.length && _isNameChar(s.codeUnitAt(i), i == start)) {
      i++;
    }
    if (i == start) throw _fail('xml.bad_name', 'Ad bekleniyordu');
    return s.substring(start, i);
  }

  static bool _isNameChar(int c, bool first) {
    final letter =
        (c >= 0x41 && c <= 0x5A) ||
        (c >= 0x61 && c <= 0x7A) ||
        c == 0x5F ||
        c == 0x3A ||
        c > 0x7F;
    if (letter) return true;
    return !first && ((c >= 0x30 && c <= 0x39) || c == 0x2D || c == 0x2E);
  }

  _XmlNode _parseElement(int depth) {
    if (depth > 200) throw _fail('xml.too_deep', 'Çok derin iç içelik');
    i++; // '<'
    final name = _parseName();
    final attrs = <String, String>{};
    while (true) {
      _skipWs();
      if (i >= s.length) {
        throw _fail('xml.unterminated_tag', '<$name açık kaldı');
      }
      if (s[i] == '>' || _at('/>')) break;
      final before = i;
      final an = _parseName();
      if (i == before) {
        throw _fail('xml.bad_attribute', 'Öznitelik bekleniyordu');
      }
      _skipWs();
      if (i >= s.length || s[i] != '=') {
        throw _fail('xml.bad_attribute', '$an için "=" yok');
      }
      i++;
      _skipWs();
      if (i >= s.length || (s[i] != '"' && s[i] != "'")) {
        throw _fail('xml.unquoted_attribute', '$an değeri tırnaksız');
      }
      final quote = s[i++];
      final end = s.indexOf(quote, i);
      if (end < 0) throw _fail('xml.unterminated_attribute', '$an değeri açık');
      final raw = s.substring(i, end);
      if (raw.contains('<')) {
        throw _fail('xml.bad_attribute', '$an değerinde "<" var');
      }
      if (attrs.containsKey(an)) {
        throw _fail('xml.duplicate_attribute', 'Yinelenen öznitelik: $an');
      }
      attrs[an] = _decode(raw);
      i = end + 1;
    }
    final node = _XmlNode(name, attrs);
    if (_at('/>')) {
      i += 2;
      return node;
    }
    i++; // '>'
    while (true) {
      if (i >= s.length) {
        throw _fail('xml.unterminated_element', '<$name kapanmadı');
      }
      if (_at('</')) {
        i += 2;
        final close = _parseName();
        _skipWs();
        if (i >= s.length || s[i] != '>') {
          throw _fail('xml.bad_close', '</$close > eksik');
        }
        i++;
        if (close != name) {
          throw _fail('xml.mismatched_tag', '<$name> için </$close> geldi');
        }
        return node;
      }
      if (_at('<!--')) {
        _skipComment();
      } else if (_at('<![CDATA[')) {
        final end = s.indexOf(']]>', i + 9);
        if (end < 0) throw _fail('xml.unterminated_cdata', 'Kapanmayan CDATA');
        node._text.write(s.substring(i + 9, end));
        i = end + 3;
      } else if (_at('<?')) {
        final end = s.indexOf('?>', i + 2);
        if (end < 0) throw _fail('xml.unterminated_pi', 'Kapanmayan <?');
        i = end + 2;
      } else if (s[i] == '<') {
        node.children.add(_parseElement(depth + 1));
      } else {
        final end = s.indexOf('<', i);
        final stop = end < 0 ? s.length : end;
        node._text.write(_decode(s.substring(i, stop)));
        i = stop;
      }
    }
  }

  String _decode(String raw) {
    if (!raw.contains('&')) return raw;
    final out = StringBuffer();
    var k = 0;
    while (k < raw.length) {
      final c = raw[k];
      if (c != '&') {
        out.write(c);
        k++;
        continue;
      }
      final semi = raw.indexOf(';', k);
      if (semi < 0) throw _fail('xml.bad_entity', '"&" ; ile kapanmıyor');
      final ent = raw.substring(k + 1, semi);
      switch (ent) {
        case 'amp':
          out.write('&');
        case 'lt':
          out.write('<');
        case 'gt':
          out.write('>');
        case 'quot':
          out.write('"');
        case 'apos':
          out.write("'");
        default:
          int? code;
          if (ent.startsWith('#x')) {
            code = int.tryParse(ent.substring(2), radix: 16);
          } else if (ent.startsWith('#')) {
            code = int.tryParse(ent.substring(1));
          }
          if (code == null || code <= 0 || code > 0x10FFFF) {
            throw _fail('xml.bad_entity', 'Bilinmeyen varlık: &$ent;');
          }
          out.writeCharCode(code);
      }
      k = semi + 1;
    }
    return out.toString();
  }
}
