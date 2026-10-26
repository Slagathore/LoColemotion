"""Retain every bounded candidate and independent reconstruction."""
import argparse
from contextlib import ExitStack
import json
from pathlib import Path
from unittest.mock import patch
import mujoco
import numpy as np
import predictive_command_selection as component
from audit_held_contact_rollout import ROOT,HERE,ATTEMPT,RECEIPT_SHA,read,sha,require
from audit_gpu_batch_execution import read_jsonl
from audit_residual_training_closure import verify_population
from run_hierarchical_native_v6 import inventory
from gpu_measurement_probe import write_new

CONTRACT=HERE/"predictive_command_selection_v1.json"
SOURCES=("predictive_command_selection.py","audit_predictive_command_selection.py",
    "test_predictive_command_selection.py","run_predictive_command_selection.py")
CONTROLS=66
GATES=(("contact","test_causal_contact_predictor",22),("rollout","test_held_contact_rollout",22),
    ("selection","test_predictive_command_selection",22))
CLOSURE="sdk2-held-contact-rollout-v1-2e3ce47c639745cbbbb747f27b9b3d57"
CLOSURE_SHA="88f235d28a7c1066e7b74bd242e12a77dfed2af806144a67f378505fa644696a"
CLOSURE_RESULT=HERE/"held_contact_rollout_result_v1.json"
RESULT_SHA="b35d62cd047c2bf1cbeb1546f43c8902a05790fa1803df9921a0bb1407346742"


def expected_contract():
    return dict(schema_version="locolemotion_predictive_command_selection_contract_v1",
        ledger_scope=dict(subsystem="adaptation",engine_scope="mujoco_cpu",
            authority_mode="configured_causal_command_selection_component",question_class="development"),
        original_attempt=ATTEMPT,original_receipt_sha256=RECEIPT_SHA,
        closure_attempt=CLOSURE,closure_receipt_sha256=CLOSURE_SHA,closure_result_sha256=RESULT_SHA,
        controls_required=CONTROLS,command_interval_inclusive=[60,118],commands=59,
        candidates_per_command=34,candidate_evaluations=2006,maximum_predicted_steps=10030,
        candidate_recipe="nominal, midpoint, 16 coordinate endpoints, 16 clipped Gaussian proposals",
        random_seed=component.SEED,per_command_seed="seed + command",gaussian_sigma_rad_s=.08,
        maximum_absolute_correction_rad_s=3.5,maximum_slew_per_command_rad_s=.08,
        maximum_target_speed_rad_s=3.5,guard_parameters=component.guard_parameters(),
        guard_check_tolerance=2e-6,selection=component.SELECTION,objective_parameters=component.task_parameters(),
        objective="mean over five post states of gain-weighted quadratic COM/orientation/joint position plus velocity and motor effort",
        ranking="minimum objective among all guard-eligible candidates; original index breaks ties",
        no_eligible_candidate="refuse with no selected target; retain every rejection",
        timing="each reader records separate unfiltered per-candidate wall times; timing never affects selection",
        causal_fields=sorted(component.FIELDS),intermediate_native_observations_used=False,
        measured_forces_used=False,parameters_fitted=False,worlds_opened=0,native_physics_steps=0,
        production_controller_changed=False,trained=False,tier2_qualified=False,tier3_benefit_established=False,
        physical_acceptance_authority=False,release_authority=False,
        source_bindings={name:sha(HERE/name) for name in SOURCES},
        research_sources=["https://arxiv.org/html/2212.00541v2#S3.SS4",
            "https://arxiv.org/html/2212.00541v2#A2"])


def declaration():
    c=read(CONTRACT);require(c==expected_contract(),"Selection exact prospective contract");return c


