#requires -Version 7.0

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = [System.IO.Path]::GetFullPath(
    (Split-Path -Parent $PSScriptRoot)
)
$closurePath = Join-Path (
    $repoRoot
) "sdk\cross_engine_c6_host_characterization_closure.json"
$basePreregistrationPath = Join-Path (
    $repoRoot
) "sdk\cross_engine_c6_host_characterization_preregistration.json"
$r1ClosurePath = Join-Path (
    $repoRoot
) "sdk\cross_engine_c6_host_characterization_r1_closure.json"
$r1PreregistrationPath = Join-Path (
    $repoRoot
) "sdk\cross_engine_c6_host_characterization_r1_preregistration.json"
$r2ClosurePath = Join-Path (
    $repoRoot
) "sdk\cross_engine_c6_host_characterization_r2_closure.json"
$r2PreregistrationPath = Join-Path (
    $repoRoot
) "sdk\cross_engine_c6_host_characterization_r2_preregistration.json"

function Assert-Exact {
    param(
        [bool]$Condition,
        [string]$Message
    )
    if (-not $Condition) {
        throw $Message
    }
}

function Get-PrefixedSha256 {
    param([Parameter(Mandatory)][string]$Path)
    return "sha256:" + (
        Get-FileHash -Algorithm SHA256 -LiteralPath $Path
    ).Hash.ToLowerInvariant()
}

Assert-Exact (
    Test-Path -LiteralPath $closurePath -PathType Leaf
) "C6-HC1 closure is missing"
$closure = Get-Content -Raw -LiteralPath $closurePath | ConvertFrom-Json
Assert-Exact (
    [string]$closure.schema_version -ceq
        "sporespore_cross_engine_c6_host_characterization_closure_v1" -and
    [string]$closure.campaign_id -ceq
        "C6-HOST-CHARACTERIZATION" -and
    [string]$closure.gate_id -ceq "C6-HC1" -and
    [string]$closure.status -ceq
        "closed_mixed_result_rapier_fixture_invalid_mujoco_pass" -and
    [string]$closure.source_commit -ceq
        "4707b8d5d467d899a3b6ea1d8f5caf28bd99f008" -and
    [bool]$closure.source_was_clean_and_equal_to_origin_main
) "C6-HC1 closure identity changed"
Assert-Exact (
    (Get-PrefixedSha256 -Path $basePreregistrationPath) -ceq
        [string]$closure.preregistration.raw_sha256
) "C6-HC1 base preregistration hash changed"

$artifactProperties = @(
    "rapier_report",
    "rapier_stdout",
    "rapier_stderr",
    "mujoco_report",
    "mujoco_stdout",
    "mujoco_stderr"
)
foreach ($property in $artifactProperties) {
    $artifact = $closure.artifacts.$property
    Assert-Exact (
        (Test-Path -LiteralPath $artifact.path -PathType Leaf) -and
        (Get-Item -LiteralPath $artifact.path).Length -eq
            [long]$artifact.bytes -and
        (Get-PrefixedSha256 -Path $artifact.path) -ceq
            [string]$artifact.sha256
    ) "C6-HC1 artifact changed or is missing: $property"
    Assert-Exact (
        -not [System.IO.Path]::GetFullPath(
            [string]$artifact.path
        ).StartsWith(
            "C:\tmp\",
            [StringComparison]::OrdinalIgnoreCase
        )
    ) "C6-HC1 evidence is under C:\tmp: $property"
}

