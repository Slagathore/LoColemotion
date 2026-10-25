"""Prospective finite native inertia/bias readback contract and launch gates."""
import hashlib,importlib.metadata,itertools,json
from pathlib import Path
import numpy as np
import floating_base_dynamics_audit as component
from contact_force_observer_task import ROOT,HERE,read,sha,require
from audit_contact_force_observer_closure import validate_bindings
from audit_residual_training_closure import verify_population
from run_floating_base_dynamics import inventory
from run_residual_native import verify_tests
from audit_gpu_batch_execution import read_jsonl
from floating_base_dynamics_inputs import native_parameters
from floating_dynamics_oracle_math import canonical_state
from floating_base_dynamics import FloatingDynamics

CONTRACT=HERE/"floating_dynamics_oracle_v1.json"
RESULT=HERE/"floating_base_dynamics_result_v1.json"
RESULT_SHA="a51438260dabc1c422c3fe26c334c60aaaa8b94c3a311e785c7c1e29a49a5ec7"
SOURCES=("floating_dynamics_oracle_math.py","floating_dynamics_oracle_task.py",
    "floating_dynamics_oracle.py","audit_floating_dynamics_oracle.py",
    "test_floating_dynamics_oracle.py","run_floating_dynamics_oracle.py")
GATES=(*component.GATES,("oracle","test_floating_dynamics_oracle",26))
CONTROL_COUNT=83
FLAGS=("controller_changed","dynamic_feasibility_established","held_contact_guaranteed",
    "recovery_benefit_established","tier2_qualified","tier3_benefit_established",
    "physical_acceptance_authority","training_data_authority","release_authority","equivalence_authority")
EVIDENCE=ROOT.parent/"SporeSpore_Evidence"
INPUT_ROOT=EVIDENCE/component.NATIVE_ATTEMPT/"physical"


def expected_contract():
    return dict(schema_version="locolemotion_floating_dynamics_oracle_contract_v1",
        ledger_scope=dict(subsystem="adaptation",engine_scope="mujoco_cpu",
            authority_mode="finite_native_dynamics_readback",question_class="development"),
        source_bindings={n:sha(HERE/n) for n in SOURCES},
        component_result_sha256=RESULT_SHA,
        input_sha256={t+"/"+n:sha(INPUT_ROOT/t/n) for t in component.TRIALS
            for n in ("model.xml","force-profile.json","controller.jsonl")},
        runtime={"mujoco":"3.11.0","numpy":"2.4.6"},trials=list(component.TRIALS),
        commands_start=60,commands_end_exclusive=126,states_per_trial=66,states=132,
        planned_models=2,planned_cpu_worlds=2,planned_gpu_worlds=0,solver_steps=0,
        position_evaluations=264,velocity_evaluations=264,dense_mass_readbacks=132,
        assigned_state_times_are_retained_not_integrated=True,new_trajectory_generated=False,
        seed=104242001,source_start_id="train_001",state_selection="retained post-handoff commands 60 through 125",
        controls_required=CONTROL_COUNT,safety_controls=[dict(name=n,module=m,count=k) for n,m,k in GATES],
        containment_controls=1,absolute_tolerance=1e-9,relative_tolerance=1e-9,
        generalized_order="root world linear; root world angular; ordered revolute joints",
        synthetic_acceleration=np.linspace(-.2,.3,14).tolist(),
        maximum_worker_wall_seconds=120,maximum_reader_wall_seconds=120,minimum_free_storage_bytes=100000000,
        allowed_native_calls=["MjModel.from_xml_string","MjData","mj_resetData","mj_fwdPosition","mj_fwdVelocity","mj_fullM"],
        forbidden_native_calls=["mj_step","mj_step1","mj_step2","mj_forward","mj_inverse","mj_integratePos"],
        risks_covered=["source/runtime/input binding","job containment","fresh single-use identity",
            "partial construction accounting","native/world coordinates","native armature and damping",
            "state/time immutability","complete finite population","readback corruption"],
        exclusions=["native trajectory","contact force accuracy","controller integration","recovery",
            "arbitrary morphology","cross-engine equivalence","release qualification"],
        **{k:False for k in FLAGS})


def declaration():
    c=read(CONTRACT);require(c==expected_contract(),"Oracle exact prospective declaration");return c


