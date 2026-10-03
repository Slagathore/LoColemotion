#requires -Version 7.0

[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [System.IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$sdkRoot = Join-Path $repoRoot "sdk"
$campaignId = "BW21L-MATERIAL-LATERAL-DEVELOPMENT"
$gateId = "BW21L"
$sourceCommit = "ca13b430f73dfdc1bece46564bc758a813347dbc"
$closurePath = Join-Path (
    $sdkRoot
) "balanced_wave_bw21l_lateral_development_closure.json"
$expectedClosureSha256 =
    "d592e160c1111d05047a545986099ce957226a8d12e81d19013930133b98af4b"
$runnerPath = Join-Path (
    $sdkRoot
) "run_balanced_wave_bw21l_lateral_development.ps1"

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

function Assert-HashedArtifact {
    param(
        [Parameter(Mandatory)][string]$Root,
        [Parameter(Mandatory)]$Artifact,
        [Parameter(Mandatory)][string]$Label
    )
    $path = Join-Path $Root ([string]$Artifact.path)
    Assert-Exact (
        (Test-Path -LiteralPath $path -PathType Leaf) -and
        (Get-Item -LiteralPath $path).Length -eq
            [long]$Artifact.byte_length -and
        (Get-RawSha256 -Path $path) -ceq
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
                $hash = Get-RawSha256 -Path $_.FullName
                "{0}`t{1}`t{2}" -f $relative, $_.Length, $hash
            } |
            Sort-Object
    )
    $text = ($rows -join "`n") + "`n"
    $digest = [Convert]::ToHexString(
        [Security.Cryptography.SHA256]::HashData(
            [Text.Encoding]::UTF8.GetBytes($text)
        )
    ).ToLowerInvariant()
    return [ordered]@{
        file_count = $files.Count
        total_byte_length = [long](
            $files | Measure-Object -Property Length -Sum
        ).Sum
        tree_sha256 = $digest
    }
}

function Get-FalseBooleanNames {
    param([Parameter(Mandatory)][System.Collections.IDictionary]$Values)
    return @(
        $Values.GetEnumerator() |
            Where-Object { -not [bool]$_.Value } |
            ForEach-Object { [string]$_.Key } |
            Sort-Object
    )
}

function Test-Near {
    param([double]$Actual, [double]$Expected)
    return (
        [double]::IsFinite($Actual) -and
        [double]::IsFinite($Expected) -and
        [math]::Abs($Actual - $Expected) -le 0.000000000001
    )
}

Assert-Exact (
    (Test-Path -LiteralPath $closurePath -PathType Leaf) -and
    (Get-RawSha256 -Path $closurePath) -ceq $expectedClosureSha256
) "$gateId closure is missing or changed"
$closure = Get-Content -Raw -LiteralPath $closurePath |
    ConvertFrom-Json -AsHashtable

Assert-Exact (
    [string]$closure.schema_version -ceq
        "sporespore_balanced_wave_bw21l_lateral_development_closure_v1" -and
    [string]$closure.status -ceq
        "closed_invalid_inherited_policy_identity_gate" -and
    [string]$closure.campaign_id -ceq $campaignId -and
    [string]$closure.gate_id -ceq $gateId -and
    [string]$closure.experiment_source_commit -ceq $sourceCommit -and
    [bool]$closure.source_was_clean_and_equal_to_origin_and_live_github_main -and
    -not [bool]$closure.disposition.infrastructure_valid -and
    -not [bool]$closure.disposition.development_result_valid -and
    [string]$closure.complete_attempt.selected_candidate_id -ceq "NONE" -and
    -not [bool]$closure.complete_attempt.development_selection_authority -and
    [bool]$closure.disposition.not_a_locomotion_negative -and
    [bool]$closure.disposition.not_a_valid_none_selection -and
    [bool]$closure.execution_defect.present -and
    -not [bool]$closure.execution_defect.production_controller_or_adapter_defect -and
    [bool]$closure.immutability.same_identity_rerun_forbidden -and
    [bool]$closure.immutability.posthoc_selection_forbidden -and
    [bool]$closure.immutability.posthoc_positive_reclassification_forbidden -and
    [bool]$closure.immutability.retained_artifact_rewrite_forbidden
) "$gateId closure identity, invalid disposition, or immutability changed"

& git -C $repoRoot cat-file -e "$sourceCommit`^{commit}"
Assert-Exact ($LASTEXITCODE -eq 0) "$gateId source commit is not retained"
& git -C $repoRoot merge-base --is-ancestor $sourceCommit HEAD
Assert-Exact ($LASTEXITCODE -eq 0) "$gateId source is not an ancestor of HEAD"
$originMain = (& git -C $repoRoot rev-parse origin/main).Trim()
Assert-Exact ($LASTEXITCODE -eq 0) "$gateId origin/main could not be resolved"
& git -C $repoRoot merge-base --is-ancestor $sourceCommit $originMain
Assert-Exact ($LASTEXITCODE -eq 0) "$gateId source is not retained on origin/main"

foreach ($binding in @($closure.frozen_source_blobs.Values)) {
    $relativePath = [string]$binding.path
    $blobSpec = "$sourceCommit`:$relativePath"
    $blobOid = (& git -C $repoRoot rev-parse $blobSpec).Trim()
    Assert-Exact (
        $LASTEXITCODE -eq 0 -and
        $blobOid -ceq [string]$binding.git_blob_oid -and
        [string]$binding.raw_sha256 -cmatch "^[0-9a-f]{64}$"
    ) "$gateId frozen Git blob changed: $relativePath"
    # The raw hash is retained as a historical checkout receipt. The audit
    # deliberately does not compare it to a mutable, filter-dependent checkout.
}

$composerBinding = $closure.frozen_source_blobs.defective_common_execution_parent_worker
$composerSource = (& git -C $repoRoot show (
    "$sourceCommit`:$([string]$composerBinding.path)"
) | Out-String)
Assert-Exact (
    $composerSource.Contains(
        'String(sdk_summary.get("controller_policy_id", "")) == BW15F_CONTROLLER_POLICY_ID',
        [StringComparison]::Ordinal
    ) -and
    $composerSource.Contains(
        'receipt["controller_policy_id"] = BW15F_CONTROLLER_POLICY_ID',
        [StringComparison]::Ordinal
    )
) "$gateId historical hard-coded receipt identity defect changed"

$evidenceRoot = [System.IO.Path]::GetFullPath(
    [string]$closure.retained_evidence.root
)
Assert-Exact (
    $evidenceRoot -ceq
        "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence\" +
        "balanced-wave-bw21l-lateral-development-ca13b43"
) "$gateId retained evidence root changed"
foreach ($name in @(
    "attempt",
    "completion",
    "evaluation",
    "raw_result",
    "primary_report"
)) {
    Assert-HashedArtifact `
        -Root $evidenceRoot `
        -Artifact $closure.retained_evidence[$name] `
        -Label $name
}
$tree = Get-EvidenceTreeDigest -Root $evidenceRoot
Assert-Exact (
    [string]$closure.retained_evidence.tree.algorithm -ceq
        "sha256_utf8_sorted_relative_path_tab_bytes_tab_raw_sha256_lf_v1" -and
    [int]$tree.file_count -eq 164 -and
    [int]$tree.file_count -eq [int]$closure.retained_evidence.tree.file_count -and
    [long]$tree.total_byte_length -eq 3003930 -and
    [long]$tree.total_byte_length -eq
        [long]$closure.retained_evidence.tree.total_byte_length -and
    [string]$tree.tree_sha256 -ceq
        [string]$closure.retained_evidence.tree.tree_sha256
) "$gateId complete retained evidence tree changed"

$cellDirectories = @(
    Get-ChildItem -LiteralPath $evidenceRoot -Directory -Filter "cell-*"
)
Assert-Exact ($cellDirectories.Count -eq 53) "$gateId must retain 53 cell directories"
foreach ($directory in $cellDirectories) {
    $relativeFiles = @(
        Get-ChildItem -LiteralPath $directory.FullName -File -Recurse |
            ForEach-Object {
                [System.IO.Path]::GetRelativePath(
                    $directory.FullName,
                    $_.FullName
                ).Replace("\", "/")
            } |
            Sort-Object
    )
    Assert-Exact (
        ($relativeFiles -join "|") -ceq
            "appdata/Godot/app_userdata/sporespore/logs/godot.log|stderr.log|transcript.log"
    ) "$gateId cell artifact surface changed: $($directory.Name)"
}

$attemptPath = Join-Path $evidenceRoot "attempt.json"
$completionPath = Join-Path $evidenceRoot "completion.json"
$evaluationPath = Join-Path $evidenceRoot "evaluation.json"
$rawResultPath = Join-Path $evidenceRoot "raw-result.json"
$reportPath = Join-Path $evidenceRoot "report.json"
$attempt = Get-Content -Raw -LiteralPath $attemptPath |
    ConvertFrom-Json -AsHashtable
$completion = Get-Content -Raw -LiteralPath $completionPath |
    ConvertFrom-Json -AsHashtable
$evaluation = Get-Content -Raw -LiteralPath $evaluationPath |
    ConvertFrom-Json -AsHashtable
$rawResult = Get-Content -Raw -LiteralPath $rawResultPath |
    ConvertFrom-Json -AsHashtable
$report = Get-Content -Raw -LiteralPath $reportPath |
    ConvertFrom-Json -AsHashtable

Assert-Exact (
    [string]$attempt.schema_version -ceq
        "sporespore_balanced_wave_bw21l_lateral_development_attempt_v1" -and
    [string]$attempt.campaign_id -ceq $campaignId -and
    [string]$attempt.gate_id -ceq $gateId -and
    [string]$attempt.source_commit -ceq $sourceCommit -and
    [bool]$attempt.source_worktree_clean -and
    [bool]$attempt.source_matches_live_github_main -and
    [bool]$attempt.complete_zero_world_gate_passed -and
    [bool]$attempt.authority_contract_passed -and
    [int]$attempt.expected_world_count -eq 53 -and
    @($attempt.ordered_cell_ids).Count -eq 53 -and
    [bool]$attempt.physical_identity_consumed -and
    -not [bool]$attempt.same_identity_rerun_allowed -and
    [int]$attempt.completed_cell_attempt_count -eq 53 -and
    [int]$attempt.parsed_receipt_count -eq 53 -and
    [int]$attempt.integrity_failure_count -eq 0 -and
    -not [bool]$attempt.evaluation_ok
) "$gateId retained attempt changed"

Assert-Exact (
    [string]$completion.schema_version -ceq
        "sporespore_balanced_wave_bw21l_lateral_development_completion_v1" -and
    [string]$completion.campaign_id -ceq $campaignId -and
    [string]$completion.gate_id -ceq $gateId -and
    [string]$completion.source_commit -ceq $sourceCommit -and
    [int]$completion.expected_world_count -eq 53 -and
    [int]$completion.attempted_world_count -eq 53 -and
    [int]$completion.parsed_receipt_count -eq 53 -and
    [int]$completion.integrity_failure_count -eq 0 -and
    -not [bool]$completion.evaluation_ok -and
    [string]$completion.selected_candidate_id -ceq "NONE" -and
    -not [bool]$completion.development_selection_authority -and
    -not [bool]$completion.same_identity_rerun_allowed -and
    -not [bool]$completion.physical_acceptance_authority
) "$gateId retained completion changed"

Assert-Exact (
    [string]$report.schema_version -ceq
        "sporespore_balanced_wave_bw21l_lateral_development_report_v1" -and
    [string]$report.campaign_id -ceq $campaignId -and
    [string]$report.gate_id -ceq $gateId -and
    [string]$report.source_commit -ceq $sourceCommit -and
    [bool]$report.first_complete_result_final_for_source_identity -and
    -not [bool]$report.evaluation_ok -and
    [string]$report.result_status -ceq "invalid_development_execution" -and
    [string]$report.selected_candidate_id -ceq "NONE" -and
    -not [bool]$report.development_selection_authority -and
    [string]$report.attempt_raw_sha256 -ceq
        [string]$closure.retained_evidence.attempt.raw_sha256 -and
    [string]$report.raw_result_raw_sha256 -ceq
        [string]$closure.retained_evidence.raw_result.raw_sha256 -and
    [string]$report.evaluation_raw_sha256 -ceq
        [string]$closure.retained_evidence.evaluation.raw_sha256 -and
    [string]$report.completion_raw_sha256 -ceq
        [string]$closure.retained_evidence.completion.raw_sha256 -and
    -not [bool]$report.physical_acceptance_authority
) "$gateId retained report identity or artifact binding changed"

$cellAttempts = @($report.cell_attempts)
Assert-Exact ($cellAttempts.Count -eq 53) "$gateId must retain 53 cell attempts"
$exitZeroCount = 0
$exitOneCount = 0
foreach ($cellAttempt in $cellAttempts) {
    $ordinal = [int]$cellAttempt.ordinal
    $cellId = [string]$cellAttempt.cell_id
    Assert-Exact (
        $ordinal -ge 1 -and $ordinal -le 53 -and
        -not [bool]$cellAttempt.timed_out -and
        -not [bool]$cellAttempt.killed_process_tree -and
        [bool]$cellAttempt.receipt_parsed -and
        [string]$cellAttempt.receipt_parse_error -ceq ""
    ) "$gateId retained cell attempt integrity changed: $cellId"
    if ([int]$cellAttempt.process_exit_code -eq 0) {
        $exitZeroCount += 1
    } elseif ([int]$cellAttempt.process_exit_code -eq 1) {
        $exitOneCount += 1
    } else {
        throw "$gateId retained unexpected cell exit code: $cellId"
    }
    foreach ($artifactName in @("transcript", "stderr")) {
        $artifactPath = [System.IO.Path]::GetFullPath(
            [string]$cellAttempt["${artifactName}_path"]
        )
        Assert-Exact (
            $artifactPath.StartsWith(
                $evidenceRoot + [System.IO.Path]::DirectorySeparatorChar,
                [StringComparison]::OrdinalIgnoreCase
            ) -and
            (Get-RawSha256 -Path $artifactPath) -ceq
                [string]$cellAttempt["${artifactName}_raw_sha256"]
        ) "$gateId retained cell $artifactName changed: $cellId"
    }
}
Assert-Exact (
    $exitZeroCount -eq 17 -and $exitOneCount -eq 36
) "$gateId retained process-exit partition changed"

Assert-Exact (
    [string]$rawResult.schema_version -ceq
        "sporespore_balanced_wave_bw21l_lateral_development_result_v1" -and
    [string]$rawResult.campaign_id -ceq $campaignId -and
    [string]$rawResult.gate_id -ceq $gateId -and
    [int]$rawResult.expected_gate_count -eq 73 -and
    [int]$rawResult.expected_world_count -eq 53 -and
    [int]$rawResult.observed_world_count -eq 53 -and
    [int]$rawResult.integrity_failure_count -eq 0 -and
    [string]$rawResult.source.commit -ceq $sourceCommit -and
    [bool]$rawResult.source.worktree_clean -and
    [bool]$rawResult.source.matches_live_github_main -and
    [string]$rawResult.engine.physics_engine -ceq "Jolt Physics" -and
    [int]$rawResult.engine.physics_hz -eq 120
) "$gateId retained raw result identity changed"

$temporaryEvaluatorPath = Join-Path (
    [System.IO.Path]::GetTempPath()
) ("sporespore-bw21l-frozen-evaluator-" + [Guid]::NewGuid().ToString("N") + ".ps1")
try {
    $evaluatorRelativePath = [string](
        $closure.frozen_source_blobs.production_evaluator.path
    )
    $sourceLines = @(& git -C $repoRoot show (
        "$sourceCommit`:$evaluatorRelativePath"
    ))
    Assert-Exact (
        $LASTEXITCODE -eq 0 -and $sourceLines.Count -gt 0
    ) "$gateId frozen evaluator could not be materialized"
    [System.IO.File]::WriteAllText(
        $temporaryEvaluatorPath,
        ($sourceLines -join [Environment]::NewLine) + [Environment]::NewLine,
        [System.Text.UTF8Encoding]::new($false)
    )
    . $temporaryEvaluatorPath
    $reconstructed = Test-Bw21lLateralDevelopmentResult -Result $rawResult
} finally {
    if (Test-Path -LiteralPath $temporaryEvaluatorPath) {
        Remove-Item -LiteralPath $temporaryEvaluatorPath -Force
    }
}

