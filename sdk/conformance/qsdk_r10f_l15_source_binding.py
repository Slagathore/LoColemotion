"""Explicit L15 root-source handoff; not a route or physics qualification.

The original root declaration remains historical. Only its two named recovery
sources may use this successor binding. The L13 adapter permission is separate
and continues to be checked by the existing materializer.
"""

from __future__ import annotations

import json
import hashlib
from pathlib import Path
import re
import subprocess

import qsdk_r10f_l15_frozen_source_replay as frozen
import qsdk_r10f_l15_launch_ownership_publication_successor_design as design_audit

ROOT = Path(__file__).resolve().parents[2]
ROOT_PARENT = "21a1019bc170c2f09125896df6b3e0934b217812"
SOURCE_ROLES = {
    "sdk/adapters/godot/gdscript/recovery_native_world_v1.gd": (
        "qualified_recovery_native_world_source",
        "fd2e2c7d9d115c00ee6eb97c5540e8b3aec48d8e",
    ),
    "sdk/adapters/godot/gdscript/recovery_native_route_v1.gd": (
        "qualified_recovery_native_route_source",
        design_audit.PARENT,
    ),
}
QUALIFICATION_INPUT_SCHEMA = "sporespore_qsdk_r10f_l15_qualification_inputs_v2"
QUALIFIED_GRAPH_PATHS = (
    "sdk/qsdk_r10f_development_route_ghost_zero_world_qualification_closure_v16.json",
    "sdk/qsdk_r10f_development_route_ghost_execution_authority_v16.json",
)
QUALIFICATION_GIT_ATTRIBUTES = {
    "text": "set",
    "eol": "lf",
    "filter": "unspecified",
    "working-tree-encoding": "unspecified",
    "ident": "unspecified",
}
# Required reader shape only; no expected source bytes or passing result live in
# this declaration. The production materializer must reopen every input first.
QUALIFICATION_INPUT_FIELDS = frozenset(
    {
        "schema_version",
        "gate_id",
        "repair_id",
        "ledger_scope",
        "ok",
        "source_commit",
        "source_tree",
        "committed_source_required",
        "all_source_git_projections_equal_commit",
        "checkout_bytes_differ_from_git_storage_paths",
        "original_checkout_bytes_preserved",
        "changed_or_uncommitted_source_paths",
        "qualified_source_path_count",
        "qualified_source_path_sha256",
        "qualified_source_bindings",
        "qualified_source_binding_sha256",
        "dependency_manifest",
        "complete_dependency_receipt",
        "root_source_binding",
        "historical_root_authorities",
        "unchanged_l13_adapter_permission",
        "runtime_binding",
        "qualification_or_physical_identity_created",
        "complete_implementation_qualified",
        "official_expected_context_origin_authenticated",
        "worker_report_used_as_source",
        "source_or_evidence_files_written",
        "model_construction_count",
        "world_attempt_count",
        "world_build_count",
        "scene_tree_insertion_count",
        "native_physics_read_count",
        "solver_step_count",
        "physics_state_modified",
        "physical_execution_authorized",
        "physical_acceptance_authority",
        "release_authority",
    }
)


def require(condition, code):
    if not condition:
        raise ValueError("QSDK_R10F_L15_SOURCE_BINDING_" + code)


def git(*arguments):
    try:
        return frozen.git(*arguments)
    except (OSError, subprocess.SubprocessError) as exc:
        raise ValueError("QSDK_R10F_L15_SOURCE_BINDING_GIT_READ") from exc


def exact(left, right):
    if type(left) is not type(right):
        return False
    if type(left) is dict:
        return left.keys() == right.keys() and all(
            exact(left[key], right[key]) for key in left
        )
    if type(left) is list:
        return len(left) == len(right) and all(exact(a, b) for a, b in zip(left, right))
    return left == right


def read_worktree_source(relative):
    path = ROOT / frozen.relative_path(relative)
    require(path.resolve().is_relative_to(ROOT.resolve()), "PATH_ESCAPE")
    require(path.is_file(), "SOURCE_MISSING:" + relative)
    return path.read_bytes()


