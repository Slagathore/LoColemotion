$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = [System.IO.Path]::GetFullPath(
    (Split-Path -Parent $PSScriptRoot)
)
$closurePath = Join-Path (
    $repoRoot
) "sdk\rapier_c6_selected_policy_commissioning_r1_closure.json"
$expectedClosureRawSha256 = (
    "sha256:" +
    "0fe513b1af8fe386f4d9c13d7485f4bdfd37711d38a846a938fab11270b0e9fb"
)

function Assert-Exact {
    param([bool]$Condition, [string]$Message)
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
    (Test-Path -LiteralPath $closurePath -PathType Leaf) -and
    (Get-RawSha256 $closurePath) -ceq $expectedClosureRawSha256
) "Rapier C6-RAP-SP1-R1 closure is missing or changed"
$closure = (
    Get-Content -Raw -LiteralPath $closurePath |
        ConvertFrom-Json
)
foreach ($source in @(
    $closure.preregistration,
    $closure.predecessor_closure
)) {
    $path = Join-Path $repoRoot ([string]$source.path)
    Assert-Exact (
        (Test-Path -LiteralPath $path -PathType Leaf) -and
        (Get-RawSha256 $path) -ceq [string]$source.raw_sha256
    ) "Rapier C6-RAP-SP1-R1 source chain failed its hash audit"
}
foreach ($artifactName in @("report", "stdout", "stderr")) {
    $artifact = $closure.artifacts.$artifactName
    $path = [string]$artifact.path
    Assert-Exact (
        (Test-Path -LiteralPath $path -PathType Leaf) -and
        (Get-Item -LiteralPath $path).Length -eq [long]$artifact.bytes -and
        (Get-RawSha256 $path) -ceq [string]$artifact.sha256
    ) "Rapier C6-RAP-SP1-R1 $artifactName failed its artifact audit"
}
$report = (
    Get-Content -Raw -LiteralPath ([string]$closure.artifacts.report.path) |
        ConvertFrom-Json
)
Assert-Exact (
    [string]$closure.status -ceq
        "closed_negative_active_controller_host_dynamics" -and
    [string]$closure.source.commit -ceq
        "1597cfc379595e8767395083420506b191a9d081" -and
    -not [bool]$closure.result.ok -and
    [int]$closure.result.world_attempt_count -eq 1 -and
    [int]$closure.result.world_build_count -eq 1 -and
    [int]$closure.result.controller_semantic_step_count -eq 2992 -and
    [int]$closure.result.validated_portable_command_count -eq 23936 -and
    [int]$closure.result.native_motor_application_count -eq 23936 -and
    [int]$closure.result.controller_error_count -eq 0 -and
    [int]$closure.result.safe_no_actuation_count -eq 0 -and
    [int]$closure.result.nonfinite_observation_count -eq 0 -and
    [int]$closure.result.motor_impulse_limit_violation_count -eq 0 -and
    [bool]$closure.interpretation.adapter_transport_repair_confirmed -and
    -not [bool]$closure.interpretation.policy_generalization_claim_allowed -and
    -not [bool]$closure.disposition.technical_commissioning_accepted -and
    -not [bool]$closure.disposition.same_identity_rerun_allowed -and
    [bool]$closure.disposition.diagnostic_successor_allowed
) "Rapier C6-RAP-SP1-R1 result or disposition changed"
Assert-Exact (
    [string]$report.source_commit -ceq [string]$closure.source.commit -and
    -not [bool]$report.ok -and
    [int]$report.controller_semantic_step_count -eq 2992 -and
    [int]$report.validated_portable_command_count -eq 23936 -and
    [int]$report.native_motor_application_count -eq 23936 -and
    [int]$report.controller_error_count -eq 0 -and
    [int]$report.safe_no_actuation_count -eq 0 -and
    [int]$report.nonfinite_observation_count -eq 0 -and
    [int]$report.motor_impulse_limit_violation_count -eq 0
) "Rapier C6-RAP-SP1-R1 report no longer reconstructs the closure"
$reportFailures = @($report.gate_failures | ForEach-Object { [string]$_ })
$closureFailures = @(
    $closure.result.gate_failures |
        ForEach-Object { [string]$_ }
)
Assert-Exact (
    $reportFailures.Count -eq 19 -and
    $closureFailures.Count -eq 19 -and
    @(Compare-Object $reportFailures $closureFailures).Count -eq 0
) "Rapier C6-RAP-SP1-R1 gate failure inventory changed"
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
) "Rapier C6-RAP-SP1-R1 negative closure overclaims authority"

Write-Host (
    "Rapier C6-RAP-SP1-R1 closure passed: active controller integrity, " +
    "3 retained artifacts, 19 physical gate failures, and no overclaim."
)
