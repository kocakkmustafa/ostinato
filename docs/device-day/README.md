# Cihaz günü paketi (OST-DEV-DAY-PREP)

Tarih: 2026-11-18 · Durum: **HAZIRLIK (yalnız belge + betik)**; gün yapılmadı, hiçbir hücrede ölçülmüş sonuç yoktur · Güncel reçete bu klasördür; eski `RECIPE.md` tarihsel kalır.

Amaç: yeni ekranları (bayrakları) açmanın ön şartı olan gerçek cihaz kanıtlarını tek oturumda toplamak. Bayrak açma kararı bu belgenin işi değildir; gün bitince Motion orchestration kurucuya yeniden sorar. Marka metinlerde "Yula Lab".

## Dosya haritası

| Dosya | Bilet | İçerik |
|---|---|---|
| [`CIHAZ-TABLOSU.md`](CIHAZ-TABLOSU.md) | QA-OST-02 | 5 cihaz kayıt tablosu şablonu |
| [`TUR-LISTESI.md`](TUR-LISTESI.md) | QA-OST-02 | Her cihazda aynı 6 adımlık tur, ekran/dosya eşlemesi |
| [`FLAG-21-OLCUM.md`](FLAG-21-OLCUM.md) | FLAG #21 | Kare süresi, bulanık katman, mikrofon izni reddi → "Başlat" |
| [`FLAG-22-EKRAN-OKUYUCU.md`](FLAG-22-EKRAN-OKUYUCU.md) | FLAG #22 | VoiceOver / TalkBack kontrol listesi |
| [`SEC-OST-01-YAKALAMA.md`](SEC-OST-01-YAKALAMA.md) | SEC-OST-01 | mitmproxy ağ yakalama tarifi + rapor şablonu; betik `tools/har_audio_check.py` |
| [`CORPUS-PROTOKOL.md`](CORPUS-PROTOKOL.md) | QA-OST-01 | Gerçek kayıt corpus'u, adlandırma, rapor şablonu, kuru koşu kanıtı |
| [`PROFIL-DERLEME.md`](PROFIL-DERLEME.md) | ön hazırlık 4 | iPhone profil kurulumu, Android profil APK, ENGEL listesi; §6 cihaz günü iki derleme (bayraklar kapalı/açık), donma notu |

## Gün akışı (≈2,5 saat; 2-3 cihaz için, 5 cihazda ≈3 saat)

0. Hazırlık: 22 Kas 12:00 main donar; 13:30'a dek iki profil derlemesi hazır ([`PROFIL-DERLEME.md`](PROFIL-DERLEME.md) §6).
1. Kurulum (20 dk): [`PROFIL-DERLEME.md`](PROFIL-DERLEME.md); yakalama sertifikası telefona kurulur ([`SEC-OST-01-YAKALAMA.md`](SEC-OST-01-YAKALAMA.md)).
2. Cihaz turu (cihaz başına ≈15 dk): [`TUR-LISTESI.md`](TUR-LISTESI.md); sonuçlar [`CIHAZ-TABLOSU.md`](CIHAZ-TABLOSU.md)'na; kare süresi ve izin reddi [`FLAG-21-OLCUM.md`](FLAG-21-OLCUM.md) yöntemiyle.
3. Ağ yakalama (20 dk, cihaz 1): SEC-OST-01.
4. Corpus kaydı (40 dk): [`CORPUS-PROTOKOL.md`](CORPUS-PROTOKOL.md).
5. Ekran okuyucu (20 dk): [`FLAG-22-EKRAN-OKUYUCU.md`](FLAG-22-EKRAN-OKUYUCU.md).
6. Kapanış (10 dk): tablo + açık bulgular; ertesi gün Ostinato raporları yazar.

## Gün öncesi karar gerektirenler (ayrıntı ilgili belgede)

- **K1, bayraklar:** `lib/app/ostinato_release_policy.dart` içindeki yeni yüzey bayrakları (`ostinatoFirstThreeMinutesOpen`, `ostinatoStageHomeEnabled`, `ostinatoListenTryFixRepeatOpen`, `ostinatoGhostScreenOpen`) `const bool` ve **kapalıdır**; yalnız `ostinatoStageHomeEnabled` ile `ostinatoGhostScreenOpen` cihaz günü profil derlemesinde `--dart-define` ile açılır, mağaza derlemesinde asla ([`PROFIL-DERLEME.md`](PROFIL-DERLEME.md) §6). Diğer ikisi kapalı kalır; kapalı derlemede tur adımlarının bir kısmı (ör. ilk üç dakika) görünmez.
- **K2, imza/hesap adımları** [`PROFIL-DERLEME.md`](PROFIL-DERLEME.md) §5'te kimin yapacağıyla işaretlidir.

## Kapsam dışı

Bu paket yeni uygulama ya da araç kurmaz, ücretli araç kullanmaz, sır okumaz, kullanıcıya dönük dizge eklemez.
