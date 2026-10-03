"""Independent packet reader over the actual emitted production-route data."""

import copy
import hashlib
import json
from pathlib import Path
import sys
import unittest

from test_qsdk_r10f_l15_collection_transport import run_zero_world_fixture

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "sdk/conformance"))
import qsdk_r10f_l15_collection_retention as reader
import qsdk_r10f_physical_closure as closure


def binding(value):
    text = (
        value
        if type(value) is str
        else json.dumps(
            value, ensure_ascii=False, separators=(",", ":"), allow_nan=False
        )
    )
    raw = text.encode("utf-8")
    return {
        "utf8_text": text,
        "utf8_byte_length": len(raw),
        "raw_sha256": "sha256:" + hashlib.sha256(raw).hexdigest(),
    }


class IndependentCollectionRetention(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.fixture = run_zero_world_fixture(
            "res://tests/test_sdk_qsdk_r10f_l15_route_retention_zero_world.gd",
            "QSDK_R10F_L15_ROUTE_RETENTION_ZERO_WORLD ",
        )
        cls.packets = {
            name: case["collection_transport_retention"]
            for name, case in cls.fixture["cases"].items()
            if name != "legacy_success"
        }
        request = reader.parse_json(cls.packets["success"]["request"]["utf8_text"])
        # Freeze the independently supplied expected identity before damaging
        # packets. Production callers must obtain this from their authority.
        cls.identity = {
            key: copy.deepcopy(request[key]) for key in reader.IDENTITY_KEYS
        }

    def audit(self, packet, **kwargs):
        return reader.validate_packet(
            packet,
            expected_identity=self.identity,
            canonical_sha256=closure.canonical_sha256_v1,
            expected_global_step=509,
            **kwargs
        )

    def test_actual_supported_refused_and_precollection_shapes(self):
        kinds = {
            "success": "reported_supported_exact",
            "native_schema_refusal": "abi_refusal",
            "native_observation_refusal": "value_refusal",
            "native_portable_step_refusal": "reported_supported_exact",
            "malformed_reply": "malformed_response",
            "precollection_crossed_memory": "not_called",
            "precollection_bad_phase": "not_called",
            "precollection_bad_profile": "not_called",
        }
        for name, expected_kind in kinds.items():
            with self.subTest(name=name):
                result = self.audit(self.packets[name])
                self.assertIs(result["retained_transport_integrity_valid"], True)
                self.assertEqual(expected_kind, result["native_response_kind"])
                self.assertIs(result["valid_physical_route_established"], False)
                self.assertIs(
                    result["legacy_decoded_numbers_used_for_inference"], False
                )
                self.assertIs(result["raw_and_decoded_numeric_identity_claimed"], False)
        for name in (
            "precollection_missing_application",
            "precollection_missing_bound",
        ):
            with self.assertRaises(ValueError):
                self.audit(self.packets[name])
        refusal = self.audit(self.packets["native_schema_refusal"])
        self.assertIs(refusal["decoded_refusal_whole_value_exact"], True)

    def test_view_difference_is_explicit_and_not_a_tolerance(self):
        result = self.audit(self.packets["success"])
        dt = [
            entry
            for entry in result["legacy_numeric_differences"]
            if entry["path"] == "$.observation.outer_step_duration_s"
        ]
        self.assertEqual(1, len(dt))
        self.assertEqual("0x1.1111111111111p-7", dt[0]["native_float_hex"])
        self.assertEqual("0x1.111111111110fp-7", dt[0]["legacy_float_hex"])
        self.assertIs(result["legacy_decoded_numbers_used_for_inference"], False)
        self.assertIs(result["valid_physical_route_established"], False)

    def test_rejects_every_missing_packet_field_and_wrong_kind_counters(self):
        original = self.packets["success"]
        for key in original:
            damaged = copy.deepcopy(original)
            del damaged[key]
            with self.subTest(missing=key), self.assertRaises(ValueError):
                self.audit(damaged)
        counters = reader.ZERO_COUNTERS | {
            "request_serialization_call_count",
            "compiled_collection_call_count",
            "response_json_parse_call_count",
        }
        for key in counters:
            for replacement in (True, float(original[key]), original[key] + 1):
                damaged = copy.deepcopy(original)
                damaged[key] = replacement
                with self.subTest(
                    counter=key, replacement=replacement
                ), self.assertRaises(ValueError):
                    self.audit(damaged)
        for key in reader.FALSE_FLAGS | {"decoded_collection_is_legacy_godot_view"}:
            damaged = copy.deepcopy(original)
            damaged[key] = int(original[key])
            with self.subTest(flag=key), self.assertRaises(ValueError):
                self.audit(damaged)

    def test_rehashed_request_and_source_substitutions_do_not_repair_bindings(self):
        original = self.packets["success"]
        mutations = []
        for key in reader.IDENTITY_KEYS:
            damaged = copy.deepcopy(original)
            request = json.loads(damaged["request"]["utf8_text"])
            request[key] = "crossed_identity"
            damaged["request"] = binding(request)
            mutations.append(damaged)
        for key in ("observation", "observation_source_binding"):
            damaged = copy.deepcopy(original)
            request = json.loads(damaged["request"]["utf8_text"])
            request[key] = {}
            damaged["request"] = binding(request)
            mutations.append(damaged)
        damaged = copy.deepcopy(original)
        memory = json.loads(damaged["source_links"]["source_memory"]["utf8_text"])
        memory["phase_steps_observed"] += 1
        damaged["source_links"]["source_memory"] = binding(memory)
        mutations.append(damaged)
        damaged = copy.deepcopy(original)
        (
            damaged["source_links"]["source_application"],
            damaged["source_links"]["source_memory"],
        ) = (
            damaged["source_links"]["source_memory"],
            damaged["source_links"]["source_application"],
        )
        mutations.append(damaged)
        for index, damaged in enumerate(mutations):
            with self.subTest(mutation=index), self.assertRaises(ValueError):
                self.audit(damaged)

    def test_byte_corruption_decision_rewriting_and_fabricated_precollection_response(
        self,
    ):
        for slot in ("request", "response"):
            for field, replacement in (
                ("utf8_text", self.packets["success"][slot]["utf8_text"] + " "),
                ("utf8_byte_length", True),
                ("raw_sha256", "sha256:" + "0" * 64),
            ):
                damaged = copy.deepcopy(self.packets["success"])
                damaged[slot][field] = replacement
                with self.subTest(slot=slot, field=field), self.assertRaises(
                    ValueError
                ):
                    self.audit(damaged)
        damaged = copy.deepcopy(self.packets["native_schema_refusal"])
        damaged["decoded_collection"]["detail"] = "rewritten refusal"
        with self.assertRaises(ValueError):
            self.audit(damaged)
        damaged = copy.deepcopy(self.packets["success"])
        damaged["decoded_collection"]["support_status"] = "invalid_observation"
        with self.assertRaises(ValueError):
            self.audit(damaged)
        damaged = copy.deepcopy(self.packets["success"])
        damaged["decoded_collection"]["solver_step_count"] = 1
        with self.assertRaises(ValueError):
            self.audit(damaged)
        damaged = copy.deepcopy(self.packets["precollection_bad_phase"])
        damaged["response"] = binding({"ok": True, "value": {}})
        with self.assertRaises(ValueError):
            self.audit(damaged)

    def test_duplicate_nonfinite_and_wrong_stage_json_refused(self):
        for text in ('{"x":1,"x":2}', '{"x":NaN}', '{"x":1e400}'):
            with self.assertRaises(ValueError):
                reader.parse_json(text)
        damaged = copy.deepcopy(self.packets["success"])
        damaged["response"] = binding('{"ok":false,"ok":true,"value":{}}')
        with self.assertRaises(ValueError):
            self.audit(damaged)
        damaged = copy.deepcopy(self.packets["success"])
        damaged["stage"] = "precollection_refused"
        damaged["transport_failure_code"] = "invented_precollection_stage"
        with self.assertRaises(ValueError):
            self.audit(damaged)

    def test_native_observation_and_source_digests_are_independently_linked(self):
        original = self.packets["success"]
        self.assertIs(
            self.audit(original)[
                "native_observation_request_and_source_digests_verified"
            ],
            True,
        )
        for key in (
            "observation_sha256",
            "observation_source_binding_sha256",
            "capability_sha256",
        ):
            damaged = copy.deepcopy(original)
            response = json.loads(damaged["response"]["utf8_text"])
            response["value"][key] = "sha256:" + "0" * 64
            damaged["response"] = binding(response)
            damaged["decoded_collection"][key] = response["value"][key]
            with self.subTest(digest=key), self.assertRaises(ValueError):
                self.audit(damaged)
        damaged = copy.deepcopy(original)
        response = json.loads(damaged["response"]["utf8_text"])
        value = response["value"]
        value["observation"]["outer_step_duration_s"] *= 2
        value["observation_sha256"] = closure.canonical_sha256_v1(value["observation"])
        value["observation_source_binding"]["portable_observation_sha256"] = value[
            "observation_sha256"
        ]
        value["observation_source_binding_sha256"] = closure.canonical_sha256_v1(
            value["observation_source_binding"]
        )
        damaged["response"] = binding(response)
        damaged["decoded_collection"] = copy.deepcopy(value)
        with self.assertRaises(ValueError):
            self.audit(damaged)
        with self.assertRaises(ValueError):
            reader.validate_packet(
                original,
                expected_identity=self.identity,
                canonical_sha256=lambda _value: "sha256:" + "0" * 64,
            )

    def test_rehashed_application_and_mapping_source_changes_are_refused(self):
        original = self.packets["success"]
        for key in (
            "source_memory_sha256",
            "source_application_sha256",
            "canonical_controller_owner",
        ):
            damaged = copy.deepcopy(original)
            app = json.loads(damaged["source_links"]["source_application"]["utf8_text"])
            app["canonical_ownership_mapping"][key] = "changed_source"
            damaged["source_links"]["source_application"] = binding(app)
            with self.subTest(mapping=key), self.assertRaises(ValueError):
                self.audit(damaged)
        damaged = copy.deepcopy(original)
        app = json.loads(damaged["source_links"]["source_application"]["utf8_text"])
        app["zero_command"] = not app["zero_command"]
        damaged["source_links"]["source_application"] = binding(app)
        with self.assertRaises(ValueError):
            self.audit(damaged)


if __name__ == "__main__":
    unittest.main(verbosity=2)
