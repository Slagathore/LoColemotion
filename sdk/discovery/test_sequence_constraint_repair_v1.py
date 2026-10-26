"""Guard boundaries, ordering, finite denominators and corrupted-record controls."""
import copy
import math
from types import SimpleNamespace
import unittest
from unittest.mock import patch
import numpy as np
import predictive_sequence_constraint_repair_v1 as repair
import sequence_constraint_repair_checks_v1 as checks
from predictive_command_selection_v2 import guard
from test_sequence_local_search_v1 import VALUE,SEED

LIMITS=np.array([[-.72,.72]]*8)
SELECTOR=SimpleNamespace(limits=LIMITS)


def case(*,good=66,cost=1.,joint=0.,speed=0.,height=.44,tilt=0.,contacts=None,numerical=False):
    q=[0.,0.,height,math.cos(tilt/2),math.sin(tilt/2),0.,0.]+[joint]+[0.]*7
    v=[0.]*6+[speed]+[0.]*7
    forecast=dict(accepted=not numerical,completed_steps=0 if numerical else 5,
        rows=[] if numerical else [dict(step=i,qpos=q.copy(),qvel=v.copy(),contacts=copy.deepcopy(contacts or [])) for i in range(5)])
    reasons=guard(forecast,LIMITS)
    block=dict(forecast=forecast,guard_reasons=reasons)
    return dict(eligible=good==66,valid_intervals=good,planned_intervals=66,
        attempted_intervals=min(good+1,66),rows=[copy.deepcopy(block) for _ in range(min(good+1,66))],
        rejection_reasons=reasons,mean_objective=None if numerical else float(cost))


def fixture(selector,value,knots,horizon):
    return case(cost=float(np.sum(np.square(np.array(knots)-.1))))


