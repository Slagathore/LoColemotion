"""Retained-reader refusal controls with real public-core commands."""
import copy,itertools,os,unittest
from pathlib import Path
from audit_dynamic_control_component import verify_row
from dynamic_control_component_task import EVIDENCE,ORIGINAL,TRIALS
from dynamic_force_policy import make_profile
from dynamic_hold_control import DynamicHoldController
from floating_base_dynamics import FloatingDynamics
from support_reach_geometry import ReachModel
from hold_horizon_task import read,bridge,controller_contract,frozen_model,declaration
from audit_gpu_batch_execution import read_jsonl

class DynamicReaderControls(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        identity=TRIALS[0][0];folder=EVIDENCE/ORIGINAL/"physical"/identity
        compiled=read(folder/"compiled.json");cls.profile=make_profile(compiled,read(folder/"inputs.json"))
        cls.core=bridge.LocomotionCore(Path(os.environ["QUADRUPED_TEST_CORE"]))
        frozen=frozen_model(cls.core);host=DynamicHoldController(cls.core,compiled,controller_contract(declaration(),frozen),frozen,identity,cls.profile)
        cls.original=list(itertools.islice(read_jsonl(folder/"controller.jsonl"),61));cls.rows=[]
        try:
            for old in cls.original:cls.rows.append(host.step(copy.deepcopy(old["request"]["state"]),copy.deepcopy(old["stability"]),copy.deepcopy(old["kinematics"])))
        finally:host.close()
        cls.model=FloatingDynamics(cls.profile["morphology_spec"],cls.profile["parameters"]["joint_inertia_kg_m2"])
        cls.reach=ReachModel(cls.profile["morphology_spec"]);cls.nominal=host.force_policy.height

    def verify(self,row):
        return verify_row(row,self.original[60],self.rows[59],self.profile,self.model,self.reach,self.nominal)
    def test_01_real_row_and_prefix(self):
        self.assertIsNotNone(self.verify(self.rows[60]))
        self.assertIsNone(verify_row(self.rows[0],self.original[0],None,self.profile,self.model,self.reach,self.nominal))
    def test_02_corrupt_solution_refused(self):
        row=copy.deepcopy(self.rows[60]);row["force_reference"]["decision"]["allocation"]["solver"]["x"][0]+=.1
        with self.assertRaises(ValueError):self.verify(row)
    def test_03_corrupt_problem_identity_refused(self):
        row=copy.deepcopy(self.rows[60]);row["force_reference"]["decision"]["allocation"]["solver"]["problem_sha256"]="0"*64
        with self.assertRaises(ValueError):self.verify(row)
    def test_04_changed_resolved_target_refused(self):
        row=copy.deepcopy(self.rows[60]);row["resolution"]["ordered_commands"][0]["final_canonical_target_velocity_rad_s"]+=.01
        with self.assertRaises(ValueError):self.verify(row)
    def test_05_changed_original_observation_refused(self):
        row=copy.deepcopy(self.rows[60]);row["request"]["state"]["base_pose_world"]["position_m"]["x"]+=.001
        with self.assertRaises(ValueError):self.verify(row)
    def test_06_authority_escalation_refused(self):
        row=copy.deepcopy(self.rows[60]);row["force_reference"]["decision"]["allocation"]["held_contact_guaranteed"]=True
        with self.assertRaises(ValueError):self.verify(row)

if __name__=="__main__":unittest.main()
