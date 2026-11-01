"""Prospective scope and exact evidence joins for retained contact-native diagnosis."""
import hashlib
import json
from pathlib import Path

from actuation_recovery_mechanics import require
from audit_gpu_batch_execution import same_bits

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent.parent
EVIDENCE = ROOT.parent / "SporeSpore_Evidence"
PARENT = "sdk2-contact-sequence-native-v2-50b5b203051c442db9a71ae4754979d9"
PARENT_SOURCE = "07fac08aa0e5e9d68ff87fbbac0d1cbf04ef0af4"
PARENT_RECEIPT = "55cdd0d0d5ece7f2db526a33fc726be463217491e16e8385e792f0ce88da2030"
PARENT_AUDIT = "806e63c610cb5bebe1056040273b551a77c21aa798f6781156fea13ce84ccf4b"
CLOSURE = HERE / "contact_sequence_native_result_v2.json"
CLOSURE_SHA = "faa14c9ae86c08fe5060ccc7ee5f053106535060eb44c857d86513971d3d4546"
CONTRACT = HERE / "contact_sequence_authority_v1.json"
SOURCES = (
    "contact_sequence_authority_task_v1.py", "contact_sequence_authority_diagnostic_v1.py",
    "audit_contact_sequence_authority_v1.py", "run_contact_sequence_authority_v1.py",
    "test_contact_sequence_authority_v1.py",
)
GATES = (
    ("retained-authority-arithmetic", "test_sequence_authority_v1", 20),
    ("retained-contact-authority", "test_contact_sequence_authority_v1", 34),
    ("contained-stage-lifecycle-v2", "test_contained_stage_owner_v2", 17),
)
CONTROLS = sum(count for _, _, count in GATES)
TRIALS = ("reach_hold_left_075_train_001", "predictive_hold_left_075_train_001")
FILES = ("controller.jsonl", "trace.jsonl", "contact-force.jsonl", "force-profile.json",
         "inputs.json", "native-model.json", "contact-metadata.json", "result.json", "plan.json")
FLAGS = ("trained", "planning_memory_is_learning", "recovery_benefit_established",
         "safe_withdrawal_established", "training_data_authority", "tier2_qualified",
         "tier3_benefit_established", "real_time_qualified", "physical_acceptance_authority",
         "release_authority", "equivalence_authority", "global_infeasibility_established",
         "forecast_error_attributable_to_held_baseline_measured")
SCOPE = dict(subsystem="adaptation", engine_scope="mujoco_cpu_retained_and_portable_forecasts",
             authority_mode="retained_contact_and_actuator_arithmetic_diagnosis", question_class="development")


def sha(path):
    with Path(path).open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def read(path):
    return json.loads(Path(path).read_bytes())


def write_new(path, value):
    with Path(path).open("x", encoding="utf-8", newline="\n") as stream:
        json.dump(value, stream, indent=2, allow_nan=False)
        stream.write("\n")


def inventory(folder):
    return [dict(path=path.relative_to(folder).as_posix(), sha256=sha(path), byte_length=path.stat().st_size)
            for path in sorted(folder.rglob("*")) if path.is_file() and path != folder / "receipt.json"]


def population(expected, actual):
    def indexed(rows):
        result = {}
        for row in rows:
            require(set(row) == {"path", "sha256", "byte_length"}
                    and row["path"] not in result and not Path(row["path"]).is_absolute()
                    and ".." not in Path(row["path"]).parts,
                    "Contact authority unique relative artifact population")
            result[row["path"]] = row
        return result
    require(indexed(expected) == indexed(actual), "Contact authority exact artifact population")


def expected_contract():
    folder = EVIDENCE / PARENT
    receipt = read(folder / "receipt.json")
    require(sha(folder / "receipt.json") == PARENT_RECEIPT, "Contact authority immutable native receipt")
    artifacts = {row["path"]: row for row in receipt["artifacts"]}
    inputs = {f"physical/{trial}/{name}": artifacts[f"physical/{trial}/{name}"]
              for trial in TRIALS for name in FILES}
    return dict(
        schema_version="locolemotion_contact_sequence_authority_contract_v1", ledger_scope=SCOPE,
        source_bindings={name: sha(HERE / name) for name in SOURCES},
        native_parent=dict(attempt_id=PARENT, source_commit=PARENT_SOURCE,
                           receipt_sha256=PARENT_RECEIPT, audit_sha256=PARENT_AUDIT,
                           closure_path=CLOSURE.relative_to(ROOT).as_posix(), closure_sha256=CLOSURE_SHA),
        method_predecessor=dict(contract_path="sdk/discovery/sequence_authority_v2.json",
                                contract_sha256=sha(HERE / "sequence_authority_v2.json"),
                                result_path="sdk/discovery/sequence_authority_result_v1.json",
                                result_sha256=sha(HERE / "sequence_authority_result_v1.json")),
        input_bindings=inputs, inherited_native_controls_verified=1615,
        controls_required=CONTROLS, gates=[dict(name=name, module=module, count=count) for name, module, count in GATES],
        population=dict(trials=list(TRIALS), controller_rows=[1440, 91], native_steps=[7200, 450],
                        prefix_commands=60, prefix_native_steps=300,
                        predictive_commands=list(range(60, 91)), transferred_predictive_commands=list(range(60, 90)),
                        best_forecasts=55, retained_candidate_outcomes=5262,
                        forecast_horizon_intervals=66, steps_per_interval=5),
        native_scope="All retained samples from both opened worlds; whole and post-prefix counts remain separate",
        forecast_scope="All original, refined and contact-aware nested best forecasts; overlapping futures are not independent episodes",
        candidate_scope="All retained candidate outcome fields; complete guard/cost reconstruction is inherited from the native readers",
        contact_scope="Prepared support flags, geometric contact, positive normal force and capsule clearance are distinct measurements",
        joint_limit_scope="Native constraint IDs join through retained actuator transmission IDs; forecast forces use declared conic block identities",
        motor_scope="Scalar/vector arithmetic and instantaneous command-envelope torque ranges at fixed retained states",
        future_baseline_scope="Compare later actual closed-loop baseline commands retrospectively; no counterfactual baseline truth or causal error attribution",
        native_forecast_comparison_scope="Only the selected first interval at each of 30 transferred post-prefix commands: 150 native steps",
        arithmetic_tolerance=dict(relative=1e-12, absolute=1e-12),
        force_cap_comparison="exact equality", positive_normal_force_comparison="strictly greater than zero",
        maximum_control_wall_seconds=900, maximum_reader_wall_seconds=7200,
        minimum_free_storage_bytes=32 * 2**30, maximum_input_row_bytes=2**30,
        maximum_capture_bytes=256 * 2**20, maximum_capture_row_bytes=8 * 2**20,
        runtime_native_execution_forbidden=True, runtime_xml_parsing_forbidden=True,
        new_forecasts=0, candidate_searches=0, new_worlds_opened=0, dynamics_solves=0,
        geometry_only_evaluations_permitted=True,
        **{name: False for name in FLAGS},
    )


