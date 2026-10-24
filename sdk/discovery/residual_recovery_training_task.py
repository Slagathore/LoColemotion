"""Prospective recovery learning on fresh challenge prefixes and frozen scaling."""
import copy
import json
from pathlib import Path

import residual_training_task as training
import residual_recovery_task as predecessor
import residual_recovery_training_objective as objective
from adaptation_provider import bounded_residual_ars_fixed_v1 as fixed
from residual_recovery_task import ROOT,HERE,FLAGS,sha,require,provider,bridge,read,initial_arrays,controller_contract
from gpu_measurement_probe import write_new

actor=provider.actor_provider
ars=actor.ars
CONTRACT=HERE/"residual_recovery_training_v1.json"
CLOSURE=HERE/"residual_recovery_closure_v1.json"
SOURCES=("residual_recovery_training_task.py","residual_recovery_training_native.py",
    "audit_residual_recovery_training.py","run_residual_recovery_training.py","test_residual_recovery_training.py")
COMPONENTS=(Path(fixed.__file__),Path(objective.__file__),HERE/"test_residual_recovery_training_component.py",
    HERE/"run_residual_recovery_training_component.py")
ARTIFACTS=(predecessor.CONTRACT,CLOSURE,*predecessor.ARTIFACTS)
GATES=(*predecessor.GATES,("recovery-closure","test_residual_recovery_closure",10),
    ("recovery-training-component","test_residual_recovery_training_component",18),
    ("recovery-training","test_residual_recovery_training",24))
EXPECTED_CONTROLS=sum(n for _,_,n in GATES)+3
ROLES=("challenge_only","initial_recovery","trained_final","training_selected")


def expected_declaration():
    old=predecessor.declaration()
    fields=("core_sha256","baseline_core_sha256","runtime","model_xml_sha256","descriptor_sha256",
        "policy_id","stability_policy_id","phase_mode","internal_steps_per_outer","timestep_s",
        "controller_dt_s","warmup_outer_steps","initial_values","cpu_warning_count","naconmax",
        "naconmax_per_world","njmax","selection","conditions","condition_model_sha256","training_starts",
        "reserved_starts","excluded_confirmation_starts","reward","official_quality","maximum_trace_bytes_per_trial",
        "provider_definition","source_host","challenge_actor_sha256","warning_model_sha256")
    return dict({k:copy.deepcopy(old[k]) for k in fields},
        schema_version="locolemotion_residual_recovery_training_v1",
        ledger_scope=dict(subsystem="adaptation",engine_scope="mujoco_cpu",
            authority_mode="bounded_recovery_development_training",question_class="development"),
        warm_start_recovery_actor_sha256=old["recovery_actor_sha256"],
        predecessor_closure_sha256=sha(CLOSURE),warm_start_model_sha256="sha256:"+sha(predecessor.MODEL),
        lanes=dict(route=dict(seed=104240901,outer_steps=120,horizon_s=1.,iterations=1,directions=1,
                groups=["left_075_train_001"],planned_cpu_worlds=7,official_quality_enabled=False,
                training_data_scope="recovery_execution_fixture_only"),
            pilot=dict(seed=104241001,outer_steps=1440,horizon_s=12.,iterations=2,directions=2,
                groups=[condition+"_"+start for condition in ("left_075","nominal") for start,_ in training.STARTS],
                planned_cpu_worlds=112,official_quality_enabled=True,
                training_data_scope="bounded_eight_group_recovery_training")),
        comparison_roles=list(ROLES),handoff_command=60,reentry_permitted=False,
        recovery_objective=copy.deepcopy(objective.OBJECTIVE),
        optimizer=dict(noise_scale=.02,step_size=.01,selected_directions="all",
            initial_weights="unchanged selected exposed training artifact",
            normalizer="warm-start moments frozen byte-for-byte through every update",
            observed_moments="all mechanically supported rows, retained diagnostically but never deployed",
            perturbations="stored lossless antithetic Gaussian",seed_rule="lane seed plus iteration",
            route_data_may_initialize_pilot=False,comparison_data_may_fit=False),
        candidate_selection=dict(rule=objective.SELECTION_RULE,population="all complete training perturbations from all iterations",
            initial_and_final_checkpoint_in_selection=False,comparison_data_may_select=False,
            every_candidate_group_required=True),
        finite_screen="All eight training-selected recovery comparisons eligible through the full horizon. Fixed final checkpoint and initial recovery are separate retained controls; no comparison-based reselection.",
        reference="fresh challenge-only trial per group in every stage; exact prefix and handoff observation required",
        invalid_rollout="retain attempt, reject complete update, and leave remaining stages unopened",
        ordinary_negative="retain complete horizon and failure-padded reward; never omit from fitting or selection",
        planned_gpu_worlds=0,calibration_worlds=0,evaluation_worlds=0,
        minimum_free_storage_bytes=100*2**30,maximum_worker_wall_seconds=4800,maximum_reader_wall_seconds=4800,
        safety_controls=[dict(name=n,module=m,count=k) for n,m,k in GATES],
        provider_controls=2,containment_controls=1,complete_safety_control_count=EXPECTED_CONTROLS,
        implementation_bindings={n:sha(HERE/n) for n in SOURCES},
        component_bindings={p.relative_to(ROOT).as_posix():sha(p) for p in COMPONENTS},
        artifact_bindings={p.relative_to(ROOT).as_posix():sha(p) for p in ARTIFACTS},
        coverage=["unchanged native stepping and other-core raw controller replay",
            "fresh challenge prefixes, actual action history and selected-actor handoff slew",
            "post-handoff objective, full failure padding and censored official quality",
            "fixed-normalizer updates with complete paired training populations",
            "prospective training-only selection and separate final/selected comparisons"],
        not_covered=["reserved calibration/evaluation","warning retuning","reentry",
            "safe backup proof","Tier 3 memory benefit","other engines or morphologies","qualification or release"],
        controller_selection_authority=False,adaptation_benefit_established=False,tier3_benefit_established=False,
        **{k:k=="training_data_authority" for k in FLAGS})


