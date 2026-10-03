"""Actual final-reader boundaries on synthetic inputs; no physical claim."""
import copy
import json
from pathlib import Path
import sys
import unittest
from unittest import mock
import uuid

import test_development_recovery_smoke_reader as legacy
import r10af_selection_check as fixtures
import r10af_development as identity
import r10af_host_runtime as host
import r10af_smoke_result as result
import r10af_finite_task_audit as finite
import r10af_contact_frame_report as contacts
import development_passive_entry_profile as entry
from r10ac_support_loss_diagnosis import write


class R10AFSmokeReader(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.out = identity.EVIDENCE / ('r10af-smoke-reader-' + uuid.uuid4().hex); cls.out.mkdir()
        cls.before = entry._source_snapshot(); write(cls.out / 'source-before.json', cls.before)
        cls.fixed = fixtures.fixture(); cls.chosen = cls.fixed['selection']
        print('R10AF_SMOKE_READER_ROOT ' + str(cls.out), flush=True)

    @classmethod
    def tearDownClass(cls):
        after = entry._source_snapshot(); write(cls.out / 'source-after.json', after)
        assert after == cls.before

    def fixture(self):
        declaration = copy.deepcopy(self.fixed['declaration']); chosen = self.chosen; worker = chosen['worker_selection']
        declaration.update(fixtures.candidate.limits(chosen), schema_version=worker['declaration_schema'],
            diagnostic_schedule_id=worker['schedule'], worker_resource=worker['worker'],
            passive_entry_runtime=entry.binding(chosen)['runtime'], timeout_seconds_per_child=2400,
            independent_replay_timeout_seconds=1200, runtime=host.expected_binding(),
            context_cache_profile_id=entry.profile.CACHE_PROFILE_ID,
            context_cache_call_sites=entry.profile.CACHE_CALL_SITES, step_cost_profile_id=entry.profile.PROFILE_ID)
        report, _, _ = legacy.SmokeReader().fixture(); descriptor = declaration['children'][0]
        seed = identity.seed_identity(identity.SEED)
        report.update(schema_version=worker['report_schema'], work_id=worker['work_id'],
            source_commit=declaration['source_snapshot']['head'], parent_attempt_id=declaration['attempt_id'],
            child_attempt_id=descriptor['child_attempt_id'], arm_id=identity.ROLE, seed=identity.SEED,
            seed_label=seed['label'], seed_sha256=seed['sha256'], held_out_cell_access_count=0,
            maximum_solver_step_count=3752, r10af_development=declaration[identity.CONTEXT_KEY])
        for key in ('candidate_profile', 'development_execution_mode', 'comparative_authority', 'baseline_reused'):
            report[key] = declaration[key]
        report['retained_arm'] = dict(walking_sessions=[dict(evaluation_segment_id='walking_prefix', start_receipt=dict(
            initial_gait_steps=dict.fromkeys(('front_left', 'front_right', 'rear_left', 'rear_right'), 248),
            development_prefix_phase_selection=identity.prefix_selection(identity.SEED, identity.PREFIX_PROFILE)))])
        report['r10af_native_world_claim'] = dict(claim_binding=dict(
            path=(Path(descriptor['evidence_path']) / result.authority.CLAIM).as_posix(), raw_sha256='sha256:' + 'a'*64),
            world_permission_consumed=True, maximum_world_builds=1, physical_acceptance_authority=False, release_authority=False)
        return report, descriptor, declaration

    def test_actual_final_header_and_incomplete_diagnostic_admitted(self):
        report, descriptor, declaration = self.fixture()
        legacy.reader.validate_header(report, descriptor, declaration, 123)
        self.assertEqual([identity.ROLE], legacy.reader.declared_roles(declaration))
        report.update(coverage_complete=False, status='development_smoke_coverage_incomplete')
        legacy.reader.validate_header(report, descriptor, declaration, 123)
        write(self.out / 'synthetic-header.json', dict(synthetic_header_only=True, report=report, declaration=declaration))

    def test_crossed_identity_prefix_and_promoted_report_refused(self):
        report, descriptor, declaration = self.fixture()
        changes = [lambda r: r.update(r10ac_development={}), lambda r: r.update(seed=51008), lambda r: r.update(r10ab_development={}),
            lambda r: r.update(r10af_development={}), lambda r: r.update(held_out=True),
            lambda r: r.update(physical_acceptance_authority=True), lambda r: r.update(synthetic_test_fixture=True),
            lambda r: r.update(complete_route_proven=True), lambda r: r.update(release_authority=True),
            lambda r: r['retained_arm']['walking_sessions'][0]['start_receipt']['initial_gait_steps'].update(front_left=247),
            lambda r: r['retained_arm']['walking_sessions'][0]['start_receipt'].update(development_prefix_phase_selection={})]
        for change in changes:
            changed = copy.deepcopy(report); change(changed)
            with self.assertRaises(ValueError): legacy.reader.validate_header(changed, descriptor, declaration, 123)

    def test_missing_crossed_or_unused_native_claim_refused(self):
        report, descriptor, declaration = self.fixture()
        for field, value in [('world_permission_consumed', False), ('maximum_world_builds', True),
            ('maximum_world_builds', 2), ('claim_binding', {}), ('physical_acceptance_authority', True), ('release_authority', 0)]:
            changed = copy.deepcopy(report); changed['r10af_native_world_claim'][field] = value
            with self.subTest(field=field), self.assertRaises(ValueError): legacy.reader.validate_header(changed, descriptor, declaration, 123)
        del report['r10af_native_world_claim']
        with self.assertRaises(ValueError): legacy.reader.validate_header(report, descriptor, declaration, 123)

    def test_legacy_cannot_accept_undeclared_diagnostic_claim(self):
        for field in ('r10af_development', 'r10af_native_world_claim'):
            report, descriptor, declaration = legacy.SmokeReader().fixture(); report[field] = {}
            with self.assertRaisesRegex(ValueError, 'UNDECLARED_R10AF_DEVELOPMENT'):
                legacy.reader.validate_header(report, descriptor, declaration, 123)

    def test_physical_claim_binding_requires_independent_retained_verification(self):
        report, _, _ = self.fixture(); expected = report['r10af_native_world_claim']['claim_binding']
        declaration = self.out / 'synthetic-unused-declaration.json'
        with mock.patch.object(result.authority, 'verify', return_value=expected) as check:
            self.assertEqual(expected, result.verify_physical_claim(report, declaration, 123))
            check.assert_called_once_with(declaration, 123)
        with mock.patch.object(result.authority, 'verify', return_value=dict(expected, raw_sha256='sha256:'+'0'*64)):
            with self.assertRaisesRegex(ValueError, 'RETAINED_CLAIM'): result.verify_physical_claim(report, declaration, 123)

    def test_final_contact_check_requires_both_native_and_independent_replay(self):
        declaration = self.out / 'contact-declaration.json'; write(declaration, self.fixed['declaration'])
        report = self.fixed['report']; expected = contacts.replay_report(report, self.fixed['declaration'], identity)
        native = dict(controller_and_diagnostic_replay_passed=True, r10af_contact_frame_replay=expected)
        self.assertEqual(expected, result.diagnostic_replay(report, declaration, native))
        with self.assertRaises(ValueError): result.diagnostic_replay(report, declaration, dict(native, controller_and_diagnostic_replay_passed=False))
        crossed = copy.deepcopy(native); crossed['r10af_contact_frame_replay']['classification_changes'] += 1
        with self.assertRaises(ValueError): result.diagnostic_replay(report, declaration, crossed)

    def test_result_retains_negative_and_positive_diagnostics_without_claims(self):
        _, descriptor, declaration = self.fixture()
        contact = self.fixed['diagnostic_expected']
        children = [dict(role=identity.ROLE, solver_steps=contact['diagnostic_steps_replayed'], r10af_contact_frame_replay=contact)]
        for positive in (False, True):
            cells = [dict(role=identity.ROLE, child_attempt_id=descriptor['child_attempt_id'], entry_kind='partial', finite_task_predicates_passed=positive)]
            observed = result.finite_result(declaration, cells, children)
            self.assertIs(observed['all_tasks_positive'], positive)
            for name in ('causal_repair_proven', 'paired_commissioning_satisfied', 'comparative_authority', 'physical_acceptance_authority', 'release_authority'):
                self.assertIs(observed[name], False)
        children[0]['solver_steps'] += 1
        with self.assertRaisesRegex(ValueError, 'RESULT_CONTACT_REPLAY'): result.finite_result(declaration, cells, children)

    def test_unchanged_task_measurement_on_retained_synthetic_controller_report(self):
        path = identity.EVIDENCE / 'r10af-complete-report-a454b0e90f3543fa94074717824f8803/worker_report.json'
        self.assertEqual('sha256:f6f7aa4b2aab49928fddcea09aa7fe7a74c5a09ee59de684ee2921a92ec35024', identity.sha(path))
        report = json.loads(path.read_text())
        sys.path.insert(0, str(identity.ROOT / 'sdk/python'))
        from sporespore_locomotion import LocomotionCore
        core = LocomotionCore(entry.binding(self.chosen)['runtime']['path'])
        compiled = core.compile_bounded_quadruped(report['configuration']['base_descriptor'])
        measured = finite.measure(report, compiled)
        self.assertIs(measured['finite_task_predicates_passed'], False)
        self.assertEqual('walking_not_reached', measured['walking']['status'])
        self.assertIs(measured['physical_acceptance_authority'], False)
        write(self.out / 'synthetic-task-measurement.json', measured)


if __name__ == '__main__': unittest.main()
