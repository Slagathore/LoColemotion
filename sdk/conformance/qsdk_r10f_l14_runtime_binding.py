"""Source-only exact runtime image binding for the prospective L14 route.

The console launcher is not the physics engine. Both images, the adapter, and
the two host interpreters must be the selected bytes. Reading these files does
not run Godot, construct a model, sample native physics, or authorize a world.
"""

from __future__ import annotations

import argparse
import copy
import hashlib
import json
from pathlib import Path
import re
import shutil
import sys
from typing import Any

import qsdk_r10f_l14_authority_contract as authority

ROOT = Path(__file__).resolve().parents[2]
MARKER = "QSDK_R10F_L14_EXACT_RUNTIME_BINDING_PASS "
SCHEMA = "sporespore_qsdk_r10f_l14_exact_runtime_image_binding_v1"
FOUNDATION = {
    "path": "sdk/recovery/r24d157_godot_jolt_rotation_integration_energy_zero_world_qualification_closure_v1.json",
    "byte_length": 21291,
    "raw_sha256": "sha256:b1603f995d83228de1f7331673b35d3a2d56514c467061d408025d64ef1b14de",
}
IMAGE_DIRECTORY = (
    "C:/Users/Cole/CodeStuff/games/SporeSpore_Evidence/"
    "qsdk-r24d157-godot-jolt-rotation-integration-energy-v6/"
    "development-cold-build-ed4ec00a/"
)
IMAGES = {
    "godot_console": {
        "path": IMAGE_DIRECTORY + "godot.windows.editor.dev.x86_64.console.exe",
        "byte_length": 293376,
        "raw_sha256": "sha256:2027bcd4adfce5cdecafa5b02392f859b1c61b0895d4f4588b4edf6eb91e2f9c",
    },
    "godot_engine": {
        "path": IMAGE_DIRECTORY + "godot.windows.editor.dev.x86_64.exe",
        "byte_length": 188855808,
        "raw_sha256": "sha256:1b365fe5a054e2614e2c063273d6e686593eafac81836475385df14b65177e4b",
    },
    "sdk_adapter": {
        "path": "C:/Users/Cole/CodeStuff/games/SporeSpore/sdk/target/debug/sporespore_godot_adapter.dll",
        "byte_length": 10120192,
        "raw_sha256": "sha256:0170af9b467434e8d750a699d52547dc88ab24148a860a3c82df05a9de777405",
    },
    "python_helper": {
        "path": "C:/Program Files/Python311/python.exe",
        "byte_length": 103192,
        "raw_sha256": "sha256:5f7b89a612c9b8af1d6456cdfcd1dbe5ca630849e79aebced9bee9a6694952ec",
    },
    "powershell_host": {
        "path": "C:/Program Files/PowerShell/7/pwsh.exe",
        "byte_length": 301368,
        "raw_sha256": "sha256:362a356ce7f0940ec74f73a8fc2c990a2cc24a38a11c90bbd8eca947110ad139",
    },
}
# Preserve the observed L14 image population. The successor is explicit,
# source-bound data; installed bytes never choose their own accepted digest.
LEGACY_IMAGES = copy.deepcopy(IMAGES)
LEGACY_SCHEMA = SCHEMA
HOST_SUCCESSOR_PATH = "sdk/development/recovery_powershell_host_successor_v1.json"
HOST_SUCCESSOR_SHA256 = "sha256:64a98bd44a27d89912fcb9fb955d1776d53f19c6f9080f748a03a3d8d8dfac3e"
_host_raw = (ROOT / HOST_SUCCESSOR_PATH).read_bytes()
if "sha256:" + hashlib.sha256(_host_raw).hexdigest() != HOST_SUCCESSOR_SHA256:
    raise ValueError("RUNTIME_HOST_SUCCESSOR_SOURCE_BINDING")
HOST_SUCCESSOR = json.loads(_host_raw)
if HOST_SUCCESSOR["previous_host"] != LEGACY_IMAGES["powershell_host"]:
    raise ValueError("RUNTIME_HOST_SUCCESSOR_PREDECESSOR")
