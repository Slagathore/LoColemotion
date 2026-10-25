"""Reproduce the consumed first dynamic controller's independent KKT refusal."""
from pathlib import Path
from unittest.mock import patch
import numpy as np
import dynamic_inverse_dynamics as original_math
from dynamic_force_policy import Policy
from dynamic_qp_solver import certificate
from hold_horizon_task import ROOT,read,sha,require,bridge
from audit_gpu_batch_execution import read_jsonl
from audit_contact_force_observer_closure import validate_bindings
from audit_residual_training_closure import verify_population
from run_support_reach_native import inventory
from run_residual_native import verify_tests

FAILED="sdk2-dynamic-control-component-e404d6cb8b4c44fd9853fd78f4170e72"
FAILED_SHA="525b8b48227e0b2935bce39334cc34d5401257151acd4c02773247efc6918b63"


def verify_failure():
    folder=ROOT.parent/"SporeSpore_Evidence"/FAILED;receipt=read(folder/"receipt.json")
    require(sha(folder/"receipt.json")==FAILED_SHA and receipt["ok"] is False and receipt["controls_passed"]==103
        and receipt["worlds_opened"]==receipt["solver_steps"]==0 and receipt["physical_started"] is False
        and "audit-reader" in receipt["error"],"Dynamic consumed numerical refusal")
    verify_population(receipt["artifacts"],inventory(folder))
    decl=read(folder/"declaration.json");validate_bindings(decl["binding"])
    from dynamic_control_component_task import GATES
    for name,_,count in GATES:verify_tests(folder/(name+"-controls"),count)
    streams=[list(read_jsonl(folder/("audit/reach_hold_left_075_train_001-core-"+str(i)+".jsonl"))) for i in (0,1)]
    require([len(s) for s in streams]==[129,128] and streams[0][:128]==streams[1],"Dynamic original partial population")
    row=streams[0][-1]["controller"];request=row["resolution_request"]["provider_request"]
    require(row["request"]["state"]["semantic_step"]==128
        and row["force_reference"]["terminal_error"]==dict(type="ValueError",message="Dynamic QP refused: solved")
        and row["resolution_request"]["provider_response"] is None
        and not (folder/"audit.json").exists() and not (folder/"reconstruction.json").exists(),
        "Dynamic refused original command and absent complete readers")
    core_files=[Path(n) for n,h in decl["binding"]["runtime"].items()
        if h=="f88cb47a720802ac95d3f4553bd238f5812a6e9b291b17f5e2717708aa3d5b99"]
    require(len(core_files)==1,"Dynamic original core identity");core=bridge.LocomotionCore(core_files[0])
    profile=read(folder/"audit/reach_hold_left_075_train_001-profile.json");policy=Policy(core,profile)
    captured={};solve=original_math.solve
    def retained(*args):
        result=solve(*args);captured.update(result)
        require(result["certificate"]==certificate(*args,result["x"],result["y"]),"Dynamic refusal independently recomputed")
        return result
    with patch.object(original_math,"solve",retained):
        try:policy.respond(request)
        except ValueError as exc:require(str(exc)=="Dynamic QP refused: solved","Dynamic exact numerical refusal")
        else:raise ValueError("Dynamic original refusal was not reproduced")
    cert=captured["certificate"];scale=cert["stationarity_scale"]
    require(captured["accepted"] is False and captured["status_value"]==1 and captured["iterations"]==300
        and captured["polishing_status"]==-1
        and captured["problem_sha256"]=="dc8e71fe8b9a520811d85e9807531c5b761e5a4bba98cd37d0e36598b0005b97"
        and cert["maximum_bound_violation"]<=2e-6
        and cert["maximum_stationarity_error"]<=1e-6+1e-8*scale
        and cert["maximum_complementarity_error"]>2e-6+1e-8*scale,"Dynamic isolated complementarity refusal")
    return dict(attempt_id=FAILED,receipt_sha256=FAILED_SHA,ok=False,controls_passed=103,command=128,
        original_stream_rows=[129,128],original_complete_readers=0,refusal_reproduced=True,
        source_binding_count=len(decl["binding"]["source"]),runtime_binding_count=len(decl["binding"]["runtime"]),
        problem_sha256=captured["problem_sha256"],iterations=captured["iterations"],polishing_status=-1,
        certificate=cert,world_build_count=0,solver_steps=0,alternative_actions_generated_observations=False)
