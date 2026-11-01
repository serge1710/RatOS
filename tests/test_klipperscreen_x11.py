import importlib.util
from pathlib import Path
import tempfile
import unittest

HELPER = Path(__file__).resolve().parents[1] / 'modules/generic/files/ratos/root/usr/local/lib/ratos/klipperscreen-x11.py'
spec = importlib.util.spec_from_file_location('klipperscreen_x11', HELPER)
ks = importlib.util.module_from_spec(spec)
spec.loader.exec_module(ks)


class DisplayCardTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.drm = self.root / 'sys'
        self.dev = self.root / 'dev'
        self.drm.mkdir()
        self.dev.mkdir()

    def card(self, name, connector=None, status='disconnected'):
        device = self.dev / name
        device.touch()
        if connector:
            entry = self.drm / f'{name}-{connector}'
            entry.mkdir()
            (entry / 'status').write_text(status)
        return device

    def test_cm5_render_card_is_not_used_for_display(self):
        self.card('card0')
        display = self.card('card1', 'HDMI-A-1', 'connected')
        self.assertEqual(ks.select_card(self.drm, self.dev), display)
        self.assertIn(f'Option "kmsdev" "{display}"', ks.xorg_config(display))

    def test_connected_display_wins_over_disconnected_card(self):
        self.card('card0', 'HDMI-A-1')
        display = self.card('card1', 'DSI-1', 'connected')
        self.assertEqual(ks.select_card(self.drm, self.dev), display)

    def test_pi_with_display_on_card0(self):
        display = self.card('card0', 'HDMI-A-1', 'connected')
        self.card('card1')
        self.assertEqual(ks.select_card(self.drm, self.dev), display)

    def test_unplugged_display_still_selects_kms_device(self):
        self.card('card0')
        display = self.card('card1', 'HDMI-A-1')
        self.assertEqual(ks.select_card(self.drm, self.dev), display)

    def test_no_display_device_has_explicit_error(self):
        self.card('card0')
        with self.assertRaisesRegex(RuntimeError, 'No display KMS card'):
            ks.select_card(self.drm, self.dev)


if __name__ == '__main__':
    unittest.main()
