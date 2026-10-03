"""Read or verify the curated public evidence boundary. Never launches physics."""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path, PurePosixPath
import re
import sys

ROOT = Path(__file__).resolve().parents[2]
INDEX = "proof/EVIDENCE_INDEX.json"
AUTHORITY = {key: False for key in (
    "new_physical_acceptance", "publication_authorized", "binary_distribution_authorized",
    "formal_cross_engine_equivalence", "complete_archive_verification")}


def require(condition: bool, message: str) -> None:
    if not condition:
        raise ValueError(message)


def within(root: Path, relative: str) -> Path:
    require(isinstance(relative, str) and bool(relative), "Missing relative path")
    path = PurePosixPath(relative)
    require(not path.is_absolute() and "\\" not in relative and ":" not in relative
            and all(part not in {".", ".."} for part in path.parts), "Unsafe path: " + relative)
    root = root.resolve()
    resolved = (root / path).resolve()
    require(resolved.is_relative_to(root), "Path escapes its declared root: " + relative)
    return resolved


def read_json(path: Path):
    return json.loads(path.read_text(encoding="utf-8-sig"))


def check_bytes(root: Path, binding: dict, key: str = "path") -> None:
    path = within(root, binding[key])
    expected = binding["sha256"]
    require(isinstance(expected, str) and re.fullmatch(r"[0-9a-f]{64}", expected) is not None,
            "Invalid SHA-256: " + binding[key])
    require(type(binding["byte_length"]) is int and binding["byte_length"] >= 0,
            "Invalid byte length: " + binding[key])
    require(path.is_file(), "Missing file: " + binding[key])
    basis = binding.get("byte_basis", "raw")
    if basis == "lf_normalized_text":
        require(key == "path" and path.suffix == ".md", "Normalization is limited to indexed prose")
        raw = path.read_bytes().replace(b"\r\n", b"\n")
        observed = hashlib.sha256(raw).hexdigest()
        size = len(raw)
    else:
        require(basis == "raw", "Unknown byte basis")
        size = path.stat().st_size
        with path.open("rb") as handle:
            observed = hashlib.file_digest(handle, "sha256").hexdigest()
    alternatives = binding.get("checkout_alternatives", [])
    if alternatives:
        # Exported source can have two known checkout encodings. Bind both exact
        # digests rather than converting or weakening any retained receipt hash.
        require(key == "path" and binding[key].startswith("sdk/") and basis == "raw",
                "Checkout alternatives are limited to exported SDK source")
        raw = path.read_bytes()
        require(hashlib.sha256(raw.replace(b"\r\n", b"\n")).hexdigest() == expected,
                "Source checkout content mismatch: " + binding[key])
    candidates = [binding, *alternatives]
    require(any(size == candidate["byte_length"] for candidate in candidates), "Byte length mismatch: " + binding[key])
    require(any(size == candidate["byte_length"] and observed == candidate["sha256"] for candidate in candidates),
            "SHA-256 mismatch: " + binding[key])


def pointer(document, location: str | None):
    if location is None:
        return document
    require(location.startswith("/"), "Invalid JSON pointer")
    for part in location[1:].split("/"):
        part = part.replace("~1", "/").replace("~0", "~")
        document = document[int(part)] if isinstance(document, list) else document[part]
    return document


