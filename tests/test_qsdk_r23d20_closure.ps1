#requires -Version 7.0

[CmdletBinding()]
param(
    [string]$EvidenceRoot = (
        "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence\" +
        "qsdk-r23d20-20260812T043309Z"
    )
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$sdkRoot = Join-Path $repoRoot "sdk"
$closurePath = Join-Path $sdkRoot "turning\r23d20_physical_closure_v1.json"
$manifestPath = Join-Path $sdkRoot "turning\r23d20_campaign_attestation_manifest_v1.json"
$artifactStorePath = Join-Path $sdkRoot "content_addressed_artifact_store.ps1"
$campaignId = "QSDK-R23D20-ACTUAL-SESSION-INTEGRATION-RECOVERY-GODOT-DEVELOPMENT"
$gateId = "QSDK-R23D20"
$sourceCommit = "690751073c946445843211debae5606e9aa2e120"
$sourceTree = "16a06919a56c7ab53271e465339bed82e51bbace"
$attemptId = "989ac403f45c4186925cdc03f3457f62"

. $artifactStorePath

function Assert-R23D20Closure([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "QSDK-R23D20 closure: $Message" }
}

function Get-R23D20ClosureSha256([string]$Path) {
    return "sha256:" + (
        Get-FileHash -LiteralPath $Path -Algorithm SHA256
    ).Hash.ToLowerInvariant()
}

function Get-R23D20GitBlobSha256([string]$RelativePath) {
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
        Assert-R23D20Closure $process.Start() "could not start Git blob reader"
        $stderrTask = $process.StandardError.ReadToEndAsync()
        $hasher = [Security.Cryptography.SHA256]::Create()
        try { $digest = $hasher.ComputeHash($process.StandardOutput.BaseStream) }
        finally { $hasher.Dispose() }
        $process.WaitForExit()
        $stderr = $stderrTask.GetAwaiter().GetResult()
        Assert-R23D20Closure ($process.ExitCode -eq 0) (
            "Git blob read failed for $RelativePath`: $stderr"
        )
        return "sha256:" + [Convert]::ToHexString($digest).ToLowerInvariant()
    } finally { $process.Dispose() }
}

function Test-R23D20Cas([string]$Sha256, [long]$ByteLength) {
    $artifactRoot = Join-Path (
        Get-SporeSporeArtifactEvidenceRoot -RepoRoot $repoRoot
    ) "artifacts\sha256"
    return Test-SporeSporeStoredArtifact `
        -Directory (Join-Path $artifactRoot $Sha256.Substring(7)) `
        -ExpectedSha256 $Sha256.Substring(7) `
        -ExpectedByteLength $ByteLength
}

function Assert-R23D20RetainedFile(
    [string]$Path,
    [string]$ExpectedSha256,
    [string]$Label
) {
    Assert-R23D20Closure (Test-Path -LiteralPath $Path -PathType Leaf) (
        "retained file is missing: $Label"
    )
    $item = Get-Item -LiteralPath $Path
    Assert-R23D20Closure (
        (Get-R23D20ClosureSha256 $Path) -ceq $ExpectedSha256 -and
        (Test-R23D20Cas $ExpectedSha256 ([long]$item.Length))
    ) "retained bytes or CAS changed: $Label"
}

Assert-R23D20Closure (
    (git -C $repoRoot rev-parse --show-toplevel).Replace("/", "\") -ceq
        $repoRoot -and
    (git -C $repoRoot remote get-url origin) -ceq
        "https://github.com/Slagathore/sporespore.git" -and
    (git -C $repoRoot cat-file -t $sourceCommit) -ceq "commit" -and
    (git -C $repoRoot rev-parse "$sourceCommit`^{tree}") -ceq $sourceTree
) "repository or frozen source identity changed"

foreach ($path in @($closurePath, $manifestPath, $artifactStorePath, $EvidenceRoot)) {
    Assert-R23D20Closure (Test-Path -LiteralPath $path) "required path missing: $path"
}

