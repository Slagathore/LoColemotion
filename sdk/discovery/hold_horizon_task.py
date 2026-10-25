"""Prospective 12-second horizon extension of the unchanged hold controller."""
import copy
import xml.etree.ElementTree as ET
import numpy as np
import recovery_hold_native_task as old
import audit_recovery_hold_closure as retained
from recovery_hold_native_task import ROOT,HERE,FLAGS,MODEL,DIAGNOSIS,COMPONENT_CONTRACT,COMPONENT_RESULT,read,sha,require,bridge,provider,controller_contract,initial_arrays,frozen_model,controller_for
from audit_gpu_batch_execution import read_jsonl

CONTRACT=HERE/"hold_horizon_v1.json"
PARENT_CLOSURE=retained.CLOSURE
SOURCES=("hold_horizon_task.py","hold_horizon_native.py","audit_hold_horizon.py","run_hold_horizon.py","test_hold_horizon.py")
GATES=(*old.GATES,("hold-closure","test_recovery_hold_closure",12),("hold-horizon","test_hold_horizon",14))
EXPECTED_CONTROLS=sum(n for _,_,n in GATES)+3
HORIZON=1440


def expected_declaration():
    c=copy.deepcopy(old.declaration())
    c.update(schema_version="locolemotion_hold_horizon_contract_v1",
        ledger_scope=dict(subsystem="adaptation",engine_scope="mujoco_cpu",authority_mode="hold_horizon_development_route",question_class="development"),
        lane="hold_horizon",roles=["force_hold"],outer_steps=HORIZON,horizon_s=12.0,
        planned_cpu_worlds=2,planned_gpu_worlds=0,parent_closure_sha256=sha(PARENT_CLOSURE),
        parent_native_contract_sha256=sha(old.CONTRACT),parent_native_closure_sha256=sha(PARENT_CLOSURE),
        diagnosis_sha256=sha(DIAGNOSIS),maximum_trace_bytes_per_trial=2**30,minimum_free_storage_bytes=12*2**30,
        maximum_worker_wall_seconds=600,maximum_reader_wall_seconds=600,
        pair_comparison=dict(kind="fresh_long_trajectory_vs_retained_same_controller_prefix",
            prefix_commands=120,prefix_internal_steps=600,
            comparison="complete controller and native trace fields bitwise equal for original first second",
            after_prefix="new causal trajectory; no continuation from cached physical state"),
        production_entrypoints=dict(worker="sdk/discovery/hold_horizon_native.py:run",
            native_trial="sdk/discovery/recovery_hold_native.py:run_hold_trial",
            controller="sdk/discovery/recovery_hold_control.py:HoldForceController",
            trial_reader="sdk/discovery/recovery_hold_native_trial_audit.py:audit_trial",
            resolver="resolve_adaptation_v1",stepping="mj_step1 then held inputs then mj_step2"),
        coverage=["fresh setup and complete original one-second prefix comparison",
            "unchanged controller through final supported command 1439; refusal at 1440",
            "actual provider memory and resolved history across the complete horizon",
            "complete native trace, all rigid contacts and other-core replay",
            "larger retained streams with bounded per-stream size",
            "original full-horizon thresholds; failed and horizon-censored outcomes retained"],
        code_path_risks_covered=["extended clock and memory sequence","native/refusal/containment paths",
            "complete long-horizon denominators","unchanged first-second behavior",
            "force and geometry clock join","retained capsule-plane geometry"],
        code_path_risks_not_covered=["learned capability","held-out starts/bodies","noise/delay/rough terrain",
            "cross-engine equivalence","statistical superiority","Tier3 learning","safe backup qualification"],
        synthetic_clock_check=dict(commands_per_core=1440,cores=2,
            later_observation_source="held original final prepared state with advanced declared clock",
            observations_generated_by_alternative_actions=False,physical_acceptance_authority=False),
        planning_geometry=dict(source="parent force-hold controller rows 59 and 119 plus exact model XML",
            method="capsule lowest surface z from body pose, endpoints and radius; ground plane z=0",
            dynamic_reachability_established=False),
        safety_controls=[dict(name=n,module=m,count=k) for n,m,k in GATES],
        complete_safety_control_count=EXPECTED_CONTROLS,
        implementation_bindings={n:sha(HERE/n) for n in SOURCES},
        inherited_source_bindings={n:sha(HERE/n) for n in ("recovery_hold_native.py","recovery_hold_native_trial_audit.py",
            "recovery_hold_control.py","recovery_hold_composition.py","causal_force_policy.py","causal_force_allocator.py")})
    return c


