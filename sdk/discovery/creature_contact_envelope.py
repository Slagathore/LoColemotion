"""Continuous distal-capsule reach bounds for compiled planar two-joint limbs.

Only endpoint height is optimized. A reachable point is not a collision-free
whole-body pose, supported force solution, trajectory, or recovery certificate.
"""
import math
import numpy as np
from actuation_recovery_mechanics import RigidTree, array, require, xyz

DOMAINS = ("all", "outward", "inward")
TOLERANCE_M = 1e-9


def minimum_height(coefficients, bounds):
    """Minimize c+a*cos(h)+b*sin(h)+d*cos(h+k)+e*sin(h+k).

    A minimum on the closed rectangle is a corner, an edge stationary point,
    or an interior stationary point. Interior derivatives separate into the
    two sinusoid derivatives. Flat sinusoids are covered by the edges.
    All candidates are evaluated, rather than choosing a local solution.
    """
    raw = np.asarray(coefficients)
    require(raw.ndim == 2 and raw.shape[1] == 5 and 0 < len(raw) <= 4096,
            "Envelope coefficient population")
    co = array(raw, raw.shape, "Envelope finite coefficients")
    limits = array(bounds, (2, 2), "Envelope joint rectangle")
    require(np.all(limits[:, 0] < limits[:, 1]) and np.max(np.abs(limits)) <= math.pi,
            "Envelope rectangle inside one joint turn")
    c, a, b, d, e = co.T
    hl, hu = limits[0]; kl, ku = limits[1]
    best = np.full(len(co), np.inf); witness = np.empty((len(co), 2))

    def consider(h, k):
        h, k = np.broadcast_arrays(h, k, c)[:2]
        valid = (h >= hl-1e-12) & (h <= hu+1e-12) & (k >= kl-1e-12) & (k <= ku+1e-12)
        h = np.clip(h, hl, hu); k = np.clip(k, kl, ku)
        value = c+a*np.cos(h)+b*np.sin(h)+d*np.cos(h+k)+e*np.sin(h+k)
        require(np.isfinite(value).all(), "Envelope arithmetic overflow")
        take = valid & (value < best)
        best[take] = value[take]
        witness[take, 0] = h[take]; witness[take, 1] = k[take]

    for h in (hl, hu):
        for k in (kl, ku): consider(h, k)
        for turn in range(-3, 4):
            consider(h, np.arctan2(e, d)+turn*math.pi-h)
    for k in (kl, ku):
        edge_a = a+d*math.cos(k)+e*math.sin(k)
        edge_b = b-d*math.sin(k)+e*math.cos(k)
        for turn in range(-3, 4):
            consider(np.arctan2(edge_b, edge_a)+turn*math.pi, k)
    for ht in range(-3, 4):
        h = np.arctan2(b, a)+ht*math.pi
        for ut in range(-3, 4):
            consider(h, np.arctan2(e, d)+ut*math.pi-h)
    require(np.isfinite(best).all(), "Envelope missing minimum")
    return best, witness


def orientation_grid(progress_degrees, axis_body):
    degrees = np.asarray(progress_degrees)
    require(degrees.ndim == 1 and 1 <= len(degrees) <= 4096, "Envelope orientation population")
    degrees = array(degrees, degrees.shape, "Envelope finite angles")
    axis = array(axis_body, (3,), "Envelope axis")
    require(np.all((degrees >= 0) & (degrees <= 180))
            and axis.tolist() in ([1.,0.,0.], [-1.,0.,0.], [0.,0.,1.], [0.,0.,-1.]),
            "Envelope positive principal-axis rotation")
    theta = np.deg2rad(degrees)
    initial = np.array([0., -1., 0.])
    # World up expressed in the rotating body; native roots are never moved.
    return np.cos(theta)[:, None]*initial-np.sin(theta)[:, None]*np.cross(axis, initial)


