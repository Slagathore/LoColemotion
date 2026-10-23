"""Prospective physical-context task and finite condition-known profile selection.

Derating scales both velocity-servo gain and actuator force limits. Morphology,
target units, transmission and every undeclared XML attribute remain unchanged.
This is a distinct development environment, not the nominal qualified profile.
"""
import copy
import hashlib
import json
import math
from pathlib import Path
import statistics
import sys
import xml.etree.ElementTree as ET

import numpy as np

from gpu_quadruped_model import ROOT, FLAGS, sha, build_inputs
from portable_search_control import bridge, S169
sys.path.insert(0, str(ROOT / "sdk"))
from adaptation_provider.retrieval import flat_v2 as learner

HERE = Path(__file__).resolve().parent
CONTRACT = HERE/"gpu_motor_effectiveness_v1.json"
CONDITIONS = [dict(condition_id="nominal", side="none", effectiveness=1.),
    dict(condition_id="left_090", side="left", effectiveness=.9),
    dict(condition_id="right_090", side="right", effectiveness=.9),
    dict(condition_id="left_075", side="left", effectiveness=.75),
    dict(condition_id="right_075", side="right", effectiveness=.75)]


def declaration():
    c = json.loads(CONTRACT.read_text(encoding="utf-8"))
    expected = [dict(id=a["action_id"], factor=None if i == 0 else 0., ordered_coefficients=a["ordered_coefficients"])
        for i, a in enumerate(learner.contract()["actions"])]
    learner.require(c["schema_version"] == "locolemotion_gpu_motor_effectiveness_v1"
        and c["conditions"] == CONDITIONS and c["provider"]["candidates"] == expected
        and c["outer_steps"] == 480 and c["internal_steps_per_outer"] == 5 and c["warmup_outer_steps"] == 0
        and c["provider"]["maximum_absolute_correction_rad_s"] == .25
        and c["provider"]["maximum_slew_per_step_rad_s"] == .02
        and c["retrieval_contract_sha256"] == sha(learner.CONTRACT)
        and c["training_data_authority"] is True and c["training_scope"] == "development_discovery_only"
        and all(c[k] is False for k in FLAGS if k != "training_data_authority")
        and c["discovery_starts"] == [dict(source_group="train_0", lateral_velocity_m_s=.002),
            dict(source_group="train_3", lateral_velocity_m_s=.005)]
        and c["confirmation_starts"] == [dict(source_group="calibration_1", lateral_velocity_m_s=.0035),
            dict(source_group="calibration_2", lateral_velocity_m_s=.0045)]
        and c["comparison"] == dict(minimum_gain_m_s=.001, maximum_individual_loss_m_s=.001,
            discovery_selector="eligible_in_every_required_start_then_highest_mean_quality_then_smallest_action_index",
            primary_conditioning_population="eight_degraded_confirmation_pairs",
            healthy_guard_population="two_nominal_confirmation_pairs", population_inference=False),
        "Motor-effectiveness declaration")
    learner.require(set(c["condition_model_sha256"]) == {r["condition_id"] for r in CONDITIONS}
        and all(len(h) == 64 and all(ch in "0123456789abcdef" for ch in h) for h in c["condition_model_sha256"].values()),
        "Prospective condition model bindings")
    return c


def condition_inputs(core_path, c, condition_id):
    condition = next((r for r in c["conditions"] if r["condition_id"] == condition_id), None)
    learner.require(condition is not None, "Unknown motor condition")
    compiled, xml, spec = build_inputs(core_path, c)
    learner.require(hashlib.sha256(xml.encode()).hexdigest() == c["model_xml_sha256"], "Nominal source XML changed")
    tree = ET.fromstring(xml)
    tree.set("model", "sdk2_motor_effectiveness_v1_"+condition_id)
    motors = list(tree.findall("actuator/velocity"))
    nominal = copy.deepcopy(spec["force_ranges"])
    gains, forces, factors = [], [], []
    for motor, bounds in zip(motors, nominal, strict=True):
        affected = condition["side"] != "none" and "_"+condition["side"]+"_" in motor.attrib["name"]
        factor = condition["effectiveness"] if affected else 1.
        gain = float(motor.attrib["kv"])*factor
        limits = [x*factor for x in bounds]
        motor.set("kv", format(gain, ".17g"))
        motor.set("forcerange", " ".join(format(x, ".17g") for x in limits))
        gains.append(gain); forces.append(limits); factors.append(factor)
    spec.update(initial_lateral_velocities=[], motor_condition=copy.deepcopy(condition),
        nominal_force_ranges=nominal, force_ranges=forces, velocity_gains=gains, effectiveness_factors=factors)
    return compiled, ET.tostring(tree, encoding="unicode")+"\n", spec


