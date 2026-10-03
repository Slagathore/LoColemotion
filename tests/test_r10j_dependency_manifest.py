"""Dependency closure coverage and mutation controls without source writes."""
import copy
from pathlib import Path
import sys
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'sdk/conformance'))
import r10j_dependency_manifest as manifest


class DependencyManifest(unittest.TestCase):
    def test_route_inputs_included_outputs_explicitly_separate(self):
        for path in ('project.godot', 'sdk/run_r10j_finite_recovery.ps1', 'sdk/conformance/r10j_campaign_audit.py',
                     'scripts/a.gd', 'tests/a.py', 'addons/a.tscn', 'sdk/core/src/a.rs',
                     'sdk/recovery/r10j_held_out_preregistration_v4.json'):
            self.assertTrue(manifest.included(path), path)
        for path in manifest.OUTPUTS | {'sdk/release/quadruped_support_matrix.json', 'docs/README.md'}:
            self.assertFalse(manifest.included(path), path)

    def test_actual_source_and_runtime_key_is_complete_and_stable(self):
        value = manifest.snapshot()
        self.assertEqual(manifest.source_paths(), [s['path'] for s in value['source_files']])
        self.assertIn('sdk/conformance/r10j_qualification.py', [s['path'] for s in value['source_files']])
        self.assertEqual(value['production_route_key'], manifest.validate(value))
        self.assertGreaterEqual(len(value['runtime_files']), 5)

    def test_omitted_changed_or_added_source_and_runtime_refuse(self):
        original = dict(source_files=[dict(path='sdk/a.py', raw_sha256='a')], runtime_files=[dict(path='engine', raw_sha256='b')])
        for defect in ('omit', 'source', 'runtime', 'add'):
            changed = copy.deepcopy(original)
            if defect == 'omit': changed['source_files'] = []
            elif defect == 'source': changed['source_files'][0]['raw_sha256'] = 'c'
            elif defect == 'runtime': changed['runtime_files'][0]['raw_sha256'] = 'c'
            else: changed['source_files'].append(dict(path='sdk/new.py', raw_sha256='c'))
            with self.subTest(defect=defect), patch.object(manifest, 'snapshot', return_value=original), self.assertRaises(ValueError):
                manifest.validate(changed)


if __name__ == '__main__':
    unittest.main()
