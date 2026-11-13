"""Floor-contact moment bounds and nonadjacent clearance for fixed poses.

This is a sampled geometric proposal screen. No contact force, actuator effort,
pose transition or dynamic recovery is certified.
"""
import itertools
import math
import numpy as np

from actuation_recovery_mechanics import array, require
from creature_righting_geometry import MAX_POSES, PoseGeometry, unit_up

TOLERANCE_M = 1e-9


def segments(value, name):
    raw = np.asarray(value)
    require(raw.ndim == 3 and raw.shape[1:] == (2, 3) and 0 < len(raw) <= MAX_POSES,
            name+" segment population")
    result = array(raw, raw.shape, name+" finite segments")
    require(np.max(np.abs(result)) <= 1e6, name+" coordinate bound")
    return result


def segment_segment_distance(first, second):
    """Global rectangle minimum: four edge projections and the interior."""
    first = segments(first, "First"); second = segments(second, "Second")
    require(first.shape == second.shape, "Segment pair population")
    p, q = first[:, 0], second[:, 0]
    u, v = first[:, 1]-p, second[:, 1]-q
    w = p-q
    a = np.sum(u*u, axis=1); c = np.sum(v*v, axis=1)
    best = np.full(len(p), np.inf)

    def consider(s, t, valid=True):
        nonlocal best
        delta = w+np.clip(s, 0., 1.)[:, None]*u-np.clip(t, 0., 1.)[:, None]*v
        distance2 = np.sum(delta*delta, axis=1)
        best = np.minimum(best, np.where(valid, distance2, np.inf))

    for s in (0., 1.):
        t = np.divide(np.sum((w+s*u)*v, axis=1), c, out=np.zeros_like(c), where=c>0)
        consider(np.full(len(p), s), t)
    for t in (0., 1.):
        s = np.divide(np.sum((t*v-w)*u, axis=1), a, out=np.zeros_like(a), where=a>0)
        consider(s, np.full(len(p), t))
    # Cross products avoid cancellation in a*c-(u.v)**2 near parallelism.
    cross = np.cross(u, v); determinant = np.sum(cross*cross, axis=1)
    s = np.divide(np.sum(np.cross(v, w)*cross, axis=1), determinant,
                  out=np.zeros_like(a), where=determinant>0)
    t = np.divide(np.sum(np.cross(u, w)*cross, axis=1), determinant,
                  out=np.zeros_like(a), where=determinant>0)
    consider(s, t, (determinant>0) & (s>=0) & (s<=1) & (t>=0) & (t<=1))
    require(np.isfinite(best).all(), "Segment distance arithmetic")
    return np.sqrt(best)


def segment_box_distance(value, half):
    """Exact piecewise-quadratic distance from segments to an axis-aligned box."""
    value = segments(value, "Box"); half = array(half, (3,), "Box half extents")
    require((half>0).all() and np.max(half)<=1e6, "Positive bounded box")
    p = value[:, 0]; d = value[:, 1]-p
    knots = [np.zeros(len(p)), np.ones(len(p))]
    for axis in range(3):
        for sign in (-1., 1.):
            t = np.divide(sign*half[axis]-p[:, axis], d[:, axis],
                          out=np.zeros(len(p)), where=d[:, axis]!=0)
            knots.append(np.clip(t, 0., 1.))
    knots = np.sort(np.stack(knots, axis=1), axis=1)
    best = np.full(len(p), np.inf)
    for i in range(knots.shape[1]-1):
        low, high = knots[:, i], knots[:, i+1]
        middle = (low+high)/2
        point = p+middle[:, None]*d
        outside = np.abs(point)>half
        offset = p-np.where(point>=0, half, -half)
        numerator = np.sum(np.where(outside, offset*d, 0.), axis=1)
        denominator = np.sum(np.where(outside, d*d, 0.), axis=1)
        t = np.divide(-numerator, denominator, out=middle.copy(), where=denominator>0)
        point = p+np.clip(t, low, high)[:, None]*d
        distance2 = np.sum((point-np.clip(point, -half, half))**2, axis=1)
        best = np.minimum(best, distance2)
    require(np.isfinite(best).all(), "Box distance arithmetic")
    return np.sqrt(best)


