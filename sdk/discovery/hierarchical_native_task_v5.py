"""Prospective exposed native comparison of verified configured contact-first hierarchy."""
import copy
from pathlib import Path
import support_reach_native_task as old
import audit_hierarchical_public_v8 as component
import hierarchical_native_task as previous_route
from hierarchical_force_policy_v8 import SOLVER_RUNTIME
import audit_support_reach_native_closure as retained
from hold_horizon_task import ROOT,HERE,FLAGS,MODEL,read,sha,require,bridge,provider,controller_contract,initial_arrays,frozen_model
from support_reach_force_policy import make_profile as baseline_profile
from hierarchical_force_policy_v8 import make_profile as dynamic_profile
from support_reach_control import ReachHoldController
from hierarchical_hold_control_v8 import HierarchicalHoldController

CONTRACT=HERE/"hierarchical_native_v5.json"
PARENT_CLOSURE=retained.CLOSURE
COMPONENT_CONTRACT=component.CONTRACT
COMPONENT_RESULT=HERE/"hierarchical_public_result_v8.json"
COMPONENT_SHA="6d1c8d617fefdbfb685ebecf161dde626f667e25c77fa7b0fbed9963b062c0fc"
PREDECESSOR_ATTEMPT="sdk2-hierarchical-native-v4-e021aaff51a8459a9f1c2309c72c6a77"
PREDECESSOR_RECEIPT_SHA="f72aa326ed1087b2005db4a944f733d29070a49a6106c193241e63e570da67c7"
DIAGNOSIS=HERE/"hierarchical_native_failure_result_v3.json"
SOURCES=("hierarchical_native_task_v5.py","hierarchical_native_trial_v5.py","hierarchical_native_v5.py",
    "hierarchical_native_trial_audit_v5.py","audit_hierarchical_native_v5.py","run_hierarchical_native_v5.py","test_hierarchical_native_v5.py","hierarchical_native_row_audit_v8.py")
ROUTE_CONTROLS=33
GATES=(*previous_route.GATES,*(("refinement-"+name,module,count) for name,module,count in component.GATES
    if module not in {g[1] for g in previous_route.GATES}),("refinement-route","test_hierarchical_native_v5",ROUTE_CONTROLS))
EXPECTED_CONTROLS=sum(n for _,_,n in GATES)+3


