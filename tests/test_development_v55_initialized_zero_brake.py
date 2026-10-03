"""V55 native semantics and finite exposed-input coverage; never new physics."""
import copy
import json
import os
from pathlib import Path
import sys
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path[:0] = [str(ROOT / 'sdk/python'), str(ROOT / 'sdk/conformance')]
import development_recovery_refusal as refusal
import r10n_zero_world_state_sweep as sweep
from sporespore_locomotion import LocomotionCoreError

POLICY = 'sporespore_balanced_wave_recovery_initialized_zero_brake_v1'
V54 = 'sporespore_balanced_wave_recovery_zero_velocity_brake_v1'
V53 = 'sporespore_balanced_wave_recovery_bounded_stop_velocity_v1'
MEMORY = 'sporespore_balanced_wave_recovery_initialized_zero_brake_memory_v1'
RECEIPT = 'sporespore_recovery_initialized_zero_brake_controller_step_receipt_v1'


def memory_schema(policy):
    return policy.removesuffix('_v1') + '_memory_v1'


def comparable(output):
    """Normalize only the three distinct policy identities and receipt digest."""
    value = copy.deepcopy(output)
    value['next_memory']['schema_version'] = '<policy_memory>'
    receipt = value['actuation']['receipt']
    receipt['schema_version'] = '<policy_receipt>'
    receipt['policy_id'] = '<policy>'
    value['actuation'].pop('receipt_sha256')
    return value


