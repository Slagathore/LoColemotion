"""Zero-world source and mutation audit for the shared R54 launcher repair."""

from __future__ import annotations

import json
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
DECLARATION = ROOT / (
    "sdk/recovery/r24d54_rapier_integration_authority_routing_repair_v1.json"
)
RUNNER = ROOT / "sdk/run_qsdk_r24d48_rapier_recovery_energy_v2.ps1"
CONTRACT = ROOT / (
    "sdk/recovery/r24d54_rapier_recovery_energy_v3_behavior_contract_v1.json"
)
BASE_CLOSURE = ROOT / (
    "sdk/recovery/"
    "r24d54_rapier_recovery_energy_v3_zero_world_qualification_closure_v1.json"
)
RUNNER_RELATIVE = "sdk/run_qsdk_r24d48_rapier_recovery_energy_v2.ps1"


class AuditError(RuntimeError):
    """Raised when a deterministic launcher-repair assertion fails."""


def require(condition: bool, code: str) -> None:
    if not condition:
        raise AuditError(code)


def exact(actual: object, expected: object, code: str) -> None:
    require(actual == expected, f"{code}:{actual!r}!={expected!r}")


def sha256(raw: bytes) -> str:
    import hashlib

    return "sha256:" + hashlib.sha256(raw).hexdigest()


def brace_block(text: str, marker: str) -> tuple[int, int, str]:
    start = text.find(marker)
    require(start >= 0, f"MARKER:{marker}")
    opening = text.find("{", start)
    require(opening >= 0, f"OPENING_BRACE:{marker}")
    depth = 0
    for index in range(opening, len(text)):
        character = text[index]
        if character == "{":
            depth += 1
        elif character == "}":
            depth -= 1
            if depth == 0:
                return start, index + 1, text[start : index + 1]
    raise AuditError(f"UNCLOSED_BLOCK:{marker}")


