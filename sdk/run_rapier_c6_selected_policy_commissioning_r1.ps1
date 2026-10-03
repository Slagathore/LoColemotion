[CmdletBinding()]
param(
    [switch]$PreflightOnly,
    [string]$OutputRoot = ""
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$sdkRoot = [System.IO.Path]::GetFullPath($PSScriptRoot)
$repoRoot = [System.IO.Path]::GetFullPath((Split-Path -Parent $sdkRoot))
$evidenceRoot = [System.IO.Path]::GetFullPath(
    (Join-Path (Split-Path -Parent $repoRoot) "SporeSpore_Evidence")
)
$preregistrationPath = Join-Path (
    $sdkRoot
) "rapier_c6_selected_policy_commissioning_r1_preregistration.json"
$closurePath = Join-Path (
    $sdkRoot
) "rapier_c6_selected_policy_commissioning_r1_closure.json"
$predecessorClosurePath = Join-Path (
    $sdkRoot
) "rapier_c6_selected_policy_commissioning_closure.json"
$hostClosurePath = Join-Path (
    $sdkRoot
) "cross_engine_c6_host_characterization_r2_closure.json"
$selectedPolicyPath = Join-Path $sdkRoot "balanced_wave_selected_policy.json"

$expectedPreregistrationRawSha256 = (
    "sha256:" +
    "3102a8dddb8f6c7236735e2cdc6b403763d000a6b1518d55c201a7627e00a37f"
)
$expectedPredecessorClosureRawSha256 = (
    "sha256:" +
    "b7f461bcadff96069e14b85357e58b97c61c555903792b99c37116e17ee31557"
)
$expectedPredecessorReportSha256 = (
    "sha256:" +
    "05d6a300364d2a1a1f05b3007bbc00b94db7f4f4079da785558d72cb19ec39cd"
)
$expectedHostClosureRawSha256 = (
    "sha256:" +
    "a7b1b3c172b98780f574cec9dbb18bebda35429ece5105a0385ecb7d67d6ddd9"
)
$expectedHostReportSha256 = (
    "sha256:" +
    "7ec18fbe8d6cb1efd3dcbbfce86f400e1cfed6c284df3fcf9183030e856a95e0"
)
$expectedSelectedPolicyRawSha256 = (
    "sha256:" +
    "ba9498aa8b709703a578f52e496079a87d3bfd11fc60095a6b5100f8722b4bb9"
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

function Invoke-LoggedProcess {
    param(
        [Parameter(Mandatory)][string]$FilePath,
        [Parameter(Mandatory)][string[]]$ArgumentList,
        [Parameter(Mandatory)][string]$WorkingDirectory,
        [Parameter(Mandatory)][string]$StdoutPath,
        [Parameter(Mandatory)][string]$StderrPath
    )
    Assert-Exact (
        -not (Test-Path -LiteralPath $StdoutPath) -and
        -not (Test-Path -LiteralPath $StderrPath)
    ) "Refusing to overwrite a C6-RAP-SP1-R1 supervisor artifact"
    $process = Start-Process `
        -FilePath $FilePath `
        -ArgumentList $ArgumentList `
        -WorkingDirectory $WorkingDirectory `
        -WindowStyle Hidden `
        -Wait `
        -PassThru `
        -RedirectStandardOutput $StdoutPath `
        -RedirectStandardError $StderrPath
    return $process.ExitCode
}

foreach ($requiredPath in @(
    $preregistrationPath,
    $predecessorClosurePath,
    $hostClosurePath,
    $selectedPolicyPath
)) {
    Assert-Exact (
        Test-Path -LiteralPath $requiredPath -PathType Leaf
    ) "Required C6-RAP-SP1-R1 source is missing: $requiredPath"
}
Assert-Exact (
    (Get-RawSha256 $preregistrationPath) -ceq
        $expectedPreregistrationRawSha256 -and
    (Get-RawSha256 $predecessorClosurePath) -ceq
        $expectedPredecessorClosureRawSha256 -and
    (Get-RawSha256 $hostClosurePath) -ceq
        $expectedHostClosureRawSha256 -and
    (Get-RawSha256 $selectedPolicyPath) -ceq
        $expectedSelectedPolicyRawSha256
) "A hash-pinned C6-RAP-SP1-R1 source changed"

$preregistration = (
    Get-Content -Raw -LiteralPath $preregistrationPath |
        ConvertFrom-Json
)
$predecessorClosure = (
    Get-Content -Raw -LiteralPath $predecessorClosurePath |
        ConvertFrom-Json
)
$hostClosure = (
    Get-Content -Raw -LiteralPath $hostClosurePath |
        ConvertFrom-Json
)
$selectedPolicy = (
    Get-Content -Raw -LiteralPath $selectedPolicyPath |
        ConvertFrom-Json
)
$predecessorReportPath = [string]$predecessorClosure.artifacts.report.path
$hostReportPath = [string]$hostClosure.artifacts.rapier_report.path

Assert-Exact (
    [string]$preregistration.schema_version -ceq
        "sporespore_rapier_c6_selected_policy_commissioning_r1_preregistration_v1" -and
    [string]$preregistration.campaign_id -ceq
        "C6-RAPIER-SELECTED-POLICY-COMMISSIONING-R1" -and
    [string]$preregistration.gate_id -ceq "C6-RAP-SP1-R1" -and
    [string]$preregistration.status -ceq
        "frozen_before_first_c6_rap_sp1_r1_physics_world" -and
    [int]$preregistration.scope.world_count -eq 1 -and
    -not [bool]$preregistration.allowed_changes_from_predecessor.physics_or_policy_changes_allowed -and
    -not [bool]$preregistration.allowed_changes_from_predecessor.geometry_mass_inertia_changes_allowed -and
    -not [bool]$preregistration.allowed_changes_from_predecessor.motor_gain_or_limit_changes_allowed -and
    -not [bool]$preregistration.allowed_changes_from_predecessor.clock_or_threshold_changes_allowed -and
    [bool]$preregistration.preflight_contract.nonidentity_host_quaternion_conversion_must_pass_portable_unit_norm_validation -and
    [bool]$preregistration.preflight_contract.intentional_null_must_not_increment_numeric_nonfinite_count
) "C6-RAP-SP1-R1 preregistration identity or constrained delta changed"
Assert-Exact (
    [string]$predecessorClosure.status -ceq
        "closed_negative_adapter_transport" -and
    -not [bool]$predecessorClosure.diagnosis.same_identity_rerun_allowed -and
    [string]$predecessorClosure.artifacts.report.sha256 -ceq
        $expectedPredecessorReportSha256 -and
    (Test-Path -LiteralPath $predecessorReportPath -PathType Leaf) -and
    (Get-RawSha256 $predecessorReportPath) -ceq
        $expectedPredecessorReportSha256
) "C6-RAP-SP1-R1 predecessor closure or retained report failed its audit"
Assert-Exact (
    [string]$hostClosure.status -ceq
        "closed_pass_host_characterization_only" -and
    [bool]$hostClosure.rapier_result.ok -and
    [string]$hostClosure.artifacts.rapier_report.sha256 -ceq
        $expectedHostReportSha256 -and
    (Test-Path -LiteralPath $hostReportPath -PathType Leaf) -and
    (Get-RawSha256 $hostReportPath) -ceq $expectedHostReportSha256
) "C6-RAP-SP1-R1 Rapier host-characterization input failed its audit"
Assert-Exact (
    [string]$selectedPolicy.selected_candidate_id -ceq "BW5R-B" -and
    [string]$selectedPolicy.selected_policy_id -ceq
        "sporespore_balanced_wave_bw5r_b_v1" -and
    [string]$selectedPolicy.selected_candidate_policy_digest -ceq
        "sha256:9dfade277ff0dd28f47aa807447c51a24363ce9d10671930ae01b61273d5f59f"
) "C6-RAP-SP1-R1 selected portable policy changed"

foreach ($source in $preregistration.method_sources.local_research_inputs) {
    $sourcePath = [System.IO.Path]::GetFullPath(
        (Join-Path $repoRoot ([string]$source.path))
    )
    Assert-Exact (
        (Test-Path -LiteralPath $sourcePath -PathType Leaf) -and
        (Get-RawSha256 $sourcePath) -ceq [string]$source.sha256
    ) "A frozen C6-RAP-SP1-R1 research source is missing or changed: $sourcePath"
}

# This zero-world path proves the complete synthetic gate, failure canary,
# f32-to-f64 nonidentity quaternion normalization, and numeric-only finiteness
# accounting before the successor is allowed to construct a Rapier world.
Push-Location -LiteralPath $sdkRoot
try {
    & cargo run `
        --package sporespore-rapier-adapter `
        --bin locomotion_r1 `
        --offline `
        -- `
        --preflight-only
    Assert-Exact (
        $LASTEXITCODE -eq 0
    ) "Rapier C6-RAP-SP1-R1 zero-world preflight failed"
} finally {
    Pop-Location
}

if ($PreflightOnly) {
    Write-Host (
        "C6-RAP-SP1-R1 zero-world preflight passed: synthetic gate, " +
        "failure canary, nonidentity quaternion normalization, and " +
        "numeric-only finiteness accounting are green."
    )
    return
}

Assert-Exact (
    -not (Test-Path -LiteralPath $closurePath -PathType Leaf)
) (
    "C6-RAP-SP1-R1 is closed and may not open another physics world; audit " +
    "sdk/rapier_c6_selected_policy_commissioning_r1_closure.json instead"
)
$sourceCommit = (& git -C $repoRoot rev-parse HEAD).Trim()
$originMainCommit = (& git -C $repoRoot rev-parse origin/main).Trim()
$sourceStatus = @(& git -C $repoRoot status --porcelain=v1)
Assert-Exact (
    $LASTEXITCODE -eq 0 -and
    $sourceCommit -cmatch "^[0-9a-f]{40}$" -and
    $sourceCommit -ceq $originMainCommit
) "C6-RAP-SP1-R1 physical execution requires HEAD == origin/main"
Assert-Exact (
    $sourceStatus.Count -eq 0
) "C6-RAP-SP1-R1 physical execution requires a clean worktree"

$shortCommit = $sourceCommit.Substring(0, 7)
if ([string]::IsNullOrWhiteSpace($OutputRoot)) {
    $OutputRoot = Join-Path (
        $evidenceRoot
    ) "c6-rapier-selected-policy-r1-$shortCommit"
}
$resolvedOutputRoot = [System.IO.Path]::GetFullPath($OutputRoot)
$evidencePrefix = $evidenceRoot.TrimEnd(
    [System.IO.Path]::DirectorySeparatorChar,
    [System.IO.Path]::AltDirectorySeparatorChar
) + [System.IO.Path]::DirectorySeparatorChar
Assert-Exact (
    $resolvedOutputRoot.StartsWith(
        $evidencePrefix,
        [StringComparison]::OrdinalIgnoreCase
    )
) "C6-RAP-SP1-R1 evidence must live beneath SporeSpore_Evidence"
$reportPath = Join-Path $resolvedOutputRoot "report.json"
$stdoutPath = Join-Path $resolvedOutputRoot "stdout.log"
$stderrPath = Join-Path $resolvedOutputRoot "stderr.log"
Assert-Exact (
    -not (Test-Path -LiteralPath $reportPath) -and
    -not (Test-Path -LiteralPath $stdoutPath) -and
    -not (Test-Path -LiteralPath $stderrPath)
) "Refusing to overwrite existing C6-RAP-SP1-R1 evidence"
[void][System.IO.Directory]::CreateDirectory($resolvedOutputRoot)

$cargo = (Get-Command cargo -ErrorAction Stop).Source
$processExitCode = Invoke-LoggedProcess `
    -FilePath $cargo `
    -ArgumentList @(
        "run",
        "--package",
        "sporespore-rapier-adapter",
        "--bin",
        "locomotion_r1",
        "--release",
        "--offline",
        "--",
        "--source-commit",
        $sourceCommit,
        "--output",
        $reportPath
    ) `
    -WorkingDirectory $sdkRoot `
    -StdoutPath $stdoutPath `
    -StderrPath $stderrPath

Assert-Exact (
    Test-Path -LiteralPath $reportPath -PathType Leaf
) "Rapier C6-RAP-SP1-R1 exited $processExitCode without retaining report.json"
$report = (
    Get-Content -Raw -LiteralPath $reportPath |
        ConvertFrom-Json
)
$boundaryValid = (
    [string]$report.schema_version -ceq
        "sporespore_rapier_c6_selected_policy_commissioning_r1_report_v1" -and
    [string]$report.campaign_id -ceq
        "C6-RAPIER-SELECTED-POLICY-COMMISSIONING-R1" -and
    [string]$report.gate_id -ceq "C6-RAP-SP1-R1" -and
    [string]$report.source_commit -ceq $sourceCommit -and
    [string]$report.preregistration_raw_sha256 -ceq
        $expectedPreregistrationRawSha256 -and
    [bool]$report.preflight.perfect_synthetic_result_passed -and
    [bool]$report.preflight.nonzero_failure_canary_rejected -and
    [bool]$report.preflight.nonidentity_host_quaternion_conversion.portable_unit_norm_validation_passed -and
    [bool]$report.preflight.intentional_previous_actuation_null_ignored_by_numeric_finiteness_check -and
    [int]$report.preflight.world_build_count -eq 0 -and
    [int]$report.world_attempt_count -eq 1 -and
    [int]$report.world_build_count -eq 1 -and
    [int]$report.world_reset_count -eq 0 -and
    -not [bool]$report.rapier_selected_policy_physical_c6 -and
    -not [bool]$report.claim_boundary.cross_engine_c6 -and
    -not [bool]$report.claim_boundary.independent_validation -and
    -not [bool]$report.claim_boundary.release_authorized -and
    -not [bool]$report.claim_boundary.physical_acceptance_authority -and
    -not [bool]$report.claim_boundary.completed_engine_neutral_sdk
)
Assert-Exact (
    $boundaryValid
) "C6-RAP-SP1-R1 report violated its frozen identity or claim boundary"
$reportSha256 = Get-RawSha256 $reportPath
Write-Host (
    "C6-RAP-SP1-R1 retained: $reportPath $reportSha256 " +
    "(process exit $processExitCode)"
)
if ([bool]$report.ok) {
    Assert-Exact (
        [int]$processExitCode -eq 0 -and
        [bool]$report.rapier_selected_policy_single_body_technical_commissioning_passed
    ) "C6-RAP-SP1-R1 claimed success with an inconsistent process result"
} else {
    Assert-Exact (
        [int]$processExitCode -ne 0
    ) "C6-RAP-SP1-R1 retained a negative report but exited successfully"
    throw (
        "C6-RAP-SP1-R1 retained a complete negative report at $reportPath; " +
        "the same identity may not be rerun"
    )
}
