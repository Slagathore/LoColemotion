#requires -Version 7.0

[CmdletBinding()]
param(
    [switch]$SkipGodotPreflight,
    [string]$Godot = (
        "C:\Users\Cole\CodeStuff\Misc\Godot\" +
        "Godot_v4.7-stable_mono_win64_console.exe"
    )
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [System.IO.Path]::GetFullPath(
    (Split-Path -Parent $PSScriptRoot)
)
$implementationParentCommit = "dff8dfb647a3b04e78134d2f9e1bccf74c4c8e16"
$campaignId = "BW22L-FRESH-MATERIAL-LATERAL-DEVELOPMENT"
$preregistrationPath = Join-Path (
    $repoRoot
) "sdk\balanced_wave_bw22l_lateral_development_preregistration.json"
$candidatesPath = Join-Path (
    $repoRoot
) "sdk\balanced_wave_bw22l_lateral_development_candidates.json"
$runnerPath = Join-Path (
    $repoRoot
) "sdk\run_balanced_wave_bw22l_lateral_declaration_preflight.ps1"
$gateTestPath = Join-Path (
    $repoRoot
) "tests\test_bw22l_lateral_development_gate.ps1"
$evidenceRoot = Join-Path (
    (Split-Path -Parent $repoRoot)
) "SporeSpore_Evidence"

$boundFiles = [ordered]@{
    "sdk/balanced_wave_bw22l_lateral_development_preregistration.json" =
        "2688945b7953c52ae049990868ef15c1e0efce06dd32f78ba6526e7459ab8d4b"
    "sdk/balanced_wave_bw22l_lateral_development_candidates.json" =
        "31b02c3cfd6c15ed054d27082c21d8e2fad7811260bfc952e8455ba72a90a55c"
    "sdk/balanced_wave_bw22l_lateral_development_gate.ps1" =
        "26ba0536bb8583af171f8c0b8126fdeaabf8889d5eaa94597a17bf69e1159d65"
    "sdk/run_balanced_wave_bw22l_lateral_declaration_preflight.ps1" =
        "41c258bb7506045bdba7e63491b5ef0c830d30fb367b044b6679ca5376e53bc6"
    "tests/test_bw22l_lateral_development_gate.ps1" =
        "4f038cfdd6125160bfbe9b621c54e36c59f8215070fc5ffd707b5039c22a3e18"
    "tests/test_sdk_balanced_wave_bw22l_authority_contract.gd" =
        "5201e54590889c3d56d3c60520fd6eaed000642c2b8e7a17ca6cdd886cb55b56"
    "sdk/balanced_wave_bw22m_material_profile_publication_closure.json" =
        "09a7f017a85f9bfe53c6f707985bd9b87083cee564168bf0311d8b57d8b787e9"
    "tests/test_bw22m_material_profile_publication_closure.ps1" =
        "b7e5ee4bc814ff23fd598fb548dd1003e2b5dbe7fddc6653c41552285c20ce1d"
    "sdk/balanced_wave_bw21l_lateral_development_closure.json" =
        "d592e160c1111d05047a545986099ce957226a8d12e81d19013930133b98af4b"
    "tests/test_bw21l_lateral_development_closure.ps1" =
        "f695f17a12d33d48ff331168b96df8ae2e872091571653f4a576d196e1990799"
    "sdk/balanced_wave_bw19v_closure_manifest.json" =
        "ea8df6a574e1b9be1050afa8ed57982a102982ada0f0d5babccf3c937c7067f7"
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
    ) "BW22L declaration artifact is missing or changed: $($entry.Key)"
}

& git -C $repoRoot merge-base --is-ancestor $implementationParentCommit HEAD
Assert-Exact (
    $LASTEXITCODE -eq 0
) "BW22L implementation parent is not an ancestor of HEAD"

$preregistration = Get-Content -Raw -LiteralPath $preregistrationPath |
    ConvertFrom-Json -AsHashtable -Depth 100