def verify(index: dict, root: Path, archive_root: Path | None = None) -> dict:
    require(index["schema_version"] == "locolemotion_public_evidence_index_v1", "Unsupported index schema")
    require(index["authority"] == AUTHORITY, "Public index overclaims authority")
    require(index["storage"]["full_archive_in_git"] is False, "Full archive cannot be a Git dependency")
    local = index["local_files"]
    by_path = {item["path"]: item for item in local}
    require(len(local) == len(by_path), "Duplicate local file")
    for item in local:
        check_bytes(root, item)
    records = index["records"]
    require(len({row["id"] for row in records}) == len(records), "Duplicate evidence ID")
    for row in records:
        require(row["dependency_closure_complete"] is False, "Curated record claims complete dependency closure")
        require(row["record"]["path"] in by_path, "Unbound source record")
        pointer(read_json(within(root, row["record"]["path"])), row["record"]["pointer"])
        require(all(path in by_path for path in row["related_documents"]), "Unbound related document")

    receipt = read_json(within(root, "proof/receipts/sdk1-clean-readiness.json"))
    require(receipt["sdk1_counts"] == index["sdk1_counts"], "SDK1 count mismatch")
    require(receipt["source"]["commit"] == index["archive_source_commit"]
            and receipt["source"]["clean"] is True, "SDK1 source identity mismatch")
    require({"passed": receipt["full_program"]["required_passed"], "total": receipt["full_program"]["required_total"]}
            == index["full_program_counts"], "Full-program count mismatch")
    require(receipt["claims"]["publication_authorized"] is False and receipt["claims"]["sdk1_released"] is False,
            "Milestone receipt is being presented as a release")
    for key, path in [("mapping", "sdk/release/quadruped_sdk1_milestone_mapping_v1.json"),
                      ("contract", "sdk/release/quadruped_release_contract.json"),
                      ("support_matrix", "sdk/release/quadruped_support_matrix.json")]:
        require(receipt[key]["sha256"].removeprefix("sha256:") == by_path[path]["sha256"], "Readiness binding mismatch: " + key)
    matrix = read_json(within(root, "sdk/release/quadruped_support_matrix.json"))
    require(matrix["comparative_inference"]["formal_equivalence_study_accepted"] is False
            and matrix["release_authorized"] is False, "Support scope changed")
    package = read_json(within(root, "sdk/release/sdk1_package_acceptance_closure_v1.json"))
    for key, binding in package["reports"].items():
        require(binding["sha256"].removeprefix("sha256:") == by_path[f"proof/receipts/package-{key}.json"]["sha256"],
                "Package receipt binding mismatch")
    require(package["adoption_controls"]["receipt"]["sha256"].removeprefix("sha256:")
            == by_path["proof/receipts/package-adoption-controls.json"]["sha256"], "Adoption control binding mismatch")

    manifest = read_json(within(root, "replay/manifest.json"))
    require(manifest["physical_acceptance_authority"] is False
            and manifest["formal_cross_engine_equivalence"] is False, "Replay overclaims authority")
    require(manifest["output"] == by_path["replay/bundle.js"], "Replay bundle binding mismatch")
    check_bytes(root, manifest["source_record"])
    builder = within(root, manifest["builder"]["path"]).read_bytes()
    require(hashlib.sha256(builder).hexdigest() == manifest["builder"]["sha256"], "Replay builder identity changed")
    for source in manifest["sources"]:
        original = pointer(read_json(within(root, manifest["source_record"]["path"])), source["record_pointer"])
        require(original["sha256"].removeprefix("sha256:") == source["sha256"]
                and original["byte_length"] == source["byte_length"], "Replay source binding mismatch")

    external = index["external_artifacts"]
    ids = {row["id"] for row in external}
    require(len(ids) == len(external), "Duplicate external artifact ID")
    require(all(set(row["external_artifact_ids"]) <= ids for row in records), "Unknown external artifact ID")
    for item in external:
        # Validate even skipped paths. A future archive root must never permit traversal.
        within(root, item["archive_relative_path"])
        require(item["availability"] in {"not_published", "included_copy"} and item["download_url"] is None,
                "Unexpected publication state; version the index before adding downloads")
        for origin in item["declared_by"]:
            require(origin["path"] in by_path, "Unbound external declaration")
            original = pointer(read_json(within(root, origin["path"])), origin["pointer"])
            expected = original.get("sha256", original.get("raw_sha256", "")).removeprefix("sha256:")
            require(expected == item["sha256"], "External digest disagrees with declaration")
            if "byte_length" in original:
                require(original["byte_length"] == item["byte_length"], "External size disagrees with declaration")
        if item["availability"] == "included_copy":
            require(item["local_path"] in by_path and by_path[item["local_path"]]["sha256"] == item["sha256"],
                    "Included receipt identity mismatch")
        if archive_root is not None:
            check_bytes(archive_root, item, "archive_relative_path")
    return dict(ok=True, local_files_verified=len(local),
                external_artifacts_verified=len(external) if archive_root else 0,
                external_artifacts_not_checked=0 if archive_root else len(external),
                records_indexed=len(records), experiment_revalidated=False,
                complete_dependency_closure_verified=False, worlds_opened=0)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    subs = parser.add_subparsers(dest="command", required=True)
    subs.add_parser("list", help="List the curated records")
    show = subs.add_parser("show", help="Read one record, without executing it")
    show.add_argument("id")
    check = subs.add_parser("verify", help="Check indexed bytes and presentation boundaries")
    check.add_argument("--archive-root", type=Path, help="Also check only the selected external artifacts in an existing archive")
    args = parser.parse_args()
    try:
        index = read_json(ROOT / INDEX)
        if args.command == "list":
            for row in index["records"]:
                print(f"{row['id']:24} {row['classification']:36} {row['title']}")
        elif args.command == "show":
            matches = [row for row in index["records"] if row["id"] == args.id]
            require(len(matches) == 1, "Unknown evidence ID: " + args.id)
            print(json.dumps(matches[0], indent=2))
        else:
            print(json.dumps(verify(index, ROOT, args.archive_root), indent=2))
        return 0
    except (ValueError, OSError, KeyError, TypeError, IndexError) as error:
        print(json.dumps(dict(ok=False, error=str(error), worlds_opened=0)), file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
