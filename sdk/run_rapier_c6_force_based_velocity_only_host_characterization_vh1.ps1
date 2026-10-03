[CmdletBinding()]
param(
    [switch]$PreflightOnly,
    [switch]$RunPhysical,
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
) "rapier_c6_force_based_velocity_only_host_characterization_vh1_preregistration.json"
$canonicalProfilePath = Join-Path $sdkRoot "canonical_velocity_actuation_profile_v1.json"
$semanticsPath = Join-Path $repoRoot "docs\LOCOMOTION_SEMANTICS_V4.md"
$canonicalImplementationPath = Join-Path $sdkRoot "core\src\canonical_actuation.rs"
$activeConfigurationPath = Join-Path (
    $sdkRoot
) "adapters\rapier\src\active_configuration.rs"
$vh1ImplementationPath = Join-Path (
    $sdkRoot
) "adapters\rapier\src\force_based_velocity_only_characterization.rs"
$vh1BinaryPath = Join-Path (
    $sdkRoot
) "adapters\rapier\src\bin\force_based_velocity_only_characterization.rs"
$spv1ClosurePath = Join-Path (
    $sdkRoot
) "rapier_c6_force_based_selected_configuration_validation_spv1_closure.json"
$cargoLockPath = Join-Path $sdkRoot "Cargo.lock"
$closurePath = Join-Path (
    $sdkRoot
) "rapier_c6_force_based_velocity_only_host_characterization_vh1_closure.json"

$expectedPreregistrationRawSha256 = (
    "sha256:a0f7bd5994da1df009e59fb75f13bd831db1d916b99a470001bd2f58aae1caf0"
)
$expectedCanonicalProfileRawSha256 = (
    "sha256:1240ad4bba89bc8d1c22fa270fa718c57ab5ee227d777434b3870b859001e6a3"
)
$expectedSemanticsRawSha256 = (
    "sha256:19134cf0745f0a3d4cbbfb9c5ce4a7e051244c7477575863cee8558cf15da3c8"
)
$expectedCanonicalImplementationRawSha256 = (
    "sha256:81bb1747c0abb903fdfc552e6764036c0479152388e09fd4c79b0813edd4a6c4"
)
$expectedActiveConfigurationRawSha256 = (
    "sha256:f92d6710ac90ce225477ce778be874722be6730e507f3d1a2e75afa259fc4ab7"
)
$expectedVh1ImplementationRawSha256 = (
    "sha256:2ba5cde0f3615a401b4bc890d9ba8a8db393bad74bf351574923fc4f878e8359"
)
$expectedVh1BinaryRawSha256 = (
    "sha256:ac9bc8fb81349a58f35ae0561a53fd44944ceb3b041e71fa80024bbea27e4442"
)
$expectedSpv1ClosureRawSha256 = (
    "sha256:7830f66de49f1d7c2d5b88d151c0c2d5077782903457837d7ecd0da2fb724203"
)
$expectedCargoLockRawSha256 = (
    "sha256:0b8c50eac716ebd82fd323fcf52dad357f2e3128c382be26f291a224139c5cbc"
)
$implementationParentCommit = "0e77c47377fa721f99c4b5e1d484b6edd6ab8025"

