"""Zero-world route, sensor mapping and independent trace refusal controls."""
import copy
import csv
import hashlib
import json
from pathlib import Path
from types import SimpleNamespace
import unittest
from unittest.mock import patch
import uuid

import mujoco
from actuation_measurement import named_force_samples, scalar_implicitfast_step
from audit_gpu_measurement_probe import audit, f32
from gpu_measurement_probe import ROOT, FIELDS, inputs, load_contract, zero_world


class ProbeControls(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.folder = ROOT.parent/'SporeSpore_Evidence'/('sdk2-probe-synthetic-controls-'+uuid.uuid4().hex)
        cls.folder.mkdir()
        cls.contract = load_contract()
        cls.inputs = inputs(cls.contract)
        cls.rows = []
        for backend in ['cpu', 'gpu']:
            project = f32 if backend == 'gpu' else float
            for cell in range(8):
                velocity = project(cls.inputs['initial_velocities'][cell])
                for step in range(1, 121):
                    target = project(cls.inputs['targets'][cell] * (1 if step <= 60 else -1))
                    result = scalar_implicitfast_step(velocity=velocity, target=target,
                        inertia=1/60, damping=10., force_cap=6., dt=1/600)
                    after = project(result['velocity_next_rad_s'])
                    cls.rows.append(dict(backend=backend, cell=cell, step=step, time_s=step/600,
                        target_rad_s=target, before_rad_s=velocity, after_rad_s=after,
                        completed_step_force_nm=result['completed_step_force_nm'],
                        joint_force_nm=result['completed_step_force_nm'],
                        post_state_force_nm=result['post_state_force_nm'],
                        scalar_net_impulse_nms=result['effective_motor_impulse_nms']))
                    velocity = after

    def fixture(self, rows=None, source_inputs=None):
        folder = self.folder/uuid.uuid4().hex
        physical = folder/'physical'
        physical.mkdir(parents=True)
        (folder/'declaration.json').write_text(json.dumps(dict(contract=self.contract, synthetic=True)))
        (physical/'inputs.json').write_text(json.dumps(source_inputs or self.inputs))
        trace = physical/'trace.csv'
        with trace.open('w', newline='') as stream:
            writer = csv.DictWriter(stream, fieldnames=FIELDS)
            writer.writeheader()
            writer.writerows(self.rows if rows is None else rows)
        result = dict(ok=True, synthetic=True, cpu_worlds=8, gpu_worlds=8, solver_steps_per_backend=960,
            trace_sha256=hashlib.sha256(trace.read_bytes()).hexdigest(), physical_acceptance_authority=False,
            release_authority=False, training_data_authority=False)
        (physical/'worker-result.json').write_text(json.dumps(result))
        return physical

    def test_runtime_preflight_cannot_construct_native_world(self):
        with patch.object(mujoco, 'MjModel', side_effect=AssertionError('World in preflight')), \
             patch.object(mujoco, 'MjData', side_effect=AssertionError('Data in preflight')):
            self.assertEqual(zero_world()['world_build_count'], 0)

    def test_named_sensor_identity_and_stage_values(self):
        model = SimpleNamespace(actuator=lambda _: SimpleNamespace(id=7),
            joint=lambda _: SimpleNamespace(id=4),
            sensor=lambda name: SimpleNamespace(id={'motor_force': 0, 'hinge_actuator_force': 1}[name]),
            sensor_type=[mujoco.mjtSensor.mjSENS_ACTUATORFRC, mujoco.mjtSensor.mjSENS_JOINTACTFRC],
            sensor_objid=[7, 4], sensor_dim=[1, 1], sensor_adr=[2, 0])
        data = SimpleNamespace(sensordata=[-5., 999., -6.])
        self.assertEqual(named_force_samples(model, data, 'motor', 'hinge'),
                         dict(actuator_force_nm=-6., joint_actuator_force_nm=-5.))
        model.sensor_objid[1] = 99
        with self.assertRaises(ValueError):
            named_force_samples(model, data, 'motor', 'hinge')

    def test_complete_synthetic_trace_has_no_physical_authority(self):
        result = audit(self.fixture())
        self.assertEqual(result['rows'], 1920)
        self.assertFalse(result['physical_acceptance_authority'])
        self.assertFalse(result['training_data_authority'])

    def test_missing_duplicate_and_crossed_rows_refused(self):
        for rows in [self.rows[:-1], self.rows+[self.rows[0]], self.rows[1:]+[self.rows[0]]]:
            with self.assertRaises(ValueError):
                audit(self.fixture(rows))

    def test_counterexamples_do_not_disappear_behind_summary(self):
        for key, value in [('after_rad_s', float('nan')), ('time_s', 999.),
                           ('target_rad_s', .123), ('joint_force_nm', 5.), ('before_rad_s', 9.)]:
            rows = copy.deepcopy(self.rows)
            rows[0][key] = value
            with self.subTest(key=key), self.assertRaises(ValueError):
                audit(self.fixture(rows))

    def test_crossed_seeded_population_refused(self):
        changed = copy.deepcopy(self.inputs)
        changed['initial_velocities'][0] += .001
        with self.assertRaises(ValueError):
            audit(self.fixture(source_inputs=changed))

    def test_corrupted_raw_trace_refused(self):
        folder = self.fixture()
        with (folder/'trace.csv').open('a') as stream:
            stream.write('\n')
        with self.assertRaisesRegex(ValueError, 'digest'):
            audit(folder)

    def test_authority_promotion_refused(self):
        folder = self.fixture()
        path = folder/'worker-result.json'
        result = json.loads(path.read_text())
        result['physical_acceptance_authority'] = True
        path.write_text(json.dumps(result))
        with self.assertRaisesRegex(ValueError, 'authority'):
            audit(folder)

    def test_diagnosis_preserves_every_cell_and_grants_no_authority(self):
        from diagnose_gpu_measurement_probe import diagnose
        result = diagnose(self.fixture())
        self.assertEqual(result['audited_rows'], 1920)
        self.assertEqual([r['cell'] for r in result['per_cell']], list(range(8)))
        self.assertFalse(result['equivalence_authority'])
        self.assertFalse(result['thresholds_changed'])

    def test_closure_rehashes_artifacts_and_recomputes_reader(self):
        from audit_gpu_measurement_probe import verify_closure
        physical = self.fixture()
        attempt = physical.parent
        source = '0'*40
        (attempt/'receipt.json').write_text(json.dumps(dict(ok=True, source_commit=source, synthetic=True)))
        (attempt/'consumed.json').write_text(json.dumps(dict(synthetic=True)))
        observed = audit(physical)
        (attempt/'independent-audit.json').write_text(json.dumps(observed))
        for name in ['model.xml', 'stdout.log', 'stderr.log']:
            (physical/name).write_text('synthetic fixture only')
        artifacts = [dict(evidence_relative_path=p.relative_to(self.folder).as_posix(),
            byte_length=p.stat().st_size, sha256=hashlib.sha256(p.read_bytes()).hexdigest())
            for p in attempt.rglob('*') if p.is_file()]
        closure = dict(artifacts=artifacts, attempt_id=attempt.name, source_commit=source,
            independent_audit=observed, physical_acceptance_authority=False, release_authority=False,
            equivalence_authority=False, training_data_authority=False, synthetic=True)
        path = self.folder/(attempt.name+'-closure.json')
        path.write_text(json.dumps(closure))
        self.assertTrue(verify_closure(path, self.folder)['ok'])
        changed = copy.deepcopy(closure)
        changed['independent_audit']['rows'] = 1
        path.write_text(json.dumps(changed))
        with self.assertRaisesRegex(ValueError, 'audit changed'):
            verify_closure(path, self.folder)
        path.write_text(json.dumps(closure))
        (physical/'stderr.log').write_text('changed artifact')
        with self.assertRaisesRegex(ValueError, 'artifact changed'):
            verify_closure(path, self.folder)


if __name__ == '__main__':
    unittest.main()
