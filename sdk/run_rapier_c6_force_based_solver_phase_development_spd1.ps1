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
) "rapier_c6_force_based_solver_phase_development_spd1_preregistration.json"
$solverPhaseDiagnosticPath = Join-Path (
    $sdkRoot
) "rapier_c6_force_based_cw1_solver_phase_diagnostic.json"
$cw1ClosurePath = Join-Path (
    $sdkRoot
) "rapier_c6_force_based_convergence_window_cw1_closure.json"
$cargoLockPath = Join-Path $sdkRoot "Cargo.lock"
$closurePath = Join-Path (
    $sdkRoot
) "rapier_c6_force_based_solver_phase_development_spd1_closure.json"
$expectedPreregistrationRawSha256 = (
    "sha256:" +
    "ccfa677c7f3e7ab1d43c0c61be304b7fedb669f6292d8c53486aee5fc4c5c014"
)
$expectedSolverPhaseDiagnosticRawSha256 = (
    "sha256:" +
    "bcf35b8edd3d9340ff8680b3e85644dd8565841c000fb94e80a7ad54d9933594"
)
$expectedCw1ClosureRawSha256 = (
    "sha256:" +
    "df46f8a7982cabcd166a13c2b1f9e67fa606709b97484661d36aba1556e5747c"
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
        $solverPhaseDiagnosticPath,
        $cw1ClosurePath,
        $cargoLockPath
    )
) {
    Assert-Exact (
        Test-Path -LiteralPath $requiredPath -PathType Leaf
    ) "An SPD1 declaration, predecessor, diagnostic, or lock file is missing"
}
Assert-Exact (
    (Get-Sha256 -Path $preregistrationPath) -ceq
        $expectedPreregistrationRawSha256 -and
    (Get-Sha256 -Path $solverPhaseDiagnosticPath) -ceq
        $expectedSolverPhaseDiagnosticRawSha256 -and
    (Get-Sha256 -Path $cw1ClosurePath) -ceq
        $expectedCw1ClosureRawSha256 -and
    (Get-Sha256 -Path $cargoLockPath) -ceq
        $expectedCargoLockRawSha256
) "An SPD1 declaration, predecessor, diagnostic, or lock hash changed"

$preregistration = (
    Get-Content -Raw -LiteralPath $preregistrationPath |
        ConvertFrom-Json -AsHashtable
)
$allocations = @(
    $preregistration.controlled_configuration.candidate_phase_allocations
)
Assert-Exact (
    [string]$preregistration.schema_version -ceq
        "sporespore_rapier_c6_force_based_solver_phase_development_preregistration_v1" -and
    [string]$preregistration.campaign_id -ceq
        "C6-RAPIER-FORCE-BASED-SOLVER-PHASE-DEVELOPMENT" -and
    [string]$preregistration.gate_id -ceq "C6-RAP-HC-SPD1" -and
    [string]$preregistration.status -ceq
        "frozen_before_first_c6_rap_hc_spd1_physics_world" -and
    [string]$preregistration.study_classification.class -ceq
        "exact_finite_cell_configuration_development_screen" -and
    [bool]$preregistration.study_classification.finite_decision -and
    [bool]$preregistration.study_classification.development_screen -and
    -not [bool]$preregistration.study_classification.superiority_study -and
    -not [bool]$preregistration.study_classification.
        noninferiority_or_equivalence_study -and
    [int]$preregistration.physical_grid.expected_world_count -eq 16 -and
    [int]$preregistration.controlled_configuration.num_solver_iterations -eq
        16 -and
    [int]$preregistration.controlled_configuration.
        total_joint_constraint_passes_per_small_step -eq 8 -and
    $allocations.Count -eq 4 -and
    (@($allocations.candidate_id) -join ",") -ceq
        "SPD1-A,SPD1-B,SPD1-C,SPD1-D" -and
    @(
        $allocations | Where-Object {
            [int]$_.num_internal_pgs_iterations +
            [int]$_.num_internal_stabilization_iterations -eq 8
        }
    ).Count -eq 4 -and
    -not [bool]$preregistration.per_cell_convergence_contract.
        threshold_change_from_cw1 -and
    [bool]$preregistration.preflight_contract.
        must_run_before_any_physics_world -and
    [bool]$preregistration.preflight_contract.
        perfect_sixteen_cell_traces_must_pass_entire_gate -and
    [bool]$preregistration.preflight_contract.
        no_eligible_candidate_canary_must_select_none -and
    [bool]$preregistration.preflight_contract.
        missing_cell_canary_must_fail -and
    [bool]$preregistration.preflight_contract.
        window_gap_canary_must_fail -and
    [bool]$preregistration.preflight_contract.
        unequal_total_pass_canary_must_fail -and
    [bool]$preregistration.preflight_contract.
        tie_break_canary_must_select_spd1_a
) "The SPD1 declaration identity, study class, grid, or preflight changed"

