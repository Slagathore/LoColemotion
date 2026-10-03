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
) "rapier_c6_selected_policy_commissioning_r2_preregistration.json"
$closurePath = Join-Path (
    $sdkRoot
) "rapier_c6_selected_policy_commissioning_r2_closure.json"
$predecessorClosurePath = Join-Path (
    $sdkRoot
) "rapier_c6_selected_policy_commissioning_r1_closure.json"
$r1PreregistrationPath = Join-Path (
    $sdkRoot
) "rapier_c6_selected_policy_commissioning_r1_preregistration.json"

$expectedPreregistrationRawSha256 = (
    "sha256:" +
    "fe0b6d23f1262d1d3ead5621f6c8042c48ae016afebbdac20d51c52671ff7ec9"
)
$expectedPredecessorClosureRawSha256 = (
    "sha256:" +
    "0fe513b1af8fe386f4d9c13d7485f4bdfd37711d38a846a938fab11270b0e9fb"
)
$expectedPredecessorReportSha256 = (
    "sha256:" +
    "762696c9788aa940f00231a99cbb7fc8072aa05106badfee03f285490f88065d"
)
$expectedR1PreregistrationRawSha256 = (
    "sha256:" +
    "3102a8dddb8f6c7236735e2cdc6b403763d000a6b1518d55c201a7627e00a37f"
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
    ) "Refusing to overwrite a C6-RAP-SP1-R2 supervisor artifact"
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

foreach ($path in @(
    $preregistrationPath,
    $predecessorClosurePath,
    $r1PreregistrationPath
)) {
    Assert-Exact (
        Test-Path -LiteralPath $path -PathType Leaf
    ) "Required C6-RAP-SP1-R2 source is missing: $path"
}
Assert-Exact (
    (Get-RawSha256 $preregistrationPath) -ceq
        $expectedPreregistrationRawSha256 -and
    (Get-RawSha256 $predecessorClosurePath) -ceq
        $expectedPredecessorClosureRawSha256 -and
    (Get-RawSha256 $r1PreregistrationPath) -ceq
        $expectedR1PreregistrationRawSha256
) "A hash-pinned C6-RAP-SP1-R2 declaration changed"
$preregistration = (
    Get-Content -Raw -LiteralPath $preregistrationPath |
        ConvertFrom-Json
)
$predecessor = (
    Get-Content -Raw -LiteralPath $predecessorClosurePath |
        ConvertFrom-Json
)
$predecessorReportPath = [string]$predecessor.artifacts.report.path
Assert-Exact (
    [string]$preregistration.schema_version -ceq
        "sporespore_rapier_c6_selected_policy_commissioning_r2_preregistration_v1" -and
    [string]$preregistration.campaign_id -ceq
        "C6-RAPIER-SELECTED-POLICY-COMMISSIONING-R2" -and
    [string]$preregistration.gate_id -ceq "C6-RAP-SP1-R2" -and
    [string]$preregistration.status -ceq
        "frozen_before_first_c6_rap_sp1_r2_physics_world" -and
    [int]$preregistration.scope.world_count -eq 1 -and
    [bool]$preregistration.claim_boundary.observability_only -and
    -not [bool]$preregistration.frozen_physical_contract.physics_or_policy_changes_allowed -and
    -not [bool]$preregistration.frozen_physical_contract.geometry_mass_inertia_changes_allowed -and
    -not [bool]$preregistration.frozen_physical_contract.material_or_contact_semantics_changes_allowed -and
    -not [bool]$preregistration.frozen_physical_contract.motor_gain_limit_or_sign_changes_allowed -and
    -not [bool]$preregistration.frozen_physical_contract.clock_or_threshold_changes_allowed
) "C6-RAP-SP1-R2 identity or observability-only boundary changed"
Assert-Exact (
    [string]$predecessor.status -ceq
        "closed_negative_active_controller_host_dynamics" -and
    -not [bool]$predecessor.disposition.same_identity_rerun_allowed -and
    [bool]$predecessor.disposition.diagnostic_successor_allowed -and
    [string]$predecessor.artifacts.report.sha256 -ceq
        $expectedPredecessorReportSha256 -and
    (Test-Path -LiteralPath $predecessorReportPath -PathType Leaf) -and
    (Get-RawSha256 $predecessorReportPath) -ceq
        $expectedPredecessorReportSha256
) "C6-RAP-SP1-R2 predecessor closure or report failed its audit"
foreach ($source in $preregistration.method_sources.local_research_inputs) {
    $sourcePath = [System.IO.Path]::GetFullPath(
        (Join-Path $repoRoot ([string]$source.path))
    )
    Assert-Exact (
        (Test-Path -LiteralPath $sourcePath -PathType Leaf) -and
        (Get-RawSha256 $sourcePath) -ceq [string]$source.sha256
    ) "A C6-RAP-SP1-R2 research source is missing or changed: $sourcePath"
}