function Assert-Exact {
    param([bool]$Condition, [string]$Message)
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

Assert-Exact (
    [bool]$PreflightOnly -xor [bool]$RunPhysical
) "Specify exactly one of -PreflightOnly or -RunPhysical"
Assert-Exact (
    [bool]$RunPhysical -or [string]::IsNullOrWhiteSpace($OutputRoot)
) "-OutputRoot is valid only with -RunPhysical"

# A retained closure is the first authority for physical mode. Refuse before
# mutable checkout hashes, prospective preflight replay, locks, or world setup.
if (
    $RunPhysical.IsPresent -and
    (Test-Path -LiteralPath $closurePath -PathType Leaf)
) {
    throw "VH1 is already closed and may not open another physics world"
}

$requiredHashes = [ordered]@{
    $preregistrationPath = $expectedPreregistrationRawSha256
    $canonicalProfilePath = $expectedCanonicalProfileRawSha256
    $semanticsPath = $expectedSemanticsRawSha256
    $canonicalImplementationPath = $expectedCanonicalImplementationRawSha256
    $activeConfigurationPath = $expectedActiveConfigurationRawSha256
    $vh1ImplementationPath = $expectedVh1ImplementationRawSha256
    $vh1BinaryPath = $expectedVh1BinaryRawSha256
    $spv1ClosurePath = $expectedSpv1ClosureRawSha256
    $cargoLockPath = $expectedCargoLockRawSha256
}
foreach ($entry in $requiredHashes.GetEnumerator()) {
    Assert-Exact (
        (Test-Path -LiteralPath $entry.Key -PathType Leaf) -and
        (Get-Sha256 -Path $entry.Key) -ceq [string]$entry.Value
    ) "VH1 pinned source changed or is missing: $($entry.Key)"
}

$preregistration = (
    Get-Content -Raw -LiteralPath $preregistrationPath |
        ConvertFrom-Json -AsHashtable
)
Assert-Exact (
    [string]$preregistration.schema_version -ceq
        "sporespore_rapier_c6_force_based_velocity_only_host_characterization_preregistration_v1" -and
    [string]$preregistration.campaign_id -ceq
        "C6-RAPIER-FORCE-BASED-VELOCITY-ONLY-HOST-CHARACTERIZATION-VH1" -and
    [string]$preregistration.gate_id -ceq "C6-RAP-HC-VH1" -and
    [string]$preregistration.status -ceq
        "frozen_before_first_c6_rap_hc_vh1_physics_world" -and
    [string]$preregistration.implementation_parent_commit -ceq
        $implementationParentCommit -and
    [string]$preregistration.study_class -ceq
        "exact_finite_cell_velocity_only_host_characterization" -and
    [string]$preregistration.semantic_predecessor.profile_id -ceq
        "sporespore_complete_closed_loop_canonical_velocity_v1" -and
    [string]$preregistration.semantic_predecessor.rapier_profile_id -ceq
        "rapier_force_based_velocity_only_v1" -and
    [string]$preregistration.semantic_predecessor.position_target_role -ceq
        "provenance_and_bounds_only" -and
    [double]$preregistration.semantic_predecessor.
        native_position_stiffness_required -eq 0.0 -and
    [string]$preregistration.validated_host_predecessor.status -ceq
        "closed_positive_exact_finite_host_validation" -and
    [int]$preregistration.pinned_host_configuration.solver_iterations -eq 16 -and
    [int]$preregistration.pinned_host_configuration.
        num_internal_pgs_iterations -eq 3 -and
    [int]$preregistration.pinned_host_configuration.
        num_internal_stabilization_iterations -eq 5 -and
    [double]$preregistration.pinned_host_configuration.
        position_stiffness_nm_per_rad -eq 0.0 -and
    [double]$preregistration.pinned_host_configuration.
        damping_nm_s_per_rad -eq 10.0 -and
    [double]$preregistration.pinned_host_configuration.
        maximum_motor_force_nm -eq 6.0 -and
    [int]$preregistration.physical_grid.expected_world_count -eq 12 -and
    (@($preregistration.physical_grid.unloaded_velocity_cells.
        target_velocities_rad_s) -join ",") -ceq "-0.75,0.75,-2.25,2.25" -and
    (@($preregistration.physical_grid.constant_torque_loaded_velocity_cells.
        target_velocities_rad_s) -join ",") -ceq "-1.5,1.5" -and
    (@($preregistration.physical_grid.constant_torque_loaded_velocity_cells.
        signed_external_torques_nm) -join ",") -ceq "-0.75,0.75,-2.25,2.25" -and
    [bool]$preregistration.preflight_contract.
        must_run_before_any_physics_world -and
    [bool]$preregistration.preflight_contract.
        perfect_synthetic_twelve_cell_result_must_pass_the_complete_real_gate -and
    [bool]$preregistration.execution_contract.
        physical_execution_requires_explicit_run_physical_switch -and
    [bool]$preregistration.execution_contract.
        physical_execution_requires_clean_head_equal_origin_main -and
    [int]$preregistration.preflight_contract.world_build_count -eq 0 -and
    -not [bool]$preregistration.preflight_contract.
        physical_acceptance_authority
) "The VH1 identity, grid, motor profile, or execution contract changed"

Push-Location -LiteralPath $sdkRoot
try {
    $metadataRaw = (& cargo metadata --format-version 1 --offline)
    Assert-Exact (
        $LASTEXITCODE -eq 0
    ) "Cargo metadata failed before the VH1 source audit"
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
) "VH1 requires exactly one resolved rapier3d 0.34.0 package"
$rapierSourceRoot = Split-Path -Parent (
    [System.IO.Path]::GetFullPath([string]$rapierPackages[0].manifest_path)
)
$sourcePrefix = $rapierSourceRoot.TrimEnd(
    [System.IO.Path]::DirectorySeparatorChar,
    [System.IO.Path]::AltDirectorySeparatorChar
) + [System.IO.Path]::DirectorySeparatorChar
foreach ($sourceDeclaration in @(
    $preregistration.host_source_semantics.upstream_files
)) {
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
    ) "VH1 pinned Rapier source mismatch: $($sourceDeclaration.path)"
}

