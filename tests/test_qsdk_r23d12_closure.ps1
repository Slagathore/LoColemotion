#requires -Version 7.0

[CmdletBinding()]
param(
    [string]$EvidenceRoot = (
        "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence\" +
        "qsdk-r23d12-662763fc-20260810T022631Z"
    )
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$sdkRoot = Join-Path $repoRoot "sdk"
$closurePath = Join-Path $sdkRoot "turning\r23d12_physical_closure_v1.json"
$artifactStorePath = Join-Path $sdkRoot "content_addressed_artifact_store.ps1"
$campaignId = (
    "QSDK-R23D12-INDEPENDENT-PLANNER-AND-SUPPORT-MARGIN-SEMANTICS-" +
    "BILATERAL-TURN-DEVELOPMENT"
)
$gateId = "QSDK-R23D12"
$sourceCommit = "662763fc4eab164c56dbc06bd76e3cd618dd8515"
$sourceTree = "6a0306215da03c5f74aba27c6c53dfbe569d1911"
$emptySha256 = (
    "sha256:e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
)

. $artifactStorePath

function Assert-R23D12Closure {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function Get-R23D12ClosureRawSha256 {
    param([Parameter(Mandatory)][string]$Path)
    return "sha256:" + (
        Get-FileHash -LiteralPath $Path -Algorithm SHA256
    ).Hash.ToLowerInvariant()
}

function Get-R23D12ClosureBytesSha256 {
    param([Parameter(Mandatory)][byte[]]$Bytes)
    return "sha256:" + [Convert]::ToHexString(
        [Security.Cryptography.SHA256]::HashData($Bytes)
    ).ToLowerInvariant()
}

function Get-R23D12ClosureEvidenceTree {
    param([Parameter(Mandatory)][string]$Root)
    $files = @(Get-ChildItem -LiteralPath $Root -File -Recurse | Sort-Object {
        $_.FullName.Substring($Root.Length + 1).Replace("\", "/")
    })
    $lines = @($files | ForEach-Object {
        $relative = $_.FullName.Substring($Root.Length + 1).Replace("\", "/")
        "{0}`t{1}`t{2}" -f $relative, $_.Length, (
            Get-R23D12ClosureRawSha256 $_.FullName
        ).Substring(7)
    })
    $projection = [Text.Encoding]::UTF8.GetBytes(($lines -join "`n") + "`n")
    return [ordered]@{
        files = $files
        file_count = $files.Count
        total_byte_length = [int64](($files | Measure-Object Length -Sum).Sum)
        raw_sha256 = Get-R23D12ClosureBytesSha256 $projection
    }
}

function Test-R23D12ClosureCasArtifact {
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

function Assert-R23D12ClosureFile {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$ExpectedSha256,
        [Parameter(Mandatory)][string]$Label
    )
    Assert-R23D12Closure (Test-Path -LiteralPath $Path -PathType Leaf) (
        "QSDK-R23D12 retained file is missing: $Label"
    )
    $item = Get-Item -LiteralPath $Path
    Assert-R23D12Closure (
        (Get-R23D12ClosureRawSha256 $Path) -ceq $ExpectedSha256 -and
        (Test-R23D12ClosureCasArtifact `
            -ExpectedSha256 $ExpectedSha256 `
            -ExpectedByteLength ([long]$item.Length))
    ) "QSDK-R23D12 retained file or CAS object changed: $Label"
}

Assert-R23D12Closure (
    (git -C $repoRoot rev-parse --show-toplevel).Replace("/", "\") -ceq
        $repoRoot -and
    (git -C $repoRoot remote get-url origin) -ceq
        "https://github.com/Slagathore/sporespore.git"
) "QSDK-R23D12 closure repository identity mismatch"
Assert-R23D12Closure (
    (git -C $repoRoot rev-parse ($sourceCommit + "^{tree}")) -ceq $sourceTree
) "QSDK-R23D12 frozen source tree is unavailable"
Assert-R23D12Closure (Test-Path -LiteralPath $closurePath -PathType Leaf) (
    "QSDK-R23D12 closure is missing"
)
Assert-R23D12Closure (Test-Path -LiteralPath $EvidenceRoot -PathType Container) (
    "QSDK-R23D12 retained attempt root is missing"
)

$closure = Get-Content -Raw -LiteralPath $closurePath |
    ConvertFrom-Json -AsHashtable -Depth 100
Assert-R23D12Closure (
    [string]$closure.schema_version -ceq
        "sporespore_qsdk_r23d12_physical_development_closure_v1" -and
    [string]$closure.status -ceq (
        "closed_consumed_valid_none_stage_a_negative_heading_" +
        "quiescent_taper_failure"
    ) -and
    [string]$closure.campaign_id -ceq $campaignId -and
    [string]$closure.gate_id -ceq $gateId -and
    [string]$closure.source_identity.commit -ceq $sourceCommit -and
    [string]$closure.source_identity.tree_git_oid -ceq $sourceTree -and
    [int]$closure.source_identity.declared_source_binding_count -eq 108 -and
    [int]$closure.source_identity.runtime_artifact_count -eq 3 -and
    [int]$closure.source_identity.external_runtime_binding_count -eq 4 -and
    [int]$closure.source_identity.declared_worker_dependency_count -eq 58 -and
    -not [bool]$closure.source_identity.controller_or_physics_changed_by_post_push_authority_closure
) "QSDK-R23D12 closure identity changed"

$keyDigests = [ordered]@{
    "physical-freeze.json" = $closure.attempt.physical_freeze_raw_sha256
    "stage-a-authorization.json" = $closure.attempt.stage_a_authorization_raw_sha256
    "stage-a-terminal-paths.json" = $closure.attempt.stage_a_manifest_raw_sha256
    "stage-b-terminal-paths.json" = $closure.attempt.stage_b_manifest_raw_sha256
    "report.json" = $closure.attempt.report_raw_sha256
    "completion.json" = $closure.attempt.completion_raw_sha256
    "stage-a-evaluator/evaluation.json" = $closure.attempt.stage_a_evaluation_raw_sha256
    "complete-evaluator/evaluation.json" = $closure.attempt.complete_evaluation_raw_sha256
}
foreach ($item in $keyDigests.GetEnumerator()) {
    Assert-R23D12ClosureFile `
        -Path (Join-Path $EvidenceRoot $item.Key) `
        -ExpectedSha256 ([string]$item.Value) `
        -Label $item.Key
}

$tree = Get-R23D12ClosureEvidenceTree $EvidenceRoot
Assert-R23D12Closure (
    [int]$tree.file_count -eq [int]$closure.attempt.evidence_file_count -and
    [int64]$tree.total_byte_length -eq
        [int64]$closure.attempt.evidence_total_byte_length -and
    [string]$tree.raw_sha256 -ceq
        [string]$closure.attempt.evidence_tree_raw_sha256
) "QSDK-R23D12 retained evidence tree changed"
foreach ($file in @($tree.files)) {
    $sha256 = Get-R23D12ClosureRawSha256 $file.FullName
    Assert-R23D12Closure (
        Test-R23D12ClosureCasArtifact `
            -ExpectedSha256 $sha256 `
            -ExpectedByteLength ([long]$file.Length)
    ) (
        "QSDK-R23D12 retained evidence CAS object changed: " +
        $file.FullName.Substring($EvidenceRoot.Length + 1)
    )
}

$externalFiles = @(
    @{ path = [string]$closure.full_godot_attestation.path; digest = [string]$closure.full_godot_attestation.raw_sha256; bytes = [long]$closure.full_godot_attestation.byte_length; label = "attestation" },
    @{ path = [string]$closure.full_godot_attestation.conformance_log_path; digest = [string]$closure.full_godot_attestation.conformance_log_raw_sha256; bytes = [long]$closure.full_godot_attestation.conformance_log_byte_length; label = "conformance log" },
    @{ path = [string]$closure.production_authorization_canaries.standalone_log_path; digest = [string]$closure.production_authorization_canaries.standalone_log_raw_sha256; bytes = [long]$closure.production_authorization_canaries.standalone_log_byte_length; label = "authorization-canary log" },
    @{ path = [string]$closure.attempt.supervisor_log_path; digest = [string]$closure.attempt.supervisor_log_raw_sha256; bytes = [long]$closure.attempt.supervisor_log_byte_length; label = "supervisor log" }
)
foreach ($record in $externalFiles) {
    Assert-R23D12ClosureFile `
        -Path ([string]$record.path) `
        -ExpectedSha256 ([string]$record.digest) `
        -Label ([string]$record.label)
    Assert-R23D12Closure (
        (Get-Item -LiteralPath ([string]$record.path)).Length -eq
            [long]$record.bytes
    ) "QSDK-R23D12 retained external length changed: $([string]$record.label)"
}
Assert-R23D12Closure (
    [int]$closure.post_attempt_retention_completion.retained_file_count -eq 30 -and
    [int]$closure.post_attempt_retention_completion.already_content_addressed_file_count -eq 25 -and
    [int]$closure.post_attempt_retention_completion.new_content_addressed_file_count -eq 5 -and
    [bool]$closure.post_attempt_retention_completion.all_retained_files_content_addressed -and
    -not [bool]$closure.post_attempt_retention_completion.attempt_tree_bytes_changed -and
    -not [bool]$closure.post_attempt_retention_completion.physics_reexecuted -and
    -not [bool]$closure.post_attempt_retention_completion.evaluator_reexecuted
) "QSDK-R23D12 post-attempt retention changed"

$attestation = Get-Content -Raw -LiteralPath (
    [string]$closure.full_godot_attestation.path
) | ConvertFrom-Json -AsHashtable -Depth 100
Assert-R23D12Closure (
    [string]$attestation.status -ceq "full_godot_conformance_passed" -and
    [string]$attestation.source.commit -ceq $sourceCommit -and
    [string]$attestation.source.tree_git_oid -ceq $sourceTree -and
    [bool]$attestation.source.clean_pushed_live -and
    [bool]$attestation.conformance.godot_including -and
    [double]$attestation.conformance.duration_seconds -eq
        [double]$closure.full_godot_attestation.duration_seconds -and
    @($attestation.claims.GetEnumerator() | Where-Object { [bool]$_.Value }).Count -eq 0 -and
    [bool]$closure.full_godot_attestation.independent_verification_passed
) "QSDK-R23D12 source-exact attestation semantics changed"

$standaloneCanaryLog = Get-Content -Raw -LiteralPath (
    [string]$closure.production_authorization_canaries.standalone_log_path
)
Assert-R23D12Closure (
    @($standaloneCanaryLog -split "`r?`n" | Where-Object {
        $_.StartsWith("QSDK_R23D12_AUTHORIZATION_CANARIES_PASS ")
    }).Count -eq 1 -and
    [bool]$closure.production_authorization_canaries.supervisor_reexecuted_before_freeze -and
    [int]$closure.production_authorization_canaries.engine_count -eq 3 -and
    [int]$closure.production_authorization_canaries.actual_production_authorization_function_execution_count -eq 6 -and
    [int]$closure.production_authorization_canaries.positive_authorization_canary_count -eq 3 -and
    [int]$closure.production_authorization_canaries.mutated_binding_refusal_canary_count -eq 3 -and
    [int]$closure.production_authorization_canaries.content_addressed_input_count -eq 58 -and
    [int]$closure.production_authorization_canaries.model_construction_count -eq 0 -and
    [int]$closure.production_authorization_canaries.world_build_count -eq 0 -and
    [bool]$closure.production_authorization_canaries.test_only_evidence_root_deleted
) "QSDK-R23D12 production authorization canaries changed"

$freeze = Get-Content -Raw -LiteralPath (Join-Path $EvidenceRoot "physical-freeze.json") |
    ConvertFrom-Json -AsHashtable -Depth 100
$authorization = Get-Content -Raw -LiteralPath (
    Join-Path $EvidenceRoot "stage-a-authorization.json"
) | ConvertFrom-Json -AsHashtable -Depth 100
$report = Get-Content -Raw -LiteralPath (Join-Path $EvidenceRoot "report.json") |
    ConvertFrom-Json -AsHashtable -Depth 100
$completion = Get-Content -Raw -LiteralPath (
    Join-Path $EvidenceRoot "completion.json"
) | ConvertFrom-Json -AsHashtable -Depth 100
Assert-R23D12Closure (
    [string]$freeze.schema_version -ceq
        "sporespore_qsdk_r23d12_physical_freeze_v1" -and
    [string]$freeze.source_commit -ceq $sourceCommit -and
    [string]$freeze.source_tree_git_oid -ceq $sourceTree -and
    @($freeze.source_bindings).Count -eq 108 -and
    @($freeze.runtime_artifacts).Count -eq 3 -and
    @($freeze.external_runtime_bindings).Count -eq 4 -and
    @($freeze.content_addressed_inputs.source_bindings).Count -eq 108 -and
    @($freeze.content_addressed_inputs.runtime_artifacts).Count -eq 3 -and
    @($freeze.content_addressed_inputs.external_runtime_bindings).Count -eq 4 -and
    [string]$freeze.content_addressed_inputs.full_godot_attestation.sha256 -ceq
        [string]$closure.full_godot_attestation.raw_sha256 -and
    [bool]$freeze.production_authorization_canaries_valid -and
    [bool]$freeze.complete_zero_world_gate_passed -and
    [bool]$freeze.physical_execution_authorized -and
    -not [bool]$freeze.physical_acceptance_authority
) "QSDK-R23D12 physical freeze changed"
$embeddedCanaries = $freeze.production_authorization_canaries
Assert-R23D12Closure (
    [int]$embeddedCanaries.engine_count -eq 3 -and
    [int]$embeddedCanaries.worker_process_launch_count -eq 6 -and
    [int]$embeddedCanaries.positive_authorization_canary_count -eq 3 -and
    [int]$embeddedCanaries.mutated_binding_refusal_canary_count -eq 3 -and
    [int]$embeddedCanaries.content_addressed_input_count -eq 58 -and
    [int]$embeddedCanaries.model_construction_count -eq 0 -and
    [int]$embeddedCanaries.world_build_count -eq 0
) "QSDK-R23D12 embedded production canaries changed"
Assert-R23D12Closure (
    [string]$authorization.schema_version -ceq
        "sporespore_qsdk_r23d12_attempt_v1" -and
    [string]$authorization.stage_authorization_id -ceq "stage_a" -and
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
    @($authorization.ordered_stage_b_cell_ids).Count -eq 0 -and
    -not [bool]$authorization.replacement_or_selective_rerun_permitted
) "QSDK-R23D12 Stage A authorization changed"

Assert-R23D12Closure (
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
    -not [bool]$completion.release_authorized -and
    -not [bool]$completion.physical_acceptance_authority
) "QSDK-R23D12 immutable completion changed"
Assert-R23D12Closure (
    [string]$report.schema_version -ceq
        "sporespore_qsdk_r23d12_campaign_report_v1" -and
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
) "QSDK-R23D12 retained campaign report changed"

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
        Assert-R23D12ClosureFile `
            -Path ([string]$receipt.path) `
            -ExpectedSha256 ([string]$receipt.digest) `
            -Label "$cellId $([string]$receipt.label)"
    }
    $tracePath = Join-Path $EvidenceRoot (
        "traces\mujoco_stability_assisted_taper_screen__$cellId.ndjson"
    )
    Assert-R23D12ClosureFile `
        -Path $tracePath `
        -ExpectedSha256 ([string]$expected.trace_raw_sha256) `
        -Label "$cellId trace"
    $terminal = Get-Content -Raw -LiteralPath (
        Join-Path $cellRoot "terminal-entry.json"
    ) | ConvertFrom-Json -AsHashtable -Depth 100
    $process = Get-Content -Raw -LiteralPath (Join-Path $cellRoot "process.json") |
        ConvertFrom-Json -AsHashtable -Depth 100
    $measurement = $terminal.measurements
    $evaluation = $report.stage_a_evaluation.cell_evaluations[$index]
    Assert-R23D12Closure (
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
        [bool]$evaluation.entry_valid -and
        [bool]$evaluation.execution_integrity_passed -and
        [bool]$evaluation.outcome.signed_yaw_response_passed -and
        [bool]$evaluation.outcome.outcome_gate_passed -eq
            [bool]$expected.outcome_gate_passed
    ) "QSDK-R23D12 retained cell changed: $cellId"
}

$positive = $closure.retained_stage_a_cells[0]
$negative = $closure.retained_stage_a_cells[1]
$negativeTrace = Join-Path $EvidenceRoot (
    "traces\mujoco_stability_assisted_taper_screen__" +
    "mujoco__stability_assisted_taper__negative_heading.ndjson"
)
$negativeTerminalRows = @(
    Get-Content -LiteralPath $negativeTrace |
        Select-Object -Skip 2992 |
        ForEach-Object { $_ | ConvertFrom-Json -Depth 40 }
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
$lastNegativeActive = $negativeActive[-1]
Assert-R23D12Closure (
    [bool]$positive.outcome_gate_passed -and
    [bool]$positive.confirmation_satisfied -and
    [int]$positive.post_handoff_contact_loss_step_count -eq 0 -and
    -not [bool]$negative.outcome_gate_passed -and
    -not [bool]$negative.confirmation_satisfied -and
    [string]$negative.handoff_reason -ceq
        "deadline_forced_without_quiescence_confirmation" -and
    [int]$negative.active_terminal_step_count -eq 540 -and
    [int]$negative.first_post_handoff_contact_loss_step -eq 585 -and
    [int]$negative.post_handoff_contact_loss_step_count -eq 50 -and
    $negativeMinimumTilt -eq [double]$negative.minimum_active_tilt_rad -and
    $negativeMinimumJointError -eq
        [double]$negative.minimum_active_joint_position_error_rad -and
    $negativeTightRows.Count -eq 0 -and
    $negativeCoarseRows.Count -eq 258 -and
    @($lastNegativeActive.ordered_foot_contacts.psobject.Properties |
        Where-Object { [bool]$_.Value }).Count -eq 4 -and
    @($negative.failed_gate_ids).Count -eq 1 -and
    [string]$negative.failed_gate_ids[0] -ceq "R23D12_QUIESCENT_TAPER" -and
    [bool]$positive.signed_yaw_response_passed -and
    [bool]$negative.signed_yaw_response_passed
) "QSDK-R23D12 valid-negative mechanism changed"

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
        Assert-R23D12ClosureFile `
            -Path (Join-Path $EvidenceRoot "$relative\$([string]$receipt.name)") `
            -ExpectedSha256 ([string]$receipt.digest) `
            -Label "$kind evaluator $([string]$receipt.name)"
    }
    Assert-R23D12Closure ([int]$declared.process_exit_code -eq 0) (
        "QSDK-R23D12 evaluator exit changed: $kind"
    )
}
$stageAStdout = Get-Content -Raw -LiteralPath (
    Join-Path $EvidenceRoot "stage-a-evaluator\stdout.txt"
)
$completeStdout = Get-Content -Raw -LiteralPath (
    Join-Path $EvidenceRoot "complete-evaluator\stdout.txt"
)
Assert-R23D12Closure (
    @($stageAStdout -split "`r?`n" | Where-Object {
        $_.StartsWith("QSDK_R23D12_STAGE_A_EVALUATION ")
    }).Count -eq 1 -and
    @($completeStdout -split "`r?`n" | Where-Object {
        $_.StartsWith("QSDK_R23D12_COMPLETE_EVALUATION ")
    }).Count -eq 1 -and
    @($stageAStdout, $completeStdout | Where-Object {
        $_ -match "QSDK_R23D12_EVALUATION "
    }).Count -eq 0
) "QSDK-R23D12 evaluator producer/consumer markers changed"

$supervisorText = Get-Content -Raw -LiteralPath (
    Join-Path $sdkRoot "run_qsdk_r23d12_supervisor.ps1"
)
$mujocoText = Get-Content -Raw -LiteralPath (
    Join-Path $sdkRoot (
        "adapters\mujoco\sporespore_mujoco_adapter\" +
        "qsdk_r23d12_stability_assisted_taper_physical.py"
    )
)
$rapierText = Get-Content -Raw -LiteralPath (
    Join-Path $sdkRoot (
        "adapters\rapier\src\qsdk_r23d3_phase_balanced\r23d12_physical.rs"
    )
)
$godotText = Get-Content -Raw -LiteralPath (
    Join-Path $repoRoot (
        "tests\test_sdk_qsdk_r23d12_stability_assisted_taper_" +
        "godot_jolt_physical_worker.gd"
    )
)
$conformanceText = Get-Content -Raw -LiteralPath (
    Join-Path $sdkRoot "run_conformance.ps1"
)
Assert-R23D12Closure (
    $supervisorText.Contains("r23d12_physical_closure_v1.json") -and
    $supervisorText.Contains("QSDK-R23D12 CLOSED") -and
    $mujocoText.Contains("r23d12_physical_closure_v1.json") -and
    $mujocoText.Contains("QSDK_R23D12_MJC_CLOSED") -and
    $rapierText.Contains("r23d12_physical_closure_v1.json") -and
    $rapierText.Contains("QSDK_R23D12_RAP_CLOSED") -and
    $godotText.Contains("r23d12_physical_closure_v1.json") -and
    $godotText.Contains("QSDK_R23D12_GJT_CLOSED") -and
    $conformanceText.Contains("tests\test_qsdk_r23d12_closure.ps1") -and
    -not $conformanceText.Contains("run_qsdk_r23d12_mujoco_worker_preflight.ps1") -and
    -not $conformanceText.Contains("run_qsdk_r23d12_rapier_worker_preflight.ps1") -and
    -not $conformanceText.Contains("run_qsdk_r23d12_godot_jolt_worker_preflight.ps1") -and
    -not $conformanceText.Contains("run_qsdk_r23d12_authorization_canaries.ps1")
) "QSDK-R23D12 physical closure routing changed"

$priorAttemptRoots = @(
    Get-ChildItem -LiteralPath (Split-Path -Parent $EvidenceRoot) -Directory |
        Where-Object {
            $_.Name.StartsWith("qsdk-r23d12-", [StringComparison]::Ordinal)
        }
)
$sameIdentityRefusal = @(
    & pwsh -NoLogo -NoProfile -File (
        Join-Path $sdkRoot "run_qsdk_r23d12_supervisor.ps1"
    ) `
        -RunPhysical `
        -FullConformanceAttestation ([string]$closure.full_godot_attestation.path) `
        2>&1
)
$sameIdentityExitCode = $LASTEXITCODE
$sameIdentityText = @($sameIdentityRefusal | ForEach-Object { [string]$_ }) -join "`n"
$afterAttemptRoots = @(
    Get-ChildItem -LiteralPath (Split-Path -Parent $EvidenceRoot) -Directory |
        Where-Object {
            $_.Name.StartsWith("qsdk-r23d12-", [StringComparison]::Ordinal)
        }
)
Assert-R23D12Closure (
    $sameIdentityExitCode -ne 0 -and
    $sameIdentityText.Contains("QSDK_R23D12_PHYSICAL_REFUSAL") -and
    $sameIdentityText.Contains('"reason":"r23d12_identity_closed"') -and
    $sameIdentityText.Contains("QSDK-R23D12 CLOSED") -and
    $priorAttemptRoots.Count -eq 1 -and
    $afterAttemptRoots.Count -eq 1 -and
    $afterAttemptRoots[0].FullName -ceq $priorAttemptRoots[0].FullName
) "QSDK-R23D12 same-identity refusal changed"

Assert-R23D12Closure (
    [bool]$closure.immutable_completion_record.scientific_negative -and
    -not [bool]$closure.immutable_completion_record.scientific_positive -and
    [string]$closure.successor_boundary.successor_id -ceq "QSDK-R23D13" -and
    [bool]$closure.successor_boundary.new_campaign_and_gate_identity_required -and
    -not [bool]$closure.successor_boundary.same_policy_physical_rerun_permitted -and
    [bool]$closure.successor_boundary.scientifically_distinct_terminal_recovery_mechanism_required -and
    [bool]$closure.successor_boundary.stage_a_must_remain_bilateral -and
    [bool]$closure.scientific_observation_boundary.r23d11_trace_semantics_failure_repaired -and
    [bool]$closure.scientific_observation_boundary.both_forward_displacement_gates_passed -and
    -not [bool]$closure.claims.command_conditioned_turning -and
    -not [bool]$closure.claims.bilateral_signed_turning -and
    -not [bool]$closure.claims.portable_basic_turning -and
    -not [bool]$closure.claims.cross_engine_equivalence -and
    -not [bool]$closure.claims.q_sdk_r23_satisfied -and
    -not [bool]$closure.claims.prone_to_standing -and
    -not [bool]$closure.claims.release_authorized -and
    -not [bool]$closure.claims.physical_acceptance_authority
) "QSDK-R23D12 claim or successor boundary changed"

# The same-identity negative control intentionally launches a child that exits
# nonzero. Preserve that observed refusal above, then clear the ambient native
# command status so callers that dot-invoke this successful audit do not
# mistake the expected child refusal for an audit failure.
$global:LASTEXITCODE = 0

Write-Host (
    "QSDK_R23D12_CLOSURE_PASS status=valid-none worlds=2 " +
    "traces=2 rows=7784 yaw_signed=2/2 taper=1/2 selected=NONE " +
    "stage_b=0/9 evidence_files=$($tree.file_count) retained_cas=30 " +
    "same_identity_refusal=1 same_identity_rerun=False " +
    "turning=False equivalence=False " +
    "physical_authority=False"
)
