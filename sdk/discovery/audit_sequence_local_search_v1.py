"""Reconstruct a finite refinement at native command 81 without opening worlds."""
import argparse
import copy
from contextlib import ExitStack
import json
from pathlib import Path
import time
from unittest.mock import patch
import mujoco
import numpy as np
from audit_prepared_predictive_model import ROOT,HERE,DLL,DLL_SHA,read,sha,require
from audit_predictive_sequence_public_v3 import GATES as PARENT_GATES
from audit_residual_training_closure import verify_population
from run_hierarchical_native_v6 import inventory
from audit_gpu_batch_execution import same_bits
from contact_force_observer_task import bridge
from predictive_sequence_policy_v3 import Policy,digest
from predictive_sequence_row_audit_v3 import verify_row
from predictive_sequence_online_v2 import select,validate_plan,HORIZON
from predictive_sequence_v1 import evaluate,rank
from predictive_command_selection_v2 import PredictiveSelector
from audit_predictive_sequence_v1 import Capture,packet,verify_sequence
from audit_predictive_numeric_backend import compare
from predictive_sequence_local_search_v1 import search,options,SCALES,CANDIDATES,SEED,SAMPLES
from gpu_measurement_probe import write_new

EVIDENCE=ROOT.parent/"SporeSpore_Evidence"
PARENT="sdk2-predictive-sequence-native-v3-f478d1e7aa6b477f94654d5c76db4a0e"
PARENT_SHA="fe2802ce0a08c50908e8b0d44e8d928c385d3aaed249af81f6a2d687fa0dc528"
CLOSURE_RESULT=HERE/"predictive_sequence_native_result_v3.json"
RESULT_SHA="873f230f04e991104f039f5974012a561afaeb4e4d789b7e27856d88fd56121f"
TRIAL=EVIDENCE/PARENT/"physical/predictive_hold_left_075_train_001"
INPUT=TRIAL/"controller.jsonl"
CONTRACT=HERE/"sequence_local_search_v1.json"
SOURCES=("predictive_sequence_local_search_v1.py","audit_sequence_local_search_v1.py",
    "test_sequence_local_search_v1.py","run_sequence_local_search_v1.py")
GATES=(("sequence-local-search","test_sequence_local_search_v1",16),*PARENT_GATES)
CONTROLS=sum(n for _,_,n in GATES)


def expected_contract():
    return dict(schema_version="locolemotion_sequence_local_search_contract_v1",
        ledger_scope=dict(subsystem="adaptation",engine_scope="core",
            authority_mode="finite_native_refusal_search_diagnosis",question_class="development"),
        source_bindings={n:sha(HERE/n) for n in SOURCES},
        parent_attempt=PARENT,parent_receipt_sha256=PARENT_SHA,parent_result_sha256=RESULT_SHA,
        input_bindings={n:sha(TRIAL/n) for n in ("controller.jsonl","force-profile.json","model.xml")},
        command=81,horizon=66,initial_seed="best rejected sequence in the consumed native decision",
        parent_search="recompute all 103 original candidates from exact state and actual prior plan",
        successor_search="four full rounds; incumbent, 64 individual control-point perturbations, 14 random perturbations",
        perturbation_scales=list(SCALES),candidates_per_round=CANDIDATES,maximum_evaluations=4*CANDIDATES,
        random_seed=SEED,ranking="unchanged eligibility, longest admissible prefix, then original objective",
        first_command_permission="none; diagnostic outputs are never transferred",
        controls_required=CONTROLS,maximum_control_wall_seconds=600,maximum_reader_wall_seconds=1800,
        minimum_free_storage_bytes=64*2**30,maximum_capture_bytes=4*2**30,
        maximum_capture_row_bytes=512*2**20,maximum_input_tail_bytes=384*2**20,
        reference="original Python independently predicts final best; every candidate guard and objective reconstructed",
        runtime_native_api_forbidden=True,runtime_xml_parsing_forbidden=True,
        future_observations_used=False,future_recorded_actions_used=False,
        changed_horizon=False,changed_guard=False,worlds_opened=0,solver_steps=0,
        actual_native_transfer_verified=False,trained=False,training_data_authority=False,
        recovery_benefit_established=False,tier2_qualified=False,tier3_benefit_established=False,
        physical_acceptance_authority=False,release_authority=False,real_time_qualified=False)


def declaration():
    c=read(CONTRACT);require(c==expected_contract(),"Local exact contract");return c


