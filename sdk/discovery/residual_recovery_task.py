"""Prospective paired recovery handoffs on two exposed development groups."""
import copy
from pathlib import Path

import residual_training_task as base
import residual_selection as selection
import residual_withdrawal_task as predecessor
from residual_training_task import ROOT,HERE,FLAGS,sha,require,bridge,read,initial_arrays
from adaptation_provider.warning import recovery_v1 as provider
from residual_recovery_control import expected_provider
from gpu_measurement_probe import write_new

CONTRACT=HERE/"residual_recovery_v1.json"
MODEL=HERE/"residual_recovery_model_v1.json"
WITHDRAWAL_CLOSURE=HERE/"residual_withdrawal_closure_v1.json"
SOURCES=("residual_recovery_task.py","residual_recovery_native.py",
    "audit_residual_recovery.py","run_residual_recovery.py",
    "residual_recovery_metrics.py","test_residual_recovery.py")
COMPONENTS=(Path(provider.__file__),provider.CONTRACT,HERE/"residual_recovery_control.py",
    HERE/"test_residual_recovery_provider.py",HERE/"run_residual_recovery_component.py")
ARTIFACTS=(MODEL,WITHDRAWAL_CLOSURE,predecessor.CONTRACT,*predecessor.ARTIFACTS)
GATES=(*predecessor.GATES,("withdrawal-closure","test_residual_withdrawal_closure",9),
    ("recovery-provider","test_residual_recovery_provider",26),
    ("recovery-native","test_residual_recovery",22))
EXPECTED_CONTROLS=sum(n for _,_,n in GATES)+3
ROLES=provider.MODES[:-1]


def controller_contract(c,model):
    return dict(c,provider=expected_provider(model))


def frozen_models(core):
    previous=predecessor.frozen_models(core)
    document=provider.artifact(previous["challenge"].actor,previous["selected"].actor,previous["selected"].warning)
    require(read(MODEL)==document,"Recovery changed frozen actors/warning")
    model=provider.FrozenModel.load(core,document)
    require(MODEL.read_text(encoding="utf-8")==model.serialized
        and "sha256:"+sha(MODEL)==model.sha256,"Recovery composite exact bytes")
    return {"recovery":model}


def expected_declaration():
    old=predecessor.expected_declaration()
    fields=("core_sha256","baseline_core_sha256","runtime","model_xml_sha256","descriptor_sha256",
        "policy_id","stability_policy_id","phase_mode","internal_steps_per_outer","timestep_s",
        "controller_dt_s","warmup_outer_steps","initial_values","cpu_warning_count","naconmax",
        "naconmax_per_world","njmax","selection","conditions","condition_model_sha256",
        "training_starts","reserved_starts","excluded_confirmation_starts","reward","official_quality",
        "maximum_trace_bytes_per_trial")
    return dict({k:copy.deepcopy(old[k]) for k in fields},
        schema_version="locolemotion_residual_recovery_native_v1",
        ledger_scope=dict(subsystem="adaptation",engine_scope="mujoco_cpu",
            authority_mode="frozen_actor_recovery_development",question_class="development"),
        lane="comparison",seed=104240801,outer_steps=1440,horizon_s=12.,
        groups=["left_075_train_001","nominal_train_001"],
        comparison_roles=list(ROLES),planned_cpu_worlds=14,planned_gpu_worlds=0,
        calibration_worlds=0,evaluation_worlds=0,official_quality_enabled=True,
        training_data_scope="none_frozen_actor_recovery_diagnostic",
        provider_definition=provider.definition(),early_handoff_command=provider.EARLY_COMMAND,
        source_host=dict(path="sdk/discovery/residual_recovery_control.py",
            sha256=sha(HERE/"residual_recovery_control.py")),
        model_sha256="sha256:"+sha(MODEL),
        challenge_actor_sha256=old["challenge_actor_sha256"],
        recovery_actor_sha256=read(selection.FIT)["selected_model_sha256"],
        warning_model_sha256=old["warning_model_sha256"],
        selection_record_sha256=sha(selection.FIT),predecessor_closure_sha256=sha(WITHDRAWAL_CLOSURE),
        challenge_choice_is_retrospective=True,recovery_choice_is_retrospective=True,
        early_handoff_is_development_design=True,preserve_weights_and_thresholds=True,
        comparison_data_may_fit=False,scheduled_request_changes_prediction=False,
        reentry_permitted=False,recovery_success_is_completion_requirement=False,
        safe_backup_established=False,confidence_is_calibrated=False,
        minimum_free_storage_bytes=25*2**30,maximum_worker_wall_seconds=4800,maximum_reader_wall_seconds=4800,
        safety_controls=[dict(name=n,module=m,count=k) for n,m,k in GATES],
        provider_controls=2,containment_controls=1,complete_safety_control_count=EXPECTED_CONTROLS,
        implementation_bindings={n:sha(HERE/n) for n in SOURCES},
        component_bindings={p.relative_to(ROOT).as_posix():sha(p) for p in COMPONENTS},
        artifact_bindings={p.relative_to(ROOT).as_posix():sha(p) for p in ARTIFACTS},
        diagnostic_questions=[
            "Does earlier baseline handoff change challenge failure versus warning-time baseline handoff?",
            "Does the unchanged selected actor recover from challenge-generated states at either handoff time?",
            "Do fresh pure-controller outcomes and identical pre-handoff histories support the paired comparison?"],
        outcome_rules=dict(
            prefix="exact native trace equality before handoff and identical native observation at handoff",
            controls="fresh selected-only, challenge-only and baseline-only setup in both conditions",
            comparison="retain every outcome; quality difference only when both eligible; failure-time difference only when both fail",
            negative_quality=None,minimum_lead_for_safety_claim=None,
            latch="one handoff until the horizon; unsupported still refuses to baseline"),
        coverage=["production baseline/composition/public v1 resolver/native targets",
            "unchanged selected and challenge actors plus unchanged full-data warning",
            "scheduled versus natural trigger and baseline versus selected recovery",
            "actual resolved history and slew through the handoff; immediate baseline refusal",
            "complete native state/force/timing capture, other-core replay and paired-prefix checks",
            "fixed fourteen-world population including ordinary negative outcomes"],
        not_covered=["reentry from recovery to challenge","reserved calibration/evaluation starts",
            "a learned recovery region or safe backup proof","warning probability calibration",
            "Tier 3 memory benefit","other engines or morphologies","multi-seed robustness","qualification or release"],
        controller_selection_authority=False,adaptation_benefit_established=False,
        tier2_qualified=False,tier3_benefit_established=False,**{k:False for k in FLAGS})


