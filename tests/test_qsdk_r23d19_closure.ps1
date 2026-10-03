#requires -Version 7.0

[CmdletBinding()]
param(
    [string]$EvidenceRoot = (
        "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence\" +
        "qsdk-r23d19-20260812T034953Z"
    )
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$sdkRoot = Join-Path $repoRoot "sdk"
$closurePath = Join-Path $sdkRoot "turning\r23d19_physical_closure_v1.json"
$artifactStorePath = Join-Path $sdkRoot "content_addressed_artifact_store.ps1"
$campaignId = "QSDK-R23D19-HEADING-ALIGNED-PATH-GODOT-DEVELOPMENT"
$gateId = "QSDK-R23D19"
$sourceCommit = "28a4e9113d2e72e49b7b672891d47cc3633bbfe0"
$sourceTree = "2d1cececfb507c791d58ca645b45435463956b9d"
$attemptId = "6bee00aa43f54bb8bfcbeafd7b03c16a"
$workerMarkerPrefix = "QSDK_R23D19_GODOT_JOLT_TERMINAL "

. $artifactStorePath

function Assert-R23D19Closure([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "QSDK-R23D19 closure: $Message" }
}

function Get-R23D19ClosureSha256([string]$Path) {
    return "sha256:" + (
        Get-FileHash -LiteralPath $Path -Algorithm SHA256
    ).Hash.ToLowerInvariant()
}

function Get-R23D19GitBlobSha256([string]$RelativePath) {
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
        Assert-R23D19Closure $process.Start() "could not start Git blob reader"
        $stderrTask = $process.StandardError.ReadToEndAsync()
        $hasher = [Security.Cryptography.SHA256]::Create()
        try { $digest = $hasher.ComputeHash($process.StandardOutput.BaseStream) }
        finally { $hasher.Dispose() }
        $process.WaitForExit()
        $stderr = $stderrTask.GetAwaiter().GetResult()
        Assert-R23D19Closure ($process.ExitCode -eq 0) (
            "Git blob read failed for $RelativePath`: $stderr"
        )
        return "sha256:" + [Convert]::ToHexString($digest).ToLowerInvariant()
    } finally { $process.Dispose() }
}

function Test-R23D19Cas([string]$Sha256, [long]$ByteLength) {
    $artifactRoot = Join-Path (
        Get-SporeSporeArtifactEvidenceRoot -RepoRoot $repoRoot
    ) "artifacts\sha256"
    $digest = $Sha256.Substring(7)
    return Test-SporeSporeStoredArtifact `
        -Directory (Join-Path $artifactRoot $digest) `
        -ExpectedSha256 $digest `
        -ExpectedByteLength $ByteLength
}

function Assert-R23D19RetainedFile(
    [string]$Path,
    [string]$ExpectedSha256,
    [string]$Label
) {
    Assert-R23D19Closure (Test-Path -LiteralPath $Path -PathType Leaf) (
        "retained file is missing: $Label"
    )
    $item = Get-Item -LiteralPath $Path
    Assert-R23D19Closure (
        (Get-R23D19ClosureSha256 $Path) -ceq $ExpectedSha256 -and
        (Test-R23D19Cas $ExpectedSha256 ([long]$item.Length))
    ) "retained bytes or CAS changed: $Label"
}

Assert-R23D19Closure (
    (git -C $repoRoot rev-parse --show-toplevel).Replace("/", "\") -ceq
        $repoRoot -and
    (git -C $repoRoot remote get-url origin) -ceq
        "https://github.com/Slagathore/sporespore.git" -and
    (git -C $repoRoot cat-file -t $sourceCommit) -ceq "commit" -and
    (git -C $repoRoot rev-parse "$sourceCommit`^{tree}") -ceq $sourceTree
) "repository or frozen source identity changed"

foreach ($path in @($closurePath, $artifactStorePath, $EvidenceRoot)) {
    Assert-R23D19Closure (Test-Path -LiteralPath $path) "required path missing: $path"
}

$closure = Get-Content -LiteralPath $closurePath -Raw |
    ConvertFrom-Json -AsHashtable -Depth 100