class ContactEnvelope:
    def __init__(self, spec):
        self.tree = RigidTree(spec)
        tree = self.tree
        require(tree.n == 8 and len(spec["contact_sites"]) == 4, "Envelope four two-joint limbs")
        torso = tree.bodies[0]["collision"]
        require(torso["kind"] == "box", "Envelope box torso")
        self.half = xyz(torso["size_m"])/2
        require((self.half > 0).all(), "Envelope positive torso")
        self.limbs = []
        for i, site in enumerate(spec["contact_sites"]):
            hi, ki = 2*i, 2*i+1
            hip, knee = tree.joints[hi:ki+1]
            distal = tree.index[site["body_id"]]
            require(tree.parent[hi] == 0 and tree.parent[ki] == tree.child[hi]
                    and tree.child[ki] == distal and tree.ancestors[distal] == [hi, ki],
                    "Envelope ordered limb topology")
            require(all(np.array_equal(xyz(j["axis_parent_unit"]), [0.,0.,1.]) for j in (hip, knee)),
                    "Envelope requires parallel positive body-z axes")
            limits = np.array([[j["lower_limit_rad"], j["upper_limit_rad"]] for j in (hip, knee)])
            require(np.all(limits[:, 0] < 0) and np.all(limits[:, 1] > 0)
                    and np.max(np.abs(limits)) <= math.pi, "Envelope finite joint limits")
            shape = tree.bodies[distal]["collision"]
            require(shape["kind"] == "capsule", "Envelope distal capsule")
            dims = array([shape["length_m"], shape["radius_m"]], (2,), "Envelope capsule dimensions")
            require((dims > 0).all() and site["radius_m"] == dims[1], "Envelope contact radius")
            anchor = xyz(hip["anchor_parent_m"])
            require(abs(anchor[0]) > 1e-12, "Envelope front/rear bend identity")
            first = xyz(knee["anchor_parent_m"])-xyz(hip["anchor_child_m"])
            ends = np.array([[0., -dims[0]/2, 0.], [0., dims[0]/2, 0.]])-xyz(knee["anchor_child_m"])
            self.limbs.append(dict(anchor=anchor, first=first, ends=ends, radius=float(dims[1]),
                                   limits=limits, distal=distal))
        self.half.setflags(write=False)

    def bounds(self, limb, domain):
        require(type(limb) is int and 0 <= limb < 4 and domain in DOMAINS, "Envelope limb or domain")
        limits = .9*self.limbs[limb]["limits"]
        if domain != "all":
            sign = 1 if self.limbs[limb]["anchor"][0] > 0 else -1
            if domain == "inward": sign = -sign
            limits[:, 0 if sign > 0 else 1] = 0.
        return limits

    def evaluate(self, up_body, limb, domain="all", root_height_m=None):
        up = np.asarray(up_body)
        require(up.ndim == 2 and up.shape[1] == 3 and 0 < len(up) <= 4096, "Envelope up-vector population")
        up = array(up, up.shape, "Envelope finite up vectors")
        require(np.max(np.abs(np.sum(up*up, axis=1)-1.)) <= 1e-10, "Envelope unit up vectors")
        bounds = self.bounds(limb, domain); part = self.limbs[limb]
        height = np.abs(up) @ self.half if root_height_m is None else array(
            root_height_m, (len(up),), "Envelope finite root heights")
        first = part["first"]
        outputs = []
        for endpoint, second in enumerate(part["ends"]):
            coefficients = np.column_stack((
                up @ part["anchor"]+up[:, 2]*(first[2]+second[2]),
                up[:, 0]*first[0]+up[:, 1]*first[1],
                -up[:, 0]*first[1]+up[:, 1]*first[0],
                up[:, 0]*second[0]+up[:, 1]*second[1],
                -up[:, 0]*second[1]+up[:, 1]*second[0]))
            value, angles = minimum_height(coefficients, bounds)
            outputs.append((value, angles))
        choose = outputs[1][0] < outputs[0][0]
        value = np.where(choose, outputs[1][0], outputs[0][0])
        angles = np.where(choose[:, None], outputs[1][1], outputs[0][1])
        return dict(minimum_capsule_clearance_m=height+value-part["radius"],
                    witness_joint_angles_rad=angles, witness_endpoint=choose.astype(np.int8),
                    torso_floor_height_m=np.abs(up) @ self.half,
                    evaluated_root_height_m=height.copy())


