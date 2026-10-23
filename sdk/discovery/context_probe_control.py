"""Observe a common baseline prefix, then apply one declared fixed controller.

The prefix is issued through real no-proposal responses. This preserves exact
baseline commands while recording truthful v1 history; an absent provider has
no representable history status and must never be relabeled after resolution.
Only the 64 past actions and their observed next states feed the context vector.
"""
import copy
import hashlib
import json
import math

from body_height_feedback_control import BodyHeightFeedbackController
from portable_search_control import bridge, map_resolution, proposal_request
from adaptation_provider.retrieval import causal_history_v1 as history
from adaptation_provider.body_height_feedback_v1 import require

PROBE_STEPS = 64
DT = 1. / 120.
JOINTS = [leg + "_" + joint for leg in
          ["front_left", "front_right", "rear_left", "rear_right"] for joint in ["hip", "knee"]]
ACTUATORS = [joint + "_motor" for joint in JOINTS]
FEATURE_NAMES = [joint + "_" + statistic for statistic in
                 ["mean_velocity_tracking_error_rad_s", "rms_velocity_tracking_error_rad_s"] for joint in JOINTS]


def context_features(request):
    """Measure response to issued velocity commands without condition labels.

    Each error is (q[t+1]-q[t])/dt minus the final speed-limited command issued
    at t. The current state supplies only the last observed endpoint. Means
    and RMS errors are computed per joint; no future outcome enters a feature.
    """
    window = request["history"]
    history.attach(request, window)
    entries = window["ordered_entries"]
    require(request["state"]["semantic_step"] == PROBE_STEPS and len(entries) == PROBE_STEPS,
            "Context requires the complete 64-step baseline prefix")
    states = [entry["state"] for entry in entries] + [request["state"]]
    positions = []
    for step, state in enumerate(states):
        joints = state["ordered_joint_observations"]
        require(state["semantic_step"] == step and state["sample_time_s"] == step * DT
                and [joint["joint_id"] for joint in joints] == JOINTS,
                "Context canonical clock/joint order")
        require(all(joint["validity"]["position"] is True and type(joint["position_rad"]) in (int, float)
                    and math.isfinite(joint["position_rad"]) for joint in joints), "Context finite valid positions")
        positions.append([joint["position_rad"] for joint in joints])
    errors, causal = [], []
    for step, entry in enumerate(entries):
        require(entry["semantic_step"] == step and entry["provider_status"] == "no_proposal"
                and entry["adaptation_applied"] is False
                and [row["actuator_id"] for row in entry["deterministic_baseline"]["ordered_commands"]] == ACTUATORS,
                "Context prefix must contain actual baseline actions")
        issued = history.final_velocities(entry)
        require(all(type(value) in (int, float) and math.isfinite(value) for value in issued), "Context finite issued action")
        errors.append([(after-before)/DT-target for before, after, target in
                       zip(positions[step], positions[step+1], issued, strict=True)])
        # This binding excludes provider/model identities, condition labels and
        # proposed post-prefix choices, so independently run arms can be joined.
        causal.append(dict(state=entry["state"], command=entry["command"], issued_velocity_rad_s=issued))
    values = [sum(row[joint] for row in errors)/PROBE_STEPS for joint in range(8)]
    values += [math.sqrt(sum(row[joint]**2 for row in errors)/PROBE_STEPS) for joint in range(8)]
    require(all(math.isfinite(value) for value in values), "Context finite feature vector")
    payload = dict(past=causal, current_state=request["state"])
    digest = hashlib.sha256(json.dumps(payload, sort_keys=True, separators=(",", ":"), allow_nan=False).encode()).hexdigest()
    return dict(schema_version="locolemotion_causal_joint_response_v1", decision_step=PROBE_STEPS,
                past_entries=PROBE_STEPS, names=FEATURE_NAMES, values=values, causal_input_sha256=digest)


