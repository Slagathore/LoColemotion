"""Audit the exact Rust, C, Python, and built-library portable API surface.

This module deliberately does not run a physics engine.  It compares the
versioned public contract with the source declarations and, when supplied,
the real dynamic library that Python consumers load.
"""

from __future__ import annotations

import argparse
import ast
import ctypes
import hashlib
import json
import re
import sys
import tomllib
from pathlib import Path
from typing import Any


REPORT_PREFIX = "PORTABLE_API_SURFACE_CONFORMANCE "
CONTRACT_SCHEMA = "sporespore_portable_api_contract_v2"
INVENTORY_SCHEMA = "sporespore_quadruped_package_source_inventory_v1"
SURFACE_REPORT_SCHEMA = "sporespore_portable_api_surface_conformance_v1"


class ConformanceError(RuntimeError):
    """Raised when one public-surface invariant no longer holds."""


def _require(condition: bool, message: str) -> None:
    if not condition:
        raise ConformanceError(message)


def _read_json_object(path: Path) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as exc:
        raise ConformanceError(f"invalid JSON at {path}: {exc}") from exc
    _require(isinstance(value, dict), f"expected a JSON object at {path}")
    return value


def _sha256(path: Path) -> str:
    return f"sha256:{hashlib.sha256(path.read_bytes()).hexdigest()}"


def _normalized_whitespace(value: str) -> str:
    return " ".join(value.strip().split())


def _normalized_rust_type(value: str) -> str:
    normalized = _normalized_whitespace(value)
    normalized = re.sub(r"\s*\*\s*(const|mut)\s*", r"*\1 ", normalized)
    return normalized


def _normalized_c_type(value: str) -> str:
    normalized = _normalized_whitespace(value)
    normalized = re.sub(r"\s*\*\s*", "*", normalized)
    return normalized


def _parse_rust_exports(source: str) -> dict[str, dict[str, Any]]:
    pattern = re.compile(
        r'^pub\s+(?:unsafe\s+)?extern\s+"C"\s+fn\s+'
        r"(ss_[A-Za-z0-9_]+)\s*\((.*?)\)\s*->\s*([^\{\r\n]+)\s*\{",
        re.MULTILINE | re.DOTALL,
    )
    exports: dict[str, dict[str, Any]] = {}
    for match in pattern.finditer(source):
        name, raw_parameters, raw_return = match.groups()
        _require(name not in exports, f"duplicate Rust export: {name}")
        parameters: list[str] = []
        for raw_parameter in raw_parameters.split(","):
            raw_parameter = raw_parameter.strip()
            if not raw_parameter:
                continue
            _require(
                ":" in raw_parameter,
                f"could not parse Rust parameter for {name}: {raw_parameter}",
            )
            _, raw_type = raw_parameter.split(":", 1)
            parameters.append(_normalized_rust_type(raw_type))
        exports[name] = {
            "parameters": parameters,
            "return": _normalized_rust_type(raw_return),
        }

    no_mangle_count = len(re.findall(r"#\[unsafe\(no_mangle\)\]", source))
    _require(
        no_mangle_count == len(exports),
        "every no_mangle declaration must be one parsed public C export "
        f"(annotations={no_mangle_count}, exports={len(exports)})",
    )
    return exports


def _parse_c_declarations(source: str) -> dict[str, dict[str, Any]]:
    pattern = re.compile(
        r"^SS_API\s+([^\r\n]*?)\b(ss_[A-Za-z0-9_]+)\s*\((.*?)\)\s*;",
        re.MULTILINE | re.DOTALL,
    )
    declarations: dict[str, dict[str, Any]] = {}
    for match in pattern.finditer(source):
        raw_return, name, raw_parameters = match.groups()
        _require(name not in declarations, f"duplicate C declaration: {name}")
        parameters: list[str] = []
        if raw_parameters.strip() != "void":
            for raw_parameter in raw_parameters.split(","):
                normalized = _normalized_whitespace(raw_parameter)
                typed_name = re.fullmatch(r"(.+?)([A-Za-z_][A-Za-z0-9_]*)", normalized)
                _require(
                    typed_name is not None,
                    f"could not parse C parameter for {name}: {normalized}",
                )
                parameters.append(_normalized_c_type(typed_name.group(1)))
        declarations[name] = {
            "parameters": parameters,
            "return": _normalized_c_type(raw_return),
        }
    return declarations


