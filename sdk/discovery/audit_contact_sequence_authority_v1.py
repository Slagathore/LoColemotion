"""Read complete retained contact-native populations without executing a controller."""
import argparse
from collections import Counter
import hashlib
import json
from pathlib import Path

from audit_gpu_batch_execution import same_bits
from audit_recovery_hold_native import validate_sample
from causal_force_control import terminal_error
from contact_sequence_native_checks_v1 import native_step, outcome
from contact_sequence_authority_diagnostic_v1 import (
    FEET, close, control_packet, forecast_cases, forecast_diagnostic,
    future_input_drift, matched_first_interval, model_spec, motor_state,
    native_limit_forces, native_summary, population_summary, retained_only,
    scalar_guards,
)
from contact_sequence_authority_task_v1 import (
    CONTRACT, CONTROLS, EVIDENCE, FLAGS, PARENT, PARENT_AUDIT, PARENT_RECEIPT,
    SCOPE, TRIALS, declaration, parent, read, require, sha, write_new,
)
from predictive_contact_sequence_v1 import ClearanceMetric


def bounded_rows(path, binding, maximum):
    """Consume each exact stream once; a truncated or extra tail cannot disappear."""
    require(path.stat().st_size == binding["byte_length"], "Contact authority input byte length")
    digest = hashlib.sha256(); count = size = 0
    with path.open("rb") as stream:
        while True:
            line = stream.readline(maximum + 1)
            if not line:
                break
            require(len(line) <= maximum and line.endswith(b"\n"),
                    "Contact authority bounded complete input row")
            digest.update(line); size += len(line)
            row = json.loads(line)
            require(type(row) is dict, "Contact authority object input row")
            yield count, hashlib.sha256(line).hexdigest(), len(line), row
            del row, line
            count += 1
    require(size == binding["byte_length"] and digest.hexdigest() == binding["sha256"],
            "Contact authority complete stream digest")


class Capture:
    def __init__(self, folder, contract):
        self.folder = folder; self.contract = contract
        self.rows = 0; self.bytes = 0; self.artifacts = []

    def append(self, stream, value):
        data = (json.dumps(value, separators=(",", ":"), allow_nan=False) + "\n").encode("utf-8")
        require(len(data) <= self.contract["maximum_capture_row_bytes"]
                and self.bytes + len(data) <= self.contract["maximum_capture_bytes"],
                "Contact authority bounded complete capture")
        require(stream.write(data) == len(data), "Contact authority complete capture write")
        self.rows += 1; self.bytes += len(data)

    def finish(self, path):
        value = dict(path=path.relative_to(self.folder).as_posix(), sha256=sha(path),
                     byte_length=path.stat().st_size)
        self.artifacts.append(value)
        return value

    def write(self, name, value):
        path = self.folder / name
        path.parent.mkdir(parents=True, exist_ok=True)
        with path.open("xb") as stream:
            self.append(stream, value)
        return self.finish(path)


