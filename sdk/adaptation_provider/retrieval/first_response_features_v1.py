"""Native-free runtime implementation of the frozen first-response feature schema.

The fitting implementation and its observed results remain immutable. Runtime
controls compare these features and predictions with that retained definition.
"""
import hashlib
import json
import math

from . import causal_history_v1 as history
from ..body_height_feedback_v1 import require

DT = 1. / 120.
JOINTS = [leg + "_" + joint for leg in
          ["front_left", "front_right", "rear_left", "rear_right"] for joint in ["hip", "knee"]]
ACTUATORS = [joint + "_motor" for joint in JOINTS]
FEATURE_NAMES = [joint + "_" + statistic for statistic in
                 ["mean_velocity_tracking_error_rad_s", "rms_velocity_tracking_error_rad_s"] for joint in JOINTS]

STEPS = 1
SCHEMA = "locolemotion_first_joint_response_v1"
LABELS = ["left_075", "nominal"]
STARTS = ["train_001", "train_003", "train_004", "train_006"]


def digest(value):
    return hashlib.sha256(json.dumps(value, sort_keys=True, separators=(",", ":"), allow_nan=False).encode()).hexdigest()


def finite(value):
    return type(value) in (int, float) and math.isfinite(value)


def features(request):
    """Use one past actual action and two observed joint positions."""
    window = request["history"]
    history.attach(request, window)
    entries = window["ordered_entries"]
    require(request["state"]["semantic_step"] == STEPS and len(entries) == STEPS,
            "First response requires exactly one past command")
    states = [entry["state"] for entry in entries] + [request["state"]]
    positions = []
    for step, state in enumerate(states):
        joints = state["ordered_joint_observations"]
        require(type(state["semantic_step"]) is int and state["semantic_step"] == step
                and state["sample_time_s"] == step * DT and [j["joint_id"] for j in joints] == JOINTS,
                "First response canonical clock/joint order")
        require(all(j["validity"]["position"] is True and finite(j["position_rad"]) for j in joints),
                "First response finite valid positions")
        positions.append([j["position_rad"] for j in joints])
    errors, causal = [], []
    for step, entry in enumerate(entries):
        commands = entry["deterministic_baseline"]["ordered_commands"]
        require(type(entry["semantic_step"]) is int and entry["semantic_step"] == step
                and entry["provider_status"] == "no_proposal" and entry["adaptation_applied"] is False
                and [c["actuator_id"] for c in commands] == ACTUATORS,
                "First response requires actual baseline actions")
        require(all(finite(c["maximum_target_speed_rad_s"]) and c["maximum_target_speed_rad_s"] > 0
                and finite(c["combined_canonical_target_velocity_rad_s"])
                and abs(c["combined_canonical_target_velocity_rad_s"]) <= c["maximum_target_speed_rad_s"]
                for c in commands), "First response finite projected baseline")
        issued = history.final_velocities(entry)
        require(all(finite(v) for v in issued), "First response finite actual action")
        errors.append([(after-before)/DT-target for before, after, target in
                       zip(positions[step], positions[step+1], issued, strict=True)])
        causal.append(dict(state=entry["state"], command=entry["command"], issued_velocity_rad_s=issued))
    values = [sum(row[j] for row in errors)/STEPS for j in range(8)]
    values += [math.sqrt(sum(row[j]**2 for row in errors)/STEPS) for j in range(8)]
    require(all(finite(v) for v in values), "First response finite feature vector")
    return dict(schema_version=SCHEMA, decision_step=STEPS, past_entries=STEPS,
        names=list(FEATURE_NAMES), values=values,
        causal_input_sha256=digest(dict(past=causal, current_state=request["state"])))


def vector(feature):
    require(feature["schema_version"] == SCHEMA and feature["decision_step"] == feature["past_entries"] == STEPS
            and feature["names"] == FEATURE_NAMES and len(feature["values"]) == 16
            and all(finite(v) for v in feature["values"])
            and all(v >= 0 for v in feature["values"][8:]), "First response vector schema/values")
    return list(feature["values"])


def predict(model, feature):
    require(model["schema_version"] == "locolemotion_first_response_centroids_v1"
            and model["feature_schema"] == SCHEMA and model["feature_names"] == FEATURE_NAMES
            and model["decision_step"] == STEPS and model["metric"] == "unscaled_squared_euclidean"
            and model["action_mapping"] is None and model["control_authority"] is False
            and model["qualification_or_release_authority"] is False, "First response model scope")
    centroids = model["centroids"]
    require([c["condition_id"] for c in centroids] == LABELS and all(len(c["values"]) == 16
            and all(finite(v) for v in c["values"]) and all(v >= 0 for v in c["values"][8:])
            for c in centroids), "First response centroid shape/values")
    values = vector(feature)
    distances = [sum((a-b)**2 for a,b in zip(values,c["values"],strict=True)) for c in centroids]
    require(all(finite(d) for d in distances), "First response finite distance")
    label = None if distances[0] == distances[1] else LABELS[0 if distances[0] < distances[1] else 1]
    return dict(status="ambiguous" if label is None else "classified", condition_id=label,
        squared_distances=dict(zip(LABELS, distances, strict=True)), confidence=None,
        control_authority=False)