def declaration():
    c=read(CONTRACT);require(c==expected_declaration(),"Hold horizon exact declaration/source bindings");return c


def plans(c):
    require(c["roles"]==["force_hold"] and c["groups"]==["left_075_train_001","nominal_train_001"]
        and c["outer_steps"]==1440 and c["horizon_s"]==12.0 and c["planned_cpu_worlds"]==2,
        "Hold horizon exact exposed scope")
    return [dict(p,stage="hold_horizon") for p in old.plans(old.declaration()) if p["role"]=="force_hold"]


def validate_launch_documents(owner,gate,consumed,c,source,attempt_id,declaration_sha,gate_sha):
    require(owner["source_commit"]==source and owner["contract"]==c and owner["planned_trials"]==plans(c)
        and owner["source_status"]==[] and owner["component_only"] is False
        and all(owner[k] is False for k in FLAGS),"Hold horizon owner authority")
    require(gate["ok"] is True and gate["source_commit"]==source and gate["declaration_sha256"]==declaration_sha
        and gate["safety_controls"]=={**{n:k for n,_,k in GATES},"provider":2,"containment":1}
        and gate["preflight"]["ok"] is True and gate["preflight"]["parent_reconstruction_verified"] is True
        and gate["preflight"]["world_build_count"]==gate["preflight"]["solver_steps"]==0,
        "Hold horizon complete launch gate")
    require(consumed==dict(attempt_id=attempt_id,source_commit=source,contract_sha256=sha(CONTRACT),
        declaration_sha256=declaration_sha,gate_receipt_sha256=gate_sha,trials=plans(c)),"Hold horizon single-use claim")


def launch_records(folder,c,source):
    attempt=folder.parent
    require(folder.name=="physical" and attempt.name.startswith("sdk2-hold-horizon-")
        and attempt.parent.resolve()==(ROOT.parent/"SporeSpore_Evidence").resolve(),"Hold horizon durable boundary")
    owner,gate,consumed=[read(attempt/n) for n in ("declaration.json","gate-receipt.json","consumed.json")]
    validate_launch_documents(owner,gate,consumed,c,source,attempt.name,sha(attempt/"declaration.json"),sha(attempt/"gate-receipt.json"))
    return owner


def capsule_clearance(position,rotation,endpoints,radius):
    position=np.asarray(position,dtype=float);rotation=np.asarray(rotation,dtype=float);endpoints=np.asarray(endpoints,dtype=float)
    require(position.shape==(3,) and rotation.size==9 and endpoints.size==6
        and np.isfinite(position).all() and np.isfinite(rotation).all() and np.isfinite(endpoints).all()
        and np.isfinite(radius) and radius>0,"Hold capsule geometry")
    rotation=rotation.reshape(3,3);endpoints=endpoints.reshape(2,3)
    require(np.allclose(rotation.T @ rotation,np.eye(3),rtol=0,atol=1e-9)
        and abs(np.linalg.det(rotation)-1.)<1e-9,"Hold capsule body rotation")
    world=position+endpoints @ rotation.T
    return float(world[:,2].min()-radius)


def retained_geometry(attempt):
    output=[]
    for condition in ("left_075","nominal"):
        folder=attempt/"physical"/("force_hold_"+condition+"_train_001")
        rows=list(read_jsonl(folder/"controller.jsonl"));metadata=read(folder/"native-model.json")
        xml=ET.fromstring((folder/"model.xml").read_text(encoding="utf-8"))
        ground=xml.find("./worldbody/geom[@name='ground']")
        require(ground.get("type")=="plane" and ground.get("pos") is None and ground.get("quat") is None,"Hold geometry ground frame")
        samples=[]
        for step in (59,119):
            row=rows[step];native=row["native_observation"];feet={}
            for limb in ("front_left","front_right","rear_left","rear_right"):
                body=limb+"_distal";index=metadata["ordered_bodies"].index(body)
                geom=xml.find(".//body[@name='"+body+"']/geom");require(geom.get("type")=="capsule","Hold capsule type")
                feet[limb]=dict(lowest_surface_height_m=capsule_clearance(native["xpos"][index],native["xmat"][index],
                    [float(v) for v in geom.get("fromto").split()],float(geom.get("size").split()[0])),
                    bears_support=next(x["bears_support"] for x in row["request"]["state"]["ordered_contact_observations"] if x["contact_site_id"]==limb+"_foot"))
            samples.append(dict(command=step,time_s=native["time_s"],feet=feet))
        output.append(dict(condition_id=condition,controller_sha256=sha(folder/"controller.jsonl"),
            model_xml_sha256=sha(folder/"model.xml"),prepared_geometry=samples,dynamic_reachability_established=False))
    return output
