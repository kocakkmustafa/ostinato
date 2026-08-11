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

## Sonraki adım (öneri, karar değil)

- Guitar/voice için aynı koşum (`pilot.dart guitar` / `pilot.dart voice`)
  — istenirse, bu koşumun kapsamı DIŞINDA tutuldu.
- Aynalama belirsizliğini çözecek ek kaynak ya da yöntem — kurucu/
  koordinatör kararı, bu belge yalnız ölçümü raporluyor.
