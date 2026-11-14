"""Solved ground-contact reactions captured before the next preparation.

This is diagnostic telemetry, never controller input or recovery authority.
Native MuJoCo coordinates are retained throughout: z up, force then torque.
"""
import copy

import numpy as np

from creature_batch import require
from gpu_batch_execution import SubstepHistory, array_at
from actuation_recovery_mechanics import quaternion_rotation

SCHEMA = "locolemotion_contact_reactions_v1"
POLICY = dict(schema_version=SCHEMA, sampling_stage="completed_step_before_next_prepare",
              every_internal_step=True, coordinate_frame="mujoco_world_z_up",
              ground_geom=0, force_on="geom_1", decode_float32_ulps=32,
              root_balance_float32_ulps=128, controller_input=False,
              recovery_authority=False)
FIELDS = ("contact.dim", "contact.friction", "contact.efc_address", "efc.force",
          "qfrc_constraint", "subtree_com", "reaction.force_world")


def enabled(c):
    if "contact_reactions" not in c:
        return False
    require(c["contact_reactions"] == POLICY and c.get("mode") == "route_ghost"
            and c.get("capture_mode") == "full" and "righting_spec" in c,
            "Contact reaction capture scope")
    return True


class History(SubstepHistory):
    """Extend the existing five-step buffers without changing solver inputs."""
    def __init__(self, wp, mjw, model, data):
        super().__init__(wp, data)
        self.mjw, self.model, self.data = mjw, model, data
        self.ids = wp.array(np.arange(data.naconmax, dtype=np.int32), dtype=wp.int32, device=data.qpos.device)
        self.forces = wp.empty(data.naconmax, dtype=wp.spatial_vector, device=data.qpos.device)
        for name in FIELDS:
            source = self.forces if name == "reaction.force_world" else array_at(data, name)
            self.sources[name] = source
            buffer = wp.empty((5, *source.shape), dtype=source.dtype, device=source.device)
            self.buffers[name] = buffer
            for sub in range(5):
                self.slots[sub][name] = buffer[sub]

    def after(self, sub):
        # step2 has solved forces; step1 would replace their contact geometry.
        with self.wp.ScopedDevice(self.forces.device):
            self.mjw.contact_force(self.model, self.data, self.ids, True, self.forces)
        super().after(sub)
        for name in FIELDS:
            self.wp.copy(self.slots[sub][name], self.sources[name])


def array(value, shape):
    result = np.asarray(value, dtype=float)
    require(result.shape == shape and np.isfinite(result).all(), "Contact reaction finite shape")
    return result


def decode(force, addresses, dim, friction, cone):
    """Independent float64 decoder of retained solver components."""
    force = array(force, (128,))
    friction = array(friction, (5,))
    require(type(dim) is int and dim in (1, 3, 4, 6) and type(cone) is int and cone in (0, 1)
            and np.all(friction >= 0.)
            and isinstance(addresses, list) and len(addresses) >= (dim if cone else 1)
            and all(type(v) is int for v in addresses), "Contact reaction decoder fields")
    result = np.zeros(6)
    if addresses[0] < 0:
        require(addresses[0] == -1, "Contact reaction inactive constraint")
        return result
    if cone == 1 or dim == 1:
        indices = addresses[:dim] if cone else addresses[:1]
        require(all(0 <= i < len(force) for i in indices)
                and len(set(indices)) == len(indices), "Contact reaction constraint indices")
        result[:len(indices)] = force[indices]
    else:
        start, count = addresses[0], 2*(dim-1)
        require(0 <= start and start+count <= len(force), "Contact reaction pyramid indices")
        edges = force[start:start+count].reshape(-1, 2)
        result[0] = np.sum(edges)
        result[1:dim] = (edges[:, 0]-edges[:, 1])*friction[:dim-1]
    return result


def project(snapshot, native, binding, cone):
    cell = native["cell"]
    contacts = []
    for contact in native["contacts"]:
        i = contact["native_index"]
        contacts.append(dict(native_index=i, dim=int(snapshot["contact.dim"][i]),
            friction=snapshot["contact.friction"][i].tolist(),
            efc_address=snapshot["contact.efc_address"][i].tolist(),
            force_world=snapshot["reaction.force_world"][i].tolist()))
    return dict(schema_version=SCHEMA, cell=cell, step=native["step"], time_s=native["time_s"],
        binding=copy.deepcopy(binding), sampling_stage=POLICY["sampling_stage"], cone=cone,
        constraint_force=snapshot["efc.force"][cell].tolist(),
        generalized_constraint_force=snapshot["qfrc_constraint"][cell].tolist(),
        center_of_mass=snapshot["subtree_com"][cell, 1].tolist(), contacts=contacts)


