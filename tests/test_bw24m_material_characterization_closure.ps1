#requires -Version 7.0

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = [System.IO.Path]::GetFullPath(
    (Split-Path -Parent $PSScriptRoot)
)
$sdkRoot = Join-Path $repoRoot "sdk"
$closurePath = Join-Path (
    $sdkRoot
) "balanced_wave_bw24m_material_characterization_closure.json"
$supervisorPath = Join-Path (
    $sdkRoot
) "run_balanced_wave_bw24m_material_characterization.ps1"
$productionGatePath = Join-Path (
    $sdkRoot
) "balanced_wave_bw24m_material_characterization_gate.ps1"
$conformancePath = Join-Path $sdkRoot "run_conformance.ps1"
$expectedClosureRawSha256 = (
    "92a5aa2498e1260139f5ab36dd63663628084f3a8b83d1588250d20299ebbee2"
)
$campaignId = "BW24M-BW23Y-FRESH-MATERIAL-CHARACTERIZATION"
$gateId = "BW24M"
$physicalSourceCommit = "730fa100d14f427c6ccf09e83f30d4716e0f00e2"
$expectedValues = @(0.59, 0.71, 0.83)
$expectedLowerForces = @(23.0, 27.0, 32.0)
$expectedUpperForces = @(24.0, 29.0, 33.0)
$expectedLowerRatios = @(
    0.5864476091642263,
    0.688520883045167,
    0.816026345341562
)
$expectedControllerMus = @(0.58, 0.68, 0.81)
$falseClaimKeys = @(
    "walking_acceptance",
    "friction_or_material_locomotion_robustness",
    "continuous_friction_coverage",
    "portable_material_coefficient",
    "cross_engine_equivalence",
    "arbitrary_quadruped_coverage",
    "continuous_full_volume_morphology_coverage",
    "rough_terrain_robustness",
    "external_push_recovery",
    "sensor_noise_or_latency_robustness",
    "release_authorized",
    "physical_acceptance_authority",
    "completed_engine_neutral_sdk"
)

function Assert-Exact {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) {
        throw $Message
    }
}

function Get-RawSha256 {
    param([Parameter(Mandatory)][string]$Path)
    return (
        Get-FileHash -Algorithm SHA256 -LiteralPath $Path
    ).Hash.ToLowerInvariant()
}

function Assert-HashedFile {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$ExpectedSha256,
        [Parameter(Mandatory)][long]$ExpectedLength,
        [Parameter(Mandatory)][string]$Message
    )
    Assert-Exact (
        (Test-Path -LiteralPath $Path -PathType Leaf) -and
        (Get-RawSha256 -Path $Path) -ceq $ExpectedSha256 -and
        (Get-Item -LiteralPath $Path).Length -eq $ExpectedLength
    ) $Message
}

Assert-Exact (
    (Test-Path -LiteralPath $closurePath -PathType Leaf) -and
    (Get-RawSha256 -Path $closurePath) -ceq $expectedClosureRawSha256
) "$gateId closure is missing or changed"
$closure = Get-Content -Raw -LiteralPath $closurePath | ConvertFrom-Json

Assert-Exact (
    [string]$closure.schema_version -ceq
        "sporespore_balanced_wave_bw24m_material_characterization_closure_v1" -and
    [string]$closure.status -ceq
        "closed_complete_valid_positive_exact_finite_adapter_material_characterization" -and
    [string]$closure.campaign_id -ceq $campaignId -and
    [string]$closure.gate_id -ceq $gateId -and
    [string]$closure.study_classification -ceq
        "exact_finite_cell_adapter_material_characterization" -and
    [string]$closure.decision_classification -ceq "finite_decision" -and
    [string]$closure.physical_source_commit -ceq $physicalSourceCommit -and
    -not [bool]$closure.same_identity_rerun_allowed -and
    -not [bool]$closure.threshold_fixture_host_report_or_world_rewrite_allowed -and
    [int]$closure.physical_attempt.process_launch_count -eq 1 -and
    [int]$closure.physical_attempt.process_exit_code -eq 0 -and
    -not [bool]$closure.physical_attempt.process_timed_out -and
    -not [bool]$closure.physical_attempt.process_tree_killed -and
    [bool]$closure.physical_attempt.identity_consumed -and
    [bool]$closure.physical_attempt.report_retained -and
    [int]$closure.physical_attempt.expected_world_count -eq 10 -and
    [int]$closure.physical_attempt.observed_world_count -eq 10 -and
    [int]$closure.physical_attempt.locomotion_world_count -eq 0 -and
    [int]$closure.physical_attempt.expected_gate_count -eq 19 -and
    [int]$closure.physical_attempt.passed_gate_count -eq 19 -and
    [int]$closure.physical_attempt.failed_gate_count -eq 0 -and
    [bool]$closure.physical_attempt.accepted
) "$gateId closure identity, classification, or attempt summary changed"

