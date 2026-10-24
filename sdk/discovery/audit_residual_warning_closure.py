"""Verify retained warning-fit closure without repeating fitting or controller replay."""
from pathlib import Path
import json

import residual_warning_fit as fit
from run_residual_training import inventory
from run_residual_native import verify_tests

ROOT,HERE=fit.ROOT,fit.HERE
read,sha,require=fit.read,fit.sha,fit.require
CLOSURE=HERE/"residual_warning_closure_v1.json"
MODEL=HERE/"residual_warning_model_v1.json"
ATTEMPT="sdk2-residual-warning-fit-181bfb8ddc6d48ecaa78aec031294cab"
RECEIPT_SHA="1751edcf121cbc7b0ac2ff855219d6c14fdca243b3a7316bf7a61844fff80f9d"
SOURCE="b01f3e84f21c050cc249689e153083bf7af49c5b"


def validate_owner(receipt):
    require(receipt["ok"] is True and receipt["source_commit"]==SOURCE
        and receipt["physical_started"] is False and receipt["worlds_opened"]==receipt["solver_steps"]==0
        and receipt["controls_passed"]==receipt["controls_planned"]==20
        and receipt["reader_corruption_controls_passed"]==8
        and receipt["source_runtime_unchanged"] is True
        and receipt["planned_training_episodes"]==64 and receipt["planned_rows"]==92160
        and receipt["planned_cpu_worlds"]==receipt["planned_gpu_worlds"]==0
        and all(receipt[k] is False for k in ("physical_acceptance_authority","release_authority",
            "automatic_withdrawal_authority","tier2_complete","tier3_complete")),"Warning fit owner scope")


def expected():
    evidence=(ROOT.parent/"SporeSpore_Evidence").resolve(strict=True)
    folder=(evidence/ATTEMPT).resolve(strict=True)
    require(folder.parent==evidence and sha(folder/"receipt.json")==RECEIPT_SHA,"Warning owner identity")
    receipt=read(folder/"receipt.json");validate_owner(receipt)
    require(receipt["artifacts"]==inventory(folder),"Warning complete retained artifact inventory")
    declaration=read(folder/"declaration.json")
    require(sha(folder/"declaration.json")==receipt["declaration_sha256"]
        and declaration["recipe"]==fit.recipe(),"Warning declaration/source recipe")
    for path in (folder/"source").rglob("*"):
        if path.is_file():
            relative=path.relative_to(folder/"source").as_posix()
            require(sha(path)==declaration["binding"]["source"][relative]==sha(ROOT/relative),
                "Warning retained/current component bytes")
    verify_tests(folder/"controls",20)
    audit=read(folder/"audit.json");manifest=read(folder/"fit/data-manifest.json");result=read(folder/"fit/fit.json")
    require(sha(folder/"audit.json")==receipt["audit_sha256"]
        and sha(folder/"fit/fit.json")==receipt["fit_sha256"]==audit["fit_sha256"]
        and audit["ok"] is True and audit["reader_world_build_count"]==audit["reader_solver_steps"]==0
        and audit["training_episodes_reopened"]==64 and audit["controller_rows_reopened"]==92160
        and audit["internal_rows_reopened"]==460800 and len(audit["corruption_controls_passed"])==8
        and manifest["dataset_sha256"]==receipt["dataset_sha256"]==audit["dataset_sha256"]
        and manifest["training_trial_count"]==64 and manifest["eligible_episodes"]==15
        and manifest["failed_episodes"]==49,"Warning independent full reconstruction")
    require(audit["artifacts"]=={p.name:sha(p) for p in sorted((folder/"fit").iterdir())},
        "Warning audit artifact bindings")
    require(MODEL.read_bytes()==(folder/"fit/model-full.json").read_bytes(),"Warning published model bytes")
    full=fit.warning.FrozenWarning.load(read(MODEL))
    require(full.sha256==receipt["final_model_sha256"]==audit["final_model_sha256"]==result["full_fit"]["model_sha256"],
        "Warning frozen model identity")
    cross=result["crossfit_tuned_threshold_diagnostics"];final=result["full_fit_diagnostics"]
    compact=lambda value:{k:v for k,v in value.items() if k!="trials"}
    return dict(schema_version="locolemotion_residual_warning_closure_v1",ledger_scope=fit.SCOPE,
        status="complete_development_shadow_fit",source_base_commit=SOURCE,
        component_source_status="new component captured byte-exact before publication; zero-world development",
        definition_path=fit.warning.CONTRACT.relative_to(ROOT).as_posix(),definition_sha256=sha(fit.warning.CONTRACT),
        recipe_path=fit.CONTRACT.relative_to(ROOT).as_posix(),recipe_sha256=sha(fit.CONTRACT),
        parent_closure_path=fit.data.selection.PARENT.relative_to(ROOT).as_posix(),
        parent_closure_sha256=fit.data.selection.PARENT_SHA,
        attempt_id=ATTEMPT,receipt_sha256=RECEIPT_SHA,declaration_sha256=receipt["declaration_sha256"],
        audit_sha256=receipt["audit_sha256"],fit_sha256=receipt["fit_sha256"],
        model_path=MODEL.relative_to(ROOT).as_posix(),model_file_sha256=sha(MODEL),
        final_model_sha256=full.sha256,dataset_sha256=receipt["dataset_sha256"],
        component_controls_passed=20,reader_corruption_controls_passed=8,
        source_binding_count=receipt["source_binding_count"],runtime_binding_count=receipt["runtime_binding_count"],
        retained_artifact_count=len(receipt["artifacts"]),retained_artifact_bytes=sum(r["byte_length"] for r in receipt["artifacts"]),
        training_trial_count=64,eligible_episodes=15,failed_episodes=49,
        controller_rows=92160,internal_rows=460800,row_categories=manifest["row_categories"],
        original_mechanical_feature_rows=manifest["original_mechanical_feature_rows"],
        threshold=result["threshold"],hysteresis_exit_offset=.05,reentry_commands=30,
        crossfit_tuned_threshold_diagnostics=compact(cross),full_fit_diagnostics=compact(final),
        first_warning_lead_s={name:dict(minimum=min(r["first_warning_lead_s"] for r in value["trials"] if not r["diagnostic_eligible"]),
            maximum=max(r["first_warning_lead_s"] for r in value["trials"] if not r["diagnostic_eligible"]))
            for name,value in (("crossfit",cross),("full_fit",final))},
        selected_training_episode_diagnostics=[r for r in final["trials"] if r["candidate_id"]=="iteration_00/d00_plus"],
        alternate_numerical_solver=audit["alternate_solver"],
        worlds_opened=0,solver_steps=0,comparison_trials_used=0,route_trials_used=0,reserved_starts_opened=0,
        excluded_confirmation_trials_used=0,controller_replay_repeated=False,
        reader_scope="verify retained complete reconstruction and all artifact bytes; no new fit or raw controller replay",
        warning_score_is_probability=False,threshold_has_independent_validation=False,
        safe_backup_established=False,automatic_withdrawal_authority=False,
        physical_acceptance_authority=False,tier2_complete=False,tier3_complete=False,release_authority=False)


def validate(value,expected_value=None):
    require(value==(expected_value if expected_value is not None else expected()),"Warning closure exact derivation")
    return True
