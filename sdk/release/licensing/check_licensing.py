"""Zero-world source-distribution licensing audit; never a legal opinion."""
from __future__ import annotations

import argparse
import copy
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import tomllib

ROOT = Path(__file__).resolve().parents[3]
CONTRACT = ROOT / "sdk/release/quadruped_distribution_licensing_contract_v2.json"
REMOTE = "https://github.com/Slagathore/sporespore.git"
SOURCE_PATHS = {".gitattributes", "sdk/Cargo.lock", "sdk/core/Cargo.toml",
                "sdk/adapters/godot/Cargo.toml", "sdk/adapters/rapier/Cargo.toml",
                "sdk/release/quadruped_package_source_inventory_v1.json",
                "sdk/release/quadruped_distribution_licensing_contract_v1.json",
                "sdk/release/licensing/check_licensing.py"}
LEGAL_PATHS = {
    "sdk/LICENSE", "sdk/THIRD_PARTY_NOTICES.md",
    *["sdk/release/licensing/" + name for name in (
        "COMMUNITY-LICENSE.md", "COMMERCIAL-LICENSE.md", "COMMERCIAL-ORDER-FORM.md",
        "CONTRIBUTOR-AGREEMENT.md", "README.md", "GODOT-LICENSE.txt",
        "GODOT-COPYRIGHT.txt", "AUTHORS.md", "JOLT-LICENSE.txt", "MPL-2.0.txt",
        "locked-dependency-licenses.json", "upstream-license-origins.json",
    )],
}
POLICY = {
    "copyright_holder": "Charles Chambers", "effective_date": "2026-10-03",
    "community_revenue_cap_usd": 100000, "cap_inclusive": True,
    "revenue_period": "trailing_twelve_months", "revenue_measure": "gross",
    "all_industries": True, "aggregate_controlled_group": True,
    "benefiting_client_assessed": True, "unrelated_personal_wages_excluded": True,
    "monetized_tutorial_exception": True, "threshold_crossing_grace_days": 90,
    "business_evaluation_days": 90, "sharing_trigger": "distribution",
    "independent_application_may_remain_private": True,
    "commercial_rights_options": ["Shared Improvements", "Private Modifications"],
    "pricing": "quote_based_business_size_and_rights_option",
    "third_party_obligations_preserved": True,
}


def git(*args: str) -> str:
    return subprocess.check_output(["git", *args], cwd=ROOT, text=True).strip()


def digest(data: bytes) -> str:
    return "sha256:" + hashlib.sha256(data).hexdigest()


def binding(path: Path) -> dict:
    data = path.read_bytes()
    return {"path": path.relative_to(ROOT).as_posix(),
            "sha256": digest(data), "byte_length": len(data)}


def require(condition: bool, code: str) -> None:
    if not condition:
        raise ValueError(code)


