"""Fresh finite CPU challenge; no fitting, selection or equivalence authority."""
import copy
import json
import numpy as np
from motor_effectiveness_task import ROOT, HERE, FLAGS, sha, declaration as parent_declaration
from adaptation_provider.retrieval.flat_v2 import require

CONTRACT = HERE/"cpu_motor_challenge_v1.json"


def declaration():
    d = json.loads(CONTRACT.read_text(encoding="utf-8"))
    require(d["schema_version"] == "locolemotion_cpu_motor_challenge_v1"
        and d["condition_id"] == "left_075" and d["seed"] == 104231900
        and d["outer_steps"] == 480 and d["planned_cpu_worlds"] == 4
        and d["starts"] == [dict(id="start_002", lateral_velocity_m_s=.002),
            dict(id="start_0035", lateral_velocity_m_s=.0035)]
        and d["roles"] == [dict(id="baseline", action_index=0), dict(id="selected_profile", action_index=6)]
        and d["initial_values"] == "float32_equalized_inputs_then_native_float64_cpu_dynamics"
        and all(d[k] is False for k in FLAGS), "CPU challenge declaration")
    for key, name in [("parent_contract", "gpu_motor_effectiveness_v1.json"),
                      ("gpu_predecessor", "gpu_motor_batch_closure_v1.json")]:
        require(d[key] == dict(path="sdk/discovery/"+name, sha256=sha(HERE/name)), "CPU lineage binding")
    c = copy.deepcopy(parent_declaration())
    c.update(schema_version=d["schema_version"], ledger_scope=d["ledger_scope"], challenge=d,
        seed=d["seed"], purpose=d["purpose"], initialization=d["initial_values"],
        sampling="Native CPU step1, prepared observations, held target, step2, immediate force/contact/state capture before the next prepare. No state edits after initialization.",
        training_scope="diagnostic_only", corpus="No fitting or selection authority.",
        coverage=d["coverage"], not_covered=d["not_covered"],
        maximum_worker_wall_seconds=d["maximum_worker_wall_seconds"],
        naconmax=64, **{k: False for k in FLAGS})
    return c


def trial_plan(c):
    d = c["challenge"]
    return [dict(trial_id=start["id"]+"_"+role["id"], group_id=start["id"]+"_"+role["id"],
        partition="development_cpu_diagnostic", condition_id="left_075", start_id=start["id"], role=role["id"],
        seed=d["seed"], nworld=1, arm="scalar_direct", candidate_indices=[role["action_index"]],
        role_order=[role["id"]], initial_native_roll_rad=0.,
        initial_native_lateral_velocity_m_s=start["lateral_velocity_m_s"], training_data_authority=False)
        for start in d["starts"] for role in d["roles"]]


def initial_arrays(spec, plan):
    # Equal initial values do not imply equal dynamics: CPU remains float64.
    positions = np.asarray(spec["initial_qpos"], np.float32).astype(np.float64)
    positions[3:7] = [1., 0., 0., 0.]
    velocities = np.zeros(14, np.float64)
    velocities[1] = float(np.float32(plan["initial_native_lateral_velocity_m_s"]))
    return positions, velocities
