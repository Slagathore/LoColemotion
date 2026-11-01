"""Descriptor-aware creature inputs and scalar/batch public controller execution.

This shared development component compiles XML without constructing a world.
Native callers must verify that their model and observations match each binding;
a matching label alone is not evidence of native morphology coverage.
"""
import copy
from dataclasses import asdict
import hashlib
import math
import re
from types import SimpleNamespace
import xml.etree.ElementTree as ET

from portable_search_control import (
    EMPTY_CORPUS, bridge, initial_memory, map_resolution, proposal_request,
)
from portable_batch_control import CanonicalCache, pure_batch, values
from showcase_model import FIELDS, validate_descriptor

PROVIDER_ID = "bounded_creature_search"
PROVIDER_VERSION = "untrained_joint_profile_v1"
MODEL_KIND = "bounded_quadruped_joint_profile_v1"
MAXIMUM_CORRECTION = .25
MAXIMUM_SLEW = .02


def require(ok, message):
    if not ok:
        raise ValueError(message)


def identifier(value):
    return isinstance(value, str) and re.fullmatch(r"[a-z][a-z0-9_]{0,95}", value) is not None


def profile(value):
    require(type(value) is dict and set(value) == {"id", "factor", "ordered_coefficients"},
            "Creature profile fields")
    require(identifier(value["id"]), "Creature profile identity")
    coefficients = value["ordered_coefficients"]
    require(type(coefficients) is list and len(coefficients) == 8
            and all(type(v) in (int, float) and math.isfinite(v) and -.25 <= v <= .25
                    for v in coefficients), "Creature coefficient bounds")
    factor = value["factor"]
    require(factor is None or type(factor) in (int, float) and factor == 0.,
            "Creature profile mode")
    require(factor is not None or coefficients == [0.] * 8, "Absent-provider profile must be zero")
    return copy.deepcopy(value)


def compile_creature(core, descriptor, motor_effectiveness=None):
    """Use the real public compiler and existing native XML builder, zero worlds."""
    descriptor = copy.deepcopy(validate_descriptor(descriptor))
    factors = [1.] * 8 if motor_effectiveness is None else copy.deepcopy(motor_effectiveness)
    require(type(factors) is list and len(factors) == 8
            and all(type(v) in (int, float) and math.isfinite(v) and .5 <= v <= 1.
                    for v in factors), "Creature motor effectiveness bounds")
    compiled = core.compile_bounded_quadruped(descriptor)
    require(compiled["descriptor"] == descriptor and compiled["world_build_count"] == 0
            and compiled["physical_acceptance_authority"] is False, "Creature compiler identity")
    morphology = compiled["morphology"]
    require(morphology["world_build_count"] == 0, "Morphology compiler constructed a world")
    tree = ET.fromstring(bridge.build_model_xml(compiled, bridge.PER_ACTUATOR_DEVELOPMENT_PROFILE_ID))
    tree.set("model", "locolemotion_bounded_creature")
    motors = tree.findall("actuator/velocity")
    joints = tree.findall(".//joint")
    require(len(tree.findall(".//body")) == 9 and len(tree.findall(".//freejoint")) == 1
            and len(motors) == len(joints) == 8, "Creature topology")
    require([m.attrib["name"] for m in motors] == morphology["ordered_actuator_ids"]
            and [j.attrib["name"] for j in joints] == morphology["ordered_joint_ids"]
            and [m.attrib["joint"] for m in motors] == morphology["ordered_joint_ids"],
            "Creature actuator/joint ordering")
    sensor = ET.SubElement(tree, "sensor")
    nominal, forces, gains = [], [], []
    for motor, factor in zip(motors, factors, strict=True):
        bounds = [float(x) for x in motor.attrib["forcerange"].split()]
        force = [v * factor for v in bounds]
        gain = float(motor.attrib["kv"]) * factor
        motor.set("forcerange", " ".join(format(v, ".17g") for v in force))
        motor.set("kv", format(gain, ".17g"))
        nominal.append(bounds); forces.append(force); gains.append(gain)
        ET.SubElement(sensor, "actuatorfrc", name=motor.attrib["name"] + "_force", actuator=motor.attrib["name"])
        ET.SubElement(sensor, "jointactuatorfrc", name=motor.attrib["joint"] + "_actuator_force", joint=motor.attrib["joint"])
    xml = ET.tostring(tree, encoding="unicode") + "\n"
    spec = dict(initial_qpos=[float(x) for x in tree.find("worldbody/body").attrib["pos"].split()]
                + [1., 0., 0., 0.] + [0.] * 8,
        ordered_actuators=list(morphology["ordered_actuator_ids"]),
        ordered_joints=list(morphology["ordered_joint_ids"]),
        geom_names=[g.attrib["name"] for g in tree.findall(".//geom")],
        nominal_force_ranges=nominal, force_ranges=forces, velocity_gains=gains,
        effectiveness_factors=factors)
    binding = dict(schema_version="locolemotion_creature_binding_v1",
        descriptor_sha256=compiled["descriptor_sha256"],
        # An alias is not a new shape; policy replicas may intentionally share this key.
        body_shape_sha256=core.canonicalize_json({key: descriptor[key] for key in FIELDS})["sha256"],
        morphology_spec_sha256=morphology["morphology_spec_sha256"],
        compiled_sha256=core.canonicalize_json(compiled)["sha256"],
        model_xml_sha256=hashlib.sha256(xml.encode()).hexdigest(),
        inputs_sha256=core.canonicalize_json(spec)["sha256"],
        world_build_count=0, physical_acceptance_authority=False)
    return dict(descriptor=descriptor, compiled=compiled, model_xml=xml, spec=spec, binding=binding)


