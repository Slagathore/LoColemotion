#requires -Version 7.0

[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [System.IO.Path]::GetFullPath(
    (Split-Path -Parent $PSScriptRoot)
)
$sdkRoot = Join-Path $repoRoot "sdk"
$evidenceRoot = [System.IO.Path]::GetFullPath(
    (Join-Path (Split-Path -Parent $repoRoot) "SporeSpore_Evidence")
)
$campaignId = "BW30N-BW29N-IMPLEMENTATION-RECOVERY-DEVELOPMENT"
$gateId = "BW30N"
$implementationParent = "34516c1723450f3afcaec596d44904b77bfc6258"
$preregistrationPath = Join-Path $sdkRoot (
    "balanced_wave_bw30n_recovery_preregistration.json"
)
$candidatesPath = Join-Path $sdkRoot (
    "balanced_wave_bw30n_recovery_candidates.json"
)
$manifestPath = Join-Path $sdkRoot (
    "balanced_wave_bw30n_recovery_manifest.json"
)
$horizonPath = Join-Path $sdkRoot (
    "balanced_wave_bw30n_fixed_observation_horizon.json"
)
$bw29nClosureAuditPath = Join-Path $repoRoot (
    "tests\test_bw29n_nuisance_transfer_closure.ps1"
)
$expectedHashes = [ordered]@{
    "sdk/balanced_wave_bw30n_recovery_preregistration.json" =
        "d4ea40c06241a96eb1854392ad86cc8dc0ba2632e502bd39725fb587abe9aea8"
    "sdk/balanced_wave_bw30n_recovery_candidates.json" =
        "7725baa0fcc0693da289987d81975513b02fe1f2afee634b08ccd7161805f1dd"
    "sdk/balanced_wave_bw30n_recovery_manifest.json" =
        "f9c265cc5e9a1b147edcf07e0076e8405140b217454d9cb3bc14c2ebfacf8c8d"
    "sdk/balanced_wave_bw30n_fixed_observation_horizon.json" =
        "3b76314d6d0726746644f4c66ae67da01364a353d199562f3ed9843be349d912"
}
$candidateDigests = [ordered]@{
    "BW30N-A" =
        "sha256:794b42e64e1a89f371b0113ad1c3cf14c0a3d87abfed876323eda9e4aaeed1e6"
    "BW30N-B" =
        "sha256:3490c1934bb018ef68a54b5d5415c7d19dddf7696ee0ac7fca4ab27951957e4d"
}

function Assert-Exact {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function Get-Bw30nRawSha256 {
    param([Parameter(Mandatory)][string]$Path)
    return (
        Get-FileHash -Algorithm SHA256 -LiteralPath $Path
    ).Hash.ToLowerInvariant()
}

function Read-JsonMap {
    param([Parameter(Mandatory)][string]$Path)
    return Get-Content -Raw -LiteralPath $Path |
        ConvertFrom-Json -AsHashtable -Depth 100
}

function Assert-ExactKeys {
    param(
        [Parameter(Mandatory)][System.Collections.IDictionary]$Map,
        [Parameter(Mandatory)][string[]]$Keys,
        [Parameter(Mandatory)][string]$Context
    )
    $actual = @($Map.Keys | ForEach-Object { [string]$_ } | Sort-Object)
    $expected = @($Keys | Sort-Object)
    Assert-Exact (
        $actual.Count -eq $expected.Count -and
        ($actual -join "`n") -ceq ($expected -join "`n")
    ) "$Context exact key set changed"
}

function Test-SequenceEqual {
    param(
        [Parameter(Mandatory)][AllowEmptyCollection()][object[]]$Actual,
        [Parameter(Mandatory)][AllowEmptyCollection()][object[]]$Expected
    )
    if ($Actual.Count -ne $Expected.Count) { return $false }
    for ($index = 0; $index -lt $Expected.Count; $index += 1) {
        if ([string]$Actual[$index] -cne [string]$Expected[$index]) {
            return $false
        }
    }
    return $true
}

foreach ($binding in $expectedHashes.GetEnumerator()) {
    $path = Join-Path $repoRoot ([string]$binding.Key)
    Assert-Exact (
        (Test-Path -LiteralPath $path -PathType Leaf) -and
        (Get-Bw30nRawSha256 -Path $path) -ceq [string]$binding.Value
    ) "$gateId stage-zero declaration changed: $($binding.Key)"
}

$preregistration = Read-JsonMap -Path $preregistrationPath
$candidates = Read-JsonMap -Path $candidatesPath
$manifest = Read-JsonMap -Path $manifestPath
$horizon = Read-JsonMap -Path $horizonPath

Assert-Exact (
    [string]$preregistration.schema_version -ceq
        "sporespore_balanced_wave_bw30n_recovery_preregistration_v1" -and
    [string]$candidates.schema_version -ceq
        "sporespore_balanced_wave_bw30n_recovery_candidates_v1" -and
    [string]$manifest.schema_version -ceq
        "sporespore_balanced_wave_bw30n_recovery_manifest_v1" -and
    [string]$horizon.schema_version -ceq
        "sporespore_balanced_wave_bw30n_fixed_observation_horizon_v1"
) "$gateId declaration schema changed"

foreach ($document in @($preregistration, $candidates, $manifest)) {
    Assert-Exact (
        [string]$document.campaign_id -ceq $campaignId -and
        [string]$document.gate_id -ceq $gateId -and
        [string]$document.implementation_parent_commit -ceq
            $implementationParent -and
        [string]$document.status -cmatch
            "prospective.*zero_world.*physical_execution_blocked"
    ) "$gateId declaration identity or stage changed"
}
& git -C $repoRoot cat-file -e "${implementationParent}^{commit}" 2>$null
Assert-Exact ($LASTEXITCODE -eq 0) (
    "$gateId implementation parent does not exist"
)

foreach ($sourceBinding in @(
    @($preregistration.source_bindings.Values) +
    @($manifest.source_bindings.Values)
)) {
    $path = Join-Path $repoRoot ([string]$sourceBinding.path)
    Assert-Exact (
        (Test-Path -LiteralPath $path -PathType Leaf) -and
        (Get-Bw30nRawSha256 -Path $path) -ceq
            [string]$sourceBinding.raw_sha256
    ) "$gateId source binding changed: $($sourceBinding.path)"
}

& pwsh `
    -NoLogo `
    -NoProfile `
    -File $bw29nClosureAuditPath
Assert-Exact ($LASTEXITCODE -eq 0) (
    "$gateId prerequisite BW29N invalid closure audit failed"
)
Assert-Exact (
    [bool]$preregistration.historical_result_boundary.bw6n_remains_immutable_16_of_24_closed_negative -and
    [bool]$preregistration.historical_result_boundary.bw29n_remains_immutable_implementation_invalid -and
    [bool]$preregistration.historical_result_boundary.bw29n_remains_not_a_locomotion_negative -and
    [bool]$preregistration.historical_result_boundary.bw29n_remains_not_a_valid_none_selection -and
    [bool]$preregistration.historical_result_boundary.bw29n_b_remains_unselected_and_unpromoted -and
    [bool]$preregistration.historical_result_boundary.bw29n_same_identity_repair_or_rerun_forbidden -and
    [bool]$preregistration.historical_result_boundary.bw29n_descriptive_observations_may_inform_bw30n_design_only -and
    [bool]$preregistration.historical_result_boundary.bw30n_is_a_distinct_successor_campaign
) "$gateId historical-result boundary changed"

Assert-Exact (
    [string]$preregistration.study_class.classification -ceq
        "paired_outcome_exposed_exact_finite_implementation_recovery_development_screen" -and
    [bool]$preregistration.study_class.scientifically_distinct_from_bw29n -and
    [bool]$preregistration.study_class.outcome_exposed_profiles -and
    [bool]$preregistration.study_class.outcome_exposed_seeds -and
    [int]$preregistration.study_class.expected_candidate_count -eq 2 -and
    [int]$preregistration.study_class.expected_world_count -eq 24 -and
    -not [bool]$preregistration.study_class.population_inference -and
    -not [bool]$preregistration.study_class.superiority_study -and
    -not [bool]$preregistration.study_class.noninferiority_or_equivalence_study -and
    -not [bool]$preregistration.study_class.single_mechanism_causal_attribution -and
    [bool]$preregistration.study_class.development_result_may_validly_select_none -and
    [bool]$preregistration.study_class.selected_candidate_requires_distinct_independent_validation -and
    -not [bool]$preregistration.study_class.bw29n_posthoc_reclassification_or_repair
) "$gateId study class changed"

Assert-Exact (
    [string]$horizon.policy_id -ceq
        "fixed_post_sdk_observation_horizon_v1" -and
    [string]$horizon.classification -ceq
        "candidate_independent_wall_clock_observation_and_outcome_horizon" -and
    [int]$horizon.physics_hz -eq 120 -and
    [bool]$horizon.one_sdk_observation_per_physics_tick -and
    [int]$horizon.first_post_sdk_observation_index -eq 0 -and
    [int]$horizon.last_post_sdk_observation_index -eq 1513 -and
    [int]$horizon.exact_post_sdk_observation_count -eq 1514 -and
    [bool]$horizon.horizon_begins_at_first_sdk_sample_after_common_settle_and_authority_start -and
    -not [bool]$horizon.evidence_support_acquisition_may_extend_horizon -and
    -not [bool]$horizon.contact_gated_phase_progression_may_extend_horizon -and
    [bool]$horizon.candidate_specific_horizon_extension_forbidden -and
    [bool]$horizon.outcome_based_early_stop_forbidden -and
    [int]$horizon.post_horizon_physics_or_policy_steps -eq 0 -and
    [bool]$horizon.walking_outcome_terminalized_at_exact_horizon -and
    [bool]$horizon.incomplete_gait_or_terminal_contact_conjunction_at_horizon_is_a_complete_walking_negative -and
    [int]$horizon.challenge_contract.sensor_noise_observation_fault_application_count -eq 1514 -and
    [int]$horizon.challenge_contract.sensor_noise_base_and_stability_fault_count -eq 1514 -and
    [int]$horizon.challenge_contract.push_step_from_sdk_start -eq 540 -and
    [int]$horizon.receipt_contract.candidate_specific_horizon_extension_count -eq 0 -and
    [bool]$horizon.receipt_contract.same_values_required_for_reference_and_successor -and
    [int]$horizon.world_build_count -eq 0 -and
    -not [bool]$horizon.physical_execution_authorized -and
    -not [bool]$horizon.walking_acceptance -and
    -not [bool]$horizon.nuisance_acceptance -and
    -not [bool]$horizon.release_authorized -and
    -not [bool]$horizon.physical_acceptance_authority
) "$gateId fixed terminal-horizon contract changed"

$candidateOrder = @($candidates.candidate_order)
Assert-Exact (
    Test-SequenceEqual `
        -Actual $candidateOrder `
        -Expected @("BW30N-A", "BW30N-B")
) "$gateId candidate order changed"
Assert-Exact (@($candidates.candidates).Count -eq 2) (
    "$gateId must declare exactly two candidates"
)
foreach ($candidateId in @("BW30N-A", "BW30N-B")) {
    $candidate = @($candidates.candidates | Where-Object {
        [string]$_.candidate_id -ceq $candidateId
    }) | Select-Object -First 1
    Assert-Exact ($null -ne $candidate) (
        "$gateId candidate is missing: $candidateId"
    )
    Assert-Exact (
        [string]$candidates.candidate_composition_digests[$candidateId] -ceq
            [string]$candidateDigests[$candidateId] -and
        [string]$candidate.evidence_acquisition_policy_id -ceq
            "bounded_all_support_acquisition_v1" -and
        [int]$candidate.evidence_acquisition_maximum_ticks -eq 15 -and
        [int]$candidate.evidence_acquisition_minimum_all_support_dwell_ticks -eq 3 -and
        [string]$candidate.terminal_horizon_policy_id -ceq
            "fixed_post_sdk_observation_horizon_v1" -and
        [string]$candidate.terminal_horizon_policy_sha256 -ceq
            "sha256:3b76314d6d0726746644f4c66ae67da01364a353d199562f3ed9843be349d912" -and
        [int]$candidate.exact_post_sdk_observation_count -eq 1514 -and
        [int]$candidate.candidate_specific_horizon_extension_count -eq 0 -and
        [string]$candidate.final_receipt_schema_version -ceq
            "sporespore_balanced_wave_bw30n_recovery_raw_cell_v1" -and
        [string]$candidate.material_profile_field_name -ceq
            "material_profile_sha256" -and
        @($candidate.branch_surfaces).Count -eq 0 -and
        -not [bool]$candidate.physical_acceptance_authority
    ) "$gateId candidate common contract changed: $candidateId"
    foreach ($countName in @(
        "morphology_condition_count",
        "material_condition_count",
        "seed_condition_count",
        "challenge_condition_count",
        "failure_identity_condition_count",
        "outcome_condition_count"
    )) {
        Assert-Exact ([int]$candidate[$countName] -eq 0) (
            "$gateId candidate conditions on ${countName}: $candidateId"
        )
    }
}
$candidateA = @($candidates.candidates | Where-Object {
    [string]$_.candidate_id -ceq "BW30N-A"
}) | Select-Object -First 1
$candidateB = @($candidates.candidates | Where-Object {
    [string]$_.candidate_id -ceq "BW30N-B"
}) | Select-Object -First 1
Assert-Exact (
    [string]$candidateA.controller_policy_id -ceq
        "sporespore_balanced_wave_bw5r_b_v1" -and
    [string]$candidateA.stability_policy_id -ceq
        "p5i3c_support_centroid_tilt_feedback_v1" -and
    [string]$candidateA.authority_scope -ceq
        "stability_contribution_overlay" -and
    [string]$candidateB.controller_policy_id -ceq
        "sporespore_balanced_wave_bw15f_b_v1" -and
    [string]$candidateB.stability_policy_id -ceq
        "sporespore_scheduled_load_transfer_bw13p_a_v3" -and
    [string]$candidateB.authority_scope -ceq "post_settle_full" -and
    [double]$candidateB.global_requested_correction_scale -eq 0.5
) "$gateId exact candidate composition changed"
Assert-Exact (
    [bool]$candidates.controlled_comparison.terminal_horizon_policy_held_identical -and
    [bool]$candidates.controlled_comparison.final_receipt_schema_and_composer_held_identical -and
    [bool]$candidates.controlled_comparison.candidate_specific_horizon_extension_forbidden -and
    [bool]$candidates.controlled_comparison.candidate_specific_conditioning_forbidden -and
    -not [bool]$candidates.controlled_comparison.single_mechanism_causal_attribution_authorized -and
    -not [bool]$candidates.controlled_comparison.bw29n_descriptive_observations_select_or_promote_bw30n_b
) "$gateId controlled-comparison boundary changed"

$profiles = @(
    [ordered]@{ id = "bw6n_baseline_v1"; token = "baseline" },
    [ordered]@{ id = "bw6n_rough_v1"; token = "rough" },
    [ordered]@{ id = "bw6n_push_v1"; token = "push" },
    [ordered]@{ id = "bw6n_sensor_noise_v1"; token = "sensor_noise" }
)
$seeds = @(21001, 21002, 21003)
$candidateSpecs = @(
    [ordered]@{ id = "BW30N-A"; suffix = "bw30n_a" },
    [ordered]@{ id = "BW30N-B"; suffix = "bw30n_b" }
)
$expectedCells = [System.Collections.Generic.List[object]]::new()
foreach ($profile in $profiles) {
    foreach ($seed in $seeds) {
        foreach ($candidate in $candidateSpecs) {
            [void]$expectedCells.Add([ordered]@{
                cell_id = "$($profile.token)_s${seed}_$($candidate.suffix)"
                cohort = "paired_outcome_exposed_implementation_recovery"
                role = "candidate"
                campaign_seed = $seed
                challenge_profile_id = $profile.id
                candidate_id = $candidate.id
                candidate_composition_digest =
                    [string]$candidateDigests[$candidate.id]
                material_profile_id = "godot_jolt_bw5c_mu095_v1"
                measurement_policy_id = "bounded_all_support_acquisition_v1"
                terminal_horizon_policy_id =
                    "fixed_post_sdk_observation_horizon_v1"
                expected_post_sdk_observation_count = 1514
            })
        }
    }
}
$cells = @($manifest.ordered_cells)
Assert-Exact (
    $cells.Count -eq 24 -and $expectedCells.Count -eq 24 -and
    [int]$manifest.matrix_contract.expected_world_count -eq 24 -and
    [int]$manifest.matrix_contract.fixed_post_sdk_observation_count -eq 1514 -and
    [int]$manifest.matrix_contract.candidate_specific_horizon_extension_count -eq 0 -and
    [bool]$manifest.matrix_contract.outcome_exposed -and
    -not [bool]$manifest.matrix_contract.fresh_acceptance_cohort
) "$gateId matrix cardinality or classification changed"
$cellKeys = @(
    "cell_id",
    "cohort",
    "role",
    "campaign_seed",
    "challenge_profile_id",
    "candidate_id",
    "candidate_composition_digest",
    "material_profile_id",
    "measurement_policy_id",
    "terminal_horizon_policy_id",
    "expected_post_sdk_observation_count"
)
for ($index = 0; $index -lt 24; $index += 1) {
    $actual = [System.Collections.IDictionary]$cells[$index]
    $expected = [System.Collections.IDictionary]$expectedCells[$index]
    Assert-ExactKeys -Map $actual -Keys $cellKeys -Context (
        "$gateId cell $index"
    )
    foreach ($key in $cellKeys) {
        Assert-Exact (
            [string]$actual[$key] -ceq [string]$expected[$key]
        ) "$gateId cell $index field changed: $key"
    }
}
Assert-Exact (
    @($cells | Group-Object cell_id | Where-Object Count -ne 1).Count -eq 0
) "$gateId cell identities are missing or duplicated"
foreach ($profile in $profiles) {
    foreach ($seed in $seeds) {
        $pair = @($cells | Where-Object {
            [string]$_.challenge_profile_id -ceq $profile.id -and
            [int]$_.campaign_seed -eq $seed
        })
        Assert-Exact (
            $pair.Count -eq 2 -and
            (Test-SequenceEqual `
                -Actual @($pair.candidate_id) `
                -Expected @("BW30N-A", "BW30N-B")) -and
            @($pair | Where-Object {
                [int]$_.expected_post_sdk_observation_count -ne 1514
            }).Count -eq 0
        ) "$gateId paired cell changed: $($profile.id) seed $seed"
    }
}

Assert-Exact (
    [string]$preregistration.final_receipt_contract.schema_version -ceq
        "sporespore_balanced_wave_bw30n_recovery_raw_cell_v1" -and
    [bool]$preregistration.final_receipt_contract.one_shared_composer_for_both_real_workers -and
    [bool]$preregistration.final_receipt_contract.exact_key_set_required -and
    [string]$preregistration.final_receipt_contract.material_profile_field_name -ceq
        "material_profile_sha256" -and
    [bool]$preregistration.final_receipt_contract.legacy_material_profile_digest_alias_forbidden -and
    [bool]$preregistration.final_receipt_contract.real_reference_receipt_must_pass_frozen_evaluator_before_world -and
    [bool]$preregistration.final_receipt_contract.real_successor_receipt_must_pass_frozen_evaluator_before_world -and
    [bool]$preregistration.final_receipt_contract.real_shaped_walking_negative_receipt_must_pass_integrity_before_world -and
    [bool]$preregistration.final_receipt_contract.missing_field_extra_field_and_candidate_specific_field_name_canaries_required -and
    [bool]$preregistration.final_receipt_contract.synthetic_only_receipt_parity_is_insufficient
) "$gateId shared final-receipt contract changed"
Assert-Exact (
    [bool]$preregistration.gate_contract.walking_failure_may_be_a_complete_valid_cell -and
    -not [bool]$preregistration.gate_contract.sensor_latency_in_scope -and
    -not [bool]$preregistration.gate_contract.combined_nuisance_in_scope -and
    [string]$preregistration.selection_contract.eligible_candidate_id -ceq
        "BW30N-B" -and
    [string]$preregistration.selection_contract.reference_candidate_id -ceq
        "BW30N-A" -and
    [bool]$preregistration.selection_contract.strict_total_improvement_required -and
    [bool]$preregistration.selection_contract.per_axis_non_regression_required -and
    [string]$preregistration.selection_contract.neutral_or_tied_result_selects -ceq
        "NONE" -and
    [string]$preregistration.selection_contract.incomplete_or_integrity_invalid_result_selects -ceq
        "NONE" -and
    [bool]$preregistration.selection_contract.fresh_nuisance_validation_ready_requires_bw30n_b_twelve_of_twelve -and
    -not [bool]$preregistration.selection_contract.selection_grants_release_authority -and
    -not [bool]$preregistration.selection_contract.selection_grants_nuisance_acceptance
) "$gateId gate or selector contract changed"

$reservedSeeds = @(
    $preregistration.pipeline_stages.stage_2_independent_nuisance_validation.reserved_unopened_seed_ids
)
Assert-Exact (
    (Test-SequenceEqual `
        -Actual $reservedSeeds `
        -Expected @(49101, 49102, 49103)) -and
    (Test-SequenceEqual `
        -Actual @($manifest.reserved_fresh_validation_seeds) `
        -Expected @(49101, 49102, 49103)) -and
    [bool]$manifest.reserved_fresh_seeds_are_not_part_of_bw30n -and
    -not [bool]$preregistration.pipeline_stages.stage_2_independent_nuisance_validation.reserved_seed_use_authorized_at_stage_zero
) "$gateId reserved fresh-seed boundary changed"
foreach ($seed in $reservedSeeds) {
    $pattern = '"campaign_seed"\s*:\s*' + [string]$seed + '(?:\D|$)'
    $hits = @(& rg `
        --files-with-matches `
        -g "*.json" `
        -- $pattern $repoRoot $evidenceRoot 2>$null)
    Assert-Exact (
        $LASTEXITCODE -eq 1 -and $hits.Count -eq 0
    ) "$gateId reserved validation seed has already been opened: $seed"
}

