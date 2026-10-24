"""Analytical and complete-population controls for the pure residual optimizer."""
import copy
from dataclasses import replace
import math
import unittest

from adaptation_provider import bounded_residual_ars_v1 as ars


class ArsControls(unittest.TestCase):
    def policy(self,dimension=2):
        return ars.Policy(((0.,)*dimension,),ars.Moments.empty(dimension),(3.5,),1e-8)

    def batch(self,groups=("weak","healthy"),directions=2,selected=1,iteration=0,seed=73):
        return ars.ask(self.policy(),ars.Plan(iteration,seed,groups,directions,selected,.03,.2))

    def rows(self,batch,rewards=(3.,1.,0.,-1.)):
        result=[]
        for i,s,g in batch.identities():
            reward=rewards[2*i+(s==-1)]
            observations=ars.Moments.empty(2).add([(float(i+s),float(len(result)))],partition="training")
            result.append(ars.Rollout(batch.sha256,batch.candidate(i,s).sha256,i,s,g,"training",
                                      f"trial_{i}_{s}_{g}",reward,observations))
        return result

    def test_analytic_top_direction_update_uses_paired_reward_deviation(self):
        batch=self.batch();before=copy.deepcopy(batch);rows=self.rows(batch)
        result,audit=ars.tell(batch,rows)
        # Chosen rewards 3 and 1 have population deviation 1, so the
        # published update is alpha * (3-1) / 1 * delta = 0.4 delta.
        self.assertEqual(audit["selected_directions"],[0])
        for got,delta in zip(result.weights[0],batch.perturbations[0][0],strict=True):
            self.assertAlmostEqual(got,.4*delta,places=14)
        self.assertEqual(batch,before)
        self.assertEqual(audit["rollout_count"],8)
        self.assertEqual(result.moments.count,8)
        self.assertAlmostEqual(result.moments.mean[1],3.5)
        self.assertEqual(audit["previous_policy_sha256"],batch.policy.sha256)
        self.assertNotEqual(result.sha256,batch.policy.sha256)

    def test_balanced_group_aggregation_and_arrival_order_independence(self):
        batch=self.batch();rows=self.rows(batch)
        # Two groups per sign: + rewards 7,-1 average 3; - rewards 3,-1 average 1.
        rows[0]=replace(rows[0],reward=7.)
        rows[1]=replace(rows[1],reward=-1.)
        rows[2]=replace(rows[2],reward=3.)
        rows[3]=replace(rows[3],reward=-1.)
        forward=ars.tell(batch,rows);backward=ars.tell(batch,list(reversed(rows)))
        self.assertEqual(forward,backward)
        self.assertEqual(forward[1]["paired_mean_rewards"][0],(3.,1.))
        self.assertEqual(forward[1]["ordered_trial_ids"],[r.trial_id for r in rows])

    def test_antithetic_candidates_frozen_normalizer_and_deterministic_seed(self):
        batch=self.batch()
        self.assertEqual(batch,ars.ask(batch.policy,batch.plan))
        self.assertNotEqual(batch.sha256,ars.ask(batch.policy,replace(batch.plan,seed=74)).sha256)
        for i in range(2):
            positive,negative=batch.candidate(i,1),batch.candidate(i,-1)
            self.assertEqual(positive.moments,batch.policy.moments)
            for plus,minus,w in zip(positive.weights[0],negative.weights[0],batch.policy.weights[0],strict=True):
                self.assertEqual(plus+minus,2*w)
        with self.assertRaisesRegex(ValueError,"perturbations changed"):
            ars.tell(replace(batch,perturbations=tuple(reversed(batch.perturbations))),self.rows(batch))

    def test_all_negative_rewards_are_retained_and_equal_rewards_keep_weights(self):
        batch=self.batch()
        _,audit=ars.tell(batch,self.rows(batch,(-1.,-3.,-4.,-5.)))
        self.assertEqual(audit["selected_directions"],[0])
        result,audit=ars.tell(batch,self.rows(batch,(-8.,)*4))
        self.assertTrue(audit["zero_reward_variance"])
        self.assertEqual(result.weights,batch.policy.weights)
        self.assertEqual(result.moments.count,8)
        self.assertEqual(audit["ordered_trial_ids"],[r.trial_id for r in self.rows(batch)])
        self.assertFalse(audit["physical_acceptance_authority"])

    def test_population_corruptions_refuse_instead_of_dropping_rows(self):
        batch=self.batch();rows=self.rows(batch)
        with self.assertRaisesRegex(ValueError,"Incomplete"):ars.tell(batch,rows[:-1])
        alterations=[
            (0,replace(rows[0],direction=True)),
            (0,replace(rows[0],sign=True)),
            (0,replace(rows[0],group="unexposed")),
            (0,replace(rows[0],partition="evaluation")),
            (0,replace(rows[0],partition="calibration")),
            (0,replace(rows[0],policy_sha256=rows[2].policy_sha256)),
            (0,replace(rows[0],batch_sha256="sha256:"+"0"*64)),
            (0,replace(rows[0],reward=float("nan"))),
            (0,replace(rows[0],reward=float("inf"))),
            (0,replace(rows[0],observations=ars.Moments.empty(2))),
            (0,replace(rows[0],observations=ars.Moments.empty(1).add([(0.,)],partition="training"))),
            (1,rows[0]),
            (1,replace(rows[1],trial_id=rows[0].trial_id))]
        for index,changed in alterations:
            with self.subTest(changed=changed):
                corrupt=list(rows);corrupt[index]=changed
                with self.assertRaises(ValueError):ars.tell(batch,corrupt)

    def test_moments_match_independent_population_and_zero_variance_rule(self):
        states=[(1.,7.),(2.,7.),(5.,7.),(-4.,7.)]
        first=ars.Moments.empty(2).add(states[:2],partition="training")
        second=ars.Moments.empty(2).add(states[2:],partition="training")
        merged=first.merge(second)
        self.assertEqual(merged.count,4)
        means=tuple(sum(row[j] for row in states)/4 for j in range(2))
        variances=tuple(sum((row[j]-means[j])**2 for row in states)/4 for j in range(2))
        for j in range(2):
            self.assertAlmostEqual(merged.mean[j],means[j])
            self.assertAlmostEqual(merged.m2[j]/4,variances[j])
        self.assertAlmostEqual(merged.normalize((2.,20.),1e-8)[0],1/math.sqrt(10.5))
        self.assertEqual(merged.normalize((2.,20.),1e-8)[1],0.)
        self.assertEqual(ars.Moments.empty(2).normalize((2.,20.),1e-8),(2.,20.))
        with self.assertRaisesRegex(ValueError,"Only training"):
            first.add(states,partition="evaluation")
        for bad in [ars.Moments(0,(1.,0.),(0.,0.)),ars.Moments(1,(0.,0.),(1.,0.)),
                    ars.Moments(2,(0.,0.),(-1.,0.))]:
            with self.assertRaises(ValueError):bad.validate()

    def test_bounded_output_and_zero_policy_do_not_claim_support(self):
        policy=self.policy()
        self.assertEqual(policy.action((1e100,-1e100)),(0.,))
        nonzero=replace(policy,weights=((1.,-1.),))
        self.assertEqual(nonzero.action((100.,-100.)),(3.5,))
        self.assertEqual(nonzero.action((-100.,100.)),(-3.5,))
        with self.assertRaises(ValueError):nonzero.action((float("nan"),1.))
        with self.assertRaises(ValueError):nonzero.action((1.,))
        with self.assertRaises(ValueError):replace(nonzero,weights=([1.,-1.],)).validate()

    def test_reward_scale_and_shift_invariance_with_finite_extremes(self):
        batch=self.batch();baseline=ars.tell(batch,self.rows(batch))[0].weights
        for rewards in [(3e300,1e300,0.,-1e300),(103.,101.,100.,99.)]:
            result,_=ars.tell(batch,self.rows(batch,rewards))
            for got,w in zip(result.weights[0],baseline[0],strict=True):
                self.assertAlmostEqual(got,w,places=13)

    def test_invalid_plans_and_numeric_state_refuse(self):
        batch=self.batch()
        for change in [dict(groups=("same","same")),dict(groups=()),dict(selected_directions=0),
                       dict(selected_directions=3),dict(noise_scale=0.),dict(step_size=float("inf")),
                       dict(iteration=-1),dict(seed=True),dict(directions=2.5)]:
            with self.assertRaises(ValueError):ars.ask(batch.policy,replace(batch.plan,**change))
        with self.assertRaises(ValueError):batch.candidate(0,0)
        with self.assertRaises(ValueError):batch.candidate(True,1)

    def test_real_training_iterations_improve_a_bounded_analytical_control_objective(self):
        # Analytical plant x_next = x + bounded_action, target 2*x at x=-1,+1.
        # This is an optimizer control, explicitly not native locomotion evidence.
        policy=self.policy()
        reward=lambda p:-sum((x+p.action((x,0.))[0]-2*x)**2 for x in (-1.,1.))/2
        original=reward(policy);digests=[]
        for iteration in range(12):
            batch=ars.ask(policy,ars.Plan(iteration,900+iteration,("analytical",),8,4,.03,.025))
            rows=[]
            for i,s,g in batch.identities():
                candidate=batch.candidate(i,s)
                # Balanced input statistics keep this plant's normalized coordinate
                # exactly 1 without introducing information from evaluation data.
                moments=ars.Moments.empty(2).add([(-1.,0.),(1.,0.)],partition="training")
                rows.append(ars.Rollout(batch.sha256,candidate.sha256,i,s,g,"training",
                                       f"plant_{iteration}_{i}_{s}",reward(candidate),moments))
            policy,audit=ars.tell(batch,rows)
            digests.append(policy.sha256)
            self.assertEqual(audit["world_build_count"],0)
        self.assertEqual(len(set(digests)),12)
        self.assertGreater(reward(policy),original)
        self.assertLess(abs(policy.action((1.,0.))[0]-1.),.15)


if __name__ == "__main__":
    unittest.main(verbosity=2)