def verify_component():
    require(sha(RESULT)==RESULT_SHA,"Oracle component result identity")
    result=read(RESULT);folder=EVIDENCE/result["attempt_id"]
    require(folder.parent==EVIDENCE and folder.name.startswith("sdk2-floating-base-dynamics-"),"Oracle component boundary")
    receipt=read(folder/"receipt.json");declared=read(folder/"declaration.json")
    for key,name in (("receipt_sha256","receipt.json"),("declaration_sha256","declaration.json"),
        ("audit_sha256","audit.json"),("reconstruction_sha256","reconstruction.json")):
        require(result[key]==sha(folder/name),"Oracle component artifact identity")
    audit=read(folder/"audit.json")
    require(receipt["ok"] is True and receipt["source_runtime_unchanged"] is True
        and receipt["controls_passed"]==result["controls_passed"]==56
        and receipt["worlds_opened"]==receipt["solver_steps"]==0
        and declared["contract"]==receipt["contract"]==component.declaration()
        and len(declared["binding"]["source"])==receipt["source_binding_count"]==714
        and len(declared["binding"]["runtime"])==receipt["runtime_binding_count"]==1359
        and audit==read(folder/"reconstruction.json") and audit["trials"]==result["trials"]
        and audit["ok"] is True and audit["frames"]==132 and audit["body_observations"]==1188
        and all(audit[k] is False for k in component.DENIALS),"Oracle complete parent component")
    verify_population(receipt["artifacts"],inventory(folder));validate_bindings(declared["binding"])
    for name,_,count in component.GATES:verify_tests(folder/(name+"-controls"),count)
    return audit


def inputs(c):
    require(c["input_sha256"]==expected_contract()["input_sha256"],"Oracle retained input identities")
    result=[]
    for trial in c["trials"]:
        folder=INPUT_ROOT/trial;profile=read(folder/"force-profile.json");xml=(folder/"model.xml").read_text()
        parameters=native_parameters(xml,profile["morphology_spec"])
        require(parameters["joint_inertia_kg_m2"]==[.01]*8 and parameters["passive_damping_nms_per_rad"]==[0.]*8,
            "Oracle explicit inertia/damping")
        rows=list(itertools.islice(read_jsonl(folder/"controller.jsonl"),60,126))
        require(len(rows)==66 and [r["outer_step"] for r in rows]==list(range(60,126))
            and [r["request"]["state"]["semantic_step"] for r in rows]==list(range(60,126)),
            "Oracle exact retained state population")
        result.append((trial,xml,profile,rows))
    return result


def preflight():
    c=declaration()
    require({k:importlib.metadata.version(k) for k in c["runtime"]}==c["runtime"],"Oracle native runtime versions")
    from contextlib import ExitStack
    from unittest.mock import patch
    import mujoco
    with ExitStack() as guards:
        for name in ("MjModel","MjData",*c["forbidden_native_calls"],"mj_fwdPosition","mj_fwdVelocity"):
            guards.enter_context(patch.object(mujoco,name,side_effect=AssertionError("Oracle preflight opens no worlds")))
        parent=verify_component();retained={(r["trial_id"],r["command"]):r for r in parent["rows"]}
        for trial,_,profile,rows in inputs(c):
            model=FloatingDynamics(profile["morphology_spec"],[.01]*8)
            for row in rows:
                p,q,j,v,g=canonical_state(row);value=model.evaluate(p,q,j,v,c["synthetic_acceleration"],g)
                old=retained[(trial,row["outer_step"])]
                require(value["mass_matrix"].tolist()==old["mass_matrix"]
                    and value["gravity_force"].tolist()==old["checks"]["gravity_force"]
                    and value["velocity_bias"].tolist()==old["checks"]["velocity_bias"],"Oracle original portable states")
    return dict(ok=True,component_evidence_verified=True,states=132,world_build_count=0,solver_steps=0)


def validate_launch(owner,gate,consumed,c,source,attempt,declaration_sha,gate_sha):
    require(owner["source_commit"]==source and owner["contract"]==c and owner["source_status"]==[]
        and all(owner[k] is False for k in FLAGS),"Oracle clean owner/authority")
    require(gate==dict(ok=True,source_commit=source,declaration_sha256=declaration_sha,
        safety_controls={**{n:k for n,_,k in GATES},"containment":1},
        preflight=dict(ok=True,component_evidence_verified=True,states=132,world_build_count=0,solver_steps=0)),
        "Oracle complete zero-world gate")
    require(consumed==dict(attempt_id=attempt,source_commit=source,contract_sha256=sha(CONTRACT),
        declaration_sha256=declaration_sha,gate_receipt_sha256=gate_sha,trials=c["trials"]),
        "Oracle fresh consumed identity")


def launch_records(folder,c,source):
    attempt=folder.parent
    require(folder.name=="native" and attempt.name.startswith("sdk2-floating-dynamics-oracle-")
        and attempt.parent.resolve()==EVIDENCE.resolve(),"Oracle durable output boundary")
    owner,gate,consumed=[read(attempt/n) for n in ("declaration.json","gate-receipt.json","consumed.json")]
    validate_launch(owner,gate,consumed,c,source,attempt.name,sha(attempt/"declaration.json"),sha(attempt/"gate-receipt.json"))
    return owner