$failedGateIds = @(
    $reconstructed.gates |
        Where-Object { -not [bool]$_.passed } |
        ForEach-Object { [string]$_.gate_id }
)
$retainedFailedGateIds = @(
    $evaluation.gates |
        Where-Object { -not [bool]$_.passed } |
        ForEach-Object { [string]$_.gate_id }
)
$failedCellGateIds = @($failedGateIds | Where-Object { $_.StartsWith("cell_") })
$failedAggregateGateIds = @($failedGateIds | Where-Object { -not $_.StartsWith("cell_") })
$expectedAggregateGateIds = @(
    "exact_order_and_role_cardinality",
    "zero_candidate_infrastructure_failures",
    "candidate_mechanism_and_application",
    "all_candidates_complete_before_selection",
    "strict_selection_integrity"
)
Assert-Exact (
    -not [bool]$reconstructed.ok -and
    [int]$reconstructed.reconstructed_passed_gate_count -eq 32 -and
    [int]$reconstructed.reconstructed_failed_gate_count -eq 41 -and
    [int]$reconstructed.cell_pass_count -eq 17 -and
    $failedCellGateIds.Count -eq 36 -and
    ($failedAggregateGateIds -join "|") -ceq ($expectedAggregateGateIds -join "|") -and
    ($failedGateIds -join "|") -ceq ($retainedFailedGateIds -join "|") -and
    (@($reconstructed.failure_codes) -join "|") -ceq
        (@($evaluation.failure_codes) -join "|") -and
    [string]$reconstructed.selected_candidate_id -ceq "NONE" -and
    -not [bool]$reconstructed.development_selection_authority -and
    -not [bool]$reconstructed.physical_acceptance_authority
) "$gateId frozen and reconstructed evaluations diverged"

