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
) "rapier_c6_force_based_selected_configuration_validation_spv1_preregistration.json"
$spd1ClosurePath = Join-Path (
    $sdkRoot
) "rapier_c6_force_based_solver_phase_development_spd1_closure.json"
$cargoLockPath = Join-Path $sdkRoot "Cargo.lock"
$closurePath = Join-Path (
    $sdkRoot
) "rapier_c6_force_based_selected_configuration_validation_spv1_closure.json"
$expectedPreregistrationRawSha256 = (
    "sha256:" +
    "9a4bbe4888efa6855e803d94b08c394667e617d4e71956e6d99e3fd9201c7172"
)
$expectedSpd1ClosureRawSha256 = (
    "sha256:" +
    "e39f8f2621cf55177342ea757dbd6b2262256393b3add65a8c62441cf5e36e52"
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
        $spd1ClosurePath,
        $cargoLockPath
    )
) {
    Assert-Exact (
        Test-Path -LiteralPath $requiredPath -PathType Leaf
    ) "An SPV1 declaration, predecessor closure, or lock file is missing"
}
Assert-Exact (
    (Get-Sha256 -Path $preregistrationPath) -ceq
        $expectedPreregistrationRawSha256 -and
    (Get-Sha256 -Path $spd1ClosurePath) -ceq
        $expectedSpd1ClosureRawSha256 -and
    (Get-Sha256 -Path $cargoLockPath) -ceq
        $expectedCargoLockRawSha256
) "An SPV1 declaration, predecessor closure, or lock hash changed"

$preregistration = (
    Get-Content -Raw -LiteralPath $preregistrationPath |
        ConvertFrom-Json -AsHashtable
)
Assert-Exact (
    [string]$preregistration.schema_version -ceq
        "sporespore_rapier_c6_force_based_selected_configuration_validation_preregistration_v1" -and
    [string]$preregistration.campaign_id -ceq
        "C6-RAPIER-FORCE-BASED-SELECTED-CONFIGURATION-VALIDATION" -and
    [string]$preregistration.gate_id -ceq "C6-RAP-HC-SPV1" -and
    [string]$preregistration.status -ceq
        "frozen_before_first_c6_rap_hc_spv1_physics_world" -and
    [string]$preregistration.study_class -ceq
        "exact_finite_cell_independent_host_validation" -and
    -not [bool]$preregistration.estimand.population_inference -and
    -not [bool]$preregistration.estimand.superiority -and
    -not [bool]$preregistration.estimand.non_inferiority -and
    -not [bool]$preregistration.estimand.equivalence -and
    -not [bool]$preregistration.estimand.development_selection -and
    -not [bool]$preregistration.estimand.selector_present -and
    [string]$preregistration.predecessor.selected_candidate_id -ceq
        "SPD1-B" -and
    [int]$preregistration.pinned_host_configuration.solver_iterations -eq
        16 -and
    [int]$preregistration.pinned_host_configuration.
        num_internal_pgs_iterations -eq 3 -and
    [int]$preregistration.pinned_host_configuration.
        num_internal_stabilization_iterations -eq 5 -and
    [int]$preregistration.pinned_host_configuration.
        total_constraint_passes_per_small_step -eq 8 -and
    [int]$preregistration.physical_grid.expected_world_count -eq 8 -and
    (@(
        $preregistration.physical_grid.unloaded_position_validation.
            target_positions_rad
    ) -join ",") -ceq "-0.55,0.55" -and
    (@(
        $preregistration.physical_grid.signed_velocity_validation.
            target_velocities_rad_s
    ) -join ",") -ceq "-1.25,1.25" -and
    (@(
        $preregistration.physical_grid.gravity_loaded_convergence_validation.
            signed_lever_arms_z_m
    ) -join ",") -ceq "-0.1,0.1,-0.5,0.5" -and
    [bool]$preregistration.preflight_contract.
        must_run_before_any_physics_world -and
    [bool]$preregistration.preflight_contract.
        perfect_synthetic_eight_cell_result_must_pass_the_real_cell_pair_and_aggregate_gate -and
    [bool]$preregistration.preflight_contract.
        missing_cell_canary_must_fail_closed -and
    [bool]$preregistration.preflight_contract.
        wrong_allocation_canary_must_fail_closed -and
    [bool]$preregistration.preflight_contract.
        position_error_canary_must_fail_closed -and
    [bool]$preregistration.preflight_contract.
        velocity_response_canary_must_fail_closed -and
    [bool]$preregistration.preflight_contract.
        loaded_window_gap_canary_must_fail_closed -and
    [bool]$preregistration.preflight_contract.
        motor_model_mismatch_canary_must_fail_closed -and
    [int]$preregistration.preflight_contract.world_build_count -eq 0
) "The SPV1 declaration identity, study class, grid, or preflight changed"

# Hash the installed Rapier implementation that defines the exact motor and
# solver behavior before entering the Rust zero-world gate.
Push-Location -LiteralPath $sdkRoot
try {
    $metadataRaw = (& cargo metadata --format-version 1 --offline)
    Assert-Exact (
        $LASTEXITCODE -eq 0
    ) "Cargo metadata failed before the SPV1 source audit"
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
) "SPV1 requires exactly one resolved rapier3d 0.34.0 package"
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
        "SPV1 pinned Rapier source mismatch: " +
        [string]$sourceDeclaration.path
    )
}

