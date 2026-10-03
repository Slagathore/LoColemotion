param(
    [string]$Python = "python",
    [string]$Godot = (
        "C:\Users\Cole\CodeStuff\Misc\Godot\" +
        "Godot_v4.7-stable_mono_win64_console.exe"
    ),
    [switch]$SkipGodot
)

$ErrorActionPreference = "Stop"

function Assert-R23D62([bool]$Condition, [string]$Message) {
    if (-not $Condition) {
        throw "QSDK-R23D62 preregistration audit failed: $Message"
    }
}

function Get-R23D62Sha256([string]$Path) {
    return "sha256:$((Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant())"
}

function Assert-R23D62DoubleEqual($Actual, $Expected, [string]$Label) {
    Assert-R23D62 (
        [BitConverter]::DoubleToInt64Bits([double]$Actual) -eq
        [BitConverter]::DoubleToInt64Bits([double]$Expected)
    ) "$Label changed"
}

function Assert-R23D62VectorEqual($Actual, $Expected, [string]$Label) {
    Assert-R23D62 (@($Actual).Count -eq @($Expected).Count) "$Label length changed"
    for ($index = 0; $index -lt @($Expected).Count; $index++) {
        Assert-R23D62DoubleEqual $Actual[$index] $Expected[$index] "$Label value $index"
    }
}

function Find-R23D62Record($Value) {
    if ($null -eq $Value) { return $null }
    if ($Value -is [Collections.IDictionary]) {
        if ($Value.Contains("prospective_r23d62_selected_profile_three_engine_turning_validation")) {
            return $Value["prospective_r23d62_selected_profile_three_engine_turning_validation"]
        }
        foreach ($child in $Value.Values) {
            $found = Find-R23D62Record $child
            if ($null -ne $found) { return $found }
        }
        return $null
    }
    if ($Value -is [Collections.IEnumerable] -and $Value -isnot [string]) {
        foreach ($child in $Value) {
            $found = Find-R23D62Record $child
            if ($null -ne $found) { return $found }
        }
    }
    return $null
}

$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$expectedRoot = "C:\Users\Cole\CodeStuff\games\SporeSpore"
$expectedRemote = "https://github.com/Slagathore/sporespore.git"
$declarationParentCommit = "fa4001578e244deff25cce4dd32d7a0c9e5d3418"
$designPath = Join-Path $repoRoot (
    "sdk\turning\r23d62_selected_profile_three_engine_turning_validation.py"
)
$declarationPath = Join-Path $repoRoot (
    "sdk\turning\r23d62_selected_profile_three_engine_turning_validation_" +
    "preregistration_v1.json"
)
$seedCompilerPath = Join-Path $repoRoot "sdk\turning\r23d62_seed_fixture_compiler.gd"
$r60ClosurePath = Join-Path $repoRoot (
    "sdk\turning\r23d60_godot_fixture_knee_held_out_turning_validation_" +
    "closure_v1.json"
)
$r61ContractPath = Join-Path $repoRoot (
    "sdk\turning\r23d61_selected_actuator_profile_publication_v1.json"
)
$r61ClosurePath = Join-Path $repoRoot (
    "sdk\turning\r23d61_selected_actuator_profile_publication_closure_v1.json"
)
$releaseContractPath = Join-Path $repoRoot "sdk\release\quadruped_release_contract.json"
$supportMatrixPath = Join-Path $repoRoot "sdk\release\quadruped_support_matrix.json"
$workbenchPath = Join-Path $repoRoot "sdk\workbench\experiment_catalog.json"

