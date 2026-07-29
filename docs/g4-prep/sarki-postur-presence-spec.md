# Şan postürü için "presence" spec'i (öneri, karar DEĞİL)

**Tarih:** 2026-07-29 · **Talep:** koordinatör (M-F-108) — `presence_isolator`
core'a merge olduğunda analiz hazır başlasın diye önceden yazılan hazırlık.
**Durum:** ÖNERİ. Eşik/tasarım kararları koordinatörde; burada yalnız
GERÇEK VERİYLE desteklenen bir çerçeve sunuluyor.

## 1. Problem — M-F-95'in şüphesi şimdi ÖLÇÜLDÜ

M-F-95: "şancılar ayakta ve hareketli; postür-tutuş nadir" — `hold_isolator`
(durağanlık arayan araç) şan malzemesine yapısal olarak uymayabilir.

**Ölçtüm (bu spec'i yazmadan önce, 4 uygun şan kaynağında, 5sn kayan
pencerelerde, `hold_isolator`'ın AYNI `_hold_energy`/`_drift`
fonksiyonlarıyla — yeni bir ölçüm icat etmedim):**

| Kaynak | enerji medyan | enerji max | **drift medyan** | **drift max** |
|---|---|---|---|---|
| GiHZrYCAIas | 0,190/s | 0,887/s | **0,895** | 3,818 |
| xm1NdA4cmEs | 0,120/s | 0,302/s | **0,972** | 2,309 |
| II2b3gs31SU | 0,117/s | 0,238/s | **0,273** | 1,449 |
| CGhlnPVquHw | 0,161/s | 0,242/s | **0,467** | 1,391 |

