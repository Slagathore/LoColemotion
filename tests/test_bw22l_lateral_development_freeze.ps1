#requires -Version 7.0

[CmdletBinding()]
param(
    [switch]$SkipSupervisorPreflight,
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
$sdkRoot = Join-Path $repoRoot "sdk"
$evidenceRoot = [System.IO.Path]::GetFullPath(
    (Join-Path (Split-Path -Parent $repoRoot) "SporeSpore_Evidence")
)
$campaignId = "BW22L-FRESH-MATERIAL-LATERAL-DEVELOPMENT"
$gateId = "BW22L"
$freezePath = Join-Path (
    $sdkRoot
) "balanced_wave_bw22l_lateral_development_freeze.json"
$supervisorPath = Join-Path (
    $sdkRoot
) "run_balanced_wave_bw22l_lateral_development.ps1"
$workerPath = Join-Path (
    $repoRoot
) "tests\test_sdk_balanced_wave_bw22l_lateral_development.gd"
$receiptCompositionPath = Join-Path (
    $repoRoot
) "tests\test_sdk_balanced_wave_bw22l_policy_receipt_composition.gd"
$gateTestPath = Join-Path (
    $repoRoot
) "tests\test_bw22l_lateral_development_gate.ps1"
$conformancePath = Join-Path $sdkRoot "run_conformance.ps1"
$closurePath = Join-Path (
    $sdkRoot
) "balanced_wave_bw22l_lateral_development_closure.json"
$expectedFreezeSha256 = (
    "e492cf752dcd2aa2f7a1c00ca84bb2eb3114fc027914efb2770a9611f2a52965"
)

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

function Assert-SourceContains {
    param(
        [Parameter(Mandatory)][string]$Source,
        [Parameter(Mandatory)][string[]]$Needles,
        [Parameter(Mandatory)][string]$Label
    )
    foreach ($needle in $Needles) {
        Assert-Exact (
            $Source.Contains($needle, [StringComparison]::Ordinal)
        ) "$gateId $Label lost required text: $needle"
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
    ) "$gateId $Label did not fail closed"
}

Assert-Exact (
    (Test-Path -LiteralPath $freezePath -PathType Leaf) -and
    (Get-RawSha256 -Path $freezePath) -ceq $expectedFreezeSha256
) "$gateId freeze declaration is missing or changed"
Assert-Exact (
    -not (Test-Path -LiteralPath $closurePath -PathType Leaf)
) "$gateId already has a closure and is not a prospective freeze"

$freeze = Get-Content -Raw -LiteralPath $freezePath |
    ConvertFrom-Json -AsHashtable
$witness = $freeze.stage_zero_conformance_witness
$study = $freeze.study_class
$matrix = $freeze.physical_matrix
$gate = $freeze.gate_contract
$corrections = @($freeze.prospective_prephysical_corrections)
$preflight = $freeze.zero_world_authorization_preflight
$execution = $freeze.one_shot_execution_contract
$claims = $freeze.claims_before_physical_execution
$ceiling = $freeze.claim_ceiling_after_valid_complete_development_result
$externalEvidence = $freeze.external_evidence_bindings
$bindings = $freeze.source_bindings

Assert-Exact (
    [string]$freeze.schema_version -ceq
        "sporespore_balanced_wave_bw22l_lateral_development_freeze_v1" -and
    [string]$freeze.status -ceq
        "frozen_before_first_bw22l_physical_world" -and
    [string]$freeze.campaign_id -ceq $campaignId -and
    [string]$freeze.gate_id -ceq $gateId -and
    [string]$freeze.freeze_parent_commit -ceq
        "3693e919000c5d607dc8463d2311b01281640ede" -and
    [string]$witness.source_commit -ceq
        "38c6a52007db4e57d6d7edd65dca0ca09ca34cc2" -and
    [bool]$witness.source_was_clean_and_pushed -and
    [bool]$witness.head_equaled_origin_main_and_live_github_main -and
    [bool]$witness.godot_included -and
    [int]$witness.exit_code -eq 0 -and
    [double]$witness.duration_seconds -eq 672.0 -and
    [int]$witness.physical_world_count -eq 0 -and
    -not [bool]$witness.locomotion_outcome_exposed
) "$gateId freeze identity or stage-zero conformance witness changed"

Assert-Exact (
    [string]$study.classification -ceq
        "paired_outcome_exposed_finite_controller_development_screen" -and
    [int]$study.candidate_count -eq 2 -and
    [string]$study.baseline_candidate_id -ceq "BW22L-A" -and
    [string]$study.successor_candidate_id -ceq "BW22L-B" -and
    [bool]$study.development_screen -and
    -not [bool]$study.finite_acceptance_decision -and
    -not [bool]$study.population_inference -and
    -not [bool]$study.superiority_study -and
    -not [bool]$study.noninferiority_or_equivalence_study -and
    [bool]$study.selection_is_hypothesis_generation_only -and
    [bool]$study.fresh_independent_validation_required_after_non_none_selection
) "$gateId finite development-only study class changed"

Assert-Exact (
    (@($matrix.authored_friction_values) -join ",") -ceq "0.57,0.69,0.81" -and
    (@($matrix.campaign_seeds) -join ",") -ceq "24011,24012,24013,24014" -and
    [int]$matrix.candidate_world_count -eq 24 -and
    [int]$matrix.control_world_count -eq 3 -and
    [int]$matrix.safety_world_count -eq 1 -and
    [int]$matrix.expected_world_count -eq 28 -and
    [int]$matrix.physical_world_count_at_freeze -eq 0 -and
    [int]$matrix.selector_invocation_count_at_freeze -eq 0 -and
    [int]$matrix.candidate_outcome_count_at_freeze -eq 0 -and
    [bool]$matrix.first_complete_result_final_for_source_identity -and
    [int]$gate.expected_gate_count -eq 50 -and
    [int]$gate.pre_matrix_gate_count -eq 4 -and
    [int]$gate.per_world_gate_count -eq 28 -and
    [int]$gate.aggregate_gate_count -eq 18 -and
    [bool]$gate.perfect_serialized_result_passes -and
    [bool]$gate.valid_result_may_select_none -and
    [bool]$gate.selected_candidate_must_be_strictly_lexicographically_better_than_baseline -and
    [int]$gate.selected_candidate_paired_walking_gate_regression_count_must_equal -eq 0 -and
    [bool]$gate.outcome_based_early_stop_forbidden -and
    [bool]$gate.selective_cell_rerun_forbidden -and
    [bool]$gate.failed_cell_replacement_forbidden -and
    [bool]$gate.post_result_gate_edit_forbidden
) "$gateId matrix, selector, or gate contract changed"

Assert-Exact (
    $corrections.Count -eq 3 -and
    @($corrections | Where-Object {
        -not [bool]$_.detected_before_any_physical_world -or
        -not [bool]$_.detected_before_any_locomotion_outcome -or
        [bool]$_.threshold_value_seed_or_selector_changed -or
        [bool]$_.post_result_edit
    }).Count -eq 0 -and
    @($corrections | Where-Object {
        [string]$_.issue -match "dropped policy_relative_common_execution"
    }).Count -eq 1
) "$gateId prospective correction history changed or became post-result"

Assert-Exact (
    [int]$preflight.production_gate_count -eq 50 -and
    [int]$preflight.production_evaluator_negative_canary_count -eq 23 -and
    [int]$preflight.candidate_authority_check_count -eq 11 -and
    [int]$preflight.worker_entrypoint_count -eq 28 -and
    [int]$preflight.adapter_start_count -eq 27 -and
    [int]$preflight.policy_receipt_perfect_summary_count -eq 3 -and
    [int]$preflight.policy_receipt_negative_canary_count -eq 4 -and
    [int]$preflight.authorization_receipt_canary_count -eq 1 -and
    [int]$preflight.direct_worker_bypass_canary_count -eq 1 -and
    [bool]$preflight.perfect_synthetic_report_passes_complete_gate -and
    [bool]$preflight.exact_final_wrapper_policy_receipt_composition_passes -and
    [bool]$preflight.candidate_authority_contract_passes -and
    [bool]$preflight.real_worker_entrypoints_all_pass_without_worlds -and
    [bool]$preflight.valid_supervisor_authorization_passes_without_worlds -and
    [bool]$preflight.direct_physical_worker_bypass_fails_before_world -and
    [int]$preflight.world_build_count -eq 0 -and
    [int]$preflight.scene_tree_insertion_count -eq 0 -and
    [int]$preflight.physics_state_mutation_count -eq 0 -and
    -not [bool]$preflight.locomotion_outcome_exposed -and
    -not [bool]$preflight.validation_authority -and
    -not [bool]$preflight.physical_acceptance_authority
) "$gateId complete zero-world preflight contract changed"

Assert-Exact (
    [bool]$execution.only_complete_supervisor_may_open_physical_worlds -and
    [bool]$execution.worker_requires_exact_retained_attempt_and_matching_authorization_token -and
    [bool]$execution.worker_token_supplied_only_after_attempt_receipt_is_durably_created -and
    [bool]$execution.output_root_must_be_new_durable_and_inside_sporespore_evidence -and
    [bool]$execution.output_root_leaf_must_equal_campaign_slug_plus_source_commit_prefix -and
    [bool]$execution.retained_output_forbidden_under_temp -and
    [bool]$execution.head_must_equal_origin_main_and_live_github_main -and
    [bool]$execution.worktree_must_be_clean -and
    [bool]$execution.prior_attempt_count_must_be_zero -and
    [bool]$execution.attempt_receipt_written_and_identity_consumed_before_first_world -and
    [bool]$execution.each_world_runs_in_a_fresh_isolated_process -and
    [bool]$execution.all_twenty_eight_cells_attempted_even_after_cell_failure -and
    [bool]$execution.first_complete_result_final_for_source_identity -and
    [bool]$execution.incomplete_attempt_cannot_resume_in_place -and
    [bool]$execution.selective_cell_rerun_forbidden -and
    [bool]$execution.failed_cell_replacement_forbidden -and
    [bool]$execution.averaging_forbidden -and
    [bool]$execution.post_result_gate_edit_forbidden -and
    -not [bool]$execution.same_identity_rerun_allowed -and
    [bool]$execution.physical_execution_may_be_authorized_once_after_clean_pushed_full_conformance
) "$gateId one-shot execution contract changed"

foreach ($claimName in @($claims.Keys)) {
    Assert-Exact (
        -not [bool]$claims[$claimName]
    ) "$gateId prephysical claim inflated: $claimName"
}
Assert-Exact (
    [bool]$ceiling.exact_finite_development_result_complete -and
    [bool]$ceiling.development_hypothesis_selected_only_if_selector_returns_non_none
) "$gateId finite development claim ceiling changed"
foreach ($claimName in @($ceiling.Keys | Where-Object {
    $_ -notin @(
        "exact_finite_development_result_complete",
        "development_hypothesis_selected_only_if_selector_returns_non_none"
    )
})) {
    Assert-Exact (
        -not [bool]$ceiling[$claimName]
    ) "$gateId post-development claim ceiling inflated: $claimName"
}

Assert-Exact ($bindings.Count -eq 35) (
    "$gateId source-binding cardinality changed"
)
foreach ($binding in $bindings.GetEnumerator()) {
    $relativePath = [string]$binding.Value.path
    $expectedSha256 = [string]$binding.Value.raw_sha256
    $absolutePath = Join-Path $repoRoot $relativePath
    Assert-Exact (
        $expectedSha256 -cmatch "^[0-9a-f]{64}$" -and
        (Test-Path -LiteralPath $absolutePath -PathType Leaf) -and
        (Get-RawSha256 -Path $absolutePath) -ceq $expectedSha256
    ) "$gateId frozen source is missing or changed: $relativePath"
}
Assert-Exact ($externalEvidence.Count -eq 2) (
    "$gateId external evidence-binding cardinality changed"
)
foreach ($binding in $externalEvidence.GetEnumerator()) {
    $absolutePath = [System.IO.Path]::GetFullPath(
        [string]$binding.Value.path
    )
    Assert-Exact (
        (Test-Path -LiteralPath $absolutePath -PathType Leaf) -and
        (Get-RawSha256 -Path $absolutePath) -ceq
            [string]$binding.Value.raw_sha256
    ) "$gateId retained external prerequisite changed: $absolutePath"
}

& git -C $repoRoot merge-base --is-ancestor `
    ([string]$freeze.freeze_parent_commit) HEAD
Assert-Exact ($LASTEXITCODE -eq 0) (
    "$gateId freeze parent is not an ancestor of HEAD"
)

$priorAttempts = @()
if (Test-Path -LiteralPath $evidenceRoot -PathType Container) {
    $priorAttempts = @(
        Get-ChildItem -LiteralPath $evidenceRoot -Recurse -File `
            -Filter "attempt.json" |
        Where-Object {
            try {
                $attempt = Get-Content -Raw -LiteralPath $_.FullName |
                    ConvertFrom-Json
                [string]$attempt.campaign_id -ceq $campaignId
            } catch { $false }
        }
    )
}
Assert-Exact ($priorAttempts.Count -eq 0) (
    "$gateId physical identity was already consumed"
)

