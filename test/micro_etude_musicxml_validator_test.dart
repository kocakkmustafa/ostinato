import 'package:flutter_test/flutter_test.dart';
import 'package:ostinato/app/practice/micro_etude/micro_etude_validation.dart';
import 'package:ostinato/app/practice/micro_etude/musicxml_validator.dart';

String doc({
  String version = '4.0',
  String partList =
      '<part-list><score-part id="P1"><part-name>G</part-name></score-part></part-list>',
  String? measures,
  String partId = 'P1',
}) {
  final m =
      measures ??
      measure(1, [
        note('C', 4, 2),
        note('D', 4, 2),
        note('E', 4, 2),
        note('F', 4, 2),
      ], attrs: true);
  return '<?xml version="1.0" encoding="UTF-8"?>\n'
      '<!DOCTYPE score-partwise PUBLIC "-//Recordare//DTD MusicXML 4.0 Partwise//EN" "http://www.musicxml.org/dtds/partwise.dtd">\n'
      '<!-- yorum -->\n'
      '<score-partwise version="$version">$partList<part id="$partId">$m</part></score-partwise>';
}

String note(
  String step,
  int octave,
  int dur, {
  String extra = '',
  String type = 'quarter',
}) =>
    '<note><pitch><step>$step</step>$extra<octave>$octave</octave></pitch><duration>$dur</duration><type>$type</type></note>';

String measure(
  int n,
  List<String> notes, {
  bool attrs = false,
  String tempo = '',
}) =>
    '<measure number="$n">'
    '${attrs ? '<attributes><divisions>2</divisions><time><beats>4</beats><beat-type>4</beat-type></time></attributes>' : ''}'
    '$tempo${notes.join()}</measure>';

