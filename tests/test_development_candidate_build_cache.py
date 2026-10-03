"""Compiler reuse cannot alias or overwrite retained candidate images."""
import copy
from pathlib import Path
import sys
import unittest
import uuid

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'sdk/conformance'))
import development_recovery_candidate_build as build


class BuildCache(unittest.TestCase):
    def test_shared_compile_path_keeps_distinct_candidate_publish_paths(self):
        key = 'a' * 64
        first, compiled1 = build.build_configuration('first-v1', 'release', key)
        second, compiled2 = build.build_configuration('second-v1', 'release', key)
        self.assertEqual(first, second)
        self.assertEqual(compiled1, compiled2)
        self.assertIn('--locked', first)
        self.assertIn('--release', first)
        _, published1 = build.build_configuration('first-v1', 'release')
        _, published2 = build.build_configuration('second-v1', 'release')
        self.assertNotEqual(published1, published2)
        self.assertNotEqual(compiled1, published1)
        for key in ['../escape', '', 'A' * 64, 'a' * 63]:
            with self.assertRaises(ValueError):
                build.build_configuration('first-v1', 'release', key)

    def test_cache_partition_changes_with_build_settings_not_candidate_name(self):
        args = ['release', 'rustc fixture', 'cargo fixture', {'RUSTFLAGS': 'sha256:fixture'}, []]
        original = build.compiler_cache_identity(*args)
        self.assertEqual(original, build.compiler_cache_identity(*copy.deepcopy(args)))
        self.assertFalse(original['qualification_or_test_evidence_reused'])
        for index, value in enumerate(['debug', 'another rustc', 'another cargo', {'RUSTFLAGS': None}, [{'path': '.cargo/config.toml', 'raw_sha256': 'changed'}]]):
            changed = copy.deepcopy(args)
            changed[index] = value
            self.assertNotEqual(original['key'], build.compiler_cache_identity(*changed)['key'])

    def test_copy_is_independent_and_refuses_existing_alias_or_escape(self):
        root = build.entry.EVIDENCE / ('development-build-cache-copy-controls-' + uuid.uuid4().hex)
        root.mkdir()
        print('BUILD_CACHE_COPY_CONTROL_ROOT', root, flush=True)
        source, destination = root / 'mutable_fixture.bin', root / 'retained_fixture.bin'
        source.write_bytes(b'first')
        build.copy_image_once(source, destination)
        source.write_bytes(b'next')
        self.assertEqual(b'first', destination.read_bytes())
        with self.assertRaises(FileExistsError):
            build.copy_image_once(source, destination)
        with self.assertRaises(ValueError):
            build.copy_image_once(source, source)
        with self.assertRaises(ValueError):
            build.copy_image_once(source, ROOT / 'unexpected-cache-copy.bin')
        self.assertEqual(b'first', destination.read_bytes())


if __name__ == '__main__':
    unittest.main()
