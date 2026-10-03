"""Isolated reservation/claim controls; never grant production world permission."""
import copy
import json
import os
from pathlib import Path
import subprocess
import sys
import unittest
from unittest.mock import patch
import uuid
ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'sdk/conformance'))
import r10dg_identity as I
import r10dg_launch as L
import r10dg_native_world_authority as A

class Controls(unittest.TestCase):
    def setUp(self):
        self.folder = I.EVIDENCE / ('r10dg-isolated-controls-' + uuid.uuid4().hex)
        self.folder.mkdir()
        for name, value in [('EVIDENCE', self.folder), ('TOKEN', self.folder / 'isolated-consumption.json')]:
            item = patch.object(I, name, value); item.start(); self.addCleanup(item.stop)
        self.value = L.declaration('a' * 40)
        self.parent = I.EVIDENCE / ('development-recovery-smoke-' + self.value['attempt_id'])
        self.parent.mkdir()
        self.path = self.parent / 'declaration.json'
        Path(self.value['children'][0]['evidence_path']).mkdir(parents=True)
        I.write_new(self.path, self.value)
        self.preworld = dict(ok=True, world_build_count=0, solver_step_count=0, construction_boundary_reached=True,
                             construction_guard=dict(failure_code='R10DG_NATIVE_WORLD_QUALIFICATION_PENDING'), comparison=dict(ok=True))
        for name in ['prepared-context.json', 'pre-world-result.json']: I.write_new(self.parent / name, self.preworld)
        for obj, name, result in [(I, 'freeze', {}), (I, 'verify_images', {}), (A, 'verify_qualification', {})]:
            item = patch.object(obj, name, return_value=result); item.start(); self.addCleanup(item.stop)

    def test_identity_mutations_and_fixture_physical_refusal(self):
        I.validate(self.value, physical=True)
        for key, changed in [('seed', True), ('seed', 70248), ('release_authority', True), ('official_qualification', 0),
                             ('maximum_steps_per_child', 830), ('worker_resource', 'crossed'), ('runtime', {}),
                             ('children', []), ('candidate_profile', {}), ('source_snapshot', {})]:
            value = copy.deepcopy(self.value); value[key] = changed
            with self.subTest(key=key), self.assertRaises((ValueError, KeyError)): I.validate(value, physical=True)
        for fixture in [False, True]:
            value = copy.deepcopy(self.value); value['report_fixture_only'] = fixture
            with self.assertRaisesRegex(ValueError, 'SYNTHETIC_IDENTITY'): I.validate(value, physical=True)

    def test_exclusive_reservation_and_missing_qualification(self):
        self.value['safety_qualification'] = {}
        # Mock only this isolated declaration loader, leaving the exclusive writer real.
        with patch.object(A, 'declared', return_value=self.value):
            with patch.object(A, 'verify_qualification', side_effect=ValueError('missing qualification')):
                with self.assertRaises(ValueError): A.authorize(self.path)
            self.assertFalse(I.TOKEN.exists())
            A.authorize(self.path)
            original = I.TOKEN.read_bytes()
            with self.assertRaises(FileExistsError): A.authorize(self.path)
            self.assertEqual(original, I.TOKEN.read_bytes())
            A.verify(self.path)

    def test_partial_reservation_write_consumes_without_retry(self):
        self.value['safety_qualification'] = {}
        real = I.write_new
        def interrupted(path, value):
            if path == I.TOKEN:
                with path.open('xb') as stream: stream.write(b'isolated interrupted reservation')
                raise OSError('interrupted')
            return real(path, value)
        with patch.object(A, 'declared', return_value=self.value):
            with patch.object(I, 'write_new', side_effect=interrupted):
                with self.assertRaises(OSError): A.authorize(self.path)
            raw = I.TOKEN.read_bytes()
            with self.assertRaises(FileExistsError): A.authorize(self.path)
            self.assertEqual(raw, I.TOKEN.read_bytes())

    def test_claim_environment_parent_image_and_exclusivity(self):
        child = self.value['children'][0]
        values = dict(AUTHORIZATION_SHA256=I.sha(self.path), SOURCE_COMMIT=self.value['source_snapshot']['head'],
            PARENT_ATTEMPT_ID=self.value['attempt_id'], ATTEMPT_ID=child['child_attempt_id'], CHILD_ROLE=I.ROLE,
            TERMINATION_NONCE=child['termination_nonce'], SEED=str(I.SEED), SEED_LABEL=I.LABEL,
            SEED_SHA256=I.seed_identity()['sha256'], SUPERVISED_TERMINATION='1')
        env = {'SPORESPORE_GODOT_RECOVERY_' + k:v for k,v in values.items()}
        I.write_new(self.parent / I.LAUNCH, {'isolated': True})
        I.write_new(I.TOKEN, {'isolated': True})
        image = I.read(I.HOST)['images']['godot_engine']
        with patch.object(A, 'verify', return_value=self.value), patch.dict(os.environ, env), patch.object(A, 'worker_image', return_value=image):
            for key in env:
                with patch.dict(os.environ, {key:'crossed'}):
                    with self.subTest(key=key), self.assertRaisesRegex(ValueError, 'CHILD_ENVIRONMENT'): A.claim(self.path, os.getppid())
            with self.assertRaisesRegex(ValueError, 'HELPER_PARENT'): A.claim(self.path, os.getppid()+1)
            with patch.object(A, 'worker_image', return_value=I.read(I.HOST)['images']['python_helper']):
                with self.assertRaisesRegex(ValueError, 'HELPER_IMAGE'): A.claim(self.path, os.getppid())
            result = A.claim(self.path, os.getppid())
            self.assertIs(result['ok'], True)
            target = Path(child['evidence_path']) / I.CLAIM
            raw = target.read_bytes()
            with self.assertRaises(FileExistsError): A.claim(self.path, os.getppid())
            self.assertEqual(raw, target.read_bytes())

    def test_real_process_image_is_read_only(self):
        result = A.worker_image(os.getpid())
        self.assertEqual(Path(result['path']).resolve(), Path(sys.executable).resolve())
        self.assertEqual(result['raw_sha256'], I.sha(sys.executable))

    def test_actual_powershell_context_constructor(self):
        output = self.folder / 'context.json'
        run = subprocess.run([I.read(I.HOST)['images']['powershell_host']['path'], '-NoProfile', '-File',
            str(ROOT / 'tests/test_r10dg_launcher_context.ps1'), '-Declaration', str(self.path), '-OutputPath', str(output)],
            cwd=ROOT, capture_output=True, timeout=60, creationflags=subprocess.CREATE_NO_WINDOW)
        (self.folder / 'context.stdout.txt').write_bytes(run.stdout)
        (self.folder / 'context.stderr.txt').write_bytes(run.stderr)
        self.assertEqual(0, run.returncode, run.stderr.decode(errors='replace'))
        self.assertEqual(b'', run.stderr)
        self.assertTrue(I.read(output)['ok'])

if __name__ == '__main__': unittest.main()
