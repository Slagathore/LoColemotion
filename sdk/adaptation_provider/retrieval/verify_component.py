"""Reopen the synthetic fitted-model and episode-memory component evidence."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import sys
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[3]
sys.path[:0] = [str(ROOT / "sdk"), str(ROOT / "sdk/python"), str(ROOT / "sdk/discovery")]
import mujoco
from sporespore_locomotion import LocomotionCore
from audit_gpu_batch_execution import same_bits
from adaptation_provider.retrieval import learner


def sha(path):
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def verify(path, evidence_root, core_path):
    record = json.loads(path.read_text(encoding="utf-8"))
    require = learner.require
    require(record["schema_version"] == "locolemotion_retrieval_component_v1" and record["synthetic"] is True
            and record["world_build_count"] == 0 and all(record[k] is False for k in [
                "native_experience_used", "physical_acceptance_authority", "release_authority", "training_data_authority"]),
            "Component identity/authority")
    root = evidence_root.resolve(strict=True)
    attempt = (root / record["attempt_id"]).resolve(strict=True)
    require(attempt.parent == root and attempt.name == record["attempt_id"], "Component evidence root")
    indexed = set()
    for entry in record["artifacts"]:
        target = (root / entry["evidence_relative_path"]).resolve(strict=True)
        require(target.is_relative_to(attempt) and target not in indexed and target.is_file(), "Crossed/repeated artifact")
        require(target.stat().st_size == entry["byte_length"] and sha(target) == entry["sha256"], "Changed retained artifact")
        indexed.add(target)
    require(len(indexed) == record["artifact_count"]
            and indexed == {p.resolve() for p in attempt.rglob("*") if p.is_file()}, "Incomplete artifact inventory")
    for name, digest in record["source_bindings"].items():
        source = (ROOT / name).resolve(strict=True)
        require(source.is_relative_to(ROOT) and sha(source) == digest, "Component source differs")
    require(sha(core_path) == record["core_sha256"], "Core binding")
    initial = json.loads((attempt / "tests-01/receipt.json").read_text())
    require(initial["exit_code"] != 0 and initial["world_build_count"] == 0
            and "IDENTITY_INVALID:adaptation_provider_request.expected_provider_version:bounded_retrieval_v1:" in
                (attempt / "tests-01/stderr.log").read_text(), "Original identifier refusal changed")
    successful = json.loads((attempt / "tests-03/receipt.json").read_text())
    log = (attempt / "tests-03/stderr.log").read_text()
    require(successful["exit_code"] == 0 and successful["world_build_count"] == 0
            and re.findall(r"(?m)^Ran ([0-9]+) tests? in ", log) == [str(record["tests_passed"])]
            and log.strip().endswith("OK"), "Successful test receipt")
    fixture = (root / record["fixture_directory"]).resolve(strict=True)
    require(fixture.is_relative_to(attempt / "tests-03"), "Crossed fixture directory")
    core = LocomotionCore(core_path)
    model_binding = json.loads((fixture / "model-binding.json").read_text())
    episodes = json.loads((fixture / "synthetic-episodes.json").read_text())
    model_document = json.loads((fixture / "synthetic-model.json").read_text())
    counts = {mode: 0 for mode in ["frozen", "episodic", "episodic_shuffled"]}
    previous = {}
    choices = {}
    with patch.object(mujoco, "MjModel", side_effect=AssertionError("Component audit world")), \
            patch.object(mujoco, "MjData", side_effect=AssertionError("Component audit data")), \
            patch.object(mujoco, "mj_step", side_effect=AssertionError("Component audit physics")):
        model = learner.fit(core, episodes, **model_binding["corpus"])
        require(same_bits(model.document(), model_document)
                and model.sha256 == model_binding["model_sha256"] == record["synthetic_model_sha256"], "Fitted artifact differs")
        with (fixture / "synthetic-episode-decisions.jsonl").open() as stream:
            for index, line in enumerate(stream):
                row = json.loads(line)
                mode = ["frozen", "episodic", "episodic_shuffled"][index // 61] if index < 183 else None
                step = index % 61
                require((row["mode"], row["step"]) == (mode, step), "Decision population/order")
                request = row["request"]
                require(request["state"]["semantic_step"] == step, "Request step join")
                if step:
                    require(same_bits(request["provider_memory"], previous[mode]["next_memory"]), "Episode memory continuity")
                    require([x["previous_applied_correction_rad_s"] for x in request["safety_envelope"]["ordered_actuator_limits"]]
                            == [x["applied_correction_rad_s"] for x in previous[mode]["ordered_commands"]], "Correction continuity")
                response = learner.respond(core, request, model, mode)
                require(same_bits(response, row["response"]), "Provider decision replay differs")
                resolution = core.resolve_adaptation_v1(dict(schema_version="sporespore_adaptation_resolution_request_v1",
                    provider_request=request, provider_response=response))
                require(same_bits(resolution, row["resolution"]), "Core resolution replay differs")
                previous[mode] = resolution
                counts[mode] += 1
                if step in [0, 30, 60]:
                    choices[mode + "_" + str(step)] = next(x for x in response["diagnostics"] if x.startswith("selected_action:"))
        require(counts == {mode: 61 for mode in counts} and learner.digest(core, model.document()) == model.sha256,
                "Incomplete decision denominator or base mutation")
    require(len(episodes) == record["synthetic_episode_count"] == 36
            and len(model.cases) == record["synthetic_case_count"] == 560
            and choices["frozen_0"] == choices["frozen_30"]
            and choices["episodic_0"] != choices["episodic_30"]
            and choices["episodic_shuffled_0"] == choices["episodic_shuffled_30"], "Synthetic outcome/control result")
    return dict(ok=True, synthetic=True, artifacts=len(indexed), sources=len(record["source_bindings"]),
        fitted_model_sha256=model.sha256, replayed_decisions=sum(counts.values()), choices=choices,
        original_identifier_refusal_preserved=True, world_build_count=0, native_experience_used=False,
        physical_acceptance_authority=False, release_authority=False, training_data_authority=False)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--record", type=Path, default=Path(__file__).with_name("component_v1.json"))
    parser.add_argument("--evidence-root", type=Path, default=ROOT.parent / "SporeSpore_Evidence")
    parser.add_argument("--core", type=Path, required=True)
    args = parser.parse_args()
    print(json.dumps(verify(args.record, args.evidence_root, args.core), indent=2))