$bw30nAttempts = @(
    Get-ChildItem `
        -LiteralPath $evidenceRoot `
        -Filter "attempt.json" `
        -File `
        -Recurse | Where-Object {
            try {
                $attempt = Get-Content -Raw -LiteralPath $_.FullName |
                    ConvertFrom-Json -AsHashtable -Depth 100
                [string]$attempt.campaign_id -ceq $campaignId
            } catch { $false }
        }
)
Assert-Exact ($bw30nAttempts.Count -eq 0) (
    "$gateId already has a retained physical attempt"
)
Assert-Exact (
    -not [bool]$manifest.physical_execution_authorized -and
    -not [bool]$manifest.independent_validation_authority -and
    -not [bool]$manifest.release_gate_promotion_authority -and
    -not [bool]$manifest.physical_acceptance_authority -and
    [int]$manifest.preflight_contract.world_build_count -eq 0 -and
    [bool]$manifest.preflight_contract.common_fixed_horizon_verified -and
    [bool]$manifest.preflight_contract.shared_final_receipt_contract_declared -and
    [bool]$preregistration.staged_interlocks.physical_execution_blocked_at_stage_zero -and
    [bool]$preregistration.staged_interlocks.physical_run_requires_distinct_complete_stage_one_freeze -and
    [bool]$preregistration.staged_interlocks.stage_two_reserved_seeds_may_not_be_opened_by_stage_one -and
    [bool]$preregistration.staged_interlocks.stage_one_may_not_update_qsdk_r09_r10_r11_r12_or_r13
) "$gateId stage-zero interlock changed"

foreach ($claim in $preregistration.claims_before_and_after_development.Keys) {
    Assert-Exact (
        -not [bool]$preregistration.claims_before_and_after_development[$claim]
    ) "$gateId preregistration claim became true: $claim"
}
foreach ($entry in $candidates.claim_boundary.GetEnumerator()) {
    if ([string]$entry.Key -ceq "development_only") {
        Assert-Exact ([bool]$entry.Value) (
            "$gateId candidates must remain development-only"
        )
    } elseif ($entry.Value -is [bool]) {
        Assert-Exact (-not [bool]$entry.Value) (
            "$gateId candidate claim became true: $($entry.Key)"
        )
    }
}

Write-Host (
    "BW30N_DECLARATION_PASS cells=24 candidates=2 profiles=4 " +
    "exposed_seeds=3 horizon=1514 receipt_schema=shared " +
    "material_field=material_profile_sha256 reserved_fresh_seeds=3 " +
    "attempts=0 worlds=0 selection_authority=False " +
    "nuisance_authority=False physical_authority=False"
)