$closure = Get-Content -LiteralPath $closurePath -Raw |
    ConvertFrom-Json -AsHashtable -Depth 100
Assert-R23D20Closure (
    [string]$closure.schema_version -ceq
        "sporespore_qsdk_r23d20_physical_closure_v1" -and
    [string]$closure.status -ceq
        "closed_consumed_valid_complete_negative_negative_command_not_conditioned" -and
    [string]$closure.campaign_id -ceq $campaignId -and
    [string]$closure.gate_id -ceq $gateId -and
    [string]$closure.source_identity.commit -ceq $sourceCommit -and
    [string]$closure.source_identity.tree_git_oid -ceq $sourceTree -and
    [int]$closure.source_identity.declared_worker_dependency_count -eq 67 -and
    [int]$closure.source_identity.runtime_artifact_count -eq 2 -and
    -not [bool]$closure.source_identity.controller_or_physics_changed_by_closure
) "closure identity or frozen-source boundary changed"

$manifestSha = "sha256:d8adeeef0ffd377550d3e9232c2d3cf70590414f5b0017f6810d3e8e348c2104"
Assert-R23D20Closure (
    (Get-R23D20GitBlobSha256 "sdk/turning/r23d20_campaign_attestation_manifest_v1.json") -ceq
        $manifestSha
) "frozen campaign manifest changed"
$manifest = Get-Content -LiteralPath $manifestPath -Raw |
    ConvertFrom-Json -AsHashtable -Depth 100
Assert-R23D20Closure (
    [string]$manifest.campaign_id -ceq $campaignId -and
    [int]$manifest.declared_physical_world_count -eq 3 -and
    [int]$manifest.declared_lineage_gate_count -eq 1 -and
    [int]$manifest.declared_campaign_gate_count -eq 3
) "campaign manifest identity changed"
foreach ($binding in @($manifest.source_bindings)) {
    Assert-R23D20Closure (
        (Get-R23D20GitBlobSha256 ([string]$binding.path)) -ceq
            [string]$binding.raw_sha256
    ) "frozen Git blob changed: $($binding.path)"
}

$failurePath = [string]$closure.prelaunch_incident.failure_path
Assert-R23D20RetainedFile `
    $failurePath ([string]$closure.prelaunch_incident.failure_raw_sha256) `
    "prelaunch qualification refusal"
$prelaunchFailure = Get-Content -LiteralPath $failurePath -Raw |
    ConvertFrom-Json -AsHashtable -Depth 100
Assert-R23D20Closure (
    [string]$closure.prelaunch_incident.failed_gate_id -ceq
        "CAK1-EVIDENCE-PROVENANCE" -and
    [string]$prelaunchFailure.source_commit -ceq
        "d60c9a463b949591eacc5dc175944d8e2e28e867" -and
    $prelaunchFailure.message.Contains("CAK1-EVIDENCE-PROVENANCE") -and
    -not [bool]$prelaunchFailure.physical_launch_prerequisite_satisfied -and
    -not [bool]$prelaunchFailure.physical_acceptance_authority -and
    [int]$closure.prelaunch_incident.world_build_count -eq 0 -and
    -not [bool]$closure.prelaunch_incident.physical_identity_consumed
) "prelaunch refusal boundary changed"

$qualification = $closure.campaign_local_qualification
$attestationPath = [string]$qualification.scoped_attestation_path
$adoptionPath = [string]$qualification.adoption_path
Assert-R23D20RetainedFile `
    $attestationPath ([string]$qualification.scoped_attestation_raw_sha256) `
    "scoped attestation"
Assert-R23D20RetainedFile `
    $adoptionPath ([string]$qualification.adoption_raw_sha256) `
    "attestation adoption"
$attestation = Get-Content -LiteralPath $attestationPath -Raw |
    ConvertFrom-Json -AsHashtable -Depth 100
$adoption = Get-Content -LiteralPath $adoptionPath -Raw |
    ConvertFrom-Json -AsHashtable -Depth 100
