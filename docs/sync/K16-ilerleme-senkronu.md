# K16 — İlerleme senkronu (tasarım)

Tarih: 2026-11-01 · Dal: `feat/progress-sync` · Durum: **tasarım; sunucu tarafı uygulanmadı**

Kurucu kararı (1 Kas): senkron v1'de olacak; uygulama yerel-önce kalır, senkron
üstüne eklenir; tasarım ve uygulama PR'ı ayrı; Supabase şema değişikliği ve
canlı deploy kurucu onayı bekler.

## 0. Bugünkü durum (okunan kaynak)

| Veri | Yer ve biçim | Kapsam |
|---|---|---|
| Gitar kursu ilerlemesi | `lib/app/guitar_journey_progress.dart` → `<AppSupport>/accounts/<uuid>/guitar_journey_progress.v1.json` (`schemaVersion: 1`, `records[]`) | Anahtar `contentVersion\|lessonId` (`progressVersionFor` revizyonu dahil). Alanlar: `seenAt`, `practicedAt`, `practiceCount`, `selfReportedCompletedAt`, `evidence: self_report_only`. Tek yazma yeri `record()`; tamamlama için en az bir pratik şart. |
| Seans geçmişi | `lib/app/session_store.dart` → aynı dizinde `sessions.jsonl` (`v: 1`) | Kamera oturumu özeti (`elapsedSeconds`, `sampleCount`, `outCount`). Kamera pratiği bu sürümde kapalı. |
| Seri (streak) | **Yok.** | Yalnız son `practicedAt` tutuluyor; gün geçmişi yok. |
| Ayarlar | `ostinato.theme.v1.json`, `ostinato.locale.v1.json`, `onboarding-v1.done`, `ostinato.age_gate.v1.json` | Cihaz düzeyi, hesapsız kök dizin. |
| Diğer çalgılar (piyano, bas, ukulele, vokal) | Kalıcı ilerleme yok | Yazılı pratik. |

Kimlik: Motion Core'un ortak hesabı (`motion_account`, pin `5b15308`). Supabase
Auth, **yalnız e-posta + parola**; Sign in with Apple ve anonim oturum yok.
Kullanıcı UUID'si `AccountScope.currentUserId` ile gelir ve yerel dosyaları
`accounts/<uuid>/` altına ayırır (`account_data_directory.dart`). Oturum
kapalıyken kök dizin kullanılır; bu "konuk" geçmişi yeni bir kullanıcıya
**asla sessizce atanmaz**. Abonelik: RevenueCat yok; Core'un
`motion_entitlements` paketi `in_app_purchase` (StoreKit/Play Billing) kullanır,
sunucu `motion-verify-purchase` ile doğrular, hak kaydı `motion_entitlements`
tablosunda aynı Supabase UUID'sine bağlıdır.

Sunucu: Motion Supabase projesi `aljdbngmeqwmsqhvfeau` (SERVICES/PROJECTS;
27 Eki MCP teyidi). 2026-11-01 salt okunur tablo listesi: yalnız Core
tabloları (`motion_profiles`, `motion_entitlements`,
`motion_deleted_account_receipts`, `motion_store_review_access`,
`motion_age_declarations`, `motion_parental_consents`,
`motion_trial_ledger`); hepsinde RLS açık. Uygulamaya özgü ilerleme tablosu
yok. Core'un `motion-delete-account` fonksiyonu `auth.admin.deleteUser` çağırır;
`auth.users`'a `on delete cascade` bağlı satırlar onunla silinir.

## 1. Kimlik — ⚠️ kurucu kararı

| Seçenek | Artı | Eksi |
|---|---|---|
| **A. Ortak Motion hesabı (Supabase UUID)** — öneri | Zaten var; abonelik de aynı kimlikte; iOS↔Android çalışır; silme yolu hazır (cascade). | Mağaza etiketi değişir (§7); sunucuya yeni tablo. |
| B. Supabase anonim oturum | Hesapsız senkron | Auth Core'un; yeni Auth kullanıcıları, kurtarma yok, bağlama karmaşık; Core değişikliği ister. |
| C. Platform bulutu (iCloud KVS / Android Backup) | Geliştirici veriyi görmez, etiket değişmeyebilir | iOS↔Android arası yok; Android Backup çoklu cihaz senkronu değil; iki ayrı uygulama. |
| D. Sign in with Apple | Hızlı giriş | Core değişikliği; Android'de ayrı akış; senkron sorununu çözmez. |

