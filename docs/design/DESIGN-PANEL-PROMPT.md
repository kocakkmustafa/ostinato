# Ostinato — Claude Design Paneli Promptu (v1, 2026-08-05)

> Koordinatör hazırladı, **kurucu onayı sonrası** panele verilir.
> Kaynak: kurucu tasarım yönü (M-F-282, *"soft"*) + 2 referans görsel
> + ölçülmüş yüzey envanteri (`UI-BRIEF.md` + `assets/content/library.json`).
> §9'daki kısıtlar **estetik tercih değil** — testler ve içerik kapıları zorluyor.

---

## 0. Ne tasarlıyorsun

**Ostinato** — *"telefonunu göreceğin bir yere koy; **nasıl oturduğuna kameradan**, **ne
çaldığına mikrofondan** bakan bir pratik arkadaşı."*

Üç çalgı **canlı**: **Gitar** (7 ders) · **Şan** (6 ders) · **Piyano** (6 ders).
Her birinin doğrulanmış bir postür referansı var — gerçek eğitmenlerden ölçülmüş.

**Karakter:** *öğretmen gibi, hakem gibi değil.* Kısa cümle, düşük kontrastlı uyarı,
abartısız kutlama. **Beklenti şişirmez** — *"açık akorları tanımayı öğren"* der,
*"3 ayda gitarist ol"* demez. Streak baskısı, kırmızı alarm, suçlayıcı dil yok.

**Ürünün imza cümlesi, ekranda yazılı:**
> *"Measured, not chosen. Correct posture is a band, not a point."*

---

## 1. Görsel yön

> **⚠️ Referanslar nasıl okunacak — kurucu talimatı:** **Renk ve cam malzemesi
> Referans-1'den**, **düzen/tasarım dili Referans-2'den**. Renkler **soft ve geçişli**
> kullanılacak. İkisi de müzik uygulaması ama ikisi de **streaming** — biz **pratik**
> uygulamasıyız; onların ekran anlamlarını değil, **düzen gramerini** alıyoruz.

**Referans-1 (pastel müzik kartları arşivi):** yumuşak çok-renkli pastel gradyanlar —
**lila · pudra pembe · nane/turkuaz · şeftali · krem · gök mavisi.** Yarı saydam, camsı
kart yüzeyleri. Yumuşak yuvarlak köşeler. Açık zemin.
→ **AL:** palet, gradyan geçişleri, camsı kart malzemesi, yumuşaklık.

**Referans-2 (Musiclo):** temiz, açık, beyaz tabanlı düzen. Bölümlenmiş satırlar
(*Recently played · Playlists · Discover*), **döşeme ızgaraları**, küçük görselli
**liste satırları**, net başlıklar, alt gezinme.
→ **AL:** düzen grameri — bölüm ritmi, ızgara/liste karışımı, temiz iskelet.
→ **ALMA:** kırmızı vurgu (renk Referans-1'den) · streaming anlamları (şarkı sözü,
favoriler, çalma listesi) — bizde bunların karşılığı yok.

**🎨 Çok-renklilik bir fırsat:** Referans-1'de her kart kendi renginde. Bizde **üç çalgı**
var — **her çalgı kendi gradyan kimliğini** taşıyabilir (ör. gitar bir tonda, şan
başkasında, piyano üçüncüsünde). Kullanıcı hangi çalgıda olduğunu renkten anlar.

### 🔴 KARDEŞ AYRIŞMASI — bağlayıcı

