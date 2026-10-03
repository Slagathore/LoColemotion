#requires -Version 7.0

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [System.IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$sdkRoot = Join-Path $repoRoot "sdk"
$evidenceBase = Join-Path (Split-Path -Parent $repoRoot) "SporeSpore_Evidence"
$campaignId = "BW28Y-FRESH-MATERIAL-YAW-DEVELOPMENT"
$gateId = "BW28Y"
$sourceCommit = "77b4ca34fc2d8c3271fcfa364a817b02d7eb81ed"
$closurePath = Join-Path (
    $sdkRoot
) "balanced_wave_bw28y_yaw_development_closure.json"
$runnerPath = Join-Path $sdkRoot "run_balanced_wave_bw28y_yaw_development.ps1"
$expectedClosureSha256 =
    "28b95ae71cc00be49ae1f84d94356c3b410d80a156e7641e0fc02a610898919c"

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

function Get-GitBlobRawSha256 {
    param(
        [Parameter(Mandatory)][string]$Commit,
        [Parameter(Mandatory)][string]$RelativePath
    )
    $start = [System.Diagnostics.ProcessStartInfo]::new()
    $start.FileName = "git"
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    foreach ($argument in @(
        "-C", $repoRoot, "cat-file", "blob", "${Commit}:$RelativePath"
    )) {
        [void]$start.ArgumentList.Add($argument)
    }
    $process = [System.Diagnostics.Process]::new()
    $process.StartInfo = $start
    Assert-Exact ($process.Start()) "Failed to start git cat-file"
    $memory = [System.IO.MemoryStream]::new()
    try {
        $process.StandardOutput.BaseStream.CopyTo($memory)
        $stderr = $process.StandardError.ReadToEnd()
        $process.WaitForExit()
        Assert-Exact ($process.ExitCode -eq 0) (
            "Historical blob is missing: $RelativePath; $stderr"
        )
        return [Convert]::ToHexString(
            [Security.Cryptography.SHA256]::HashData($memory.ToArray())
        ).ToLowerInvariant()
    } finally {
        $memory.Dispose()
        $process.Dispose()
    }
}

function Get-GitBlobUtf8Text {
    param(
        [Parameter(Mandatory)][string]$Commit,
        [Parameter(Mandatory)][string]$RelativePath
    )
    $start = [System.Diagnostics.ProcessStartInfo]::new()
    $start.FileName = "git"
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    foreach ($argument in @(
        "-C", $repoRoot, "cat-file", "blob", "${Commit}:$RelativePath"
    )) {
        [void]$start.ArgumentList.Add($argument)
    }
    $process = [System.Diagnostics.Process]::new()
    $process.StartInfo = $start
    Assert-Exact ($process.Start()) "Failed to start git cat-file"
    $memory = [System.IO.MemoryStream]::new()
    try {
        $process.StandardOutput.BaseStream.CopyTo($memory)
        $stderr = $process.StandardError.ReadToEnd()
        $process.WaitForExit()
        Assert-Exact ($process.ExitCode -eq 0) (
            "Historical blob is missing: $RelativePath; $stderr"
        )
        return [Text.UTF8Encoding]::new($false, $true).GetString(
            $memory.ToArray()
        )
    } finally {
        $memory.Dispose()
        $process.Dispose()
    }
}

function Get-GitBindingTreeDigest {
    param(
        [Parameter(Mandatory)][string]$Commit,
        [Parameter(Mandatory)][System.Collections.IDictionary]$Bindings
    )
    $rows = @(
        foreach ($entry in $Bindings.GetEnumerator()) {
            $relativePath = [string]$entry.Value.path
            $oid = (& git -C $repoRoot rev-parse (
                "${Commit}:$relativePath"
            )).Trim()
            Assert-Exact (
                $LASTEXITCODE -eq 0 -and $oid -cmatch "^[0-9a-f]{40}$"
            ) "$gateId historical experiment blob is missing: $relativePath"
            $start = [System.Diagnostics.ProcessStartInfo]::new()
            $start.FileName = "git"
            $start.UseShellExecute = $false
            $start.CreateNoWindow = $true
            $start.RedirectStandardOutput = $true
            $start.RedirectStandardError = $true
            foreach ($argument in @(
                "-C", $repoRoot, "cat-file", "blob", "${Commit}:$relativePath"
            )) {
                [void]$start.ArgumentList.Add($argument)
            }
            $process = [System.Diagnostics.Process]::new()
            $process.StartInfo = $start
            Assert-Exact ($process.Start()) "Failed to start git cat-file"
            $memory = [System.IO.MemoryStream]::new()
            try {
                $process.StandardOutput.BaseStream.CopyTo($memory)
                $stderr = $process.StandardError.ReadToEnd()
                $process.WaitForExit()
                Assert-Exact ($process.ExitCode -eq 0) (
                    "Historical blob is missing: $relativePath; $stderr"
                )
                $bytes = $memory.ToArray()
                $sha256 = [Convert]::ToHexString(
                    [Security.Cryptography.SHA256]::HashData($bytes)
                ).ToLowerInvariant()
                "{0}`t{1}`t{2}`t{3}" -f (
                    $relativePath,
                    $bytes.Length,
                    $oid,
                    $sha256
                )
            } finally {
                $memory.Dispose()
                $process.Dispose()
            }
        }
    )
    $text = (@($rows | Sort-Object) -join "`n") + "`n"
    return [ordered]@{
        binding_count = $rows.Count
        serialized_byte_length = [Text.Encoding]::UTF8.GetByteCount($text)
        tree_sha256 = [Convert]::ToHexString(
            [Security.Cryptography.SHA256]::HashData(
                [Text.Encoding]::UTF8.GetBytes($text)
            )
        ).ToLowerInvariant()
    }
}

function Assert-HashedArtifact {
    param(
        [Parameter(Mandatory)][string]$Root,
        [Parameter(Mandatory)][System.Collections.IDictionary]$Artifact,
        [Parameter(Mandatory)][string]$Label
    )
    $path = Join-Path $Root ([string]$Artifact.path)
    Assert-Exact (
        (Test-Path -LiteralPath $path -PathType Leaf) -and
        (Get-Item -LiteralPath $path).Length -eq
            [long]$Artifact.byte_length -and
        (Get-RawSha256 -Path $path) -ceq [string]$Artifact.raw_sha256
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
                    (Get-RawSha256 -Path $_.FullName)
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

function Get-WalkingFailureCount {
    param([Parameter(Mandatory)]$Cell)
    return @(
        $Cell.walking_gate_receipts.GetEnumerator() |
            Where-Object { -not [bool]$_.Value }
    ).Count
}

Assert-Exact (
    (Test-Path -LiteralPath $closurePath -PathType Leaf) -and
    (Get-RawSha256 -Path $closurePath) -ceq $expectedClosureSha256
) "$gateId closure is missing or changed"
$closure = Get-Content -Raw -LiteralPath $closurePath |
    ConvertFrom-Json -AsHashtable -Depth 128

Assert-Exact (
    [string]$closure.schema_version -ceq
        "sporespore_balanced_wave_bw28y_yaw_development_closure_v1" -and
    [string]$closure.status -ceq
        "closed_complete_valid_development_no_selection" -and
    [string]$closure.campaign_id -ceq $campaignId -and
    [string]$closure.gate_id -ceq $gateId -and
    [string]$closure.study_classification -ceq
        "paired_outcome_unexposed_finite_controller_development_screen" -and
    [string]$closure.experiment_source_commit -ceq $sourceCommit -and
    [bool]$closure.source_was_clean_and_equal_to_origin_and_live_github_main -and
    [bool]$closure.disposition.complete_physical_execution_retained -and
    [bool]$closure.disposition.infrastructure_valid -and
    [bool]$closure.disposition.development_result_valid -and
    [bool]$closure.disposition.valid_none_selection -and
    -not [bool]$closure.disposition.development_candidate_selected -and
    -not [bool]$closure.disposition.walking_negative -and
    -not [bool]$closure.disposition.physical_acceptance_authority
) "$gateId closure identity or disposition changed"

$freezeBinding = $closure.frozen_source.stage_one_freeze
$freezeAuditBinding = $closure.frozen_source.stage_one_freeze_audit
foreach ($binding in @($freezeBinding, $freezeAuditBinding)) {
    $relativePath = [string]$binding.path
    $oid = (& git -C $repoRoot rev-parse "${sourceCommit}:$relativePath").Trim()
    Assert-Exact (
        $LASTEXITCODE -eq 0 -and
        $oid -ceq [string]$binding.git_blob_oid -and
        (Get-GitBlobRawSha256 `
            -Commit $sourceCommit `
            -RelativePath $relativePath) -ceq [string]$binding.raw_sha256
    ) "$gateId frozen top-level source binding changed: $relativePath"
}
$freeze = Get-GitBlobUtf8Text `
    -Commit $sourceCommit `
    -RelativePath ([string]$freezeBinding.path) |
    ConvertFrom-Json -AsHashtable -Depth 128
Assert-Exact (
    $freeze.source_bindings.Count -eq
        [int]$closure.frozen_source.source_binding_count
) "$gateId historical stage-one freeze binding cardinality changed"
$canonicalBindingTree = Get-GitBindingTreeDigest `
    -Commit $sourceCommit `
    -Bindings $freeze.source_bindings
$declaredCanonicalBindingTree =
    $closure.frozen_source.canonical_experiment_commit_binding_tree
$serializationBoundary = $closure.frozen_source.checkout_serialization_boundary
Assert-Exact (
    [string]$declaredCanonicalBindingTree.algorithm -ceq
        "sha256_utf8_sorted_path_tab_bytes_tab_git_blob_oid_tab_blob_raw_sha256_lf_v1" -and
    [int]$canonicalBindingTree.binding_count -eq
        [int]$declaredCanonicalBindingTree.binding_count -and
    [int]$canonicalBindingTree.serialized_byte_length -eq
        [int]$declaredCanonicalBindingTree.serialized_byte_length -and
    [string]$canonicalBindingTree.tree_sha256 -ceq
        [string]$declaredCanonicalBindingTree.tree_sha256 -and
    [bool]$serializationBoundary.stage_one_freeze_records_exact_physical_checkout_raw_sha256_values -and
    [bool]$serializationBoundary.experiment_source_commit_separately_pins_canonical_git_blobs -and
    [bool]$serializationBoundary.supervisor_verified_all_exact_checkout_raw_sha256_values_before_first_world -and
    [bool]$serializationBoundary.git_cleanliness_treats_configured_text_line_ending_normalization_as_equivalent -and
    [bool]$serializationBoundary.line_ending_serialization_does_not_change_executed_tokens_or_experiment_logic -and
    [bool]$serializationBoundary.closure_audit_reconstructs_the_complete_canonical_binding_tree_from_the_experiment_commit
) "$gateId canonical experiment source-binding tree changed"
$evidenceRoot = [System.IO.Path]::GetFullPath(
    [string]$closure.retained_evidence.root
)
Assert-Exact (
    $evidenceRoot -ceq (
        "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence\" +
        "balanced-wave-bw28y-yaw-development-77b4ca3"
    ) -and
    (Test-Path -LiteralPath $evidenceRoot -PathType Container)
) "$gateId retained evidence root is missing"
foreach ($entry in @(
    @($closure.retained_evidence.attempt, "attempt"),
    @($closure.retained_evidence.raw_result, "raw result"),
    @($closure.retained_evidence.evaluation, "evaluation"),
    @($closure.retained_evidence.primary_report, "primary report"),
    @($closure.retained_evidence.completion, "completion")
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
        [string]$closure.retained_evidence.tree.tree_sha256
) "$gateId retained evidence tree changed"

$attempt = Get-Content -Raw -LiteralPath (
    Join-Path $evidenceRoot "attempt.json"
) | ConvertFrom-Json -AsHashtable -Depth 128
$rawResult = Get-Content -Raw -LiteralPath (
    Join-Path $evidenceRoot "raw-result.json"
) | ConvertFrom-Json -AsHashtable -Depth 128
$evaluation = Get-Content -Raw -LiteralPath (
    Join-Path $evidenceRoot "evaluation.json"
) | ConvertFrom-Json -AsHashtable -Depth 128
$report = Get-Content -Raw -LiteralPath (
    Join-Path $evidenceRoot "report.json"
) | ConvertFrom-Json -AsHashtable -Depth 128
$completion = Get-Content -Raw -LiteralPath (
    Join-Path $evidenceRoot "completion.json"
) | ConvertFrom-Json -AsHashtable -Depth 128

Assert-Exact (
    [string]$attempt.schema_version -ceq
        "sporespore_balanced_wave_bw28y_yaw_development_attempt_v1" -and
    [string]$attempt.campaign_id -ceq $campaignId -and
    [string]$attempt.gate_id -ceq $gateId -and
    [string]$attempt.attempt_id -ceq
        "7a44427e656244358f8f774333eb2af5" -and
    [string]$attempt.source_commit -ceq $sourceCommit -and
    [string]$attempt.origin_main_commit -ceq $sourceCommit -and
    [string]$attempt.remote_main_commit -ceq $sourceCommit -and
    [bool]$attempt.source_worktree_clean -and
    [bool]$attempt.source_matches_live_github_main -and
    [string]$attempt.full_godot_v2_attestation_sha256 -ceq
        [string]$closure.prephysical_authority.full_godot_v2_attestation.raw_sha256 -and
    [bool]$attempt.complete_zero_world_gate_passed -and
    [bool]$attempt.declaration_audit_passed -and
    [bool]$attempt.actual_receipt_path_preflight_passed -and
    [bool]$attempt.production_composer_evaluator_preflight_passed -and
    [bool]$attempt.worker_entrypoint_preflight_passed -and
    [bool]$attempt.attempt_contract_preflight_passed -and
    [bool]$attempt.stage_one_freeze_verified -and
    [int]$attempt.expected_gate_count -eq 50 -and
    [int]$attempt.expected_world_count -eq 28 -and
    [int]$attempt.expected_adapter_start_count -eq 27 -and
    @($attempt.ordered_cell_ids).Count -eq 28 -and
    @($attempt.primary_world_attempt_ids).Count -eq 28 -and
    @($attempt.replacement_world_attempt_ids).Count -eq 28 -and
    [int]$attempt.replacement_budget_per_incomplete_cell -eq 1 -and
    [bool]$attempt.physical_identity_consumed -and
    -not [bool]$attempt.same_identity_rerun_allowed -and
    -not [bool]$attempt.locomotion_outcome_exposed_at_attempt -and
    [bool]$attempt.retained_physical_execution_serialized -and
    -not [bool]$attempt.physical_acceptance_authority
) "$gateId retained attempt authorization changed"

$attestation = $closure.prephysical_authority.full_godot_v2_attestation
$attestationPath = [System.IO.Path]::GetFullPath([string]$attestation.path)
Assert-HashedArtifact `
    -Root (Split-Path -Parent $attestationPath) `
    -Artifact ([ordered]@{
        path = Split-Path -Leaf $attestationPath
        byte_length = [long]$attestation.byte_length
        raw_sha256 = [string]$attestation.raw_sha256
    }) `
    -Label "full-Godot V2 attestation"
$attestationDocument = Get-Content -Raw -LiteralPath $attestationPath |
    ConvertFrom-Json -AsHashtable -Depth 128
Assert-Exact (
    [string]$attestationDocument.source.commit -ceq $sourceCommit -and
    -not [bool]$attestationDocument.claims.physical_acceptance_authority -and
    -not [bool]$attestationDocument.claims.new_physical_campaign_executed -and
    -not [bool]$attestationDocument.claims.new_scientific_outcome_exposed
) "$gateId prephysical full-conformance attestation changed"

Assert-Exact (
    [string]$completion.schema_version -ceq
        "sporespore_balanced_wave_bw28y_yaw_development_completion_v1" -and
    [string]$completion.source_commit -ceq $sourceCommit -and
    [string]$completion.campaign_attempt_id -ceq
        [string]$attempt.attempt_id -and
    [int]$completion.expected_cell_count -eq 28 -and
    [int]$completion.worker_process_attempt_count -eq 28 -and
    [int]$completion.replacement_attempt_count -eq 0 -and
    [int]$completion.complete_final_receipt_count -eq 28 -and
    [int]$completion.production_cell_gate_pass_count -eq 28 -and
    [int]$completion.integrity_failure_count -eq 0 -and
    [bool]$completion.complete_result -and
    [bool]$completion.evaluation_ok -and
    [string]$completion.selected_candidate_id -ceq "NONE" -and
    -not [bool]$completion.development_selection_authority -and
    -not [bool]$completion.independent_validation_authority -and
    [bool]$completion.attempt_immutable -and
    -not [bool]$completion.same_identity_rerun_allowed -and
    -not [bool]$completion.physical_acceptance_authority
) "$gateId retained completion changed"

Assert-Exact (
    [string]$evaluation.schema_version -ceq
        "sporespore_balanced_wave_bw28y_yaw_development_evaluation_v1" -and
    [bool]$evaluation.ok -and
    [int]$evaluation.reconstructed_passed_gate_count -eq 50 -and
    [int]$evaluation.reconstructed_failed_gate_count -eq 0 -and
    [int]$evaluation.expected_world_count -eq 28 -and
    [int]$evaluation.observed_world_count -eq 28 -and
    [int]$evaluation.candidate_count -eq 24 -and
    [int]$evaluation.control_count -eq 3 -and
    [int]$evaluation.safety_count -eq 1 -and
    @($evaluation.gates).Count -eq 50 -and
    @($evaluation.gates | Where-Object { -not [bool]$_.passed }).Count -eq 0 -and
    @($evaluation.failure_codes).Count -eq 0 -and
    [string]$evaluation.selected_candidate_id -ceq "NONE" -and
    [bool]$evaluation.selected_candidate_strictly_better_than_baseline -and
    [int]$evaluation.selected_candidate_paired_regression_count -eq 2 -and
    -not [bool]$evaluation.development_selection_authority -and
    -not [bool]$evaluation.independent_validation_authority -and
    -not [bool]$evaluation.physical_acceptance_authority
) "$gateId frozen evaluation changed"

$candidateSummaries = @($evaluation.candidate_summaries)
Assert-Exact (
    $candidateSummaries.Count -eq 2 -and
    [string]$candidateSummaries[0].candidate_id -ceq "BW28Y-A" -and
    [int]$candidateSummaries[0].walking_conjunction_failure_count -eq 5 -and
    [int]$candidateSummaries[0].aggregate_failed_production_walking_gate_count -eq 5 -and
    [math]::Abs(
        [double]$candidateSummaries[0].maximum_absolute_cross_track_error_m -
        [double]0.204510810627321
    ) -lt 1.0e-12 -and
    [math]::Abs(
        [double]$candidateSummaries[0].aggregate_cumulative_absolute_cross_track_error_m_s -
        [double]13.9942057522041
    ) -lt 1.0e-12 -and
    [string]$candidateSummaries[1].candidate_id -ceq "BW28Y-B" -and
    [int]$candidateSummaries[1].walking_conjunction_failure_count -eq 3 -and
    [int]$candidateSummaries[1].aggregate_failed_production_walking_gate_count -eq 3 -and
    [math]::Abs(
        [double]$candidateSummaries[1].maximum_absolute_cross_track_error_m -
        [double]0.198771206845476
    ) -lt 1.0e-12 -and
    [math]::Abs(
        [double]$candidateSummaries[1].aggregate_cumulative_absolute_cross_track_error_m_s -
        [double]14.5350879158064
    ) -lt 1.0e-12 -and
    [int]$candidateSummaries[1].paired_walking_gate_regression_count -eq 2
) "$gateId candidate summary changed"

Assert-Exact (
    [string]$report.schema_version -ceq
        "sporespore_balanced_wave_bw28y_yaw_development_report_v1" -and
    [string]$report.source_commit -ceq $sourceCommit -and
    [bool]$report.first_complete_result_final_for_source_identity -and
    [int]$report.complete_final_receipt_count -eq 28 -and
    [int]$report.production_cell_gate_pass_count -eq 28 -and
    [int]$report.physical_world_process_attempt_count -eq 28 -and
    [int]$report.recovery_exhausted_incomplete_cell_count -eq 0 -and
    [bool]$report.evaluation_ok -and
    [string]$report.result_status -ceq "valid_development_no_selection" -and
    [string]$report.selected_candidate_id -ceq "NONE" -and
    -not [bool]$report.development_selection_authority -and
    -not [bool]$report.independent_validation_authority -and
    [bool]$report.full_godot_v2_attestation.production_verifier_ok -and
    [bool]$report.operation_lock.acquired -and
    [string]$report.operation_lock.role -ceq "physical" -and
    -not [bool]$report.operation_lock.abandoned_owner_recovered -and
    -not [bool]$report.operation_lock.test_only -and
    -not [bool]$report.physical_acceptance_authority
) "$gateId retained report changed"

$cellAttempts = @($report.cell_attempts)
Assert-Exact ($cellAttempts.Count -eq 28) "$gateId cell-attempt count changed"
foreach ($cellAttempt in $cellAttempts) {
    Assert-Exact (
        [string]$cellAttempt.attempt_kind -ceq "primary" -and
        [int]$cellAttempt.process_exit_code -eq 0 -and
        -not [bool]$cellAttempt.timed_out -and
        -not [bool]$cellAttempt.killed_process_tree -and
        [bool]$cellAttempt.raw_receipt_parsed -and
        [bool]$cellAttempt.complete_final_receipt -and
        [bool]$cellAttempt.role_gate_passed -and
        [bool]$cellAttempt.production_cell_gate_passed -and
        [string]$cellAttempt.recovery_action -ceq "finalize_cell" -and
        -not [bool]$cellAttempt.replacement_eligible -and
        -not [bool]$cellAttempt.locomotion_outcome_triggered_replacement
    ) "$gateId cell execution changed: $($cellAttempt.cell_id)"
    foreach ($artifactName in @("transcript", "stderr")) {
        $path = [System.IO.Path]::GetFullPath(
            [string]$cellAttempt["${artifactName}_path"]
        )
        Assert-Exact (
            $path.StartsWith(
                $evidenceRoot + [System.IO.Path]::DirectorySeparatorChar,
                [StringComparison]::OrdinalIgnoreCase
            ) -and
            (Get-RawSha256 -Path $path) -ceq
                [string]$cellAttempt["${artifactName}_raw_sha256"]
        ) "$gateId cell $artifactName changed: $($cellAttempt.cell_id)"
    }
}

Assert-Exact (
    [string]$rawResult.schema_version -ceq
        "sporespore_balanced_wave_bw28y_yaw_development_result_v1" -and
    [string]$rawResult.campaign_id -ceq $campaignId -and
    [string]$rawResult.source.commit -ceq $sourceCommit -and
    [bool]$rawResult.source.worktree_clean -and
    [bool]$rawResult.source.matches_live_github_main -and
    [int]$rawResult.expected_gate_count -eq 50 -and
    [int]$rawResult.expected_world_count -eq 28 -and
    [int]$rawResult.observed_world_count -eq 28 -and
    [int]$rawResult.integrity_failure_count -eq 0 -and
    [int]$rawResult.physical_world_process_attempt_count -eq 28 -and
    [int]$rawResult.complete_final_receipt_count -eq 28 -and
    [int]$rawResult.selector_invocation_count_before_evaluation -eq 0 -and
    [string]$rawResult.pre_evaluation_selected_candidate_id -ceq "NONE" -and
    @($rawResult.cells).Count -eq 28
) "$gateId retained raw result changed"

$cells = @($rawResult.cells)
$candidates = @($cells | Where-Object { [string]$_.role -ceq "candidate" })
$controls = @($cells | Where-Object { [string]$_.role -ceq "control" })
$safetyCells = @($cells | Where-Object { [string]$_.role -ceq "safety" })
Assert-Exact (
    $candidates.Count -eq 24 -and
    $controls.Count -eq 3 -and
    $safetyCells.Count -eq 1 -and
    @($cells | Where-Object { -not [bool]$_.role_gate_passed }).Count -eq 0 -and
    @($candidates | Where-Object { [bool]$_.walking_observed }).Count -eq 16 -and
    @($controls | Where-Object { [bool]$_.walking_observed }).Count -eq 2 -and
    @($safetyCells | Where-Object { [bool]$_.walking_observed }).Count -eq 0
) "$gateId cell roles or walking totals changed"

$candidateA = @($candidates | Where-Object {
    [string]$_.candidate_id -ceq "BW28Y-A"
})
$candidateB = @($candidates | Where-Object {
    [string]$_.candidate_id -ceq "BW28Y-B"
})
Assert-Exact (
    $candidateA.Count -eq 12 -and
    $candidateB.Count -eq 12 -and
    @($candidateA | Where-Object walking_observed).Count -eq 7 -and
    @($candidateB | Where-Object walking_observed).Count -eq 9
) "$gateId candidate walking totals changed"

$improvementCount = 0
$regressionCount = 0
$jointWalkingCount = 0
$jointFailureCount = 0
foreach ($a in $candidateA) {
    $b = @($candidateB | Where-Object {
        [double]$_.authored_friction -eq [double]$a.authored_friction -and
        [int]$_.campaign_seed -eq [int]$a.campaign_seed
    }) | Select-Object -First 1
    Assert-Exact ($null -ne $b) "$gateId paired candidate is missing"
    if (-not [bool]$a.walking_observed -and [bool]$b.walking_observed) {
        $improvementCount += 1
    } elseif ([bool]$a.walking_observed -and -not [bool]$b.walking_observed) {
        $regressionCount += 1
    } elseif ([bool]$a.walking_observed -and [bool]$b.walking_observed) {
        $jointWalkingCount += 1
    } else {
        $jointFailureCount += 1
    }
}
Assert-Exact (
    $improvementCount -eq 4 -and
    $regressionCount -eq 2 -and
    $jointWalkingCount -eq 5 -and
    $jointFailureCount -eq 1
) "$gateId paired outcome comparison changed"

$failedCandidateOrControl = @(
    @($candidates + $controls) |
        Where-Object { -not [bool]$_.walking_observed }
)
Assert-Exact (
    $failedCandidateOrControl.Count -eq 9 -and
    @($failedCandidateOrControl | Where-Object {
        (Get-WalkingFailureCount -Cell $_) -ne 1 -or
        [bool]$_.walking_gate_receipts.bounded_lateral_drift -or
        -not [bool]$_.walking_gate_receipts.bounded_tilt -or
        -not [bool]$_.walking_gate_receipts.minimum_final_forward_translation -or
        -not [bool]$_.walking_gate_receipts.native_sdk_exclusive_post_settle_actuation
    }).Count -eq 0
) "$gateId walking-failure mechanism changed"
Assert-Exact (
    @($controls | Where-Object {
        [bool]$_.residual_application_observed -or
        [int]$_.sdk_effective_application_count -ne 0 -or
        -not [bool]$_.base_controller_application_observed -or
        -not [bool]$_.broad_base_controller_physical_influence_observed
    }).Count -eq 0
) "$gateId control mechanism changed"
$safety = $safetyCells[0]
Assert-Exact (
    [double]$safety.authored_friction -eq 0.0 -and
    [bool]$safety.role_gate_passed -and
    -not [bool]$safety.walking_observed -and
    [int]$safety.sdk_native_motor_write_count -eq 0 -and
    [int]$safety.sdk_effective_application_count -eq 0 -and
    -not [bool]$safety.physical_influence
) "$gateId zero-friction safety result changed"

Assert-Exact (
    [bool]$closure.frozen_evaluation.valid_complete_negative_development_result -and
    [string]$closure.frozen_evaluation.selected_candidate_id -ceq "NONE" -and
    [int]$closure.frozen_evaluation.successor_paired_walking_gate_regression_count -eq 2 -and
    [int]$closure.frozen_evaluation.required_successor_paired_walking_gate_regression_count -eq 0 -and
    [bool]$closure.optimization_boundary.negative_and_none_results_may_inform_successor_design -and
    [bool]$closure.optimization_boundary.observed_mechanisms_and_tradeoffs_should_be_used_in_future_candidates -and
    [bool]$closure.optimization_boundary.closed_result_may_not_be_rethresholded_rewritten_or_rerun -and
    [bool]$closure.optimization_boundary.bw28y_b_may_not_be_promoted_as_selected -and
    [bool]$closure.optimization_boundary.new_candidates_may_be_designed_from_the_observed_1_3_to_1_0_tradeoff
) "$gateId selection or optimization boundary changed"

Assert-Exact (
    [bool]$closure.claim_boundary.exact_finite_development_result_complete -and
    @($closure.claim_boundary.GetEnumerator() | Where-Object {
        [string]$_.Key -cne "exact_finite_development_result_complete" -and
        [bool]$_.Value
    }).Count -eq 0 -and
    [bool]$closure.immutability.first_complete_result_is_final_for_source_identity -and
    [bool]$closure.immutability.same_identity_rerun_forbidden -and
    [bool]$closure.immutability.same_identity_threshold_or_selector_edit_forbidden -and
    [bool]$closure.immutability.posthoc_candidate_selection_forbidden -and
    [bool]$closure.successor_requirements.new_campaign_id_gate_id_source_identity_preregistration_and_evidence_root -and
    [bool]$closure.successor_requirements.fresh_unexposed_material_values_and_seeds -and
    [bool]$closure.successor_requirements.explicitly_test_the_aggregate_gain_versus_paired_regression_tradeoff
) "$gateId claim, immutability, or successor boundary changed"

$campaignAttemptFiles = @(
    Get-ChildItem -LiteralPath $evidenceBase -Directory |
        ForEach-Object {
            $path = Join-Path $_.FullName "attempt.json"
            if (Test-Path -LiteralPath $path -PathType Leaf) {
                try {
                    $candidate = Get-Content -Raw -LiteralPath $path |
                        ConvertFrom-Json
                    if ([string]$candidate.campaign_id -ceq $campaignId) {
                        Get-Item -LiteralPath $path
                    }
                } catch {}
            }
        }
)
Assert-Exact (
    $campaignAttemptFiles.Count -eq 1 -and
    [System.IO.Path]::GetFullPath($campaignAttemptFiles[0].FullName) -ceq
        (Join-Path $evidenceRoot "attempt.json")
) "$gateId retained physical-attempt cardinality changed"

$rerunRoot = Join-Path (
    [System.IO.Path]::GetTempPath()
) ("bw28y-closure-rerun-" + [Guid]::NewGuid().ToString("N"))
$rerunOutput = (& pwsh `
    -NoLogo `
    -NoProfile `
    -File $runnerPath `
    -RunPhysical `
    -OutputRoot $rerunRoot 2>&1 | Out-String)
Assert-Exact (
    $LASTEXITCODE -ne 0 -and
    $rerunOutput.Contains(
        "$gateId campaign is already closed and may not rerun",
        [StringComparison]::Ordinal
    ) -and
    -not (Test-Path -LiteralPath $rerunRoot)
) "$gateId closed-state rerun interlock changed"

Write-Host (
    "BW28Y_YAW_DEVELOPMENT_CLOSURE_PASS status=valid-none worlds=28 " +
    "process_attempts=28 replacements=0 receipts=28 cell_gates=28/28 " +
    "evaluation_gates=50/50 walking=18 candidate_a=7/12 candidate_b=9/12 " +
    "improvement_pairs=4 regression_pairs=2 selected=NONE " +
    "development_selection=False validation_authority=False " +
    "turning_acceptance=False material_robustness=False " +
    "physical_authority=False rerun_refused=True"
)
