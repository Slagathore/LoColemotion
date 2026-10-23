"""Private episode feedback indexed by the context in which an action began.

The frozen v2 casebook and its selection rules remain unchanged. This distinct
provider adds bounded residual records only after observing a complete held
window. A record can affect a later choice only in the same phase/contact
category and within the casebook's existing scaled-distance support radius.
"""
import copy
import hashlib
import json
import math
from pathlib import Path

from . import flat_v2 as base

CONTRACT = Path(__file__).with_name("contextual_contract_v1.json")
MODES = base.MODES
EPISODIC = ("episodic", "episodic_shuffled")
require, finite, digest = base.require, base.finite, base.digest


def contract():
    value = json.loads(CONTRACT.read_text(encoding="utf-8"))
    require(value["schema_version"] == "locolemotion_contextual_episode_contract_v1"
            and value["base_contract"] == "flat_contract_v2.json"
            and hashlib.sha256(CONTRACT.with_name(value["base_contract"]).read_bytes()).hexdigest()
                == value["base_contract_sha256"]
            and value["nearest_neighbors"] == 3 and value["kernel_epsilon"] == 1e-6
            and value["maximum_records"] == 64 and value["maximum_residual_m_s"] == .15
            and value["maximum_opaque_state_bytes"] == 65536
            and value["authority"] == dict(development_only=True, base_model_immutable=True,
                physical_acceptance_authority=False, release_authority=False, safety_probability=False),
            "Contextual component contract")
    return value


def version(core, config, mode):
    require(mode in MODES, "Provider mode")
    return config["provider_version"] + "_" + digest(core, config)[7:] + "_" + mode


def empty_memory(core, reset_epoch=0):
    require(type(reset_epoch) is int and reset_epoch >= 0, "Reset epoch")
    return dict(schema_version="sporespore_adaptation_provider_memory_v1",
        provider_id=contract()["provider_id"], reset_epoch=reset_epoch, sequence=0,
        opaque_state={}, opaque_state_sha256=digest(core, {}), weights_mutated=False)


def bind_request(core, request, model, mode):
    config = contract()
    require(model.plan() == base.contract(), "Crossed base contract")
    value = base.bind_request(core, request, model, mode)
    value.update(provider_id=config["provider_id"], expected_provider_version=version(core, config, mode),
                 provider_memory=empty_memory(core))
    return value


def credited_action(action, mode, plan):
    if mode != "episodic_shuffled" or action == 0:
        return action
    original = plan["actions"][action]
    return next(i for i, candidate in enumerate(plan["actions"])
        if candidate["global_scale"] == -original["global_scale"]
        and candidate["side_bias"] == -original["side_bias"])


def context_distance(query, stored, plan):
    base.validate_cue(query)
    base.validate_cue(stored)
    if query["phase"] != stored["phase"] or query["contact_mask"] != stored["contact_mask"]:
        return None
    # hypot avoids overflow when an otherwise finite unsupported cue is large.
    distance = math.hypot(*((a-b)/scale for a, b, scale in
        zip(query["vector"], stored["vector"], plan["feature_scales"], strict=True)))
    return distance if distance <= plan["maximum_support_distance"] else None


def contextual_offsets(query, records, plan, config):
    """Expose the actual supporting window IDs, including negative outcomes."""
    neighbors = [[] for _ in plan["actions"]]
    for record in records:
        distance = context_distance(query, record["cue"], plan)
        if distance is not None:
            neighbors[record["credited_action"]].append((distance, record["start_step"], record["residual_m_s"]))
    result = {}
    for action, candidates in enumerate(neighbors):
        selected = sorted(candidates)[:config["nearest_neighbors"]]
        if selected:
            weights = [1/(distance*distance + config["kernel_epsilon"]) for distance, _, _ in selected]
            offset = sum(weight*row[2] for weight, row in zip(weights, selected, strict=True))/sum(weights)
            cap = config["maximum_residual_m_s"]
            result[action] = dict(offset_m_s=max(-cap, min(cap, offset)),
                record_start_steps=[row[1] for row in selected], support_distance=max(row[0] for row in selected))
    return result


