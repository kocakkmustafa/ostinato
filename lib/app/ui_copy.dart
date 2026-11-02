import 'package:flutter/widgets.dart';

import 'app_locale.dart';

/// A reviewed EN/TR source pair. Its message id is sha256(en + "\0" + tr)
/// (`tool/build_message_ids.py`); until the other twelve catalogs carry the
/// id, [uiText] falls back to the English source outside Turkish.
typedef UiCopy = (String en, String tr);

String uiText(
  BuildContext context,
  UiCopy copy, {
  Map<String, Object?> values = const {},
}) => localized(context, copy.$1, copy.$2, values: values);

/// Joins two already localized sentences: Chinese and Japanese sentences
/// follow each other without a space.
String joinSentences(BuildContext context, String first, String second) {
  final language = Localizations.maybeLocaleOf(context)?.languageCode;
  final gap = language == 'ja' || language == 'zh' ? '' : ' ';
  return '$first$gap$second';
}
