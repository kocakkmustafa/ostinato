# Mevcut derslerin v1 eşlemesi

**Kapsam:** Uygulamadaki mevcut dersler (yazılı kurslar: gitar 60, piyano 25, ses 22 = 107) ve kamera temelli "foundations" kursları (gitar 10, ses 9, piyano 9 = 28). Ukulele (18) ve bas (18) v1 dışında, gizli kalır; bu belgede yok.

**Durumlar:**
- **R — yeniden kullanıldı:** açıklama metni büyük ölçüde korunur; ölçülen pratik, referans ses ve geçiş ölçütü eklenir.
- **V — revize:** ders bölündü, birleşti, başka seviyeye taşındı ya da yeniden yazılır.
- **X — emekli:** v1'de ders olarak yok; içerik başka derse paragraf/madde olarak girer ya da sonraki sürüme kalır.

**Ortak revizyon (tüm R ve V):** Mevcut yazılı derslerin `measurementMode` değeri `self_report_only`. v1'de her derse `00-ders-format-sozlesmesi.md`'deki ölçüm, motor ve yedek alanları eklenir. Yazılı ses kursunun "kişisel göreli perde, sabit aralık yok" (L-M-H) yaklaşımı v1'de **kişisel tona taşınmış derece** sistemine geçer: perde artık ölçülür, ama başlangıç perdesi yine kullanıcının rahat menzilinden gelir. "Kendi kaydını dinle" adımları tekrar-ölç adımına çevrilir.

Bu tablo kurs listelerindeki `Mevcut` sütunundan betikle üretildi.


## Gitar — guitar_journey (60)

