#requires -Version 7.0

[CmdletBinding()]
param(
    [switch]$SkipSupervisorPreflight
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [System.IO.Path]::GetFullPath(
    (Split-Path -Parent $PSScriptRoot)
)
$sdkRoot = Join-Path $repoRoot "sdk"
$campaignId = "BW20F-BW19V-COLD-MATERIAL"
$gateId = "BW20F"
$implementationParentCommit = "23f76a41ba0f96a56094350632081acffcc96abe"
$preregistrationRelativePath = (
    "sdk/balanced_wave_bw20f_cold_material_preregistration.json"
)
$preregistrationPath = Join-Path $repoRoot $preregistrationRelativePath
$supervisorPath = Join-Path (
    $sdkRoot
) "run_balanced_wave_bw20f_material_characterization.ps1"
$genericRunnerPath = Join-Path (
    $sdkRoot
) "run_godot_jolt_friction_ladder_characterization.ps1"
$closurePath = Join-Path (
    $sdkRoot
) "balanced_wave_bw20f_material_characterization_closure.json"
$bw19vClosureAuditPath = Join-Path $repoRoot "tests\test_bw19v_closure.ps1"

$frozenFiles = [ordered]@{
    "sdk/balanced_wave_bw20f_cold_material_preregistration.json" =
        "7f90a75611c34dd27c3e2a6f1b04b30a58368be9d9871075fb6ef1d0d2caf999"
    "sdk/balanced_wave_bw20f_material_characterization_gate.ps1" =
        "969e82bd9a603692211d6cf573e1f536a066432559563b0e62b0768334cbd9c3"
    "sdk/run_balanced_wave_bw20f_material_characterization.ps1" =
        "5210424ed569d7e285960399dc4b79973a1d838b0d805260d9278390ab28d870"
    "sdk/run_godot_jolt_friction_ladder_characterization.ps1" =
        "47a84a2611f7050739c2aa96cf8dbfac0f80892220419ac688c79cc03748c5d7"
    "tests/test_bw20f_material_characterization_gate.ps1" =
        "273b396c4af2fb4343b4281774c7f5b27f5ce34b419b38b1267f72190c4b16ac"
    "tests/test_sdk_balanced_wave_bw20f_material_characterization_preflight.gd" =
        "0fc048f3b36d560bd56eebd11391ee34872117d68ef6eed4dc4d8f2ae49bdd21"
    "tests/test_sdk_godot_jolt_friction_ladder_characterization.gd" =
        "2c07053fcce9d0982cf533b1eac65955bb4e3a57e1507fdb20284fc7c6f17c1e"
    "scripts/lab/rigs/sdk_friction_ladder_sled_rig.gd" =
        "bcd40080800669492dbc0633d5aa95ed11461d7ae29756c05e892b3467ccd014"
    "scripts/lab/capture_clock.gd" =
        "f2f0305ce698d17d892057e160928bbebd29bac21c290aa22bf4b112205f1291"
    "scripts/lab/observer_profile.gd" =
        "645844c8534d8c1c0fe693b7dc2c926a3732c3fa020c81cc2240edc5639f8fd2"
    "scripts/lab/rigs/friction_sled_rig.gd" =
        "92f7983a47257e7d3ee7e262ad57aee2c7cd5c345f54f6ce9981da8dd3beb487"
    "scripts/lab/mechanics/observed_rigid_body.gd" =
        "04c95729af1f755f270d07caa97d822d4b86afeeb3b6bcb246b4d68a5284be91"
    "scripts/lab/mechanics/contact_capacity.gd" =
        "8d91b6a9b774f6d51a14fa4eb5672f7779051ed35075cd73d1ac31ecea63c2ca"
    "scripts/lab/mechanics/contact_canonicalizer.gd" =
        "ecc22a205123ef486faa61cbf66c33b6d05b98d3bf1ff2e8b24021bba326089c"
    "scripts/lab/mechanics/contact_slip_observer.gd" =
        "b153ecd8e6d7a4cc867ef8787d9a8cc97ea15cc4a35994dcd4be3640f2c3834b"
    "scripts/lab/mechanics/friction_breakaway_analyzer.gd" =
        "b9efc3397d41609ea6d00d6d3e14c96ea0bb1a61ec0b7a9145a63ab5edcc8a14"
    "scripts/lab/canonical_json.gd" =
        "b1f0f4df813663008824d223165577e281bffb97e81080d33d77c1ffb031501f"
    "scripts/lab/frozen_value.gd" =
        "b45d91510d6f42a3cccc87bb9ea40c602469fed11338860512a832361a835d10"
    "scripts/lab/failure_codes.gd" =
        "9cc79d962ad70b12c932685f8aee3996d62b631d664af57525df8726edfc3456"
    "scripts/lab/finite_sanitizer.gd" =
        "40428eb592bda785be76d32869f63fb55fe8e40ac038a8daf94c976414e6e444"
    "tests/test_bw19v_closure.ps1" =
        "493fd2983f876b9ba0781295d8fc0d855c2520f0dbadc7f42d1a23082b751109"
}

function Assert-Exact {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) {
        throw $Message
    }
}

