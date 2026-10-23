"""Fit a bounded casebook and use it through the existing optional-provider ABI.

The casebook is immutable. Tier 3 changes only explicit bounded episode memory;
neither fitting nor runtime selection grants physical or release authority.
"""
from dataclasses import dataclass
import copy
import json
import math
from pathlib import Path


CONTRACT = Path(__file__).with_name("contract_v1.json")
MODES = ("frozen", "episodic", "disabled", "shuffled", "episodic_shuffled")


def require(condition, message):
    if not condition:
        raise ValueError(message)


def finite(value):
    return type(value) in (int, float) and math.isfinite(value)


def digest(core, value):
    return core.canonicalize_json(value)["sha256"]


def contract():
    value = json.loads(CONTRACT.read_text(encoding="utf-8"))
    require(value["schema_version"] == "locolemotion_bounded_retrieval_contract_v1"
            and value["decision_window_steps"] == value["phase_bin_steps"] == 30
            and value["fitting"]["calibration_and_evaluation_may_fit"] is False
            and value["authority"]["physical_acceptance_authority"] is False,
            "Retrieval contract")
    return value


def cue(request, plan):
    """Use canonical observations and explicit controller phase, no native API."""
    state = request["state"]
    command = request["command"]
    context = request["controller_context"]
    require(context["source_policy_id"] == plan["policy_id"] and context["engine_specific"] is False,
            "Unsupported policy context")
    require(command["phase_progression_mode"] == "clocked" and command["gait_family_id"] == "lateral_wave"
            and command["gait_amplitude"] == 1. and command["desired_heading_rad"] == 0.
            and command["desired_planar_velocity_task_m_s"] == dict(x=plan["desired_forward_velocity_m_s"], y=0., z=0.),
            "Unsupported task")
    q = state["base_pose_world"]["orientation_xyzw"]
    x, y, z, w = [q[key] for key in "xyzw"]
    require(all(finite(v) for v in [x, y, z, w]) and abs(x*x+y*y+z*z+w*w-1.) < 1e-5,
            "Invalid orientation")
    up = [2*(x*y-z*w), 1-2*(x*x+z*z), 2*(y*z+x*w)]
    pose = state["base_pose_world"]["position_m"]
    velocity = state["base_twist_world"]["linear_velocity_m_s"]
    vector = [pose["y"], up[0], up[2], velocity["x"], velocity["z"],
              state["base_twist_world"]["angular_velocity_rad_s"]["y"]]
    require(all(finite(v) for v in [*vector, pose["x"], pose["z"]]), "Nonfinite cue")
    require(vector[0] >= plan["minimum_height_m"]
            and math.acos(max(-1., min(1., up[1]))) <= plan["maximum_tilt_rad"], "Outside posture domain")
    contacts = state["ordered_contact_observations"]
    require([r["contact_site_id"] for r in contacts] == plan["ordered_contact_site_ids"]
            and all(type(r["presence"]) is bool and type(r["bears_support"]) is bool for r in contacts),
            "Unavailable contact cue")
    limbs = context["controller_memory"]["ordered_limb_memory"]
    steps = {row["limb_id"]: row["gait_step"] for row in limbs}
    require(len(steps) == len(limbs) == 4 and set(steps) == set(plan["ordered_limb_ids"])
            and all(type(v) is int and v >= 0 for v in steps.values()), "Invalid gait phase")
    return dict(vector=vector, phase=[steps[name] % plan["phase_cycle_steps"] // plan["phase_bin_steps"]
                for name in plan["ordered_limb_ids"]],
                contact_mask=sum((1 << i) for i, row in enumerate(contacts) if row["bears_support"]))


def validate_cue(value):
    require(set(value) == {"vector", "phase", "contact_mask"}
            and len(value["vector"]) == 6 and all(finite(v) for v in value["vector"])
            and len(value["phase"]) == 4 and all(type(v) is int and 0 <= v < 12 for v in value["phase"])
            and type(value["contact_mask"]) is int and 0 <= value["contact_mask"] < 16, "Malformed case cue")


