"""Prospective observer-only fixture on two exposed recovery groups."""
import copy
from pathlib import Path

import residual_recovery_training_task as parent
from residual_recovery_task import ROOT, HERE, FLAGS, sha, require, read, bridge, provider, controller_contract, initial_arrays

CONTRACT = HERE/"contact_force_observer_v1.json"
MODEL = HERE/"contact_force_observer_model_v1.json"
PARENT_CLOSURE = HERE/"residual_recovery_training_closure_v1.json"
DIAGNOSIS = HERE/"residual_recovery_diagnostic_v1.json"
SOURCES = ("contact_force_measurement.py", "contact_force_observer_task.py",
    "contact_force_observer_native.py", "audit_contact_force_observer.py",
    "run_contact_force_observer.py", "test_contact_force_measurement.py",
    "test_contact_force_observer.py")
GATES = (*parent.GATES, ("contact-measurement", "test_contact_force_measurement", 22),
         ("contact-observer", "test_contact_force_observer", 14))
EXPECTED_CONTROLS = sum(n for _, _, n in GATES)+3
MODEL_SHA = "08050eec6175acf5cc9b63fc03d1c318e4757adca28dcc13921e28b68f3595b6"


def expected_declaration():
    old = parent.declaration("pilot")
    fields = ("core_sha256", "baseline_core_sha256", "runtime", "model_xml_sha256",
        "descriptor_sha256", "policy_id", "stability_policy_id", "phase_mode",
        "internal_steps_per_outer", "timestep_s", "controller_dt_s", "warmup_outer_steps",
        "initial_values", "cpu_warning_count", "naconmax", "naconmax_per_world", "njmax",
        "selection", "conditions", "condition_model_sha256", "training_starts",
        "reserved_starts", "excluded_confirmation_starts", "reward", "official_quality",
        "maximum_trace_bytes_per_trial", "provider_definition", "source_host",
        "challenge_actor_sha256", "warning_model_sha256")
    return dict({k: copy.deepcopy(old[k]) for k in fields},
        schema_version="locolemotion_contact_force_observer_contract_v1",
        ledger_scope=dict(subsystem="adaptation", engine_scope="mujoco_cpu",
            authority_mode="contact_force_observation_development", question_class="development"),
        lane="observer_fixture", seed=104242001, outer_steps=120, horizon_s=1.,
        groups=["left_075_train_001", "nominal_train_001"],
        roles=["observer_off", "observer_on"], planned_cpu_worlds=4, planned_gpu_worlds=0,
        calibration_worlds=0, evaluation_worlds=0, official_quality_enabled=False,
        training_data_scope="none_observer_noninterference",
        selected_model_sha256=MODEL_SHA, parent_closure_sha256=sha(PARENT_CLOSURE),
        diagnosis_sha256=sha(DIAGNOSIS), handoff_command=60, reentry_permitted=False,
        observation=dict(api="mj_contactForce", stage="completed_step_before_next_prepare",native_cone="elliptic",
            units=dict(force="N", torque="N*m", position="m", time="s"),
            direction="positive_on_geom2_negative_on_geom1", local_to_world="frame_transpose",
            world_to_canonical="x,z,-y", torque_origin="each_contact_position",
            load_scope="mapped_distal_geom_ground_contact_not_endpoint_force",
            canonical_controller_normal_load_n=None, controller_load_fields_changed=False,
            clock_alone_proves_stage=False, trusted_host_exclusive_stage_ownership=True,
            raw_capture="every_internal_step_all_rigid_contacts_full_constraint_force_vector",
            independent_force_reconstruction="constraint_rows_with_cone_friction_dimension_and_adhesion",
            absolute_tolerance=1e-11, relative_tolerance=2e-12,
            frame_tolerance=1e-9, inactive_contact_force=[0.]*6),
        pair_comparison=dict(trace="all_fields_float64_bitwise_equal",
            controller_fields=["native_observation", "stability", "kinematics", "composition",
                               "output", "native_targets"],
            additional_fields=["request.state", "resolution.ordered_commands"],
            controller_replay="every_row_against_other_core",
            identity_fields="distinct_episode_id_per_fresh_world"),
        production_entrypoints=dict(baseline_worker="sdk/discovery/residual_recovery_native.py:run_trial",
            observer_worker="sdk/discovery/contact_force_observer_native.py:run_observed_trial",
            controller="sdk/discovery/residual_recovery_control.py:RecoveryController",
            stepping="mj_step1 then held inputs then mj_step2"),
        minimum_free_storage_bytes=5*2**30, maximum_worker_wall_seconds=600,
        maximum_reader_wall_seconds=600,
        safety_controls=[dict(name=n, module=m, count=k) for n, m, k in GATES],
        provider_controls=2, containment_controls=1, complete_safety_control_count=EXPECTED_CONTROLS,
        implementation_bindings={n: sha(HERE/n) for n in SOURCES},
        inherited_source_bindings={n: sha(HERE/n) for n in
            ("residual_recovery_native.py", "residual_recovery_control.py", "audit_residual_recovery.py")},
        artifact_bindings={p.relative_to(ROOT).as_posix(): sha(p)
            for p in (MODEL, PARENT_CLOSURE, DIAGNOSIS, parent.CONTRACT)},
        coverage=["completed solver force stage and geometry join",
            "force and torque orientation, signed body attribution and raw constraint reconstruction",
            "all contacts retained including non-distal ground collisions",
            "explicit zero loads versus missing capture; full stream denominator",
            "fresh off/on native equality in healthy and weakened exposed starts",
            "original baseline, provider, resolved action history and other-core replay",
            "observer overhead measured without capture reduction"],
        not_covered=["controller use of contact forces", "actuation-aware recovery behavior",
            "12-second recovery", "endpoint-only foot contact attribution",
            "inverse dynamics or feasible wrench certificate", "safe backup",
            "out-of-band native API calls", "multi-seed robustness",
            "held-out starts", "other engines", "Tier 3 benefit", "qualification or release"],
        controller_selection_authority=False, adaptation_benefit_established=False,
        tier2_qualified=False, tier3_benefit_established=False, **{k: False for k in FLAGS})


