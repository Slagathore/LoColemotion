"""Prospective paired native test of bounded contact-constrained posture."""
import copy
from pathlib import Path
import support_reach_native_task as old
import audit_contact_posture_component as component
import audit_support_reach_native_closure as retained
from hold_horizon_task import ROOT,HERE,FLAGS,MODEL,DIAGNOSIS,read,sha,require,bridge,provider,controller_contract,initial_arrays,frozen_model
from support_reach_force_policy import make_profile as hold_profile
from contact_posture_force_policy import make_profile as reach_profile
from support_reach_control import ReachHoldController as BaselineController
from contact_posture_control import ContactPostureController

CONTRACT=HERE/"contact_posture_native_v1.json"
PARENT_CLOSURE=retained.CLOSURE
COMPONENT_CONTRACT=component.CONTRACT
COMPONENT_RESULT=HERE/"contact_posture_component_result_v1.json"
DIAGNOSIS=HERE/"reach_tracking_diagnostic_result_v1.json"
SOURCES=("contact_posture_native_task.py","contact_posture_native_trial.py","contact_posture_native.py",
    "contact_posture_native_trial_audit.py","audit_contact_posture_native.py","run_contact_posture_native.py","test_contact_posture_native.py")
GATES=(*old.GATES,*(gate for gate in component.GATES if gate[1] not in {g[1] for g in old.GATES}),("posture-route","test_contact_posture_native",17))
EXPECTED_CONTROLS=sum(n for _,_,n in GATES)+3


def expected_declaration():
    c=copy.deepcopy(old.declaration())
    c.update(schema_version="locolemotion_contact_posture_native_contract_v1",
        ledger_scope=dict(subsystem="adaptation",engine_scope="mujoco_cpu",authority_mode="contact_posture_development_route",question_class="development"),
        lane="contact_posture_native",roles=["reach_hold","posture_hold"],planned_cpu_worlds=4,planned_gpu_worlds=0,
        parent_closure_sha256=sha(PARENT_CLOSURE),parent_native_closure_sha256=sha(PARENT_CLOSURE),
        parent_native_contract_sha256=sha(old.CONTRACT),component_contract_sha256=sha(COMPONENT_CONTRACT),
        component_result_sha256=sha(COMPONENT_RESULT),reference_parameters=component.declaration()["reference_parameters"],
        posture_parameters=component.declaration()["posture_parameters"],diagnosis_sha256=sha(DIAGNOSIS),
        candidate="bounded contact-nullspace posture hierarchy; unchanged reach lowering, force allocator and public resolver",
        pair_comparison=dict(prefix_commands=60,prefix_internal_steps=300,prepared_handoff_identical=True,
            post_handoff="fresh causal trajectories; no equality requirement",
            fresh_baseline_regression="all 1440 controller rows and 7200 trace rows match retained reach hold per group"),
        production_entrypoints=dict(worker="sdk/discovery/contact_posture_native.py:run",
            native_trial="sdk/discovery/contact_posture_native_trial.py:run_hold_trial",
            candidate="sdk/discovery/contact_posture_control.py:ContactPostureController",
            reference="sdk/discovery/support_reach_control.py:ReachHoldController",
            trial_reader="sdk/discovery/contact_posture_native_trial_audit.py:audit_trial",
            resolver="resolve_adaptation_v1",stepping="mj_step1 then held inputs then mj_step2"),
        coverage=["fresh role-specific profile/controller construction","exact first60/300 paired prefix",
            "complete fresh baseline reproduction","actual causal resolved history",
            "full twelve-second trace/contact capture and independent replay","bounded reference and unchanged actuation caps","native/canonical capsule geometry","posture retraction/contact witness and explicit fallbacks"],
        code_path_risks_covered=["profile/role crossing","reference memory and clock","geometry joined to current native observation","posture rank loss, bounded increments and contact backtracking",
            "terminal provider failure prevents transfer","fresh independent worlds","source/runtime drift and complete capture"],
        code_path_risks_not_covered=["held-out starts or bodies","learned capability","collision-free path guarantee",
            "dynamic feasibility certificate","rough terrain/noise/delay","cross-engine equivalence","Tier3 learning","safe-backup qualification"],
        synthetic_clock_check=component.declaration()["observation_source"],
        planning_geometry=dict(component_result_sha256=sha(COMPONENT_RESULT),reference_only=True,virtual_base_is_not_actuated=True,dynamic_feasibility_established=False),
        minimum_free_storage_bytes=24*2**30,maximum_worker_wall_seconds=900,maximum_reader_wall_seconds=900,
        safety_controls=[dict(name=n,module=m,count=k) for n,m,k in GATES],complete_safety_control_count=EXPECTED_CONTROLS,
        implementation_bindings={n:sha(HERE/n) for n in SOURCES},
        inherited_source_bindings={n:sha(HERE/n) for n in (*component.SOURCES,"recovery_hold_control.py","recovery_hold_composition.py",
            "causal_force_policy.py","causal_force_allocator.py","actuation_recovery_mechanics.py")})
    return c


def declaration():
    c=read(CONTRACT);require(c==expected_declaration(),"Posture route exact declaration/source bindings");return c


def plans(c):
    require(c["roles"]==["reach_hold","posture_hold"] and c["groups"]==["left_075_train_001","nominal_train_001"]
        and c["outer_steps"]==1440 and c["horizon_s"]==12. and c["planned_cpu_worlds"]==4,"Posture route exact exposed scope")
    return [dict(p,role=role,trial_id=role+"_"+p["group_id"],stage="contact_posture_native")
        for p in old.plans(old.declaration()) if p["role"]=="reach_hold" for role in c["roles"]]


