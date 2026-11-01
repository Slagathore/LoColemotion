"""Check this public source declaration without requalifying the historical audit."""
import argparse
import copy
import importlib.util
import json
from pathlib import Path
from pathlib import PurePosixPath
import subprocess

ROOT = Path(__file__).resolve().parents[2]
LEGACY = ROOT / "sdk/release/licensing/check_licensing.py"
CONTRACT = ROOT / "sdk/publication/licensing_current_source_v2.json"
PREDECESSOR = "sdk/publication/licensing_current_source_v1.json"
AGPL_TEXT = "licenses/AGPL-3.0.txt"
# GNU's published agpl-3.0.txt with LF endings. Editing the license text refuses
# even if its pin is refreshed alongside it.
AGPL_LF_SHA256 = "sha256:0d96a4ff68ad6d4b6f1f30f713b18d5184912ba8dd389f86aa7710db079abcb0"
EARLIER_TERMS = "licenses/COMMUNITY-LICENSE.md"
PUBLIC_PATHS = {
    "LICENSE", AGPL_TEXT, EARLIER_TERMS, "licenses/COMMERCIAL-LICENSE.md",
    "licenses/COMMERCIAL-ORDER-FORM.md", "licenses/CONTRIBUTOR-AGREEMENT.md",
    "sdk/publication/check_licensing.py", PREDECESSOR,
}
POLICY = {
    "copyright_holder": "Charles Chambers", "effective_date": "2026-11-01",
    "public_license": "AGPL-3.0-only", "public_license_text": AGPL_TEXT, "osi_approved": True,
    "revenue_cap_usd": None, "business_evaluation_days": None, "commercial_alternative": True,
    "commercial_rights_options": ["Shared Improvements", "Private Modifications"],
    "pricing": "quote_based_business_size_and_rights_option",
    "earlier_terms": {"name": "LoColemotion SDK Community License 1.0", "path": EARLIER_TERMS,
                      "applies_to": "copies_obtained_under_earlier_notices", "text_unchanged": True},
    "third_party_obligations_preserved": True,
}
COVERED = ["sdk/", "scripts/lab/", "data/lab/", "tests/", "scenes/tools/", "harness/", "proof/", "replay/"]
RUNNERS = ["scripts/run_*.ps1", "scripts/run_all_tests.*", "scripts/process_runner*.ps1",
           "scripts/initialize_lab_attestation.ps1", "scripts/open_locomotion_experiment_workbench.ps1",
           "scripts/test_run_*.ps1", "scripts/test_run_all_tests.*", "scripts/test_process_runner*.ps1",
           "scripts/test_initialize_lab_attestation.ps1", "scripts/test_open_locomotion_experiment_workbench.ps1"]
RESERVED = ["scripts/sim/", "scenes/sim/", "scripts/tools/", "docs/", "scripts/core/", "scripts/creature/",
            "scripts/editor/", "scripts/game/", "scenes/creature/", "scenes/editor/", "scenes/game/",
            "scenes/world/", "data/creatures/", "assets/", "legacy/", "project.godot"]
AUTHORITY = {key: False for key in ("sdk1_qualification", "release_authorized", "binary_distribution_authorized",
             "physical_acceptance_authority", "customer_order_executed", "legal_opinion")}
LEDGER = dict(subsystem="publication_licensing", engine_scope="engine_neutral",
              authority_mode="non_qualifying_current_source_check", question_class="development")


def pinned_checker():
    spec = importlib.util.spec_from_file_location("locolemotion_pinned_licensing", LEGACY)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    module.REMOTE = "https://github.com/Slagathore/LoColemotion.git"
    return module


