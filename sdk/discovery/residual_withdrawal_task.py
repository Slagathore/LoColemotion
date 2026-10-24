"""Prospective native withdrawal diagnostics on two exposed development groups."""
import copy
from pathlib import Path

import residual_training_task as base
import residual_selection as selection
import residual_selection_task as predecessor
from residual_training_task import ROOT,HERE,FLAGS,sha,require,bridge,read,initial_arrays
from adaptation_provider.warning import control_v1 as provider
from residual_withdrawal_control import expected_provider
from gpu_measurement_probe import write_new

CONTRACT=HERE/"residual_withdrawal_v1.json"
MODEL=HERE/"residual_withdrawal_model_v1.json"
CHALLENGE=HERE/"residual_withdrawal_challenge_v1.json"
WARNING=HERE/"residual_warning_model_v1.json"
WARNING_CLOSURE=HERE/"residual_warning_closure_v1.json"
SELECTION_CLOSURE=HERE/"residual_selection_closure_v1.json"
SOURCES=("residual_withdrawal_task.py","residual_withdrawal_native.py",
    "audit_residual_withdrawal.py","run_residual_withdrawal.py",
    "residual_withdrawal_metrics.py","test_residual_withdrawal.py")
COMPONENTS=(Path(provider.__file__),provider.CONTRACT,HERE/"residual_withdrawal_control.py",
    HERE/"test_residual_withdrawal_provider.py",HERE/"run_residual_withdrawal_component.py")
ARTIFACTS=(MODEL,CHALLENGE,WARNING,WARNING_CLOSURE,SELECTION_CLOSURE,selection.FIT,selection.MODEL,selection.PARENT)
GATES=(*predecessor.GATES,("warning","test_residual_warning",20),
    ("warning-closure","test_residual_warning_closure",6),
    ("selection-closure","test_residual_selection_closure",8),
    ("withdrawal-provider","test_residual_withdrawal_provider",26),
    ("withdrawal-native","test_residual_withdrawal",20))
EXPECTED_CONTROLS=sum(n for _,_,n in GATES)+3
ROLES=(("selected_shadow","selected","shadow"),("selected_guarded","selected","frozen"),
    ("selected_forced","selected","forced_route"),("challenge_shadow","challenge","shadow"),
    ("challenge_guarded","challenge","frozen"))
CHALLENGE_ACTOR="sha256:868fcd240a78dcee1aa98cc2653cd22b0463f92815e1216989800625cdec9d33"


def controller_contract(c,model):
    return dict(c,provider=expected_provider(model))


def frozen_models(core):
    selected=selection.verify_fit(core)[1]
    _,population,_=selection.retained_population()
    source=next(r for r in population if r["stage"]=="iteration_00" and r["model_key"]=="d00_minus")
    require(source["provider_model_sha256"]==CHALLENGE_ACTOR
        and len(source["trials"])==8 and not any(r["diagnostic_eligible"] for r in source["trials"]),
        "Withdrawal retrospective challenge identity")
    challenge=provider.actor_provider.FrozenModel.load(core,read(source["model_path"]))
    warning=provider.warning.FrozenWarning.load(read(WARNING))
    models={}
    for name,path,actor in (("selected",MODEL,selected),("challenge",CHALLENGE,challenge)):
        document=provider.artifact(actor,warning)
        require(read(path)==document,"Withdrawal crossed actor/warning artifact")
        model=provider.FrozenModel.load(core,document)
        require(path.read_text(encoding="utf-8")==model.serialized
            and "sha256:"+sha(path)==model.sha256,"Withdrawal composite exact bytes")
        models[name]=model
    return models


