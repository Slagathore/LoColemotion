"""Refuse leakage and invalid context; check blocked fitting without native worlds."""
import copy
import json
import math
import os
from pathlib import Path
import unittest
from unittest.mock import patch

import mujoco
import early_context_v1 as estimator
import early_context_feasibility as reader


def request():
    def state(step):
        return dict(semantic_step=step,sample_time_s=step*estimator.DT,
            ordered_joint_observations=[dict(joint_id=j,position_rad=.25*step*estimator.DT,
                validity=dict(position=True)) for j in estimator.JOINTS])
    entries=[]
    for step in range(16):
        entries.append(dict(semantic_step=step,state=state(step),command=dict(command_id=str(step)),
            deterministic_baseline=dict(ordered_commands=[dict(actuator_id=a,
                maximum_target_speed_rad_s=2.,combined_canonical_target_velocity_rad_s=.5) for a in estimator.ACTUATORS]),
            ordered_applied_corrections=[dict(actuator_id=a,canonical_velocity_delta_rad_s=0.) for a in estimator.ACTUATORS],
            provider_status="no_proposal",adaptation_applied=False,request_sha256="0"*64,resolution_receipt_sha256="1"*64))
    return dict(state=state(16),history=dict(schema_version=estimator.history.SCHEMA,ordered_entries=entries))


def groups():
    result=[]
    for label in estimator.LABELS:
        for start in estimator.STARTS:
            feature=estimator.features(request())
            # Two symmetric analytic clusters: means -1/+1, RMS fixed at one.
            feature["values"]=[-1. if label=="left_075" else 1.]*8+[1.]*8
            result.append(dict(group_id=label+"_"+start,condition_id=label,start_id=start,
                partition="training",matching_fresh_prefixes=3,features=feature))
    return result