def quality(start_position, end_position, duration, plan):
    require(finite(duration) and duration > 0 and all(finite(v) for v in [*start_position, *end_position])
            and len(start_position) == len(end_position) == 2, "Invalid outcome window")
    forward = (end_position[0] - start_position[0]) / duration
    lateral = (end_position[1] - start_position[1]) / duration
    return -abs(forward - plan["desired_forward_velocity_m_s"]) - plan["lateral_error_weight"] * abs(lateral)


def archive_index(metrics, plan):
    bins = []
    for axis, edges in zip(plan["archive"]["axes"], plan["archive"]["edges"], strict=True):
        value = metrics[axis]
        require(finite(value), "Nonfinite archive axis")
        indices = [i for i in range(len(edges)-1) if edges[i] <= value < edges[i+1]]
        if not indices:
            return None
        bins.append(indices[0])
    return bins


def fit(core, episodes, *, frozen_corpus_id, frozen_corpus_sha256, source_receipt_sha256, synthetic):
    """Fit only declared training groups; retain every rejected/failed identity.

    Native callers must first verify the source campaign and raw-episode joins.
    This pure fitting function verifies its data shape and split membership; its
    result remains an unpromoted model candidate even with a native source.
    """
    plan = contract()
    require(type(synthetic) is bool and bool(frozen_corpus_id), "Corpus identity")
    for value in [frozen_corpus_sha256, source_receipt_sha256]:
        require(isinstance(value, str) and len(value) == 71 and value.startswith("sha256:")
                and all(c in "0123456789abcdef" for c in value[7:]), "Corpus/source digest")
    train_groups = {r["group_id"] for r in plan["groups"] if r["partition"] == "train"}
    actions = [row["action_id"] for row in plan["actions"]]
    cases, ledger, elites = [], [], {}
    identities = set()
    pairs = set()
    for episode in episodes:
        require(set(episode) == {"episode_id", "group_id", "action_id", "outcome", "failure_code",
                "raw_episode_sha256", "synthetic", "metrics", "windows"}, "Episode fields")
        require(episode["group_id"] in train_groups and episode["action_id"] in actions
                and episode["synthetic"] is synthetic, "Split leakage or crossed episode identity")
        identity = episode["episode_id"]
        pair = (episode["group_id"], episode["action_id"])
        require(isinstance(identity, str) and identity and identity not in identities and pair not in pairs,
                "Duplicate episode/group-action")
        identities.add(identity)
        pairs.add(pair)
        require(episode["outcome"] in ["positive", "negative", "rejected", "invalid", "incomplete"], "Episode outcome")
        require((episode["failure_code"] is None) == (episode["outcome"] == "positive"), "Failure classification")
        raw = episode["raw_episode_sha256"]
        require(isinstance(raw, str) and len(raw) == 71 and raw.startswith("sha256:")
                and all(c in "0123456789abcdef" for c in raw[7:]), "Raw episode digest")
        ledger.append(dict(episode_id=identity, group_id=episode["group_id"], action_id=episode["action_id"],
            outcome=episode["outcome"], failure_code=episode["failure_code"], episode_sha256=digest(core, episode),
            raw_episode_sha256=raw))
        if episode["outcome"] != "positive":
            # Failed/invalid trials remain visible, but cannot supply positive cases.
            continue
        require(set(episode["metrics"]) == {"mean_height_m", "lateral_displacement_m", "quality_m_s"}
                and all(finite(v) for v in episode["metrics"].values())
                and episode["metrics"]["quality_m_s"] <= 0., "Episode metrics")
        starts = []
        for window in episode["windows"]:
            require(set(window) == {"start_step", "cue", "start_position_xz_m", "end_position_xz_m", "quality_m_s"}, "Window fields")
            step = window["start_step"]
            require(type(step) is int and step >= 0 and step % plan["decision_window_steps"] == 0
                    and step + plan["decision_window_steps"] <= plan["training_episode_outer_steps"], "Window step")
            validate_cue(window["cue"])
            expected = quality(window["start_position_xz_m"], window["end_position_xz_m"],
                               plan["decision_window_steps"] * plan["controller_dt_s"], plan)
            require(window["quality_m_s"] == expected, "Window outcome does not match positions")
            starts.append(step)
            cases.append(dict(case_id=identity + "_" + str(step), episode_id=identity,
                action_index=actions.index(episode["action_id"]), cue=copy.deepcopy(window["cue"]), quality_m_s=expected))
        require(starts == list(range(0, plan["training_episode_outer_steps"], plan["decision_window_steps"])), "Missing/reordered training window")
        index = archive_index(episode["metrics"], plan)
        if index is not None:
            key = tuple(index)
            entry = dict(niche=index, episode_id=identity, action_id=episode["action_id"], quality_m_s=episode["metrics"]["quality_m_s"])
            previous = elites.get(key)
            if previous is None or (-entry["quality_m_s"], identity) < (-previous["quality_m_s"], previous["episode_id"]):
                elites[key] = entry
    require(pairs == {(group, action) for group in train_groups for action in actions}, "Incomplete training trial ledger")
    require(cases and any(row["action_index"] == 0 for row in cases), "No eligible baseline cases")
    document = dict(schema_version="locolemotion_fitted_retrieval_model_v1", contract_sha256=digest(core, plan),
        synthetic=synthetic, fitted=True, frozen_corpus_id=frozen_corpus_id, frozen_corpus_sha256=frozen_corpus_sha256,
        source_receipt_sha256=source_receipt_sha256, ordered_episode_ledger=ledger,
        ordered_elites=[elites[key] for key in sorted(elites)], ordered_cases=cases,
        base_model_immutable=True, physical_acceptance_authority=False, release_authority=False)
    return FrozenModel.load(core, document)


