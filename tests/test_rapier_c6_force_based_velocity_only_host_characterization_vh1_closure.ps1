#requires -Version 7.0

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = [System.IO.Path]::GetFullPath(
    (Split-Path -Parent $PSScriptRoot)
)
$sdkRoot = Join-Path $repoRoot "sdk"
$manifestPath = Join-Path (
    $sdkRoot
) "rapier_c6_force_based_velocity_only_host_characterization_vh1_closure.json"
$expectedManifestSha256 = (
    "d94b20ef4767479172408c1dfbd0b7f66e18e3f4bc8b9d8d84193fc157d284aa"
)
$expectedSourceCommit = "ce1e846d7d866b24ef5e30b46ca17247c6862748"
. (Join-Path $PSScriptRoot "closed_experiment_source_audit.ps1")
$expectedCellIds = @(
    "unloaded_target_negative_0_75",
    "unloaded_target_positive_0_75",
    "unloaded_target_negative_2_25",
    "unloaded_target_positive_2_25",
    "loaded_target_negative_1_50_torque_negative_0_75",
    "loaded_target_negative_1_50_torque_positive_0_75",
    "loaded_target_negative_1_50_torque_negative_2_25",
    "loaded_target_negative_1_50_torque_positive_2_25",
    "loaded_target_positive_1_50_torque_negative_0_75",
    "loaded_target_positive_1_50_torque_positive_0_75",
    "loaded_target_positive_1_50_torque_negative_2_25",
    "loaded_target_positive_1_50_torque_positive_2_25"
)
$falseClaims = @(
    "rapier_v4_live_adapter_integration",
    "rapier_selected_policy_physical_authority",
    "rapier_locomotion_acceptance",
    "walking_acceptance",
    "different_physics_engines",
    "cross_engine_selected_policy_equivalence",
    "arbitrary_quadruped_coverage",
    "continuous_full_volume_coverage",
    "friction_or_material_robustness",
    "release_authorized",
    "physical_acceptance_authority",
    "completed_engine_neutral_sdk"
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

function Assert-Close {
    param(
        [double]$Actual,
        [double]$Expected,
        [double]$Tolerance,
        [string]$Message
    )

    Assert-Exact (
        [double]::IsFinite($Actual) -and
        [math]::Abs($Actual - $Expected) -le $Tolerance
    ) $Message
}

function Get-Sha256 {
    param([Parameter(Mandatory)][string]$Path)

    return (
        Get-FileHash -Algorithm SHA256 -LiteralPath $Path
    ).Hash.ToLowerInvariant()
}

function Assert-HashedFile {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$ExpectedSha256,
        [Parameter(Mandatory)][string]$Message
    )

    Assert-Exact (
        (Test-Path -LiteralPath $Path -PathType Leaf) -and
        (Get-Sha256 -Path $Path) -ceq
            $ExpectedSha256.Replace("sha256:", "")
    ) $Message
}

function Get-GitBlobSha256 {
    param(
        [Parameter(Mandatory)][string]$Commit,
        [Parameter(Mandatory)][string]$Path
    )

    $start = [System.Diagnostics.ProcessStartInfo]::new()
    $start.FileName = (Get-Command git -ErrorAction Stop).Source
    $start.WorkingDirectory = $repoRoot
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    [void]$start.ArgumentList.Add("-C")
    [void]$start.ArgumentList.Add($repoRoot)
    [void]$start.ArgumentList.Add("cat-file")
    [void]$start.ArgumentList.Add("blob")
    [void]$start.ArgumentList.Add("$Commit`:$Path")
    $process = [System.Diagnostics.Process]::new()
    $process.StartInfo = $start
    Assert-Exact (
        $process.Start()
    ) "Failed to start the C6-RAP-HC-VH1 Git blob audit"
    $memory = [System.IO.MemoryStream]::new()
    try {
        $process.StandardOutput.BaseStream.CopyTo($memory)
        $stderr = $process.StandardError.ReadToEnd()
        $process.WaitForExit()
        Assert-Exact (
            $process.ExitCode -eq 0
        ) "Git blob audit failed for $Commit`:$Path`: $stderr"
        return [Convert]::ToHexString(
            [Security.Cryptography.SHA256]::HashData($memory.ToArray())
        ).ToLowerInvariant()
    } finally {
        $memory.Dispose()
        $process.Dispose()
    }
}

