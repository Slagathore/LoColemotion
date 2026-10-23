"""Support-only opposing-vertical compensation at command zero or sixteen.

The baseline and delayed roles share sixteen actual baseline commands. Both
immediate roles have no baseline prefix. The reference remains unchanged and
no classifier chooses actions.
"""
import copy

from portable_search_control import Controller, proposal
from adaptation_provider import support_vertical_feedback_v1 as feedback
from portable_search_control import bridge, map_resolution, proposal_request
from adaptation_provider.retrieval import causal_history_v1 as history
require = feedback.require

from context_probe_control import no_proposal
from early_context_v1 import features as context_features

ROLES = [dict(id="baseline", candidate_index=0, activation_step=None, baseline_probe_steps=16),
         dict(id="height_immediate", candidate_index=2, activation_step=0, baseline_probe_steps=0),
         dict(id="vertical_immediate", candidate_index=3, activation_step=0, baseline_probe_steps=0),
         dict(id="vertical_after_16", candidate_index=3, activation_step=16, baseline_probe_steps=16)]

class SupportVerticalController(Controller):
    def __init__(self, core, compiled, contract, cell):
        require(type(cell) is int and 0 <= cell < len(ROLES), "Support-vertical role index")
        self.role = copy.deepcopy(ROLES[cell])
        self.probe_steps = self.role["baseline_probe_steps"]
        self.model = feedback.definition()
        feedback.validate_geometry(compiled, self.model)
        require(set(contract["provider"]) == {"kind", "candidates", "envelope_selection", "ground_domain"}
            and contract["provider"]["kind"] == "untrained_support_vertical_feedback_v1"
            and contract["provider"]["candidates"] == self.model["candidates"]
            and contract["provider"]["ground_domain"] == self.model["ground_domain"]
            and contract["provider"]["envelope_selection"] == self.model["envelope_selection"],
            "Support-vertical host family/envelope ownership")
        candidate = self.model["candidates"][self.role["candidate_index"]]
        bound = dict(contract, provider=dict(contract["provider"], **{k: candidate[k] for k in
            ["maximum_absolute_correction_rad_s", "maximum_slew_per_step_rad_s"]}))
        super().__init__(core, compiled, bound, self.role["candidate_index"])
        self.provider_memory["provider_id"] = "support_vertical_comparison"
        self.model_digest = core.canonicalize_json(dict(definition=self.model, candidate=self.candidate,
            activation_role=self.role, feature_schema="locolemotion_early_joint_response_v1"))["sha256"]
        self.index, self.next_step, self.closed = cell, 0, False
        self.history = history.empty()

    def close(self):
        if not self.closed:
            super().close()
            self.closed = True

    def response(self, request):
        try:
            delta, detail = feedback.feedback(request["state"], request["command"], self.candidate,
                self.model, request["deterministic_baseline"])
        except (ValueError, KeyError, TypeError) as exc:
            return None, dict(status="refused", reason=str(exc))
        response = proposal(self.core, request, self.candidate)
        commands = request["deterministic_baseline"]["ordered_commands"]
        response["ordered_corrections"] = [dict(actuator_id=row["actuator_id"],
            canonical_velocity_delta_rad_s=k*row["combined_canonical_target_velocity_rad_s"]+d)
            for row, k, d in zip(commands, self.candidate["ordered_coefficients"], delta, strict=True)]
        response["diagnostics"] = ["untrained_support_vertical_feedback; confidence denotes observation support only"]
        return response, detail

    def step(self, state, stability, kinematics):
        require(not self.closed and type(state["semantic_step"]) is int
                and state["semantic_step"] == self.next_step, "Support-vertical controller lifecycle/clock")
        try:
            step = self.next_step
            command = bridge._motion_command(step, self.c["phase_mode"])
            request = dict(memory=self.memory, state=state, command=command)
            limbs = bridge._ordered_limb_steps(self.memory, self.context.morphology["ordered_limb_ids"])
            output = self.session.step(request)
            actuation = output["actuation"]
            require(actuation["receipt"]["controller_error"] is None and not actuation["failure_codes"],
                    "Support-vertical portable controller refusal")
            composition = bridge.compose_bw19v_step(self.context, actuation, stability, kinematics, limbs, self.composition_memory)
            provider = proposal_request(self.core, self.c, self.candidate, state, command, output,
                composition["canonical_actuation"], self.provider_memory, self.previous)
            provider.update(provider_id="support_vertical_comparison", expected_provider_version="support_vertical_v1",
                            expected_model_sha256=self.model_digest)
            provider = history.attach(provider, self.history if step <= self.probe_steps else history.empty())
            features = context_features(provider) if self.probe_steps and step == self.probe_steps else None
            if step < self.probe_steps or self.candidate["mode"] == "baseline":
                response, detail = no_proposal(self.core, provider), dict(status="baseline")
            else:
                response, detail = self.response(provider)
            resolution_request = dict(schema_version="sporespore_adaptation_resolution_request_v1",
                                      provider_request=provider, provider_response=response)
            resolved = self.core.resolve_adaptation_v1(resolution_request)
            require(resolved["fallback_reason"] in ("none", "provider_no_proposal", "provider_absent", "safe_no_actuation"),
                    "Support-vertical unexpected resolver refusal")
            targets = map_resolution(composition["host_mapping"], resolved)
            if step < self.probe_steps:
                following, boundary = history.append_resolved(self.core, provider, resolved)
                require(boundary is None and len(following["ordered_entries"]) == step+1,
                        "Support-vertical history must retain truthful resolved prefix")
            else:
                following = history.empty()
            self.memory, self.provider_memory = output["next_memory"], resolved["next_memory"]
            self.previous = [row["applied_correction_rad_s"] for row in resolved["ordered_commands"]]
            self.history, self.next_step = following, step+1
            return dict(request=request, output=output, stability=stability, kinematics=kinematics,
                composition=composition, resolution_request=resolution_request, resolution=resolved,
                native_targets=targets, feedback=detail,
                activation_probe=dict(role_id=self.role["id"], candidate_index=self.role["candidate_index"],
                    activation_step=self.role["activation_step"], baseline_probe_steps=self.probe_steps,
                    phase="baseline_observation" if step < self.probe_steps else "fixed_controller",
                    history_entries=len(provider["history"]["ordered_entries"]), features=features,
                    learned_selection=False))
        except BaseException:
            self.close()
            raise
