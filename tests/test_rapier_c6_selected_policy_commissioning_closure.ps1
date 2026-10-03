$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = [System.IO.Path]::GetFullPath(
    (Split-Path -Parent $PSScriptRoot)
)
$closurePath = Join-Path (
    $repoRoot
) "sdk\rapier_c6_selected_policy_commissioning_closure.json"
$expectedClosureRawSha256 = (
    "sha256:" +
    "b7f461bcadff96069e14b85357e58b97c61c555903792b99c37116e17ee31557"
)

function Assert-Exact {
    param(
        [bool]$Condition,
        [string]$Message
    )
    if (-not $Condition) {
        throw $Message
    }
}

function Get-RawSha256 {
    param([Parameter(Mandatory)][string]$Path)
    return "sha256:" + (
        Get-FileHash -Algorithm SHA256 -LiteralPath $Path
    ).Hash.ToLowerInvariant()
}

Assert-Exact (
    Test-Path -LiteralPath $closurePath -PathType Leaf
) "Rapier C6-RAP-SP1 closure is missing"
Assert-Exact (
    (Get-RawSha256 $closurePath) -ceq $expectedClosureRawSha256
) "Rapier C6-RAP-SP1 closure bytes changed"
$closure = (
    Get-Content -Raw -LiteralPath $closurePath |
        ConvertFrom-Json
)
$preregistrationPath = Join-Path (
    $repoRoot
) ([string]$closure.preregistration.path)
Assert-Exact (
    (Test-Path -LiteralPath $preregistrationPath -PathType Leaf) -and
    (Get-RawSha256 $preregistrationPath) -ceq
        [string]$closure.preregistration.raw_sha256
) "Rapier C6-RAP-SP1 preregistration failed its closure hash audit"

foreach ($artifactName in @("report", "stdout", "stderr")) {
    $artifact = $closure.artifacts.$artifactName
    $artifactPath = [string]$artifact.path
    Assert-Exact (
        (Test-Path -LiteralPath $artifactPath -PathType Leaf) -and
        (Get-Item -LiteralPath $artifactPath).Length -eq [long]$artifact.bytes -and
        (Get-RawSha256 $artifactPath) -ceq [string]$artifact.sha256
    ) "Rapier C6-RAP-SP1 $artifactName failed its retained-artifact audit"
}

$report = (
    Get-Content -Raw -LiteralPath ([string]$closure.artifacts.report.path) |
        ConvertFrom-Json
)
Assert-Exact (
    [string]$closure.schema_version -ceq
        "sporespore_rapier_c6_selected_policy_commissioning_closure_v1" -and
    [string]$closure.status -ceq "closed_negative_adapter_transport" -and
    [string]$closure.source.commit -ceq
        "1df9c703721781502f3ea15eef9ee181fc341456" -and
    -not [bool]$closure.result.ok -and
    [int]$closure.result.world_attempt_count -eq 1 -and
    [int]$closure.result.world_build_count -eq 1 -and
    [int]$closure.result.controller_semantic_step_count -eq 2992 -and
    [int]$closure.result.controller_error_count -eq 2991 -and
    [int]$closure.result.safe_no_actuation_count -eq 2991 -and
    [int]$closure.result.validated_portable_command_count -eq 23936 -and
    [int]$closure.result.native_motor_application_count -eq 23936 -and
    [int]$closure.result.motor_impulse_limit_violation_count -eq 0 -and
    -not [bool]$closure.diagnosis.locomotion_metrics_interpretable_as_policy_performance -and
    -not [bool]$closure.diagnosis.same_identity_rerun_allowed -and
    -not [bool]$closure.disposition.technical_commissioning_accepted -and
    [bool]$closure.disposition.successor_allowed
) "Rapier C6-RAP-SP1 closure identity, result, or disposition changed"
Assert-Exact (
    [string]$report.source_commit -ceq [string]$closure.source.commit -and
    -not [bool]$report.ok -and
    [int]$report.world_attempt_count -eq [int]$closure.result.world_attempt_count -and
    [int]$report.world_build_count -eq [int]$closure.result.world_build_count -and
    [int]$report.controller_semantic_step_count -eq
        [int]$closure.result.controller_semantic_step_count -and
    [int]$report.controller_error_count -eq
        [int]$closure.result.controller_error_count -and
    [int]$report.safe_no_actuation_count -eq
        [int]$closure.result.safe_no_actuation_count -and
    [int]$report.validated_portable_command_count -eq
        [int]$closure.result.validated_portable_command_count -and
    [int]$report.native_motor_application_count -eq
        [int]$closure.result.native_motor_application_count -and
    [int]$report.motor_impulse_limit_violation_count -eq
        [int]$closure.result.motor_impulse_limit_violation_count
) "Rapier C6-RAP-SP1 report no longer reconstructs the closure result"

$reportFailures = @($report.gate_failures | ForEach-Object { [string]$_ })
$closureFailures = @(
    $closure.result.gate_failures |
        ForEach-Object { [string]$_ }
)
Assert-Exact (
    $reportFailures.Count -eq 22 -and
    $closureFailures.Count -eq $reportFailures.Count -and
    @(Compare-Object $reportFailures $closureFailures).Count -eq 0
) "Rapier C6-RAP-SP1 gate failure inventory changed"
Assert-Exact (
    -not [bool]$closure.claim_boundary.independent_validation -and
    -not [bool]$closure.claim_boundary.arbitrary_quadruped_coverage -and
    -not [bool]$closure.claim_boundary.continuous_full_volume_coverage -and
    -not [bool]$closure.claim_boundary.material_robustness -and
    -not [bool]$closure.claim_boundary.cross_engine_c6 -and
    -not [bool]$closure.claim_boundary.locomotion_acceptance -and
    -not [bool]$closure.claim_boundary.release_authorized -and
    -not [bool]$closure.claim_boundary.physical_acceptance_authority -and
    -not [bool]$closure.claim_boundary.completed_engine_neutral_sdk
) "Rapier C6-RAP-SP1 negative closure overclaims authority"

Write-Host (
    "Rapier C6-RAP-SP1 negative closure passed: 3 retained artifacts, " +
    "22 exact gate failures, and all scientific/release claims remain false."
)