function Get-RelativeDifference {
    param(
        [double]$First,
        [double]$Second
    )

    $scale = [math]::Max(
        ([math]::Abs($First) + [math]::Abs($Second)) * 0.5,
        [double]::Epsilon
    )
    return [math]::Abs(
        [math]::Abs($First) - [math]::Abs($Second)
    ) / $scale
}

function Test-SameNonzeroSign {
    param(
        [double]$First,
        [double]$Second
    )

    return (
        ($First -gt 0.0 -and $Second -gt 0.0) -or
        ($First -lt 0.0 -and $Second -lt 0.0)
    )
}

function Find-ExactCell {
    param(
        [Parameter(Mandatory)][object[]]$Cells,
        [double]$TargetVelocity,
        [double]$ExternalTorque
    )

    $matches = @(
        $Cells | Where-Object {
            [double]$_["target_velocity_rad_s"] -eq $TargetVelocity -and
            [double]$_["external_torque_nm"] -eq $ExternalTorque
        }
    )
    Assert-Exact (
        $matches.Count -eq 1
    ) "The VH1 grid no longer has one exact requested cell"
    return $matches[0]
}

function Test-ReportBoundary {
    param([Parameter(Mandatory)][hashtable]$Candidate)

    try {
        if (
            [string]$Candidate["schema_version"] -cne
                "sporespore_rapier_c6_force_based_velocity_only_host_characterization_report_v1" -or
            -not [bool]$Candidate["ok"] -or
            [string]$Candidate["campaign_id"] -cne
                "C6-RAPIER-FORCE-BASED-VELOCITY-ONLY-HOST-CHARACTERIZATION-VH1" -or
            [string]$Candidate["gate_id"] -cne "C6-RAP-HC-VH1" -or
            [string]$Candidate["source"]["commit"] -cne
                $expectedSourceCommit -or
            -not [bool]$Candidate["source"]["clean"] -or
            -not [bool]$Candidate["source"]["matches_origin_main"] -or
            -not [bool]$Candidate[
                "rapier_force_based_velocity_only_host_characterization"
            ] -or
            [bool]$Candidate["physical_acceptance_authority"]
        ) {
            return $false
        }
        foreach ($claim in $falseClaims) {
            if ([bool]$Candidate[$claim]) {
                return $false
            }
        }
        $cells = @($Candidate["cells"])
        if (
            $cells.Count -ne 12 -or
            (@($cells | ForEach-Object { $_["cell_id"] }) -join "`n") -cne
                ($expectedCellIds -join "`n")
        ) {
            return $false
        }
        foreach ($cell in $cells) {
            $velocityResponse = [double]$cell["normalized_velocity_response"]
            if (
                -not [bool]$cell["ok"] -or
                [string]$cell["motor_model_readback"] -cne "ForceBased" -or
                [double]$cell["readback_stiffness_nm_per_rad"] -ne 0.0 -or
                [double]$cell["readback_target_velocity_rad_s"] -ne
                    [double]$cell["target_velocity_rad_s"] -or
                [int]$cell["motor_model_mismatch_count"] -ne 0 -or
                [int]$cell["motor_field_mismatch_count"] -ne 0 -or
                [int]$cell["nonfinite_value_count"] -ne 0 -or
                [int]$cell["step_impulse_limit_violation_count"] -ne 0 -or
                $velocityResponse -lt 0.98 -or
                $velocityResponse -gt 1.02 -or
                [int]$cell["world_attempt_count"] -ne 1 -or
                [int]$cell["world_build_count"] -ne 1 -or
                [bool]$cell["physical_acceptance_authority"]
            ) {
                return $false
            }
            if ([double]$cell["external_torque_nm"] -ne 0.0) {
                $impulseResponse = [double]$cell[
                    "normalized_motor_impulse_response"
                ]
                if (
                    $impulseResponse -lt 0.98 -or
                    $impulseResponse -gt 1.02 -or
                    -not [bool]$cell[
                        "load_velocity_offset_and_impulse_signs_passed"
                    ]
                ) {
                    return $false
                }
            }
        }
        $aggregate = $Candidate["aggregate"]
        return (
            [int]$aggregate["cell_count"] -eq 12 -and
            [int]$aggregate["passed_cell_count"] -eq 12 -and
            [int]$aggregate["failed_cell_count"] -eq 0 -and
            [int]$aggregate["world_attempt_count"] -eq 12 -and
            [int]$aggregate["world_build_count"] -eq 12 -and
            [int]$aggregate["motor_model_readback_count"] -eq 12 -and
            [int]$aggregate["motor_model_mismatch_count"] -eq 0 -and
            [int]$aggregate["motor_field_mismatch_count"] -eq 0 -and
            [int]$aggregate["nonfinite_value_count"] -eq 0 -and
            [int]$aggregate["step_impulse_limit_violation_count"] -eq 0 -and
            [bool]$aggregate["ordered_cell_identity_passed"] -and
            [bool]$aggregate["unloaded_velocity_grid_passed"] -and
            [bool]$aggregate["loaded_affine_response_grid_passed"] -and
            [int]$aggregate["signed_pair_count"] -eq 6 -and
            [double]$aggregate[
                "maximum_signed_pair_relative_asymmetry"
            ] -le 0.005 -and
            [bool]$aggregate["signed_pair_symmetry_passed"] -and
            [bool]$aggregate[
                "complete_velocity_only_host_characterization_passed"
            ] -and
            @($Candidate["failure_codes"]).Count -eq 0
        )
    } catch {
        return $false
    }
}

