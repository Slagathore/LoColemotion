"""Prospective exposed native comparison of verified configured contact-first hierarchy."""
import copy
from pathlib import Path
import support_reach_native_task as old
import hierarchical_contact_component_audit_v5 as component
from hierarchical_force_policy_v5 import SOLVER_RUNTIME
import audit_support_reach_native_closure as retained
from hold_horizon_task import ROOT,HERE,FLAGS,MODEL,read,sha,require,bridge,provider,controller_contract,initial_arrays,frozen_model
from support_reach_force_policy import make_profile as baseline_profile
from hierarchical_force_policy_v5 import make_profile as dynamic_profile
from support_reach_control import ReachHoldController
from hierarchical_hold_control_v5 import HierarchicalHoldController

CONTRACT=HERE/"hierarchical_native_v1.json"
PARENT_CLOSURE=retained.CLOSURE
COMPONENT_CONTRACT=component.CONTRACT
COMPONENT_RESULT=HERE/"hierarchical_contact_component_result_v5.json"
COMPONENT_SHA="8b3ae9bae872585b2a6a891620ddf96f813ed30506535473226980f379e83c45"
DIAGNOSIS=HERE/"proximal_repeatability_result_v1.json"
SOURCES=("hierarchical_native_task.py","hierarchical_native_trial.py","hierarchical_native.py",
    "hierarchical_native_trial_audit.py","audit_hierarchical_native.py","run_hierarchical_native.py","test_hierarchical_native.py","hierarchical_native_row_audit.py")
ROUTE_CONTROLS=26
GATES=(*old.GATES,*(("hierarchy-"+name,module,count) for name,module,count in component.GATES
    if module not in {g[1] for g in old.GATES}),("hierarchy-route","test_hierarchical_native",ROUTE_CONTROLS))
EXPECTED_CONTROLS=sum(n for _,_,n in GATES)+3