def moment_bounds(points, center, up, axis, friction):
    """Signed torque per unit normal force, in metres, about the declared axis."""
    points = np.asarray(points); center = np.asarray(center)
    require(points.ndim == 3 and points.shape[2] == 3 and 0<len(points)<=24*MAX_POSES,
            "Moment point population")
    points = array(points, points.shape, "Moment finite points")
    center = array(center, (len(points), 3), "Moment center of mass")
    require(np.max(np.abs(points))<=1e6 and np.max(np.abs(center))<=1e6, "Moment coordinate bound")
    up = unit_up(up); axis = unit_up(axis)
    require(abs(float(up @ axis))<=1e-12 and type(friction) in (int, float)
            and math.isfinite(friction) and 0<=friction<=2, "Moment axis/friction")
    lever = np.cross(axis, points-center[:, None, :])
    normal = lever @ up
    tangent = lever-normal[:, :, None]*up
    extent = friction*np.linalg.norm(tangent, axis=2)
    return normal, normal-extent, normal+extent


class PoseContacts:
    """Own fixed-pose geometry, all support-feature vertices and collision gaps."""
    def __init__(self, spec, poses):
        self.geometry = PoseGeometry(spec, poses)
        model = self.geometry; tree = model.tree
        require(len(tree.bodies)==9 and model.shapes[0][0]=="box"
                and all(kind=="capsule" for kind, _ in model.shapes[1:])
                and tree.parent==[0,1,0,3,0,5,0,7],
                "Moment four ordered two-joint limbs")
        self.distal = np.array([2,4,6,8])
        require([tree.index[s["body_id"]] for s in spec["contact_sites"]]==self.distal.tolist(),
                "Moment ordered distal contacts")
        corners = np.asarray(list(itertools.product((-1.,1.), repeat=3)))*model.shapes[0][1]
        points = [np.broadcast_to(corners, (len(model.poses),8,3)).copy()]
        feature_body = [0]*8; radii = [0.]*8
        self.ends = {}
        for b in range(1,9):
            half, radius = model.shapes[b][1]
            offset = model.rotations[:,b,:,1]*half
            ends = np.stack((model.positions[:,b]-offset, model.positions[:,b]+offset), axis=1)
            self.ends[b] = ends
            points.append(ends); feature_body.extend([b,b]); radii.extend([radius,radius])
        self.points = np.concatenate(points, axis=1)
        self.feature_body = np.asarray(feature_body)
        self.radii = np.asarray(radii)
        self.feature_bits = (1<<self.feature_body).astype(np.uint16)
        adjacent = {tuple(sorted(pair)) for pair in zip(tree.parent,tree.child)}
        self.pairs = [pair for pair in itertools.combinations(range(9),2) if pair not in adjacent]
        gaps = []
        for left,right in self.pairs:
            if left==0:
                distance = segment_box_distance(self.ends[right],model.shapes[0][1])
                gap = distance-model.shapes[right][1][1]
            else:
                distance = segment_segment_distance(self.ends[left],self.ends[right])
                gap = distance-model.shapes[left][1][1]-model.shapes[right][1][1]
            gaps.append(gap)
        self.gaps = np.stack(gaps, axis=1)
        self.minimum_gap = np.min(self.gaps,axis=1)
        self.minimum_pair = np.argmin(self.gaps,axis=1)
        self.clear = self.minimum_gap>=-TOLERANCE_M
        hips = np.array([[tree.joints[2*i]["anchor_parent_m"][k] for k in "xyz"] for i in range(4)])
        signs = np.sign(hips[:,0]); require(np.all(signs!=0),"Moment front/rear limb identity")
        pair_poses = model.poses.reshape(-1,4,2)
        self.outward = np.all(pair_poses*signs[None,:,None]>=-1e-12,axis=2)
        self.inward = np.all(pair_poses*signs[None,:,None]<=1e-12,axis=2)
        self.hips = hips
        for x in (self.points,self.feature_body,self.radii,self.feature_bits,self.gaps,
                  self.minimum_gap,self.minimum_pair,self.clear,self.outward,self.inward,self.hips):
            x.setflags(write=False)

    def evaluate(self, up, axis, friction):
        up = unit_up(up)
        low = self.points @ up-self.radii
        minimum = np.min(low,axis=1)
        touching = low<=minimum[:,None]+TOLERANCE_M
        rows,features=np.nonzero(touching)
        points=self.points[rows,features]-self.radii[features,None]*up
        normal,_,upper=moment_bounds(points[:,None,:],self.geometry.com[rows],up,axis,friction)
        normal=normal[:,0];upper=upper[:,0];bodies=self.feature_body[features]
        def mask(condition):
            result=np.zeros(len(low),dtype=np.uint16)
            np.bitwise_or.at(result,rows[condition],self.feature_bits[features[condition]])
            return result
        # Evaluate forces only at support features; retain every pose's masks.
        masks=dict(contact=mask(np.ones(len(rows),dtype=bool)),
                   normal_positive=mask(normal>TOLERANCE_M),friction_positive=mask(upper>TOLERANCE_M))
        def maximum(values):
            result=np.full((len(low),9),-np.inf)
            np.maximum.at(result,(rows,bodies),values)
            return result
        return dict(floor_height_m=-minimum,normal=maximum(normal),friction=maximum(upper),
                    masks=masks,contact_features=touching)

    def summary(self, result, axis):
        normal = result["normal"]; friction = result["friction"]
        n = len(normal); selected = np.argsort(-(np.cross(self.hips,[0.,-1.,0.]) @ axis),kind="stable")[:2]
        categories = {
            "distal_all": np.ones((n,4),dtype=bool),
            "distal_outward":self.outward,
            "distal_inward":self.inward,
            "distal_initial_selected":np.broadcast_to(np.isin(np.arange(4),selected),(n,4)),
        }
        groups = {}
        witnesses = []
        for name, allowed in categories.items():
            m = np.where(allowed,normal[:,self.distal],-np.inf)
            f = np.where(allowed,friction[:,self.distal],-np.inf)
            touch = np.isfinite(m).any(axis=1)
            entry = dict(contact_poses=int(touch.sum()),
                clear_contact_poses=int(np.count_nonzero(touch & self.clear)),
                clear_positive_normal_poses=int(np.count_nonzero((m>TOLERANCE_M).any(axis=1)&self.clear)),
                clear_positive_friction_bound_poses=int(np.count_nonzero((f>TOLERANCE_M).any(axis=1)&self.clear)))
            for label,values in (("normal",m),("friction",f)):
                candidates = np.where(self.clear[:,None],values,-np.inf)
                index = int(np.argmax(candidates)); pose,limb = divmod(index,4)
                value = float(candidates[pose,limb])
                entry["maximum_"+label+"_arm_m"] = value if math.isfinite(value) else None
                entry["witness_"+label] = dict(pose_index=pose,body_index=int(self.distal[limb])) if math.isfinite(value) else None
                if name=="distal_all" and math.isfinite(value):
                    witnesses.append((pose,int(self.distal[limb]),label))
            groups[name] = entry
        for name,bodies in (("proximal",[1,3,5,7]),("torso",[0])):
            m=normal[:,bodies];f=friction[:,bodies]
            groups[name]=dict(clear_contact_poses=int(np.count_nonzero(np.isfinite(m).any(axis=1)&self.clear)),
                clear_positive_normal_poses=int(np.count_nonzero((m>TOLERANCE_M).any(axis=1)&self.clear)),
                clear_positive_friction_bound_poses=int(np.count_nonzero((f>TOLERANCE_M).any(axis=1)&self.clear)))
        return groups,witnesses