$candidatesDeclaration = Get-Content -Raw -LiteralPath $candidatesPath |
    ConvertFrom-Json -AsHashtable -Depth 100
$study = $preregistration.study_class
$hostIdentity = $preregistration.host_identity
$policy = $preregistration.policy
$selector = $preregistration.selection_contract
$diagnostics = $preregistration.retained_diagnostic_contract
$matrix = $preregistration.matrix
$gate = $preregistration.gate_contract
$preflight = $preregistration.required_stage_one_freeze_contract
$interlocks = $preregistration.staged_interlocks
$claims = $preregistration.claims_before_and_after_development
$cells = @($matrix.ordered_cells)

Assert-Exact (
    [string]$preregistration.schema_version -ceq
        "sporespore_balanced_wave_bw22l_lateral_development_preregistration_v1" -and
    [string]$preregistration.status -ceq
        "prospective_stage_zero_zero_world_only_physical_execution_blocked" -and
    [string]$preregistration.campaign_id -ceq $campaignId -and
    [string]$preregistration.gate_id -ceq "BW22L" -and
    [string]$preregistration.implementation_parent_commit -ceq
        $implementationParentCommit -and
    [string]$study.classification -ceq
        "paired_outcome_exposed_finite_controller_development_screen" -and
    [bool]$study.finite_decision -and
    [bool]$study.development_screen -and
    -not [bool]$study.population_inference -and
    -not [bool]$study.superiority_study -and
    -not [bool]$study.noninferiority_or_equivalence_study -and
    [int]$study.expected_world_count -eq 28 -and
    [bool]$study.baseline_may_remain_unreplaced -and
    [bool]$study.development_result_may_validly_select_none
) "BW22L identity or development-only study class changed"

Assert-Exact (
    [string]$hostIdentity.operating_system_family -ceq "windows" -and
    [string]$hostIdentity.godot_version -ceq
        "4.7.stable.mono.official.5b4e0cb0f" -and
    [string]$hostIdentity.godot_executable_sha256 -ceq
        "c5fc2d0bb24826a6757fa1e6bf2991effb294859c7dd03d09a122ef217484896" -and
    [string]$hostIdentity.adapter_id -ceq "godot_jolt_gdextension_v1" -and
    [string]$hostIdentity.physics_engine -ceq "Jolt Physics" -and
    [string]$hostIdentity.solver_policy_id -ceq "jolt_120hz_20v_7p_v1" -and
    [int]$hostIdentity.physics_hz -eq 120 -and
    [int]$hostIdentity.solver_velocity_steps -eq 20 -and
    [int]$hostIdentity.solver_position_steps -eq 7 -and
    [string]$hostIdentity.material_combine_rule -ceq
        "highest_friction_both_rough_v1"
) "BW22L host or solver identity changed"

Assert-SequenceExact @($matrix.seeds) @(24011, 24012, 24013, 24014) `
    "BW22L seeds"
Assert-SequenceExact @($matrix.candidate_order) @("BW22L-A", "BW22L-B") `
    "BW22L candidate order"
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
) "BW22L matrix cardinality or unique cell identity changed"