$cells = @($rawResult.cells)
$candidates = @($cells | Where-Object { [string]$_.role -ceq "candidate" })
$controls = @($cells | Where-Object { [string]$_.role -ceq "control" })
$safety = @($cells | Where-Object { [string]$_.role -ceq "safety" })
Assert-Exact (
    $cells.Count -eq 53 -and
    $candidates.Count -eq 48 -and
    $controls.Count -eq 4 -and
    $safety.Count -eq 1
) "$gateId retained role cardinality changed"

$policyIds = [ordered]@{
    "BW21L-A" = "sporespore_balanced_wave_bw15f_b_v1"
    "BW21L-B" = "sporespore_balanced_wave_bw21l_b_v1"
    "BW21L-C" = "sporespore_balanced_wave_bw21l_c_v1"
    "BW21L-D" = "sporespore_balanced_wave_bw21l_d_v1"
}
foreach ($cell in $candidates) {
    $candidateId = [string]$cell.candidate_id
    $identityExpected = $candidateId -ceq "BW21L-A"
    Assert-Exact (
        $policyIds.Contains($candidateId) -and
        [string]$cell.controller_policy_id -ceq [string]$policyIds[$candidateId] -and
        [bool]$cell.profile_binding_exact -and
        [bool]$cell.mechanism_gate_passed -and
        [bool]$cell.outcome_complete -and
        [bool]$cell.residual_application_observed -and
        [int]$cell.sdk_effective_application_count -gt 0 -and
        [int]$cell.sdk_native_motor_write_count -gt 0 -and
        [int]$cell.sdk_failure_count -eq 0 -and
        [int]$cell.sdk_mismatch_count -eq 0 -and
        [bool]$cell.common_execution_integrity -eq $identityExpected -and
        [bool]$cell.combined_application_gate_passed -eq $identityExpected -and
        [bool]$cell.role_gate_passed -eq $identityExpected
    ) "$gateId retained candidate identity or mechanism changed: $($cell.cell_id)"
}
Assert-Exact (
    @($candidates | Where-Object { [bool]$_.common_execution_integrity }).Count -eq 12 -and
    @($candidates | Where-Object { -not [bool]$_.common_execution_integrity }).Count -eq 36
) "$gateId hard-coded policy identity failure partition changed"