def declaration(lane):
    value=read(CONTRACT)
    require(value==expected_declaration() and lane in value["lanes"],"Recovery training declaration/source bindings")
    return dict(value,**value["lanes"][lane],lane=lane)


def stages(c):return [f"iteration_{i:02d}" for i in range(c["iterations"])]+["comparison"]


def candidate_keys(c):
    return tuple((d,s,f"d{d:02d}_"+("plus" if s==1 else "minus"))
        for d in range(c["directions"]) for s in (1,-1))


def candidate_ids(c):
    return tuple(f"iteration_{i:02d}/"+key for i in range(c["iterations"]) for _,_,key in candidate_keys(c))


def trial_plans(c,stage):
    require(stage in stages(c),"Recovery training stage")
    combinations=([(None,None,g,r,r) for g in c["groups"] for r in ROLES] if stage=="comparison" else
        [(None,None,g,"challenge_only","challenge_only") for g in c["groups"]]+
        [(d,s,g,"search",key) for d,s,key in candidate_keys(c) for g in c["groups"]])
    plans=[]
    for direction,sign,group,role,key in combinations:
        condition,start=group.split("_train_");start="train_"+start
        require(condition in ("left_075","nominal") and start in dict(training.STARTS),"Recovery training exposed group")
        model_key="initial_recovery" if role in ("challenge_only","initial_recovery") else key
        plans.append(dict(trial_id=stage+"_"+key+"_"+group,stage=stage,group_id=group,
            condition_id=condition,start_id=start,role=role,direction=direction,sign=sign,model_key=model_key,
            partition="training" if role=="search" else ("development_comparison" if stage=="comparison" else "development_reference"),
            mode="challenge_only" if role=="challenge_only" else "early_selected",
            seed=c["seed"],nworld=1,arm="scalar_direct",training_data_authority=role=="search",
            initial_native_lateral_velocity_m_s=dict(training.STARTS)[start]))
    return plans


def all_plans(c):
    plans=[p for stage in stages(c) for p in trial_plans(c,stage)]
    require(len(plans)==c["planned_cpu_worlds"] and len({p["trial_id"] for p in plans})==len(plans),
        "Recovery training complete population")
    return plans


def warm_model(core):return predecessor.frozen_models(core)["recovery"]


def ars_plan(c,iteration):
    require(type(iteration) is int and 0<=iteration<c["iterations"],"Recovery training iteration")
    return ars.Plan(iteration,c["seed"]+iteration,tuple(c["groups"]),c["directions"],c["directions"],
        c["optimizer"]["noise_scale"],c["optimizer"]["step_size"])


def composite(core,parent,policy,corpus):
    recovery=actor.FrozenModel.load(core,actor.artifact(policy,corpus))
    return provider.FrozenModel.load(core,provider.artifact(parent.actor,recovery,parent.warning))


