"""Read-only fixed-Git input projection for the retired materializer replay.

The historical program and its refusal predicate are not rewritten. Only the
two path inputs used by design_binding are projected onto fixed Git objects
and an exactly hash-verified declared checkout-line-ending representation.
This is a narrow replay input adapter, not a security sandbox or a new physical
authority. It cannot qualify the changed successor sources by itself.
"""

from __future__ import annotations

import hashlib
import io
import json
import os
from pathlib import Path
import re
import subprocess
from types import MappingProxyType, SimpleNamespace

ROOT = Path(__file__).resolve().parents[2]
EXPECTED_ROOT = Path(r"C:\Users\Cole\CodeStuff\games\SporeSpore")
REMOTE = "https://github.com/Slagathore/sporespore.git"
RETIRED_SOURCE = "ebee550164eea4830ea7c55127ff672b04ad8419"
MATERIALIZER = "sdk/conformance/qsdk_r10f_authority_materializer.py"
DESIGN = "sdk/qsdk_r10f_continuous_passive_fall_recovery_successor_design_v1.json"
PINNED_FILES = {
    MATERIALIZER: (
        109451,
        "sha256:1f9cf4ad21b8f559b33d785a59a1f4248ff6185da865025e3add295db6672158",
        "e732847eb71889895cd654357c96b7097e10cc80",
    ),
    DESIGN: (
        25621,
        "sha256:696cc5ee80002e39968d27c6f21fa97f9309b7f08d3caad2961699ceb7184dfa",
        "8cda904e04e34e9631026baae702b2d5d544f83c",
    ),
}


def require(condition, code):
    if not condition:
        raise ValueError("QSDK_R10F_L15_FROZEN_SOURCE_" + code)


def relative_path(value):
    require(
        type(value) is str
        and bool(value)
        and "\\" not in value
        and ":" not in value
        and all(part not in ("", ".", "..") for part in value.split("/")),
        "RELATIVE_PATH",
    )
    return value


def git(*arguments):
    return subprocess.check_output(["git", *arguments], cwd=ROOT, timeout=30)


def blob_identity(path, raw):
    require(type(raw) is bytes, "BLOB_BYTES")
    return {
        "path": relative_path(path),
        "byte_length": len(raw),
        "raw_sha256": "sha256:" + hashlib.sha256(raw).hexdigest(),
        "git_blob_oid": hashlib.sha1(
            b"blob " + str(len(raw)).encode("ascii") + b"\0" + raw
        ).hexdigest(),
    }


def declared_checkout_projection(raw, authority):
    """Reproduce declared source bytes only when both identities prove it.

    One original declaration hashes a CRLF checkout separately from its LF Git
    blob. This is an explicit source-byte reproduction, not a claim to possess
    the old working file. Never use it to repair changed content or evidence.
    """
    identity = blob_identity(authority["path"], raw)
    require(identity["git_blob_oid"] == authority["git_blob_oid"], "PROJECTION_GIT_ID")
    require(b"\r" not in raw and b"\n" in raw, "PROJECTION_LF_SOURCE")
    restored = raw.replace(b"\n", b"\r\n")
    require(
        type(authority["byte_length"]) is int
        and len(restored) == authority["byte_length"]
        and "sha256:" + hashlib.sha256(restored).hexdigest() == authority["raw_sha256"],
        "PROJECTION_DECLARED_BYTES",
    )
    return restored


