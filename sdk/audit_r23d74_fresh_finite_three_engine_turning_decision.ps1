#requires -Version 7.0

[CmdletBinding()]
param(
    [string]$Godot = "C:\Users\Cole\CodeStuff\Misc\Godot\Godot_v4.7-stable_mono_win64_console.exe"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$sdkRoot = [IO.Path]::GetFullPath($PSScriptRoot)
$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $sdkRoot))
$contractPath = Join-Path $sdkRoot (
    "turning\r23d74_fresh_finite_three_engine_turning_decision_v1.json"
)
$compilerPath = Join-Path $sdkRoot "turning\r23d74_seed_fixture_compiler.gd"
$expectedRoot = "C:\Users\Cole\CodeStuff\games\SporeSpore"
$expectedRemote = "https://github.com/Slagathore/sporespore.git"
$parentCommit = "03c160b7f020e114df099c74154dc04ab57676b5"
$tolerance = 1.0e-15

function Assert-R23D74([bool]$Condition, [string]$Message) {
    if (-not $Condition) {
        throw "[turning/3e] R23D74 declaration audit: $Message"
    }
}

function Get-R23D74Sha256([string]$Path) {
    return "sha256:" + (
        Get-FileHash -LiteralPath $Path -Algorithm SHA256
    ).Hash.ToLowerInvariant()
}

function Get-R23D74GitBlobRawSha256([string]$Commit, [string]$RelativePath) {
    $start = [Diagnostics.ProcessStartInfo]::new()
    $start.FileName = "git"
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    foreach ($argument in @(
        "-C", $repoRoot, "cat-file", "blob", "${Commit}:$RelativePath"
    )) { [void]$start.ArgumentList.Add($argument) }
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $start
    try {
        Assert-R23D74 $process.Start() "could not start Git blob reader"
        $stderrTask = $process.StandardError.ReadToEndAsync()
        $hasher = [Security.Cryptography.SHA256]::Create()
        try { $digest = $hasher.ComputeHash($process.StandardOutput.BaseStream) }
        finally { $hasher.Dispose() }
        $process.WaitForExit()
        $stderr = $stderrTask.GetAwaiter().GetResult()
        Assert-R23D74 ($process.ExitCode -eq 0) (
            "Git blob read failed for $RelativePath`: $stderr"
        )
        return "sha256:" + [Convert]::ToHexString($digest).ToLowerInvariant()
    } finally { $process.Dispose() }
}