def body_population(inherited, corner_fields, generated_seed_start, generated_count):
    """Distinct descriptor values, with predecessor identities retained first."""
    import copy
    import itertools
    import json
    from showcase_model import FIELDS, S169, generated, validate_descriptor
    require(corner_fields == list(FIELDS) and type(generated_seed_start) is int
            and type(generated_count) is int and 0 <= generated_count <= 1024
            and 0 <= generated_seed_start <= 2**31-1-generated_count, "Envelope body recipe")
    proposals=[("retained",x) for x in inherited]
    for i, values in enumerate(itertools.product(*(FIELDS[f] for f in corner_fields))):
        proposals.append(("corner",dict(S169,morphology_id=f"contact_envelope_corner_{i:03d}",
                                        **dict(zip(corner_fields,values,strict=True)))))
    proposals += [("generated",generated(i)) for i in range(generated_seed_start,generated_seed_start+generated_count)]
    seen=set();accepted=[];duplicates=[]
    for origin,value in proposals:
        validate_descriptor(value)
        key=json.dumps({k:v for k,v in value.items() if k!="morphology_id"},sort_keys=True,separators=(",",":"))
        if key in seen:
            duplicates.append(dict(origin=origin,descriptor=value));continue
        seen.add(key);accepted.append(dict(origin=origin,descriptor=copy.deepcopy(value)))
    return accepted,duplicates


def bound_archive(reference, kind, evidence):
    import json
    from pathlib import Path
    from creature_righting_geometry import sha
    relative=Path(reference[kind]["archive_relative_path"])
    require(not relative.is_absolute() and ".." not in relative.parts, "Envelope archive traversal")
    path=(evidence/relative).resolve(strict=True)
    require(path.is_relative_to(evidence.resolve(strict=True))
            and sha(path/"receipt.json")==reference[kind]["receipt_sha256"]
            and sha(path/"independent-audit.json")==reference[kind]["independent_audit_sha256"],
            "Envelope retained receipt binding")
    owner=json.loads((path/"receipt.json").read_bytes())
    require(owner["ok"] is True and owner["audit"]["ok"] is True
            and owner["source_runtime_unchanged"] is True, "Envelope incomplete native predecessor")
    return path,owner


