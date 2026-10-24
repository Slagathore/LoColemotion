"""Verify full-population state coverage, causal joins and actual corruption stimuli."""
import copy
from contextlib import ExitStack
from itertools import islice
import json
import os
from pathlib import Path
import unittest
from unittest.mock import patch

import mujoco
import committed_state_coverage_diagnostic as reader


class StateCoverageControls(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.parent=reader.read(reader.PARENT)
        cls.evidence=(reader.ROOT.parent/"SporeSpore_Evidence").resolve(strict=True)
        cls.physical=cls.evidence/cls.parent["attempt_id"]/"physical"
        cls.trials,cls.contract=reader.population(cls.parent)
        cls.directory=cls.physical/"left_075_train_006_current_frozen"
        with (cls.directory/"controller.jsonl").open(encoding="utf-8") as f:
            rows=[json.loads(line) for line in islice(f,88)]
        cls.row=rows[87];cls.first=rows[:2]
        cls.previous=cls.prior(rows[86])
        cls.frame=reader.describe(cls.row,"current_frozen",87,cls.previous)

    @staticmethod
    def prior(row):
        commands=row["resolution"]["ordered_commands"]
        return dict(step=row["outer_step"],commands=commands,
            final=[r["final_canonical_target_velocity_rad_s"] for r in commands],
            correction=[r["applied_correction_rad_s"] for r in commands])

    def setUp(self):
        guards=ExitStack();self.addCleanup(guards.close)
        for name in ["MjModel","MjData","mj_step","mj_step1","mj_step2","mj_forward"]:
            guards.enter_context(patch.object(mujoco,name,side_effect=AssertionError("No worlds in state coverage diagnosis")))

    def frames(self,count=1440):
        features=dict(joint_position_rad=[0.]*8,joint_velocity_rad_s=[0.]*8,
            vertical_velocity_m_s=[0.],roll_pitch_rate_rad_s=[0.,0.],
            previous_final_command_rad_s=[0.]*8,previous_correction_rad_s=[0.]*8,
            exact_phase_commands=[0,0,0,0])
        return [dict(step=i,features=copy.deepcopy(features),final=[0.]*8,correction=[0.]*8,
            qpos=[0.]*15,qvel=[0.]*14,targets=[0.]*8,contacts=[False]*4,
            action=1,applied=True,reason="current_case_retrieval",
            query=dict(phase=[0]*4,contact_mask=0),
            prediction=dict(case_ids=["case"],quality_m_s=-.1,support_distance=.2)) for i in range(count)]

    def cases(self,features):
        return {"case":dict(features=copy.deepcopy(features),action_index=1,
            cue=dict(phase=[0]*4,contact_mask=0),trial_id="source",step=0)}

    def test_complete_all_forty_eight_trials_regenerate(self):
        result=reader.verify_record(Path(os.environ["COMMITTED_STATE_COVERAGE_RECORD"]),self.evidence,
            Path(os.environ["QUADRUPED_TEST_CORE"]),Path(os.environ["PORTABLE_BATCH_BASELINE_CORE"]))
        self.assertTrue(result["ok"])
        self.assertEqual((result["source_trials"],result["controller_rows"],result["internal_samples"]),(48,69120,345600))
        self.assertEqual((result["fitted_source_streams"],result["fitted_feature_rows"],result["fitted_cases"]),(24,21600,21165))
        self.assertTrue(all(result[k] is False for k in reader.AUTHORITY))
        record=reader.read(Path(os.environ["COMMITTED_STATE_COVERAGE_RECORD"]))
        self.assertEqual(sum(t["original_outcome"]=="negative" for t in record["trials"]),19)
        self.assertTrue(all(t["official_quality_m_s"] is None for t in record["trials"] if t["original_outcome"]=="negative"))
        self.assertEqual(sum(len(g["pairs"]) for g in record["groups"]),56)
        print(json.dumps(result,sort_keys=True))

    def test_real_causal_previous_command_and_empty_runtime_history(self):
        first=reader.describe(self.first[0],"current_frozen",0,None)
        second=reader.describe(self.first[1],"current_frozen",1,first)
        self.assertEqual(second["features"]["previous_final_command_rad_s"],first["final"])
        self.assertEqual(self.row["resolution_request"]["provider_request"]["history"]["ordered_entries"],[])
        self.assertEqual(self.frame["features"]["previous_final_command_rad_s"],self.previous["final"])
        altered=copy.deepcopy(self.previous);altered["correction"][0]+=.01
        with self.assertRaisesRegex(ValueError,"prior correction join"):
            reader.describe(self.row,"current_frozen",87,altered)
        altered=copy.deepcopy(self.row)
        altered["resolution_request"]["provider_request"]["history"]["ordered_entries"]=[{}]
        with self.assertRaisesRegex(ValueError,"history availability"):
            reader.describe(altered,"current_frozen",87,self.previous)

    def test_real_state_order_clock_role_and_nonfinite_refusals(self):
        mutations=[
            (lambda r:r.__setitem__("outer_step",86),"order/clock"),
            (lambda r:r["selection"]["role"].__setitem__("implementation","committed"),"role"),
            (lambda r:r["resolution_request"]["provider_request"]["state"].__setitem__("sample_time_s",0.),"state/context"),
            (lambda r:r["resolution"]["ordered_commands"][0].__setitem__("applied_correction_rad_s",float("nan")),"correction")]
        for mutation,message in mutations:
            row=copy.deepcopy(self.row);mutation(row)
            with self.assertRaisesRegex(ValueError,message):
                reader.describe(row,"current_frozen",87,self.previous)
        request=copy.deepcopy(self.row["resolution_request"]["provider_request"])
        request["state"]["ordered_joint_observations"].reverse()
        with self.assertRaisesRegex(ValueError,"joint order"):reader.state_features(request,self.previous)

    def test_shuffled_actual_prediction_not_logical_label(self):
        row=copy.deepcopy(self.row);row["selection"]["role"]=copy.deepcopy(reader.ROLES[3])
        d=row["selection"]["decision"]
        d.update(mode="shuffled",logical_action_index=1,proposed_action_index=2,candidate_index=4)
        d["predictions"]=[dict(action_index=1,case_ids=["logical"]),dict(action_index=2,case_ids=["actual"])]
        frame=reader.describe(row,"current_shuffled",87,self.previous)
        self.assertEqual(frame["prediction"]["case_ids"],["actual"])
        d["proposed_action_index"]=1
        with self.assertRaisesRegex(ValueError,"shuffled action"):reader.describe(row,"current_shuffled",87,self.previous)

    def test_missing_dimensions_and_phase_use_explicit_physical_units(self):
        a=self.frames(1)[0]["features"];b=copy.deepcopy(a)
        a["joint_position_rad"][3]=.5;a["joint_velocity_rad_s"][2]=-2.
        a["vertical_velocity_m_s"][0]=-.2;a["roll_pitch_rate_rad_s"][1]=1.2
        a["previous_final_command_rad_s"][7]=3.5;a["previous_correction_rad_s"][6]=-.08
        a["exact_phase_commands"][0]=359
        self.assertEqual(reader.differences(a,b),dict(joint_position_rad=.5,joint_velocity_rad_s=2.,
            vertical_velocity_m_s=.2,roll_pitch_rate_rad_s=1.2,previous_final_command_rad_s=3.5,
            previous_correction_rad_s=.08,exact_phase_commands=1))
        b["previous_final_command_rad_s"]=None
        self.assertIsNone(reader.differences(a,b)["previous_final_command_rad_s"])

    def test_case_denominators_censoring_and_wrong_associations(self):
        frames=self.frames(4);cases=self.cases(frames[0]["features"])
        result=reader.summarize_cases(frames,cases,11)
        self.assertEqual((result["complete_commands_before_violation"],result["selected_neighbor_pairs"]),(2,2))
        self.assertEqual(result["omitted_state_differences"]["joint_position_rad"]["count"],2)
        self.assertEqual(reader.summarize_cases(frames,cases,10)["selected_neighbor_pairs"],1)
        frames[0]["applied"]=False
        self.assertEqual(reader.summarize_cases(frames,cases,11)["selected_neighbor_pairs"],1)
        for key,value in [("action_index",2),("cue",dict(phase=[1]*4,contact_mask=0))]:
            corrupt=copy.deepcopy(cases);corrupt["case"][key]=value
            with self.assertRaisesRegex(ValueError,"action/phase/contact"):reader.summarize_cases(frames,corrupt,None)
        with self.assertRaisesRegex(ValueError,"unknown selected case"):reader.summarize_cases(frames,{},None)

    def test_force_prefix_excludes_first_violation_and_checks_cap_labels(self):
        frames=self.frames();caps=[[-1.,1.]]*8;violation=dict(internal_step=11,time_s=11/600,failure_codes=["tilt"])
        def samples():
            for i in range(1,7201):
                force=1. if i%2 else 0.
                yield dict(step=i,backend="cpu",cell=0,ctrl=[0.]*8,
                    before_qpos=[0.]*15,before_qvel=[0.]*14,qpos=[0.]*15,qvel=[0.]*14,
                    actuator_force_nm=[force]*8,on_force_cap=[bool(i%2)]*8)
        trial=dict(native_metrics=dict(first_physical_violation=violation))
        with patch.object(reader,"read_jsonl",side_effect=lambda p:samples()),patch.object(
            reader,"physical_violation",side_effect=lambda r,s:violation if r["step"]==11 else None):
            result=reader.trace_summary(self.directory,frames,trial,{},caps)
        self.assertEqual(result["internal_samples_before_violation"],10)
        self.assertEqual(result["force_cap_steps_before_violation"],[5]*8)
        self.assertEqual(result["full_force_cap_steps"],[3600]*8)
        row=next(samples());row["on_force_cap"][0]=False
        with patch.object(reader,"read_jsonl",return_value=iter([row])):
            with self.assertRaisesRegex(ValueError,"cap label"):reader.trace_summary(self.directory,frames,trial,{},caps)

    def test_first_control_divergence_is_not_a_counterfactual_outcome(self):
        a=self.frames();b=copy.deepcopy(a)
        for frame in b[3:]:frame["correction"][0]=.08;frame["final"][0]=.08
        for frame in b[4:]:frame["qpos"][0]=.001
        ta=dict(condition_id="left_075",start_id="train_001",role="current",outcome="positive")
        tb=dict(ta,role="committed",outcome="negative")
        result=reader.pair_summary(a,b,ta,tb)
        self.assertEqual(result["first_different_correction"]["step"],3)
        self.assertEqual(result["first_different_native_position"]["step"],4)
        self.assertTrue(result["same_observation_at_first_correction_difference"])
        with self.assertRaisesRegex(ValueError,"crossed pair"):
            reader.pair_summary(a,b,ta,dict(tb,start_id="train_006"))

    def test_parent_population_and_official_failures_remain_immutable(self):
        for change in [
            lambda p:p["finite_outcomes"]["trials"].pop(),
            lambda p:p["finite_outcomes"]["trials"].reverse(),
            lambda p:p["finite_outcomes"]["trials"][0]["episode_metrics"].__setitem__("quality_m_s",0.),
            lambda p:p["finite_outcomes"].__setitem__("negative",18),
            lambda p:p["finite_outcomes"]["repertoire"].__setitem__("ranked_role_indices",[4])]:
            value=copy.deepcopy(self.parent);change(value)
            with self.assertRaises(ValueError):reader.population(value)

    def test_parent_fit_and_original_trace_corruption_stimuli_hit(self):
        original=reader.sha
        for target,call,message in [
            (reader.PARENT,lambda:reader.analyze(self.evidence),"parent changed"),
            (reader.FIT,lambda:reader.case_features(self.evidence),"fitted source changed"),
            (self.physical/"left_075_train_001_baseline"/"trace.jsonl",lambda:reader.analyze(self.evidence),"original raw bytes changed")]:
            hits=[]
            def corrupt(path):
                if Path(path).resolve(strict=True)==target.resolve(strict=True):
                    hits.append(str(path));return "0"*64
                return original(path)
            guards=ExitStack()
            with guards:
                if target.name=="trace.jsonl":guards.enter_context(patch.object(reader,"case_features",return_value=({},[])))
                guards.enter_context(patch.object(reader,"sha",side_effect=corrupt))
                with self.assertRaisesRegex(ValueError,message):call()
            self.assertTrue(hits)


if __name__=="__main__":
    unittest.main(verbosity=2)