def provider_request(core, cell, request, baseline):
    value = proposal_request(core, cell.contract, cell.candidate, request["state"], request["command"],
        baseline["output"], baseline["composition"]["canonical_actuation"], cell.provider_memory, cell.previous)
    # Bind the new request before hashing or asking the public resolver to use it.
    value.update(descriptor=copy.deepcopy(cell.descriptor), provider_id=PROVIDER_ID,
        expected_provider_version=PROVIDER_VERSION,
        request_id="creature_" + cell.cell_id + "_" + str(request["state"]["semantic_step"]))
    return value


def provider_response(core, request, candidate):
    if candidate["factor"] is None:
        return None
    validate_descriptor(request["descriptor"])
    require(request["provider_id"] == PROVIDER_ID
            and request["expected_provider_version"] == PROVIDER_VERSION, "Creature provider identity")
    memory = copy.deepcopy(request["provider_memory"])
    memory["sequence"] += 1
    return dict(schema_version="sporespore_adaptation_provider_response_v1",
        request_id=request["request_id"], request_sha256=core.canonicalize_json(request)["sha256"],
        status="applied", confidence=1., support_distance=0.,
        ordered_corrections=[dict(actuator_id=row["actuator_id"],
            canonical_velocity_delta_rad_s=k * row["combined_canonical_target_velocity_rad_s"])
            for k, row in zip(candidate["ordered_coefficients"],
                              request["deterministic_baseline"]["ordered_commands"], strict=True)],
        next_memory=memory,
        provenance=dict(provider_id=PROVIDER_ID, provider_version=PROVIDER_VERSION,
            model_id=request["expected_model_id"], model_sha256=request["expected_model_sha256"],
            training_corpus_id=request["expected_training_corpus_id"],
            training_corpus_sha256=request["expected_training_corpus_sha256"], seed=request["seed"],
            engine_specific_logic_used=False, direct_world_access_used=False, weights_mutated=False,
            physical_acceptance_authority=False),
        candidate_experience=None,
        diagnostics=["untrained bounded quadruped action; confidence denotes declared support only"],
        physical_acceptance_authority=False)


