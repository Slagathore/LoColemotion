"""World-free full-stream audit of contact capture and paired noninterference."""
import argparse
from contextlib import ExitStack
import json
import math
from pathlib import Path
from unittest.mock import patch

import mujoco
import numpy as np
from audit_residual_recovery import audit_trial
from audit_gpu_batch_execution import same_bits, read_jsonl
from contact_force_observer_task import (ROOT, FLAGS, declaration, plans, frozen_model, read,
    sha, require, bridge, launch_records)
from contact_force_measurement import decode_constraint, STAGE, SCHEMA, validate_frame
from gpu_measurement_probe import write_new


def expected_metadata(compiled,spec,c):
    names=["world"]+compiled["morphology"]["ordered_body_ids"]
    geoms=[dict(id=i,name=name,body_id=0 if i==0 else names.index(name.removesuffix("_geom")),
                body_name="world" if i==0 else name.removesuffix("_geom"))
           for i,name in enumerate(spec["geom_names"])]
    mapping=[dict(contact_site_id=s["contact_site_id"],body_name=s["body_id"],
                  geom_id=spec["geom_names"].index(s["body_id"]+"_geom"),geom_name=s["body_id"]+"_geom")
             for s in compiled["morphology"]["morphology_spec"]["contact_sites"]]
    # The cone is declared and checked against the bound XML during preflight.
    return dict(schema_version="locolemotion_contact_force_metadata_v1",stage=STAGE,
        geoms=geoms,site_mapping=mapping,ground_geom_id=0,cone=c["observation"]["native_cone"],timestep_s=c["timestep_s"],
        force_convention="positive_on_geom2_negative_on_geom1",torque_origin="each_contact_position",
        load_semantics="mapped_distal_geom_ground_contact_not_endpoint_force",
        canonical_rotation="x,z,-y",controller_load_fields_changed=False)


def close_values(a,b,c):
    require(len(a)==len(b) and all(type(x) in (int,float) and math.isfinite(x) for x in [*a,*b])
        and all(abs(x-y)<=c["observation"]["absolute_tolerance"]
                +c["observation"]["relative_tolerance"]*max(abs(x),abs(y)) for x,y in zip(a,b)),
        "Observer force reconstruction")


