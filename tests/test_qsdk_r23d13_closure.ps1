#requires -Version 7.0

[CmdletBinding()]
param(
    [string]$EvidenceRoot = (
        "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence\" +
        "qsdk-r23d13-22836253-20260810T102836Z"
    )
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$sdkRoot = Join-Path $repoRoot "sdk"
$closurePath = Join-Path $sdkRoot "turning\r23d13_physical_closure_v1.json"
$artifactStorePath = Join-Path $sdkRoot "content_addressed_artifact_store.ps1"
$campaignId = (
    "QSDK-R23D13-RESIDUAL-POSE-AUTHORITY-QUIESCENT-TAPER-" +
    "BILATERAL-TURN-DEVELOPMENT"
)
$gateId = "QSDK-R23D13"
$sourceCommit = "2283625319c1d082082f584d288511d403608952"
$sourceTree = "891455b0665c44043698cbee9539a5c4be35df65"
$emptySha256 = (
    "sha256:e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
)

. $artifactStorePath

function Assert-R23D13Closure {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function Get-R23D13ClosureRawSha256 {
    param([Parameter(Mandatory)][string]$Path)
    return "sha256:" + (
        Get-FileHash -LiteralPath $Path -Algorithm SHA256
    ).Hash.ToLowerInvariant()
}

function Get-R23D13ClosureBytesSha256 {
    param([Parameter(Mandatory)][byte[]]$Bytes)
    return "sha256:" + [Convert]::ToHexString(
        [Security.Cryptography.SHA256]::HashData($Bytes)
    ).ToLowerInvariant()
}

function Get-R23D13ClosureEvidenceTree {
    param([Parameter(Mandatory)][string]$Root)
    $files = @(Get-ChildItem -LiteralPath $Root -File -Recurse | Sort-Object {
        $_.FullName.Substring($Root.Length + 1).Replace("\", "/")
    })
    $lines = @($files | ForEach-Object {
        $relative = $_.FullName.Substring($Root.Length + 1).Replace("\", "/")
        "{0}`t{1}`t{2}" -f $relative, $_.Length, (
            Get-R23D13ClosureRawSha256 $_.FullName
        ).Substring(7)
    })
    $projection = [Text.Encoding]::UTF8.GetBytes(($lines -join "`n") + "`n")
    return [ordered]@{
        files = $files
        file_count = $files.Count
        total_byte_length = [int64](($files | Measure-Object Length -Sum).Sum)
        raw_sha256 = Get-R23D13ClosureBytesSha256 $projection
    }
}

function Test-R23D13ClosureCasArtifact {
    param(
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

function Assert-R23D13ClosureFile {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$ExpectedSha256,
        [Parameter(Mandatory)][string]$Label
    )
    Assert-R23D13Closure (Test-Path -LiteralPath $Path -PathType Leaf) (
        "QSDK-R23D13 retained file is missing: $Label"
    )
    $item = Get-Item -LiteralPath $Path
    Assert-R23D13Closure (
        (Get-R23D13ClosureRawSha256 $Path) -ceq $ExpectedSha256 -and
        (Test-R23D13ClosureCasArtifact `
            -ExpectedSha256 $ExpectedSha256 `
            -ExpectedByteLength ([long]$item.Length))
    ) "QSDK-R23D13 retained file or CAS object changed: $Label"
}

Assert-R23D13Closure (
    (git -C $repoRoot rev-parse --show-toplevel).Replace("/", "\") -ceq
        $repoRoot -and
    (git -C $repoRoot remote get-url origin) -ceq
        "https://github.com/Slagathore/sporespore.git"
) "QSDK-R23D13 closure repository identity mismatch"
Assert-R23D13Closure (
    (git -C $repoRoot rev-parse ($sourceCommit + "^{tree}")) -ceq $sourceTree
) "QSDK-R23D13 frozen source tree is unavailable"
Assert-R23D13Closure (Test-Path -LiteralPath $closurePath -PathType Leaf) (
    "QSDK-R23D13 closure is missing"
)
Assert-R23D13Closure (Test-Path -LiteralPath $EvidenceRoot -PathType Container) (
    "QSDK-R23D13 retained attempt root is missing"
)

$closure = Get-Content -Raw -LiteralPath $closurePath |
    ConvertFrom-Json -AsHashtable -Depth 100
Assert-R23D13Closure (
    [string]$closure.schema_version -ceq
        "sporespore_qsdk_r23d13_physical_development_closure_v1" -and
    [string]$closure.status -ceq (
        "closed_consumed_valid_none_stage_a_negative_heading_" +
        "quiescent_taper_failure"
    ) -and
    [string]$closure.campaign_id -ceq $campaignId -and
    [string]$closure.gate_id -ceq $gateId -and
    [string]$closure.source_identity.commit -ceq $sourceCommit -and
    [string]$closure.source_identity.tree_git_oid -ceq $sourceTree -and
    [int]$closure.source_identity.declared_source_binding_count -eq 115 -and
    [int]$closure.source_identity.runtime_artifact_count -eq 3 -and
    [int]$closure.source_identity.external_runtime_binding_count -eq 4 -and
    [int]$closure.source_identity.declared_worker_dependency_count -eq 61
) "QSDK-R23D13 closure identity changed"

$tree = Get-R23D13ClosureEvidenceTree -Root $EvidenceRoot
Assert-R23D13Closure (
    $tree.file_count -eq [int]$closure.attempt.evidence_file_count -and
    $tree.total_byte_length -eq [int64]$closure.attempt.evidence_total_byte_length -and
    [string]$tree.raw_sha256 -ceq
        [string]$closure.attempt.evidence_tree_raw_sha256
) "QSDK-R23D13 retained evidence tree changed"
foreach ($file in @($tree.files)) {
    $sha256 = Get-R23D13ClosureRawSha256 $file.FullName
    Assert-R23D13Closure (
        Test-R23D13ClosureCasArtifact `
            -ExpectedSha256 $sha256 `
            -ExpectedByteLength ([long]$file.Length)
    ) "QSDK-R23D13 attempt file is not retained in CAS: $($file.FullName)"
}

$attestationPath = [string]$closure.full_godot_attestation.path
Assert-R23D13ClosureFile `
    -Path $attestationPath `
    -ExpectedSha256 ([string]$closure.full_godot_attestation.raw_sha256) `
    -Label "full-Godot attestation"
$attestation = Get-Content -Raw -LiteralPath $attestationPath |
    ConvertFrom-Json -AsHashtable -Depth 100
Assert-R23D13Closure (
    [string]$attestation.schema_version -ceq
        "sporespore_full_godot_conformance_attestation_v2" -and
    [string]$attestation.status -ceq "full_godot_conformance_passed" -and
    [string]$attestation.source.commit -ceq $sourceCommit -and
    [string]$attestation.source.tree_git_oid -ceq $sourceTree -and
    [bool]$attestation.source.clean_pushed_live -and
    [bool]$attestation.conformance.godot_including -and
    [double]$attestation.conformance.duration_seconds -eq
        [double]$closure.full_godot_attestation.duration_seconds -and
    @($attestation.claims.Values | Where-Object { [bool]$_ }).Count -eq 0
) "QSDK-R23D13 full-Godot attestation changed"

$freezePath = Join-Path $EvidenceRoot "physical-freeze.json"
$authorizationPath = Join-Path $EvidenceRoot "stage-a-authorization.json"
$reportPath = Join-Path $EvidenceRoot "report.json"
$completionPath = Join-Path $EvidenceRoot "completion.json"
foreach ($receipt in @(
    @{ path = $freezePath; digest = $closure.attempt.physical_freeze_raw_sha256; label = "freeze" },
    @{ path = $authorizationPath; digest = $closure.attempt.stage_a_authorization_raw_sha256; label = "authorization" },
    @{ path = Join-Path $EvidenceRoot "stage-a-terminal-paths.json"; digest = $closure.attempt.stage_a_manifest_raw_sha256; label = "Stage A manifest" },
    @{ path = Join-Path $EvidenceRoot "stage-b-terminal-paths.json"; digest = $closure.attempt.stage_b_manifest_raw_sha256; label = "Stage B manifest" },
    @{ path = $reportPath; digest = $closure.attempt.report_raw_sha256; label = "report" },
    @{ path = $completionPath; digest = $closure.attempt.completion_raw_sha256; label = "completion" }
)) {
    Assert-R23D13ClosureFile `
        -Path ([string]$receipt.path) `
        -ExpectedSha256 ([string]$receipt.digest) `
        -Label ([string]$receipt.label)
}

$freeze = Get-Content -Raw -LiteralPath $freezePath |
    ConvertFrom-Json -AsHashtable -Depth 100
$authorization = Get-Content -Raw -LiteralPath $authorizationPath |
    ConvertFrom-Json -AsHashtable -Depth 100
$report = Get-Content -Raw -LiteralPath $reportPath |
    ConvertFrom-Json -AsHashtable -Depth 100
$completion = Get-Content -Raw -LiteralPath $completionPath |
    ConvertFrom-Json -AsHashtable -Depth 100
$canaries = $freeze.production_authorization_canaries
Assert-R23D13Closure (
    [string]$freeze.schema_version -ceq
        "sporespore_qsdk_r23d13_physical_freeze_v1" -and
    [string]$freeze.source_commit -ceq $sourceCommit -and
    [string]$freeze.source_tree_git_oid -ceq $sourceTree -and
    @($freeze.source_bindings).Count -eq 115 -and
    @($freeze.runtime_artifacts).Count -eq 3 -and
    @($freeze.external_runtime_bindings).Count -eq 4 -and
    @($freeze.content_addressed_inputs.source_bindings).Count -eq 115 -and
    [bool]$freeze.production_authorization_canaries_valid -and
    [bool]$freeze.complete_zero_world_gate_passed -and
    [bool]$freeze.physical_execution_authorized -and
    -not [bool]$freeze.physical_acceptance_authority -and
    [int]$canaries.engine_count -eq 3 -and
    [int]$canaries.worker_process_launch_count -eq 6 -and
    [int]$canaries.actual_production_authorization_function_execution_count -eq 6 -and
    [int]$canaries.positive_authorization_canary_count -eq 3 -and
    [int]$canaries.mutated_binding_refusal_canary_count -eq 3 -and
    [int]$canaries.content_addressed_input_count -eq 61 -and
    [int]$canaries.model_construction_count -eq 0 -and
    [int]$canaries.world_build_count -eq 0 -and
    [bool]$canaries.test_only_evidence_root_deleted
) "QSDK-R23D13 physical freeze or authorization canaries changed"
Assert-R23D13Closure (
    [string]$authorization.schema_version -ceq
        "sporespore_qsdk_r23d13_attempt_v1" -and
    [string]$authorization.stage_authorization_id -ceq "stage_a" -and
    [string]$authorization.attempt_id -ceq [string]$closure.attempt.attempt_id -and
    [string]$authorization.source_commit -ceq $sourceCommit -and
    [string]$authorization.full_godot_attestation_sha256 -ceq
        [string]$closure.full_godot_attestation.raw_sha256 -and
    [bool]$authorization.physical_execution_authorized -and
    [bool]$authorization.single_use_supervisor_authorization -and
    [bool]$authorization.one_shot_attempt_unconsumed -and
    @($authorization.ordered_stage_a_cell_ids).Count -eq 2 -and
    @($authorization.ordered_stage_b_cell_ids).Count -eq 0 -and
    -not [bool]$authorization.replacement_or_selective_rerun_permitted
) "QSDK-R23D13 Stage A authorization changed"
Assert-R23D13Closure (
    [string]$completion.status -ceq "valid_none_stage_a_first_attempt" -and
    [string]$completion.source_commit -ceq $sourceCommit -and
    [string]$completion.attempt_id -ceq [string]$closure.attempt.attempt_id -and
    [string]$completion.selected_terminal_policy_id -ceq "NONE" -and
    [string]$completion.result_classification -ceq "valid_none_stage_a" -and
    [int]$completion.stage_a_terminal_entry_count -eq 2 -and
    [int]$completion.stage_b_terminal_entry_count -eq 0 -and
    [bool]$completion.one_shot_identity_consumed -and
    -not [bool]$completion.same_identity_rerun_allowed -and
    -not [bool]$completion.command_conditioned_turning -and
    -not [bool]$completion.q_sdk_r23_satisfied -and
    -not [bool]$completion.cross_engine_equivalence -and
    -not [bool]$completion.release_authorized
) "QSDK-R23D13 immutable completion changed"
Assert-R23D13Closure (
    [string]$report.schema_version -ceq
        "sporespore_qsdk_r23d13_campaign_report_v1" -and
    [string]$report.result_classification -ceq "valid_none_stage_a" -and
    [bool]$report.development_result_valid -and
    [string]$report.selected_terminal_policy_id -ceq "NONE" -and
    -not [bool]$report.stage_b_launched -and
    [int]$report.stage_a_world_count -eq 2 -and
    [int]$report.stage_b_world_count -eq 0 -and
    @($report.ordered_stage_a_cells).Count -eq 2 -and
    @($report.ordered_stage_b_cells).Count -eq 0 -and
    [string]$report.stage_a_evaluation.classification -ceq
        "valid_none_stage_a" -and
    [string]$report.complete_evaluation.classification -ceq
        "valid_none_stage_a" -and
    $null -eq $report.complete_evaluation.stage_b
) "QSDK-R23D13 retained campaign report changed"

for ($index = 0; $index -lt @($closure.retained_stage_a_cells).Count; $index++) {
    $expected = $closure.retained_stage_a_cells[$index]
    $cellId = [string]$expected.cell_id
    $cellRoot = Join-Path $EvidenceRoot "stage-a\$cellId"
    foreach ($receipt in @(
        @{ path = Join-Path $cellRoot "process.json"; digest = $expected.process_raw_sha256; label = "process" },
        @{ path = Join-Path $cellRoot "stdout.txt"; digest = $expected.stdout_raw_sha256; label = "stdout" },
        @{ path = Join-Path $cellRoot "stderr.txt"; digest = $expected.stderr_raw_sha256; label = "stderr" },
        @{ path = Join-Path $cellRoot "terminal-entry.json"; digest = $expected.terminal_entry_raw_sha256; label = "terminal" }
    )) {
        Assert-R23D13ClosureFile `
            -Path ([string]$receipt.path) `
            -ExpectedSha256 ([string]$receipt.digest) `
            -Label "$cellId $([string]$receipt.label)"
    }
    $tracePath = Join-Path $EvidenceRoot (
        "traces\mujoco_residual_pose_authority_screen__$cellId.ndjson"
    )
    Assert-R23D13ClosureFile `
        -Path $tracePath `
        -ExpectedSha256 ([string]$expected.trace_raw_sha256) `
        -Label "$cellId trace"
    $terminal = Get-Content -Raw -LiteralPath (
        Join-Path $cellRoot "terminal-entry.json"
    ) | ConvertFrom-Json -AsHashtable -Depth 100
    $process = Get-Content -Raw -LiteralPath (Join-Path $cellRoot "process.json") |
        ConvertFrom-Json -AsHashtable -Depth 100
    $measurement = $terminal.measurements
    $authority = $terminal.trace_summary.authority_outcome
    $evaluation = $report.stage_a_evaluation.cell_evaluations[$index]
    Assert-R23D13Closure (
        [string]$terminal.cell_id -ceq $cellId -and
        [bool]$terminal.execution.integrity_passed -and
        [int]$terminal.execution.world_attempt_count -eq 1 -and
        [int]$terminal.execution.world_build_count -eq 1 -and
        [int]$terminal.trace_summary.row_count -eq 3892 -and
        [string]$terminal.trace_artifact.sha256 -ceq
            [string]$expected.trace_raw_sha256 -and
        [int]$process.exit_code -eq 0 -and
        -not [bool]$process.timed_out -and
        [double]$process.duration_seconds -eq
            [double]$expected.process_duration_seconds -and
        [double]$measurement.turn_phase_yaw_delta_rad -eq
            [double]$expected.turn_phase_yaw_delta_rad -and
        [double]$measurement.final_forward_displacement_m -eq
            [double]$expected.final_forward_displacement_m -and
        [int]$measurement.active_terminal_step_count -eq
            [int]$expected.active_terminal_step_count -and
        [int]$measurement.passive_terminal_step_count -eq
            [int]$expected.passive_zero_actuation_step_count -and
        [bool]$measurement.confirmation_satisfied -eq
            [bool]$expected.confirmation_satisfied -and
        [string]$measurement.handoff_reason -ceq
            [string]$expected.handoff_reason -and
        [int]$measurement.post_handoff_contact_loss_step_count -eq
            [int]$expected.post_handoff_contact_loss_step_count -and
        [int]$measurement.post_handoff_native_actuation_application_count -eq 0 -and
        [int]$authority.pose_floor_dominant_row_count -eq
            [int]$expected.pose_floor_dominant_row_count -and
        [int]$authority.maximum_authority_numerator_increase -eq
            [int]$expected.maximum_authority_numerator_increase -and
        [bool]$evaluation.entry_valid -and
        [bool]$evaluation.execution_integrity_passed -and
        [bool]$evaluation.outcome.signed_yaw_response_passed -and
        [bool]$evaluation.outcome.outcome_gate_passed -eq
            [bool]$expected.outcome_gate_passed
    ) "QSDK-R23D13 retained cell changed: $cellId"
}

$positive = $closure.retained_stage_a_cells[0]
$negative = $closure.retained_stage_a_cells[1]
$negativeTrace = Join-Path $EvidenceRoot (
    "traces\mujoco_residual_pose_authority_screen__" +
    "mujoco__residual_pose_authority__negative_heading.ndjson"
)
$negativeTerminalRows = @(
    Get-Content -LiteralPath $negativeTrace |
        Select-Object -Skip 2992 |
        ForEach-Object { $_ | ConvertFrom-Json -Depth 50 }
)
$negativeActive = @($negativeTerminalRows | Where-Object {
    -not [bool]$_.zero_actuation
})
$negativeMinimumTilt = [double](
    ($negativeActive | Measure-Object torso_tilt_rad -Minimum).Minimum
)
$negativeMinimumJointError = [double](
    ($negativeActive |
        Measure-Object maximum_absolute_joint_position_error_rad -Minimum).Minimum
)
$negativeTightRows = @($negativeTerminalRows | Where-Object {
    [bool]$_.tight_pose_satisfied
})
$negativeCoarseRows = @($negativeTerminalRows | Where-Object {
    [bool]$_.coarse_pose_satisfied
})
$negativePoseFloorRows = @($negativeActive | Where-Object {
    [int]$_.pose_authority_floor_numerator -gt
        [int]$_.temporal_scale_numerator
})
$lastNegativeActive = $negativeActive[-1]
Assert-R23D13Closure (
    [bool]$positive.outcome_gate_passed -and
    [bool]$positive.confirmation_satisfied -and
    [int]$positive.post_handoff_contact_loss_step_count -eq 0 -and
    -not [bool]$negative.outcome_gate_passed -and
    -not [bool]$negative.confirmation_satisfied -and
    [string]$negative.handoff_reason -ceq
        "deadline_forced_without_quiescence_confirmation" -and
    [int]$negative.active_terminal_step_count -eq 540 -and
    [int]$negative.first_post_handoff_contact_loss_step -eq 699 -and
    [int]$negative.post_handoff_contact_loss_step_count -eq 43 -and
    $negativeMinimumTilt -eq [double]$negative.minimum_active_tilt_rad -and
    $negativeMinimumJointError -eq
        [double]$negative.minimum_active_joint_position_error_rad -and
    $negativeTightRows.Count -eq 0 -and
    $negativeCoarseRows.Count -eq 390 -and
    $negativePoseFloorRows.Count -eq 133 -and
    @($lastNegativeActive.ordered_foot_contacts.psobject.Properties |
        Where-Object { [bool]$_.Value }).Count -eq 4 -and
    @($negative.failed_gate_ids).Count -eq 1 -and
    [string]$negative.failed_gate_ids[0] -ceq "R23D13_QUIESCENT_TAPER" -and
    [bool]$positive.signed_yaw_response_passed -and
    [bool]$negative.signed_yaw_response_passed
) "QSDK-R23D13 valid-negative mechanism changed"

foreach ($kind in @("stage_a", "complete")) {
    $relative = if ($kind -ceq "stage_a") { "stage-a-evaluator" } else {
        "complete-evaluator"
    }
    $declared = $closure.retained_evaluators[$kind]
    foreach ($receipt in @(
        @{ name = "evaluation.json"; digest = $declared.evaluation_raw_sha256 },
        @{ name = "process.json"; digest = $declared.process_raw_sha256 },
        @{ name = "stdout.txt"; digest = $declared.stdout_raw_sha256 },
        @{ name = "stderr.txt"; digest = $declared.stderr_raw_sha256 }
    )) {
        Assert-R23D13ClosureFile `
            -Path (Join-Path $EvidenceRoot "$relative\$([string]$receipt.name)") `
            -ExpectedSha256 ([string]$receipt.digest) `
            -Label "$kind evaluator $([string]$receipt.name)"
    }
    Assert-R23D13Closure ([int]$declared.process_exit_code -eq 0) (
        "QSDK-R23D13 evaluator exit changed: $kind"
    )
}
$stageAStdout = Get-Content -Raw -LiteralPath (
    Join-Path $EvidenceRoot "stage-a-evaluator\stdout.txt"
)
$completeStdout = Get-Content -Raw -LiteralPath (
    Join-Path $EvidenceRoot "complete-evaluator\stdout.txt"
)
Assert-R23D13Closure (
    @($stageAStdout -split "`r?`n" | Where-Object {
        $_.StartsWith("QSDK_R23D13_STAGE_A_EVALUATION ")
    }).Count -eq 1 -and
    @($completeStdout -split "`r?`n" | Where-Object {
        $_.StartsWith("QSDK_R23D13_COMPLETE_EVALUATION ")
    }).Count -eq 1
) "QSDK-R23D13 evaluator producer/consumer markers changed"

$supervisorText = Get-Content -Raw -LiteralPath (
    Join-Path $sdkRoot "run_qsdk_r23d13_supervisor.ps1"
)
$mujocoText = Get-Content -Raw -LiteralPath (
    Join-Path $sdkRoot (
        "adapters\mujoco\sporespore_mujoco_adapter\" +
        "qsdk_r23d13_residual_pose_authority_physical.py"
    )
)
$rapierText = Get-Content -Raw -LiteralPath (
    Join-Path $sdkRoot (
        "adapters\rapier\src\qsdk_r23d3_phase_balanced\r23d13_physical.rs"
    )
)
$godotText = Get-Content -Raw -LiteralPath (
    Join-Path $repoRoot (
        "tests\test_sdk_qsdk_r23d13_residual_pose_authority_" +
        "godot_jolt_physical_worker.gd"
    )
)
$conformanceText = Get-Content -Raw -LiteralPath (
    Join-Path $sdkRoot "run_conformance.ps1"
)
Assert-R23D13Closure (
    $supervisorText.Contains("r23d13_physical_closure_v1.json") -and
    $supervisorText.Contains("QSDK-R23D13 CLOSED") -and
    $mujocoText.Contains("r23d13_physical_closure_v1.json") -and
    $mujocoText.Contains("QSDK_R23D13_MJC_CLOSED") -and
    $rapierText.Contains("r23d13_physical_closure_v1.json") -and
    $rapierText.Contains("QSDK_R23D13_RAP_CLOSED") -and
    $godotText.Contains("r23d13_physical_closure_v1.json") -and
    $godotText.Contains("QSDK_R23D13_GJT_CLOSED") -and
    $conformanceText.Contains("tests\test_qsdk_r23d13_closure.ps1") -and
    -not $conformanceText.Contains("run_qsdk_r23d13_zero_world_gate.ps1")
) "QSDK-R23D13 physical closure routing changed"

$priorAttemptRoots = @(
    Get-ChildItem -LiteralPath (Split-Path -Parent $EvidenceRoot) -Directory |
        Where-Object {
            $_.Name.StartsWith("qsdk-r23d13-", [StringComparison]::Ordinal) -and
            (Test-Path -LiteralPath (Join-Path $_.FullName "completion.json"))
        }
)
$sameIdentityRefusal = @(
    & pwsh -NoLogo -NoProfile -File (
        Join-Path $sdkRoot "run_qsdk_r23d13_supervisor.ps1"
    ) `
        -RunPhysical `
        -FullConformanceAttestation $attestationPath `
        2>&1
)
$sameIdentityExitCode = $LASTEXITCODE
$sameIdentityText = @($sameIdentityRefusal | ForEach-Object { [string]$_ }) -join "`n"
$afterAttemptRoots = @(
    Get-ChildItem -LiteralPath (Split-Path -Parent $EvidenceRoot) -Directory |
        Where-Object {
            $_.Name.StartsWith("qsdk-r23d13-", [StringComparison]::Ordinal) -and
            (Test-Path -LiteralPath (Join-Path $_.FullName "completion.json"))
        }
)
Assert-R23D13Closure (
    $sameIdentityExitCode -ne 0 -and
    $sameIdentityText.Contains("QSDK_R23D13_PHYSICAL_REFUSAL") -and
    $sameIdentityText.Contains('"reason":"r23d13_identity_closed"') -and
    $sameIdentityText.Contains("QSDK-R23D13 CLOSED") -and
    $priorAttemptRoots.Count -eq 1 -and
    $afterAttemptRoots.Count -eq 1 -and
    $afterAttemptRoots[0].FullName -ceq $priorAttemptRoots[0].FullName
) "QSDK-R23D13 same-identity refusal changed"

Assert-R23D13Closure (
    [bool]$closure.immutable_completion_record.scientific_negative -and
    -not [bool]$closure.immutable_completion_record.scientific_positive -and
    [bool]$closure.post_series_process_pause.pause_required -and
    [bool]$closure.post_series_process_pause.pause_active_after_closure -and
    $null -eq $closure.post_series_process_pause.successor_gate_id -and
    $null -eq $closure.post_series_process_pause.successor_campaign_id -and
    -not [bool]$closure.post_series_process_pause.successor_design_authorized -and
    -not [bool]$closure.post_series_process_pause.successor_preregistration_authorized -and
    -not [bool]$closure.post_series_process_pause.successor_physical_series_authorized -and
    [bool]$closure.post_series_process_pause.process_changes_required_before_any_successor -and
    [bool]$closure.scientific_observation_boundary.negative_pose_authority_floor_engaged -and
    -not [bool]$closure.claims.command_conditioned_turning -and
    -not [bool]$closure.claims.bilateral_signed_turning -and
    -not [bool]$closure.claims.portable_basic_turning -and
    -not [bool]$closure.claims.cross_engine_equivalence -and
    -not [bool]$closure.claims.q_sdk_r23_satisfied -and
    -not [bool]$closure.claims.prone_to_standing -and
    -not [bool]$closure.claims.release_authorized -and
    -not [bool]$closure.claims.physical_acceptance_authority
) "QSDK-R23D13 claim or pause boundary changed"

# The same-identity negative control intentionally exits nonzero. Preserve its
# observed refusal, then clear native command status for dot-invoking callers.
$global:LASTEXITCODE = 0

Write-Host (
    "QSDK_R23D13_CLOSURE_PASS status=valid-none worlds=2 " +
    "traces=2 rows=7784 yaw_signed=2/2 taper=1/2 pose_floor_rows=133 " +
    "selected=NONE stage_b=0/9 evidence_files=$($tree.file_count) " +
    "retained_cas=27 same_identity_refusal=1 same_identity_rerun=False " +
    "successor_authorized=False pause=True turning=False equivalence=False " +
    "physical_authority=False"
)