def expected_declaration():
    old=predecessor.expected_declaration()
    fields=("core_sha256","baseline_core_sha256","runtime","model_xml_sha256","descriptor_sha256",
        "policy_id","stability_policy_id","phase_mode","internal_steps_per_outer","timestep_s",
        "controller_dt_s","warmup_outer_steps","initial_values","cpu_warning_count","naconmax",
        "naconmax_per_world","njmax","selection","conditions","condition_model_sha256",
        "training_starts","reserved_starts","excluded_confirmation_starts","reward","official_quality",
        "maximum_trace_bytes_per_trial")
    return dict({k:copy.deepcopy(old[k]) for k in fields},
        schema_version="locolemotion_residual_withdrawal_native_v1",
        ledger_scope=dict(subsystem="adaptation",engine_scope="mujoco_cpu",
            authority_mode="frozen_warning_intervention_development",question_class="development"),
        lane="comparison",seed=104240701,outer_steps=1440,horizon_s=12.,
        groups=["left_075_train_001","nominal_train_001"],
        comparison_roles=[r for r,_,_ in ROLES],planned_cpu_worlds=10,planned_gpu_worlds=0,
        calibration_worlds=0,evaluation_worlds=0,official_quality_enabled=True,
        training_data_scope="none_frozen_warning_intervention_diagnostic",
        provider_definition=provider.definition(),forced_request_command=provider.FORCED_COMMAND,
        source_host=dict(path="sdk/discovery/residual_withdrawal_control.py",
            sha256=sha(HERE/"residual_withdrawal_control.py")),
        selected_model_sha256="sha256:"+sha(MODEL),challenge_model_sha256="sha256:"+sha(CHALLENGE),
        challenge_actor_sha256=CHALLENGE_ACTOR,challenge_source_candidate="iteration_00/d00_minus",
        challenge_choice_is_retrospective=True,warning_model_sha256=provider.warning.digest(read(WARNING)),
        selection_record_sha256=sha(selection.FIT),predecessor_closure_sha256=sha(SELECTION_CLOSURE),
        warning_closure_sha256=sha(WARNING_CLOSURE),preserve_weights_and_thresholds=True,
        comparison_data_may_fit=False,forced_request_changes_prediction=False,
        intervention_success_is_completion_requirement=False,safe_backup_established=False,
        confidence_is_calibrated=False,minimum_free_storage_bytes=20*2**30,
        maximum_worker_wall_seconds=3600,maximum_reader_wall_seconds=3600,
        safety_controls=[dict(name=n,module=m,count=k) for n,m,k in GATES],
        provider_controls=2,containment_controls=1,complete_safety_control_count=EXPECTED_CONTROLS,
        implementation_bindings={n:sha(HERE/n) for n in SOURCES},
        component_bindings={p.relative_to(ROOT).as_posix():sha(p) for p in COMPONENTS},
        artifact_bindings={p.relative_to(ROOT).as_posix():sha(p) for p in ARTIFACTS},
        diagnostic_questions=[
            "Does a silent guard preserve the selected shadow trajectory exactly?",
            "Does an explicit request at command 90 reach baseline immediately and permit natural hysteresis reentry?",
            "Does the frozen warning intervene before the known challenge fails, and what happens afterward?"],
        outcome_rules=dict(
            silent_preservation="report exact native trace equality only when both selected monitors remain clear",
            forced_route="report actual fallback, clear-command count and first reentry; do not require recovery",
            challenge="retain both outcomes; quality change only if both eligible; failure-time change only if both fail",
            negative_quality=None,minimum_lead_for_safety_claim=None),
        coverage=["production baseline/composition/public v1 resolver/native targets",
            "both frozen actor identities with the same unchanged full-data warning",
            "complete native state/force/timing capture and independent baseline-core decision replay",
            "actual resolved history through immediate baseline fallback and hysteresis reentry",
            "fixed ten-world population, including all ordinary negative outcomes"],
        not_covered=["bare baseline or disabled native worlds in this campaign; covered by predecessor and zero-world controls",
            "reserved calibration/evaluation starts","safe backup or verified intervention lead",
            "warning probability calibration","Tier 3 memory benefit","other engines or morphologies",
            "multi-seed robustness","qualification or release"],
        controller_selection_authority=False,adaptation_benefit_established=False,
        tier2_qualified=False,tier3_benefit_established=False,**{k:False for k in FLAGS})


def declaration(lane="comparison"):
    value=read(CONTRACT)
    require(lane=="comparison" and value==expected_declaration(),"Withdrawal declaration/source bindings")
    return value


def trial_plans(c,stage="comparison"):
    require(stage=="comparison" and c["lane"]=="comparison","Withdrawal stage scope")
    plans=[]
    for group in c["groups"]:
        condition,start=group.split("_train_");start="train_"+start
        require(condition in ("left_075","nominal") and start=="train_001","Withdrawal exposed group boundary")
        for role,model,mode in ROLES:
            plans.append(dict(trial_id="comparison_"+role+"_"+group,stage=stage,group_id=group,
                condition_id=condition,start_id=start,role=role,direction=None,sign=None,model_key=model,
                partition="development_comparison",mode=mode,seed=c["seed"],nworld=1,arm="scalar_direct",
                training_data_authority=False,initial_native_lateral_velocity_m_s=dict(base.STARTS)[start]))
    return plans


def all_plans(c):
    plans=trial_plans(c)
    require(len(plans)==c["planned_cpu_worlds"]==10 and len({p["trial_id"] for p in plans})==10,
        "Withdrawal complete population")
    return plans