Push-Location -LiteralPath $sdkRoot
try {
    $preflightLines = @(
        & cargo run `
            --quiet `
            --package sporespore-rapier-adapter `
            --bin force_based_velocity_only_characterization `
            --offline `
            -- `
            --preflight-only
    )
    Assert-Exact (
        $LASTEXITCODE -eq 0
    ) "VH1 zero-world preflight failed"
} finally {
    Pop-Location
}
$preflight = ($preflightLines -join [Environment]::NewLine) | ConvertFrom-Json
Assert-Exact (
    [bool]$preflight.ok -and
    [bool]$preflight.default_model_canary.passed -and
    [bool]$preflight.explicit_builder_readback.passed -and
    [bool]$preflight.mutable_update_readback.passed -and
    [double]$preflight.explicit_builder_readback.stiffness_nm_per_rad -eq 0.0 -and
    [double]$preflight.mutable_update_readback.stiffness_nm_per_rad -eq 0.0 -and
    [bool]$preflight.
        perfect_synthetic_twelve_cell_result_passed_complete_gate -and
    [bool]$preflight.perfect_synthetic_serialization_round_trip_passed -and
    [int]$preflight.perfect_synthetic_aggregate.cell_count -eq 12 -and
    [int]$preflight.perfect_synthetic_aggregate.passed_cell_count -eq 12 -and
    [bool]$preflight.perfect_synthetic_aggregate.
        complete_velocity_only_host_characterization_passed -and
    [bool]$preflight.missing_cell_canary_rejected -and
    [bool]$preflight.wrong_model_canary_rejected -and
    [bool]$preflight.nonzero_stiffness_canary_rejected -and
    [bool]$preflight.wrong_target_velocity_readback_canary_rejected -and
    [bool]$preflight.wrong_velocity_response_canary_rejected -and
    [bool]$preflight.wrong_impulse_response_canary_rejected -and
    [bool]$preflight.wrong_signed_response_canary_rejected -and
    [bool]$preflight.whole_outer_step_impulse_canary_rejected -and
    [bool]$preflight.
        world_count_and_physical_authority_inflation_canary_rejected -and
    [int]$preflight.world_build_count -eq 0 -and
    [int]$preflight.scene_insertion_count -eq 0 -and
    -not [bool]$preflight.physics_state_modified -and
    -not [bool]$preflight.physical_acceptance_authority
) "The VH1 zero-world receipt is incomplete or inflated"

if ($PreflightOnly) {
    Write-Output (
        "C6-RAP-HC-VH1 zero-world preflight passed: v4 profile, six pinned " +
        "Rapier sources, exact ForceBased velocity-only builder/mutable " +
        "readbacks, perfect 12-cell whole gate, nine negative controls, " +
        "worlds=0."
    )
    return
}

Assert-Exact (
    -not (Test-Path -LiteralPath $closurePath -PathType Leaf)
) "VH1 is already closed and may not open another physics world"
$priorEvidence = @(
    Get-ChildItem -LiteralPath $evidenceRoot `
        -Directory `
        -Filter "c6-rapier-force-based-velocity-only-vh1-*" `
        -ErrorAction SilentlyContinue
)
Assert-Exact (
    $priorEvidence.Count -eq 0
) "A VH1 evidence directory already exists; same-identity rerun is forbidden"

$sourceCommit = (& git -C $repoRoot rev-parse HEAD).Trim()
$originMainCommit = (& git -C $repoRoot rev-parse origin/main).Trim()
$sourceStatus = @(& git -C $repoRoot status --porcelain=v1)
Assert-Exact (
    $LASTEXITCODE -eq 0 -and
    $sourceCommit -cmatch "^[0-9a-f]{40}$" -and
    $sourceCommit -cne $implementationParentCommit -and
    $sourceCommit -ceq $originMainCommit -and
    $sourceStatus.Count -eq 0
) "VH1 physical execution requires distinct clean HEAD == origin/main"

$shortCommit = $sourceCommit.Substring(0, 7)
if ([string]::IsNullOrWhiteSpace($OutputRoot)) {
    $OutputRoot = Join-Path (
        $evidenceRoot
    ) "c6-rapier-force-based-velocity-only-vh1-$shortCommit"
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
) "VH1 evidence must live beneath SporeSpore_Evidence"

$reportPath = Join-Path $resolvedOutputRoot "report.json"
$stdoutPath = Join-Path $resolvedOutputRoot "stdout.log"
$stderrPath = Join-Path $resolvedOutputRoot "stderr.log"
foreach ($path in @($reportPath, $stdoutPath, $stderrPath)) {
    Assert-Exact (
        -not (Test-Path -LiteralPath $path)
    ) "Refusing to overwrite an existing VH1 artifact"
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
        "force_based_velocity_only_characterization",
        "--release",
        "--offline",
        "--",
        "--source-commit",
        $sourceCommit,
        "--output",
        $reportPath
    ) `
    -WorkingDirectory $sdkRoot `
    -RedirectStandardOutput $stdoutPath `
    -RedirectStandardError $stderrPath `
    -NoNewWindow `
    -Wait `
    -PassThru

Assert-Exact (
    Test-Path -LiteralPath $reportPath -PathType Leaf
) "VH1 did not retain its complete physical report"
$reportSha256 = Get-Sha256 -Path $reportPath
$report = Get-Content -Raw -LiteralPath $reportPath | ConvertFrom-Json
Write-Output "VH1_REPORT=$reportPath"
Write-Output "VH1_REPORT_SHA256=$reportSha256"
Write-Output "VH1_PROCESS_EXIT_CODE=$($process.ExitCode)"
Write-Output "VH1_PASSED=$([bool]$report.ok)"

if ($process.ExitCode -ne 0 -or -not [bool]$report.ok) {
    throw (
        "VH1 retained a complete negative report. Close it without rerun, " +
        "rethresholding, or cell replacement."
    )
}
