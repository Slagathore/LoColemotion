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
import r10x_campaign_authority as authority
import qsdk_r10f_l14_runtime_binding as runtime
import qsdk_r10f_l15_collection_retention as packet
import r10x_campaign_profile as profile
import development_passive_entry_profile as snapshot
from test_r10x_campaign_authority import fixture


def case(mode, seed, role):
    auth, _, _, graph = fixture()
    identity = authority.seed_identity(seed)
    candidate = auth['candidate_profile']
    population = authority.population(mode)
    parent = 'b'*32
    children = [dict(cell_id=c['cell_id'], role=c['role'], campaign_attempt_id='a'*32,
        parent_attempt_id=parent if c['seed']['seed'] == seed else f'{i+100:032x}',
        child_attempt_id=f'{i+1:032x}', termination_nonce=f'{i+20:032x}',
        evidence_path=f"{authority.EVIDENCE.as_posix()}/development-recovery-smoke-{parent}/children/{c['role']}")
        for i,c in enumerate(population)]
    claim = dict(schema_version='sporespore_r10x_campaign_claim_v1', mode=mode,
        cells=population, candidate_profile=candidate, attempt_id='a'*32, source_commit='3'*40, children=children)
    context = dict(schema_version='sporespore_r10x_campaign_child_context_v1', mode=mode,
        seed=identity, source_commit='3'*40, campaign_attempt_id='a'*32, candidate_profile=candidate,
        preregistration_binding=dict(raw_sha256=auth['preregistration_sha256']))
    selected = [child for child,c in zip(children,population) if c['seed']['seed'] == seed]
    declaration = dict(process_observation=dict(profile_id='r10x_native_process_observation_v1',explicit_selection=True,l15_context_required=True,cim_fallback_permitted=False),seed=seed, candidate_profile=candidate, attempt_id=parent, children=copy.deepcopy(selected),
        worker_resource=profile.WORKER, r10x_campaign=context, source_snapshot=dict(head='3'*40),
        development_execution_mode='fresh_paired_development_diagnostic_v1')
    preregistration = json.loads(graph['blobs'][auth['source_freeze_commit'], authority.PREREGISTRATION_PATH])
    return dict(context=context, declaration=declaration, claim=claim,
        authority=auth if mode == 'held_out_finite_decision' else {},
        preregistration=preregistration if mode == 'held_out_finite_decision' else {},
        seed_text=str(seed), label=identity['label'], digest=identity['sha256'], role=role, source_commit='3'*40)