def bind_current_source(relative, source_commit):
    """Bind original checkout bytes, without filters, to a caller's exact commit."""
    relative = frozen.relative_path(relative)
    raw = read_worktree_source(relative)
    binding = frozen.blob_identity(relative, raw)
    expected_oid = git("rev-parse", source_commit + ":" + relative).decode().strip()
    require(binding["git_blob_oid"] == expected_oid, "CURRENT_SOURCE:" + relative)
    return raw, {**binding, "source_commit": source_commit}


def validate_source_pair(
    authority,
    observed,
    historical_raw,
    parent_oid,
    current,
    current_raw,
    source_commit,
    qualified_source_oid,
):
    """A pure negative-control seam, with no caller-supplied change allowlist."""
    require(type(authority) is dict and type(observed) is dict, "PAIR_OBJECTS")
    relative = authority.get("path")
    require(relative in SOURCE_ROLES, "PAIR_ROLE_PATH")
    role, observed_commit = SOURCE_ROLES[relative]
    old = frozen.blob_identity(relative, historical_raw)
    require(
        exact(authority, {"role": role, **old})
        and exact(
            observed,
            {
                "path": relative,
                "source_commit": observed_commit,
                "git_blob": old["git_blob_oid"],
                "byte_length": old["byte_length"],
                "raw_sha256": old["raw_sha256"],
            },
        )
        and type(parent_oid) is str
        and parent_oid == old["git_blob_oid"],
        "HISTORICAL_PAIR:" + relative,
    )
    require(
        type(source_commit) is str
        and re.fullmatch(r"[0-9a-f]{40}", source_commit) is not None
        and exact(
            current,
            {
                **frozen.blob_identity(relative, current_raw),
                "source_commit": source_commit,
            },
        )
        and type(qualified_source_oid) is str
        and current["git_blob_oid"] == qualified_source_oid
        and current["git_blob_oid"] != old["git_blob_oid"],
        "SUCCESSOR_PAIR:" + relative,
    )


def bind_root_sources(source_commit, root_design):
    frozen.verify_repository()
    require(
        type(source_commit) is str
        and re.fullmatch(r"[0-9a-f]{40}", source_commit) is not None,
        "SOURCE_COMMIT",
    )
    require(
        git("rev-parse", "--verify", source_commit + "^{commit}").decode().strip()
        == source_commit,
        "SOURCE_COMMIT_OBJECT",
    )
    root_raw, root_binding = bind_current_source(frozen.DESIGN, source_commit)
    require(
        tuple(root_binding[k] for k in ("byte_length", "raw_sha256", "git_blob_oid"))
        == frozen.PINNED_FILES[frozen.DESIGN]
        and exact(root_design, json.loads(root_raw))
        and root_design["authored_parent_commit"] == ROOT_PARENT,
        "ROOT_DESIGN_PRESERVED",
    )
    design_path = design_audit.DESIGN.relative_to(ROOT).as_posix()
    design_raw, design_binding = bind_current_source(design_path, source_commit)
    require(
        len(design_raw) == design_audit.DESIGN_BYTES
        and design_audit.sha(design_raw) == design_audit.DESIGN_SHA,
        "L15_DESIGN_PIN",
    )
    design = json.loads(design_raw)
    design_audit.validate_contract(design, json.loads(design_raw))
    # The unchanged design auditor reopens all nine exact authorities and three
    # frozen retention sources. It does not run its separate diagnosis replay.
    diagnosis = design_audit.reopen_inputs(design)
    for entry in design["bound_authorities"]:
        raw, binding = bind_current_source(entry["path"], source_commit)
        require(
            len(raw) == entry["byte_length"]
            and binding["raw_sha256"] == entry["raw_sha256"]
            and binding["git_blob_oid"] == entry["git_blob"],
            "L15_AUTHORITY_PIN:" + entry["role"],
        )
    sources = (
        diagnosis["frozen_sources"] + design["additional_frozen_retention_sources"]
    )
    pairs = []
    for relative in SOURCE_ROLES:
        root_matches = [
            a for a in root_design["bound_authorities"] if a["path"] == relative
        ]
        observed_matches = [s for s in sources if s["path"] == relative]
        require(len(root_matches) == len(observed_matches) == 1, "EXACT_SOURCE_ROLES")
        authority, observed = root_matches[0], observed_matches[0]
        historical_raw = git(
            "cat-file", "blob", observed["source_commit"] + ":" + relative
        )
        parent_oid = git("rev-parse", ROOT_PARENT + ":" + relative).decode().strip()
        current_raw, current = bind_current_source(relative, source_commit)
        qualified_oid = (
            git("rev-parse", source_commit + ":" + relative).decode().strip()
        )
        validate_source_pair(
            authority,
            observed,
            historical_raw,
            parent_oid,
            current,
            current_raw,
            source_commit,
            qualified_oid,
        )
        pairs.append(
            {
                "historical_root_authority": dict(authority),
                "preserved_observed_source": dict(observed),
                "exact_successor_source": current,
            }
        )
    return {
        "schema_version": "sporespore_qsdk_r10f_l15_root_source_binding_v1",
        "ledger_scope": {
            "subsystem": "recovery",
            "engine_scope": "godot_jolt",
            "authority_mode": "zero_world_explicit_successor_source_binding",
            "question_class": "development",
        },
        "ok": True,
        "source_commit": source_commit,
        "unchanged_root_design": root_binding,
        "l15_design": design_binding,
        "historical_root_parent_commit": ROOT_PARENT,
        "source_pair_count": len(pairs),
        "source_pairs": pairs,
        "historical_root_authorities_rewritten": False,
        "legacy_l13_adapter_permission_widened": False,
        "whole_recursive_source_manifest_qualified": False,
        "whole_route_qualified": False,
        "official_qualification_consumed": False,
        "source_or_evidence_files_written": False,
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "scene_tree_insertion_count": 0,
        "native_physics_read_count": 0,
        "solver_step_count": 0,
        "physical_execution_authorized": False,
        "physical_acceptance_authority": False,
        "release_authority": False,
    }


