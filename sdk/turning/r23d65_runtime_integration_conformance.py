#!/usr/bin/env python3
"""Production-shaped zero-world conformance for the R23D65 runtime repairs.

This module exercises the exact Rapier trace-retention call chain that failed
in R23D64: the R23D65 evaluator delegates to the accepted retainer, which
launches child PowerShell, invokes the production publisher, and stores the
canonical NDJSON payload in the content-addressed artifact store.  The input
is a synthetic evaluator canary, so no native model or physics world is built.
"""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import shutil
import sys
import tempfile
from typing import Any, Sequence


ROOT = Path(__file__).resolve().parent
SDK_ROOT = ROOT.parent
REPO_ROOT = SDK_ROOT.parent
TARGET_ROOT = SDK_ROOT / "target"

if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

import r23d34_native_r23d29_transfer_evaluator as inherited_retainer  # noqa: E402
import r23d65_selected_profile_three_engine_turning_validation as design  # noqa: E402
import r23d65_selected_profile_three_engine_turning_validation_evaluator as evaluator  # noqa: E402


class R23D65RuntimeIntegrationError(RuntimeError):
    """An exact production-shaped runtime seam did not conform."""


def _require(condition: bool, code: str) -> None:
    if not condition:
        raise R23D65RuntimeIntegrationError(code)


def _powershell_path(explicit: str | None) -> str:
    candidate = explicit or shutil.which("pwsh") or shutil.which("powershell")
    _require(isinstance(candidate, str) and bool(candidate), "R23D65_POWERSHELL_MISSING")
    path = Path(candidate).resolve()
    _require(path.is_file(), "R23D65_POWERSHELL_INVALID")
    return str(path)


def _production_child_invocation_contract_exact() -> None:
    source = Path(inherited_retainer.__file__).read_text(encoding="utf-8")
    exact_vector = """        "-NoLogo",
        "-NoProfile",
        "-ExecutionPolicy",
        "Bypass",
        "-File",
        str(PUBLISHER_PATH),"""
    _require(
        exact_vector in source,
        "R23D65_RAPIER_CAS_CHILD_EXECUTION_POLICY_VECTOR_INVALID",
    )


