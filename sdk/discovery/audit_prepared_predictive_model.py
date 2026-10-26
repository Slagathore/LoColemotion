"""Retained canonical observations and explicit model data through prediction."""
import argparse
import copy
from contextlib import ExitStack
import json
from pathlib import Path
import time
from unittest.mock import patch
import mujoco
import numpy as np
from audit_predictive_numeric_backend import ROOT,HERE,DLL,DLL_SHA,compare,read,sha,require,GATES as PARENT_GATES
from audit_predictive_numeric_backend import declaration as parent_declaration
from audit_gpu_batch_execution import read_jsonl,same_bits
from audit_residual_training_closure import verify_population
from run_hierarchical_native_v6 import inventory
from gpu_measurement_probe import write_new
from contact_force_observer_task import bridge
from prepare_predictive_model_mujoco import prepare
from prepared_predictive_model import PreparedSelector,canonical_packet,law
from predictive_command_selection_v2 import packet

CONTRACT=HERE/"prepared_predictive_model_v1.json"
SOURCES=("prepared_predictive_model.py","prepare_predictive_model_mujoco.py",
    "test_prepared_predictive_model.py","audit_prepared_predictive_model.py","run_prepared_predictive_model.py")
GATES=(*PARENT_GATES,("prepared-model","test_prepared_predictive_model",24))
CONTROLS=sum(count for _,_,count in GATES)
CLOSURE_RESULT=HERE/"predictive_numeric_backend_result_v1.json"
RESULT_SHA="45de2bf71dbc14faf462b488b56e23094109886c6892db6d28f1c93264ea0a2b"
PARENT="sdk2-predictive-numeric-backend-v1-0c50d60d38fc4ec1a8da3aa1a84a206c"
PARENT_SHA="f5e864e2615642d568b122f2bfcba30b1c2b69d7e03bf6d34c39a0d834e91dde"
ORIGINAL="sdk2-hierarchical-native-v6-f5072c1d2e46499498911eed68d74146"
TRIAL="hierarchy_hold_left_075_train_001"
EVIDENCE=ROOT.parent/"SporeSpore_Evidence"
FOLDER=EVIDENCE/ORIGINAL/"physical"/TRIAL


def expected_contract():
    return dict(schema_version="locolemotion_prepared_predictive_model_contract_v1",
        ledger_scope=dict(subsystem="adaptation",engine_scope="core",
            authority_mode="finite_prepared_model_and_canonical_input_comparison",question_class="development"),
        parent_attempt=PARENT,parent_receipt_sha256=PARENT_SHA,parent_result_sha256=RESULT_SHA,
        original_attempt=ORIGINAL,trial_id=TRIAL,input_bindings={name:sha(FOLDER/name)
            for name in ("controller.jsonl","force-profile.json","model.xml")},
        source_bindings={name:sha(HERE/name) for name in SOURCES},dll_sha256=DLL_SHA,controls_required=CONTROLS,
        declared_model_law=law(),canonical_input_maximum_absolute_error=1e-12,
        comparison_tolerances="unchanged compiled-backend position 1e-10, velocity 1e-8, other 1e-8+1e-10 relative",
        commands=59,candidates_per_command=34,candidate_evaluations=2006,predicted_steps=10030,
        public_provenance_controls_per_core=2,public_core_builds=2,
        xml_preparation_adapter="prepare_predictive_model_mujoco.py:prepare",
        prediction_entrypoint="prepared_predictive_model.py:PreparedSelector.select_canonical",
        runtime_xml_parsing_forbidden=True,runtime_native_api_forbidden=True,
        native_model_preparation_engine_specific=True,configured_model_not_learned=True,
        public_provider_integration_verified=False,engine_neutral_provenance_qualified=False,
        cross_engine_equivalence=False,worlds_opened=0,native_physics_steps=0,
        physical_acceptance_authority=False,tier2_qualified=False,tier3_benefit_established=False,release_authority=False)


def declaration():
    c=read(CONTRACT);require(c==expected_contract(),"Prepared exact contract")
    parent_declaration()
    require(sha(CLOSURE_RESULT)==RESULT_SHA,"Prepared parent closure identity")
    return c


