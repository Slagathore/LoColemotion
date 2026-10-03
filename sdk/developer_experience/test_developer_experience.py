from __future__ import annotations

import json
import tempfile
import unittest
from pathlib import Path

from diagnostics import diagnose_descriptor
from examples.quadruped_quickstart import run_quickstart
from examples.reference_quadruped import run_reference_frames
from python import (
    LocomotionCore,
    SELECTED_BALANCED_WAVE_POLICY_ID,
    reference_quadruped,
)
from record_replay import (
    RecordReplayError,
    replay_recording,
    verify_recording,
    write_recording,
)


class DeveloperExperienceConformanceTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.core = LocomotionCore()

    def _new_recording(
        self,
        directory: str,
        *,
        frame_count: int = 2,
    ) -> Path:
        descriptor, frames = run_reference_frames(
            self.core,
            frame_count=frame_count,
            morphology_id="developer_experience_conformance",
        )
        path = Path(directory) / "recording.jsonl"
        write_recording(
            path,
            self.core,
            recording_id="developer_experience_conformance_v1",
            descriptor=descriptor,
            frames=frames,
        )
        return path

    def test_quickstart_uses_selected_public_policy_and_no_world(self) -> None:
        receipt = run_quickstart()
        self.assertEqual(
            receipt["schema_version"],
            "sporespore_quadruped_quickstart_receipt_v1",
        )
        self.assertEqual(receipt["frame_count"], 2)
        self.assertEqual(receipt["ordered_actuator_command_count"], 16)
        self.assertTrue(receipt["recording_integrity_verified"])
        self.assertTrue(receipt["deterministic_policy_replay_exact"])
        self.assertTrue(receipt["all_outputs_pure"])
        self.assertFalse(receipt["physics_trajectory_recorded_or_replayed"])
        self.assertFalse(receipt["walking_acceptance"])
        self.assertEqual(receipt["world_build_count"], 0)
        self.assertFalse(receipt["physical_acceptance_authority"])

    def test_descriptor_diagnostic_accepts_and_explains_without_claims(
        self,
    ) -> None:
        accepted = diagnose_descriptor(
            self.core,
            reference_quadruped("diagnostic_acceptance"),
        )
        self.assertTrue(accepted["accepted"])
        self.assertEqual(accepted["ordered_body_count"], 9)
        self.assertEqual(accepted["ordered_actuator_count"], 8)
        self.assertEqual(accepted["branch_surface_count"], 0)
        self.assertFalse(accepted["walking_acceptance"])
        self.assertEqual(accepted["world_build_count"], 0)
        self.assertFalse(accepted["physical_acceptance_authority"])

        rejected_descriptor = reference_quadruped("diagnostic_rejection")
        rejected_descriptor["torso_length_scale"] = 1.100001
        rejected = diagnose_descriptor(self.core, rejected_descriptor)
        self.assertFalse(rejected["accepted"])
        self.assertTrue(rejected["failure_code"])
        self.assertTrue(rejected["failure_detail"])
        self.assertTrue(rejected["suggestion"])
        self.assertEqual(rejected["world_build_count"], 0)
        self.assertFalse(rejected["physical_acceptance_authority"])

    def test_recording_verifies_and_replays_exactly(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = self._new_recording(directory)
            verified = verify_recording(path, self.core)
            self.assertTrue(verified["integrity_verified"])
            self.assertEqual(verified["frame_count"], 2)
            self.assertFalse(verified["deterministic_replay_executed"])
            self.assertFalse(verified["physics_trajectory_recorded"])
            self.assertEqual(verified["world_build_count"], 0)
            self.assertFalse(verified["physical_acceptance_authority"])

            replayed = replay_recording(path, self.core)
            self.assertTrue(replayed["integrity_verified"])
            self.assertTrue(replayed["deterministic_replay_executed"])
            self.assertTrue(replayed["deterministic_replay_exact"])
            self.assertEqual(len(replayed["replayed_response_sha256"]), 2)
            self.assertFalse(replayed["physics_trajectory_replayed"])
            self.assertFalse(replayed["walking_acceptance"])
            self.assertFalse(replayed["physical_acceptance_authority"])

    def test_modified_frame_fails_closed(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = self._new_recording(directory)
            records = [
                json.loads(line)
                for line in path.read_text(encoding="utf-8").splitlines()
            ]
            records[1]["response"]["actuation"]["safe_no_actuation"] = True
            path.write_text(
                "\n".join(
                    json.dumps(
                        record,
                        allow_nan=False,
                        ensure_ascii=False,
                        separators=(",", ":"),
                        sort_keys=True,
                    )
                    for record in records
                )
                + "\n",
                encoding="utf-8",
            )
            with self.assertRaises(RecordReplayError) as raised:
                verify_recording(path, self.core)
            self.assertEqual(
                raised.exception.failure_code,
                "RECORD_CANONICAL_DIGEST_MISMATCH",
            )

    def test_numeric_transport_spelling_drift_fails_closed(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = self._new_recording(directory)
            records = [
                json.loads(line)
                for line in path.read_text(encoding="utf-8").splitlines()
            ]
            self.assertIsInstance(
                records[0]["descriptor"]["torso_length_scale"],
                float,
            )
            records[0]["descriptor"]["torso_length_scale"] = 1
            path.write_text(
                "\n".join(
                    json.dumps(
                        record,
                        allow_nan=False,
                        ensure_ascii=False,
                        separators=(",", ":"),
                        sort_keys=True,
                    )
                    for record in records
                )
                + "\n",
                encoding="utf-8",
            )
            with self.assertRaises(RecordReplayError) as raised:
                verify_recording(path, self.core)
            self.assertEqual(
                raised.exception.failure_code,
                "DESCRIPTOR_TRANSPORT_DIGEST_MISMATCH",
            )

    def test_deleted_frame_fails_closed(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = self._new_recording(directory)
            lines = path.read_text(encoding="utf-8").splitlines()
            path.write_text(
                "\n".join((lines[0], lines[2], lines[3])) + "\n",
                encoding="utf-8",
            )
            with self.assertRaises(RecordReplayError) as raised:
                verify_recording(path, self.core)
            self.assertEqual(
                raised.exception.failure_code,
                "FRAME_COUNT_MISMATCH",
            )

    def test_sdk_version_drift_fails_before_replay(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = self._new_recording(directory)
            records = [
                json.loads(line)
                for line in path.read_text(encoding="utf-8").splitlines()
            ]
            records[0]["sdk_version"] = "999.0.0"
            path.write_text(
                "\n".join(
                    json.dumps(
                        record,
                        allow_nan=False,
                        ensure_ascii=False,
                        separators=(",", ":"),
                        sort_keys=True,
                    )
                    for record in records
                )
                + "\n",
                encoding="utf-8",
            )
            with self.assertRaises(RecordReplayError) as raised:
                replay_recording(path, self.core)
            self.assertEqual(
                raised.exception.failure_code,
                "SDK_VERSION_MISMATCH",
            )

    def test_wrong_policy_expectation_fails_closed(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = self._new_recording(directory)
            with self.assertRaises(RecordReplayError) as raised:
                verify_recording(
                    path,
                    self.core,
                    expected_policy_id=(SELECTED_BALANCED_WAVE_POLICY_ID + "_wrong"),
                )
            self.assertEqual(
                raised.exception.failure_code,
                "POLICY_ID_MISMATCH",
            )


if __name__ == "__main__":
    unittest.main()
