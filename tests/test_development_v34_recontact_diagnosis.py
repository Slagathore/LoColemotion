"""Retained-data diagnosis, independently counted holds and source corruption refusals."""
import json
from pathlib import Path
import sys
import unittest

ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'sdk/conformance'))
import development_recovery_v34_recontact_diagnosis as diagnosis


class RecontactDiagnosis(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.record=json.loads((ROOT/'sdk/development/recovery_floor_support_recontact_diagnosis_v1.json').read_text())
        cls.report=json.loads(Path(cls.record['source_report']['path']).read_text())

    def test_complete_cold_recomputation_and_claim_boundaries(self):
        self.assertEqual(self.record,diagnosis.observe())
        self.assertEqual(1600,self.record['measured_body_sample_count'])
        for key in ('world_build_count','solver_step_count','native_physics_read_count'):
            self.assertEqual(0,self.record[key])
        for key in ('physical_acceptance_authority','release_authority','original_evaluation_changed','physical_cause_proven','alternate_physical_outcome_predicted'):
            self.assertIs(False,self.record[key])

    def test_all_hold_intervals_match_native_counter_changes(self):
        entries=self.report['development_walking_entry']['rows']
        counts={name:[] for name in ('front_left','front_right','rear_left','rear_right')}
        for local,row in enumerate(entries,1):
            before={m['limb_id']:m for m in row['request']['memory']['ordered_limb_memory']}
            for after in row['native_output']['next_memory']['ordered_limb_memory']:
                limb=after['limb_id']
                if after['recontact_hold_step_count']!=before[limb]['recontact_hold_step_count']:
                    counts[limb].append(local)
        self.assertEqual({'front_left':list(range(76,196)),'front_right':[],'rear_left':[],'rear_right':list(range(277,374))},counts)
        a,b=self.record['recontact_hold_episodes']
        self.assertEqual((120,120,32,0),tuple(a[k] for k in ('held_command_count','requested_direction_unreachable_count','unreachable_even_with_unrestricted_planar_joint_angles_count','precommand_native_support_count')))
        self.assertEqual((97,0,0,2),tuple(b[k] for k in ('held_command_count','requested_direction_unreachable_count','unreachable_even_with_unrestricted_planar_joint_angles_count','precommand_native_support_count')))
        self.assertEqual([196],[v['command_local_step'] for v in self.record['native_timeouts']])

    def test_crossed_source_and_floor_context_refuse(self):
        with self.assertRaises(AssertionError):
            diagnosis.summarize(dict(self.report,source_commit='0'*40))
        rows=list(self.report['development_walking_entry']['rows'])
        request=dict(rows[10]['request'],floor_reference=dict(rows[10]['request']['floor_reference'],height_world_m=1.))
        rows[10]=dict(rows[10],request=request)
        changed=dict(self.report,development_walking_entry=dict(self.report['development_walking_entry'],rows=rows))
        with self.assertRaises(AssertionError):
            diagnosis.summarize(changed)


if __name__=='__main__':
    unittest.main()
