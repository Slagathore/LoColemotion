#requires -Version 7.0

[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$evidenceRoot = "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence"
$artifactRoot = Join-Path $evidenceRoot "artifacts\sha256"
$qualificationRoot = Join-Path $evidenceRoot (
    "qsdk-r23d67-qualification-20260826T001219Z-5d946908-parent-lock-repair"
)
$attemptRoot = Join-Path $evidenceRoot (
    "qsdk-r23d67-physical-20260826T001932Z-5d946908"
)
$closurePath = Join-Path $repoRoot (
    "sdk\turning\r23d67_authorization_schema_repaired_three_engine_turning_" +
    "validation_closure_v1.json"
)
$auditPath = $PSCommandPath
$releaseContractPath = Join-Path $repoRoot "sdk\release\quadruped_release_contract.json"
$supportMatrixPath = Join-Path $repoRoot "sdk\release\quadruped_support_matrix.json"
$sourceCommit = "5d9469087ab86640a6413ed320c8bcd02ca630e4"
$sourceTree = "d5bbf367069743809fa8667c7d7168afa04dd54f"
$campaignId = (
    "QSDK-R23D67-AUTHORIZATION-SCHEMA-REPAIRED-THREE-ENGINE-" +
    "TURNING-VALIDATION"
)
$closedStatus = (
    "closed_consumed_invalid_incomplete_after_first_godot_jolt_world_" +
    "trace_vocabulary_and_supervisor_process_shape_mismatch"
)
$processFailure = (
    "Method invocation failed because " +
    "[System.Management.Automation.PSCustomObject] does not contain a method " +
    "named 'Contains'."
)
$cellId = "r23d67__godot_jolt__s23181__reference_zero"
$expectedCellIds = @(
    "r23d67__godot_jolt__s23181__reference_zero",
    "r23d67__godot_jolt__s23181__positive_heading",
    "r23d67__godot_jolt__s23181__negative_heading",
    "r23d67__rapier_parry__s23181__reference_zero",
    "r23d67__rapier_parry__s23181__positive_heading",
    "r23d67__rapier_parry__s23181__negative_heading",
    "r23d67__mujoco__s23181__reference_zero",
    "r23d67__mujoco__s23181__positive_heading",
    "r23d67__mujoco__s23181__negative_heading"
)

function Assert-R23D67Closure([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "QSDK-R23D67 CLOSURE: $Message" }
}

function Get-R23D67Sha256([string]$Path) {
    return "sha256:" + (
        Get-FileHash -LiteralPath $Path -Algorithm SHA256
    ).Hash.ToLowerInvariant()
}

function Get-R23D67BytesSha256([byte[]]$Bytes) {
    return "sha256:" + [Convert]::ToHexString(
        [Security.Cryptography.SHA256]::HashData($Bytes)
    ).ToLowerInvariant()
}

function Invoke-R23D67Git([string[]]$Arguments) {
    $lines = @(& git -C $repoRoot @Arguments 2>&1)
    Assert-R23D67Closure ($LASTEXITCODE -eq 0) (
        "git $($Arguments -join ' ') failed: $($lines -join ' ')"
    )
    return ($lines -join "`n").Trim()
}

function Assert-R23D67RetainedBinding($Binding) {
    $path = [IO.Path]::GetFullPath([string]$Binding.path)
    Assert-R23D67Closure (
        (Test-Path -LiteralPath $path -PathType Leaf) -and
        (Get-Item -LiteralPath $path).Length -eq [long]$Binding.byte_length -and
        (Get-R23D67Sha256 $path) -ceq [string]$Binding.raw_sha256
    ) "retained binding changed: $path"
}

function Assert-R23D67CasPayload([string]$Path) {
    $digest = (Get-R23D67Sha256 $Path).Substring(7)
    $payload = Join-Path $artifactRoot "$digest\payload.bin"
    Assert-R23D67Closure (
        (Test-Path -LiteralPath $payload -PathType Leaf) -and
        (Get-Item -LiteralPath $payload).Length -eq
            (Get-Item -LiteralPath $Path).Length -and
        (Get-R23D67Sha256 $payload) -ceq "sha256:$digest"
    ) "CAS payload changed or is missing: $Path"
}

function Test-R23D67ClosureVector($Value) {
    return (
        [string]$Value.schema_version -ceq
            "sporespore_qsdk_r23d67_authorization_schema_repaired_three_engine_turning_validation_closure_v1" -and
        [string]$Value.status -ceq $closedStatus -and
        [string]$Value.campaign_id -ceq $campaignId -and
        [string]$Value.gate_id -ceq "QSDK-R23D67" -and
        [string]$Value.release_gate_id -ceq "QSDK-R23" -and
        [string]$Value.ledger_scope.subsystem -ceq "turning" -and
        [string]$Value.ledger_scope.engine_scope -ceq "3e" -and
        [string]$Value.physical_question_class -ceq "finite_decision" -and
        [string]$Value.observed_failure_question_class -ceq
            "integration_contract_failure" -and
        [string]$Value.source.commit -ceq $sourceCommit -and
        [string]$Value.source.tree_git_oid -ceq $sourceTree -and
        [string]$Value.source.supervisor_git_blob_oid -ceq
            "c1ab675f7ff93913ae46afca96054355ee4e3a09" -and
        [string]$Value.source.runtime_design_git_blob_oid -ceq
            "fbc768e62b1d10401f26bb7a02a707e5b391aefb" -and
        [string]$Value.source.godot_trace_producer_git_blob_oid -ceq
            "e5f67de6d99ddf068cce753f9a68bb4aabb028a4" -and
        [string]$Value.source.evaluator_git_blob_oid -ceq
            "fcc86d22a880cdd44f92a2f3d9950e50fc9d9b2b" -and
        [bool]$Value.source.clean_pushed_live_equal_at_launch -and
        [int]$Value.qualification.complete_retained_file_count -eq 50 -and
        [long]$Value.qualification.complete_retained_byte_count -eq 493789 -and
        [int]$Value.qualification.executed_gate_count -eq 16 -and
        [bool]$Value.qualification.qualification_passed -and
        [bool]$Value.qualification.adoption_passed -and
        [bool]$Value.qualification.physical_launch_prerequisite_satisfied -and
        [int]$Value.qualification.world_build_count -eq 0 -and
        -not [bool]$Value.qualification.physical_acceptance_authority -and
        [string]$Value.attempt.attempt_id -ceq
            "100036bf0be24d40a3a7423a595a4cd7" -and
        [int]$Value.attempt.campaign_seed -eq 23181 -and
        [bool]$Value.attempt.campaign_identity_consumed -and
        -not [bool]$Value.attempt.same_identity_rerun_allowed -and
        -not [bool]$Value.attempt.replacement_or_selective_rerun_allowed -and
        [bool]$Value.attempt.physical_execution_observation_exists -and
        [bool]$Value.attempt.behavioral_measurement_exposed -and
        [int]$Value.frozen_input_population.source_binding_count -eq 206 -and
        [int]$Value.frozen_input_population.runtime_binding_count -eq 8 -and
        [int]$Value.frozen_input_population.complete_content_addressed_input_count -eq 215 -and
        [int]$Value.retained_evidence.complete_file_population_count -eq 27 -and
        [long]$Value.retained_evidence.complete_file_population_byte_count -eq 16423522 -and
        [int]$Value.retained_evidence.retained_unique_digest_count -eq 18 -and
        [int]$Value.retained_evidence.explicitly_cas_backed_file_count -eq 25 -and
        [int]$Value.retained_evidence.non_cas_retained_file_count -eq 2 -and
        [int]$Value.retained_evidence.canonical_population_manifest_byte_length -eq 3897 -and
        [string]$Value.retained_evidence.canonical_population_manifest_sha256 -ceq
            "sha256:4ba642c67f3698c99efbb0e48c506e981d58c5d0e375430a6fccfbd56738eca0" -and
        [int]$Value.authorization_population.retained_receipt_count -eq 9 -and
        [int]$Value.authorization_population.accepted_receipt_count -eq 9 -and
        [bool]$Value.authorization_population.complete_matrix_passed -and
        [int]$Value.authorization_population.physical_worker_process_count -eq 1 -and
        [int]$Value.authorization_population.retained_physical_cell_terminal_count -eq 1 -and
        [int]$Value.authorization_population.completion_retained_cell_count -eq 0 -and
        [int]$Value.first_world_observation.actual_row_count -eq 2992 -and
        [int]$Value.first_world_observation.producer_segment_counts.after_declared_schedule -eq 592 -and
        -not [bool]$Value.first_world_observation.canonical_trace_artifact_created -and
        [int]@($Value.failure_mechanisms).Count -eq 2 -and
        [string]$Value.failure_mechanisms[0].producer_segment_id -ceq
            "after_declared_schedule" -and
        [string]$Value.failure_mechanisms[0].evaluator_expected_segment_id -ceq
            "reference_continuation" -and
        [int]$Value.failure_mechanisms[0].affected_row_count -eq 592 -and
        [string]$Value.failure_mechanisms[1].invalid_method_call -ceq "Contains" -and
        [string]$Value.failure_mechanisms[1].exact_failure_message -ceq
            $processFailure -and
        -not [bool]$Value.official_result.scientific_result_exists -and
        [bool]$Value.official_result.physical_execution_observation_exists -and
        -not [bool]$Value.official_result.q_sdk_r23_satisfied -and
        [string]$Value.official_result.release_score_before -ceq "10/25" -and
        [string]$Value.official_result.release_score_after -ceq "10/25" -and
        [bool]$Value.successor_boundary.distinct_successor_required -and
        -not [bool]$Value.successor_boundary.same_seed_reuse_allowed -and
        -not [bool]$Value.successor_boundary.selective_completion_allowed -and
        [int]@($Value.successor_boundary.minimum_integration_repair_population).Count -eq 4 -and
        [bool]$Value.claims.campaign_closed -and
        [bool]$Value.claims.retained_evidence_complete -and
        [bool]$Value.claims.campaign_identity_consumed -and
        -not [bool]$Value.claims.historical_result_reinterpreted -and
        [bool]$Value.claims.one_native_world_observed -and
        -not [bool]$Value.claims.turning_claimed -and
        -not [bool]$Value.claims.physical_acceptance_authority
    )
}

Assert-R23D67Closure (
    (Invoke-R23D67Git @("rev-parse", "--show-toplevel")) -ceq
        $repoRoot.Replace("\", "/") -and
    (Invoke-R23D67Git @("remote", "get-url", "origin")) -ceq
        "https://github.com/Slagathore/sporespore.git"
) "repository identity changed"
foreach ($path in @($qualificationRoot, $attemptRoot, $closurePath, $auditPath)) {
    Assert-R23D67Closure (Test-Path -LiteralPath $path) "path is missing: $path"
}

$closure = Get-Content -LiteralPath $closurePath -Raw |
    ConvertFrom-Json -AsHashtable -Depth 100
Assert-R23D67Closure (Test-R23D67ClosureVector $closure) "closure claim vector changed"
Assert-R23D67Closure (
    (Invoke-R23D67Git @("rev-parse", "$sourceCommit^{tree}")) -ceq $sourceTree -and
    (Invoke-R23D67Git @("rev-parse", "$sourceCommit`:sdk/run_qsdk_r23d67_supervisor.ps1")) -ceq
        [string]$closure.source.supervisor_git_blob_oid -and
    (Invoke-R23D67Git @("rev-parse", "$sourceCommit`:sdk/turning/r23d67_production_route_runtime.py")) -ceq
        [string]$closure.source.runtime_design_git_blob_oid -and
    (Invoke-R23D67Git @("rev-parse", "$sourceCommit`:scripts/lab/gait/physical_wave_gait_quadruped.gd")) -ceq
        [string]$closure.source.godot_trace_producer_git_blob_oid -and
    (Invoke-R23D67Git @("rev-parse", "$sourceCommit`:sdk/turning/r23d67_production_route_three_engine_turning_evaluator.py")) -ceq
        [string]$closure.source.evaluator_git_blob_oid
) "consumed source identity changed"
$sourceSupervisor = Invoke-R23D67Git @(
    "show", "$sourceCommit`:sdk/run_qsdk_r23d67_supervisor.ps1"
)
$sourceRuntime = Invoke-R23D67Git @(
    "show", "$sourceCommit`:sdk/turning/r23d67_production_route_runtime.py"
)
$sourceProducer = Invoke-R23D67Git @(
    "show", "$sourceCommit`:scripts/lab/gait/physical_wave_gait_quadruped.gd"
)
$sourceEvaluator = Invoke-R23D67Git @(
    "show", "$sourceCommit`:sdk/turning/r23d67_production_route_three_engine_turning_evaluator.py"
)
Assert-R23D67Closure (
    $sourceRuntime -cmatch 'return "reference_continuation", 0\.0' -and
    $sourceRuntime -cmatch '"reference_continuation": 592' -and
    $sourceProducer -cmatch 'segment_id = "after_declared_schedule"' -and
    $sourceEvaluator -cmatch 'inherited\.design = design' -and
    $sourceSupervisor -cmatch '\$process\.Contains\("host_exit_code"\)' -and
    $sourceSupervisor -cmatch '\$process\.Contains\("supervisor_terminated"\)' -and
    $sourceSupervisor -cmatch '\$process\.Contains\("termination_protocol_valid"\)'
) "observed production integration mismatches changed"

Assert-R23D67RetainedBinding $closure.qualification.attestation
Assert-R23D67RetainedBinding $closure.qualification.adoption
$qualificationFiles = @(Get-ChildItem -LiteralPath $qualificationRoot -Recurse -File)
Assert-R23D67Closure (
    $qualificationFiles.Count -eq 50 -and
    [long](($qualificationFiles | Measure-Object Length -Sum).Sum) -eq 493789
) "qualification retained population changed"
$attestation = Get-Content -LiteralPath ([string]$closure.qualification.attestation.path) -Raw |
    ConvertFrom-Json -AsHashtable -Depth 100
$adoption = Get-Content -LiteralPath ([string]$closure.qualification.adoption.path) -Raw |
    ConvertFrom-Json -AsHashtable -Depth 100
Assert-R23D67Closure (
    [string]$attestation.status -ceq
        "campaign_local_godot_including_qualification_passed" -and
    [string]$attestation.source.commit -ceq $sourceCommit -and
    [bool]$attestation.source.clean_pushed_live -and
    [int]$attestation.global_gate_count -eq 12 -and
    [int]$attestation.lineage_gate_count -eq 1 -and
    [int]$attestation.campaign_gate_count -eq 3 -and
    [int]$attestation.executed_gate_count -eq 16 -and
    [bool]$attestation.all_gates_executed -and
    [bool]$attestation.all_gate_streams_content_addressed -and
    [int]$attestation.declared_physical_world_count -eq 9 -and
    -not [bool]$attestation.claims.physical_campaign_executed -and
    -not [bool]$attestation.claims.turning_acceptance -and
    [string]$adoption.status -ceq
        "commissioned_campaign_local_qualification_adopted_for_physical_launch" -and
    [string]$adoption.source_commit -ceq $sourceCommit -and
    [int]$adoption.executed_gate_count -eq 16 -and
    [int]$adoption.gate_cas_object_count -eq 48 -and
    [bool]$adoption.physical_launch_prerequisite_satisfied -and
    -not [bool]$adoption.physical_acceptance_authority -and
    -not [bool]$adoption.release_authority
) "qualification or adoption semantics changed"

$attemptFiles = @(Get-ChildItem -LiteralPath $attemptRoot -Recurse -File |
    Sort-Object { $_.FullName.Substring($attemptRoot.Length + 1).Replace("\", "/") })
$relativePaths = @($attemptFiles | ForEach-Object {
    $_.FullName.Substring($attemptRoot.Length + 1).Replace("\", "/")
})
Assert-R23D67Closure (
    $attemptFiles.Count -eq 27 -and
    [long](($attemptFiles | Measure-Object Length -Sum).Sum) -eq 16423522 -and
    ($relativePaths -join "`n") -ceq
        (@($closure.retained_evidence.ordered_relative_paths) -join "`n")
) "complete retained physical population changed"
$manifestText = ($attemptFiles | ForEach-Object {
    $relative = $_.FullName.Substring($attemptRoot.Length + 1).Replace("\", "/")
    "$relative`t$($_.Length)`t$(Get-R23D67Sha256 $_.FullName)`n"
}) -join ""
$manifestBytes = [Text.UTF8Encoding]::new($false).GetBytes($manifestText)
$uniqueDigests = @($attemptFiles | ForEach-Object {
    Get-R23D67Sha256 $_.FullName
} | Sort-Object -Unique)
Assert-R23D67Closure (
    $manifestBytes.Length -eq 3897 -and
    (Get-R23D67BytesSha256 $manifestBytes) -ceq
        "sha256:4ba642c67f3698c99efbb0e48c506e981d58c5d0e375430a6fccfbd56738eca0" -and
    $uniqueDigests.Count -eq 18
) "canonical retained-population manifest changed"
$nonCasPaths = @(
    "completion.json",
    "pending-traces/r23d67__godot_jolt__s23181__reference_zero.rows.json"
)
foreach ($file in $attemptFiles) {
    $relative = $file.FullName.Substring($attemptRoot.Length + 1).Replace("\", "/")
    if ($nonCasPaths -cnotcontains $relative) {
        Assert-R23D67CasPayload $file.FullName
    }
}

$freeze = Get-Content -LiteralPath ([string]$closure.attempt.physical_freeze.path) -Raw |
    ConvertFrom-Json -AsHashtable -Depth 100
$attempt = Get-Content -LiteralPath ([string]$closure.attempt.attempt_authorization.path) -Raw |
    ConvertFrom-Json -AsHashtable -Depth 100
$authorization = Get-Content -LiteralPath ([string]$closure.attempt.authorization_preflight.path) -Raw |
    ConvertFrom-Json -AsHashtable -Depth 100
$completion = Get-Content -LiteralPath ([string]$closure.attempt.completion.path) -Raw |
    ConvertFrom-Json -AsHashtable -Depth 100
foreach ($binding in @(
    $closure.attempt.physical_freeze,
    $closure.attempt.attempt_authorization,
    $closure.attempt.authorization_preflight,
    $closure.attempt.completion,
    $closure.first_world_observation.terminal,
    $closure.first_world_observation.pending_rows,
    $closure.first_world_observation.trace_diagnostic
)) { Assert-R23D67RetainedBinding $binding }
Assert-R23D67Closure (
    [string]$freeze.status -ceq "frozen_supervisor_only_physical_authorized" -and
    [string]$freeze.source_commit -ceq $sourceCommit -and
    [string]$freeze.source_tree_git_oid -ceq $sourceTree -and
    [int]@($freeze.implementation_dependency_digests.Keys).Count -eq 206 -and
    [int]@($freeze.source_bindings).Count -eq 206 -and
    [int]@($freeze.runtime_artifacts).Count -eq 3 -and
    [int]@($freeze.external_runtime_bindings).Count -eq 5 -and
    [int]@($freeze.content_addressed_inputs.source_bindings).Count -eq 206 -and
    [int]@($freeze.content_addressed_inputs.runtime_bindings).Count -eq 8 -and
    [int]$freeze.declared_world_count -eq 9 -and
    [bool]$freeze.physical_behavior_thresholds_applied -and
    -not [bool]$freeze.posthoc_threshold_or_selector_change_performed -and
    [bool]$freeze.source_checkout_bytes_equal_git_blobs -and
    [bool]$freeze.reproducible_runtime_materialization_passed -and
    [bool]$freeze.physical_execution_authorized -and
    -not [bool]$freeze.physical_acceptance_authority -and
    (@($freeze.ordered_cell_ids) -join "`n") -ceq ($expectedCellIds -join "`n")
) "physical freeze changed"
Assert-R23D67Closure (
    [string]$attempt.attempt_id -ceq "100036bf0be24d40a3a7423a595a4cd7" -and
    [string]$attempt.source_commit -ceq $sourceCommit -and
    [bool]$attempt.physical_execution_authorized -and
    [bool]$attempt.single_use_supervisor_authorization -and
    [bool]$attempt.one_shot_attempt_unconsumed -and
    [bool]$attempt.operation_lock_held -and
    [bool]$attempt.campaign_attestation_adoption_valid -and
    [bool]$attempt.content_addressed_inputs_retained -and
    -not [bool]$attempt.physical_acceptance_authority
) "attempt authorization changed"
Assert-R23D67Closure (
    [int]$authorization.receipt_count -eq 9 -and
    [int]$authorization.pass_count -eq 9 -and
    [bool]$authorization.complete_matrix_passed -and
    [int]$authorization.model_construction_count -eq 0 -and
    [int]$authorization.world_attempt_count -eq 0 -and
    [int]$authorization.world_build_count -eq 0 -and
    (@($authorization.ordered_receipts.cell_id) -join "`n") -ceq
        ($expectedCellIds -join "`n")
) "authorization population changed"
foreach ($receipt in @($authorization.ordered_receipts)) {
    Assert-R23D67Closure (
        [bool]$receipt.valid -and
        [int]$receipt.process.exit_code -eq 0 -and
        -not [bool]$receipt.process.timed_out -and
        [bool]$receipt.worker_receipt.ok -and
        [bool]$receipt.worker_receipt.authorization_passed -and
        [bool]$receipt.worker_receipt.returned_before_model -and
        [int]$receipt.worker_receipt.model_construction_count -eq 0 -and
        [int]$receipt.worker_receipt.world_attempt_count -eq 0 -and
        [int]$receipt.worker_receipt.world_build_count -eq 0
    ) "worker authorization receipt changed: $($receipt.cell_id)"
}
Assert-R23D67Closure (
    [string]$completion.status -ceq "invalid_or_incomplete_first_attempt" -and
    [string]$completion.attempt_id -ceq [string]$attempt.attempt_id -and
    [string]$completion.source_commit -ceq $sourceCommit -and
    [int]$completion.retained_cell_count -eq 0 -and
    [bool]$completion.one_shot_attempt_consumed -and
    -not [bool]$completion.replacement_or_selective_rerun_permitted -and
    [string]$completion.failure_message -ceq $processFailure -and
    -not [bool]$completion.physical_acceptance_authority
) "consumed completion changed"

$terminal = Get-Content -LiteralPath ([string]$closure.first_world_observation.terminal.path) -Raw |
    ConvertFrom-Json -AsHashtable -Depth 100
$diagnostic = Get-Content -LiteralPath ([string]$closure.first_world_observation.trace_diagnostic.path) -Raw |
    ConvertFrom-Json -AsHashtable -Depth 100
$rows = @(Get-Content -LiteralPath ([string]$closure.first_world_observation.pending_rows.path) -Raw |
    ConvertFrom-Json -AsHashtable -Depth 100)
Assert-R23D67Closure (
    [string]$terminal.schema_version -ceq
        "sporespore_qsdk_r23d67_worker_failure_v1" -and
    [string]$terminal.source_commit -ceq $sourceCommit -and
    [string]$terminal.cell_id -ceq $cellId -and
    [string]$terminal.engine_id -ceq "godot_jolt" -and
    [string]$terminal.arm_id -ceq "reference_zero" -and
    [string]$terminal.failure_stage -ceq "controller_horizon_complete" -and
    [string]$terminal.failure_code -ceq
        "QSDK_R23D67_GJT_TRACE_RETENTION_FAILED:1" -and
    [int]$terminal.model_construction_count -eq 0 -and
    [int]$terminal.world_attempt_count -eq 1 -and
    [int]$terminal.world_build_count -eq 1 -and
    $null -eq $terminal.trace_artifact -and
    [string]$terminal.trace_diagnostic_artifact.sha256 -ceq
        [string]$closure.first_world_observation.trace_diagnostic.raw_sha256 -and
    -not [bool]$terminal.claims.finite_three_engine_turning -and
    -not [bool]$terminal.claims.q_sdk_r23_satisfied -and
    -not [bool]$terminal.physical_acceptance_authority
) "first worker terminal changed"
Assert-R23D67Closure (
    [string]$diagnostic.schema_version -ceq
        "sporespore_qsdk_r23d67_trace_diagnostic_v1" -and
    [string]$diagnostic.cell_id -ceq $cellId -and
    [bool]$diagnostic.complete -and
    [bool]$diagnostic.partial_rows_retained -and
    [bool]$diagnostic.retained_before_terminal_entry -and
    [int]$diagnostic.declared_row_count -eq 2992 -and
    [int]$diagnostic.reported_row_count -eq 2992 -and
    [int]$diagnostic.actual_row_count -eq 2992 -and
    [int]$diagnostic.contiguous_row_count -eq 2992 -and
    [int]$diagnostic.first_valid_semantic_step -eq 0 -and
    [int]$diagnostic.last_valid_semantic_step -eq 2991 -and
    [int]$diagnostic.first_missing_semantic_step -eq 2992 -and
    [int]@($diagnostic.failure_codes).Count -eq 0 -and
    [string]$diagnostic.trace_retention_failure_code -ceq
        "QSDK_R23D67_GJT_TRACE_RETENTION_FAILED:1" -and
    [string]@($diagnostic.trace_retention_failure_detail.output)[0] -cmatch
        'R23D34_TRACE_ROW_INVALID:2400'
) "trace diagnostic changed"
Assert-R23D67Closure ($rows.Count -eq 2992) "pending row population changed"
$segmentCounts = @{}
for ($index = 0; $index -lt $rows.Count; $index++) {
    $row = $rows[$index]
    Assert-R23D67Closure (
        [int]$row.semantic_step -eq $index -and
        [string]$row.cell_id -ceq $cellId -and
        [string]$row.engine_id -ceq "godot_jolt"
    ) "pending row identity changed at $index"
    $segment = [string]$row.segment_id
    if (-not $segmentCounts.ContainsKey($segment)) { $segmentCounts[$segment] = 0 }
    $segmentCounts[$segment] += 1
}
Assert-R23D67Closure (
    $segmentCounts.Count -eq 4 -and
    [int]$segmentCounts.reference_warmup -eq 600 -and
    [int]$segmentCounts.commanded_turn -eq 1200 -and
    [int]$segmentCounts.reference_recovery -eq 600 -and
    [int]$segmentCounts.after_declared_schedule -eq 592 -and
    [string]$rows[2399].segment_id -ceq "reference_recovery" -and
    [string]$rows[2400].segment_id -ceq "after_declared_schedule" -and
    [string]$rows[2991].segment_id -ceq "after_declared_schedule"
) "observed trace segment population changed"

$release = Get-Content -LiteralPath $releaseContractPath -Raw |
    ConvertFrom-Json -AsHashtable -Depth 100
$support = Get-Content -LiteralPath $supportMatrixPath -Raw |
    ConvertFrom-Json -AsHashtable -Depth 100
$turningGate = @($release.gates | Where-Object {
    [string]$_.gate_id -ceq "QSDK-R23"
})[0]
$releaseLifecycle = $turningGate.proof.
    prospective_r23d67_authorization_schema_repaired_three_engine_turning_validation
$supportLifecycle = $support.locomotion_modes.three_engine_turning_production_route.
    current_prospective_held_out_successor
$nestedSupportLifecycle = $support.locomotion_modes.heading_command_physical_development.
    scientifically_distinct_successor.stage_zero_successor.terminal_stabilization_successor.
    dependency_closed_successor.policy_compatible_restoration_successor.
    neutral_stance_successor.authorization_closed_successor.scientifically_distinct_successor.
    next_scientifically_distinct_successor.consumed_r23d12_successor.
    prospective_r23d67_authorization_schema_repaired_three_engine_turning_validation
foreach ($lifecycle in @($releaseLifecycle, $supportLifecycle, $nestedSupportLifecycle)) {
    Assert-R23D67Closure (
        [string]$lifecycle.current_lifecycle_status -ceq $closedStatus -and
        [string]$lifecycle.current_lifecycle.closure_path -ceq
            "sdk/turning/r23d67_authorization_schema_repaired_three_engine_turning_validation_closure_v1.json" -and
        [string]$lifecycle.current_lifecycle.closure_raw_sha256 -ceq
            (Get-R23D67Sha256 $closurePath) -and
        [string]$lifecycle.current_lifecycle.closure_audit_path -ceq
            "tests/test_qsdk_r23d67_physical_closure.ps1" -and
        [string]$lifecycle.current_lifecycle.closure_audit_raw_sha256 -ceq
            (Get-R23D67Sha256 $auditPath) -and
        [int]$lifecycle.current_lifecycle.qualification_gate_pass_count -eq 16 -and
        [int]$lifecycle.current_lifecycle.authorization_receipt_count -eq 9 -and
        [int]$lifecycle.current_lifecycle.authorization_pass_count -eq 9 -and
        [int]$lifecycle.current_lifecycle.physical_worker_process_count -eq 1 -and
        [int]$lifecycle.current_lifecycle.world_attempt_count -eq 1 -and
        [int]$lifecycle.current_lifecycle.world_build_count -eq 1 -and
        [int]$lifecycle.current_lifecycle.retained_row_count -eq 2992 -and
        [int]$lifecycle.current_lifecycle.affected_segment_row_count -eq 592 -and
        [bool]$lifecycle.current_lifecycle.campaign_identity_consumed -and
        -not [bool]$lifecycle.current_lifecycle.q_sdk_r23_satisfied -and
        -not [bool]$lifecycle.current_lifecycle.physical_acceptance_authority
    ) "release lifecycle closure changed"
}

$mutationControls = 0
foreach ($mutation in @(
    @{ path = "status"; value = "passing" },
    @{ path = "attempt.same_identity_rerun_allowed"; value = $true },
    @{ path = "authorization_population.accepted_receipt_count"; value = 8 },
    @{ path = "first_world_observation.actual_row_count"; value = 2991 },
    @{ path = "failure_mechanisms.0.affected_row_count"; value = 591 },
    @{ path = "official_result.q_sdk_r23_satisfied"; value = $true },
    @{ path = "claims.turning_claimed"; value = $true },
    @{ path = "claims.physical_acceptance_authority"; value = $true }
)) {
    $copy = $closure | ConvertTo-Json -Depth 100 |
        ConvertFrom-Json -AsHashtable -Depth 100
    $parts = [string]$mutation.path -split '\.'
    $target = $copy
    for ($index = 0; $index -lt $parts.Count - 1; $index++) {
        $part = $parts[$index]
        if ($part -match '^\d+$') { $target = $target[[int]$part] }
        else { $target = $target[$part] }
    }
    $target[$parts[-1]] = $mutation.value
    Assert-R23D67Closure (-not (Test-R23D67ClosureVector $copy)) (
        "mutation was accepted: $($mutation.path)"
    )
    $mutationControls += 1
}

Write-Output (
    "[turning/3e] PASS R23D67 immutable physical closure: " +
    "qualification=16/16 adoption=True authorization=9/9 worlds=1/9 " +
    "rows=2992 mismatch_rows=592 files=27 bytes=16423522 " +
    "mutations=$mutationControls turning=False QSDK-R23=False score=10/25"
)
