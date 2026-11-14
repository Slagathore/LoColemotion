"""Profile a retained startup packet through the production pure recovery route."""
import argparse
import copy
import ctypes as C
from ctypes import wintypes as W
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess
import sys
import time

ROOT=Path(__file__).resolve().parents[3]
for relative in ("sdk/discovery","sdk/conformance","sdk/explorer","sdk/explorer/studio","sdk/python","sdk/adapters/mujoco","sdk"):
    sys.path.insert(0,str(ROOT/relative))
from showcase_owner import Owner
from contained_stage_owner_v2 import jobs
from run_contact_sequence_native_v2 import invoke
from materialize_godot_context_cache import materialize
from materialize_godot_bridge_profile import instrument
from run_godot_cache_diagnostic import binding

EVIDENCE=ROOT.parent/"SporeSpore_Evidence"
HISTORICAL="development-recovery-smoke-0f483029e5e649ddad83f0d83eb7e138/children/kick_passive_recovery_resume/worker_report.json"
SCOPE=dict(subsystem="explorer",engine_scope="godot_jolt",authority_mode="retained_packet_cpu_diagnostic",question_class="development")
sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest()


def write(path,value):
    with Path(path).open("x",encoding="utf-8",newline="\n") as stream:
        json.dump(value,stream,indent=2,allow_nan=False);stream.write("\n")


def snapshot(value):
    raw=value["utf8_text"].encode("utf-8")
    assert len(raw)==value["utf8_byte_length"]
    assert "sha256:"+hashlib.sha256(raw).hexdigest()==value["raw_sha256"]
    return value


def extract():
    closure=json.loads((ROOT/"sdk/recovery/r10ap_progressive_headroom_closure_v1.json").read_bytes())
    source=EVIDENCE/HISTORICAL
    pin=next(r for r in closure["bindings"] if r["path"].replace("\\","/").endswith(HISTORICAL))
    raw=source.read_bytes()
    assert len(raw)==pin["byte_length"] and "sha256:"+hashlib.sha256(raw).hexdigest()==pin["raw_sha256"]
    report=json.loads(raw)
    prepared=snapshot(report["l15_prepared_context_comparison"]["observed_capture"])
    context=snapshot(json.loads(prepared["utf8_text"])["source_context"])
    arm=report["retained_arm"];packet=arm["last_recovery_collection_transport_retention"]
    step=arm["last_recovery_collection_transport_global_semantic_step"]
    assert step==report["precondition_terminal_receipt"]["completed_global_semantic_step"]==240
    return dict(schema_version="locolemotion_studio_startup_replay_packet_v1",ledger_scope=SCOPE,
        source_report=dict(archive_relative_path=HISTORICAL,sha256=pin["raw_sha256"],byte_length=len(raw)),
        global_step=step,context=context,sources={k:snapshot(v) for k,v in packet["source_links"].items()},
        request=snapshot(packet["request"]),response=snapshot(packet["response"]),
        expected_step=report["precondition_terminal_receipt"]["recovery_step_receipt"])


def profile_canonicalization(project):
    path=project/"sdk/adapters/godot/gdscript/recovery_runtime.gd"
    source=path.read_text(encoding="utf-8-sig")
    begin=source.index("static func canonicalize(")
    end=source.index("\n\nstatic func ",begin)
    original=source[begin:end]
    expected='''static func canonicalize(sdk: Object, value: Variant) -> Dictionary:
\treturn _decode_envelope(
\t\tsdk.canonicalize_json(
\t\t\tJsonTransportScript.stringify(
\t\t\t\t{
\t\t\t\t\t"schema_version": CANONICAL_JSON_REQUEST_SCHEMA,
\t\t\t\t\t"value": value,
\t\t\t\t}
\t\t\t)
\t\t)
\t)
'''
    assert original.rstrip()==expected.rstrip(),"Canonicalization source changed"
    replacement='''static func canonicalize(sdk: Object, value: Variant) -> Dictionary:
\tvar start := Time.get_ticks_usec()
\tvar request := JsonTransportScript.stringify({"schema_version":CANONICAL_JSON_REQUEST_SCHEMA,"value":value})
\tvar serialized := Time.get_ticks_usec()
\tvar raw: String = sdk.canonicalize_json(request)
\tvar called := Time.get_ticks_usec()
\tvar result := _decode_envelope(raw)
\tvar decoded := Time.get_ticks_usec()
\tstartup_probe_profile["calls"] = startup_probe_profile.get("calls",0)+1
\tstartup_probe_profile["serialize_us"] = startup_probe_profile.get("serialize_us",0)+serialized-start
\tstartup_probe_profile["native_and_cache_us"] = startup_probe_profile.get("native_and_cache_us",0)+called-serialized
\tstartup_probe_profile["decode_us"] = startup_probe_profile.get("decode_us",0)+decoded-called
\tstartup_probe_profile["request_characters"] = startup_probe_profile.get("request_characters",0)+request.length()
\tstartup_probe_profile["response_characters"] = startup_probe_profile.get("response_characters",0)+raw.length()
\treturn result
'''
    source=source[:begin]+replacement+source[end:]
    source+="\nstatic var startup_probe_profile: Dictionary = {}\n"
    path.write_text(source,encoding="utf-8",newline="\n")


