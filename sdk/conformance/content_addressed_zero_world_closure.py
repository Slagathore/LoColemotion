"""Shared content-addressed mechanics for retained scientific closures."""

from __future__ import annotations

import hashlib
import json
import math
from pathlib import Path
import subprocess
from typing import Any, Sequence


class ClosureAuditError(RuntimeError):
    """Stable failure raised by a content-addressed closure audit."""


def require(condition: bool, code: str) -> None:
    if not condition:
        raise ClosureAuditError(code)


def exact(actual: object, expected: object, code: str) -> None:
    require(actual == expected, f"{code}:expected={expected!r}:actual={actual!r}")


def _reject_duplicates(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    value: dict[str, Any] = {}
    for key, item in pairs:
        require(key not in value, f"DUPLICATE_KEY:{key}")
        value[key] = item
    return value


def loads(value: bytes) -> dict[str, Any]:
    decoded = json.loads(value, object_pairs_hook=_reject_duplicates)
    require(isinstance(decoded, dict), "JSON_ROOT")
    return decoded


def load(path: Path) -> dict[str, Any]:
    return loads(path.read_bytes())


def records_with_key(value: object, key: str) -> list[dict[str, Any]]:
    """Find every nested object that owns one exact key."""

    records: list[dict[str, Any]] = []
    if isinstance(value, dict):
        if key in value:
            records.append(value)
        for child in value.values():
            records.extend(records_with_key(child, key))
    elif isinstance(value, list):
        for child in value:
            records.extend(records_with_key(child, key))
    return records


def canonical_bytes(value: object) -> bytes:
    return json.dumps(
        value,
        allow_nan=False,
        ensure_ascii=False,
        separators=(",", ":"),
        sort_keys=True,
    ).encode("utf-8")


def _core_canonical_value(value: object) -> object:
    """Mirror sdk/core's shared fourteen-significant-digit JSON policy."""

    if value is None or isinstance(value, (bool, str)):
        return value
    if isinstance(value, int):
        require(
            -9_007_199_254_740_991 <= value <= 9_007_199_254_740_991,
            "CORE_CANONICAL_INTEGER_RANGE",
        )
        return value
    if isinstance(value, float):
        require(math.isfinite(value), "CORE_CANONICAL_NONFINITE")
        if value == 0.0:
            return 0
        if value.is_integer() and abs(value) <= 9_007_199_254_740_991:
            return int(value)
        quantized = float(f"{value:.13e}")
        if quantized == 0.0:
            return 0
        if quantized.is_integer() and abs(quantized) <= 9_007_199_254_740_991:
            return int(quantized)
        return quantized
    if isinstance(value, list):
        return [_core_canonical_value(item) for item in value]
    if isinstance(value, dict):
        require(
            all(isinstance(key, str) for key in value),
            "CORE_CANONICAL_OBJECT_KEY",
        )
        return {
            key: _core_canonical_value(item) for key, item in value.items()
        }
    raise ClosureAuditError(f"CORE_CANONICAL_TYPE:{type(value).__name__}")


def _serde_json_float(value: float) -> str:
    """Render one finite binary64 like serde_json's f64 formatter.

    CPython and serde_json both choose a shortest round-tripping mantissa, but
    their presentation rules differ at two boundaries relevant to content
    hashes: Python zero-pads one-digit exponents, and serde_json uses fixed
    notation for decimal exponent -5. The core converts integral floats to
    integers before this point, so the remaining representation can be mapped
    without changing numeric identity.
    """

    rendered = repr(value).lower()
    if "e" not in rendered:
        return rendered
    mantissa, exponent_text = rendered.split("e", 1)
    exponent = int(exponent_text)
    if exponent != -5:
        sign = "+" if exponent >= 0 else "-"
        return f"{mantissa}e{sign}{abs(exponent)}"

    negative = mantissa.startswith("-")
    unsigned = mantissa[1:] if negative else mantissa
    digits = unsigned.replace(".", "")
    fixed = "0." + ("0" * 4) + digits
    return ("-" if negative else "") + fixed


def _serde_json_bytes(value: object) -> bytes:
    """Encode a core-projected JSON tree with serde_json-compatible numbers."""

    if value is None:
        return b"null"
    if value is True:
        return b"true"
    if value is False:
        return b"false"
    if isinstance(value, str):
        return json.dumps(value, ensure_ascii=False).encode("utf-8")
    if isinstance(value, int):
        return str(value).encode("ascii")
    if isinstance(value, float):
        return _serde_json_float(value).encode("ascii")
    if isinstance(value, list):
        return b"[" + b",".join(_serde_json_bytes(item) for item in value) + b"]"
    if isinstance(value, dict):
        entries = (
            _serde_json_bytes(key) + b":" + _serde_json_bytes(value[key])
            for key in sorted(value)
        )
        return b"{" + b",".join(entries) + b"}"
    raise ClosureAuditError(f"CORE_CANONICAL_TYPE:{type(value).__name__}")


def core_canonical_bytes(value: object) -> bytes:
    """Encode data exactly as the Rust/Godot core digest boundary does."""

    return _serde_json_bytes(_core_canonical_value(value))


def sha256(value: bytes) -> str:
    return "sha256:" + hashlib.sha256(value).hexdigest()


def git(
    root: Path,
    *arguments: str,
    text: bool = True,
) -> str | bytes:
    process = subprocess.run(
        ["git", *arguments],
        cwd=root,
        check=True,
        capture_output=True,
        text=text,
    )
    return process.stdout.rstrip() if text else process.stdout


def source_bytes(root: Path, source_commit: str, relative: str) -> bytes:
    value = git(root, "show", f"{source_commit}:{relative}", text=False)
    assert isinstance(value, bytes)
    return value


def verify_retained_commit(
    root: Path,
    source_commit: str,
    expected_parent: str,
) -> None:
    git(root, "cat-file", "-e", f"{source_commit}^{{commit}}")
    exact(
        git(root, "show", "-s", "--format=%P", source_commit),
        expected_parent,
        "SOURCE_PARENT",
    )
    for reference in ("HEAD", "origin/main"):
        descendant = git(root, "rev-parse", reference)
        assert isinstance(descendant, str)
        git(root, "merge-base", "--is-ancestor", source_commit, descendant)


def resolve_prospective_source_freeze(
    *,
    root: Path,
    contract: dict[str, Any],
    closure_path: Path,
    closure_schema: str,
    gate_id: str,
) -> tuple[str, bool]:
    """Resolve implementation identity before and after closure publication.

    A prospective source audit initially runs at the implementation freeze, but
    its physical preflight necessarily runs from a later commit that publishes
    the closure. Comparing the publication commit directly with the authored
    implementation-path set is therefore wrong. This helper selects the frozen
    implementation commit from the published closure when present, proves it is
    an ancestor of the current checkout, and applies the authored-path check to
    that immutable implementation delta in both phases.
    """

    head = git(root, "rev-parse", "HEAD")
    assert isinstance(head, str)
    published = closure_path.is_file()
    source_commit = head
    if published:
        closure = load(closure_path)
        exact(
            (closure["schema_version"], closure["gate_id"]),
            (closure_schema, gate_id),
            "PUBLICATION_CLOSURE_IDENTITY",
        )
        source_commit = str(closure["source"]["source_freeze_commit"])
        exact(closure["source"]["commit"], source_commit, "PUBLICATION_SOURCE")
        git(root, "cat-file", "-e", f"{source_commit}^{{commit}}")
        git(root, "merge-base", "--is-ancestor", source_commit, head)

    parent = str(contract["authored_parent_commit"])
    if source_commit != parent:
        changed = git(root, "diff", "--name-only", f"{parent}..{source_commit}")
        assert isinstance(changed, str)
        actual_paths = changed.splitlines()
        expected_paths = [str(path) for path in contract["authored_source_paths"]]
        exact(
            len(actual_paths),
            len(set(actual_paths)),
            "IMPLEMENTATION_COMMIT_PATHS_ACTUAL_UNIQUE",
        )
        exact(
            len(expected_paths),
            len(set(expected_paths)),
            "IMPLEMENTATION_COMMIT_PATHS_EXPECTED_UNIQUE",
        )
        exact(
            sorted(actual_paths),
            sorted(expected_paths),
            "IMPLEMENTATION_COMMIT_PATHS",
        )
    return source_commit, published


def frozen_manifest(
    root: Path,
    source_commit: str,
    paths: Sequence[str],
) -> list[dict[str, object]]:
    manifest: list[dict[str, object]] = []
    for relative in paths:
        value = source_bytes(root, source_commit, relative)
        oid = git(root, "rev-parse", f"{source_commit}:{relative}")
        assert isinstance(oid, str)
        manifest.append(
            {
                "path": relative,
                "blob_oid": oid,
                "byte_length": len(value),
                "raw_sha256": sha256(value),
            }
        )
    return manifest


def verify_frozen_manifest(
    root: Path,
    source_commit: str,
    paths: Sequence[str],
    claim: dict[str, Any],
) -> list[dict[str, object]]:
    manifest = frozen_manifest(root, source_commit, paths)
    encoded = canonical_bytes(manifest)
    exact(len(manifest), claim["entry_count"], "MANIFEST_COUNT")
    exact(len(encoded), claim["canonical_byte_length"], "MANIFEST_LENGTH")
    exact(sha256(encoded), claim["canonical_sha256"], "MANIFEST_HASH")
    return manifest


def verify_retained_json(
    path: Path,
    expected_byte_length: int,
    expected_raw_sha256: str,
    expected_canonical_byte_length: int,
    expected_canonical_sha256: str,
) -> dict[str, Any]:
    raw = path.read_bytes()
    exact(len(raw), expected_byte_length, "RETAINED_RAW_LENGTH")
    exact(sha256(raw), expected_raw_sha256, "RETAINED_RAW_HASH")
    value = loads(raw)
    encoded = canonical_bytes(value)
    exact(len(encoded), expected_canonical_byte_length, "RETAINED_CANONICAL_LENGTH")
    exact(sha256(encoded), expected_canonical_sha256, "RETAINED_CANONICAL_HASH")
    return value


def verify_current_git_identity(
    root: Path,
    source_commit: str,
    paths: Sequence[str],
) -> None:
    for relative in paths:
        subprocess.run(
            ["git", "diff", "--quiet", source_commit, "HEAD", "--", relative],
            cwd=root,
            check=True,
            capture_output=True,
        )


def verify_current_raw_bindings(
    root: Path,
    bindings: Sequence[dict[str, Any]],
) -> None:
    for binding in bindings:
        raw = (root / binding["path"]).read_bytes()
        exact(len(raw), binding["byte_length"], f"BOUND_LENGTH:{binding['path']}")
        exact(sha256(raw), binding["raw_sha256"], f"BOUND_HASH:{binding['path']}")


def find_external_source_root(
    search_root: Path,
    directory_name: str,
    bindings: Sequence[dict[str, Any]],
) -> Path:
    """Find one installed dependency tree matching a complete source binding."""

    for candidate in sorted(search_root.glob(f"*/{directory_name}")):
        if all(
            (candidate / str(binding["path"])).is_file()
            and len((candidate / str(binding["path"])).read_bytes())
            == binding["byte_length"]
            and sha256((candidate / str(binding["path"])).read_bytes())
            == binding["raw_sha256"]
            for binding in bindings
        ):
            return candidate
    raise ClosureAuditError(f"EXTERNAL_SOURCE_ROOT:{directory_name}")


def verify_version_pinned_crates_io_patch_source(
    root: Path,
    dependency: dict[str, Any],
    *,
    registry_source_root: Path | None = None,
    lock_relative_path: str = "sdk/Cargo.lock",
) -> tuple[Path, str]:
    """Verify one complete, version-pinned crates.io patch declaration.

    This is the shared source-audit half of the patched-dependency runner. The
    runner remains responsible for extracting the checksum-bound archive,
    applying the patch, compiling it, and binding every patched output file.
    """

    patch_path = (root / str(dependency["patch_path"])).resolve()
    require(patch_path.is_relative_to(root.resolve()), "PATCH_PATH_ESCAPE")
    patch_raw = patch_path.read_bytes()
    exact(
        (len(patch_raw), sha256(patch_raw)),
        (dependency["patch_byte_length"], dependency["patch_raw_sha256"]),
        "PATCH",
    )
    bindings = dependency["upstream_and_patched_files"]
    upstream_bindings = [
        {
            "path": item["path"],
            "byte_length": item["upstream_byte_length"],
            "raw_sha256": item["upstream_raw_sha256"],
        }
        for item in bindings
    ]
    upstream = find_external_source_root(
        registry_source_root or Path.home() / ".cargo/registry/src",
        str(dependency["installed_source_root_suffix"]),
        upstream_bindings,
    )
    subprocess.run(
        [
            "git", "-c", str(dependency["patch_application_git_config"]),
            "apply", "--check", str(patch_path),
        ],
        cwd=upstream,
        check=True,
    )
    lock = (root / lock_relative_path).read_text(encoding="utf-8")
    require_ordered_markers(
        lock,
        (
            'name = "' + str(dependency["crate"]) + '"',
            'version = "' + str(dependency["version"]) + '"',
            'source = "' + str(dependency["registry_source"]) + '"',
            'checksum = "' + str(dependency["cargo_registry_checksum"]) + '"',
        ),
        "LOCK",
    )
    return upstream, patch_raw.decode("utf-8")


def verify_declared_source_inventory(root: Path, paths: Sequence[str]) -> None:
    """Require one unique, complete file inventory for a source gate."""

    exact(len(paths), len(set(paths)), "SOURCE_INVENTORY")
    require(all((root / path).is_file() for path in paths), "SOURCE_INVENTORY_MISSING")


def require_ordered_markers(
    source: str,
    markers: Sequence[str],
    code: str,
) -> None:
    """Require exact source markers to occur in the declared order."""

    cursor = 0
    for marker in markers:
        position = source.find(marker, cursor)
        require(position >= 0, f"{code}:{marker}")
        cursor = position + len(marker)


def verify_retained_file_manifest(
    base: Path,
    entries: Sequence[dict[str, Any]],
) -> None:
    """Verify an ordered retained-artifact manifest without re-execution."""

    resolved_base = base.resolve()
    require(resolved_base.is_dir(), f"MANIFEST_BASE_MISSING:{resolved_base}")
    seen: set[str] = set()
    for entry in entries:
        relative = str(entry["path"])
        relative_path = Path(relative)
        require(
            not relative_path.is_absolute()
            and ".." not in relative_path.parts
            and relative not in seen,
            f"MANIFEST_PATH:{relative}",
        )
        seen.add(relative)
        path = (resolved_base / relative_path).resolve()
        require(path.is_relative_to(resolved_base), f"MANIFEST_ESCAPE:{relative}")
        require(path.is_file(), f"MANIFEST_FILE_MISSING:{relative}")
        raw = path.read_bytes()
        exact(len(raw), entry["byte_length"], f"MANIFEST_LENGTH:{relative}")
        exact(sha256(raw), entry["raw_sha256"], f"MANIFEST_HASH:{relative}")


def verify_source_receipt_manifest(
    root: Path,
    source_commit: str,
    entries: Sequence[dict[str, Any]],
    raw_representation: str = "git_blob",
) -> None:
    """Verify a qualification receipt's source manifest against frozen Git.

    Historical runners usually recorded raw Git-blob bytes. The reusable
    core-only runner records the exact checked-out bytes that its compiler read
    plus the Git-cleaned blob OID. Those bytes can differ on a text checkout
    (including a mixed-newline file edited before freeze), so the receipt digest
    binds the observed checkout hash while the blob OID binds immutable Git.
    """

    require(
        raw_representation in {"git_blob", "observed_checkout_plus_git_blob"},
        f"SOURCE_MANIFEST_REPRESENTATION:{raw_representation}",
    )

    seen: set[str] = set()
    for entry in entries:
        relative = str(entry["path"])
        require(relative not in seen, f"SOURCE_MANIFEST_DUPLICATE:{relative}")
        seen.add(relative)
        raw = source_bytes(root, source_commit, relative)
        exact(
            git(root, "rev-parse", f"{source_commit}:{relative}"),
            entry["git_blob_oid"],
            f"SOURCE_OID:{relative}",
        )
        if raw_representation == "git_blob":
            exact(len(raw), entry["byte_length"], f"SOURCE_LENGTH:{relative}")
            exact(sha256(raw), entry["raw_sha256"], f"SOURCE_HASH:{relative}")
        else:
            require(
                isinstance(entry["byte_length"], int)
                and entry["byte_length"] >= 0
                and isinstance(entry["raw_sha256"], str)
                and len(entry["raw_sha256"]) == 71
                and entry["raw_sha256"].startswith("sha256:")
                and all(
                    character in "0123456789abcdef"
                    for character in entry["raw_sha256"][7:]
                ),
                f"SOURCE_CHECKOUT_IDENTITY:{relative}",
            )


def exact_bools(
    value: dict[str, Any],
    keys: Sequence[str],
    expected: bool,
    prefix: str,
) -> None:
    """Check a compact group of boolean claim or authority fields."""

    for key in keys:
        exact(value[key], expected, f"{prefix}_{key.upper()}")


def verify_boolean_partition(
    value: dict[str, Any],
    true_keys: Sequence[str],
    false_keys: Sequence[str],
    prefix: str,
) -> None:
    """Verify every boolean field and reject undeclared boolean claims."""

    expected = set(true_keys) | set(false_keys)
    exact(len(expected), len(true_keys) + len(false_keys), f"{prefix}_DUPLICATE")
    exact(
        {key for key, item in value.items() if isinstance(item, bool)},
        expected,
        f"{prefix}_KEYS",
    )
    exact_bools(value, true_keys, True, prefix)
    exact_bools(value, false_keys, False, prefix)


def verify_exact_paths(
    value: dict[str, Any],
    expectations: dict[str, object],
    prefix: str,
) -> None:
    """Verify a compact declarative set of dotted JSON-object paths."""

    for dotted_path, expected in expectations.items():
        observed: Any = value
        for key in dotted_path.split("."):
            require(
                isinstance(observed, dict) and key in observed,
                f"{prefix}_PATH:{dotted_path}",
            )
            observed = observed[key]
        exact(observed, expected, f"{prefix}_{dotted_path.upper()}")


def verify_source_binding(
    root: Path,
    source_commit: str,
    binding: dict[str, Any],
) -> bytes:
    """Verify one declared source authority against immutable Git content."""

    relative = str(binding["path"])
    raw = source_bytes(root, source_commit, relative)
    exact(len(raw), binding["byte_length"], f"SOURCE_LENGTH:{relative}")
    exact(sha256(raw), binding["raw_sha256"], f"SOURCE_HASH:{relative}")
    exact(
        git(root, "rev-parse", f"{source_commit}:{relative}"),
        binding["git_blob_oid"],
        f"SOURCE_OID:{relative}",
    )
    return raw


def verify_bound_source_markers(
    bound: dict[str, bytes],
    expectations: dict[str, Sequence[str]],
    prefix: str,
) -> dict[str, str]:
    """Decode bound UTF-8 sources and verify compact declarative markers."""

    exact(set(bound), set(expectations), f"{prefix}_PATHS")
    decoded: dict[str, str] = {}
    for path, required in expectations.items():
        text = bound[path].decode("utf-8")
        require(all(marker in text for marker in required), f"{prefix}:{path}")
        decoded[path] = text
    return decoded


def verify_initial_relative_joint_limit_projection(
    rows: Sequence[dict[str, Any]],
    *,
    host_velocity_sign: float,
    prefix: str,
    tolerance: float = 1.0e-12,
    require_nontrivial_offset: bool = False,
) -> None:
    """Verify absolute joint limits projected into an initial-relative host frame."""

    require(host_velocity_sign in (-1.0, 1.0), f"{prefix}_SIGN")
    identities = [str(row["joint_id"]) for row in rows]
    exact(len(set(identities)), len(identities), f"{prefix}_IDENTITIES")

    def close(observed: float, expected: float, code: str) -> None:
        require(
            math.isclose(observed, expected, rel_tol=0.0, abs_tol=tolerance),
            code,
        )

    for row in rows:
        joint_id = str(row["joint_id"])
        q0 = float(row["q0_rad"])
        lower = float(row["canonical_lower_rad"])
        upper = float(row["canonical_upper_rad"])
        require(lower <= upper, f"{prefix}_CANONICAL_ORDER:{joint_id}")
        host_endpoints = sorted(
            (
                host_velocity_sign * (lower - q0),
                host_velocity_sign * (upper - q0),
            )
        )
        required_lower, required_upper = host_endpoints
        close(
            float(row["required_host_lower_rad"]),
            required_lower,
            f"{prefix}_HOST_LOWER:{joint_id}",
        )
        close(
            float(row["required_host_upper_rad"]),
            required_upper,
            f"{prefix}_HOST_UPPER:{joint_id}",
        )
        canonical_roundtrip = sorted(
            (
                q0 + required_lower / host_velocity_sign,
                q0 + required_upper / host_velocity_sign,
            )
        )
        close(canonical_roundtrip[0], lower, f"{prefix}_ROUNDTRIP_LOWER:{joint_id}")
        close(canonical_roundtrip[1], upper, f"{prefix}_ROUNDTRIP_UPPER:{joint_id}")
        current_canonical = sorted(
            (
                q0 + float(row["current_host_lower_rad"]) / host_velocity_sign,
                q0 + float(row["current_host_upper_rad"]) / host_velocity_sign,
            )
        )
        close(
            float(row["current_realizable_canonical_lower_rad"]),
            current_canonical[0],
            f"{prefix}_CURRENT_LOWER:{joint_id}",
        )
        close(
            float(row["current_realizable_canonical_upper_rad"]),
            current_canonical[1],
            f"{prefix}_CURRENT_UPPER:{joint_id}",
        )
        require(required_lower <= required_upper, f"{prefix}_SWAPPED:{joint_id}")
        if require_nontrivial_offset:
            require(
                not (
                    math.isclose(lower, required_lower, rel_tol=0.0, abs_tol=tolerance)
                    and math.isclose(upper, required_upper, rel_tol=0.0, abs_tol=tolerance)
                ),
                f"{prefix}_PASSTHROUGH:{joint_id}",
            )


def joint_position_ranges(
    observations: Sequence[dict[str, Any]],
    joint_ids: Sequence[str],
) -> dict[str, dict[str, float]]:
    """Project exact min, max, and final joint positions from a portable trace."""

    require(bool(observations), "JOINT_RANGE_EMPTY_TRACE")
    projected: dict[str, dict[str, float]] = {}
    for joint_id in joint_ids:
        values = [
            float(
                next(
                    item["position_rad"]
                    for item in sample["state"]["ordered_joint_observations"]
                    if item["joint_id"] == joint_id
                )
            )
            for sample in observations
        ]
        projected[joint_id] = {
            "minimum": min(values),
            "maximum": max(values),
            "final": values[-1],
        }
    return projected


def godot_recovery_phase_response_projection(
    arm: dict[str, Any],
    phase: str,
    *,
    settled_target_phase_step: int,
    tail_step_count: int,
) -> dict[str, Any]:
    """Project reusable control-response facts from one retained Godot arm.

    Godot behavior traces retain the observation produced by application N,
    while the control plan applied at N was authored from observation N - 1.
    This helper owns that alignment once so successor diagnoses do not grow
    their own campaign-specific indexing and cap-comparison code.
    """

    observations = arm["trace_v3"]["observations"]
    applications = arm["command_application_receipts"]
    plans = arm["planned_control_receipts"]
    steps = arm["portable_step_receipts"]
    exact(len(observations), len(applications), "PHASE_RESPONSE_APPLICATION_COUNT")
    exact(len(observations), len(steps), "PHASE_RESPONSE_STEP_COUNT")
    exact(len(plans), len(observations) - 1, "PHASE_RESPONSE_PLAN_COUNT")
    require(tail_step_count > 0, "PHASE_RESPONSE_TAIL_COUNT")

    indices = [
        index
        for index, application in enumerate(applications)
        if application["phase"] == phase
    ]
    require(bool(indices), f"PHASE_RESPONSE_EMPTY:{phase}")
    require(indices == list(range(indices[0], indices[-1] + 1)),
            f"PHASE_RESPONSE_NONCONTIGUOUS:{phase}")
    require(indices[0] > 0, f"PHASE_RESPONSE_UNPLANNED_FIRST:{phase}")
    require(len(indices) >= tail_step_count, f"PHASE_RESPONSE_SHORT_TAIL:{phase}")

    first_joints = observations[indices[0]]["state"]["ordered_joint_observations"]
    joint_ids = [str(item["joint_id"]) for item in first_joints]
    require(bool(joint_ids), "PHASE_RESPONSE_EMPTY_JOINT_SET")
    exact(len(joint_ids), len(set(joint_ids)), "PHASE_RESPONSE_JOINT_IDENTITIES")
    joint_rows: dict[str, list[dict[str, float | bool]]] = {
        joint_id: [] for joint_id in joint_ids
    }

    for index in indices:
        observation = observations[index]
        application = applications[index]
        plan = plans[index - 1]
        exact(
            int(application["source_control_semantic_step"]),
            int(plan["semantic_step"]),
            f"PHASE_RESPONSE_PLAN_ALIGNMENT:{index}",
        )
        observed_joints = observation["state"]["ordered_joint_observations"]
        impulses = observation["applied_actuation"]["ordered_applied_impulses"]
        intents = application["ordered_intents"]
        commands = plan["ordered_commands"]
        exact(
            (len(observed_joints), len(impulses), len(intents), len(commands)),
            (len(joint_ids),) * 4,
            f"PHASE_RESPONSE_WIDTH:{index}",
        )
        for offset, joint_id in enumerate(joint_ids):
            observed_joint = observed_joints[offset]
            impulse = impulses[offset]
            intent = intents[offset]
            command = commands[offset]
            exact(
                (
                    observed_joint["joint_id"],
                    impulse["actuator_id"],
                    intent["joint_id"],
                    intent["actuator_id"],
                    command["joint_id"],
                    command["actuator_id"],
                ),
                (
                    joint_id,
                    intent["actuator_id"],
                    joint_id,
                    intent["actuator_id"],
                    joint_id,
                    intent["actuator_id"],
                ),
                f"PHASE_RESPONSE_ORDER:{index}:{joint_id}",
            )
            cap = float(
                intent["host_cap_projection"][
                    "projected_native_effective_impulse_limit_nms"
                ]
            )
            applied = float(impulse["applied_angular_impulse_nms"])
            maximum_speed = float(command["maximum_target_speed_rad_s"])
            commanded_speed = float(intent["canonical_target_velocity_rad_s"])
            require(math.isfinite(cap) and cap >= 0.0,
                    f"PHASE_RESPONSE_CAP:{index}:{joint_id}")
            require(math.isfinite(applied),
                    f"PHASE_RESPONSE_APPLIED:{index}:{joint_id}")
            require(math.isfinite(maximum_speed) and maximum_speed > 0.0,
                    f"PHASE_RESPONSE_SPEED_CAP:{index}:{joint_id}")
            require(math.isfinite(commanded_speed),
                    f"PHASE_RESPONSE_COMMAND_SPEED:{index}:{joint_id}")
            joint_rows[joint_id].append(
                {
                    "position_rad": float(observed_joint["position_rad"]),
                    "target_position_rad": float(command["target_position_rad"]),
                    "phase_step": float(plan["phase_step"]),
                    "command_speed_capped": abs(commanded_speed)
                    >= maximum_speed - 1.0e-12,
                    "native_impulse_at_exact_cap": abs(applied) == cap,
                }
            )

    projected_joints: dict[str, dict[str, Any]] = {}
    settled_step_count: int | None = None
    for joint_id, rows in joint_rows.items():
        settled = [
            row
            for row in rows
            if row["phase_step"] >= float(settled_target_phase_step)
        ]
        require(bool(settled), f"PHASE_RESPONSE_SETTLED_EMPTY:{joint_id}")
        if settled_step_count is None:
            settled_step_count = len(settled)
        exact(len(settled), settled_step_count, f"PHASE_RESPONSE_SETTLED:{joint_id}")
        projected_joints[joint_id] = {
            "start_position_rad": rows[0]["position_rad"],
            "settled_target_entry_position_rad": settled[0]["position_rad"],
            "final_position_rad": rows[-1]["position_rad"],
            "final_target_position_rad": rows[-1]["target_position_rad"],
            "final_position_error_rad": (
                rows[-1]["target_position_rad"] - rows[-1]["position_rad"]
            ),
            "command_speed_cap_count": sum(
                bool(row["command_speed_capped"]) for row in rows
            ),
            "native_impulse_cap_exact_count": sum(
                bool(row["native_impulse_at_exact_cap"]) for row in rows
            ),
            "settled_target_step_count": len(settled),
            "settled_target_command_speed_cap_count": sum(
                bool(row["command_speed_capped"]) for row in settled
            ),
            "settled_target_native_impulse_cap_exact_count": sum(
                bool(row["native_impulse_at_exact_cap"]) for row in settled
            ),
            "tail_position_delta_rad": (
                rows[-1]["position_rad"] - rows[-tail_step_count]["position_rad"]
            ),
        }

    classifications = [steps[index]["classification"] for index in indices]
    maximum_com_height_gain_m = max(
        float(item["center_of_mass_height_gain_m"]) for item in classifications
    )
    maximum_com_offset = next(
        offset
        for offset, item in enumerate(classifications)
        if float(item["center_of_mass_height_gain_m"]) == maximum_com_height_gain_m
    )
    energy_channels = (
        "cumulative_signed_external_work_j",
        "cumulative_signed_constraint_exchange_j",
        "cumulative_signed_discrete_staging_exchange_j",
        "cumulative_passive_dissipation_j",
    )
    before_phase = observations[indices[0] - 1]["energy_balance"]
    after_phase = observations[indices[-1]]["energy_balance"]
    return {
        "phase_step_count": len(indices),
        "first_observation_index": indices[0],
        "last_observation_index": indices[-1],
        "settled_target_step_count": settled_step_count,
        "maximum_com_height_gain_m": maximum_com_height_gain_m,
        "maximum_com_phase_step_one_based": maximum_com_offset + 1,
        "final_com_height_gain_m": float(
            classifications[-1]["center_of_mass_height_gain_m"]
        ),
        "tail_com_height_gain_delta_m": (
            float(classifications[-1]["center_of_mass_height_gain_m"])
            - float(classifications[-tail_step_count]["center_of_mass_height_gain_m"])
        ),
        "maximum_torso_height_ratio": max(
            float(item["torso_height_ratio"]) for item in classifications
        ),
        "raised_body_gate_true_count": sum(
            bool(item["raised_body_gate"]) for item in classifications
        ),
        "safety_gate_true_count": sum(
            bool(item["safety_gate"]) for item in classifications
        ),
        "energy_within_0_25_j_count": sum(
            float(item["energy_balance_residual_j"]) <= 0.25
            for item in classifications
        ),
        "phase_mechanical_energy_delta_j": (
            float(after_phase["current_mechanical_energy_j"])
            - float(before_phase["current_mechanical_energy_j"])
        ),
        "phase_actuator_work_delta_j": (
            float(after_phase["cumulative_applied_actuator_work_j"])
            - float(before_phase["cumulative_applied_actuator_work_j"])
        ),
        "final_energy_balance_residual_j": float(
            classifications[-1]["energy_balance_residual_j"]
        ),
        "all_external_constraint_staging_passive_channels_structural_zero": all(
            all(float(observation["energy_balance"][key]) == 0.0 for key in energy_channels)
            for observation in observations
        ),
        "joints": projected_joints,
    }


def collision_masks_interact(first: dict[str, int], second: dict[str, int]) -> bool:
    """Apply Godot/Jolt's symmetric layer-mask interaction rule."""

    return bool(
        (int(first["mask"]) & int(second["layer"]))
        or (int(second["mask"]) & int(first["layer"]))
    )


def verify_legacy_live_authority_projection(
    root: Path,
    authority_paths: Sequence[str],
    *,
    record_key: str,
    expected: dict[str, Any],
    prefix: str,
) -> None:
    """Verify one live record while tolerating known legacy duplicate JSON keys."""

    for relative in authority_paths:
        authority = json.loads((root / relative).read_bytes())
        require(isinstance(authority, dict), f"{prefix}_OBJECT:{relative}")
        records = records_with_key(authority, record_key)
        exact(len(records), 1, f"{prefix}_COUNT:{relative}")
        exact(
            {key: records[0][key] for key in expected},
            expected,
            f"{prefix}:{relative}",
        )


def verify_exact_retained_inventory(
    base: Path,
    entries: Sequence[dict[str, Any]],
) -> None:
    """Bind every retained file and reject undeclared files in an evidence root."""

    resolved_base = base.resolve()
    require(resolved_base.is_dir(), f"INVENTORY_BASE_MISSING:{resolved_base}")
    declared = {str(entry["path"]).replace("\\", "/") for entry in entries}
    exact(len(declared), len(entries), f"INVENTORY_DUPLICATE:{resolved_base}")
    observed = {
        path.relative_to(resolved_base).as_posix()
        for path in resolved_base.rglob("*")
        if path.is_file()
    }
    exact(observed, declared, f"INVENTORY:{resolved_base}")
    verify_retained_file_manifest(resolved_base, entries)


def retained_file_tree_projection(base: Path) -> dict[str, object]:
    """Content-address every retained file without embedding the full inventory."""

    resolved_base = base.resolve()
    require(resolved_base.is_dir(), f"TREE_BASE_MISSING:{resolved_base}")
    entries: list[dict[str, object]] = []
    for path in resolved_base.rglob("*"):
        require(not path.is_symlink(), f"TREE_SYMLINK:{path}")
        if not path.is_file():
            continue
        raw = path.read_bytes()
        entries.append(
            {
                "path": path.relative_to(resolved_base).as_posix(),
                "byte_length": len(raw),
                "raw_sha256": sha256(raw),
            }
        )
    entries.sort(key=lambda item: str(item["path"]))
    encoded = canonical_bytes(entries)
    return {
        "schema_version": "sporespore_retained_file_tree_manifest_v1",
        "file_count": len(entries),
        "total_byte_length": sum(int(item["byte_length"]) for item in entries),
        "manifest_canonical_byte_length": len(encoded),
        "manifest_canonical_sha256": sha256(encoded),
    }


def verify_retained_file_tree(base: Path, expected: dict[str, Any]) -> None:
    """Verify a compact, complete, content-addressed retained file population."""

    exact(retained_file_tree_projection(base), expected, f"TREE:{base.resolve()}")


def matching_evidence_roots(
    parent: Path,
    directory_prefix: str,
    identity_file: str,
    gate_id: str,
    source_commit: str,
) -> list[Path]:
    """Find all retained attempts that consumed one exact gate/source identity."""

    matches: list[Path] = []
    for directory in sorted(parent.glob(f"{directory_prefix}*")):
        candidate = directory / identity_file
        if not candidate.is_file():
            continue
        value = load(candidate)
        if (
            value.get("gate_id") == gate_id
            and value.get("source_commit") == source_commit
        ):
            matches.append(directory)
    return matches


def verify_content_addressed_json(
    claim: dict[str, Any],
    *,
    label: str,
) -> dict[str, Any]:
    """Verify one durable JSON CAS payload and its compact manifest."""

    payload = Path(str(claim["payload_path"]))
    manifest_path = Path(str(claim["manifest_path"]))
    raw = payload.read_bytes()
    exact((len(raw), sha256(raw)),
          (claim["byte_length"], claim["sha256"]), label)
    manifest = load(manifest_path)
    verify_exact_paths(
        manifest,
        {
            "schema_version": "sporespore_content_addressed_artifact_manifest_v1",
            "algorithm": "sha256",
            "sha256": claim["sha256"],
            "byte_length": claim["byte_length"],
            "payload_name": "payload.bin",
            "media_type": "application/json",
        },
        f"{label}_MANIFEST",
    )
    return loads(raw)


def verify_supervised_bounded_ghost_attempt(
    *,
    physical: dict[str, Any],
    gate_id: str,
    source_commit: str,
    status: str,
    schemas: dict[str, str],
    raw_count_keys: Sequence[str] = (
        "model_construction_count",
        "world_attempt_count",
        "world_build_count",
        "solver_step_count",
        "behavior_evaluator_invocation_count",
        "threshold_count",
        "margin_count",
        "held_out_cell_access_count",
    ),
) -> dict[str, dict[str, Any]]:
    """Verify the repeated mechanics of one finite supervised physical attempt.

    Successor-specific audits retain responsibility for the causal diagnosis,
    interpretation, and next scientific authority. This helper owns the exact
    attempt population, complete retained tree, JSON/log hashes, source and
    authorization binding, lock/worker lifecycle, bounded counts, CAS copies,
    and universal fail-closed claim fields.
    """

    evidence = Path(str(physical["evidence_root"]))
    exact(
        matching_evidence_roots(
            evidence.parent, "", "attempt.json", gate_id, source_commit
        ),
        [evidence],
        "GHOST_ATTEMPT_POPULATION",
    )
    verify_retained_file_tree(evidence, physical["retained_tree"])
    artifacts = physical["artifacts"]
    exact(set(artifacts), {"attempt", "raw", "terminal", "stdout", "stderr"},
          "GHOST_ARTIFACT_KEYS")

    values: dict[str, dict[str, Any]] = {}
    for key in ("attempt", "raw", "terminal"):
        artifact = artifacts[key]
        values[key] = verify_retained_json(
            evidence / str(artifact["path"]),
            int(artifact["byte_length"]),
            str(artifact["raw_sha256"]),
            int(artifact["canonical_byte_length"]),
            str(artifact["canonical_sha256"]),
        )
        exact(values[key]["schema_version"], schemas[key],
              f"GHOST_{key.upper()}_SCHEMA")
    for key in ("stdout", "stderr"):
        artifact = artifacts[key]
        raw = (evidence / str(artifact["path"])).read_bytes()
        exact((len(raw), sha256(raw)),
              (artifact["byte_length"], artifact["raw_sha256"]),
              f"GHOST_{key.upper()}")

    attempt, raw, terminal = values["attempt"], values["raw"], values["terminal"]
    common = {
        "gate_id": gate_id,
        "question_class": "development",
        "status": status,
        "attempt_id": physical["attempt_id"],
        "source_commit": source_commit,
        "seed": physical["seed"],
        "seed_sha256": physical["seed_sha256"],
        "held_out": False,
        "physical_acceptance_authority": False,
        "release_authority": False,
    }
    verify_exact_paths(attempt, common, "GHOST_ATTEMPT")
    verify_exact_paths(
        attempt,
        {
            "authorization_sha256": physical["authorization_sha256"],
            "authorization_control_sha256": physical["authorization_control_sha256"],
            "maximum_world_build_count": physical["maximum_world_build_count"],
            "maximum_solver_step_count": physical["maximum_solver_step_count"],
            "operation_lock.acquired": True,
            "operation_lock.role": "physical_development",
            "operation_lock.test_only": False,
        },
        "GHOST_ATTEMPT_AUTHORITY",
    )
    verify_exact_paths(
        terminal,
        {
            "gate_id": gate_id,
            "question_class": "development",
            "status": status,
            "integration_ghost_passed": physical["integration_ghost_passed"],
            "attempt_id": physical["attempt_id"],
            "source.head": source_commit,
            "source.upstream": source_commit,
            "source.cached_origin_main": source_commit,
            "source.live_origin_main": source_commit,
            "source.worktree_clean": True,
            "authorization.raw_sha256": physical["authorization_sha256"],
            "worker.semantic_exit_code": physical["worker_semantic_exit_code"],
            "worker.host_exit_code": physical["worker_host_exit_code"],
            "worker.timed_out": False,
            "worker.termination_protocol_valid": True,
            "worker.raw_marker_count": 1,
            "worker.raw_binding_valid": True,
            "same_identity_rerun_permitted": False,
            "held_out": False,
            "recovery_success_required": False,
            "prone_to_standing_claimed": False,
            "physical_acceptance_authority": False,
            "release_authority": False,
        },
        "GHOST_TERMINAL",
    )
    if physical["authorization_control_sha256"] is None:
        exact(terminal["authorization"]["control"], None,
              "GHOST_TERMINAL_AUTHORIZATION_CONTROL")
    else:
        exact(
            terminal["authorization"]["control"]["raw_sha256"],
            physical["authorization_control_sha256"],
            "GHOST_TERMINAL_AUTHORIZATION_CONTROL",
        )
    verify_exact_paths(raw, common, "GHOST_RAW")
    for key in raw_count_keys:
        exact(raw[key], physical[key], f"GHOST_RAW_{key.upper()}")
    for value, label in ((attempt, "ATTEMPT"), (raw, "RAW"), (terminal, "TERMINAL")):
        keys = ["physical_acceptance_authority", "release_authority"]
        if label != "ATTEMPT":
            keys.insert(0, "prone_to_standing_claimed")
        for key in keys:
            exact(value[key], False, f"GHOST_{label}_{key.upper()}")

    exact(terminal["raw_result"]["raw_sha256"], artifacts["raw"]["raw_sha256"],
          "GHOST_TERMINAL_RAW_HASH")
    exact(terminal["raw_result"]["byte_length"], artifacts["raw"]["byte_length"],
          "GHOST_TERMINAL_RAW_LENGTH")
    verify_content_addressed_json(physical["raw_result_cas"], label="GHOST_RAW_CAS")
    verify_content_addressed_json(physical["terminal_cas"], label="GHOST_TERMINAL_CAS")
    return values


def complete_in_run_physical_invariant_projection(
    value: object,
) -> dict[str, object]:
    """Project complete finite/raw invariant populations from retained JSON.

    Campaign audits remain responsible for the meaning and adequacy of their
    named invariants. This shared walker prevents each successor from copying
    the same exhaustive numeric, validity, source-measurement, and external-
    intervention population scan.
    """

    numbers: list[float] = []
    validity_records: list[dict[str, object]] = []
    source_measurements: list[bool] = []
    external_interventions: list[dict[str, object]] = []

    def walk(current: object) -> None:
        if isinstance(current, dict):
            validity = current.get("validity")
            if isinstance(validity, dict):
                validity_records.append(validity)
            source_measurement = current.get("source_measurement")
            if isinstance(source_measurement, bool):
                source_measurements.append(source_measurement)
            interventions = current.get("external_interventions")
            if isinstance(interventions, dict):
                external_interventions.append(interventions)
            for child in current.values():
                walk(child)
        elif isinstance(current, list):
            for child in current:
                walk(child)
        elif isinstance(current, (int, float)) and not isinstance(current, bool):
            numbers.append(float(current))

    walk(value)
    return {
        "complete_raw_numeric_scalar_count": len(numbers),
        "all_raw_numeric_scalars_finite": all(math.isfinite(item) for item in numbers),
        "validity_record_count": len(validity_records),
        "validity_field_count": sum(len(record) for record in validity_records),
        "all_validity_fields_true": all(
            all(field is True for field in record.values())
            for record in validity_records
        ),
        "source_measurement_flag_count": len(source_measurements),
        "all_source_measurement_flags_true": all(source_measurements),
        "external_intervention_receipt_count": len(external_interventions),
        "external_intervention_field_count": sum(
            len(record) for record in external_interventions
        ),
        "external_intervention_total": sum(
            float(field)
            for record in external_interventions
            for field in record.values()
        ),
    }


def verify_two_step_native_portable_route(
    raw: dict[str, Any],
    *,
    phase: str,
    joint_count: int,
) -> dict[str, Any]:
    """Verify common two-step native/portable route traversal mechanics."""

    require(joint_count > 0, "TWO_STEP_JOINT_COUNT")
    steps: dict[str, Any] = {}
    for name, solver_step, semantic_step in (
        ("first_step", 1, 1.0),
        ("second_step", 2, 2.0),
    ):
        step = raw[name]
        verify_exact_paths(
            step["native_route"],
            {
                "ok": True,
                "model_construction_count": 1,
                "world_attempt_count": 1,
                "world_build_count": 1,
                "solver_step_count": solver_step,
                "physics_state_modified": True,
                "native_runtime_observation_collection_executed": True,
            },
            f"{name.upper()}_NATIVE",
        )
        portable = step["portable_route"]
        verify_exact_paths(
            portable,
            {
                "ok": True,
                "model_construction_count": 0,
                "world_attempt_count": 0,
                "world_build_count": 0,
                "solver_step_count": 0,
                "physics_state_modified": False,
                "control_receipt.phase": phase,
                "control_receipt.semantic_step": semantic_step,
            },
            f"{name.upper()}_PORTABLE",
        )
        commands = portable["control_receipt"]["ordered_commands"]
        joints = portable["collection_request"]["observation"]["state"][
            "ordered_joint_observations"
        ]
        exact(len(commands), joint_count, f"{name.upper()}_COMMANDS")
        exact(len(joints), joint_count, f"{name.upper()}_JOINTS")
        require(
            all(all(row["validity"].values()) for row in joints),
            f"{name.upper()}_JOINT_VALIDITY",
        )
        steps[name] = step
    return steps


def verify_force_based_joint_impulse_application(
    application: dict[str, Any],
    *,
    actuator_mapping_id: str,
    work_mapping_id: str,
    joint_count: int,
) -> dict[str, Any]:
    """Verify reusable equal-and-opposite force-based application mechanics."""

    verify_exact_paths(
        application,
        {
            "ok": True,
            "actuator_mapping_id": actuator_mapping_id,
            "work_mapping_id": work_mapping_id,
            "validated_command_count": joint_count,
            "host_write_count": joint_count * 2,
            "body_impulse_write_count": joint_count * 2,
            "host_readback_count": joint_count,
            "hard_constraint_motor_disabled_count": joint_count,
            "hard_constraint_motor_target_write_count": 0,
            "motor_enabled_count": 0,
            "fallback_control_count": 0,
            "root_actuation_count": 0,
            "zero_world_host_surface": False,
        },
        "FORCE_APPLICATION",
    )
    intents = application["ordered_intents"]
    receipts = application["ordered_receipts"]
    exact((len(intents), len(receipts)), (joint_count, joint_count),
          "FORCE_APPLICATION_COUNTS")
    exact(intents, receipts, "FORCE_APPLICATION_INTENT_RECEIPT_EQUALITY")
    require(
        all(
            row["ok"]
            and row["source_measurement"]
            and row["actuator_mapping_id"] == actuator_mapping_id
            and row["equal_and_opposite_pair"]
            and not row["hard_constraint_velocity_motor_enabled"]
            and row["parent_call_returned"]
            and row["child_call_returned"]
            and not row["mechanical_energy_residual_used_as_work_source"]
            and row["body_impulse_write_count"] == 2
            and all(
                component == 0.0
                for component in row["pairing_residual_world_nms"].values()
            )
            and abs(float(row["axis_world_length_squared"]) - 1.0)
            <= float(row["axis_unit_length_squared_tolerance"])
            and abs(float(row["applied_signed_joint_impulse_nms"]))
            <= float(row["published_maximum_outer_step_impulse_nms"])
            for row in receipts
        ),
        "FORCE_APPLICATION_RECEIPTS",
    )
    absolute_applied = [
        abs(float(row["applied_signed_joint_impulse_nms"])) for row in receipts
    ]
    published_caps = [
        float(row["published_maximum_outer_step_impulse_nms"]) for row in receipts
    ]
    return {
        "receipts": receipts,
        "intent_receipt_equality_passed": True,
        "positive_impulse_count": sum(
            float(row["applied_signed_joint_impulse_nms"]) > 0 for row in receipts
        ),
        "negative_impulse_count": sum(
            float(row["applied_signed_joint_impulse_nms"]) < 0 for row in receipts
        ),
        "saturated_count": sum(bool(row["impulse_saturated"]) for row in receipts),
        "representation_projection_count": sum(
            bool(row["representation_projection_applied"]) for row in receipts
        ),
        "minimum_absolute_applied_impulse_nms": min(absolute_applied),
        "maximum_absolute_applied_impulse_nms": max(absolute_applied),
        "minimum_published_cap_nms": min(published_caps),
        "maximum_published_cap_nms": max(published_caps),
        "maximum_pairing_residual_component_nms": max(
            abs(float(component))
            for row in receipts
            for component in row["pairing_residual_world_nms"].values()
        ),
    }


def verify_force_based_joint_work_source(
    telemetry: dict[str, Any],
    *,
    application_receipts: Sequence[dict[str, Any]],
    actuator_mapping_id: str,
    work_mapping_id: str,
) -> dict[str, Any]:
    """Verify centered source-measured work derived from applied impulses."""

    verify_exact_paths(
        telemetry,
        {
            "source_measurement": True,
            "actuator_mapping_id": actuator_mapping_id,
            "work_mapping_id": work_mapping_id,
            "body_impulse_write_count": len(application_receipts) * 2,
            "hard_constraint_velocity_motor_enabled_count": 0,
            "mechanical_energy_residual_used_as_work_source": False,
            "work_equation": (
                "applied_signed_joint_impulse_times_centered_pre_post_relative_velocity"
            ),
        },
        "FORCE_WORK_SOURCE",
    )
    rows = telemetry["ordered_telemetry"]
    exact(len(rows), len(application_receipts), "FORCE_WORK_ROW_COUNT")
    by_joint = {str(row["joint_id"]): row for row in application_receipts}
    exact(len(by_joint), len(application_receipts), "FORCE_WORK_JOINT_IDENTITIES")
    for row in rows:
        expected_work = float(row["signed_motor_impulse_nms"]) * float(
            row["centered_relative_velocity_rad_s"]
        )
        require(
            math.isclose(
                float(row["net_motor_work_j"]),
                expected_work,
                rel_tol=1e-12,
                abs_tol=1e-12,
            ),
            "FORCE_WORK_EQUATION",
        )
        exact(
            row["signed_motor_impulse_nms"],
            by_joint[str(row["joint_id"])]["applied_signed_joint_impulse_nms"],
            "FORCE_WORK_IMPULSE_BINDING",
        )
        exact(row["actuator_mapping_id"], actuator_mapping_id,
              "FORCE_WORK_ACTUATOR_MAPPING")
        exact(row["work_mapping_id"], work_mapping_id, "FORCE_WORK_MAPPING")
        exact(row["net_motor_work_projection_delta_j"], 0.0,
              "FORCE_WORK_PROJECTION_DELTA")
        exact(row["mechanical_energy_residual_used_as_work_source"], False,
              "FORCE_WORK_RESIDUAL_SOURCE")
    net_work = sum(float(row["net_motor_work_j"]) for row in rows)
    require(
        math.isclose(
            net_work,
            float(telemetry["step_net_motor_work_j"]),
            rel_tol=1e-12,
            abs_tol=1e-12,
        ),
        "FORCE_WORK_SUM",
    )
    return {
        "row_count": len(rows),
        "positive_work_row_count": sum(
            float(row["positive_motor_work_j"]) > 0 for row in rows
        ),
        "absorbed_work_row_count": sum(
            float(row["absorbed_motor_work_j"]) > 0 for row in rows
        ),
        "saturated_count": sum(bool(row["impulse_saturated"]) for row in rows),
        "mechanical_energy_residual_used_count": sum(
            bool(row["mechanical_energy_residual_used_as_work_source"])
            for row in rows
        ),
        "maximum_work_projection_delta_j": max(
            abs(float(row["net_motor_work_projection_delta_j"])) for row in rows
        ),
        "net_motor_work_j": net_work,
    }


def transition_projection(
    receipts: Sequence[dict[str, Any]],
) -> tuple[list[list[str]], list[int]]:
    """Project portable transition identities without campaign-specific logic."""

    transitioned = [
        (index, receipt)
        for index, receipt in enumerate(receipts)
        if receipt["transitioned"] is True
    ]
    return (
        [
            [str(receipt["prior_phase"]), str(receipt["next_phase"])]
            for _, receipt in transitioned
        ],
        [index for index, _ in transitioned],
    )


def exact_true_checks(
    checks: dict[str, Any], expected: set[str], code: str
) -> None:
    """Require one exact named check population with every check passing."""

    exact(set(checks), expected, f"{code}_KEYS")
    require(all(checks.values()), f"{code}_VALUES")


def find_gate_nodes(value: object, gate_id: str) -> list[dict[str, Any]]:
    """Find every gate node in a legacy live authority object."""

    found: list[dict[str, Any]] = []
    if isinstance(value, dict):
        if value.get("gate_id") == gate_id:
            found.append(value)
        for child in value.values():
            found.extend(find_gate_nodes(child, gate_id))
    elif isinstance(value, list):
        for child in value:
            found.extend(find_gate_nodes(child, gate_id))
    return found


def load_legacy_live_authority(path: Path) -> dict[str, Any]:
    """Load a live authority whose retained legacy keys predate strict parsing."""

    value = json.loads(path.read_bytes())
    require(isinstance(value, dict), f"LIVE_AUTHORITY_ROOT:{path}")
    return value


def verify_legacy_live_gate_paths(
    root: Path,
    paths: Sequence[str],
    gate_id: str,
    expectations: dict[str, object],
    revision: str | None = None,
) -> None:
    """Verify one gate node now or at its immutable publication revision."""

    for relative in paths:
        authority = (
            load_legacy_live_authority(root / relative)
            if revision is None
            else json.loads(source_bytes(root, revision, relative))
        )
        require(isinstance(authority, dict), f"LIVE_AUTHORITY_ROOT:{relative}")
        nodes = find_gate_nodes(authority, gate_id)
        exact(len(nodes), 1, f"LIVE_GATE_COUNT:{relative}")
        verify_exact_paths(nodes[0], expectations, f"LIVE_GATE:{relative}")


def _active_application_indices(arm: dict[str, Any]) -> list[int]:
    return [
        index
        for index, receipt in enumerate(arm["native_receipts"])
        if receipt["application"]["no_actuation_requested"] is False
    ]


def _stance_completion_candidate_projection(
    summary: dict[str, Any], arm: dict[str, Any]
) -> dict[str, Any]:
    compact = summary["candidate"]
    observations = arm["observations"]
    steps = arm["portable_step_receipts"]
    active = _active_application_indices(arm)
    stance_observations = [
        observation
        for observation in observations
        if observation["controller_ownership"]["owner"] == "stance"
    ]
    stance_requests = [
        observation
        for observation in observations
        if observation["applied_actuation"]["command_id"].startswith(
            "candidate_command_stance_"
        )
    ]
    records = compact["transition_records"]
    transition_indices = {
        (record["prior_phase"], record["next_phase"]): record[
            "outer_index_zero_based"
        ]
        for record in records
    }
    exact(
        [[record["prior_phase"], record["next_phase"]] for record in records],
        compact["transition_pairs"],
        "STANCE_CANDIDATE_TRANSITION_RECORDS",
    )
    exact(len(active), compact["active_application_count"], "STANCE_CANDIDATE_ACTIVE")
    exact(
        (active[0], active[-1]),
        (
            compact["first_active_outer_index_zero_based"],
            compact["last_active_outer_index_zero_based"],
        ),
        "STANCE_CANDIDATE_ACTIVE_RANGE",
    )
    exact(
        (len(stance_observations), len(stance_requests)),
        (
            summary["candidate_stance_observation_count"],
            summary["candidate_stance_control_request_count"],
        ),
        "STANCE_CANDIDATE_CONTROL_COUNTS",
    )
    require(
        all(
            observation["controller_ownership"]["fallback_controller_active"]
            is False
            for observation in stance_observations
        ),
        "STANCE_CANDIDATE_FALLBACK",
    )
    final_step = steps[-1]
    final_observation = observations[-1]
    final_classification = final_step["classification"]
    ownership = final_observation["controller_ownership"]
    memory = final_step["memory"]
    exact(
        sum(final_observation["external_interventions"].values()),
        0,
        "STANCE_CANDIDATE_FINAL_INTERVENTIONS",
    )
    return {
        "outer_step_count": compact["outer_step_count"],
        "native_solver_step_count": arm["native_solver_step_count"],
        "active_application_count": len(active),
        "first_active_outer_index_zero_based": active[0],
        "last_active_outer_index_zero_based": active[-1],
        "final_phase": compact["final_phase"],
        "terminal_failure_code": compact["terminal_failure_code"],
        "transition_pairs": compact["transition_pairs"],
        "stance_handoff_outer_index_zero_based": transition_indices[
            ("raise_body", "stance_handoff")
        ],
        "stance_dwell_outer_index_zero_based": transition_indices[
            ("stance_handoff", "stance_dwell")
        ],
        "complete_outer_index_zero_based": transition_indices[
            ("stance_dwell", "complete")
        ],
        "stance_observation_count": len(stance_observations),
        "stance_control_request_count": len(stance_requests),
        "final_stance_dwell_steps_observed": memory[
            "stance_dwell_steps_observed"
        ],
        "final_controller_owner": ownership["owner"],
        "final_stance_controller_id": ownership["stance_controller_id"],
        "final_pose_class": final_classification["pose_class"],
        "final_torso_height_ratio": final_classification["torso_height_ratio"],
        "final_torso_up_dot": final_classification["torso_up_dot"],
        "final_linear_speed_m_s": final_classification[
            "terminal_linear_speed_m_s"
        ],
        "final_angular_speed_rad_s": final_classification[
            "terminal_angular_speed_rad_s"
        ],
        "final_minimum_nonfoot_clearance_m": final_classification[
            "minimum_nonfoot_clearance_m"
        ],
        "final_energy_balance_residual_j": final_classification[
            "energy_balance_residual_j"
        ],
        "final_intervention_counter_total": final_classification[
            "intervention_counter_total"
        ],
        "final_no_cheat_gate": final_classification["no_cheat_gate"],
        "final_safety_gate": final_classification["safety_gate"],
        "final_stable_stance_gate": final_classification["stable_stance_gate"],
    }


def _stance_completion_matched_projection(
    summary: dict[str, Any], arm: dict[str, Any]
) -> dict[str, Any]:
    compact = summary["matched_zero_command"]
    observations = arm["observations"]
    return {
        "outer_step_count": compact["outer_step_count"],
        "native_solver_step_count": arm["native_solver_step_count"],
        "active_application_count": len(_active_application_indices(arm)),
        "observations_all_zero_command": all(
            observation["applied_actuation"]["zero_command"]
            for observation in observations
        ),
        "stance_control_request_count": sum(
            observation["controller_ownership"]["owner"] == "stance"
            for observation in observations
        ),
        "final_phase": compact["final_phase"],
        "terminal_failure_code": compact["terminal_failure_code"],
    }


def verify_stance_completion_physical_positive(
    *,
    summary: dict[str, Any],
    full: dict[str, Any],
    observed: dict[str, Any],
    expected_execution_checks: set[str],
    expected_target_checks: set[str],
    expected_transitions: list[list[str]],
) -> None:
    """Verify the reusable exact-pair stance-completion evidence shape."""

    exact(
        (
            summary["execution_valid"],
            summary["decision_positive"],
            summary["valid_negative_if_decision_not_positive"],
            summary["exact_nominal_mujoco_prone_to_standing_observed"],
        ),
        (True, True, False, True),
        "STANCE_PHYSICAL_DECISION",
    )
    exact_true_checks(
        summary["execution_checks"], expected_execution_checks, "STANCE_EXECUTION"
    )
    exact_true_checks(summary["target_checks"], expected_target_checks, "STANCE_TARGET")
    result = full["result"]
    exact(
        _stance_completion_candidate_projection(summary, result["candidate"]),
        observed["candidate"],
        "STANCE_CANDIDATE",
    )
    exact(
        _stance_completion_matched_projection(
            summary, result["matched_zero_command"]
        ),
        observed["matched_zero_command"],
        "STANCE_MATCHED_ZERO",
    )
    exact(
        summary["candidate"]["transition_pairs"],
        expected_transitions,
        "STANCE_PHASE_SEQUENCE",
    )
    final_candidate_step = result["candidate"]["portable_step_receipts"][-1]
    exact(
        (
            final_candidate_step["physical_result"],
            final_candidate_step["prone_to_standing_claimed"],
            result["candidate"]["stance_continuation_commissioned"],
        ),
        (True, True, True),
        "STANCE_EXACT_CELL_RESULT",
    )
    evaluation = result["evaluation"]
    exact(
        (
            evaluation["support_status"],
            evaluation["verdict"],
            evaluation["physical_development_trace_valid"],
            evaluation["candidate_physical_path_completed"],
            evaluation[
                "matched_zero_command_physical_control_failed_to_complete"
            ],
            evaluation["all_negative_control_requirements_enforced"],
        ),
        (
            "supported_exact",
            observed["portable_evaluation_verdict"],
            True,
            True,
            True,
            True,
        ),
        "STANCE_PORTABLE_EVALUATION",
    )
    exact(
        (len(summary["execution_checks"]), sum(summary["execution_checks"].values())),
        (observed["execution_check_count"], observed["execution_checks_passed"]),
        "STANCE_EXECUTION_COUNT",
    )
    exact(
        (len(summary["target_checks"]), sum(summary["target_checks"].values())),
        (observed["target_check_count"], observed["target_checks_passed"]),
        "STANCE_TARGET_COUNT",
    )
    trace = summary["trace_invariants"]
    exact(trace, full["trace_invariants"], "STANCE_TRACE_PROJECTION")
    verify_exact_paths(
        trace,
        {
            "validated_arm_count": 2,
            "arm_step_counts.candidate_command": observed["candidate"][
                "outer_step_count"
            ],
            "arm_step_counts.matched_zero_command": observed[
                "matched_zero_command"
            ]["outer_step_count"],
            "validated_outer_step_count": observed["validated_outer_step_count"],
            "validated_native_substep_count": observed[
                "validated_native_substep_count"
            ],
            "natural_stops_validated": True,
            "streaming_chain_replayed_once": observed[
                "streaming_chain_replayed_once"
            ],
            "portable_publication_replayed_exact": observed[
                "portable_publication_replayed_exact"
            ],
            "final_legacy_full_aggregate_execution_count": observed[
                "final_legacy_full_aggregate_execution_count"
            ],
            "final_legacy_full_aggregate_numeric_parity": observed[
                "final_legacy_full_aggregate_numeric_parity"
            ],
            "retained_streaming_publication_canonical_byte_count": observed[
                "retained_streaming_publication_canonical_byte_count"
            ],
            "full_streaming_publications_retained_inline": True,
            "current_batch_mapping_cardinality_bounded": True,
            "behavior_threshold_selected_or_changed": False,
        },
        "STANCE_TRACE",
    )
    invariant_receipts = trace["in_run_invariant_receipt_sha256s"]
    exact(
        len(invariant_receipts),
        observed["in_run_invariant_receipt_count"],
        "STANCE_IN_RUN_INVARIANT_COUNT",
    )
    require(
        all(
            isinstance(value, str)
            and value.startswith("sha256:")
            and len(value) == 71
            for value in invariant_receipts
        ),
        "STANCE_IN_RUN_INVARIANT_DIGESTS",
    )


def verify_portable_arm_projection(
    arm: dict[str, Any],
    claim: dict[str, Any],
    label: str,
) -> None:
    """Verify common full-trace arm counts, transitions, and support receipts."""

    exact(arm["outer_step_count"], claim["outer_step_count"], f"{label}_OUTER")
    exact(
        arm["native_solver_step_count"],
        claim["native_solver_step_count"],
        f"{label}_SOLVER",
    )
    for key, field in (
        ("observations", "observation_count"),
        ("native_receipts", "native_receipt_count"),
        ("collector_receipts", "collector_receipt_count"),
        ("portable_step_receipts", "portable_receipt_count"),
    ):
        exact(len(arm[key]), claim[field], f"{label}_{field.upper()}")
    exact(arm["final_phase"], claim["final_phase"], f"{label}_PHASE")
    pairs, indices = transition_projection(arm["portable_step_receipts"])
    exact(pairs, claim["transition_pairs"], f"{label}_TRANSITIONS")
    exact(indices, claim["transition_indices_zero_based"], f"{label}_INDICES")
    exact(
        arm["portable_step_receipts"][-1]["memory"]["terminal_failure_code"],
        claim["terminal_failure_code"],
        f"{label}_FAILURE",
    )
    require(
        all(
            receipt["support_status"] == "supported_exact"
            and receipt["refusal_reason"] is None
            and receipt["classification"]["joint_limits_respected"] is True
            for receipt in arm["portable_step_receipts"]
        ),
        f"{label}_PORTABLE_RECEIPT",
    )


def native_energy_terms(
    arm: dict[str, Any],
    index: int,
) -> dict[str, float]:
    """Project independently sourced native and portable cumulative energy terms."""

    native = arm["native_receipts"][index]["native_step"]
    energy = arm["observations"][index]["energy_balance"]
    classification = arm["portable_step_receipts"][index]["classification"]
    return {
        "initial_mechanical_energy": energy["initial_mechanical_energy_j"],
        "current_mechanical_energy": energy["current_mechanical_energy_j"],
        "cumulative_actuator_work": energy["cumulative_applied_actuator_work_j"],
        "cumulative_constraint_work": native["cumulative_constraint_work_j"],
        "cumulative_damper_work": native["cumulative_damper_work_j"],
        "cumulative_fluid_work": native["cumulative_fluid_work_j"],
        "cumulative_adhesion_work": native["cumulative_adhesion_work_j"],
        "cumulative_dissipated_energy": energy["cumulative_dissipated_energy_j"],
        "residual": classification["energy_balance_residual_j"],
    }


def verify_native_energy_ledger_arm(
    arm: dict[str, Any],
    label: str,
    profile_id: str,
    tolerance_j: float,
) -> dict[str, Any]:
    """Re-derive every native component and portable energy identity in one arm."""

    residuals: list[float] = []
    component_names = ("constraint", "damper", "fluid", "adhesion")
    observed_nonzero = {name: False for name in component_names}
    for index, (native_receipt, observation, portable) in enumerate(
        zip(
            arm["native_receipts"],
            arm["observations"],
            arm["portable_step_receipts"],
            strict=True,
        )
    ):
        native = native_receipt["native_step"]
        energy = observation["energy_balance"]
        exact(native["semantic_step"], index, f"{label}_NATIVE_STEP:{index}")
        exact(
            native["energy_ledger_profile_id"], profile_id, f"{label}_PROFILE:{index}"
        )
        exact(energy["source_measurement"], True, f"{label}_SOURCE:{index}")
        components = [
            native[f"{scope}_{name}_work_j"]
            for scope in ("step", "cumulative")
            for name in component_names
        ]
        require(
            all(math.isfinite(float(value)) for value in components),
            f"{label}_FINITE_COMPONENT:{index}",
        )
        for name in component_names:
            observed_nonzero[name] |= native[f"step_{name}_work_j"] != 0.0
        for scope in ("step", "cumulative"):
            require(
                abs(
                    native[f"{scope}_dissipated_energy_j"]
                    + sum(native[f"{scope}_{name}_work_j"] for name in component_names)
                )
                <= tolerance_j,
                f"{label}_{scope.upper()}_COMPONENT_IDENTITY:{index}",
            )
        exact(
            native["cumulative_actuator_work_j"],
            energy["cumulative_applied_actuator_work_j"],
            f"{label}_ACTUATOR_IDENTITY:{index}",
        )
        exact(
            native["cumulative_dissipated_energy_j"],
            energy["cumulative_dissipated_energy_j"],
            f"{label}_DISSIPATION_IDENTITY:{index}",
        )
        exact(
            native["current_mechanical_energy_j"],
            energy["current_mechanical_energy_j"],
            f"{label}_MECHANICAL_IDENTITY:{index}",
        )
        require(
            energy["cumulative_dissipated_energy_j"] >= -tolerance_j,
            f"{label}_NEGATIVE_DISSIPATION:{index}",
        )
        recomputed = abs(
            energy["current_mechanical_energy_j"]
            - energy["initial_mechanical_energy_j"]
            - energy["cumulative_applied_actuator_work_j"]
            - energy["cumulative_external_work_j"]
            + energy["cumulative_dissipated_energy_j"]
        )
        residual = portable["classification"]["energy_balance_residual_j"]
        require(
            math.isfinite(float(recomputed))
            and abs(recomputed - residual) <= tolerance_j,
            f"{label}_RESIDUAL_IDENTITY:{index}",
        )
        residuals.append(residual)
    return {
        "residuals": residuals,
        "observed_nonzero": observed_nonzero,
    }


def verify_staged_physical_runner_closure(
    *,
    root: Path,
    closure: dict[str, Any],
    gate_id: str,
    source_commit: str,
    qualification_source_commit: str,
    physical_directory_prefix: str,
    mode: str,
    schemas: dict[str, str],
    runtime_binding_field: str,
) -> dict[str, dict[str, Any]]:
    """Verify the reusable retained shell from the staged physical launcher.

    Campaign audits own their scientific interpretation and in-run invariants.
    This helper binds the one exact attempt, complete file tree, JSON artifacts,
    source/qualification/runtime/environment identity, Cargo lock, result hash,
    lock release, and fail-closed claim surface for both ghost and development.
    """

    physical = closure["physical_attempt"]
    evidence_root = Path(physical["evidence_root"])
    verify_retained_file_tree(evidence_root, physical["retained_tree"])
    require(
        not (evidence_root / "physical_failure.json").exists(),
        "STAGED_PHYSICAL_FAILURE_FILE",
    )
    exact(
        matching_evidence_roots(
            evidence_root.parent,
            physical_directory_prefix,
            "physical_attempt.json",
            gate_id,
            source_commit,
        ),
        [evidence_root],
        "STAGED_PHYSICAL_ATTEMPT_IDENTITY",
    )

    values: dict[str, dict[str, Any]] = {}
    for key in ("attempt", "result", "receipt"):
        artifact = physical[key]
        values[key] = verify_retained_json(
            evidence_root / artifact["path"],
            artifact["byte_length"],
            artifact["raw_sha256"],
            artifact["canonical_byte_length"],
            artifact["canonical_sha256"],
        )
        exact(values[key]["schema_version"], schemas[key], f"STAGED_{key.upper()}_SCHEMA")

    attempt, result, receipt = (
        values["attempt"], values["result"], values["receipt"]
    )
    for value, prefix in ((attempt, "ATTEMPT"), (result, "RESULT"),
                          (receipt, "RECEIPT")):
        exact(value["gate_id"], gate_id, f"STAGED_{prefix}_GATE")
        if "mode" in value:
            exact(value["mode"], mode, f"STAGED_{prefix}_MODE")
        exact(value["physical_acceptance_authority"], False,
              f"STAGED_{prefix}_ACCEPTANCE")
        exact(value["release_authority"], False, f"STAGED_{prefix}_RELEASE")
    for value, prefix in ((attempt, "ATTEMPT"), (receipt, "RECEIPT")):
        exact(value["source_commit"], source_commit, f"STAGED_{prefix}_SOURCE")
        exact(value["qualification_source_commit"], qualification_source_commit,
              f"STAGED_{prefix}_QUALIFICATION_SOURCE")
        exact(value[runtime_binding_field], physical["runtime_binding_sha256"],
              f"STAGED_{prefix}_RUNTIME_BINDING")
    exact(attempt["upstream_commit"], source_commit, "STAGED_ATTEMPT_UPSTREAM")
    exact(attempt["live_remote_commit"], source_commit, "STAGED_ATTEMPT_LIVE")
    exact(attempt["worktree_clean_at_start"], True, "STAGED_ATTEMPT_CLEAN")
    exact(receipt["stage_valid"], True, "STAGED_RECEIPT_VALID")
    exact(receipt["operation_lock_released"], True, "STAGED_LOCK_RELEASED")
    exact(result[runtime_binding_field], physical["runtime_binding_sha256"],
          "STAGED_RESULT_RUNTIME_BINDING")

    exact(receipt["environment"], attempt["environment"], "STAGED_ENVIRONMENT")
    exact(receipt["environment_sha256"], attempt["environment_sha256"],
          "STAGED_ENVIRONMENT_HASH_IDENTITY")
    environment_bytes = json.dumps(
        attempt["environment"], ensure_ascii=False, separators=(",", ":")
    ).encode("utf-8")
    exact(sha256(environment_bytes), attempt["environment_sha256"],
          "STAGED_ENVIRONMENT_HASH")

    lock = physical["retained_qualification_cargo_lock"]
    lock_path = evidence_root / lock["path"]
    lock_raw = lock_path.read_bytes()
    exact((len(lock_raw), sha256(lock_raw)),
          (lock["byte_length"], lock["raw_sha256"]), "STAGED_CARGO_LOCK")
    exact(
        (
            attempt["environment"]["qualification_harness_cargo_lock_sha256"],
            receipt["qualification_harness_cargo_lock_sha256"],
        ),
        (lock["raw_sha256"], lock["raw_sha256"]),
        "STAGED_CARGO_LOCK_IDENTITY",
    )

    result_artifact = physical["result"]
    exact(
        (receipt["result_path"], receipt["result_byte_length"],
         receipt["result_raw_sha256"]),
        (result_artifact["path"], result_artifact["byte_length"],
         result_artifact["raw_sha256"]),
        "STAGED_RESULT_BINDING",
    )
    exact(receipt["actual_total_outer_steps"],
          physical["actual_total_outer_steps"], "STAGED_OUTER_STEPS")
    exact(receipt["held_out_cell_access_count"], 0, "STAGED_HELDOUT")
    exact(receipt["held_out_selector_invocation_count"], 0, "STAGED_SELECTOR")
    return values


def verify_rapier_recovery_energy_v2_arm(
    arm: dict[str, Any],
    label: str,
    *,
    expected_outer_steps: int | None = None,
) -> dict[str, Any]:
    """Verify the reusable live Rapier observation-V2 chain for one arm.

    This covers the in-run invariant, native energy sample, V1-to-V2 mapping,
    cumulative aggregation, native collector, portable consumer, and planned
    control receipts. Behavior thresholds remain observations returned to the
    campaign audit; this helper does not turn them into acceptance authority.
    """

    route_id = "sporespore_qsdk_r24d48_rapier_recovery_energy_v2_route_v1"
    energy_rule = "rapier_scalar_solver_phase_total_kinetic_exchange_v1"
    mapping_profile = "rapier_r24d47_native_components_to_recovery_energy_v2_v1"
    count = arm["outer_step_count"]
    if expected_outer_steps is not None:
        exact(count, expected_outer_steps, f"{label}_OUTER_STEPS")
    verify_exact_paths(arm, {
        "schema_version": "sporespore_qsdk_r24d48_rapier_recovery_arm_result_v1",
        "gate_id": "QSDK-R24D48",
        "route_id": route_id,
        "native_solver_step_count": count,
        "energy_exchange_sequence_count": count,
        "model_construction_count": 1,
        "world_attempt_count": 1,
        "world_build_count": 1,
        "post_initialization_intervention_count": 0,
        "physics_state_modified": True,
        "prone_to_standing_claimed": False,
        "physical_acceptance_authority": False,
        "release_authority": False,
        "trace.schema_version": "sporespore_recovery_trace_v2",
        "trace.arm_kind": arm["arm_kind"],
        "trace.declared_initial_state_sha256": arm["declared_initial_state_sha256"],
    }, f"{label}_ARM")
    receipt_fields = (
        "invariant_receipts", "energy_samples", "component_receipts",
        "mapping_receipts", "aggregation_receipts", "collector_receipts",
        "portable_step_receipts",
    )
    terminal = arm["final_phase"] in ("complete", "failed", "refused")
    expected_control_count = count - 1 if terminal else count
    exact(
        {
            **{field: len(arm[field]) for field in receipt_fields},
            "planned_control_receipts": len(arm["planned_control_receipts"]),
        },
        {
            **{field: count for field in receipt_fields},
            "planned_control_receipts": expected_control_count,
        },
        f"{label}_RECEIPT_COUNTS",
    )
    exact(len(arm["trace"]["observations"]), count, f"{label}_TRACE_COUNT")

    previous_v1_sha: str | None = None
    previous_v2_sha: str | None = None
    residuals: list[float] = []
    pose_classes: list[str] = []
    joint_limits: list[bool] = []
    no_cheat: list[bool] = []
    safety: list[bool] = []
    stable_stance: list[bool] = []
    active_control_count = 0
    runtime_bindings: list[str] = []
    for index in range(count):
        semantic_step = index + 1
        invariant = arm["invariant_receipts"][index]
        energy = arm["energy_samples"][index]
        component = arm["component_receipts"][index]
        mapping = arm["mapping_receipts"][index]
        aggregation = arm["aggregation_receipts"][index]
        collector = arm["collector_receipts"][index]
        portable = arm["portable_step_receipts"][index]
        control = (
            arm["planned_control_receipts"][index]
            if index < expected_control_count else None
        )
        trace_observation = arm["trace"]["observations"][index]

        exact(invariant["semantic_step"], semantic_step,
              f"{label}_INVARIANT_STEP:{index}")
        exact(
            (
                invariant["host_step_before"], invariant["host_step_after"],
                invariant["solver_step_before"], invariant["solver_step_after"],
                invariant["native_solver_step_count"],
                invariant["world_build_count_for_arm"],
                invariant["external_intervention_count"],
                invariant["engine_specific_policy_branch_count"],
                invariant["previous_observation_sha256"],
            ),
            (index, semantic_step, index, semantic_step, 1, 1, 0, 0,
             previous_v1_sha),
            f"{label}_INVARIANT_SEQUENCE:{index}",
        )
        require(
            all(
                isinstance(value, str)
                and value.startswith("sha256:")
                and len(value) == 71
                for value in (
                    invariant["application_sha256"],
                    invariant["observation_sha256"],
                )
            ),
            f"{label}_NATIVE_DIGESTS:{index}",
        )
        exact(
            sha256(canonical_bytes(invariant["source_trace"])),
            invariant["source_trace_sha256"],
            f"{label}_SOURCE_TRACE_HASH:{index}",
        )
        verify_exact_paths(invariant["source_trace"], {
            "schema_version": "sporespore_rapier_recovery_source_trace_v1",
            "route_id": invariant["route_id"],
            "cell_id": invariant["cell_id"],
            "arm_kind": arm["arm_kind"],
            "phase": invariant["phase"],
            "semantic_step": semantic_step,
            "previous_observation_sha256": previous_v1_sha,
            "application_sha256": invariant["application_sha256"],
            "host_step_before": index, "host_step_after": semantic_step,
            "solver_step_before": index, "solver_step_after": semantic_step,
            "native_solver_step_count": 1,
            "external_intervention_count": 0,
            "engine_specific_policy_branch_count": 0,
        }, f"{label}_SOURCE_TRACE:{index}")
        runtime_bindings.append(
            invariant["source_trace"]["runtime_qualification_sha256"]
        )
        verify_exact_paths(invariant["application"], {
            "arm_kind": arm["arm_kind"],
            "phase": invariant["phase"],
            "semantic_step": semantic_step,
            "host_step_before": index, "host_step_after": semantic_step,
            "solver_step_before": index, "solver_step_after": semantic_step,
            "external_impulse_application_count": 0,
            "engine_specific_policy_branch_count": 0,
        }, f"{label}_APPLICATION:{index}")
        exact(
            invariant["observation"]["engine_step_identity"][
                "source_trace_sha256"
            ],
            invariant["source_trace_sha256"],
            f"{label}_ENGINE_SOURCE_TRACE:{index}",
        )
        require(
            all(
                isinstance(invariant["source_trace"][field], str)
                and invariant["source_trace"][field].startswith("sha256:")
                and len(invariant["source_trace"][field]) == 71
                for field in (
                    "state_sha256", "energy_balance_sha256",
                    "contact_measurements_sha256",
                )
            ),
            f"{label}_SOURCE_MEASUREMENT_DIGESTS:{index}",
        )
        exact(
            invariant["observation"]["applied_actuation"][
                "adapter_receipt_sha256"
            ],
            invariant["application_sha256"],
            f"{label}_APPLICATION_LINK:{index}",
        )
        previous_v1_sha = invariant["observation_sha256"]
        require(
            all(
                value == 0
                for value in invariant["observation"][
                    "external_interventions"
                ].values()
            ),
            f"{label}_EXTERNAL_INTERVENTIONS:{index}",
        )

        exact(
            (energy["sequence"], energy["rule_id"],
             energy["source_measurement"], energy["residual_derived_work_used"]),
            (semantic_step, energy_rule, True, False),
            f"{label}_ENERGY_SOURCE:{index}",
        )
        require(
            all(
                math.isfinite(float(value))
                for key, value in energy.items()
                if key.endswith("_j")
            ),
            f"{label}_ENERGY_FINITE:{index}",
        )
        exact(component["energy_exchange_sample"], energy,
              f"{label}_COMPONENT_SAMPLE:{index}")
        exact(component["pre_step_route_capability"],
              component["post_step_route_capability"],
              f"{label}_ROUTE_CAPABILITY:{index}")
        verify_exact_paths(component, {
            "schema_version": (
                "sporespore_qsdk_r24d48_rapier_recovery_"
                "energy_component_receipt_v1"
            ),
            "gate_id": "QSDK-R24D48",
            "source_route_id": route_id,
            "mapping_profile_id": mapping_profile,
            "semantic_step": semantic_step,
            "previous_observation_v2_sha256": previous_v2_sha,
            "base_observation_v1_sha256": invariant["observation_sha256"],
            "source_measurement": True,
        }, f"{label}_COMPONENT:{index}")
        component_sha = mapping["source_component_receipts_sha256"]
        require(
            isinstance(component_sha, str)
            and component_sha.startswith("sha256:")
            and len(component_sha) == 71,
            f"{label}_COMPONENT_HASH:{index}",
        )

        verify_exact_paths(mapping, {
            "schema_version": (
                "sporespore_qsdk_r24d48_rapier_recovery_"
                "observation_v2_mapping_receipt_v1"
            ),
            "gate_id": "QSDK-R24D48",
            "source_route_id": route_id,
            "mapping_profile_id": mapping_profile,
            "energy_rule_id": energy_rule,
            "semantic_step": semantic_step,
            "sequence_index": semantic_step,
            "base_observation_v1_sha256": invariant["observation_sha256"],
            "source_component_receipts_sha256": component_sha,
            "threshold_applied": False,
            "physical_result": False,
        }, f"{label}_MAPPING:{index}")
        exact(
            (
                aggregation["increment_count"],
                aggregation["first_sequence_index"],
                aggregation["last_sequence_index"],
                aggregation["first_semantic_step"],
                aggregation["last_semantic_step"],
                aggregation["ordered_source_values_sha256"],
                aggregation["ledger_sha256"],
            ),
            (
                semantic_step, 1, semantic_step, 1, semantic_step,
                mapping["ordered_source_values_sha256"], mapping["ledger_sha256"],
            ),
            f"{label}_AGGREGATION_SEQUENCE:{index}",
        )
        require(
            isinstance(aggregation["ledger_sha256"], str)
            and aggregation["ledger_sha256"].startswith("sha256:")
            and len(aggregation["ledger_sha256"]) == 71,
            f"{label}_LEDGER_HASH:{index}",
        )
        verify_exact_paths(aggregation, {
            "support_status": "supported_exact", "refusal_reason": None,
            "evaluation.threshold_applied": False,
            "evaluation.physical_result": False,
            "model_construction_count": 0, "world_attempt_count": 0,
            "world_build_count": 0, "solver_step_count": 0,
            "physics_state_modified": False,
            "physical_acceptance_authority": False, "release_authority": False,
        }, f"{label}_AGGREGATION:{index}")

        observation = collector["observation"]
        observation_sha = collector["observation_sha256"]
        require(
            isinstance(observation_sha, str)
            and observation_sha.startswith("sha256:")
            and len(observation_sha) == 71,
            f"{label}_V2_OBSERVATION_HASH:{index}",
        )
        binding_sha = sha256(canonical_bytes(collector["observation_source_binding"]))
        exact(observation, trace_observation, f"{label}_TRACE_OBSERVATION:{index}")
        exact(observation["energy_balance"], aggregation["ledger"],
              f"{label}_LEDGER_OBSERVATION:{index}")
        exact(observation["energy_balance"]["source_measurement"], True,
              f"{label}_V2_ENERGY_SOURCE:{index}")
        verify_exact_paths(collector, {
            "support_status": "supported_exact", "refusal_reason": None,
            "observation_sha256": observation_sha,
            "observation_source_binding_sha256": binding_sha,
            "supplied_native_post_step_observation_validated": True,
            "native_runtime_observation_collection_executed": False,
            "engine_identity_exposed_to_controller": False,
            "model_construction_count": 0, "world_attempt_count": 0,
            "world_build_count": 0, "solver_step_count": 0,
            "physics_state_modified": False, "prone_to_standing_claimed": False,
            "physical_acceptance_authority": False, "release_authority": False,
        }, f"{label}_COLLECTOR:{index}")
        exact(
            (
                collector["observation_source_binding"]["mapping_receipt_sha256"],
                collector["observation_source_binding"][
                    "source_component_receipts_sha256"
                ],
                collector["observation_source_binding"]["ledger_sha256"],
                collector["observation_source_binding"]["mapping_profile_id"],
                collector["observation_source_binding"]["source_route_id"],
                collector["observation_source_binding"][
                    "portable_observation_sha256"
                ],
            ),
            (
                sha256(canonical_bytes(mapping)), component_sha,
                mapping["ledger_sha256"], mapping_profile, route_id,
                observation_sha,
            ),
            f"{label}_SOURCE_BINDING:{index}",
        )

        verify_exact_paths(portable, {
            "support_status": "supported_exact", "refusal_reason": None,
            "observation_sha256": observation_sha,
            "post_step_observation_only": True,
            "phase_skip_permitted": False,
            "controller_implemented": True,
            "physical_threshold_authority": True,
            "world_build_count": 0, "solver_step_count": 0,
            "physics_state_modified": False,
            "prone_to_standing_claimed": False,
            "physical_acceptance_authority": False, "release_authority": False,
        }, f"{label}_PORTABLE:{index}")
        residual = portable["classification"]["energy_balance_residual_j"]
        require(math.isfinite(float(residual)), f"{label}_RESIDUAL_FINITE:{index}")
        exact(residual, aggregation["evaluation"]["absolute_residual_j"],
              f"{label}_RESIDUAL_AGGREGATION:{index}")
        residuals.append(residual)
        pose_classes.append(portable["classification"]["pose_class"])
        joint_limits.append(portable["classification"]["joint_limits_respected"])
        no_cheat.append(portable["classification"]["no_cheat_gate"])
        safety.append(portable["classification"]["safety_gate"])
        stable_stance.append(portable["classification"]["stable_stance_gate"])

        if control is not None:
            verify_exact_paths(control, {
                "support_status": "supported_exact", "refusal_reason": None,
                "observation_sha256": observation_sha,
                "semantic_step": semantic_step,
                "controller_implemented": True, "deterministic": True,
                "engine_identity_input_count": 0,
                "engine_specific_policy_branch_count": 0,
                "fallback_controller_active": False,
                "model_construction_count": 0, "world_attempt_count": 0,
                "world_build_count": 0, "solver_step_count": 0,
                "physics_state_modified": False,
                "prone_to_standing_claimed": False,
                "physical_acceptance_authority": False,
                "release_authority": False,
            }, f"{label}_CONTROL:{index}")
            active_control_count += not control["no_actuation_requested"]
        previous_v2_sha = observation_sha

    return {
        "outer_step_count": count,
        "native_solver_step_count": arm["native_solver_step_count"],
        "declared_initial_state_sha256": arm["declared_initial_state_sha256"],
        "final_phase": arm["final_phase"],
        "terminal_failure_code": arm["terminal_failure_code"],
        "residuals_j": residuals,
        "pose_classes": pose_classes,
        "joint_limits_respected": joint_limits,
        "no_cheat_gate": no_cheat,
        "safety_gate": safety,
        "stable_stance_gate": stable_stance,
        "active_control_count": active_control_count,
        "runtime_bindings": runtime_bindings,
    }


def verify_rapier_staging_transport_v3(
    result: dict[str, Any],
    label: str,
    *,
    gate_id: str,
    expected_steps: int,
) -> dict[str, Any]:
    """Verify the reusable native-staging-to-portable-V3 transport chain."""

    route_id = "sporespore_qsdk_r24d48_rapier_recovery_energy_v2_route_v1"
    mapping_id = "rapier_r24d52_native_discrete_staging_energy_v3_mapping_v1"
    verify_exact_paths(result, {
        "schema_version": (
            "sporespore_qsdk_r24d53_rapier_staging_transport_smoke_result_v1"
        ),
        "ok": True, "gate_id": gate_id,
        "question_class": "development_integration_smoke",
        "route_id": route_id, "mapping_profile_id": mapping_id,
        "maximum_total_outer_steps": expected_steps,
        "actual_total_outer_steps": expected_steps,
        "native_staging_record_count": expected_steps,
        "portable_v3_increment_count": expected_steps,
        "in_run_invariant_receipt_count": expected_steps,
        "native_staging_transport_observed": True,
        "portable_v3_mapping_observed": True,
        "behavior_success_required": False, "official_behavior_evidence": False,
        "recovery_evaluation_executed": False,
        "result_may_satisfy_prone_to_standing": False,
        "held_out_cell_access_count": 0, "held_out_selector_invocation_count": 0,
        "model_construction_count": 1, "world_attempt_count": 1,
        "world_build_count": 1, "solver_step_count": expected_steps,
        "physics_state_modified": True, "physical_question_opened": True,
        "prone_to_standing_claimed": False,
        "physical_acceptance_authority": False, "release_authority": False,
    }, f"{label}_RESULT")
    runtime_binding = result["runtime_binding_sha256"]
    require(
        isinstance(runtime_binding, str)
        and runtime_binding.startswith("sha256:")
        and len(runtime_binding) == 71,
        f"{label}_RUNTIME_BINDING",
    )

    arm = result["transport_arm"]
    verify_exact_paths(arm, {
        "arm_kind": "candidate_command",
        "cell_id": "r24d48_rapier_development_nominal",
        "seed": 260226999,
    }, f"{label}_ARM_IDENTITY")
    arm_projection = verify_rapier_recovery_energy_v2_arm(
        arm, f"{label}_ARM", expected_outer_steps=expected_steps
    )
    exact(
        arm_projection["runtime_bindings"],
        [runtime_binding] * expected_steps,
        f"{label}_ARM_RUNTIME_BINDINGS",
    )

    records = result["native_staging_records"]
    exact(len(records), expected_steps, f"{label}_RECORD_COUNT")
    increments: list[dict[str, Any]] = []
    staging_values: list[float] = []
    for index, record in enumerate(records, 1):
        telemetry = record["native_telemetry"]
        exchange = record["staging_exchange"]
        energy = record["energy_exchange_sample"]
        increment = record["portable_v3_increment"]
        exact(
            (
                record["semantic_step"], telemetry["sequence"],
                exchange["sequence"], increment["sequence_index"],
                increment["semantic_step"], energy["sequence"],
            ),
            (index,) * 6,
            f"{label}_STEP_IDENTITY:{index}",
        )
        exact(
            (
                telemetry["small_step_count"], len(telemetry["small_steps"]),
                telemetry["overflow_small_step_count"],
                telemetry["island_solve_count"], telemetry["ccd_substep_count"],
                telemetry["endpoint_body_count_before"],
                telemetry["endpoint_body_count_after"],
            ),
            (16, 16, 0, 1, 1, 9, 9),
            f"{label}_NATIVE_TOPOLOGY:{index}",
        )
        exact(
            [step["small_step_index"] for step in telemetry["small_steps"]],
            list(range(16)),
            f"{label}_SMALL_STEP_ORDER:{index}",
        )
        require(
            telemetry["endpoint_source_measurement"] is True
            and all(step["source_measurement"] is True
                    for step in telemetry["small_steps"]),
            f"{label}_NATIVE_SOURCE:{index}",
        )
        native_values = [
            value
            for step in telemetry["small_steps"]
            for value in (
                step["kinetic_energy_before_force_j"],
                step["kinetic_energy_after_force_j"],
                step["raw_gravity_potential_before_position_j"],
                step["raw_gravity_potential_after_position_j"],
            )
        ] + [
            telemetry["endpoint_half_step_projection_before_j"],
            telemetry["endpoint_half_step_projection_after_j"],
        ]
        require(
            all(math.isfinite(float(value)) for value in native_values),
            f"{label}_NATIVE_FINITE:{index}",
        )
        force = sum(
            step["kinetic_energy_after_force_j"]
            - step["kinetic_energy_before_force_j"]
            for step in telemetry["small_steps"]
        )
        gravity = sum(
            step["raw_gravity_potential_after_position_j"]
            - step["raw_gravity_potential_before_position_j"]
            for step in telemetry["small_steps"]
        )
        endpoint = (
            telemetry["endpoint_half_step_projection_after_j"]
            - telemetry["endpoint_half_step_projection_before_j"]
        )
        for observed, retained, component in (
            (force, exchange["force_integration_kinetic_exchange_j"], "FORCE"),
            (gravity, exchange["raw_gravity_potential_position_exchange_j"],
             "GRAVITY"),
            (endpoint, exchange["endpoint_half_step_projection_exchange_j"],
             "ENDPOINT"),
            (force + gravity + endpoint,
             exchange["signed_discrete_staging_exchange_j"], "SIGNED"),
        ):
            require(
                abs(observed - retained) <= 1.0e-12,
                f"{label}_{component}_IDENTITY:{index}",
            )
        verify_exact_paths(exchange, {
            "small_step_count": 16, "source_measurement": True,
            "mechanical_energy_change_used_as_input": False,
            "energy_balance_residual_used_as_input": False,
            "acceptance_threshold_used_as_input": False,
        }, f"{label}_EXCHANGE:{index}")
        exact(
            (
                increment["applied_actuator_work_j"],
                increment["signed_external_work_j"],
                increment["signed_constraint_exchange_j"],
                increment["signed_discrete_staging_exchange_j"],
                increment["passive_dissipation_j"],
                increment["source_measurement"],
            ),
            (
                energy["motor_net_work_j"], energy["signed_external_work_j"],
                energy["signed_constraint_exchange_j"],
                exchange["signed_discrete_staging_exchange_j"],
                energy["passive_dissipation_j"], True,
            ),
            f"{label}_PORTABLE_MAPPING:{index}",
        )
        require(
            energy["source_measurement"] is True
            and energy["small_step_count"] == 16
            and all(
                math.isfinite(float(increment[key]))
                for key in (
                    "applied_actuator_work_j", "signed_external_work_j",
                    "signed_constraint_exchange_j",
                    "signed_discrete_staging_exchange_j",
                    "passive_dissipation_j",
                )
            ),
            f"{label}_PORTABLE_SOURCE:{index}",
        )
        increments.append(increment)
        staging_values.append(exchange["signed_discrete_staging_exchange_j"])

    aggregation = result["portable_v3_aggregation"]
    ledger = aggregation["ledger"]
    evaluation = aggregation["evaluation"]
    verify_exact_paths(aggregation, {
        "schema_version": "sporespore_recovery_energy_balance_aggregation_receipt_v3",
        "support_status": "supported_exact", "increment_count": expected_steps,
        "first_sequence_index": 1, "last_sequence_index": expected_steps,
        "first_semantic_step": 1, "last_semantic_step": expected_steps,
        "model_construction_count": 0, "world_attempt_count": 0,
        "world_build_count": 0, "solver_step_count": 0,
        "physics_state_modified": False,
        "physical_acceptance_authority": False, "release_authority": False,
    }, f"{label}_AGGREGATION")
    verify_exact_paths(ledger, {
        "schema_version": "sporespore_recovery_energy_balance_ledger_v3",
        "source_profile_id": mapping_id, "source_measurement": True,
    }, f"{label}_LEDGER")
    cumulative_fields = (
        ("applied_actuator_work_j", "cumulative_applied_actuator_work_j"),
        ("signed_external_work_j", "cumulative_signed_external_work_j"),
        ("signed_constraint_exchange_j", "cumulative_signed_constraint_exchange_j"),
        ("signed_discrete_staging_exchange_j",
         "cumulative_signed_discrete_staging_exchange_j"),
        ("passive_dissipation_j", "cumulative_passive_dissipation_j"),
    )
    for increment_field, ledger_field in cumulative_fields:
        require(
            abs(sum(item[increment_field] for item in increments)
                - ledger[ledger_field]) <= 1.0e-12,
            f"{label}_CUMULATIVE:{increment_field}",
        )
    first_balance = arm["trace"]["observations"][0]["energy_balance"]
    last_balance = arm["trace"]["observations"][-1]["energy_balance"]
    exact(
        (ledger["initial_mechanical_energy_j"], ledger["current_mechanical_energy_j"]),
        (first_balance["initial_mechanical_energy_j"],
         last_balance["current_mechanical_energy_j"]),
        f"{label}_MECHANICAL_ENERGY",
    )
    residual = (
        ledger["current_mechanical_energy_j"]
        - ledger["initial_mechanical_energy_j"]
        - ledger["cumulative_applied_actuator_work_j"]
        - ledger["cumulative_signed_external_work_j"]
        - ledger["cumulative_signed_constraint_exchange_j"]
        - ledger["cumulative_signed_discrete_staging_exchange_j"]
        + ledger["cumulative_passive_dissipation_j"]
    )
    require(
        abs(residual - evaluation["signed_residual_j"]) <= 1.0e-12
        and abs(abs(residual) - evaluation["absolute_residual_j"]) <= 1.0e-12,
        f"{label}_V3_RESIDUAL",
    )
    exact(
        (
            aggregation["ordered_source_values_sha256"],
            ledger["source_values_sha256"], aggregation["ledger_sha256"],
            evaluation["ledger_sha256"], evaluation["threshold_applied"],
            evaluation["physical_result"],
        ),
        (
            ledger["source_values_sha256"], ledger["source_values_sha256"],
            aggregation["ledger_sha256"], aggregation["ledger_sha256"],
            False, False,
        ),
        f"{label}_V3_DIGEST_AND_AUTHORITY",
    )
    exact(
        sha256(core_canonical_bytes(increments)),
        aggregation["ordered_source_values_sha256"],
        f"{label}_V3_SOURCE_DIGEST_REPLAY",
    )
    exact(
        sha256(core_canonical_bytes(ledger)), aggregation["ledger_sha256"],
        f"{label}_V3_LEDGER_DIGEST_REPLAY",
    )
    for digest in (
        aggregation["ordered_source_values_sha256"], aggregation["ledger_sha256"]
    ):
        require(
            isinstance(digest, str) and digest.startswith("sha256:")
            and len(digest) == 71,
            f"{label}_V3_DIGEST",
        )
    return {
        "arm": arm_projection,
        "staging_sequences": [record["native_telemetry"]["sequence"]
                              for record in records],
        "staging_exchange_j": staging_values,
        "cumulative_staging_exchange_j": (
            ledger["cumulative_signed_discrete_staging_exchange_j"]
        ),
        "v3_signed_residual_j": evaluation["signed_residual_j"],
        "v3_absolute_residual_j": evaluation["absolute_residual_j"],
        "ordered_source_values_sha256": aggregation["ordered_source_values_sha256"],
        "ledger_sha256": aggregation["ledger_sha256"],
    }


def verify_physical_attempt_closure(
    *,
    root: Path,
    closure: dict[str, Any],
    gate_id: str,
    campaign_id: str,
    source_commit: str,
    physical_directory_prefix: str,
    schemas: dict[str, str],
    qualification_receipt_raw_sha256: str,
) -> dict[str, dict[str, Any]]:
    """Verify common retained mechanics for one finite physical attempt.

    Campaign audits remain responsible for the scientific decision, physical
    invariants, exact observed values, claim boundary, and successor authority.
    This helper owns the repeated attempt identity, artifact inventory, hashes,
    schemas, lock lifecycle, source/qualification binding, counts, and
    fail-closed absence of held-out or release authority.
    """

    physical = closure["physical_attempt"]
    evidence_root = Path(physical["evidence_root"])
    artifacts = physical["retained_artifacts"]
    exact(
        len(artifacts),
        physical["retained_artifact_count"],
        "PHYSICAL_ARTIFACT_COUNT",
    )
    verify_exact_retained_inventory(evidence_root, artifacts)
    exact(
        matching_evidence_roots(
            evidence_root.parent,
            physical_directory_prefix,
            "attempt_reservation.json",
            gate_id,
            source_commit,
        ),
        [evidence_root],
        "PHYSICAL_ATTEMPT_IDENTITY",
    )

    file_names = {
        "reservation": "attempt_reservation.json",
        "manifest": "manifest.json",
        "full": "paired_full_result.json",
        "summary": "paired_summary.json",
        "completion": "supervisor_completion.json",
        "lock": "operation_lock.json",
    }
    values = {key: load(evidence_root / name) for key, name in file_names.items()}
    for key, schema in schemas.items():
        exact(values[key]["schema_version"], schema, f"PHYSICAL_{key.upper()}_SCHEMA")
    for key in ("reservation", "manifest", "full", "summary", "completion"):
        value = values[key]
        prefix = f"PHYSICAL_{key.upper()}"
        exact(value["gate_id"], gate_id, f"{prefix}_GATE")
        exact(value["campaign_id"], campaign_id, f"{prefix}_CAMPAIGN")
        exact(value["source_commit"], source_commit, f"{prefix}_SOURCE")

    reservation = values["reservation"]
    exact(reservation["question_class"], closure["question_class"], "PHYSICAL_QUESTION")
    exact(
        reservation["selected_cell_id"], physical["selected_cell_id"], "PHYSICAL_CELL"
    )
    exact(reservation["selected_seed"], physical["selected_seed"], "PHYSICAL_SEED")
    exact(
        reservation["horizon_steps_per_arm"],
        physical["horizon_steps_per_arm"],
        "PHYSICAL_HORIZON",
    )
    exact(
        reservation["paired_arm_count"], physical["paired_arm_count"], "PHYSICAL_ARMS"
    )
    exact(
        reservation["qualification_receipt_raw_sha256"],
        qualification_receipt_raw_sha256,
        "PHYSICAL_QUALIFICATION",
    )
    exact(reservation["operation_lock"]["acquired"], True, "PHYSICAL_RESERVATION_LOCK")
    exact(
        reservation["operation_lock"]["test_only"],
        False,
        "PHYSICAL_RESERVATION_LOCK_TEST",
    )
    for key in (
        "model_construction_count",
        "world_attempt_count",
        "world_build_count",
        "solver_step_count",
    ):
        exact(reservation[key], 0, f"PHYSICAL_RESERVATION_{key.upper()}")

    completion = values["completion"]
    exact(
        completion["worker_started"],
        physical["worker_started"],
        "PHYSICAL_WORKER_STARTED",
    )
    exact(
        completion["worker_exit_code"],
        physical["worker_exit_code"],
        "PHYSICAL_WORKER_EXIT",
    )
    exact(completion["route_coverage_passed"], True, "PHYSICAL_ROUTE_COVERAGE")
    exact(completion["invalid_or_incomplete_retained"], False, "PHYSICAL_COMPLETE")
    exact(
        completion["operation_lock_released"],
        physical["operation_lock_released"],
        "PHYSICAL_LOCK_RELEASED",
    )
    exact(completion["caught_error"], None, "PHYSICAL_WORKER_ERROR")
    lock = values["lock"]
    exact(lock["acquired"], True, "PHYSICAL_LOCK_ACQUIRED")
    exact(lock["role"], "physical", "PHYSICAL_LOCK_ROLE")
    exact(lock["test_only"], False, "PHYSICAL_LOCK_TEST")

    full_path = evidence_root / file_names["full"]
    summary_path = evidence_root / file_names["summary"]
    full_hash = sha256(full_path.read_bytes())
    summary_hash = sha256(summary_path.read_bytes())
    manifest = values["manifest"]
    exact(
        manifest["artifacts"],
        [
            {
                "byte_length": full_path.stat().st_size,
                "path": file_names["full"],
                "raw_sha256": full_hash,
            },
            {
                "byte_length": summary_path.stat().st_size,
                "path": file_names["summary"],
                "raw_sha256": summary_hash,
            },
        ],
        "PHYSICAL_MANIFEST_ARTIFACTS",
    )
    exact(manifest["complete_trace_retained"], True, "PHYSICAL_MANIFEST_TRACE")
    exact(manifest["compact_projection_retained"], True, "PHYSICAL_MANIFEST_SUMMARY")
    exact(
        values["summary"]["full_result_raw_sha256"],
        full_hash,
        "PHYSICAL_SUMMARY_FULL_HASH",
    )

    full = values["full"]
    exact(
        full["qualification_receipt_raw_sha256"],
        qualification_receipt_raw_sha256,
        "PHYSICAL_FULL_QUALIFICATION",
    )
    result = full["result"]
    exact(result["route_id"], physical["route_id"], "PHYSICAL_ROUTE")
    exact(
        result["model_xml_byte_length"],
        physical["model_xml_byte_length"],
        "PHYSICAL_MODEL_LENGTH",
    )
    exact(
        result["model_xml_sha256"], physical["model_xml_sha256"], "PHYSICAL_MODEL_HASH"
    )
    exact(result["initializer_identity_matched"], True, "PHYSICAL_INITIALIZER")
    for key in ("model_construction_count", "world_attempt_count", "world_build_count"):
        exact(result[key], physical[key], f"PHYSICAL_RESULT_{key.upper()}")
    exact(
        result["outer_step_count"], physical["outer_step_count"], "PHYSICAL_OUTER_STEPS"
    )
    exact(
        result["native_solver_step_count"],
        physical["native_solver_step_count"],
        "PHYSICAL_SOLVER_STEPS",
    )
    exact(result["physics_state_modified"], True, "PHYSICAL_STATE_MODIFIED")

    for value, prefix in (
        (reservation, "PHYSICAL_RESERVATION"),
        (manifest, "PHYSICAL_MANIFEST"),
        (full, "PHYSICAL_FULL"),
        (values["summary"], "PHYSICAL_SUMMARY"),
        (completion, "PHYSICAL_COMPLETION"),
    ):
        exact(value["held_out_cell_access_count"], 0, f"{prefix}_HELDOUT")
        if "held_out_selector_invocation_count" in value:
            exact(value["held_out_selector_invocation_count"], 0, f"{prefix}_SELECTOR")
        for key in (
            "prone_to_standing_claimed",
            "physical_acceptance_authority",
            "release_authority",
        ):
            exact(value[key], False, f"{prefix}_{key.upper()}")
    return values


def verify_invalid_physical_attempt_closure(
    *,
    root: Path,
    closure: dict[str, Any],
    gate_id: str,
    campaign_id: str,
    source_commit: str,
    physical_directory_prefix: str,
    schemas: dict[str, str],
    qualification_receipt_raw_sha256: str,
    absent_complete_paths: Sequence[str] = (
        "manifest.json",
        "paired_full_result.json",
        "paired_summary.json",
    ),
) -> dict[str, dict[str, Any]]:
    """Verify common retained mechanics for one invalid physical attempt.

    This is the fail-closed counterpart to ``verify_physical_attempt_closure``.
    It binds the one reserved identity, exact retained inventory, source and
    qualification, lock lifecycle, zero-count reservation, invalid publisher,
    and absence of a complete result. Campaign audits remain responsible for
    the causal diagnosis, source-order limits, scientific interpretation, and
    successor decision.
    """

    physical = closure["physical_attempt"]
    evidence_root = Path(physical["evidence_root"])
    artifacts = physical["retained_artifacts"]
    exact(
        len(artifacts),
        physical["retained_artifact_count"],
        "INVALID_ARTIFACT_COUNT",
    )
    verify_exact_retained_inventory(evidence_root, artifacts)
    exact(
        matching_evidence_roots(
            evidence_root.parent,
            physical_directory_prefix,
            "attempt_reservation.json",
            gate_id,
            source_commit,
        ),
        [evidence_root],
        "INVALID_ATTEMPT_IDENTITY",
    )

    file_names = {
        "reservation": "attempt_reservation.json",
        "invalid": "invalid_result.json",
        "completion": "supervisor_completion.json",
        "lock": "operation_lock.json",
    }
    values = {key: load(evidence_root / name) for key, name in file_names.items()}
    for key, schema in schemas.items():
        exact(values[key]["schema_version"], schema, f"INVALID_{key.upper()}_SCHEMA")
    for key in ("reservation", "invalid", "completion"):
        value = values[key]
        prefix = f"INVALID_{key.upper()}"
        exact(value["gate_id"], gate_id, f"{prefix}_GATE")
        exact(value["campaign_id"], campaign_id, f"{prefix}_CAMPAIGN")
        exact(value["source_commit"], source_commit, f"{prefix}_SOURCE")

    reservation = values["reservation"]
    exact(reservation["question_class"], closure["question_class"], "INVALID_QUESTION")
    exact(reservation["selected_cell_id"], physical["selected_cell_id"], "INVALID_CELL")
    exact(reservation["selected_seed"], physical["selected_seed"], "INVALID_SEED")
    exact(
        reservation["horizon_steps_per_arm"],
        physical["horizon_steps_per_arm"],
        "INVALID_HORIZON",
    )
    exact(reservation["paired_arm_count"], physical["paired_arm_count"], "INVALID_ARMS")
    exact(
        reservation["qualification_receipt_raw_sha256"],
        qualification_receipt_raw_sha256,
        "INVALID_QUALIFICATION",
    )
    exact(reservation["operation_lock_held"], True, "INVALID_RESERVATION_LOCK_HELD")
    exact(reservation["operation_lock"]["acquired"], True, "INVALID_RESERVATION_LOCK")
    exact(
        reservation["operation_lock"]["test_only"],
        False,
        "INVALID_RESERVATION_LOCK_TEST",
    )
    for key in (
        "model_construction_count",
        "world_attempt_count",
        "world_build_count",
        "solver_step_count",
    ):
        exact(reservation[key], 0, f"INVALID_RESERVATION_{key.upper()}")

    invalid = values["invalid"]
    exact(invalid["error_type"], physical["error_type"], "INVALID_ERROR_TYPE")
    exact(invalid["error"], physical["error"], "INVALID_ERROR")
    exact(invalid["invalid_or_incomplete_retained"], True, "INVALID_RETAINED")
    exact(invalid["valid_behavior_result_observed"], False, "INVALID_BEHAVIOR")

    completion = values["completion"]
    exact(
        completion["worker_started"],
        physical["worker_started"],
        "INVALID_WORKER_STARTED",
    )
    exact(
        completion["worker_exit_code"],
        physical["worker_exit_code"],
        "INVALID_WORKER_EXIT",
    )
    exact(completion["route_coverage_passed"], False, "INVALID_ROUTE_COVERAGE")
    exact(completion["invalid_or_incomplete_retained"], True, "INVALID_COMPLETION")
    exact(
        completion["operation_lock_released"],
        physical["operation_lock_released"],
        "INVALID_LOCK_RELEASED",
    )
    exact(completion["caught_error"], None, "INVALID_SUPERVISOR_ERROR")

    lock = values["lock"]
    exact(lock["acquired"], True, "INVALID_LOCK_ACQUIRED")
    exact(lock["role"], "physical", "INVALID_LOCK_ROLE")
    exact(lock["test_only"], False, "INVALID_LOCK_TEST")
    for relative in absent_complete_paths:
        require(
            not (evidence_root / relative).exists(),
            f"INVALID_UNEXPECTED_COMPLETE_RESULT:{relative}",
        )

    for value, prefix in (
        (reservation, "INVALID_RESERVATION"),
        (invalid, "INVALID_RESULT"),
        (completion, "INVALID_COMPLETION"),
    ):
        exact(value["held_out_cell_access_count"], 0, f"{prefix}_HELDOUT")
        if "held_out_selector_invocation_count" in value:
            exact(value["held_out_selector_invocation_count"], 0, f"{prefix}_SELECTOR")
        for key in (
            "prone_to_standing_claimed",
            "physical_acceptance_authority",
            "release_authority",
        ):
            exact(value[key], False, f"{prefix}_{key.upper()}")
    return values


def verify_patched_rapier_runner_attempt(
    *, root: Path, closure: dict[str, Any]
) -> tuple[dict[str, Any], dict[str, Any], dict[str, Any]]:
    """Verify the reusable retained mechanics of the patched Rapier launcher.

    Successor audits remain responsible for physical invariants, evaluator
    semantics, exact observed values, and claim limits. This helper owns the
    common one-attempt identity, complete file population, qualification and
    runtime binding, environment, step counts, lock release, held-out seal, and
    absence of acceptance or release authority.
    """

    gate_id = str(closure["gate_id"])
    source_commit = str(closure["source"]["commit"])
    qualification = closure["qualification"]
    physical = closure["physical_attempt"]
    evidence_root = Path(physical["evidence_root"])
    artifacts = physical["retained_artifacts"]
    exact(len(artifacts), physical["retained_artifact_count"], "RAPIER_ARTIFACT_COUNT")
    exact(
        len({str(item["path"]) for item in artifacts}),
        len(artifacts),
        "RAPIER_ARTIFACT_UNIQUE",
    )
    verify_exact_retained_inventory(evidence_root, artifacts)
    exact(
        matching_evidence_roots(
            evidence_root.parent,
            str(physical["directory_prefix"]),
            "physical_attempt.json",
            gate_id,
            source_commit,
        ),
        [evidence_root],
        "RAPIER_ATTEMPT_IDENTITY",
    )

    attempt_path = evidence_root / "physical_attempt.json"
    receipt_path = evidence_root / "physical_receipt.json"
    result_path = evidence_root / "physical_result.json"
    attempt = load(attempt_path)
    receipt = load(receipt_path)
    result = load(result_path)
    exact(attempt["schema_version"], physical["attempt_schema"], "RAPIER_ATTEMPT_SCHEMA")
    exact(receipt["schema_version"], physical["receipt_schema"], "RAPIER_RECEIPT_SCHEMA")
    exact(result["schema_version"], physical["result_schema"], "RAPIER_RESULT_SCHEMA")

    for value, prefix in (
        (attempt, "RAPIER_ATTEMPT"),
        (receipt, "RAPIER_RECEIPT"),
    ):
        exact(value["gate_id"], gate_id, f"{prefix}_GATE")
        exact(value["source_commit"], source_commit, f"{prefix}_SOURCE")
        exact(value["physical_acceptance_authority"], False, f"{prefix}_ACCEPTANCE")
        exact(value["release_authority"], False, f"{prefix}_RELEASE")

    exact(result["gate_id"], gate_id, "RAPIER_RESULT_GATE")
    exact(result["physical_acceptance_authority"], False, "RAPIER_RESULT_ACCEPTANCE")
    exact(result["release_authority"], False, "RAPIER_RESULT_RELEASE")

    exact(
        (
            attempt["mode"],
            attempt["qualification_source_commit"],
            attempt["branch"],
            attempt["remote"],
            attempt["upstream_commit"],
            attempt["live_remote_commit"],
            attempt["worktree_clean_at_start"],
            attempt["runtime_binding_sha256"],
        ),
        (
            "development",
            qualification["source_commit"],
            "main",
            "https://github.com/Slagathore/sporespore.git",
            source_commit,
            source_commit,
            True,
            qualification["runtime_binding_sha256"],
        ),
        "RAPIER_ATTEMPT_AUTHORITY",
    )
    exact(
        attempt["environment"],
        physical["environment"],
        "RAPIER_ATTEMPT_ENVIRONMENT",
    )
    exact(
        attempt["environment_sha256"],
        physical["environment_sha256"],
        "RAPIER_ATTEMPT_ENVIRONMENT_SHA",
    )

    exact(
        (
            receipt["mode"],
            receipt["stage_valid"],
            receipt["qualification_source_commit"],
            receipt["runtime_binding_sha256"],
            receipt["environment"],
            receipt["environment_sha256"],
            receipt["qualification_harness_cargo_lock_sha256"],
            receipt["result_path"],
            receipt["result_byte_length"],
            receipt["result_raw_sha256"],
            receipt["operation_lock_released"],
        ),
        (
            "development",
            True,
            qualification["source_commit"],
            qualification["runtime_binding_sha256"],
            physical["environment"],
            physical["environment_sha256"],
            qualification["cargo_lock_raw_sha256"],
            "physical_result.json",
            result_path.stat().st_size,
            sha256(result_path.read_bytes()),
            True,
        ),
        "RAPIER_RECEIPT_AUTHORITY",
    )
    exact(
        (
            receipt["actual_total_outer_steps"],
            receipt["candidate_outer_steps"],
            receipt["matched_zero_outer_steps"],
            result["actual_total_outer_steps"],
            result["candidate_outer_steps"],
            result["matched_zero_outer_steps"],
        ),
        (
            physical["actual_total_outer_steps"],
            physical["candidate_outer_steps"],
            physical["matched_zero_outer_steps"],
            physical["actual_total_outer_steps"],
            physical["candidate_outer_steps"],
            physical["matched_zero_outer_steps"],
        ),
        "RAPIER_STEP_COUNTS",
    )
    exact(result["ok"], True, "RAPIER_RESULT_OK")
    exact(
        result["runtime_binding_sha256"],
        qualification["runtime_binding_sha256"],
        "RAPIER_RESULT_RUNTIME",
    )
    exact(result["held_out_cell_access_count"], 0, "RAPIER_RESULT_HELDOUT")
    exact(result["held_out_selector_invocation_count"], 0, "RAPIER_RESULT_SELECTOR")
    exact(receipt["held_out_cell_access_count"], 0, "RAPIER_RECEIPT_HELDOUT")
    exact(receipt["held_out_selector_invocation_count"], 0, "RAPIER_RECEIPT_SELECTOR")

    qualification_closure_path = root / qualification["closure_path"]
    qualification_closure = load(qualification_closure_path)
    exact(
        (
            sha256(qualification_closure_path.read_bytes()),
            qualification_closure["source"]["commit"],
            qualification_closure["qualification"]["runtime_binding_sha256"],
            qualification_closure["qualification"]["isolated_harness_cargo_lock"]["raw_sha256"],
        ),
        (
            qualification["closure_raw_sha256"],
            qualification["source_commit"],
            qualification["runtime_binding_sha256"],
            qualification["cargo_lock_raw_sha256"],
        ),
        "RAPIER_QUALIFICATION",
    )
    return attempt, receipt, result


def verify_rapier_recovery_v3_arm_capture(
    *,
    projection: dict[str, Any],
    expected_arm_kind: str,
    captured_observation_count: int,
    terminal_prefix_observation_count: int,
) -> dict[str, Any]:
    """Verify reusable native V3 capture, invariant, and staging mechanics."""

    capture = projection["complete_capture"]
    exact(
        (
            projection["captured_observation_count"],
            projection["evaluator_observation_count"],
            projection["post_terminal_tail_observation_count"],
            projection["captured_trace_v3_sha256"],
            projection["complete_capture_retained"],
            projection["evaluator_input_is_exact_terminal_prefix"],
            projection["projection_world_build_count"],
            projection["projection_solver_step_count"],
            projection["projection_physics_state_modified"],
        ),
        (
            captured_observation_count,
            terminal_prefix_observation_count,
            captured_observation_count - terminal_prefix_observation_count,
            capture["trace_v3_sha256"],
            True,
            True,
            0,
            0,
            False,
        ),
        "RAPIER_ARM_PROJECTION",
    )
    exact(capture["arm_kind"], expected_arm_kind, "RAPIER_ARM_KIND")
    exact(
        capture["trace_v3"]["arm_kind"],
        expected_arm_kind,
        "RAPIER_TRACE_ARM_KIND",
    )
    exact(
        (
            capture["captured_observation_count"],
            len(capture["trace_v3"]["observations"]),
            capture["in_run_invariant_receipt_count"],
            len(capture["in_run_invariant_receipts"]),
            capture["staging_record_count"],
            len(capture["compact_staging_records"]),
            capture["v3_increment_count"],
            len(capture["ordered_v3_increments"]),
            len(capture["v3_prefix_aggregation_receipts"]),
            capture["terminal_prefix_observation_count"],
            len(capture["v2_v3_phase_prefix_receipts"]),
            capture["native_solver_step_count"],
        ),
        (
            captured_observation_count,
            captured_observation_count,
            captured_observation_count,
            captured_observation_count,
            captured_observation_count,
            captured_observation_count,
            captured_observation_count,
            captured_observation_count,
            captured_observation_count,
            terminal_prefix_observation_count,
            terminal_prefix_observation_count,
            captured_observation_count,
        ),
        "RAPIER_ARM_COUNTS",
    )

    for index, receipt in enumerate(capture["in_run_invariant_receipts"], start=1):
        exact(receipt["semantic_step"], index, "RAPIER_INVARIANT_SEQUENCE")
        require(
            receipt["engine_specific_policy_branch_count"] == 0
            and receipt["external_intervention_count"] == 0
            and receipt["native_solver_step_count"] == 1
            and not receipt["physical_acceptance_authority"]
            and not receipt["release_authority"]
            and not receipt["prone_to_standing_claimed"],
            "RAPIER_INVARIANT_BOUNDARY",
        )
        application = receipt["application"]
        require(
            application["engine_specific_policy_branch_count"] == 0
            and application["external_impulse_application_count"] == 0
            and all(
                value["readback_matches"]
                for value in application["ordered_pre_step_readbacks"]
            )
            and all(
                value["impulse_within_cap"]
                for value in application["ordered_post_step_readbacks"]
            ),
            "RAPIER_NATIVE_APPLICATION_INVARIANT",
        )
        exact(
            sum(receipt["observation"]["external_interventions"].values()),
            0,
            "RAPIER_INTERVENTION_TOTAL",
        )

    for index, record in enumerate(capture["compact_staging_records"], start=1):
        require(
            record["semantic_step"] == index
            and record["energy_sequence"] == index
            and record["staging_sequence"] == index
            and record["source_measurement"]
            and record["endpoint_source_measurement"]
            and record["overflow_small_step_count"] == 0
            and record["island_solve_count"] == 1
            and record["ccd_substep_count"] == 1,
            "RAPIER_STAGING_RECORD",
        )

    for index, receipt in enumerate(
        capture["v3_prefix_aggregation_receipts"], start=1
    ):
        require(
            receipt["semantic_step"] == index
            and receipt["increment_count"] == index
            and not receipt["threshold_applied"]
            and not receipt["physical_result"],
            "RAPIER_AGGREGATION_RECEIPT",
        )

    for index, receipt in enumerate(
        capture["v2_v3_phase_prefix_receipts"], start=1
    ):
        require(
            receipt["semantic_step"] == index
            and receipt["pre_terminal_phase_identity"],
            "RAPIER_PHASE_PREFIX_RECEIPT",
        )
    return capture


def verify_zero_world_qualification_closure(
    *,
    root: Path,
    closure: dict[str, Any],
    gate_id: str,
    source_commit: str,
    attempt_schema: str,
    receipt_schema: str,
    qualification_directory_prefix: str,
    contract_inventory: Sequence[str],
    expected_checks: Sequence[str] = (
        "core_dynamic_library_rebuilt",
        "core_recovery_tests_passed",
        "mujoco_adapter_zero_world_tests_passed",
        "source_contract_audit_passed",
        "production_preflight_passed",
        "worktree_unchanged",
    ),
    source_manifest_raw_representation: str = "git_blob",
    preflight_zero_count_keys: Sequence[str] = (
        "model_construction_count",
        "world_attempt_count",
        "world_build_count",
        "solver_step_count",
    ),
) -> tuple[dict[str, Any], dict[str, Any], dict[str, Any]]:
    """Verify common retained mechanics for a zero-world qualification closure.

    Campaign audits remain responsible only for their semantic controls,
    decision, claim boundary, and successor authority. This helper owns the
    repeated commit, evidence, manifest, lock, toolchain, and zero-physics
    checks so successors do not grow another bespoke closure verifier.
    """

    qualification = closure["qualification"]
    evidence_root = Path(qualification["evidence_root"])
    if "retained_tree" in qualification:
        require("retained_artifacts" not in qualification, "RETAINED_EVIDENCE_MODE")
        verify_retained_file_tree(evidence_root, qualification["retained_tree"])
    else:
        artifacts = qualification["retained_artifacts"]
        exact(
            len(artifacts),
            qualification["retained_artifact_count"],
            "ARTIFACT_COUNT",
        )
        exact(
            len({str(item["path"]) for item in artifacts}),
            len(artifacts),
            "ARTIFACT_UNIQUE",
        )
        verify_retained_file_manifest(evidence_root, artifacts)
    require(
        not (evidence_root / "qualification_failure.json").exists(),
        "FAILURE_FILE",
    )

    attempt = verify_retained_json(
        evidence_root / qualification["attempt_path"],
        qualification["attempt_byte_length"],
        qualification["attempt_raw_sha256"],
        qualification["attempt_canonical_byte_length"],
        qualification["attempt_canonical_sha256"],
    )
    receipt = verify_retained_json(
        evidence_root / qualification["receipt_path"],
        qualification["receipt_byte_length"],
        qualification["receipt_raw_sha256"],
        qualification["receipt_canonical_byte_length"],
        qualification["receipt_canonical_sha256"],
    )

    matching_attempts: list[Path] = []
    for directory in evidence_root.parent.glob(f"{qualification_directory_prefix}*"):
        candidate = directory / "qualification_attempt.json"
        if candidate.is_file():
            value = load(candidate)
            if (
                value.get("gate_id") == gate_id
                and value.get("source_commit") == source_commit
            ):
                matching_attempts.append(directory)
    exact(
        len(matching_attempts),
        qualification["official_qualification_attempt_count_for_source"],
        "ATTEMPT_COUNT",
    )
    exact(matching_attempts, [evidence_root], "ATTEMPT_IDENTITY")

    exact(attempt["schema_version"], attempt_schema, "ATTEMPT_SCHEMA")
    exact(receipt["schema_version"], receipt_schema, "RECEIPT_SCHEMA")
    for value, prefix in ((attempt, "ATTEMPT"), (receipt, "RECEIPT")):
        exact(value["gate_id"], gate_id, f"{prefix}_GATE")
        exact(value["mode"], "qualification", f"{prefix}_MODE")
        exact(value["source_commit"], source_commit, f"{prefix}_SOURCE")
        exact(value["upstream_commit"], source_commit, f"{prefix}_UPSTREAM")
        exact(value["live_remote_commit"], source_commit, f"{prefix}_LIVE")
    exact(attempt["worktree_clean_at_start"], True, "ATTEMPT_CLEAN")
    exact(attempt["operation_lock"]["acquired"], True, "ATTEMPT_LOCK")
    exact(attempt["operation_lock"]["test_only"], False, "ATTEMPT_LOCK_TEST")
    exact(receipt["ok"], True, "RECEIPT_OK")
    exact(
        receipt["checks"],
        {key: True for key in expected_checks},
        "RECEIPT_CHECKS",
    )
    exact(receipt["toolchain"], qualification["toolchain"], "TOOLCHAIN")
    exact(receipt["operation_lock_released"], True, "LOCK_RELEASED")

    manifest = receipt["source_manifest"]
    exact(
        len(manifest),
        qualification["source_manifest_entry_count"],
        "SOURCE_COUNT",
    )
    exact(
        [item["path"] for item in manifest],
        list(contract_inventory),
        "SOURCE_ORDER",
    )
    encoded_manifest = canonical_bytes(manifest)
    exact(
        len(encoded_manifest),
        qualification["source_manifest_canonical_byte_length"],
        "SOURCE_LENGTH",
    )
    exact(
        sha256(encoded_manifest),
        qualification["source_manifest_canonical_sha256"],
        "SOURCE_HASH",
    )
    verify_source_receipt_manifest(
        root,
        source_commit,
        manifest,
        source_manifest_raw_representation,
    )

    preflight = receipt["production_preflight"]
    encoded_preflight = canonical_bytes(preflight)
    exact(
        len(encoded_preflight),
        qualification["production_preflight_canonical_byte_length"],
        "PREFLIGHT_LENGTH",
    )
    exact(
        sha256(encoded_preflight),
        qualification["production_preflight_canonical_sha256"],
        "PREFLIGHT_HASH",
    )
    exact(preflight["gate_id"], gate_id, "PREFLIGHT_GATE")

    all_zero_count_keys = (
        "model_construction_count",
        "world_attempt_count",
        "world_build_count",
        "solver_step_count",
    )
    require(
        set(preflight_zero_count_keys).issubset(all_zero_count_keys),
        "PREFLIGHT_ZERO_COUNT_KEYS",
    )
    for value, prefix, keys in (
        (attempt, "ATTEMPT", all_zero_count_keys),
        (receipt, "RECEIPT", all_zero_count_keys),
        (preflight, "PREFLIGHT", preflight_zero_count_keys),
        (qualification, "QUALIFICATION", all_zero_count_keys),
    ):
        for key in keys:
            exact(value[key], 0, f"{prefix}_{key.upper()}")
    for key in (
        "physics_state_modified",
        "physical_question_opened",
        "controller_physical_viability_proven",
        "prone_to_standing_claimed",
        "physical_acceptance_authority",
        "release_authority",
    ):
        if key in receipt:
            exact(receipt[key], False, f"RECEIPT_{key.upper()}")
    exact(receipt["held_out_cell_access_count"], 0, "HELDOUT_ACCESS")
    exact(receipt["held_out_selector_invocation_count"], 0, "HELDOUT_SELECTOR")
    return attempt, receipt, preflight


def verify_declared_zero_world_qualification_authority(
    *,
    root: Path,
    closure_path: Path,
    schema_version: str,
    gate_id: str,
    closure_status: str,
    source_commit: str,
    source_subject: str,
    source_binding_names: Sequence[str],
    predecessor_status: str,
    attempt_schema: str,
    receipt_schema: str,
    qualification_directory_prefix: str,
    expected_checks: Sequence[str],
    checkout_only_metadata: Sequence[dict[str, Any]],
    retained_log_markers: dict[str, str],
    physical_question_declared: bool = False,
    preflight_zero_count_keys: Sequence[str] = (
        "model_construction_count",
        "world_attempt_count",
        "world_build_count",
        "solver_step_count",
    ),
) -> tuple[dict[str, Any], dict[str, Any], dict[str, Any], dict[str, Any]]:
    """Verify the reusable authority shell around a zero-world closure.

    Successor-specific audits supply only immutable identities and their small
    semantic decision. This helper owns the repeated closure declaration,
    frozen source bindings, predecessor preservation, qualification mechanics,
    Windows checkout representation accounting, and retained log markers.
    """

    closure = load(closure_path)
    exact(
        (
            closure["schema_version"],
            closure["gate_id"],
            closure["closure_status"],
            closure["question_class"],
        ),
        (schema_version, gate_id, closure_status, "development"),
        "CLOSURE_IDENTITY",
    )
    exact(
        closure["physical_question_declared"],
        physical_question_declared,
        "DECLARATION_PHYSICAL_QUESTION_DECLARED",
    )
    exact_bools(
        closure,
        (
            "superiority_question_declared",
            "equivalence_or_non_inferiority_question_declared",
            "population_inference_declared",
        ),
        False,
        "DECLARATION",
    )

    source = closure["source"]
    verify_retained_commit(root, source_commit, source["parent_commit"])
    exact(
        (source["commit"], source["tree"], source["subject"]),
        (
            source_commit,
            git(root, "show", "-s", "--format=%T", source_commit),
            source_subject,
        ),
        "SOURCE_IDENTITY",
    )
    for binding_name in source_binding_names:
        verify_source_binding(root, source_commit, source[binding_name])
    contract = loads(verify_source_binding(root, source_commit, source["contract"]))

    predecessor = closure["predecessor"]
    predecessor_path = root / predecessor["closure_path"]
    predecessor_closure = load(predecessor_path)
    predecessor_observed_status = predecessor_closure.get(
        "closure_status", predecessor_closure.get("status")
    )
    require(predecessor_observed_status is not None, "PREDECESSOR_STATUS_KEY")
    exact(
        (sha256(predecessor_path.read_bytes()), predecessor_observed_status),
        (predecessor["closure_raw_sha256"], predecessor_status),
        "PREDECESSOR",
    )
    exact(predecessor["historical_result"], predecessor_status, "PREDECESSOR_STATUS")
    exact_bools(
        predecessor,
        (
            "historical_result_rewritten",
            "historical_threshold_rewritten",
            "historical_evaluator_rewritten",
            "historical_interpretation_rewritten",
            "same_identity_rerun_permitted",
            "same_identity_requalification_permitted",
        ),
        False,
        "PREDECESSOR",
    )

    qualification = closure["qualification"]
    _attempt, receipt, preflight = verify_zero_world_qualification_closure(
        root=root,
        closure=closure,
        gate_id=gate_id,
        source_commit=source_commit,
        attempt_schema=attempt_schema,
        receipt_schema=receipt_schema,
        qualification_directory_prefix=qualification_directory_prefix,
        contract_inventory=contract["source_inventory"],
        expected_checks=expected_checks,
        source_manifest_raw_representation=qualification[
            "source_manifest_raw_representation"
        ],
        preflight_zero_count_keys=preflight_zero_count_keys,
    )
    evidence_root = Path(qualification["evidence_root"])
    if "retained_tree" not in qualification:
        verify_exact_retained_inventory(
            evidence_root, qualification["retained_artifacts"]
        )
    exact(receipt["contract_path"], source["contract"]["path"], "RECEIPT_CONTRACT")
    exact(
        receipt["contract_raw_sha256"],
        source["contract"]["raw_sha256"],
        "RECEIPT_CONTRACT_HASH",
    )

    metadata_by_path = {
        str(item["path"]): {key: value for key, value in item.items() if key != "path"}
        for item in checkout_only_metadata
    }
    exact(
        len(metadata_by_path),
        len(checkout_only_metadata),
        "SOURCE_REPRESENTATION_METADATA_DUPLICATE",
    )
    checkout_only_entries = []
    for entry in receipt["source_manifest"]:
        raw = source_bytes(root, source_commit, entry["path"])
        if len(raw) == entry["byte_length"] and sha256(raw) == entry["raw_sha256"]:
            continue
        relative = str(entry["path"])
        require(
            relative in metadata_by_path, f"SOURCE_REPRESENTATION_UNDECLARED:{relative}"
        )
        checkout_only_entries.append(
            {
                "path": relative,
                "observed_checkout_byte_length": entry["byte_length"],
                "observed_checkout_raw_sha256": entry["raw_sha256"],
                "canonical_git_blob_byte_length": len(raw),
                "canonical_git_blob_raw_sha256": sha256(raw),
                **metadata_by_path.pop(relative),
            }
        )
    exact(metadata_by_path, {}, "SOURCE_REPRESENTATION_UNOBSERVED")
    exact(
        qualification["source_manifest_representation_evidence"],
        {
            "git_blob_oid_match_count": len(receipt["source_manifest"]),
            "git_blob_raw_byte_match_count": len(receipt["source_manifest"])
            - len(checkout_only_entries),
            "checkout_only_entry_count": len(checkout_only_entries),
            "checkout_only_entries": checkout_only_entries,
        },
        "SOURCE_REPRESENTATION",
    )
    require(
        all(
            marker in (evidence_root / relative).read_text(encoding="utf-8")
            for relative, marker in retained_log_markers.items()
        ),
        "RETAINED_LOG_MARKERS",
    )
    return closure, contract, receipt, preflight


def verify_published_closure_authorization_control(
    *,
    root: Path,
    closure_path: Path,
    schema_version: str,
    gate_id: str,
    closure_status: str,
    control_commit: str,
    control_subject: str,
    predecessor_status: str,
    receipt_schema: str,
    preflight_schema: str,
    projection_omitted_fields: Sequence[str] = (),
) -> tuple[dict[str, Any], dict[str, Any], dict[str, Any]]:
    """Verify shared mechanics for a post-publication authorization control.

    The caller remains responsible for the campaign-specific decision, claim
    boundary, finite physical payload, and live-authority projection. This
    helper owns the repeated immutable commit, predecessor, retained receipt,
    repository identity, authorization binding, lock, and zero-physics checks.
    """

    closure = load(closure_path)
    exact(
        (
            closure["schema_version"],
            closure["gate_id"],
            closure["closure_status"],
            closure["question_class"],
            closure["physical_question_declared"],
        ),
        (schema_version, gate_id, closure_status, "development", False),
        "CLOSURE_IDENTITY",
    )
    verify_boolean_partition(
        closure,
        (),
        (
            "physical_question_declared",
            "superiority_question_declared",
            "equivalence_or_non_inferiority_question_declared",
            "population_inference_declared",
        ),
        "QUESTION_DECLARATION",
    )

    source = closure["source"]
    verify_retained_commit(root, control_commit, source["parent_commit"])
    exact(
        (
            source["control_commit"],
            source["tree"],
            source["subject"],
            source["repository_root"],
            source["remote"],
            source["branch"],
            source["worktree_count"],
            source["clean_pushed_live_equal"],
            source["qualified_physical_path_drift_from_source_freeze"],
        ),
        (
            control_commit,
            git(root, "show", "-s", "--format=%T", control_commit),
            control_subject,
            root.as_posix(),
            "https://github.com/Slagathore/sporespore.git",
            "main",
            1,
            True,
            False,
        ),
        "SOURCE",
    )

    predecessor = closure["predecessor"]
    predecessor_path = root / predecessor["closure_path"]
    predecessor_value = load(predecessor_path)
    exact(
        (
            sha256(predecessor_path.read_bytes()),
            predecessor_path.stat().st_size,
            predecessor_value["closure_status"],
        ),
        (
            predecessor["closure_raw_sha256"],
            predecessor["closure_byte_length"],
            predecessor_status,
        ),
        "PREDECESSOR",
    )
    exact(predecessor["closure_status"], predecessor_status, "PREDECESSOR_STATUS")
    verify_boolean_partition(
        predecessor,
        (),
        (
            "historical_result_rewritten",
            "historical_threshold_rewritten",
            "historical_evaluator_rewritten",
            "historical_interpretation_rewritten",
            "same_identity_requalification_permitted",
        ),
        "PREDECESSOR_FLAGS",
    )

    control = closure["authorization_control"]
    evidence_root = Path(control["evidence_root"])
    exact(retained_file_tree_projection(evidence_root), control["retained_tree"], "TREE")
    receipt = verify_retained_json(
        evidence_root / control["receipt_path"],
        control["receipt_byte_length"],
        control["receipt_raw_sha256"],
        control["receipt_canonical_byte_length"],
        control["receipt_canonical_sha256"],
    )
    exact(
        sorted(p.name for p in evidence_root.iterdir() if p.is_file()),
        [control["receipt_path"]],
        "COMPLETE_FILE_POPULATION",
    )
    verify_exact_paths(
        receipt,
        {
            "schema_version": receipt_schema,
            "gate_id": gate_id,
            "question_class": "development",
            "ok": True,
            "status": "published_closure_authorization_control_passed",
            "control_id": control["control_id"],
            "source.control_commit": control_commit,
            "source.repository.root": root.as_posix(),
            "source.repository.remote": "https://github.com/Slagathore/sporespore.git",
            "source.repository.branch": "main",
            "source.repository.head": control_commit,
            "source.repository.upstream": control_commit,
            "source.repository.cached_origin_main": control_commit,
            "source.repository.live_origin_main": control_commit,
            "source.repository.worktree_count": 1,
            "source.repository.worktree_clean": True,
            "authorization.path": control["authorization_closure_absolute_path"],
            "authorization.raw_sha256": control["authorization_closure_raw_sha256"],
            "authorization.byte_length": control["authorization_closure_byte_length"],
            "authorization.source_freeze_commit": control[
                "authorization_source_freeze_commit"
            ],
            "preflight.schema_version": preflight_schema,
            "preflight.gate_id": gate_id,
            "preflight.ok": True,
            "preflight.source_audit_and_runtime_preflight_count": 1,
            "preflight.worker_parse_count": 1,
            "operation_lock.acquired": True,
            "operation_lock.released": True,
            "operation_lock.role": "conformance",
            "operation_lock.test_only": False,
            "operation_lock.abandoned_owner_recovered": False,
            "model_construction_count": 0,
            "world_attempt_count": 0,
            "world_build_count": 0,
            "solver_step_count": 0,
            "physical_execution_count": 0,
            "physics_state_modified": False,
            "next_physical_invocation_authorized": True,
            "held_out": False,
            "same_identity_rerun_permitted": False,
            "prone_to_standing_claimed": False,
            "physical_acceptance_authority": False,
            "release_authority": False,
        },
        "RECEIPT",
    )
    source_projection = predecessor_value["physical_authorization"]
    omitted = tuple(projection_omitted_fields)
    exact(len(omitted), len(set(omitted)), "PROJECTION_OMISSION_DUPLICATE")
    require(
        all(key in source_projection for key in omitted),
        "PROJECTION_OMISSION_SOURCE_KEY",
    )
    normalized_projection = {
        key: value
        for key, value in source_projection.items()
        if key not in omitted
    }
    exact(
        receipt["authorization"]["projection"],
        normalized_projection,
        "PROJECTION_BINDING",
    )
    exact(
        (
            len(canonical_bytes(receipt["authorization"]["projection"])),
            sha256(canonical_bytes(receipt["authorization"]["projection"])),
            len(canonical_bytes(receipt["preflight"])),
            sha256(canonical_bytes(receipt["preflight"])),
        ),
        (
            control["projection_canonical_byte_length"],
            control["projection_canonical_sha256"],
            control["preflight_canonical_byte_length"],
            control["preflight_canonical_sha256"],
        ),
        "CANONICAL_COMPONENTS",
    )
    exact(
        (
            control["command_invocation_count"],
            control["receipt_count"],
            control["schema_version"],
            control["status"],
            control["completed_utc"],
            control["operation_lock_acquired"],
            control["operation_lock_released"],
            control["model_construction_count"],
            control["world_attempt_count"],
            control["world_build_count"],
            control["solver_step_count"],
            control["physical_execution_count"],
            control["physics_state_modified"],
            control["held_out"],
            control["same_exact_control_rerun_permitted"],
        ),
        (
            1,
            1,
            receipt_schema,
            "published_closure_authorization_control_passed",
            receipt["completed_utc"],
            True,
            True,
            0,
            0,
            0,
            0,
            0,
            False,
            False,
            False,
        ),
        "CONTROL_SUMMARY",
    )
    return closure, predecessor_value, receipt