def run_rapier_worker_evaluator_powershell_cas_chain(
    *,
    powershell: str | None = None,
) -> dict[str, Any]:
    design.validate_declaration(
        json.loads(
            (
                ROOT
                / "r23d65_selected_profile_three_engine_turning_validation_"
                "preregistration_v1.json"
            ).read_text(encoding="utf-8")
        )
    )
    _production_child_invocation_contract_exact()
    item = design.cell("rapier_parry", "reference_zero")
    rows = evaluator._synthetic_rows(item)
    _require(
        len(rows) == design.CONTROLLER_STEPS,
        "R23D65_RAPIER_CAS_CANARY_ROW_COUNT_INVALID",
    )
    TARGET_ROOT.mkdir(parents=True, exist_ok=True)
    temporary_path: Path | None = None
    with tempfile.TemporaryDirectory(
        prefix="r23d65-runtime-integration-",
        dir=TARGET_ROOT,
    ) as directory:
        temporary_path = Path(directory).resolve()
        _require(
            temporary_path.parent == TARGET_ROOT.resolve(),
            "R23D65_RAPIER_CAS_CANARY_ROOT_INVALID",
        )
        evidence_root = temporary_path / "evidence"
        attempt_root = evidence_root / "attempt"
        rows_path = temporary_path / "rapier-reference-zero-rows.json"
        rows_path.write_text(
            json.dumps(
                rows,
                allow_nan=False,
                ensure_ascii=False,
                separators=(",", ":"),
            ),
            encoding="utf-8",
            newline="\n",
        )
        receipt = evaluator.retain_trace(
            stage_id=design.STAGE_ID,
            cell_id=item.cell_id,
            rows_json_path=rows_path,
            repo_root=REPO_ROOT,
            attempt_root=attempt_root,
            powershell=_powershell_path(powershell),
            test_only=True,
            evidence_root_override=evidence_root,
        )
        artifact = receipt.get("trace_artifact")
        summary = receipt.get("trace_summary")
        _require(isinstance(artifact, dict), "R23D65_RAPIER_CAS_ARTIFACT_MISSING")
        _require(isinstance(summary, dict), "R23D65_RAPIER_CAS_SUMMARY_MISSING")
        payload_path = Path(str(artifact.get("payload_path", ""))).resolve()
        manifest_path = Path(str(artifact.get("manifest_path", ""))).resolve()
        digest = str(artifact.get("sha256", ""))
        digest_hex = digest.removeprefix("sha256:")
        expected_artifact_root = (
            evidence_root / "artifacts" / "sha256" / digest_hex
        ).resolve()
        payload = payload_path.read_bytes()
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
        _require(
            receipt.get("schema_version")
            == evaluator.TRACE_RETENTION_SCHEMA
            and receipt.get("stage_id") == design.STAGE_ID
            and receipt.get("cell_id") == item.cell_id
            and receipt.get("engine_id") == "rapier_parry"
            and receipt.get("campaign_seed") == design.CAMPAIGN_SEED
            and receipt.get("profile_id") == design.PROFILE_ID
            and receipt.get("host_mapping_id") == item.host_mapping_id
            and receipt.get("retained_before_terminal_entry") is True
            and receipt.get("world_attempt_count") == 0
            and receipt.get("world_build_count") == 0
            and receipt.get("physical_acceptance_authority") is False
            and artifact.get("schema_version") == evaluator.ARTIFACT_SCHEMA
            and artifact.get("test_only") is True
            and payload_path.parent == expected_artifact_root
            and manifest_path.parent == expected_artifact_root
            and len(digest_hex) == 64
            and "sha256:" + hashlib.sha256(payload).hexdigest() == digest
            and len(payload) == artifact.get("byte_length")
            and summary.get("ok") is True
            and summary.get("row_count") == design.CONTROLLER_STEPS
            and summary.get("raw_sha256") == digest
            and summary.get("byte_length") == len(payload)
            and manifest.get("sha256") == digest
            and manifest.get("byte_length") == len(payload)
            and manifest.get("media_type") == "application/x-ndjson",
            "R23D65_RAPIER_CAS_CHAIN_RECEIPT_INVALID",
        )
        result = {
            "schema_version": (
                "sporespore_qsdk_r23d65_rapier_worker_evaluator_"
                "powershell_cas_conformance_v1"
            ),
            "campaign_id": design.CAMPAIGN_ID,
            "gate_id": design.GATE_ID,
            "question_class": "equivalence_non_inferiority",
            "population": "exact_r23d65_rapier_worker_evaluator_child_powershell_publisher_cas_chain",
            "declared_chain_count": 1,
            "conforming_chain_count": 1,
            "equivalence_margin": 0,
            "non_inferiority_margin": 0,
            "sampling_used": False,
            "execution_policy_bypass_in_exact_child_vector": True,
            "production_retainer_invoked": True,
            "production_publisher_invoked": True,
            "content_addressed_store_invoked": True,
            "canonical_trace_row_count": design.CONTROLLER_STEPS,
            "canonical_trace_sha256": digest,
            "canonical_trace_byte_length": len(payload),
            "test_only_artifact": True,
            "test_scratch_removed_after_receipt": True,
            "model_construction_count": 0,
            "world_attempt_count": 0,
            "world_build_count": 0,
            "physical_equivalence_claimed": False,
            "physical_acceptance_authority": False,
        }
    assert temporary_path is not None
    _require(
        not temporary_path.exists(),
        "R23D65_RAPIER_CAS_CANARY_SCRATCH_NOT_REMOVED",
    )
    return result


def _arguments(argv: Sequence[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--powershell")
    return parser.parse_args(argv)


def main(argv: Sequence[str] | None = None) -> int:
    arguments = _arguments(sys.argv[1:] if argv is None else argv)
    try:
        result = run_rapier_worker_evaluator_powershell_cas_chain(
            powershell=arguments.powershell,
        )
    except (OSError, ValueError, R23D65RuntimeIntegrationError) as error:
        print(
            "QSDK_R23D65_RAPIER_CAS_INTEGRATION_FAIL "
            + json.dumps(
                {
                    "error_type": type(error).__name__,
                    "error": str(error),
                    "model_construction_count": 0,
                    "world_attempt_count": 0,
                    "world_build_count": 0,
                    "physical_acceptance_authority": False,
                },
                sort_keys=True,
            )
        )
        return 1
    print(
        "QSDK_R23D65_RAPIER_CAS_INTEGRATION_PASS "
        + json.dumps(result, sort_keys=True)
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
