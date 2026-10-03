"""Independent context integrity and its actual refused-collection consumer.

Expected raw bindings here are explicitly test authority, not official source
qualification. The original Godot marker text is consumed without reconstruction.
"""

import copy
import hashlib
import json
from pathlib import Path
import sys
import unittest

from test_qsdk_r10f_l15_collection_transport import run_zero_world_fixture

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "sdk/conformance"))
import qsdk_r10f_l15_collection_context as context
import qsdk_r10f_l15_collection_retention as packet
import qsdk_r10f_physical_closure as closer

MARKER = "QSDK_R10F_L15_PREPARED_COLLECTION_CONTEXT "


def snapshot(value):
    text = json.dumps(value, sort_keys=True, separators=(",", ":"))
    raw = text.encode("utf-8")
    return {
        "utf8_text": text,
        "utf8_byte_length": len(raw),
        "raw_sha256": "sha256:" + hashlib.sha256(raw).hexdigest(),
    }


class PreparedContextReader(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        emitted = run_zero_world_fixture(
            "res://tests/test_sdk_qsdk_r10f_l15_collection_context_zero_world.gd",
            "QSDK_R10F_L15_COLLECTION_CONTEXT_ZERO_WORLD ",
            additional_markers=(MARKER,),
        )
        texts = emitted["captured_additional_marker_texts"][MARKER]
        assert len(texts) == 1, "ONE_ORIGINAL_CONTEXT_CAPTURE_REQUIRED"
        cls.raw = texts[0]
        cls.capture = packet.parse_json(cls.raw)
        cls.proof = cls.validate_text(cls.raw)

    @staticmethod
    def validate_text(raw, expected=None):
        return context.validate_capture(
            raw,
            expected_raw_binding=(
                context.raw_binding(raw) if expected is None else expected
            ),
            canonical_sha256=closer.canonical_sha256_v1,
        )

    def reject_candidate(self, candidate, message=None):
        raw = json.dumps(candidate, sort_keys=True, separators=(",", ":"))
        with self.assertRaises(ValueError, msg=message):
            self.validate_text(raw)

    def test_original_capture_and_independent_digests_produce_identity_only(self):
        proof = self.proof
        self.assertIs(proof["ok"], True)
        self.assertIs(proof["external_raw_capture_binding_verified"], True)
        self.assertTrue(
            packet.same(proof["raw_capture_binding"], context.raw_binding(self.raw))
        )
        expected = packet.parse_json(self.capture["expected_identity"]["utf8_text"])
        self.assertTrue(packet.same(expected, proof["expected_identity"]))
        for key in (
            "source_origin_authenticated_by_this_reader",
            "complete_v18_native_predicate_reexecuted_by_this_reader",
            "official_context_qualification",
            "physical_worker_context_installed",
            "physical_execution_authorized",
            "physical_acceptance_authority",
            "release_authority",
        ):
            self.assertIs(proof[key], False)
        for key in context.ZERO_COUNTERS:
            self.assertIs(type(proof[key]), int)
            self.assertEqual(0, proof[key])

    def test_missing_crossed_and_wrong_kind_outer_bindings_are_rejected(self):
        expected = context.raw_binding(self.raw)
        for supplied in (
            {},
            True,
            {**expected, "utf8_byte_length": float(expected["utf8_byte_length"])},
            {**expected, "utf8_byte_length": str(expected["utf8_byte_length"])},
            {**expected, "raw_sha256": "sha256:" + "0" * 64},
            {**expected, "extra": True},
        ):
            with self.subTest(binding=supplied), self.assertRaisesRegex(
                ValueError, "ENCLOSING_RAW_BINDING"
            ):
                self.validate_text(self.raw, supplied)
        with self.assertRaisesRegex(ValueError, "ENCLOSING_RAW_BINDING"):
            self.validate_text(self.raw + " ", expected)
        for field in self.capture:
            changed = copy.deepcopy(self.capture)
            del changed[field]
            self.reject_candidate(changed, field)
        for name in context.ZERO_COUNTERS | {
            "collection_request_constructor_call_count"
        }:
            for invalid in (True, 0.0, "0", None, 2):
                changed = copy.deepcopy(self.capture)
                changed[name] = invalid
                self.reject_candidate(changed, name)
        for name in context.FALSE_FLAGS:
            for invalid in (True, 0, None):
                changed = copy.deepcopy(self.capture)
                changed[name] = invalid
                self.reject_candidate(changed, name)

    def test_rehashed_snapshot_changes_cannot_break_identity_or_source_links(self):
        for field in packet.IDENTITY_KEYS:
            changed = copy.deepcopy(self.capture)
            identity = packet.parse_json(changed["expected_identity"]["utf8_text"])
            if type(identity[field]) is dict:
                identity[field]["unexpected"] = True
            else:
                identity[field] = "crossed_identity"
            changed["expected_identity"] = snapshot(identity)
            self.reject_candidate(changed, field)
        for field, replacement in (
            ("ok", 1),
            ("recovery_controller_id", "other_controller"),
            ("model_construction_count", 0.0),
            ("world_attempt_count", False),
            ("solver_step_count", "0"),
            ("physical_acceptance_authority", True),
            ("capability_sha256", "sha256:" + "0" * 64),
            ("runtime_qualification_sha256", "sha256:" + "0" * 64),
        ):
            changed = copy.deepcopy(self.capture)
            source = packet.parse_json(changed["source_context"]["utf8_text"])
            source[field] = replacement
            changed["source_context"] = snapshot(source)
            self.reject_candidate(changed, field)
        for role in ("source_context", "expected_identity"):
            changed = copy.deepcopy(self.capture)
            changed[role]["utf8_text"] += " "
            self.reject_candidate(changed, role)
        with self.assertRaises(ValueError):
            context.validate_capture(
                self.raw,
                expected_raw_binding=context.raw_binding(self.raw),
                canonical_sha256=lambda _value: "sha256:" + "0" * 64,
            )

    def test_duplicate_nonfinite_and_promoted_capture_json_are_refused(self):
        duplicate = '{"ok":true,' + self.raw[1:]
        with self.assertRaisesRegex(ValueError, "JSON_DUPLICATE_KEY"):
            self.validate_text(duplicate)
        for raw in ('{"value":NaN}', '{"value":1e999}'):
            with self.assertRaises(ValueError):
                self.validate_text(raw)
        for field in (
            "ok",
            "failure_code",
            "schema_version",
            "source_is_prepared_context_not_observation",
            "production_request_identity_projection_checked",
        ):
            changed = copy.deepcopy(self.capture)
            changed[field] = "promoted"
            self.reject_candidate(changed, field)
        for role in ("source_context", "expected_identity"):
            changed = copy.deepcopy(self.capture)
            value = changed[role]["utf8_text"]
            raw = '{"duplicate":0,"duplicate":1,' + value[1:]
            changed[role] = {"utf8_text": raw, **context.raw_binding(raw)}
            self.reject_candidate(changed, role)

    def test_independent_prepared_identity_checks_actual_refused_collection_packet(
        self,
    ):
        native = run_zero_world_fixture(
            "res://tests/test_sdk_qsdk_r10f_l15_worker_retention_zero_world.gd",
            "QSDK_R10F_L15_WORKER_RETENTION_ZERO_WORLD ",
        )
        self.assertEqual(2, native["genuine_compiled_collection_call_count"])
        self.assertEqual(1, native["compiled_portable_step_call_count"])
        self.assertEqual(1, native["compiled_control_planning_call_count"])
        case = native["cases"]["native_schema_refusal"]
        retained = case["partial_arm"]["last_recovery_collection_transport_retention"]
        proof = packet.validate_packet(
            retained,
            expected_identity=self.proof["expected_identity"],
            canonical_sha256=closer.canonical_sha256_v1,
            expected_global_step=509,
        )
        self.assertIs(proof["retained_transport_integrity_valid"], True)
        self.assertIs(proof["expected_request_identity_checked"], True)
        self.assertIs(proof["decoded_refusal_whole_value_exact"], True)
        self.assertIs(proof["valid_physical_route_established"], False)
        self.assertIs(proof["physical_acceptance_authority"], False)
        self.assertEqual(
            "SCHEMA_INVALID", retained["decoded_collection"]["failure_code"]
        )
        self.assertIs(case["stage_ok"], False)
        crossed = copy.deepcopy(self.proof["expected_identity"])
        crossed["task_id"] = "other_task"
        with self.assertRaises(ValueError):
            packet.validate_packet(
                retained,
                expected_identity=crossed,
                canonical_sha256=closer.canonical_sha256_v1,
                expected_global_step=509,
            )


if __name__ == "__main__":
    unittest.main(verbosity=2)
