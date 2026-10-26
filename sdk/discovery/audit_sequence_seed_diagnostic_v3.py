"""Test the retained nominal refusal with a bounded actual-history seed."""
import argparse
import copy
from contextlib import ExitStack
import json
from pathlib import Path
import time
from unittest.mock import patch
import mujoco
from audit_prepared_predictive_model import ROOT,HERE,DLL,DLL_SHA,read,sha,require
from audit_predictive_sequence_public_v2 import GATES as PARENT_GATES
from audit_residual_training_closure import verify_population
from run_hierarchical_native_v6 import inventory
from audit_gpu_batch_execution import same_bits
from contact_force_observer_task import bridge
from predictive_sequence_policy_v2 import Policy,make_profile,digest
from hierarchical_force_policy_v8 import make_profile as nominal_profile,HierarchyRefusal
from prepare_predictive_model_mujoco import prepare
from prepared_predictive_model import canonical_packet
from predictive_command_selection_v2 import PredictiveSelector
from predictive_sequence_online_v2 import select,validate_plan
from predictive_sequence_selection_audit_v2 import verify_selection
from actuation_recovery_mechanics import command_envelope,resolve_correction
from audit_predictive_sequence_v1 import Capture
from gpu_measurement_probe import write_new

EVIDENCE=ROOT.parent/"SporeSpore_Evidence"
CONTRACT=HERE/"sequence_seed_diagnostic_v3.json"
CLOSURE_RESULT=HERE/"predictive_sequence_public_result_v2.json"
PARENT="sdk2-predictive-sequence-public-v2-50dad9cf4f87435c8e5347a351945e8d"
TRIAL="predictive_hold_left_075_train_001"
INPUT=EVIDENCE/PARENT/"audit-capture"/(TRIAL+"-core0.jsonl")
ORIGINAL=EVIDENCE/"sdk2-predictive-native-v1-13374a22f25c4d089c34045c96ec64f7"/"physical"/TRIAL
SOURCES=("audit_sequence_seed_diagnostic_v3.py","test_sequence_seed_diagnostic_v3.py","run_sequence_seed_diagnostic_v3.py","sequence_seed_diagnostic_result_v1.json","sequence_seed_diagnostic_result_v2.json")
GATES=(("sequence-seed-diagnostic","test_sequence_seed_diagnostic_v3",8),*PARENT_GATES)
CONTROLS=sum(n for _,_,n in GATES)


def expected_contract():
    return dict(schema_version="locolemotion_sequence_seed_diagnostic_contract_v3",
        ledger_scope=dict(subsystem="adaptation",engine_scope="core",
            authority_mode="finite_nominal_refusal_seed_diagnosis",question_class="development"),
        source_bindings={n:sha(HERE/n) for n in SOURCES},
        parent_attempt=PARENT,parent_receipt_sha256=sha(EVIDENCE/PARENT/"receipt.json"),
        parent_result_sha256=sha(CLOSURE_RESULT),input_sha256=sha(INPUT),command=68,horizon=66,
        failed_predecessor=dict(attempt_id='sdk2-sequence-seed-diagnostic-v2-633b656224d44115a44f392b42d5e99e',receipt_sha256='38b3fe376a5f77724db9c786c87c17a8f2115103ae0f8a95e2cd022de23e199e',result_sha256='f5806392d0393cc1475e7ed1a1bed72da6856ad27fa486530ae9319b2324f51d'),
        prior_history="actual public resolutions retained by the verified zero-world parent; observations were prerecorded",
        proposed_seed="previous applied correction projected through the current public baseline and unchanged envelope",
        original_nominal_refusal="recomputed from the exact retained internal request and compared bytewise",
        search="unchanged v2 online sequence search, including warm-plan validation and bounded replanning",
        reference="original Python predictor independently reconstructs final best sequence",
        controls_required=CONTROLS,maximum_control_wall_seconds=600,maximum_reader_wall_seconds=900,
        minimum_free_storage_bytes=64*2**30,maximum_capture_bytes=4*2**30,maximum_capture_row_bytes=512*2**20,
        maximum_input_tail_bytes=16*2**20,maximum_evaluations=103,
        current_public_provider_applies_this_seed=False,actual_native_transfer_verified=False,
        worlds_opened=0,solver_steps=0,trained=False,training_data_authority=False,
        recovery_benefit_established=False,tier2_qualified=False,tier3_benefit_established=False,
        physical_acceptance_authority=False,release_authority=False,real_time_qualified=False)