def declaration(lane="comparison"):
    value=read(CONTRACT)
    require(lane=="comparison" and value==expected_declaration(),"Recovery declaration/source bindings")
    return value


def trial_plans(c,stage="comparison"):
    require(stage=="comparison" and c["lane"]=="comparison","Recovery stage scope")
    plans=[]
    for group in c["groups"]:
        condition,start=group.split("_train_");start="train_"+start
        require(condition in ("left_075","nominal") and start=="train_001","Recovery exposed group boundary")
        for role in ROLES:
            plans.append(dict(trial_id="comparison_"+role+"_"+group,stage=stage,group_id=group,
                condition_id=condition,start_id=start,role=role,direction=None,sign=None,model_key="recovery",
                partition="development_comparison",mode=role,seed=c["seed"],nworld=1,arm="scalar_direct",
                training_data_authority=False,initial_native_lateral_velocity_m_s=dict(base.STARTS)[start]))
    return plans


def all_plans(c):
    plans=trial_plans(c)
    require(len(plans)==c["planned_cpu_worlds"]==14 and len({p["trial_id"] for p in plans})==14,
        "Recovery complete population")
    return plans


def stage_claim(folder,c,core):
    require(folder.name=="comparison","Recovery fixed stage")
    models=frozen_models(core);attempt=folder.parent.parent
    claim=dict(schema_version="locolemotion_residual_recovery_stage_v1",stage="comparison",lane=c["lane"],
        source_commit=read(attempt/"declaration.json")["source_commit"],contract_sha256=sha(CONTRACT),
        declaration_sha256=sha(attempt/"declaration.json"),gate_receipt_sha256=sha(attempt/"gate-receipt.json"),
        consumed_sha256=sha(attempt/"consumed.json"),models={k:v.sha256 for k,v in models.items()},
        trials=all_plans(c),planned_cpu_worlds=14,planned_gpu_worlds=0,training_data_scope=c["training_data_scope"])
    return claim,None,models


def prepare_stage(folder,c,core):
    folder.mkdir();claim,_,models=stage_claim(folder,c,core);(folder/"models").mkdir()
    for key,model in models.items():
        with (folder/"models"/(key+".json")).open("x",encoding="utf-8",newline="\n") as stream:
            stream.write(model.serialized)
    write_new(folder/"stage.json",claim)
    return load_stage(folder,c,core)


def load_stage(folder,c,core):
    expected,_,models=stage_claim(folder,c,core)
    require(read(folder/"stage.json")==expected,"Recovery stage claim")
    require(not (folder/"batch.json").exists() and not (folder/"update.json").exists(),"Recovery cannot fit")
    for key,model in models.items():
        path=folder/"models"/(key+".json")
        require("sha256:"+sha(path)==model.sha256 and read(path)==model.document(),"Recovery staged model")
    return expected,None,models