def committed_source_objects(source_commit):
    """Read one exact Git tree without applying checkout filters or executing it."""
    require(
        type(source_commit) is str
        and re.fullmatch(r"[0-9a-f]{40}", source_commit) is not None,
        "QUALIFICATION_SOURCE_COMMIT",
    )
    entries = git("ls-tree", "-rz", "--full-tree", source_commit).split(b"\0")
    result = {}
    for entry in entries:
        if not entry:
            continue
        metadata, raw_path = entry.split(b"\t", 1)
        mode, kind, oid = metadata.decode("ascii").split(" ")
        relative = frozen.relative_path(raw_path.decode("utf-8", errors="strict"))
        require(relative not in result, "QUALIFICATION_TREE_DUPLICATE")
        result[relative] = {"mode": mode, "kind": kind, "git_blob_oid": oid}
    return result


def qualification_git_attributes(paths):
    """Read only the attributes governing the declared text-to-Git projection.

    No clean filter, encoding converter or identifier expansion is executed or
    accepted. The original checkout bytes always remain separately bound.
    """
    names = tuple(QUALIFICATION_GIT_ATTRIBUTES)
    fields = git("check-attr", "-z", *names, "--", *paths).decode("utf-8").split("\0")
    require(fields[-1] == "", "QUALIFICATION_ATTRIBUTE_TERMINATOR")
    fields.pop()
    require(len(fields) == len(paths) * len(names) * 3, "QUALIFICATION_ATTRIBUTE_COUNT")
    result = {path: {} for path in paths}
    for index in range(0, len(fields), 3):
        relative, name, value = fields[index : index + 3]
        require(
            relative in result and name in names and name not in result[relative],
            "QUALIFICATION_ATTRIBUTE_POPULATION",
        )
        result[relative][name] = value
    require(
        all(exact(value, QUALIFICATION_GIT_ATTRIBUTES) for value in result.values()),
        "QUALIFICATION_ATTRIBUTE_POLICY",
    )
    return result


