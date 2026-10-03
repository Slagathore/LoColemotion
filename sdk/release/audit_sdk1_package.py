"""Read-only R20 source-package determinism and isolated-consumption auditor.

The compared artifacts remain watermarked candidates. Native build reproducibility,
physical success, and publication permission are outside this audit's scope.
"""
from __future__ import annotations

import argparse
import copy
import hashlib
import json
import re
from pathlib import Path, PurePosixPath


def require(condition, message):
    if not condition:
        raise ValueError(message)


def digest(path):
    return "sha256:" + hashlib.sha256(Path(path).read_bytes()).hexdigest()


def read(path):
    return json.loads(Path(path).read_text(encoding="utf-8-sig"))


def entries(manifest):
    result = {}
    for item in manifest["files"]:
        name = item["path"]
        path = PurePosixPath(name)
        require(re.fullmatch(r"[A-Za-z0-9_./-]+", name) is not None
                and not path.is_absolute() and str(path) == name
                and not any(part in (".", "..") for part in path.parts),
                "Unsafe source path")
        require(name.casefold() not in result, "Duplicate source path")
        require(re.fullmatch(r"sha256:[0-9a-f]{64}", item["sha256"]), "Invalid source hash")
        result[name.casefold()] = item
    require(len(result) == manifest["file_count"] and result, "Source count mismatch")
    return result


def no_links(root):
    # Junctions and other Windows reparse points may escape without is_symlink().
    for path in [root, *root.rglob("*")]:
        require(not path.is_symlink() and not
                (getattr(path.lstat(), "st_file_attributes", 0) & 0x400),
                f"Reparse point in candidate: {path}")


