"""Actual PowerShell development declaration and pre-world refusals for R10V."""
import os
import subprocess
import sys
import unittest
import uuid

from test_development_r10v_complete_report import ROOT, EVIDENCE, PROFILE, declaration, candidate, development, entry, write

PWSH = 'C:/Program Files/PowerShell/7/pwsh.exe'


DISCOVERY_CODE = """import json,sys,unittest
loader=unittest.TestLoader()
suite=loader.discover(sys.argv[1], pattern=sys.argv[2])
print(json.dumps(dict(count=suite.countTestCases(), errors=loader.errors)))
"""


class R10VLauncher(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.out = EVIDENCE / ('development-r10v-launcher-' + uuid.uuid4().hex)
        cls.out.mkdir()
        cls.before = entry._source_snapshot()
        write(cls.out / 'source_before.json', cls.before)
        cls.reference = candidate.reference_for_path(PROFILE)
        print('R10V_LAUNCHER_EVIDENCE ' + str(cls.out), flush=True)

    @classmethod
    def tearDownClass(cls):
        after = entry._source_snapshot()
        write(cls.out / 'source_after.json', after)
        if after != cls.before:
            raise AssertionError('R10V_LAUNCHER_SOURCE_DRIFT')

    def run_launcher(self, label, options, output=''):
        relative = self.reference['resource'].removeprefix('res://')
        command = f". ./sdk/run_development_recovery_smoke.ps1 -ProfileSteps -ReuseContextChecks -CandidateProfile '{relative}' {options}"
        if output:
            command += '; ' + output
        args = [PWSH, '-NoProfile', '-NonInteractive', '-Command', command]
        result = subprocess.run(args, cwd=ROOT, capture_output=True, timeout=40, creationflags=subprocess.CREATE_NO_WINDOW)
        for stream, data in [('stdout', result.stdout), ('stderr', result.stderr)]:
            with (self.out / (label + '.' + stream + '.txt')).open('xb') as retained:
                retained.write(data)
        write(self.out / (label + '.execution.json'), dict(command=args, returncode=result.returncode))
        return result

    def discover_fresh(self, label, pattern, candidate_profile=None, start='tests'):
        # Match Invoke-DevelopmentStage's per-stage selection and keep parent
        # imports/PYTHONPATH from hiding missing imports in the child module.
        environment = dict(os.environ)
        environment.pop('PYTHONPATH', None)
        environment.pop('SPORESPORE_DEVELOPMENT_TEST_CANDIDATE', None)
        if candidate_profile:
            environment['SPORESPORE_DEVELOPMENT_TEST_CANDIDATE'] = candidate_profile
        args = [sys.executable, '-B', '-c', DISCOVERY_CODE, str(start), pattern]
        result = subprocess.run(args, cwd=ROOT, env=environment, capture_output=True,
            timeout=40, creationflags=subprocess.CREATE_NO_WINDOW)
        for stream, data in [('stdout', result.stdout), ('stderr', result.stderr)]:
            with (self.out / ('discovery-' + label + '.' + stream + '.txt')).open('xb') as retained:
                retained.write(data)
        self.assertEqual(0, result.returncode, result.stderr.decode())
        return entry.packet.parse_json(result.stdout.decode())

    def test_actual_initial_single_library_context_and_worker_declaration_agree(self):
        result = self.run_launcher('paired', '-Library',
            'ConvertTo-SporeSporeExactJson -Value ([ordered]@{fields=(Get-DevelopmentCandidateFields);'
            'worker=$script:WorkerResource;roles=$script:OrderedChildRoles;seed=$script:DevelopmentSeed;'
            'context=$r10vDevelopmentContext})')
        self.assertEqual(0, result.returncode, result.stderr.decode())
        selected = entry.packet.parse_json(result.stdout.decode())
        self.assertEqual(41345, selected['seed'])
        self.assertEqual(development.ROLES, selected['roles'])
        value = declaration(self.reference, self.before['head'])
        value.update(selected['fields'])
        value['worker_resource'] = selected['worker']
        value['r10v_development'] = selected['context']
        self.assertEqual(development.ROLES, development.validate_declaration(value)['roles'])
        from development_recovery_smoke import declared_schedule
        self.assertEqual(candidate.limits(candidate.selection(self.reference)), declared_schedule(value))
        self.assertEqual(self.reference, value['candidate_profile'])
        self.assertEqual(3752, value['maximum_steps_per_child'])
        self.assertFalse(value['comparative_authority'])
        self.assertFalse(value['baseline_reused'])
        write(self.out / 'paired-declaration.json', value)

    def test_actual_gate_selects_r10v_and_every_declared_test_exists(self):
        result = self.run_launcher('stage-selection', '-Library',
            'ConvertTo-SporeSporeExactJson -Value $stages')
        self.assertEqual(0, result.returncode, result.stderr.decode())
        stages = entry.packet.parse_json(result.stdout.decode())
        ids = [stage['id'] for stage in stages]
        self.assertEqual(len(ids), len(set(ids)))
        contract = entry.packet.parse_json((ROOT / 'sdk/development/r10v_safety_stage_contract_v3.json').read_text())
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
            observed = self.discover_fresh(stage['id'], stage['pattern'], stage.get('candidate_profile'))
            self.assertEqual([], observed['errors'], stage)
            counts[stage['id']] = observed['count']
            self.assertEqual(stage['tests'], counts[stage['id']], stage)
        # Import failure still counts as one unittest case. Prove the negative
        # control is rejected even when that misleading count looks correct.
        broken = self.out / 'broken-discovery'; broken.mkdir()
        with (broken / 'test_r10v_discovery_refusal.py').open('x') as stream:
            stream.write("raise ImportError('R10V_DISCOVERY_NEGATIVE_CONTROL')\n")
        refused = self.discover_fresh('negative-control', 'test_r10v_discovery_refusal.py', start=broken)
        self.assertEqual(1, refused['count'])
        self.assertEqual(1, len(refused['errors']))
        self.assertIn('R10V_DISCOVERY_NEGATIVE_CONTROL', refused['errors'][0])
        self.assertNotIn('test_development_v32_walking_policy.py', [stage['pattern'] for stage in stages])
        self.assertNotIn('candidate_walking_start', ids)
        self.assertNotIn('candidate_walking_entry', ids) # Both selected role adapters cover these controls.
        write(self.out / 'selected-stages.json', dict(stages=stages, discovered_test_counts=counts,
            test_count=sum(counts.values()), world_build_count=0, solver_step_count=0))

    def test_invalid_test_timeout_refuses_before_a_process_or_log_file(self):
        specs = [
            ('zero', 'never-launched', 'unused', 1, 0, False),
            ('boolean', 'never-launched', 'unused', 1, True, False),
            ('too-long', 'never-launched', 'unused', 1, 601, False),
            ('preparation-too-long', 'r10v_preparation_report', 'test_development_r10v_preparation_report.py', 2, 901, False),
            ('crossed-pattern', 'r10v_preparation_report', 'unused.py', 2, 601, False),
            ('crossed-count', 'r10v_preparation_report', 'test_development_r10v_preparation_report.py', 1, 601, False),
            ('hold-too-long', 'r10v_complete_hold_report', 'test_r10v_complete_hold_report.py', 2, 901, False),
            ('crossed-old-id', 'r10s_preparation_report', 'test_development_r10v_preparation_report.py', 2, 601, False),
            ('crossed-hold-pattern', 'r10v_complete_hold_report', 'test_development_r10v_preparation_report.py', 2, 601, False),
            ('accepted-preparation', 'r10v_preparation_report', 'test_development_r10v_preparation_report.py', 2, 900, True),
            ('accepted-hold', 'r10v_complete_hold_report', 'test_r10v_complete_hold_report.py', 2, 900, True),
            ('accepted-r10v_preparation_refusals', 'r10v_preparation_refusals', 'test_development_r10v_preparation_refusals.py', 1, 900, True),
            ('accepted-r10v_preparation_positive', 'r10v_preparation_positive', 'test_development_r10v_preparation_positive.py', 1, 900, True),
            ('accepted-r10v_ready_hold_report', 'r10v_ready_hold_report', 'test_development_r10v_ready_hold_report.py', 1, 900, True),
            ('accepted-r10v_timeout_hold_report', 'r10v_timeout_hold_report', 'test_development_r10v_timeout_hold_report.py', 1, 900, True),
            ('single-report-too-long', 'r10v_ready_hold_report', 'test_development_r10v_ready_hold_report.py', 1, 901, False),
            ('single-report-wrong-count', 'r10v_ready_hold_report', 'test_development_r10v_ready_hold_report.py', 2, 601, False),
            ('single-report-wrong-pattern', 'r10v_ready_hold_report', 'unused.py', 1, 601, False),
        ]
        cases = []
        for label, stage_id, pattern, tests, seconds, accepted in specs:
            directory = self.out / ('timeout-case-' + label); directory.mkdir()
            # Every case has an exclusive-file barrier before Process.Start,
            # including invalid caps if the timeout validator ever regresses.
            (directory / (stage_id + '.stdout.log')).write_bytes(b'preexisting exclusive log\n')
            cases.append(dict(id=label, directory=directory.as_posix(), accepted=accepted,
                integer_timeout=type(seconds) is int,
                stage=dict(id=stage_id, pattern=pattern, tests=tests, timeout_seconds=seconds)))
        path = self.out / 'timeout-cases.json'; write(path, cases)
        command = ("$taskCases = Get-Content -Raw -LiteralPath '" + path.as_posix() + "' | ConvertFrom-Json -AsHashtable; "
            "$taskResults = @(foreach ($case in $taskCases) { $stage = $case.stage; $stage.tests = [int]$stage.tests; "
            "if ($case.integer_timeout) { $stage.timeout_seconds = [int]$stage.timeout_seconds }; "
            "try { $null = Invoke-DevelopmentStage $stage $case.directory; throw 'UNEXPECTED_STAGE_COMPLETION' } "
            "catch { if ($case.accepted) { if ($_.Exception.InnerException -isnot [IO.IOException]) { throw }; "
            "@{id=$case.id;accepted=$true;boundary='exclusive_log'} } else { "
            "if ($_.Exception.Message -cne 'DEVELOPMENT_STAGE_TIMEOUT_INVALID') { throw }; "
            "@{id=$case.id;accepted=$false;boundary='timeout_validation'} } } }); "
            "ConvertTo-SporeSporeExactJson -Value @{cases=$taskResults;world_build_count=0;test_process_start_count=0}")
        result = self.run_launcher('timeout-boundaries', '-Library', command)
        self.assertEqual(0, result.returncode, result.stderr.decode())
        observed = entry.packet.parse_json(result.stdout.decode())
        self.assertEqual([dict(id=c['id'], accepted=c['accepted'],
            boundary='exclusive_log' if c['accepted'] else 'timeout_validation') for c in cases], observed['cases'])
        self.assertEqual((0, 0), (observed['world_build_count'], observed['test_process_start_count']))
        for case in cases:
            directory = self.out / ('timeout-case-' + case['id']); stage_id = case['stage']['id']
            self.assertEqual(b'preexisting exclusive log\n', (directory / (stage_id + '.stdout.log')).read_bytes())
            self.assertFalse((directory / (stage_id + '.stderr.log')).exists())
        write(self.out / 'timeout-boundaries.json', observed)

    def test_later_stages_refuse_without_the_required_retained_positive_result(self):
        for label, options, code in [
            ('single-first-refused', '-Library -SingleKick', 'MODE_SEED'),
            ('branch-without-pair', '-Library -SingleKick -R10VDiagnosticSeed 41343', 'ADDITIONAL_SINGLE_REQUIRES_POSITIVE_PAIR'),
            ('undeclared-seed', '-Library -SingleKick -R10VDiagnosticSeed 40200', 'R10V_DEVELOPMENT_CONTEXT_REFUSED'),
            ('wrong-pair-seed', '-Library -R10VDiagnosticSeed 41346', 'MODE_SEED'),
            ('initial-with-prerequisite', '-Library -R10VPrerequisite never-created', 'INITIAL_PAIR_HAS_PREREQUISITE')]:
            result = self.run_launcher(label, options)
            self.assertNotEqual(0, result.returncode)
            self.assertIn(code, result.stderr.decode())
            self.assertNotIn('DEVELOPMENT_SMOKE_CHILD_START', result.stdout.decode())

    def test_physical_prelaunch_requires_complete_current_safety_stages(self):
        # Invoke the actual prelaunch predicate through Library mode. No test
        # calls RunSmoke, launches a child, or supplies physical authority.
        receipt = ("$taskReceipts = @($stages | ForEach-Object { "
                   "@{id=$_.id;passed=$true;timed_out=$false;exit_code=0;"
                   "test_count=$_.tests;expected_test_count=$_.tests} }); ")
        cases = {
            'complete': '',
            'serialized_prehost': "foreach ($i in @(-2,-1)) { $taskReceipts[$i] = ((ConvertTo-SporeSporeExactJson -Value $taskReceipts[$i]) | ConvertFrom-Json -AsHashtable) }; ",
            'serialized_all': "$taskReceipts = @((ConvertTo-SporeSporeExactJson -Value $taskReceipts) | ConvertFrom-Json -AsHashtable); ",
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
            'crossed_preparation_timeout': "($stages | Where-Object { $_.id -ceq 'r10v_preparation_positive' }).timeout_seconds = 600; ",
            'crossed_native_timeout': "($stages | Where-Object { $_.id -ceq 'r10v_native_control' }).timeout_seconds = 180; ",
            'missing_preparation': "$stages = @($stages | Where-Object { $_.id -cne 'r10v_preparation_positive' }); ",
        }
        # Values equal the expected numeric value, but their types must refuse.
        for field, number in [('test_count',1),('expected_test_count',1),('exit_code',0)]:
            for kind, value in [('string',"'"+str(number)+"'"),('float','[double]'+str(number)),
                                ('boolean','$true' if number else '$false')]:
                cases[field+'_'+kind] = '$taskReceipts[-1].'+field+' = '+value+'; '
        cases['serialized_wrong_count'] = cases['serialized_prehost'] + '$taskReceipts[-1].test_count = [long]2; '
        case_path = self.out / 'prelaunch-cases.json'
        write(case_path, [dict(id=label, mutation=mutation) for label, mutation in cases.items()])
        command = ("$taskOriginalStages = ConvertTo-SporeSporeExactJson -Value $stages; "
            "$taskCases = Get-Content -Raw -LiteralPath '" + case_path.as_posix() + "' | ConvertFrom-Json -AsHashtable; "
            "$taskResults = @(foreach ($case in $taskCases) { "
            "$stages = @($taskOriginalStages | ConvertFrom-Json -AsHashtable); "
            # JSON decoding uses Int64; restore the production graph's typed counts.
            "foreach ($stage in $stages) { $stage.tests = [int]$stage.tests; "
            "if ($stage.ContainsKey('timeout_seconds')) { $stage.timeout_seconds = [int]$stage.timeout_seconds } }; "
            + receipt +
            "if ($case.mutation) { Invoke-Expression $case.mutation }; "
            "try { Assert-R10VPreparationSafety -CompletedStages $taskReceipts -SelectedStages $stages; "
            "@{id=$case.id;accepted=$true;failure=''} } catch { "
            "@{id=$case.id;accepted=$false;failure=$_.Exception.Message} } }); "
            "ConvertTo-SporeSporeExactJson -Value @{cases=$taskResults;world_build_count=0}")
        result = self.run_launcher('prelaunch-controls', '-Library', command)
        self.assertEqual(0, result.returncode, result.stderr.decode())
        observed = entry.packet.parse_json(result.stdout.decode())
        self.assertEqual(list(cases), [case['id'] for case in observed['cases']])
        for case in observed['cases']:
            self.assertEqual(case['id'] in ('complete','serialized_prehost','serialized_all'), case['accepted'], case)
            self.assertEqual('' if case['accepted'] else 'R10V_COMPLETE_PRODUCTION_SAFETY_GATE_PENDING',
                case['failure'], case)
        self.assertEqual(0, observed['world_build_count'])
        self.assertNotIn('DEVELOPMENT_SMOKE_CHILD_START', result.stdout.decode())
        write(self.out / 'prelaunch-controls.json', observed)



if __name__ == '__main__':
    unittest.main()
