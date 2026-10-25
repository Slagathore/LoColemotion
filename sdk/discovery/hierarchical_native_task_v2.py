"""Prospective exposed native comparison of verified configured contact-first hierarchy."""
import copy
from pathlib import Path
import support_reach_native_task as old
import audit_hierarchical_public_v6 as component
import hierarchical_native_task as previous_route
from hierarchical_force_policy_v6 import SOLVER_RUNTIME
import audit_support_reach_native_closure as retained
from hold_horizon_task import ROOT,HERE,FLAGS,MODEL,read,sha,require,bridge,provider,controller_contract,initial_arrays,frozen_model
from support_reach_force_policy import make_profile as baseline_profile
from hierarchical_force_policy_v6 import make_profile as dynamic_profile
from support_reach_control import ReachHoldController
from hierarchical_hold_control_v6 import HierarchicalHoldController

CONTRACT=HERE/"hierarchical_native_v2.json"
PARENT_CLOSURE=retained.CLOSURE
COMPONENT_CONTRACT=component.CONTRACT
COMPONENT_RESULT=HERE/"hierarchical_public_result_v6.json"
COMPONENT_SHA="83648e8c8d4e4f523bc48598daa9aef2e9f95b938401d0e703da75efc6acd844"
DIAGNOSIS=HERE/"terminal_constraint_feasibility_result_v1.json"
SOURCES=("hierarchical_native_task_v2.py","hierarchical_native_trial_v2.py","hierarchical_native_v2.py",
    "hierarchical_native_trial_audit_v2.py","audit_hierarchical_native_v2.py","run_hierarchical_native_v2.py","test_hierarchical_native_v2.py","hierarchical_native_row_audit_v6.py")
ROUTE_CONTROLS=27
GATES=(*previous_route.GATES,*(("refinement-"+name,module,count) for name,module,count in component.GATES
    if module not in {g[1] for g in previous_route.GATES}),("refinement-route","test_hierarchical_native_v2",ROUTE_CONTROLS))
EXPECTED_CONTROLS=sum(n for _,_,n in GATES)+3


