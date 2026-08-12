# 🧭 Ostinato — gezilebilirlik SAYMA KURALI (O-105, 2026-08-12)

> **Neden yazıldı:** Gravita panoya girmek üzere olan bir karşılaştırmayı
> durdurdu — *"sekmeleri farklı sayıyorsak iki sayı AYNI ŞEYİ ÖLÇMÜYOR; fark
> içerik değil SAYMA KURALI olur."* Gravita (7/4) ve Lissom (6/2) kurallarını
> yazdı ve aynı çıktılar → kıyaslanabilir. **Ostinato'nun 08-07'deki 11 sayısı
> kuralsız VE bayattı.** Bu belge kuralı yazar, ölçüyü DEĞİŞTİRMEZ.
>
> Ölçüm aracı: `test/reachable_screens_test.dart` (O-074'ten beri).
> Bu belge o aracın **yazılı kuralıdır**, yeni bir eksen değildir.

## Dört soru, dört cevap

### ① Sekme/perde: KATI'da kaç, GEVŞEK'te kaç?

| okuma | sekme·perde·aşama | gerekçe |
|---|---|---|
| **KATI** | **+0** | Ayrı bir **ROTAYA** gidiş sayılır. Aynı sayfa içinde değişen perde/aşama **navigasyon kabuğu değil, içerik derinliğidir.** |
| **GEVŞEK** | **+1/aşama** | Kullanıcının gördüğü ayrı **görsel hâl** sayılır. |

**Ostinato'nun ölçülmüş perde/aşama envanteri (GEVŞEK'in kaynağı):**
* Onboarding: **3** perde (`_stepCount = 3`, tek rota)
* Kurulum Kontrolü: **6** aşama (`_Stage { starting, framingError, lowLight,
  ok, room, passed }`)
* Canlı ölçüm + Özet: `ostinato_posture/surface_state.dart` **sealed** hiyerarşisi
  (`Starting` · `PermissionDeniedRetriable` · `PermissionDeniedPermanent` ·
  `CameraUnavailable` · `SetupFailed` · `NoPersonVisible` · `Measuring`)
  → **7 hâl**, ama bunların ekranlara dağılımı **SAYILMADI** (kamera arkasında,
  aşağıya bak). Bu sınır **isimli**: GEVŞEK sayı bu yüzden bir **alt sınır**dır.

### ② Aday envanteri nasıl türetiliyor: desen mi, elle mi?

**ELLE.** Yürüyüş, ürünün kendi kontrollerine **açıkça yazılmış** dokunuşlarla
ilerler (`find.byKey('onboarding-primary')` · `find.text('⚙')` ·
`find.text('Guitar')` · `find.text('‹')` …). Türetimli bir rota listesi
**yoktur**.

> **Kör noktası, adıyla:** *elle yazılmış yürüyüşün göremediği şey, yazarın
> DENEMEYİ AKLINA GETİRMEDİĞİ kontroldür.* Gravita'nın desen-türetimli
> envanteri bir ekranı kaçırmıştı (desen tanımadığı için); bendeki kusur
> **simetriği**: desen yok, dolayısıyla kaçan şey **desenin tanımadığı** değil
> **benim listemde olmayan** olur. İkisi de sessizdir — ama benimki yürüyüş
> büyüdükçe DEĞİL, ürün büyüdükçe büyür.

### ③ Ölçüm nereden başlıyor?

**Soğuk ilk açılıştan** — `OstinatoHome(alreadyOnboarded: false)` +
`InMemoryOnboardingStore()` (boş). Yani kullanıcının uygulamayı ilk kez
açtığı andan. 375×812 fiziksel boyut zorlanır (`flutter_test`in varsayılan
yüzeyi gerçek telefonun iki katı).

### ④ Onboarding içeride mi?

**EVET** — sayının **1 numaralı** kalemi. Atlanmıyor, üç perdesi **gerçek
dokunuşlarla** geçiliyor (KATI'da +0 katkı).

---

## 🔴 Bugün ölçülen İKİ ŞEY: sayı TAZELENDİ ve bir UYUŞMAZLIK çıktı

**Taze koşum (2026-08-12, `9e974ce`):** araç **KATI SAYI: 9** yazdırıyor.
08-07'nin *"11"*i **bayat ve kuralsızdı** (o satır KATI 8 + kamera-arkası 3'ü
tek sayıda topluyordu — GEVŞEK bir okuma).

