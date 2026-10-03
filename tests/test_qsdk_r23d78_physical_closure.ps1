#requires -Version 7.0

[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$materializer = Join-Path $repoRoot "sdk/turning/materialize_r23d78_physical_closure.py"
$closurePath = Join-Path $repoRoot (
    "sdk/turning/" +
    "r23d78_production_route_three_engine_turning_validation_closure_v1.json"
)
$sourceCommit = "7b876726ba1471c6acd228181a877bd18bbb08a3"
$physicalEvidenceRoot = Join-Path (
    Split-Path -Parent $repoRoot
) "SporeSpore_Evidence/qsdk-r23d78-physical-20260826T174119Z-7b876726"

function Assert-R23D78Closure([bool]$Condition, [string]$Message) {
    if (-not $Condition) {
        throw "QSDK_R23D78_PHYSICAL_CLOSURE_INVALID: $Message"
    }
}

Assert-R23D78Closure (
    (git -C $repoRoot rev-parse --show-toplevel).Replace("/", "\") -ceq
        $repoRoot.TrimEnd("\", "/")
) "repository root changed"
Assert-R23D78Closure (
    (git -C $repoRoot remote get-url origin) -ceq
        "https://github.com/Slagathore/sporespore.git"
) "repository remote changed"
Assert-R23D78Closure (
    (git -C $repoRoot rev-parse (
        "${sourceCommit}:sdk/turning/" +
        "r23d78_production_route_three_engine_turning_evaluator.py"
    )) -cmatch "^[0-9a-f]{40}$"
) "pinned evaluator Git blob is unavailable"
Assert-R23D78Closure (Test-Path -LiteralPath $physicalEvidenceRoot -PathType Container) (
    "retained content-addressed physical evidence root missing"
)
Assert-R23D78Closure (Test-Path -LiteralPath $materializer -PathType Leaf) (
    "materializer missing"
)
Assert-R23D78Closure (Test-Path -LiteralPath $closurePath -PathType Leaf) (
    "closure missing"
)

$python = (Get-Command python -ErrorAction Stop).Source
$output = @(& $python -B $materializer --check 2>&1)
Assert-R23D78Closure ($LASTEXITCODE -eq 0) (
    "materializer audit failed: $($output -join [Environment]::NewLine)"
)
$marker = @($output | Where-Object {
    [string]$_ -clike "QSDK_R23D78_PHYSICAL_CLOSURE *"
})
Assert-R23D78Closure ($marker.Count -eq 1) "materializer marker missing"
$receipt = ($marker[0].Substring("QSDK_R23D78_PHYSICAL_CLOSURE ".Length) |
    ConvertFrom-Json -Depth 100)
Assert-R23D78Closure (
    [bool]$receipt.passed -and
    [bool]$receipt.check_only -and
    [int]$receipt.qualification_gates -eq 16 -and
    [int]$receipt.authorization_receipts -eq 9 -and
    [int]$receipt.worlds -eq 9 -and
    [int]$receipt.complete_horizons -eq 9 -and
    [int]$receipt.retained_trace_rows -eq 26928 -and
    [int]$receipt.engine_turning_pass_count -eq 3 -and
    [bool]$receipt.finite_three_engine_turning -and
    [bool]$receipt.q_sdk_r23_satisfied -and
    [string]$receipt.release_score -ceq "11/25" -and
    -not [bool]$receipt.cross_engine_equivalence -and
    -not [bool]$receipt.physical_acceptance_authority -and
    -not [bool]$receipt.release_authority
) "materializer receipt changed"

$closure = Get-Content -Raw -LiteralPath $closurePath |
    ConvertFrom-Json -Depth 100
Assert-R23D78Closure (
    [string]$closure.status -ceq (
        "closed_consumed_valid_complete_positive_exact_seed_23199_" +
        "three_engine_portable_turning"
    ) -and
    [string]$closure.official_result.classification -ceq (
        "valid_complete_positive_exact_seed_23199_three_engine_portable_turning"
    ) -and
    [bool]$closure.official_result.campaign_identity_consumed -and
    -not [bool]$closure.official_result.same_identity_rerun_allowed -and
    [bool]$closure.official_result.finite_three_engine_turning_positive -and
    [bool]$closure.official_result.q_sdk_r23_satisfied -and
    [string]$closure.official_result.release_score_after -ceq "11/25" -and
    [int]$closure.retained_physical_attempt.world_build_count -eq 9 -and
    [int]$closure.retained_physical_attempt.retained_trace_row_count -eq 26928 -and
    [int]$closure.source_authority.implementation_dependency_count -eq 227 -and
    [bool]$closure.claims.godot_jolt_frozen_turning_gates_passed -and
    [bool]$closure.claims.rapier_parry_frozen_turning_gates_passed -and
    [bool]$closure.claims.mujoco_frozen_turning_gates_passed -and
    [bool]$closure.claims.q_sdk_r23_satisfied -and
    -not [bool]$closure.claims.cross_engine_equivalence -and
    -not [bool]$closure.claims.prone_to_standing -and
    -not [bool]$closure.claims.release_authority
) "closure interpretation changed"

Write-Output (
    "QSDK_R23D78_PHYSICAL_CLOSURE_PASS " +
    ($receipt | ConvertTo-Json -Compress -Depth 100)
)
