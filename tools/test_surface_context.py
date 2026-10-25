import contextlib
import io
import json
from pathlib import Path
import unittest
from unittest.mock import patch

import validate_surface_honesty as gate
from surface_context import (
    arguments, body_side_allowed, dart_hand_context, guarded_dart_contexts,
    hand_context, historical_body_report, instructional_promise_word,
    catalog_parity, merged_dart_literals, message_id_map, paired_json_contexts, preference_payload_role,
    translation_text_proof, without_labelled_turkish_quote,
)

LOCALE = """String localized(BuildContext context, String english, String turkish) =>
 Localizations.localeOf(context).languageCode == 'tr' ? turkish : english;"""
FILE = 'lib/app/screens/example.dart'


def guarded(source, extra=None):
    return guarded_dart_contexts({
        'lib/app/app_locale.dart': LOCALE,
        FILE: source,
        **(extra or {}),
    })


def texts(items):
    return {text for _, text in items}


class ContextTests(unittest.TestCase):
    def test_json_locale_requires_a_complete_nonempty_pair(self):
        locales, errors = paired_json_contexts(
            {'teach': {'en': 'Read first.', 'tr': 'Önce oku.'}}, 'course')
        self.assertEqual(locales, {'course.teach.en': 'en', 'course.teach.tr': 'tr'})
        self.assertFalse(errors)
        for value in [{'tr': 'Oku.'}, {'en': '', 'tr': 'Oku.'},
                      {'en': 'Read.', 'tr': 'Oku.', 'other': 'x'}]:
            with self.subTest(value=value):
                self.assertTrue(paired_json_contexts(value, 'course')[1])
                self.assertFalse(paired_json_contexts(value, 'course')[0])

    def test_import_does_not_exempt_unlocalized_turkish_or_english_branch(self):
        source = """import '../app_locale.dart';
Text('Önce oku.');
Text(localized(context, 'Yanlış İngilizce alan.', 'Doğru Türkçe.'));"""
        result = texts(guarded(source))
        self.assertIn('Doğru Türkçe.', result)
        self.assertNotIn('Önce oku.', result)
        self.assertNotIn('Yanlış İngilizce alan.', result)

    def test_changed_dispatcher_and_wrong_arity_fail_closed(self):
        source = "import '../app_locale.dart'; localized(context, 'Read.', 'Oku.');"
        self.assertIn('Oku.', texts(guarded(source)))
        self.assertNotIn('Oku.', texts(guarded(source, {
            'lib/app/app_locale.dart': LOCALE.replace('? turkish : english', '? english : turkish')})))
        self.assertNotIn('Oku.', texts(guarded(source.replace(
            "'Oku.')", "'Oku.', 'extra')"))))

    def test_receiver_method_is_not_the_imported_locale_dispatcher(self):
        for receiver in ['Other().', 'other . ', 'other?.']:
            source = ("import '../app_locale.dart'; " + receiver +
                      "localized(context, 'Read.', 'Yanlış Türkçe.');")
            self.assertNotIn('Yanlış Türkçe.', texts(guarded(source)))

    def test_local_member_or_callback_cannot_shadow_imported_dispatcher(self):
        declarations = [
            'String localized(BuildContext context, String english, String turkish) => turkish;',
            'localized(context, english, turkish) => turkish;',
            'final localized = (context, english, turkish) => turkish;']
        for declaration in declarations:
            source = ("import '../app_locale.dart'; class Other { " + declaration +
                      " Widget build() => Text(localized(context, 'Read.', 'Yanlış Türkçe.')); }")
            self.assertNotIn('Yanlış Türkçe.', texts(guarded(source)), declaration)

    def test_verified_dispatcher_file_keeps_its_own_localized_calls(self):
        source = LOCALE + " localized(context, 'Read.', 'Önce oku.');"
        self.assertIn('Önce oku.', texts(guarded('', {'lib/app/app_locale.dart': source})))
        source += ' String localized(context, en, tr) => tr;'
        self.assertNotIn('Önce oku.', texts(guarded('', {'lib/app/app_locale.dart': source})))

    def test_reviewed_copy_needs_exact_constructor_and_complete_renderer(self):
        source = """import '../app_locale.dart';
const _Reviewed(this.source, this.turkish);
static String text(BuildContext context, String id, String source) {
final _Reviewed? copy = _copies[id];
return copy != null && copy.source == source ? localized(context, source, copy.turkish) : source;
}
const copy = _Reviewed('Read.', 'Önce oku.');"""
        self.assertIn('Önce oku.', texts(guarded(source)))
        for changed in [source.replace('copy.turkish) : source', 'copy.turkish) + copy.turkish : source'),
                        source.replace('this.source, this.turkish', 'this.turkish, this.source')]:
            self.assertNotIn('Önce oku.', texts(guarded(changed)))

    def test_localized_wrapper_only_allows_the_forwarded_parameter(self):
        source = """import '../app_locale.dart';
Widget section(BuildContext context, String en, String tr, String body) =>
 Column(children: [Text(localized(context, en, tr)), Text(body)]);
section(context, 'Read.', 'Önce oku.', 'Body.');"""
        self.assertIn('Önce oku.', texts(guarded(source)))
        self.assertNotIn('Önce oku.', texts(guarded(source.replace(
            'Text(body)', 'Text(tr)'))))

    def test_locale_ternary_and_if_are_scoped_to_the_turkish_branch(self):
        source = """final tr = widget.locale == 'tr';
Text(tr ? 'Önce oku.' : 'Read first.');
if (Localizations.localeOf(context).languageCode == 'tr') { Text('Yeniden dene.'); }
Text('Korumasız Türkçe.');"""
        values = texts(guarded(source))
        self.assertIn('Önce oku.', values)
        self.assertIn('Yeniden dene.', values)
        self.assertNotIn('Korumasız Türkçe.', values)
        self.assertNotIn('Önce oku.', texts(guarded(source.replace(
            "widget.locale == 'tr'", 'false'))))

    def test_negated_boolean_composition_and_shadowed_flags_are_not_tr_guards(self):
        for condition in ['!tr', 'true || tr', 'false && tr', 'false == tr', 'true != tr']:
            source = ("void build() { final tr = widget.locale == 'tr'; "
                      f"Text({condition} ? 'Yanlış Türkçe.' : 'Read.'); }}")
            self.assertNotIn('Yanlış Türkçe.', texts(guarded(source)), condition)
        source = """void first() { final tr = widget.locale == 'tr'; }
void second() { final tr = true; Text(tr ? 'Yanlış Türkçe.' : 'Read.'); }"""
        self.assertNotIn('Yanlış Türkçe.', texts(guarded(source)))
        source = """void first() { final tr = widget.locale == 'tr';
Widget copy(bool tr) => Text(tr ? 'Yanlış Türkçe.' : 'Read.'); copy(true); }"""
        self.assertNotIn('Yanlış Türkçe.', texts(guarded(source)))
        source = """void first() { final tr = widget.locale == 'tr';
{ final tr = true; Text(tr ? 'Yanlış Türkçe.' : 'Read.'); } }"""
        self.assertNotIn('Yanlış Türkçe.', texts(guarded(source)))

    def test_private_flag_forwarding_needs_every_caller_to_prove_locale(self):
        source = """void build() { final tr = widget.locale == 'tr'; _label(1, tr); }
String _label(int n, bool tr) { return tr ? 'Önce oku.' : 'Read.'; }"""
        self.assertIn('Önce oku.', texts(guarded(source)))
        self.assertNotIn('Önce oku.', texts(guarded(source +
            ' void other() { _label(1, true); }')))
        self.assertNotIn('Önce oku.', texts(guarded(source +
            ' final callback = _label; callback(1, true);')))
        self.assertNotIn('Önce oku.', texts(guarded(source.replace(
            "return tr ?", "tr |= true; return tr ?"))))

    def test_named_optional_and_closure_parameters_shadow_outer_locale(self):
        for declaration in [
                'Widget copy({bool tr = true})',
                'Widget copy([bool tr = true])',
                'final copy = (tr)', 'final copy = (bool tr)',
                'final copy = ({bool tr = true})']:
            source = ("void build() { final tr = widget.locale == 'tr'; " +
                      declaration + " => Text(tr ? 'Yanlış Türkçe.' : 'Read.'); }")
            self.assertNotIn('Yanlış Türkçe.', texts(guarded(source)), declaration)

    def test_for_loop_and_pattern_binding_cannot_inherit_outer_locale(self):
        for loop in ['for (final tr in [true])', 'for (bool tr in [true])',
                     'for (final (tr, count) in rows)', 'for (var tr = true; tr; tr = false)']:
            source = ("void build() { final tr = widget.locale == 'tr'; " + loop +
                      " Text(tr ? 'Yanlış Türkçe.' : 'Read.'); }")
            self.assertNotIn('Yanlış Türkçe.', texts(guarded(source)), loop)

    def test_a_locale_map_cannot_escape_into_unconditional_or_english_reads(self):
        source = """const Map<String, String> copy = <String, String>{'label': 'Önce oku.'};
String text(BuildContext context) => Localizations.localeOf(context).languageCode == 'tr'
 ? copy['label']! : 'Read.';"""
        self.assertIn('Önce oku.', texts(guarded(source)))
        for escape in ["Text(copy['label']!);", 'return copy;']:
            self.assertNotIn('Önce oku.', texts(guarded(source + escape)))

    def test_wrapper_cannot_append_turkish_after_locale_dispatch(self):
        source = """import '../app_locale.dart';
String text(BuildContext context, String en, String tr) => localized(context, en, tr) + tr;
text(context, 'Read.', 'Yanlış Türkçe.');"""
        self.assertNotIn('Yanlış Türkçe.', texts(guarded(source)))

    def test_study_constructor_needs_both_constructor_and_render_guard(self):
        file = 'lib/app/study_review_content.dart'
        content = 'const StudyText(this.en, this.tr); StudyText("Read.", "Önce oku.");'
        renderer = ('String inContext(BuildContext context) => _text(context, en, tr); '
                    'String _text(BuildContext context, String en, String tr) => '
                    'localized(context, en, tr);')
        sources = {file: content, 'lib/app/study_review.dart': renderer}
        self.assertIn('Önce oku.', texts(guarded('', sources)))
        self.assertNotIn('Önce oku.', texts(guarded('', {
            **sources, file: content.replace('this.en, this.tr', 'this.tr, this.en')})))
        self.assertNotIn('Önce oku.', texts(guarded('', {
            **sources, 'lib/app/study_review.dart': renderer.replace(
                'localized(context, en, tr)', 'localized(context, tr, en)')})))
        shadow = (' String localized(BuildContext context, String english, '
                  'String turkish) => turkish;')
        self.assertNotIn('Önce oku.', texts(guarded('', {
            **sources, 'lib/app/study_review.dart': renderer + shadow})))
        self.assertNotIn('Önce oku.', texts(guarded('', {
            **sources, 'lib/app/app_locale.dart': LOCALE + shadow})))
        for expression in ['localized(context, en, tr) + tr',
                           '_text(context, en, tr) + tr']:
            call = 'localized(context, en, tr)' if expression.startswith('localized') else '_text(context, en, tr)'
            self.assertNotIn('Önce oku.', texts(guarded('', {
                **sources, 'lib/app/study_review.dart': renderer.replace(call, expression)})))

    def test_legacy_map_allows_only_the_exact_guarded_render_read(self):
        source = Path('lib/app/catalog_copy_tr.dart').read_text()
        self.assertTrue(gate.guarded_turkish_catalog_literals([], source, precise=True))
        leaks = ["String leak(String key) => true ? _turkishCopy[key]! : 'Read.';",
                 "String leak(String key) => _turkishCopy[key]!;",
                 'final copy = _turkishCopy;']
        for leak in leaks:
            self.assertFalse(gate.guarded_turkish_catalog_literals(
                [], source + leak, precise=True), leak)
        # Both render shapes: legacy early-return and the fourteen-locale
        # forwarded dispatch. Only mutations that actually apply are counted.
        mutations = [source.replace('return source;', "return 'Önce oku.';", 1),
                     source.replace(': source;', ": 'Önce oku.';", 1),
                     source.replace('localized(context, source, _turkishCopy[key]!)',
                                    'localized(context, _turkishCopy[key]!, source)', 1),
                     source.replace('_fingerprint(source);', '_fingerprint(source) || true;')]
        applied = [m for m in mutations if m != source]
        self.assertGreaterEqual(len(applied), 3)
        for mutation in applied:
            self.assertFalse(gate.guarded_turkish_catalog_literals([], mutation, precise=True))

    def test_nested_interpolation_keeps_every_inner_literal_and_concatenation(self):
        source = """Text('${localized(context, 'Read.', 'Önce oku.')} ${n}');
Text('Microphone is not ' 'wired in this build.');"""
        literals = list(merged_dart_literals(source))
        self.assertIn('Read.', {text for _, _, text in literals})
        self.assertIn('Önce oku.', {text for _, _, text in literals})
        self.assertIn('Microphone is not wired in this build.',
                      {text for _, _, text in literals})
        self.assertIn('Önce oku.', texts(guarded("import '../app_locale.dart';" + source)))
        self.assertFalse(arguments("f('text', [1, 2)", 1))

    def test_nested_string_does_not_break_outer_concatenated_claim(self):
        source = '''Text("${format('x')} The microphone is not " "wired in this build.");'''
        values = [value for _, _, value in merged_dart_literals(source)]
        self.assertIn('x', values)
        self.assertTrue(any(gate.global_audio_absence(value) for value in values))

    def test_only_explicitly_labelled_foreign_quote_is_language_context(self):
        self.assertEqual(without_labelled_turkish_quote(
            'Turkish “Ben bu-ra-da” has four syllables.'),
            'Turkish example has four syllables.')
        self.assertIn('önce oku', without_labelled_turkish_quote(
            'Turkish “Ben” is an example; önce oku.'))

    def test_physical_steps_are_not_future_release_promises(self):
        valid = [('No pedal yet.', 'yet'),
                 ('Do not play C yet if reaching is uncomfortable.', 'yet'),
                 ('Do akorunu henüz çalma.', 'henüz'),
                 ('Yakında su olabilir.', 'yakında')]
        invalid = [('Audio feedback is not available yet.', 'yet'),
                   ('No pedal yet; audio scoring is not ready yet.', 'yet'),
                   ('Do not play yet; we cannot measure your notes yet.', 'yet'),
                   ('Yakında su takibi eklenecek.', 'yakında'),
                   ('Henüz canlı nota ölçümü yok.', 'henüz')]
        for sentence, label in valid:
            self.assertTrue(instructional_promise_word(sentence, label), sentence)
        for sentence, label in invalid:
            self.assertFalse(instructional_promise_word(sentence, label), sentence)

    def test_scoped_audio_absence_does_not_erase_global_absence(self):
        for text in ['This written course needs no microphone or camera.',
                     'Duruş dersleri mikrofon kullanmaz; yazılı gitar yolu isteğe bağlıdır.']:
            self.assertFalse(gate.global_audio_absence(text))
        for text in ['There is no microphone input in this build.',
                     'Bu sürüm mikrofon kullanmaz.',
                     'This written course has no microphone input in this build.']:
            self.assertTrue(gate.global_audio_absence(text))

    def test_engine_description_is_not_data_retention_but_actual_data_is(self):
        self.assertFalse(gate.RETENTION_CLAIM.search(
            "Instrument pages describe recorded references and the measurement engine's limits."))
        for sentence in ['We save your measurements.',
                         'We recorded references containing your measurements.',
                         'The measurement engine stores your angles.',
                         'Your measurements are saved.']:
            self.assertTrue(gate.RETENTION_CLAIM.search(sentence), sentence)

    def test_handedness_uses_the_course_entry_and_does_not_allow_other_limbs(self):
        right = {'id': 'ukulele.beginner', 'entry': {'en': 'Right-handed four-string ukulele.'}}
        self.assertTrue(body_side_allowed(hand_context(right), 'left-hand finger'))
        self.assertFalse(body_side_allowed(hand_context({**right, 'entry': {}}), 'left hand'))
        self.assertFalse(body_side_allowed(hand_context({'id': 'guitar.journey'}), 'right hand'))
        self.assertTrue(body_side_allowed(hand_context({'id': 'piano.beginner'}), 'left hand'))
        self.assertFalse(body_side_allowed(hand_context({'id': 'piano.beginner'}), 'right shoulder'))
        self.assertFalse(body_side_allowed(hand_context(right), 'left shoulder'))
        self.assertTrue(gate.BODY_SIDE.search('Sağ elini buraya koy.'))
        for entry in ['No right-handed convention is assumed.',
                      'Not right-handed.', 'Right-handed bass is not supported.']:
            self.assertIsNone(hand_context({**right, 'entry': {'en': entry}}))

    def test_dart_diagram_context_depends_on_its_source_and_course_convention(self):
        source = "class UkuleleDiagrams {} import '../ukulele_beginner.dart'; UkuleleCourse course;"
        contexts = {'assets/content/ukulele_beginner.v1.json': 'declared_string_convention'}
        self.assertEqual(dart_hand_context(source, contexts), 'declared_string_convention')
        self.assertIsNone(dart_hand_context(source, {}))
        self.assertIsNone(dart_hand_context(source.replace('UkuleleCourse course', ''), contexts))

    def test_historical_hand_ambiguity_is_not_an_instruction(self):
        text = ('Kaydedilmiş referans analizinde kayıtlarda sağ ve sol kol '
                'güvenilir biçimde ayrılmadığı için yanlış tarafı puanlama riski vardır.')
        self.assertTrue(historical_body_report(text))
        self.assertFalse(historical_body_report(text + ' Sağ kolunu kaldır.'))


class GateRegressionTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.raw = list(gate.dart_surface_strings())
        cls.json_strings = gate.json_surface_strings()

    def assert_rejects(self, *, dart=None, json_strings=None, category):
        with patch.object(gate, 'dart_surface_strings', return_value=iter(dart or self.raw)), \
                patch.object(gate, 'json_surface_strings', side_effect=(
                    lambda files=None: json_strings if files is None and json_strings is not None
                    else gate_json_original(files))), contextlib.redirect_stdout(io.StringIO()) as out:
            self.assertEqual(gate.main(), 1)
        self.assertIn(category, out.getvalue())

    def test_untranslated_literal_in_a_file_importing_locale_still_fails(self):
        self.assert_rejects(dart=self.raw + [
            ('lib/app/screens/library_screen.dart', 99999, 'Önce oku ve sonra seç.')],
            category='[dil]')

    def test_turkish_in_the_english_json_branch_still_fails(self):
        self.assert_rejects(json_strings=self.json_strings + [
            ('assets/content/piano_beginner.v1.json.lessons[0].teach.en', 'Önce oku ve sonra çal.')],
            category='[dil]')

    def test_a_valid_turkish_branch_still_checks_future_claims(self):
        self.assert_rejects(json_strings=self.json_strings + [
            ('assets/content/piano_beginner.v1.json.lessons[0].teach.tr', 'Yakında canlı nota ölçümü eklenecek.')],
            category='[vaat dili]')

    def test_unknown_handedness_still_fails(self):
        self.assert_rejects(dart=self.raw + [
            ('lib/app/screens/library_screen.dart', 99999, 'Put your right hand here.')],
            category='[vücut-taraf]')

    def test_duplicate_literal_identity_does_not_hide_an_unguarded_occurrence(self):
        sources = {file: gate.strip_dart_comments(Path(file).read_text())
                   for file, _, _ in self.raw}
        pairs = guarded_dart_contexts(sources)
        where, text = next((where, text) for where, text in pairs
                           if set(text) & gate.TURKISH_CHARS and ' ' in text)
        file, line = where.rsplit(':', 1)
        self.assert_rejects(dart=self.raw + [(file, int(line), text)], category='[dil]')

    def test_allowed_first_hand_does_not_hide_a_later_unsupported_limb(self):
        self.assert_rejects(json_strings=self.json_strings + [
            ('assets/content/piano_beginner.v1.json.lessons[0].teach.en',
             'Put your right hand on the keys and raise your left shoulder.')],
            category='left shoulder')

    def test_new_dependency_cannot_escape_partition(self):
        original = gate.lock_packages
        with patch.object(gate, 'lock_packages', side_effect=lambda text: original(text) + ['mystery_network']), \
                contextlib.redirect_stdout(io.StringIO()) as out:
            self.assertEqual(gate.main(), 1)
        self.assertIn('[bölme]', out.getvalue())

    def test_english_count_has_english_subdivision_and_turkish_keeps_ve(self):
        course = json.loads(Path('assets/content/piano_beginner.v1.json').read_text())
        copy = course['lessons'][7]['recover']
        self.assertIn('1-and 2-and 3-and 4-and', copy['en'])
        self.assertNotIn('1-ve', copy['en'])
        self.assertIn('1-ve', copy['tr'])


