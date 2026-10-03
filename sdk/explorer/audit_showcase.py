"""Read-only audit of finite standalone Explorer interface evidence.

This checks M20 app behavior, not new locomotion or recovery acceptance.
It creates no physics world and never executes a retained command.
"""
import argparse
import hashlib
import json
from pathlib import Path
import sys

from showcase_model import ENGINES, PROTOCOL, SCOPE, StreamIdentity, sha

SDK=Path(__file__).resolve().parents[1]


def require(value, detail):
    if not value: raise ValueError(detail)


def bound_file(binding):
    path=Path(binding["path"])
    require(path.is_file() and sha(path)==binding["sha256"],"Artifact digest: "+str(path))
    return path


def audit(closure):
    require(closure["schema_version"]=="sporespore_explorer_interface_closure_v1","Closure schema")
    require(closure["status"]=="closed_finite_standalone_interface_validation","Closure status")
    require(closure["physical_acceptance_authority"] is False and closure["release_authority"] is False,"Authority overclaim")
    require(closure["isolated_sdk_without_git_or_game_project"] is True,"Standalone layout missing")
    require(set(closure["engines"])==set(ENGINES),"Three-engine population")
    results={}
    for engine,cell in closure["engines"].items():
        receipt=json.loads(bound_file(cell["receipt"]).read_text(encoding="utf-8"))
        ui_log=bound_file(cell["ui_log"]).read_text(encoding="utf-8")
        require("SHOWCASE_NATIVE_UI_PASS" in ui_log and "engine="+engine in ui_log,"Native UI did not pass")
        require(receipt["ok"] is True and receipt["engine"]==engine,"Invalid physical interface receipt")
        require(receipt["physical_acceptance_authority"] is False and receipt["release_authority"] is False,"Native observation promoted")
        require(receipt["preflight"]["completed"]["ok"] is True and receipt["preflight"]["completed"]["summary"]["world_build_count"]==0,"Preflight missing")
        require({"explorer/showcase_owner.py","explorer/showcase.gd","explorer/showcase_model.py",
            "explorer/native_recovery/worker.gd","explorer/recovery_sources.zip","explorer/recovery_sources.json",
            "conformance/r10v_windows_job.py"} <= set(receipt["source_binding"]["files"]),"Incomplete source binding")
        for relative,digest in receipt["source_binding"]["files"].items():
            path=(SDK/relative).resolve()
            require(path.is_relative_to(SDK.resolve()) and path.is_file() and sha(path)==digest,"Current interface source drift: "+relative)
        physical=receipt["physical"]
        stream=bound_file(cell["stream"])
        require(sha(stream)==physical["stream_sha256"],"Physical stream mismatch")
        identity=physical["hello"]
        guard=StreamIdentity(identity["session_id"],engine,receipt["source_commit"],False)
        applied=[]; frames=0; phases=set(); completed=None
        with stream.open(encoding="utf-8") as data:
            for line in data:
                row=json.loads(line);kind=guard.accept(row)
                if kind=="frame":
                    frames+=1;applied.extend(row.get("applied_impulses",[]));phases.add(row.get("phase","native_walking"))
                if kind=="completed": completed=row
        require(completed is not None and completed["ok"] is True and frames>0,"Incomplete native stream")
        require(len(applied)==1 and applied==physical["applied_impulses"],"Native impulse application missing or duplicated")
        require(guard.last_frame==physical["last_frame"] and guard.last_frame>720,"Native horizon coverage incomplete")
        if engine=="godot_jolt":
            require(receipt["request"]["phase"]==74,"Godot declared development phase drift")
            require(completed["summary"]["walking_shutdown"]["ok"] is True,"Godot controller shutdown")
            require("fresh_selected_policy_walking_prefix" in phases and "measured_upright_stabilization" in phases,"Recovery production path missing")
        results[engine]=dict(native_frames=frames,last_frame=guard.last_frame,applied_impulses=len(applied),outcome=completed.get("outcome"),phases=sorted(phases))
    ui=bound_file(closure["visible_ui"]["log"]).read_text(encoding="utf-8")
    require("SHOWCASE_UI_PASS" in ui,"Visible construction/editing UI check missing")
    bound_file(closure["visible_ui"]["screenshot"])
    require(closure["visible_ui"]["visually_reviewed"] is True,"Visual review missing")
    return dict(schema_version="sporespore_explorer_interface_audit_v1",ledger_scope=SCOPE,ok=True,
        sdk1_m20_passed=True,engines=results,world_build_count=0,solver_step_count=0,
        physical_acceptance_authority=False,release_authority=False)


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--closure",type=Path,default=SDK/"explorer/showcase_closure_v1.json")
    parser.add_argument("--output",type=Path)
    args=parser.parse_args()
    try: result=audit(json.loads(args.closure.read_text(encoding="utf-8")))
    except Exception as exc:
        print(json.dumps(dict(ok=False,error=str(exc),world_build_count=0)));return 1
    if args.output:
        with args.output.open("x",encoding="utf-8") as out: json.dump(result,out,indent=2)
    print(json.dumps(result,indent=2));return 0


if __name__=="__main__": raise SystemExit(main())
