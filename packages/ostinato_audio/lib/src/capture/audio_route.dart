/// Fiziksel giriş yolu — hoparlör/dahili mic ile kablolu/Bluetooth ayrı
/// latency sınıfları taşır (roadmap §7 + §11: "kalibre edilmiş Bluetooth
/// ≤60ms" ama hoparlör/kablolu ≤30ms — TEK eşik ikisini de yanlış ölçer).
///
/// `unknown` İSİMLİ bir hâldir, "bluetooth sanıyorum" DEĞİL — platform route
/// bilgisini çözemediğinde buraya düşer ve `AudioCalibrating` kapısından asla
/// çıkmaz (motion_camera `ClockDomain.unknown` deseniyle aynı disiplin:
/// beyan ≠ canlı, ölçülemeyen adıyla ölçülemez kalır).
enum AudioRoute { speaker, wiredHeadset, bluetooth, usbOrOther, unknown }