FORWARDED_LOCALE = """String localized(
  BuildContext context,
  String english,
  String turkish, {
  Map<String, Object?> values = const {},
  num? pluralCount,
}) =>
    (AppTranslations.maybeOf(context) ??
            AppTranslations(
              Localizations.maybeLocaleOf(context) ?? const Locale('en'),
              const {},
            ))
        .text(english, turkish, values: values, pluralCount: pluralCount);"""
CATALOG = """final class AppTranslations {
  String text(
    String english,
    String turkish, {
    Map<String, Object?> values = const {},
    num? pluralCount,
  }) {
    final tag = canonicalLanguageTag(locale);
    final id = appMessageIds[(english, turkish)];
    var template = tag == 'tr' ? turkish : english;
    if (pluralCount == 1 && id != null) {
      template = appMessagePluralSources[id]?[tag == 'tr' ? 'trOne' : 'enOne'] ?? template;
    }
    return template;
  }
}"""


def forwarded(source, catalog=CATALOG, extra=None):
    return texts(guarded_dart_contexts({
        'lib/app/app_locale.dart': FORWARDED_LOCALE,
        'lib/app/app_translation_catalog.dart': catalog,
        FILE: source, **(extra or {})}))


class ForwardedDispatcherTests(unittest.TestCase):
    call = ("import '../app_locale.dart'; a = localized(context, 'Read {v0}.', 'Oku {v0}.', "
            "values: {'v0': 1}); b = localized(context, 'Read.', 'Oku.');")

    def test_forwarded_dispatcher_classifies_tr_argument_with_named_values(self):
        self.assertTrue({'Oku {v0}.', 'Oku.'} <= forwarded(self.call))
        self.assertTrue(translation_text_proof(CATALOG))

    def test_unknown_named_or_positional_extra_argument_fails_closed(self):
        for call in ["localized(context, 'Read.', 'Yanlış.', other: 1);",
                     "localized(context, 'Read.', 'Yanlış.', 'extra');",
                     "localized(context, 'Read.', 'Yanlış.', values: {}, values: {});",
                     "localized(context, english: 'Read.', 'Yanlış.', 'x');"]:
            self.assertNotIn('Yanlış.', forwarded("import '../app_locale.dart'; " + call), call)

    def test_catalog_that_can_render_turkish_off_the_tr_branch_fails_closed(self):
        for old, new in [("tag == 'tr' ? turkish : english", "tag == 'tr' ? english : turkish"),
                         ("var template = tag == 'tr' ? turkish : english;", "var template = turkish;"),
                         ("final id =", "tag = 'tr'; final id ="),
                         ("[tag == 'tr' ? 'trOne' : 'enOne']", "['trOne']"),
                         ("return template;", "return template + turkish;")]:
            broken = CATALOG.replace(old, new, 1)
            self.assertNotEqual(broken, CATALOG)
            self.assertFalse(translation_text_proof(broken), new)
            self.assertNotIn('Oku.', forwarded(self.call, broken), new)

    def test_second_reader_of_the_id_map_fails_closed(self):
        self.assertNotIn('Oku.', forwarded(self.call, extra={
            'lib/app/leak.dart': "String leak() => appMessageIds.keys.first.$2;"}))

    def test_changed_forwarding_definition_fails_closed(self):
        source = FORWARDED_LOCALE.replace('.text(english, turkish', '.text(turkish, english')
        self.assertNotIn('Oku.', texts(guarded_dart_contexts({
            'lib/app/app_locale.dart': source,
            'lib/app/app_translation_catalog.dart': CATALOG, FILE: self.call})))

    def test_turkish_map_only_read_as_tr_argument(self):
        good = ("import '../app_locale.dart';\n"
                "const Map<String, String> _names = <String, String>{'a': 'Gitar adı'};\n"
                "String name(BuildContext context, String id, String en) {\n"
                "  final tr = _names[id] ?? en;\n  return localized(context, en, tr);\n}")
        self.assertIn('Gitar adı', forwarded(good))
        leaked = good.replace('return localized(context, en, tr);',
                              'return localized(context, tr, en);')
        self.assertNotIn('Gitar adı', forwarded(leaked))
        direct = good + "\nString raw(String id) => _names[id]!;"
        self.assertNotIn('Gitar adı', forwarded(direct))