| Mevcut id | Başlık (TR) | Durum | v1 dersi / gerekçe |
|---|---|---|---|
| `guitar.journey.start.parts` | Bölümler ve teller | R | gtr-s1-m01-01 |
| `guitar.journey.start.setup` | Rahat başlangıç konumu | V | gtr-s1-m01-02 |
| `guitar.journey.start.tuning` | Standart akort Mi La Re Sol Si Mi | V | gtr-s1-m01-04 |
| `guitar.journey.start.pluck` | Tek temiz ses | R | gtr-s1-m01-06 |
| `guitar.journey.start.fret` | Sıkmadan perde bas | R | gtr-s1-m01-07 |
| `guitar.journey.start.first_pulse` | İlk dört vuruşlu cümle | V | gtr-s1-m03-01 |
| `guitar.journey.notes.bass_e` | Altıncı tel notaları | R | gtr-s1-m02-02 |
| `guitar.journey.notes.bass_a` | Beşinci tel notaları | R | gtr-s1-m02-03 |
| `guitar.journey.notes.middle_strings` | Dördüncü ve üçüncü tel notaları | R | gtr-s1-m02-04 |
| `guitar.journey.notes.treble_strings` | İkinci ve birinci tel notaları | R | gtr-s1-m02-05 |
| `guitar.journey.notes.alternating_pick` | Aşağı yukarı pena | R | gtr-s1-m02-06 |
| `guitar.journey.notes.note_checkpoint` | Sekiz ölçülük nota çalışması | R | gtr-s1-m02-10 |
| `guitar.journey.reading.quarters_eighths` | Dörtlük ve sekizlikler | V | gtr-s1-m03-02, gtr-s1-m03-03 |
| `guitar.journey.reading.rests_ties` | Suslar ve bağlar | V | gtr-s1-m03-04, gtr-s1-m03-09 |
| `guitar.journey.reading.meters` | 3/4 ve 6/8 gruplama | V | gtr-s1-m03-06 |
| `guitar.journey.reading.tablature` | Basit tablatür oku | V | gtr-s1-m02-01 |
| `guitar.journey.reading.staff` | Birinci pozisyonda porte notaları | V | gtr-s4-m18-01, gtr-s4-m18-02 |
| `guitar.journey.reading.reading_checkpoint` | Kısa notayı oku ve düzelt | V | gtr-s4-m18-09 |
| `guitar.journey.chords.diagrams_em_am` | Akor şemaları, Mi minör ve La minör | V | gtr-s1-m04-01, gtr-s1-m04-02 |
| `guitar.journey.chords.e_a` | Mi ve La majör | R | gtr-s1-m04-03 |
| `guitar.journey.chords.d_g` | Re ve Sol majör | V | gtr-s1-m04-04, gtr-s1-m04-05 |
| `guitar.journey.chords.c_dm` | Do ve Re minör | V | gtr-s1-m04-06, gtr-s2-m05-07 |
| `guitar.journey.chords.two_chord_changes` | İki akor arasında geçiş | V | gtr-s1-m04-07 |
| `guitar.journey.chords.four_chord_loop` | Dört akorlu döngü | R | gtr-s1-m04-11 |
| `guitar.journey.strum.down_up` | Aşağı ve yukarı pena | R | gtr-s2-m06-01 |
| `guitar.journey.strum.accents` | Vurgu ve ses düzeyi | R | gtr-s2-m06-03 |
| `guitar.journey.strum.waltz` | Üç zamanda eşlik | R | gtr-s2-m06-07 |
| `guitar.journey.strum.offbeat` | Ara vuruşlar ve planlı sessizlik | R | gtr-s2-m06-05 |
| `guitar.journey.strum.mute` | Akoru temiz sustur | R | gtr-s2-m06-06 |
| `guitar.journey.strum.accompaniment` | On altı ölçülük eşlik | R | gtr-s2-m06-11 |
| `guitar.journey.melody.interval_map` | Tam ve yarım aralıklar | R | gtr-s2-m09-01 |
| `guitar.journey.melody.c_major` | Açık tellerde Do majör | R | gtr-s2-m09-04 |
| `guitar.journey.melody.g_major` | Sol majör ve değişen ses | R | gtr-s2-m09-05 |
| `guitar.journey.melody.a_minor_pent` | La minör pentatonik | R | gtr-s2-m09-11 |
| `guitar.journey.melody.phrasing` | Soru ve cevap cümleleri | R | gtr-s2-m09-09 |
| `guitar.journey.melody.melody_capstone` | Özgün sekiz ölçülük melodi | R | gtr-s2-m09-12 |
| `guitar.journey.harmony.triads` | Majör ve minör üçlüleri kur | R | gtr-s3-m14-01 |
| `guitar.journey.harmony.key_chords` | Tonda I, IV ve V | R | gtr-s3-m14-04 |
| `guitar.journey.harmony.transpose` | Kısa diziyi başka tona taşı | R | gtr-s3-m14-06 |
| `guitar.journey.harmony.blues_form` | On iki ölçülük biçim | R | gtr-s3-m13-01 |
| `guitar.journey.harmony.power_chords` | Kök ve beşli şekilleri | R | gtr-s3-m10-01 |
| `guitar.journey.harmony.sevenths_chart` | Yedililer ve kendi çizelgen | R | gtr-s3-m14-08 |
| `guitar.journey.fingerstyle.finger_names` | Başparmak ve üç parmak | R | gtr-s3-m12-01 |
| `guitar.journey.fingerstyle.steady_bass` | Yinelenen bas nota | R | gtr-s3-m12-02 |
| `guitar.journey.fingerstyle.alternating_bass` | Değişen bas | R | gtr-s3-m12-06 |
| `guitar.journey.fingerstyle.arpeggio` | Arpej örüntüsü | R | gtr-s3-m12-07 |
| `guitar.journey.fingerstyle.melody_bass` | Bas üzerinde melodi | R | gtr-s3-m12-09 |
| `guitar.journey.fingerstyle.finger_arrangement` | On altı ölçülük parmak stili parça | R | gtr-s3-m12-12 |
| `guitar.journey.intermediate.partial_barre` | Kısmi bare, hafif gevşeme | V | gtr-s2-m07-05 |
| `guitar.journey.intermediate.f_chord` | Fa majör seçenekleri | V | gtr-s2-m07-04 |
| `guitar.journey.intermediate.movable_shape` | Kök ve şekli taşı | V | gtr-s3-m11-09, gtr-s4-m16-08 |
| `guitar.journey.intermediate.pentatonic_link` | İki pentatonik bölgeyi bağla | R | gtr-s4-m17-08 |
| `guitar.journey.intermediate.slides_bends` | Anlatımlı perde hareketi | V | gtr-s4-m19b-04, gtr-s4-m19b-05 |
| `guitar.journey.intermediate.blues_improv` | On iki ölçüde soru cevap | R | gtr-s3-m13-09 |
| `guitar.journey.independent.choose_piece` | Parça seç ve haritala | X | Kullanıcının seçtiği herhangi bir parça doğrulanamaz ve telif riski taşır. "Parça haritalama" yöntemi voc-s2-m09-10 ve pno-s2-m08-10 gibi kamu malı listeyle sınırlı derslere taşındı; gitarda S5 repertuvar modülünde dönecek. |
| `guitar.journey.independent.arrange` | Giriş ve bitiş kur | R | gtr-s3-m14-11 |
| `guitar.journey.independent.self_review` | Dinle ve tek şeyi düzelt | X | Kendi kaydını dinlemeye dayanıyor; v1 "öğrenci kaydı yok" kararına aykırı. Yerini nota sonuçlarıyla tekrar-ölç dersi aldı (gtr-s4-m18-09). |
| `guitar.journey.independent.rhythm_final` | Bitirme I: eşlik | V | gtr-s2-test |
| `guitar.journey.independent.melody_final` | Bitirme II: melodi ve bas | V | gtr-s3-m13-11 |
| `guitar.journey.independent.next_cycle` | Sonraki çalışma döngünü planla | X | Ayrı ders yerine her seviye testinin sonuç ekranında "sonraki döngü" önerisi olarak gösterilir. |