def expected_actuator_arrays(spec):
    return dict(gainprm=[[v]+[0.]*9 for v in spec["velocity_gains"]],
        biasprm=[[0., 0., -v]+[0.]*7 for v in spec["velocity_gains"]],
        forcerange=spec["force_ranges"], gear=[[1.]+[0.]*5 for _ in range(8)],
        forcelimited=[True]*8, ctrllimited=[False]*8, gaintype=[0]*8,
        biastype=[1]*8, dyntype=[0]*8, trntype=[0]*8, trnid=[[i+1, -1] for i in range(8)])


def validate_native_profile(model, spec):
    learner.require((model.nq, model.nv, model.nu, model.nbody, model.ngeom, model.njnt, model.nsensordata)
        == (15, 14, 8, 10, 10, 9, 16)
        and float(model.opt.timestep) == bridge.INTERNAL_DT_S
        and int(model.opt.integrator) == int(bridge.mujoco.mjtIntegrator.mjINT_IMPLICITFAST), "Condition native topology/integrator")
    actual = {name: getattr(model, "actuator_"+name).tolist() for name in expected_actuator_arrays(spec)}
    learner.require(actual == expected_actuator_arrays(spec), "Condition native actuator identity")
    learner.require([model.actuator(i).name for i in range(8)] == spec["ordered_actuators"]
        and [model.joint(i+1).name for i in range(8)] == spec["ordered_joints"], "Condition native named transmission")
    return actual


def validate_gpu_profile(wm, spec):
    expected = expected_actuator_arrays(spec)
    actual = {}
    for key in ["gainprm", "biasprm", "forcerange"]:
        value = getattr(wm, "actuator_"+key).numpy()
        learner.require(value.dtype == np.float32 and value.shape == (1, *np.asarray(expected[key]).shape)
            and np.array_equal(value[0], np.asarray(expected[key], dtype=np.float32)), "Condition GPU actuator identity")
        actual[key] = value.tolist()
    return actual


class ConditionRobot(bridge.MujocoBw19vRobot):
    def _validate_model_identity(self):
        validate_native_profile(self.model, self.condition_spec)


def condition_robot_view(core, compiled, model, data, spec):
    robot = object.__new__(ConditionRobot)
    robot.core = core
    robot.profile_id = bridge.PER_ACTUATOR_DEVELOPMENT_PROFILE_ID
    robot.descriptor = dict(S169)
    robot.compiled = compiled
    robot.morphology = compiled["morphology"]
    robot.spec = robot.morphology["morphology_spec"]
    robot.condition_spec = copy.deepcopy(spec)
    robot.model, robot.data = model, data
    robot.ground_geom_id = model.geom("ground").id
    robot.body_geom_ids = {k: model.geom(k+"_geom").id for k in robot.morphology["ordered_body_ids"]}
    robot.joint_ids = {k: model.joint(k).id for k in robot.morphology["ordered_joint_ids"]}
    robot.actuator_ids = {k: model.actuator(k).id for k in robot.morphology["ordered_actuator_ids"]}
    robot.actuator_specs = {r["actuator_id"]: r for r in robot.spec["actuators"]}
    robot.contact_sites = {r["contact_site_id"]: r for r in robot.spec["contact_sites"]}
    robot.limbs = {r["limb_id"]: r for r in robot.spec["limbs"]}
    robot._validate_model_identity()
    return robot


