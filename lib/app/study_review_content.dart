// Authored reading/recall activities derived from the source references below.
// These do not promote physical instruction, media rights, scoring or mastery.
final class StudyText {
  const StudyText(this.en, this.tr);
  final String en, tr;
}

final class RecallLesson {
  const RecallLesson({
    required this.id,
    required this.title,
    required this.teaching,
    required this.question,
    required this.answer,
  });
  final String id;
  final StudyText title, teaching, question, answer;
}

final class StudyArea {
  const StudyArea({
    required this.id,
    required this.title,
    required this.boundary,
    required this.sourceRefs,
    required this.lessons,
  });
  final String id;
  final StudyText title, boundary;
  final List<String> sourceRefs;
  final List<RecallLesson> lessons;
}

const List<StudyArea> studyAreas = <StudyArea>[
  StudyArea(
    id: "piano",
    title: StudyText("Piano and keyboard", "Piyano ve klavye"),
    boundary: StudyText(
      "Reading and written recall only; no movement is needed. Demonstration, personal suitability and physical technique require separate review.",
      "Yalnız okuma ve yazılı hatırlama; hareket gerekmez. Gösterim, kişisel uygunluk ve fiziksel teknik ayrı inceleme gerektirir.",
    ),
    sourceRefs: <String>[
      "assets/content/piano_beginner.v1.json#piano-02",
      "assets/content/piano_beginner.v1.json#piano-04",
    ],
    lessons: <RecallLesson>[
      RecallLesson(
        id: "piano.1",
        title: StudyText("Find C from a pair", "Do’yu ikiliden bul"),
        teaching: StudyText(
          "Black keys repeat in groups of two and three. C is the white key immediately left of a pair. White keys repeat C D E F G A B. This is a keyboard map, not detected pitch feedback.",
          "Siyah tuşlar ikili ve üçlü gruplarla tekrarlanır. Do, ikilinin hemen solundaki beyaz tuştur. Beyaz tuşlar Do Re Mi Fa Sol La Si sırasındadır. Bu klavye haritasıdır; algılanmış ses geri bildirimi değildir.",
        ),
        question: StudyText(
          "In a drawing, where do you label C relative to a pair of black keys?",
          "Çizimde iki siyah tuşa göre Do’yu nerede işaretlersin?",
        ),
        answer: StudyText(
          "On the white key immediately to the pair’s left. If lost, locate a pair again rather than guessing from a triple.",
          "İkilinin hemen solundaki beyaz tuşta. Kaybolursan üçlüden tahmin etmek yerine ikiliyi yeniden bul.",
        ),
      ),
      RecallLesson(
        id: "piano.2",
        title: StudyText("Rests belong to the pulse", "Sus vuruşa dahildir"),
        teaching: StudyText(
          "A rest occupies counted time without a new note. Written rhythm recall compares event order and durations; it does not prove live timing or key-release control.",
          "Sus, yeni nota olmadan sayılan süreyi kaplar. Yazılı ritim hatırlaması olay sırası ve süreyi karşılaştırır; canlı zamanlamayı veya tuş bırakma kontrolünü kanıtlamaz.",
        ),
        question: StudyText(
          "A four-count row has a note then a rest. Should the count disappear during the rest?",
          "Dört sayımlık satırda nota ardından sus var. Sus sırasında sayım kaybolmalı mı?",
        ),
        answer: StudyText(
          "No. Keep the pulse count while distinguishing sound from silence. Compare the same written row before claiming any playing result.",
          "Hayır. Sesi sessizlikten ayırırken vuruş sayımını koru. Çalma sonucu iddia etmeden aynı yazılı satırı karşılaştır.",
        ),
      ),
    ],
  ),
  StudyArea(
    id: "vocal",
    title: StudyText("Vocal", "Vokal"),
    boundary: StudyText(
      "Reading and written recall only; no movement is needed. Demonstration, personal suitability and physical technique require separate review.",
      "Yalnız okuma ve yazılı hatırlama; hareket gerekmez. Gösterim, kişisel uygunluk ve fiziksel teknik ayrı inceleme gerektirir.",
    ),
    sourceRefs: <String>[
      "assets/content/vocal_beginner.v1.json#vocal-07",
      "assets/content/vocal_beginner.v1.json#vocal-09",
    ],
    lessons: <RecallLesson>[
      RecallLesson(
        id: "vocal.1",
        title: StudyText(
          "Pitch direction versus volume",
          "Ses yönü ve ses yüksekliği",
        ),
        teaching: StudyText(
          "A pitch rising in a contour is different from singing louder. The contour task describes relative direction; the app does not approve a comfortable vocal range or detected pitch from a written answer.",
          "Konturda sesin incelmesi daha yüksek sesle söylemekten farklıdır. Kontur görevi göreli yönü açıklar; uygulama yazılı cevaptan rahat vokal aralığı veya algılanmış sesi onaylamaz.",
        ),
        question: StudyText(
          "Does an upward contour arrow mean “use more volume”?",
          "Yukarı kontur oku “sesini daha çok yükselt” mi demektir?",
        ),
        answer: StudyText(
          "No. It names pitch direction. Volume is separate, and no singing is needed for this reading task.",
          "Hayır. Sesin incelme yönünü adlandırır. Ses yüksekliği ayrıdır; bu okuma görevinde söylemek gerekmez.",
        ),
      ),
      RecallLesson(
        id: "vocal.2",
        title: StudyText(
          "Read a contour and silence",
          "Konturu ve sessizliği oku",
        ),
        teaching: StudyText(
          "An original contour can show repeated, rising or falling tones and counted rests without specifying an absolute starting pitch. Recall compares the symbols and durations.",
          "Özgün kontur kesin başlangıç sesi belirtmeden tekrar, yükselen veya alçalan seslerle sayılan susları gösterebilir. Hatırlama sembollerle süreleri karşılaştırır.",
        ),
        question: StudyText(
          "Can a correctly recalled contour establish the exact sung starting note?",
          "Doğru hatırlanan kontur söylenmiş kesin başlangıç notasını kanıtlar mı?",
        ),
        answer: StudyText(
          "No. Relative contour and absolute pitch are different evidence. Leave actual singing and pitch detection unverified.",
          "Hayır. Göreli kontur ve kesin ses farklı kanıttır. Gerçek söyleme ve ses algılamayı doğrulanmadı bırak.",
        ),
      ),
    ],
  ),
  StudyArea(
    id: "ukulele",
    title: StudyText("Ukulele", "Ukulele"),
    boundary: StudyText(
      "Reading and written recall only; no movement is needed. Demonstration, personal suitability and physical technique require separate review.",
      "Yalnız okuma ve yazılı hatırlama; hareket gerekmez. Gösterim, kişisel uygunluk ve fiziksel teknik ayrı inceleme gerektirir.",
    ),
    sourceRefs: <String>[
      "assets/content/ukulele_beginner.v1.json#ukulele-01",
      "assets/content/ukulele_beginner.v1.json#ukulele-13",
    ],
    lessons: <RecallLesson>[
      RecallLesson(
        id: "ukulele.1",
        title: StudyText("Name the exact tuning", "Kesin akordu adlandır"),
        teaching: StudyText(
          "The pathway specifies a high-G G4 C4 E4 A4 ukulele setup. A low-G or baritone instrument is a different configuration, not a silent replacement.",
          "Yol yüksek-Sol Sol4 Do4 Mi4 La4 ukulele düzenini belirtir. Alçak-Sol veya bariton çalgı farklı düzendir; sessizce yerine konmaz.",
        ),
        question: StudyText(
          "The instrument says low-G. Can its tuning be labelled high-G without checking?",
          "Çalgı alçak-Sol diyor. Kontrol etmeden yüksek-Sol diye işaretlenebilir mi?",
        ),
        answer: StudyText(
          "No. Identify the exact configuration and use matching guidance. This task does not instruct retuning an unknown string set.",
          "Hayır. Kesin düzeni tanı ve ona uygun öğreti kullan. Bu görev bilinmeyen tel takımını yeniden akort etmeyi öğretmez.",
        ),
      ),
      RecallLesson(
        id: "ukulele.2",
        title: StudyText("Hold versus rest", "Uzatma ve sus"),
        teaching: StudyText(
          "A hold lets the earlier sound continue; a rest is counted silence. “No new stroke” alone does not distinguish them. Sparse rhythm still needs an explicit event at each counted position.",
          "Uzatma önceki sesin sürmesine izin verir; sus sayılan sessizliktir. Yalnız “yeni vuruş yok” ikisini ayırmaz. Seyrek ritimde de her sayılan konumun olayı açık gerekir.",
        ),
        question: StudyText(
          "A written row says hold, then rest. What changes if neither position has a new stroke?",
          "Yazılı satır uzatma, sonra sus diyor. İkisinde de yeni vuruş yoksa ne değişir?",
        ),
        answer: StudyText(
          "The existing sound continues in the hold; the rest is silence. A written distinction does not verify real muting or timing.",
          "Uzatmada mevcut ses sürer; sus sessizliktir. Yazılı ayrım gerçek susturmayı veya zamanlamayı doğrulamaz.",
        ),
      ),
    ],
  ),
  StudyArea(
    id: "bass",
    title: StudyText("Bass", "Bas"),
    boundary: StudyText(
      "Reading and written recall only; no movement is needed. Demonstration, personal suitability and physical technique require separate review.",
      "Yalnız okuma ve yazılı hatırlama; hareket gerekmez. Gösterim, kişisel uygunluk ve fiziksel teknik ayrı inceleme gerektirir.",
    ),
    sourceRefs: <String>[
      "assets/content/bass_beginner.v1.json#bass-13",
      "assets/content/bass_beginner.v1.json#bass-14",
    ],
    lessons: <RecallLesson>[
      RecallLesson(
        id: "bass.1",
        title: StudyText(
          "Sounding and written octave",
          "Gerçek ve yazılı oktav",
        ),
        teaching: StudyText(
          "The bass pathway uses sounding E1 A1 D2 G2 open strings. Standard bass-clef notation writes these an octave higher. The written label and sounding pitch must be named separately.",
          "Bas yolu gerçek Mi1 La1 Re2 Sol2 açık telleri kullanır. Standart Fa anahtarı bunları bir oktav yukarı yazar. Yazılı etiket ve gerçek ses ayrı adlandırılmalıdır.",
        ),
        question: StudyText(
          "The lowest open string sounds E1. What written octave label does this convention use?",
          "En pes açık tel Mi1 duyulur. Bu düzen hangi yazılı oktav etiketini kullanır?",
        ),
        answer: StudyText(
          "E2 written, E1 sounding. The octave label alone is not an audio observation of the instrument.",
          "Yazılı Mi2, gerçek Mi1. Oktav etiketi tek başına çalgının ses gözlemi değildir.",
        ),
      ),
      RecallLesson(
        id: "bass.2",
        title: StudyText(
          "Count subdivisions and rests",
          "Bölünmeleri ve susları say",
        ),
        teaching: StudyText(
          "Eighth-note subdivisions split a beat into two positions. A rest keeps its counted time while sound is absent. Note order, duration and silence are distinct written checks.",
          "Sekizlik bölünmeleri vuruşu iki konuma ayırır. Seste sessizlik varken sus sayılan süresini korur. Nota sırası, süre ve sessizlik ayrı yazılı kontrollerdir.",
        ),
        question: StudyText(
          "If one eighth-note position is a rest, should the written count skip that position?",
          "Bir sekizlik konum sus ise yazılı sayım o konumu atlamalı mı?",
        ),
        answer: StudyText(
          "No. Keep both positions in the pulse and mark the silent one as rest. Do not infer actual bass timing or muting from written recall.",
          "Hayır. İki konumu da vuruşta koru, sessiz olanı sus işaretle. Yazılı hatırlamadan gerçek bas zamanlaması veya susturma sonucu çıkarma.",
        ),
      ),
    ],
  ),
];