def verify(row, native, binding, cone, geom_names):
    require(set(row) == {"schema_version", "cell", "step", "time_s", "binding", "sampling_stage",
            "cone", "constraint_force", "generalized_constraint_force", "center_of_mass", "contacts"}
            and row["schema_version"] == SCHEMA and row["binding"] == binding
            and row["sampling_stage"] == POLICY["sampling_stage"] and row["cone"] == cone
            and all(type(row[k]) is int and row[k] == native[k] for k in ("cell", "step"))
            and row["time_s"] == native["time_s"], "Contact reaction identity or stage")
    require(type(row["contacts"]) is list and len(row["contacts"]) == len(native["contacts"])
            and len(geom_names) == 10 and geom_names[0] == "ground", "Contact reaction population")
    array(row["constraint_force"], (128,))
    constraint = array(row["generalized_constraint_force"], (14,))
    center = array(row["center_of_mass"], (3,))
    qpos = array(native["before_qpos"], (15,))
    force_by_geom, moment_by_geom = np.zeros((10, 3)), np.zeros((10, 3))
    total_force, root_moment = np.zeros(3), np.zeros(3)
    force_scale, moment_scale = 0., 0.
    eps = np.finfo(np.float32).eps
    for recorded, contact in zip(row["contacts"], native["contacts"], strict=True):
        require(set(recorded) == {"native_index", "dim", "friction", "efc_address", "force_world"}
                and type(recorded["native_index"]) is int and recorded["native_index"] == contact["native_index"]
                and len(contact["geom"]) == 2 and contact["geom"].count(0) == 1
                and all(type(g) is int and 0 <= g < 10 for g in contact["geom"]),
                "Contact reaction ground contact join")
        local = decode(row["constraint_force"], recorded["efc_address"], recorded["dim"], recorded["friction"], cone)
        frame = array(contact["frame"], (9,)).reshape(3, 3)
        require(np.allclose(frame @ frame.T, np.eye(3), atol=32*eps, rtol=0.)
                and np.linalg.det(frame) > 0., "Contact reaction frame")
        world = np.concatenate((local[:3] @ frame, local[3:] @ frame))
        reported = array(recorded["force_world"], (6,))
        require(np.allclose(world, reported, atol=32*eps, rtol=32*eps), "Contact reaction solver decode")
        # The engine's vector acts on geom[1]; reverse it when ground is second.
        sign = 1. if contact["geom"][0] == 0 else -1.
        geom = contact["geom"][1] if sign > 0 else contact["geom"][0]
        force, torque = sign*world[:3], sign*world[3:]
        point = array(contact["position_m"], (3,))
        about_root = np.cross(point-qpos[:3], force)+torque
        force_by_geom[geom] += force
        moment_by_geom[geom] += np.cross(point-center, force)+torque
        total_force += force
        root_moment += about_root
        force_scale += np.linalg.norm(force, ord=1)
        moment_scale += np.linalg.norm(about_root, ord=1)
    # Free-joint translation is world-frame; rotational generalized force is local.
    quaternion = qpos[3:7]
    norm = np.linalg.norm(quaternion)
    require(abs(norm-1.) <= 32*eps, "Contact reaction native quaternion")
    quaternion = quaternion/norm
    rotation = quaternion_rotation([*quaternion[1:], quaternion[0]])
    reported_root = rotation @ constraint[3:6]
    force_error = np.max(np.abs(total_force-constraint[:3]))
    moment_error = np.max(np.abs(root_moment-reported_root))
    require(force_error <= 128*eps*max(1., force_scale)
            and moment_error <= 128*eps*max(1., moment_scale),
            "Contact reaction free-root constraint balance")
    return dict(force_by_geom=force_by_geom, moment_by_geom=moment_by_geom,
                force_balance_error=float(force_error), moment_balance_error=float(moment_error))


class Reader:
    def __init__(self, c, creatures, cones):
        require(enabled(c) and len(creatures) == len(cones), "Contact reaction reader declaration")
        self.c, self.creatures, self.cones = c, creatures, cones
        self.rows = [dict(cell_id=cell["cell_id"], samples=0,
            force_impulse_by_geom_ns=np.zeros((10, 3)),
            moment_impulse_about_com_by_geom_nms=np.zeros((10, 3)),
            maximum_force_balance_error_n=0., maximum_moment_balance_error_nm=0.)
            for cell in c["cells"]]

    def consume(self, row, native):
        cell = native["cell"];target = self.rows[cell]
        require(native["step"] == target["samples"]+1, "Contact reaction sample order")
        actual = verify(row, native, self.creatures[cell]["binding"], self.cones[cell],
                        self.creatures[cell]["spec"]["geom_names"])
        target["samples"] += 1
        for key, field in (("force_impulse_by_geom_ns", "force_by_geom"),
                           ("moment_impulse_about_com_by_geom_nms", "moment_by_geom")):
            target[key] += self.c["timestep_s"]*actual[field]
        target["maximum_force_balance_error_n"] = max(target["maximum_force_balance_error_n"], actual["force_balance_error"])
        target["maximum_moment_balance_error_nm"] = max(target["maximum_moment_balance_error_nm"], actual["moment_balance_error"])

    def finish(self):
        require(all(r["samples"] == 5*self.c["outer_steps"] for r in self.rows), "Incomplete contact reaction stream")
        return dict(schema_version=SCHEMA, coordinate_frame=POLICY["coordinate_frame"],
            samples_verified=sum(r["samples"] for r in self.rows),
            cells=[{k:v.tolist() if isinstance(v,np.ndarray) else v for k,v in r.items()} for r in self.rows],
            controller_input=False, recovery_authority=False)