class FrozenGitTree:
    """A bounded immutable source population, never a linked worktree."""

    def __init__(self, commit, objects, identities):
        require(
            type(commit) is str and re.fullmatch(r"[0-9a-f]{40}", commit) is not None,
            "COMMIT",
        )
        require(
            type(objects) is dict
            and type(identities) is dict
            and objects.keys() == identities.keys(),
            "POPULATION_KEYS",
        )
        for path, raw in objects.items():
            expected = blob_identity(path, raw)
            supplied = identities[path]
            require(
                type(supplied) is dict
                and supplied.keys() == expected.keys()
                and all(type(supplied[k]) is type(expected[k]) for k in expected)
                and supplied == expected,
                "OBJECT_IDENTITY:" + path,
            )
        require(DESIGN in objects, "DESIGN_SOURCE_REQUIRED")
        design_pin = blob_identity(DESIGN, objects[DESIGN])
        require(
            tuple(design_pin[k] for k in ("byte_length", "raw_sha256", "git_blob_oid"))
            == PINNED_FILES[DESIGN],
            "DESIGN_PIN",
        )
        overrides, projections = {}, []
        for authority in json.loads(objects[DESIGN])["bound_authorities"]:
            path = authority["path"]
            require(path in objects, "DECLARED_SOURCE_REQUIRED:" + path)
            identity = identities[path]
            if identity["git_blob_oid"] == authority["git_blob_oid"] and any(
                identity[k] != authority[k] for k in ("byte_length", "raw_sha256")
            ):
                restored = declared_checkout_projection(objects[path], authority)
                overrides[path] = restored
                projections.append(
                    {
                        "path": path,
                        "projection": "lf_git_blob_to_exact_declared_crlf_source_bytes",
                        "source_git_blob_oid": identity["git_blob_oid"],
                        "source_git_byte_length": identity["byte_length"],
                        "source_git_raw_sha256": identity["raw_sha256"],
                        "declared_checkout_byte_length": len(restored),
                        "declared_checkout_raw_sha256": authority["raw_sha256"],
                        "original_checkout_file_claimed_present": False,
                        "declared_source_identity_changed": False,
                    }
                )
        self.commit = commit
        self._objects = MappingProxyType(dict(objects))
        self._overrides = MappingProxyType(overrides)
        self.projections = tuple(MappingProxyType(p) for p in projections)
        self.identities = MappingProxyType(
            {p: MappingProxyType(dict(b)) for p, b in identities.items()}
        )
        self.read_paths = []
        self.root = FrozenGitPath(self, "")

    def read(self, relative):
        relative = relative_path(relative)
        if relative not in self._objects:
            raise FileNotFoundError("FROZEN_SOURCE_NOT_IN_POPULATION:" + relative)
        self.read_paths.append(relative)
        return self._overrides.get(relative, self._objects[relative])


class FrozenGitPath(os.PathLike):
    """Only the read-only Path surface used by the pinned historical method."""

    def __init__(self, tree, relative):
        self.tree = tree
        self.relative = relative_path(relative) if relative else ""

    def __truediv__(self, value):
        value = relative_path(value)
        return FrozenGitPath(
            self.tree, self.relative + "/" + value if self.relative else value
        )

    def __fspath__(self):
        # The unchanged historical Git helper needs the canonical repository
        # as cwd. Individual sources may never fall back to working files.
        require(self.relative == "", "NO_WORKTREE_FILE_FALLBACK")
        return str(ROOT)

    def __str__(self):
        return f"git-object:{self.tree.commit}:{self.relative}"

    def resolve(self):
        return self

    def is_file(self):
        return self.relative in self.tree._objects

    def stat(self):
        return SimpleNamespace(st_size=len(self.read_bytes()))

    def read_bytes(self):
        return self.tree.read(self.relative)

    def open(self, mode="r", *, encoding=None):
        require(mode in ("r", "rb"), "READ_ONLY_MODE")
        raw = io.BytesIO(self.read_bytes())
        return (
            raw if mode == "rb" else io.TextIOWrapper(raw, encoding=encoding or "utf-8")
        )

    def read_text(self, encoding="utf-8"):
        with self.open("r", encoding=encoding) as stream:
            return stream.read()


def verify_repository():
    require(ROOT.resolve() == EXPECTED_ROOT.resolve(), "CANONICAL_ROOT")
    require(
        Path(git("rev-parse", "--show-toplevel").decode().strip()).resolve()
        == ROOT.resolve(),
        "GIT_ROOT",
    )
    require(git("remote", "get-url", "origin").decode().strip() == REMOTE, "REMOTE")


