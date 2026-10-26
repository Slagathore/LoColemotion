"""Prospective fresh native comparison of the verified predictive public host."""
import copy
from pathlib import Path
import hierarchical_native_task_v6 as previous
import audit_predictive_public_v1 as component
from hierarchical_native_task_v6 import ROOT,HERE,FLAGS,MODEL,PARENT_CLOSURE,read,sha,require,bridge,provider,controller_contract,initial_arrays,frozen_model,retained
from hierarchical_force_policy_v8 import make_profile as nominal_profile
from support_reach_force_policy import make_profile as baseline_profile
from support_reach_control import ReachHoldController
from prepare_predictive_model_mujoco import prepare
from predictive_hold_policy_v1 import make_profile
from predictive_hold_control_v1 import PredictiveHoldController
from audit_predictive_numeric_backend import DLL,DLL_SHA
from run_gpu_measurement_probe import source_identity

CONTRACT=HERE/"predictive_native_v1.json"
COMPONENT_CONTRACT=component.CONTRACT
COMPONENT_RESULT=HERE/"predictive_public_result_v1.json"
COMPONENT_SHA="2a325142df26c4bef657d227a76a9db37ebf4ef5629b661f02fe6386a487e193"
DIAGNOSIS=HERE/"predictive_public_result_v1.json"
COVERAGE_RESULT=previous.COVERAGE_RESULT
SOURCES=("predictive_native_task_v1.py","predictive_native_trial_v1.py","predictive_native_v1.py",
    "predictive_native_trial_audit_v1.py","predictive_native_checks_v1.py","audit_predictive_native_v1.py",
    "run_predictive_native_v1.py","test_predictive_native_v1.py")
ROUTE_CONTROLS=24
ADDED=tuple(("prediction-"+name,module,count) for name,module,count in component.GATES
    if module not in {g[1] for g in previous.GATES})
GATES=(*previous.GATES,*ADDED,("predictive-native","test_predictive_native_v1",ROUTE_CONTROLS))
EXPECTED_CONTROLS=sum(n for _,_,n in GATES)+3