class MessageIdMapTests(unittest.TestCase):
    source = ('const appMessageIds = <(String, String), String>{\n'
              '  ("Play\\nnow", "Çal\\nşimdi"): "0123456789abcdef",\n};\n'
              'const appMessagePlaceholders = <String, Map<String, int>>{\n'
              '  "0123456789abcdef": {"v0": 1},\n};\n'
              'const appMessagePluralSources = <String, Map<String, String>>{\n'
              '  "0123456789abcdef": {"enOne": "{v0} day", "trOne": "{v0} gün"},\n};\n')

    def test_generated_map_structure_is_read_with_unescaped_values(self):
        result = message_id_map(self.source)
        self.assertEqual(result['keys'], [(2, 'Play\nnow', 'Çal\nşimdi')])
        self.assertEqual(result['plural'], [(8, '{v0} day', '{v0} gün')])

    def test_any_other_code_or_entry_shape_is_not_a_key_map(self):
        for broken in [self.source + "String leak() => 'Sızıntı';",
                       self.source.replace('"Çal\\nşimdi"', '"Çal${x}"'),
                       self.source.replace('"0123456789abcdef",\n}', '"zz",\n}', 1),
                       self.source.replace('): "0123456789abcdef"', ', "x"): "0123456789abcdef"', 1)]:
            self.assertIsNone(message_id_map(broken))


