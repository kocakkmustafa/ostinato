# Ostinato — F5 final rapor (2026-08-16, YAYIN YOLU turu)

**Mühür:** `HEAD cb629c8` · **210 commit** (bu turda **6**, hepsi PUSH'LU) · ağaç temiz ·
**42 kapı** (turda +2: `validate_template_assets.py`) + MUT-A boyunca yeşil.

## Bu turun akışı

| Commit | Ne | DEFTER |
|---|---|---|
| `1ccb030` | D14 — yerel oturum geçmişi + H-21 üçlü depo-sabotajı | O-153/O-154 |
| `d6561ac` | D6 — mağaza listesi taslağı + 4 ekran görüntüsü | O-156/O-157 |
| `b590328` | D8 — şablon ikon/açılış-ekranı → gerçek postür-figürü glifi | O-158 |
| `41dc72c` | D20 — Android imza kablolaması, geçici anahtarla uçtan uca sınandı | O-159 |
| `7177c55` | F5a — cihaz günü paketi (ön-uçuş betiği + reçete) | O-160 |
| `cb629c8` | F5b — yayın provası (gerçek App Store IPA, yüklenmedi) | O-161 |

**F4 (mağaza yüzeyi) TAM kapandı** — D6+D8+D20, aile içinde ilk. **F5 üç parçadan
ikisi kapalı** (cihaz günü + yayın provası); final rapor bu belgenin kendisi.

## Aileye yayılan bulgular (bu turda)

- **`H-45`** — async navigasyon yalnız SIRAYA ihtiyaç duyan bir I/O'ya bağlanmamalı (sonucuna değil); `full_flow_test.dart` sabotajı kendi hatamı yakaladı.
- **`H-50`/`O-155`** — bir kapı asla yeşile dönemiyorsa SIKI değil BOZUKTUR; muafiyet listesi ile mutabakat kaydı arasındaki fark (`RETENTION_WRITERS_RECONCILED`).
- **`H-51`** — dosya mtime'ı "ne zaman üretildi"nin değil "en son ne zaman dokunuldu"nun ölçümü; kendi hatamı (`ls -la` okuyup `git log`a bakmamak) kendim yakaladım, aile çapında 27/40 dosya etkiliydi.
- **`H-56`** — bir değişikliği kanıtlamak için "sonra"yı ölçmek yetmez, "önce"yi de ölçmek gerekir (`validate_template_assets.py`nin taze-`flutter create`-referans yöntemi); üç kardeş hat hâlâ stok ikonda olduğu bu yöntemle ortaya çıktı.
- **`keytool` vs `apksigner`** — `keytool -printcert -jarfile` yalnız ESKİ v1/jar imzasını anlıyor, modern v2+ imzalı bir APK'yı "not signed" diye okuyabiliyor; dört hatta iletildi.

## Açık kalanlar — adıyla, gizlenmeden

1. **`F3` (W1 içerik hasadı turu 2) BLOKE** — YouTube ToS/telif, kurucu kalemi (`M-F-653 §5c`), orkestratörün yetkisi dışında. Kör başlamadım, sorduğum an bloke olduğu ortaya çıktı.
2. **Android GERÇEK yüklenebilir artefakt** — `D20` kablolamayı geçici anahtarla kanıtladı; gerçek keystore orkestratör kalemi (`D5`, `~/.secrets/yula/motion/ostinato-upload.jks`).
3. **Kamera köprüsünün canlılığı — bu proje için HİÇ ölçülmedi.** Bugüne kadarki her kanıt simülatörde, sahte/enjekte poz kaynağıyla (`full_flow_test.dart` vb.). GERÇEK bir telefonun GERÇEK bir insan gövdesini okuyup okumadığı bilinmiyor — cihaz günü reçetesi (`docs/device-day/RECIPE.md`, madde 5-6) bunu "son kontrol" değil ASIL SORU olarak çerçeveliyor.
4. **`coached_only` eklem sınıflandırması** (dirsek/omuz vb.) ruleset'lerde serbest-metin alanında yaşıyor, bu turda eklem-eklem doğrulanmadı — mağaza metninde EKSİK bırakıldı, UYDURULMADI (`docs/store/listing.json:$measurementDisclosureLine`).
5. **`B2` (ASC yükleme)** orkestratörün kendi kalemi — ölçtü: `D6` 3/5 hat hazır (Ostinato + Gravita + JabLab), Choreia/Lissom değil; kardeş-karşılaştırma yapılmadan tek tek yüklemek yerine tek oturuşta yapılacak, kurucu paketine öyle yazıldı.

## Ship için gereken zincir (bu raporun ötesinde)

1. Kurucu cihaz günü — reçeteyi kullanır, kamera köprüsü gerçek ilk kanıtını verir.
2. Gerçek Android keystore (`D5`, orkestratör).
3. `F3`ün çözümü (kurucunun ToS kararı) YA DA mevcut şan/piyano havuzuyla W1'in sevki.
4. Orkestratörün kardeş-karşılaştırması + `B2` ASC yüklemesi (kendi zamanlaması, "beş hat hazır olunca tek oturuş").
5. Gerçek SUBMIT — `B7`, yalnız kurucu, hiçbir zaman otomatikleştirilmedi.

## Ölçüm disiplini — bu turda iki kez kendi kendimi düzelttim

- `.gitignore`de `key.properties`/`*.jks` yok sanıp "kritik boşluk" diye yazdım; `android/.gitignore`nin (Flutter'ın kendi şablonu) bunu ZATEN kapsadığını ölçtüm. DEFTER'e "kapattığım boşluk" değil "yarım ölçtüğüm" diye yazdım.
- `docs/g1/uzman-turu-envanteri.json`nin "bugün üretildiği" iddiam `ls -la` mtime'ına dayanıyordu; `git log` gerçek tarihi (9 gün eski) verdi — bu da `H-51`in kendisi oldu.

İkisi de "doğru sonuca yanlış/yarım süreçle varmak" sınıfının örneği (`H-25` ailesi) — ikisinde de sonuç zararsızdı ama süreç DEFTER'e olduğu gibi yazıldı, düzeltilerek değil.
