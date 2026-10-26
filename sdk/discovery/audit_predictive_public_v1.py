"""Bounded retained-state predictive public hosts on two core builds."""
import argparse
import copy
from contextlib import ExitStack
import json
import time
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch
import numpy as np
import mujoco
from audit_prepared_predictive_model import ROOT,HERE,DLL,DLL_SHA,read,sha,require,GATES as MODEL_GATES
from audit_prepared_predictive_model import declaration as model_declaration
from audit_gpu_batch_execution import read_jsonl,same_bits
from audit_residual_training_closure import verify_population
from run_hierarchical_native_v6 import inventory
from contact_force_observer_task import bridge
from hold_horizon_task import controller_contract,frozen_model,declaration as hold_declaration
from hierarchical_force_policy_v8 import make_profile as nominal_profile
from prepare_predictive_model_mujoco import prepare
from predictive_hold_policy_v1 import make_profile
from predictive_hold_control_v1 import PredictiveHoldController,terminal_error,transfer_targets
from predictive_public_row_audit_v1 import verify_row
from predictive_command_selection_v2 import PredictiveSelector
from gpu_measurement_probe import write_new

CONTRACT=HERE/"predictive_public_v1.json"
SOURCES=("predictive_hold_policy_v1.py","predictive_hold_control_v1.py","predictive_public_row_audit_v1.py",
    "test_predictive_hold_policy_v1.py","test_predictive_public_audit_v1.py",
    "audit_predictive_public_v1.py","run_predictive_public_v1.py")
GATES=(*MODEL_GATES,("nominal-policy","test_hierarchical_force_policy_v8",17),
    ("predictive-policy","test_predictive_hold_policy_v1",28),("predictive-reader","test_predictive_public_audit_v1",10))
CONTROLS=sum(count for _,_,count in GATES)
CLOSURE_RESULT=HERE/"prepared_predictive_model_result_v1.json"
RESULT_SHA="fedff7e06516745c34b76f0b835303f13ec3dc7ddfc0228c042c4dd3ec993495"
PARENT="sdk2-prepared-predictive-model-v1-363b5ff2b39d4d63a5bdb1b08a6361a6"
PARENT_SHA="f224690dd6a2dad1bfa7f444fc6003f67bb1f10527cff896474e841e53b6da90"
EVIDENCE=ROOT.parent/"SporeSpore_Evidence"


def cases():
    return [dict(attempt_id="sdk2-hierarchical-native-v6-f5072c1d2e46499498911eed68d74146",
        trial_id="hierarchy_hold_left_075_train_001",maximum_commands=120,kind="weak_retained_route"),
        dict(attempt_id="sdk2-support-reach-native-1b8cdaeebbb246079d7cf5737cfa4dd8",
        trial_id="reach_hold_nominal_train_001",maximum_commands=62,kind="nominal_retained_handoff")]


def expected_contract():
    return dict(schema_version="locolemotion_predictive_public_contract_v1",
        ledger_scope=dict(subsystem="adaptation",engine_scope="core",
            authority_mode="bounded_retained_state_public_route",question_class="development"),
        source_bindings={name:sha(HERE/name) for name in SOURCES},parent_attempt=PARENT,
        parent_receipt_sha256=PARENT_SHA,parent_result_sha256=RESULT_SHA,
        input_cases=[dict(case,input_bindings={name:sha(EVIDENCE/case["attempt_id"]/"physical"/case["trial_id"]/name)
            for name in ("controller.jsonl","compiled.json","inputs.json","model.xml")}) for case in cases()],
        controls_required=CONTROLS,public_core_builds=2,public_hosts_per_reader=4,
        maximum_public_commands_per_reader=364,unchanged_prefix_per_host=60,
        minimum_applied_predictive_commands_per_host=2,
        stopping_rule="first retained terminal provider error closes host; no failed command is transferred",
        full_reference_forecasts="all candidates at every reached selection row on first core; second core rows must match bitwise",
        reference_backend="published Python predictive selector with unchanged comparison tolerances",
        nominal_hierarchy_role="diagnostic proposal seed; its force certificate is not selected-command authority",
        provenance_contract=dict(engine_specific_logic_used=False,
            meaning="runtime policy uses canonical observations and explicit model parameters without engine-specific dispatch",
            adapter_model_preparation_engine_specific=True,contact_law_configured_not_estimated=True,
            cross_engine_equivalence=False,arbitrary_models_supported=False),
        runtime_xml_parsing_forbidden=True,runtime_native_api_forbidden=True,
        timing="unprofiled complete host.step; reference verification and serialization excluded; separate artifacts",
        public_resolver_unchanged=True,native_targets_from_final_public_resolution_only=True,
        actual_resolved_history_required=True,synthetic=True,worlds_opened=0,solver_steps=0,
        alternative_actions_generated_observations=False,physical_launch_authority=False,
        physical_acceptance_authority=False,training_data_authority=False,
        recovery_benefit_established=False,real_time_qualified=False,
        tier2_qualified=False,tier3_benefit_established=False,release_authority=False)


