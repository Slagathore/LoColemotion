"""Read eight bound best trajectories; no candidate evaluation or native access."""
import argparse
from contextlib import ExitStack
from pathlib import Path
from unittest.mock import patch
import json
import mujoco
from sequence_authority_task_v1 import *
from sequence_authority_diagnostic_v1 import diagnose
from audit_sequence_constraint_repair_v1 import bound_inputs
from audit_predictive_sequence_v1 import Capture
from actuation_recovery_mechanics import RigidTree
from gpu_measurement_probe import write_new
from audit_gpu_batch_execution import same_bits


def model_spec(profile):
    m=profile["prepared_model"];tree=RigidTree(m["morphology_spec"])
    return dict(joint_ids=tree.joint_ids,
        limits=[[j["lower_limit_rad"],j["upper_limit_rad"]] for j in tree.joints],
        gains=m["velocity_gains"],ranges=m["force_ranges"],
        geom_bodies=["world"]+[g["body_id"] for g in m["ordered_geometry"]])


def audit(capture_folder):
    c=declaration();closure=parent();capture=Capture(capture_folder,c)
    profile=read(TRIAL/"force-profile.json");spec=model_spec(profile);summaries=[];last_value=None
    native_contract=prior.declaration()
    with ExitStack() as stack:
        for name in ("MjModel","MjData","mj_step","mj_step1","mj_step2","mj_forward","mj_collision"):
            stack.enter_context(patch.object(mujoco,name,side_effect=AssertionError("Authority no native access")))
        for name in ("fromstring","parse"):
            stack.enter_context(patch("xml.etree.ElementTree."+name,side_effect=AssertionError("Authority no XML")))
        stack.enter_context(patch("predictive_sequence_v1.evaluate",side_effect=AssertionError("Authority no new forecasts")))
        stack.enter_context(patch("held_contact_rollout.HeldContactRollout.predict",side_effect=AssertionError("Authority no rollout")))
        def retain(name,value,best,binding):
            diagnostic=diagnose(value,best["option"]["knots"],best["result"],spec)
            artifact=capture.write(name+".json",dict(case=name,input_binding=binding,
                starting_packet=value,control_points=best["option"]["knots"],specification=spec,diagnostic=diagnostic))
            summaries.append(dict(case=name,artifact=artifact,**{k:v for k,v in diagnostic.items() if k!="trace"}))
            print(json.dumps(dict(case=name,steps=diagnostic["predicted_steps"],
                accepted=diagnostic["accepted"])),flush=True)
        for previous,row,expected in inputs(native_contract,closure):
            value,plan,selection=bound_inputs(previous,row,profile,expected)
            binding=dict(controller_sha256=native_contract["input_bindings"]["controller.jsonl"],
                row_sha256=expected["row_sha256"])
            if value["command"]==86:
                retain("native_original_86",value,selection["original"]["best"],binding);last_value=value
            retain("native_refined_"+str(value["command"]),value,selection["refinement"]["result"]["best"],binding)
        require(last_value is not None,"Authority terminal causal input")
        for name,path in EXTRA:
            retained=read(path)
            require(same_bits(retained["starting_packet"],last_value),"Authority identical terminal starting state")
            key=str(path.relative_to(EVIDENCE)).replace("\\","/")
            require(sha(path)==c["input_bindings"][key],"Authority captured forecast identity")
            retain(name,last_value,retained["result"]["best"],dict(path=key,sha256=sha(path)))
    require(tuple(x["case"] for x in summaries)==CASES,"Authority exact eight-case population")
    require(c==expected_contract(),"Authority inputs and source unchanged")
    return dict(schema_version="locolemotion_sequence_authority_audit_v1",ok=True,
        ledger_scope=c["ledger_scope"],contract_sha256=sha(CONTRACT),parent_receipt_sha256=PARENT_SHA,
        controls_required=CONTROLS,inherited_verified_controls=362,cases=summaries,
        total_retained_predicted_steps=sum(x["predicted_steps"] for x in summaries),
        capture_rows=capture.rows,capture_bytes=capture.bytes,retained_forecasts_only=True,
        new_forecasts=0,candidate_searches=0,worlds_opened=0,solver_steps=0,
        dynamics_recomputed=False,local_ranges_prove_global_infeasibility=False,
        baseline_approximation_error_measured=False,actual_native_transfer_verified=False,
        recovery_benefit_established=False,training_data_authority=False,tier2_qualified=False,
        tier3_benefit_established=False,physical_acceptance_authority=False,release_authority=False)


if __name__=="__main__":
    p=argparse.ArgumentParser();p.add_argument("--core",type=Path,required=True)
    p.add_argument("--baseline-core",type=Path,required=True);p.add_argument("--output",type=Path,required=True)
    args=p.parse_args();folder=args.output.parent/(args.output.stem+"-capture");folder.mkdir()
    result=audit(folder);write_new(args.output,result)
    print(json.dumps(dict(ok=True,cases=len(result["cases"]),steps=result["total_retained_predicted_steps"])))
