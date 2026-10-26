"""Reconstruct conditional sequence search and recorded-action forecast errors."""
import argparse
import copy
from contextlib import ExitStack
import json
from pathlib import Path
import time
from unittest.mock import patch
import mujoco
import numpy as np
from predictive_sequence_task_v1 import (ROOT,EVIDENCE,CONTRACT,FOLDER,STARTS,END_COMMAND,FLAGS,
    DLL,DLL_SHA,read,sha,require,declaration,verify_parent,inputs)
from predictive_sequence_v1 import search,evaluate,commands,rank
from prepared_predictive_model import PreparedSelector,canonical_packet
from predictive_command_selection_v2 import PredictiveSelector,guard
from audit_predictive_numeric_backend import compare
from audit_gpu_batch_execution import same_bits
from gpu_measurement_probe import write_new


class Capture:
    def __init__(self,folder,c):
        self.folder=folder;self.c=c;self.bytes=0;self.rows=0
    def append(self,stream,value):
        data=(json.dumps(value,allow_nan=False,separators=(",",":"))+"\n").encode("utf-8")
        require(len(data)<=self.c["maximum_capture_row_bytes"],"Sequence capture row bound")
        require(self.bytes+len(data)<=self.c["maximum_capture_bytes"],"Sequence total capture bound")
        stream.write(data);self.bytes+=len(data);self.rows+=1
    def write(self,name,value):
        path=self.folder/name
        with path.open("xb") as stream:self.append(stream,value)
        return dict(path=name,sha256=sha(path))


def packet(row,profile):
    old=row["force_reference"]["decision"]["starting_packet"]
    command={k:v for k,v in old.items() if k not in ("qpos","qvel")}
    value=canonical_packet(row["request"]["state"],command,
        [j["joint_id"] for j in profile["prepared_model"]["morphology_spec"]["joints"]])
    require(same_bits(value,old),"Sequence exact canonical starting observation")
    require(max(abs(a-b) for k in ("qpos","qvel") for a,b in
        zip(value[k],row["native_observation"][k],strict=True))<=1e-12,"Sequence native/canonical state join")
    return value


def forecast_recorded(selector,value,targets):
    """Retrospective calibration only: no intermediate measured state reset."""
    q=list(value["qpos"]);v=list(value["qvel"]);rows=[]
    for offset,target in enumerate(targets):
        forecast=selector.rollout.predict(dict(qpos=q,qvel=v,target_velocity=target))
        rows.append(dict(offset=offset,target=target,forecast=forecast,guard_reasons=guard(forecast,selector.limits)))
        if not forecast["accepted"]:break
        q=forecast["final_qpos"];v=forecast["final_qvel"]
    return dict(completed=len(rows)==len(targets) and all(r["forecast"]["accepted"] for r in rows),
        planned_intervals=len(targets),rows=rows,initial_state_only=True,
        intermediate_native_observations_used=False,future_recorded_actions_used=True,
        retrospective_diagnostic_only=True,policy_selection_authority=False)


def native_errors(forecast,trace,start,targets):
    maximum=dict(base_position_m=0.,quaternion_component=0.,joint_position_rad=0.,
        base_linear_velocity_m_s=0.,body_angular_velocity_rad_s=0.,joint_velocity_rad_s=0.)
    checked=0;events=[]
    for block in forecast["rows"]:
        offset=block["offset"]
        if block["guard_reasons"]:events.append(dict(command=start+offset,reasons=block["guard_reasons"]))
        for row in block["forecast"]["rows"]:
            if "qpos" not in row:continue
            internal=5*(start+offset)+row["step"]+1;raw=trace[internal-1]
            require(raw["step"]==internal and raw["ctrl"]==targets[offset],"Sequence calibration applied action/clock")
            for key,field,lo,hi in (("base_position_m","qpos",0,3),("quaternion_component","qpos",3,7),
                ("joint_position_rad","qpos",7,15),("base_linear_velocity_m_s","qvel",0,3),
                ("body_angular_velocity_rad_s","qvel",3,6),("joint_velocity_rad_s","qvel",6,14)):
                maximum[key]=max(maximum[key],max(abs(a-b) for a,b in zip(row[field][lo:hi],raw[field][lo:hi],strict=True)))
            checked+=1
    return dict(compared_native_steps=checked,maximum_errors=maximum,forecast_guard_events=events,
        errors_are_diagnostic_only=True,physical_prediction_accuracy_qualified=False)