def declaration():
    c=read(CONTRACT);require(c==expected_contract(),"Predictive public exact contract")
    model_declaration();require(sha(CLOSURE_RESULT)==RESULT_SHA,"Predictive public prepared closure")
    return c


def audit(evidence,core_paths,capture):
    c=declaration();folder=evidence/PARENT;r=read(folder/"receipt.json")
    require(sha(folder/"receipt.json")==PARENT_SHA and r["ok"] and r["controls_passed"]==115,
        "Predictive public complete prepared parent")
    verify_population(r["artifacts"],inventory(folder))
    require(sha(folder/"audit.json")==sha(folder/"reconstruction.json")==r["audit_sha256"],
        "Predictive public parent identical readers")
    reports=[]
    for case in cases():
        original_folder=evidence/case["attempt_id"]/"physical"/case["trial_id"]
        original=list(read_jsonl(original_folder/"controller.jsonl"))[:case["maximum_commands"]]
        require(len(original)==case["maximum_commands"],"Predictive public complete declared inputs")
        compiled=read(original_folder/"compiled.json");xml=(original_folder/"model.xml").read_text(encoding="utf-8")
        nominal=nominal_profile(compiled,read(original_folder/"inputs.json"))
        prepared=prepare(nominal,xml);profile=make_profile(nominal,prepared,DLL_SHA)
        reference=PredictiveSelector(nominal,xml);outputs=[];checked=[]
        with ExitStack() as guards:
            for name in ("MjModel","MjData","mj_step","mj_step1","mj_step2","mj_forward","mj_collision"):
                guards.enter_context(patch.object(mujoco,name,side_effect=AssertionError("Predictive public no native access")))
            for name in ("fromstring","parse"):
                guards.enter_context(patch("xml.etree.ElementTree."+name,side_effect=AssertionError("Predictive public no runtime XML")))
            for index,path in enumerate(core_paths):
                core=bridge.LocomotionCore(path);model=frozen_model(core)
                host=PredictiveHoldController(core,compiled,controller_contract(hold_declaration(),model),
                    model,case["trial_id"],profile,DLL)
                rows=[];checks=[];timings=[];transfers=0;data=SimpleNamespace(ctrl=np.zeros(8))
                try:
                    for step,old in enumerate(original):
                        started=time.perf_counter()
                        row=host.step(copy.deepcopy(old["request"]["state"]),copy.deepcopy(old["stability"]),copy.deepcopy(old["kinematics"]))
                        timings.append(dict(command=step,host_step_wall_s=time.perf_counter()-started))
                        rows.append(row)
                        checks.append(verify_row(core,row,rows[-2] if step else None,old,profile,reference if index==0 else None))
                        if terminal_error(row) is not None:
                            before=data.ctrl.copy()
                            try:transfer_targets(row,data)
                            except ValueError:pass
                            else:raise ValueError("Predictive public refusal transferred")
                            require(host.closed and np.array_equal(before,data.ctrl),"Predictive public refused world input unchanged")
                            break
                        transfer_targets(row,data);transfers+=1
                        require(data.ctrl.tolist()==row["native_targets"],"Predictive public actual adapter transfer")
                finally:
                    host.close()
                    write_new(capture/(case["trial_id"]+"-core"+str(index)+".json"),dict(
                        case=case,profile=profile,core_sha256=sha(path),rows=rows,checks=checks,
                        successful_mock_transfers=transfers,controller_closed=host.closed,worlds_opened=0))
                    values=[x["host_step_wall_s"] for x in timings if x["command"]>=60]
                    write_new(capture/(case["trial_id"]+"-core"+str(index)+"-timing.json"),dict(
                        case=case,rows=timings,post_handoff_samples=len(values),
                        post_handoff_mean_s=float(np.mean(values)) if values else None,
                        post_handoff_maximum_s=max(values) if values else None,
                        post_handoff_total_s=sum(values),real_time_qualified=False))
                require(len(rows)>=62 and sum(not x["prefix"] and x["applied"] for x in checks)>=2,
                    "Predictive public minimum full handoff coverage")
                require(len(rows)==case["maximum_commands"] or terminal_error(rows[-1]) is not None,
                    "Predictive public bounded route completed or retained refusal")
                outputs.append(rows);checked.append(checks)
        require(same_bits(outputs[0],outputs[1]),"Predictive public two-core bitwise rows")
        checks=checked[0];selected=[x for x in checks if not x["prefix"] and x["applied"]]
        comparisons=[x["comparison"] for x in checks if x.get("comparison") is not None]
        reports.append(dict(case=case,profile_sha256=bridge.LocomotionCore(core_paths[0]).canonicalize_json(profile)["sha256"],
            commands_per_core=len(outputs[0]),applied_predictive_commands_per_core=len(selected),
            non_nominal_selected_per_core=sum(x["differs_from_nominal"] for x in selected),
            reference_compared_selections=len(comparisons),candidate_forecasts_compared=len(comparisons)*34,
            terminal_error=terminal_error(outputs[0][-1]),terminal_command=(len(outputs[0])-1 if terminal_error(outputs[0][-1]) else None),
            terminal_stage=(outputs[0][-1]["force_reference"]["decision"]["stage"] if terminal_error(outputs[0][-1]) else None),
            cores_bitwise_identical=True,checks=checks))
    return dict(schema_version="locolemotion_predictive_public_audit_v1",ok=True,
        ledger_scope=c["ledger_scope"],contract_sha256=sha(CONTRACT),parent_receipt_sha256=PARENT_SHA,
        public_hosts=4,public_commands=sum(x["commands_per_core"]*2 for x in reports),
        applied_predictive_commands=sum(x["applied_predictive_commands_per_core"]*2 for x in reports),
        non_nominal_selected=sum(x["non_nominal_selected_per_core"]*2 for x in reports),
        reference_compared_selections=sum(x["reference_compared_selections"] for x in reports),
        candidate_forecasts_compared=sum(x["candidate_forecasts_compared"] for x in reports),
        public_controller_integration_verified=True,actual_resolved_history_verified=True,
        nominal_hierarchy_certificate_promoted=False,observations_generated_by_selected_actions=False,
        runtime_xml_parsing_forbidden=True,runtime_native_api_forbidden=True,reports=reports,
        synthetic=True,worlds_opened=0,solver_steps=0,physical_launch_authority=False,
        recovery_benefit_established=False,real_time_qualified=False,training_data_authority=False,
        tier2_qualified=False,tier3_benefit_established=False,physical_acceptance_authority=False,release_authority=False)


if __name__=="__main__":
    p=argparse.ArgumentParser(description=__doc__);p.add_argument("--core",type=Path,required=True)
    p.add_argument("--baseline-core",type=Path,required=True);p.add_argument("--output",type=Path,required=True)
    args=p.parse_args();capture=args.output.parent/(args.output.stem+"-capture");capture.mkdir()
    result=audit(EVIDENCE,(args.core,args.baseline_core),capture);write_new(args.output,result)
    print(json.dumps({k:result[k] for k in ("ok","public_commands","applied_predictive_commands","candidate_forecasts_compared")}))
