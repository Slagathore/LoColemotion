"""Synthetic V24 interface probes derived from exposed R10AA loaded inputs.

The schema and controller identities are changed in copies, never in retained
evidence. This checks native planning and source admission, not new physics.
Run under the native-operation lock.
"""
import copy
import json
from pathlib import Path
import sys
import unittest
import uuid

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'sdk/conformance'))
import r10ab_native_component as native
import r10aa_first_support_closure as previous
import test_development_r10q_source_orchestration as shared


class R10ABLoadedSource(unittest.TestCase):
    run_godot = shared.R10QSourceOrchestration.run_godot

    @classmethod
    def setUpClass(cls):
        cls.out = native.EVIDENCE / ('r10ab-loaded-source-' + uuid.uuid4().hex)
        cls.out.mkdir()
        cls.before = native.entry._source_snapshot()
        native.write(cls.out / 'source_before.json', cls.before)
        print('R10AB_LOADED_SOURCE_ROOT ' + cls.out.as_posix(), flush=True)

    @classmethod
    def tearDownClass(cls):
        after = native.entry._source_snapshot()
        native.write(cls.out / 'source_after.json', after)
        assert cls.before == after

    def test_active_loaded_plans_reach_source_and_upward_proofs_refuse(self):
        runtime, _ = native.runtime()
        core = native.ExactInputCore(runtime['runtime']['path'])
        rows = []
        for kind, packet in previous.partial_records(previous.CHILD / 'worker_report.json'):
            if kind != 'packet' or (packet['native_receipt'].get('next_load_plan') or {}).get('mode') != 'loaded_geometry_rise':
                continue
            original = json.loads(packet['call']['request']['utf8_text'])
            request = copy.deepcopy(original)
            request['schema_version'] = 'sporespore_r10ab_partial_downward_rise_step_control_request_v1'
            for observation in (request['collection']['observation'], request['step']['observation']):
                observation['controller_ownership']['recovery_controller_id'] = 'sporespore_exact_s169_partial_downward_rise_controller_v24'
            # Rebuild the binding for this NEW synthetic observation. Retaining
            # the old binding after changing its owner must (and did) refuse.
            observation = request['collection']['observation']
            binding = request['collection']['observation_source_binding']
            base_fields = ('task_id', 'semantics_id', 'actuator_profile_id', 'semantic_step',
                'outer_step_duration_s', 'state', 'center_of_mass', 'ordered_foot_bearing_observations',
                'ordered_body_clearance_observations', 'applied_actuation', 'external_interventions',
                'controller_ownership', 'engine_step_identity')
            binding['observation_base_sha256'] = core.canonicalize_json({key: observation[key] for key in base_fields})['sha256']
            binding['portable_observation_sha256'] = core.canonicalize_json(observation)['sha256']
            binding['source_chain_sha256'] = core.canonicalize_json({key: value for key, value in binding.items() if key != 'source_chain_sha256'})['sha256']
            # Only synthetic identities and their binding digests change. The
            # geometry, loads, task memory, budgets and energy remain original.
            restored = copy.deepcopy(request)
            restored['schema_version'] = original['schema_version']
            restored['collection']['observation_source_binding'] = original['collection']['observation_source_binding']
            for group in ('collection', 'step'):
                restored[group]['observation']['controller_ownership'] = original[group]['observation']['controller_ownership']
            self.assertEqual(original, restored)
            result = core._call_json_input('ss_recovery_r10ab_partial_step_control_v1_json', request)
            self.assertEqual('loaded_downward_rise', result['next_load_plan']['mode'])
            self.assertIsNone(result['next_load_plan']['hold_reason'])
            self.assertGreater(result['next_load_plan']['virtual_translation_world_m'][1], 0)
            rows.append(dict(original_request_sha256=packet['call']['request']['raw_sha256'],
                original_partial_step=packet['native_receipt']['step']['memory']['total_steps_observed'],
                synthetic_input=True, request=request, expected=result,
                native_response_utf8=core.raw_response.decode('utf-8')))
        self.assertEqual(44, len(rows))
        path = self.out / 'fixtures.json'
        native.write(path, dict(schema_version='sporespore_r10ab_loaded_source_probes_v1',
            ledger_scope=dict(subsystem='recovery', engine_scope='godot_jolt',
                authority_mode='synthetic_native_interface_probe', question_class='development'),
            original_report=native.diagnosis.binding(previous.CHILD / 'worker_report.json'),
            runtime_binding=native.diagnosis.binding(native.BINDING),
            changed_fields=['request.schema_version', 'collection.observation.controller_ownership.recovery_controller_id',
                            'step.observation.controller_ownership.recovery_controller_id',
                            'collection.observation_source_binding.observation_base_sha256',
                            'collection.observation_source_binding.portable_observation_sha256',
                            'collection.observation_source_binding.source_chain_sha256'],
            fixtures=rows, world_build_count=0, solver_step_count=0,
            physical_acceptance_authority=False, release_authority=False))
        result = self.run_godot('loaded-source', 'test_r10ab_loaded_source.gd', path, 120)
        self.assertEqual(44, result['loaded_inputs'])
        self.assertEqual(352, result['negative_checks'])


if __name__ == '__main__':
    unittest.main()