def declaration():
    value = read(CONTRACT)
    require(value == expected_declaration(), "Contact observer declaration/source bindings")
    return value


def plans(c):
    result = []
    for group in c["groups"]:
        condition, start = group.split("_train_"); start = "train_"+start
        require(condition in ("left_075", "nominal") and start == "train_001",
                "Observer exposed development scope")
        for role in c["roles"]:
            result.append(dict(trial_id=role+"_"+group, stage="observer", group_id=group,
                condition_id=condition, start_id=start, role=role, model_key="training_selected",
                direction=None, sign=None, partition="development_comparison",
                mode="early_selected", seed=c["seed"], nworld=1, arm="scalar_direct",
                training_data_authority=False, initial_native_lateral_velocity_m_s=.001))
    require(len(result) == 4 == c["planned_cpu_worlds"]
            and len({p["trial_id"] for p in result}) == 4, "Observer complete population")
    return result


def frozen_model(core):
    require(sha(MODEL) == MODEL_SHA, "Observer selected recovery identity")
    result = provider.FrozenModel.load(core, read(MODEL))
    require(result.serialized == MODEL.read_text(encoding="utf-8")
            and result.sha256 == "sha256:"+MODEL_SHA, "Observer exact model bytes")
    return result


def launch_records(folder, c, source):
    attempt = folder.parent
    require(folder.name == "physical" and attempt.name.startswith("sdk2-contact-observer-")
            and attempt.parent.resolve() == (ROOT.parent/"SporeSpore_Evidence").resolve(),
            "Observer durable output boundary")
    owner, gate, consumed = [read(attempt/n) for n in ("declaration.json", "gate-receipt.json", "consumed.json")]
    require(owner["source_commit"] == source and owner["contract"] == c
            and owner["planned_trials"] == plans(c) and owner["source_status"] == []
            and owner["component_only"] is False
            and all(owner[k] is False for k in FLAGS), "Observer owner authority")
    require(gate["ok"] is True and gate["source_commit"] == source
            and gate["declaration_sha256"] == sha(attempt/"declaration.json")
            and gate["safety_controls"] == {**{n: k for n, _, k in GATES}, "provider": 2, "containment": 1}
            and gate["preflight"]["ok"] is True
            and gate["preflight"]["world_build_count"] == gate["preflight"]["solver_steps"] == 0,
            "Observer complete launch gate")
    require(consumed == dict(attempt_id=attempt.name, source_commit=source,
            contract_sha256=sha(CONTRACT), declaration_sha256=sha(attempt/"declaration.json"),
            gate_receipt_sha256=sha(attempt/"gate-receipt.json"), trials=plans(c)),
            "Observer single-use claim")
    return owner
