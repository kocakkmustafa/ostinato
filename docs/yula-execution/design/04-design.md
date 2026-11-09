# Ostinato — Tasarım kararı ve Aşama 5 teslimatları (OST-UX-03)

Tarih: 2026-11-09 · Girdi: [`01-audit.md`](01-audit.md), [`02-mental-model.md`](02-mental-model.md), [`03-concepts.md`](03-concepts.md) (özellikle bölüm 4–6) · Dayanak: "Dört Ürün Arayüz ve Deneyim Talimatı" §5, §7 Aşama 4–5.
YALNIZ BELGE: kod, test, içerik, renk, tipografi, marka, bağımlılık ve veri modeli değişmez. Tüm bayraklar KAPALI varsayılanla anılır; bu belge hiçbir bayrağın değerini değiştirmez. Doğrulama kodları 03 ile aynı: **K** kaynakta okundu · **T** testte var (koşturulmadı) · **U** doğrulanamadı. "Yeni" = bugün kodda karşılığı yok.
Kapsam notu: kullanıcıyla test yapılmadı; gerekçe tasarım düzeyindedir (03 §7). Dosya düzeni: bu dosya = ADR-UX-001 + teslimat 1–13; teslimat 14 (UX-05a…h kabul ölçütleri) = [`04-backlog-ux-05.md`](04-backlog-ux-05.md).

---

## ADR-UX-001 — Tasarım seçimi: "Tek Sahne" omurgalı, sınırlı melez

Biçim: [`../DECISIONS.md`](../DECISIONS.md) ADR biçimi (beş madde) + durum/seçenek/sonuç. Bu ADR tasarım kararıdır; kurucuya sorulmadı (brief: tasarım kararları ADR olarak yazılır).

**Durum:** Kabul (tasarım). Uygulama UX-05a…h biletleriyle, bayrak arkasında.

### Karar
Konsept 1 "Tek Sahne" (çalmak-önce, katmanlı) omurgadır. Üç bağımsız parça, yalnız bağımsız oldukları için eklenir; başka hiçbir şey alınmaz:

