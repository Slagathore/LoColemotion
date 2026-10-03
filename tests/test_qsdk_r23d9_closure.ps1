#requires -Version 7.0

[CmdletBinding()]
param(
    [string]$EvidenceRoot = (
        "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence\" +
        "qsdk-r23d9-20260809T101930Z"
    ),
    [string]$SupervisorLog = (
        "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence\" +
        "qsdk-r23d9-supervisor-20260809T101930Z.log"
    )
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$sdkRoot = Join-Path $repoRoot "sdk"
$closurePath = Join-Path $sdkRoot "turning\r23d9_physical_closure_v1.json"
$supervisorPath = Join-Path $sdkRoot "run_qsdk_r23d9_supervisor.ps1"
$evaluatorPath = Join-Path $sdkRoot "turning\r23d9_physical_evaluator.py"
$implementationPath = Join-Path $sdkRoot (
    "turning\r23d9_physical_implementation_contract_v1.json"
)
$artifactStorePath = Join-Path $sdkRoot "content_addressed_artifact_store.ps1"
$campaignId = (
    "QSDK-R23D9-SUPPORT-CONFIRMED-ACTIVE-TO-PASSIVE-HANDOFF-" +
    "BILATERAL-TURN-DEVELOPMENT"
)
$gateId = "QSDK-R23D9"
$sourceCommit = "74f45053c69cd264e60e0927d9eaf4bcd8a43038"
$sourceTree = "5f4b236ad4f5f295b5aa72b9d7a2bb329530189c"
$emptySha256 = (
    "sha256:e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
)

. $artifactStorePath

function Assert-R23D9Closure {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function Get-R23D9ClosureRawSha256 {
    param([Parameter(Mandatory)][string]$Path)
    return "sha256:" + (
        Get-FileHash -LiteralPath $Path -Algorithm SHA256
    ).Hash.ToLowerInvariant()
}

function Get-R23D9ClosureBytesSha256 {
    param([Parameter(Mandatory)][byte[]]$Bytes)
    return "sha256:" + [Convert]::ToHexString(
        [Security.Cryptography.SHA256]::HashData($Bytes)
    ).ToLowerInvariant()
}

function Get-R23D9ClosureEvidenceTree {
    param([Parameter(Mandatory)][string]$Root)
    $files = @(Get-ChildItem -LiteralPath $Root -File -Recurse | Sort-Object {
        $_.FullName.Substring($Root.Length + 1).Replace("\", "/")
    })
    $lines = @($files | ForEach-Object {
        $relative = $_.FullName.Substring($Root.Length + 1).Replace("\", "/")
        "{0}`t{1}`t{2}" -f `
            $relative, $_.Length, (
                Get-R23D9ClosureRawSha256 $_.FullName
            ).Substring(7)
    })
    $projection = [Text.Encoding]::UTF8.GetBytes(($lines -join "`n") + "`n")
    return [ordered]@{
        files = $files
        file_count = $files.Count
        total_byte_length = [int64](($files | Measure-Object Length -Sum).Sum)
        raw_sha256 = Get-R23D9ClosureBytesSha256 $projection
    }
}

function Get-R23D9ClosureGitBlob {
    param(
        [Parameter(Mandatory)][string]$Commit,
        [Parameter(Mandatory)][string]$Path
    )
    $spec = "$Commit`:$Path"
    $oid = (& git -C $repoRoot rev-parse $spec 2>$null).Trim()
    Assert-R23D9Closure (
        $LASTEXITCODE -eq 0 -and $oid -match '^[0-9a-f]{40}$'
    ) "QSDK-R23D9 historical Git blob is unavailable: $spec"

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
    Assert-R23D9Closure $process.Start() (
        "QSDK-R23D9 could not start git cat-file"
    )
    $memory = [IO.MemoryStream]::new()
    try {
        $process.StandardOutput.BaseStream.CopyTo($memory)
        $stderr = $process.StandardError.ReadToEnd()
        $process.WaitForExit()
        Assert-R23D9Closure ($process.ExitCode -eq 0) (
            "QSDK-R23D9 git cat-file failed for $spec`: $stderr"
        )
        $bytes = $memory.ToArray()
        return [ordered]@{
            oid = $oid
            byte_length = $bytes.Length
            raw_sha256 = Get-R23D9ClosureBytesSha256 $bytes
            text = [Text.Encoding]::UTF8.GetString($bytes)
        }
    } finally {
        $memory.Dispose()
        $process.Dispose()
    }
}

function Get-R23D9ClosureMarker {
    param(
        [Parameter(Mandatory)][string]$Text,
        [Parameter(Mandatory)][string]$Prefix
    )
    $lines = @(($Text -split "`r?`n") | Where-Object {
        $_.StartsWith($Prefix, [StringComparison]::Ordinal)
    })
    Assert-R23D9Closure ($lines.Count -eq 1) (
        "QSDK-R23D9 expected one '$Prefix' marker, observed $($lines.Count)"
    )
    return $lines[0].Substring($Prefix.Length) |
        ConvertFrom-Json -AsHashtable -Depth 100
}

function Test-R23D9ClosureCasArtifact {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$ExpectedSha256,
        [Parameter(Mandatory)][long]$ExpectedByteLength
    )
    $artifactRoot = Join-Path (
        Get-SporeSporeArtifactEvidenceRoot -RepoRoot $repoRoot
    ) "artifacts\sha256"
    $digest = $ExpectedSha256.Substring(7)
    return Test-SporeSporeStoredArtifact `
        -Directory (Join-Path $artifactRoot $digest) `
        -ExpectedSha256 $digest `
        -ExpectedByteLength $ExpectedByteLength
}

Assert-R23D9Closure (
    (git -C $repoRoot rev-parse --show-toplevel).Replace("/", "\") -ceq
        $repoRoot -and
    (git -C $repoRoot remote get-url origin) -ceq
        "https://github.com/Slagathore/sporespore.git"
) "QSDK-R23D9 closure repository identity mismatch"
Assert-R23D9Closure (Test-Path -LiteralPath $closurePath -PathType Leaf) (
    "QSDK-R23D9 closure is missing"
)
Assert-R23D9Closure (Test-Path -LiteralPath $EvidenceRoot -PathType Container) (
    "QSDK-R23D9 retained attempt root is missing"
)
Assert-R23D9Closure (Test-Path -LiteralPath $SupervisorLog -PathType Leaf) (
    "QSDK-R23D9 retained supervisor log is missing"
)

$closure = Get-Content -Raw -LiteralPath $closurePath |
    ConvertFrom-Json -AsHashtable -Depth 100
$freezePath = Join-Path $EvidenceRoot "physical-freeze.json"
$authorizationPath = Join-Path $EvidenceRoot "stage-a-authorization.json"
$manifestPath = Join-Path $EvidenceRoot "stage-a-terminal-paths.json"
$completionPath = Join-Path $EvidenceRoot "completion.json"
$evaluatorRoot = Join-Path $EvidenceRoot "stage-a-evaluator"
$evaluatorProcessPath = Join-Path $evaluatorRoot "process.json"
$evaluatorStdoutPath = Join-Path $evaluatorRoot "stdout.txt"
$evaluatorStderrPath = Join-Path $evaluatorRoot "stderr.txt"

$keyDigests = [ordered]@{
    "physical-freeze.json" = $closure.attempt.physical_freeze_raw_sha256
    "stage-a-authorization.json" = $closure.attempt.stage_a_authorization_raw_sha256
    "stage-a-terminal-paths.json" = $closure.attempt.stage_a_manifest_raw_sha256
    "completion.json" = $closure.attempt.completion_raw_sha256
}
foreach ($item in $keyDigests.GetEnumerator()) {
    $path = Join-Path $EvidenceRoot $item.Key
    Assert-R23D9Closure (Test-Path -LiteralPath $path -PathType Leaf) (
        "QSDK-R23D9 retained file is missing: $($item.Key)"
    )
    Assert-R23D9Closure (
        (Get-R23D9ClosureRawSha256 $path) -ceq [string]$item.Value
    ) "QSDK-R23D9 retained file changed: $($item.Key)"
}

$tree = Get-R23D9ClosureEvidenceTree $EvidenceRoot
Assert-R23D9Closure (
    [int]$tree.file_count -eq [int]$closure.attempt.evidence_file_count -and
    [int64]$tree.total_byte_length -eq
        [int64]$closure.attempt.evidence_total_byte_length -and
    [string]$tree.raw_sha256 -ceq
        [string]$closure.attempt.evidence_tree_raw_sha256
) "QSDK-R23D9 retained evidence tree changed"
foreach ($file in @($tree.files)) {
    $sha256 = Get-R23D9ClosureRawSha256 $file.FullName
    Assert-R23D9Closure (
        Test-R23D9ClosureCasArtifact `
            -Path $file.FullName `
            -ExpectedSha256 $sha256 `
            -ExpectedByteLength ([long]$file.Length)
    ) (
        "QSDK-R23D9 retained evidence CAS object changed: " +
        $file.FullName.Substring($EvidenceRoot.Length + 1)
    )
}

Assert-R23D9Closure (
    (Get-R23D9ClosureRawSha256 $SupervisorLog) -ceq
        [string]$closure.attempt.supervisor_log_raw_sha256 -and
    (Get-Item -LiteralPath $SupervisorLog).Length -eq
        [long]$closure.attempt.supervisor_log_byte_length -and
    (Test-R23D9ClosureCasArtifact `
        -Path $SupervisorLog `
        -ExpectedSha256 ([string]$closure.attempt.supervisor_log_raw_sha256) `
        -ExpectedByteLength ([long]$closure.attempt.supervisor_log_byte_length))
) "QSDK-R23D9 supervisor log changed or is not content-addressed"

$attestationPath = [string]$closure.full_godot_attestation.path
$attestationLogPath = [string]$closure.full_godot_attestation.conformance_log_path
Assert-R23D9Closure (
    (Get-R23D9ClosureRawSha256 $attestationPath) -ceq
        [string]$closure.full_godot_attestation.raw_sha256 -and
    (Get-R23D9ClosureRawSha256 $attestationLogPath) -ceq
        [string]$closure.full_godot_attestation.conformance_log_raw_sha256 -and
    (Get-Item -LiteralPath $attestationLogPath).Length -eq
        [long]$closure.full_godot_attestation.conformance_log_byte_length -and
    (Test-R23D9ClosureCasArtifact `
        -Path $attestationLogPath `
        -ExpectedSha256 (
            [string]$closure.full_godot_attestation.conformance_log_raw_sha256
        ) `
        -ExpectedByteLength (
            [long]$closure.full_godot_attestation.conformance_log_byte_length
        ))
) "QSDK-R23D9 source-exact attestation evidence changed"
$attestation = Get-Content -Raw -LiteralPath $attestationPath |
    ConvertFrom-Json -AsHashtable -Depth 100
Assert-R23D9Closure (
    [string]$attestation.status -ceq "full_godot_conformance_passed" -and
    [string]$attestation.source.commit -ceq $sourceCommit -and
    [string]$attestation.source.tree_git_oid -ceq $sourceTree -and
    [bool]$attestation.source.clean_pushed_live -and
    [bool]$attestation.conformance.godot_including -and
    [double]$attestation.conformance.duration_seconds -eq
        [double]$closure.full_godot_attestation.duration_seconds -and
    -not [bool]$attestation.claims.turning_acceptance -and
    -not [bool]$attestation.claims.physical_acceptance_authority
) "QSDK-R23D9 source-exact attestation semantics changed"

$freeze = Get-Content -Raw -LiteralPath $freezePath |
    ConvertFrom-Json -AsHashtable -Depth 100
$authorization = Get-Content -Raw -LiteralPath $authorizationPath |
    ConvertFrom-Json -AsHashtable -Depth 100
$completion = Get-Content -Raw -LiteralPath $completionPath |
    ConvertFrom-Json -AsHashtable -Depth 100
Assert-R23D9Closure (
    [string]$closure.schema_version -ceq
        "sporespore_qsdk_r23d9_physical_development_closure_v1" -and
    [string]$closure.status -ceq (
        "closed_consumed_infrastructure_invalid_after_two_stage_a_worlds_" +
        "evaluator_marker_mismatch"
    ) -and
    [string]$closure.campaign_id -ceq $campaignId -and
    [string]$closure.gate_id -ceq $gateId -and
    [string]$closure.source_identity.commit -ceq $sourceCommit -and
    [string]$closure.source_identity.tree_git_oid -ceq $sourceTree -and
    [int]$closure.source_identity.declared_source_binding_count -eq 92 -and
    [int]$closure.attempt.launched_stage_a_worker_process_count -eq 2 -and
    [int]$closure.attempt.execution_valid_stage_a_cell_count -eq 2 -and
    [int]$closure.attempt.stage_b_worker_process_count -eq 0 -and
    [int]$closure.attempt.world_attempt_count -eq 2 -and
    [int]$closure.attempt.world_build_count -eq 2 -and
    [bool]$closure.attempt.one_shot_identity_consumed -and
    -not [bool]$closure.attempt.same_identity_rerun_allowed
) "QSDK-R23D9 closure identity changed"
Assert-R23D9Closure (
    [string]$freeze.schema_version -ceq
        "sporespore_qsdk_r23d9_physical_freeze_v1" -and
    [string]$freeze.campaign_id -ceq $campaignId -and
    [string]$freeze.gate_id -ceq $gateId -and
    [string]$freeze.source_commit -ceq $sourceCommit -and
    [string]$freeze.source_tree_git_oid -ceq $sourceTree -and
    @($freeze.source_bindings).Count -eq 92 -and
    @($freeze.runtime_artifacts).Count -eq 3 -and
    @($freeze.external_runtime_bindings).Count -eq 4 -and
    [bool]$freeze.production_authorization_canaries_valid -and
    [bool]$freeze.complete_zero_world_gate_passed -and
    [bool]$freeze.physical_execution_authorized
) "QSDK-R23D9 physical freeze changed"
$canaries = $freeze.production_authorization_canaries
Assert-R23D9Closure (
    [int]$canaries.engine_count -eq 3 -and
    [int]$canaries.worker_process_launch_count -eq 6 -and
    [int]$canaries.actual_production_authorization_function_execution_count -eq 6 -and
    [int]$canaries.positive_authorization_canary_count -eq 3 -and
    [int]$canaries.mutated_binding_refusal_canary_count -eq 3 -and
    [int]$canaries.model_construction_count -eq 0 -and
    [int]$canaries.world_build_count -eq 0 -and
    [bool]$canaries.test_only_evidence_root_deleted
) "QSDK-R23D9 production authorization canary receipt changed"
Assert-R23D9Closure (
    [string]$authorization.schema_version -ceq
        "sporespore_qsdk_r23d9_attempt_v1" -and
    [string]$authorization.attempt_id -ceq [string]$closure.attempt.attempt_id -and
    [string]$authorization.source_commit -ceq $sourceCommit -and
    [string]$authorization.freeze_raw_sha256 -ceq
        [string]$closure.attempt.physical_freeze_raw_sha256 -and
    [string]$authorization.full_godot_attestation_sha256 -ceq
        [string]$closure.full_godot_attestation.raw_sha256 -and
    [bool]$authorization.physical_execution_authorized -and
    [bool]$authorization.single_use_supervisor_authorization -and
    [bool]$authorization.one_shot_attempt_unconsumed -and
    @($authorization.ordered_stage_a_cell_ids).Count -eq 2 -and
    @($authorization.ordered_stage_b_cell_ids).Count -eq 0
) "QSDK-R23D9 Stage A authorization changed"
Assert-R23D9Closure (
    [string]$completion.status -ceq "invalid_or_incomplete_first_attempt" -and
    [string]$completion.failure_code -ceq
        "SUPERVISOR_INFRASTRUCTURE_EXCEPTION" -and
    [string]$completion.failure_detail -ceq
        [string]$closure.immutable_completion_record.failure_detail -and
    [bool]$completion.one_shot_identity_consumed -and
    -not [bool]$completion.same_identity_rerun_allowed -and
    -not [bool]$completion.command_conditioned_turning -and
    -not [bool]$completion.q_sdk_r23_satisfied -and
    -not [bool]$completion.cross_engine_equivalence -and
    -not [bool]$completion.release_authorized -and
    -not [bool]$completion.physical_acceptance_authority
) "QSDK-R23D9 immutable completion changed"

$manifest = Get-Content -Raw -LiteralPath $manifestPath |
    ConvertFrom-Json -AsHashtable -Depth 100
$retainedCellIds = @()
for ($index = 0; $index -lt @($closure.retained_stage_a_cells).Count; $index++) {
    $expected = $closure.retained_stage_a_cells[$index]
    $cellId = [string]$expected.cell_id
    $retainedCellIds += $cellId
    $cellRoot = Join-Path $EvidenceRoot "stage-a\$cellId"
    $processPath = Join-Path $cellRoot "process.json"
    $stdoutPath = Join-Path $cellRoot "stdout.txt"
    $stderrPath = Join-Path $cellRoot "stderr.txt"
    $terminalPath = Join-Path $cellRoot "terminal-entry.json"
    foreach ($receipt in @(
        @{ path = $processPath; digest = $expected.process_raw_sha256 },
        @{ path = $stdoutPath; digest = $expected.stdout_raw_sha256 },
        @{ path = $stderrPath; digest = $expected.stderr_raw_sha256 },
        @{ path = $terminalPath; digest = $expected.terminal_entry_raw_sha256 }
    )) {
        Assert-R23D9Closure (
            (Get-R23D9ClosureRawSha256 $receipt.path) -ceq
                [string]$receipt.digest
        ) "QSDK-R23D9 retained worker artifact changed: $($receipt.path)"
    }
    $process = Get-Content -Raw -LiteralPath $processPath |
        ConvertFrom-Json -AsHashtable -Depth 30
    $stdout = Get-Content -Raw -LiteralPath $stdoutPath
    $terminal = Get-Content -Raw -LiteralPath $terminalPath |
        ConvertFrom-Json -AsHashtable -Depth 100
    $stdoutTerminal = Get-R23D9ClosureMarker `
        -Text $stdout `
        -Prefix "QSDK_R23D9_TERMINAL "
    $tracePath = Join-Path $EvidenceRoot (
        "traces\mujoco_support_handoff_screen__$cellId.ndjson"
    )
    Assert-R23D9Closure (
        [string]$process.schema_version -ceq
            "sporespore_qsdk_r23d9_worker_process_v1" -and
        [bool]$process.process_launch_succeeded -and
        [int]$process.exit_code -eq 0 -and
        -not [bool]$process.timed_out -and
        [double]$process.duration_seconds -eq
            [double]$expected.process_duration_seconds -and
        [string]$terminal.schema_version -ceq
            "sporespore_qsdk_r23d9_engine_cell_report_v1" -and
        [string]$terminal.cell_id -ceq $cellId -and
        [bool]$terminal.execution.integrity_passed -and
        [int]$terminal.execution.world_attempt_count -eq 1 -and
        [int]$terminal.execution.world_build_count -eq 1 -and
        [int]$terminal.trace_summary.row_count -eq 3772 -and
        [string]$terminal.trace_summary.raw_sha256 -ceq
            [string]$expected.trace_raw_sha256 -and
        (Get-R23D9ClosureRawSha256 $tracePath) -ceq
            [string]$expected.trace_raw_sha256 -and
        [string]$stdoutTerminal.cell_id -ceq $cellId -and
        [string]$stdoutTerminal.trace_summary.raw_sha256 -ceq
            [string]$terminal.trace_summary.raw_sha256 -and
        [int]$terminal.measurements.post_handoff_native_actuation_application_count -eq 0 -and
        [double]$terminal.measurements.turn_phase_yaw_delta_rad -eq
            [double]$expected.turn_phase_yaw_delta_rad -and
        [int]$terminal.measurements.post_handoff_contact_loss_step_count -eq
            [int]$expected.post_handoff_contact_loss_step_count
    ) "QSDK-R23D9 retained worker semantics changed: $cellId"
    $terminalPayload = Join-Path (Join-Path (
        Get-SporeSporeArtifactEvidenceRoot -RepoRoot $repoRoot
    ) "artifacts\sha256") (
        $expected.terminal_entry_raw_sha256.Substring(7) + "\payload.bin"
    )
    Assert-R23D9Closure (
        [string]$manifest[$index] -ceq $terminalPayload
    ) "QSDK-R23D9 Stage A terminal manifest changed: $cellId"
}
Assert-R23D9Closure (
    ($retainedCellIds -join "|") -ceq (
        "mujoco__support_handoff__positive_heading|" +
        "mujoco__support_handoff__negative_heading"
    )
) "QSDK-R23D9 retained Stage A cell order changed"
Assert-R23D9Closure (
    [bool]$closure.retained_stage_a_cells[0].outcome_gate_passed -and
    @($closure.retained_stage_a_cells[0].failed_gate_ids).Count -eq 0 -and
    -not [bool]$closure.retained_stage_a_cells[1].outcome_gate_passed -and
    (@($closure.retained_stage_a_cells[1].failed_gate_ids) -join "|") -ceq
        "R23D9_IRREVERSIBLE_HANDOFF"
) "QSDK-R23D9 retained cell-level outcome boundary changed"

Assert-R23D9Closure (
    (Get-R23D9ClosureRawSha256 $evaluatorProcessPath) -ceq
        [string]$closure.retained_evaluator_diagnostic.process_raw_sha256 -and
    (Get-R23D9ClosureRawSha256 $evaluatorStdoutPath) -ceq
        [string]$closure.retained_evaluator_diagnostic.stdout_raw_sha256 -and
    (Get-R23D9ClosureRawSha256 $evaluatorStderrPath) -ceq $emptySha256
) "QSDK-R23D9 retained evaluator process bytes changed"
$evaluatorProcess = Get-Content -Raw -LiteralPath $evaluatorProcessPath |
    ConvertFrom-Json -AsHashtable -Depth 30
$evaluatorStdout = Get-Content -Raw -LiteralPath $evaluatorStdoutPath
$genericLines = @(($evaluatorStdout -split "`r?`n") | Where-Object {
    $_.StartsWith("QSDK_R23D9_EVALUATION ", [StringComparison]::Ordinal)
})
$expectedLines = @(($evaluatorStdout -split "`r?`n") | Where-Object {
    $_.StartsWith(
        "QSDK_R23D9_STAGE_A_EVALUATION ",
        [StringComparison]::Ordinal
    )
})
Assert-R23D9Closure ($genericLines.Count -eq 1 -and $expectedLines.Count -eq 0) (
    "QSDK-R23D9 retained evaluator marker counts changed"
)
$diagnostic = $genericLines[0].Substring("QSDK_R23D9_EVALUATION ".Length) |
    ConvertFrom-Json -AsHashtable -Depth 100
Assert-R23D9Closure (
    [int]$evaluatorProcess.exit_code -eq 0 -and
    -not [bool]$evaluatorProcess.timed_out -and
    [string]$diagnostic.schema_version -ceq
        "sporespore_qsdk_r23d9_stage_a_evaluation_v1" -and
    [string]$diagnostic.classification -ceq "valid_none_stage_a" -and
    [bool]$diagnostic.valid -and
    [string]$diagnostic.selected_terminal_policy_id -ceq "NONE" -and
    -not [bool]$diagnostic.stage_b_launch_authorized -and
    [int]$diagnostic.world_attempt_count -eq 2 -and
    [int]$diagnostic.world_build_count -eq 2 -and
    @($diagnostic.cell_evaluations).Count -eq 2 -and
    [bool]$diagnostic.cell_evaluations[0].outcome.outcome_gate_passed -and
    -not [bool]$diagnostic.cell_evaluations[1].outcome.outcome_gate_passed -and
    [bool]$closure.retained_evaluator_diagnostic.diagnostic_payload_is_not_authoritative_campaign_result
) "QSDK-R23D9 retained diagnostic evaluator payload changed"
Assert-R23D9Closure (
    -not (Test-Path -LiteralPath (Join-Path $evaluatorRoot "evaluation.json")) -and
    -not (Test-Path -LiteralPath (Join-Path $EvidenceRoot "report.json")) -and
    -not (Test-Path -LiteralPath (Join-Path $EvidenceRoot "complete-evaluator")) -and
    -not (Test-Path -LiteralPath (Join-Path $EvidenceRoot "stage-b-authorization.json")) -and
    -not (Test-Path -LiteralPath (Join-Path $EvidenceRoot "stage-b")) -and
    -not (Test-Path -LiteralPath (Join-Path $EvidenceRoot "stage-b-terminal-paths.json"))
) "QSDK-R23D9 unopened or incomplete campaign boundary changed"

$historicalTexts = @{}
foreach ($expected in @($closure.historical_source_blobs)) {
    $actual = Get-R23D9ClosureGitBlob `
        -Commit $sourceCommit `
        -Path ([string]$expected.path)
    Assert-R23D9Closure (
        [string]$actual.oid -ceq [string]$expected.git_blob_oid -and
        [int64]$actual.byte_length -eq [int64]$expected.byte_length -and
        [string]$actual.raw_sha256 -ceq [string]$expected.raw_sha256
    ) "QSDK-R23D9 historical source blob changed: $($expected.path)"
    $historicalTexts[[string]$expected.path] = [string]$actual.text
}
$frozenSupervisor = [string]$historicalTexts[
    "sdk/run_qsdk_r23d9_supervisor.ps1"
]
$frozenEvaluator = [string]$historicalTexts[
    "sdk/turning/r23d9_physical_evaluator.py"
]
$frozenImplementation = [string]$historicalTexts[
    "sdk/turning/r23d9_physical_implementation_contract_v1.json"
] | ConvertFrom-Json -AsHashtable -Depth 100
Assert-R23D9Closure (
    $frozenSupervisor.Contains(
        '$prefix = "QSDK_R23D9_STAGE_A_EVALUATION "',
        [StringComparison]::Ordinal
    ) -and
    $frozenSupervisor.Contains(
        '$prefix = "QSDK_R23D9_COMPLETE_EVALUATION "',
        [StringComparison]::Ordinal
    ) -and
    $frozenEvaluator.Contains(
        'print("QSDK_R23D9_EVALUATION " + json.dumps(result, sort_keys=True))',
        [StringComparison]::Ordinal
    ) -and
    @($frozenImplementation.source_binding_policy.exact_paths) -ccontains
        "sdk/run_qsdk_r23d9_supervisor.ps1" -and
    @($frozenImplementation.source_binding_policy.exact_paths) -ccontains
        "sdk/turning/r23d9_physical_evaluator.py"
) "QSDK-R23D9 historical producer/consumer marker mismatch changed"

$currentSupervisor = Get-Content -Raw -LiteralPath $supervisorPath
$currentMujoco = Get-Content -Raw -LiteralPath (Join-Path $sdkRoot (
    "adapters\mujoco\sporespore_mujoco_adapter\" +
    "qsdk_r23d9_support_handoff_physical.py"
))
$currentRapier = Get-Content -Raw -LiteralPath (Join-Path $sdkRoot (
    "adapters\rapier\src\qsdk_r23d3_phase_balanced.rs"
))
$currentGodot = Get-Content -Raw -LiteralPath (Join-Path $repoRoot (
    "tests\test_sdk_qsdk_r23d9_support_handoff_godot_jolt_worker.gd"
))
Assert-R23D9Closure (
    $currentSupervisor.Contains(
        'r23d9_physical_closure_v1.json', [StringComparison]::Ordinal
    ) -and
    $currentSupervisor.Contains(
        'r23d9_identity_closed', [StringComparison]::Ordinal
    ) -and
    $currentMujoco.Contains(
        'if CLOSURE_PATH.is_file():', [StringComparison]::Ordinal
    ) -and
    $currentMujoco.Contains(
        'QSDK_R23D9_MJC_CLOSED', [StringComparison]::Ordinal
    ) -and
    $currentRapier.Contains(
        'R23D9_CLOSURE_PATH', [StringComparison]::Ordinal
    ) -and
    $currentRapier.Contains(
        'QSDK_R23D9_RAP_CLOSED', [StringComparison]::Ordinal
    ) -and
    $currentGodot.Contains(
        'FileAccess.file_exists(R9_CLOSURE_PATH)', [StringComparison]::Ordinal
    ) -and
    $currentGodot.Contains(
        'QSDK_R23D9_GJT_CLOSED', [StringComparison]::Ordinal
    )
) "QSDK-R23D9 closure interlocks changed"

$priorAttemptCount = @(Get-ChildItem -LiteralPath (
    Get-SporeSporeArtifactEvidenceRoot -RepoRoot $repoRoot
) -Directory -Filter "qsdk-r23d9-*" | Where-Object {
    Test-Path -LiteralPath (Join-Path $_.FullName "stage-a-authorization.json")
}).Count
$start = [Diagnostics.ProcessStartInfo]::new()
$start.FileName = [Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
$start.WorkingDirectory = $repoRoot
$start.UseShellExecute = $false
$start.CreateNoWindow = $true
$start.RedirectStandardOutput = $true
$start.RedirectStandardError = $true
foreach ($argument in @(
    "-NoLogo", "-NoProfile", "-File", $supervisorPath,
    "-RunPhysical", "-FullConformanceAttestation", $attestationPath
)) {
    [void]$start.ArgumentList.Add($argument)
}
$process = [Diagnostics.Process]::new()
$process.StartInfo = $start
Assert-R23D9Closure $process.Start() (
    "QSDK-R23D9 closure could not start the rerun-refusal canary"
)
$stdoutTask = $process.StandardOutput.ReadToEndAsync()
$stderrTask = $process.StandardError.ReadToEndAsync()
$timedOut = -not $process.WaitForExit(60000)
if ($timedOut) {
    $process.Kill($true)
    $process.WaitForExit()
}
$refusalStdout = $stdoutTask.GetAwaiter().GetResult()
$refusalStderr = $stderrTask.GetAwaiter().GetResult()
$refusalExit = $process.ExitCode
$process.Dispose()
$refusal = Get-R23D9ClosureMarker `
    -Text $refusalStdout `
    -Prefix "QSDK_R23D9_PHYSICAL_REFUSAL "
$afterAttemptCount = @(Get-ChildItem -LiteralPath (
    Get-SporeSporeArtifactEvidenceRoot -RepoRoot $repoRoot
) -Directory -Filter "qsdk-r23d9-*" | Where-Object {
    Test-Path -LiteralPath (Join-Path $_.FullName "stage-a-authorization.json")
}).Count
Assert-R23D9Closure (
    -not $timedOut -and
    $refusalExit -ne 0 -and
    [string]$refusal.reason -ceq "r23d9_identity_closed" -and
    [string]$refusal.refusal_stage -ceq "before_attempt_or_world" -and
    [int]$refusal.physical_process_launch_count -eq 0 -and
    [int]$refusal.world_attempt_count -eq 0 -and
    [int]$refusal.world_build_count -eq 0 -and
    $priorAttemptCount -eq $afterAttemptCount -and
    $refusalStderr.Contains("QSDK-R23D9 CLOSED", [StringComparison]::Ordinal)
) "QSDK-R23D9 same-identity rerun did not fail closed"

Assert-R23D9Closure (
    -not [bool]$closure.claims.scientific_positive -and
    -not [bool]$closure.claims.scientific_negative -and
    -not [bool]$closure.claims.command_conditioned_turning -and
    -not [bool]$closure.claims.bilateral_signed_turning -and
    -not [bool]$closure.claims.portable_basic_turning -and
    -not [bool]$closure.claims.cross_engine_equivalence -and
    -not [bool]$closure.claims.q_sdk_r23_satisfied -and
    -not [bool]$closure.claims.prone_to_standing -and
    -not [bool]$closure.claims.release_authorized -and
    -not [bool]$closure.claims.physical_acceptance_authority -and
    [string]$closure.successor_boundary.successor_id -ceq "QSDK-R23D10" -and
    [bool]$closure.successor_boundary.new_campaign_and_gate_identity_required -and
    -not [bool]$closure.successor_boundary.marker_only_same_policy_physical_rerun_permitted -and
    [bool]$closure.successor_boundary.scientifically_distinct_physical_policy_required_for_new_worlds -and
    [bool]$closure.successor_boundary.producer_consumer_cli_marker_integration_canary_required_before_worlds
) "QSDK-R23D9 claim or successor boundary changed"

Write-Host (
    "QSDK_R23D9_CLOSURE_PASS status=infrastructure-invalid worlds=2 " +
    "stage_a=2/2 evaluator_exit=0 generic_marker=1 expected_marker=0 " +
    "diagnostic=valid-none-stage-a stage_b=0 one_shot=True " +
    "turning=False equivalence=False physical_authority=False"
)