def trial_plan(c, phase, selection=None):
    learner.require(phase in ("discovery", "confirmation"), "Motor phase")
    learner.require((selection is None) == (phase == "discovery"), "Motor selection phase")
    plans = []
    for condition_index, condition in enumerate(c["conditions"]):
        cid = condition["condition_id"]
        for group_index, start in enumerate(c[phase+"_starts"]):
            if phase == "discovery":
                roles = ["action_"+str(i) for i in range(9)]
                actions = list(range(9))
            else:
                roles = ["baseline", "condition_known", "shared_profile"]
                actions = [0, selection["conditions"][cid]["executed_action_index"], selection["shared"]["executed_action_index"]]
            offset = (condition_index+group_index) % len(roles)
            roles, actions = roles[offset:]+roles[:offset], actions[offset:]+actions[:offset]
            group = phase+"_"+cid+"_"+str(group_index)
            plans.append(dict(trial_id=group, group_id=group, partition="development_"+phase,
                condition_id=cid, source_start_family=start["source_group"],
                seed=104231100+(100 if phase == "confirmation" else 0)+2*condition_index+group_index,
                initial_native_roll_rad=0., initial_native_lateral_velocity_m_s=start["lateral_velocity_m_s"],
                nworld=len(actions), arm="batch_graph", candidate_indices=actions, role_order=roles,
                training_data_authority=phase == "discovery" and not c.get("synthetic", False)))
    return plans


def select_profiles(discovery, c):
    """Freeze a finite shortlist using discovery only, never confirmation outcomes."""
    learner.require(discovery["ok"] is True and discovery["phase"] == "discovery"
        and type(discovery["synthetic"]) is bool and discovery["reader_world_build_count"] == 0,
        "Selection requires complete discovery reader")
    plans = trial_plan(c, "discovery")
    learner.require(len(discovery["trials"]) == len(plans), "Selection trial denominator")
    by_condition = {r["condition_id"]: [[] for _ in range(9)] for r in c["conditions"]}
    for plan, result in zip(plans, discovery["trials"], strict=True):
        learner.require(all(result[k] == v for k, v in plan.items()) and len(result["episodes"]) == 9,
            "Selection crossed phase/group")
        for action, episode in zip(plan["candidate_indices"], result["episodes"], strict=True):
            learner.require(episode["action_id"] == c["provider"]["candidates"][action]["id"]
                and episode["group_id"] == plan["group_id"] and episode["synthetic"] is discovery["synthetic"]
                and episode["outcome"] in ("positive", "negative")
                and learner.finite(episode["metrics"]["quality_m_s"]), "Selection action/outcome binding")
            by_condition[plan["condition_id"]][action].append(episode)

    def choose(population, expected):
        summaries = []
        for action, episodes in enumerate(population):
            learner.require(len(episodes) == expected, "Selection episode denominator")
            eligible = all(e["outcome"] == "positive" for e in episodes)
            summaries.append(dict(action_index=action, eligible=eligible, episode_count=expected,
                mean_quality_m_s=statistics.mean(e["metrics"]["quality_m_s"] for e in episodes) if eligible else None))
        supported = [r for r in summaries if r["eligible"]]
        selected = min(supported, key=lambda r: (-r["mean_quality_m_s"], r["action_index"]))["action_index"] if supported else None
        return dict(selected_action_index=selected, executed_action_index=0 if selected is None else selected,
            reason="no_eligible_profile_baseline_diagnostic_only" if selected is None else "discovery_mean_quality",
            action_summaries=summaries)

    pooled = [[episode for population in by_condition.values() for episode in population[action]] for action in range(9)]
    return dict(schema_version="locolemotion_motor_profile_selection_v1", synthetic=discovery["synthetic"],
        ledger_scope=c["ledger_scope"], conditions={key: choose(value, 2) for key, value in by_condition.items()},
        shared=choose(pooled, 10), selection_source="development_discovery_only", confirmation_outcomes_used=False,
        known_condition_oracle_scope="nine_constant_bounded_residual_profiles_only",
        physical_acceptance_authority=False, release_authority=False, statistical_superiority_authority=False)
