"""Cross-language native seed authority and malformed-envelope refusals."""
import copy
import json
from pathlib import Path
import subprocess
import sys
import unittest
import uuid

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'sdk/conformance'))
import r10j_campaign_authority as authority
import qsdk_r10f_l14_runtime_binding as runtime
import qsdk_r10f_l15_collection_retention as packet
import development_recovery_smoke as smoke
from test_r10j_campaign_authority import fixture


def case(mode, seed, role):
    auth, _, _, _ = fixture()
    identity = authority.seed_identity(seed)
    profile = auth['candidate_profile']
    population = authority.population(mode)
    children = [dict(cell_id=c['cell_id'], parent_attempt_id='b'*32 if c['seed']['seed'] == seed else f'{i+1:032x}',
                     child_attempt_id=f'{i+1:032x}') for i,c in enumerate(population)]
    selected = next(c for c in children if c['cell_id'] == f'{seed}:{role}')
    claim = dict(schema_version='sporespore_r10j_campaign_claim_v1', mode=mode,
                 cells=authority.population(mode), candidate_profile=profile,
                 attempt_id='a'*32, source_commit='3'*40,
                 children=children)
    context = dict(schema_version='sporespore_r10j_campaign_child_context_v1', mode=mode,
                   seed=identity, source_commit='3'*40, campaign_attempt_id='a'*32,
                   candidate_profile=profile, preregistration_binding=dict(raw_sha256=auth['preregistration_sha256']))
    declaration = dict(seed=seed, candidate_profile=profile, attempt_id='b'*32,
                       children=[dict(role=role, child_attempt_id=selected['child_attempt_id'])])
    preregistration = dict(campaign_id=authority.CAMPAIGN_ID,
                          cells=authority.population('held_out_finite_decision'), candidate_profile=profile)
    return dict(context=context, declaration=declaration, claim=claim,
                authority=auth if mode == 'held_out_finite_decision' else {},
                preregistration=preregistration if mode == 'held_out_finite_decision' else {},
                seed_text=str(seed), label=identity['label'], digest=identity['sha256'], role=role, source_commit='3'*40)