def summarize(results):
    rows=[r for result in results for r in result["candidates"]]
    selected=[r["candidates"][r["selected_index"]] for r in results if r["accepted"]]
    reasons={}
    for row in rows:
        for reason in row["rejection_reasons"]:reasons[reason]=reasons.get(reason,0)+1
    changed=[r for r in results if r["accepted"] and r["selected_index"]!=0]
    improvements=[]
    for r in results:
        if r["accepted"] and r["candidates"][0]["eligible"]:
            chosen=r["candidates"][r["selected_index"]]
            delta=r["candidates"][0]["objective"]["total"]-chosen["objective"]["total"]
            require(delta>=0,"Selection worsened eligible nominal objective");improvements.append(delta)
    return dict(commands=len(results),candidate_evaluations=len(rows),
        converged_candidates=sum(r["forecast"]["accepted"] for r in rows),
        eligible_candidates=sum(r["eligible"] for r in rows),
        selected_commands=len(selected),refused_commands=[r["command"] for r in results if not r["accepted"]],
        changed_nominal_commands=[r["command"] for r in changed],
        eligible_nominal_commands=sum(r["candidates"][0]["eligible"] for r in results),
        recovered_eligible_command_choices=[r["command"] for r in results if r["accepted"] and not r["candidates"][0]["eligible"]],
        rejections_by_reason=reasons,compared_eligible_nominals=len(improvements),
        maximum_objective_reduction=max(improvements) if improvements else None,
        mean_objective_reduction=float(np.mean(improvements)) if improvements else None,
        completed_predicted_steps=sum(r["forecast"]["completed_steps"] for r in rows))


def audit(evidence,timing):
    c=declaration();original=evidence/ATTEMPT;closure=evidence/CLOSURE
    require(sha(original/"receipt.json")==RECEIPT_SHA and sha(closure/"receipt.json")==CLOSURE_SHA
        and sha(CLOSURE_RESULT)==RESULT_SHA,"Selection parent identities")
    for folder in (original,closure):verify_population(read(folder/"receipt.json")["artifacts"],inventory(folder))
    prior=read(closure/"receipt.json")
    require(prior["ok"] and prior["controls_passed"]==44
        and sha(closure/"audit.json")==sha(closure/"reconstruction.json")==prior["audit_sha256"],"Selection full prior closure")
    folder=original/"physical/hierarchy_hold_left_075_train_001"
    controls=list(read_jsonl(folder/"controller.jsonl"));require(len(controls)==120,"Selection complete parent controls")
    results=[]
    with ExitStack() as guards:
        for name in ("MjModel","MjData","mj_step","mj_step1","mj_step2","mj_forward","mj_collision","mj_integratePos"):
            guards.enter_context(patch.object(mujoco,name,side_effect=AssertionError("Selection calls no native world")))
        model=component.PredictiveSelector(read(folder/"force-profile.json"),(folder/"model.xml").read_text(encoding="utf-8"))
        for command in range(60,119):
            value=component.packet(controls[command]);result=model.select(value,timing)
            results.append(dict(result,starting_packet=value))
    summary=summarize(results)
    require(summary["candidate_evaluations"]==2006,"Selection complete candidate denominator")
    return dict(schema_version="locolemotion_predictive_command_selection_audit_v1",ok=True,
        ledger_scope=c["ledger_scope"],contract_sha256=sha(CONTRACT),
        original_receipt_sha256=RECEIPT_SHA,closure_receipt_sha256=CLOSURE_SHA,
        inputs={name:sha(folder/name) for name in ("controller.jsonl","force-profile.json","model.xml")},
        summary=summary,results=results,worlds_opened=0,native_physics_steps=0,
        alternative_commands_are_predictions_not_observations=True,production_controller_changed=False,
        recovery_benefit_established=False,trained=False,tier2_qualified=False,
        tier3_benefit_established=False,physical_acceptance_authority=False,release_authority=False)


if __name__=="__main__":
    p=argparse.ArgumentParser(description=__doc__);p.add_argument("--core",type=Path,required=True)
    p.add_argument("--baseline-core",type=Path,required=True);p.add_argument("--output",type=Path,required=True)
    args=p.parse_args();timing=[];result=audit(ROOT.parent/"SporeSpore_Evidence",timing)
    write_new(args.output,result)
    values=[r["evaluation_s"] for r in timing]
    write_new(args.output.with_name(args.output.stem+"-timing.json"),dict(
        schema_version="locolemotion_predictive_command_selection_timing_v1",ledger_scope=result["ledger_scope"],
        measured_only=True,real_time_qualified=False,control_period_s=5/600.,samples=len(values),
        total_evaluation_s=sum(values),median_evaluation_s=float(np.median(values)),maximum_evaluation_s=max(values),rows=timing))
    print(json.dumps(dict(ok=True,output=str(args.output),summary=result["summary"])))