def no_proposal(core, request):
    memory = copy.deepcopy(request["provider_memory"])
    memory["sequence"] += 1
    return dict(schema_version="sporespore_adaptation_provider_response_v1", request_id=request["request_id"],
        request_sha256=core.canonicalize_json(request)["sha256"], status="no_proposal", confidence=1., support_distance=0.,
        ordered_corrections=[], next_memory=memory,
        provenance=dict(provider_id=request["provider_id"], provider_version=request["expected_provider_version"],
            model_id=request["expected_model_id"], model_sha256=request["expected_model_sha256"],
            training_corpus_id=request["expected_training_corpus_id"], training_corpus_sha256=request["expected_training_corpus_sha256"],
            seed=request["seed"], engine_specific_logic_used=False, direct_world_access_used=False,
            weights_mutated=False, physical_acceptance_authority=False), candidate_experience=None,
        diagnostics=["declared baseline observation prefix or fixed baseline role; no learned choice"],
        physical_acceptance_authority=False)


class ContextProbeController(BodyHeightFeedbackController):
    def __init__(self, core, compiled, contract, cell):
        super().__init__(core, compiled, contract, cell)
        self.provider_memory["provider_id"] = "context_probe_repertoire"
        self.model_digest = core.canonicalize_json(dict(definition=self.model, candidate=self.candidate,
            probe_steps=PROBE_STEPS, feature_schema="locolemotion_causal_joint_response_v1"))["sha256"]
        self.index, self.next_step, self.closed = cell, 0, False
        self.history = history.empty()

    def close(self):
        if not self.closed:
            super().close()
            self.closed = True

    def step(self, state, stability, kinematics):
        require(not self.closed and type(state["semantic_step"]) is int
                and state["semantic_step"] == self.next_step, "Context controller lifecycle/clock")
        try:
            step = self.next_step
            command = bridge._motion_command(step, self.c["phase_mode"])
            request = dict(memory=self.memory, state=state, command=command)
            limbs = bridge._ordered_limb_steps(self.memory, self.context.morphology["ordered_limb_ids"])
            output = self.session.step(request)
            actuation = output["actuation"]
            require(actuation["receipt"]["controller_error"] is None and not actuation["failure_codes"],
                    "Context portable controller refusal")
            composition = bridge.compose_bw19v_step(self.context, actuation, stability, kinematics, limbs, self.composition_memory)
            provider = proposal_request(self.core, self.c, self.candidate, state, command, output,
                composition["canonical_actuation"], self.provider_memory, self.previous)
            provider.update(provider_id="context_probe_repertoire", expected_provider_version="context_probe_v1",
                            expected_model_sha256=self.model_digest)
            provider = history.attach(provider, self.history if step <= PROBE_STEPS else history.empty())
            features = context_features(provider) if step == PROBE_STEPS else None
            if step < PROBE_STEPS or self.candidate["mode"] == "baseline":
                response, detail = no_proposal(self.core, provider), dict(status="baseline")
            else:
                response, detail = super().response(provider)
            resolution_request = dict(schema_version="sporespore_adaptation_resolution_request_v1",
                                      provider_request=provider, provider_response=response)
            resolved = self.core.resolve_adaptation_v1(resolution_request)
            require(resolved["fallback_reason"] in ("none", "provider_no_proposal", "provider_absent", "safe_no_actuation"),
                    "Context unexpected resolver refusal")
            targets = map_resolution(composition["host_mapping"], resolved)
            if step < PROBE_STEPS:
                following, boundary = history.append_resolved(self.core, provider, resolved)
                require(boundary is None and len(following["ordered_entries"]) == step+1,
                        "Context history must retain truthful resolved prefix")
            else:
                following = history.empty()
            self.memory, self.provider_memory = output["next_memory"], resolved["next_memory"]
            self.previous = [row["applied_correction_rad_s"] for row in resolved["ordered_commands"]]
            self.history, self.next_step = following, step+1
            return dict(request=request, output=output, stability=stability, kinematics=kinematics,
                composition=composition, resolution_request=resolution_request, resolution=resolved,
                native_targets=targets, feedback=detail,
                context_probe=dict(phase="baseline_observation" if step < PROBE_STEPS else "fixed_controller",
                    planned_candidate_index=self.index, selected_candidate_index=self.index if step >= PROBE_STEPS else None,
                    history_entries=len(provider["history"]["ordered_entries"]), features=features,
                    learned_selection=False))
        except BaseException:
            self.close()
            raise
