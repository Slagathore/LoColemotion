"""Retained V31 diagnosis and the actual V32 DLL's exported, zero-world API."""
import copy
import ctypes
import json
from pathlib import Path
import sys
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'sdk/conformance'))
import development_recovery_candidate as candidate
import development_recovery_v31_recontact_diagnosis as diagnosis

NEW_POLICY = 'sporespore_balanced_wave_recovery_swing_end_recontact_v1'
OLD_POLICY = 'sporespore_balanced_wave_bw5r_b_v1'
PROFILE = ROOT / 'sdk/development/recovery_candidates/v32-swing-end-recontact-v1.json'


class NativeApi:
    def __init__(self, path):
        self.library = ctypes.CDLL(str(path))

    def raw(self, name, data):
        function = getattr(self.library, name)
        function.argtypes = [ctypes.c_void_p, ctypes.c_size_t, ctypes.c_void_p, ctypes.c_size_t, ctypes.POINTER(ctypes.c_size_t)]
        function.restype = ctypes.c_int
        required = ctypes.c_size_t()
        function(data, len(data), None, 0, ctypes.byref(required))
        if not 0 < required.value < 2_000_000:
            raise ValueError('COMPONENT_NATIVE_BUFFER_SIZE')
        output = ctypes.create_string_buffer(required.value)
        status = function(data, len(data), output, required.value, ctypes.byref(required))
        return status, output.raw[:required.value]

    def call(self, name, value):
        status, raw = self.raw(name, json.dumps(value, separators=(',', ':'), allow_nan=False).encode())
        return status, json.loads(raw)

    def canonical(self, value):
        status, envelope = self.call('ss_canonicalize_json', dict(schema_version='sporespore_canonical_json_request_v1', value=value))
        if status != 0 or envelope.get('ok') is not True:
            raise ValueError('COMPONENT_CANONICALIZATION_FAILED')
        return envelope['value']['canonical_json'].encode()


