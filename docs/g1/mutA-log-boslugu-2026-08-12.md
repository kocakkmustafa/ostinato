# MUT-A log boşluğu — pid 81734 vakası (2026-08-12)

**Soru (koordinatör):** `contributingTakes 3→99` yine çıktı ve bu kez
kimse `kill` yapmadı. Kendi log'unu oku — kaynağı bulunabilir mi?

## Ölçüm

`.mutA-log.jsonl` (170 satır, 20:35–22:57 arası) **10 tam koşumun
onunda da** temiz: her biri `run_start`→...→`final_restore`(restored:
true)→`run_end`(exit_code:0) zinciriyle bitiyor. Bir tanesi
(`pid 35164`) organik bir kesintiden `heal_detected`/`heal_result` ile
onarıldı — O-087'nin canlı kanıtı.

**Ama `pid 81734` (asıl işlenmemiş kalıntının kaynağı) log'da HİÇ YOK**
— ne `run_start`, ne `heal_blocked`. `git checkout --` ile onarıldığında
(unstaged olduğu için güvenli) sentinel zaten silinmişti.

## Bulgu — log'un kendi kör noktası

`main()`'in ESKİ sırası:
```
_heal_if_needed()
BACKUP_DIR.mkdir() + 7 dosya kopyala + digest hesapla + DIGESTS.json yaz
SENTINEL.write_text(...)
_log("run_start", ...)   ← BURAYA KADAR gelmeyen süreç İZSİZ ölür
```

`_heal_if_needed()`'in KİLİT dalı (`heal_blocked`) zaten günlüklüyordu
— kod satırı doğru. Ama pid 81734 bu dala hiç düşmediyse (örn. sentinel
henüz yokken başladıysa) ve **backup-kurulumu (mkdir+7 kopya+digest,
üç ayrı dosya-sistemi işlemi) SIRASINDA** öldüyse, sentinel/log
YAZILMADAN önce süreç bitmiş olabilir — bu durumda NE sentinel NE log
kalır, ve bulduğumuz sentinel (pid 81734) BAŞKA bir açıklama ister; tam
mekanizma bu kanıtla %100 KAPATILAMADI. **Ama kesin olan şu:** log'un
`run_start`ı, süreç ölümüne en açık üç dosya-sistemi işleminden SONRA
geliyordu — bu, adıyla bir kör nokta.

⚠️ **Tam kapanmadı, adıyla:** pid 81734'ün NEDEN `_alive(81734)` testini
GEÇTİĞİ (böylece heal yerine kilit dalına düştüğü) ayrı bir soru —
O-079'un PID-yeniden-kullanım riskiyle aynı sınıf olabilir (bu gece
pid 27209'da bir kez ölçülmüştü): sistemde aynı anda çok sayıda `dart
run` süreci (leave-one-out analizi) çalışıyordu, biri 81734'ü devralmış
olabilir. Bu KANITLANMADI, yalnız en olası ikinci açıklama olarak
adıyla bırakılıyor.

## Panzehir uygulandı

`SENTINEL.write_text` + `_log("run_start", ...)` artık backup-
kurulumundan ÖNCE, `main()`'in İLK işi. Bu noktadan sonra ölen HER
süreç en azından `run_start` bırakır. Eğer backup-kurulumu
tamamlanmadan ölürse, `DIGESTS.json` de yoktur — `_heal_if_needed()`
zaten bu durumda "son çare git" yoluna düşüyor (kod değişmedi,
davranış zaten doğruydu).

**Doğrulama:** `python3 tools/gate_mutation_test.py --selftest-log`
exit=0, üç senaryo (`heal_detected`/`heal_result`/`heal_blocked`) yine
log'a düştü — refactor davranışı bozmadı.

## Kapanmayan soru (isimli, kalıcı) — pid 81734

pid 81734'ün TAM ölüm anı (hangi satırda) ve `_alive()`'ın onu neden
"canlı" saydığı kanıtlanamadı. Panzehir (erken log) bu SINIFI kapatır
ama bu SPESİFİK vakayı geriye dönük açıklamaz — log o an henüz
erken-yazmıyordu.

## Ek — kendi panzehirim kendi hatamı taşıdı, canlı yakalandı

İlk yazımda `SENTINEL.write_text(...)`'i `BACKUP_DIR.mkdir(...)`'den
ÖNCEYE almıştım ("erken kayıt" mantığıyla) — ama `SENTINEL =
BACKUP_DIR / "IN-FLIGHT"`, yani dizin yoksa yazım **çöker**. Bu commit'i
denerken (pid 91294, 92226, 92855, ve doğrudan bir tanı koşumunda)
ART ARDA "MUT-A ZATEN KOŞUYOR" gördüm — ilk üçü gerçekten anlık kilit
çakışması sanılabilirdi (ağaç temizdi), ama DOĞRUDAN `run_gates.sh`
koşumunda tam traceback yakalandı:

```
FileNotFoundError: [Errno 2] No such file or directory: '.mutA-backup/IN-FLIGHT'
```

**Bu, pid 81734'ü AÇIKLAMAZ** (o olay bu düzeltmeden ÖNCE, dün gece
oldu) — ama muhtemelen 91294/92226/92855 üçlüsünü açıklıyor: her commit
denemesi arasında `.mutA-backup/` bir önceki koşumun `finally`
bloğunda `shutil.rmtree` ile siliniyordu, sonraki koşum SENTINEL'i
dizin yeniden kurulmadan yazmaya çalışınca çöküyordu — çöken süreç de
kendi sentinel'ini bırakamadığı için "ZATEN KOŞUYOR" mesajı aslında
YANLIŞ TEŞHIS edilmiş olabilir (gerçek sebep kilit değil çökmeydi).

**Düzeltildi:** `BACKUP_DIR.mkdir(exist_ok=True)` artık SENTINEL
yazımından ÖNCE — doğru sıra: mkdir (ucuz) → sentinel+log → kopyalama/
digest. **En riskli senaryoyla doğrulandı:** `.mutA-backup/` TAMAMEN
silinip `python3 tools/gate_mutation_test.py` doğrudan koşuldu —
13/13 mutasyon doğru davrandı, log'a düştü, restore tuttu, exit=0.

🎓 **Ders:** bir panzehir yazarken "daha erken kaydet" doğru ilke, ama
YAZDIĞIN YERİN ÖN KOŞULLARINI (burada: ebeveyn dizinin varlığı) atlamak
panzehirin kendisini yeni bir arıza sınıfı yapar. Kendi düzeltmemi
kendi testimle yakaladım — "kırmızı yandı" görmek "doğru şeyin
yandığını" görmek değildir kuralının bu geceki son tekrarı.