$rapier = (
    Get-Content -Raw -LiteralPath $closure.artifacts.rapier_report.path |
        ConvertFrom-Json
)
$mujoco = (
    Get-Content -Raw -LiteralPath $closure.artifacts.mujoco_report.path |
        ConvertFrom-Json
)
foreach ($report in @($rapier, $mujoco)) {
    Assert-Exact (
        [string]$report.source.commit -ceq
            [string]$closure.source_commit -and
        [bool]$report.source.clean -and
        [bool]$report.source.matches_origin_main -and
        [int]$report.world_attempt_count -eq 28 -and
        [int]$report.integrity_summary.observed_material_profile_count -eq
            3 -and
        [int]$report.integrity_summary.observed_breakaway_trial_count -eq
            21 -and
        [int]$report.integrity_summary.observed_steady_slide_trial_count -eq
            3 -and
        [int]$report.integrity_summary.observed_actuator_cell_count -eq 4 -and
        -not [bool]$report.cross_engine_c6 -and
        -not [bool]$report.different_physics_engines -and
        -not [bool]$report.locomotion_acceptance -and
        -not [bool]$report.material_robustness -and
        -not [bool]$report.physical_acceptance_authority -and
        -not [bool]$report.release_authorized -and
        -not [bool]$report.completed_engine_neutral_sdk
    ) "A C6-HC1 report identity, count, or claim boundary changed"
}
Assert-Exact (
    -not [bool]$rapier.ok -and
    [int]$rapier.world_build_count -eq 24 -and
    [bool]$rapier.material_characterization_complete_for_declared_grid -and
    -not [bool]$rapier.actuator_characterization_complete_for_declared_grid -and
    [int]$rapier.integrity_summary.failed_actuator_cell_count -eq 4 -and
    [bool]$mujoco.ok -and
    [int]$mujoco.world_build_count -eq 28 -and
    [bool]$mujoco.material_characterization_complete_for_declared_grid -and
    [bool]$mujoco.actuator_characterization_complete_for_declared_grid -and
    [int]$mujoco.integrity_summary.failed_actuator_cell_count -eq 0
) "C6-HC1 mixed result changed"
Assert-Exact (
    -not [bool]$closure.decision.overall_gate_passed -and
    -not [bool]$closure.decision.rapier_engine_failure_claimed -and
    [bool]$closure.decision.mujoco_host_characterization_pass_retained -and
    [bool]$closure.decision.same_identity_rerun_forbidden -and
    -not [bool]$closure.decision.cross_engine_c6 -and
    -not [bool]$closure.decision.release_authorized -and
    -not [bool]$closure.decision.completed_engine_neutral_sdk
) "C6-HC1 closure decision boundary changed"

& git -C $repoRoot cat-file -e "$($closure.source_commit)^{commit}"
Assert-Exact ($LASTEXITCODE -eq 0) "C6-HC1 source commit is unavailable"

Assert-Exact (
    Test-Path -LiteralPath $r1ClosurePath -PathType Leaf
) "C6-HC1-R1 closure is missing"
$r1Closure = (
    Get-Content -Raw -LiteralPath $r1ClosurePath |
        ConvertFrom-Json
)
Assert-Exact (
    [string]$r1Closure.schema_version -ceq
        "sporespore_cross_engine_c6_host_characterization_r1_closure_v1" -and
    [string]$r1Closure.campaign_id -ceq
        "C6-HOST-CHARACTERIZATION-R1" -and
    [string]$r1Closure.gate_id -ceq "C6-HC1-R1" -and
    [string]$r1Closure.status -ceq
        "closed_mixed_result_rapier_pass_mujoco_actuator_integrator_invalid" -and
    [string]$r1Closure.source_commit -ceq
        "f54375ad1a4ba3d1e02c01b77983c3879e110bf4" -and
    [bool]$r1Closure.source_was_clean_and_equal_to_origin_main -and
    (Get-PrefixedSha256 -Path $r1PreregistrationPath) -ceq
        [string]$r1Closure.preregistration.raw_sha256 -and
    (Get-PrefixedSha256 -Path $closurePath) -ceq
        [string]$r1Closure.predecessor_closure.raw_sha256
) "C6-HC1-R1 closure identity or predecessor changed"
foreach ($property in $artifactProperties) {
    $artifact = $r1Closure.artifacts.$property
    Assert-Exact (
        (Test-Path -LiteralPath $artifact.path -PathType Leaf) -and
        (Get-Item -LiteralPath $artifact.path).Length -eq
            [long]$artifact.bytes -and
        (Get-PrefixedSha256 -Path $artifact.path) -ceq
            [string]$artifact.sha256 -and
        -not [System.IO.Path]::GetFullPath(
            [string]$artifact.path
        ).StartsWith(
            "C:\tmp\",
            [StringComparison]::OrdinalIgnoreCase
        )
    ) "C6-HC1-R1 artifact changed, is missing, or is temporary: $property"
}
$r1Rapier = (
    Get-Content -Raw -LiteralPath $r1Closure.artifacts.rapier_report.path |
        ConvertFrom-Json
)
$r1Mujoco = (
    Get-Content -Raw -LiteralPath $r1Closure.artifacts.mujoco_report.path |
        ConvertFrom-Json
)
foreach ($report in @($r1Rapier, $r1Mujoco)) {
    Assert-Exact (
        [string]$report.source.commit -ceq
            [string]$r1Closure.source_commit -and
        [int]$report.world_attempt_count -eq 28 -and
        [int]$report.integrity_summary.observed_breakaway_trial_count -eq
            21 -and
        [int]$report.integrity_summary.observed_steady_slide_trial_count -eq
            3 -and
        [int]$report.integrity_summary.observed_actuator_cell_count -eq 4 -and
        -not [bool]$report.cross_engine_c6 -and
        -not [bool]$report.different_physics_engines -and
        -not [bool]$report.locomotion_acceptance -and
        -not [bool]$report.material_robustness -and
        -not [bool]$report.physical_acceptance_authority -and
        -not [bool]$report.release_authorized -and
        -not [bool]$report.completed_engine_neutral_sdk
    ) "A C6-HC1-R1 report identity, count, or claim boundary changed"
}
Assert-Exact (
    [bool]$r1Rapier.ok -and
    [int]$r1Rapier.world_build_count -eq 28 -and
    [bool]$r1Rapier.material_characterization_complete_for_declared_grid -and
    [bool]$r1Rapier.actuator_characterization_complete_for_declared_grid -and
    [int]$r1Rapier.integrity_summary.failed_actuator_cell_count -eq 0 -and
    -not [bool]$r1Mujoco.ok -and
    [int]$r1Mujoco.world_build_count -eq 24 -and
    [bool]$r1Mujoco.material_characterization_complete_for_declared_grid -and
    -not [bool]$r1Mujoco.actuator_characterization_complete_for_declared_grid -and
    [int]$r1Mujoco.integrity_summary.failed_actuator_cell_count -eq 4 -and
    -not [bool]$r1Closure.decision.overall_gate_passed -and
    [bool]$r1Closure.decision.rapier_host_characterization_pass_retained -and
    -not [bool]$r1Closure.decision.mujoco_engine_failure_claimed -and
    [bool]$r1Closure.decision.same_identity_rerun_forbidden
) "C6-HC1-R1 mixed result or decision changed"
& git -C $repoRoot cat-file -e "$($r1Closure.source_commit)^{commit}"
Assert-Exact ($LASTEXITCODE -eq 0) "C6-HC1-R1 source commit is unavailable"