def expected_declaration():
    c=copy.deepcopy(old.declaration());c.pop("planning_geometry")
    c.update(schema_version="locolemotion_hierarchical_native_contract_v1",
        ledger_scope=dict(subsystem="adaptation",engine_scope="mujoco_cpu",
            authority_mode="configured_hierarchical_development_route",question_class="development"),
        lane="hierarchical_native",roles=["reach_hold","hierarchy_hold"],planned_cpu_worlds=4,planned_gpu_worlds=0,
        runtime=dict(c["runtime"],**SOLVER_RUNTIME),
        parent_closure_sha256=sha(PARENT_CLOSURE),parent_native_closure_sha256=sha(PARENT_CLOSURE),
        parent_native_contract_sha256=sha(old.CONTRACT),component_contract_sha256=sha(COMPONENT_CONTRACT),
        component_result_sha256=sha(COMPONENT_RESULT),diagnosis_sha256=sha(DIAGNOSIS),
        dynamic_parameters=component.component.parameters(),optimization_settings=component.settings(),
        candidate="generic proximal contact-first hierarchy; certified five-step held motor and joint model; unchanged public resolver",
        pair_comparison=dict(prefix_commands=60,prefix_internal_steps=300,prepared_handoff_identical=True,
            post_handoff="fresh causal trajectories; no equality requirement",
            fresh_baseline_regression="all 1440 controller rows and 7200 trace rows match retained reach hold per group"),
        comparison_endpoints=dict(primary="first physical violation under unchanged height, tilt and torso-contact rules",
            secondary=["complete twelve-second diagnostic eligibility","supporting-foot counts including pre-failure window",
                "actual motor reconstruction and held-interval change","measured control wall cost"],
            interpretation="two exposed condition-specific development pairs; no robustness or superiority qualification"),
        production_entrypoints=dict(worker="sdk/discovery/hierarchical_native.py:run",
            native_trial="sdk/discovery/hierarchical_native_trial.py:run_hold_trial",
            candidate="sdk/discovery/hierarchical_hold_control_v5.py:HierarchicalHoldController",
            reference="sdk/discovery/support_reach_control.py:ReachHoldController",
            trial_reader="sdk/discovery/hierarchical_native_trial_audit.py:audit_trial",
            resolver="resolve_adaptation_v1",stepping="mj_step1 then held inputs then mj_step2"),
        coverage=["fresh role-specific profile/controller construction","exact first60/300 paired prefix",
            "complete fresh baseline reproduction","actual causal resolved history",
            "full twelve-second native trace and contact capture","two independent other-core readers",
            "independent primary and secondary reduced/full certificates and implicit motor equation","all five predicted held motor steps","nominal and weak prefix/two-command handoff ghosts","empty supporting sets",
            "every internal motor torque and prepared versus held-interval torque change"],
        code_path_risks_covered=["profile/role crossing","reference memory and clock","native/canonical geometry",
            "controller numerical refusal prevents transfer","fresh independent worlds",
            "complete source/runtime bindings including generic ProxQP, OSQP, SciPy and cmeel","native sensor and solver-input joins"],
        code_path_risks_not_covered=["held-out starts or bodies","estimated capability","contact-model accuracy",
            "guaranteed maintained contact","rough terrain/noise/delay","cross-engine equivalence",
            "Tier3 learning","safe-backup qualification","real-time interactive performance"],
        synthetic_clock_check=component.declaration()["observation_source"],
        refusal_policy="retain terminal controller row and close before native transfer; abort remaining campaign worlds",
        retained_inputs_are_training_data=False,
        independent_selected_row_reader="sdk/discovery/hierarchical_native_row_audit.py:verify_row",
        component_handoff_scope="two weak retained roles; nominal two-core handoff added by this route gate",
        planning_dynamics=dict(component_result_sha256=sha(COMPONENT_RESULT),
            base_unactuated=True,contact_acceleration_is_highest_priority=True,optimal_attained_support_frozen_for_secondary=True,held_contact_guaranteed=False,
            dynamic_feasibility_established=False),
        motor_model_absolute_tolerance_nm=1e-10,prepared_projection_absolute_tolerance_nm=2e-6,
        minimum_free_storage_bytes=24*2**30,maximum_worker_wall_seconds=1200,maximum_reader_wall_seconds=1200,
        safety_controls=[dict(name=n,module=m,count=k) for n,m,k in GATES],complete_safety_control_count=EXPECTED_CONTROLS,
        implementation_bindings={n:sha(HERE/n) for n in SOURCES},
        inherited_source_bindings={n:sha(HERE/n) for n in (*component.SOURCES,"recovery_hold_control.py",
            "recovery_hold_composition.py","support_reach_force_policy.py","support_reach_control.py",
            "causal_force_policy.py","causal_force_allocator.py","actuation_recovery_mechanics.py")})
    require(len({n for n,_,_ in GATES})==len(GATES),"Dynamic unique gate identities")
    return c


def declaration():
    c=read(CONTRACT);require(c==expected_declaration(),"Dynamic route exact declaration/source bindings");return c


def plans(c):
    require(c["roles"]==["reach_hold","hierarchy_hold"] and c["groups"]==["left_075_train_001","nominal_train_001"]
        and c["outer_steps"]==1440 and c["horizon_s"]==12. and c["planned_cpu_worlds"]==4,"Dynamic exact exposed scope")
    return [dict(p,role=role,trial_id=role+"_"+p["group_id"],stage="hierarchical_native")
        for p in old.plans(old.declaration()) if p["role"]=="reach_hold" for role in c["roles"]]


def profile_for(role,compiled,inputs):
    require(role in ("reach_hold","hierarchy_hold"),"Dynamic route unknown role")
    return (baseline_profile if role=="reach_hold" else dynamic_profile)(compiled,inputs)


def controller_for(role,core,compiled,c,model,episode,profile):
    require(role in ("reach_hold","hierarchy_hold"),"Dynamic route unknown role")
    kind=ReachHoldController if role=="reach_hold" else HierarchicalHoldController
    return kind(core,compiled,controller_contract(c,model),model,episode,profile)