$expectedProfiles = [ordered]@{
    "0.57" = @(
        "godot_jolt_bw22m_mu057_v1",
        "sha256:754c2f45b19dea315bd3527db8b8b87041be57cb7e4999412710d82c7c57903f"
    )
    "0.69" = @(
        "godot_jolt_bw22m_mu069_v1",
        "sha256:a66f00fb0836a0838ab20e3f54c531ee5e9a6ea50180780e81e4f6106aad5ff3"
    )
    "0.81" = @(
        "godot_jolt_bw22m_mu081_v1",
        "sha256:9446ba227a7a80f7592ffb7e358b8903a4e7afeb7297d5ba94dab87be8e33cbd"
    )
}
$expectedSeeds = @(24011, 24012, 24013, 24014)
foreach ($authoredFriction in @(0.57, 0.69, 0.81)) {
    $key = $authoredFriction.ToString(
        "0.00",
        [Globalization.CultureInfo]::InvariantCulture
    )
    $materialCells = @($cells | Where-Object {
        [double]$_.authored_friction -eq $authoredFriction
    })
    Assert-Exact (
        $materialCells.Count -eq 9
    ) "BW22L material $key does not have exactly nine cells"
    foreach ($seed in $expectedSeeds) {
        $pair = @($materialCells | Where-Object {
            [int]$_.campaign_seed -eq $seed -and
            [string]$_.role -ceq "candidate"
        })
        Assert-Exact (
            $pair.Count -eq 2 -and
            (@($pair.candidate_id) -join ",") -ceq "BW22L-A,BW22L-B"
        ) "BW22L material/seed pair changed: $key/$seed"
        foreach ($cell in $pair) {
            Assert-Exact (
                [string]$cell.profile_id -ceq $expectedProfiles[$key][0] -and
                [string]$cell.profile_digest -ceq $expectedProfiles[$key][1] -and
                [double]$cell.global_requested_correction_scale -eq 0.5
            ) "BW22L profile or scale changed: $($cell.cell_id)"
        }
    }
    $control = @($materialCells | Where-Object role -CEQ "control")
    Assert-Exact (
        $control.Count -eq 1 -and
        [int]$control[0].campaign_seed -eq 24011 -and
        [string]$control[0].candidate_id -ceq "BW22L-CONTROL" -and
        [double]$control[0].global_requested_correction_scale -eq 0.0
    ) "BW22L material-matched control changed: $key"
}

$candidateA = @($cells | Where-Object candidate_id -CEQ "BW22L-A")
$candidateB = @($cells | Where-Object candidate_id -CEQ "BW22L-B")
Assert-Exact (
    $candidateA.Count -eq 12 -and
    @($candidateA | Where-Object {
        [string]$_.controller_policy_id -cne
            "sporespore_balanced_wave_bw15f_b_v1" -or
        [string]$_.runtime_profile_sha256 -cne
            "sha256:1134302a1566e12d1e1179beebed893176eeed88065920855026e903738bb413" -or
        [string]$_.candidate_composition_digest -cne
            "sha256:c67ad10b9eb0c74eae4a91b7a431c0d0eaae8c28574dcc78d91ab90fdee82aba" -or
        [double]$_.proportional_factor -ne 1.0 -or
        [double]$_.velocity_factor -ne 1.0
    }).Count -eq 0 -and
    $candidateB.Count -eq 12 -and
    @($candidateB | Where-Object {
        [string]$_.controller_policy_id -cne
            "sporespore_balanced_wave_bw21l_b_v1" -or
        [string]$_.runtime_profile_sha256 -cne
            "sha256:70b1b0c445bc8b53d94a09f70e18271b9727d9f41b772fa843ae9e59174af6f5" -or
        [string]$_.candidate_composition_digest -cne
            "sha256:431e8ea82d751f5c3755a21a2e91d096264580caa3b84d2dbaa9fc50062db07e" -or
        [double]$_.proportional_factor -ne 1.5 -or
        [double]$_.velocity_factor -ne 1.0
    }).Count -eq 0
) "BW22L candidate policy, composition, or controlled gain contrast changed"

$safety = @($cells | Where-Object role -CEQ "safety")
Assert-Exact (
    $safety.Count -eq 1 -and
    [string]$safety[0].cell_id -ceq "negative_mu000_s24011_safety" -and
    [int]$safety[0].campaign_seed -eq 24011 -and
    [double]$safety[0].authored_friction -eq 0.0 -and
    [string]$safety[0].profile_id -ceq "godot_jolt_p5m1r1_mu000_v1" -and
    [string]$safety[0].candidate_id -ceq "NONE" -and
    [double]$safety[0].global_requested_correction_scale -eq 0.0
) "BW22L zero-friction safety cell changed"

