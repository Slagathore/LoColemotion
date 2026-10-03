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
$campaignId = "BW31N-BW30N-AUTHORITY-HORIZON-RECOVERY-DEVELOPMENT"
$gateId = "BW31N"
$implementationParent = "11ad16d84cf22a1933aec078be838c032fce8090"
$preregistrationPath = Join-Path $sdkRoot (
    "balanced_wave_bw31n_authority_horizon_preregistration.json"
)
$candidatesPath = Join-Path $sdkRoot (
    "balanced_wave_bw31n_authority_horizon_candidates.json"
)
$manifestPath = Join-Path $sdkRoot (
    "balanced_wave_bw31n_authority_horizon_manifest.json"
)
$horizonPath = Join-Path $sdkRoot (
    "balanced_wave_bw31n_candidate_authority_exposure_horizon.json"
)
$bw30nClosurePath = Join-Path $sdkRoot "balanced_wave_bw30n_recovery_closure.json"
$bw6nManifestPath = Join-Path $sdkRoot "balanced_wave_bw6n_validation_manifest.json"

$expectedHashes = [ordered]@{
    preregistration = "ccf11c8b2c9c23580fbfdec88131f84306eeb8da73afef3a1630103c146bcf3e"
    candidates = "12b9f5d818a9dbe89f96d51f04fcc1b2a6b5648206ee8ebb13ed3411ec9aabfb"
    manifest = "f5c1b72ceeae3664b6798cf717d3c039906d362f798c6e4466686c706c15bfc3"
    horizon = "f074fe4004d085c4d763f0b01009c011b91af339fbaf45e42256daa91e2e09ab"
    bw30n_closure = "6d5a8a2e8d76fddb95b48a8554fcc1135c5a93199a3978c095a2e1960747d9df"
    bw6n_manifest = "83886d8c893a4a6e5a960b06b3398d907a203a865e1ac66ed1870ea09dc3d38e"
}
$candidateBaseDigests = [ordered]@{
    "BW31N-A" = "sha256:794b42e64e1a89f371b0113ad1c3cf14c0a3d87abfed876323eda9e4aaeed1e6"
    "BW31N-B" = "sha256:3490c1934bb018ef68a54b5d5415c7d19dddf7696ee0ac7fca4ab27951957e4d"
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
    $bw30nClosurePath,
    $bw6nManifestPath
)) {
    Assert-Exact (Test-Path -LiteralPath $requiredPath -PathType Leaf) (
        "Missing BW31N declaration authority: $requiredPath"
    )
}

Assert-Exact ((Get-RawSha256 $preregistrationPath) -ceq $expectedHashes.preregistration) (
    "BW31N preregistration raw hash changed"
)
Assert-Exact ((Get-RawSha256 $candidatesPath) -ceq $expectedHashes.candidates) (
    "BW31N candidate declaration raw hash changed"
)
Assert-Exact ((Get-RawSha256 $manifestPath) -ceq $expectedHashes.manifest) (
    "BW31N manifest raw hash changed"
)
Assert-Exact ((Get-RawSha256 $horizonPath) -ceq $expectedHashes.horizon) (
    "BW31N authority-horizon raw hash changed"
)
Assert-Exact ((Get-RawSha256 $bw30nClosurePath) -ceq $expectedHashes.bw30n_closure) (
    "BW30N immutable closure changed"
)
Assert-Exact ((Get-RawSha256 $bw6nManifestPath) -ceq $expectedHashes.bw6n_manifest) (
    "BW6N frozen challenge manifest changed"
)

$preregistration = Read-JsonMap $preregistrationPath
$candidates = Read-JsonMap $candidatesPath
$manifest = Read-JsonMap $manifestPath
$horizon = Read-JsonMap $horizonPath
$bw30nClosure = Read-JsonMap $bw30nClosurePath