def validate_public_contract(value):
    audit = pinned_checker()
    audit.require(value["schema_version"] == "locolemotion_current_source_licensing_v2", "CURRENT_SCHEMA")
    audit.require(value["policy"] == POLICY, "CURRENT_POLICY")
    audit.require(value["authority"] == AUTHORITY and all(v is False for v in value["authority"].values()),
                  "CURRENT_AUTHORITY")
    audit.require(value["ledger_scope"] == LEDGER, "CURRENT_LEDGER")
    audit.require(value["owner_authorized_current_check"] is True and value["historical_legal_terms_edited"] is False,
                  "CURRENT_DECLARATION")
    audit.require(value["covered_directories"] == COVERED and value["covered_runner_patterns"] == RUNNERS
                  and value["reserved_material"] == RESERVED, "CURRENT_SCOPE")
    pins = {row["path"]: row for row in value["source_pins"]}
    audit.require(len(pins) == len(value["source_pins"]) and set(pins) == audit.SOURCE_PATHS | PUBLIC_PATHS,
                  "CURRENT_PIN_POPULATION")
    for relative, pin in pins.items():
        path = PurePosixPath(relative)
        audit.require(not path.is_absolute() and ".." not in path.parts and ":" not in relative
                      and "\\" not in relative, "CURRENT_PIN_PATH")
        file = ROOT / relative
        audit.require(file.is_file() and not file.is_symlink() and file.resolve().is_relative_to(ROOT), "CURRENT_PIN_FILE")
        raw = file.read_bytes()
        variants = pin["exact_byte_variants"]
        audit.require(1 <= len(variants) <= 2, "CURRENT_PIN_VARIANTS")
        audit.require(any(v["byte_length"] == len(raw) and v["sha256"] == audit.digest(raw) for v in variants),
                      "CURRENT_PIN_IDENTITY:" + relative)
        audit.require(audit.digest(raw.replace(b"\r\n", b"\n")) == pin["git_lf_sha256"],
                      "CURRENT_PIN_CONTENT:" + relative)
    audit.require(pins[AGPL_TEXT]["git_lf_sha256"] == AGPL_LF_SHA256, "CURRENT_PUBLIC_LICENSE_TEXT")
    # The superseded declaration stays bound, and the earlier terms it pinned
    # must still be the exact text kept for copies obtained under them.
    audit.require(value["predecessor"] == {"path": PREDECESSOR, "status": "superseded"}, "CURRENT_PREDECESSOR")
    predecessor = json.loads((ROOT / PREDECESSOR).read_bytes())
    audit.require(predecessor["schema_version"] == "locolemotion_current_source_licensing_v1", "PREDECESSOR_SCHEMA")
    earlier = {row["path"]: row["git_lf_sha256"] for row in predecessor["source_pins"]}
    audit.require(earlier.get(EARLIER_TERMS) == pins[EARLIER_TERMS]["git_lf_sha256"], "EARLIER_TERMS_CHANGED")
    audit.require(value["historical_contract"]["path"] == "sdk/release/quadruped_distribution_licensing_contract_v2.json",
                  "HISTORICAL_CONTRACT_PATH")
    legacy_raw = (ROOT / value["historical_contract"]["path"]).read_bytes()
    audit.require(audit.digest(legacy_raw) == value["historical_contract"]["sha256"], "HISTORICAL_CONTRACT_IDENTITY")
    # The prospective declaration binds today's inputs. Never rewrite the old
    # v2 declaration or claim that its earlier source population was revalidated.
    prospective = json.loads(legacy_raw)
    prospective["source_dependencies"] = [audit.binding(ROOT / relative) for relative in sorted(audit.SOURCE_PATHS)]
    return audit, prospective


def current_negative_controls(value):
    # Each corruption has to cross the public declaration gate itself.
    forged = [{"byte_length": 1, "sha256": "sha256:" + "0" * 64}]
    pin = lambda v, relative: next(row for row in v["source_pins"] if row["path"] == relative)
    mutations = {
        "revenue_cap_restored": lambda v: v["policy"].update(revenue_cap_usd=100000),
        "license_version_widened": lambda v: v["policy"].update(public_license="AGPL-3.0-or-later"),
        "private_option_missing": lambda v: v["policy"].update(commercial_rights_options=["Shared Improvements"]),
        "earlier_terms_dropped": lambda v: v["policy"].pop("earlier_terms"),
        "reserved_path_granted": lambda v: v["covered_directories"].append("scripts/editor/"),
        "unearned_release": lambda v: v["authority"].update(release_authorized=True),
        "license_text_forged": lambda v: pin(v, AGPL_TEXT).update(exact_byte_variants=forged),
        "predecessor_unbound": lambda v: v["source_pins"].remove(pin(v, PREDECESSOR)),
    }
    passed = []
    for name, mutation in mutations.items():
        changed = copy.deepcopy(value); mutation(changed)
        try:
            validate_public_contract(changed)
        except ValueError:
            passed.append(name)
        else:
            raise ValueError("NEGATIVE_ACCEPTED:" + name)
    return passed


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--contract", type=Path, default=CONTRACT)
    args = parser.parse_args()
    if not args.contract.resolve().is_relative_to(ROOT) or args.contract.is_symlink():
        raise ValueError("CURRENT_CONTRACT_PATH")
    value = json.loads(args.contract.read_bytes())
    audit, prospective = validate_public_contract(value)
    current_controls = current_negative_controls(value)
    audit.require(Path(audit.git("rev-parse", "--show-toplevel")).resolve() == ROOT, "CURRENT_ROOT")
    audit.require(audit.git("remote", "get-url", "origin") == audit.REMOTE, "CURRENT_REMOTE")
    inventory = json.loads((ROOT / "sdk/release/quadruped_package_source_inventory_v1.json").read_bytes())
    projection = set(audit.git("ls-files", "--", *inventory["git_pathspecs"]).splitlines())
    metadata = json.loads(subprocess.check_output(["cargo", "metadata", "--manifest-path", "sdk/Cargo.toml",
                                                 "--locked", "--offline", "--format-version", "1"], cwd=ROOT))
    audit.validate(prospective, projection=projection, metadata=metadata)
    controls = audit.negative_controls(prospective, projection, metadata)
    report = dict(schema_version="locolemotion_current_source_licensing_check_v2", checks_passed=True,
        ledger_scope=value["ledger_scope"], source=dict(commit=audit.git("rev-parse", "HEAD"),
        clean=not audit.git("status", "--porcelain=v1", "--untracked-files=all"), remote=audit.REMOTE),
        current_declaration=audit.binding(args.contract.resolve()), public_license=POLICY["public_license"],
        original_contract_revalidated=False, original_audit_or_records_edited=False,
        historical_legal_terms_edited=False, source_pins_verified=len(value["source_pins"]),
        negative_controls_passed=controls, current_negative_controls_passed=current_controls,
        historical_contract=value["historical_contract"], authority=AUTHORITY,
        execution=dict(world_build_count=0, solver_step_count=0))
    print(json.dumps(report, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