`hold_isolator`'ın gitar/piyano için kalibre edilmiş eşiği `max_drift:
0,06-0,08`. Şan verisinde medyan drift bunun **4-16 KATI**. Bu tesadüf
değil, yapısal: **enerji** (kare-kare hız) medyanda hâlâ makul bir aralıkta
(0,12-0,19/s) ama **drift** (pencere-medyanından sapma) sürekli yüksek —
yani şarkıcı hızlı hareket ETMİYOR ama pencere boyunca YAVAŞÇA SÜRÜKLENİYOR
(nefes, doğal salınım, ağırlık aktarımı). Bu tam olarak `hold_isolator`'ın
kendi "yavaş sürüklenme" tuzağının (M-F-75 modül dokümanı) TERSİ bir vaka:
orada düşük enerji YANLIŞLIKLA tutuş sanılıyordu; burada gerçek bir
performans duruşu, YAPISAL OLARAK "tutuş" tanımına asla girmeyecek.

## 2. Öneri — "presence" ayrı bir kavram, "hold"un gevşetilmişi DEĞİL

**Presence ≠ hold - epsilon.** Eşiği gevşetmek (M-F-95'in kendi uyarısı:
"sözlüğe müzik lehçesi eklemek... ölçmeden yapılmamalı" ile aynı sınıf
hata) yanlış çözüm olur — çünkü drift'in kaynağı GÜRÜLTÜ değil GERÇEK,
İSTENEN hareket (nefes almak duruşu bozmaz, doğal salınım kötü postür
değildir). Öneri: iki AYRI landmark kapsamı ile iki AYRI soru sorulsun.

### 2a. Kapsam daraltma — M-O-43'ün dersi burada da geçerli

Gitarda `scope=upperBody` (diz/ayak bileği hariç) sahte-red'i kapattı
(M-O-43/45). Şanda bir adım daha ileri gidilebilir: **`scope=trunkOnly`**
(yalnız `trunk_tilt`in kullandığı 4 landmark — omuz×2 + kalça×2). Kollar
zaten burada da coached_only olacaktı (B4 pilotu, M-O-09: "şanda kolun
doğru yeri yok"); onları presence hesabına hiç katmamak hem doğru hem
ucuz.

### 2b. Presence kriteri — üç katman, hold'dan FARKLI ağırlıklarla

1. **Kapsama** (`hold_isolator`'daki AYNI kavram, DEĞİŞMEZ): kişi kadrajda
   VE görünür (M-O-41/43 dersi — görünürlük her zaman kapı, asla gevşetilmez).
2. **Enerji tavanı — YÜKSEK ama YOK DEĞİL:** ölçülen medyan 0,12-0,19/s'in
   ÜSTÜNDE bir taban (öneri: ~0,5/s, `hold_isolator`'ın ORİJİNAL — henüz
   daraltılmamış — enerji tavanına yakın) reddetmeye devam etsin: bu,
   "aktif olarak yürüyor/dans ediyor" gibi GERÇEKTEN sunum-dışı anları
   eler, ama nefes/doğal salınımı ELEMEZ.
3. **Drift tavanı YOK, ONUN YERİNE trunk_tilt'in KENDİ DEĞER ARALIĞI
   ölçülsün:** `_drift`i (ham landmark pozisyon sapması) bir kapı olarak
   KULLANMA — onun yerine pencere boyunca `trunk_tilt` DEĞERİNİN (açı,
   zaten hesaplanan metrik) ne kadar bir bantta kaldığını ölç ve BUNU
   raporla (kapı değil, DAYANAK). Bir şarkıcı sallanırken bile
   `trunk_tilt` göreli olarak dar bir bantta kalabilir (salınım simetrik,
   açı ortalamaya yakın) — ya da kalmayabilir; bu ÖLÇÜLMEDEN bilinmez.

### 2c. Aday API (hold_isolator'ın AYNI imzası, `scope` zaten var)

```python
find_presence_windows(
    frames, fps=..., window_s=5.0, scope="trunkOnly",
    max_energy_per_s=0.5,       # hold'un ORİJİNAL tavanı — öneri, ölçülmedi
    min_coverage=0.8,           # DEĞİŞMEZ
    # max_drift PARAMETRESİ YOK — presence'ta drift kapı değil, dayanak
    report_trunk_tilt_band=True,  # yeni: pencere boyunca trunk_tilt aralığı
)
```

Bu, `hold_isolator`ı DEĞİŞTİRMEZ — yanına `scope` parametresini paylaşan
KARDEŞ bir fonksiyon (aynı dosyada veya `presence_isolator.py` olarak
ayrı, coordinator kararı).

## 3. Bilinmeyen — ölçülmesi gereken, varsayılmayan

- Yukarıdaki `max_energy_per_s: 0,5` VE `window_s: 5.0` öneriler,
  hold_isolator'ın kendi (henüz gerçek-veri kalibre edilmemiş) sentetik
  tabanından ödünç alındı — GERÇEK şan verisiyle kalibre edilmedi (bu
  spec'in kapsamı DEĞİL, presence_isolator ilk koşumunun işi, M-O-43'ün
  drift-kalibrasyonu emsali).
- Trunk_tilt bant-genişliğinin gerçekten dar mı geniş mi çıkacağı
  BİLİNMİYOR — 4 kaynakla önceden tahmin ölçüm-öncesi disiplini (O-007)
  ihlali olurdu.
- "Sunum-dışı an" (öğretmen konuşuyor, farklı egzersize geçiyor) ile
  "gerçek performans duruşu" arasındaki ayrım kadraj/enerjiyle TAM
  yakalanamayabilir — transkript aday-zamanı (hold_isolator'daki AYNI
  `candidate_times_s` kancası) burada daha KRİTİK bir rol oynayabilir,
  çünkü presence'ın kendisi zayıf bir filtre.

## 4. Bekleyen

`presence_isolator` (veya `hold_isolator`'a `scope=trunkOnly` + drift-kapısız
mod eklenmesi) core işi — koordinatör kuyruğunda. Merge olduğunda: `voice`
için tüm uygun kaynaklar (4) bu yeni izolatörle taranacak, `trunk_tilt`
bant-genişliği ölçülecek, kanonik CLI'a (v0.8.4+, `--scope trunkOnly` eşdeğeri)
verilecek — gitar zincirinin (M-O-47/48) AYNI deseni.
