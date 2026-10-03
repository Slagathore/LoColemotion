"""Reconstruct retained build-cache observations without compiling or physics."""
import json
from pathlib import Path
import sys
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'sdk/conformance'))
import development_recovery_build_cache_checkpoint as checkpoint


class CacheCheckpoint(unittest.TestCase):
    def test_exact_retained_builds_copies_fixtures_and_runtime_receipt(self):
        expected = json.loads((ROOT / 'sdk/development/recovery_build_cache_v1.json').read_text())
        actual = checkpoint.observe()
        self.assertEqual(expected, actual)
        self.assertTrue(actual['original_v11_dll_unchanged'])
        self.assertEqual(4, actual['independent_retained_copy_count'])
        self.assertFalse(actual['qualification_evidence_reused'])
        self.assertEqual(0, actual['world_build_count'])


if __name__ == '__main__':
    unittest.main()
