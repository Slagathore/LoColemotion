"""Public refinement on retained states, with separately labeled protocol continuation."""
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
from audit_sequence_local_search_v1 import GATES as PARENT_GATES
from audit_gpu_batch_execution import same_bits,read_jsonl
from audit_residual_training_closure import verify_population
from run_hierarchical_native_v6 import inventory
from audit_predictive_sequence_v1 import Capture
from contact_force_observer_task import bridge
from hold_horizon_task import controller_contract,frozen_model,declaration as hold_declaration
from hierarchical_force_policy_v8 import make_profile as nominal_profile
from prepare_predictive_model_mujoco import prepare
from prepared_predictive_model import PreparedSelector
from predictive_command_selection_v2 import PredictiveSelector
from predictive_sequence_policy_v4 import make_profile
from predictive_sequence_control_v4 import PredictiveSequenceController,terminal_error,transfer_targets
from predictive_sequence_row_audit_v4 import verify_row
from predictive_sequence_following_request_v1 import following_request
from gpu_measurement_probe import write_new

EVIDENCE=ROOT.parent/"SporeSpore_Evidence"
CONTRACT=HERE/"predictive_sequence_public_v4.json"
CLOSURE_RESULT=HERE/"sequence_local_search_result_v1.json"
RESULT_SHA="148e5a6d302b0ce4e03d2b4e74c392d153b2bafd88b330e630694c2f79249862"
PARENT="sdk2-sequence-local-search-v1-9d1d751fdd26424199dd2c6803ae1ff4"
PARENT_SHA="02d569fb9be25f3d63eb80943192e90d1c1269d1a8126d501b46046d3f9b25b6"
NATIVE="sdk2-predictive-sequence-native-v3-f478d1e7aa6b477f94654d5c76db4a0e"
NATIVE_SHA="fe2802ce0a08c50908e8b0d44e8d928c385d3aaed249af81f6a2d687fa0dc528"
PUBLIC_PARENT="sdk2-predictive-sequence-public-v3-4db025ca0ada47e5a7e801c7cd9fdb29"
PUBLIC_SHA="3e665cd66499bd800603c93850567bebc25d08b9d7902c587b2a4b12c89ecc6e"
FOLLOWING=EVIDENCE/"sdk2-predictive-native-v1-13374a22f25c4d089c34045c96ec64f7"/"physical/predictive_hold_left_075_train_001/controller.jsonl"
SOURCES=("predictive_sequence_refinement_v1.py","predictive_sequence_refinement_audit_v1.py",
    "predictive_sequence_following_request_v1.py","predictive_sequence_policy_v4.py",
    "predictive_sequence_control_v4.py","predictive_sequence_row_audit_v4.py",
    "audit_predictive_sequence_public_v4.py","run_predictive_sequence_public_v4.py","test_predictive_sequence_public_v4.py")
GATES=(("sequence-public-refinement","test_predictive_sequence_public_v4",36),*PARENT_GATES)
CONTROLS=sum(n for _,_,n in GATES)


def cases():
    return [dict(attempt_id=NATIVE,trial_id="predictive_hold_left_075_train_001",
        maximum_commands=82,kind="native_refusal_integration"),
        dict(attempt_id="sdk2-support-reach-native-1b8cdaeebbb246079d7cf5737cfa4dd8",
        trial_id="reach_hold_nominal_train_001",maximum_commands=62,kind="nominal_exposed_sequence_handoff")]