def qualification_source_projection(relative, raw, attributes):
    """Describe original bytes and their explicit Git-storage representation.

    This is read-only identity bookkeeping, not an edit or an assertion that
    changed checkout bytes inherit an earlier qualification. Their raw SHA-256
    stays in the complete input key even when Git's text projection is equal.
    """
    require(
        exact(attributes, QUALIFICATION_GIT_ATTRIBUTES),
        "QUALIFICATION_ATTRIBUTE_POLICY",
    )
    require(type(raw) is bytes and b"\0" not in raw, "QUALIFICATION_SOURCE_TEXT_KIND")
    try:
        raw.decode("utf-8", errors="strict")
    except UnicodeError as exc:
        raise ValueError(
            "QSDK_R10F_L15_SOURCE_BINDING_QUALIFICATION_SOURCE_UTF8"
        ) from exc
    original = frozen.blob_identity(relative, raw)
    projected = frozen.blob_identity(relative, raw.replace(b"\r\n", b"\n"))
    return {
        **original,
        "git_storage_projection": {
            "rule": "declared_text_eol_lf_crlf_pairs_only",
            **{
                key: projected[key]
                for key in ("byte_length", "raw_sha256", "git_blob_oid")
            },
        },
        "git_attributes": dict(attributes),
    }


def qualified_source_snapshot(paths, committed_objects):
    """Bind every original source byte; development edits remain visible."""
    require(
        type(paths) is list
        and paths
        and all(type(path) is str for path in paths)
        and paths == sorted(set(paths)),
        "QUALIFICATION_SOURCE_POPULATION",
    )
    attributes = qualification_git_attributes(paths)
    bindings, changed = [], []
    for relative in paths:
        committed = committed_objects.get(relative)
        require(
            committed is None
            or (
                committed["kind"] == "blob"
                and committed["mode"] in ("100644", "100755")
            ),
            "QUALIFICATION_NOT_REGULAR_SOURCE:" + relative,
        )
        raw = read_worktree_source(relative)
        binding = qualification_source_projection(relative, raw, attributes[relative])
        if (
            committed is None
            or binding["git_storage_projection"]["git_blob_oid"]
            != committed["git_blob_oid"]
        ):
            changed.append(relative)
        bindings.append(binding)
    return bindings, changed


def qualified_checkout_context(source_commit, *, checkout_commit=None):
    """Admit only source itself, its new freeze, or its new authority child.

    This checks Git topology and unchanged checkout artifacts, not whether the
    qualification or physical declaration inside an artifact is valid. Those
    complete records remain the enclosing materializer's responsibility.
    """
    require(
        type(source_commit) is str and re.fullmatch(r"[0-9a-f]{40}", source_commit),
        "QUALIFICATION_SOURCE_COMMIT",
    )
    head = git("rev-parse", "HEAD").decode().strip()
    if checkout_commit is None:
        require(head == source_commit, "QUALIFICATION_SOURCE_NOT_HEAD")
        return {
            "source_commit": source_commit,
            "checkout_commit": head,
            "phase": "source",
            "graph_artifacts": [],
        }
    require(
        type(checkout_commit) is str
        and re.fullmatch(r"[0-9a-f]{40}", checkout_commit)
        and head == checkout_commit,
        "QUALIFICATION_CHECKOUT_NOT_HEAD",
    )
    require(
        git("branch", "--show-current").decode().strip() == "main"
        and not git("status", "--porcelain=v1", "--untracked-files=all").strip(),
        "QUALIFICATION_GRAPH_CHECKOUT_NOT_CLEAN_MAIN",
    )
    if head == source_commit:
        return {
            "source_commit": source_commit,
            "checkout_commit": head,
            "phase": "source",
            "graph_artifacts": [],
        }

    def parent(commit):
        row = git("rev-list", "--parents", "-n", "1", commit).decode().split()
        require(len(row) == 2 and row[0] == commit, "QUALIFICATION_GRAPH_SINGLE_PARENT")
        return row[1]

    previous = parent(head)
    if previous == source_commit:
        commits, phase = [head], "freeze"
    else:
        require(parent(previous) == source_commit, "QUALIFICATION_GRAPH_SOURCE_PARENT")
        commits, phase = [previous, head], "authority"
    artifacts = []
    for commit, relative in zip(commits, QUALIFIED_GRAPH_PATHS):
        changes = (
            git(
                "diff-tree",
                "--no-commit-id",
                "--name-status",
                "--no-renames",
                "-r",
                commit,
            )
            .decode()
            .splitlines()
        )
        require(changes == ["A\t" + relative], "QUALIFICATION_GRAPH_SINGLE_NEW_PATH")
        entry = committed_source_objects(commit).get(relative)
        require(
            entry is not None and entry["mode"] == "100644" and entry["kind"] == "blob",
            "QUALIFICATION_GRAPH_REGULAR_ARTIFACT",
        )
        raw = read_worktree_source(relative)
        attributes = qualification_git_attributes([relative])[relative]
        identity = qualification_source_projection(relative, raw, attributes)
        require(
            identity["git_storage_projection"]["git_blob_oid"] == entry["git_blob_oid"],
            "QUALIFICATION_GRAPH_ARTIFACT_NOT_COMMITTED",
        )
        artifacts.append({"commit": commit, **identity})
    require(
        git("diff", "--name-only", "--no-renames", source_commit, head)
        .decode()
        .splitlines()
        == sorted(QUALIFIED_GRAPH_PATHS[: len(commits)]),
        "QUALIFICATION_GRAPH_CHANGED_PATHS",
    )
    return {
        "source_commit": source_commit,
        "checkout_commit": head,
        "phase": phase,
        "graph_artifacts": artifacts,
    }


