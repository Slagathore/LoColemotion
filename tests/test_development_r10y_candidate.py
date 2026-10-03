"""Cross-language candidate/population/worker admission checks, never launch."""
import copy
import unittest
import uuid

from test_development_r10y_complete_report import ROOT, PROFILE, candidate, development, native, entry, declaration, write
import test_development_r10q_source_orchestration as shared


def refusals(value):
    result = []
    def case(label, mutate):
        bad = copy.deepcopy(value)
        mutate(bad)
        result.append(dict(label=label, declaration=bad))
    case('paired_mode', lambda d: d.update(development_execution_mode='fresh_paired_development_diagnostic_v1'))
    case('extra_child', lambda d: d['children'].append(copy.deepcopy(d['children'][0])))
    case('wrong_role', lambda d: d['children'][0].update(role='matched_no_kick_continuation'))
    case('crossed_campaign', lambda d: d.update(r10v_development={}))
    case('baseline_reuse', lambda d: d.update(baseline_reused=True))
    case('comparative_claim', lambda d: d.update(comparative_authority=True))
    case('undeclared_seed', lambda d: d.update(seed=51007))
    case('source_commit', lambda d: d['r10y_development'].update(source_commit='0' * 40))
    case('phase', lambda d: d['r10y_development']['seed'].update(prefix_phase=247))
    case('profile', lambda d: d['r10y_development'].update(candidate_profile=dict(d['candidate_profile'], raw_sha256='sha256:' + '0' * 64)))
    case('design', lambda d: d['r10y_development']['design_binding'].update(raw_sha256='sha256:' + '0' * 64))
    case('branch', lambda d: d['r10y_development'].update(required_entry_kind='upright'))
    case('stage', lambda d: d['r10y_development'].update(stage='paired_commissioning'))
    case('acceptance', lambda d: d['r10y_development'].update(physical_acceptance_authority=True))
    case('release', lambda d: d['r10y_development'].update(release_authority=True))
    case('id_reuse', lambda d: d['children'][0].update(termination_nonce=d['children'][0]['child_attempt_id']))
    case('parent_id_reuse', lambda d: d['children'][0].update(child_attempt_id=d['attempt_id']))
    case('path', lambda d: d['children'][0].update(evidence_path=(native.EVIDENCE / 'crossed').as_posix()))
    return result


class R10YCandidate(unittest.TestCase):
    run_godot = shared.R10QSourceOrchestration.run_godot

    @classmethod
    def setUpClass(cls):
        cls.out = native.EVIDENCE / ('r10y-candidate-' + uuid.uuid4().hex)
        cls.out.mkdir()
        cls.before = entry._source_snapshot()
        write(cls.out / 'source_before.json', cls.before)
        print('R10Y_CANDIDATE_ROOT ' + str(cls.out), flush=True)
        reference = candidate.reference_for_path(PROFILE)
        cls.declaration = declaration(reference, cls.before['head'])
        cls.input = cls.out / 'input.json'
        cls.bad = refusals(cls.declaration)
        write(cls.input, dict(declaration=cls.declaration, selection=candidate.selection(reference), refusals=cls.bad))

    @classmethod
    def tearDownClass(cls):
        after = entry._source_snapshot()
        write(cls.out / 'source_after.json', after)
        assert after == cls.before

    def test_python_context_population_and_result_refusals(self):
        self.assertEqual([51008], [development.validate_declaration(self.declaration)['seed']])
        for value in self.bad:
            with self.subTest(defect=value['label']), self.assertRaises(ValueError):
                development.validate_context(value['declaration']['r10y_development'], value['declaration'])
        cell = dict(role=development.ROLES[0], entry_kind='partial', finite_task_predicates_passed=False)
        result = development.finite_result(self.declaration, [cell])
        self.assertFalse(result['all_tasks_positive'] or result['paired_commissioning_satisfied'] or result['physical_acceptance_authority'])
        with self.assertRaises(ValueError):
            development.finite_result(self.declaration, [cell, cell])
        write(self.out / 'python.json', dict(ok=True, context_refusals=len(self.bad), result_population_refusals=1,
            single_result=result, world_build_count=0, solver_step_count=0))

    def test_godot_profile_population_worker_and_publication(self):
        result = self.run_godot('godot', 'test_development_r10y_candidate.gd', self.input, 120)
        self.assertTrue(result['checks']['python_godot_selection_equal'])
        self.assertFalse(result['launch_gate_checked'])


if __name__ == '__main__':
    unittest.main()