Assert-R23D20Closure (
    [string]$attestation.campaign_id -ceq $campaignId -and
    [string]$attestation.source.commit -ceq $sourceCommit -and
    [bool]$attestation.claims.campaign_local_qualification_passed -and
    [int]$adoption.declared_physical_world_count -eq 3 -and
    [int]$adoption.executed_gate_count -eq 16 -and
    [int]$adoption.global_gate_count -eq 12 -and
    [int]$adoption.lineage_gate_count -eq 1 -and
    [int]$adoption.campaign_gate_count -eq 3 -and
    [bool]$adoption.physical_launch_prerequisite_satisfied -and
    -not [bool]$adoption.claims.physical_campaign_executed -and
    -not [bool]$adoption.physical_acceptance_authority
) "campaign-local qualification or adoption changed"

$attempt = $closure.attempt
$retainedHashes = [ordered]@{
    "physical-freeze.json" = [string]$attempt.physical_freeze_raw_sha256
    "matrix-authorization.json" = [string]$attempt.matrix_authorization_raw_sha256
    "matrix-terminal-paths.json" = [string]$attempt.matrix_terminal_paths_raw_sha256
    "evaluation.json" = [string]$attempt.complete_evaluation_raw_sha256
    "report.json" = [string]$attempt.report_raw_sha256
    "completion.json" = [string]$attempt.completion_raw_sha256
}
foreach ($entry in $retainedHashes.GetEnumerator()) {
    Assert-R23D20RetainedFile `
        (Join-Path $EvidenceRoot ([string]$entry.Key)) `
        ([string]$entry.Value) ([string]$entry.Key)
}