def expected_declaration():
    c=copy.deepcopy(previous.declaration())
    for key in ("dynamic_parameters","optimization_settings","diagnosis_sha256","planning_dynamics"):
        c.pop(key)
    c.update(schema_version="locolemotion_predictive_native_contract_v1",
        ledger_scope=dict(subsystem="adaptation",engine_scope="mujoco_cpu",
            authority_mode="fresh_predictive_recovery_development_comparison",question_class="development"),
        lane="predictive_native_v1",roles=["reach_hold","predictive_hold"],
        predecessor_attempt="sdk2-hierarchical-native-v6-f5072c1d2e46499498911eed68d74146",
        predecessor_receipt_sha256="2a9f28a81b097ad03679804c3f69da7fb8965350a9b1f461bd4ef5b0d9427301",
        previous_native_contract_sha256=sha(previous.CONTRACT),
        component_contract_sha256=sha(COMPONENT_CONTRACT),component_result_sha256=COMPONENT_SHA,
        candidate="configured canonical predictive selection with actual public-resolved history",
        production_entrypoints=dict(worker="sdk/discovery/predictive_native_v1.py:run",
            native_trial="sdk/discovery/predictive_native_trial_v1.py:run_hold_trial",
            candidate="sdk/discovery/predictive_hold_control_v1.py:PredictiveHoldController",
            reference="sdk/discovery/support_reach_control.py:ReachHoldController",
            trial_reader="sdk/discovery/predictive_native_trial_audit_v1.py:audit_trial",
            resolver="resolve_adaptation_v1",stepping="mj_step1 then held inputs then mj_step2"),
        coverage=["fresh baseline and predictive worlds","unchanged twelve-second physical criteria",
            "paired 60-command/300-step prefix and prepared handoff","actual public history and selected transfer",
            "complete native state, contact and named-force streams","other-core whole-host replay",
            "all candidate guards and ranking; independent selected Python forecast",
            "every internal motor force and native/canonical geometry","valid refusal audited with explicit censored outcome",
            "streamed readers retain only adjacent control rows and bounded summaries"],
        code_path_risks_covered=["profile and model crossing","wrong kernel binary","control-history crossing",
            "missing native steps or contact samples","invalid refusal relabeled as completion",
            "changed selected target after resolution","nonzero reader worlds","source/runtime drift",
            "bounded storage and contained worker lifetime"],
        code_path_risks_not_covered=["held-out starts/bodies","robustness","statistical superiority",
            "cross-engine equivalence","learned capability","Tier3 learning","real-time interactive performance"],
        independent_selected_row_reader="sdk/discovery/predictive_native_trial_audit_v1.py:audit_trial",
        component_handoff_scope="verified weak retained commands60..116 and terminal117; nominal60..61 on both cores",
        refusal_policy="retain final controller row and unchanged native state; stop before transfer and abort remaining worlds; audit available complete streams",
        completion_semantics="owner ok means verified complete execution or valid retained refusal, never recovery success; full comparison requires all four complete worlds",
        gate_applicability=dict(prior_complete_controls=1050,added_prediction_controls=sum(g[2] for g in ADDED),
            new_route_controls=ROUTE_CONTROLS,total=EXPECTED_CONTROLS,prior_modules_retained=True,duplicate_modules_removed_from_additions=True),
        runtime_kernel=dict(path=DLL.relative_to(ROOT.parent).as_posix(),sha256=DLL_SHA),
        selection_seed=dict(physical_development_seed=104242001,candidate_sampler_base=20261025,
            recipe="immutable sampler base plus command index; one exposed physical development seed"),
        reference_reconstruction="whole host replay on other core; all retained candidate guards and objective ranking; independent Python forecast for selected command only",
        prediction_error_scope="measured selected forecast versus new native steps; diagnostic, no retrospective tolerance fitting",
        maximum_trace_bytes_per_trial=8*2**30,maximum_controller_row_bytes=16*2**20,
        minimum_free_storage_bytes=256*2**30,maximum_worker_wall_seconds=7200,maximum_reader_wall_seconds=7200,
        resource_basis=dict(parent_result_sha256=COMPONENT_SHA,weak_host_mean_seconds=[.7286782379323368,.9746870706901597],
            observed_maximum_host_seconds=18.259706199998618,observed_maximum_compact_controller_row_bytes=1409756,
            streams_per_trial=5,maximum_trials=4,reader_streaming=True,
            wall_limit_is_not_a_control_period_or_recovery_threshold=True),
        safety_controls=[dict(name=n,module=m,count=k) for n,m,k in GATES],
        complete_safety_control_count=EXPECTED_CONTROLS,
        implementation_bindings={name:sha(HERE/name) for name in SOURCES},
        inherited_source_bindings={name:sha(HERE/name) for name in (*component.SOURCES,
            "prepared_predictive_model.py","predictive_numeric_backend.py","predictive_numeric_kernels.rs",
            "predictive_command_selection_v2.py","hierarchical_hold_control_v8.py",
            "hierarchical_force_policy_v8.py","support_reach_control.py","support_reach_force_policy.py")})
    require(EXPECTED_CONTROLS==1227 and len({n for n,_,_ in GATES})==len(GATES)
        and len({m for _,m,_ in GATES})==len(GATES),"Predictive complete unique applicability mapping")
    return c


def declaration():
    c=read(CONTRACT);require(c==expected_declaration(),"Predictive native exact contract");return c


def plans(c):
    require(c["roles"]==["reach_hold","predictive_hold"] and c["groups"]==["left_075_train_001","nominal_train_001"]
        and c["outer_steps"]==1440 and c["horizon_s"]==12. and c["planned_cpu_worlds"]==4
        and c["planned_gpu_worlds"]==0,"Predictive exact exposed native scope")
    return [dict(p,role=role,trial_id=role+"_"+p["group_id"],stage="predictive_native_v1")
        for p in previous.plans(previous.declaration()) if p["role"]=="reach_hold" for role in c["roles"]]


def profile_for(role,compiled,inputs,xml):
    require(role in ("reach_hold","predictive_hold"),"Predictive native role")
    if role=="reach_hold":return baseline_profile(compiled,inputs)
    nominal=nominal_profile(compiled,inputs)
    return make_profile(nominal,prepare(nominal,xml),DLL_SHA)


