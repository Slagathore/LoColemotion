"""Recompute captured UTF-8 identities independently of the Godot producer.

Component only. Route/abort/envelope readers are not integrated or qualified.
"""

from __future__ import annotations

import copy
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "sdk/conformance"))
import qsdk_r10f_l14_runtime_binding as runtime

MARKER = "QSDK_R10F_L15_COLLECTION_TRANSPORT_ZERO_WORLD "


def verify_bytes(binding):
    if type(binding) is not dict or set(binding) != {
        "utf8_text",
        "utf8_byte_length",
        "raw_sha256",
    }:
        raise ValueError("BYTE_BINDING_SHAPE")
    if (
        type(binding["utf8_text"]) is not str
        or type(binding["utf8_byte_length"]) is not int
    ):
        raise ValueError("BYTE_BINDING_KIND")
    raw = binding["utf8_text"].encode("utf-8")
    if (
        binding["utf8_byte_length"] != len(raw)
        or binding["raw_sha256"] != "sha256:" + hashlib.sha256(raw).hexdigest()
    ):
        raise ValueError("BYTE_BINDING_MISMATCH")
    return raw


def run_zero_world_fixture(script: str, marker: str, additional_markers=()):
    """Run and join one pinned source-only fixture; never launch the physical worker."""
    runtime.bind_runtime(Path(runtime.IMAGES["godot_console"]["path"]))
    run = subprocess.run(
        [
            runtime.IMAGES["godot_engine"]["path"],
            "--headless",
            "--path",
            str(ROOT),
            "--script",
            script,
        ],
        cwd=ROOT,
        capture_output=True,
        text=True,
        encoding="utf-8",
        timeout=120,
        creationflags=subprocess.CREATE_NO_WINDOW,
    )
    lines = [
        line[len(marker) :]
        for line in run.stdout.splitlines()
        if line.startswith(marker)
    ]
    if run.returncode or "ERROR:" in run.stdout + run.stderr or len(lines) != 1:
        raise AssertionError(
            f"L15_RETENTION_COMPONENT:{run.returncode}:{run.stderr}:{run.stdout[:12000]}"
        )
    receipt = json.loads(lines[0])
    if receipt.get("ok") is not True:
        raise AssertionError(json.dumps(receipt, ensure_ascii=False)[:15000])
    if additional_markers:
        # Preserve separately emitted production report text rather than
        # rebuilding it from the fixture's summary or parsed object.
        receipt["captured_additional_marker_texts"] = {
            prefix: [
                line[len(prefix) :]
                for line in run.stdout.splitlines()
                if line.startswith(prefix)
            ]
            for prefix in additional_markers
        }
    return receipt


