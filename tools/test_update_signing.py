"""Signing regressions: checkout line endings must not change key identity."""
import base64
import contextlib
import io
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
import zipfile

from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import padding, rsa
import release_updates as release


class SigningTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.base = Path(self.temp.name)
        self.root = self.base / 'project'
        (self.root / 'config').mkdir(parents=True)
        self.private = self.base / 'private.pem'
        self.public = self.root / 'config/updates_public.pem'
        self.key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
        self.private.write_bytes(self.key.private_bytes(serialization.Encoding.PEM,
            serialization.PrivateFormat.PKCS8, serialization.NoEncryption()))
        public = self.key.public_key().public_bytes(serialization.Encoding.PEM,
            serialization.PublicFormat.SubjectPublicKeyInfo)
        self.public.write_bytes(public.replace(b'\n', b'\r\n'))
        self.config = self.root / 'config/updates.json'
        self.config.write_text(json.dumps(dict(product_id='ralph-wolf', channel='stable',
            bootstrap_abi=1, key_id='test-only')))
        self.pack = self.base / 'export.zip'
        with zipfile.ZipFile(self.pack, 'w') as archive:
            archive.writestr('assets/example.json', '{}')
            archive.writestr('project.binary', 'must be excluded')

    def run_sign(self, private=None):
        args = ['release_updates', 'sign-pack', '--pack', str(self.pack), '--platform',
            'windows-x86_64', '--version', 'test', '--sequence', '1', '--private-key',
            str(private or self.private), '--output', str(self.base / 'output')]
        with patch.object(release, 'ROOT', self.root), patch.object(release, 'CONFIG', self.config), \
                patch('sys.argv', args), contextlib.redirect_stdout(io.StringIO()):
            release.main()

    def test_crlf_public_key_signs_valid_envelope(self):
        self.run_sign()
        envelope = json.loads((self.base / 'output/stable/windows-x86_64/manifest.json').read_text())
        self.key.public_key().verify(base64.b64decode(envelope['signature_base64']),
            base64.b64decode(envelope['payload_base64']), padding.PKCS1v15(), hashes.SHA256())
        with zipfile.ZipFile(self.base / 'output/releases/00000001-test/windows-x86_64/content.zip') as archive:
            self.assertNotIn('project.binary', archive.namelist())
            self.assertIn('assets/updates/content_release.json', archive.namelist())

    def test_different_private_key_is_rejected_before_writing(self):
        other = rsa.generate_private_key(public_exponent=65537, key_size=2048)
        path = self.base / 'other-private.pem'
        path.write_bytes(other.private_bytes(serialization.Encoding.PEM,
            serialization.PrivateFormat.PKCS8, serialization.NoEncryption()))
        with self.assertRaisesRegex(ValueError, 'no corresponde'):
            self.run_sign(path)
        self.assertFalse((self.base / 'output').exists())

    def test_keygen_reuses_same_public_key_with_crlf(self):
        with patch.object(release, 'ROOT', self.root), contextlib.redirect_stdout(io.StringIO()):
            release.keygen(self.private, self.public)
        self.assertEqual(serialization.load_pem_public_key(self.public.read_bytes()).public_numbers(),
            self.key.public_key().public_numbers())

    def test_private_key_inside_repository_is_rejected(self):
        with patch.object(release, 'ROOT', self.root), self.assertRaisesRegex(ValueError, 'FUERA'):
            release.keygen(self.root / 'private.pem', self.public)


if __name__ == '__main__':
    unittest.main()