# Resolve and hash all eight Rapier sources that establish the phase-order
# question. This check occurs before the Rust preflight and before any world.
Push-Location -LiteralPath $sdkRoot
try {
    $metadataRaw = (& cargo metadata --format-version 1 --offline)
    Assert-Exact (
        $LASTEXITCODE -eq 0
    ) "Cargo metadata failed before the SPD1 source audit"
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
) "SPD1 requires exactly one resolved rapier3d 0.34.0 package"
$rapierSourceRoot = Split-Path -Parent (
    [System.IO.Path]::GetFullPath(
        [string]$rapierPackages[0].manifest_path
    )
)
$sourcePrefix = $rapierSourceRoot.TrimEnd(
    [System.IO.Path]::DirectorySeparatorChar,
    [System.IO.Path]::AltDirectorySeparatorChar
) + [System.IO.Path]::DirectorySeparatorChar
foreach (
    $sourceDeclaration in @(
        $preregistration.host_source_semantics.upstream_files
    )
) {
    $relativeSourcePath = (
        [string]$sourceDeclaration.path
    ).Replace("/", [System.IO.Path]::DirectorySeparatorChar)
    $sourcePath = [System.IO.Path]::GetFullPath(
        (Join-Path $rapierSourceRoot $relativeSourcePath)
    )
    Assert-Exact (
        $sourcePath.StartsWith(
            $sourcePrefix,
            [StringComparison]::OrdinalIgnoreCase
        ) -and
        (Test-Path -LiteralPath $sourcePath -PathType Leaf) -and
        (Get-Sha256 -Path $sourcePath) -ceq (
            "sha256:" + [string]$sourceDeclaration.raw_sha256
        )
    ) (
        "SPD1 pinned Rapier source mismatch: " +
        [string]$sourceDeclaration.path
    )
}

