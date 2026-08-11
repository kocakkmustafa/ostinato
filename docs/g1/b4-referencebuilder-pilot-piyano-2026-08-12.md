# B4 — ReferenceBuilder Pilotu: Piyano-özel yeniden koşum (2026-08-12)

**Tarih:** 2026-08-12 · **Araç:** `tools/dart_pilot/bin/pilot.dart piano` (motion_core pin `f13bdc9`)
**Bu koşum, bir ÖLÇÜMdür — bir TERFİ değil.** Çıktısı ne olursa olsun
`piano.foundations.shoulder_tension` bu turda **açılmadı**; açılması ayrı
bir hüküm ister (dürüstlük kutusu + attested zincir + `validate_library`).

## Neden ŞİMDİ koşulabildi (ön koşulun kendisi — kayıtta dursun)

07-29 pilotu (`b4-referencebuilder-pilot-sonuc.md`) kendi sonraki-adımını
yazmıştı: *"Havuzu çalgı-başına ayır ve pilotu tekrar koş."* O gün ön koşul
yoktu:

| | 07-29 (karışık havuz) | 08-12 (bu koşum) |
|---|---|---|
| toplam fixture | 11 (3 çalgı karışık) | 57 (çalgı-başına ayrılmış, `config/fixture-instrument-map.json`) |
| piyano fixture | (ayrı sayılmadı) | 14 (9 attested + 5 ineligible) |
| sağ-ön-çapraz (A) | 0/11 | piyano alt-kümesinde 5/14 |

Bu tablo olmadan bir sonraki oturum *"neden o gün koşmamışlar"* diye
sorar — 07-29'da koşulamazdı, veri yoktu.

## Sonuç — eğitmenler arası dağılım (piyano-özel, 9 attested take)

| Eklem | 07-29 (karışık, 11 fixture) | 08-12 (piyano-özel, 9 attested) |
|---|---|---|
| trunk_tilt | 3.0° | 4.6° |
| left_shoulder | 13.3° | 6.6° |
| right_shoulder | 15.4° | 11.0° |
| left_upper_arm | 12.5° | 7.3° |
| right_upper_arm | 25.0° | 10.0° |
| left_elbow | 29.6° | 13.0° |
| **right_elbow** | **39.2° ⚠️ güvenilmez** | **9.3°** |
| right_forearm | 31.7° | 12.6° |
| **left_forearm** | **58.8° ⚠️ güvenilmez** | **16.6°** |

**GÜVENİLMEZ eklem (sapma >35°): YOK.** 07-29'un iki güvenilmez eklemi
(right_elbow, left_forearm) çalgı-ayrımıyla güvenilir aralığa düştü —
b4-sonuc.md'nin "doğru okuma: havuzu çalgı-başına ayırmadan kol metriği
çıkarılamaz" hipotezi bu ölçümle DOĞRULANDI.

## ⚠️ Ama: aynalama çözümü KESİN DEĞİL — taraf-bağımlı metrikler TUTULUR

```
aynalanmış take : 0/9
mirrorConfident : false (resolution: false)
runnerUpGap     : 0.00276  (çok küçük — algoritma sol/sağ atamasında emin değil)
gapMeasured     : true (tükenmeli arama — dayanak ÖLÇÜM, uydurma değil)
dışlanan (M-F-47): 8jbvOgGxk5c, F8fKXmcL7ao, SGsYZAqIwi4, cBuC89ApQtM, e-USjrHOL8s
```

