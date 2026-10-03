"""Pure authority graph controls cannot create or consume a physical campaign."""
import copy
import json
from pathlib import Path
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'sdk/conformance'))
import r10j_campaign_authority as authority


def raw(value):
    return json.dumps(value, sort_keys=True).encode()


def fixture():
    freeze, qualification_commit, head = ('1'*40, '2'*40, '3'*40)
    candidate = dict(resource=authority.CANDIDATE_RESOURCE, raw_sha256='sha256:'+'4'*64)
    route_key = 'sha256:'+'5'*64
    preregistration = dict(schema_version='sporespore_r10j_held_out_preregistration_v1',
                          campaign_id=authority.CAMPAIGN_ID, candidate_profile=candidate,
                          cells=authority.population('held_out_finite_decision'),
                          task_contract_path=authority.TASK_PATH, task_contract_sha256=authority.TASK_SHA,
                          maximum_campaign_attempt_count=1, maximum_world_attempt_count=6,
                          maximum_solver_step_count=18192, all_cells_must_pass=True,
                          all_cells_run_regardless_of_behavior=True, cell_replacement_permitted=False,
                          retry_permitted=False, threshold_override_permitted=False,
                          physical_execution_authorized=False, physical_acceptance_authority=False, release_authority=False)
    manifest = dict(production_route_key=route_key)
    ghost = dict(production_route_ghost_passed=True, launcher_ok=True, independent_audit_ok=True,
                 post_exposure_regraded=False, held_out_worlds_opened=0,
                 physical_acceptance_authority=False, production_route_key=route_key)
    qualification = dict(schema_version='sporespore_r10j_zero_world_qualification_v1', passed=True,
                         source_freeze_commit=freeze, world_build_count=0, solver_step_count=0,
                         physical_execution_authorized=False, production_route_key=route_key,
                         preregistration_sha256=authority.sha(raw(preregistration)),
                         dependency_manifest_sha256=authority.sha(raw(manifest)))
    auth = dict(schema_version='sporespore_r10j_execution_authority_v1', campaign_id=authority.CAMPAIGN_ID,
                qualification_closure_path=authority.QUALIFICATION_PATH, prerequisite_ghost_path=authority.GHOST_PATH,
                maximum_campaign_attempt_count=1, maximum_world_attempt_count=6, maximum_solver_step_count=18192,
                physical_execution_authorized=True, physical_acceptance_authority=False, release_authority=False,
                retry_permitted=False, cell_replacement_permitted=False,
                cells=authority.population('held_out_finite_decision'), source_freeze_commit=freeze,
                qualification_commit=qualification_commit, qualification_closure_sha256=authority.sha(raw(qualification)),
                prerequisite_ghost_sha256=authority.sha(raw(ghost)), candidate_profile=candidate,
                preregistration_sha256=qualification['preregistration_sha256'],
                dependency_manifest_sha256=qualification['dependency_manifest_sha256'])
    blobs = {(head, authority.AUTHORITY_PATH): raw(auth),
             (qualification_commit, authority.QUALIFICATION_PATH): raw(qualification),
             (freeze, authority.GHOST_PATH): raw(ghost),
             (freeze, authority.PREREGISTRATION_PATH): raw(preregistration),
             (freeze, authority.MANIFEST_PATH): raw(manifest)}
    parents = {head: [qualification_commit], qualification_commit: [freeze]}
    changes = {head: [authority.AUTHORITY_PATH], qualification_commit: [authority.QUALIFICATION_PATH]}
    return auth, qualification, ghost, dict(head=head, parents=parents, changes=changes, blobs=blobs)


def validate(auth, qualification, ghost, graph):
    return authority.validate_graph(auth, qualification, ghost, head=graph['head'],
                                    parents=graph['parents'].__getitem__, changes=graph['changes'].__getitem__,
                                    blob=lambda commit, path: graph['blobs'][commit, path])