class CampaignSeed(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.cases = {}
        for mode in ('development_ghost', 'held_out_finite_decision'):
            for cell in authority.population(mode):
                seed, role = cell['seed']['seed'], cell['role']
                cls.cases[f'positive_{seed}_{role}'] = case(mode, seed, role)
        baseline = case('held_out_finite_decision', 51007, authority.ROLES[0])
        corruptions = {
            'wrong_seed': ('seed_text', '51008'), 'bad_label': ('label', 'unknown'),
            'bad_seed_digest': ('digest', 'sha256:'+'0'*64), 'noncanonical_integer': ('seed_text', '051007'),
            'unknown_role': ('role', 'undeclared_role'), 'wrong_source': ('source_commit', '9'*40),
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
            'wrong_worker': lambda c: c['declaration'].update(worker_resource='res://unknown.gd'),
            'wrong_declaration_source': lambda c: c['declaration']['source_snapshot'].update(head='9'*40),
            'crossed_r10o_context': lambda c: c['declaration'].update(r10o_development={}),
            'missing_paired_role': lambda c: c['declaration']['children'].pop(),
            'wrong_mode': lambda c: c['declaration'].update(development_execution_mode='single_kick_controller_diagnostic_v1'),
            'changed_nonce': lambda c: c['declaration']['children'][0].update(termination_nonce='e'*32),
            'baseline_reuse': lambda c: c['authority'].update(baseline_reuse_permitted=True),
            'threshold_override': lambda c: c['authority'].update(threshold_override_permitted=True),
            'skip_negative_cell': lambda c: c['authority'].update(all_cells_run_regardless_of_behavior=False),
            'changed_reader': lambda c: c['preregistration'].update(reader_contract_sha256='sha256:'+'0'*64),
            'changed_task': lambda c: c['preregistration'].update(task_contract_sha256='sha256:'+'0'*64),
        }
        for name, mutate in mutations.items():
            item = copy.deepcopy(baseline); mutate(item); cls.cases[name] = item
        cls.root = authority.EVIDENCE / ('r10x-seed-boundary-'+uuid.uuid4().hex)
        cls.root.mkdir()
        path = cls.root / 'cases.json'
        cls.publication = {name: dict(context=copy.deepcopy(value['context']), declaration=copy.deepcopy(value['declaration']),
            role=value['role'], selected_seed=int(value['seed_text']))
            for name, value in cls.cases.items() if name.startswith('positive_')}
        original = cls.publication['positive_51007_'+authority.ROLES[0]]
        for name, key, value in [('fractional_seed', 'seed', 51007.5), ('boolean_seed', 'seed', True),
                                 ('wrong_phase', 'prefix_phase', 242), ('boolean_phase', 'prefix_phase', True),
                                 ('wrong_label', 'label', 'unknown'), ('wrong_digest', 'sha256', 'sha256:'+'0'*64)]:
            changed = copy.deepcopy(original)
            changed['context']['seed'][key] = value
            cls.publication[name] = changed
        for name, seed in [('wrong_selected_seed', 51008), ('unknown_selected_seed', 99999)]:
            changed = copy.deepcopy(original); changed['selected_seed'] = seed; cls.publication[name] = changed
        changed = copy.deepcopy(original); changed['context']['mode'] = 'development_ghost'
        cls.publication['crossed_mode'] = changed
        path.write_text(json.dumps(dict(cases=cls.cases, publication=cls.publication, candidate_profile=profile.reference())), encoding='utf-8')
        source = snapshot._source_snapshot()
        (cls.root / 'source_snapshot.json').write_text(json.dumps(source), encoding='utf-8')
        image = runtime.IMAGES['godot_engine']
        if runtime.file_identity(Path(image['path'])) != image:
            raise ValueError('R10X_SEED_ENGINE_DRIFT')
        command = [image['path'], '--headless', '--path', str(ROOT), '--script',
                   'res://tests/test_r10x_campaign_seed.gd', '--', str(path)]
        run = subprocess.run(command, cwd=ROOT, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                             timeout=60, creationflags=subprocess.CREATE_NO_WINDOW)
        (cls.root / 'stdout.txt').write_bytes(run.stdout)
        (cls.root / 'stderr.txt').write_bytes(run.stderr)
        unchanged = packet.same(source, snapshot._source_snapshot())
        receipt = dict(command=command, engine_image=image, returncode=run.returncode,
            timeout_seconds=60, source_unchanged_during_run=unchanged,
            input_binding=runtime.file_identity(path), source_snapshot_binding=runtime.file_identity(cls.root / 'source_snapshot.json'),
            stdout_binding=runtime.file_identity(cls.root / 'stdout.txt'), stderr_binding=runtime.file_identity(cls.root / 'stderr.txt'),
            world_build_count=0, solver_step_count=0, physical_acceptance_authority=False, release_authority=False)
        (cls.root / 'execution.json').write_text(json.dumps(receipt), encoding='utf-8')
        if not unchanged: raise AssertionError('R10X_SEED_SOURCE_CHANGED')
        print('R10X_SEED_BOUNDARY_ROOT', cls.root, flush=True)
        if run.returncode or b'ERROR:' in run.stdout+run.stderr:
            raise AssertionError((run.returncode, run.stdout.decode(), run.stderr.decode()))
        marker = 'R10X_SEED_BOUNDARY '
        rows = [line[len(marker):] for line in run.stdout.decode().splitlines() if line.startswith(marker)]
        if len(rows) != 1: raise AssertionError('R10X_SEED_MARKER')
        cls.result = json.loads(rows[0])

    def test_actual_profile_worker_and_prefix_dispatch_preserve_native_behavior(self):
        chosen = profile.selection()
        native = self.result['actual_profile']
        self.assertTrue(self.result['worker_script_loaded'])
        self.assertEqual(chosen['candidate_profile'], native['candidate_profile'])
        self.assertEqual(chosen['diagnostic_schedule'], native['diagnostic_schedule'])
        self.assertEqual(chosen['reader'], native['reader'])
        self.assertEqual(chosen['candidate']['runtime_sha256'], native['candidate']['runtime_sha256'])
        # The subclass supplies R10X entry/publication; its inherited native route stays R10V.
        self.assertEqual('res://sdk/adapters/godot/gdscript/r10v_recovery_worker_v1.gd', native['worker_selection']['worker'])
        self.assertEqual(profile.WORKER, chosen['worker_selection']['worker'])
        for seed in (*authority.DEVELOPMENT_SEEDS, *authority.SEEDS):
            phase = authority.seed_identity(seed)['prefix_phase']
            expected = dict.fromkeys(('front_left','front_right','rear_left','rear_right'),phase)
            self.assertEqual(expected,self.result['prefix_steps'][str(seed)])
        self.assertTrue(all(self.result['prefix_refusals'].values()))

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
                self.assertTrue(packet.same(emitted['report']['r10x_campaign'], expected))
                held_out = expected['mode'] == 'held_out_finite_decision'
                declaration = dict(r10x_campaign=expected)
                campaign = dict(seed=self.publication[name]['selected_seed'], held_out=held_out)
                profile.validate_campaign_retention(emitted['report'], declaration, campaign)
                # Exercise every campaign-specific production header predicate,
                # including the label/digest omissions hidden by the first defect.
                for field in ('seed_label', 'seed_sha256', 'held_out_cell_access_count', 'r10x_campaign'):
                    changed = copy.deepcopy(emitted['report']); changed.pop(field)
                    with self.assertRaises(ValueError):
                        profile.validate_campaign_retention(changed, declaration, campaign)
                self.assertIs(emitted['report']['held_out'], held_out)
                self.assertTrue(packet.same(emitted['report']['held_out_cell_access_count'], int(held_out)))
                self.assertEqual(expected['mode'], emitted['report']['ledger_scope']['authority_mode'])
                self.assertEqual('finite decision' if held_out else 'development',
                                 emitted['report']['ledger_scope']['question_class'])


if __name__ == '__main__':
    unittest.main()