Kural 7 (M-F-48): çözüm kesin değilse taraf-bağımlı (left_X vs right_X)
hüküm verilmez. Yukarıdaki tablo `left_shoulder`/`right_shoulder` gibi
taraf-etiketli satırlar taşısa da, **hangi tarafın gerçekten sol/sağ
olduğu bu koşumda ÇÖZÜLEMEDİ** — sayılar doğru ölçüldü, ama etiketleri
güvenilir değil. `shoulder_tension`in kendi engeli ("bir tarafta 24°,
diğerinde 5°") ile bu sonucu birebir eşlemek bu yüzden YAPILMADI —
farklı bir ölçüm hattından geliyor olabilirler, karşılaştırma iddiası
bu belgede kurulmuyor.

## Kaynak uygunluğu (M-F-43/M-F-62, fail-closed)

9 attested · 5 ineligible (`romMode: unknown`, daima dışarıda, isimle:
2mPS-2guHVo, D9hEN4wEwNU, N7IIVWvSyRQ, dc8PNOTTUlg, fe57D8HxuvU) · 0
unattested · 0 firstParty. `--allow-unattested` KULLANILMADI — yalnız
rig'in "uygun" dediği kaynaklar.

## Eşik icat edilmedi

Bu belge hiçbir yeni tolerans/eşik ÖNERMİYOR. Dispersiyon sayıları
pilotun kendi metodolojisinden (ReferenceBuilder + StandardJoints) geldi;
"yeterince yakın" diye bir sayı seçilmedi. `shoulder_tension`i açmak
isteyen bir sonraki adım varsa, aynalama belirsizliğini önce çözmeli
(daha fazla/daha net kaynak, ya da kural 7'nin izin verdiği bir prior).

## Ek — aynalama belirsizliği: veri miktarı mı, yapısal mı? (aynı gün, ek ölçüm)

**Soru (koordinatör):** `runnerUpGap=0,00276` küçük — eksik veriden mi,
yoksa piyanonun kendi (neredeyse simetrik) duruşundan mı? **Ucuz test:**
9 attested take'i alt-kümelere böl, `runnerUpGap`in N ile nasıl
değiştiğini ölç.

Geçici bir `--only=id1,id2,...` bayrağı `pilot.dart`a eklendi (koşum
sonrası **geri alındı**, `git checkout --`, commit'lenmedi — bu yalnız
tanı amaçlı):

| N | Hangi take'ler | runnerUpGap | mirrorConfident |
|---|---|---|---|
| 5 (A) | ilk 5 (kronolojik) | **0,0246** | **true** |
| 5 (B) | son 5 | **çöktü** — `ReferenceAgreementError`: 14° içinde küme yok (SGsYZAqIwi4 16,8° · U4mU0uu-0Aw 12,0° · cBuC89ApQtM 16,3° · e-USjrHOL8s 7,4° · p_6y7MPW_Ek 20,7°) | — |
| 7 (A) | ilk 5 + 2 | 0,0032 | false |
| 7 (B) | ilk 5 + son 2 (farklı 2) | 0,0132 | false |
| 9 | tümü | 0,0028 | false |

**Cevap ikisi de DEĞİL — soru ikiye ayrılmalıydı.** Gap, N'in düzgün bir
fonksiyonu değil: aynı N=5'te bir alt-küme TEMİZ uzlaşıyor, başka bir
alt-küme çekirdeğin kendi güvenlik kapısını (`ReferenceAgreementError`)
tetikleyip TAMAMEN reddediliyor. Bu ne "veri arttıkça netleşir" (N=5'te
zaten temiz bir sonuç ALINABİLİYOR) ne "piyano yapısal olarak simetrik"
(N=5'te bazı kombinasyonlar KESİN çözülüyor) hipoteziyle temiz uyuşuyor.

**En savunulabilir okuma: havuzun kendisi HETEROJEN.** 9 take'in bir
kısmı birbiriyle iyi uzlaşıyor, bir kısmı uzlaşmıyor (kamera açısı,
öğretim tarzı, oturuş farkı — hangisi olduğu bu ölçümle AYIRT
EDİLEMEDİ). 9-take'in düşük-güven sonucu bu karışık popülasyonun
DÜRÜST yansıması — 5 tutmayan take'i attest etmek gap'i büyütmeyebilir
(zaten karışık bir alt-kümeye daha fazla karışıklık eklenmiş olur).
**Kalıcı, isimli sınır bu:** hangi spesifik take'lerin birbiriyle
uzlaştığı/uzlaşmadığı ayrı bir ölçüm ister (her take'i sırayla dışlayıp
gap'in nasıl değiştiğine bakmak) — bu belgenin kapsamı dışında
bırakıldı, adıyla.

## Ek 2 — leave-one-out: hangi take heterojenliği taşıyor? (aynı gün)

**Yöntem:** 9 attested take'in her biri sırayla dışlanarak pilot yeniden
koşuldu (geçici `--exclude=` bayrağı, koşum sonrası **geri alındı**,
`git checkout --`, commit'lenmedi). Taban (9/9): `runnerUpGap=0,00276`.

| dışlanan | runnerUpGap | Δ taban'dan |
|---|---|---|
| 2T70e4OroEY | 0,00221 | −0,00055 |
| 2mxlG5bzcyQ | 0,00418 | +0,00142 |
| 8jbvOgGxk5c | 0,00311 | +0,00035 |
| F8fKXmcL7ao | 0,00345 | +0,00069 |
| SGsYZAqIwi4 | 0,00319 | +0,00043 |
| U4mU0uu-0Aw | 0,00279 | +0,00003 |
| **cBuC89ApQtM** | **0,00862** | **+0,00586 (~3×, en yakın etkinin 4 katı)** |
| e-USjrHOL8s | 0,00279 | +0,00003 |
| p_6y7MPW_Ek | 0,00316 | +0,00040 |

**Tek net aday: `cBuC89ApQtM`.** Onun dışlanması gap'i 3 kata çıkarıyor
(hâlâ `mirrorConfident:false` — eşik yine de aşılmıyor, ama etki tek
başına diğer sekizin toplamından büyük).

## Ek 3 — bağımsız-özellik kontrolü: dışlama İLKELİ mi? (aynı gün)

**Kural (koordinatör):** bir take'i "gap'i iyileştirdiği için" dışlamak
YASAK — o veri seçmektir. Doğru soru: `cBuC89ApQtM`, bu gece BAĞIMSIZ
ölçülmüş bir eksende (angleClass, postureRatio, fullBodyRatio, yaw)
diğer sekizden AYRIŞIYOR mu?

| take | angleClass | yaw° | fullBodyRatio | postureRatio | looGap |
|---|---|---|---|---|---|
| 2T70e4OroEY | C_frontal | 13,9 | 0,041 | 0,537 | 0,00221 |
| 2mxlG5bzcyQ | B_side_profile | 75,8 | 0,003 | 0,899 | 0,00418 |
| 8jbvOgGxk5c | A_right_front_diagonal | 52,8 | 0,022 | 0,778 | 0,00311 |
| F8fKXmcL7ao | A_right_front_diagonal | 41,3 | 0,006 | **0,086** | 0,00345 |
| SGsYZAqIwi4 | C_frontal | 24,1 | 0,006 | 0,869 | 0,00319 |
| U4mU0uu-0Aw | C_frontal | 9,1 | **0,251** | 0,476 | 0,00279 |
| **cBuC89ApQtM** | C_frontal | 10,9 | 0,043 | 0,353 | **0,00862** |
| e-USjrHOL8s | B_side_profile | 64,5 | 0,031 | 0,735 | 0,00279 |
| p_6y7MPW_Ek | B_side_profile | 66,1 | 0,021 | 0,497 | 0,00316 |

**Sonuç: PAYLAŞMIYOR — dışlama YAPILMADI.**
- angleClass: `cBuC89ApQtM` C_frontal, 4/9 take'in paylaştığı EN KALABALIK sınıf — ayırt edici değil.
- yaw: 10,9° — U4mU0uu-0Aw'ın (9,1°, looGap=0,00003, TABANA EN YAKIN etki) yaw'ına neredeyse eşit — ayırt edici değil.
- fullBodyRatio: 0,043 — SGsYZAqIwi4 (0,006) ve F8fKXmcL7ao (0,006) daha uç, onların looGap etkisi küçük — ayırt edici değil.
- postureRatio: 0,353 — F8fKXmcL7ao'nun 0,086'sı çok daha uç, ama F8fKXmcL7ao'nun looGap etkisi (0,00069) küçük — YÖN TERS, ayırt edici değil.

**Dört eksenin dördünde de `cBuC89ApQtM`, en az bir başka take ile
"benzer ama düşük-etkili" eşleşiyor** — hiçbiri onu tek başına
açıklamıyor. Bu gece ölçülen eksenlerle heterojenliğin KAYNAĞI
belirlenemedi.

**⛔ Kalıcı, isimli sınır:** `cBuC89ApQtM` DIŞLANMADI.
Aynalama belirsizliği bu 9-take havuzda ÇÖZÜLEMEDİ EN mevcut
ölçümlerle. `piano.foundations.shoulder_tension` **ölçülmüş-bloke**
kalır — kod/kural değişmedi, ders açılmadı. Heterojenliğin gerçek
kaynağı (kanal/öğretim tarzı/çekim koşulları gibi bu oturumda
ölçülmeyen bir eksen) ayrı bir soruşturma ister.

## Sonraki adım (öneri, karar değil)

- Guitar/voice için aynı koşum (`pilot.dart guitar` / `pilot.dart voice`)
  — istenirse, bu koşumun kapsamı DIŞINDA tutuldu.
- Aynalama belirsizliğini çözecek ek kaynak ya da yöntem — kurucu/
  koordinatör kararı, bu belge yalnız ölçümü raporluyor.
