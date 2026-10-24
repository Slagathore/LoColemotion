"""Analytical controls for frozen scaling, post-handoff reward and selection."""
import copy
from contextlib import ExitStack
from dataclasses import replace
import math
import unittest
from unittest.mock import patch
import mujoco

from adaptation_provider import bounded_residual_ars_fixed_v1 as fixed
from adaptation_provider import bounded_residual_ars_v1 as ars
import residual_recovery_training_objective as objective


class Components(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.guards=ExitStack();cls.addClassCleanup(cls.guards.close)
        for name in ("MjModel","MjData","mj_step","mj_step1","mj_step2","mj_forward"):
            cls.guards.enter_context(patch.object(mujoco,name,side_effect=AssertionError("Component opened physics")))

    def batch(self):
        p=ars.Policy(((.1,.2),),ars.Moments.empty(2),(3.5,),1e-8)
        return ars.ask(p,ars.Plan(0,104240901,("weak","healthy"),2,1,.02,.2))

    def rows(self,batch,rewards=(3.,1.,0.,-1.)):
        return [ars.Rollout(batch.sha256,batch.candidate(i,s).sha256,i,s,g,"training",
            f"trial_{i}_{s}_{g}",rewards[2*i+(s==-1)],
            ars.Moments.empty(2).add([(float(i+s),float(n))],partition="training"))
            for n,(i,s,g) in enumerate(batch.identities())]

    def native(self,tilt=.3):
        c=dict(outer_steps=64,internal_steps_per_outer=5,controller_dt_s=1/120,
            selection=dict(minimum_height_m=.25,maximum_tilt_rad=.6,maximum_torso_contact_steps=0),
            reward=dict(desired_forward_velocity_m_s=.2,lateral_error_weight=.25,error_scale_m_s=.4,failure_value=-1.),
            official_quality_enabled=False,recovery_objective=copy.deepcopy(objective.OBJECTIVE))
        controls=[dict(output=dict(actuation=dict(safe_no_actuation=False)),
            residual=dict(decision=dict(features=dict(values=[0.]*88),reason="supported"))) for _ in range(64)]
        trace=[dict(step=i+1,time_s=(i+1)/600,qpos=[0.,0.,.4,math.cos(tilt/2),math.sin(tilt/2),0.,0.]+[0.]*8,
            qvel=[.2]+[0.]*13,contacts=[]) for i in range(320)]
        return controls,trace,c

    def candidates(self):
        out=[]
        for name,rewards in (("a",(-.1,-.8)),("b",(-.5,-.5))):
            model="sha256:"+name*64;policy="sha256:"+("c" if name=="a" else "d")*64
            rows=[dict(trial_id=name+"_"+g,group_id=g,partition="training",role="search",
                provider_model_sha256=model,recovery_policy_sha256=policy,reward_denominator=6900,
                diagnostic_eligible=False,first_reward_failure=dict(internal_step=500),
                official_quality_m_s=None,comparison_data_used_for_training=False,training_reward=r)
                for g,r in zip(("weak","healthy"),rewards,strict=True)]
            out.append(dict(candidate_id=name,model_sha256=model,policy_sha256=policy,trials=rows))
        return out

    def select(self,candidates):
        return objective.select(candidates,("weak","healthy"),("a","b"),6900)

    def test_01_analytic_weight_update_preserves_original_scaling(self):
        b=self.batch();result,record=fixed.tell(b,self.rows(b))
        for got,w,d in zip(result.weights[0],b.policy.weights[0],b.perturbations[0][0],strict=True):
            self.assertAlmostEqual(got,w+.4*d,places=14)
        self.assertEqual(result.moments,b.policy.moments)
        self.assertEqual(record["underlying_update"]["selected_directions"],[0])
        self.assertEqual(record["observed_moments"]["count"],8)
        self.assertFalse(record["normalizer_updated"])

    def test_02_equal_rewards_preserve_every_policy_byte_and_action(self):
        b=self.batch();result,record=fixed.tell(b,self.rows(b,(-1.,)*4))
        self.assertEqual(result,b.policy);self.assertEqual(result.sha256,b.policy.sha256)
        self.assertTrue(record["underlying_update"]["zero_reward_variance"])
        for x in ((0.,0.),(1.,-3.),(8.,.2)):self.assertEqual(result.action(x),b.policy.action(x))

    def test_03_existing_nonidentity_scaling_is_retained(self):
        b=self.batch();moments=ars.Moments.empty(2).add([(1.,2.),(3.,4.)],partition="training")
        b=ars.ask(replace(b.policy,moments=moments),b.plan)
        result,record=fixed.tell(b,self.rows(b))
        self.assertEqual(result.moments,moments);self.assertEqual(record["observed_moments"]["count"],10)

    def test_04_complete_population_and_reserved_data_refuse(self):
        b=self.batch();rows=self.rows(b)
        for bad in (rows[:-1],rows+[rows[0]],[replace(rows[0],partition="evaluation")]+rows[1:],
            [replace(rows[0],policy_sha256="crossed")]+rows[1:]):
            with self.assertRaises(ValueError):fixed.tell(b,bad)

    def test_05_arrival_order_and_parent_immutability(self):
        b=self.batch();before=copy.deepcopy(b);rows=self.rows(b)
        self.assertEqual(fixed.tell(b,rows),fixed.tell(b,list(reversed(rows))))
        self.assertEqual(b,before)

    def test_06_negative_rewards_and_zero_world_authority(self):
        b=self.batch();result,record=fixed.tell(b,self.rows(b,(-.3,-.7,-.8,-.9)))
        self.assertEqual(record["underlying_update"]["rollout_count"],8)
        self.assertEqual((record["world_build_count"],record["solver_steps"]),(0,0))
        self.assertFalse(record["physical_acceptance_authority"]);self.assertFalse(record["release_authority"])
        self.assertEqual(record["next_policy_sha256"],result.sha256)

    def test_07_analytic_post_handoff_tilt_reward_and_denominator(self):
        controls,trace,c=self.native()
        score=objective.score(controls,trace,c,training=False)
        self.assertAlmostEqual(score["training_reward"],-.125,places=14)
        self.assertEqual(score["reward_denominator"],20)
        self.assertEqual(score["walking_reward_diagnostic"]["reward_denominator"],320)
        self.assertEqual(score["walking_reward_diagnostic"]["training_reward"],0.)
        self.assertEqual(score["recovery_objective"]["surviving_internal_samples"],20)

    def test_08_first_violation_and_fixed_remaining_failure_padding(self):
        controls,trace,c=self.native()
        trace[310]["qpos"][3:5]=[math.cos(.7/2),math.sin(.7/2)]
        score=objective.score(controls,trace,c,training=False)
        self.assertAlmostEqual(score["training_reward"],-.5625,places=14)
        self.assertEqual(score["first_reward_failure"]["internal_step"],311)
        self.assertEqual(score["recovery_objective"]["failure_padded_samples"],10)
        self.assertIsNone(score["official_quality_m_s"])

    def test_09_prefix_failure_keeps_all_post_handoff_samples_negative(self):
        controls,trace,c=self.native();trace[100]["qpos"][2]=.1
        score=objective.score(controls,trace,c,training=False)
        self.assertEqual(score["training_reward"],-1.)
        self.assertFalse(score["recovery_objective"]["prefix_eligible"])
        self.assertEqual(score["recovery_objective"]["failure_padded_samples"],20)

    def test_10_safe_no_actuation_is_a_physical_objective_failure(self):
        controls,trace,c=self.native();controls[62]["output"]["actuation"]["safe_no_actuation"]=True
        score=objective.score(controls,trace,c,training=False)
        self.assertEqual(score["first_reward_failure"]["internal_step"],311)
        self.assertIn("safe_no_actuation",score["first_reward_failure"]["failure_codes"])

    def test_11_prefix_tracking_does_not_change_recovery_reward(self):
        controls,trace,c=self.native();a=objective.score(controls,trace,c,training=False)
        for row in trace[:300]:row["qvel"][0]=1.2
        b=objective.score(controls,trace,c,training=False)
        self.assertEqual(a["training_reward"],b["training_reward"])
        self.assertEqual(a["reward_samples_sha256"],b["reward_samples_sha256"])
        self.assertNotEqual(a["walking_reward_diagnostic"],b["walking_reward_diagnostic"])

    def test_12_changed_objective_and_incomplete_or_reordered_native_rows_refuse(self):
        controls,trace,c=self.native();bad=copy.deepcopy(c);bad["recovery_objective"]["failure_value"]=0.
        for rows,contract in ((trace,bad),(trace[:-1],c),(list(reversed(trace)),c)):
            with self.assertRaises(ValueError):objective.score(controls,rows,contract,training=False)

    def test_13_observed_moments_are_retained_without_comparison_fitting(self):
        controls,trace,c=self.native()
        train=objective.score(controls,trace,c,training=True);comparison=objective.score(controls,trace,c,training=False)
        self.assertEqual(train["observations"]["count"],64);self.assertIsNone(comparison["observations"])
        self.assertEqual(train["training_reward"],comparison["training_reward"])
        self.assertFalse(comparison["comparison_data_used_for_training"])

    def test_14_selection_prioritizes_worst_group_before_mean(self):
        result=self.select(self.candidates())
        self.assertEqual(result["selected_candidate_id"],"b")
        self.assertEqual(result["candidate_count"],2)
        self.assertFalse(result["comparison_data_used_for_selection"])
        self.assertFalse(result["physical_acceptance_authority"])

    def test_15_selection_prioritizes_complete_eligible_count(self):
        candidates=self.candidates()
        candidates[0]["trials"][0].update(diagnostic_eligible=True,first_reward_failure=None,official_quality_m_s=-.2)
        self.assertEqual(self.select(candidates)["selected_candidate_id"],"a")

    def test_16_selection_lexical_ties_and_arrival_order(self):
        candidates=self.candidates()
        for row in candidates[0]["trials"]:row["training_reward"]=-.5
        expected=self.select(candidates)
        self.assertEqual(expected["selected_candidate_id"],"a")
        for item in candidates:item["trials"].reverse()
        self.assertEqual(expected,self.select(list(reversed(candidates))))

    def test_17_selection_missing_duplicate_or_crossed_population_refuses(self):
        candidates=self.candidates()
        for bad in (candidates[:-1],candidates+[candidates[0]]):
            with self.assertRaises(ValueError):self.select(bad)
        for change in (lambda x:x[0]["trials"].pop(),
            lambda x:x[0]["trials"][0].__setitem__("group_id","reserved"),
            lambda x:x[0]["trials"][0].__setitem__("trial_id",x[0]["trials"][1]["trial_id"]),
            lambda x:x[0]["trials"][0].__setitem__("provider_model_sha256","crossed")):
            bad=copy.deepcopy(candidates);change(bad)
            with self.assertRaises(ValueError):self.select(bad)

    def test_18_selection_reserved_comparison_or_uncensored_failure_refuses(self):
        for key,value in (("partition","development_comparison"),("comparison_data_used_for_training",True),
            ("official_quality_m_s",0.),("reward_denominator",7200),("training_reward",float("nan"))):
            bad=self.candidates();bad[0]["trials"][0][key]=value
            with self.assertRaises(ValueError):self.select(bad)


if __name__=="__main__":unittest.main()
