"""Complete fixed-topology model transport for mixed-creature native batches.

Every field is checked. Only fields declared per-world by the pinned engine may
differ; native compiled constants are transported alongside primary geometry.
This module does not construct or step native worlds.
"""
import copy
from dataclasses import fields, is_dataclass
import hashlib
import json
import math

import numpy as np
import warp as wp

from creature_batch import require
from motor_effectiveness_task import ConditionRobot, validate_native_profile


def _json(value):
    return json.dumps(value, allow_nan=False, sort_keys=True, separators=(",", ":"))


def _array_record(value, *, logical_shape, batchable):
    data = np.ascontiguousarray(value)
    require(data.dtype.kind in "biuf" and np.all(np.isfinite(data)), "Nonfinite or unsupported model array")
    return dict(kind="array", dtype=data.dtype.str, shape=list(data.shape),
                logical_shape=list(logical_shape), batchable=batchable,
                sha256=hashlib.sha256(data.tobytes()).hexdigest(), data=data.tolist())


def array_value(record):
    require(type(record) is dict and set(record) == {
        "kind", "dtype", "shape", "logical_shape", "batchable", "sha256", "data"},
        "Model array record fields")
    require(record["kind"] == "array" and type(record["batchable"]) is bool,
            "Model array record identity")
    data = np.asarray(record["data"], dtype=np.dtype(record["dtype"])).reshape(record["shape"])
    require(_array_record(data, logical_shape=record["logical_shape"], batchable=record["batchable"]) == record,
            "Model array record digest or values")
    return data


def _walk(value, visit, path="$", annotation=None):
    """Preserve nested dataclasses and tuple structure, including sparse solver tables."""
    if is_dataclass(value):
        visit(path, "object", type(value).__qualname__, None)
        result = copy.copy(value)
        for field in fields(value):
            object.__setattr__(result, field.name, _walk(getattr(value, field.name), visit,
                                                       path + "." + field.name, field.type))
        return result
    if isinstance(value, (tuple, list)):
        visit(path, "sequence", dict(type=type(value).__name__, length=len(value)), None)
        result = [_walk(v, visit, path + "[" + str(i) + "]") for i, v in enumerate(value)]
        return tuple(result) if isinstance(value, tuple) else result
    if isinstance(value, wp.array):
        shape = getattr(annotation, "shape", ())
        batchable = bool(shape and shape[0] == "*")
        return visit(path, "array", value, batchable)
    if isinstance(value, np.generic):
        value = value.item()
    require(value is None or isinstance(value, (bool, int, float, str, bytes)),
            "Unsupported model leaf: " + path + " " + type(value).__qualname__)
    if isinstance(value, float):
        require(math.isfinite(value), "Nonfinite model scalar: " + path)
    visit(path, "scalar", dict(type=type(value).__qualname__,
                              value=value.hex() if isinstance(value, bytes) else value), None)
    return value


def model_snapshot(model):
    """Read every native model field, including nested per-world statistics."""
    result = {}
    def visit(path, kind, value, batchable):
        if kind == "array":
            result[path] = _array_record(value.numpy(), logical_shape=value.shape, batchable=batchable)
            return value
        result[path] = dict(kind=kind, value=value)
    _walk(model, visit)
    return result


def merge_snapshots(snapshots):
    """Pure, byte-sensitive transport plan; unsupported differences fail closed."""
    require(type(snapshots) is list and 1 <= len(snapshots) <= 256, "Model batch denominator")
    require(all(type(row) is dict and set(row) == set(snapshots[0]) for row in snapshots),
            "Different model field populations")
    result, differing = {}, []
    for path, first in snapshots[0].items():
        rows = [row[path] for row in snapshots]
        require(all(row["kind"] == first["kind"] for row in rows), "Model field kind: " + path)
        if first["kind"] != "array":
            require(all(_json(row) == _json(first) for row in rows), "Non-batched model field differs: " + path)
            result[path] = copy.deepcopy(first)
            continue
        arrays = [array_value(row) for row in rows]
        signature = {key: first[key] for key in ("dtype", "shape", "logical_shape", "batchable")}
        require(all({key: row[key] for key in signature} == signature for row in rows),
                "Model field dimensions or dtype: " + path)
        if first["batchable"]:
            require(first["logical_shape"] and first["logical_shape"][0] == 1
                    and first["shape"] and first["shape"][0] == 1,
                    "Source model field already batched: " + path)
        if all(row["sha256"] == first["sha256"] for row in rows):
            result[path] = copy.deepcopy(first)
        else:
            require(first["batchable"], "Non-batched model array differs: " + path)
            result[path] = _array_record(np.concatenate(arrays, axis=0),
                logical_shape=[len(rows), *first["logical_shape"][1:]], batchable=True)
            differing.append(path)
    return result, differing


def pack_models(models):
    """Copy complete independently compiled models into one checked GPU model."""
    snapshots = [model_snapshot(model) for model in models]
    merged, differing = merge_snapshots(snapshots)
    def visit(path, kind, value, batchable):
        if kind != "array":
            return None
        record = merged[path]
        out = wp.array(array_value(record), dtype=value.dtype, device=value.device)
        require(list(out.shape) == record["logical_shape"], "Transport logical dimensions: " + path)
        # The pinned engine tags annotated per-world arrays during put_model.
        if batchable:
            out._is_batched = True
        return out
    result = _walk(models[0], visit)
    require(model_snapshot(result) == merged, "GPU model transport readback differs")
    return result, dict(source_models=snapshots, packed_model=merged, differing_fields=differing)


def verify_transport(record, expected_worlds):
    require(set(record) == {"source_models", "packed_model", "differing_fields"}
            and len(record["source_models"]) == expected_worlds, "Transport evidence denominator")
    packed, differing = merge_snapshots(record["source_models"])
    require(record["packed_model"] == packed and record["differing_fields"] == differing,
            "Transport evidence does not reconstruct")
    return differing


