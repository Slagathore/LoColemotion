"""Full retained-population comparison of compiled and reference numerical paths."""
import argparse
from contextlib import ExitStack
import json
from pathlib import Path
import time
from unittest.mock import patch
import mujoco
import numpy as np
from predictive_numeric_backend import KernelSelector
from predictive_command_selection_v2 import PredictiveSelector
from audit_predictive_command_selection_v2 import ROOT,HERE,read,sha,require
from audit_gpu_batch_execution import same_bits
from audit_residual_training_closure import verify_population
from run_hierarchical_native_v6 import inventory
from gpu_measurement_probe import write_new

CONTRACT=HERE/"predictive_numeric_backend_v1.json"
SOURCES=("predictive_numeric_kernels.rs","predictive_numeric_backend.py",
    "audit_predictive_numeric_backend.py","test_predictive_numeric_backend.py","run_predictive_numeric_backend.py")
CONTROLS=91
GATES=(("contact","test_causal_contact_predictor",22),("rollout","test_held_contact_rollout",22),
    ("selection","test_predictive_command_selection_v2",25),("kernels","test_predictive_numeric_backend",22))
CLOSURE_RESULT=HERE/"predictive_command_selection_result_v2.json"
RESULT_SHA="bc51a21605f5bd5dc2a39819b8f3cf2c2619b9044b3d197bc7a6f5e5847ccd0d"
PARENT="sdk2-predictive-command-selection-v2-aaa56952527c4d6f878584c13d221225"
PARENT_SHA="236684d90c2a8079ae6efe572748e8d868101e5e77ee11851e923e7831e5962e"
PROFILE="sdk2-predictive-selection-profile-v1-3aaaf671d9be49f38640f1ed673e7bfb"
PROFILE_SHA="5969c6f47f5ae09f7aa4466281b2744ebc7911a0e5c66b9ccbc5ee131fd3c817"
BUILD="sdk2-predictive-kernel-build-24896ff6f93c480b8e66334b89b75a72"
DLL=ROOT.parent/"SporeSpore_Evidence"/BUILD/"predictive_numeric_kernels.dll"
DLL_SHA="f850d5a8cc4123e0225f8421a6e009125676c4a63b47b6f91fe3a4a75c038d93"


def expected_contract():
    build=DLL.parent
    return dict(schema_version="locolemotion_predictive_numeric_backend_contract_v1",
        ledger_scope=dict(subsystem="adaptation",engine_scope="mujoco_cpu",
            authority_mode="finite_compiled_backend_comparison",question_class="development"),
        parent_attempt=PARENT,parent_receipt_sha256=PARENT_SHA,parent_result_sha256=RESULT_SHA,
        profile_attempt=PROFILE,profile_receipt_sha256=PROFILE_SHA,
        build_attempt=BUILD,build_artifacts=inventory(build),dll_sha256=DLL_SHA,
        controls_required=CONTROLS,commands=59,candidates_per_command=34,candidate_evaluations=2006,
        predicted_steps=10030,reference_rerun_must_match_parent_bitwise=True,
        position_absolute_tolerance=1e-10,velocity_absolute_tolerance=1e-8,
        other_float_absolute_tolerance=1e-8,other_float_relative_tolerance=1e-10,
        exact_fields="All nonfloating fields, candidates, bounds, guards, decisions; optimizer iteration counts measured separately",
        strict_cone_certificate="Original Python primal/dual cone and complementarity certificate; unchanged tolerances",
        timing="Unprofiled alternating reference/compiled order by command; entire selector.select call, constructors and serialization excluded",
        thresholds_are_backend_comparison_not_physical_acceptance=True,
        worlds_opened=0,native_physics_steps=0,trained=False,real_time_qualified=False,
        tier2_qualified=False,tier3_benefit_established=False,physical_acceptance_authority=False,release_authority=False,
        source_bindings={name:sha(HERE/name) for name in SOURCES})


def declaration():
    c=read(CONTRACT);require(c==expected_contract(),"Kernel exact contract")
    require(sha(DLL)==DLL_SHA and sha(DLL.parent/"source.rs")==sha(HERE/"predictive_numeric_kernels.rs"),
        "Kernel source/build identity")
    return c


