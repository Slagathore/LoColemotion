"""Generate and independently audit four bounded stance-clearance searches."""
import argparse
import copy
from contextlib import ExitStack
import json
from pathlib import Path
import time
from unittest.mock import patch
import mujoco
from contact_sequence_task_v1 import *
from predictive_contact_sequence_v1 import ClearanceMetric,search,contact_counts
from contact_sequence_checks_v1 import verify_population as verify_search
from audit_predictive_sequence_v1 import Capture,packet
from predictive_sequence_online_v2 import validate_plan
from predictive_sequence_v1 import evaluate
from predictive_command_selection_v2 import PredictiveSelector
from prepared_predictive_model import PreparedSelector
from audit_predictive_numeric_backend import compare
from audit_gpu_batch_execution import same_bits
from audit_sequence_constraint_repair_v1 import rows
from gpu_measurement_probe import write_new


def bound_input(previous,row,profile,expected):
    value=packet(row,profile);memory=row["resolution_request"]["provider_request"]["provider_memory"]
    plan=memory["opaque_state"]["plan"];validate_plan(plan,value)
    require(value["previous_correction"]==[x["applied_correction_rad_s"]
        for x in previous["resolution"]["ordered_commands"]],"Contact actual applied correction history")
    if value["command"]==60:
        require(plan is None and memory["sequence"]==0,"Contact fresh public planner memory")
    else:
        require(memory==previous["resolution"]["next_memory"]
            and plan["request_sha256"]==previous["resolution"]["request_sha256"]
            and value["previous_correction"]==[x["applied_correction_rad_s"] for x in previous["resolution"]["ordered_commands"]],
            "Contact actual resolved predecessor")
    selection=row["force_reference"]["decision"]["selection"]
    require(selection["accepted"]==expected["accepted"] and selection["evaluated_candidates"]==expected["evaluations"]
        and selection["best"]["result"]["valid_intervals"]==expected["valid_intervals"],"Contact retained decision identity")
    return value,plan,selection["best"]


def audit(capture_folder,timing_path):
    c=declaration();parent();profile=read(TRIAL/"force-profile.json")
    xml=(TRIAL/"model.xml").read_text(encoding="utf-8");capture=Capture(capture_folder,c);summaries=[];timings=[]
    with ExitStack() as guards:
        for name in ("MjModel","MjData","mj_step","mj_step1","mj_step2","mj_forward","mj_collision"):
            guards.enter_context(patch.object(mujoco,name,side_effect=AssertionError("Contact no native access")))
        reference=PredictiveSelector(profile["nominal_profile"],xml)
        for name in ("fromstring","parse"):
            guards.enter_context(patch("xml.etree.ElementTree."+name,side_effect=AssertionError("Contact no runtime XML")))
        selector=PreparedSelector(profile["prepared_model"],DLL,DLL_SHA);metric=ClearanceMetric(profile["prepared_model"])
        for previous,row,expected in inputs(c):
            value,plan,old=bound_input(previous,row,profile,expected);started=time.perf_counter()
            seed=copy.deepcopy(old["option"]["knots"]);baseline=old["result"];before=copy.deepcopy((value,seed))
            original_comparison=compare(evaluate(reference,value,seed,66),baseline)
            path=capture_folder/f"candidates-{value['command']}.jsonl";count=0
            with path.open("xb") as stream:
                def retain(record):
                    nonlocal count
                    capture.append(stream,record);count+=1
                    if count%34==0:print(json.dumps(dict(command=value["command"],completed_candidates=count)),flush=True)
                result=search(selector,metric,value,seed,retain)
            require(count==102,"Contact complete new population")
            summary=verify_search(rows(path,c),result,value,seed,selector,metric,baseline)
            best=result["best"];reconstructed=evaluate(reference,value,best["option"]["knots"],66)
            comparison=compare(reconstructed,best["result"])
            artifact=capture.write(f"final-{value['command']}.json",dict(starting_packet=value,prior_plan=plan,
                initial_seed=seed,result=result,retained_row_sha256=expected["row_sha256"],
                original_reference_comparison=original_comparison,reference=reconstructed,reference_comparison=comparison))
            require(same_bits(before,(value,seed)),"Contact unchanged causal inputs")
            summaries.append(dict(summary,initial_contacts=contact_counts(baseline,metric),final_contacts=contact_counts(best["result"],metric),
                selected_target_changed=not same_bits(best["result"]["rows"][0]["target"],baseline["rows"][0]["target"]),
                best=dict(iteration=best["iteration"],option=best["option"],
                    result={k:v for k,v in best["result"].items() if k!="rows"},
                    contact_metric={k:v for k,v in best["contact_metric"].items() if k!="clearance_m"}),
                original_reference_comparison=original_comparison,reference_comparison=comparison,
                candidate_sha256=sha(path),artifact=artifact))
            timings.append(dict(command=value["command"],wall_s=time.perf_counter()-started))
            print(json.dumps(dict(command=value["command"],accepted=result["accepted"],
                initial_clearance_m2=summary["initial_clearance_m2"],final_clearance_m2=summary["final_clearance_m2"])),flush=True)
    require([x["command"] for x in summaries]==[60,70,80,86] and c==expected_contract(),"Contact full population and unchanged inputs")
    write_new(timing_path,dict(cases=timings,real_time_qualified=False))
    return dict(schema_version="locolemotion_contact_sequence_audit_v1",ok=True,ledger_scope=c["ledger_scope"],
        contract_sha256=sha(CONTRACT),parent_receipt_sha256=PARENT_SHA,cases=summaries,new_evaluations=408,
        independent_scalar_geometry_accounting=True,all_candidate_guards_costs_and_proposals_verified=True,
        all_retained_seed_forecasts_reproduced=True,capture_rows=capture.rows,capture_bytes=capture.bytes,
        changed_ranking=True,earlier_accepted_decisions_may_change=True,guards_changed=False,actuator_caps_changed=False,
        worlds_opened=0,solver_steps=0,actual_native_transfer_verified=False,trained=False,
        recovery_benefit_established=False,tier2_qualified=False,tier3_benefit_established=False,
        training_data_authority=False,physical_acceptance_authority=False,release_authority=False,
        real_time_qualified=False,global_infeasibility_established=False)


if __name__=="__main__":
    p=argparse.ArgumentParser();p.add_argument("--core",type=Path,required=True)
    p.add_argument("--baseline-core",type=Path,required=True);p.add_argument("--output",type=Path,required=True)
    args=p.parse_args();folder=args.output.parent/(args.output.stem+"-capture");folder.mkdir()
    result=audit(folder,args.output.parent/(args.output.stem+"-timing.json"));write_new(args.output,result)
    print(json.dumps(dict(ok=True,cases=len(result["cases"]),new_evaluations=408,capture_bytes=result["capture_bytes"])))