Assert-HashedFile `
    -Path $manifestPath `
    -ExpectedSha256 $expectedManifestSha256 `
    -Message "The C6-RAP-HC-VH1 closure manifest changed"
$manifest = (
    Get-Content -Raw -LiteralPath $manifestPath |
        ConvertFrom-Json -AsHashtable
)
Assert-Exact (
    [string]$manifest.schema_version -ceq
        "sporespore_rapier_c6_force_based_velocity_only_host_characterization_closure_v1" -and
    [string]$manifest.status -ceq
        "closed_positive_exact_finite_velocity_only_host_characterization" -and
    [string]$manifest.campaign_id -ceq
        "C6-RAPIER-FORCE-BASED-VELOCITY-ONLY-HOST-CHARACTERIZATION-VH1" -and
    [string]$manifest.gate_id -ceq "C6-RAP-HC-VH1" -and
    [string]$manifest.study_class -ceq
        "exact_finite_cell_velocity_only_host_characterization" -and
    [string]$manifest.experiment_source_commit -ceq
        $expectedSourceCommit -and
    [bool]$manifest.source_was_clean_and_equal_to_origin_main -and
    [string]$manifest.preregistration.status -ceq
        "frozen_before_first_c6_rap_hc_vh1_physics_world" -and
    [string]$manifest.preregistration.implementation_parent_commit -ceq
        "0e77c47377fa721f99c4b5e1d484b6edd6ab8025" -and
    [string]$manifest.bound_source_inventory_authority -ceq
        "git_blob_at_experiment_source_commit" -and
    [bool]$manifest.predecessor_disposition.fb1_remains_closed_negative -and
    [bool]$manifest.predecessor_disposition.
        fb1_terminal_impulse_threshold_was_not_changed_or_reinterpreted -and
    [bool]$manifest.predecessor_disposition.
        vh1_used_a_new_campaign_identity_and_source_derived_estimand -and
    [bool]$manifest.predecessor_disposition.
        spv1_remains_closed_positive_for_its_distinct_combined_pd_profile -and
    [bool]$manifest.predecessor_disposition.
        no_predecessor_was_rerun_rethresholded_or_reclassified -and
    [bool]$manifest.immutability.same_identity_rerun_forbidden -and
    [bool]$manifest.immutability.report_rewrite_forbidden -and
    [bool]$manifest.immutability.threshold_change_forbidden -and
    [bool]$manifest.immutability.cell_grid_change_forbidden -and
    [bool]$manifest.immutability.
        cell_deletion_replacement_or_averaging_forbidden -and
    [bool]$manifest.immutability.posthoc_scope_expansion_forbidden -and
    [bool]$manifest.immutability.successor_requires_new_identity
) "The C6-RAP-HC-VH1 closure identity or immutability changed"

& git -C $repoRoot cat-file -e "${expectedSourceCommit}^{commit}"
Assert-Exact (
    $LASTEXITCODE -eq 0
) "The C6-RAP-HC-VH1 experiment commit is not retained"
& git -C $repoRoot merge-base --is-ancestor $expectedSourceCommit HEAD
Assert-Exact (
    $LASTEXITCODE -eq 0
) "The C6-RAP-HC-VH1 experiment commit is not an ancestor of HEAD"
$originMain = (& git -C $repoRoot rev-parse origin/main).Trim()
Assert-Exact (
    $LASTEXITCODE -eq 0
) "origin/main could not be resolved while auditing C6-RAP-HC-VH1"
& git -C $repoRoot merge-base --is-ancestor $expectedSourceCommit $originMain
Assert-Exact (
    $LASTEXITCODE -eq 0
) "The C6-RAP-HC-VH1 experiment commit is not retained on origin/main"

Assert-HashedFile `
    -Path (Join-Path $repoRoot ([string]$manifest.preregistration.path)) `
    -ExpectedSha256 ([string]$manifest.preregistration.raw_sha256) `
    -Message "The frozen C6-RAP-HC-VH1 preregistration changed"
