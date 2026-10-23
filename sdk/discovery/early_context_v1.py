"""Fixed 16-command causal response features and development-only centroids.

This successor does not alter the consumed 64-command feature definition.
It estimates an exposed condition label; it does not select or authorize control.
"""
import copy
import hashlib
import json
import math

from context_probe_control import DT, JOINTS, ACTUATORS, FEATURE_NAMES
from adaptation_provider.retrieval import causal_history_v1 as history
from adaptation_provider.body_height_feedback_v1 import require

STEPS = 16
SCHEMA = "locolemotion_early_joint_response_v1"
LABELS = ["left_075", "nominal"]
STARTS = ["train_001", "train_003", "train_004", "train_006"]


def digest(value):
    return hashlib.sha256(json.dumps(value, sort_keys=True, separators=(",", ":"), allow_nan=False).encode()).hexdigest()


def finite(value):
    return type(value) in (int, float) and math.isfinite(value)


def features(request):
    """Use sixteen past actual actions and seventeen observed joint positions."""
    window = request["history"]
    history.attach(request, window)
    entries = window["ordered_entries"]
    require(request["state"]["semantic_step"] == STEPS and len(entries) == STEPS,
            "Early context requires exactly sixteen past commands")
    states = [entry["state"] for entry in entries] + [request["state"]]
    positions = []
    for step, state in enumerate(states):
        joints = state["ordered_joint_observations"]
        require(type(state["semantic_step"]) is int and state["semantic_step"] == step
                and state["sample_time_s"] == step * DT and [j["joint_id"] for j in joints] == JOINTS,
                "Early context canonical clock/joint order")
        require(all(j["validity"]["position"] is True and finite(j["position_rad"]) for j in joints),
                "Early context finite valid positions")
        positions.append([j["position_rad"] for j in joints])
    errors, causal = [], []
    for step, entry in enumerate(entries):
        commands = entry["deterministic_baseline"]["ordered_commands"]
        require(type(entry["semantic_step"]) is int and entry["semantic_step"] == step
                and entry["provider_status"] == "no_proposal" and entry["adaptation_applied"] is False
                and [c["actuator_id"] for c in commands] == ACTUATORS,
                "Early context requires actual baseline actions")
        require(all(finite(c["maximum_target_speed_rad_s"]) and c["maximum_target_speed_rad_s"] > 0
                and finite(c["combined_canonical_target_velocity_rad_s"])
                and abs(c["combined_canonical_target_velocity_rad_s"]) <= c["maximum_target_speed_rad_s"]
                for c in commands), "Early context finite projected baseline")
        issued = history.final_velocities(entry)
        require(all(finite(v) for v in issued), "Early context finite actual action")
        errors.append([(after-before)/DT-target for before, after, target in
                       zip(positions[step], positions[step+1], issued, strict=True)])
        causal.append(dict(state=entry["state"], command=entry["command"], issued_velocity_rad_s=issued))
    values = [sum(row[j] for row in errors)/STEPS for j in range(8)]
    values += [math.sqrt(sum(row[j]**2 for row in errors)/STEPS) for j in range(8)]
    require(all(finite(v) for v in values), "Early context finite feature vector")
    return dict(schema_version=SCHEMA, decision_step=STEPS, past_entries=STEPS,
        names=list(FEATURE_NAMES), values=values,
        causal_input_sha256=digest(dict(past=causal, current_state=request["state"])))


def vector(feature):
    require(feature["schema_version"] == SCHEMA and feature["decision_step"] == feature["past_entries"] == STEPS
            and feature["names"] == FEATURE_NAMES and len(feature["values"]) == 16
            and all(finite(v) for v in feature["values"])
            and all(v >= 0 for v in feature["values"][8:]), "Early context vector schema/values")
    return list(feature["values"])


def validate_groups(groups, *, complete=False):
    require(type(groups) is list and bool(groups), "Early context training groups")
    seen = set()
    for group in groups:
        condition, start = group["condition_id"], group["start_id"]
        require(group["partition"] == "training" and condition in LABELS and start in STARTS
                and group["group_id"] == condition+"_"+start
                and group["matching_fresh_prefixes"] == 3, "Early context training split/identity")
        require(group["group_id"] not in seen, "Early context duplicate training group")
        seen.add(group["group_id"])
        vector(group["features"])
    by_label = [{g["start_id"] for g in groups if g["condition_id"] == label} for label in LABELS]
    require(bool(by_label[0]) and by_label[0] == by_label[1], "Early context paired condition/start groups")
    if complete:
        require(len(groups) == 8 and by_label[0] == set(STARTS), "Early context complete eight-group corpus")