def declaration():
    c=read(CONTRACT);require(c==expected_contract(),"Seed diagnosis exact contract");return c


def inputs():
    # The final complete row fits in the prospectively bounded tail. The full
    # file digest and complete parent inventory are verified separately.
    with INPUT.open("rb") as stream:
        stream.seek(max(0,INPUT.stat().st_size-16*2**20));tail=stream.read()
    require(tail.endswith(b"\n"),"Seed complete input row")
    row=json.loads(tail.rstrip(b"\r\n").rsplit(b"\n",1)[-1])
    require(row["request"]["state"]["semantic_step"]==68,"Seed exact exposed command")
    compiled=read(ORIGINAL/"compiled.json");xml=(ORIGINAL/"model.xml").read_text(encoding="utf-8")
    n=nominal_profile(compiled,read(ORIGINAL/"inputs.json"));profile=make_profile(n,prepare(n,xml),DLL_SHA)
    return row,profile,xml


def seed_packet(policy,row):
    request=row["resolution_request"]["provider_request"];decision=row["force_reference"]["decision"]
    require(decision["stage"]=="nominal_refusal" and decision["selection"] is None
        and row["resolution_request"]["provider_response"] is None and not row["resolution"]["adaptation_applied"],
        "Seed exact retained nominal refusal")
    require(decision["profile_sha256"]==policy.sha and decision["request_sha256"]==digest(policy.core,request)
        and decision["prepared_model_sha256"]==policy.prepared_sha
        and same_bits(policy.core.resolve_adaptation_v1(row["resolution_request"]),row["resolution"]),
        "Seed bound public request and refused resolution")
    internal=policy.nominal_request(request);failure=decision["nominal"]
    require(failure["step"]==68 and failure["request_sha256"]==digest(policy.core,internal)
        and failure["profile_sha256"]==policy.nominal.sha and failure["allocation"]["accepted"] is False
        and failure["physical_acceptance_authority"] is False,"Seed original nominal identity")
    base=request["deterministic_baseline"]["ordered_commands"];limits=request["safety_envelope"]["ordered_actuator_limits"]
    require(not request["deterministic_baseline"]["safe_no_actuation"]
        and all(x["maximum_absolute_correction_rad_s"]==3.5 and x["maximum_slew_per_step_rad_s"]==.08 for x in limits),
        "Seed unchanged current envelope")
    previous=[x["previous_applied_correction_rad_s"] for x in limits]
    require(previous==[x["canonical_velocity_delta_rad_s"] for x in request["history"]["ordered_entries"][0]["ordered_applied_corrections"]],
        "Seed actual preceding corrections")
    baseline=[x["combined_canonical_target_velocity_rad_s"] for x in base];speeds=[x["maximum_target_speed_rad_s"] for x in base]
    correction,target=resolve_correction(command_envelope(baseline,speeds,previous,[3.5]*8,[.08]*8),previous)
    value=canonical_packet(request["state"],dict(command=68,baseline=baseline,speeds=speeds,
        previous_correction=previous,nominal_correction=correction.tolist(),target_com=failure["target_com"],
        reference_joints=failure["support_reference"]["reference_joint_positions_rad"]),policy.selector.model.tree.joint_ids)
    plan=copy.deepcopy(request["provider_memory"]["opaque_state"]["plan"]);validate_plan(plan,value)
    require(plan["request_sha256"]==request["provider_memory"]["opaque_state"]["previous_binding"],
        "Seed actual plan binding")
    return value,plan,internal,dict(correction=correction.tolist(),target=target.tolist(),
        force_allocation_certificate=False,public_transfer_authority=False)