def next_model(core,parent,policy,c,update_sha):
    return composite(core,parent,policy,dict(corpus_id="recovery_"+c["lane"]+"_training_v1",
        kind="development_training_checkpoint",source_record_sha256="sha256:"+update_sha,training_data_authority=True))


def stage_inputs(folder,c,core):
    stage=folder.name;require(stage in stages(c),"Recovery training stage identity")
    index=c["iterations"] if stage=="comparison" else int(stage.split("_")[1])
    warm=warm_model(core);parent=warm;previous=None
    if index:
        prior=folder.parent/f"iteration_{index-1:02d}"
        verify_update(prior,c,core,require_verification=True)
        parent=provider.FrozenModel.load(core,read(prior/"next-model.json"));previous=sha(prior/"verified-update.json")
    models={"initial_recovery":warm}
    if stage=="comparison":
        verify_selection(folder.parent.parent,c,core,require_verification=True)
        models.update(trained_final=parent,
            training_selected=provider.FrozenModel.load(core,read(folder.parent.parent/"selected-model.json")))
        batch=None
    else:
        batch=ars.ask(parent.recovery.policy,ars_plan(c,index))
        for direction,sign,key in candidate_keys(c):
            models[key]=composite(core,parent,batch.candidate(direction,sign),parent.recovery.document()["corpus"])
    return batch,models,parent.sha256,previous


def stage_claim(folder,c,core):
    batch,models,parent,previous=stage_inputs(folder,c,core);attempt=folder.parent.parent
    claim=dict(schema_version="locolemotion_recovery_training_stage_v1",stage=folder.name,lane=c["lane"],
        source_commit=read(attempt/"declaration.json")["source_commit"],contract_sha256=sha(CONTRACT),
        declaration_sha256=sha(attempt/"declaration.json"),gate_receipt_sha256=sha(attempt/"gate-receipt.json"),
        consumed_sha256=sha(attempt/"consumed.json"),parent_model_sha256=parent,
        previous_verified_update_sha256=previous,batch_sha256=batch.sha256 if batch else None,
        models={k:m.sha256 for k,m in models.items()},trials=trial_plans(c,folder.name),
        planned_cpu_worlds=len(trial_plans(c,folder.name)),planned_gpu_worlds=0,
        training_data_scope=c["training_data_scope"],
        verified_selection_sha256=sha(attempt/"verified-selection.json") if folder.name=="comparison" else None)
    return claim,batch,models


def prepare_stage(folder,c,core):
    folder.mkdir();claim,batch,models=stage_claim(folder,c,core);(folder/"models").mkdir()
    for key,model in models.items():
        with (folder/"models"/(key+".json")).open("x",encoding="utf-8",newline="\n") as stream:stream.write(model.serialized)
    if batch:write_new(folder/"batch.json",training.batch_document(batch))
    write_new(folder/"stage.json",claim)
    return load_stage(folder,c,core)


def load_stage(folder,c,core):
    expected,batch,models=stage_claim(folder,c,core)
    require(read(folder/"stage.json")==expected,"Recovery training stage claim")
    for key,model in models.items():
        p=folder/"models"/(key+".json")
        require("sha256:"+sha(p)==model.sha256 and read(p)==model.document(),"Recovery training staged model")
    if batch:require(read(folder/"batch.json")==training.batch_document(batch),"Recovery training stored perturbations")
    else:require(not (folder/"batch.json").exists(),"Recovery comparison cannot fit")
    return expected,batch,models


def score(controls,trace,c,*,training):return objective.score(controls,trace,c,training=training)


def update_from_audit(batch,audit,c,stage):
    plans=trial_plans(c,stage);trials=audit["trials"]
    require(stage!="comparison" and audit["ok"] is True and audit["synthetic"] is False
        and audit["stage"]==stage and audit["training_data_scope"]==c["training_data_scope"]
        and len(trials)==len(plans) and all(all(r.get(k)==v for k,v in p.items())
            for p,r in zip(plans,trials,strict=True)),"Recovery training audited update population")
    rollouts=[]
    for plan,row in zip(plans,trials,strict=True):
        if plan["role"]!="search":
            require(row["observations"] is None and row["training_data_authority"] is False,"Recovery reference cannot fit")
            continue
        policy=batch.candidate(plan["direction"],plan["sign"])
        require(row["recovery_policy_sha256"]==policy.sha256
            and row["reward_denominator"]==(c["outer_steps"]-60)*5
            and -1.<=row["training_reward"]<=0. and row["paired_prefix"]["identical_before_handoff"] is True
            and row["paired_prefix"]["handoff_observation_identical"] is True,"Recovery training policy/reward/prefix")
        rollouts.append(ars.Rollout(batch.sha256,policy.sha256,plan["direction"],plan["sign"],plan["group_id"],
            plan["partition"],plan["trial_id"],row["training_reward"],training.load_moments(row["observations"])))
    return fixed.tell(batch,rollouts)


