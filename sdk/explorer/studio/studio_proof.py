"""Copy and verify a viewing subset while preserving original raw identities."""
from __future__ import annotations

from html.parser import HTMLParser
import json
from pathlib import Path
import shutil
import types
from urllib.parse import urlsplit

from studio_portability import SCOPE, binding, within, verify_files

SCHEMA = "locolemotion_studio_viewing_closure_v1"


def module(path, name):
    # Read-only verification must not create __pycache__ inside the pack.
    result = types.ModuleType(name)
    result.__file__ = str(path)
    exec(compile(path.read_bytes(), str(path), "exec"), result.__dict__)
    return result


class Resources(HTMLParser):
    def __init__(self):
        super().__init__()
        self.resources = []

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if tag == "script" and "src" in attrs:
            self.resources.append(attrs["src"])
        if tag == "link" and attrs.get("rel") == "stylesheet":
            self.resources.append(attrs["href"])


def curate(root, output, archive_root, source_commit):
    index = json.loads((root / "proof/EVIDENCE_INDEX.json").read_text())
    replay = json.loads((root / "replay/manifest.json").read_text())
    names = {r["path"] for r in index["local_files"]}
    names.update({"proof/EVIDENCE_INDEX.json", "sdk/publication/evidence.py", "sdk/publication/build_replay.py"})
    names.update(p.relative_to(root).as_posix() for p in (root / "replay").iterdir() if p.is_file())
    output.mkdir(parents=True, exist_ok=False)
    files = []
    for relative in sorted(names):
        original = within(root, relative)
        target = within(output, relative)
        target.parent.mkdir(parents=True, exist_ok=True)
        before = binding(original, relative)
        shutil.copy2(original, target)
        if binding(target, relative) != before or binding(original, relative) != before:
            raise ValueError("Viewing source changed while copying")
        files.append(before)
    raw_sources = []
    for record in replay["sources"]:
        source = within(archive_root, record["archive_relative_path"])
        relative = "raw/" + record["engine"] + "/stream.jsonl"
        row = dict(path=relative, byte_length=record["byte_length"], sha256=record["sha256"])
        if binding(source, relative) != row:
            raise ValueError("Original replay stream is missing or changed")
        target = within(output, relative)
        target.parent.mkdir(parents=True, exist_ok=False)
        shutil.copy2(source, target)
        files.append(row)
        raw_sources.append(dict(original=dict(record), local_path=relative))
    copied = {r["original"]["sha256"] for r in raw_sources}
    missing = [dict(id=r["id"], archive_relative_path=r["archive_relative_path"],
                    sha256=r["sha256"], byte_length=r["byte_length"])
               for r in index["external_artifacts"] if r["sha256"] not in copied and r["availability"] != "included_copy"]
    closure = dict(schema_version=SCHEMA, ledger_scope=SCOPE, source_commit=source_commit,
                   files=files, raw_sources=raw_sources, missing_scientific_dependencies=missing,
                   viewing_resource_closure_complete=True, complete_scientific_dependency_closure=False,
                   physical_acceptance_authority=False, release_authority=False)
    (output / "viewing-closure.json").write_text(json.dumps(closure, indent=2) + "\n", encoding="utf-8", newline="\n")
    verify(output)
    return closure


def verify(root):
    root = root.resolve()
    closure = json.loads((root / "viewing-closure.json").read_text())
    if closure["schema_version"] != SCHEMA or closure["viewing_resource_closure_complete"] is not True:
        raise ValueError("Viewing closure schema")
    for key in ["complete_scientific_dependency_closure", "physical_acceptance_authority", "release_authority"]:
        if closure[key] is not False:
            raise ValueError("Viewing closure overclaims")
    verify_files(root, closure["files"])
    actual = {p.relative_to(root).as_posix() for p in root.rglob("*") if p.is_file() and p.name != "viewing-closure.json"}
    if actual != {r["path"] for r in closure["files"]}:
        raise ValueError("Viewing closure population changed")
    reader = module(root / "sdk/publication/evidence.py", "studio_evidence_reader")
    index = json.loads((root / "proof/EVIDENCE_INDEX.json").read_text())
    report = reader.verify(index, root)
    replay = json.loads((root / "replay/manifest.json").read_text())
    projector = module(root / "sdk/publication/build_replay.py", "studio_replay_projector")
    raw = (root / "replay/bundle.js").read_text(encoding="utf-8")
    if not raw.startswith(projector.PREFIX) or not raw.endswith(projector.SUFFIX):
        raise ValueError("Replay bundle format")
    bundle = json.loads(raw[len(projector.PREFIX):-len(projector.SUFFIX)])
    if [r["original"] for r in closure["raw_sources"]] != replay["sources"]:
        raise ValueError("Crossed replay source identity")
    for row in closure["raw_sources"]:
        expected = dict(path=row["local_path"], byte_length=row["original"]["byte_length"], sha256=row["original"]["sha256"])
        if binding(within(root, row["local_path"]), row["local_path"]) != expected:
            raise ValueError("Raw stream differs from its original scientific identity")
    sessions = [projector.project_stream(within(root, r["local_path"]).read_bytes(), r["original"]["engine"])
                for r in closure["raw_sources"]]
    if sessions != bundle["sessions"]:
        raise ValueError("Viewing projection differs from original raw streams")
    copied = {r["original"]["sha256"] for r in closure["raw_sources"]}
    missing = [dict(id=r["id"], archive_relative_path=r["archive_relative_path"], sha256=r["sha256"], byte_length=r["byte_length"])
               for r in index["external_artifacts"] if r["sha256"] not in copied and r["availability"] != "included_copy"]
    if closure["missing_scientific_dependencies"] != missing:
        raise ValueError("Missing scientific dependency accounting changed")
    html = Resources()
    html.feed((root / "replay/index.html").read_text(encoding="utf-8"))
    for relative in html.resources:
        if urlsplit(relative).scheme or not within(root, "replay/" + relative).is_file():
            raise ValueError("Viewing requires a missing or network resource")
    return dict(ok=True, source_commit=closure["source_commit"], files_verified=len(closure["files"]),
                raw_streams_verified=len(sessions), viewing_frames=sum(s["published_frames"] for s in sessions),
                missing_scientific_dependencies=len(missing), worlds_opened=0,
                complete_scientific_dependency_closure=False, original_index_report=report)