def validate_join(manifest, marker, readiness, r01, r16, package, manifest_hash):
    source = manifest["source_commit"]
    require(re.fullmatch(r"[0-9a-f]{40}", source), "Invalid source commit")
    require(manifest["schema_version"] == "sporespore_quadruped_sdk_package_manifest_v1",
            "Wrong package schema")
    for obj in (manifest, marker):
        require(obj["artifact_role"] == "sdk1_clean_room_conformance_candidate"
                and obj["candidate_authority_scope"] == "bounded_sdk1_17_plus_3"
                and obj["source_commit"] == source
                and obj["release_authorized"] is False
                and obj["publication_authorized"] is False, "Candidate authority mismatch")
    require(readiness["clean_room_candidate_authorized"] is True
            and readiness["source"]["commit"] == source
            and readiness["source"]["clean"] is True
            and readiness["source"]["matches_origin_main"] is True
            and readiness["clean_room_candidate_blocking_conditions"] == []
            and readiness["clean_room_candidate_validation_gate_ids"] ==
                ["QSDK-R01", "QSDK-R16", "QSDK-R20"], "Unqualified candidate freeze")
    for receipt, gate, flag, schema in (
        (r01, "QSDK-R01", "r01_passed", "sporespore_portable_api_conformance_report_v1"),
        (r16, "QSDK-R16", "r16_passed", "sporespore_developer_experience_conformance_report_v1"),
    ):
        require(receipt["schema_version"] == schema
                and receipt["status"] == "clean_room_candidate_passed"
                and receipt["validation_scope"] == "clean_room_candidate"
                and receipt["clean_room_candidate_validated"] is True
                and receipt[flag] is True and receipt["release_gate_id"] == gate,
                f"Incomplete {gate} receipt")
        require(Path(receipt["package_root"]).resolve() == package
                and receipt["source"]["authority"] == "package_manifest"
                and receipt["source"]["commit"] == source
                and receipt["source"]["package_manifest_sha256"] == manifest_hash
                and receipt["source"]["package_file_hashes_verified"] is True,
                f"Crossed {gate} package/source")
        require(receipt["claims"]["release_authorized"] is False
                and receipt["claims"]["publication_authorized"] is False
                and receipt["claims"]["physical_acceptance_authority"] is False,
                f"Overclaim in {gate}")
    require(r01["candidate_authorization"]["sha256"] == manifest["readiness_report"]["sha256"]
            and r01["candidate_authorization"]["source_commit"] == source
            and r01["candidate_authorization"]["clean_room_candidate_authorized"] is True,
            "R01 authorization mismatch")
    projection = r01["package_projection"]
    require(projection["file_count"] == manifest["file_count"]
            and projection["package_manifest_sha256"] == manifest_hash
            and projection["all_file_hashes_verified"] is True
            and projection["isolated_from_source_repository"] is True
            and projection["package_inventory_and_isolation_passed"] is True
            and r16["package_manifest_sha256"] == manifest_hash, "Package projection mismatch")
    c = r01["conformance"]
    require(c["cell_count"] == c["passed_cell_count"] == 8
            and c["failed_cell_count"] == c["rust_unit_test_failure_count"] ==
                c["python_ctypes_test_failure_count"] == 0
            and c["rust_unit_test_count"] > 0 and c["python_ctypes_test_count"] > 0
            and c["sdk1_extension_test_count"] == 3 and c["sdk1_extension_test_failure_count"] == 0
            and c["surface_negative_control_count"] == c["surface_negative_control_rejection_count"] == 10
            and c["current_source_positive_control_count"] == 1, "R01 incomplete tests")
    require(all(c[key] == c["contract_symbol_count"] > 0 for key in (
        "rust_export_count", "c_declaration_count", "python_ctypes_signature_count",
        "dynamic_library_resolved_export_count", "dynamic_library_invoked_export_count")),
        "R01 surface parity mismatch")
    require(all(c[key] is True for key in (
        "exact_signature_parity_passed", "real_dynamic_library_load_passed",
        "caller_owned_buffer_and_typed_refusal_paths_passed", "package_source_projection_passed",
        "package_inventory_and_isolation_passed")), "R01 incomplete surface audit")
    require(all(type(value) is int and value == 0 for value in r01["execution"].values()),
            "Unexpected physical execution")
    c = r16["conformance"]
    require(c["unit_test_count"] == 8 and c["unit_test_failure_count"] == 0
            and all(c[key] is True for key in (
                "quickstart_passed", "diagnostics_passed", "recording_verify_passed",
                "deterministic_policy_replay_passed", "negative_tamper_numeric_gap_version_policy_tests_passed",
                "package_inventory_and_isolation_passed")), "R16 incomplete tests")
    require(r16["recording"]["integrity_verified"] is True
            and r16["recording"]["deterministic_policy_replay_exact"] is True
            and r16["recording"]["physics_trajectory_recorded_or_replayed"] is False
            and r16["claims"]["world_build_count"] == 0, "R16 replay scope mismatch")
    require(r01["library"]["sha256"] == r16["library"]["sha256"]
            and Path(r01["library"]["path"]).resolve() == Path(r16["library"]["path"]).resolve(),
            "Crossed native libraries")