IMAGES["powershell_host"] = copy.deepcopy(HOST_SUCCESSOR["selected_host"])
SCHEMA = HOST_SUCCESSOR["binding_schema"]

ZERO_COUNTERS = (
    "model_construction_count",
    "world_attempt_count",
    "world_build_count",
    "scene_tree_insertion_count",
    "native_readback_count",
    "solver_step_count",
)
DENIED_FLAGS = (
    "physics_state_modified",
    "physical_execution_authorized",
    "physical_acceptance_authority",
    "release_authority",
)


def require(condition: bool, code: str) -> None:
    if not condition:
        raise ValueError(code)


def file_identity(path: Path, *, display_path: str | None = None) -> dict[str, Any]:
    digest = hashlib.sha256()
    count = 0
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            count += len(chunk)
            digest.update(chunk)
    return {
        "path": display_path if display_path is not None else path.as_posix(),
        "byte_length": count,
        "raw_sha256": "sha256:" + digest.hexdigest(),
    }


def historical_expected_binding() -> dict[str, Any]:
    """Original bytes remain valid as historical records, not current runtime proof."""
    return {
        "schema_version": LEGACY_SCHEMA,
        "gate_id": "QSDK-R10F",
        "repair_id": "QSDK-R10F-L14",
        "ledger_scope": {
            "subsystem": "recovery",
            "engine_scope": "godot_jolt",
            "authority_mode": "zero_world_exact_runtime_image_binding",
            "question_class": "development",
        },
        "ok": True,
        "qualified_native_foundation": copy.deepcopy(FOUNDATION),
        "images": copy.deepcopy(LEGACY_IMAGES),
        "image_count": 5,
        "console_and_engine_are_distinct_required_images": True,
        "file_existence_or_version_string_alone_is_authority": False,
        "selected_images_changed": False,
        "historical_result_reclassified": False,
        "sdk1_m07_satisfied": False,
        **dict.fromkeys(ZERO_COUNTERS, 0),
        **dict.fromkeys(DENIED_FLAGS, False),
    }


def expected_binding() -> dict[str, Any]:
    """Prospective successor; every actual image is still reopened before use."""
    value = historical_expected_binding()
    value.update(schema_version=SCHEMA, images=copy.deepcopy(IMAGES),
                 selected_images_changed=True,
                 host_successor=dict(path=HOST_SUCCESSOR_PATH,
                                     raw_sha256=HOST_SUCCESSOR_SHA256))
    return value


def validate_binding(value: Any) -> None:
    # Diagnostic launch relationships may bind v7 explicitly. This does not
    # change bind_runtime or grant reuse of the v6 official qualification.
    if isinstance(value, dict) and value.get('schema_version') == 'sporespore_r10ap_diagnostic_runtime_image_binding_v1':
        import r10ap_host_runtime
        r10ap_host_runtime.validate_binding(value)
        return
    if isinstance(value, dict) and value.get('schema_version') == 'sporespore_r10am_diagnostic_runtime_image_binding_v1':
        import r10am_host_runtime
        r10am_host_runtime.validate_binding(value)
        return
    if isinstance(value, dict) and value.get('schema_version') == 'sporespore_r10aj_diagnostic_runtime_image_binding_v1':
        import r10aj_host_runtime
        r10aj_host_runtime.validate_binding(value)
        return
    if isinstance(value, dict) and value.get('schema_version') == 'sporespore_r10ai_diagnostic_runtime_image_binding_v1':
        import r10ai_host_runtime
        r10ai_host_runtime.validate_binding(value)
        return
    if isinstance(value, dict) and value.get('schema_version') == 'sporespore_r10ag_diagnostic_runtime_image_binding_v1':
        import r10ag_host_runtime
        r10ag_host_runtime.validate_binding(value)
        return
    if isinstance(value, dict) and value.get('schema_version') == 'sporespore_r10af_diagnostic_runtime_image_binding_v1':
        import r10af_host_runtime
        r10af_host_runtime.validate_binding(value)
        return
    if isinstance(value, dict) and value.get('schema_version') == 'sporespore_r10ae_diagnostic_runtime_image_binding_v1':
        import r10ae_host_runtime
        r10ae_host_runtime.validate_binding(value)
        return
    if isinstance(value, dict) and value.get('schema_version') == 'sporespore_r10ad_diagnostic_runtime_image_binding_v1':
        import r10ad_host_runtime
        r10ad_host_runtime.validate_binding(value)
        return
    if isinstance(value, dict) and value.get('schema_version') == 'sporespore_r10ac_diagnostic_runtime_image_binding_v1':
        import r10ac_host_runtime
        r10ac_host_runtime.validate_binding(value)
        return
    require(
        authority.design_audit.exact(value, expected_binding())
        or authority.design_audit.exact(value, historical_expected_binding()),
        "L14_RUNTIME_BINDING_NOT_EXACT",
    )