@dataclass(frozen=True)
class FrozenModel:
    """Store model data as immutable text/tuples; expose only copies of documents."""
    serialized: str
    sha256: str
    cases: tuple
    plan_serialized: str

    @classmethod
    def load(cls, core, document):
        plan = contract()
        require(set(document) == {"schema_version", "contract_sha256", "synthetic", "fitted", "frozen_corpus_id",
                "frozen_corpus_sha256", "source_receipt_sha256", "ordered_episode_ledger", "ordered_elites",
                "ordered_cases", "base_model_immutable", "physical_acceptance_authority", "release_authority"}
                and document["schema_version"] == "locolemotion_fitted_retrieval_model_v1"
                and document["contract_sha256"] == digest(core, plan) and document["fitted"] is True
                and type(document["synthetic"]) is bool and document["base_model_immutable"] is True
                and document["physical_acceptance_authority"] is False and document["release_authority"] is False,
                "Model identity/authority")
        groups = {row["group_id"] for row in plan["groups"] if row["partition"] == "train"}
        actions = [row["action_id"] for row in plan["actions"]]
        ledger = document["ordered_episode_ledger"]
        by_episode = {row["episode_id"]: row for row in ledger}
        require(len(by_episode) == len(ledger) == len(groups)*len(actions)
                and {(r["group_id"], r["action_id"]) for r in ledger} == {(g, a) for g in groups for a in actions}, "Model trial ledger/split")
        rows = []
        ids = set()
        for row in document["ordered_cases"]:
            validate_cue(row["cue"])
            require(set(row) == {"case_id", "episode_id", "action_index", "cue", "quality_m_s"}
                    and row["episode_id"] in by_episode and by_episode[row["episode_id"]]["outcome"] == "positive"
                    and row["case_id"] not in ids and type(row["action_index"]) is int
                    and 0 <= row["action_index"] < len(plan["actions"])
                    and actions[row["action_index"]] == by_episode[row["episode_id"]]["action_id"]
                    and finite(row["quality_m_s"]) and row["quality_m_s"] <= 0., "Malformed fitted case")
            ids.add(row["case_id"])
            rows.append((row["action_index"], tuple(row["cue"]["phase"]), row["cue"]["contact_mask"],
                         tuple(row["cue"]["vector"]), row["quality_m_s"], row["case_id"]))
        require(rows, "Empty model")
        return cls(json.dumps(document, sort_keys=True, separators=(",", ":"), allow_nan=False), digest(core, document),
                   tuple(rows), json.dumps(plan, sort_keys=True, separators=(",", ":"), allow_nan=False))

    def document(self):
        return json.loads(self.serialized)

    def plan(self):
        return json.loads(self.plan_serialized)

    @property
    def model_id(self):
        return "s169_casebook_" + self.sha256[7:27]

    def predictions(self, query):
        plan = self.plan()
        validate_cue(query)
        neighbors = [[] for _ in plan["actions"]]
        for action, phase, mask, vector, score, case_id in self.cases:
            if phase != tuple(query["phase"]) or mask != query["contact_mask"]:
                continue
            distance = math.sqrt(sum(((a-b)/scale)**2 for a, b, scale in zip(query["vector"], vector, plan["feature_scales"], strict=True)))
            if distance <= plan["maximum_support_distance"]:
                neighbors[action].append((distance, case_id, score))
        predictions = {}
        for action, candidates in enumerate(neighbors):
            selected = sorted(candidates)[:plan["nearest_neighbors"]]
            if selected:
                weights = [1/(1e-6 + distance*distance) for distance, _, _ in selected]
                predictions[action] = dict(quality_m_s=sum(w*row[2] for w, row in zip(weights, selected, strict=True))/sum(weights),
                    support_distance=max(row[0] for row in selected), case_ids=[row[1] for row in selected])
        return predictions


