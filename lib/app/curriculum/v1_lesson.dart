import '../guitar_journey.dart' show GuitarText;

/// One v1 lesson body (contract: docs/v1-curriculum/00-ders-format-sozlesmesi.md
/// §2). Source files live in `content/v1/<course>/<id>.json` and are not
/// bundled yet; `tool/curriculum_lint.py --check` ties each file to its plan
/// row.
///
/// Parsing is strict: unknown or missing keys throw, so a typo in one of the
/// ~690 files fails a test instead of silently dropping copy.
final class V1Lesson {
  V1Lesson._({
    required this.id,
    required this.course,
    required this.level,
    required this.title,
    required this.goal,
    required this.explanation,
    required this.referenceAudio,
    required this.practice,
    required this.fallback,
    required this.safety,
    required this.prerequisites,
    required this.selfCheck,
    required this.commonErrors,
    required this.adaptation,
    required this.repertoire,
    required this.legacy,
    required this.minutes,
    required this.expertPending,
  });

  final String id;
  final String course;
  final int level;
  final GuitarText title;
  final GuitarText goal;
  final List<GuitarText> explanation;
  final V1ReferenceAudio referenceAudio;
  final V1Practice practice;
  final V1Fallback fallback;
  final List<String> safety;

  /// Empty = default rule (contract §9); listed only for exceptions.
  final List<String> prerequisites;
  final List<GuitarText> selfCheck;
  final List<V1CommonError> commonErrors;
  final GuitarText adaptation;
  final String? repertoire;
  final String? legacy;
  final int minutes;

  /// Pass thresholds are defaults until a music teacher signs them off.
  final bool expertPending;

  static final RegExp idPattern = RegExp(
    r'^(gtr|voc|pno|ear)-s([1-4])-(?:m\d{2}[ab]?-\d{2}|test(?:-[ab])?)$',
  );
  static const Set<String> safetyCodes = {
    'Ç', 'G1', 'G2', 'G3', 'V1', 'V2', 'V3', 'V4', 'V5', 'P1', 'P2', 'E1', //
  };
  static const Set<String> _keys = {
    'id', 'title', 'goal', 'explanation', 'referenceAudio', 'practice',
    'fallback', 'safety', 'prerequisites', 'selfCheck', 'commonErrors',
    'adaptation', 'minutes', 'expertPending', //
  };
  static const Set<String> _optionalKeys = {'repertoire', 'legacy'};

  factory V1Lesson.fromJson(Object? json) {
    final m = _object(json, _keys, optional: _optionalKeys);
    final id = _string(m['id']);
    final match = idPattern.firstMatch(id);
    if (match == null) throw FormatException('Invalid v1 lesson id $id');
    final practice = V1Practice.fromJson(m['practice']);
    final fallback = V1Fallback.values.byName(_string(m['fallback']));
    if (fallback != V1Fallback.forMeasurement(practice.measurement)) {
      throw FormatException('$id: fallback does not follow measurement');
    }
    final explanation = _texts(m['explanation']);
    if (explanation.length < 3 || explanation.length > 6) {
      throw FormatException('$id: explanation needs 3–6 points');
    }
    final safety = _strings(m['safety']);
    if (!safety.contains('Ç') || !safetyCodes.containsAll(safety)) {
      throw FormatException('$id: safety must include Ç and known codes');
    }
    final selfCheck = _texts(m['selfCheck']);
    if (practice.measurement.contains('Ö') &&
        (selfCheck.length < 3 || selfCheck.length > 5)) {
      throw FormatException('$id: Ö lessons need a 3–5 item self-check');
    }
    final rawErrors = m['commonErrors'];
    if (rawErrors is! List) throw FormatException('$id: commonErrors list');
    final errors = rawErrors
        .map(V1CommonError.fromJson)
        .toList(growable: false);
    if (errors.isEmpty || errors.length > 3) {
      throw FormatException('$id: commonErrors needs 1–3 entries');
    }
    final prerequisites = _strings(m['prerequisites']);
    if (prerequisites.any((p) => !idPattern.hasMatch(p))) {
      throw FormatException('$id: invalid prerequisite id');
    }
    final minutes = m['minutes'];
    if (minutes is! int || minutes < 2 || minutes > 30) {
      throw FormatException('$id: minutes must be 2–30');
    }
    final expertPending = m['expertPending'];
    if (expertPending is! bool) {
      throw FormatException('$id: expertPending must be a bool');
    }
    return V1Lesson._(
      id: id,
      course: match.group(1)!,
      level: int.parse(match.group(2)!),
      title: _text(m['title']),
      goal: _text(m['goal']),
      explanation: explanation,
      referenceAudio: V1ReferenceAudio.fromJson(m['referenceAudio']),
      practice: practice,
      fallback: fallback,
      safety: safety,
      prerequisites: prerequisites,
      selfCheck: selfCheck,
      commonErrors: errors,
      adaptation: _text(m['adaptation']),
      repertoire: m['repertoire'] == null ? null : _string(m['repertoire']),
      legacy: m['legacy'] == null ? null : _string(m['legacy']),
      minutes: minutes,
      expertPending: expertPending,
    );
  }
}