def projection_diagnosis(retained, owner):
    """Posthoc evaluation only when a retained torso projection was updated."""
    import collections
    import json
    from creature_righting_geometry import sha
    from creature_contact_reach import LimbGeometry
    contract=owner["contract"];inventory={a["path"]:a for a in owner["artifacts"]}
    require(owner["audit"]["capture"]["full_capture"] is True, "Envelope requires full projection capture")
    reports={};rows=0;witness_checks=0
    for batch in owner["preflight"]["batches"]:
        models={};grids={}
        for slot,index in enumerate(batch["cell_indices"]):
            relative=f"native/{batch['batch_id']}/cell_{slot}/creature.json"
            require(sha(retained/relative)==inventory[relative]["sha256"],"Envelope retained creature binding")
            creature=json.loads((retained/relative).read_bytes())
            require(creature["descriptor"]==contract["cells"][index]["descriptor"],"Envelope crossed creature")
            spec=creature["compiled"]["morphology"]["morphology_spec"]
            models[slot]=ContactEnvelope(spec);grids[slot]=LimbGeometry(spec)
        relative=f"native/{batch['batch_id']}/controller.jsonl"
        require(sha(retained/relative)==inventory[relative]["sha256"],"Envelope controller stream binding")
        steps=[0]*len(batch["cell_indices"])
        with (retained/relative).open(encoding="utf-8") as stream:
            for line in stream:
                row=json.loads(line);slot=row["cell"];index=batch["cell_indices"][slot]
                profile=contract["cells"][index]["profile"]
                require(row["outer_step"]==steps[slot] and row["binding"]["cell_id"]==contract["cells"][index]["cell_id"]
                        and row["binding"]["candidate_id"]==profile["id"],"Envelope projection population")
                steps[slot]+=1;rows+=1
                if "torso_target" not in profile:continue
                decision=row["resolution"]["contact_reach"];after=decision["state_after"]
                if after["phase"]!="push" or not ((after["elapsed"]-1)%profile["target_update_steps"]==0 or decision["anchor_updates"]>0):continue
                for limb,choice in enumerate(after["choices"]):
                    if choice is None or not choice["torso_target_projection"]["active"]:continue
                    frame=choice["torso_target_projection"]["virtual_frame"]
                    rotation=np.asarray(frame["rotation_matrix"]);position=np.asarray(frame["position_m"])
                    model=models[slot];grid=grids[slot]
                    full=model.evaluate(rotation[1:2],limb,"all",[position[1]])
                    domain=model.evaluate(rotation[1:2],limb,profile["bend_pattern"],[position[1]])
                    points=grid.candidates(limb,position,rotation)
                    require(np.max(np.abs(points[choice["grid_index"]]-choice["geometric_low_endpoint_world_m"]))<=2e-12,
                            "Envelope selected projection reconstruction")
                    sign=1 if grid.hips[limb,0]>0 else -1
                    if profile["bend_pattern"]=="inward":sign=-sign
                    allowed=np.all(grid.poses*sign>=-1e-12,axis=1)
                    grid_clearance=float(np.min(points[allowed,1])-grid.radii[limb])
                    minimum=float(domain["minimum_capsule_clearance_m"][0])
                    require(minimum<=grid_clearance+2e-12,"Envelope continuous minimum above grid")
                    witness_checks+=1
                    d=reports.setdefault(profile["id"],collections.Counter())
                    d["updated_projections"]+=1
                    d["selected_above_floor"]+=choice["predicted_capsule_clearance_m"]>TOLERANCE_M
                    d["domain_cannot_reach_floor"]+=minimum>TOLERANCE_M
                    d["full_joint_rectangle_cannot_reach_floor"]+=full["minimum_capsule_clearance_m"][0]>TOLERANCE_M
                    d["grid_missed_reachable_floor"]+=(grid_clearance>TOLERANCE_M and minimum<=TOLERANCE_M)
                    d["bend_domain_excludes_reachable_floor"]+=(minimum>TOLERANCE_M and full["minimum_capsule_clearance_m"][0]<=TOLERANCE_M)
                    d["cannot_reach_requested_depth"]+=minimum>-profile["push_depth_m"]+TOLERANCE_M
                    d["selected_above_floor_despite_domain_reach"]+=(choice["predicted_capsule_clearance_m"]>TOLERANCE_M and minimum<=TOLERANCE_M)
                    d["at_normalized_joint_boundary"]+=max(map(abs,choice["normalized_pose"]))>=.9-1e-12
        require(steps==[contract["outer_steps"]]*len(steps),"Envelope incomplete projection stream")
    return dict(controller_rows_verified=rows,projection_grid_checks=witness_checks,
                profiles={k:{key:int(value) for key,value in v.items()} for k,v in reports.items()},
                observed_projections_are_posthoc=True,recovery_eligibility_changed=False)