def profile_functions(project):
    """Wrap coarse pure boundaries; inclusive timers must not be added together."""
    modules={
        "sdk/adapters/godot/gdscript/recovery_runtime.gd": ["collect_native_v3_l15_v1","step_v5"],
        "sdk/adapters/godot/gdscript/qsdk_r10f_l15_collection_transport_v1.gd":
            ["prepare_v1","_retain_source_links_v1","complete_v1","bytes_v1"],
        "sdk/adapters/godot/gdscript/recovery_native_route_v1.gd":
            ["_l15_advance_sources_v1","collection_request_v1",
             "commissioned_discrete_staging_complete_energy_partition_authority_v1"],
        "sdk/explorer/studio/immutable_context_cache.gd": ["check"],
    }
    for relative,names in modules.items():
        path=project/relative;source=path.read_text(encoding="utf-8-sig")
        wrappers=[]
        for name in names:
            pattern=re.compile(r"static func "+re.escape(name)+r"\(([^)]*)\) -> (\w+):")
            matches=list(pattern.finditer(source))
            assert len(matches)==1,"Profile boundary changed: "+name
            match=matches[0]
            arguments=", ".join(part.strip().split(":")[0] for part in match[1].split(",") if part.strip())
            original="_startup_original_"+name
            wrappers.append(match[0]+"\n\tvar started := Time.get_ticks_usec()\n"
                +f"\tvar result: {match[2]} = {original}({arguments})\n"
                +"\tvar elapsed := Time.get_ticks_usec()-started\n"
                +f'\tvar row: Dictionary = startup_function_profile.get("{name}",{{"calls":0,"total_us":0}})\n'
                +"\trow.calls += 1\n\trow.total_us += elapsed\n"
                +f'\tstartup_function_profile["{name}"] = row\n\treturn result\n')
            source=source[:match.start()]+match[0].replace("func "+name+"(","func "+original+"(")+source[match.end():]
        source+="\nstatic var startup_function_profile: Dictionary = {}\n\n"+"\n".join(wrappers)
        path.write_text(source,encoding="utf-8",newline="\n")


def validate_probe(value):
    assert value["ok"] is True
    for key in ("world_build_count","solver_steps","native_physics_reads"):
        assert type(value[key]) is int and value[key]==0,key
    for key in ("collection_request_and_response_exact","step_receipt_exact","source_inputs_unchanged"):
        assert value[key] is True,key
    assert value["physical_acceptance_authority"] is value["release_authority"] is False
    rows=value["rows"]
    assert len(rows)==32
    assert [(r["mode"],r["repeat"]) for r in rows]==[
        (mode,repeat) for mode in ("fresh_cache","reused_cache") for repeat in range(16)]
    assert all(type(r["elapsed_us"]) is int and r["elapsed_us"]>=0 for r in rows)
    hashes=[r.get("full_route_output_sha256") for r in rows]
    assert len(set(hashes))==1
    if hashes[0] is not None:
        assert len(hashes[0])==64 and all(c in "0123456789abcdef" for c in hashes[0])
    if "validation_controls" in value:
        assert value["validation_controls"]["ok"] is True and not value["validation_controls"]["failures"]
        assert value["validation_controls"]["checks"]==2352


def reader_controls(value):
    edits=[lambda x:x.update(world_build_count=1),
        lambda x:x.update(collection_request_and_response_exact=False),
        lambda x:x["rows"][1].update(repeat=0),
        lambda x:x["rows"][0].update(full_route_output_sha256="0"*64)]
    for edit in edits:
        mutant=copy.deepcopy(value);edit(mutant)
        try:validate_probe(mutant)
        except AssertionError:continue
        raise AssertionError("Probe reader accepted a corruption control")
    return len(edits)