/// What happens when the engine step a lesson needs is late (contract §4.2).
enum V1Fallback {
  selfCheck,
  held,
  experimental,
  camera,
  noEngine;

  static V1Fallback forMeasurement(List<String> codes) {
    if (codes.contains('M!')) return held;
    if (codes.contains('M~')) return experimental;
    if (codes.contains('M')) return selfCheck;
    if (codes.contains('K')) return camera;
    return noEngine;
  }
}

/// Synthesized reference only (contract §7); never a recording.
final class V1ReferenceAudio {
  const V1ReferenceAudio(this.kinds, this.brief);
  final List<String> kinds;
  final GuitarText? brief;

  static const Set<String> allowed = {'S', 'SE', 'DR', 'KL'};

  factory V1ReferenceAudio.fromJson(Object? json) {
    final m = _object(json, {'kinds'}, optional: {'brief'});
    final kinds = _strings(m['kinds']);
    if (!allowed.containsAll(kinds)) {
      throw const FormatException('Unknown reference audio kind');
    }
    return V1ReferenceAudio(
      kinds,
      m['brief'] == null ? null : _text(m['brief']),
    );
  }
}

final class V1Practice {
  const V1Practice({
    required this.measurement,
    required this.engineSteps,
    required this.task,
    required this.sequence,
    required this.tempo,
    required this.pass,
    required this.drill,
    this.alternative,
    this.clap,
  });

  /// Dominant code first, as in the plan row (`D+M`).
  final List<String> measurement;
  final List<String> engineSteps;
  final GuitarText task;

  /// Scientific pitch, sounding pitch for guitar; degrees for voice (§6.1).
  final String? sequence;

  /// Null = free tempo ("serbest").
  final V1Tempo? tempo;
  final V1Pass pass;

  /// Generated on-screen questions: required for D, optional for M!.
  final V1Drill? drill;

  /// The on-screen version a singing (A5) task offers instead of singing.
  /// It is the lesson's measured path; singing stays a self-check.
  final V1Alternative? alternative;

  /// The drill this lesson can run: its own (D, M!) or a singing
  /// alternative.
  V1Drill? get anyDrill => drill ?? alternative?.drill;

  /// Clapping lines generated per attempt (ear course, A3); no `sequence`.
  final V1ClapLines? clap;

  /// The tempo ladder of this lesson's practice: a clap block's own, else
  /// [tempo].
  V1Tempo? get practiceTempo => clap?.tempo ?? tempo;

  static const Set<String> measurementCodes = {
    'M', 'M!', 'M~', 'MIDI', 'K', 'Ö', 'D', //
  };
  static const Set<String> engineCodes = {
    'A0', 'A1', 'A2', 'A3', 'A4', 'A5', 'A6', 'A6p', 'A7', //
  };

