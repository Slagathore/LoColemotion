"""Paired virtual-torso targets across exposed anchor and sweep profiles."""
import copy
import hashlib
import json
import math
from pathlib import Path

from creature_batch import require
import creature_contact_reach as contact
import creature_contact_reach_search as previous
import creature_righting as righting
import creature_torso_target as torso
import creature_trajectory_search as trajectory

ROOT = Path(__file__).resolve().parents[2]
SOURCE = dict(path="sdk/discovery/creature_contact_reach_v1.json", sha256="c06d9dde5b47d3247ce1b6b8d2e7bb04e7cb87af5aec11b217cc4cc9a4462cf3")
LEGACY_SOURCE = dict(commit="b18ab9f681ead98e8b15b2f9c7b5e184861aeed8",
    path="sdk/discovery/creature_contact_reach.py", sha256="1f512e2e7dd917f5312cc2a6554e456a599dec605de364a44ef5df382dc7a5ea")
RECIPE = dict(schema_version="locolemotion_torso_target_search_v1", seed=1061125,
    source_contract=SOURCE, route_body_index=1, route_outer_steps=360,
    rotation_degrees=[15.,30.,60.], pivots=["root","torso_edge"])


def source():
    raw=(ROOT/SOURCE["path"]).read_bytes()
    require(hashlib.sha256(raw).hexdigest()==SOURCE["sha256"], "Torso source binding")
    return json.loads(raw)["righting_spec"]


def spec(recipe, *, route=False):
    require(recipe == RECIPE, "Torso frozen recipe")
    original=source();profiles=copy.deepcopy(original["profiles"][:2]);mapping={}
    for old_index,p in enumerate(original["profiles"]):
        if p.get("strategy") not in ("anchor","sweep"):continue
        indices=[len(profiles)];profiles.append(copy.deepcopy(p))
        variant=int(p["id"].split("_")[1]);family=int(p["strategy"]=="sweep")
        for pivot in RECIPE["pivots"]:
            value=copy.deepcopy(p);value["id"]+="_"+pivot
            value["torso_target"]=dict(schema_version=torso.SCHEMA,pivot=pivot,
                maximum_rotation_rad=math.radians(RECIPE["rotation_degrees"][(variant+family)%3]),
                ramp_steps=60 if variant%2==0 else 120,rise_m=0. if variant%2==0 else .02)
            indices.append(len(profiles));profiles.append(contact.profile(value))
        mapping[old_index]=indices
    rows=[]
    for row in original["profiles_by_body"]:
        rows.append([0,1]+[i for old in row if old in mapping for i in mapping[old]])
    result=copy.deepcopy(original);result.update(profiles=profiles,profiles_by_body=rows)
    if route:
        index=recipe["route_body_index"]
        result.update(schema_version=righting.SCHEMA,descriptors=[result["descriptors"][index]],
            profiles=[profiles[i] for i in rows[index]])
        del result["profiles_by_body"]
    return result


def source_dependencies(c):
    return ([ROOT/SOURCE["path"],ROOT/"sdk/discovery/creature_torso_target_v1.json",
             ROOT/"sdk/discovery/creature_torso_target_route_v1.json"] if "torso_target_search" in c else [])


def validate(c):
    opted=any("torso_target" in p for p in c.get("righting_spec",{}).get("profiles",[]))
    require(not opted or "torso_target_search" in c,"Torso target requires its declared gate")
    if "torso_target_search" not in c:return
    require(c["torso_target_search"]==RECIPE and c["mode"] in ("route_ghost","development_discovery")
        and not any(k in c for k in ("trajectory_proposal","trajectory_retiming","joint_braking_search","contact_reach_search"))
        and c["trajectory_screen"]==trajectory.POLICY,"Torso target declaration scope")
    route=c["mode"]=="route_ghost"
    require(c["righting_spec"]==spec(RECIPE,route=route)
        and c["outer_steps"]==(RECIPE["route_outer_steps"] if route else 1440)
        and c["maximum_worlds_per_batch"]==14 and c["seed"]==RECIPE["seed"],"Torso population or clock drift")


def route_report(rows,profiles):
    by_id={p["id"]:p for p in profiles};counts={p:dict(active_projections=0,nonzero_rotation=0,
        changed_projection_geometry=0) for p in RECIPE["pivots"]}
    def counted_rows():
        for row in rows:
            accumulate(row)
            yield row
    def accumulate(row):
        p=by_id[row["binding"]["candidate_id"]]
        if "torso_target" not in p:return
        for choice in row["resolution"]["contact_reach"]["state_after"]["choices"]:
            if choice is None:continue
            projection=choice["torso_target_projection"]
            if not projection["active"]:continue
            count=counts[p["torso_target"]["pivot"]];frame=projection["virtual_frame"]
            count["active_projections"]+=1
            count["nonzero_rotation"]+=frame["applied_rotation_rad"]>1e-8
            count["changed_projection_geometry"]+=any(abs(a-b)>1e-8 for a,b in zip(
                choice["geometric_low_endpoint_world_m"],projection["actual_root_geometric_low_endpoint_world_m"],strict=True))
            require(frame["root_is_actuated_or_teleported"] is False,"Torso projection claims root actuation")
    contact_report=previous.route_report(counted_rows(),profiles,strategies=("anchor","sweep"))
    require(all(all(v>0 for v in count.values()) for count in counts.values()),"Torso route projection coverage incomplete")
    return dict(contact_coverage=contact_report,projection_counts=counts,complete=True,recovery_qualified=False)


def verify_route(folder,receipt):
    require(receipt["contract"]["mode"]=="route_ghost" and receipt["audit"]["capture"]["controller_replay_verified"]
        and receipt["audit"]["capture"]["within_run_projection_verified"],"Torso route full replay required")
    paths=[Path(folder)/"native"/g["batch_id"]/"controller.jsonl" for g in receipt["audit"]["batches"]]
    if "artifacts" in receipt:
        inventory={a["path"]:a for a in receipt["artifacts"]}
        for path in paths:
            bound=inventory[path.relative_to(folder).as_posix()]
            require(path.stat().st_size==bound["bytes"]
                and hashlib.sha256(path.read_bytes()).hexdigest()==bound["sha256"],"Torso route stream binding")
    def rows():
        for path in paths:
            with path.open(encoding="utf-8") as stream:
                for line in stream:yield json.loads(line)
    return route_report(rows(),receipt["contract"]["righting_spec"]["profiles"])
