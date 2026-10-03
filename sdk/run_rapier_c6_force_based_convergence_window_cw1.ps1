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
) "rapier_c6_force_based_convergence_window_cw1_preregistration.json"
$lr1ClosurePath = Join-Path (
    $sdkRoot
) "rapier_c6_force_based_load_response_lr1_closure.json"
$lr1DiagnosticPath = Join-Path (
    $sdkRoot
) "rapier_c6_force_based_load_response_lr1_posthoc_diagnostic.json"
$cargoLockPath = Join-Path $sdkRoot "Cargo.lock"
$closurePath = Join-Path (
    $sdkRoot
) "rapier_c6_force_based_convergence_window_cw1_closure.json"
$expectedPreregistrationRawSha256 = (
    "sha256:" +
    "bb38c730c3df137cebb240d1450263426d974630001caddc0d2f05f031eda3fb"
)
$expectedLr1ClosureRawSha256 = (
    "sha256:" +
    "edb1890f9b9b4a38e53446f474f7c75e5aff8ce102d797912ce4ac7ef7d61a9f"
)
$expectedLr1DiagnosticRawSha256 = (
    "sha256:" +
    "5cf4f29192354479d23ca06e0306d1128b100bb3c9e224ceb7a25883999f38bb"
)
$expectedCargoLockRawSha256 = (
    "sha256:" +
    "0b8c50eac716ebd82fd323fcf52dad357f2e3128c382be26f291a224139c5cbc"
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
        $lr1ClosurePath,
        $lr1DiagnosticPath,
        $cargoLockPath
    )
) {
    Assert-Exact (
        Test-Path -LiteralPath $requiredPath -PathType Leaf
    ) "A C6-RAP-HC-CW1 declaration, predecessor, diagnostic, or lock file is missing"
}
Assert-Exact (
    (Get-Sha256 -Path $preregistrationPath) -ceq
        $expectedPreregistrationRawSha256 -and
    (Get-Sha256 -Path $lr1ClosurePath) -ceq
        $expectedLr1ClosureRawSha256 -and
    (Get-Sha256 -Path $lr1DiagnosticPath) -ceq
        $expectedLr1DiagnosticRawSha256 -and
    (Get-Sha256 -Path $cargoLockPath) -ceq
        $expectedCargoLockRawSha256
) "A C6-RAP-HC-CW1 declaration, predecessor, diagnostic, or lock hash changed"

$preregistration = (
    Get-Content -Raw -LiteralPath $preregistrationPath |
        ConvertFrom-Json -AsHashtable
)
Assert-Exact (
    [string]$preregistration.schema_version -ceq
        "sporespore_rapier_c6_force_based_convergence_window_preregistration_v1" -and
    [string]$preregistration.campaign_id -ceq
        "C6-RAPIER-FORCE-BASED-CONVERGENCE-WINDOW" -and
    [string]$preregistration.gate_id -ceq "C6-RAP-HC-CW1" -and
    [string]$preregistration.status -ceq
        "frozen_before_first_c6_rap_hc_cw1_physics_world" -and
    [string]$preregistration.estimand.class -ceq
        "exact_finite_cell_host_characterization" -and
    [bool]$preregistration.scientifically_distinct_from_fb1_and_lr1 -and
    [bool]$preregistration.freshness_contract.no_cw1_physical_cell_was_opened_before_freeze -and
    [int]$preregistration.physical_grid.expected_world_count -eq 8 -and
    [int]$preregistration.dynamics_grounded_horizon.maximum_observation_steps -eq 1440 -and
    [int]$preregistration.dynamics_grounded_horizon.minimum_steps_before_convergence_acceptance -eq 120 -and
    [int]$preregistration.dynamics_grounded_horizon.required_consecutive_converged_steps -eq 60 -and
    [bool]$preregistration.preflight_contract.must_run_before_any_physics_world -and
    [bool]$preregistration.preflight_contract.perfect_eight_cell_convergence_traces_must_pass_entire_gate -and
    [bool]$preregistration.preflight_contract.single_acceptable_step_canary_must_fail -and
    [bool]$preregistration.preflight_contract.window_gap_canary_must_fail -and
    [bool]$preregistration.preflight_contract.whole_outer_step_impulse_canary_must_fail -and
    [bool]$preregistration.preflight_contract.missing_cell_canary_must_fail
) "The C6-RAP-HC-CW1 declaration identity or preflight contract changed"

# Resolve and hash the installed Rapier 0.34 source files that ground the
# ForceBased PD equation, small-step impulse, constraint, and writeback gates.
Push-Location -LiteralPath $sdkRoot
try {
    $metadataRaw = (& cargo metadata `
        --format-version 1 `
        --offline)
    Assert-Exact (
        $LASTEXITCODE -eq 0
    ) "Cargo metadata failed before the C6-RAP-HC-CW1 source audit"
} finally {
    Pop-Location
}
$metadata = $metadataRaw | ConvertFrom-Json -AsHashtable
$rapierPackages = @(
    $metadata.packages | Where-Object {
        [string]$_.name -ceq "rapier3d" -and
        [string]$_.version -ceq "0.34.0"
    }
)
Assert-Exact (
    $rapierPackages.Count -eq 1
) "C6-RAP-HC-CW1 requires exactly one resolved rapier3d 0.34.0 package"
$rapierManifestPath = [System.IO.Path]::GetFullPath(
    [string]$rapierPackages[0].manifest_path
)
$rapierSourceRoot = Split-Path -Parent $rapierManifestPath
foreach ($sourceDeclaration in @(
    $preregistration.host_source_semantics.upstream_files
)) {
    $relativeSourcePath = (
        [string]$sourceDeclaration.path
    ).Replace("/", [System.IO.Path]::DirectorySeparatorChar)
    $sourcePath = [System.IO.Path]::GetFullPath(
        (Join-Path $rapierSourceRoot $relativeSourcePath)
    )
    $sourcePrefix = $rapierSourceRoot.TrimEnd(
        [System.IO.Path]::DirectorySeparatorChar,
        [System.IO.Path]::AltDirectorySeparatorChar
    ) + [System.IO.Path]::DirectorySeparatorChar
    Assert-Exact (
        $sourcePath.StartsWith(
            $sourcePrefix,
            [StringComparison]::OrdinalIgnoreCase
        ) -and
        (Test-Path -LiteralPath $sourcePath -PathType Leaf) -and
        (Get-Sha256 -Path $sourcePath) -ceq
            [string]$sourceDeclaration.raw_sha256
    ) (
        "C6-RAP-HC-CW1 pinned Rapier source mismatch: " +
        [string]$sourceDeclaration.path
    )
}