foreach ($source in @($manifest.bound_source_inventory.Values)) {
    Assert-Exact (
        (Get-GitBlobSha256 `
            -Commit $expectedSourceCommit `
            -Path ([string]$source.path)) -ceq
            ([string]$source.raw_sha256).Replace("sha256:", "")
    ) "An experiment-commit C6-RAP-HC-VH1 source blob changed"
}
foreach ($artifactName in @("report", "stdout", "stderr")) {
    Assert-HashedFile `
        -Path ([string]$manifest.complete_attempt["${artifactName}_path"]) `
        -ExpectedSha256 (
            [string]$manifest.complete_attempt["${artifactName}_sha256"]
        ) `
        -Message "The retained C6-RAP-HC-VH1 $artifactName changed"
}
Assert-Exact (
    (Get-Item -LiteralPath (
        [string]$manifest.complete_attempt.report_path
    )).Length -eq [int64]$manifest.complete_attempt.report_size_bytes
) "The retained C6-RAP-HC-VH1 report size changed"

Push-Location -LiteralPath $sdkRoot
try {
    $metadataRaw = (& cargo metadata --format-version 1 --offline)
    Assert-Exact (
        $LASTEXITCODE -eq 0
    ) "Cargo metadata failed during the C6-RAP-HC-VH1 closure audit"
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
) "C6-RAP-HC-VH1 requires exactly one resolved Rapier 0.34.0 package"
$rapierSourceRoot = Split-Path -Parent (
    [System.IO.Path]::GetFullPath([string]$rapierPackages[0].manifest_path)
)
$rapierPrefix = $rapierSourceRoot.TrimEnd(
    [System.IO.Path]::DirectorySeparatorChar,
    [System.IO.Path]::AltDirectorySeparatorChar
) + [System.IO.Path]::DirectorySeparatorChar
foreach ($source in @($manifest.rapier_source_inventory.upstream_files)) {
    $relative = ([string]$source.path).Replace(
        "/",
        [System.IO.Path]::DirectorySeparatorChar
    )
    $path = [System.IO.Path]::GetFullPath(
        (Join-Path $rapierSourceRoot $relative)
    )
    Assert-Exact (
        $path.StartsWith(
            $rapierPrefix,
            [StringComparison]::OrdinalIgnoreCase
        )
    ) "A C6-RAP-HC-VH1 upstream path escaped the Rapier source root"
    Assert-HashedFile `
        -Path $path `
        -ExpectedSha256 ([string]$source.raw_sha256) `
        -Message "A pinned C6-RAP-HC-VH1 Rapier source changed"
}

$report = (
    Get-Content -Raw -LiteralPath (
        [string]$manifest.complete_attempt.report_path
    ) |
        ConvertFrom-Json -AsHashtable
)
Assert-Exact (
    Test-ReportBoundary -Candidate $report
) "The retained C6-RAP-HC-VH1 report no longer passes its independent boundary"
Assert-Exact (
    [string]$report.study_class -ceq
        "exact_finite_cell_velocity_only_host_characterization" -and
    [string]$report.source.origin_main_commit -ceq $expectedSourceCommit -and
    [string]$report.preregistration.raw_sha256 -ceq (
        "sha256:" + [string]$manifest.preregistration.raw_sha256
    ) -and
    [string]$report.canonical_profile_id -ceq
        "sporespore_complete_closed_loop_canonical_velocity_v1" -and
    [string]$report.rapier_host_profile_id -ceq
        "rapier_force_based_velocity_only_v1" -and
    [string]$report.adapter_id -ceq "sporespore_rapier3d_adapter" -and
    [string]$report.rapier_version -ceq "0.34.0" -and
    [string]$report.motor_model -ceq "ForceBased" -and
    [string]$report.actuation_mode -ceq "velocity_only" -and
    [string]$report.position_target_role -ceq
        "provenance_and_bounds_only" -and
    [double]$report.native_position_stiffness_nm_per_rad -eq 0.0 -and
    [double]$report.damping_nm_s_per_rad -eq 10.0 -and
    [double]$report.maximum_motor_force_nm -eq 6.0 -and
    [int]$report.solver_iterations -eq 16 -and
    [int]$report.internal_pgs_iterations -eq 3 -and
    [int]$report.internal_stabilization_iterations -eq 5
) "The retained C6-RAP-HC-VH1 source or host identity changed"

