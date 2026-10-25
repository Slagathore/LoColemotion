"""Native posture route, evidence boundary and corruption/refusal controls."""
import copy,os
from pathlib import Path
from types import SimpleNamespace
import unittest
from unittest.mock import patch
import numpy as np
import contact_posture_native_task as task
from contact_posture_native import preflight
from contact_posture_native_trial import transfer_targets
from audit_contact_posture_native import compare_pair,compare_baseline
from support_reach_force_policy import Policy as HoldPolicy
from contact_posture_force_policy import Policy as ReachPolicy


class NativeReachControls(unittest.TestCase):
    def setUp(self):
        self.c=task.declaration();self.source="0"*40;self.attempt="sdk2-contact-posture-native-synthetic"
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
        self.validate();self.assertEqual(sum(self.gate["safety_controls"].values()),556)

    def test_four_fresh_exposed_worlds_and_fixed_horizon(self):
        plans=task.plans(self.c)
        self.assertEqual(len(plans),4);self.assertEqual(len({p["trial_id"] for p in plans}),4)
        self.assertEqual({p["role"] for p in plans},{"reach_hold","posture_hold"})
        self.assertTrue(all(p["start_id"]=="train_001" and p["seed"]==104242001 for p in plans))
        self.assertEqual(self.c["outer_steps"],1440);self.assertEqual(self.c["horizon_s"],12.)

    def test_changed_scope_is_refused(self):
        for change in (dict(roles=["posture_hold"]),dict(groups=["nominal_train_003"]),dict(outer_steps=1441),
            dict(horizon_s=1.),dict(planned_cpu_worlds=2)):
            with self.assertRaises(ValueError):task.plans(dict(self.c,**change))

    def test_dirty_source_cannot_launch(self):
        self.owner["source_status"]=[" M unexpected.py"]
        with self.assertRaises(ValueError):self.validate()

    def test_component_only_cannot_launch(self):
        self.owner["component_only"]=True
        with self.assertRaises(ValueError):self.validate()

    def test_missing_gate_cannot_launch(self):
        del self.gate["safety_controls"]["posture-route"]
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
        with patch("audit_contact_posture_native.read_jsonl",side_effect=reader):
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
        hold=task.profile_for("reach_hold",compiled,inputs);reach=task.profile_for("posture_hold",compiled,inputs)
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
        for change in (dict(controls_passed=45),dict(world_build_count=1),dict(release_authority=True),
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

    def test_native_reference_join_and_corruption_refusals(self):
        import itertools,json
        from contact_posture_native_trial_audit import reference_checks
        from support_reach_geometry import ReachModel
        from contact_posture_reference import PostureReference
        result=task.read(task.COMPONENT_RESULT);closure=task.read(task.PARENT_CLOSURE)
        trial="reach_hold_left_075_train_001"
        native=task.ROOT.parent/"SporeSpore_Evidence"/closure["attempt_id"]/"physical"/trial
        synthetic=task.ROOT.parent/"SporeSpore_Evidence"/result["attempt_id"]/"audit"/(trial+"-core-0.jsonl")
        with synthetic.open(encoding="utf-8") as f:before,row=[json.loads(s)["controller"] for s in itertools.islice(f,59,61)]
        with (native/"controller.jsonl").open(encoding="utf-8") as f:observed=json.loads(next(itertools.islice(f,60,61)))
        row["native_observation"]=observed["native_observation"]
        compiled=task.read(native/"compiled.json");inputs=task.read(native/"inputs.json")
        profile=task.profile_for("posture_hold",compiled,inputs)
        model=ReachModel(profile["morphology_spec"]);metadata=task.read(native/"native-model.json")
        nominal=result["trials"][0]["synthetic_runs"][0]["nominal_com_reference_m"]
        def verify(value):return reference_checks(value,before,profile,"posture_hold",nominal,nominal,model,metadata)
        self.assertEqual(verify(row)["posture_status"],"solved")
        for mutation in (
            lambda r:r["force_reference"]["decision"]["posture_reference"]["reference_joint_positions_rad"].__setitem__(0,10.),
            lambda r:r["force_reference"]["decision"]["posture_reference"].__setitem__("dynamic_feasibility_established",True),
            lambda r:r["force_reference"]["decision"]["posture_reference"]["nonlinear_witness"].__setitem__("maximum_contact_displacement_m",.1),
            lambda r:r["force_reference"]["decision"]["support_reference"].__setitem__("target_com_height_m",nominal+.01),
            lambda r:r["resolution"]["ordered_commands"][0].__setitem__("applied_correction_rad_s",4.),
            lambda r:r["force_reference"]["decision"]["support_reach"][0].__setitem__("current_clearance_m",10.)):
            changed=copy.deepcopy(row);mutation(changed)
            with self.assertRaises(ValueError):verify(changed)


if __name__=="__main__":unittest.main()
