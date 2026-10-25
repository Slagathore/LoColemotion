"""Solver-stage rigid contact readout; no controller observation is modified.

The trusted host exclusively owns preparation and completion. A clock value alone
cannot prove solver stage: an out-of-band mj_forward can leave time unchanged.
See the frozen observer contract for the supported host and non-claims.
"""
import math
import time

import numpy as np

STAGE = "completed_step_before_next_prepare"
SCHEMA = "locolemotion_contact_force_sample_v1"


def require(value, message):
    if not value:
        raise ValueError(message)


def vector(value, count):
    require(isinstance(value, (list, tuple)) and len(value) == count
            and all(type(x) in (int, float) and math.isfinite(x) for x in value),
            "Contact finite vector")
    return value


def canonical(value):
    x, y, z = vector(value, 3)
    return [x, z, -y]


def world_vector(frame, value):
    vector(frame, 9); vector(value, 3)
    # MuJoCo stores the contact basis in rows. Local -> world is its transpose.
    return [sum(frame[3*j+i]*value[j] for j in range(3)) for i in range(3)]


def validate_frame(frame):
    vector(frame, 9)
    rows = [frame[3*i:3*i+3] for i in range(3)]
    require(all(abs(sum(a*b for a, b in zip(rows[i], rows[j]))-int(i == j)) <= 1e-9
                for i in range(3) for j in range(3)), "Contact orthonormal frame")
    cross = [rows[0][1]*rows[1][2]-rows[0][2]*rows[1][1],
             rows[0][2]*rows[1][0]-rows[0][0]*rows[1][2],
             rows[0][0]*rows[1][1]-rows[0][1]*rows[1][0]]
    require(abs(sum(a*b for a, b in zip(cross, rows[2]))-1.) <= 1e-9,
            "Contact frame handedness")


def decode_constraint(contact, efc_force, cone):
    """Independent algebraic reconstruction of the six contact-frame components."""
    require(cone in ("pyramidal", "elliptic"), "Contact cone")
    dim, address = contact["dim"], contact["efc_address"]
    require(type(dim) is int and dim in (1, 3, 4, 6), "Contact dimension")
    require(type(address) is int and address >= -1, "Contact constraint address")
    vector(efc_force, len(efc_force)); vector(contact["friction"], 5)
    require(math.isfinite(contact["adhesion_n"]) and contact["adhesion_n"] >= 0,
            "Contact adhesion")
    result = [0.] * 6
    if address < 0:
        return result
    count = 2*(dim-1) if cone == "pyramidal" and dim > 1 else dim
    require(address+count <= len(efc_force), "Contact constraint extent")
    values = efc_force[address:address+count]
    if cone == "pyramidal" and dim > 1:
        result[0] = sum(values)
        for i in range(1, dim):
            result[i] = (values[2*i-2]-values[2*i-1])*contact["friction"][i-1]
    else:
        result[:dim] = values
    # MuJoCo 3.11 returns net interface force after adhesive pull, if any.
    result[0] -= contact["adhesion_n"]
    return result


def geometry(data):
    return [dict(native_index=i, geom=[int(g) for g in con.geom],
                 position_m=con.pos.tolist(), frame=con.frame.tolist(),
                 distance_m=float(con.dist), dim=int(con.dim),
                 efc_address=int(con.efc_address), exclude=int(con.exclude),
                 friction=con.friction.tolist(), adhesion_n=float(con.adhesion))
            for i, con in enumerate(data.contact[:data.ncon])]


def enrich(contact, wrench, metadata):
    vector(wrench, 6); validate_frame(contact["frame"])
    pair = contact["geom"]
    require(len(pair) == 2 and pair[0] != pair[1]
            and all(type(g) is int and 0 <= g < len(metadata["geoms"]) for g in pair),
            "Rigid contact geometry identity")
    ids = [metadata["geoms"][g] for g in pair]
    force = world_vector(contact["frame"], wrench[:3])
    torque = world_vector(contact["frame"], wrench[3:])
    return dict(contact, geom_names=[g["name"] for g in ids],
                body_ids=[g["body_id"] for g in ids], body_names=[g["body_name"] for g in ids],
                local_force_n=wrench[:3], local_torque_nm=wrench[3:],
                force_on_geom2_world_n=force, torque_on_geom2_world_nm=torque,
                force_on_geom2_canonical_n=canonical(force),
                torque_on_geom2_canonical_nm=canonical(torque))


def summarize_loads(contacts, metadata):
    """All mapped distal-geom loads, including explicit zero-contact entries.

    These capsules include the lower leg. Mapping to a contact-site identifier
    does not prove that a force was applied at the anatomical endpoint.
    Torques remain per-contact and are not summed about different origins.
    """
    result = {m["contact_site_id"]: dict(m, contact_indices=[], normal_load_n=0.,
                force_canonical_n=[0., 0., 0.]) for m in metadata["site_mapping"]}
    by_geom = {m["geom_id"]: m["contact_site_id"] for m in metadata["site_mapping"]}
    other = []
    for contact in contacts:
        pair = contact["geom"]
        if metadata["ground_geom_id"] in pair:
            side = 1-pair.index(metadata["ground_geom_id"])
            site = by_geom.get(pair[side])
            if site is not None:
                row = result[site]; row["contact_indices"].append(contact["native_index"])
                row["normal_load_n"] += contact["local_force_n"][0]
                sign = 1 if side == 1 else -1
                row["force_canonical_n"] = [a+sign*b for a, b in
                    zip(row["force_canonical_n"], contact["force_on_geom2_canonical_n"])]
                continue
        other.append(contact["native_index"])
    return dict(mapped_distal_ground_loads=list(result.values()), other_contact_indices=other)