class ConstraintRepairControls(unittest.TestCase):
    def trace(self,refused=False):
        records=[]
        def evaluate(*args):
            out=fixture(*args)
            return case(good=65,cost=out["mean_objective"],joint=.73) if refused else out
        with patch.object(repair,"evaluate",side_effect=evaluate):
            result=repair.search(SELECTOR,copy.deepcopy(VALUE),copy.deepcopy(SEED),records.append)
        return records,result

    def verify(self,records,result):
        with patch.object(checks,"verify_sequence") as replay:
            out=checks.verify_population(records,result,VALUE,SEED,SELECTOR)
            self.assertEqual(replay.call_count,316)
        return out

    def test_01_feasible_cost_order_preserved(self):
        self.assertLess(repair.rank(case(cost=1),LIMITS),repair.rank(case(cost=2),LIMITS))
        self.assertEqual(repair.violation(case(),LIMITS)["normalized_violation"],0.)

    def test_02_feasible_precedes_any_rejected_cost(self):
        self.assertLess(repair.rank(case(cost=1e10),LIMITS),repair.rank(case(good=65,cost=0,joint=.73),LIMITS))

    def test_03_longer_prefix_precedes_smaller_violation(self):
        self.assertLess(repair.rank(case(good=65,joint=.9),LIMITS),repair.rank(case(good=64,joint=.72),LIMITS))

    def test_04_violation_precedes_task_cost(self):
        self.assertLess(repair.rank(case(good=65,cost=1e10,joint=.72),LIMITS),
            repair.rank(case(good=65,cost=0,joint=.8),LIMITS))

    def test_05_equal_violation_uses_original_cost(self):
        self.assertLess(repair.rank(case(good=65,cost=1,joint=.72),LIMITS),
            repair.rank(case(good=65,cost=2,joint=.72),LIMITS))

    def test_06_numerical_refusal_has_no_zero_severity(self):
        result=case(good=65,numerical=True);metric=repair.violation(result,LIMITS)
        self.assertTrue(metric["numerical_refusal"]);self.assertIsNone(metric["normalized_violation"])
        self.assertLess(repair.rank(case(good=65,joint=2.),LIMITS),repair.rank(result,LIMITS))

    def test_07_exact_upper_position_boundary(self):
        high=.72-3.5/600.+2e-6
        self.assertEqual(repair.violation(case(joint=high),LIMITS)["normalized_violation"],0.)
        result=case(good=65,joint=high+.0144)
        self.assertAlmostEqual(repair.violation(result,LIMITS)["normalized_violation"],.01)
        checks.check_metric(result,LIMITS)

    def test_08_exact_lower_position_boundary(self):
        low=-.72+3.5/600.-2e-6
        self.assertEqual(repair.violation(case(joint=low),LIMITS)["normalized_violation"],0.)
        self.assertAlmostEqual(repair.violation(case(good=65,joint=low-.0144),LIMITS)["normalized_violation"],.01)

    def test_09_positive_speed_threshold_and_units(self):
        self.assertEqual(repair.violation(case(speed=3.5+2e-6),LIMITS)["normalized_violation"],0.)
        self.assertAlmostEqual(repair.violation(case(good=65,speed=3.5+2e-6+.035),LIMITS)["normalized_violation"],.01)

    def test_10_negative_speed_threshold_and_units(self):
        self.assertEqual(repair.violation(case(speed=-(3.5+2e-6)),LIMITS)["normalized_violation"],0.)
        self.assertAlmostEqual(repair.violation(case(good=65,speed=-(3.5+2e-6+.035)),LIMITS)["normalized_violation"],.01)

    def test_11_height_boundary_and_units(self):
        self.assertEqual(repair.violation(case(height=.25),LIMITS)["normalized_violation"],0.)
        self.assertAlmostEqual(repair.violation(case(good=65,height=.2),LIMITS)["normalized_violation"],.2)

    def test_12_tilt_units(self):
        result=case(good=65,tilt=.66)
        self.assertAlmostEqual(repair.violation(result,LIMITS)["normalized_violation"],.1)
        checks.check_metric(result,LIMITS)

    def test_13_torso_contact_is_binary_per_step(self):
        result=case(good=65,contacts=[dict(geom=[0,1]),dict(geom=[1,2])])
        self.assertEqual(repair.violation(result,LIMITS)["normalized_violation"],1.)
        self.assertEqual(repair.violation(case(contacts=[dict(geom=[0,2])]),LIMITS)["normalized_violation"],0.)

    def test_14_all_violation_channels_add(self):
        result=case(good=65,joint=.72-3.5/600.+2e-6+.0144,speed=3.5+2e-6+.035,
            height=.2,tilt=.66,contacts=[dict(geom=[0,1])])
        self.assertAlmostEqual(repair.violation(result,LIMITS)["normalized_violation"],1.32)
        checks.check_metric(result,LIMITS)

    def test_15_nonfinite_forecast_refused(self):
        for field,index in (("qpos",7),("qvel",6)):
            result=case();result["rows"][-1]["forecast"]["rows"][0][field][index]=float("nan")
            with self.assertRaises(ValueError):repair.rank(result,LIMITS)

    def test_16_invalid_joint_ranges_refused(self):
        for limits in (np.zeros((8,2)),np.zeros((7,2)),np.full((8,2),float("nan"))):
            with self.assertRaises(ValueError):repair.rank(case(),limits)

    def test_17_changed_horizon_refused(self):
        result=case();result["planned_intervals"]=65
        with self.assertRaises(ValueError):repair.rank(result,LIMITS)

    def test_18_false_eligibility_refused(self):
        for result in (case(good=65),case(good=65,joint=.73)):
            if result["rejection_reasons"]:result["eligible"]=True
            with self.assertRaises(ValueError):repair.rank(result,LIMITS)

    def test_19_crossed_guard_refused(self):
        result=case(good=65,joint=.73);result["rows"][-1]["guard_reasons"]=[]
        with self.assertRaises(ValueError):repair.rank(result,LIMITS)

    def test_20_incomplete_accepted_forecast_refused(self):
        result=case();result["rows"][-1]["forecast"]["rows"].pop()
        with self.assertRaises(ValueError):repair.rank(result,LIMITS)

    def test_21_same_candidate_recipe(self):
        for iteration in range(4):
            self.assertEqual(repair.options(VALUE,SEED,iteration),checks.independent_options(VALUE,SEED,iteration))

    def test_22_complete_search_preserves_causal_inputs(self):
        value=copy.deepcopy(VALUE);seed=copy.deepcopy(SEED);before=copy.deepcopy((value,seed));records=[]
        with patch.object(repair,"evaluate",side_effect=fixture):
            result=repair.search(SELECTOR,value,seed,records.append)
        self.assertEqual((value,seed),before);self.assertEqual(len(records),316)
        self.assertTrue(result["accepted"]);self.assertEqual(result["horizon"],66)

    def test_23_refused_search_never_admitted(self):
        records,result=self.trace(True)
        self.assertFalse(result["accepted"]);self.assertEqual(result["best"]["result"]["valid_intervals"],65)
        self.verify(records,result)

    def test_24_no_new_authority(self):
        _,result=self.trace()
        self.assertTrue(all(result[k] is False for k in checks.FLAGS))

    def test_25_independent_metric_detects_corruption(self):
        result=case(good=65,joint=.73);metric=repair.violation(result,LIMITS)
        metric["normalized_violation"]=0.
        with self.assertRaises(ValueError):checks.check_metric(result,LIMITS,metric)

    def test_26_complete_trace_independently_reconstructed(self):
        records,result=self.trace();self.assertTrue(self.verify(records,result)["accepted"])

    def test_27_truncated_population_refused(self):
        records,result=self.trace()
        with patch.object(checks,"verify_sequence"):
            with self.assertRaises(ValueError):checks.verify_population(records[:-1],result,VALUE,SEED,SELECTOR)

    def test_28_extra_population_refused(self):
        records,result=self.trace()
        with patch.object(checks,"verify_sequence"):
            with self.assertRaises(ValueError):checks.verify_population(records+[records[-1]],result,VALUE,SEED,SELECTOR)

    def test_29_crossed_winner_refused(self):
        records,result=self.trace();result=copy.deepcopy(result);result["best"]["option"]["index"]+=1
        with patch.object(checks,"verify_sequence"):
            with self.assertRaises(ValueError):checks.verify_population(records,result,VALUE,SEED,SELECTOR)

    def test_30_crossed_round_rank_refused(self):
        records,result=self.trace();result["rounds"][0]["rank"][-1]+=1.
        with patch.object(checks,"verify_sequence"):
            with self.assertRaises(ValueError):checks.verify_population(records,result,VALUE,SEED,SELECTOR)

    def test_31_crossed_candidate_coordinates_refused(self):
        records,result=self.trace();records[0]["option"]["knots"][0][0]+=.01
        with patch.object(checks,"verify_sequence"):
            with self.assertRaises(ValueError):checks.verify_population(records,result,VALUE,SEED,SELECTOR)

    def test_32_crossed_retained_metric_refused(self):
        records,result=self.trace();records[0]["constraint_violation"]["normalized_violation"]=1.
        with patch.object(checks,"verify_sequence"):
            with self.assertRaises(ValueError):checks.verify_population(records,result,VALUE,SEED,SELECTOR)


    def test_33_retained_feasible_winners_preserved(self):
        records,result=self.trace()
        for row in records:row.pop("constraint_violation")
        result.pop("strategy")
        for round_ in result["rounds"]:round_["rank"]=[round_["rank"][i] for i in (0,1,4)]
        with patch.object(checks,"verify_sequence") as replay:
            checked=checks.verify_population(records,result,VALUE,SEED,SELECTOR,retained_regression=True)
        self.assertEqual(replay.call_count,316);self.assertTrue(checked["previous_winners_preserved"])
        self.assertFalse(checked["new_forecasts_generated"])

    def test_34_regression_without_feasible_round_refused(self):
        records,result=self.trace(True)
        for row in records:row.pop("constraint_violation")
        result.pop("strategy")
        for round_ in result["rounds"]:round_["rank"]=[round_["rank"][i] for i in (0,1,4)]
        with patch.object(checks,"verify_sequence"):
            with self.assertRaisesRegex(ValueError,"accepted retained winner"):
                checks.verify_population(records,result,VALUE,SEED,SELECTOR,retained_regression=True)


if __name__=="__main__":unittest.main()
