#requires -Version 7.0

[CmdletBinding()]
param(
    [string]$EvidenceRoot = (
        "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence\" +
        "qsdk-r23d22-20260812T065412Z"
    )
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$sdkRoot = Join-Path $repoRoot "sdk"
$closurePath = Join-Path $sdkRoot "turning\r23d22_physical_closure_v1.json"
$supervisorPath = Join-Path $sdkRoot "run_qsdk_r23d22_supervisor.ps1"
$artifactStorePath = Join-Path $sdkRoot "content_addressed_artifact_store.ps1"
$campaignId = "QSDK-R23D22-REDUCED-YAW-CROSS-ENGINE-TRANSFER-CONFORMANCE"
$gateId = "QSDK-R23D22"
$sourceCommit = "724e07e0fe81e7dab429e05b3cef801754d7d811"
$sourceTree = "2e8115ac3661fcbe243f691c71390351dc930dea"
$attemptId = "8990b78ad93e4ad0ba29791813a6723f"

. $artifactStorePath

function Assert-R23D22Closure([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "QSDK-R23D22 closure: $Message" }
}

function Get-R23D22ClosureSha256([string]$Path) {
    return "sha256:" + (
        Get-FileHash -LiteralPath $Path -Algorithm SHA256
    ).Hash.ToLowerInvariant()
}

function Get-R23D22GitBlobSha256([string]$RelativePath) {
    $start = [Diagnostics.ProcessStartInfo]::new()
    $start.FileName = "git"
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    foreach ($argument in @(
        "-C", $repoRoot, "cat-file", "blob", "${sourceCommit}:$RelativePath"
    )) { [void]$start.ArgumentList.Add($argument) }
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $start
    try {
        Assert-R23D22Closure $process.Start() "could not start Git blob reader"
        $stderrTask = $process.StandardError.ReadToEndAsync()
        $hasher = [Security.Cryptography.SHA256]::Create()
        try { $digest = $hasher.ComputeHash($process.StandardOutput.BaseStream) }
        finally { $hasher.Dispose() }
        $process.WaitForExit()
        $stderr = $stderrTask.GetAwaiter().GetResult()
        Assert-R23D22Closure ($process.ExitCode -eq 0) (
            "Git blob read failed for $RelativePath`: $stderr"
        )
        return "sha256:" + [Convert]::ToHexString($digest).ToLowerInvariant()
    } finally { $process.Dispose() }
}

function Test-R23D22Cas([string]$Sha256, [long]$ByteLength) {
    $artifactRoot = Join-Path (
        Get-SporeSporeArtifactEvidenceRoot -RepoRoot $repoRoot
    ) "artifacts\sha256"
    return Test-SporeSporeStoredArtifact `
        -Directory (Join-Path $artifactRoot $Sha256.Substring(7)) `
        -ExpectedSha256 $Sha256.Substring(7) `
        -ExpectedByteLength $ByteLength
}

function Assert-R23D22RetainedFile(
    [string]$Path,
    [string]$ExpectedSha256,
    [long]$ExpectedLength,
    [string]$Label
) {
    Assert-R23D22Closure (Test-Path -LiteralPath $Path -PathType Leaf) (
        "retained file is missing: $Label"
    )
    Assert-R23D22Closure (
        (Get-Item -LiteralPath $Path).Length -eq $ExpectedLength -and
        (Get-R23D22ClosureSha256 $Path) -ceq $ExpectedSha256 -and
        (Test-R23D22Cas $ExpectedSha256 $ExpectedLength)
    ) "retained bytes or CAS changed: $Label"
}

Assert-R23D22Closure (
    (git -C $repoRoot rev-parse --show-toplevel).Replace("/", "\") -ceq
        $repoRoot -and
    (git -C $repoRoot remote get-url origin) -ceq
        "https://github.com/Slagathore/sporespore.git" -and
    (git -C $repoRoot cat-file -t $sourceCommit) -ceq "commit" -and
    (git -C $repoRoot rev-parse "$sourceCommit`^{tree}") -ceq $sourceTree
) "repository or frozen source identity changed"

foreach ($path in @($closurePath, $supervisorPath, $artifactStorePath, $EvidenceRoot)) {
    Assert-R23D22Closure (Test-Path -LiteralPath $path) "required path missing: $path"
}

$closure = Get-Content -LiteralPath $closurePath -Raw |
    ConvertFrom-Json -AsHashtable -Depth 100
Assert-R23D22Closure (
    [string]$closure.schema_version -ceq
        "sporespore_qsdk_r23d22_physical_closure_v1" -and
    [string]$closure.status -ceq
        "closed_consumed_invalid_complete_matrix_runtime_receipt_mismatches" -and
    [string]$closure.campaign_id -ceq $campaignId -and
    [string]$closure.gate_id -ceq $gateId -and
    [string]$closure.source_identity.commit -ceq $sourceCommit -and
    [string]$closure.source_identity.tree_git_oid -ceq $sourceTree -and
    [int]$closure.source_identity.declared_worker_dependency_count -eq 57 -and
    [int]$closure.source_identity.declared_new_world_count -eq 6 -and
    -not [bool]$closure.source_identity.controller_or_physics_changed_by_closure
) "closure identity or frozen-source boundary changed"

foreach ($binding in @(
    [ordered]@{
        path = [string]$closure.source_identity.preregistration_path
        oid = [string]$closure.source_identity.preregistration_git_blob_oid
        sha = [string]$closure.source_identity.preregistration_raw_sha256
    },
    [ordered]@{
        path = [string]$closure.source_identity.implementation_contract_path
        oid = [string]$closure.source_identity.implementation_contract_git_blob_oid
        sha = [string]$closure.source_identity.implementation_contract_raw_sha256
    },
    [ordered]@{
        path = [string]$closure.source_identity.campaign_manifest_path
        oid = [string]$closure.source_identity.campaign_manifest_git_blob_oid
        sha = [string]$closure.source_identity.campaign_manifest_raw_sha256
    }
)) {
    Assert-R23D22Closure (
        (git -C $repoRoot rev-parse "${sourceCommit}:$($binding.path)") -ceq
            [string]$binding.oid -and
        (Get-R23D22GitBlobSha256 ([string]$binding.path)) -ceq
            [string]$binding.sha
    ) "frozen Git blob changed: $($binding.path)"
}

$godot = $closure.immutable_godot_binding
Assert-R23D22Closure (
    [string]$godot.gate_id -ceq "QSDK-R23D21" -and
    [string]$godot.closure_commit -ceq
        "0401f3adc9caf07cf4be91d55ffeec73be8fe29b" -and
    (Get-R23D22GitBlobSha256 ([string]$godot.closure_path)) -ceq
        [string]$godot.closure_raw_sha256 -and
    [int]$godot.bound_cell_count -eq 3 -and
    [bool]$godot.scientific_positive -and
    -not [bool]$godot.rerun_performed
) "immutable R23D21 Godot/Jolt binding changed"

$qualification = $closure.campaign_local_qualification
Assert-R23D22RetainedFile `
    ([string]$qualification.first_scoped_attestation_path) `
    ([string]$qualification.first_scoped_attestation_raw_sha256) `
    ([long]$qualification.first_scoped_attestation_byte_length) `
    "first non-adopted scoped attestation"
Assert-R23D22RetainedFile `
    ([string]$qualification.accepted_scoped_attestation_path) `
    ([string]$qualification.accepted_scoped_attestation_raw_sha256) `
    ([long]$qualification.accepted_scoped_attestation_byte_length) `
    "accepted scoped attestation"
Assert-R23D22RetainedFile `
    ([string]$qualification.adoption_path) `
    ([string]$qualification.adoption_raw_sha256) `
    ([long]$qualification.adoption_byte_length) `
    "campaign-local adoption"
$adoption = Get-Content -LiteralPath ([string]$qualification.adoption_path) -Raw |
    ConvertFrom-Json -AsHashtable -Depth 100
Assert-R23D22Closure (
    [string]$qualification.first_adoption_refusal -ceq
        "commissioned_runtime_python_executable_mismatch" -and
    [int]$qualification.first_attempt_world_build_count -eq 0 -and
    [string]$adoption.campaign_id -ceq $campaignId -and
    [string]$adoption.source_commit -ceq $sourceCommit -and
    [int]$adoption.declared_physical_world_count -eq 6 -and
    [int]$adoption.executed_gate_count -eq 16 -and
    [int]$adoption.global_gate_count -eq 12 -and
    [int]$adoption.lineage_gate_count -eq 1 -and
    [int]$adoption.campaign_gate_count -eq 3 -and
    [int]$adoption.gate_cas_object_count -eq 48 -and
    [bool]$adoption.physical_launch_prerequisite_satisfied -and
    -not [bool]$adoption.physical_acceptance_authority
) "qualification/adoption boundary changed"

$attempt = $closure.attempt
$retainedHashes = [ordered]@{
    "physical-freeze.json" = [string]$attempt.physical_freeze_raw_sha256
    "matrix-authorization.json" = [string]$attempt.matrix_authorization_raw_sha256
    "matrix-terminal-paths.json" = [string]$attempt.matrix_terminal_paths_raw_sha256
    "complete-evaluator/evaluation.json" = [string]$attempt.complete_evaluation_raw_sha256
    "report.json" = [string]$attempt.report_raw_sha256
    "completion.json" = [string]$attempt.completion_raw_sha256
}
foreach ($entry in $retainedHashes.GetEnumerator()) {
    $path = Join-Path $EvidenceRoot ([string]$entry.Key)
    Assert-R23D22RetainedFile `
        $path ([string]$entry.Value) ([long](Get-Item $path).Length) `
        ([string]$entry.Key)
}

$files = @(Get-ChildItem -LiteralPath $EvidenceRoot -Recurse -File |
    Sort-Object @{Expression={
        [IO.Path]::GetRelativePath($EvidenceRoot, $_.FullName).Replace("\", "/")
    }})
$projectionLines = @()
$totalBytes = 0L
foreach ($file in $files) {
    $relative = [IO.Path]::GetRelativePath($EvidenceRoot, $file.FullName).
        Replace("\", "/")
    $raw = Get-R23D22ClosureSha256 $file.FullName
    $totalBytes += [long]$file.Length
    $projectionLines += "$relative`t$($file.Length)`t$($raw.Substring(7))"
    Assert-R23D22Closure (Test-R23D22Cas $raw ([long]$file.Length)) (
        "attempt file is not retained in CAS: $relative"
    )
}
$projection = ($projectionLines -join "`n") + "`n"
$treeSha = "sha256:" + [Convert]::ToHexString(
    [Security.Cryptography.SHA256]::HashData(
        [Text.Encoding]::UTF8.GetBytes($projection)
    )
).ToLowerInvariant()
Assert-R23D22Closure (
    $files.Count -eq 35 -and
    $totalBytes -eq 18328543 -and
    $treeSha -ceq [string]$attempt.evidence_tree_raw_sha256 -and
    [bool]$attempt.all_attempt_files_content_addressed -and
    [int]$attempt.attempt_files_content_addressed_before_closure_count -eq 34 -and
    [int]$attempt.newly_content_addressed_intermediate_file_count -eq 1 -and
    [string]$attempt.newly_content_addressed_intermediate_raw_sha256 -ceq
        "sha256:3ea35a06fe92fb5e88dbc74045d87e1fb65c18933c1305cd7ac295c979da6729"
) "complete attempt tree or CAS retention changed"

$report = Get-Content -LiteralPath (Join-Path $EvidenceRoot "report.json") -Raw |
    ConvertFrom-Json -AsHashtable -Depth 100
$evaluation = Get-Content -LiteralPath (
    Join-Path $EvidenceRoot "complete-evaluator\evaluation.json"
) -Raw | ConvertFrom-Json -AsHashtable -Depth 100
$completion = Get-Content -LiteralPath (Join-Path $EvidenceRoot "completion.json") -Raw |
    ConvertFrom-Json -AsHashtable -Depth 100
$authorization = Get-Content -LiteralPath (
    Join-Path $EvidenceRoot "matrix-authorization.json"
) -Raw | ConvertFrom-Json -AsHashtable -Depth 100
Assert-R23D22Closure (
    [string]$report.source.commit -ceq $sourceCommit -and
    [string]$report.source.tree_git_oid -ceq $sourceTree -and
    [string]$report.attempt_id -ceq $attemptId -and
    [string]$report.result_classification -ceq
        "invalid_or_incomplete_complete_matrix" -and
    -not [bool]$report.finite_matrix_result_valid -and
    @($report.ordered_matrix_cells).Count -eq 6 -and
    [string]$evaluation.classification -ceq
        "invalid_or_incomplete_complete_matrix" -and
    -not [bool]$evaluation.matrix_valid -and
    [int]$evaluation.outcome_failure_count -eq 1 -and
    [int]$evaluation.world_attempt_count -eq 6 -and
    [int]$evaluation.world_build_count -eq 6 -and
    @($evaluation.failure_codes).Count -eq 7 -and
    [int]$evaluation.historical_godot_binding.cell_count -eq 3 -and
    [bool]$evaluation.historical_godot_binding.scientific_positive -and
    -not [bool]$evaluation.historical_godot_binding.rerun_performed -and
    [string]$completion.status -ceq "invalid_or_incomplete_first_attempt" -and
    [string]$completion.attempt_id -ceq $attemptId -and
    [int]$completion.matrix_terminal_entry_count -eq 6 -and
    [bool]$completion.one_shot_identity_consumed -and
    -not [bool]$completion.same_identity_rerun_allowed -and
    [string]$authorization.attempt_id -ceq $attemptId -and
    -not [bool]$authorization.replacement_or_selective_rerun_permitted
) "report, evaluator, completion, or one-shot boundary changed"

$validCount = 0
$workerFailureCount = 0
$rowCount = 0
foreach ($cell in @($closure.cells)) {
    $cellId = [string]$cell.cell_id
    $reportCells = @($report.ordered_matrix_cells | Where-Object {
        [string]$_.cell_id -ceq $cellId
    })
    $evaluationCells = @($evaluation.cell_evaluations | Where-Object {
        [string]$_.cell_id -ceq $cellId
    })
    Assert-R23D22Closure (
        $reportCells.Count -eq 1 -and
        $evaluationCells.Count -eq 1 -and
        [int]$reportCells[0].process_exit_code -eq [int]$cell.process_exit_code -and
        [bool]$reportCells[0].process_timed_out -eq [bool]$cell.process_timed_out -and
        [string]$reportCells[0].terminal_marker_kind -ceq
            [string]$cell.terminal_marker_kind -and
        [string]$reportCells[0].terminal_entry_cas.sha256 -ceq
            [string]$cell.terminal_cas_sha256 -and
        [bool]$evaluationCells[0].entry_valid -eq [bool]$cell.entry_valid -and
        [bool]$evaluationCells[0].execution_integrity_passed -eq
            [bool]$cell.execution_integrity_passed
    ) "supervisor/evaluator projection changed for $cellId"

    $terminalPath = Join-Path $EvidenceRoot "matrix\$cellId\terminal-entry.json"
    Assert-R23D22RetainedFile `
        $terminalPath ([string]$cell.terminal_cas_sha256) `
        ([long](Get-Item $terminalPath).Length) "$cellId terminal"
    $terminal = Get-Content -LiteralPath $terminalPath -Raw |
        ConvertFrom-Json -AsHashtable -Depth 100
    if ([bool]$cell.entry_valid) {
        $validCount += 1
        Assert-R23D22Closure (
            [string]$terminal.schema_version -ceq
                "sporespore_qsdk_r23d22_engine_cell_report_v1" -and
            [bool]$terminal.execution.integrity_passed -and
            [int]$terminal.execution.world_attempt_count -eq 1 -and
            [int]$terminal.execution.world_build_count -eq 1 -and
            [int]$terminal.trace_summary.row_count -eq 3952 -and
            [string]$terminal.trace_artifact.sha256 -ceq
                [string]$cell.trace_cas_sha256 -and
            [long]$terminal.trace_artifact.byte_length -eq
                [long]$cell.trace_byte_length -and
            [double]$terminal.measurements.turn_phase_yaw_delta_rad -eq
                [double]$cell.turn_phase_yaw_delta_rad -and
            [double]$terminal.measurements.final_forward_displacement_m -eq
                [double]$cell.final_forward_displacement_m -and
            [double]$terminal.measurements.minimum_torso_height_m -eq
                [double]$cell.minimum_torso_height_m -and
            [double]$terminal.measurements.maximum_tilt_rad -eq
                [double]$cell.maximum_tilt_rad -and
            [int]$terminal.measurements.controller_error_count -eq 0 -and
            -not [bool]$terminal.measurements.quiescent_taper_gate_passed -and
            [string]$terminal.measurements.handoff_reason -ceq
                "deadline_forced_without_quiescence_confirmation" -and
            [int]$terminal.measurements.passive_terminal_step_count -eq 360 -and
            [int]$terminal.measurements.quiescent_taper_step_count -eq 20 -and
            [int]$terminal.measurements.taper_reset_count -eq 2 -and
            -not [bool]$evaluationCells[0].outcome.outcome_gate_passed -and
            (@($evaluationCells[0].outcome.failed_gate_ids) -join "|") -ceq
                "R23D22_QUIESCENT_TAPER"
        ) "valid Rapier reference observation changed"
        foreach ($limb in @("front_left", "front_right", "rear_left", "rear_right")) {
            Assert-R23D22Closure (
                [int]$terminal.measurements.contact_cycle_count_by_limb[$limb] -eq 4
            ) "Rapier reference contact cycles changed for $limb"
        }
        $rowCount += [int]$terminal.trace_summary.row_count
    } else {
        $workerFailureCount += 1
        Assert-R23D22Closure (
            [string]$terminal.schema_version -ceq
                "sporespore_qsdk_r23d22_worker_failure_v1" -and
            [string]$terminal.failure_code -ceq [string]$cell.failure_code -and
            [string]$terminal.failure_stage -ceq [string]$cell.failure_stage -and
            [int]$terminal.world_attempt_count -eq 1 -and
            [int]$terminal.world_build_count -eq 1 -and
            $null -eq $terminal.trace_artifact -and
            (@($evaluationCells[0].failure_codes) -join "|") -ceq
                [string]$cell.failure_code
        ) "worker failure changed for $cellId"
    }
}
Assert-R23D22Closure (
    $validCount -eq 1 -and
    $workerFailureCount -eq 5 -and
    $rowCount -eq 3952 -and
    [int]$attempt.execution_valid_report_count -eq 1 -and
    [int]$attempt.worker_failure_count -eq 5 -and
    [int]$attempt.trace_count -eq 1 -and
    [int]$attempt.trace_row_count_total -eq 3952 -and
    [int]$attempt.actual_world_attempt_count -eq 6 -and
    [int]$attempt.actual_world_build_count -eq 6
) "cell, trace, or actual-world totals changed"

$record = $closure.immutable_completion_record
$claims = $closure.claims
Assert-R23D22Closure (
    [string]$record.campaign_result_classification -ceq
        "invalid_or_incomplete_complete_matrix" -and
    -not [bool]$record.finite_matrix_result_valid -and
    -not [bool]$record.scientific_positive -and
    -not [bool]$record.scientific_negative -and
    -not [bool]$record.turning_outcome_available -and
    [int]$record.outcome_failure_count -eq 1 -and
    [int]$record.worker_failure_count -eq 5 -and
    [int]$record.failure_code_count -eq 7 -and
    -not [bool]$claims.r23d22_scientific_result -and
    -not [bool]$claims.r23d22_result_is_positive -and
    -not [bool]$claims.r23d22_result_is_negative -and
    [bool]$claims.r23d21_finite_godot_turning_candidate_preserved -and
    [bool]$claims.finite_rapier_reference_walking_observation -and
    -not [bool]$claims.finite_three_engine_turning_candidate -and
    -not [bool]$claims.independent_validation -and
    -not [bool]$claims.command_conditioned_turning -and
    -not [bool]$claims.bilateral_signed_turning -and
    -not [bool]$claims.portable_basic_turning -and
    -not [bool]$claims.finite_three_engine_turning -and
    -not [bool]$claims.cross_engine_equivalence -and
    -not [bool]$claims.q_sdk_r23_satisfied -and
    -not [bool]$claims.prone_to_standing -and
    -not [bool]$claims.release_authorized -and
    -not [bool]$claims.physical_acceptance_authority -and
    -not [bool]$closure.mechanism_and_interpretation.threshold_or_selector_changed_after_observation -and
    [bool]$closure.mechanism_and_interpretation.same_identity_reconstruction_or_rerun_forbidden -and
    [bool]$closure.mechanism_and_interpretation.successor_must_be_scientifically_distinct
) "invalid-result interpretation or claim boundary changed"

$attemptDirsBefore = @(
    Get-ChildItem -LiteralPath (Split-Path -Parent $EvidenceRoot) -Directory |
        Where-Object { $_.Name -like "qsdk-r23d22-*" }
).Count
$refusalOutput = & pwsh -NoLogo -NoProfile -File $supervisorPath -RunPhysical 2>&1 |
    Out-String
$refusalExit = $LASTEXITCODE
$global:LASTEXITCODE = 0
$attemptDirsAfter = @(
    Get-ChildItem -LiteralPath (Split-Path -Parent $EvidenceRoot) -Directory |
        Where-Object { $_.Name -like "qsdk-r23d22-*" }
).Count
Assert-R23D22Closure (
    $refusalExit -ne 0 -and
    $refusalOutput.Contains("QSDK_R23D22_PHYSICAL_REFUSAL") -and
    $refusalOutput.Contains('"reason":"r23d22_identity_closed"') -and
    $refusalOutput.Contains('"world_attempt_count":0') -and
    $refusalOutput.Contains('"world_build_count":0') -and
    $refusalOutput.Contains("QSDK-R23D22 CLOSED") -and
    $attemptDirsAfter -eq $attemptDirsBefore
) "same-identity rerun did not refuse before a world"

Write-Host (
    "QSDK_R23D22_CLOSURE_PASS " +
    "classification=invalid_or_incomplete_complete_matrix cells=6 " +
    "valid_reports=1 worker_failures=5 traces=1 rows=3952 worlds=6 " +
    "godot_rerun=False finite=False equivalence=False release=False rerun=False"
)
