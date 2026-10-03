"""Actual diagnostic host/launcher interfaces and crossed-input refusals; no world."""
import copy
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import unittest
from unittest import mock
import uuid

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'sdk/conformance'))
import r10af_host_runtime as host
import r10af_replay_host as replay
import r10af_development as identity
import r10af_selection_check as fixtures
import development_passive_entry_profile as entry


def write(path, value):
    with path.open('x', encoding='utf-8', newline='\n') as stream:
        json.dump(value, stream, indent=2); stream.write('\n')


class R10AFHost(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.out = identity.EVIDENCE / ('r10af-host-check-' + uuid.uuid4().hex)
        cls.out.mkdir()
        cls.before = entry._source_snapshot()
        write(cls.out / 'source-before.json', cls.before)
        cls.fixed = fixtures.fixture()
        cls.chosen = cls.fixed['selection']
        cls.declaration = copy.deepcopy(cls.fixed['declaration'])
        cls.declaration['runtime'] = host.expected_binding()
        print('R10AF_HOST_CHECK_ROOT ' + str(cls.out), flush=True)

    @classmethod
    def tearDownClass(cls):
        after = entry._source_snapshot()
        write(cls.out / 'source-after.json', after)
        assert after == cls.before

    def powershell(self, label, code):
        command = [host.expected_binding()['images']['powershell_host']['path'],
            '-NoProfile', '-NonInteractive', '-Command', "$ErrorActionPreference='Stop'; " + code]
        result = subprocess.run(command, cwd=ROOT, capture_output=True, timeout=60,
            creationflags=subprocess.CREATE_NO_WINDOW)
        for stream in ('stdout', 'stderr'):
            (self.out / (label + '.' + stream + '.txt')).write_bytes(getattr(result, stream))
        write(self.out / (label + '.execution.json'), dict(command=command, returncode=result.returncode,
            world_build_count=0, solver_step_count=0))
        return result

    def launcher(self, label, options, expression=''):
        code = ". ./sdk/run_development_recovery_smoke.ps1 -ProfileSteps -ReuseContextChecks -CandidateProfile '" + identity.reference()['resource'].removeprefix('res://') + "' " + options
        if expression: code += '; ' + expression
        return self.powershell(label, code)

    def test_actual_images_and_cross_language_runtime_binding(self):
        expected = host.expected_binding()
        with mock.patch.object(host.predecessor, 'file_identity', wraps=host.predecessor.file_identity) as reader:
            actual = host.bind_runtime(expected['images']['godot_console']['path'], expected['images']['powershell_host']['path'])
        self.assertEqual(8, reader.call_count)
        self.assertEqual(expected, actual)
        self.assertNotIn('qualified_native_foundation', actual)
        host.predecessor.validate_binding(actual)
        result = self.powershell('runtime', ". ./sdk/qsdk_r10f_l14_runtime_binding.ps1; . ./sdk/r10af_host_runtime.ps1; $b=Get-R10afRuntimeBinding -Godot (Get-R10afExpectedRuntimeBinding).images.godot_console.path; Assert-QsdkR10fL14RuntimeBinding $b; ConvertTo-Json -Depth 100 -Compress -InputObject $b")
        self.assertEqual(0, result.returncode, result.stderr.decode())
        self.assertEqual(b'', result.stderr)
        self.assertEqual(actual, json.loads(result.stdout))
        write(self.out / 'runtime-binding.json', actual)

    def test_every_runtime_field_is_required_and_type_strict(self):
        original = host.expected_binding()
        mutations = []
        def visit(value, prefix=()):
            for key, child in value.items():
                path = (*prefix, key)
                changed = copy.deepcopy(original); at = changed
                for part in prefix: at = at[part]
                del at[key]; mutations.append(changed)
                if isinstance(child, dict): visit(child, path)
                elif type(child) is bool:
                    changed = copy.deepcopy(original); at = changed
                    for part in prefix: at = at[part]
                    at[key] = int(child); mutations.append(changed)
                elif type(child) is int:
                    changed = copy.deepcopy(original); at = changed
                    for part in prefix: at = at[part]
                    at[key] = float(child); mutations.append(changed)
        visit(original)
        for role in original['images']:
            changed = copy.deepcopy(original)
            changed['images'][role]['raw_sha256'] = 'sha256:' + '0'*64
            mutations.append(changed)
        changed=copy.deepcopy(original);changed['physical_execution_authorized']=True;mutations.append(changed)
        changed=copy.deepcopy(original);changed['extra']=True;mutations.append(changed)
        for changed in mutations:
            with self.assertRaises(ValueError): host.predecessor.validate_binding(changed)
        write(self.out/'runtime-mutations.json', mutations)
        result=self.powershell('runtime-mutations', ". ./sdk/qsdk_r10f_l14_runtime_binding.ps1; $rows=Get-Content -Raw '"+(self.out/'runtime-mutations.json').as_posix()+"' | ConvertFrom-Json -AsHashtable -Depth 100; $count=0; foreach($row in $rows){$refused=$false;try {Assert-QsdkR10fL14RuntimeBinding $row}catch {$refused=$true};if(-not $refused){throw 'Mutation admitted'};$count++}; $count")
        self.assertEqual(0,result.returncode,result.stderr.decode())
        self.assertEqual(len(mutations),int(result.stdout))

    def test_missing_changed_images_and_crossed_paths_refuse(self):
        expected=host.expected_binding()
        for wrong in (expected['images']['godot_engine']['path'],host.predecessor.IMAGES['godot_console']['path']):
            with self.assertRaisesRegex(ValueError,'HOST_SELECTED_PATH'):
                host.bind_runtime(wrong,expected['images']['powershell_host']['path'])
        original=host.predecessor.file_identity
        for role in expected['images']:
            for missing in (False,True):
                def changed(path, **kwargs):
                    if Path(path)==Path(expected['images'][role]['path']):
                        if missing: raise FileNotFoundError('synthetic missing image')
                        return dict(expected['images'][role],raw_sha256='sha256:'+'0'*64)
                    return original(path,**kwargs)
                with mock.patch.object(host.predecessor,'file_identity',side_effect=changed):
                    with self.assertRaises((ValueError,FileNotFoundError)):
                        host.bind_runtime(expected['images']['godot_console']['path'],expected['images']['powershell_host']['path'])
        # The shared validator supports the relationship; official v6 rebinding
        # still refuses the diagnostic engine and cannot recycle qualification.
        with self.assertRaises(ValueError):
            host.predecessor.verify_qualified_binding(expected,Path(expected['images']['godot_console']['path']))
        host.predecessor.validate_binding(host.predecessor.expected_binding())
        host.predecessor.validate_binding(host.predecessor.historical_expected_binding())

    def test_actual_supervisor_declaration_and_deadlines(self):
        result=self.launcher('library','-SingleKick -Library',
            'ConvertTo-SporeSporeExactJson -Value ([ordered]@{fields=(Get-DevelopmentCandidateFields);worker=$script:WorkerResource;roles=$script:OrderedChildRoles;seed=$script:DevelopmentSeed;timeout=$TimeoutSeconds;godot=$Godot;ab=$r10abSelected;ad=$r10afSelected;ac=$r10acSelected;stages=$stages})')
        self.assertEqual(0,result.returncode,result.stderr.decode());self.assertEqual(b'',result.stderr)
        actual=json.loads(result.stdout)
        declaration=copy.deepcopy(self.declaration)
        declaration['source_snapshot']['head']=self.before['head']
        declaration.update(actual['fields']);declaration['worker_resource']=actual['worker']
        # The supervisor adds these shared fields before applying candidate fields.
        declaration.update(context_cache_profile_id=entry.profile.CACHE_PROFILE_ID,
            context_cache_call_sites=entry.profile.CACHE_CALL_SITES,step_cost_profile_id=entry.profile.PROFILE_ID)
        self.assertEqual([identity.ROLE],actual['roles'])
        self.assertEqual((64248,2400,2400,1200),(actual['seed'],actual['timeout'],declaration['timeout_seconds_per_child'],declaration['independent_replay_timeout_seconds']))
        self.assertIs(actual['ad'],True);self.assertIs(actual['ac'],False);self.assertIs(actual['ab'],False)
        import r10af_development_launch as launch
        expected=[]
        if launch.CONTRACT.exists():
            for spec in launch.contract()['stages']:
                stage={k:spec[k] for k in ('id','pattern','tests')}
                if spec['candidate_bound']:stage['candidate_profile']=identity.reference()['resource'].removeprefix('res://')
                if 'timeout_seconds' in spec:stage['timeout_seconds']=spec['timeout_seconds']
                expected.append(stage)
        self.assertEqual(expected,actual['stages'])
        self.assertEqual(host.expected_binding()['images']['godot_console']['path'],actual['godot'])
        identity.validate_declaration(declaration)
        entry.validate_declaration(declaration)
        write(self.out/'supervisor-declaration-interface.json',declaration)

    def test_launch_stays_closed_and_old_options_do_not_cross(self):
        before=list(identity.EVIDENCE.glob('development-recovery-smoke-*/declaration.json'))
        for label,options,reason in [('paired','-Library','R10AF_DIAGNOSTIC_REQUIRES_SINGLE_KICK'),
            ('seed','-Library -SingleKick -R10VDiagnosticSeed 41341','R10V_OPTIONS_REQUIRE_R10V_ROUTE')]:
            result=self.launcher(label,options)
            self.assertNotEqual(0,result.returncode)
            self.assertIn(reason,result.stderr.decode())
        self.assertEqual(before,list(identity.EVIDENCE.glob('development-recovery-smoke-*/declaration.json')))
        self.assertEqual([],list(identity.EVIDENCE.glob('r10af*consumption*.json')))

    def test_report_command_has_exact_declared_child_engine_and_four_arguments(self):
        declaration=self.declaration
        report_path=Path(declaration['children'][0]['evidence_path'])/'worker_report.json'
        declared=report_path.parent.parent.parent/'declaration.json'
        raw=json.dumps(declaration).encode()
        bound=dict(path=declared.as_posix(),byte_length=len(raw),raw_sha256='sha256:'+hashlib.sha256(raw).hexdigest())
        original=Path.read_text
        def read(path,*args,**kwargs):
            return raw.decode() if path==declared else original(path,*args,**kwargs)
        with mock.patch.object(Path,'read_text',read),mock.patch.object(host.predecessor,'file_identity',return_value=bound):
            plan=replay.plan(report_path,self.chosen,self.fixed['report'])
            command=entry._command(report_path,self.chosen,plan)
            self.assertEqual(1200,plan['timeout_seconds'])
            self.assertEqual(host.expected_binding()['images']['godot_engine']['path'],command[0])
            self.assertEqual([str(report_path),identity.reference()['resource'],identity.PROFILE_SHA,str(declared)],command[command.index('--')+1:])
            crossed=copy.deepcopy(self.fixed['report']);crossed['child_attempt_id']='0'*32
            with self.assertRaisesRegex(ValueError,'REPORT_CHILD'):replay.plan(report_path,self.chosen,crossed)
            with self.assertRaises(ValueError):replay.plan(report_path.parent.parent/'other/worker_report.json',self.chosen)
        for mutation in ('runtime','r10ab_development','candidate_profile','seed'):
            changed=copy.deepcopy(declaration)
            if mutation=='runtime':changed[mutation]=host.predecessor.expected_binding()
            elif mutation=='seed':changed[mutation]=51008
            else:changed[mutation]={}
            with self.assertRaises(ValueError):replay.deadlines(self.chosen,changed)
        legacy=entry.selection()
        self.assertEqual(host.predecessor.IMAGES['godot_engine'],entry._replay_host(report_path,legacy)['engine_image'])
        self.assertEqual(900,entry._replay_host(report_path,legacy)['timeout_seconds'])

    def test_independent_contact_result_requires_both_readers(self):
        path=self.out/'synthetic-declaration.json';write(path,self.declaration)
        report=self.fixed['report']
        result=dict(controller_and_diagnostic_replay_passed=True,r10af_contact_frame_replay=self.fixed['diagnostic_expected'])
        self.assertEqual(self.fixed['diagnostic_expected'],replay.independent_result(report,path,result))
        for changed in ({},dict(result,controller_and_diagnostic_replay_passed=1),
            dict(result,r10af_contact_frame_replay=dict(self.fixed['diagnostic_expected'],classification_changes=999))):
            with self.assertRaises(ValueError):replay.independent_result(report,path,changed)
        changed=copy.deepcopy(report);changed['r10af_contact_frame_links']['records'].pop()
        with self.assertRaises(ValueError):replay.independent_result(changed,path,result)


if __name__=='__main__':unittest.main()
