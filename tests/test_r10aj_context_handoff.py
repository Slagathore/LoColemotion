"""Real candidate/launcher environment/context handoff before any reservation."""
import copy,json,subprocess,sys,unittest,uuid
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT/'sdk/conformance'))
import r10aj_context_handoff as handoff
import r10aj_selection_check as fixtures
import development_passive_entry_profile as entry

class Handoff(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.root=handoff.EVIDENCE/('r10aj-handoff-'+uuid.uuid4().hex);cls.root.mkdir()
        cls.before=entry._source_snapshot();handoff.write(cls.root/'source-before.json',cls.before)
        cls.tokens={p.name:handoff.bind(p) for p in handoff.EVIDENCE.glob('*consumption*.json')}
        print('R10AJ_HANDOFF_ROOT '+str(cls.root),flush=True)
        cls.value=fixtures.fixture()['declaration'];cls.value['source_snapshot']['head']=cls.before['head']
        identity=handoff.identity
        cls.value[identity.CONTEXT_KEY]=identity.context(identity.SINGLE,cls.before['head'],identity.reference())
        cls.value.update(cls.ps('fields','ConvertTo-SporeSporeExactJson -Value (Get-DevelopmentCandidateFields)'))
        cls.value.update(worker_resource='res://sdk/adapters/godot/gdscript/r10aj_development_worker_v1.gd',
            runtime=handoff.host.expected_binding(),context_cache_profile_id=entry.profile.CACHE_PROFILE_ID,
            context_cache_call_sites=entry.profile.CACHE_CALL_SITES,step_cost_profile_id=entry.profile.PROFILE_ID,
            prepared_context_expectation=None,safety_stages=[])
        proposal=cls.root/'r10aj_context_proposal.json';handoff.write(proposal,cls.value)
        prepared=handoff.prepare(proposal)
        cls.value['prepared_context_expectation']=prepared['expectation'];cls.value['r10aj_context_producer']=prepared['producer']
        cls.declaration=cls.root/'declaration.json';handoff.write(cls.declaration,cls.value)
        code="$d=Get-Content -LiteralPath '"+cls.declaration.as_posix()+"' -Raw | ConvertFrom-Json -AsHashtable -Depth 100; $script:RepairId='QSDK-R10F-L15'; $script:PhysicalAttemptId=$d.attempt_id; $b=@{authority=@{source_commit=$d.source_snapshot.head};authority_sha256=(Get-PrefixedSha256 '"+cls.declaration.as_posix()+"');l14_exact_runtime_images=$d.runtime;l15_prepared_context_expectation=$d.prepared_context_expectation}; ConvertTo-SporeSporeExactJson -Value (New-QsdkR10fL9ChildEnvironment -Descriptor $d.children[0] -Binding $b)"
        cls.environment=cls.root/'environment.json';handoff.write(cls.environment,cls.ps('environment',code))
        cls.result=handoff.consume(cls.declaration,cls.environment)
    @classmethod
    def ps(cls,name,expression):
        command=[handoff.host.expected_binding()['images']['powershell_host']['path'],'-NoProfile','-NonInteractive','-Command',
            "$ErrorActionPreference='Stop'; . ./sdk/run_development_recovery_smoke.ps1 -Library -SingleKick -ProfileSteps -ReuseContextChecks -CandidateProfile sdk/development/recovery_candidates/r10aj-hip-recenter-v1.json; "+expression]
        run=subprocess.run(command,cwd=ROOT,capture_output=True,timeout=90,creationflags=subprocess.CREATE_NO_WINDOW)
        for stream in ['stdout','stderr']:(cls.root/(name+'.'+stream+'.log')).write_bytes(getattr(run,stream))
        handoff.write(cls.root/(name+'.execution.json'),dict(command=command,exit_code=run.returncode))
        assert run.returncode==0 and run.stderr==b'',run.stderr.decode(errors='replace')
        return json.loads(run.stdout)
    @classmethod
    def tearDownClass(cls):
        after=entry._source_snapshot();handoff.write(cls.root/'source-after.json',after);assert cls.before==after
        assert cls.tokens=={p.name:handoff.bind(p) for p in handoff.EVIDENCE.glob('*consumption*.json')}
        assert not Path(cls.value['children'][0]['evidence_path']).exists()
    def test_actual_initializer_environment_and_pre_world_handoff(self):
        self.assertIs(self.result['ok'],True)
        self.assertEqual(self.result['receipt'],handoff.verify(self.declaration))
        observed=handoff.read(self.root/'r10aj_pre_world_consumption/consumer.json')
        self.assertIs(observed['construction_boundary_reached'],True)
        self.assertIs(observed['authority_claim_replaced_by_read_only_identity'],True)
    def test_consumer_result_cannot_hide_context_or_world_failure(self):
        original=handoff.read(self.root/'r10aj_pre_world_consumption/consumer.json')
        for field,value in [('world_build_count',1),('solver_step_count',False),('construction_boundary_reached',False),('candidate_profile',{})]:
            changed=copy.deepcopy(original);changed[field]=value
            with self.subTest(field=field),self.assertRaises(ValueError):handoff.validate_consumer(changed,self.value)
    def test_producer_context_and_retained_binding_are_required(self):
        result=handoff.read(self.root/'r10aj_context_production/producer.json')
        changed=copy.deepcopy(result);changed['capture']['raw_sha256']='sha256:'+'0'*64
        with self.assertRaisesRegex(ValueError,'CAPTURE_HASH'):handoff.expectation(changed)
        ref=copy.deepcopy(self.result['receipt']);ref['raw_sha256']='sha256:'+'0'*64
        with self.assertRaisesRegex(ValueError,'RETAINED_BYTES'):handoff.verify_binding(ref)

if __name__=='__main__':unittest.main()
