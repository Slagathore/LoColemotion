#requires -Version 7.0

[CmdletBinding()]
param(
    [string]$EvidenceRoot = (
        "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence\" +
        "qsdk-r23d23-20260812T081403Z"
    )
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$sdkRoot = Join-Path $repoRoot "sdk"
$closurePath = Join-Path $sdkRoot "turning\r23d23_physical_closure_v1.json"
$supervisorPath = Join-Path $sdkRoot "run_qsdk_r23d23_supervisor.ps1"
$artifactStorePath = Join-Path $sdkRoot "content_addressed_artifact_store.ps1"
$campaignId = "QSDK-R23D23-IMPLEMENTATION-RECOVERY-TRANSFER-CONFORMANCE"
$gateId = "QSDK-R23D23"
$sourceCommit = "7bcd47c331630ed68c68098a24a881955b23f29d"
$sourceTree = "f4809cd183118c72905586d5f78853d956940e5f"
$attemptId = "7646859de000400298bffb94a7b8cb5f"
$mujocoFailure = (
    "QSDK_R23D23_MJC_RUNTIME_ERROR:RuntimeError:" +
    "QSDK_R23D8_NEUTRAL_UNEXPECTED_FORWARD_RECEIPT"
)

. $artifactStorePath

function Assert-R23D23Closure([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "QSDK-R23D23 closure: $Message" }
}

function Get-R23D23Sha256([string]$Path) {
    return "sha256:" + (
        Get-FileHash -LiteralPath $Path -Algorithm SHA256
    ).Hash.ToLowerInvariant()
}

function Get-R23D23GitBlobSha256([string]$RelativePath) {
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
        Assert-R23D23Closure $process.Start() "could not start Git blob reader"
        $stderrTask = $process.StandardError.ReadToEndAsync()
        $hasher = [Security.Cryptography.SHA256]::Create()
        try { $digest = $hasher.ComputeHash($process.StandardOutput.BaseStream) }
        finally { $hasher.Dispose() }
        $process.WaitForExit()
        $stderr = $stderrTask.GetAwaiter().GetResult()
        Assert-R23D23Closure ($process.ExitCode -eq 0) (
            "Git blob read failed for $RelativePath`: $stderr"
        )
        return "sha256:" + [Convert]::ToHexString($digest).ToLowerInvariant()
    } finally { $process.Dispose() }
}

function Test-R23D23Cas([string]$Sha256, [long]$ByteLength) {
    $artifactRoot = Join-Path (
        Get-SporeSporeArtifactEvidenceRoot -RepoRoot $repoRoot
    ) "artifacts\sha256"
    return Test-SporeSporeStoredArtifact `
        -Directory (Join-Path $artifactRoot $Sha256.Substring(7)) `
        -ExpectedSha256 $Sha256.Substring(7) `
        -ExpectedByteLength $ByteLength
}

function Assert-R23D23RetainedFile(
    [string]$Path,
    [string]$ExpectedSha256,
    [long]$ExpectedLength,
    [string]$Label
) {
    Assert-R23D23Closure (Test-Path -LiteralPath $Path -PathType Leaf) (
        "retained file is missing: $Label"
    )
    Assert-R23D23Closure (
        (Get-Item -LiteralPath $Path).Length -eq $ExpectedLength -and
        (Get-R23D23Sha256 $Path) -ceq $ExpectedSha256 -and
        (Test-R23D23Cas $ExpectedSha256 $ExpectedLength)
    ) "retained bytes or CAS changed: $Label"
}

Assert-R23D23Closure (
    (git -C $repoRoot rev-parse --show-toplevel).Replace("/", "\") -ceq
        $repoRoot -and
    (git -C $repoRoot remote get-url origin) -ceq
        "https://github.com/Slagathore/sporespore.git" -and
    (git -C $repoRoot cat-file -t $sourceCommit) -ceq "commit" -and
    (git -C $repoRoot rev-parse "$sourceCommit`^{tree}") -ceq $sourceTree
) "repository or frozen source identity changed"

foreach ($path in @($closurePath, $supervisorPath, $artifactStorePath, $EvidenceRoot)) {
    Assert-R23D23Closure (Test-Path -LiteralPath $path) "required path missing: $path"
}

$closure = Get-Content -LiteralPath $closurePath -Raw |
    ConvertFrom-Json -AsHashtable -Depth 100