$preflight = $report.preflight
$preflightCanaries = @(
    "missing_cell_canary_rejected",
    "wrong_model_canary_rejected",
    "nonzero_stiffness_canary_rejected",
    "wrong_target_velocity_readback_canary_rejected",
    "wrong_velocity_response_canary_rejected",
    "wrong_impulse_response_canary_rejected",
    "wrong_signed_response_canary_rejected",
    "whole_outer_step_impulse_canary_rejected",
    "world_count_and_physical_authority_inflation_canary_rejected"
)
Assert-Exact (
    [bool]$preflight.ok -and
    [int]$preflight.world_build_count -eq 0 -and
    -not [bool]$preflight.physics_state_modified -and
    -not [bool]$preflight.physical_acceptance_authority -and
    [bool]$preflight.default_model_canary.passed -and
    [string]$preflight.default_model_canary.observed -ceq
        "AccelerationBased" -and
    [bool]$preflight.explicit_builder_readback.passed -and
    [bool]$preflight.mutable_update_readback.passed -and
    [double]$preflight.explicit_builder_readback.stiffness_nm_per_rad -eq
        0.0 -and
    [double]$preflight.mutable_update_readback.stiffness_nm_per_rad -eq
        0.0 -and
    [bool]$preflight.
        perfect_synthetic_twelve_cell_result_passed_complete_gate -and
    [bool]$preflight.
        perfect_synthetic_serialization_round_trip_passed -and
    [int]$preflight.perfect_synthetic_aggregate.cell_count -eq 12 -and
    [int]$preflight.perfect_synthetic_aggregate.passed_cell_count -eq 12 -and
    [bool]$preflight.perfect_synthetic_aggregate.
        complete_velocity_only_host_characterization_passed -and
    @($preflight.perfect_synthetic_failure_codes).Count -eq 0 -and
    @($preflightCanaries | Where-Object {
        -not [bool]$preflight[$_]
    }).Count -eq 0
) "The retained C6-RAP-HC-VH1 zero-world gate changed"