⚠️ **VE ARAÇ KENDİ YAZILI KURALIYLA ÇELİŞİYOR — 9 mu 8 mi:**

Araç `reached` kümesine **etiket DİZGESİ** ekliyor, **rota kimliği** değil.
Ders türleri şöyle dağılıyor (`course_screen.dart:100-104`, ölçüldü):

| ders türü | gidilen rota |
|---|---|
| `locked` | `LessonLockedScreenRoute` |
| `demoOnly` | `LessonDemoScreenRoute` |
| `guide` **veya** `scored` | **`LessonScoredScreenRoute`** (aynı rota) |

Yani `guide` ve `scored` **AYNI ROTAYA** gidiyor — yazar bunu biliyordu
(etiketleri `'6 Lesson/guide→scored'` ve `'6 Lesson/scored'`, **ikisi de 6**).
Ama küme iki ayrı DİZGE gördüğü için `reached.length` **9** sayıyor.

* **Yazılı KATI kurala göre doğru sayı: 8** (ayrı rota: Onboarding · Library ·
  Settings · Instrument · Course · LessonScored · LessonDemo · LessonLocked)
* **Aracın yazdırdığı: 9** (ayrı etiket dizgesi)
* Eşik zaten `>= 8` — yani **eşik kurala uyuyor, yazdırılan sayı uymuyor.**

> ***Bu, M-F-499'un bu hatta üçüncü hâli: sayı doğru sayıyor ama SAYDIĞI ŞEY
> kuralın konusu değil.*** Etiket ≠ rota.

⛔ **Sayaç DEĞİŞTİRİLMEDİ** — koordinatör sınırı *"ölçüyü değiştirme, kuralı
yaz"*. Uyuşmazlık burada **adıyla** duruyor; sayacı rota-kimliğine çevirmek
raporlanmış bir metriği değiştirir ve o karar koordinatördedir.

## Kamera arkasındaki üç ekran — sayının yanına YAZILMAK ZORUNDA

`SetupCheck` · `Live` · `Review` hiçbir otomatik yürüyüşle gezilemiyor:
`SetupCheckScreenRoute` `initState`te gerçek `MotionCameraController` kurar,
widget testinde platform kanalı yanıt vermez, ekran asılı kalır (O-036/O-037
ile AYNI donanım sınırı).

> **Bu üçü, ürünün ASIL deneyiminin tamamı.** *"Ostinato'da 11 ekran var"*
> demek, gezilemeyen üçünü gezilebilir sananları yanıltır — bu yüzden KATI
> sayı (8) ile kamera-arkası (3) **AYNI SAYIDA TOPLANMAZ.**

## Gizli dayanak — Lissom'un sorusuna cevap: EVET, bende de var

Lissom sayısının **doğru sebeple** çıktığını Flutter kaynağında doğrulamıştı
(`skipOffstage: true`). **Aynı dayanak Ostinato'da da var ve ölçüldü:**
`flutter_test/lib/src/finders.dart:103` →
`Finder text(String text, {bool findRichText = false, bool skipOffstage = true})`

Bu varsayılan **lehimize** çalışıyor: sahne-dışı (offstage) bir widget'a —
ör. arkadaki `Navigator` sayfasında kalan bir kontrole — dokunulamaz ve
sayılmaz. Ama **dayanak GİZLİ**: varsayılan yarın değişse sayı sessizce
büyürdü. Kayda geçiyor.

**İkinci gizli dayanak (bu hatta özel):** `t.pageBack()` KULLANILAMAZ — geri
düğmesi standart `BackButton` değil, ürünün kendi `GlassIconButton`'ı (metin
glifi `‹`). Aracın varsayılanı ürünün gerçeğini tanımıyordu; yürüyüş ürünün
kendi kontrolüne basıyor.

## Ve sayı bir ÜST SINIRDIR — `requireSubstance`

Her varışta ekranın **kendi özünden** bir cümle aranıyor (ders gerekçesi ·
dürüstlük kutusu · ölçüm iddiası). *Ulaşmak ≠ çalışmak*: kabuk çizilip içerik
boş kalabilir. Bu kontrol gezilebilirlik sayısını **daraltır**, genişletmez.