$workerSource = Get-Content -Raw -LiteralPath $workerPath
$receiptSource = Get-Content -Raw -LiteralPath $receiptCompositionPath
$supervisorSource = Get-Content -Raw -LiteralPath $supervisorPath
$conformanceSource = Get-Content -Raw -LiteralPath $conformancePath
Assert-SourceContains $workerSource @(
    'extends "res://tests/test_sdk_balanced_wave_bw20f_material_locomotion.gd"',
    'BW22L_FREEZE_PATH',
    'Bw22PolicyRelativeIntegrityScript',
    '. bind_physical_receipt(',
    'func _validate_stage_one_freeze() -> bool:',
    'bool(attempt.get("stage_one_freeze_verified", false))',
    'actual_world_build_count": 0',
    '"locomotion_outcome_exposed": false'
) "physical worker"
Assert-SourceContains $receiptSource @(
    'extends "res://tests/test_sdk_balanced_wave_bw22l_lateral_development.gd"',
    '_bw20f_physical_cell_receipt(cell, summary)',
    '_bw22l_physical_cell_receipt(cell, summary)',
    '"policy_relative_common_execution"',
    'BW22L_POLICY_RECEIPT_COMPOSITION_PASS',
    '"actual_world_build_count": actual_world_build_count',
    '"physical_acceptance_authority": false'
) "exact receipt-composition preflight"
Assert-SourceContains $supervisorSource @(
    '[bool]$PreflightOnly -xor [bool]$RunPhysical',
    'stage_one_freeze_verified = $true',
    'stage_one_freeze_raw_sha256 = Get-RawSha256 -Path $freezePath',
    'Write-NewJsonArtifact -Value $attempt -Path $attemptPath',
    'all_twenty_eight_cells_attempted_even_after_cell_failure',
    'same_identity_rerun_allowed = $false',
    'validation_authority=False physical_authority=False'
) "one-shot supervisor"
$attemptWriteIndex = $supervisorSource.IndexOf(
    'Write-NewJsonArtifact -Value $attempt -Path $attemptPath',
    [StringComparison]::Ordinal
)
$physicalLoopIndex = $supervisorSource.IndexOf(
    'for ($index = 0; $index -lt $cells.Count; $index += 1)',
    [StringComparison]::Ordinal
)
Assert-Exact (
    $attemptWriteIndex -ge 0 -and $physicalLoopIndex -gt $attemptWriteIndex
) "$gateId supervisor can enter its physical loop before durable attempt creation"
Assert-Exact (
    $conformanceSource.Contains(
        'test_bw22l_lateral_development_freeze.ps1',
        [StringComparison]::Ordinal
    ) -and
    $conformanceSource.Contains('-PreflightOnly', [StringComparison]::Ordinal) -and
    -not [regex]::IsMatch(
        $conformanceSource,
        'run_balanced_wave_bw22l_lateral_development\.ps1[\s\S]{0,240}-RunPhysical'
    )
) "$gateId normal conformance does not retain a zero-world-only route"