def validate_sample(row,trace,metadata,c):
    require(row["schema_version"]==SCHEMA and row["stage"]==STAGE
        and row["step"]==trace["step"] and row["integrated_time_s"]==trace["time_s"],
        "Observer sample stage/clock")
    require(all(same_bits(row[k],trace[k]) for k in ("before_qpos","before_qvel","qpos","qvel","ctrl")),
        "Observer native state join")
    require(math.isfinite(row["prepared_time_s"])
        and row["prepared_time_s"]+c["timestep_s"]==row["integrated_time_s"],
        "Observer prepared/solved clock")
    require(type(row["nefc"]) is int and row["nefc"]==trace["nefc"]
        and type(row["ncon"]) is int and row["ncon"]==trace["batch_contacts"]==len(row["contacts"])
        and len(row["efc_force"])==len(row["efc_id"])==len(row["efc_type"])==row["nefc"]
        and all(type(x) in (int,float) and math.isfinite(x) for x in row["efc_force"])
        and all(type(x) is int for x in row["efc_id"]+row["efc_type"]),
        "Observer complete contact/constraint population")
    mapped={m["contact_site_id"]:dict(m,contact_indices=[],normal_load_n=0.,force_canonical_n=[0.,0.,0.])
            for m in metadata["site_mapping"]}
    by_geom={m["geom_id"]:m["contact_site_id"] for m in metadata["site_mapping"]};other=[]
    for index,(contact,raw) in enumerate(zip(row["contacts"],trace["contacts"],strict=True)):
        require(type(contact["native_index"]) is int and contact["native_index"]==index==raw["native_index"]
            and all(same_bits(contact[k],raw[k]) for k in ("geom","distance_m","position_m","frame")),
            "Observer contact geometry join")
        validate_frame(contact["frame"])
        pair=contact["geom"]
        require(len(pair)==2 and pair[0]!=pair[1] and all(type(g) is int and 0<=g<len(metadata["geoms"]) for g in pair),
            "Observer rigid pair")
        identities=[metadata["geoms"][g] for g in pair]
        require(contact["geom_names"]==[g["name"] for g in identities]
            and contact["body_ids"]==[g["body_id"] for g in identities]
            and contact["body_names"]==[g["body_name"] for g in identities],"Observer body attribution")
        reconstructed=decode_constraint(contact,row["efc_force"],metadata["cone"])
        close_values(contact["local_force_n"]+contact["local_torque_nm"],reconstructed,c)
        address=contact["efc_address"];dim=contact["dim"]
        if address>=0:
            count=2*(dim-1) if metadata["cone"]=="pyramidal" and dim>1 else dim
            kind=5 if dim==1 else (6 if metadata["cone"]=="pyramidal" else 7)
            require(row["efc_id"][address:address+count]==[index]*count
                and row["efc_type"][address:address+count]==[kind]*count,"Observer constraint identity")
        require(type(contact["exclude"]) is int and 0<=contact["exclude"]<=4
            and all(x>=0 for x in contact["friction"]),"Observer contact constraint metadata")
        basis=np.array(contact["frame"],dtype=np.float64).reshape(3,3)
        expected={}
        for local,world,canonical in (
            ("local_force_n","force_on_geom2_world_n","force_on_geom2_canonical_n"),
            ("local_torque_nm","torque_on_geom2_world_nm","torque_on_geom2_canonical_nm")):
            transformed=basis.T @ np.asarray(contact[local],dtype=np.float64)
            value=[float(transformed[0]),float(transformed[2]),float(-transformed[1])]
            close_values(contact[world],transformed.tolist(),c);close_values(contact[canonical],value,c)
            expected[canonical]=value
        if metadata["ground_geom_id"] in pair:
            side=1-pair.index(metadata["ground_geom_id"]);site=by_geom.get(pair[side])
            if site is not None:
                load=mapped[site];load["contact_indices"].append(index)
                load["normal_load_n"]+=contact["local_force_n"][0]
                sign=1 if side==1 else -1
                load["force_canonical_n"]=[x+sign*y for x,y in
                    zip(load["force_canonical_n"],expected["force_on_geom2_canonical_n"])]
                continue
        other.append(index)
    require(row["other_contact_indices"]==other and len(row["mapped_distal_ground_loads"])==4,
        "Observer preserved other contacts/zero loads")
    for actual,expected in zip(row["mapped_distal_ground_loads"],mapped.values(),strict=True):
        require(actual.keys()==expected.keys()
            and all(actual[k]==v for k,v in expected.items() if k not in ("normal_load_n","force_canonical_n")),
            "Observer load mapping")
        close_values([actual["normal_load_n"]],[expected["normal_load_n"]],c)
        close_values(actual["force_canonical_n"],expected["force_canonical_n"],c)


def compare_pair(off,on,c):
    left=list(read_jsonl(off/"trace.jsonl"));right=list(read_jsonl(on/"trace.jsonl"))
    require(len(left)==len(right)==5*c["outer_steps"] and same_bits(left,right),
        "Observer altered native trajectory")
    a=list(read_jsonl(off/"controller.jsonl"));b=list(read_jsonl(on/"controller.jsonl"))
    require(len(a)==len(b)==c["outer_steps"],"Observer pair command population")
    for x,y in zip(a,b,strict=True):
        require(all(same_bits(x[k],y[k]) for k in c["pair_comparison"]["controller_fields"])
            and same_bits(x["request"]["state"],y["request"]["state"])
            and same_bits(x["resolution"]["ordered_commands"],y["resolution"]["ordered_commands"]),
            "Observer altered controller inputs/outputs")
    return dict(exact_native_trace_match=True,controller_inputs_and_commands_match=True,
                controller_rows=len(a),internal_rows=len(left),fresh_worlds=2)


