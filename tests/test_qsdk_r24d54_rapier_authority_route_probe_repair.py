"""Zero-world source audit for the R24D54-L2 production-route probe repair."""

from __future__ import annotations

import json
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
DECLARATION = ROOT / (
    "sdk/recovery/r24d54_rapier_authority_route_probe_repair_v1.json"
)
RUNNER = ROOT / "sdk/run_qsdk_r24d48_rapier_recovery_energy_v2.ps1"
CONTRACT = ROOT / (
    "sdk/recovery/r24d54_rapier_recovery_energy_v3_behavior_contract_v1.json"
)
L1_CLOSURE = ROOT / (
    "sdk/recovery/r24d54_rapier_integration_authority_routing_repair_closure_v1.json"
)
RUNNER_RELATIVE = "sdk/run_qsdk_r24d48_rapier_recovery_energy_v2.ps1"


class AuditError(RuntimeError):
    """Raised when a production-route probe source assertion fails."""


def require(condition: bool, code: str) -> None:
    if not condition:
        raise AuditError(code)


def exact(actual: object, expected: object, code: str) -> None:
    require(actual == expected, f"{code}:{actual!r}!={expected!r}")


def sha256(raw: bytes) -> str:
    import hashlib

    return "sha256:" + hashlib.sha256(raw).hexdigest()


def verify_probe_source(source: str) -> None:
    required_once = (
        "[switch]$AuthorityRouteProbe",
        "[string[]]$repairChangedPaths = @(",
        'if ($AuthorityRouteProbe) {',
        '"AUTHORITY_ROUTE_PROBE_SCOPE"',
        '"AUTHORITY_ROUTE_PROBE_ALREADY_RETAINED"',
        'Enter-SporeSporeLocomotionOperationLock -Role "conformance"',
        '"sporespore_qsdk_r24d54_rapier_authority_route_probe_receipt_v1"',
        '"QSDK_R24D54_AUTHORITY_ROUTE_PROBE_PASS "',
    )
    for token in required_once:
        exact(source.count(token), 1, f"TOKEN:{token}")
    required_counts = {
        '"sporespore_qsdk_r24d54_rapier_authority_route_probe_repair_v1"': 3,
        '"sporespore_qsdk_r24d54_rapier_authority_route_probe_repair_closure_v1"': 2,
    }
    for token, count in required_counts.items():
        exact(source.count(token), count, f"TOKEN:{token}")
    probe_start = source.find('if ($AuthorityRouteProbe) {')
    require(probe_start >= 0, "PROBE_BLOCK_MISSING")
    exit_position = source.find("exit 0", probe_start)
    require(exit_position >= 0, "PROBE_EXIT_MISSING")
    probe_source = source[probe_start:exit_position]
    require(
        "$Mode -ceq \"Development\" -and" in probe_source
        and '$stageAuthorityKind -ceq "r24d54_launcher_repair" -and'
        in probe_source
        and "$stageAuthoritySchema -ceq" in probe_source
        and '"sporespore_qsdk_r24d54_rapier_authority_route_probe_repair_v1"'
        in probe_source
        and "$null -ne $developmentIntegrationAuthority -and" in probe_source
        and "$null -eq $ghostAuthority" in probe_source,
        "PROBE_AUTHORITY_PARTITION",
    )
    require(
        "$priorProbeRoots.Count -eq 0" in probe_source,
        "PROBE_SINGLE_ATTEMPT",
    )
    require(
        "physical_attempt_record_created = $false" in probe_source
        and "model_construction_count = 0" in probe_source
        and "world_attempt_count = 0" in probe_source
        and "world_build_count = 0" in probe_source
        and "solver_step_count = 0" in probe_source
        and "physics_state_modified = $false" in probe_source
        and "physical_question_opened = $false" in probe_source
        and "physical_attempt_consumed = $false" in probe_source,
        "PROBE_ZERO_PHYSICS_RECEIPT",
    )
    main_lock = source.find(". $lockScript", probe_start)
    physical_lock = source.find(
        "Enter-SporeSporeLocomotionOperationLock -Role ([string]$runner.operation_lock_role)",
        probe_start,
    )
    require(
        probe_start < main_lock < exit_position < physical_lock,
        "PROBE_DOES_NOT_EXIT_BEFORE_PHYSICAL_LOCK",
    )
    require(
        "$repairChangedPaths = if ([string]::IsNullOrEmpty" not in source,
        "SCALAR_ARRAY_REGRESSION",
    )