def compare(left,right,path="",stats=None):
    if stats is None:stats=dict(maximum_position_error=0.,maximum_velocity_error=0.,
        maximum_other_float_error=0.,changed_iteration_counts=0,maximum_iteration_difference=0)
    require(type(left)==type(right),"Kernel field type "+path)
    if isinstance(left,dict):
        require(left.keys()==right.keys(),"Kernel field population "+path)
        for key in left:compare(left[key],right[key],path+"."+key,stats)
    elif isinstance(left,list):
        require(len(left)==len(right),"Kernel array population "+path)
        for index,(a,b) in enumerate(zip(left,right,strict=True)):compare(a,b,path+"["+str(index)+"]",stats)
    elif type(left) is float:
        error=abs(left-right)
        if any("."+field+"[" in path for field in ("qpos","before_qpos","final_qpos","post_joint_position")):
            key="maximum_position_error";limit=1e-10
        elif any("."+field+"[" in path for field in ("qvel","before_qvel","final_qvel","post_velocity")):
            key="maximum_velocity_error";limit=1e-8
        else:key="maximum_other_float_error";limit=1e-8+1e-10*abs(left)
        require(np.isfinite(left) and np.isfinite(right) and error<=limit,"Kernel numeric parity "+path)
        stats[key]=max(stats[key],error)
    elif path.endswith(".iterations"):
        difference=abs(left-right);stats["changed_iteration_counts"]+=difference>0
        stats["maximum_iteration_difference"]=max(stats["maximum_iteration_difference"],difference)
    else:require(left==right,"Kernel exact decision field "+path)
    return stats


def audit(evidence,timing):
    contract=declaration()
    for attempt,digest in ((PARENT,PARENT_SHA),(PROFILE,PROFILE_SHA)):
        folder=evidence/attempt;require(sha(folder/"receipt.json")==digest,"Kernel retained parent identity")
        r=read(folder/"receipt.json");verify_population(r["artifacts"],inventory(folder))
        require(r["ok"] and r["controls_passed"]==69
            and sha(folder/"audit.json")==sha(folder/"reconstruction.json")==r["audit_sha256"],"Kernel complete parent readers")
    require(sha(CLOSURE_RESULT)==RESULT_SHA,"Kernel parent result")
    parent=read(evidence/PARENT/"audit.json");original=read(CLOSURE_RESULT)["original_attempt"]
    folder=evidence/original/"physical/hierarchy_hold_left_075_train_001"
    profile=read(folder/"force-profile.json");xml=(folder/"model.xml").read_text(encoding="utf-8")
    results=[]
    with ExitStack() as guards:
        for name in ("MjModel","MjData","mj_step","mj_step1","mj_step2","mj_forward","mj_collision"):
            guards.enter_context(patch.object(mujoco,name,side_effect=AssertionError("Kernels open no native world")))
        reference=PredictiveSelector(profile,xml);compiled=KernelSelector(profile,xml,DLL,DLL_SHA)
        for old in parent["results"]:
            value=old["starting_packet"];command=value["command"];pair={}
            order=("reference","compiled") if command%2==0 else ("compiled","reference")
            for name in order:
                started=time.perf_counter()
                pair[name]=(reference if name=="reference" else compiled).select(value)
                timing.append(dict(command=command,backend=name,wall_s=time.perf_counter()-started))
            require(same_bits(pair["reference"],{k:v for k,v in old.items() if k!="starting_packet"}),
                "Kernel current reference changed retained result")
            measured=compare(pair["reference"],pair["compiled"])
            results.append(dict(command=command,comparison=measured,result=pair["compiled"]))
    maxima={key:max(r["comparison"][key] for r in results) for key in
        ("maximum_position_error","maximum_velocity_error","maximum_other_float_error","maximum_iteration_difference")}
    maxima["changed_iteration_counts"]=sum(r["comparison"]["changed_iteration_counts"] for r in results)
    return dict(schema_version="locolemotion_predictive_numeric_backend_audit_v1",ok=True,
        ledger_scope=contract["ledger_scope"],contract_sha256=sha(CONTRACT),parent_receipt_sha256=PARENT_SHA,
        profile_receipt_sha256=PROFILE_SHA,dll_sha256=DLL_SHA,commands=59,candidate_evaluations=2006,
        predicted_steps=10030,summary=maxima,results=results,worlds_opened=0,native_physics_steps=0,
        production_controller_changed=False,trained=False,real_time_qualified=False,
        tier2_qualified=False,tier3_benefit_established=False,physical_acceptance_authority=False,release_authority=False)


if __name__=="__main__":
    p=argparse.ArgumentParser(description=__doc__);p.add_argument("--core",type=Path,required=True)
    p.add_argument("--baseline-core",type=Path,required=True);p.add_argument("--output",type=Path,required=True)
    args=p.parse_args();timing=[];result=audit(ROOT.parent/"SporeSpore_Evidence",timing)
    write_new(args.output,result)
    summary={}
    for name in ("reference","compiled"):
        values=[r["wall_s"] for r in timing if r["backend"]==name]
        summary[name]=dict(samples=len(values),minimum_s=min(values),mean_s=float(np.mean(values)),
            median_s=float(np.median(values)),maximum_s=max(values),total_s=sum(values))
    write_new(args.output.with_name(args.output.stem+"-timing.json"),dict(
        schema_version="locolemotion_predictive_numeric_timing_v1",ledger_scope=result["ledger_scope"],
        summary=summary,rows=timing,real_time_qualified=False,control_period_s=5/600.))
    print(json.dumps(dict(ok=True,summary=result["summary"],timing=summary,output=str(args.output))))