**Özet:** R 38 · V 19 · X 3 (toplam 60)

## Piyano — piano_beginner (25)

| Mevcut id | Başlık (TR) | Durum | v1 dersi / gerekçe |
|---|---|---|---|
| `piano-01` | Kurulum ve sınırlar | V | pno-s1-m01-01 |
| `piano-02` | Klavye haritası | R | pno-s1-m01-03 |
| `piano-03` | Parmak numaraları ve tuşe | R | pno-s1-m01-05 |
| `piano-04` | Düzenli vuruş ve sus | R | pno-s1-m02-05 |
| `piano-05` | Sağ elde beş nota | R | pno-s1-m02-01 |
| `piano-06` | Sol elde beş nota | R | pno-s1-m03-01 |
| `piano-07` | Büyük dizeği okumak | R | pno-s1-m03-05 |
| `piano-08` | Nota ile ritmi okumak | R | pno-s1-m04-02 |
| `piano-09` | Elleri sırayla kullanmak | R | pno-s1-m03-06 |
| `piano-10` | Birlikte: ortak vuruş | R | pno-s2-m08-01 |
| `piano-11` | Tutulan bas üstünde melodi | R | pno-s2-m08-02 |
| `piano-12` | Değişen bas ve iki sesli armoni | R | pno-s2-m08-03 |
| `piano-13` | Cümleleme ve gürlük | R | pno-s1-m04-08 |
| `piano-14` | İlk bağımsız okuma | R | pno-s1-m04-09 |
| `piano-15` | Özgün iki el etüdü | R | pno-s2-m08-09 |
| `piano-16` | Siyah tuşlar, diyez ve bemoller | R | pno-s1-m01-07 |
| `piano-17` | İkiliden beşliye aralıklar | R | pno-s2-m05-10 |
| `piano-18` | Sol konumu ve eli taşımak | R | pno-s2-m05-01 |
| `piano-19` | Başparmak geçişiyle Do majör dizisi | R | pno-s2-m06-01 |
| `piano-20` | Üç dörtlük ölçü ve noktalı notalar | R | pno-s1-m04-05 |
| `piano-21` | Staccato, legato ve aksanlar | R | pno-s2-m09-01 |
| `piano-22` | Sol elde Do, Fa ve Sol7 akorları | R | pno-s2-m07-08 |
| `piano-23` | Yeni bir parçayı kendin haritala | R | pno-s2-m08-10 |
| `piano-24` | Kendi çalışma döngün | R | pno-s2-m09-10 |
| `piano-25` | Çıkış değerlendirmesi ve sonraki çalışma | V | pno-s2-test |

