"""Isolated child-claim controls and an actual Godot-to-Python owner probe; no world."""
import copy
import json
import os
from pathlib import Path
import subprocess
import unittest
from unittest import mock

import test_r10aj_launch_guard as base
import r10aj_native_world_authority as authority


class R10AJNativeWorldAuthority(base.R10AJLaunchGuard):
    # Inherited guard tests run under the same fresh source snapshot as these.
    def prepared(self):
        path = self.fixture()
        self.declaration = base.launch.read(path)
        child = self.declaration['children'][0]
        Path(child['evidence_path']).mkdir(parents=True)
        base.launch.authorize(path)
        seed = base.development.seed_identity(base.development.SEED)
        values = dict(AUTHORIZATION_SHA256=base.development.sha(path),
            SOURCE_COMMIT=self.declaration['source_snapshot']['head'], PARENT_ATTEMPT_ID=self.declaration['attempt_id'],
            ATTEMPT_ID=child['child_attempt_id'], CHILD_ROLE=child['role'], TERMINATION_NONCE=child['termination_nonce'],
            SEED=str(seed['seed']), SEED_LABEL=seed['label'], SEED_SHA256=seed['sha256'], SUPERVISED_TERMINATION='1')
        patch = mock.patch.dict(os.environ, {authority.PREFIX + k: v for k, v in values.items()})
        patch.start(); self.addCleanup(patch.stop)
        patch = mock.patch.object(authority, 'validate_worker', return_value=base.host.expected_binding()['images']['godot_engine'])
        self.worker_mock = patch.start(); self.addCleanup(patch.stop)
        # Synthetic launch/claim controls isolate the new preflight boundary.
        # The real Godot helper is exercised separately, never by these fake PIDs.
        patch = mock.patch.object(authority.startup, 'inspect_request', return_value=dict(ok=True, synthetic_control=True))
        self.preflight_mock = patch.start(); self.addCleanup(patch.stop)
        return path, Path(child['evidence_path']) / authority.CLAIM

    def test_native_claim_is_exclusive_and_historical_verification_is_read_only(self):
        path, target = self.prepared()
        result = authority.claim(path, 10002)
        self.assertIs(result['ok'], True); original = target.read_bytes()
        self.assertEqual(base.launch.binding(target), authority.verify(path, 10002))
        with self.assertRaisesRegex(ValueError, 'CHILD_ALREADY_CLAIMED'): authority.claim(path, 10003)
        self.assertEqual(original, target.read_bytes())
        self.assertEqual(1, result['claim']['maximum_world_builds'])
        self.assertIs(result['claim']['physical_acceptance_authority'], False)

    def test_native_crossed_environment_refuses_before_claim(self):
        path, target = self.prepared()
        for key in ('AUTHORIZATION_SHA256', 'SOURCE_COMMIT', 'PARENT_ATTEMPT_ID', 'ATTEMPT_ID', 'CHILD_ROLE',
                    'TERMINATION_NONCE', 'SEED', 'SEED_LABEL', 'SEED_SHA256', 'SUPERVISED_TERMINATION'):
            with mock.patch.dict(os.environ, {authority.PREFIX + key: 'crossed'}):
                with self.subTest(key=key), self.assertRaisesRegex(ValueError, 'CHILD_ENVIRONMENT'):
                    authority.claim(path, 10002)
        self.worker_mock.assert_not_called(); self.preflight_mock.assert_not_called(); self.assertFalse(target.exists())

    def test_native_changed_freeze_or_missing_launch_cannot_claim(self):
        path, target = self.prepared()
        receipt=dict(ok=False, stage='source_freeze', failure_code='source changed',
            command_receipts=[dict(exit_code=128,stderr='retained synthetic Git error')])
        with mock.patch.object(authority.startup, 'inspect_request', return_value=receipt):
            with self.assertRaisesRegex(authority.StartupRefused, 'source changed') as refused:
                authority.claim(path, 10002)
            self.assertEqual(receipt,refused.exception.receipt)
        self.worker_mock.assert_not_called()
        with mock.patch.object(base.launch, 'verify', side_effect=ValueError('missing launch receipt')):
            with self.assertRaisesRegex(ValueError, 'missing launch receipt'): authority.claim(path, 10002)
        self.assertFalse(target.exists())

    def test_native_partial_claim_write_cannot_be_retried(self):
        path, target = self.prepared()
        def partial(p, _value):
            with p.open('x', encoding='utf-8') as stream: stream.write('retained synthetic interrupted claim')
            raise OSError('synthetic write interruption')
        with mock.patch.object(base.launch, 'write_new', side_effect=partial):
            with self.assertRaisesRegex(OSError, 'write interruption'): authority.claim(path, 10002)
        original = target.read_bytes()
        with self.assertRaisesRegex(ValueError, 'CHILD_ALREADY_CLAIMED'): authority.claim(path, 10002)
        self.assertEqual(original, target.read_bytes())

    def test_native_claim_crossed_fields_refuse(self):
        path, target = self.prepared(); authority.claim(path, 10002)
        original = target.read_bytes(); value = base.launch.read(target); read = base.launch.read
        for key, changed in [('worker_process_id', 10003), ('maximum_world_builds', True),
            ('parent_attempt_id', '0' * 32), ('child_attempt_id', '0' * 32), ('termination_nonce', '0' * 32),
            ('declaration', {}), ('launch_receipt', {}), ('source_key', {}), ('population_reservation', {}),
            ('worker_image', {}), ('physical_acceptance_authority', True), ('release_authority', True)]:
            mutation = copy.deepcopy(value); mutation[key] = changed
            with mock.patch.object(base.launch, 'read', side_effect=lambda p: mutation if p == target else read(p)):
                with self.subTest(key=key), self.assertRaisesRegex(ValueError, 'CLAIM_BINDING'):
                    authority.verify(path, 10002)
        self.assertEqual(original, target.read_bytes())

    def test_native_owner_requires_actual_parent_and_exact_worker_image(self):
        pid = os.getppid()
        with self.assertRaisesRegex(ValueError, 'HELPER_PARENT'): authority.validate_worker(pid + 1)
        with mock.patch.object(authority, 'worker_image', return_value=base.host.expected_binding()['images']['python_helper']):
            with self.assertRaisesRegex(ValueError, 'RUNNING_IMAGE'): authority.validate_worker(pid)
        self.assertEqual(Path(os.sys.executable).resolve(), Path(authority.worker_image(os.getpid())['path']).resolve())

    def test_native_pure_permission_and_real_helper_parent_probe(self):
        # Keep the canonical path from setUpClass; this test's Python namespace
        # is deliberately redirected, while the native guard is never redirected.
        declaration = copy.deepcopy(self.template)
        declaration['runtime'] = base.host.expected_binding()
        fake = dict(schema_version='sporespore_r10aj_native_world_claim_v1',
            parent_attempt_id=declaration['attempt_id'], child_attempt_id=declaration['children'][0]['child_attempt_id'],
            termination_nonce=declaration['children'][0]['termination_nonce'], role=base.development.ROLE,
            source_commit=declaration['source_snapshot']['head'], worker_process_id=10002,
            maximum_world_builds=1, permission_scope='diagnostic_world_construction_only',
            physical_acceptance_authority=False, release_authority=False)
        fixture = self.base / 'fixture.json'
        base.write(fixture, dict(declaration=declaration, claim=fake, synthetic_claim=True))
        output = self.base / 'result.json'
        command = [base.host.expected_binding()['images']['godot_engine']['path'], '--headless', '--path', str(base.ROOT),
            '--script', 'res://tests/test_r10aj_native_world_guard.gd', '--', str(fixture), str(output)]
        env = {k: v for k, v in os.environ.items() if not k.startswith(authority.PREFIX)}
        with (self.base / 'native.stdout.txt').open('xb') as stdout, (self.base / 'native.stderr.txt').open('xb') as stderr:
            result = subprocess.run(command, cwd=base.ROOT, env=env, stdout=stdout, stderr=stderr, timeout=90,
                creationflags=subprocess.CREATE_NO_WINDOW)
        base.write(self.base / 'native.execution.json', dict(command=command, exit_code=result.returncode,
            world_build_count=0, solver_step_count=0))
        self.assertEqual(0, result.returncode, (self.base / 'native.stderr.txt').read_text())
        self.assertEqual(b'', (self.base / 'native.stderr.txt').read_bytes())
        value = json.loads(output.read_text())
        self.assertIs(value['ok'], True); self.assertTrue(all(value['checks'].values()))
        self.assertEqual(base.host.expected_binding()['images']['godot_engine'], value['owner_probe']['worker_image'])
        self.assertEqual([], list(base.development.EVIDENCE.glob('**/' + authority.CLAIM)))


if __name__ == '__main__': unittest.main()
