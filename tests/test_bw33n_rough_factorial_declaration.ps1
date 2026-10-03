$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = Split-Path -Parent $PSScriptRoot
$campaignId = "BW33N-BW32N-ROUGH-FACTORIAL-DEVELOPMENT"
$gateId = "BW33N"
$candidatePath = Join-Path $repoRoot `
    "sdk\balanced_wave_bw33n_rough_factorial_candidates.json"
$preregistrationPath = Join-Path $repoRoot `
    "sdk\balanced_wave_bw33n_rough_factorial_preregistration.json"
$manifestPath = Join-Path $repoRoot `
    "sdk\balanced_wave_bw33n_rough_factorial_manifest.json"
$evidenceRoot = `
    "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence\balanced-wave-bw33n-rough-factorial-development-attempts"

function Read-JsonMap([string]$Path) {
    return Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json -AsHashtable
}

function Get-RawSha256([string]$Path) {
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
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
        "BW33N declaration file is missing: $requiredPath"
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
            "cb1ef4f168e08bfe9ff87976a1080407ab9f81e3" -and
        [string]$document.status -ceq
            "prospective_stage_zero_zero_world_only_physical_execution_blocked"
    ) "BW33N declaration identity changed"
}

foreach ($binding in @(
    $preregistration.source_bindings.candidate_declarations,
    $preregistration.source_bindings.bw32n_immutable_valid_closure,
    $preregistration.source_bindings.bw28y_immutable_valid_negative_closure,
    $preregistration.source_bindings.candidate_authority_exposure_horizon,
    $preregistration.source_bindings.bw32n_frozen_manifest,
    $manifest.source_bindings.candidate_declarations,
    $manifest.source_bindings.preregistration
)) {
    $boundPath = Join-Path $repoRoot ([string]$binding.path -replace '/', '\')
    Assert-Exact (Test-Path -LiteralPath $boundPath -PathType Leaf) (
        "BW33N bound source is missing: $boundPath"
    )
    Assert-Exact ((Get-RawSha256 $boundPath) -ceq [string]$binding.raw_sha256) (
        "BW33N bound source digest changed: $boundPath"
    )
}

$bw32nClosure = Read-JsonMap (
    Join-Path $repoRoot "sdk\balanced_wave_bw32n_dynamic_receipt_recovery_closure.json"
)
$bw28yClosure = Read-JsonMap (
    Join-Path $repoRoot "sdk\balanced_wave_bw28y_yaw_development_closure.json"
)
Assert-Exact (
    [string]$bw32nClosure.status -ceq
        "closed_valid_development_selection_fresh_validation_ineligible" -and
    [string]$bw32nClosure.disposition.selected_candidate_id -ceq "BW32N-B" -and
    [int]$bw32nClosure.candidate_comparison.candidate_b.failures_by_axis.bw6n_rough_v1 -eq 2 -and
    [bool]$bw32nClosure.next_work_authority.new_rough_focused_development_successor_may_be_declared -and
    -not [bool]$bw32nClosure.next_work_authority.independent_validation_declaration_authorized -and
    [bool]$bw32nClosure.next_work_authority.reserved_fresh_seeds_remain_unopened
) "BW33N prerequisite BW32N closure boundary changed"
Assert-Exact (
    [string]$bw28yClosure.status -ceq "closed_complete_valid_development_no_selection" -and
    [string]$bw28yClosure.attempt.selected_candidate_id -ceq "NONE" -and
    [bool]$bw28yClosure.disposition.valid_none_selection -and
    -not [bool]$bw28yClosure.disposition.development_candidate_selected -and
    [bool]$bw28yClosure.optimization_boundary.bw28y_b_may_not_be_promoted_as_selected -and
    [bool]$bw28yClosure.optimization_boundary.new_candidates_may_be_designed_from_the_observed_1_3_to_1_0_tradeoff
) "BW33N prerequisite BW28Y negative boundary changed"

$candidateOrder = @("BW33N-A", "BW33N-B", "BW33N-C", "BW33N-D")
Assert-Exact (
    [string]$candidates.schema_version -ceq
        "sporespore_balanced_wave_bw33n_rough_factorial_candidates_v1" -and
    (Test-SequenceEqual @($candidates.candidate_order) $candidateOrder) -and
    @($candidates.candidates).Count -eq 4 -and
    [string]$candidates.factor_contract.design -ceq
        "two_by_two_branch_free_rough_mechanism_factorial" -and
    (Test-SequenceEqual @($candidates.factor_contract.yaw_error_stride_gain_per_rad_levels) @(1.3, 1.0)) -and
    (Test-SequenceEqual @($candidates.factor_contract.global_requested_correction_scale_levels) @(0.5, 0.75)) -and
    [bool]$candidates.factor_contract.runtime_rough_conditioning_forbidden -and
    [bool]$candidates.factor_contract.candidate_seed_failure_identity_and_outcome_conditioning_forbidden
) "BW33N factor contract changed"

$expectedFactors = @{
    "BW33N-A" = @{ yaw = 1.3; scale = 0.5; policy = "sporespore_balanced_wave_bw15f_b_v1"; profile = "sha256:1134302a1566e12d1e1179beebed893176eeed88065920855026e903738bb413"; treatment = 0; eligible = $false }
    "BW33N-B" = @{ yaw = 1.3; scale = 0.75; policy = "sporespore_balanced_wave_bw15f_b_v1"; profile = "sha256:1134302a1566e12d1e1179beebed893176eeed88065920855026e903738bb413"; treatment = 1; eligible = $true }
    "BW33N-C" = @{ yaw = 1.0; scale = 0.5; policy = "sporespore_balanced_wave_bw23y_b_v1"; profile = "sha256:d345d9607bed545ee6c58a20055cd6258f38ed581dd3d9f6490a9ae7f1a57570"; treatment = 1; eligible = $true }
    "BW33N-D" = @{ yaw = 1.0; scale = 0.75; policy = "sporespore_balanced_wave_bw23y_b_v1"; profile = "sha256:d345d9607bed545ee6c58a20055cd6258f38ed581dd3d9f6490a9ae7f1a57570"; treatment = 2; eligible = $true }
}

foreach ($candidateId in $candidateOrder) {
    $matches = @($candidates.candidates | Where-Object {
        [string]$_.candidate_id -ceq $candidateId
    })
    Assert-Exact ($matches.Count -eq 1) (
        "BW33N candidate missing or duplicated: $candidateId"
    )
    $candidate = $matches[0]
    $expected = $expectedFactors[$candidateId]
    Assert-Exact (
        [string]$candidate.schema_version -ceq
            "sporespore_bw33n_rough_factorial_candidate_v1" -and
        [string]$candidate.controller_policy_id -ceq [string]$expected.policy -and
        [string]$candidate.runtime_profile_sha256 -ceq [string]$expected.profile -and
        [double]$candidate.yaw_error_stride_gain_per_rad -eq [double]$expected.yaw -and
        [double]$candidate.global_requested_correction_scale -eq [double]$expected.scale -and
        [string]$candidate.stability_policy_id -ceq
            "sporespore_scheduled_load_transfer_bw13p_a_v3" -and
        [string]$candidate.authority_scope -ceq "post_settle_full" -and
        [string]$candidate.execution_mode -ceq
            "native_balanced_wave_base_with_stability_contribution" -and
        [string]$candidate.authority_horizon_policy_sha256 -ceq
            "sha256:ec8291ecd54dbc8299d79d6b3adf176bf67fe851e4bacffc3df253c9a0a605df" -and
        [int]$candidate.exact_candidate_authority_observation_count -eq 3232 -and
        [int]$candidate.expected_native_motor_write_count -eq 25856 -and
        [int]$candidate.treatment_factor_count -eq [int]$expected.treatment -and
        [bool]$candidate.selection_eligible -eq [bool]$expected.eligible -and
        @($candidate.branch_surfaces).Count -eq 0 -and
        -not [bool]$candidate.physical_acceptance_authority
    ) "BW33N candidate factor or branch contract changed: $candidateId"
}

$expectedSeeds = @(21001, 21002, 21003)
$cells = @($manifest.ordered_cells)
Assert-Exact ($cells.Count -eq 12) "BW33N manifest must contain exactly 12 cells"
$ordinal = 0
$seen = @{}
foreach ($seed in $expectedSeeds) {
    foreach ($candidateId in $candidateOrder) {
        $cell = $cells[$ordinal]
        $suffix = $candidateId.Substring($candidateId.Length - 1).ToLowerInvariant()
        $expectedCellId = "rough_s${seed}_bw33n_${suffix}"
        $expected = $expectedFactors[$candidateId]
        Assert-Exact (
            [string]$cell.cell_id -ceq $expectedCellId -and
            [string]$cell.cohort -ceq "paired_outcome_exposed_rough_factorial" -and
            [string]$cell.role -ceq $(if ($candidateId -ceq "BW33N-A") { "reference" } else { "treatment" }) -and
            [string]$cell.challenge_profile_id -ceq "bw6n_rough_v1" -and
            [int]$cell.campaign_seed -eq $seed -and
            [string]$cell.candidate_id -ceq $candidateId -and
            [string]$cell.controller_policy_id -ceq [string]$expected.policy -and
            [string]$cell.runtime_profile_sha256 -ceq [string]$expected.profile -and
            [double]$cell.yaw_error_stride_gain_per_rad -eq [double]$expected.yaw -and
            [double]$cell.global_requested_correction_scale -eq [double]$expected.scale -and
            [int]$cell.expected_candidate_authority_observation_count -eq 3232
        ) "BW33N manifest cell changed at ordinal $ordinal"
        Assert-Exact (-not $seen.ContainsKey($expectedCellId)) (
            "BW33N cell identity duplicated: $expectedCellId"
        )
        $seen[$expectedCellId] = $true
        $ordinal += 1
    }
}

Assert-Exact (
    (Test-SequenceEqual @($preregistration.paired_matrix.candidate_order) $candidateOrder) -and
    (Test-SequenceEqual @($manifest.matrix_contract.candidate_order) $candidateOrder) -and
    (Test-SequenceEqual @($preregistration.paired_matrix.seed_order) $expectedSeeds) -and
    (Test-SequenceEqual @($manifest.matrix_contract.seed_order) $expectedSeeds) -and
    [int]$preregistration.paired_matrix.expected_world_count -eq 12 -and
    [int]$manifest.matrix_contract.expected_world_count -eq 12 -and
    [bool]$preregistration.paired_matrix.all_worlds_execute_even_after_selection_is_decided -and
    [bool]$preregistration.paired_matrix.failed_cell_replacement_forbidden -and
    [bool]$manifest.matrix_contract.early_stop_forbidden -and
    [bool]$manifest.matrix_contract.rerun_or_replacement_forbidden
) "BW33N matrix or one-shot contract changed"

Assert-Exact (
    [string]$preregistration.selection_contract.reference_candidate_id -ceq "BW33N-A" -and
    (Test-SequenceEqual @($preregistration.selection_contract.eligible_candidate_ids) @("BW33N-B", "BW33N-C", "BW33N-D")) -and
    (Test-SequenceEqual @($preregistration.selection_contract.prospective_parsimony_order) @("BW33N-B", "BW33N-C", "BW33N-D")) -and
    [int]$preregistration.selection_contract.required_walking_pass_count -eq 3 -and
    [int]$preregistration.selection_contract.required_integrity_pass_count -eq 3 -and
    [int]$preregistration.selection_contract.required_failed_walking_gate_count -eq 0 -and
    [bool]$preregistration.selection_contract.every_reference_passing_seed_must_remain_passing -and
    [bool]$preregistration.selection_contract.first_eligible_candidate_in_parsimony_order_selected -and
    [string]$preregistration.selection_contract.no_eligible_candidate_selects -ceq "NONE" -and
    -not [bool]$preregistration.selection_contract.selection_grants_fresh_validation_authority -and
    -not [bool]$preregistration.selection_contract.selection_grants_rough_terrain_acceptance
) "BW33N selection contract changed"

Assert-Exact (
    [bool]$preregistration.inferential_ceiling.screen_may_rank_mechanisms_and_select_one_development_arm -and
    -not [bool]$preregistration.inferential_ceiling.screen_may_confirm_rough_terrain_robustness -and
    -not [bool]$preregistration.inferential_ceiling.screen_may_estimate_population_main_effects_or_interaction -and
    [bool]$preregistration.inferential_ceiling.three_outcome_exposed_seeds_per_arm_are_not_independent_validation -and
    [bool]$preregistration.inferential_ceiling.factorial_label_describes_the_frozen_parameter_grid_not_statistical_factorial_authority -and
    [bool]$preregistration.prospective_mechanism_interpretation.no_posthoc_interaction_story_if_d_fails_eligibility -and
    [bool]$preregistration.prospective_mechanism_interpretation.seedwise_patterns_are_descriptive_mechanism_evidence_not_causal_or_population_estimates -and
    ([string]$preregistration.prospective_mechanism_interpretation.midpoint_scale_main_effect_prediction).Contains("21002") -and
    ([string]$preregistration.prospective_mechanism_interpretation.lower_yaw_main_effect_prediction).Contains("21003") -and
    ([string]$preregistration.prospective_mechanism_interpretation.clean_double_dissociation_pattern).Contains("uniquely") -and
    ([string]$preregistration.prospective_mechanism_interpretation.interaction_worth_pursuing_pattern).Contains("neither BW33N-B nor BW33N-C reaches 3/3")
) "BW33N inferential ceiling or prospective mechanism interpretation changed"

$reservedSeeds = @(49101, 49102, 49103)
Assert-Exact (
    (Test-SequenceEqual @($manifest.reserved_fresh_validation_seeds) $reservedSeeds) -and
    (Test-SequenceEqual @($preregistration.pipeline_stages.stage_3_independent_validation.reserved_unopened_seed_ids) $reservedSeeds) -and
    [bool]$manifest.reserved_fresh_seeds_are_not_part_of_bw33n -and
    -not [bool]$preregistration.pipeline_stages.stage_3_independent_validation.reserved_seed_use_authorized
) "BW33N reserved validation seed boundary changed"
foreach ($cell in $cells) {
    Assert-Exact ($reservedSeeds -notcontains [int]$cell.campaign_seed) (
        "BW33N illegally includes a fresh reserved seed"
    )
}

foreach ($claimMap in @(
    $candidates,
    $preregistration,
    $preregistration.claims_before_and_after_development,
    $manifest
)) {
    foreach ($claimName in @(
        "physical_execution_authorized",
        "rough_terrain_acceptance",
        "release_authorized",
        "physical_acceptance_authority"
    )) {
        if ($claimMap.Contains($claimName)) {
            Assert-Exact (-not [bool]$claimMap[$claimName]) (
                "BW33N declaration inflated claim: $claimName"
            )
        }
    }
}
Assert-Exact (
    [int]$preregistration.world_build_count -eq 0 -and
    [int]$preregistration.pipeline_stages.stage_0_declaration.world_build_count -eq 0 -and
    -not [bool]$preregistration.pipeline_stages.stage_0_declaration.physical_execution_authorized -and
    [bool]$preregistration.staged_interlocks.physical_execution_blocked_at_stage_zero -and
    [bool]$preregistration.staged_interlocks.physical_run_requires_distinct_complete_stage_one_freeze -and
    [int]$manifest.world_build_count -eq 0 -and
    -not [bool]$manifest.physical_execution_authorized -and
    -not [bool]$manifest.selection_authority -and
    -not [bool]$manifest.independent_validation_authority -and
    -not [bool]$manifest.release_gate_promotion_authority -and
    -not [bool]$manifest.physical_acceptance_authority
) "BW33N stage-zero physical interlock changed"

$priorAttempts = @()
if (Test-Path -LiteralPath $evidenceRoot -PathType Container) {
    $priorAttempts = @(Get-ChildItem -LiteralPath $evidenceRoot -Filter attempt.json -File -Recurse |
        Where-Object {
            try {
                $attempt = Read-JsonMap $_.FullName
                [string]$attempt.campaign_id -ceq $campaignId
            } catch { $false }
        })
}
Assert-Exact ($priorAttempts.Count -eq 0) (
    "BW33N already has a retained physical attempt; declaration-only state is false"
)

Write-Host (
    "BW33N_DECLARATION_PASS cells=12 candidates=4 factors=2 rough_profiles=1 " +
    "exposed_seeds=3 authority_horizon=3232 branch_surfaces=0 " +
    "reserved_fresh_seeds=3 attempts=0 worlds=0 selection_authority=False " +
    "rough_authority=False physical_authority=False"
)