class CreatureController:
    """One descriptor/session with explicit, isolated host memory."""

    def __init__(self, core, declaration, *, seed, phase_mode="clocked"):
        require(type(declaration) is dict and set(declaration) in (
            {"cell_id", "descriptor", "profile"},
            {"cell_id", "descriptor", "profile", "motor_effectiveness"}), "Creature cell fields")
        require(identifier(declaration["cell_id"]), "Creature cell identity")
        require(type(seed) is int and 0 <= seed <= 2147483647, "Creature seed")
        require(phase_mode in ("clocked", "contact_gated"), "Creature phase mode")
        self.core, self.cell_id = core, declaration["cell_id"]
        self.candidate = profile(declaration["profile"])
        self.creature = compile_creature(core, declaration["descriptor"], declaration.get("motor_effectiveness"))
        self.descriptor = self.creature["descriptor"]
        self.contract = dict(seed=seed, phase_mode=phase_mode, policy_id=bridge.SELECTED_POLICY_ID,
            provider=dict(kind=MODEL_KIND, maximum_absolute_correction_rad_s=MAXIMUM_CORRECTION,
                          maximum_slew_per_step_rad_s=MAXIMUM_SLEW))
        self.context = SimpleNamespace(core=core, descriptor=self.descriptor,
            morphology=self.creature["compiled"]["morphology"], profile_id=bridge.PER_ACTUATOR_DEVELOPMENT_PROFILE_ID)
        self.memory = core.balanced_wave_initial_memory()
        self.composition_memory = bridge.CompositionMemory()
        self.provider_memory = initial_memory(core)
        self.provider_memory["provider_id"] = PROVIDER_ID
        self.previous = [0.] * 8
        self.session = core.create_balanced_wave_policy_session(bridge.SELECTED_POLICY_ID, self.descriptor)
        self.closed = False

    @property
    def binding(self):
        return dict(copy.deepcopy(self.creature["binding"]), cell_id=self.cell_id,
                    candidate_id=self.candidate["id"])

    def close(self):
        self.session.close()
        self.closed = True

    def check_observation(self, observation):
        require(not self.closed, "Creature controller is closed")
        require(type(observation) is dict and set(observation) == {
            "cell_id", "descriptor_sha256", "model_xml_sha256", "state", "stability", "kinematics"},
            "Creature observation fields")
        binding = self.creature["binding"]
        require(observation["cell_id"] == self.cell_id
                and observation["descriptor_sha256"] == binding["descriptor_sha256"]
                and observation["model_xml_sha256"] == binding["model_xml_sha256"],
                "Crossed creature observation binding")
        return dict(memory=self.memory, state=observation["state"],
            command=bridge._motion_command(observation["state"]["semantic_step"], self.contract["phase_mode"]))

    def commit(self, baseline, resolution):
        self.memory = copy.deepcopy(baseline["output"]["next_memory"])
        self.composition_memory = bridge.CompositionMemory(**copy.deepcopy(baseline["next_composition_memory"]))
        self.provider_memory = copy.deepcopy(resolution["next_memory"])
        self.previous = [row["applied_correction_rad_s"] for row in resolution["ordered_commands"]]

    def record(self, observation, request, baseline, resolution_request, resolution):
        require(resolution["fallback_reason"] in ("none", "provider_absent", "safe_no_actuation"),
                "Unexpected creature provider refusal: " + resolution["fallback_reason"])
        targets = map_resolution(baseline["composition"]["host_mapping"], resolution)
        return dict(binding=self.binding, request=copy.deepcopy(request), output=baseline["output"],
            stability=observation["stability"], kinematics=observation["kinematics"],
            composition=baseline["composition"], resolution_request=resolution_request,
            resolution=resolution, native_targets=targets)

    def step(self, observation):
        request = self.check_observation(observation)
        output = self.session.step(request)
        require(output["actuation"]["receipt"]["controller_error"] is None
                and not output["actuation"]["failure_codes"], "Creature scalar controller refused")
        # The scalar bridge mutates this object. Do not publish it until resolution succeeds.
        memory = copy.deepcopy(self.composition_memory)
        limbs = bridge._ordered_limb_steps(self.memory, self.context.morphology["ordered_limb_ids"])
        composition = bridge.compose_bw19v_step(self.context, output["actuation"],
            observation["stability"], observation["kinematics"], limbs, memory)
        baseline = dict(output=output, composition=composition, next_composition_memory=asdict(memory))
        provider = provider_request(self.core, self, request, baseline)
        resolution_request = dict(schema_version="sporespore_adaptation_resolution_request_v1",
            provider_request=provider, provider_response=provider_response(self.core, provider, self.candidate))
        resolution = self.core.resolve_adaptation_v1(resolution_request)
        record = self.record(observation, request, baseline, resolution_request, resolution)
        self.commit(baseline, resolution)
        return record