class CampaignAuthority(unittest.TestCase):
    def test_exact_development_and_held_out_populations(self):
        ghost = authority.population('development_ghost')
        held_out = authority.population('held_out_finite_decision')
        self.assertEqual(2, len(ghost))
        self.assertEqual(6, len(held_out))
        self.assertEqual([241, 242, 243], [row['seed']['prefix_phase'] for row in held_out[::2]])
        self.assertEqual(18192, sum(row['maximum_solver_steps'] for row in held_out))
        self.assertEqual(authority.DEVELOPMENT_SHA, ghost[0]['seed']['sha256'])

    def test_in_memory_complete_graph_passes_without_creating_authority(self):
        auth, qualification, ghost, graph = fixture()
        result = validate(auth, qualification, ghost, graph)
        self.assertEqual(graph['head'], result['authority_commit'])
        self.assertNotIn('physical_execution_authorized', result)

    def test_missing_reordered_repeated_or_mixed_population_refuses(self):
        cells = authority.population('held_out_finite_decision')
        cases = [cells[:-1], cells[::-1], cells[:1]*6, authority.population('development_ghost')+cells[2:]]
        wrong_role = copy.deepcopy(cells); wrong_role[0]['role'] = authority.ROLES[1]; cases.append(wrong_role)
        wrong_sha = copy.deepcopy(cells); wrong_sha[0]['seed']['sha256'] = 'sha256:'+'0'*64; cases.append(wrong_sha)
        bool_count = copy.deepcopy(cells); bool_count[0]['maximum_world_builds'] = True; cases.append(bool_count)
        for case in cases:
            with self.subTest(case=case), self.assertRaises(ValueError):
                authority.validate_population(case, 'held_out_finite_decision')

    def test_merge_skipped_qualification_and_source_in_authority_commit_refuse(self):
        for defect in ('merge', 'skip', 'source', 'qualification_source'):
            auth, qualification, ghost, graph = fixture()
            if defect == 'merge': graph['parents'][graph['head']].append('9'*40)
            elif defect == 'skip': graph['parents'][graph['head']] = [auth['source_freeze_commit']]
            elif defect == 'source': graph['changes'][graph['head']].append('sdk/core/src/controller.rs')
            else: graph['changes'][auth['qualification_commit']].append('sdk/core/src/controller.rs')
            with self.subTest(defect=defect), self.assertRaises(ValueError):
                validate(auth, qualification, ghost, graph)

    def test_failed_launcher_missing_audit_and_post_exposure_regrade_refuse(self):
        for key, value in [('production_route_ghost_passed', False), ('launcher_ok', False),
                           ('independent_audit_ok', None), ('post_exposure_regraded', True),
                           ('production_route_key', 'sha256:'+'9'*64)]:
            auth, qualification, ghost, graph = fixture()
            ghost[key] = value
            graph['blobs'][auth['source_freeze_commit'], authority.GHOST_PATH] = raw(ghost)
            auth['prerequisite_ghost_sha256'] = authority.sha(raw(ghost))
            graph['blobs'][graph['head'], authority.AUTHORITY_PATH] = raw(auth)
            with self.subTest(key=key), self.assertRaises(ValueError):
                validate(auth, qualification, ghost, graph)

    def test_tampered_qualification_and_runtime_route_key_refuse(self):
        for key, value in [('passed', False), ('source_freeze_commit', '9'*40),
                           ('world_build_count', 1), ('production_route_key', 'sha256:'+'9'*64)]:
            auth, qualification, ghost, graph = fixture()
            qualification[key] = value
            graph['blobs'][auth['qualification_commit'], authority.QUALIFICATION_PATH] = raw(qualification)
            auth['qualification_closure_sha256'] = authority.sha(raw(qualification))
            graph['blobs'][graph['head'], authority.AUTHORITY_PATH] = raw(auth)
            with self.subTest(key=key), self.assertRaises(ValueError):
                validate(auth, qualification, ghost, graph)

    def test_authority_threshold_retry_or_release_promotion_refuses(self):
        for key, value in [('maximum_campaign_attempt_count', 2), ('maximum_solver_step_count', 18193),
                           ('retry_permitted', True), ('cell_replacement_permitted', True),
                           ('physical_acceptance_authority', True), ('release_authority', True)]:
            auth, qualification, ghost, graph = fixture()
            auth[key] = value
            graph['blobs'][graph['head'], authority.AUTHORITY_PATH] = raw(auth)
            with self.subTest(key=key), self.assertRaises(ValueError):
                validate(auth, qualification, ghost, graph)

    def test_ambiguous_json_and_undeclared_seeds_refuse(self):
        for value in ('{"seed":50641,"seed":50642}', '{"seed":NaN}'):
            with self.assertRaises(ValueError): authority.parse(value)
        for seed in (True, 40201, 50644, 50641.):
            with self.assertRaises(ValueError): authority.seed_identity(seed)


if __name__ == '__main__':
    unittest.main()