def select_action(predictions, offsets, plan):
    require(0 in predictions, "No supported baseline prediction")
    adjusted = {action: prediction["quality_m_s"] + offsets.get(action, {}).get("offset_m_s", 0.)
        for action, prediction in predictions.items()}
    chosen = min(adjusted, key=lambda action: (-adjusted[action], action))
    return chosen if adjusted[chosen] >= adjusted[0] + plan["minimum_predicted_gain_m_s"] else 0


def validate_statistics(value, last_step, mode, plan, config):
    require(set(value) == {"records", "updates", "evictions"}
            and type(value["records"]) is list
            and all(type(value[key]) is int and value[key] >= 0 for key in ["updates", "evictions"])
            and len(value["records"]) == min(value["updates"], config["maximum_records"])
            and value["evictions"] == max(0, value["updates"]-config["maximum_records"]),
            "Invalid bounded record statistics")
    require(mode in EPISODIC or value["updates"] == 0, "Feedback in memory-off mode")
    previous_end = -1
    for record in value["records"]:
        require(set(record) == {"start_step", "observed_at_step", "applied_action", "credited_action", "cue",
                "predicted_quality_m_s", "observed_quality_m_s", "residual_m_s"}
                and all(type(record[key]) is int for key in ["start_step", "observed_at_step", "applied_action", "credited_action"])
                and record["start_step"] >= max(0, previous_end)
                and record["observed_at_step"]-record["start_step"] == plan["decision_window_steps"]
                and record["observed_at_step"] <= last_step
                and 0 <= record["applied_action"] < len(plan["actions"])
                and record["credited_action"] == credited_action(record["applied_action"], mode, plan)
                and all(finite(record[key]) for key in ["predicted_quality_m_s", "observed_quality_m_s", "residual_m_s"])
                and record["predicted_quality_m_s"] <= 0. and record["observed_quality_m_s"] <= 0.,
                "Invalid completed feedback record")
        base.validate_cue(record["cue"])
        cap = config["maximum_residual_m_s"]
        require(record["residual_m_s"] == max(-cap, min(cap,
            record["observed_quality_m_s"]-record["predicted_quality_m_s"])), "Feedback residual arithmetic")
        previous_end = record["observed_at_step"]


def statistics(opaque):
    return copy.deepcopy({key: opaque[key] for key in ["records", "updates", "evictions"]})


def validate_opaque(opaque, step, request, model, mode, plan, config, component_sha):
    require(set(opaque) == {"schema_version", "component_sha256", "model_sha256", "mode", "seed", "last_step",
            "active", "records", "checkpoint", "updates", "rollbacks", "evictions"}
            and opaque["schema_version"] == config["memory_schema_version"]
            and opaque["component_sha256"] == component_sha and opaque["model_sha256"] == model.sha256
            and opaque["mode"] == mode and opaque["seed"] == request["seed"]
            and type(opaque["rollbacks"]) is int and opaque["rollbacks"] >= 0,
            "Crossed contextual episode memory")
    last = opaque["last_step"]
    require(type(last) is int and last >= 0 and step == last+1, "Stale/noncontiguous provider observation")
    validate_statistics(statistics(opaque), last, mode, plan, config)
    if opaque["checkpoint"] is not None:
        validate_statistics(opaque["checkpoint"], last, mode, plan, config)
    active = opaque["active"]
    if active is not None:
        require(set(active) == {"action", "start_step", "start_position", "start_cue", "prediction", "support_distance", "case_ids"}
                and type(active["action"]) is int and 0 <= active["action"] < len(plan["actions"])
                and type(active["start_step"]) is int and 0 <= active["start_step"] <= last
                and step-active["start_step"] <= plan["decision_window_steps"]
                and len(active["start_position"]) == 2 and all(finite(v) for v in active["start_position"])
                and finite(active["prediction"]) and active["prediction"] <= 0.
                and finite(active["support_distance"]) and 0 <= active["support_distance"] <= plan["maximum_support_distance"]
                and type(active["case_ids"]) is list and 1 <= len(active["case_ids"]) <= plan["nearest_neighbors"]
                and all(isinstance(v, str) and v for v in active["case_ids"]), "Invalid held decision")
        base.validate_cue(active["start_cue"])
        require(not opaque["records"] or active["start_step"] >= opaque["records"][-1]["observed_at_step"],
                "Held decision overlaps completed feedback")


