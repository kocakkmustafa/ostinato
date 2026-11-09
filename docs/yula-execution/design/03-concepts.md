# Ostinato — Üç bağımsız etkileşim konsepti (OST-UX-02, Aşama 3)

Tarih: 2026-11-09 · Taban: `origin/main` `f121485be72e64102152b4f2b2389688c533d3fa` · Girdi: [`01-audit.md`](01-audit.md) (envanter), [`02-mental-model.md`](02-mental-model.md) (zihinsel model).
Dayanak: kurucu emri 2026-11-09 19:50, "Dört Ürün Arayüz ve Deneyim Talimatı" §7 Aşama 3 ve §2.4. YALNIZ BELGE: kod, test, içerik, tema, renk, tipografi, marka ve bağımlılık değişmedi; wireframe'ler yalnız yerleşim ve akıştır. Bu belge SEÇİM YAPMAZ; seçim OST-UX-03'te ADR ile yapılır.
Doğrulama kodları (01/02 ile aynı): **K** kaynakta okundu · **T** testte var (koşturulmadı) · **U** doğrulanamadı. Yeni = bugün kodda karşılığı yok.

## 0. Talimat dayanağı (başlık ve numaralar birebir)

- **§5.1 Temel UX kararı:** "Ostinato'da en önemli eylem müzik yapmaktır. Arayüz kullanıcıyı müzikten uzaklaştırmamalıdır." Üç konseptin hiçbirinde ders listesi birincil yüzey değildir; açılışta kullanıcı çalmaya, çalmaya hazırlanmaya veya duymaya yönlendirilir.
- **§5.2 Tasarlanması gereken temel deneyim alanları:** A. Stüdyo / Başlangıç · B. Canlı pratik · C. Öğrenme yolculuğu / Dersler · D. Hayalet Ekran · E. Kişiselleştirilmiş alıştırmalar · F. Kulak ve ritim eğitimi · G. İlerleme ve performans geçmişi · H. Enstrüman ve cihaz kurulumu.
- **§5.3 Ostinato tasarımında istenmeyenler:** her ekranı ders listesine dönüştürmek; pratiği fazla animasyon/efektle gölgelemek; her hata için sert görsel ceza; güvenilir olmayan ses analizini kesin ölçüm göstermek; sürekli kamera kurdurmak; oyun başarısını müzik becerisiyle karıştırmak; çalışan kurs ve ilerleme sistemini silmek. Hiçbiri aşağıdaki konseptlerin parçası değildir (bölüm 5'te ayrıca işaretlendi).
- **§5.4 Ostinato tasarım testi:** rehber okumadan (1) pratiğe başlama, (2) enstrümansız uygun çalışma, (3) öğrenme yolculuğunu görme, (4) bir hatayı anlama, (5) aynı bölümü tekrar deneme, (6) ilerleme geçmişine ulaşma, (7) mikrofon/kamera izni verilmediğinde alternatif deneyim.
- **§7 Aşama 3:** "Her biri farklı bir kullanım ve gezinme mantığı önermelidir"; altı ölçüt: kullanım kolaylığı, özgünlük, erişilebilirlik, profesyonel derinlik, mühendislik maliyeti, mevcut ürünle uyum.
- **§2.4 Özgün düşünün:** başka ürünlerin ekranları taklit edilmez; bu belge başka ürün adı vermez, onlardan görsel veya akış ödünç almaz. Yeni yaklaşım "kullanımı kolaylaştırması, zihinsel yükü azaltması veya kontrol sağlaması" ölçütüyle değerlendirilir (bölüm 4).
- **§2.3 Glass tasarım sistemi (katman tanımı olarak kullanıldı):** "yalnızca ihtiyaç duyulduğunda ortaya çıkan ek katmanlar", "yüzeyler arasında net odak ilişkisi", "tüm yüzeyler aynı yarı saydam kart OLMAZ", düşük donanımda performans, okunabilirlik, kontrast, azaltılmış hareket. Aşağıda "cam katman" = ana yüzeyin ÜSTÜNDE geçici duran, odağı çalınan müzikten ayırmadan bilgi/kontrol ekleyen yüzey; ana çalma yüzeyi (TAB şeridi, ŞİMDİ çizgisi) cam DEĞİLDİR.

## 1. Ortak zemin (üç konseptte de değişmeyenler)

Bunlar konsept değil, bugünkü ürünün sözleşmesidir (01/02'den):
- Ürün gerçeği: gitar + kulak eğitimi; ses/piyano çalgı kartı "Yakında"; kamera bayrakları kapalı (`ostinatoCameraPracticeAvailable=false`, `ostinatoCameraLessonsOpen=false`), ilk üç dakika ve dinle-dene-düzelt bayrakları kapalı (`lib/app/ostinato_release_policy.dart`, 01 §7). Konseptler bu bayrakların DEĞERİNİ değiştirmez; bayrak arkasındaki yüzeyler "bayrak açılırsa" diye işaretlenir.
- Ölçüm sözleşmesi: güvenilir değilse "duyamadım" (◯), yanlış hüküm yok, "farklı nota" (◆) hata kelimesi değil bilgi (`lib/app/practice/loop/practice_marks.dart`, K); duyulamayan notalar doğruluk oranının dışında (K); notaların beşte birinden fazlasında duyulamazsa bileşen puanlanmaz (K, `app_message_ids.dart`); tüm eşikler `expertPending` (450/450). Cihaz-üstü doğruluk ölçülmedi (01 §6).
- Ders içeriği, geçit/kapı mantığı (`V1PracticeRecord`, `v1_course_catalog.dart`), ücretsiz kapsam ve üyelik korumaları (`lib/app/course_access.dart`) aynen kalır; konseptler yalnız bunların SUNUMUNU değiştirir (§5.2.C, §2.5).
- Hayalet Ekran (D) bugün YOK (02 §3); her konsept onu YENİ olarak yerleştirir ve ilerlemeyi yalnız güvenilir ölçümle açar.
- "Dersler" bir yüzey olarak korunur ama hiçbir konseptte açılış veya ana gezinme değildir.

## 2. Konseptler

### Konsept 1 — "Tek Sahne" (çalmak-önce, katmanlı)

**(a) Tez.** Uygulama tek bir çalma sahnesidir; yapılacak her şey (ne çalacağım, nasıl gidiyorum, nasıl kurulur) sahnenin üstüne geçici cam katmanlar olarak açılır; kullanıcı çalma akışı sırasında başka bir ekrana gitmez, araç ve kurulum ekranları (akort, kurulum sihirbazı, alıştırma, kontrol noktası, ayarlar, hesap) yalnız "katman çıkışı" olarak tam ekran açılır ve kapanınca sahneye döner.

**(b) İlk 5 saniye.** Karşılama bittikten sonra açılış, kaldığı alıştırmanın (varsa `V1CourseState.next`; yoksa ilk ölçülü ders) pratik sahnesidir: akan şerit hazır, ŞİMDİ çizgisi, tempo, tek büyük "Çal". Üstte tek satır: "Notalar - yarım yol - ... dersinden devam" (ders adı; liste yok). Kullanıcı dokunur ve çalar; mikrofon izni ilk "Çal"da istenir (bugünkü kapı: `lib/app/audio/mic_permission_gate.dart`, K). Kenarda üç niyet tutamağı: "Başka çalış", "Yolum", "Ayar".

**(c) §5.2 alanları: nerede yaşar**

| Alan | Konum | Not |
|---|---|---|
| A. Stüdyo / Başlangıç | Sahnenin kendisi + "Başka çalış" katmanı | Devam = sahnenin açılış hâli. "Başka çalış" katmanı (alttan yükselen): hızlı pratik (aynı alıştırma), kısa öneri satırı (Yeni: kural tabanlı, `V1CourseState.next` + son hata türü), enstrüman/alan seçimi (gitar, kulak), akort kısayolu. "Son gelişim" tek cümle, katmanın üstünde |
| B. Canlı pratik | Ana yüzey (sahne) | Mevcut `practice_loop_screen.dart` çekirdeği; çalma sırasında hiçbir katman kendiliğinden açılmaz |
| C. Öğrenme yolculuğu / Dersler | "Yolum" katmanı (sağdan çekmece) | Seviye > modül şeması bu çekmecede, ders başına "neden bu" tek satırı (Yeni); liste çekmecenin İÇİNDE, açılışta değil |
| D. Hayalet Ekran | Sahnenin parametresi (Yeni) | Şerit yardımı (hedef nota, vuruş çizgisi, etiket) basamak basamak soluklaşır; basamak ELLE seçilir, otomatik yükselme yok (aşağıda f) |
| E. Kişiselleştirilmiş alıştırmalar | Sonuç katmanında "Şunu dene" + "Başka çalış" | Bugün: bayrak arkasında `listen_try_fix.dart`; yayında yalnız deterministik `drill_generator.dart`. İlk aşama: kural tabanlı seçim; mikro-etüt "araştırma" etiketli, yok |
| F. Kulak ve ritim | "Başka çalış" katmanında "Enstrümansız" satırı → sahne kulak kipine geçer | Kipler karışmaz: ekran alıştırması (cevap), alkış (mikrofon), söyleme (öz-kontrol) ayrı etiketli (`test_flow_screen.dart` yorumu) |
| G. İlerleme ve geçmiş | "Yolum" çekmecesinin üst sekmesi + pratik sonu katmanı | "Geçmiş" = aynı bölümün önceki denemeleri yan yana (bugün UI'da okunmayan `bestAccuracy/bestHeard/bestBpm` okunur; Yeni okuma, veri değişmez). Puan/rozet yok |
| H. Kurulum | "Ayar" katmanı + bağlamsal | Sahnede mikrofon şeridi hep görünür; gecikme/akort kurulumu bağlamsal ("zamanlama için kalibre et" bugünkü yer, `setup_wizard_screen.dart`); kamera yalnız kamera dersi açılınca, katmanda |

**(d) Glass katman ilişkisi.** Cam yalnız üç geçici katmandır (Başka çalış, Yolum, Ayar). Çalma sırasında (başla → durdur arası) üç tutamak da gizlenir ve hiçbir katman açılamaz; bu, "ritmi bozmayan" §5.2.B koşuludur. Katman açıkken sahne arkada durur, bulanık ve durağan (bulanıklık yalnız katman açıkken çizilir, sahne çalarken çizilmez; performans). Katman sahneyi KAPSAMAZ: üstten ~%40 şerit görünür kalır. "Hareketi azalt" ve "saydamlığı azalt" açıkken katman opak ve hareketsiz açılır (bugün bu iki yol yok: 01 §8; Yeni).

**(e) Mikrofon izni reddi.** Sahne "Dinleme kapalı" kipinde açılır: şerit, metronom, "Şu hızda dinle" (telefonda sentezlenen referans, `reference_listen_bar.dart`) ve öz-kontrol çalışır; ✓◆◯ yok, sayaç yerinde "ölçülmüyor" yazar. "Başka çalış" katmanında enstrümansız kulak alıştırması ve ritim dokunma öne çıkar. Ayarlara git bağlantısı sürekli ama susturulabilir. Kısıtlı: bugünkü davranış kodda ve testte var (`test/mic_permission_gate_test.dart`, T; `evidence/ux-01/render/09-pratik-mikrofon-izni-reddi.png` test render); "Başlat" düğmesinin mikrofon kapalıyken tam ne yaptığı cihazda doğrulanmadı (U).

**(f) Güvenilmeyen ölçüm.** Aynen mevcut sözleşme: nota başına ◯ "duyamadım" + neden (`HearingReason`: kısık, kırpma, perde çözülemedi...), sonuçta "duyulan %" ayrı, doğruluk yalnız karar verilebilenler üzerinden (`practice_result_screen.dart`, K). Hayalet basamağı ELLE; güvenilir ölçüm yokken "yetkinlik kazanıldı" ibaresi ve otomatik basamak yükseltme yoktur. Ölçüm güvenilmezse sahne "bu bölümü kendin değerlendir" öz-kontrolüne düşer (`V1LessonCheckStore`, K).

**(g) Mevcut ekran ve bileşen eşleşmesi**

| Bugünkü | Konseptte | Durum |
|---|---|---|
| `lib/app/practice/loop/practice_loop_screen.dart`, `practice_tab_strip.dart`, `metronome_beat_view.dart`, `practice_transport.dart`, `practice_tempo_ladder.dart`, `reference_listen_bar.dart` | Sahnenin çekirdeği | YENİDEN KULLANILIR; başlık/hazırlık bloğu sadeleşir |
| `practice_result_screen.dart` | Sahne üstünde sonuç katmanı (ayrı ekran değil) | Yeniden düzenlenir, içerik (6/1/1, hata haritası, geçit) korunur |
| `lib/app/screens/library_screen.dart` (kök) | Kalkar; kök = sahne | YENİ kök; kartlar "Başka çalış" katmanına taşınır |
| `v1_practice_list_screen.dart`, `v1_lesson_reader_screen.dart` | "Yolum" çekmecesi içinde | Yeniden kullanılır (kapı/chip mantığı aynı), kabuk yeni |
| `instrument_screen.dart`, `coming_soon_instrument_screen.dart` | "Başka çalış" içinde çalgı seçimi | Birleşir; eski duruş akışı (`course_screen`, `lesson_scored_screen`...) çekmecede ikinci düzey |
| `setup_wizard_screen.dart`, `tuner_screen.dart`, `drill_screen.dart`, `test_flow_screen.dart` | Katman çıkışı: tam ekran açılır, geri = sahne | Aynen yeniden kullanılır |
| `lib/app/retention/weekly_goal_card.dart` | "Yolum" > Geçmiş sekmesinde düz bilgi satırı (kart içeriği korunur) | Yeniden kullanılır; sahnede yer almaz |
| `lib/app/screens/settings_screen.dart` | "Ayar" katmanının çıkışı (tam ekran) | Yeniden kullanılır |
| `lib/app/ostinato_membership_page.dart`, `lib/app/ostinato_paid_access.dart`, `lib/app/account_connection.dart` | "Ayar" > Hesap/Üyelik çıkışı; ücretli ders kapısı "Yolum" içinde aynı koruma | Yeniden kullanılır, davranış değişmez |
| `lib/app/design/widgets.dart` `GlassCard` | Katman yüzeyi | Yeniden kullanılır; "saydamlığı azalt" yolu YENİ |
| Yeni | Sahne kabuğu, katman yöneticisi, Hayalet basamak ayarı, geçmiş görünümü (okuma), kural tabanlı öneri | Yeni |

---

### Konsept 2 — "Oturum Akışı" (zaman merkezli, rehberli)

**(a) Tez.** Kullanıcı bir ders seçmez, kısa bir oturum başlatır: uygulama 5–15 dakikalık bir çalışmayı adım adım (ısınma, çalma, duyma, özet) açar ve kullanıcı akışın içinde istediği adımı atlar, uzatır veya tekrar eder.

**(b) İlk 5 saniye.** Açılışta tek bir "Bugünkü oturum" yüzeyi: süre seçimi (5 / 10 / 15 dk), altında oturumun adım şeridi (ör. akort, ısınma, bugünkü bölüm, kulak, özet) ve büyük "Başla". Adımlar önizlemedir, tıklanıp ders listesi açılmaz. "Başla" ilk adıma, çoğu kez çalmaya, geçer; mikrofon izni ilk mikrofonlu adımda sorulur.

**(c) §5.2 alanları: nerede yaşar**

| Alan | Konum | Not |
|---|---|---|
| A. Stüdyo / Başlangıç | Oturum kapısı (açılış ekranı) | Devam = oturumun ilk adımı kaldığı bölüm; hızlı pratik = "5 dk"; çalgı/alan = oturum kapısında "Gitar / Kulak" ikilisi; öneri = oturum şeridinin kendisi (kural tabanlı, Yeni); son gelişim = kapının altında tek satır |
| B. Canlı pratik | Oturumun "Çal" adımı (tam ekran) | Mevcut pratik ekranı; adım şeridi küçülür, çalarken kalkar |
| C. Öğrenme yolculuğu / Dersler | "Yol" çekmecesi (oturum kapısından) ve adım başına "neden bu" satırı | Liste ikincil; oturum bölümü yolun sıradaki durağını sürer |
| D. Hayalet Ekran | Oturum şeridinde "Hatırla" adımı (Yeni) | Bölüm daha önce çalındıysa yardımsız deneme adımı eklenir; geçişi kullanıcı onaylar, ölçüm güvenilmezse adım eklenmez |
| E. Kişiselleştirilmiş alıştırmalar | Oturumun "Düzelt" adımı | Önceki oturumdaki ◆ bölümü kısa tekrar (bayrak arkasındaki `listen_try_fix.dart` mantığı açılırsa; ilk aşamada deterministik `drill_generator.dart`) |
| F. Kulak ve ritim | Oturumun "Duy" adımı; kulak oturumu = tamamı kulaktan (enstrümansız oturum) | Ölçüm biçimleri adım başına etiketli |
| G. İlerleme ve geçmiş | Oturum özeti + "Geçmiş" şeridi (kapı altında tamamlanan oturumların tarihli listesi) | Özet, bu oturumda ne çalındı ve önceki denemeyle fark; seri vurgusu yok: "Geçmiş" tamamlanan oturumların tarihli listesidir, ardışık-gün noktası ve kaçırılan gün boşluğu gösterilmez; mevcut haftalık hedef kartı korunur, baskı dili yok |
| H. Kurulum | Oturumun "Hazırlık" adımı (yalnız gerektiğinde) + kapıda küçük cihaz durumu | Akort ve gecikme kalibrasyonu adım olarak önerilir, atlanabilir; kamera yalnız kamera dersi adımı eklenirse (bayrak açılırsa) |

**(d) Glass katman ilişkisi.** Ana yüzey her adımda tek ve opaktır: oturum kapısındaki adım listesi ve oturum özeti opak metin/liste yüzeyleridir, cam DEĞİLDİR; özet tam ekran opak bir sondur (oturum sonu tek odaklı an). Cam yalnız geçici katmandır: adım ARASINDA açılan "sonraki adım" önizlemesi, "Yol" çekmecesi ve özet üstünde istenince açılan "önceki denemeyle karşılaştır" katmanı. Çalma adımında katman yoktur; katman çalarken çıkmaz ve kullanıcı kapatınca iner. Aynı yarı saydam kartın tekrarı yoktur (§2.3). Hareketi azalt: adım geçişi anlık; saydamlığı azalt: şerit opak (Yeni).

**(e) Mikrofon izni reddi.** Oturum, mikrofonsuz adımlarla kurulur: akort (mikrofonsuz alternatif yok; adım atlanır), "Dinle" (sentezlenen referans), enstrümansız kulak ve ritim dokunma, öz-kontrol ile çalma. Kapıda "Mikrofon kapalı: oturum ölçümsüz" yazar; oturum yine başlar. İzin ancak mikrofonlu adımda yeniden önerilir ve her seferinde sorulmaz.

**(f) Güvenilmeyen ölçüm.** Oturum özeti "duyamadım" sayısını doğruluktan ayrı yazar; duyulamayan notalar özette yargı yaratmaz; "Hatırla" adımı ve Hayalet geçişi güvenilir ölçüm olmadan eklenmez, özet "kendi değerlendirmen" satırı sorar. "Bugün X'i öğrendin" benzeri otomatik yetkinlik cümlesi yok.

**(g) Mevcut ekran ve bileşen eşleşmesi**

| Bugünkü | Konseptte | Durum |
|---|---|---|
| `practice_loop_screen.dart` + `practice_result_screen.dart` | "Çal" adımı ve adım sonu | YENİDEN KULLANILIR; sonuç adım içi özet |
| `drill_screen.dart`, `test_flow_screen.dart` | "Duy" / "Düzelt" adımları | Yeniden kullanılır |
| `tuner_screen.dart`, `setup_wizard_screen.dart` | "Hazırlık" adımı | Yeniden kullanılır |
| `lib/app/first_minutes/first_three_minutes_screen.dart` (bayrak kapalı) | Oturum kapısının ilk kullanım hâline yakın model; ritim dokunma adımı | Bayrak açılırsa yeniden kullanılabilir; bugün kapalı |
| `library_screen.dart` | Kalkar; kök = oturum kapısı | Yeni kök |
| `v1_practice_list_screen.dart`, `v1_lesson_reader_screen.dart` | "Yol" çekmecesi | Yeniden kullanılır |
| `weekly_goal_card.dart` | Kapıda tek satır | Yeniden kullanılır |
| `lib/app/screens/settings_screen.dart` | Kapıdaki <Ayar> çıkışı (tam ekran) | Yeniden kullanılır |
| `lib/app/ostinato_membership_page.dart`, `lib/app/ostinato_paid_access.dart`, `lib/app/account_connection.dart` | Ayar > Hesap/Üyelik; ücretli ders kapısı "Yol" içinde aynı koruma | Yeniden kullanılır, davranış değişmez |
| `session_store.dart` | Oturum kaydı (geçmiş şeridi) | Yeniden kullanılır, okuma yeni |
| Yeni | Oturum oluşturucu (deterministik, kural tabanlı; veri modeli: adımlar, süre), adım şeridi, oturum özeti, Hayalet "Hatırla" adımı | Yeni; oturum bileşimi bugün kodda yok (02 §3.A: günün çalışması yok) |

---

### Konsept 3 — "Çalışma Masası" (konu haritası + dokunulabilir araç katmanları)

**(a) Tez.** Kullanıcı çalışma alanını bir masa gibi kurar: kaldığı yer ve konu haritası ile tekrar edeceği bölüm masada durur, metronom, akort, referans dinleme ve döngü gibi araçlar pratik yüzeyinin etrafına tutulup bırakılan katmanlar olarak dizilir.

**(b) İlk 5 saniye.** Açılışta masa: ortada "Kaldığın bölüm" (mini şerit önizlemesi ve "Çal"), solda küçük konu haritası (gitar modülleri ve kulak modülleri düğüm olarak; ders adları değil, modül adları), sağda araç rafı (Akort, Metronom, Referans, Döngü). Tek dokunuş "Çal": mevcut pratik ekranı masanın üstünde açılır. Harita ilk açılışta daraltılmış ve tek satırdır.

**(c) §5.2 alanları: nerede yaşar**

| Alan | Konum | Not |
|---|---|---|
| A. Stüdyo / Başlangıç | Masa (açılış) | Devam = ortadaki "Kaldığın bölüm"; hızlı pratik = "Çal"; çalgı/alan = harita filtresi (Gitar / Kulak); öneri = haritada "Sıradaki" düğümü işaretli; son gelişim = masada son sonucun tek satırı |
| B. Canlı pratik | Masa üstü tam yüzey | Araç katmanları (metronom, döngü, referans) pratik yüzeyine tutunur; çalarken yalnız seçilmiş araçlar görünür |
| C. Öğrenme yolculuğu / Dersler | Konu haritası düğümü → modül çekmecesi | Düğüm = mevcut modül (gitar 22 modül kimliği, kulak 9; `v1_course_catalog.dart`, 01 §5); modül çekmecesinde dersler; "bu modül neden sırada" satırı (Yeni) |
| D. Hayalet Ekran | Katman olarak "Yardım" aracı (Yeni) | Araç rafında kaydırıcı: nota, vuruş çizgisi, etiket katmanlarını tek tek kapatma; "Yardımsız dene" düğümü haritada modül düğümüne bağlı |
| E. Kişiselleştirilmiş alıştırmalar | Haritada düğüm üstü "Şunu çalış" rozeti → kısa etüt | İlk aşama deterministik; bayrak arkası `listen_try_fix.dart` açılırsa aynı kapıdan |
| F. Kulak ve ritim | Haritanın ikinci bölgesi (kulak modülleri) + araç rafında "Kulak" | Enstrümansız masa: yalnız kulak bölgesi etkin; ölçüm biçimleri düğümde etiketli |
| G. İlerleme ve geçmiş | Harita üzerinde durum (modül düğümü: dokunulmadı / çalışıldı / geçit geçildi / tamamlandı) + masa çekmecesinde "Geçmiş" | Durumlar `V1PracticeRecord` alanlarından (passedAt/completedAt, K); yeni beceri adı ya da yetkinlik yüzdesi icat edilmez |
| H. Kurulum | Araç rafı (akort, kalibrasyon) + "Cihaz" katmanı | Mikrofon durumu, gecikme, ortam gürültüsü, kamera ayarı tek "Cihaz" katmanında; kamera yalnız ilgili modülde |

**(d) Glass katman ilişkisi.** Çok katmanlı tek konsept budur: araçlar cam katman olarak pratik yüzeyinin ÜSTÜNDE tutunur. Kurallar: en fazla iki cam katman aynı anda açık (ör. Metronom + Döngü); "Yardım" gibi kaydırıcı denetimler katman değil, opak araç rafı satırıdır; çalarken yalnız kullanıcı önceden "sabitlediği" katmanlar (ör. metronom görünümü) kalır, diğerleri iner; katman çalma yüzeyini kapsamaz (şeridin üst %40'ı hep açık). Bulanıklık yalnız açık katmanın arkasında, katman sayısı 2 ile sınırlı (performans). Hareketi azalt: katmanlar anlık; saydamlığı azalt: opak (Yeni). Bu konsept ek katman yönetimi gerektirir; kontrast riski daha yüksektir (üst üste cam).

**(e) Mikrofon izni reddi.** Masada "Dinleme kapalı" rozeti; harita ve araç rafı normal çalışır: Metronom, Referans (sentezlenen), Döngü, kulak bölgesi ve ekran alıştırmaları mikrofonsuz kullanılabilir; "Çal" ölçümsüz kipte açılır (öz-kontrol). Mikrofonlu araç (Akort) rafta soluk ve açıklamalıdır ("mikrofon gerekir"), dokunulursa izin açıklanır.

**(f) Güvenilmeyen ölçüm.** Düğüm durumu yalnız kayıtlı geçit/tamamlama olgusundan gelir; "duyamadım" yoğun denemeler düğümde "ölçülemedi" olarak işaretlenir, ilerleme sayılmaz, yetkinlik cümlesi yoktur. Hayalet "Yardımsız dene" yalnız kullanıcı isteğiyle; ölçüm güvenilmezse sonucu "değerlendirilemedi" gösterir.

**(g) Mevcut ekran ve bileşen eşleşmesi**

| Bugünkü | Konseptte | Durum |
|---|---|---|
| `practice_loop_screen.dart` ve parçaları (`practice_transport.dart`, `reference_listen_bar.dart`, `practice_tempo_ladder.dart`) | Masa üstü pratik yüzeyi; parçalar araç katmanına bölünür | Yeniden kullanılır, bölünür (orta-yüksek iş: şu an tek ekrana gömülü) |
| `tuner_screen.dart` | Araç katmanı | Katman biçimine uyarlanır |
| `v1_practice_list_screen.dart` (4 seviye × modül) | Harita + modül çekmecesi kaynağı | Veri/kapı mantığı yeniden kullanılır; sunum yeni |
| `library_screen.dart` | Kalkar; kök = masa | Yeni kök |
| `practice_result_screen.dart`, `drill_screen.dart`, `test_flow_screen.dart`, `setup_wizard_screen.dart` | Aynı | Yeniden kullanılır |
| `lib/app/retention/weekly_goal_card.dart` | Masanın "Geçmiş" çekmecesinde düz bilgi satırı | Yeniden kullanılır |
| `lib/app/screens/settings_screen.dart` | "Cihaz" katmanından "Ayarlar" çıkışı (tam ekran) | Yeniden kullanılır |
| `lib/app/ostinato_membership_page.dart`, `lib/app/ostinato_paid_access.dart`, `lib/app/account_connection.dart` | Ayarlar > Hesap/Üyelik; ücretli modül kapısı harita düğümünde (·) aynı koruma | Yeniden kullanılır, davranış değişmez |
| Yeni | Masa kabuğu, katman/araç raf sistemi, konu haritası bileşeni (düğümler, durum), ekran okuyucu için liste eşdeğeri, "Cihaz" katmanı | Yeni, en büyük kalem: harita görünümü bugün yok |

## 3. Wireframe'ler (kaba; yerleşim ve akış, renk/tipografi/marka içermez)

Gösterim: telefon dikey, genişlik ~34 karakter. `[ ]` düğme, `<...>` tutamak, `░` cam katman, `▒` opak ana yüzey. İşaretler `practice_marks.dart` kısaltmasıdır (✓ doğru, ◆ farklı nota, ◯ duyamadım); `●` = mikrofon durumu göstergesi (nota işareti değil).

### 3.1 Konsept 1 — Tek Sahne

**Stüdyo (açılış = sahne; "Başka çalış" katmanı kapalı/açık)**
```
Kapalı:                            "Başka çalış" açık:
+----------------------------------+ +----------------------------------+
| Altıncı telde notalar   <Ayar>   | | Altıncı telde notalar   <Ayar>   |
| devam: 2. seviye > modül 3       | |▒ şerit görünür (üst %40) ▒▒▒▒▒▒|
|                                  | |░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░|
|  ▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒   | |░ Bugün için bir öneri           ░|
|  ▒ ─────┃── (ŞİMDİ) ──────── ▒   | |░  "2. ölçüyü yavaş tekrar"  [Çal]░|
|  ▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒   | |░ [Gitar] [Kulak - enstrümansız] ░|
|  ♩=50    ● mikrofon hazır         | |░ [Akort] [Aynı alıştırma]        ░|
|                                  | |░ Son gelişim: 6 ✓, 1 ◆, 1 ◯      ░|
|         [      Çal      ]        | +----------------------------------+
|                                  |
| <Başka çalış>  <Yolum>  <Ayar>   |
+----------------------------------+
```

**Canlı pratik (çalarken tüm tutamaklar gizli)**
```
+----------------------------------+
| ♩=50  mikrofon: dinliyor   [Dur] |
|  ▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒  |
|  ▒  ✓  ✓  ◆  ✓  ◯   ┃  ...    ▒  |
|  ▒ ─────────────────┃──────────▒  |
|  ▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒  |
|                                  |
|  ✓4  ◆1  ◯1  (sayaç, yargı yok)  |
|  (ekran durmaz; katman yok)      |
+----------------------------------+
Dur -> sonuç katmanı (alttan) -> [Tekrar dene] [Sonraki]
```

**İlerleme ("Yolum" çekmecesi, sağdan; sahne arkada)**
```
+--------------------+░░░░░░░░░░░░░░░░░░
| sahne (duran)      |░ Yolum           ░
| ▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒   |░ [Geçmiş][Yol]   ░
|                    |░ Bu bölüm:       ░
|                    |░  dün  ✓5 ◆2 ◯1 ░
|                    |░  bugün ✓6 ◆1 ◯1░
|                    |░ Çalabildiklerim:░
|                    |░  (geçit geçilen ░
|                    |░   modüller)     ░
|                    |░ Zorlandığım:    ░
|                    |░  2. ölçü, tel 6 ░
|                    |░ Sıradaki: ...   ░
|                    |░ > Yol: seviye>  ░
|                    |░    modül>ders   ░
+--------------------+░░░░░░░░░░░░░░░░░░
```

### 3.2 Konsept 2 — Oturum Akışı

**Stüdyo (oturum kapısı)** (adım listesi opak; bu ekranda cam yok)
```
+----------------------------------+
| Ostinato                 <Ayar>  |
|                                  |
| Bugünkü oturum                   |
| [ 5 dk ] [*10 dk*] [ 15 dk ]     |
|                                  |
| 1  Akort          (atlanabilir)  |
| 2  Isınma         2 dk           |
| 3  Bölüm: altıncı tel   4 dk     |
| 4  Duy            2 dk           |
| 5  Özet                          |
|  Gitar / Kulak (enstrümansız)    |
|                                  |
|         [     Başla     ]        |
| geçmiş: son 5 oturum  <Yol>      |
+----------------------------------+
(<Yol> -> sağdan tek geçici ░ katman)
```

**Canlı pratik (oturumun 3. adımı)**
```
+----------------------------------+
| 3/5 Bölüm     ♩=50      [Dur]    |
| ▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒  |
| ▒  ✓  ✓  ◆  ✓  ◯  ┃  ...      ▒  |
| ▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒  |
| mikrofon: dinliyor               |
|        [ Başla / Çal ]           |
| (adım şeridi çalarken gizli)     |
| bitince: [Tekrar] [Sonraki adım] |
+----------------------------------+
```

**İlerleme (oturum özeti, tam ekran, opak)**
```
+----------------------------------+
| Oturum özeti      10 dk          |
|                                  |
| Bölüm: altıncı tel               |
|  ✓6  ◆1  ◯1   (duyulan %88)      |
| Zorlandığın yer: 2. ölçü         |
| Yarın için: kısa tekrar          |
| (yetkinlik iddiası yok)          |
|                                  |
| <Önceki denemeyle karşılaştır>   |
|  -> ░ geçici katman, kapatınca   |
|     iner ░                       |
|  [ Bir daha ]  [ Kapat ]         |
| Tamamlanan oturumlar:            |
|  8 Kas · 5 Kas · 2 Kas           |
+----------------------------------+
```

### 3.3 Konsept 3 — Çalışma Masası

**Stüdyo (masa)**
```
+----------------------------------+
| Masa  [Gitar|Kulak]  <Cihaz>     |
| ┌ Kaldığın bölüm ──────────────┐ |
| │ ▒ mini şerit ▒▒▒▒▒▒▒▒▒▒▒▒    │ |
| │            [   Çal   ]       │ |
| └──────────────────────────────┘ |
| Konu haritası  (daraltılmış)     |
|  (o)--(o)--(*)--( )--( )         |
|        sıradaki: modül 3         |
| Araçlar: [Akort][Metronom]       |
|          [Referans][Döngü]       |
| Son: ✓6 ◆1 ◯1        <Geçmiş>    |
+----------------------------------+
```

**Canlı pratik (iki cam araç katmanı tutunmuş; Yardım opak raf satırı)**
```
+----------------------------------+
| ♩=50  mikrofon: dinliyor  [Dur]  |
| ▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒  |
| ▒  ✓  ✓  ◆  ✓  ◯  ┃           ▒  |
| ▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒  |
| ░ Metronom ♩=50 ░ ░ Döngü 1-2 ░  |
| Yardım: nota [x] vuruş [x] (opak)|
|        [ Çal ]                   |
| (en fazla 2 katman; çalarken     |
|  yalnız sabitlenenler kalır)     |
+----------------------------------+
```

**İlerleme (harita açık)**
```
+----------------------------------+
| Konu haritası  [Gitar|Kulak]     |
|  Seviye 1                        |
|   (✓)modül1 ──(✓)modül2 ──(*)3   |
|  Seviye 2                        |
|   ( )4 ── ( )5  ... (kilit: ·)   |
|  Kulak                           |
|   (✓)ritim ── (o)aralık          |
| ✓ geçit geçildi  o çalışıldı     |
| * sıradaki  · kilitli/ücretli    |
| (düğüme dokun -> ░ modül         |
|  çekmecesi: dersler + geçmiş ░)  |
| Liste görünümü: [Haritayı listele]|
+----------------------------------+
```

## 4. Karşılaştırma matrisi

Ölçek 1–5, yüksek = o ölçütte daha iyi. Mühendislik maliyetinde 5 = düşük maliyet. Puanlar tasarım düzeyinde ve yazarın okumasıdır: kullanıcıyla veya cihazda ölçülmedi (bölüm 7); saat tahmini yoktur.

| Ölçüt | K1 Tek Sahne | K2 Oturum Akışı | K3 Çalışma Masası |
|---|---|---|---|
| Kullanım kolaylığı | **4** · tek dokunuşla çalma, sahne tek ekran; ama üç tutamak (Başka çalış, Yolum, Ayar) ve katmanlar küçük bir gezinme öğrenme maliyeti ekler | **4** · "Başla" yeterli ama adım sırası ve süre seçimi küçük bir karar ekler | **2** · masa, harita ve araç rafı aynı anda sunulur; ilk kullanıcı için seçenek fazla |
| Özgünlük (§2.4) | **3** · sahne-ve-katman düzeni bilinen bir kalıba yakın, özgünlük çalma yüzeyinin kök olmasında | **3** · oturum bileşimi ders listesinden farklı ama zaman çizelgesi benzeri akışlar yaygın | **4** · araçların tutunduğu masa ve modül haritası Ostinato'ya özgü bir çalışma modeli verir |
| Erişilebilirlik | **3** · tutamak ve çekmece dokunuş/hareket ister, klavye ve ekran okuyucu eşdeğeri ek iş; çalarken katmanın kapalı olması sadeliği artırır | **4** · doğrusal adımlar ekran okuyucu ve klavyeyle en doğal sırayı verir | **2** · harita ve üst üste katmanlar ekran okuyucu ve büyük metin için en zoru, liste eşdeğeri zorunlu |
| Profesyonel derinlik | **3** · çekmece derinliği var ama araçlar (döngü, referans, tempo) sahne içinde sınırlı | **2** · oturum akışı ileri kullanıcının serbest çalışmasını yavaşlatabilir; derinlik "serbest sahne" çıkışına bağlı | **5** · döngü, referans, metronom, yardım azaltma kullanıcı tarafından kurulur; en çok kontrol |
| Mühendislik maliyeti | **4** · orta-düşük: pratik çekirdeği ve tüm çıkış ekranları hazır, yeni veri modeli gerekmez; kök değişimi, katman yöneticisi ve geçmiş okuma yeni (K2'den ucuz: oturum bileşimi modeli yok; K3'ten çok ucuz: pratik ekranı bölünmez) | **3** · orta: adım ekranları büyük oranda mevcut; oturum bileşimi ve özet modeli yeni (günün çalışması bugün yok, 02 §3.A) | **1** · yüksek: pratik ekranı tek parça, araçlara bölünmeli; harita bileşeni ve liste eşdeğeri sıfırdan |
| Mevcut ürünle uyum | **4** · kök dışında çekirdek ve tüm ekranlar korunur | **4** · tuner, drill, test akışı, kurulum adım olarak oturur; kütüphane kökü kalkar | **3** · modül/kapı verisi birebir kullanılır ama pratik ekranının bölünmesi mevcut davranış riskidir |
| **Toplam /30** | **21** (4+3+3+3+4+4) | **20** (4+3+4+2+3+4) | **17** (2+4+2+5+1+3) |

Toplamlar seçim değildir; ölçütlerin eşit ağırlıkta toplamıdır (ağırlık kararı OST-UX-03'tedir).

### 4.1 §5.4 testi: geçer / kalır (tasarım düzeyinde, kullanıcı testi yapılmadı)

Talimat §5.4 metni: "Kullanıcı rehber okumadan:" ve aşağıdaki yedi madde (madde metinleri talimattan aynen alınmıştır).

| # | Madde (talimat metni) | K1 Tek Sahne | K2 Oturum Akışı | K3 Çalışma Masası |
|---|---|---|---|---|
| 1 | Pratiğe başlayabilmeli. | **Geçer** · açılış zaten pratik sahnesi, tek "Çal" | **Geçer** · tek "Başla"; ilk adımın akort mu çalma mı olacağı açık olmalı | **Kalır** · "Çal" masada var ama harita ve rafla yarışır; kullanıcı rehbersiz neye dokunacağını seçmek zorunda kalabilir |
| 2 | Enstrümanı olmadan uygun bir çalışma yapabilmeli. | **Geçer** · "Başka çalış" > Kulak (enstrümansız) iki dokunuş | **Geçer** · kapıdaki "Kulak (enstrümansız)" seçimi tam oturum kurar | **Geçer** · harita kulak bölgesi; gitar filtresiyle birlikte görünürlüğü zayıf, etiket gerekir |
| 3 | Öğrenme yolculuğunu görebilmeli. | **Geçer** · "Yolum" çekmecesi, ama bir tutamak ardında | **Geçer** · "Yol" kapıdan ve oturum satırlarından | **Geçer** · harita birincil; en görünür |
| 4 | Bir hatasını anlayabilmeli. | **Geçer** · sonuç katmanı, hata haritası ("Nerede oldu"), ◆ bilgi | **Geçer** · oturum özeti + adım sonu özet | **Geçer** · aynı sonuç ekranı; hata modül düğümüne bağlanmaz |
| 5 | Aynı bölümü tekrar deneyebilmeli. | **Geçer** · [Tekrar dene], çubuğa dokun = döngü (bugünkü davranış, `practice_result_screen.dart` "Tap a bar to loop it") | **Geçer** · "Bir daha" ve "Düzelt" adımı; tek bölümü tekrar sonra oturum akışı dışına çıkar | **Geçer** · Döngü aracı en doğrudan |
| 6 | İlerleme geçmişine ulaşabilmeli. | **Geçer** · "Yolum" > Geçmiş | **Geçer** · kapıdaki geçmiş şeridi | **Geçer** · harita durumu ve "Geçmiş" |
| 7 | Mikrofon veya kamera izni vermediğinde de uygun alternatif deneyimi kullanabilmeli. | **Geçer** · mikrofon: "Dinleme kapalı" kipi, kulak ve referans; kamera: bağımlılık yok | **Geçer** · mikrofon: oturum mikrofonsuz kurulur; kamera: bağımlılık yok | **Geçer** · mikrofon: mikrofonlu araçlar soluk, diğerleri açık; kamera: bağımlılık yok |

Madde 7, kamera boyutu: üç konsept de kameraya bağımlı değildir. Kamera bayrakları kapalıdır (`ostinatoCameraPracticeAvailable=false`, `ostinatoCameraLessonsOpen=false`, 01 §7); bayrak açılırsa kamera yalnız K8 derslerinde (`gtr-s1-m01-02`, `-03`) ve yalnız o ders açılınca istenir, reddedilirse o ders kamerasız atlanır ya da ilerleme öz-bildirimle sürer; hiçbir konseptte açılış, oturum veya masa kamera kurulumu gerektirmez. Kamera izni reddi cihazda doğrulanmadı (U).

Özet: K1 7/7, K2 7/7, K3 6/7 (madde 1). Madde 1 K3'te, masanın açılışında "Çal"ı tek eylem yapan bir sadeleştirmeyle çözülebilir; bu K3'ü K1'e yaklaştırır (bölüm 6, melez).

## 5. §5.1 ve §5.3 kontrolü (üç konsept)

| Madde | K1 | K2 | K3 |
|---|---|---|---|
| §5.1 "en önemli eylem müzik yapmaktır": açılış müziğe götürüyor mu | Evet: açılış çalma sahnesi | Kısmen: açılış oturum kapısı; "Başla" çoğu kez çalmaya gider ama ilk adım akort/ısınma olabilir | Kısmen: açılış masa; "Çal" var ama harita ve araç rafıyla aynı yüzeyde |
| Her ekranı ders listesine dönüştürmek | Hayır: liste yalnız "Yolum" içinde | Hayır: liste yalnız "Yol" içinde | Hayır: harita düğümleri modül, ders listesi çekmecede |
| Fazla animasyon/efekt | Çalarken katman ve hareket yok | Çalarken şerit gizli | Çalarken yalnız sabitlenmiş katmanlar |
| Sert görsel ceza | ◆ ve ◯ nötr; sayaçta yargı yok | Özette ceza dili yok | Düğümde "ölçülemedi" nötr |
| Güvenilmeyen ölçümü kesin gösterme | ◯ + neden, doğruluk ayrı | Özet ◯ ayrı yazar | Düğüm durumu yalnız kayıtlı geçitten |
| Sürekli kamera kurdurma | Kamera yalnız kamera dersi | Aynı | Aynı |
| Oyun başarısını müzik becerisiyle karıştırma | Puan/rozet yok; mevcut haftalık hedef/seri yalnız "Yolum" > Geçmiş içinde düz bilgi, sahnede yok | Puan/rozet yok; geçmiş tarihli oturum listesi, ardışık-gün noktası ve boş gün gösterilmez; haftalık hedef kapıda tek satır (kalan risk: seri sayısı gösterilirse 02 §5 #6 geçerli) | Düğüm durumu geçit olgusudur, puan değil; haftalık hedef "Geçmiş" çekmecesinde düz bilgi |
| Çalışan kurs/ilerleme sistemini silme | Silinmez; sunum değişir; haftalık hedef kartı, ayarlar, hesap/üyelik yerleri belirli (bölüm 2 g tabloları) | Silinmez; aynı yerler belirli | Silinmez; aynı yerler belirli |

## 6. Öneri ve gerekçe (SEÇİM YAPILMAZ)

Bu belge konsept seçmez; seçimi OST-UX-03'te ADR ile ilgili ekip yapar (Aşama 4). Aşağıdakiler yazarın okumasıdır.

- **K1 Tek Sahne** matriste en yüksek toplamı alır ve §5.1'e en doğrudan cevap verir (uygulama = çalma yüzeyi). Zayıflığı: derinlik katmanlara bağlı ve erişilebilirlikte katmanlar için klavye/ekran okuyucu eşdeğeri gerekir; özgünlük orta.
- **K2 Oturum Akışı** yeni başlayan ve "ne çalayım" sorusunu taşımak istemeyen kullanıcı için en az karar yükü getirir; erişilebilirliği doğal olarak iyi. Zayıflığı: ileri kullanıcıyı yavaşlatır ve oturum bileşimi (günün çalışması) bugün yok; deterministik kural kümesi ve pedagojik doğrulama (uzman onayı bekliyor) olmadan öneri zayıf kalır.
- **K3 Çalışma Masası** profesyonel derinlik ve özgünlükte en güçlüsü; en yüksek maliyet ve en zor erişilebilirlik. Pratik ekranını araçlara bölmek mevcut ölçüm yüzeyine regresyon riski taşır (01 §4, §8).
- **Hangi koşulda hangisi:** ürünün önceliği "ilk gün çalmaya başlayan" ise K1 veya K2; hedef kitle ağırlıkla ileri/rutinli gitaristse K3'ün araç katmanları; mühendislik kapasitesi sınırlı ve hızlı sonuç gerekiyorsa K1 (maliyet 4: çekirdek ve çıkış ekranları hazır, yeni veri modeli yok; K2 maliyet 3: oturum bileşimi modeli yeni). Erişilebilirlik öncelikliyse K2'nin doğrusal yapısı.
- **Olası melez (öneri değil, seçenek):** K1'in sahnesi kök, K2'nin "Bugünkü oturum" önerisi "Başka çalış" katmanında tek satır, K3'ün araç katmanları (metronom, döngü, referans, yardım) sahnede isteğe bağlı rafa dönüşür; harita (K3) çalışma haritası olarak "Yolum" çekmecesine girer. Bu melez her konseptten yalnız bağımsız parçayı alır; maliyeti ve tutarlılığı OST-UX-03'te değerlendirilmelidir.
- Karar öncesi eksik girdiler: bölüm 7.

## 7. Kapsam dışı / doğrulanamayan

- Kullanıcıyla test edilmedi; puanlar ve §5.4 sonuçları yazar değerlendirmesidir, ölçülmüş davranış değildir. Gerçek kullanıcı verisi ve analitik yoktur (02 kapsam notu).
- Wireframe'ler prototip değil; etkileşimli prototip Aşama 6'dır. Ekran ölçüleri, dokunma sayıları, katman animasyonları, performans (cam bulanıklığı düşük donanımda) ölçülmedi.
- Cihaz-üstü mikrofon doğruluğu, "Başlat" düğmesinin mikrofon kapalıyken davranışı, kaç dokunuşta pratik başladığı, ekran okuyucu akışı doğrulanmadı (U).
- Mühendislik maliyeti "düşük/orta/yüksek" tahminidir; saat/adam-gün yok. Katman yöneticisi, harita bileşeni, oturum bileşimi, Hayalet Ekran ve "saydamlığı azalt" yolunun kapsamı çıkarılmadı.
- Hayalet Ekran (D) ve üretilmiş mikro-etüt (E) bugün yok; konseptler bunları YENİ ve ölçüm güvenilirliğine bağlı olarak konumlar, yayınlanmış işlev olarak değil. Dinle-dene-düzelt, ilk üç dakika ve kamera dersleri bayrak arkasında; konseptlerdeki kullanımları "bayrak açılırsa"dır.
- Ders içeriği, uzman onayı (`expertPending` 450/450), eşikler ve gerçek gitar ölçümü bu belgenin kapsamı dışındadır; sonuç eşikleri değişmez.
- Renk, tipografi, marka ve bağımlılık önerisi yoktur; bu belge bunları değiştirmez. Ses/piyano/şan içerikleri konseptlerde kapsam dışı tutuldu (ürün gerçeği gitar + kulak).
- Mevcut ekran eşleşmeleri `01-audit.md` envanterine ve statik kaynak okumasına dayanır; çalışma zamanı sınıflaması (hangi dersin ölçülü pratikle açıldığı) hesaplanmadı (01 §5).
- Görsel bağlam: [`evidence/ux-01/render/`](evidence/ux-01/render/INDEX.md) test render, sahte veri; gerçek cihaz görüntüsü değildir. Bu belgede başka ürünlerin arayüzü örnek alınmadı.
