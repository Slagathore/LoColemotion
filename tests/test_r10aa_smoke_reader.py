"""R10AA-specific admission in the real final auditor; synthetic headers only."""
import copy
import unittest

import test_development_r10aa_complete_report as shared
import test_development_recovery_smoke_reader as original
import development_recovery_smoke as reader


class R10AASmokeReader(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.reference = shared.candidate.reference_for_path(shared.PROFILE)
        cls.head = shared.entry._source_snapshot()['head']

    def fixture(self):
        report, _, _ = original.SmokeReader().fixture()
        declaration = shared.declaration(self.reference, self.head)
        descriptor = declaration['children'][0]
        worker = shared.candidate.selection(self.reference)['worker_selection']
        identity = shared.development.seed_identity(51008)
        report.update(schema_version=worker['report_schema'], work_id=worker['work_id'], source_commit=self.head,
            parent_attempt_id=declaration['attempt_id'], child_attempt_id=descriptor['child_attempt_id'],
            arm_id=descriptor['role'], seed=51008, seed_label=identity['label'], seed_sha256=identity['sha256'],
            held_out_cell_access_count=0, maximum_solver_step_count=3752,
            r10aa_development=declaration['r10aa_development'])
        for key in ('candidate_profile', 'development_execution_mode', 'comparative_authority', 'baseline_reused'):
            report[key] = declaration[key]
        report['retained_arm'] = dict(walking_sessions=[dict(evaluation_segment_id='walking_prefix',
            start_receipt=dict(initial_gait_steps=dict.fromkeys(('front_left','front_right','rear_left','rear_right'),248),
                development_prefix_phase_selection=dict(schema_version='sporespore_r10aa_prefix_phase_selection_v1',
                    profile_id='r10aa_declared_development_prefix_phase_v1', seed=51008, prefix_phase=248,
                    source_design_sha256=shared.development.DESIGN_SHA,
                    physical_acceptance_authority=False, release_authority=False)))])
        return report, descriptor, declaration

    def test_actual_header_admission_preserves_single_role_and_no_claims(self):
        report, descriptor, declaration = self.fixture()
        reader.validate_header(report, descriptor, declaration, 123)
        self.assertEqual([descriptor['role']], reader.declared_roles(declaration))
        report.update(coverage_complete=False, status='development_smoke_coverage_incomplete')
        reader.validate_header(report, descriptor, declaration, 123)

    def test_crossed_seed_phase_report_context_and_promotions_refused(self):
        report, descriptor, declaration = self.fixture()
        for mutate in [lambda r: r.update(seed=51007), lambda r: r.update(seed_label='old'),
            lambda r: r.update(r10aa_development={}), lambda r: r.update(r10v_development={}),
            lambda r: r.update(held_out=True), lambda r: r.update(held_out_cell_access_count=1),
            lambda r: r.update(synthetic_test_fixture=True), lambda r: r.update(physical_acceptance_authority=True),
            lambda r: r.update(complete_route_proven=True), lambda r: r.update(release_authority=True),
            lambda r: r['retained_arm']['walking_sessions'][0]['start_receipt']['initial_gait_steps'].update(front_left=247),
            lambda r: r['retained_arm']['walking_sessions'].append(copy.deepcopy(r['retained_arm']['walking_sessions'][0]))]:
            bad = copy.deepcopy(report); mutate(bad)
            with self.assertRaises(ValueError): reader.validate_header(bad, descriptor, declaration, 123)

    def test_undeclared_r10aa_context_cannot_enter_legacy_reader(self):
        report, descriptor, declaration = original.SmokeReader().fixture()
        report['r10aa_development'] = {}
        with self.assertRaisesRegex(ValueError, 'UNDECLARED_R10AA_DEVELOPMENT'):
            reader.validate_header(report, descriptor, declaration, 123)


if __name__ == '__main__': unittest.main()
