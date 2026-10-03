"""Contract drift checks plus actual script runtimes; no physics or core build.

The fast gate separately exercises the real owned-process launcher/readers and
compiled collector, with hardcoded historical expectations independent of the
new contract. Rust unit tests exercise the freshly generated core enum.
"""
import copy
import json
from pathlib import Path
import subprocess
import sys
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'sdk/conformance'))
import recovery_interface_contract as contract
import qsdk_r10f_l14_runtime_binding as runtime


class SharedRecoveryInterfaces(unittest.TestCase):
    def test_generated_scripts_match_and_stale_projection_refuses(self):
        contract.verify_generated()
        inventory = json.loads((ROOT / 'sdk/release/quadruped_package_source_inventory_v1.json').read_text())
        # Exercise Git's real source projection, including this owned pre-commit
        # snapshot. This is source inclusion, not candidate/package acceptance.
        selected = subprocess.run(['git', 'ls-files', '--cached', '--others', '--exclude-standard',
                                   '--', *inventory['git_pathspecs']], cwd=ROOT, capture_output=True,
                                  text=True, check=True, timeout=15).stdout.splitlines()
        for path in ('sdk/core/build.rs', 'sdk/core/contracts/recovery_interfaces_v1.json'):
            self.assertIn(path, selected)
        sources = contract.generated_sources(contract.CONTRACT)
        sources[contract.GDSCRIPT_PATH] += '# stale projection\n'
        with self.assertRaisesRegex(ValueError, 'GENERATED_DRIFT'):
            contract.verify_generated(sources)
        changed = copy.deepcopy(contract.CONTRACT)
        changed['process']['maximum_chain_nodes'] += 1
        with self.assertRaisesRegex(ValueError, 'GENERATED_DRIFT'):
            contract.verify_generated(contract.generated_sources(changed))

    def test_invalid_source_mapping_and_duplicate_keys_refuse(self):
        changes = [
            lambda c: c['no_actuation_mapping'].update(recovery_v6='not_a_canonical_owner'),
            lambda c: c['canonical_owners'].append(c['canonical_owners'][0]),
            lambda c: c['process'].update(maximum_chain_nodes=True),
            lambda c: c['process'].update(maximum_chain_nodes=0),
            lambda c: c['process'].update(roles=['duplicate', 'duplicate']),
            lambda c: c['process'].update(self_relationship=c['process']['descendant_relationship']),
            lambda c: c['process'].update(receipt_schema="text'; Write-Output 'injection"),
        ]
        for index, change in enumerate(changes):
            value = copy.deepcopy(contract.CONTRACT)
            change(value)
            with self.subTest(index=index), self.assertRaises(ValueError):
                contract.validate_contract(value)
        with patch.object(Path, 'read_text', return_value='{"schema_version":1,"schema_version":2}'), \
                self.assertRaisesRegex(ValueError, 'DUPLICATE_KEY'):
            contract.load_contract()

    def test_actual_powershell_producer_loads_the_same_process_contract(self):
        command = ". ./sdk/qsdk_r10f_l15_launch_relationship.ps1; Get-SporeRecoveryProcessContractV1 | ConvertTo-Json -Compress"
        result = subprocess.run(['C:/Program Files/PowerShell/7/pwsh.exe', '-NoProfile', '-NonInteractive',
                                 '-Command', command], cwd=ROOT, capture_output=True, timeout=20,
                                creationflags=subprocess.CREATE_NO_WINDOW)
        self.assertEqual(0, result.returncode, result.stderr)
        self.assertEqual(b'', result.stderr)
        self.assertEqual(contract.PROCESS, json.loads(result.stdout))

    def test_actual_godot_producer_projection_matches_source_without_physics(self):
        runtime.bind_runtime(Path(runtime.IMAGES['godot_console']['path']))
        result = subprocess.run([runtime.IMAGES['godot_engine']['path'], '--headless', '--path', str(ROOT),
                                 '--script', 'res://tests/test_development_shared_interfaces.gd'],
                                cwd=ROOT, capture_output=True, timeout=60, creationflags=subprocess.CREATE_NO_WINDOW)
        self.assertEqual(0, result.returncode, result.stderr)
        self.assertNotIn(b'ERROR:', result.stdout + result.stderr)
        prefix = b'RECOVERY_SHARED_INTERFACE_CONSTANTS '
        lines = [line[len(prefix):] for line in result.stdout.splitlines() if line.startswith(prefix)]
        self.assertEqual(1, len(lines), result.stdout)
        expected = dict(canonical_owners=[row['wire_name'] for row in contract.CONTRACT['canonical_owners']],
                        no_actuation_mapping=contract.CONTRACT['no_actuation_mapping'],
                        recovery_controller_id=contract.CONTRACT['recovery_controller_id'],
                        world_count=0, solver_step_count=0, physical_acceptance_authority=False, release_authority=False)
        self.assertEqual(expected, json.loads(lines[0]))
        print(prefix.decode() + lines[0].decode('utf-8'))


if __name__ == '__main__':
    unittest.main()