**Özet:** R 23 · V 2 · X 0 (toplam 25)

## Ses — vocal_beginner (22)

| Mevcut id | Başlık (TR) | Durum | v1 dersi / gerekçe |
|---|---|---|---|
| `vocal-01` | Rahat başla ve ne zaman duracağını bil | R | voc-s1-m01-01 |
| `vocal-02` | Katı duruş hedefi olmadan yerleş | V | voc-s1-m01-02 |
| `vocal-03` | Doğal nefes ve kısa hava akışı | R | voc-s1-m01-03 |
| `vocal-04` | Hafif ve rahat mırıldanma | R | voc-s1-m01-04 |
| `vocal-05` | Kısa sesi başlat ve bırak | R | voc-s1-m01-06 |
| `vocal-06` | Dört sayımlı ritmi oku | R | voc-s1-m04-01 |
| `vocal-07` | Perde yönü ses seviyesinden farklıdır | R | voc-s1-m02-01 |
| `vocal-08` | Yakın üç rahat ses seç | V | voc-s1-m02-10 |
| `vocal-09` | Yeni iki ölçülük çizgiyi oku | V | voc-s1-m04-02 |
| `vocal-10` | Ünlüyü zorlamadan aç | R | voc-s1-m04-03 |
| `vocal-11` | Açık özgün sözler ve heceler | R | voc-s1-m04-04 |
| `vocal-12` | Rahat seviyede ifade | R | voc-s2-m08-01 |
| `vocal-13` | Cümle süresi ve nefes araları | R | voc-s2-m08-05 |
| `vocal-14` | Özgün sekiz ölçülük ses etüdünü hazırla | R | voc-s1-m04-08 |
| `vocal-15` | Tek sorunu gözle ve aynı görevi karşılaştır | V | voc-s2-m09-13 |
| `vocal-16` | Beş küçük basamak çıkış ve iniş | R | voc-s1-m03-01 |
| `vocal-17` | Atlamalar ve eve dönüş | R | voc-s1-m03-03 |
| `vocal-18` | Gürlüğü artırmak ve azaltmak | R | voc-s2-m08-03 |
| `vocal-19` | Kendi ısınman ve durma sinyallerin | R | voc-s2-m09-11 |
| `vocal-20` | Seçtiğin kısa bir melodiyi haritala | V | voc-s2-m09-10 |
| `vocal-21` | Kendi çalışma döngün | V | voc-s2-m09-12 |
| `vocal-22` | Başlangıç çıkışı ve başka gün tekrarı | V | voc-s2-test |

**Özet:** R 15 · V 7 · X 0 (toplam 22)

## Gitar — kamera kursu `guitar.foundations` (10)

| Mevcut id | Başlık (TR) | Durum | v1 dersi / gerekçe |
|---|---|---|---|
| `guitar.foundations.camera_space` | Camera and space | V | gtr-s1-m01-02 |
| `guitar.foundations.posture` | Sitting posture | V | gtr-s1-m01-02 |
| `guitar.foundations.teacher_range` | How much teachers actually differ | X | Öğretmenler arası farkı anlatan meta ders; gtr-s1-m01-02 anlatımına bir paragraf olarak girer. |
| `guitar.foundations.posture_under_play` | Staying upright while you play | X | Çalarken duruş kamera kontrolü S1 dışına taşar (kamera yalnız S1 başında). gtr-s1-m01-02 kontrol listesine madde olarak eklenir. |
| `guitar.foundations.arms` | Holding the guitar — measured, never graded | V | gtr-s1-m01-03 |
| `guitar.foundations.foot_support` | Foot support and instrument tilt | V | gtr-s1-m01-02 |
| `guitar.foundations.open_chords` | Open chords | V | gtr-s1-m04-01 |
| `guitar.foundations.light_and_frame` | Light, distance, and when we refuse | V | gtr-s1-m01-02 |
| `guitar.foundations.strum_timing` | Strumming in time | V | gtr-s1-m03-07 |
| `guitar.foundations.chords_beyond_eight` | Chords outside the eight | V | gtr-s2-m07-01 |

