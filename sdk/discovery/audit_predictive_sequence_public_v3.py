"""Retained-observation public sequence routes; zero native worlds."""
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
from audit_prepared_predictive_model import ROOT,HERE,DLL,DLL_SHA,read,sha,require
from audit_sequence_seed_diagnostic_v3 import GATES as PARENT_GATES
from audit_gpu_batch_execution import same_bits
from predictive_sequence_task_v1 import verify_parent as verify_native_parent
from audit_gpu_batch_execution import read_jsonl
from audit_residual_training_closure import verify_population
from run_hierarchical_native_v6 import inventory
from audit_predictive_sequence_v1 import Capture
from contact_force_observer_task import bridge
from hold_horizon_task import controller_contract,frozen_model,declaration as hold_declaration
from hierarchical_force_policy_v8 import make_profile as nominal_profile
from prepare_predictive_model_mujoco import prepare
from prepared_predictive_model import PreparedSelector
from predictive_command_selection_v2 import PredictiveSelector
from predictive_sequence_policy_v3 import make_profile
from predictive_sequence_control_v3 import PredictiveSequenceController,terminal_error,transfer_targets
from predictive_sequence_row_audit_v3 import verify_row
from gpu_measurement_probe import write_new

EVIDENCE=ROOT.parent/"SporeSpore_Evidence"
CONTRACT=HERE/"predictive_sequence_public_v3.json"
CLOSURE_RESULT=HERE/"sequence_seed_diagnostic_result_v3.json"
RESULT_SHA="17778898e50f79a0d6c0b6de1ea4fbc83e58bef44ea68331541ce637eb8f026e"
PARENT="sdk2-sequence-seed-diagnostic-v3-a78f0fa2d5df4b90961dbbc68ed35dd6"
PARENT_SHA="95b948992115b44b61c0ac8dc24430f7e1b2422060a6b0fa2ded41f47de86833"
PUBLIC_PARENT="sdk2-predictive-sequence-public-v2-50dad9cf4f87435c8e5347a351945e8d"
PUBLIC_SHA="ccfd32fae54a80e5c9ad609eec7d5d0c8292a78ac315d8ef66b17b6e502394bd"
PUBLIC_RESULT_SHA="09443630898eae6fbf9ad3f4aac61b96d3e72ddd34676a8ae63bae0e2de92475"
SOURCES=("predictive_history_seed_v1.py","predictive_sequence_policy_v3.py","predictive_sequence_control_v3.py",
    "predictive_sequence_row_audit_v3.py","audit_predictive_sequence_public_v3.py",
    "run_predictive_sequence_public_v3.py","test_predictive_sequence_public_v3.py","predictive_sequence_public_result_v2.json")
GATES=(("sequence-public-fallback","test_predictive_sequence_public_v3",24),*PARENT_GATES)
CONTROLS=sum(n for _,_,n in GATES)


def cases():
    return [dict(attempt_id="sdk2-predictive-native-v1-13374a22f25c4d089c34045c96ec64f7",
        trial_id="predictive_hold_left_075_train_001",maximum_commands=74,kind="weak_exposed_sequence_route"),
        dict(attempt_id="sdk2-support-reach-native-1b8cdaeebbb246079d7cf5737cfa4dd8",
        trial_id="reach_hold_nominal_train_001",maximum_commands=62,kind="nominal_exposed_sequence_handoff")]


def expected_contract():
    return dict(schema_version="locolemotion_predictive_sequence_public_contract_v3",
        ledger_scope=dict(subsystem="adaptation",engine_scope="core",
            authority_mode="bounded_retained_state_sequence_public_route",question_class="development"),
        source_bindings={n:sha(HERE/n) for n in SOURCES},parent_attempt=PARENT,parent_receipt_sha256=PARENT_SHA,
        parent_result_sha256=RESULT_SHA,
        public_parent=dict(attempt_id=PUBLIC_PARENT,receipt_sha256=PUBLIC_SHA,result_sha256=PUBLIC_RESULT_SHA),
        nominal_refusal_strategy="project_actual_history_after_bound_nominal_refusal",
        refusal_scope="only explicit nominal allocation refusal; retain original decision, validate reference, clear unavailable force memory",
        fallback_coverage="weak route must apply command68 and inspect its following request69; stop on later terminal refusal",
        prefix_comparison="exact numerical targets against published v2 through67, all nominal case commands",
        first_fallback_comparison="exact starting packet and selected command against published single-state seed diagnosis",
        input_cases=[dict(case,input_bindings={n:sha(EVIDENCE/case["attempt_id"]/"physical"/case["trial_id"]/n)
            for n in ("controller.jsonl","compiled.json","inputs.json","model.xml")}) for case in cases()],
        controls_required=CONTROLS,core_builds=2,public_hosts_per_reader=4,maximum_public_commands_per_reader=272,
        horizon_intervals=66,replanning_interval=12,maximum_evaluations_per_command=103,
        warm_start="shift prior projected targets by one interval, sample four knots, subtract actual current baseline, project and re-predict",
        replan="handoff, every 12 commands, or failed warm forecast; three rounds of 34 candidates",
        minimum_applied_sequence_commands_per_host=1,unchanged_prefix_commands_per_host=60,
        stop="first terminal refusal closes host; refuse transfer; retain incomplete route",
        reference="original Python re-predicts every final best sequence on first core; all candidates checked structurally; second core rows byte identical",
        retention="complete candidate forecasts and public rows; no reduced capture; full host and capture timings separate",
        maximum_reader_wall_seconds=7200,maximum_control_wall_seconds=600,minimum_free_storage_bytes=64*2**30,
        maximum_capture_bytes=16*2**30,maximum_capture_row_bytes=512*2**20,
        future_baseline="current baseline and speed limits constant in each refreshed forecast; no future public-envelope equivalence",
        runtime_xml_parsing_forbidden=True,runtime_native_api_forbidden=True,
        public_resolver_unchanged=True,exact_selected_first_command_required=True,
        actual_resolved_history_required=True,planning_memory_is_learning=False,
        observations_generated_by_selected_actions=False,synthetic=True,worlds_opened=0,solver_steps=0,
        recovery_benefit_established=False,training_data_authority=False,tier2_qualified=False,
        tier3_benefit_established=False,physical_acceptance_authority=False,release_authority=False,real_time_qualified=False)


