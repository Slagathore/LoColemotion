"""Streaming native invariants and explicit complete/refused denominators."""
import math
from itertools import zip_longest
import numpy as np
from audit_gpu_batch_execution import same_bits,finite_vector,read_jsonl,SECTIONS
from actuation_recovery_mechanics import require,motor_torque
from causal_force_control import terminal_error


def outcome(result,c,role):
    complete=result["completed"];outer=result["outer_rows"];inner=result["internal_rows"]
    require(type(complete) is bool and type(outer) is int and type(inner) is int
        and 1<=outer<=c["outer_steps"] and result["controller_closed"] is True,"Predictive result population")
    if complete:
        require(result["status"]=="complete" and result["terminal_refusal"] is None
            and inner==5*outer==5*c["outer_steps"],"Predictive complete denominator")
    else:
        require(role=="predictive_hold" and result["status"]=="controller_refusal"
            and isinstance(result["terminal_refusal"],dict) and inner==5*(outer-1)
            and result["terminal_refusal"]["command"]==outer-1,"Predictive refusal denominator")
    return outer,inner


def worker_population(worker,population,flags):
    rows=worker["trials"];n=len(rows)
    require(worker["ok"] is True and worker["synthetic"] is False and 1<=n<=len(population)
        and worker["constructed_cpu_worlds"]==worker["constructed_model_count"]==n
        and worker["constructed_gpu_worlds"]==0 and all(worker[k] is False for k in flags),
        "Predictive worker world population/authority")
    require(worker["unopened_trials"]==[p["trial_id"] for p in population[n:]]
        and all(all(r.get(k)==v for k,v in p.items()) for r,p in zip(rows,population[:n],strict=True)),
        "Predictive ordered opened/unopened trials")
    complete=all(r["completed"] is True for r in rows)
    require(type(worker["execution_complete"]) is bool and worker["execution_complete"] is complete,
        "Predictive worker execution semantics")
    if complete:require(n==len(population) and worker["status"]=="complete_predictive_native_fixture","Predictive full fixture")
    else:
        require(all(r["completed"] is True for r in rows[:-1]) and rows[-1]["completed"] is False
            and rows[-1]["role"]=="predictive_hold" and rows[-1]["status"]=="controller_refusal"
            and worker["status"]=="retained_controller_refusal","Predictive stop after first refusal")
    return n


def refusal_join(result,row,last,initial,previous_targets):
    value=result["terminal_refusal"];native=row["native_observation"]
    require(terminal_error(row) is not None and value["error"]==terminal_error(row)
        and value["transferred"] is False and value["command"]==row["outer_step"],
        "Predictive final refusal cause/transfer")
    require(same_bits(value["native_control"],previous_targets)
        and same_bits(value["qpos"],native["qpos"]) and same_bits(value["qvel"],native["qvel"])
        and value["time_s"]==native["time_s"],"Predictive refusal capture")
    expected=(last["qpos"],last["qvel"],last["time_s"]) if last else (*initial,0.)
    require(same_bits(value["qpos"],expected[0]) and same_bits(value["qvel"],expected[1])
        and value["time_s"]==expected[2],"Predictive refusal changed state")


def timing_row(row,index,transferred):
    require(set(row)=={"outer_step","measured","transfer_performed",*SECTIONS,"outer_total_s"}
        and row["outer_step"]==index and row["measured"] is True
        and row["transfer_performed"] is transferred,"Predictive timing identity")
    values=[row[k] for k in (*SECTIONS,"outer_total_s")]
    require(all(type(x) in (int,float) and math.isfinite(x) and x>=0 for x in values)
        and row["outer_total_s"]>0 and sum(row[k] for k in SECTIONS)<=row["outer_total_s"]+1e-9,
        "Predictive finite partitioned timing")
    if not transferred:require(row["integration_and_device_history_s"]==row["internal_readback_and_capture_s"]==0.,
        "Predictive refused timing contains integration")


def compare_pair(reference,candidate,c):
    for i,(x,y) in enumerate(zip(read_jsonl(reference/"controller.jsonl"),read_jsonl(candidate/"controller.jsonl"))):
        if i<60:
            require(all(same_bits(x[k],y[k]) for k in ("native_observation","stability","kinematics","composition","output","native_targets"))
                and same_bits(x["request"]["state"],y["request"]["state"]),"Predictive paired prefix control")
        else:
            require(same_bits(x["native_observation"],y["native_observation"]),"Predictive prepared handoff")
            break
    else:raise ValueError("Predictive missing prefix/handoff")
    count=0
    for x,y in zip(read_jsonl(reference/"trace.jsonl"),read_jsonl(candidate/"trace.jsonl")):
        require(same_bits(x,y),"Predictive paired native prefix");count+=1
        if count==300:break
    require(count==300,"Predictive missing native prefix")
    return dict(prefix_controller_rows_identical=60,prefix_internal_rows_identical=300,
        handoff_prepared_state_identical=True,fresh_worlds=2,post_handoff_equality_required=False)


