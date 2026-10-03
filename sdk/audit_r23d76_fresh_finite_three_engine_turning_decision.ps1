#requires -Version 7.0

[CmdletBinding()]
param(
    [string]$Godot = (
        "C:\Users\Cole\CodeStuff\Misc\Godot\" +
        "Godot_v4.7-stable_mono_win64_console.exe"
    )
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$sdkRoot = [IO.Path]::GetFullPath($PSScriptRoot)
$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $sdkRoot))
$contractPath = Join-Path $sdkRoot (
    "turning\r23d76_fresh_finite_three_engine_turning_decision_v1.json"
)
$compilerPath = Join-Path $sdkRoot "turning\r23d76_seed_fixture_compiler.gd"
$expectedRoot = "C:\Users\Cole\CodeStuff\games\SporeSpore"
$expectedRemote = "https://github.com/Slagathore/sporespore.git"
$parentCommit = "5b868c1261da1a69764e2a1a21518b7b4e1b8b01"
$tolerance = 1.0e-15

function Assert-R23D76([bool]$Condition, [string]$Message) {
    if (-not $Condition) {
        throw "[turning/3e] R23D76 declaration audit: $Message"
    }
}

function Get-R23D76Sha256([string]$Path) {
    return "sha256:" + (
        Get-FileHash -LiteralPath $Path -Algorithm SHA256
    ).Hash.ToLowerInvariant()
}

function Get-R23D76GitBlobRawSha256([string]$Commit, [string]$RelativePath) {
    $start = [Diagnostics.ProcessStartInfo]::new()
    $start.FileName = "git"
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    foreach ($argument in @(
        "-C", $repoRoot, "cat-file", "blob", "${Commit}:$RelativePath"
    )) {
        [void]$start.ArgumentList.Add($argument)
    }
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $start
    try {
        Assert-R23D76 $process.Start() "could not start Git blob reader"
        $stderrTask = $process.StandardError.ReadToEndAsync()
        $hasher = [Security.Cryptography.SHA256]::Create()
        try {
            $digest = $hasher.ComputeHash($process.StandardOutput.BaseStream)
        } finally {
            $hasher.Dispose()
        }
        $process.WaitForExit()
        $stderr = $stderrTask.GetAwaiter().GetResult()
        Assert-R23D76 ($process.ExitCode -eq 0) (
            "Git blob read failed for $RelativePath`: $stderr"
        )
        return "sha256:" + [Convert]::ToHexString($digest).ToLowerInvariant()
    } finally {
        $process.Dispose()
    }
}

