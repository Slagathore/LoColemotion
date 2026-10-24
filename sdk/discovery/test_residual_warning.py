"""Causal, numerical, chronology and negative controls for development warnings."""
import copy
from dataclasses import replace
import math
import unittest
import numpy as np

from adaptation_provider.warning import residual_v1 as w
import residual_warning_data as data
import residual_warning_fit as fit
import residual_warning_metrics as metrics


def feature(step=0):
    values={name:0. for name in w.features.NAMES}
    values.update({"morphology_"+k:w.features.DESCRIPTOR[k] for k in w.features.MORPHOLOGY_FIELDS})
    values.update(height_m=.44,up_body_y=1.,desired_velocity_body_m_s_x=.2,previous_action_available=float(step>0))
    for joint in w.features.JOINTS:values[joint+"_maximum_command_speed_rad_s"]=3.5
    for leg in w.features.LEGS:values[leg+"_phase_cos"]=1.
    return dict(schema_version=w.features.SCHEMA,names=list(w.features.NAMES),
        values=[values[k] for k in w.features.NAMES],history_entries=int(step>0),
        previous_semantic_step=step-1 if step else None,
        previous_request_sha256="sha256:"+"a"*64 if step else None,
        previous_resolution_sha256="sha256:"+"b"*64 if step else None,
        exact_local_phase_commands=[0]*4,support_distance=.4,confidence_is_calibrated=False)


def model():
    return w.FrozenWarning.load(fit.model_document([0.]*96,.5,"sha256:"+"c"*64))


def episode(trial,first=None,candidate="synthetic",start="train_001"):
    rows=[]
    for step in range(w.HORIZON):
        rows.append(dict(trial_id=trial,step=step,category=data.category(step,first,True),
            x=[0.]*w.DIMENSION,unsupported_reason=None))
    meta=dict(trial_id=trial,candidate_id=candidate,start_id=start,condition_id="nominal",
        first_failure=dict(internal_step=first,time_s=first/600,failure_codes=["height"]) if first else None,
        diagnostic_eligible=first is None)
    return rows,meta