def _ctypes_expression(node: ast.AST, aliases: dict[str, str] | None = None) -> str:
    aliases = {} if aliases is None else aliases
    if isinstance(node, ast.Name) and node.id in aliases:
        return aliases[node.id]
    if isinstance(node, ast.Attribute):
        if isinstance(node.value, ast.Name) and node.value.id == "ctypes":
            return node.attr
    if isinstance(node, ast.Call):
        if (
            isinstance(node.func, ast.Attribute)
            and isinstance(node.func.value, ast.Name)
            and node.func.value.id == "ctypes"
            and node.func.attr == "POINTER"
            and len(node.args) == 1
            and not node.keywords
        ):
            return f"POINTER({_ctypes_expression(node.args[0], aliases)})"
    raise ConformanceError(
        "unsupported ctypes signature expression: "
        + ast.dump(node, include_attributes=False)
    )


def _ctypes_argtypes(node: ast.AST, aliases: dict[str, str]) -> list[str]:
    _require(isinstance(node, (ast.List, ast.Tuple)), "ctypes argtypes must be a list")
    return [_ctypes_expression(element, aliases) for element in node.elts]


def _direct_library_signature_target(target: ast.AST) -> tuple[str, str] | None:
    if not isinstance(target, ast.Attribute) or target.attr not in {
        "argtypes",
        "restype",
    }:
        return None
    symbol_node = target.value
    if not (
        isinstance(symbol_node, ast.Attribute)
        and symbol_node.attr.startswith("ss_")
        and isinstance(symbol_node.value, ast.Attribute)
        and symbol_node.value.attr == "_library"
        and isinstance(symbol_node.value.value, ast.Name)
        and symbol_node.value.value.id == "self"
    ):
        return None
    return symbol_node.attr, target.attr


def _assign_ctypes_field(
    signatures: dict[str, dict[str, Any]],
    symbol: str,
    field: str,
    value: ast.AST,
    aliases: dict[str, str],
) -> None:
    entry = signatures.setdefault(symbol, {})
    _require(field not in entry, f"duplicate Python ctypes {field} for {symbol}")
    if field == "argtypes":
        entry[field] = _ctypes_argtypes(value, aliases)
    else:
        entry[field] = _ctypes_expression(value, aliases)