class CollectionTransport(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.receipt = run_zero_world_fixture(
            "res://tests/test_sdk_qsdk_r10f_l15_collection_transport_zero_world.gd",
            MARKER,
        )

    def test_exact_native_success_and_refusal_bytes_and_sources(self):
        self.assertEqual(31, self.receipt["control_count"])
        self.assertEqual([], self.receipt["failed_controls"])
        self.assertTrue(
            all(value is True for value in self.receipt["controls"].values())
        )
        self.assertEqual(3, self.receipt["genuine_compiled_collection_call_count"])
        self.assertEqual(
            0, self.receipt["additional_failure_reconstruction_call_count"]
        )
        for label in (
            "genuine_success",
            "genuine_schema_refusal",
            "genuine_observation_refusal",
        ):
            case = self.receipt["cases"][label]
            packet = case["collection_transport_retention"]
            self.assertEqual("compiled_response_decoded", packet["stage"])
            self.assertEqual(1, packet["request_serialization_call_count"])
            self.assertEqual(1, packet["compiled_collection_call_count"])
            self.assertEqual(1, packet["response_json_parse_call_count"])
            request = json.loads(verify_bytes(packet["request"]))
            raw_response = verify_bytes(packet["response"])
            response = json.loads(raw_response)
            self.assertEqual(
                {"source_application", "source_memory", "bound_observation"},
                set(packet["source_links"]),
            )
            sources = {
                key: json.loads(verify_bytes(value))
                for key, value in packet["source_links"].items()
            }
            self.assertEqual(case["collection"], packet["decoded_collection"])
            self.assertEqual("confirm_prone", sources["source_memory"]["phase"])
            self.assertEqual(509, sources["source_application"]["semantic_step"])
            if label != "genuine_schema_refusal":
                # Godot's legacy numeric parser is not a CPython parser. The
                # GDScript control checks the entire view against that actual
                # legacy decoder; here native bytes and decision labels are
                # checked independently, without an invented numeric equality.
                self.assertIs(packet["decoded_collection_is_legacy_godot_view"], True)
                self.assertIs(packet["raw_and_decoded_numeric_identity_claimed"], False)
                self.assertIs(response["ok"], True)
                for key in (
                    "schema_version",
                    "support_status",
                    "refusal_reason",
                    "adapter_id",
                    "collector_id",
                    "runtime_profile_id",
                    "engine",
                    "supplied_native_post_step_observation_validated",
                    "native_runtime_observation_collection_executed",
                    "engine_identity_exposed_to_controller",
                    "model_construction_count",
                    "world_attempt_count",
                    "world_build_count",
                    "solver_step_count",
                    "physical_acceptance_authority",
                    "release_authority",
                ):
                    self.assertEqual(
                        response["value"][key], packet["decoded_collection"][key], key
                    )
                self.assertEqual(
                    sources["bound_observation"]["observation_v2"],
                    request["observation"],
                )
                if label == "genuine_observation_refusal":
                    self.assertEqual(
                        "invalid_observation", response["value"]["support_status"]
                    )
                    self.assertEqual(
                        "observation_v2_source_binding_mismatch",
                        response["value"]["refusal_reason"],
                    )
                    self.assertNotEqual(
                        sources["bound_observation"]["source_binding"],
                        request["observation_source_binding"],
                    )
            else:
                self.assertIs(response["ok"], False)
                self.assertEqual("SCHEMA_INVALID", response["failure_code"])
                self.assertEqual(
                    response["failure_code"], case["collection"]["failure_code"]
                )
                self.assertEqual(response["detail"], case["collection"]["detail"])
                self.assertIn("invalid_owner_→_♥", packet["request"]["utf8_text"])
                self.assertGreater(
                    packet["request"]["utf8_byte_length"],
                    len(packet["request"]["utf8_text"]),
                )

    def test_malformed_response_and_precollection_stages_do_not_invent_calls(self):
        self.assertEqual(5, self.receipt["malformed_reply_stub_call_count"])
        for label, case in self.receipt["cases"].items():
            packet = case["collection_transport_retention"]
            if label.startswith("genuine_"):
                continue
            if label.startswith("precollection_"):
                self.assertEqual("precollection_refused", packet["stage"])
                self.assertEqual(0, packet["compiled_collection_call_count"])
                self.assertEqual(0, packet["response_json_parse_call_count"])
                self.assertIsNone(packet["response"])
                if label == "precollection_nonfinite":
                    self.assertIsNone(packet["request"])
                    self.assertEqual(0, packet["request_serialization_call_count"])
                else:
                    verify_bytes(packet["request"])
            else:
                self.assertEqual("compiled_response_malformed", packet["stage"])
                self.assertEqual(1, packet["compiled_collection_call_count"])
                verify_bytes(packet["request"])
                verify_bytes(packet["response"])
            self.assertIs(case["collection"]["ok"], False)
        for key in (
            "model_construction_count",
            "world_attempt_count",
            "world_build_count",
            "scene_tree_insertion_count",
            "native_physics_read_count",
            "solver_step_count",
        ):
            self.assertEqual(0, self.receipt[key], key)
        for key in (
            "route_abort_envelope_retention_qualified",
            "physical_execution_authorized",
            "physical_acceptance_authority",
            "release_authority",
        ):
            self.assertIs(self.receipt[key], False, key)

    def test_independent_byte_reader_refuses_changed_missing_and_wrong_kind_fields(
        self,
    ):
        binding = self.receipt["cases"]["genuine_schema_refusal"][
            "collection_transport_retention"
        ]["request"]
        changes = [
            {"utf8_text": binding["utf8_text"] + " "},
            {"utf8_byte_length": binding["utf8_byte_length"] + 1},
            {"raw_sha256": "sha256:" + "0" * 64},
            {"utf8_byte_length": True},
            {"utf8_byte_length": float(binding["utf8_byte_length"])},
            {"extra": 1},
        ]
        for change in changes:
            damaged = copy.deepcopy(binding)
            damaged.update(change)
            with self.assertRaises(ValueError):
                verify_bytes(damaged)
        for key in binding:
            damaged = copy.deepcopy(binding)
            del damaged[key]
            with self.assertRaises(ValueError):
                verify_bytes(damaged)


if __name__ == "__main__":
    unittest.main(verbosity=2)