def compare_baseline(reference,candidate,c):
    counts={}
    for stream,expected in (("controller",c["outer_steps"]),("trace",5*c["outer_steps"])):
        n=0
        for a,b in zip_longest(read_jsonl(reference/(stream+".jsonl")),read_jsonl(candidate/(stream+".jsonl"))):
            require(a is not None and b is not None and same_bits(a,b),"Predictive fresh baseline changed")
            n+=1
        require(n==expected,"Predictive full baseline denominator");counts[stream+"_rows_identical"]=n
    return dict(counts,fresh_world=True,cached_physical_state_used=False)


def native_step(row,step,control,last,initial,spec,c,profile):
    """Validate every solver input and sample independently of forecast success."""
    eps=2**-52;qpos,qvel=initial
    require(step<=5*c["outer_steps"] and (row["backend"],row["cell"],row["step"])==("cpu",0,step),"Predictive internal order")
    for name,length in (("qpos",15),("before_qpos",15),("qvel",14),("before_qvel",14),
                        ("ctrl",8),("actuator_force_nm",8),("joint_force_nm",8)):
        require(finite_vector(row[name],length),"Predictive finite native population")
    require(same_bits(row["before_qpos"],last["qpos"] if last else qpos)
        and same_bits(row["before_qvel"],last["qvel"] if last else qvel),"Predictive native state continuity")
    require(same_bits(row["ctrl"],control["native_targets"]),"Predictive held solver input differs")
    if (step-1)%5==0:
        require(same_bits(row["before_qpos"],control["native_observation"]["qpos"])
            and same_bits(row["before_qvel"],control["native_observation"]["qvel"]),"Predictive prepared-state clock")
        now=control["native_observation"]["time_s"]
        require(math.isfinite(now) and abs(now-(step-1)*c["timestep_s"])<=4*eps*step*step*c["timestep_s"],"Predictive observation time")
    require(math.isfinite(row["time_s"]) and abs(row["time_s"]-step*c["timestep_s"])<=4*eps*step*step*c["timestep_s"],"Predictive internal time")
    require(abs(sum(x*x for x in row["qpos"][3:7])-1.)<=128*eps,"Predictive native quaternion")
    require(row["warnings"]==[0]*c["cpu_warning_count"] and type(row["overflow"]) is int and row["overflow"]==0
        and type(row["nefc"]) is int and 0<=row["nefc"]<=c["njmax"],"Predictive native warning/capacity")
    require(row["on_force_cap"]==[f<=lo or f>=hi for f,(lo,hi) in zip(row["actuator_force_nm"],spec["force_ranges"],strict=True)],
        "Predictive force-cap labels")
    for force,joint,(lo,hi) in zip(row["actuator_force_nm"],row["joint_force_nm"],spec["force_ranges"],strict=True):
        require(lo-32*eps*abs(lo)<=force<=hi+32*eps*abs(hi)
            and abs(force-joint)<=32*eps*max(abs(lo),abs(hi)),"Predictive force bounds/named sensors")
    require(type(row["batch_contacts"]) is int and 0<=row["batch_contacts"]<=c["naconmax"],"Predictive contact capacity")
    slots=[]
    for contact in row["contacts"]:
        require(type(contact["world"]) is int and contact["world"]==0
            and type(contact["native_index"]) is int and 0<=contact["native_index"]<row["batch_contacts"],"Predictive contact world/index")
        pair=contact["geom"]
        require(len(pair)==2 and 0 in pair and pair[0]!=pair[1]
            and all(type(g) is int and 0<=g<10 for g in pair),"Predictive contact geometry")
        require(finite_vector(contact["position_m"],3) and finite_vector(contact["frame"],9)
            and math.isfinite(contact["distance_m"]),"Predictive finite contact")
        slots.append(contact["native_index"])
    require(sorted(slots)==list(range(row["batch_contacts"])),"Predictive contact denominator")
    predicted=motor_torque(row["ctrl"],row["before_qvel"][6:],profile["velocity_gains"],profile["force_ranges"])
    error=float(np.max(np.abs(predicted-np.array(row["actuator_force_nm"]))))
    require(error<=c["motor_model_absolute_tolerance_nm"],"Predictive native motor-model identity")
    return error