class PreferencePayloadTests(unittest.TestCase):
    locale = """Future<void> write(String? languageTag) async {
    if (languageTag != null && !supportedLanguageTags.contains(languageTag)) {
      throw ArgumentError.value(languageTag, 'languageTag');
    }
    await pending.writeAsString(
      jsonEncode({'schemaVersion': 1, 'languageTag': languageTag}),
      flush: true,
    );
  }"""
    theme = """enum AppThemePreference { system, light, dark }
  Future<void> write(AppThemePreference preference) async {
    await pending.writeAsString(
      jsonEncode({'schemaVersion': 1, 'mode': preference.name}),
      flush: true,
    );
  }"""

    def test_locale_and_theme_payloads_are_preferences(self):
        self.assertEqual(preference_payload_role(self.locale), 'locale')
        self.assertEqual(preference_payload_role(self.theme), 'theme')

    age = """Future<void> markBlocked() async {
    await pending.writeAsString(
      jsonEncode({'schemaVersion': 1, 'blocked': true}),
      flush: true,
    );
  }"""

    def test_age_gate_marker_is_a_fixed_fact(self):
        self.assertEqual(preference_payload_role(self.age), 'age_gate')
        for broken in [self.age.replace("'blocked': true", "'blocked': birthYear"),
                       self.age.replace('markBlocked()', 'markBlocked(int birthYear)'),
                       self.age.replace("'blocked': true", "'birthMonth': true")]:
            self.assertIsNone(preference_payload_role(broken), broken[:60])

    def test_measurement_like_or_unproven_payloads_stay_writers(self):
        for broken in [
                self.locale.replace("'languageTag': languageTag", "'history': languageTag"),
                self.locale.replace("if (languageTag != null", "if (false"),
                self.locale.replace("String? languageTag", "String? languageTag, List<double> a")
                    .replace("'languageTag': languageTag", "'languageTag': a"),
                self.locale + "\nawait File('a').writeAsBytes(bytes);",
                self.theme.replace("dark }", "dark, angles }"),
                self.theme.replace("preference.name", "rawSamples"),
                self.theme.replace("flush: true,", "")]:
            self.assertIsNone(preference_payload_role(broken), broken[-80:])