class CreatureBatch:
    """Shared mixed-descriptor controller execution; no native world access."""

    def __init__(self, core, declarations, *, seed, phase_mode="clocked"):
        require(type(declarations) is list and 1 <= len(declarations) <= 256, "Creature batch size")
        ids = [row.get("cell_id") for row in declarations if type(row) is dict]
        require(len(ids) == len(declarations) and all(identifier(i) for i in ids)
                and len(set(ids)) == len(ids), "Creature batch identities")
        self.core, self.controllers, self.closed = core, [], False
        try:
            for row in declarations:
                self.controllers.append(CreatureController(core, row, seed=seed, phase_mode=phase_mode))
            models = [dict(kind=MODEL_KIND, candidate=c.candidate, trained=False) for c in self.controllers]
            self.static = CanonicalCache(core, [EMPTY_CORPUS, *models])
        except BaseException:
            self.close()
            raise

    @property
    def bindings(self):
        return [c.binding for c in self.controllers]

    def close(self):
        for cell in self.controllers:
            cell.close()
        self.closed = True

    def step(self, observations):
        require(not self.closed and type(observations) is list
                and len(observations) == len(self.controllers), "Creature batch closed or observation denominator")
        requests = [c.check_observation(o) for c, o in zip(self.controllers, observations, strict=True)]
        ids = [c.cell_id for c in self.controllers]
        calls = [dict(cell_id=c.cell_id, session_handle=c.session.batch_handle, request=dict(
            **request, stability=o["stability"], kinematics=o["kinematics"],
            composition_memory=asdict(c.composition_memory),
            host_profile=bridge._mujoco_host_profile(c.context.profile_id)))
            for c, o, request in zip(self.controllers, observations, requests, strict=True)]
        receipt = self.core.bw19v_composition_batch_v1(calls)
        require(receipt.get("schema_version") == "sporespore_bw19v_composition_batch_receipt_v1",
                "Creature composition batch schema")
        baselines = values(receipt, ids)
        cache = CanonicalCache(self.core, [b["output"]["next_memory"] for b in baselines], self.static)
        providers = [provider_request(cache, c, request, b)
                     for c, request, b in zip(self.controllers, requests, baselines, strict=True)]
        cache = CanonicalCache(self.core, providers, cache)
        resolutions_in = [dict(schema_version="sporespore_adaptation_resolution_request_v1",
            provider_request=p, provider_response=provider_response(cache, p, c.candidate))
            for c, p in zip(self.controllers, providers, strict=True)]
        resolutions = pure_batch(self.core, "resolve_adaptation_v1", resolutions_in)
        records = [c.record(o, request, b, ri, r) for c, o, request, b, ri, r in zip(
            self.controllers, observations, requests, baselines, resolutions_in, resolutions, strict=True)]
        # Failed identities, ABI cells or final mappings leave every host memory unchanged.
        for c, b, r in zip(self.controllers, baselines, resolutions, strict=True):
            c.commit(b, r)
        return records