def audit(core,capture_folder,timing_path):
    c=declaration();prior=c["failed_predecessor"];failed=EVIDENCE/prior["attempt_id"];f=read(failed/"receipt.json")
    require(sha(failed/"receipt.json")==prior["receipt_sha256"] and f["ok"] is False and f["controls_passed"]==226,
        "Seed retained failed control predecessor")
    verify_population(f["artifacts"],inventory(failed))
    require(sha(HERE/"sequence_seed_diagnostic_result_v2.json")==prior["result_sha256"],"Seed failed predecessor closure")
    folder=EVIDENCE/PARENT;r=read(folder/"receipt.json");a=read(folder/"audit.json")
    require(r["ok"] is True and r["controls_passed"]==226 and r["source_runtime_unchanged"] is True
        and sha(folder/"audit.json")==sha(folder/"reconstruction.json")==r["audit_sha256"],
        "Seed complete parent readers")
    verify_population(r["artifacts"],inventory(folder))
    require(a["public_commands"]==262 and a["applied_sequence_commands"]==20 and a["worlds_opened"]==0,
        "Seed exact finite public population")
    row,profile,xml=inputs();reference=PredictiveSelector(profile["nominal_profile"],xml);capture=Capture(capture_folder,c)
    with ExitStack() as guards:
        for name in ("MjModel","MjData","mj_step","mj_step1","mj_step2","mj_forward","mj_collision"):
            guards.enter_context(patch.object(mujoco,name,side_effect=AssertionError("Seed no native access")))
        for name in ("fromstring","parse"):
            guards.enter_context(patch("xml.etree.ElementTree."+name,side_effect=AssertionError("Seed no runtime XML")))
        policy=Policy(core,profile,DLL);value,plan,internal,proposal=seed_packet(policy,row)
        started=time.perf_counter()
        try:policy.nominal.respond(internal)
        except HierarchyRefusal as exc:
            require(same_bits(exc.decision,row["force_reference"]["decision"]["nominal"]),"Seed exact reconstructed nominal refusal")
        else:raise ValueError("Seed expected original refusal")
        refusal_s=time.perf_counter()-started
        before=copy.deepcopy((value,plan));started=time.perf_counter()
        selection=select(policy.selector,value,plan);search_s=time.perf_counter()-started
        require(same_bits(before,(value,plan)),"Seed immutable causal inputs")
        comparison=verify_selection(selection,value,plan,policy.selector,reference)
        artifact=capture.write("diagnosis.json",dict(starting_packet=value,prior_plan=plan,proposal=proposal,
            original_nominal_refusal=row["force_reference"]["decision"]["nominal"],selection=selection,comparison=comparison))
    write_new(timing_path,dict(original_refusal_wall_s=refusal_s,sequence_search_wall_s=search_s,real_time_qualified=False))
    best=selection["best"]["result"]
    return dict(schema_version="locolemotion_sequence_seed_diagnostic_audit_v3",ok=True,ledger_scope=c["ledger_scope"],
        contract_sha256=sha(CONTRACT),parent_receipt_sha256=c["parent_receipt_sha256"],command=68,
        original_nominal_refusal_reconstructed=True,search_reason=selection["reason"],
        evaluations=selection["evaluated_candidates"],accepted=selection["accepted"],
        planned_intervals=best["planned_intervals"],valid_intervals=best["valid_intervals"],
        rejection_reasons=best["rejection_reasons"],mean_objective=best["mean_objective"],
        selected_target=selection["selected_target"],selected_correction=selection["selected_correction"],
        reference_comparison=comparison,capture=artifact,capture_bytes=capture.bytes,
        current_public_provider_applies_this_seed=False,actual_native_transfer_verified=False,
        worlds_opened=0,solver_steps=0,trained=False,training_data_authority=False,recovery_benefit_established=False,
        tier2_qualified=False,tier3_benefit_established=False,physical_acceptance_authority=False,release_authority=False)


if __name__=="__main__":
    p=argparse.ArgumentParser();p.add_argument("--core",type=Path,required=True)
    p.add_argument("--baseline-core",type=Path,required=True);p.add_argument("--output",type=Path,required=True)
    args=p.parse_args();capture=args.output.parent/(args.output.stem+"-capture");capture.mkdir()
    result=audit(bridge.LocomotionCore(args.core),capture,args.output.parent/(args.output.stem+"-timing.json"))
    write_new(args.output,result);print(json.dumps({k:result[k] for k in ("ok","accepted","evaluations","valid_intervals")}))
