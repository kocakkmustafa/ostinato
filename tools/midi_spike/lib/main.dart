import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_midi_command/flutter_midi_command.dart';
import 'package:flutter_midi_command/flutter_midi_command_messages.dart';

/// İKİNCİ İŞ (2026-07-29 gece devri) — MIDI modu spike'ı.
///
/// Amaç: `flutter_midi_command`in cihaz keşfi + gecikme ölçümü gerçekten
/// çalışıyor mu, macOS'ta (bu makinede fiziksel MIDI donanımı YOK) kaç
/// numarayı ÖLÇEBİLİYORUZ? Sentetik veri yerine (M-O-24/O-019 dersi) gerçek
/// motoru gerçek bir MIDI yoldan geçiriyoruz: kendi sanal cihazımızı
/// oluşturup ona bağlanıp, gönderdiğimiz notanın `onMidiDataReceived`
/// zaman damgasıyla geri dönüşünü ölçüyoruz. Bu YAZILIM/veri-yolu gecikmesi
/// — gerçek USB/BLE klavye donanım gecikmesi DEĞİL; ikisi karıştırılmaz.
///
/// Atılabilir araç: `tools/dart_pilot` gibi, `motion_shell` platform
/// iskeletinin (M-F-25, JabLab pilotu) yerine geçmez.
void main() {
  runApp(const MidiSpikeApp());
}

class MidiSpikeApp extends StatelessWidget {
  const MidiSpikeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ostinato — MIDI spike',
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo)),
      home: const SpikePage(),
    );
  }
}

class SpikePage extends StatefulWidget {
  const SpikePage({super.key});

  @override
  State<SpikePage> createState() => _SpikePageState();
}

class _SpikePageState extends State<SpikePage> {
  final MidiCommand _midi = MidiCommand();
  final List<String> _log = [];
  StreamSubscription<MidiDataReceivedEvent>? _rxSub;
  StreamSubscription<MidiSetupChange>? _setupSub;
  bool _running = false;

  void _print(String line) {
    // Konsola da basılır: `flutter run -d macos` çıktısından okunabilir,
    // GUI etkileşimi gerekmez.
    // ignore: avoid_print
    print(line);
    if (mounted) setState(() => _log.add(line));
  }

  @override
  void initState() {
    super.initState();
    _setupSub = _midi.onMidiSetupChanged?.listen((c) => _print('[setup] $c'));
    _rxSub = _midi.onMidiDataReceived?.listen((e) {
      final localUs = DateTime.now().microsecondsSinceEpoch;
      _print('[rx] dev=${e.device.name} transport=${e.transport} '
          'pluginTs=${e.timestamp} localUs=$localUs msg=${e.message}');
      final started = _pendingSendUs;
      if (started != null && e.message is NoteOnMessage) {
        final deltaMs = (localUs - started) / 1000.0;
        _print('[loopback] gönderim→alım gecikmesi: ${deltaMs.toStringAsFixed(2)} ms');
        _pendingSendUs = null;
      }
    });
    // Otomatik koş — manuel tıklama gerekmesin, çıktı log'a düşsün.
    WidgetsBinding.instance.addPostFrameCallback((_) => _runSpike());
  }

  int? _pendingSendUs;

  Future<void> _runSpike() async {
    if (_running) return;
    _running = true;
    _print('=== Ostinato MIDI spike — ${DateTime.now().toIso8601String()} ===');

    // BLE bilinçli olarak DIŞARIDA: bu makinede fiziksel BLE MIDI donanımı
    // yok, ayrı `flutter_midi_command_ble` paketi + izin akışı gerektirir.
    // Takip işi olarak kayda geçti (bkz. DEFTER).
    _midi.configureBleTransport(null);
    _midi.configureTransportPolicy(
      const MidiTransportPolicy(excludedTransports: {MidiTransport.ble}),
    );

    final before = await _midi.devices ?? const <MidiDevice>[];
    _print('1) Fiziksel/mevcut cihaz taraması: ${before.length} cihaz');
    for (final d in before) {
      _print('   - ${d.name} (${d.id}) type=${d.type} '
          'in=${d.inputPorts.length} out=${d.outputPorts.length}');
    }

    _print('2) Kendi sanal MIDI kaynağımızı oluşturuyoruz (addVirtualDevice)…');
    try {
      _midi.addVirtualDevice(name: 'Ostinato Spike');
    } catch (e) {
      _print('   ⛔ addVirtualDevice patladı: $e');
    }

    // CoreMIDI/ALSA bildirimi asenkron gelebilir; setup-changed olayını da
    // dinliyoruz ama sabit bir üst sınır da koyuyoruz (kapı: sonsuz beklemez).
    await Future<void>.delayed(const Duration(milliseconds: 800));

    final after = await _midi.devices ?? const <MidiDevice>[];
    _print('3) Sanal cihaz sonrası tarama: ${after.length} cihaz');
    for (final d in after) {
      _print('   - ${d.name} (${d.id}) type=${d.type} '
          'in=${d.inputPorts.length} out=${d.outputPorts.length}');
    }

    final ownVirtual = after.where((d) =>
        d.type == MidiDeviceType.ownVirtual || d.name.contains('Ostinato Spike'));
    if (ownVirtual.isEmpty) {
      _print('4) ⛔ Sanal cihaz kendi tarama listemizde GÖRÜNMÜYOR — '
          'macOS bu süreçte kendi sanal kaynağını "dışarıdan gelen cihaz" '
          'olarak listelemiyor olabilir (CoreMIDI: kendi MIDISourceCreate\'i '
          'geri-taramada görünmez, bu BEKLENEN bir sınır, dedektör kusuru '
          'DEĞİL). Loopback gecikme testi bu yoldan KOŞULAMIYOR.');
      _print('   → Gerçek gecikme ölçümü için fiziksel MIDI cihazı (USB veya '
          'BLE klavye/kontrolcü) veya harici bir loopback yardımcı '
          '(ör. macOS IAC Driver + ikinci bir MIDI istemcisi) gerekiyor.');
    } else {
      final dev = ownVirtual.first;
      _print('4) Sanal cihaz görünür: ${dev.name} — bağlanılıyor…');
      try {
        await _midi.connectToDevice(dev);
        _print('   ✅ bağlandı, test notası gönderiliyor (NoteOn ch0 note60)…');
        _pendingSendUs = DateTime.now().microsecondsSinceEpoch;
        _midi.sendData(
          NoteOnMessage(channel: 0, note: 60, velocity: 100).generateData(),
          deviceId: dev.id,
        );
        await Future<void>.delayed(const Duration(milliseconds: 500));
        if (_pendingSendUs != null) {
          _print('   ⚠️ 500ms içinde `onMidiDataReceived` ateşlenmedi — '
              'loopback bu yoldan tamamlanmadı.');
        }
      } catch (e) {
        _print('   ⛔ bağlantı/gönderim hatası: $e');
      }
    }

    _print('=== spike bitti ===');
    _running = false;
  }

  @override
  void dispose() {
    _rxSub?.cancel();
    _setupSub?.cancel();
    _midi.removeVirtualDevice(name: 'Ostinato Spike');
    _midi.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ostinato — MIDI spike (M-O-34 devamı)')),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FilledButton(
              onPressed: _running ? null : () { setState(_log.clear); _runSpike(); },
              child: Text(_running ? 'çalışıyor…' : 'yeniden koş'),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: _log.length,
                itemBuilder: (context, i) => Text(
                  _log[i],
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
