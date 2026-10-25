"""Prospective paired native test of the verified support-reach component."""
import copy
from pathlib import Path
import hold_horizon_task as old
import audit_support_reach_component as component
import audit_hold_horizon_closure as retained
from hold_horizon_task import ROOT,HERE,FLAGS,MODEL,DIAGNOSIS,read,sha,require,bridge,provider,controller_contract,initial_arrays,frozen_model
from causal_force_policy import make_profile as hold_profile
from support_reach_force_policy import make_profile as reach_profile
from recovery_hold_control import HoldForceController
from support_reach_control import ReachHoldController

CONTRACT=HERE/"support_reach_native_v1.json"
PARENT_CLOSURE=retained.CLOSURE
COMPONENT_CONTRACT=component.CONTRACT
COMPONENT_RESULT=HERE/"support_reach_component_result_v1.json"
SOURCES=("support_reach_native_task.py","support_reach_native_trial.py","support_reach_native.py",
    "support_reach_native_trial_audit.py","audit_support_reach_native.py","run_support_reach_native.py","test_support_reach_native.py")
GATES=(*old.GATES,*component.GATES,("reach-route","test_support_reach_native",14))
EXPECTED_CONTROLS=sum(n for _,_,n in GATES)+3


def expected_declaration():
    c=copy.deepcopy(old.declaration())
    c.update(schema_version="locolemotion_support_reach_native_contract_v1",
        ledger_scope=dict(subsystem="adaptation",engine_scope="mujoco_cpu",authority_mode="support_reach_development_route",question_class="development"),
        lane="support_reach_native",roles=["force_hold","reach_hold"],planned_cpu_worlds=4,planned_gpu_worlds=0,
        parent_closure_sha256=sha(PARENT_CLOSURE),parent_native_closure_sha256=sha(PARENT_CLOSURE),
        parent_native_contract_sha256=sha(old.CONTRACT),component_contract_sha256=sha(COMPONENT_CONTRACT),
        component_result_sha256=sha(COMPONENT_RESULT),reference_parameters=component.declaration()["reference_parameters"],
        candidate="bounded lowering-only COM reference and airborne-leg extension; existing force allocator and resolver",
        pair_comparison=dict(prefix_commands=60,prefix_internal_steps=300,prepared_handoff_identical=True,
            post_handoff="fresh causal trajectories; no equality requirement",
            fresh_baseline_regression="all 1440 controller rows and 7200 trace rows match retained hold per group"),
        production_entrypoints=dict(worker="sdk/discovery/support_reach_native.py:run",
            native_trial="sdk/discovery/support_reach_native_trial.py:run_hold_trial",
            candidate="sdk/discovery/support_reach_control.py:ReachHoldController",
            reference="sdk/discovery/recovery_hold_control.py:HoldForceController",
            trial_reader="sdk/discovery/support_reach_native_trial_audit.py:audit_trial",
            resolver="resolve_adaptation_v1",stepping="mj_step1 then held inputs then mj_step2"),
        coverage=["fresh role-specific profile/controller construction","exact first60/300 paired prefix",
            "complete fresh baseline reproduction","actual causal resolved history",
            "full twelve-second trace/contact capture and independent replay","bounded reference and unchanged actuation caps"],
        code_path_risks_covered=["profile/role crossing","reference memory and clock","geometry joined to current native observation",
            "terminal provider failure prevents transfer","fresh independent worlds","source/runtime drift and complete capture"],
        code_path_risks_not_covered=["held-out starts or bodies","learned capability","collision-free path guarantee",
            "dynamic feasibility certificate","rough terrain/noise/delay","cross-engine equivalence","Tier3 learning","safe-backup qualification"],
        synthetic_clock_check=component.declaration()["observation_source"],
        planning_geometry=dict(component_result_sha256=sha(COMPONENT_RESULT),body_pose_held_fixed=True,dynamic_feasibility_established=False),
        minimum_free_storage_bytes=24*2**30,maximum_worker_wall_seconds=900,maximum_reader_wall_seconds=900,
        safety_controls=[dict(name=n,module=m,count=k) for n,m,k in GATES],complete_safety_control_count=EXPECTED_CONTROLS,
        implementation_bindings={n:sha(HERE/n) for n in SOURCES},
        inherited_source_bindings={n:sha(HERE/n) for n in (*component.SOURCES,"recovery_hold_control.py","recovery_hold_composition.py",
            "causal_force_policy.py","causal_force_allocator.py","actuation_recovery_mechanics.py")})
    return c


def declaration():
    c=read(CONTRACT);require(c==expected_declaration(),"Reach route exact declaration/source bindings");return c


def plans(c):
    require(c["roles"]==["force_hold","reach_hold"] and c["groups"]==["left_075_train_001","nominal_train_001"]
        and c["outer_steps"]==1440 and c["horizon_s"]==12. and c["planned_cpu_worlds"]==4,"Reach route exact exposed scope")
    return [dict(p,role=role,trial_id=role+"_"+p["group_id"],stage="support_reach_native")
        for p in old.plans(old.declaration()) for role in c["roles"]]


