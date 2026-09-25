import 'package:flutter/widgets.dart';

/// The versioned English catalog remains the source of product claims. A
/// Turkish sentence is used only for the exact catalog text it was reviewed
/// against; changed source text stays visible in English until retranslated.
String catalogCopy(BuildContext context, String key, String source) {
  if (Localizations.localeOf(context).languageCode != 'tr') return source;
  return hasCurrentTurkishCatalogCopy(key, source)
      ? _turkishCopy[key]!
      : source;
}

String catalogFirstSentence(BuildContext context, String key, String source) {
  final text = catalogCopy(context, key, source);
  final stop = text.indexOf('. ');
  return stop == -1 ? text : text.substring(0, stop + 1);
}

bool hasCurrentTurkishCatalogCopy(String key, String source) =>
    _turkishCopy.containsKey(key) &&
    _sourceFingerprints[key] == _fingerprint(source);

String _fingerprint(String source) {
  var first = 0;
  var second = 0;
  for (final unit in source.codeUnits) {
    first = (first * 31 + unit) % 2147483647;
    second = (second * 131 + unit) % 2147483629;
  }
  return '${source.length}:${first.toRadixString(16)}:${second.toRadixString(16)}';
}

// Generated from the reviewed English fields in assets/content/library.json.
// The focused catalog test checks every live field and catches source drift.
const Map<String, String> _sourceFingerprints = <String, String>{
  'guitar.measured.0': '206:6e8d047f:16e8057c',
  'guitar.notMeasured.0': '862:150a0cfa:5f959e45',
  'guitar.notMeasured.1': '149:90eafdc:39e221c1',
  'guitar.notMeasured.2': '223:3fe0ef81:dbaf7e6',
  'guitar.notMeasured.3': '329:7815cd61:25617ea3',
  'guitar.notMeasured.4': '85:277a2c1:d3fa6e3',
  'guitar.notMeasured.5': '336:6f3357f2:19224c7f',
  'guitar.instrumentSpecificGap': '212:11083d49:9ecae67',
  'guitar.outOfScopeDerived.0': '232:602ee866:a7abc95',
  'guitar.comingSoon.0': '171:5d3069f7:4077bac0',
  'guitar.comingSoon.1': '475:796f335a:6f37ff1c',
  'guitar.comingSoon.2': '360:a9b43ca:1e807f7b',
  'guitar.foundations.arms.demoOnlyReason': '394:62fa8f4a:74ee8013',
  'guitar.foundations.arms.blockedBy': '214:1118824e:1f7a6f3f',
  'guitar.foundations.arms.unblockedBy': '195:19a46a33:4a58e818',
  'guitar.foundations.arms.ifItStaysBlocked': '242:63c2d8f2:44e73503',
  'guitar.foundations.foot_support.lockedReason': '271:5fba9b53:2814068e',
  'guitar.foundations.foot_support.unblockedBy': '227:70591648:5ab34ab0',
  'guitar.foundations.open_chords.lockedReason': '778:5c8442fb:7f6c68bd',
  'guitar.foundations.open_chords.unblockedBy': '443:55a8f9fd:70d5656a',
  'guitar.foundations.strum_timing.lockedReason': '434:44824148:608bf925',
  'guitar.foundations.strum_timing.unblockedBy': '436:331ced0d:25b881ae',
  'guitar.foundations.chords_beyond_eight.lockedReason': '502:66f9c592:3cd60dc8',
  'guitar.foundations.chords_beyond_eight.unblockedBy': '385:3849de27:3fbe61ef',
  'voice.measured.0': '394:548f225b:69d3f553',
  'voice.notMeasured.0': '355:67626739:5397dd08',
  'voice.notMeasured.1': '214:4e23874b:6a1ce854',
  'voice.notMeasured.2': '143:14800a0b:61d94938',
  'voice.notMeasured.3': '182:29618c1d:33766067',
  'voice.notMeasured.4': '285:d119732:56e05365',
  'voice.notMeasured.5': '147:1b0261aa:2a956d52',
  'voice.instrumentSpecificGap': '147:6caffff5:48bc624d',
  'voice.outOfScopeDerived.0': '205:84ce972:472a1a29',
  'voice.outOfScopeDerived.1': '214:1e0f51c6:66d94918',
  'voice.comingSoon.0': '182:e75575b:26c35e91',
  'voice.comingSoon.1': '116:42c1f844:61063473',
  'voice.comingSoon.2': '114:4bbc4bbe:a25f8da',
  'voice.foundations.sustained_note.lockedReason': '456:41d7746b:643800c4',
  'voice.foundations.sustained_note.unblockedBy': '367:4a899061:66c561ee',
  'voice.foundations.arms.demoOnlyReason': '394:62fa8f4a:74ee8013',
  'voice.foundations.arms.blockedBy': '213:4f2e0bd0:efc1fde',
  'voice.foundations.arms.unblockedBy': '195:19a46a33:4a58e818',
  'voice.foundations.arms.ifItStaysBlocked': '242:63c2d8f2:44e73503',
  'voice.foundations.vibrato.lockedReason': '307:1cc990e6:2579ae37',
  'voice.foundations.vibrato.unblockedBy': '376:2611a55a:549df1ec',
  'voice.foundations.knees_and_chin.lockedReason': '425:3b5fb1d9:4e8529a4',
  'voice.foundations.knees_and_chin.unblockedBy': '203:32b33297:64c0b801',
  'piano.measured.0': '264:198a7cda:58f7eb35',
  'piano.notMeasured.0': '259:2d73b5ad:584995d3',
  'piano.notMeasured.1': '378:6552afee:2eaa2ca8',
  'piano.notMeasured.2': '455:3af2cb47:21a3c9e4',
  'piano.notMeasured.3': '306:588dbce0:524f5864',
  'piano.notMeasured.4': '141:9fef241:4d724270',
  'piano.notMeasured.5': '133:4b8ac666:4e0bf518',
  'piano.instrumentSpecificGap': '194:2409879:69dddf93',
  'piano.outOfScopeDerived.0': '222:7bbd284a:5c9a973d',
  'piano.outOfScopeDerived.1': '223:3af6178d:398e2cb',
  'piano.comingSoon.0': '157:3ba5362d:77c6b702',
  'piano.comingSoon.1': '219:5052debd:11a4e94d',
  'piano.comingSoon.2': '136:1b944f84:37428606',
  'piano.foundations.five_finger.lockedReason': '396:3ca77092:1a9b026d',
  'piano.foundations.five_finger.unblockedBy': '377:16520c96:16ec7fce',
  'piano.foundations.arms.demoOnlyReason': '394:62fa8f4a:74ee8013',
  'piano.foundations.arms.blockedBy': '213:75d20b62:7e8f471b',
  'piano.foundations.arms.unblockedBy': '195:19a46a33:4a58e818',
  'piano.foundations.arms.ifItStaysBlocked': '242:63c2d8f2:44e73503',
  'piano.foundations.shoulder_tension.lockedReason': '458:235c4c6b:4a2b6a3f',
  'piano.foundations.shoulder_tension.unblockedBy': '159:3c628c58:26c8421c',
  'piano.foundations.hands_and_wrists.lockedReason': '323:64c402bb:582f943c',
  'piano.foundations.hands_and_wrists.unblockedBy': '219:2aff4ecc:552c5fc0',
};