def _parse_python_ctypes_signatures(source: str) -> dict[str, dict[str, Any]]:
    try:
        module = ast.parse(source)
    except SyntaxError as exc:
        raise ConformanceError(f"invalid Python binding syntax: {exc}") from exc

    configure: ast.FunctionDef | None = None
    for node in module.body:
        if isinstance(node, ast.ClassDef) and node.name == "LocomotionCore":
            for child in node.body:
                if (
                    isinstance(child, ast.FunctionDef)
                    and child.name == "_configure_signatures"
                ):
                    configure = child
                    break
    _require(configure is not None, "LocomotionCore._configure_signatures is missing")

    signatures: dict[str, dict[str, Any]] = {}
    aliases: dict[str, str] = {}
    for statement in configure.body:
        if (
            isinstance(statement, ast.Assign)
            and len(statement.targets) == 1
            and isinstance(statement.targets[0], ast.Name)
        ):
            try:
                aliases[statement.targets[0].id] = _ctypes_expression(
                    statement.value, aliases
                )
            except ConformanceError:
                continue
    for statement in configure.body:
        if isinstance(statement, ast.Assign) and len(statement.targets) == 1:
            direct = _direct_library_signature_target(statement.targets[0])
            if direct is not None:
                _assign_ctypes_field(
                    signatures, direct[0], direct[1], statement.value, aliases
                )
        if not isinstance(statement, ast.For):
            continue
        _require(
            isinstance(statement.target, ast.Name) and statement.target.id == "name",
            "ctypes signature loop must iterate with the name variable",
        )
        _require(
            isinstance(statement.iter, (ast.Tuple, ast.List)),
            "ctypes signature loop must use a literal symbol tuple",
        )
        names: list[str] = []
        for element in statement.iter.elts:
            _require(
                isinstance(element, ast.Constant)
                and isinstance(element.value, str)
                and element.value.startswith("ss_"),
                "ctypes signature loop contains a non-literal symbol",
            )
            names.append(element.value)
        loop_fields: dict[str, ast.AST] = {}
        loop_body = []
        for child in statement.body:
            if isinstance(child, ast.If):
                _require(ast.unparse(child.test) == "function is not None" and not child.orelse,
                         "unsupported conditional ctypes signature")
                loop_body.extend(child.body)
            else:
                loop_body.append(child)
        for child in loop_body:
            if not isinstance(child, ast.Assign) or len(child.targets) != 1:
                continue
            target = child.targets[0]
            if (
                isinstance(target, ast.Attribute)
                and isinstance(target.value, ast.Name)
                and target.value.id == "function"
                and target.attr in {"argtypes", "restype"}
            ):
                _require(
                    target.attr not in loop_fields,
                    f"duplicate loop ctypes {target.attr}",
                )
                loop_fields[target.attr] = child.value
        _require(
            set(loop_fields) == {"argtypes", "restype"},
            "every ctypes signature loop must declare argtypes and restype",
        )
        for name in names:
            _assign_ctypes_field(
                signatures, name, "argtypes", loop_fields["argtypes"], aliases
            )
            _assign_ctypes_field(
                signatures, name, "restype", loop_fields["restype"], aliases
            )

    incomplete = sorted(
        name
        for name, signature in signatures.items()
        if set(signature) != {"argtypes", "restype"}
    )
    _require(not incomplete, f"incomplete Python ctypes signatures: {incomplete}")
    return signatures


def _expected_signatures(
    contract: dict[str, Any], language: str
) -> dict[str, dict[str, Any]]:
    groups = contract.get("signature_groups")
    _require(
        isinstance(groups, list) and groups, "contract signature_groups are missing"
    )
    group_ids: set[str] = set()
    signatures: dict[str, dict[str, Any]] = {}
    for group in groups:
        _require(isinstance(group, dict), "signature group must be an object")
        group_id = group.get("group_id")
        _require(
            isinstance(group_id, str) and group_id, "signature group ID is missing"
        )
        _require(group_id not in group_ids, f"duplicate signature group ID: {group_id}")
        group_ids.add(group_id)
        declared = group.get(language)
        _require(isinstance(declared, dict), f"{group_id} has no {language} signature")
        if language == "python_ctypes":
            signature = {
                "argtypes": declared.get("argtypes"),
                "restype": declared.get("restype"),
            }
        else:
            signature = {
                "parameters": declared.get("parameters"),
                "return": declared.get("return"),
            }
        for symbol in group.get("symbols", []):
            _require(
                isinstance(symbol, str) and symbol.startswith("ss_"),
                f"invalid symbol in {group_id}",
            )
            _require(symbol not in signatures, f"duplicate contract symbol: {symbol}")
            signatures[symbol] = signature
    return signatures


