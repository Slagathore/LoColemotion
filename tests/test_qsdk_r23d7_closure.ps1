#requires -Version 7.0

[CmdletBinding()]
param(
    [string]$EvidenceRoot = (
        "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence\" +
        "qsdk-r23d7-20260809T015843Z"
    )
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$sdkRoot = Join-Path $repoRoot "sdk"
$closurePath = Join-Path $sdkRoot "turning\r23d7_physical_closure_v1.json"
$supervisorPath = Join-Path $sdkRoot "run_qsdk_r23d7_supervisor.ps1"
$conformancePath = Join-Path $sdkRoot "run_conformance.ps1"
$artifactStorePath = Join-Path $sdkRoot "content_addressed_artifact_store.ps1"
$campaignId = "QSDK-R23D7-NEUTRAL-STANCE-ACQUISITION-BILATERAL-TURN-DEVELOPMENT"
$gateId = "QSDK-R23D7"
$sourceCommit = "a02eeecbff77f1d62f262b8bdfa9901050e712d5"
$sourceTree = "853e7d9698caff88255dd69998a44a2d083ce5a5"

. $artifactStorePath

function Assert-R23D7Closure {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function Get-R23D7ClosureRawSha256 {
    param([Parameter(Mandatory)][string]$Path)
    return "sha256:" + (
        Get-FileHash -LiteralPath $Path -Algorithm SHA256
    ).Hash.ToLowerInvariant()
}

function Get-R23D7ClosureBytesSha256 {
    param([Parameter(Mandatory)][byte[]]$Bytes)
    return "sha256:" + [Convert]::ToHexString(
        [Security.Cryptography.SHA256]::HashData($Bytes)
    ).ToLowerInvariant()
}

function Get-R23D7ClosureEvidenceTree {
    param([Parameter(Mandatory)][string]$Root)
    $files = @(Get-ChildItem -LiteralPath $Root -File -Recurse | Sort-Object {
        $_.FullName.Substring($Root.Length + 1).Replace("\", "/")
    })
    $lines = @($files | ForEach-Object {
        $relative = $_.FullName.Substring($Root.Length + 1).Replace("\", "/")
        "{0}`t{1}`t{2}" -f `
            $relative, $_.Length, (
                Get-R23D7ClosureRawSha256 $_.FullName
            ).Substring(7)
    })
    $projection = [Text.Encoding]::UTF8.GetBytes(($lines -join "`n") + "`n")
    return [ordered]@{
        files = $files
        file_count = $files.Count
        total_byte_length = [int64](($files | Measure-Object Length -Sum).Sum)
        raw_sha256 = Get-R23D7ClosureBytesSha256 $projection
    }
}

function Get-R23D7ClosureGitBlob {
    param(
        [Parameter(Mandatory)][string]$Commit,
        [Parameter(Mandatory)][string]$Path
    )
    $spec = "$Commit`:$Path"
    $oid = (& git -C $repoRoot rev-parse $spec 2>$null).Trim()
    Assert-R23D7Closure (
        $LASTEXITCODE -eq 0 -and $oid -match '^[0-9a-f]{40}$'
    ) "QSDK-R23D7 historical Git blob is unavailable: $spec"

    $start = [Diagnostics.ProcessStartInfo]::new()
    $start.FileName = "git"
    $start.WorkingDirectory = $repoRoot
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    [void]$start.ArgumentList.Add("cat-file")
    [void]$start.ArgumentList.Add("blob")
    [void]$start.ArgumentList.Add($spec)
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $start
    Assert-R23D7Closure $process.Start() "QSDK-R23D7 could not start git cat-file"
    $memory = [IO.MemoryStream]::new()
    try {
        $process.StandardOutput.BaseStream.CopyTo($memory)
        $stderr = $process.StandardError.ReadToEnd()
        $process.WaitForExit()
        Assert-R23D7Closure ($process.ExitCode -eq 0) (
            "QSDK-R23D7 git cat-file failed for $spec`: $stderr"
        )
        $bytes = $memory.ToArray()
        return [ordered]@{
            oid = $oid
            byte_length = $bytes.Length
            raw_sha256 = Get-R23D7ClosureBytesSha256 $bytes
            text = [Text.Encoding]::UTF8.GetString($bytes)
        }
    } finally {
        $memory.Dispose()
        $process.Dispose()
    }
}

Assert-R23D7Closure (
    (git -C $repoRoot rev-parse --show-toplevel).Replace("/", "\") -ceq
        $repoRoot -and
    (git -C $repoRoot remote get-url origin) -ceq
        "https://github.com/Slagathore/sporespore.git"
) "QSDK-R23D7 closure repository identity mismatch"
Assert-R23D7Closure (Test-Path -LiteralPath $closurePath -PathType Leaf) (
    "QSDK-R23D7 closure is missing"
)
Assert-R23D7Closure (Test-Path -LiteralPath $EvidenceRoot -PathType Container) (
    "QSDK-R23D7 retained attempt root is missing"
)

$closure = Get-Content -Raw -LiteralPath $closurePath |
    ConvertFrom-Json -AsHashtable -Depth 100
$freezePath = Join-Path $EvidenceRoot "physical-freeze.json"
$authorizationPath = Join-Path $EvidenceRoot "stage-a-authorization.json"
$stageAEvaluationPath = Join-Path $EvidenceRoot "stage-a-evaluator\evaluation.json"
$completeEvaluationPath = Join-Path $EvidenceRoot "complete-evaluator\evaluation.json"
$reportPath = Join-Path $EvidenceRoot "report.json"
$completionPath = Join-Path $EvidenceRoot "completion.json"

$keyDigests = [ordered]@{
    "physical-freeze.json" = $closure.attempt.physical_freeze_raw_sha256
    "stage-a-authorization.json" = $closure.attempt.stage_a_authorization_raw_sha256
    "stage-a-evaluator/evaluation.json" = $closure.attempt.stage_a_evaluation_raw_sha256
    "complete-evaluator/evaluation.json" = $closure.attempt.complete_evaluation_raw_sha256
    "report.json" = $closure.attempt.report_raw_sha256
    "completion.json" = $closure.attempt.completion_raw_sha256
}
foreach ($item in $keyDigests.GetEnumerator()) {
    $path = Join-Path $EvidenceRoot $item.Key
    Assert-R23D7Closure (Test-Path -LiteralPath $path -PathType Leaf) (
        "QSDK-R23D7 retained file is missing: $($item.Key)"
    )
    Assert-R23D7Closure (
        (Get-R23D7ClosureRawSha256 $path) -ceq [string]$item.Value
    ) "QSDK-R23D7 retained file changed: $($item.Key)"
}

$tree = Get-R23D7ClosureEvidenceTree $EvidenceRoot
Assert-R23D7Closure (
    [int]$tree.file_count -eq [int]$closure.attempt.evidence_file_count -and
    [int64]$tree.total_byte_length -eq
        [int64]$closure.attempt.evidence_total_byte_length -and
    [string]$tree.raw_sha256 -ceq
        [string]$closure.attempt.evidence_tree_raw_sha256
) "QSDK-R23D7 retained evidence tree changed"

$artifactRoot = Join-Path (Get-SporeSporeArtifactEvidenceRoot -RepoRoot $repoRoot) (
    "artifacts\sha256"
)
foreach ($file in @($tree.files)) {
    $digest = (Get-R23D7ClosureRawSha256 $file.FullName).Substring(7)
    Assert-R23D7Closure (
        Test-SporeSporeStoredArtifact `
            -Directory (Join-Path $artifactRoot $digest) `
            -ExpectedSha256 $digest `
            -ExpectedByteLength ([long]$file.Length)
    ) (
        "QSDK-R23D7 retained evidence CAS object changed: " +
        $file.FullName.Substring($EvidenceRoot.Length + 1)
    )
}

$freeze = Get-Content -Raw -LiteralPath $freezePath |
    ConvertFrom-Json -AsHashtable -Depth 100
$authorization = Get-Content -Raw -LiteralPath $authorizationPath |
    ConvertFrom-Json -AsHashtable -Depth 100
$stageAEvaluation = Get-Content -Raw -LiteralPath $stageAEvaluationPath |
    ConvertFrom-Json -AsHashtable -Depth 100
$completeEvaluation = Get-Content -Raw -LiteralPath $completeEvaluationPath |
    ConvertFrom-Json -AsHashtable -Depth 100
$report = Get-Content -Raw -LiteralPath $reportPath |
    ConvertFrom-Json -AsHashtable -Depth 100
$completion = Get-Content -Raw -LiteralPath $completionPath |
    ConvertFrom-Json -AsHashtable -Depth 100

Assert-R23D7Closure (
    [string]$closure.schema_version -ceq
        "sporespore_qsdk_r23d7_physical_development_closure_v1" -and
    [string]$closure.status -ceq
        "closed_consumed_implementation_invalid_zero_world" -and
    [string]$closure.campaign_id -ceq $campaignId -and
    [string]$closure.gate_id -ceq $gateId -and
    [string]$closure.source_identity.commit -ceq $sourceCommit -and
    [string]$closure.source_identity.tree_git_oid -ceq $sourceTree -and
    [int]$closure.source_identity.declared_source_binding_count -eq 75 -and
    [int]$closure.attempt.declared_stage_a_cell_count -eq 2 -and
    [int]$closure.attempt.launched_stage_a_worker_process_count -eq 2 -and
    [int]$closure.attempt.terminalized_stage_a_cell_count -eq 2 -and
    [int]$closure.attempt.valid_completed_stage_a_cell_count -eq 0 -and
    [int]$closure.attempt.unopened_stage_b_cell_count -eq 9 -and
    [int]$closure.attempt.world_attempt_count -eq 0 -and
    [int]$closure.attempt.world_build_count -eq 0 -and
    [bool]$closure.attempt.one_shot_identity_consumed -and
    -not [bool]$closure.attempt.same_identity_rerun_allowed
) "QSDK-R23D7 closure identity changed"

Assert-R23D7Closure (
    [string]$freeze.schema_version -ceq
        "sporespore_qsdk_r23d7_physical_freeze_v1" -and
    [string]$freeze.status -ceq "frozen_supervisor_only_physical_authorized" -and
    [string]$freeze.campaign_id -ceq $campaignId -and
    [string]$freeze.gate_id -ceq $gateId -and
    [string]$freeze.source_commit -ceq $sourceCommit -and
    [string]$freeze.source_tree_git_oid -ceq $sourceTree -and
    @($freeze.source_bindings).Count -eq 75 -and
    @($freeze.runtime_artifacts).Count -eq 3 -and
    @($freeze.external_runtime_bindings).Count -eq 4 -and
    [bool]$freeze.physical_execution_authorized
) "QSDK-R23D7 physical freeze changed"
Assert-R23D7Closure (
    [string]$authorization.schema_version -ceq
        "sporespore_qsdk_r23d7_attempt_v1" -and
    [string]$authorization.attempt_id -ceq [string]$closure.attempt.attempt_id -and
    [string]$authorization.source_commit -ceq $sourceCommit -and
    [string]$authorization.freeze_raw_sha256 -ceq
        [string]$closure.attempt.physical_freeze_raw_sha256 -and
    [bool]$authorization.physical_execution_authorized -and
    [bool]$authorization.single_use_supervisor_authorization -and
    [bool]$authorization.source_worktree_clean -and
    [bool]$authorization.source_matches_live_github_main -and
    [bool]$authorization.operation_lock_held -and
    [bool]$authorization.full_godot_attestation_valid -and
    [bool]$authorization.content_addressed_inputs_retained -and
    [bool]$authorization.one_shot_attempt_unconsumed -and
    @($authorization.ordered_stage_a_cell_ids).Count -eq 2 -and
    @($authorization.ordered_stage_b_cell_ids).Count -eq 0 -and
    [string]$authorization.full_godot_attestation_sha256 -ceq
        [string]$closure.full_godot_attestation.raw_sha256
) "QSDK-R23D7 Stage A authorization changed"

Assert-R23D7Closure (
    [string]$completion.status -ceq "invalid_or_incomplete_first_attempt" -and
    [string]$completion.result_classification -ceq
        "invalid_or_incomplete_complete_campaign" -and
    [string]$completion.selected_terminal_restoration_policy_id -ceq "INVALID" -and
    [int]$completion.stage_a_terminal_entry_count -eq 2 -and
    [int]$completion.stage_b_terminal_entry_count -eq 0 -and
    [bool]$completion.one_shot_identity_consumed -and
    -not [bool]$completion.same_identity_rerun_allowed -and
    -not [bool]$completion.command_conditioned_turning -and
    -not [bool]$completion.q_sdk_r23_satisfied -and
    -not [bool]$completion.cross_engine_equivalence -and
    -not [bool]$completion.release_authorized -and
    -not [bool]$completion.physical_acceptance_authority
) "QSDK-R23D7 immutable completion changed"
Assert-R23D7Closure (
    [string]$stageAEvaluation.classification -ceq "invalid_or_incomplete_stage_a" -and
    [string]$stageAEvaluation.selected_terminal_restoration_policy_id -ceq "INVALID" -and
    -not [bool]$stageAEvaluation.valid -and
    -not [bool]$stageAEvaluation.stage_b_launch_authorized -and
    [int]$stageAEvaluation.world_attempt_count -eq 0 -and
    [int]$stageAEvaluation.world_build_count -eq 0 -and
    [string]$completeEvaluation.classification -ceq
        "invalid_or_incomplete_complete_campaign" -and
    [int]$completeEvaluation.world_attempt_count -eq 0 -and
    [int]$completeEvaluation.world_build_count -eq 0 -and
    [string]$report.result_classification -ceq
        "invalid_or_incomplete_complete_campaign" -and
    -not [bool]$report.development_result_valid -and
    -not [bool]$report.stage_b_launched -and
    [string]$report.selected_terminal_restoration_policy_id -ceq "INVALID"
) "QSDK-R23D7 evaluator or report classification changed"

$retainedCellIds = @()
foreach ($worker in @($closure.retained_stage_a_workers)) {
    $cellId = [string]$worker.cell_id
    $retainedCellIds += $cellId
    $cellRoot = Join-Path $EvidenceRoot "stage-a\$cellId"
    $processPath = Join-Path $cellRoot "process.json"
    $stdoutPath = Join-Path $cellRoot "stdout.txt"
    $stderrPath = Join-Path $cellRoot "stderr.txt"
    $terminalPath = Join-Path $cellRoot "terminal-entry.json"
    foreach ($receipt in @(
        @{ path = $processPath; digest = $worker.process_raw_sha256 },
        @{ path = $stdoutPath; digest = $worker.stdout_raw_sha256 },
        @{ path = $stderrPath; digest = $worker.stderr_raw_sha256 },
        @{ path = $terminalPath; digest = $worker.terminal_entry_raw_sha256 }
    )) {
        Assert-R23D7Closure (
            (Get-R23D7ClosureRawSha256 $receipt.path) -ceq [string]$receipt.digest
        ) "QSDK-R23D7 retained worker artifact changed: $($receipt.path)"
    }
    $processReceipt = Get-Content -Raw -LiteralPath $processPath |
        ConvertFrom-Json -AsHashtable -Depth 30
    $stdout = Get-Content -Raw -LiteralPath $stdoutPath
    $stderr = Get-Content -Raw -LiteralPath $stderrPath
    $terminalLines = @($stdout -split "`r?`n" | Where-Object {
        $_.StartsWith("QSDK_R23D7_TERMINAL ", [StringComparison]::Ordinal)
    })
    Assert-R23D7Closure ($terminalLines.Count -eq 1) (
        "QSDK-R23D7 retained stdout marker count changed: $cellId"
    )
    $terminal = Get-Content -Raw -LiteralPath $terminalPath |
        ConvertFrom-Json -AsHashtable -Depth 100
    $stdoutTerminal = $terminalLines[0].Substring("QSDK_R23D7_TERMINAL ".Length) |
        ConvertFrom-Json -AsHashtable -Depth 100
    Assert-R23D7Closure (
        [string]$processReceipt.schema_version -ceq
            "sporespore_qsdk_r23d7_worker_process_v1" -and
        [bool]$processReceipt.process_launch_succeeded -and
        [int]$processReceipt.exit_code -eq 1 -and
        -not [bool]$processReceipt.timed_out -and
        [double]$processReceipt.duration_seconds -eq
            [double]$worker.process_duration_seconds -and
        [string]$terminal.schema_version -ceq
            "sporespore_qsdk_r23d7_worker_failure_v1" -and
        [string]$terminal.failure_code -ceq
            "QSDK_R23D7_MJC_PHYSICAL_AUTHORIZATION_INVALID" -and
        [string]$terminal.failure_stage -ceq "before_world" -and
        [int]$terminal.world_attempt_count -eq 0 -and
        [int]$terminal.world_build_count -eq 0 -and
        $null -eq $terminal.trace_artifact -and
        [string]$stdoutTerminal.cell_id -ceq $cellId -and
        [string]$stdoutTerminal.failure_code -ceq [string]$terminal.failure_code -and
        $stderr.Trim() -ceq (
            "QSDK_R23D7_MUJOCO_FAILURE " +
            "QSDK_R23D7_MJC_PHYSICAL_AUTHORIZATION_INVALID"
        )
    ) "QSDK-R23D7 retained worker semantics changed: $cellId"
}
Assert-R23D7Closure (
    ($retainedCellIds -join "|") -ceq (
        "mujoco__neutral_stance__positive_heading|" +
        "mujoco__neutral_stance__negative_heading"
    )
) "QSDK-R23D7 retained Stage A cell order changed"

Assert-R23D7Closure (
    -not (Test-Path -LiteralPath (Join-Path $EvidenceRoot "stage-b-authorization.json")) -and
    -not (Test-Path -LiteralPath (Join-Path $EvidenceRoot "stage-b")) -and
    (Get-Content -Raw -LiteralPath (
        Join-Path $EvidenceRoot "stage-b-terminal-paths.json"
    )) -ceq "[]`n"
) "QSDK-R23D7 unopened Stage B boundary changed"

$historicalTexts = @{}
foreach ($expected in @($closure.historical_source_blobs)) {
    $actual = Get-R23D7ClosureGitBlob `
        -Commit $sourceCommit `
        -Path ([string]$expected.path)
    Assert-R23D7Closure (
        [string]$actual.oid -ceq [string]$expected.git_blob_oid -and
        [int64]$actual.byte_length -eq [int64]$expected.byte_length -and
        [string]$actual.raw_sha256 -ceq [string]$expected.raw_sha256
    ) "QSDK-R23D7 historical source blob changed: $($expected.path)"
    $historicalTexts[[string]$expected.path] = [string]$actual.text
}

$workerPath = (
    "sdk/adapters/mujoco/sporespore_mujoco_adapter/" +
    "qsdk_r23d7_neutral_stance.py"
)
$contractPath = "sdk/turning/r23d7_implementation_contract_v1.json"
$workerText = [string]$historicalTexts[$workerPath]
$contract = [string]$historicalTexts[$contractPath] |
    ConvertFrom-Json -AsHashtable -Depth 100
$declared = @(
    $contract.dependency_closure.required_dependency_paths_by_worker.mujoco
)
$tupleMatch = [regex]::Match(
    $workerText,
    '(?s)expected_paths = \((?<body>.*?)\r?\n    \)\r?\n    try:'
)
Assert-R23D7Closure $tupleMatch.Success (
    "QSDK-R23D7 frozen MuJoCo dependency tuple is not recoverable"
)
$hardCoded = @([regex]::Matches(
    $tupleMatch.Groups["body"].Value,
    '"(?<path>[^"\r\n]+)"'
) | ForEach-Object { $_.Groups["path"].Value })
$omitted = @($declared | Where-Object { $hardCoded -cnotcontains [string]$_ })
Assert-R23D7Closure (
    $declared.Count -eq 16 -and
    $hardCoded.Count -eq 11 -and
    ($hardCoded -join "|") -cne ($declared -join "|") -and
    [string]$hardCoded[1] -cne [string]$declared[1] -and
    ($omitted -join "|") -ceq (
        @($closure.worker_authorization_diagnosis.omitted_declared_dependency_paths) -join "|"
    ) -and
    $omitted.Count -eq 5 -and
    @($closure.worker_authorization_diagnosis.failed_predicate_ids).Count -eq 1 -and
    [string]$closure.worker_authorization_diagnosis.failed_predicate_ids[0] -ceq
        "source_bindings_exact"
) "QSDK-R23D7 frozen authorization diagnosis changed"

$bindingByPath = @{}
foreach ($binding in @($freeze.source_bindings)) {
    $bindingByPath[[string]$binding.path] = $binding
}
foreach ($pathValue in $declared) {
    $path = [string]$pathValue
    Assert-R23D7Closure ($bindingByPath.ContainsKey($path)) (
        "QSDK-R23D7 declared MuJoCo dependency is absent from freeze: $path"
    )
    $sourceBlob = Get-R23D7ClosureGitBlob -Commit $sourceCommit -Path $path
    Assert-R23D7Closure (
        [string]$sourceBlob.oid -ceq [string]$bindingByPath[$path].git_blob_oid -and
        [string]$sourceBlob.raw_sha256 -ceq
            [string]$bindingByPath[$path].raw_sha256 -and
        [bool]$bindingByPath[$path].raw_checkout_equals_git_blob
    ) "QSDK-R23D7 declared MuJoCo dependency binding changed: $path"
}

$inputSourceReceipts = @($authorization.content_addressed_inputs.source_bindings)
$inputRuntimeReceipts = @($authorization.content_addressed_inputs.runtime_artifacts)
$inputExternalReceipts = @($authorization.content_addressed_inputs.external_runtime_bindings)
Assert-R23D7Closure (
    $inputSourceReceipts.Count -eq 75 -and
    $inputRuntimeReceipts.Count -eq 3 -and
    $inputExternalReceipts.Count -eq 4
) "QSDK-R23D7 content-addressed input cardinality changed"

$attestationPath = [string]$closure.full_godot_attestation.path
Assert-R23D7Closure (
    (Get-R23D7ClosureRawSha256 $attestationPath) -ceq
        [string]$closure.full_godot_attestation.raw_sha256
) "QSDK-R23D7 full-Godot attestation bytes changed"
$attestation = Get-Content -Raw -LiteralPath $attestationPath |
    ConvertFrom-Json -AsHashtable -Depth 64
Assert-R23D7Closure (
    [string]$attestation.status -ceq "full_godot_conformance_passed" -and
    [string]$attestation.source.commit -ceq $sourceCommit -and
    [string]$attestation.source.tree_git_oid -ceq $sourceTree -and
    [double]$attestation.conformance.duration_seconds -eq
        [double]$closure.full_godot_attestation.duration_seconds -and
    [bool]$attestation.conformance.godot_including -and
    -not [bool]$attestation.claims.physical_acceptance_authority
) "QSDK-R23D7 full-Godot attestation semantics changed"

$supervisorSource = [IO.File]::ReadAllText($supervisorPath)
$workerSources = @(
    $workerPath,
    "sdk/adapters/rapier/src/qsdk_r23d3_phase_balanced.rs",
    "tests/test_sdk_qsdk_r23d7_neutral_stance_godot_jolt_worker.gd"
)
Assert-R23D7Closure (
    $supervisorSource.Contains(
        'Test-Path -LiteralPath $closurePath -PathType Leaf'
    ) -and
    $supervisorSource.Contains("QSDK-R23D7 CLOSED")
) "QSDK-R23D7 supervisor closure interlock is missing"
foreach ($relative in $workerSources) {
    $text = [IO.File]::ReadAllText((Join-Path $repoRoot $relative))
    Assert-R23D7Closure (
        $text.Contains("r23d7_physical_closure_v1.json")
    ) "QSDK-R23D7 worker closure interlock is missing: $relative"
}

$beforeRoots = @(
    Get-ChildItem -LiteralPath (
        "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence"
    ) -Directory | Where-Object Name -like "qsdk-r23d7-*"
).Count
$refusal = @(& (Get-Process -Id $PID).Path `
    -NoProfile -File $supervisorPath `
    -RunPhysical `
    -FullConformanceAttestation "R23D7_CLOSED_CANARY" 2>&1)
$refusalExit = $LASTEXITCODE
$afterRoots = @(
    Get-ChildItem -LiteralPath (
        "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence"
    ) -Directory | Where-Object Name -like "qsdk-r23d7-*"
).Count
Assert-R23D7Closure (
    $refusalExit -ne 0 -and
    ($refusal -join "`n").Contains("QSDK-R23D7 CLOSED") -and
    $afterRoots -eq $beforeRoots
) "QSDK-R23D7 same-identity supervisor did not fail closed"
$global:LASTEXITCODE = 0

$conformanceSource = [IO.File]::ReadAllText($conformancePath)
Assert-R23D7Closure (
    $conformanceSource.Contains("tests\test_qsdk_r23d7_closure.ps1") -and
    -not $conformanceSource.Contains(
        '& (Join-Path $repoRoot "tests\test_qsdk_r23d7_declaration.ps1")'
    ) -and
    -not $conformanceSource.Contains(
        '& (Join-Path $sdkRoot "run_qsdk_r23d7_mujoco_worker_preflight.ps1")'
    ) -and
    -not $conformanceSource.Contains(
        '& (Join-Path $sdkRoot "run_qsdk_r23d7_rapier_worker_preflight.ps1")'
    ) -and
    -not $conformanceSource.Contains(
        '& (Join-Path $sdkRoot "run_qsdk_r23d7_godot_jolt_worker_preflight.ps1")'
    )
) "QSDK-R23D7 canonical conformance routing changed"

Assert-R23D7Closure (
    -not [bool]$closure.claims.scientific_positive -and
    -not [bool]$closure.claims.scientific_negative -and
    -not [bool]$closure.claims.command_conditioned_turning -and
    -not [bool]$closure.claims.cross_engine_equivalence -and
    -not [bool]$closure.claims.q_sdk_r23_satisfied -and
    -not [bool]$closure.claims.prone_to_standing -and
    -not [bool]$closure.claims.release_authorized -and
    -not [bool]$closure.claims.physical_acceptance_authority
) "QSDK-R23D7 closed claims changed"

$receipt = [ordered]@{
    schema_version = "sporespore_qsdk_r23d7_closure_audit_v1"
    campaign_id = $campaignId
    gate_id = $gateId
    status = [string]$closure.status
    retained_evidence_file_count = [int]$tree.file_count
    retained_evidence_total_byte_length = [int64]$tree.total_byte_length
    retained_evidence_cas_count = [int]$tree.file_count
    launched_worker_process_count = 2
    terminalized_stage_a_cell_count = 2
    valid_completed_stage_a_cell_count = 0
    omitted_worker_dependency_count = 5
    unopened_stage_b_cell_count = 9
    world_attempt_count = 0
    world_build_count = 0
    one_shot_identity_consumed = $true
    same_identity_rerun_allowed = $false
    scientific_positive = $false
    scientific_negative = $false
    command_conditioned_turning = $false
    cross_engine_equivalence = $false
    q_sdk_r23_satisfied = $false
    release_authorized = $false
    physical_acceptance_authority = $false
}
Write-Host "QSDK_R23D7_CLOSURE_AUDIT $($receipt | ConvertTo-Json -Compress)"
Write-Host (
    "QSDK_R23D7_CLOSURE_PASS status=$($closure.status) " +
    "files=$($tree.file_count) cas=$($tree.file_count) workers=2 " +
    "terminalized=2 valid=0 omitted_dependencies=5 stage_b_unopened=9 " +
    "worlds=0 consumed=True rerun=False turning=False equivalence=False " +
    "physical_authority=False"
)
