"""Reproduce the complete development fit and independently check blocked scores."""
import argparse
import json
import re
from pathlib import Path

from first_response_repertoire import ROOT, HERE, PARENT_SHA, declaration, run, read, sha, require

RECORD = HERE / "first_response_repertoire_closure_v1.json"
TESTED = ["sdk/discovery/first_response_v1.py", "sdk/discovery/first_response_repertoire.py",
    "sdk/discovery/first_response_repertoire_v1.json", "sdk/discovery/test_first_response_repertoire.py",
    "sdk/adaptation_provider/retrieval/feedback_flat_v1.py",
    "sdk/adaptation_provider/retrieval/feedback_contract_v1.json"]


def check_evaluation(result):
    """Recalculate centroids and predictions without calling the estimator."""
    groups = result["groups"]
    evaluation = result["evaluation"]
    labels = ["left_075", "nominal"]
    starts = ["train_001", "train_003", "train_004", "train_006"]
    require(len(groups) == 8 and {(g["condition_id"], g["start_id"]) for g in groups}
        == {(label, start) for label in labels for start in starts}, "Independent context population")
    require([f["held_out_training_start"] for f in evaluation["folds"]] == starts,
        "Independent fold population")
    correct = constant = swapped = 0
    for fold in evaluation["folds"]:
        held = fold["held_out_training_start"]
        training = sorted([g for g in groups if g["start_id"] != held], key=lambda g:g["group_id"])
        model = fold["model"]
        require(model["training_group_ids"] == [g["group_id"] for g in training], "Independent blocked training identities")
        centers = []
        for label in labels:
            values = [g["features"]["values"] for g in training if g["condition_id"] == label]
            centers.append(dict(condition_id=label, values=[sum(v[j] for v in values)/3 for j in range(16)]))
        require(model["centroids"] == centers, "Independent fitted centroids")
        testing = [g for g in groups if g["start_id"] == held]
        require([p["group_id"] for p in fold["predictions"]] == [g["group_id"] for g in testing], "Independent testing identities")
        for group, saved in zip(testing, fold["predictions"], strict=True):
            distances = [sum((x-y)**2 for x,y in zip(group["features"]["values"], c["values"], strict=True)) for c in centers]
            label = None if distances[0] == distances[1] else labels[distances[1] < distances[0]]
            reversed_label = None if label is None else labels[1-labels.index(label)]
            require(saved["prediction"]["condition_id"] == label
                and saved["prediction"]["squared_distances"] == dict(zip(labels, distances, strict=True))
                and saved["expected_condition_id"] == group["condition_id"]
                and saved["correct"] is (label == group["condition_id"])
                and saved["constant_nominal_correct"] is (group["condition_id"] == "nominal")
                and saved["swapped_association_correct"] is (reversed_label == group["condition_id"]), "Independent prediction/control scores")
            correct += label == group["condition_id"]
            constant += group["condition_id"] == "nominal"
            swapped += reversed_label == group["condition_id"]
    require((evaluation["correct"], evaluation["constant_nominal_correct"], evaluation["swapped_association_correct"], evaluation["denominator"])
        == (correct, constant, swapped, 8), "Independent score denominator")


def verify_record(path, evidence_root, core, baseline):
    record = read(path)
    require(record["schema_version"] == "locolemotion_first_response_repertoire_closure_v1"
        and record["status"] == "complete_development_context_and_feedback_fit"
        and record["ledger_scope"] == declaration()["ledger_scope"]
        and record["worlds_opened"] == 0 and record["training_groups"] == 8
        and record["source_trials"] == 32 and record["fitted_episodes"] == 24
        and record["runtime_selection_implemented"] is False and record["control_authority"] is False
        and record["adaptation_benefit"] is False and record["population_inference"] is False
        and record["qualification_or_release_authority"] is False, "Feedback closure identity/scope")
    require(record["parent_closure_sha256"] == PARENT_SHA
        and record["reader_sha256"] == sha(Path(__file__)), "Feedback closure parent/reader binding")
    root = evidence_root.resolve(strict=True)
    attempt = (root/record["attempt_id"]).resolve(strict=True)
    require(attempt.parent == root, "Feedback closure attempt path")
    paths = []
    for item in record["artifacts"]:
        target = (root/item["evidence_relative_path"]).resolve(strict=True)
        require(target.is_relative_to(attempt) and target.is_file()
            and target.stat().st_size == item["byte_length"] and sha(target) == item["sha256"], "Feedback closure retained artifact changed")
        paths.append(target)
    require(len(paths) == len(set(paths)) == record["artifact_count"]
        and set(paths) == {p.resolve() for p in attempt.rglob("*") if p.is_file()}, "Feedback closure inventory")
    require(set(record["tested_sources"]) == set(TESTED), "Feedback closure tested source inventory")
    for name,digest in record["tested_sources"].items():
        require(sha(ROOT/name) == digest and sha(attempt/"tested-source"/name) == digest, "Feedback closure tested source changed")
    log = (attempt/"tests/stderr.log").read_text()
    require(re.findall(r"(?m)^Ran ([0-9]+) tests? in ", log) == ["10"] and log.rstrip().endswith("OK"), "Feedback closure controls incomplete")
    receipt, declared = read(attempt/"receipt.json"), read(attempt/"declaration.json")
    require(receipt["ok"] is True and receipt["worlds_opened"] == declared["worlds_opened"] == 0
        and receipt["source_commit"] == declared["source_commit"] == record["source_commit"]
        and receipt["binding"] == declared["binding"] and declared["expected_tests"] == 10
        and receipt["tested_sources"] == declared["tested_sources"] == record["tested_sources"]
        and declared["contract"] == declaration(), "Feedback closure execution binding")
    retained = read(attempt/"tested-training-analysis.json")
    require(retained == record["result"] and sha(attempt/"tested-training-analysis.json") == receipt["analysis_sha256"],
        "Feedback closure retained result changed")
    check_evaluation(retained)
    require(run(evidence_root, core, baseline) == retained, "Feedback closure regenerated analysis differs")
    require(receipt["model_sha256"] == retained["model_sha256"]
        and receipt["cases"] == len(retained["model"]["ordered_cases"]), "Feedback closure fitted model binding")
    return dict(ok=True, worlds_opened=0, training_groups=8, source_trials=32, fitted_episodes=24,
        eligible_fitted_episodes=sum(e["outcome"] == "positive" for e in retained["corpus"]["episodes"]),
        failed_fitted_episodes=sum(e["outcome"] == "negative" for e in retained["corpus"]["episodes"]),
        fitted_cases=len(retained["model"]["ordered_cases"]), model_sha256=retained["model_sha256"],
        internal_correct=retained["evaluation"]["correct"], denominator=8,
        constant_nominal_correct=retained["evaluation"]["constant_nominal_correct"],
        synthetic_swapped_association_correct=retained["evaluation"]["swapped_association_correct"],
        parent_artifacts_verified=retained["parent_artifacts_verified"], artifact_count=len(paths),
        runtime_selection_implemented=False, adaptation_benefit=False, qualification_or_release_authority=False)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--record", type=Path, default=RECORD)
    parser.add_argument("--evidence-root", type=Path, default=ROOT.parent/"SporeSpore_Evidence")
    parser.add_argument("--core", type=Path, required=True)
    parser.add_argument("--baseline-core", type=Path, required=True)
    args = parser.parse_args()
    print(json.dumps(verify_record(args.record, args.evidence_root, args.core, args.baseline_core), indent=2))