class V32Component(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.record_path = ROOT / 'sdk/development/recovery_attempts/72f7accb15c44d68a7ba817a61b3ac08.json'
        cls.record = candidate.read(cls.record_path)
        cls.report_path = Path(cls.record['kicked_report']['path'])
        if candidate.sha(cls.report_path) != cls.record['kicked_report']['raw_sha256']:
            raise AssertionError('V31_REPORT_DRIFT')
        cls.report = candidate.read(cls.report_path)
        cls.summary = diagnosis.summarize(cls.report, cls.record['source_snapshot']['head'])
        cls.profile = candidate.read(PROFILE)
        cls.binding = candidate.read(candidate.resource_path(cls.profile['runtime_binding']))
        cls.old_binding = candidate.read(ROOT / 'sdk/development/recovery_candidates/v28-first-swing-walking-warmup-v1.runtime.json')
        for binding in (cls.binding, cls.old_binding):
            for image in (Path(binding['runtime']['path']), ROOT / binding['local_build_path']):
                if candidate.sha(image) != binding['runtime']['raw_sha256']:
                    raise AssertionError('COMPONENT_DLL_DRIFT')
        cls.new = NativeApi(cls.binding['runtime']['path'])
        cls.old = NativeApi(cls.old_binding['runtime']['path'])
        cls.descriptor = cls.report['configuration']['base_descriptor']

    def test_retained_geometry_distinguishes_pose_from_joint_tracking(self):
        self.assertEqual('sha256:638c375a87053ee104c53e7d4336d76d885267107a5406070c654c1978841b64', candidate.sha(self.record_path))
        self.assertEqual('sha256:25b413f0502031853d17c156e0b5e3c9ae0312cdc5355ef7637bbbc4fa150282', self.summary['frozen_runtime_source_sha256'])
        self.assertEqual(1600, self.summary['measured_body_sample_count'])
        rows = {r['trace_local_step']: r for r in self.summary['front_left_vertical_decomposition']}
        fields = ('torso_height_change_m', 'orientation_at_initial_joints_change_m', 'joint_change_at_current_pose_m', 'ideal_constraint_residual_change_m')
        for row in rows.values():
            self.assertAlmostEqual(row['nominal_bottom_m']-rows[0]['nominal_bottom_m'], sum(row[k] for k in fields), places=14)
        sample = rows[200]
        self.assertEqual(0, sample['measured_knee_rad'])
        self.assertAlmostEqual(.04878963633803679, sample['nominal_bottom_m'], places=14)
        self.assertAlmostEqual(.04550618981468142, sample['orientation_at_initial_joints_change_m'], places=14)
        self.assertAlmostEqual(.0397704813349376, sample['relaxed_fixed_torso_minimum_bottom_m'], places=14)
        self.assertEqual((251, 0), tuple(self.summary['front_left_long_raw_gap'][k] for k in ('sample_count', 'raw_contact_sample_count')))
        for key in ('physical_outcome_predicted', 'causal_attribution_proven', 'old_evaluation_changed', 'physical_acceptance_authority', 'release_authority'):
            self.assertFalse(self.summary[key])
        print('V32_RETAINED_MECHANISM_DIAGNOSIS', json.dumps(self.summary, separators=(',', ':')), flush=True)

    def test_source_derived_sequence_and_contact_driven_command_switches(self):
        events = self.summary['sequence_boundaries']
        self.assertEqual([75, 91, 148], [events[k]['local_step'] for k in ('front_left_swing_end', 'rear_right_next_swing_start', 'front_left_first_recontact_hold')])
        self.assertTrue(all(e['prior_measured_support']['front_left'] is False for e in events.values()))
        held = self.summary['rear_right_phase_66']
        self.assertEqual((159, 268, 110, 52, 37), tuple(held[k] for k in ('first_local_step', 'last_local_step', 'sample_count', 'support_count', 'contact_switch_count')))
        self.assertEqual([.2226407971086264, .4624228134574003], held['requested_knee_values_rad'])
        self.assertAlmostEqual(held['target_jump_rad'], held['existing_contact_assist_at_selected_amplitude_rad'], places=14)
        self.assertEqual((84, 90), (self.summary['proposed_swing_end_plus_existing_skew'], self.summary['following_swing_offset']))
        self.assertEqual(120, self.summary['scheduler_constants']['MAXIMUM_GATE_HOLD_STEPS'])
        self.assertEqual(3, self.summary['scheduler_constants']['MINIMUM_GATE_DWELL_STEPS'])

    def test_actual_exported_old_policy_preserves_all_400_retained_command_inputs(self):
        for entry in self.report['development_walking_entry']['rows']:
            request = dict(entry['request'], schema_version='sporespore_balanced_wave_policy_step_request_v1', policy_id=OLD_POLICY, descriptor=self.descriptor)
            # The existing native canonicalizer projects JSON count syntax.
            # Retained files and measured values are never rewritten.
            encoded = self.old.canonical(request)
            old_status, old_raw = self.old.raw('ss_balanced_wave_policy_step_json', encoded)
            new_status, new_raw = self.new.raw('ss_balanced_wave_policy_step_json', encoded)
            self.assertEqual((0, 0), (old_status, new_status))
            self.assertEqual(old_raw, new_raw)
            self.assertFalse(json.loads(new_raw)['value']['actuation']['safe_no_actuation'])
        def fixtures(binding):
            path = Path(binding['compiled_fixtures']['path'])
            self.assertEqual(binding['compiled_fixtures']['raw_sha256'], candidate.sha(path))
            return [line for line in path.read_text().splitlines() if line.startswith('CANDIDATE_RECOVERY_CONTROL_FIXTURE ')]
        previous, current = fixtures(self.old_binding), fixtures(self.binding)
        self.assertEqual(6, len(previous))
        self.assertEqual(previous, current)
        print('V32_EXPORTED_LEGACY_COMPATIBILITY', json.dumps(dict(retained_input_count=400, exact_native_output_matches=400, exact_recovery_fixture_matches=6, world_build_count=0, solver_step_count=0)), flush=True)

    def test_exported_new_policy_holds_and_component_profile_refuses_physical_selection(self):
        profile_request = dict(schema_version='sporespore_balanced_wave_policy_profile_request_v1', descriptor=self.descriptor, policy_id=NEW_POLICY)
        status, profile = self.new.call('ss_balanced_wave_policy_profile_json', profile_request)
        self.assertEqual(0, status)
        self.assertEqual('scheduled_swing_end_recontact_v1', profile['value']['recontact_gate_mode_id'])
        self.assertFalse(profile['value']['physical_acceptance_authority'])
        original = self.report['development_walking_entry']['rows'][75]['request']
        request = dict(original, schema_version='sporespore_balanced_wave_policy_step_request_v1', policy_id=NEW_POLICY, descriptor=self.descriptor)
        status, raw = self.new.raw('ss_balanced_wave_policy_step_json', self.new.canonical(request))
        value = json.loads(raw)['value']
        self.assertEqual(0, status)
        self.assertFalse(value['actuation']['safe_no_actuation'])
        limb = next(m for m in value['next_memory']['ordered_limb_memory'] if m['limb_id'] == 'front_left')
        self.assertEqual((162, 1, 0), tuple(limb[k] for k in ('gait_step', 'recontact_hold_step_count', 'gate_timeout_count')))
        unknown = dict(profile_request, policy_id='unregistered_recontact_policy')
        status, refused = self.new.call('ss_balanced_wave_policy_profile_json', unknown)
        self.assertNotEqual(0, status)
        self.assertFalse(refused['ok'])
        bad = copy.deepcopy(request)
        bad['state']['ordered_contact_observations'][0]['bears_support'] = None
        status, raw = self.new.raw('ss_balanced_wave_policy_step_json', self.new.canonical(bad))
        self.assertTrue(json.loads(raw)['value']['actuation']['safe_no_actuation'])
        with self.assertRaisesRegex(ValueError, 'PROFILE_SCHEMA'):
            candidate.selection(candidate.reference_for_path(PROFILE))
        self.assertEqual(self.profile['runtime_binding_sha256'], candidate.sha(candidate.resource_path(self.profile['runtime_binding'])))
        for source in self.binding['source_files']:
            self.assertEqual(source['raw_sha256'], candidate.sha(ROOT / source['path']))
        print('V32_EXPORTED_NEW_POLICY_COMPONENT', json.dumps(dict(policy_id=NEW_POLICY, probe_local_step=76, front_left_clock=162, recontact_holds=1, physical_selection_refused=True, predicted_native_outcome=False)), flush=True)


if __name__ == '__main__':
    unittest.main()