def audit(checkpoint, forbidden):
    checkpoint, forbidden = checkpoint.resolve(), forbidden.resolve()
    a, b = checkpoint / "candidate-a", checkpoint / "candidate-b"
    require(a != b and not a.is_relative_to(forbidden) and not b.is_relative_to(forbidden),
            "Candidates must be outside source repository")
    for root in (a, b):
        no_links(root)
        for forbidden_name in (".git", "project.godot", "scripts", "tests"):
            require(not (root / forbidden_name).exists(), "Game/source checkout in candidate")
    manifest = read(a / "PACKAGE_MANIFEST.json")
    selected = entries(manifest)
    metadata = ["PACKAGE_MANIFEST.json", "NOT_FOR_DISTRIBUTION.json"]
    for name in metadata:
        require((a / name).read_bytes() == (b / name).read_bytes(), "Package metadata differs")
    for item in selected.values():
        for root in (a, b):
            require(digest(root / item["path"]) == item["sha256"], "Changed packaged source")
    expected = set(selected) | {name.casefold() for name in metadata}
    for root in (a, b):
        actual = {path.relative_to(root).as_posix().casefold() for path in root.rglob("*")
                  if path.is_file() and not (root == a and path.is_relative_to(a / "target"))}
        require(actual == expected, "Unexpected package file population")
    readiness_path = checkpoint / "readiness.json"
    require(digest(readiness_path) == manifest["readiness_report"]["sha256"]
            and Path(manifest["readiness_report"]["source_path"]).resolve() == readiness_path,
            "Changed/crossed readiness authority")
    r01, r16 = read(checkpoint / "r01.json"), read(checkpoint / "r16.json")
    args = [manifest, read(a / metadata[1]), read(readiness_path), r01, r16,
            a, digest(a / metadata[0])]
    validate_join(*args)
    library = Path(r01["library"]["path"]).resolve()
    require(library.is_relative_to(a / "target") and digest(library) == r01["library"]["sha256"],
            "Changed/external isolated build")
    # Exercise refusal paths on copies; never mutate retained artifacts.
    mutations = [
        (0, ("publication_authorized",), True),
        (1, ("source_commit",), "0" * 40),
        (2, ("clean_room_candidate_authorized",), False),
        (3, ("r01_passed",), False),
        (3, ("validation_scope",), "source_tree"),
        (3, ("source", "commit"), "0" * 40),
        (3, ("conformance", "failed_cell_count"), 1),
        (3, ("conformance", "surface_negative_control_rejection_count"), 9),
        (3, ("conformance", "dynamic_library_invoked_export_count"), 0),
        (3, ("conformance", "sdk1_extension_test_count"), 0),
        (3, ("package_projection", "all_file_hashes_verified"), False),
        (3, ("execution", "world_build_count"), 1),
        (4, ("r16_passed",), False),
        (4, ("package_manifest_sha256",), "sha256:" + "0" * 64),
        (4, ("conformance", "diagnostics_passed"), False),
        (4, ("recording", "deterministic_policy_replay_exact"), False),
        (4, ("library", "sha256"), "sha256:" + "0" * 64),
    ]
    for index, keys, value in mutations:
        crossed = copy.deepcopy(args)
        obj = crossed[index]
        for key in keys[:-1]:
            obj = obj[key]
        obj[keys[-1]] = value
        try:
            validate_join(*crossed)
        except ValueError:
            continue
        raise ValueError(f"Negative control accepted: {index} {keys}")
    artifacts = [readiness_path, checkpoint / "r01.json", checkpoint / "r16.json",
                 checkpoint / "package-a.log", checkpoint / "package-b.log",
                 checkpoint / "r01.log", checkpoint / "r16.log",
                 *(root / name for root in (a, b) for name in metadata)]
    return {
        "schema_version": "sporespore_sdk1_package_isolation_report_v1",
        "ledger_scope": {"subsystem": "release", "engine_scope": "sdk1",
                         "authority_mode": "zero_world_package_conformance", "question_class": "development"},
        "status": "clean_room_candidate_passed", "release_gate_id": "QSDK-R20",
        "r20_passed": True, "source_commit": manifest["source_commit"],
        "candidate_directories": [str(a), str(b)],
        "source_file_count": manifest["file_count"], "metadata_file_count": 2,
        "all_source_and_metadata_bytes_identical": True,
        "isolated_r01_passed": True, "isolated_r16_passed": True,
        "negative_controls_rejected": len(mutations),
        "native_library": {"path": str(library), "sha256": digest(library)},
        "artifacts": [{"path": str(p), "sha256": digest(p)} for p in artifacts],
        "claims": {"deterministic_source_package": True, "deterministic_native_build": False,
                   "world_build_count": 0, "physical_acceptance_authority": False,
                   "release_authorized": False, "publication_authorized": False},
    }


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--checkpoint", type=Path, required=True)
    parser.add_argument("--forbidden-source", type=Path, required=True)
    parser.add_argument("--output", type=Path)
    options = parser.parse_args()
    result = audit(options.checkpoint, options.forbidden_source)
    text = json.dumps(result, indent=2) + "\n"
    if options.output:
        with options.output.open("x", encoding="utf-8") as stream:
            stream.write(text)
    print(text)