def inputs():
    with INPUT.open("rb") as stream:
        stream.seek(max(0,INPUT.stat().st_size-384*2**20));tail=stream.read()
    require(tail.endswith(b"\n"),"Local complete retained input")
    parts=tail.rstrip(b"\n").rsplit(b"\n",2)
    require(len(parts)==3,"Local two complete final inputs")
    previous,row=(json.loads(x) for x in parts[-2:])
    require(previous["outer_step"]==80 and row["outer_step"]==81,"Local exact native clocks")
    return previous,row,read(TRIAL/"force-profile.json"),(TRIAL/"model.xml").read_text(encoding="utf-8")


def bound_inputs(core,previous,row,profile,selector):
    d=row["force_reference"]["decision"];selection=d["selection"]
    require(row["outer_step"]==81 and previous["outer_step"]==80 and d["stage"]=="selection"
        and selection["accepted"] is False and selection["reason"]=="warm_refused"
        and selection["evaluated_candidates"]==103 and d["proposal"]["nominal_allocation_available"] is True,
        "Local retained refused population")
    checked=verify_row(core,row,previous,row,profile,selector)
    require(checked["applied"] is False,"Local original refusal never transferred")
    value=packet(row,profile);plan=row["resolution_request"]["provider_request"]["provider_memory"]["opaque_state"]["plan"]
    validate_plan(plan,value)
    require(selection["best"]["result"]["valid_intervals"]==65 and selection["best"]["result"]["planned_intervals"]==66,
        "Local original finite boundary")
    return value,copy.deepcopy(plan),copy.deepcopy(selection["best"]["option"]["knots"])


def independent_options(value,center,iteration):
    # Separate construction verifies the declared candidate coordinates and RNG.
    p=np.array(center,dtype=float);step=SCALES[iteration]
    expected=[dict(index=0,name="incumbent",knots=p.tolist())]
    for coordinate in range(32):
        for sign in (-1,1):
            x=p.copy();x.flat[coordinate]+=sign*step
            expected.append(dict(index=len(expected),name=f"knot_{coordinate//8}_joint_{coordinate%8}_{sign}",
                knots=np.clip(x,-3.5,3.5).tolist()))
    rng=np.random.default_rng(SEED+10000*value["command"]+iteration)
    for i in range(SAMPLES):
        x=p+rng.normal(0.,step,(4,8))
        expected.append(dict(index=len(expected),name=f"sample_{i}",knots=np.clip(x,-3.5,3.5).tolist()))
    return expected


def verify_trace(path,result,value,seed,selector,c):
    center=copy.deepcopy(seed);rounds=[];prior=None;count=0;winner=None
    require(path.stat().st_size<=c["maximum_capture_bytes"],"Local retained stream bound")
    with path.open("rb") as stream:
        for iteration,scale in enumerate(SCALES):
            best=None;eligible=0
            for option in independent_options(value,center,iteration):
                raw=stream.readline(c["maximum_capture_row_bytes"]+1)
                require(raw.endswith(b"\n") and len(raw)<=c["maximum_capture_row_bytes"],"Local complete bounded candidate row")
                record=json.loads(raw)
                require(record["iteration"]==iteration and same_bits(record["option"],option),"Local exact candidate order/domain")
                verify_sequence(record["result"],value,option["knots"],66,selector)
                eligible+=int(record["result"]["eligible"])
                if best is None or rank(record["result"])<rank(best["result"]):best=record
                count+=1
            current=rank(best["result"])
            require(prior is None or current<=prior,"Local retained incumbent regression")
            winner=best;center=copy.deepcopy(best["option"]["knots"]);prior=current
            rounds.append(dict(iteration=iteration,scale=scale,evaluated=CANDIDATES,eligible_candidates=eligible,
                winner_index=best["option"]["index"],rank=list(current)))
        require(not stream.read(1),"Local trailing candidate population")
    require(result["evaluated_candidates"]==count==316 and result["rounds"]==rounds
        and same_bits(result["best"],winner) and result["accepted"]==winner["result"]["eligible"]
        and result["horizon"]==66 and result["finite_search_only"] is True,"Local complete final decision")
    require(all(result[k] is False for k in ("global_infeasibility_established","changed_horizon","changed_guard",
        "trained","actual_native_transfer_verified","recovery_benefit_established","tier2_qualified",
        "tier3_benefit_established","training_data_authority","physical_acceptance_authority","release_authority")),
        "Local forbidden authority")


