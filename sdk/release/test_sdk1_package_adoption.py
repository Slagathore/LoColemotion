"""Exercise the actual release compiler against the three new package proofs.

Fixtures live in a fresh durable directory; retained candidates and reports are
read-only. No physics process is started by this test.
"""
import argparse
import copy
import json
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[2]


def require(value, detail):
    if not value:
        raise AssertionError(detail)


def read(path):
    return json.loads(path.read_text(encoding="utf-8-sig"))


def run(output):
    require(subprocess.check_output(["git", "rev-parse", "--show-toplevel"], cwd=ROOT,
                                   text=True).strip().replace("\\", "/") == ROOT.as_posix(), "Repository root")
    require(subprocess.check_output(["git", "remote", "get-url", "origin"], cwd=ROOT,
                                   text=True).strip() == "https://github.com/Slagathore/sporespore.git", "Origin")
    output = output.resolve()
    require(output.is_relative_to(ROOT.parent / "SporeSpore_Evidence"), "Use durable evidence root")
    output.mkdir(parents=True, exist_ok=False)
    compiler = ROOT / "sdk/compile_quadruped_sdk_release_readiness.ps1"
    contract = read(ROOT / "sdk/release/quadruped_release_contract.json")
    matrix = read(ROOT / "sdk/release/quadruped_support_matrix.json")

    def compile_case(label, changed_contract, changed_matrix):
        folder = output / label
        folder.mkdir()
        for name, value in [("contract.json", changed_contract), ("matrix.json", changed_matrix)]:
            (folder / name).write_text(json.dumps(value, indent=2) + "\n", encoding="utf-8")
        with (folder / "compiler.log").open("x", encoding="utf-8") as log:
            subprocess.run(["pwsh", "-NoProfile", "-File", str(compiler),
                            "-Contract", str(folder / "contract.json"),
                            "-SupportMatrix", str(folder / "matrix.json"),
                            "-Output", str(folder / "report.json")], cwd=ROOT,
                           stdout=log, stderr=subprocess.STDOUT, check=True)
        return read(folder / "report.json")

    baseline = compile_case("positive", contract, matrix)
    require(baseline["gate_counts"]["required_passed"] == 19, "Full-program finite count")
    require(baseline["support_matrix"]["consistent_with_gate_dispositions"] is True, "Support matrix")
    for gate_id in ("QSDK-R01", "QSDK-R16", "QSDK-R20"):
        changed = copy.deepcopy(contract)
        gate = next(g for g in changed["gates"] if g["gate_id"] == gate_id)
        gate["proof"]["sha256"] = "sha256:" + "0" * 64
        observed = compile_case(gate_id.lower(), changed, matrix)
        result = next(g for g in observed["gates"] if g["gate_id"] == gate_id)
        require(result["disposition"] == "invalid_proof", "Corrupted receipt accepted: " + gate_id)
        require(observed["gate_counts"]["required_passed"] == 18, "Corrupted mark retained")
    overclaim = copy.deepcopy(matrix)
    overclaim["release_authorized"] = True
    observed = compile_case("publication_overclaim", contract, overclaim)
    require(observed["support_matrix"]["consistent_with_gate_dispositions"] is False,
            "Full-program release overclaim accepted")
    result = {"schema_version": "sporespore_sdk1_package_adoption_controls_v1",
              "ledger_scope": {"subsystem": "release", "engine_scope": "sdk1",
                               "authority_mode": "zero_world_adoption_controls", "question_class": "development"},
              "positive_control": True, "package_receipt_corruptions_rejected": 3,
              "release_overclaim_rejected": True, "world_build_count": 0,
              "publication_authorized": False}
    (output / "receipt.json").write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(result))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    run(parser.parse_args().output)
