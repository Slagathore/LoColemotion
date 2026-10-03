#requires -Version 7.0

[CmdletBinding()]
param(
    [string]$Godot = (
        "C:\Users\Cole\CodeStuff\Misc\Godot\" +
        "Godot_v4.7-stable_mono_win64_console.exe"
    ),
    [switch]$SkipSupervisorPreflight
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [System.IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$freezePath = Join-Path $repoRoot "sdk\balanced_wave_bw31n_authority_horizon_freeze.json"
$preregistrationPath = Join-Path $repoRoot "sdk\balanced_wave_bw31n_authority_horizon_preregistration.json"
$manifestPath = Join-Path $repoRoot "sdk\balanced_wave_bw31n_authority_horizon_manifest.json"
$horizonPath = Join-Path $repoRoot "sdk\balanced_wave_bw31n_candidate_authority_exposure_horizon.json"
$evaluatorPath = Join-Path $repoRoot "sdk\balanced_wave_bw31n_authority_horizon_gate.ps1"
$supervisorPath = Join-Path $repoRoot "sdk\run_balanced_wave_bw31n_authority_horizon.ps1"
$zeroWorldGatePath = Join-Path $repoRoot "sdk\run_balanced_wave_bw31n_authority_horizon_zero_world_gate.ps1"
$declarationAuditPath = Join-Path $repoRoot "tests\test_bw31n_authority_horizon_declaration.ps1"

function Assert-Bw31nFreezeExact {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function Get-Bw31nFreezeRawSha256 {
    param([Parameter(Mandatory)][string]$Path)
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

Assert-Bw31nFreezeExact (Test-Path -LiteralPath $freezePath -PathType Leaf) (
    "BW31N stage-one freeze is missing"
)
$freeze = Get-Content -Raw -LiteralPath $freezePath |
    ConvertFrom-Json -AsHashtable -Depth 64
$study = [System.Collections.IDictionary]$freeze["study_class"]
$matrix = [System.Collections.IDictionary]$freeze["physical_matrix"]
$measurement = [System.Collections.IDictionary]$freeze["measurement_contract"]
$horizon = [System.Collections.IDictionary]$freeze["candidate_authority_horizon_contract"]
$receipt = [System.Collections.IDictionary]$freeze["final_receipt_contract"]
$gate = [System.Collections.IDictionary]$freeze["gate_contract"]
$preflight = [System.Collections.IDictionary]$freeze["zero_world_authorization_preflight"]
$execution = [System.Collections.IDictionary]$freeze["one_shot_execution_contract"]

Assert-Bw31nFreezeExact (
    [string]$freeze["schema_version"] -ceq
        "sporespore_balanced_wave_bw31n_authority_horizon_freeze_v1" -and
    [string]$freeze["status"] -ceq "frozen_before_first_bw31n_physical_world" -and
    [string]$freeze["campaign_id"] -ceq
        "BW31N-BW30N-AUTHORITY-HORIZON-RECOVERY-DEVELOPMENT" -and
    [string]$freeze["gate_id"] -ceq "BW31N" -and
    [string]$freeze["freeze_parent_commit"] -ceq
        "fe33a452d6f134e6579f5de40b410c1db5a1778c" -and
    -not [bool]$freeze["physical_execution_authorized_by_freeze"]
) "BW31N freeze identity or authority changed"

Assert-Bw31nFreezeExact (
    [string]$study["classification"] -ceq
        "paired_outcome_exposed_exact_finite_candidate_authority_horizon_recovery_development_screen" -and
    [bool]$study["scientifically_distinct_from_bw29n_and_bw30n"] -and
    [bool]$study["bw29n_and_bw30n_remain_immutable_implementation_invalid"] -and
    [int]$study["candidate_count"] -eq 2 -and
    [string]$study["reference_candidate_id"] -ceq "BW31N-A" -and
    [string]$study["successor_candidate_id"] -ceq "BW31N-B" -and
    [bool]$study["development_screen"] -and
    -not [bool]$study["finite_acceptance_decision"] -and
    -not [bool]$study["population_inference"] -and
    -not [bool]$study["causal_component_attribution"] -and
    [bool]$study["fresh_independent_validation_required_after_non_none_selection"]
) "BW31N frozen study class changed"

Assert-Bw31nFreezeExact (
    (@($matrix["challenge_profile_ids"]) -join "|") -ceq
        "bw6n_baseline_v1|bw6n_rough_v1|bw6n_push_v1|bw6n_sensor_noise_v1" -and
    (@($matrix["campaign_seeds"]) -join "|") -ceq "21001|21002|21003" -and
    [int]$matrix["worlds_per_candidate"] -eq 12 -and
    [int]$matrix["expected_world_count"] -eq 24 -and
    [int]$matrix["physical_world_count_at_freeze"] -eq 0 -and
    [int]$matrix["selector_invocation_count_at_freeze"] -eq 0 -and
    [int]$matrix["candidate_outcome_count_at_freeze"] -eq 0 -and
    [bool]$matrix["all_cells_outcome_exposed_when_executed"] -and
    [bool]$matrix["first_complete_result_final_for_source_identity"] -and
    (@($matrix["reserved_fresh_independent_validation_seeds"]) -join "|") -ceq
        "49101|49102|49103" -and
    [bool]$matrix["reserved_fresh_seeds_are_not_part_of_bw31n"]
) "BW31N frozen physical matrix changed"

Assert-Bw31nFreezeExact (
    [string]$measurement["policy_id"] -ceq "bounded_all_support_acquisition_v1" -and
    [string]$measurement["configuration_sha256"] -ceq
        "sha256:4a49770e35b67b2186a5a64ad3dcbf7d1d637e9ffc6ea2a9365615731eb2e748" -and
    [int]$measurement["maximum_acquisition_ticks"] -eq 15 -and
    [int]$measurement["minimum_all_support_dwell_ticks"] -eq 3 -and
    -not [bool]$measurement["controller_parameter"] -and
    -not [bool]$measurement["walking_claim_authorized"] -and
    -not [bool]$measurement["may_extend_candidate_authority_horizon"]
) "BW31N common evidence-acquisition policy changed"

Assert-Bw31nFreezeExact (
    [string]$horizon["policy_id"] -ceq "fixed_candidate_authority_exposure_horizon_v1" -and
    [string]$horizon["policy_sha256"] -ceq
        "sha256:f074fe4004d085c4d763f0b01009c011b91af339fbaf45e42256daa91e2e09ab" -and
    [int]$horizon["exact_candidate_authority_observation_count"] -eq 3232 -and
    [int]$horizon["first_candidate_authority_observation_index"] -eq 0 -and
    [int]$horizon["last_candidate_authority_observation_index"] -eq 3231 -and
    [int]$horizon["reference_pre_authority_world_tick_count"] -eq 712 -and
    [int]$horizon["successor_pre_authority_world_tick_count"] -eq 240 -and
    [int]$horizon["expected_native_motor_write_count_per_world"] -eq 25856 -and
    [int]$horizon["candidate_specific_horizon_extension_count"] -eq 0 -and
    -not [bool]$horizon["pre_authority_world_ticks_count_toward_exposure"] -and
    -not [bool]$horizon["contact_gated_progression_may_extend_horizon"] -and
    -not [bool]$horizon["evidence_acquisition_may_extend_horizon"] -and
    [bool]$horizon["walking_negative_at_exact_horizon_is_complete"]
) "BW31N candidate-authority horizon changed"

Assert-Bw31nFreezeExact (
    [string]$receipt["schema_version"] -ceq
        "sporespore_balanced_wave_bw31n_authority_horizon_raw_cell_v1" -and
    [string]$receipt["composer_id"] -ceq "bw31n_shared_final_receipt_composer_v1" -and
    [bool]$receipt["one_shared_composer_for_both_real_workers"] -and
    [bool]$receipt["exact_key_set_required"] -and
    [string]$receipt["pre_authority_field_name"] -ceq "pre_authority_world_tick_count" -and
    [bool]$receipt["real_shaped_walking_negative_receipts_are_complete"] -and
    [bool]$receipt["synthetic_only_parity_is_insufficient"]
) "BW31N shared receipt contract changed"

Assert-Bw31nFreezeExact (
    [int]$gate["expected_gate_count"] -eq 15 -and
    [bool]$gate["shared_final_receipt_exact_key_set_required"] -and
    [bool]$gate["fixed_candidate_authority_horizon_required"] -and
    [bool]$gate["route_specific_pre_authority_exclusion_required"] -and
    [bool]$gate["walking_negative_cell_is_complete_when_integrity_passes"] -and
    [bool]$gate["successor_requires_strictly_fewer_total_walking_failures"] -and
    [bool]$gate["successor_requires_zero_paired_axis_regressions"] -and
    [bool]$gate["tie_or_no_eligible_improvement_selects_none"] -and
    [bool]$gate["valid_none_is_a_complete_development_result"] -and
    [bool]$gate["outcome_based_early_stop_forbidden"] -and
    [bool]$gate["outcome_based_retry_or_replacement_forbidden"] -and
    [bool]$gate["post_result_gate_edit_forbidden"]
) "BW31N frozen evaluator or negative-result contract changed"

Assert-Bw31nFreezeExact (
    [int]$preflight["production_gate_count"] -eq 15 -and
    [int]$preflight["production_evaluator_negative_canary_count"] -eq 14 -and
    [int]$preflight["attempt_record_canary_count"] -eq 6 -and
    [int]$preflight["authorization_and_bypass_canary_count"] -eq 2 -and
    [int]$preflight["worker_entrypoint_count"] -eq 24 -and
    [int]$preflight["successor_adapter_start_count"] -eq 12 -and
    [int]$preflight["valid_authorization_preflight_count"] -eq 2 -and
    [int]$preflight["real_shaped_receipt_count"] -eq 24 -and
    [int]$preflight["real_shaped_walking_negative_count"] -eq 2 -and
    [bool]$preflight["shared_final_receipt_composer_passed"] -and
    [bool]$preflight["candidate_authority_horizon_passed"] -and
    [bool]$preflight["pre_authority_exclusion_passed"] -and
    [int]$preflight["world_build_count"] -eq 0 -and
    [int]$preflight["scene_tree_insertion_count"] -eq 0 -and
    [int]$preflight["physics_state_mutation_count"] -eq 0 -and
    -not [bool]$preflight["locomotion_outcome_exposed"] -and
    -not [bool]$preflight["physical_acceptance_authority"]
) "BW31N declared zero-world authorization preflight changed"

Assert-Bw31nFreezeExact (
    [string]$execution["only_authorized_entrypoint"] -ceq
        "sdk/run_balanced_wave_bw31n_authority_horizon.ps1 -RunPhysical -OutputRoot <new durable evidence root> -FullConformanceAttestation <exact V2 attestation>" -and
    [bool]$execution["only_complete_supervisor_may_open_physical_worlds"] -and
    [bool]$execution["worker_requires_exact_retained_attempt_and_matching_authorization_token"] -and
    [bool]$execution["output_root_must_be_new_durable_and_inside_sporespore_evidence"] -and
    [bool]$execution["head_must_equal_origin_main_and_live_github_main"] -and
    [bool]$execution["worktree_must_be_clean"] -and
    [bool]$execution["prior_attempt_count_must_be_zero"] -and
    [bool]$execution["attempt_receipt_written_and_identity_consumed_before_first_world"] -and
    [bool]$execution["attempt_receipt_remains_immutable_after_first_world"] -and
    [bool]$execution["each_world_runs_in_a_fresh_isolated_process"] -and
    [bool]$execution["all_twenty_four_cells_attempted_even_after_cell_failure"] -and
    [bool]$execution["valid_walking_negative_cell_is_final_and_does_not_fail_process"] -and
    [bool]$execution["no_cell_retry_or_replacement_allowed"] -and
    [bool]$execution["first_complete_result_final_for_source_identity"] -and
    -not [bool]$execution["same_identity_rerun_allowed"] -and
    [bool]$execution["physical_execution_requires_new_clean_pushed_full_conformance"]
) "BW31N frozen one-shot execution contract changed"

foreach ($claimSetName in @(
    "claims_before_physical_execution",
    "claim_ceiling_after_valid_complete_development_result"
)) {
    $claimSet = [System.Collections.IDictionary]$freeze[$claimSetName]
    foreach ($entry in $claimSet.GetEnumerator()) {
        if (
            $claimSetName -ceq "claim_ceiling_after_valid_complete_development_result" -and
            [string]$entry.Key -in @(
                "exact_finite_development_result_complete",
                "development_hypothesis_selected_only_if_selector_returns_non_none"
            )
        ) {
            Assert-Bw31nFreezeExact ([bool]$entry.Value) (
                "BW31N valid-development ceiling lost: $($entry.Key)"
            )
            continue
        }
        Assert-Bw31nFreezeExact (-not [bool]$entry.Value) (
            "BW31N claim inflated in ${claimSetName}: $($entry.Key)"
        )
    }
}

$bindings = [System.Collections.IDictionary]$freeze["source_bindings"]
Assert-Bw31nFreezeExact ($bindings.Count -ge 25) "BW31N source binding surface is incomplete"
foreach ($entry in $bindings.GetEnumerator()) {
    $binding = [System.Collections.IDictionary]$entry.Value
    $relativePath = [string]$binding["path"]
    $expectedHash = [string]$binding["raw_sha256"]
    $absolutePath = Join-Path $repoRoot $relativePath
    Assert-Bw31nFreezeExact (
        $expectedHash -cmatch "^[0-9a-f]{64}$" -and
        (Test-Path -LiteralPath $absolutePath -PathType Leaf) -and
        (Get-Bw31nFreezeRawSha256 $absolutePath) -ceq $expectedHash
    ) "BW31N frozen source is missing or changed: $relativePath"
}

& pwsh -NoLogo -NoProfile -File $declarationAuditPath
Assert-Bw31nFreezeExact ($LASTEXITCODE -eq 0) "BW31N stage-zero declaration audit failed"

$preregistration = Get-Content -Raw -LiteralPath $preregistrationPath |
    ConvertFrom-Json -AsHashtable -Depth 64
$manifest = Get-Content -Raw -LiteralPath $manifestPath |
    ConvertFrom-Json -AsHashtable -Depth 64
$declaredHorizon = Get-Content -Raw -LiteralPath $horizonPath |
    ConvertFrom-Json -AsHashtable -Depth 64
$cells = @($manifest["ordered_cells"])
Assert-Bw31nFreezeExact (
    [string]$preregistration["campaign_id"] -ceq
        "BW31N-BW30N-AUTHORITY-HORIZON-RECOVERY-DEVELOPMENT" -and
    [string]$manifest["campaign_id"] -ceq
        "BW31N-BW30N-AUTHORITY-HORIZON-RECOVERY-DEVELOPMENT" -and
    [int]$declaredHorizon["exact_candidate_authority_observation_count"] -eq 3232 -and
    $cells.Count -eq 24 -and
    @($cells | Where-Object { [string]$_["candidate_id"] -ceq "BW31N-A" }).Count -eq 12 -and
    @($cells | Where-Object { [string]$_["candidate_id"] -ceq "BW31N-B" }).Count -eq 12 -and
    @($cells | Where-Object { [int]$_["campaign_seed"] -notin @(21001, 21002, 21003) }).Count -eq 0 -and
    -not [bool]$manifest["physical_execution_authorized"]
) "BW31N declarations no longer match the frozen 24-cell matrix"

. $evaluatorPath
$perfect = @(New-Bw31nPerfectSyntheticReceiptSet)
$perfectEvaluation = Invoke-Bw31nRecoveryEvaluation -CellReceipts $perfect
$perfect[0]["walking_observed"] = $false
$negativeEvaluation = Invoke-Bw31nRecoveryEvaluation -CellReceipts $perfect
$preAuthorityMutation = @(New-Bw31nPerfectSyntheticReceiptSet)
$preAuthorityMutation[0]["pre_authority_world_tick_count"] = 713
$preAuthorityEvaluation = Invoke-Bw31nRecoveryEvaluation -CellReceipts $preAuthorityMutation
Assert-Bw31nFreezeExact (
    [bool]$perfectEvaluation["ok"] -and
    [int]$perfectEvaluation["passed_gate_count"] -eq 15 -and
    [string]$perfectEvaluation["selected_candidate_id"] -ceq "NONE" -and
    [bool]$negativeEvaluation["ok"] -and
    [int]$negativeEvaluation["passed_gate_count"] -eq 15 -and
    [string]$negativeEvaluation["selected_candidate_id"] -ceq "BW31N-B" -and
    [bool]$negativeEvaluation["fresh_nuisance_validation_ready"] -and
    -not [bool]$preAuthorityEvaluation["ok"] -and
    "BW31N_PRE_AUTHORITY_INVALID" -cin @($preAuthorityEvaluation["failure_codes"])
) "BW31N frozen evaluator controls changed"

foreach ($path in @($supervisorPath, $zeroWorldGatePath, $evaluatorPath)) {
    $tokens = $null
    $parseErrors = $null
    [void][System.Management.Automation.Language.Parser]::ParseFile(
        $path,
        [ref]$tokens,
        [ref]$parseErrors
    )
    Assert-Bw31nFreezeExact ($parseErrors.Count -eq 0) (
        "BW31N PowerShell source no longer parses: $path"
    )
}

$supervisorSource = Get-Content -Raw -LiteralPath $supervisorPath
foreach ($marker in @(
    "New-Bw31nAttemptRecord",
    "Test-Bw31nAttemptRecord",
    "BW31N-P1::",
    "source_matches_live_github_main",
    "Test-SporeSporeFullConformanceAttestationFile",
    "real_shaped_receipt_preflight_passed",
    "candidate_authority_horizon_preflight_passed",
    "already has a retained attempt and may not rerun",
    "foreach (`$cell in `$cells)",
    "first physical attempt was retained as invalid/incomplete"
)) {
    Assert-Bw31nFreezeExact (
        $supervisorSource.Contains($marker, [StringComparison]::Ordinal)
    ) "BW31N supervisor contract marker is missing: $marker"
}

if (-not $SkipSupervisorPreflight) {
    & pwsh -NoLogo -NoProfile -File $supervisorPath -PreflightOnly -Godot $Godot
    Assert-Bw31nFreezeExact ($LASTEXITCODE -eq 0) (
        "BW31N actual supervisor preflight failed"
    )
}

Write-Host (
    "BW31N_STAGE_ONE_FREEZE_PASS worlds=0 cells=24 gates=15 authority_horizon=3232 " +
    "native_motor_writes=25856 reference_pre_authority=712 successor_pre_authority=240 " +
    "source_bindings=$($bindings.Count) evaluator_canaries=14 attempt_canaries=6 " +
    "authorization_canaries=2 real_shaped_receipts=24 shared_composer=True " +
    "walking_negative_complete=True outcomes_exposed=False physical_authority=False " +
    "freeze_sha256=$(Get-Bw31nFreezeRawSha256 $freezePath)"
)
