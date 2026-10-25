"""Contained native inertia/bias readbacks; two data worlds, no integration."""
import argparse,json,time
from contextlib import ExitStack
from pathlib import Path
from unittest.mock import patch
import numpy as np
import mujoco
from floating_dynamics_oracle_task import ROOT,FLAGS,read,sha,require,declaration,inputs,preflight,launch_records
from floating_dynamics_oracle_math import canonical_state,unchanged_state
from floating_base_dynamics_inputs import C
from gpu_measurement_probe import write_new
from run_gpu_measurement_probe import source_identity


def observe(data):
    return {name:np.asarray(getattr(data,name)).tolist()
        for name in ("qpos","qvel","xpos","xipos","subtree_com","xmat","cvel")}


def execute(folder,permit,core,baseline):
    import r10v_windows_job as jobs
    require(permit.is_file() and jobs.current_in_job()
        and permit.resolve(strict=True)==folder.resolve(strict=True)/"contained.permit","Oracle job containment")
    source=source_identity(True);c=declaration();owner=launch_records(folder,c,source)
    from run_floating_dynamics_oracle import bindings
    require(bindings(core,baseline)==owner["binding"],"Oracle worker source/runtime")
    prepared=inputs(c)
    result=dict(schema_version="locolemotion_floating_dynamics_oracle_worker_v1",ok=False,
        ledger_scope=c["ledger_scope"],source_commit=source,constructed_models=0,constructed_cpu_worlds=0,
        constructed_gpu_worlds=0,solver_steps=0,position_evaluations=0,velocity_evaluations=0,
        dense_mass_readbacks=0,states=0,trials=[],new_trajectory_generated=False,**{k:False for k in FLAGS})
    started=time.monotonic()
    try:
        with ExitStack() as guards:
            for name in c["forbidden_native_calls"]:
                guards.enter_context(patch.object(mujoco,name,side_effect=AssertionError("Oracle forbidden native operation")))
            for trial,xml,profile,rows in prepared:
                out=folder/trial;out.mkdir()
                m=mujoco.MjModel.from_xml_string(xml);result["constructed_models"]+=1
                write_new(out/"model-built.json",dict(trial_id=trial,native_model_constructed=True))
                d=mujoco.MjData(m);result["constructed_cpu_worlds"]+=1
                write_new(out/"world-opened.json",dict(trial_id=trial,native_data_constructed=True,solver_steps=0))
                require(m.nv==14 and m.nq==15 and m.nbody==10 and m.nu==8 and m.njnt==9
                    and np.array_equal(m.jnt_dofadr,np.r_[0,np.arange(6,14)])
                    and np.array_equal(m.body_rootid,np.r_[0,np.ones(9)])
                    and np.array_equal(m.dof_armature,np.r_[np.zeros(6),np.full(8,.01)])
                    and np.array_equal(m.dof_damping,np.zeros(14)) and np.count_nonzero(m.dof_dampingpoly)==0 and d.time==0.,"Oracle compiled fixture coefficients")
                write_new(out/"model-readback.json",dict(nv=m.nv,nq=m.nq,nbody=m.nbody,nu=m.nu,
                    joint_dof_addresses=m.jnt_dofadr.tolist(),body_rootid=m.body_rootid.tolist(),
                    armature=m.dof_armature.tolist(),damping=m.dof_damping.tolist(),higher_order_damping_nonzero=int(np.count_nonzero(m.dof_dampingpoly)),gravity=m.opt.gravity.tolist()))
                for row in rows:
                    obs=row["native_observation"];p,q,j,v,g=canonical_state(row)
                    require(np.allclose(m.opt.gravity,C.T @ g,atol=1e-12,rtol=0),"Oracle native gravity identity")
                    qpos=np.array(obs["qpos"]);qvel=np.array(obs["qvel"]);stamp=obs["time_s"]
                    mujoco.mj_resetData(m,d)
                    d.qpos[:]=qpos;d.qvel[:]=0.;d.time=stamp
                    mujoco.mj_fwdPosition(m,d);result["position_evaluations"]+=1
                    mujoco.mj_fwdVelocity(m,d);result["velocity_evaluations"]+=1
                    unchanged_state(d,qpos,np.zeros(14),stamp);gravity=d.qfrc_bias.copy()
                    d.qvel[:]=qvel
                    mujoco.mj_fwdPosition(m,d);result["position_evaluations"]+=1
                    mujoco.mj_fwdVelocity(m,d);result["velocity_evaluations"]+=1
                    unchanged_state(d,qpos,qvel,stamp)
                    mass=np.empty((14,14));mujoco.mj_fullM(m,d,mass);result["dense_mass_readbacks"]+=1
                    unchanged_state(d,qpos,qvel,stamp)
                    native=dict(root_rotation=d.xmat[1].reshape(3,3).tolist(),qvel=d.qvel.tolist(),
                        mass_matrix=mass.tolist(),bias=d.qfrc_bias.tolist(),gravity_bias=gravity.tolist(),
                        passive_force=d.qfrc_passive.tolist(),observation=observe(d))
                    record=dict(trial_id=trial,command=row["outer_step"],assigned_time_s=stamp,
                        state_unchanged=True,solver_steps=0,native=native)
                    write_new(out/("state-%03d.json"%row["outer_step"]),record);result["states"]+=1
                result["trials"].append(dict(trial_id=trial,states=66,model_constructed=True,data_constructed=True))
        require(result["constructed_models"]==result["constructed_cpu_worlds"]==2
            and result["states"]==result["dense_mass_readbacks"]==132
            and result["position_evaluations"]==result["velocity_evaluations"]==264,"Oracle complete native population")
        result["ok"]=True
    except BaseException as exc:result["error"]=f"{type(exc).__name__}: {exc}"
    finally:
        result["wall_s"]=time.monotonic()-started;write_new(folder/"worker-result.json",result)
    require(result["ok"],result.get("error","Oracle incomplete worker"));return result


def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument("--core",type=Path)
    p.add_argument("--baseline-core",type=Path);p.add_argument("--check-only",action="store_true")
    p.add_argument("--output",type=Path);p.add_argument("--permit",type=Path);args=p.parse_args()
    if args.check_only:print(json.dumps(preflight()))
    else:
        require(all(x is not None for x in (args.core,args.baseline_core,args.output,args.permit)),"Oracle launch arguments")
        print(json.dumps(execute(args.output,args.permit,args.core,args.baseline_core)))
    return 0
if __name__=="__main__":raise SystemExit(main())
