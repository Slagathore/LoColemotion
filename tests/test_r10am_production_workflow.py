"""Exercise actual supervisor selection and its pre-declaration refusals."""
import json
from pathlib import Path
import subprocess
import sys
import unittest
import uuid

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'sdk/conformance'))
import r10am_development as identity
import r10am_host_runtime as host
import r10am_development_launch as launch
import r10am_context_handoff as retained
import development_passive_entry_profile as source

PROFILE = 'sdk/development/recovery_candidates/r10am-support-anchored-v1.json'


class ProductionWorkflow(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.out = identity.EVIDENCE / ('r10am-production-workflow-' + uuid.uuid4().hex)
        cls.out.mkdir()
        cls.before = source._source_snapshot()
        retained.write(cls.out / 'source-before.json', cls.before)
        cls.populations = set(identity.EVIDENCE.glob('development-recovery-smoke-*'))
        cls.tokens = {p: p.read_bytes() for p in identity.EVIDENCE.glob('r10am*consumption*.json')}
        assert not launch.CONTRACT.exists(), 'These refusal controls require the pre-qualification state'
        print('R10AM_PRODUCTION_WORKFLOW_ROOT ' + cls.out.as_posix(), flush=True)

    @classmethod
    def tearDownClass(cls):
        after = source._source_snapshot(); retained.write(cls.out / 'source-after.json', after)
        assert after == cls.before
        assert cls.populations == set(identity.EVIDENCE.glob('development-recovery-smoke-*'))
        assert cls.tokens == {p: p.read_bytes() for p in identity.EVIDENCE.glob('r10am*consumption*.json')}

    def invoke(self, name, arguments, expression=None):
        engine = host.expected_binding()['images']['powershell_host']['path']
        command = [engine, '-NoProfile', '-NonInteractive']
        if expression is None:
            command += ['-File', str(ROOT / 'sdk/run_development_recovery_smoke.ps1'),
                        '-CandidateProfile', PROFILE, *arguments]
        else:
            command += ['-Command', "$ErrorActionPreference='Stop'; . ./sdk/run_development_recovery_smoke.ps1 -Library -SingleKick -ProfileSteps -ReuseContextChecks -CandidateProfile " + PROFILE + '; ' + expression]
        process = subprocess.run(command, cwd=ROOT, capture_output=True, timeout=90,
                                 creationflags=subprocess.CREATE_NO_WINDOW)
        (self.out / (name + '.stdout.txt')).write_bytes(process.stdout)
        (self.out / (name + '.stderr.txt')).write_bytes(process.stderr)
        retained.write(self.out / (name + '.execution.json'), dict(command=command, returncode=process.returncode,
            world_build_count=0, solver_step_count=0, physical_acceptance_authority=False, release_authority=False))
        return process

    def test_real_library_selects_declared_seed_runtime_and_worker(self):
        expression = "Assert-QsdkR10fL14RuntimeBinding (Get-R10amExpectedRuntimeBinding); ConvertTo-SporeSporeExactJson -Value @{fields=(Get-DevelopmentCandidateFields);seed=$script:DevelopmentSeed;label=$script:DevelopmentSeedLabel;worker=$script:WorkerResource;runtime=(Get-R10amRuntimeBinding -Godot $Godot);stages=$stages.Count}"
        result = self.invoke('selection', [], expression)
        self.assertEqual(0, result.returncode, result.stderr.decode(errors='replace'))
        self.assertEqual(b'', result.stderr)
        value = json.loads(result.stdout)
        self.assertEqual(identity.SEED, value['seed'])
        self.assertEqual(identity.seed_identity(identity.SEED)['label'], value['label'])
        self.assertTrue(value['worker'].endswith('/r10am_development_worker_v1.gd'))
        self.assertEqual(host.expected_binding(), value['runtime'])
        import qsdk_r10f_l14_runtime_binding as shared_runtime
        shared_runtime.validate_binding(value['runtime'])
        crossed = dict(value['runtime'], release_authority=True)
        with self.assertRaises(ValueError):
            shared_runtime.validate_binding(crossed)
        self.assertEqual(0, value['stages'])
        self.assertEqual(2400, value['fields']['timeout_seconds_per_child'])
        self.assertEqual(1200, value['fields']['independent_replay_timeout_seconds'])
        self.assertEqual(identity.reference(), value['fields']['candidate_profile'])

    def test_real_smoke_refuses_missing_safety_contract_before_declaration(self):
        result = self.invoke('missing-safety', ['-SingleKick', '-ProfileSteps', '-ReuseContextChecks', '-RunSmoke'])
        self.assertNotEqual(0, result.returncode)
        self.assertIn(b'R10AM_COMPLETE_SAFETY_CONTRACT_PENDING', result.stderr)

    def test_real_supervisor_refuses_undeclared_paired_mode(self):
        result = self.invoke('paired-refusal', ['-ProfileSteps', '-ReuseContextChecks'])
        self.assertNotEqual(0, result.returncode)
        self.assertIn(b'R10AM_DIAGNOSTIC_REQUIRES_SINGLE_KICK', result.stderr)


if __name__ == '__main__':
    unittest.main()