**Özet:** R 0 · V 8 · X 2 (toplam 10)

## Ses — kamera kursu `voice.foundations` (9)

| Mevcut id | Başlık (TR) | Durum | v1 dersi / gerekçe |
|---|---|---|---|
| `voice.foundations.camera_space` | Camera and space | V | voc-s1-m01-02 |
| `voice.foundations.posture` | How you stand before you sing | V | voc-s1-m01-02 |
| `voice.foundations.teacher_range` | How much teachers actually differ | X | gtr ile aynı gerekçe; voc-s1-m01-02 anlatımına paragraf. |
| `voice.foundations.posture_under_sing` | Staying open while you sing | X | Söylerken kamera duruş takibi yok; voc-s1-m01-02 kontrol listesine madde. |
| `voice.foundations.sustained_note` | Sustained note | V | voc-s1-m02-03, voc-s1-m02-09 |
| `voice.foundations.arms` | Your arms — measured, never graded | X | Kollar puanlanmıyordu ve ayrı ders gerektirmiyor; voc-s1-m01-02 kontrol listesine madde. |
| `voice.foundations.light_and_frame` | Light, distance, and when we refuse | V | voc-s1-m01-02 |
| `voice.foundations.vibrato` | Vibrato | X | Vibrato S5'e kaydı; öğretmen verisi olmadan doğru vibrato puanı verilmez. |
| `voice.foundations.knees_and_chin` | Locked knees and a lifted chin | V | voc-s1-m01-02 |

**Özet:** R 0 · V 5 · X 4 (toplam 9)

## Piyano — kamera kursu `piano.foundations` (9)

| Mevcut id | Başlık (TR) | Durum | v1 dersi / gerekçe |
|---|---|---|---|
| `piano.foundations.camera_space` | Camera and space | V | pno-s1-m01-01 |
| `piano.foundations.posture` | How you sit at the keyboard | V | pno-s1-m01-01 |
| `piano.foundations.teacher_range` | How much teachers actually differ | X | gtr ile aynı gerekçe; pno-s1-m01-01 anlatımına paragraf. |
| `piano.foundations.posture_under_play` | Staying settled while you play | X | Çalarken kamera takibi yok; pno-s1-m01-01 kontrol listesine madde. |
| `piano.foundations.five_finger` | Five-finger patterns | V | pno-s1-m02-07 |
| `piano.foundations.arms` | Your arms — measured, never graded | V | pno-s1-m01-02 |
| `piano.foundations.light_and_frame` | Light, distance, and when we refuse | V | pno-s1-m01-01 |
| `piano.foundations.shoulder_tension` | Shoulder tension | V | pno-s1-m01-08 |
| `piano.foundations.hands_and_wrists` | Wrists, fingers, hand shape | V | pno-s1-m01-02 |

**Özet:** R 0 · V 7 · X 2 (toplam 9)

## Toplam

| Kaynak | R | V | X |
|---|---|---|---|
| Gitar (yazılı, 60) | 38 | 19 | 3 |
| Piyano (yazılı, 25) | 23 | 2 | 0 |
| Ses (yazılı, 22) | 15 | 7 | 0 |
| Gitar (kamera, 10) | 0 | 8 | 2 |
| Ses (kamera, 9) | 0 | 5 | 4 |
| Piyano (kamera, 9) | 0 | 7 | 2 |

**Yazılı 107 dersten** 76'sı yeniden kullanıldı, 28'i revize edildi, 3'ü emekli. Kamera kurslarının 28 dersinin 20'si S1 kamera/kurulum derslerine birleşti, 8'i emekli. v1'in 690 dersinin **120'si** mevcut bir yazılı ya da kamera dersinden yararlanır (gitar 68, ses 24, piyano 28); **570 ders tamamen yeni yazılacak** (ürün önerisindeki ~580 tahminine yakın).