def declaration(path):
    import json
    from pathlib import Path
    from creature_righting_geometry import sha
    root=Path(__file__).resolve().parents[2]
    c=json.loads(Path(path).read_bytes())
    require(c["schema_version"]=="locolemotion_contact_envelope_v1"
            and c["ledger_scope"]==dict(subsystem="discovery",engine_scope="core",
                authority_mode="zero_world_geometry_diagnostic",question_class="development"),
            "Envelope declaration identity")
    require(type(c["progress_degrees"]) is list and 2<=len(c["progress_degrees"])<=181
            and all(type(x) is int and 0<=x<=180 for x in c["progress_degrees"])
            and c["progress_degrees"]==sorted(set(c["progress_degrees"]))
            and c["progress_degrees"][0]==0 and c["progress_degrees"][-1]==180
            and c["axes_body"]==[[1.,0.,0.],[-1.,0.,0.],[0.,0.,1.],[0.,0.,-1.]]
            and c["domains"]==list(DOMAINS) and c["normalized_joint_limit"]==.9
            and c["numerical_tolerance_m"]==TOLERANCE_M and c["controls_required"]==10
            and all(c[k] is False for k in ("physical_started","trained","recovery_benefit_established",
                "training_data_authority","physical_acceptance_authority","release_authority","dynamic_feasibility_established")),
            "Envelope declaration scope")
    for name in ("predecessor","native_contract"):
        relative=Path(c[name]["path"]);target=(root/relative).resolve(strict=True)
        require(not relative.is_absolute() and ".." not in relative.parts and target.is_relative_to(root)
                and sha(target)==c[name]["sha256"],"Envelope source input binding")
    return c


def scalar_witness(model, limb, axis, degrees, height, angles):
    theta=math.radians(degrees)/2;initial=np.array([1.,0.,0.])
    quaternion=[*(initial*math.cos(theta)+np.cross(initial,axis)*math.sin(theta)),-axis[0]*math.sin(theta)]
    joints=np.zeros(8);joints[2*limb:2*limb+2]=angles
    frame=model.tree.kinematics([0.,height,0.],quaternion,joints)
    body=model.limbs[limb]["distal"];shape=model.tree.bodies[body]["collision"]
    center=frame["positions"][body];offset=frame["rotations"][body][:,1]*shape["length_m"]/2
    return min((center-offset)[1],(center+offset)[1])-shape["radius_m"]


