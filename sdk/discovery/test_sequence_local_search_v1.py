"""Finite population, causal inputs, immutable guards and retained-data controls."""
import copy
import json
import os
from pathlib import Path
import unittest
from unittest.mock import patch
import uuid
import numpy as np
import predictive_sequence_local_search_v1 as local
import audit_sequence_local_search_v1 as audit
from predictive_sequence_v1 import rank

VALUE=dict(qpos=[0.,0.,.44,1.,0.,0.,0.]+[0.]*8,qvel=[0.]*14,baseline=[0.]*8,
    speeds=[3.5]*8,previous_correction=[0.]*8,nominal_correction=[0.]*8,
    target_com=[0.,.44,0.],reference_joints=[0.]*8,command=81)
SEED=[[0.]*8 for _ in range(4)]


def fixture(selector,value,knots,horizon):
    score=float(np.sum(np.square(np.array(knots)-.1)))
    return dict(eligible=True,valid_intervals=horizon,planned_intervals=horizon,
        mean_objective=score,rows=[])


class LocalControls(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.previous,cls.row,cls.profile,_=audit.inputs()
        cls.core=audit.bridge.LocomotionCore(Path(os.environ["QUADRUPED_TEST_CORE"]))
        cls.policy=audit.Policy(cls.core,cls.profile,audit.DLL)

    def trace(self):
        folder=Path(os.environ["EXPLORER_TEST_OUTPUT"])/uuid.uuid4().hex;folder.mkdir(parents=True)
        path=folder/"candidates.jsonl";records=[]
        with patch.object(local,"evaluate",side_effect=fixture):
            result=local.search(None,copy.deepcopy(VALUE),copy.deepcopy(SEED),records.append)
        path.write_text("".join(json.dumps(r,separators=(",",":"))+"\n" for r in records),encoding="utf-8",newline="\n")
        return path,result,records

    def verify(self,path,result):
        c=dict(maximum_capture_bytes=2**20,maximum_capture_row_bytes=2**16)
        with patch.object(audit,"verify_sequence") as checked:
            audit.verify_trace(path,result,VALUE,SEED,None,c)
            self.assertEqual(checked.call_count,316)

    def test_01_complete_bounded_independent_population(self):
        for i in range(4):
            rows=local.options(VALUE,SEED,i)
            self.assertEqual(len(rows),79);self.assertEqual(rows,audit.independent_options(VALUE,SEED,i))
            self.assertTrue(all(np.max(np.abs(x["knots"]))<=3.5 for x in rows))

    def test_02_individual_coordinate_shapes_and_clipping(self):
        center=np.full((4,8),3.4).tolist();rows=local.options(VALUE,center,0)
        for row in rows[1:65]:
            delta=np.array(row["knots"])-center
            self.assertEqual(np.count_nonzero(delta),1)
            self.assertLessEqual(np.max(np.abs(delta)),.400000000000001)

    def test_03_random_population_is_repeatable_and_round_specific(self):
        self.assertEqual(local.options(VALUE,SEED,0),local.options(VALUE,SEED,0))
        self.assertNotEqual(local.options(VALUE,SEED,0)[65:],local.options(VALUE,SEED,1)[65:])

    def test_04_candidate_inputs_immutable(self):
        value=copy.deepcopy(VALUE);seed=copy.deepcopy(SEED)
        before=copy.deepcopy((value,seed));local.options(value,seed,0)
        self.assertEqual((value,seed),before)

    def test_05_invalid_search_domain_refused(self):
        for iteration in (-1,4,True,1.5):
            with self.assertRaises(ValueError):local.options(VALUE,SEED,iteration)
        for seed in ([[4.]*8]*4,[[float("nan")]*8]*4,[[0.]*7]*4):
            with self.assertRaises(ValueError):local.options(VALUE,seed,0)

    def test_06_future_observation_field_refused(self):
        value=dict(VALUE,future_observation=[])
        with self.assertRaises(ValueError):local.options(value,SEED,0)

    def test_07_search_preserves_incumbent_and_complete_denominator(self):
        records=[]
        with patch.object(local,"evaluate",side_effect=fixture):
            r=local.search(None,VALUE,SEED,records.append)
        ranks=[x["rank"] for x in r["rounds"]]
        self.assertEqual(len(records),316)
        self.assertTrue(all(b<=a for a,b in zip(ranks,ranks[1:])))
        self.assertTrue(r["accepted"]);self.assertFalse(r["actual_native_transfer_verified"])

    def test_08_inadmissible_plan_never_admitted(self):
        def refused(*args):
            r=fixture(*args);r.update(eligible=False,valid_intervals=65);return r
        with patch.object(local,"evaluate",side_effect=refused):
            r=local.search(None,VALUE,SEED,lambda x:None)
        self.assertFalse(r["accepted"]);self.assertEqual(r["horizon"],66)
        self.assertFalse(r["changed_guard"]);self.assertFalse(r["global_infeasibility_established"])

    def test_09_causal_input_mutation_detected(self):
        value=copy.deepcopy(VALUE)
        def mutate(*args):
            value["qpos"][0]+=.001;return fixture(*args)
        with patch.object(local,"evaluate",side_effect=mutate):
            with self.assertRaisesRegex(ValueError,"immutable"):
                local.search(None,value,SEED,lambda x:None)

    def test_10_complete_retained_trace(self):
        path,result,_=self.trace();self.verify(path,result)

    def test_11_crossed_candidate_or_order_refused(self):
        for field in ("iteration","knots"):
            path,result,records=self.trace()
            if field=="iteration":records[0]["iteration"]=1
            else:records[0]["option"]["knots"][0][0]=.01
            path.write_text("".join(json.dumps(r)+"\n" for r in records),encoding="utf-8",newline="\n")
            with self.assertRaises(ValueError):self.verify(path,result)

    def test_12_incomplete_population_false_winner_and_authority_refused(self):
        for kind in ("truncated","extra","winner","authority"):
            path,result,records=self.trace()
            if kind=="truncated":path.write_text(json.dumps(records[0])+"\n",encoding="utf-8",newline="\n")
            elif kind=="extra":
                with path.open("a",encoding="utf-8",newline="\n") as f:f.write("{}\n")
            elif kind=="winner":result["best"]["option"]["index"]+=1
            else:result["training_data_authority"]=True
            with self.assertRaises(ValueError):self.verify(path,result)

    def test_13_exact_retained_refusal_history_and_state(self):
        value,plan,seed=audit.bound_inputs(self.core,self.previous,self.row,self.profile,self.policy.selector)
        self.assertEqual(value["command"],81);self.assertEqual(plan["command"],80)
        self.assertEqual(np.shape(seed),(4,8))
        self.assertEqual(value["previous_correction"],plan["correction"])

    def test_14_crossed_request_digest_refused(self):
        row=dict(self.row);row["force_reference"]=dict(row["force_reference"])
        row["force_reference"]["decision"]=dict(row["force_reference"]["decision"],request_sha256="sha256:"+"0"*64)
        with self.assertRaises(ValueError):
            audit.bound_inputs(self.core,self.previous,row,self.profile,self.policy.selector)

    def test_15_actual_history_mismatch_refused(self):
        previous=dict(self.previous);previous["resolution"]=copy.deepcopy(previous["resolution"])
        previous["resolution"]["ordered_commands"][0]["applied_correction_rad_s"]+=.01
        with self.assertRaises(ValueError):
            audit.bound_inputs(self.core,previous,self.row,self.profile,self.policy.selector)

    def test_16_crossed_clock_and_false_acceptance_refused(self):
        for kind in ("clock","accepted"):
            row=dict(self.row)
            if kind=="clock":row["outer_step"]=82
            else:
                row["force_reference"]=dict(row["force_reference"])
                d=dict(row["force_reference"]["decision"]);d["selection"]=dict(d["selection"],accepted=True)
                row["force_reference"]["decision"]=d
            with self.assertRaises(ValueError):
                audit.bound_inputs(self.core,self.previous,row,self.profile,self.policy.selector)


if __name__=="__main__":unittest.main()