Assert-Exact (
    [int]$policy.policy_branch_surface_count -eq 0 -and
    [int]$policy.morphology_condition_count -eq 0 -and
    [int]$policy.material_condition_count -eq 0 -and
    [int]$policy.seed_condition_count -eq 0 -and
    [int]$policy.failure_identity_condition_count -eq 0 -and
    [int]$policy.outcome_condition_count -eq 0 -and
    @($policy.branch_surfaces).Count -eq 0
) "BW22L controller gained a forbidden branch surface"

Assert-SequenceExact @($selector.selection_vector_in_priority_order) @(
    "walking_conjunction_failure_count",
    "aggregate_failed_production_walking_gate_count",
    "maximum_absolute_cross_track_error_m",
    "aggregate_cumulative_absolute_cross_track_error_m_s",
    "candidate_order"
) "BW22L selection vector"
Assert-Exact (
    [string]$selector.selection_mode -ceq
        "complete_preregistered_paired_lexicographic_development_selection" -and
    [string]$selector.baseline_candidate_id -ceq "BW22L-A" -and
    [string]$selector.successor_candidate_id -ceq "BW22L-B" -and
    [bool]$selector.successor_must_be_strictly_lexicographically_better_than_baseline -and
    [int]$selector.successor_paired_walking_gate_regression_count_must_equal -eq 0 -and
    [string]$selector.no_eligible_strict_improvement_selects -ceq "NONE" -and
    [bool]$selector.selection_is_development_hypothesis_only -and
    [bool]$selector.selected_successor_requires_distinct_independent_validation -and
    -not [bool]$selector.independent_validation_authority
) "BW22L selector or non-promotion boundary changed"

Assert-SequenceExact @($diagnostics.per_candidate_world_required_fields) @(
    "final_task_frame_lateral_displacement_m",
    "maximum_absolute_cross_track_error_m",
    "cumulative_absolute_cross_track_error_m_s",
    "minimum_cross_track_error_m",
    "maximum_cross_track_error_m",
    "steering_feedback_update_count",
    "steering_filter_application_count",
    "steering_saturation_count",
    "steering_slew_limited_count",
    "maximum_absolute_requested_steering_fraction",
    "maximum_absolute_filtered_steering_fraction",
    "maximum_absolute_steering_delta_per_step",
    "initial_perturbation",
    "initial_perturbation_sha256",
    "walking_gate_receipts"
) "BW22L retained diagnostic fields"
Assert-Exact (
    [bool]$diagnostics.all_numeric_diagnostics_must_be_finite -and
    [bool]$diagnostics.steering_update_and_filter_counts_must_be_positive -and
    [double]$diagnostics.maximum_absolute_requested_and_filtered_steering_fraction_must_not_exceed -eq 0.4 -and
    [bool]$diagnostics.receipts_are_mechanism_and_selection_diagnostics_not_acceptance_thresholds
) "BW22L diagnostic completeness or steering bound changed"

Assert-Exact (
    [int]$gate.expected_gate_count -eq 50 -and
    [int]$gate.pre_matrix_gate_count -eq 4 -and
    [int]$gate.per_world_execution_integrity_gate_count -eq 28 -and
    [int]$gate.aggregate_gate_count -eq 18 -and
    @($gate.aggregate_gates).Count -eq 18 -and
    @($gate.aggregate_gates) -contains "policy_relative_receipt_identity" -and
    @($gate.aggregate_gates) -contains "selector_not_preinvoked" -and
    -not [bool]$gate.walking_success_required_for_every_candidate_cell -and
    [bool]$gate.development_result_may_validly_select_none -and
    [bool]$gate.outcome_based_early_stop_forbidden -and
    [bool]$gate.selective_cell_rerun_forbidden -and
    [bool]$gate.failed_cell_replacement_forbidden -and
    [bool]$gate.first_complete_result_is_final_for_this_source_identity
) "BW22L gate arithmetic or completion rule changed"

