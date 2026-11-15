"""l10n vaat taraması (kural A2) öz-testi: onaysız eşleşme KIRMIZI, onaylı YEŞİL."""
import unittest

import validate_surface_honesty as gate

# Gerçek katalog biçimi: {dil: {hash: metin}}. de "bald", es "pronto" gibi
# kelimeler dil desenlerinin eşleştirdiği ham vaat sözcükleridir.
CATALOGS = {
    "en": {"k1": "Coming soon"},
    "tr": {"k1": "Yakında"},
    "de": {"k1": "Bald verfügbar", "k2": "Gitarre stimmen"},
    "es-419": {"k1": "Próximamente", "k2": "Afina la guitarra"},
}
OK = {"etiket": "kisit", "gerekce": "test"}


class L10nPromiseGuard(unittest.TestCase):
    def test_en_tr_kapsam_disi(self):
        hits = gate.l10n_promise_hits({"en": {"a": "coming soon"}, "tr": {"a": "yakında"}})
        self.assertEqual(hits, {})

    def test_onaysiz_eslesme_kirmizi(self):
        v = gate.l10n_promise_violations(CATALOGS, {})
        self.assertEqual(len(v), 1)
        self.assertIn("k1", v[0])
        self.assertIn("onaylı listede yok", v[0])

    def test_onayli_yesil(self):
        self.assertEqual(gate.l10n_promise_violations(CATALOGS, {"k1": OK}), [])

    def test_eslesmeyen_anahtar_onaysiz_sorun_degil(self):
        self.assertEqual(gate.l10n_promise_hits(CATALOGS).keys(), {"k1"})

    def test_olu_hash_kirmizi(self):
        v = gate.l10n_promise_violations(CATALOGS, {"k1": OK, "k2": OK})
        self.assertEqual(len(v), 1)
        self.assertIn("ölü hash", v[0])

    def test_gecersiz_etiket_veya_bos_gerekce_kirmizi(self):
        for entry in ({"etiket": "vaat", "gerekce": "x"}, {"etiket": "ders", "gerekce": ""}):
            v = gate.l10n_promise_violations(CATALOGS, {"k1": entry})
            self.assertEqual(len(v), 1)

    def test_degisen_metin_yeni_vaat_ise_hash_degisir_onay_gecmez(self):
        # Kaynak metin değişince hash değişir; eski onay yeni hash'i kapsamaz.
        moved = {"de": {"k9": "Bald verfügbar"}}
        v = gate.l10n_promise_violations(moved, {"k1": OK})
        self.assertEqual(len(v), 2)  # k9 onaysız + k1 ölü

    def test_gercek_depo_yesil(self):
        catalogs = gate.load_l10n_catalogs()
        self.assertEqual(len(catalogs), 14)
        self.assertEqual(
            gate.l10n_promise_violations(catalogs, gate.L10N_PROMISE_APPROVED), [])


if __name__ == "__main__":
    unittest.main()