Assert-R23D23Closure (
    [string]$closure.schema_version -ceq
        "sporespore_qsdk_r23d23_physical_closure_v1" -and
    [string]$closure.status -ceq
        "closed_consumed_invalid_complete_matrix_mujoco_terminal_receipt_failure" -and
    [string]$closure.campaign_id -ceq $campaignId -and
    [string]$closure.gate_id -ceq $gateId -and
    [string]$closure.source_identity.commit -ceq $sourceCommit -and
    [string]$closure.source_identity.tree_git_oid -ceq $sourceTree -and
    [int]$closure.source_identity.declared_worker_dependency_count -eq 57 -and
    [int]$closure.source_identity.declared_new_world_count -eq 6 -and
    -not [bool]$closure.source_identity.controller_or_physics_changed_by_closure
) "closure identity or frozen-source boundary changed"

foreach ($binding in @(
    $closure.source_identity.preregistration_path,
    $closure.source_identity.implementation_contract_path,
    $closure.source_identity.campaign_manifest_path
)) {
    $prefix = if ($binding -like "*preregistration*") {
        "preregistration"
    } elseif ($binding -like "*implementation_contract*") {
        "implementation_contract"
    } else { "campaign_manifest" }
    Assert-R23D23Closure (
        (git -C $repoRoot rev-parse "${sourceCommit}:$binding") -ceq
            [string]$closure.source_identity["${prefix}_git_blob_oid"] -and
        (Get-R23D23GitBlobSha256 $binding) -ceq
            [string]$closure.source_identity["${prefix}_raw_sha256"]
    ) "frozen source binding changed: $binding"
}

Assert-R23D23Closure (@($closure.immutable_lineage_bindings).Count -eq 2) (
    "immutable lineage count changed"
)
foreach ($lineage in @($closure.immutable_lineage_bindings)) {
    $lineagePath = Join-Path $repoRoot ([string]$lineage.closure_path)
    $auditPath = Join-Path $repoRoot ([string]$lineage.audit_path)
    Assert-R23D23Closure (
        (Get-R23D23Sha256 $lineagePath) -ceq
            [string]$lineage.closure_raw_sha256 -and
        (Get-R23D23Sha256 $auditPath) -ceq
            [string]$lineage.audit_raw_sha256 -and
        -not [bool]$lineage.rerun_performed
    ) "immutable lineage bytes changed: $($lineage.gate_id)"
}

$qualification = $closure.campaign_local_qualification
Assert-R23D23RetainedFile `
    ([string]$qualification.accepted_scoped_attestation_path) `
    ([string]$qualification.accepted_scoped_attestation_raw_sha256) `
    ([long]$qualification.accepted_scoped_attestation_byte_length) `
    "campaign-local attestation"
Assert-R23D23RetainedFile `
    ([string]$qualification.adoption_path) `
    ([string]$qualification.adoption_raw_sha256) `
    ([long]$qualification.adoption_byte_length) `
    "campaign-local adoption"
$adoption = Get-Content -LiteralPath $qualification.adoption_path -Raw |
    ConvertFrom-Json -AsHashtable -Depth 100
Assert-R23D23Closure (
    [int]$qualification.executed_gate_count -eq 17 -and
    [int]$qualification.global_gate_count -eq 12 -and
    [int]$qualification.lineage_gate_count -eq 2 -and
    [int]$qualification.campaign_gate_count -eq 3 -and
    [int]$qualification.gate_cas_object_count -eq 51 -and
    [bool]$adoption.commissioned_executor_verified -and
    [bool]$adoption.physical_launch_prerequisite_satisfied -and
    -not [bool]$adoption.physical_acceptance_authority
) "campaign-local qualification or adoption changed"