def audit(folder):
    """Reopen retained outputs, exact source snapshots and owned cleanup."""
    folder=Path(folder).resolve();assert folder.is_relative_to(EVIDENCE.resolve())
    receipt=json.loads((folder/"receipt.json").read_bytes())
    declaration=json.loads((folder/"declaration.json").read_bytes())
    assert receipt["ok"] is True and receipt["source_runtime_unchanged"] is True
    assert receipt["worlds_opened"]==receipt["solver_steps"]==0
    assert receipt["dependency_binding"]==declaration["dependency_binding"]
    assert sha(folder/"packet.json")==receipt["packet_sha256"]==declaration["packet_sha256"]
    assert sha(folder/"probe.json")==receipt["probe_sha256"]
    value=json.loads((folder/"probe.json").read_bytes());validate_probe(value)
    for name,digest in receipt["dependency_binding"].items():
        original=Path(name)
        saved=receipt.get("repository_source_snapshots",{}).get(name)
        if saved:
            target=(folder/saved).resolve();assert target.is_relative_to(folder)
        elif original.is_relative_to(ROOT):
            # Earlier CPU comparison archived unchanged sources in its parent.
            target=folder.parent/"source_snapshot"/original.relative_to(ROOT)
        else:
            target=original.resolve();assert target.is_relative_to(EVIDENCE.resolve())
        assert sha(target)==digest,str(target)
    cleanup=json.loads((folder/"owned/cleanup.json").read_bytes())
    assert cleanup["ok"] and not cleanup["members"] and not cleanup["errors"]
    assert all((folder/"owned"/name).exists() for name in ("stdout.log","stderr.log"))
    return dict(ok=True,source_runtime_bindings_verified=len(receipt["dependency_binding"]),
        route_replays=len(value["rows"]),reader_refusal_controls=reader_controls(value),
        original_streams_retained=True,
        worlds_opened=0,solver_steps=0,physical_acceptance_authority=False,release_authority=False)


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--config",type=Path);parser.add_argument("--output",type=Path)
    parser.add_argument("--audit",type=Path,help="Reopen a completed retained CPU probe without invoking Godot")
    args=parser.parse_args()
    if args.audit:
        print(json.dumps(audit(args.audit)));return 0
    if args.config is None or args.output is None:parser.error("--config and --output are required for a new probe")
    git=lambda *a:subprocess.check_output(["git",*a],cwd=ROOT,text=True).strip()
    assert git("rev-parse","--show-toplevel")=="C:/Users/Cole/CodeStuff/games/LoColemotion"
    assert git("remote","get-url","origin")=="https://github.com/Slagathore/LoColemotion.git"
    assert git("config","core.hooksPath")==".githooks"
    folder=args.output.resolve();assert folder.is_relative_to(EVIDENCE.resolve())
    folder.mkdir(parents=True,exist_ok=False)
    cfg=json.loads(args.config.read_bytes());cfg.update(source_commit=git("rev-parse","HEAD"),evidence_root=str(folder))
    receipt=dict(ledger_scope=SCOPE,source_commit=cfg["source_commit"],ok=False,worlds_opened=0,solver_steps=0,
        physical_acceptance_authority=False,release_authority=False)
    owner=None;acquired=False
    create=jobs.api("CreateMutexW",[C.c_void_p,W.BOOL,W.LPCWSTR],W.HANDLE);release=jobs.api("ReleaseMutex",[W.HANDLE])
    handle=jobs.checked(create(None,False,"Global\\SporeSpore.Locomotion.PhysicalConformance.Serial.v1"))
    started=time.monotonic()
    try:
        if jobs.wait(handle,0) not in (0,128):raise RuntimeError("Native operation occupied")
        acquired=True
        packet=extract();write(folder/"packet.json",packet)
        receipt["packet_sha256"]=sha(folder/"packet.json")
        owner=Owner(cfg,folder)
        assert owner.identity["recovery_dll"]["sha256"]=="76d05482da331ee4ed423f82672e2bf429222cd0efdeafa2f4f20c50a6023b81"
        receipt["runtime"]=owner.identity
        project=owner.prepare_recovery(folder);materialize(project);instrument(project);profile_canonicalization(project)
        profile_functions(project)
        shutil.copy2(ROOT/"sdk/explorer/studio/startup_packet_probe.gd",project/"sdk/explorer/studio/startup_packet_probe.gd")
        receipt["dependency_binding"]=binding(project)
        # Preserve any uncommitted diagnostic source by its exact bound bytes.
        # The isolated runtime is already retained under recovery_app.
        receipt["repository_source_snapshots"]={}
        for source_name,digest in receipt["dependency_binding"].items():
            source_path=Path(source_name)
            if source_path.is_relative_to(ROOT):
                target=folder/"source_snapshot"/source_path.relative_to(ROOT)
                target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(source_path,target)
                assert sha(target)==digest
                receipt["repository_source_snapshots"][source_name]=str(target.relative_to(folder))
        write(folder/"declaration.json",receipt)
        invoke([cfg["recovery_console"],"--headless","--path",str(project),"--script","res://sdk/explorer/studio/startup_packet_probe.gd"],
            folder/"owned",60,dict(STUDIO_STARTUP_PROBE_INPUT=str(folder/"packet.json"),STUDIO_STARTUP_PROBE_OUTPUT=str(folder/"probe.json")))
        result=json.loads((folder/"probe.json").read_bytes())
        validate_probe(result)
        assert receipt["dependency_binding"]==binding(project)
        for row in owner.identity.values():assert sha(row["path"])==row["sha256"]
        receipt.update(ok=True,probe_sha256=sha(folder/"probe.json"),source_runtime_unchanged=True)
    except BaseException as exc:
        receipt["error"]=type(exc).__name__+": "+str(exc)
    finally:
        if owner:owner.close()
        if acquired:release(handle)
        jobs.close(handle)
        receipt["wall_s"]=time.monotonic()-started;write(folder/"receipt.json",receipt)
    if receipt["ok"]:write(folder/"audit.json",audit(folder))
    print(json.dumps({k:v for k,v in receipt.items() if k in ("ok","error","wall_s","worlds_opened")}))
    return 0 if receipt["ok"] else 1


if __name__=="__main__":raise SystemExit(main())