def audit(core,capture_folder,timing_path):
    c=declaration();parent=EVIDENCE/PARENT;r=read(parent/"receipt.json");a=read(parent/"audit.json")
    require(sha(parent/"receipt.json")==PARENT_SHA and sha(CLOSURE_RESULT)==RESULT_SHA and r["ok"] is True
        and sum(r["safety_controls"].values())==1351 and r["source_runtime_unchanged"] is True
        and sha(parent/"audit.json")==sha(parent/"reconstruction.json")==r["audit_sha256"],
        "Local complete native parent")
    verify_population(r["artifacts"],inventory(parent))
    require(a["constructed_cpu_worlds"]==2 and a["execution_complete"] is False
        and a["controller_rows"]==1522 and a["internal_rows"]==7605,"Local finite parent population")
    previous,row,profile,xml=inputs();capture=Capture(capture_folder,c);timing={}
    with ExitStack() as guards:
        for name in ("MjModel","MjData","mj_step","mj_step1","mj_step2","mj_forward","mj_collision"):
            guards.enter_context(patch.object(mujoco,name,side_effect=AssertionError("Local no native access")))
        reference=PredictiveSelector(profile["nominal_profile"],xml)
        for name in ("fromstring","parse"):
            guards.enter_context(patch("xml.etree.ElementTree."+name,side_effect=AssertionError("Local no runtime XML")))
        policy=Policy(core,profile,DLL)
        value,plan,seed=bound_inputs(core,previous,row,profile,policy.selector)
        started=time.perf_counter();original=select(policy.selector,value,plan)
        require(same_bits(original,row["force_reference"]["decision"]["selection"]),"Local exact consumed search reconstruction")
        timing["parent_search_wall_s"]=time.perf_counter()-started
        original_comparison=compare(evaluate(reference,value,seed,66),original["best"]["result"])
        del original,previous,row
        before=copy.deepcopy((value,plan,seed));path=capture_folder/"candidates.jsonl"
        started=time.perf_counter()
        with path.open("xb") as stream:
            result=search(policy.selector,value,seed,lambda record:capture.append(stream,record))
        timing["search_and_capture_wall_s"]=time.perf_counter()-started
        require(same_bits(before,(value,plan,seed)),"Local unchanged causal state/history/seed")
        verify_trace(path,result,value,seed,policy.selector,c)
        best=result["best"];started=time.perf_counter()
        reconstructed=evaluate(reference,value,best["option"]["knots"],66)
        comparison=compare(reconstructed,best["result"])
        timing["final_reference_wall_s"]=time.perf_counter()-started
        artifact=capture.write("final.json",dict(starting_packet=value,prior_plan=plan,initial_seed=seed,
            result=result,original_comparison=original_comparison,reference=reconstructed,comparison=comparison))
    write_new(timing_path,dict(timing,real_time_qualified=False))
    return dict(schema_version="locolemotion_sequence_local_search_audit_v1",ok=True,ledger_scope=c["ledger_scope"],
        contract_sha256=sha(CONTRACT),parent_receipt_sha256=PARENT_SHA,command=81,horizon=66,
        original_search_exactly_reconstructed=True,original_evaluations=103,original_valid_intervals=65,
        original_reference_comparison=original_comparison,evaluations=result["evaluated_candidates"],rounds=result["rounds"],
        accepted=result["accepted"],best=dict(iteration=best["iteration"],option=best["option"],
            **{k:v for k,v in best["result"].items() if k!="rows"}),reference_comparison=comparison,
        candidate_sha256=sha(path),artifact=artifact,capture_rows=capture.rows,capture_bytes=capture.bytes,
        worlds_opened=0,solver_steps=0,changed_horizon=False,changed_guard=False,
        actual_native_transfer_verified=False,trained=False,training_data_authority=False,
        recovery_benefit_established=False,tier2_qualified=False,tier3_benefit_established=False,
        physical_acceptance_authority=False,release_authority=False,real_time_qualified=False)


if __name__=="__main__":
    p=argparse.ArgumentParser();p.add_argument("--core",type=Path,required=True)
    p.add_argument("--baseline-core",type=Path,required=True);p.add_argument("--output",type=Path,required=True)
    args=p.parse_args();capture=args.output.parent/(args.output.stem+"-capture");capture.mkdir()
    result=audit(bridge.LocomotionCore(args.core),capture,args.output.parent/(args.output.stem+"-timing.json"))
    write_new(args.output,result);print(json.dumps({k:result[k] for k in ("ok","accepted","evaluations","capture_bytes")}))
