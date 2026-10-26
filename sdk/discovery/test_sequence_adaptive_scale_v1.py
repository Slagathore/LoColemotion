"""Adaptive scale decisions, exact regressions and corrupted-schedule controls."""
import copy
import math
import unittest
from unittest.mock import patch
import numpy as np
import predictive_sequence_adaptive_scale_v1 as adaptive
import sequence_adaptive_scale_checks_v1 as checks
from predictive_sequence_local_search_v1 import options as original_options
from test_sequence_constraint_repair_v1 import case,fixture,SELECTOR,VALUE,SEED


class AdaptiveScaleControls(unittest.TestCase):
    def trace(self,kind="feasible"):
        records=[]
        def evaluate(selector,value,knots,horizon):
            if kind=="stalled":return case(good=65,joint=.73)
            if kind=="improving":
                q=.72-3.5/600.+2e-6+.002*math.exp(knots[0][0])
                return case(good=65,joint=q,cost=1.)
            return fixture(selector,value,knots,horizon)
        with patch.object(adaptive,"evaluate",side_effect=evaluate):
            result=adaptive.search(SELECTOR,copy.deepcopy(VALUE),copy.deepcopy(SEED),records.append)
        return records,result

    def verify(self,records,result,retained=False):
        with patch.object(checks,"verify_sequence") as replay:
            out=checks.verify_population(records,result,VALUE,SEED,SELECTOR,retained_regression=retained)
        self.assertEqual(replay.call_count,316);return out

    def test_01_inherited_schedule_preserves_all_options(self):
        for i,scale in enumerate((.4,.2,.1,.05)):
            self.assertEqual(adaptive.options(VALUE,SEED,i,scale),original_options(VALUE,SEED,i))

    def test_02_independent_dynamic_population_and_clipping(self):
        center=np.full((4,8),3.4).tolist()
        for scale in (.4,.3,.2,.1,.05):
            rows=adaptive.options(VALUE,center,2,scale)
            self.assertEqual(rows,checks.independent_options(VALUE,center,2,scale))
            self.assertEqual(len(rows),79)
            self.assertTrue(all(np.max(np.abs(x["knots"]))<=3.5 for x in rows))

    def test_03_repeatability_and_causal_input_immutability(self):
        value=copy.deepcopy(VALUE);seed=copy.deepcopy(SEED);before=copy.deepcopy((value,seed))
        first=adaptive.options(value,seed,0,.4)
        self.assertEqual(first,adaptive.options(value,seed,0,.4))
        self.assertNotEqual(first[65:],adaptive.options(value,seed,1,.4)[65:])
        self.assertEqual((value,seed),before)

    def test_04_longer_prefix_retains_scale(self):
        self.assertEqual(adaptive.next_scale(0,.4,(True,-63,False,.001,1.),(True,-65,False,.2,10.)),(.4,True))

    def test_05_smaller_violation_retains_scale(self):
        self.assertEqual(adaptive.next_scale(1,.4,(True,-65,False,.1,1.),(True,-65,False,.05,10.)),(.4,True))

    def test_06_finite_predictor_replacing_numerical_refusal(self):
        self.assertEqual(adaptive.next_scale(1,.2,(True,-65,True,0.,1e300),(True,-65,False,1.,10.)),(.2,True))

    def test_07_ties_and_cost_only_gains_shrink(self):
        before=(True,-65,False,.1,2.)
        for after in (before,(True,-65,False,.1,1.)):
            self.assertEqual(adaptive.next_scale(1,.4,before,after),(.2,False))

    def test_08_feasible_round_uses_absolute_original_schedule(self):
        for i,expected in enumerate((.2,.1,.05)):
            self.assertEqual(adaptive.next_scale(i,.4,(True,-65,False,.1,1.),(False,-66,False,0.,10.)),(expected,True))

    def test_09_last_round_never_adds_evaluations(self):
        self.assertEqual(adaptive.next_scale(3,.4,(True,-65,False,.1,2.),(True,-65,False,.01,3.)),(None,True))

    def test_10_invalid_schedule_domains_and_future_inputs(self):
        rank=(True,-65,False,.1,1.)
        for scale in (0.,-.1,.41,float("nan"),True):
            with self.assertRaises(ValueError):adaptive.options(VALUE,SEED,0,scale)
            with self.assertRaises(ValueError):adaptive.next_scale(0,scale,rank,rank)
        for i in (-1,4,True):
            with self.assertRaises(ValueError):adaptive.options(VALUE,SEED,i,.4)
        with self.assertRaises(ValueError):adaptive.next_scale(0,.4,rank,(True,-64,False,.1,1.))
        with self.assertRaises(ValueError):adaptive.options(dict(VALUE,future_observation=[]),SEED,0,.4)

    def test_11_stalled_search_contracts_and_stays_refused(self):
        records,result=self.trace("stalled")
        self.assertEqual([x["scale"] for x in result["rounds"]],[.4,.2,.1,.05])
        self.assertFalse(result["accepted"]);self.assertEqual(len(records),316)
        self.verify(records,result)

    def test_12_improving_rejected_search_retains_scale(self):
        records,result=self.trace("improving")
        self.assertEqual(result["rounds"][1]["scale"],.4)
        for round_ in result["rounds"][:-1]:
            expected=round_["scale"] if round_["feasibility_improved"] else round_["scale"]*.5
            self.assertEqual(round_["next_scale"],expected)
        self.assertFalse(result["accepted"]);self.verify(records,result)

    def test_13_complete_feasible_search_and_no_authority(self):
        records,result=self.trace();out=self.verify(records,result)
        self.assertTrue(out["accepted"]);self.assertTrue(all(result[k] is False for k in checks.FLAGS))
        self.assertEqual([x["scale"] for x in result["rounds"]],[.4,.2,.1,.05])

    def test_14_crossed_scale_or_winner_refused(self):
        for key in ("scale","winner_index"):
            records,result=self.trace();result=copy.deepcopy(result);result["rounds"][0][key]+=.1
            with patch.object(checks,"verify_sequence"):
                with self.assertRaises(ValueError):checks.verify_population(records,result,VALUE,SEED,SELECTOR)

    def test_15_crossed_incumbent_and_progress_reason_refused(self):
        for kind in ("incumbent","progress"):
            records,result=self.trace();result=copy.deepcopy(result)
            if kind=="incumbent":result["rounds"][0]["incumbent_rank"][-1]+=1.
            else:result["rounds"][0]["feasibility_improved"]=not result["rounds"][0]["feasibility_improved"]
            with patch.object(checks,"verify_sequence"):
                with self.assertRaises(ValueError):checks.verify_population(records,result,VALUE,SEED,SELECTOR)

    def test_16_crossed_next_scale_and_candidate_refused(self):
        for kind in ("next","candidate"):
            records,result=self.trace();result=copy.deepcopy(result)
            if kind=="next":result["rounds"][0]["next_scale"]=.3
            else:records[0]["option"]["knots"][0][0]=.01
            with patch.object(checks,"verify_sequence"):
                with self.assertRaises(ValueError):checks.verify_population(records,result,VALUE,SEED,SELECTOR)

    def test_17_incomplete_extra_or_false_authority_refused(self):
        for kind in ("missing","extra","authority"):
            records,result=self.trace();result=copy.deepcopy(result)
            if kind=="missing":records=records[:-1]
            elif kind=="extra":records=records+[records[-1]]
            else:result["training_data_authority"]=True
            with patch.object(checks,"verify_sequence"):
                with self.assertRaises(ValueError):checks.verify_population(records,result,VALUE,SEED,SELECTOR)

    def test_18_retained_legacy_regression_uses_original_schedule(self):
        records,result=self.trace()
        for row in records:row.pop("constraint_violation")
        result.pop("strategy")
        for i,round_ in enumerate(result["rounds"]):
            result["rounds"][i]={k:round_[k] for k in ("iteration","scale","evaluated","eligible_candidates","winner_index")}
            result["rounds"][i]["rank"]=[round_["rank"][j] for j in (0,1,4)]
        out=self.verify(records,result,True)
        self.assertTrue(out["previous_winners_preserved"]);self.assertFalse(out["new_forecasts_generated"])


if __name__=="__main__":unittest.main()
