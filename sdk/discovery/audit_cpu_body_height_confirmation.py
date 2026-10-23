"""Complete independent replay for fixed-candidate duration and nominal-body checks."""
import argparse
from contextlib import ExitStack
import hashlib
import json
from pathlib import Path
from unittest.mock import patch
import mujoco
from cpu_height_confirmation_task import declaration, trial_plan, assess, ROOT, FLAGS, sha, require
from motor_effectiveness_task import condition_inputs, expected_actuator_arrays
from portable_search_control import bridge
from audit_cpu_body_height_discovery import audit_trial


def read(path):
    return json.loads(path.read_text(encoding="utf-8"))


def audit(folder, core_path, baseline_path):
    declared=read(folder.parent/"declaration.json");c=declared["contract"];synthetic=declared.get("synthetic",False)
    expected=declaration()
    require(type(synthetic) is bool, "Confirmation synthetic identity")
    if synthetic:
        require(type(c["outer_steps"]) is int and 1 <= c["outer_steps"] <= 1440, "Confirmation synthetic horizon")
        expected.update(outer_steps=c["outer_steps"],synthetic=True)
    require(c == expected, "Confirmation prospective contract")
    require(sha(core_path) == c["core_sha256"] and sha(baseline_path) == c["baseline_core_sha256"], "Confirmation core identity")
    worker=read(folder/"worker-result.json")
    require(worker["ok"] is True and worker["synthetic"] is synthetic
        and worker["ledger_scope"] == c["ledger_scope"]
        and worker["status"] == "complete_native_cpu_body_height_confirmation" and worker["controller_sessions_closed"] is True
        and worker["constructed_cpu_worlds"] == 12 and worker["constructed_gpu_worlds"] == 0
        and len(worker["trials"]) == 12 and all(worker[k] is False for k in FLAGS), "Confirmation worker population/authority")
    plans=trial_plan(c);conditions=c["challenge"]["conditions"]
    require({p.name for p in folder.iterdir() if p.is_dir()} == {p["trial_id"] for p in plans}|{"models"}, "Confirmation trial folders")
    require({p.name for p in (folder/"models").iterdir() if p.is_dir()} == set(conditions), "Confirmation condition folders")
    observed=[]
    with ExitStack() as guards:
        for name in ["MjModel","MjData","mj_step","mj_step1","mj_step2","mj_forward"]:
            guards.enter_context(patch.object(mujoco,name,side_effect=AssertionError("Reader constructs no worlds")))
        core=bridge.LocomotionCore(baseline_path);models={}
        for condition in conditions:
            directory=folder/"models"/condition
            compiled,xml,spec=condition_inputs(core_path,c,condition)
            require((directory/"model.xml").read_text() == xml and sha(directory/"model.xml") == c["condition_model_sha256"][condition],
                "Confirmation condition XML binding")
            require(read(directory/"compiled.json") == compiled and read(directory/"inputs.json") == spec, "Confirmation condition inputs")
            metadata=read(directory/"native-model.json")
            for name in ["model","compiled","inputs"]:
                require(metadata[name+"_sha256"] == sha(directory/(name+(".xml" if name == "model" else ".json"))), "Confirmation native input digest")
            require(metadata["condition_id"] == condition and metadata["actuator_profile"] == expected_actuator_arrays(spec)
                and metadata["force_ranges"] == spec["force_ranges"] and metadata["dynamics_dtype"] == "float64"
                and metadata["initial_values"] == c["challenge"]["initial_values"]
                and metadata["observation_stage"] == "prepared_before_control"
                and metadata["force_stage"] == "completed_step_before_next_prepare", "Confirmation native condition profile")
            models[condition]=(compiled,spec,metadata)
        for plan,recorded in zip(plans,worker["trials"],strict=True):
            directory=folder/plan["trial_id"]
            require(read(directory/"result.json") == recorded, "Confirmation worker trial join")
            compiled,spec,metadata=models[plan["condition_id"]]
            observed.append(audit_trial(directory,plan,c,spec,compiled,metadata,core))
    return dict(ok=True,synthetic=synthetic,ledger_scope=c["ledger_scope"],trials=observed,
        controller_rows=sum(t["controller_rows"] for t in observed),internal_rows=sum(t["internal_rows"] for t in observed),
        constructed_cpu_worlds=12,constructed_gpu_worlds=0,reader_world_build_count=0,
        eligible_episodes=sum(t["episodes"][0]["outcome"] == "positive" for t in observed),
        negative_episodes=sum(t["episodes"][0]["outcome"] == "negative" for t in observed),
        native_worker_wall_s=worker["total_wall_s"],training_data_scope="development_confirmation_no_fitting",
        confirmation=assess(observed,c),controller_selection_authority=False,population_inference=False,
        **{k:False for k in FLAGS})


if __name__ == "__main__":
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument("--folder",type=Path,required=True);p.add_argument("--output",type=Path,required=True)
    p.add_argument("--core",type=Path,required=True);p.add_argument("--baseline-core",type=Path,required=True)
    a=p.parse_args();result=audit(a.folder,a.core,a.baseline_core)
    with a.output.open("x",encoding="utf-8",newline="\n") as stream:
        json.dump(result,stream,indent=2,allow_nan=False);stream.write("\n")
    print(json.dumps({k:result[k] for k in ["ok","controller_rows","internal_rows","eligible_episodes","negative_episodes","reader_world_build_count"]}))
