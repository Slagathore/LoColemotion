"""Verify exposed regressions and one adaptive-scale search without worlds."""
import argparse
import copy
from contextlib import ExitStack
import json
from pathlib import Path
import time
from unittest.mock import patch
import mujoco
from sequence_adaptive_scale_task_v1 import *
from predictive_sequence_adaptive_scale_v1 import search
from sequence_adaptive_scale_checks_v1 import verify_population as verify_search
from audit_predictive_sequence_v1 import Capture,packet
from predictive_sequence_v1 import evaluate
from predictive_sequence_online_v2 import validate_plan
from predictive_command_selection_v2 import PredictiveSelector
from prepared_predictive_model import PreparedSelector
from audit_predictive_numeric_backend import compare
from audit_gpu_batch_execution import same_bits
from gpu_measurement_probe import write_new


from audit_sequence_constraint_repair_v1 import bound_inputs,rows


def audit(capture_folder,timing_path):
    c=declaration();closure=parent();profile=read(TRIAL/"force-profile.json")
    predecessor=read(EVIDENCE/PARENT/"audit.json")["new_search"]
    xml=(TRIAL/"model.xml").read_text(encoding="utf-8");capture=Capture(capture_folder,c);timing=[]
    regressions=[];new_summary=None
    with ExitStack() as guards:
        for name in ("MjModel","MjData","mj_step","mj_step1","mj_step2","mj_forward","mj_collision"):
            guards.enter_context(patch.object(mujoco,name,side_effect=AssertionError("Repair no native access")))
        reference=PredictiveSelector(profile["nominal_profile"],xml)
        for name in ("fromstring","parse"):
            guards.enter_context(patch("xml.etree.ElementTree."+name,side_effect=AssertionError("Repair no runtime XML")))
        selector=PreparedSelector(profile["prepared_model"],DLL,DLL_SHA)
        for previous,row,expected in inputs(c,closure):
            value,plan,selection=bound_inputs(previous,row,profile,expected)
            seed=copy.deepcopy(selection["original"]["best"]["option"]["knots"]);started=time.perf_counter()
            before=copy.deepcopy((value,plan,seed))
            if value["command"]!=86:
                summary=verify_search(selection["refinement"]["evaluations"],selection["refinement"]["result"],
                    value,seed,selector,retained_regression=True)
                artifact=capture.write(f"retained-{value['command']}.json",dict(summary,
                    row_sha256=expected["row_sha256"],controller_sha256=c["input_bindings"]["controller.jsonl"],
                    starting_packet=value,initial_seed=seed))
                regressions.append(dict(summary,artifact=artifact))
                timing.append(dict(command=value["command"],stage="retained_reranking",wall_s=time.perf_counter()-started))
                print(json.dumps(dict(command=value["command"],retained_winners_preserved=True)),flush=True)
            else:
                original=selection["original"]["best"]["result"]
                old=selection["refinement"]["result"]
                original_comparison=compare(evaluate(reference,value,seed,66),original)
                old_summary={k:v for k,v in old["best"]["result"].items() if k!="rows"}
                del selection,row,old,original
                path=capture_folder/"candidates.jsonl";count=0
                with path.open("xb") as stream:
                    def retain(record):
                        nonlocal count
                        capture.append(stream,record);count+=1
                        if count%79==0:print(json.dumps(dict(command=86,completed_candidates=count)),flush=True)
                    result=search(selector,value,seed,retain)
                require(count==316,"Repair complete newly evaluated population")
                verify_search(rows(path,c),result,value,seed,selector)
                best=result["best"];reconstructed=evaluate(reference,value,best["option"]["knots"],66)
                comparison=compare(reconstructed,best["result"])
                artifact=capture.write("final-86.json",dict(starting_packet=value,prior_plan=plan,initial_seed=seed,
                    result=result,original_reference_comparison=original_comparison,
                    reference=reconstructed,reference_comparison=comparison))
                new_summary=dict(command=86,evaluations=count,accepted=result["accepted"],rounds=result["rounds"],
                    best=dict(iteration=best["iteration"],option=best["option"],constraint_violation=best["constraint_violation"],
                        **{k:v for k,v in best["result"].items() if k!="rows"}),
                    previous_refinement_best=old_summary,previous_constraint_repair_best=predecessor["best"],
                    original_reference_comparison=original_comparison,
                    reference_comparison=comparison,candidate_sha256=sha(path),artifact=artifact)
                timing.append(dict(command=86,stage="new_search_and_reconstruction",wall_s=time.perf_counter()-started))
                print(json.dumps(dict(command=86,accepted=result["accepted"],
                    valid_intervals=best["result"]["valid_intervals"])),flush=True)
            require(same_bits(before,(value,plan,seed)),"Repair unchanged causal inputs")
    require([x["command"] for x in regressions]==[81,83,84,85] and new_summary is not None,"Repair full declared case population")
    write_new(timing_path,dict(rows=timing,real_time_qualified=False))
    return dict(schema_version="locolemotion_sequence_adaptive_scale_audit_v1",ok=True,ledger_scope=c["ledger_scope"],
        contract_sha256=sha(CONTRACT),parent_receipt_sha256=PARENT_SHA,regressions=regressions,new_search=new_summary,
        retained_regression_evaluations=1264,new_evaluations=316,
        all_previous_round_winners_preserved=True,all_candidate_guards_and_costs_reconstructed=True,
        independent_scalar_violation_accounting=True,capture_rows=capture.rows,capture_bytes=capture.bytes,
        worlds_opened=0,solver_steps=0,changed_horizon=False,changed_guard=False,
        changed_candidate_budget=False,changed_ranking=False,changed_scale_schedule=True,
        actual_native_transfer_verified=False,trained=False,training_data_authority=False,
        recovery_benefit_established=False,tier2_qualified=False,tier3_benefit_established=False,
        physical_acceptance_authority=False,release_authority=False,real_time_qualified=False)


if __name__=="__main__":
    p=argparse.ArgumentParser();p.add_argument("--core",type=Path,required=True)
    p.add_argument("--baseline-core",type=Path,required=True);p.add_argument("--output",type=Path,required=True)
    args=p.parse_args();capture=args.output.parent/(args.output.stem+"-capture");capture.mkdir()
    result=audit(capture,args.output.parent/(args.output.stem+"-timing.json"))
    write_new(args.output,result)
    print(json.dumps(dict(ok=True,accepted=result["new_search"]["accepted"],new_evaluations=316,capture_bytes=result["capture_bytes"])))
