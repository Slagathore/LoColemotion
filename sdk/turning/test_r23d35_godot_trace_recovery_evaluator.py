"""Zero-world regression tests for the prospective R23D35 evaluator."""

from __future__ import annotations

import copy
import hashlib
import json
from pathlib import Path
import sys
import tempfile
import unittest


ROOT = Path(__file__).resolve().parent
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

import r23d31_cycle_integrated_measurement as measurement  # noqa: E402
import r23d35_godot_trace_recovery as design  # noqa: E402
import r23d35_godot_trace_recovery_evaluator as evaluator  # noqa: E402


class R23D35EvaluatorTests(unittest.TestCase):
    def test_declaration_and_exact_order(self) -> None:
        declaration = evaluator.load_declaration()
        self.assertEqual(declaration["campaign_id"], design.CAMPAIGN_ID)
        self.assertTrue(declaration["immutable_lineage"]["r23d34_identity_consumed"])
        self.assertTrue(
            declaration["implementation_repair_boundary"][
                "same_unresolved_godot_estimand_retained_because_r23d34_exposed_no_godot_locomotion_outcome"
            ]
        )
        self.assertEqual(len(design.cells()), 3)
        self.assertEqual(
            [item.engine_id for item in design.cells()],
            ["godot_jolt"] * 3,
        )

    def test_inherited_trace_vocabulary_is_validated_exactly(self) -> None:
        item = design.cells()[0]
        rows = [
            evaluator._synthetic_row(item, step)
            for step in range(design.CONTROLLER_STEPS)
        ]
        result = evaluator.validate_trace(item.cell_id, rows)
        self.assertTrue(result["ok"])
        self.assertEqual(result["segment_counts"], design.expected_segment_counts(item))
        self.assertEqual(rows[2400]["segment_id"], "after_declared_schedule")
        mutated = copy.deepcopy(rows)
        mutated[2400]["segment_id"] = "reference_continuation"
        self.assertFalse(evaluator.validate_trace(item.cell_id, mutated)["ok"])

    def test_measurement_boundary_translates_only_the_post_schedule_name(self) -> None:
        rows_by_arm = {}
        for arm_id in design.ARM_OFFSETS:
            item = design.cell(design.STAGE_ID, "godot_jolt", arm_id)
            rows = [
                evaluator._synthetic_row(item, step)
                for step in range(design.CONTROLLER_STEPS)
            ]
            translated = evaluator._measurement_rows(rows)
            self.assertEqual(translated[2399]["phase_id"], "reference_recovery")
            self.assertEqual(translated[2400]["phase_id"], "reference_continuation")
            rows_by_arm[arm_id] = translated
        self.assertTrue(measurement.measure_cycle_integrated_response(rows_by_arm)["passed"])

    def test_complete_zero_world_preflight(self) -> None:
        receipt = evaluator.run_zero_world_preflight()
        self.assertEqual(receipt["declared_cell_count"], 3)
        self.assertEqual(receipt["trace_mutation_rejection_count"], 1)
        self.assertEqual(receipt["model_construction_count"], 0)
        self.assertEqual(receipt["world_build_count"], 0)

    def test_incomplete_world_requires_retained_trace_diagnostic(self) -> None:
        item = design.cells()[0]
        entry = {
            "schema_version": evaluator.FAILURE_SCHEMA,
            "campaign_id": design.CAMPAIGN_ID,
            "gate_id": design.GATE_ID,
            "stage_id": item.stage_id,
            "cell_id": item.cell_id,
            "engine_id": item.engine_id,
            "arm_id": item.arm_id,
            "source_commit": "0" * 40,
            "failure_code": "QSDK_R23D35_GJT_TRACE_INCOMPLETE",
            "world_attempt_count": 1,
            "world_build_count": 1,
        }
        result, rows = evaluator.evaluate_entry(
            entry,
            item,
            expected_source_commit="0" * 40,
        )
        self.assertEqual(rows, [])
        self.assertIn(
            "R23D35_INCOMPLETE_TRACE_DIAGNOSTIC_MISSING",
            result["failed_gate_ids"],
        )

    def test_incomplete_trace_diagnostic_reconstructs_retained_partial_rows(self) -> None:
        item = design.cells()[0]
        with tempfile.TemporaryDirectory() as temporary:
            payload = Path(temporary) / "diagnostic.json"
            retained = {
                "schema_version": "sporespore_qsdk_r23d35_trace_diagnostic_v1",
                "campaign_id": design.CAMPAIGN_ID,
                "gate_id": design.GATE_ID,
                "stage_id": item.stage_id,
                "cell_id": item.cell_id,
                "arm_id": item.arm_id,
                "trace_container_schema": "sporespore_sdk_physical_trace_v1",
                "rows_variant_type": "array",
                "failure_codes_variant_type": "array",
                "declared_row_count": design.CONTROLLER_STEPS,
                "reported_row_count": 1,
                "actual_row_count": 1,
                "contiguous_row_count": 1,
                "first_valid_semantic_step": 0,
                "last_valid_semantic_step": 0,
                "first_missing_semantic_step": 1,
                "failure_codes": ["SDK_PHYSICAL_TRACE_CANARY"],
                "complete": False,
                "rows": [{"semantic_step": 0}],
                "partial_rows_retained": True,
                "retained_before_terminal_entry": True,
                "physical_acceptance_authority": False,
            }
            raw = (json.dumps(retained, separators=(",", ":")) + "\n").encode()
            payload.write_bytes(raw)
            summary = dict(retained)
            summary.pop("rows")
            entry = {
                "trace_diagnostic": summary,
                "trace_diagnostic_artifact": {
                    "schema_version": evaluator.ARTIFACT_SCHEMA,
                    "payload_path": str(payload),
                    "sha256": "sha256:" + hashlib.sha256(raw).hexdigest(),
                    "byte_length": len(raw),
                    "test_only": False,
                },
            }
            self.assertEqual(
                evaluator._incomplete_trace_diagnostic_failures(entry, item),
                [],
            )

    def test_complete_trace_is_published_through_the_r23d35_cas_route(self) -> None:
        item = design.cells()[0]
        rows = [
            evaluator._synthetic_row(item, step)
            for step in range(design.CONTROLLER_STEPS)
        ]
        with tempfile.TemporaryDirectory() as temporary:
            evidence_root = Path(temporary) / "evidence"
            attempt_root = evidence_root / "attempt"
            attempt_root.mkdir(parents=True)
            rows_path = Path(temporary) / "rows.json"
            rows_path.write_text(json.dumps(rows), encoding="utf-8")
            receipt = evaluator.retain_trace(
                stage_id=design.STAGE_ID,
                cell_id=item.cell_id,
                rows_json_path=rows_path,
                repo_root=evaluator.REPO_ROOT,
                attempt_root=attempt_root,
                powershell="pwsh",
                test_only=True,
                evidence_root_override=evidence_root,
            )
        self.assertTrue(receipt["retained_before_terminal_entry"])
        self.assertEqual(receipt["trace_summary"]["row_count"], design.CONTROLLER_STEPS)


if __name__ == "__main__":
    unittest.main()