def verify_routing_source(text: str) -> None:
    development_marker = 'if ($Mode -ceq "Development") {'
    integration_marker = 'if (-not $developmentRequiresPriorGhost) {'
    ghost_guard = 'if ($null -ne $ghostAuthority) {'
    ghost_path = "$ghostResultPath = Join-Path"
    fallback = 'Assert-R24D48 ($null -ne $developmentIntegrationAuthority) ('
    repair_schema = (
        '"sporespore_qsdk_r24d54_rapier_integration_authority_" +\n'
        '        "routing_repair_closure_v1"'
    )

    exact(text.count(development_marker), 1, "DEVELOPMENT_BRANCH_COUNT")
    exact(text.count(integration_marker), 1, "INTEGRATION_BRANCH_COUNT")
    exact(text.count(ghost_guard), 1, "GHOST_GUARD_COUNT")
    exact(text.count(ghost_path), 1, "GHOST_RESULT_PATH_COUNT")
    exact(text.count(fallback), 1, "INTEGRATION_FALLBACK_COUNT")
    exact(text.count(repair_schema), 1, "REPAIR_SCHEMA_COUNT")

    development_start, development_end, development = brace_block(
        text, development_marker
    )
    integration_start, integration_end, integration = brace_block(
        development, integration_marker
    )
    guard_start, guard_end, guard = brace_block(development, ghost_guard)
    require(development_start < development_end, "DEVELOPMENT_BLOCK")
    require(integration_start < integration_end < guard_start, "INTEGRATION_BLOCK")
    require(ghost_path in guard, "GHOST_RESULT_OUTSIDE_NULL_GUARD")
    require("GHOST_RESULT_BINDING" in guard, "GHOST_BINDING_OUTSIDE_NULL_GUARD")
    fallback_position = development.find(fallback)
    require(
        fallback_position > guard_end
        and "else {" in development[guard_end : fallback_position],
        "INTEGRATION_FALLBACK_NOT_GUARD_ELSE",
    )
    require(
        '$stageAuthorityKind -ceq "r24d54_launcher_repair"' in integration,
        "REPAIR_AUTHORITY_NOT_ALLOWED_ON_INTEGRATION_ROUTE",
    )
    require(
        'Assert-R24D48 $false "STAGE_AUTHORITY_SCHEMA"' in text,
        "UNKNOWN_STAGE_AUTHORITY_NOT_REFUSED",
    )
    require(
        '$repairChangedPaths.Count -eq 1' in text
        and '$repairChangedPaths[0] -ceq $exclusions[0]' in text
        and '"STAGE_AUTHORITY_REPAIR_SCOPE"' in text,
        "REPAIR_SCOPE_NOT_EXACT",
    )
    require(
        '$exclusions.Count -eq 1' in text
        and '$exclusions[0] -ceq [string]$runner.script_path' in text,
        "REPAIR_EXCLUSION_NOT_SINGLE_RUNNER",
    )
    require(
        '& $git -C $repoRoot diff --quiet $repairSource HEAD -- @exclusions' in text
        and '"STAGE_AUTHORITY_REPAIR_DRIFT"' in text,
        "REPAIRED_RUNNER_DRIFT_NOT_REFUSED",
    )

    # Every later reference either sits in the explicit non-null guard or in a
    # receipt expression whose preceding branch tests for null first.
    occurrences = []
    offset = 0
    while True:
        index = text.find("$ghostAuthority.path", offset)
        if index < 0:
            break
        occurrences.append(index)
        offset = index + 1
    exact(len(occurrences), 3, "GHOST_PATH_REFERENCE_COUNT")
    absolute_guard_start = development_start + guard_start
    absolute_guard_end = development_start + guard_end
    require(
        absolute_guard_start <= occurrences[0] < absolute_guard_end,
        "PRIMARY_GHOST_PATH_NOT_GUARDED",
    )
    for index in occurrences[1:]:
        prefix = text[max(0, index - 260) : index]
        require(
            "$null -eq $ghostAuthority" in prefix,
            "RECEIPT_GHOST_PATH_NOT_NULL_PARTITIONED",
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
            "sporespore_qsdk_r24d54_rapier_integration_authority_routing_repair_v1",
            "QSDK-R24D54",
            "R24D54-L1",
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
            failure["physics_state_modified"],
            failure["physical_question_opened"],
            failure["physical_attempt_consumed"],
            failure["behavior_result_observed"],
        ),
        (
            "e26d40ab00540b59e7e801db82ed2cfc456d5e54",
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
            False,
            False,
        ),
        "OBSERVED_FAILURE",
    )
    exact(
        declaration["controlled_change"]["changed_paths"],
        [RUNNER_RELATIVE],
        "CHANGED_PATHS",
    )
    exact(declaration["controlled_change"]["changed_path_count"], 1, "CHANGE_COUNT")
    exact(
        sha256(BASE_CLOSURE.read_bytes()),
        declaration["base_qualification"]["closure_raw_sha256"],
        "BASE_CLOSURE",
    )

    code_paths = contract["physical_runner"]["qualification_source_code_paths"]
    exact(len(code_paths), 23, "QUALIFIED_SOURCE_COUNT")
    exact(
        declaration["prospective_closure"]["authority_only_qualified_path_exclusions"],
        [RUNNER_RELATIVE],
        "EXCLUSIONS",
    )
    exact(
        declaration["prospective_closure"]["qualified_unchanged_source_paths"],
        [path for path in code_paths if path != RUNNER_RELATIVE],
        "UNCHANGED_SOURCE_PATHS",
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
    verify_routing_source(source)
    mutations = {
        "unguarded_ghost_validation": source.replace(
            'if ($null -ne $ghostAuthority) {', "if ($true) {", 1
        ),
        "inverted_ghost_guard": source.replace(
            'if ($null -ne $ghostAuthority) {',
            'if ($null -eq $ghostAuthority) {',
            1,
        ),
        "missing_integration_fallback": source.replace(
            'Assert-R24D48 ($null -ne $developmentIntegrationAuthority) (',
            'Assert-R24D48 $true (',
            1,
        ),
        "expanded_repair_exclusion": source.replace(
            "$exclusions.Count -eq 1", "$exclusions.Count -eq 2", 1
        ),
        "missing_repair_scope_refusal": source.replace(
            '"STAGE_AUTHORITY_REPAIR_SCOPE"',
            '"STAGE_AUTHORITY_REPAIR_SCOPE_REMOVED"',
            1,
        ),
    }
    exact(len(mutations), 5, "MUTATION_COUNT")
    for mutation_id, mutation in mutations.items():
        rejected = False
        try:
            verify_routing_source(mutation)
        except AuditError:
            rejected = True
        require(rejected, f"MUTATION_ACCEPTED:{mutation_id}")

    print(
        "QSDK_R24D54_RAPIER_INTEGRATION_AUTHORITY_ROUTING_REPAIR_PASS "
        "controls=8/8 mutations=5/5 changed_paths=1 models=0 worlds=0 "
        "solver_steps=0 physical=false"
    )


if __name__ == "__main__":
    try:
        audit()
    except (AuditError, OSError, KeyError, TypeError, ValueError) as error:
        print(
            f"QSDK_R24D54_RAPIER_INTEGRATION_AUTHORITY_ROUTING_REPAIR_FAIL {error}",
            file=sys.stderr,
        )
        raise SystemExit(1) from error
