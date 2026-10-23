"""Verify retained early-context fitting and independently rebuild its complete result."""
import argparse
import json
from pathlib import Path
import re

from early_context_feasibility import ROOT, HERE, run, read, require, sha, PARENT_SHA, declaration

RECORD = HERE / "early_context_feasibility_closure_v1.json"


def verify_record(path, evidence_root, core, baseline):
    record=read(path)
    require(record["schema_version"] == "locolemotion_early_context_feasibility_closure_v1"
            and record["status"] == "complete_training_label_feasibility"
            and record["ledger_scope"] == declaration()["ledger_scope"]
            and record["worlds_opened"] == 0 and record["training_groups"] == 8
            and record["validation_scope"] == "internal_leave_training_start_out_not_reserved_evaluation"
            and record["control_authority"] is False and record["action_mapping"] is None
            and record["adaptation_benefit"] is False and record["population_inference"] is False
            and record["qualification_or_release_authority"] is False, "Early closure identity/scope")
    require(record["parent_closure_sha256"] == PARENT_SHA
            and record["reader_sha256"] == sha(Path(__file__)), "Early closure parent/reader binding")
    root=evidence_root.resolve(strict=True);attempt=(root/record["attempt_id"]).resolve(strict=True)
    require(attempt.parent == root, "Early closure attempt path")
    paths=[]
    for item in record["artifacts"]:
        target=(root/item["evidence_relative_path"]).resolve(strict=True)
        require(target.is_relative_to(attempt) and target.is_file()
                and target.stat().st_size == item["byte_length"] and sha(target) == item["sha256"],
                "Early closure retained artifact changed")
        paths.append(target)
    require(len(paths) == len(set(paths)) == record["artifact_count"]
            and set(paths) == {p.resolve() for p in attempt.rglob("*") if p.is_file()}, "Early closure inventory")
    require(set(record["tested_sources"]) == {"early_context_v1.py", "early_context_feasibility.py",
            "early_context_feasibility_v1.json", "test_early_context_feasibility.py"},
            "Early closure tested source inventory")
    for name,digest in record["tested_sources"].items():
        require(sha(HERE/name) == digest and sha(attempt/"tested-source"/name) == digest,
                "Early closure tested source changed")
    log=(attempt/"tests/stderr.log").read_text()
    require(re.findall(r"(?m)^Ran ([0-9]+) tests? in ",log) == ["7"] and log.rstrip().endswith("OK"),
            "Early closure controls incomplete")
    retained=read(attempt/"tested-training-analysis.json")
    require(retained == record["result"], "Early closure result differs from retained analysis")
    reconstructed=run(evidence_root,core,baseline)
    require(reconstructed == retained, "Early closure regenerated training analysis differs")
    evaluation=reconstructed["evaluation"]
    require(evaluation["correct"] == 8 and evaluation["denominator"] == 8
            and evaluation["constant_nominal_correct"] == 4 and evaluation["swapped_association_correct"] == 0
            and reconstructed["worlds_opened"] == 0, "Early closure finite classification")
    return dict(ok=True,worlds_opened=0,training_groups=8,internal_correct=8,denominator=8,
        constant_nominal_correct=4,synthetic_swapped_association_correct=0,
        parent_artifacts_verified=reconstructed["parent_artifacts_verified"],artifact_count=len(paths),
        learned_control_selection=False,adaptation_benefit=False,qualification_or_release_authority=False)


if __name__ == "__main__":
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--record",type=Path,default=RECORD)
    parser.add_argument("--evidence-root",type=Path,default=ROOT.parent/"SporeSpore_Evidence")
    parser.add_argument("--core",type=Path,required=True)
    parser.add_argument("--baseline-core",type=Path,required=True)
    args=parser.parse_args()
    print(json.dumps(verify_record(args.record,args.evidence_root,args.core,args.baseline_core),indent=2))
