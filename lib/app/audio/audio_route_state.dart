import 'package:ostinato_audio/ostinato_audio.dart';

/// Native tarafın kanaldan gönderdiği ÖZ-TANIMLI route etiketini
/// [AudioRoute]e çevirir. Girdi biçimi `"<platform>:<hamAd>"` — ör.
/// `"ios:BluetoothHFP"`, `"android:TYPE_BLUETOOTH_SCO"`.
///
/// **Neden `Platform.isIOS` DEĞİL de etiketin kendisi platformu taşıyor:**
/// ilk tasarım host-platformuna bakıyordu (`dart:io Platform.isIOS`), ama bu
/// `flutter test`i macOS'ta koşan HER geliştirme makinesinde SESSİZCE yanlış
/// dala düşürürdü (`Platform.isIOS`/`isAndroid` ikisi de false — host macOS)
/// — route-eşleme testleri gerçek cihazsız hiç YAZILAMAZDI. Etiketin kendi
/// öneki taşıması, hangi native kaynaktan geldiğini AMBIENT bir global'e
/// değil KENDİ verisine bağlar; `AudioCaptureChannel` testte de üretimde de
/// aynı fonksiyonu çağırır.
///
/// Neden native'in kendisi anlamlı bir [AudioRoute] DEĞİL ham etiket
/// gönderiyor: "kabuk yalnız kablolama" sınırı (Gravita G-100,
/// `ostinato_posture` + `CameraPostureAdapter` ile aynı disiplin) — eşleme
/// bir HÜKÜMdür (hangi platform port'u hangi latency sınıfına girer) ve
/// hüküm test edilebilir Dart'ta yaşamalı.
///
/// Tanınmayan HER etiket [AudioRoute.unknown]e düşer — tahmin YOK. Roadmap
/// §7 madde 2 gereği `unknown` de tıpkı bilinen route'lar gibi
/// `AudioCalibrating`i tetikler; yalnız hangi latency sınıfına girdiği
/// bilinmediği için `AudioStreaming`e asla terfi ETMEZ (bu dosyanın kapsamı
/// dışında: terfi kararı `AudioInputController`de).
AudioRoute mapPlatformRouteTag(String tag) {
  final int sep = tag.indexOf(':');
  if (sep < 0) return AudioRoute.unknown;
  final String platform = tag.substring(0, sep);
  final String raw = tag.substring(sep + 1);
  switch (platform) {
    case 'ios':
      return mapIosPortType(raw);
    case 'android':
      return mapAndroidDeviceType(raw);
    default:
      return AudioRoute.unknown;
  }
}

AudioRoute mapIosPortType(String rawPortType) {
  switch (rawPortType) {
    case 'Speaker':
    case 'Receiver':
    case 'BuiltInMic':
    case 'MicrophoneBuiltIn':
      return AudioRoute.speaker;
    case 'Headphones':
    case 'HeadsetMic':
    // Raw `AVAudioSession.Port.headsetMic` — what the capture tag sends.
    case 'MicrophoneWired':
    case 'LineIn':
    case 'LineOut':
      return AudioRoute.wiredHeadset;
    case 'BluetoothHFP':
    case 'BluetoothA2DP':
    case 'BluetoothLE':
      return AudioRoute.bluetooth;
    case 'USBAudio':
      return AudioRoute.usbOrOther;
    default:
      return AudioRoute.unknown;
  }
}

/// Android `AudioDeviceInfo.getType()` sabitlerinin ADLARI (int değeri
/// DEĞİL — platform kanalı üstünden isim taşımak, sabit numaralar kayarsa
/// SESSİZCE yanlış eşlemeyi önler; bkz. `AudioCaptureStreamer.kt`).
AudioRoute mapAndroidDeviceType(String rawTypeName) {
  switch (rawTypeName) {
    case 'TYPE_BUILTIN_MIC':
    case 'TYPE_BUILTIN_SPEAKER':
    case 'TYPE_BUILTIN_EARPIECE':
      return AudioRoute.speaker;
    case 'TYPE_WIRED_HEADSET':
    case 'TYPE_WIRED_HEADPHONES':
      return AudioRoute.wiredHeadset;
    case 'TYPE_BLUETOOTH_SCO':
    case 'TYPE_BLUETOOTH_A2DP':
    case 'TYPE_BLE_HEADSET':
    case 'TYPE_BLE_SPEAKER':
      return AudioRoute.bluetooth;
    case 'TYPE_USB_DEVICE':
    case 'TYPE_USB_HEADSET':
    case 'TYPE_USB_ACCESSORY':
      return AudioRoute.usbOrOther;
    default:
      return AudioRoute.unknown;
  }
}