Aile beş uygulama ve **hiçbiri diğerine benzemeyecek** (kurucu kuralı: *"aynı elden
çıkmış renkleri değişik şekilde değil"*). Şu an tasarlananlar:

| | JabLab | Choreia | **Lissom** | **Ostinato (sen)** |
|---|---|---|---|---|
| Zemin | koyu | koyu | açık | **açık** |
| Renk | kırmızı | erik/gül | pastel mor-şeftali | **çok-renkli pastel** |
| Malzeme | **buzlu** cam | **şeffaf prizmatik** cam | **mat kil** (saydam DEĞİL) | **camsı gradyan kart** |

**⚠️ En yakın kardeşin LISSOM** — ikiniz de açık zemin + pastel. Ayrım şurada kurulacak:

- **Malzeme:** Lissom **mat kil** (opak, saydamlık yok). Sen **camsı/yarı saydam
  gradyan**. Aynı malzeme değil.
- **Renk mantığı:** Lissom **tek bir pastel aile** (mor→şeftali, uyumlu). Sen **çok-renkli
  spektrum** — lila, nane, şeftali, gök mavisi **yan yana**.
- **Düzen:** Lissom **çok boşluklu, sihirbaz akışı**, ekran başına az öğe. Sen
  **bölümlenmiş, ızgara/liste ritmi olan** yapılı bir kütüphane (Referans-2 grameri).
- **Tipografi:** Lissom **zarif serif**. Sen **temiz sans** (müzik uygulaması dili).
- **Hareket:** Lissom **yavaş, süzülen, dağınık**. Sen **düzenli, ölçülü, metronomik** —
  yumuşak ama **tempolu**. (Choreia akan/döngüsel; onunla da karışma.)

**Palet dışında en az 3 eksende ayrışmayan çıktı reddedilir.**

---

## 2. Sayfa yapısı

**Kütüphane → Çalgı → Kurs → Ders** (Referans-2'nin gramerine çok uyar)
+ **Kurulum Kontrolü** (sert kapı) + **Canlı tur** + **Özet** + **Ayarlar**.

| Ekran | İçerik | Kritik |
|---|---|---|
| **Kütüphane** | Çalgı kartları | canlı olmayan çalgı **isimli gerekçeli** |
| **Çalgı sayfası** | Tanıtım + **dürüstlük kutusu** (ölçülen/ölçülmeyen) + kurslar + kapsam-dışı | canlı olmayan çalgıda **KURS GÖSTERİLMEZ** |
| **Kurs** | Ders listesi, seviye, süre | — |
| **Ders kartı** | Başlık + süre + odak | üç görsel sınıf (§4) |

---

## 3. Kurulum Kontrolü — **SERT KAPI**, ailenin en özgün ekranı

Geçilmeden ölçüm modu **başlamaz**. Bu ekran Ostinato'ya özgü: **hem kamera hem mikrofon
kalibre ediliyor.**

| Durum | Ne görünür |
|---|---|
| Yönlendirme | Canlı kamera + silüet/kadraj rehberi + *"kalçandan omzuna görünmelisin"* |
| **Kadraj hatası** | Hangi eklem eksik, **isimle** (*"kalçan kadrajın dışında"*) |
| **Işık yetersiz** | Ölçülmüş neden (*"çok karanlık — landmark güveni düşük"*) |
| 🎤 **Oda gürültü tabanı** | **3-5 sn sessizlik isteği** + ilerleme göstergesi; gürültü çok yüksekse **isimli ret** |
| **Geçti** | Onay + neyin kalibre edildiği **tek satır** |
| Serbest pratik | Kapı DEĞİL, uyarı bandı (ölçüm modunda sert, serbest modda öneri) |

> **Bu ekranı ürünün ilk izlenimi olarak tasarla.** "Sessiz ol, dinliyorum" anı bu
> uygulamanın karakterini tek başına anlatıyor — teknik bir engel gibi değil, bir
> **hazırlık ritüeli** gibi hissettirmeli.

---

## 4. Ders — ÜÇ GÖRSEL SINIF (üçüncüsü ailede yeni)

| Sınıf | Anlamı | Görsel gereksinim |
|---|---|---|
| **Skorlu** | ölçülür ve hüküm verilir | normal akış |
| **Kilitli** | ders **görünür ama açılmaz** | sebep **EKSİK ÖLÇÜMÜN ADIYLA** (eşik değeriyle değil) |
| **⭐ Ölçülür ama puanlanmaz** | değer **canlı gösterilir**, hüküm **verilmez** | **"bilgi" tonu — "hata" tonu DEĞİL.** Eksik/ikinci sınıf görünmemeli |

**Üçüncü sınıf bugün 3 derste var** (her çalgının `arms` dersi) ve metni hazır:
> *"You see your own elbow and forearm angles, live, next to the range the teachers we
> recorded occupy. What you do not get is a mark, because there is nothing honest to mark
> you against."*

**4 kilitli dersin gerekçeleri — AYNEN kullanılacak, yumuşatılmayacak:**

- **Gitar / foot support:** *"Nothing below your hips is measured. Our posture reference
  is built from upper-body landmarks only, because guitar teaching footage is filmed
  waist-up… Without leg landmarks we cannot tell a footstool from a crossed leg."*
- **Gitar / open chords:** *"Chord recognition has only been proven on synthetic audio
  (8/8 chords, zero false judgements) — it hasn't been tested on a real guitar recording
  yet. We won't grade you against a measurement we haven't confirmed on a real instrument."*
- **Şan / sustained note:** *"…it has only been confirmed on real cello recordings…
  never on a real singing voice. A voice is not a cello: vibrato, breath and formants are
  exactly the things that would break it… **One real vocal recording through the same
  pipeline opens this lesson.**"*
- **Piyano / five finger:** *"We can hear every note you play and time it against the
  beat — you will see those numbers. What we cannot do is turn them into a mark…
  **A grade built on that would be arithmetic, not teaching.**"*

> **Kilit gerekçesi VİTRİNDİR.** Bu metinler ürünün en güçlü içeriği — küçük punto
> dipnot değil, **okunacak yer** olarak tasarlanmalı.

---

## 5. Canlı tur

| Durum | Ne görünür |
|---|---|
| Hazırlık | Geri sayım + ne yapılacağı |
| **Ölçüyor** | Sakin canlı geri bildirim · **SAYISAL SKOR YOK** · eğitmen **bandı** ölçülen aralıkla |
| **Hüküm yok** | ⚠️ Güven düşükken **SESSİZLİK DEĞİL**, *"şu an göremiyorum"* — **sessizlik "iyi gidiyorsun" diye okunur** |
| Koç konuşuyor | Görünür işaret ister |

**Eğitmen bandı ekranda:** ölçülen aralık gösterilir (gitar 7 eğitmen 2,24° içinde ·
şan 6 eğitmen 1,35° · piyano 3 eğitmen 1,09°). **Puan yok, bant var.**

### ⭐ Gözlem işareti — bu turun çözmesi gereken tasarım problemi

`observationCue` bir **hata uyarısı DEĞİL**, bir **gözlem**: *"ölçtüğümüz eğitmenlerin
hiçbiri bu kadar eğilmiyor."* Rahatsız etmemek için **30 saniyelik bir bastırma** var —
ölçüldü: işaret zamanın yalnız **%7,4'ünde** görünüyor.

> **Karar senin:** bu doğru denge mi? Rahatsız etmeme ile fark edilme arasındaki ayarı
> **görsel olarak** çöz — işaret nadir kalıp **daha güçlü** mü belirsin, yoksa daha sık
> ama daha sessiz mi? Her iki yönü de öner. (Bastırma süresini değiştirmek koordinatör
> kararı; sen **görünürlük tasarımını** öner.)

---

## 6. Özet (Review)

| Bölüm | İçerik |
|---|---|
| **Neyi ölçtük** | Bant + eğri + süre — *"steady / improving / needs focus"*. Sayılar **yalnız** kalibrasyon geçilmişse ve **bileşenleri açıklanarak** |
| **Neyi ölçemedik** | ⚠️ **ZORUNLU BÖLÜM** — atlanan/güvensiz pencereler **isimle** |
| **Sonraki adım** | **TEK** öneri — liste değil |
| **Paylaşım** | **İskelet-render** rapor; **ham video ASLA çıkmaz**, açık onay ister |

> *"Neyi ölçemedik"* atlanabilir bir bölüm değil, özetin **eşit ağırlıklı yarısı**.

---

## 7. Çalgı sayfasının dürüstlük kutusu — ürünün vitrini

Her çalgı sayfasında **ölçülen / ölçülmeyen** listesi var ve metinleri hazır. Örnekler:

- *"Trunk alignment while you sit — checked against 3 independent piano teachers who agree
  to within 1.09 degrees of each other, **the tightest agreement of any instrument we have
  measured**."*
- *"Vibrato — measured, never judged. We have no teacher data on what rate is 'right', and
  **inventing one would be a guess dressed as a measurement**."*
- *"Arm, shoulder and elbow position — the six teachers **disagree with each other by 43 to
  88 degrees**. That is style and framing, not error."*
- *"A chord outside those 8 is **refused by name** ('not one of the chords this lesson
  covers'), not reported as the nearest one that is."*

Bu kutu **birinci sınıf yerleşim** ister. Rakipler bunu yazmıyor; bizim farkımız bu.

---

## 8. Hareket ve geçişler

- Karakter: **düzenli, ölçülü, metronomik** — yumuşak ama **tempolu**.
  (Lissom'un dağınık süzülmesi ve Choreia'nın döngüsel akışı **kullanılmaz**.)
- Gradyanlar hafifçe canlı olabilir — nefes alan, yavaş kayan.
- Kurulum kapısı geçildiğinde: **sakin bir onay**, kutlama değil.
- Sessizlik ölçümü sırasında: sakinleştiren, bekleteni rahatsız etmeyen bir ilerleme.
- Gözlem işareti belirirken: **fark edilir ama bölmez** (§5).

---

## 9. ⛔ ASLA

1. **Kalibre edilmemiş SAYISAL SKOR YOK** — bant kullan ("nokta değil bant").
2. **Beklenti şişiren vaat YOK** — *"3 ayda gitarist ol"* sınıfı her cümle yasak.
3. **TIBBİ DİL YASAK** — "postüral bozukluk", "tedavi", "tanı" (wellness sınırı).
   Bizim dilimiz: *"duruş", "rahat", "destek"*.
4. **Streak / rekor / kırmızı alarm / suçlayıcı dil YOK.**
5. **Hüküm yokken SESSİZ KALMA** — sessizlik "iyi gidiyorsun" diye okunur; *"göremiyorum"* de.
6. **Canlı olmayan çalgıda kurs listelenmez** (sahte kurs yok).
7. **Kilit gerekçesi eşik değeriyle değil, EKSİK ÖLÇÜMÜN ADIYLA** yazılır.
8. **"Ölçülür ama puanlanmaz" ders ikinci sınıf gösterilemez.**
9. **HAM VİDEO ASLA cihazdan çıkmaz** — paylaşım yalnız iskelet-render + açık onay.
10. **Referans-2'nin kırmızısı ve streaming anlamları KULLANILMAZ** (§1).
11. **Lissom'un mat kili ve serif dili KULLANILMAZ** (§1 ayrışma kuralı).

---

## 10. Zorunlu hâller

boş · yükleniyor · hata (teknik jargon yok) · **kamera izni reddi (geçici/kalıcı ayrı)** ·
**mikrofon izni reddi** · kadraj dışı (hangi eklem, isimle) · düşük ışık ·
**oda çok gürültülü** · düşük takip güveni · kilitli ders · "ölçülür ama puanlanmaz" ders ·
canlı olmayan çalgı (gerekçeli).

---

## 11. Teslim

- Kütüphane → Çalgı → Kurs → Ders zinciri
- **Kurulum Kontrolü'nün tüm hâlleri** (kadraj · ışık · **sessizlik ölçümü** · geçti · ret)
- **Üç ders sınıfı ayrı ayrı** ("ölçülür ama puanlanmaz" en kritiği)
- Canlı tur + eğitmen bandı + **gözlem işareti için iki görünürlük önerisi** (§5)
- Özet — "neyi ölçemedik" bölümü **eşit ağırlıkta**
- Çalgı sayfası dürüstlük kutusu
- Üç çalgının **gradyan kimliği**
- Geçiş animasyonları + hareket spec'i
- Palet, tipografi ölçeği, **camsı gradyan kart** spesifikasyonu
- **Arayüz metinleri İNGİLİZCE**

> **Açık kalem (kurucu kararı bekliyor, tasarlama):** ayarlarda bir **çocuk rejimi** var —
> çocuk modunda ton ve görsel dilin ayrışıp ayrışmayacağı **henüz kararlaşmadı**. Bu turda
> kapsam dışı; sorulursa koordinatöre gelir.

---

*Bağlayıcı kaynak: `docs/design/UI-BRIEF.md` (§2.2 sert kapı · §4 güncel canlı durum ·
EK gözlem işareti) · `assets/content/library.json` · K8 · M-F-09 · M-F-232 · M-F-282.*
