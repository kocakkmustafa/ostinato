import 'package:flutter/widgets.dart';
import 'package:ostinato_posture/ostinato_posture.dart';

import '../content.dart';
import '../cue_text.dart';

/// Uygulama-geneli erişim: içerik deposu + gözlem-işareti çözücüsü.
///
/// Yalnız KABLOLAMA — her ekran constructor'ında `repo`+`cueText` taşımak
/// yerine tek bir InheritedWidget. Hiçbir hüküm taşımaz, yalnız zaten var
/// olan iki nesneye erişim verir.
class ContentRepositoryScope extends InheritedWidget {
  const ContentRepositoryScope({
    super.key,
    required this.repo,
    required this.cueText,
    required super.child,
  });

  final ContentRepository repo;
  final CueTextResolver cueText;

  static ContentRepositoryScope of(BuildContext context) {
    final ContentRepositoryScope? scope =
        context.dependOnInheritedWidgetOfExactType<ContentRepositoryScope>();
    assert(scope != null, 'ContentRepositoryScope bulunamadı — ağacın kökünde yok');
    return scope!;
  }

  PostureContract? contractOrNull(String instrument) =>
      repo.contractOrNull(instrument);

  @override
  bool updateShouldNotify(ContentRepositoryScope oldWidget) =>
      repo != oldWidget.repo || cueText != oldWidget.cueText;
}