def work(contract_path, core_path, output):
    from contextlib import ExitStack
    import hashlib
    import json
    from pathlib import Path
    from unittest.mock import patch
    import mujoco
    from creature_batch import bridge, compile_creature
    from creature_righting import recovery_descriptor
    from creature_righting_geometry import sha, write_new
    from showcase_model import FIELDS
    root=Path(__file__).resolve().parents[2];evidence=(root.parent/"SporeSpore_Evidence").resolve(strict=True)
    output=Path(output).resolve()
    require(output.is_relative_to(evidence) and not output.exists(),"Envelope fresh durable output")
    c=declaration(contract_path);require(sha(core_path)==c["core_sha256"],"Envelope SDK image binding")
    predecessor=json.loads((root/c["predecessor"]["path"]).read_bytes())
    retained,owner=bound_archive(predecessor,"search",evidence)
    route,route_owner=bound_archive(predecessor,"full_canary",evidence)
    native=json.loads((root/c["native_contract"]["path"]).read_bytes())
    inherited=native["righting_spec"]["descriptors"]
    pool,duplicates=body_population(inherited,c["body_population"]["corner_fields"],
        c["body_population"]["generated_seed_start"],c["body_population"]["generated_count"])
    require(len(pool)==c["body_population"]["expected_distinct_bodies"]
            and len(inherited)==c["body_population"]["inherited_bodies"]
            and len(duplicates)==c["body_population"]["duplicate_corners_removed"],"Envelope body denominator")
    output.mkdir()
    core=bridge.LocomotionCore(Path(core_path))
    angles=c["progress_degrees"];axes=c["axes_body"];n=len(angles)
    up=np.concatenate([orientation_grid(angles,a) for a in axes])
    inventory={a["path"]:a for a in owner["artifacts"]}
    bodies=[];checks=0;compiled_new=0
    with ExitStack() as trap:
        for name in ("MjModel","MjData","mj_step","mj_step1","mj_step2","mj_forward"):
            trap.enter_context(patch.object(mujoco,name,side_effect=AssertionError("Physics in contact envelope")))
        projections=projection_diagnosis(route,route_owner)
        for body_index,entry in enumerate(pool):
            descriptor=entry["descriptor"];input_binding=None
            if entry["origin"]=="retained":
                index=next(i for i,m in enumerate(owner["contract"]["righting_metadata"])
                    if m["body_index"]==body_index and m["candidate_index"]==0)
                batch=next(b for b in owner["preflight"]["batches"] if index in b["cell_indices"])
                slot=batch["cell_indices"].index(index)
                relative=f"native/{batch['batch_id']}/cell_{slot}/creature.json"
                require(sha(retained/relative)==inventory[relative]["sha256"],"Envelope retained body digest")
                creature=json.loads((retained/relative).read_bytes())
                require(creature["descriptor"]==descriptor,"Envelope retained body identity")
                input_binding=dict(archive_relative_path=predecessor["search"]["archive_relative_path"],
                    path=relative,sha256=inventory[relative]["sha256"])
            else:
                creature=compile_creature(core,descriptor,recovery_descriptor=recovery_descriptor(descriptor));compiled_new+=1
            spec=creature["compiled"]["morphology"]["morphology_spec"];model=ContactEnvelope(spec)
            name=f"body_{body_index:03d}";write_new(output/(name+"_creature.json"),creature)
            clearance=np.empty((3,4,4,n));witness=np.empty((3,4,4,n,2))
            for di,domain in enumerate(DOMAINS):
                for limb in range(4):
                    result=model.evaluate(up,limb,domain)
                    clearance[di,limb]=result["minimum_capsule_clearance_m"].reshape(4,n)
                    witness[di,limb]=result["witness_joint_angles_rad"].reshape(4,n,2)
            filename=name+"_reach.npz"
            with (output/filename).open("xb") as stream:
                np.savez(stream,clearance_m=clearance,joint_witness_rad=witness)
            groups=[]
            anchors=np.array([p["anchor"] for p in model.limbs])
            for ai,axis in enumerate(axes):
                scores=np.cross(anchors,[0.,-1.,0.]) @ axis
                selected=sorted(range(4),key=lambda i:(-float(scores[i]),i))[:2]
                require(all(scores[i]>0 for i in selected),"Envelope initial hip selection")
                for di,domain in enumerate(DOMAINS):
                    best=np.min(clearance[di,selected,ai],axis=0)
                    excluded=np.flatnonzero(best>TOLERANCE_M)
                    first=int(excluded[0]) if len(excluded) else None
                    groups.append(dict(axis_body=axis,domain=domain,initial_positive_hip_leverage_limbs=selected,
                        first_sample_without_selected_distal_reach_degrees=angles[first] if first is not None else None,
                        potentially_reachable_samples=int(np.count_nonzero(best<=TOLERANCE_M)),
                        excluded_samples=int(len(excluded))))
                    indices={0,n-1} if first is None else {first,max(0,first-1)}
                    for i in sorted(indices):
                        for limb in selected:
                            height=float(np.abs(up[ai*n+i]) @ model.half)
                            scalar=scalar_witness(model,limb,axis,angles[i],height,witness[di,limb,ai,i])
                            require(abs(scalar-clearance[di,limb,ai,i])<=2e-12,"Envelope scalar reach witness mismatch")
                            checks+=1
            shape=dict(torso=model.half.tolist(),limbs=[{k:(v.tolist() if isinstance(v,np.ndarray) else v)
                for k,v in part.items() if k!="distal"} for part in model.limbs])
            shape_digest=hashlib.sha256(json.dumps(shape,sort_keys=True,separators=(",",":")).encode()).hexdigest()
            bodies.append(dict(body_index=body_index,origin=entry["origin"],descriptor=descriptor,
                kinematic_shape_sha256=shape_digest,input_binding=input_binding,table_file=filename,
                table_sha256=sha(output/filename),groups=groups))
            if (body_index+1)%32==0 or body_index+1==len(pool):
                print(json.dumps(dict(bodies_complete=body_index+1,total=len(pool))),flush=True)
    summaries=[]
    for ai,axis in enumerate(axes):
        for domain in DOMAINS:
            values=[g["first_sample_without_selected_distal_reach_degrees"] for b in bodies for g in b["groups"]
                    if g["axis_body"]==axis and g["domain"]==domain]
            finite=[x for x in values if x is not None]
            summaries.append(dict(axis_body=axis,domain=domain,bodies=len(values),
                bodies_with_an_excluded_sample=len(finite),
                first_excluded_sample_min_degrees=min(finite) if finite else None,
                first_excluded_sample_median_degrees=float(np.median(finite)) if finite else None,
                first_excluded_sample_max_degrees=max(finite) if finite else None))
    result=dict(schema_version="locolemotion_contact_envelope_result_v1",ledger_scope=c["ledger_scope"],ok=True,
        body_count=len(bodies),new_sdk_compilations=compiled_new,
        distinct_kinematic_shapes=len({b["kinematic_shape_sha256"] for b in bodies}),
        deduplicated_descriptors=duplicates,orientation_count=len(up),
        limb_domain_minima=len(bodies)*len(up)*4*3,scalar_witness_checks=checks,
        continuous_joint_domain=True,continuous_orientation_or_morphology_coverage=False,
        body_summaries=summaries,bodies=bodies,retained_projection_diagnosis=projections,
        world_build_count=0,solver_steps=0,physical_started=False,trained=False,
        recovery_benefit_established=False,physical_acceptance_authority=False,
        training_data_authority=False,release_authority=False,dynamic_feasibility_established=False,
        limits=c["limits"])
    write_new(output/"result.json",result)
    return result