function Test-R23D76Shape([hashtable]$Value) {
    $selection = $Value.held_out_seed_selection
    $matrix = $Value.finite_population
    $schedule = $Value.fixed_schedule
    $thresholds = $Value.thresholds_and_estimator
    $smoke = $Value.post_zero_world_native_smoke
    return (
        [string]$Value.schema_version -ceq
            "sporespore_qsdk_r23d76_fresh_finite_three_engine_turning_decision_v1" -and
        [string]$Value.campaign_id -ceq
            "QSDK-R23D76-FRESH-FINITE-THREE-ENGINE-TURNING-DECISION" -and
        [string]$Value.gate_id -ceq "QSDK-R23D76" -and
        [string]$Value.release_gate_id -ceq "QSDK-R23" -and
        [string]$Value.status -ceq
            "prospective_declaration_complete_implementation_pending_physical_not_authorized" -and
        [string]$Value.question_class -ceq "finite_decision" -and
        [bool]$Value.not_development_work -and
        [bool]$Value.not_superiority_work -and
        [bool]$Value.not_equivalence_or_non_inferiority_work -and
        [string]$Value.declaration_parent.commit -ceq $parentCommit -and
        [string]$Value.declaration_parent.tree_git_oid -ceq
            "cfbbe464da7f12eeeea28bff77ad693e13c8ee58" -and
        [int]$selection.seed -eq 23197 -and
        [int]$selection.previous_consumed_or_outcome_exposed_seed -eq 23193 -and
        @($selection.rejected_candidates).Count -eq 1 -and
        [int]$selection.rejected_candidates[0].seed -eq 23195 -and
        [int]$selection.rejected_candidates[0].token_occurrence_count_at_declaration_parent -eq 2 -and
        [string]$selection.rejected_candidates[0].disposition -ceq
            "rejected_not_fresh" -and
        [int]$selection.first_fresh_candidate -eq 23197 -and
        [int]$selection.first_fresh_candidate_token_occurrence_count_at_declaration_parent -eq 0 -and
        [bool]$selection.selection_performed_after_development_design_frozen -and
        [bool]$selection.held_out_for_prospective_native_validation -and
        [int]$Value.seed_fixture_compilation.seed -eq 23197 -and
        [int]$matrix.declared_engine_count -eq 3 -and
        [int]$matrix.declared_arm_count -eq 3 -and
        [int]$matrix.declared_cell_count -eq 9 -and
        @($matrix.ordered_cell_ids).Count -eq 9 -and
        [bool]$matrix.complete_enumeration_required -and
        [bool]$matrix.all_cells_run_regardless_of_intermediate_behavior -and
        -not [bool]$matrix.selective_completion_or_rerun_allowed -and
        [int]$schedule.controller_semantic_step_count -eq 2992 -and
        [int]$schedule.commanded_turn_step_count -eq 1200 -and
        [int]$schedule.forward_displacement_measurement_origin_semantic_step -eq 472 -and
        [string]$schedule.startup_transform_by_engine.godot_jolt -ceq
            "support_loss_latched_smoothstep_one_cycle_v1" -and
        [string]$schedule.startup_transform_by_engine.rapier_parry -ceq
            "support_loss_latched_smoothstep_one_cycle_v1" -and
        [string]$schedule.startup_transform_by_engine.mujoco -ceq
            "canonical_velocity_smoothstep_one_gait_cycle_v1" -and
        [int]$schedule.startup_step_count -eq 360 -and
        [double]$thresholds.common_physical_gate_vector.minimum_final_forward_displacement_m -eq
            0.030123046875 -and
        [double]$thresholds.common_physical_gate_vector.maximum_tilt_rad -eq 0.6 -and
        [double]$thresholds.common_physical_gate_vector.minimum_torso_height_m -eq
            0.2499708652072946 -and
        [double]$thresholds.minimum_positive_raw_cycle_shift_rad -eq 0.01 -and
        [double]$thresholds.maximum_negative_raw_cycle_shift_rad -eq -0.01 -and
        [double]$thresholds.minimum_positive_reference_conditioned_cycle_shift_rad -eq
            0.01 -and
        [double]$thresholds.minimum_negative_reference_conditioned_cycle_shift_rad -eq
            0.01 -and
        $null -eq $thresholds.equivalence_margin -and
        $null -eq $thresholds.non_inferiority_margin -and
        -not [bool]$thresholds.equivalence_or_non_inferiority_interpretation_allowed -and
        [bool]$Value.finite_decision_rule.conjunctive -and
        -not [bool]$Value.finite_decision_rule.partial_credit_allowed -and
        [string]$Value.finite_decision_rule.score_before -ceq "10/25" -and
        [string]$Value.finite_decision_rule.score_if_positive -ceq "11/25" -and
        -not [bool]$Value.required_zero_world_implementation_gate.full_seeded_world_ghost_required -and
        -not [bool]$Value.required_zero_world_implementation_gate.behavioral_success_prediction_allowed -and
        [bool]$smoke.required_before_qualification -and
        [int]$smoke.engine_count -eq 3 -and
        [int]$smoke.maximum_world_count -eq 3 -and
        [int]$smoke.maximum_solver_step_count_per_world -eq 2 -and
        -not [bool]$smoke.uses_held_out_seed_23197 -and
        -not [bool]$smoke.behavior_thresholds_applied -and
        -not [bool]$smoke.finite_evidence -and
        -not [bool]$Value.physical_authorization.physical_execution_authorized -and
        -not [bool]$Value.physical_authorization.physical_acceptance_authority -and
        [bool]$Value.claims.r23d76_declared -and
        [bool]$Value.claims.seed_23197_held_out_to_physics -and
        -not [bool]$Value.claims.implementation_complete -and
        -not [bool]$Value.claims.zero_world_gate_passed -and
        -not [bool]$Value.claims.native_smoke_passed -and
        -not [bool]$Value.claims.physical_campaign_opened -and
        -not [bool]$Value.claims.portable_basic_turning -and
        -not [bool]$Value.claims.q_sdk_r23_satisfied -and
        -not [bool]$Value.claims.cross_engine_equivalence -and
        -not [bool]$Value.claims.release_readiness_score_changed -and
        [string]$Value.claims.release_score_before -ceq "10/25" -and
        [string]$Value.claims.release_score_after -ceq "10/25" -and
        -not [bool]$Value.claims.release_authorized
    )
}