def _validate_contract(contract: dict[str, Any]) -> None:
    _require(contract.get("schema_version") == CONTRACT_SCHEMA, "wrong contract schema")
    _require(contract.get("release_gate_id") == "QSDK-R01", "wrong release gate")
    _require(contract.get("sdk_version") == "0.1.0", "wrong SDK version")
    _require(contract.get("abi_generation") == 1, "wrong ABI generation")
    _require(
        contract.get("requires_clean_room_candidate") is True, "candidate is required"
    )
    ledger = contract.get("ledger_scope")
    _require(
        ledger
        == {
            "subsystem": "release",
            "engine_scope": "engine_neutral",
            "authority_mode": "zero_world_source_and_package_conformance",
            "question_class": "development",
        },
        "portable API ledger scope changed",
    )
    acceptance = contract.get("clean_room_acceptance")
    true_acceptance_rules = {
        "package_manifest_required",
        "not_for_distribution_marker_required",
        "candidate_authorization_report_required",
        "candidate_authorization_report_hash_must_match_package_manifest",
        "candidate_authorization_source_commit_must_match_package_manifest",
        "candidate_authorization_report_must_be_outside_package_and_source",
        "source_repository_metadata_forbidden",
        "symbolic_links_and_reparse_points_forbidden",
        "unlisted_package_files_forbidden",
        "all_package_file_hashes_must_match",
        "all_required_portable_api_paths_must_be_packaged",
        "build_and_all_conformance_cells_must_run_from_package_root",
        "build_artifacts_must_be_created_inside_package",
        "library_override_forbidden",
        "retained_source_report_library_override_forbidden",
        "report_must_be_retained_outside_package_and_source",
    }
    zero_acceptance_rules = {
        "world_build_count_must_equal",
        "solver_step_count_must_equal",
    }
    _require(isinstance(acceptance, dict), "clean-room acceptance contract is missing")
    _require(
        set(acceptance)
        == true_acceptance_rules
        | zero_acceptance_rules
        | {"physical_acceptance_authority_must_equal"},
        "clean-room acceptance rule set changed",
    )
    for rule in true_acceptance_rules:
        _require(acceptance.get(rule) is True, f"clean-room rule weakened: {rule}")
    for rule in zero_acceptance_rules:
        value = acceptance.get(rule)
        _require(
            type(value) is int and value == 0,
            f"clean-room zero-execution rule changed: {rule}",
        )
    _require(
        acceptance.get("physical_acceptance_authority_must_equal") is False,
        "clean-room proof gained physical authority",
    )
    boundary = contract.get("claim_boundary")
    _require(isinstance(boundary, dict), "contract claim boundary is missing")
    for false_claim in (
        "clean_room_candidate_validated",
        "r01_passed",
        "sdk1_m01_passed",
        "release_authorized",
        "publication_authorized",
        "walking_acceptance",
        "physical_acceptance_authority",
        "completed_engine_neutral_sdk",
    ):
        _require(
            boundary.get(false_claim) is False,
            f"source contract promoted {false_claim}",
        )


def validate_package_pathspecs(pathspecs: Any) -> None:
    """Match the packager's SDK-only inclusion/exclusion grammar."""
    _require(isinstance(pathspecs, list) and pathspecs, "package pathspecs are missing")
    _require(all(isinstance(p, str) for p in pathspecs), "package pathspec must be a string")
    _require(len(pathspecs) == len(set(pathspecs)), "duplicate package pathspec")
    for pathspec in pathspecs:
        path = pathspec.removeprefix(":(exclude)")
        _require(re.fullmatch(r"sdk/[A-Za-z0-9_./*?-]+", path) is not None
                 and not any(part in (".", "..") for part in path.split("/")),
                 f"unsafe package pathspec: {pathspec}")


def _validate_inventory(
    sdk_root: Path, contract: dict[str, Any], inventory: dict[str, Any]
) -> list[str]:
    _require(
        inventory.get("schema_version") == INVENTORY_SCHEMA, "wrong inventory schema"
    )
    _require(inventory.get("source_root") == "sdk", "wrong package source root")
    validate_package_pathspecs(inventory.get("git_pathspecs"))

    required = inventory.get("required_portable_api_paths")
    _require(
        isinstance(required, list) and required, "required portable paths are missing"
    )
    _require(len(required) == len(set(required)), "duplicate required portable path")
    required_set = set(required)
    public_surfaces = contract.get("public_surfaces")
    _require(isinstance(public_surfaces, dict), "contract public surfaces are missing")
    _require(
        set(public_surfaces.values()).issubset(required_set),
        "a contract public surface is not mandatory in the package inventory",
    )
    for relative in required:
        _require(
            isinstance(relative, str)
            and relative
            and not Path(relative).is_absolute()
            and ".." not in Path(relative).parts
            and "\\" not in relative,
            f"unsafe required package path: {relative}",
        )
        _require(
            (sdk_root / relative).is_file(),
            f"required portable API file is missing: {relative}",
        )
    boundary = inventory.get("claim_boundary")
    _require(
        isinstance(boundary, dict)
        and boundary.get("inventory_defines_source_projection_only") is True
        and boundary.get("inventory_is_a_package_authorization") is False
        and boundary.get("inventory_is_a_publication_authorization") is False
        and boundary.get("clean_room_candidate_validation_required") is True
        and boundary.get("physical_acceptance_authority") is False,
        "package source inventory claim boundary changed",
    )
    return required


