"""Exact host succession and retained prelaunch refusal; no physics execution."""
import json
from pathlib import Path
import subprocess
import sys
import unittest
import uuid

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'sdk/conformance'))
import qsdk_r10f_l14_runtime_binding as runtime


class HostRuntimeSuccessor(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.root = ROOT.parent / 'SporeSpore_Evidence' / ('development-host-successor-test-' + uuid.uuid4().hex)
        cls.root.mkdir()
        print('HOST_SUCCESSOR_TEST_ROOT', cls.root, flush=True)

    def run_ps(self, label, script):
        run = subprocess.run([runtime.IMAGES['powershell_host']['path'], '-NoProfile', '-NonInteractive', '-Command', script],
                             cwd=ROOT, capture_output=True, timeout=60, creationflags=subprocess.CREATE_NO_WINDOW)
        (self.root / (label + '.stdout.log')).write_bytes(run.stdout)
        (self.root / (label + '.stderr.log')).write_bytes(run.stderr)
        return run

    def test_historical_record_is_exact_but_cannot_supply_current_qualification(self):
        old = runtime.historical_expected_binding()
        current = runtime.expected_binding()
        runtime.validate_binding(old)
        runtime.validate_binding(current)
        self.assertNotEqual(old['schema_version'], current['schema_version'])
        self.assertEqual({'powershell_host'}, {role for role in old['images'] if old['images'][role] != current['images'][role]})
        with self.assertRaisesRegex(ValueError, 'L14_RUNTIME_QUALIFICATION_DRIFT'):
            runtime.verify_qualified_binding(old, Path(runtime.IMAGES['godot_console']['path']))
        # A mixed generation cannot pass as either complete exact contract.
        mixed = runtime.historical_expected_binding()
        mixed['images']['powershell_host'] = current['images']['powershell_host']
        with self.assertRaisesRegex(ValueError, 'L14_RUNTIME_BINDING_NOT_EXACT'):
            runtime.validate_binding(mixed)

    def test_real_powershell_reopens_successor_and_refuses_stale_qualification(self):
        run = self.run_ps('actual_binding', r'''
$ErrorActionPreference = 'Stop'
. ./sdk/qsdk_r10f_l14_runtime_binding.ps1
$old = Get-QsdkR10fL14HistoricalRuntimeBinding
Assert-QsdkR10fL14RuntimeBinding $old
$selected = Get-QsdkR10fL14ExpectedRuntimeBinding
$actual = Get-QsdkR10fL14RuntimeBinding -Godot $selected.images.godot_console.path -ExpectedBinding $selected
$refused = $false
try { $null = Get-QsdkR10fL14RuntimeBinding -Godot $selected.images.godot_console.path -ExpectedBinding $old }
catch { if ($_.Exception.Message -cne 'L14_RUNTIME_QUALIFICATION_DRIFT') { throw }; $refused = $true }
if (-not $refused) { throw 'STALE_HOST_QUALIFICATION_ACCEPTED' }
$actual | ConvertTo-Json -Depth 100 -Compress
''')
        self.assertEqual(0, run.returncode, run.stderr.decode())
        self.assertEqual(b'', run.stderr)
        self.assertEqual(runtime.expected_binding(), json.loads(run.stdout))

    def test_actual_supervisor_tail_retains_runtime_refusal_before_any_stage(self):
        # Execute the exact production tail after loading its real definitions.
        # Mock only the failure and lock in this nested, zero-world test. An
        # unexpected attempt to enter a safety stage throws a different error.
        run = self.run_ps('early_refusal', r'''
$ErrorActionPreference = 'Stop'
. ./sdk/run_development_recovery_smoke.ps1 -Library
function Enter-SporeSporeLocomotionOperationLock { return @{acquired=$true;abandoned_owner_recovered=$false;test_only=$true} }
function Exit-SporeSporeLocomotionOperationLock { }
function Get-QsdkR10fL14RuntimeBinding { throw 'SYNTHETIC_HOST_IMAGE_REFUSAL' }
function Invoke-DevelopmentStage { throw 'REFUSAL_TEST_ENTERED_SAFETY_STAGE' }
$text = [IO.File]::ReadAllText((Join-Path $repoRoot 'sdk/run_development_recovery_smoke.ps1'))
$marker = "$" + "script:PhysicalMarker = 'DEVELOPMENT_RECOVERY_SMOKE_COMPLETE '"
$offset = $text.IndexOf($marker, [StringComparison]::Ordinal)
if ($offset -lt 0) { throw 'SUPERVISOR_TAIL_NOT_FOUND' }
& ([scriptblock]::Create($text.Substring($offset)))
''')
        self.assertEqual(1, run.returncode, run.stderr.decode())
        prefix = 'DEVELOPMENT_RECOVERY_SMOKE_COMPLETE '
        lines = [line[len(prefix):] for line in run.stdout.decode().splitlines() if line.startswith(prefix)]
        self.assertEqual(1, len(lines), (run.stdout, run.stderr))
        result = json.loads(lines[0])
        self.assertEqual('SYNTHETIC_HOST_IMAGE_REFUSAL', result['failure_code'])
        self.assertFalse(result['physical_attempt_started'])
        self.assertEqual([], result['safety_stages'])
        self.assertEqual([], result['children'])
        retained = Path(result['output_root'])
        self.assertTrue(retained.is_relative_to(ROOT.parent / 'SporeSpore_Evidence'))
        self.assertFalse((retained / 'children').exists())
        self.assertEqual(result, json.loads((retained / 'supervisor_result.json').read_bytes()))
        self.assertTrue((retained / 'published_marker.txt').is_file())


if __name__ == '__main__':
    unittest.main()
