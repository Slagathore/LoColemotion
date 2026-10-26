"""Exercise contact-priority public handoff and synthetic following observations."""
import argparse
import copy
from contextlib import ExitStack
from itertools import islice
import json
from pathlib import Path
import time
from types import SimpleNamespace
from unittest.mock import patch
import mujoco
import numpy as np
from contact_sequence_public_task_v1 import *
from audit_gpu_batch_execution import same_bits,read_jsonl
from audit_predictive_sequence_v1 import Capture
from contact_force_observer_task import bridge
from hold_horizon_task import controller_contract,frozen_model,declaration as hold_declaration
from hierarchical_force_policy_v8 import make_profile as nominal_profile
from prepare_predictive_model_mujoco import prepare
from prepared_predictive_model import PreparedSelector
from predictive_command_selection_v2 import PredictiveSelector
from predictive_contact_sequence_policy_v1 import make_profile
from predictive_contact_sequence_control_v1 import PredictiveSequenceController,terminal_error,transfer_targets
from predictive_contact_sequence_row_audit_v1 import verify_row
from predictive_contact_sequence_v1 import ClearanceMetric,contact_counts
from gpu_measurement_probe import write_new


def audit(core_paths,capture_folder):
    c=declaration();verify_parents(c)
    diagnosis=read(EVIDENCE/PARENT/"audit-capture/final-60.json")
    capture=Capture(capture_folder,c);reports=[]
    with ExitStack() as native_guards:
        for name in ("MjModel","MjData","mj_step","mj_step1","mj_step2","mj_forward","mj_collision"):
            native_guards.enter_context(patch.object(mujoco,name,side_effect=AssertionError("Contact public no native API")))
        for case in cases():
            weak=case["kind"].startswith("weak")
            folder=EVIDENCE/case["attempt_id"]/"physical"/case["trial_id"]
            compiled=read(folder/"compiled.json");xml=(folder/"model.xml").read_text(encoding="utf-8")
            nominal=nominal_profile(compiled,read(folder/"inputs.json"));prepared=prepare(nominal,xml)
            profile=make_profile(nominal,prepared,DLL_SHA);reference=PredictiveSelector(nominal,xml)
            selector=PreparedSelector(prepared,DLL,DLL_SHA);metric=ClearanceMetric(prepared);cores=[]
            with ExitStack() as xml_guards:
                for name in ("fromstring","parse"):
                    xml_guards.enter_context(patch("xml.etree.ElementTree."+name,side_effect=AssertionError("Contact public no runtime XML")))
                for index,path in enumerate(core_paths):
                    core=bridge.LocomotionCore(path);model=frozen_model(core)
                    host=PredictiveSequenceController(core,compiled,controller_contract(hold_declaration(),model),
                        model,case["trial_id"],profile,DLL)
                    previous=None;checks=[];timings=[];transfers=unchanged=0;searches=[];changed=[];handoff=None
                    data=SimpleNamespace(ctrl=np.zeros(8));name=case["trial_id"]+"-core"+str(index)
                    file=capture_folder/(name+".jsonl")
                    try:
                        with file.open("xb") as stream:
                            originals=islice(read_jsonl(folder/"controller.jsonl"),case["maximum_commands"])
                            for step,old in enumerate(originals):
                                require(old["request"]["state"]["semantic_step"]==step,"Contact public input clock")
                                began=time.perf_counter()
                                row=host.step(copy.deepcopy(old["request"]["state"]),copy.deepcopy(old["stability"]),copy.deepcopy(old["kinematics"]))
                                elapsed=time.perf_counter()-began
                                if step<60:
                                    require(row["native_targets"]==old["native_targets"],"Contact unchanged pre-handoff targets")
                                    unchanged+=1
                                else:
                                    require(terminal_error(row) is None,"Contact required handoff/following route refused")
                                    d=row["force_reference"]["decision"];s=d["selection"]
                                    require(s["evaluated_candidates"]<=521,"Contact bounded public candidate population")
                                    if "contact_search" in s:searches.append(step)
                                    if row["native_targets"]!=old["native_targets"]:changed.append(step)
                                    if step==60:
                                        require("contact_search" in s,"Contact full handoff search required")
                                        if weak:
                                            require(same_bits(d["starting_packet"],diagnosis["starting_packet"])
                                                and same_bits(s["contact_search"]["result"],diagnosis["result"])
                                                and row["native_targets"]!=old["native_targets"],
                                                "Contact exact published changed weak handoff")
                                        best=s["best"];seed=s["seed_selection"]["best"]
                                        handoff=dict(first_target_changed=row["native_targets"]!=old["native_targets"],
                                            initial_metric=s["contact_search"]["result"]["initial_metric"],
                                            final_metric={k:v for k,v in best["contact_metric"].items() if k!="clearance_m"},
                                            initial_contacts=contact_counts(seed["result"],metric),
                                            final_contacts=contact_counts(best["result"],metric))
                                        handoff["initial_metric"]={k:v for k,v in handoff["initial_metric"].items() if k!="clearance_m"}
                                    else:
                                        require(row["resolution_request"]["provider_request"]["provider_memory"]==previous["resolution"]["next_memory"]
                                            and d["starting_packet"]["previous_correction"]==
                                                [x["applied_correction_rad_s"] for x in previous["resolution"]["ordered_commands"]],
                                            "Contact following command uses newly applied history")
                                checks.append(verify_row(core,row,previous,old,profile,selector,reference if index==0 else None))
                                began=time.perf_counter();capture.append(stream,row);capture_s=time.perf_counter()-began
                                timings.append(dict(command=step,host_step_wall_s=elapsed,capture_wall_s=capture_s))
                                require(terminal_error(row) is None,"Contact complete public route")
                                transfer_targets(row,data);transfers+=1
                                require(data.ctrl.tolist()==row["native_targets"],"Contact exact adapter array transfer")
                                previous=row
                                if step>=60:print(json.dumps(dict(trial=case["trial_id"],core=index,command=step,
                                    reason=row["force_reference"]["decision"]["selection"]["reason"])),flush=True)
                        require(len(checks)==62 and unchanged==60 and searches[0]==60 and handoff is not None,
                            "Contact complete public handoff and following population")
                    finally:
                        host.close()
                        write_new(capture_folder/(name+"-timing.json"),dict(case=case,rows=timings,real_time_qualified=False))
                    applied=[x for x in checks if not x["prefix"] and x["applied"]]
                    require(len(applied)==2,"Contact both sequence commands applied")
                    cores.append(dict(core_sha256=sha(path),rows=len(checks),capture_sha256=sha(file),
                        applied_sequence_commands=len(applied),transfers=transfers,checks=checks,
                        contact_search_commands=searches,changed_parent_target_commands=changed,
                        unchanged_prefix_commands=unchanged,handoff=handoff))
            require(cores[0]["capture_sha256"]==cores[1]["capture_sha256"],"Contact two-core byte-identical public rows")
            reports.append(dict(case=case,profile_sha256=bridge.LocomotionCore(core_paths[0]).canonicalize_json(profile)["sha256"],
                cores=cores,core_rows_byte_identical=True))
    require(c==expected_contract(),"Contact public unchanged inputs and source")
    return dict(schema_version="locolemotion_contact_sequence_public_audit_v1",ok=True,ledger_scope=c["ledger_scope"],
        contract_sha256=sha(CONTRACT),parent_receipt_sha256=PARENT_SHA,reports=reports,
        public_hosts=4,public_commands=sum(x["rows"] for r in reports for x in r["cores"]),
        applied_sequence_commands=sum(x["applied_sequence_commands"] for r in reports for x in r["cores"]),
        contact_searches=sum(len(x["contact_search_commands"]) for r in reports for x in r["cores"]),
        unchanged_prefix_commands=sum(x["unchanged_prefix_commands"] for r in reports for x in r["cores"]),
        capture_rows=capture.rows,capture_bytes=capture.bytes,
        worlds_opened=0,solver_steps=0,public_first_command_verified=True,actual_resolved_history_verified=True,
        next_request_protocol_verified=True,native_continuation_verified=False,
        observations_generated_by_selected_actions=False,planning_memory_is_learning=False,
        recovery_benefit_established=False,training_data_authority=False,tier2_qualified=False,
        tier3_benefit_established=False,physical_acceptance_authority=False,release_authority=False,real_time_qualified=False)


if __name__=="__main__":
    p=argparse.ArgumentParser();p.add_argument("--core",type=Path,required=True)
    p.add_argument("--baseline-core",type=Path,required=True);p.add_argument("--output",type=Path,required=True)
    args=p.parse_args();folder=args.output.parent/(args.output.stem+"-capture");folder.mkdir()
    result=audit((args.core,args.baseline_core),folder);write_new(args.output,result)
    print(json.dumps({k:result[k] for k in ("ok","public_commands","contact_searches","capture_bytes")}))
