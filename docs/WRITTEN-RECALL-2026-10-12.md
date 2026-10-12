# Yazılı hatırlama ve geri bildirim — 12 Ekim 2026

Bu ek, mevcut kaynak derslerini okuma/aktif hatırlama ile çalıştırır. Hareket veya ekipman gerekmez. Öğrenen yazılı cevabı kaynaktan ayrı kurup karşılaştırır. Fiziksel uygunluk, tekniğin doğruluğu, demonstrasyon/lisans ve tam müfredat kabulü verilmez.

| Onaylı alan | Mevcut ders/birim | Yeni okuma | Açık kapsam |
|---|---:|---:|---|
| guitar | 60 | 0 | Existing approved guitar journey is inventoried only. The user-cancelled separate guitar correction is not resumed; waveform/audio, physical teaching and mastery acceptance remain open. |
| piano | 16 | 2 | Keyboard/notation/two-hand study exists; actual pitch, duration, key release, coordination and ergonomic performance feedback require instrument/learner evidence. |
| vocal | 16 | 2 | Contour/rhythm/comfortable-study material exists; actual vocal pitch, range, strain/suitability and vocal technique need qualified instruction and learner evidence. |
| ukulele | 18 | 2 | High-G configuration, chord/tab and eight-bar study exist; actual tuning, ringing/rest distinction, muting, rhythm and technique are not verified by the written record. |
| bass | 18 | 2 | Four-string sounding/written octave, tab and study exist; bass-capable audio, muting, timing and hand technique need instrument/learner evidence. |

Kaynak dosyaları ve bölüm referansları `lib/app/study_review_content.dart` içindeki `sourceRefs` alanındadır. Eski ders metinleri, süre/doz, sensör eşikleri, fiziksel kabul ve ders ilerlemesi değiştirilmez.

`study_review.dart` durumları ayrı tutar: denenmedi → örneği yeniden oku; belirsiz → kesin terimi/geçişi adlandır ve uygun eğitmene soru hazırla; tek fark → yalnız aynı yazılı noktayı düzeltip kaynağı gizleyerek yeniden hatırla; durdum → bitir, hareket/ekipman görevini tekrar etmeyi önerme. Notlar geçicidir; kalıcı sağlık/hesap/ilerleme kaydı yoktur.

`test/study_review_test.dart` TR/EN dar ekran/büyük metin, kaynak cevabının gizlenip açılması, dört farklı geri bildirim ve çıkışta not/durum atılmasını sınar. Gerçek cihaz, fiziksel öğretim, sensör ve mağaza testi değildir.