Assert-Exact (
    [bool]$preflight.production_evaluator_must_accept_a_perfect_serialized_28_cell_result -and
    [bool]$preflight.complete_gate_must_run_before_attempt_receipt_and_before_first_world -and
    [bool]$preflight.real_adapter_entrypoint_must_preflight_all_28_cells_without_worlds -and
    [bool]$preflight.candidate_authority_contract_must_pass_without_worlds -and
    [bool]$preflight.complete_policy_relative_receipt_composition_must_pass_without_worlds -and
    [bool]$preflight.missing_or_reordered_cell_canary_must_fail -and
    [bool]$preflight.candidate_policy_gain_or_digest_canary_must_fail -and
    [bool]$preflight.control_base_influence_canary_must_fail -and
    [bool]$preflight.claim_inflation_canary_must_fail -and
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
) "BW22L zero-world preflight or staged physical interlock changed"

foreach ($claimName in @($claims.Keys)) {
    Assert-Exact (
        -not [bool]$claims[$claimName]
    ) "BW22L prospective claim inflated: $claimName"
}

Assert-Exact (
    [string]$candidatesDeclaration.schema_version -ceq
        "sporespore_balanced_wave_bw22l_lateral_development_candidates_v1" -and
    [string]$candidatesDeclaration.status -ceq
        "prospective_development_candidates_no_physical_authority" -and
    [string]$candidatesDeclaration.campaign_id -ceq $campaignId -and
    [string]$candidatesDeclaration.implementation_parent_commit -ceq
        $implementationParentCommit -and
    (@($candidatesDeclaration.candidate_order) -join ",") -ceq
        "BW22L-A,BW22L-B" -and
    @($candidatesDeclaration.candidates).Count -eq 2 -and
    @($candidatesDeclaration.policy_relative_control.branch_surfaces).Count -eq 0 -and
    -not [bool]$candidatesDeclaration.claim_boundary.physical_acceptance_authority
) "BW22L candidate declaration identity or claim boundary changed"

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
) "BW22L prior physical attempt exists; stage-zero declaration is invalid"
foreach ($forbiddenPath in @(
    "sdk/balanced_wave_bw22l_lateral_development_freeze.json",
    "sdk/balanced_wave_bw22l_lateral_development_closure.json",
    "sdk/run_balanced_wave_bw22l_lateral_development.ps1",
    "tests/test_sdk_balanced_wave_bw22l_lateral_development.gd"
)) {
    Assert-Exact (
        -not (Test-Path -LiteralPath (Join-Path $repoRoot $forbiddenPath))
    ) "BW22L stage-zero unexpectedly contains physical-stage artifact: $forbiddenPath"
}

& pwsh `
    -NoLogo `
    -NoProfile `
    -File (Join-Path $repoRoot "tests\test_bw21l_lateral_development_closure.ps1")
Assert-Exact (
    $LASTEXITCODE -eq 0
) "BW22L prerequisite BW21L invalid closure audit failed"

& pwsh `
    -NoLogo `
    -NoProfile `
    -File (
        Join-Path $repoRoot `
            "tests\test_bw22m_material_profile_publication_closure.ps1"
    )
Assert-Exact (
    $LASTEXITCODE -eq 0
) "BW22L prerequisite BW22M profile closure audit failed"

if ($SkipGodotPreflight) {
    & pwsh -NoLogo -NoProfile -File $gateTestPath
    Assert-Exact (
        $LASTEXITCODE -eq 0
    ) "BW22L synthetic gate test failed"
} else {
    & pwsh `
        -NoLogo `
        -NoProfile `
        -File $runnerPath `
        -Godot $Godot
    Assert-Exact (
        $LASTEXITCODE -eq 0
    ) "BW22L complete zero-world declaration preflight failed"
}

Write-Host (
    "BW22L_DECLARATION_PASS candidates=2 materials=3 seeds=4 " +
    "worlds_planned=28 candidate_worlds=24 controls=3 safety=1 gates=50 " +
    "canaries=23 worlds_opened=0 stage_one_required=True " +
    "physical_authority=False"
)