def _python_ctype(name: str) -> Any:
    primitive = {
        "c_char_p": ctypes.c_char_p,
        "c_int": ctypes.c_int,
        "c_size_t": ctypes.c_size_t,
        "c_uint8": ctypes.c_uint8,
        "c_uint64": ctypes.c_uint64,
    }
    if name in primitive:
        return primitive[name]
    pointer = re.fullmatch(r"POINTER\(([A-Za-z0-9_]+)\)", name)
    _require(pointer is not None, f"unknown contract ctypes type: {name}")
    pointee = primitive.get(pointer.group(1))
    _require(pointee is not None, f"unknown contract ctypes pointee: {name}")
    return ctypes.POINTER(pointee)


def _decode_probe_json(output: Any, length: int, symbol: str) -> dict[str, Any]:
    try:
        value = json.loads(bytes(output[:length]).decode("utf-8", errors="strict"))
    except (UnicodeError, json.JSONDecodeError) as exc:
        raise ConformanceError(f"{symbol} returned invalid probe JSON: {exc}") from exc
    _require(isinstance(value, dict), f"{symbol} probe did not return a JSON object")
    return value


def _probe_dynamic_abi(
    library: Any,
    contract: dict[str, Any],
    expected_python: dict[str, dict[str, Any]],
) -> dict[str, int]:
    for symbol, signature in expected_python.items():
        function = getattr(library, symbol)
        function.argtypes = [_python_ctype(name) for name in signature["argtypes"]]
        function.restype = _python_ctype(signature["restype"])

    groups = {
        group["group_id"]: list(group["symbols"])
        for group in contract["signature_groups"]
    }
    payload_bytes = b"{}"
    payload = (ctypes.c_uint8 * len(payload_bytes)).from_buffer_copy(payload_bytes)
    invocation_count = 0
    buffer_protocol_symbol_count = 0

    version = library.ss_version()
    invocation_count += 1
    _require(version is not None, "ss_version returned null during ABI probe")
    _require(
        version.decode("utf-8", errors="strict") == contract["sdk_version"],
        "ss_version changed during ABI probe",
    )

    for symbol in groups["json_input_caller_owned_output"]:
        function = getattr(library, symbol)
        required = ctypes.c_size_t(0)
        first = function(payload, len(payload_bytes), None, 0, ctypes.byref(required))
        _require(
            first == 2 and required.value > 0, f"{symbol} size query contract failed"
        )
        output = (ctypes.c_uint8 * required.value)()
        second = function(
            payload,
            len(payload_bytes),
            output,
            required.value,
            ctypes.byref(required),
        )
        _require(
            second == 3, f"{symbol} malformed JSON request was not typed core error"
        )
        failure = _decode_probe_json(output, required.value, symbol)
        _require(
            failure.get("ok") is False
            and isinstance(failure.get("failure_code"), str)
            and bool(failure["failure_code"]),
            f"{symbol} malformed-request failure envelope changed",
        )
        invocation_count += 1
        buffer_protocol_symbol_count += 1

    for symbol in groups["json_output_only_caller_owned_output"]:
        function = getattr(library, symbol)
        required = ctypes.c_size_t(0)
        first = function(None, 0, ctypes.byref(required))
        _require(
            first == 2 and required.value > 0, f"{symbol} size query contract failed"
        )
        output = (ctypes.c_uint8 * required.value)()
        second = function(output, required.value, ctypes.byref(required))
        _require(second == 0, f"{symbol} output-only call failed")
        success = _decode_probe_json(output, required.value, symbol)
        _require(success.get("ok") is True, f"{symbol} success envelope changed")
        invocation_count += 1
        buffer_protocol_symbol_count += 1

    create_symbol = groups["policy_session_create"][0]
    handle = ctypes.c_uint64(0)
    create_status = getattr(library, create_symbol)(
        payload, len(payload_bytes), ctypes.byref(handle)
    )
    _require(
        create_status == 3 and handle.value == 0,
        "policy-session create malformed-request contract changed",
    )
    invocation_count += 1

    step_symbol = groups["policy_session_step"][0]
    step = getattr(library, step_symbol)
    required = ctypes.c_size_t(0)
    first = step(0, payload, len(payload_bytes), None, 0, ctypes.byref(required))
    _require(first == 2 and required.value > 0, "policy-session step size query failed")
    output = (ctypes.c_uint8 * required.value)()
    second = step(
        0,
        payload,
        len(payload_bytes),
        output,
        required.value,
        ctypes.byref(required),
    )
    _require(second == 3, "policy-session malformed step was not a typed core error")
    failure = _decode_probe_json(output, required.value, step_symbol)
    _require(failure.get("ok") is False, "policy-session step failure envelope changed")
    invocation_count += 1
    buffer_protocol_symbol_count += 1

    destroy_symbol = groups["policy_session_destroy"][0]
    _require(
        getattr(library, destroy_symbol)(0) == 1,
        "zero policy-session handle was not rejected",
    )
    invocation_count += 1

    _require(
        invocation_count == len(expected_python),
        "not every declared symbol was invoked through the C ABI",
    )
    return {
        "invoked_export_count": invocation_count,
        "buffer_protocol_symbol_count": buffer_protocol_symbol_count,
        "typed_malformed_json_refusal_count": len(
            groups["json_input_caller_owned_output"]
        )
        + 2,
        "output_only_success_count": len(
            groups["json_output_only_caller_owned_output"]
        ),
    }


