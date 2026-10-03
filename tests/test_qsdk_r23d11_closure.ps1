#requires -Version 7.0

[CmdletBinding()]
param(
    [string]$EvidenceRoot = (
        "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence\" +
        "qsdk-r23d11-20260809T193359Z"
    ),
    [string]$PreAttemptRefusalRoot = (
        "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence\" +
        "qsdk-r23d11-20260809T192557Z"
    )
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$sdkRoot = Join-Path $repoRoot "sdk"
$closurePath = Join-Path $sdkRoot "turning\r23d11_physical_closure_v1.json"
$artifactStorePath = Join-Path $sdkRoot "content_addressed_artifact_store.ps1"
$campaignId = (
    "QSDK-R23D11-SUPPORT-CENTROID-ASSISTED-QUIESCENT-TAPER-" +
    "BILATERAL-TURN-DEVELOPMENT"
)
$gateId = "QSDK-R23D11"
$sourceCommit = "2477b6bece55a31257b1306a64330f59633b6c58"
$sourceTree = "cf81fdafa39062ef8c389e3f10e6852148f3f2b3"
$emptySha256 = (
    "sha256:e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
)

. $artifactStorePath

function Assert-R23D11Closure {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function Get-R23D11ClosureRawSha256 {
    param([Parameter(Mandatory)][string]$Path)
    return "sha256:" + (
        Get-FileHash -LiteralPath $Path -Algorithm SHA256
    ).Hash.ToLowerInvariant()
}

function Get-R23D11ClosureBytesSha256 {
    param([Parameter(Mandatory)][byte[]]$Bytes)
    return "sha256:" + [Convert]::ToHexString(
        [Security.Cryptography.SHA256]::HashData($Bytes)
    ).ToLowerInvariant()
}

function Get-R23D11ClosureEvidenceTree {
    param([Parameter(Mandatory)][string]$Root)
    $files = @(Get-ChildItem -LiteralPath $Root -File -Recurse | Sort-Object {
        $_.FullName.Substring($Root.Length + 1).Replace("\", "/")
    })
    $lines = @($files | ForEach-Object {
        $relative = $_.FullName.Substring($Root.Length + 1).Replace("\", "/")
        "{0}`t{1}`t{2}" -f $relative, $_.Length, (
            Get-R23D11ClosureRawSha256 $_.FullName
        ).Substring(7)
    })
    $projection = [Text.Encoding]::UTF8.GetBytes(($lines -join "`n") + "`n")
    return [ordered]@{
        files = $files
        file_count = $files.Count
        total_byte_length = [int64](($files | Measure-Object Length -Sum).Sum)
        raw_sha256 = Get-R23D11ClosureBytesSha256 $projection
    }
}

function Test-R23D11ClosureCasArtifact {
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

function Assert-R23D11ClosureFile {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$ExpectedSha256,
        [Parameter(Mandatory)][string]$Label
    )
    Assert-R23D11Closure (Test-Path -LiteralPath $Path -PathType Leaf) (
        "QSDK-R23D11 retained file is missing: $Label"
    )
    $item = Get-Item -LiteralPath $Path
    Assert-R23D11Closure (
        (Get-R23D11ClosureRawSha256 $Path) -ceq $ExpectedSha256 -and
        (Test-R23D11ClosureCasArtifact `
            -ExpectedSha256 $ExpectedSha256 `
            -ExpectedByteLength ([long]$item.Length))
    ) "QSDK-R23D11 retained file or CAS object changed: $Label"
}

Assert-R23D11Closure (
    (git -C $repoRoot rev-parse --show-toplevel).Replace("/", "\") -ceq
        $repoRoot -and
    (git -C $repoRoot remote get-url origin) -ceq
        "https://github.com/Slagathore/sporespore.git"
) "QSDK-R23D11 closure repository identity mismatch"
Assert-R23D11Closure (
    (git -C $repoRoot rev-parse ($sourceCommit + "^{tree}")) -ceq $sourceTree
) "QSDK-R23D11 frozen source tree is unavailable"
Assert-R23D11Closure (Test-Path -LiteralPath $closurePath -PathType Leaf) (
    "QSDK-R23D11 closure is missing"
)
Assert-R23D11Closure (Test-Path -LiteralPath $EvidenceRoot -PathType Container) (
    "QSDK-R23D11 retained attempt root is missing"
)
Assert-R23D11Closure (
    Test-Path -LiteralPath $PreAttemptRefusalRoot -PathType Container
) "QSDK-R23D11 pre-attempt refusal root is missing"

$closure = Get-Content -Raw -LiteralPath $closurePath |
    ConvertFrom-Json -AsHashtable -Depth 100
Assert-R23D11Closure (
    [string]$closure.schema_version -ceq
        "sporespore_qsdk_r23d11_physical_development_closure_v1" -and
    [string]$closure.status -ceq (
        "closed_consumed_infrastructure_invalid_trace_diagnostic_" +
        "semantics_mismatch"
    ) -and
    [string]$closure.campaign_id -ceq $campaignId -and
    [string]$closure.gate_id -ceq $gateId -and
    [string]$closure.source_identity.commit -ceq $sourceCommit -and
    [string]$closure.source_identity.tree_git_oid -ceq $sourceTree -and
    [int]$closure.source_identity.declared_source_binding_count -eq 99 -and
    [int]$closure.source_identity.runtime_artifact_count -eq 3 -and
    [int]$closure.source_identity.external_runtime_binding_count -eq 4 -and
    [int]$closure.source_identity.declared_worker_dependency_count -eq 49
) "QSDK-R23D11 closure identity changed"

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
    Assert-R23D11ClosureFile `
        -Path (Join-Path $EvidenceRoot $item.Key) `
        -ExpectedSha256 ([string]$item.Value) `
        -Label $item.Key
}

$tree = Get-R23D11ClosureEvidenceTree $EvidenceRoot
Assert-R23D11Closure (
    [int]$tree.file_count -eq [int]$closure.attempt.evidence_file_count -and
    [int64]$tree.total_byte_length -eq
        [int64]$closure.attempt.evidence_total_byte_length -and
    [string]$tree.raw_sha256 -ceq
        [string]$closure.attempt.evidence_tree_raw_sha256
) "QSDK-R23D11 retained evidence tree changed"
foreach ($file in @($tree.files)) {
    $sha256 = Get-R23D11ClosureRawSha256 $file.FullName
    Assert-R23D11Closure (
        Test-R23D11ClosureCasArtifact `
            -ExpectedSha256 $sha256 `
            -ExpectedByteLength ([long]$file.Length)
    ) (
        "QSDK-R23D11 retained evidence CAS object changed: " +
        $file.FullName.Substring($EvidenceRoot.Length + 1)
    )
}

$refusal = $closure.pre_attempt_checkout_byte_refusal
$refusalPath = Join-Path $PreAttemptRefusalRoot (
    "pre_attempt_checkout_byte_refusal.json"
)
Assert-R23D11ClosureFile `
    -Path $refusalPath `
    -ExpectedSha256 ([string]$refusal.receipt_raw_sha256) `
    -Label "pre-attempt checkout-byte refusal"
$refusalTree = Get-R23D11ClosureEvidenceTree $PreAttemptRefusalRoot
Assert-R23D11Closure (
    [int]$refusalTree.file_count -eq [int]$refusal.evidence_tree_file_count -and
    [int64]$refusalTree.total_byte_length -eq
        [int64]$refusal.evidence_tree_total_byte_length -and
    [string]$refusalTree.raw_sha256 -ceq
        [string]$refusal.evidence_tree_raw_sha256 -and
    [int]$refusal.raw_checkout_blob_mismatch_count -eq 2 -and
    [int]$refusal.post_rematerialization_raw_checkout_blob_mismatch_count -eq 0 -and
    -not [bool]$refusal.stage_a_authorization_created -and
    -not [bool]$refusal.attempt_id_created -and
    -not [bool]$refusal.physical_identity_consumed
) "QSDK-R23D11 pre-attempt refusal changed"

$attestationPath = [string]$closure.full_godot_attestation.path
Assert-R23D11ClosureFile `
    -Path $attestationPath `
    -ExpectedSha256 ([string]$closure.full_godot_attestation.raw_sha256) `
    -Label "full-Godot attestation"
Assert-R23D11Closure (
    (Get-Item -LiteralPath $attestationPath).Length -eq
        [long]$closure.full_godot_attestation.byte_length
) "QSDK-R23D11 attestation length changed"
$attestation = Get-Content -Raw -LiteralPath $attestationPath |
    ConvertFrom-Json -AsHashtable -Depth 100
Assert-R23D11Closure (
    [string]$attestation.status -ceq "full_godot_conformance_passed" -and
    [string]$attestation.source.commit -ceq $sourceCommit -and
    [string]$attestation.source.tree_git_oid -ceq $sourceTree -and
    [bool]$attestation.source.clean_pushed_live -and
    [bool]$attestation.conformance.godot_including -and
    [double]$attestation.conformance.duration_seconds -eq
        [double]$closure.full_godot_attestation.duration_seconds -and
    -not [bool]$attestation.conformance.one_shot_physical_campaign_executed -and
    -not [bool]$attestation.claims.turning_acceptance -and
    -not [bool]$attestation.claims.physical_acceptance_authority
) "QSDK-R23D11 source-exact attestation semantics changed"

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
Assert-R23D11Closure (
    [string]$freeze.schema_version -ceq
        "sporespore_qsdk_r23d11_physical_freeze_v1" -and
    [string]$freeze.source_commit -ceq $sourceCommit -and
    [string]$freeze.source_tree_git_oid -ceq $sourceTree -and
    @($freeze.source_bindings).Count -eq 99 -and
    @($freeze.runtime_artifacts).Count -eq 3 -and
    @($freeze.external_runtime_bindings).Count -eq 4 -and
    @($freeze.content_addressed_inputs.source_bindings).Count -eq 99 -and
    [bool]$freeze.production_authorization_canaries_valid -and
    [bool]$freeze.complete_zero_world_gate_passed -and
    [bool]$freeze.physical_execution_authorized -and
    -not [bool]$freeze.physical_acceptance_authority
) "QSDK-R23D11 physical freeze changed"
$canaries = $freeze.production_authorization_canaries
Assert-R23D11Closure (
    [int]$canaries.engine_count -eq 3 -and
    [int]$canaries.worker_process_launch_count -eq 6 -and
    [int]$canaries.actual_production_authorization_function_execution_count -eq 6 -and
    [int]$canaries.positive_authorization_canary_count -eq 3 -and
    [int]$canaries.mutated_binding_refusal_canary_count -eq 3 -and
    [int]$canaries.content_addressed_input_count -eq 49 -and
    [int]$canaries.model_construction_count -eq 0 -and
    [int]$canaries.world_build_count -eq 0 -and
    [bool]$canaries.test_only_evidence_root_deleted
) "QSDK-R23D11 production authorization canary receipt changed"
Assert-R23D11Closure (
    [string]$authorization.schema_version -ceq
        "sporespore_qsdk_r23d11_attempt_v1" -and
    [string]$authorization.attempt_id -ceq [string]$closure.attempt.attempt_id -and
    [string]$authorization.source_commit -ceq $sourceCommit -and
    [bool]$authorization.physical_execution_authorized -and
    [bool]$authorization.single_use_supervisor_authorization -and
    [bool]$authorization.one_shot_attempt_unconsumed -and
    @($authorization.ordered_stage_a_cell_ids).Count -eq 2 -and
    @($authorization.ordered_stage_b_cell_ids).Count -eq 0 -and
    -not [bool]$authorization.replacement_or_selective_rerun_permitted
) "QSDK-R23D11 Stage A authorization changed"
Assert-R23D11Closure (
    [string]$completion.status -ceq "invalid_or_incomplete_first_attempt" -and
    [string]$completion.source_commit -ceq $sourceCommit -and
    [string]$completion.attempt_id -ceq [string]$closure.attempt.attempt_id -and
    [string]$completion.selected_terminal_policy_id -ceq "INVALID" -and
    [string]$completion.result_classification -ceq
        "invalid_or_incomplete_complete_campaign" -and
    [int]$completion.stage_a_terminal_entry_count -eq 2 -and
    [int]$completion.stage_b_terminal_entry_count -eq 0 -and
    [bool]$completion.one_shot_identity_consumed -and
    -not [bool]$completion.same_identity_rerun_allowed -and
    -not [bool]$completion.command_conditioned_turning -and
    -not [bool]$completion.cross_engine_equivalence -and
    -not [bool]$completion.physical_acceptance_authority
) "QSDK-R23D11 immutable completion changed"
Assert-R23D11Closure (
    [string]$report.schema_version -ceq
        "sporespore_qsdk_r23d11_campaign_report_v1" -and
    [string]$report.result_classification -ceq
        "invalid_or_incomplete_complete_campaign" -and
    -not [bool]$report.development_result_valid -and
    [string]$report.selected_terminal_policy_id -ceq "INVALID" -and
    -not [bool]$report.stage_b_launched -and
    [int]$report.stage_a_world_count -eq 2 -and
    [int]$report.stage_b_world_count -eq 0 -and
    @($report.ordered_stage_a_cells).Count -eq 2 -and
    @($report.ordered_stage_b_cells).Count -eq 0 -and
    [string]$report.stage_a_evaluation.classification -ceq
        "invalid_or_incomplete_stage_a" -and
    [string]$report.complete_evaluation.classification -ceq
        "invalid_or_incomplete_complete_campaign" -and
    $null -eq $report.complete_evaluation.stage_b
) "QSDK-R23D11 retained campaign report changed"

foreach ($expected in @($closure.retained_stage_a_cells)) {
    $cellId = [string]$expected.cell_id
    $cellRoot = Join-Path $EvidenceRoot "stage-a\$cellId"
    $pendingPath = Join-Path $EvidenceRoot (
        "pending-traces\mujoco_stability_assisted_taper_screen__" +
        "$cellId.rows.json"
    )
    foreach ($receipt in @(
        @{ path = Join-Path $cellRoot "process.json"; digest = $expected.process_raw_sha256; label = "process" },
        @{ path = Join-Path $cellRoot "stdout.txt"; digest = $expected.stdout_raw_sha256; label = "stdout" },
        @{ path = Join-Path $cellRoot "stderr.txt"; digest = $expected.stderr_raw_sha256; label = "stderr" },
        @{ path = Join-Path $cellRoot "terminal-entry.json"; digest = $expected.terminal_entry_raw_sha256; label = "terminal" },
        @{ path = $pendingPath; digest = $expected.pending_trace_raw_sha256; label = "pending trace" }
    )) {
        Assert-R23D11ClosureFile `
            -Path ([string]$receipt.path) `
            -ExpectedSha256 ([string]$receipt.digest) `
            -Label "$cellId $([string]$receipt.label)"
    }
    Assert-R23D11Closure (
        (Get-Item -LiteralPath $pendingPath).Length -eq
            [long]$expected.pending_trace_byte_length
    ) "QSDK-R23D11 pending trace length changed: $cellId"
    $terminal = Get-Content -Raw -LiteralPath (
        Join-Path $cellRoot "terminal-entry.json"
    ) | ConvertFrom-Json -AsHashtable -Depth 100
    $process = Get-Content -Raw -LiteralPath (
        Join-Path $cellRoot "process.json"
    ) | ConvertFrom-Json -AsHashtable -Depth 100
    $rows = Get-Content -Raw -LiteralPath $pendingPath |
        ConvertFrom-Json -AsHashtable -Depth 100
    $mismatchRows = @($rows | Where-Object {
        [string]$_.stability_planning_availability -ceq
            "observation_unavailable" -and
        $null -ne $_.minimum_dynamic_support_margin_m
    })
    Assert-R23D11Closure (
        @($rows).Count -eq [int]$expected.pending_trace_row_count -and
        $mismatchRows.Count -eq
            [int]$expected.observation_unavailable_with_finite_support_margin_count -and
        [int]$expected.trace_diagnostic_failure_count -eq $mismatchRows.Count -and
        [int]$expected.trace_diagnostic_failure_class_count -eq 1 -and
        [int]$process.exit_code -eq 1 -and
        -not [bool]$process.timed_out -and
        [string]$terminal.schema_version -ceq
            "sporespore_qsdk_r23d11_worker_failure_v1" -and
        [string]$terminal.failure_stage -ceq "settlement_complete" -and
        [string]$terminal.failure_code -like
            "QSDK_R23D11_MJC_RUNTIME_ERROR:R23D11PhysicalEvaluationError:*" -and
        $null -eq $terminal.trace_artifact -and
        [int]$terminal.world_attempt_count -eq 1 -and
        [int]$terminal.world_build_count -eq 1 -and
        -not [bool]$terminal.claims.command_conditioned_turning -and
        -not [bool]$terminal.claims.physical_acceptance_authority
    ) "QSDK-R23D11 retained invalid cell changed: $cellId"
}

$supervisorText = Get-Content -Raw -LiteralPath (
    Join-Path $sdkRoot "run_qsdk_r23d11_supervisor.ps1"
)
$mujocoText = Get-Content -Raw -LiteralPath (
    Join-Path $sdkRoot (
        "adapters\mujoco\sporespore_mujoco_adapter\" +
        "qsdk_r23d11_stability_assisted_taper_physical.py"
    )
)
$rapierText = Get-Content -Raw -LiteralPath (
    Join-Path $sdkRoot (
        "adapters\rapier\src\qsdk_r23d3_phase_balanced\" +
        "r23d11_physical.rs"
    )
)
$godotText = Get-Content -Raw -LiteralPath (
    Join-Path $repoRoot (
        "tests\test_sdk_qsdk_r23d11_stability_assisted_taper_" +
        "godot_jolt_physical_worker.gd"
    )
)
Assert-R23D11Closure (
    $supervisorText.Contains("r23d11_physical_closure_v1.json") -and
    $supervisorText.Contains("QSDK-R23D11 CLOSED") -and
    $mujocoText.Contains("r23d11_physical_closure_v1.json") -and
    $mujocoText.Contains("QSDK_R23D11_MJC_CLOSED") -and
    $rapierText.Contains("r23d11_physical_closure_v1.json") -and
    $rapierText.Contains("QSDK_R23D11_RAP_CLOSED") -and
    $godotText.Contains("r23d11_physical_closure_v1.json") -and
    $godotText.Contains("QSDK_R23D11_GJT_CLOSED")
) "QSDK-R23D11 physical closure interlocks changed"

Assert-R23D11Closure (
    -not [bool]$closure.immutable_completion_record.scientific_positive -and
    -not [bool]$closure.immutable_completion_record.scientific_negative -and
    [string]$closure.failure_mechanism.classification -ceq
        "producer_validator_trace_diagnostic_semantics_mismatch" -and
    -not [bool]$closure.failure_mechanism.diagnostic_projection_is_scientific_evidence -and
    [string]$closure.successor_boundary.successor_id -ceq "QSDK-R23D12" -and
    [bool]$closure.successor_boundary.new_campaign_and_gate_identity_required -and
    -not [bool]$closure.successor_boundary.r23d11_trace_replay_as_acceptance_permitted -and
    [bool]$closure.successor_boundary.fresh_physical_worlds_required -and
    -not [bool]$closure.claims.command_conditioned_turning -and
    -not [bool]$closure.claims.bilateral_signed_turning -and
    -not [bool]$closure.claims.portable_basic_turning -and
    -not [bool]$closure.claims.cross_engine_equivalence -and
    -not [bool]$closure.claims.q_sdk_r23_satisfied -and
    -not [bool]$closure.claims.prone_to_standing -and
    -not [bool]$closure.claims.release_authorized -and
    -not [bool]$closure.claims.physical_acceptance_authority
) "QSDK-R23D11 claim or successor boundary changed"

Write-Host (
    "QSDK_R23D11_CLOSURE_PASS status=infrastructure-invalid worlds=2 " +
    "traces=2 rows=7784 diagnostics=1832 classes=1 selected=INVALID " +
    "stage_b=0/9 evidence_files=$($tree.file_count) all_cas=True " +
    "same_identity_rerun=False scientific_result=False turning=False " +
    "equivalence=False physical_authority=False"
)
