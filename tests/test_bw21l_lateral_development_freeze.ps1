#requires -Version 7.0

[CmdletBinding()]
param(
    [switch]$SkipGodotExecution,
    [switch]$SkipSupervisorPreflight,
    [string]$Godot = (
        "C:\Users\Cole\CodeStuff\Misc\Godot\" +
        "Godot_v4.7-stable_mono_win64_console.exe"
    ),
    [string]$LogRoot = (
        Join-Path $env:TEMP "sporespore_bw21l_lateral_development_freeze"
    )
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [System.IO.Path]::GetFullPath(
    (Split-Path -Parent $PSScriptRoot)
)
$sdkRoot = Join-Path $repoRoot "sdk"
$campaignId = "BW21L-MATERIAL-LATERAL-DEVELOPMENT"
$gateId = "BW21L"
$implementationParentCommit = "611ab8c23ee621a2df0adbd423705ab6039a1a4c"
$preregistrationPath = Join-Path (
    $sdkRoot
) "balanced_wave_bw21l_lateral_development_preregistration.json"
$candidatesPath = Join-Path (
    $sdkRoot
) "balanced_wave_bw21l_lateral_development_candidates.json"
$productionGatePath = Join-Path (
    $sdkRoot
) "balanced_wave_bw21l_lateral_development_gate.ps1"
$gateTestPath = Join-Path $repoRoot "tests\test_bw21l_lateral_development_gate.ps1"
$authorityContractPath = Join-Path (
    $repoRoot
) "tests\test_sdk_balanced_wave_bw21l_authority_contract.gd"
$physicalHarnessPath = Join-Path (
    $repoRoot
) "tests\test_sdk_balanced_wave_bw21l_lateral_development.gd"
$supervisorPath = Join-Path (
    $sdkRoot
) "run_balanced_wave_bw21l_lateral_development.ps1"
$closurePath = Join-Path (
    $sdkRoot
) "balanced_wave_bw21l_lateral_development_closure.json"
$bw20fReportPath = [System.IO.Path]::GetFullPath(
    "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence\" +
    "balanced-wave-bw20f-material-locomotion-452c11d\report.json"
)
$frozenFiles = [ordered]@{
    "sdk/balanced_wave_bw21l_lateral_development_preregistration.json" =
        "f27b2fd29b81b8e661163f7b991417b7858631190cdeb866fc11437f024ab1da"
    "sdk/balanced_wave_bw21l_lateral_development_candidates.json" =
        "4cdb98b341a932ccd69d85839301b54d039e3680cd67a44baeea2b77136d913b"
    "sdk/balanced_wave_bw21l_lateral_development_gate.ps1" =
        "76b2d28e5b1ba815e2987f2b332566d8ac195141aa57ca1db767b8a9a62d8ccf"
    "tests/test_bw21l_lateral_development_gate.ps1" =
        "f93ed37123c2ab9a2304e0ed75373e973ca1397661a3c914f0c9a421d201d095"
    "tests/test_sdk_balanced_wave_bw21l_authority_contract.gd" =
        "5ad5000d0f713af65bc57bd4d8a8d2a11e0b794173a186c3b2babf18980501aa"
    "tests/test_sdk_balanced_wave_bw21l_lateral_development.gd" =
        "561b31f35b2eb19777289baab95ec699d7510f73a0f0538c01d700b09c9f782e"
    "sdk/run_balanced_wave_bw21l_lateral_development.ps1" =
        "ab39dd340c7779de1dbe0ab607ab920c7def42a339264fa8e6832dd87590298f"
    "scripts/lab/gait/physical_wave_gait_quadruped.gd" =
        "81170c35ddb12d582b71f19d865a45333ee6c21f57e72820bad1a5947c3ef82f"
    "scripts/lab/gait/sdk_godot_jolt_adapter.gd" =
        "3cf17ad6acaf791cc7bcc9c80d1e5d0f9e55749676f637da708080354241c0b3"
    "scripts/lab/gait/sdk_godot_jolt_material_profiles.gd" =
        "6344363c1218a85ffd5bed79b00e9615a74456f31787c2a8e5c48272e044255d"
    "scripts/lab/gait/physical_quadruped_fixture_spec.gd" =
        "6e005493982a55c113706101b1e4b3ab857473becbbea03ee48ba213b4d3b050"
    "scripts/lab/gait/physical_gait_clock_spec.gd" =
        "55a8495f16842808487eccdfbc6bd695ef385d807c2221ab5a9c01017ed137d3"
    "sdk/core/src/controller.rs" =
        "af5c48e2e38052012817c0a12ab848b5b3168b79386d5e8042192d61eee22eff"
    "sdk/core/src/runtime.rs" =
        "0eaeaea657510d4bcea47b61bf5d63be95500b70b6a02e208d02b5ae4559038a"
    "sdk/core/src/lib.rs" =
        "cb08220b80487e61b9188a25b0d1b2b5b9fffc82717d230f2b2ff7e4249d40e4"
    "tests/test_sdk_balanced_wave_bw20f_material_locomotion.gd" =
        "462f5bb05bf75dd437112da13e72692decd007f2edb9c6bf37b176394b0984d5"
    "tests/test_sdk_balanced_wave_bw19v_independent_validation.gd" =
        "4024bb8135c5f2b9feccc8c6501fdacfade8d63cfe382937dae4cae5c28ae7c6"
    "tests/test_sdk_qsdk_independent_morphology_v2.gd" =
        "3365582b076ccaedf2ec5a4562abed006f42a89af85be9193436f94e179ba90e"
    "sdk/balanced_wave_bw20f_material_locomotion_closure.json" =
        "bd18cd9a4905182673459b7b203ff7b7ae4cd5f954f00175f14fc721980bc1ef"
    "sdk/balanced_wave_bw19v_closure_manifest.json" =
        "ea8df6a574e1b9be1050afa8ed57982a102982ada0f0d5babccf3c937c7067f7"
}
$candidateIds = @("BW21L-A", "BW21L-B", "BW21L-C", "BW21L-D")
$policyIds = @(
    "sporespore_balanced_wave_bw15f_b_v1",
    "sporespore_balanced_wave_bw21l_b_v1",
    "sporespore_balanced_wave_bw21l_c_v1",
    "sporespore_balanced_wave_bw21l_d_v1"
)
$runtimeProfileDigests = @(
    "sha256:1134302a1566e12d1e1179beebed893176eeed88065920855026e903738bb413",
    "sha256:70b1b0c445bc8b53d94a09f70e18271b9727d9f41b772fa843ae9e59174af6f5",
    "sha256:53c443565996a1a7e7c749ca37c7530a99847d7c3a267a9dea83ee1c17926ff3",
    "sha256:9b558419c3b74218b26fa306407b6efb20a680c80059365a405c6fdb06642a59"
)
$compositionDigests = @(
    "sha256:2546cae8c4d3312b88289b80c65c0f6cf488c940576c6595c4975617814098d8",
    "sha256:7278c8ed0afbdd8124a51beef8ca8ca0b11731aafcfe5537051504cc9ee94d0f",
    "sha256:f494931c45fe792242556b78cd87b228dff1a1f2b2362674986979c6616e3853",
    "sha256:881cb65b226c5e0f934378db8ad556b2a95cbf87b7098cd868de6a3abe7ec8b3"
)
$profileTokens = @("009", "037", "076", "118")
$profileIds = @(
    "godot_jolt_bw20f_mu009_v1",
    "godot_jolt_bw20f_mu037_v1",
    "godot_jolt_bw20f_mu076_v1",
    "godot_jolt_bw20f_mu118_v1"
)
$seeds = @(23001, 23002, 23003)

function Assert-Exact {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function Get-RawSha256 {
    param([Parameter(Mandatory)][string]$Path)
    return (
        Get-FileHash -Algorithm SHA256 -LiteralPath $Path
    ).Hash.ToLowerInvariant()
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
    ) "$gateId $Label negative control did not fail closed"
}

Assert-Exact (
    -not ($SkipGodotExecution -and -not $SkipSupervisorPreflight)
) "$gateId -SkipGodotExecution requires -SkipSupervisorPreflight"

foreach ($entry in $frozenFiles.GetEnumerator()) {
    $path = Join-Path $repoRoot $entry.Key
    Assert-Exact (
        (Test-Path -LiteralPath $path -PathType Leaf) -and
        (Get-RawSha256 -Path $path) -ceq [string]$entry.Value
    ) "$gateId frozen source or prerequisite changed: $($entry.Key)"
}
Assert-Exact (
    (Test-Path -LiteralPath $bw20fReportPath -PathType Leaf) -and
    (Get-RawSha256 -Path $bw20fReportPath) -ceq
        "69400655be32d09404222a647601aa7a1a0856c5c4f3c0cd6a07dac3841caf03"
) "$gateId retained BW20F prerequisite report is missing or changed"
Assert-Exact (
    -not (Test-Path -LiteralPath $closurePath -PathType Leaf)
) "$gateId is already closed and is no longer prospective"

foreach ($scriptPath in @($productionGatePath, $gateTestPath, $supervisorPath)) {
    [void][scriptblock]::Create((Get-Content -Raw -LiteralPath $scriptPath))
}

$manifest = Get-Content -Raw -LiteralPath $preregistrationPath |
    ConvertFrom-Json -AsHashtable
$declaration = Get-Content -Raw -LiteralPath $candidatesPath |
    ConvertFrom-Json -AsHashtable
$study = $manifest.study_class
$factorial = $manifest.controller_factorial
$control = $manifest.policy_relative_control
$matrix = $manifest.matrix
$cells = @($matrix.ordered_cells)
$selector = $manifest.selection_contract
$gate = $manifest.gate_contract
$preflight = $manifest.preflight_contract
$interlocks = $manifest.staged_interlocks
$claims = $manifest.claims_before_and_after_development
$futureValidation = $manifest.future_validation_reservation

Assert-Exact (
    [string]$manifest.schema_version -ceq
        "sporespore_balanced_wave_bw21l_lateral_development_preregistration_v1" -and
    [string]$manifest.status -ceq
        "frozen_before_first_bw21l_lateral_development_world" -and
    [string]$manifest.campaign_id -ceq $campaignId -and
    [string]$manifest.gate_id -ceq $gateId -and
    [string]$manifest.implementation_parent_commit -ceq
        $implementationParentCommit -and
    [string]$study.classification -ceq
        "paired_outcome_exposed_finite_controller_development_screen" -and
    -not [bool]$study.finite_acceptance_decision -and
    [bool]$study.development_screen -and
    -not [bool]$study.population_inference -and
    -not [bool]$study.superiority_study -and
    -not [bool]$study.noninferiority_or_equivalence_study -and
    [bool]$study.development_selection_is_not_acceptance_or_promotion -and
    [bool]$study.fresh_independent_validation_identity_values_and_seeds_required_after_any_selection
) "$gateId identity or development-only study class changed"

Assert-Exact (
    [string]$declaration.schema_version -ceq
        "sporespore_balanced_wave_bw21l_lateral_development_candidates_v1" -and
    [string]$declaration.status -ceq
        "prospective_development_candidates_no_physical_authority" -and
    [string]$declaration.campaign_id -ceq $campaignId -and
    (@($declaration.candidate_order) -join "|") -ceq ($candidateIds -join "|") -and
    @($declaration.candidates).Count -eq 4
) "$gateId candidate declaration identity changed"
$proportionalFactors = @(1.0, 1.5, 1.0, 1.5)
$velocityFactors = @(1.0, 1.0, 2.0, 2.0)
for ($index = 0; $index -lt 4; $index += 1) {
    $candidate = @($declaration.candidates)[$index]
    Assert-Exact (
        [string]$candidate.candidate_id -ceq $candidateIds[$index] -and
        [string]$candidate.controller_policy_id -ceq $policyIds[$index] -and
        [string]$candidate.runtime_profile_sha256 -ceq $runtimeProfileDigests[$index] -and
        [double]$candidate.cross_track_proportional_factor -eq $proportionalFactors[$index] -and
        [double]$candidate.cross_track_velocity_factor -eq $velocityFactors[$index] -and
        [double]$candidate.global_requested_correction_scale -eq 0.5 -and
        [int]$candidate.morphology_condition_count -eq 0 -and
        [int]$candidate.material_condition_count -eq 0 -and
        [int]$candidate.seed_condition_count -eq 0 -and
        [int]$candidate.failure_identity_condition_count -eq 0 -and
        [int]$candidate.outcome_condition_count -eq 0 -and
        @($candidate.branch_surfaces).Count -eq 0 -and
        -not [bool]$candidate.physical_acceptance_authority
    ) "$gateId candidate $($candidateIds[$index]) composition changed"
}
Assert-Exact (
    [double]$control.global_requested_correction_scale -eq 0.0 -and
    -not [bool]$control.residual_application_expected -and
    [int]$control.sdk_effective_application_count_required -eq 0 -and
    [double]$control.maximum_absolute_applied_residual_velocity_rad_s_required -eq 0.0 -and
    [bool]$control.mechanism_gate_passed_required -and
    -not [bool]$control.combined_application_gate_passed_required -and
    [bool]$control.base_controller_motor_writes_required_positive -and
    [bool]$control.broad_base_controller_physical_influence_required -and
    -not [bool]$control.comparative_outcome_estimator
) "$gateId corrected policy-relative control semantics changed"

$expectedCellIds = [System.Collections.Generic.List[string]]::new()
foreach ($profileToken in $profileTokens) {
    foreach ($seed in $seeds) {
        foreach ($candidateId in $candidateIds) {
            $candidateToken = $candidateId.ToLowerInvariant().Replace("-", "_")
            $expectedCellIds.Add(
                "development_mu${profileToken}_s${seed}_${candidateToken}"
            )
        }
        if ($seed -eq 23001) {
            $expectedCellIds.Add("development_mu${profileToken}_s23001_control")
        }
    }
}
$expectedCellIds.Add("negative_mu000_s23001_safety")
Assert-Exact (
    $cells.Count -eq 53 -and
    [int]$matrix.candidate_world_count -eq 48 -and
    [int]$matrix.control_world_count -eq 4 -and
    [int]$matrix.safety_world_count -eq 1 -and
    [int]$matrix.expected_world_count -eq 53 -and
    (@($cells | ForEach-Object { [string]$_.cell_id }) -join "|") -ceq
        (@($expectedCellIds) -join "|") -and
    @($cells | Where-Object { [string]$_.role -ceq "candidate" }).Count -eq 48 -and
    @($cells | Where-Object { [string]$_.role -ceq "control" }).Count -eq 4 -and
    @($cells | Where-Object { [string]$_.role -ceq "safety" }).Count -eq 1
) "$gateId ordered matrix or role cardinality changed"

foreach ($cell in $cells) {
    $role = [string]$cell.role
    if ($role -ceq "candidate") {
        $candidateIndex = [Array]::IndexOf($candidateIds, [string]$cell.candidate_id)
        $profileIndex = [Array]::IndexOf($profileIds, [string]$cell.profile_id)
        Assert-Exact (
            $candidateIndex -ge 0 -and $profileIndex -ge 0 -and
            [string]$cell.controller_policy_id -ceq $policyIds[$candidateIndex] -and
            [string]$cell.runtime_profile_sha256 -ceq $runtimeProfileDigests[$candidateIndex] -and
            [string]$cell.candidate_composition_digest -ceq $compositionDigests[$candidateIndex] -and
            [double]$cell.global_requested_correction_scale -eq 0.5 -and
            [double]$cell.proportional_factor -eq $proportionalFactors[$candidateIndex] -and
            [double]$cell.velocity_factor -eq $velocityFactors[$candidateIndex]
        ) "$gateId candidate matrix binding changed: $($cell.cell_id)"
    } elseif ($role -ceq "control") {
        Assert-Exact (
            [string]$cell.candidate_id -ceq "BW21L-CONTROL" -and
            [double]$cell.global_requested_correction_scale -eq 0.0 -and
            [int]$cell.campaign_seed -eq 23001
        ) "$gateId control matrix binding changed: $($cell.cell_id)"
    } else {
        Assert-Exact (
            [string]$cell.cell_id -ceq "negative_mu000_s23001_safety" -and
            [string]$cell.profile_id -ceq "godot_jolt_p5m1r1_mu000_v1" -and
            [string]$cell.controller_policy_id -ceq "NONE"
        ) "$gateId safety matrix binding changed"
    }
}

Assert-Exact (
    [string]$selector.selection_mode -ceq
        "complete_preregistered_lexicographic_development_selection" -and
    [string]$selector.baseline_candidate_id -ceq "BW21L-A" -and
    (@($selector.selection_vector_in_priority_order) -join "|") -ceq (
        @(
            "walking_conjunction_failure_count",
            "aggregate_failed_production_walking_gate_count",
            "maximum_absolute_cross_track_error_m",
            "aggregate_cumulative_absolute_cross_track_error_m_s",
            "candidate_order"
        ) -join "|"
    ) -and
    [bool]$selector.selected_candidate_must_be_strictly_lexicographically_better_than_baseline -and
    [int]$selector.selected_candidate_paired_walking_gate_regression_count_must_equal -eq 0 -and
    [string]$selector.no_eligible_strict_improvement_selects -ceq "NONE" -and
    [bool]$selector.selection_is_development_hypothesis_only -and
    -not [bool]$selector.independent_validation_authority
) "$gateId selector or non-promotion boundary changed"
Assert-Exact (
    [int]$gate.expected_gate_count -eq 73 -and
    [int]$gate.pre_matrix_gate_count -eq 4 -and
    [int]$gate.per_world_execution_integrity_gate_count -eq 53 -and
    [int]$gate.aggregate_gate_count -eq 16 -and
    -not [bool]$gate.walking_success_required_for_every_candidate_cell -and
    [bool]$gate.development_result_may_validly_select_none -and
    [bool]$gate.outcome_based_early_stop_forbidden -and
    [bool]$gate.selective_cell_rerun_forbidden -and
    [bool]$gate.failed_cell_replacement_forbidden -and
    [bool]$gate.post_result_gate_edit_forbidden -and
    [bool]$gate.first_complete_result_is_final_for_this_source_identity
) "$gateId gate counts or completion rules changed"
Assert-Exact (
    [bool]$preflight.production_evaluator_must_accept_a_perfect_serialized_53_cell_result -and
    [bool]$preflight.complete_gate_must_run_before_attempt_receipt_and_before_first_world -and
    [bool]$preflight.real_adapter_entrypoint_must_preflight_all_53_cells_without_worlds -and
    [bool]$preflight.candidate_authority_contract_must_pass_without_worlds -and
    [bool]$preflight.valid_supervisor_authorization_must_pass_without_worlds -and
    [int]$preflight.world_build_count -eq 0 -and
    [int]$preflight.scene_tree_insertion_count -eq 0 -and
    [int]$preflight.physics_state_mutation_count -eq 0 -and
    -not [bool]$preflight.locomotion_outcome_exposed -and
    -not [bool]$preflight.physical_acceptance_authority -and
    [bool]$interlocks.physical_run_requires_clean_pushed_source_matching_live_github_main -and
    [bool]$interlocks.attempt_receipt_must_be_written_before_first_physical_process -and
    [bool]$interlocks.attempt_receipt_must_mark_source_identity_consumed_before_first_physical_process -and
    [bool]$interlocks.each_world_runs_in_a_fresh_isolated_process -and
    [bool]$interlocks.all_fifty_three_cell_attempts_are_retained_even_if_a_cell_fails -and
    -not [bool]$interlocks.same_identity_rerun_allowed
) "$gateId whole-gate preflight or one-shot interlock changed"
foreach ($claimName in $claims.Keys) {
    Assert-Exact (
        -not [bool]$claims[$claimName]
    ) "$gateId prospective claim inflated: $claimName"
}
Assert-Exact (
    [bool]$futureValidation.required_if_a_development_candidate_is_selected -and
    [bool]$futureValidation.new_campaign_id_required -and
    [bool]$futureValidation.new_source_identity_required -and
    [bool]$futureValidation.new_preregistration_required -and
    [bool]$futureValidation.fresh_unexposed_material_values_required -and
    [bool]$futureValidation.fresh_unexposed_seeds_required -and
    [bool]$futureValidation.independent_validation_may_not_reuse_bw20f_or_bw21l_outcomes_for_thresholds_or_selection -and
    [bool]$futureValidation.development_selector_may_not_be_reinterpreted_as_validation
) "$gateId fresh independent validation reservation changed"

$gateSource = Get-Content -Raw -LiteralPath $productionGatePath
$harnessSource = Get-Content -Raw -LiteralPath $physicalHarnessPath
$supervisorSource = Get-Content -Raw -LiteralPath $supervisorPath
Assert-SourceContains $gateSource @(
    "function Test-Bw21lLateralDevelopmentResult",
    "function New-Bw21lPerfectSyntheticLateralDevelopmentResult",
    "expected_gate_count = 73",
    "complete_preregistered_lexicographic_development_selection",
    'independent_validation_authority = $false',
    'physical_acceptance_authority = $false'
) "production evaluator"
Assert-SourceContains $harnessSource @(
    'extends "res://tests/test_sdk_balanced_wave_bw20f_material_locomotion.gd"',
    "func _run_bw21l_entrypoint_preflight",
    "func _run_bw21l_authorization_preflight",
    "func _physical_authorization_exact",
    'and bool(attempt.get("physical_identity_consumed", false))',
    '"actual_world_build_count": 0',
    '"locomotion_outcome_exposed": false'
) "physical harness"
Assert-SourceContains $supervisorSource @(
    '[bool]$PreflightOnly -xor [bool]$RunPhysical',
    '$gateId -RunPhysical requires an explicit durable OutputRoot',
    "status --porcelain=v1 --untracked-files=all",
    "ls-remote origin refs/heads/main",
    "requires clean source with HEAD equal to live GitHub main",
    'physical_identity_consumed = $true',
    '"authorization_preflight"',
    'for ($index = 0; $index -lt $cells.Count; $index += 1)',
    "Test-Bw21lLateralDevelopmentResult -Result `$rawResult",
    "first complete physical result was retained but failed its integrity gate"
) "physical supervisor"

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
            } catch { $false }
        }
    )
}
Assert-Exact (
    $priorAttempts.Count -eq 0
) "$gateId prior physical attempt exists; prospective freeze is invalid"

