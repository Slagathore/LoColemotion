"""R10Q DLL startup coverage on exposed inputs; no physical trajectory claim.

Run under the locomotion operation lock. Inherit the complete V55 startup and
stop compatibility population, then enumerate V50 holding independently.
"""
import copy
import hashlib
import json
import os
from pathlib import Path
import unittest
import uuid

import test_development_v55_initialized_zero_brake as shared
from development_passive_entry_profile import _source_snapshot

ROOT = shared.ROOT
EVIDENCE = ROOT.parent / 'SporeSpore_Evidence'
RUNTIME = ROOT / 'sdk/development/recovery_candidates/r10q-upright-recovery-core-v1.runtime.json'
DLL_SHA = 'sha256:870f62740894b958d85df29cde27fa8a0bb6a5c68b7d40cc5693a26da76888da'
HOLD = 'sporespore_balanced_wave_recovery_startup_reference_velocity_v1'


def binding(path):
    path = Path(path)
    with path.open('rb') as stream:
        digest = 'sha256:' + hashlib.file_digest(stream, 'sha256').hexdigest()
    return dict(path=path.as_posix(), byte_length=path.stat().st_size, raw_sha256=digest)


def write(path, value):
    with Path(path).open('x', encoding='utf-8', newline='\n') as stream:
        json.dump(value, stream, indent=2, allow_nan=False)
        stream.write('\n')