def score(controls,trace,c,*,training):
    require(training is False,"Recovery cannot fit")
    return base.score(controls,trace,c,training=False)


def assess_comparison(trials,c):
    plans=all_plans(c)
    require(len(trials)==len(plans) and all(all(r.get(k)==v for k,v in p.items())
        for r,p in zip(trials,plans,strict=True)),"Recovery comparison population")
    require(all(r["observations"] is None and r["comparison_data_used_for_training"] is False
        and (r["official_quality_m_s"] is not None) is r["diagnostic_eligible"] for r in trials),
        "Recovery comparison authority/failed quality")
    result=dict(groups=[],fixed_models_and_thresholds=True,reentry_permitted=False,
        tier2_qualified=False,tier3_benefit_established=False,safe_backup_established=False,release_authority=False)
    def quality_delta(a,b):
        return a["official_quality_m_s"]-b["official_quality_m_s"] if a["diagnostic_eligible"] and b["diagnostic_eligible"] else None
    def failure_delta(a,b):
        x,y=a["first_reward_failure"],b["first_reward_failure"]
        return x["time_s"]-y["time_s"] if x is not None and y is not None else None
    for group in c["groups"]:
        roles={r["role"]:r for r in trials if r["group_id"]==group}
        challenge,selected,baseline=[roles[k] for k in ("challenge_only","selected_only","baseline_only")]
        interventions=[]
        for mode in ROLES[3:]:
            row=roles[mode];prefix=row["paired_prefix"]
            require(prefix["identical_before_handoff"] is True and prefix["handoff_observation_identical"] is True
                and prefix["reference_trial_id"]==challenge["trial_id"],"Recovery paired prefix")
            interventions.append(dict(role=mode,eligible=row["diagnostic_eligible"],
                challenge_negative_and_intervention_eligible=not challenge["diagnostic_eligible"] and row["diagnostic_eligible"],
                quality_m_s=row["official_quality_m_s"],
                quality_change_from_selected_control_m_s=quality_delta(row,selected),
                quality_change_from_baseline_control_m_s=quality_delta(row,baseline),
                failure_time_change_from_challenge_s=failure_delta(row,challenge),
                first_failure=copy.deepcopy(row["first_reward_failure"]),
                recovery=copy.deepcopy(row["recovery"]),paired_prefix=copy.deepcopy(prefix)))
        result["groups"].append(dict(group_id=group,
            controls={key:dict(eligible=roles[key]["diagnostic_eligible"],quality_m_s=roles[key]["official_quality_m_s"],
                first_failure=copy.deepcopy(roles[key]["first_reward_failure"])) for key in ROLES[:3]},
            interventions=interventions,
            early_minus_warning_failure_time_s={destination:failure_delta(roles["early_"+destination],roles["warning_"+destination])
                for destination in ("baseline","selected")},
            selected_minus_baseline_failure_time_s={trigger:failure_delta(roles[trigger+"_selected"],roles[trigger+"_baseline"])
                for trigger in ("early","warning")}))
    return result


def validate_launch_records(folder,c,source):
    evidence=(ROOT.parent/"SporeSpore_Evidence").resolve(strict=True)
    folder=folder.resolve(strict=True);attempt=folder.parent.parent.parent
    require(folder.name=="physical" and folder.parent.name=="comparison" and folder.parent.parent.name=="stages"
        and attempt.parent==evidence and attempt.name.startswith("sdk2-residual-recovery-"),
        "Recovery durable output boundary")
    owner=read(attempt/"declaration.json");gate=read(attempt/"gate-receipt.json")
    counts={n:k for n,_,k in GATES};counts.update(provider=2,containment=1)
    require(owner["contract"]==c and owner["source_commit"]==source and owner["synthetic"] is False,
        "Recovery owner freeze")
    require(gate["ok"] is True and gate["source_commit"]==source and gate["safety_controls"]==counts
        and sum(counts.values())==c["complete_safety_control_count"]
        and gate["declaration_sha256"]==sha(attempt/"declaration.json")
        and gate["preflight"]["ok"] is True and gate["preflight"]["world_build_count"]==0
        and gate["preflight"]["solver_steps"]==0,"Recovery complete zero-world gate")
    require(read(attempt/"consumed.json")==dict(attempt_id=attempt.name,source_commit=source,lane=c["lane"],
        contract_sha256=sha(CONTRACT),declaration_sha256=sha(attempt/"declaration.json"),
        gate_receipt_sha256=sha(attempt/"gate-receipt.json"),trials=all_plans(c)),"Recovery consumed claim")
    return owner
