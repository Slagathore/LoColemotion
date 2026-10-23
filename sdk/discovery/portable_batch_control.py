"""Batched complete BW19V baseline and provider resolution, with explicit memory.

This source-only successor reuses the scalar proposal and adapter mapping. It
does not authorize a physical run or change the consumed portable-search v2.
"""
import copy
from dataclasses import asdict
import json

from portable_search_control import (
    Controller, EMPTY_CORPUS, bridge, map_resolution, proposal, proposal_request,
)


def _key(value):
    return json.dumps(value, sort_keys=True, separators=(",", ":"), allow_nan=False)


def values(receipt, ids):
    """Reject crossed/missing rows and refusals before any caller memory changes."""
    rows = receipt.get("ordered_results", [])
    if (receipt.get("world_build_count") != 0
            or receipt.get("physics_state_modified") is not False
            or receipt.get("physical_acceptance_authority") is not False
            or [r["cell_id"] for r in rows] != ids):
        raise ValueError("Batch receipt identity or denominator")
    for row in rows:
        if row["outcome"].get("ok") is not True:
            raise ValueError(f"Batch cell {row['cell_id']} refused: {row['outcome']}")
    return [row["outcome"]["value"] for row in rows]


def pure_batch(core, operation, requests):
    result = []
    for offset in range(0, len(requests), 256):
        chunk = requests[offset:offset + 256]
        ids = [str(i) for i in range(offset, offset + len(chunk))]
        receipt = core.pure_json_batch_v1(operation, [
            dict(cell_id=cell_id, request=request)
            for cell_id, request in zip(ids, chunk, strict=True)
        ])
        if (receipt.get("schema_version") != "sporespore_pure_json_batch_receipt_v1"
                or receipt.get("operation") != operation):
            raise ValueError("Pure batch schema or operation")
        result.extend(values(receipt, ids))
    return result


class CanonicalCache:
    """Cache only actual core canonical receipts, keyed by exact Python JSON."""

    def __init__(self, core, objects, inherited=None):
        self.receipts = {} if inherited is None else dict(inherited.receipts)
        unique = {_key(obj): obj for obj in objects if _key(obj) not in self.receipts}
        for key, receipt in zip(unique, pure_batch(core, "canonicalize_json", list(unique.values())), strict=True):
            self.receipts[key] = receipt

    def canonicalize_json(self, value):
        return self.receipts[_key(value)]


class BatchController:
    def __init__(self, core, compiled, contract, candidate_cells=None):
        self.core = core
        self.contract = contract
        cells = list(range(len(contract["provider"]["candidates"]))) if candidate_cells is None else list(candidate_cells)
        if not 1 <= len(cells) <= 256:
            raise ValueError("Batch controller count outside 1..256")
        self.controllers = []
        try:
            for cell in cells:
                self.controllers.append(Controller(core, compiled, contract, cell))
            models = [dict(kind=contract["provider"]["kind"], candidate=c.candidate, trained=False)
                      for c in self.controllers]
            self.static = CanonicalCache(core, [EMPTY_CORPUS, *models])
        except BaseException:
            self.close()
            raise

    def close(self):
        for controller in self.controllers:
            controller.close()

    def step(self, observations):
        if len(observations) != len(self.controllers):
            raise ValueError("Batch observation denominator")
        ids = [str(i) for i in range(len(self.controllers))]
        calls = []
        requests = []
        for cell_id, controller, (state, stability, kinematics) in zip(ids, self.controllers, observations, strict=True):
            request = dict(memory=controller.memory, state=state,
                           command=bridge._motion_command(state["semantic_step"], self.contract["phase_mode"]))
            requests.append(request)
            calls.append(dict(cell_id=cell_id, session_handle=controller.session.batch_handle, request=dict(
                **request, stability=stability, kinematics=kinematics,
                composition_memory=asdict(controller.composition_memory),
                host_profile=bridge._mujoco_host_profile(controller.context.profile_id))))
        receipt = self.core.bw19v_composition_batch_v1(calls)
        if receipt.get("schema_version") != "sporespore_bw19v_composition_batch_receipt_v1":
            raise ValueError("Composition batch schema")
        baseline = values(receipt, ids)
        # Only static model/corpus hashes persist. Per-step caches die with this
        # call; neither historical requests nor controller memory accumulate.
        cache = CanonicalCache(self.core, [b["output"]["next_memory"] for b in baseline], self.static)
        providers = [proposal_request(cache, self.contract, c.candidate, request["state"], request["command"],
                    b["output"], b["composition"]["canonical_actuation"], c.provider_memory, c.previous)
                     for c, request, b in zip(self.controllers, requests, baseline, strict=True)]
        cache = CanonicalCache(self.core, providers, cache)
        resolution_requests = [dict(schema_version="sporespore_adaptation_resolution_request_v1",
            provider_request=provider, provider_response=proposal(cache, provider, c.candidate))
            for c, provider in zip(self.controllers, providers, strict=True)]
        resolutions = pure_batch(self.core, "resolve_adaptation_v1", resolution_requests)
        records = []
        for request, observation, b, resolution_request, resolution in zip(requests, observations, baseline, resolution_requests, resolutions, strict=True):
            if resolution["fallback_reason"] not in ("none", "provider_absent", "safe_no_actuation"):
                raise ValueError("Unexpected provider refusal: " + resolution["fallback_reason"])
            targets = map_resolution(b["composition"]["host_mapping"], resolution)
            records.append(dict(request=copy.deepcopy(request), output=b["output"], stability=observation[1],
                kinematics=observation[2], composition=b["composition"], resolution_request=resolution_request,
                resolution=resolution, native_targets=targets))
        # Commit explicit host memory only after every result and mapping passed.
        for c, b, resolution in zip(self.controllers, baseline, resolutions, strict=True):
            c.memory = b["output"]["next_memory"]
            c.composition_memory = bridge.CompositionMemory(**b["next_composition_memory"])
            c.provider_memory = resolution["next_memory"]
            c.previous = [r["applied_correction_rad_s"] for r in resolution["ordered_commands"]]
        return records
