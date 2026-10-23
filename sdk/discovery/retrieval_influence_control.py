"""Closed-loop fitted retrieval with private memory and explicit clamp history.

The complete production baseline is recomputed from each world's current
observation. Its absent-provider resolution is retained as a same-input
reference; it is never substituted for a fresh physical comparison world.
"""
import copy

from portable_batch_control import BatchController
from portable_search_control import map_resolution
from retrieval_shadow_control import learner, load_candidate, candidate_path

MODES = ("baseline", "disabled", "frozen", "shuffled", "episodic", "episodic_shuffled")


def influence_round(core, rows, model, modes, memories, previous):
    following, history = [], []
    for cell, (row, mode) in enumerate(zip(rows, modes, strict=True)):
        for key in ["resolution_request", "resolution", "native_targets"]:
            row["baseline_" + key] = copy.deepcopy(row[key])
        row.update(mode=mode, provider_error=None, operation=None,
            commands_applied_to_physics=True,
            outcome_credit="actual_applied_action_sequence")
        if mode != "baseline":
            request = learner.bind_request(core, row["resolution_request"]["provider_request"], model, mode)
            request["provider_memory"] = copy.deepcopy(memories[cell])
            request["request_id"] = "retrieval_influence_" + mode + "_step_" + str(request["state"]["semantic_step"])
            # The v1 envelope carries the resolver's bounded correction before
            # final speed projection. Do not reset this history each call.
            for limit, value in zip(request["safety_envelope"]["ordered_actuator_limits"], previous[cell], strict=True):
                limit["previous_applied_correction_rad_s"] = value
            call = learner.call_provider(core, request, model, mode)
            resolved_request = dict(schema_version="sporespore_adaptation_resolution_request_v1",
                provider_request=request, provider_response=call["provider_response"])
            resolved = core.resolve_adaptation_v1(resolved_request)
            targets = map_resolution(row["composition"]["host_mapping"], resolved)
            row.update(resolution_request=resolved_request, resolution=resolved,
                native_targets=targets, provider_error=call["provider_error"])
        following.append(copy.deepcopy(row["resolution"]["next_memory"]))
        history.append([r["applied_correction_rad_s"] for r in row["resolution"]["ordered_commands"]])
    return rows, following, history


class InfluenceController:
    def __init__(self, core, compiled, c, model, modes):
        learner.require(len(modes) == len(MODES) and set(modes) == set(MODES), "Influence mode population")
        self.core, self.model, self.modes = core, model, list(modes)
        self.baseline = BatchController(core, compiled, c, [0] * len(modes))
        self.memories = [learner.empty_memory(core, plan=model.plan()) for _ in modes]
        self.previous = [[0.] * 8 for _ in modes]
        self.closed = False

    def close(self):
        if not self.closed:
            self.baseline.close()
            self.closed = True

    def step(self, observations):
        learner.require(not self.closed and len(observations) == len(self.modes), "Influence lifecycle/population")
        try:
            rows = self.baseline.step(observations)
            rows, following, history = influence_round(self.core, rows, self.model,
                self.modes, self.memories, self.previous)
            self.memories, self.previous = following, history
            return rows
        except BaseException:
            # Baseline sessions have advanced: never resume a partially
            # resolved host transaction, including a failed native mapping.
            self.close()
            raise