Assert-R23D19Closure (
    [string]$closure.schema_version -ceq
        "sporespore_qsdk_r23d19_physical_closure_v1" -and
    [string]$closure.status -ceq
        "closed_consumed_invalid_complete_matrix_three_worker_trace_failures" -and
    [string]$closure.campaign_id -ceq $campaignId -and
    [string]$closure.gate_id -ceq $gateId -and
    [string]$closure.source_identity.commit -ceq $sourceCommit -and
    [string]$closure.source_identity.tree_git_oid -ceq $sourceTree -and
    [int]$closure.source_identity.declared_worker_dependency_count -eq 67 -and
    [int]$closure.source_identity.runtime_artifact_count -eq 2 -and
    -not [bool]$closure.source_identity.controller_or_physics_changed_by_closure
) "closure identity or frozen-source boundary changed"

$sourceHashes = [ordered]@{
    "sdk/turning/r23d19_heading_aligned_path_preregistration_v1.json" =
        "sha256:4903bd501d0d726b55bc0d0311a9a22139e3f69dd2e4e9b33b2a516865aa025b"
    "sdk/turning/r23d19_physical_implementation_contract_v1.json" =
        "sha256:437963da1ea3dc1355d2665c2a315021194c425172fb47ad2d4368a3a9acf55d"
    "sdk/turning/r23d19_physical_evaluator.py" =
        "sha256:74d7af75386aa42738e08c151b2c03117b6468e1f0c3de063f81b654c008ee3a"
    "sdk/turning/r23d19_physical_trace.py" =
        "sha256:b07d48643891020b2ed03af9abbd0e428b3fba035c78be5b63d2f73291bfab6a"
    "sdk/run_qsdk_r23d19_supervisor.ps1" =
        "sha256:c56ff64e26470b3f3286a8dc8c9f2714374d0ad504f3e6c0e72fcea91a1e7617"
    "tests/test_sdk_qsdk_r23d19_godot_jolt_physical_worker.gd" =
        "sha256:408ee7879d6ae07186a4ebf592a801d2a80266abd59c801e061bb880b0e4639b"
    "scripts/lab/gait/physical_wave_gait_quadruped.gd" =
        "sha256:d6ce61398928fd6bed11f007207b62d465460539b52f5cebbdf64f269aa6158d"
    "sdk/core/src/controller.rs" =
        "sha256:f0d716225d4a318951942254339ddfe659f80b48a2faef9eec126d6768765ea2"
    "sdk/core/src/runtime.rs" =
        "sha256:d296706afbd800f638351708b8caaab722d235c102f467bf6bc51daa4b219b68"
}
foreach ($binding in $sourceHashes.GetEnumerator()) {
    Assert-R23D19Closure (
        (Get-R23D19GitBlobSha256 ([string]$binding.Key)) -ceq
            [string]$binding.Value
    ) "frozen Git blob changed: $($binding.Key)"
}

$failurePath = [string]$closure.prelaunch_incident.failure_path
Assert-R23D19RetainedFile `
    $failurePath ([string]$closure.prelaunch_incident.failure_raw_sha256) `
    "prelaunch qualification refusal"
$prelaunchFailure = Get-Content -LiteralPath $failurePath -Raw |
    ConvertFrom-Json -AsHashtable -Depth 100
Assert-R23D19Closure (
    [string]$closure.prelaunch_incident.failed_gate_id -ceq
        "CAK1-EVIDENCE-PROVENANCE" -and
    [string]$prelaunchFailure.source_commit -ceq
        "0cb07bd11c1ae192912cdee8484d9fe52d9304b5" -and
    -not [bool]$prelaunchFailure.physical_launch_prerequisite_satisfied -and
    -not [bool]$prelaunchFailure.physical_acceptance_authority -and
    [int]$closure.prelaunch_incident.world_build_count -eq 0 -and
    -not [bool]$closure.prelaunch_incident.physical_identity_consumed
) "prelaunch refusal boundary changed"

$attestationPath = [string]$closure.campaign_local_qualification.scoped_attestation_path
$adoptionPath = [string]$closure.campaign_local_qualification.adoption_path
Assert-R23D19RetainedFile `
    $attestationPath `
    ([string]$closure.campaign_local_qualification.scoped_attestation_raw_sha256) `
    "scoped attestation"
Assert-R23D19RetainedFile `
    $adoptionPath `
    ([string]$closure.campaign_local_qualification.adoption_raw_sha256) `
    "attestation adoption"
$attestation = Get-Content -LiteralPath $attestationPath -Raw |
    ConvertFrom-Json -AsHashtable -Depth 100
$adoption = Get-Content -LiteralPath $adoptionPath -Raw |
    ConvertFrom-Json -AsHashtable -Depth 100
