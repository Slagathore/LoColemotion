"""R10K compiled interfaces and synthetic source-bound controls; no physics."""
import copy
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import unittest
import uuid

ROOT = Path(__file__).resolve().parents[1]
sys.path[:0] = [str(ROOT / 'sdk/python'), str(ROOT / 'sdk/conformance')]
from sporespore_locomotion import LocomotionCore, LocomotionCoreError
from test_development_v32_recontact_component import NativeApi

PROFILE = ROOT / 'sdk/development/recovery_candidates/r10k-partial-fall-control-core-v1.json'
FIXTURES = ROOT.parent / 'SporeSpore_Evidence/development-r10k-control-component-90952b02eab94958a0db68ca0ae1a08e/stdout.log'
OLD = ROOT / 'sdk/development/recovery_candidates/r10i-joint-pose-entry-core-v1.runtime.json'
GODOT = ROOT.parent / 'SporeSpore_Evidence/qsdk-r24d157-godot-jolt-rotation-integration-energy-v6/development-cold-build-ed4ec00a/godot.windows.editor.dev.x86_64.exe'
METHODS = {'entry': 'recovery_r10k_entry_control_v1', 'step': 'recovery_partial_fall_step_control_v1'}

def read(path):
    return json.loads(Path(path).read_text(encoding='utf-8'))

def sha(path):
    return 'sha256:' + hashlib.sha256(Path(path).read_bytes()).hexdigest()

def resource(value):
    return ROOT / value.removeprefix('res://')