$top = [IO.Path]::GetFullPath((git -C $repoRoot rev-parse --show-toplevel).Trim())
$remote = (git -C $repoRoot remote get-url origin).Trim()
Assert-R23D76 ($LASTEXITCODE -eq 0) "repository identity unreadable"
Assert-R23D76 ($top -ceq $expectedRoot) "repository root mismatch"
Assert-R23D76 ($remote -ceq $expectedRemote) "origin mismatch"
foreach ($path in @($contractPath, $compilerPath, $Godot)) {
    Assert-R23D76 (Test-Path -LiteralPath $path -PathType Leaf) (
        "required declaration path missing: $path"
    )
}

$contract = Get-Content -LiteralPath $contractPath -Raw |
    ConvertFrom-Json -AsHashtable -Depth 100
Assert-R23D76 (Test-R23D76Shape $contract) (
    "declaration identity, design, threshold, smoke, or claim boundary changed"
)
& git -C $repoRoot cat-file -e "${parentCommit}^{commit}" 2>$null
Assert-R23D76 ($LASTEXITCODE -eq 0) "declaration parent is unavailable"
& git -C $repoRoot merge-base --is-ancestor $parentCommit HEAD
Assert-R23D76 ($LASTEXITCODE -eq 0) "declaration parent is not an ancestor of HEAD"
$parentTree = (git -C $repoRoot rev-parse "${parentCommit}^{tree}").Trim()
Assert-R23D76 (
    $parentTree -ceq [string]$contract.declaration_parent.tree_git_oid
) "declaration-parent tree changed"

$rejectedSeedMatches = @(
    git -C $repoRoot grep -n -P '(^|[^0-9])23195([^0-9]|$)' $parentCommit `
        -- . ':(exclude)sdk/target/**' 2>$null
)
$rejectedSeedGrepExit = $LASTEXITCODE
Assert-R23D76 (
    $rejectedSeedGrepExit -eq 0 -and $rejectedSeedMatches.Count -eq 2
) "rejected candidate 23195 parent population changed"
$freshSeedMatches = @(
    git -C $repoRoot grep -n -P '(^|[^0-9])23197([^0-9]|$)' $parentCommit `
        -- . ':(exclude)sdk/target/**' 2>$null
)
$freshSeedGrepExit = $LASTEXITCODE
Assert-R23D76 (
    $freshSeedGrepExit -eq 1 -and $freshSeedMatches.Count -eq 0
) "seed 23197 was not fresh at the declaration parent"

Assert-R23D76 (
    (Get-R23D76Sha256 $compilerPath) -ceq
        [string]$contract.seed_fixture_compilation.compiler_raw_sha256
) "seed compiler digest changed"

$r23d74 = $contract.immutable_predecessors.consumed_r23d74_finite_result
$r23d75 = $contract.immutable_predecessors.closed_r23d75_native_startup_trace_evaluator_conformance
foreach ($binding in @(
    @([string]$r23d74.declaration_path, [string]$r23d74.declaration_git_blob_raw_sha256),
    @([string]$r23d74.closure_path, [string]$r23d74.closure_git_blob_raw_sha256),
    @([string]$r23d74.closure_audit_path, [string]$r23d74.closure_audit_git_blob_raw_sha256),
    @([string]$r23d75.closure_path, [string]$r23d75.closure_git_blob_raw_sha256),
    @([string]$r23d75.closure_audit_path, [string]$r23d75.closure_audit_git_blob_raw_sha256),
    @(
        [string]$contract.thresholds_and_estimator.cycle_estimator_path,
        [string]$contract.thresholds_and_estimator.cycle_estimator_git_blob_raw_sha256
    ),
    @(
        [string]$contract.thresholds_and_estimator.common_gate_source_path,
        [string]$contract.thresholds_and_estimator.common_gate_source_git_blob_raw_sha256
    )
)) {
    Assert-R23D76 (
        (Get-R23D76GitBlobRawSha256 $parentCommit $binding[0]) -ceq $binding[1]
    ) "immutable predecessor binding changed: $($binding[0])"
}