  factory V1Practice.fromJson(Object? json) {
    final m = _object(
      json,
      {'measurement', 'engineSteps', 'task', 'pass'},
      optional: {'sequence', 'tempo', 'drill', 'clap', 'alternative'},
    );
    final measurement = _strings(m['measurement']);
    final steps = _strings(m['engineSteps']);
    if (measurement.isEmpty || !measurementCodes.containsAll(measurement)) {
      throw const FormatException('Unknown measurement code');
    }
    if (steps.isEmpty || !engineCodes.containsAll(steps)) {
      throw const FormatException('Unknown engine step');
    }
    final screenOnly = measurement.every((c) => c == 'D' || c == 'Ö');
    if (steps.contains('A0') != screenOnly ||
        (steps.contains('A0') && steps.length > 1)) {
      throw const FormatException('A0 iff measurement is D/Ö only');
    }
    final drill = m['drill'] == null ? null : V1Drill.fromJson(m['drill']);
    // D lessons need a drill; checkpoints (M!) may carry one for their
    // on-screen part; nothing else may.
    if (measurement.contains('D') && drill == null ||
        drill != null &&
            !measurement.contains('D') &&
            !measurement.contains('M!')) {
      throw const FormatException('Drill only on D lessons and checkpoints');
    }
    final alternative = m['alternative'] == null
        ? null
        : V1Alternative.fromJson(m['alternative']);
    if (alternative != null && !steps.contains('A5')) {
      throw const FormatException('An alternative replaces singing (A5)');
    }
    final clap = m['clap'] == null ? null : V1ClapLines.fromJson(m['clap']);
    if (clap != null &&
        (m['sequence'] != null ||
            !steps.every((s) => s == 'A3') ||
            !(measurement.contains('M') || measurement.contains('M!')))) {
      throw const FormatException(
        'A clap block is for A3 microphone lessons without a sequence',
      );
    }
    return V1Practice(
      alternative: alternative,
      clap: clap,
      measurement: measurement,
      engineSteps: steps,
      task: _text(m['task']),
      sequence: m['sequence'] == null ? null : _string(m['sequence']),
      tempo: m['tempo'] == null ? null : V1Tempo.fromJson(m['tempo']),
      pass: V1Pass.fromJson(m['pass']),
      drill: drill,
    );
  }
}

/// The on-screen version a singing task names ("If you'd rather not sing,
/// …"). [source] quotes where it comes from.
final class V1Alternative {
  const V1Alternative(this.drill, this.source);
  final V1Drill drill;
  final String source;

  factory V1Alternative.fromJson(Object? json) {
    final m = _object(json, {'drill', 'source'});
    return V1Alternative(V1Drill.fromJson(m['drill']), _string(m['source']));
  }
}

/// Clapping lines made at run time (lesson guide §3.1: generated lines carry
/// no `sequence`). [derivedFrom] records where the values came from.
final class V1ClapLines {
  const V1ClapLines({
    required this.values,
    required this.bars,
    required this.lines,
    required this.tempo,
    required this.ties,
    required this.derivedFrom,
  });

  /// Rhythm value names of the dictation drills (`quarter`, `eighthPair`…).
  final List<String> values;
  final int bars, lines;
  final V1Tempo tempo;
  final bool ties;
  final String derivedFrom;

  static const Set<String> valueNames = {
    'whole', 'half', 'dottedQuarter', 'quarter', 'eighthPair', 'eighth', //
    'quarterRest', 'halfRest',
  };

  factory V1ClapLines.fromJson(Object? json) {
    final m = _object(
      json,
      {'values', 'bars', 'lines', 'tempo', 'derivedFrom'},
      optional: {'ties'},
    );
    final values = _strings(m['values']);
    final bars = m['bars'], lines = m['lines'], ties = m['ties'] ?? false;
    if (values.isEmpty || !valueNames.containsAll(values)) {
      throw const FormatException('Unknown clap value');
    }
    if (bars is! int || bars < 1 || bars > 4) {
      throw const FormatException('Clap bars must be 1–4');
    }
    if (lines is! int || lines < 1 || lines > 8) {
      throw const FormatException('Clap lines must be 1–8');
    }
    if (ties is! bool) throw const FormatException('ties must be a boolean');
    return V1ClapLines(
      values: values,
      bars: bars,
      lines: lines,
      tempo: V1Tempo.fromJson(m['tempo']),
      ties: ties,
      derivedFrom: _string(m['derivedFrom']),
    );
  }
}