def scalar_features(spec, pose, up, axis, friction):
    """Independent scalar rigid tree in world coordinates for retained witnesses."""
    from actuation_recovery_mechanics import RigidTree
    up=unit_up(up); axis=unit_up(axis)
    cross=np.cross(up,[0.,1.,0.]); length=float(np.linalg.norm(cross))
    if length<1e-14:
        quaternion=[0.,0.,0.,1.] if up[1]>0 else [1.,0.,0.,0.]
    else:
        half=math.acos(float(np.clip(up[1],-1.,1.)))/2
        quaternion=[*(cross/length*math.sin(half)),math.cos(half)]
    tree=RigidTree(spec)
    joints=[float(v)*(j["upper_limit_rad"] if v>=0 else -j["lower_limit_rad"])
            for v,j in zip(pose,tree.joints,strict=True)]
    frame=tree.kinematics([0.,0.,0.],quaternion,joints)
    world_axis=frame["rotations"][0] @ axis
    points=[];bodies=[]
    for b,body in enumerate(tree.bodies):
        shape=body["collision"];position=frame["positions"][b];rotation=frame["rotations"][b]
        if shape["kind"]=="box":
            half=np.array([shape["size_m"][k]/2 for k in "xyz"])
            local=[np.array(v)*half for v in itertools.product((-1.,1.),repeat=3)]
            radius=0.
        else:
            local=[np.array([0.,sign*shape["length_m"]/2,0.]) for sign in (-1.,1.)]
            radius=shape["radius_m"]
        for value in local:
            point=position+rotation @ value-np.array([0.,radius,0.])
            points.append(point);bodies.append(b)
    minimum=min(point[1] for point in points)
    normal=np.full(9,-np.inf);upper=np.full(9,-np.inf)
    contact=positive=friction_positive=0
    for point,b in zip(points,bodies,strict=True):
        if point[1]>minimum+TOLERANCE_M:continue
        r=point-frame["whole_body_com"]
        # Independent scalar expansion in the world frame: vertical and the
        # two horizontal force directions, rather than the batched projection.
        n=float(np.dot(np.cross(r,[0.,1.,0.]),world_axis))
        tx=float(np.dot(np.cross(r,[1.,0.,0.]),world_axis))
        tz=float(np.dot(np.cross(r,[0.,0.,1.]),world_axis))
        f=n+friction*math.hypot(tx,tz)
        normal[b]=max(normal[b],n);upper[b]=max(upper[b],f)
        contact |= 1<<b
        if n>TOLERANCE_M:positive |= 1<<b
        if f>TOLERANCE_M:friction_positive |= 1<<b
    return dict(floor_height_m=-minimum,normal=normal,friction=upper,
                masks=dict(contact=contact,normal_positive=positive,friction_positive=friction_positive))