const Map<String, String> _turkishCopy = <String, String>{
  // Guitar: measured scope, named limits, and lesson gates.
  'guitar.measured.0': 'Oturarak gövde hizası ölçülür. Bağımsız yedi gitar eğitmeninin duruşları arasında 2,24° içinde uyum vardır; bu uyum, onlardan oluşturulan kayıtlı referansla doğrulanmıştır.',
  'guitar.notMeasured.0': 'Çaldığınız ses ölçülmez. Akor motorunun bu kurstaki sekiz akorun (E A D G C Am Em Dm) dışındakileri yanlış bir ad vermeden reddettiği ölçüldü. Ancak gerçek bir gitaristin ritimli eşliğine ait üç bağımsız kaydın 150 penceresinde doğru akoru yalnız %15,3 oranında adlandırdı; dersin puanlama için gereken %90 düzeyinin çok altında. Bu ölçüm sizin çalmanızla değil kayıtlarla yapıldı. Bu sürümde mikrofon girişi yoktur; odanızdaki ses dinlenmez.',
  'guitar.notMeasured.1': 'Gitarı tutarken kol ve el konumu puanlanmaz. Eğitmenlerin duruşları stile göre 11–18° farklıdır; konum gösterilir ama değerlendirilmez (M-O-46).',
  'guitar.notMeasured.2': 'Parmak yerleşimi ve perdeye basma tekniği puanlanmaz. Kalçaları kadrajda tutan mesafede parmak ucu yalnız birkaç pikseldir; kamera güvenilir bir parmak ölçümü alamaz.',
  'guitar.notMeasured.3': 'Pena vuruşlarının zamanlaması ölçülmez. Bir vuruş altı neredeyse eşzamanlı nota başlangıcı üretir; bunları tek akora bağlayan adım yoktur. Önceki metin bunun ölçülüp yalnız puanlanmadığını söylüyordu; bu yanlıştı.',
  'guitar.notMeasured.4': 'Nota nota tam döküm yapılmaz; motor her notayı değil akor sınıfını tanır.',
  'guitar.notMeasured.5': 'Bu sekiz akorun dışındakiler adlandırılmaz. Önceden çalınan bir Si bemol 29 pencerenin 28’inde güvenle Re minör diye raporlanıyordu. Motor artık 24 akorun tamamını değerlendirir ve sonuç derste öğretilen sekiz akordan değilse reddeder.',
  'guitar.instrumentSpecificGap': 'Gitarın sapındaki parmaklarınız ve kalçalarınızın altı değerlendirilmez. Kalçalarınızı kadrajda tutan mesafede bir parmak ucu yalnızca birkaç piksel genişliğindedir; referansımızın dayandığı eğitim görüntüleri de belden yukarı çekilmiştir.',
  'guitar.comingSoon.0': 'Pena zamanlamasını puanlamak için hem vuruştaki altı nota başlangıcını tek akora bağlayan adım hem de ritim hatasına ilişkin eğitmen verisi eksiktir.',
  'guitar.comingSoon.1': 'Dirsek ve önkol açısını puanlamak doğru olmaz: ölçülen yedi eğitmen arasında 39–105° fark vardır; bu stil ve kamera açısı farkıdır. Omuz ve üst kol açılarında uyum gövde kadar yakındır, ancak kayıtlarda sağ ve sol kol güvenilir biçimde ayrılmadığı için yanlış tarafı puanlama riski vardır.',
  'guitar.comingSoon.2': 'Adlandırılmış duruş uyarısının eşiği referanstan türetilmiştir (14°), ancak bir ölçümün düzeltme önerisi olarak söylenip söylenemeyeceği için yaptırılmamış bir hareket bilimi incelemesi gerekir.',
  'guitar.outOfScopeDerived.0': 'Hataları yavaş ve bilinçli çalışmak yerine tekrar etmek kapsam dışındadır. Dört bağımsız eğitim kaynağı bunu anar; kamera bunu göremez. İzliyormuş gibi davranmıyoruz.',
  'guitar.foundations.foot_support.lockedReason': 'Kalçanızın altı ölçülmez. Duruş referansımız belden yukarı çekilmiş gitar eğitim görüntülerinden oluşturulduğu için dizler ve ayak bilekleri çoğunlukla kadrajda yoktur. Bacak noktaları olmadan ayak taburesiyle bacak bacak üstüne oturmayı ayıramayız.',
  'guitar.foundations.open_chords.lockedReason': 'Akor tanıma sentetik seste sekiz akorun tamamında, yanlış hüküm vermeden çalıştı. Gerçek gitara ait üç bağımsız kayıttaki 34 akor örneğinde ise bu kursun üç sesli akorlarında doğruluk yalnız %15,3 oldu; puanlama için gereken %90’ın çok altında. Hataların çoğu motorun tahmin etmek yerine daha zor ritimli eşlik sinyalini reddetmesinden, kalanı belirli akor çiftlerini karıştırmasından kaynaklanır. Nedenini bilsek de gerçek çalmada başarısız olan bir ölçüme göre puan vermeyiz.',
  'guitar.foundations.strum_timing.lockedReason': 'İki ayrı engel var. Pena vuruşunun ürettiği altı yakın nota başlangıcını tek akor olayına bağlayan adım yok. Bu adım olsa bile ritimden ne kadar sapmanın hata olduğuna ilişkin eğitmen verisi yok. Karşılaştırma dayanağı olmadan sayı üretip bu dersi açmayız.',
  'guitar.foundations.chords_beyond_eight.lockedReason': 'Bu kurs sekiz açık akor öğretir; motor artık diğerlerini adlarıyla reddeder. Önceden çalınan Si bemol, 29 pencerenin 28’inde güvenle Re minör diye raporlanıyordu; çünkü motor yalnız sekiz akor arasından seçim yapıyordu. Artık 24 akoru değerlendirir ve dersin kapsamı dışındaki kazananı reddeder. Diğer 16 akordaki doğruluğu ölçmeden o derslerde puan veremeyiz.',
  'guitar.foundations.arms.demoOnlyReason': 'Kaydettiğimiz eğitmenlerin dirsek ve önkol aralığını gövdenizin çizimiyle birlikte görürsünüz. Kendi dirsek açınız gösterilmez: bu sürümde canlı dirsek ölçümü yoktur; bu yüzden çizimde kollar kesiklidir ve eklem noktaları yoktur. Ölçüm olsa bile dürüst bir puanlama dayanağı bulunmuyor.',
  'guitar.foundations.arms.blockedBy': 'Referanstaki eğitmenlerin dirsek ve önkol açıları 39–105° arasında yayılır. Bu aralıktan türetilen tolerans neredeyse hiçbir şeyi hata saymaz; daha dar bir tolerans ise normal stil farkını hata sayar.',
  'guitar.foundations.arms.unblockedBy': 'Bu eklem zincirinde stil ile hatayı ayıran bir ölçüm gerekir. Örneğin kayıtlar eğitim amacıyla etiketlenirse uyum farklı amaçlar arasında değil, aynı amaç içinde hesaplanabilir.',
  'guitar.foundations.arms.ifItStaysBlocked': 'Ders olduğu gibi kalır: ölçüm gösterilir, puan verilmez. Bu kalıcı da olabilecek meşru bir durumdur; ancak kamera bu eklemleri görebildiği için kesin kalıcı demiyoruz. Eksik olan görüş değil, uzlaşıdır.',
  'guitar.foundations.foot_support.unblockedBy': 'Bacakları gerçekten kadraja alan görüntülerden yeni bir duruş referansı gerekir. Bugünkü referans belden yukarı gitar eğitim çekimlerinden oluşur; mevcut veriden çıkarılacak bir eşik yetmez.',
  'guitar.foundations.open_chords.unblockedBy': 'Gerçek çalmada ölçülmüş bir doğruluk artışı gerekir; tek veri kümesine uydurulmuş yeni eşik yetmez. Paylaşılan algılayıcı kodu değiştirilmeden önce, dersin istediği tek ve tutulmuş akora daha yakın gerçek kayıtlarla sınamak gerekir. Bu sürümde mikrofon girişi de yoktur; doğruluk tek engel değildir.',
  'guitar.foundations.strum_timing.unblockedBy': 'Altı yakın nota başlangıcını tek akora bağlayan adım ve ritim sapmasını değerlendiren eğitmen verisi birlikte gerekir. İlkini tek başına kurmak, karşılaştırılacak dayanağı olmayan bir sayı üretir. Ayrıca bu sürümde mikrofon girişi yoktur; ölçüm doğrulanmamıştır ve çalmanızı dinleme yolu bulunmaz.',
  'guitar.foundations.chords_beyond_eight.unblockedBy': 'Kalan 16 akorda tanıyıcının her akor için ve yanlış adlandırmaları sayarak ölçülmesi gerekir. Genel ortalama, daha önce düzelttiğimiz kusuru gizler. Ayrıca bu sürümde mikrofon girişi yoktur; ölçüm doğrulanmamıştır ve çalmanızı dinleme yolu bulunmaz.',
  // Voice: the shipped camera path is distinct from recorded audio research.
  'voice.measured.0': 'Şarkı söylemeye hazırlanırken gövde hizası ölçülür. Bağımsız altı şan eğitmeninin duruşları arasında 1,35° içinde uyum vardır; bu uyum kayıtlı referansla doğrulanmıştır. Referans şarkı söylerken duruşu da kapsar, ancak bu sürüm başlangıç anını algılayamaz: o aşama sesin periyodikliğine dayanır ve burada mikrofon girişi yoktur.',
  'voice.notMeasured.0': 'Odanın yeterince sessiz veya sesinizin değerlendirmeye yetecek kadar yüksek olup olmadığı canlı ölçülmez. Tahmin etmek yerine reddeden kapı kayıtlarda çalıştırıldı; bu sürümde mikrofon girişi olmadığından odanızda çalışmaz. Kurulum denetimi de bunu açıklar ve gerçekleşmeyen bir ses yakalama için ilerleme çubuğu göstermez.',
  'voice.notMeasured.1': 'Şarkı söylerken perde doğruluğu ve kararlılığı ölçülmez. Motor çalışır ve ölçülmüştür, ancak gerçek bir şan sesinde değil yalnız gerçek çello sesinde doğrulanmıştır. Şan kaydıyla doğrulanana kadar Uzatılmış nota dersi kilitlidir.',
  'voice.notMeasured.2': 'Vibrato ölçülmüştür ama puanlanmaz. Doğru hız için eğitmen verisi yoktur; sayı uydurmak ölçüm gibi görünen bir tahmin olur.',
  'voice.notMeasured.3': 'Kol, omuz ve dirsek konumu puanlanmaz. Altı eğitmen arasında bu açılar 43–88° farklıdır; bu stil ve kadraj farkıdır, hata değildir. Konum gösterilir ama değerlendirilmez.',
  'voice.notMeasured.4': 'Kalçaların altı, baş ve çene değerlendirilmez. Şan eğitim görüntüleri belden yukarı çekildiğinden dizler çoğunlukla kadrajda yoktur; referansta baş noktası da bulunmaz. Bu nedenle eğitmenlerin adlandırdığı kilitli diz ve kalkık çene hatalarını saptayamayız.',
  'voice.notMeasured.5': 'Nefes desteği, gırtlak konumu ve dil kökü kamera tarafından görülemez. Hata sözlüğümüzde yer alırlar ama bilinçli olarak ürün kapsamı dışındadır.',
  'voice.instrumentSpecificGap': 'Perde ve ses uzatma değerlendirilmez. Motor çalıştırıldı ve ölçüldü, ancak yalnızca gerçek çello sesinde; gerçek bir şan sesinde veya odanızda canlı olarak hiç doğrulanmadı.',
  'voice.comingSoon.0': 'Kilitli diz veya kalkık çene uyarısı için eğitmenlerin kullandığı hata adlarına karşılık gelen diz ve baş noktaları gerekir. Bu yeni görüntü toplama işidir; yalnız yeni eşik belirlemek yetmez.',
  'voice.comingSoon.1': 'Vibrato hızı bugün ölçülür, ancak doğru aralığı belirleyecek eğitmen verisi olmadığı için puanlanmaz.',
  'voice.comingSoon.2': 'Perde ve uzatma puanlamasının motoru hazırdır; gerçek bir şan kaydında doğrulanması gerekir (Uzatılmış nota dersi).',
  'voice.outOfScopeDerived.0': 'Yüksek gırtlak konumu ve boğaz gerginliği bilinçli olarak kapsam dışındadır. İki bağımsız eğitim kaynağı bunları anar; kamera göremez. İzliyormuş gibi davranmıyoruz.',
  'voice.outOfScopeDerived.1': 'Dil kökü gerginliği bilinçli olarak kapsam dışındadır. İki bağımsız eğitim kaynağı bunu anar; kamera göremez. İzliyormuş gibi davranmıyoruz.',
  'voice.foundations.sustained_note.lockedReason': 'Perde motoru gerçektir ve neyi ölçtüğü gösterilebilir; ancak yalnız gerçek çello kayıtlarında doğrulandı (48 bölüm, ortanca hata 19 sentin altında). Gerçek şan sesinde hiç doğrulanmadı. Vibrato, nefes ve formantlar çellodan farklıdır ve sonucu bozabilir. Şarkınızı, şan üzerinde doğrulanmamış bir ölçüme göre puanlamayız. Aynı hattan geçirilen bilinen perdeli bir gerçek şan kaydı bu ölçüm engelini kaldırır.',
  'voice.foundations.vibrato.lockedReason': 'Vibrato ölçülür ama puanlanmaz; eksik olan araç değildir. Doğru hız için eğitmen verisi yoktur. Burada sayı uydurmak ölçüm kılığında tahmin olur. Ders motor gelişince değil, bir referans oluşunca açılabilir.',
  'voice.foundations.knees_and_chin.lockedReason': 'Şan eğitmenlerinin sık adlandırdığı kilitli diz ve kalkık çeneyi göremiyoruz. Belden yukarı eğitim görüntülerinden oluşturulan referansta baş noktası yoktur; dizler de çoğunlukla kadraj dışındadır. Bu nedenle çenenin neye göre kalktığı veya dizin kilitlenip kilitlenmediği bilinmez. Yeni bir eşik değil, bu noktaları içeren yeni görüntüler gerekir.',
  'voice.foundations.arms.demoOnlyReason': 'Kaydettiğimiz eğitmenlerin dirsek ve önkol aralığını gövdenizin çizimiyle birlikte görürsünüz. Kendi dirsek açınız gösterilmez: bu sürümde canlı dirsek ölçümü yoktur; bu yüzden çizimde kollar kesiklidir ve eklem noktaları yoktur. Ölçüm olsa bile dürüst bir puanlama dayanağı bulunmuyor.',
  'voice.foundations.arms.blockedBy': 'Referanstaki eğitmenlerin dirsek ve önkol açıları 43–88° arasında yayılır. Bu aralıktan türetilen tolerans neredeyse hiçbir şeyi hata saymaz; daha dar bir tolerans normal stil farkını hata sayar.',
  'voice.foundations.arms.unblockedBy': 'Bu eklem zincirinde stil ile hatayı ayıran bir ölçüm gerekir. Örneğin kayıtlar eğitim amacıyla etiketlenirse uyum farklı amaçlar arasında değil, aynı amaç içinde hesaplanabilir.',
  'voice.foundations.arms.ifItStaysBlocked': 'Ders olduğu gibi kalır: ölçüm gösterilir, puan verilmez. Bu kalıcı da olabilecek meşru bir durumdur; ancak kamera bu eklemleri görebildiği için kesin kalıcı demiyoruz. Eksik olan görüş değil, uzlaşıdır.',
  'voice.foundations.sustained_note.unblockedBy': 'Bilinen perdeli bir gerçek şan kaydının çello kayıtlarıyla aynı yöntemle ölçülmesi gerekir. Motor tamamdır ve çellodaki hatası bilinir; eksik olan şan ölçümüdür. Ayrıca bu sürümde mikrofon girişi yoktur; ölçüm doğrulanmamıştır ve sesinizi dinleme yolu bulunmaz.',
  'voice.foundations.vibrato.unblockedBy': 'Vibrato hızını anlamlı bir aralıkla karşılaştırabilmek için yeterli sayıda bağımsız şan eğitmeninden, birbirine yakın ölçümler gerekir. Motor hızı zaten ölçer; karşılaştırma verisi yoktur. Ayrıca bu sürümde mikrofon girişi yoktur; ölçüm doğrulanmamıştır ve sesinizi dinleme yolu bulunmaz.',
  'voice.foundations.knees_and_chin.unblockedBy': 'Dizleri ve başı içeren yeni eğitim görüntüleri toplanmalı; referans bu iki hatanın gerektirdiği noktaları taşımalıdır. Bu kamera ve kadraj sorunudur, eşik sorunu değil.',
  // Piano: timing research is recorded-data only, with no microphone input.
  'piano.measured.0': 'Oturarak gövde hizası ölçülür. Bağımsız üç piyano eğitmeninin duruşları arasında 1,09° içinde uyum vardır; ölçtüğümüz çalgılar arasındaki en yakın uyum budur ve kayıtlı referansla doğrulanmıştır.',
  'piano.notMeasured.0': 'Odanızdaki nota zamanlaması ölçülmez. Zamanlama ölçümü gerçektir ve bir kayıt üzerinde yapılmıştır (AF-008-five-note-timing), ancak bu sürümde mikrofon girişi olmadığı için canlı çalışmaz. Aşağıdaki satır, canlı çalışsa bile neden puanlanamayacağını açıklar.',
  'piano.notMeasured.1': 'Nota zamanlaması puanlanmaz. Gerçek ölçüm (AF-008-five-note-timing), tam zamanında çalınan notayı 8,3 ms erken okuyor. Yanlılık eşit değil: aynı 40 ms hata hızlanırken 49 ms, yavaşlarken 31 ms okunuyor. Buna göre puan vermek, müziksel gerekçe olmadan hızlanmayı daha sert cezalandırır.',
  'piano.notMeasured.2': 'Bilek, parmak ve el biçimi puanlanmaz. Poz modeli her elde bir bilek ve üç kaba el noktası (işaret, serçe, başparmak) verir; parmak eklemlerini çözmez. Düşük bilek bir nokta değil biçimdir. Bu noktalardan el ölçümü kurulmadı, iyi bileğin nasıl göründüğüne ilişkin eğitmen verisi de yok. Hem ölçüm aracı hem referans eksiktir.',
  'piano.notMeasured.3': 'Omuz gerginliği puanlanmaz; beş bağımsız eğitim kaynağında piyano için en sık adlandırılan hatadır. Omuzlar görünür, ancak üç eğitmenin omuz açıları sağ ve solda 24° ile 5° farklıdır. “Omuzların kulaklara yükselmesi” yüksekliktir; tuttuğumuz değer açı olduğu için bunu adlandırmak tahmin olur.',
  'piano.notMeasured.4': 'Dirseğin gövdeden uzaklığı ölçülür, ancak üç eğitmenin dirsek açıları 20–77° aralığına yayılır. Bu bir eşik değil, değişkenliktir; puanlanmaz.',
  'piano.notMeasured.5': 'Tabure yüksekliği, pedal kullanımı, tuşe eşitliği ve nota okuma ya eksik araçlara bağlıdır ya da kameranın görebileceği şeyler değildir.',
  'piano.instrumentSpecificGap': 'Bilek, parmak ve el biçimi. Poz modeli bilekleri ve kaba el noktalarını içerir; ancak Ostinato’da canlı el biçimi ölçümü ve eğitmen referansı yoktur. Bu yüzden bileğin çökmesini değerlendiremez.',
  'piano.comingSoon.0': 'Nota zamanlamasını puanlamak için ritimden sapma hakkında eğitmen verisi ve motorun eşitsiz zamanlama yanlılığının düzeltilmesi gerekir.',
  'piano.comingSoon.1': 'Bilek çökmesi, düz parmaklar ve el biçimi için kurulmamış bir el biçimi ölçümü ve toplanmamış eğitmen referansı gerekir; mevcut poz noktaları parmak eklemlerini çözmez.',
  'piano.comingSoon.2': 'Piyano eğitmenlerinin en sık adlandırdığı omuz gerginliği için mevcut olmayan omuz yüksekliği ölçümü ve ona ait referans istatistiği gerekir.',
  'piano.outOfScopeDerived.0': 'Nota adlarını ezberleyip gerçek nota okumaya dayanmamak bilinçli olarak kapsam dışındadır. Dört bağımsız eğitim kaynağı bunu anar; kamera göremez. İzliyormuş gibi davranmıyoruz.',
  'piano.outOfScopeDerived.1': 'Zor bölümleri ayırmak yerine tüm parçayı tekrar tekrar çalışmak bilinçli olarak kapsam dışındadır. İki bağımsız eğitim kaynağı bunu anar; kamera göremez. İzliyormuş gibi davranmıyoruz.',
  'piano.foundations.five_finger.lockedReason': 'Bir kayıtta her notayı ayırıp vuruşa göre zamanlayabiliyoruz. Odanızda bunu yapamıyoruz: bu sürümde mikrofon girişi yoktur. Mikrofon olsa bile bu sayılardan puan üretilemez; ritimden ne kadar sapmanın hata sayıldığına ilişkin piyano eğitmeni verisi yoktur. Motor da tam zamanında çalınan notayı 8,3 ms erken ve hızlanmayı yavaşlamadan daha ağır okuyarak yanlı sonuç verir.',
  'piano.foundations.shoulder_tension.lockedReason': 'Beş bağımsız eğitim kaynağına göre piyano eğitmenlerinin en sık adlandırdığı hata omuz gerginliğidir. Omuzları görüyoruz, ancak “omuzların kulaklara yükselmesi” bir yükseklik; bizim ölçtüğümüz ise açıdır. Üç eğitmenin omuz açıları bir tarafta 24°, diğerinde 5° farklı olduğundan üzerinde uzlaşılan bir konum da yoktur. Buna hata demek ölçüme dayanarak tahmin yürütmek olur.',
  'piano.foundations.hands_and_wrists.lockedReason': 'Poz modeli bilekleri ve kaba işaret, serçe ve başparmak noktalarını içerir; parmak eklemlerini çözmez. Ostinato’da bu noktalardan kurulmuş canlı bir el biçimi ölçümü ve iyi bileğe ilişkin eğitmen referansı yoktur. Uygun ölçüm ve referans doğrulanana kadar bilek çökmesi, düz parmaklar ve el biçimi değerlendirilemez.',
  'piano.foundations.arms.demoOnlyReason': 'Kaydettiğimiz eğitmenlerin dirsek ve önkol aralığını gövdenizin çizimiyle birlikte görürsünüz. Kendi dirsek açınız gösterilmez: bu sürümde canlı dirsek ölçümü yoktur; bu yüzden çizimde kollar kesiklidir ve eklem noktaları yoktur. Ölçüm olsa bile dürüst bir puanlama dayanağı bulunmuyor.',
  'piano.foundations.arms.blockedBy': 'Referanstaki eğitmenlerin dirsek ve önkol açıları 20–77° arasında yayılır. Bu aralıktan türetilen tolerans neredeyse hiçbir şeyi hata saymaz; daha dar bir tolerans normal stil farkını hata sayar.',
  'piano.foundations.arms.unblockedBy': 'Bu eklem zincirinde stil ile hatayı ayıran bir ölçüm gerekir. Örneğin kayıtlar eğitim amacıyla etiketlenirse uyum farklı amaçlar arasında değil, aynı amaç içinde hesaplanabilir.',
  'piano.foundations.arms.ifItStaysBlocked': 'Ders olduğu gibi kalır: ölçüm gösterilir, puan verilmez. Bu kalıcı da olabilecek meşru bir durumdur; ancak kamera bu eklemleri görebildiği için kesin kalıcı demiyoruz. Eksik olan görüş değil, uzlaşıdır.',
  'piano.foundations.five_finger.unblockedBy': 'Ritimden ne kadar sapmanın hata olduğunu belirleyen eğitmen verisi ve motorun eşitsiz yanlılığının düzeltilmesi gerekir (tam zamanlı notayı 8,3 ms erken okur). İkisi de ölçüm işidir, bizim görüşümüzle seçilecek sayı değildir. Ayrıca bu sürümde mikrofon girişi yoktur; ölçüm doğrulanmamıştır ve çalmanızı dinleme yolu bulunmaz.',
  'piano.foundations.shoulder_tension.unblockedBy': 'Yalnız açı ölçüldüğü için yeni bir omuz yüksekliği ölçümü ve eğitmenler arasındaki kendi referans istatistiği gerekir. İkisi de eksiktir; hiçbiri keyfî seçilecek bir sayı değildir.',
  'piano.foundations.hands_and_wrists.unblockedBy': 'Doğrulanmış bir el biçimi ölçümü ve eğitmen referansı gerekir. Mevcut poz noktaları bileği ve kaba el uçlarını içerir, fakat parmak eklemlerini çözmez; bu noktalardan güvenilir değerlendirme yapılıp yapılamayacağı gösterilmedi.',
};
