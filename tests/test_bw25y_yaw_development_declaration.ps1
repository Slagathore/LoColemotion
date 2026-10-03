#requires -Version 7.0

[CmdletBinding()]
param(
    [string]$Godot = (
        "C:\Users\Cole\CodeStuff\Misc\Godot\" +
        "Godot_v4.7-stable_mono_win64_console.exe"
    ),
    [switch]$SkipPrerequisiteAudits,
    [switch]$SkipGodotPreflight
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [System.IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$implementationParentCommit = "970fcc1a8de69ac833633c68a4696d71e17741dc"
$campaignId = "BW25Y-FRESH-MATERIAL-YAW-DEVELOPMENT"
$preregistrationPath = Join-Path (
    $repoRoot
) "sdk\balanced_wave_bw25y_yaw_development_preregistration.json"
$candidatesPath = Join-Path (
    $repoRoot
) "sdk\balanced_wave_bw25y_yaw_development_candidates.json"
$runnerPath = Join-Path (
    $repoRoot
) "sdk\run_balanced_wave_bw25y_yaw_development_declaration_preflight.ps1"
$gateTestPath = Join-Path (
    $repoRoot
) "tests\test_bw25y_yaw_development_gate.ps1"
$receiptParityTestPath = Join-Path (
    $repoRoot
) "tests\test_bw25y_yaw_development_receipt_parity.ps1"
$evidenceRoot = Join-Path (
    (Split-Path -Parent $repoRoot)
) "SporeSpore_Evidence"

$boundFiles = [ordered]@{
    "sdk/balanced_wave_bw25y_yaw_development_candidates.json" =
        "02e7b3de50e9ca108f0c8e1508c10422361b3be6d5aa3d86e1db67348e0afb50"
    "sdk/balanced_wave_bw25y_yaw_development_preregistration.json" =
        "a102e9e40742fdded2df4c2ec806a1112cf21c2fec1165f9534da59b2153ff39"
    "tests/test_sdk_balanced_wave_bw25y_authority_contract.gd" =
        "33f662174a8dd41b945515eb6a121b90f29c5de48a93fc4a8749dd6135cccf01"
    "sdk/run_balanced_wave_bw25y_yaw_development_declaration_preflight.ps1" =
        "af5ef2aaa7e16986cf4ff84cb956ec905a2dd29fc1777c5e7b8604b840a42481"
    "sdk/balanced_wave_bw25y_yaw_development_gate.ps1" =
        "a4b54b5cea72f9b63fedf192da36d7044067350b16623e724bbd367cc291f230"
    "tests/test_bw25y_yaw_development_gate.ps1" =
        "ee3ca31b0aa2700d5a4aee7c2520d971185ea447a6fcd8885d898bb45fbba632"
    "tests/test_bw25y_yaw_development_receipt_parity.ps1" =
        "76fe611240340a1f13ea3d1f38ddb4bb12a1f9613a068534c5d41ce72cf57f78"
    "sdk/balanced_wave_bw22l_lateral_development_closure.json" =
        "e35a93c19613a302e72800d1be9222970ef127fd0028baf8e7440e620e2929e5"
    "tests/test_bw22l_lateral_development_closure.ps1" =
        "dff11347b823442c141e0fcfaab1adb912fa04c61188188cf75f68d6f1e5ba84"
    "sdk/balanced_wave_bw24p_material_profile_publication_closure.json" =
        "c8a0b9d64740a79562e2f07c85f366921cc585b5429e938a360a3489a1585cfa"
    "tests/test_bw24p_material_profile_publication_closure.ps1" =
        "bf9eea36d58acf8b8cbd5c6812256b3314c91a571f113b07660d523da6bf253d"
    "sdk/core/src/controller.rs" =
        "dff3d0d8f3a4b1690e9052d5abf7117d8727a3b55f1c9bc5d546fd6499714b39"
    "sdk/core/src/runtime.rs" =
        "36b8f16b4e48452b6bf79b34f82fa2e44e19aaa6ad5c559af8bac2fb1ff03868"
    "sdk/run_balanced_wave_bw23y_yaw_gain_development_preflight.ps1" =
        "ba4524ef775e1ffa64b19bdb8ac19899e76c5831b51dbe0b743712681f4a754b"
    "scripts/lab/gait/sdk_godot_jolt_material_profiles.gd" =
        "1f83f1941984506f48782caa3564506ea3e88b5a84d283f740b34585ae72dc8a"
    "tests/test_sdk_godot_jolt_material_profiles.gd" =
        "a1e21cffc556d74077412960fbed5875286c0daf0a03a3b6df8e58c6d283a784"
    "scripts/lab/gait/sdk_policy_relative_execution_integrity.gd" =
        "1d3833fdddd39b348926fe0161ce34bda7f987d80ac94e8223347a7e16eb531e"
    "tests/test_sdk_policy_relative_execution_integrity.gd" =
        "5d9447688e4a58f7960d664839e5e0ff616008f28ada551f9ffc2398a0fbbe8d"
    "tests/test_sdk_balanced_wave_bw22l_policy_receipt_composition.gd" =
        "bcf6d4e68d98de308222c0308180884414f08b3eb68ba5019b839c4fd472a96f"
}

function Assert-Exact {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function Get-RawSha256 {
    param([Parameter(Mandatory)][string]$Path)
    return (
        Get-FileHash -LiteralPath $Path -Algorithm SHA256
    ).Hash.ToLowerInvariant()
}

function Assert-SequenceExact {
    param(
        [Parameter(Mandatory)][object[]]$Actual,
        [Parameter(Mandatory)][object[]]$Expected,
        [Parameter(Mandatory)][string]$Label
    )
    Assert-Exact ($Actual.Count -eq $Expected.Count) "$Label count changed"
    for ($index = 0; $index -lt $Expected.Count; $index += 1) {
        Assert-Exact (
            [string]$Actual[$index] -ceq [string]$Expected[$index]
        ) "$Label order/value changed at index $index"
    }
}

foreach ($entry in $boundFiles.GetEnumerator()) {
    $path = Join-Path $repoRoot $entry.Key
    Assert-Exact (
        (Test-Path -LiteralPath $path -PathType Leaf) -and
        (Get-RawSha256 $path) -ceq [string]$entry.Value
    ) "BW25Y declaration artifact is missing or changed: $($entry.Key)"
}

& git -C $repoRoot merge-base --is-ancestor $implementationParentCommit HEAD
Assert-Exact (
    $LASTEXITCODE -eq 0
) "BW25Y implementation parent is not an ancestor of HEAD"

$preregistration = Get-Content -Raw -LiteralPath $preregistrationPath |
    ConvertFrom-Json -AsHashtable -Depth 100
$candidates = Get-Content -Raw -LiteralPath $candidatesPath |
    ConvertFrom-Json -AsHashtable -Depth 100
$study = $preregistration.study_class
$stages = $preregistration.pipeline_stages
$hostIdentity = $preregistration.host_identity
$provenance = $preregistration.successor_provenance
$policy = $preregistration.policy
$contrast = $preregistration.controlled_contrast
$matrix = $preregistration.matrix
$receipt = $preregistration.receipt_schema_contract
$selector = $preregistration.selection_contract
$preflight = $preregistration.required_stage_one_freeze_contract
$interlocks = $preregistration.staged_interlocks
$recovery = $preregistration.infrastructure_interruption_contract
$claims = $preregistration.claims_before_and_after_development
$cells = @($matrix.ordered_cells)

Assert-Exact (
    [string]$preregistration.schema_version -ceq
        "sporespore_balanced_wave_bw25y_yaw_development_preregistration_v1" -and
    [string]$preregistration.status -ceq
        "prospective_stage_zero_zero_world_only_physical_execution_blocked" -and
    [string]$preregistration.campaign_id -ceq $campaignId -and
    [string]$preregistration.gate_id -ceq "BW25Y" -and
    [string]$preregistration.implementation_parent_commit -ceq
        $implementationParentCommit -and
    [string]$study.classification -ceq
        "paired_outcome_unexposed_finite_controller_development_screen" -and
    [bool]$study.finite_decision -and
    [bool]$study.development_screen -and
    -not [bool]$study.population_inference -and
    -not [bool]$study.superiority_study -and
    -not [bool]$study.noninferiority_or_equivalence_study -and
    [int]$study.expected_world_count -eq 28 -and
    [bool]$study.baseline_may_remain_unreplaced -and
    [bool]$study.development_result_may_validly_select_none -and
    [bool]$study.selected_candidate_requires_distinct_independent_validation
) "BW25Y identity or development-only study class changed"

Assert-Exact (
    [string]$stages.stage_0_declaration_authority_and_real_shaped_gate_preflight.status -ceq
        "prospectively_declared_zero_world_only" -and
    [int]$stages.stage_0_declaration_authority_and_real_shaped_gate_preflight.world_build_count -eq 0 -and
    -not [bool]$stages.stage_0_declaration_authority_and_real_shaped_gate_preflight.locomotion_outcome_exposed -and
    -not [bool]$stages.stage_0_declaration_authority_and_real_shaped_gate_preflight.physical_acceptance_authority -and
    [string]$stages.stage_1_physical_development.status -ceq
        "blocked_until_worker_evaluator_supervisor_and_complete_freeze_are_committed_and_pushed" -and
    [int]$stages.stage_1_physical_development.physical_world_count -eq 28 -and
    [bool]$stages.stage_1_physical_development.may_not_open_from_this_document_alone -and
    [bool]$stages.stage_2_independent_validation.required_for_bounded_material_locomotion_claim
) "BW25Y staged authority boundary changed"

Assert-Exact (
    [string]$hostIdentity.operating_system_family -ceq "windows" -and
    [string]$hostIdentity.godot_version -ceq
        "4.7.stable.mono.official.5b4e0cb0f" -and
    [string]$hostIdentity.godot_launcher_executable_sha256 -ceq
        "c5fc2d0bb24826a6757fa1e6bf2991effb294859c7dd03d09a122ef217484896" -and
    [string]$hostIdentity.godot_runtime_executable_sha256 -ceq
        "baa909d0a905021da80cfc831713e9d3ba4bd0935ac3b93ba4c77dc140cfecc4" -and
    [string]$hostIdentity.adapter_id -ceq "godot_jolt_gdextension_v1" -and
    [string]$hostIdentity.physics_engine -ceq "Jolt Physics" -and
    [string]$hostIdentity.solver_policy_id -ceq "jolt_120hz_20v_7p_v1" -and
    [int]$hostIdentity.physics_hz -eq 120 -and
    [int]$hostIdentity.solver_velocity_steps -eq 20 -and
    [int]$hostIdentity.solver_position_steps -eq 7 -and
    [string]$hostIdentity.material_combine_rule -ceq
        "highest_friction_both_rough_v1"
) "BW25Y host or solver identity changed"

Assert-Exact (
    [string]$provenance.bw22l_disposition -ceq
        "closed_invalid_final_receipt_composition_mismatch" -and
    -not [bool]$provenance.bw22l_was_a_controller_comparison_result -and
    [string]$provenance.bw22l_selected_candidate_id -ceq "NONE" -and
    [string]$provenance.bw22l_posthoc_selector_output -ceq "NONE" -and
    [bool]$provenance.bw22l_b_may_not_be_promoted_or_retested -and
    [bool]$provenance.bw22l_descriptive_observations_used_for_hypothesis_narrowing_only -and
    [bool]$provenance.bw23y_development_worlds_were_nonretained_and_outcome_exposed -and
    -not [bool]$provenance.bw23y_selected -and
    -not [bool]$provenance.bw23y_promoted -and
    [string]$provenance.bw24p_profile_publication_status -ceq
        "closed_complete_valid_positive_deterministic_zero_world_profile_publication" -and
    [bool]$provenance.bw24p_authorizes_distinct_bw25y_manifest -and
    -not [bool]$provenance.bw24p_authorizes_bw25y_physical_launch -and
    [bool]$provenance.fresh_material_values -and
    [bool]$provenance.fresh_unopened_locomotion_seeds -and
    -not [bool]$provenance.same_identity_repair_or_rerun
) "BW25Y successor provenance or non-promotion boundary changed"

Assert-SequenceExact @($matrix.seeds) @(26011, 26012, 26013, 26014) `
    "BW25Y seeds"
Assert-SequenceExact @($matrix.candidate_order) @("BW25Y-A", "BW25Y-B") `
    "BW25Y candidate order"
Assert-Exact (
    [int]$matrix.candidate_world_count -eq 24 -and
    [int]$matrix.control_world_count -eq 3 -and
    [int]$matrix.safety_world_count -eq 1 -and
    [int]$matrix.expected_world_count -eq 28 -and
    $cells.Count -eq 28 -and
    @($cells | Where-Object role -CEQ "candidate").Count -eq 24 -and
    @($cells | Where-Object role -CEQ "control").Count -eq 3 -and
    @($cells | Where-Object role -CEQ "safety").Count -eq 1 -and
    @($cells.cell_id | Sort-Object -Unique).Count -eq 28
) "BW25Y matrix cardinality or unique cell identity changed"

$expectedProfiles = [ordered]@{
    "0.59" = @(
        0.58,
        "godot_jolt_bw24m_mu059_v1",
        "sha256:2d8a2571c129dbe7b2b894bae1aa28f5650fdbea27fcb65a149566c54a536173"
    )
    "0.71" = @(
        0.68,
        "godot_jolt_bw24m_mu071_v1",
        "sha256:a8efdd111b740391931219d720079beffeea8181e5c46fd00ea7acb6108ab8ee"
    )
    "0.83" = @(
        0.81,
        "godot_jolt_bw24m_mu083_v1",
        "sha256:e5916d9e17f87120e5cc04ff03e8688c4dea3919715a68854a8dce29e4d9c2a0"
    )
}
$expectedCellIds = [Collections.Generic.List[string]]::new()
foreach ($authoredFriction in @(0.59, 0.71, 0.83)) {
    $key = $authoredFriction.ToString(
        "0.00",
        [Globalization.CultureInfo]::InvariantCulture
    )
    $digits = $key.Replace(".", "")
    $materialCells = @($cells | Where-Object {
        [double]$_.authored_friction -eq $authoredFriction
    })
    Assert-Exact (
        $materialCells.Count -eq 9
    ) "BW25Y material $key does not have exactly nine cells"
    foreach ($seed in @(26011, 26012, 26013, 26014)) {
        foreach ($suffix in @("a", "b")) {
            $expectedCellIds.Add(
                "development_mu${digits}_s${seed}_bw25y_${suffix}"
            )
        }
        $pair = @($materialCells | Where-Object {
            [int]$_.campaign_seed -eq $seed -and
            [string]$_.role -ceq "candidate"
        })
        Assert-Exact (
            $pair.Count -eq 2 -and
            (@($pair.candidate_id) -join ",") -ceq "BW25Y-A,BW25Y-B"
        ) "BW25Y material/seed pair changed: $key/$seed"
        foreach ($cell in $pair) {
            Assert-Exact (
                [double]$cell.controller_coefficient -eq
                    [double]$expectedProfiles[$key][0] -and
                [string]$cell.profile_id -ceq
                    [string]$expectedProfiles[$key][1] -and
                [string]$cell.profile_digest -ceq
                    [string]$expectedProfiles[$key][2] -and
                [double]$cell.global_requested_correction_scale -eq 0.5
            ) "BW25Y profile, coefficient, or scale changed: $($cell.cell_id)"
        }
    }
    $expectedCellIds.Insert(
        $expectedCellIds.Count - 6,
        "development_mu${digits}_s26011_control"
    )
    $control = @($materialCells | Where-Object role -CEQ "control")
    Assert-Exact (
        $control.Count -eq 1 -and
        [int]$control[0].campaign_seed -eq 26011 -and
        [string]$control[0].candidate_id -ceq "BW25Y-CONTROL" -and
        [double]$control[0].controller_coefficient -eq
            [double]$expectedProfiles[$key][0] -and
        [double]$control[0].global_requested_correction_scale -eq 0.0
    ) "BW25Y material-matched control changed: $key"
}
$expectedCellIds.Add("negative_mu000_s26011_safety")
Assert-SequenceExact @($cells.cell_id) @($expectedCellIds) "BW25Y ordered cells"

$candidateA = @($cells | Where-Object candidate_id -CEQ "BW25Y-A")
$candidateB = @($cells | Where-Object candidate_id -CEQ "BW25Y-B")
Assert-Exact (
    $candidateA.Count -eq 12 -and
    @($candidateA | Where-Object {
        [string]$_.controller_policy_id -cne
            "sporespore_balanced_wave_bw15f_b_v1" -or
        [string]$_.runtime_profile_sha256 -cne
            "sha256:1134302a1566e12d1e1179beebed893176eeed88065920855026e903738bb413" -or
        [string]$_.candidate_composition_digest -cne
            "sha256:3a2e04cfa76c63f829d9828b125a8de2e0c0fe35e75b29d8caf87866ce1ea913" -or
        [double]$_.yaw_error_stride_gain_per_rad -ne 1.3
    }).Count -eq 0 -and
    $candidateB.Count -eq 12 -and
    @($candidateB | Where-Object {
        [string]$_.controller_policy_id -cne
            "sporespore_balanced_wave_bw23y_b_v1" -or
        [string]$_.runtime_profile_sha256 -cne
            "sha256:d345d9607bed545ee6c58a20055cd6258f38ed581dd3d9f6490a9ae7f1a57570" -or
        [string]$_.candidate_composition_digest -cne
            "sha256:cba24c1ac86b4cc629723d86609af58a17e88b23c041c4e8bca5deb766704a57" -or
        [double]$_.yaw_error_stride_gain_per_rad -ne 1.0
    }).Count -eq 0
) "BW25Y candidate policy, composition, or yaw-gain contrast changed"

$safety = @($cells | Where-Object role -CEQ "safety")
Assert-Exact (
    $safety.Count -eq 1 -and
    [string]$safety[0].cell_id -ceq "negative_mu000_s26011_safety" -and
    [int]$safety[0].campaign_seed -eq 26011 -and
    [double]$safety[0].authored_friction -eq 0.0 -and
    [double]$safety[0].controller_coefficient -eq 0.0 -and
    [string]$safety[0].profile_id -ceq "godot_jolt_p5m1r1_mu000_v1" -and
    [string]$safety[0].candidate_id -ceq "BW25Y-SAFETY" -and
    [string]$safety[0].controller_policy_id -ceq "NONE" -and
    [double]$safety[0].global_requested_correction_scale -eq 0.0
) "BW25Y zero-friction safety cell changed"

Assert-Exact (
    [string]$contrast.single_mechanism_difference -ceq
        "BW25Y-B differs from BW25Y-A only by policy identity and yaw_error_stride_gain_per_rad 1.3 to 1.0." -and
    [double]$contrast.candidate_a_yaw_error_stride_gain_per_rad -eq 1.3 -and
    [double]$contrast.candidate_b_yaw_error_stride_gain_per_rad -eq 1.0 -and
    [bool]$contrast.all_other_runtime_profile_fields_held_identical -and
    [bool]$contrast.material_seed_fixture_scale_schedule_and_gates_held_identical -and
    [int]$policy.policy_branch_surface_count -eq 0 -and
    [int]$policy.morphology_condition_count -eq 0 -and
    [int]$policy.material_condition_count -eq 0 -and
    [int]$policy.seed_condition_count -eq 0 -and
    [int]$policy.failure_identity_condition_count -eq 0 -and
    [int]$policy.outcome_condition_count -eq 0 -and
    @($policy.branch_surfaces).Count -eq 0
) "BW25Y controller contrast or forbidden branch surface changed"

Assert-SequenceExact @($receipt.decision_walking_keys_in_exact_order) @(
    "bounded_lateral_drift",
    "bounded_tilt",
    "minimum_final_forward_translation",
    "native_sdk_exclusive_post_settle_actuation"
) "BW25Y decision walking keys"
Assert-SequenceExact @($receipt.common_identity_fields_required_in_every_world) @(
    "controller_coefficient",
    "declared_controller_policy_id",
    "controller_runtime_profile_sha256",
    "yaw_error_stride_gain_per_rad",
    "seed_condition_count",
    "failure_identity_condition_count",
    "outcome_condition_count",
    "failed_production_walking_gate_count"
) "BW25Y common receipt fields"
Assert-Exact (
    [int]$receipt.decision_walking_key_count -eq 4 -and
    [bool]$receipt.full_inherited_walking_dictionary_must_be_projected_before_final_serialization -and
    [bool]$receipt.walking_observed_must_be_computed_from_the_exact_four_key_projection -and
    [bool]$receipt.failed_production_walking_gate_count_must_be_computed_from_the_exact_four_key_projection -and
    [bool]$receipt.controller_coefficient_required_in_every_world -and
    [bool]$receipt.safety_receipt_uses_declared_none_sentinels_and_complete_common_schema -and
    [bool]$receipt.real_shaped_candidate_control_safety_and_negative_walking_receipts_must_traverse_complete_production_evaluator -and
    [bool]$receipt.negative_walking_outcome_must_pass_execution_integrity_while_remaining_a_physical_failure
) "BW25Y receipt-parity repair contract changed"

Assert-SequenceExact @($selector.selection_vector_in_priority_order) @(
    "walking_conjunction_failure_count",
    "aggregate_failed_production_walking_gate_count",
    "maximum_absolute_cross_track_error_m",
    "aggregate_cumulative_absolute_cross_track_error_m_s",
    "candidate_order"
) "BW25Y selection vector"
Assert-Exact (
    [string]$selector.selection_mode -ceq
        "complete_preregistered_paired_lexicographic_development_selection" -and
    [string]$selector.baseline_candidate_id -ceq "BW25Y-A" -and
    [string]$selector.successor_candidate_id -ceq "BW25Y-B" -and
    [bool]$selector.eligibility_requires_zero_receipt_composition_failures -and
    [bool]$selector.successor_must_be_strictly_lexicographically_better_than_baseline -and
    [int]$selector.successor_paired_walking_gate_regression_count_must_equal -eq 0 -and
    [string]$selector.no_eligible_strict_improvement_selects -ceq "NONE" -and
    [bool]$selector.selection_is_development_hypothesis_only -and
    [bool]$selector.selected_successor_requires_distinct_independent_validation -and
    -not [bool]$selector.independent_validation_authority
) "BW25Y selector or non-promotion boundary changed"

Assert-Exact (
    [bool]$preflight.production_evaluator_must_accept_a_perfect_serialized_28_cell_result -and
    [bool]$preflight.complete_gate_must_run_before_attempt_receipt_and_before_first_world -and
    [bool]$preflight.real_adapter_entrypoint_must_preflight_all_28_cells_without_worlds -and
    [bool]$preflight.candidate_authority_contract_must_pass_without_worlds -and
    [bool]$preflight.complete_policy_relative_receipt_composition_must_pass_without_worlds -and
    [bool]$preflight.real_shaped_receipt_parity_must_pass_without_worlds -and
    [bool]$preflight.full_walking_dictionary_canary_must_fail -and
    [bool]$preflight.missing_controller_coefficient_canary_must_fail -and
    [bool]$preflight.incomplete_safety_schema_canary_must_fail -and
    [bool]$preflight.negative_walking_outcome_canary_must_preserve_execution_integrity -and
    [int]$preflight.world_build_count -eq 0 -and
    [int]$preflight.scene_tree_insertion_count -eq 0 -and
    [int]$preflight.physics_state_mutation_count -eq 0 -and
    -not [bool]$preflight.locomotion_outcome_exposed -and
    -not [bool]$preflight.physical_acceptance_authority -and
    [bool]$interlocks.physical_execution_blocked_at_stage_zero -and
    [bool]$interlocks.physical_run_requires_distinct_complete_stage_one_freeze -and
    [bool]$interlocks.physical_run_requires_clean_pushed_source_matching_live_github_main -and
    [bool]$interlocks.attempt_receipt_must_mark_source_identity_consumed_before_first_physical_process -and
    -not [bool]$interlocks.same_identity_rerun_allowed
) "BW25Y stage-one zero-world gate or physical interlock changed"

Assert-Exact (
    [bool]$recovery.prospectively_incorporated_before_first_physical_world -and
    [bool]$recovery.retained_physical_execution_serialized_on_current_host -and
    [bool]$recovery.concurrent_read_only_static_and_zero_world_work_allowed -and
    [bool]$recovery.simultaneous_retained_physics_requires_a_distinct_proven_host_isolation_contract -and
    [bool]$recovery.complete_cell_receipt_is_final_pass_or_fail -and
    [bool]$recovery.complete_cell_receipt_may_not_be_replaced -and
    [string]$recovery.incomplete_cell_receipt_status -ceq
        "infrastructure_interrupted_no_scientific_disposition" -and
    [int]$recovery.replacement_budget_per_exact_incomplete_cell -eq 1 -and
    [string]$recovery.replacement_slot_id_template -ceq
        "BW25Y-R1::<cell_id>" -and
    [string]$recovery.replacement_eligibility -ceq
        "absence_of_complete_cell_receipt_only" -and
    [bool]$recovery.unexplained_termination_treated_as_infrastructure_interruption -and
    [bool]$recovery.replacement_uses_byte_identical_source_controller_thresholds_inputs_fixture_material_seed_schedule_and_evaluator -and
    [bool]$recovery.replacement_receives_a_new_attempt_and_world_identity_linked_to_the_interrupted_attempt -and
    [bool]$recovery.replacement_never_overwrites_or_continues_the_interrupted_world -and
    [bool]$recovery.all_partial_logs_attempt_records_reservations_termination_metadata_and_replacement_links_retained -and
    [bool]$recovery.replacement_decision_automatic_from_receipt_completeness -and
    [bool]$recovery.partial_trajectory_or_outcome_may_not_alter_or_cancel_recovery -and
    [bool]$recovery.first_complete_receipt_for_each_exact_reservation_is_scored -and
    [bool]$recovery.outcome_based_retry_or_replacement_forbidden -and
    [bool]$recovery.exhausted_replacement_budget_closes_campaign_incomplete
) "BW25Y prospective infrastructure-interruption contract changed"

foreach ($claimName in @($claims.Keys)) {
    Assert-Exact (
        -not [bool]$claims[$claimName]
    ) "BW25Y prospective claim inflated: $claimName"
}

Assert-Exact (
    [string]$candidates.schema_version -ceq
        "sporespore_balanced_wave_bw25y_yaw_development_candidates_v1" -and
    [string]$candidates.status -ceq
        "prospective_development_candidates_no_physical_authority" -and
    [string]$candidates.campaign_id -ceq $campaignId -and
    [string]$candidates.implementation_parent_commit -ceq
        $implementationParentCommit -and
    (@($candidates.candidate_order) -join ",") -ceq "BW25Y-A,BW25Y-B" -and
    @($candidates.candidates).Count -eq 2 -and
    @($candidates.policy_relative_control.branch_surfaces).Count -eq 0 -and
    [string]$candidates.candidate_composition_digests."BW25Y-A" -ceq
        "sha256:3a2e04cfa76c63f829d9828b125a8de2e0c0fe35e75b29d8caf87866ce1ea913" -and
    [string]$candidates.candidate_composition_digests."BW25Y-B" -ceq
        "sha256:cba24c1ac86b4cc629723d86609af58a17e88b23c041c4e8bca5deb766704a57" -and
    -not [bool]$candidates.claim_boundary.physical_acceptance_authority
) "BW25Y candidate declaration identity or claim boundary changed"

$priorAttempts = @()
if (Test-Path -LiteralPath $evidenceRoot -PathType Container) {
    $priorAttempts = @(
        Get-ChildItem -LiteralPath $evidenceRoot -Recurse -File -Filter "attempt.json" |
            Where-Object {
                try {
                    $attempt = Get-Content -Raw -LiteralPath $_.FullName |
                        ConvertFrom-Json
                    [string]$attempt.campaign_id -ceq $campaignId
                } catch { $false }
            }
    )
}
Assert-Exact (
    $priorAttempts.Count -eq 0
) "BW25Y prior physical attempt exists; prephysical declaration boundary is invalid"
foreach ($forbiddenPath in @(
    "sdk/balanced_wave_bw25y_yaw_development_closure.json"
)) {
    Assert-Exact (
        -not (Test-Path -LiteralPath (Join-Path $repoRoot $forbiddenPath))
    ) "BW25Y prephysical boundary unexpectedly contains closure artifact: $forbiddenPath"
}
foreach ($requiredStageOnePath in @(
    "sdk/balanced_wave_bw25y_yaw_development_freeze.json",
    "sdk/run_balanced_wave_bw25y_yaw_development.ps1",
    "tests/test_sdk_balanced_wave_bw25y_yaw_development.gd",
    "tests/test_bw25y_yaw_development_freeze.ps1"
)) {
    Assert-Exact (
        Test-Path -LiteralPath (Join-Path $repoRoot $requiredStageOnePath) -PathType Leaf
    ) "BW25Y complete stage-one artifact is missing: $requiredStageOnePath"
}

& pwsh -NoLogo -NoProfile -File $gateTestPath
Assert-Exact (
    $LASTEXITCODE -eq 0
) "BW25Y complete synthetic production evaluator failed"

& pwsh -NoLogo -NoProfile -File $receiptParityTestPath
Assert-Exact (
    $LASTEXITCODE -eq 0
) "BW25Y real-shaped final receipt parity preflight failed"

if (-not $SkipPrerequisiteAudits) {
    & pwsh `
        -NoLogo `
        -NoProfile `
        -File (Join-Path $repoRoot "tests\test_bw22l_lateral_development_closure.ps1")
    Assert-Exact (
        $LASTEXITCODE -eq 0
    ) "BW25Y prerequisite BW22L invalid closure audit failed"

    & pwsh `
        -NoLogo `
        -NoProfile `
        -File (Join-Path $repoRoot "tests\test_bw24p_material_profile_publication_closure.ps1")
    Assert-Exact (
        $LASTEXITCODE -eq 0
    ) "BW25Y prerequisite BW24P positive profile closure audit failed"
}

if (-not $SkipGodotPreflight) {
    & pwsh `
        -NoLogo `
        -NoProfile `
        -File $runnerPath `
        -Godot $Godot
    Assert-Exact (
        $LASTEXITCODE -eq 0
    ) "BW25Y zero-world declaration preflight failed"
}

Write-Host (
    "BW25Y_DECLARATION_PASS candidates=2 materials=3 seeds=4 " +
    "worlds_planned=28 candidate_worlds=24 controls=3 safety=1 " +
    "receipt_keys=4 gate_canaries=28 receipt_parity=True worlds_opened=0 " +
    "stage_one_gate=True stage_one_freeze=True physical_worker=True " +
    "physical_authority=False"
)