# This is the first executable path that could lead to SPD1. It creates zero
# worlds and runs perfect traces plus selector, no-eligible, missing-cell,
# gap, unequal-work, and deterministic-tie negative controls.
Push-Location -LiteralPath $sdkRoot
try {
    & cargo run `
        --package sporespore-rapier-adapter `
        --bin force_based_solver_phase_development `
        --offline `
        -- `
        --preflight-only
    Assert-Exact (
        $LASTEXITCODE -eq 0
    ) "SPD1 zero-world preflight failed"
} finally {
    Pop-Location
}

if ($PreflightOnly) {
    Write-Host (
        "C6-RAP-HC-SPD1 zero-world preflight passed: eight pinned source " +
        "hashes, model readbacks, complete sixteen-cell gate, selector, " +
        "no-eligible/missing/gap/unequal-work/tie canaries; worlds=0."
    )
    return
}

Assert-Exact (
    -not (Test-Path -LiteralPath $closurePath -PathType Leaf)
) (
    "C6-RAP-HC-SPD1 is already closed and may not open another physics " +
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
) "SPD1 physical execution requires clean HEAD == origin/main"

$shortCommit = $sourceCommit.Substring(0, 7)
if ([string]::IsNullOrWhiteSpace($OutputRoot)) {
    $OutputRoot = Join-Path (
        $evidenceRoot
    ) "c6-rapier-force-based-solver-phase-spd1-$shortCommit"
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
) "SPD1 evidence must live beneath SporeSpore_Evidence"

$reportPath = Join-Path $resolvedOutputRoot "report.json"
$stdoutPath = Join-Path $resolvedOutputRoot "stdout.log"
$stderrPath = Join-Path $resolvedOutputRoot "stderr.log"
foreach ($path in @($reportPath, $stdoutPath, $stderrPath)) {
    Assert-Exact (
        -not (Test-Path -LiteralPath $path)
    ) "Refusing to overwrite an existing SPD1 artifact"
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
        "force_based_solver_phase_development",
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
) "SPD1 did not retain report.json"
$report = (
    Get-Content -Raw -LiteralPath $reportPath |
        ConvertFrom-Json -AsHashtable
)
$boundaryValid = (
    [string]$report.schema_version -ceq
        "sporespore_rapier_c6_force_based_solver_phase_development_report_v1" -and
    [string]$report.campaign_id -ceq
        "C6-RAPIER-FORCE-BASED-SOLVER-PHASE-DEVELOPMENT" -and
    [string]$report.gate_id -ceq "C6-RAP-HC-SPD1" -and
    [string]$report.study_class -ceq
        "exact_finite_cell_configuration_development_screen" -and
    [string]$report.source.commit -ceq $sourceCommit -and
    [string]$report.source.origin_main_commit -ceq $sourceCommit -and
    [bool]$report.source.clean -and
    [bool]$report.source.matches_origin_main -and
    [string]$report.preregistration.raw_sha256 -ceq
        $expectedPreregistrationRawSha256 -and
    [string]$report.solver_phase_diagnostic_raw_sha256 -ceq
        $expectedSolverPhaseDiagnosticRawSha256 -and
    [string]$report.cw1_closure_raw_sha256 -ceq
        $expectedCw1ClosureRawSha256 -and
    [bool]$report.preflight.ok -and
    [int]$report.preflight.world_build_count -eq 0 -and
    [int]$report.aggregate.world_attempt_count -eq 16 -and
    [int]$report.aggregate.world_build_count -eq 16 -and
    [int]$report.aggregate.cell_count -eq 16 -and
    [int]$report.aggregate.candidate_count -eq 4 -and
    [int]$report.aggregate.motor_model_readback_count -eq 16 -and
    [int]$report.aggregate.selector_invocation_count -eq 1 -and
    [bool]$report.aggregate.complete_sixteen_cell_screen -and
    [bool]$report.rapier_force_based_solver_phase_development_complete -and
    -not [bool]$report.rapier_force_based_static_convergence_characterization -and
    -not [bool]$report.rapier_force_based_host_characterization -and
    -not [bool]$report.rapier_selected_policy_physical_authority -and
    -not [bool]$report.rapier_locomotion_acceptance -and
    -not [bool]$report.different_physics_engines -and
    -not [bool]$report.cross_engine_c6 -and
    -not [bool]$report.validation_authority -and
    -not [bool]$report.physical_acceptance_authority -and
    -not [bool]$report.completed_engine_neutral_sdk
)
Assert-Exact (
    $boundaryValid
) "SPD1 retained report violated its identity or claim boundary"

$reportSha256 = Get-Sha256 -Path $reportPath
Write-Host (
    "C6-RAP-HC-SPD1 retained: $reportPath $reportSha256 " +
    "selected=$([string]$report.selection.selected_candidate_id) " +
    "eligible=$([int]$report.aggregate.eligible_candidate_count)/4 " +
    "cells=$([int]$report.aggregate.passed_cell_count)/16"
)
if (
    $process.ExitCode -ne 0 -or
    -not [bool]$report.ok -or
    [string]::IsNullOrWhiteSpace(
        [string]$report.selection.selected_candidate_id
    )
) {
    throw (
        "C6-RAP-HC-SPD1 retained a complete negative development result " +
        "(process exit $($process.ExitCode)); close it without rerunning"
    )
}
