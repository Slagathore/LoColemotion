"""Native posture route, evidence boundary and corruption/refusal controls."""
import copy,os
from pathlib import Path
from types import SimpleNamespace
import unittest
from unittest.mock import patch
import numpy as np
import dynamic_control_native_task as task
from dynamic_control_native import preflight
from dynamic_control_native_trial import transfer_targets
from audit_dynamic_control_native import compare_pair,compare_baseline
from support_reach_force_policy import Policy as HoldPolicy
from dynamic_force_policy_v2 import Policy as ReachPolicy


class NativeReachControls(unittest.TestCase):
    def setUp(self):
        self.c=task.declaration();self.source="0"*40;self.attempt="sdk2-dynamic-control-native-synthetic"
        self.owner=dict(source_commit=self.source,contract=self.c,planned_trials=task.plans(self.c),
            source_status=[],component_only=False,**{k:False for k in task.FLAGS})
        self.gate=dict(ok=True,source_commit=self.source,declaration_sha256="declaration",
            safety_controls={**{n:k for n,_,k in task.GATES},"provider":2,"containment":1},
            preflight=dict(ok=True,world_build_count=0,solver_steps=0,component_evidence_verified=True))
        self.consumed=dict(attempt_id=self.attempt,source_commit=self.source,contract_sha256=task.sha(task.CONTRACT),
            declaration_sha256="declaration",gate_receipt_sha256="gate",trials=task.plans(self.c))

    def validate(self):
        task.validate_launch_documents(self.owner,self.gate,self.consumed,self.c,self.source,self.attempt,"declaration","gate")

    def test_complete_launch_documents(self):
        self.validate();self.assertEqual(sum(self.gate["safety_controls"].values()),task.EXPECTED_CONTROLS)

    def test_four_fresh_exposed_worlds_and_fixed_horizon(self):
        plans=task.plans(self.c)
        self.assertEqual(len(plans),4);self.assertEqual(len({p["trial_id"] for p in plans}),4)
        self.assertEqual({p["role"] for p in plans},{"reach_hold","dynamic_hold"})
        self.assertTrue(all(p["start_id"]=="train_001" and p["seed"]==104242001 for p in plans))
        self.assertEqual(self.c["outer_steps"],1440);self.assertEqual(self.c["horizon_s"],12.)

    def test_changed_scope_is_refused(self):
        for change in (dict(roles=["dynamic_hold"]),dict(groups=["nominal_train_003"]),dict(outer_steps=1441),
            dict(horizon_s=1.),dict(planned_cpu_worlds=2)):
            with self.assertRaises(ValueError):task.plans(dict(self.c,**change))

    def test_dirty_source_cannot_launch(self):
        self.owner["source_status"]=[" M unexpected.py"]
        with self.assertRaises(ValueError):self.validate()

    def test_component_only_cannot_launch(self):
        self.owner["component_only"]=True
        with self.assertRaises(ValueError):self.validate()

    def test_missing_gate_cannot_launch(self):
        del self.gate["safety_controls"]["dynamic-route"]
        with self.assertRaises(ValueError):self.validate()

    def test_unverified_component_or_world_opening_preflight_refused(self):
        self.gate["preflight"]["component_evidence_verified"]=False
        with self.assertRaises(ValueError):self.validate()
        self.gate["preflight"].update(component_evidence_verified=True,world_build_count=1)
        with self.assertRaises(ValueError):self.validate()

    def test_consumed_identity_or_digest_cannot_be_reused(self):
        for key in ("attempt_id","source_commit","contract_sha256","declaration_sha256","gate_receipt_sha256"):
            value=self.consumed[key];self.consumed[key]="crossed"
            with self.assertRaises(ValueError):self.validate()
            self.consumed[key]=value

    def test_terminal_provider_row_prevents_solver_transfer(self):
        data=SimpleNamespace(ctrl=np.ones(8))
        with self.assertRaises(ValueError):transfer_targets(dict(force_reference=dict(terminal_error={"type":"failure"}),native_targets=[0.]*8),data)
        np.testing.assert_array_equal(data.ctrl,np.ones(8))

    def pairs(self,mutation=None,baseline=False):
        def row(i):return dict(native_observation=dict(step=i),stability=i,kinematics=i,composition=i,
            output=i,native_targets=[float(i)],request=dict(state=dict(step=i)))
        left=[row(i) for i in range(1440)];right=copy.deepcopy(left)
        a=[dict(step=i+1,value=float(i)) for i in range(7200)];b=copy.deepcopy(a)
        if mutation:mutation(right,b)
        def reader(path):
            candidate=path.parent.name=="candidate"
            return (right if candidate else left) if path.name=="controller.jsonl" else (b if candidate else a)
        with patch("audit_dynamic_control_native.read_jsonl",side_effect=reader):
            return (compare_baseline if baseline else compare_pair)(Path("reference"),Path("candidate"),self.c)

    def test_changed_or_incomplete_prefix_or_handoff_is_refused(self):
        for mutate in (lambda c,t:c[59].update(output=-1),lambda c,t:t[299].update(value=-1),
            lambda c,t:c[60].update(native_observation={"step":-1}),lambda c,t:c.pop()):
            with self.assertRaises(ValueError):self.pairs(mutate)

    def test_fresh_post_handoff_divergence_is_allowed(self):
        result=self.pairs(lambda c,t:(c[61].update(output=-1),t[300].update(value=-1)))
        self.assertFalse(result["post_handoff_equality_required"]);self.assertTrue(result["handoff_prepared_state_identical"])

    def test_complete_baseline_regression_rejects_late_changes(self):
        self.assertEqual(self.pairs(baseline=True)["internal_rows_identical"],7200)
        for mutate in (lambda c,t:c[-1].update(output=-1),lambda c,t:t[-1].update(value=-1),lambda c,t:t.pop()):
            with self.assertRaises(ValueError):self.pairs(mutate,baseline=True)

    def test_unknown_role_or_crossed_profile_is_refused(self):
        result=task.read(task.COMPONENT_RESULT);closure=task.read(task.PARENT_CLOSURE)
        folder=task.ROOT.parent/"SporeSpore_Evidence"/closure["attempt_id"]/"physical/reach_hold_left_075_train_001"
        compiled=task.read(folder/"compiled.json");inputs=task.read(folder/"inputs.json")
        hold=task.profile_for("reach_hold",compiled,inputs);reach=task.profile_for("dynamic_hold",compiled,inputs)
        with self.assertRaises(ValueError):task.profile_for("crossed",compiled,inputs)
        with self.assertRaises(ValueError):task.controller_for("crossed",None,None,None,None,None,None)
        with self.assertRaises(ValueError):HoldPolicy(None,reach)
        with self.assertRaises(ValueError):ReachPolicy(None,hold)
        self.assertNotEqual(hold["schema_version"],reach["schema_version"])

    def test_real_runtime_preflight_opens_no_world(self):
        result=preflight(Path(os.environ["QUADRUPED_TEST_CORE"]),Path(os.environ["PORTABLE_BATCH_BASELINE_CORE"]))
        self.assertEqual(result["world_build_count"],0);self.assertEqual(result["solver_steps"],0)
        self.assertTrue(result["component_evidence_verified"]);self.assertEqual(len(result["profiles"]),4)
        self.assertEqual(result["planned_cpu_worlds"],4);self.assertEqual(result["contact_sample_rows"],28800)


    def test_component_scope_and_authority_mutations_refused(self):
        original=task.read
        for change in (dict(controls_passed=109),dict(world_build_count=1),dict(release_authority=True),
            dict(ledger_scope={}),dict(status="unverified")):
            def crossed(path):
                value=original(path)
                return dict(value,**change) if path==task.COMPONENT_RESULT else value
            with patch.object(task,"read",side_effect=crossed):
                with self.assertRaises(ValueError):task.verify_component(task.ROOT.parent/"SporeSpore_Evidence")

    def test_component_failed_receipt_refused(self):
        original=task.read
        result=original(task.COMPONENT_RESULT)
        target=(task.ROOT.parent/"SporeSpore_Evidence"/result["attempt_id"]/"receipt.json").resolve()
        def crossed(path):
            value=original(path)
            return dict(value,ok=False) if path.resolve()==target else value
        with patch.object(task,"read",side_effect=crossed):
            with self.assertRaises(ValueError):task.verify_component(task.ROOT.parent/"SporeSpore_Evidence")

    @classmethod
    def dynamic_fixture(cls,command):
        import itertools,json
        from floating_base_dynamics import FloatingDynamics
        from support_reach_geometry import ReachModel
        if not hasattr(cls,"fixtures"):cls.fixtures={}
        if command in cls.fixtures:return cls.fixtures[command]
        evidence=task.ROOT.parent/"SporeSpore_Evidence";result=task.read(task.COMPONENT_RESULT)
        trial="reach_hold_left_075_train_001"
        native=evidence/"sdk2-contact-posture-native-51b63e3d72c24fbd83c604934d836110"/"physical"/trial
        synthetic=evidence/result["attempt_id"]/"audit"/(trial+"-core-0.jsonl")
        with synthetic.open(encoding="utf-8") as f:
            previous,row=[json.loads(s)["controller"] for s in itertools.islice(f,command-1,command+1)]
        with (native/"controller.jsonl").open(encoding="utf-8") as f:
            observed=json.loads(next(itertools.islice(f,command,command+1)))
        row.update(native_observation=observed["native_observation"],outer_step=command)
        compiled=task.read(native/"compiled.json");inputs=task.read(native/"inputs.json")
        profile=task.profile_for("dynamic_hold",compiled,inputs);reach=ReachModel(profile["morphology_spec"])
        model=FloatingDynamics(profile["morphology_spec"],profile["parameters"]["joint_inertia_kg_m2"])
        nominal=float(model.tree.kinematics([0.,profile["reference_root_height_m"],0.],[0.,0.,0.,1.],[0.]*8)["whole_body_com"][1])
        prior=nominal if command==60 else previous["force_reference"]["decision"]["target_com"][1]
        cls.fixtures[command]=(row,previous,profile,nominal,prior,reach,task.read(native/"native-model.json"),model)
        return cls.fixtures[command]

    def test_native_reference_join_and_corruption_refusals(self):
        from dynamic_control_native_trial_audit import reference_checks
        row,previous,profile,nominal,prior,reach,metadata,model=self.dynamic_fixture(60)
        def verify(value):return reference_checks(value,previous,profile,"dynamic_hold",nominal,prior,reach,metadata,model)
        self.assertIsNotNone(verify(row)["optimization"])
        for mutation in (
            lambda r:r["force_reference"]["decision"]["allocation"]["solver"]["x"].__setitem__(0,10.),
            lambda r:r["force_reference"]["decision"]["allocation"].__setitem__("held_contact_guaranteed",True),
            lambda r:r["force_reference"]["decision"]["allocation"]["solver"].__setitem__("problem_sha256","0"*64),
            lambda r:r["force_reference"]["decision"]["support_reference"].__setitem__("target_com_height_m",nominal+.01),
            lambda r:r["resolution"]["ordered_commands"][0].__setitem__("applied_correction_rad_s",4.),
            lambda r:r["force_reference"]["decision"]["support_reach"][0].__setitem__("current_clearance_m",10.)):
            changed=copy.deepcopy(row);mutation(changed)
            with self.assertRaises(ValueError):verify(changed)

    def test_empty_support_and_late_retained_states(self):
        from dynamic_control_native_trial_audit import reference_checks
        for command in (160,1230):
            row,previous,profile,nominal,prior,reach,metadata,model=self.dynamic_fixture(command)
            result=reference_checks(row,previous,profile,"dynamic_hold",nominal,prior,reach,metadata,model)
            self.assertIsNotNone(result["optimization"])
            if command==160:self.assertEqual(result["optimization"]["active_contacts"],0)

    def test_nominal_prefix_and_dynamic_handoff(self):
        import itertools
        from audit_gpu_batch_execution import read_jsonl
        from causal_force_control import terminal_error
        closure=task.read(task.PARENT_CLOSURE);identity="reach_hold_nominal_train_001"
        folder=task.ROOT.parent/"SporeSpore_Evidence"/closure["attempt_id"]/"physical"/identity
        core=task.bridge.LocomotionCore(Path(os.environ["QUADRUPED_TEST_CORE"]));model=task.frozen_model(core)
        compiled=task.read(folder/"compiled.json");profile=task.profile_for("dynamic_hold",compiled,task.read(folder/"inputs.json"))
        controller=task.controller_for("dynamic_hold",core,compiled,self.c,model,"dynamic_nominal_ghost",profile)
        try:
            for old in itertools.islice(read_jsonl(folder/"controller.jsonl"),62):
                row=controller.step(old["request"]["state"],old["stability"],old["kinematics"])
                self.assertIsNone(terminal_error(row))
            self.assertEqual(controller.force_memory["sequence"],2)
        finally:controller.close()
        self.assertTrue(controller.closed)

    def test_retained_native_motor_reconstruction(self):
        import itertools
        from audit_gpu_batch_execution import read_jsonl
        from dynamic_control_native_trial_audit import motor_checks
        closure=task.read(task.PARENT_CLOSURE)
        folder=task.ROOT.parent/"SporeSpore_Evidence"/closure["attempt_id"]/"physical/reach_hold_left_075_train_001"
        profile=task.profile_for("reach_hold",task.read(folder/"compiled.json"),task.read(folder/"inputs.json"))
        control=next(itertools.islice(read_jsonl(folder/"controller.jsonl"),60,61))
        for trace in itertools.islice(read_jsonl(folder/"trace.jsonl"),300,305):
            result=motor_checks(trace,control,profile,self.c,"reach_hold")
            self.assertLessEqual(result["motor_model_error_nm"],1e-10)

    def test_motor_corruption_prepared_mismatch_and_held_change(self):
        from dynamic_control_native_trial_audit import motor_checks
        from actuation_recovery_mechanics import motor_torque
        profile=self.dynamic_fixture(60)[2]
        control=dict(request=dict(state=dict(semantic_step=60)),
            force_reference=dict(decision=dict(allocation=dict(requested_torque=[0.]*8))))
        trace=dict(ctrl=[0.]*8,before_qvel=[0.]*6+[.1]*8,step=302)
        trace["actuator_force_nm"]=motor_torque(trace["ctrl"],trace["before_qvel"][6:],
            profile["velocity_gains"],profile["force_ranges"]).tolist()
        result=motor_checks(trace,control,profile,self.c,"dynamic_hold")
        self.assertFalse(result["prepared"]);self.assertGreater(result["requested_torque_error_nm"],0.)
        with self.assertRaises(ValueError):motor_checks(dict(trace,step=301),control,profile,self.c,"dynamic_hold")
        changed=copy.deepcopy(trace);changed["actuator_force_nm"][0]+=.001
        with self.assertRaises(ValueError):motor_checks(changed,control,profile,self.c,"dynamic_hold")

    def test_complete_retained_baseline_reader(self):
        from dynamic_control_native_trial_audit import audit_trial
        closure=task.read(task.PARENT_CLOSURE)
        folder=task.ROOT.parent/"SporeSpore_Evidence"/closure["attempt_id"]/"physical/reach_hold_left_075_train_001"
        path=Path(os.environ["PORTABLE_BATCH_BASELINE_CORE"]);core=task.bridge.LocomotionCore(path)
        model=task.frozen_model(core)
        result=audit_trial(folder,task.read(folder/"plan.json"),self.c,path,core,model.document())
        self.assertEqual(result["controller_rows"],1440);self.assertEqual(result["internal_rows"],7200)
        self.assertEqual(result["native_motor_validation"]["internal_samples"],7200)
        self.assertEqual(result["reference_validation"]["checked_optimizations"],0)

    def test_unique_gate_names_and_exact_solver_runtime(self):
        self.assertEqual(len(task.GATES),len({name for name,_,_ in task.GATES}))
        self.assertEqual(self.c["runtime"]["osqp"],"1.1.3")
        import dynamic_control_native as native
        changed=copy.deepcopy(self.c);changed["runtime"]["osqp"]="changed"
        with patch.object(native,"declaration",return_value=changed):
            with self.assertRaises(ValueError):
                preflight(Path(os.environ["QUADRUPED_TEST_CORE"]),Path(os.environ["PORTABLE_BATCH_BASELINE_CORE"]))


if __name__=="__main__":unittest.main()