class EarlyContextControls(unittest.TestCase):
    def setUp(self):
        for name in ["MjModel","MjData","mj_step","mj_step1","mj_step2","mj_forward"]:
            guard=patch.object(mujoco,name,side_effect=AssertionError("No worlds in early context diagnostic"))
            guard.start();self.addCleanup(guard.stop)

    def test_known_motion_uses_actual_velocity_and_current_endpoint(self):
        value=request();result=estimator.features(value)
        for v in result["values"][:8]:self.assertAlmostEqual(v,-.25,places=14)
        for v in result["values"][8:]:self.assertAlmostEqual(v,.25,places=14)
        for entry in value["history"]["ordered_entries"]:
            entry["deterministic_baseline"]["ordered_commands"][0]["combined_canonical_target_velocity_rad_s"]=2.
        changed=estimator.features(value)
        self.assertAlmostEqual(changed["values"][0],-1.75,places=14)
        self.assertAlmostEqual(changed["values"][8],1.75,places=14)
        value["state"]["ordered_joint_observations"][0]["position_rad"] += .01
        endpoint=estimator.features(value)
        self.assertAlmostEqual(endpoint["values"][0]-changed["values"][0],.01/estimator.DT/16,places=13)
        self.assertNotEqual(endpoint["causal_input_sha256"],changed["causal_input_sha256"])

    def test_labels_outcomes_provider_identity_and_receipt_metadata_do_not_enter_feature(self):
        value=request();expected=estimator.features(value)
        value.update(condition_id="other",future_outcome="positive",expected_model_id="future",seed=100)
        for entry in value["history"]["ordered_entries"]:
            entry["request_sha256"]="2"*64;entry["resolution_receipt_sha256"]="3"*64
        self.assertEqual(estimator.features(value),expected)
        data=groups();model=estimator.fit(data)
        for g in data:g["future_outcome"]="unavailable"
        changed=estimator.fit(data)
        self.assertEqual(model["centroids"],changed["centroids"])
        self.assertEqual(estimator.predict(model,data[0]["features"]),estimator.predict(changed,data[0]["features"]))

    def test_incomplete_noncausal_invalid_nonbaseline_or_unprojected_history_refuses(self):
        changes=[lambda r:r["history"]["ordered_entries"].pop(),
            lambda r:r["history"]["ordered_entries"][0].__setitem__("semantic_step",16),
            lambda r:r["history"]["ordered_entries"][0].__setitem__("provider_status",None),
            lambda r:r["history"]["ordered_entries"][0].__setitem__("adaptation_applied",True),
            lambda r:r["state"]["ordered_joint_observations"][0].__setitem__("position_rad",float("nan")),
            lambda r:r["state"]["ordered_joint_observations"][0].__setitem__("position_rad",True),
            lambda r:r["state"].__setitem__("sample_time_s",17*estimator.DT),
            lambda r:r["state"]["ordered_joint_observations"].reverse(),
            lambda r:r["history"]["ordered_entries"][0]["deterministic_baseline"]["ordered_commands"][0].__setitem__("combined_canonical_target_velocity_rad_s",3.)]
        for change in changes:
            value=request();change(value)
            with self.assertRaises(ValueError):estimator.features(value)

    def test_centroids_are_analytic_blocked_and_association_control_is_distinct(self):
        data=groups();result=estimator.evaluate(data)
        self.assertEqual((result["correct"],result["constant_nominal_correct"],result["swapped_association_correct"]),(8,4,0))
        self.assertEqual(len(result["folds"]),4)
        for fold in result["folds"]:
            held=fold["held_out_training_start"]
            self.assertEqual(len(fold["model"]["training_group_ids"]),6)
            self.assertTrue(all(not name.endswith(held) for name in fold["model"]["training_group_ids"]))
            self.assertEqual({p["expected_condition_id"] for p in fold["predictions"]},set(estimator.LABELS))
        middle=copy.deepcopy(data[0]["features"]);middle["values"]=8*[0.]+8*[1.]
        prediction=estimator.predict(result["all_training_model"],middle)
        self.assertEqual(prediction["status"],"ambiguous");self.assertIsNone(prediction["condition_id"])
        self.assertEqual(list(prediction["squared_distances"].values()),[8.,8.])

    def test_split_duplicate_missing_groups_and_unearned_action_authority_refuse(self):
        changes=[lambda g:g.pop(),lambda g:g.append(copy.deepcopy(g[0])),
            lambda g:g[0].__setitem__("partition","calibration"),
            lambda g:g[0].__setitem__("start_id","train_002"),
            lambda g:g[0].__setitem__("matching_fresh_prefixes",1),
            lambda g:g[0]["features"]["values"].__setitem__(0,float("inf"))]
        for change in changes:
            data=groups();change(data)
            with self.assertRaises(ValueError):estimator.evaluate(data)
        data=groups();model=estimator.fit(data)
        for key,value in [("control_authority",True),("action_mapping",{"left_075":2}),("qualification_or_release_authority",True)]:
            bad=copy.deepcopy(model);bad[key]=value
            with self.assertRaisesRegex(ValueError,"model scope"):estimator.predict(bad,data[0]["features"])

    def test_declaration_preserves_failed_parent_and_unopened_reservations(self):
        c=reader.declaration()
        self.assertEqual(c["decision_step"],16);self.assertEqual(c["worlds_opened"],0)
        self.assertFalse(c["reserved_calibration_exposed"]);self.assertFalse(c["reserved_evaluation_exposed"])
        self.assertFalse(c["previous_confirmation_fitting"]);self.assertIsNone(c["action_mapping"])
        altered=copy.deepcopy(c);altered["decision_step"]=32
        with patch.object(reader,"read",return_value=altered):
            with self.assertRaisesRegex(ValueError,"declaration/parent"):reader.declaration()

    def test_retained_native_training_data_rejoins_without_worlds(self):
        core=Path(os.environ["QUADRUPED_TEST_CORE"]);baseline=Path(os.environ["PORTABLE_BATCH_BASELINE_CORE"])
        result=reader.run(reader.ROOT.parent/"SporeSpore_Evidence",core,baseline)
        self.assertTrue(result["ok"]);self.assertEqual(result["worlds_opened"],0)
        self.assertEqual(len(result["groups"]),8);self.assertEqual(result["parent_artifacts_verified"],9181)
        self.assertEqual(result["parent_native_outcomes"],dict(eligible=12,negative=12,denominator=24))
        self.assertEqual(len([s for g in result["groups"] for s in g["sources"]]),24)
        self.assertEqual(sum(s["original_whole_episode_outcome"]=="negative" for g in result["groups"] for s in g["sources"]),12)
        self.assertFalse(result["evaluation"]["physical_control_effectiveness_tested"])
        root=Path(os.environ["EXPLORER_TEST_OUTPUT"])
        with (root/"tested-training-analysis.json").open("x",encoding="utf-8",newline="\n") as stream:
            json.dump(result,stream,indent=2,allow_nan=False);stream.write("\n")


if __name__ == "__main__":unittest.main()
