"""Actual PowerShell development declaration and pre-world refusals for R10Q."""
import subprocess
import unittest
import uuid

from test_development_r10q_complete_report import ROOT, EVIDENCE, PROFILE, declaration, candidate, development, entry, write

PWSH = 'C:/Program Files/PowerShell/7/pwsh.exe'


class R10QLauncher(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.out = EVIDENCE / ('development-r10q-launcher-' + uuid.uuid4().hex)
        cls.out.mkdir()
        cls.before = entry._source_snapshot()
        write(cls.out / 'source_before.json', cls.before)
        cls.reference = candidate.reference_for_path(PROFILE)
        print('R10Q_LAUNCHER_EVIDENCE ' + str(cls.out), flush=True)

    @classmethod
    def tearDownClass(cls):
        after = entry._source_snapshot()
        write(cls.out / 'source_after.json', after)
        if after != cls.before:
            raise AssertionError('R10Q_LAUNCHER_SOURCE_DRIFT')

    def run_launcher(self, label, options, output=''):
        relative = self.reference['resource'].removeprefix('res://')
        command = f". ./sdk/run_development_recovery_smoke.ps1 -ProfileSteps -ReuseContextChecks -CandidateProfile '{relative}' {options}"
        if output:
            command += '; ' + output
        args = [PWSH, '-NoProfile', '-NonInteractive', '-Command', command]
        result = subprocess.run(args, cwd=ROOT, capture_output=True, timeout=40, creationflags=subprocess.CREATE_NO_WINDOW)
        (self.out / (label + '.stdout.txt')).write_bytes(result.stdout)
        (self.out / (label + '.stderr.txt')).write_bytes(result.stderr)
        write(self.out / (label + '.execution.json'), dict(command=args, returncode=result.returncode))
        return result

    def test_actual_paired_library_context_and_worker_declaration_agree(self):
        result = self.run_launcher('paired', '-Library',
            'ConvertTo-SporeSporeExactJson -Value ([ordered]@{fields=(Get-DevelopmentCandidateFields);'
            'worker=$script:WorkerResource;roles=$script:OrderedChildRoles;seed=$script:DevelopmentSeed;'
            'context=$r10qDevelopmentContext})')
        self.assertEqual(0, result.returncode, result.stderr.decode())
        selected = entry.packet.parse_json(result.stdout.decode())
        self.assertEqual(40846, selected['seed'])
        self.assertEqual(development.ROLES, selected['roles'])
        value = declaration(self.reference, self.before['head'])
        value.update(selected['fields'])
        value['worker_resource'] = selected['worker']
        value['r10q_development'] = selected['context']
        self.assertEqual(development.ROLES, development.validate_declaration(value)['roles'])
        self.assertEqual(self.reference, value['candidate_profile'])
        self.assertEqual(3512, value['maximum_steps_per_child'])
        self.assertFalse(value['comparative_authority'])
        self.assertFalse(value['baseline_reused'])
        write(self.out / 'paired-declaration.json', value)

    def test_actual_gate_selects_r10q_and_every_declared_test_exists(self):
        result = self.run_launcher('stage-selection', '-Library',
            'ConvertTo-SporeSporeExactJson -Value $stages')
        self.assertEqual(0, result.returncode, result.stderr.decode())
        stages = entry.packet.parse_json(result.stdout.decode())
        ids = [stage['id'] for stage in stages]
        self.assertEqual(len(ids), len(set(ids)))
        contract = entry.packet.parse_json((ROOT / 'sdk/development/r10q_safety_stage_contract_v3.json').read_text())
        self.assertEqual(len(contract['stages']), len(stages))
        for index, (declared, selected) in enumerate(zip(contract['stages'], stages)):
            self.assertEqual(declared, {k: selected[k] for k in ('id', 'pattern', 'tests')})
            if index >= contract['unbound_common_stage_count']:
                self.assertEqual(self.reference['resource'].removeprefix('res://'), selected['candidate_profile'])
            else:
                self.assertNotIn('candidate_profile', selected)
            timeout = contract['stage_timeout_overrides_seconds'].get(selected['id'])
            if timeout is None:
                self.assertNotIn('timeout_seconds', selected)
            else:
                self.assertEqual(timeout, selected['timeout_seconds'])
        counts = {}
        for stage in stages:
            suite = unittest.TestLoader().discover(str(ROOT / 'tests'), pattern=stage['pattern'])
            counts[stage['id']] = suite.countTestCases()
            self.assertEqual(stage['tests'], counts[stage['id']], stage)
        self.assertNotIn('test_development_v32_walking_policy.py', [stage['pattern'] for stage in stages])
        self.assertNotIn('candidate_walking_start', ids)
        self.assertNotIn('candidate_walking_entry', ids) # Both selected role adapters cover these controls.
        write(self.out / 'selected-stages.json', dict(stages=stages, discovered_test_counts=counts,
            test_count=sum(counts.values()), world_build_count=0, solver_step_count=0))

    def test_invalid_test_timeout_refuses_before_a_process_or_log_file(self):
        # These library calls cannot execute tests or construct a physical world.
        for label, value in [('zero', '0'), ('boolean', '$true'), ('too-long', '601')]:
            result = self.run_launcher('timeout-' + label, '-Library',
                "Invoke-DevelopmentStage @{id='never-launched';pattern='unused';tests=1;timeout_seconds="
                + value + "} '" + self.out.as_posix() + "'")
            self.assertNotEqual(0, result.returncode)
            self.assertIn('DEVELOPMENT_STAGE_TIMEOUT_INVALID', result.stderr.decode())
        for label, pattern, tests, seconds in [
                ('registered-too-long', 'test_development_r10q_preparation_report.py', 2, 901),
                ('crossed-long-pattern', 'unused.py', 2, 601),
                ('crossed-long-count', 'test_development_r10q_preparation_report.py', 1, 601)]:
            result = self.run_launcher(label, '-Library',
                "Invoke-DevelopmentStage @{id='r10q_preparation_report';pattern='" + pattern
                + "';tests=" + str(tests) + ";timeout_seconds=" + str(seconds) + "} '" + self.out.as_posix() + "'")
            self.assertNotEqual(0, result.returncode)
            self.assertIn('DEVELOPMENT_STAGE_TIMEOUT_INVALID', result.stderr.decode())
        self.assertFalse((self.out / 'r10q_preparation_report.stdout.log').exists())
        self.assertFalse((self.out / 'never-launched.stdout.log').exists())
        self.assertFalse((self.out / 'never-launched.stderr.log').exists())

    def test_single_branch_refuses_without_a_retained_positive_pair(self):
        result = self.run_launcher('single-without-pair', '-Library -SingleKick -R10QDiagnosticSeed 40843')
        self.assertNotEqual(0, result.returncode)
        self.assertIn('SINGLE_REQUIRES_POSITIVE_PAIR', result.stderr.decode())
        for options in ('-Library -R10QDiagnosticSeed 40845', '-Library -R10QDiagnosticSeed 40200', '-Library -SingleKick'):
            result = self.run_launcher('invalid-seed-' + options.split()[-1], options)
            self.assertNotEqual(0, result.returncode)
            self.assertIn('R10Q_DEVELOPMENT_CONTEXT_REFUSED', result.stderr.decode())

    def test_physical_prelaunch_requires_complete_current_safety_stages(self):
        # Invoke the actual prelaunch predicate through Library mode. No test
        # calls RunSmoke, launches a child, or supplies physical authority.
        receipt = ("$taskReceipts = @($stages | ForEach-Object { "
                   "@{id=$_.id;passed=$true;timed_out=$false;exit_code=0;"
                   "test_count=$_.tests;expected_test_count=$_.tests} }); ")
        cases = {
            'complete': '',
            'missing': '$taskReceipts = @(); ',
            'untyped_count': "$taskReceipts[-1].test_count = '4'; ",
            'crossed_candidate': "$stages[-1].candidate_profile = 'wrong.json'; ",
            'bound_common': "$stages[0].candidate_profile = $candidatePathRequested; ",
            'wrong_count': '$taskReceipts[-1].test_count = 0; ',
            'false_pass': '$taskReceipts[-1].passed = $false; ',
            'untyped_pass': "$taskReceipts[-1].passed = 'true'; ",
            'timeout': '$taskReceipts[-1].timed_out = $true; ',
            'missing_first_stage': '$stages = @($stages | Select-Object -Skip 1); $taskReceipts = @($taskReceipts | Select-Object -Skip 1); ',
            'crossed_pattern': "$stages[0].pattern = 'wrong.py'; ",
            'crossed_preparation_timeout': "($stages | Where-Object { $_.id -ceq 'r10q_preparation_report' }).timeout_seconds = 600; ",
            'missing_preparation': "$stages = @($stages | Where-Object { $_.id -cne 'r10q_preparation_report' }); ",
        }
        for label, mutation in cases.items():
            result = self.run_launcher('prelaunch-' + label, '-Library', receipt + mutation +
                'Assert-R10QPreparationSafety -CompletedStages $taskReceipts -SelectedStages $stages')
            if label == 'complete':
                self.assertEqual(0, result.returncode, result.stderr.decode())
            else:
                self.assertNotEqual(0, result.returncode)
                self.assertIn('R10Q_COMPLETE_PRODUCTION_SAFETY_GATE_PENDING', result.stderr.decode())
            self.assertNotIn('DEVELOPMENT_SMOKE_CHILD_START', result.stdout.decode())


if __name__ == '__main__':
    unittest.main()