class R10QStartupSweep(shared.InitializedZeroBrake):
    @classmethod
    def setUpClass(cls):
        cls.out = Path(os.environ.get('SPORE_R10Q_SWEEP_ROOT', str(EVIDENCE / ('r10q-startup-sweep-' + uuid.uuid4().hex))))
        cls.out.mkdir()
        print('R10Q_STARTUP_SWEEP_EVIDENCE ' + str(cls.out), flush=True)
        cls.before = _source_snapshot()
        write(cls.out / 'source_before.json', cls.before)
        runtime = json.loads(RUNTIME.read_bytes())
        assert runtime['runtime']['raw_sha256'] == DLL_SHA
        for item in [runtime['runtime'], *runtime['source_files']]:
            path = Path(item['path'])
            actual = binding(path if path.is_absolute() else ROOT / path)
            assert actual['raw_sha256'] == item['raw_sha256'], item['path']
        declaration = dict(schema_version='sporespore_r10q_startup_sweep_declaration_v1',
            ledger_scope=dict(subsystem='recovery', engine_scope='godot_jolt',
                authority_mode='finite_exposed_input_native_sweep', question_class='development'),
            runtime_binding=binding(RUNTIME), runtime=runtime['runtime'],
            source_files=[binding(Path(__file__)), binding(Path(shared.__file__)),
                binding(ROOT / 'sdk/conformance/development_recovery_refusal.py'),
                binding(ROOT / 'sdk/conformance/r10n_zero_world_state_sweep.py')],
            population_design=binding(shared.sweep.DESIGN), startup_gait_phases=list(range(360)),
            walking_policy=shared.POLICY, walking_startup_commands=73,
            walking_compatibility_and_stop_checks='All seven inherited V55 tests, including both retained 120-command stopping tails.',
            hold_policy=HOLD, hold_commands=240, hold_amplitude=0.0,
            hold_desired_planar_velocity_task_m_s=dict(x=0.0, y=0.0, z=0.0),
            fresh_native_memory_and_session_per_phase=True,
            source_measurement_population_count=5, maximum_phase_sweep_calls=360*5*(73+240),
            retained_inputs='First 73 or 240 consecutive walking measurement packets from each hash-bound exposed population; copy requests and replace controller memory and policy prospectively.',
            terminal_refusal_rule='Retain typed native rejection or safe no-actuation, stop only that synthetic session, and continue enumerating the declared phases. Never treat a refusal as a positive physical result.',
            session_stateless_check_phases=[0, 90, 180, 270],
            world_build_count=0, solver_step_count=0, physical_prefix_phase_coverage=False,
            physical_response_predicted=False, original_results_regraded=False,
            physical_acceptance_authority=False, release_authority=False)
        write(cls.out / 'declaration.json', declaration)
        os.environ['SPORE_V55_COMPONENT_ROOT'] = str(cls.out)
        os.environ['SPORE_V55_DLL'] = runtime['runtime']['path']
        try:
            super().setUpClass()
            assert len(cls.populations) == 5 and all(len(p['rows']) >= 240 for p in cls.populations)
        except BaseException:
            write(cls.out / 'setup_source_after.json', _source_snapshot())
            raise

    @classmethod
    def tearDownClass(cls):
        after = _source_snapshot()
        write(cls.out / 'source_after.json', after)
        if cls.before != after:
            raise AssertionError('R10Q_STARTUP_SWEEP_SOURCE_DRIFT')

    def test_v50_hold_full_budget_over_360_phases_and_five_exposed_states(self):
        populations = []
        for population in self.populations:
            cases = []
            for phase in range(360):
                memory = self.core.balanced_wave_policy_initial_memory(HOLD, self.descriptor)
                for limb in memory['ordered_limb_memory']:
                    limb['gait_step'] = phase
                    limb['evidence_gait_step_limit'] = phase + 1440
                hashes, refused, out = [], None, None
                with self.core.create_balanced_wave_policy_session(HOLD, self.descriptor) as session:
                    for row in population['rows'][:240]:
                        q = self.request(row, HOLD)
                        q['memory'] = memory
                        # This is the adapter's stationary-hold input contract,
                        # including zero desired velocity on the first command.
                        q['command']['gait_amplitude'] = 0.0
                        q['command']['desired_planar_velocity_task_m_s'] = dict(x=0.0, y=0.0, z=0.0)
                        try:
                            out = session.step_with_measured_body({k: v for k, v in q.items() if k not in ['descriptor', 'policy_id']})
                        except shared.LocomotionCoreError:
                            raw = self.core.raw_response
                            refusal = json.loads(raw)
                            self.assertIsInstance(refusal.get('failure_code'), str)
                            refused = dict(command=row['session_local_step'], kind='abi_rejection', error=refusal['failure_code'])
                            hashes.append(shared.refusal.digest(raw))
                            break
                        raw = self.core.raw_response
                        hashes.append(shared.refusal.digest(raw))
                        if phase in [0, 90, 180, 270] and row['session_local_step'] in [1, 240]:
                            stateless_raw, stateless = self.call(q)
                            self.assertEqual(raw, stateless_raw)
                            self.assertEqual(out, stateless)
                        if out['actuation']['safe_no_actuation']:
                            self.assert_refusal(q, out)
                            refused = dict(command=row['session_local_step'], kind='controller_refusal',
                                error=out['actuation']['receipt']['controller_error'])
                            break
                        memory = out['next_memory']
                if refused is None:
                    self.assertEqual(240, len(hashes))
                cases.append(dict(phase=phase, completed_calls=len(hashes), first_refusal=refused,
                    response_hashes=hashes, terminal_request=q, final_raw_response_utf8=raw.decode()))
                if (phase + 1) % 90 == 0:
                    print('R10Q_V50_HOLD_PROGRESS ' + json.dumps(dict(population=population['id'], completed_cases=phase+1)), flush=True)
            item = dict(id=population['id'], cases=cases)
            self.retain('v50-hold-' + population['id'] + '.json', item)
            populations.append(dict(id=population['id'], case_count=len(cases),
                completed_calls=sum(c['completed_calls'] for c in cases),
                refused_cases=sum(c['first_refusal'] is not None for c in cases)))
        self.assertEqual(1800, sum(p['case_count'] for p in populations))
        self.retain('v50-hold-360-summary.json', dict(populations=populations,
            synthetic_measurements_reused=True, physical_prefix_phase_coverage=False,
            physical_response_predicted=False, world_build_count=0, solver_step_count=0))


if __name__ == '__main__':
    unittest.main()