$files = @(Get-ChildItem -LiteralPath $EvidenceRoot -Recurse -File | Sort-Object FullName)
$projectionLines = @()
$totalBytes = 0L
foreach ($file in $files) {
    $relative = [IO.Path]::GetRelativePath($EvidenceRoot, $file.FullName).Replace("\", "/")
    $raw = Get-R23D20ClosureSha256 $file.FullName
    $totalBytes += [long]$file.Length
    $projectionLines += "$relative`t$($file.Length)`t$($raw.Substring(7))"
    Assert-R23D20Closure (Test-R23D20Cas $raw ([long]$file.Length)) (
        "attempt file is not retained in CAS: $relative"
    )
}
$projection = ($projectionLines -join "`n") + "`n"
$treeSha = "sha256:" + [Convert]::ToHexString(
    [Security.Cryptography.SHA256]::HashData(
        [Text.Encoding]::UTF8.GetBytes($projection)
    )
).ToLowerInvariant()
Assert-R23D20Closure (
    $files.Count -eq 26 -and
    $totalBytes -eq 63087927 -and
    $treeSha -ceq [string]$attempt.evidence_tree_raw_sha256 -and
    [bool]$attempt.all_attempt_files_content_addressed -and
    [int]$attempt.newly_content_addressed_intermediate_file_count -eq 4
) "complete attempt tree or CAS retention changed"

$report = Get-Content -LiteralPath (Join-Path $EvidenceRoot "report.json") -Raw |
    ConvertFrom-Json -AsHashtable -Depth 100
$evaluation = Get-Content -LiteralPath (Join-Path $EvidenceRoot "evaluation.json") -Raw |
    ConvertFrom-Json -AsHashtable -Depth 100
$completion = Get-Content -LiteralPath (Join-Path $EvidenceRoot "completion.json") -Raw |
    ConvertFrom-Json -AsHashtable -Depth 100
$authorization = Get-Content -LiteralPath (
    Join-Path $EvidenceRoot "matrix-authorization.json"
) -Raw | ConvertFrom-Json -AsHashtable -Depth 100
Assert-R23D20Closure (
    [string]$report.source.commit -ceq $sourceCommit -and
    [string]$report.attempt_id -ceq $attemptId -and
    [string]$report.result_classification -ceq "valid_complete_negative" -and
    -not [bool]$report.finite_godot_mechanism_candidate -and
    [string]$evaluation.classification -ceq "valid_complete_negative" -and
    [bool]$evaluation.matrix_valid -and
    [int]$evaluation.world_attempt_count -eq 3 -and
    [int]$evaluation.world_build_count -eq 3 -and
    [string]$completion.status -ceq "valid_complete_negative_first_attempt" -and
    [string]$completion.attempt_id -ceq $attemptId -and
    [int]$completion.matrix_terminal_entry_count -eq 3 -and
    [bool]$completion.one_shot_identity_consumed -and
    -not [bool]$completion.same_identity_rerun_allowed -and
    [string]$authorization.attempt_id -ceq $attemptId -and
    -not [bool]$authorization.replacement_or_selective_rerun_permitted
) "report, evaluator, completion, or one-shot boundary changed"

$totalRows = 0
$totalAttempts = 0
$totalBuilds = 0
foreach ($cell in @($closure.cells)) {
    $cellId = [string]$cell.cell_id
    $reportCell = @($report.ordered_matrix_cells | Where-Object {
        [string]$_.cell_id -ceq $cellId
    })
    $evaluationCell = @($evaluation.cell_evaluations | Where-Object {
        [string]$_.cell_id -ceq $cellId
    })
    Assert-R23D20Closure (
        $reportCell.Count -eq 1 -and
        $evaluationCell.Count -eq 1 -and
        [int]$reportCell[0].process.exit_code -eq 0 -and
        -not [bool]$reportCell[0].process.timed_out -and
        [string]$reportCell[0].marker_kind -ceq "worker_report_terminal" -and
        [string]$reportCell[0].stdout_cas.sha256 -ceq [string]$cell.stdout_cas_sha256 -and
        [string]$reportCell[0].godot_log_cas.sha256 -ceq [string]$cell.godot_log_cas_sha256 -and
        [string]$reportCell[0].terminal_cas.sha256 -ceq [string]$cell.terminal_cas_sha256 -and
        [bool]$evaluationCell[0].entry_valid -and
        [bool]$evaluationCell[0].execution_integrity_passed -and
        [bool]$evaluationCell[0].outcome.walking_and_taper_gate_passed
    ) "supervisor or evaluator retention changed for $cellId"
    $terminalPath = Join-Path $EvidenceRoot "matrix\$cellId\terminal-entry.json"
    Assert-R23D20RetainedFile $terminalPath ([string]$cell.terminal_cas_sha256) (
        "$cellId terminal"
    )
    $terminal = Get-Content -LiteralPath $terminalPath -Raw |
        ConvertFrom-Json -AsHashtable -Depth 100
    Assert-R23D20Closure (
        [string]$terminal.schema_version -ceq
            "sporespore_qsdk_r23d20_engine_cell_report_v1" -and
        [string]$terminal.campaign_id -ceq $campaignId -and
        [string]$terminal.gate_id -ceq $gateId -and
        [string]$terminal.source_commit -ceq $sourceCommit -and
        [string]$terminal.arm_id -ceq [string]$cell.arm_id -and
        [double]$terminal.turn_heading_offset_rad -eq
            [double]$cell.turn_heading_offset_rad -and
        [bool]$terminal.execution.integrity_passed -and
        [int]$terminal.execution.world_attempt_count -eq 1 -and
        [int]$terminal.execution.world_build_count -eq 1 -and
        [int]$terminal.execution.controller_semantic_step_count -eq 2992 -and
        [int]$terminal.execution.terminal_quiescent_taper_step_count -eq 960 -and
        [int]$terminal.trace_summary.row_count -eq 3952 -and
        [string]$terminal.trace_artifact.sha256 -ceq [string]$cell.trace_cas_sha256 -and
        [double]$terminal.measurements.turn_phase_yaw_delta_rad -eq
            [double]$cell.turn_phase_yaw_delta_rad -and
        [bool]$terminal.measurements.quiescent_taper_gate_passed -and
        [int]$terminal.measurements.passive_terminal_step_count -eq 839 -and
        [int]$terminal.measurements.post_handoff_contact_loss_step_count -eq 0 -and
        [int]$terminal.measurements.controller_error_count -eq 0
    ) "worker terminal or measurement changed for $cellId"
    $matchingTraces = @(Get-ChildItem -LiteralPath (Join-Path $EvidenceRoot "traces") -File |
        Where-Object { (Get-R23D20ClosureSha256 $_.FullName) -ceq [string]$cell.trace_cas_sha256 })
    Assert-R23D20Closure ($matchingTraces.Count -eq 1) "retained trace changed for $cellId"
    Assert-R23D20Closure (
        Test-R23D20Cas ([string]$cell.trace_cas_sha256) ([long]$cell.trace_byte_length)
    ) "trace CAS changed for $cellId"
    $totalRows += [int]$terminal.trace_summary.row_count
    $totalAttempts += [int]$terminal.execution.world_attempt_count
    $totalBuilds += [int]$terminal.execution.world_build_count
}
Assert-R23D20Closure (
    $totalRows -eq 11856 -and
    $totalAttempts -eq 3 -and
    $totalBuilds -eq 3 -and
    [int]$attempt.trace_count -eq 3 -and
    [int]$attempt.trace_row_count_total -eq 11856 -and
    [int]$attempt.actual_world_attempt_count -eq 3 -and
    [int]$attempt.actual_world_build_count -eq 3
) "trace or actual-world totals changed"

$response = $closure.command_conditioned_response
$claims = $closure.claims
Assert-R23D20Closure (
    [double]$response.reference_turn_phase_yaw_delta_rad -eq -0.241120030652402 -and
    [double]$response.positive_turn_phase_yaw_delta_rad -eq 0.366803012832242 -and
    [double]$response.negative_turn_phase_yaw_delta_rad -eq -0.208428507977459 -and
    [double]$response.positive_minus_reference_rad -eq 0.607923043484644 -and
    [double]$response.negative_minus_reference_rad -eq 0.03269152267494302 -and
    [bool]$response.positive_conditioned_gate_passed -and
    -not [bool]$response.negative_conditioned_gate_passed -and
    -not [bool]$response.conditioned_response_gate_passed -and
    (@($response.failure_codes) -join "|") -ceq
        "R23D20_NEGATIVE_COMMAND_CONDITIONED_YAW" -and
    [bool]$closure.immutable_completion_record.finite_matrix_result_valid -and
    -not [bool]$closure.immutable_completion_record.scientific_positive -and
    [bool]$closure.immutable_completion_record.scientific_negative -and
    [bool]$closure.immutable_completion_record.turning_outcome_available -and
    [bool]$closure.immutable_completion_record.all_three_cells_walked_and_tapered -and
    [bool]$closure.mechanism_and_interpretation.same_identity_reconstruction_or_rerun_forbidden -and
    [bool]$claims.r23d20_scientific_result -and
    [bool]$claims.r23d20_result_is_negative -and
    [bool]$claims.actual_session_trace_integration_repaired -and
    [bool]$claims.all_three_finite_godot_cells_walked_and_tapered -and
    [bool]$claims.positive_command_conditioned_response_observed -and
    -not [bool]$claims.negative_command_conditioned_response_observed -and
    -not [bool]$claims.command_conditioned_turning -and
    -not [bool]$claims.bilateral_signed_turning -and
    -not [bool]$claims.portable_basic_turning -and
    -not [bool]$claims.cross_engine_equivalence -and
    -not [bool]$claims.q_sdk_r23_satisfied -and
    -not [bool]$claims.prone_to_standing -and
    -not [bool]$claims.release_authorized -and
    -not [bool]$claims.physical_acceptance_authority
) "negative-result interpretation or claim boundary changed"

Write-Host (
    "QSDK_R23D20_CLOSURE_PASS classification=valid_complete_negative " +
    "cells=3 walking_and_taper=3 traces=3 rows=11856 worlds=3 " +
    "positive_conditioned=True negative_conditioned=False " +
    "rerun=False turning=False equivalence=False release=False"
)