class WarningControls(unittest.TestCase):
    def test_definition_and_recipe_bind_exact_sources(self):
        self.assertEqual(w.definition(),w.expected_definition())
        self.assertEqual(fit.recipe(),fit.expected_recipe())

    def test_feature_current_inputs_and_mechanical_scaling(self):
        x=w.encode(feature(),0)
        self.assertEqual(len(x),95);self.assertEqual(x[w.features.NAMES.index("desired_velocity_body_m_s_x")],1.)
        self.assertEqual(x[-7],0.);self.assertEqual(x[-6],0.)
        later=feature(119);self.assertEqual(w.encode(later,119)[-7],119/1440)

    def test_feature_rejects_future_privileged_and_changed_schema(self):
        for key,value in (("future_failure",True),("motor_effectiveness",.75),("target",1)):
            altered=feature();altered[key]=value
            with self.assertRaises(ValueError):w.encode(altered,0)
        altered=feature();altered["names"]=list(reversed(altered["names"]))
        with self.assertRaises(ValueError):w.encode(altered,0)

    def test_feature_domain_and_history_corruption(self):
        for mutate in (
            lambda f:f["values"].__setitem__(6,float("nan")),
            lambda f:f["values"].__setitem__(6,.1),
            lambda f:f["values"].__setitem__(0,1.2),
            lambda f:f.update(history_entries=True),
            lambda f:f.update(previous_semantic_step=9),
            lambda f:f.update(previous_request_sha256="broken"),
            lambda f:f.update(exact_local_phase_commands=[360]*4)):
            value=feature(1);mutate(value)
            with self.assertRaises(ValueError):w.encode(value,1)

    def test_model_freezes_bytes_and_validates_provenance(self):
        value=fit.model_document([0.]*96,.5,"sha256:"+"c"*64);frozen=w.FrozenWarning.load(value)
        value["weights"][0]=.9
        self.assertEqual(frozen.weights[0],0.);self.assertNotEqual(w.digest(value),frozen.sha256)
        for path,val in ((("training","comparison_trials_used"),1),(("training","reserved_starts_opened"),1),
                         (("training","training_trial_count"),63),(("definition","safe_backup_established"),True)):
            changed=frozen.document();changed[path[0]][path[1]]=val
            with self.assertRaises(ValueError):w.FrozenWarning.load(changed)

    def test_fold_model_never_claims_full_population(self):
        value=fit.model_document([0.]*96,.5,"sha256:"+"c"*64,"train_003")
        m=w.FrozenWarning.load(value)
        self.assertEqual(m.document()["training"]["training_trial_count"],48)
        value["training"]["training_trial_count"]=64
        with self.assertRaises(ValueError):w.FrozenWarning.load(value)

    def test_inclusive_entry_and_strict_hysteresis_exit(self):
        m=model();state=w.empty_memory(m,"episode")
        state,d=w.advance_score(m,state,0,.5);self.assertTrue(d["withdraw_requested"])
        state,d=w.advance_score(m,state,1,m.exit_threshold);self.assertEqual(state.clear_commands,0)
        for step in range(2,31):
            state,d=w.advance_score(m,state,step,.1);self.assertTrue(state.withheld)
        state,d=w.advance_score(m,state,31,.1)
        self.assertFalse(state.withheld);self.assertEqual(d["reason"],"supported_reentry")

    def test_unsupported_resets_clear_run_and_never_returns_low_score(self):
        m=model();state=w.empty_memory(m,"episode")
        state,d=w.advance(m,state,0,None);self.assertTrue(state.withheld);self.assertIsNone(d["score"])
        for step in range(1,20):state,_=w.advance_score(m,state,step,.1)
        state,d=w.advance(m,state,20,{"invalid":True})
        self.assertEqual(state.clear_commands,0);self.assertEqual(d["reason"],"unsupported_observation")

    def test_clock_reset_and_corrupt_memory_fail_closed(self):
        m=model();state=w.empty_memory(m,"episode")
        for bad in (replace(state,reset_epoch=-1),replace(state,episode_id="../bad"),
                    replace(state,last_step=False),replace(state,withheld=True),
                    replace(state,model_sha256="sha256:"+"f"*64)):
            with self.assertRaises(ValueError):w.advance_score(m,bad,0,.1)
        state,_=w.advance_score(m,state,0,.1)
        with self.assertRaises(ValueError):w.advance_score(m,state,0,.1)
        with self.assertRaises(ValueError):w.advance_score(m,state,2,.1)
        fresh=w.empty_memory(m,"episode",1);fresh,_=w.advance_score(m,fresh,0,.1)
        self.assertEqual(fresh.reset_epoch,1)

    def test_labels_respect_internal_step_and_inclusive_lookahead(self):
        self.assertEqual(data.category(0,150,True),"positive")
        self.assertEqual(data.category(0,151,True),"negative")
        self.assertEqual(data.category(30,150,True),"already_failed")
        self.assertEqual(data.category(29,150,True),"positive")
        self.assertEqual(data.category(0,1,True),"positive")

    def test_censoring_never_becomes_a_negative(self):
        self.assertEqual(data.category(1410,None,True),"negative")
        self.assertEqual(data.category(1411,None,True),"right_censored")
        self.assertEqual(data.category(1439,7200,True),"positive")
        self.assertEqual(data.category(1439,None,False),"unsupported")
        self.assertEqual(data.category(1439,1,False),"already_failed")

    def test_dataset_complete_chronology_and_label_rejection(self):
        rows,e=episode("episode",151);data.split_episodes(rows,[e])
        for mutate in (lambda r:r.pop(),lambda r:r[0].update(category="positive"),
                       lambda r:r[0].update(trial_id="crossed"),lambda r:r[0].update(step=1),
                       lambda r:r[0]["x"].__setitem__(0,float("inf"))):
            changed=copy.deepcopy(rows);mutate(changed)
            with self.assertRaises(ValueError):data.split_episodes(changed,[e])

    def test_regression_closed_form_ridge_with_free_intercept(self):
        beta,info=fit.regression([[-1.],[1.]],[0,1],["a","b"])
        self.assertAlmostEqual(beta[0],.5,places=13)
        self.assertAlmostEqual(beta[1],.5/(1+fit.RIDGE),places=13)
        self.assertLessEqual(info["normal_equation_infinity_residual"],1e-10)

    def test_episode_balancing_prevents_duplicate_row_dominance(self):
        a,_=fit.regression([[-1.],[.5],[1.]],[0,0,1],["a","b","c"])
        b,_=fit.regression([[-1.]]*7+[[.5],[1.]],[0]*8+[1],["a"]*7+["b","c"])
        np.testing.assert_allclose(a,b,rtol=0,atol=1e-13)

    def test_numerical_fit_agrees_with_augmented_least_squares(self):
        x=np.array([[-1.,.2],[.5,.7],[.9,-.1],[.1,1.]])
        y=np.array([0,0,1,1]);beta,_=fit.regression(x.tolist(),y.tolist(),["a","b","c","d"])
        design=np.column_stack((np.ones(4),x))
        penalty=np.diag([0.,math.sqrt(fit.RIDGE),math.sqrt(fit.RIDGE)])
        expected=np.linalg.lstsq(np.vstack((.5*design,penalty)),np.r_[.5*y,[0.,0.,0.]],rcond=None)[0]
        np.testing.assert_allclose(beta,expected,rtol=0,atol=1e-12)

    def test_regression_refuses_missing_class_and_nonfinite(self):
        for x,y,ids in (([[0.],[1.]],[0,0],["a","b"]),([[float("nan")],[1.]],[0,1],["a","b"]),
                        ([[0.],[1.]],[0,1],["a"])):
            with self.assertRaises(ValueError):fit.regression(x,y,ids)

    def test_threshold_uses_supported_warning_windows_not_healthy_maxima(self):
        a,ea=episode("a",150);b,eb=episode("b",300);c,ec=episode("c")
        scores=[-.8]*1440+[-.2]*1440+[100.]*1440
        threshold,limits,without=metrics.threshold_limits(a+b+c,[ea,eb,ec],scores)
        self.assertEqual(threshold,-.8);self.assertEqual(len(limits),2);self.assertEqual(without,[])

    def test_no_supported_failure_opportunity_is_retained(self):
        a,ea=episode("a",150);b,eb=episode("b",300)
        for row in a:
            if row["category"]=="positive":
                row.update(x=None,category="unsupported",unsupported_reason="synthetic_unavailable")
        scores=[None if row["x"] is None else 0. for row in a+b]
        _,limits,without=metrics.threshold_limits(a+b,[ea,eb],scores)
        self.assertEqual(without,["a"]);self.assertEqual(len(limits),1)

    def test_shadow_metrics_retain_missed_failures_and_eligible_warnings(self):
        a,ea=episode("a",150);b,eb=episode("b",candidate="iteration_00/d00_plus")
        m=model()
        _,report=metrics.evaluate(a+b,[ea,eb],{"train_001":m})
        self.assertEqual(report["failures_without_target_window_warning"],["a"])
        self.assertEqual(report["eligible_episodes_with_any_warning"],0)
        noisy=w.FrozenWarning.load(fit.model_document([1.]+[0.]*95,.5,"sha256:"+"c"*64))
        _,report=metrics.evaluate(a+b,[ea,eb],{"train_001":noisy})
        self.assertEqual(report["selected_episodes_with_any_warning"],1)
        self.assertEqual(report["known_negative_warning_commands"],1411)
        self.assertFalse(report["counterfactual_physical_outcomes_known"])

    def test_original_complete_training_audits_and_excluded_partitions(self):
        c,candidates,_=data.selection.retained_population()
        decision=data.selection.select_population(candidates,c)
        self.assertEqual(decision["training_trial_count"],64)
        self.assertEqual(sum(t["diagnostic_eligible"] for r in candidates for t in r["trials"]),15)
        self.assertEqual({t["partition"] for r in candidates for t in r["trials"]},{"training"})
        with self.assertRaises(ValueError):data.selection.select_population(candidates[:-1],c)


if __name__=="__main__":unittest.main()
