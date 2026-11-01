"""Fresh capture-projection question after v1 failed cross-run byte identity.

Exactness applies to a record and its own native samples. Separate GPU trials
are retained observations, not a bitwise replay or equivalence experiment.
"""
import copy
import json

import population_discovery_task_v1 as previous
from population_discovery_task_v1 import ROOT, HERE, FLAGS, LiveBlock, summarize, select, plans, require, sha, f32

CONTRACT = HERE / "population_discovery_v2.json"
PARENT = previous.CONTRACT
PARENT_SHA = "8a0246de51a8970802430052fd600a55bb97e52f3c4cd0f15c6dcf569f7008fd"
FAILURE = HERE / "population_discovery_native_failure_v1.json"
FAILURE_SHA = "500a8921c905a6fc592e0f451dacbcd55915df74c7ff2f0e2fa28a53c4f8b3ec"
SOURCES = ["population_discovery_task_v2.py", "population_discovery_v2.py",
    "audit_population_discovery_v2.py", "run_population_discovery_v2.py", "test_population_discovery_v2.py"]
GATES = [*previous.GATES, ("projection-successor", "test_population_discovery_v2", 8)]


def expected_declaration():
    d = copy.deepcopy(previous.expected_declaration())
    d.update(schema_version="locolemotion_population_discovery_v2",
        predecessor=dict(path=FAILURE.relative_to(ROOT).as_posix(), sha256=FAILURE_SHA),
        parent=dict(path=PARENT.relative_to(ROOT).as_posix(), sha256=PARENT_SHA),
        safety_controls=[dict(name=n, module=m, count=k) for n, m, k in GATES],
        safety_control_count=sum(k for _, _, k in GATES),
        successor_change="Validate compact fields against their own raw native samples; separate fresh runs are descriptive observations and never a bitwise replay claim",
        cross_run_equivalence_claim=False,
        former_attempt_reinterpreted=False)
    d["canaries"].update(compact_records_must_match_bitwise=False,
        within_run_projection_must_match_exactly=True,
        independent_full_scalar_replay_required=True,
        between_run_differences="report exact hash agreement and episode outcomes without an acceptance threshold or equivalence authority")
    d["coverage"] = [s.replace("two predetermined full/compact pairs", "two predetermined full/compact pairs with descriptive repeat differences") for s in d["coverage"]]
    d["not_covered"].extend(["bitwise repetition across fresh GPU worlds", "causal attribution of cross-run numerical differences"])
    return d


def declaration():
    d = json.loads(CONTRACT.read_text(encoding="utf-8"))
    require(d == expected_declaration() and sha(PARENT) == PARENT_SHA and sha(FAILURE) == FAILURE_SHA,
        "Projection successor declaration or preserved failure")
    failure = json.loads(FAILURE.read_text(encoding="utf-8"))
    require(failure["canary_reader_ok"] is False and failure["population_worlds_opened"] == 0
        and failure["constructed_gpu_worlds"] == 16 and failure["all_outer_cleanup_verified"] is True,
        "Projection successor predecessor scope")
    c = previous.declaration()
    c.update(schema_version=d["schema_version"], challenge=d, ledger_scope=d["ledger_scope"],
        purpose=d["scope"], **{key: False for key in FLAGS})
    return c
