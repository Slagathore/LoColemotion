"""Prospective retained-only authority diagnosis with exact predecessor bindings."""
from pathlib import Path
import sequence_adaptive_scale_task_v1 as prior
from sequence_constraint_repair_task_v1 import inputs
from audit_residual_training_closure import verify_population
from run_hierarchical_native_v6 import inventory
ROOT,HERE,EVIDENCE,TRIAL=prior.ROOT,prior.HERE,prior.EVIDENCE,prior.TRIAL
read,sha,require=prior.read,prior.sha,prior.require
DLL,DLL_SHA=prior.DLL,prior.DLL_SHA
PARENT="sdk2-sequence-adaptive-scale-v1-d9ba05d4f4e747ea8fc1a29d8617ab5a"
PARENT_SHA="8bd120f05bb3e0373d374ca761bc0bb7212c448e65e817b682538f1d94dde263"
CLOSURE_RESULT=HERE/"sequence_adaptive_scale_result_v1.json"
RESULT_SHA="95fe64108d9e3a75430bf2619cfd0d931377a1b78e2aa729e2e680ddf6735fe0"
CONTRACT=HERE/"sequence_authority_v2.json"
SOURCES=("sequence_authority_diagnostic_v1.py","sequence_authority_task_v1.py",
    "audit_sequence_authority_v1.py","test_sequence_authority_v1.py","run_sequence_authority_v1.py","sequence_authority_v1.json")
GATES=(("authority-arithmetic","test_sequence_authority_v1",20),)
CONTROLS=20
CASES=("native_refined_81","native_refined_83","native_refined_84","native_refined_85",
    "native_original_86","native_refined_86","constraint_repair_86","adaptive_scale_86")
EXTRA=(("constraint_repair_86",EVIDENCE/prior.PARENT/"audit-capture/final-86.json"),
       ("adaptive_scale_86",EVIDENCE/PARENT/"audit-capture/final-86.json"))


def expected_contract():
    return dict(schema_version="locolemotion_sequence_authority_contract_v2",
        failed_control_predecessor=dict(attempt_id="sdk2-sequence-authority-v1-60fadddeee654cd48593d83408e6fcdc",
            receipt_sha256="474c8a9c72cc945509bf62377d7df495b698ca254bf5fd6b8cddcc99c02eb415",
            contract_path="sdk/discovery/sequence_authority_v1.json",
            contract_sha256="b60e61accdfc3b178f6bf51625e04c5bf6981828c2e5f52132f93ea2616813f3",
            controls_run=20,failures=1,readers_started=False,
            correction="Test expectation only: exact bound hits are 65; interval 1 is one ULP below 3.5. Diagnostic arithmetic and thresholds unchanged."),
        ledger_scope=dict(subsystem="adaptation",engine_scope="core",
            authority_mode="retained_forecast_arithmetic_diagnosis",question_class="development"),
        source_bindings={n:sha(HERE/n) for n in SOURCES},
        parent_attempt=PARENT,parent_receipt_sha256=PARENT_SHA,parent_result_sha256=RESULT_SHA,
        inherited_verified_controls=362,controls_required=20,
        input_bindings={str(p.relative_to(EVIDENCE)).replace("\\","/"):sha(p)
            for p in (prior.INPUT,TRIAL/"force-profile.json",*[p for _,p in EXTRA])},
        cases=list(CASES),horizon_intervals=66,steps_per_interval=5,
        diagnostic="All retained best-trajectory steps; scalar/vector command projection, motor torque and guards; conic force-vector identity accounting",
        arithmetic_tolerance=dict(relative=1e-12,absolute=1e-12),
        force_cap_comparison="exact equality to declared clipped bound",
        loaded_contact_comparison="retained normal force strictly positive; no support or feasibility threshold inferred",
        predictor_refusal_handling="reject incomplete or numerically refused input; never invent unavailable torque or geometry",
        state_scope="instantaneous torque ranges hold each retained state fixed; they are not alternative-action trajectories",
        prior_qualification="verify completed parent controls and complete artifact populations; do not rerun inherited search controls",
        maximum_control_wall_seconds=600,maximum_reader_wall_seconds=1800,
        minimum_free_storage_bytes=4*2**30,maximum_capture_bytes=64*2**20,
        maximum_capture_row_bytes=8*2**20,
        runtime_native_api_forbidden=True,runtime_xml_parsing_forbidden=True,new_forecasts=0,
        candidate_searches=0,worlds_opened=0,solver_steps=0,trained=False,
        actual_native_transfer_verified=False,recovery_benefit_established=False,
        training_data_authority=False,tier2_qualified=False,tier3_benefit_established=False,
        physical_acceptance_authority=False,release_authority=False,
        global_infeasibility_established=False,baseline_approximation_error_measured=False)


def declaration():
    c=read(CONTRACT);require(c==expected_contract(),"Authority exact prospective contract");return c


def parent():
    failed=EVIDENCE/"sdk2-sequence-authority-v1-60fadddeee654cd48593d83408e6fcdc"
    record=read(failed/"receipt.json")
    require(sha(failed/"receipt.json")=="474c8a9c72cc945509bf62377d7df495b698ca254bf5fd6b8cddcc99c02eb415"
        and record["ok"] is False and record["physical_started"] is False
        and record["controls_passed"]==0 and not (failed/"audit.json").exists(),
        "Authority preserved failed control predecessor")
    verify_population(record["artifacts"],inventory(failed))
    folder=EVIDENCE/PARENT;r=read(folder/"receipt.json");a=read(folder/"audit.json")
    require(sha(folder/"receipt.json")==PARENT_SHA and sha(CLOSURE_RESULT)==RESULT_SHA
        and r["ok"] is True and r["source_runtime_unchanged"] is True and r["controls_passed"]==362
        and sha(folder/"audit.json")==sha(folder/"reconstruction.json")==r["audit_sha256"],
        "Authority completed adaptive predecessor")
    verify_population(r["artifacts"],inventory(folder))
    require(a["new_search"]["accepted"] is False and a["new_search"]["best"]["valid_intervals"]==65
        and a["all_previous_round_winners_preserved"] is True
        and a["worlds_opened"]==a["solver_steps"]==0,"Authority finite predecessor outcome")
    return prior.parent()