foreach ($authority in @($preregistration, $candidates, $manifest, $horizon)) {
    Assert-Exact ([string]$authority.campaign_id -ceq $campaignId) (
        "BW31N campaign identity changed"
    )
    Assert-Exact ([string]$authority.gate_id -ceq $gateId) (
        "BW31N gate identity changed"
    )
    Assert-Exact ([string]$authority.implementation_parent_commit -ceq $implementationParent) (
        "BW31N implementation parent changed"
    )
}

Assert-Exact (
    [string]$preregistration.source_bindings.candidate_declarations.raw_sha256 -ceq (
        $expectedHashes.candidates
    ) -and
    [string]$preregistration.source_bindings.candidate_authority_exposure_horizon.raw_sha256 -ceq (
        $expectedHashes.horizon
    ) -and
    [string]$preregistration.source_bindings.bw30n_immutable_invalid_closure.raw_sha256 -ceq (
        $expectedHashes.bw30n_closure
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
    [string]$manifest.source_bindings.bw30n_immutable_invalid_closure.raw_sha256 -ceq (
        $expectedHashes.bw30n_closure
    ) -and
    [string]$manifest.source_bindings.bw6n_frozen_challenge_manifest.raw_sha256 -ceq (
        $expectedHashes.bw6n_manifest
    )
) "BW31N stage-zero source binding changed"

Assert-Exact (
    [string]$bw30nClosure.status -ceq (
        "closed_implementation_invalid_after_complete_physical_matrix_and_frozen_evaluation"
    ) -and
    [string]$bw30nClosure.campaign_id -ceq (
        "BW30N-BW29N-IMPLEMENTATION-RECOVERY-DEVELOPMENT"
    ) -and
    [string]$bw30nClosure.gate_id -ceq "BW30N" -and
    -not [bool]$bw30nClosure.same_identity_rerun_allowed -and
    [bool]$bw30nClosure.successor_requirements.fixed_horizon_must_be_anchored_to_exact_candidate_authority_exposure -and
    [bool]$bw30nClosure.successor_requirements.pre_authority_support_acquisition_must_not_consume_candidate_exposure_budget -and
    [bool]$bw30nClosure.successor_requirements.challenge_application_count_must_be_exact_and_candidate_independent -and
    [bool]$bw30nClosure.successor_requirements.horizon_must_be_long_enough_for_the_frozen_every_limb_evidence_schedule_without_posthoc_extension
) "BW31N no longer binds the complete immutable BW30N successor requirements"

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
        "sporespore_balanced_wave_bw31n_candidate_authority_exposure_horizon_v1"
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
    -not [bool]$horizon.derivation.uses_bw29n_or_bw30n_candidate_failure_counts_to_set_horizon -and
    [int]$horizon.challenge_contract.push_step_from_candidate_authority_start -eq 540 -and
    [int]$horizon.challenge_contract.sensor_noise_observation_fault_application_count -eq 3232 -and
    [int]$horizon.challenge_contract.sensor_noise_base_and_stability_fault_count -eq 3232 -and
    [bool]$horizon.challenge_contract.challenge_application_count_is_candidate_independent -and
    [int]$horizon.world_build_count -eq 0 -and
    -not [bool]$horizon.physical_execution_authorized
) "BW31N schedule-derived candidate-authority horizon changed"

