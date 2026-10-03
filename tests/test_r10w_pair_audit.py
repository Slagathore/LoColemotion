"""Actual R10W header/declaration checks on synthetic nonphysical fixtures.

The fixture claim lives below a separate zero-world evidence directory, never
at an executable campaign consumption path. No original physical record exists.
"""
import copy
import json
import unittest
import uuid
from unittest import mock
from test_r10w_campaign_seed import case,authority,profile
import r10w_pair_audit as reader
import development_step_cost_profile as capture


class PairHeader(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.root=authority.EVIDENCE/('r10w-header-controls-'+uuid.uuid4().hex)
        cls.root.mkdir()
        scope=mock.patch.object(authority,'EVIDENCE',cls.root)
        scope.start();cls.addClassCleanup(scope.stop)
        item=case('development_ghost',41445,authority.ROLES[0])
        candidate=profile.reference();declaration=item['declaration'];claim=item['claim']
        declaration['candidate_profile']=candidate
        declaration['r10w_campaign']['candidate_profile']=candidate
        claim['candidate_profile']=candidate
        declaration['source_snapshot'].update(dirty=False,status=[],changed_file_bindings=[])
        claim.update(synthetic_zero_world_fixture=True,world_build_count=0,solver_step_count=0,
            physical_execution_authorized=False,physical_acceptance_authority=False,release_authority=False)
        folder=cls.root/('r10w-production-ghost-'+claim['attempt_id']);folder.mkdir()
        path=folder/'campaign_claim.json';path.write_text(json.dumps(claim),encoding='utf-8')
        declaration['r10w_campaign']['claim_binding']=dict(path=path.as_posix(),raw_sha256=authority.sha(path.read_bytes()))
        chosen=profile.selection();worker=chosen['worker_selection']
        declaration.update(profile.candidate.limits(chosen),schema_version=worker['declaration_schema'],
            diagnostic_schedule_id=worker['schedule'],passive_entry_runtime=profile.entry.binding(chosen)['runtime'],
            timeout_seconds_per_child=1740,independent_replay_timeout_seconds=900,official_qualification=False,
            physical_acceptance_authority=False,release_authority=False,comparative_authority=False,baseline_reused=False,
            context_cache_profile_id=capture.CACHE_PROFILE_ID,context_cache_call_sites=capture.CACHE_CALL_SITES,
            step_cost_profile_id=capture.PROFILE_ID)
        campaign=authority.validate_pair_declaration(declaration)
        prefix=dict(schema_version='sporespore_r10w_prefix_phase_selection_v1',profile_id='r10w_declared_campaign_prefix_phase_v1',seed=41445,prefix_phase=245,source_design_sha256=authority.DESIGN_SHA,physical_acceptance_authority=False,release_authority=False)
        cls.fixtures=[]
        for child in declaration['children']:
            report=dict(schema_version=worker['report_schema'],work_id=worker['work_id'],source_commit='3'*40,
                parent_attempt_id=declaration['attempt_id'],child_attempt_id=child['child_attempt_id'],arm_id=child['role'],process_id=123,
                seed=41445,maximum_solver_step_count=3752,model_construction_attempt_count=1,model_construction_count=1,
                world_attempt_count=1,world_build_count=1,complete_route_proven=False,held_out=False,physical_acceptance_authority=False,
                release_authority=False,behavioral_conclusion='none',telemetry_profile='unchanged_full_per_step_capture',ok=True,
                solver_step_count=1,global_solver_frame_count=1,after_interaction_step_count=0,coverage_complete=False,
                status='development_smoke_coverage_incomplete',ledger_scope=campaign['ledger_scope'],r10w_campaign=declaration['r10w_campaign'],
                seed_label=item['label'],seed_sha256=item['digest'],held_out_cell_access_count=0,
                retained_arm=dict(walking_sessions=[dict(evaluation_segment_id='walking_prefix',start_receipt=dict(
                    initial_gait_steps=dict.fromkeys(('front_left','front_right','rear_left','rear_right'),245),development_prefix_phase_selection=prefix))]))
            for key in ('candidate_profile','development_execution_mode','comparative_authority','baseline_reused'): report[key]=declaration[key]
            cls.fixtures.append((report,child,declaration))
        (cls.root/'synthetic_header_fixtures.json').write_text(json.dumps(cls.fixtures),encoding='utf-8')

    def test_both_development_headers_accept_the_exact_campaign_and_prefix(self):
        self.assertEqual(2,len(self.fixtures))
        for report,child,declaration in self.fixtures: reader.validate_header(report,child,declaration,123)

    def test_header_refuses_crossed_identity_claims_typed_counters_and_phase(self):
        report,child,declaration=self.fixtures[0]
        changes=dict(seed=50647,process_id=124,child_attempt_id='other',parent_attempt_id='other',source_commit='9'*40,
            candidate_profile={},baseline_reused=True,comparative_authority=True,held_out=True,held_out_cell_access_count=False,
            r10w_campaign={},seed_label='other',seed_sha256='other',physical_acceptance_authority=True,release_authority=True,
            solver_step_count=True,world_build_count=True,maximum_solver_step_count=3753,global_solver_frame_count=2,
            coverage_complete=1,ledger_scope={},synthetic_test_fixture=True,r10v_development={},retained_arm={})
        for key,value in changes.items():
            with self.subTest(key=key),self.assertRaises(ValueError): reader.validate_header(dict(report,**{key:value}),child,declaration,123)
        for key in ('r10w_campaign','seed_label','seed_sha256','held_out_cell_access_count'):
            changed=copy.deepcopy(report);changed.pop(key)
            with self.subTest(missing=key),self.assertRaises(ValueError): reader.validate_header(changed,child,declaration,123)

    def test_declaration_refuses_missing_roles_mixed_worker_changed_claim_and_deadline(self):
        report,child,declaration=self.fixtures[0]
        for mutate in (lambda d:d.update(worker_resource='res://other.gd'),lambda d:d['children'].pop(),
            lambda d:d['r10w_campaign']['claim_binding'].update(raw_sha256='sha256:'+'0'*64),
            lambda d:d.update(r10v_development={}),lambda d:d.update(timeout_seconds_per_child=1741),
            lambda d:d.update(development_execution_mode='single_kick_controller_diagnostic_v1')):
            changed=copy.deepcopy(declaration);mutate(changed)
            with self.assertRaises(ValueError): reader.validate_header(report,child,changed,123)


if __name__=='__main__': unittest.main()