Push-Location -LiteralPath $sdkRoot
try {
    & cargo run `
        --package sporespore-rapier-adapter `
        --bin force_based_selected_configuration_validation `
        --offline `
        -- `
        --preflight-only
    Assert-Exact (
        $LASTEXITCODE -eq 0
    ) "SPV1 zero-world preflight failed"
} finally {
    Pop-Location
}

if ($PreflightOnly) {
    Write-Host (
        "C6-RAP-HC-SPV1 zero-world preflight passed: eight pinned source " +
        "hashes, model readbacks, complete position/velocity/loaded gate, " +
        "and missing/allocation/position/velocity/gap/model canaries; " +
        "worlds=0."
    )
    return
}

Assert-Exact (
    -not (Test-Path -LiteralPath $closurePath -PathType Leaf)
) (
    "C6-RAP-HC-SPV1 is already closed and may not open another physics " +
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
) "SPV1 physical execution requires clean HEAD == origin/main"

$shortCommit = $sourceCommit.Substring(0, 7)
if ([string]::IsNullOrWhiteSpace($OutputRoot)) {
    $OutputRoot = Join-Path (
        $evidenceRoot
    ) "c6-rapier-force-based-selected-configuration-spv1-$shortCommit"
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
) "SPV1 evidence must live beneath SporeSpore_Evidence"

$reportPath = Join-Path $resolvedOutputRoot "report.json"
$stdoutPath = Join-Path $resolvedOutputRoot "stdout.log"
$stderrPath = Join-Path $resolvedOutputRoot "stderr.log"
foreach ($path in @($reportPath, $stdoutPath, $stderrPath)) {
    Assert-Exact (
        -not (Test-Path -LiteralPath $path)
    ) "Refusing to overwrite an existing SPV1 artifact"
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
        "force_based_selected_configuration_validation",
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
) "SPV1 did not retain report.json"
$report = (
    Get-Content -Raw -LiteralPath $reportPath |
        ConvertFrom-Json -AsHashtable
)
$outcome = [bool]$report.ok
$boundaryValid = (
    [string]$report.schema_version -ceq
        "sporespore_rapier_c6_force_based_selected_configuration_validation_report_v1" -and
    [string]$report.campaign_id -ceq
        "C6-RAPIER-FORCE-BASED-SELECTED-CONFIGURATION-VALIDATION" -and
    [string]$report.gate_id -ceq "C6-RAP-HC-SPV1" -and
    [string]$report.study_class -ceq
        "exact_finite_cell_independent_host_validation" -and
    [string]$report.source.commit -ceq $sourceCommit -and
    [string]$report.source.origin_main_commit -ceq $sourceCommit -and
    [bool]$report.source.clean -and
    [bool]$report.source.matches_origin_main -and
    [string]$report.preregistration.raw_sha256 -ceq
        $expectedPreregistrationRawSha256 -and
    [string]$report.predecessor.spd1_closure_raw_sha256 -ceq
        $expectedSpd1ClosureRawSha256 -and
    -not [bool]$report.predecessor.selector_reinvoked -and
    [bool]$report.preflight.ok -and
    [int]$report.preflight.world_build_count -eq 0 -and
    [int]$report.aggregate.world_attempt_count -eq 8 -and
    [int]$report.aggregate.world_build_count -eq 8 -and
    [int]$report.aggregate.cell_count -eq 8 -and
    [int]$report.aggregate.motor_model_readback_count -eq 8 -and
    [bool]$report.rapier_force_based_selected_configuration_validation -eq
        $outcome -and
    [bool]$report.rapier_force_based_static_convergence_characterization -eq
        $outcome -and
    [bool]$report.rapier_force_based_host_characterization -eq
        $outcome -and
    [bool]$report.validation_authority -eq $outcome -and
    -not [bool]$report.rapier_selected_policy_physical_authority -and
    -not [bool]$report.rapier_locomotion_acceptance -and
    -not [bool]$report.different_physics_engines -and
    -not [bool]$report.cross_engine_c6 -and
    -not [bool]$report.physical_acceptance_authority -and
    -not [bool]$report.completed_engine_neutral_sdk
)
Assert-Exact (
    $boundaryValid
) "SPV1 retained report violated its identity or claim boundary"

$reportSha256 = Get-Sha256 -Path $reportPath
Write-Host (
    "C6-RAP-HC-SPV1 retained: $reportPath $reportSha256 " +
    "passed=$([int]$report.aggregate.passed_cell_count)/8 " +
    "position=$([bool]$report.aggregate.unloaded_position_pair_passed) " +
    "velocity=$([bool]$report.aggregate.signed_velocity_pair_passed) " +
    "loaded=$([bool]$report.aggregate.gravity_loaded_convergence_grid_passed)"
)
if ($process.ExitCode -ne 0 -or -not $outcome) {
    throw (
        "C6-RAP-HC-SPV1 retained a complete negative validation result " +
        "(process exit $($process.ExitCode)); close it without rerunning"
    )
}