$cells = @($report.cells)
$worldAttempts = 0
$worldBuilds = 0
$modelReadbacks = 0
$updateReadbacks = 0
$modelMismatches = 0
$fieldMismatches = 0
$nonfinite = 0
$impulseViolations = 0
$minimumStreak = [int]::MaxValue
$maximumTransientImpulse = 0.0
$maximumAnchorError = 0.0
foreach ($cell in $cells) {
    $target = [double]$cell.target_velocity_rad_s
    $load = [double]$cell.external_torque_nm
    $outerDt = [double]$cell.outer_timestep_s
    $expectedVelocity = $target + $load / 10.0
    $expectedImpulse = $load * $outerDt / 16.0
    $smallStepLimit = 6.0 * $outerDt / 16.0
    Assert-Exact (
        [string]$cell.schema_version -ceq
            "sporespore_rapier_force_based_velocity_only_characterization_cell_v1" -and
        [bool]$cell.ok -and
        [int]$cell.observation_outer_steps -eq 360 -and
        [int]$cell.minimum_acceptance_outer_step -eq 120 -and
        [int]$cell.required_consecutive_acceptable_outer_steps -eq 60 -and
        [int]$cell.longest_consecutive_acceptable_outer_steps -ge 60 -and
        [string]$cell.motor_model_readback -ceq "ForceBased" -and
        [double]$cell.readback_target_position_rad -eq 0.0 -and
        [double]$cell.readback_target_velocity_rad_s -eq $target -and
        [double]$cell.readback_stiffness_nm_per_rad -eq 0.0 -and
        [double]$cell.readback_damping_nm_s_per_rad -eq 10.0 -and
        [double]$cell.readback_maximum_force_nm -eq 6.0 -and
        [int]$cell.motor_update_readback_count -eq 360 -and
        [int]$cell.motor_model_mismatch_count -eq 0 -and
        [int]$cell.motor_field_mismatch_count -eq 0 -and
        [int]$cell.nonfinite_value_count -eq 0 -and
        [int]$cell.step_impulse_limit_violation_count -eq 0 -and
        [bool]$cell.readback_passed -and
        [bool]$cell.finite_passed -and
        [bool]$cell.response_passed -and
        [bool]$cell.convergence_passed -and
        [bool]$cell.anchor_passed -and
        [bool]$cell.force_limit_passed -and
        [bool]$cell.target_and_terminal_velocity_signs_passed -and
        [double]$cell.final_anchor_error_m -le 0.00001 -and
        [double]$cell.maximum_observed_motor_impulse_nms -le
            $smallStepLimit + 0.000001 -and
        [int]$cell.world_attempt_count -eq 1 -and
        [int]$cell.world_build_count -eq 1 -and
        -not [bool]$cell.physical_acceptance_authority
    ) "A retained C6-RAP-HC-VH1 cell changed its shared gate"
    Assert-Close `
        -Actual ([double]$cell.expected_terminal_velocity_rad_s) `
        -Expected $expectedVelocity `
        -Tolerance 1.0e-6 `
        -Message "A VH1 source-derived expected velocity changed"
    Assert-Close `
        -Actual ([double]$cell.expected_terminal_motor_impulse_nms) `
        -Expected $expectedImpulse `
        -Tolerance 1.0e-9 `
        -Message "A VH1 source-derived expected impulse changed"
    Assert-Close `
        -Actual ([double]$cell.small_step_impulse_limit_nms) `
        -Expected $smallStepLimit `
        -Tolerance 1.0e-9 `
        -Message "A VH1 source-derived small-step force limit changed"
    if ($load -eq 0.0) {
        Assert-Exact (
            [string]$cell.cell_kind -ceq "unloaded_velocity" -and
            $null -eq $cell.normalized_motor_impulse_response
        ) "A VH1 unloaded cell changed kind or impulse-response scope"
        $reconstructedVelocityResponse = (
            [double]$cell.terminal_velocity_rad_s / $target
        )
    } else {
        Assert-Exact (
            [string]$cell.cell_kind -ceq
                "constant_torque_loaded_velocity" -and
            [bool]$cell.load_velocity_offset_and_impulse_signs_passed -and
            (Test-SameNonzeroSign `
                -First $load `
                -Second (
                    [double]$cell.terminal_velocity_rad_s - $target
                )) -and
            (Test-SameNonzeroSign `
                -First $load `
                -Second ([double]$cell.terminal_motor_impulse_nms))
        ) "A VH1 loaded response changed sign or scope"
        $reconstructedVelocityResponse = (
            ([double]$cell.terminal_velocity_rad_s - $target) /
            ($load / 10.0)
        )
        $reconstructedImpulseResponse = (
            [double]$cell.terminal_motor_impulse_nms / $expectedImpulse
        )
        Assert-Close `
            -Actual ([double]$cell.normalized_motor_impulse_response) `
            -Expected $reconstructedImpulseResponse `
            -Tolerance 1.0e-6 `
            -Message "A VH1 loaded normalized impulse response changed"
        Assert-Exact (
            $reconstructedImpulseResponse -ge 0.98 -and
            $reconstructedImpulseResponse -le 1.02
        ) "A VH1 loaded impulse response no longer passes"
    }
    Assert-Close `
        -Actual ([double]$cell.normalized_velocity_response) `
        -Expected $reconstructedVelocityResponse `
        -Tolerance 1.0e-6 `
        -Message "A VH1 normalized velocity response changed"
    Assert-Exact (
        $reconstructedVelocityResponse -ge 0.98 -and
        $reconstructedVelocityResponse -le 1.02
    ) "A VH1 velocity response no longer passes"

    $worldAttempts += [int]$cell.world_attempt_count
    $worldBuilds += [int]$cell.world_build_count
    $modelReadbacks += [int](
        [string]$cell.motor_model_readback -ceq "ForceBased"
    )
    $updateReadbacks += [int]$cell.motor_update_readback_count
    $modelMismatches += [int]$cell.motor_model_mismatch_count
    $fieldMismatches += [int]$cell.motor_field_mismatch_count
    $nonfinite += [int]$cell.nonfinite_value_count
    $impulseViolations += [int]$cell.step_impulse_limit_violation_count
    $minimumStreak = [math]::Min(
        $minimumStreak,
        [int]$cell.longest_consecutive_acceptable_outer_steps
    )
    $maximumTransientImpulse = [math]::Max(
        $maximumTransientImpulse,
        [double]$cell.maximum_observed_motor_impulse_nms
    )
    $maximumAnchorError = [math]::Max(
        $maximumAnchorError,
        [double]$cell.final_anchor_error_m
    )
}

