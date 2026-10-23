"""Observe a baseline trajectory through isolated, non-actuating providers.

Shadow memory is diagnostic only. Its feedback cannot establish the effect of
an action that was never applied, and is never adopted into the frozen model.
"""
import copy
import json
from pathlib import Path
import sys

from gpu_quadruped_model import ROOT, sha
from portable_batch_control import BatchController
sys.path.insert(0, str(ROOT / "sdk"))
from adaptation_provider.retrieval import flat_v2 as learner


def candidate_path(c):
    root = (ROOT.parent / "SporeSpore_Evidence").resolve(strict=True)
    binding = c["model"]
    attempt = (root / binding["attempt_id"]).resolve(strict=True)
    path = (attempt / binding["artifact"]).resolve(strict=True)
    learner.require(attempt.parent == root and path.is_relative_to(attempt), "Candidate evidence path")
    return path


def load_candidate(core, c):
    binding = c["model"]
    closure_path = (ROOT / binding["closure_path"]).resolve(strict=True)
    learner.require(closure_path.is_relative_to(ROOT) and sha(closure_path) == binding["closure_sha256"], "Candidate closure binding")
    closure = json.loads(closure_path.read_text())
    path = candidate_path(c)
    learner.require(closure["attempt_id"] == binding["attempt_id"]
        and closure["fit_receipt_sha256"] == binding["fit_receipt_sha256"]
        and closure["fitted_model_sha256"] == binding["canonical_sha256"]
        and closure["native_fitted_provider_available"] is True
        and closure["native_influence_evaluated"] is False
        and sha(path) == binding["artifact_sha256"]
        and sha(path.parent / "fit-receipt.json") == binding["fit_receipt_sha256"], "Candidate provenance binding")
    model = learner.FrozenModel.load(core, json.loads(path.read_text()))
    learner.require(model.sha256 == binding["canonical_sha256"]
        and model.document()["synthetic"] is False, "Native candidate identity")
    return model


def operation_for(c, mode, step):
    if mode not in c["shadow_operation_modes"]:
        return None
    return next((row["operation"] for row in c["shadow_operations"] if row["outer_step"] == step), None)


def shadow_round(core, baseline_row, model, c, memories):
    """Return records and new private memories; never edit the applied row."""
    modes = c["shadow_modes"]
    learner.require(modes == list(learner.MODES) and set(memories) == set(modes), "Shadow mode population")
    actual = baseline_row["resolution"]
    learner.require(baseline_row["resolution_request"]["provider_response"] is None
        and actual["adaptation_applied"] is False
        and all(row["applied_correction_rad_s"] == 0. for row in actual["ordered_commands"]), "Shadow requires baseline-only actuation")
    rows, following = [], {}
    for mode in modes:
        request = learner.bind_request(core, baseline_row["resolution_request"]["provider_request"], model, mode)
        # bind_request initializes a new host request; subsequent observations
        # must carry the last accepted private shadow memory, never reset it.
        request["provider_memory"] = copy.deepcopy(memories[mode])
        step = request["state"]["semantic_step"]
        request["request_id"] = "retrieval_shadow_" + mode + "_step_" + str(step)
        operation = operation_for(c, mode, step)
        call = learner.call_provider(core, request, model, mode, operation)
        resolution_request = dict(schema_version="sporespore_adaptation_resolution_request_v1",
            provider_request=request, provider_response=call["provider_response"])
        resolution = core.resolve_adaptation_v1(resolution_request)
        rows.append(dict(mode=mode, operation=operation, provider_error=call["provider_error"],
            resolution_request=resolution_request, resolution=resolution,
            commands_applied_to_physics=False, outcome_credit="shadow_only_not_action_effect"))
        following[mode] = resolution["next_memory"]
    return rows, following


class ShadowController:
    """One production baseline world with five independent shadow consumers."""
    def __init__(self, core, compiled, c, model):
        learner.require(c["shadow_modes"] == list(learner.MODES), "Shadow mode order")
        self.core, self.c, self.model = core, c, model
        self.baseline = BatchController(core, compiled, c, [0])
        self.memories = {mode: learner.empty_memory(core, plan=model.plan()) for mode in c["shadow_modes"]}
        self.closed = False

    def close(self):
        if not self.closed:
            self.baseline.close()
            self.closed = True

    def step(self, observations):
        learner.require(not self.closed and len(observations) == 1, "Shadow controller lifecycle/population")
        try:
            rows = self.baseline.step(observations)
            shadow, following = shadow_round(self.core, rows[0], self.model, self.c, self.memories)
            rows[0]["shadow"] = shadow
            self.memories = following
            return rows
        except BaseException:
            # An invalid host transaction cannot silently resume with the
            # baseline session already advanced but shadow memory uncommitted.
            self.close()
            raise