Assert-Exact (
    [bool]$closure.execution_context.pre_physical_complete_conformance_passed -and
    [string]$closure.execution_context.conformance_source_commit -ceq
        $physicalSourceCommit -and
    [string]$closure.execution_context.conformance_success_marker -ceq
        "SDK C0/C1 conformance passed." -and
    [string]$closure.execution_context.conformance_stdout_sha256 -ceq
        "1ae8cb4f32777fb26b86fc04f0f0e8c1e4d57f3e1b4d5735e85de4fc7c2ed0d0" -and
    [string]$closure.execution_context.conformance_stderr_sha256 -ceq
        "4fef7fb157d998827f265c93bbfb4bc0b27e4c3f9c50f9e2e0e68dc4fb969841" -and
    [bool]$closure.execution_context.conformance_logs_are_transient_non_authoritative -and
    -not [bool]$closure.execution_context.overlapping_physics_or_conformance_process_observed
) "$gateId pre-physical conformance context changed"

& git -C $repoRoot cat-file -e "${physicalSourceCommit}^{commit}"
Assert-Exact (
    $LASTEXITCODE -eq 0
) "$gateId physical source commit is not retained by Git"
& git -C $repoRoot merge-base --is-ancestor $physicalSourceCommit HEAD
Assert-Exact (
    $LASTEXITCODE -eq 0
) "$gateId physical source is not an ancestor of HEAD"
$originMain = (& git -C $repoRoot rev-parse origin/main).Trim()
Assert-Exact (
    $LASTEXITCODE -eq 0
) "$gateId origin/main cannot be resolved"
& git -C $repoRoot merge-base --is-ancestor $physicalSourceCommit $originMain
Assert-Exact (
    $LASTEXITCODE -eq 0
) "$gateId physical source is not retained by origin/main"

$sourceBindings = @($closure.frozen_source_blobs.PSObject.Properties)
Assert-Exact (
    $sourceBindings.Count -eq 25
) "$gateId closure must bind all 25 physical-source blobs"
foreach ($binding in $sourceBindings) {
    $entry = $binding.Value
    $relativePath = [string]$entry.path
    $gitBlob = (& git -C $repoRoot rev-parse (
        $physicalSourceCommit + ":" + $relativePath
    )).Trim()
    Assert-Exact (
        $LASTEXITCODE -eq 0 -and
        [string]$entry.raw_sha256 -cmatch "^[0-9a-f]{64}$" -and
        $gitBlob -ceq [string]$entry.git_blob_oid
    ) "$gateId physical-source Git blob changed: $relativePath"
}

$evidenceRoot = [System.IO.Path]::GetFullPath(
    [string]$closure.retained_evidence.root
)
$expectedEvidenceRoot = [System.IO.Path]::GetFullPath(
    (Join-Path (Split-Path -Parent $repoRoot) (
        "SporeSpore_Evidence\" +
        "balanced-wave-bw24m-material-characterization-730fa10"
    ))
)
Assert-Exact (
    $evidenceRoot -ceq $expectedEvidenceRoot -and
    -not $evidenceRoot.StartsWith(
        "C:\tmp\",
        [StringComparison]::OrdinalIgnoreCase
    )
) "$gateId retained evidence root changed or escaped durable storage"

