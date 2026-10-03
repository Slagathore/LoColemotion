[CmdletBinding()]
param(
    [switch]$PreflightOnly,
    [string]$OutputRoot = ""
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$sdkRoot = [System.IO.Path]::GetFullPath($PSScriptRoot)
$repoRoot = [System.IO.Path]::GetFullPath(
    (Split-Path -Parent $sdkRoot)
)
$evidenceRoot = [System.IO.Path]::GetFullPath(
    (Join-Path (Split-Path -Parent $repoRoot) "SporeSpore_Evidence")
)
$preregistrationPath = Join-Path (
    $sdkRoot
) "rapier_c6_force_based_host_characterization_preregistration.json"
$predecessorHostClosurePath = Join-Path (
    $sdkRoot
) "cross_engine_c6_host_characterization_r2_closure.json"
$predecessorLocomotionClosurePath = Join-Path (
    $sdkRoot
) "rapier_c6_selected_policy_commissioning_r2_closure.json"
$closurePath = Join-Path (
    $sdkRoot
) "rapier_c6_force_based_host_characterization_closure.json"
$expectedPreregistrationRawSha256 = (
    "sha256:" +
    "7d3753308707f4e96b33959eea5dbf0ad54ae6e442614a2acb87d339c26d20dc"
)
$expectedPredecessorHostClosureRawSha256 = (
    "sha256:" +
    "a7b1b3c172b98780f574cec9dbb18bebda35429ece5105a0385ecb7d67d6ddd9"
)
$expectedPredecessorLocomotionClosureRawSha256 = (
    "sha256:" +
    "07b02dbd2343d772a002b045ce32cbc6d5bb07c3fa63a308a4b06d70f202097d"
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

function Get-Sha256 {
    param([Parameter(Mandatory)][string]$Path)

    return "sha256:" + (
        Get-FileHash -Algorithm SHA256 -LiteralPath $Path
    ).Hash.ToLowerInvariant()
}

foreach (
    $requiredPath in @(
        $preregistrationPath,
        $predecessorHostClosurePath,
        $predecessorLocomotionClosurePath
    )
) {
    Assert-Exact (
        Test-Path -LiteralPath $requiredPath -PathType Leaf
    ) "A C6-RAP-HC-FB1 declaration or predecessor closure is missing"
}
Assert-Exact (
    (Get-Sha256 -Path $preregistrationPath) -ceq
        $expectedPreregistrationRawSha256 -and
    (Get-Sha256 -Path $predecessorHostClosurePath) -ceq
        $expectedPredecessorHostClosureRawSha256 -and
    (Get-Sha256 -Path $predecessorLocomotionClosurePath) -ceq
        $expectedPredecessorLocomotionClosureRawSha256
) "A C6-RAP-HC-FB1 declaration or predecessor hash changed"
$preregistration = (
    Get-Content -Raw -LiteralPath $preregistrationPath |
        ConvertFrom-Json
)
Assert-Exact (
    [string]$preregistration.schema_version -ceq
        "sporespore_rapier_c6_force_based_host_characterization_preregistration_v1" -and
    [string]$preregistration.campaign_id -ceq
        "C6-RAPIER-FORCE-BASED-HOST-CHARACTERIZATION" -and
    [string]$preregistration.gate_id -ceq "C6-RAP-HC-FB1" -and
    [string]$preregistration.status -ceq
        "frozen_before_first_c6_rap_hc_fb1_physics_world" -and
    [string]$preregistration.correction.required_model -ceq
        "ForceBased" -and
    [int]$preregistration.physical_grid.expected_world_count -eq 8 -and
    [bool]$preregistration.preflight_contract.must_run_before_any_physics_world -and
    [bool]$preregistration.preflight_contract.perfect_synthetic_result_must_pass_entire_integrity_gate -and
    [bool]$preregistration.preflight_contract.nonzero_failure_canary_must_fail_entire_integrity_gate
) "The C6-RAP-HC-FB1 declaration identity or preflight contract changed"

# This invocation is deliberately first and constructs zero worlds. The Rust
# path parses and hashes the complete declaration, proves the Rapier default
# is AccelerationBased, reads explicit ForceBased builder and mutable-update
# models back, and applies the entire result gate to a perfect synthetic
# declaration plus a nonzero mismatch canary.
Push-Location -LiteralPath $sdkRoot
try {
    & cargo run `
        --package sporespore-rapier-adapter `
        --bin force_based_characterization `
        --offline `
        -- `
        --preflight-only
    Assert-Exact (
        $LASTEXITCODE -eq 0
    ) "C6-RAP-HC-FB1 zero-world preflight failed"
} finally {
    Pop-Location
}

if ($PreflightOnly) {
    Write-Host (
        "C6-RAP-HC-FB1 zero-world preflight passed: default-model canary, " +
        "explicit builder/mutable ForceBased readback, perfect synthetic " +
        "integrity gate, and mismatch canary."
    )
    return
}

Assert-Exact (
    -not (Test-Path -LiteralPath $closurePath -PathType Leaf)
) (
    "C6-RAP-HC-FB1 is closed and may not open another physics world; " +
    "audit its closure instead"
)

$sourceCommit = (& git -C $repoRoot rev-parse HEAD).Trim()
$originMainCommit = (& git -C $repoRoot rev-parse origin/main).Trim()
$sourceStatus = @(& git -C $repoRoot status --porcelain=v1)
Assert-Exact (
    $LASTEXITCODE -eq 0 -and
    $sourceCommit -cmatch "^[0-9a-f]{40}$" -and
    $sourceCommit -ceq $originMainCommit -and
    $sourceStatus.Count -eq 0
) "C6-RAP-HC-FB1 physical execution requires clean HEAD == origin/main"

$shortCommit = $sourceCommit.Substring(0, 7)
if ([string]::IsNullOrWhiteSpace($OutputRoot)) {
    $OutputRoot = Join-Path (
        $evidenceRoot
    ) "c6-rapier-force-based-host-characterization-$shortCommit"
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
) "C6-RAP-HC-FB1 evidence must live beneath SporeSpore_Evidence"

$reportPath = Join-Path $resolvedOutputRoot "report.json"
$stdoutPath = Join-Path $resolvedOutputRoot "stdout.log"
$stderrPath = Join-Path $resolvedOutputRoot "stderr.log"
foreach ($path in @($reportPath, $stdoutPath, $stderrPath)) {
    Assert-Exact (
        -not (Test-Path -LiteralPath $path)
    ) "Refusing to overwrite an existing C6-RAP-HC-FB1 artifact"
}
[void][System.IO.Directory]::CreateDirectory($resolvedOutputRoot)

$cargo = (Get-Command cargo -ErrorAction Stop).Source
$process = Start-Process `
    -FilePath $cargo `
    -ArgumentList @(
        "run",
        "--package",
        "sporespore-rapier-adapter",
        "--bin",
        "force_based_characterization",
        "--release",
        "--offline",
        "--",
        "--source-commit",
        $sourceCommit,
        "--output",
        $reportPath
    ) `
    -WorkingDirectory $sdkRoot `
    -WindowStyle Hidden `
    -Wait `
    -PassThru `
    -RedirectStandardOutput $stdoutPath `
    -RedirectStandardError $stderrPath

Assert-Exact (
    Test-Path -LiteralPath $reportPath -PathType Leaf
) "C6-RAP-HC-FB1 did not retain report.json"
$report = (
    Get-Content -Raw -LiteralPath $reportPath |
        ConvertFrom-Json
)
$boundaryValid = (
    [string]$report.schema_version -ceq
        "sporespore_rapier_c6_force_based_host_characterization_report_v1" -and
    [string]$report.campaign_id -ceq
        "C6-RAPIER-FORCE-BASED-HOST-CHARACTERIZATION" -and
    [string]$report.gate_id -ceq "C6-RAP-HC-FB1" -and
    [string]$report.source.commit -ceq $sourceCommit -and
    [string]$report.source.origin_main_commit -ceq $sourceCommit -and
    [bool]$report.source.clean -and
    [bool]$report.source.matches_origin_main -and
    [string]$report.preregistration.raw_sha256 -ceq
        $expectedPreregistrationRawSha256 -and
    [bool]$report.preflight.ok -and
    [int]$report.preflight.world_build_count -eq 0 -and
    [int]$report.aggregate.world_attempt_count -eq 8 -and
    [int]$report.aggregate.world_build_count -eq 8 -and
    [int]$report.aggregate.cell_count -eq 8 -and
    [int]$report.aggregate.motor_model_readback_count -eq 8 -and
    -not [bool]$report.rapier_selected_policy_physical_authority -and
    -not [bool]$report.rapier_locomotion_acceptance -and
    -not [bool]$report.different_physics_engines -and
    -not [bool]$report.cross_engine_c6 -and
    -not [bool]$report.physical_acceptance_authority -and
    -not [bool]$report.completed_engine_neutral_sdk
)
Assert-Exact (
    $boundaryValid
) "C6-RAP-HC-FB1 retained report violated its identity or claim boundary"

$reportSha256 = Get-Sha256 -Path $reportPath
Write-Host (
    "C6-RAP-HC-FB1 retained: $reportPath $reportSha256 " +
    "passed=$([bool]$report.ok) cells=" +
    "$([int]$report.aggregate.passed_cell_count)/8"
)
if (
    $process.ExitCode -ne 0 -or
    -not [bool]$report.ok -or
    -not [bool]$report.rapier_force_based_host_characterization
) {
    throw (
        "C6-RAP-HC-FB1 retained a complete negative result " +
        "(process exit $($process.ExitCode)); close it without rerunning"
    )
}

