#requires -Version 7.0

[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$evidenceRoot = "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence"
$artifactRoot = Join-Path $evidenceRoot "artifacts\sha256"
$attemptRoot = Join-Path $evidenceRoot (
    "qsdk-r23d64-physical-20260825T120152Z-8277ab3e"
)
$qualificationRoot = Join-Path $evidenceRoot (
    "qsdk-r23d64-qualification-20260825T114823Z-8277ab3e"
)
$closurePath = Join-Path $repoRoot (
    "sdk\turning\r23d64_selected_profile_three_engine_turning_validation_closure_v1.json"
)
$sourceCommit = "8277ab3e934561902bd375f7bcaf263ac7fae231"
$sourceTree = "0aa240e74791df0d49a201c95bcc4179d0cab6b6"
$attemptId = "9629fdfcbe9249a98b0c45213b58fc89"
$campaignId = (
    "QSDK-R23D64-RAPIER-LAUNCH-CONTRACT-REPAIRED-SELECTED-PROFILE-" +
    "MATCHED-THREE-ENGINE-TURNING-VALIDATION"
)
$profileId = "sporespore_qsdk_r23d60_selected_s169_actuator_cap_profile_v1"
$closedStatus = (
    "closed_consumed_invalid_incomplete_after_six_worlds_" +
    "three_engine_integration_failures"
)
$expectedCells = @(
    [pscustomobject]@{ engine = "godot_jolt"; arm = "reference_zero"; offset = 0.0 },
    [pscustomobject]@{ engine = "godot_jolt"; arm = "positive_heading"; offset = 0.2 },
    [pscustomobject]@{ engine = "godot_jolt"; arm = "negative_heading"; offset = -0.2 },
    [pscustomobject]@{ engine = "rapier_parry"; arm = "reference_zero"; offset = 0.0 },
    [pscustomobject]@{ engine = "rapier_parry"; arm = "positive_heading"; offset = 0.2 },
    [pscustomobject]@{ engine = "rapier_parry"; arm = "negative_heading"; offset = -0.2 },
    [pscustomobject]@{ engine = "mujoco"; arm = "reference_zero"; offset = 0.0 },
    [pscustomobject]@{ engine = "mujoco"; arm = "positive_heading"; offset = 0.2 },
    [pscustomobject]@{ engine = "mujoco"; arm = "negative_heading"; offset = -0.2 }
)
$expectedCellIds = @(
    $expectedCells | ForEach-Object {
        "$($_.engine)__s23171__selected_profile__$($_.arm)"
    }
)
$casVerified = @{}

function Assert-R23D64Closure([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "QSDK-R23D64 CLOSURE: $Message" }
}

function Get-R23D64Sha256([string]$Path) {
    return "sha256:" + (
        Get-FileHash -LiteralPath $Path -Algorithm SHA256
    ).Hash.ToLowerInvariant()
}

function Get-R23D64BytesSha256([byte[]]$Bytes) {
    return "sha256:" + [Convert]::ToHexString(
        [Security.Cryptography.SHA256]::HashData($Bytes)
    ).ToLowerInvariant()
}

function Get-R23D64GitBlobBytes([string]$Commit, [string]$RelativePath) {
    $start = [Diagnostics.ProcessStartInfo]::new()
    $start.FileName = "git"
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    foreach ($argument in @(
        "-C", $repoRoot, "cat-file", "blob", "${Commit}:$RelativePath"
    )) { [void]$start.ArgumentList.Add($argument) }
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $start
    Assert-R23D64Closure ($process.Start()) "could not start git cat-file"
    $memory = [IO.MemoryStream]::new()
    try {
        $process.StandardOutput.BaseStream.CopyTo($memory)
        $stderr = $process.StandardError.ReadToEnd()
        $process.WaitForExit()
        Assert-R23D64Closure ($process.ExitCode -eq 0) (
            "historical blob unavailable: $RelativePath; $stderr"
        )
        return ,([byte[]]$memory.ToArray())
    } finally {
        $memory.Dispose()
        $process.Dispose()
    }
}

function Assert-R23D64Cas([string]$Sha256, [long]$ByteLength) {
    Assert-R23D64Closure ($Sha256 -cmatch '^sha256:[0-9a-f]{64}$') (
        "invalid CAS digest: $Sha256"
    )
    if ($casVerified.ContainsKey($Sha256)) {
        Assert-R23D64Closure (
            [long]$casVerified[$Sha256] -eq $ByteLength
        ) "one digest declared with multiple byte lengths: $Sha256"
        return
    }
    $directory = Join-Path $artifactRoot $Sha256.Substring(7)
    $payload = Join-Path $directory "payload.bin"
    $manifestPath = Join-Path $directory "manifest.json"
    Assert-R23D64Closure (
        (Test-Path -LiteralPath $payload -PathType Leaf) -and
        (Test-Path -LiteralPath $manifestPath -PathType Leaf) -and
        (Get-Item -LiteralPath $payload).Length -eq $ByteLength -and
        (Get-R23D64Sha256 $payload) -ceq $Sha256
    ) "CAS payload changed: $Sha256"
    $manifest = Get-Content -LiteralPath $manifestPath -Raw |
        ConvertFrom-Json -Depth 20
    Assert-R23D64Closure (
        [string]$manifest.schema_version -ceq
            "sporespore_content_addressed_artifact_manifest_v1" -and
        [string]$manifest.algorithm -ceq "sha256" -and
        [string]$manifest.sha256 -ceq $Sha256 -and
        [long]$manifest.byte_length -eq $ByteLength -and
        [string]$manifest.payload_name -ceq "payload.bin"
    ) "CAS manifest changed: $Sha256"
    $casVerified[$Sha256] = $ByteLength
}

function Assert-R23D64RetainedFile($File) {
    $relative = ([string]$File.relative_path).Replace(
        '/', [IO.Path]::DirectorySeparatorChar
    )
    $path = Join-Path $attemptRoot $relative
    Assert-R23D64Closure (
        (Test-Path -LiteralPath $path -PathType Leaf) -and
        (Get-Item -LiteralPath $path).Length -eq [long]$File.byte_length -and
        (Get-R23D64Sha256 $path) -ceq [string]$File.raw_sha256
    ) "retained file changed: $relative"
    Assert-R23D64Cas ([string]$File.raw_sha256) ([long]$File.byte_length)
}

function Get-R23D64WorkerMarker([string]$CellId, [string]$EngineId) {
    $prefix = switch ($EngineId) {
        "godot_jolt" { "QSDK_R23D64_GODOT_JOLT_TERMINAL " }
        "rapier_parry" { "QSDK_R23D64_RAPIER_TERMINAL " }
        "mujoco" { "QSDK_R23D64_MUJOCO_TERMINAL " }
        default { throw "unknown engine: $EngineId" }
    }
    $stdoutPath = Join-Path $attemptRoot "cells\$CellId\stdout.txt"
    $lines = @(
        Get-Content -LiteralPath $stdoutPath |
            Where-Object { $_.StartsWith($prefix) }
    )
    Assert-R23D64Closure ($lines.Count -eq 1) (
        "worker marker count changed: $CellId"
    )
    return $lines[0].Substring($prefix.Length) | ConvertFrom-Json -Depth 100
}

function Test-R23D64ClosureVector($Value) {
    return (
        [string]$Value.schema_version -ceq
            "sporespore_qsdk_r23d64_selected_profile_three_engine_turning_validation_closure_v1" -and
        [string]$Value.status -ceq $closedStatus -and
        [string]$Value.campaign_id -ceq $campaignId -and
        [string]$Value.gate_id -ceq "QSDK-R23D64" -and
        [string]$Value.release_gate_id -ceq "QSDK-R23" -and
        [string]$Value.physical_question_class -ceq "finite_decision" -and
        [string]$Value.runtime_integration_conformance_question_class -ceq
            "equivalence_non_inferiority" -and
        [string]$Value.source_commit -ceq $sourceCommit -and
        [string]$Value.source_tree_git_oid -ceq $sourceTree -and
        [string]$Value.attempt_id -ceq $attemptId -and
        [int]$Value.campaign_seed -eq 23171 -and
        [bool]$Value.campaign_identity_consumed -and
        -not [bool]$Value.same_identity_rerun_allowed -and
        -not [bool]$Value.replacement_or_selective_rerun_allowed -and
        [bool]$Value.physical_outcome_exposed -and
        [bool]$Value.held_out_seed_physical_outcome_exposed -and
        [bool]$Value.held_out_condition_consumed -and
        -not [bool]$Value.successor_campaign_opened_at_closure -and
        [bool]$Value.qualification.qualification_passed -and
        [bool]$Value.qualification.adoption_passed -and
        [int]$Value.qualification.global_gate_count -eq 12 -and
        [int]$Value.qualification.lineage_gate_count -eq 9 -and
        [int]$Value.qualification.campaign_gate_count -eq 3 -and
        [int]$Value.qualification.executed_gate_count -eq 24 -and
        [int]$Value.qualification.gate_cas_object_count -eq 72 -and
        [int]$Value.qualification.world_build_count -eq 0 -and
        [bool]$Value.declaration_and_zero_world_provenance.complete_zero_world_gate_passed -and
        [int]$Value.declaration_and_zero_world_provenance.transitive_path_count -eq 233 -and
        [int]$Value.declaration_and_zero_world_provenance.transitive_edge_count -eq 229 -and
        [int]$Value.declaration_and_zero_world_provenance.worker_preflight_count -eq 9 -and
        [int]$Value.declaration_and_zero_world_provenance.world_build_count -eq 0 -and
        [int]$Value.physical_evidence.complete_retained_file_population_count -eq 60 -and
        [long]$Value.physical_evidence.complete_retained_file_population_byte_count -eq 265254983 -and
        [int]$Value.physical_evidence.retained_unique_digest_count -eq 44 -and
        [int]$Value.physical_evidence.cas_backed_file_count -eq 60 -and
        [int]$Value.physical_evidence.authorization_preflight_receipt_count -eq 9 -and
        [int]$Value.physical_evidence.physical_cell_process_count -eq 9 -and
        [int]$Value.physical_evidence.worker_terminal_marker_count -eq 9 -and
        [int]$Value.physical_evidence.supervisor_terminal_entry_count -eq 9 -and
        [int]$Value.physical_evidence.canonical_rapier_trace_count -eq 3 -and
        [int]$Value.physical_evidence.canonical_rapier_trace_row_count_each -eq 2992 -and
        [int]$Value.physical_evidence.actual_worker_reported_world_attempt_count -eq 6 -and
        [int]$Value.physical_evidence.actual_worker_reported_world_build_count -eq 6 -and
        [int]$Value.physical_evidence.execution_valid_cell_count -eq 0 -and
        [int]$Value.physical_evidence.turning_evaluated_cell_count -eq 0 -and
        [string]$Value.failure_mechanisms.godot_jolt.worker_failure_code -ceq
            "QSDK_R23D64_GJT_TRACE_INCOMPLETE" -and
        [string]$Value.failure_mechanisms.godot_jolt.underlying_sdk_authority_failure_code -ceq
            "QSDK_R23D64_GJT_PUBLIC_PROFILE_BINDING_INVALID" -and
        [int]$Value.failure_mechanisms.godot_jolt.world_build_count -eq 3 -and
        [int]$Value.failure_mechanisms.godot_jolt.sdk_authority_step_count -eq 0 -and
        [string]$Value.failure_mechanisms.rapier_parry.trace_retention_failure -ceq
            "R23D34_TRACE_CAS_FAILED:1:SecurityError: AuthorizationManager check failed." -and
        [int]$Value.failure_mechanisms.rapier_parry.world_build_count -eq 3 -and
        [int]$Value.failure_mechanisms.rapier_parry.canonical_trace_row_count_each -eq 2992 -and
        -not [bool]$Value.failure_mechanisms.rapier_parry.post_attempt_trace_evaluation_performed -and
        [string]$Value.failure_mechanisms.mujoco.worker_failure_code -ceq
            "QSDK_R23D3_MJC_PREFLIGHT_ERROR:KeyError:'command_schedule'" -and
        [int]$Value.failure_mechanisms.mujoco.world_build_count -eq 0 -and
        [string]$Value.failure_mechanisms.aggregate.failure_class -ceq
            "strict_complete_identity_gate_rejected_six_identity_incomplete_failure_terminals" -and
        -not [bool]$Value.failure_mechanisms.aggregate.scientific_result_created -and
        [int]$Value.runtime_integration_conformance.worker_terminal_population_size -eq 9 -and
        [bool]$Value.runtime_integration_conformance.worker_terminal_population_compared_completely -and
        [int]$Value.runtime_integration_conformance.supervisor_terminal_population_size -eq 9 -and
        [bool]$Value.runtime_integration_conformance.supervisor_terminal_population_compared_completely -and
        -not [bool]$Value.runtime_integration_conformance.sampling_claimed -and
        [double]$Value.runtime_integration_conformance.equivalence_margin -eq 0.0 -and
        [double]$Value.runtime_integration_conformance.non_inferiority_margin -eq 0.0 -and
        [int]$Value.runtime_integration_conformance.conforming_cell_count -eq 0 -and
        [int]$Value.runtime_integration_conformance.nonconforming_cell_count -eq 9 -and
        -not [bool]$Value.official_result.scientific_result_exists -and
        -not [bool]$Value.official_result.physical_result_exists -and
        -not [bool]$Value.official_result.finite_three_engine_turning -and
        -not [bool]$Value.official_result.portable_basic_turning -and
        -not [bool]$Value.official_result.q_sdk_r23_satisfied -and
        -not [bool]$Value.official_result.posthoc_trace_evaluation_performed -and
        [string]$Value.official_result.release_score_before -ceq "10/25" -and
        [string]$Value.official_result.release_score_after -ceq "10/25" -and
        -not [bool]$Value.bounded_interpretation.r23d64_turning_positive -and
        -not [bool]$Value.bounded_interpretation.r23d64_turning_negative -and
        -not [bool]$Value.bounded_interpretation.r23d64_is_a_turning_near_miss -and
        [bool]$Value.bounded_interpretation.three_rapier_traces_are_diagnostic_only -and
        [bool]$Value.successor_requirements.distinct_campaign_identity_required -and
        [bool]$Value.successor_requirements.fresh_unused_seed_required -and
        -not [bool]$Value.successor_requirements.physical_successor_authorized_by_this_closure -and
        -not [bool]$Value.claims.finite_three_engine_turning -and
        -not [bool]$Value.claims.q_sdk_r23_satisfied -and
        -not [bool]$Value.claims.prone_to_standing -and
        -not [bool]$Value.claims.release_authorized
    )
}

Assert-R23D64Closure (Test-Path -LiteralPath $closurePath -PathType Leaf) (
    "closure missing"
)
$closure = Get-Content -LiteralPath $closurePath -Raw |
    ConvertFrom-Json -Depth 100
Assert-R23D64Closure (Test-R23D64ClosureVector $closure) "closure vector changed"

# The retained population is closed exactly. This audit hashes and counts the
# diagnostic traces but deliberately does not pass them back through a turning
# evaluator after the consumed attempt.
$actualRelative = @(
    Get-ChildItem -LiteralPath $attemptRoot -Recurse -File |
        ForEach-Object {
            $_.FullName.Substring($attemptRoot.Length + 1).Replace('\', '/')
        } | Sort-Object
)
$declaredRelative = @(
    $closure.physical_evidence.files |
        ForEach-Object { [string]$_.relative_path } | Sort-Object
)
Assert-R23D64Closure (
    $actualRelative.Count -eq 60 -and
    ($actualRelative -join "`n") -ceq ($declaredRelative -join "`n")
) "retained file population changed"
$declaredByteCount = [long](
    ($closure.physical_evidence.files |
        Measure-Object -Property byte_length -Sum).Sum
)
Assert-R23D64Closure ($declaredByteCount -eq 265254983) (
    "retained byte population changed"
)
foreach ($file in @($closure.physical_evidence.files)) {
    Assert-R23D64RetainedFile $file
}
$uniqueDigests = @(
    $closure.physical_evidence.files.raw_sha256 | Sort-Object -Unique
)
Assert-R23D64Closure ($uniqueDigests.Count -eq 44) "unique digest count changed"
Assert-R23D64Closure ($casVerified.Count -eq 44) "CAS digest population changed"

foreach ($qualificationArtifact in @(
    $closure.qualification.attestation,
    $closure.qualification.adoption
)) {
    Assert-R23D64Closure (
        (Test-Path -LiteralPath $qualificationArtifact.path -PathType Leaf) -and
        (Get-Item -LiteralPath $qualificationArtifact.path).Length -eq
            [long]$qualificationArtifact.byte_length -and
        (Get-R23D64Sha256 $qualificationArtifact.path) -ceq
            [string]$qualificationArtifact.raw_sha256
    ) "qualification artifact changed: $($qualificationArtifact.path)"
    Assert-R23D64Cas (
        [string]$qualificationArtifact.raw_sha256
    ) ([long]$qualificationArtifact.byte_length)
}
$attestation = Get-Content -LiteralPath (
    Join-Path $qualificationRoot "attestation.json"
) -Raw | ConvertFrom-Json -Depth 100
$adoption = Get-Content -LiteralPath (
    Join-Path $qualificationRoot "adoption.json"
) -Raw | ConvertFrom-Json -Depth 100
Assert-R23D64Closure (
    [string]$attestation.schema_version -ceq
        "sporespore_locomotion_campaign_attestation_v1" -and
    [string]$attestation.status -ceq
        "campaign_local_godot_including_qualification_passed" -and
    [string]$attestation.source.commit -ceq $sourceCommit -and
    [string]$attestation.source.tree_git_oid -ceq $sourceTree -and
    [bool]$attestation.source.clean_pushed_live -and
    [int]$attestation.global_gate_count -eq 12 -and
    [int]$attestation.lineage_gate_count -eq 9 -and
    [int]$attestation.campaign_gate_count -eq 3 -and
    [int]$attestation.executed_gate_count -eq 24 -and
    @($attestation.gate_receipts).Count -eq 24 -and
    [bool]$attestation.all_gates_executed -and
    [bool]$attestation.all_gate_streams_content_addressed -and
    -not [bool]$attestation.commissioned
) "qualification attestation changed"
Assert-R23D64Closure (
    [string]$adoption.schema_version -ceq
        "sporespore_locomotion_campaign_attestation_adoption_v1" -and
    [string]$adoption.status -ceq
        "commissioned_campaign_local_qualification_adopted_for_physical_launch" -and
    [string]$adoption.source_commit -ceq $sourceCommit -and
    [string]$adoption.source_tree_git_oid -ceq $sourceTree -and
    [int]$adoption.global_gate_count -eq 12 -and
    [int]$adoption.lineage_gate_count -eq 9 -and
    [int]$adoption.campaign_gate_count -eq 3 -and
    [int]$adoption.executed_gate_count -eq 24 -and
    [int]$adoption.gate_cas_object_count -eq 72 -and
    @($adoption.role_bindings).Count -eq 3 -and
    [bool]$adoption.all_gate_cas_objects_verified -and
    [bool]$adoption.clean_pushed_live_source_verified -and
    [bool]$adoption.physical_launch_prerequisite_satisfied -and
    -not [bool]$adoption.physical_acceptance_authority
) "qualification adoption changed"

$freeze = Get-Content -LiteralPath (Join-Path $attemptRoot "physical-freeze.json") -Raw |
    ConvertFrom-Json -Depth 100
$attempt = Get-Content -LiteralPath (Join-Path $attemptRoot "attempt-authorization.json") -Raw |
    ConvertFrom-Json -Depth 100
$authorization = Get-Content -LiteralPath (
    Join-Path $attemptRoot "authorization-preflight.json"
) -Raw | ConvertFrom-Json -Depth 100
$completion = Get-Content -LiteralPath (Join-Path $attemptRoot "completion.json") -Raw |
    ConvertFrom-Json -Depth 20
$diagnosis = Get-Content -LiteralPath (
    Join-Path $attemptRoot "postphysical-diagnosis.json"
) -Raw | ConvertFrom-Json -Depth 100
Assert-R23D64Closure (
    [string]$freeze.schema_version -ceq "sporespore_qsdk_r23d64_physical_freeze_v1" -and
    [string]$freeze.source_commit -ceq $sourceCommit -and
    [string]$freeze.source_tree_git_oid -ceq $sourceTree -and
    [bool]$freeze.complete_zero_world_gate_passed -and
    [int]$freeze.zero_world_receipt.campaign_gate_count -eq 14 -and
    [int]$freeze.zero_world_receipt.worker_preflight_count -eq 9 -and
    [int]$freeze.zero_world_receipt.model_construction_count -eq 0 -and
    [int]$freeze.zero_world_receipt.world_attempt_count -eq 0 -and
    [int]$freeze.zero_world_receipt.world_build_count -eq 0 -and
    [int]$freeze.authorization_receipt_schema_conformance.conforming_producer_count -eq 3 -and
    [int]$freeze.authorization_receipt_schema_conformance.negative_controls_passed -eq 12 -and
    [double]$freeze.authorization_receipt_schema_conformance.equivalence_margin -eq 0.0 -and
    [double]$freeze.authorization_receipt_schema_conformance.non_inferiority_margin -eq 0.0 -and
    [bool]$freeze.authorization_receipt_schema_conformance.runtime_dependency_path_self_bound -and
    [int]$freeze.authorization_receipt_schema_conformance.runtime_dependency_distribution_count -eq 9 -and
    [int]$freeze.authorization_receipt_schema_conformance.runtime_dependency_distribution_file_count -eq 8094 -and
    [bool]$freeze.physical_execution_authorized
) "physical freeze changed"
Assert-R23D64Closure (
    [string]$attempt.schema_version -ceq "sporespore_qsdk_r23d64_attempt_v1" -and
    [string]$attempt.attempt_id -ceq $attemptId -and
    [string]$attempt.source_commit -ceq $sourceCommit -and
    [string]$attempt.freeze_raw_sha256 -ceq
        "sha256:7e5614f30aafb9c9fea2fa1360ea5bfdedcd5e59b6a83be42f7bdaa2685f62c2" -and
    ($attempt.ordered_matrix_cell_ids -join "`n") -ceq
        ($expectedCellIds -join "`n") -and
    [bool]$attempt.physical_execution_authorized -and
    [bool]$attempt.single_use_supervisor_authorization -and
    [bool]$attempt.matrix_authorization_immutable_before_first_world -and
    [bool]$attempt.source_worktree_clean -and
    [bool]$attempt.source_matches_live_github_main -and
    [bool]$attempt.campaign_attestation_adoption_valid -and
    [bool]$attempt.all_cells_run_regardless_of_intermediate_outcome
) "attempt authorization changed"

Assert-R23D64Closure (
    [string]$authorization.schema_version -ceq
        "sporespore_qsdk_r23d64_authorization_preflight_matrix_v1" -and
    [string]$authorization.source_commit -ceq $sourceCommit -and
    [int]$authorization.receipt_count -eq 9 -and
    @($authorization.ordered_receipts).Count -eq 9 -and
    [int]$authorization.model_construction_count -eq 0 -and
    [int]$authorization.world_attempt_count -eq 0 -and
    [int]$authorization.world_build_count -eq 0 -and
    -not [bool]$authorization.physical_acceptance_authority
) "authorization preflight matrix changed"
for ($index = 0; $index -lt $expectedCells.Count; $index++) {
    $expected = $expectedCells[$index]
    $cellId = $expectedCellIds[$index]
    $wrapper = $authorization.ordered_receipts[$index]
    $receipt = $wrapper.worker_receipt
    Assert-R23D64Closure (
        [string]$wrapper.cell_id -ceq $cellId -and
        [string]$wrapper.engine_id -ceq [string]$expected.engine -and
        [string]$receipt.cell_id -ceq $cellId -and
        [string]$receipt.engine_id -ceq [string]$expected.engine -and
        [string]$receipt.campaign_id -ceq $campaignId -and
        [bool]$receipt.authorization_passed -and
        [bool]$receipt.complete_ordered_nine_cell_matrix_validated -and
        [bool]$receipt.returned_before_model -and
        [int]$receipt.model_construction_count -eq 0 -and
        [int]$receipt.world_attempt_count -eq 0 -and
        [int]$receipt.world_build_count -eq 0 -and
        [int]$wrapper.process.exit_code -eq 0 -and
        -not [bool]$wrapper.process.timed_out -and
        -not [bool]$wrapper.physical_acceptance_authority
    ) "authorization receipt changed: $cellId"
    if ([string]$expected.engine -ceq "godot_jolt") {
        Assert-R23D64Closure (
            [int]$receipt.campaign_seed -eq 23171 -and
            [string]$receipt.profile_id -ceq $profileId -and
            [string]$receipt.arm_id -ceq [string]$expected.arm -and
            [double]$receipt.turn_heading_offset_rad -eq [double]$expected.offset
        ) "Godot authorization receipt identity changed: $cellId"
    } elseif ([string]$expected.engine -ceq "rapier_parry") {
        Assert-R23D64Closure (
            [string]$receipt.candidate_id -ceq "selected_profile" -and
            [int]$receipt.physical_process_launch_count -eq 0
        ) "Rapier authorization receipt identity changed: $cellId"
    }
}

$actualWorkerWorldAttempts = 0
$actualWorkerWorldBuilds = 0
$workerMarkers = @{}
for ($index = 0; $index -lt $expectedCells.Count; $index++) {
    $expected = $expectedCells[$index]
    $cellId = $expectedCellIds[$index]
    $worker = Get-R23D64WorkerMarker $cellId ([string]$expected.engine)
    $workerMarkers[$cellId] = $worker
    $actualWorkerWorldAttempts += [int]$worker.world_attempt_count
    $actualWorkerWorldBuilds += [int]$worker.world_build_count
    Assert-R23D64Closure (
        [string]$worker.schema_version -ceq
            "sporespore_qsdk_r23d64_worker_failure_v1" -and
        [string]$worker.campaign_id -ceq $campaignId -and
        [string]$worker.cell_id -ceq $cellId -and
        [string]$worker.engine_id -ceq [string]$expected.engine -and
        [string]$worker.arm_id -ceq [string]$expected.arm -and
        [double]$worker.turn_heading_offset_rad -eq [double]$expected.offset -and
        [string]$worker.source_commit -ceq $sourceCommit -and
        @($worker.claims.PSObject.Properties.Value |
            Where-Object { [bool]$_ }).Count -eq 0
    ) "worker failure terminal changed: $cellId"

    $terminal = Get-Content -LiteralPath (
        Join-Path $attemptRoot "cells\$cellId\terminal.json"
    ) -Raw | ConvertFrom-Json -Depth 100
    Assert-R23D64Closure (
        [string]$terminal.cell_id -ceq $cellId -and
        [string]$terminal.engine_id -ceq [string]$expected.engine -and
        [string]$terminal.campaign_id -ceq $campaignId -and
        [string]$terminal.source_commit -ceq $sourceCommit -and
        @($terminal.claims.PSObject.Properties.Value |
            Where-Object { [bool]$_ }).Count -eq 0
    ) "retained terminal identity changed: $cellId"

    if ([string]$expected.engine -ceq "godot_jolt") {
        Assert-R23D64Closure (
            [int]$worker.campaign_seed -eq 23171 -and
            [string]$worker.profile_id -ceq $profileId -and
            [string]$worker.host_mapping_id -ceq
                "sporespore_godot_hinge_maximum_impulse_cap_mapping_v1" -and
            [string]$worker.failure_stage -ceq "controller_horizon_complete" -and
            [string]$worker.failure_code -ceq "QSDK_R23D64_GJT_TRACE_INCOMPLETE" -and
            [int]$worker.world_attempt_count -eq 1 -and
            [int]$worker.world_build_count -eq 1 -and
            [string]$worker.raw_sdk_authority_summary.failure_code -ceq
                "QSDK_R23D64_GJT_PUBLIC_PROFILE_BINDING_INVALID" -and
            [int]$worker.raw_sdk_authority_summary.step_count -eq 0 -and
            [int]$worker.raw_sdk_authority_summary.validated_balanced_wave_command_count -eq 0 -and
            [int]$worker.raw_sdk_authority_summary.native_actuation_application_count -eq 0 -and
            @($worker.actuator_cap_profile_resolution_receipt.PSObject.Properties).Count -eq 0 -and
            @($worker.actuator_cap_profile_host_mapping_receipt.PSObject.Properties).Count -eq 0 -and
            @($worker.actuator_cap_profile_physical_binding_receipt.PSObject.Properties).Count -eq 0 -and
            [int]$worker.trace_diagnostic.actual_row_count -eq 0 -and
            [string]$terminal.schema_version -ceq
                "sporespore_qsdk_r23d64_worker_failure_v1" -and
            [string]$terminal.failure_code -ceq "QSDK_R23D64_GJT_TRACE_INCOMPLETE" -and
            [int]$terminal.world_attempt_count -eq 1 -and
            [int]$terminal.world_build_count -eq 1
        ) "Godot/Jolt failure finding changed: $cellId"
    } elseif ([string]$expected.engine -ceq "rapier_parry") {
        Assert-R23D64Closure (
            [int]$worker.campaign_seed -eq 23171 -and
            [string]$worker.candidate_id -ceq "selected_profile" -and
            -not ($worker.PSObject.Properties.Name -ccontains "profile_id") -and
            -not ($worker.PSObject.Properties.Name -ccontains "host_mapping_id") -and
            [string]$worker.failure_stage -ceq "settlement_complete" -and
            [string]$worker.failure_code -clike
                "QSDK_R23D27_RAP_TRACE_RETENTION_FAILED:*R23D34_TRACE_CAS_FAILED:1:SecurityError: AuthorizationManager check failed.*" -and
            [int]$worker.world_attempt_count -eq 1 -and
            [int]$worker.world_build_count -eq 1 -and
            [string]$terminal.schema_version -ceq
                "sporespore_qsdk_r23d64_supervisor_failure_v1" -and
            [string]$terminal.failure_code -ceq
                "R23D64_SUPERVISOR_TERMINAL_CAPTURE:The property 'profile_id' cannot be found on this object. Verify that the property exists." -and
            [int]$terminal.world_attempt_count -eq 1 -and
            [int]$terminal.world_build_count -eq 0 -and
            -not [bool]$terminal.world_build_count_exact -and
            [int]$terminal.world_build_count_upper_bound -eq 1
        ) "Rapier/Parry failure finding changed: $cellId"
        $tracePath = Join-Path $attemptRoot "traces\$cellId.ndjson"
        $traceRowCount = ([IO.File]::ReadLines($tracePath) | Measure-Object).Count
        Assert-R23D64Closure ($traceRowCount -eq 2992) (
            "diagnostic Rapier trace row count changed: $cellId"
        )
    } else {
        Assert-R23D64Closure (
            -not ($worker.PSObject.Properties.Name -ccontains "campaign_seed") -and
            -not ($worker.PSObject.Properties.Name -ccontains "profile_id") -and
            -not ($worker.PSObject.Properties.Name -ccontains "host_mapping_id") -and
            [string]$worker.failure_stage -ceq "before_world" -and
            [string]$worker.failure_code -ceq
                "QSDK_R23D3_MJC_PREFLIGHT_ERROR:KeyError:'command_schedule'" -and
            [int]$worker.world_attempt_count -eq 0 -and
            [int]$worker.world_build_count -eq 0 -and
            [string]$terminal.schema_version -ceq
                "sporespore_qsdk_r23d64_supervisor_failure_v1" -and
            [string]$terminal.failure_code -ceq
                "R23D64_SUPERVISOR_TERMINAL_CAPTURE:The property 'campaign_seed' cannot be found on this object. Verify that the property exists." -and
            [int]$terminal.world_attempt_count -eq 1 -and
            [int]$terminal.world_build_count -eq 0 -and
            -not [bool]$terminal.world_build_count_exact -and
            [int]$terminal.world_build_count_upper_bound -eq 1
        ) "MuJoCo failure finding changed: $cellId"
    }
}
Assert-R23D64Closure (
    $actualWorkerWorldAttempts -eq 6 -and $actualWorkerWorldBuilds -eq 6
) "actual worker world population changed"

$terminalPaths = Get-Content -LiteralPath (
    Join-Path $attemptRoot "terminal-paths.json"
) -Raw | ConvertFrom-Json -Depth 10
$expectedTerminalPaths = @(
    foreach ($cellId in $expectedCellIds) {
        $relative = "cells/$cellId/terminal.json"
        $entry = @(
            $closure.physical_evidence.files |
                Where-Object { [string]$_.relative_path -ceq $relative }
        )
        Assert-R23D64Closure ($entry.Count -eq 1) (
            "terminal inventory entry changed: $cellId"
        )
        Join-Path (
            Join-Path $artifactRoot ([string]$entry[0].raw_sha256).Substring(7)
        ) "payload.bin"
    }
)
Assert-R23D64Closure (
    @($terminalPaths).Count -eq 9 -and
    ($terminalPaths -join "`n") -ceq ($expectedTerminalPaths -join "`n")
) "terminal path order or CAS binding changed"
Assert-R23D64Closure (
    -not (Test-Path -LiteralPath (Join-Path $attemptRoot "complete-evaluation.json")) -and
    -not (Test-Path -LiteralPath (Join-Path $attemptRoot "campaign-report.json")) -and
    -not (Test-Path -LiteralPath (Join-Path $attemptRoot "report.json"))
) "an official evaluation or report unexpectedly exists"
Assert-R23D64Closure (
    [string]$completion.schema_version -ceq "sporespore_qsdk_r23d64_completion_v1" -and
    [string]$completion.status -ceq "invalid_or_incomplete_first_attempt" -and
    [string]$completion.source_commit -ceq $sourceCommit -and
    [bool]$completion.one_shot_attempt_consumed -and
    -not [bool]$completion.replacement_or_selective_rerun_permitted -and
    [string]$completion.failure_message -ceq
        "QSDK-R23D64: complete evaluator failed: QSDK_R23D64_EVALUATOR_V2_FAILURE R23D64EvaluationError:R23D64_COMPLETE_ENTRY_ORDER_INVALID`r`n " -and
    -not [bool]$completion.physical_acceptance_authority
) "completion changed"
Assert-R23D64Closure (
    [string]$diagnosis.schema_version -ceq
        "sporespore_qsdk_r23d64_postphysical_diagnosis_v1" -and
    [string]$diagnosis.status -ceq
        "immutable_consumed_invalid_incomplete_first_attempt_diagnosed" -and
    [string]$diagnosis.source_commit -ceq $sourceCommit -and
    [string]$diagnosis.source_tree_git_oid -ceq $sourceTree -and
    [string]$diagnosis.attempt_id -ceq $attemptId -and
    [bool]$diagnosis.campaign_identity_consumed -and
    -not [bool]$diagnosis.same_identity_rerun_allowed -and
    [int]$diagnosis.authorization_and_execution_population.actual_worker_reported_world_build_count -eq 6 -and
    [int]$diagnosis.authorization_and_execution_population.execution_valid_cell_count -eq 0 -and
    [int]$diagnosis.rapier_parry_failure.canonical_trace_row_count_each -eq 2992 -and
    -not [bool]$diagnosis.official_result.scientific_result_exists -and
    -not [bool]$diagnosis.official_result.turning_positive -and
    -not [bool]$diagnosis.official_result.turning_negative -and
    -not [bool]$diagnosis.official_result.turning_near_miss -and
    [string]$diagnosis.official_result.release_score_after -ceq "10/25" -and
    -not [bool]$diagnosis.successor_boundary.physical_successor_authorized_by_this_diagnosis
) "postphysical diagnosis changed"

foreach ($binding in @($closure.source_bindings)) {
    $bytes = Get-R23D64GitBlobBytes $sourceCommit ([string]$binding.path)
    Assert-R23D64Closure (
        $bytes.Length -eq [long]$binding.byte_length -and
        (Get-R23D64BytesSha256 $bytes) -ceq [string]$binding.raw_sha256
    ) "source binding changed: $($binding.path)"
}
$supervisorText = [Text.Encoding]::UTF8.GetString((
    Get-R23D64GitBlobBytes $sourceCommit "sdk/run_qsdk_r23d64_supervisor.ps1"
))
$evaluatorText = [Text.Encoding]::UTF8.GetString((
    Get-R23D64GitBlobBytes $sourceCommit (
        "sdk/turning/r23d64_selected_profile_three_engine_turning_validation_evaluator.py"
    )
))
$mujocoWorkerText = [Text.Encoding]::UTF8.GetString((
    Get-R23D64GitBlobBytes $sourceCommit (
        "sdk/adapters/mujoco/sporespore_mujoco_adapter/" +
        "qsdk_r23d64_selected_profile_turning.py"
    )
))
$mujocoCoreText = [Text.Encoding]::UTF8.GetString((
    Get-R23D64GitBlobBytes $sourceCommit (
        "sdk/adapters/mujoco/sporespore_mujoco_adapter/qsdk_r23d3_phase_balanced.py"
    )
))
$rapierEvaluatorText = [Text.Encoding]::UTF8.GetString((
    Get-R23D64GitBlobBytes $sourceCommit (
        "sdk/turning/r23d34_native_r23d29_transfer_evaluator.py"
    )
))
$godotWorkerText = [Text.Encoding]::UTF8.GetString((
    Get-R23D64GitBlobBytes $sourceCommit (
        "tests/test_sdk_qsdk_r23d64_godot_jolt_physical_worker.gd"
    )
))
Assert-R23D64Closure (
    $supervisorText.Contains('[int]$terminal.campaign_seed -ne $campaignSeed') -and
    $supervisorText.Contains('[string]$terminal.profile_id -cne $profileId') -and
    $supervisorText.Contains('R23D64_SUPERVISOR_TERMINAL_CAPTURE:') -and
    $supervisorText.Contains('complete evaluator failed') -and
    $evaluatorText.Contains('def _validate_complete_order(') -and
    $evaluatorText.Contains('entry.get("campaign_seed")') -and
    $evaluatorText.Contains('entry.get("profile_id")') -and
    $evaluatorText.Contains('entry.get("host_mapping_id")') -and
    $evaluatorText.Contains('R23D64_COMPLETE_ENTRY_ORDER_INVALID')
) "aggregate identity-gate source mechanism changed"
$bindingBlock = [regex]::Match(
    $mujocoWorkerText,
    '(?s)for name, value in \{(?<body>.*?)\}\.items\(\):\s+setattr\(_core, name, value\)'
)
Assert-R23D64Closure (
    $bindingBlock.Success -and
    -not $bindingBlock.Groups['body'].Value.Contains('"run_preflight"') -and
    $mujocoWorkerText.Contains('report = _core.run_physical(') -and
    $mujocoCoreText.Contains('contract["command_schedule"][') -and
    $mujocoCoreText.Contains('run_preflight(stage_id, onset_id, arm_id)')
) "MuJoCo inherited preflight-binding mechanism changed"
Assert-R23D64Closure (
    $rapierEvaluatorText.Contains('str(PUBLISHER_PATH)') -and
    $rapierEvaluatorText.Contains('subprocess.run(') -and
    $rapierEvaluatorText.Contains('R23D34_TRACE_CAS_FAILED:') -and
    $godotWorkerText.Contains('QSDK_R23D64_GJT_PUBLIC_PROFILE_BINDING_INVALID') -and
    $godotWorkerText.Contains('actuator_cap_profile_resolution_receipt') -and
    $godotWorkerText.Contains('actuator_cap_profile_host_mapping_receipt') -and
    $godotWorkerText.Contains('actuator_cap_profile_physical_binding_receipt')
) "engine runtime failure source mechanism changed"

$mutations = @(
    @{ path = "status"; value = "passing" },
    @{ path = "source_commit"; value = ("0" * 40) },
    @{ path = "source_tree_git_oid"; value = ("0" * 40) },
    @{ path = "attempt_id"; value = "replacement" },
    @{ path = "campaign_seed"; value = 23173 },
    @{ path = "same_identity_rerun_allowed"; value = $true },
    @{ path = "replacement_or_selective_rerun_allowed"; value = $true },
    @{ path = "physical_outcome_exposed"; value = $false },
    @{ path = "physical_evidence.complete_retained_file_population_count"; value = 59 },
    @{ path = "physical_evidence.complete_retained_file_population_byte_count"; value = 1 },
    @{ path = "physical_evidence.actual_worker_reported_world_build_count"; value = 9 },
    @{ path = "physical_evidence.execution_valid_cell_count"; value = 1 },
    @{ path = "failure_mechanisms.godot_jolt.world_build_count"; value = 0 },
    @{ path = "failure_mechanisms.rapier_parry.post_attempt_trace_evaluation_performed"; value = $true },
    @{ path = "failure_mechanisms.mujoco.world_build_count"; value = 1 },
    @{ path = "runtime_integration_conformance.equivalence_margin"; value = 0.1 },
    @{ path = "runtime_integration_conformance.conforming_cell_count"; value = 9 },
    @{ path = "official_result.scientific_result_exists"; value = $true },
    @{ path = "official_result.physical_result_exists"; value = $true },
    @{ path = "official_result.finite_three_engine_turning"; value = $true },
    @{ path = "official_result.q_sdk_r23_satisfied"; value = $true },
    @{ path = "official_result.release_score_after"; value = "11/25" },
    @{ path = "bounded_interpretation.r23d64_turning_positive"; value = $true },
    @{ path = "bounded_interpretation.r23d64_turning_negative"; value = $true },
    @{ path = "successor_requirements.physical_successor_authorized_by_this_closure"; value = $true },
    @{ path = "claims.finite_three_engine_turning"; value = $true },
    @{ path = "claims.q_sdk_r23_satisfied"; value = $true },
    @{ path = "claims.prone_to_standing"; value = $true },
    @{ path = "claims.release_authorized"; value = $true }
)
foreach ($mutation in $mutations) {
    $candidate = $closure | ConvertTo-Json -Depth 100 -Compress |
        ConvertFrom-Json -Depth 100
    $parts = ([string]$mutation.path).Split('.')
    $parent = $candidate
    for ($index = 0; $index -lt $parts.Count - 1; $index++) {
        $parent = $parent.($parts[$index])
    }
    $parent.($parts[-1]) = $mutation.value
    Assert-R23D64Closure (-not (Test-R23D64ClosureVector $candidate)) (
        "closure mutation accepted: $($mutation.path)"
    )
}

Write-Output (
    "QSDK_R23D64_PHYSICAL_CLOSURE_PASS files=60 bytes=265254983 " +
    "unique_digests=44 cas=60 authorization_receipts=9 cells=9 " +
    "worker_markers=9 models=0 worlds=6 valid_cells=0 " +
    "rapier_diagnostic_traces=3 rows_each=2992 mutations=$($mutations.Count) " +
    "q_sdk_r23=False release_score=10/25 release_authority=False"
)