def model_metadata(model, compiled, spec):
    require(int(model.nflex) == 0 and model.ngeom == 10, "Rigid observer model scope")
    geoms = [dict(id=i, name=model.geom(i).name, body_id=int(model.geom_bodyid[i]),
                  body_name=model.body(int(model.geom_bodyid[i])).name)
             for i in range(model.ngeom)]
    require([g["name"] for g in geoms] == spec["geom_names"], "Observer ordered geometry")
    sites = compiled["morphology"]["morphology_spec"]["contact_sites"]
    mapping = [dict(contact_site_id=s["contact_site_id"], body_name=s["body_id"],
                    geom_id=spec["geom_names"].index(s["body_id"]+"_geom"),
                    geom_name=s["body_id"]+"_geom") for s in sites]
    require(len(mapping) == 4 and len({m["geom_id"] for m in mapping}) == 4
            and all(geoms[m["geom_id"]]["body_name"] == m["body_name"] for m in mapping),
            "Observer distal geometry mapping")
    return dict(schema_version="locolemotion_contact_force_metadata_v1",
                stage=STAGE, geoms=geoms, site_mapping=mapping,
                ground_geom_id=spec["geom_names"].index("ground"),
                cone="pyramidal" if int(model.opt.cone) == 0 else "elliptic",
                timestep_s=float(model.opt.timestep),
                force_convention="positive_on_geom2_negative_on_geom1",
                torque_origin="each_contact_position",
                load_semantics="mapped_distal_geom_ground_contact_not_endpoint_force",
                canonical_rotation="x,z,-y", controller_load_fields_changed=False)


class ContactStepper:
    """Single-use preparation/completion protocol owned by the bound host.

    complete() advances exactly once, then captures synchronously. There is no
    public delayed-capture operation. Calls outside this owner are unsupported,
    not detected from time alone. A native or capture exception poisons the instance.
    """
    def __init__(self, api, model, data, metadata):
        self.api, self.model, self.data, self.metadata = api, model, data, metadata
        self.next_step, self.pending, self.poisoned = 1, None, False

    def prepare(self, step):
        require(not self.poisoned and self.pending is None and step == self.next_step,
                "Observer prepare order")
        self.poisoned = True
        tick = time.perf_counter()
        self.api.mj_step1(self.model, self.data)
        native_s = time.perf_counter()-tick
        tick = time.perf_counter()
        self.pending = dict(step=step, prepared_time_s=float(self.data.time),
            before_qpos=self.data.qpos.tolist(), before_qvel=self.data.qvel.tolist(),
            geometry=geometry(self.data), nefc=int(self.data.nefc),
            native_prepare_s=native_s)
        self.pending["prepare_capture_s"] = time.perf_counter()-tick
        self.poisoned = False

    def complete(self, step):
        guard_tick = time.perf_counter()
        require(not self.poisoned and self.pending is not None
                and self.pending["step"] == step == self.next_step, "Observer completion order")
        self.poisoned = True
        p, data = self.pending, self.data
        require(data.qpos.tolist() == p["before_qpos"] and data.qvel.tolist() == p["before_qvel"]
                and float(data.time) == p["prepared_time_s"]
                and geometry(data) == p["geometry"] and int(data.nefc) == p["nefc"],
                "Observer prepared state changed")
        held = data.ctrl.tolist()
        guard_s = time.perf_counter()-guard_tick
        tick = time.perf_counter(); self.api.mj_step2(self.model, data)
        native_s = time.perf_counter()-tick
        tick = time.perf_counter()
        require(float(data.time) == p["prepared_time_s"]+self.metadata["timestep_s"]
                and geometry(data) == p["geometry"] and int(data.nefc) == p["nefc"],
                "Observer solver stage mismatch")
        state = dict(qpos=data.qpos.tolist(), qvel=data.qvel.tolist(), ctrl=data.ctrl.tolist(),
                     time_s=float(data.time), efc_force=data.efc_force.tolist(),
                     sensordata=data.sensordata.tolist())
        require(state["ctrl"] == held, "Observer held inputs")
        contacts = []
        for contact in p["geometry"]:
            force = np.empty(6, dtype=np.float64)
            self.api.mj_contactForce(self.model, data, contact["native_index"], force)
            contacts.append(enrich(contact, force.tolist(), self.metadata))
        require(state == dict(qpos=data.qpos.tolist(), qvel=data.qvel.tolist(),
                    ctrl=data.ctrl.tolist(), time_s=float(data.time),
                    efc_force=data.efc_force.tolist(), sensordata=data.sensordata.tolist())
                and geometry(data) == p["geometry"], "Contact readout modified native state")
        sample = dict(schema_version=SCHEMA, stage=STAGE, step=step,
            prepared_time_s=p["prepared_time_s"], integrated_time_s=state["time_s"],
            before_qpos=p["before_qpos"], before_qvel=p["before_qvel"],
            qpos=state["qpos"], qvel=state["qvel"], ctrl=held, nefc=p["nefc"],
            ncon=len(contacts), efc_force=state["efc_force"],
            efc_id=data.efc_id.tolist(), efc_type=data.efc_type.tolist(), contacts=contacts,
            **summarize_loads(contacts, self.metadata))
        timing = dict(step=step, native_prepare_s=p["native_prepare_s"],
                      prepare_capture_s=p["prepare_capture_s"], native_complete_s=native_s,
                      complete_guard_s=guard_s,
                      force_capture_s=time.perf_counter()-tick)
        self.pending = None; self.next_step += 1; self.poisoned = False
        return sample, timing