function Test-R23D74Shape([hashtable]$Value) {
    $matrix = $Value.finite_population
    $thresholds = $Value.thresholds_and_estimator
    return (
        [string]$Value.schema_version -ceq
            "sporespore_qsdk_r23d74_fresh_finite_three_engine_turning_decision_v1" -and
        [string]$Value.campaign_id -ceq
            "QSDK-R23D74-FRESH-FINITE-THREE-ENGINE-TURNING-DECISION" -and
        [string]$Value.gate_id -ceq "QSDK-R23D74" -and
        [string]$Value.release_gate_id -ceq "QSDK-R23" -and
        [string]$Value.status -ceq
            "prospective_declaration_complete_implementation_pending_physical_not_authorized" -and
        [string]$Value.question_class -ceq "finite_decision" -and
        [bool]$Value.not_development_work -and
        [bool]$Value.not_superiority_work -and
        [bool]$Value.not_equivalence_or_non_inferiority_work -and
        [string]$Value.declaration_parent.commit -ceq $parentCommit -and
        [int]$Value.held_out_seed_selection.seed -eq 23193 -and
        [int]$Value.held_out_seed_selection.previous_consumed_or_outcome_exposed_seed -eq
            23191 -and
        [int]$Value.held_out_seed_selection.first_candidate -eq 23193 -and
        [int]$Value.held_out_seed_selection.first_candidate_token_occurrence_count_at_declaration_parent -eq
            0 -and
        [bool]$Value.held_out_seed_selection.selection_performed_after_development_design_frozen -and
        [bool]$Value.held_out_seed_selection.held_out_for_prospective_native_validation -and
        [int]$Value.seed_fixture_compilation.seed -eq 23193 -and
        [int]$matrix.declared_engine_count -eq 3 -and
        [int]$matrix.declared_arm_count -eq 3 -and
        [int]$matrix.declared_cell_count -eq 9 -and
        @($matrix.ordered_cell_ids).Count -eq 9 -and
        [bool]$matrix.complete_enumeration_required -and
        [bool]$matrix.all_cells_run_regardless_of_intermediate_behavior -and
        -not [bool]$matrix.selective_completion_or_rerun_allowed -and
        [int]$Value.fixed_schedule.controller_semantic_step_count -eq 2992 -and
        [int]$Value.fixed_schedule.commanded_turn_step_count -eq 1200 -and
        [int]$Value.fixed_schedule.forward_displacement_measurement_origin_semantic_step -eq
            472 -and
        [string]$Value.fixed_schedule.mujoco_startup_ramp_id -ceq
            "canonical_velocity_smoothstep_one_gait_cycle_v1" -and
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
        -not [bool]$Value.physical_authorization.physical_execution_authorized -and
        -not [bool]$Value.physical_authorization.physical_acceptance_authority -and
        [bool]$Value.claims.r23d74_declared -and
        [bool]$Value.claims.seed_23193_held_out_to_physics -and
        -not [bool]$Value.claims.implementation_complete -and
        -not [bool]$Value.claims.zero_world_gate_passed -and
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
Assert-R23D74 ($LASTEXITCODE -eq 0) "repository identity unreadable"
Assert-R23D74 ($top -ceq $expectedRoot) "repository root mismatch"
Assert-R23D74 ($remote -ceq $expectedRemote) "origin mismatch"
foreach ($path in @($contractPath, $compilerPath, $Godot)) {
    Assert-R23D74 (Test-Path -LiteralPath $path -PathType Leaf) (
        "required declaration path missing: $path"
    )
}

$contract = Get-Content -LiteralPath $contractPath -Raw |
    ConvertFrom-Json -AsHashtable -Depth 100
Assert-R23D74 (Test-R23D74Shape $contract) (
    "declaration identity, design, threshold, or claim boundary changed"
)
$parentTree = (git -C $repoRoot rev-parse "${parentCommit}^{tree}").Trim()
Assert-R23D74 ($LASTEXITCODE -eq 0) "declaration parent is unavailable"
Assert-R23D74 (
    $parentTree -ceq [string]$contract.declaration_parent.tree_git_oid
) "declaration-parent tree changed"

$seedMatches = @(
    git -C $repoRoot grep -n -P '(^|[^0-9])23193([^0-9]|$)' $parentCommit `
        -- . ':(exclude)sdk/target/**' 2>$null
)
$seedGrepExit = $LASTEXITCODE
Assert-R23D74 ($seedGrepExit -eq 1 -and $seedMatches.Count -eq 0) (
    "seed 23193 was not fresh at the declaration parent"
)

Assert-R23D74 (
    (Get-R23D74Sha256 $compilerPath) -ceq
        [string]$contract.seed_fixture_compilation.compiler_raw_sha256
) "seed compiler digest changed"

foreach ($binding in @(
    @(
        [string]$contract.immutable_predecessors.consumed_r23d71_finite_result.closure_path,
        [string]$contract.immutable_predecessors.consumed_r23d71_finite_result.closure_raw_sha256
    ),
    @(
        [string]$contract.immutable_predecessors.consumed_r23d71_finite_result.closure_audit_path,
        [string]$contract.immutable_predecessors.consumed_r23d71_finite_result.closure_audit_raw_sha256
    ),
    @(
        [string]$contract.immutable_predecessors.closed_three_engine_execution_route.closure_path,
        [string]$contract.immutable_predecessors.closed_three_engine_execution_route.closure_raw_sha256
    ),
    @(
        [string]$contract.immutable_predecessors.closed_three_engine_execution_route.closure_audit_path,
        [string]$contract.immutable_predecessors.closed_three_engine_execution_route.closure_audit_raw_sha256
    ),
    @(
        [string]$contract.immutable_predecessors.prospective_measurement_origin_parity.contract_path,
        [string]$contract.immutable_predecessors.prospective_measurement_origin_parity.contract_raw_sha256
    ),
    @(
        [string]$contract.immutable_predecessors.prospective_measurement_origin_parity.audit_path,
        [string]$contract.immutable_predecessors.prospective_measurement_origin_parity.audit_raw_sha256
    ),
    @(
        [string]$contract.immutable_predecessors.closed_r23d73_mujoco_positive_turn_development.closure_path,
        [string]$contract.immutable_predecessors.closed_r23d73_mujoco_positive_turn_development.closure_raw_sha256
    ),
    @(
        [string]$contract.immutable_predecessors.closed_r23d73_mujoco_positive_turn_development.closure_audit_path,
        [string]$contract.immutable_predecessors.closed_r23d73_mujoco_positive_turn_development.closure_audit_raw_sha256
    ),
    @(
        [string]$contract.thresholds_and_estimator.cycle_estimator_path,
        [string]$contract.thresholds_and_estimator.cycle_estimator_raw_sha256
    ),
    @(
        [string]$contract.thresholds_and_estimator.common_gate_source_path,
        [string]$contract.thresholds_and_estimator.common_gate_source_raw_sha256
    )
)) {
    Assert-R23D74 (
        (Get-R23D74GitBlobRawSha256 $parentCommit $binding[0]) -ceq $binding[1]
    ) "immutable predecessor binding changed: $($binding[0])"
}

$compilerLines = @(
    & $Godot --headless --path $repoRoot --script (
        "res://sdk/turning/r23d74_seed_fixture_compiler.gd"
    ) 2>&1
)
$compilerExit = $LASTEXITCODE
Assert-R23D74 ($compilerExit -eq 0) (
    "seed compiler failed: $($compilerLines -join ' ')"
)
$marker = "QSDK_R23D74_SEED_FIXTURES "
$payloads = @(
    $compilerLines |
        Where-Object { ([string]$_).StartsWith($marker, [StringComparison]::Ordinal) } |
        ForEach-Object { ([string]$_).Substring($marker.Length) }
)
Assert-R23D74 ($payloads.Count -eq 1) "seed compiler marker count changed"
$compiled = $payloads[0] | ConvertFrom-Json -AsHashtable -Depth 100
$fixture = @($compiled.fixtures)[0]
$expectedFixture = $contract.seed_fixture_compilation.compiled_initial_perturbation
Assert-R23D74 (
    [string]$compiled.schema_version -ceq "sporespore_qsdk_r23d74_seed_fixtures_v1" -and
    @($compiled.r23d74_unopened_held_out_seeds).Count -eq 1 -and
    [int]$compiled.r23d74_unopened_held_out_seeds[0] -eq 23193 -and
    @($compiled.fixtures).Count -eq 1 -and
    [int]$compiled.model_construction_count -eq 0 -and
    [int]$compiled.world_attempt_count -eq 0 -and
    [int]$compiled.world_build_count -eq 0 -and
    [int]$fixture.campaign_seed -eq 23193 -and
    [string]$fixture.cohort -ceq "r23d74_unopened_three_engine_held_out_turning" -and
    [Math]::Abs(
        [double]$fixture.fixture_vertical_clearance_m -
        [double]$expectedFixture.fixture_vertical_clearance_m
    ) -le $tolerance -and
    [Math]::Abs(
        [double]$fixture.fixture_yaw_rad - [double]$expectedFixture.fixture_yaw_rad
    ) -le $tolerance -and
    [int]$fixture.gait_phase_offset_ticks -eq 0
) "compiled held-out fixture changed"
foreach ($index in 0..2) {
    Assert-R23D74 (
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
            "r23d74__${engine}__s23193__${arm}"
        }
    }
)
Assert-R23D74 (
    (@($contract.finite_population.ordered_cell_ids) -join "|") -ceq
        ($expectedCells -join "|")
) "ordered finite population changed"

$mutationRejections = 0
foreach ($mutation in @(
    { param($value) $value.status = "physical_authorized" },
    { param($value) $value.held_out_seed_selection.seed = 23195 },
    { param($value) $value.held_out_seed_selection.first_candidate_token_occurrence_count_at_declaration_parent = 1 },
    { param($value) $value.finite_population.declared_cell_count = 8 },
    { param($value) $value.fixed_schedule.controller_semantic_step_count = 2991 },
    { param($value) $value.thresholds_and_estimator.minimum_positive_raw_cycle_shift_rad = 0.0 },
    { param($value) $value.thresholds_and_estimator.equivalence_margin = 0.1 },
    { param($value) $value.physical_authorization.physical_execution_authorized = $true },
    { param($value) $value.claims.release_score_after = "11/25" }
)) {
    $candidate = $contract | ConvertTo-Json -Depth 100 |
        ConvertFrom-Json -AsHashtable -Depth 100
    & $mutation $candidate
    if (-not (Test-R23D74Shape $candidate)) { $mutationRejections += 1 }
}
Assert-R23D74 ($mutationRejections -eq 9) (
    "declaration mutation controls did not all reject"
)

Write-Output (
    "[turning/3e] R23D74 declaration PASS: seed 23193 fresh at parent, " +
    "1 zero-world fixture compiled, 9/9 finite cells declared, " +
    "9/9 mutations rejected, 0 models/worlds, physical not authorized, score 10/25"
)
