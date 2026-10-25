"""Refusal controls for finite force-recovery closure; no new worlds."""
import copy
import math
import unittest
import audit_hold_horizon_closure as a


class ClosureControls(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.record=a.read(a.CLOSURE)
        cls.attempt=a.ROOT.parent/"SporeSpore_Evidence"/cls.record["attempt_id"]
        cls.receipt=a.read(cls.attempt/"receipt.json")
        cls.declared=a.read(cls.attempt/"declaration.json")
        cls.original=a.read(cls.attempt/"audit.json")

    def test_original_header_links_and_owner(self):
        self.assertEqual(a.header(self.record,a.ROOT.parent/"SporeSpore_Evidence"),self.attempt.resolve())
        a.validate_owner(self.receipt,self.declared,self.record,a.task.declaration())

    def test_every_authority_escalation_is_refused(self):
        for key in a.DENIALS:
            r=copy.deepcopy(self.record);r[key]=True
            with self.assertRaises(ValueError):a.validate_header(r)

    def test_crossed_source_contract_or_reader_is_refused(self):
        for key in ("source_commit","contract_sha256","component_result_sha256"):
            r=copy.deepcopy(self.record);r[key]="0"*64
            with self.assertRaises(ValueError):a.validate_header(r)
        r=copy.deepcopy(self.record);r["closure_source_bindings"][a.SOURCES[0]]="0"*64
        with self.assertRaises(ValueError):a.validate_header(r)

    def test_incomplete_denominators_or_new_reserved_scope_are_refused(self):
        for key in ("complete_safety_controls","closure_controls_required","source_binding_count",
            "runtime_binding_count","reserved_starts_opened","training_worlds_opened"):
            r=copy.deepcopy(self.record);r[key]+=1
            with self.assertRaises(ValueError):a.validate_header(r)

    def test_attempt_cannot_escape_evidence_root(self):
        for identity in ("../escape","sdk2-hold-horizon-x/../escape","sdk2-hold-horizon-x\\..\\escape"):
            r=copy.deepcopy(self.record);r["attempt_id"]=identity
            with self.assertRaises(ValueError):a.validate_header(r)

    def test_incomplete_or_dirty_owner_cannot_be_closed(self):
        for key,value in (("ok",False),("zero_world_gate_passed",False),("component_only",True),
            ("constructed_cpu_worlds",3),("source_status",[" M unexpected.py"]),("source_runtime_unchanged",False)):
            r=copy.deepcopy(self.receipt);r[key]=value
            with self.assertRaises(ValueError):a.validate_owner(r,self.declared,self.record,a.task.declaration())

    def test_observed_failure_or_horizon_censoring_cannot_be_changed(self):
        for index,trial in enumerate(self.original["trials"]):
            value=copy.deepcopy(self.original)
            old=trial["diagnostic_metrics"]["first_physical_violation"]
            value["trials"][index]["diagnostic_metrics"]["first_physical_violation"]=(
                None if old is not None else dict(internal_step=600,time_s=1.,failure_codes=["tilt"]))
            with self.assertRaises(ValueError):a.compare_reconstruction(self.original,value)

    def test_total_target_change_cannot_be_relabelled_residual_change(self):
        value=copy.deepcopy(self.original)
        changed=value["trials"][1]["handoff_transition"]["at_handoff"]
        changed["target_delta_rad_s"]=changed["correction_delta_rad_s"]
        with self.assertRaises(ValueError):a.compare_reconstruction(self.original,value)

    def test_support_denominator_and_post_failure_scope_cannot_be_erased(self):
        for key,change in (("prepared_commands",59),("may_include_post_failure_states",False)):
            value=copy.deepcopy(self.original);value["trials"][1]["post_handoff_support"][key]=change
            with self.assertRaises(ValueError):a.compare_reconstruction(self.original,value)

    def test_missing_duplicate_or_changed_artifact_is_refused(self):
        expected=[dict(path="a",sha256="a",byte_length=1),dict(path="b",sha256="b",byte_length=2)]
        for observed in (expected[:1],[expected[0],expected[0]],[expected[0],dict(expected[1],sha256="changed")]):
            with self.assertRaises(ValueError):a.verify_population(expected,observed)


    def endpoint_rows(self):
        return [dict(step=i,time_s=i/600.,qpos=[0.,0.,.4,1.,0.,0.,0.]+[0.]*8) for i in range(1,7201)]

    def test_endpoint_zero_and_rising_tilt_keep_actual_clock(self):
        rows=self.endpoint_rows();value=a.endpoint_trend(rows)
        self.assertEqual(value["last_500ms_tilt_secant_rad_s"],0.)
        for step,angle in ((6900,.1),(7200,.2)):
            rows[step-1]["qpos"][3:7]=[math.cos(angle/2),math.sin(angle/2),0.,0.]
        value=a.endpoint_trend(rows)
        self.assertAlmostEqual(value["last_500ms_tilt_secant_rad_s"],.2)
        self.assertEqual(value["maximum_tilt_step"],7200)
        self.assertTrue(value["posthoc"]);self.assertFalse(value["future_trajectory_extrapolated"])

    def test_missing_crossed_clock_or_invalid_endpoint_pose_refused(self):
        rows=self.endpoint_rows()
        with self.assertRaises(ValueError):a.endpoint_trend(rows[:-1])
        for key,value in (("step",7199),("time_s",rows[7198]["time_s"]),("qpos",[0.]*15)):
            changed=copy.deepcopy(rows);changed[-1][key]=value
            with self.assertRaises(ValueError):a.endpoint_trend(changed)



if __name__=="__main__":unittest.main()