def fit(groups):
    """Unscaled nearest centroids; all sixteen features share rad/s units.

    There is no feature search, parameter sweep, confidence threshold or action
    mapping. Each start contributes one row per condition, irrespective of the
    three controller roles that happened to share its physical prefix.
    """
    validate_groups(groups)
    rows = sorted(groups, key=lambda g: g["group_id"])
    centroids = []
    for label in LABELS:
        values = [vector(g["features"]) for g in rows if g["condition_id"] == label]
        centroids.append(dict(condition_id=label, values=[sum(v[j] for v in values)/len(values) for j in range(16)]))
    return dict(schema_version="locolemotion_early_context_centroids_v1", feature_schema=SCHEMA,
        feature_names=list(FEATURE_NAMES), decision_step=STEPS,
        metric="unscaled_squared_euclidean", centroids=centroids,
        training_group_ids=[g["group_id"] for g in rows], training_data_sha256=digest(rows),
        action_mapping=None, control_authority=False, qualification_or_release_authority=False)


def predict(model, feature):
    require(model["schema_version"] == "locolemotion_early_context_centroids_v1"
            and model["feature_schema"] == SCHEMA and model["feature_names"] == FEATURE_NAMES
            and model["decision_step"] == STEPS and model["metric"] == "unscaled_squared_euclidean"
            and model["action_mapping"] is None and model["control_authority"] is False
            and model["qualification_or_release_authority"] is False, "Early context model scope")
    centroids = model["centroids"]
    require([c["condition_id"] for c in centroids] == LABELS and all(len(c["values"]) == 16
            and all(finite(v) for v in c["values"]) and all(v >= 0 for v in c["values"][8:])
            for c in centroids), "Early context centroid shape/values")
    values = vector(feature)
    distances = [sum((a-b)**2 for a,b in zip(values,c["values"],strict=True)) for c in centroids]
    require(all(finite(d) for d in distances), "Early context finite distance")
    label = None if distances[0] == distances[1] else LABELS[0 if distances[0] < distances[1] else 1]
    return dict(status="ambiguous" if label is None else "classified", condition_id=label,
        squared_distances=dict(zip(LABELS, distances, strict=True)), confidence=None,
        control_authority=False)


def evaluate(groups):
    """Blocked internal validation only: both conditions of a start stay out."""
    validate_groups(groups, complete=True)
    folds = []
    for start in STARTS:
        training = [g for g in groups if g["start_id"] != start]
        testing = [g for g in groups if g["start_id"] == start]
        model = fit(training)
        require(len(training) == 6 and len(testing) == 2
                and not set(model["training_group_ids"]) & {g["group_id"] for g in testing},
                "Early context blocked fold leakage")
        results = []
        for group in testing:
            prediction = predict(model, group["features"])
            label = prediction["condition_id"]
            swapped = None if label is None else LABELS[1-LABELS.index(label)]
            results.append(dict(group_id=group["group_id"], expected_condition_id=group["condition_id"],
                prediction=prediction, correct=label == group["condition_id"],
                constant_nominal_correct=group["condition_id"] == "nominal",
                swapped_association_correct=swapped == group["condition_id"]))
        folds.append(dict(held_out_training_start=start, model=model, predictions=results))
    predictions = [p for fold in folds for p in fold["predictions"]]
    return dict(validation_scope="internal_leave_training_start_out_not_reserved_evaluation",
        folds=folds, correct=sum(p["correct"] for p in predictions), denominator=8,
        constant_nominal_correct=sum(p["constant_nominal_correct"] for p in predictions),
        swapped_association_correct=sum(p["swapped_association_correct"] for p in predictions),
        association_swap_is_synthetic=True, all_training_model=fit(groups),
        physical_control_effectiveness_tested=False, qualification_or_release_authority=False)
