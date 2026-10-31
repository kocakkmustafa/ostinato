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