$compilerLines = @(
    & $Godot --headless --path $repoRoot --script (
        "res://sdk/turning/r23d76_seed_fixture_compiler.gd"
    ) 2>&1
)
$compilerExit = $LASTEXITCODE
Assert-R23D76 ($compilerExit -eq 0) (
    "seed compiler failed: $($compilerLines -join ' ')"
)
$marker = "QSDK_R23D76_SEED_FIXTURES "
$payloads = @(
    $compilerLines |
        Where-Object { ([string]$_).StartsWith($marker, [StringComparison]::Ordinal) } |
        ForEach-Object { ([string]$_).Substring($marker.Length) }
)
Assert-R23D76 ($payloads.Count -eq 1) "seed compiler marker count changed"
$compiled = $payloads[0] | ConvertFrom-Json -AsHashtable -Depth 100
$fixture = @($compiled.fixtures)[0]
$expectedFixture = $contract.seed_fixture_compilation.compiled_initial_perturbation
Assert-R23D76 (
    [string]$compiled.schema_version -ceq "sporespore_qsdk_r23d76_seed_fixtures_v1" -and
    @($compiled.r23d76_unopened_held_out_seeds).Count -eq 1 -and
    [int]$compiled.r23d76_unopened_held_out_seeds[0] -eq 23197 -and
    @($compiled.fixtures).Count -eq 1 -and
    [int]$compiled.model_construction_count -eq 0 -and
    [int]$compiled.world_attempt_count -eq 0 -and
    [int]$compiled.world_build_count -eq 0 -and
    [int]$fixture.campaign_seed -eq 23197 -and
    [string]$fixture.cohort -ceq "r23d76_unopened_three_engine_held_out_turning" -and
    [Math]::Abs(
        [double]$fixture.fixture_vertical_clearance_m -
        [double]$expectedFixture.fixture_vertical_clearance_m
    ) -le $tolerance -and
    [Math]::Abs(
        [double]$fixture.fixture_yaw_rad - [double]$expectedFixture.fixture_yaw_rad
    ) -le $tolerance -and
    [int]$fixture.gait_phase_offset_ticks -eq -3
) "compiled held-out fixture changed"
foreach ($index in 0..2) {
    Assert-R23D76 (
        [Math]::Abs(
            [double]$fixture.initial_linear_velocity_world_m_s[$index] -
            [double]$expectedFixture.initial_linear_velocity_world_m_s[$index]
        ) -le $tolerance -and
        [Math]::Abs(
            [double]$fixture.initial_torso_angular_velocity_world_rad_s[$index] -
            [double]$expectedFixture.initial_torso_angular_velocity_world_rad_s[$index]
        ) -le $tolerance
    ) "compiled held-out fixture vector changed at index $index"
}

$expectedCells = @(
    foreach ($engine in @("godot_jolt", "rapier_parry", "mujoco")) {
        foreach ($arm in @("reference_zero", "positive_heading", "negative_heading")) {
            "r23d76__${engine}__s23197__${arm}"
        }
    }
)
Assert-R23D76 (
    (@($contract.finite_population.ordered_cell_ids) -join "|") -ceq
        ($expectedCells -join "|")
) "ordered finite population changed"

$mutationRejections = 0
foreach ($mutation in @(
    { param($value) $value.status = "physical_authorized" },
    { param($value) $value.held_out_seed_selection.seed = 23195 },
    { param($value) $value.held_out_seed_selection.rejected_candidates[0].token_occurrence_count_at_declaration_parent = 1 },
    { param($value) $value.held_out_seed_selection.first_fresh_candidate_token_occurrence_count_at_declaration_parent = 1 },
    { param($value) $value.finite_population.declared_cell_count = 8 },
    { param($value) $value.fixed_schedule.controller_semantic_step_count = 2991 },
    { param($value) $value.fixed_schedule.startup_transform_by_engine.mujoco = "support_loss_latched_smoothstep_one_cycle_v1" },
    { param($value) $value.thresholds_and_estimator.minimum_positive_raw_cycle_shift_rad = 0.0 },
    { param($value) $value.thresholds_and_estimator.equivalence_margin = 0.1 },
    { param($value) $value.required_zero_world_implementation_gate.full_seeded_world_ghost_required = $true },
    { param($value) $value.post_zero_world_native_smoke.uses_held_out_seed_23197 = $true },
    { param($value) $value.claims.release_score_after = "11/25" }
)) {
    $candidate = $contract | ConvertTo-Json -Depth 100 |
        ConvertFrom-Json -AsHashtable -Depth 100
    & $mutation $candidate
    if (-not (Test-R23D76Shape $candidate)) {
        $mutationRejections += 1
    }
}
Assert-R23D76 ($mutationRejections -eq 12) (
    "declaration mutation controls did not all reject"
)

Write-Output (
    "[turning/3e] R23D76 declaration PASS: seed 23195 rejected (2 parent " +
    "occurrences), seed 23197 fresh, 1 zero-world fixture compiled, 9/9 finite " +
    "cells declared, 12/12 mutations rejected, full ghost=False, bounded smoke " +
    "<=3 worlds x <=2 steps after zero-world only, 0 models/worlds now, " +
    "physical not authorized, score 10/25"
)
