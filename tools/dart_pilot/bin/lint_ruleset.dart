import 'dart:io';

import 'package:motion_core/motion_core.dart';

/// `voice@0.1.0-draft`ı mühürlü şemanın KATI okuyucusundan geçirir.
///
/// Bu config, şema v3.0 mühürlendikten sonra yazılan ilk gerçek config; bu da
/// onu linter'ın ilk gerçek müşterisi yapıyor. Amaç "yeşil almak" değil:
/// okuyucu ile config arasındaki her ayrışma ya bende bir hata ya şemada bir
/// boşluk demek, ikisi de raporlanmaya değer.
void main(List<String> args) {
  final path = args.isEmpty ? '../../config/rulesets/voice@0.1.0-draft.json' : args.first;
  final raw = File(path).readAsStringSync();

  PhaseConfig config;
  try {
    config = const PhaseConfigParser().parseJson(raw);
  } on PhaseConfigError catch (e) {
    stdout.writeln('❌ PARSE HATASI');
    stdout.writeln('   konum : ${e.path}');
    stdout.writeln('   mesaj : ${e.message}');
    exit(2);
  } catch (e) {
    stdout.writeln('❌ PARSE İSTİSNASI: $e');
    exit(2);
  }

  stdout.writeln('✅ parse geçti — ${config.techniques.length} teknik, '
      '${config.metrics.length} metrik');

  final issues = const PhaseConfigValidator().validate(config);
  if (issues.isEmpty) {
    stdout.writeln('✅ doğrulayıcı TEMİZ (aile değişmezleri)');
    exit(0);
  }
  stdout.writeln('\n⚠️ ${issues.length} ihlal:');
  for (final i in issues) {
    stdout.writeln('  - $i');
  }
  exit(1);
}
