"""Fixed matched diagnostic; no fitting, selection or predecessor regrading."""
import copy
import json

from motor_effectiveness_task import ROOT, HERE, FLAGS, sha, declaration as parent_declaration
from adaptation_provider.retrieval.flat_v2 import require

CONTRACT = HERE / "gpu_motor_batch_diagnostic_v1.json"


def declaration():
    d = json.loads(CONTRACT.read_text(encoding="utf-8"))
    require(d["schema_version"] == "locolemotion_gpu_motor_batch_diagnostic_v1"
        and d["parent_contract"] == dict(path="sdk/discovery/gpu_motor_effectiveness_v1.json",
            sha256=sha(HERE / "gpu_motor_effectiveness_v1.json"))
        and d["condition_id"] == "left_075" and d["seed"] == 104231700
        and d["outer_steps"] == 480 and d["planned_worlds"] == 48
        and d["focus_action_index"] == 6 and d["focus_cell"] == 1
        and d["starts"] == [dict(id="start_002", lateral_velocity_m_s=.002),
            dict(id="start_0035", lateral_velocity_m_s=.0035)]
        and d["layouts"] == [dict(id="mixed_nine", actions=[0, 6, 1, 2, 3, 4, 5, 7, 8]),
            dict(id="repeated_nine", actions=[0, 6, 6]*3),
            dict(id="narrow_three", actions=[0, 6, 6]), dict(id="repeat_three", actions=[0, 6, 6])]
        and all(d[k] is False for k in FLAGS), "Matched diagnostic declaration")
    # All dynamics, capture, profile limits and eligibility bounds are inherited
    # without mutation. The new declaration owns only this fresh population.
    c = copy.deepcopy(parent_declaration())
    c.update(schema_version=d["schema_version"], ledger_scope=d["ledger_scope"], diagnostic=d,
        seed=d["seed"], purpose=d["purpose"], initialization=d["purpose"],
        training_scope="diagnostic_only", corpus="No fitting or selection authority.",
        coverage=d["coverage"], not_covered=d["not_covered"],
        maximum_worker_wall_seconds=d["maximum_worker_wall_seconds"],
        **{k: False for k in FLAGS})
    return c


def trial_plan(c):
    d = c["diagnostic"]
    plans = []
    for layout in d["layouts"]:
        for start in d["starts"]:
            identity = layout["id"] + "_" + start["id"]
            actions = list(layout["actions"])
            plans.append(dict(trial_id=identity, group_id=identity,
                partition="development_diagnostic", condition_id=d["condition_id"],
                layout=layout["id"], start_id=start["id"], source_start_family="previously_exposed_"+start["id"],
                seed=d["seed"], initial_native_roll_rad=0.,
                initial_native_lateral_velocity_m_s=start["lateral_velocity_m_s"],
                nworld=len(actions), arm="batch_graph", candidate_indices=actions,
                role_order=["diagnostic_cell_"+str(i) for i in range(len(actions))],
                training_data_authority=False))
    return plans


def comparison_pairs(c):
    """Predeclare both cells: outcome inspection cannot pick a favorable slot."""
    pairs = []
    for start in c["diagnostic"]["starts"]:
        suffix = "_"+start["id"]
        for name, a, b in [("batch_width", "repeated_nine", "narrow_three"),
                           ("neighbor_composition", "mixed_nine", "repeated_nine"),
                           ("fresh_repeat", "narrow_three", "repeat_three")]:
            pairs.append(dict(kind=name, left=a+suffix, left_cell=1, right=b+suffix, right_cell=1))
        for layout in ["narrow_three", "repeat_three", "repeated_nine"]:
            pairs.append(dict(kind="within_batch_duplicate", left=layout+suffix, left_cell=1,
                right=layout+suffix, right_cell=2))
    for layout in c["diagnostic"]["layouts"]:
        pairs.append(dict(kind="start_state", left=layout["id"]+"_start_002", left_cell=1,
            right=layout["id"]+"_start_0035", right_cell=1))
    return pairs
