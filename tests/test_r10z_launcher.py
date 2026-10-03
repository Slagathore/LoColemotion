"""Actual PowerShell R10Z declaration and pre-world refusal boundaries."""
import json
import subprocess
import unittest
import uuid

import test_development_r10z_complete_report as shared


class R10ZLauncher(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.out = shared.native.EVIDENCE / ('r10z-launcher-' + uuid.uuid4().hex)
        cls.out.mkdir()
        cls.before = shared.entry._source_snapshot()
        shared.write(cls.out / 'source_before.json', cls.before)
        cls.reference = shared.candidate.reference_for_path(shared.PROFILE)
        print('R10Z_LAUNCHER_ROOT ' + str(cls.out), flush=True)

    @classmethod
    def tearDownClass(cls):
        after = shared.entry._source_snapshot()
        shared.write(cls.out / 'source_after.json', after)
        assert after == cls.before

    def run_launcher(self, label, options, output=''):
        profile = self.reference['resource'].removeprefix('res://')
        code = f". ./sdk/run_development_recovery_smoke.ps1 -ProfileSteps -ReuseContextChecks -CandidateProfile '{profile}' {options}"
        if output: code += '; ' + output
        command = ['C:/Program Files/PowerShell/7/pwsh.exe', '-NoProfile', '-NonInteractive', '-Command', code]
        result = subprocess.run(command, cwd=shared.ROOT, capture_output=True, timeout=60,
            creationflags=subprocess.CREATE_NO_WINDOW)
        for name in ('stdout', 'stderr'):
            with (self.out / (label + '.' + name + '.txt')).open('xb') as stream: stream.write(getattr(result, name))
        shared.write(self.out / (label + '.execution.json'), dict(command=command, returncode=result.returncode,
            world_build_count=0, solver_step_count=0))
        return result

    def test_actual_library_declaration_matches_python_population_and_deadline(self):
        result = self.run_launcher('single', '-Library -SingleKick',
            'ConvertTo-SporeSporeExactJson -Value ([ordered]@{fields=(Get-DevelopmentCandidateFields);'
            'worker=$script:WorkerResource;roles=$script:OrderedChildRoles;seed=$script:DevelopmentSeed;'
            'label=$script:DevelopmentSeedLabel;digest=$script:DevelopmentSeedSha256;timeout=$TimeoutSeconds})')
        self.assertEqual(0, result.returncode, result.stderr.decode())
        selected = json.loads(result.stdout)
        value = shared.declaration(self.reference, self.before['head'])
        value.update(selected['fields']); value['worker_resource'] = selected['worker']
        self.assertEqual(shared.development.ROLES, selected['roles'])
        self.assertEqual((51008, 1740, 1740, 900), (selected['seed'], selected['timeout'],
            value['timeout_seconds_per_child'], value['independent_replay_timeout_seconds']))
        identity = shared.development.seed_identity(51008)
        self.assertEqual((identity['label'], identity['sha256']), (selected['label'], selected['digest']))
        self.assertEqual(shared.development.ROLES, shared.development.validate_declaration(value)['roles'])
        from development_recovery_smoke import declared_schedule
        self.assertEqual(shared.candidate.limits(shared.candidate.selection(self.reference)), declared_schedule(value))
        shared.write(self.out / 'selected-declaration.json', value)

    def test_paired_and_historical_options_refuse_before_execution(self):
        for label, options, expected in (
            ('paired', '-Library', 'R10Z_FIRST_DIAGNOSTIC_REQUIRES_SINGLE_KICK'),
            ('old-seed', '-Library -SingleKick -R10VDiagnosticSeed 41341', 'R10V_OPTIONS_REQUIRE_R10V_ROUTE'),
            ('old-host', '-Library -SingleKick -R10VHostRequest missing.json', 'R10V_HOST_OPTIONS_REQUIRE_R10V_ROUTE'),
            ('campaign', '-Library -SingleKick -R10XCampaignLibrary', 'R10X_CAMPAIGN_LIBRARY_ONLY')):
            result = self.run_launcher(label, options)
            self.assertNotEqual(0, result.returncode)
            self.assertIn(expected, result.stderr.decode())

    def test_complete_stage_selection_and_fresh_discovery(self):
        import os
        import sys
        from r10z_development_launch import contract
        fixed = contract()
        result = self.run_launcher('stage-selection', '-Library -SingleKick',
            'ConvertTo-SporeSporeExactJson -Value $stages')
        self.assertEqual(0, result.returncode, result.stderr.decode())
        selected = json.loads(result.stdout)
        self.assertEqual(len(fixed['stages']), len(selected))
        counts = {}
        code = "import json,sys,unittest; loader=unittest.TestLoader(); suite=loader.discover('tests',pattern=sys.argv[1]); print(json.dumps(dict(count=suite.countTestCases(),errors=loader.errors)))"
        for spec, stage in zip(fixed['stages'], selected, strict=True):
            self.assertEqual({k: spec[k] for k in ('id','pattern','tests')},
                {k: stage[k] for k in ('id','pattern','tests')})
            if spec['candidate_bound']:
                self.assertEqual(self.reference['resource'].removeprefix('res://'), stage['candidate_profile'])
            else:
                self.assertNotIn('candidate_profile', stage)
            self.assertEqual(spec.get('timeout_seconds'), stage.get('timeout_seconds'))
            environment = dict(os.environ)
            environment.pop('PYTHONPATH', None)
            environment.pop('SPORESPORE_DEVELOPMENT_TEST_CANDIDATE', None)
            if spec['candidate_bound']:
                environment['SPORESPORE_DEVELOPMENT_TEST_CANDIDATE'] = stage['candidate_profile']
            discovered = subprocess.run([sys.executable, '-B', '-c', code, spec['pattern']],
                cwd=shared.ROOT, env=environment, capture_output=True, timeout=40,
                creationflags=subprocess.CREATE_NO_WINDOW)
            for stream in ('stdout','stderr'):
                (self.out / ('discovery-' + spec['id'] + '.' + stream + '.txt')).write_bytes(getattr(discovered,stream))
            self.assertEqual(0, discovered.returncode, discovered.stderr.decode())
            value = json.loads(discovered.stdout)
            self.assertEqual([], value['errors'], spec['id'])
            self.assertEqual(spec['tests'], value['count'], spec['id'])
            counts[spec['id']] = value['count']
        self.assertEqual(fixed['total_tests'], sum(counts.values()))
        shared.write(self.out / 'stage-discovery.json', dict(stages=selected, discovered_tests=counts,
            total_tests=sum(counts.values()), world_build_count=0, solver_step_count=0))


if __name__ == '__main__': unittest.main()
