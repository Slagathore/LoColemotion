"""Synthetic arithmetic and tamper controls; no dynamics or native worlds."""
import copy
import math
import unittest
from predictive_sequence_v1 import commands
from predictive_command_selection_v2 import guard
from sequence_authority_diagnostic_v1 import diagnose
import numpy as np


def fixture(target=0.,baseline=0.,gain=1.,cap=5.):
    names=[leg+"_"+joint for leg in ("front_left","front_right","rear_left","rear_right") for joint in ("hip","knee")]
    bodies=["world","torso"]+[leg+"_"+part for leg in ("front_left","front_right","rear_left","rear_right") for part in ("proximal","distal")]
    spec=dict(joint_ids=names,limits=[[-.72,.72]]*8,gains=[gain]*8,ranges=[[-cap,cap]]*8,geom_bodies=bodies)
    q=[0.,0.,.45,1.,0.,0.,0.]+[0.]*8;v=[0.]*14
    value=dict(baseline=[baseline]*8,speeds=[3.5]*8,previous_correction=[target]*8,
        nominal_correction=[target]*8,target_com=[0.,.45,0.],reference_joints=[0.]*8,command=86,qpos=q,qvel=v)
    knots=[[target]*8 for _ in range(4)];corrections,targets=commands(value,knots,66);rows=[]
    for offset,(c,t) in enumerate(zip(corrections,targets)):
        steps=[]
        for step in range(5):
            force=[max(-cap,min(cap,gain*x)) for x in t]
            steps.append(dict(step=step,before_qpos=list(q),before_qvel=list(v),qpos=list(q),qvel=list(v),contacts=[],
                prediction=dict(accepted=True,solution=dict(accepted=True,force=[]),constraints=[],
                    actuator_force=force,post_velocity=list(v),post_joint_position=list(q[7:]))))
        rows.append(dict(offset=offset,correction=c,target=t,guard_reasons=[],
            forecast=dict(accepted=True,planned_steps=5,completed_steps=5,rows=steps,held_target=t,
                final_qpos=list(q),final_qvel=list(v))))
    result=dict(eligible=True,planned_intervals=66,valid_intervals=66,attempted_intervals=66,
        completed_predicted_steps=330,rejection_reasons=[],rows=rows,
        future_baseline_assumption="current deterministic baseline held constant",
        future_observations_used=False,future_recorded_actions_used=False,public_future_envelope_equivalence=False,
        native_worlds=0,native_physics_steps=0,trained=False,physical_acceptance_authority=False,release_authority=False)
    return value,knots,result,spec


def finish_violation(parts,mutate):
    value,knots,result,spec=parts;forecast=result["rows"][-1]["forecast"];row=forecast["rows"][-1]
    mutate(row)
    row["prediction"]["post_velocity"]=list(row["qvel"])
    row["prediction"]["post_joint_position"]=list(row["qpos"][7:])
    forecast["final_qpos"]=list(row["qpos"]);forecast["final_qvel"]=list(row["qvel"])
    reasons=guard(forecast,np.array(spec["limits"]))
    result["rows"][-1]["guard_reasons"]=reasons
    result.update(eligible=False,valid_intervals=65,rejection_reasons=reasons)


def add_contact(row,normal,geom=3):
    row["contacts"]=[dict(geom=[0,geom],distance_m=-.001)]
    row["prediction"]["constraints"]=[dict(kind="contact",native_index=0,body_id="front_left_distal")]
    row["prediction"]["solution"]["force"]=[normal,0.,0.]