$declaredEvidencePaths = @()
foreach ($binding in @($closure.retained_evidence.PSObject.Properties)) {
    if ($binding.Name -ceq "root") {
        continue
    }
    $entry = $binding.Value
    $declaredEvidencePaths += [string]$entry.path
    Assert-HashedFile `
        -Path (Join-Path $evidenceRoot ([string]$entry.path)) `
        -ExpectedSha256 ([string]$entry.raw_sha256) `
        -ExpectedLength ([long]$entry.byte_length) `
        -Message "$gateId retained evidence changed: $($entry.path)"
}
$observedEvidencePaths = @(
    Get-ChildItem -LiteralPath $evidenceRoot -Recurse -File |
        ForEach-Object {
            [System.IO.Path]::GetRelativePath(
                $evidenceRoot,
                $_.FullName
            ).Replace("\", "/")
        } |
        Sort-Object
)
$declaredEvidencePaths = @($declaredEvidencePaths | Sort-Object)
Assert-Exact (
    $observedEvidencePaths.Count -eq 5 -and
    ($observedEvidencePaths -join "|") -ceq
        ($declaredEvidencePaths -join "|")
) "$gateId retained evidence file set is incomplete or contains undeclared files"

$attemptPath = Join-Path $evidenceRoot "attempt.json"
$reportPath = Join-Path $evidenceRoot "report.json"
$attempt = Get-Content -Raw -LiteralPath $attemptPath | ConvertFrom-Json
$report = Get-Content -Raw -LiteralPath $reportPath |
    ConvertFrom-Json -AsHashtable

Assert-Exact (
    [string]$attempt.schema_version -ceq
        "sporespore_balanced_wave_bw24m_material_characterization_attempt_v1" -and
    [string]$attempt.campaign_id -ceq $campaignId -and
    [string]$attempt.gate_id -ceq $gateId -and
    [string]$attempt.source_commit -ceq $physicalSourceCommit -and
    [string]$attempt.origin_main_commit -ceq $physicalSourceCommit -and
    [string]$attempt.remote_main_commit -ceq $physicalSourceCommit -and
    [bool]$attempt.source_worktree_clean -and
    [bool]$attempt.source_matches_live_github_main -and
    [string]$attempt.godot_version -ceq
        "4.7.stable.mono.official.5b4e0cb0f" -and
    [string]$attempt.godot_launcher_executable_sha256 -ceq
        "c5fc2d0bb24826a6757fa1e6bf2991effb294859c7dd03d09a122ef217484896" -and
    [string]$attempt.godot_runtime_executable_sha256 -ceq
        "baa909d0a905021da80cfc831713e9d3ba4bd0935ac3b93ba4c77dc140cfecc4" -and
    [string]$attempt.preregistration_raw_sha256 -ceq
        "7e622d2ef25cc3d0224e95f21cd00fff3a60ac96c8179e6ccfe36f0043375815" -and
    [bool]$attempt.complete_synthetic_production_gate_passed -and
    [bool]$attempt.zero_world_fixture_preflight_passed -and
    [bool]$attempt.physical_process_launch_reserved_identity_consumed -and
    -not [bool]$attempt.same_identity_rerun_allowed -and
    [int]$attempt.expected_world_count -eq 10 -and
    [int]$attempt.expected_gate_count -eq 19 -and
    [int]$attempt.locomotion_world_count -eq 0 -and
    -not [bool]$attempt.physical_acceptance_authority -and
    [int]$attempt.process_exit_code -eq 0 -and
    -not [bool]$attempt.process_timed_out -and
    -not [bool]$attempt.process_tree_killed -and
    [bool]$attempt.receipt_parsed -and
    [bool]$attempt.accepted
) "$gateId attempt receipt changed"

Assert-Exact (
    [string]$report.schema_version -ceq
        "sporespore_balanced_wave_bw24m_material_characterization_report_v1" -and
    [string]$report.campaign_id -ceq $campaignId -and
    [string]$report.gate_id -ceq $gateId -and
    [string]$report.source_commit -ceq $physicalSourceCommit -and
    [bool]$report.source_worktree_clean -and
    [bool]$report.source_matches_origin_main -and
    [bool]$report.source_matches_live_github_main -and
    [bool]$report.accepted -and
    [string]$report.result_status -ceq "passed" -and
    [bool]$report.first_complete_result_is_final -and
    -not [bool]$report.selective_replicate_rerun_allowed -and
    [int]$report.locomotion_world_count -eq 0 -and
    -not [bool]$report.material_robustness -and
    -not [bool]$report.continuous_friction_coverage -and
    -not [bool]$report.cross_engine_equivalence -and
    -not [bool]$report.physical_acceptance_authority -and
    [int]$report.godot_process.exit_code -eq 0 -and
    -not [bool]$report.godot_process.timed_out -and
    -not [bool]$report.godot_process.killed_process_tree -and
    [string]$report.godot_process.receipt_parse_failure -ceq "" -and
    [string]$report.host_identity.godot_version -ceq
        "4.7.stable.mono.official.5b4e0cb0f" -and
    [string]$report.host_identity.godot_launcher_executable_sha256 -ceq
        "c5fc2d0bb24826a6757fa1e6bf2991effb294859c7dd03d09a122ef217484896" -and
    [string]$report.host_identity.godot_runtime_executable_sha256 -ceq
        "baa909d0a905021da80cfc831713e9d3ba4bd0935ac3b93ba4c77dc140cfecc4" -and
    [string]$report.host_identity.physics_engine -ceq "Jolt Physics" -and
    [int]$report.host_identity.physics_hz -eq 120 -and
    [int]$report.host_identity.solver_velocity_steps -eq 20 -and
    [int]$report.host_identity.solver_position_steps -eq 7
) "$gateId retained report identity, host, result, or claim boundary changed"

$receipt = $report.receipt
Assert-Exact (
    [string]$receipt.schema_version -ceq
        "sporespore_balanced_wave_bw24m_material_characterization_receipt_v1" -and
    [bool]$receipt.ok -and
    [int]$receipt.expected_world_count -eq 10 -and
    [int]$receipt.observed_world_count -eq 10 -and
    [int]$receipt.expected_gate_count -eq 19 -and
    [int]$receipt.passed_gate_count -eq 19 -and
    [int]$receipt.failed_gate_count -eq 0 -and
    [bool]$receipt.cold_characterization -and
    -not [bool]$receipt.development_data_only -and
    -not [bool]$receipt.adapter_actuation_applied -and
    -not [bool]$receipt.physics_transform_or_velocity_written -and
    -not [bool]$receipt.walking -and
    -not [bool]$receipt.material_robustness -and
    -not [bool]$receipt.continuous_friction_coverage -and
    -not [bool]$receipt.cross_engine_equivalence -and
    -not [bool]$receipt.physical_acceptance_authority -and
    -not [bool]$receipt.completed_engine_neutral_sdk -and
    [bool]$receipt.invalid_value_control.rejected -and
    [double]$receipt.invalid_value_control.attempted_friction -eq 0.25 -and
    [string]$receipt.invalid_value_control.failure_code -ceq
        "SDK_FRICTION_LADDER_VALUE_INVALID" -and
    [bool]$receipt.frictionless_control.ok -and
    [string]$receipt.frictionless_control.classification -ceq "SLIDING" -and
    [int]$receipt.frictionless_control.world_build_count -eq 1 -and
    [bool]$receipt.monotonicity.ok -and
    @($receipt.monotonicity.violations).Count -eq 0
) "$gateId receipt integrity, controls, or claim boundary changed"

$authoredValues = @($receipt.fixture.authored_friction_values)
$positiveValues = @($receipt.fixture.positive_friction_values)
Assert-Exact (
    $authoredValues.Count -eq 4 -and
    [double]$authoredValues[0] -eq 0.0 -and
    $positiveValues.Count -eq 3 -and
    (@(for ($i = 0; $i -lt 3; $i += 1) {
        [double]$authoredValues[$i + 1] -eq $expectedValues[$i] -and
        [double]$positiveValues[$i] -eq $expectedValues[$i]
    }) -notcontains $false)
) "$gateId authored friction matrix changed"

$cells = @($receipt.positive_cells)
$evaluatedCells = @($report.production_gate_evaluation.cells)
$closedCells = @($closure.result.cells)
Assert-Exact (
    $cells.Count -eq 3 -and
    $evaluatedCells.Count -eq 3 -and
    $closedCells.Count -eq 3
) "$gateId must retain exactly three positive characterization cells"
for ($cellIndex = 0; $cellIndex -lt 3; $cellIndex += 1) {
    $cell = $cells[$cellIndex]
    $evaluated = $evaluatedCells[$cellIndex]
    $closed = $closedCells[$cellIndex]
    $replicates = @($cell.replicates)
    $closedBrackets = @($closed.replicate_breakaway_brackets_n)
    Assert-Exact (
        [double]$cell.authored_friction -eq $expectedValues[$cellIndex] -and
        [bool]$cell.ok -and
        $replicates.Count -eq 3 -and
        [double]$cell.minimum_lower_breakaway_force_n -eq
            $expectedLowerForces[$cellIndex] -and
        [double]$cell.minimum_lower_empirical_ratio -eq
            $expectedLowerRatios[$cellIndex] -and
        [double]$cell.coefficient_derivation.controller_mu -eq
            $expectedControllerMus[$cellIndex] -and
        [bool]$cell.coefficient_derivation.ok -and
        -not [bool]$cell.coefficient_derivation.cross_engine_equivalent -and
        -not [bool]$cell.coefficient_derivation.locomotion_robustness -and
        [double]$cell.first_sliding_force_spread_n -eq 0.0 -and
        [double]$cell.lower_breakaway_force_spread_n -eq 0.0 -and
        [double]$evaluated.authored_friction -eq $expectedValues[$cellIndex] -and
        [double]$evaluated.minimum_lower_breakaway_force_n -eq
            $expectedLowerForces[$cellIndex] -and
        [double]$evaluated.minimum_lower_empirical_ratio -eq
            $expectedLowerRatios[$cellIndex] -and
        [double]$evaluated.controller_mu -eq $expectedControllerMus[$cellIndex] -and
        [bool]$evaluated.passed -and
        [double]$closed.authored_friction -eq $expectedValues[$cellIndex] -and
        [double]$closed.minimum_lower_breakaway_force_n -eq
            $expectedLowerForces[$cellIndex] -and
        [double]$closed.minimum_lower_empirical_ratio -eq
            $expectedLowerRatios[$cellIndex] -and
        [double]$closed.controller_mu -eq $expectedControllerMus[$cellIndex] -and
        [bool]$closed.passed -and
        $closedBrackets.Count -eq 3
    ) "$gateId cell $cellIndex summary or coefficient changed"
    for ($replicateIndex = 0; $replicateIndex -lt 3; $replicateIndex += 1) {
        $closedBracket = @($closedBrackets[$replicateIndex])
        Assert-Exact (
            $closedBracket.Count -eq 2 -and
            [double]$closedBracket[0] -eq $expectedLowerForces[$cellIndex] -and
            [double]$closedBracket[1] -eq $expectedUpperForces[$cellIndex]
        ) "$gateId closed cell $cellIndex bracket $replicateIndex changed"
    }
    foreach ($replicate in $replicates) {
        Assert-Exact (
            [bool]$replicate.ok -and
            [bool]$replicate.all_stage_observations_complete -and
            [bool]$replicate.breakaway_analysis.breakaway_detected -and
            [double]$replicate.breakaway_analysis.breakaway_force_lower_n -eq
                $expectedLowerForces[$cellIndex] -and
            [double]$replicate.breakaway_analysis.breakaway_force_upper_n -eq
                $expectedUpperForces[$cellIndex] -and
            [bool]$replicate.two_consecutive_sliding_stages_observed -and
            [bool]$replicate.positive_force_held_observed -and
            [int]$replicate.world_build_count -eq 1
        ) "$gateId cell $cellIndex replicate changed or became incomplete"
    }
}

Assert-Exact (
    [bool]$report.production_gate_evaluation.ok -and
    [int]$report.production_gate_evaluation.expected_gate_count -eq 19 -and
    [int]$report.production_gate_evaluation.reconstructed_passed_gate_count -eq 19 -and
    [int]$report.production_gate_evaluation.reconstructed_failed_gate_count -eq 0 -and
    [bool]$report.production_gate_evaluation.receipt_meta_integrity_passed -and
    [bool]$report.production_gate_evaluation.fixture_identity_and_matrix_passed -and
    [int]$report.production_gate_evaluation.observed_world_count -eq 10 -and
    @($report.production_gate_evaluation.gates).Count -eq 19 -and
    @($report.production_gate_evaluation.failure_codes).Count -eq 0 -and
    [bool]$report.production_gate_evaluation.claims_remain_bounded -and
    -not [bool]$report.production_gate_evaluation.physical_acceptance_authority
) "$gateId retained production-gate evaluation changed"

. $productionGatePath
$recomputed = Test-Bw24mMaterialCharacterizationReceipt -Receipt $receipt
Assert-Exact (
    [bool]$recomputed.ok -and
    [int]$recomputed.reconstructed_passed_gate_count -eq 19 -and
    [int]$recomputed.reconstructed_failed_gate_count -eq 0 -and
    [int]$recomputed.observed_world_count -eq 10 -and
    @($recomputed.failure_codes).Count -eq 0 -and
    -not [bool]$recomputed.physical_acceptance_authority
) "$gateId frozen production evaluator no longer accepts the retained receipt"

$reportSources = $report.sources
Assert-Exact (
    $reportSources.Count -eq 25
) "$gateId retained report source map changed"
foreach ($binding in $sourceBindings) {
    $entry = $binding.Value
    $path = [string]$entry.path
    Assert-Exact (
        $reportSources.Contains($path) -and
        [string]$reportSources[$path].path -ceq $path -and
        [string]$reportSources[$path].sha256 -ceq [string]$entry.raw_sha256
    ) "$gateId report/source hash reconciliation changed: $path"
}
Assert-Exact (
    [string]$report.attempt.sha256 -ceq
        [string]$closure.retained_evidence.attempt.raw_sha256 -and
    [string]$report.transcript.sha256 -ceq
        [string]$closure.retained_evidence.transcript.raw_sha256 -and
    [string]$report.engine_log.sha256 -ceq
        [string]$closure.retained_evidence.engine_log.raw_sha256
) "$gateId report/evidence hash reconciliation changed"

Assert-Exact (
    (@($closure.result.authored_friction_values) -join ",") -ceq
        "0.59,0.71,0.83" -and
    [int]$closure.result.replicates_per_positive_value -eq 3 -and
    [int]$closure.result.frictionless_control_count -eq 1 -and
    [string]$closure.result.frictionless_control_classification -ceq "SLIDING" -and
    [double]$closure.result.invalid_authored_value -eq 0.25
) "$gateId closed result matrix or controls changed"

Assert-Exact (
    [bool]$closure.result.accepted -and
    [string]$closure.result.result_status -ceq "passed" -and
    [bool]$closure.result.cold_characterization -and
    [bool]$closure.result.invalid_authored_value_rejected -and
    [bool]$closure.result.operational_monotonicity_passed -and
    [bool]$closure.scientific_disposition.complete_valid_positive_exact_finite_characterization -and
    [bool]$closure.scientific_disposition.adapter_profile_publication_authorized -and
    -not [bool]$closure.scientific_disposition.locomotion_outcome_observed -and
    -not [bool]$closure.scientific_disposition.future_locomotion_seeds_opened -and
    -not [bool]$closure.scientific_disposition.material_robustness_established -and
    -not [bool]$closure.scientific_disposition.continuous_friction_coverage_established -and
    -not [bool]$closure.scientific_disposition.portable_material_coefficient_established -and
    -not [bool]$closure.scientific_disposition.cross_engine_equivalence_established -and
    -not [bool]$closure.scientific_disposition.physical_acceptance_authority -and
    [bool]$closure.next_allowed_work.bw24m_stage_1_is_closed -and
    [bool]$closure.next_allowed_work.immutable_adapter_profile_publication_may_proceed -and
    [bool]$closure.next_allowed_work.stage_3_manifest_may_freeze_only_after_profile_publication -and
    [bool]$closure.next_allowed_work.stage_3_physical_locomotion_may_not_open_before_distinct_manifest_and_complete_zero_world_gate -and
    [bool]$closure.next_allowed_work.post_closure_full_conformance_pass_required_before_profile_publication -and
    [bool]$closure.next_allowed_work.release_selected_policy_unchanged -and
    [bool]$closure.next_allowed_work.release_not_authorized
) "$gateId scientific disposition or staged interlock changed"

Assert-Exact (
    (@($closure.next_allowed_work.profile_must_retain_exact_authored_values) -join ",") -ceq
        "0.59,0.71,0.83" -and
    (@($closure.next_allowed_work.profile_must_retain_exact_characterized_coefficients) -join ",") -ceq
        "0.58,0.68,0.81" -and
    [bool]$closure.next_allowed_work.profile_publication_must_open_zero_locomotion_worlds -and
    (@($closure.next_allowed_work.sealed_future_locomotion_seeds) -join ",") -ceq
        "26011,26012,26013,26014"
) "$gateId exact profile-publication values or sealed seeds changed"

$conformanceRaw = Get-Content -Raw -LiteralPath $conformancePath
Assert-Exact (
    $conformanceRaw.Contains(
        'tests\test_bw24m_material_characterization_closure.ps1'
    ) -and
    $conformanceRaw -notmatch
        'run_balanced_wave_bw24m_material_characterization\.ps1[\s\S]{0,320}-PreflightOnly'
) "$gateId normal conformance can replay a consumed prospective route"

Assert-Exact (
    [bool]$closure.claims.exact_finite_godot_jolt_material_characterization -and
    [bool]$closure.claims.immutable_profile_publication_authorized
) "$gateId positive characterization claim changed"
foreach ($key in $falseClaimKeys) {
    Assert-Exact (
        -not [bool]$closure.claims.$key
    ) "$gateId unsupported claim became true: $key"
}

$allAttemptPaths = @(
    Get-ChildItem `
        -LiteralPath (Join-Path (Split-Path -Parent $repoRoot) "SporeSpore_Evidence") `
        -Recurse `
        -File `
        -Filter "attempt.json" |
        Where-Object {
            try {
                $candidateAttempt = Get-Content -Raw -LiteralPath $_.FullName |
                    ConvertFrom-Json
                [string]$candidateAttempt.campaign_id -ceq $campaignId
            } catch {
                $false
            }
        }
)
Assert-Exact (
    $allAttemptPaths.Count -eq 1 -and
    [System.IO.Path]::GetFullPath($allAttemptPaths[0].FullName) -ceq
        [System.IO.Path]::GetFullPath($attemptPath)
) "$gateId must retain exactly one physical attempt"

$rerunOutput = @(
    & pwsh `
        -NoLogo `
        -NoProfile `
        -File $supervisorPath `
        -RunPhysical `
        -OutputRoot $evidenceRoot 2>&1
)
$rerunExitCode = $LASTEXITCODE
Assert-Exact (
    $rerunExitCode -ne 0 -and
    (($rerunOutput | Out-String) -match
        "BW24M characterization is already closed and may not rerun")
) "$gateId physical rerun did not fail at the immutable closure interlock"

Write-Host (
    "BW24M_MATERIAL_CLOSURE_PASS status=positive worlds=10 gates=19 " +
    "cells=3 profile_publication=True locomotion_seeds_opened=0 " +
    "pre_physical_conformance=True conformance_overlap=False " +
    "post_closure_conformance_required=True rerun_refused=True " +
    "material_robustness=False physical_authority=False"
)