def expected_declaration():
    c=copy.deepcopy(old.declaration());c.pop("planning_geometry")
    c.update(schema_version="locolemotion_hierarchical_native_contract_v2",
        ledger_scope=dict(subsystem="adaptation",engine_scope="mujoco_cpu",
            authority_mode="configured_hierarchical_development_route",question_class="development"),
        lane="hierarchical_native_v2",roles=["reach_hold","hierarchy_hold"],planned_cpu_worlds=4,planned_gpu_worlds=0,
        runtime=dict(c["runtime"],**SOLVER_RUNTIME),
        parent_closure_sha256=sha(PARENT_CLOSURE),parent_native_closure_sha256=sha(PARENT_CLOSURE),
        parent_native_contract_sha256=sha(old.CONTRACT),component_contract_sha256=sha(COMPONENT_CONTRACT),
        component_result_sha256=sha(COMPONENT_RESULT),diagnosis_sha256=sha(DIAGNOSIS),
        dynamic_parameters=component.parameters()["hierarchy"],optimization_settings=component.solver_settings(),
        candidate="certified original generic hierarchy; bounded primary refinement only after numerical refusal; unchanged public resolver",
        pair_comparison=dict(prefix_commands=60,prefix_internal_steps=300,prepared_handoff_identical=True,
            post_handoff="fresh causal trajectories; no equality requirement",
            fresh_baseline_regression="all 1440 controller rows and 7200 trace rows match retained reach hold per group"),
        comparison_endpoints=dict(primary="first physical violation under unchanged height, tilt and torso-contact rules",
            secondary=["complete twelve-second diagnostic eligibility","supporting-foot counts including pre-failure window",
                "actual motor reconstruction and held-interval change","measured control wall cost"],
            interpretation="two exposed condition-specific development pairs; no robustness or superiority qualification"),
        production_entrypoints=dict(worker="sdk/discovery/hierarchical_native_v2.py:run",
            native_trial="sdk/discovery/hierarchical_native_trial_v2.py:run_hold_trial",
            candidate="sdk/discovery/hierarchical_hold_control_v6.py:HierarchicalHoldController",
            reference="sdk/discovery/support_reach_control.py:ReachHoldController",
            trial_reader="sdk/discovery/hierarchical_native_trial_audit_v2.py:audit_trial",
            resolver="resolve_adaptation_v1",stepping="mj_step1 then held inputs then mj_step2"),
        coverage=["fresh role-specific profile/controller construction","exact first60/300 paired prefix",
            "complete fresh baseline reproduction","actual causal resolved history",
            "full twelve-second native trace and contact capture","two independent other-core readers",
            "independent primary and secondary reduced/full certificates and implicit motor equation","all five predicted held motor steps","nominal two-command handoff and weak public recovery through command89","empty supporting sets",
            "every internal motor torque and prepared versus held-interval torque change"],
        code_path_risks_covered=["profile/role crossing","reference memory and clock","native/canonical geometry",
            "controller numerical refusal prevents transfer","fresh independent worlds",
            "complete source/runtime bindings including generic ProxQP, OSQP, SciPy and cmeel","native sensor and solver-input joins"],
        code_path_risks_not_covered=["held-out starts or bodies","estimated capability","contact-model accuracy",
            "guaranteed maintained contact","rough terrain/noise/delay","cross-engine equivalence",
            "Tier3 learning","safe-backup qualification","real-time interactive performance"],
        synthetic_clock_check="retained public observations; alternative actions did not generate observations",
        refusal_policy="retain terminal controller row and close before native transfer; abort remaining campaign worlds",
        retained_inputs_are_training_data=False,
        independent_selected_row_reader="sdk/discovery/hierarchical_native_row_audit_v6.py:verify_row",
        component_handoff_scope="two-core weak public replay through command89 and nominal two-command handoff",
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
    return [dict(p,role=role,trial_id=role+"_"+p["group_id"],stage="hierarchical_native_v2")
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
    from run_hierarchical_public_v6 import inventory
    from run_residual_native import verify_tests
    from audit_gpu_batch_execution import same_bits
    require(sha(COMPONENT_RESULT)==COMPONENT_SHA,"Native2 exact public result")
    result=read(COMPONENT_RESULT);c=component.declaration();folder=evidence/result["attempt_id"]
    require(result["status"]=="complete_two_core_public_recovery_and_nominal_handoff"
        and result["controls_passed"]==105 and result["public_controller_integration_verified"] is True
        and result["public_hosts_per_reader"]==4 and result["public_commands_per_reader"]==304
        and result["recovered_public_commands_per_reader"]==2 and result["complete_reader_invocations"]==2
        and result["worlds_opened"]==result["solver_steps"]==0,"Native2 public scope")
    for key,name in (("receipt_sha256","receipt.json"),("declaration_sha256","declaration.json"),
            ("audit_sha256","audit.json"),("reconstruction_sha256","reconstruction.json")):
        require(result[key]==sha(folder/name),"Native2 public artifact")
    receipt=read(folder/"receipt.json");declared=read(folder/"declaration.json");a=read(folder/"audit.json")
    require(receipt["ok"] is True and receipt["source_runtime_unchanged"] is True and receipt["controls_passed"]==105
        and receipt["contract"]==declared["contract"]==c
        and declared["source_commit"]==receipt["source_commit"]==result["source_commit"]
        and a["ok"] is True and a["public_controller_integration_verified"] is True
        and a["public_hosts"]==4 and a["public_commands"]==304 and a["hierarchical_commands"]==64
        and a["recovered_public_commands"]==2 and a["worlds_opened"]==a["solver_steps"]==0
        and same_bits(a,read(folder/"reconstruction.json")) and sha(folder/"audit.json")==sha(folder/"reconstruction.json")
        and all(a[k] is False for k in component.DENIALS)
        and len(declared["binding"]["source"])==result["source_binding_count"]==916
        and len(declared["binding"]["runtime"])==result["runtime_binding_count"]==3582,
        "Native2 complete public evidence")
    verify_population(receipt["artifacts"],inventory(folder));validate_bindings(declared["binding"])
    for name,_,count in component.GATES:verify_tests(folder/(name+"-controls"),count)
    return dict(ok=True,component_result_sha256=sha(COMPONENT_RESULT),complete_artifact_population_verified=True,
        source_binding_count=916,runtime_binding_count=3582,public_hosts=4,public_commands=304,
        recovered_public_commands=2,world_build_count=0,solver_steps=0)


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
    require(folder.name=="physical" and attempt.name.startswith("sdk2-hierarchical-native-v2-")
        and attempt.parent.resolve()==(ROOT.parent/"SporeSpore_Evidence").resolve(),"Dynamic durable output boundary")
    owner,gate,consumed=[read(attempt/n) for n in ("declaration.json","gate-receipt.json","consumed.json")]
    validate_launch_documents(owner,gate,consumed,c,source,attempt.name,sha(attempt/"declaration.json"),sha(attempt/"gate-receipt.json"))
    return owner
