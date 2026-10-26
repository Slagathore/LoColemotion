"""Prospective finite search from exposed states of the consumed native refusal."""
import json
from pathlib import Path
from audit_prepared_predictive_model import ROOT,HERE,EVIDENCE,DLL,DLL_SHA,GATES as MODEL_GATES,read,sha,require
from audit_gpu_batch_execution import read_jsonl
from predictive_sequence_v1 import MAX_INTERVALS,KNOTS,CANDIDATES,ITERATIONS,SEED,SIGMA

CONTRACT=HERE/"predictive_sequence_v1.json"
CLOSURE_RESULT=HERE/"predictive_native_result_v1.json"
RESULT_SHA="e76c58e91ec0c77eaf862ab17024f8bf0713c1e94deabde0d2fbfdbfa4eb0651"
PARENT="sdk2-predictive-native-v1-13374a22f25c4d089c34045c96ec64f7"
PARENT_SHA="49809ddcbc8a9a0987325ae6b12a5344413359b7d11c30523bfc2bccb854fffc"
FOLDER=EVIDENCE/PARENT/"physical/predictive_hold_left_075_train_001"
STARTS=(60,72,84,96,108,114)
END_COMMAND=126
SOURCES=("predictive_sequence_v1.py","predictive_sequence_task_v1.py",
    "audit_predictive_sequence_v1.py","run_predictive_sequence_v1.py","test_predictive_sequence_v1.py")
GATES=(*MODEL_GATES,("sequence","test_predictive_sequence_v1",24))
CONTROLS=sum(n for _,_,n in GATES)
FLAGS=("trained","native_recovery_established","tier2_qualified","tier3_benefit_established",
    "training_data_authority","physical_acceptance_authority","release_authority","equivalence_authority")


def expected_contract():
    return dict(schema_version="locolemotion_predictive_sequence_contract_v1",
        ledger_scope=dict(subsystem="adaptation",engine_scope="core",
            authority_mode="finite_conditional_sequence_diagnosis",question_class="development"),
        parent_attempt=PARENT,parent_receipt_sha256=PARENT_SHA,parent_result_sha256=RESULT_SHA,
        parent_trial_id=FOLDER.name,starting_commands=list(STARTS),ending_command_exclusive=END_COMMAND,
        horizons=[END_COMMAND-s for s in STARTS],maximum_intervals=MAX_INTERVALS,
        control_points=KNOTS,interpolation="piecewise linear projected at every 120 Hz command",
        candidate_count=CANDIDATES,iterations=ITERATIONS,random_seed=SEED,gaussian_sigma=SIGMA,
        planned_search_evaluations=len(STARTS)*CANDIDATES*ITERATIONS,
        maximum_search_predicted_steps=sum(END_COMMAND-s for s in STARTS)*CANDIDATES*ITERATIONS*5,
        candidate_families="incumbent, zero correction, zero target, velocity brake, 16 coordinate bounds, 14 Gaussian spline perturbations",
        initial_incumbent="current nominal correction repeated at all four control points",
        selection="lexicographic full eligibility, descending admissible interval count, ascending mean original objective; first tie wins",
        incomplete_plans="optimization intermediates only; never eligible to apply",
        future_baseline="current deterministic baseline and speed limits held constant; future actual public envelopes not claimed equivalent",
        future_correction_limits=dict(absolute_rad_s=3.5,slew_rad_s=.08),
        final_application="none; this is a zero-world diagnosis, not public controller integration",
        calibration=dict(starting_commands=list(STARTS[:-1]),ending_command_exclusive=114,
            supplied_actions="retained actually applied sequence; retrospective diagnostic only",
            initial_state_only=True,subsequent_observations_used_as_inputs=False,
            errors_are_measurements_not_acceptance_thresholds=True),
        independent_reference="original Python predictor reruns each final best sequence and each recorded-action calibration",
        numerical_comparison="existing compiled-backend tolerances and exact guard/decision fields; iteration differences retained",
        safety_guard_source="predictive_command_selection_v2.py:guard unchanged for each five-step interval",
        source_bindings={n:sha(HERE/n) for n in SOURCES},
        inherited_source_bindings={n:sha(HERE/n) for n in ("prepared_predictive_model.py","predictive_command_selection_v2.py",
            "held_contact_rollout.py","predictive_numeric_backend.py","predictive_numeric_kernels.rs")},
        input_bindings={n:sha(FOLDER/n) for n in ("controller.jsonl","trace.jsonl","force-profile.json","model.xml","inputs.json")},
        dll_sha256=DLL_SHA,controls_required=CONTROLS,
        maximum_reader_wall_seconds=7200,minimum_free_storage_bytes=64*2**30,
        maximum_capture_bytes=8*2**30,maximum_capture_row_bytes=16*2**20,
        primary_research=dict(url="https://arxiv.org/html/2212.00541v2",
            application="bounded low-dimensional linear control points and repeated predictive sampling; no upstream source copied"),
        native_worlds=0,native_physics_steps=0,**{k:False for k in FLAGS})


