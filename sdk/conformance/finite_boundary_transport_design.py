#!/usr/bin/env python3
"""Reusable zero-world audit for the contiguous boundary-transport design."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path
import subprocess
import sys
from typing import Any

from sdk.conformance.content_addressed_zero_world_closure import (
    ClosureAuditError,
    canonical_bytes,
    exact,
    verify_exact_paths,
)
from sdk.conformance.contiguous_boundary_transport_design import (
    BoundaryTransportDesignError,
    qualify_contiguous_boundary_transport_design_v1,
)
from sdk.conformance.finite_recovery_load_path_diagnosis import (
    validate_bound_zero_world_engineering_diagnosis,
)


def validate_contiguous_boundary_transport_design(
    root: Path,
    relative_path: str,
    schema: str,
    expected_sha256: str,
    expected_length: int,
    **scope: Any,
) -> dict[str, Any]:
    """Verify R167's authority bindings and executable reference state machine."""

    design = validate_bound_zero_world_engineering_diagnosis(
        root,
        relative_path,
        schema,
        expected_sha256,
        expected_length,
        **scope,
    )
    receipt = qualify_contiguous_boundary_transport_design_v1()
    encoded = canonical_bytes(receipt)
    exact(
        (len(encoded), "sha256:" + hashlib.sha256(encoded).hexdigest()),
        (
            int(design["qualification_receipt_canonical_byte_length"]),
            str(design["qualification_receipt_canonical_sha256"]),
        ),
        "BOUNDARY_TRANSPORT_RECEIPT_IDENTITY",
    )
    exact(receipt, design["qualification_receipt"], "BOUNDARY_TRANSPORT_RECEIPT")
    exact(
        design["refusal_contract"]["mutation_control_ids"],
        receipt["mutation_control_ids"],
        "BOUNDARY_TRANSPORT_MUTATION_IDS",
    )
    verify_exact_paths(
        design,
        {
            "transport_design.sequence_origin": 0,
            "transport_design.outcome_derived_input_permitted": False,
            "initializer_contract.physics_must_be_inactive": True,
            "initializer_contract.boundary_sequence_must_equal": 0,
            "advance_contract.cache_advance_count_per_success": 1,
            "advance_contract.cache_advance_before_complete_validation_permitted": False,
            "advance_contract.replay_after_success_permitted": False,
            "refusal_contract.mutation_control_count": 17,
            "refusal_contract.all_refusals_return_no_pair": True,
            "refusal_contract.all_refusals_preserve_prior_state": True,
            "method.positive_case_count": 6,
            "method.mutation_control_count": 17,
            "method.rejection_state_unchanged_count": 17,
            "interpretation.contiguous_boundary_transport_design_qualified": True,
            "interpretation.live_boundary_transport_implemented": False,
            "interpretation.live_boundary_transport_qualified": False,
            "decision.r24d168_zero_world_boundary_transport_implementation_required": True,
            "decision.live_boundary_transport_implementation_completed": False,
            "decision.controller_change_selected": False,
            "decision.threshold_change_selected": False,
            "decision.physical_execution_authorized": False,
            "claim_boundary.r167_contiguous_boundary_transport_design_qualified": True,
            "claim_boundary.r167_live_boundary_transport_implemented": False,
            "claim_boundary.current_exact_balance_safety_authority_available_for_prospective_reliance": False,
            "claim_boundary.energy_balance_physically_corrected": False,
        },
        "BOUNDARY_TRANSPORT_EXTENSION",
    )
    return design


def run_contiguous_boundary_transport_design_cli(
    root: Path,
    relative_path: str,
    schema: str,
    expected_sha256: str,
    expected_length: int,
    pass_marker: str,
    failure_marker: str,
    **scope: Any,
) -> int:
    """Run one thin R167 binding over the reusable design audit."""

    try:
        design = validate_contiguous_boundary_transport_design(
            root,
            relative_path,
            schema,
            expected_sha256,
            expected_length,
            **scope,
        )
        receipt = design["qualification_receipt"]
        print(
            pass_marker,
            json.dumps(
                {
                    "gate_id": design["gate_id"],
                    "ok": True,
                    "status": design["status"],
                    "initializer_boundary_sequence": receipt[
                        "initializer_boundary_sequence"
                    ],
                    "terminal_cached_boundary_sequence": receipt[
                        "terminal_cached_boundary_sequence"
                    ],
                    "mutation_control_count": receipt["mutation_control_count"],
                    "rejection_state_unchanged_count": receipt[
                        "rejection_state_unchanged_count"
                    ],
                    "live_boundary_transport_implemented": False,
                    "model_construction_count": 0,
                    "native_readback_count": 0,
                    "world_build_count": 0,
                    "solver_step_count": 0,
                    "prone_to_standing_claimed": False,
                    "sdk1_milestone_advanced": False,
                },
                sort_keys=True,
            ),
        )
        return 0
    except (
        BoundaryTransportDesignError,
        ClosureAuditError,
        KeyError,
        OSError,
        subprocess.CalledProcessError,
        TypeError,
        ValueError,
    ) as error:
        print(f"{failure_marker}:{error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit("use a campaign-specific thin binding")
