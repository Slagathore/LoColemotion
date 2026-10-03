"""Build-mode selection is pure configuration, never an experiment launcher."""
import sys
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'sdk/conformance'))
import development_recovery_candidate_build as build


class BuildConfiguration(unittest.TestCase):
    def test_default_keeps_original_debug_command_and_path(self):
        args, image = build.build_configuration('fixture-v1')
        self.assertEqual(['--locked', '--manifest-path', 'sdk/Cargo.toml', '--target-dir',
                          'sdk/target/development-candidate-fixture-v1'], args)
        self.assertEqual(ROOT / 'sdk/target/development-candidate-fixture-v1/debug/sporespore_godot_adapter.dll', image)

    def test_explicit_optimized_profile_is_bound_to_separate_output(self):
        args, image = build.build_configuration('fixture-v1', 'release')
        self.assertEqual('--release', args[-1])
        self.assertEqual(ROOT / 'sdk/target/development-candidate-fixture-v1/release/sporespore_godot_adapter.dll', image)
        # The real CLI defaults to the fast mode; low-level historical callers
        # retain their original default and explicit debug is still possible.
        required = ['--candidate-id', 'fixture-v1', '--controller-id', 'fixture',
                    '--fixture-test', 'fixture', '--question', 'fixture']
        parsed = build.argument_parser().parse_args(required)
        self.assertEqual('release', parsed.build_profile)
        command, selected_image = build.build_configuration(parsed.candidate_id, parsed.build_profile)
        self.assertIn('--release', command)
        self.assertEqual(image, selected_image)
        self.assertEqual('debug', build.argument_parser().parse_args(required + ['--build-profile', 'debug']).build_profile)

    def test_unknown_profiles_and_escaping_identities_refuse(self):
        for identity, profile in [('fixture-v1', 'unknown'), ('../escape', 'release'), ('', 'debug')]:
            with self.assertRaises(ValueError):
                build.build_configuration(identity, profile)


if __name__ == '__main__':
    unittest.main()
