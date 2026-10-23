"""Local, relocatable runtime bindings. Verification never constructs a world."""
from __future__ import annotations

import argparse
import hashlib
import importlib.metadata
import json
from pathlib import Path, PurePosixPath
import shutil
import subprocess
import sys

SCHEMA = "locolemotion_studio_dependencies_v2"
ROLES = {"core", "rapier", "godot", "recovery_engine", "recovery_console", "recovery_dll"}
SCOPE = dict(subsystem="explorer", engine_scope="3e", authority_mode="development", question_class="development")


def digest(path):
    with Path(path).open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def binding(path, relative):
    return dict(path=relative, byte_length=path.stat().st_size, sha256=digest(path))


def within(root, relative):
    if (not isinstance(relative, str) or not relative or "\\" in relative or ":" in relative
            or relative.startswith("/") or any(p in {"", ".", ".."} for p in relative.split("/"))):
        raise ValueError("Unsafe portable path: " + str(relative))
    path = (root / PurePosixPath(relative)).resolve()
    if not path.is_relative_to(root.resolve()):
        raise ValueError("Portable path escapes installation: " + relative)
    return path


def verify_files(root, records, *, exact_folder=None):
    expected = {r["path"]: r for r in records}
    if len(expected) != len(records) or not expected:
        raise ValueError("Empty or repeated file inventory")
    for relative, row in expected.items():
        path = within(root, relative)
        if not path.is_file() or binding(path, relative) != row:
            raise ValueError("Missing or changed portable file: " + relative)
    if exact_folder is not None:
        actual = {p.relative_to(root).as_posix() for p in within(root, exact_folder).rglob("*") if p.is_file()}
        if actual != set(expected):
            raise ValueError("Portable file population changed")


def lock_requirements(path):
    packages = {}
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        if line.count("==") != 1:
            raise ValueError("Studio requires exact package versions")
        name, version = line.split("==")
        packages[name] = version
    if not {"mujoco", "numpy"} <= packages.keys():
        raise ValueError("Incomplete Python package lock")
    return packages


def python_identity(packages):
    """Bind imported code and native libraries without importing/starting physics.

    Venv paths and generated entry-point launchers are deliberately not copied.
    A new location supplies its own interpreter with these same runtime bytes.
    """
    if sys.version_info[:2] != (3, 11) or sys.platform != "win32":
        raise ValueError("This Studio runtime requires Windows CPython 3.11")
    files = []
    for name, expected in sorted(packages.items()):
        dist = importlib.metadata.distribution(name)
        if dist.version != expected:
            raise ValueError(f"Python package mismatch: {name} requires {expected}, found {dist.version}")
        population = []
        for relative in dist.files or []:
            parts = relative.parts
            if ".." in parts or "__pycache__" in parts or any(p.endswith(".dist-info") for p in parts):
                continue
            path = Path(dist.locate_file(relative)).resolve()
            if path.suffix.lower() in {".py", ".pyd", ".dll"}:
                population.append(binding(path, name + "/" + relative.as_posix()))
        if not population:
            raise ValueError("Missing package code inventory: " + name)
        files.extend(population)
    base = Path(sys.base_prefix)
    for path in [Path(sys.executable), Path(sys._base_executable), base / "python311.dll", base / "python3.dll"]:
        # Different identities for venv launcher and the underlying interpreter.
        role = "launcher" if path == Path(sys.executable) else "base/" + path.name
        row = binding(path, role)
        if row not in files:
            files.append(row)
    return dict(python_version=sys.version.split()[0], packages=packages,
                files=sorted(files, key=lambda r: r["path"]), world_build_count=0)


def inspect_python(executable, packages):
    command = [str(executable), "-B", str(Path(__file__).resolve()), "--python-identity", json.dumps(packages)]
    result = subprocess.run(command, cwd=Path(__file__).parent, capture_output=True, text=True, timeout=60)
    if result.returncode:
        raise ValueError("Python runtime preflight refused: " + result.stderr.strip())
    return json.loads(result.stdout)


