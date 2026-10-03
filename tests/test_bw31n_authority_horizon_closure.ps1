#requires -Version 7.0

[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [System.IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$sdkRoot = Join-Path $repoRoot "sdk"
$campaignId = "BW31N-BW30N-AUTHORITY-HORIZON-RECOVERY-DEVELOPMENT"
$gateId = "BW31N"
$sourceCommit = "2690f24370ad8af09521b7bd9e61ce46ff6c1510"
$sourceTree = "89b9282760c729cc12bdb98ba70c99d542229ff4"
$attemptId = "71b68972efba4c7395b8215e49918bd2"
$closurePath = Join-Path $sdkRoot "balanced_wave_bw31n_authority_horizon_closure.json"
$expectedClosureSha256 = (
    "b92320e3122257829cebab3ae08c6dacc0aa2def055a649c1345e78b0a51e65f"
)
$evidenceBase = [System.IO.Path]::GetFullPath(
    (Join-Path (Split-Path -Parent $repoRoot) "SporeSpore_Evidence")
)
$materialProfileSha256 = (
    "sha256:e62b97398497f32243bae4fb6eaca258f90cbd233fc8c913c456b01a287bf993"
)

function Assert-Exact {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function Get-Bw31nClosureRawSha256 {
    param([Parameter(Mandatory)][string]$Path)
    return (Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash.ToLowerInvariant()
}

function Assert-HashedArtifact {
    param(
        [Parameter(Mandatory)][string]$Root,
        [Parameter(Mandatory)]$Artifact,
        [Parameter(Mandatory)][string]$Label
    )
    $path = Join-Path $Root ([string]$Artifact.path)
    Assert-Exact (
        (Test-Path -LiteralPath $path -PathType Leaf) -and
        (Get-Item -LiteralPath $path).Length -eq [long]$Artifact.byte_length -and
        (Get-Bw31nClosureRawSha256 -Path $path) -ceq [string]$Artifact.raw_sha256
    ) "$gateId retained $Label is missing or changed"
}

function Get-EvidenceTreeDigest {
    param([Parameter(Mandatory)][string]$Root)
    $files = @(Get-ChildItem -LiteralPath $Root -File -Recurse)
    $rows = @(
        $files |
            ForEach-Object {
                $relative = [System.IO.Path]::GetRelativePath(
                    $Root,
                    $_.FullName
                ).Replace("\", "/")
                "{0}`t{1}`t{2}" -f (
                    $relative,
                    $_.Length,
                    (Get-Bw31nClosureRawSha256 -Path $_.FullName)
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

function Get-HistoricalGitBlobSha256 {
    param(
        [Parameter(Mandatory)][string]$Repo,
        [Parameter(Mandatory)][string]$BlobOid
    )
    $start = [System.Diagnostics.ProcessStartInfo]::new()
    $start.FileName = "git"
    [void]$start.ArgumentList.Add("-C")
    [void]$start.ArgumentList.Add($Repo)
    [void]$start.ArgumentList.Add("cat-file")
    [void]$start.ArgumentList.Add("blob")
    [void]$start.ArgumentList.Add($BlobOid)
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    $process = [System.Diagnostics.Process]::new()
    $process.StartInfo = $start
    [void]$process.Start()
    $memory = [System.IO.MemoryStream]::new()
    try {
        $process.StandardOutput.BaseStream.CopyTo($memory)
        $errorText = $process.StandardError.ReadToEnd()
        $process.WaitForExit()
        if ($process.ExitCode -ne 0) {
            throw "git cat-file failed for $BlobOid`: $errorText"
        }
        return [Convert]::ToHexString(
            [Security.Cryptography.SHA256]::HashData($memory.ToArray())
        ).ToLowerInvariant()
    } finally {
        $memory.Dispose()
        $process.Dispose()
    }
}

Assert-Exact (
    (Test-Path -LiteralPath $closurePath -PathType Leaf) -and
    (Get-Bw31nClosureRawSha256 -Path $closurePath) -ceq $expectedClosureSha256
) "$gateId closure is missing or changed"
$closure = Get-Content -Raw -LiteralPath $closurePath |
    ConvertFrom-Json -AsHashtable -Depth 100

Assert-Exact (
    [string]$closure.schema_version -ceq
        "sporespore_balanced_wave_bw31n_authority_horizon_closure_v1" -and
    [string]$closure.status -ceq
        "closed_implementation_invalid_after_complete_physical_matrix_and_frozen_evaluation" -and
    [string]$closure.campaign_id -ceq $campaignId -and
    [string]$closure.gate_id -ceq $gateId -and
    [string]$closure.experiment_source_commit -ceq $sourceCommit -and
    [string]$closure.experiment_source_tree -ceq $sourceTree -and
    [bool]$closure.source_was_clean_and_equal_to_origin_and_live_github_main -and
    [string]$closure.attempt_id -ceq $attemptId -and
    [bool]$closure.disposition.complete_declared_physical_matrix_attempted -and
    [int]$closure.disposition.expected_world_count -eq 24 -and
    [int]$closure.disposition.attempted_world_count -eq 24 -and
    [int]$closure.disposition.parsed_receipt_count -eq 24 -and
    [int]$closure.disposition.process_timeout_count -eq 0 -and
    [int]$closure.disposition.process_tree_kill_count -eq 0 -and
    [bool]$closure.disposition.original_frozen_evaluator_completed -and
    -not [bool]$closure.disposition.original_frozen_evaluator_valid -and
    -not [bool]$closure.disposition.development_result_valid -and
    -not [bool]$closure.disposition.development_candidate_selected -and
    [string]$closure.disposition.selected_candidate_id -ceq "NONE" -and
    -not [bool]$closure.disposition.valid_none_selection -and
    [bool]$closure.disposition.not_a_locomotion_negative -and
    [bool]$closure.disposition.not_a_nuisance_acceptance_result -and
    [bool]$closure.disposition.implementation_invalid
) "$gateId closure identity or disposition changed"

Assert-Exact (
    (git -C $repoRoot rev-parse "${sourceCommit}^{tree}").Trim() -ceq $sourceTree
) "$gateId experiment source tree changed"
foreach ($binding in $closure.exact_source_bindings.GetEnumerator()) {
    $relativePath = [string]$binding.Value.path
    $treeLine = (& git -C $repoRoot ls-tree $sourceCommit -- $relativePath).Trim()
    $treeParts = @($treeLine -split "\s+")
    Assert-Exact (
        $treeParts.Count -ge 3 -and
        [string]$treeParts[2] -ceq [string]$binding.Value.git_blob_oid -and
        (Get-HistoricalGitBlobSha256 `
            -Repo $repoRoot `
            -BlobOid ([string]$binding.Value.git_blob_oid)) -ceq
            [string]$binding.Value.git_blob_raw_sha256
    ) "$gateId historical source binding changed: $($binding.Key)"
}

$evidenceRoot = [System.IO.Path]::GetFullPath([string]$closure.retained_evidence.root)
Assert-Exact (
    $evidenceRoot.StartsWith(
        $evidenceBase + [System.IO.Path]::DirectorySeparatorChar,
        [StringComparison]::OrdinalIgnoreCase
    ) -and
    (Test-Path -LiteralPath $evidenceRoot -PathType Container)
) "$gateId retained evidence root is missing or outside the evidence boundary"
foreach ($entry in @(
    @($closure.retained_evidence.attempt, "attempt"),
    @($closure.retained_evidence.evaluation_input, "evaluation input"),
    @($closure.retained_evidence.original_evaluation, "evaluation"),
    @($closure.retained_evidence.original_report, "report"),
    @($closure.retained_evidence.original_completion, "completion")
)) {
    Assert-HashedArtifact -Root $evidenceRoot -Artifact $entry[0] -Label $entry[1]
}
$tree = Get-EvidenceTreeDigest -Root $evidenceRoot
Assert-Exact (
    [int]$tree.file_count -eq [int]$closure.retained_evidence.tree.file_count -and
    [long]$tree.total_byte_length -eq
        [long]$closure.retained_evidence.tree.total_byte_length -and
    [string]$tree.tree_sha256 -ceq
        [string]$closure.retained_evidence.tree.tree_sha256 -and
    @(Get-ChildItem -LiteralPath $evidenceRoot -Directory).Count -eq 24 -and
    @(Get-ChildItem -LiteralPath $evidenceRoot -Filter engine.log -File -Recurse).Count -eq 24 -and
    @(Get-ChildItem -LiteralPath $evidenceRoot -Filter transcript.log -File -Recurse).Count -eq 24 -and
    @(Get-ChildItem -LiteralPath $evidenceRoot -Filter stderr.log -File -Recurse).Count -eq 24
) "$gateId retained evidence tree or log inventory changed"

$attestationPath = [System.IO.Path]::GetFullPath(
    [string]$closure.full_godot_v2_attestation.path
)
Assert-Exact (
    (Test-Path -LiteralPath $attestationPath -PathType Leaf) -and
    (Get-Item -LiteralPath $attestationPath).Length -eq
        [long]$closure.full_godot_v2_attestation.byte_length -and
    (Get-Bw31nClosureRawSha256 -Path $attestationPath) -ceq
        [string]$closure.full_godot_v2_attestation.raw_sha256
) "$gateId exact-source full-Godot V2 attestation changed"
$attestation = Get-Content -Raw -LiteralPath $attestationPath |
    ConvertFrom-Json -AsHashtable -Depth 100
Assert-Exact (
    [string]$attestation.schema_version -ceq
        "sporespore_full_godot_conformance_attestation_v2" -and
    [string]$attestation.status -ceq "full_godot_conformance_passed" -and
    [string]$attestation.source.commit -ceq $sourceCommit -and
    [string]$attestation.source.tree_git_oid -ceq $sourceTree -and
    [double]$attestation.conformance.duration_seconds -eq
        [double]$closure.full_godot_v2_attestation.duration_seconds -and
    @($attestation.claims.GetEnumerator() | Where-Object { [bool]$_.Value }).Count -eq 0
) "$gateId exact-source attestation identity or claim boundary changed"

$attempt = Get-Content -Raw -LiteralPath (Join-Path $evidenceRoot "attempt.json") |
    ConvertFrom-Json -AsHashtable -Depth 100
$input = Get-Content -Raw -LiteralPath (Join-Path $evidenceRoot "evaluation-input.json") |
    ConvertFrom-Json -AsHashtable -Depth 100
$evaluation = Get-Content -Raw -LiteralPath (Join-Path $evidenceRoot "evaluation.json") |
    ConvertFrom-Json -AsHashtable -Depth 100
$report = Get-Content -Raw -LiteralPath (Join-Path $evidenceRoot "report.json") |
    ConvertFrom-Json -AsHashtable -Depth 100
$completion = Get-Content -Raw -LiteralPath (Join-Path $evidenceRoot "completion.json") |
    ConvertFrom-Json -AsHashtable -Depth 100

Assert-Exact (
    [string]$attempt.schema_version -ceq
        "sporespore_balanced_wave_bw31n_authority_horizon_attempt_v1" -and
    [string]$attempt.campaign_id -ceq $campaignId -and
    [string]$attempt.gate_id -ceq $gateId -and
    [string]$attempt.attempt_id -ceq $attemptId -and
    [string]$attempt.source_commit -ceq $sourceCommit -and
    [string]$attempt.origin_main_commit -ceq $sourceCommit -and
    [string]$attempt.remote_main_commit -ceq $sourceCommit -and
    [bool]$attempt.source_worktree_clean -and
    [bool]$attempt.source_matches_live_github_main -and
    [bool]$attempt.complete_zero_world_gate_passed -and
    [bool]$attempt.candidate_authority_horizon_preflight_passed -and
    [bool]$attempt.stage_one_freeze_verified -and
    [bool]$attempt.physical_identity_consumed -and
    -not [bool]$attempt.same_identity_rerun_allowed -and
    [int]$attempt.expected_world_count -eq 24 -and
    @($attempt.ordered_cell_ids).Count -eq 24 -and
    @($attempt.primary_world_attempt_ids).Count -eq 24
) "$gateId retained attempt identity or authorization changed"

$receipts = @($input.cell_receipts)
$candidateA = @($receipts | Where-Object { [string]$_.candidate_id -ceq "BW31N-A" })
$candidateB = @($receipts | Where-Object { [string]$_.candidate_id -ceq "BW31N-B" })
$candidateANoise = @($candidateA | Where-Object {
    [string]$_.challenge_profile_id -ceq "bw6n_sensor_noise_v1"
})
$candidateBNoise = @($candidateB | Where-Object {
    [string]$_.challenge_profile_id -ceq "bw6n_sensor_noise_v1"
})
$expectedKeys = @($receipts[0].Keys | Sort-Object)
$allKeySetsExact = $true
foreach ($receipt in $receipts) {
    if (-not (Test-SequenceEqual `
        -Actual @($receipt.Keys | Sort-Object) `
        -Expected $expectedKeys)) {
        $allKeySetsExact = $false
    }
}
Assert-Exact (
    [string]$input.schema_version -ceq
        "sporespore_balanced_wave_bw31n_authority_horizon_evaluation_input_v1" -and
    [string]$input.attempt_id -ceq $attemptId -and
    $receipts.Count -eq 24 -and
    $candidateA.Count -eq 12 -and
    $candidateB.Count -eq 12 -and
    $allKeySetsExact -and
    @($receipts | Where-Object {
        [string]$_.material_profile_sha256 -ceq $materialProfileSha256
    }).Count -eq 24 -and
    @($receipts | Where-Object {
        [int]$_.candidate_authority_observation_count -eq 3232 -and
        [int]$_.first_candidate_authority_observation_index -eq 0 -and
        [int]$_.last_candidate_authority_observation_index -eq 3231 -and
        [int]$_.candidate_specific_horizon_extension_count -eq 0
    }).Count -eq 24 -and
    @($candidateA | Where-Object { [int]$_.pre_authority_world_tick_count -eq 712 }).Count -eq 12 -and
    @($candidateB | Where-Object { [int]$_.pre_authority_world_tick_count -eq 240 }).Count -eq 12 -and
    @($receipts | Where-Object { [bool]$_.measurement_gate_passed }).Count -eq 24 -and
    @($candidateA | Where-Object { [bool]$_.application_gate_passed }).Count -eq 12 -and
    @($candidateB | Where-Object { [bool]$_.application_gate_passed }).Count -eq 0 -and
    @($candidateA | Where-Object { [bool]$_.outcome_complete }).Count -eq 12 -and
    @($candidateB | Where-Object { [bool]$_.outcome_complete }).Count -eq 0 -and
    @($candidateA | Where-Object { [bool]$_.challenge_gate_passed }).Count -eq 9 -and
    @($candidateB | Where-Object { [bool]$_.challenge_gate_passed }).Count -eq 12 -and
    @($receipts | Where-Object { [bool]$_.common_execution_integrity }).Count -eq 0 -and
    @($receipts | Where-Object { [bool]$_.walking_observed }).Count -eq 0 -and
    @($receipts | Where-Object { [bool]$_.physical_acceptance_authority }).Count -eq 0
) "$gateId retained receipt matrix or implementation diagnosis changed"

Assert-Exact (
    @($candidateB | Where-Object {
        -not [string]::IsNullOrEmpty([string]$_.controller_policy_id) -or
        -not [string]::IsNullOrEmpty([string]$_.controller_policy_digest) -or
        -not [string]::IsNullOrEmpty([string]$_.stability_policy_id) -or
        -not [string]::IsNullOrEmpty([string]$_.authority_scope) -or
        -not [string]::IsNullOrEmpty([string]$_.execution_mode) -or
        [bool]$_.physical_influence
    }).Count -eq 0 -and
    @($candidateANoise | Where-Object {
        [int]$_.observation_fault_application_count -eq 3232 -and
        [int]$_.observation_fault_base_and_stability_count -eq 3232 -and
        [double]$_.maximum_observation_fault_component -eq 0.02 -and
        -not [bool]$_.challenge_gate_passed
    }).Count -eq 3 -and
    @($candidateBNoise | Where-Object {
        [int]$_.observation_fault_application_count -eq 3232 -and
        [int]$_.observation_fault_base_and_stability_count -eq 3232 -and
        [double]$_.maximum_observation_fault_component -eq 0.02 -and
        [bool]$_.challenge_gate_passed
    }).Count -eq 3
) "$gateId legacy parent-field projection failure changed"

$failedGates = @($evaluation.gates | Where-Object { -not [bool]$_.passed })
Assert-Exact (
    [string]$evaluation.schema_version -ceq
        "sporespore_balanced_wave_bw31n_authority_horizon_evaluation_v1" -and
    -not [bool]$evaluation.ok -and
    [string]$evaluation.status -ceq "invalid_or_incomplete" -and
    [string]$evaluation.campaign_id -ceq $campaignId -and
    [string]$evaluation.attempt_id -ceq $attemptId -and
    [int]$evaluation.observed_world_count -eq 24 -and
    [int]$evaluation.evaluated_cell_count -eq 24 -and
    @($evaluation.missing_cell_ids).Count -eq 0 -and
    @($evaluation.duplicate_cell_ids).Count -eq 0 -and
    @($evaluation.unexpected_cell_ids).Count -eq 0 -and
    [int]$evaluation.passed_gate_count -eq 10 -and
    [int]$evaluation.failed_gate_count -eq 5 -and
    [int]$evaluation.expected_gate_count -eq 15 -and
    (Test-SequenceEqual -Actual @($evaluation.failure_codes) -Expected @(
        "BW31N_IDENTITY_INVALID",
        "BW31N_CHALLENGE_INVALID",
        "BW31N_APPLICATION_INVALID",
        "BW31N_OUTCOME_INCOMPLETE",
        "BW31N_DEVELOPMENT_RESULT_INVALID"
    )) -and
    (Test-SequenceEqual `
        -Actual @($failedGates | ForEach-Object { [string]$_.gate_id }) `
        -Expected @(
            "exact_identities",
            "challenge_realization",
            "candidate_application",
            "outcome_complete",
            "complete_development_result"
        )) -and
    -not [bool]$evaluation.strict_total_improvement_passed -and
    [bool]$evaluation.per_axis_non_regression_passed -and
    [string]$evaluation.selected_candidate_id -ceq "NONE" -and
    -not [bool]$evaluation.fresh_nuisance_validation_ready -and
    -not [bool]$evaluation.walking_acceptance -and
    -not [bool]$evaluation.nuisance_acceptance -and
    -not [bool]$evaluation.release_authorized -and
    -not [bool]$evaluation.completed_engine_neutral_sdk -and
    -not [bool]$evaluation.physical_acceptance_authority
) "$gateId frozen evaluator result or claim boundary changed"

function Get-FalseWalkingSubreceipts {
    param([Parameter(Mandatory)]$Receipt)
    return @(
        $Receipt.walking_gate_receipts.GetEnumerator() |
            Where-Object { $_.Value -is [bool] -and -not [bool]$_.Value } |
            ForEach-Object { [string]$_.Key } |
            Sort-Object
    )
}
$descriptiveAComplete = @($candidateA | Where-Object {
    @(Get-FalseWalkingSubreceipts -Receipt $_).Count -eq 0
})
$descriptiveBComplete = @($candidateB | Where-Object {
    @(Get-FalseWalkingSubreceipts -Receipt $_).Count -eq 0
})
$expectedDescriptiveFailures = [ordered]@{
    "rough_s21001_bw31n_a" = @(
        "contact_gating_completed_without_timeout",
        "every_limb_two_contact_cycles"
    )
    "rough_s21002_bw31n_a" = @("contact_gating_completed_without_timeout")
    "rough_s21002_bw31n_b" = @(
        "bounded_tilt",
        "bounded_torso_height",
        "contact_gated_evidence_horizon_completed",
        "contact_gating_completed_without_timeout",
        "every_limb_completed_evidence_gait_horizon",
        "minimum_evidence_forward_translation",
        "terminal_four_contact_recovery",
        "zero_torso_contact"
    )
    "rough_s21003_bw31n_b" = @(
        "bounded_lateral_drift",
        "contact_gating_completed_without_timeout"
    )
    "push_s21003_bw31n_a" = @("bounded_lateral_drift")
}
foreach ($entry in $expectedDescriptiveFailures.GetEnumerator()) {
    $receipt = @($receipts | Where-Object { [string]$_.cell_id -ceq $entry.Key })[0]
    Assert-Exact (
        Test-SequenceEqual `
            -Actual @(Get-FalseWalkingSubreceipts -Receipt $receipt) `
            -Expected @($entry.Value | Sort-Object)
    ) "$gateId descriptive walking subreceipt set changed: $($entry.Key)"
}
Assert-Exact (
    $descriptiveAComplete.Count -eq 9 -and
    $descriptiveBComplete.Count -eq 10 -and
    @($receipts | Where-Object {
        @(Get-FalseWalkingSubreceipts -Receipt $_).Count -gt 0
    }).Count -eq 5 -and
    [bool]$closure.descriptive_observations_without_selection_authority.candidate_b_had_one_fewer_descriptive_incomplete_walking_cell -and
    [bool]$closure.descriptive_observations_without_selection_authority.descriptive_profile_failure_counts_did_not_regress_for_candidate_b -and
    [bool]$closure.descriptive_observations_without_selection_authority.descriptive_comparison_has_no_selection_or_superiority_authority -and
    [bool]$closure.descriptive_observations_without_selection_authority.not_a_valid_locomotion_negative -and
    -not [bool]$closure.descriptive_observations_without_selection_authority.candidate_b_selected -and
    -not [bool]$closure.descriptive_observations_without_selection_authority.candidate_b_promoted
) "$gateId descriptive non-authoritative observations changed"

Assert-Exact (
    [string]$report.schema_version -ceq
        "sporespore_balanced_wave_bw31n_authority_horizon_report_v1" -and
    [string]$report.campaign_id -ceq $campaignId -and
    [string]$report.source_commit -ceq $sourceCommit -and
    [string]$report.attempt_raw_sha256 -ceq
        [string]$closure.retained_evidence.attempt.raw_sha256 -and
    [string]$report.evaluation_input_raw_sha256 -ceq
        [string]$closure.retained_evidence.evaluation_input.raw_sha256 -and
    [string]$report.evaluation_raw_sha256 -ceq
        [string]$closure.retained_evidence.original_evaluation.raw_sha256 -and
    @($report.cell_attempts).Count -eq 24 -and
    @($report.cell_attempts | Where-Object { [int]$_.process_exit_code -eq 1 }).Count -eq 24 -and
    @($report.cell_attempts | Where-Object { [bool]$_.timed_out }).Count -eq 0 -and
    @($report.cell_attempts | Where-Object { [bool]$_.killed_process_tree }).Count -eq 0 -and
    @($report.cell_attempts | Where-Object { [bool]$_.receipt_parsed }).Count -eq 24 -and
    -not [bool]$report.evaluation.ok -and
    [string]$report.selected_candidate_id -ceq "NONE" -and
    -not [bool]$report.fresh_nuisance_validation_ready -and
    -not [bool]$report.physical_acceptance_authority -and
    [string]$completion.schema_version -ceq
        "sporespore_balanced_wave_bw31n_authority_horizon_completion_v1" -and
    [string]$completion.campaign_id -ceq $campaignId -and
    [string]$completion.source_commit -ceq $sourceCommit -and
    [string]$completion.report_raw_sha256 -ceq
        [string]$closure.retained_evidence.original_report.raw_sha256 -and
    -not [bool]$completion.valid_complete_result -and
    [string]$completion.selected_candidate_id -ceq "NONE" -and
    [int]$completion.attempted_world_count -eq 24 -and
    [int]$completion.passed_gate_count -eq 10 -and
    [int]$completion.failed_gate_count -eq 5 -and
    -not [bool]$completion.same_identity_rerun_allowed -and
    -not [bool]$completion.physical_acceptance_authority
) "$gateId report or completion retention contract changed"

$priorAttempts = @(
    Get-ChildItem -LiteralPath $evidenceBase -Filter attempt.json -File -Recurse |
        Where-Object {
            try {
                $candidate = Get-Content -Raw -LiteralPath $_.FullName |
                    ConvertFrom-Json -AsHashtable -Depth 100
                [string]$candidate.campaign_id -ceq $campaignId
            } catch { $false }
        }
)
Assert-Exact (
    $priorAttempts.Count -eq 1 -and
    [System.IO.Path]::GetFullPath($priorAttempts[0].FullName) -ceq
        [System.IO.Path]::GetFullPath((Join-Path $evidenceRoot "attempt.json")) -and
    [bool]$closure.immutability.first_attempt_is_final_for_source_identity -and
    [bool]$closure.immutability.physical_identity_consumed -and
    [bool]$closure.immutability.same_identity_rerun_forbidden -and
    [bool]$closure.immutability.posthoc_reclassification_forbidden -and
    [bool]$closure.immutability.successor_requires_new_campaign_source_preregistration_and_evidence_identity
) "$gateId immutable one-shot closure changed"

Assert-Exact (
    @($closure.claim_boundary.GetEnumerator() | Where-Object { [bool]$_.Value }).Count -eq 0 -and
    [bool]$closure.successor_requirements.new_campaign_id_gate_id_source_identity_preregistration_and_evidence_root -and
    [bool]$closure.successor_requirements.same_bw31n_identity_may_not_be_repaired_or_rerun -and
    [bool]$closure.successor_requirements.candidate_application_must_be_recomputed_from_3232_authority_tick_primitive_counts -and
    [bool]$closure.successor_requirements.outcome_completeness_must_not_inherit_a_legacy_fixed_world_horizon_aggregate -and
    [bool]$closure.successor_requirements.sensor_noise_challenge_must_be_recomputed_from_3232_direct_application_counts -and
    [bool]$closure.successor_requirements.common_execution_integrity_must_not_inherit_legacy_parent_campaign_booleans -and
    [bool]$closure.successor_requirements.actual_dynamic_reference_and_successor_receipts_must_traverse_the_shared_composer_and_complete_evaluator_before_one_shot_physics -and
    [bool]$closure.successor_requirements.repeatable_noncampaign_regression_physics_must_exercise_the_long_horizon_parent_summary_projection_after_zero_world_gates -and
    (Test-SequenceEqual `
        -Actual @($closure.successor_requirements.fresh_reserved_seeds) `
        -Expected @(49101, 49102, 49103)) -and
    [bool]$closure.successor_requirements.fresh_reserved_seeds_remain_unopened_by_bw31n -and
    [bool]$closure.successor_requirements.fresh_reserved_seeds_remain_reserved_for_independent_validation_after_a_valid_development_selection -and
    -not [bool]$closure.descriptive_observations_without_selection_authority.candidate_b_selected
) "$gateId claim or successor boundary changed"

Write-Host (
    "BW31N_AUTHORITY_HORIZON_CLOSURE_PASS status=implementation-invalid " +
    "worlds=24 parsed=24 logs=24 gates=10/15 horizon=24/24 " +
    "a_identity=12/12 b_identity=0/12 a_application=12/12 b_application=0/12 " +
    "integrity=0/24 descriptive_subreceipts=9/12,10/12 selector=NONE " +
    "selection_authority=False nuisance_authority=False physical_authority=False " +
    "rerun_refused=True"
)
