#requires -Version 7.0

[CmdletBinding()]
param(
    [string]$EvidenceRoot = (
        "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence\" +
        "qsdk-r23d5-20260808T162059Z"
    )
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$sdkRoot = Join-Path $repoRoot "sdk"
$closurePath = Join-Path $sdkRoot "turning\r23d5_physical_closure_v1.json"
$supervisorPath = Join-Path $sdkRoot "run_qsdk_r23d5_supervisor.ps1"
$artifactStorePath = Join-Path $sdkRoot "content_addressed_artifact_store.ps1"
$campaignId = "QSDK-R23D5-DEPENDENCY-CLOSED-TERMINAL-STABILIZED-BILATERAL-TURN-DEVELOPMENT"
$gateId = "QSDK-R23D5"
$sourceCommit = "f2378090357e5bbbceb2b1787c7f317d66aaa3a2"
$sourceTree = "d7b38cbb879c178809ace51a8241e7928a643be4"
$failureCode = "QSDK_R23D5_MJC_PHYSICAL_WORKER_ERROR:KeyError:'forward_velocity_foot_placement'"

. $artifactStorePath

function Assert-R23D5Closure {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function Get-R23D5ClosureRawSha256 {
    param([Parameter(Mandatory)][string]$Path)
    return "sha256:" + (
        Get-FileHash -LiteralPath $Path -Algorithm SHA256
    ).Hash.ToLowerInvariant()
}

function Get-R23D5ClosureBytesSha256 {
    param([Parameter(Mandatory)][byte[]]$Bytes)
    return "sha256:" + [Convert]::ToHexString(
        [Security.Cryptography.SHA256]::HashData($Bytes)
    ).ToLowerInvariant()
}

function Get-R23D5ClosureEvidenceTree {
    param([Parameter(Mandatory)][string]$Root)
    $files = @(Get-ChildItem -LiteralPath $Root -File -Recurse | Sort-Object {
        $_.FullName.Substring($Root.Length + 1).Replace("\", "/")
    })
    $lines = @($files | ForEach-Object {
        $relative = $_.FullName.Substring($Root.Length + 1).Replace("\", "/")
        "{0}`t{1}`t{2}" -f $relative, $_.Length, (
            Get-R23D5ClosureRawSha256 $_.FullName
        ).Substring(7)
    })
    $projection = [Text.Encoding]::UTF8.GetBytes(($lines -join "`n") + "`n")
    return [ordered]@{
        files = $files
        file_count = $files.Count
        total_byte_length = [int64](($files | Measure-Object Length -Sum).Sum)
        raw_sha256 = Get-R23D5ClosureBytesSha256 $projection
    }
}

function Get-R23D5ClosureGitBlob {
    param(
        [Parameter(Mandatory)][string]$Commit,
        [Parameter(Mandatory)][string]$Path
    )
    $spec = "$Commit`:$Path"
    $oid = (& git -C $repoRoot rev-parse $spec 2>$null).Trim()
    Assert-R23D5Closure (
        $LASTEXITCODE -eq 0 -and $oid -match '^[0-9a-f]{40}$'
    ) "QSDK-R23D5 historical Git blob is unavailable: $spec"
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
    Assert-R23D5Closure $process.Start() "QSDK-R23D5 could not start git cat-file"
    $memory = [IO.MemoryStream]::new()
    try {
        $process.StandardOutput.BaseStream.CopyTo($memory)
        $stderr = $process.StandardError.ReadToEnd()
        $process.WaitForExit()
        Assert-R23D5Closure ($process.ExitCode -eq 0) (
            "QSDK-R23D5 git cat-file failed for $spec`: $stderr"
        )
        $bytes = $memory.ToArray()
        return [ordered]@{
            oid = $oid
            byte_length = $bytes.Length
            raw_sha256 = Get-R23D5ClosureBytesSha256 $bytes
            text = [Text.Encoding]::UTF8.GetString($bytes)
        }
    } finally {
        $memory.Dispose()
        $process.Dispose()
    }
}

Assert-R23D5Closure (
    (git -C $repoRoot rev-parse --show-toplevel).Replace("/", "\") -ceq
        $repoRoot -and
    (git -C $repoRoot remote get-url origin) -ceq
        "https://github.com/Slagathore/sporespore.git"
) "QSDK-R23D5 closure repository identity mismatch"
Assert-R23D5Closure (Test-Path -LiteralPath $closurePath -PathType Leaf) (
    "QSDK-R23D5 closure is missing"
)
Assert-R23D5Closure (Test-Path -LiteralPath $EvidenceRoot -PathType Container) (
    "QSDK-R23D5 retained attempt root is missing"
)

$closure = Get-Content -Raw -LiteralPath $closurePath |
    ConvertFrom-Json -AsHashtable -Depth 100
$tree = Get-R23D5ClosureEvidenceTree $EvidenceRoot
Assert-R23D5Closure (
    [int]$tree.file_count -eq [int]$closure.attempt.evidence_file_count -and
    [int64]$tree.total_byte_length -eq
        [int64]$closure.attempt.evidence_total_byte_length -and
    [string]$tree.raw_sha256 -ceq
        [string]$closure.attempt.evidence_tree_raw_sha256
) "QSDK-R23D5 retained evidence tree changed"

$evidenceRootParent = Get-SporeSporeArtifactEvidenceRoot -RepoRoot $repoRoot
foreach ($file in @($tree.files)) {
    $digest = (Get-R23D5ClosureRawSha256 $file.FullName).Substring(7)
    $casDirectory = Join-Path $evidenceRootParent "artifacts\sha256\$digest"
    Assert-R23D5Closure (Test-SporeSporeStoredArtifact `
        -Directory $casDirectory `
        -ExpectedSha256 $digest `
        -ExpectedByteLength $file.Length) (
        "QSDK-R23D5 retained file lacks matching CAS bytes: $($file.FullName)"
    )
}

$keyDigests = [ordered]@{
    "physical-freeze.json" = $closure.attempt.physical_freeze_raw_sha256
    "stage-a-authorization.json" = $closure.attempt.stage_a_authorization_raw_sha256
    "completion.json" = $closure.attempt.completion_raw_sha256
    "report.json" = $closure.attempt.report_raw_sha256
    "stage-a-evaluator/evaluation.json" = $closure.attempt.stage_a_evaluation_raw_sha256
    "complete-evaluator/evaluation.json" = $closure.attempt.complete_evaluation_raw_sha256
}
foreach ($item in $keyDigests.GetEnumerator()) {
    $path = Join-Path $EvidenceRoot $item.Key
    Assert-R23D5Closure (
        (Get-R23D5ClosureRawSha256 $path) -ceq [string]$item.Value
    ) "QSDK-R23D5 retained key file changed: $($item.Key)"
}

$freeze = Get-Content -Raw -LiteralPath (Join-Path $EvidenceRoot "physical-freeze.json") |
    ConvertFrom-Json -AsHashtable -Depth 100
$authorization = Get-Content -Raw -LiteralPath (
    Join-Path $EvidenceRoot "stage-a-authorization.json"
) | ConvertFrom-Json -AsHashtable -Depth 100
$completion = Get-Content -Raw -LiteralPath (Join-Path $EvidenceRoot "completion.json") |
    ConvertFrom-Json -AsHashtable -Depth 100
$report = Get-Content -Raw -LiteralPath (Join-Path $EvidenceRoot "report.json") |
    ConvertFrom-Json -AsHashtable -Depth 100
$stageAEvaluation = Get-Content -Raw -LiteralPath (
    Join-Path $EvidenceRoot "stage-a-evaluator\evaluation.json"
) | ConvertFrom-Json -AsHashtable -Depth 100
$completeEvaluation = Get-Content -Raw -LiteralPath (
    Join-Path $EvidenceRoot "complete-evaluator\evaluation.json"
) | ConvertFrom-Json -AsHashtable -Depth 100

Assert-R23D5Closure (
    [string]$closure.schema_version -ceq
        "sporespore_qsdk_r23d5_physical_development_closure_v1" -and
    [string]$closure.status -ceq
        "closed_consumed_implementation_invalid_after_stage_a_worlds" -and
    [string]$closure.campaign_id -ceq $campaignId -and
    [string]$closure.gate_id -ceq $gateId -and
    [string]$closure.source_identity.commit -ceq $sourceCommit -and
    [string]$closure.source_identity.tree_git_oid -ceq $sourceTree -and
    [int]$closure.source_identity.declared_source_binding_count -eq 70 -and
    [int]$closure.attempt.launched_stage_a_worker_process_count -eq 2 -and
    [int]$closure.attempt.retained_stage_a_terminal_entry_count -eq 2 -and
    [int]$closure.attempt.stage_b_worker_process_count -eq 0 -and
    [int]$closure.attempt.world_attempt_count -eq 2 -and
    [int]$closure.attempt.world_build_count -eq 2 -and
    [bool]$closure.attempt.one_shot_identity_consumed -and
    -not [bool]$closure.attempt.same_identity_rerun_allowed
) "QSDK-R23D5 closure identity changed"

Assert-R23D5Closure (
    [string]$freeze.schema_version -ceq
        "sporespore_qsdk_r23d5_physical_freeze_v1" -and
    [string]$freeze.source_commit -ceq $sourceCommit -and
    [string]$freeze.source_tree_git_oid -ceq $sourceTree -and
    @($freeze.source_bindings).Count -eq 70 -and
    @($freeze.runtime_artifacts).Count -eq 3 -and
    @($freeze.external_runtime_bindings).Count -eq 4 -and
    [bool]$freeze.complete_zero_world_gate_passed -and
    [bool]$freeze.source_checkout_bytes_equal_git_blobs -and
    [bool]$freeze.reproducible_runtime_materialization_passed -and
    [bool]$freeze.physical_execution_authorized
) "QSDK-R23D5 physical freeze changed"
Assert-R23D5Closure (
    [string]$authorization.schema_version -ceq
        "sporespore_qsdk_r23d5_attempt_v1" -and
    [string]$authorization.attempt_id -ceq [string]$closure.attempt.attempt_id -and
    [string]$authorization.source_commit -ceq $sourceCommit -and
    [bool]$authorization.physical_execution_authorized -and
    [bool]$authorization.one_shot_attempt_unconsumed -and
    @($authorization.ordered_stage_a_cell_ids).Count -eq 2 -and
    @($authorization.ordered_stage_b_cell_ids).Count -eq 0 -and
    [string]$authorization.full_godot_attestation_sha256 -ceq
        [string]$closure.full_godot_attestation.raw_sha256
) "QSDK-R23D5 Stage A authorization changed"

Assert-R23D5Closure (
    [string]$completion.status -ceq "invalid_or_incomplete_first_attempt" -and
    [string]$completion.result_classification -ceq
        "invalid_or_incomplete_complete_campaign" -and
    [string]$completion.selected_terminal_restoration_policy_id -ceq "INVALID" -and
    [int]$completion.stage_a_terminal_entry_count -eq 2 -and
    [int]$completion.stage_b_terminal_entry_count -eq 0 -and
    [bool]$completion.one_shot_identity_consumed -and
    -not [bool]$completion.same_identity_rerun_allowed -and
    -not [bool]$completion.command_conditioned_turning -and
    -not [bool]$completion.cross_engine_equivalence -and
    -not [bool]$completion.physical_acceptance_authority
) "QSDK-R23D5 immutable completion changed"
Assert-R23D5Closure (
    [string]$stageAEvaluation.classification -ceq
        "invalid_or_incomplete_stage_a" -and
    [string]$stageAEvaluation.selected_terminal_restoration_policy_id -ceq
        "INVALID" -and
    -not [bool]$stageAEvaluation.stage_b_launch_authorized -and
    @($stageAEvaluation.cell_evaluations).Count -eq 2 -and
    [string]$completeEvaluation.classification -ceq
        "invalid_or_incomplete_complete_campaign" -and
    $null -eq $completeEvaluation.stage_b -and
    [int]$completeEvaluation.world_attempt_count -eq 2 -and
    [int]$completeEvaluation.world_build_count -eq 2
) "QSDK-R23D5 evaluator closure changed"
Assert-R23D5Closure (
    [string]$report.result_classification -ceq
        "invalid_or_incomplete_complete_campaign" -and
    -not [bool]$report.development_result_valid -and
    -not [bool]$report.stage_b_launched -and
    [int]$report.stage_a_world_count -eq 2 -and
    [int]$report.stage_b_world_count -eq 0 -and
    @($report.ordered_stage_a_cells).Count -eq 2 -and
    @($report.ordered_stage_b_cells).Count -eq 0
) "QSDK-R23D5 campaign report changed"

$orderedArms = @("positive_heading", "negative_heading")
$orderedOffsets = @(0.2, -0.2)
foreach ($index in 0..1) {
    $declared = $closure.retained_stage_a_cells[$index]
    $cellId = "mujoco__terminal_restoration__$($orderedArms[$index])"
    $cellRoot = Join-Path $EvidenceRoot "stage-a\$cellId"
    $processPath = Join-Path $cellRoot "process.json"
    $stdoutPath = Join-Path $cellRoot "stdout.txt"
    $stderrPath = Join-Path $cellRoot "stderr.txt"
    $terminalPath = Join-Path $cellRoot "terminal-entry.json"
    Assert-R23D5Closure (
        (Get-R23D5ClosureRawSha256 $processPath) -ceq
            [string]$declared.process_raw_sha256 -and
        (Get-R23D5ClosureRawSha256 $stdoutPath) -ceq
            [string]$declared.stdout_raw_sha256 -and
        (Get-R23D5ClosureRawSha256 $stderrPath) -ceq
            [string]$declared.stderr_raw_sha256 -and
        (Get-R23D5ClosureRawSha256 $terminalPath) -ceq
            [string]$declared.terminal_entry_raw_sha256
    ) "QSDK-R23D5 retained Stage A bytes changed: $cellId"
    $processReceipt = Get-Content -Raw -LiteralPath $processPath |
        ConvertFrom-Json -AsHashtable -Depth 30
    $terminal = Get-Content -Raw -LiteralPath $terminalPath |
        ConvertFrom-Json -AsHashtable -Depth 100
    $stdout = Get-Content -Raw -LiteralPath $stdoutPath
    $stderr = Get-Content -Raw -LiteralPath $stderrPath
    $terminalLines = @($stdout -split "`r?`n" | Where-Object {
        $_.StartsWith("QSDK_R23D5_TERMINAL ", [StringComparison]::Ordinal)
    })
    Assert-R23D5Closure (
        [string]$declared.cell_id -ceq $cellId -and
        [string]$declared.arm_id -ceq $orderedArms[$index] -and
        [double]$declared.turn_heading_offset_rad -eq $orderedOffsets[$index] -and
        [bool]$processReceipt.process_launch_succeeded -and
        [int]$processReceipt.exit_code -eq 1 -and
        -not [bool]$processReceipt.timed_out -and
        [string]$terminal.failure_code -ceq $failureCode -and
        [string]$terminal.failure_stage -ceq "settlement_complete" -and
        [int]$terminal.world_attempt_count -eq 1 -and
        [int]$terminal.world_build_count -eq 1 -and
        $null -eq $terminal.trace_artifact -and
        $terminalLines.Count -eq 1 -and
        $stderr.Contains($failureCode)
    ) "QSDK-R23D5 retained Stage A failure changed: $cellId"
}

$attestationPath = [string]$closure.full_godot_attestation.path
Assert-R23D5Closure (
    (Get-R23D5ClosureRawSha256 $attestationPath) -ceq
        [string]$closure.full_godot_attestation.raw_sha256
) "QSDK-R23D5 full-Godot attestation bytes changed"
$attestation = Get-Content -Raw -LiteralPath $attestationPath |
    ConvertFrom-Json -AsHashtable -Depth 100
Assert-R23D5Closure (
    [string]$attestation.schema_version -ceq
        "sporespore_full_godot_conformance_attestation_v2" -and
    [string]$attestation.status -ceq "full_godot_conformance_passed" -and
    [string]$attestation.source.commit -ceq $sourceCommit -and
    [string]$attestation.source.tree_git_oid -ceq $sourceTree -and
    [bool]$attestation.conformance.godot_including -and
    [bool]$attestation.conformance.passed -and
    [double]$attestation.conformance.duration_seconds -eq
        [double]$closure.full_godot_attestation.duration_seconds -and
    -not [bool]$attestation.claims.physical_acceptance_authority
) "QSDK-R23D5 full-Godot attestation semantics changed"

foreach ($declaredBlob in @($closure.historical_source_blobs)) {
    $blob = Get-R23D5ClosureGitBlob `
        -Commit $sourceCommit `
        -Path ([string]$declaredBlob.path)
    Assert-R23D5Closure (
        [string]$blob.oid -ceq [string]$declaredBlob.git_blob_oid -and
        [int]$blob.byte_length -eq [int]$declaredBlob.byte_length -and
        [string]$blob.raw_sha256 -ceq [string]$declaredBlob.raw_sha256
    ) "QSDK-R23D5 historical source blob changed: $($declaredBlob.path)"
}
$workerBlob = Get-R23D5ClosureGitBlob $sourceCommit (
    "sdk/adapters/mujoco/sporespore_mujoco_adapter/qsdk_r23d5_dependency_closed.py"
)
$restorationBlob = Get-R23D5ClosureGitBlob $sourceCommit (
    "sdk/adapters/mujoco/sporespore_mujoco_adapter/selected_policy_pose_hold_restoration_mv6.py"
)
$baseBlob = Get-R23D5ClosureGitBlob $sourceCommit (
    "sdk/adapters/mujoco/sporespore_mujoco_adapter/qsdk_r23d2_heading_response.py"
)
Assert-R23D5Closure (
    $workerBlob.text.Contains("base.POLICY_ID") -and
    $workerBlob.text.Contains("restoration._terminal_restoration_composition(") -and
    $restorationBlob.text.Contains('receipt["forward_velocity_foot_placement"]') -and
    $baseBlob.text.Contains('POLICY_ID = "sporespore_balanced_wave_bw5r_b_v1"') -and
    [string]$closure.policy_composition_diagnosis.turning_policy_id -ceq
        "sporespore_balanced_wave_bw5r_b_v1" -and
    [string]$closure.policy_composition_diagnosis.imported_restoration_source_policy_id -ceq
        "sporespore_balanced_wave_bw15f_b_v1" -and
    [int]$closure.policy_composition_diagnosis.failure_after_controller_semantic_step_count -eq 2992 -and
    [int]$closure.policy_composition_diagnosis.failure_at_terminal_restoration_step -eq 0 -and
    -not [bool]$closure.policy_composition_diagnosis.trace_publication_completed
) "QSDK-R23D5 policy-composition diagnosis changed"

$supervisorSource = Get-Content -Raw -LiteralPath $supervisorPath
$mujocoSource = Get-Content -Raw -LiteralPath (
    Join-Path $sdkRoot "adapters\mujoco\sporespore_mujoco_adapter\qsdk_r23d5_dependency_closed.py"
)
$rapierSource = Get-Content -Raw -LiteralPath (
    Join-Path $sdkRoot "adapters\rapier\src\qsdk_r23d3_phase_balanced.rs"
)
$godotSource = Get-Content -Raw -LiteralPath (
    Join-Path $repoRoot "tests\test_sdk_qsdk_r23d5_godot_jolt_worker.gd"
)
Assert-R23D5Closure (
    $supervisorSource.Contains("r23d5_physical_closure_v1.json") -and
    $supervisorSource.Contains("QSDK-R23D5 CLOSED") -and
    $mujocoSource.Contains("QSDK_R23D5_MJC_CLOSED") -and
    $rapierSource.Contains("QSDK_R23D5_RAP_CLOSED") -and
    $godotSource.Contains("QSDK_R23D5_GJT_CLOSED")
) "QSDK-R23D5 closure interlocks changed"

$refusalOutput = (& pwsh `
    -NoLogo `
    -NoProfile `
    -File $supervisorPath `
    -RunPhysical `
    -FullConformanceAttestation "R23D5_CLOSED_CANARY_MUST_NOT_BE_READ" 2>&1 |
    Out-String)
Assert-R23D5Closure (
    $LASTEXITCODE -ne 0 -and
    $refusalOutput.Contains("QSDK-R23D5 CLOSED") -and
    $refusalOutput.Contains("rerun is forbidden")
) "QSDK-R23D5 supervisor did not refuse the closed identity"
$global:LASTEXITCODE = 0

Assert-R23D5Closure (
    [string]$closure.successor_boundary.successor_id -ceq "QSDK-R23D6" -and
    [bool]$closure.successor_boundary.new_campaign_and_gate_identity_required -and
    [bool]$closure.successor_boundary.policy_compatible_terminal_restoration_composition_required -and
    [bool]$closure.successor_boundary.production_shaped_bw5r_b_restoration_preflight_required -and
    [bool]$closure.successor_boundary.missing_forward_velocity_receipt_control_required -and
    [bool]$closure.successor_boundary.independent_heading_removal_oracle_required -and
    -not [bool]$closure.claims.scientific_positive -and
    -not [bool]$closure.claims.scientific_negative -and
    -not [bool]$closure.claims.command_conditioned_turning -and
    -not [bool]$closure.claims.cross_engine_equivalence -and
    -not [bool]$closure.claims.release_authorized -and
    -not [bool]$closure.claims.physical_acceptance_authority
) "QSDK-R23D5 closure claims changed"

Write-Host (
    "QSDK_R23D5_CLOSURE_PASS status=implementation-invalid worlds=2 " +
    "stage_a=2/2 worker_failures=2 controller_steps=2992 restoration_step=0 " +
    "failure=missing_forward_velocity_foot_placement stage_b=0 " +
    "turning=False equivalence=False rerun_refused=True physical_authority=False"
)
