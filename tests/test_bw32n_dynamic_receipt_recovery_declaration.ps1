[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [System.IO.Path]::GetFullPath(
    (Join-Path $PSScriptRoot "..")
)
$sdkRoot = Join-Path $repoRoot "sdk"
$evidenceRoot = [System.IO.Path]::GetFullPath(
    (Join-Path $repoRoot "..\SporeSpore_Evidence")
)
$campaignId = "BW32N-BW31N-DYNAMIC-RECEIPT-RECOVERY-DEVELOPMENT"
$gateId = "BW32N"
$implementationParent = "91a10826b27ba4aa1c153ea9af77034e09f87f40"
$preregistrationPath = Join-Path $sdkRoot (
    "balanced_wave_bw32n_dynamic_receipt_recovery_preregistration.json"
)
$candidatesPath = Join-Path $sdkRoot (
    "balanced_wave_bw32n_dynamic_receipt_recovery_candidates.json"
)
$manifestPath = Join-Path $sdkRoot (
    "balanced_wave_bw32n_dynamic_receipt_recovery_manifest.json"
)
$horizonPath = Join-Path $sdkRoot (
    "balanced_wave_bw32n_candidate_authority_exposure_horizon.json"
)
$bw31nClosurePath = Join-Path $sdkRoot "balanced_wave_bw31n_authority_horizon_closure.json"
$drp1ClosurePath = Join-Path $sdkRoot (
    "balanced_wave_dynamic_receipt_projection_drp1_closure.json"
)
$bw6nManifestPath = Join-Path $sdkRoot "balanced_wave_bw6n_validation_manifest.json"

$expectedHashes = [ordered]@{
    preregistration = "8d87510bf77c28f8145fb89b679be7e58c6a48fd66276624ad6bc7b4b1d15e38"
    candidates = "4abe3dc64f1d76a5e481cf82af89f6ce480c254589aafad9a8f1f04bae156a8f"
    manifest = "76521ce7a23ee4cabd64186fd87b5c9d2a4bd13c7916251e88df1f031e142783"
    horizon = "ec8291ecd54dbc8299d79d6b3adf176bf67fe851e4bacffc3df253c9a0a605df"
    bw31n_closure = "b92320e3122257829cebab3ae08c6dacc0aa2def055a649c1345e78b0a51e65f"
    drp1_closure = "34ecf649748015dbd066fc262afdd453b7dcb2a7edfc33a78e99cfd272d1d9c9"
    bw6n_manifest = "83886d8c893a4a6e5a960b06b3398d907a203a865e1ac66ed1870ea09dc3d38e"
}
$candidateBaseDigests = [ordered]@{
    "BW32N-A" = "sha256:794b42e64e1a89f371b0113ad1c3cf14c0a3d87abfed876323eda9e4aaeed1e6"
    "BW32N-B" = "sha256:3490c1934bb018ef68a54b5d5415c7d19dddf7696ee0ac7fca4ab27951957e4d"
}

function Assert-Exact {
    param([Parameter(Mandatory)][bool]$Condition, [Parameter(Mandatory)][string]$Message)
    if (-not $Condition) { throw $Message }
}

function Get-RawSha256 {
    param([Parameter(Mandatory)][string]$Path)
    return (Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash.ToLowerInvariant()
}

function Read-JsonMap {
    param([Parameter(Mandatory)][string]$Path)
    return Get-Content -Raw -LiteralPath $Path |
        ConvertFrom-Json -AsHashtable -Depth 100
}

function Test-SequenceEqual {
    param([Parameter(Mandatory)][object[]]$Actual, [Parameter(Mandatory)][object[]]$Expected)
    if ($Actual.Count -ne $Expected.Count) { return $false }
    for ($index = 0; $index -lt $Expected.Count; $index++) {
        if ([string]$Actual[$index] -cne [string]$Expected[$index]) { return $false }
    }
    return $true
}

foreach ($requiredPath in @(
    $preregistrationPath,
    $candidatesPath,
    $manifestPath,
    $horizonPath,
    $bw31nClosurePath,
    $drp1ClosurePath,
    $bw6nManifestPath
)) {
    Assert-Exact (Test-Path -LiteralPath $requiredPath -PathType Leaf) (
        "Missing BW32N declaration authority: $requiredPath"
    )
}

Assert-Exact ((Get-RawSha256 $preregistrationPath) -ceq $expectedHashes.preregistration) (
    "BW32N preregistration raw hash changed"
)
Assert-Exact ((Get-RawSha256 $candidatesPath) -ceq $expectedHashes.candidates) (
    "BW32N candidate declaration raw hash changed"
)
Assert-Exact ((Get-RawSha256 $manifestPath) -ceq $expectedHashes.manifest) (
    "BW32N manifest raw hash changed"
)
Assert-Exact ((Get-RawSha256 $horizonPath) -ceq $expectedHashes.horizon) (
    "BW32N authority-horizon raw hash changed"
)
Assert-Exact ((Get-RawSha256 $bw31nClosurePath) -ceq $expectedHashes.bw31n_closure) (
    "BW31N immutable closure changed"
)
Assert-Exact ((Get-RawSha256 $drp1ClosurePath) -ceq $expectedHashes.drp1_closure) (
    "DRP1 positive closure changed"
)
Assert-Exact ((Get-RawSha256 $bw6nManifestPath) -ceq $expectedHashes.bw6n_manifest) (
    "BW6N frozen challenge manifest changed"
)

$preregistration = Read-JsonMap $preregistrationPath
$candidates = Read-JsonMap $candidatesPath
$manifest = Read-JsonMap $manifestPath
$horizon = Read-JsonMap $horizonPath
$bw31nClosure = Read-JsonMap $bw31nClosurePath
$drp1Closure = Read-JsonMap $drp1ClosurePath

foreach ($authority in @($preregistration, $candidates, $manifest, $horizon)) {
    Assert-Exact ([string]$authority.campaign_id -ceq $campaignId) (
        "BW32N campaign identity changed"
    )
    Assert-Exact ([string]$authority.gate_id -ceq $gateId) (
        "BW32N gate identity changed"
    )
    Assert-Exact ([string]$authority.implementation_parent_commit -ceq $implementationParent) (
        "BW32N implementation parent changed"
    )
}

Assert-Exact (
    [string]$preregistration.source_bindings.candidate_declarations.raw_sha256 -ceq (
        $expectedHashes.candidates
    ) -and
    [string]$preregistration.source_bindings.candidate_authority_exposure_horizon.raw_sha256 -ceq (
        $expectedHashes.horizon
    ) -and
    [string]$preregistration.source_bindings.bw31n_immutable_invalid_closure.raw_sha256 -ceq (
        $expectedHashes.bw31n_closure
    ) -and
    [string]$preregistration.source_bindings.drp1_positive_dynamic_receipt_regression_closure.raw_sha256 -ceq (
        $expectedHashes.drp1_closure
    ) -and
    [string]$preregistration.source_bindings.bw6n_frozen_challenge_manifest.raw_sha256 -ceq (
        $expectedHashes.bw6n_manifest
    ) -and
    [string]$manifest.source_bindings.preregistration.raw_sha256 -ceq (
        $expectedHashes.preregistration
    ) -and
    [string]$manifest.source_bindings.candidate_declarations.raw_sha256 -ceq (
        $expectedHashes.candidates
    ) -and
    [string]$manifest.source_bindings.candidate_authority_exposure_horizon.raw_sha256 -ceq (
        $expectedHashes.horizon
    ) -and
    [string]$manifest.source_bindings.bw31n_immutable_invalid_closure.raw_sha256 -ceq (
        $expectedHashes.bw31n_closure
    ) -and
    [string]$manifest.source_bindings.drp1_positive_dynamic_receipt_regression_closure.raw_sha256 -ceq (
        $expectedHashes.drp1_closure
    ) -and
    [string]$manifest.source_bindings.bw6n_frozen_challenge_manifest.raw_sha256 -ceq (
        $expectedHashes.bw6n_manifest
    )
) "BW32N stage-zero source binding changed"

Assert-Exact (
    [string]$bw31nClosure.status -ceq (
        "closed_implementation_invalid_after_complete_physical_matrix_and_frozen_evaluation"
    ) -and
    [string]$bw31nClosure.campaign_id -ceq (
        "BW31N-BW30N-AUTHORITY-HORIZON-RECOVERY-DEVELOPMENT"
    ) -and
    [string]$bw31nClosure.gate_id -ceq "BW31N" -and
    [bool]$bw31nClosure.immutability.same_identity_rerun_forbidden -and
    [bool]$bw31nClosure.successor_requirements.same_bw31n_identity_may_not_be_repaired_or_rerun -and
    [bool]$bw31nClosure.successor_requirements.candidate_application_must_be_recomputed_from_3232_authority_tick_primitive_counts -and
    [bool]$bw31nClosure.successor_requirements.actual_dynamic_reference_and_successor_receipts_must_traverse_the_shared_composer_and_complete_evaluator_before_one_shot_physics -and
    [bool]$bw31nClosure.successor_requirements.repeatable_noncampaign_regression_physics_must_exercise_the_long_horizon_parent_summary_projection_after_zero_world_gates -and
    -not [bool]$bw31nClosure.successor_requirements.bw31n_b_may_be_promoted_from_this_result
) "BW32N no longer binds the immutable BW31N successor requirements"

Assert-Exact (
    [string]$drp1Closure.status -ceq "complete_repeatable_dynamic_receipt_regression_passed" -and
    [string]$drp1Closure.regression_id -ceq (
        "BW31N-DYNAMIC-RECEIPT-PROJECTION-REGRESSION-DRP1"
    ) -and
    [bool]$drp1Closure.regression_conclusion.dynamic_reference_receipt_projection_passed -and
    [bool]$drp1Closure.regression_conclusion.dynamic_successor_receipt_projection_passed -and
    [bool]$drp1Closure.regression_conclusion.shared_outer_schema_passed -and
    [bool]$drp1Closure.regression_conclusion.route_specific_nested_schema_passed -and
    [bool]$drp1Closure.regression_conclusion.common_execution_integrity_passed -and
    [bool]$drp1Closure.regression_conclusion.implementation_regression_positive -and
    -not [bool]$drp1Closure.regression_conclusion.locomotion_positive -and
    -not [bool]$drp1Closure.regression_conclusion.locomotion_negative -and
    [bool]$drp1Closure.next_work_authority.separately_preregistered_development_campaign_declaration_permitted -and
    -not [bool]$drp1Closure.next_work_authority.development_campaign_execution_authorized_by_this_closure -and
    -not [bool]$drp1Closure.next_work_authority.fresh_validation_seed_use_authorized
) "BW32N no longer binds the complete positive DRP1 implementation prerequisite"

$derivedCount = (
    [int]$horizon.derivation.warmup_cycle_ticks_after_post_settle_authority_start +
    [int]$horizon.derivation.evidence_boundary_alignment_ticks +
    [int]$horizon.derivation.evidence_cycle_ticks +
    [int]$horizon.derivation.maximum_contact_gated_evidence_extension_ticks +
    [int]$horizon.derivation.cooldown_cycle_ticks +
    [int]$horizon.derivation.terminal_settle_ticks
)
Assert-Exact (
    [string]$horizon.schema_version -ceq (
        "sporespore_balanced_wave_bw32n_candidate_authority_exposure_horizon_v1"
    ) -and
    [string]$horizon.policy_id -ceq "fixed_candidate_authority_exposure_horizon_v1" -and
    [string]$horizon.authority_exposure_anchor -ceq (
        "first_successful_native_or_overlay_candidate_authority_application"
    ) -and
    $derivedCount -eq 3232 -and
    [int]$horizon.derivation.derived_exact_candidate_authority_observation_count -eq 3232 -and
    [int]$horizon.first_candidate_authority_observation_index -eq 0 -and
    [int]$horizon.last_candidate_authority_observation_index -eq 3231 -and
    [int]$horizon.exact_candidate_authority_observation_count -eq 3232 -and
    [int]$horizon.candidate_specific_horizon_extension_count -eq 0 -and
    -not [bool]$horizon.pre_authority_world_ticks_count_toward_exposure -and
    -not [bool]$horizon.pre_authority_support_or_warmup_ticks_count_toward_exposure -and
    -not [bool]$horizon.derivation.uses_observed_walking_outcomes_to_set_horizon -and
    -not [bool]$horizon.derivation.uses_bw29n_bw30n_bw31n_or_drp1_walking_outcomes_to_set_horizon -and
    [bool]$horizon.derivation.inherits_the_prospectively_derived_bw31n_horizon_without_modification -and
    [int]$horizon.challenge_contract.push_step_from_candidate_authority_start -eq 540 -and
    [int]$horizon.challenge_contract.sensor_noise_observation_fault_application_count -eq 3232 -and
    [int]$horizon.challenge_contract.sensor_noise_base_and_stability_fault_count -eq 3232 -and
    [bool]$horizon.challenge_contract.challenge_application_count_is_candidate_independent -and
    [bool]$horizon.route_contract.both_routes_must_project_from_actual_dynamic_parent_summaries -and
    [bool]$horizon.route_contract.drp1_route_projection_qualification_required -and
    [string]$horizon.receipt_contract.required_final_receipt_schema -ceq (
        "sporespore_balanced_wave_bw32n_dynamic_receipt_recovery_raw_cell_v1"
    ) -and
    [string]$horizon.receipt_contract.required_final_receipt_composer_id -ceq (
        "bw32n_dynamic_parent_summary_composer_v1"
    ) -and
    [bool]$horizon.receipt_contract.one_shared_campaign_composer_for_both_routes -and
    [bool]$horizon.receipt_contract.route_specific_nested_walking_schema_preserved -and
    [int]$horizon.world_build_count -eq 0 -and
    -not [bool]$horizon.physical_execution_authorized
) "BW32N schedule-derived candidate-authority horizon changed"

Assert-Exact (
    [string]$preregistration.schema_version -ceq (
        "sporespore_balanced_wave_bw32n_dynamic_receipt_recovery_preregistration_v1"
    ) -and
    [string]$preregistration.study_class.classification -ceq (
        "paired_outcome_exposed_exact_finite_dynamic_receipt_recovery_development_screen"
    ) -and
    [bool]$preregistration.study_class.scientifically_distinct_from_bw29n_bw30n_and_bw31n -and
    -not [bool]$preregistration.study_class.population_inference -and
    -not [bool]$preregistration.study_class.superiority_study -and
    -not [bool]$preregistration.study_class.noninferiority_or_equivalence_study -and
    [bool]$preregistration.dynamic_receipt_contract.drp1_closure_required -and
    [int]$preregistration.dynamic_receipt_contract.drp1_complete_gate_count -eq 12 -and
    [int]$preregistration.dynamic_receipt_contract.drp1_complete_dynamic_world_count -eq 24 -and
    [bool]$preregistration.dynamic_receipt_contract.actual_dynamic_parent_summary_required_for_every_physical_receipt -and
    [bool]$preregistration.dynamic_receipt_contract.constructed_parent_summary_substitution_for_physical_execution_forbidden -and
    [string]$preregistration.dynamic_receipt_contract.required_final_receipt_schema -ceq (
        "sporespore_balanced_wave_bw32n_dynamic_receipt_recovery_raw_cell_v1"
    ) -and
    [string]$preregistration.dynamic_receipt_contract.required_final_receipt_composer_id -ceq (
        "bw32n_dynamic_parent_summary_composer_v1"
    ) -and
    [bool]$preregistration.dynamic_receipt_contract.one_campaign_specific_shared_composer_required_for_both_routes -and
    [bool]$preregistration.dynamic_receipt_contract.route_specific_nested_walking_schema_preserved -and
    [bool]$preregistration.dynamic_receipt_contract.drp1_regression_seed_ids_may_not_be_used_for_candidate_selection
) "BW32N scientific classification or dynamic-receipt contract changed"

$candidateOrder = @($candidates.candidate_order)
Assert-Exact (Test-SequenceEqual $candidateOrder @("BW32N-A", "BW32N-B")) (
    "BW32N candidate order changed"
)
Assert-Exact (@($candidates.candidates).Count -eq 2) "BW32N candidate count changed"
foreach ($candidateId in $candidateOrder) {
    $candidate = @($candidates.candidates | Where-Object {
        [string]$_.candidate_id -ceq [string]$candidateId
    })
    Assert-Exact ($candidate.Count -eq 1) "BW32N candidate declaration missing or duplicated"
    $candidate = $candidate[0]
    $expectedRouteId = if ($candidateId -ceq "BW32N-A") {
        "DRP1-REFERENCE-ROUTE"
    } else { "DRP1-SUCCESSOR-ROUTE" }
    Assert-Exact (
        [string]$candidate.schema_version -ceq (
            "sporespore_bw32n_dynamic_receipt_recovery_candidate_v1"
        ) -and
        [string]$candidate.base_composition_digest -ceq $candidateBaseDigests[$candidateId] -and
        [string]$candidate.authority_horizon_policy_id -ceq (
            "fixed_candidate_authority_exposure_horizon_v1"
        ) -and
        [string]$candidate.authority_horizon_policy_sha256 -ceq (
            "sha256:$($expectedHashes.horizon)"
        ) -and
        [int]$candidate.exact_candidate_authority_observation_count -eq 3232 -and
        [int]$candidate.expected_native_motor_write_count -eq 25856 -and
        -not [bool]$candidate.pre_authority_world_ticks_count_toward_exposure -and
        [int]$candidate.candidate_specific_horizon_extension_count -eq 0 -and
        [string]$candidate.dynamic_parent_summary_route_id -ceq $expectedRouteId -and
        [bool]$candidate.dynamic_parent_summary_required -and
        [string]$candidate.prospective_final_receipt_schema -ceq (
            "sporespore_balanced_wave_bw32n_dynamic_receipt_recovery_raw_cell_v1"
        ) -and
        [string]$candidate.prospective_final_receipt_composer_id -ceq (
            "bw32n_dynamic_parent_summary_composer_v1"
        ) -and
        [bool]$candidate.scientifically_distinct_successor_composition -and
        -not [bool]$candidate.physical_acceptance_authority
    ) "BW32N candidate authority contract changed for $candidateId"
    foreach ($countName in @(
        "morphology_condition_count",
        "material_condition_count",
        "seed_condition_count",
        "challenge_condition_count",
        "failure_identity_condition_count",
        "outcome_condition_count"
    )) {
        Assert-Exact ([int]$candidate[$countName] -eq 0) (
            "BW32N candidate conditions are not branch-free for $candidateId/$countName"
        )
    }
    Assert-Exact (@($candidate.branch_surfaces).Count -eq 0) (
        "BW32N candidate branch surfaces changed for $candidateId"
    )
}

$expectedProfiles = @(
    "bw6n_baseline_v1",
    "bw6n_rough_v1",
    "bw6n_push_v1",
    "bw6n_sensor_noise_v1"
)
$expectedSeeds = @(21001, 21002, 21003)
$cells = @($manifest.ordered_cells)
Assert-Exact ($cells.Count -eq 24) "BW32N manifest must contain exactly 24 cells"
$ordinal = 0
$seen = @{}
foreach ($profile in $expectedProfiles) {
    $prefix = if ($profile -ceq "bw6n_sensor_noise_v1") {
        "sensor_noise"
    } else { ($profile -replace '^bw6n_', '' -replace '_v1$', '') }
    foreach ($seed in $expectedSeeds) {
        foreach ($candidateId in $candidateOrder) {
            $cell = $cells[$ordinal]
            $suffix = if ($candidateId -ceq "BW32N-A") { "a" } else { "b" }
            $expectedCellId = "${prefix}_s${seed}_bw32n_${suffix}"
            Assert-Exact (
                [string]$cell.cell_id -ceq $expectedCellId -and
                [string]$cell.cohort -ceq "paired_outcome_exposed_dynamic_receipt_recovery" -and
                [string]$cell.challenge_profile_id -ceq $profile -and
                [int]$cell.campaign_seed -eq $seed -and
                [string]$cell.candidate_id -ceq $candidateId -and
                [string]$cell.candidate_base_composition_digest -ceq (
                    $candidateBaseDigests[$candidateId]
                ) -and
                [string]$cell.authority_horizon_policy_id -ceq (
                    "fixed_candidate_authority_exposure_horizon_v1"
                ) -and
                [int]$cell.expected_candidate_authority_observation_count -eq 3232
            ) "BW32N ordered cell changed at ordinal $ordinal"
            Assert-Exact (-not $seen.ContainsKey($expectedCellId)) (
                "BW32N cell identity duplicated: $expectedCellId"
            )
            $seen[$expectedCellId] = $true
            $ordinal += 1
        }
    }
}

Assert-Exact (
    (Test-SequenceEqual @($manifest.matrix_contract.candidate_order) $candidateOrder) -and
    (Test-SequenceEqual @($manifest.matrix_contract.challenge_profile_order) $expectedProfiles) -and
    (Test-SequenceEqual @($manifest.matrix_contract.seed_order) $expectedSeeds) -and
    [int]$manifest.matrix_contract.expected_world_count -eq 24 -and
    [int]$manifest.matrix_contract.fixed_candidate_authority_observation_count -eq 3232 -and
    [int]$manifest.matrix_contract.candidate_specific_horizon_extension_count -eq 0 -and
    [bool]$manifest.matrix_contract.pre_authority_ticks_excluded -and
    [bool]$manifest.matrix_contract.all_cells_required -and
    [bool]$manifest.matrix_contract.early_stop_forbidden -and
    [bool]$manifest.matrix_contract.rerun_or_replacement_forbidden
) "BW32N matrix contract changed"

$reservedSeeds = @(49101, 49102, 49103)
Assert-Exact (
    (Test-SequenceEqual @($manifest.reserved_fresh_validation_seeds) $reservedSeeds) -and
    (Test-SequenceEqual @(
        $preregistration.pipeline_stages.stage_2_independent_nuisance_validation.reserved_unopened_seed_ids
    ) $reservedSeeds) -and
    [bool]$manifest.reserved_fresh_seeds_are_not_part_of_bw32n -and
    -not [bool]$preregistration.pipeline_stages.stage_2_independent_nuisance_validation.reserved_seed_use_authorized_at_stage_zero
) "BW32N fresh validation seed boundary changed"
foreach ($cell in $cells) {
    Assert-Exact ($reservedSeeds -notcontains [int]$cell.campaign_seed) (
        "BW32N stage one illegally includes a fresh reserved seed"
    )
}
$regressionSeeds = @(22001, 22002, 22003)
foreach ($cell in $cells) {
    Assert-Exact ($regressionSeeds -notcontains [int]$cell.campaign_seed) (
        "BW32N stage one illegally promotes a DRP1 regression seed"
    )
}

foreach ($claimMap in @(
    $preregistration.claims_before_and_after_development,
    $horizon
)) {
    foreach ($claimName in @(
        "walking_acceptance",
        "nuisance_acceptance",
        "release_authorized",
        "physical_acceptance_authority"
    )) {
        Assert-Exact (-not [bool]$claimMap[$claimName]) (
            "BW32N declaration inflated claim: $claimName"
        )
    }
}
Assert-Exact (
    [int]$preregistration.pipeline_stages.stage_0_declaration.world_build_count -eq 0 -and
    -not [bool]$preregistration.pipeline_stages.stage_0_declaration.physical_execution_authorized -and
    [bool]$preregistration.staged_interlocks.physical_execution_blocked_at_stage_zero -and
    [bool]$preregistration.staged_interlocks.physical_run_requires_distinct_complete_stage_one_freeze -and
    [bool]$preregistration.staged_interlocks.drp1_regression_seeds_may_not_become_campaign_seeds -and
    [bool]$manifest.preflight_contract.bw31n_invalid_closure_verified -and
    [bool]$manifest.preflight_contract.drp1_positive_dynamic_receipt_regression_verified -and
    [bool]$manifest.preflight_contract.actual_dynamic_parent_summary_required_for_physical_receipts -and
    -not [bool]$manifest.physical_execution_authorized -and
    -not [bool]$manifest.independent_validation_authority -and
    -not [bool]$manifest.release_gate_promotion_authority -and
    -not [bool]$manifest.physical_acceptance_authority
) "BW32N stage-zero physical interlock changed"

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
    "BW32N already has a retained physical attempt; declaration-only state is false"
)

Write-Host (
    "BW32N_DECLARATION_PASS cells=24 candidates=2 profiles=4 exposed_seeds=3 " +
    "authority_horizon=3232 pre_authority_excluded=True dynamic_parent_summary=True " +
    "drp1_qualified=True reserved_fresh_seeds=3 attempts=0 worlds=0 selection_authority=False " +
    "nuisance_authority=False physical_authority=False"
)
