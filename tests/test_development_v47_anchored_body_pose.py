"""V47 actual C ABI and immutable V46 regression; no physics."""
import copy,hashlib,json,math,os,sys,unittest
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
sys.path[:0]=[str(ROOT/"sdk/python"),str(ROOT/"sdk/conformance")]
from sporespore_locomotion import LocomotionCore
from test_development_v32_recontact_component import NativeApi
import development_v46_support_geometry_diagnosis as geometry
POLICY="sporespore_balanced_wave_recovery_anchored_body_pose_v1"
class AnchoredBodyPose(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.dll=Path(os.environ["SPORE_V47_DLL"]);cls.core=LocomotionCore(cls.dll);cls.native=NativeApi(str(cls.dll))
        cls.rows,cls.input=geometry.read_source();cls.descriptor=cls.input["descriptor"]
        cls.root=ROOT.parent/"SporeSpore_Evidence"/("development-v46-mujoco-closed-loop-"+geometry.ATTEMPT)
    def initial(self):
        m=self.core.balanced_wave_policy_initial_memory(POLICY,self.descriptor)
        for l in m["ordered_limb_memory"]:l["gait_step"]=90
        return m
    def request(self,n,m):
        r=copy.deepcopy(self.rows[0]["request"]);r["policy_id"]=POLICY;r["memory"]=copy.deepcopy(m)
        for k in ("state","measured_body_frame"):r[k].update(semantic_step=n,sample_time_s=n/120)
        u=min(1.,(n-1)/72);r["command"].update(valid_from_step=n,valid_through_step=n,gait_amplitude=.5994550408719347*u*u*(3-2*u))
        return r
    def call(self,r):
        status,raw=self.native.raw("ss_balanced_wave_policy_step_json",self.core._input_bytes(r));self.assertEqual(0,status)
        return raw,json.loads(raw)["value"]
    def test_original_v46_responses_and_refusal_are_byte_exact(self):
        for row in self.rows:
            raw,out=self.call(row["request"]);self.assertEqual(row["raw_response_sha256"],"sha256:"+hashlib.sha256(raw).hexdigest());self.assertEqual(row["output"],out)
        r=json.loads((self.root/"controller-refusal.json").read_text(encoding="utf-8"));raw,out=self.call(r["request"])
        self.assertEqual(r["output"],out);self.assertEqual((self.root/"calls/0242.response.json").read_bytes(),raw)
    def test_stateless_cached_independent_fk_and_finite_preparation(self):
        m=self.initial();count=0
        with self.core.create_balanced_wave_policy_session(POLICY,self.descriptor) as session:
            for n in range(1,243):
                r=self.request(n,m);_,out=self.call(r)
                self.assertEqual(out,session.step_with_measured_body({k:v for k,v in r.items() if k not in ("policy_id","descriptor")}))
                if out["actuation"]["safe_no_actuation"]:
                    self.assertEqual(242,n);self.assertIn("preparation_timeout",out["actuation"]["receipt"]["controller_error"]);self.assertEqual(m,out["next_memory"]);break
                a=out["actuation"]["receipt"]["recovery_support_plane"]["anchored_body_pose"]
                if n>1:
                    self.assertLess(max(a["ordered_target_fk_error_m"]),1e-12)
                    desired=copy.deepcopy(r["state"]);desired["base_pose_world"]["position_m"]=a["desired_body_position_world_m"]
                    f=a["desired_forward_world_unit"];yaw=math.atan2(f["x"],f["z"])
                    desired["base_pose_world"]["orientation_xyzw"]=dict(x=0.,y=math.sin(yaw/2),z=0.,w=math.cos(yaw/2))
                    for i,limb in enumerate(geometry.LIMBS):
                        h,k=a["ordered_joint_goals_rad"][2*i:2*i+2]
                        self.assertLess(abs(geometry.bottom(desired,self.descriptor,limb,h,k)),1e-12);count+=1
                self.assertEqual([l["gait_step"] for l in m["ordered_limb_memory"]],[l["gait_step"] for l in out["next_memory"]["ordered_limb_memory"]]);m=out["next_memory"]
        self.assertEqual(960,count)
    def test_reference_ignores_measured_height_drift_and_stop_holds_it(self):
        m=self.initial()
        for n in range(1,15):_,o=self.call(self.request(n,m));self.assertFalse(o["actuation"]["safe_no_actuation"]);m=o["next_memory"]
        r=self.request(15,m);_,before=self.call(r);changed=copy.deepcopy(r);changed["state"]["base_pose_world"]["position_m"]["y"]+=.006
        for body in changed["measured_body_frame"]["ordered_body_states"]:body["pose_world"]["position_m"]["y"]+=.006
        _,after=self.call(changed);self.assertFalse(after["actuation"]["safe_no_actuation"])
        a=before["actuation"]["receipt"]["recovery_support_plane"]["anchored_body_pose"];b=after["actuation"]["receipt"]["recovery_support_plane"]["anchored_body_pose"]
        for k in ("desired_body_position_world_m","ordered_foot_targets_world_m","ordered_joint_goals_rad"):self.assertEqual(a[k],b[k])
        for x,y in zip(a["ordered_goal_bottom_in_measured_pose_m"],b["ordered_goal_bottom_in_measured_pose_m"]):self.assertAlmostEqual(.006,y-x,places=12)
        r=self.request(16,before["next_memory"]);r["command"]["gait_amplitude"]=0.;r["command"]["desired_planar_velocity_task_m_s"]["x"]=0.
        _,stop=self.call(r);s=stop["actuation"]["receipt"]["recovery_support_plane"]["anchored_body_pose"]
        self.assertEqual(a["desired_body_position_world_m"],s["desired_body_position_world_m"]);self.assertEqual(a["ordered_foot_targets_world_m"],s["ordered_foot_targets_world_m"])
    def test_crossed_memory_and_impossible_target_refuse_with_unchanged_memory(self):
        _,o=self.call(self.request(1,self.initial()));m=o["next_memory"]
        for defect in ("missing","clock","identity","floor","reach","crossed_policy"):
            r=self.request(2,m)
            if defect=="missing":r["memory"].pop("anchored_body_pose")
            elif defect=="clock":r["memory"]["anchored_body_pose"]["last_sample_time_s"]+=1.
            elif defect=="identity":r["memory"]["anchored_body_pose"]["ordered_feet"][0]["limb_id"]="rear_right"
            elif defect=="floor":r["memory"]["anchored_body_pose"]["ordered_feet"][0]["anchor_world_m"]["y"]+=.01
            elif defect=="reach":r["memory"]["anchored_body_pose"]["ordered_feet"][0]["anchor_world_m"]["x"]+=10.
            else:r["policy_id"]="sporespore_balanced_wave_recovery_measured_pose_support_v1";r["memory"]["schema_version"]="sporespore_balanced_wave_recovery_measured_pose_support_memory_v1"
            _,out=self.call(r);self.assertTrue(out["actuation"]["safe_no_actuation"],defect);self.assertEqual(r["memory"],out["next_memory"])
            self.assertTrue(all(c["target_velocity_rad_s"]==0 for c in out["actuation"]["ordered_commands"]))
    def test_forced_synthetic_phase_inputs_cover_swing_landing_and_stationary_stance(self):
        # Explicit synthetic clock/memory fixtures, not a feasible physics trajectory.
        # Exercise the real exported policy's reference transitions independently
        # of its separately tested readiness and native contact route.
        _,out=self.call(self.request(1,self.initial()));m=out["next_memory"]
        original=copy.deepcopy(m["anchored_body_pose"]["ordered_feet"]);seen=[]
        for n in range(2,78):
            phase=n-1
            for limb in m["ordered_limb_memory"]:limb["gait_step"]=90+phase-1
            transfer=m["measured_support_transfer"];transfer.update(hip_bias_rad=0.,prepared_limb_id="front_left",prepared_swing_start_gait_step=90,preparation_commands=0,ready_dwell_commands=0)
            r=self.request(n,m)
            if phase<72:
                r["state"]["ordered_contact_observations"][0].update(presence=False,bears_support=False)
            _,out=self.call(r);self.assertFalse(out["actuation"]["safe_no_actuation"],out["actuation"]["receipt"]["controller_error"])
            support=out["actuation"]["receipt"]["recovery_support_plane"];a=support["anchored_body_pose"];p0=support["measured_support_transfer"]["effective_selected_phases"][0];seen.append(p0)
            u=min(1.,p0/72);distance=.06*u*u*(3-2*u);lift=.02*math.sin(math.pi*u) if 0<p0<72 else 0.
            start=original[0]["anchor_world_m"];f=a["desired_forward_world_unit"];target=a["ordered_foot_targets_world_m"][0]
            for axis in ("x","z"):self.assertAlmostEqual(start[axis]+distance*f[axis],target[axis],places=12)
            self.assertAlmostEqual(start["y"]+lift,target["y"],places=12)
            for j in range(1,4):self.assertEqual(original[j]["anchor_world_m"],a["ordered_foot_targets_world_m"][j])
            self.assertLess(max(a["ordered_target_fk_error_m"]),1e-12);m=out["next_memory"]
        self.assertGreaterEqual(len(set(seen)),70);self.assertGreater(seen[-1],72)
        foot=m["anchored_body_pose"]["ordered_feet"][0];self.assertIsNone(foot["swing_epoch"]);self.assertIsNone(foot["swing_start_world_m"])
        self.assertEqual(foot["anchor_world_m"],m["anchored_body_pose"]["ordered_last_targets_world_m"][0])
if __name__=="__main__":unittest.main()
