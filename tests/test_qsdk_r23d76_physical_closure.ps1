#requires -Version 7.0

[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$materializer = Join-Path $repoRoot "sdk/turning/materialize_r23d76_physical_closure.py"
$closurePath = Join-Path $repoRoot (
    "sdk/turning/" +
    "r23d76_production_route_three_engine_turning_validation_closure_v1.json"
)

function Assert-R23D76Closure([bool]$Condition, [string]$Message) {
    if (-not $Condition) {
        throw "QSDK_R23D76_PHYSICAL_CLOSURE_INVALID: $Message"
    }
}

Assert-R23D76Closure (
    (git -C $repoRoot rev-parse --show-toplevel).Replace("/", "\") -ceq
        $repoRoot.TrimEnd("\", "/")
) "repository root changed"
Assert-R23D76Closure (
    (git -C $repoRoot remote get-url origin) -ceq
        "https://github.com/Slagathore/sporespore.git"
) "repository remote changed"
Assert-R23D76Closure (Test-Path -LiteralPath $materializer -PathType Leaf) (
    "materializer missing"
)
Assert-R23D76Closure (Test-Path -LiteralPath $closurePath -PathType Leaf) (
    "closure missing"
)

$python = (Get-Command python -ErrorAction Stop).Source
$output = @(& $python -B $materializer --check 2>&1)
Assert-R23D76Closure ($LASTEXITCODE -eq 0) (
    "materializer audit failed: $($output -join [Environment]::NewLine)"
)
$marker = @($output | Where-Object {
    [string]$_ -clike "QSDK_R23D76_PHYSICAL_CLOSURE *"
})
Assert-R23D76Closure ($marker.Count -eq 1) "materializer marker missing"
$receipt = ($marker[0].Substring("QSDK_R23D76_PHYSICAL_CLOSURE ".Length) |
    ConvertFrom-Json -Depth 100)
Assert-R23D76Closure (
    [bool]$receipt.passed -and
    [bool]$receipt.check_only -and
    [int]$receipt.qualification_gates -eq 17 -and
    [int]$receipt.authorization_receipts -eq 9 -and
    [int]$receipt.worlds -eq 9 -and
    [int]$receipt.complete_horizons -eq 9 -and
    [bool]$receipt.godot_jolt_turning_gates_passed -and
    [bool]$receipt.mujoco_turning_gates_passed -and
    [int]$receipt.rapier_cas_path_invalid_cells -eq 3 -and
    -not [bool]$receipt.finite_three_engine_turning -and
    [string]$receipt.release_score -ceq "10/25" -and
    -not [bool]$receipt.physical_acceptance_authority
) "materializer receipt changed"

$closure = Get-Content -Raw -LiteralPath $closurePath |
    ConvertFrom-Json -Depth 100
Assert-R23D76Closure (
    [string]$closure.status -ceq (
        "closed_consumed_invalid_complete_rapier_windows_extended_" +
        "cas_path_identity_failure"
    ) -and
    [string]$closure.official_result.classification -ceq (
        "invalid_or_incomplete_exact_seed_23197_three_engine_portable_turning"
    ) -and
    [bool]$closure.official_result.campaign_identity_consumed -and
    -not [bool]$closure.official_result.same_identity_rerun_allowed -and
    -not [bool]$closure.official_result.finite_three_engine_turning_positive -and
    [int]$closure.integration_finding.affected_cell_count -eq 3 -and
    [bool]$closure.integration_finding.deterministic_evidence_transport_invalidity -and
    -not [bool]$closure.integration_finding.physics_failure_established -and
    [bool]$closure.claims.godot_jolt_frozen_turning_gates_passed -and
    [bool]$closure.claims.mujoco_frozen_turning_gates_passed -and
    -not [bool]$closure.claims.q_sdk_r23_satisfied -and
    -not [bool]$closure.claims.release_authority
) "closure interpretation changed"

Write-Output (
    "QSDK_R23D76_PHYSICAL_CLOSURE_PASS " +
    ($receipt | ConvertTo-Json -Compress -Depth 100)
)