def main():
    import argparse
    import ctypes as C
    from ctypes import wintypes as W
    import json
    from pathlib import Path
    import subprocess
    import sys
    import time
    import uuid
    from creature_righting_geometry import sha,write_new
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--contract",type=Path,required=True)
    parser.add_argument("--core",type=Path,required=True)
    parser.add_argument("--worker",action="store_true")
    parser.add_argument("--output",type=Path)
    args=parser.parse_args()
    contract=args.contract.resolve(strict=True);core=args.core.resolve(strict=True)
    if args.worker:
        require(args.output is not None,"Envelope worker output")
        result=work(contract,core,args.output)
        print(json.dumps({k:result[k] for k in ("ok","body_count","limb_domain_minima","scalar_witness_checks","world_build_count")}))
        return
    require(args.output is None,"Envelope owner chooses a fresh identity")
    from run_gpu_measurement_probe import source_identity
    from run_gpu_motor_effectiveness import bindings as inherited_bindings
    from run_contact_sequence_native_v2 import invoke,jobs
    from run_residual_native import verify_tests
    from run_creature_native import inventory
    root=Path(__file__).resolve().parents[2]
    c=declaration(contract)
    require(contract.is_relative_to(root) and sha(core)==c["core_sha256"]
            and np.__version__==c["runtime_numpy"],"Envelope source/runtime identity")
    source=source_identity(False)
    status=lambda:subprocess.check_output(["git","status","--porcelain"],cwd=root,text=True).splitlines()
    initial_status=status()
    paths=[contract,Path(__file__).resolve(),root/"sdk/discovery/test_creature_contact_envelope.py",
        root/"sdk/discovery/.gitattributes",root/c["predecessor"]["path"],root/c["native_contract"]["path"],
        root/"sdk/discovery/creature_righting_geometry.py",root/"sdk/discovery/actuation_recovery_mechanics.py",
        root/"sdk/discovery/creature_contact_reach.py",root/"sdk/explorer/showcase_model.py",
        root/"sdk/discovery/creature_batch.py",root/"sdk/discovery/creature_righting.py"]
    def bindings():
        result=inherited_bindings(core,core)
        result["source"].update({p.relative_to(root).as_posix():sha(p) for p in paths})
        return result
    folder=root.parent/"SporeSpore_Evidence"/("sdk2-contact-envelope-v1-"+uuid.uuid4().hex)
    folder.mkdir();print(str(folder),flush=True)
    receipt=dict(schema_version="locolemotion_contact_envelope_owner_v1",ledger_scope=c["ledger_scope"],
        source_commit=source,source_status=initial_status,contract=c,ok=False,synthetic=True,
        world_build_count=0,solver_steps=0,physical_started=False,trained=False,
        physical_acceptance_authority=False,training_data_authority=False,release_authority=False)
    create=jobs.api("CreateMutexW",[C.c_void_p,W.BOOL,W.LPCWSTR],W.HANDLE)
    release=jobs.api("ReleaseMutex",[W.HANDLE])
    handle=jobs.checked(create(None,False,r"Global\SporeSpore.Locomotion.PhysicalConformance.Serial.v1"))
    acquired=False;started=time.monotonic()
    try:
        require(jobs.wait(handle,0)==0,"Another operation owns the project mutex");acquired=True
        receipt["bindings"]=bindings()
        for path in paths:
            target=folder/"source"/path.relative_to(root);target.parent.mkdir(parents=True,exist_ok=True)
            with target.open("xb") as stream:stream.write(path.read_bytes())
        write_new(folder/"declaration.json",receipt)
        env=dict(PYTHONPATH=";".join(str(root/p) for p in
            ("sdk/discovery","sdk/conformance","sdk/explorer","sdk/python","sdk/adapters/mujoco","sdk")),
            QUADRUPED_TEST_CORE=str(core),PYTHONIOENCODING="utf-8",
            OPENBLAS_NUM_THREADS="1",OMP_NUM_THREADS="1",MKL_NUM_THREADS="1")
        tests=folder/"test-artifacts";tests.mkdir()
        invoke([sys.executable,"-B","-m","unittest","-v","test_creature_contact_envelope"],
            folder/"controls",300,dict(env,EXPLORER_TEST_OUTPUT=str(tests)))
        verify_tests(folder/"controls",c["controls_required"])
        receipt["controls_passed"]=c["controls_required"]
        def unchanged():
            require(source_identity(False)==source and status()==initial_status and bindings()==receipt["bindings"],
                    "Envelope source/runtime drift")
        unchanged()
        invoke([sys.executable,"-B",str(Path(__file__).resolve()),"--worker","--contract",str(contract),
            "--core",str(core),"--output",str(folder/"computation")],folder/"worker",c["maximum_worker_wall_seconds"],env)
        result=json.loads((folder/"computation/result.json").read_bytes())
        require(result["ok"] is True and result["world_build_count"]==result["solver_steps"]==0
                and result["body_count"]==c["body_population"]["expected_distinct_bodies"],"Envelope worker completion")
        unchanged()
        receipt.update(ok=True,source_runtime_unchanged=True,result_sha256=sha(folder/"computation/result.json"),
            body_count=result["body_count"],limb_domain_minima=result["limb_domain_minima"],
            scalar_witness_checks=result["scalar_witness_checks"])
    except BaseException as exc:
        receipt["error"]=type(exc).__name__+": "+str(exc)
    finally:
        if acquired:release(handle)
        jobs.close(handle)
        receipt["wall_s"]=time.monotonic()-started
        receipt["artifacts"]=inventory(folder)
        write_new(folder/"receipt.json",receipt)
    print(json.dumps(dict(ok=receipt["ok"],output=str(folder),error=receipt.get("error"))))
    if not receipt["ok"]:raise SystemExit(1)


if __name__=="__main__":
    main()