def declaration():
    c=read(CONTRACT);require(c==expected_contract(),"Sequence public exact contract")
    require(sha(CLOSURE_RESULT)==RESULT_SHA,"Sequence public published sequence closure")
    return c


def audit(core_paths,capture_folder):
    c=declaration();verify_native_parent()
    for attempt,receipt_sha,controls in ((PARENT,PARENT_SHA,234),(PUBLIC_PARENT,PUBLIC_SHA,226)):
        folder=EVIDENCE/attempt;r=read(folder/"receipt.json")
        require(sha(folder/"receipt.json")==receipt_sha and r["ok"] is True and r["controls_passed"]==controls,
            "Sequence public completed bound parent")
        verify_population(r["artifacts"],inventory(folder))
        require(sha(folder/"audit.json")==sha(folder/"reconstruction.json")==r["audit_sha256"],
            "Sequence public parent independent readers")
    require(sha(HERE/"predictive_sequence_public_result_v2.json")==PUBLIC_RESULT_SHA,"Published public parent closure")
    diagnosis=read(EVIDENCE/PARENT/"audit-capture/diagnosis.json")
    capture=Capture(capture_folder,c);reports=[]
    for case in cases():
        folder=EVIDENCE/case["attempt_id"]/"physical"/case["trial_id"]
        originals=list(islice(read_jsonl(folder/"controller.jsonl"),case["maximum_commands"]))
        require(len(originals)==case["maximum_commands"],"Sequence public input population")
        prior_file=EVIDENCE/PUBLIC_PARENT/"audit-capture"/(case["trial_id"]+"-core0.jsonl")
        prior_targets={r["request"]["state"]["semantic_step"]:r["native_targets"] for r in read_jsonl(prior_file)
            if terminal_error(r) is None} if case["kind"].startswith("weak") else {
            r["request"]["state"]["semantic_step"]:r["native_targets"] for r in read_jsonl(prior_file)}
        compiled=read(folder/"compiled.json");xml=(folder/"model.xml").read_text(encoding="utf-8")
        nominal=nominal_profile(compiled,read(folder/"inputs.json"));prepared=prepare(nominal,xml)
        profile=make_profile(nominal,prepared,DLL_SHA);reference=PredictiveSelector(nominal,xml)
        selector=PreparedSelector(prepared,DLL,DLL_SHA);cores=[]
        with ExitStack() as guards:
            for name in ("MjModel","MjData","mj_step","mj_step1","mj_step2","mj_forward","mj_collision"):
                guards.enter_context(patch.object(mujoco,name,side_effect=AssertionError("Sequence public no native API")))
            for name in ("fromstring","parse"):
                guards.enter_context(patch("xml.etree.ElementTree."+name,side_effect=AssertionError("Sequence public no runtime XML")))
            for index,path in enumerate(core_paths):
                core=bridge.LocomotionCore(path);model=frozen_model(core)
                host=PredictiveSequenceController(core,compiled,controller_contract(hold_declaration(),model),
                    model,case["trial_id"],profile,DLL)
                previous=None;checks=[];timings=[];transfers=0;fallback_steps=[];following_steps=[];data=SimpleNamespace(ctrl=np.zeros(8))
                name=case["trial_id"]+"-core"+str(index);file=capture_folder/(name+".jsonl")
                try:
                    with file.open("xb") as stream:
                        for step,old in enumerate(originals):
                            began=time.perf_counter()
                            row=host.step(copy.deepcopy(old["request"]["state"]),copy.deepcopy(old["stability"]),copy.deepcopy(old["kinematics"]))
                            elapsed=time.perf_counter()-began
                            if step in prior_targets:
                                require(row["native_targets"]==prior_targets[step],"Sequence unchanged prior numerical route")
                            if step>=60:
                                decision=row["force_reference"]["decision"]
                                if previous is not None and step>60 and previous["resolution"]["next_memory"]["opaque_state"]["last_nominal_allocation_accepted"] is False:
                                    following_steps.append(step)
                                if decision.get("proposal",{}).get("nominal_allocation_available") is False and terminal_error(row) is None:
                                    fallback_steps.append(step)
                                if step==68 and case["kind"].startswith("weak"):
                                    require(same_bits(decision["starting_packet"],diagnosis["starting_packet"])
                                        and decision["selection"]["selected_target"]==diagnosis["selection"]["selected_target"]
                                        and decision["selection"]["selected_correction"]==diagnosis["selection"]["selected_correction"],
                                        "Sequence exact published seed diagnosis continuation")
                            checks.append(verify_row(core,row,previous,old,profile,selector,reference if index==0 else None))
                            began=time.perf_counter();capture.append(stream,row);capture_s=time.perf_counter()-began
                            timings.append(dict(command=step,host_step_wall_s=elapsed,capture_wall_s=capture_s))
                            if terminal_error(row) is not None:
                                before=data.ctrl.copy()
                                try:transfer_targets(row,data)
                                except ValueError:pass
                                else:raise ValueError("Sequence refused transfer succeeded")
                                require(host.closed and np.array_equal(before,data.ctrl),"Sequence refusal leaves native input unchanged")
                                break
                            transfer_targets(row,data);transfers+=1
                            require(data.ctrl.tolist()==row["native_targets"],"Sequence exact adapter target transfer")
                            previous=row
                finally:
                    host.close()
                    write_new(capture_folder/(name+"-timing.json"),dict(case=case,rows=timings,real_time_qualified=False))
                applied=[x for x in checks if not x["prefix"] and x["applied"]]
                require(len(checks)>=61 and len(applied)>=c["minimum_applied_sequence_commands_per_host"],
                    "Sequence public required first-command coverage")
                require(len(checks)==case["maximum_commands"] or terminal_error(row) is not None,"Sequence bounded route termination")
                if case["kind"].startswith("weak"):
                    require(68 in fallback_steps and 69 in following_steps,"Sequence required fallback and next request coverage")
                cores.append(dict(applied_fallback_commands=fallback_steps,requests_after_fallback=following_steps,
                    unchanged_parent_commands=len(prior_targets),core_sha256=sha(path),rows=len(checks),capture_sha256=sha(file),
                    applied_sequence_commands=len(applied),transfers=transfers,terminal_error=terminal_error(row),
                    terminal_command=len(checks)-1 if terminal_error(row) is not None else None,checks=checks))
        require(cores[0]["capture_sha256"]==cores[1]["capture_sha256"],"Sequence public two-core exact row bytes")
        reports.append(dict(case=case,profile_sha256=bridge.LocomotionCore(core_paths[0]).canonicalize_json(profile)["sha256"],
            cores=cores,core_rows_byte_identical=True))
    return dict(schema_version="locolemotion_predictive_sequence_public_audit_v3",ok=True,ledger_scope=c["ledger_scope"],
        contract_sha256=sha(CONTRACT),parent_receipt_sha256=PARENT_SHA,reports=reports,
        public_hosts=4,public_commands=sum(x["rows"] for r in reports for x in r["cores"]),
        applied_sequence_commands=sum(x["applied_sequence_commands"] for r in reports for x in r["cores"]),
        applied_fallback_commands=sum(len(x["applied_fallback_commands"]) for r in reports for x in r["cores"]),
        requests_after_fallback=sum(len(x["requests_after_fallback"]) for r in reports for x in r["cores"]),
        capture_rows=capture.rows,capture_bytes=capture.bytes,worlds_opened=0,solver_steps=0,
        public_first_command_verified=True,actual_resolved_history_verified=True,
        observations_generated_by_selected_actions=False,planning_memory_is_learning=False,
        recovery_benefit_established=False,training_data_authority=False,tier2_qualified=False,
        tier3_benefit_established=False,physical_acceptance_authority=False,release_authority=False,real_time_qualified=False)


if __name__=="__main__":
    p=argparse.ArgumentParser();p.add_argument("--core",type=Path,required=True)
    p.add_argument("--baseline-core",type=Path,required=True);p.add_argument("--output",type=Path,required=True)
    a=p.parse_args();capture=a.output.parent/(a.output.stem+"-capture");capture.mkdir()
    result=audit((a.core,a.baseline_core),capture);write_new(a.output,result)
    print(json.dumps({k:result[k] for k in ("ok","public_commands","applied_sequence_commands","capture_bytes")}))
