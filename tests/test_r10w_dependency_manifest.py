"""Transitive-input and runtime drift controls; no engine or world is opened."""
import copy
from pathlib import Path
import sys
import unittest
from unittest import mock

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'sdk/conformance'))
import r10w_dependency_manifest as dependencies


def row(path, digest='1', size=10):
    return dict(path=path, byte_length=size, raw_sha256='sha256:'+digest*64)


class DependencyManifest(unittest.TestCase):
    def test_complete_source_families_and_only_named_output_exclusions(self):
        included = ['sdk/conformance/r10w_campaign_authority.py', 'sdk/conformance/nested/future_reader.py',
                    'sdk/core/src/recovery.rs', 'sdk/core/Cargo.lock', 'sdk/recovery/unknown_input.json',
                    'sdk/recovery/r10j_held_out_physical_closure_v1.json',
                    dependencies.authority.PREREGISTRATION_PATH, dependencies.authority.READER_CONTRACT_PATH,
                    dependencies.authority.READER_COMPONENT_PATH, dependencies.authority.DESIGN_PATH,
                    'scripts/physics/adapter.gd', 'tests/fixtures/trace.json', 'addons/native/native.cpp',
                    'addons/native/runtime.gdextension', 'project.godot', '.gitattributes']
        excluded = [*dependencies.OUTPUTS, 'sdk/release/quadruped_support_matrix.json',
                    'docs/README.md', 'sdk/target/build.dll', 'unrelated/file.py']
        for path in included:
            with self.subTest(path=path): self.assertTrue(dependencies.included(path))
        for path in excluded:
            with self.subTest(path=path): self.assertFalse(dependencies.included(path))

    def test_source_runtime_size_added_and_removed_dependency_change_the_key(self):
        sources, runtime = [row('sdk/reader.py')], [row('C:/engine.exe'), row('C:/adapter.dll')]
        original = dependencies.keyed_manifest(sources, runtime)
        changes = [([row('sdk/reader.py', '2')], runtime),
                   ([row('sdk/reader.py', size=11)], runtime),
                   (sources+[row('sdk/nested/reader.py')], runtime),
                   ([], runtime), (sources, [row('C:/engine.exe'), row('C:/adapter.dll', '3')]),
                   (sources, runtime[:-1])]
        for changed_sources, changed_runtime in changes:
            changed = dependencies.keyed_manifest(changed_sources, changed_runtime)
            self.assertNotEqual(original['production_route_key'], changed['production_route_key'])
            with mock.patch.object(dependencies, 'snapshot', return_value=changed), self.assertRaises(ValueError):
                dependencies.validate(original)
        with mock.patch.object(dependencies, 'snapshot', return_value=original):
            self.assertEqual(original['production_route_key'], dependencies.validate(copy.deepcopy(original)))

    def test_order_is_canonical_but_duplicate_paths_and_omitted_inclusion_rules_refuse(self):
        sources = [row('sdk/b.py'), row('sdk/a.py')]
        runtime = [row('C:/z.dll'), row('C:/a.exe')]
        original = dependencies.keyed_manifest(sources, runtime)
        self.assertEqual(original, dependencies.keyed_manifest(sources[::-1], runtime[::-1]))
        for changed_sources, changed_runtime in ((sources+sources[:1], runtime), (sources, runtime+runtime[:1])):
            with self.assertRaises(ValueError): dependencies.keyed_manifest(changed_sources, changed_runtime)
        changed = copy.deepcopy(original)
        changed['inclusion']['suffixes'].remove('.json')
        with mock.patch.object(dependencies, 'snapshot', return_value=original), self.assertRaises(ValueError):
            dependencies.validate(changed)

    def test_actual_source_inventory_contains_all_new_authority_and_reader_inputs(self):
        paths = dependencies.source_paths()
        self.assertEqual(sorted(set(paths)), paths)
        for path in ('sdk/conformance/r10w_campaign_authority.py', 'sdk/conformance/r10w_dependency_manifest.py',
                     'tests/test_r10w_campaign_authority.py', 'tests/test_r10w_dependency_manifest.py',
                     dependencies.authority.READER_CONTRACT_PATH, dependencies.authority.READER_COMPONENT_PATH,
                     dependencies.authority.DESIGN_PATH, dependencies.RUNTIME_BINDING_PATH):
            self.assertIn(path, paths)
        self.assertFalse(set(paths).intersection(dependencies.OUTPUTS))


    def test_git_checkout_configuration_changes_the_complete_key(self):
        sources, runtime = [row('.gitattributes')], [row('C:/git.exe')]
        original = dependencies.keyed_manifest(sources,runtime,{'core.autocrlf':'true','core.eol':None})
        changed = dependencies.keyed_manifest(sources,runtime,{'core.autocrlf':'false','core.eol':None})
        self.assertNotEqual(original['production_route_key'],changed['production_route_key'])
        with mock.patch.object(dependencies,'snapshot',return_value=changed),self.assertRaises(ValueError):
            dependencies.validate(original)


if __name__ == '__main__':
    unittest.main()