function Get-RawSha256 {
    param([Parameter(Mandatory)][string]$Path)
    return (Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash.ToLowerInvariant()
}

function Assert-SourceContains {
    param(
        [Parameter(Mandatory)][string]$Source,
        [Parameter(Mandatory)][string[]]$Needles,
        [Parameter(Mandatory)][string]$Label
    )
    foreach ($needle in $Needles) {
        Assert-Exact (
            $Source.Contains($needle, [StringComparison]::Ordinal)
        ) "$gateId $Label lost required surface: $needle"
    }
}

function Invoke-ExpectedFailure {
    param(
        [Parameter(Mandatory)][string[]]$Arguments,
        [Parameter(Mandatory)][string]$ExpectedText,
        [Parameter(Mandatory)][string]$Label
    )
    $output = (& pwsh @Arguments 2>&1 | Out-String)
    $exitCode = $LASTEXITCODE
    Assert-Exact (
        $exitCode -ne 0 -and
        $output.Contains($ExpectedText, [StringComparison]::Ordinal)
    ) "$gateId $Label negative control did not fail before world entry"
}

foreach ($entry in $frozenFiles.GetEnumerator()) {
    $path = Join-Path $repoRoot $entry.Key
    Assert-Exact (
        (Test-Path -LiteralPath $path -PathType Leaf) -and
        (Get-RawSha256 $path) -ceq [string]$entry.Value
    ) "$gateId frozen artifact is missing or changed: $($entry.Key)"
}
Assert-Exact (
    -not (Test-Path -LiteralPath $closurePath -PathType Leaf)
) "$gateId already has a closure and is no longer a prospective freeze"

$preregistration = Get-Content -Raw -LiteralPath $preregistrationPath |
    ConvertFrom-Json -AsHashtable
$study = $preregistration.study_class
$stages = $preregistration.pipeline_stages
$hostIdentity = $preregistration.host_identity
$candidate = $preregistration.candidate_identity
$reservation = $preregistration.cold_reservation
$characterization = $preregistration.material_characterization
$future = $preregistration.future_bw19v_b_cold_locomotion_contract
$claims = $preregistration.claims_if_stage_1_passes

Assert-Exact (
    [string]$preregistration.schema_version -ceq
        "sporespore_balanced_wave_bw20f_cold_material_preregistration_v1" -and
    [string]$preregistration.status -ceq
        "frozen_before_first_bw20f_characterization_world" -and
    [string]$preregistration.campaign_id -ceq $campaignId -and
    [string]$preregistration.gate_id -ceq $gateId -and
    [string]$preregistration.implementation_parent_commit -ceq
        $implementationParentCommit -and
    [string]$study.classification -ceq
        "exact_finite_cell_adapter_material_characterization" -and
    [bool]$study.finite_decision -and
    -not [bool]$study.development_screen -and
    -not [bool]$study.population_inference -and
    -not [bool]$study.superiority_study -and
    -not [bool]$study.noninferiority_or_equivalence_study -and
    -not [bool]$study.sampling_distribution_claim -and
    [int]$study.expected_world_count -eq 13 -and
    [string]$stages.stage_1_material_characterization.status -ceq
        "prospectively_frozen_unopened" -and
    [string]$stages.stage_2_profile_publication.status -ceq
        "blocked_until_stage_1_closes_positive" -and
    [string]$stages.stage_3_bw19v_b_cold_locomotion.status -ceq
        "blocked_until_stage_2_closes_positive_and_a_distinct_manifest_is_frozen"
) "$gateId identity, study class, or staged interlock changed"

Assert-Exact (
    [string]$hostIdentity.operating_system_family -ceq "windows" -and
    [string]$hostIdentity.godot_version -ceq
        "4.7.stable.mono.official.5b4e0cb0f" -and
    [string]$hostIdentity.godot_runtime_version -ceq
        "4.7-stable (official)" -and
    [string]$hostIdentity.godot_executable_sha256 -ceq
        "c5fc2d0bb24826a6757fa1e6bf2991effb294859c7dd03d09a122ef217484896" -and
    [string]$hostIdentity.adapter_id -ceq "godot_jolt_gdextension_v1" -and
    [string]$hostIdentity.physics_engine -ceq "Jolt Physics" -and
    [int]$hostIdentity.physics_hz -eq 120 -and
    [int]$hostIdentity.solver_velocity_steps -eq 20 -and
    [int]$hostIdentity.solver_position_steps -eq 7
) "$gateId exact Godot/Jolt host identity changed"

Assert-Exact (
    [string]$candidate.candidate_id -ceq "BW19V-B" -and
    [string]$candidate.candidate_composition_digest -ceq
        "sha256:3d0fc7ac8da2de811bbc890a4a2a7b32ffc5f59fb9ee36a3e391cdec65548c77" -and
    [string]$candidate.controller_candidate_id -ceq "BW15F-B" -and
    [string]$candidate.controller_policy_id -ceq
        "sporespore_balanced_wave_bw15f_b_v1" -and
    [string]$candidate.controller_policy_digest -ceq
        "sha256:7e6004c57a1f2b193beb3757c5b45ecc3589aabd1b70c103920f0a74dd1207cd" -and
    [string]$candidate.stability_policy_id -ceq
        "sporespore_scheduled_load_transfer_bw13p_a_v3" -and
    [double]$candidate.global_requested_correction_scale -eq 0.5 -and
    [int]$candidate.policy_branch_surface_count -eq 0 -and
    [int]$candidate.material_condition_count -eq 0 -and
    @($candidate.branch_surfaces).Count -eq 0
) "$gateId BW19V-B candidate identity or branch-free material boundary changed"

$selectedPolicy = Get-Content -Raw -LiteralPath (
    Join-Path $repoRoot "sdk\balanced_wave_bw15f_selected_policy.json"
) | ConvertFrom-Json -AsHashtable
Assert-Exact (
    [string]$selectedPolicy.selected_candidate_id -ceq "BW15F-B" -and
    [string]$selectedPolicy.selected_policy_id -ceq
        "sporespore_balanced_wave_bw15f_b_v1" -and
    [string]$selectedPolicy.selected_candidate_policy_digest -ceq
        [string]$candidate.controller_policy_digest -and
    [int]$selectedPolicy.selected_profile.material_condition_count -eq 0 -and
    @($selectedPolicy.selected_profile.branch_surfaces).Count -eq 0 -and
    -not [bool]$selectedPolicy.claims.material_robustness
) "$gateId bound controller policy does not preserve its material-blind contract"

$expectedValues = "0.09,0.37,0.76,1.18"
$expectedSeeds = "23001,23002,23003"
Assert-Exact (
    (@($reservation.authored_friction_values) -join ",") -ceq $expectedValues -and
    (@($reservation.locomotion_campaign_seeds) -join ",") -ceq $expectedSeeds -and
    [bool]$reservation.values_were_unopened_by_locomotion_before_this_freeze -and
    [bool]$reservation.seeds_were_unopened_by_locomotion_before_this_freeze -and
    [bool]$reservation.stage_1_opens_values_for_adapter_characterization_only -and
    [bool]$reservation.stage_1_does_not_open_locomotion_seeds -and
    [bool]$reservation.axis_appears_in_no_controller_branch_condition -and
    @($reservation.unopened_continuity).Count -eq 6
) "$gateId sealed cold values, seeds, or stage-1 boundary changed"

$boundSources = @(
    @($candidate.source_bindings.Values),
    @($reservation.initial_reservation),
    @($reservation.unopened_continuity),
    @($preregistration.numeric_threshold_provenance.inherited_contract),
    @($preregistration.numeric_threshold_provenance.accepted_reference_manifest)
) | ForEach-Object { $_ }
Assert-Exact ($boundSources.Count -eq 13) "$gateId bound-source count changed"
foreach ($binding in $boundSources) {
    $boundPath = Join-Path $repoRoot ([string]$binding.path)
    Assert-Exact (
        (Test-Path -LiteralPath $boundPath -PathType Leaf) -and
        (Get-RawSha256 $boundPath) -ceq [string]$binding.raw_sha256
    ) "$gateId pinned authority is missing or changed: $($binding.path)"
}

$bw7dPreregistration = Get-Content -Raw -LiteralPath (
    Join-Path $repoRoot "sdk\balanced_wave_bw7d_preregistration.json"
) | ConvertFrom-Json -AsHashtable
Assert-Exact (
    (@($bw7dPreregistration.cold_unbiased_friction_reservation.authored_friction_values) -join ",") -ceq
        $expectedValues -and
    (@($bw7dPreregistration.cold_unbiased_friction_reservation.campaign_seeds) -join ",") -ceq
        $expectedSeeds
) "$gateId initial BW7D cold reservation does not match"
foreach ($relativePath in @(
    "sdk/balanced_wave_bw7d_closure_manifest.json",
    "sdk/balanced_wave_bw8u_closure_manifest.json"
)) {
    $manifest = Get-Content -Raw -LiteralPath (Join-Path $repoRoot $relativePath) |
        ConvertFrom-Json -AsHashtable
    Assert-Exact (
        (@($manifest.unopened_reservations.cold_unbiased_authored_friction_values) -join ",") -ceq
            $expectedValues -and
        (@($manifest.unopened_reservations.cold_unbiased_campaign_seeds) -join ",") -ceq
            $expectedSeeds -and
        -not [bool]$manifest.unopened_reservations.locomotion_outcomes_exposed
    ) "$gateId unopened reservation continuity failed: $relativePath"
}
foreach ($relativePath in @(
    "sdk/balanced_wave_bw9l_closure_manifest.json",
    "sdk/balanced_wave_bw10f_closure_manifest.json",
    "sdk/balanced_wave_bw11r_closure_manifest.json",
    "sdk/balanced_wave_bw12e_closure_manifest.json"
)) {
    $manifest = Get-Content -Raw -LiteralPath (Join-Path $repoRoot $relativePath) |
        ConvertFrom-Json -AsHashtable
    Assert-Exact (
        (@($manifest.reservations.cold_friction_values) -join ",") -ceq
            $expectedValues -and
        (@($manifest.reservations.cold_friction_seeds) -join ",") -ceq
            $expectedSeeds -and
        -not [bool]$manifest.reservations.cold_friction_opened
    ) "$gateId unopened reservation continuity failed: $relativePath"
}

$bw5cPreregistration = Get-Content -Raw -LiteralPath (
    Join-Path $repoRoot "sdk\balanced_wave_bw5c_preregistration.json"
) | ConvertFrom-Json -AsHashtable
$bw5cCharacterization = $bw5cPreregistration.material_characterization
Assert-Exact (
    [string]$preregistration.numeric_threshold_provenance.kind -ceq
        "pinned_host_semantics_and_retained_operational_characterization_contract" -and
    -not [bool]$preregistration.numeric_threshold_provenance.new_outcomes_used_to_choose_thresholds -and
    [int]$characterization.replicate_count_per_value -eq
        [int]$bw5cCharacterization.replicate_count_per_value -and
    [int]$characterization.settle_ticks -eq [int]$bw5cCharacterization.settle_ticks -and
    [int]$characterization.force_stage_ticks -eq
        [int]$bw5cCharacterization.force_stage_ticks -and
    [int]$characterization.analysis_ticks_per_stage -eq
        [int]$bw5cCharacterization.analysis_ticks_per_stage -and
    (@($characterization.force_stages_n.tail_n) -join ",") -ceq
        (@($bw5cCharacterization.force_stages_n.tail_n) -join ",") -and
    [double]$characterization.maximum_holding_speed_m_s -eq
        [double]$bw5cCharacterization.maximum_holding_speed_m_s -and
    [double]$characterization.maximum_holding_displacement_m -eq
        [double]$bw5cCharacterization.maximum_holding_displacement_m -and
    [double]$characterization.minimum_sliding_speed_m_s -eq
        [double]$bw5cCharacterization.minimum_sliding_speed_m_s -and
    [double]$characterization.minimum_sliding_displacement_m -eq
        [double]$bw5cCharacterization.minimum_sliding_displacement_m -and
    [double]$characterization.maximum_breakaway_bracket_width_n -eq
        [double]$bw5cCharacterization.maximum_breakaway_bracket_width_n -and
    [double]$characterization.maximum_first_sliding_force_spread_n -eq
        [double]$bw5cCharacterization.maximum_first_sliding_force_spread_n -and
    [double]$characterization.maximum_lower_breakaway_force_spread_n -eq
        [double]$bw5cCharacterization.maximum_lower_breakaway_force_spread_n -and
    [double]$characterization.maximum_monotonic_force_decrease_n -eq
        [double]$bw5cCharacterization.maximum_monotonic_force_decrease_n -and
    [double]$characterization.maximum_monotonic_ratio_decrease -eq
        [double]$bw5cCharacterization.maximum_monotonic_ratio_decrease -and
    [double]$characterization.maximum_sliding_tilt_rad -eq
        [double]$bw5cCharacterization.maximum_sliding_tilt_rad -and
    [string]$characterization.controller_coefficient_derivation -ceq
        [string]$bw5cCharacterization.controller_coefficient_derivation
) "$gateId operational thresholds are not inherited byte-for-value from BW5C"

$reference = (
    $preregistration.numeric_threshold_provenance.accepted_reference_manifest
)
$referencePath = [System.IO.Path]::GetFullPath(
    [string]$reference.retained_characterization_report
)
Assert-Exact (
    (Test-Path -LiteralPath $referencePath -PathType Leaf) -and
    (Get-RawSha256 $referencePath) -ceq
        [string]$reference.retained_characterization_sha256
) "$gateId retained BW5C threshold-provenance report is missing or changed"
$referenceReport = Get-Content -Raw -LiteralPath $referencePath |
    ConvertFrom-Json -AsHashtable
Assert-Exact (
    [bool]$referenceReport.accepted -and
    [int]$referenceReport.receipt.observed_world_count -eq 13 -and
    [int]$referenceReport.receipt.passed_gate_count -eq 23 -and
    [int]$referenceReport.receipt.failed_gate_count -eq 0 -and
    [string]$referenceReport.receipt.fixture.fixture_id -ceq
        "SDK.BW5C.godot_jolt_material_sled.v1" -and
    -not [bool]$referenceReport.receipt.material_robustness -and
    -not [bool]$referenceReport.receipt.physical_acceptance_authority
) "$gateId retained BW5C reference does not support the inherited contract"

Assert-Exact (
    [string]$characterization.adapter_id -ceq "godot_jolt_gdextension_v1" -and
    [string]$characterization.physics_engine -ceq "Jolt Physics" -and
    (@($characterization.authored_friction_values) -join ",") -ceq
        $expectedValues -and
    [double]$characterization.frictionless_control_value -eq 0.0 -and
    [int]$characterization.replicate_count_per_value -eq 3 -and
    [int]$characterization.frictionless_control_world_count -eq 1 -and
    [int]$characterization.expected_world_count -eq 13 -and
    [int]$characterization.expected_gate_count -eq 23 -and
    [bool]$characterization.characterization_may_not_run_locomotion -and
    [bool]$characterization.characterization_result_may_only_authorize_profile_publication -and
    -not [bool]$characterization.steady_velocity_claim -and
    -not [bool]$characterization.kinetic_friction_coefficient_claim -and
    -not [bool]$characterization.cross_engine_equivalence -and
    -not [bool]$characterization.locomotion_robustness -and
    [bool]$characterization.selective_replicate_rerun_forbidden -and
    [bool]$characterization.failed_cell_replacement_forbidden -and
    [bool]$characterization.averaging_forbidden -and
    [bool]$characterization.post_result_gate_edit_forbidden
) "$gateId finite matrix, immutability, or characterization claim changed"

Assert-Exact (
    [string]$future.study_classification -ceq
        "exact_finite_cell_material_acceptance_decision" -and
    -not [bool]$future.population_inference -and
    -not [bool]$future.superiority_study -and
    -not [bool]$future.noninferiority_or_equivalence_study -and
    (@($future.authored_friction_values) -join ",") -ceq $expectedValues -and
    (@($future.seeds) -join ",") -ceq $expectedSeeds -and
    [string]$future.treatment_candidate_id -ceq "BW19V-B" -and
    [double]$future.treatment_global_requested_correction_scale -eq 0.5 -and
    [string]$future.control_candidate_id -ceq "BW19V-A" -and
    [double]$future.control_global_requested_correction_scale -eq 0.0 -and
    [int]$future.expected_treatment_world_count -eq 12 -and
    [int]$future.expected_control_world_count -eq 4 -and
    [int]$future.expected_zero_friction_safety_world_count -eq 1 -and
    [int]$future.expected_world_count -eq 17 -and
    [int]$future.treatment_expected_nonzero_application_world_count -eq 12 -and
    [int]$future.control_expected_nonzero_application_world_count -eq 0 -and
    [bool]$future.all_treatments_must_pass_ordinary_production_walking_gates -and
    [bool]$future.controls_are_integrity_and_mechanism_controls_not_comparative_estimators -and
    [bool]$future.treatment_need_not_outperform_control_for_this_finite_acceptance_decision
) "$gateId future policy-relative finite matrix or inference boundary changed"

foreach ($claimName in @(
    "walking_acceptance",
    "bw19v_b_material_robustness",
    "continuous_friction_coverage",
    "arbitrary_material_robustness",
    "population_inference",
    "cross_engine_equivalence",
    "release_authorized",
    "physical_acceptance_authority",
    "completed_engine_neutral_sdk"
)) {
    Assert-Exact (
        -not [bool]$claims[$claimName]
    ) "$gateId prospective claim inflated: $claimName"
}

$supervisorSource = Get-Content -Raw -LiteralPath $supervisorPath
$genericRunnerSource = Get-Content -Raw -LiteralPath $genericRunnerPath
$productionGateSource = Get-Content -Raw -LiteralPath (
    Join-Path $sdkRoot "balanced_wave_bw20f_material_characterization_gate.ps1"
)
$fixtureSource = Get-Content -Raw -LiteralPath (
    Join-Path $repoRoot "scripts\lab\rigs\sdk_friction_ladder_sled_rig.gd"
)
$physicalHarnessSource = Get-Content -Raw -LiteralPath (
    Join-Path $repoRoot "tests\test_sdk_godot_jolt_friction_ladder_characterization.gd"
)
$preflightSource = Get-Content -Raw -LiteralPath (
    Join-Path $repoRoot "tests\test_sdk_balanced_wave_bw20f_material_characterization_preflight.gd"
)
Assert-SourceContains $supervisorSource @(
    '[bool]$PreflightOnly -xor [bool]$RunPhysical',
    'status --porcelain=v1 --untracked-files=all',
    'ls-remote origin refs/heads/main',
    'HEAD equal to live GitHub main',
    'SporeSpore_Evidence',
    'C:\tmp\',
    'physical_process_launch_reserved_identity_consumed',
    'same_identity_rerun_allowed = $false',
    '-SkipSupervisorPreflight',
    '-Bw20fSupervisorAuthorized',
    '-Bw20fSupervisorAttempt $attemptPath',
    'world_build_count = 0',
    'locomotion_seed_world_count = 0'
) "supervisor"
Assert-SourceContains $genericRunnerSource @(
    'if ($isBw20f -and -not $Bw20fSupervisorAuthorized)',
    'BW20F physical characterization requires its campaign supervisor',
    'BW20F preflight is owned by the complete campaign supervisor',
    "BW20F worker requires the supervisor's durable attempt receipt",
    'BW20F worker requires the exact sibling supervisor attempt receipt',
    'BW20F requires clean, pushed source distinct from its parent',
    'godot_executable_sha256',
    'retained threshold-provenance report',
    'Test-Bw20fMaterialCharacterizationReceipt'
) "physical runner"
Assert-SourceContains $productionGateSource @(
    'Bw20fGodotExecutableSha256',
    'BW20F_ENGINE_IDENTITY',
    'BW20F_INVALID_VALUE_CONTROL',
    'BW20F_REPLICATE_GATE',
    'BW20F_COEFFICIENT_DERIVATION',
    'BW20F_MONOTONICITY',
    'BW20F_CLAIM_INFLATION'
) "production gate"
Assert-SourceContains $fixtureSource @(
    'BW20F_FIXTURE_ID',
    'BW20F_AUTHORED_FRICTION_VALUES := [0.0, 0.09, 0.37, 0.76, 1.18]',
    'SDK_FRICTION_LADDER_VALUE_INVALID',
    'godot_pair_rule',
    'portable_material_coefficient'
) "fixture"
Assert-SourceContains $physicalHarnessSource @(
    '_bw20f_mode',
    '"--bw20f"',
    'observer_profile_executable',
    'invalid_value_control',
    'physical_acceptance_authority'
) "physical harness"
Assert-SourceContains $preflightSource @(
    'world_build_count',
    'scene_tree_insertion_count',
    'physics_state_mutation_count',
    'characterization_outcome_exposed',
    'physical_acceptance_authority'
) "fixture preflight"

$evidenceRoot = [System.IO.Path]::GetFullPath(
    (Join-Path (Split-Path -Parent $repoRoot) "SporeSpore_Evidence")
)
$priorAttempts = @()
if (Test-Path -LiteralPath $evidenceRoot -PathType Container) {
    $priorAttempts = @(
        Get-ChildItem -LiteralPath $evidenceRoot -Recurse -File -Filter "attempt.json" |
        Where-Object {
            try {
                $attempt = Get-Content -Raw -LiteralPath $_.FullName |
                    ConvertFrom-Json
                [string]$attempt.campaign_id -ceq $campaignId
            } catch {
                $false
            }
        }
    )
}
Assert-Exact (
    $priorAttempts.Count -eq 0
) "$gateId already has a retained physical attempt and may not rerun"

& pwsh -NoProfile -File $bw19vClosureAuditPath
$bw19vAuditExitCode = $LASTEXITCODE
Assert-Exact (
    $bw19vAuditExitCode -eq 0
) "$gateId pinned BW19V closure audit failed"

$gateTestPath = Join-Path $repoRoot "tests\test_bw20f_material_characterization_gate.ps1"
& pwsh -NoProfile -File $gateTestPath
$gateTestExitCode = $LASTEXITCODE
Assert-Exact (
    $gateTestExitCode -eq 0
) "$gateId complete synthetic production-gate test failed"

Invoke-ExpectedFailure @(
    "-NoProfile",
    "-File", $supervisorPath,
    "-RunPhysical"
) "$gateId -RunPhysical requires an explicit durable OutputRoot" `
    "missing-output-root"
Invoke-ExpectedFailure @(
    "-NoProfile",
    "-File", $genericRunnerPath,
    "-Campaign", "BW20F"
) "BW20F physical characterization requires its campaign supervisor" `
    "direct-runner-bypass"
Invoke-ExpectedFailure @(
    "-NoProfile",
    "-File", $genericRunnerPath,
    "-Campaign", "BW20F",
    "-Bw20fSupervisorAuthorized"
) "BW20F worker requires the supervisor's durable attempt receipt" `
    "forged-supervisor-switch"

if (-not $SkipSupervisorPreflight) {
    & pwsh -NoProfile -File $supervisorPath -PreflightOnly
    $supervisorExitCode = $LASTEXITCODE
    Assert-Exact (
        $supervisorExitCode -eq 0
    ) "$gateId complete zero-world supervisor preflight failed"
}

Write-Host (
    "BW20F_MATERIAL_FREEZE_PASS class=finite_decision values=4 " +
    "locomotion_seeds_sealed=3 worlds=0 production_gates=23 " +
    "fixture_gates_declared=8 fixture_preflight_executed=" +
    "$(-not $SkipSupervisorPreflight) canaries=6 bypass_canaries=3 " +
    "host_pinned=True " +
    "physical_authority=False"
)