$maximumPairAsymmetry = 0.0
foreach ($magnitude in @(0.75, 2.25)) {
    $negative = Find-ExactCell `
        -Cells $cells `
        -TargetVelocity (-$magnitude) `
        -ExternalTorque 0.0
    $positive = Find-ExactCell `
        -Cells $cells `
        -TargetVelocity $magnitude `
        -ExternalTorque 0.0
    $maximumPairAsymmetry = [math]::Max(
        $maximumPairAsymmetry,
        (Get-RelativeDifference `
            -First ([double]$negative.normalized_velocity_response) `
            -Second ([double]$positive.normalized_velocity_response))
    )
}
foreach ($target in @(-1.5, 1.5)) {
    foreach ($magnitude in @(0.75, 2.25)) {
        $negative = Find-ExactCell `
            -Cells $cells `
            -TargetVelocity $target `
            -ExternalTorque (-$magnitude)
        $positive = Find-ExactCell `
            -Cells $cells `
            -TargetVelocity $target `
            -ExternalTorque $magnitude
        foreach (
            $field in @(
                "normalized_velocity_response",
                "normalized_motor_impulse_response"
            )
        ) {
            $maximumPairAsymmetry = [math]::Max(
                $maximumPairAsymmetry,
                (Get-RelativeDifference `
                    -First ([double]$negative[$field]) `
                    -Second ([double]$positive[$field]))
            )
        }
    }
}

$aggregate = $report.aggregate
Assert-Exact (
    $worldAttempts -eq 12 -and
    $worldBuilds -eq 12 -and
    $modelReadbacks -eq 12 -and
    $updateReadbacks -eq 4320 -and
    $modelMismatches -eq 0 -and
    $fieldMismatches -eq 0 -and
    $nonfinite -eq 0 -and
    $impulseViolations -eq 0 -and
    $minimumStreak -eq 241 -and
    $maximumAnchorError -eq 0.0 -and
    [int]$aggregate.cell_count -eq 12 -and
    [int]$aggregate.passed_cell_count -eq 12 -and
    [int]$aggregate.failed_cell_count -eq 0 -and
    [int]$aggregate.world_attempt_count -eq 12 -and
    [int]$aggregate.world_build_count -eq 12 -and
    [int]$aggregate.motor_model_readback_count -eq 12 -and
    [int]$aggregate.motor_model_mismatch_count -eq 0 -and
    [int]$aggregate.motor_field_mismatch_count -eq 0 -and
    [int]$aggregate.nonfinite_value_count -eq 0 -and
    [int]$aggregate.step_impulse_limit_violation_count -eq 0 -and
    [bool]$aggregate.ordered_cell_identity_passed -and
    [bool]$aggregate.unloaded_velocity_grid_passed -and
    [bool]$aggregate.loaded_affine_response_grid_passed -and
    [int]$aggregate.signed_pair_count -eq 6 -and
    [bool]$aggregate.signed_pair_symmetry_passed -and
    [bool]$aggregate.complete_velocity_only_host_characterization_passed -and
    @($report.failure_codes).Count -eq 0
) "The C6-RAP-HC-VH1 aggregate did not independently reconstruct"
Assert-Close `
    -Actual $maximumPairAsymmetry `
    -Expected 0.000007987023828093498 `
    -Tolerance 1.0e-15 `
    -Message "The VH1 maximum signed-pair asymmetry changed"
Assert-Close `
    -Actual ([double]$aggregate.maximum_signed_pair_relative_asymmetry) `
    -Expected $maximumPairAsymmetry `
    -Tolerance 1.0e-15 `
    -Message "The VH1 aggregate pair asymmetry changed"
Assert-Close `
    -Actual $maximumTransientImpulse `
    -Expected 0.0022213675547391176 `
    -Tolerance 1.0e-15 `
    -Message "The VH1 maximum transient motor impulse changed"