void main() {
  group('validateMusicXml pozitif', () {
    test('geçerli 4/4 ölçü; süre tempo ile', () {
      final r = validateMusicXml(
        doc(
          measures: measure(
            1,
            [
              note('C', 4, 2),
              note('D', 4, 2),
              note('E', 4, 2),
              note('F', 4, 2),
            ],
            attrs: true,
            tempo:
                '<direction><direction-type><words>x</words></direction-type><sound tempo="60"/></direction>',
          ),
        ),
      );
      expect(r.isValid, isTrue, reason: '$r');
      expect(r.noteCount, 4);
      expect(r.durationSeconds, closeTo(4.0, 1e-9));
      expect(r.minNote, 60);
      expect(r.maxNote, 65);
    });

    test('alter, dinlenme, akor, varlıklar ve CDATA', () {
      final m = measure(1, [
        note('F', 3, 4, extra: '<alter>1</alter>', type: 'half'),
        '<note><chord/><pitch><step>A</step><octave>3</octave></pitch><duration>4</duration></note>',
        '<note><rest/><duration>4</duration><type>half</type></note>',
      ], attrs: true).replaceFirst('<beats>', '<!-- c --><beats>');
      final r = validateMusicXml(
        doc(
          measures: m,
          partList:
              '<part-list><score-part id="P1"><part-name><![CDATA[G & <C>]]></part-name></score-part></part-list>',
        ).replaceFirst('<!-- yorum -->', '<?pi x?>'),
      );
      expect(r.isValid, isTrue, reason: '$r');
      expect(r.noteCount, 2);
      expect(r.minNote, 54);
    });
  });

  group('validateMusicXml negatif (gerçekten reddeder)', () {
    String code(String xml) {
      final r = validateMusicXml(xml);
      expect(r.isValid, isFalse);
      return r.issues.first.code;
    }

    test('ölçü toplamı tutmaz (eksik)', () {
      expect(
        code(
          doc(
            measures: measure(1, [
              note('C', 4, 2),
              note('D', 4, 2),
              note('E', 4, 2),
            ], attrs: true),
          ),
        ),
        'musicxml.measure_duration',
      );
    });

    test('ölçü toplamı tutmaz (fazla; ikinci ölçüde)', () {
      final m =
          measure(1, [note('C', 4, 8, type: 'whole')], attrs: true) +
          measure(2, [note('C', 4, 8, type: 'whole'), note('D', 4, 2)]);
      final r = validateMusicXml(doc(measures: m));
      expect(r.hasCode('musicxml.measure_duration'), isTrue);
      expect(r.issues.single.message, contains('Measure 2'));
    });

    test('bilinmeyen step', () {
      expect(
        code(
          doc(
            measures: measure(1, [note('H', 4, 8, type: 'whole')], attrs: true),
          ),
        ),
        'musicxml.step',
      );
    });

    test('octave aralık dışı', () {
      expect(
        code(
          doc(
            measures: measure(1, [
              note('C', 12, 8, type: 'whole'),
            ], attrs: true),
          ),
        ),
        'musicxml.octave',
      );
    });

    test('alter aralık dışı', () {
      expect(
        code(
          doc(
            measures: measure(1, [
              note('C', 4, 8, extra: '<alter>5</alter>', type: 'whole'),
            ], attrs: true),
          ),
        ),
        'musicxml.alter',
      );
    });

    test('duration sıfır / sayı değil', () {
      expect(
        code(
          doc(
            measures: measure(1, [note('C', 4, 0, type: 'whole')], attrs: true),
          ),
        ),
        'musicxml.duration',
      );
      expect(
        code(
          doc(
            measures: measure(1, [
              note('C', 4, 8, type: 'whole').replaceFirst('>8<', '>x<'),
            ], attrs: true),
          ),
        ),
        'musicxml.duration',
      );
    });

    test('bilinmeyen nota türü', () {
      expect(
        code(
          doc(
            measures: measure(1, [note('C', 4, 8, type: 'zork')], attrs: true),
          ),
        ),
        'musicxml.note_type',
      );
    });

    test('divisions/time tanımsız', () {
      expect(
        code(doc(measures: measure(1, [note('C', 4, 8)]))),
        'musicxml.attributes_missing',
      );
    });

    test('kök score-partwise değil', () {
      expect(code('<score-timewise version="4.0"/>'), 'musicxml.root');
    });

    test('version yok / bilinmeyen', () {
      expect(
        code(doc().replaceFirst(' version="4.0"', '')),
        'musicxml.version_missing',
      );
      expect(code(doc(version: '9.9')), 'musicxml.version');
    });

    test('part-list ile part eşleşmiyor', () {
      expect(code(doc(partId: 'P2')), 'musicxml.part_unlisted');
      final r = validateMusicXml(doc(partId: 'P2'));
      expect(r.hasCode('musicxml.part_missing'), isTrue);
    });

    test('part-list yok', () {
      expect(code(doc(partList: '')), 'musicxml.part_list_missing');
    });

    test('iyi biçimli değil: eşleşmeyen etiket', () {
      expect(
        code(doc().replaceFirst('</step>', '</stp>')),
        'xml.mismatched_tag',
      );
    });

    test('iyi biçimli değil: kapanmayan öğe / kesik belge', () {
      final d = doc();
      expect(code(d.substring(0, d.length - 20)), startsWith('xml.'));
    });

    test(
      'iyi biçimli değil: tırnaksız öznitelik, bilinmeyen varlık, ikinci kök',
      () {
        expect(
          code(doc().replaceFirst('number="1"', 'number=1')),
          'xml.unquoted_attribute',
        );
        expect(
          code(doc().replaceFirst('<part-name>G', '<part-name>&bogus;')),
          'xml.bad_entity',
        );
        expect(code('${doc()}<extra/>'), 'xml.trailing_content');
        expect(
          code(doc().replaceFirst('number="1"', 'number="1" number="2"')),
          'xml.duplicate_attribute',
        );
      },
    );

    test('boş girdi', () {
      expect(code(''), 'xml.no_root');
    });
  });

  group('validateMusicXml güvenlik ve sınır dalları', () {
    ValidationReport v(String x) => validateMusicXml(x);

    test('çok derin iç içelik reddedilir (xml.too_deep)', () {
      final deep = '${'<a>' * 250}${'</a>' * 250}';
      expect(v(deep).hasCode('xml.too_deep'), isTrue);
      final shallow = '${'<a>' * 150}${'</a>' * 150}';
      expect(v(shallow).hasCode('xml.too_deep'), isFalse);
    });

    test('DOCTYPE iç alt kümesi okunur ama varlık tanımı işlenmez', () {
      final d = doc().replaceFirst(
        RegExp(r'<!DOCTYPE[^>]*>'),
        '<!DOCTYPE score-partwise [ <!ENTITY a "xx"> <!ELEMENT x ANY> ]>',
      );
      expect(v(d).isValid, isTrue, reason: '${v(d)}');
    });

    test('tanımlı özel varlık kullanımı reddedilir (XXE)', () {
      final d = doc()
          .replaceFirst(
            RegExp(r'<!DOCTYPE[^>]*>'),
            '<!DOCTYPE score-partwise [ <!ENTITY a "xx"> ]>',
          )
          .replaceFirst('<part-name>G', '<part-name>&a;');
      expect(v(d).issues.first.code, 'xml.bad_entity');
    });

    test('dış varlık (SYSTEM) reddedilir', () {
      final d = doc()
          .replaceFirst(
            RegExp(r'<!DOCTYPE[^>]*>'),
            '<!DOCTYPE score-partwise [ <!ENTITY x SYSTEM "file:///etc/hosts"> ]>',
          )
          .replaceFirst('<part-name>G', '<part-name>&x;');
      expect(v(d).issues.first.code, 'xml.bad_entity');
    });

    test('billion-laughs: iç içe varlık genişlemesi yapılmaz', () {
      const defs =
          '<!ENTITY l0 "ha"><!ENTITY l1 "&l0;&l0;&l0;&l0;"><!ENTITY l2 "&l1;&l1;&l1;&l1;">';
      final d = doc()
          .replaceFirst(
            RegExp(r'<!DOCTYPE[^>]*>'),
            '<!DOCTYPE score-partwise [ $defs ]>',
          )
          .replaceFirst('<part-name>G', '<part-name>&l2;');
      expect(v(d).issues.first.code, 'xml.bad_entity');
    });

    test('kapanmayan DOCTYPE', () {
      final d = doc().replaceFirst(
        RegExp(r'<!DOCTYPE[^>]*>'),
        '<!DOCTYPE score-partwise [ <!ENTITY a "x">',
      );
      expect(v(d).issues.first.code, 'xml.unterminated_doctype');
    });

    test(
      'geçersiz karakter başvurusu: &#0;, aşırı kod noktası, sayısal olmayan',
      () {
        for (final ref in [
          '&#0;',
          '&#x110000;',
          '&#99999999999;',
          '&#xZZ;',
          '&#;',
        ]) {
          final d = doc().replaceFirst('<part-name>G', '<part-name>$ref');
          expect(v(d).issues.first.code, 'xml.bad_entity', reason: ref);
        }
        final ok = doc().replaceFirst('<part-name>G', '<part-name>&#65;&#x42;');
        expect(v(ok).isValid, isTrue);
      },
    );

    test('girdi boyutu sınırı (xml.too_large)', () {
      final big = doc().replaceFirst(
        '<part-name>G',
        '<part-name>${'x' * (2 * 1024 * 1024)}',
      );
      expect(v(big).issues.first.code, 'xml.too_large');
    });
  });
}