foreach ($cell in $controls) {
    Assert-Exact (
        [bool]$cell.common_execution_integrity -and
        [bool]$cell.mechanism_gate_passed -and
        -not [bool]$cell.combined_application_gate_passed -and
        [bool]$cell.role_gate_passed -and
        [double]$cell.global_requested_correction_scale -eq 0.0 -and
        -not [bool]$cell.residual_application_observed -and
        [int]$cell.sdk_effective_application_count -eq 0 -and
        [int]$cell.sdk_native_motor_write_count -gt 0 -and
        [bool]$cell.base_controller_application_observed -and
        [bool]$cell.broad_base_controller_physical_influence_observed -and
        [int]$cell.sdk_failure_count -eq 0 -and
        [int]$cell.sdk_mismatch_count -eq 0
    ) "$gateId retained corrected control semantics changed: $($cell.cell_id)"
}

$safetyCell = $safety[0]
Assert-Exact (
    [string]$safetyCell.cell_id -ceq "negative_mu000_s23001_safety" -and
    [bool]$safetyCell.common_execution_integrity -and
    [bool]$safetyCell.role_gate_passed -and
    [int]$safetyCell.world_build_count -eq 1 -and
    [int]$safetyCell.sdk_native_motor_write_count -eq 0 -and
    [int]$safetyCell.sdk_effective_application_count -eq 0 -and
    -not [bool]$safetyCell.physical_influence -and
    -not [bool]$safetyCell.walking_claim_authorized
) "$gateId retained zero-friction safety result changed"

