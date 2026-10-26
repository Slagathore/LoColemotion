"""Prospective adaptive scale experiment, preserving the original exposed states."""
import copy
from sequence_constraint_repair_task_v1 import ROOT,HERE,DLL,DLL_SHA,read,sha,require,TRIAL,INPUT,COMMANDS,inputs
import sequence_constraint_repair_task_v1 as native
from audit_residual_training_closure import verify_population
from run_hierarchical_native_v6 import inventory

EVIDENCE=native.EVIDENCE
PARENT="sdk2-sequence-constraint-repair-v1-5df5955031694ad6a69ce9a0695a8379"
PARENT_SHA="b39f256000af90d43a1b74ba378927d06e8bacce0acaffc8f75c5f9712091210"
CLOSURE_RESULT=HERE/"sequence_constraint_repair_result_v1.json"
RESULT_SHA="2e2136b334c4bd39664c8a30b04e38f96221b2cddffda41d8deb0d69202a610f"
CONTRACT=HERE/"sequence_adaptive_scale_v1.json"
SOURCES=("predictive_sequence_adaptive_scale_v1.py","sequence_adaptive_scale_checks_v1.py",
    "sequence_adaptive_scale_task_v1.py","audit_sequence_adaptive_scale_v1.py",
    "test_sequence_adaptive_scale_v1.py","run_sequence_adaptive_scale_v1.py")
GATES=(("adaptive-scale","test_sequence_adaptive_scale_v1",18),*native.GATES)
CONTROLS=sum(n for _,_,n in GATES)


def expected_contract():
    c=copy.deepcopy(native.declaration());c.pop("perturbation_scales")
    c.update(schema_version="locolemotion_sequence_adaptive_scale_contract_v1",
        ledger_scope=dict(subsystem="adaptation",engine_scope="core",
            authority_mode="finite_retained_native_adaptive_scale",question_class="development"),
        source_bindings={n:sha(HERE/n) for n in SOURCES},
        parent_attempt=PARENT,parent_receipt_sha256=PARENT_SHA,parent_result_sha256=RESULT_SHA,
        native_parent=dict(attempt_id=native.PARENT,receipt_sha256=native.PARENT_SHA,result_sha256=native.RESULT_SHA),
        initial_scale=.4,rounds=4,controls_required=CONTROLS,
        scale_update=dict(improving_rejected_round="retain scale only if prefix, numerical category or normalized violation strictly improves",
            stalled_rejected_round="halve scale, including when only task cost improves",
            feasible_round="use inherited absolute scale schedule [.4,.2,.1,.05] for remaining rounds",
            final_round="no continuation or additional candidates"),
        changed_candidate_budget=False,changed_ranking=False,changed_scale_schedule=True,
        initial_seed="same original native86 rejected best; do not seed from the constraint-repair final winner",
        successor_search="four full adaptive-scale rounds; identical incumbent, 64 coordinate and 14 random proposals, seeds, bounds and ranking")
    return c


def declaration():
    c=read(CONTRACT);require(c==expected_contract(),"Adaptive exact prospective contract");return c


def parent():
    folder=EVIDENCE/PARENT;r=read(folder/"receipt.json");a=read(folder/"audit.json")
    require(sha(folder/"receipt.json")==PARENT_SHA and sha(CLOSURE_RESULT)==RESULT_SHA
        and r["ok"] is True and r["source_runtime_unchanged"] is True and r["controls_passed"]==344
        and sha(folder/"audit.json")==sha(folder/"reconstruction.json")==r["audit_sha256"],
        "Adaptive complete constraint-repair predecessor")
    verify_population(r["artifacts"],inventory(folder))
    require(a["worlds_opened"]==a["solver_steps"]==0 and a["all_previous_round_winners_preserved"] is True
        and a["retained_regression_evaluations"]==1264 and a["new_evaluations"]==316
        and a["new_search"]["accepted"] is False and a["new_search"]["best"]["valid_intervals"]==65,
        "Adaptive retained finite refusal")
    return native.parent()