OWNER_PREFIX="sdk2-contact-moment-v1-"
TEST_MODULES=("test_creature_contact_moment","test_creature_righting_geometry")
FALSE_FLAGS=("physical_started","trained","training_data_authority","physical_acceptance_authority",
             "release_authority","recovery_benefit_established","dynamic_feasibility_established")


def native_filter(creature):
    """Read the retained XML; never compile a simulator model."""
    import hashlib
    import xml.etree.ElementTree as ET
    xml=creature["model_xml"]
    require(hashlib.sha256(xml.encode()).hexdigest()==creature["binding"]["model_xml_sha256"],
            "Moment retained XML binding")
    root=ET.fromstring(xml);geoms=root.findall(".//geom")
    require(len(geoms)==10 and root.find("contact") is None,"Moment unexpected collision pairs")
    floor=[g for g in geoms if g.get("name")=="ground"]
    robot=[g for g in geoms if g.get("name")!="ground"]
    spec=creature["compiled"]["morphology"]["morphology_spec"]
    require(len(floor)==1 and floor[0].get("type")=="plane"
            and (floor[0].get("contype"),floor[0].get("conaffinity"))==("1","2")
            and {g.get("name") for g in robot}=={b["body_id"]+"_geom" for b in spec["bodies"]}
            and all((g.get("contype"),g.get("conaffinity"))==("2","1") for g in robot),
            "Moment native collision policy")
    frictions=[float(g.get("friction").split()[0]) for g in geoms]
    require(all(math.isfinite(f) and f==frictions[0] and 0<=f<=2 for f in frictions),
            "Moment shared native friction")
    return dict(robot_self_collisions_enabled=False,ground_collisions_enabled=True,
                sliding_friction_coefficient=frictions[0])