& pwsh -NoProfile -File $gateTestPath
Assert-Exact (
    $LASTEXITCODE -eq 0
) "$gateId complete production evaluator and canary test failed"

Invoke-ExpectedFailure `
    -Arguments @("-NoProfile", "-File", $supervisorPath, "-RunPhysical") `
    -ExpectedText "$gateId -RunPhysical requires an explicit durable OutputRoot" `
    -Label "missing durable output root"

if (-not $SkipSupervisorPreflight) {
    & pwsh `
        -NoProfile `
        -File $supervisorPath `
        -PreflightOnly `
        -Godot $Godot `
        -LogRoot (Join-Path $LogRoot "supervisor")
    Assert-Exact (
        $LASTEXITCODE -eq 0
    ) "$gateId supervisor whole-gate preflight failed"
}

$bypassCanaryCount = 1
if (-not $SkipGodotExecution) {
    $godotPath = [System.IO.Path]::GetFullPath($Godot)
    Assert-Exact (
        (Test-Path -LiteralPath $godotPath -PathType Leaf) -and
        (Get-RawSha256 -Path $godotPath) -ceq
            "c5fc2d0bb24826a6757fa1e6bf2991effb294859c7dd03d09a122ef217484896"
    ) "$gateId pinned Godot executable changed"
    $projectRoot = Join-Path (
        [System.IO.Path]::GetFullPath($LogRoot)
    ) ("bypass-project-" + [Guid]::NewGuid().ToString("N"))
    [void][System.IO.Directory]::CreateDirectory($projectRoot)
    foreach ($directory in @("scripts", "tests", "sdk")) {
        [void](New-Item `
            -ItemType Junction `
            -Path (Join-Path $projectRoot $directory) `
            -Target (Join-Path $repoRoot $directory))
    }
    $projectText = @"
config_version=5
[application]
config/name="sporespore-bw21l-lateral-development-bypass-canary"
config/features=PackedStringArray("4.7", "Forward Plus")
[debug]
gdscript/warnings/shadowed_global_identifier=0
[physics]
3d/physics_engine="Jolt Physics"
jolt_physics_3d/simulation/velocity_steps=20
jolt_physics_3d/simulation/position_steps=7
"@
    [System.IO.File]::WriteAllText(
        (Join-Path $projectRoot "project.godot"),
        $projectText,
        [System.Text.UTF8Encoding]::new($false)
    )
    $cellId = [string]$expectedCellIds[0]
    $previousAttempt = $env:SPORESPORE_BW21L_ATTEMPT
    $previousToken = $env:SPORESPORE_BW21L_TOKEN
    $previousCell = $env:SPORESPORE_BW21L_CELL
    try {
        Remove-Item Env:SPORESPORE_BW21L_ATTEMPT -ErrorAction SilentlyContinue
        Remove-Item Env:SPORESPORE_BW21L_TOKEN -ErrorAction SilentlyContinue
        Remove-Item Env:SPORESPORE_BW21L_CELL -ErrorAction SilentlyContinue
        $directOutput = (& $godotPath `
            --headless `
            --path $projectRoot `
            --script "res://tests/test_sdk_balanced_wave_bw21l_lateral_development.gd" `
            -- physical $cellId 2>&1 | Out-String)
        $directExitCode = $LASTEXITCODE
        Assert-Exact (
            $directExitCode -ne 0 -and
            $directOutput.Contains(
                "physical entry requires exact retained supervisor authorization",
                [StringComparison]::Ordinal
            ) -and
            -not $directOutput.Contains(
                "BW21L_LATERAL_DEVELOPMENT_CELL ",
                [StringComparison]::Ordinal
            )
        ) "$gateId direct physical-worker bypass did not fail before a world"
        $bypassCanaryCount += 1

        $env:SPORESPORE_BW21L_ATTEMPT = Join-Path $projectRoot "missing-attempt.json"
        $env:SPORESPORE_BW21L_TOKEN = "forged"
        $env:SPORESPORE_BW21L_CELL = $cellId
        $forgedOutput = (& $godotPath `
            --headless `
            --path $projectRoot `
            --script "res://tests/test_sdk_balanced_wave_bw21l_lateral_development.gd" `
            -- physical $cellId 2>&1 | Out-String)
        $forgedExitCode = $LASTEXITCODE
        Assert-Exact (
            $forgedExitCode -ne 0 -and
            $forgedOutput.Contains(
                "physical entry requires exact retained supervisor authorization",
                [StringComparison]::Ordinal
            ) -and
            -not $forgedOutput.Contains(
                "BW21L_LATERAL_DEVELOPMENT_CELL ",
                [StringComparison]::Ordinal
            )
        ) "$gateId forged physical-worker authorization did not fail before a world"
        $bypassCanaryCount += 1

        $unconsumedToken = [Guid]::NewGuid().ToString("N")
        $unconsumedPath = Join-Path $projectRoot "unconsumed-attempt.json"
        $unconsumedAttempt = [ordered]@{
            schema_version = "sporespore_balanced_wave_bw21l_lateral_development_attempt_v1"
            campaign_id = $campaignId
            gate_id = $gateId
            authorization_token = $unconsumedToken
            source_commit = ("0" * 40)
            source_worktree_clean = $true
            source_matches_live_github_main = $true
            complete_zero_world_gate_passed = $true
            authority_contract_passed = $true
            expected_world_count = 53
            ordered_cell_ids = @($expectedCellIds)
            physical_identity_consumed = $false
            same_identity_rerun_allowed = $false
        }
        [System.IO.File]::WriteAllText(
            $unconsumedPath,
            (($unconsumedAttempt | ConvertTo-Json -Depth 16) + [Environment]::NewLine),
            [System.Text.UTF8Encoding]::new($false)
        )
        $env:SPORESPORE_BW21L_ATTEMPT = $unconsumedPath
        $env:SPORESPORE_BW21L_TOKEN = $unconsumedToken
        $unconsumedOutput = (& $godotPath `
            --headless `
            --path $projectRoot `
            --script "res://tests/test_sdk_balanced_wave_bw21l_lateral_development.gd" `
            -- authorization_preflight $cellId 2>&1 | Out-String)
        $unconsumedExitCode = $LASTEXITCODE
        Assert-Exact (
            $unconsumedExitCode -ne 0 -and
            $unconsumedOutput.Contains(
                '"authorization_exact":false',
                [StringComparison]::Ordinal
            ) -and
            $unconsumedOutput.Contains(
                '"actual_world_build_count":0',
                [StringComparison]::Ordinal
            )
        ) "$gateId unconsumed source identity was not rejected without a world"
        $bypassCanaryCount += 1
    } finally {
        if ($null -eq $previousAttempt) {
            Remove-Item Env:SPORESPORE_BW21L_ATTEMPT -ErrorAction SilentlyContinue
        } else { $env:SPORESPORE_BW21L_ATTEMPT = $previousAttempt }
        if ($null -eq $previousToken) {
            Remove-Item Env:SPORESPORE_BW21L_TOKEN -ErrorAction SilentlyContinue
        } else { $env:SPORESPORE_BW21L_TOKEN = $previousToken }
        if ($null -eq $previousCell) {
            Remove-Item Env:SPORESPORE_BW21L_CELL -ErrorAction SilentlyContinue
        } else { $env:SPORESPORE_BW21L_CELL = $previousCell }
    }
}

Write-Host (
    "$gateId LATERAL_DEVELOPMENT_FREEZE_PASS worlds=0 production_gates=73 " +
    "cells=53 candidates=48 controls=4 safety=1 profiles=4 seeds=3 " +
    "canaries=18 authorization=1/1 bypass_canaries=$bypassCanaryCount " +
    "development_only=True validation_authority=False physical_authority=False"
)