class AuthorityControls(unittest.TestCase):
    def test_01_complete_population_and_immutability(self):
        p=fixture();before=copy.deepcopy(p);a=diagnose(*p)
        self.assertEqual(p,before);self.assertEqual(a["predicted_steps"],330)
        self.assertTrue(a["accepted"]);self.assertIsNone(a["first_guard"])
        for key in ("recovery_benefit_established","tier2_qualified","tier3_benefit_established",
            "global_infeasibility_established","baseline_approximation_error_measured","release_authority"):
            self.assertIs(a[key],False)

    def test_02_exact_guard_refusal(self):
        p=fixture();finish_violation(p,lambda row:row["qpos"].__setitem__(11,.72))
        a=diagnose(*p);self.assertFalse(a["accepted"])
        self.assertEqual(a["first_guard"],dict(interval=65,step=4,reasons=["joint_position_margin"]))

    def test_03_lower_motor_saturation(self):
        a=diagnose(*fixture(target=-1.,gain=10.,cap=.5))
        self.assertEqual(a["lower_force_cap_steps"],[330]*8)
        self.assertEqual(a["unchanged_torque_across_interval_envelope_steps"],[330]*8)

    def test_04_upper_motor_saturation(self):
        a=diagnose(*fixture(target=1.,gain=10.,cap=.5))
        self.assertEqual(a["upper_force_cap_steps"],[330]*8)

    def test_05_contact_geometry_and_positive_normal_force(self):
        p=fixture();add_contact(p[2]["rows"][0]["forecast"]["rows"][0],4.)
        a=diagnose(*p);self.assertEqual(a["front_geometric_contact_steps"],1)
        self.assertEqual(a["front_positive_normal_force_steps"],1)

    def test_06_zero_and_negative_force_are_not_positive_load(self):
        for force in (0.,-1e-12):
            with self.subTest(force=force):
                p=fixture();add_contact(p[2]["rows"][0]["forecast"]["rows"][0],force)
                a=diagnose(*p);self.assertEqual(a["front_geometric_contact_steps"],1)
                self.assertEqual(a["front_positive_normal_force_steps"],0)

    def test_07_held_baseline_absolute_range_is_one_sided(self):
        a=diagnose(*fixture(target=3.5,baseline=-3.5))
        self.assertEqual(a["held_baseline_absolute_target_bounds"],[[-3.5,0.]]*8)
        # The existing interpolator lands one ULP below the cap at interval 1.
        # Keep exact binding counts distinct from mathematically constant knots.
        self.assertEqual(a["absolute_correction_bound_intervals"],[65]*8)
        p=fixture(target=3.5,baseline=-3.5)
        self.assertEqual(p[2]["rows"][1]["correction"],[math.nextafter(3.5,0.)]*8)

    def test_08_unsaturated_local_torque_range(self):
        a=diagnose(*fixture());r=a["trace"][0]
        self.assertEqual(r["reachable_lower_torque_nm"],[-.08]*8)
        self.assertEqual(r["reachable_upper_torque_nm"],[.08]*8)
        self.assertEqual(a["unchanged_torque_across_interval_envelope_steps"],[0]*8)

    def test_09_changed_target_refused(self):
        p=fixture();p[2]["rows"][0]["target"][0]=.1
        with self.assertRaises(ValueError):diagnose(*p)

    def test_10_changed_correction_refused(self):
        p=fixture();p[2]["rows"][0]["correction"][0]=.1
        with self.assertRaises(ValueError):diagnose(*p)

    def test_11_changed_motor_force_refused(self):
        p=fixture();p[2]["rows"][0]["forecast"]["rows"][0]["prediction"]["actuator_force"][0]=.01
        with self.assertRaises(ValueError):diagnose(*p)

    def test_12_changed_state_join_refused(self):
        p=fixture();p[2]["rows"][0]["forecast"]["rows"][1]["before_qvel"][6]=.01
        with self.assertRaises(ValueError):diagnose(*p)

    def test_13_changed_guard_or_false_success_refused(self):
        p=fixture();finish_violation(p,lambda row:row["qpos"].__setitem__(2,.24))
        self.assertEqual(diagnose(*p)["first_guard"]["reasons"],["height"])
        p[2]["eligible"]=True
        with self.assertRaises(ValueError):diagnose(*p)

    def test_14_missing_interval_refused(self):
        p=fixture();p[2]["rows"].pop(20)
        with self.assertRaises(ValueError):diagnose(*p)

    def test_15_missing_step_refused(self):
        p=fixture();p[2]["rows"][0]["forecast"]["rows"].pop()
        with self.assertRaises(ValueError):diagnose(*p)

    def test_16_wrong_contact_identity_refused(self):
        p=fixture();r=p[2]["rows"][0]["forecast"]["rows"][0];add_contact(r,4.)
        r["prediction"]["constraints"][0]["native_index"]=1
        with self.assertRaises(ValueError):diagnose(*p)

    def test_17_missing_or_extra_force_refused(self):
        for forces in ([4.,0.],[4.,0.,0.,1.]):
            with self.subTest(forces=forces):
                p=fixture();r=p[2]["rows"][0]["forecast"]["rows"][0];add_contact(r,4.)
                r["prediction"]["solution"]["force"]=forces
                with self.assertRaises(ValueError):diagnose(*p)

    def test_18_future_data_or_false_authority_refused(self):
        for key in ("future_observations_used","future_recorded_actions_used","trained","release_authority"):
            with self.subTest(key=key):
                p=fixture();p[2][key]=True
                with self.assertRaises(ValueError):diagnose(*p)

    def test_19_nonfinite_or_wrong_specification_refused(self):
        for mutation in (lambda p:p[3]["gains"].__setitem__(0,float("nan")),
                         lambda p:p[3]["joint_ids"].__setitem__(1,p[3]["joint_ids"][0]),
                         lambda p:p[1][0].__setitem__(0,4.)):
            p=fixture();mutation(p)
            with self.assertRaises(ValueError):diagnose(*p)

    def test_20_numerical_refusal_cannot_invent_diagnostics(self):
        p=fixture();p[2]["rows"][0]["forecast"]["accepted"]=False
        with self.assertRaises(ValueError):diagnose(*p)


if __name__=="__main__":unittest.main()
