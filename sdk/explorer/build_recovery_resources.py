"""Maintainer-only source projection, never called by the installed showcase.

Snapshot the existing recovery route's transitive resource bytes into a
deterministic source archive. This removes runtime dependence on the game/lab
checkout without editing any historical worker or scientific record. Native
binaries remain separately supplied, hash-bound dependencies.
"""
import hashlib
import json
from pathlib import Path
import re
import zipfile

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent


def main():
    todo = ["sdk/explorer/native_recovery/worker.gd",
        "sdk/development/recovery_schedules/r10ap-progressive-headroom-v1.json",
        "sdk/python/sporespore_locomotion.py"]
    mujoco = ROOT/"sdk/adapters/mujoco"
    todo += [p.relative_to(ROOT).as_posix() for p in (mujoco/"sporespore_mujoco_adapter").glob("*.py")]
    todo += [p.relative_to(ROOT).as_posix() for p in mujoco.glob("*.json")]
    seen = set(); files = []; external = []
    while todo:
        relative = todo.pop()
        if "\\" in relative or ".." in Path(relative).parts or Path(relative).as_posix()!=relative:
            continue
        if relative in seen: continue
        seen.add(relative)
        path = ROOT / relative
        if not path.is_file(): continue
        if path.suffix in (".dll", ".exe"):
            external.append(relative); continue
        data = path.read_bytes()
        if not relative.startswith("sdk/explorer/"):
            files.append(dict(path=relative, sha256=hashlib.sha256(data).hexdigest(), byte_length=len(data)))
        if path.suffix in (".gd", ".json", ".gdextension"):
            for resource in re.findall(r'''res://([^\s"'<>]+)''',data.decode("utf-8-sig")):
                if (ROOT/resource).is_file(): todo.append(resource)
        if path.suffix == ".py":
            for name in re.findall(r'''["']([^"'\s/]+\.json)["']''',data.decode("utf-8-sig")):
                for candidate in (ROOT/"sdk"/name,path.parent/name,mujoco/name):
                    if candidate.is_file(): todo.append(candidate.relative_to(ROOT).as_posix())
        if path.suffix == ".json":
            # Follow executable contract bindings, not the historical evidence
            # graph or source-build inventories embedded in those records.
            def contracts(value):
                if isinstance(value,dict):
                    for key,item in value.items():
                        if (key.endswith("_contract") or key in ("native_component_record","runtime_binding")) and isinstance(item,str) and item.startswith("sdk/") and (ROOT/item).is_file():
                            todo.append(item)
                        elif isinstance(item,(dict,list)): contracts(item)
                elif isinstance(value,list):
                    for item in value: contracts(item)
            contracts(json.loads(data))
    files.sort(key=lambda row: row["path"])
    archive = HERE / "recovery_sources.zip"
    with zipfile.ZipFile(archive,"w",compression=zipfile.ZIP_DEFLATED,compresslevel=9) as out:
        for row in files:
            info=zipfile.ZipInfo(row["path"],date_time=(2026,10,3,0,0,0))
            info.compress_type=zipfile.ZIP_DEFLATED
            out.writestr(info,(ROOT/row["path"]).read_bytes())
    manifest=dict(schema_version="sporespore_explorer_recovery_source_projection_v1",
        ledger_scope=dict(subsystem="explorer",engine_scope="godot",authority_mode="source_projection",question_class="development"),
        scope="Byte-preserving source projection; no historical evidence promotion or native binaries",
        archive_sha256=hashlib.sha256(archive.read_bytes()).hexdigest(),files=files,
        referenced_external_binaries=sorted(external), physical_acceptance_authority=False,release_authority=False)
    (HERE/"recovery_sources.json").write_text(json.dumps(manifest,indent=2)+"\n",encoding="utf-8",newline="\n")
    print(f"Projected {len(files)} source resources; {archive.stat().st_size} compressed bytes; binaries excluded")


if __name__=="__main__": main()
