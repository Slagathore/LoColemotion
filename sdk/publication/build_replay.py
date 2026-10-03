"""Project retained Explorer poses into the public browser bundle. Opens no worlds."""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path, PurePosixPath

ROOT = Path(__file__).resolve().parents[2]
CLOSURE = "sdk/explorer/showcase_closure_v1.json"
PREFIX = "window.LOCO_REPLAY = "
SUFFIX = ";\n"


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def archive_relative(path: str) -> str:
    normalized = path.replace("\\", "/")
    marker = "/SporeSpore_Evidence/"
    if normalized.count(marker) != 1:
        raise ValueError("Unknown evidence root in source record")
    relative = normalized.split(marker, 1)[1]
    parts = PurePosixPath(relative).parts
    if not parts or any(part in {".", ".."} or ":" in part for part in parts):
        raise ValueError("Unsafe archive path")
    return relative


def project_stream(raw: bytes, engine: str) -> dict:
    messages = [json.loads(line) for line in raw.decode("utf-8").splitlines() if line.strip()]
    hello = next(row for row in messages if row["message_type"] == "hello")
    terminal = messages[-1]
    if terminal["message_type"] != "completed" or terminal.get("ok") is not True:
        raise ValueError(f"Incomplete retained stream: {engine}")
    if hello["engine_id"] != engine or terminal["session_id"] != hello["session_id"]:
        raise ValueError(f"Crossed stream identity: {engine}")
    scene = next((row["scene"] for row in messages if row["message_type"] == "scene"), hello.get("scene"))
    bodies = scene["morphology_spec"]["bodies"]
    body_ids = [body["body_id"] for body in bodies]
    frames = []
    prior_time = -1
    for row in messages:
        if row["message_type"] != "frame":
            continue
        if row["engine_id"] != engine or row["session_id"] != hello["session_id"]:
            raise ValueError("Crossed frame identity")
        if row["simulation_time_s"] <= prior_time:
            raise ValueError("Non-increasing simulation time")
        prior_time = row["simulation_time_s"]
        poses = {body["body_id"]: body for body in row["ordered_bodies"]}
        contacts = {contact["body_id"]: contact["present"] for contact in row["ordered_body_ground_contacts"]}
        if set(poses) != set(body_ids) or set(contacts) != set(body_ids):
            raise ValueError("Incomplete pose or contact population")
        packed_poses = []
        for body_id in body_ids:
            pose = poses[body_id]
            # Keep every published pose and its numeric values; no resampling or smoothing.
            packed_poses.append([*(pose["position_m"][axis] for axis in "xyz"),
                                 *(pose["orientation_xyzw"][axis] for axis in "xyzw")])
        frames.append([row["frame_index"], row["simulation_time_s"],
                       row.get("phase", "walking"), packed_poses,
                       [contacts[body_id] for body_id in body_ids], row["applied_impulses"]])
    expected = terminal.get("streamed_frame_count", terminal["frame_count"])
    if len(frames) != expected:
        raise ValueError("Published frame population mismatch")
    return dict(engine=engine, engine_version=hello["engine_version"],
                source_commit=hello["source_commit"], session_id=hello["session_id"],
                bodies=[dict(id=body["body_id"], collision=body["collision"]) for body in bodies],
                published_frames=len(frames), native_steps=terminal["frame_count"],
                original_terminal_outcome=terminal["outcome"], frames=frames)


def build(archive_root: Path) -> tuple[bytes, bytes]:
    archive_root = archive_root.resolve(strict=True)
    closure_bytes = (ROOT / CLOSURE).read_bytes()
    closure = json.loads(closure_bytes)
    bundle = dict(schema_version="locolemotion_pose_replay_v1", mode="recorded_playback",
                  physical_acceptance_authority=False, formal_cross_engine_equivalence=False,
                  frame_layout=["native_frame_index", "simulation_time_s", "phase", "poses_xyz_xyzw", "ground_contacts", "applied_impulses"],
                  sessions=[])
    sources = []
    for engine, entry in closure["engines"].items():
        binding = entry["stream"]
        relative = archive_relative(binding["path"])
        path = (archive_root / relative).resolve(strict=True)
        if not path.is_relative_to(archive_root):
            raise ValueError("Evidence path escapes archive root")
        raw = path.read_bytes()
        if len(raw) != binding["byte_length"] or sha256(raw) != binding["sha256"].removeprefix("sha256:"):
            raise ValueError(f"Retained stream identity mismatch: {engine}")
        session = project_stream(raw, engine)
        bundle["sessions"].append(session)
        sources.append(dict(engine=engine, archive_relative_path=relative,
                            sha256=sha256(raw), byte_length=len(raw),
                            record_pointer=f"/engines/{engine}/stream",
                            published_frames=session["published_frames"],
                            native_steps=session["native_steps"],
                            source_commit=session["source_commit"], availability="not_published", download_url=None))
    data = (PREFIX + json.dumps(bundle, ensure_ascii=True, allow_nan=False, separators=(",", ":")) + SUFFIX).encode()
    manifest = dict(schema_version="locolemotion_pose_replay_manifest_v1",
                    purpose="Viewing projection of retained development sessions; not acceptance evidence.",
                    source_record=dict(path=CLOSURE, sha256=sha256(closure_bytes), byte_length=len(closure_bytes)),
                    sources=sources,
                    projection=dict(all_published_pose_frames_retained=True, numeric_rounding=False,
                                    interpolation=False, omitted=["solver telemetry", "controller telemetry", "wall-clock timing", "full receipts"],
                                    coordinates="canonical x-forward, y-up, z-right, metres; quaternion xyzw"),
                    output=dict(path="replay/bundle.js", sha256=sha256(data), byte_length=len(data)),
                    builder=dict(path="sdk/publication/build_replay.py", sha256=sha256(Path(__file__).read_bytes())),
                    physical_acceptance_authority=False, release_authority=False,
                    formal_cross_engine_equivalence=False)
    return data, (json.dumps(manifest, indent=2) + "\n").encode()


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--archive-root", type=Path, required=True)
    parser.add_argument("--check", action="store_true", help="Compare the derived files without writing anything")
    args = parser.parse_args()
    data, manifest = build(args.archive_root)
    for relative, content in [("replay/bundle.js", data), ("replay/manifest.json", manifest)]:
        path = ROOT / relative
        if args.check:
            if path.read_bytes() != content:
                raise ValueError(f"Derived file mismatch: {relative}")
        else:
            if path.exists() and path.read_bytes() != content:
                raise ValueError(f"Refusing to overwrite a different bundle: {relative}; use a distinct successor")
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(content)
    print(json.dumps(dict(ok=True, check_only=args.check, bundle_bytes=len(data), worlds_opened=0)))


if __name__ == "__main__":
    main()