def respond(core, request, model, mode="frozen", operation=None):
    config, plan, doc = contract(), model.plan(), model.document()
    component_sha = digest(core, config)
    require(plan == base.contract(), "Crossed base contract")
    require(mode in MODES and operation in [None, "checkpoint", "rollback", "reset"], "Runtime option")
    require(request["provider_id"] == config["provider_id"]
            and request["expected_provider_version"] == version(core, config, mode)
            and request["expected_model_id"] == model.model_id and request["expected_model_sha256"] == model.sha256
            and request["expected_training_corpus_id"] == doc["frozen_corpus_id"]
            and request["expected_training_corpus_sha256"] == doc["frozen_corpus_sha256"], "Model/corpus/provider mismatch")
    require(digest(core, request["descriptor"]) == plan["descriptor_sha256"], "Unsupported morphology")
    baseline = request["deterministic_baseline"]["ordered_commands"]
    require([row["actuator_id"] for row in baseline] == plan["ordered_actuator_ids"], "Actuator order")
    memory = copy.deepcopy(request["provider_memory"])
    require(set(memory) == {"schema_version", "provider_id", "reset_epoch", "sequence", "opaque_state", "opaque_state_sha256", "weights_mutated"}
            and memory["schema_version"] == "sporespore_adaptation_provider_memory_v1"
            and memory["provider_id"] == config["provider_id"] and memory["weights_mutated"] is False
            and all(type(memory[key]) is int and memory[key] >= 0 for key in ["sequence", "reset_epoch"])
            and digest(core, memory["opaque_state"]) == memory["opaque_state_sha256"], "Provider memory binding")
    state, step = request["state"], request["state"]["semantic_step"]
    require(type(step) is int and step >= 0 and state["sample_time_s"] == step*plan["controller_dt_s"], "Canonical clock")
    status, distance, corrections = "no_proposal", 0., []
    diagnostics = ["confidence denotes declared case support, not a calibrated safety probability"]
    if operation == "reset":
        memory = empty_memory(core, memory["reset_epoch"]+1)
        status = "reset"
        diagnostics.append("explicit_reset")
    else:
        opaque = memory["opaque_state"]
        if not opaque:
            require(opaque == {} and memory["sequence"] == 0, "Missing contextual episode state")
            opaque = dict(schema_version=config["memory_schema_version"], component_sha256=component_sha,
                model_sha256=model.sha256, mode=mode, seed=request["seed"], last_step=None, active=None,
                records=[], checkpoint=None, updates=0, rollbacks=0, evictions=0)
        else:
            require(memory["sequence"] > 0, "Missing memory sequence")
            validate_opaque(opaque, step, request, model, mode, plan, config, component_sha)
        if operation == "checkpoint":
            opaque["checkpoint"] = statistics(opaque)
            diagnostics.append("checkpoint_created")
        if operation == "rollback":
            require(opaque["checkpoint"] is not None, "No valid rollback checkpoint")
            opaque.update(copy.deepcopy(opaque["checkpoint"]))
            opaque.update(active=None, rollbacks=opaque["rollbacks"]+1)
            diagnostics.append("statistics_rolled_back; controller clock not rewound")
        try:
            query = base.cue(request, plan)
        except (ValueError, KeyError, TypeError) as exc:
            query = None
            diagnostics.append("unsupported_cue: " + str(exc))
        if query is None or request["deterministic_baseline"]["safe_no_actuation"]:
            opaque["active"] = None
            status = "unsupported"
        elif operation != "rollback":
            position = [state["base_pose_world"]["position_m"][axis] for axis in ["x", "z"]]
            active = opaque["active"]
            if active is not None and step-active["start_step"] == plan["decision_window_steps"]:
                if mode in EPISODIC:
                    observed = base.quality(active["start_position"], position,
                        plan["decision_window_steps"]*plan["controller_dt_s"], plan)
                    credited = credited_action(active["action"], mode, plan)
                    cap = config["maximum_residual_m_s"]
                    opaque["records"].append(dict(start_step=active["start_step"], observed_at_step=step,
                        applied_action=active["action"], credited_action=credited, cue=copy.deepcopy(active["start_cue"]),
                        predicted_quality_m_s=active["prediction"], observed_quality_m_s=observed,
                        residual_m_s=max(-cap, min(cap, observed-active["prediction"]))))
                    opaque["updates"] += 1
                    if len(opaque["records"]) > config["maximum_records"]:
                        opaque["records"].pop(0)
                        opaque["evictions"] += 1
                    diagnostics.append("episode_outcome_update:" + str(credited))
                    if mode == "episodic_shuffled":
                        diagnostics.append("episode_association_shuffled:" + str(credited))
                active = None
            if active is None:
                predictions = model.predictions(query)
                if 0 not in predictions:
                    status = "unsupported"
                else:
                    offsets = contextual_offsets(query, opaque["records"], plan, config) if mode in EPISODIC else {}
                    chosen = select_action(predictions, offsets, plan)
                    for action, support in sorted(offsets.items()):
                        diagnostics.append("context_feedback:" + json.dumps(dict(action=action, **support),
                            sort_keys=True, separators=(",", ":"), allow_nan=False))
                    prediction = predictions[chosen]
                    active = dict(action=chosen, start_step=step, start_position=position, start_cue=copy.deepcopy(query),
                        prediction=prediction["quality_m_s"], support_distance=prediction["support_distance"], case_ids=prediction["case_ids"])
            opaque["active"] = active
            if active is not None:
                action, distance = active["action"], active["support_distance"]
                diagnostics += ["selected_action:" + plan["actions"][action]["action_id"], "held_from_step:" + str(active["start_step"])]
                coefficients = plan["actions"][action]["ordered_coefficients"]
                if mode == "shuffled":
                    coefficients = [-v for v in coefficients]
                    diagnostics.append("sign_reversed_association; requested absolute magnitudes preserved")
                if action and mode != "disabled":
                    status = "applied"
                    corrections = [dict(actuator_id=row["actuator_id"],
                        canonical_velocity_delta_rad_s=coefficient*row["combined_canonical_target_velocity_rad_s"])
                        for coefficient, row in zip(coefficients, baseline, strict=True)]
        opaque["last_step"] = step
        memory.update(sequence=memory["sequence"]+1, opaque_state=opaque, opaque_state_sha256=digest(core, opaque))
    require(len(core.canonicalize_json(memory["opaque_state"])["canonical_json"].encode()) <= config["maximum_opaque_state_bytes"],
            "Episode memory capacity")
    return dict(schema_version="sporespore_adaptation_provider_response_v1", request_id=request["request_id"],
        request_sha256=digest(core, request), status=status, confidence=1., support_distance=distance,
        ordered_corrections=corrections, next_memory=memory,
        provenance=dict(provider_id=config["provider_id"], provider_version=request["expected_provider_version"],
            model_id=model.model_id, model_sha256=model.sha256, training_corpus_id=doc["frozen_corpus_id"],
            training_corpus_sha256=doc["frozen_corpus_sha256"], seed=request["seed"], engine_specific_logic_used=False,
            direct_world_access_used=False, weights_mutated=False, physical_acceptance_authority=False),
        candidate_experience=None, diagnostics=diagnostics, physical_acceptance_authority=False)


def call_provider(core, request, model, mode="frozen", operation=None):
    """Retain errors; the unchanged core resolves provider absence to baseline."""
    try:
        response, error = respond(core, request, model, mode, operation), None
    except Exception as exc:
        response, error = None, dict(type=type(exc).__name__, message=str(exc))
    return dict(provider_response=response, provider_error=error,
        world_build_count=0, physical_acceptance_authority=False)