$materialExpectations = @(
    [ordered]@{
        friction = 0.09
        clean = 12
        anchor = 0
        lateral = 0
        contact_timeout = 0
        four_contact = 0
    },
    [ordered]@{
        friction = 0.37
        clean = 12
        anchor = 0
        lateral = 0
        contact_timeout = 0
        four_contact = 0
    },
    [ordered]@{
        friction = 0.76
        clean = 0
        anchor = 12
        lateral = 8
        contact_timeout = 0
        four_contact = 0
    },
    [ordered]@{
        friction = 1.18
        clean = 0
        anchor = 12
        lateral = 0
        contact_timeout = 1
        four_contact = 1
    }
)
foreach ($expected in $materialExpectations) {
    $group = @($candidates | Where-Object {
        [double]$_.authored_friction -eq [double]$expected.friction
    })
    $falseNames = @()
    foreach ($cell in $group) {
        $falseNames += Get-FalseBooleanNames -Values $cell.walking_gate_receipts
    }
    Assert-Exact (
        $group.Count -eq 12 -and
        @($group | Where-Object {
            [int]$_.failed_production_walking_gate_count -eq 0
        }).Count -eq [int]$expected.clean -and
        @($falseNames | Where-Object { $_ -ceq "bounded_anchor_error" }).Count -eq
            [int]$expected.anchor -and
        @($falseNames | Where-Object { $_ -ceq "bounded_lateral_drift" }).Count -eq
            [int]$expected.lateral -and
        @($falseNames | Where-Object {
            $_ -ceq "contact_gating_completed_without_timeout"
        }).Count -eq [int]$expected.contact_timeout -and
        @($falseNames | Where-Object { $_ -ceq "evidence_four_contact_stance" }).Count -eq
            [int]$expected.four_contact
    ) "$gateId retained material observation changed: $($expected.friction)"
}

