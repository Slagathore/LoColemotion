"""Prospective bounded native route for the configured force recovery reference."""
import copy
from pathlib import Path
import contact_force_observer_task as old
from contact_force_observer_task import ROOT,HERE,FLAGS,MODEL,PARENT_CLOSURE,DIAGNOSIS,read,sha,require,bridge,provider,controller_contract,initial_arrays,frozen_model
from causal_force_component_audit import GATES as COMPONENT_GATES,CONTRACT as COMPONENT_CONTRACT

CONTRACT=HERE/"causal_force_native_v1.json"
COMPONENT_RESULT=HERE/"causal_force_component_result_v1.json"
SOURCES=("causal_force_native_task.py","causal_force_native.py","causal_force_native_trial_audit.py",
    "audit_causal_force_native.py","run_causal_force_native.py","test_causal_force_native.py")
GATES=(*old.GATES,*COMPONENT_GATES,("force-route","test_causal_force_native",10))
EXPECTED_CONTROLS=sum(n for _,_,n in GATES)+3


def expected_declaration():
    c=copy.deepcopy(old.declaration())
    c.update(schema_version="locolemotion_causal_force_native_contract_v1",
        ledger_scope=dict(subsystem="adaptation",engine_scope="mujoco_cpu",
            authority_mode="causal_force_development_route",question_class="development"),
        lane="causal_force_route",roles=["selected_reference","force_reference"],
        training_data_scope="none_execution_fixture_only",component_contract_sha256=sha(COMPONENT_CONTRACT),
        component_result_sha256=sha(COMPONENT_RESULT),capability_source="configured_reference_not_estimated",
        correction_envelope="unchanged_absolute_3.5_slew_0.08_and_final_speed_limits",
        prefix="original challenge through command 59; actual resolved history continues at command 60",
        candidate="untrained centroidal force least squares plus joint posture/damping",
        pair_comparison=dict(prefix_commands=60,prefix_internal_steps=300,
            prefix_comparison="all native trace fields bitwise equal; inputs, baseline and commands identical",
            handoff_prepared_observation="bitwise equal before command 60",
            after_handoff="fresh causal trajectories; no outcome equivalence requirement"),
        production_entrypoints=dict(worker="sdk/discovery/causal_force_native.py:run_force_trial",
            candidate="sdk/discovery/causal_force_control.py:ForceController",
            reference="sdk/discovery/residual_recovery_control.py:RecoveryController",
            resolver="resolve_adaptation_v1",stepping="mj_step1 then held inputs then mj_step2"),
        code_path_risks_covered=["fixed irreversible handoff with real command history",
            "declared gains/caps joined to fresh native model","rank-deficient force allocation",
            "bounded residual resolution and actual solver input","terminal failure prevents solver transfer",
            "complete prepared/completed force-stage capture","full other-core replay"],
        code_path_risks_not_covered=["learned capability","held interval force guarantees","long horizon recovery",
            "held out starts or bodies","rough terrain","sensing noise or delay","cross engine equivalence","Tier3 learning"],
        maximum_worker_wall_seconds=600,maximum_reader_wall_seconds=600,
        safety_controls=[dict(name=n,module=m,count=k) for n,m,k in GATES],complete_safety_control_count=EXPECTED_CONTROLS,
        implementation_bindings={name:sha(HERE/name) for name in SOURCES},
        capability_estimated=False,dynamic_feasibility_established=False,held_interval_force_guaranteed=False,
        recovery_benefit_established=False,twelve_second_recovery_established=False,
        safe_backup_established=False)
    return c


def declaration():
    c=read(CONTRACT);require(c==expected_declaration(),"Force route exact declaration/source bindings")
    return c


def plans(c):
    require(c["roles"]==["selected_reference","force_reference"]
        and c["groups"]==["left_075_train_001","nominal_train_001"],"Force route exact exposed roles/groups")
    values=old.plans(c)
    return [dict(p,stage="causal_force_route") for p in values]


def validate_launch_documents(owner,gate,consumed,c,source,attempt_id,declaration_sha,gate_sha):
    require(owner["source_commit"]==source and owner["contract"]==c and owner["planned_trials"]==plans(c)
        and owner["source_status"]==[] and owner["component_only"] is False
        and all(owner[k] is False for k in FLAGS),"Force route owner authority")
    require(gate["ok"] is True and gate["source_commit"]==source and gate["declaration_sha256"]==declaration_sha
        and gate["safety_controls"]=={**{n:k for n,_,k in GATES},"provider":2,"containment":1}
        and gate["preflight"]["ok"] is True
        and gate["preflight"]["world_build_count"]==gate["preflight"]["solver_steps"]==0,
        "Force route complete launch gate")
    require(consumed==dict(attempt_id=attempt_id,source_commit=source,contract_sha256=sha(CONTRACT),
        declaration_sha256=declaration_sha,gate_receipt_sha256=gate_sha,trials=plans(c)),"Force route single-use claim")


def launch_records(folder,c,source):
    attempt=folder.parent
    require(folder.name=="physical" and attempt.name.startswith("sdk2-causal-force-native-")
        and attempt.parent.resolve()==(ROOT.parent/"SporeSpore_Evidence").resolve(),"Force route durable output boundary")
    owner,gate,consumed=[read(attempt/n) for n in ("declaration.json","gate-receipt.json","consumed.json")]
    validate_launch_documents(owner,gate,consumed,c,source,attempt.name,
        sha(attempt/"declaration.json"),sha(attempt/"gate-receipt.json"))
    return owner
