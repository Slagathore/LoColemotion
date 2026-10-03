"""Reconstruct the observed source bytes from durable Git blobs, without Godot."""
import hashlib
import json
from pathlib import Path
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[1]


class SourceRetention(unittest.TestCase):
    def test_original_executed_source_bytes_survive_git_newline_normalization(self):
        witness = json.loads((ROOT / 'sdk/development_exact_context_cache_source_retention_v1.json').read_text())
        checkpoint = json.loads((ROOT / witness['checkpoint_path']).read_text())
        expected = {item['path']: item for item in checkpoint['additional_source_files']}
        self.assertEqual(set(expected), {item['path'] for item in witness['source_retention']})
        for item in witness['source_retention']:
            with self.subTest(path=item['path']):
                object_name = witness['source_commit'] + ':' + item['path']
                blob = subprocess.check_output(['git', 'rev-parse', object_name], cwd=ROOT).decode().strip()
                self.assertEqual(item['git_blob'], blob)
                raw = subprocess.check_output(['git', 'cat-file', 'blob', blob], cwd=ROOT)
                self.assertNotIn(b'\r', raw)
                self.assertTrue(raw.endswith(b'\n'))
                self.assertFalse(raw.startswith(b'\xef\xbb\xbf'))
                raw.decode('utf-8')
                self.assertIn(item['executed_byte_encoding'], ('utf8_lf', 'utf8_crlf'))
                if item['executed_byte_encoding'] == 'utf8_crlf':
                    raw = raw.replace(b'\n', b'\r\n')
                self.assertEqual(expected[item['path']]['byte_length'], len(raw))
                self.assertEqual(expected[item['path']]['raw_sha256'], 'sha256:' + hashlib.sha256(raw).hexdigest())
                self.assertEqual(expected[item['path']]['byte_length'], item['byte_length'])
                self.assertEqual(expected[item['path']]['raw_sha256'], item['raw_sha256'])


if __name__ == '__main__':
    unittest.main()