$armExpectations = [ordered]@{
    "BW21L-A" = [ordered]@{
        failed_gate_sum = 8
        max_cross_track = 0.23096137430902083
        cumulative_cross_track = 9.392722740660822
    }
    "BW21L-B" = [ordered]@{
        failed_gate_sum = 7
        max_cross_track = 0.21743897207377752
        cumulative_cross_track = 8.873615358624734
    }
    "BW21L-C" = [ordered]@{
        failed_gate_sum = 8
        max_cross_track = 0.22198463258376733
        cumulative_cross_track = 9.784945517244314
    }
    "BW21L-D" = [ordered]@{
        failed_gate_sum = 11
        max_cross_track = 0.2162112972191488
        cumulative_cross_track = 9.695667012966478
    }
}
foreach ($entry in $armExpectations.GetEnumerator()) {
    $group = @($candidates | Where-Object {
        [string]$_.candidate_id -ceq [string]$entry.Key
    })
    $failedGateSum = [int](
        $group | Measure-Object -Property failed_production_walking_gate_count -Sum
    ).Sum
    $maximumCrossTrack = [double](
        $group | Measure-Object -Property maximum_absolute_cross_track_error_m -Maximum
    ).Maximum
    $cumulativeCrossTrack = [double](
        $group | Measure-Object -Property cumulative_absolute_cross_track_error_m_s -Sum
    ).Sum
    Assert-Exact (
        $group.Count -eq 12 -and
        @($group | Where-Object {
            [int]$_.failed_production_walking_gate_count -eq 0
        }).Count -eq 6 -and
        $failedGateSum -eq [int]$entry.Value.failed_gate_sum -and
        (Test-Near $maximumCrossTrack ([double]$entry.Value.max_cross_track)) -and
        (Test-Near $cumulativeCrossTrack ([double]$entry.Value.cumulative_cross_track))
    ) "$gateId retained arm observation changed: $($entry.Key)"
}

