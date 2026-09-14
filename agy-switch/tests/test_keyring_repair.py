"""Synthetic fixtures only; never read the user's keyring."""
import configparser
import importlib.util
from pathlib import Path
import unittest

from gi.repository import GLib

spec = importlib.util.spec_from_file_location(
    'repair', Path(__file__).resolve().parents[1] / 'keyring-fix/repair_unescaped.py')
repair = importlib.util.module_from_spec(spec)
spec.loader.exec_module(repair)


class RepairTests(unittest.TestCase):
    def fixture(self, secret):
        return (b'[keyring]\ndisplay-name=Test\nctime=0\nmtime=0\n\n'
                b'[1]\nitem-type=0\ndisplay-name=Test\nsecret=' + secret +
                b'\nmtime=12\nctime=10\n\n[1:attribute0]\nname=service\ntype=string\nvalue=test\n')

    def test_preserves_exact_bytes(self):
        for secret in (b'one\ntwo\n', b'  leading\\n literal\\backslash\t', b'', 'हिन्दी'.encode()):
            with self.subTest(secret=secret):
                converted, count = repair.convert(self.fixture(secret))
                self.assertEqual(count, 1)
                k = GLib.KeyFile()
                k.load_from_data(converted.decode(), len(converted), GLib.KeyFileFlags.NONE)
                self.assertEqual(bytes.fromhex(k.get_string('1', 'binary-secret')), secret)
                self.assertEqual(k.get_string('1:attribute0', 'value'), 'test')
                self.assertEqual(repair.convert(converted), (converted, 0))

    def test_rejects_ambiguous_or_damaged_input(self):
        for data in (b'GnomeKeyring\n\r', self.fixture(b'x\nsecret=y'),
                     self.fixture(b'x\n[2]\ny'), self.fixture(b'x\nmtime=1\nctime=2\nfoo=bar'),
                     self.fixture(b'ok').replace(b'mtime=12', b'mtime=bad')):
            with self.subTest():
                with self.assertRaises((ValueError, GLib.Error, configparser.Error)):
                    repair.convert(data)


if __name__ == '__main__':
    unittest.main()
