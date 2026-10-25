"""Recompute all finite native readback comparisons without new worlds."""
import argparse,json
from contextlib import ExitStack
from pathlib import Path
from unittest.mock import patch
import numpy as np
import mujoco
from floating_dynamics_oracle_task import FLAGS,require,read,sha,declaration,inputs
from floating_dynamics_oracle_math import compare_record
from gpu_measurement_probe import write_new


def audit(folder):
    c=declaration();worker=read(folder/"worker-result.json")
    require(worker["ok"] is True and worker["constructed_models"]==worker["constructed_cpu_worlds"]==2
        and worker["constructed_gpu_worlds"]==worker["solver_steps"]==0
        and worker["states"]==worker["dense_mass_readbacks"]==132
        and worker["position_evaluations"]==worker["velocity_evaluations"]==264
        and worker["new_trajectory_generated"] is False and all(worker[k] is False for k in FLAGS),
        "Oracle native population/authority")
    rows=[];trials=[]
    with ExitStack() as guards:
        for name in ("MjModel","MjData",*c["forbidden_native_calls"],"mj_fwdPosition","mj_fwdVelocity"):
            guards.enter_context(patch.object(mujoco,name,side_effect=AssertionError("Oracle reader opens no worlds")))
        for trial,_,profile,originals in inputs(c):
            out=folder/trial
            require(sorted(p.name for p in out.glob("state-*.json"))==["state-%03d.json"%i for i in range(60,126)],
                "Oracle complete readback files")
            require(read(out/"world-opened.json")==dict(trial_id=trial,native_data_constructed=True,solver_steps=0)
                and read(out/"model-built.json")==dict(trial_id=trial,native_model_constructed=True),"Oracle construction markers")
            meta=read(out/"model-readback.json")
            require(meta==dict(nv=14,nq=15,nbody=10,nu=8,joint_dof_addresses=[0,*range(6,14)],
                body_rootid=[0]+[1]*9,armature=[0.]*6+[.01]*8,damping=[0.]*14,higher_order_damping_nonzero=0,gravity=[0.,0.,-9.81]),
                "Oracle model readback identity")
            errors={};geometry={}
            for original in originals:
                path=out/("state-%03d.json"%original["outer_step"]);record=read(path);obs=original["native_observation"]
                require(record["trial_id"]==trial and record["command"]==original["outer_step"]
                    and record["assigned_time_s"]==obs["time_s"] and record["state_unchanged"] is True
                    and record["solver_steps"]==0 and record["native"]["observation"]["qpos"]==obs["qpos"]
                    and record["native"]["observation"]["qvel"]==obs["qvel"],"Oracle original assigned state")
                checked=compare_record(profile,original,record["native"],c["synthetic_acceleration"])
                for k,v in checked["maximum_errors"].items():errors[k]=max(errors.get(k,0.),v)
                for k,v in checked["native_geometry_velocity_errors"].items():geometry[k]=max(geometry.get(k,0.),v)
                rows.append(dict(trial_id=trial,command=original["outer_step"],readback_sha256=sha(path),comparison=checked))
            trials.append(dict(trial_id=trial,states=66,maximum_errors=errors,maximum_geometry_velocity_errors=geometry))
    require(len(rows)==132,"Oracle comparison count")
    return dict(schema_version="locolemotion_floating_dynamics_oracle_audit_v1",ok=True,
        ledger_scope=c["ledger_scope"],contract_sha256=sha(__import__("floating_dynamics_oracle_task").CONTRACT),
        worker_result_sha256=sha(folder/"worker-result.json"),states=132,trials=trials,rows=rows,
        native_dynamics_readback_agreement_verified_for_retained_states=True,
        native_models_constructed=2,native_data_worlds_constructed=2,native_solver_steps=0,
        reader_world_build_count=0,reader_solver_steps=0,**{k:False for k in FLAGS})


def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument("--folder",type=Path,required=True)
    p.add_argument("--output",type=Path,required=True);args=p.parse_args()
    value=audit(args.folder);write_new(args.output,value)
    print(json.dumps(dict(ok=True,states=132,reader_world_build_count=0,reader_solver_steps=0)))
    return 0
if __name__=="__main__":raise SystemExit(main())