def trial_reader(trial_id, contract, inherited, spec, metric, capture):
    folder = inherited["folder"] / "physical" / trial_id
    result = read(folder / "result.json"); native_contract = inherited["contract"]
    outer_count, inner_count = outcome(result, native_contract, result["role"])
    profile = read(folder / "force-profile.json")
    motor_profile = profile.get("nominal_profile", profile)
    inputs = read(folder / "inputs.json"); metadata = read(folder / "contact-metadata.json")
    native_metadata = read(folder / "native-model.json")
    require(inputs["ordered_joints"] == spec["joint_ids"]
            and inputs["velocity_gains"] == spec["gains"]
            and inputs["force_ranges"] == spec["ranges"]
            and [entry["body_name"] for entry in metadata["geoms"]] == spec["geom_bodies"],
            "Contact authority model and native force identity")
    transmissions = native_metadata["actuator_profile"]["trnid"]
    require(transmissions == [[index + 1, -1] for index in range(8)],
            "Contact authority bound native transmission order")
    native_ids = [entry[0] for entry in transmissions]
    output = capture.folder / trial_id; output.mkdir()

    def rows(name):
        key = f"physical/{trial_id}/{name}.jsonl"
        return bounded_rows(folder / (name + ".jsonl"), contract["input_bindings"][key],
                            contract["maximum_input_row_bytes"])

    native_rows = {}; packets = {}; forecasts = []; future_inputs = []
    outcomes = []; observed_kinds = Counter(); controls = inner = evaluated = 0
    last = initial = None
    trace_iterator = rows("trace"); force_iterator = rows("contact-force")
    candidate = trial_id == TRIALS[1]
    control_path = output / "prepared-commands.jsonl"; native_path = output / "native-steps.jsonl"
    with control_path.open("xb") as control_stream, native_path.open("xb") as native_stream:
        for ordinal, row_hash, row_bytes, row in rows("controller"):
            require(ordinal == row["outer_step"] and ordinal < outer_count
                    and (row["backend"], row["cell"]) == ("cpu", 0),
                    "Contact authority complete ordered controller population")
            packet = control_packet(row)
            transferred = result["completed"] or ordinal < outer_count - 1
            require((terminal_error(row) is None) == transferred,
                    "Contact authority actual refusal placement")
            packet.update(transferred=transferred, row_sha256=row_hash, row_bytes=row_bytes)
            packet["distal_clearance_m"] = metric.clearance(packet["qpos"])
            packets[ordinal] = packet
            capture.append(control_stream, packet)
            if initial is None:
                initial = (packet["qpos"], packet["qvel"])
            if transferred:
                for substep in range(5):
                    raw_entry = next(trace_iterator, None); force_entry = next(force_iterator, None)
                    require(raw_entry is not None and force_entry is not None,
                            "Contact authority missing transferred internal sample")
                    raw_index, raw_hash, _, raw = raw_entry
                    force_index, force_hash, _, sample = force_entry
                    require(raw_index == force_index == inner, "Contact authority internal stream row join")
                    native_step(raw, inner + 1, row, last, initial, inputs, native_contract, motor_profile)
                    validate_sample(sample, raw, metadata, native_contract)
                    motor = motor_state(packet, raw, spec, native_contract["motor_model_absolute_tolerance_nm"])
                    guard_reasons, violations, tilt = scalar_guards(raw, spec)
                    loads = sample["mapped_distal_ground_loads"]
                    require([entry["body_name"] for entry in loads] == list(FEET),
                            "Contact authority complete named native distal loads")
                    compact = dict(
                        step=raw["step"], command=ordinal, substep=substep, time_s=raw["time_s"],
                        prepared_time_s=sample["prepared_time_s"], raw_sha256=raw_hash,
                        contact_row_sha256=force_hash, qpos=raw["qpos"], qvel=raw["qvel"],
                        target=raw["ctrl"], motor=motor,
                        distal_geometric_contact=[bool(entry["contact_indices"]) for entry in loads],
                        distal_normal_force_n=[entry["normal_load_n"] for entry in loads],
                        distal_clearance_before_m=metric.clearance(raw["before_qpos"]),
                        distal_clearance_after_m=metric.clearance(raw["qpos"]),
                        joint_limit_constraint_force=native_limit_forces(sample, native_ids, spec["joint_ids"]),
                        unchanged_forecast_guard_reasons=guard_reasons,
                        joint_margin_violations=violations, tilt_rad=tilt,
                    )
                    observed_kinds.update(str(kind) for kind in sample["efc_type"])
                    native_rows[raw["step"]] = compact
                    capture.append(native_stream, compact)
                    last = raw; inner += 1
            else:
                require(ordinal == 90 and last is not None
                        and same_bits(packet["qpos"], last["qpos"])
                        and same_bits(packet["qvel"], last["qvel"])
                        and packet["time_s"] == last["time_s"]
                        and result["terminal_refusal"]["transferred"] is False,
                        "Contact authority terminal command did not advance native state")

            if candidate and ordinal >= 60:
                decision = row["force_reference"]["decision"]
                starting = decision["starting_packet"]; selection = decision["selection"]
                require(starting["command"] == ordinal, "Contact authority forecast starting command")
                for name in ("baseline", "speeds", "previous_correction"):
                    require(same_bits(starting[name], packet[name]), "Contact authority causal " + name)
                for name in ("qpos", "qvel"):
                    close(starting[name], packet[name], "Contact authority canonical/native " + name)
                cases, populations = forecast_cases(selection)
                summary = population_summary(populations)
                count = sum(entry["evaluated"] for entry in summary); evaluated += count
                outcomes.append(dict(command=ordinal, row_sha256=row_hash, transferred=transferred,
                                     accepted=selection["accepted"], stages=summary, evaluated=count))
                require(selection["accepted"] is transferred, "Contact authority selected transfer/refusal")
                for index, (name, best) in enumerate(cases):
                    diagnostic = forecast_diagnostic(starting, best, spec, metric)
                    label = f"command-{ordinal:03d}-{name}"
                    artifact = capture.write(trial_id + "/" + label + ".json", dict(
                        case=label, controller_row_sha256=row_hash, starting_packet=starting,
                        knots=best["option"]["knots"], specification=spec, diagnostic=diagnostic))
                    measured = None
                    if transferred and index == len(cases) - 1:
                        measured = matched_first_interval(ordinal, best["result"], native_rows, spec)
                    forecasts.append(dict(case=label, command=ordinal, stage=name, artifact=artifact,
                                          selected=index == len(cases) - 1,
                                          selected_first_interval_transferred=transferred and index == len(cases) - 1,
                                          native_comparison=measured,
                                          **{key: value for key, value in diagnostic.items() if key not in ("trace", "command")}))
                    future_inputs.append((label, {key: starting[key] for key in ("command", "baseline", "speeds")},
                                          [dict(offset=interval["offset"], target=interval["target"])
                                           for interval in best["result"]["rows"]]))
                print(json.dumps(dict(trial=trial_id, command=ordinal, best_forecasts=len(cases),
                                      retained_candidate_outcomes=count)), flush=True)
                # Avoid retaining a large raw candidate population across iterations.
                del decision, selection, cases, populations, starting, best, diagnostic
            controls += 1
            del row
    require(controls == outer_count and inner == inner_count,
            "Contact authority complete available native denominator")
    require(next(trace_iterator, None) is None and next(force_iterator, None) is None,
            "Contact authority unexpected native sample tail")
    capture.finish(control_path); capture.finish(native_path)
    drift = []
    for label, starting, intervals in future_inputs:
        value = future_input_drift(starting, intervals, packets)
        artifact = capture.write(trial_id + "/" + label + "-future-inputs.json", dict(case=label, **value))
        drift.append(dict(case=label, artifact=artifact,
                          **{key: item for key, item in value.items() if key != "rows"}))
    ordered = list(native_rows.values()); post = ordered[300:]
    prepared = list(packets.values()); prepared_post = prepared[60:]
    return dict(
        trial_id=trial_id, controller_rows=controls, internal_steps=inner,
        native= native_summary(ordered, spec), post_prefix_native=native_summary(post, spec),
        prepared_support=dict(commands=len(prepared), post_prefix_commands=len(prepared_post),
                              ordered_distal_bodies=list(FEET),
                              whole=[sum(int(packet["prepared_support"][j]) for packet in prepared) for j in range(4)],
                              post_prefix=[sum(int(packet["prepared_support"][j]) for packet in prepared_post) for j in range(4)],
                              measured_loads_were_controller_inputs=False),
        constraint_row_kind_counts=dict(sorted(observed_kinds.items())),
        forecast_cases=forecasts, candidate_outcomes=outcomes,
        retained_candidate_outcomes=evaluated, future_input_drift=drift,
        guard_application_scope="Forecast predicates on retained native samples are diagnostic; original native acceptance is unchanged",
    )


