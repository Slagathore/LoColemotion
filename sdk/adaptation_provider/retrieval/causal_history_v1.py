"""Bounded host-owned canonical observation/action history for provider v1.

Entries describe past observations and resolved commands, never future outcomes.
The original resolution receipt remains the authority for final speed projection
and fallback. Missing or unrepresentable provider status breaks the window; it
is never relabeled as a successful proposal to fit the v1 history schema.
"""
import copy

from . import flat_v2 as base

SCHEMA = "sporespore_adaptation_history_v1"
CAPACITY = 64
STATUSES = {"applied", "no_proposal", "refused", "unsupported", "uncertain", "reset"}


def empty():
    return dict(schema_version=SCHEMA, ordered_entries=[])


def attach(request, history):
    base.require(set(history) == {"schema_version", "ordered_entries"} and history["schema_version"] == SCHEMA
        and type(history["ordered_entries"]) is list and len(history["ordered_entries"]) <= CAPACITY,
        "History shape/capacity")
    entries = history["ordered_entries"]
    step = request["state"]["semantic_step"]
    base.require(type(step) is int and step >= 0, "History current clock")
    if entries:
        steps = [e["semantic_step"] for e in entries]
        base.require(all(type(s) is int and s >= 0 for s in steps)
            and steps == list(range(step-len(entries), step)), "History must be the contiguous past")
    value = copy.deepcopy(request)
    value["history"] = copy.deepcopy(history)
    return value


def append_resolved(core, request, receipt):
    """Call after successful resolution/mapping; commit the whole host batch atomically."""
    # Recheck chronology even if a caller did not use attach(). The core checks
    # complete entry schemas and observations when it resolves the next request.
    attach(request, request["history"])
    base.require(receipt["schema_version"] == "sporespore_adaptation_resolution_receipt_v1"
        and receipt["request_id"] == request["request_id"]
        and receipt["request_sha256"] == base.digest(core, request)
        and receipt["world_build_count"] == 0 and receipt["physics_state_modified"] is False
        and receipt["physical_acceptance_authority"] is False, "History resolution binding/authority")
    commands = receipt["ordered_commands"]
    baseline = request["deterministic_baseline"]["ordered_commands"]
    base.require([r["actuator_id"] for r in commands] == [r["actuator_id"] for r in baseline], "History actuator order")
    for command, original in zip(commands, baseline, strict=True):
        correction = command["applied_correction_rad_s"]
        speed = original["maximum_target_speed_rad_s"]
        baseline_speed = original["combined_canonical_target_velocity_rad_s"]
        base.require(base.finite(correction) and command["baseline_canonical_target_velocity_rad_s"] == baseline_speed
            and command["maximum_target_speed_rad_s"] == speed
            and command["final_canonical_target_velocity_rad_s"] == max(-speed, min(speed, baseline_speed+correction))
            and (receipt["adaptation_applied"] or correction == 0.), "History resolved action projection")
    status = receipt["provider_status"]
    if status not in STATUSES or receipt["adaptation_applied"] != (status == "applied"):
        return empty(), "v1_unrepresentable_provider_status"
    step = request["state"]["semantic_step"]
    entry = dict(semantic_step=step, state=copy.deepcopy(request["state"]), command=copy.deepcopy(request["command"]),
        deterministic_baseline=copy.deepcopy(request["deterministic_baseline"]),
        ordered_applied_corrections=[dict(actuator_id=r["actuator_id"],
            canonical_velocity_delta_rad_s=r["applied_correction_rad_s"]) for r in commands],
        request_sha256=receipt["request_sha256"], resolution_receipt_sha256=base.digest(core, receipt),
        provider_status=status, adaptation_applied=receipt["adaptation_applied"])
    entries = copy.deepcopy(request["history"]["ordered_entries"])
    entries.append(entry)
    return dict(schema_version=SCHEMA, ordered_entries=entries[-CAPACITY:]), None


def final_velocities(entry):
    """Decode the issued command, including the final actuator speed projection."""
    baseline = entry["deterministic_baseline"]["ordered_commands"]
    corrections = entry["ordered_applied_corrections"]
    base.require([r["actuator_id"] for r in baseline] == [r["actuator_id"] for r in corrections], "History decode order")
    if not entry["adaptation_applied"]:
        base.require(all(c["canonical_velocity_delta_rad_s"] == 0. for c in corrections), "History fallback correction")
        return [b["combined_canonical_target_velocity_rad_s"] for b in baseline]
    return [max(-b["maximum_target_speed_rad_s"], min(b["maximum_target_speed_rad_s"],
        b["combined_canonical_target_velocity_rad_s"]+c["canonical_velocity_delta_rad_s"]))
        for b, c in zip(baseline, corrections, strict=True)]