**Öneri: A.** Senkron yalnız oturum açmış ve doğrulanmış hesapta çalışır.

**Hesapsız kullanıcı:** ilerleme bugünkü gibi yalnız cihazda kalır, ağ yok.
Konuk ilerlemesini ilk girişte hesaba taşımak bugünkü "sessizce atanmaz"
kuralı yüzünden ancak **açık kullanıcı onayıyla** olabilir; v1'e girip
girmeyeceği ⚠️ kurucu kararıdır (öneri: v1'de yok, konuk verisi yerelde kalır).

## 2. Veri modeli

**Senkronlanır (yalnız gitar kursu ilerlemesi):** anahtar `contentVersion` +
`lessonId`; `seenAt` (ilk görülme), `practicedAt` (son pratik),
`completedAt` (kullanıcı beyanıyla tamamlama), `practiceCounts` (kopya başına
pratik sayacı, §3).

**Asla senkronlanmaz:** ses, video, kamera karesi, ham açı/Hz/cents ölçümü,
`sessions.jsonl` seans özetleri (`sampleCount`/`outCount` ölçümden türer),
yaş kapısı, tema/dil/onboarding ayarları, cihaz modeli, reklam kimliği.
Seri yok; ileride eklenirse senkronlanan `practicedAt`'ten değil, ayrıca
onaylanacak bir "pratik günleri" kümesinden türetilir.

Ayarlar v1'de senkronlanmaz (cihaz düzeyi; kayıpları zararsız).

## 3. Çakışma çözümü

Her kayıt durum-temelli bir CRDT'dir; birleşme **değişmeli, birleşmeli,
idempotent**tir. Bu yüzden sıra, tekrar ve gecikme sonucu değiştirmez.

| Alan | Kural | Gerekçe |
|---|---|---|
| `seenAt` | en erken (null yok sayılır) | "ilk görüldü" |
| `practicedAt` | en geç | "son pratik" |
| `completedAt` | en erken; bir kez dolunca boşalmaz | Tamamlama monoton; uygulamada "geri al" yok |
| `practiceCounts` | kopya kimliği başına `max`, toplam = değerlerin toplamı (G-Counter) | İki cihaz çevrimdışı pratik yaparsa ikisi de sayılır; düz `max` artışları kaybederdi |

- Kopya kimliği (`replicaId`): hesap + kurulum başına cihazda üretilen rastgele
  UUID. Donanım/reklam kimliği değildir; yalnız sayaç birleşmesinde kullanılır;
  hesap dizininde durur, hesapla silinir.
- Farklı `contentVersion` ayrı kayıttır; revize ders eski tamamlamayı devralmaz
  (bugünkü yerel kural).
- Değişmez: tamamlama varsa sayaç > 0. Her iki taraf da sağlıyorsa birleşme de
  sağlar.
- İleride "ilerlemeyi sıfırla" eklenirse monotonluk bozulur; o gün hesap başına
  bir sıfırlama dönemi (epoch) eklenir. v1'de yok.

## 4. Çevrimdışı kuyruk

Durum-temelli birleşme sayesinde kuyruk bir işlem günlüğü değil, **kirli
anahtar kümesidir**. Yerel yazma kaydı birleştirir ve anahtarı kirli işaretler.
Senkron turu: çek (imleçten beri) → yerelle birleştir → kirli anahtarların
birleşmiş hâlini gönder → başarılıysa kirli kümeyi temizle. Ağ hatasında hiçbir
şey kaybolmaz; aynı kayıt tekrar gönderilebilir (idempotent). Tetikleyiciler:
doğrulanmış oturum açılışı, ön plana dönüş, yerel yazmadan sonra gecikmeli
tek tur. Arka plan görevi yok. Çekme imleci sunucu saatidir; işlem sırası
belirsizliğine karşı birkaç dakikalık örtüşmeyle çekilir (birleşme
idempotent olduğu için zararsız). Kullanıcı başına ~700 satır olduğundan v1 tam
çekme de yapabilir.

## 5. Şema önerisi (uygulanmadı)

Dosya: [`supabase/proposals/K16_ostinato_lesson_progress.sql`](../../supabase/proposals/K16_ostinato_lesson_progress.sql)

- Tablo `public.ostinato_lesson_progress`, PK `(user_id, content_version,
  lesson_id)`, `user_id → auth.users on delete cascade`, alan sınırları ve
  `practice_counts` doğrulaması CHECK ile.
- RLS: istemci yalnız kendi satırını **okur ve silebilir**. Doğrudan
  insert/update yetkisi yok.
- Yazma yalnız `ostinato_push_lesson_progress(jsonb)` RPC'si ile: `auth.uid()`
  zorunlu, `motion_account_restricted` hesapta (veli onayı bekleyen) reddeder,
  en çok 500 kayıt, aynı anahtar bir partide bir kez, zamanlar sunucu saatiyle
  kırpılır, birleşme §3 kuralıyla sunucuda yapılır (son yazan kazanmaz).
- Açık `grant`'ler (30 Eki Supabase varsayılan değişikliğine uygun).
- 2026-11-01 yalnız yerel, geçici bir Postgres kümesinde (sahte `auth` şeması
  ve `motion_account_restricted` taslağıyla) koşuldu: birleşme, tekrar
  gönderimin idempotentliği, ileri tarih kırpma (NULL korunur), pratiksiz
  tamamlama/bozuk kopya kimliği/yinelenen anahtar reddi, doğrudan
  insert/update reddi, başka hesabın 0 satır görmesi, kısıtlı ve anonim
  çağrının reddi, kendi satırını silme ve `auth.users` cascade'i beklendiği
  gibi. Bu, Supabase/PostgREST/GoTrue kabulü değildir.

## 6. İstemci mimarisi

- Yerel depo **birincil kalır**: ekranlar bugünkü gibi
  `GuitarJourneyProgressStore`'dan okur; ağ yokken davranış aynıdır.
- Bu dalda eklenen sunucusuz dilim (`lib/app/sync/`):
  - `LessonProgressSyncRecord` — §3 birleşme kuralı ve doğrulama;
  - `ProgressSyncAdapter` — `pull(accountUserId, since)` /
    `push(accountUserId, records)` arayüzü;
  - `InMemoryProgressSyncAdapter` — sahte sunucu (testler için, ağ yok);
  - `ProgressSyncEngine` — yerel eylem uygulama, kirli küme, tek senkron turu.
  - `ostinatoProgressSyncAvailable = false` (`ostinato_release_policy.dart`);
    hiçbir yere bağlı değil, uygulama davranışı değişmedi.
- Sonraki uygulama PR'ı (kurucu onayından sonra): senkron durumu hesap
  dizininde yan dosyada (`progress_sync.v1.json`: `replicaId`, kayıtlar, kirli
  küme, imleç); `record()` aynı kuyrukta (`AccountDataOperations`) yan dosyayı
  da günceller; birleşmiş toplamlar v1 dosyasına yazılır. Gerçek adaptör
  mevcut `supabase_flutter` istemcisiyle (yeni bağımlılık/servis yok) ve her
  çağrıdan önce/sonra `AccountOwnershipEpoch` ile oturumun hâlâ aynı UUID
  olduğunu denetler (A'nın verisi B oturumuyla gönderilmez).
- Test kapısı: `test/flutter_test_config.dart` sıfır-ağ kapısı kalır; gerçek
  adaptör yalnız ayrı E2E'de koşar.

## 7. Hesap silme ve veri silme

- **App Store 5.1.1(v) / Play hesap silme:** uygulama içi silme Core'da var.
  `motion-delete-account` → `deleteUser` → `on delete cascade` ilerleme
  satırlarını da siler; ek fonksiyon gerekmez. Yerelde
  `deleteAccountData` hesap dizinini (yan dosya dahil) siler.
- **Hesabı silmeden veri silme (Play'in "veri silme" seçeneği):** ayarlarda
  "Sunucudaki ilerlemeyi sil" = RLS `delete` politikasıyla kendi satırlarını
  silme; yerel ilerleme kalır ve senkron kapanır.
- Çıkış yapmak ve hesap değiştirmek yerel veriyi silmez, senkronu durdurur.
- `yulalab.com/privacy/motion` hesap silme bölümüne "Ostinato ders ilerlemesi
  hesapla birlikte silinir" satırı eklenir (Yulalab sitesi işi).

## 8. Gizlilik beyanı ve etiket değişiklikleri

Senkron açıldığı sürümde ders ilerlemesi **cihaz dışına çıkar = toplanan veri**
olur. Bugünkü beyan ("Gitar kursu ilerlemesi … Motion hesabına senkronize
edilmez", `docs/store/account-data-safety-draft.md`) o sürümde değişir.

| Yer | Değişiklik |
|---|---|
| `ios/Runner/PrivacyInfo.xcprivacy` | `NSPrivacyCollectedDataTypeProductInteraction` (Linked=true, Tracking=false, App Functionality) eklenir; yedi tür → sekiz. `tools/validate_privacy_manifest.py` beklentisi aynı PR'da. |
| App Store Connect App Privacy | Usage Data → Product Interaction; kimliğe bağlı; izleme yok. |
| Play Data safety | App activity → App interactions; zorunlu değil (senkron isteğe bağlı/hesapla); aktarımda şifreli; silme talep edilebilir. |
| `docs/store/account-data-safety-draft.md` | İlerleme satırı "Evet, Motion hesabına" olarak güncellenir; seans geçmişi satırı "Hayır" kalır. |
| Gizlilik politikası sayfası | Ders ilerlemesi, amaç, saklama ve silme. |

Etiket ve manifest **senkronu açan sürümle birlikte** değişir; bayrak kapalı
olan bu dal hiçbir beyanı değiştirmez.

## 9. Riskler

- Etiket değişmeden senkron açılırsa mağaza beyanı yanlış olur → manifest
  kapısı ve bayrak aynı PR'da.
- Kirli küme kaybı: kirli küme diske yazılmadan uygulama kapanırsa o anahtar
  gönderilmeyebilir; kayıt yerelde durur ve periyodik tam gönderim düzeltir.
- Eşzamanlılık: `syncOnce` saf bir turdur; tur sürerken gelen yerel yazma
  sonuçla birleştirilmelidir. Uygulama PR'ı turu `AccountDataOperations`
  kuyruğunda yerel yazmalarla sıralar.
- Saat kayması: `practicedAt` ileri tarihli olabilir → sunucu `now()` ile kırpar.
- Hesap karışması: yanlış oturumla gönderim → epoch denetimi (§6).
- Supabase açık grant değişikliği: öneri SQL'i açık grant içerir; yine de
  canlıda RLS/grant ayrı kabul ister.
- Motion projesi beş uygulamanın ortak projesi: uygulamaya özgü tablo ortak
  projeye girer (aşağıda karar).

## 10. ⚠️ Kurucu kararı gereken noktalar

1. **Kimlik:** A (ortak Motion hesabı) mı, C (platform bulutu, çapraz platform
   yok, etiket değişmeyebilir) mi? Öneri A.
2. **Konuk ilerlemesi:** ilk girişte açık onayla hesaba taşınsın mı? Öneri:
   v1'de hayır.
3. **Şema sahipliği:** uygulamaya özgü `ostinato_lesson_progress` tablosu ortak
   Motion projesine mi (migration Core reposu üzerinden, ayrı onayla), yoksa
   Core'da beş uygulamaya ortak genel bir ilerleme tablosu mu? Öneri: önce
   Ostinato'ya özgü tablo; genelleme ikinci uygulama gelince.
4. **Supabase migration ve canlı deploy onayı.**
5. **Etiket değişikliği:** App Store "Product Interaction" ve Play "App
   interactions" eklenmesi; `replicaId`'nin ayrı "Device ID" sayılıp
   sayılmayacağı (öneri: ilerleme kaydının parçası, cihaz kimliği değil —
   hukuk teyidi).
6. **Veli onayı bekleyen hesap:** senkron kapalı mı (öneri, Core'un
   `motion_account_restricted` kuralıyla tutarlı) yoksa açık mı?
7. **Kapsam:** v1 yalnız gitar kursu ilerlemesi; seans geçmişi, ayarlar ve seri
   dışarıda. Onay?