def validate(contract: dict, *, projection: set[str], metadata: dict) -> None:
    require(contract["schema_version"] == "sporespore_distribution_licensing_contract_v2", "SCHEMA")
    require(contract["status"] == "owner_authorized_custom_terms", "STATUS")
    require(contract["policy"] == POLICY, "OWNER_POLICY")
    require(contract["distribution_scope"] == "source_only_no_vendored_dependency_source_or_binaries", "SCOPE")
    require(contract["legal_review"] == {"automated_checks_are_legal_opinion": False,
            "attorney_review_completed": False, "owner_authorized_publication": True}, "REVIEW_SCOPE")
    require(all(v is False for v in contract["claims"].values()) and
            set(contract["claims"]) == {"binary_distribution_authorized", "release_authorized",
            "package_authorized", "physical_acceptance_authority", "customer_order_executed"}, "CLAIMS")
    entries = contract["legal_files"]
    require(len(entries) == len(LEGAL_PATHS) and {e["path"] for e in entries} == LEGAL_PATHS, "LEGAL_POPULATION")
    require(len(contract["source_dependencies"]) == len(SOURCE_PATHS) and
            {e["path"] for e in contract["source_dependencies"]} == SOURCE_PATHS, "SOURCE_POPULATION")
    historical = json.loads((ROOT / "sdk/release/quadruped_distribution_licensing_contract_v1.json").read_text(encoding="utf-8"))
    require(all(entry in contract["engine_patches"] for entry in
                historical["distribution_scope"]["godot_jolt_patch_files"]), "PATCH_HISTORY")
    for entry in entries + contract["source_dependencies"] + contract["engine_patches"]:
        path = (ROOT / entry["path"]).resolve()
        require(path.is_relative_to(ROOT) and not (ROOT / entry["path"]).is_symlink(), "UNSAFE_PATH")
        require(path.is_file() and binding(path) == entry, "FILE_IDENTITY:" + entry["path"])
    require(LEGAL_PATHS <= projection, "PACKAGE_OMISSION")
    require(not any(Path(p).suffix.lower() in {".dll", ".exe", ".so", ".a", ".lib", ".pdb", ".whl", ".rlib", ".wasm", ".dylib", ".pyc"}
                    for p in projection), "BINARY_IN_SOURCE_PROJECTION")
    require(not any({"vendor", "thirdparty", "site-packages", ".venv"} & set(Path(p).parts)
                    for p in projection), "VENDORED_SOURCE_IN_PROJECTION")
    require(not any(p.startswith("sdk/explorer/phase74_diagnostic/") for p in projection), "DIAGNOSTIC_IN_PACKAGE")
    patches = {p for p in projection if p.startswith("sdk/adapters/godot/engine_patches/") and p.endswith(".patch")}
    require(patches == {p["path"] for p in contract["engine_patches"]} and
            len(patches) == len(contract["engine_patches"]) == 7, "PATCH_POPULATION")
    inventory = json.loads((ROOT / "sdk/release/licensing/locked-dependency-licenses.json").read_text(encoding="utf-8"))
    require(inventory["cargo_lock_sha256"] == digest((ROOT / "sdk/Cargo.lock").read_bytes()), "LOCK")
    lock = tomllib.loads((ROOT / "sdk/Cargo.lock").read_text(encoding="utf-8"))
    checksums = {(p["name"], p["version"]): p.get("checksum") for p in lock["package"]}
    external = sorted([dict(name=p["name"], version=p["version"], source=p["source"],
                           license=p["license"], checksum=checksums[(p["name"], p["version"])])
                       for p in metadata["packages"] if p["source"]], key=lambda p: (p["name"], p["version"]))
    require(len(external) == 84 and external == inventory["packages"], "DEPENDENCY_POPULATION")
    workspace = [p for p in metadata["packages"] if not p["source"]]
    require({p["name"] for p in workspace} == {"sporespore-locomotion-core", "sporespore-godot-adapter", "sporespore-rapier-adapter"}, "WORKSPACE")
    for package in workspace:
        require(package["license"] is None and isinstance(package["license_file"], str), "CUSTOM_METADATA")
        require((Path(package["manifest_path"]).parent / package["license_file"]).resolve() == ROOT / "sdk/LICENSE", "LICENSE_FILE")
    community = (ROOT / "sdk/release/licensing/COMMUNITY-LICENSE.md").read_text(encoding="utf-8")
    require("Charles Chambers" in community and "US$100,000" in community and
            "DRAFT" not in community and "PENDING" not in community, "INACTIVE_COMMUNITY_TEXT")


