import 'dart:async';

import 'package:flutter/material.dart';

import 'app_locale.dart';
import 'app_theme_preferences.dart';

/// Reuses only the nine reviewed theme source pairs. Put inside the existing
/// Settings route; do not recreate an app, Navigator or resource owner here.
final class AppAppearancePicker extends StatelessWidget {
  const AppAppearancePicker({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = AppThemeScope.maybeOf(context);
    if (controller == null) return const SizedBox.shrink();
    final status = controller.loading
        ? localized(context, 'Loading appearance…', 'Görünüm yükleniyor…')
        : controller.readFailed
        ? localized(context,
            'Theme preference could not be loaded. System appearance is in use.',
            'Tema tercihi yüklenemedi. Sistem görünümü kullanılıyor.')
        : controller.writeFailed
        ? localized(context,
            'Theme changed on this device, but could not be saved. Choose again to retry.',
            'Tema bu cihazda değişti ancak kaydedilemedi. Yeniden denemek için tekrar seç.')
        : controller.saving
        ? localized(context, 'Saving theme preference…', 'Tema tercihi kaydediliyor…')
        : controller.hasSavedSelection
        ? localized(context, 'Theme preference saved on this device.', 'Tema tercihi bu cihazda kaydedildi.')
        : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        InputDecorator(
          decoration: InputDecoration(labelText: localized(context, 'Theme', 'Tema')),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<AppThemePreference>(
                value: controller.preference,
                isExpanded: true,
                items: [
                  DropdownMenuItem(value: AppThemePreference.system,
                    child: Text(localized(context, 'System', 'Sistem'))),
                  DropdownMenuItem(value: AppThemePreference.light,
                    child: Text(localized(context, 'Light', 'Açık'))),
                  DropdownMenuItem(value: AppThemePreference.dark,
                    child: Text(localized(context, 'Dark', 'Koyu'))),
                ],
                onChanged: controller.loading ? null : (value) {
                  if (value != null) unawaited(controller.select(value));
                },
              ),
            ),
          ),
        ),
        if (status != null) ...[
          const SizedBox(height: 8),
          Semantics(liveRegion: true, child: Text(status)),
        ],
      ],
    );
  }
}
