"""Successor host checks for the declared R10AC graph; Library mode only."""
import copy
import json
import unittest
import test_r10ac_host as previous
from test_r10ac_host import identity, host, entry, write
import r10ac_development_launch as launch


class R10ACSafetyHost(previous.R10ACHost):
    def test_historical_graph_absent_suite_cannot_launch(self):
        with self.assertRaisesRegex(unittest.SkipTest, 'graph-absent launch probe retired'):
            previous.R10ACHost.setUpClass()

    def test_actual_supervisor_declaration_and_deadlines(self):
        result=self.launcher('library','-SingleKick -Library',
            'ConvertTo-SporeSporeExactJson -Value ([ordered]@{fields=(Get-DevelopmentCandidateFields);worker=$script:WorkerResource;roles=$script:OrderedChildRoles;seed=$script:DevelopmentSeed;timeout=$TimeoutSeconds;godot=$Godot;ab=$r10abSelected;ac=$r10acSelected;stages=$stages})')
        self.assertEqual(0,result.returncode,result.stderr.decode());self.assertEqual(b'',result.stderr)
        actual=json.loads(result.stdout)
        declaration=copy.deepcopy(self.declaration)
        declaration['source_snapshot']['head']=self.before['head']
        declaration.update(actual['fields']);declaration['worker_resource']=actual['worker']
        # The supervisor adds these shared fields before applying candidate fields.
        declaration.update(context_cache_profile_id=entry.profile.CACHE_PROFILE_ID,
            context_cache_call_sites=entry.profile.CACHE_CALL_SITES,step_cost_profile_id=entry.profile.PROFILE_ID)
        self.assertEqual([identity.ROLE],actual['roles'])
        self.assertEqual((61248,2400,2400,1200),(actual['seed'],actual['timeout'],declaration['timeout_seconds_per_child'],declaration['independent_replay_timeout_seconds']))
        self.assertIs(actual['ac'],True);self.assertIs(actual['ab'],False)
        expected=[]
        self.assertTrue(all(spec.get('timeout_seconds',180)<=600 for spec in launch.contract()['stages']))
        for spec in launch.contract()['stages']:
            stage={k:spec[k] for k in ('id','pattern','tests')}
            if spec['candidate_bound']: stage['candidate_profile']=identity.reference()['resource'].removeprefix('res://')
            if 'timeout_seconds' in spec: stage['timeout_seconds']=spec['timeout_seconds']
            expected.append(stage)
        self.assertEqual(expected,actual['stages'])
        self.assertEqual(host.expected_binding()['images']['godot_console']['path'],actual['godot'])
        identity.validate_declaration(declaration)
        entry.validate_declaration(declaration)
        write(self.out/'supervisor-declaration-interface.json',declaration)

    def test_launch_stays_closed_and_old_options_do_not_cross(self):
        before=list(identity.EVIDENCE.glob('development-recovery-smoke-*/declaration.json'))
        for label,options,reason in [('paired','-Library','R10AC_DIAGNOSTIC_REQUIRES_SINGLE_KICK'),
            ('seed','-Library -SingleKick -R10VDiagnosticSeed 41341','R10V_OPTIONS_REQUIRE_R10V_ROUTE')]:
            result=self.launcher(label,options)
            self.assertNotEqual(0,result.returncode)
            self.assertIn(reason,result.stderr.decode())
        self.assertEqual(before,list(identity.EVIDENCE.glob('development-recovery-smoke-*/declaration.json')))
        self.assertEqual([],list(identity.EVIDENCE.glob('r10ac*consumption*.json')))


if __name__=='__main__':unittest.main()
