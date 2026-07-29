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