foreach ($scriptPath in @($gateTestPath, $supervisorPath, $conformancePath)) {
    [void][scriptblock]::Create((Get-Content -Raw -LiteralPath $scriptPath))
}
& pwsh -NoLogo -NoProfile -File $gateTestPath
Assert-Exact ($LASTEXITCODE -eq 0) (
    "$gateId production-gate canaries failed"
)
Invoke-ExpectedFailure `
    -Arguments @(
        "-NoLogo", "-NoProfile", "-File", $supervisorPath, "-RunPhysical"
    ) `
    -ExpectedText "$gateId -RunPhysical requires an explicit durable OutputRoot" `
    -Label "missing durable output-root bypass canary"

if (-not $SkipSupervisorPreflight) {
    & pwsh `
        -NoLogo `
        -NoProfile `
        -File $supervisorPath `
        -PreflightOnly `
        -Godot $Godot
    Assert-Exact ($LASTEXITCODE -eq 0) (
        "$gateId complete supervisor preflight failed"
    )
}

Write-Host (
    "BW22L_LATERAL_DEVELOPMENT_FREEZE_PASS worlds=0 entrypoints=28 " +
    "adapter_starts=27 production_gates=50 production_canaries=23 " +
    "authority=11/11 receipt_summaries=3 receipt_canaries=4 " +
    "authorization=1/1 bypass_canaries=2 source_bindings=35 " +
    "eligible_after_clean_pushed_conformance=True physical_authority=False"
)
