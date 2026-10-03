"""Actual launcher fields -> shared final-auditor declaration path.

Candidate selection is the sole injected boundary: a complete R10U dependency
key and production route are still required before these components can launch.
No timeout global is patched, and no old physical attempt is reclassified.
"""
import copy
import json
import subprocess
import unittest
from unittest import mock
import uuid

from test_r10u_development_context import ROOT, REFERENCE, declaration, development, entry, smoke, write
import r10u_host_deadline as host


class HostDeadline(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.out = development.EVIDENCE/('r10u-host-deadline-component-'+uuid.uuid4().hex)
        cls.out.mkdir()
        cls.before = entry._source_snapshot(); write(cls.out/'source_before.json',cls.before)
        print('R10U_HOST_DEADLINE_COMPONENT_EVIDENCE '+str(cls.out),flush=True)
        chosen = copy.deepcopy(entry.candidate_profile.contract())
        profile = entry.read(ROOT/'sdk/development/recovery_candidates/r10t-v56-post-recovery-hold-integrated-v1.json')
        profile['candidate_id'] = host.CANDIDATE_ID
        schedule = entry.read(ROOT/'sdk/development/recovery_schedules/r10t-v56-post-recovery-hold-integrated-v1.json')['schedules']['r10t-v56-post-recovery-hold-integrated-v1']
        schedule['walking_policy_id'] = development.ROUTE
        schedule['coverage_basis']['successor_design'] = development.DESIGN.relative_to(ROOT).as_posix()
        schedule['coverage_basis']['successor_design_sha256'] = development.DESIGN_SHA
        chosen.update(candidate_profile=REFERENCE,candidate=profile,diagnostic_schedule=schedule)
        chosen['worker_selection']['binding'] = profile['runtime_binding']
        chosen['worker_selection']['worker'] = 'res://sdk/adapters/godot/gdscript/r10u_recovery_worker_v1.gd'
        cls.chosen = chosen
        fixture = cls.out/'synthetic-selection.json'
        write(fixture,dict(selection=chosen,declaration=declaration(),synthetic_component_only=True))
        command = ['pwsh','-NoProfile','-File',str(ROOT/'tests/test_r10u_host_deadline.ps1'),
            '-Fixture',str(fixture),'-Output',str(cls.out/'launcher-declaration.json')]
        with (cls.out/'launcher.stdout.log').open('xb') as stdout, (cls.out/'launcher.stderr.log').open('xb') as stderr:
            process = subprocess.run(command,cwd=ROOT,stdout=stdout,stderr=stderr,timeout=90,creationflags=subprocess.CREATE_NO_WINDOW)
        write(cls.out/'launcher-execution.json',dict(command=command,exit_code=process.returncode,world_build_count=0,solver_step_count=0))
        if process.returncode:
            raise AssertionError((cls.out/'launcher.stderr.log').read_text(encoding='utf-8'))
        cls.value = entry.read(cls.out/'launcher-declaration.json')

    @classmethod
    def tearDownClass(cls):
        after = entry._source_snapshot(); write(cls.out/'source_after.json',after)
        if cls.before != after: raise AssertionError('R10U_HOST_COMPONENT_SOURCE_DRIFT')

    def audit(self, value, chosen=None):
        with mock.patch.object(entry.candidate_profile,'selection',return_value=self.chosen if chosen is None else chosen) as selection:
            observed = smoke.declared_schedule(value)
            selection.assert_called_once_with(value['candidate_profile'])
            return observed

    def test_actual_launcher_fields_pass_shared_final_auditor(self):
        self.assertEqual(1500,entry.CHILD_TIMEOUT_SECONDS)
        self.assertEqual(1740,self.value['timeout_seconds_per_child'])
        self.assertEqual(self.chosen['diagnostic_schedule']['limits'],self.audit(self.value))
        self.assertEqual(1500,entry.CHILD_TIMEOUT_SECONDS)

    def test_stale_crossed_missing_boolean_and_float_deadlines_refuse(self):
        for deadline in (1500,1741,True,False,1740.0,'1740',None):
            changed = copy.deepcopy(self.value); changed['timeout_seconds_per_child'] = deadline
            with self.subTest(deadline=deadline),self.assertRaisesRegex(ValueError,'DECLARATION_timeout_seconds_per_child'):
                self.audit(changed)
        changed = copy.deepcopy(self.value); del changed['timeout_seconds_per_child']
        with self.assertRaisesRegex(ValueError,'DECLARATION_timeout_seconds_per_child'): self.audit(changed)

    def test_wrong_profile_route_reference_or_design_cannot_borrow_deadline(self):
        changes = {
            'profile':lambda c:c['candidate'].update(candidate_id='r10t-v56-post-recovery-hold-integrated-v1'),
            'route':lambda c:c['diagnostic_schedule'].update(walking_policy_id='r10t_v56_post_recovery_hold_route_v1'),
            'reference':lambda c:c.update(candidate_profile={}),
            'design_path':lambda c:c['diagnostic_schedule']['coverage_basis'].update(successor_design='sdk/recovery/r10t_post_recovery_settling_design_v1.json'),
            'design_digest':lambda c:c['diagnostic_schedule']['coverage_basis'].update(successor_design_sha256='sha256:'+'0'*64),
        }
        for name,mutate in changes.items():
            chosen = copy.deepcopy(self.chosen); mutate(chosen)
            with self.subTest(name=name),self.assertRaisesRegex(ValueError,'HOST_DEADLINE_'):
                self.audit(self.value,chosen)

    def test_missing_or_crossed_context_cannot_borrow_deadline(self):
        changed = copy.deepcopy(self.value); del changed['r10u_development']
        with self.assertRaisesRegex(ValueError,'CONTEXT_SHAPE'): self.audit(changed)
        changed = copy.deepcopy(self.value); changed['r10t_development'] = {}
        with self.assertRaisesRegex(ValueError,'CROSSED_CAMPAIGN'): self.audit(changed)

    def test_existing_candidate_retains_original_1500_second_contract(self):
        chosen = copy.deepcopy(self.chosen)
        chosen['diagnostic_schedule']['walking_policy_id'] = 'r10t_v56_post_recovery_hold_route_v1'
        changed = copy.deepcopy(self.value); del changed['r10u_development']
        with self.assertRaisesRegex(ValueError,'DECLARATION_timeout_seconds_per_child'):
            self.audit(changed,chosen)
        changed['timeout_seconds_per_child'] = 1500
        self.assertEqual(chosen['diagnostic_schedule']['limits'],self.audit(changed,chosen))

    def test_shared_auditor_still_checks_other_budgets_and_no_claims(self):
        for field,value in [('maximum_steps_per_child',3753),('after_interaction_steps',3401),
                ('independent_replay_timeout_seconds',1740),('release_authority',True),
                ('physical_acceptance_authority',True),('official_qualification',True),('baseline_reused',True)]:
            changed = copy.deepcopy(self.value); changed[field] = value
            with self.subTest(field=field),self.assertRaises(ValueError): self.audit(changed)


if __name__ == '__main__':
    unittest.main()
