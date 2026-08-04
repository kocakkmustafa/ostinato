# Ostinato — UI BRIEF (ekran envanteri, tasarım girdisi)

**Tarih:** 2026-07-29 · **Amaç:** `claude.ai/design` oturumlarına GİRDİ. Kod
değil, ekran-envanteri + durum listesi + akış. **Statü:** taslak — görsel
kararlar tasarım oturumunda verilir.

> ⚠️ Bu belge ölçüm-durumunu 2026-07-29 gecesi itibarıyla yansıtır ve
> **kasten tutucudur**: ekranlar, bugün GERÇEKTEN ölçtüğümüz şeyin üstüne
> tasarlanır. Bir ekranda "yakında" yazıyorsa o gerçek bir boşluktur,
> yer-tutucu değil. Ölçüm ilerledikçe bu belge güncellenir — tasarım
> ilerlediği için DEĞİL.

---

## 0. Ürünün tek cümlesi

**TR:** Telefonunu göreceğin bir yere koy; nasıl oturduğuna kameradan,
ne çaldığına mikrofondan bakan bir pratik arkadaşı.
**EN:** Put your phone where it can see you; a practice companion that
watches how you sit and listens to what you play.

## 1. Marka tonu (metin yazımı için bağlayıcı)

| İlke | Nasıl görünür | Karşıtı (YASAK) |
|---|---|---|
| **Dürüst** | "Bunu ölçüyoruz · bunu ölçmüyoruz" her çalgı sayfasında kutu olarak | Ölçmediğimiz şeyi ima eden rozet/skor |
| **Sakin** | Kısa cümle, düşük kontrastlı uyarı, kutlama abartısız | Streak baskısı, kırmızı alarm, suçlayıcı dil |
| **Öğretmen gibi, hakem gibi değil** | "Omzun yükseliyor" · "sırtın öne kayıyor" | "Yanlış!", puan-şoku, sıralama |
| **Tıbbi DEĞİL** | "duruş", "rahat", "destek" | "postüral bozukluk", "tedavi", "tanı" — YASAK (wellness sınırı) |
| **Beklenti şişirmez** | "açık akorları tanımayı öğren" | "3 ayda gitarist ol" (O-011) |

Dil: **TR + EN** (içerik kütüphanesi bugün EN; TR çeviri ship kapısında).

## 2. Ekran envanteri

Her ekran için: **ne gösterir · hangi durumları taşır**. Durum listesi
tasarımın asıl işi — Ostinato'da "boş" ve "izin reddi" istisna değil,
BEKLENEN yollar.

### 2.1 Onboarding (ilk açılış)
| # | Ekran | İçerik | Durumlar |
|---|---|---|---|
| O1 | Karşılama | Tek cümle vaat + "ne ölçeriz/ölçmeyiz" özeti | — |
| O2 | Çalgı seçimi | 3 canlı (Gitar canlı · Şan/Piyano "yakında") + 39 çalgı "yakında" | **yakında** (kilitli kart, isimli gerekçe), arama boş sonucu |
| O3 | İzinler | Kamera + mikrofon; NEDEN gerektiği tek cümle, izin isteğinden ÖNCE | **izin reddi** (kamera yok → yalnız ses akışı? bugün HAYIR: postür dersi çalışmaz, dürüstçe söyle) · **kalıcı ret** (ayarlara yönlendir) · **yalnız biri verildi** |
| O4 | Yaş bandı / vasi onayı | Çocuk rejimi bayrağı | **çocuk rejimi** (vasi onayı alınana kadar akış DURUR) |