def audit(evidence,core_paths,output,timing):
    c=declaration();folder=evidence/PARENT
    receipt=read(folder/"receipt.json")
    require(sha(folder/"receipt.json")==PARENT_SHA and receipt["ok"] and receipt["controls_passed"]==91,
        "Prepared complete backend parent")
    verify_population(receipt["artifacts"],inventory(folder))
    require(sha(folder/"audit.json")==sha(folder/"reconstruction.json")==receipt["audit_sha256"],
        "Prepared parent identical readers")
    parent=read(folder/"audit.json")
    originals=list(read_jsonl(FOLDER/"controller.jsonl"))
    require([r["command"] for r in parent["results"]]==list(range(60,119))
        and len(originals)==120,"Prepared exact retained population")
    prepared=prepare(read(FOLDER/"force-profile.json"),(FOLDER/"model.xml").read_text(encoding="utf-8"))
    model_path=output.with_name(output.stem+"-prepared-model.json");write_new(model_path,prepared)
    require(same_bits(read(model_path),prepared),"Prepared serialized model reload")
    controls=[]
    for core_path in core_paths:
        core=bridge.LocomotionCore(core_path);request=copy.deepcopy(originals[60]["resolution_request"])
        accepted=core.resolve_adaptation_v1(request)
        request["provider_response"]["provenance"]["engine_specific_logic_used"]=True
        refused=core.resolve_adaptation_v1(request)
        require(accepted["provider_status"]=="applied" and refused["provider_status"]!="applied"
            and refused["fallback_reason"] and all(x["applied_correction_rad_s"]==0.
                for x in refused["ordered_commands"]),"Prepared public provenance refusal")
        controls.append(dict(core_sha256=sha(core_path),accepted=accepted,refused=refused))
    require(same_bits(controls[0]["accepted"],controls[1]["accepted"])
        and same_bits(controls[0]["refused"],controls[1]["refused"]),"Prepared two-core provenance identity")
    results=[]
    with ExitStack() as guards:
        for name in ("MjModel","MjData","mj_step","mj_step1","mj_step2","mj_forward","mj_collision"):
            guards.enter_context(patch.object(mujoco,name,side_effect=AssertionError("Prepared no native access")))
        for name in ("fromstring","parse"):
            guards.enter_context(patch("xml.etree.ElementTree."+name,side_effect=AssertionError("Prepared no runtime XML")))
        candidate=PreparedSelector(read(model_path),DLL,DLL_SHA)
        for old in parent["results"]:
            command=old["command"];row=originals[command];reference=packet(row)
            commands={k:v for k,v in reference.items() if k not in ("qpos","qvel")}
            observation=copy.deepcopy(row["request"]["state"]);before=copy.deepcopy((observation,commands))
            converted=canonical_packet(observation,commands,candidate.model.tree.joint_ids)
            input_errors={k:float(np.max(np.abs(np.array(converted[k])-reference[k]))) for k in ("qpos","qvel")}
            require(max(input_errors.values())<=c["canonical_input_maximum_absolute_error"],"Prepared causal state join")
            started=time.perf_counter();new=candidate.select_canonical(observation,commands)
            timing.append(dict(command=command,wall_s=time.perf_counter()-started))
            measured=compare(old["result"],new)
            require(before==(observation,commands),"Prepared inputs unchanged")
            results.append(dict(command=command,input_errors=input_errors,comparison=measured,result=new))
    maxima={key:max(r["comparison"][key] for r in results) for key in (
        "maximum_position_error","maximum_velocity_error","maximum_other_float_error","maximum_iteration_difference")}
    maxima["changed_iteration_counts"]=sum(r["comparison"]["changed_iteration_counts"] for r in results)
    return dict(schema_version="locolemotion_prepared_predictive_model_audit_v1",ok=True,
        ledger_scope=c["ledger_scope"],contract_sha256=sha(CONTRACT),parent_receipt_sha256=PARENT_SHA,
        prepared_model_sha256=sha(model_path),commands=59,candidate_evaluations=2006,predicted_steps=10030,
        input_maxima={key:max(r["input_errors"][key] for r in results) for key in ("qpos","qvel")},
        summary=maxima,results=results,public_provenance_controls=controls,
        runtime_xml_parsing_forbidden=True,runtime_native_api_forbidden=True,worlds_opened=0,native_physics_steps=0,
        public_provider_integration_verified=False,engine_neutral_provenance_qualified=False,
        production_controller_changed=False,trained=False,real_time_qualified=False,cross_engine_equivalence=False,
        tier2_qualified=False,tier3_benefit_established=False,physical_acceptance_authority=False,release_authority=False)


if __name__=="__main__":
    p=argparse.ArgumentParser(description=__doc__);p.add_argument("--core",type=Path,required=True)
    p.add_argument("--baseline-core",type=Path,required=True);p.add_argument("--output",type=Path,required=True)
    args=p.parse_args();timing=[]
    result=audit(EVIDENCE,(args.core,args.baseline_core),args.output,timing);write_new(args.output,result)
    values=[r["wall_s"] for r in timing]
    summary=dict(samples=len(values),minimum_s=min(values),mean_s=float(np.mean(values)),maximum_s=max(values))
    write_new(args.output.with_name(args.output.stem+"-timing.json"),dict(
        schema_version="locolemotion_prepared_prediction_timing_v1",ledger_scope=result["ledger_scope"],
        rows=timing,summary=summary,real_time_qualified=False))
    print(json.dumps(dict(ok=True,summary=result["summary"],input_maxima=result["input_maxima"],timing=summary)))