def verify_component(evidence):
    from audit_contact_force_observer_closure import validate_bindings
    from audit_residual_training_closure import verify_population
    from run_hierarchical_contact_component_v5 import inventory
    from run_residual_native import verify_tests
    from audit_gpu_batch_execution import same_bits
    require(sha(COMPONENT_RESULT)==COMPONENT_SHA,"Hierarchy completed component result identity")
    result=read(COMPONENT_RESULT);contract=component.declaration();evidence=evidence.resolve(strict=True)
    identity=result["attempt_id"]
    require(identity=="sdk2-hierarchical-contact-component-v5-98e830c9f6c248118a3e809d39afc226","Hierarchy component attempt")
    attempt=(evidence/identity).resolve(strict=True)
    require(attempt.parent==evidence and result["contract_sha256"]==sha(COMPONENT_CONTRACT)
        and result["schema_version"]=="locolemotion_hierarchical_contact_component_result_v5"
        and result["status"]=="complete_generic_hierarchical_handoff_with_retained_numerical_refusals"
        and result["ledger_scope"]==contract["ledger_scope"] and result["complete_reader_invocations"]==2
        and result["controls_passed"]==287 and result["states"]==118 and result["accepted_states"]==102
        and result["public_hosts"]==4 and result["public_commands_reconstructed_per_reader"]==248
        and result["worlds_opened"]==result["solver_steps"]==0
        and all(result[k] is False for k in component.DENIALS),"Hierarchy component scope/authority")
    for key,name in (("receipt_sha256","receipt.json"),("declaration_sha256","declaration.json"),
        ("audit_sha256","audit.json"),("reconstruction_sha256","reconstruction.json")):
        require(result[key]==sha(attempt/name),"Hierarchy component artifact digest")
    receipt=read(attempt/"receipt.json");declared=read(attempt/"declaration.json");audit=read(attempt/"audit.json")
    require(receipt["ok"] is True and receipt["source_runtime_unchanged"] is True
        and receipt["controls_passed"]==287 and receipt["worlds_opened"]==receipt["solver_steps"]==0
        and declared["source_commit"]==receipt["source_commit"]==result["source_commit"]
        and declared["contract"]==receipt["contract"]==contract
        and len(declared["binding"]["source"])==result["source_binding_count"]==862
        and len(declared["binding"]["runtime"])==result["runtime_binding_count"]==3582
        and result["trials"]==audit["trials"] and audit["states"]==118
        and same_bits(audit,read(attempt/"reconstruction.json")) and audit["ok"] is True
        and sha(attempt/"audit.json")==sha(attempt/"reconstruction.json")
        and all(audit[k] is False for k in component.DENIALS)
        and audit["worlds_opened"]==audit["solver_steps"]==0,"Hierarchy complete component evidence")
    verify_population(receipt["artifacts"],inventory(attempt));validate_bindings(declared["binding"])
    for name,_,count in component.GATES:verify_tests(attempt/(name+"-controls"),count)
    return dict(ok=True,component_result_sha256=sha(COMPONENT_RESULT),complete_artifact_population_verified=True,
        source_binding_count=862,runtime_binding_count=3582,retained_states=118,public_hosts=4,
        world_build_count=0,solver_steps=0)


def validate_launch_documents(owner,gate,consumed,c,source,attempt_id,declaration_sha,gate_sha):
    require(owner["source_commit"]==source and owner["contract"]==c and owner["planned_trials"]==plans(c)
        and owner["source_status"]==[] and owner["component_only"] is False
        and all(owner[k] is False for k in FLAGS),"Dynamic route owner authority")
    require(gate["ok"] is True and gate["source_commit"]==source and gate["declaration_sha256"]==declaration_sha
        and gate["safety_controls"]=={**{n:k for n,_,k in GATES},"provider":2,"containment":1}
        and gate["preflight"]["ok"] is True and gate["preflight"]["component_evidence_verified"] is True
        and gate["preflight"]["world_build_count"]==gate["preflight"]["solver_steps"]==0,"Dynamic complete launch gate")
    require(consumed==dict(attempt_id=attempt_id,source_commit=source,contract_sha256=sha(CONTRACT),
        declaration_sha256=declaration_sha,gate_receipt_sha256=gate_sha,trials=plans(c)),"Dynamic single-use claim")


def launch_records(folder,c,source):
    attempt=folder.parent
    require(folder.name=="physical" and attempt.name.startswith("sdk2-hierarchical-native-")
        and attempt.parent.resolve()==(ROOT.parent/"SporeSpore_Evidence").resolve(),"Dynamic durable output boundary")
    owner,gate,consumed=[read(attempt/n) for n in ("declaration.json","gate-receipt.json","consumed.json")]
    validate_launch_documents(owner,gate,consumed,c,source,attempt.name,sha(attempt/"declaration.json"),sha(attempt/"gate-receipt.json"))
    return owner