def empty_memory(core, reset_epoch=0, plan=None):
    plan = contract() if plan is None else plan
    return dict(schema_version="sporespore_adaptation_provider_memory_v1", provider_id=plan["provider_id"],
        reset_epoch=reset_epoch, sequence=0, opaque_state={}, opaque_state_sha256=digest(core, {}), weights_mutated=False)


def bind_request(core, request, model, mode):
    """Rebind a host-created valid provider request to this exact candidate."""
    require(mode in MODES, "Provider mode")
    value = copy.deepcopy(request)
    plan = model.plan()
    doc = model.document()
    value.update(provider_id=plan["provider_id"], expected_provider_version=plan["provider_version"] + "_" + mode,
        expected_model_id=model.model_id, expected_model_sha256=model.sha256,
        expected_training_corpus_id=doc["frozen_corpus_id"], expected_training_corpus_sha256=doc["frozen_corpus_sha256"])
    value["provider_memory"] = empty_memory(core, plan=plan)
    value["safety_envelope"].update(minimum_confidence=1., maximum_support_distance=plan["maximum_support_distance"])
    for limit in value["safety_envelope"]["ordered_actuator_limits"]:
        limit.update(maximum_absolute_correction_rad_s=plan["maximum_absolute_correction_rad_s"],
                     maximum_slew_per_step_rad_s=plan["maximum_slew_per_step_rad_s"], previous_applied_correction_rad_s=0.)
    return value