def verify_sequence(result,value,knots,intervals,selector):
    corrections,targets=commands(value,knots,intervals)
    previous_q=value["qpos"];previous_v=value["qvel"];good=0;completed=0;cost=0.
    require(1<=len(result["rows"])<=intervals,"Sequence retained interval denominator")
    for offset,block in enumerate(result["rows"]):
        forecast=block["forecast"]
        require(block["offset"]==offset and block["correction"]==corrections[offset]
            and block["target"]==targets[offset] and forecast["held_target"]==targets[offset],
            "Sequence retained projection")
        first=forecast["rows"][0]
        require(same_bits(first["before_qpos"],previous_q) and same_bits(first["before_qvel"],previous_v),
            "Sequence forecast continuity")
        reasons=guard(forecast,selector.limits)
        require(reasons==block["guard_reasons"],"Sequence unchanged retained guard")
        objective=selector.cost(forecast,value) if forecast["accepted"] else None
        require(same_bits(objective,block["objective"]),"Sequence retained objective")
        if objective is not None:cost+=objective["total"]
        completed+=forecast["completed_steps"]
        if reasons:require(offset==len(result["rows"])-1,"Sequence continued after inadmissible interval")
        else:
            good+=1;previous_q=forecast["final_qpos"];previous_v=forecast["final_qvel"]
    require((good==intervals or bool(result["rows"][-1]["guard_reasons"]))
        and result["eligible"]==(good==intervals) and result["valid_intervals"]==good
        and result["planned_intervals"]==intervals and result["attempted_intervals"]==len(result["rows"])
        and result["completed_predicted_steps"]==completed,"Sequence complete or refused population")
    expected=cost/len(result["rows"]) if all(r["objective"] is not None for r in result["rows"]) else None
    require(result["mean_objective"]==expected,"Sequence aggregate objective")
    require(all(result[k] is False for k in ("future_observations_used","future_recorded_actions_used",
        "public_future_envelope_equivalence","trained","physical_acceptance_authority","release_authority"))
        and result["native_worlds"]==result["native_physics_steps"]==0,"Sequence forbidden authority")


def audit(capture_folder,timings):
    c=declaration();parent=verify_parent();rows,trace,profile,xml=inputs();capture=Capture(capture_folder,c)
    searches=[];calibrations=[]
    with ExitStack() as guards:
        for name in ("MjModel","MjData","mj_step","mj_step1","mj_step2","mj_forward","mj_collision"):
            guards.enter_context(patch.object(mujoco,name,side_effect=AssertionError("Sequence opens no native world")))
        reference=PredictiveSelector(profile["nominal_profile"],xml)
        for name in ("fromstring","parse"):
            guards.enter_context(patch("xml.etree.ElementTree."+name,side_effect=AssertionError("Sequence runtime reads no XML")))
        model=PreparedSelector(profile["prepared_model"],DLL,DLL_SHA)
        for start in STARTS:
            value=packet(rows[start],profile);before=copy.deepcopy(value);intervals=END_COMMAND-start
            if start<114:
                targets=[r["native_targets"] for r in rows[start:114]]
                began=time.perf_counter();forecast=forecast_recorded(model,value,targets)
                native=native_errors(forecast,trace,start,targets)
                checked=compare(forecast_recorded(reference,value,targets),forecast)
                artifact=capture.write(f"calibration-{start}.json",dict(starting_packet=value,targets=targets,
                    forecast=forecast,comparison=checked,native=native))
                calibrations.append(dict(start_command=start,completed=forecast["completed"],planned_intervals=len(targets),
                    comparison=checked,native=native,artifact=artifact))
                timings.append(dict(stage="calibration",start_command=start,wall_s=time.perf_counter()-began))
            began=time.perf_counter();stream_path=capture_folder/f"search-{start}.jsonl";count=0
            def retain(record):
                nonlocal count
                require(record["iteration"]==count//34 and record["option"]["index"]==count%34,
                    "Sequence complete candidate order")
                verify_sequence(record["result"],value,record["option"]["knots"],intervals,model)
                capture.append(stream,record);count+=1
            with stream_path.open("xb") as stream:result=search(model,value,intervals,retain)
            require(count==102 and same_bits(value,before),"Sequence complete search and immutable causal input")
            best=result["best"];ref=evaluate(reference,value,best["option"]["knots"],intervals)
            comparison=compare(ref,best["result"])
            artifact=capture.write(f"final-{start}.json",dict(result=result,reference=ref,comparison=comparison))
            searches.append(dict(start_command=start,planned_intervals=intervals,evaluations=count,
                rounds=result["rounds"],best=dict(iteration=best["iteration"],option=best["option"],
                    **{k:v for k,v in best["result"].items() if k!="rows"}),comparison=comparison,
                search_sha256=sha(stream_path),artifact=artifact))
            timings.append(dict(stage="search_and_reference",start_command=start,wall_s=time.perf_counter()-began))
            print(json.dumps(dict(start_command=start,eligible=best["result"]["eligible"],
                valid_intervals=best["result"]["valid_intervals"],planned_intervals=intervals)),flush=True)
    return dict(schema_version="locolemotion_predictive_sequence_audit_v1",ok=True,ledger_scope=c["ledger_scope"],
        contract_sha256=sha(CONTRACT),parent=parent,searches=searches,calibrations=calibrations,
        evaluations=sum(x["evaluations"] for x in searches),eligible_starting_commands=[
            x["start_command"] for x in searches if x["best"]["eligible"]],
        capture_rows=capture.rows,capture_bytes=capture.bytes,worlds_opened=0,native_physics_steps=0,
        future_baseline_assumption=c["future_baseline"],future_public_envelope_equivalence=False,
        observed_native_recovery=False,global_infeasibility_established=False,**{k:False for k in FLAGS})


def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument("--core",type=Path,required=True)
    p.add_argument("--baseline-core",type=Path,required=True);p.add_argument("--output",type=Path,required=True)
    args=p.parse_args();folder=args.output.with_name(args.output.stem+"-capture");folder.mkdir();timings=[]
    result=audit(folder,timings);write_new(args.output,result)
    write_new(args.output.with_name(args.output.stem+"-timing.json"),dict(rows=timings,real_time_qualified=False))
    print(json.dumps(dict(ok=True,evaluations=result["evaluations"],eligible_starting_commands=result["eligible_starting_commands"])))
    return 0


if __name__=="__main__":raise SystemExit(main())