def declaration():
    value = read(CONTRACT)
    require(value == expected_contract(), "Contact authority exact prospective declaration")
    return value


def validate_parent_documents(receipt, owner, audit, closure):
    require(receipt["ok"] is True and receipt["source_runtime_unchanged"] is True
            and receipt["source_commit"] == owner["source_commit"] == PARENT_SOURCE
            and owner["source_status"] == [] and receipt["binding"] == owner["binding"]
            and sum(receipt["safety_controls"].values()) == 1615
            and receipt["constructed_cpu_worlds"] == 2 and receipt["constructed_gpu_worlds"] == 0,
            "Contact authority completed native parent and source freeze")
    require(audit["ok"] is True and audit["execution_complete"] is False
            and audit["controller_rows"] == 1531 and audit["internal_rows"] == audit["contact_rows"] == 7650
            and audit["reader_world_build_count"] == audit["reader_solver_steps"] == 0
            and audit["constructed_cpu_worlds"] == 2 and audit["constructed_gpu_worlds"] == 0,
            "Contact authority native audit denominator")
    require(closure["attempt_id"] == PARENT and closure["receipt_sha256"] == PARENT_RECEIPT
            and closure["audit_sha256"] == closure["reconstruction_sha256"] == PARENT_AUDIT
            and closure["controls_passed"] == 1615 and closure["execution_complete"] is False
            and same_bits(closure["trials"], audit["trials"]),
            "Contact authority native closure joins")
    require([trial["trial_id"] for trial in audit["trials"]] == list(TRIALS)
            and [trial["controller_rows"] for trial in audit["trials"]] == [1440, 91]
            and [trial["internal_rows"] for trial in audit["trials"]] == [7200, 450]
            and audit["trials"][1]["terminal_refusal"]["command"] == 90
            and audit["trials"][1]["terminal_refusal"]["transferred"] is False,
            "Contact authority exact retained refusal population")
    for name in ("training_data_authority", "physical_acceptance_authority", "release_authority", "equivalence_authority"):
        require(receipt[name] is False and closure[name] is False,
                "Contact authority no inherited qualification")


def parent():
    """Read the immutable parent; never rerun or reinterpret its consumed campaign."""
    folder = EVIDENCE / PARENT
    require(sha(folder / "receipt.json") == PARENT_RECEIPT and sha(CLOSURE) == CLOSURE_SHA,
            "Contact authority predecessor identities")
    receipt = read(folder / "receipt.json"); closure = read(CLOSURE)
    for name, digest in (("declaration.json", closure["declaration_sha256"]),
                         ("gate-receipt.json", closure["gate_receipt_sha256"]),
                         ("consumed.json", closure["consumed_sha256"]),
                         ("audit.json", PARENT_AUDIT), ("reconstruction.json", PARENT_AUDIT)):
        require(sha(folder / name) == digest, "Contact authority predecessor " + name)
    require((folder / "audit.json").read_bytes() == (folder / "reconstruction.json").read_bytes(),
            "Contact authority complete independent parent readers")
    owner = read(folder / "declaration.json"); audit = read(folder / "audit.json")
    validate_parent_documents(receipt, owner, audit, closure)
    population(receipt["artifacts"], inventory(folder))
    require(len(receipt["artifacts"]) + 1 == closure["artifacts_including_receipt"] == 3051,
            "Contact authority complete retained parent files")
    for kind in ("source", "runtime"):
        for name, digest in owner["binding"][kind].items():
            path = ROOT / name if kind == "source" else Path(name)
            require(sha(path) == digest, "Contact authority unchanged parent binding: " + name)
    return dict(folder=folder, receipt=receipt, owner=owner, audit=audit,
                closure=closure, contract=owner["contract"])