def audit() -> None:
    declaration = json.loads(DECLARATION.read_text(encoding="utf-8"))
    contract = json.loads(CONTRACT.read_text(encoding="utf-8"))
    exact(
        (
            declaration["schema_version"],
            declaration["gate_id"],
            declaration["stage_id"],
            declaration["question_class"],
        ),
        (
            "sporespore_qsdk_r24d54_rapier_authority_route_probe_repair_v1",
            "QSDK-R24D54",
            "R24D54-L2",
            "development_launch_authority_repair",
        ),
        "DECLARATION_IDENTITY",
    )
    for key in (
        "physical_question_declared",
        "superiority_question_declared",
        "equivalence_or_non_inferiority_question_declared",
        "population_inference_declared",
    ):
        exact(declaration[key], False, f"DECLARATION_{key.upper()}")
    failure = declaration["observed_failure"]
    exact(
        (
            failure["source_commit"],
            failure["failure_boundary"],
            failure["operation_lock_acquired"],
            failure["evidence_root_created"],
            failure["physical_attempt_record_created"],
            failure["model_construction_count"],
            failure["world_attempt_count"],
            failure["world_build_count"],
            failure["solver_step_count"],
            failure["physical_question_opened"],
            failure["physical_attempt_consumed"],
        ),
        (
            "67fd8743b7f78eee5f33f529a078a64959fdf082",
            "before_operation_lock_and_before_evidence_root_creation",
            False,
            False,
            False,
            0,
            0,
            0,
            0,
            False,
            False,
        ),
        "OBSERVED_FAILURE",
    )
    exact(
        sha256(L1_CLOSURE.read_bytes()),
        declaration["predecessor_launcher_repair"]["closure_raw_sha256"],
        "L1_CLOSURE",
    )
    code_paths = contract["physical_runner"]["qualification_source_code_paths"]
    exact(len(code_paths), 23, "QUALIFIED_SOURCE_COUNT")
    exact(
        declaration["authority_only_qualified_path_exclusions"],
        [RUNNER_RELATIVE],
        "EXCLUSIONS",
    )
    exact(
        declaration["qualified_unchanged_source_paths"],
        [path for path in code_paths if path != RUNNER_RELATIVE],
        "UNCHANGED_PATHS",
    )
    parse = subprocess.run(
        [
            "pwsh",
            "-NoProfile",
            "-Command",
            (
                "$tokens=$null; $errors=$null; "
                "[System.Management.Automation.Language.Parser]::ParseFile("
                f"'{RUNNER.as_posix()}', [ref]$tokens, [ref]$errors) > $null; "
                "if ($errors.Count -ne 0) { $errors | ForEach-Object { $_.Message }; exit 1 }"
            ),
        ],
        cwd=ROOT,
        capture_output=True,
        text=True,
        check=False,
    )
    require(parse.returncode == 0, f"POWERSHELL_PARSE:{parse.stdout}:{parse.stderr}")
    source = RUNNER.read_text(encoding="utf-8")
    verify_probe_source(source)
    mutations = {
        "scalar_changed_path": source.replace(
            "[string[]]$repairChangedPaths = @(", "$repairChangedPaths = if (", 1
        ),
        "missing_probe_scope": source.replace(
            '"AUTHORITY_ROUTE_PROBE_SCOPE"', '"AUTHORITY_ROUTE_PROBE_SCOPE_REMOVED"', 1
        ),
        "ghost_allowed": source.replace(
            "$null -eq $ghostAuthority", "$null -ne $ghostAuthority", 1
        ),
        "missing_single_attempt": source.replace(
            "$priorProbeRoots.Count -eq 0", "$priorProbeRoots.Count -ge 0", 1
        ),
        "physical_question_opened": source.replace(
            "physical_question_opened = $false",
            "physical_question_opened = $true",
            1,
        ),
        "missing_prephysical_exit": source.replace("    exit 0\n}\n\n. $lockScript", "}\n\n. $lockScript", 1),
    }
    exact(len(mutations), 6, "MUTATION_COUNT")
    for mutation_id, mutation in mutations.items():
        rejected = False
        try:
            verify_probe_source(mutation)
        except AuditError:
            rejected = True
        require(rejected, f"MUTATION_ACCEPTED:{mutation_id}")
    print(
        "QSDK_R24D54_RAPIER_AUTHORITY_ROUTE_PROBE_REPAIR_PASS "
        "controls=9/9 mutations=6/6 changed_paths=1 models=0 worlds=0 "
        "solver_steps=0 physical=false"
    )


if __name__ == "__main__":
    try:
        audit()
    except (AuditError, OSError, KeyError, TypeError, ValueError) as error:
        print(
            f"QSDK_R24D54_RAPIER_AUTHORITY_ROUTE_PROBE_REPAIR_FAIL {error}",
            file=sys.stderr,
        )
        raise SystemExit(1) from error