### 2.2 Setup Check — **SERT KAPI** (M-F-09)
Ürünün en kritik ekranı: geçilmeden ölçüm modu BAŞLAMAZ.
| Durum | Ne görünür |
|---|---|
| Yönlendirme | Canlı kamera + silüet/kadraj rehberi + "kalçandan omzuna görünmelisin" |
| **Kadraj hatası** | Hangi eklem eksik, isimle ("kalçan kadrajın dışında") |
| **Işık yetersiz** | Ölçülmüş neden ("çok karanlık — landmark güveni düşük") |
| **Oda gürültü tabanı ölçümü** | 3-5 sn sessizlik isteği + ilerleme; gürültü çok yüksekse isimli ret |
| **Geçti** | Yeşil onay + neyin kalibre edildiği tek satır |
| Serbest pratik | Kapı DEĞİL uyarı bandı (ölçüm modunda sert, serbest modda öneri) |

### 2.3 Kütüphane → Çalgı → Kurs → Ders
| # | Ekran | İçerik | Durumlar |
|---|---|---|---|
| L1 | Kütüphane | Çalgı kartları (canlı / yakında) | yakında kartı isimli gerekçeli |
| L2 | Çalgı sayfası | Tanıtım + **dürüstlük kutusu** (ölçülen/ölçülmeyen listesi) + kurslar + kapsam-dışı listesi | `coming_soon` çalgıda **KURS GÖSTERİLMEZ** (sahte kurs yok) |
| L3 | Kurs | Ders listesi, seviye, süre | — |
| L4 | Ders kartı | Başlık + süre + odak | **kilitli** — ders GÖRÜNÜR ama açılmaz, `lockedReason` EKSİK ÖLÇÜMÜN ADIYLA yazılır (eşik değeri değil). Bugün 4 kilitli ders var; metinleri `assets/content/library.json`da hazır |

### 2.4 Canlı tur (ders içi)
| Durum | Ne görünür |
|---|---|
| Hazırlık | Geri sayım + ne yapılacağı |
| **Ölçüyor** | Sakin canlı geri bildirim; **sayısal skor YOK** (kalibrasyon kapısı K8/M-F-04) |
| **Hüküm yok** | Güven düşükken sessizlik DEĞİL, "şu an göremiyorum" — sessizlik "iyi gidiyorsun" diye okunur |
| **Koç konuşuyor** | Analiz zaman-kapısı (CueGate) görünür işaret ister |
| Duraklat / çık | Kısmi seans kaydedilir mi? (karar açık) |

### 2.5 Özet (Review)
| Bölüm | İçerik |
|---|---|
| Neyi ölçtük | Bant + eğri + süre — **"steady / improving / needs focus"**; cent/ms sayıları YALNIZ kalibrasyon geçilmişse ve bileşenleri açıklanarak |
| **Neyi ölçemedik** | Zorunlu bölüm — atlanan/güvensiz pencereler isimle |
| Sonraki adım | Tek öneri, liste değil |
| Paylaşım | İskelet-render rapor; **ham video ASLA çıkmaz**, açık onay ister |

### 2.6 Ayarlar
Çalgı değiştir · kalibrasyonu yenile · dil (TR/EN) · veri ve gizlilik
(ham video cihazda kalır beyanı) · çocuk rejimi · hesap/veri silme.

## 3. Akış (metin diyagramı)

```
İlk açılış
  O1 karşılama → O2 çalgı → O3 izinler → O4 yaş/vasi
        │                        └─(ret)→ dürüst çıkmaz ekranı: neyin çalışmayacağı
        ▼
  L1 kütüphane → L2 çalgı sayfası (dürüstlük kutusu) → L3 kurs → L4 ders
        │                                                          │
        │                                              (kilitli)───┴→ lockedReason ekranı
        ▼
  Setup Check ──(SERT KAPI: geçemedi)──→ isimli hata + tekrar dene
        │ geçti
        ▼
  Canlı tur ──(güven düşük)──→ "şu an göremiyorum" bandı
        │ bitti
        ▼
  Özet: ölçtüklerimiz + ÖLÇEMEDİKLERİMİZ + tek sonraki adım
        └─(opsiyonel)→ Öğretmen paylaşımı (açık onay, iskelet-render)
```