def updated_artifacts(folder,c,core):
    claim,batch,models=load_stage(folder,c,core);require(batch is not None,"Recovery comparison cannot update")
    audit=read(folder/"audit.json")
    require(audit["stage_claim_sha256"]==sha(folder/"stage.json") and audit["source_commit"]==claim["source_commit"]
        and audit["reader_world_build_count"]==audit["reader_solver_steps"]==0,"Recovery training audited stage binding")
    policy,update=update_from_audit(batch,audit,c,folder.name)
    record=training.document(dict(schema_version="locolemotion_recovery_training_update_v1",ledger_scope=c["ledger_scope"],
        source_commit=claim["source_commit"],lane=c["lane"],stage=folder.name,training_data_scope=c["training_data_scope"],
        stage_claim_sha256=sha(folder/"stage.json"),audit_sha256=sha(folder/"audit.json"),
        batch_file_sha256=sha(folder/"batch.json"),update=update,synthetic=False,
        **{k:k=="training_data_authority" for k in FLAGS}))
    return policy,record,models["initial_recovery"]


def write_update(folder,c,core):
    policy,record,warm=updated_artifacts(folder,c,core);write_new(folder/"update.json",record)
    model=next_model(core,warm,policy,c,sha(folder/"update.json"))
    with (folder/"next-model.json").open("x",encoding="utf-8",newline="\n") as stream:stream.write(model.serialized)


def verify_update(folder,c,core,*,require_verification=False):
    policy,record,warm=updated_artifacts(folder,c,core)
    require(read(folder/"update.json")==record,"Recovery training update reconstruction")
    model=next_model(core,warm,policy,c,sha(folder/"update.json"))
    require(read(folder/"next-model.json")==model.document() and "sha256:"+sha(folder/"next-model.json")==model.sha256
        and policy.moments==warm.recovery.policy.moments,"Recovery training frozen scaling/checkpoint")
    result=dict(ok=True,stage=folder.name,lane=c["lane"],update_sha256=sha(folder/"update.json"),
        model_sha256=model.sha256,recovery_policy_sha256=policy.sha256,audit_sha256=sha(folder/"audit.json"),
        normalizer_updated=False,world_build_count=0,solver_steps=0,physical_acceptance_authority=False,release_authority=False)
    if require_verification:require(read(folder/"verified-update.json")==result,"Recovery missing/crossed verified update")
    return result


def selected_artifacts(attempt,c,core):
    candidates=[];origins={};bindings=[]
    for i in range(c["iterations"]):
        stage=f"iteration_{i:02d}";folder=attempt/"stages"/stage
        verify_update(folder,c,core,require_verification=True)
        claim,_,models=load_stage(folder,c,core);audit=read(folder/"audit.json")
        require(audit["ok"] is True and audit["synthetic"] is False
            and audit["source_commit"]==claim["source_commit"] and audit["stage_claim_sha256"]==sha(folder/"stage.json"),
            "Recovery selection original audit")
        bindings.append(dict(stage=stage,audit_sha256=sha(folder/"audit.json"),verified_update_sha256=sha(folder/"verified-update.json")))
        for _,_,key in candidate_keys(c):
            identity=stage+"/"+key;model=models[key];origins[identity]=folder/"models"/(key+".json")
            candidates.append(dict(candidate_id=identity,model_sha256=model.sha256,policy_sha256=model.recovery.policy.sha256,
                trials=[r for r in audit["trials"] if r["role"]=="search" and r["model_key"]==key]))
    selected=objective.select(candidates,tuple(c["groups"]),candidate_ids(c),(c["outer_steps"]-60)*5)
    path=origins[selected["selected_candidate_id"]];model=provider.FrozenModel.load(core,read(path))
    require(model.sha256==selected["selected_model_sha256"] and "sha256:"+sha(path)==model.sha256,
        "Recovery selected original bytes")
    record=dict(schema_version="locolemotion_recovery_training_selection_v1",ledger_scope=c["ledger_scope"],
        source_commit=read(attempt/"declaration.json")["source_commit"],lane=c["lane"],
        training_data_scope=c["training_data_scope"],contract_sha256=sha(CONTRACT),
        stage_bindings=bindings,selection=selected,selected_source=path.relative_to(attempt).as_posix(),
        synthetic=False,**{k:k=="training_data_authority" for k in FLAGS})
    return record,model


