#requires -Version 7.0

[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [System.IO.Path]::GetFullPath(
    (Split-Path -Parent $PSScriptRoot)
)
$sdkRoot = Join-Path $repoRoot "sdk"
$campaignId = "BW30N-BW29N-IMPLEMENTATION-RECOVERY-DEVELOPMENT"
$gateId = "BW30N"
$sourceCommit = "08c06bf367dac2d4b4c8a08f2d16ae8aee39a0b3"
$sourceTree = "af53e49a0c49f8f154d5421e2dff193be6571ceb"
$attemptId = "347bdc758ff24050ae48a8421e3f7723"
$closurePath = Join-Path $sdkRoot "balanced_wave_bw30n_recovery_closure.json"
$expectedClosureSha256 = (
    "6d5a8a2e8d76fddb95b48a8554fcc1135c5a93199a3978c095a2e1960747d9df"
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

function Get-Bw30nClosureRawSha256 {
    param([Parameter(Mandatory)][string]$Path)
    return (
        Get-FileHash -Algorithm SHA256 -LiteralPath $Path
    ).Hash.ToLowerInvariant()
}

function Get-ByteSha256 {
    param([Parameter(Mandatory)][byte[]]$Bytes)
    return [Convert]::ToHexString(
        [Security.Cryptography.SHA256]::HashData($Bytes)
    ).ToLowerInvariant()
}

function Get-GitBlobBytes {
    param([Parameter(Mandatory)][string]$ObjectId)
    $startInfo = [Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = "git"
    $startInfo.WorkingDirectory = $repoRoot
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    foreach ($argument in @("cat-file", "blob", $ObjectId)) {
        [void]$startInfo.ArgumentList.Add($argument)
    }
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $startInfo
    $buffer = [IO.MemoryStream]::new()
    try {
        Assert-Exact $process.Start() (
            "$gateId failed to read historical Git blob $ObjectId"
        )
        $process.StandardOutput.BaseStream.CopyTo($buffer)
        $stderr = $process.StandardError.ReadToEnd()
        $process.WaitForExit()
        Assert-Exact ($process.ExitCode -eq 0) (
            "$gateId failed to read historical Git blob ${ObjectId}: $stderr"
        )
        return $buffer.ToArray()
    } finally {
        $buffer.Dispose()
        $process.Dispose()
    }
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
        (Get-Bw30nClosureRawSha256 -Path $path) -ceq
            [string]$Artifact.raw_sha256
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
                    (Get-Bw30nClosureRawSha256 -Path $_.FullName)
                )
            } |
            Sort-Object
    )
    $text = ($rows -join "`n") + "`n"
    return [ordered]@{
        file_count = $files.Count
        total_byte_length = [long](
            $files | Measure-Object -Property Length -Sum
        ).Sum
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

Assert-Exact (
    (Test-Path -LiteralPath $closurePath -PathType Leaf) -and
    (Get-Bw30nClosureRawSha256 -Path $closurePath) -ceq
        $expectedClosureSha256
) "$gateId closure is missing or changed"
$closure = Get-Content -Raw -LiteralPath $closurePath |
    ConvertFrom-Json -AsHashtable -Depth 100

Assert-Exact (
    [string]$closure.schema_version -ceq
        "sporespore_balanced_wave_bw30n_recovery_closure_v1" -and
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
    (git -C $repoRoot rev-parse "${sourceCommit}^{tree}").Trim() -ceq
        $sourceTree
) "$gateId experiment source tree changed"
foreach ($binding in $closure.exact_source_bindings.GetEnumerator()) {
    $relativePath = ([string]$binding.Value.path).Replace("\", "/")
    $commitBlobOid = (& git -C $repoRoot rev-parse (
        "${sourceCommit}:$relativePath"
    )).Trim()
    $commitBlobExitCode = $LASTEXITCODE
    $historicalBytes = Get-GitBlobBytes -ObjectId (
        [string]$binding.Value.git_blob_oid
    )
    Assert-Exact (
        $commitBlobExitCode -eq 0 -and
        $commitBlobOid -ceq [string]$binding.Value.git_blob_oid -and
        (Get-ByteSha256 -Bytes $historicalBytes) -ceq
            [string]$binding.Value.raw_sha256
    ) "$gateId frozen source binding changed: $($binding.Key)"
}

$evidenceRoot = [System.IO.Path]::GetFullPath(
    [string]$closure.retained_evidence.root
)
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
    Assert-HashedArtifact `
        -Root $evidenceRoot `
        -Artifact $entry[0] `
        -Label $entry[1]
}
$tree = Get-EvidenceTreeDigest -Root $evidenceRoot
Assert-Exact (
    [int]$tree.file_count -eq
        [int]$closure.retained_evidence.tree.file_count -and
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
    (Get-Bw30nClosureRawSha256 -Path $attestationPath) -ceq
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
    -not [bool]$attestation.claims.walking_acceptance -and
    -not [bool]$attestation.claims.release_authorized -and
    -not [bool]$attestation.claims.completed_engine_neutral_sdk -and
    -not [bool]$attestation.claims.physical_acceptance_authority
) "$gateId exact-source attestation identity or claim boundary changed"

$attempt = Get-Content -Raw -LiteralPath (Join-Path $evidenceRoot "attempt.json") |
    ConvertFrom-Json -AsHashtable -Depth 100
$input = Get-Content -Raw -LiteralPath (
    Join-Path $evidenceRoot "evaluation-input.json"
) | ConvertFrom-Json -AsHashtable -Depth 100
$evaluation = Get-Content -Raw -LiteralPath (
    Join-Path $evidenceRoot "evaluation.json"
) | ConvertFrom-Json -AsHashtable -Depth 100
$report = Get-Content -Raw -LiteralPath (Join-Path $evidenceRoot "report.json") |
    ConvertFrom-Json -AsHashtable -Depth 100
$completion = Get-Content -Raw -LiteralPath (
    Join-Path $evidenceRoot "completion.json"
) | ConvertFrom-Json -AsHashtable -Depth 100

Assert-Exact (
    [string]$attempt.schema_version -ceq
        "sporespore_balanced_wave_bw30n_recovery_attempt_v1" -and
    [string]$attempt.campaign_id -ceq $campaignId -and
    [string]$attempt.gate_id -ceq $gateId -and
    [string]$attempt.attempt_id -ceq $attemptId -and
    [string]$attempt.source_commit -ceq $sourceCommit -and
    [string]$attempt.origin_main_commit -ceq $sourceCommit -and
    [string]$attempt.remote_main_commit -ceq $sourceCommit -and
    [bool]$attempt.source_worktree_clean -and
    [bool]$attempt.source_matches_live_github_main -and
    [bool]$attempt.complete_zero_world_gate_passed -and
    [bool]$attempt.stage_one_freeze_verified -and
    [bool]$attempt.physical_identity_consumed -and
    -not [bool]$attempt.same_identity_rerun_allowed -and
    [int]$attempt.expected_world_count -eq 24 -and
    @($attempt.ordered_cell_ids).Count -eq 24 -and
    @($attempt.primary_world_attempt_ids).Count -eq 24
) "$gateId retained attempt identity or authorization changed"

$receipts = @($input.cell_receipts)
$expectedKeys = @($receipts[0].Keys | Sort-Object)
$allKeySetsExact = $true
foreach ($receipt in $receipts) {
    if (-not (Test-SequenceEqual `
        -Actual @($receipt.Keys | Sort-Object) `
        -Expected $expectedKeys)) {
        $allKeySetsExact = $false
    }
}
$candidateA = @($receipts | Where-Object { [string]$_.candidate_id -ceq "BW30N-A" })
$candidateB = @($receipts | Where-Object { [string]$_.candidate_id -ceq "BW30N-B" })
$candidateANoise = @($candidateA | Where-Object {
    [string]$_.challenge_profile_id -ceq "bw6n_sensor_noise_v1"
})
$candidateBNoise = @($candidateB | Where-Object {
    [string]$_.challenge_profile_id -ceq "bw6n_sensor_noise_v1"
})
Assert-Exact (
    [string]$input.schema_version -ceq
        "sporespore_balanced_wave_bw30n_recovery_evaluation_input_v1" -and
    [string]$input.attempt_id -ceq $attemptId -and
    $receipts.Count -eq 24 -and
    $candidateA.Count -eq 12 -and
    $candidateB.Count -eq 12 -and
    $allKeySetsExact -and
    @($receipts | Where-Object {
        [string]$_.material_profile_sha256 -ceq $materialProfileSha256
    }).Count -eq 24 -and
    @($receipts | Where-Object {
        [int]$_.post_sdk_observation_count -eq 1514 -and
        [int]$_.first_post_sdk_observation_index -eq 0 -and
        [int]$_.last_post_sdk_observation_index -eq 1513 -and
        [int]$_.candidate_specific_horizon_extension_count -eq 0
    }).Count -eq 24 -and
    @($receipts | Where-Object { [bool]$_.measurement_gate_passed }).Count -eq 24 -and
    @($receipts | Where-Object { [bool]$_.application_gate_passed }).Count -eq 24 -and
    @($receipts | Where-Object { [bool]$_.outcome_complete }).Count -eq 24 -and
    @($receipts | Where-Object { [bool]$_.common_execution_integrity }).Count -eq 12 -and
    @($candidateA | Where-Object { [bool]$_.common_execution_integrity }).Count -eq 0 -and
    @($candidateB | Where-Object { [bool]$_.common_execution_integrity }).Count -eq 12 -and
    @($candidateA | Where-Object { [bool]$_.challenge_gate_passed }).Count -eq 9 -and
    @($candidateB | Where-Object { [bool]$_.challenge_gate_passed }).Count -eq 12 -and
    @($receipts | Where-Object { [bool]$_.walking_observed }).Count -eq 0
) "$gateId retained receipt matrix or repaired-contract observations changed"
Assert-Exact (
    (Test-SequenceEqual `
        -Actual @($candidateANoise | ForEach-Object {
            [int]$_.observation_fault_application_count
        }) `
        -Expected @(1042, 1042, 1042)) -and
    (Test-SequenceEqual `
        -Actual @($candidateANoise | ForEach-Object {
            [int]$_.observation_fault_base_and_stability_count
        }) `
        -Expected @(1042, 1042, 1042)) -and
    (Test-SequenceEqual `
        -Actual @($candidateBNoise | ForEach-Object {
            [int]$_.observation_fault_application_count
        }) `
        -Expected @(1514, 1514, 1514)) -and
    (Test-SequenceEqual `
        -Actual @($candidateBNoise | ForEach-Object {
            [int]$_.observation_fault_base_and_stability_count
        }) `
        -Expected @(1514, 1514, 1514))
) "$gateId candidate-authority exposure diagnosis changed"

$failedGates = @($evaluation.gates | Where-Object { -not [bool]$_.passed })
Assert-Exact (
    [string]$evaluation.schema_version -ceq
        "sporespore_balanced_wave_bw30n_recovery_evaluation_v1" -and
    -not [bool]$evaluation.ok -and
    [string]$evaluation.status -ceq "invalid_or_incomplete" -and
    [string]$evaluation.campaign_id -ceq $campaignId -and
    [string]$evaluation.attempt_id -ceq $attemptId -and
    [int]$evaluation.observed_world_count -eq 24 -and
    [int]$evaluation.evaluated_cell_count -eq 24 -and
    @($evaluation.missing_cell_ids).Count -eq 0 -and
    @($evaluation.duplicate_cell_ids).Count -eq 0 -and
    @($evaluation.unexpected_cell_ids).Count -eq 0 -and
    [int]$evaluation.passed_gate_count -eq 12 -and
    [int]$evaluation.failed_gate_count -eq 2 -and
    [int]$evaluation.expected_gate_count -eq 14 -and
    (Test-SequenceEqual `
        -Actual @($evaluation.failure_codes) `
        -Expected @(
            "BW30N_CHALLENGE_INVALID",
            "BW30N_DEVELOPMENT_RESULT_INVALID"
        )) -and
    (Test-SequenceEqual `
        -Actual @($failedGates | ForEach-Object { [string]$_.gate_id }) `
        -Expected @("challenge_realization", "complete_development_result")) -and
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

$summaryA = @($evaluation.candidate_summaries | Where-Object {
    [string]$_.candidate_id -ceq "BW30N-A"
})[0]
$summaryB = @($evaluation.candidate_summaries | Where-Object {
    [string]$_.candidate_id -ceq "BW30N-B"
})[0]
Assert-Exact (
    [int]$summaryA.cell_count -eq 12 -and
    [int]$summaryA.integrity_pass_count -eq 0 -and
    [int]$summaryA.walking_pass_count -eq 0 -and
    [int]$summaryA.walking_failure_count -eq 12 -and
    [int]$summaryB.cell_count -eq 12 -and
    [int]$summaryB.integrity_pass_count -eq 12 -and
    [int]$summaryB.walking_pass_count -eq 0 -and
    [int]$summaryB.walking_failure_count -eq 12 -and
    @($evaluation.cell_evaluations | Where-Object {
        -not [bool]$_.walking_observed
    }).Count -eq 24 -and
    @($receipts | Where-Object {
        -not [bool]$_.walking_gate_receipts.every_limb_completed_evidence_gait_horizon
    }).Count -eq 24
) "$gateId descriptive non-authoritative locomotion observations changed"

Assert-Exact (
    [string]$report.schema_version -ceq
        "sporespore_balanced_wave_bw30n_recovery_report_v1" -and
    [string]$report.campaign_id -ceq $campaignId -and
    [string]$report.source_commit -ceq $sourceCommit -and
    [string]$report.attempt_raw_sha256 -ceq
        [string]$closure.retained_evidence.attempt.raw_sha256 -and
    [string]$report.evaluation_input_raw_sha256 -ceq
        [string]$closure.retained_evidence.evaluation_input.raw_sha256 -and
    [string]$report.evaluation_raw_sha256 -ceq
        [string]$closure.retained_evidence.original_evaluation.raw_sha256 -and
    -not [bool]$report.evaluation.ok -and
    [string]$report.selected_candidate_id -ceq "NONE" -and
    -not [bool]$report.fresh_nuisance_validation_ready -and
    -not [bool]$report.physical_acceptance_authority -and
    [string]$completion.schema_version -ceq
        "sporespore_balanced_wave_bw30n_recovery_completion_v1" -and
    [string]$completion.campaign_id -ceq $campaignId -and
    [string]$completion.source_commit -ceq $sourceCommit -and
    [string]$completion.report_raw_sha256 -ceq
        [string]$closure.retained_evidence.original_report.raw_sha256 -and
    -not [bool]$completion.valid_complete_result -and
    [string]$completion.selected_candidate_id -ceq "NONE" -and
    [int]$completion.attempted_world_count -eq 24 -and
    [int]$completion.passed_gate_count -eq 12 -and
    [int]$completion.failed_gate_count -eq 2 -and
    -not [bool]$completion.same_identity_rerun_allowed -and
    -not [bool]$completion.physical_acceptance_authority
) "$gateId report or completion retention contract changed"

$priorAttempts = @(Get-ChildItem -LiteralPath $evidenceBase -Filter attempt.json -File -Recurse |
    Where-Object {
        try {
            $candidate = Get-Content -Raw -LiteralPath $_.FullName |
                ConvertFrom-Json -AsHashtable -Depth 100
            [string]$candidate.campaign_id -ceq $campaignId
        } catch { $false }
    })
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

$falseClaimCount = @(
    $closure.claim_boundary.GetEnumerator() |
        Where-Object { [bool]$_.Value }
).Count
Assert-Exact (
    $falseClaimCount -eq 0 -and
    [bool]$closure.successor_requirements.new_campaign_id_gate_id_source_identity_preregistration_and_evidence_root -and
    [bool]$closure.successor_requirements.same_bw30n_identity_may_not_be_repaired_or_rerun -and
    [bool]$closure.successor_requirements.fixed_horizon_must_be_anchored_to_exact_candidate_authority_exposure -and
    [bool]$closure.successor_requirements.pre_authority_support_acquisition_must_not_consume_candidate_exposure_budget -and
    [bool]$closure.successor_requirements.challenge_application_count_must_be_exact_and_candidate_independent -and
    [bool]$closure.successor_requirements.horizon_must_be_long_enough_for_the_frozen_every_limb_evidence_schedule_without_posthoc_extension -and
    (Test-SequenceEqual `
        -Actual @($closure.successor_requirements.fresh_reserved_seeds) `
        -Expected @(49101, 49102, 49103))
) "$gateId claim or successor boundary changed"

Write-Host (
    "BW30N_RECOVERY_CLOSURE_PASS status=implementation-invalid worlds=24 " +
    "parsed=24 logs=24 gates=12/14 schemas=1 horizon=24/24 " +
    "a_integrity=0/12 b_integrity=12/12 a_noise=1042 b_noise=1514 " +
    "walking_descriptive=0/12,0/12 selector=NONE valid_none=False " +
    "selection_authority=False nuisance_authority=False physical_authority=False " +
    "rerun_refused=True"
)