| Kaynak | Alınan parça | Biçim |
|---|---|---|
| K1 Tek Sahne | Kök = çalma sahnesi; Başka çalış / Yolum / Ayar geçici katmanları; çalarken tutamaklar gizli; katman sahneyi kapsamaz | Omurga |
| K2 Oturum Akışı | "Bugün için bir öneri" tek satırı ve "Bu bölümü yavaş tekrar et" tipi kural tabanlı öneri | "Başka çalış" katmanında tek satır; oturum bileşimi, süre seçimi ve adım şeridi ALINMAZ |
| K3 Çalışma Masası | Araç rafı: metronom görünümü, referans dinleme, döngü, yardım (Hayalet) ayarı | Sahnede isteğe bağlı OPAK raf; ana pratik ekranı bölünmez (03 §6 regresyon riski) |
| K3 Konu haritası | Yol görünümü | "Yolum" içinde, liste eşdeğeri ÖNCE; harita bileşeni ilk sürümde yok (düğüm durumu yalnız `V1PracticeRecord`'dan, ileride) |

### Gerekçe (kullanıcı davranışına dayalı; ölçülmüş veri yoktur, bkz. Riskler)
1. **Talimat §5.1:** "en önemli eylem müzik yapmaktır". Açılışta kullanıcının tek niyeti "çalmak"tır; K1 açılışı doğrudan çalma sahnesi yapar (03 §5: yalnız K1 "Evet"; K2/K3 "Kısmen"). Rehbersiz ilk kullanıcı için yapılacak tek eylem tek düğmedir (§5.4 madde 1).
2. **Karar yükü:** K2 süre/adım kararı, K3 harita+raf+düğme kararı ekler (03 §4 kullanım kolaylığı: K1 4, K2 4, K3 2). Rutinli kullanıcı "kaldığım yerden çal" ister; bu K1'in açılış hâlidir.
3. **Derinlik ayrı katmanda:** Güç isteyen kullanıcı (döngü, referans, yardım azaltma) K3'ün derinliğini ister (03 §4: K3 = 5, K1 = 3). Bunu, ekranı bölmeden, raf olarak ekleyerek K1'in zayıf noktası kapatılır.
4. **Mühendislik:** K1 maliyet 4, K2 3, K3 1. Seçilen melez yeni veri modeli GEREKTİRMEZ (kural tabanlı öneri `V1CourseState.next` + son sonuçtan türer; Hayalet basamağı ayrı yeni yerel anahtar, `V1PracticeRecord`'a dokunmaz). Pratik ekranı bölünmediği için ölçüm yüzeyinde regresyon riski artmaz.
5. **Mevcut ürünle uyum:** Tüm çıkış ekranları (akort, kurulum, alıştırma, kontrol noktası, ayarlar, hesap/üyelik) aynen yeniden kullanılır (03 §2 K1 tablo g); kurs, kapı, ücretli koruma, ölçüm ve ilerleme kayıtları değişmez (talimat §5.1, §2.5).
6. **§5.4 testi:** K1 7/7 (03 §4.1); melez aynı yedi maddeyi korur (teslimat 13).

### Reddedilenler ve nedenleri
| Seçenek | Neden reddedildi | Kısmen alınan |
|---|---|---|
| K2 Oturum Akışı olduğu gibi | Açılış oturum kapısı: §5.1'e "kısmen"; ileri/rutinli kullanıcıyı yavaşlatır; "günün çalışması" bugün yok (02 §3.A) ve deterministik kural kümesi ile pedagojik doğrulama (uzman onayı bekliyor, `expertPending`) olmadan öneri zayıf | Tek satır öneri (K1 katmanında) |
| K3 Çalışma Masası olduğu gibi | İlk kullanıcıda §5.4 madde 1 "kalır"; erişilebilirlik 2; maliyet 1; pratik ekranını araçlara bölmek ölçüm yüzeyinde regresyon riski (01 §4, §8); üst üste cam kontrast riski | Araç rafı (opak), Yol görünümü (liste önce) |
| Tam K1 (melezsiz) | Derinlik katmanlarda sınırlı kalır; profesyonel derinlik 3 | — (melez bunu kapatır) |
| Üçünü birden (tam melez) | Tutarsız gezinme ve üç kat bakım; "her konseptten bağımsız parça" ilkesine aykırı olurdu | — |

### Beş madde (DECISIONS.md biçimi)
1. **Hangi bilgi değişti:** Zihinsel model (02) ve konsept karşılaştırması (03) tamamlandı; tek omurga seçildi.
2. **Hangi delil eski varsayımı çürüttü:** Bugünkü kök, kütüphane/ders listesi ekranıdır (01: `library_screen.dart`); §5.1 ve §5.3 "ders listesi birincil yüzey olmasın" der. Kök değişmelidir.
3. **Güvenlik/maliyet farkı:** Yeni ücretli kaynak: 0 USD. Yeni bağımlılık yok. Ham ses cihazdan çıkmaz; kamera bayrakları KAPALI. Mühendislik maliyeti: üç konseptin en iyi maliyet puanı (K1 = 4; ölçekte 5 = düşük maliyet); kötüleşmez.
4. **Geri dönüş:** Kök değişimi yeni bayrakla (`ostinatoStageHomeEnabled`, varsayılan KAPALI, UX-05b) kapalı kalır; bayrak kapalıyken bugünkü kütüphane kökü çalışır. Bu ADR yeni bir ADR-UX ile geçersiz kılınabilir; kod geri alma = bayrak.
5. **Kim yararlanır:** İlk gün çalmaya başlayan, enstrümansız kulak çalışan, rutinli ve ileri gitarist (raf), ekran okuyucu kullanan (doğrusal "Yol" listesi).

### Sonuçlar ve riskler
| Risk | Etki | Önlem |
|---|---|---|
| Üç tutamak (Başka çalış, Yolum, Ayar) küçük gezinme öğrenme maliyeti ekler | Keşfedilebilirlik | Tutamaklar çalma dışında hep görünür, metin etiketli (yalnız simge değil); §5.4 madde 2–3, 6 senaryoları (teslimat 13) |
| Katmanlar için klavye/ekran okuyucu eşdeğeri gerekir (03 §6) | Erişilebilirlik borcu | Teslimat 10 kuralları; UX-05h kabul ölçütü |
| Cam bulanıklığı düşük donanımda performans | Takılma | Teslimat 6 bütçesi + opak yedek; ölçülmedi (03 §7), UX-05a'da cihaz ölçümü kabul ölçütü |
| Kural tabanlı öneri pedagojik doğrulanmadı | Yanlış yönlendirme | Öneri "öneri" etiketli, deterministik, yetkinlik iddiası yok; mikro-etüt "araştırma" etiketli, kapsam dışı |
| Hayalet Ekran bugün yok | Yeni davranış, ölçüm güvenilirliğine bağlı | Ek B: manuel basamak, güvenilmeyen ölçümde iddia yok; bayrak KAPALI |
| Puanlar ve §5.4 sonuçları yazar değerlendirmesi | Yanlış varsayım | Aşama 6 etkileşimli prototip ve kullanıcı testi sonuçları bu ADR'yi gözden geçirtir |

---

## 1. Tasarım vizyonu ve etkileşim felsefesi

**Vizyon:** Ostinato açıldığında kullanıcı doğrudan çalma sahnesindedir. Uygulama bir "ders listesi" değil bir "çalma yüzeyi"dir; yapılacak her şey (ne çalacağım, nasıl gidiyorum, nasıl kurulur) sahnenin üstüne, ihtiyaç anında açılan geçici katmandır.

**İlkeler (talimat §2 ve §5'e bağlı):**
| # | İlke | Somut davranış |
|---|---|---|
| 1 | Önce müzik (§5.1) | Açılış = devam edilen alıştırmanın sahnesi + tek büyük "Çal" |
| 2 | Odak çalınan müzikte (§5.2.B) | Çalarken tutamaklar ve katmanlar gizli; hata olunca ekran DURMAZ; sayaç nötr (✓ ◆ ◯), yargı dili yok |
| 3 | Dürüst ölçüm (§5.2.H, §5.3) | Güvenilmeyen ölçümde "duyamadım" (◯) + neden; kesin hüküm yok; "yanlış/wrong" gösterilmez |
| 4 | Cam = işlev (§2.3) | Cam yalnız geçici katmanda; ana çalma yüzeyi opak; aynı kartlarla dolu ekran yok |
| 5 | Kontrol kullanıcıda | Hayalet basamağı elle seçilir; öneri varsa yalnız öneridir |
| 6 | Gerçek yetenekler korunur (§2.5) | Kurs, kapı, ücretli koruma, enstrüman desteği, ilerleme kayıtları aynen kalır |
| 7 | İzin yoksa da deneyim var (§5.4-7) | Mikrofon reddi: "Dinleme kapalı" kipi; kamera hiçbir akışta zorunlu değil |

**Değişmeyenler:** renk paleti, tipografi, marka ("YULA Lab" kullanıcıya dönük metinde), kurs verisi, ölçüm eşikleri (`expertPending`), kamera bayrakları KAPALI.

---

## 2. Bilgi mimarisi ve navigasyon haritası

```
KÖK = SAHNE (pratik)
 |-- <Başka çalış>  katman (alttan)   : öneri satırı, aynı alıştırma, Gitar/Kulak (enstrümansız), Akort, son gelişim
 |      |-- Kulak kipi (sahne kulak kipine geçer)
 |      |-- Akort (tam ekran çıkış, geri = sahne)
 |-- <Yolum>        katman (sağdan)   : [Yol] liste: seviye > modül > ders, "neden bu" · [Geçmiş] bölüm denemeleri, haftalık hedef
 |-- <Ayar>         katman (alttan)   : Cihaz (mikrofon, gecikme/kalibrasyon, gürültü, erişilebilirlik), Ayarlar, Hesap/Üyelik
 |-- Sonuç katmanı  (Dur sonrası, alttan) : özet, Tekrar dene / Sonraki
 |-- Araç rafı      (sahnede opak, isteğe bağlı) : Metronom, Referans, Döngü, Yardım (Hayalet)
 Çıkış ekranları (tam ekran, geri = sahne): Akort, Kurulum sihirbazı, Alıştırma, Kontrol noktası,
                                             Ayarlar, Hesap/Üyelik, Ders okuyucu
```

**Kurallar:** (1) Her yerden geri = bir önceki sahne durumu; çıkmaz sokak yok. (2) Çalarken hiçbir katman açılamaz (teslimat 6). (3) Ders listesi yalnız "Yolum > Yol" içinde. (4) Bayrak KAPALIyken bugünkü kök (`library_screen.dart`) çalışır. (5) Tutamaklar çalma dışında hep görünür ve metin etiketlidir; ekran okuyucu sırası: Çal → tutamaklar → durum.

**§5.2 alanlarının yeri** (03 K1 tablo c + melez eklemeleri):
| Alan | Konum |
|---|---|
| A. Stüdyo/Başlangıç | Sahne (devam) + "Başka çalış" katmanı |
| B. Canlı pratik | Sahne |
| C. Öğrenme yolculuğu/Dersler | "Yolum > Yol" |
| D. Hayalet Ekran | Sahne parametresi + araç rafı "Yardım" |
| E. Kişiselleştirilmiş alıştırmalar | Sonuç katmanında "Şunu dene" + "Başka çalış"; ilk aşama deterministik `drill_generator.dart`; mikro-etüt kapsam dışı ("araştırma") |
| F. Kulak ve ritim | "Başka çalış > Enstrümansız" → kulak kipi |
| G. İlerleme/geçmiş | "Yolum > Geçmiş" + Sonuç katmanı |
| H. Kurulum | "Ayar > Cihaz" + bağlamsal (kalibre et önerisi) |

---

## 3. Bütün temel ekranların listesi

| # | Ekran / yüzey | Tür | Bugünkü karşılık (03 §2 K1 g) | Durum |
|---|---|---|---|---|
| S1 | Sahne (pratik) | Kök | `practice_loop_screen.dart` + parçaları | Yeniden kullanılır, kök Yeni |
| S2 | Başka çalış | Katman | `library_screen.dart` kartları, `instrument_screen.dart` | Yeni kabuk |
| S3 | Yolum: Yol | Katman | `v1_practice_list_screen.dart`, `v1_lesson_reader_screen.dart` | Kabuk Yeni |
| S4 | Yolum: Geçmiş | Katman | `weekly_goal_card.dart`, `V1PracticeRecord` okuma | Okuma Yeni |
| S5 | Sonuç | Katman | `practice_result_screen.dart` | Yeniden düzenlenir |
| S6 | Ayar / Cihaz | Katman | `setup_wizard_screen.dart` bağlamı | Yeni kabuk |
| S7 | Kulak kipi | Sahne kipi | `drill_screen.dart`, `test_flow_screen.dart`, `reference_listen_bar.dart` | Kip Yeni |
| S8 | Araç rafı | Sahne ögesi | `practice_transport.dart`, `reference_listen_bar.dart`, `practice_tempo_ladder.dart` | Sarmalayıcı Yeni (ekran bölünmez) |
| S9 | Hayalet ayarı | Raf satırı | — | Yeni |
| X1 | Akort | Çıkış (tam ekran) | `tuner_screen.dart` | Aynen |
| X2 | Kurulum sihirbazı | Çıkış | `setup_wizard_screen.dart` | Aynen |
| X3 | Alıştırma / Kontrol noktası | Çıkış | `drill_screen.dart`, `test_flow_screen.dart` | Aynen |
| X4 | Ayarlar | Çıkış | `lib/app/screens/settings_screen.dart` | Aynen |
| X5 | Hesap/Üyelik | Çıkış | `ostinato_membership_page.dart`, `ostinato_paid_access.dart`, `account_connection.dart` | Aynen (davranış değişmez) |
| X6 | Karşılama (ilk açılış) | Ekran | mevcut onboarding (03 evidence render 01–03) | Aynen; sonra S1 |

---

## 4. Mobil ve masaüstü kullanım stratejisi

Birincil hedef telefon dikey (ürün mobil uygulamadır; masaüstü hedefi 01'de yok, U). Kurallar:
| Konu | Telefon dikey | Tablet / geniş / yatay (öneri) |
|---|---|---|
| Sahne | Tek sütun; şerit üstte ~%40 hep görünür katman açıkken | Şerit geniş kalır; "Yolum" çekmecesi sağ panel olarak SAHNENİN YANINDA kalıcı açılabilir (cam değil opak panel) |
| Katman | Alttan (Başka çalış, Ayar), sağdan (Yolum); sahneyi kapsamaz | Katman kenar paneli; sahne çalarken panel yine kapalı |
| Dokunma hedefi | En az 48 dp; Çal düğmesi baş parmak alanında | Aynı |
| Büyük metin | Metin ölçeği 2.0'a kadar kırılmaz; etiketli tutamaklar iki satıra iner | Aynı |
| Yön | Dikey birincil; yatayda sahne tam genişlik, katman yan | Aynı |
| Girdi | Dokunma; harici klavyede Tab sırası ve boşluk = Çal/Dur (U: bugün doğrulanmadı) | Klavye kısayolları ikincil, zorunlu değil |
Masaüstü ayrı bir sürüm olarak ELE ALINMAZ (kapsam dışı; web/masaüstü hedefi bu ADR'de yok). Yatay/tablet düzeni UX-05h'de yalnız "kırılmıyor" düzeyinde kabul edilir.

---

## 5. Her temel ekranın ayrıntılı wireframe'i

Gösterim (03 §3 ile aynı): `▒` opak ana yüzey, `░` cam katman, `[ ]` düğme, `< >` tutamak, ✓ doğru · ◆ farklı nota · ◯ duyamadım (`practice_marks.dart`), `●` mikrofon durumu. Renk/tipografi/marka içermez.

### 5.1 Sahne (açılış, çalmıyor)
```
+----------------------------------+
| Altıncı telde notalar   <Ayar>   |
| Devam: 2. seviye > modül 3       |
|  ▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒   |
|  ▒ ─────┃── (ŞİMDİ) ──────── ▒   |
|  ▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒   |
|  ♩=50   ● mikrofon hazır         |
|  Raf ▸  (kapalı; opak)           |
|         [      Çal      ]        |
| <Başka çalış>  <Yolum>  <Ayar>   |
+----------------------------------+
```
Raf kapalı başlar; "Raf ▸" tek satırdır, açılınca opak satırlar belirir (Metronom, Referans, Döngü, Yardım). Cam yok.

### 5.2 Canlı pratik (çalarken)
```
+----------------------------------+
| ♩=50  ● dinliyor            [Dur]|
|  ▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒   |
|  ▒  ✓  ✓  ◆  ✓  ◯   ┃  ...   ▒  |
|  ▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒   |
|  ✓4  ◆1  ◯1   (yargı yok)       |
| (tutamak yok · katman yok ·      |
|  ekran durmaz · bulanıklık yok)  |
+----------------------------------+
```

### 5.3 Başka çalış (alttan katman)
```
+----------------------------------+
|▒ şerit görünür (üst %40) ▒▒▒▒▒▒▒|
|░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░|
|░ Öneri: "2. ölçüyü yavaş tekrar" |
|░                         [Çal]  ░|
|░ [Gitar] [Kulak: enstrümansız]  ░|
|░ [Aynı alıştırma] [Akort]       ░|
|░ Son gelişim: ✓6 ◆1 ◯1          ░|
|░ (öneri satırı: kural tabanlı)  ░|
+----------------------------------+
```

### 5.4 Yolum (sağdan katman): Yol ve Geçmiş
```
Yol (liste; ekran okuyucu birincil)    Geçmiş
+---------------------------+          +---------------------------+
| Yolum   [Yol*][Geçmiş]    |          | Yolum   [Yol][Geçmiş*]    |
| Seviye 1                  |          | Bu bölüm                  |
|  Modül 1  tamamlandı      |          |  dün    ✓5 ◆2 ◯1  (duyulan%)|
|  Modül 2  geçit geçildi   |          |  bugün  ✓6 ◆1 ◯1          |
|  Modül 3  sıradaki *      |          | Zorlandığım: 2. ölçü      |
|   neden: "2. modülün      |          | En iyi: doğruluk, duyulan,|
|   geçidi geçildi"         |          |  tempo (kayıttan okunur)  |
| Seviye 2   ·ücretli/kilit |          | Haftalık hedef (düz satır)|
| Kulak     ritim ✓ aralık o|          | Önerilen sonraki adım     |
+---------------------------+          +---------------------------+
```
Durumlar yalnız `V1PracticeRecord` / `V1LessonCheck` olgularından (geçit, tamamlama, ölçülmedi/öz-bildirim ayrımı); yeni beceri adı ya da yetkinlik yüzdesi yok.

### 5.5 Sonuç katmanı
```
+----------------------------------+
|░ Bu koşu                         ░|
|░ ✓6  ◆1  ◯1   duyulan %88       ░|
|░ Nerede oldu: 2. ölçü (çubuk)   ░|
|░ Duyamadım: 1 nota · sebep: kısık░|
|░ Bir düzeltme: "ikinci ölçü ...  ░|
|░ [Tekrar dene]  [Sonraki]  [Döngü]░|
+----------------------------------+
```

### 5.6 Hayalet Ekran (dört basamak; Raf > Yardım)
```
Öğrenme   : nota ▒ tab ▒ vuruş ▒ etiket ▒   (tam yardım)
Pekiştirme: nota ▒ tab ▒ vuruş ▒ etiket –   (etiket kalkar)
Hatırlama : nota – (başlamadan 3 sn göster) · vuruş çizgisi ▒
Bağımsız  : yüzey boş; yalnız metronom (isteğe bağlı) · "ipucu" düğmesi
Seçici: [Öğrenme][Pekiştirme][Hatırlama][Bağımsız]  (elle; öneri varsa ince satır)
```

### 5.7 Kulak kipi (enstrümansız)
```
+----------------------------------+
| Kulak · enstrümansız   <Sahneye> |
| Etiket: [Ekranda cevap]          |  ← ölçüm biçimi etiketi:
|  ▒ dinle → seç ▒▒▒▒▒▒▒▒▒▒▒▒▒    |     Ekranda cevap / Alkış (mikrofon) /
|  [ Çal ] [ Tekrar dinle ]        |     Söyle (öz-kontrol)
| Sonuç: ekran alıştırması doğruluğu|
| (enstrüman ilerlemesine SAYILMAZ)|
+----------------------------------+
```

### 5.8 Ayar / Cihaz
```
+----------------------------------+
|░ Cihaz                           ░|
|░ ● Mikrofon: hazır   [Ayarlar]  ░|
|░ Gecikme: kalibre edilmedi [Kalibre et]|
|░ Ortam gürültüsü: [Ölç]          ░|
|░ Erişilebilirlik: hareket, saydamlık (sistemi izler)|
|░ [Ayarlar]  [Hesap/Üyelik]       ░|
+----------------------------------+
```

### 5.9 İzin reddi (mikrofon) sahnesi
```
+----------------------------------+
| ● Dinleme kapalı · ölçülmüyor    |
|  ▒ şerit, metronom ▒▒▒▒▒▒▒▒▒     |
|  [Şu hızda dinle]  [Çal (kendin değerlendir)]|
|  Sayaç yerinde: "ölçülmüyor"     |
|  Kulak (enstrümansız) önde       |
|  Ayarlara git (susturulabilir)   |
+----------------------------------+
```

---

## 6. Glass tasarım sisteminin bileşen ve davranış kuralları

Talimat §2.3: cam işlevseldir, ekran aynı kartlarla dolu olmaz. Renkler/marka mevcut tema belirteçlerinden gelir; bu belge renk icat etmez. Mevcut bileşen: `lib/app/design/widgets.dart` `GlassCard` (K).

**Neyin cam olduğu:**
| Cam (geçici katman) | Opak (cam DEĞİL) |
|---|---|
| Başka çalış, Yolum, Ayar, Sonuç katmanı; karşılaştırma/önizleme benzeri geçici üst yüzeyler | Sahne (şerit, ŞİMDİ çizgisi, tempo, Çal), araç rafı satırları, Yol listesi gövdesi içindeki metin satırları, tüm tam ekran çıkışlar |

**Katman sayısı:** En fazla **iki cam öğe** aynı anda açık ([`03-concepts.md`](03-concepts.md) K2 ve K3 "(d) Glass katman ilişkisi" paragrafları, OST-UX-02 reviewer düzeltmesi). Pratikte: tek katman (Başka çalış / Yolum / Ayar / Sonuç) açıkken ikincisi açılırsa birincisi kapanır (yığılma yok); ikinci cam öğe yalnız katmanın içinde geçici onay/açıklama için kullanılır (ör. bir bilgi balonu). Üçüncü açılamaz.

**Çalarken:** Cam öğe sayısı 0, istisna yok. Kullanıcının sabitlediği metronom görünümü varsa TAMAMEN OPAK araç rafı ögesidir (cam değil, bulanıklık yok, sahneyi kapsamaz).

**Bulanıklık bütçesi:**
| Kural | Değer |
|---|---|
| Aynı anda arka plan bulanıklığı çizen yüzey | ≤ 1 |
| Bulanıklık yalnız katman AÇIKKEN çizilir; sahne çalarken ve katman kapanırken çizilmez | Zorunlu |
| Bulanıklık yarıçapı (sigma) üst sınırı | ≤ 16 mantıksal piksel (öneri; UX-05a cihazda ölçüp sıkılaştırabilir) |
| Bulanık alan | Ekranın en çok ~%60'ı (katman sahneyi kapsamaz: üstten ~%40 şerit açık kalır) |
| Düşük donanım yedeği | Kare süresi bütçesi aşılırsa ya da sistem "düşük güç/saydamlığı azalt" derse bulanıklık KAPANIR, katman opak çizilir (U: eşik cihazda ölçülmedi) |

**Kontrast:** Katman üzerinde metin ≥ 4.5:1, büyük metin ve düğme/simge sınırı ≥ 3:1; bu oran EN KÖTÜ arka plan (bulanık sahne altı) için sağlanmalıdır. Sağlanamıyorsa katman opak çizilir. İşaretler (✓ ◆ ◯) yalnız renkle ayırt edilmez; şekil + metin etiketi taşır.

**Azaltılmış hareket ve saydamlık:** Sistem "hareketi azalt" açıksa katman geçişi anlıktır, paralaks/yansıma animasyonu yok; "saydamlığı azalt/kontrastı artır" açıksa tüm cam katmanlar opak. Bugün: yalnız sayfa geçişi `MediaQuery.disableAnimationsOf` ile hareketsiz (K, `lib/app/app_theme.dart`); saydamlık yolu YENİ.

**Hareket süreleri (öneri):** katman açılış/kapanış 200–300 ms, çıkış hızlıdır; oynatma sırasında katman animasyonu yok; ışık/yansıma efekti yalnız katman kenarında, statik (hareketli ışık yok).

**Dokunma ve odak:** Katman açıkken sahne durur ve etkileşim dışıdır (ekran okuyucuya "arka plan" olarak gizlenir); katman dışına dokunma/geri = kapat; odak katman açılınca katmanın ilk öğesine, kapanınca tutamağa döner.

---

## 7. Ekranlar arası geçişler

| Geçiş | Davranış | Hareketi azalt |
|---|---|---|
| Karşılama → Sahne | Bir kez; sonra daima Sahne | Anlık |
| Sahne → katman (tutamak) | Alttan/sağdan 200–300 ms; sahne durağan + bulanık | Anlık, opak |
| Katman → Sahne | Ters yön; bulanıklık kalkar | Anlık |
| Çal → Dur → Sonuç | Dur ile Sonuç katmanı alttan; sahne üstte kalır | Anlık |
| Sonuç → Tekrar dene | Katman kapanır, sahne aynı bölümde hazır (çubuğa dokun = döngü, bugünkü davranış, T) | Anlık |
| Katman → çıkış ekranı (Akort, Ayarlar...) | Tam ekran, platform geçişi; geri = sahne | Platform: hareketsiz |
| Kulak kipi ↔ gitar kipi | Sahne içinde kip değişimi (etiketli); kayıtlar ayrı | Anlık |
| İzin reddi | Sahne "Dinleme kapalı" kipinde açılır, geçiş yok | — |
**Kural:** Çalarken hiçbir geçiş tetiklenmez (bildirim/ katman/ çıkış yok).

---

## 8. Gerçek veriyle çalışan ve boş veri durumları

| Yüzey | Gerçek veri | Boş / ilk kullanım |
|---|---|---|
| Sahne açılış | `V1CourseState.next` dersi; yoksa ilk ölçülü ders | Kayıt yok: "Başla: ilk alıştırma", devam satırı yerine "Yeni başlıyorsun" nötr metin |
| Öneri satırı | Son hata türü + `next` (kural tabanlı) | Kayıt yok: satır gizlenir (öneri uydurma yok) |
| Yolum > Yol | `v1_course_catalog.dart` seviye > modül > ders; kapı/ücretli işaretleri | Tüm dersler "dokunulmadı", sıradaki ders işaretli |
| Yolum > Geçmiş | `V1PracticeRecord` (`bestAccuracy/bestHeard/bestBpm`, geçit/tamamlama tarihleri), `V1LessonCheck` (ölçülmedi/ölçüldü ayrımı), haftalık hedef | "Henüz koşu yok. Bir kez çal; burada görünür." Puan/seri baskısı yok |
| Sonuç | Koşunun ✓ ◆ ◯, duyulan %, hata haritası, geçit | Koşu yarıda: "Koşu tamamlanmadı", ölçüm yok (unmeasured) |
| Hayalet | Basamak (yeni yerel anahtar) + son uygun koşular | Kayıt yok: Öğrenme basamağı, öneri yok |
| Kulak | Ekran alıştırması sonuçları (kendi kaydı) | Boş: "Dinle ve seç ile başla" |
Her sayı kayıttan okunur; yeni beceri adı, yetkinlik yüzdesi, rozet/puan icat edilmez. Mevcut veri modelinde değişiklik yok.

---

## 9. Yüklenme, çevrimdışı, hata, izin reddi ve onay durumları

| Durum | Sahne/yüzey davranışı | Metin ilkesi |
|---|---|---|
| Yükleniyor (kurs/kayıt okuma) | Sahne iskeleti hemen çizilir; "Çal" etkin olmadan önce yalnız gerekli veri bekler; döner gösterge yalnız 400 ms'yi aşarsa | Nötr |
| Çevrimdışı | Pratik, kulak, akort, yerel kayıtlar çalışır; bulut/hesap/üyelik/senkron yüzeyleri "çevrimdışı, sonra denenir" der (U: her akışın çevrimdışı davranışı 01'de doğrulanmadı, UX-05h'de kanıtlanır) | Suçlayıcı değil |
| Hata (veri okuma/kayıt) | Sahne açık kalır; hata katmanı "tekrar dene" + ayrıntı gizli; ilerleme kaydı sessizce kaybolmaz (yazılamadıysa bildirir) | Yargı yok |
| Mikrofon reddi / kapalı | "Dinleme kapalı" kipi (5.9): ölçüm yok, öz-kontrol, kulak enstrümansız; Ayarlara git bağlantısı susturulabilir | "Ölçülmüyor" |
| Mikrofon güvenilmez (ortam/kırpma/kısık) | "Duyamadım" ailesi, aşağıdaki alt başlık | Aşağıda |
| Kamera | Hiçbir akış kamera istemez (bayraklar KAPALI); bayrak ileride açılırsa yalnız K8 dersi (`gtr-s1-m01-02`, `-03`) açılınca istenir, reddedilirse ders kamerasız atlanır/öz-bildirim; bu akışın bugünkü kodda davranışı doğrulanmadı (U) | Bu belge öneridir |
| Onay (silme/çıkış/üyelik) | Yıkıcı eylemde (kayıt silme, hesap çıkışı) açık onay iletişim kutusu; ücretli kapı mevcut `ostinato_paid_access.dart` korumasıyla aynı | Net, "geri alınamaz" ise söylenir |
| Pratik ortasında çıkış | Yarım koşu kaydı "tamamlanmadı" = ölçülmedi; kapıyı AÇMAZ | — |

### Güvenilmeyen ölçümde dürüst durum ("duyamadım" ailesi)
Mevcut OST-P0-04 / ölçüm kurallarıyla eşleşir (belge: [`../MEASUREMENT-OST-P0-03-04.md`](../MEASUREMENT-OST-P0-03-04.md); kod: `lib/app/practice/loop/practice_marks.dart`, `practice_outcome.dart`; `GuitarPitchObserver` ve `assets/config/guitar-observation.v2.json` yalnız ölçüm raporundaki adıyla anılır, kaynak yolu bu belgede okunmadı):
| Kural (kaynakta) | Arayüzde |
|---|---|
| Nota başına ◯ "duyamadım" + sebep: `noAttack`, `tooQuiet` (oda tabanı + 6 dB), `tooLoud` (kırpma), `unclear` (perde çözülemedi/çok ses/kararsız), `appPlayback` (uygulama sesi duyuldu), `skipped` (Bekle) (K) | Sebep metni düz: "kısık", "çok yüksek", "net ayıramadım", "uygulama sesi karıştı" |
| Çok sesli giriş: ürün yolunda 28/28 reddedilir (`multipleSources`/`notPeriodic`), yanlış hüküm 0/28; sapma ±40/±50 cent: hüküm yok (`maxCenterErrorCents` 35); gürültü-only: `mayJudge` 0/8 (T, sentetik) | "Net ayıramadım, tekrar dener misin?" tonu; nota "yanlış" DENMEZ |
| Doğruluk yalnız karar verilenler üzerinden; duyulamayan notalar doğruluğun dışında (K) | Sonuçta "duyulan %" ve doğruluk AYRI satır |
| Geçit: doğruluk ≥ %80 ve duyulan ≥ %80 (notaların beşte birinden fazlası duyulamazsa set geçersiz, `PassCriteria.minHeard`), tempo kuralı (K); eşikler `expertPending` | Geçit metni değişmez; eşik değişikliği bu belgenin kapsamında değil |
| Duyulan < %80 → sonraki adım "kurulumu kontrol et" (`NextStep.checkSetup`) (K) | "Ortamı/mikrofonu kontrol et" önerisi, suçlama yok |
| Hiçbir yerde "yanlış/wrong" gösterilmez; ◆ "farklı nota" bilgidir | Metin sözlüğü: ◆ = "farklı nota duyuldu" |
Güvenilmeyen ölçümde: doğruluk %'si gösterilmez ya da "ölçülemedi" yazılır; yetkinlik cümlesi yok; Hayalet basamağı yükselme önerisi yok (Ek B).

---

## 10. Erişilebilirlik ve performans kuralları

| Konu | Kural |
|---|---|
| Ekran okuyucu | Her tutamak ve düğme etiketli; sıra Çal → tutamaklar → durum; katman açılınca odak katmana, kapanınca tutamağa; Yol listesi doğrusal eşdeğer; ✓ ◆ ◯ metin etiketi okunur ("doğru", "farklı nota", "duyamadım") |
| Renk | İşaretler renkle tek başına ayrılmaz; mevcut palet korunur |
| Kontrast | Teslimat 6: 4.5:1 / 3:1; sağlanamayan cam opaklaşır |
| Hareket | Sistem ayarını izler; çalarken hareket yok; ışık/yansıma statik |
| Saydamlık | Sistem "saydamlığı azalt" = opak katman (YENİ yol) |
| Büyük metin | 2.0 ölçeğe kadar taşma yok; katman kaydırılabilir |
| Dokunma hedefi | ≥ 48 dp; Çal/Dur ayrı ve büyük |
| Zaman baskısı yok | Süre sınırı/geri sayım zorunlu değil; "Bekle" mevcut |
| Ses | Metronom ve referans görsel alternatifli; ham ses cihazdan çıkmaz, kayıt saklama bayrakları KAPALI (`ostinatoRecordingRetentionOpen=false`) |
| Performans | Bulanıklık bütçesi (teslimat 6); çalarken ek çizim yok; çalma karesi 60 fps hedefi (UX-05a'da cihazda ölçülür, U); şerit/ölçüm yolu değişmez |
| Güç tasarrufu | Düşük güç modunda bulanıklık kapalı |

---

## 11. Yeni ve mevcut bileşenlerin eşleştirilmesi

| Bugünkü | Yeni deneyimde | Karar |
|---|---|---|
| `practice_loop_screen.dart`, `practice_tab_strip.dart`, `metronome_beat_view.dart`, `practice_transport.dart`, `practice_tempo_ladder.dart`, `reference_listen_bar.dart` | Sahne çekirdeği + raf | Yeniden kullanılır; ekran BÖLÜNMEZ; raf bu parçaların sarmalayıcısı |
| `practice_result_screen.dart` | Sonuç katmanı | Yeniden düzenlenir; içerik (6/1/1, hata haritası, geçit) korunur |
| `practice_marks.dart` (`HearingReason`, ✓◆◯) | Nota işaretleri ve "duyamadım" ailesi | Aynen |
| `practice_outcome.dart` (`PassCriteria`, `GateIneligible`) | Geçit ve unmeasured koşu | Aynen (eşik değişmez) |
| `lib/app/screens/library_screen.dart` | Kalkar (bayrakla); kök = sahne | Yeni kök |
| `v1_practice_list_screen.dart`, `v1_lesson_reader_screen.dart` | "Yolum > Yol" içi | Yeniden kullanılır, kabuk yeni |
| `instrument_screen.dart`, `coming_soon_instrument_screen.dart` | "Başka çalış" içi çalgı seçimi | Birleşir |
| `tuner_screen.dart`, `setup_wizard_screen.dart`, `drill_screen.dart`, `test_flow_screen.dart` | Çıkış ekranları | Aynen |
| `weekly_goal_card.dart` | "Yolum > Geçmiş" düz satır | Yeniden kullanılır |
| `settings_screen.dart`, `ostinato_membership_page.dart`, `ostinato_paid_access.dart`, `account_connection.dart` | Ayar çıkışları | Aynen |
| `session_store.dart`, `V1PracticeRecord`, `V1LessonCheck` | Geçmiş (okuma) | Okuma Yeni, veri değişmez |
| `lib/app/design/widgets.dart` `GlassCard` | Katman yüzeyi | Mevcut `GlassCard` sigma 18 çizer (widgets.dart, 01-audit.md); yeni katman yüzeyi `GlassLayer`'da sigma ≤ 16; `GlassCard`'ın kendisi değişmez. Opak yedek ve saydamlık yolu YENİ |
| `listen_try_fix.dart` (bayrak `ostinatoListenTryFixRepeatOpen=false`) | Şunu dene (ileride) | Bayrak KAPALI kalır; ilk aşama `drill_generator.dart` |
| `first_minutes/first_three_minutes_screen.dart` (bayrak kapalı) | Kapsam dışı | Aynen kapalı |
| Yeni | Sahne kabuğu, `GlassLayer` + katman yöneticisi, araç rafı sarmalayıcısı, Hayalet basamak ayarı ve ayrı yerel store, geçmiş okuma görünümü, kural tabanlı öneri | Yeni |
Yeni bayraklar (hepsi KAPALI varsayılan, `ostinato_release_policy.dart` benzeri): `ostinatoStageHomeEnabled` (UX-05b), `ostinatoGhostScreenEnabled` (UX-05g).

---

## 12. Mevcut ekranlardan yeni deneyime geçiş planı

Hiç büyük patlama yok: her adım bayrak arkasında, bugünkü kök bayrak KAPALIyken çalışır; her adım ayrı PR.
| Adım | İş | Bilet | Bayrak | Geri dönüş |
|---|---|---|---|---|
| 0 | Belge (bu PR) | OST-UX-03 | — | — |
| 1 | `GlassLayer` + opak yedek + saydamlık/hareket yolu | UX-05a | yok (bileşen) | Kullanılmayabilir |
| 2 | Sahne kabuğu + kök değişimi | UX-05b | `ostinatoStageHomeEnabled` KAPALI | Bayrak kapalı = eski kök |
| 3 | Katman yöneticisi + Başka çalış | UX-05c | aynı | Aynı |
| 4 | Yolum (Yol + Geçmiş) | UX-05d | aynı | Aynı |
| 5 | Sonuç katmanı + dürüst durum | UX-05e | aynı | Aynı |
| 6 | İzin reddi + Ayar/Cihaz | UX-05f | aynı | Aynı |
| 7 | Hayalet Ekran | UX-05g | `ostinatoGhostScreenEnabled` KAPALI | Bayrak |
| 8 | Erişilebilirlik, çevrimdışı/hata, test senaryoları, ekran kanıtı | UX-05h | — | — |
**Ürün açılışı (bayrakları AÇMAK) bu planın DIŞINDADIR:** kurucu kararı ve cihaz kanıtı ister; mağaza/fiyat/üyelik kararları ayrıdır.
Veri geçişi YOK: kurs verisi, ilerleme, ücretli koruma değişmez; Hayalet basamağı yeni yerel anahtar (eski kayıtlara dokunmaz).

---

## 13. Kullanıcı deneyimi test senaryoları

Hepsi rehbersiz, bayrak AÇIK (test ortamında) ve KAPALI karşılaştırması ile; kanıt = test render/ekran görüntüsü yolu + test adı. Not: kullanıcıyla (insan) test yapılmadı; bunlar uygulama sonrası koşulacak senaryolardır.
| # | Talimat §5.4 | Senaryo | Beklenen |
|---|---|---|---|
| T1 | 1 Pratiğe başlama | İlk açılışta (karşılamadan sonra) kullanıcı çalmaya başlar | Tek dokunuşla "Çal"; mikrofon izni ilk Çal'da istenir |
| T2 | 2 Enstrümansız çalışma | "Başka çalış > Kulak (enstrümansız)" | En çok iki dokunuş; kulak kipi, mikrofon gerektirmeyen ekran alıştırması |
| T3 | 3 Öğrenme yolculuğu | "Yolum > Yol" | Seviye > modül > ders listesi; sıradaki ders ve "neden bu" satırı görünür |
| T4 | 4 Hatayı anlama | Hatalı koşu → Sonuç | ◆ "farklı nota", "Nerede oldu" çubuğu, tek düzeltme; "yanlış" kelimesi yok |
| T5 | 5 Aynı bölümü tekrar | Sonuçta Tekrar dene / çubuğa dokun | Aynı bölüm hazır; döngü çalışır |
| T6 | 6 İlerleme geçmişi | "Yolum > Geçmiş" | Önceki denemeler yan yana; duyulan % ayrı satır |
| T7 | 7 İzin yok | Mikrofon reddi | "Dinleme kapalı" kipi; şerit, metronom, referans, kulak çalışır; ölçüm yok |
| T8 | 7 Kamera | Kamera bayrağı KAPALI | Hiçbir akış kamera istemez |
| T9 | Hayalet | Basamağı elle seç; ölçüm güvenilmezken yükselme önerisi | Öneri yok; "ölçülmedi" |
| T10 | Güvenilmez ölçüm | Çok sesli giriş / gürültü | ◯ + sebep; doğruluk yargısı yok |
| T11 | Kulak ≠ enstrüman | Kulak alıştırması yap | Enstrüman geçidi/Hayalet basamağı DEĞİŞMEZ |
| T12 | Erişilebilirlik | Ekran okuyucu, büyük metin, hareketi/saydamlığı azalt | Sıra doğru; kırılma yok; katman opak, hareketsiz |
| T13 | Çalarken | Çalarken tutamak/katman arama | Hiçbiri yok; ekran hatada durmaz |
| T14 | Yarım koşu | Dur / döngü / Bekle kullanımı | Koşu "ölçülmedi" (unmeasured), geçidi açmaz |

---

## 14. Uygulama backlog'u ve kabul kriterleri

Tam bölüm: **[`04-backlog-ux-05.md`](04-backlog-ux-05.md)**, başlık **"UX-05a…h alt biletleri: kabul ölçütleri"** (sekiz alt bilet a–h; her biri için test türü, ekran kanıtı, bayrak KAPALI varsayılan).

---

# Ek: Hayalet Ekran ve ölçüm kuralları (teslimat 5–9'un bağlayıcı içeriği)

> Bu ek yeni bir teslimat değildir; teslimat 5 (wireframe), 6 (glass), 9 (güvenilmeyen ölçüm) kurallarını tek yerde bağlar. UX-05e ve UX-05g bu ekten kabul alır.

## A. Canlı pratikte odak
1. Çalarken: tutamak yok, katman yok, bulanıklık yok, hata olunca ekran DURMAZ (kural 2).
2. Sayaç nötr: ✓ ◆ ◯ sayıları; "yanlış", kırmızı ceza, titreşim/ses cezası yok.
3. Değerlendirme yalnız Dur / bölüm bitişi sonrası Sonuç katmanında.

## B. Hayalet Ekran: dört basamak ve geçiş koşulları
| # | Basamak | Yardım | Geçiş koşulu (yukarı) | Aşağı |
|---|---|---|---|---|
| 1 | Öğrenme | Nota, tab, vuruş çizgisi, etiket tam | Kullanıcı seçer; ya da ÖNERİ: bu bölümde bu basamakta bir tam ölçülmüş koşu geçti | Her an elle |
| 2 | Pekiştirme | Etiketler kalkar; nota/tab/vuruş durur | Kullanıcı seçer; ÖNERİ: iki ayrı ölçülmüş koşu geçti (öneri parametresi, kurucu eşiği değil) | Her an elle |
| 3 | Hatırlama | Nota yalnız başlamadan kısa gösterilir; yalnız vuruş çizgisi | Kullanıcı seçer; ÖNERİ: üç ayrı ölçülmüş koşu geçti (öneri parametresi) | Her an elle |
| 4 | Bağımsız | Yüzey boş; metronom isteğe bağlı; "ipucu" düğmesi | — (son basamak) | Her an elle |
**Kurallar:**
- Basamak ELLE seçilir; otomatik yükseltme yok. Öneri yalnız ince satır olarak çıkar.
- "Ölçülmüş geçen koşu" = tam koşu (yarıda bırakılmamış), döngü/Bekle kullanılmamış, mevcut `PassCriteria` geçidini (doğruluk ≥ %80 ve duyulan ≥ %80) geçmiş. Kısmi (`GateIneligible.stoppedEarly`), döngülü (`loopUsed`) ve Bekle'li (`waitUsed`) koşu "unmeasured"dır: yetkinlik/öneri üretmez, geçidi açmaz (kodda K; OST-P0-07/#74 ile aynı olacağı varsayılır: #74 bu dalın tabanında birleşmemiştir, birleşince UX-05g'de doğrulanır, U).
- Ölçüm güvenilir değilse (duyulan < %80, `appPlayback`, çok sesli, kırpma, kısık, mikrofon reddi): basamak önerisi YOK, "yetkinlik kazanıldı" ibaresi YOK, sonuç "değerlendirilemedi/ölçülmedi" yazar; kullanıcı yine elle basamak seçebilir (öz-kontrol).
- Hayalet basamağı yeni, ayrı yerel anahtarda (bayrak `ostinatoGhostScreenEnabled` KAPALI); `V1PracticeRecord`, kapı ve eşikler değişmez; Hayalet basamağı kapıyı AÇMAZ.
- Hayalet yalnız enstrüman (gitar) pratiğine uygulanır; kulak alıştırmasına uygulanmaz (aşağıda C).

## C. Kulak/ritim ölçümü fiziksel pratikten ayrı
| Ölçüm biçimi | Nasıl ölçülür | Nereye yazılır | Birbirine karışmaz |
|---|---|---|---|
| Ekran cevabı (kulak alıştırması) | Ekranda seçim, mikrofon yok | Mevcut depolar: `TestFlowStore` ve `V1LessonCheck` (yalnız geçti/kaldı; yeni kayıt türü yok) | Enstrüman geçidine, Hayalet basamağına, doğruluk/duyulan % değerlerine SAYILMAZ |
| Alkış / ritim dokunma | Mikrofon onset (alkış) ya da dokunma | Ritim satırı etiketli | Aynı |
| Söyleme | Öz-kontrol (ölçülmez) | "Öz-bildirim" etiketli (`V1CheckEvidence.selfReport`, `practice_progress_store.dart`) | Ölçülmüş sayılmaz |
| Enstrüman (gitar) | Nota gözlemi (`GuitarPitchObserver`) | `V1PracticeRecord` | Kulak/ritim sonuçları bunu etkilemez |
Her sonuç ekranı ölçüm biçimini etiketler. Kulak sonuçları Yolum > Geçmiş'te ayrı bölümde (Kulak) görünür ve bu bölüm yalnız geçti/kaldı gösterir (yüzde/puan yok, yeni kayıt kurulmaz); enstrüman ilerlemesine toplanmaz. (`test_flow_screen.dart` yorumundaki kip ayrımı korunur.)

## D. Glass kuralları özeti
En fazla iki cam öğe · çalarken 0 · aynı anda ≤ 1 bulanık yüzey · sigma ≤ 16 · kontrast 4.5:1/3:1 · saydamlığı/hareketi azalt = opak/anlık · düşük donanımda bulanıklık kapalı. Ayrıntı: teslimat 6.