def audit(folder,core_path,baseline_path):
    from run_contact_force_observer import bindings
    from run_gpu_measurement_probe import source_identity
    c=declaration();source=source_identity(True);owner=launch_records(folder,c,source)
    require(bindings(core_path,baseline_path)==owner["binding"],"Observer audit source/runtime binding")
    worker=read(folder/"worker-result.json");population=plans(c)
    require(worker["ok"] is True and worker["synthetic"] is False
        and worker["status"]=="complete_contact_observer_fixture"
        and worker["ledger_scope"]==c["ledger_scope"] and all(worker[k] is False for k in FLAGS)
        and worker["constructed_cpu_worlds"]==worker["constructed_model_count"]==4
        and worker["constructed_gpu_worlds"]==0 and len(worker["trials"])==4,"Observer worker population/authority")
    trials=[];contact_rows=0
    with ExitStack() as guards:
        for name in ("MjModel","MjData","mj_step","mj_step1","mj_step2","mj_forward"):
            guards.enter_context(patch.object(mujoco,name,side_effect=AssertionError("Observer reader opens no world")))
        core=bridge.LocomotionCore(baseline_path);model=frozen_model(core)
        for plan,observed in zip(population,worker["trials"],strict=True):
            path=folder/plan["trial_id"];result=read(path/"result.json")
            require(result==observed and read(path/"world-opened.json")==dict(trial_id=plan["trial_id"],
                native_data_constructed=True,core_sha256=c["core_sha256"],provider_model_sha256=model.sha256),
                "Observer result/construction join")
            trial=audit_trial(path,plan,c,baseline_path,core,model.document())
            controls=list(read_jsonl(path/"controller.jsonl"))
            # The provider continues to receive null loads throughout this fixture.
            loads=[site["normal_load_n"] for control in controls
                   for site in control["request"]["state"]["ordered_contact_observations"]]
            require(all(load is None for load in loads),"Observer fed loads to controller")
            if plan["role"]=="observer_on":
                metadata=expected_metadata(read(path/"compiled.json"),read(path/"inputs.json"),c)
                require(read(path/"contact-metadata.json")==metadata
                    and sha(path/"contact-metadata.json")==result["contact_metadata_sha256"],"Observer metadata")
                for name in ("contact-force","contact-timing"):
                    require(sha(path/(name+".jsonl"))==result["contact_hashes"][name],"Observer raw stream digest")
                samples=list(read_jsonl(path/"contact-force.jsonl"));trace=list(read_jsonl(path/"trace.jsonl"))
                timings=list(read_jsonl(path/"contact-timing.jsonl"))
                require(len(samples)==len(trace)==len(timings)==600,"Observer full capture denominator")
                total_contacts=inactive=other_count=0;total_load=0.;timing_totals={}
                for sample,raw,timing in zip(samples,trace,timings,strict=True):
                    validate_sample(sample,raw,metadata,c);contact_rows+=1
                    require(timing["step"]==sample["step"] and set(timing)=={"step","native_prepare_s",
                        "prepare_capture_s","native_complete_s","complete_guard_s","force_capture_s","serialization_s"},
                        "Observer capture timing identity")
                    for key,value in timing.items():
                        if key=="step":continue
                        require(type(value) in (float,int) and math.isfinite(value) and value>=0,"Observer finite timing")
                        timing_totals[key]=timing_totals.get(key,0.)+value
                    total_contacts+=sample["ncon"]
                    inactive+=sum(x["efc_address"]<0 for x in sample["contacts"])
                    other_count+=len(sample["other_contact_indices"])
                    total_load+=sum(x["normal_load_n"] for x in sample["mapped_distal_ground_loads"])
                trial["contact_capture"]=dict(rows=600,contacts=total_contacts,inactive_contacts=inactive,
                    other_contacts=other_count,mean_total_distal_normal_load_n=total_load/600,
                    timing_s=timing_totals,force_reconstruction_verified=True)
            else:
                require(not any((path/name).exists() for name in
                    ("contact-force.jsonl","contact-timing.jsonl","contact-metadata.json")),
                    "Observer-off role captured contact force")
            trials.append(trial)
        pairs=[dict(group_id=group,**compare_pair(folder/("observer_off_"+group),
                    folder/("observer_on_"+group),c)) for group in c["groups"]]
    require(source_identity(True)==source and bindings(core_path,baseline_path)==owner["binding"],
            "Observer audit source/runtime drift")
    return dict(schema_version="locolemotion_contact_observer_audit_v1",ok=True,synthetic=False,
        ledger_scope=c["ledger_scope"],source_commit=source,constructed_cpu_worlds=4,constructed_gpu_worlds=0,
        controller_rows=480,internal_rows=2400,contact_rows=contact_rows,trials=trials,pairs=pairs,
        reader_world_build_count=0,reader_solver_steps=0,controller_load_fields_changed=False,
        tier2_qualified=False,tier3_benefit_established=False,**{k:False for k in FLAGS})


def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument("--folder",type=Path,required=True)
    p.add_argument("--core",type=Path,required=True);p.add_argument("--baseline-core",type=Path,required=True)
    p.add_argument("--output",type=Path,required=True);args=p.parse_args()
    value=audit(args.folder,args.core,args.baseline_core);write_new(args.output,value)
    print(json.dumps(dict(ok=True,contact_rows=value["contact_rows"],world_build_count=0,solver_steps=0)))
    return 0


if __name__=="__main__":raise SystemExit(main())