def audit_source_surfaces(
    sdk_root: Path | str, library_path: Path | str | None = None
) -> dict[str, Any]:
    root = Path(sdk_root).resolve()
    contract_path = root / "portable_api" / "portable_api_contract_v2.json"
    inventory_path = root / "release" / "quadruped_package_source_inventory_v1.json"
    cargo_path = root / "core" / "Cargo.toml"
    rust_path = root / "core" / "src" / "ffi.rs"
    header_path = root / "include" / "sporespore_locomotion.h"
    python_path = root / "python" / "sporespore_locomotion.py"

    for path in (
        contract_path,
        inventory_path,
        cargo_path,
        rust_path,
        header_path,
        python_path,
    ):
        _require(path.is_file(), f"portable API surface is missing: {path}")

    contract = _read_json_object(contract_path)
    inventory = _read_json_object(inventory_path)
    _validate_contract(contract)
    required_paths = _validate_inventory(root, contract, inventory)

    try:
        cargo = tomllib.loads(cargo_path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, tomllib.TOMLDecodeError) as exc:
        raise ConformanceError(f"invalid portable-core Cargo.toml: {exc}") from exc
    artifact = contract["rust_artifact_contract"]
    _require(
        cargo.get("package", {}).get("name") == artifact["package_name"],
        "wrong crate name",
    )
    _require(
        cargo.get("package", {}).get("version") == contract["sdk_version"],
        "wrong crate version",
    )
    _require(
        cargo.get("lib", {}).get("name") == artifact["library_name"],
        "wrong library name",
    )
    _require(
        cargo.get("lib", {}).get("crate-type") == artifact["crate_types"],
        "wrong crate types",
    )

    rust_source = rust_path.read_text(encoding="utf-8")
    header_source = header_path.read_text(encoding="utf-8")
    python_source = python_path.read_text(encoding="utf-8")
    rust_exports = _parse_rust_exports(rust_source)
    c_declarations = _parse_c_declarations(header_source)
    python_signatures = _parse_python_ctypes_signatures(python_source)
    # The SDK1 extension preserves the legacy binding used by retained physics
    # evidence while declaring all four additional existing native exports.
    extension_header = root / "include" / "sporespore_locomotion_sdk1.h"
    extension_python = root / "python" / "sporespore_locomotion_sdk1.py"
    extra_c = _parse_c_declarations(extension_header.read_text(encoding="utf-8"))
    extra_python = _parse_python_ctypes_signatures(extension_python.read_text(encoding="utf-8"))
    _require(not (set(c_declarations) & set(extra_c)), "duplicate extension C declaration")
    _require(not (set(python_signatures) & set(extra_python)), "duplicate extension Python signature")
    c_declarations.update(extra_c)
    python_signatures.update(extra_python)
    expected_rust = _expected_signatures(contract, "rust")
    expected_c = _expected_signatures(contract, "c")
    expected_python = _expected_signatures(contract, "python_ctypes")

    _require(
        rust_exports == expected_rust,
        "Rust exports differ from the portable API contract",
    )
    _require(
        c_declarations == expected_c,
        "C declarations differ from the portable API contract",
    )
    _require(
        python_signatures == expected_python,
        "Python ctypes signatures differ from the portable API contract",
    )
    _require(
        f'#define SS_SDK_VERSION "{contract["sdk_version"]}"' in header_source,
        "C header SDK version differs from the contract",
    )
    _require(
        f'#define SS_ABI_GENERATION {contract["abi_generation"]}' in header_source,
        "C header ABI generation differs from the contract",
    )

    library_receipt: dict[str, Any] | None = None
    if library_path is not None:
        resolved_library = Path(library_path).resolve()
        _require(
            resolved_library.is_file(),
            f"dynamic library is missing: {resolved_library}",
        )
        try:
            library = ctypes.CDLL(str(resolved_library))
            missing_symbols = [
                symbol for symbol in expected_rust if not hasattr(library, symbol)
            ]
            _require(
                not missing_symbols,
                f"dynamic library exports are missing: {missing_symbols}",
            )
            probe = _probe_dynamic_abi(library, contract, expected_python)
            library.ss_version.argtypes = []
            library.ss_version.restype = ctypes.c_char_p
            raw_version = library.ss_version()
            _require(raw_version is not None, "dynamic library returned a null version")
            version = raw_version.decode("utf-8", errors="strict")
        except (OSError, UnicodeError) as exc:
            raise ConformanceError(f"could not inspect dynamic library: {exc}") from exc
        _require(version == contract["sdk_version"], "dynamic library version differs")
        library_receipt = {
            "path": str(resolved_library),
            "sha256": _sha256(resolved_library),
            "version": version,
            "resolved_export_count": len(expected_rust),
            "missing_exports": [],
            **probe,
        }

    source_hashes = {
        "contract": _sha256(contract_path),
        "package_source_inventory": _sha256(inventory_path),
        "rust_crate": _sha256(cargo_path),
        "rust_ffi": _sha256(rust_path),
        "c_header": _sha256(header_path),
        "python_binding": _sha256(python_path),
        "sdk1_c_header": _sha256(extension_header),
        "sdk1_python_binding": _sha256(extension_python),
    }
    return {
        "schema_version": SURFACE_REPORT_SCHEMA,
        "ok": True,
        "release_gate_id": "QSDK-R01",
        "ledger_scope": contract["ledger_scope"],
        "sdk_version": contract["sdk_version"],
        "abi_generation": contract["abi_generation"],
        "signature_group_count": len(contract["signature_groups"]),
        "contract_symbol_count": len(expected_rust),
        "rust_export_count": len(rust_exports),
        "c_declaration_count": len(c_declarations),
        "python_ctypes_signature_count": len(python_signatures),
        "required_package_path_count": len(required_paths),
        "source_hashes": source_hashes,
        "library": library_receipt,
        "rust_c_python_exact_signature_parity": True,
        "all_dynamic_library_exports_resolved": library_receipt is not None,
        "physics_model_construction_count": 0,
        "world_build_count": 0,
        "solver_step_count": 0,
        "physical_acceptance_authority": False,
        "release_authorized": False,
        "publication_authorized": False,
    }


def _parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--sdk-root", type=Path, required=True)
    parser.add_argument("--library", type=Path, required=True)
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = _parse_args(sys.argv[1:] if argv is None else argv)
    try:
        receipt = audit_source_surfaces(args.sdk_root, args.library)
    except ConformanceError as exc:
        print(f"PORTABLE_API_SURFACE_ERROR {exc}", file=sys.stderr)
        return 2
    print(
        REPORT_PREFIX
        + json.dumps(receipt, sort_keys=True, separators=(",", ":"), allow_nan=False)
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