$attempt = $closure.attempt
$retainedFiles = @(Get-ChildItem -LiteralPath $EvidenceRoot -Recurse -File)
$projectionLines = @(
    $retainedFiles |
        Sort-Object {
            [IO.Path]::GetRelativePath($EvidenceRoot, $_.FullName).Replace("\", "/")
        } |
        ForEach-Object {
            $relative = [IO.Path]::GetRelativePath(
                $EvidenceRoot, $_.FullName
            ).Replace("\", "/")
            $sha = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).
                Hash.ToLowerInvariant()
            "$relative`t$($_.Length)`t$sha"
        }
)
$projectionBytes = [Text.Encoding]::UTF8.GetBytes(
    ($projectionLines -join "`n") + "`n"
)
$hasher = [Security.Cryptography.SHA256]::Create()
try {
    $projectionSha = "sha256:" + [Convert]::ToHexString(
        $hasher.ComputeHash($projectionBytes)
    ).ToLowerInvariant()
} finally { $hasher.Dispose() }

foreach ($file in $retainedFiles) {
    $sha = Get-R23D23Sha256 $file.FullName
    Assert-R23D23Closure (Test-R23D23Cas $sha $file.Length) (
        "attempt file is not content-addressed: $($file.FullName)"
    )
}
Assert-R23D23Closure (
    [string]$attempt.attempt_root -ceq $EvidenceRoot.Replace("\", "/") -and
    [string]$attempt.attempt_id -ceq $attemptId -and
    [int]$attempt.supervisor_exit_code -eq 1 -and
    $retainedFiles.Count -eq 39 -and
    [long]($retainedFiles | Measure-Object Length -Sum).Sum -eq 54356840 -and
    $projectionSha -ceq
        "sha256:dcb939ac8ee192315cbbf1e5a291a6620d64f04e9e611e1200a5e444048124d8" -and
    [bool]$attempt.all_attempt_files_content_addressed -and
    [int]$attempt.newly_content_addressed_intermediate_file_count -eq 3 -and
    @($attempt.newly_content_addressed_intermediate_raw_sha256).Count -eq 3
) "complete attempt tree or CAS retention changed"

$attemptBindings = [ordered]@{
    "physical-freeze.json" = [string]$attempt.physical_freeze_raw_sha256
    "matrix-authorization.json" = [string]$attempt.matrix_authorization_raw_sha256
    "matrix-terminal-paths.json" = [string]$attempt.matrix_terminal_paths_raw_sha256
    "complete-evaluator\evaluation.json" = [string]$attempt.complete_evaluation_raw_sha256
    "report.json" = [string]$attempt.report_raw_sha256
    "completion.json" = [string]$attempt.completion_raw_sha256
}
foreach ($relative in $attemptBindings.Keys) {
    Assert-R23D23Closure (
        (Get-R23D23Sha256 (Join-Path $EvidenceRoot $relative)) -ceq
            $attemptBindings[$relative]
    ) "attempt binding changed: $relative"
}

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
Assert-R23D23Closure (
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
    [int]$evaluation.outcome_failure_count -eq 4 -and
    [int]$evaluation.world_attempt_count -eq 6 -and
    [int]$evaluation.world_build_count -eq 6 -and
    @($evaluation.failure_codes).Count -eq 4 -and
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
    $reportCell = @($report.ordered_matrix_cells | Where-Object {
        [string]$_.cell_id -ceq $cellId
    })
    $evaluationCell = @($evaluation.cell_evaluations | Where-Object {
        [string]$_.cell_id -ceq $cellId
    })
    Assert-R23D23Closure (
        $reportCell.Count -eq 1 -and
        $evaluationCell.Count -eq 1 -and
        [int]$reportCell[0].process_exit_code -eq [int]$cell.process_exit_code -and
        [bool]$reportCell[0].process_timed_out -eq [bool]$cell.process_timed_out -and
        [string]$reportCell[0].terminal_marker_kind -ceq
            [string]$cell.terminal_marker_kind -and
        [string]$reportCell[0].terminal_entry_cas.sha256 -ceq
            [string]$cell.terminal_cas_sha256 -and
        [bool]$evaluationCell[0].entry_valid -eq [bool]$cell.entry_valid -and
        [bool]$evaluationCell[0].execution_integrity_passed -eq
            [bool]$cell.execution_integrity_passed
    ) "supervisor/evaluator projection changed for $cellId"

    $terminalPath = Join-Path $EvidenceRoot "matrix\$cellId\terminal-entry.json"
    Assert-R23D23RetainedFile `
        $terminalPath ([string]$cell.terminal_cas_sha256) `
        ([long](Get-Item $terminalPath).Length) "$cellId terminal"
    $terminal = Get-Content -LiteralPath $terminalPath -Raw |
        ConvertFrom-Json -AsHashtable -Depth 100
    if ([bool]$cell.entry_valid) {
        $validCount += 1
        Assert-R23D23Closure (
            [string]$terminal.schema_version -ceq
                "sporespore_qsdk_r23d23_engine_cell_report_v1" -and
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
            -not [bool]$evaluationCell[0].outcome.outcome_gate_passed -and
            (@($evaluationCell[0].outcome.failed_gate_ids) -join "|") -ceq
                (@($cell.failed_gate_ids) -join "|")
        ) "execution-valid Rapier observation changed for $cellId"
        $rowCount += [int]$terminal.trace_summary.row_count
    } else {
        $workerFailureCount += 1
        Assert-R23D23Closure (
            [string]$terminal.schema_version -ceq
                "sporespore_qsdk_r23d23_worker_failure_v1" -and
            [string]$terminal.failure_code -ceq $mujocoFailure -and
            [string]$terminal.failure_stage -ceq "settlement_complete" -and
            [int]$terminal.world_attempt_count -eq 1 -and
            [int]$terminal.world_build_count -eq 1 -and
            $null -eq $terminal.trace_artifact -and
            (@($evaluationCell[0].failure_codes) -join "|") -ceq $mujocoFailure
        ) "MuJoCo worker failure changed for $cellId"
    }
}
Assert-R23D23Closure (
    $validCount -eq 3 -and
    $workerFailureCount -eq 3 -and
    $rowCount -eq 11856 -and
    [int]$attempt.execution_valid_report_count -eq 3 -and
    [int]$attempt.worker_failure_count -eq 3 -and
    [int]$attempt.trace_count -eq 3 -and
    [int]$attempt.trace_row_count_total -eq 11856 -and
    [int]$attempt.actual_world_attempt_count -eq 6 -and
    [int]$attempt.actual_world_build_count -eq 6
) "cell, trace, or actual-world totals changed"

$record = $closure.immutable_completion_record
$claims = $closure.claims
Assert-R23D23Closure (
    [string]$record.campaign_result_classification -ceq
        "invalid_or_incomplete_complete_matrix" -and
    -not [bool]$record.finite_matrix_result_valid -and
    -not [bool]$record.scientific_positive -and
    -not [bool]$record.scientific_negative -and
    -not [bool]$record.turning_outcome_available -and
    [bool]$record.conditioned_response_available_for_rapier -and
    -not [bool]$record.conditioned_response_available_for_mujoco -and
    [int]$record.outcome_failure_count -eq 4 -and
    [int]$record.worker_failure_count -eq 3 -and
    [int]$record.failure_code_count -eq 4 -and
    -not [bool]$claims.r23d23_scientific_result -and
    -not [bool]$claims.r23d23_result_is_positive -and
    -not [bool]$claims.r23d23_result_is_negative -and
    [bool]$claims.r23d21_finite_godot_turning_candidate_preserved -and
    [bool]$claims.rapier_receipt_implementation_repair_physically_exercised -and
    -not [bool]$claims.finite_rapier_turning_candidate -and
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
        Where-Object { $_.Name -like "qsdk-r23d23-*" }
).Count
$refusalOutput = & pwsh -NoLogo -NoProfile -File $supervisorPath -RunPhysical 2>&1 |
    Out-String
$refusalExit = $LASTEXITCODE
$global:LASTEXITCODE = 0
$attemptDirsAfter = @(
    Get-ChildItem -LiteralPath (Split-Path -Parent $EvidenceRoot) -Directory |
        Where-Object { $_.Name -like "qsdk-r23d23-*" }
).Count
Assert-R23D23Closure (
    $refusalExit -ne 0 -and
    $refusalOutput.Contains("QSDK_R23D23_PHYSICAL_REFUSAL") -and
    $refusalOutput.Contains('"reason":"r23d23_identity_closed"') -and
    $refusalOutput.Contains('"world_attempt_count":0') -and
    $refusalOutput.Contains('"world_build_count":0') -and
    $refusalOutput.Contains("QSDK-R23D23 CLOSED") -and
    $attemptDirsAfter -eq $attemptDirsBefore
) "same-identity rerun did not refuse before a world"

Write-Host (
    "QSDK_R23D23_CLOSURE_PASS " +
    "classification=invalid_or_incomplete_complete_matrix cells=6 " +
    "valid_reports=3 worker_failures=3 traces=3 rows=11856 worlds=6 " +
    "godot_rerun=False finite=False equivalence=False release=False rerun=False"
)
