"""Run production child/replay dispatch with explicit synthetic process stand-ins.

No production host, campaign claim, Godot process or world is created. Original
PowerShell file writes, ordering and failure propagation remain exercised.
"""
import json
from pathlib import Path
import subprocess
import sys
import unittest
import uuid
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'sdk/conformance'))
import r10w_campaign_authority as authority
import development_passive_entry_profile as source


class ExecutionDispatch(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.root=authority.EVIDENCE/('r10w-execution-controls-'+uuid.uuid4().hex);cls.root.mkdir()
        command=r'''
param([string]$OutputRoot)
. ./sdk/run_r10w_finite_recovery.ps1 -Library
$result=@{}
function Assert-R10WSourceAndRuntime { param($Source,$Key)
    $script:calls.Add('source')
    if ($script:scenario -eq 'source_failure') { throw 'SYNTHETIC_SOURCE_FAILURE' }
}
function New-QsdkR10fL15ProductionLaunchContext { return @{} }
function Assert-QsdkR10fL15ChildLaunchRelationship { return $true }
function Write-R10WHostProgress { param($Stage,$State,$Role,$Subject)
    $script:calls.Add($Stage+':'+$State+':'+$Role)
}
function Invoke-L9ChildProcess { param($Descriptor,$Binding,$GodotPath,[switch]$RequireL15LaunchRelationship,[switch]$RetainR10wCompactEnvelope)
    if (-not $RequireL15LaunchRelationship -or -not $RetainR10wCompactEnvelope) { throw 'MISSING_REAL_DISPATCH_FLAGS' }
    $script:calls.Add('launch:'+$Descriptor.role)
    if ($script:scenario -eq 'child_failure') { throw 'SYNTHETIC_CHILD_FAILURE' }
    return @{child_attempt_id=$Descriptor.child_attempt_id;exit_code=0;raw_marker_valid=$true;engine_health_passed=$true;
        retained_envelope_binding=@{synthetic=$true};r10f_l15_launch_relationship=@{synthetic=$true}}
}
function Invoke-R10WHostPython { param($Arguments,$Stage,$Role,$OutputBase,$TimeoutSeconds)
    $script:calls.Add($Stage+':'+$Role+':'+$TimeoutSeconds)
    if ($script:scenario -eq 'replay_timeout' -and $Stage -eq 'replay') { throw 'SYNTHETIC_REPLAY_TIMEOUT' }
    if ($script:scenario -eq 'pair_failure' -and $Stage -eq 'pair_audit') { return @{exit_code=1;output=@('{"ok":false}')} }
    # A valid finite-task negative must not suppress the next child or replay.
    return @{exit_code=0;output=@('{"ok":true,"finite_task_predicates_passed":false}')}
}
foreach ($case in @('negative','child_failure','source_failure','replay_timeout','pair_failure')) {
    $script:scenario=$case; $script:calls=[Collections.Generic.List[string]]::new()
    $r10wCellFailures=[Collections.Generic.List[object]]::new();$script:r10wPhysicalStarted=$false
    $pair=@{attempt_id=[Guid]::NewGuid().ToString('N');seed=@{seed=41445};root=(Join-Path $OutputRoot $case);children=@()}
    $null=New-Item -ItemType Directory -Path $pair.root
    foreach ($role in @('matched_no_kick_continuation','kick_passive_recovery_resume')) {
        $pair.children+=@{cell_id=('41445:'+$role);role=$role;child_attempt_id=[Guid]::NewGuid().ToString('N');parent_attempt_id=$pair.attempt_id;
            evidence_path=(Join-Path $pair.root ('children/'+$role));termination_nonce=[Guid]::NewGuid().ToString('N')}
    }
    $failure=''
    try {
        Invoke-R10WPairChildren $pair @{head=('0'*40)} 'synthetic-key' @{} @{authority_sha256='synthetic'} | Out-Null
        Invoke-R10WPairPostprocess $pair | Out-Null
    } catch { $failure=$_.Exception.Message }
    $result[$case]=@{calls=$script:calls.ToArray();failure=$failure;physical_attempt_dispatched=$script:r10wPhysicalStarted;
        cell_failures=$r10wCellFailures.ToArray();pair=$pair;synthetic_zero_world_fixture=$true}
}
ConvertTo-Json -InputObject $result -Depth 100 -Compress
'''
        script=cls.root/'dispatch.ps1';script.write_text(command,encoding='utf-8')
        before=source._source_snapshot()
        run=subprocess.run(['C:/Program Files/PowerShell/7/pwsh.exe','-NoLogo','-NoProfile','-File',str(script),'-OutputRoot',str(cls.root)],cwd=authority.ROOT,capture_output=True,timeout=60,creationflags=subprocess.CREATE_NO_WINDOW)
        (cls.root/'stdout.json').write_bytes(run.stdout);(cls.root/'stderr.txt').write_bytes(run.stderr)
        after=source._source_snapshot()
        for name,value in [('source_before',before),('source_after',after),('execution',dict(exit_code=run.returncode,source_unchanged=before==after,world_build_count=0,solver_step_count=0,physical_execution_authorized=False))]:
            (cls.root/(name+'.json')).write_text(json.dumps(value),encoding='utf-8')
        print('R10W_EXECUTION_CONTROLS',cls.root,flush=True)
        if before!=after or run.returncode:raise AssertionError(run.stderr.decode(errors='replace'))
        cls.values=json.loads(run.stdout)

    def test_negative_dispatches_both_fresh_roles_then_both_replays_and_audit(self):
        value=self.values['negative'];self.assertEqual(value['failure'],'');self.assertEqual(value['cell_failures'],[])
        children=value['pair']['children'];self.assertNotEqual(children[0]['child_attempt_id'],children[1]['child_attempt_id'])
        expected=[]
        for c in children:expected+=['source','child:start:'+c['cell_id'],'launch:'+c['role'],'child:end:'+c['cell_id']]
        expected += ['replay:'+c['cell_id']+':960' for c in children]+['pair_audit:41445:1800']
        self.assertEqual(value['calls'],expected)

    def test_child_infrastructure_failure_stops_without_second_launch(self):
        value=self.values['child_failure'];self.assertIn('SYNTHETIC_CHILD_FAILURE',value['failure'])
        self.assertEqual(sum(c.startswith('launch:') for c in value['calls']),1)
        self.assertEqual(len(value['cell_failures']),1)
        a,b=value['pair']['children']
        self.assertTrue((Path(a['evidence_path'])/'campaign_launch_failure.json').is_file())
        self.assertFalse(Path(b['evidence_path']).exists())

    def test_source_failure_leaves_every_child_unopened(self):
        value=self.values['source_failure'];self.assertEqual(value['calls'],['source'])
        self.assertFalse(value['physical_attempt_dispatched'])
        self.assertTrue(all(not Path(c['evidence_path']).exists() for c in value['pair']['children']))

    def test_replay_timeout_propagates_without_retry(self):
        value=self.values['replay_timeout'];self.assertIn('SYNTHETIC_REPLAY_TIMEOUT',value['failure'])
        self.assertEqual(sum(c.startswith('replay:') for c in value['calls']),1)
        self.assertFalse(any(c.startswith('pair_audit:') for c in value['calls']))

    def test_original_negative_publications_are_retained(self):
        value=self.values['negative']
        for child in value['pair']['children']:
            original=json.loads((Path(child['evidence_path'])/'passive_entry_replay_result.json').read_bytes())
            self.assertFalse(original['finite_task_predicates_passed'])
        original=json.loads((Path(value['pair']['root'])/'independent_audit.stdout.json').read_bytes())
        self.assertFalse(original['finite_task_predicates_passed'])

    def test_failed_pair_audit_is_retained_as_failure(self):
        value=self.values['pair_failure'];self.assertEqual(len(value['cell_failures']),1)
        self.assertEqual(value['cell_failures'][0]['failure'],'R10W_PAIR_AUDIT_FAILED')
        original=json.loads((Path(value['pair']['root'])/'independent_audit.stdout.json').read_bytes())
        self.assertFalse(original['ok'])


if __name__=='__main__':unittest.main()