def expected_contract():
    return dict(schema_version="locolemotion_predictive_sequence_public_contract_v4",
        ledger_scope=dict(subsystem="adaptation",engine_scope="core",
            authority_mode="bounded_retained_state_refinement_public_route",question_class="development"),
        source_bindings={n:sha(HERE/n) for n in SOURCES},
        parent_attempt=PARENT,parent_receipt_sha256=PARENT_SHA,parent_result_sha256=RESULT_SHA,
        native_parent=dict(attempt_id=NATIVE,receipt_sha256=NATIVE_SHA),
        public_parent=dict(attempt_id=PUBLIC_PARENT,receipt_sha256=PUBLIC_SHA),
        refinement_trigger="only an explicitly rejected original sequence; accepted searches remain numerically unchanged",
        unchanged_prior_commands=dict(weak_native=81,nominal_public=62),
        input_cases=[dict(case,input_bindings={n:sha(EVIDENCE/case["attempt_id"]/"physical"/case["trial_id"]/n)
            for n in ("controller.jsonl","compiled.json","inputs.json","model.xml")}) for case in cases()],
        following_request_fixture=dict(source_path=str(FOLLOWING.relative_to(EVIDENCE)).replace("\\","/"),
            source_sha256=sha(FOLLOWING),command=82,kind="synthetic protocol join with a separately recorded observation",
            native_continuity_claim=False,next_action_prediction=False),
        controls_required=CONTROLS,core_builds=2,public_hosts_per_reader=4,public_commands_per_reader=288,
        required_refinement_command=81,required_refinements_per_reader=2,synthetic_following_requests_per_reader=2,
        horizon_intervals=66,replanning_interval=12,maximum_evaluations_per_command=419,
        reference="original Python reconstructs original and refined best sequences on first core; all candidates checked",
        retention="complete public rows and forecasts; streamed inputs; separate protocol-continuation artifacts and timings",
        maximum_reader_wall_seconds=10800,maximum_control_wall_seconds=900,minimum_free_storage_bytes=64*2**30,
        maximum_capture_bytes=16*2**30,maximum_capture_row_bytes=1024*2**20,
        runtime_xml_parsing_forbidden=True,runtime_native_api_forbidden=True,
        public_resolver_unchanged=True,exact_selected_first_command_required=True,
        actual_resolved_history_required=True,planning_memory_is_learning=False,
        observations_generated_by_selected_actions=False,synthetic=True,worlds_opened=0,solver_steps=0,
        recovery_benefit_established=False,training_data_authority=False,tier2_qualified=False,
        tier3_benefit_established=False,physical_acceptance_authority=False,release_authority=False,real_time_qualified=False)


def declaration():
    c=read(CONTRACT);require(c==expected_contract(),"Refined public exact contract")
    require(sha(CLOSURE_RESULT)==RESULT_SHA,"Refined published component");return c


def verify_parents():
    for attempt,digest,controls in ((PARENT,PARENT_SHA,274),(PUBLIC_PARENT,PUBLIC_SHA,258),(NATIVE,NATIVE_SHA,1351)):
        folder=EVIDENCE/attempt;r=read(folder/"receipt.json")
        count=r.get("controls_passed",sum(r.get("safety_controls",{}).values()))
        require(sha(folder/"receipt.json")==digest and r["ok"] is True and count==controls
            and r["source_runtime_unchanged"] is True,"Refined completed parent")
        verify_population(r["artifacts"],inventory(folder))
        require(sha(folder/"audit.json")==sha(folder/"reconstruction.json")==r["audit_sha256"],
            "Refined parent independent readers")


