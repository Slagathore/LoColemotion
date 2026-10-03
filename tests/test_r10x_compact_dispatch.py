"""Exercise actual campaign admission and native flag forwarding without physics."""
import json
from pathlib import Path
import subprocess
import sys
import unittest
import uuid
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'sdk/conformance'))
import r10x_campaign_authority as authority
import development_passive_entry_profile as source


class CompactDispatch(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        root = authority.EVIDENCE / ('r10x-compact-dispatch-' + uuid.uuid4().hex)
        root.mkdir()
        command = r'''
param([string]$OutputRoot)
. ./sdk/run_r10x_finite_recovery.ps1 -Library
# Every admission case stops before process construction.
function Get-QsdkR10fL14RuntimeBinding {
    if (-not $script:forwarding) { throw 'TEST_ONLY_RUNTIME_BOUNDARY' }
    return @{}
}
$script:forwarding=$false
$cases=@()
foreach ($worker in @('r10x_campaign_worker_v1','r10w_campaign_worker_v1','r10v_recovery_worker_v1','wrong_worker')) {
    foreach ($choice in @('x','w','v','both','x_without_native','native_without_x','none','x_without_context')) {
        $script:WorkerResource='res://sdk/adapters/godot/gdscript/'+$worker+'.gd'
        $script:RepairId='SYNTHETIC_NO_IMPLICIT_L15'
        try {
            $invoke=@{Descriptor=@{};Binding=@{l14_exact_runtime_images=@{}};GodotPath='never-opened';
                RequireL15LaunchRelationship=($choice -ne 'x_without_context');
                RetainR10xCompactEnvelope=($choice -in @('x','both','x_without_native','x_without_context'));
                R10xNativeProcessObservation=($choice -in @('x','both','native_without_x','x_without_context'));
                RetainR10wCompactEnvelope=($choice -in @('w','both'));RetainR10vCompactEnvelope=($choice -eq 'v')}
            $null=Invoke-L9ChildProcess @invoke
            throw 'TEST_UNEXPECTED_RETURN'
        } catch { $cases+=@{worker=$worker;choice=$choice;failure=$_.Exception.Message} }
    }
}
# The leaf process invocation is a stand-in; actual L9 must forward its option.
$script:forwarding=$true
$script:WorkerResource='res://sdk/adapters/godot/gdscript/r10x_campaign_worker_v1.gd'
function New-QsdkR10fL15ProductionLaunchContext { return @{synthetic_context='exact'} }
function Invoke-SporeSporeGodotReceiptTerminatedProcess {
    param([switch]$R10xNativeProcessObservation,$R10fL15LaunchContext)
    if (-not $R10xNativeProcessObservation -or $R10fL15LaunchContext.synthetic_context -cne 'exact') { throw 'TEST_NATIVE_FORWARDING_MISSING' }
    throw 'TEST_NATIVE_FORWARDING_REACHED'
}
$descriptor=@{evidence_path=$OutputRoot;role='matched_no_kick_continuation';child_attempt_id=('a'*32);termination_nonce=('b'*32)}
$binding=@{l14_exact_runtime_images=@{};authority_sha256=('0'*64);authority=@{source_commit=('1'*40)}}
$forward=''
try { $null=Invoke-L9ChildProcess $descriptor $binding 'never-opened' -RequireL15LaunchRelationship -RetainR10xCompactEnvelope -R10xNativeProcessObservation }
catch { $forward=$_.Exception.Message }
ConvertTo-Json -InputObject @{cases=$cases;forwarding=$forward} -Depth 20 -Compress
'''
        script = root / 'dispatch.ps1'
        script.write_text(command, encoding='utf-8')
        before = source._source_snapshot()
        run = subprocess.run(['C:/Program Files/PowerShell/7/pwsh.exe', '-NoLogo', '-NoProfile',
            '-File', str(script), '-OutputRoot', str(root)], cwd=authority.ROOT,
            capture_output=True, timeout=60, creationflags=subprocess.CREATE_NO_WINDOW)
        (root / 'stdout.json').write_bytes(run.stdout)
        (root / 'stderr.txt').write_bytes(run.stderr)
        after = source._source_snapshot()
        for name, value in [('source_before', before), ('source_after', after),
            ('execution', dict(exit_code=run.returncode, source_unchanged=before == after,
                world_build_count=0, solver_step_count=0))]:
            (root / (name + '.json')).write_text(json.dumps(value), encoding='utf-8')
        print('R10X_COMPACT_DISPATCH', root, flush=True)
        if before != after or run.returncode:
            raise AssertionError(run.stderr.decode(errors='replace'))
        cls.values = json.loads(run.stdout)

    def test_actual_launcher_refuses_crossed_omitted_and_ambiguous_routes(self):
        values = self.values['cases']
        self.assertEqual(len(values), 32)
        for row in values:
            worker, choice = row['worker'], row['choice']
            if choice == 'both':
                expected = 'COMPACT_ROUTE_AMBIGUOUS'
            elif choice in ('x', 'x_without_native', 'native_without_x', 'x_without_context'):
                expected = ('TEST_ONLY_RUNTIME_BOUNDARY' if worker == 'r10x_campaign_worker_v1'
                    and choice == 'x' else 'R10X_NATIVE_COMPACT_ROUTE_REQUIRED')
            elif worker == 'r10x_campaign_worker_v1':
                expected = 'R10X_NATIVE_OBSERVER_REQUIRED'
            elif choice == 'w':
                expected = ('TEST_ONLY_RUNTIME_BOUNDARY' if worker == 'r10w_campaign_worker_v1'
                    else 'R10W_COMPACT_ROUTE_REQUIRED')
            elif choice == 'v':
                expected = ('TEST_ONLY_RUNTIME_BOUNDARY' if worker == 'r10v_recovery_worker_v1'
                    else 'R10V_COMPACT_ROUTE_REQUIRED')
            else:
                expected = 'TEST_ONLY_RUNTIME_BOUNDARY'
            self.assertIn(expected, row['failure'], row)

    def test_actual_launcher_forwards_explicit_native_flag_and_l15_context(self):
        self.assertEqual(self.values['forwarding'], 'TEST_NATIVE_FORWARDING_REACHED')


if __name__ == '__main__':
    unittest.main()