def negative_controls(contract: dict, projection: set[str], metadata: dict) -> list[str]:
    # Each corruption crosses an actual gate boundary rather than testing a mock checker.
    mutations = {
        "owner": lambda c: c["policy"].update(copyright_holder="Some Company"),
        "threshold": lambda c: c["policy"].update(community_revenue_cap_usd=1000000),
        "industry_loophole": lambda c: c["policy"].update(all_industries=False),
        "subsidiary_loophole": lambda c: c["policy"].update(aggregate_controlled_group=False),
        "client_loophole": lambda c: c["policy"].update(benefiting_client_assessed=False),
        "private_option_missing": lambda c: c["policy"].update(commercial_rights_options=["Shared Improvements"]),
        "upstream_waiver": lambda c: c["policy"].update(third_party_obligations_preserved=False),
        "unearned_release": lambda c: c["claims"].update(release_authorized=True),
        "false_legal_review": lambda c: c["legal_review"].update(attorney_review_completed=True),
        "license_tamper": lambda c: c["legal_files"][0].update(sha256="sha256:" + "0" * 64),
        "missing_license": lambda c: c["legal_files"].pop(),
        "changed_patch": lambda c: c["engine_patches"][0].update(sha256="sha256:" + "0" * 64),
        "changed_dependency": lambda c: c["source_dependencies"][0].update(byte_length=1),
        "missing_dependency_binding": lambda c: c["source_dependencies"].pop(),
    }
    passed = []
    for name, mutation in mutations.items():
        changed = copy.deepcopy(contract); mutation(changed)
        try:
            validate(changed, projection=projection, metadata=metadata)
        except ValueError:
            passed.append(name)
        else:
            raise ValueError("NEGATIVE_ACCEPTED:" + name)
    for name, changed in [("projection_omission", projection - {"sdk/LICENSE"}),
                           ("binary_added", projection | {"sdk/unreviewed.dll"}),
                           ("vendored_source_added", projection | {"sdk/vendor/other/source.rs"}),
                           ("diagnostic_added", projection | {"sdk/explorer/phase74_diagnostic/launch.py"})]:
        try:
            validate(contract, projection=changed, metadata=metadata)
        except ValueError:
            passed.append(name)
        else:
            raise ValueError("NEGATIVE_ACCEPTED:" + name)
    changed = copy.deepcopy(metadata)
    next(p for p in changed["packages"] if not p["source"])["license_file"] = "missing"
    try:
        validate(contract, projection=projection, metadata=changed)
    except ValueError:
        passed.append("crossed_cargo_license")
    else:
        raise ValueError("NEGATIVE_ACCEPTED:crossed_cargo_license")
    return passed


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--require-ready", action="store_true")
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    require(Path(git("rev-parse", "--show-toplevel")).resolve() == ROOT, "REPO_ROOT")
    require(git("remote", "get-url", "origin") == REMOTE, "REMOTE")
    contract = json.loads(CONTRACT.read_text(encoding="utf-8"))
    inventory = json.loads((ROOT / "sdk/release/quadruped_package_source_inventory_v1.json").read_text(encoding="utf-8"))
    projection = set(git("ls-files", "--", *inventory["git_pathspecs"]).splitlines())
    metadata = json.loads(subprocess.check_output(["cargo", "metadata", "--manifest-path", "sdk/Cargo.toml",
                                                 "--locked", "--offline", "--format-version", "1"], cwd=ROOT))
    validate(contract, projection=projection, metadata=metadata)
    controls = negative_controls(contract, projection, metadata)
    head = git("rev-parse", "HEAD")
    origin = git("rev-parse", "origin/main")
    clean = not git("status", "--porcelain=v1", "--untracked-files=all")
    live = git("ls-remote", "origin", "refs/heads/main").split()[0] if args.require_ready else None
    ready = clean and head == origin and head == live
    report = {"schema_version": "sporespore_distribution_licensing_readiness_v2",
              "ledger_scope": contract["ledger_scope"], "checks_passed": True,
              "r19_passed": ready, "sdk1_m14_passed": ready,
              "source": {"commit": head, "origin_main": origin, "live_main": live, "clean": clean},
              "contract": binding(CONTRACT), "negative_controls_passed": controls,
              "legal_file_count": len(LEGAL_PATHS), "external_dependency_count": 84,
              "patch_count": 7, "package_source_file_count": len(projection),
              "claims": contract["claims"], "legal_review": contract["legal_review"],
              "execution": {"world_build_count": 0, "solver_step_count": 0}}
    if args.output:
        output = args.output.resolve()
        require(output.is_relative_to(ROOT.parent / "SporeSpore_Evidence") and not output.exists(), "OUTPUT_BOUNDARY")
        output.parent.mkdir(parents=True, exist_ok=True)
        with output.open("x", encoding="utf-8", newline="\n") as stream:
            stream.write(json.dumps(report, indent=2) + "\n")
    print(json.dumps(report, indent=2))
    return 0 if not args.require_ready or ready else 2


if __name__ == "__main__":
    sys.exit(main())