Assert-R23D19Closure (
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
    Assert-R23D19RetainedFile `
        (Join-Path $EvidenceRoot ([string]$entry.Key)) `
        ([string]$entry.Value) ([string]$entry.Key)
}

$files = @(Get-ChildItem -LiteralPath $EvidenceRoot -Recurse -File | Sort-Object FullName)
$projectionLines = @()
$totalBytes = 0L
foreach ($file in $files) {
    $relative = [IO.Path]::GetRelativePath($EvidenceRoot, $file.FullName).Replace("\", "/")
    $raw = Get-R23D19ClosureSha256 $file.FullName
    $totalBytes += [long]$file.Length
    $projectionLines += "$relative`t$($file.Length)`t$($raw.Substring(7))"
    Assert-R23D19Closure (Test-R23D19Cas $raw ([long]$file.Length)) (
        "attempt file is not retained in CAS: $relative"
    )
}
$projection = ($projectionLines -join "`n") + "`n"
$treeSha = "sha256:" + [Convert]::ToHexString(
    [Security.Cryptography.SHA256]::HashData(
        [Text.Encoding]::UTF8.GetBytes($projection)
    )
).ToLowerInvariant()
Assert-R23D19Closure (
    $files.Count -eq 20 -and
    $totalBytes -eq 377421 -and
    $treeSha -ceq [string]$attempt.evidence_tree_raw_sha256 -and
    [bool]$attempt.all_attempt_files_content_addressed -and
    [int]$attempt.newly_content_addressed_intermediate_file_count -eq 1
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
Assert-R23D19Closure (
    [string]$report.source.commit -ceq $sourceCommit -and
    [string]$report.attempt_id -ceq $attemptId -and
    [string]$report.result_classification -ceq
        "invalid_or_incomplete_complete_matrix" -and
    -not [bool]$report.finite_godot_mechanism_candidate -and
    [string]$evaluation.classification -ceq
        "invalid_or_incomplete_complete_matrix" -and
    -not [bool]$evaluation.matrix_valid -and
    [int]$evaluation.world_attempt_count -eq 0 -and
    [int]$evaluation.world_build_count -eq 0 -and
    [string]$completion.status -ceq
        "invalid_or_incomplete_complete_matrix_first_attempt" -and
    [string]$completion.attempt_id -ceq $attemptId -and
    [int]$completion.matrix_terminal_entry_count -eq 3 -and
    [bool]$completion.one_shot_identity_consumed -and
    -not [bool]$completion.same_identity_rerun_allowed -and
    [string]$authorization.attempt_id -ceq $attemptId -and
    -not [bool]$authorization.replacement_or_selective_rerun_permitted
) "report, evaluator, completion, or one-shot boundary changed"

$expectedTraceFailures = @(
    "R23D11_GJT_TRACE_TASK_VELOCITY_INVALID",
    "R23D11_GJT_TRACE_MODE_INVALID"
)
$actualWorldAttempts = 0
$actualWorldBuilds = 0
foreach ($cell in @($closure.cells)) {
    $cellId = [string]$cell.cell_id
    $cellRoot = Join-Path $EvidenceRoot "matrix\$cellId"
    $reportCell = @($report.ordered_matrix_cells | Where-Object {
        [string]$_.cell_id -ceq $cellId
    })
    Assert-R23D19Closure (
        $reportCell.Count -eq 1 -and
        [int]$reportCell[0].process.exit_code -eq 1 -and
        -not [bool]$reportCell[0].process.timed_out -and
        [string]$reportCell[0].marker_kind -ceq "supervisor_process_failure" -and
        [string]$reportCell[0].stdout_cas.sha256 -ceq
            [string]$cell.stdout_cas_sha256 -and
        [string]$reportCell[0].godot_log_cas.sha256 -ceq
            [string]$cell.godot_log_cas_sha256 -and
        [string]$reportCell[0].terminal_cas.sha256 -ceq
            [string]$cell.supervisor_terminal_cas_sha256
    ) "supervisor retention changed for $cellId"
    $terminalPath = Join-Path $cellRoot "terminal-entry.json"
    Assert-R23D19RetainedFile `
        $terminalPath ([string]$cell.supervisor_terminal_cas_sha256) `
        "$cellId supervisor terminal"
    $supervisorTerminal = Get-Content -LiteralPath $terminalPath -Raw |
        ConvertFrom-Json -AsHashtable -Depth 100
    Assert-R23D19Closure (
        [string]$supervisorTerminal.schema_version -ceq
            "sporespore_qsdk_r23d19_supervisor_process_failure_v1" -and
        -not [bool]$supervisorTerminal.world_attempt_count_known -and
        -not [bool]$supervisorTerminal.world_build_count_known
    ) "generic supervisor projection changed for $cellId"
    $stdoutPath = Join-Path $cellRoot "stdout.txt"
    Assert-R23D19RetainedFile `
        $stdoutPath ([string]$cell.stdout_cas_sha256) "$cellId stdout"
    $markers = @((Get-Content -LiteralPath $stdoutPath) | Where-Object {
        $_.StartsWith($workerMarkerPrefix, [StringComparison]::Ordinal)
    })
    Assert-R23D19Closure ($markers.Count -eq 1) (
        "expected exactly one worker terminal marker for $cellId"
    )
    $worker = $markers[0].Substring($workerMarkerPrefix.Length) |
        ConvertFrom-Json -AsHashtable -Depth 100
    Assert-R23D19Closure (
        [string]$worker.schema_version -ceq
            "sporespore_qsdk_r23d19_worker_failure_v1" -and
        [string]$worker.campaign_id -ceq $campaignId -and
        [string]$worker.gate_id -ceq $gateId -and
        [string]$worker.source_commit -ceq $sourceCommit -and
        [string]$worker.cell_id -ceq $cellId -and
        [string]$worker.arm_id -ceq [string]$cell.arm_id -and
        [double]$worker.turn_heading_offset_rad -eq
            [double]$cell.turn_heading_offset_rad -and
        [string]$worker.failure_code -ceq "QSDK_R23D19_GJT_TRACE_INCOMPLETE" -and
        [string]$worker.failure_stage -ceq "settlement_complete" -and
        [int]$worker.world_attempt_count -eq 1 -and
        [int]$worker.world_build_count -eq 1 -and
        [int]$worker.trace_artifact.observed_trace_row_count -eq 0 -and
        (@($worker.trace_artifact.trace_failure_codes) -join "|") -ceq
            ($expectedTraceFailures -join "|")
    ) "retained worker failure changed for $cellId"
    $actualWorldAttempts += [int]$worker.world_attempt_count
    $actualWorldBuilds += [int]$worker.world_build_count
}

Assert-R23D19Closure (
    $actualWorldAttempts -eq 3 -and
    $actualWorldBuilds -eq 3 -and
    [int]$attempt.actual_world_attempt_count_from_worker_terminals -eq 3 -and
    [int]$attempt.actual_world_build_count_from_worker_terminals -eq 3 -and
    [int]$attempt.evaluator_projected_world_attempt_count -eq 0 -and
    [int]$attempt.evaluator_projected_world_build_count -eq 0 -and
    [int]$attempt.trace_count -eq 0 -and
    [int]$attempt.trace_row_count_total -eq 0
) "actual-world versus evaluator-projection distinction changed"

$claims = $closure.claims
Assert-R23D19Closure (
    -not [bool]$closure.immutable_completion_record.finite_matrix_result_valid -and
    -not [bool]$closure.immutable_completion_record.scientific_positive -and
    -not [bool]$closure.immutable_completion_record.scientific_negative -and
    -not [bool]$closure.immutable_completion_record.turning_outcome_available -and
    [bool]$closure.mechanism_and_interpretation.visible_motion_is_not_an_accepted_result -and
    [bool]$closure.mechanism_and_interpretation.same_identity_reconstruction_or_rerun_forbidden -and
    -not [bool]$claims.r23d19_scientific_result -and
    -not [bool]$claims.godot_heading_aligned_path_mechanism_confirmed -and
    -not [bool]$claims.command_conditioned_turning -and
    -not [bool]$claims.bilateral_signed_turning -and
    -not [bool]$claims.portable_basic_turning -and
    -not [bool]$claims.cross_engine_equivalence -and
    -not [bool]$claims.q_sdk_r23_satisfied -and
    -not [bool]$claims.prone_to_standing -and
    -not [bool]$claims.release_authorized -and
    -not [bool]$claims.physical_acceptance_authority
) "invalid-result claim boundary changed"

Write-Host (
    "QSDK_R23D19_CLOSURE_PASS classification=invalid_complete_matrix " +
    "cells=3 worker_failures=3 actual_worlds=3 evaluator_worlds=0 " +
    "traces=0 rows=0 files=20 bytes=377421 rerun=False " +
    "scientific_result=False turning=False equivalence=False release=False"
)
