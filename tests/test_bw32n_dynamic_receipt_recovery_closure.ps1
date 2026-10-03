#requires -Version 7.0

[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$sdkRoot = Join-Path $repoRoot "sdk"
$closurePath = Join-Path $sdkRoot `
    "balanced_wave_bw32n_dynamic_receipt_recovery_closure.json"
$expectedClosureSha256 = (
    "c249a3727402ec5ebbea507d7550d0edd1f36ca58d69d87d69e8ac52489239d0"
)
$campaignId = "BW32N-BW31N-DYNAMIC-RECEIPT-RECOVERY-DEVELOPMENT"
$gateId = "BW32N"
$sourceCommit = "04226fd076b1a1d856f2b0fcec44fb35318f7d3e"
$sourceTree = "135c7da34f8179745ef8012402f6c16adb597b09"
$attemptId = "1ea5469a17bd4129a6005cf19b7567b6"

function Assert-Bw32nClosure {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function Get-Bw32nClosureRawSha256 {
    param([Parameter(Mandatory)][string]$Path)
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Assert-Bw32nHashedArtifact {
    param(
        [Parameter(Mandatory)][string]$Root,
        [Parameter(Mandatory)]$Artifact,
        [Parameter(Mandatory)][string]$Label
    )
    $path = Join-Path $Root ([string]$Artifact.path)
    Assert-Bw32nClosure (
        (Test-Path -LiteralPath $path -PathType Leaf) -and
        (Get-Item -LiteralPath $path).Length -eq [long]$Artifact.byte_length -and
        (Get-Bw32nClosureRawSha256 $path) -ceq [string]$Artifact.raw_sha256
    ) "$gateId retained $Label is missing or changed"
}

function Get-Bw32nEvidenceTreeDigest {
    param([Parameter(Mandatory)][string]$Root)
    $files = @(Get-ChildItem -LiteralPath $Root -File -Recurse)
    $rows = @(
        $files |
            ForEach-Object {
                $relative = [IO.Path]::GetRelativePath(
                    $Root,
                    $_.FullName
                ).Replace("\", "/")
                "{0}`t{1}`t{2}" -f (
                    $relative,
                    $_.Length,
                    (Get-Bw32nClosureRawSha256 $_.FullName)
                )
            } |
            Sort-Object
    )
    $text = ($rows -join "`n") + "`n"
    return [ordered]@{
        file_count = $files.Count
        total_byte_length = [long]($files | Measure-Object Length -Sum).Sum
        tree_sha256 = [Convert]::ToHexString(
            [Security.Cryptography.SHA256]::HashData(
                [Text.Encoding]::UTF8.GetBytes($text)
            )
        ).ToLowerInvariant()
    }
}

function Test-Bw32nSequenceEqual {
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

Assert-Bw32nClosure (
    (Test-Path -LiteralPath $closurePath -PathType Leaf) -and
    (Get-Bw32nClosureRawSha256 $closurePath) -ceq $expectedClosureSha256
) "$gateId closure is missing or changed"

& git -C $repoRoot cat-file -e "$sourceCommit`^{commit}"
Assert-Bw32nClosure ($LASTEXITCODE -eq 0) "$gateId source commit is unavailable"
Assert-Bw32nClosure (
    (& git -C $repoRoot rev-parse "$sourceCommit`^{tree}").Trim() -ceq $sourceTree
) "$gateId source tree changed"

$closure = Get-Content -Raw -LiteralPath $closurePath |
    ConvertFrom-Json -AsHashtable -Depth 100
$disposition = [Collections.IDictionary]$closure.disposition
$evidence = [Collections.IDictionary]$closure.retained_evidence
$comparison = [Collections.IDictionary]$closure.candidate_comparison
$next = [Collections.IDictionary]$closure.next_work_authority

Assert-Bw32nClosure (
    [string]$closure.schema_version -ceq
        "sporespore_balanced_wave_bw32n_dynamic_receipt_recovery_closure_v1" -and
    [string]$closure.status -ceq
        "closed_valid_development_selection_fresh_validation_ineligible" -and
    [string]$closure.campaign_id -ceq $campaignId -and
    [string]$closure.gate_id -ceq $gateId -and
    [string]$closure.experiment_source_commit -ceq $sourceCommit -and
    [string]$closure.experiment_source_tree -ceq $sourceTree -and
    [bool]$closure.source_was_clean_and_equal_to_origin_and_live_github_main -and
    [string]$closure.attempt_id -ceq $attemptId
) "$gateId closure identity changed"

Assert-Bw32nClosure (
    [bool]$disposition.complete_declared_physical_matrix_attempted -and
    [int]$disposition.expected_world_count -eq 24 -and
    [int]$disposition.attempted_world_count -eq 24 -and
    [int]$disposition.parsed_receipt_count -eq 24 -and
    [int]$disposition.candidate_a_receipt_count -eq 12 -and
    [int]$disposition.candidate_b_receipt_count -eq 12 -and
    [int]$disposition.process_exit_zero_count -eq 24 -and
    [int]$disposition.process_timeout_count -eq 0 -and
    [int]$disposition.process_tree_kill_count -eq 0 -and
    [bool]$disposition.frozen_evaluator_valid -and
    [int]$disposition.passed_gate_count -eq 16 -and
    [int]$disposition.failed_gate_count -eq 0 -and
    [bool]$disposition.development_result_valid -and
    [bool]$disposition.development_candidate_selected -and
    [string]$disposition.selected_candidate_id -ceq "BW32N-B" -and
    [bool]$disposition.selection_is_development_only -and
    -not [bool]$disposition.fresh_nuisance_validation_ready -and
    [bool]$disposition.independent_validation_required -and
    -not [bool]$disposition.physical_acceptance_authority
) "$gateId disposition changed"

$evidenceRoot = [IO.Path]::GetFullPath([string]$evidence.root)
foreach ($record in @(
    @{ value = $evidence.attempt; label = "attempt" },
    @{ value = $evidence.evaluation_input; label = "evaluation input" },
    @{ value = $evidence.evaluation; label = "evaluation" },
    @{ value = $evidence.report; label = "report" },
    @{ value = $evidence.completion; label = "completion" }
)) {
    Assert-Bw32nHashedArtifact `
        -Root $evidenceRoot `
        -Artifact $record.value `
        -Label $record.label
}
$tree = Get-Bw32nEvidenceTreeDigest $evidenceRoot
Assert-Bw32nClosure (
    [int]$evidence.cell_directories -eq 24 -and
    [int]$evidence.engine_logs -eq 24 -and
    [int]$evidence.transcripts -eq 24 -and
    [int]$evidence.stderr_logs -eq 24 -and
    [int]$tree.file_count -eq [int]$evidence.tree.file_count -and
    [long]$tree.total_byte_length -eq [long]$evidence.tree.total_byte_length -and
    [string]$tree.tree_sha256 -ceq [string]$evidence.tree.tree_sha256
) "$gateId retained evidence tree changed"

$attempt = Get-Content -Raw -LiteralPath (
    Join-Path $evidenceRoot ([string]$evidence.attempt.path)
) | ConvertFrom-Json -AsHashtable -Depth 100
$evaluationInput = Get-Content -Raw -LiteralPath (
    Join-Path $evidenceRoot ([string]$evidence.evaluation_input.path)
) | ConvertFrom-Json -AsHashtable -Depth 100
$evaluation = Get-Content -Raw -LiteralPath (
    Join-Path $evidenceRoot ([string]$evidence.evaluation.path)
) | ConvertFrom-Json -AsHashtable -Depth 100
$report = Get-Content -Raw -LiteralPath (
    Join-Path $evidenceRoot ([string]$evidence.report.path)
) | ConvertFrom-Json -AsHashtable -Depth 100
$completion = Get-Content -Raw -LiteralPath (
    Join-Path $evidenceRoot ([string]$evidence.completion.path)
) | ConvertFrom-Json -AsHashtable -Depth 100

$expectedCells = [Collections.Generic.List[string]]::new()
foreach ($profile in @("baseline", "rough", "push", "sensor_noise")) {
    foreach ($seed in @(21001, 21002, 21003)) {
        foreach ($suffix in @("a", "b")) {
            $expectedCells.Add("${profile}_s${seed}_bw32n_${suffix}")
        }
    }
}
Assert-Bw32nClosure (
    [string]$attempt.schema_version -ceq
        "sporespore_balanced_wave_bw32n_dynamic_receipt_recovery_attempt_v1" -and
    [string]$attempt.campaign_id -ceq $campaignId -and
    [string]$attempt.gate_id -ceq $gateId -and
    [string]$attempt.source_commit -ceq $sourceCommit -and
    [string]$attempt.origin_main_commit -ceq $sourceCommit -and
    [string]$attempt.remote_main_commit -ceq $sourceCommit -and
    [bool]$attempt.source_worktree_clean -and
    [bool]$attempt.source_matches_live_github_main -and
    [string]$attempt.attempt_id -ceq $attemptId -and
    [bool]$attempt.physical_identity_consumed -and
    -not [bool]$attempt.same_identity_rerun_allowed -and
    [bool]$attempt.locomotion_outcome_exposed_at_attempt -and
    -not [bool]$attempt.physical_acceptance_authority -and
    [int]$attempt.expected_world_count -eq 24 -and
    (Test-Bw32nSequenceEqual @($attempt.ordered_cell_ids) @($expectedCells))
) "$gateId attempt identity or order changed"
Assert-Bw32nClosure (
    -not ((@($attempt.ordered_cell_ids) -join "|") -match "49101|49102|49103") -and
    [string]$attempt.full_godot_v2_attestation_sha256 -ceq
        [string]$closure.full_godot_v2_attestation.raw_sha256
) "$gateId fresh-seed or attestation boundary changed"

Assert-Bw32nClosure (
    [bool]$evaluation.ok -and
    [string]$evaluation.status -ceq "complete_valid_development_result" -and
    [int]$evaluation.expected_world_count -eq 24 -and
    [int]$evaluation.observed_world_count -eq 24 -and
    [int]$evaluation.evaluated_cell_count -eq 24 -and
    @($evaluation.missing_cell_ids).Count -eq 0 -and
    @($evaluation.duplicate_cell_ids).Count -eq 0 -and
    @($evaluation.unexpected_cell_ids).Count -eq 0 -and
    [bool]$evaluation.strict_total_improvement_passed -and
    [bool]$evaluation.per_axis_non_regression_passed -and
    [string]$evaluation.selected_candidate_id -ceq "BW32N-B" -and
    -not [bool]$evaluation.fresh_nuisance_validation_ready -and
    [bool]$evaluation.selection_is_development_only -and
    [bool]$evaluation.independent_validation_required -and
    [int]$evaluation.passed_gate_count -eq 16 -and
    [int]$evaluation.failed_gate_count -eq 0 -and
    @($evaluation.failure_codes).Count -eq 0
) "$gateId frozen evaluation changed"

$summaryA = @($evaluation.candidate_summaries | Where-Object {
    [string]$_.candidate_id -ceq "BW32N-A"
})[0]
$summaryB = @($evaluation.candidate_summaries | Where-Object {
    [string]$_.candidate_id -ceq "BW32N-B"
})[0]
Assert-Bw32nClosure (
    [int]$summaryA.integrity_pass_count -eq 12 -and
    [int]$summaryA.walking_pass_count -eq 9 -and
    [int]$summaryA.walking_failure_count -eq 3 -and
    [int]$summaryA.failures_by_axis.bw6n_baseline_v1 -eq 0 -and
    [int]$summaryA.failures_by_axis.bw6n_rough_v1 -eq 2 -and
    [int]$summaryA.failures_by_axis.bw6n_push_v1 -eq 1 -and
    [int]$summaryA.failures_by_axis.bw6n_sensor_noise_v1 -eq 0 -and
    [int]$summaryB.integrity_pass_count -eq 12 -and
    [int]$summaryB.walking_pass_count -eq 10 -and
    [int]$summaryB.walking_failure_count -eq 2 -and
    [int]$summaryB.failures_by_axis.bw6n_baseline_v1 -eq 0 -and
    [int]$summaryB.failures_by_axis.bw6n_rough_v1 -eq 2 -and
    [int]$summaryB.failures_by_axis.bw6n_push_v1 -eq 0 -and
    [int]$summaryB.failures_by_axis.bw6n_sensor_noise_v1 -eq 0
) "$gateId candidate summaries changed"

$expectedFailures = [ordered]@{
    rough_s21001_bw32n_a = @(
        "contact_gating_completed_without_timeout",
        "every_limb_two_contact_cycles"
    )
    rough_s21002_bw32n_a = @("contact_gating_completed_without_timeout")
    rough_s21002_bw32n_b = @(
        "bounded_tilt",
        "bounded_torso_height",
        "contact_gated_evidence_horizon_completed",
        "contact_gating_completed_without_timeout",
        "every_limb_completed_evidence_gait_horizon",
        "minimum_evidence_forward_translation",
        "terminal_four_contact_recovery",
        "zero_torso_contact"
    )
    rough_s21003_bw32n_b = @(
        "bounded_lateral_drift",
        "contact_gating_completed_without_timeout"
    )
    push_s21003_bw32n_a = @("bounded_lateral_drift")
}
$observedFailures = [ordered]@{}
foreach ($receipt in @($evaluationInput.cell_receipts)) {
    Assert-Bw32nClosure (
        [int]$receipt.candidate_authority_observation_count -eq 3232 -and
        [int]$receipt.candidate_specific_horizon_extension_count -eq 0 -and
        [bool]$receipt.dynamic_parent_summary_gate_passed -and
        [bool]$receipt.common_execution_integrity -and
        [bool]$receipt.role_gate_passed -and
        [bool]$receipt.challenge_gate_passed -and
        [bool]$receipt.measurement_gate_passed -and
        [bool]$receipt.application_gate_passed -and
        [bool]$receipt.outcome_complete -and
        -not [bool]$receipt.walking_claim_authorized -and
        -not [bool]$receipt.nuisance_acceptance_claim_authorized -and
        -not [bool]$receipt.release_authorized -and
        -not [bool]$receipt.physical_acceptance_authority
    ) "$gateId receipt integrity or claim boundary changed: $($receipt.cell_id)"
    if (-not [bool]$receipt.walking_observed) {
        $observedFailures[[string]$receipt.cell_id] = @(
            $receipt.walking_gate_receipts.GetEnumerator() |
                Where-Object { -not [bool]$_.Value } |
                ForEach-Object { [string]$_.Key } |
                Sort-Object
        )
    }
}
Assert-Bw32nClosure (
    @($evaluationInput.cell_receipts).Count -eq 24 -and
    $observedFailures.Count -eq 5 -and
    (Test-Bw32nSequenceEqual @($observedFailures.Keys) @($expectedFailures.Keys))
) "$gateId walking-failure cell set changed"
foreach ($cellId in $expectedFailures.Keys) {
    Assert-Bw32nClosure (
        Test-Bw32nSequenceEqual `
            @($observedFailures[$cellId]) `
            @($expectedFailures[$cellId])
    ) "$gateId walking-failure receipts changed: $cellId"
}

Assert-Bw32nClosure (
    @($report.cell_attempts).Count -eq 24 -and
    @($report.cell_attempts | Where-Object {
        [int]$_.process_exit_code -eq 0
    }).Count -eq 24 -and
    @($report.cell_attempts | Where-Object { [bool]$_.timed_out }).Count -eq 0 -and
    @($report.cell_attempts | Where-Object {
        [bool]$_.killed_process_tree
    }).Count -eq 0 -and
    @($report.cell_attempts | Where-Object {
        [bool]$_.receipt_parsed
    }).Count -eq 24 -and
    [string]$report.selected_candidate_id -ceq "BW32N-B" -and
    -not [bool]$report.fresh_nuisance_validation_ready -and
    [bool]$report.independent_validation_required -and
    -not [bool]$report.physical_acceptance_authority
) "$gateId report changed"
Assert-Bw32nClosure (
    [bool]$completion.valid_complete_result -and
    [string]$completion.selected_candidate_id -ceq "BW32N-B" -and
    [int]$completion.expected_world_count -eq 24 -and
    [int]$completion.attempted_world_count -eq 24 -and
    [int]$completion.passed_gate_count -eq 16 -and
    [int]$completion.failed_gate_count -eq 0 -and
    -not [bool]$completion.same_identity_rerun_allowed -and
    -not [bool]$completion.physical_acceptance_authority
) "$gateId completion changed"

$attestationRecord = $closure.full_godot_v2_attestation
$attestationPath = [IO.Path]::GetFullPath([string]$attestationRecord.path)
Assert-Bw32nClosure (
    (Test-Path -LiteralPath $attestationPath -PathType Leaf) -and
    (Get-Item -LiteralPath $attestationPath).Length -eq
        [long]$attestationRecord.byte_length -and
    (Get-Bw32nClosureRawSha256 $attestationPath) -ceq
        [string]$attestationRecord.raw_sha256 -and
    [bool]$attestationRecord.production_verifier_ok_before_physical_attempt -and
    @($attestationRecord.production_verifier_failure_codes).Count -eq 0
) "$gateId full-Godot attestation changed"
$attestation = Get-Content -Raw -LiteralPath $attestationPath |
    ConvertFrom-Json -AsHashtable -Depth 100
Assert-Bw32nClosure (
    [string]$attestation.status -ceq "full_godot_conformance_passed" -and
    [bool]$attestation.conformance.passed -and
    [string]$attestation.source.commit -ceq $sourceCommit -and
    [string]$attestation.source.tree_git_oid -ceq $sourceTree -and
    [string]$attestation.source.origin_main -ceq $sourceCommit -and
    [string]$attestation.source.live_github_main -ceq $sourceCommit -and
    [bool]$attestation.source.worktree_clean -and
    [bool]$attestation.source.clean_pushed_live -and
    [double]$attestation.conformance.duration_seconds -eq 1630.6123323
) "$gateId attested source changed"
foreach ($binding in @($attestation.source_bindings)) {
    $historicalOid = (& git -C $repoRoot rev-parse (
        "$sourceCommit`:$([string]$binding.path)"
    )).Trim()
    Assert-Bw32nClosure (
        $LASTEXITCODE -eq 0 -and
        $historicalOid -ceq [string]$binding.git_blob_oid
    ) "$gateId historical attestation binding changed: $($binding.path)"
}
$lockSource = ((& git -C $repoRoot show (
    "$sourceCommit`:sdk/locomotion_operation_lock.ps1"
)) -join "`n") -replace '^#requires[^\r\n]*\r?\n', ''
$validatorSource = ((& git -C $repoRoot show (
    "$sourceCommit`:sdk/locomotion_full_conformance_attestation.ps1"
)) -join "`n") -replace '^#requires[^\r\n]*\r?\n', ''
Invoke-Expression $lockSource
Invoke-Expression $validatorSource
$historicalVerification = Test-SporeSporeFullConformanceAttestationDocument `
    -Document $attestation `
    -ExpectedSource $attestation.source `
    -ExpectedGodotIdentity $attestation.godot `
    -ExpectedPowerShellIdentity $attestation.powershell `
    -ExpectedSourceBindings @($attestation.source_bindings)
Assert-Bw32nClosure (
    [bool]$historicalVerification.ok -and
    @($historicalVerification.failure_codes).Count -eq 0 -and
    -not [bool]$historicalVerification.physical_acceptance_authority
) "$gateId historical attestation no longer verifies"

foreach ($entry in $attestation.claims.GetEnumerator()) {
    Assert-Bw32nClosure (-not [bool]$entry.Value) (
        "$gateId attestation claim inflated: $($entry.Key)"
    )
}
foreach ($field in @(
    "walking_acceptance",
    "nuisance_acceptance",
    "rough_terrain_robustness",
    "external_push_recovery",
    "sensor_noise_robustness",
    "sensor_latency_robustness",
    "combined_nuisance_robustness",
    "turning",
    "self_righting_or_fall_recovery",
    "arbitrary_quadruped_coverage",
    "continuous_full_volume_coverage",
    "cross_engine_equivalence",
    "release_authorized",
    "completed_engine_neutral_sdk",
    "physical_acceptance_authority"
)) {
    Assert-Bw32nClosure (-not [bool]$closure.claim_boundary[$field]) (
        "$gateId closure claim inflated: $field"
    )
    if ($evaluation.ContainsKey($field)) {
        Assert-Bw32nClosure (-not [bool]$evaluation[$field]) (
            "$gateId evaluation claim inflated: $field"
        )
    }
}

Assert-Bw32nClosure (
    [int]$comparison.candidate_a.walking_pass_count -eq 9 -and
    [int]$comparison.candidate_b.walking_pass_count -eq 10 -and
    [bool]$comparison.strict_total_improvement_passed -and
    [bool]$comparison.per_axis_non_regression_passed -and
    [bool]$comparison.candidate_b_removed_the_observed_candidate_a_push_failure -and
    [bool]$comparison.candidate_b_retained_two_rough_profile_failures -and
    -not [bool]$comparison.candidate_b_twelve_of_twelve_prerequisite_passed -and
    [bool]$comparison.finite_development_selection_authority -and
    -not [bool]$comparison.population_inference -and
    -not [bool]$comparison.superiority -and
    -not [bool]$comparison.noninferiority_or_equivalence -and
    [bool]$next.same_bw32n_identity_may_not_be_rerun_or_repaired -and
    [bool]$next.new_rough_focused_development_successor_may_be_declared -and
    -not [bool]$next.independent_validation_declaration_authorized -and
    -not [bool]$next.fresh_validation_seed_use_authorized -and
    (Test-Bw32nSequenceEqual `
        @($next.reserved_fresh_independent_validation_seed_ids) `
        @(49101, 49102, 49103)) -and
    [bool]$next.reserved_fresh_seeds_remain_unopened
) "$gateId comparison or next-work boundary changed"

Write-Host (
    "BW32N_DYNAMIC_RECEIPT_RECOVERY_CLOSURE_PASS status=valid-development-selection " +
    "worlds=24 receipts=24 gates=16/16 selected=BW32N-B " +
    "walking=9/12,10/12 failures=3,2 push_failures=1,0 rough_failures=2,2 " +
    "fresh_validation_ready=False fresh_seeds_opened=False " +
    "selection_authority=True walking_authority=False nuisance_authority=False " +
    "physical_authority=False rerun_refused=True"
)