# This is the first executable path that could lead to CW1. It creates no
# PhysicsWorld. The Rust path runs perfect synthetic traces through the exact
# per-step window evaluator and aggregate gate, then proves short, gap,
# whole-step-impulse, and missing-cell canaries fail closed.
Push-Location -LiteralPath $sdkRoot
try {
    & cargo run `
        --package sporespore-rapier-adapter `
        --bin force_based_convergence_window `
        --offline `
        -- `
        --preflight-only
    Assert-Exact (
        $LASTEXITCODE -eq 0
    ) "C6-RAP-HC-CW1 zero-world preflight failed"
} finally {
    Pop-Location
}

if ($PreflightOnly) {
    Write-Host (
        "C6-RAP-HC-CW1 zero-world preflight passed: pinned Rapier source " +
        "hashes, default/explicit/mutable model readbacks, complete analytic " +
        "eight-cell convergence gate, and short/gap/whole-step/missing canaries."
    )
    return
}

Assert-Exact (
    -not (Test-Path -LiteralPath $closurePath -PathType Leaf)
) (
    "C6-RAP-HC-CW1 is already closed and may not open another physics " +
    "world; audit its closure instead"
)

$sourceCommit = (& git -C $repoRoot rev-parse HEAD).Trim()
$originMainCommit = (& git -C $repoRoot rev-parse origin/main).Trim()
$sourceStatus = @(& git -C $repoRoot status --porcelain=v1)
Assert-Exact (
    $LASTEXITCODE -eq 0 -and
    $sourceCommit -cmatch "^[0-9a-f]{40}$" -and
    $sourceCommit -ceq $originMainCommit -and
    $sourceStatus.Count -eq 0
) "C6-RAP-HC-CW1 physical execution requires clean HEAD == origin/main"

$shortCommit = $sourceCommit.Substring(0, 7)
if ([string]::IsNullOrWhiteSpace($OutputRoot)) {
    $OutputRoot = Join-Path (
        $evidenceRoot
    ) "c6-rapier-force-based-convergence-window-cw1-$shortCommit"
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
) "C6-RAP-HC-CW1 evidence must live beneath SporeSpore_Evidence"

$reportPath = Join-Path $resolvedOutputRoot "report.json"
$stdoutPath = Join-Path $resolvedOutputRoot "stdout.log"
$stderrPath = Join-Path $resolvedOutputRoot "stderr.log"
foreach ($path in @($reportPath, $stdoutPath, $stderrPath)) {
    Assert-Exact (
        -not (Test-Path -LiteralPath $path)
    ) "Refusing to overwrite an existing C6-RAP-HC-CW1 artifact"
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
        "force_based_convergence_window",
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
) "C6-RAP-HC-CW1 did not retain report.json"
$report = (
    Get-Content -Raw -LiteralPath $reportPath |
        ConvertFrom-Json -AsHashtable
)
$boundaryValid = (
    [string]$report.schema_version -ceq
        "sporespore_rapier_c6_force_based_convergence_window_report_v1" -and
    [string]$report.campaign_id -ceq
        "C6-RAPIER-FORCE-BASED-CONVERGENCE-WINDOW" -and
    [string]$report.gate_id -ceq "C6-RAP-HC-CW1" -and
    [string]$report.estimand_class -ceq
        "exact_finite_cell_host_characterization" -and
    [string]$report.source.commit -ceq $sourceCommit -and
    [string]$report.source.origin_main_commit -ceq $sourceCommit -and
    [bool]$report.source.clean -and
    [bool]$report.source.matches_origin_main -and
    [string]$report.preregistration.raw_sha256 -ceq
        $expectedPreregistrationRawSha256 -and
    [string]$report.lr1_closure_raw_sha256 -ceq
        $expectedLr1ClosureRawSha256 -and
    [string]$report.lr1_posthoc_diagnostic_raw_sha256 -ceq
        $expectedLr1DiagnosticRawSha256 -and
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
) "C6-RAP-HC-CW1 retained report violated its identity or claim boundary"

$reportSha256 = Get-Sha256 -Path $reportPath
Write-Host (
    "C6-RAP-HC-CW1 retained: $reportPath $reportSha256 " +
    "passed=$([bool]$report.ok) cells=" +
    "$([int]$report.aggregate.passed_cell_count)/8"
)
if (
    $process.ExitCode -ne 0 -or
    -not [bool]$report.ok -or
    -not [bool]$report.rapier_force_based_static_convergence_characterization -or
    -not [bool]$report.rapier_force_based_host_characterization
) {
    throw (
        "C6-RAP-HC-CW1 retained a complete negative result " +
        "(process exit $($process.ExitCode)); close it without rerunning"
    )
}