def robot_view(core, creature, model, data):
    """Attach production observation methods to this creature's own native copy."""
    robot = object.__new__(ConditionRobot)
    from creature_batch import bridge
    robot.core = core
    robot.profile_id = bridge.PER_ACTUATOR_DEVELOPMENT_PROFILE_ID
    robot.descriptor = copy.deepcopy(creature["descriptor"])
    robot.compiled = creature["compiled"]
    robot.morphology = robot.compiled["morphology"]
    robot.spec = robot.morphology["morphology_spec"]
    robot.condition_spec = copy.deepcopy(creature["spec"])
    robot.model, robot.data = model, data
    robot.ground_geom_id = model.geom("ground").id
    robot.body_geom_ids = {key: model.geom(key + "_geom").id for key in robot.morphology["ordered_body_ids"]}
    robot.joint_ids = {key: model.joint(key).id for key in robot.morphology["ordered_joint_ids"]}
    robot.actuator_ids = {key: model.actuator(key).id for key in robot.morphology["ordered_actuator_ids"]}
    robot.actuator_specs = {row["actuator_id"]: row for row in robot.spec["actuators"]}
    robot.contact_sites = {row["contact_site_id"]: row for row in robot.spec["contact_sites"]}
    robot.limbs = {row["limb_id"]: row for row in robot.spec["limbs"]}
    validate_native_profile(model, creature["spec"])
    require(robot.compiled["descriptor"] == robot.descriptor, "Native observation descriptor identity")
    return robot


def expected_native_fields(creature):
    """Independent primary-geometry reconstruction from the compiler's XML."""
    import xml.etree.ElementTree as ET
    from motor_effectiveness_task import expected_actuator_arrays
    tree = ET.fromstring(creature["model_xml"])
    bodies, geoms = tree.findall(".//body"), tree.findall(".//geom")
    def vector(element, name, default):
        return list(map(float, element.attrib.get(name, default).split()))
    sizes, positions = [], []
    for geom in geoms:
        size = vector(geom, "size", "0")
        position = vector(geom, "pos", "0 0 0")
        if "fromto" in geom.attrib:
            ends = np.asarray(vector(geom, "fromto", "")).reshape(2, 3)
            position = ends.mean(axis=0).tolist()
            size = [size[0], float(np.linalg.norm(ends[1] - ends[0]) / 2)]
        sizes.append((size + [0.] * 3)[:3])
        positions.append(position)
    result = dict(qpos0=creature["spec"]["initial_qpos"],
        body_pos=[[0.] * 3] + [vector(body, "pos", "0 0 0") for body in bodies],
        body_mass=[0.] + [float(body.find("inertial").attrib["mass"]) for body in bodies],
        body_inertia=[[0.] * 3] + [vector(body.find("inertial"), "diaginertia", "") for body in bodies],
        body_ipos=[[0.] * 3] + [vector(body.find("inertial"), "pos", "0 0 0") for body in bodies],
        geom_size=sizes, geom_pos=positions,
        jnt_pos=[[0.] * 3] + [vector(joint, "pos", "0 0 0") for joint in tree.findall(".//joint")])
    result.update({"actuator_" + key: value for key, value in expected_actuator_arrays(creature["spec"]).items()})
    if "recovery_compilation" in creature:
        # Recovery anchors and ranges have a different public compiler authority.
        result["jnt_range"] = [[0., 0.]] + [vector(j, "range", "") for j in tree.findall(".//joint")]
        result["jnt_axis"] = [[0., 0., 1.]] + [vector(j, "axis", "") for j in tree.findall(".//joint")]
    return result


def native_metadata(model, creature):
    validate_native_profile(model, creature["spec"])
    return dict(binding=creature["binding"],
        ordered_bodies=[model.body(i).name for i in range(model.nbody)],
        ordered_geoms=[model.geom(i).name for i in range(model.ngeom)],
        body_rootid=model.body_rootid.tolist(), force_ranges=model.actuator_forcerange.tolist(),
        native_fields={name: getattr(model, name).tolist() for name in expected_native_fields(creature)},
        observation_stage="prepared_before_control", force_stage="completed_step_before_next_prepare")


def validate_model_evidence(creature, metadata, source_snapshot):
    import xml.etree.ElementTree as ET
    tree = ET.fromstring(creature["model_xml"])
    require(metadata["binding"] == creature["binding"]
            and metadata["ordered_bodies"] == ["world"] + [body.attrib["name"] for body in tree.findall(".//body")]
            and metadata["ordered_geoms"] == creature["spec"]["geom_names"]
            and metadata["body_rootid"] == [0] + [1] * 9
            and metadata["force_ranges"] == creature["spec"]["force_ranges"],
            "Native creature names or model binding")
    expected = expected_native_fields(creature)
    require(set(metadata["native_fields"]) == set(expected), "Native geometry field population")
    for name, values in expected.items():
        actual = np.asarray(metadata["native_fields"][name])
        require(actual.shape == np.asarray(values).shape
                and np.all(np.isfinite(actual)) and np.allclose(actual, values, atol=1e-12, rtol=1e-12),
                "Compiled XML/native geometry mismatch: " + name)
        record = source_snapshot["$." + name]
        device = array_value(record)
        expected_device = actual.astype(device.dtype)
        if record["batchable"]:
            expected_device = expected_device[None]
        require(device.dtype in (np.dtype("float32"), np.dtype("int32"), np.dtype("bool"))
                and device.shape == expected_device.shape
                and device.tobytes() == expected_device.tobytes(),
                "Native/GPU primary model field mismatch: " + name)
