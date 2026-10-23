"""Distinct history-bearing development host; no physical launch authority.

The consumed contextual host stays unchanged. This successor attaches each
world's actual bounded past after provider binding (which initializes history).
The frozen/current-memory providers do not yet use history to infer dynamics.
"""
import copy

from portable_batch_control import BatchController
from portable_search_control import map_resolution
from contextual_influence_control import MODES, learner
from adaptation_provider.retrieval import causal_history_v1 as history


def influence_round(core, rows, model, modes, memories, previous, histories):
    following, corrections, windows = [], [], []
    for cell, (row, mode) in enumerate(zip(rows, modes, strict=True)):
        for key in ["resolution_request", "resolution", "native_targets"]:
            row["baseline_"+key] = copy.deepcopy(row[key])
        row.update(mode=mode, provider_error=None, operation=None,
            commands_applied_to_physics=True, outcome_credit="actual_applied_action_sequence")
        if mode != "baseline":
            request = learner.bind_request(core, row["resolution_request"]["provider_request"], model, mode)
            request["provider_memory"] = copy.deepcopy(memories[cell])
            request["request_id"] = "history_influence_"+mode+"_step_"+str(request["state"]["semantic_step"])
            request = history.attach(request, histories[cell])
            for limit, value in zip(request["safety_envelope"]["ordered_actuator_limits"], previous[cell], strict=True):
                limit["previous_applied_correction_rad_s"] = value
            call = learner.call_provider(core, request, model, mode)
            resolution_request = dict(schema_version="sporespore_adaptation_resolution_request_v1",
                provider_request=request, provider_response=call["provider_response"])
            resolved = core.resolve_adaptation_v1(resolution_request)
            targets = map_resolution(row["composition"]["host_mapping"], resolved)
            row.update(resolution_request=resolution_request, resolution=resolved,
                native_targets=targets, provider_error=call["provider_error"])
        request = row["resolution_request"]["provider_request"]
        window, boundary = history.append_resolved(core, request, row["resolution"])
        row.update(history_boundary_reason=boundary, history_retained_entry_count=len(window["ordered_entries"]))
        following.append(copy.deepcopy(row["resolution"]["next_memory"]))
        corrections.append([r["applied_correction_rad_s"] for r in row["resolution"]["ordered_commands"]])
        windows.append(window)
    return rows, following, corrections, windows


class HistoryInfluenceController:
    def __init__(self, core, compiled, c, model, modes):
        learner.require(len(modes) == len(MODES) and set(modes) == set(MODES), "History mode population")
        self.core, self.model, self.modes = core, model, list(modes)
        self.baseline = BatchController(core, compiled, c, [0]*len(modes))
        self.memories = [learner.empty_memory(core) for _ in modes]
        self.previous = [[0.]*8 for _ in modes]
        self.histories = [history.empty() for _ in modes]
        self.closed = False

    def close(self):
        if not self.closed:
            self.baseline.close()
            self.closed = True

    def step(self, observations):
        learner.require(not self.closed and len(observations) == len(self.modes), "History lifecycle/population")
        try:
            rows = self.baseline.step(observations)
            rows, memories, corrections, windows = influence_round(self.core, rows, self.model,
                self.modes, self.memories, self.previous, self.histories)
            self.memories, self.previous, self.histories = memories, corrections, windows
            return rows
        except BaseException:
            # No cell may commit history after a partial host transaction.
            self.close()
            raise