## 4. Bugün GERÇEKTEN canlı olan (tasarım bunun üstüne kurulur)

- **Gitar / oturuş duruşu:** `trunk_tilt` — 3 bağımsız eğitmen konsensüsü,
  ATTESTED referans (M-O-47), tüketicisi canlı doğrulandı (M-O-48).
- **Gitar / çalarken duruş:** ses seviyesi tetiği + slouch hatası — ikisi de
  kanıtlı (M-O-52 uçtan-uca zincir).
- **Akor sınıfı (8 açık akor):** motor çalışıyor ve ölçülü (M-O-35/52) ama
  **gerçek gitar kaydında doğrulanmadı** → ders KİLİTLİ.
- **Kollar/eller:** ölçülüyor ama **skorlanmıyor** (eğitmenler 11-18° ayrışıyor)
  → gösterilebilir, hüküm verilemez. Tasarımda "bilgi" tonu, "hata" tonu DEĞİL.
- **Şan / Piyano:** hiçbir postür referansı anlaşma kapısını geçmedi → çalgı
  sayfaları "yakında", kurs YOK.

## 5. Tasarım oturumuna açık sorular (karar tasarımda/koordinatörde)

1. "Ölçemedik" bilgisi Özet'te ne kadar öne çıkmalı — eşdeğer bölüm mü, ikincil mi?
2. Kilitli ders: kilit ikonu + gerekçe mi, yoksa gerekçe metni kartın kendisinde mi?
3. Canlı turda "hüküm yok" bandı ile gerçek hata uyarısı görsel olarak nasıl
   AYRIŞIR (ikisi karışırsa dürüstlük kaybolur)?
4. Kalibrasyon geçilmeden sayı gösterilmiyor — bant/eğri dili sayısal-hissi
   vermeden nasıl "ilerleme" anlatır?
5. Çocuk rejiminde ton ve görsel dil ayrışmalı mı?

---

## EK — 2026-08-04: gözlem işareti yüzeyi + 5 açık ders (tasarım turu girdisi)

> 🔴 **2026-08-05 ŞERHİ — bu bölümü okurken:** gözlem işaretinin config bağı
> ve şablon sözleşmesi geçerlidir, ama **çalışan uygulamada göründüğü
> KANITLANMADI** (O-032). Değerlendirici işareti üretiyor (ölçüldü) ve widget
> onu çiziyor (3 test), fakat canlı uygulamada aralık-dışı pencerenin
> ortasında da görünmedi; yakalama zamanlaması elendi. Bu ek "işaret canlı
> çalışıyor" DEMEZ — tasarım turu, O-032 kapandıktan sonra bu bölümün
> ekran karşılığıyla birlikte okunmalı.

Bu ek, kurucu-manuel tasarım turu için hazırlandı. Aşağıdaki her şey BUGÜN
ölçülüyor; hiçbiri gelecek vaadi değil.

### 1. Yeni yüzey: GÖZLEM İŞARETİ (`observationCue`) — hata uyarısı DEĞİL

Ürün artık iki AYRI iddia sınıfı taşıyor ve **ekranda da ayrı görünmeleri
gerekiyor** — karıştırılırlarsa şeridi ayıran bütün yapı boşa gider:

| | ÖĞÜT (bugün KAPALI) | GÖZLEM (bugün AÇIK) |
|---|---|---|
| ne der | "duruşun yanlış / şöyle otur" | "ölçtüğümüz 7 eğitmenin hiçbiri bu kadar eğilmiyor; sen 17°'desin" |
| dayanağı | uzman doğrulaması (movement-science turu) | ATTESTED referans + artefakttan türetilmiş 14,0° eşik |
| durumu | `expertPending` — hiçbir derste görünmüyor | 5 açık postür dersine BAĞLI (config) — canlı uygulamada görünürlüğü **O-032 ile AÇIK**, aşağıya bak |