def read_archive(reference,evidence):
    import json
    from pathlib import Path
    from creature_righting_geometry import sha
    relative=Path(reference["archive_relative_path"])
    require(not relative.is_absolute() and ".." not in relative.parts,"Moment archive traversal")
    path=(evidence/relative).resolve(strict=True)
    require(path.is_relative_to(evidence.resolve(strict=True)),"Moment archive escape")
    for name,key in (("receipt.json","receipt_sha256"),("declaration.json","declaration_sha256"),
                     ("computation/result.json","result_sha256")):
        require(sha(path/name)==reference[key],"Moment retained input digest")
    owner=json.loads((path/"receipt.json").read_bytes())
    result=json.loads((path/"computation/result.json").read_bytes())
    require(owner["ok"] is True and owner["source_runtime_unchanged"] is True
            and owner["world_build_count"]==owner["solver_steps"]==0 and owner["physical_started"] is False
            and result["ok"] is True and result["world_build_count"]==result["solver_steps"]==0,
            "Moment incomplete zero-world predecessor")
    return path,owner,result


def declaration(path):
    import json
    from pathlib import Path
    from creature_righting_geometry import pose_pool,sha
    root=Path(__file__).resolve().parents[2];c=json.loads(Path(path).read_bytes())
    require(c["schema_version"]=="locolemotion_contact_moment_v1"
            and c["ledger_scope"]==dict(subsystem="discovery",engine_scope="core",
                authority_mode="zero_world_geometry_diagnostic",question_class="development"),
            "Moment declaration identity")
    require(c["axes_body"]==[[1.,0.,0.],[-1.,0.,0.],[0.,0.,1.],[0.,0.,-1.]]
            and c["progress_degrees"]==list(range(0,181,5)) and c["normalized_joint_limit"]==.9
            and c["numerical_tolerance_m"]==TOLERANCE_M and c["friction_coefficient"]==.95
            and c["controls_required"]==20 and c["body_count"]==334 and c["pose_count"]==7585
            and c["retention"]=="all_pose_contact_and_positive_moment_masks_with_all_nonadjacent_gaps"
            and all(c[k] is False for k in FALSE_FLAGS),"Moment declaration scope")
    require(type(c["maximum_control_wall_seconds"]) is int and 60<=c["maximum_control_wall_seconds"]<=600
            and type(c["maximum_worker_wall_seconds"]) is int and 60<=c["maximum_worker_wall_seconds"]<=3600,
            "Moment finite execution bounds")
    for name in ("predecessor","pose_bank_reference"):
        relative=Path(c[name]["path"]);target=(root/relative).resolve(strict=True)
        require(not relative.is_absolute() and ".." not in relative.parts and target.is_relative_to(root)
                and sha(target)==c[name]["sha256"],"Moment source input binding")
    pool=c["pose_pool"]
    bank=json.loads((root/c["pose_bank_reference"]["path"]).read_bytes())["pose_pool"]["limb_states"]
    require(pool["limb_states"]==bank,"Moment inherited factored limb bank")
    require(len(pose_pool(pool["limb_states"],pool["uniform_count"],pool["edge_count"],pool["seed"]))==c["pose_count"],
            "Moment pose denominator")
    return c


def source_paths(c):
    from pathlib import Path
    root=Path(__file__).resolve().parents[2]
    names=["sdk/discovery/.gitattributes","sdk/discovery/test_creature_contact_moment.py",
        "sdk/discovery/creature_contact_envelope.py","sdk/discovery/creature_righting_geometry.py",
        "sdk/discovery/test_creature_righting_geometry.py","sdk/discovery/actuation_recovery_mechanics.py",
        "sdk/discovery/creature_batch.py","sdk/discovery/creature_righting.py","sdk/explorer/showcase_model.py",
        "sdk/adapters/mujoco/sporespore_mujoco_adapter/selected_policy_development.py",
        c["predecessor"]["path"],c["pose_bank_reference"]["path"]]
    return [root/name for name in names]