Assert-R23D62 ($repoRoot.TrimEnd("\") -ceq $expectedRoot) "repository root changed"
Assert-R23D62 (
    (& git -C $repoRoot rev-parse --show-toplevel).Trim().Replace("/", "\") -ceq
    $expectedRoot
) "Git top-level changed"
Assert-R23D62 (
    (& git -C $repoRoot remote get-url origin).Trim() -ceq $expectedRemote
) "origin remote changed"
foreach ($path in @(
    $designPath,
    $declarationPath,
    $seedCompilerPath,
    $r60ClosurePath,
    $r61ContractPath,
    $r61ClosurePath,
    $releaseContractPath,
    $supportMatrixPath,
    $workbenchPath
)) {
    Assert-R23D62 (Test-Path -LiteralPath $path -PathType Leaf) "required file missing: $path"
}

$attributes = Get-Content -Raw -LiteralPath (Join-Path $repoRoot ".gitattributes")
foreach ($rule in @(
    "sdk/turning/r23d62_* text eol=lf",
    "sdk/run_qsdk_r23d62_* text eol=lf",
    "tests/test_qsdk_r23d62_* text eol=lf",
    "tests/test_sdk_qsdk_r23d62_* text eol=lf",
    "sdk/adapters/rapier/src/bin/qsdk_r23d62_* text eol=lf",
    "sdk/adapters/mujoco/sporespore_mujoco_adapter/qsdk_r23d62_* text eol=lf"
)) {
    Assert-R23D62 ($attributes.Contains($rule)) "missing byte-stable rule: $rule"
}

$declaration = Get-Content -Raw -LiteralPath $declarationPath |
    ConvertFrom-Json -AsHashtable -Depth 100
$r60Closure = Get-Content -Raw -LiteralPath $r60ClosurePath |
    ConvertFrom-Json -AsHashtable -Depth 100
$r61Contract = Get-Content -Raw -LiteralPath $r61ContractPath |
    ConvertFrom-Json -AsHashtable -Depth 100
$r61Closure = Get-Content -Raw -LiteralPath $r61ClosurePath |
    ConvertFrom-Json -AsHashtable -Depth 100

Assert-R23D62 (
    [string]$declaration.campaign_id -ceq
        "QSDK-R23D62-SELECTED-PROFILE-MATCHED-THREE-ENGINE-TURNING-VALIDATION" -and
    [string]$declaration.gate_id -ceq "QSDK-R23D62" -and
    [string]$declaration.question_class -ceq "finite_decision" -and
    [bool]$declaration.physical_question_declared -and
    -not [bool]$declaration.physical_campaign_opened
) "campaign identity or finite-decision classification changed"

Assert-R23D62 (
    [string]$r61Closure.status -ceq
        "closed_complete_valid_positive_non_physical_source_conformance" -and
    [bool]$r61Closure.adequacy_and_claim_boundary.exact_scope_profile_published -and
    [bool]$r61Closure.adequacy_and_claim_boundary.godot_configuration_mapping_conformed -and
    [bool]$r61Closure.adequacy_and_claim_boundary.rapier_configuration_mapping_conformed -and
    [bool]$r61Closure.adequacy_and_claim_boundary.mujoco_configuration_mapping_conformed -and
    -not [bool]$r61Closure.adequacy_and_claim_boundary.new_physical_result -and
    -not [bool]$r61Closure.adequacy_and_claim_boundary.finite_three_engine_turning -and
    -not [bool]$r61Closure.adequacy_and_claim_boundary.q_sdk_r23_satisfied
) "R23D61 publication boundary changed"
Assert-R23D62 (
    [string]$declaration.published_profile_binding.profile_id -ceq
        [string]$r61Closure.profile.profile_id -and
    [string]$declaration.published_profile_binding.profile_sha256 -ceq
        [string]$r61Closure.profile.profile_sha256 -and
    [string]$declaration.published_profile_binding.semantics_id -ceq
        [string]$r61Closure.profile.semantics_id -and
    [string]$r61Contract.publication.profile_id -ceq
        [string]$r61Closure.profile.profile_id -and
    [string]$r61Contract.publication.profile_sha256 -ceq
        [string]$r61Closure.profile.profile_sha256 -and
    -not [bool]$declaration.published_profile_binding.legacy_fixture_override_permitted
) "public selected-profile binding changed"

$matrix = $declaration.frozen_matrix
Assert-R23D62 (
    [int]$matrix.seed -eq 23167 -and
    (@($matrix.ordered_engine_ids) -join ",") -ceq
        "godot_jolt,rapier_parry,mujoco" -and
    (@($matrix.ordered_arm_ids) -join ",") -ceq
        "reference_zero,positive_heading,negative_heading" -and
    @($matrix.cells).Count -eq 9 -and
    [int]$matrix.declared_cell_count -eq 9 -and
    [int]$matrix.declared_world_count -eq 9 -and
    [int]$matrix.controller_step_count -eq 2992 -and
    [int]$matrix.turn_start_step -eq 600 -and
    [int]$matrix.turn_end_step_exclusive -eq 1800 -and
    [int]$matrix.recovery_duration_steps -eq 600 -and
    [string]$matrix.controller_policy_id -ceq
        "sporespore_balanced_wave_r23d29_two_swing_persistent_predictive_stability_guarded_steering_v1" -and
    [string]$matrix.task_frame_origin_policy_id -ceq
        "warmup_preserving_command_onset_origin_reanchor_v1" -and
    [string]$matrix.startup_transform_id -ceq
        "support_loss_latched_smoothstep_one_cycle_v1" -and
    [bool]$matrix.serial_execution_required -and
    [bool]$matrix.fresh_world_required_per_cell -and
    [bool]$matrix.all_cells_run_regardless_of_intermediate_outcome -and
    -not [bool]$matrix.engine_identity_is_policy_input -and
    -not [bool]$matrix.arm_identity_is_policy_input
) "matched nine-cell matrix changed"
foreach ($pair in @(
    @($matrix.ordered_heading_offsets_rad[0], 0.0),
    @($matrix.ordered_heading_offsets_rad[1], 0.2),
    @($matrix.ordered_heading_offsets_rad[2], -0.2)
)) {
    Assert-R23D62DoubleEqual $pair[0] $pair[1] "ordered heading offset"
}

foreach ($key in @(
    "minimum_final_forward_displacement_m",
    "maximum_tilt_rad",
    "minimum_torso_height_m",
    "minimum_contact_cycles_per_limb",
    "maximum_torso_ground_contact_step_count",
    "maximum_controller_error_count",
    "maximum_safe_no_actuation_count",
    "maximum_nonfinite_observation_count",
    "maximum_actuator_application_mismatch_count",
    "exact_controller_semantic_step_count",
    "exact_validated_portable_command_count",
    "exact_native_actuation_application_count",
    "maximum_portable_impulse_violation_count"
)) {
    Assert-R23D62 (
        $declaration.frozen_common_physical_gates[$key] -eq
        $r60Closure.threshold_margin_and_cohort_provenance[$key]
    ) "inherited common physical gate changed: $key"
}
Assert-R23D62DoubleEqual (
    $declaration.cycle_integrated_measurement.minimum_raw_signed_cycle_shift_rad
) 0.01 "raw directional-response floor"
Assert-R23D62DoubleEqual (
    $declaration.cycle_integrated_measurement.minimum_reference_conditioned_cycle_shift_rad
) 0.01 "reference-conditioned directional-response floor"
Assert-R23D62 (
    [bool]$declaration.finite_decision_rule.complete_execution_valid_nine_cell_matrix_required -and
    [bool]$declaration.finite_decision_rule.all_nine_cells_must_pass_every_common_physical_gate -and
    [bool]$declaration.finite_decision_rule.each_engine_must_independently_pass_both_turning_gates -and
    [bool]$declaration.finite_decision_rule.positive_qsdk_r23_transition_permitted -and
    -not [bool]$declaration.finite_decision_rule.positive_cross_engine_equivalence -and
    -not [bool]$declaration.finite_decision_rule.early_stop_or_selective_rerun_permitted
) "finite decision rule changed"

$trueClaims = @(
    $declaration.claims.GetEnumerator() |
        Where-Object { [bool]$_.Value } |
        ForEach-Object { [string]$_.Key }
)
Assert-R23D62 (
    $trueClaims.Count -eq 1 -and
    $trueClaims[0] -ceq "r23d62_preregistered" -and
    -not [bool]$declaration.implementation_and_execution_requirements.physical_world_may_open_from_this_declaration_alone
) "preregistration-only claim boundary changed"

$parentSeedUses = @(
    & git -C $repoRoot grep -n -E "(^|[^0-9])23167([^0-9]|`$)" `
        $declarationParentCommit -- sdk tests docs 2>$null
)
Assert-R23D62 ($LASTEXITCODE -in @(0, 1)) "parent seed scan failed"
Assert-R23D62 ($parentSeedUses.Count -eq 0) "held-out seed predates R23D62 declaration"

$oldNoBytecode = $env:PYTHONDONTWRITEBYTECODE
try {
    $env:PYTHONDONTWRITEBYTECODE = "1"
    $pythonOutput = @(& $Python $designPath --declaration $declarationPath 2>&1)
    Assert-R23D62 ($LASTEXITCODE -eq 0) "Python declaration audit failed"
} finally {
    if ($null -eq $oldNoBytecode) {
        Remove-Item Env:PYTHONDONTWRITEBYTECODE -ErrorAction SilentlyContinue
    } else {
        $env:PYTHONDONTWRITEBYTECODE = $oldNoBytecode
    }
}
$auditMarker = @($pythonOutput | Where-Object {
    [string]$_ -like "QSDK_R23D62_DECLARATION_PASS *"
})
Assert-R23D62 ($auditMarker.Count -eq 1) "Python audit marker changed"
$audit = ([string]$auditMarker[0]).Substring(
    "QSDK_R23D62_DECLARATION_PASS ".Length
) | ConvertFrom-Json -AsHashtable
Assert-R23D62 (
    [string]$audit.question_class -ceq "finite_decision" -and
    [int]$audit.engine_count -eq 3 -and
    [int]$audit.arm_count_per_engine -eq 3 -and
    [int]$audit.cell_count -eq 9 -and
    [int]$audit.mutation_rejection_count -eq 35 -and
    [int]$audit.reserved_seed -eq 23167 -and
    [int]$audit.model_construction_count -eq 0 -and
    [int]$audit.world_attempt_count -eq 0 -and
    [int]$audit.world_build_count -eq 0 -and
    -not [bool]$audit.physical_campaign_opened -and
    -not [bool]$audit.finite_three_engine_turning -and
    -not [bool]$audit.q_sdk_r23_satisfied -and
    -not [bool]$audit.release_authority
) "Python audit receipt changed"

$compilerText = Get-Content -Raw -LiteralPath $seedCompilerPath
foreach ($forbidden in @(
    "WaveGaitScript.new(",
    ".run(",
    "add_child(",
    "RigidBody3D",
    "StaticBody3D",
    "PackedScene",
    "instantiate(",
    "await "
)) {
    Assert-R23D62 (-not $compilerText.Contains($forbidden)) (
        "seed compiler contains physical construction token: $forbidden"
    )
}

$godotCompilerRun = $false
if (-not $SkipGodot) {
    Assert-R23D62 (Test-Path -LiteralPath $Godot -PathType Leaf) "Godot executable missing"
    $godotOutput = @(
        & $Godot --headless --path $repoRoot --script `
            "res://sdk/turning/r23d62_seed_fixture_compiler.gd" 2>&1
    )
    Assert-R23D62 ($LASTEXITCODE -eq 0) "Godot seed compiler failed"
    $seedMarker = @($godotOutput | Where-Object {
        [string]$_ -like "QSDK_R23D62_SEED_FIXTURES *"
    })
    Assert-R23D62 ($seedMarker.Count -eq 1) "Godot seed fixture marker changed"
    $receipt = ([string]$seedMarker[0]).Substring(
        "QSDK_R23D62_SEED_FIXTURES ".Length
    ) | ConvertFrom-Json -AsHashtable
    Assert-R23D62 (
        [int]$receipt.model_construction_count -eq 0 -and
        [int]$receipt.world_attempt_count -eq 0 -and
        [int]$receipt.world_build_count -eq 0 -and
        (@($receipt.r23d62_unopened_held_out_seeds) -join ",") -ceq "23167" -and
        @($receipt.fixtures).Count -eq 1
    ) "Godot seed compiler receipt changed"
    $actual = $receipt.fixtures[0]
    $expected = $matrix.initial_perturbation
    foreach ($key in @("fixture_vertical_clearance_m", "fixture_yaw_rad")) {
        Assert-R23D62DoubleEqual $actual[$key] $expected[$key] "compiled $key"
    }
    Assert-R23D62VectorEqual $actual.initial_linear_velocity_world_m_s `
        $expected.initial_linear_velocity_world_m_s "compiled linear velocity"
    Assert-R23D62VectorEqual $actual.initial_torso_angular_velocity_world_rad_s `
        $expected.initial_torso_angular_velocity_world_rad_s "compiled angular velocity"
    Assert-R23D62 (
        [int]$actual.gait_phase_offset_ticks -eq [int]$expected.gait_phase_offset_ticks
    ) "compiled gait phase changed"
    $godotCompilerRun = $true
}

$releaseContract = Get-Content -Raw -LiteralPath $releaseContractPath |
    ConvertFrom-Json -AsHashtable -Depth 100
$supportMatrix = Get-Content -Raw -LiteralPath $supportMatrixPath |
    ConvertFrom-Json -AsHashtable -Depth 100
$turningGates = @($releaseContract.gates | Where-Object {
    [string]$_.gate_id -ceq "QSDK-R23"
})
$contractRecord = if ($turningGates.Count -eq 1) {
    $turningGates[0].proof.prospective_r23d62_selected_profile_three_engine_turning_validation
} else { $null }
$matrixRecord = Find-R23D62Record $supportMatrix
$designHash = Get-R23D62Sha256 $designPath
$declarationHash = Get-R23D62Sha256 $declarationPath
$seedCompilerHash = Get-R23D62Sha256 $seedCompilerPath
$auditHash = Get-R23D62Sha256 ([IO.Path]::GetFullPath($PSCommandPath))
Assert-R23D62 (
    $null -ne $contractRecord -and
    $null -ne $matrixRecord -and
    [string]$turningGates[0].proof.kind -ceq "missing" -and
    [string]$turningGates[0].proof.current_prospective_successor_status -ceq
        "r23d62_closed_consumed_invalid_incomplete_before_first_world_authorization_receipt_schema_projection_failure" -and
    [string]$contractRecord.status -ceq
        "closed_consumed_invalid_incomplete_before_first_world_authorization_receipt_schema_projection_failure" -and
    [string]$matrixRecord.status -ceq [string]$contractRecord.status -and
    [string]$contractRecord.question_class -ceq "finite_decision" -and
    [string]$matrixRecord.question_class -ceq "finite_decision" -and
    [string]$contractRecord.preregistration_raw_sha256 -ceq $declarationHash -and
    [string]$matrixRecord.preregistration_sha256 -ceq $declarationHash -and
    [string]$contractRecord.design_raw_sha256 -ceq $designHash -and
    [string]$matrixRecord.design_sha256 -ceq $designHash -and
    [string]$contractRecord.seed_fixture_compiler_raw_sha256 -ceq $seedCompilerHash -and
    [string]$matrixRecord.seed_fixture_compiler_sha256 -ceq $seedCompilerHash -and
    [string]$contractRecord.local_declaration_audit_raw_sha256 -ceq $auditHash -and
    [string]$matrixRecord.local_declaration_audit_sha256 -ceq $auditHash -and
    [int]$contractRecord.reserved_seed -eq 23167 -and
    [int]$matrixRecord.reserved_seed -eq 23167 -and
    [int]$contractRecord.declared_world_count -eq 9 -and
    [int]$matrixRecord.declared_world_count -eq 9 -and
    [int]$contractRecord.local_mutation_rejection_count -eq 35 -and
    [int]$matrixRecord.local_mutation_rejection_count -eq 35 -and
    [bool]$contractRecord.local_declaration_gate_passed -and
    [bool]$matrixRecord.local_declaration_gate_passed -and
    [bool]$contractRecord.implementation_complete -and
    [bool]$matrixRecord.implementation_complete -and
    [int]$contractRecord.dependency_closure_path_count -eq 221 -and
    [int]$matrixRecord.dependency_closure_path_count -eq 221 -and
    [int]$contractRecord.dependency_closure_edge_count -eq 219 -and
    [int]$matrixRecord.dependency_closure_edge_count -eq 219 -and
    [string]$contractRecord.supervisor_path -ceq
        "sdk/run_qsdk_r23d62_supervisor.ps1" -and
    [string]$matrixRecord.supervisor_path -ceq
        [string]$contractRecord.supervisor_path -and
    [string]$contractRecord.campaign_roles_gate_path -ceq
        "tests/test_qsdk_r23d62_campaign_roles.ps1" -and
    [string]$matrixRecord.campaign_roles_gate_path -ceq
        [string]$contractRecord.campaign_roles_gate_path -and
    [int]$contractRecord.complete_zero_world_gate_count -eq 12 -and
    [int]$matrixRecord.complete_zero_world_gate_count -eq 12 -and
    [int]$contractRecord.complete_zero_world_worker_preflight_count -eq 9 -and
    [int]$matrixRecord.complete_zero_world_worker_preflight_count -eq 9 -and
    [bool]$contractRecord.complete_campaign_zero_world_gate_passed -and
    [bool]$matrixRecord.complete_campaign_zero_world_gate_passed -and
    [bool]$contractRecord.clean_pushed_qualification_retained -and
    [bool]$matrixRecord.clean_pushed_qualification_retained -and
    [string]$contractRecord.qualification_source_commit -ceq
        "93d31e8eceeab519692f03470f20c9da5a86cc63" -and
    [string]$matrixRecord.qualification_source_commit -ceq
        [string]$contractRecord.qualification_source_commit -and
    [string]$contractRecord.qualification_attestation_raw_sha256 -ceq
        "sha256:46e609462cb82d8d4b56c9c77f8d89f974160acfb011cf08c1b8dec46927eca0" -and
    [string]$matrixRecord.qualification_attestation_raw_sha256 -ceq
        [string]$contractRecord.qualification_attestation_raw_sha256 -and
    [int]$contractRecord.qualification_executed_gate_count -eq 22 -and
    [int]$matrixRecord.qualification_executed_gate_count -eq 22 -and
    [int]$contractRecord.qualification_gate_cas_reference_count -eq 66 -and
    [int]$matrixRecord.qualification_gate_cas_reference_count -eq 66 -and
    [int]$contractRecord.qualification_gate_cas_unique_object_count -eq 46 -and
    [int]$matrixRecord.qualification_gate_cas_unique_object_count -eq 46 -and
    [int]$contractRecord.qualification_physical_world_count -eq 0 -and
    [int]$matrixRecord.qualification_physical_world_count -eq 0 -and
    [bool]$contractRecord.qualification_adoption_attempted -and
    [bool]$matrixRecord.qualification_adoption_attempted -and
    -not [bool]$contractRecord.campaign_attestation_adopted -and
    -not [bool]$matrixRecord.campaign_attestation_adopted -and
    [string]$contractRecord.adoption_refusal_failure_message -ceq
        "Commissioned executor source changed: sdk/run_conformance.ps1" -and
    [string]$matrixRecord.adoption_refusal_failure_message -ceq
        [string]$contractRecord.adoption_refusal_failure_message -and
    [int]$contractRecord.commissioned_core_source_binding_match_count -eq 9 -and
    [int]$matrixRecord.commissioned_core_source_binding_match_count -eq 9 -and
    [int]$contractRecord.commissioned_core_source_binding_mismatch_count -eq 1 -and
    [int]$matrixRecord.commissioned_core_source_binding_mismatch_count -eq 1 -and
    [string]$contractRecord.lca1_rc8_status -ceq
        "closed_negative_full_stage_4_r23d62_preregistration_live_authority_expectation_mismatch_scoped_not_started" -and
    [string]$matrixRecord.lca1_rc8_status -ceq
        [string]$contractRecord.lca1_rc8_status -and
    [bool]$contractRecord.lca1_rc8_full_half_attempted -and
    [bool]$matrixRecord.lca1_rc8_full_half_attempted -and
    -not [bool]$contractRecord.lca1_rc8_pair_completed -and
    -not [bool]$matrixRecord.lca1_rc8_pair_completed -and
    [string]$contractRecord.lca1_rc8_incident_path -ceq
        "sdk/locomotion_campaign_attestation_v1_recommissioning_rc8_incident.json" -and
    [string]$matrixRecord.lca1_rc8_incident_path -ceq
        [string]$contractRecord.lca1_rc8_incident_path -and
    [string]$contractRecord.lca1_rc8_incident_raw_sha256 -ceq
        "sha256:10163fd4023f5ef816af71af7e2f883390cb73c9b38d4e7b29709378bbf2c28b" -and
    [string]$matrixRecord.lca1_rc8_incident_raw_sha256 -ceq
        [string]$contractRecord.lca1_rc8_incident_raw_sha256 -and
    [string]$contractRecord.lca1_rc8_incident_audit_path -ceq
        "tests/test_locomotion_campaign_attestation_v1_recommissioning_rc8_incident.ps1" -and
    [string]$matrixRecord.lca1_rc8_incident_audit_path -ceq
        [string]$contractRecord.lca1_rc8_incident_audit_path -and
    [string]$contractRecord.lca1_rc8_incident_audit_raw_sha256 -ceq
        "sha256:a049437f51a581c42d43933c3d215016e4eec08fd470641f34f3195a29186a6c" -and
    [string]$matrixRecord.lca1_rc8_incident_audit_raw_sha256 -ceq
        [string]$contractRecord.lca1_rc8_incident_audit_raw_sha256 -and
    [string]$contractRecord.lca1_rc9_program_id -ceq
        "LCA1-RC9-R23D62-PREREGISTRATION-LIVE-AUTHORITY-RECONCILIATION" -and
    [string]$matrixRecord.lca1_rc9_program_id -ceq
        [string]$contractRecord.lca1_rc9_program_id -and
    [string]$contractRecord.lca1_rc9_status -ceq
        "closed_negative_full_stage_4_r23d62_rapier_route_live_authority_expectation_mismatch_scoped_not_started" -and
    [string]$matrixRecord.lca1_rc9_status -ceq
        [string]$contractRecord.lca1_rc9_status -and
    [string]$contractRecord.lca1_rc9_question_class -ceq
        "equivalence_non_inferiority" -and
    [string]$matrixRecord.lca1_rc9_question_class -ceq
        [string]$contractRecord.lca1_rc9_question_class -and
    [int]$contractRecord.lca1_rc9_failing_audit_source_change_count -eq 1 -and
    [int]$matrixRecord.lca1_rc9_failing_audit_source_change_count -eq 1 -and
    [int]$contractRecord.lca1_rc9_runner_source_change_count -eq 0 -and
    [int]$matrixRecord.lca1_rc9_runner_source_change_count -eq 0 -and
    [int]$contractRecord.lca1_rc9_campaign_semantics_change_count -eq 0 -and
    [int]$matrixRecord.lca1_rc9_campaign_semantics_change_count -eq 0 -and
    [bool]$contractRecord.lca1_rc9_complete_full_scoped_pair_required -and
    [bool]$matrixRecord.lca1_rc9_complete_full_scoped_pair_required -and
    [int]$contractRecord.lca1_rc9_full_required_stage_count -eq 8 -and
    [int]$matrixRecord.lca1_rc9_full_required_stage_count -eq 8 -and
    [int]$contractRecord.lca1_rc9_scoped_required_executed_gate_count -eq 16 -and
    [int]$matrixRecord.lca1_rc9_scoped_required_executed_gate_count -eq 16 -and
    [int]$contractRecord.lca1_rc9_source_runtime_host_identity_margin -eq 0 -and
    [int]$matrixRecord.lca1_rc9_source_runtime_host_identity_margin -eq 0 -and
    [int]$contractRecord.lca1_rc9_claim_vector_margin -eq 0 -and
    [int]$matrixRecord.lca1_rc9_claim_vector_margin -eq 0 -and
    -not [bool]$contractRecord.lca1_rc9_prior_result_reuse_allowed -and
    -not [bool]$matrixRecord.lca1_rc9_prior_result_reuse_allowed -and
    -not [bool]$contractRecord.lca1_rc9_pair_executed -and
    -not [bool]$matrixRecord.lca1_rc9_pair_executed -and
    [bool]$contractRecord.lca1_rc9_full_half_attempted -and
    [bool]$matrixRecord.lca1_rc9_full_half_attempted -and
    -not [bool]$contractRecord.lca1_rc9_commissioning_passed -and
    -not [bool]$matrixRecord.lca1_rc9_commissioning_passed -and
    [int]$contractRecord.lca1_rc9_physical_world_count -eq 0 -and
    [int]$matrixRecord.lca1_rc9_physical_world_count -eq 0 -and
    [string]$contractRecord.lca1_rc9_source_commit -ceq
        "8d55aad2b19d88d80455fc16ae9b9ce74cdd7b7e" -and
    [string]$matrixRecord.lca1_rc9_source_commit -ceq
        [string]$contractRecord.lca1_rc9_source_commit -and
    [string]$contractRecord.lca1_rc9_source_tree_git_oid -ceq
        "2da6b343a5b6197f3f3e286da7573e139bb6e412" -and
    [string]$matrixRecord.lca1_rc9_source_tree_git_oid -ceq
        [string]$contractRecord.lca1_rc9_source_tree_git_oid -and
    [string]$contractRecord.lca1_rc9_full_run_receipt_raw_sha256 -ceq
        "sha256:98775688881bfcccf6e9288502a21b6c5a2757179ffa27e75ebd117837c9792f" -and
    [string]$matrixRecord.lca1_rc9_full_run_receipt_raw_sha256 -ceq
        [string]$contractRecord.lca1_rc9_full_run_receipt_raw_sha256 -and
    [int]$contractRecord.lca1_rc9_passed_stage_count -eq 3 -and
    [int]$matrixRecord.lca1_rc9_passed_stage_count -eq 3 -and
    [int]$contractRecord.lca1_rc9_failed_stage_count -eq 1 -and
    [int]$matrixRecord.lca1_rc9_failed_stage_count -eq 1 -and
    [string]$contractRecord.lca1_rc9_inner_failure_code -ceq
        "QSDK_R23D62_RAP_ROUTE_AUTHORITY_STATUS_INVALID" -and
    [string]$matrixRecord.lca1_rc9_inner_failure_code -ceq
        [string]$contractRecord.lca1_rc9_inner_failure_code -and
    -not [bool]$contractRecord.lca1_rc9_scoped_attempted -and
    -not [bool]$matrixRecord.lca1_rc9_scoped_attempted -and
    [int]$contractRecord.lca1_rc9_executed_mismatched_value_count -eq 2 -and
    [int]$matrixRecord.lca1_rc9_executed_mismatched_value_count -eq 2 -and
    [int]$contractRecord.lca1_rc9_prospectively_identified_same_defect_consumer_count -eq 3 -and
    [int]$matrixRecord.lca1_rc9_prospectively_identified_same_defect_consumer_count -eq 3 -and
    [string]$contractRecord.lca1_rc9_incident_path -ceq
        "sdk/locomotion_campaign_attestation_v1_recommissioning_rc9_incident.json" -and
    [string]$matrixRecord.lca1_rc9_incident_path -ceq
        [string]$contractRecord.lca1_rc9_incident_path -and
    [string]$contractRecord.lca1_rc9_incident_raw_sha256 -ceq
        "sha256:c012ee33662aeadeeb54b0fa785f376d48a48e44b4e5ed34bfbe13576bb1b0b6" -and
    [string]$matrixRecord.lca1_rc9_incident_raw_sha256 -ceq
        [string]$contractRecord.lca1_rc9_incident_raw_sha256 -and
    [string]$contractRecord.lca1_rc9_incident_audit_path -ceq
        "tests/test_locomotion_campaign_attestation_v1_recommissioning_rc9_incident.ps1" -and
    [string]$matrixRecord.lca1_rc9_incident_audit_path -ceq
        [string]$contractRecord.lca1_rc9_incident_audit_path -and
    [string]$contractRecord.lca1_rc9_incident_audit_raw_sha256 -ceq
        "sha256:2b489f31e1a591418e6618dddec728639d249cc58a8cb1d0a42b22974ac628a3" -and
    [string]$matrixRecord.lca1_rc9_incident_audit_raw_sha256 -ceq
        [string]$contractRecord.lca1_rc9_incident_audit_raw_sha256 -and
    [string]$contractRecord.lca1_rc10_program_id -ceq
        "LCA1-RC10-R23D62-ROUTE-LIVE-AUTHORITY-RECONCILIATION" -and
    [string]$matrixRecord.lca1_rc10_program_id -ceq
        [string]$contractRecord.lca1_rc10_program_id -and
    [string]$contractRecord.lca1_rc10_status -ceq
        "closed_negative_full_stage_6_r24d3_live_source_manifest_binding_drift_scoped_not_started" -and
    [string]$matrixRecord.lca1_rc10_status -ceq
        [string]$contractRecord.lca1_rc10_status -and
    [string]$contractRecord.lca1_rc10_question_class -ceq
        "equivalence_non_inferiority" -and
    [string]$matrixRecord.lca1_rc10_question_class -ceq
        [string]$contractRecord.lca1_rc10_question_class -and
    [int]$contractRecord.lca1_rc10_live_authority_consumer_change_count -eq 4 -and
    [int]$matrixRecord.lca1_rc10_live_authority_consumer_change_count -eq 4 -and
    [int]$contractRecord.lca1_rc10_runner_source_change_count -eq 0 -and
    [int]$matrixRecord.lca1_rc10_runner_source_change_count -eq 0 -and
    [int]$contractRecord.lca1_rc10_campaign_semantics_change_count -eq 0 -and
    [int]$matrixRecord.lca1_rc10_campaign_semantics_change_count -eq 0 -and
    [bool]$contractRecord.lca1_rc10_complete_full_scoped_pair_required -and
    [bool]$matrixRecord.lca1_rc10_complete_full_scoped_pair_required -and
    [int]$contractRecord.lca1_rc10_full_required_stage_count -eq 8 -and
    [int]$matrixRecord.lca1_rc10_full_required_stage_count -eq 8 -and
    [int]$contractRecord.lca1_rc10_scoped_required_executed_gate_count -eq 16 -and
    [int]$matrixRecord.lca1_rc10_scoped_required_executed_gate_count -eq 16 -and
    [int]$contractRecord.lca1_rc10_source_runtime_host_identity_margin -eq 0 -and
    [int]$matrixRecord.lca1_rc10_source_runtime_host_identity_margin -eq 0 -and
    [int]$contractRecord.lca1_rc10_claim_vector_margin -eq 0 -and
    [int]$matrixRecord.lca1_rc10_claim_vector_margin -eq 0 -and
    -not [bool]$contractRecord.lca1_rc10_prior_result_reuse_allowed -and
    -not [bool]$matrixRecord.lca1_rc10_prior_result_reuse_allowed -and
    -not [bool]$contractRecord.lca1_rc10_pair_executed -and
    -not [bool]$matrixRecord.lca1_rc10_pair_executed -and
    [bool]$contractRecord.lca1_rc10_full_half_attempted -and
    [bool]$matrixRecord.lca1_rc10_full_half_attempted -and
    -not [bool]$contractRecord.lca1_rc10_commissioning_passed -and
    -not [bool]$matrixRecord.lca1_rc10_commissioning_passed -and
    [int]$contractRecord.lca1_rc10_physical_world_count -eq 0 -and
    [int]$matrixRecord.lca1_rc10_physical_world_count -eq 0 -and
    [string]$contractRecord.lca1_rc10_source_commit -ceq
        "fad968e7609a4f15fcd4ade834f953cd0e972eec" -and
    [string]$matrixRecord.lca1_rc10_source_commit -ceq
        [string]$contractRecord.lca1_rc10_source_commit -and
    [string]$contractRecord.lca1_rc10_source_tree_git_oid -ceq
        "df6218701b6a0d33655970a1ba08dbf1d038d7b9" -and
    [string]$matrixRecord.lca1_rc10_source_tree_git_oid -ceq
        [string]$contractRecord.lca1_rc10_source_tree_git_oid -and
    [string]$contractRecord.lca1_rc10_full_run_receipt_raw_sha256 -ceq
        "sha256:5889d7b74a0785c50f03e067d17de8e5f5f71fa0fe826c1327abd199daadafbd" -and
    [string]$matrixRecord.lca1_rc10_full_run_receipt_raw_sha256 -ceq
        [string]$contractRecord.lca1_rc10_full_run_receipt_raw_sha256 -and
    [int]$contractRecord.lca1_rc10_passed_stage_count -eq 5 -and
    [int]$matrixRecord.lca1_rc10_passed_stage_count -eq 5 -and
    [int]$contractRecord.lca1_rc10_failed_stage_count -eq 1 -and
    [int]$matrixRecord.lca1_rc10_failed_stage_count -eq 1 -and
    [string]$contractRecord.lca1_rc10_first_failed_stage_id -ceq
        "godot_runtime_regression" -and
    [string]$matrixRecord.lca1_rc10_first_failed_stage_id -ceq
        [string]$contractRecord.lca1_rc10_first_failed_stage_id -and
    [string]$contractRecord.lca1_rc10_failure_message -ceq
        "QSDK-R24D3: Manifest source binding drifted: .gitattributes" -and
    [string]$matrixRecord.lca1_rc10_failure_message -ceq
        [string]$contractRecord.lca1_rc10_failure_message -and
    [string]$contractRecord.lca1_rc10_inner_failure_code -ceq
        "QSDK_R24D3_MANIFEST_SOURCE_BINDING_DRIFT" -and
    [string]$matrixRecord.lca1_rc10_inner_failure_code -ceq
        [string]$contractRecord.lca1_rc10_inner_failure_code -and
    -not [bool]$contractRecord.lca1_rc10_scoped_attempted -and
    -not [bool]$matrixRecord.lca1_rc10_scoped_attempted -and
    [int]$contractRecord.lca1_rc10_r24d3_manifest_matching_binding_count -eq 10 -and
    [int]$matrixRecord.lca1_rc10_r24d3_manifest_matching_binding_count -eq 10 -and
    [int]$contractRecord.lca1_rc10_r24d3_manifest_stale_binding_count -eq 4 -and
    [int]$matrixRecord.lca1_rc10_r24d3_manifest_stale_binding_count -eq 4 -and
    [bool]$contractRecord.lca1_rc10_r23d62_stage4_passed -and
    [bool]$matrixRecord.lca1_rc10_r23d62_stage4_passed -and
    [string]$contractRecord.lca1_rc10_incident_path -ceq
        "sdk/locomotion_campaign_attestation_v1_recommissioning_rc10_incident.json" -and
    [string]$matrixRecord.lca1_rc10_incident_path -ceq
        [string]$contractRecord.lca1_rc10_incident_path -and
    [string]$contractRecord.lca1_rc10_incident_raw_sha256 -ceq
        "sha256:fe470ea3cd04154c49a439835bd2ad3a47ca66113a51af5ee4e041955203c87c" -and
    [string]$matrixRecord.lca1_rc10_incident_raw_sha256 -ceq
        [string]$contractRecord.lca1_rc10_incident_raw_sha256 -and
    [string]$contractRecord.lca1_rc10_incident_audit_path -ceq
        "tests/test_locomotion_campaign_attestation_v1_recommissioning_rc10_incident.ps1" -and
    [string]$matrixRecord.lca1_rc10_incident_audit_path -ceq
        [string]$contractRecord.lca1_rc10_incident_audit_path -and
    [string]$contractRecord.lca1_rc10_incident_audit_raw_sha256 -ceq
        "sha256:7c9c67cb939e0adae3e69716dbfd3b4d7ba03575631ec2c9724fbe70e12d7495" -and
    [string]$matrixRecord.lca1_rc10_incident_audit_raw_sha256 -ceq
        [string]$contractRecord.lca1_rc10_incident_audit_raw_sha256 -and
    [string]$contractRecord.lca1_rc11_program_id -ceq
        "LCA1-RC11-R24D3-LIVE-SOURCE-AUDIT-RECONCILIATION" -and
    [string]$matrixRecord.lca1_rc11_program_id -ceq
        [string]$contractRecord.lca1_rc11_program_id -and
    [string]$contractRecord.lca1_rc11_status -ceq
        "closed_negative_full_stage_6_r24d2_live_source_manifest_binding_drift_scoped_not_started" -and
    [string]$matrixRecord.lca1_rc11_status -ceq
        [string]$contractRecord.lca1_rc11_status -and
    [string]$contractRecord.lca1_rc11_question_class -ceq
        "equivalence_non_inferiority" -and
    [string]$matrixRecord.lca1_rc11_question_class -ceq
        [string]$contractRecord.lca1_rc11_question_class -and
    [int]$contractRecord.lca1_rc11_r24d3_live_manifest_binding_reconciliation_count -eq 4 -and
    [int]$matrixRecord.lca1_rc11_r24d3_live_manifest_binding_reconciliation_count -eq 4 -and
    [int]$contractRecord.lca1_rc11_r24d3_live_manifest_field_repair_count -eq 8 -and
    [int]$matrixRecord.lca1_rc11_r24d3_live_manifest_field_repair_count -eq 8 -and
    [int]$contractRecord.lca1_rc11_r24d3_historical_toolchain_audit_semantic_repair_count -eq 1 -and
    [int]$matrixRecord.lca1_rc11_r24d3_historical_toolchain_audit_semantic_repair_count -eq 1 -and
    [int]$contractRecord.lca1_rc11_live_authority_consumer_change_count -eq 4 -and
    [int]$matrixRecord.lca1_rc11_live_authority_consumer_change_count -eq 4 -and
    [int]$contractRecord.lca1_rc11_implementation_hash_binding_change_count -eq 3 -and
    [int]$matrixRecord.lca1_rc11_implementation_hash_binding_change_count -eq 3 -and
    [int]$contractRecord.lca1_rc11_campaign_manifest_binding_refresh_count -eq 3 -and
    [int]$matrixRecord.lca1_rc11_campaign_manifest_binding_refresh_count -eq 3 -and
    [int]$contractRecord.lca1_rc11_runner_source_change_count -eq 0 -and
    [int]$matrixRecord.lca1_rc11_runner_source_change_count -eq 0 -and
    [int]$contractRecord.lca1_rc11_campaign_semantics_change_count -eq 0 -and
    [int]$matrixRecord.lca1_rc11_campaign_semantics_change_count -eq 0 -and
    [string]$contractRecord.lca1_rc11_freeze_path -ceq
        "sdk/locomotion_campaign_attestation_v1_recommissioning_rc11_freeze.json" -and
    [string]$matrixRecord.lca1_rc11_freeze_path -ceq
        [string]$contractRecord.lca1_rc11_freeze_path -and
    [string]$contractRecord.lca1_rc11_manifest_path -ceq
        "sdk/locomotion_campaign_attestation_v1_recommissioning_rc11_manifest.json" -and
    [string]$matrixRecord.lca1_rc11_manifest_path -ceq
        [string]$contractRecord.lca1_rc11_manifest_path -and
    [string]$contractRecord.lca1_rc11_freeze_audit_path -ceq
        "tests/test_locomotion_campaign_attestation_v1_recommissioning_rc11_freeze.ps1" -and
    [string]$matrixRecord.lca1_rc11_freeze_audit_path -ceq
        [string]$contractRecord.lca1_rc11_freeze_audit_path -and
    [bool]$contractRecord.lca1_rc11_complete_full_scoped_pair_required -and
    [bool]$matrixRecord.lca1_rc11_complete_full_scoped_pair_required -and
    [int]$contractRecord.lca1_rc11_full_required_stage_count -eq 8 -and
    [int]$matrixRecord.lca1_rc11_full_required_stage_count -eq 8 -and
    [int]$contractRecord.lca1_rc11_scoped_required_executed_gate_count -eq 16 -and
    [int]$matrixRecord.lca1_rc11_scoped_required_executed_gate_count -eq 16 -and
    [int]$contractRecord.lca1_rc11_source_runtime_host_identity_margin -eq 0 -and
    [int]$matrixRecord.lca1_rc11_source_runtime_host_identity_margin -eq 0 -and
    [int]$contractRecord.lca1_rc11_claim_vector_margin -eq 0 -and
    [int]$matrixRecord.lca1_rc11_claim_vector_margin -eq 0 -and
    -not [bool]$contractRecord.lca1_rc11_prior_result_reuse_allowed -and
    -not [bool]$matrixRecord.lca1_rc11_prior_result_reuse_allowed -and
    -not [bool]$contractRecord.lca1_rc11_pair_executed -and
    -not [bool]$matrixRecord.lca1_rc11_pair_executed -and
    [bool]$contractRecord.lca1_rc11_full_half_attempted -and
    [bool]$matrixRecord.lca1_rc11_full_half_attempted -and
    -not [bool]$contractRecord.lca1_rc11_commissioning_passed -and
    -not [bool]$matrixRecord.lca1_rc11_commissioning_passed -and
    [int]$contractRecord.lca1_rc11_physical_world_count -eq 0 -and
    [int]$matrixRecord.lca1_rc11_physical_world_count -eq 0 -and
    [string]$contractRecord.lca1_rc11_source_commit -ceq
        "2b109c2f791531d875d63704f970fcaded1eb433" -and
    [string]$matrixRecord.lca1_rc11_source_commit -ceq
        [string]$contractRecord.lca1_rc11_source_commit -and
    [string]$contractRecord.lca1_rc11_source_tree_git_oid -ceq
        "d8700c2cd5d066302dc9cef6d2a2005465381262" -and
    [string]$matrixRecord.lca1_rc11_source_tree_git_oid -ceq
        [string]$contractRecord.lca1_rc11_source_tree_git_oid -and
    [string]$contractRecord.lca1_rc11_full_run_receipt_path -ceq
        "C:/Users/Cole/CodeStuff/games/SporeSpore_Evidence/conformance-runs/20260825T002211Z-2b109c2f-d9d6a44cb03c4977adaa022e4781dd5a/receipt.json" -and
    [string]$matrixRecord.lca1_rc11_full_run_receipt_path -ceq
        [string]$contractRecord.lca1_rc11_full_run_receipt_path -and
    [string]$contractRecord.lca1_rc11_full_run_receipt_raw_sha256 -ceq
        "sha256:0c871f9b33170872c34064e15998ef5a3b10750c96da915f370787728e62e7c3" -and
    [string]$matrixRecord.lca1_rc11_full_run_receipt_raw_sha256 -ceq
        [string]$contractRecord.lca1_rc11_full_run_receipt_raw_sha256 -and
    [double]$contractRecord.lca1_rc11_full_duration_seconds -eq 1015.2435862 -and
    [double]$matrixRecord.lca1_rc11_full_duration_seconds -eq 1015.2435862 -and
    [int]$contractRecord.lca1_rc11_passed_stage_count -eq 5 -and
    [int]$matrixRecord.lca1_rc11_passed_stage_count -eq 5 -and
    [int]$contractRecord.lca1_rc11_failed_stage_count -eq 1 -and
    [int]$matrixRecord.lca1_rc11_failed_stage_count -eq 1 -and
    [string]$contractRecord.lca1_rc11_first_failed_stage_id -ceq "godot_runtime_regression" -and
    [string]$matrixRecord.lca1_rc11_first_failed_stage_id -ceq
        [string]$contractRecord.lca1_rc11_first_failed_stage_id -and
    [string]$contractRecord.lca1_rc11_failure_message -ceq
        "QSDK-R24D2: Manifest source binding drifted: .gitattributes" -and
    [string]$matrixRecord.lca1_rc11_failure_message -ceq
        [string]$contractRecord.lca1_rc11_failure_message -and
    [string]$contractRecord.lca1_rc11_inner_failure_code -ceq
        "QSDK_R24D2_MANIFEST_SOURCE_BINDING_DRIFT" -and
    [string]$matrixRecord.lca1_rc11_inner_failure_code -ceq
        [string]$contractRecord.lca1_rc11_inner_failure_code -and
    -not [bool]$contractRecord.lca1_rc11_scoped_attempted -and
    -not [bool]$matrixRecord.lca1_rc11_scoped_attempted -and
    [int]$contractRecord.lca1_rc11_r24d2_manifest_matching_binding_count -eq 18 -and
    [int]$matrixRecord.lca1_rc11_r24d2_manifest_matching_binding_count -eq 18 -and
    [int]$contractRecord.lca1_rc11_r24d2_manifest_stale_binding_count -eq 15 -and
    [int]$matrixRecord.lca1_rc11_r24d2_manifest_stale_binding_count -eq 15 -and
    [bool]$contractRecord.lca1_rc11_r24d3_gate_passed -and
    [bool]$matrixRecord.lca1_rc11_r24d3_gate_passed -and
    [bool]$contractRecord.lca1_rc11_r23d62_stage4_passed -and
    [bool]$matrixRecord.lca1_rc11_r23d62_stage4_passed -and
    [string]$contractRecord.lca1_rc11_incident_path -ceq
        "sdk/locomotion_campaign_attestation_v1_recommissioning_rc11_incident.json" -and
    [string]$matrixRecord.lca1_rc11_incident_path -ceq
        [string]$contractRecord.lca1_rc11_incident_path -and
    [string]$contractRecord.lca1_rc11_incident_raw_sha256 -ceq
        "sha256:85f20e739f726e2858fc0bb77668b54cd863753c4d166ff9a0a4149af9fbd149" -and
    [string]$matrixRecord.lca1_rc11_incident_raw_sha256 -ceq
        [string]$contractRecord.lca1_rc11_incident_raw_sha256 -and
    [string]$contractRecord.lca1_rc11_incident_audit_path -ceq
        "tests/test_locomotion_campaign_attestation_v1_recommissioning_rc11_incident.ps1" -and
    [string]$matrixRecord.lca1_rc11_incident_audit_path -ceq
        [string]$contractRecord.lca1_rc11_incident_audit_path -and
    [string]$contractRecord.lca1_rc11_incident_audit_raw_sha256 -ceq
        "sha256:bc1434159b78ac40d159f7db06d44ec240fec4f096a82cf179940030061ae544" -and
    [string]$matrixRecord.lca1_rc11_incident_audit_raw_sha256 -ceq
        [string]$contractRecord.lca1_rc11_incident_audit_raw_sha256 -and
    [string]$contractRecord.lca1_rc12_program_id -ceq
        "LCA1-RC12-R24D2-LIVE-SOURCE-AUDIT-RECONCILIATION" -and
    [string]$matrixRecord.lca1_rc12_program_id -ceq
        [string]$contractRecord.lca1_rc12_program_id -and
    [string]$contractRecord.lca1_rc12_status -ceq
        "closed_positive_exact_same_source_full_scoped_pair_cas_claim_vector_and_serialization_verified" -and
    [string]$matrixRecord.lca1_rc12_status -ceq
        [string]$contractRecord.lca1_rc12_status -and
    [string]$contractRecord.lca1_rc12_question_class -ceq
        "equivalence_non_inferiority" -and
    [string]$matrixRecord.lca1_rc12_question_class -ceq
        [string]$contractRecord.lca1_rc12_question_class -and
    [int]$contractRecord.lca1_rc12_r24d2_live_manifest_binding_reconciliation_count -eq 15 -and
    [int]$matrixRecord.lca1_rc12_r24d2_live_manifest_binding_reconciliation_count -eq 15 -and
    [int]$contractRecord.lca1_rc12_r24d2_live_manifest_field_repair_count -eq 30 -and
    [int]$matrixRecord.lca1_rc12_r24d2_live_manifest_field_repair_count -eq 30 -and
    [int]$contractRecord.lca1_rc12_r24d2_recovery_contract_change_count -eq 0 -and
    [int]$matrixRecord.lca1_rc12_r24d2_recovery_contract_change_count -eq 0 -and
    [int]$contractRecord.lca1_rc12_r24d2_recovery_semantics_change_count -eq 0 -and
    [int]$matrixRecord.lca1_rc12_r24d2_recovery_semantics_change_count -eq 0 -and
    [int]$contractRecord.lca1_rc12_live_authority_consumer_change_count -eq 4 -and
    [int]$matrixRecord.lca1_rc12_live_authority_consumer_change_count -eq 4 -and
    [int]$contractRecord.lca1_rc12_implementation_hash_binding_change_count -eq 3 -and
    [int]$matrixRecord.lca1_rc12_implementation_hash_binding_change_count -eq 3 -and
    [int]$contractRecord.lca1_rc12_campaign_manifest_binding_refresh_count -eq 3 -and
    [int]$matrixRecord.lca1_rc12_campaign_manifest_binding_refresh_count -eq 3 -and
    [int]$contractRecord.lca1_rc12_runner_source_change_count -eq 0 -and
    [int]$matrixRecord.lca1_rc12_runner_source_change_count -eq 0 -and
    [int]$contractRecord.lca1_rc12_campaign_semantics_change_count -eq 0 -and
    [int]$matrixRecord.lca1_rc12_campaign_semantics_change_count -eq 0 -and
    [string]$contractRecord.lca1_rc12_freeze_path -ceq
        "sdk/locomotion_campaign_attestation_v1_recommissioning_rc12_freeze.json" -and
    [string]$matrixRecord.lca1_rc12_freeze_path -ceq
        [string]$contractRecord.lca1_rc12_freeze_path -and
    [string]$contractRecord.lca1_rc12_manifest_path -ceq
        "sdk/locomotion_campaign_attestation_v1_recommissioning_rc12_manifest.json" -and
    [string]$matrixRecord.lca1_rc12_manifest_path -ceq
        [string]$contractRecord.lca1_rc12_manifest_path -and
    [string]$contractRecord.lca1_rc12_freeze_audit_path -ceq
        "tests/test_locomotion_campaign_attestation_v1_recommissioning_rc12_freeze.ps1" -and
    [string]$matrixRecord.lca1_rc12_freeze_audit_path -ceq
        [string]$contractRecord.lca1_rc12_freeze_audit_path -and
    [bool]$contractRecord.lca1_rc12_complete_full_scoped_pair_required -and
    [bool]$matrixRecord.lca1_rc12_complete_full_scoped_pair_required -and
    [int]$contractRecord.lca1_rc12_full_required_stage_count -eq 8 -and
    [int]$matrixRecord.lca1_rc12_full_required_stage_count -eq 8 -and
    [int]$contractRecord.lca1_rc12_scoped_required_executed_gate_count -eq 16 -and
    [int]$matrixRecord.lca1_rc12_scoped_required_executed_gate_count -eq 16 -and
    [int]$contractRecord.lca1_rc12_source_runtime_host_identity_margin -eq 0 -and
    [int]$matrixRecord.lca1_rc12_source_runtime_host_identity_margin -eq 0 -and
    [int]$contractRecord.lca1_rc12_claim_vector_margin -eq 0 -and
    [int]$matrixRecord.lca1_rc12_claim_vector_margin -eq 0 -and
    -not [bool]$contractRecord.lca1_rc12_prior_result_reuse_allowed -and
    -not [bool]$matrixRecord.lca1_rc12_prior_result_reuse_allowed -and
    [bool]$contractRecord.lca1_rc12_pair_executed -and
    [bool]$matrixRecord.lca1_rc12_pair_executed -and
    [bool]$contractRecord.lca1_rc12_full_half_attempted -and
    [bool]$matrixRecord.lca1_rc12_full_half_attempted -and
    [bool]$contractRecord.lca1_rc12_pair_completed -and
    [bool]$matrixRecord.lca1_rc12_pair_completed -and
    [bool]$contractRecord.lca1_rc12_commissioning_passed -and
    [bool]$matrixRecord.lca1_rc12_commissioning_passed -and
    [string]$contractRecord.lca1_rc12_closure_raw_sha256 -ceq
        "sha256:1e99f66def1d6d68de1b69aa4b38a4a815aaf494fea3e502062858b3a23c183b" -and
    [string]$matrixRecord.lca1_rc12_closure_raw_sha256 -ceq
        [string]$contractRecord.lca1_rc12_closure_raw_sha256 -and
    [int]$contractRecord.lca1_rc12_physical_world_count -eq 0 -and
    [int]$matrixRecord.lca1_rc12_physical_world_count -eq 0 -and
    [string]$contractRecord.post_rc12_qualification_process_question_class -ceq
        "equivalence_non_inferiority" -and
    [string]$matrixRecord.post_rc12_qualification_process_question_class -ceq
        [string]$contractRecord.post_rc12_qualification_process_question_class -and
    [string]$contractRecord.post_rc12_physical_question_class_inherited_unchanged -ceq
        "finite_decision" -and
    [string]$matrixRecord.post_rc12_physical_question_class_inherited_unchanged -ceq
        [string]$contractRecord.post_rc12_physical_question_class_inherited_unchanged -and
    [bool]$contractRecord.post_rc12_first_qualification_attempted -and
    [bool]$matrixRecord.post_rc12_first_qualification_attempted -and
    [string]$contractRecord.post_rc12_first_qualification_status -ceq
        "failed_incomplete_global_provenance_gate" -and
    [string]$matrixRecord.post_rc12_first_qualification_status -ceq
        [string]$contractRecord.post_rc12_first_qualification_status -and
    [string]$contractRecord.post_rc12_first_qualification_source_commit -ceq
        "f55930f881560aa5398d2527e8fb30fdb780c7ae" -and
    [string]$matrixRecord.post_rc12_first_qualification_source_commit -ceq
        [string]$contractRecord.post_rc12_first_qualification_source_commit -and
    [string]$contractRecord.post_rc12_first_qualification_source_tree_git_oid -ceq
        "dfb3f323341a86b14b6ea3cd0d5fcc76722e399d" -and
    [string]$matrixRecord.post_rc12_first_qualification_source_tree_git_oid -ceq
        [string]$contractRecord.post_rc12_first_qualification_source_tree_git_oid -and
    [string]$contractRecord.post_rc12_first_qualification_failure_raw_sha256 -ceq
        "sha256:5ed3c4bdf569fb7570f57b540518857eaa333ff814c3381ed20c86b05a0d78cd" -and
    [string]$matrixRecord.post_rc12_first_qualification_failure_raw_sha256 -ceq
        [string]$contractRecord.post_rc12_first_qualification_failure_raw_sha256 -and
    [long]$contractRecord.post_rc12_first_qualification_failure_byte_length -eq 628 -and
    [long]$matrixRecord.post_rc12_first_qualification_failure_byte_length -eq 628 -and
    [string]$contractRecord.post_rc12_first_qualification_failed_gate_id -ceq
        "CAK1-EVIDENCE-PROVENANCE" -and
    [string]$matrixRecord.post_rc12_first_qualification_failed_gate_id -ceq
        [string]$contractRecord.post_rc12_first_qualification_failed_gate_id -and
    [string]$contractRecord.post_rc12_first_qualification_failed_gate_receipt_raw_sha256 -ceq
        "sha256:0181d05e07de83640a1d548bfa91a90d4b98a8af0dd474b216d1017231f3c214" -and
    [string]$matrixRecord.post_rc12_first_qualification_failed_gate_receipt_raw_sha256 -ceq
        [string]$contractRecord.post_rc12_first_qualification_failed_gate_receipt_raw_sha256 -and
    [string]$contractRecord.post_rc12_first_qualification_failed_gate_stderr_raw_sha256 -ceq
        "sha256:b28acb33c56b6a6174983302ef2fa32bb65da482b57742e30169984c7dd04f48" -and
    [string]$matrixRecord.post_rc12_first_qualification_failed_gate_stderr_raw_sha256 -ceq
        [string]$contractRecord.post_rc12_first_qualification_failed_gate_stderr_raw_sha256 -and
    [int]$contractRecord.post_rc12_first_qualification_passed_gate_count -eq 3 -and
    [int]$matrixRecord.post_rc12_first_qualification_passed_gate_count -eq 3 -and
    [int]$contractRecord.post_rc12_first_qualification_campaign_role_gate_count -eq 0 -and
    [int]$matrixRecord.post_rc12_first_qualification_campaign_role_gate_count -eq 0 -and
    [int]$contractRecord.post_rc12_first_qualification_model_construction_count -eq 0 -and
    [int]$matrixRecord.post_rc12_first_qualification_model_construction_count -eq 0 -and
    [int]$contractRecord.post_rc12_first_qualification_world_attempt_count -eq 0 -and
    [int]$matrixRecord.post_rc12_first_qualification_world_attempt_count -eq 0 -and
    [int]$contractRecord.post_rc12_first_qualification_world_build_count -eq 0 -and
    [int]$matrixRecord.post_rc12_first_qualification_world_build_count -eq 0 -and
    [int]$contractRecord.post_rc12_first_qualification_retained_file_count -eq 13 -and
    [int]$matrixRecord.post_rc12_first_qualification_retained_file_count -eq 13 -and
    [long]$contractRecord.post_rc12_first_qualification_retained_byte_count -eq 12675 -and
    [long]$matrixRecord.post_rc12_first_qualification_retained_byte_count -eq 12675 -and
    [int]$contractRecord.post_rc12_inventory_population_size -eq 167 -and
    [int]$matrixRecord.post_rc12_inventory_population_size -eq 167 -and
    [bool]$contractRecord.post_rc12_inventory_population_compared_completely -and
    [bool]$matrixRecord.post_rc12_inventory_population_compared_completely -and
    [int]$contractRecord.post_rc12_inventory_changed_entry_count -eq 1 -and
    [int]$matrixRecord.post_rc12_inventory_changed_entry_count -eq 1 -and
    [string]$contractRecord.post_rc12_inventory_changed_entry_path -ceq
        "tests/test_locomotion_campaign_attestation_recommissioning_closure.ps1" -and
    [string]$matrixRecord.post_rc12_inventory_changed_entry_path -ceq
        [string]$contractRecord.post_rc12_inventory_changed_entry_path -and
    [string]$contractRecord.post_rc12_inventory_pre_maintenance_raw_sha256 -ceq
        "sha256:dff0e6b44eee7c9673d3708291edf25d22df0bf8fbb9ba9961a8244dc46f31e7" -and
    [string]$matrixRecord.post_rc12_inventory_pre_maintenance_raw_sha256 -ceq
        [string]$contractRecord.post_rc12_inventory_pre_maintenance_raw_sha256 -and
    [string]$contractRecord.post_rc12_inventory_post_maintenance_raw_sha256 -ceq
        "sha256:257423b0b4c0ea3c50e578e50e7e7eaa879998e15de0397bd6398a0db2041631" -and
    [string]$matrixRecord.post_rc12_inventory_post_maintenance_raw_sha256 -ceq
        [string]$contractRecord.post_rc12_inventory_post_maintenance_raw_sha256 -and
    [int]$contractRecord.post_rc12_inventory_classification_change_count -eq 0 -and
    [int]$matrixRecord.post_rc12_inventory_classification_change_count -eq 0 -and
    [int]$contractRecord.post_rc12_inventory_aggregate_count_delta -eq 0 -and
    [int]$matrixRecord.post_rc12_inventory_aggregate_count_delta -eq 0 -and
    [int]$contractRecord.post_rc12_inventory_equivalence_margin -eq 0 -and
    [int]$matrixRecord.post_rc12_inventory_equivalence_margin -eq 0 -and
    [int]$contractRecord.post_rc12_inventory_non_inferiority_margin -eq 0 -and
    [int]$matrixRecord.post_rc12_inventory_non_inferiority_margin -eq 0 -and
    [string]$contractRecord.post_rc12_inventory_adequacy -ceq
        "complete_167_entry_population_exact_object_comparison_one_raw_hash_change_zero_classification_or_aggregate_count_changes" -and
    [string]$matrixRecord.post_rc12_inventory_adequacy -ceq
        [string]$contractRecord.post_rc12_inventory_adequacy -and
    -not [bool]$contractRecord.post_rc12_first_qualification_reusable -and
    -not [bool]$matrixRecord.post_rc12_first_qualification_reusable -and
    [bool]$contractRecord.post_rc12_provenance_inventory_corrected -and
    [bool]$matrixRecord.post_rc12_provenance_inventory_corrected -and
    [int]$contractRecord.post_rc12_live_authority_status_consumer_reconciliation_count -eq 4 -and
    [int]$matrixRecord.post_rc12_live_authority_status_consumer_reconciliation_count -eq 4 -and
    [int]$contractRecord.post_rc12_implementation_hash_binding_refresh_count -eq 3 -and
    [int]$matrixRecord.post_rc12_implementation_hash_binding_refresh_count -eq 3 -and
    [int]$contractRecord.post_rc12_release_support_hash_field_refresh_count -eq 8 -and
    [int]$matrixRecord.post_rc12_release_support_hash_field_refresh_count -eq 8 -and
    [int]$contractRecord.post_rc12_workbench_proof_binding_refresh_count -eq 4 -and
    [int]$matrixRecord.post_rc12_workbench_proof_binding_refresh_count -eq 4 -and
    [int]$contractRecord.post_rc12_route_worker_controller_physics_or_evaluator_semantics_change_count -eq 0 -and
    [int]$matrixRecord.post_rc12_route_worker_controller_physics_or_evaluator_semantics_change_count -eq 0 -and
    [string]$contractRecord.post_rc12_second_qualification_status -ceq
        "passed_complete_clean_pushed_zero_world" -and
    [string]$contractRecord.post_rc12_second_qualification_source_commit -ceq
        "103e2043f09e7c3f131042e1b9b5250df7ccc652" -and
    [string]$contractRecord.post_rc12_second_qualification_source_tree_git_oid -ceq
        "4c8da505e32f413c4b760bf4e2dfea873a8fc9bd" -and
    [string]$contractRecord.post_rc12_second_qualification_attestation_raw_sha256 -ceq
        "sha256:9af4b73f885d46544128a879b8692cffadc25de43faf784ff6b6329193def8b4" -and
    [long]$contractRecord.post_rc12_second_qualification_attestation_byte_length -eq 107220 -and
    [int]$contractRecord.post_rc12_second_qualification_executed_gate_count -eq 22 -and
    [int]$contractRecord.post_rc12_second_qualification_global_gate_count -eq 12 -and
    [int]$contractRecord.post_rc12_second_qualification_lineage_gate_count -eq 7 -and
    [int]$contractRecord.post_rc12_second_qualification_campaign_gate_count -eq 3 -and
    [int]$contractRecord.post_rc12_second_qualification_gate_cas_reference_count -eq 66 -and
    [int]$contractRecord.post_rc12_second_qualification_model_construction_count -eq 0 -and
    [int]$contractRecord.post_rc12_second_qualification_world_attempt_count -eq 0 -and
    [int]$contractRecord.post_rc12_second_qualification_world_build_count -eq 0 -and
    [string]$contractRecord.post_rc12_second_adoption_status -ceq
        "passed_physical_launch_prerequisite_for_exact_103e2043_source" -and
    [string]$contractRecord.post_rc12_second_adoption_raw_sha256 -ceq
        "sha256:1baac9c5984b721cd27b0a61199f6fc60ec39b1c7a7986008959eac47eb02b2d" -and
    [long]$contractRecord.post_rc12_second_adoption_byte_length -eq 3303 -and
    [int]$contractRecord.post_rc12_second_adoption_gate_cas_object_count -eq 66 -and
    [string]$contractRecord.prephysical_checkout_blob_refusal_process_question_class -ceq
        "equivalence_non_inferiority" -and
    [string]$contractRecord.prephysical_checkout_blob_refusal_physical_question_class_inherited_unchanged -ceq
        "finite_decision" -and
    [string]$contractRecord.prephysical_launch_status -ceq
        "refused_before_freeze_attempt_authorization_or_world" -and
    [string]$contractRecord.prephysical_refusal_record_raw_sha256 -ceq
        "sha256:b4e167e91bdf125c90c36be2c4e4e1ded66493850a5f68e24f6bea5035bc366b" -and
    [long]$contractRecord.prephysical_refusal_record_byte_length -eq 5117 -and
    [int]$contractRecord.prephysical_refusal_supervisor_exit_code -eq 1 -and
    [string]$contractRecord.prephysical_refusal_failure_code -ceq
        "R23D62_DEPENDENCY_CHECKOUT_BLOB_MISMATCH" -and
    [string]$contractRecord.prephysical_refusal_initial_path -ceq
        "docs/research/LOCOMOTION_RESEARCH_SOURCES.md" -and
    [int]$contractRecord.prephysical_dependency_population_size -eq 221 -and
    [bool]$contractRecord.prephysical_dependency_population_compared_completely -and
    -not [bool]$contractRecord.prephysical_dependency_sampling_claimed -and
    [int]$contractRecord.prephysical_checkout_blob_match_count -eq 218 -and
    [int]$contractRecord.prephysical_checkout_blob_mismatch_count -eq 3 -and
    (@($contractRecord.prephysical_checkout_blob_mismatch_paths) -join "|") -ceq
        "docs/research/LOCOMOTION_RESEARCH_SOURCES.md|sdk/adapters/mujoco/sporespore_mujoco_adapter/__init__.py|sdk/adapters/rapier/src/conformance.rs" -and
    [string]$contractRecord.prephysical_checkout_blob_threshold_origin -ceq
        "exact_raw_checkout_blob_oid_equality_against_HEAD_for_all_221_dependencies" -and
    [int]$contractRecord.prephysical_checkout_blob_equivalence_margin -eq 0 -and
    [int]$contractRecord.prephysical_checkout_blob_non_inferiority_margin -eq 0 -and
    -not [bool]$contractRecord.prephysical_refusal_physical_freeze_written -and
    -not [bool]$contractRecord.prephysical_refusal_attempt_authorization_written -and
    -not [bool]$contractRecord.prephysical_refusal_attempt_consumed -and
    [int]$contractRecord.prephysical_refusal_authorization_preflight_count -eq 0 -and
    [int]$contractRecord.prephysical_refusal_physical_cell_count -eq 0 -and
    [int]$contractRecord.prephysical_refusal_model_construction_count -eq 0 -and
    [int]$contractRecord.prephysical_refusal_world_attempt_count -eq 0 -and
    [int]$contractRecord.prephysical_refusal_world_build_count -eq 0 -and
    [int]$contractRecord.prephysical_checkout_lf_rule_repair_count -eq 3 -and
    [bool]$contractRecord.prephysical_clean_source_qualification_strict_raw_byte_gate_added -and
    [int]$contractRecord.prephysical_route_worker_controller_physics_threshold_selector_or_evaluator_semantics_change_count -eq 0 -and
    -not [bool]$contractRecord.post_rc12_second_qualification_and_adoption_reusable_for_repaired_source -and
    [bool]$contractRecord.fresh_qualification_and_adoption_required_after_checkout_blob_repair -and
    [string]$contractRecord.post_checkout_repair_first_qualification_status -ceq
        "failed_incomplete_pre_output_root_manifest_validation" -and
    [string]$contractRecord.post_checkout_repair_first_qualification_source_commit -ceq
        "cb5883ce1bd0528a6279bcda4d0cde3947cfe664" -and
    [string]$contractRecord.post_checkout_repair_first_qualification_source_tree_git_oid -ceq
        "37aacaa054e2c12c3f509dd375a10ed41fa38dcb" -and
    [string]$contractRecord.post_checkout_repair_first_qualification_analyst_record_raw_sha256 -ceq
        "sha256:558a8a3cfeabce6b38fe27226e96863efc57a484665e95a7a487f1b7d79a7d73" -and
    [long]$contractRecord.post_checkout_repair_first_qualification_analyst_record_byte_length -eq 4494 -and
    [string]$contractRecord.post_checkout_repair_first_qualification_manifest_raw_sha256 -ceq
        "sha256:9da744842cba4f0bab70e935fc260269b645fd4f613549bc943b400911eb3be8" -and
    [long]$contractRecord.post_checkout_repair_first_qualification_manifest_byte_length -eq 11471 -and
    [int]$contractRecord.post_checkout_repair_first_qualification_runner_exit_code -eq 1 -and
    [string]$contractRecord.post_checkout_repair_first_qualification_failure_gate_id -ceq
        "R23D62-CHECKOUT-PROVENANCE-LINEAGE" -and
    [string]$contractRecord.post_checkout_repair_first_qualification_failure_path -ceq
        "tests/test_closure_evidence_provenance_contract.ps1" -and
    -not [bool]$contractRecord.post_checkout_repair_first_qualification_runner_output_root_created -and
    [bool]$contractRecord.post_checkout_repair_first_qualification_analyst_root_created_after_refusal -and
    -not [bool]$contractRecord.post_checkout_repair_first_qualification_attestation_written -and
    -not [bool]$contractRecord.post_checkout_repair_first_qualification_gate_process_started -and
    [int]$contractRecord.post_checkout_repair_first_qualification_executed_gate_count -eq 0 -and
    [int]$contractRecord.post_checkout_repair_first_qualification_manifest_identity_population_size -eq 32 -and
    [bool]$contractRecord.post_checkout_repair_first_qualification_manifest_identity_population_compared_completely -and
    -not [bool]$contractRecord.post_checkout_repair_first_qualification_manifest_identity_sampling_claimed -and
    [int]$contractRecord.post_checkout_repair_first_qualification_manifest_identity_match_count -eq 27 -and
    [int]$contractRecord.post_checkout_repair_first_qualification_manifest_identity_mismatch_entry_count -eq 5 -and
    [int]$contractRecord.post_checkout_repair_first_qualification_manifest_identity_mismatch_unique_path_count -eq 4 -and
    (@($contractRecord.post_checkout_repair_first_qualification_manifest_identity_mismatch_unique_paths) -join "|") -ceq
        "tests/test_closure_evidence_provenance_contract.ps1|.gitattributes|sdk/release/quadruped_release_contract.json|sdk/release/quadruped_support_matrix.json" -and
    [string]$contractRecord.post_checkout_repair_first_qualification_manifest_identity_threshold_origin -ceq
        "exact_raw_sha256_equality_for_all_32_manifest_gate_and_source_identity_entries" -and
    [int]$contractRecord.post_checkout_repair_first_qualification_manifest_identity_equivalence_margin -eq 0 -and
    [int]$contractRecord.post_checkout_repair_first_qualification_manifest_identity_non_inferiority_margin -eq 0 -and
    [int]$contractRecord.post_checkout_repair_first_qualification_manifest_identity_binding_repair_count -eq 5 -and
    [int]$contractRecord.post_checkout_repair_first_qualification_manifest_identity_unique_path_repair_count -eq 4 -and
    -not [bool]$contractRecord.post_checkout_repair_first_qualification_physical_attempt_consumed -and
    [int]$contractRecord.post_checkout_repair_first_qualification_model_construction_count -eq 0 -and
    [int]$contractRecord.post_checkout_repair_first_qualification_world_attempt_count -eq 0 -and
    [int]$contractRecord.post_checkout_repair_first_qualification_world_build_count -eq 0 -and
    -not [bool]$contractRecord.post_checkout_repair_first_qualification_reusable -and
    [int]$contractRecord.post_checkout_repair_first_qualification_route_worker_controller_physics_threshold_selector_evaluator_result_or_interpretation_change_count -eq 0 -and
    -not [bool]$contractRecord.fresh_qualification_required_after_recommissioning -and
    -not [bool]$matrixRecord.fresh_qualification_required_after_recommissioning -and
    [bool]$contractRecord.post_checkout_repair_second_qualification_passed -and
    [bool]$matrixRecord.post_checkout_repair_second_qualification_passed -and
    [bool]$contractRecord.post_checkout_repair_second_adoption_passed -and
    [bool]$matrixRecord.post_checkout_repair_second_adoption_passed -and
    [string]$contractRecord.physical_attempt_status -ceq
        "invalid_or_incomplete_first_attempt" -and
    [string]$matrixRecord.physical_attempt_status -ceq
        [string]$contractRecord.physical_attempt_status -and
    [bool]$contractRecord.physical_campaign_opened -and
    [bool]$matrixRecord.physical_campaign_opened -and
    [bool]$contractRecord.physical_attempt_consumed -and
    [bool]$matrixRecord.physical_attempt_consumed -and
    -not [bool]$contractRecord.physical_same_identity_rerun_allowed -and
    -not [bool]$matrixRecord.physical_same_identity_rerun_allowed -and
    -not [bool]$contractRecord.physical_world_opened -and
    -not [bool]$matrixRecord.physical_world_opened -and
    [int]$contractRecord.physical_executed_cell_count -eq 0 -and
    [int]$matrixRecord.physical_executed_cell_count -eq 0 -and
    [int]$contractRecord.authorization_receipt_schema_population_size -eq 3 -and
    [int]$matrixRecord.authorization_receipt_schema_population_size -eq 3 -and
    [int]$contractRecord.authorization_receipt_required_field_present_count -eq 1 -and
    [int]$matrixRecord.authorization_receipt_required_field_present_count -eq 1 -and
    [int]$contractRecord.authorization_receipt_required_field_missing_count -eq 2 -and
    [int]$matrixRecord.authorization_receipt_required_field_missing_count -eq 2 -and
    -not [bool]$contractRecord.authorization_receipt_schema_exact_conformance_passed -and
    -not [bool]$matrixRecord.authorization_receipt_schema_exact_conformance_passed -and
    -not [bool]$contractRecord.scientific_turning_result_exists -and
    -not [bool]$matrixRecord.scientific_turning_result_exists -and
    [int]$contractRecord.world_build_count -eq 0 -and
    [int]$matrixRecord.world_build_count -eq 0 -and
    -not [bool]$contractRecord.finite_three_engine_turning -and
    -not [bool]$matrixRecord.finite_three_engine_turning -and
    -not [bool]$contractRecord.q_sdk_r23_satisfied -and
    -not [bool]$matrixRecord.q_sdk_r23_satisfied -and
    -not [bool]$contractRecord.release_authorized -and
    -not [bool]$matrixRecord.release_authorized
) "release contract or support-matrix declaration record changed"

$prephysicalMirrorFields = @(
    "post_rc12_second_qualification_status",
    "post_rc12_second_qualification_source_commit",
    "post_rc12_second_qualification_source_tree_git_oid",
    "post_rc12_second_qualification_root",
    "post_rc12_second_qualification_attestation_raw_sha256",
    "post_rc12_second_qualification_attestation_byte_length",
    "post_rc12_second_qualification_executed_gate_count",
    "post_rc12_second_qualification_global_gate_count",
    "post_rc12_second_qualification_lineage_gate_count",
    "post_rc12_second_qualification_campaign_gate_count",
    "post_rc12_second_qualification_gate_cas_reference_count",
    "post_rc12_second_qualification_model_construction_count",
    "post_rc12_second_qualification_world_attempt_count",
    "post_rc12_second_qualification_world_build_count",
    "post_rc12_second_adoption_status",
    "post_rc12_second_adoption_path",
    "post_rc12_second_adoption_raw_sha256",
    "post_rc12_second_adoption_byte_length",
    "post_rc12_second_adoption_gate_cas_object_count",
    "prephysical_checkout_blob_refusal_process_question_class",
    "prephysical_checkout_blob_refusal_physical_question_class_inherited_unchanged",
    "prephysical_launch_status",
    "prephysical_launch_root",
    "prephysical_refusal_record_path",
    "prephysical_refusal_record_raw_sha256",
    "prephysical_refusal_record_byte_length",
    "prephysical_refusal_supervisor_exit_code",
    "prephysical_refusal_failure_code",
    "prephysical_refusal_initial_path",
    "prephysical_dependency_population_size",
    "prephysical_dependency_population_compared_completely",
    "prephysical_dependency_sampling_claimed",
    "prephysical_checkout_blob_match_count",
    "prephysical_checkout_blob_mismatch_count",
    "prephysical_checkout_blob_mismatch_paths",
    "prephysical_checkout_blob_threshold_origin",
    "prephysical_checkout_blob_equivalence_margin",
    "prephysical_checkout_blob_non_inferiority_margin",
    "prephysical_checkout_blob_adequacy",
    "prephysical_refusal_physical_freeze_written",
    "prephysical_refusal_attempt_authorization_written",
    "prephysical_refusal_attempt_consumed",
    "prephysical_refusal_authorization_preflight_count",
    "prephysical_refusal_physical_cell_count",
    "prephysical_refusal_model_construction_count",
    "prephysical_refusal_world_attempt_count",
    "prephysical_refusal_world_build_count",
    "prephysical_checkout_lf_rule_repair_count",
    "prephysical_clean_source_qualification_strict_raw_byte_gate_added",
    "prephysical_route_worker_controller_physics_threshold_selector_or_evaluator_semantics_change_count",
    "post_rc12_second_qualification_and_adoption_reusable_for_repaired_source",
    "fresh_qualification_and_adoption_required_after_checkout_blob_repair",
    "post_checkout_repair_first_qualification_status",
    "post_checkout_repair_first_qualification_source_commit",
    "post_checkout_repair_first_qualification_source_tree_git_oid",
    "post_checkout_repair_first_qualification_requested_root",
    "post_checkout_repair_first_qualification_analyst_record_path",
    "post_checkout_repair_first_qualification_analyst_record_raw_sha256",
    "post_checkout_repair_first_qualification_analyst_record_byte_length",
    "post_checkout_repair_first_qualification_manifest_raw_sha256",
    "post_checkout_repair_first_qualification_manifest_byte_length",
    "post_checkout_repair_first_qualification_runner_exit_code",
    "post_checkout_repair_first_qualification_failure_gate_id",
    "post_checkout_repair_first_qualification_failure_path",
    "post_checkout_repair_first_qualification_failure_message",
    "post_checkout_repair_first_qualification_runner_output_root_created",
    "post_checkout_repair_first_qualification_analyst_root_created_after_refusal",
    "post_checkout_repair_first_qualification_attestation_written",
    "post_checkout_repair_first_qualification_gate_process_started",
    "post_checkout_repair_first_qualification_executed_gate_count",
    "post_checkout_repair_first_qualification_manifest_identity_population_size",
    "post_checkout_repair_first_qualification_manifest_identity_population_compared_completely",
    "post_checkout_repair_first_qualification_manifest_identity_sampling_claimed",
    "post_checkout_repair_first_qualification_manifest_identity_match_count",
    "post_checkout_repair_first_qualification_manifest_identity_mismatch_entry_count",
    "post_checkout_repair_first_qualification_manifest_identity_mismatch_unique_path_count",
    "post_checkout_repair_first_qualification_manifest_identity_mismatch_unique_paths",
    "post_checkout_repair_first_qualification_manifest_identity_threshold_origin",
    "post_checkout_repair_first_qualification_manifest_identity_equivalence_margin",
    "post_checkout_repair_first_qualification_manifest_identity_non_inferiority_margin",
    "post_checkout_repair_first_qualification_manifest_identity_adequacy",
    "post_checkout_repair_first_qualification_manifest_identity_binding_repair_count",
    "post_checkout_repair_first_qualification_manifest_identity_unique_path_repair_count",
    "post_checkout_repair_first_qualification_physical_attempt_consumed",
    "post_checkout_repair_first_qualification_model_construction_count",
    "post_checkout_repair_first_qualification_world_attempt_count",
    "post_checkout_repair_first_qualification_world_build_count",
    "post_checkout_repair_first_qualification_reusable",
    "post_checkout_repair_first_qualification_route_worker_controller_physics_threshold_selector_evaluator_result_or_interpretation_change_count",
    "post_checkout_repair_second_qualification_status",
    "post_checkout_repair_second_qualification_source_commit",
    "post_checkout_repair_second_qualification_source_tree_git_oid",
    "post_checkout_repair_second_qualification_root",
    "post_checkout_repair_second_qualification_attestation_raw_sha256",
    "post_checkout_repair_second_qualification_attestation_byte_length",
    "post_checkout_repair_second_qualification_executed_gate_count",
    "post_checkout_repair_second_qualification_passed",
    "post_checkout_repair_second_adoption_raw_sha256",
    "post_checkout_repair_second_adoption_byte_length",
    "post_checkout_repair_second_adoption_gate_cas_object_count",
    "post_checkout_repair_second_adoption_passed",
    "post_checkout_repair_second_qualification_and_adoption_reusable",
    "physical_campaign_opened",
    "physical_attempt_root",
    "physical_source_commit",
    "physical_source_tree_git_oid",
    "physical_attempt_id",
    "physical_attempt_status",
    "physical_attempt_consumed",
    "physical_same_identity_rerun_allowed",
    "physical_replacement_or_selective_rerun_allowed",
    "physical_retained_file_count",
    "physical_authorization_preflight_receipt_count",
    "physical_executed_cell_count",
    "physical_model_construction_count",
    "physical_world_opened",
    "physical_outcome_exposed",
    "physical_failure_class",
    "physical_failure_message",
    "authorization_receipt_schema_population_size",
    "authorization_receipt_schema_population_compared_completely",
    "authorization_receipt_schema_sampling_claimed",
    "authorization_receipt_required_field_present_count",
    "authorization_receipt_required_field_missing_count",
    "authorization_receipt_required_field_missing_engine_ids",
    "authorization_receipt_schema_threshold_origin",
    "authorization_receipt_schema_equivalence_margin",
    "authorization_receipt_schema_non_inferiority_margin",
    "authorization_receipt_schema_adequacy",
    "authorization_receipt_schema_exact_conformance_passed",
    "scientific_turning_result_exists",
    "closure_path",
    "closure_raw_sha256",
    "closure_audit_path",
    "closure_audit_raw_sha256"
)
foreach ($field in $prephysicalMirrorFields) {
    Assert-R23D62 (
        ($contractRecord[$field] | ConvertTo-Json -Compress -Depth 10) -ceq
        ($matrixRecord[$field] | ConvertTo-Json -Compress -Depth 10)
    ) "release/support prephysical field differs: $field"
}
$prephysicalRecordPath = [string]$contractRecord.prephysical_refusal_record_path
Assert-R23D62 (
    (Test-Path -LiteralPath $prephysicalRecordPath -PathType Leaf) -and
    (Get-Item -LiteralPath $prephysicalRecordPath).Length -eq
        [long]$contractRecord.prephysical_refusal_record_byte_length -and
    (Get-R23D62Sha256 $prephysicalRecordPath) -ceq
        [string]$contractRecord.prephysical_refusal_record_raw_sha256
) "retained prephysical refusal record bytes changed"
$prephysicalRecord = Get-Content -Raw -LiteralPath $prephysicalRecordPath |
    ConvertFrom-Json -AsHashtable -Depth 100
Assert-R23D62 (
    [string]$prephysicalRecord.record_kind -ceq
        "post_refusal_analyst_record_not_supervisor_receipt" -and
    [string]$prephysicalRecord.status -ceq
        "pre_attempt_zero_world_checkout_blob_mismatch_refusal" -and
    -not [bool]$prephysicalRecord.attempt_consumed -and
    [int]$prephysicalRecord.checkout_blob_mismatch_count -eq 3 -and
    [int]$prephysicalRecord.world_build_count -eq 0 -and
    -not [bool]$prephysicalRecord.turning_result_created
) "retained prephysical refusal interpretation changed"

$prequalificationRecordPath =
    [string]$contractRecord.post_checkout_repair_first_qualification_analyst_record_path
Assert-R23D62 (
    (Test-Path -LiteralPath $prequalificationRecordPath -PathType Leaf) -and
    (Get-Item -LiteralPath $prequalificationRecordPath).Length -eq
        [long]$contractRecord.post_checkout_repair_first_qualification_analyst_record_byte_length -and
    (Get-R23D62Sha256 $prequalificationRecordPath) -ceq
        [string]$contractRecord.post_checkout_repair_first_qualification_analyst_record_raw_sha256
) "retained repaired-source prequalification refusal bytes changed"
$prequalificationRecord = Get-Content -Raw -LiteralPath $prequalificationRecordPath |
    ConvertFrom-Json -AsHashtable -Depth 100
Assert-R23D62 (
    [string]$prequalificationRecord.record_kind -ceq
        "post_refusal_analyst_record_not_attestation_runner_receipt" -and
    [string]$prequalificationRecord.status -ceq
        "failed_incomplete_pre_output_root_manifest_validation" -and
    -not [bool]$prequalificationRecord.runner_output_root_created -and
    [bool]$prequalificationRecord.analyst_record_root_created_after_refusal -and
    -not [bool]$prequalificationRecord.gate_process_started -and
    [int]$prequalificationRecord.executed_gate_count -eq 0 -and
    [int]$prequalificationRecord.manifest_identity_entry_population_size -eq 32 -and
    [int]$prequalificationRecord.manifest_identity_mismatch_entry_count -eq 5 -and
    [int]$prequalificationRecord.manifest_identity_mismatch_unique_path_count -eq 4 -and
    -not [bool]$prequalificationRecord.physical_attempt_consumed -and
    [int]$prequalificationRecord.world_build_count -eq 0 -and
    -not [bool]$prequalificationRecord.turning_result_created
) "retained repaired-source prequalification refusal interpretation changed"

$workbench = Get-Content -Raw -LiteralPath $workbenchPath |
    ConvertFrom-Json -AsHashtable -Depth 100
$workbenchRuns = @($workbench.runs | Where-Object {
    [string]$_.id -ceq "qsdk_r23d62_preregistration"
})
Assert-R23D62 (
    $workbenchRuns.Count -eq 1 -and
    [string]$workbenchRuns[0].kind -ceq "zero_world_declaration_gate" -and
    [string]$workbenchRuns[0].status -ceq
        "closed_consumed_invalid_incomplete_before_first_world_authorization_receipt_schema_projection_failure" -and
    [string]$workbenchRuns[0].world_policy -ceq "zero_world_declaration_only" -and
    [string]$workbenchRuns[0].risk -ceq "safe" -and
    [string]$workbenchRuns[0].runner_path -ceq
        "tests/test_qsdk_r23d62_preregistration.ps1" -and
    (@($workbenchRuns[0].arguments) -join ",") -ceq "-SkipGodot" -and
    @($workbenchRuns[0].proofs).Count -eq 6 -and
    [string]$workbenchRuns[0].proofs[0].expected_sha256 -ceq
        $declarationHash.Substring(7) -and
    [string]$workbenchRuns[0].proofs[1].expected_sha256 -ceq
        $designHash.Substring(7) -and
    [string]$workbenchRuns[0].proofs[2].expected_sha256 -ceq
        $auditHash.Substring(7) -and
    [string]$workbenchRuns[0].proofs[3].expected_sha256 -ceq
        $seedCompilerHash.Substring(7)
) "Workbench declaration exposure changed"

Write-Output (
    "QSDK_R23D62_PREREGISTRATION_PASS " +
    "question=finite_decision engines=3 arms=3 cells=9 seed=23167 " +
    "profile=sporespore_qsdk_r23d60_selected_s169_actuator_cap_profile_v1 " +
    "mutations=35 godot_seed_compiler=$godotCompilerRun models=0 worlds=0 " +
    "lifecycle_reconciled=True rc8=closed_negative rc9=closed_negative rc10=closed_negative rc11=closed_negative rc12=closed_positive post_rc12_qualification=failed_provenance_inventory_hash_drift_corrected second_qualification=passed adoption=passed prephysical=checkout_blob_mismatch_refused mismatches=3 repaired_source_qualification=manifest_identity_refused manifest_mismatches=5 final_qualification=passed final_adoption=passed attempt_consumed=True cells=0 schema_present=1 schema_missing=2 fresh_qualification_required=False " +
    "physical=False turning=False qsdk_r23=False equivalence=False release=False " +
    "design=$designHash declaration=$declarationHash seed_compiler=$seedCompilerHash " +
    "r60_closure=$(Get-R23D62Sha256 $r60ClosurePath) " +
    "r61_closure=$(Get-R23D62Sha256 $r61ClosurePath)"
)