Push-Location -LiteralPath $sdkRoot
try {
    & cargo run `
        --package sporespore-rapier-adapter `
        --bin locomotion_r2 `
        --offline `
        -- `
        --preflight-only
    Assert-Exact (
        $LASTEXITCODE -eq 0
    ) "Rapier C6-RAP-SP1-R2 zero-world preflight failed"
} finally {
    Pop-Location
}
if ($PreflightOnly) {
    Write-Host (
        "C6-RAP-SP1-R2 zero-world preflight passed: inherited integrity " +
        "and transport gates plus the observability schema/canary are green."
    )
    return
}

Assert-Exact (
    -not (Test-Path -LiteralPath $closurePath -PathType Leaf)
) "C6-RAP-SP1-R2 is closed and may not open another world"
$sourceCommit = (& git -C $repoRoot rev-parse HEAD).Trim()
$originMainCommit = (& git -C $repoRoot rev-parse origin/main).Trim()
$sourceStatus = @(& git -C $repoRoot status --porcelain=v1)
Assert-Exact (
    $LASTEXITCODE -eq 0 -and
    $sourceCommit -cmatch "^[0-9a-f]{40}$" -and
    $sourceCommit -ceq $originMainCommit -and
    $sourceStatus.Count -eq 0
) "C6-RAP-SP1-R2 requires clean source with HEAD == origin/main"
$shortCommit = $sourceCommit.Substring(0, 7)
if ([string]::IsNullOrWhiteSpace($OutputRoot)) {
    $OutputRoot = Join-Path (
        $evidenceRoot
    ) "c6-rapier-selected-policy-r2-$shortCommit"
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
) "C6-RAP-SP1-R2 evidence must live beneath SporeSpore_Evidence"
$reportPath = Join-Path $resolvedOutputRoot "report.json"
$stdoutPath = Join-Path $resolvedOutputRoot "stdout.log"
$stderrPath = Join-Path $resolvedOutputRoot "stderr.log"
Assert-Exact (
    -not (Test-Path -LiteralPath $reportPath) -and
    -not (Test-Path -LiteralPath $stdoutPath) -and
    -not (Test-Path -LiteralPath $stderrPath)
) "Refusing to overwrite existing C6-RAP-SP1-R2 evidence"
[void][System.IO.Directory]::CreateDirectory($resolvedOutputRoot)
$cargo = (Get-Command cargo -ErrorAction Stop).Source
$processExitCode = Invoke-LoggedProcess `
    -FilePath $cargo `
    -ArgumentList @(
        "run",
        "--package",
        "sporespore-rapier-adapter",
        "--bin",
        "locomotion_r2",
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
) "C6-RAP-SP1-R2 exited $processExitCode without retaining report.json"
$report = (
    Get-Content -Raw -LiteralPath $reportPath |
        ConvertFrom-Json
)
$boundaryValid = (
    [string]$report.schema_version -ceq
        "sporespore_rapier_c6_selected_policy_commissioning_r2_report_v1" -and
    [string]$report.campaign_id -ceq
        "C6-RAPIER-SELECTED-POLICY-COMMISSIONING-R2" -and
    [string]$report.gate_id -ceq "C6-RAP-SP1-R2" -and
    [string]$report.source_commit -ceq $sourceCommit -and
    [string]$report.preregistration_raw_sha256 -ceq
        $expectedPreregistrationRawSha256 -and
    [bool]$report.preflight.perfect_synthetic_observability_receipt_passed -and
    [bool]$report.preflight.missing_required_observability_field_canary_rejected -and
    [int]$report.preflight.world_build_count -eq 0 -and
    [int]$report.world_attempt_count -eq 1 -and
    [int]$report.world_build_count -eq 1 -and
    $null -ne $report.observability.post_settle.torso_position_m -and
    $null -ne $report.observability.actuators -and
    @($report.observability.actuators.psobject.Properties).Count -eq 8 -and
    @($report.observability.contacts.psobject.Properties).Count -eq 4 -and
    @($report.observability.final_limb_memory.psobject.Properties).Count -eq 4 -and
    -not [bool]$report.rapier_selected_policy_physical_c6 -and
    -not [bool]$report.claim_boundary.cross_engine_c6 -and
    -not [bool]$report.claim_boundary.release_authorized -and
    -not [bool]$report.claim_boundary.physical_acceptance_authority
)
Assert-Exact (
    $boundaryValid
) "C6-RAP-SP1-R2 report violated its identity, observability, or claim boundary"
$reportSha256 = Get-RawSha256 $reportPath
Write-Host (
    "C6-RAP-SP1-R2 retained: $reportPath $reportSha256 " +
    "(process exit $processExitCode)"
)
if ([bool]$report.ok) {
    Assert-Exact (
        [int]$processExitCode -eq 0
    ) "C6-RAP-SP1-R2 claimed success with a nonzero process exit"
} else {
    Assert-Exact (
        [int]$processExitCode -ne 0
    ) "C6-RAP-SP1-R2 retained a negative report but exited successfully"
    throw (
        "C6-RAP-SP1-R2 retained its complete diagnostic report at " +
        "$reportPath; the same identity may not be rerun"
    )
}
