"""Exercise the real shared launcher admission before any runtime launch."""
import json
from pathlib import Path
import subprocess
import sys
import unittest
import uuid
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'sdk/conformance'))
import r10w_campaign_authority as authority
import development_passive_entry_profile as source


class CompactDispatch(unittest.TestCase):
    def test_real_launcher_rejects_crossed_and_ambiguous_compact_routes(self):
        root=authority.EVIDENCE/('r10w-compact-dispatch-'+uuid.uuid4().hex);root.mkdir()
        before=source._source_snapshot()
        command=r'''
. ./sdk/run_r10w_finite_recovery.ps1 -Library
# Stop at the exact runtime boundary: no Godot process can be constructed.
function Get-QsdkR10fL14RuntimeBinding { throw 'TEST_ONLY_RUNTIME_BOUNDARY' }
$cases=@()
foreach ($worker in @('r10w_campaign_worker_v1','r10v_recovery_worker_v1','wrong_worker')) {
    foreach ($choice in @('w','v','both')) {
        $script:WorkerResource='res://sdk/adapters/godot/gdscript/'+$worker+'.gd'
        $script:RepairId='QSDK-R10F-L15'
        try {
            Invoke-L9ChildProcess -Descriptor @{} -Binding @{l14_exact_runtime_images=@{}} -GodotPath 'never-opened' -RequireL15LaunchRelationship -RetainR10wCompactEnvelope:($choice -in @('w','both')) -RetainR10vCompactEnvelope:($choice -in @('v','both'))
            throw 'TEST_UNEXPECTED_RETURN'
        } catch { $cases+=@{worker=$worker;choice=$choice;failure=$_.Exception.Message} }
    }
}
ConvertTo-Json -InputObject $cases -Compress
'''
        run=subprocess.run(['C:/Program Files/PowerShell/7/pwsh.exe','-NoLogo','-NoProfile','-Command',command],cwd=authority.ROOT,capture_output=True,timeout=60,creationflags=subprocess.CREATE_NO_WINDOW)
        (root/'stdout.json').write_bytes(run.stdout);(root/'stderr.txt').write_bytes(run.stderr)
        after=source._source_snapshot()
        for name,value in [('source_before',before),('source_after',after),('execution',dict(exit_code=run.returncode,source_unchanged=before==after,world_build_count=0,solver_step_count=0))]:
            (root/(name+'.json')).write_text(json.dumps(value),encoding='utf-8')
        print('R10W_COMPACT_DISPATCH',root,flush=True)
        self.assertEqual(before,after);self.assertEqual(run.returncode,0,run.stderr.decode(errors='replace'))
        values=json.loads(run.stdout);self.assertEqual(len(values),9)
        for row in values:
            expected=('COMPACT_ROUTE_AMBIGUOUS' if row['choice']=='both' else
                'TEST_ONLY_RUNTIME_BOUNDARY' if (row['worker'],row['choice']) in [('r10w_campaign_worker_v1','w'),('r10v_recovery_worker_v1','v')] else
                'R10W_COMPACT_ROUTE_REQUIRED' if row['choice']=='w' else 'R10V_COMPACT_ROUTE_REQUIRED')
            self.assertIn(expected,row['failure'],row)


if __name__=='__main__':unittest.main()