def audit(folder):
    contract = declaration(); inherited = parent(); capture = Capture(folder, contract)
    profile = read(inherited["folder"] / "physical" / TRIALS[1] / "force-profile.json")
    spec = model_spec(profile["prepared_model"])
    with retained_only():
        metric = ClearanceMetric(profile["prepared_model"])
        trials = [trial_reader(trial, contract, inherited, spec, metric, capture) for trial in TRIALS]
    require([trial["controller_rows"] for trial in trials] == contract["population"]["controller_rows"]
            and [trial["internal_steps"] for trial in trials] == contract["population"]["native_steps"],
            "Contact authority declared native population")
    candidate = trials[1]
    require([row["command"] for row in candidate["candidate_outcomes"]] == list(range(60, 91))
            and len(candidate["forecast_cases"]) == 55
            and candidate["retained_candidate_outcomes"] == 5262
            and sum(row["native_comparison"]["compared_native_steps"] for row in candidate["forecast_cases"]
                    if row["native_comparison"] is not None) == 150,
            "Contact authority exact forecast and matched native population")
    require(contract == declaration(), "Contact authority declaration drift")
    return dict(
        schema_version="locolemotion_contact_sequence_authority_audit_v1", ledger_scope=SCOPE, ok=True,
        contract_sha256=sha(CONTRACT), parent_attempt=PARENT, parent_receipt_sha256=PARENT_RECEIPT,
        parent_audit_sha256=PARENT_AUDIT, controls_required=CONTROLS,
        inherited_native_controls_verified=1615, trials=trials,
        total_retained_predicted_steps=sum(case["predicted_steps"] for case in candidate["forecast_cases"]),
        capture_rows=capture.rows, capture_bytes=capture.bytes, capture_artifacts=capture.artifacts,
        retained_native_worlds=2, new_worlds_opened=0, new_forecasts=0, candidate_searches=0, dynamics_solves=0,
        native_execution_repeated=False, counterfactual_dynamics_computed=False,
        original_native_acceptance_changed=False, later_forecasts_native_validated=False,
        **{name: False for name in FLAGS},
    )


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    folder = args.output.parent / (args.output.stem + "-capture"); folder.mkdir()
    result = audit(folder)
    write_new(args.output, result)
    print(json.dumps(dict(ok=True, forecast_cases=55, native_steps=7650,
                          predicted_steps=result["total_retained_predicted_steps"], new_worlds_opened=0)), flush=True)


if __name__ == "__main__":
    main()