Assert-Exact (
    Test-Path -LiteralPath $r2ClosurePath -PathType Leaf
) "C6-HC1-R2 closure is missing"
$r2Closure = (
    Get-Content -Raw -LiteralPath $r2ClosurePath |
        ConvertFrom-Json
)
Assert-Exact (
    [string]$r2Closure.schema_version -ceq
        "sporespore_cross_engine_c6_host_characterization_r2_closure_v1" -and
    [string]$r2Closure.campaign_id -ceq
        "C6-HOST-CHARACTERIZATION-R2" -and
    [string]$r2Closure.gate_id -ceq "C6-HC1-R2" -and
    [string]$r2Closure.status -ceq
        "closed_pass_host_characterization_only" -and
    [string]$r2Closure.source_commit -ceq
        "7c0373f213a9f61f9570b316221c1f9753048c43" -and
    [bool]$r2Closure.source_was_clean_and_equal_to_origin_main -and
    (Get-PrefixedSha256 -Path $r2PreregistrationPath) -ceq
        [string]$r2Closure.preregistration.raw_sha256 -and
    (Get-PrefixedSha256 -Path $r1ClosurePath) -ceq
        [string]$r2Closure.predecessor_closure.raw_sha256
) "C6-HC1-R2 closure identity or predecessor changed"
foreach ($property in $artifactProperties) {
    $artifact = $r2Closure.artifacts.$property
    Assert-Exact (
        (Test-Path -LiteralPath $artifact.path -PathType Leaf) -and
        (Get-Item -LiteralPath $artifact.path).Length -eq
            [long]$artifact.bytes -and
        (Get-PrefixedSha256 -Path $artifact.path) -ceq
            [string]$artifact.sha256 -and
        -not [System.IO.Path]::GetFullPath(
            [string]$artifact.path
        ).StartsWith(
            "C:\tmp\",
            [StringComparison]::OrdinalIgnoreCase
        )
    ) "C6-HC1-R2 artifact changed, is missing, or is temporary: $property"
}
$r2Rapier = (
    Get-Content -Raw -LiteralPath $r2Closure.artifacts.rapier_report.path |
        ConvertFrom-Json
)
$r2Mujoco = (
    Get-Content -Raw -LiteralPath $r2Closure.artifacts.mujoco_report.path |
        ConvertFrom-Json
)
foreach ($report in @($r2Rapier, $r2Mujoco)) {
    Assert-Exact (
        [string]$report.campaign_id -ceq
            [string]$r2Closure.campaign_id -and
        [string]$report.gate_id -ceq [string]$r2Closure.gate_id -and
        [string]$report.source.commit -ceq
            [string]$r2Closure.source_commit -and
        [bool]$report.source.clean -and
        [bool]$report.source.matches_origin_main -and
        [bool]$report.ok -and
        [int]$report.world_attempt_count -eq 28 -and
        [int]$report.world_build_count -eq 28 -and
        [bool]$report.preflight.ok -and
        [bool]$report.preflight.full_integrity_gate_executed -and
        [bool]$report.preflight.perfect_synthetic_result_passed -and
        [bool]$report.preflight.nonzero_failure_canary_rejected -and
        [int]$report.preflight.world_build_count -eq 0 -and
        [int]$report.integrity_summary.observed_material_profile_count -eq
            3 -and
        [int]$report.integrity_summary.observed_breakaway_trial_count -eq
            21 -and
        [int]$report.integrity_summary.observed_steady_slide_trial_count -eq
            3 -and
        [int]$report.integrity_summary.observed_actuator_cell_count -eq 4 -and
        [int]$report.integrity_summary.failed_material_profile_count -eq 0 -and
        [int]$report.integrity_summary.failed_breakaway_trial_count -eq 0 -and
        [int]$report.integrity_summary.failed_steady_slide_trial_count -eq 0 -and
        [int]$report.integrity_summary.failed_actuator_cell_count -eq 0 -and
        [int]$report.integrity_summary.nonfinite_observation_count -eq 0 -and
        [bool]$report.material_characterization_complete_for_declared_grid -and
        [bool]$report.actuator_characterization_complete_for_declared_grid -and
        -not [bool]$report.controller_policy_authority -and
        -not [bool]$report.selected_policy_physical_authority -and
        -not [bool]$report.cross_engine_c6 -and
        -not [bool]$report.different_physics_engines -and
        -not [bool]$report.locomotion_acceptance -and
        -not [bool]$report.material_robustness -and
        -not [bool]$report.physical_acceptance_authority -and
        -not [bool]$report.release_authorized -and
        -not [bool]$report.completed_engine_neutral_sdk
    ) "A C6-HC1-R2 report identity, count, result, or claim changed"
    Assert-Exact (
        @($report.material_profiles | Where-Object { -not [bool]$_.ok }).Count -eq
            0 -and
        @($report.actuator_cells | Where-Object { -not [bool]$_.ok }).Count -eq
            0 -and
        @($report.actuator_cells | Where-Object {
            [double]$_.measured_child_mass_kg -ne 1.0 -or
            @($_.measured_child_principal_inertia_kg_m2).Count -ne 3
        }).Count -eq 0
    ) "A C6-HC1-R2 declared cell or aligned actuator fixture changed"
}
Assert-Exact (
    [string]$r2Rapier.rapier_version -ceq "0.34.0" -and
    [string]$r2Mujoco.mujoco_version -ceq "3.11.0" -and
    @($r2Mujoco.material_profiles | Where-Object {
        [string]$_.integrator -cne "Euler"
    }).Count -eq 0 -and
    @($r2Mujoco.actuator_cells | Where-Object {
        [string]$_.integrator -cne "implicitfast"
    }).Count -eq 0 -and
    [bool]$r2Closure.decision.overall_gate_passed -and
    [bool]$r2Closure.decision.rapier_host_characterization_pass_retained -and
    [bool]$r2Closure.decision.mujoco_host_characterization_pass_retained -and
    [bool]$r2Closure.decision.cross_engine_host_characterization_grid_completed -and
    [bool]$r2Closure.decision.same_identity_rerun_forbidden -and
    -not [bool]$r2Closure.decision.cross_engine_c6 -and
    -not [bool]$r2Closure.decision.different_physics_engines -and
    -not [bool]$r2Closure.decision.locomotion_acceptance -and
    -not [bool]$r2Closure.decision.material_robustness -and
    -not [bool]$r2Closure.decision.release_authorized -and
    -not [bool]$r2Closure.decision.completed_engine_neutral_sdk
) "C6-HC1-R2 result, integrator boundary, or decision changed"
& git -C $repoRoot cat-file -e "$($r2Closure.source_commit)^{commit}"
Assert-Exact ($LASTEXITCODE -eq 0) "C6-HC1-R2 source commit is unavailable"

Write-Host (
    "C6-HC1 through R2 closures passed: original Rapier fixture invalid / " +
    "MuJoCo 28/28; R1 Rapier 28/28 / MuJoCo integrator invalid; " +
    "R2 Rapier 28/28 and MuJoCo 28/28; 18 retained artifact hashes; " +
    "host characterization only, no cross-engine C6 claim."
)
