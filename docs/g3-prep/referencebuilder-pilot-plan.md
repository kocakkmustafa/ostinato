# Ostinato G3-Hazırlık — ReferenceBuilder Bowing Pilotu PLANI (v1)

**Tarih:** 2026-07-26 · **Statü:** PLAN (ölçüm G3'te; O-012'nin kapanış tasarımı). **Bağlayıcı:** katalog §6.0 / M-C-01..04 (kamu eğitmen videolarından ≥3-kaynak konsensüs referansı) + M-F-03 (çekirdek sahibi koordinatör — `ReferenceBuilder`/mocore'a doğrudan yazılmaz, tüketilir; ihtiyaçlar M-O-* ile bildirilir).
**Soru (O-012):** Çello eğitmen videoları V1 standart açımızda değilken bowing SKORLAMA referansı kamu videolarından güvenilir çıkarılabilir mi?

## 1. Hedef teknik ve kapsam

Pilot TEK teknikle sınırlı: **açık tel (D) uzun yay** — V1'in çekirdek egzersizi, en bol video malzemesi olan teknik. Çıkarılacak referans: sağ kol eklem-açısı dizileri (omuz/dirsek/bilek) + faz zamanlaması (DOWN/UP/CHANGE); yay-hattı geometrisi V1 pilotunda İSTENMEZ (nesne algılama ayrı hat — referans iskelet-tabanlı başlar).

## 2. Video seçim kriterleri (≥3, hedef 5-6 bağımsız eğitmen)

- İçerik: açık tel uzun yay GÖSTERİMİ (anlatım arası kesintisiz ≥4 tam yay stroku); "doğru icra" bağlamı net (ders videosu, eğitmen kendisi çalıyor).
- Açı sınıfı ETİKETLENİR: A=sağ-ön çapraz (bizim açı) · B=tam yan (profil) · C=tam ön · D=sol/diğer. Hedef: ≥2 video A-veya-yakını; B/C bilinçli dahil (açı-duyarlılık verisi üretir).
- Kadraj: gövde+sağ kol tam görünür; kamera sabit; tek kişi.
- Çeşitlilik: farklı vücut tipleri/cinsiyet; en az 1 farklı öğretim geleneği (Suzuki-tarzı + konservatuvar-tarzı).
- Kayıt: her video için `kaynak-URL + eğitmen + açı-sınıfı + fps + kesit timestamp'leri` tablosu (provenance, M-F-07).
- **Girdi listesi BAĞLANDI (2026-07-26):** triyaj raporu `../g1/kamera-aci-triyaji.md` — A-aday 4 video (#20 Weilerstein · #40 AdultCello · #48 Olga Celli · #56 Rapsodi Sanat) + belirsiz-terfi adayları (Bora Erdoğan 1-2 kare-kontrollü) + B4 kolu için şartlı-sınıftan seçki. Provenance: `../data/harvest/cello-triage.v1.json`.

## 3. Boru hattı (hepsi mevcut kanonik araçlarla — yeni core kodu YOK)

1. Kesit çıkarma (yalnız gösterim saniyeleri) → yerel çalışma kopyası (yayınlamayız; C-017 hukuki pozisyonu kurucu-kabullü).
2. **mocore** (kanonik Python hattı) ile landmark çıkarımı — model pinli + SHA (M-L-01 kuralı).
3. Kalite kapıları sırayla: `StructuralValidator` temizliği → açı-uygunluk (fronto-paralel sapma ölçümü; §6.0 kapısı) → plan/kesme sınırı tespiti.
4. **`ReferenceBuilder`** konsensüsü: aynalama çözümü (`resolveMirroring`) + eğitmenler-arası varyans → `CanonicalReference.toleranceAt`.
5. Çapraz kontrol: türetilen tolerans bantları ↔ pedagoji taksonomisi eşik beklentileri (E-BOW-SKEW/E-ELBOW-BAD-HEIGHT bantlarıyla çelişki var mı) + fizyolojik makullük (movement-science turu).

## 4. Başarı ölçütleri (ölçümden ÖNCE — O-007 dersi)

| # | Ölçüt | Eşik |
|---|---|---|
| B1 | Kullanılabilir take oranı | ≥3 bağımsız eğitmenden ≥1'er temiz take (StructuralValidator geçer + açı kapısı geçer) |
| B2 | Aynalama konsensüsü | `resolveMirroring` TEK atamada uzlaşır (çözümsüzlük = FAIL — sistematik ters öğretme riski) |
| B3 | Varyans makullüğü | Konsensüs eklemlerinde (dirsek yörüngesi, yay-kolu faz süreleri) eğitmenler-arası band, taksonomideki "hata" büyüklüklerinden DAR (band ≥ hata büyüklüğü ise referans hata ayıramaz = FAIL) |
| B4 | Açı-duyarlılık raporu — **ANA KOL (2026-07-26 triyaj bulgusuyla terfi):** sıkı-A oranı yalnız %7 (4/57) çıktı → kamu-video stratejisinin çello verimi B/C-açı normalizasyon toleransına bağlı. Metrik-BAŞINA ayrıştırılır: postür metrikleri (açı-toleranslı beklenir) vs yay-paralellik (en duyarlı) | A↔B/C farkı metrik-başına raporlanır; "hangi metrik hangi açı sınıfından beslenebilir" tablosu pilot çıktısıdır |
| B5 | Faz tespiti | ≥%90 strokta DOWN/UP/CHANGE zamanları elle işaretlemeyle ±1 kare uyumlu |

**Sonuç yolları:** B1-B3+B5 geçer → bowing referans hattı = kamu-video (protokoldeki sahnelenmiş-doğru klipler tamamen düşer). B2 veya B3 FAIL → geri-dönüş: işbirlikçi öğretmenle KENDİ referans çekimlerimiz (G1-B'den çıkan öğretmen; §6.0'a istisna GEREKMEZ — karar "kamu videosu birincil" der, fizibilite raporuyla Ostinato-özel sapma kurucuya sunulur, motion-core DEFTER'ine M-O kaydıyla).

## 5. Bağımlılıklar ve zamanlama

- Koordinatörden (M-O-01 talebi): mocore çıkarım CLI'ının Ostinato kesitleriyle koşum şekli + ReferenceBuilder'ın video-başı-take girdi formatı + açı-uygunluk kapısının mevcut implementasyon durumu.
- G1-B'nin sonucuna BAĞIMLI DEĞİL (paralel koşabilir) ama derin-yatırım kararı öncesi yalnız PLAN + video seçimi yapılır; çıkarım koşumu G3'te (D3 disiplini: kapı öncesi emek minimum).