class R10KControlComponent(unittest.TestCase):
    profile_path = PROFILE
    @classmethod
    def setUpClass(cls):
        cls.profile = read(cls.profile_path)
        cls.binding = read(resource(cls.profile['runtime_binding']))
        if sha(resource(cls.profile['runtime_binding'])) != cls.profile['runtime_binding_sha256']:
            raise AssertionError('R10K_BINDING_DRIFT')
        cls.dll = Path(cls.binding['runtime']['path'])
        if sha(cls.dll) != cls.profile['runtime_sha256']:
            raise AssertionError('R10K_DLL_DRIFT')
        cls.core = LocomotionCore(cls.dll)
        cls.native = NativeApi(cls.dll)
        cls.old = LocomotionCore(read(OLD)['runtime']['path'])
        cls.evidence = Path(os.environ.get('SPORE_R10K_COMPONENT_ROOT', str(ROOT.parent / 'SporeSpore_Evidence' / ('development-r10k-control-native-' + uuid.uuid4().hex))))
        cls.evidence.mkdir(exist_ok=False)
        print('R10K_CONTROL_COMPONENT_EVIDENCE ' + str(cls.evidence), flush=True)
        cls.fixtures = [json.loads(line.removeprefix('R10K_CONTROL_FIXTURE '))
            for line in FIXTURES.read_text(encoding='utf-8').splitlines()
            if line.startswith('R10K_CONTROL_FIXTURE ')]
        if len(cls.fixtures) != 6:
            raise AssertionError('R10K_FIXTURE_POPULATION')
        cls.record('inputs.json', dict(profile=cls.profile, fixture_path=str(FIXTURES),
            fixture_sha256=sha(FIXTURES), dll_sha256=sha(cls.dll),
            world_build_count=0, solver_step_count=0))

    @classmethod
    def record(cls, name, value):
        with (cls.evidence / name).open('x', encoding='utf-8', newline='\n') as out:
            json.dump(value, out, indent=2, allow_nan=False)

    def call(self, kind, request):
        method = METHODS[kind]
        status, raw = self.native.raw('ss_' + method + '_json', self.core._input_bytes(request))
        return status, json.loads(raw), raw

    def test_compiled_fixtures_and_python_wrappers_match_every_phase_exactly(self):
        results = []
        for i, fixture in enumerate(self.fixtures):
            with self.subTest(case=i):
                original = copy.deepcopy(fixture['request'])
                actual = getattr(self.core, METHODS[fixture['kind']])(original)
                self.assertEqual(fixture['request'], original)
                self.assertEqual(fixture['expected'], actual)
                self.assertFalse(actual['canonical_supervisor_synthesized'])
                self.assertFalse(actual['original_observation_rewritten'])
                self.assertEqual((0, 0), (actual['world_build_count'], actual['solver_step_count']))
                self.assertFalse(actual['physical_acceptance_authority'] or actual['release_authority'])
                results.append(dict(case=i, kind=fixture['kind'], actual=actual))
        self.assertIsNone(results[-1]['actual']['next_control'])
        self.assertTrue(results[-1]['actual']['step']['partial_fall_standing_complete'])
        self.record('compiled-fixture-results.json', results)

    def corruptions(self):
        cases = []
        for kind in METHODS:
            base = next(f['request'] for f in self.fixtures if f['kind'] == kind)
            for defect in ('schema', 'unknown_field', 'source_hash', 'runtime', 'task', 'observation', 'energy'):
                request = copy.deepcopy(base)
                if defect == 'schema': request['schema_version'] = 'unregistered'
                elif defect == 'unknown_field': request['acceptance_override'] = True
                elif defect == 'source_hash': request['collection']['observation_source_binding']['portable_observation_sha256'] = 'sha256:' + '0' * 64
                elif defect == 'runtime': request['collection']['runtime_binding']['collector_id'] = 'unregistered'
                elif defect == 'task': request['collection']['task_id'] = 'unregistered'
                elif defect == 'observation': request['collection']['observation']['state']['base_pose_world']['position_m']['y'] += 0.001
                else:
                    source = request['entry']['passive_request'] if kind == 'entry' else request['step']
                    source['observation']['energy_balance']['cumulative_signed_external_work_j'] = 0.0
                cases.append(dict(id=kind + '_' + defect, kind=kind, request=request))
        return cases

    def test_native_negative_controls_refuse_before_any_plan(self):
        rows = []
        for case in self.corruptions():
            status, envelope, raw = self.call(case['kind'], case['request'])
            self.assertNotEqual(0, status, case['id'])
            self.assertFalse(envelope['ok'], case['id'])
            self.assertNotIn('value', envelope)
            with self.assertRaises(LocomotionCoreError):
                getattr(self.core, METHODS[case['kind']])(case['request'])
            rows.append(dict(case=case, status=status, response_utf8=raw.decode()))
        self.record('native-refusals.json', rows)

    def test_old_pinned_dll_still_loads_and_cannot_claim_the_new_interfaces(self):
        rows = []
        for kind, method in METHODS.items():
            request = next(f['request'] for f in self.fixtures if f['kind'] == kind)
            with self.assertRaises(LocomotionCoreError) as error:
                getattr(self.old, method)(request)
            self.assertIn('RUNTIME_UNAVAILABLE', str(error.exception))
            rows.append(dict(kind=kind, error=str(error.exception)))
        self.record('old-runtime-refusals.json', rows)

    def test_original_v20_and_v7_responses_are_byte_exact_against_the_old_dll(self):
        old_native = NativeApi(read(OLD)['runtime']['path'])
        rows = []
        for line in Path(self.binding['compiled_fixtures']['path']).read_text(encoding='utf-8').splitlines():
            if line.startswith('CANDIDATE_RECOVERY_CONTROL_FIXTURE '):
                method = 'ss_recovery_plan_control_v1_json'
            elif line.startswith('CANDIDATE_STANCE_CONTROL_FIXTURE '):
                method = 'ss_recovery_plan_stance_control_v4_json'
            else:
                continue
            fixture = json.loads(line.split(' ', 1)[1])
            data = self.core._input_bytes(fixture['request'])
            old_status, old_raw = old_native.raw(method, data)
            status, raw = self.native.raw(method, data)
            self.assertEqual(0, status)
            self.assertEqual((old_status, old_raw), (status, raw))
            self.assertEqual(fixture['expected'], json.loads(raw)['value'])
            rows.append(dict(method=method, request=fixture['request'], response_utf8=raw.decode()))
        self.assertEqual(12, len(rows))
        self.record('v20-v7-original-byte-parity.json', rows)

    def test_retained_passive_inputs_keep_original_results_and_select_prospective_branches(self):
        closure = read(ROOT / 'sdk/recovery/r10j_held_out_physical_closure_v1.json')
        bindings = {item['path']: item for item in closure['retained_evidence']['files']}
        population = [
            ('b0d292b597ab47789ba993ab6b55c536', 50641, 240, 'partial'),
            ('f9e43c7aa4e5483993e2da87b9b1244b', 50642, 240, 'partial'),
            ('57f6ce8d02664e2c963e22be3e3a364d', 50643, 117, 'prone'),
        ]
        summaries = []
        for attempt, seed, count, expected_branch in population:
            path = ROOT.parent / ('SporeSpore_Evidence/development-recovery-smoke-' + attempt
                + '/children/kick_passive_recovery_resume/worker_report.json')
            binding = bindings[path.as_posix()]
            self.assertEqual(binding['raw_sha256'], sha(path))
            report = read(path)
            self.assertEqual(seed, report['seed'])
            packets = report['passive_entry']['entry_packets']
            self.assertEqual(count, len(packets))
            prior = None
            rows = []
            for i, packet in enumerate(packets):
                original_raw = packet['entry_call']['request']['utf8_text'].encode()
                status, reproduced = self.native.raw('ss_recovery_passive_entry_step_v1_json', original_raw)
                self.assertEqual(0, status)
                self.assertEqual(packet['entry_call']['response']['utf8_text'].encode(), reproduced)
                original = json.loads(original_raw)
                prospective = copy.deepcopy(original)
                # A NEW supervisor invocation on exposed measurements. Source
                # observation and source binding remain byte-for-byte inputs;
                # only prospective profile/memory are selected before the call.
                prospective['declaration']['initialization']['threshold_profile_id'] = 'sporespore_r10k_exact_s169_prone_thresholds_v1'
                prospective['prior'] = None if prior is None else prior['passive_memory']
                collection = json.loads(packet['collection_call']['request']['utf8_text'])
                request = dict(schema_version='sporespore_r10k_entry_control_request_v1', collection=collection,
                    entry=dict(schema_version='sporespore_r10k_recovery_entry_request_v1', passive_request=prospective, prior=prior))
                self.assertEqual(original['observation'], prospective['observation'])
                result = self.core.recovery_r10k_entry_control_v1(request)
                entry = result['entry']
                prior = entry['memory']
                self.assertEqual('waiting' if i + 1 < count else expected_branch, prior['route'])
                self.assertEqual(original['observation']['energy_balance'],
                    entry['original_passive_receipt']['memory']['last_energy_ledger'])
                self.assertEqual(original['native_global_energy'],
                    entry['original_passive_receipt']['memory']['last_native_global_energy'])
                self.assertFalse(entry['energy_epoch_reset'] or result['original_observation_rewritten'])
                rows.append(dict(index=i + 1, request_sha256=result['request_sha256'],
                    original_response_reproduced_exactly=True, branch=prior['route']))
            if expected_branch == 'partial':
                self.assertEqual('descent_timeout', entry['original_passive_receipt']['memory']['status'])
                self.assertIsNone(entry['original_passive_receipt']['canonical_memory'])
                self.assertEqual('establish_distal_support', entry['partial_memory']['phase'])
                self.assertEqual(8, len(result['initial_partial_control']['ordered_commands']))
            else:
                self.assertIsNone(entry['partial_memory'])
                self.assertEqual('confirm_prone', entry['original_passive_receipt']['canonical_memory']['phase'])
            self.record('retained-passive-' + str(seed) + '.json', dict(source=binding, rows=rows,
                final_prospective_request=request, final_prospective_result=result,
                exposed_input_diagnostic_only=True, original_campaign_regraded=False,
                world_build_count=0, solver_step_count=0))
            summaries.append(dict(seed=seed, commands=count, selected_branch=prior['route']))
        self.record('retained-passive-summary.json', dict(cases=summaries,
            original_passive_responses_reproduced_exactly=sum(item['commands'] for item in summaries),
            world_build_count=0, solver_step_count=0, physical_acceptance_authority=False, release_authority=False))

    def test_actual_godot_exact_json_matches_native_successes_and_refusals(self):
        cases = [dict(id='compiled_' + str(i), kind=f['kind'], request=f['request'])
            for i, f in enumerate(self.fixtures)] + self.corruptions()
        for case in cases:
            status, envelope, raw = self.call(case['kind'], case['request'])
            case['method'] = METHODS[case['kind']] + '_json'
            case['expected_sha256'] = 'sha256:' + hashlib.sha256(self.native.canonical(envelope)).hexdigest()
            case['expected_native_response_utf8'] = raw.decode()
            case['expected_native_status'] = status
        self.record('godot-input.json', dict(cases=cases))
        args = [str(GODOT), '--headless', '--path', str(ROOT), '--script',
            'res://tests/test_development_r10k_control_component.gd', '--',
            'res://' + self.profile_path.relative_to(ROOT).as_posix(), str(self.evidence / 'godot-input.json'),
            str(self.evidence / 'godot-result.json')]
        with (self.evidence / 'godot.stdout.log').open('xb') as out, (self.evidence / 'godot.stderr.log').open('xb') as err:
            try:
                # Direct engine image: a timeout cannot leave a console-wrapper child.
                proc = subprocess.run(args, cwd=ROOT, stdout=out, stderr=err, timeout=120,
                    creationflags=subprocess.CREATE_NO_WINDOW)
            except subprocess.TimeoutExpired:
                self.record('godot-execution.json', dict(command=args, timed_out=True,
                    owned_direct_process_killed_and_reaped=True, world_build_count=0, solver_step_count=0))
                raise
        self.record('godot-execution.json', dict(command=args, exit_code=proc.returncode,
            world_build_count=0, solver_step_count=0))
        self.assertEqual(0, proc.returncode, (self.evidence / 'godot.stderr.log').read_text(encoding='utf-8'))
        result = read(self.evidence / 'godot-result.json')
        self.assertTrue(result['ok'])
        self.assertEqual(20, len(result['rows']))
        self.assertTrue(all(result['checks'].values()))


if __name__ == '__main__':
    unittest.main()