def expected_declaration():
    c=copy.deepcopy(old.declaration());c.pop("planning_geometry")
    c.update(schema_version="locolemotion_hierarchical_native_contract_v5",
        ledger_scope=dict(subsystem="adaptation",engine_scope="mujoco_cpu",
            authority_mode="configured_hierarchical_development_route",question_class="development"),
        lane="hierarchical_native_v5",predecessor_attempt=PREDECESSOR_ATTEMPT,
        predecessor_receipt_sha256=PREDECESSOR_RECEIPT_SHA,roles=["reach_hold","hierarchy_hold"],planned_cpu_worlds=4,planned_gpu_worlds=0,
        runtime=dict(c["runtime"],**SOLVER_RUNTIME),
        parent_closure_sha256=sha(PARENT_CLOSURE),parent_native_closure_sha256=sha(PARENT_CLOSURE),
        parent_native_contract_sha256=sha(old.CONTRACT),component_contract_sha256=sha(COMPONENT_CONTRACT),
        component_result_sha256=sha(COMPONENT_RESULT),diagnosis_sha256=sha(DIAGNOSIS),
        dynamic_parameters=component.parameters()["hierarchy"],optimization_settings=component.solver_settings(),
        candidate="preserve three accepted routes; bounded affine scaled primary after numerical refusal; unchanged public resolver",
        pair_comparison=dict(prefix_commands=60,prefix_internal_steps=300,prepared_handoff_identical=True,
            post_handoff="fresh causal trajectories; no equality requirement",
            fresh_baseline_regression="all 1440 controller rows and 7200 trace rows match retained reach hold per group"),
        comparison_endpoints=dict(primary="first physical violation under unchanged height, tilt and torso-contact rules",
            secondary=["complete twelve-second diagnostic eligibility","supporting-foot counts including pre-failure window",
                "actual motor reconstruction and held-interval change","measured control wall cost"],
            interpretation="two exposed condition-specific development pairs; no robustness or superiority qualification"),
        production_entrypoints=dict(worker="sdk/discovery/hierarchical_native_v5.py:run",
            native_trial="sdk/discovery/hierarchical_native_trial_v5.py:run_hold_trial",
            candidate="sdk/discovery/hierarchical_hold_control_v8.py:HierarchicalHoldController",
            reference="sdk/discovery/support_reach_control.py:ReachHoldController",
            trial_reader="sdk/discovery/hierarchical_native_trial_audit_v5.py:audit_trial",
            resolver="resolve_adaptation_v1",stepping="mj_step1 then held inputs then mj_step2"),
        coverage=["fresh role-specific profile/controller construction","exact first60/300 paired prefix",
            "complete fresh baseline reproduction","actual causal resolved history",
            "full twelve-second native trace and contact capture","two independent other-core readers",
            "independent primary and secondary reduced/full certificates and implicit motor equation","all five predicted held motor steps","nominal two-command handoff and weak public recovery through command98","empty supporting sets","certified seeds and scaled corrections with four-route actual solve accounting",
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
        independent_selected_row_reader="sdk/discovery/hierarchical_native_row_audit_v8.py:verify_row",
        component_handoff_scope="two-core weak public replay through command98 and nominal two-command handoff",
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
    return [dict(p,role=role,trial_id=role+"_"+p["group_id"],stage="hierarchical_native_v5")
        for p in old.plans(old.declaration()) if p["role"]=="reach_hold" for role in c["roles"]]


def profile_for(role,compiled,inputs):
    require(role in ("reach_hold","hierarchy_hold"),"Dynamic route unknown role")
    return (baseline_profile if role=="reach_hold" else dynamic_profile)(compiled,inputs)


def controller_for(role,core,compiled,c,model,episode,profile):
    require(role in ("reach_hold","hierarchy_hold"),"Dynamic route unknown role")
    kind=ReachHoldController if role=="reach_hold" else HierarchicalHoldController
    return kind(core,compiled,controller_contract(c,model),model,episode,profile)


def verify_predecessor(evidence):
    from audit_contact_force_observer_closure import validate_bindings
    from audit_residual_training_closure import verify_population
    from run_hierarchical_native_failure_v3 import inventory
    from run_residual_native import verify_tests
    import audit_scaled_primary_component as provenance
    from audit_gpu_batch_execution import same_bits
    require(sha(DIAGNOSIS)==provenance.PARENT_SHA,"Native5 retained predecessor closure identity")
    result=read(DIAGNOSIS);folder=evidence/result["attempt_id"]
    r=read(folder/"receipt.json");d=read(folder/"declaration.json");a=read(folder/"audit.json")
    provenance.validate_parent_scope(result,a,r,provenance.native_parent.declaration())
    for key,name in (("receipt_sha256","receipt.json"),("declaration_sha256","declaration.json"),
            ("audit_sha256","audit.json"),("reconstruction_sha256","reconstruction.json")):
        require(result[key]==sha(folder/name),"Native5 predecessor closure artifacts")
    require(r["contract"]==d["contract"]==provenance.native_parent.declaration()
        and r["source_commit"]==d["source_commit"]==result["source_commit"]
        and same_bits(a,read(folder/"reconstruction.json"))
        and sha(folder/"audit.json")==sha(folder/"reconstruction.json"),"Native5 predecessor complete replay")
    verify_population(r["artifacts"],inventory(folder));validate_bindings(d["binding"])
    verify_tests(folder/"failure-controls",24)
    native=evidence/PREDECESSOR_ATTEMPT
    require(sha(native/"receipt.json")==PREDECESSOR_RECEIPT_SHA,"Native5 predecessor native receipt")
    nr=read(native/"receipt.json");nd=read(native/"declaration.json")
    provenance.native_parent.validate_owner(nr,nd,provenance.native_parent.task.declaration())
    provenance.native_parent.validate_worker(read(native/"physical/worker-result.json"),provenance.native_parent.task.declaration())
    verify_population(nr["artifacts"],inventory(native));validate_bindings(nr["binding"])
    return dict(attempt_id=native.name,receipt_sha256=PREDECESSOR_RECEIPT_SHA,
        closure_attempt_id=folder.name,closure_receipt_sha256=result["receipt_sha256"],
        original_safety_controls=984,closure_controls=24,terminal_command=98,
        original_worlds_opened=2,new_worlds_opened=0,failed_attempt_preserved=True)


def verify_component(evidence):
    from audit_contact_force_observer_closure import validate_bindings
    from audit_residual_training_closure import verify_population
    from run_hierarchical_public_v8 import inventory
    from run_residual_native import verify_tests
    from audit_gpu_batch_execution import same_bits
    require(sha(COMPONENT_RESULT)==COMPONENT_SHA,"Native2 exact public result")
    result=read(COMPONENT_RESULT);c=component.declaration();folder=evidence/result["attempt_id"]
    require(set(result)==set(['actual_inner_qp_calls_independently_counted', 'affine_correction_and_original_duals_independently_reconstructed', 'all_three_predecessor_refusals_independently_reconstructed', 'alternative_actions_generated_observations', 'artifacts_including_receipt', 'attempt_id', 'audit_sha256', 'capability_estimated', 'certified_seed_independently_verified', 'complete_comparison_established', 'complete_reader_invocations', 'complete_saturation_regime_search', 'contract_path', 'contract_sha256', 'controls_passed', 'declaration_sha256', 'dynamic_feasibility_established', 'equivalence_authority', 'held_contact_guaranteed', 'hierarchical_commands_per_reader', 'independent_row_certificates_verified', 'ledger_scope', 'next_step', 'nominal_condition_evaluated', 'nominal_public_handoff_verified', 'owner_wall_s', 'parent_result_path', 'parent_result_sha256', 'physical_acceptance_authority', 'physical_launch_authority', 'proximal_primary_public_commands_per_reader', 'public_commands_per_reader', 'public_controller_integration_verified', 'public_hosts_per_reader', 'reader_calls_qp_solver', 'readers_byte_identical', 'receipt_sha256', 'reconstruction_sha256', 'recovered_public_commands_per_reader', 'recovery_benefit_established', 'recursive_feasibility_established', 'release_authority', 'reports', 'runtime_binding_count', 'safe_backup_established', 'scaled_primary_public_commands_per_reader', 'schema_version', 'solver_steps', 'source_binding_count', 'source_commit', 'source_solver_component_unchanged', 'status', 'tier2_qualified', 'tier3_benefit_established', 'training_data_authority', 'weak_command89_refined_recovery_preserved', 'weak_command91_original_refusals_and_recovery_verified', 'weak_command98_scaled_recovery_verified', 'weak_previously_applied_hierarchical_commands_preserved_per_host', 'worlds_opened'])
        and result["schema_version"]=="locolemotion_hierarchical_public_result_v8"
        and result["ledger_scope"]==c["ledger_scope"]
        and all(result[k] is False for k in component.DENIALS)
        and result["readers_byte_identical"] is True
        and result["contract_path"]==COMPONENT_CONTRACT.relative_to(ROOT).as_posix()
        and result["contract_sha256"]==sha(COMPONENT_CONTRACT)
        and result["hierarchical_commands_per_reader"]==82
        and result["weak_previously_applied_hierarchical_commands_preserved_per_host"]==38
        and all(result[k] is True for k in ("weak_command89_refined_recovery_preserved","weak_command91_original_refusals_and_recovery_verified",
            "certified_seed_independently_verified","all_three_predecessor_refusals_independently_reconstructed",
            "weak_command98_scaled_recovery_verified","affine_correction_and_original_duals_independently_reconstructed","actual_inner_qp_calls_independently_counted",
            "nominal_public_handoff_verified","independent_row_certificates_verified","source_solver_component_unchanged"))
        and result["status"]=="complete_two_core_public_recovery_and_nominal_handoff"
        and result["controls_passed"]==295 and result["public_controller_integration_verified"] is True
        and result["public_hosts_per_reader"]==4 and result["public_commands_per_reader"]==322
        and result["recovered_public_commands_per_reader"]==10 and result["proximal_primary_public_commands_per_reader"]==4
        and result["scaled_primary_public_commands_per_reader"]==2 and result["reader_calls_qp_solver"] is False and result["complete_reader_invocations"]==2
        and result["worlds_opened"]==result["solver_steps"]==0,"Native2 public scope")
    verify_predecessor(evidence)
    for key,name in (("receipt_sha256","receipt.json"),("declaration_sha256","declaration.json"),
            ("audit_sha256","audit.json"),("reconstruction_sha256","reconstruction.json")):
        require(result[key]==sha(folder/name),"Native2 public artifact")
    receipt=read(folder/"receipt.json");declared=read(folder/"declaration.json");a=read(folder/"audit.json")
    require(receipt["ok"] is True and receipt["source_runtime_unchanged"] is True and receipt["controls_passed"]==295
        and receipt["contract"]==declared["contract"]==c
        and declared["source_commit"]==receipt["source_commit"]==result["source_commit"]
        and a["ok"] is True and a["public_controller_integration_verified"] is True
        and a["public_hosts"]==4 and a["public_commands"]==322 and a["hierarchical_commands"]==82
        and a["recovered_public_commands"]==10 and a["scaled_primary_public_commands"]==2 and a["worlds_opened"]==a["solver_steps"]==0
        and same_bits(a,read(folder/"reconstruction.json")) and sha(folder/"audit.json")==sha(folder/"reconstruction.json")
        and all(a[k] is False for k in component.DENIALS)
        and len(declared["binding"]["source"])==result["source_binding_count"]==999
        and len(declared["binding"]["runtime"])==result["runtime_binding_count"]==3582,
        "Native2 complete public evidence")
    require(result["reports"]==[{k:v for k,v in report.items() if k not in ("rows","checks")} for report in a["reports"]]
        and result["artifacts_including_receipt"]==len(receipt["artifacts"])+1
        and result["owner_wall_s"]==receipt["wall_s"]
        and result["parent_result_sha256"]==a["parent_result_sha256"]==component.PARENT_SHA,
        "Native3 public report joins")
    verify_population(receipt["artifacts"],inventory(folder));validate_bindings(declared["binding"])
    for name,_,count in component.GATES:verify_tests(folder/(name+"-controls"),count)
    return dict(ok=True,component_result_sha256=sha(COMPONENT_RESULT),complete_artifact_population_verified=True,
        source_binding_count=999,runtime_binding_count=3582,public_hosts=4,public_commands=322,
        recovered_public_commands=10,scaled_primary_public_commands=2,world_build_count=0,solver_steps=0)


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
    require(folder.name=="physical" and attempt.name.startswith("sdk2-hierarchical-native-v5-")
        and attempt.parent.resolve()==(ROOT.parent/"SporeSpore_Evidence").resolve(),"Dynamic durable output boundary")
    owner,gate,consumed=[read(attempt/n) for n in ("declaration.json","gate-receipt.json","consumed.json")]
    validate_launch_documents(owner,gate,consumed,c,source,attempt.name,sha(attempt/"declaration.json"),sha(attempt/"gate-receipt.json"))
    return owner
