"""Real R10P worker seed/phase/serialization hooks without a physical world."""
import copy
import json
from pathlib import Path
import re
import subprocess
import unittest
import uuid

from test_r10p_campaign_seed import authority, case, packet, profile, runtime, snapshot

ROOT = authority.ROOT


class WorkerBoundary(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.root = authority.EVIDENCE / ('r10p-worker-boundary-' + uuid.uuid4().hex)
        cls.root.mkdir()
        candidate = profile.reference()
        original = profile.candidate.reference_for_path(ROOT / 'sdk/development/recovery_candidates/r10o-v55-initialized-brake-integrated-v2.json')
        cls.cases = {}
        for mode in ('development_ghost', 'held_out_finite_decision'):
            for cell in authority.population(mode):
                item = case(mode, cell['seed']['seed'], cell['role'])
                for value in (item['context'], item['declaration'], item['claim']):
                    value['candidate_profile'] = copy.deepcopy(candidate)
                cls.cases[cell['cell_id']] = item
        # Exercise the actual file-bound development authorization, on an exposed
        # seed only. This synthetic claim grants no physical launch or acceptance.
        launch = copy.deepcopy(cls.cases['40741:' + authority.ROLES[0]])
        claim_id = uuid.uuid4().hex
        claim_root = authority.EVIDENCE / ('r10p-production-ghost-' + claim_id)
        claim_root.mkdir()
        launch['claim'].update(attempt_id=claim_id, synthetic_zero_world_fixture=True,
                               physical_acceptance_authority=False, release_authority=False)
        for child in launch['claim']['children']:
            child['campaign_attempt_id'] = claim_id
        for child in launch['declaration']['children']:
            child['campaign_attempt_id'] = claim_id
        launch['declaration']['r10p_campaign']['campaign_attempt_id'] = claim_id
        claim_path = claim_root / 'campaign_claim.json'
        claim_path.write_text(json.dumps(launch['claim']), encoding='utf-8')
        launch['declaration']['r10p_campaign']['claim_binding'] = dict(path=claim_path.as_posix(), raw_sha256=authority.sha(claim_path.read_bytes()))
        data = dict(candidate=candidate, original_candidate=original, cases=cls.cases, launch=launch)
        path = cls.root / 'cases.json'
        path.write_text(json.dumps(data), encoding='utf-8')
        source = snapshot._source_snapshot()
        (cls.root / 'source_snapshot.json').write_text(json.dumps(source), encoding='utf-8')
        image = runtime.IMAGES['godot_engine']
        if runtime.file_identity(Path(image['path'])) != image:
            raise AssertionError('R10P_WORKER_ENGINE_DRIFT')
        command = [image['path'], '--headless', '--path', str(ROOT), '--script',
                   'res://tests/test_r10p_worker_boundary.gd', '--', str(path)]
        try:
            run = subprocess.run(command, cwd=ROOT, stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=90)
        except subprocess.TimeoutExpired as error:
            run = subprocess.CompletedProcess(command, 124, error.stdout or b'', error.stderr or b'')
        (cls.root / 'stdout.txt').write_bytes(run.stdout)
        (cls.root / 'stderr.txt').write_bytes(run.stderr)
        unchanged = packet.same(source, snapshot._source_snapshot())
        receipt = dict(command=command, engine_image=image, returncode=run.returncode, timeout_seconds=90,
            source_unchanged_during_run=unchanged, synthetic_claim_binding=runtime.file_identity(claim_path),
            retained_files=[runtime.file_identity(cls.root / name) for name in ('cases.json', 'source_snapshot.json', 'stdout.txt', 'stderr.txt')],
            world_build_count=0, solver_step_count=0, physical_acceptance_authority=False, release_authority=False)
        (cls.root / 'execution.json').write_text(json.dumps(receipt), encoding='utf-8')
        print('R10P_WORKER_BOUNDARY_ROOT', cls.root, flush=True)
        if run.returncode or b'ERROR:' in run.stdout + run.stderr or not unchanged:
            raise AssertionError(f'R10P_WORKER_NATIVE_FAILURE returncode={run.returncode} unchanged={unchanged}; see {cls.root}')
        rows = [line.removeprefix('R10P_WORKER_BOUNDARY ') for line in run.stdout.decode().splitlines() if line.startswith('R10P_WORKER_BOUNDARY ')]
        if len(rows) != 1:
            raise AssertionError('R10P_WORKER_MARKER')
        cls.result = json.loads(rows[0])

    def test_actual_worker_launch_boundary_and_retention(self):
        self.assertEqual(45, len(self.result['checks']))
        for name, passed in self.result['checks'].items():
            self.assertIs(passed, True, name)
        self.assertEqual(0, self.result['world_build_count'])
        self.assertEqual(0, self.result['solver_step_count'])

    def test_all_declared_prefix_phases_through_real_facade(self):
        self.assertEqual(set(self.cases), set(self.result['phases']))
        for name, phases in self.result['phases'].items():
            expected = self.cases[name]['context']['seed']['prefix_phase']
            self.assertEqual({limb: expected for limb in ('front_left', 'front_right', 'rear_left', 'rear_right')}, phases)

    def test_serialized_worker_reports_satisfy_python_campaign_reader(self):
        for name, report in self.result['publications'].items():
            item = self.cases[name]
            self.assertIs(report['ok'], True, name)
            profile.validate_campaign_retention(report, item['declaration'],
                dict(seed=int(item['seed_text']), held_out=item['context']['mode'] == 'held_out_finite_decision'))
            self.assertEqual([{'synthetic_retention_marker': 7.000000000000001}], report['passive_entry']['entry_packets'])

    def test_boundary_subclass_does_not_override_physical_hooks(self):
        source = (ROOT / profile.WORKER.removeprefix('res://')).read_text()
        self.assertEqual({'_authorized_seed_binding_v1', '_entry_selection_v1', '_walking_prefix_profile_id_v1', '_attach_entry_retention_v1'},
                         set(re.findall(r'^func (\w+)\(', source, re.M)))


if __name__ == '__main__':
    unittest.main()
