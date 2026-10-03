#requires -Version 7.0

[CmdletBinding()]
param(
    [string]$EvidenceRoot = (
        "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence\" +
        "qsdk-r23d10-c7e9510e-20260809T153312Z"
    ),
    [string]$SupervisorLog = (
        "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence\" +
        "qsdk-r23d10-supervisor-c7e9510e-20260809T153312Z.log"
    )
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$sdkRoot = Join-Path $repoRoot "sdk"
$closurePath = Join-Path $sdkRoot "turning\r23d10_physical_closure_v1.json"
$artifactStorePath = Join-Path $sdkRoot "content_addressed_artifact_store.ps1"
$campaignId = (
    "QSDK-R23D10-SUPPORT-POSE-CONFIRMED-QUIESCENT-TAPER-" +
    "BILATERAL-TURN-DEVELOPMENT"
)
$gateId = "QSDK-R23D10"
$sourceCommit = "c7e9510e12609ce71170736e3328bd782dc16ef2"
$sourceTree = "cc181db24a3f643e1858353e6095eb1ce11a3657"
$emptySha256 = (
    "sha256:e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
)

. $artifactStorePath

function Assert-R23D10Closure {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function Get-R23D10ClosureRawSha256 {
    param([Parameter(Mandatory)][string]$Path)
    return "sha256:" + (
        Get-FileHash -LiteralPath $Path -Algorithm SHA256
    ).Hash.ToLowerInvariant()
}

function Get-R23D10ClosureBytesSha256 {
    param([Parameter(Mandatory)][byte[]]$Bytes)
    return "sha256:" + [Convert]::ToHexString(
        [Security.Cryptography.SHA256]::HashData($Bytes)
    ).ToLowerInvariant()
}

function Get-R23D10ClosureEvidenceTree {
    param([Parameter(Mandatory)][string]$Root)
    $files = @(Get-ChildItem -LiteralPath $Root -File -Recurse | Sort-Object {
        $_.FullName.Substring($Root.Length + 1).Replace("\", "/")
    })
    $lines = @($files | ForEach-Object {
        $relative = $_.FullName.Substring($Root.Length + 1).Replace("\", "/")
        "{0}`t{1}`t{2}" -f $relative, $_.Length, (
            Get-R23D10ClosureRawSha256 $_.FullName
        ).Substring(7)
    })
    $projection = [Text.Encoding]::UTF8.GetBytes(($lines -join "`n") + "`n")
    return [ordered]@{
        files = $files
        file_count = $files.Count
        total_byte_length = [int64](($files | Measure-Object Length -Sum).Sum)
        raw_sha256 = Get-R23D10ClosureBytesSha256 $projection
    }
}

function Test-R23D10ClosureCasArtifact {
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

function Assert-R23D10ClosureFile {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$ExpectedSha256,
        [Parameter(Mandatory)][string]$Label
    )
    Assert-R23D10Closure (Test-Path -LiteralPath $Path -PathType Leaf) (
        "QSDK-R23D10 retained file is missing: $Label"
    )
    $item = Get-Item -LiteralPath $Path
    Assert-R23D10Closure (
        (Get-R23D10ClosureRawSha256 $Path) -ceq $ExpectedSha256 -and
        (Test-R23D10ClosureCasArtifact `
            -ExpectedSha256 $ExpectedSha256 `
            -ExpectedByteLength ([long]$item.Length))
    ) "QSDK-R23D10 retained file or CAS object changed: $Label"
}

Assert-R23D10Closure (
    (git -C $repoRoot rev-parse --show-toplevel).Replace("/", "\") -ceq
        $repoRoot -and
    (git -C $repoRoot remote get-url origin) -ceq
        "https://github.com/Slagathore/sporespore.git"
) "QSDK-R23D10 closure repository identity mismatch"
Assert-R23D10Closure (
    (git -C $repoRoot rev-parse ($sourceCommit + "^{tree}")) -ceq $sourceTree
) "QSDK-R23D10 frozen source tree is unavailable"
Assert-R23D10Closure (Test-Path -LiteralPath $closurePath -PathType Leaf) (
    "QSDK-R23D10 closure is missing"
)
Assert-R23D10Closure (Test-Path -LiteralPath $EvidenceRoot -PathType Container) (
    "QSDK-R23D10 retained attempt root is missing"
)
Assert-R23D10Closure (Test-Path -LiteralPath $SupervisorLog -PathType Leaf) (
    "QSDK-R23D10 retained supervisor log is missing"
)

$closure = Get-Content -Raw -LiteralPath $closurePath |
    ConvertFrom-Json -AsHashtable -Depth 100
Assert-R23D10Closure (
    [string]$closure.schema_version -ceq
        "sporespore_qsdk_r23d10_physical_development_closure_v1" -and
    [string]$closure.status -ceq (
        "closed_consumed_valid_none_stage_a_negative_heading_" +
        "quiescent_taper_failure"
    ) -and
    [string]$closure.campaign_id -ceq $campaignId -and
    [string]$closure.gate_id -ceq $gateId -and
    [string]$closure.source_identity.commit -ceq $sourceCommit -and
    [string]$closure.source_identity.tree_git_oid -ceq $sourceTree -and
    [int]$closure.source_identity.declared_source_binding_count -eq 94 -and
    [int]$closure.source_identity.runtime_artifact_count -eq 3 -and
    [int]$closure.source_identity.external_runtime_binding_count -eq 4 -and
    [int]$closure.source_identity.declared_worker_dependency_count -eq 44
) "QSDK-R23D10 closure identity changed"

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
    Assert-R23D10ClosureFile `
        -Path (Join-Path $EvidenceRoot $item.Key) `
        -ExpectedSha256 ([string]$item.Value) `
        -Label $item.Key
}

$tree = Get-R23D10ClosureEvidenceTree $EvidenceRoot
Assert-R23D10Closure (
    [int]$tree.file_count -eq [int]$closure.attempt.evidence_file_count -and
    [int64]$tree.total_byte_length -eq
        [int64]$closure.attempt.evidence_total_byte_length -and
    [string]$tree.raw_sha256 -ceq
        [string]$closure.attempt.evidence_tree_raw_sha256
) "QSDK-R23D10 retained evidence tree changed"
foreach ($file in @($tree.files)) {
    $sha256 = Get-R23D10ClosureRawSha256 $file.FullName
    Assert-R23D10Closure (
        Test-R23D10ClosureCasArtifact `
            -ExpectedSha256 $sha256 `
            -ExpectedByteLength ([long]$file.Length)
    ) (
        "QSDK-R23D10 retained evidence CAS object changed: " +
        $file.FullName.Substring($EvidenceRoot.Length + 1)
    )
}

Assert-R23D10ClosureFile `
    -Path $SupervisorLog `
    -ExpectedSha256 ([string]$closure.attempt.supervisor_log_raw_sha256) `
    -Label "supervisor log"
Assert-R23D10Closure (
    (Get-Item -LiteralPath $SupervisorLog).Length -eq
        [long]$closure.attempt.supervisor_log_byte_length -and
    [int]$closure.attempt.supervisor_exit_code -eq 0 -and
    [double]$closure.attempt.supervisor_elapsed_seconds -eq 362.2
) "QSDK-R23D10 supervisor receipt changed"

$attestationPath = [string]$closure.full_godot_attestation.path
$attestationLogPath = [string]$closure.full_godot_attestation.conformance_log_path
Assert-R23D10ClosureFile `
    -Path $attestationPath `
    -ExpectedSha256 ([string]$closure.full_godot_attestation.raw_sha256) `
    -Label "full-Godot attestation"
Assert-R23D10ClosureFile `
    -Path $attestationLogPath `
    -ExpectedSha256 ([string]$closure.full_godot_attestation.conformance_log_raw_sha256) `
    -Label "full-Godot conformance log"
Assert-R23D10Closure (
    (Get-Item -LiteralPath $attestationPath).Length -eq
        [long]$closure.full_godot_attestation.byte_length -and
    (Get-Item -LiteralPath $attestationLogPath).Length -eq
        [long]$closure.full_godot_attestation.conformance_log_byte_length
) "QSDK-R23D10 attestation evidence lengths changed"
$attestation = Get-Content -Raw -LiteralPath $attestationPath |
    ConvertFrom-Json -AsHashtable -Depth 100
Assert-R23D10Closure (
    [string]$attestation.status -ceq "full_godot_conformance_passed" -and
    [string]$attestation.source.commit -ceq $sourceCommit -and
    [string]$attestation.source.tree_git_oid -ceq $sourceTree -and
    [bool]$attestation.source.clean_pushed_live -and
    [bool]$attestation.conformance.godot_including -and
    [double]$attestation.conformance.duration_seconds -eq
        [double]$closure.full_godot_attestation.duration_seconds -and
    -not [bool]$attestation.claims.turning_acceptance -and
    -not [bool]$attestation.claims.physical_acceptance_authority
) "QSDK-R23D10 source-exact attestation semantics changed"

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
Assert-R23D10Closure (
    [string]$freeze.schema_version -ceq
        "sporespore_qsdk_r23d10_physical_freeze_v1" -and
    [string]$freeze.campaign_id -ceq $campaignId -and
    [string]$freeze.gate_id -ceq $gateId -and
    [string]$freeze.source_commit -ceq $sourceCommit -and
    [string]$freeze.source_tree_git_oid -ceq $sourceTree -and
    @($freeze.source_bindings).Count -eq 94 -and
    @($freeze.runtime_artifacts).Count -eq 3 -and
    @($freeze.external_runtime_bindings).Count -eq 4 -and
    @($freeze.content_addressed_inputs.source_bindings).Count -eq 94 -and
    @($freeze.content_addressed_inputs.runtime_artifacts).Count -eq 3 -and
    @($freeze.content_addressed_inputs.external_runtime_bindings).Count -eq 4 -and
    [string]$freeze.content_addressed_inputs.full_godot_attestation.sha256 -ceq
        [string]$closure.full_godot_attestation.raw_sha256 -and
    [bool]$freeze.production_authorization_canaries_valid -and
    [bool]$freeze.complete_zero_world_gate_passed -and
    [bool]$freeze.physical_execution_authorized -and
    -not [bool]$freeze.physical_acceptance_authority
) "QSDK-R23D10 physical freeze changed"
$canaries = $freeze.production_authorization_canaries
Assert-R23D10Closure (
    [int]$canaries.engine_count -eq 3 -and
    [int]$canaries.worker_process_launch_count -eq 6 -and
    [int]$canaries.actual_production_authorization_function_execution_count -eq 6 -and
    [int]$canaries.positive_authorization_canary_count -eq 3 -and
    [int]$canaries.mutated_binding_refusal_canary_count -eq 3 -and
    [int]$canaries.content_addressed_input_count -eq 44 -and
    [int]$canaries.model_construction_count -eq 0 -and
    [int]$canaries.world_build_count -eq 0 -and
    [bool]$canaries.test_only_evidence_root_deleted
) "QSDK-R23D10 production authorization canary receipt changed"
Assert-R23D10Closure (
    [string]$authorization.schema_version -ceq
        "sporespore_qsdk_r23d10_attempt_v1" -and
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
) "QSDK-R23D10 Stage A authorization changed"

Assert-R23D10Closure (
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
) "QSDK-R23D10 immutable completion changed"
Assert-R23D10Closure (
    [string]$report.schema_version -ceq
        "sporespore_qsdk_r23d10_campaign_report_v1" -and
    [string]$report.campaign_id -ceq $campaignId -and
    [string]$report.gate_id -ceq $gateId -and
    [string]$report.attempt_id -ceq [string]$closure.attempt.attempt_id -and
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
) "QSDK-R23D10 retained campaign report changed"

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
        Assert-R23D10ClosureFile `
            -Path ([string]$receipt.path) `
            -ExpectedSha256 ([string]$receipt.digest) `
            -Label "$cellId $([string]$receipt.label)"
    }
    Assert-R23D10Closure (
        (Test-R23D10ClosureCasArtifact `
            -ExpectedSha256 ([string]$expected.trace_raw_sha256) `
            -ExpectedByteLength ([long]$expected.trace_byte_length))
    ) "QSDK-R23D10 retained trace CAS changed: $cellId"
    $terminal = Get-Content -Raw -LiteralPath (
        Join-Path $cellRoot "terminal-entry.json"
    ) | ConvertFrom-Json -AsHashtable -Depth 100
    $measurement = $terminal.measurements
    $evaluation = $report.stage_a_evaluation.cell_evaluations[$index]
    Assert-R23D10Closure (
        [string]$terminal.cell_id -ceq $cellId -and
        [string]$terminal.arm_id -ceq [string]$expected.arm_id -and
        [double]$terminal.turn_heading_offset_rad -eq
            [double]$expected.turn_heading_offset_rad -and
        [bool]$terminal.execution.integrity_passed -and
        [int]$terminal.execution.world_attempt_count -eq 1 -and
        [int]$terminal.execution.world_build_count -eq 1 -and
        [int]$terminal.trace_summary.row_count -eq 3892 -and
        [string]$terminal.trace_artifact.sha256 -ceq
            [string]$expected.trace_raw_sha256 -and
        [double]$measurement.turn_phase_yaw_delta_rad -eq
            [double]$expected.turn_phase_yaw_delta_rad -and
        [double]$measurement.final_forward_displacement_m -eq
            [double]$expected.final_forward_displacement_m -and
        [int]$measurement.active_terminal_step_count -eq
            [int]$expected.active_terminal_step_count -and
        [int]$measurement.quiescent_taper_step_count -eq
            [int]$expected.quiescent_taper_step_count -and
        [int]$measurement.passive_terminal_step_count -eq
            [int]$expected.passive_zero_actuation_step_count -and
        [bool]$measurement.confirmation_satisfied -eq
            [bool]$expected.confirmation_satisfied -and
        [string]$measurement.handoff_reason -ceq
            [string]$expected.handoff_reason -and
        [int]$measurement.post_handoff_contact_loss_step_count -eq
            [int]$expected.post_handoff_contact_loss_step_count -and
        [int]$measurement.post_handoff_native_actuation_application_count -eq 0 -and
        [int]$measurement.taper_reset_count -eq [int]$expected.taper_reset_count -and
        [bool]$measurement.quiescent_taper_gate_passed -eq
            [bool]$expected.walking_and_taper_gate_passed -and
        [bool]$evaluation.entry_valid -and
        [bool]$evaluation.execution_integrity_passed -and
        [bool]$evaluation.outcome.signed_yaw_response_passed -and
        [bool]$evaluation.outcome.outcome_gate_passed -eq
            [bool]$expected.outcome_gate_passed
    ) "QSDK-R23D10 retained cell changed: $cellId"
}

$positive = $closure.retained_stage_a_cells[0]
$negative = $closure.retained_stage_a_cells[1]
Assert-R23D10Closure (
    [bool]$positive.outcome_gate_passed -and
    [bool]$positive.confirmation_satisfied -and
    [int]$positive.post_handoff_contact_loss_step_count -eq 0 -and
    -not [bool]$negative.outcome_gate_passed -and
    -not [bool]$negative.confirmation_satisfied -and
    [string]$negative.handoff_reason -ceq
        "deadline_forced_without_quiescence_confirmation" -and
    [int]$negative.active_terminal_step_count -eq 540 -and
    [int]$negative.first_post_handoff_contact_loss_step -eq 628 -and
    [int]$negative.post_handoff_contact_loss_step_count -eq 97 -and
    [bool]$positive.signed_yaw_response_passed -and
    [bool]$negative.signed_yaw_response_passed
) "QSDK-R23D10 valid-negative mechanism changed"

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
        Assert-R23D10ClosureFile `
            -Path (Join-Path $EvidenceRoot "$relative\$([string]$receipt.name)") `
            -ExpectedSha256 ([string]$receipt.digest) `
            -Label "$kind evaluator $([string]$receipt.name)"
    }
    Assert-R23D10Closure ([int]$declared.process_exit_code -eq 0) (
        "QSDK-R23D10 evaluator exit changed: $kind"
    )
}
$stageAStdout = Get-Content -Raw -LiteralPath (
    Join-Path $EvidenceRoot "stage-a-evaluator\stdout.txt"
)
$completeStdout = Get-Content -Raw -LiteralPath (
    Join-Path $EvidenceRoot "complete-evaluator\stdout.txt"
)
Assert-R23D10Closure (
    @($stageAStdout -split "`r?`n" | Where-Object {
        $_.StartsWith("QSDK_R23D10_STAGE_A_EVALUATION ")
    }).Count -eq 1 -and
    @($completeStdout -split "`r?`n" | Where-Object {
        $_.StartsWith("QSDK_R23D10_COMPLETE_EVALUATION ")
    }).Count -eq 1 -and
    @($stageAStdout, $completeStdout | Where-Object {
        $_ -match "QSDK_R23D10_EVALUATION "
    }).Count -eq 0
) "QSDK-R23D10 evaluator producer/consumer markers changed"

$supervisorText = Get-Content -Raw -LiteralPath (
    Join-Path $sdkRoot "run_qsdk_r23d10_supervisor.ps1"
)
$mujocoText = Get-Content -Raw -LiteralPath (
    Join-Path $sdkRoot (
        "adapters\mujoco\sporespore_mujoco_adapter\" +
        "qsdk_r23d10_quiescent_taper_physical.py"
    )
)
$rapierText = Get-Content -Raw -LiteralPath (
    Join-Path $sdkRoot "adapters\rapier\src\qsdk_r23d3_phase_balanced.rs"
)
$godotText = Get-Content -Raw -LiteralPath (
    Join-Path $repoRoot (
        "tests\test_sdk_qsdk_r23d10_quiescent_taper_godot_jolt_worker.gd"
    )
)
Assert-R23D10Closure (
    $supervisorText.Contains("r23d10_physical_closure_v1.json") -and
    $supervisorText.Contains("QSDK-R23D10 CLOSED") -and
    $mujocoText.Contains("r23d10_physical_closure_v1.json") -and
    $mujocoText.Contains("QSDK_R23D10_MJC_CLOSED") -and
    $rapierText.Contains("r23d10_physical_closure_v1.json") -and
    $rapierText.Contains("QSDK_R23D10_RAP_CLOSED") -and
    $godotText.Contains("r23d10_physical_closure_v1.json") -and
    $godotText.Contains("QSDK_R23D10_GJT_CLOSED")
) "QSDK-R23D10 physical closure interlocks changed"

Assert-R23D10Closure (
    [bool]$closure.immutable_completion_record.scientific_negative -and
    -not [bool]$closure.immutable_completion_record.scientific_positive -and
    [string]$closure.successor_boundary.successor_id -ceq "QSDK-R23D11" -and
    [bool]$closure.successor_boundary.new_campaign_and_gate_identity_required -and
    -not [bool]$closure.successor_boundary.same_policy_physical_rerun_permitted -and
    [bool]$closure.successor_boundary.stage_a_must_remain_bilateral -and
    -not [bool]$closure.claims.command_conditioned_turning -and
    -not [bool]$closure.claims.bilateral_signed_turning -and
    -not [bool]$closure.claims.portable_basic_turning -and
    -not [bool]$closure.claims.cross_engine_equivalence -and
    -not [bool]$closure.claims.q_sdk_r23_satisfied -and
    -not [bool]$closure.claims.prone_to_standing -and
    -not [bool]$closure.claims.release_authorized -and
    -not [bool]$closure.claims.physical_acceptance_authority
) "QSDK-R23D10 claim or successor boundary changed"

Write-Host (
    "QSDK_R23D10_CLOSURE_PASS status=valid-none worlds=2 " +
    "traces=2 rows=7784 yaw_signed=2/2 taper=1/2 selected=NONE " +
    "stage_b=0/9 evidence_files=$($tree.file_count) retained_cas=29 " +
    "same_identity_rerun=False turning=False equivalence=False " +
    "physical_authority=False"
)