def make_portable(config, output, source_commit, packages):
    """Copy supplied executables locally; this grants no redistribution license."""
    if set(config) - ROLES - {"mujoco_python", "source_commit"}:
        raise ValueError("Unknown legacy dependency role")
    if not ROLES <= config.keys() or "mujoco_python" not in config:
        raise ValueError("Incomplete Studio dependency roles")
    python = inspect_python(config["mujoco_python"], packages)
    roles = {}
    files = []
    # Keep the console launcher and its engine in one directory with exact names.
    for role in sorted(ROLES):
        original = Path(config[role]).resolve(strict=True)
        group = "recovery" if role in {"recovery_engine", "recovery_console"} else role
        relative = "runtimes/" + group + "/" + original.name
        target = within(output, relative)
        target.parent.mkdir(parents=True, exist_ok=True)
        if target.exists():
            raise ValueError("Runtime output already exists")
        before = binding(original, relative)
        shutil.copy2(original, target)
        if binding(target, relative) != before or binding(original, relative) != before:
            raise ValueError("Runtime changed while copying")
        files.append(before)
        roles[role] = relative
    value = dict(schema_version=SCHEMA, ledger_scope=SCOPE, source_commit=source_commit,
                 roles=roles, runtime_files=files, python_runtime=python,
                 python_resolution="explicit_interpreter_at_launch", bundled_native_binaries="local_copy_only",
                 physical_acceptance_authority=False, release_authority=False,
                 binary_distribution_authorized=False)
    return value


def load_dependencies(path, source_commit, python=None):
    value = json.loads(path.read_text(encoding="utf-8-sig"))
    if "schema_version" not in value:
        # The historical local configuration remains usable, but is not portable.
        result = dict(value, source_commit=source_commit)
        if python is not None:
            result["mujoco_python"] = str(Path(python).resolve(strict=True))
        return result
    if value["schema_version"] != SCHEMA or value["source_commit"] != source_commit:
        raise ValueError("Portable dependency/source identity mismatch")
    for flag in ["physical_acceptance_authority", "release_authority", "binary_distribution_authorized"]:
        if value[flag] is not False:
            raise ValueError("Portable setup cannot grant authority")
    if set(value["roles"]) != ROLES or len(set(value["roles"].values())) != len(ROLES):
        raise ValueError("Portable runtime role population")
    if set(value["roles"].values()) != {r["path"] for r in value["runtime_files"]}:
        raise ValueError("Unbound portable runtime role")
    verify_files(path.parent, value["runtime_files"], exact_folder="runtimes")
    python = Path(python or sys.executable).resolve(strict=True)
    observed = inspect_python(python, value["python_runtime"]["packages"])
    if observed != value["python_runtime"]:
        raise ValueError("Python runtime bytes changed; prepare a distinct installation")
    return dict(source_commit=source_commit, mujoco_python=str(python),
                **{role: str(within(path.parent, relative)) for role, relative in value["roles"].items()})


def evidence_destination(output, evidence_root, *, source_root):
    """An explicit durable destination must be outside the source and runtimes."""
    root = evidence_root.resolve()
    folder = output.resolve()
    if folder == root or not folder.is_relative_to(root):
        raise ValueError("Session must be a fresh child of the declared evidence root")
    if folder.is_relative_to(source_root.resolve()):
        raise ValueError("Evidence must not alter the checked source bundle")
    if root.name.lower() in {"tmp", ".tmp", "temp"} or any(p.lower() in {"tmp", ".tmp", "temp"} for p in root.parts):
        raise ValueError("Use durable evidence storage, not temporary storage")
    if folder.exists():
        raise ValueError("Evidence destination already exists")
    return folder


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--python-identity", required=True)
    args = parser.parse_args()
    print(json.dumps(python_identity(json.loads(args.python_identity))))