def load_retired_tree():
    verify_repository()
    require(
        git("rev-parse", "--verify", RETIRED_SOURCE + "^{commit}").decode().strip()
        == RETIRED_SOURCE,
        "RETIRED_COMMIT",
    )
    objects, identities = {}, {}

    def read(path):
        path = relative_path(path)
        raw = git("cat-file", "blob", RETIRED_SOURCE + ":" + path)
        identity = blob_identity(path, raw)
        require(
            identity["git_blob_oid"]
            == git("rev-parse", RETIRED_SOURCE + ":" + path).decode().strip(),
            "GIT_OBJECT:" + path,
        )
        if path in PINNED_FILES:
            require(
                tuple(
                    identity[k] for k in ("byte_length", "raw_sha256", "git_blob_oid")
                )
                == PINNED_FILES[path],
                "PINNED_SOURCE:" + path,
            )
        objects[path], identities[path] = raw, identity

    for path in PINNED_FILES:
        read(path)
    design = json.loads(objects[DESIGN])
    authorities = design["bound_authorities"]
    require(
        type(authorities) is list and len(authorities) == 15, "AUTHORITY_POPULATION"
    )
    paths = [relative_path(item["path"]) for item in authorities]
    require(
        len(set(paths)) == 15 and not set(paths).intersection(PINNED_FILES),
        "DISTINCT_SOURCE_ROLES",
    )
    for path in paths:
        read(path)
    return FrozenGitTree(RETIRED_SOURCE, objects, identities)


def replay_retired_materializer(tree=None):
    verify_repository()
    tree = load_retired_tree() if tree is None else tree
    require(
        type(tree) is FrozenGitTree and tree.commit == RETIRED_SOURCE, "REPLAY_TREE"
    )
    for path, pin in PINNED_FILES.items():
        actual = blob_identity(path, tree.read(path))
        require(
            tuple(actual[k] for k in ("byte_length", "raw_sha256", "git_blob_oid"))
            == pin,
            "REPLAY_PIN:" + path,
        )
    paths = sorted(tree.identities)
    expected_paths = {MATERIALIZER, DESIGN} | {
        entry["path"] for entry in json.loads(tree.read(DESIGN))["bound_authorities"]
    }
    require(set(paths) == expected_paths, "REPLAY_POPULATION")
    actual_oids = (
        git("rev-parse", *(RETIRED_SOURCE + ":" + p for p in paths))
        .decode()
        .splitlines()
    )
    require(len(actual_oids) == len(paths), "REPLAY_GIT_POPULATION")
    require(
        all(
            tree.identities[p]["git_blob_oid"] == oid
            for p, oid in zip(paths, actual_oids)
        ),
        "REPLAY_GIT_ORIGIN",
    )
    source = tree.read(MATERIALIZER).decode("utf-8")
    namespace = {
        "__name__": "_l15_retired_materializer_fixed_git_replay",
        "__file__": str(ROOT / MATERIALIZER),
    }
    exec(compile(source, str(ROOT / MATERIALIZER), "exec"), namespace)
    require(
        namespace["ROOT"] == ROOT and namespace["DESIGN_PATH"] == ROOT / DESIGN,
        "HISTORICAL_PATH_INPUTS",
    )
    # Do not alter the historical function, hash, authority table or predicate.
    namespace["ROOT"] = tree.root
    namespace["DESIGN_PATH"] = tree.root / DESIGN
    failure = ""
    try:
        namespace["design_binding"](RETIRED_SOURCE)
    except namespace["MaterializationFailure"] as exc:
        failure = str(exc)
    require(failure == "DESIGN_AUTHORITY_13_IDENTITY", "ORIGINAL_REFUSAL:" + failure)
    return {
        "schema_version": "sporespore_qsdk_r10f_l15_fixed_git_materializer_replay_v1",
        "ledger_scope": {
            "subsystem": "recovery",
            "engine_scope": "godot_jolt",
            "authority_mode": "zero_world_historical_fixed_git_source_projection",
            "question_class": "development",
        },
        "ok": True,
        "historical_source_commit": RETIRED_SOURCE,
        "historical_materializer_refusal": failure,
        "historical_function_executed": "design_binding",
        "historical_authority_prefix_passed_count": 13,
        "historical_authority_population_count": 15,
        "snapshot_source_file_count": len(tree.identities),
        "snapshot_source_bindings": [
            dict(tree.identities[p]) for p in sorted(tree.identities)
        ],
        "read_source_paths": sorted(set(tree.read_paths)),
        "snapshot_source_reads_from_current_worktree": 0,
        "declared_checkout_source_projection_count": len(tree.projections),
        "declared_checkout_source_projections": [dict(p) for p in tree.projections],
        "historical_source_function_rewritten": False,
        "historical_authority_or_expectation_rewritten": False,
        "successor_source_qualified": False,
        "source_checkout_or_evidence_files_written": False,
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "native_physics_read_count": 0,
        "solver_step_count": 0,
        "physical_execution_authorized": False,
        "physical_acceptance_authority": False,
        "release_authority": False,
    }