def bind_qualification_inputs(
    source_commit, *, require_committed_source=False, checkout_commit=None
):
    """Reopen the complete L15 source/runtime inputs, not a qualification result.

    This is the independent input side of the enclosing reader. It accepts no
    worker report, component result or purported expected context. Development
    edits are recorded explicitly; committed-source mode requires the declared
    Git text projection to match the commit while retaining all original bytes.
    Neither mode runs the SDK, opens a world or consumes an official identity.
    """
    import qsdk_r10f_authority_materializer as materializer
    import qsdk_r10f_dependency_closure as dependency
    import qsdk_r10f_l14_runtime_binding as runtime

    require(type(require_committed_source) is bool, "QUALIFICATION_MODE_KIND")
    require(
        checkout_commit is None or require_committed_source,
        "QUALIFICATION_GRAPH_REQUIRES_COMMITTED_SOURCE",
    )
    frozen.verify_repository()
    objects = committed_source_objects(source_commit)
    checkout_context = qualified_checkout_context(
        source_commit, checkout_commit=checkout_commit
    )
    source_tree = git("rev-parse", source_commit + "^{tree}").decode().strip()
    dependency_receipt = dependency.audit(
        require_tracked=require_committed_source,
        allow_unfinalized=False,
        require_l15_sources=True,
    )
    paths = dependency_receipt["qualified_source_paths"]
    sources, changed = qualified_source_snapshot(paths, objects)
    require(
        not require_committed_source or not changed,
        "QUALIFICATION_SOURCE_GIT_PROJECTION_NOT_COMMITTED:" + ",".join(changed),
    )
    godot = Path(runtime.IMAGES["godot_console"]["path"])
    images = runtime.bind_runtime(godot)
    # The actual materializer additionally preserves the separate L13 adapter
    # permission. A caller-provided changed-path list cannot replace that rule.
    root_design, authorities = materializer.design_binding(
        source_commit, require_l15_sources=True
    )
    require(
        exact(authorities, root_design["bound_authorities"]),
        "QUALIFICATION_HISTORICAL_AUTHORITIES",
    )
    root_binding = bind_root_sources(source_commit, root_design)
    manifest_binding = next(
        record
        for record in sources
        if record["path"] == dependency_receipt["manifest_path"]
    )
    require(
        manifest_binding["byte_length"] == dependency_receipt["manifest_byte_length"]
        and manifest_binding["raw_sha256"] == dependency_receipt["manifest_raw_sha256"],
        "QUALIFICATION_MANIFEST_CHANGED_DURING_READ",
    )
    encoded_sources = json.dumps(
        sources,
        sort_keys=True,
        separators=(",", ":"),
        ensure_ascii=False,
        allow_nan=False,
    ).encode("utf-8")
    result = {
        "schema_version": QUALIFICATION_INPUT_SCHEMA,
        "gate_id": "QSDK-R10F",
        "repair_id": "QSDK-R10F-L15",
        "ledger_scope": {
            "subsystem": "recovery",
            "engine_scope": "godot_jolt",
            "authority_mode": "read_only_complete_qualification_input_binding",
            "question_class": "development",
        },
        "ok": True,
        "source_commit": source_commit,
        "source_tree": source_tree,
        "committed_source_required": require_committed_source,
        "all_source_git_projections_equal_commit": not changed,
        "checkout_bytes_differ_from_git_storage_paths": [
            record["path"]
            for record in sources
            if record["git_blob_oid"]
            != record["git_storage_projection"]["git_blob_oid"]
        ],
        "original_checkout_bytes_preserved": True,
        "changed_or_uncommitted_source_paths": changed,
        "qualified_source_path_count": len(sources),
        "qualified_source_path_sha256": dependency_receipt[
            "qualified_source_path_sha256"
        ],
        "qualified_source_bindings": sources,
        "qualified_source_binding_sha256": "sha256:"
        + hashlib.sha256(encoded_sources).hexdigest(),
        "dependency_manifest": manifest_binding,
        "complete_dependency_receipt": dependency_receipt,
        "root_source_binding": root_binding,
        "historical_root_authorities": authorities,
        "unchanged_l13_adapter_permission": {
            "path": "sdk/qsdk_r10f_l13_walking_ledger_transport_projection_successor_design_v1.json",
            "byte_length": 27267,
            "raw_sha256": "sha256:ce85d54e7a8cc12304015f5551d4f7874ad783613cd7feb566fc63cb10b20ce9",
        },
        "runtime_binding": images,
        "qualification_or_physical_identity_created": False,
        "complete_implementation_qualified": False,
        "official_expected_context_origin_authenticated": False,
        "worker_report_used_as_source": False,
        "source_or_evidence_files_written": False,
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "scene_tree_insertion_count": 0,
        "native_physics_read_count": 0,
        "solver_step_count": 0,
        "physics_state_modified": False,
        "physical_execution_authorized": False,
        "physical_acceptance_authority": False,
        "release_authority": False,
    }
    final_sources, final_changed = qualified_source_snapshot(paths, objects)
    require(
        exact(final_sources, sources) and exact(final_changed, changed),
        "QUALIFICATION_SOURCE_DRIFT_DURING_READ",
    )
    require(exact(runtime.bind_runtime(godot), images), "QUALIFICATION_RUNTIME_DRIFT")
    require(
        exact(
            dependency.audit(
                require_tracked=require_committed_source,
                allow_unfinalized=False,
                require_l15_sources=True,
            ),
            dependency_receipt,
        ),
        "QUALIFICATION_DEPENDENCY_DRIFT",
    )
    require(
        exact(
            qualified_checkout_context(source_commit, checkout_commit=checkout_commit),
            checkout_context,
        ),
        "QUALIFICATION_HEAD_DRIFT_DURING_READ",
    )
    return result


def validate_qualification_inputs(value, *, expected):
    """Compare the whole offered record with a separately reopened input record.

    This pure seam permits exhaustive corruption tests without repeating file
    reads. Production callers must obtain ``expected`` through the input reader,
    never from the offered qualification, worker or a subset of its fields.
    """
    require(type(value) is dict and type(expected) is dict, "QUALIFICATION_INPUT_KIND")
    require(
        expected.keys() == QUALIFICATION_INPUT_FIELDS
        and expected["schema_version"] == QUALIFICATION_INPUT_SCHEMA,
        "QUALIFICATION_EXPECTED_INPUT_SHAPE",
    )
    require(exact(value, expected), "QUALIFICATION_COMPLETE_INPUT_BINDING")