**Tasarım şartları (config'te mekanik olarak zorlanıyor, UI bunları bozamaz):**
- Metin SABİT şablondan gelir (`config/observation-cue-templates.golden.json`).
  UI şablonu **yeniden yazamaz**; yalnız yerleştirir. Motor kullanıcı metni üretmez.
- Şablonda emir kipi, sebep-sonuç ve beden-sonucu YASAK (kelime-sınırıyla taranıyor).
  Yani "sit up straight" ya da "bu sırtına zarar verir" gibi bir metin UI'dan da giremez.
- Cümle KAYNAĞINI taşır ("kaydettiğimiz 7 eğitmen"). Sayıyı kaynağından koparan
  bir görsel düzen (ör. yalnız "17° / 14°" göstermek) iddiayı ölçüm-beyanı
  olmaktan çıkarır — **sayı tek başına gösterilmemeli.**
- İşaret aralık İÇİNDEYKEN SUSAR. Sürekli görünen bir rozet/ikon bu sözleşmeyi
  bozar: gözlem, arka plan değil olaydır.

**Ölçülmüş ateşleme davranışı (tasarımın sıklık beklentisi için):**
referansı kuran eğitmen kareleri: **0 ateşleme** (gitar 0/939 · şan 0/729 ·
piyano 0/407). Videonun tamamında: gitar %20 · şan %0,5 · piyano %17 — bu ikinci
sayı öğretmenin yürüdüğü/eğildiği anları da içerir, ürün içi beklenen sıklık
DEĞİL. Ayrıca `cooldownMs: 30000` ve "3 ardışık bant-dışı" bastırması var.

### 2. Beş açık ders — ekranda ne olduğu

| ders | ne SKORLANIR | gözlem işareti | ne skorlanmaz |
|---|---|---|---|
| Guitar · Sitting posture | trunk_tilt | ✅ | kollar (stil farkı 39-105°) |
| Guitar · Staying upright while you play | trunk_tilt | ✅ | akor (ders kilitli) |
| Voice · How you stand before you sing | trunk_tilt | ✅ | perde/sustain (kilitli) |
| Voice · Staying open while you sing | trunk_tilt | ✅ | vibrato (hüküm yok) |
| Piano · How you sit at the keyboard | trunk_tilt | ✅ | zamanlama (ölçülür, puanlanmaz) |

Üçünde de **tek skorlanan metrik trunk_tilt.** Ekran bundan fazlasını ima
etmemeli: çok-metrikli bir "duruş paneli" görseli, ölçmediğimiz sekiz eklemi
ölçüyormuş gibi gösterir.

### 3. "Ölçülür ama puanlanmaz" — üçüncü bir görsel sınıf gerekiyor

Bugün üç ayrı şey var ve ikisi karışmaya müsait:
1. **skorlanan** (trunk_tilt) — bant geri bildirimi
2. **ölçülür-puanlanmaz** (piyano `note_timing_ms`, kol/omuz açıları) — sayı
   gösterilir, hüküm YOK
3. **kilitli** (akor, perde, beş-parmak) — hiçbir yüzey taşımaz

(2) için ayrı bir görsel dil şart: puanlanan bir sayıyla aynı görünen bir
"ölçülür-puanlanmaz" sayı, kullanıcı için puandır. Piyanoda bu somut:
zamanlama sayısı gösterilecek ama **motorun kendi 8,29 ms önyargısı ölçüldü**
(O-025) — sayı bugün mutlak doğruluk iddiası taşıyamaz.

### 4. Kilitli derslerin gerekçesi VİTRİNDİR

Beş kilitli dersin `lockedReason` metinleri eksik ölçümün ADINI söylüyor
(eşik değerini değil). Bunlar küçük gri dipnot değil, ürünün dürüstlük
iddiasının en somut kanıtı — tasarım turunda okunabilirlik önceliği almalı.
