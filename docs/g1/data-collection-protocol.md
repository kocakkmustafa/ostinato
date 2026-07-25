# Ostinato G1-A — Çello+Yay Algılama Veri Toplama Protokolü (v1)

**Tarih:** 2026-07-26 · **Statü:** TASARIM — kurucu onayı bekliyor (D3 kapı çıktısının A parçası)
**Bağlayıcı girdiler:** `ostinato-plan.md` §12 (çeşitlilik) + §13 (gizlilik/çocuk rejimi) · motion-core `10-ARAC-KATALOGU.md` §3 (2-keypoint yay kararı) + §6 (fixture şeması) · roadmap G1-A.
**Amaç:** MediaPipe Object Detector + Model Maker transfer-learning turlarını besleyecek, lisansı %100 bize ait, çeşitlilik-kontrollü, rıza-temiz çello+yay görüntü veri seti üretme reçetesi. **Bu doküman kod içermez; kabulünden sonra çekimler kurucu koordinasyonuyla başlar.**

---

## 1. Hedef sınıflar ve etiket şeması

### 1.1 Nesne sınıfları (plan §6.3)

| Sınıf | Etiket türü | Not |
|---|---|---|
| `cello_body` | bbox | Gövde + boyun dahil, yay hariç |
| `fingerboard` | bbox | Klavye; sol el örtüşmesi normaldir, yine etiketle |
| `bridge_region` | bbox | Köprü + ~1 yay-genişliği çevresi (yay-bölge metriğinin referansı) |
| `bow` | **2 keypoint: `bow_tip` + `bow_frog`** + tamamlayıcı bbox | Katalog §3 kararı: ince/hızlı nesne → hat modeli. Bbox'ı DA etiketliyoruz ki hem detector (Model Maker bbox-tabanlı) hem keypoint yaklaşımı aynı setten eğitilebilsin — iki mimariyi tek veri turuyla karşılaştırma opsiyonu (ileriye-dönük mimari ilkesi). |
| `bow_hand` | bbox | Sağ el (yay tutuşu) |
| `left_hand` | bbox | Sol el (klavye üstü) |