def write_selection(attempt,c,core):
    record,model=selected_artifacts(attempt,c,core);write_new(attempt/"training-selection.json",record)
    with (attempt/"selected-model.json").open("x",encoding="utf-8",newline="\n") as stream:stream.write(model.serialized)


def verify_selection(attempt,c,core,*,require_verification=False):
    record,model=selected_artifacts(attempt,c,core)
    require(read(attempt/"training-selection.json")==record and read(attempt/"selected-model.json")==model.document()
        and "sha256:"+sha(attempt/"selected-model.json")==model.sha256,"Recovery training selection reconstruction")
    result=dict(ok=True,lane=c["lane"],selection_sha256=sha(attempt/"training-selection.json"),
        model_sha256=model.sha256,world_build_count=0,solver_steps=0,
        comparison_data_used_for_selection=False,physical_acceptance_authority=False,release_authority=False)
    if require_verification:require(read(attempt/"verified-selection.json")==result,"Recovery missing verified selection")
    return result


def assess_comparison(trials,c):
    plans=trial_plans(c,"comparison")
    require(len(trials)==len(plans) and all(all(r.get(k)==v for k,v in p.items())
        for p,r in zip(plans,trials,strict=True)),"Recovery training comparison population")
    require(all(r["observations"] is None and r["comparison_data_used_for_training"] is False
        and (r["diagnostic_eligible"] or r["official_quality_m_s"] is None) for r in trials),
        "Recovery training comparison fitting/failed quality")
    groups=[]
    for group in c["groups"]:
        rows={r["role"]:r for r in trials if r["group_id"]==group}
        require(set(rows)==set(ROLES),"Recovery training comparison roles")
        ref=rows["challenge_only"]
        for key in ROLES[1:]:
            p=rows[key]["paired_prefix"]
            require(p["identical_before_handoff"] is True and p["handoff_observation_identical"] is True
                and p["reference_trial_id"]==ref["trial_id"],"Recovery training fresh comparison prefix")
        groups.append(dict(group_id=group,roles={key:dict(eligible=r["diagnostic_eligible"],
            recovery_reward=r["training_reward"],official_quality_m_s=r["official_quality_m_s"],
            first_failure=r["first_reward_failure"],model_sha256=r["provider_model_sha256"]) for key,r in rows.items()}))
    selected=[r for r in trials if r["role"]=="training_selected"]
    return dict(groups=groups,selected_eligible=sum(r["diagnostic_eligible"] for r in selected),
        selected_total=len(selected),finite_development_screen_passed=all(r["diagnostic_eligible"] for r in selected),
        comparison_data_used_for_selection=False,tier2_qualified=False,tier3_benefit_established=False,
        safe_backup_established=False,release_authority=False)


def validate_launch_records(folder,c,source):
    evidence=(ROOT.parent/"SporeSpore_Evidence").resolve(strict=True);folder=folder.resolve(strict=True)
    attempt=folder.parent.parent.parent
    require(folder.name=="physical" and folder.parent.name in stages(c) and folder.parent.parent.name=="stages"
        and attempt.parent==evidence and attempt.name.startswith("sdk2-recovery-training-"),"Recovery training durable output")
    owner=read(attempt/"declaration.json");gate=read(attempt/"gate-receipt.json")
    counts={n:k for n,_,k in GATES};counts.update(provider=2,containment=1)
    require(owner["contract"]==c and owner["source_commit"]==source and owner["synthetic"] is False,"Recovery training owner freeze")
    require(gate["ok"] is True and gate["source_commit"]==source and gate["safety_controls"]==counts
        and sum(counts.values())==c["complete_safety_control_count"]
        and gate["declaration_sha256"]==sha(attempt/"declaration.json")
        and gate["preflight"]["ok"] is True and gate["preflight"]["world_build_count"]==gate["preflight"]["solver_steps"]==0,
        "Recovery training complete zero-world gate")
    require(read(attempt/"consumed.json")==dict(attempt_id=attempt.name,source_commit=source,lane=c["lane"],
        contract_sha256=sha(CONTRACT),declaration_sha256=sha(attempt/"declaration.json"),
        gate_receipt_sha256=sha(attempt/"gate-receipt.json"),trials=all_plans(c)),"Recovery training consumed claim")
    return owner