def controller_for(role,core,compiled,c,model,episode,profile):
    require(role in ("reach_hold","predictive_hold"),"Predictive native controller role")
    arguments=(core,compiled,controller_contract(c,model),model,episode,profile)
    return ReachHoldController(*arguments) if role=="reach_hold" else PredictiveHoldController(*arguments,DLL)


def verify_component(evidence):
    from audit_contact_force_observer_closure import validate_bindings
    from audit_residual_training_closure import verify_population
    from run_hierarchical_native_v6 import inventory
    from run_residual_native import verify_tests
    require(sha(COMPONENT_RESULT)==COMPONENT_SHA and sha(DLL)==DLL_SHA,"Predictive public closure/kernel identity")
    result=read(COMPONENT_RESULT);c=component.declaration();folder=evidence/result["attempt_id"]
    r=read(folder/"receipt.json");d=read(folder/"declaration.json");a=read(folder/"audit.json")
    require(result["status"]=="complete_bounded_retained_state_public_integration"
        and r["ok"] is True and result["controls_passed"]==r["controls_passed"]==170
        and r["contract"]==d["contract"]==c and result["readers_byte_identical"] is True
        and result["complete_reader_invocations"]==2 and a==read(folder/"reconstruction.json")
        and a["public_controller_integration_verified"] is True and a["actual_resolved_history_verified"] is True
        and a["public_hosts"]==4 and a["public_commands"]==360 and a["applied_predictive_commands"]==118
        and a["worlds_opened"]==a["solver_steps"]==0,"Predictive complete public integration scope")
    for name in ("receipt","declaration","audit","reconstruction"):
        require(sha(folder/(name+".json"))==result[name+"_sha256"],"Predictive public artifact")
    for key in ("tier2_qualified","tier3_benefit_established","recovery_benefit_established","physical_acceptance_authority","release_authority"):
        require(result[key] is False and a[key] is False,"Predictive no authority promotion")
    verify_population(r["artifacts"],inventory(folder));validate_bindings(d["binding"])
    for name,_,count in component.GATES:verify_tests(folder/(name+"-controls"),count)
    return dict(ok=True,result_sha256=COMPONENT_SHA,controls_passed=170,public_commands=360,
        worlds_opened=0,solver_steps=0,physical_acceptance_authority=False)


def verify_gate_coverage(evidence):
    return previous.verify_gate_coverage(evidence)


def validate_launch_documents(owner,gate,consumed,c,source,attempt_id,declaration_sha,gate_sha):
    require(attempt_id.startswith("sdk2-predictive-native-v1-") and owner["source_commit"]==source
        and owner["contract"]==c and owner["planned_trials"]==plans(c) and owner["source_status"]==[]
        and owner["component_only"] is False and all(owner[k] is False for k in FLAGS),
        "Predictive native owner scope/clean source")
    require(gate["ok"] is True and gate["source_commit"]==source and gate["declaration_sha256"]==declaration_sha
        and gate["safety_controls"]=={**{n:k for n,_,k in GATES},"provider":2,"containment":1}
        and gate["preflight"]["ok"] is True and gate["preflight"]["component_evidence_verified"] is True
        and gate["preflight"]["gate_coverage_verified"] is True
        and gate["preflight"]["world_build_count"]==gate["preflight"]["solver_steps"]==0,
        "Predictive complete zero-world launch gate")
    require(consumed==dict(attempt_id=attempt_id,source_commit=source,contract_sha256=sha(CONTRACT),
        declaration_sha256=declaration_sha,gate_receipt_sha256=gate_sha,trials=plans(c)),
        "Predictive single-use consumed identity")


def launch_records(folder,c,source):
    attempt=folder.parent
    require(folder.name=="physical" and attempt.name.startswith("sdk2-predictive-native-v1-")
        and attempt.parent.resolve()==(ROOT.parent/"SporeSpore_Evidence").resolve(),"Predictive durable output boundary")
    owner,gate,consumed=[read(attempt/name) for name in ("declaration.json","gate-receipt.json","consumed.json")]
    validate_launch_documents(owner,gate,consumed,c,source,attempt.name,sha(attempt/"declaration.json"),sha(attempt/"gate-receipt.json"))
    return owner
