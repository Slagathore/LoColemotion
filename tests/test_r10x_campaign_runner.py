"""Exercise the actual PowerShell planner and finite conjunction without worlds."""
import copy
from pathlib import Path
import subprocess
import sys
import unittest
import uuid
import json

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'sdk/conformance'))
import r10x_campaign_authority as authority
import r10x_campaign_audit as audit
import r10x_campaign_profile as entry
import development_passive_entry_profile as source


class CampaignRunner(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        command = r'''
. ./sdk/run_r10x_finite_recovery.ps1 -Library
$result = @{modes=@{};refusals=@{}}
foreach ($m in @('development_ghost','held_out_finite_decision')) {
    $cells=@(Get-R10XCells $m)
    $pairs=@(New-R10XPairPlan $cells ('a'*32))
    $declarations=@($pairs | ForEach-Object {
        $ctx=@{schema_version='sporespore_r10x_campaign_child_context_v1';mode=$m;seed=$_.seed;source_commit=('0'*40);campaign_attempt_id=('a'*32);candidate_profile=$candidateSelection.candidate_profile}
        New-R10XDeclaration $_ @{head=('0'*40);dirty=$false;status=@();changed_file_bindings=@()} @{} @{} $ctx @()
    })
    $result.modes[$m]=@{cells=$cells;pairs=$pairs;declarations=$declarations}
}
$complete=@(Get-R10XCells 'held_out_finite_decision')
foreach ($bad in @('missing','repeat','reverse')) {
    $cells=switch ($bad) {'missing' {@($complete[0..4])} 'repeat' {@($complete[0])*6} 'reverse' {@($complete[5..0])}}
    try { $null=New-R10XPairPlan $cells ('a'*32); $result.refusals[$bad]=$false }
    catch { $result.refusals[$bad]=$true }
}
$result.candidate=$candidateSelection.candidate_profile
ConvertTo-Json -InputObject $result -Depth 100 -Compress
'''
        cls.root=authority.EVIDENCE/('r10x-planner-controls-'+uuid.uuid4().hex);cls.root.mkdir()
        before=source._source_snapshot()
        (cls.root/'source_before.json').write_text(json.dumps(before),encoding='utf-8')
        run = subprocess.run(['C:/Program Files/PowerShell/7/pwsh.exe', '-NoProfile', '-Command', command], cwd=ROOT, capture_output=True,
                             timeout=60, creationflags=subprocess.CREATE_NO_WINDOW)
        (cls.root/'stdout.txt').write_bytes(run.stdout);(cls.root/'stderr.txt').write_bytes(run.stderr)
        after=source._source_snapshot();(cls.root/'source_after.json').write_text(json.dumps(after),encoding='utf-8')
        (cls.root/'execution.json').write_text(json.dumps(dict(returncode=run.returncode,source_unchanged=before==after,world_build_count=0,solver_step_count=0,physical_execution_authorized=False)),encoding='utf-8')
        if before!=after:raise AssertionError('R10X_PLANNER_SOURCE_DRIFT')
        print('R10X_PLANNER_ROOT',cls.root,flush=True)
        if run.returncode:
            raise AssertionError(run.stdout.decode(errors='replace')+run.stderr.decode(errors='replace'))
        cls.result = authority.parse(run.stdout)

    def test_real_planner_preserves_order_and_fresh_child_population(self):
        seen = set()
        for mode, value in self.result['modes'].items():
            self.assertEqual(authority.population(mode), value['cells'])
            children = [c for p in value['pairs'] for c in p['children']]
            self.assertEqual([c['cell_id'] for c in value['cells']], [c['cell_id'] for c in children])
            for child in children:
                self.assertNotIn(child['child_attempt_id'], seen)
                seen.add(child['child_attempt_id'])
                self.assertEqual('a'*32, child['campaign_attempt_id'])
            self.assertEqual(1 if mode == 'development_ghost' else 3, len(value['pairs']))
        self.assertEqual(8, len(seen))

    def test_real_declarations_use_production_candidate_and_unchanged_limits(self):
        for mode, value in self.result['modes'].items():
            for declaration in value['declarations']:
                self.assertEqual(self.result['candidate'], declaration['candidate_profile'])
                limits = entry.validate_declaration(declaration)
                self.assertEqual(3752, limits['maximum_steps_per_child'])
                self.assertEqual(mode, declaration['r10x_campaign']['mode'])
                self.assertFalse(declaration['official_qualification'])
                self.assertFalse(declaration['physical_acceptance_authority'])
                self.assertFalse(declaration['release_authority'])

    def test_actual_planner_refuses_partial_duplicate_and_reordered_population(self):
        self.assertEqual({'missing': True, 'repeat': True, 'reverse': True}, self.result['refusals'])

    def test_one_failed_cell_defeats_conjunction_and_missing_cell_is_invalid(self):
        cells = [dict(cell_id=c['cell_id'], execution_valid=True, finite_task_predicates_passed=True)
                 for c in authority.population('held_out_finite_decision')]
        self.assertEqual('positive', audit.decide(cells, 'held_out_finite_decision')['outcome'])
        for i in range(6):
            changed = copy.deepcopy(cells); changed[i]['finite_task_predicates_passed'] = False
            self.assertEqual('negative', audit.decide(changed, 'held_out_finite_decision')['outcome'])
            changed[i]['execution_valid'] = False
            self.assertEqual('invalid', audit.decide(changed, 'held_out_finite_decision')['outcome'])
        for changed in (cells[:-1], cells[::-1], cells[:1]*6):
            with self.assertRaises(ValueError): audit.decide(changed, 'held_out_finite_decision')


if __name__ == '__main__':
    unittest.main()
