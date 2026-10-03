#requires -Version 7.0

[CmdletBinding()]
param(
    [string]$EvidenceRoot = (
        "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence\" +
        "qsdk-r23d6-20260808T211150Z"
    )
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$sdkRoot = Join-Path $repoRoot "sdk"
$closurePath = Join-Path $sdkRoot "turning\r23d6_physical_closure_v1.json"
$supervisorPath = Join-Path $sdkRoot "run_qsdk_r23d6_supervisor.ps1"
$artifactStorePath = Join-Path $sdkRoot "content_addressed_artifact_store.ps1"
$campaignId = (
    "QSDK-R23D6-POLICY-COMPATIBLE-TERMINAL-STABILIZED-" +
    "BILATERAL-TURN-DEVELOPMENT"
)
$gateId = "QSDK-R23D6"
$sourceCommit = "acf0511fe9c24cd0439107ca3f8510054629263d"
$sourceTree = "8a103b53217f0338b3eb08e0347dcd9c3f3ba2ce"

. $artifactStorePath

function Assert-R23D6Closure {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function Get-R23D6ClosureRawSha256 {
    param([Parameter(Mandatory)][string]$Path)
    return "sha256:" + (
        Get-FileHash -LiteralPath $Path -Algorithm SHA256
    ).Hash.ToLowerInvariant()
}

function Get-R23D6ClosureBytesSha256 {
    param([Parameter(Mandatory)][byte[]]$Bytes)
    return "sha256:" + [Convert]::ToHexString(
        [Security.Cryptography.SHA256]::HashData($Bytes)
    ).ToLowerInvariant()
}

function Get-R23D6ClosureEvidenceTree {
    param([Parameter(Mandatory)][string]$Root)
    $files = @(Get-ChildItem -LiteralPath $Root -File -Recurse | Sort-Object {
        $_.FullName.Substring($Root.Length + 1).Replace("\", "/")
    })
    $lines = @($files | ForEach-Object {
        $relative = $_.FullName.Substring($Root.Length + 1).Replace("\", "/")
        "{0}`t{1}`t{2}" -f $relative, $_.Length, (
            Get-R23D6ClosureRawSha256 $_.FullName
        ).Substring(7)
    })
    $projection = [Text.Encoding]::UTF8.GetBytes(($lines -join "`n") + "`n")
    return [ordered]@{
        files = $files
        file_count = $files.Count
        total_byte_length = [int64](($files | Measure-Object Length -Sum).Sum)
        raw_sha256 = Get-R23D6ClosureBytesSha256 $projection
    }
}

function Get-R23D6ClosureGitBlob {
    param(
        [Parameter(Mandatory)][string]$Commit,
        [Parameter(Mandatory)][string]$Path
    )
    $spec = "$Commit`:$Path"
    $oid = (& git -C $repoRoot rev-parse $spec 2>$null).Trim()
    Assert-R23D6Closure (
        $LASTEXITCODE -eq 0 -and $oid -match '^[0-9a-f]{40}$'
    ) "QSDK-R23D6 historical Git blob is unavailable: $spec"
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
    Assert-R23D6Closure $process.Start() "QSDK-R23D6 could not start git cat-file"
    $memory = [IO.MemoryStream]::new()
    try {
        $process.StandardOutput.BaseStream.CopyTo($memory)
        $stderr = $process.StandardError.ReadToEnd()
        $process.WaitForExit()
        Assert-R23D6Closure ($process.ExitCode -eq 0) (
            "QSDK-R23D6 git cat-file failed for $spec`: $stderr"
        )
        $bytes = $memory.ToArray()
        return [ordered]@{
            oid = $oid
            byte_length = $bytes.Length
            raw_sha256 = Get-R23D6ClosureBytesSha256 $bytes
            text = [Text.Encoding]::UTF8.GetString($bytes)
        }
    } finally {
        $memory.Dispose()
        $process.Dispose()
    }
}

function Get-R23D6TraceFacts {
    param([Parameter(Mandatory)][string]$Path)
    $limbIds = @("front_left", "front_right", "rear_left", "rear_right")
    $counts = [ordered]@{}
    $rowCount = 0
    $maximumTilt = -1.0
    $maximumTiltTraceStep = -1
    $maximumTiltPhase = ""
    Get-Content -LiteralPath $Path | ForEach-Object {
        $row = $_ | ConvertFrom-Json -AsHashtable -Depth 30
        $rowCount++
        $phase = [string]$row.phase_id
        if (-not $counts.Contains($phase)) {
            $counts[$phase] = [ordered]@{}
        }
        $mask = (@($limbIds | ForEach-Object {
            if ([bool]$row.ordered_foot_contacts[$_]) { "1" } else { "0" }
        }) -join "")
        if (-not $counts[$phase].Contains($mask)) {
            $counts[$phase][$mask] = 0
        }
        $counts[$phase][$mask] = [int]$counts[$phase][$mask] + 1
        if ([double]$row.torso_tilt_rad -gt $maximumTilt) {
            $maximumTilt = [double]$row.torso_tilt_rad
            $maximumTiltTraceStep = [int]$row.trace_step
            $maximumTiltPhase = $phase
        }
    }
    return [ordered]@{
        row_count = $rowCount
        counts = $counts
        maximum_tilt_rad = $maximumTilt
        maximum_tilt_trace_step = $maximumTiltTraceStep
        maximum_tilt_phase = $maximumTiltPhase
    }
}

Assert-R23D6Closure (
    (git -C $repoRoot rev-parse --show-toplevel).Replace("/", "\") -ceq
        $repoRoot -and
    (git -C $repoRoot remote get-url origin) -ceq
        "https://github.com/Slagathore/sporespore.git"
) "QSDK-R23D6 closure repository identity mismatch"
Assert-R23D6Closure (Test-Path -LiteralPath $closurePath -PathType Leaf) (
    "QSDK-R23D6 closure is missing"
)
Assert-R23D6Closure (Test-Path -LiteralPath $EvidenceRoot -PathType Container) (
    "QSDK-R23D6 retained attempt root is missing"
)

$closure = Get-Content -Raw -LiteralPath $closurePath |
    ConvertFrom-Json -AsHashtable -Depth 100
$tree = Get-R23D6ClosureEvidenceTree $EvidenceRoot
Assert-R23D6Closure (
    [int]$tree.file_count -eq [int]$closure.attempt.evidence_file_count -and
    [int64]$tree.total_byte_length -eq
        [int64]$closure.attempt.evidence_total_byte_length -and
    [string]$tree.raw_sha256 -ceq
        [string]$closure.attempt.evidence_tree_raw_sha256
) "QSDK-R23D6 retained evidence tree changed"

$evidenceRootParent = Get-SporeSporeArtifactEvidenceRoot -RepoRoot $repoRoot
foreach ($file in @($tree.files)) {
    $digest = (Get-R23D6ClosureRawSha256 $file.FullName).Substring(7)
    $casDirectory = Join-Path $evidenceRootParent "artifacts\sha256\$digest"
    Assert-R23D6Closure (Test-SporeSporeStoredArtifact `
        -Directory $casDirectory `
        -ExpectedSha256 $digest `
        -ExpectedByteLength $file.Length) (
        "QSDK-R23D6 retained file lacks CAS bytes: $($file.FullName)"
    )
}
Assert-R23D6Closure (
    [bool]$closure.post_attempt_retention_repair.required -and
    -not [bool]$closure.post_attempt_retention_repair.attempt_tree_bytes_changed -and
    -not [bool]$closure.post_attempt_retention_repair.physics_or_evaluation_reexecuted -and
    @($closure.post_attempt_retention_repair.retained_artifacts).Count -eq 2 -and
    [string]$closure.post_attempt_retention_repair.retained_artifacts[0].raw_sha256 -ceq
        "sha256:1d52760f8c251f6681fba27d71dba635ace31fedbc0b5d351700009ccd5e6feb" -and
    [string]$closure.post_attempt_retention_repair.retained_artifacts[1].raw_sha256 -ceq
        "sha256:520b0b4b251f1232a5fe20dae9c6ef14a4c3538d22290ce4bca5d072383aea4f"
) "QSDK-R23D6 post-attempt retention record changed"

$keyDigests = [ordered]@{
    "physical-freeze.json" = $closure.attempt.physical_freeze_raw_sha256
    "stage-a-authorization.json" = $closure.attempt.stage_a_authorization_raw_sha256
    "completion.json" = $closure.attempt.completion_raw_sha256
    "report.json" = $closure.attempt.report_raw_sha256
    "stage-a-evaluator/evaluation.json" = $closure.attempt.stage_a_evaluation_raw_sha256
    "complete-evaluator/evaluation.json" = $closure.attempt.complete_evaluation_raw_sha256
    "stage-a-terminal-paths.json" = $closure.attempt.stage_a_manifest_raw_sha256
    "stage-b-terminal-paths.json" = $closure.attempt.stage_b_empty_manifest_raw_sha256
}
foreach ($item in $keyDigests.GetEnumerator()) {
    $path = Join-Path $EvidenceRoot $item.Key
    Assert-R23D6Closure (
        (Get-R23D6ClosureRawSha256 $path) -ceq [string]$item.Value
    ) "QSDK-R23D6 retained key file changed: $($item.Key)"
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

Assert-R23D6Closure (
    [string]$closure.schema_version -ceq
        "sporespore_qsdk_r23d6_physical_development_closure_v1" -and
    [string]$closure.status -ceq
        "closed_consumed_valid_none_stage_a_terminal_restoration_negative" -and
    [string]$closure.campaign_id -ceq $campaignId -and
    [string]$closure.gate_id -ceq $gateId -and
    [string]$closure.source_identity.commit -ceq $sourceCommit -and
    [string]$closure.source_identity.tree_git_oid -ceq $sourceTree -and
    [int]$closure.source_identity.declared_source_binding_count -eq 74 -and
    [int]$closure.attempt.world_attempt_count -eq 2 -and
    [int]$closure.attempt.world_build_count -eq 2 -and
    [bool]$closure.attempt.one_shot_identity_consumed -and
    -not [bool]$closure.attempt.same_identity_rerun_allowed
) "QSDK-R23D6 closure identity changed"

Assert-R23D6Closure (
    [string]$freeze.schema_version -ceq
        "sporespore_qsdk_r23d6_physical_freeze_v1" -and
    [string]$freeze.source_commit -ceq $sourceCommit -and
    [string]$freeze.source_tree_git_oid -ceq $sourceTree -and
    @($freeze.source_bindings).Count -eq 74 -and
    @($freeze.runtime_artifacts).Count -eq 3 -and
    @($freeze.external_runtime_bindings).Count -eq 4 -and
    [bool]$freeze.complete_zero_world_gate_passed -and
    [bool]$freeze.source_checkout_bytes_equal_git_blobs -and
    [bool]$freeze.reproducible_runtime_materialization_passed -and
    [bool]$freeze.physical_execution_authorized
) "QSDK-R23D6 physical freeze changed"
Assert-R23D6Closure (
    [string]$authorization.schema_version -ceq
        "sporespore_qsdk_r23d6_attempt_v1" -and
    [string]$authorization.attempt_id -ceq [string]$closure.attempt.attempt_id -and
    [string]$authorization.source_commit -ceq $sourceCommit -and
    [bool]$authorization.physical_execution_authorized -and
    [bool]$authorization.one_shot_attempt_unconsumed -and
    @($authorization.ordered_stage_a_cell_ids).Count -eq 2 -and
    @($authorization.ordered_stage_b_cell_ids).Count -eq 0 -and
    [string]$authorization.full_godot_attestation_sha256 -ceq
        [string]$closure.full_godot_attestation.raw_sha256
) "QSDK-R23D6 Stage A authorization changed"

Assert-R23D6Closure (
    [string]$completion.status -ceq "valid_none_stage_a_first_attempt" -and
    [string]$completion.result_classification -ceq "valid_none_stage_a" -and
    [string]$completion.selected_terminal_restoration_policy_id -ceq "NONE" -and
    [int]$completion.stage_a_terminal_entry_count -eq 2 -and
    [int]$completion.stage_b_terminal_entry_count -eq 0 -and
    [bool]$completion.one_shot_identity_consumed -and
    -not [bool]$completion.same_identity_rerun_allowed -and
    -not [bool]$completion.command_conditioned_turning -and
    -not [bool]$completion.cross_engine_equivalence -and
    -not [bool]$completion.physical_acceptance_authority
) "QSDK-R23D6 immutable completion changed"
Assert-R23D6Closure (
    [bool]$stageAEvaluation.valid -and
    [string]$stageAEvaluation.classification -ceq "valid_none_stage_a" -and
    [string]$stageAEvaluation.selected_terminal_restoration_policy_id -ceq "NONE" -and
    -not [bool]$stageAEvaluation.stage_b_launch_authorized -and
    @($stageAEvaluation.cell_evaluations).Count -eq 2 -and
    [string]$completeEvaluation.classification -ceq "valid_none_stage_a" -and
    $null -eq $completeEvaluation.stage_b -and
    [int]$completeEvaluation.world_attempt_count -eq 2 -and
    [int]$completeEvaluation.world_build_count -eq 2
) "QSDK-R23D6 evaluator closure changed"
Assert-R23D6Closure (
    [string]$report.result_classification -ceq "valid_none_stage_a" -and
    [bool]$report.development_result_valid -and
    -not [bool]$report.stage_b_launched -and
    [int]$report.stage_a_world_count -eq 2 -and
    [int]$report.stage_b_world_count -eq 0 -and
    @($report.ordered_stage_a_cells).Count -eq 2 -and
    @($report.ordered_stage_b_cells).Count -eq 0
) "QSDK-R23D6 campaign report changed"

$expectedCells = @(
    [ordered]@{
        arm = "positive_heading"
        offset = 0.2
        terminal = "sha256:c23f3b591003261f2a67c1a55697e6dd36e9ec405d579ef5329a57f295e0a164"
        trace = "sha256:b2722bee8f7b26075af89b8e097db83a322ade51051fe91cd2662dce92f0cca5"
        yaw = 0.0842283890494393
        first_contact = 180
        hold = 0
        pose = 6
        maximum_tilt = 0.22994998886284887
        failed = @(
            "R23D6_CONTACT_ACQUISITION",
            "R23D6_CONTACT_HOLD",
            "R23D6_POSE_MEMORY_TRANSITIONS"
        )
    },
    [ordered]@{
        arm = "negative_heading"
        offset = -0.2
        terminal = "sha256:21db819b04db599c54bb2127470511a0334a3b12a2b681ad52df6cb51df177c9"
        trace = "sha256:5571208845380d0ef135044590b423774be18bd5c2130631f417cc2acdbb4369"
        yaw = -0.15257912436083565
        first_contact = 242
        hold = 288
        pose = 16
        maximum_tilt = 0.6773622329526434
        failed = @(
            "R23D6_MAXIMUM_TILT",
            "R23D6_CONTACT_ACQUISITION",
            "R23D6_CONTACT_HOLD"
        )
    }
)
for ($index = 0; $index -lt $expectedCells.Count; $index++) {
    $expected = $expectedCells[$index]
    $declared = $closure.retained_stage_a_cells[$index]
    $evaluated = $stageAEvaluation.cell_evaluations[$index]
    $cellId = "mujoco__terminal_restoration__$($expected.arm)"
    $cellRoot = Join-Path $EvidenceRoot "stage-a\$cellId"
    $processPath = Join-Path $cellRoot "process.json"
    $stdoutPath = Join-Path $cellRoot "stdout.txt"
    $stderrPath = Join-Path $cellRoot "stderr.txt"
    $terminalPath = Join-Path $cellRoot "terminal-entry.json"
    $processReceipt = Get-Content -Raw -LiteralPath $processPath |
        ConvertFrom-Json -AsHashtable -Depth 30
    $terminal = Get-Content -Raw -LiteralPath $terminalPath |
        ConvertFrom-Json -AsHashtable -Depth 100
    $terminalLines = @(Get-Content -LiteralPath $stdoutPath | Where-Object {
        $_.StartsWith("QSDK_R23D6_TERMINAL ", [StringComparison]::Ordinal)
    })
    Assert-R23D6Closure (
        (Get-R23D6ClosureRawSha256 $processPath) -ceq
            [string]$declared.process_raw_sha256 -and
        (Get-R23D6ClosureRawSha256 $stdoutPath) -ceq
            [string]$declared.stdout_raw_sha256 -and
        (Get-R23D6ClosureRawSha256 $stderrPath) -ceq
            [string]$declared.stderr_raw_sha256 -and
        (Get-R23D6ClosureRawSha256 $terminalPath) -ceq
            [string]$expected.terminal -and
        [string]$declared.terminal_entry_raw_sha256 -ceq
            [string]$expected.terminal
    ) "QSDK-R23D6 retained Stage A bytes changed: $cellId"
    Assert-R23D6Closure (
        [string]$terminal.cell_id -ceq $cellId -and
        [string]$terminal.arm_id -ceq [string]$expected.arm -and
        [double]$terminal.turn_heading_offset_rad -eq [double]$expected.offset -and
        [bool]$processReceipt.process_launch_succeeded -and
        [int]$processReceipt.exit_code -eq 0 -and
        -not [bool]$processReceipt.timed_out -and
        [bool]$terminal.execution.integrity_passed -and
        [int]$terminal.execution.world_attempt_count -eq 1 -and
        [int]$terminal.execution.world_build_count -eq 1 -and
        [int]$terminal.trace_summary.row_count -eq 3772 -and
        [string]$terminal.trace_artifact.sha256 -ceq [string]$expected.trace -and
        $terminalLines.Count -eq 1
    ) "QSDK-R23D6 retained Stage A execution changed: $cellId"
    Assert-R23D6Closure (
        [double]$terminal.measurements.turn_phase_yaw_delta_rad -eq
            [double]$expected.yaw -and
        [int]$terminal.measurements.first_all_four_contact_restoration_step -eq
            [int]$expected.first_contact -and
        [int]$terminal.measurements.consecutive_all_four_contact_hold_step_count -eq
            [int]$expected.hold -and
        [int]$terminal.measurements.captured_pose_memory_transition_count -eq
            [int]$expected.pose -and
        [double]$terminal.measurements.maximum_tilt_rad -eq
            [double]$expected.maximum_tilt -and
        (@($evaluated.outcome.failed_gate_ids) -join "|") -ceq
            (@($expected.failed) -join "|") -and
        [bool]$evaluated.outcome.signed_yaw_response_passed -and
        -not [bool]$evaluated.outcome.walking_and_restoration_gate_passed -and
        -not [bool]$evaluated.outcome.outcome_gate_passed
    ) "QSDK-R23D6 retained Stage A outcome changed: $cellId"
    $tracePath = [string]$terminal.trace_artifact.payload_path
    Assert-R23D6Closure (
        (Get-R23D6ClosureRawSha256 $tracePath) -ceq [string]$expected.trace
    ) "QSDK-R23D6 trace CAS bytes changed: $cellId"
    $facts = Get-R23D6TraceFacts $tracePath
    Assert-R23D6Closure (
        [int]$facts.row_count -eq 3772 -and
        [int]$facts.counts.terminal_contact_acquisition."0111" -eq 180
    ) "QSDK-R23D6 acquisition trace changed: $cellId"
    if ($index -eq 0) {
        Assert-R23D6Closure (
            [int]$facts.counts.terminal_captured_pose_hold."0111" -eq 360 -and
            [int]$facts.counts.passive_zero_actuation_settle."0111" -eq 40 -and
            [int]$facts.counts.passive_zero_actuation_settle."1111" -eq 76 -and
            [int]$facts.counts.passive_zero_actuation_settle."1011" -eq 124
        ) "QSDK-R23D6 positive contact-mask trace changed"
    } else {
        Assert-R23D6Closure (
            [int]$facts.counts.terminal_captured_pose_hold."0111" -eq 66 -and
            [int]$facts.counts.terminal_captured_pose_hold."1111" -eq 294 -and
            [int]$facts.counts.passive_zero_actuation_settle."1111" -eq 24 -and
            [int]$facts.counts.passive_zero_actuation_settle."1011" -eq 167 -and
            [int]$facts.counts.passive_zero_actuation_settle."0011" -eq 49 -and
            [double]$facts.maximum_tilt_rad -eq 0.6773622329526434 -and
            [int]$facts.maximum_tilt_trace_step -eq 3771 -and
            [string]$facts.maximum_tilt_phase -ceq "passive_zero_actuation_settle"
        ) "QSDK-R23D6 negative contact-mask trace changed"
    }
}

$attestationPath = [string]$closure.full_godot_attestation.path
Assert-R23D6Closure (
    (Get-R23D6ClosureRawSha256 $attestationPath) -ceq
        [string]$closure.full_godot_attestation.raw_sha256
) "QSDK-R23D6 full-Godot attestation bytes changed"
$attestation = Get-Content -Raw -LiteralPath $attestationPath |
    ConvertFrom-Json -AsHashtable -Depth 100
Assert-R23D6Closure (
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
) "QSDK-R23D6 full-Godot attestation semantics changed"

foreach ($declaredBlob in @($closure.historical_source_blobs)) {
    $blob = Get-R23D6ClosureGitBlob `
        -Commit $sourceCommit `
        -Path ([string]$declaredBlob.path)
    Assert-R23D6Closure (
        [string]$blob.oid -ceq [string]$declaredBlob.git_blob_oid -and
        [int]$blob.byte_length -eq [int]$declaredBlob.byte_length -and
        [string]$blob.raw_sha256 -ceq [string]$declaredBlob.raw_sha256
    ) "QSDK-R23D6 historical source blob changed: $($declaredBlob.path)"
}
$restorerBlob = Get-R23D6ClosureGitBlob $sourceCommit (
    "sdk/adapters/mujoco/sporespore_mujoco_adapter/" +
    "qsdk_r23d6_policy_compatible_restoration.py"
)
$workerBlob = Get-R23D6ClosureGitBlob $sourceCommit (
    "sdk/adapters/mujoco/sporespore_mujoco_adapter/qsdk_r23d6_policy_compatible.py"
)
Assert-R23D6Closure (
    $restorerBlob.text.Contains("desired_foot_velocity = np.asarray(") -and
    $restorerBlob.text.Contains("[0.0, -DOWNWARD_SPEED_M_S, 0.0]") -and
    $restorerBlob.text.Contains("if not contact:") -and
    $workerBlob.text.Contains("for restoration_step in range(design.RESTORATION_STEPS)") -and
    $workerBlob.text.Contains("if restoration_step >= design.CONTACT_ACQUISITION_STEPS")
) "QSDK-R23D6 terminal-restoration diagnosis source changed"

$supervisorSource = Get-Content -Raw -LiteralPath $supervisorPath
$mujocoSource = Get-Content -Raw -LiteralPath (
    Join-Path $sdkRoot "adapters\mujoco\sporespore_mujoco_adapter\qsdk_r23d6_policy_compatible.py"
)
$rapierSource = Get-Content -Raw -LiteralPath (
    Join-Path $sdkRoot "adapters\rapier\src\qsdk_r23d3_phase_balanced.rs"
)
$godotSource = Get-Content -Raw -LiteralPath (
    Join-Path $repoRoot "tests\test_sdk_qsdk_r23d6_policy_compatible_godot_jolt_worker.gd"
)
Assert-R23D6Closure (
    $supervisorSource.Contains("r23d6_physical_closure_v1.json") -and
    $supervisorSource.Contains("QSDK-R23D6 CLOSED") -and
    $mujocoSource.Contains("QSDK_R23D6_MJC_CLOSED") -and
    $rapierSource.Contains("QSDK_R23D6_RAP_CLOSED") -and
    $godotSource.Contains("QSDK_R23D6_GJT_CLOSED")
) "QSDK-R23D6 closure interlocks changed"

$refusalOutput = (& pwsh `
    -NoLogo `
    -NoProfile `
    -File $supervisorPath `
    -RunPhysical `
    -FullConformanceAttestation "R23D6_CLOSED_CANARY_MUST_NOT_BE_READ" 2>&1 |
    Out-String)
Assert-R23D6Closure (
    $LASTEXITCODE -ne 0 -and
    $refusalOutput.Contains("QSDK-R23D6 CLOSED") -and
    $refusalOutput.Contains("rerun is forbidden") -and
    $refusalOutput.Contains('"world_attempt_count":0')
) "QSDK-R23D6 supervisor did not refuse the closed identity"
$global:LASTEXITCODE = 0

$conformanceSource = Get-Content -Raw -LiteralPath (
    Join-Path $sdkRoot "run_conformance.ps1"
)
Assert-R23D6Closure (
    $conformanceSource.Contains("test_qsdk_r23d6_closure.ps1") -and
    -not $conformanceSource.Contains(
        '& (Join-Path $repoRoot "tests\test_qsdk_r23d6_declaration.ps1")'
    ) -and
    -not $conformanceSource.Contains(
        '& (Join-Path $sdkRoot "run_qsdk_r23d6_mujoco_worker_preflight.ps1")'
    ) -and
    -not $conformanceSource.Contains(
        '& (Join-Path $sdkRoot "run_qsdk_r23d6_godot_jolt_worker_preflight.ps1")'
    )
) "QSDK-R23D6 canonical closure route changed"

Assert-R23D6Closure (
    [string]$closure.successor_boundary.successor_id -ceq "QSDK-R23D7" -and
    [bool]$closure.successor_boundary.new_campaign_and_gate_identity_required -and
    [bool]$closure.successor_boundary.scientifically_distinct_terminal_stance_policy_required -and
    [bool]$closure.successor_boundary.missing_front_foot_acquisition_mechanism_must_be_preflighted -and
    [bool]$closure.successor_boundary.passive_stability_handoff_must_be_preflighted -and
    -not [bool]$closure.claims.scientific_positive -and
    [bool]$closure.claims.scientific_negative -and
    [bool]$closure.claims.signed_yaw_response_observed_in_both_stage_a_cells -and
    -not [bool]$closure.claims.command_conditioned_turning -and
    -not [bool]$closure.claims.cross_engine_equivalence -and
    -not [bool]$closure.claims.release_authorized -and
    -not [bool]$closure.claims.physical_acceptance_authority
) "QSDK-R23D6 closure claims changed"

Write-Host (
    "QSDK_R23D6_CLOSURE_PASS status=valid-none-stage-a worlds=2 stage_a=2/2 " +
    "signed_yaw=2/2 selected=NONE stage_b=0 mechanism=terminal-restoration " +
    "turning=False equivalence=False rerun_refused=True physical_authority=False"
)