class CampaignSeed(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.cases = {}
        for mode, seeds in [('development_ghost', (40200,)), ('held_out_finite_decision', authority.SEEDS)]:
            for seed in seeds:
                for role in authority.ROLES:
                    cls.cases[f'positive_{seed}_{role}'] = case(mode, seed, role)
        baseline = case('held_out_finite_decision', 50641, authority.ROLES[0])
        corruptions = {
            'wrong_seed': ('seed_text', '50642'), 'bad_label': ('label', 'unknown'),
            'bad_seed_digest': ('digest', 'sha256:'+'0'*64), 'noncanonical_integer': ('seed_text', '050641'),
            'wrong_role': ('role', authority.ROLES[1]), 'wrong_source': ('source_commit', '9'*40),
        }
        for name, (key, value) in corruptions.items():
            item = copy.deepcopy(baseline); item[key] = value; cls.cases[name] = item
        mutations = {
            'missing_authority': lambda c: c.update(authority={}),
            'missing_claim': lambda c: c.update(claim={}),
            'missing_preregistration': lambda c: c.update(preregistration={}),
            'wrong_claim_child': lambda c: c['claim']['children'][0].update(child_attempt_id='d'*32),
            'wrong_parent': lambda c: c['claim']['children'][0].update(parent_attempt_id='d'*32),
            'mixed_candidate': lambda c: c['context'].update(candidate_profile=dict(c['context']['candidate_profile'], raw_sha256='sha256:'+'9'*64)),
            'reused_cell': lambda c: c['claim']['children'].append(copy.deepcopy(c['claim']['children'][0])),
            'incomplete_population': lambda c: c['authority']['cells'].pop(),
            'unconsented_retry': lambda c: c['authority'].update(retry_permitted=True),
            'release_claim': lambda c: c['authority'].update(release_authority=True),
            'numeric_execution_authority': lambda c: c['authority'].update(physical_execution_authorized=1),
            'numeric_retry_permission': lambda c: c['authority'].update(retry_permitted=0),
            'excess_world_budget': lambda c: c['authority'].update(maximum_world_attempt_count=7),
            'development_as_held_out': lambda c: c['context'].update(mode='development_ghost'),
        }
        for name, mutate in mutations.items():
            item = copy.deepcopy(baseline); mutate(item); cls.cases[name] = item
        cls.root = authority.EVIDENCE / ('r10j-seed-boundary-'+uuid.uuid4().hex)
        cls.root.mkdir()
        path = cls.root / 'cases.json'
        cls.publication = {name: dict(context=copy.deepcopy(value['context']), selected_seed=int(value['seed_text']))
                           for name, value in cls.cases.items() if name.startswith('positive_')}
        original = cls.publication['positive_50641_'+authority.ROLES[0]]
        for name, key, value in [('fractional_seed', 'seed', 50641.5), ('boolean_seed', 'seed', True),
                                 ('wrong_phase', 'prefix_phase', 242), ('boolean_phase', 'prefix_phase', True),
                                 ('wrong_label', 'label', 'unknown'), ('wrong_digest', 'sha256', 'sha256:'+'0'*64)]:
            changed = copy.deepcopy(original)
            changed['context']['seed'][key] = value
            cls.publication[name] = changed
        for name, seed in [('wrong_selected_seed', 50642), ('unknown_selected_seed', 99999)]:
            changed = copy.deepcopy(original); changed['selected_seed'] = seed; cls.publication[name] = changed
        changed = copy.deepcopy(original); changed['context']['mode'] = 'development_ghost'
        cls.publication['crossed_mode'] = changed
        path.write_text(json.dumps(dict(cases=cls.cases, publication=cls.publication)), encoding='utf-8')
        image = runtime.IMAGES['godot_engine']
        if runtime.file_identity(Path(image['path'])) != image:
            raise ValueError('R10J_SEED_ENGINE_DRIFT')
        command = [image['path'], '--headless', '--path', str(ROOT), '--script',
                   'res://tests/test_r10j_campaign_seed.gd', '--', str(path)]
        run = subprocess.run(command, cwd=ROOT, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                             timeout=60, creationflags=subprocess.CREATE_NO_WINDOW)
        (cls.root / 'stdout.txt').write_bytes(run.stdout)
        (cls.root / 'stderr.txt').write_bytes(run.stderr)
        print('R10J_SEED_BOUNDARY_ROOT', cls.root, flush=True)
        if run.returncode or b'ERROR:' in run.stdout+run.stderr:
            raise AssertionError((run.returncode, run.stdout.decode(), run.stderr.decode()))
        marker = 'R10J_SEED_BOUNDARY '
        rows = [line[len(marker):] for line in run.stdout.decode().splitlines() if line.startswith(marker)]
        if len(rows) != 1: raise AssertionError('R10J_SEED_MARKER')
        cls.result = json.loads(rows[0])

    def test_native_and_python_populations_match_exactly(self):
        self.assertEqual(authority.population('development_ghost'), self.result['development'])
        self.assertEqual(authority.population('held_out_finite_decision'), self.result['held_out'])
        self.assertEqual(0, self.result['world_build_count'])
        self.assertEqual(0, self.result['solver_step_count'])
        self.assertEqual({'exact_file': True, 'changed_bytes_refused': True, 'crossed_path_refused': True}, self.result['binding_checks'])

    def test_every_role_and_fixture_is_accepted_only_with_its_own_envelope(self):
        self.assertEqual(set(self.cases), set(self.result['cases']))
        for name, passed in self.result['cases'].items():
            self.assertIs(passed, name.startswith('positive_'), name)

    def test_production_publication_round_trip_and_invalid_seed_refusals(self):
        self.assertEqual(set(self.publication), set(self.result['publication']))
        for name, emitted in self.result['publication'].items():
            with self.subTest(name=name):
                expected = self.publication[name]['context']
                self.assertIs(emitted['declaration_unchanged'], True)
                self.assertEqual(1.0000000000000002, emitted['report']['measured_value'])
                self.assertIs(emitted['passed'], name.startswith('positive_'))
                if not emitted['passed']:
                    self.assertIs(emitted['refusal_report_unchanged'], True)
                    continue
                # This is the production reader's exact comparison, including
                # int/float identity. The old copied context must fail it.
                self.assertFalse(packet.same(emitted['generic_context'], expected))
                self.assertTrue(packet.same(emitted['report']['r10j_campaign'], expected))
                held_out = expected['mode'] == 'held_out_finite_decision'
                declaration = dict(r10j_campaign=expected)
                campaign = dict(seed=self.publication[name]['selected_seed'], held_out=held_out)
                smoke.validate_campaign_retention(emitted['report'], declaration, campaign)
                # Exercise every campaign-specific production header predicate,
                # including the label/digest omissions hidden by the first defect.
                for field in ('seed_label', 'seed_sha256', 'held_out_cell_access_count', 'r10j_campaign'):
                    changed = copy.deepcopy(emitted['report']); changed.pop(field)
                    with self.assertRaises(ValueError):
                        smoke.validate_campaign_retention(changed, declaration, campaign)
                self.assertIs(emitted['report']['held_out'], held_out)
                self.assertTrue(packet.same(emitted['report']['held_out_cell_access_count'], int(held_out)))
                self.assertEqual(expected['mode'], emitted['report']['ledger_scope']['authority_mode'])
                self.assertEqual('finite decision' if held_out else 'development',
                                 emitted['report']['ledger_scope']['question_class'])


if __name__ == '__main__':
    unittest.main()
