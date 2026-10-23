"""Scalar portable host for the finite body-gain factorial."""
from portable_search_control import Controller, bridge, map_resolution, proposal, proposal_request
from adaptation_provider import body_gain_feedback_v1 as feedback


class BodyGainFeedbackController(Controller):
    def __init__(self, core, compiled, contract, cell):
        self.model = feedback.definition()
        feedback.validate_geometry(compiled, self.model)
        feedback.require(set(contract["provider"]) == {"kind", "candidates", "envelope_selection"}
            and contract["provider"]["kind"] == "untrained_body_gain_feedback_v1"
            and contract["provider"]["candidates"] == self.model["candidates"]
            and contract["provider"]["envelope_selection"] == self.model["envelope_selection"], "Body-gain host family/envelope ownership")
        candidate = self.model["candidates"][cell]
        bound = dict(contract, provider=dict(contract["provider"], **{k: candidate[k] for k in
            ["maximum_absolute_correction_rad_s", "maximum_slew_per_step_rad_s"]}))
        super().__init__(core, compiled, bound, cell)
        self.provider_memory["provider_id"] = "body_gain_feedback_search"
        self.model_digest = core.canonicalize_json(dict(definition=self.model, candidate=self.candidate))["sha256"]

    def response(self, request):
        candidate = self.candidate
        if candidate["mode"] == "baseline":
            return None, dict(status="baseline")
        detail = dict(status="fixed_profile")
        delta = [0.] * 8
        if candidate["mode"] == "feedback":
            try:
                delta, detail = feedback.feedback(request["state"], request["command"], candidate, self.model)
            except (ValueError, KeyError, TypeError) as exc:
                # Unsupported observations withdraw the entire provider. The
                # resolver returns the original baseline without stale offsets.
                return None, dict(status="refused", reason=str(exc))
        response = proposal(self.core, request, candidate)
        commands = request["deterministic_baseline"]["ordered_commands"]
        response["ordered_corrections"] = [dict(actuator_id=row["actuator_id"],
            canonical_velocity_delta_rad_s=k*row["combined_canonical_target_velocity_rad_s"]+d)
            for row, k, d in zip(commands, candidate["ordered_coefficients"], delta, strict=True)]
        response["diagnostics"] = ["untrained_body_gain_feedback; confidence denotes declared observation support only"]
        return response, detail

    def step(self, state, stability, kinematics):
        command = bridge._motion_command(state["semantic_step"], self.c["phase_mode"])
        request = dict(memory=self.memory, state=state, command=command)
        limb_steps = bridge._ordered_limb_steps(self.memory, self.context.morphology["ordered_limb_ids"])
        output = self.session.step(request); actuation = output["actuation"]
        if actuation["receipt"]["controller_error"] is not None or actuation["failure_codes"]:
            raise ValueError("Portable controller refused: "+str(actuation["failure_codes"]))
        composition = bridge.compose_bw19v_step(self.context, actuation, stability, kinematics, limb_steps, self.composition_memory)
        provider = proposal_request(self.core, self.c, self.candidate, state, command, output,
            composition["canonical_actuation"], self.provider_memory, self.previous)
        provider.update(provider_id="body_gain_feedback_search", expected_provider_version="body_gain_feedback_v1",
            expected_model_sha256=self.model_digest)
        response, detail = self.response(provider)
        resolution_request = dict(schema_version="sporespore_adaptation_resolution_request_v1",
            provider_request=provider, provider_response=response)
        resolution = self.core.resolve_adaptation_v1(resolution_request)
        if resolution["fallback_reason"] not in ("none", "provider_absent", "safe_no_actuation"):
            raise ValueError("Unexpected provider refusal: "+resolution["fallback_reason"])
        targets = map_resolution(composition["host_mapping"], resolution)
        self.memory = output["next_memory"]; self.provider_memory = resolution["next_memory"]
        self.previous = [row["applied_correction_rad_s"] for row in resolution["ordered_commands"]]
        return dict(request=request, output=output, stability=stability, kinematics=kinematics,
            composition=composition, resolution_request=resolution_request, resolution=resolution,
            native_targets=targets, feedback=detail)