def profile_for(role,compiled,inputs):
    require(role in ("reach_hold","posture_hold"),"Posture route unknown role")
    return (hold_profile if role=="reach_hold" else reach_profile)(compiled,inputs)


def controller_for(role,core,compiled,c,model,episode,profile):
    require(role in ("reach_hold","posture_hold"),"Posture route unknown role")
    kind=BaselineController if role=="reach_hold" else ContactPostureController
    return kind(core,compiled,controller_contract(c,model),model,episode,profile)


def verify_component(evidence):
    from audit_contact_force_observer_closure import validate_bindings
    from audit_residual_training_closure import verify_population
    from run_hold_horizon import inventory
    from run_residual_native import verify_tests
    result=read(COMPONENT_RESULT);contract=component.declaration();evidence=evidence.resolve(strict=True)
    identity=result["attempt_id"]
    require(isinstance(identity,str) and identity.startswith("sdk2-contact-posture-component-")
        and Path(identity).name==identity and "/" not in identity and "\\" not in identity,"Posture component evidence boundary")
    attempt=(evidence/identity).resolve(strict=True)
    require(attempt.parent==evidence and result["contract_sha256"]==sha(COMPONENT_CONTRACT)
        and result["parent_closure_sha256"]==sha(PARENT_CLOSURE)
        and result["schema_version"]=="locolemotion_contact_posture_component_result_v1"
        and result["status"]=="bounded_contact_posture_and_synthetic_integration_verified"
        and result["ledger_scope"]==contract["ledger_scope"] and result["complete_reader_invocations"]==2
        and result["controls_passed"]==46 and result["commands"]==2880 and result["core_reconstructions"]==2
        and result["world_build_count"]==result["solver_steps"]==0
        and all(result[k] is False for k in component.DENIALS),"Posture component scope/authority")
    for key,name in (("receipt_sha256","receipt.json"),("declaration_sha256","declaration.json"),
        ("audit_sha256","audit.json"),("reconstruction_sha256","reconstruction.json")):
        require(result[key]==sha(attempt/name),"Posture component artifact digest")
    receipt=read(attempt/"receipt.json");declared=read(attempt/"declaration.json");audit=read(attempt/"audit.json")
    require(receipt["ok"] is True and receipt["source_runtime_unchanged"] is True
        and receipt["controls_passed"]==46 and receipt["worlds_opened"]==receipt["solver_steps"]==0
        and declared["source_commit"]==receipt["source_commit"]==result["source_commit"]
        and declared["contract"]==receipt["contract"]==contract
        and len(declared["binding"]["source"])==result["source_binding_count"]
        and len(declared["binding"]["runtime"])==result["runtime_binding_count"]
        and result["streams"]==audit["streams"] and audit["commands"]==2880 and audit["core_reconstructions"]==2
        and audit==read(attempt/"reconstruction.json") and audit["ok"] is True
        and all(audit[k] is False for k in component.DENIALS)
        and audit["parent_reconstruction_verified"] is True and audit["world_build_count"]==audit["solver_steps"]==0,
        "Reach complete component evidence")
    verify_population(receipt["artifacts"],inventory(attempt));validate_bindings(declared["binding"])
    for name,module,count in component.GATES:verify_tests(attempt/(name+"-controls"),count)
    return dict(ok=True,component_result_sha256=sha(COMPONENT_RESULT),complete_artifact_population_verified=True,
        source_binding_count=len(declared["binding"]["source"]),runtime_binding_count=len(declared["binding"]["runtime"]),
        original_commands=2880,original_core_reconstructions=2,world_build_count=0,solver_steps=0)


def validate_launch_documents(owner,gate,consumed,c,source,attempt_id,declaration_sha,gate_sha):
    require(owner["source_commit"]==source and owner["contract"]==c and owner["planned_trials"]==plans(c)
        and owner["source_status"]==[] and owner["component_only"] is False
        and all(owner[k] is False for k in FLAGS),"Posture route owner authority")
    require(gate["ok"] is True and gate["source_commit"]==source and gate["declaration_sha256"]==declaration_sha
        and gate["safety_controls"]=={**{n:k for n,_,k in GATES},"provider":2,"containment":1}
        and gate["preflight"]["ok"] is True and gate["preflight"]["component_evidence_verified"] is True
        and gate["preflight"]["world_build_count"]==gate["preflight"]["solver_steps"]==0,"Reach complete launch gate")
    require(consumed==dict(attempt_id=attempt_id,source_commit=source,contract_sha256=sha(CONTRACT),
        declaration_sha256=declaration_sha,gate_receipt_sha256=gate_sha,trials=plans(c)),"Reach single-use claim")


def launch_records(folder,c,source):
    attempt=folder.parent
    require(folder.name=="physical" and attempt.name.startswith("sdk2-contact-posture-native-")
        and attempt.parent.resolve()==(ROOT.parent/"SporeSpore_Evidence").resolve(),"Reach durable output boundary")
    owner,gate,consumed=[read(attempt/n) for n in ("declaration.json","gate-receipt.json","consumed.json")]
    validate_launch_documents(owner,gate,consumed,c,source,attempt.name,sha(attempt/"declaration.json"),sha(attempt/"gate-receipt.json"))
    return owner
