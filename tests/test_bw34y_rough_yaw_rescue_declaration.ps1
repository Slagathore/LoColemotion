$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = Split-Path -Parent $PSScriptRoot
$campaignId = "BW34Y-BW33N-ROUGH-YAW-RESCUE-DEVELOPMENT"
$gateId = "BW34Y"
$candidatePath = Join-Path $repoRoot `
    "sdk\balanced_wave_bw34y_rough_yaw_rescue_candidates.json"
$preregistrationPath = Join-Path $repoRoot `
    "sdk\balanced_wave_bw34y_rough_yaw_rescue_preregistration.json"
$manifestPath = Join-Path $repoRoot `
    "sdk\balanced_wave_bw34y_rough_yaw_rescue_manifest.json"
$evidenceRoot = `
    "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence\balanced-wave-bw34y-rough-yaw-rescue-development-attempts"
$expectedStatus = `
    "prospective_stage_zero_zero_world_only_physical_execution_blocked"

function Read-JsonMap([string]$Path) {
    return Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json -AsHashtable
}

function Get-RawSha256([string]$Path) {
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Get-Utf8Sha256([string]$Value) {
    $bytes = [Text.Encoding]::UTF8.GetBytes($Value)
    $digest = [Security.Cryptography.SHA256]::HashData($bytes)
    return "sha256:$([Convert]::ToHexString($digest).ToLowerInvariant())"
}

function Assert-Exact([bool]$Condition, [string]$Message) {
    if (-not $Condition) {
        throw $Message
    }
}

function Test-SequenceEqual([object[]]$Actual, [object[]]$Expected) {
    if ($Actual.Count -ne $Expected.Count) {
        return $false
    }
    for ($index = 0; $index -lt $Actual.Count; $index += 1) {
        if ([string]$Actual[$index] -cne [string]$Expected[$index]) {
            return $false
        }
    }
    return $true
}

foreach ($requiredPath in @($candidatePath, $preregistrationPath, $manifestPath)) {
    Assert-Exact (Test-Path -LiteralPath $requiredPath -PathType Leaf) (
        "BW34Y declaration file is missing: $requiredPath"
    )
}

$candidates = Read-JsonMap $candidatePath
$preregistration = Read-JsonMap $preregistrationPath
$manifest = Read-JsonMap $manifestPath

foreach ($document in @($candidates, $preregistration, $manifest)) {
    Assert-Exact (
        [string]$document.campaign_id -ceq $campaignId -and
        [string]$document.gate_id -ceq $gateId -and
        [string]$document.implementation_parent_commit -ceq
            "ec0b583a8a39b8e417720224307edc8d6163e819" -and
        [string]$document.status -ceq $expectedStatus -and
        -not [bool]$document.physical_execution_authorized -and
        -not [bool]$document.physical_acceptance_authority
    ) "BW34Y declaration identity or zero-world boundary changed"
}

foreach ($binding in @(
    $preregistration.source_bindings.candidate_declarations,
    $preregistration.source_bindings.bw33n_immutable_valid_none_closure,
    $preregistration.source_bindings.candidate_authority_exposure_horizon,
    $preregistration.source_bindings.portable_controller_implementation,
    $preregistration.source_bindings.portable_runtime_implementation,
    $preregistration.source_bindings.godot_jolt_adapter,
    $preregistration.source_bindings.physical_wave_parent,
    $preregistration.source_bindings.fixed_horizon_physical_wave_parent,
    $manifest.source_bindings.candidate_declarations,
    $manifest.source_bindings.preregistration
)) {
    $boundPath = Join-Path $repoRoot ([string]$binding.path -replace '/', '\')
    Assert-Exact (Test-Path -LiteralPath $boundPath -PathType Leaf) (
        "BW34Y bound source is missing: $boundPath"
    )
    Assert-Exact ((Get-RawSha256 $boundPath) -ceq [string]$binding.raw_sha256) (
        "BW34Y bound source digest changed: $boundPath"
    )
}

$bw33nClosure = Read-JsonMap (
    Join-Path $repoRoot "sdk\balanced_wave_bw33n_rough_factorial_closure.json"
)
Assert-Exact (
    [string]$bw33nClosure.status -ceq
        "closed_complete_valid_development_no_selection" -and
    [string]$bw33nClosure.selection.selected_candidate_id -ceq "NONE" -and
    [int]$bw33nClosure.candidate_results."BW33N-C".integrity_pass_count -eq 3 -and
    [int]$bw33nClosure.candidate_results."BW33N-C".walking_pass_count -eq 1 -and
    (Test-SequenceEqual `
        @($bw33nClosure.candidate_results."BW33N-C".walking_passing_seed_ids) `
        @(21001)) -and
    (Test-SequenceEqual `
        @($bw33nClosure.walking_failure_receipts.rough_s21002_bw33n_c) `
        @("bounded_lateral_drift")) -and
    (Test-SequenceEqual `
        @($bw33nClosure.walking_failure_receipts.rough_s21003_bw33n_c) `
        @("bounded_lateral_drift")) -and
    [bool]$bw33nClosure.next_work_authority.negative_and_none_result_may_inform_distinct_successor_design -and
    [bool]$bw33nClosure.next_work_authority.distinct_successor_requires_new_hypothesis_campaign_gate_source_preregistration_and_evidence_root -and
    -not [bool]$bw33nClosure.next_work_authority.full_nuisance_development_declaration_authorized -and
    -not [bool]$bw33nClosure.next_work_authority.independent_validation_declaration_authorized -and
    [bool]$bw33nClosure.next_work_authority.reserved_fresh_seeds_remain_unopened
) "BW34Y predecessor authority or retained BW33N-C mechanism changed"

Assert-Exact (
    [string]$candidates.study_classification -ceq
        "single_arm_outcome_exposed_rough_rescue_development_screen_against_retained_comparator" -and
    (Test-SequenceEqual @($candidates.candidate_order) @("BW34Y-A")) -and
    @($candidates.candidates).Count -eq 1 -and
    [double]$candidates.derivation.retained_predecessor_gain_per_rad -eq 1.3 -and
    [double]$candidates.derivation.retained_comparator_yaw_error_stride_gain_per_rad -eq 1.0 -and
    [double]$candidates.derivation.equal_step_continuation -eq 0.3 -and
    [double]$candidates.derivation.candidate_yaw_error_stride_gain_per_rad -eq 0.7 -and
    [string]$candidates.derivation.formula -ceq "1.0 - (1.3 - 1.0) = 0.7" -and
    [bool]$candidates.derivation.runtime_failure_seed_or_outcome_conditioning_forbidden -and
    [bool]$candidates.derivation.morphology_conditioning_forbidden -and
    [bool]$candidates.derivation.rough_profile_conditioning_forbidden
) "BW34Y single-factor derivation changed"

$candidate = @($candidates.candidates)[0]
Assert-Exact (
    [string]$candidate.candidate_id -ceq "BW34Y-A" -and
    [string]$candidate.controller_policy_id -ceq
        "sporespore_balanced_wave_bw34y_a_v1" -and
    [string]$candidate.runtime_profile_sha256 -ceq
        "sha256:f95e63ae3af945715c8a4e1030351caaf46e0cf947aa5f6711f2b9c9b5582eb5" -and
    [double]$candidate.yaw_error_stride_gain_per_rad -eq 0.7 -and
    [double]$candidate.global_requested_correction_scale -eq 0.5 -and
    [string]$candidate.stability_policy_id -ceq
        "sporespore_scheduled_load_transfer_bw13p_a_v3" -and
    [string]$candidate.authority_scope -ceq "post_settle_full" -and
    [string]$candidate.execution_mode -ceq
        "native_balanced_wave_base_with_stability_contribution" -and
    [int]$candidate.exact_candidate_authority_observation_count -eq 3232 -and
    [int]$candidate.expected_native_motor_write_count -eq 25856 -and
    @($candidate.branch_surfaces).Count -eq 0 -and
    [bool]$candidate.controller_authority -and
    -not [bool]$candidate.physical_acceptance_authority -and
    (Get-Utf8Sha256 ([string]$candidate.exact_binding_string)) -ceq
        [string]$candidate.candidate_composition_digest
) "BW34Y candidate identity, composition, or branch boundary changed"

$cells = @($manifest.ordered_cells)
$expectedSeeds = @(21001, 21002, 21003)
Assert-Exact (
    $cells.Count -eq 3 -and
    [int]$manifest.matrix_contract.expected_world_count -eq 3 -and
    (Test-SequenceEqual @($manifest.matrix_contract.candidate_order) @("BW34Y-A")) -and
    (Test-SequenceEqual @($manifest.matrix_contract.seed_order) $expectedSeeds) -and
    [bool]$manifest.matrix_contract.serialized_execution_required -and
    [bool]$manifest.matrix_contract.early_stop_forbidden -and
    [bool]$manifest.matrix_contract.rerun_or_replacement_forbidden
) "BW34Y three-world matrix contract changed"

for ($index = 0; $index -lt $cells.Count; $index += 1) {
    $seed = $expectedSeeds[$index]
    $cell = $cells[$index]
    Assert-Exact (
        [int]$cell.ordinal -eq ($index + 1) -and
        [string]$cell.cell_id -ceq "rough_s${seed}_bw34y_a" -and
        [string]$cell.cohort -ceq
            "single_arm_outcome_exposed_rough_yaw_rescue" -and
        [string]$cell.role -ceq "treatment" -and
        [int]$cell.campaign_seed -eq $seed -and
        [string]$cell.challenge_profile_id -ceq "bw6n_rough_v1" -and
        [string]$cell.material_profile_id -ceq "godot_jolt_bw5c_mu095_v1" -and
        [string]$cell.candidate_id -ceq "BW34Y-A" -and
        [string]$cell.controller_policy_id -ceq
            "sporespore_balanced_wave_bw34y_a_v1" -and
        [double]$cell.yaw_error_stride_gain_per_rad -eq 0.7 -and
        [double]$cell.global_requested_correction_scale -eq 0.5 -and
        [int]$cell.expected_candidate_authority_observation_count -eq 3232 -and
        [int]$cell.expected_native_motor_write_count -eq 25856
    ) "BW34Y manifest cell changed at ordinal $($index + 1)"
}

Assert-Exact (
    [int]$preregistration.development_matrix.expected_world_count -eq 3 -and
    [bool]$preregistration.development_matrix.all_worlds_serialized -and
    [bool]$preregistration.development_matrix.already_outcome_exposed_seeds_only -and
    [int]$preregistration.selection_contract.required_integrity_pass_count -eq 3 -and
    [int]$preregistration.selection_contract.required_walking_pass_count -eq 3 -and
    [int]$preregistration.selection_contract.required_failed_walking_gate_count -eq 0 -and
    [bool]$preregistration.selection_contract.retained_comparator_passing_seed_21001_must_remain_passing -and
    [string]$preregistration.selection_contract.eligible_candidate_selects -ceq
        "BW34Y-A" -and
    [string]$preregistration.selection_contract.no_eligible_candidate_selects -ceq
        "NONE" -and
    [bool]$preregistration.selection_contract.selection_grants_only_distinct_full_nuisance_development_declaration_authority -and
    -not [bool]$preregistration.selection_contract.selection_grants_rough_terrain_acceptance -and
    -not [bool]$preregistration.selection_contract.selection_grants_fresh_validation_authority -and
    -not [bool]$preregistration.selection_contract.selection_grants_release_authority
) "BW34Y selection or earned-authority boundary changed"

$reservedSeeds = @(49101, 49102, 49103)
Assert-Exact (
    (Test-SequenceEqual @($manifest.reserved_fresh_validation_seeds) $reservedSeeds) -and
    (Test-SequenceEqual `
        @($preregistration.pipeline_stages.stage_3_independent_validation.reserved_unopened_seed_ids) `
        $reservedSeeds) -and
    [bool]$manifest.reserved_fresh_seeds_are_not_part_of_bw34y -and
    -not [bool]$preregistration.pipeline_stages.stage_3_independent_validation.reserved_seed_use_authorized
) "BW34Y reserved validation seed boundary changed"
foreach ($cell in $cells) {
    Assert-Exact ($reservedSeeds -notcontains [int]$cell.campaign_seed) (
        "BW34Y illegally includes a reserved fresh seed"
    )
}

Assert-Exact (
    [int]$preregistration.attempt_count -eq 0 -and
    [int]$preregistration.world_count -eq 0 -and
    [int]$manifest.attempt_count -eq 0 -and
    [int]$manifest.world_count -eq 0 -and
    -not (Test-Path -LiteralPath $evidenceRoot)
) "BW34Y stage zero must have no attempt, world, or evidence root"

Push-Location $repoRoot
try {
    $candidateInspectionOutput = @(
        & cargo run --quiet --manifest-path sdk\Cargo.toml `
            -p sporespore-locomotion-core --example inspect_policy_profile -- `
            sporespore_balanced_wave_bw34y_a_v1
    )
    Assert-Exact ($LASTEXITCODE -eq 0) "BW34Y candidate profile inspection failed"
    $comparatorInspectionOutput = @(
        & cargo run --quiet --manifest-path sdk\Cargo.toml `
            -p sporespore-locomotion-core --example inspect_policy_profile -- `
            sporespore_balanced_wave_bw23y_b_v1
    )
    Assert-Exact ($LASTEXITCODE -eq 0) "BW34Y comparator profile inspection failed"
}
finally {
    Pop-Location
}

$candidateInspection = $candidateInspectionOutput[-1] | ConvertFrom-Json -AsHashtable
$comparatorInspection = $comparatorInspectionOutput[-1] | ConvertFrom-Json -AsHashtable
Assert-Exact (
    [bool]$candidateInspection.ok -and
    [string]$candidateInspection.policy_id -ceq
        "sporespore_balanced_wave_bw34y_a_v1" -and
    [string]$candidateInspection.profile_sha256 -ceq
        [string]$candidate.runtime_profile_sha256 -and
    [int]$candidateInspection.actual_world_build_count -eq 0 -and
    -not [bool]$candidateInspection.physics_state_modified -and
    -not [bool]$candidateInspection.locomotion_outcome_exposed -and
    -not [bool]$candidateInspection.physical_acceptance_authority
) "BW34Y inspected native profile identity or zero-world receipt changed"

$candidateProfile = $candidateInspection.profile
$comparatorProfile = $comparatorInspection.profile
Assert-Exact (
    [string]$candidateProfile.policy_id -ceq
        "sporespore_balanced_wave_bw34y_a_v1" -and
    [double]$candidateProfile.yaw_error_stride_gain_per_rad -eq 0.7 -and
    [string]$comparatorProfile.policy_id -ceq
        "sporespore_balanced_wave_bw23y_b_v1" -and
    [double]$comparatorProfile.yaw_error_stride_gain_per_rad -eq 1.0
) "BW34Y candidate/comparator declared policy contrast changed"
$candidateProfile.Remove("policy_id")
$candidateProfile.Remove("yaw_error_stride_gain_per_rad")
$comparatorProfile.Remove("policy_id")
$comparatorProfile.Remove("yaw_error_stride_gain_per_rad")
Assert-Exact (
    ($candidateProfile | ConvertTo-Json -Compress -Depth 20) -ceq
        ($comparatorProfile | ConvertTo-Json -Compress -Depth 20)
) "BW34Y-A differs from BW33N-C/BW23Y-B on an undeclared controller field"

Write-Output (
    "BW34Y_DECLARATION_PASS cells=3 candidates=1 exposed_seeds=3 " +
    "yaw_gain=0.7 comparator_yaw_gain=1.0 authority_horizon=3232 " +
    "branch_surfaces=0 reserved_fresh_seeds=3 attempts=0 worlds=0 " +
    "full_nuisance_authority=False validation_authority=False " +
    "rough_authority=False physical_authority=False"
)