def bind_runtime(
    godot: Path,
    *,
    python_executable: Path | None = None,
    powershell_executable: Path | None = None,
) -> dict[str, Any]:
    authority.verify_repository()
    require(
        Path(sys.executable).resolve()
        == Path(IMAGES["python_helper"]["path"]).resolve(),
        "L14_RUNTIME_EXECUTING_PYTHON_PATH",
    )
    offered_python = (
        Path(sys.executable) if python_executable is None else python_executable
    )
    resolved_powershell = (
        shutil.which("pwsh")
        if powershell_executable is None
        else str(powershell_executable)
    )
    require(resolved_powershell is not None, "L14_RUNTIME_POWERSHELL_NOT_RESOLVED")
    for role, offered in (
        ("godot_console", godot),
        ("python_helper", offered_python),
        ("powershell_host", Path(resolved_powershell)),
    ):
        require(
            offered.resolve() == Path(IMAGES[role]["path"]).resolve(),
            "L14_RUNTIME_SELECTED_PATH:" + role,
        )
    foundation_path = ROOT / FOUNDATION["path"]
    require(
        authority.design_audit.exact(
            file_identity(foundation_path, display_path=FOUNDATION["path"]), FOUNDATION
        ),
        "L14_RUNTIME_FOUNDATION_IDENTITY",
    )
    retained = json.loads(foundation_path.read_text(encoding="utf-8"))
    native = retained["qualification_receipt"]["exact_runtime"]
    require(
        native.get("binary_pair_complete") is True
        and authority.design_audit.exact(
            {key: native.get(key) for key in ("path", "byte_length", "raw_sha256")},
            IMAGES["godot_console"],
        )
        and authority.design_audit.exact(
            native.get("engine_binary"), IMAGES["godot_engine"]
        ),
        "L14_RUNTIME_FOUNDATION_PAIR",
    )
    for role, expected in IMAGES.items():
        actual = file_identity(Path(expected["path"]))
        require(
            authority.design_audit.exact(actual, expected), "L14_RUNTIME_IMAGE:" + role
        )
    return expected_binding()


def verify_qualified_binding(
    value: Any, godot: Path, **runtime_paths: Any
) -> dict[str, Any]:
    # A valid stored record does not replace fresh checks of the actual images.
    validate_binding(value)
    current = bind_runtime(godot, **runtime_paths)
    require(
        authority.design_audit.exact(current, value), "L14_RUNTIME_QUALIFICATION_DRIFT"
    )
    return current