def respond(core, request, model, mode="frozen", operation=None):
    """Select a held correction; optionally update bounded episode score offsets."""
    plan = model.plan()
    doc = model.document()
    require(mode in MODES and operation in [None, "checkpoint", "rollback", "reset"], "Runtime option")
    require(request["provider_id"] == plan["provider_id"]
            and request["expected_provider_version"] == plan["provider_version"] + "_" + mode
            and request["expected_model_id"] == model.model_id and request["expected_model_sha256"] == model.sha256
            and request["expected_training_corpus_id"] == doc["frozen_corpus_id"]
            and request["expected_training_corpus_sha256"] == doc["frozen_corpus_sha256"], "Model/corpus/provider mismatch")
    require(digest(core, request["descriptor"]) == plan["descriptor_sha256"], "Unsupported morphology")
    baseline = request["deterministic_baseline"]["ordered_commands"]
    require([row["actuator_id"] for row in baseline] == plan["ordered_actuator_ids"], "Actuator order")
    memory = copy.deepcopy(request["provider_memory"])
    require(memory["provider_id"] == plan["provider_id"] and memory["weights_mutated"] is False
            and digest(core, memory["opaque_state"]) == memory["opaque_state_sha256"], "Provider memory binding")
    state = request["state"]
    step = state["semantic_step"]
    require(type(step) is int and step >= 0 and state["sample_time_s"] == step * plan["controller_dt_s"], "Canonical clock")
    opaque = memory["opaque_state"]
    status, distance, corrections = "no_proposal", 0., []
    diagnostics = ["confidence denotes declared case support, not a calibrated safety probability"]
    if operation == "reset":
        memory = empty_memory(core, memory["reset_epoch"] + 1, plan=plan)
        status = "reset"
        diagnostics.append("explicit_reset")
    else:
        if not opaque:
            opaque = dict(schema_version="locolemotion_retrieval_episode_memory_v1", model_sha256=model.sha256,
                mode=mode, seed=request["seed"], last_step=None, active=None, offsets=[0.] * len(plan["actions"]),
                counts=[0] * len(plan["actions"]), checkpoint=None, updates=0, rollbacks=0)
        require(set(opaque) == {"schema_version", "model_sha256", "mode", "seed", "last_step", "active", "offsets", "counts", "checkpoint", "updates", "rollbacks"}
                and opaque["schema_version"] == "locolemotion_retrieval_episode_memory_v1"
                and opaque["model_sha256"] == model.sha256 and opaque["mode"] == mode and opaque["seed"] == request["seed"], "Crossed episode memory")
        count = len(plan["actions"])
        def statistics_valid(offsets, counts):
            return (len(offsets) == len(counts) == count
                and all(finite(v) and abs(v) <= plan["episodic_memory"]["maximum_offset_m_s"] for v in offsets)
                and all(type(v) is int and 0 <= v <= plan["episodic_memory"]["maximum_count"] for v in counts))
        require(statistics_valid(opaque["offsets"], opaque["counts"])
                and all(type(opaque[k]) is int and opaque[k] >= 0 for k in ["updates", "rollbacks"]), "Invalid episode statistics")
        require(opaque["last_step"] is None or step == opaque["last_step"] + 1, "Stale/noncontiguous provider observation")
        if operation == "checkpoint":
            opaque["checkpoint"] = dict(offsets=opaque["offsets"][:], counts=opaque["counts"][:], updates=opaque["updates"])
            diagnostics.append("checkpoint_created")
        if operation == "rollback":
            saved = opaque["checkpoint"]
            require(saved is not None and set(saved) == {"offsets", "counts", "updates"}
                    and statistics_valid(saved["offsets"], saved["counts"])
                    and type(saved["updates"]) is int and saved["updates"] >= 0, "No valid rollback checkpoint")
            opaque.update(offsets=saved["offsets"][:], counts=saved["counts"][:], updates=saved["updates"], active=None,
                          rollbacks=opaque["rollbacks"] + 1)
            diagnostics.append("statistics_rolled_back; controller clock not rewound")
        try:
            query = cue(request, plan)
        except (ValueError, KeyError, TypeError) as exc:
            query = None
            diagnostics.append("unsupported_cue: " + str(exc))
        if query is None or request["deterministic_baseline"]["safe_no_actuation"]:
            opaque["active"] = None
            status = "unsupported"
        elif operation != "rollback":
            position = [state["base_pose_world"]["position_m"][axis] for axis in ["x", "z"]]
            active = opaque["active"]
            if active is not None:
                require(set(active) == {"action", "start_step", "start_position", "prediction", "support_distance", "case_ids"}
                        and type(active["action"]) is int and 0 <= active["action"] < count
                        and type(active["start_step"]) is int and 0 <= step-active["start_step"] <= plan["decision_window_steps"]
                        and finite(active["prediction"]) and finite(active["support_distance"]), "Invalid held decision")
                if step-active["start_step"] == plan["decision_window_steps"]:
                    if mode in ["episodic", "episodic_shuffled"]:
                        observed = quality(active["start_position"], position, plan["decision_window_steps"] * plan["controller_dt_s"], plan)
                        action = active["action"]
                        if mode == "episodic_shuffled" and action:
                            original = plan["actions"][action]
                            action = next(i for i, candidate in enumerate(plan["actions"])
                                if candidate["global_scale"] == -original["global_scale"]
                                and candidate["side_bias"] == -original["side_bias"])
                            diagnostics.append("episode_association_shuffled:" + str(action))
                        cap = plan["episodic_memory"]["maximum_offset_m_s"]
                        residual = max(-cap, min(cap, observed-active["prediction"]))
                        opaque["counts"][action] = min(opaque["counts"][action]+1, plan["episodic_memory"]["maximum_count"])
                        old = opaque["offsets"][action]
                        opaque["offsets"][action] = max(-cap, min(cap, old + (residual-old)/opaque["counts"][action]))
                        opaque["updates"] += 1
                        diagnostics.append("episode_outcome_update:" + str(action))
                    active = None
            if active is None:
                predictions = model.predictions(query)
                if 0 not in predictions:
                    status = "unsupported"
                else:
                    adjusted = {a: p["quality_m_s"] + (opaque["offsets"][a] if mode in ["episodic", "episodic_shuffled"] else 0.) for a, p in predictions.items()}
                    chosen = min(adjusted, key=lambda a: (-adjusted[a], a))
                    if adjusted[chosen] < adjusted[0] + plan["minimum_predicted_gain_m_s"]:
                        chosen = 0
                    prediction = predictions[chosen]
                    active = dict(action=chosen, start_step=step, start_position=position,
                        prediction=prediction["quality_m_s"], support_distance=prediction["support_distance"], case_ids=prediction["case_ids"])
            opaque["active"] = active
            if active is not None:
                action = active["action"]
                distance = active["support_distance"]
                diagnostics.append("selected_action:" + plan["actions"][action]["action_id"])
                diagnostics.append("held_from_step:" + str(active["start_step"]))
                coefficients = plan["actions"][action]["ordered_coefficients"]
                if mode == "shuffled":
                    coefficients = [-v for v in coefficients]
                    diagnostics.append("sign_reversed_association; requested absolute magnitudes preserved")
                if action and mode != "disabled":
                    status = "applied"
                    corrections = [dict(actuator_id=row["actuator_id"], canonical_velocity_delta_rad_s=coefficient*row["combined_canonical_target_velocity_rad_s"])
                        for coefficient, row in zip(coefficients, baseline, strict=True)]
        opaque["last_step"] = step
        memory.update(sequence=memory["sequence"] + 1, opaque_state=opaque, opaque_state_sha256=digest(core, opaque))
    require(len(core.canonicalize_json(memory["opaque_state"])["canonical_json"].encode()) <= plan["episodic_memory"]["maximum_opaque_state_bytes"], "Episode memory capacity")
    return dict(schema_version="sporespore_adaptation_provider_response_v1", request_id=request["request_id"],
        request_sha256=digest(core, request), status=status, confidence=1., support_distance=distance,
        ordered_corrections=corrections, next_memory=memory,
        provenance=dict(provider_id=plan["provider_id"], provider_version=request["expected_provider_version"],
            model_id=model.model_id, model_sha256=model.sha256, training_corpus_id=doc["frozen_corpus_id"],
            training_corpus_sha256=doc["frozen_corpus_sha256"], seed=request["seed"], engine_specific_logic_used=False,
            direct_world_access_used=False, weights_mutated=False, physical_acceptance_authority=False),
        candidate_experience=None, diagnostics=diagnostics, physical_acceptance_authority=False)


def call_provider(core, request, model, mode="frozen", operation=None):
    """The host retains a provider error and resolves absence to exact baseline.

    Host-request validation still belongs to the core. An invalid host request
    is not made valid by this optional-provider error boundary.
    """
    try:
        response = respond(core, request, model, mode, operation)
        error = None
    except Exception as exc:
        response = None
        error = dict(type=type(exc).__name__, message=str(exc))
    return dict(provider_response=response, provider_error=error,
                world_build_count=0, physical_acceptance_authority=False)
