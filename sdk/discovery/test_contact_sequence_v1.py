"""Geometry, ranking, finite-budget and corruption controls; no native worlds."""
import copy
from types import SimpleNamespace
import unittest
from unittest.mock import patch
import numpy as np
import predictive_contact_sequence_v1 as component
import contact_sequence_checks_v1 as checks
from predictive_sequence_v1 import parameters
from sequence_authority_task_v1 import TRIAL,read
from test_sequence_constraint_repair_v1 import case,SELECTOR,VALUE

SEED=np.zeros((4,8)).tolist()


def forecast(**kwargs):
    r=case(**kwargs);r["completed_predicted_steps"]=sum(x["forecast"]["completed_steps"] for x in r["rows"]);return r


class ToyMetric:
    feet=[(i,name,np.zeros((2,3)),0.) for i,name in enumerate(component.FOOT_NAMES)]
    def frame(self,q):
        return dict(positions=[np.array([0.,q[7],0.]) for _ in range(4)],rotations=[np.eye(3) for _ in range(4)])
    def clearance(self,q):return [q[7]]*4
    score=component.ClearanceMetric.score


class ContactControls(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.prepared=read(TRIAL/"force-profile.json")["prepared_model"]
        cls.metric=component.ClearanceMetric(cls.prepared)

    def q(self):return [0.,0.,1.,1.,0.,0.,0.]+[0.]*8
    def trace(self,refused=False):
        rows=[]
        def evaluate(selector,value,knots,horizon):
            if refused:return forecast(good=65,joint=.73)
            h=.05+.005*(knots[0][0]-3.5)**2
            return forecast(joint=h,cost=float(np.sum(np.square(knots))))
        with patch.object(component,"evaluate",side_effect=evaluate):
            result=component.search(SELECTOR,ToyMetric(),copy.deepcopy(VALUE),copy.deepcopy(SEED),rows.append)
        return rows,result
    def verify(self,rows,result):
        with patch.object(checks,"verify_sequence") as verify:
            out=checks.verify_population(rows,result,VALUE,SEED,SELECTOR,ToyMetric())
        self.assertEqual(verify.call_count,102);return out

    def test_01_vertical_translation(self):
        q=self.q();a=self.metric.clearance(q);q[2]+=.3
        np.testing.assert_allclose(np.array(self.metric.clearance(q))-a,[.3]*4,atol=1e-12,rtol=0)

    def test_02_horizontal_translation(self):
        q=self.q();a=self.metric.clearance(q);q[0]+=2.;q[1]-=3.
        np.testing.assert_allclose(self.metric.clearance(q),a,atol=1e-12,rtol=0)

    def test_03_scalar_geometry_over_rotated_joint_poses(self):
        for angle in (-.2,.0,.2):
            q=self.q();q[3]=float(np.cos(angle/2));q[4]=float(np.sin(angle/2));q[7:]=[.1,-.2]*4
            r=forecast();r["rows"]=[dict(forecast=dict(rows=[dict(qpos=q)]))];r["completed_predicted_steps"]=1
            checks.check_score(self.metric,r,self.metric.score(r))

    def test_04_distal_endpoint_height_and_radius(self):
        q=self.q();frame=self.metric.frame(q);expected=[]
        for i,_,ends,radius in self.metric.feet:
            world=ends @ frame["rotations"][i].T+frame["positions"][i]
            expected.append(min(float(p[1]) for p in world)-radius)
        self.assertEqual(self.metric.clearance(q),expected)

    def test_05_penetration_has_zero_positive_clearance_cost(self):
        r=forecast(joint=-.1);s=ToyMetric().score(r)
        self.assertEqual(s["mean_squared_clearance_m2"],0.)
        self.assertEqual(s["nonpositive_clearance_states"],[330]*4)
        self.assertIs(s["geometry_is_loaded_contact"],False)
        from test_sequence_authority_v1 import fixture,add_contact
        p=fixture();steps=p[2]["rows"][0]["forecast"]["rows"]
        add_contact(steps[0],3.);add_contact(steps[1],0.)
        counts=component.contact_counts(p[2],self.metric)
        self.assertEqual(counts["geometric_contact_states"],[2,0,0,0])
        self.assertEqual(counts["positive_normal_force_states"],[1,0,0,0])
        p[2]["completed_predicted_steps"]-=1
        with self.assertRaises(ValueError):component.contact_counts(p[2],self.metric)

    def test_06_missing_quaternion_and_nonfinite_state_refused(self):
        for q in (self.q()[:-1],[float("nan")]+self.q()[1:]):
            with self.assertRaises(ValueError):self.metric.clearance(q)
        q=self.q();q[3]=2.
        with self.assertRaises(ValueError):self.metric.clearance(q)

    def test_07_missing_or_reordered_model_geometry_refused(self):
        for mode in ("missing","reorder","radius"):
            p=copy.deepcopy(self.prepared)
            if mode=="missing":p["ordered_geometry"].pop()
            elif mode=="reorder":p["ordered_geometry"][2],p["ordered_geometry"][4]=p["ordered_geometry"][4],p["ordered_geometry"][2]
            else:p["ordered_geometry"][2]["radius_m"]=-1.
            with self.assertRaises(ValueError):component.ClearanceMetric(p)

    def test_08_metric_does_not_mutate_model_or_forecast(self):
        p=copy.deepcopy(self.prepared);r=forecast();before=copy.deepcopy((p,r))
        m=component.ClearanceMetric(p);m.score(r)
        self.assertEqual((p,r),before)

    def test_09_feasible_precedes_any_contact_gain(self):
        good=forecast(joint=.5,cost=1e10);bad=forecast(good=65,joint=.73,cost=0)
        self.assertLess(component.rank(good,ToyMetric().score(good),SELECTOR.limits),
            component.rank(bad,ToyMetric().score(bad),SELECTOR.limits))

    def test_10_longer_prefix_precedes_contact_gain(self):
        a=forecast(good=65,joint=.8);b=forecast(good=64,joint=.73)
        self.assertLess(component.rank(a,ToyMetric().score(a),SELECTOR.limits),
            component.rank(b,ToyMetric().score(b),SELECTOR.limits))

    def test_11_violation_precedes_contact_score(self):
        a=forecast(good=65,joint=.72);b=forecast(good=65,joint=.8)
        sa=ToyMetric().score(a);sa["mean_squared_clearance_m2"]=1e10
        self.assertLess(component.rank(a,sa,SELECTOR.limits),component.rank(b,ToyMetric().score(b),SELECTOR.limits))

    def test_12_clearance_precedes_task_cost_once_admissible(self):
        a=forecast(joint=.1,cost=1e10);b=forecast(joint=.2,cost=0)
        self.assertLess(component.rank(a,ToyMetric().score(a),SELECTOR.limits),
            component.rank(b,ToyMetric().score(b),SELECTOR.limits))

    def test_13_equal_clearance_uses_task_cost(self):
        a=forecast(joint=.1,cost=1.);b=forecast(joint=.1,cost=2.)
        self.assertLess(component.rank(a,ToyMetric().score(a),SELECTOR.limits),
            component.rank(b,ToyMetric().score(b),SELECTOR.limits))

    def test_14_numerical_refusal_has_unavailable_geometry(self):
        a=forecast(good=0,numerical=True);s=ToyMetric().score(a)
        self.assertEqual(s["completed_states"],0);self.assertIsNone(s["mean_squared_clearance_m2"])
        self.assertEqual(component.rank(a,s,SELECTOR.limits)[4],1e300)

    def test_15_invalid_metric_score_refused(self):
        r=forecast()
        for cost in (float("nan"),float("inf"),-.1,None):
            s=ToyMetric().score(r);s["mean_squared_clearance_m2"]=cost
            with self.assertRaises(ValueError):component.rank(r,s,SELECTOR.limits)

    def test_16_independent_proposal_population(self):
        for i in range(3):self.assertEqual(parameters(VALUE,SEED,i),checks.independent_options(VALUE,SEED,i))

    def test_17_complete_search_can_change_an_accepted_decision(self):
        rows,result=self.trace();self.verify(rows,result)
        self.assertTrue(result["accepted"])
        self.assertLess(result["best"]["contact_metric"]["mean_squared_clearance_m2"],result["initial_metric"]["mean_squared_clearance_m2"])
        self.assertFalse(result["original_decision_ordering_preserved"])

    def test_18_complete_refusal_stays_refused(self):
        rows,result=self.trace(refused=True);self.verify(rows,result);self.assertFalse(result["accepted"])

    def test_19_mutated_geometry_metric_refused(self):
        rows,result=self.trace();rows[1]["contact_metric"]["clearance_m"][0][0]+=.01
        with self.assertRaises(ValueError):self.verify(rows,result)

    def test_20_mutated_winner_or_round_refused(self):
        for mode in ("winner","round"):
            rows,result=self.trace()
            if mode=="winner":result["best"]=rows[0]
            else:result["rounds"][0]["winner_index"]+=1
            with self.assertRaises(ValueError):self.verify(rows,result)

    def test_21_missing_extra_or_reordered_candidate_refused(self):
        for mode in ("missing","extra","reorder"):
            rows,result=self.trace()
            if mode=="missing":rows.pop()
            elif mode=="extra":rows.append(copy.deepcopy(rows[-1]))
            else:rows[1],rows[2]=rows[2],rows[1]
            with self.assertRaises(ValueError):self.verify(rows,result)

    def test_22_false_authority_or_guard_change_refused(self):
        for key in ("guard_predicates_changed","actuator_caps_changed","training_data_authority","tier2_qualified","release_authority"):
            rows,result=self.trace();result[key]=True
            with self.assertRaises(ValueError):self.verify(rows,result)

    def test_23_initial_metric_or_eligibility_corruption_refused(self):
        rows,result=self.trace();result["initial_eligible"]=False
        with self.assertRaises(ValueError):self.verify(rows,result)

    def test_24_missing_predicted_state_refused(self):
        r=forecast();r["rows"][0]["forecast"]["rows"][0].pop("qpos")
        with self.assertRaises(ValueError):ToyMetric().score(r)

    def test_25_handoff_retains_actual_nonzero_correction(self):
        from audit_contact_sequence_v1 import bound_input
        value=copy.deepcopy(VALUE);value.update(command=60,previous_correction=[.2]*8)
        previous=dict(resolution=dict(ordered_commands=[dict(applied_correction_rad_s=.2) for _ in range(8)]))
        best=dict(result=dict(valid_intervals=66))
        row=dict(resolution_request=dict(provider_request=dict(provider_memory=dict(sequence=0,opaque_state=dict(plan=None)))),
            force_reference=dict(decision=dict(selection=dict(accepted=True,evaluated_candidates=102,best=best))))
        expected=dict(accepted=True,evaluations=102,valid_intervals=66)
        with patch("audit_contact_sequence_v1.packet",return_value=value):
            self.assertEqual(bound_input(previous,row,{},expected),(value,None,best))
            previous["resolution"]["ordered_commands"][0]["applied_correction_rad_s"]=0.
            with self.assertRaises(ValueError):bound_input(previous,row,{},expected)


if __name__=="__main__":unittest.main()