def qualification_copies(
    attempt: dict[str, Any],
    implementation: dict[str, Any],
    completion: dict[str, Any],
    retained_runtime: dict[str, Any],
) -> dict[str, Any]:
    """Require every retained copy, then reopen the actual selected images."""
    for label, document in (
        ("attempt", attempt),
        ("completion", completion),
        ("runtime", retained_runtime),
    ):
        require(isinstance(document, dict), "L14_RUNTIME_DOCUMENT:" + label)
        validate_binding(document.get("l14_exact_runtime_images"))
    require(
        authority.design_audit.exact(
            implementation.get("runtime_identity"), retained_runtime
        ),
        "L14_RUNTIME_IMPLEMENTATION_RETAINED_COPY",
    )
    return verify_qualified_binding(
        retained_runtime["l14_exact_runtime_images"],
        Path(IMAGES["godot_console"]["path"]),
    )


def read_retained_runtime(binding: Any, source_commit: str) -> dict[str, Any]:
    """Reopen only the content-addressed runtime JSON of this exact source.

    Closing an already observed result checks its retained record, not a new
    installation that may have changed after the observation. Launch checks
    separately reopen the current images.
    """
    require(
        isinstance(source_commit, str)
        and re.fullmatch(r"[0-9a-f]{40}", source_commit) is not None,
        "L14_RUNTIME_RETAINED_SOURCE_COMMIT",
    )
    path = (
        ROOT.parent
        / "SporeSpore_Evidence"
        / (
            "qsdk-r10f-development-route-ghost-zero-world-qualification-"
            + source_commit[:12]
        )
        / "runtime_identity.json"
    )
    require(
        isinstance(binding, dict)
        and set(binding) == {"path", "byte_length", "raw_sha256"}
        and isinstance(binding.get("path"), str)
        and Path(binding["path"]).resolve() == path.resolve(),
        "L14_RUNTIME_RETAINED_PATH",
    )
    require(
        authority.design_audit.exact(
            file_identity(path, display_path=binding["path"]), binding
        ),
        "L14_RUNTIME_RETAINED_IDENTITY",
    )
    retained = json.loads(path.read_text(encoding="utf-8"))
    require(isinstance(retained, dict), "L14_RUNTIME_RETAINED_DOCUMENT")
    validate_binding(retained.get("l14_exact_runtime_images"))
    return retained


def binding_corruptions() -> list[dict[str, Any]]:
    """Missing fields and selected-image/kind drift for actual consumers."""
    original = expected_binding()
    cases: list[dict[str, Any]] = []

    def visit(value: Any, path: tuple[str, ...] = ()) -> None:
        if not isinstance(value, dict):
            return
        for key, child in value.items():
            changed = copy.deepcopy(original)
            owner = changed
            for parent in path:
                owner = owner[parent]
            del owner[key]
            cases.append(
                {"id": "missing:" + "/".join((*path, key)), "binding": changed}
            )
            visit(child, (*path, key))

    visit(original)
    for role, identity in IMAGES.items():
        for key, replacement in (
            ("byte_length", float(identity["byte_length"])),
            ("raw_sha256", "sha256:" + "0" * 64),
            ("path", "C:/synthetic/wrong-image.exe"),
        ):
            changed = copy.deepcopy(original)
            changed["images"][role][key] = replacement
            cases.append({"id": role + ":" + key, "binding": changed})
    changed = copy.deepcopy(original)
    changed["physical_execution_authorized"] = True
    cases.append({"id": "physical_authority", "binding": changed})
    return cases


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--godot", type=Path, required=True)
    parser.add_argument("--powershell-host", type=Path)
    parser.add_argument("--expected-binding-stdin", action="store_true")
    arguments = parser.parse_args()
    try:
        if arguments.expected_binding_stdin:
            offered = json.load(sys.stdin)
            binding = verify_qualified_binding(
                offered,
                arguments.godot,
                powershell_executable=arguments.powershell_host,
            )
        else:
            binding = bind_runtime(
                arguments.godot, powershell_executable=arguments.powershell_host
            )
    except (ValueError, OSError, KeyError) as exc:
        print("QSDK_R10F_L14_EXACT_RUNTIME_BINDING_FAIL " + str(exc), file=sys.stderr)
        return 1
    print(MARKER + json.dumps(binding, sort_keys=True, separators=(",", ":")))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