def declaration():
    c=read(CONTRACT);require(c==expected_contract(),"Sequence exact prospective declaration")
    require(sha(CLOSURE_RESULT)==RESULT_SHA and sha(DLL)==DLL_SHA,"Sequence parent/kernel identity")
    return c


def verify_parent():
    from audit_residual_training_closure import verify_population
    from audit_contact_force_observer_closure import validate_bindings
    from run_hierarchical_native_v6 import inventory
    folder=EVIDENCE/PARENT;result=read(CLOSURE_RESULT);r=read(folder/"receipt.json")
    a=read(folder/"audit.json")
    require(sha(folder/"receipt.json")==PARENT_SHA and r["ok"] is True and r["source_runtime_unchanged"] is True
        and sum(r["safety_controls"].values())==1227,"Sequence completed native parent gate")
    require(result["status"]=="verified_controller_refusal_incomplete_native_comparison"
        and result["attempt_id"]==PARENT and result["execution_complete"] is False
        and result["complete_reader_invocations"]==2 and result["readers_byte_identical"] is True
        and a["ok"] is True and a["execution_complete"] is False and a["constructed_cpu_worlds"]==2
        and a["constructed_gpu_worlds"]==0 and a["controller_rows"]==1555 and a["internal_rows"]==7770,
        "Sequence exact censored native population")
    for name in ("receipt","declaration","gate_receipt","consumed","audit","reconstruction"):
        file=name.replace("_","-")+".json"
        require(sha(folder/file)==result[name+"_sha256"],"Sequence parent digest "+name)
    require(sha(folder/"audit.json")==sha(folder/"reconstruction.json")==r["audit_sha256"],"Sequence parent complete readers")
    require(all(result[k] is False for k in FLAGS if k in result),"Sequence no parent authority promotion")
    verify_population(r["artifacts"],inventory(folder));validate_bindings(read(folder/"declaration.json")["binding"])
    for name,digest in declaration()["input_bindings"].items():require(sha(FOLDER/name)==digest,"Sequence raw input")
    return dict(ok=True,receipt_sha256=PARENT_SHA,controls_passed=1227,reader_worlds=0)


def inputs():
    # Retain full starting observations only; future inputs expose actions to
    # retrospective calibration, never to the search function.
    rows=[row if row["outer_step"] in STARTS else
        dict(outer_step=row["outer_step"],native_targets=row["native_targets"])
        for row in read_jsonl(FOLDER/"controller.jsonl")]
    require(len(rows)==115 and [r["outer_step"] for r in rows]==list(range(115)),"Sequence exposed controller population")
    trace=list(read_jsonl(FOLDER/"trace.jsonl"))
    require(len(trace)==570 and [r["step"] for r in trace]==list(range(1,571)),"Sequence native trace population")
    return rows,trace,read(FOLDER/"force-profile.json"),(FOLDER/"model.xml").read_text(encoding="utf-8")

