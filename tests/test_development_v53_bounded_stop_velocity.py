"""V53 over exposed R10L measurements; copied inputs are not new physics."""
import copy
import hashlib
import json
import os
from pathlib import Path
import sys
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path[:0] = [str(ROOT / 'sdk/python'), str(ROOT / 'sdk/conformance')]
from sporespore_locomotion import LocomotionCore
import development_recovery_refusal as refusal
import r10k_development_failure as failure
from test_development_v32_recontact_component import NativeApi
from v52_extended_support_transfer import read, verify

POLICY = 'sporespore_balanced_wave_recovery_bounded_stop_velocity_v1'
MEMORY = 'sporespore_balanced_wave_recovery_bounded_stop_velocity_memory_v1'
PARENT = 'sporespore_balanced_wave_recovery_extended_support_transfer_v1'
PARENT_MEMORY = 'sporespore_balanced_wave_recovery_extended_support_transfer_memory_v1'
RECEIPT = 'sporespore_recovery_bounded_stop_velocity_controller_step_receipt_v1'
OLD_RECEIPT = 'sporespore_recovery_extended_support_transfer_controller_step_receipt_v1'


class BoundedStopVelocity(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.output = Path(os.environ['SPORE_V53_COMPONENT_ROOT'])
        cls.dll = Path(os.environ['SPORE_V53_DLL'])
        cls.core = LocomotionCore(cls.dll)
        cls.native = NativeApi(cls.dll)
        design = read(ROOT / 'sdk/recovery/r10m_bounded_stop_velocity_successor_design_v1.json')
        diagnosis = read(verify(design['bound_evidence'][1]))
        cls.populations = {}
        for source in diagnosis['reports']:
            report = read(verify(source))
            role = Path(source['path']).parent.name
            cls.populations[role] = dict(source=source,
                descriptor=refusal.integers(report['configuration']['base_descriptor']),
                rows=report['development_walking_entry']['rows'],
                cycle_end=report['development_cycle_stop']['final_memory']['cycle_end_command'])
        cls.kicked = cls.populations['kick_passive_recovery_resume']

    def retain(self, name, value):
        with (self.output / name).open('x', encoding='utf-8', newline='\n') as stream:
            json.dump(value, stream, indent=2, allow_nan=False)
            stream.write('\n')

    def request(self, row, population, successor=True):
        q = refusal.integers(dict(copy.deepcopy(row['request']), descriptor=population['descriptor']))
        q.update(schema_version='sporespore_balanced_wave_policy_step_request_v3',
                 policy_id=POLICY if successor else PARENT)
        if successor:
            q['memory']['schema_version'] = MEMORY
        return q

    def call(self, q):
        status, raw = self.native.raw('ss_balanced_wave_policy_step_json', self.core._input_bytes(q))
        self.assertEqual(0, status, raw)
        return raw, json.loads(raw)['value']

    def assert_refusal(self, q, out):
        self.assertTrue(out['actuation']['safe_no_actuation'])
        self.assertEqual(q['memory'], out['next_memory'])
        self.assertTrue(all(c['target_velocity_rad_s'] == 0 for c in out['actuation']['ordered_commands']))
        self.assertIsNone(out['actuation']['receipt'].get('recovery_support_plane'))

    def test_distinct_identity_preserves_parent_profile(self):
        descriptor = self.kicked['descriptor']
        parent = self.core.balanced_wave_policy_profile(PARENT, descriptor)
        profile = self.core.balanced_wave_policy_profile(POLICY, descriptor)
        self.assertEqual(POLICY, profile['policy_id'])
        self.assertEqual('sporespore_balanced_wave_recovery_bounded_stop_velocity_profile_v1', profile['schema_version'])
        self.assertEqual({k:v for k,v in parent.items() if k not in ('policy_id','schema_version')},
                         {k:v for k,v in profile.items() if k not in ('policy_id','schema_version')})
        initial = self.core.balanced_wave_policy_initial_memory(POLICY, descriptor)
        old = self.core.balanced_wave_policy_initial_memory(PARENT, descriptor)
        self.assertEqual(MEMORY, initial['schema_version'])
        initial['schema_version'] = PARENT_MEMORY
        self.assertEqual(old, initial)
        self.retain('policy-identity.json', dict(profile=profile, parent=parent))

    def test_all_2289_original_v52_outputs_remain_byte_exact(self):
        populations = []
        for role, population in self.populations.items():
            hashes = []
            for row in population['rows']:
                raw, out = self.call(self.request(row, population, False))
                digest = refusal.digest(raw)
                self.assertEqual(row['raw_native_response_sha256'], digest)
                pose = out['actuation']['receipt']['recovery_support_plane']['anchored_body_pose']
                self.assertNotIn('zero_amplitude_velocity_guard', pose)
                hashes.append(digest)
            populations.append(dict(role=role, source=population['source'], commands=len(hashes), response_hashes=hashes))
        self.assertEqual(2289, sum(p['commands'] for p in populations))
        self.retain('v52-byte-compatibility.json', dict(populations=populations,
            world_build_count=0, solver_step_count=0, original_attempt_reclassified=False))

    def test_full_chains_and_sessions_only_apply_declared_hold_cap(self):
        populations = []
        for role, population in self.populations.items():
            memory = self.core.balanced_wave_policy_initial_memory(POLICY, population['descriptor'])
            for limb in memory['ordered_limb_memory']:
                limb['gait_step'] = 90
                limb['evidence_gait_step_limit'] = 1530
            changed, startup_clipped, hashes, hold_steps = [], [], [], []
            with self.core.create_balanced_wave_policy_session(POLICY, population['descriptor']) as session:
                for row in population['rows']:
                    q = self.request(row, population)
                    # Recomputed successor memory must preserve all parent memory arithmetic.
                    self.assertEqual(q['memory'], memory)
                    q['memory'] = memory
                    raw, out = self.call(q)
                    self.assertFalse(out['actuation']['safe_no_actuation'], out['actuation']['receipt'])
                    actual = session.step_with_measured_body({k:v for k,v in q.items() if k not in ('descriptor','policy_id')})
                    self.assertEqual(out, actual)
                    receipt = out['actuation']['receipt']
                    self.assertEqual(POLICY, receipt['policy_id'])
                    self.assertEqual(RECEIPT, receipt['schema_version'])
                    self.assertEqual(refusal.digest(self.native.canonical(receipt)), out['actuation']['receipt_sha256'])
                    pose = receipt['recovery_support_plane']['anchored_body_pose']
                    guard = pose.get('zero_amplitude_velocity_guard')
                    original = row['native_output']
                    original_commands = original['actuation']['ordered_commands']
                    commands = out['actuation']['ordered_commands']
                    hold = q['command']['gait_amplitude'] == 0
                    any_clipped = False
                    if hold:
                        hold_steps.append(row['session_local_step'])
                        self.assertEqual('sporespore_bounded_zero_amplitude_velocity_receipt_v1', guard['schema_version'])
                        self.assertEqual(.25, guard['maximum_absolute_velocity_rad_s'])
                        self.assertFalse(guard['physical_acceptance_authority'])
                        self.assertEqual(8, len(guard['ordered_commands']))
                    else:
                        self.assertIsNone(guard)
                    for i, (old, command) in enumerate(zip(original_commands, commands)):
                        expected = copy.deepcopy(old)
                        limit = min(.25, old['maximum_target_speed_rad_s'])
                        velocity = max(-limit, min(limit, old['target_velocity_rad_s'])) if hold else old['target_velocity_rad_s']
                        clipped = velocity != old['target_velocity_rad_s']
                        if clipped:
                            expected['target_velocity_rad_s'] = velocity
                            expected['safety_contribution_rad_s'] += velocity - old['target_velocity_rad_s']
                            expected['velocity_saturated'] = True
                            any_clipped = True
                        self.assertEqual(expected, command)
                        if hold:
                            self.assertEqual(dict(actuator_id=old['actuator_id'], effective_limit_rad_s=limit,
                                original_velocity_rad_s=old['target_velocity_rad_s'], bounded_velocity_rad_s=velocity,
                                clipped=clipped), guard['ordered_commands'][i])
                    # Compare the complete output, allowing only the declared identities,
                    # receipt hash, additive guard, and three specified command fields.
                    normalized = copy.deepcopy(out)
                    normalized['next_memory']['schema_version'] = PARENT_MEMORY
                    normalized_receipt = normalized['actuation']['receipt']
                    normalized_receipt['policy_id'] = PARENT
                    normalized_receipt['schema_version'] = OLD_RECEIPT
                    normalized_receipt['recovery_support_plane']['anchored_body_pose'].pop('zero_amplitude_velocity_guard', None)
                    normalized['actuation']['receipt_sha256'] = original['actuation']['receipt_sha256']
                    normalized['actuation']['ordered_commands'] = original_commands
                    self.assertEqual(original, normalized)
                    if any_clipped:
                        stop_command = row['session_local_step'] - population['cycle_end']
                        if row['development_cycle_stopping']:
                            changed.append(stop_command)
                            name = f'{role}-stop-{stop_command}.json'
                        else:
                            startup_clipped.append(row['session_local_step'])
                            name = f'{role}-startup-{row["session_local_step"]}.json'
                        self.retain(name, dict(request=q,
                            original_output=original, raw_response_utf8=raw.decode(), raw_response_sha256=refusal.digest(raw)))
                    hashes.append(refusal.digest(raw))
                    memory = out['next_memory']
            # The fresh session's first command also has zero amplitude. It is
            # covered by the cap by design, before the 120-command final stop.
            self.assertEqual([1] + list(range(population['cycle_end'] + 1, len(population['rows']) + 1)), hold_steps)
            self.assertEqual(121, len(hold_steps))
            self.assertEqual([94,95,96] if role == 'kick_passive_recovery_resume' else [], changed)
            self.assertEqual([] if role == 'kick_passive_recovery_resume' else [1], startup_clipped)
            populations.append(dict(role=role, source=population['source'], commands=len(hashes),
                zero_amplitude_commands=len(hold_steps), hold_steps=hold_steps,
                stop_commands=120, clipped_stopping_commands=changed, response_hashes=hashes,
                clipped_startup_commands=startup_clipped,
                stateless_session_equal=True, final_memory=memory))
        self.retain('copied-input-chains.json', dict(populations=populations, world_build_count=0,
            solver_step_count=0, changed_measurements_simulated=False, physical_acceptance_authority=False, release_authority=False))

    def test_crossed_memory_clock_and_geometry_refuse_without_actuation(self):
        controls = []
        for mutation in ('parent_memory','bias_low','bias_high','clock','height','geometry'):
            # Nonzero walking uses the anchor geometry; zero-amplitude stopping
            # intentionally holds the previously computed endpoint instead.
            row = self.kicked['rows'][800] if mutation == 'geometry' else self.kicked['rows'][-26]
            q = self.request(row, self.kicked)
            if mutation == 'parent_memory': q['memory']['schema_version'] = PARENT_MEMORY
            if mutation == 'bias_low': q['memory']['measured_support_transfer']['hip_bias_rad'] = -.300001
            if mutation == 'bias_high': q['memory']['measured_support_transfer']['hip_bias_rad'] = .300001
            if mutation == 'clock': q['measured_body_frame']['semantic_step'] += 1
            if mutation == 'height': q['memory']['anchored_body_pose']['height_correction_m'] = -.020001
            if mutation == 'geometry': q['memory']['anchored_body_pose']['ordered_feet'][0]['anchor_world_m']['x'] += 1
            raw, out = self.call(q)
            self.assert_refusal(q, out)
            controls.append(dict(mutation=mutation, request=q, raw_response_utf8=raw.decode()))
        self.retain('negative-controls.json', dict(controls=controls))

    def test_nonfinite_and_caller_override_packets_are_rejected(self):
        controls = []
        for mutation in ('nan_velocity','infinite_velocity','caller_override'):
            q = self.request(self.kicked['rows'][-26], self.kicked)
            if mutation == 'caller_override': q['maximum_hold_velocity_rad_s'] = 10.0
            else:
                q['state']['ordered_joint_observations'][0]['velocity_rad_s'] = float('nan' if mutation == 'nan_velocity' else 'inf')
            packet = json.dumps(q, separators=(',', ':'), allow_nan=True).encode()
            status, raw = self.native.raw('ss_balanced_wave_policy_step_json', packet)
            envelope = json.loads(raw)
            self.assertNotEqual(0, status)
            self.assertFalse(envelope['ok'])
            self.assertNotIn('value', envelope)
            controls.append(dict(mutation=mutation, request_utf8=packet.decode(), native_status=status,
                raw_response_utf8=raw.decode()))
        self.retain('packet-refusals.json', dict(controls=controls))

    def test_exhausted_preparation_deadline_is_preserved(self):
        closure = read(failure.RECORD)
        report = read(verify(closure['report']))
        descriptor = refusal.integers(read(verify(closure['descriptor_source']))['configuration']['base_descriptor'])
        failed = report['detail']['portable_step_receipt']['development_native_step_failure']
        request = failure.packet.parse_json(failed['request']['utf8_text'])
        q = self.request(dict(request=request), dict(descriptor=descriptor))
        self.assertEqual(240, q['memory']['measured_support_transfer']['preparation_commands'])
        raw, out = self.call(q)
        self.assert_refusal(q, out)
        self.assertEqual('FRAME_INVALID:measured_support_transfer_preparation_timeout', out['actuation']['receipt']['controller_error'])
        self.retain('unchanged-deadline.json', dict(request=q, raw_response_utf8=raw.decode(),
            raw_response_sha256=refusal.digest(raw), original_attempt_reclassified=False))


if __name__ == '__main__':
    unittest.main()
