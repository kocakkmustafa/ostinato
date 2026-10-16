# Ostinato — onaylı native simge, 16 Ekim 2026

Onay sürümü: `original-unchanged`. `master.png`, onay registry'sindeki
kaynakla byte eşidir: SHA-256 `6db03e9cdc6da965fc88ed28e6fd7f78aedf02a5d3fe4927bacffdd6b6a57b73`.

Mevcut iOS `AppIcon` kataloğundaki 19 kayıt / 15 benzersiz PNG ve Android
`@mipmap/ic_launcher` kaynağının 5 yoğunluk PNG'si doğrulandı. 19 PNG bu
masterdan doğrudan LANCZOS ile yenilendi; mevcut iOS 1024 PNG onaylı masterla
zaten byte eşiydi ve korunmuştur. Kare çerçeve ve RGB renk örnekleri korunur; kırpma, ek inset, yeniden
çizim, renk dönüşümü ve dosyaya gömülü köşe maskesi yoktur. Küçültülen PNG'lere
sRGB etiketi eklenir; alfa yoktur. Platform maskeleri OS tarafından uygulanır.

Dosya başına boyut, SHA-256, önceki SHA-256 ve başlangıç commit'i
[`manifest.json`](manifest.json) içindedir. Üretim, kurulu Pillow ve mevcut
`tools/uret_ikon_launch.py` (Lissom) içindeki native boyut/LANCZOS tarifini
kullanır; eski kaynak seçimi ve launch döngüsü çalıştırılmaz.

Tekrar üretmek için repo kökünden mevcut Pillow ile, bu manifestteki her
`assets` kaydı için aşağıdaki işlemi uygulayın:

```python
import json, shutil
from pathlib import Path
from PIL import Image, PngImagePlugin
m = json.loads(Path("docs/design/icon/approved-2026-10-16/manifest.json").read_text())
source = Path(m["master"]["path"])
tag = PngImagePlugin.PngInfo()
tag.add(b"sRGB", b"\x00")
with Image.open(source) as image:
    for asset in m["assets"]:
        size = tuple(asset["dimensions"])
        if image.size == size:
            shutil.copyfile(source, asset["path"])
        else:
            image.resize(size, Image.Resampling.LANCZOS).save(asset["path"], pnginfo=tag)
```

Ana ürünün iOS ve Android dışında shipping platform hedefi yoktur. Android'de
adaptive XML veya ayrı round icon yoktur; mevcut legacy launcher yapısı korunur.
Ostinato'nun üçüncü parti örnekleri ve `tools/midi_spike/macos` ürün hedefi değildir.

Görsel kontrol: 180/120/60/48 px simgeler ile örnek yuvarlak/yuvarlatılmış OS
maskelerinde ana figür korunur; tam kare kaynak kaybı yoktur. Bu, kaynak/asset
kontrolüdür; gerçek launcher veya native kurulum kabulü değildir.

Eski adaylar ve kullanıcı görselleri tarihsel olarak korunmuştur. LaunchImage
ve splash kaynakları ayrı görsellerdir. Yeni simge entegrasyonu mağaza ekran
görüntülerinin veya mağaza görsellerinin hazır olduğu anlamına gelmez.
Build/simülatör, push/PR/CI ve mağaza yüklemesi bu çalışmada yapılmadı.

Odaklı kontroller: 20 PNG boyutu/PNG bütünlüğü/SHA-256/RGB/alfasızlık/sRGB ve
masterdan piksel eşliği PASS; 19 iOS katalog kaydı ve Android launcher
bağlantısı PASS. Ayrıntılı kontrol sonuçları manifesttedir.