**Karar (D-kaydı DEFTER'e):** Yay için bbox+2-keypoint SÜPERSET etiketleme. Maliyet artışı ≈ kare başına +2 tık; kazanç = mimari A/B özgürlüğü. Occlusion durumunda görünen uç etiketlenir, görünmeyene `occluded` bayrağı.

### 1.2 Kare-düzeyi ek etiketler

- `bow_direction`: `down | up | stationary | not_visible` (state-machine eğitim/eval'i için)
- `technique_phase`: uzun-yay fazları `READY | BOW_CONTACT | DOWN_BOW | DIRECTION_CHANGE | UP_BOW | COMPLETE` (plan §9) — yalnız "teknik klipleri"nde zorunlu
- `error_code`: pedagoji taksonomisinden (G0 pedagoji kütüphanesi çıktısı; ör. `E-BOW-SKEW`, `E-SHOULDER-RAISE` — nihai kodlar o dokümandan gelir) — yalnız sahnelenmiş-hata kliplerinde
- `annotator_confidence`: `high | medium | low` (uzman-güveni alanı, plan §12)
- Klip-düzeyi: `validity` — `clean | adversarial` (kasıtlı bozucu koşul: arka plan çizgileri, düşük ışık, kadraj kaçığı — plan §9 geçersiz-durum eğitim örnekleri)

### 1.3 Manifest şeması (motion-core fixture sözleşmesiyle kardeş — katalog §6)

```json
{
  "schemaVersion": "ostinato-ds-1",
  "clipId": "OST-2026xxxx-###",
  "recordingMeta": {
    "device": "iPhone 14 | Redmi Note 12 | ...",
    "resolution": "1920x1080", "fps": 30,
    "lighting": "daylight|lamp|dim",
    "cameraSetup": "standard-right-front|adversarial-...",
    "background": "plain|bookshelf|curtain|line-rich",
    "roomAudio": "quiet|reverberant|noisy"
  },
  "subject": {
    "ageBand": "child-8-12|teen|adult", "consentId": "C-###",
    "celloSize": "4/4|3/4|1/2|1/4", "skill": "beginner|intermediate|teacher",
    "clothing": "dark|light|patterned", "sleeve": "long|short"
  },
  "content": { "exercise": "open-string-long-bow|...", "staged": true, "errorCodes": ["E-..."] },
  "labels": "clipId.labels.json"
}
```

## 2. Çekim standardı

- **Açı:** V1 standart açı — hafif sağ-ön çapraz (plan §6.4): kamera, çalanın sağ-ön çaprazında ~30-45°, mesafe 2.5-3.5m, lens yüksekliği oturan çalanın göğüs hizası (~90-110cm tripod). Gövde + çello tamamı + yayın TÜM stroku + sandalye/ayaklar kadrajda.
- **Format:** en az 1080p30; cihaz destekliyorsa 4K30 çek (etiketçi zoom'u için), teslim 1080p. Sabit pozlama/odak kilidi AÇIK (AE/AF kilidi — ışık dalgalanması etiket kalitesini bozar). Telefon SABİT (tripod/sehpa; el YOK).
- **Klip uzunluğu:** 20-60sn; her klip TEK egzersiz/tek koşul (çeşitlilik matrisi hücresine haritalanır).
- **Ses:** video sesi AÇIK kalır (ileride audio-motion senkron fixture'ı aynı kayıttan türetilebilir — tek çekim çift kullanım). Oda sessiz olmak zorunda değil; `roomAudio` alanına yaz.
- **Adversarial klipler:** toplamın ~%15'i — kasıtlı: arka planda çizgili nesneler (perde çubuğu, kitaplık rafı, süpürge sapı!), loş ışık, kadraj kaçığı, kamera hafif titreşimi. Bunlar "geçersiz durum" sınıflandırıcısının (plan §9) eğitim gerçeğidir; temiz set ile KARIŞTIRILMAZ (`validity: adversarial`).

## 3. Çeşitlilik matrisi ve hedef hacim (plan §12)

**Faz-1 hedefi (Model Maker ilk transfer-learning turu):** ~60 klip ≈ 25-40dk ham görüntü → 1-2fps örnekleme → **~3.000-4.500 etiketli kare** (sınıf başına ≥800 örnek). Faz-2 (model zayıflıkları görülünce) hedefli +40 klip.

| Boyut | Hedef dağılım (60 klip içinde) |
|---|---|
| Çello boyu | 4/4 ×30 · 3/4 ×12 · 1/2 ×12 · 1/4 ×6 (çocuk boyları toplamın yarısı — hedef kitle gerçeği) |
| Yaş bandı | yetişkin ×24 · genç ×18 · çocuk(8-12) ×18 (çocuk klipleri = ebeveyn-rızalı, §5) |
| Teknik içerik | doğru teknik ×30 · sahnelenmiş-hata ×21 (taksonomiden ≥7 hata × ≥3 tekrar) · serbest pratik ×9 |
| Kıyafet | koyu ×20 · açık ×20 · desenli ×12 · uzun-kollu zorunlu ≥15 (bilek landmark'ı zorlaşır — bilinçli) |
| Işık | gündüz-pencere ×30 · lamba ×20 · loş ×10 |
| Arka plan | düz duvar ×20 · kitaplık ×15 · perde ×10 · çizgi-zengin ×15 |
| Cihaz | güncel iPhone ×25 · eski iPhone ×15 · orta-segment Android ×20 |
| El | standart (sağ-yay) ×58 · solak-düzen ×2 (kenar vaka kaydı; V1 hedefi DEĞİL) |

Matris hücreleri bağımsız değil — klip planlama sayfası (çekim günü çıktısı) her klibe çok-boyutlu etiket atar; amaç her boyutta minimum çeşitlilik, kartesyen tamlık değil.

## 4. Kaynak insanlar ve tedarik

1. **Kurucu + yakın çevre** (yetişkin, doğru+sahnelenmiş hata): ilk 15-20 klip — protokolün kendisinin provası (pilot çekim, §7).
2. **Çello öğretmeni** (G1-B görüşmelerinden çıkan işbirlikçi): hata sahneleme ALTIN kaynak — hataları pedagojik doğrulukla sahneleyebilen tek profil; ayrıca kendi öğrencilerine erişim kapısı.
3. **Öğrenci gönüllüler / müzik okulu** (B2B sinyaline bağlı): çocuk boyları + gerçek başlangıç hataları buradan. Okul işbirliği = kurucu-manuel listesinde.
4. Açık setler (URMP vb.) BU protokole DAHİL DEĞİL — ayrı hat (lisans yazışması sürüyor); kendi setimiz birincil (katalog §6 kararı).

## 5. Rıza ve çocuk-verisi rejimi (plan §13 — bağlayıcı)

### 5.1 Rıza formu yapısı (TR asıl + EN çeviri; taslaklar §Ek-A/B)

Katmanlı onay — her katman AYRI imza kutusu, varsayılan HAYIR:
- **K1 (zorunlu):** Kayıt + Ostinato ürün geliştirme amaçlı dahili analiz. Süre: rıza geri çekilene dek, azami 3 yıl; sonra imha.
- **K2 (ayrı rıza):** Model eğitim setine dahil edilme (plan §13 "model eğitimi ayrı rıza" hükmü).
- **K3 (ayrı rıza, varsayılan HAYIR):** Anonimleştirilmiş kısa kesitlerin araştırma/tanıtım malzemesinde kullanımı.
- Her formda: silme talebi kanalı (e-posta) + 30 gün içinde imha taahhüdü + saklama yeri/şifreleme beyanı + yüz tanıma YAPILMADIĞI, kimlik tespiti YAPILMADIĞI açık cümlesi.

### 5.2 Çocuk (18 yaş altı) ek kuralları

- Form ebeveyn/veli tarafından imzalanır; çocuğun sözlü onayı (assent) çekim günü ayrıca alınır ve manifest'e işlenir.
- Çocuk kliplerinde K3 (tanıtım) SEÇENEĞİ FORMDA YOK — kategorik hayır (tasarım kararı; riskli sınıf).
- **Yüz bulanıklaştırma:** eğitim setine giden export'ta yüz bölgesi bulanıklaştırılır (hedef sınıflarımız yüz içermiyor → bilgi kaybı yok; çocuk kliplerinde ZORUNLU, yetişkinde varsayılan-açık). Ham orijinal yalnız şifreli arşivde.
- Okul üzerinden toplanan veride: okul yazılı onayı + ebeveyn formu İKİSİ birden.

### 5.3 Saklama/silme politikası

- Ham video: şifreli disk (yerel) — birincil; bulut yedeği ancak kurucu onaylı şifreli bucket (harcama kapısı). Erişim: yalnız kurucu.
- Etiket dosyaları + landmark türevleri: ham videodan AYRI yaşar; silme talebinde ham video VE o kişiye ait türevler birlikte imha (consentId üzerinden izlenebilir — manifest bu yüzden `consentId` taşır).
- İşlem kaydı: `data/CONSENT-LEDGER.md` (append-only): consentId · tarih · kapsam (K1/K2/K3) · durum (aktif/geri-çekildi/imha-tarihi).

## 6. Etiketleme süreci

- **Araç:** CVAT (MIT lisans) birincil aday; alternatif Label Studio (Apache-2.0). İç araç = shipped-dependency kırmızı çizgisinin DIŞINDA, ama yine de permissive seçildi. Kurulum yerel (veri dışarı çıkmaz — rıza beyanıyla tutarlılık).
- **Örnekleme:** klipten 1-2fps + faz-geçiş anları elle eklenir (DIRECTION_CHANGE kareleri kritik ve nadir — düz örnekleme kaçırır).
- **Kalite kapısı:** %10 çift-etiketleme (iki etiketçi aynı kareler) → IoU/keypoint-sapma uyum raporu; uyum <0.8 IoU ise yönerge netleştirilir, o parti yeniden etiketlenir.
- **Etiket yönergesi:** bu dokümanın Ek-C'si çekim pilotundan SONRA örnek karelerle doldurulur (yönerge örneksiz yazılmaz — pilot çıktısı bekleniyor).
- Split disiplini (`data-ml-engineer` şartı): train/val/test bölünmesi KİŞİ-bazlı (aynı kişi iki split'e düşmez — leakage), test split'inde her çello boyu + ışık koşulu temsil edilir; eval raporu out-of-sample ve koşul-etiketli (BF dürüstlük mirası, 00-AILE §7).

## 7. Yürütme sırası ve kapı

1. **Pilot (kurucu, ~yarım gün):** 6 klip — standart açı + 2 adversarial; amaç: açı/kadraj/ışık yönergesinin gerçekle testi + etiket yönergesi örnek kareleri. Pilot çıktısı bu dokümanın v1.1 revizyonunu üretir.
2. Rıza formları son okuma (kurucu; istenirse `legal-contracts-advisor` turu) → basılı+dijital hazır.
3. Faz-1 çekim partileri (60 klip; öğretmen işbirliği devreye girdikçe çocuk/öğrenci hücreleri dolar).
4. Etiketleme + kalite kapısı → Model Maker ilk turu (G3'te; bu protokolün kapsamı DEĞİL).
**Kapı ilişkisi:** Bu protokolün ONAYI derin-yatırım kararı DEĞİLDİR — çekim emeği B2B sinyali (G1-B) netleşene dek pilotla sınırlı tutulur (D3 hükmü: sinyalsiz derin yatırım yok).

## Ek-A — Yetişkin rıza formu taslağı (TR; EN çevirisi onay sonrası)

> **Ostinato Veri Toplama Katılım ve Rıza Formu (Yetişkin)**
> Yula Lab ("biz"), Ostinato müzik pratik uygulamasının çello/yay algılama teknolojisini geliştirmek için çello çalışınızın video+ses kaydını almak istiyor. Kayıtta yüzünüz görünebilir; **yüz tanıma veya kimlik tespiti yapılmaz.** Kayıtlar şifreli ortamda, en fazla 3 yıl saklanır; dilediğiniz an [e-posta] adresine yazarak silinmesini isteyebilirsiniz — 30 gün içinde imha edilir ve size bildirilir.
> Lütfen ayrı ayrı işaretleyin:
> ☐ **K1** Kayıtların Ostinato ürün geliştirme amaçlı dahili analizde kullanılmasına izin veriyorum. *(katılım için gerekli)*
> ☐ **K2** Kayıtların makine öğrenmesi modeli eğitiminde kullanılmasına izin veriyorum. *(isteğe bağlı)*
> ☐ **K3** Yüzüm bulanıklaştırılmış kısa kesitlerin araştırma/tanıtım malzemesinde kullanılmasına izin veriyorum. *(isteğe bağlı, varsayılan: hayır)*
> Ad-Soyad · İmza · Tarih · İletişim (silme talepleri için)

## Ek-B — Ebeveyn/veli rıza formu taslağı (TR)

> **Ostinato Veri Toplama — Ebeveyn/Veli Rıza Formu (18 yaş altı katılımcı)**
> Çocuğunuzun çello çalışının video+ses kaydı, Ostinato uygulamasının geliştirilmesi için kullanılacaktır. **Yüz tanıma/kimlik tespiti yapılmaz; model eğitimine giden her karede çocuğunuzun yüzü bulanıklaştırılır; kayıtlar hiçbir tanıtım malzemesinde kullanılmaz** (bu seçenek çocuk katılımcılar için sunulmamaktadır). Şifreli saklama, azami 3 yıl, istediğiniz an silme hakkı (30 gün içinde imha + bildirim).
> ☐ **K1** Dahili analiz. *(katılım için gerekli)* ☐ **K2** Model eğitimi. *(isteğe bağlı)*
> Çekim günü çocuğunuza da ne yapıldığı yaşına uygun dille anlatılır ve sözlü onayı alınır; istemezse çekim yapılmaz.
> Veli Ad-Soyad · Yakınlık · İmza · Tarih · Çocuğun adı ve yaşı · İletişim

## Ek-C — Etiketleme yönergesi (pilot sonrası doldurulacak — plan §7 sırası)
*(Boş bırakıldı: örnek kareler pilottan gelecek. Yönerge örneksiz yazılmaz.)*