def profile_for(role,compiled,inputs):
    require(role in ("force_hold","reach_hold"),"Reach route unknown role")
    return (hold_profile if role=="force_hold" else reach_profile)(compiled,inputs)


def controller_for(role,core,compiled,c,model,episode,profile):
    require(role in ("force_hold","reach_hold"),"Reach route unknown role")
    kind=HoldForceController if role=="force_hold" else ReachHoldController
    return kind(core,compiled,controller_contract(c,model),model,episode,profile)


def verify_component(evidence):
    from audit_contact_force_observer_closure import validate_bindings
    from audit_residual_training_closure import verify_population
    from run_hold_horizon import inventory
    from run_residual_native import verify_tests
    result=read(COMPONENT_RESULT);contract=component.declaration();evidence=evidence.resolve(strict=True)
    identity=result["attempt_id"]
    require(isinstance(identity,str) and identity.startswith("sdk2-support-reach-component-")
        and Path(identity).name==identity and "/" not in identity and "\\" not in identity,"Reach component evidence boundary")
    attempt=(evidence/identity).resolve(strict=True)
    require(attempt.parent==evidence and result["contract_sha256"]==sha(COMPONENT_CONTRACT)
        and result["parent_closure_sha256"]==sha(PARENT_CLOSURE)
        and result["controls_passed"]==18 and result["commands"]==2880 and result["core_reconstructions"]==2
        and result["world_build_count"]==result["solver_steps"]==0
        and all(result[k] is False for k in component.DENIALS),"Reach component scope/authority")
    for key,name in (("receipt_sha256","receipt.json"),("declaration_sha256","declaration.json"),
        ("audit_sha256","audit.json"),("reconstruction_sha256","reconstruction.json")):
        require(result[key]==sha(attempt/name),"Reach component artifact digest")
    receipt=read(attempt/"receipt.json");declared=read(attempt/"declaration.json");audit=read(attempt/"audit.json")
    require(receipt["ok"] is True and receipt["source_runtime_unchanged"] is True
        and receipt["controls_passed"]==18 and receipt["worlds_opened"]==receipt["solver_steps"]==0
        and declared["source_commit"]==receipt["source_commit"]==result["source_commit"]
        and declared["contract"]==receipt["contract"]==contract
        and len(declared["binding"]["source"])==result["source_binding_count"]
        and len(declared["binding"]["runtime"])==result["runtime_binding_count"]
        and result["streams"]==audit["streams"] and audit["commands"]==2880 and audit["core_reconstructions"]==2
        and audit==read(attempt/"reconstruction.json") and audit["ok"] is True
        and audit["parent_reconstruction_verified"] is True and audit["world_build_count"]==audit["solver_steps"]==0,
        "Reach complete component evidence")
    verify_population(receipt["artifacts"],inventory(attempt));validate_bindings(declared["binding"])
    verify_tests(attempt/"reach-controls",18)
    return dict(ok=True,component_result_sha256=sha(COMPONENT_RESULT),complete_artifact_population_verified=True,
        source_binding_count=len(declared["binding"]["source"]),runtime_binding_count=len(declared["binding"]["runtime"]),
        original_commands=2880,original_core_reconstructions=2,world_build_count=0,solver_steps=0)


def validate_launch_documents(owner,gate,consumed,c,source,attempt_id,declaration_sha,gate_sha):
    require(owner["source_commit"]==source and owner["contract"]==c and owner["planned_trials"]==plans(c)
        and owner["source_status"]==[] and owner["component_only"] is False
        and all(owner[k] is False for k in FLAGS),"Reach route owner authority")
    require(gate["ok"] is True and gate["source_commit"]==source and gate["declaration_sha256"]==declaration_sha
        and gate["safety_controls"]=={**{n:k for n,_,k in GATES},"provider":2,"containment":1}
        and gate["preflight"]["ok"] is True and gate["preflight"]["component_evidence_verified"] is True
        and gate["preflight"]["world_build_count"]==gate["preflight"]["solver_steps"]==0,"Reach complete launch gate")
    require(consumed==dict(attempt_id=attempt_id,source_commit=source,contract_sha256=sha(CONTRACT),
        declaration_sha256=declaration_sha,gate_receipt_sha256=gate_sha,trials=plans(c)),"Reach single-use claim")


def launch_records(folder,c,source):
    attempt=folder.parent
    require(folder.name=="physical" and attempt.name.startswith("sdk2-support-reach-native-")
        and attempt.parent.resolve()==(ROOT.parent/"SporeSpore_Evidence").resolve(),"Reach durable output boundary")
    owner,gate,consumed=[read(attempt/n) for n in ("declaration.json","gate-receipt.json","consumed.json")]
    validate_launch_documents(owner,gate,consumed,c,source,attempt.name,sha(attempt/"declaration.json"),sha(attempt/"gate-receipt.json"))
    return owner