$candidateOrder = @($candidates.candidate_order)
Assert-Exact (Test-SequenceEqual $candidateOrder @("BW31N-A", "BW31N-B")) (
    "BW31N candidate order changed"
)
Assert-Exact (@($candidates.candidates).Count -eq 2) "BW31N candidate count changed"
foreach ($candidateId in $candidateOrder) {
    $candidate = @($candidates.candidates | Where-Object {
        [string]$_.candidate_id -ceq [string]$candidateId
    })
    Assert-Exact ($candidate.Count -eq 1) "BW31N candidate declaration missing or duplicated"
    $candidate = $candidate[0]
    Assert-Exact (
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
        [bool]$candidate.scientifically_distinct_successor_composition -and
        -not [bool]$candidate.physical_acceptance_authority
    ) "BW31N candidate authority contract changed for $candidateId"
    foreach ($countName in @(
        "morphology_condition_count",
        "material_condition_count",
        "seed_condition_count",
        "challenge_condition_count",
        "failure_identity_condition_count",
        "outcome_condition_count"
    )) {
        Assert-Exact ([int]$candidate[$countName] -eq 0) (
            "BW31N candidate conditions are not branch-free for $candidateId/$countName"
        )
    }
    Assert-Exact (@($candidate.branch_surfaces).Count -eq 0) (
        "BW31N candidate branch surfaces changed for $candidateId"
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
Assert-Exact ($cells.Count -eq 24) "BW31N manifest must contain exactly 24 cells"
$ordinal = 0
$seen = @{}
foreach ($profile in $expectedProfiles) {
    $prefix = if ($profile -ceq "bw6n_sensor_noise_v1") {
        "sensor_noise"
    } else { ($profile -replace '^bw6n_', '' -replace '_v1$', '') }
    foreach ($seed in $expectedSeeds) {
        foreach ($candidateId in $candidateOrder) {
            $cell = $cells[$ordinal]
            $suffix = if ($candidateId -ceq "BW31N-A") { "a" } else { "b" }
            $expectedCellId = "${prefix}_s${seed}_bw31n_${suffix}"
            Assert-Exact (
                [string]$cell.cell_id -ceq $expectedCellId -and
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
            ) "BW31N ordered cell changed at ordinal $ordinal"
            Assert-Exact (-not $seen.ContainsKey($expectedCellId)) (
                "BW31N cell identity duplicated: $expectedCellId"
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
) "BW31N matrix contract changed"

$reservedSeeds = @(49101, 49102, 49103)
Assert-Exact (
    (Test-SequenceEqual @($manifest.reserved_fresh_validation_seeds) $reservedSeeds) -and
    (Test-SequenceEqual @(
        $preregistration.pipeline_stages.stage_2_independent_nuisance_validation.reserved_unopened_seed_ids
    ) $reservedSeeds) -and
    [bool]$manifest.reserved_fresh_seeds_are_not_part_of_bw31n -and
    -not [bool]$preregistration.pipeline_stages.stage_2_independent_nuisance_validation.reserved_seed_use_authorized_at_stage_zero
) "BW31N fresh validation seed boundary changed"
foreach ($cell in $cells) {
    Assert-Exact ($reservedSeeds -notcontains [int]$cell.campaign_seed) (
        "BW31N stage one illegally includes a fresh reserved seed"
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
            "BW31N declaration inflated claim: $claimName"
        )
    }
}
Assert-Exact (
    [int]$preregistration.pipeline_stages.stage_0_declaration.world_build_count -eq 0 -and
    -not [bool]$preregistration.pipeline_stages.stage_0_declaration.physical_execution_authorized -and
    [bool]$preregistration.staged_interlocks.physical_execution_blocked_at_stage_zero -and
    [bool]$preregistration.staged_interlocks.physical_run_requires_distinct_complete_stage_one_freeze -and
    -not [bool]$manifest.physical_execution_authorized -and
    -not [bool]$manifest.independent_validation_authority -and
    -not [bool]$manifest.release_gate_promotion_authority -and
    -not [bool]$manifest.physical_acceptance_authority
) "BW31N stage-zero physical interlock changed"

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
    "BW31N already has a retained physical attempt; declaration-only state is false"
)

Write-Host (
    "BW31N_DECLARATION_PASS cells=24 candidates=2 profiles=4 exposed_seeds=3 " +
    "authority_horizon=3232 pre_authority_excluded=True derived_schedule=True " +
    "reserved_fresh_seeds=3 attempts=0 worlds=0 selection_authority=False " +
    "nuisance_authority=False physical_authority=False"
)