def audit(core_paths,capture_folder):
    c=declaration();verify_parents()
    diagnosis=read(EVIDENCE/PARENT/"audit-capture/final.json")
    following_frame=next(islice(read_jsonl(FOLLOWING),82,83))
    capture=Capture(capture_folder,c);reports=[]
    for case in cases():
        weak=case["kind"]=="native_refusal_integration"
        folder=EVIDENCE/case["attempt_id"]/"physical"/case["trial_id"]
        prior_file=EVIDENCE/PUBLIC_PARENT/"audit-capture"/(case["trial_id"]+"-core0.jsonl")
        prior_targets={} if weak else {r["request"]["state"]["semantic_step"]:r["native_targets"] for r in read_jsonl(prior_file)}
        compiled=read(folder/"compiled.json");xml=(folder/"model.xml").read_text(encoding="utf-8")
        nominal=nominal_profile(compiled,read(folder/"inputs.json"));prepared=prepare(nominal,xml)
        profile=make_profile(nominal,prepared,DLL_SHA);reference=PredictiveSelector(nominal,xml)
        selector=PreparedSelector(prepared,DLL,DLL_SHA);cores=[]
        with ExitStack() as guards:
            for name in ("MjModel","MjData","mj_step","mj_step1","mj_step2","mj_forward","mj_collision"):
                guards.enter_context(patch.object(mujoco,name,side_effect=AssertionError("Refined public no native API")))
            for name in ("fromstring","parse"):
                guards.enter_context(patch("xml.etree.ElementTree."+name,side_effect=AssertionError("Refined public no runtime XML")))
            for index,path in enumerate(core_paths):
                core=bridge.LocomotionCore(path);model=frozen_model(core)
                host=PredictiveSequenceController(core,compiled,controller_contract(hold_declaration(),model),
                    model,case["trial_id"],profile,DLL)
                previous=None;checks=[];timings=[];transfers=unchanged=0;refinements=[];continuation=None
                data=SimpleNamespace(ctrl=np.zeros(8));name=case["trial_id"]+"-core"+str(index)
                file=capture_folder/(name+".jsonl")
                try:
                    with file.open("xb") as stream:
                        originals=islice(read_jsonl(folder/"controller.jsonl"),case["maximum_commands"])
                        for step,old in enumerate(originals):
                            began=time.perf_counter()
                            row=host.step(copy.deepcopy(old["request"]["state"]),copy.deepcopy(old["stability"]),copy.deepcopy(old["kinematics"]))
                            elapsed=time.perf_counter()-began
                            if (weak and step<81) or not weak:
                                expected=old["native_targets"] if weak else prior_targets[step]
                                require(row["native_targets"]==expected,"Refined unchanged prior numerical targets");unchanged+=1
                            if step>=60:
                                decision=row["force_reference"]["decision"];selection=decision.get("selection")
                                if selection is not None and "original" in selection:
                                    refinements.append(step)
                                    require(weak and step==81 and terminal_error(row) is None,
                                        "Refined declared first integration branch")
                                    require(same_bits(decision["starting_packet"],diagnosis["starting_packet"])
                                        and same_bits(selection["original"],old["force_reference"]["decision"]["selection"])
                                        and same_bits(selection["refinement"]["result"],diagnosis["result"]),
                                        "Refined exact published native diagnosis")
                            checks.append(verify_row(core,row,previous,old,profile,selector,reference if index==0 else None))
                            began=time.perf_counter();capture.append(stream,row);capture_s=time.perf_counter()-began
                            timings.append(dict(command=step,host_step_wall_s=elapsed,capture_wall_s=capture_s))
                            require(terminal_error(row) is None,"Refined required public route refused")
                            transfer_targets(row,data);transfers+=1
                            require(data.ctrl.tolist()==row["native_targets"],"Refined exact adapter array transfer")
                            previous=row
                    require(len(checks)==case["maximum_commands"] and unchanged==(81 if weak else 62),
                        "Refined complete required route and preservation population")
                    require(refinements==([81] if weak else []),"Refined explicit branch coverage")
                    if weak:
                        fixture=following_request(core,host.force_policy,row,following_frame)
                        continuation=capture.write(name+"-following-request.json",fixture)
                finally:
                    host.close()
                    write_new(capture_folder/(name+"-timing.json"),dict(case=case,rows=timings,real_time_qualified=False))
                applied=[x for x in checks if not x["prefix"] and x["applied"]]
                cores.append(dict(core_sha256=sha(path),rows=len(checks),capture_sha256=sha(file),
                    applied_sequence_commands=len(applied),transfers=transfers,checks=checks,
                    refinement_commands=refinements,unchanged_parent_commands=unchanged,
                    synthetic_following_request=continuation))
        require(cores[0]["capture_sha256"]==cores[1]["capture_sha256"],"Refined two-core exact rows")
        if weak:require(cores[0]["synthetic_following_request"]["sha256"]==cores[1]["synthetic_following_request"]["sha256"],
            "Refined two-core exact following protocol fixture")
        reports.append(dict(case=case,profile_sha256=bridge.LocomotionCore(core_paths[0]).canonicalize_json(profile)["sha256"],
            cores=cores,core_rows_byte_identical=True))
    return dict(schema_version="locolemotion_predictive_sequence_public_audit_v4",ok=True,ledger_scope=c["ledger_scope"],
        contract_sha256=sha(CONTRACT),parent_receipt_sha256=PARENT_SHA,reports=reports,
        public_hosts=4,public_commands=sum(x["rows"] for r in reports for x in r["cores"]),
        applied_sequence_commands=sum(x["applied_sequence_commands"] for r in reports for x in r["cores"]),
        applied_refinements=sum(len(x["refinement_commands"]) for r in reports for x in r["cores"]),
        synthetic_following_requests=2,capture_rows=capture.rows,capture_bytes=capture.bytes,
        worlds_opened=0,solver_steps=0,public_first_command_verified=True,actual_resolved_history_verified=True,
        next_request_protocol_verified=True,native_continuation_verified=False,next_action_prediction_verified=False,
        observations_generated_by_selected_actions=False,planning_memory_is_learning=False,
        recovery_benefit_established=False,training_data_authority=False,tier2_qualified=False,
        tier3_benefit_established=False,physical_acceptance_authority=False,release_authority=False,real_time_qualified=False)


if __name__=="__main__":
    p=argparse.ArgumentParser();p.add_argument("--core",type=Path,required=True)
    p.add_argument("--baseline-core",type=Path,required=True);p.add_argument("--output",type=Path,required=True)
    a=p.parse_args();capture=a.output.parent/(a.output.stem+"-capture");capture.mkdir()
    result=audit((a.core,a.baseline_core),capture);write_new(a.output,result)
    print(json.dumps({k:result[k] for k in ("ok","public_commands","applied_refinements","capture_bytes")}))