GUITAR = """final class GuitarText {
  const GuitarText(this.en, this.tr, {this.values = const {}});
  final String en;
  final String tr;
  final Map<String, Object?> values;
  String of(BuildContext context) => localized(context, en, tr, values: values);
  factory GuitarText.fromJson(Map<String, dynamic> json) =>
      GuitarText(json['en'] as String, json['tr'] as String);
}"""


class ForwardedGuitarTextTests(unittest.TestCase):
    use = ("import '../guitar_journey.dart' show GuitarText;\n"
           "final a = GuitarText('Bar {v0}', 'Ölçü {v0}', values: {'v0': 1});\n"
           "final b = GuitarText('Wrong', 'Yanlış ölçü', other: 1);\n"
           "final c = fail('piece title.tr');")

    def contexts(self, use, guitar=GUITAR):
        return forwarded(use, extra={'lib/app/guitar_journey.dart': guitar})

    def test_values_named_argument_is_the_only_extra(self):
        result = self.contexts(self.use)
        self.assertIn('Ölçü {v0}', result)
        self.assertNotIn('Yanlış ölçü', result)

    def test_direct_tr_read_in_code_disables_the_guard(self):
        self.assertNotIn('Ölçü {v0}', self.contexts(self.use + "\nString leak(GuitarText t) => t.tr;"))

    def test_changed_of_dispatch_disables_the_guard(self):
        broken = GUITAR.replace('localized(context, en, tr, values: values)',
                                'localized(context, tr, en, values: values)')
        self.assertNotIn('Ölçü {v0}', self.contexts(self.use, broken))


class CatalogParityTests(unittest.TestCase):
    def test_en_tr_catalog_values_must_equal_the_key_sides(self):
        id_map = message_id_map(MessageIdMapTests.source)
        good = {'messages': {'0123456789abcdef': {'one': '{v0} day', 'other': 'Play\nnow'}}}
        self.assertEqual(catalog_parity(good, 0, id_map), ([], [], []))
        drifted = {'messages': {'0123456789abcdef': 'Play later', 'ffffffffffffffff': 'x'}}
        mismatched, missing, unknown = catalog_parity(drifted, 0, id_map)
        self.assertEqual((mismatched, missing, unknown), (['0123456789abcdef'], [], ['ffffffffffffffff']))
        self.assertEqual(catalog_parity({'messages': {}}, 1, id_map)[1], ['0123456789abcdef'])


gate_json_original = gate.json_surface_strings

if __name__ == '__main__':
    unittest.main()
