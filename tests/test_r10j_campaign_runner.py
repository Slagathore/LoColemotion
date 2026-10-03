"""Exercise the actual PowerShell planner and finite conjunction without worlds."""
import copy
from pathlib import Path
import subprocess
import sys
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'sdk/conformance'))
import r10j_campaign_authority as authority
import r10j_campaign_audit as audit
import development_passive_entry_profile as entry


class CampaignRunner(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        command = r'''
. ./sdk/run_r10j_finite_recovery.ps1 -Library
$result = @{modes=@{};refusals=@{}}
foreach ($m in @('development_ghost','held_out_finite_decision')) {
    $cells=@(Get-R10JCells $m)
    $pairs=@(New-R10JPairPlan $cells ('a'*32))
    $declarations=@($pairs | ForEach-Object {
        $ctx=@{mode=$m;seed=$_.seed;source_commit=('0'*40);campaign_attempt_id=('a'*32);candidate_profile=$candidateSelection.candidate_profile}
        New-R10JDeclaration $_ @{head=('0'*40);dirty=$false;status=@();changed_file_bindings=@()} @{} @{} $ctx @()
    })
    $result.modes[$m]=@{cells=$cells;pairs=$pairs;declarations=$declarations}
}
$complete=@(Get-R10JCells 'held_out_finite_decision')
foreach ($bad in @('missing','repeat','reverse')) {
    $cells=switch ($bad) {'missing' {@($complete[0..4])} 'repeat' {@($complete[0])*6} 'reverse' {@($complete[5..0])}}
    try { $null=New-R10JPairPlan $cells ('a'*32); $result.refusals[$bad]=$false }
    catch { $result.refusals[$bad]=$true }
}
$result.candidate=$candidateSelection.candidate_profile
$result.stages=$r10jStages
ConvertTo-Json -InputObject $result -Depth 100 -Compress
'''
        run = subprocess.run(['pwsh', '-NoProfile', '-Command', command], cwd=ROOT, capture_output=True,
                             timeout=60, creationflags=subprocess.CREATE_NO_WINDOW)
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
            self.assertEqual(len(value['cells'])//2, len(value['pairs']))
        self.assertEqual(8, len(seen))

    def test_real_declarations_use_production_candidate_and_unchanged_limits(self):
        for mode, value in self.result['modes'].items():
            for declaration in value['declarations']:
                self.assertEqual(self.result['candidate'], declaration['candidate_profile'])
                limits = entry.validate_declaration(declaration)
                self.assertEqual(3512, limits['maximum_steps_per_child'])
                self.assertEqual(mode, declaration['r10j_campaign']['mode'])
                self.assertFalse(declaration['official_qualification'])
                self.assertFalse(declaration['physical_acceptance_authority'])
                self.assertFalse(declaration['release_authority'])
        self.assertEqual(len(self.result['stages']), len({s['id'] for s in self.result['stages']}))

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