final class V1Tempo {
  const V1Tempo(this.open, this.target);
  final int open;
  final int target;

  factory V1Tempo.fromJson(Object? json) {
    final m = _object(json, {'open', 'target'});
    final open = m['open'], target = m['target'];
    if (open is! int ||
        target is! int ||
        open < 30 ||
        target < open ||
        target > 240) {
      throw const FormatException('Invalid tempo ladder');
    }
    return V1Tempo(open, target);
  }
}

/// `levelDefault` = contract §6.2 for the lesson's level; otherwise a custom
/// rule stated in copy (and, for D drills, a minimum correct count).
final class V1Pass {
  const V1Pass(this.levelDefault, this.text, this.minCorrect);
  final bool levelDefault;
  final GuitarText? text;
  final int? minCorrect;

  factory V1Pass.fromJson(Object? json) {
    final m = _object(json, {'levelDefault'}, optional: {'text', 'minCorrect'});
    final levelDefault = m['levelDefault'];
    if (levelDefault is! bool) {
      throw const FormatException('pass.levelDefault must be a bool');
    }
    if (!levelDefault && m['text'] == null) {
      throw const FormatException('Custom pass rule needs text');
    }
    final minCorrect = m['minCorrect'];
    if (minCorrect != null && (minCorrect is! int || minCorrect < 1)) {
      throw const FormatException('Invalid pass.minCorrect');
    }
    return V1Pass(
      levelDefault,
      m['text'] == null ? null : _text(m['text']),
      minCorrect as int?,
    );
  }
}

/// A generated on-screen exercise. Questions are produced from `params` at
/// run time, so a lesson file never carries an answer key that can drift.
final class V1Drill {
  const V1Drill(this.type, this.count, this.params);
  final String type;
  final int count;
  final Map<String, Object?> params;

  static const Set<String> types = {
    'tempo_compare', 'pitch_direction', 'same_different', 'interval_name',
    'triad_quality', 'scale_degree', 'key_signature', 'note_name',
    'rhythm_dictation', 'melodic_dictation', 'symbol_match', 'diagram_match',
    'ordering', 'half_step_place', 'degree_over_drone', 'staff_match', //
  };

  factory V1Drill.fromJson(Object? json) {
    final m = _object(json, {'type', 'count', 'params'});
    final type = _string(m['type']);
    final count = m['count'];
    final params = m['params'];
    if (!types.contains(type)) {
      throw FormatException('Unknown drill type $type');
    }
    if (count is! int || count < 1 || count > 40) {
      throw const FormatException('Drill count must be 1–40');
    }
    if (params is! Map<String, dynamic>) {
      throw const FormatException('Drill params must be an object');
    }
    return V1Drill(type, count, Map.unmodifiable(params));
  }
}

/// Tied to a measured outcome ("different note, a semitone high → …").
final class V1CommonError {
  const V1CommonError(this.error, this.fix);
  final GuitarText error;
  final GuitarText fix;

  factory V1CommonError.fromJson(Object? json) {
    final m = _object(json, {'error', 'fix'});
    return V1CommonError(_text(m['error']), _text(m['fix']));
  }
}

Map<String, dynamic> _object(
  Object? value,
  Set<String> required, {
  Set<String> optional = const {},
}) {
  if (value is! Map<String, dynamic> ||
      !value.keys.toSet().containsAll(required) ||
      !required.union(optional).containsAll(value.keys)) {
    throw FormatException(
      'Invalid v1 lesson fields: expected $required (+$optional)',
    );
  }
  return value;
}

String _string(Object? value) {
  if (value is! String || value.trim().isEmpty) {
    throw const FormatException('Expected a non-empty string');
  }
  return value;
}

List<String> _strings(Object? value) {
  if (value is! List) throw const FormatException('Expected a list');
  return List.unmodifiable(value.map(_string));
}

GuitarText _text(Object? value) {
  final m = _object(value, {'en', 'tr'});
  return GuitarText(_string(m['en']), _string(m['tr']));
}

List<GuitarText> _texts(Object? value) {
  if (value is! List) throw const FormatException('Expected a list');
  return List.unmodifiable(value.map(_text));
}