def stage_claim(folder,c,core):
    require(folder.name=="comparison","Withdrawal fixed stage")
    models=frozen_models(core);attempt=folder.parent.parent
    claim=dict(schema_version="locolemotion_residual_withdrawal_stage_v1",stage="comparison",lane=c["lane"],
        source_commit=read(attempt/"declaration.json")["source_commit"],contract_sha256=sha(CONTRACT),
        declaration_sha256=sha(attempt/"declaration.json"),gate_receipt_sha256=sha(attempt/"gate-receipt.json"),
        consumed_sha256=sha(attempt/"consumed.json"),models={k:v.sha256 for k,v in models.items()},
        trials=all_plans(c),planned_cpu_worlds=10,planned_gpu_worlds=0,training_data_scope=c["training_data_scope"])
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
    require(read(folder/"stage.json")==expected,"Withdrawal stage claim")
    require(not (folder/"batch.json").exists() and not (folder/"update.json").exists(),"Withdrawal cannot fit")
    for key,model in models.items():
        path=folder/"models"/(key+".json")
        require("sha256:"+sha(path)==model.sha256 and read(path)==model.document(),"Withdrawal staged model")
    return expected,None,models


def score(controls,trace,c,*,training):
    require(training is False,"Withdrawal cannot fit")
    return base.score(controls,trace,c,training=False)


def assess_comparison(trials,c):
    plans=all_plans(c)
    require(len(trials)==len(plans) and all(all(r.get(k)==v for k,v in p.items())
        for r,p in zip(trials,plans,strict=True)),"Withdrawal comparison population")
    require(all(r["observations"] is None and r["comparison_data_used_for_training"] is False
        and (r["official_quality_m_s"] is not None) is r["diagnostic_eligible"] for r in trials),
        "Withdrawal comparison authority/failed quality")
    result=dict(groups=[],fixed_models_and_thresholds=True,tier2_qualified=False,
        tier3_benefit_established=False,safe_backup_established=False,release_authority=False)
    for group in c["groups"]:
        roles={r["role"]:r for r in trials if r["group_id"]==group}
        shadow,guarded,forced,challenge,protected=[roles[r] for r,_,_ in ROLES]
        silent=all(r["withdrawal"]["monitor_withheld_commands"]==0 for r in (shadow,guarded))
        matching=shadow["raw_hashes"]["trace"]==guarded["raw_hashes"]["trace"]
        require(not silent or matching,"Withdrawal silent monitor changed native trajectory")
        q,bq=protected["official_quality_m_s"],challenge["official_quality_m_s"]
        f,bf=protected["first_reward_failure"],challenge["first_reward_failure"]
        result["groups"].append(dict(group_id=group,selected_shadow_eligible=shadow["diagnostic_eligible"],
            selected_guarded_eligible=guarded["diagnostic_eligible"],selected_monitors_silent=silent,
            selected_trace_identical=matching,selected_quality_change_m_s=(
                guarded["official_quality_m_s"]-shadow["official_quality_m_s"]
                if guarded["diagnostic_eligible"] and shadow["diagnostic_eligible"] else None),
            forced_eligible=forced["diagnostic_eligible"],forced_transition=copy.deepcopy(forced["withdrawal"]),
            challenge_shadow_eligible=challenge["diagnostic_eligible"],
            challenge_guarded_eligible=protected["diagnostic_eligible"],
            challenge_quality_change_m_s=q-bq if q is not None and bq is not None else None,
            challenge_failure_time_change_s=f["time_s"]-bf["time_s"] if f is not None and bf is not None else None,
            challenge_shadow_warning=copy.deepcopy(challenge["withdrawal"]),
            challenge_guarded_warning=copy.deepcopy(protected["withdrawal"])))
    return result


def validate_launch_records(folder,c,source):
    evidence=(ROOT.parent/"SporeSpore_Evidence").resolve(strict=True)
    folder=folder.resolve(strict=True);attempt=folder.parent.parent.parent
    require(folder.name=="physical" and folder.parent.name=="comparison" and folder.parent.parent.name=="stages"
        and attempt.parent==evidence and attempt.name.startswith("sdk2-residual-withdrawal-"),
        "Withdrawal durable output boundary")
    owner=read(attempt/"declaration.json");gate=read(attempt/"gate-receipt.json")
    counts={n:k for n,_,k in GATES};counts.update(provider=2,containment=1)
    require(owner["contract"]==c and owner["source_commit"]==source and owner["synthetic"] is False,
        "Withdrawal owner freeze")
    require(gate["ok"] is True and gate["source_commit"]==source and gate["safety_controls"]==counts
        and sum(counts.values())==c["complete_safety_control_count"]
        and gate["declaration_sha256"]==sha(attempt/"declaration.json")
        and gate["preflight"]["ok"] is True and gate["preflight"]["world_build_count"]==0
        and gate["preflight"]["solver_steps"]==0,"Withdrawal complete zero-world gate")
    require(read(attempt/"consumed.json")==dict(attempt_id=attempt.name,source_commit=source,lane=c["lane"],
        contract_sha256=sha(CONTRACT),declaration_sha256=sha(attempt/"declaration.json"),
        gate_receipt_sha256=sha(attempt/"gate-receipt.json"),trials=all_plans(c)),"Withdrawal consumed claim")
    return owner
