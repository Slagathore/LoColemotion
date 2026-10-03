"""Actual floor constructor, adapter and cold reader; no native physics worlds."""
import copy
import hashlib
import json
import struct
import subprocess
import unittest
import uuid

from development_recovery_candidate_test_support import candidate, ROOT
import test_development_passive_entry_replay as shared

POLICY = 'sporespore_balanced_wave_recovery_floor_support_v1'


class FloorAdapter(unittest.TestCase):
    # Subclasses select data; constructor, motor ledger and corruption tests stay shared.
    policy_id = POLICY
    candidate_id = 'v34-floor-support-v1'
    fixture = 'res://tests/test_development_v34_floor_adapter.gd'
    run_label = 'V34'
    _run_retained = classmethod(shared.PassiveEntryReplay._run_retained.__func__)

    @classmethod
    def setUpClass(cls):
        cls.root = shared.entry.EVIDENCE / ('development-' + cls.run_label.lower() + '-floor-adapter-' + uuid.uuid4().hex)
        cls.root.mkdir()
        print(cls.run_label + '_FLOOR_ADAPTER_ROOT', cls.root, flush=True)
        run = cls._run_retained(cls.fixture, [], 'producer', 90)
        rows = [line for line in run.stdout.decode(errors='replace').splitlines() if line.startswith('V34_FLOOR_PRODUCER ')]
        if len(rows) != 1:
            raise AssertionError(dict(returncode=run.returncode, stderr=run.stderr.decode(errors='replace')[-7000:]))
        cls.producer = json.loads(rows[0].removeprefix('V34_FLOOR_PRODUCER '))
        if not cls.producer['ok']:
            raise AssertionError(dict(checks=cls.producer['checks'], adapter=cls.producer['result'].get('adapter_start'),
                ledger=cls.producer['result'].get('floor_fixture', {}).get('failure_code'),
                ledger_detail=cls.producer['result'].get('floor_fixture', {}).get('detail')))
        if b'ERROR:' in run.stdout + run.stderr or run.returncode:
            raise AssertionError(dict(returncode=run.returncode, stderr=run.stderr.decode(errors='replace')[-7000:]))
        cases = {'positive': dict(report=cls.producer['result']['report'], policy_id=cls.policy_id)}
        for name in ('legacy_selection', 'missing_source', 'wrong_model', 'crossed_instance', 'wrong_frame',
                     'rehashed_plane', 'rehashed_extent', 'changed_parent', 'missing_chain',
                     'context_height', 'v1_request', 'outside_extent', 'source_changed', 'memory_chain'):
            item = copy.deepcopy(cases['positive'])
            arm = item['report']['retained_arm']
            rows = item['report']['development_walking_entry']['rows']
            source = rows[0]['development_floor_source']
            geometry = source['geometry']
            request = rows[0]['request']
            if name == 'legacy_selection':
                item['policy_id'] = ''
            elif name == 'missing_source':
                del rows[0]['development_floor_source']
            elif name == 'wrong_model':
                arm['model_instance_id'] = 'different-model'
            elif name == 'crossed_instance':
                geometry['floor_instance_id'] = '123'
            elif name == 'wrong_frame':
                geometry['frame_id'] = 'body-local'
            elif name == 'rehashed_plane':
                geometry['top_world_y_m'] += .125
                source['floor_reference']['height_world_m'] = geometry['top_world_y_m']
            elif name == 'rehashed_extent':
                geometry['x_interval_m'][1] += 100
            elif name == 'changed_parent':
                geometry['transform_chain_shape_to_root'][-1]['position_m'][1] += .125
            elif name == 'missing_chain':
                geometry['transform_chain_shape_to_root'].pop()
            elif name == 'context_height':
                request['floor_reference']['height_world_m'] += .125
            elif name == 'v1_request':
                request['schema_version'] = 'sporespore_balanced_wave_policy_session_step_request_v1'
            elif name == 'outside_extent':
                request['state']['base_pose_world']['position_m']['x'] = 10
            elif name == 'source_changed':
                rows[1]['development_floor_source']['geometry']['shape_resource_instance_id'] = '123'
            else:
                rows[1]['request']['memory'] = copy.deepcopy(rows[0]['request']['memory'])
            # Rehash the source/context/session together, so the geometry and
            # model reader must reject the derivation, not just a stale hash.
            if name in ('crossed_instance', 'wrong_frame', 'rehashed_plane', 'rehashed_extent', 'changed_parent', 'missing_chain'):
                # Use the same DLL-backed canonicalizer as production.
                source['floor_reference']['geometry_source_sha256'] = 'sha256:' + hashlib.sha256(cls.native_api().canonical(geometry)).hexdigest()
                source['floor_reference']['source_instance_id'] = geometry['model_instance_id'] + ':floor:' + geometry['floor_instance_id']
                request['floor_reference'] = copy.deepcopy(source['floor_reference'])
                arm['walking_sessions'][0]['start_receipt']['development_floor_source'] = copy.deepcopy(source)
            cases[name] = item
        path = cls.root / 'reader_inputs.json'
        path.write_text(json.dumps(cases, separators=(',', ':'), allow_nan=False) + '\n', encoding='utf-8')
        run = cls._run_retained(cls.fixture, ['--', str(path)], 'cold_reader', 90)
        cls.reader = shared.marker(run, 'V34_FLOOR_READER ')

    @classmethod
    def native_api(cls):
        from test_development_v32_recontact_component import NativeApi
        return NativeApi(ROOT / ('sdk/target/development-candidate-' + cls.candidate_id + '/release/sporespore_godot_adapter.dll'))

    def test_actual_constructor_adapter_and_ledger(self):
        self.assertTrue(all(self.producer['checks'].values()), self.producer['checks'])
        old = self.producer['result']['legacy_fixture']['ledger_application_intent']
        new = self.producer['result']['floor_fixture']['ledger_application_intent']
        self.assertEqual('sporespore_balanced_wave_bw5r_b_v1', old['walking_controller_policy_id'])
        self.assertEqual(self.policy_id, new['walking_controller_policy_id'])
        for key in ('authorized_host_cap_by_actuator_id', 'published_cap_by_actuator_id'):
            self.assertEqual(old[key], new[key])
        print(self.run_label + '_FLOOR_CHECKS', json.dumps(self.producer['checks'], separators=(',', ':')), flush=True)

    def test_independent_numeric_derivation_of_all_floor_variants(self):
        def f32(x):
            return struct.unpack('<f', struct.pack('<f', x))[0]
        for name, source in self.producer['result']['sources'].items():
            g = source['geometry']
            center = [0., 0., 0.]
            for row in g['transform_chain_shape_to_root']:
                center = [f32(f32(p) + old) for p, old in zip(row['position_m'], center)]
            self.assertEqual(center, g['shape_center_world_m'], name)
            self.assertEqual(center[1] + g['size_m'][1] / 2, g['top_world_y_m'], name)
            self.assertEqual(g['top_world_y_m'], source['floor_reference']['height_world_m'])
            for axis, i in [('x', 0), ('z', 2)]:
                self.assertEqual([center[i] - g['size_m'][i] / 2, center[i] + g['size_m'][i] / 2], g[axis + '_interval_m'])
        self.assertEqual(0, self.producer['result']['sources']['authored']['floor_reference']['height_world_m'])

    def test_cold_reader_complete_population_and_fourteen_refusals(self):
        self.assertTrue(self.reader['positive']['ok'], self.reader['positive'])
        self.assertEqual(200, self.reader['positive']['replayed_walking_steps'])
        self.assertEqual(15, len(self.reader))
        for name, result in self.reader.items():
            if name != 'positive':
                self.assertFalse(result['ok'], (name, result))
        print(self.run_label + '_FLOOR_READER_RESULTS', json.dumps(self.reader, separators=(',', ':')), flush=True)

    def test_original_floor_construction_statements_preserved(self):
        path = 'sdk/adapters/godot/gdscript/recovery_native_world_v1.gd'
        original = subprocess.check_output(['git', 'show', '98a35339476f597cfadf05d53eb97cafe08d0e9d:' + path], cwd=ROOT).decode()
        current = (ROOT / path).read_text(encoding='utf-8')
        block = original.split('\tvar floor := StaticBody3D.new()\n')[1].split('\tworld.add_child(floor)')[0]
        extracted = current.split('static func create_floor_v1() -> StaticBody3D:\n\tvar floor := StaticBody3D.new()\n')[1].split('\treturn floor')[0]
        self.assertEqual(block, extracted)
        self.assertEqual(1, current.count('\tvar floor := create_floor_v1()\n\tworld.add_child(floor)'))

    def test_legacy_source_suite_has_no_new_failures(self):
        import test_development_v32_walking_policy as policy_tests
        policy_tests.WalkingPolicy.test_legacy_source_suite_has_no_new_failures(self)

    def test_zero_world_scope_and_r173_and_native_graph_preserved(self):
        for key in ('world_build_count', 'solver_step_count', 'scene_tree_insertion_count'):
            self.assertEqual(0, self.producer[key])
        self.assertEqual(1, self.producer['detached_floor_body_count'])
        self.assertFalse(self.producer['physical_acceptance_authority'])
        self.assertFalse(self.producer['release_authority'])
        path = ROOT / ('sdk/development/recovery_candidates/' + self.candidate_id + '.json')
        with self.assertRaisesRegex(ValueError, 'DEVELOPMENT_CANDIDATE_PROFILE_SCHEMA'):
            candidate.selection(candidate.reference_for_path(path))
        binding = candidate.read(candidate.resource_path(candidate.read(path)['runtime_binding']))
        for source in binding['source_files']:
            self.assertEqual(source['raw_sha256'], candidate.sha(ROOT / source['path']))
        self.assertEqual('sha256:c2d6edf090ab80a55eb8a6996f52984c14c453bf513e9d8d058d81603817425f', candidate.sha(ROOT / 'sdk/recovery/r24d173_three_engine_canonical_prone_to_standing_decision_v1.json'))


if __name__ == '__main__':
    unittest.main()