def work(contract_path,core_path,output):
    from contextlib import ExitStack
    import json
    from pathlib import Path
    import time
    from unittest.mock import patch
    import mujoco
    from creature_contact_envelope import orientation_grid
    from creature_righting_geometry import pose_pool,sha,write_new
    root=Path(__file__).resolve().parents[2];evidence=(root.parent/"SporeSpore_Evidence").resolve(strict=True)
    c=declaration(contract_path);output=Path(output).resolve()
    require(output.is_relative_to(evidence) and not output.exists()
            and sha(core_path)==c["core_sha256"],"Moment fresh output/runtime")
    predecessor=json.loads((root/c["predecessor"]["path"]).read_bytes())
    retained,owner,parent=read_archive(predecessor["verification"],evidence)
    require(parent["body_count"]==c["body_count"]
            and [b["body_index"] for b in parent["bodies"]]==list(range(c["body_count"])),
            "Moment retained body population")
    recipe=c["pose_pool"]
    poses=pose_pool(recipe["limb_states"],recipe["uniform_count"],recipe["edge_count"],recipe["seed"])
    output.mkdir()
    with (output/"poses.npy").open("xb") as stream:np.save(stream,poses,allow_pickle=False)
    inventory={a["path"]:a for a in owner["artifacts"]}
    angles=c["progress_degrees"];axes=c["axes_body"];body_rows=[]
    scalar_checks=exclusion_checks=0;started=time.monotonic()
    totals={key:np.zeros((len(axes),len(angles)),dtype=np.int64) for key in
        ("clear_distal_contact_bodies","clear_positive_normal_bodies","clear_positive_friction_bound_bodies",
         "clear_inward_contact_bodies","clear_inward_positive_normal_bodies","clear_outward_positive_normal_bodies",
         "clear_initial_selected_positive_normal_bodies","clear_proximal_positive_normal_bodies")}
    with ExitStack() as trap:
        for name in ("MjModel","MjData","mj_step","mj_step1","mj_step2","mj_forward"):
            trap.enter_context(patch.object(mujoco,name,side_effect=AssertionError("Physics in moment diagnostic")))
        for body in parent["bodies"]:
            bi=body["body_index"];name=f"body_{bi:03d}"
            relative=f"computation/{name}_creature.json"
            require(sha(retained/relative)==inventory[relative]["sha256"],"Moment compiled body binding")
            creature=json.loads((retained/relative).read_bytes())
            require(creature["descriptor"]==body["descriptor"],"Moment crossed descriptor")
            policy=native_filter(creature)
            require(policy["sliding_friction_coefficient"]==c["friction_coefficient"],"Moment native friction freeze")
            spec=creature["compiled"]["morphology"]["morphology_spec"]
            model=PoseContacts(spec,poses)
            relative="computation/"+body["table_file"]
            require(sha(retained/relative)==body["table_sha256"]==inventory[relative]["sha256"],
                    "Moment continuous reach table binding")
            with np.load(retained/relative,allow_pickle=False) as table:
                reach=table["clearance_m"].copy()
            require(reach.shape==(3,4,4,181),"Moment inherited reach dimensions")
            masks={key:np.zeros((len(axes),len(angles),len(poses)),dtype=np.uint16)
                   for key in ("contact","normal_positive","friction_positive")}
            groups=[]
            for ai,axis in enumerate(axes):
                for ti,(degree,up) in enumerate(zip(angles,orientation_grid(angles,axis),strict=True)):
                    result=model.evaluate(up,axis,c["friction_coefficient"])
                    for key in masks:masks[key][ai,ti]=result["masks"][key]
                    summary,witnesses=model.summary(result,axis)
                    for di,domain in enumerate((np.ones_like(model.outward),model.outward,model.inward)):
                        for limb,bidx in enumerate(model.distal):
                            if reach[di,limb,ai,degree]>2*TOLERANCE_M:
                                require(not np.any(((result["masks"]["contact"] & (1<<bidx))!=0)&domain[:,limb]),
                                        "Moment contact contradicts continuous reach exclusion")
                                exclusion_checks+=1
                    for pose_index in sorted({0,*[w[0] for w in witnesses]}):
                        expected=scalar_features(spec,poses[pose_index],up,axis,c["friction_coefficient"])
                        require(abs(result["floor_height_m"][pose_index]-expected["floor_height_m"])<=3e-12,
                                "Moment scalar floor mismatch")
                        for key in ("normal","friction"):
                            actual=result[key][pose_index];wanted=expected[key];finite=np.isfinite(wanted)
                            require(np.array_equal(np.isfinite(actual),finite)
                                    and np.max(np.abs(actual[finite]-wanted[finite]))<=3e-12,
                                    "Moment scalar torque mismatch")
                        require(all(int(result["masks"][k][pose_index])==v for k,v in expected["masks"].items()),
                                "Moment scalar contact classification mismatch")
                        scalar_checks+=1
                    mapping={
                        "clear_distal_contact_bodies":("distal_all","clear_contact_poses"),
                        "clear_positive_normal_bodies":("distal_all","clear_positive_normal_poses"),
                        "clear_positive_friction_bound_bodies":("distal_all","clear_positive_friction_bound_poses"),
                        "clear_inward_contact_bodies":("distal_inward","clear_contact_poses"),
                        "clear_inward_positive_normal_bodies":("distal_inward","clear_positive_normal_poses"),
                        "clear_outward_positive_normal_bodies":("distal_outward","clear_positive_normal_poses"),
                        "clear_initial_selected_positive_normal_bodies":("distal_initial_selected","clear_positive_normal_poses"),
                        "clear_proximal_positive_normal_bodies":("proximal","clear_positive_normal_poses")}
                    for key,(category,metric) in mapping.items():totals[key][ai,ti]+=summary[category][metric]>0
                    groups.append(dict(axis_body=axis,progress_degrees=degree,categories=summary))
            filename=name+"_contacts.npz"
            with (output/filename).open("xb") as stream:
                np.savez_compressed(stream,**masks,nonadjacent_gaps_m=model.gaps,
                    minimum_pair_index=model.minimum_pair,nonadjacent_clear=model.clear)
            body_rows.append(dict(body_index=bi,descriptor=body["descriptor"],origin=body["origin"],
                input_path=f"computation/{name}_creature.json",
                input_sha256=inventory[f"computation/{name}_creature.json"]["sha256"],
                table_file=filename,table_sha256=sha(output/filename),
                pose_count=len(poses),nonadjacent_clear_poses=int(model.clear.sum()),
                nonadjacent_overlapping_poses=int(np.count_nonzero(~model.clear)),
                nonadjacent_pairs=[list(x) for x in model.pairs],native_collision_policy=policy,groups=groups))
            if (bi+1)%8==0 or bi+1==c["body_count"]:
                print(json.dumps(dict(bodies_complete=bi+1,total=c["body_count"],
                                     wall_s=time.monotonic()-started)),flush=True)
    result=dict(schema_version="locolemotion_contact_moment_result_v1",ledger_scope=c["ledger_scope"],ok=True,
        body_count=len(body_rows),poses_per_body=len(poses),pose_orientation_cases=len(body_rows)*len(poses)*len(axes)*len(angles),
        nonadjacent_pair_distances=len(body_rows)*len(poses)*28,
        scalar_witness_checks=scalar_checks,continuous_reach_exclusion_checks=exclusion_checks,
        total_nonadjacent_clear_body_poses=sum(b["nonadjacent_clear_poses"] for b in body_rows),
        total_nonadjacent_overlapping_body_poses=sum(b["nonadjacent_overlapping_poses"] for b in body_rows),
        poses_sha256=sha(output/"poses.npy"),progress_degrees=angles,axes_body=axes,
        body_counts_by_orientation={k:v.tolist() for k,v in totals.items()},bodies=body_rows,
        world_build_count=0,solver_steps=0,worker_new_sdk_compilations=0,**{k:False for k in FALSE_FLAGS},
        limits=c["limits"])
    write_new(output/"result.json",result)
    return result


if __name__=="__main__":
    import sys
    from geometry_diagnostic_owner import main
    main(sys.modules[__name__])