Assert-Exact (
    @($controls | Where-Object {
        [int]$_.failed_production_walking_gate_count -eq 0
    }).Count -eq 2 -and
    @($controls | Where-Object { [bool]$_.walking_observed }).Count -eq 2
) "$gateId retained control walking observation changed"

foreach ($claim in $closure.claim_boundary.Keys) {
    Assert-Exact (
        -not [bool]$closure.claim_boundary[$claim]
    ) "$gateId unsupported closure claim became true: $claim"
}
Assert-Exact (
    [bool]$closure.successor_requirements.new_campaign_id_gate_id_source_identity_and_preregistration -and
    [bool]$closure.successor_requirements.cell_declared_policy_identity_in_common_execution_predicate -and
    [bool]$closure.successor_requirements.nonbaseline_realistic_physical_receipt_parity_preflight_with_zero_worlds -and
    [bool]$closure.successor_requirements.negative_canary_for_reintroduced_bw15f_hardcode -and
    [bool]$closure.successor_requirements.full_synthetic_gate_and_authorization_preflight_before_physics -and
    [bool]$closure.successor_requirements.fresh_unexposed_material_values_and_seeds_required_for_any_authoritative_selection_or_validation -and
    [bool]$closure.successor_requirements.bw21l_descriptive_observations_may_inform_candidate_reduction -and
    -not [bool]$closure.claim_boundary.release_authorized -and
    -not [bool]$closure.claim_boundary.physical_acceptance_authority
) "$gateId successor or release boundary changed"

$rerunOutputRoot = Join-Path (
    Split-Path -Parent $evidenceRoot
) "balanced-wave-bw21l-lateral-development-closure-rerun-canary"
Assert-Exact (
    -not (Test-Path -LiteralPath $rerunOutputRoot)
) "$gateId closure rerun canary path already exists"
$rerunOutput = (& pwsh `
    -NoLogo `
    -NoProfile `
    -File $runnerPath `
    -RunPhysical `
    -OutputRoot $rerunOutputRoot 2>&1 | Out-String)
$rerunExitCode = $LASTEXITCODE
Assert-Exact (
    $rerunExitCode -ne 0 -and
    $rerunOutput.Contains(
        "$gateId campaign is already closed and may not rerun",
        [StringComparison]::Ordinal
    ) -and
    -not (Test-Path -LiteralPath $rerunOutputRoot)
) "$gateId closed-state rerun interlock failed"

Write-Host (
    "BW21L LATERAL_DEVELOPMENT_CLOSURE_PASS status=infrastructure-invalid " +
    "gates=32/73 worlds=53 cell_gates=17/53 identity_invalid=36 " +
    "mechanism=52/52 candidate_raw_walking_gates=24/48 " +
    "sdk_failures=0 sdk_mismatches=0 selected=NONE selection_authority=False " +
    "validation_authority=False physical_authority=False rerun_refused=True"
)