class InitializedZeroBrake(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.output = Path(os.environ['SPORE_V55_COMPONENT_ROOT'])
        cls.core = refusal.RecordedCore(os.environ['SPORE_V55_DLL'])
        design = sweep.failure.read(ROOT / 'sdk/recovery/r10n_zero_world_state_sweep_design_v1.json')
        cls.descriptor = refusal.integers(sweep.failure.read(sweep.verified(design['descriptor_source']))['configuration']['base_descriptor'])
        cls.populations = []
        for source in design['populations']:
            report = sweep.failure.read(sweep.verified(source['report']))
            failure = (report['detail']['portable_step_receipt']['development_native_step_failure']
                       if source['includes_terminal_refusal'] else None)
            cls.populations.append(dict(**source, rows=report['development_walking_entry']['rows'], failure=failure))
            del report

    def retain(self, name, value):
        with (self.output / name).open('x', encoding='utf-8', newline='\n') as stream:
            json.dump(value, stream, indent=2, allow_nan=False); stream.write('\n')

    def request(self, row, policy=POLICY, convert=True):
        q = refusal.integers(dict(copy.deepcopy(row['request']), descriptor=self.descriptor))
        q.update(schema_version='sporespore_balanced_wave_policy_step_request_v3', policy_id=policy)
        if convert:
            q['memory']['schema_version'] = memory_schema(policy)
        return q

    def call(self, q):
        output = self.core.balanced_wave_policy_step_with_measured_body(q['policy_id'], q)
        return self.core.raw_response, output

    def initial(self, phase=90):
        memory = self.core.balanced_wave_policy_initial_memory(POLICY, self.descriptor)
        for limb in memory['ordered_limb_memory']:
            limb['gait_step'] = phase
            limb['evidence_gait_step_limit'] = phase + 1440
        return memory

    def assert_refusal(self, q, out):
        self.assertTrue(out['actuation']['safe_no_actuation'])
        self.assertEqual(q['memory'], out['next_memory'])
        self.assertEqual(8, len(out['actuation']['ordered_commands']))
        self.assertTrue(all(c['target_velocity_rad_s'] == 0 for c in out['actuation']['ordered_commands']))

    def test_identity_and_original_profile_limits(self):
        old = self.core.balanced_wave_policy_profile(V54, self.descriptor)
        new = self.core.balanced_wave_policy_profile(POLICY, self.descriptor)
        self.assertEqual(POLICY, new['policy_id'])
        self.assertEqual('sporespore_balanced_wave_recovery_initialized_zero_brake_profile_v1', new['schema_version'])
        self.assertEqual({k:v for k,v in old.items() if k not in ['policy_id', 'schema_version']},
                         {k:v for k,v in new.items() if k not in ['policy_id', 'schema_version']})
        memory = self.core.balanced_wave_policy_initial_memory(POLICY, self.descriptor)
        self.assertEqual(MEMORY, memory['schema_version'])
        memory['schema_version'] = memory_schema(V53)
        self.assertEqual(self.core.balanced_wave_policy_initial_memory(V53, self.descriptor), memory)
        self.retain('identity.json', dict(profile=new, predecessor=old))

    def test_original_policies_and_refusals_remain_byte_exact(self):
        results = []
        for population in self.populations:
            hashes = []
            for row in population['rows']:
                policy = row['native_output']['actuation']['receipt']['policy_id']
                raw, _ = self.call(self.request(row, policy, False))
                self.assertEqual(row['raw_native_response_sha256'], refusal.digest(raw))
                hashes.append(refusal.digest(raw))
            if population['failure']:
                failed = population['failure']
                q = self.request(dict(request=json.loads(failed['request']['utf8_text'])), failed['expected_policy_id'], False)
                raw, out = self.call(q)
                self.assertEqual(failed['response']['raw_sha256'], refusal.digest(raw))
                self.assert_refusal(q, out); hashes.append(refusal.digest(raw))
            results.append(dict(id=population['id'], report=population['report'], response_hashes=hashes))
        self.assertEqual(4170, sum(len(p['response_hashes']) for p in results))
        self.retain('original-byte-compatibility.json', dict(populations=results))

    def test_r10m_native_chains_preserve_startup_and_change_only_later_holding(self):
        results = []
        for population in self.populations[2:4]:
            memory, hashes, startup, braking = self.initial(), [], [], []
            with self.core.create_balanced_wave_policy_session(POLICY, self.descriptor) as session:
                for row in population['rows']:
                    q = self.request(row); self.assertEqual(q['memory'], memory)
                    q['memory'] = memory
                    raw, out = self.call(q)
                    self.assertFalse(out['actuation']['safe_no_actuation'])
                    self.assertEqual(RECEIPT, out['actuation']['receipt']['schema_version'])
                    hashes.append(refusal.digest(raw))
                    self.assertEqual(out, session.step_with_measured_body({k:v for k,v in q.items() if k not in ['descriptor', 'policy_id']}))
                    zero = q['command']['gait_amplitude'] == 0
                    initialized = q['memory']['last_semantic_step'] is not None
                    reference = copy.deepcopy(q)
                    reference['policy_id'] = V54 if zero and initialized else V53
                    reference['memory']['schema_version'] = memory_schema(reference['policy_id'])
                    _, expected = self.call(reference)
                    self.assertEqual(comparable(expected), comparable(out))
                    pose = out['actuation']['receipt']['recovery_support_plane']['anchored_body_pose']
                    if zero and initialized:
                        self.assertIn('zero_amplitude_motor_brake', pose)
                        self.assertNotIn('zero_amplitude_velocity_guard', pose)
                        self.assertTrue(all(c['target_velocity_rad_s'] == 0 for c in out['actuation']['ordered_commands']))
                        braking.append(row['session_local_step'])
                    elif zero:
                        self.assertIn('zero_amplitude_velocity_guard', pose)
                        self.assertNotIn('zero_amplitude_motor_brake', pose)
                        self.assertTrue(all(abs(c['target_velocity_rad_s']) <= .25 for c in out['actuation']['ordered_commands']))
                        self.assertEqual(row['native_output']['actuation']['ordered_commands'], out['actuation']['ordered_commands'])
                        startup.append(row['session_local_step'])
                    memory = out['next_memory']
            self.assertEqual([1], startup); self.assertEqual(120, len(braking))
            results.append(dict(id=population['id'], response_hashes=hashes, initialized_feedback_commands=startup,
                later_brake_commands=braking, session_and_stateless_equal=True))
        self.retain('r10m-law-and-session.json', dict(populations=results))

    def test_current_memory_on_legacy_histories(self):
        results = []
        for population in self.populations[:2]:
            memory, hashes = self.initial(), []
            rows = population['rows'] + [dict(request=json.loads(population['failure']['request']['utf8_text']))]
            for row in rows:
                q = self.request(row); q['memory'] = memory
                raw, out = self.call(q)
                self.assertFalse(out['actuation']['safe_no_actuation'], out['actuation']['receipt'])
                hashes.append(refusal.digest(raw)); memory = out['next_memory']
            results.append(dict(id=population['id'], response_hashes=hashes, original_refusal_input_native_valid=True))
        self.assertEqual(1010, sum(len(p['response_hashes']) for p in results))
        self.retain('legacy-current-memory.json', dict(populations=results, physical_response_predicted=False))

    def test_r10n_exhausted_preparation_remains_a_safe_refusal(self):
        population = self.populations[-1]
        memory, hashes = self.initial(), []
        for row in population['rows']:
            q = self.request(row); self.assertEqual(q['memory'], memory)
            q['memory'] = memory
            raw, out = self.call(q)
            self.assertFalse(out['actuation']['safe_no_actuation'])
            hashes.append(refusal.digest(raw)); memory = out['next_memory']
        q = self.request(dict(request=json.loads(population['failure']['request']['utf8_text'])))
        self.assertEqual(q['memory'], memory); q['memory'] = memory
        raw, out = self.call(q); self.assert_refusal(q, out)
        self.assertEqual('FRAME_INVALID:measured_support_transfer_preparation_timeout', out['actuation']['receipt']['controller_error'])
        self.retain('unchanged-r10n-timeout.json', dict(valid_response_hashes=hashes, request=q,
            raw_response_utf8=raw.decode(), original_attempt_reclassified=False))

    def test_crossed_state_and_caller_override_refuse(self):
        base = self.request(self.populations[2]['rows'][1])
        controls = []
        for mutation in ['memory', 'clock', 'body_frame', 'caller_override']:
            q = copy.deepcopy(base)
            if mutation == 'memory': q['memory']['schema_version'] = memory_schema(V54)
            elif mutation == 'clock': q['state']['semantic_step'] += 1
            elif mutation == 'body_frame': q.pop('measured_body_frame')
            else: q['initial_hold_velocity_rad_s'] = .5
            try:
                raw, out = self.call(q)
            except LocomotionCoreError:
                raw = self.core.raw_response
                self.assertFalse(json.loads(raw)['ok'])
            else:
                self.assert_refusal(q, out)
            controls.append(dict(mutation=mutation, request=q, raw_response_utf8=raw.decode()))
        self.retain('crossed-packet-refusals.json', dict(controls=controls))

    def test_whole_startup_blend_over_360_gait_phases_and_five_exposed_states(self):
        populations = []
        for population in self.populations:
            cases = []
            for phase in range(360):
                memory, hashes, refused, out = self.initial(phase), [], None, None
                with self.core.create_balanced_wave_policy_session(POLICY, self.descriptor) as session:
                    for row in population['rows'][:73]:
                        q = self.request(row); q['memory'] = memory
                        out = session.step_with_measured_body({k:v for k,v in q.items() if k not in ['descriptor', 'policy_id']})
                        raw = self.core.raw_response
                        hashes.append(refusal.digest(raw))
                        if phase in [0, 90, 180, 270] and row['session_local_step'] in [1, 73]:
                            _, stateless = self.call(q); self.assertEqual(out, stateless)
                        if out['actuation']['safe_no_actuation']:
                            self.assert_refusal(q, out)
                            refused = dict(command=row['session_local_step'], error=out['actuation']['receipt']['controller_error'])
                            break
                        memory = out['next_memory']
                if refused is None:
                    self.assertEqual(73, len(hashes))
                    self.assertEqual(1.0, out['actuation']['receipt']['recovery_support_plane']['anchored_body_pose']['reference_velocity_startup_scale'])
                cases.append(dict(phase=phase, completed_calls=len(hashes), first_refusal=refused,
                    response_hashes=hashes, terminal_request=q, final_raw_response_utf8=raw.decode()))
                if (phase + 1) % 90 == 0:
                    print('V55_STARTUP_PROGRESS '+json.dumps(dict(population=population['id'], completed_cases=phase+1)), flush=True)
            populations.append(dict(id=population['id'], cases=cases))
        self.assertEqual(1800, sum(len(p['cases']) for p in populations))
        self.retain('startup-360-full-blend.json', dict(populations=populations,
            synthetic_measurements_reused=True, physical_prefix_phase_coverage=False, physical_response_predicted=False))


if __name__ == '__main__':
    unittest.main()