Assert-Exact (
    [int]$manifest.complete_attempt.process_exit_code -eq 0 -and
    [int]$manifest.complete_attempt.world_build_count -eq 12 -and
    [int]$manifest.complete_attempt.passed_cell_count -eq 12 -and
    [int]$manifest.complete_attempt.failed_cell_count -eq 0 -and
    [int]$manifest.complete_attempt.motor_update_readback_count -eq 4320 -and
    [bool]$manifest.complete_attempt.
        complete_velocity_only_host_characterization_passed -and
    [bool]$manifest.technical_disposition.
        exact_finite_velocity_only_host_characterization_passed -and
    [bool]$manifest.technical_disposition.
        source_derived_affine_load_response_passed -and
    [bool]$manifest.technical_disposition.
        explicit_force_based_selection_observed_in_every_cell -and
    [bool]$manifest.technical_disposition.
        zero_native_position_stiffness_observed_in_every_cell -and
    -not [bool]$manifest.technical_disposition.
        live_v4_adapter_integration_performed -and
    -not [bool]$manifest.technical_disposition.
        selected_policy_locomotion_evaluated -and
    -not [bool]$manifest.technical_disposition.walking_evaluated -and
    -not [bool]$manifest.technical_disposition.
        population_or_continuous_host_domain_claim_authorized -and
    [bool]$manifest.technical_disposition.
        result_is_not_cross_engine_equivalence -and
    [bool]$manifest.technical_disposition.result_is_not_release_authority
) "The C6-RAP-HC-VH1 technical disposition changed"

Assert-Exact (
    [bool]$manifest.claims.
        rapier_force_based_velocity_only_host_characterization -and
    [bool]$report.rapier_force_based_velocity_only_host_characterization
) "C6-RAP-HC-VH1 must retain its exact finite positive claim"
foreach ($claim in $falseClaims) {
    Assert-Exact (
        -not [bool]$manifest.claims[$claim] -and
        -not [bool]$report[$claim]
    ) "C6-RAP-HC-VH1 may not authorize $claim"
}
foreach ($source in @($manifest.research_sources)) {
    Assert-Exact (
        (Test-Path -LiteralPath (
            Join-Path $repoRoot ([string]$source.path)
        ) -PathType Leaf) -and
        (Test-SporeWorkingOrHistoricalSourceSha256 `
            -RepositoryRoot $repoRoot `
            -Commit $expectedSourceCommit `
            -Path ([string]$source.path) `
            -ExpectedSha256 ([string]$source.sha256))
    ) "A C6-RAP-HC-VH1 research source changed"
}

$missingCellCanary = (
    $report | ConvertTo-Json -Depth 100 | ConvertFrom-Json -AsHashtable
)
$missingCellCanary["cells"] = @($missingCellCanary["cells"])[0..10]
$wrongModelCanary = (
    $report | ConvertTo-Json -Depth 100 | ConvertFrom-Json -AsHashtable
)
$wrongModelCanary["cells"][0]["motor_model_readback"] =
    "AccelerationBased"
$wrongResponseCanary = (
    $report | ConvertTo-Json -Depth 100 | ConvertFrom-Json -AsHashtable
)
$wrongResponseCanary["cells"][4]["normalized_motor_impulse_response"] =
    0.5
$inflatedClaimCanary = (
    $report | ConvertTo-Json -Depth 100 | ConvertFrom-Json -AsHashtable
)
$inflatedClaimCanary["physical_acceptance_authority"] = $true
Assert-Exact (
    -not (Test-ReportBoundary -Candidate $missingCellCanary) -and
    -not (Test-ReportBoundary -Candidate $wrongModelCanary) -and
    -not (Test-ReportBoundary -Candidate $wrongResponseCanary) -and
    -not (Test-ReportBoundary -Candidate $inflatedClaimCanary)
) "A C6-RAP-HC-VH1 closure-time negative control did not fail closed"

Write-Output (
    "C6_RAP_HC_VH1_CLOSURE_PASS worlds=12 passed=12 failed=0 " +
    "unloaded=4/4 loaded=8/8 readbacks=4320 model_mismatches=0 " +
    "field_mismatches=0 nonfinite=0 impulse_violations=0 " +
    "minimum_streak=241 max_pair_asymmetry=$maximumPairAsymmetry " +
    "preflight_canaries=9 closure_canaries=4 " +
    "finite_velocity_only_host_characterization=True " +
    "live_adapter=False locomotion_authority=False"
)
