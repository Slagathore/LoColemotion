#requires -Version 7.0

[CmdletBinding()]
param([string]$Python = "C:\Program Files\Python311\python.exe")

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$evidenceRoot = "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence"
$artifactRoot = Join-Path $evidenceRoot "artifacts\sha256"
$attemptRoot = Join-Path $evidenceRoot "qsdk-r23d52-20260814T074722Z"
$closurePath = Join-Path $repoRoot (
    "sdk\turning\r23d52_godot_segment_origin_reanchor_closure_v1.json"
)
$r51ClosurePath = Join-Path $repoRoot (
    "sdk\turning\r23d51_godot_segment_origin_reanchor_closure_v1.json"
)
$sourceCommit = "0f27c1d68d782aaf2e2e0188b56e4971e80719df"
$classification = (
    "valid_complete_negative_outcome_exposed_godot_segment_origin_" +
    "implementation_replay"
)
$candidateId = "r23d29_heading_segment_origin_reanchor_implementation_replay"
$cellIds = @(
    "godot_jolt__${candidateId}__reference_zero",
    "godot_jolt__${candidateId}__positive_heading",
    "godot_jolt__${candidateId}__negative_heading"
)
$tolerance = 1.0e-12

function Assert-R23D52Closure([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "QSDK-R23D52 CLOSURE: $Message" }
}

function Assert-R23D52Near([double]$Actual, [double]$Expected, [string]$Message) {
    Assert-R23D52Closure (
        [double]::IsFinite($Actual) -and
        [Math]::Abs($Actual - $Expected) -le $tolerance
    ) $Message
}

function Get-R23D52Sha256([string]$Path) {
    return "sha256:" + (
        Get-FileHash -LiteralPath $Path -Algorithm SHA256
    ).Hash.ToLowerInvariant()
}

function Get-R23D52BytesSha256([byte[]]$Bytes) {
    return "sha256:" + [Convert]::ToHexString(
        [Security.Cryptography.SHA256]::HashData($Bytes)
    ).ToLowerInvariant()
}

function Get-R23D52GitBlobBytes([string]$Commit, [string]$RelativePath) {
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
    Assert-R23D52Closure ($process.Start()) "could not start git cat-file"
    $memory = [IO.MemoryStream]::new()
    try {
        $process.StandardOutput.BaseStream.CopyTo($memory)
        $stderr = $process.StandardError.ReadToEnd()
        $process.WaitForExit()
        Assert-R23D52Closure ($process.ExitCode -eq 0) (
            "historical blob unavailable: $RelativePath; $stderr"
        )
        return ,([byte[]]$memory.ToArray())
    } finally {
        $memory.Dispose()
        $process.Dispose()
    }
}

function Assert-R23D52Cas([string]$Sha256, [long]$ByteLength) {
    Assert-R23D52Closure ($Sha256 -cmatch '^sha256:[0-9a-f]{64}$') (
        "invalid CAS digest: $Sha256"
    )
    $directory = Join-Path $artifactRoot $Sha256.Substring(7)
    $payload = Join-Path $directory "payload.bin"
    $manifestPath = Join-Path $directory "manifest.json"
    Assert-R23D52Closure (
        (Test-Path -LiteralPath $payload -PathType Leaf) -and
        (Test-Path -LiteralPath $manifestPath -PathType Leaf) -and
        (Get-Item -LiteralPath $payload).Length -eq $ByteLength -and
        (Get-R23D52Sha256 $payload) -ceq $Sha256
    ) "CAS payload changed: $Sha256"
    $manifest = Get-Content -Raw -LiteralPath $manifestPath |
        ConvertFrom-Json -Depth 20
    Assert-R23D52Closure (
        [string]$manifest.schema_version -ceq
            "sporespore_content_addressed_artifact_manifest_v1" -and
        [string]$manifest.algorithm -ceq "sha256" -and
        [string]$manifest.sha256 -ceq $Sha256 -and
        [long]$manifest.byte_length -eq $ByteLength -and
        [string]$manifest.payload_name -ceq "payload.bin"
    ) "CAS manifest changed: $Sha256"
    return $payload
}

function Assert-R23D52PathAndCas(
    [string]$Path,
    [string]$Sha256,
    [long]$ByteLength
) {
    Assert-R23D52Closure (
        (Test-Path -LiteralPath $Path -PathType Leaf) -and
        (Get-Item -LiteralPath $Path).Length -eq $ByteLength -and
        (Get-R23D52Sha256 $Path) -ceq $Sha256
    ) "retained artifact changed: $Path"
    $payload = Assert-R23D52Cas $Sha256 $ByteLength
    Assert-R23D52Closure (
        (Get-R23D52Sha256 $payload) -ceq (Get-R23D52Sha256 $Path)
    ) "retained artifact and CAS differ: $Path"
    return $payload
}

Assert-R23D52Closure (
    (git -C $repoRoot rev-parse --show-toplevel).Trim().Replace('/', '\') -ceq
        $repoRoot -and
    (git -C $repoRoot remote get-url origin).Trim() -ceq
        "https://github.com/Slagathore/sporespore.git"
) "repository identity changed"

$closure = Get-Content -Raw -LiteralPath $closurePath |
    ConvertFrom-Json -Depth 100
Assert-R23D52Closure (
    [string]$closure.schema_version -ceq
        "sporespore_qsdk_r23d52_godot_segment_origin_reanchor_closure_v1" -and
    [string]$closure.status -ceq
        "closed_consumed_valid_complete_negative_outcome_exposed_godot_segment_origin_implementation_replay" -and
    [string]$closure.source_commit -ceq $sourceCommit -and
    (git -C $repoRoot rev-parse "$sourceCommit`^{tree}").Trim() -ceq
        [string]$closure.source_tree_git_oid -and
    [string]$closure.attempt_id -ceq "3541ae4893bd4ba68568b34a3340e341" -and
    [int]$closure.campaign_seed -eq 21512 -and
    [bool]$closure.identity_consumed -and
    -not [bool]$closure.same_identity_rerun_allowed -and
    -not [bool]$closure.selective_rerun_allowed -and
    -not [bool]$closure.fresh_held_out_condition_consumed -and
    -not [bool]$closure.successor_campaign_opened -and
    [bool]$closure.physical_series_paused_before_successor
) "immutable disposition changed"

Assert-R23D52Closure (@($closure.prospective_inputs).Count -eq 11) (
    "prospective input count changed"
)
foreach ($input in @($closure.prospective_inputs)) {
    $relative = [string]$input.path
    $bytes = Get-R23D52GitBlobBytes $sourceCommit $relative
    Assert-R23D52Closure (
        $bytes.Length -eq [long]$input.byte_length -and
        (Get-R23D52BytesSha256 $bytes) -ceq [string]$input.raw_sha256 -and
        (git -C $repoRoot rev-parse "$sourceCommit`:$relative").Trim() -ceq
            [string]$input.git_blob_oid
    ) "prospective source identity changed: $relative"
}

$attestationPayload = Assert-R23D52PathAndCas (
    [string]$closure.qualification.attestation_path
) ([string]$closure.qualification.attestation_sha256) (
    [long]$closure.qualification.attestation_byte_length
)
$adoptionPayload = Assert-R23D52PathAndCas (
    [string]$closure.qualification.adoption_path
) ([string]$closure.qualification.adoption_sha256) (
    [long]$closure.qualification.adoption_byte_length
)
$attestation = Get-Content -Raw -LiteralPath $attestationPayload |
    ConvertFrom-Json -Depth 100
$adoption = Get-Content -Raw -LiteralPath $adoptionPayload |
    ConvertFrom-Json -Depth 100
Assert-R23D52Closure (
    [string]$attestation.status -ceq
        "campaign_local_godot_including_qualification_passed" -and
    [string]$attestation.source.commit -ceq $sourceCommit -and
    [int]$attestation.global_gate_count -eq 12 -and
    [int]$attestation.lineage_gate_count -eq 3 -and
    [int]$attestation.campaign_gate_count -eq 3 -and
    [int]$attestation.executed_gate_count -eq 18 -and
    @($attestation.gate_receipts).Count -eq 18 -and
    @($attestation.gate_receipts | Where-Object {
        -not [bool]$_.passed -or [int]$_.physical_world_count -ne 0 -or
        [int]$_.physical_process_launch_count -ne 0
    }).Count -eq 0 -and
    [string]$attestation.runtime.powershell.executable_sha256 -ceq
        [string]$closure.qualification.powershell_executable_sha256 -and
    [string]$attestation.runtime.powershell.version -ceq "7.6.0-preview.6" -and
    [string]$attestation.runtime.host.framework_description -ceq ".NET 10.0.0" -and
    [string]$adoption.source_commit -ceq $sourceCommit -and
    [bool]$adoption.physical_launch_prerequisite_satisfied -and
    -not [bool]$adoption.physical_acceptance_authority
) "qualification or adoption identity changed"

$rootArtifacts = [ordered]@{
    "physical-freeze.json" = $closure.physical_evidence.physical_freeze
    "attempt-authorization.json" = $closure.physical_evidence.attempt_authorization
    "terminal-paths.json" = $closure.physical_evidence.terminal_manifest
    "complete-evaluation.json" = $closure.physical_evidence.complete_evaluation
    "report.json" = $closure.physical_evidence.report
    "completion.json" = $closure.physical_evidence.completion
}
$rootPayloads = @{}
foreach ($entry in $rootArtifacts.GetEnumerator()) {
    $rootPayloads[$entry.Key] = Assert-R23D52PathAndCas (
        (Join-Path $attemptRoot $entry.Key)
    ) ([string]$entry.Value.sha256) ([long]$entry.Value.byte_length)
}
$freeze = Get-Content -Raw -LiteralPath $rootPayloads["physical-freeze.json"] |
    ConvertFrom-Json -Depth 100
$attempt = Get-Content -Raw -LiteralPath (
    $rootPayloads["attempt-authorization.json"]
) | ConvertFrom-Json -Depth 100
$terminalPaths = @(Get-Content -Raw -LiteralPath (
    $rootPayloads["terminal-paths.json"]
) | ConvertFrom-Json)
$evaluationFile = Get-Content -Raw -LiteralPath (
    $rootPayloads["complete-evaluation.json"]
) | ConvertFrom-Json -Depth 100
$report = Get-Content -Raw -LiteralPath $rootPayloads["report.json"] |
    ConvertFrom-Json -Depth 100
$completion = Get-Content -Raw -LiteralPath $rootPayloads["completion.json"] |
    ConvertFrom-Json -Depth 100
$evaluation = $report.complete_evaluation

Assert-R23D52Closure (
    [string]$freeze.source_commit -ceq $sourceCommit -and
    [string]$freeze.source_tree_git_oid -ceq [string]$closure.source_tree_git_oid -and
    @($freeze.source_bindings).Count -eq 69 -and
    @($freeze.content_addressed_inputs.source_bindings).Count -eq 69 -and
    [int]$freeze.declared_world_count -eq 3 -and
    [bool]$freeze.source_checkout_bytes_equal_git_blobs -and
    [bool]$freeze.reproducible_runtime_materialization_passed -and
    [bool]$freeze.complete_zero_world_gate_passed -and
    [bool]$freeze.serial_execution_required -and
    [bool]$freeze.all_cells_run_regardless_of_intermediate_outcome -and
    [bool]$freeze.physical_execution_authorized -and
    [string]$freeze.campaign_attestation_adoption_sha256 -ceq
        [string]$closure.qualification.adoption_sha256 -and
    [int]$freeze.zero_world_receipt.terminal_execution_projection.positive_terminal_projection_canary_count -eq 1 -and
    [int]$freeze.zero_world_receipt.terminal_execution_projection.failure_terminal_projection_canary_count -eq 2 -and
    [int]$freeze.zero_world_receipt.terminal_execution_projection.terminal_projection_mutation_rejection_count -eq 10 -and
    [bool]$freeze.zero_world_receipt.terminal_execution_projection.terminal_projection_uses_worker_execution_object
) "physical freeze or terminal-projection preflight changed"

for ($index = 0; $index -lt @($freeze.source_bindings).Count; $index++) {
    $binding = $freeze.source_bindings[$index]
    $cas = $freeze.content_addressed_inputs.source_bindings[$index]
    $relative = [string]$binding.path
    $bytes = Get-R23D52GitBlobBytes $sourceCommit $relative
    Assert-R23D52Closure (
        [bool]$binding.raw_checkout_equals_git_blob -and
        [string]$binding.raw_sha256 -ceq [string]$cas.sha256 -and
        (Get-R23D52BytesSha256 $bytes) -ceq [string]$binding.raw_sha256 -and
        (git -C $repoRoot rev-parse "$sourceCommit`:$relative").Trim() -ceq
            [string]$binding.git_blob_oid
    ) "frozen source binding changed: $relative"
    [void](Assert-R23D52Cas ([string]$cas.sha256) ([long]$cas.byte_length))
}
[void](Assert-R23D52Cas (
    [string]$closure.runtime_materialization.godot_adapter_debug_sha256
) ([long]$closure.runtime_materialization.godot_adapter_debug_byte_length))
Assert-R23D52Closure (
    [string]$freeze.runtime_artifacts[0].raw_sha256 -ceq
        [string]$closure.runtime_materialization.godot_adapter_debug_sha256 -and
    [int]$freeze.runtime_artifacts[0].build_receipt.source_date_epoch -eq 1786693303 -and
    -not [bool]$freeze.runtime_artifacts[0].build_receipt.cargo_incremental -and
    [int]$freeze.runtime_artifacts[0].build_receipt.remapped_path_count -eq 4 -and
    [bool]$freeze.runtime_artifacts[0].build_receipt.msvc_brepro -and
    [bool]$freeze.runtime_artifacts[0].build_receipt.pdb_alt_path_bare_name -and
    -not [bool]$freeze.runtime_artifacts[0].build_receipt.codegen_units_forced
) "runtime materialization changed"

Assert-R23D52Closure (
    [string]$attempt.attempt_id -ceq [string]$closure.attempt_id -and
    [string]$attempt.source_commit -ceq $sourceCommit -and
    @($attempt.ordered_matrix_cell_ids).Count -eq 3 -and
    (@($attempt.ordered_matrix_cell_ids) -join '|') -ceq ($cellIds -join '|') -and
    [bool]$attempt.physical_execution_authorized -and
    [bool]$attempt.single_use_supervisor_authorization -and
    [bool]$attempt.matrix_authorization_immutable_before_first_world -and
    [bool]$attempt.campaign_attestation_adoption_valid -and
    [bool]$attempt.all_cells_run_regardless_of_intermediate_outcome -and
    [bool]$attempt.one_shot_attempt_unconsumed
) "attempt authorization changed"
Assert-R23D52Closure (
    [string]$report.result_classification -ceq $classification -and
    [string]$evaluation.classification -ceq $classification -and
    ($evaluation | ConvertTo-Json -Depth 100 -Compress) -ceq
        ($evaluationFile | ConvertTo-Json -Depth 100 -Compress) -and
    [bool]$report.all_three_cells_executed_or_retained_as_failures -and
    [bool]$report.world_build_count_exact -and
    [int]$report.world_build_count_lower_bound -eq 3 -and
    [int]$report.world_build_count_upper_bound -eq 3 -and
    [int]$evaluation.cell_count -eq 3 -and
    [bool]$evaluation.all_declared_cells_executed_or_retained_as_failures -and
    [bool]$evaluation.engine_result.all_cells_execution_valid -and
    [bool]$evaluation.engine_result.all_common_physical_gates_passed -and
    -not [bool]$evaluation.engine_result.mechanism_selected -and
    @($evaluation.cell_evaluations | Where-Object {
        [bool]$_.execution_valid -and [bool]$_.common_physical_gate_passed -and
        @($_.failed_gate_ids).Count -eq 0 -and
        [int]$_.world_attempt_count -eq 1 -and [int]$_.world_build_count -eq 1
    }).Count -eq 3 -and
    [string]$completion.status -ceq $classification -and
    [int]$completion.cell_count -eq 3 -and
    [bool]$completion.world_count_exact -and
    [int]$completion.world_count -eq 3 -and
    [bool]$completion.one_shot_attempt_consumed -and
    -not [bool]$completion.replacement_or_selective_rerun_permitted -and
    -not [bool]$completion.physical_acceptance_authority
) "complete retained disposition changed"

for ($index = 0; $index -lt 3; $index++) {
    $cell = $report.ordered_cells[$index]
    $closedCell = $closure.ordered_cells[$index]
    Assert-R23D52Closure (
        [string]$cell.cell_id -ceq $cellIds[$index] -and
        [string]$cell.arm_id -ceq [string]$closedCell.arm_id -and
        [int]$cell.process.exit_code -eq 0 -and
        -not [bool]$cell.process.timed_out -and
        [bool]$cell.process.supervisor_terminated -and
        [bool]$cell.process.termination_protocol_valid -and
        [string]$cell.terminal_projection_source -ceq "execution" -and
        [int]$cell.world_attempt_count -eq 1 -and
        [int]$cell.world_build_count -eq 1 -and
        [bool]$cell.world_build_count_exact -and
        [string]$terminalPaths[$index] -ceq
            [string]$cell.terminal_entry_cas.payload_path
    ) "cell process or terminal order changed: $index"
    $terminalPath = Join-Path $attemptRoot (
        "cells\$($cell.cell_id)\terminal.json"
    )
    $terminalPayload = Assert-R23D52PathAndCas $terminalPath (
        [string]$closedCell.terminal_sha256
    ) ([long]$closedCell.terminal_byte_length)
    $terminal = Get-Content -Raw -LiteralPath $terminalPayload |
        ConvertFrom-Json -Depth 100
    $tracePath = Join-Path $attemptRoot "traces\$($cell.cell_id).ndjson"
    [void](Assert-R23D52PathAndCas $tracePath (
        [string]$closedCell.trace_sha256
    ) ([long]$closedCell.trace_byte_length))
    Assert-R23D52Closure (
        [string]$terminal.schema_version -ceq
            "sporespore_qsdk_r23d52_engine_cell_report_v1" -and
        [string]$terminal.source_commit -ceq $sourceCommit -and
        [string]$terminal.cell_id -ceq [string]$closedCell.cell_id -and
        [bool]$terminal.execution.integrity_passed -and
        [bool]$terminal.execution.trace_retained_before_terminal_entry -and
        [int]$terminal.execution.world_attempt_count -eq 1 -and
        [int]$terminal.execution.world_build_count -eq 1 -and
        [int]$terminal.execution.controller_semantic_step_count -eq 2992 -and
        [int]$terminal.execution.validated_portable_command_count -eq 23936 -and
        [int]$terminal.execution.native_actuation_application_count -eq 23936 -and
        [bool]$terminal.trace_summary.ok -and
        @($terminal.trace_summary.failure_codes).Count -eq 0 -and
        [int]$terminal.trace_summary.row_count -eq 2992 -and
        [string]$terminal.trace_summary.raw_sha256 -ceq
            [string]$closedCell.trace_sha256 -and
        [int]$terminal.measurements.controller_error_count -eq 0 -and
        [int]$terminal.measurements.nonfinite_observation_count -eq 0 -and
        [int]$terminal.measurements.actuator_application_mismatch_count -eq 0 -and
        [int]$terminal.measurements.torso_ground_contact_step_count -eq 0 -and
        [double]$terminal.measurements.final_forward_displacement_m -ge
            0.030123046875 -and
        [double]$terminal.measurements.maximum_tilt_rad -le 0.6 -and
        [double]$terminal.measurements.minimum_torso_height_m -ge
            0.2499708652072946 -and
        @($terminal.measurements.contact_cycle_count_by_limb.PSObject.Properties |
            Where-Object { [int]$_.Value -ge 2 }).Count -eq 4
    ) "retained terminal or common walking gate changed: $($cell.cell_id)"
    Assert-R23D52Near (
        [double]$terminal.measurements.final_forward_displacement_m
    ) ([double]$closedCell.final_forward_displacement_m) (
        "forward displacement changed: $($cell.arm_id)"
    )
    Assert-R23D52Near ([double]$terminal.measurements.maximum_tilt_rad) (
        [double]$closedCell.maximum_tilt_rad
    ) "maximum tilt changed: $($cell.arm_id)"
    Assert-R23D52Near ([double]$terminal.measurements.minimum_torso_height_m) (
        [double]$closedCell.minimum_torso_height_m
    ) "minimum height changed: $($cell.arm_id)"
}

$measurement = $evaluation.engine_result.cycle_integrated_measurement
Assert-R23D52Near ([double]$measurement.arms.reference_zero.cycle_shift_rad) `
    -0.16702765012127485 "reference cycle shift changed"
Assert-R23D52Near ([double]$measurement.arms.positive_heading.cycle_shift_rad) `
    0.06765086932746489 "positive cycle shift changed"
Assert-R23D52Near ([double]$measurement.arms.negative_heading.cycle_shift_rad) `
    0.05928369858018745 "negative cycle shift changed"
Assert-R23D52Near (
    [double]$measurement.positive_reference_conditioned_cycle_shift_rad
) 0.23467851944873974 "conditioned positive shift changed"
Assert-R23D52Near (
    [double]$measurement.negative_reference_conditioned_cycle_shift_rad
) -0.2263113487014623 "conditioned negative shift changed"
Assert-R23D52Near (
    [double]$measurement.bilateral_reference_conditioned_cycle_separation_rad
) 0.008367170747277441 "bilateral separation changed"
Assert-R23D52Closure (
    -not [bool]$measurement.gates.raw_signed_cycle_shift -and
    -not [bool]$measurement.gates.reference_conditioned_cycle_shift -and
    -not [bool]$measurement.passed -and
    [double]$measurement.arms.negative_heading.cycle_shift_rad -gt 0.0 -and
    [double]$measurement.negative_reference_conditioned_cycle_shift_rad -lt 0.0 -and
    (@($evaluation.engine_result.measurement_failure_codes) -join ',') -ceq
        "raw_signed_cycle_shift,reference_conditioned_cycle_shift"
) "turning negative or zero-floor sign failure changed"

$r51Closure = Get-Content -Raw -LiteralPath $r51ClosurePath |
    ConvertFrom-Json -Depth 100
$r51ReferencePayload = Assert-R23D52Cas (
    [string]$r51Closure.reference_cell.terminal.sha256
) ([long]$r51Closure.reference_cell.terminal.byte_length)
$r51Reference = Get-Content -Raw -LiteralPath $r51ReferencePayload |
    ConvertFrom-Json -Depth 100
$r52ReferencePayload = Assert-R23D52Cas (
    [string]$closure.ordered_cells[0].terminal_sha256
) ([long]$closure.ordered_cells[0].terminal_byte_length)
$r52Reference = Get-Content -Raw -LiteralPath $r52ReferencePayload |
    ConvertFrom-Json -Depth 100
Assert-R23D52Closure (
    [double]$r51Reference.measurements.final_forward_displacement_m -eq
        [double]$r52Reference.measurements.final_forward_displacement_m -and
    [double]$r51Reference.measurements.maximum_tilt_rad -eq
        [double]$r52Reference.measurements.maximum_tilt_rad -and
    [double]$r51Reference.measurements.minimum_torso_height_m -eq
        [double]$r52Reference.measurements.minimum_torso_height_m -and
    [int]$r51Reference.measurements.torso_ground_contact_step_count -eq
        [int]$r52Reference.measurements.torso_ground_contact_step_count -and
    ($r51Reference.measurements.contact_cycle_count_by_limb | ConvertTo-Json -Compress) -ceq
        ($r52Reference.measurements.contact_cycle_count_by_limb | ConvertTo-Json -Compress) -and
    [bool]$closure.official_result.r23d51_reference_selected_metrics_reproduced_exactly
) "R51/R52 reference selected-metric replay changed"

# Rebuild the evaluator namespace from the source CAS rather than today's checkout.
$tempBase = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\', '/')
$tempRoot = [IO.Path]::GetFullPath((Join-Path $tempBase (
    "sporespore-r23d52-closure-" + [Guid]::NewGuid().ToString("N")
)))
$tempPrefix = $tempBase + [IO.Path]::DirectorySeparatorChar
Assert-R23D52Closure (
    $tempRoot.StartsWith($tempPrefix, [StringComparison]::OrdinalIgnoreCase)
) "temporary evaluator root escaped system temp"
try {
    foreach ($index in 0..(@($freeze.source_bindings).Count - 1)) {
        $binding = $freeze.source_bindings[$index]
        $relative = [string]$binding.path
        if ($relative -notmatch '^sdk/(turning|python)/') { continue }
        $sourcePayload = [string](
            $freeze.content_addressed_inputs.source_bindings[$index].payload_path
        )
        $destination = Join-Path $tempRoot $relative
        [void][IO.Directory]::CreateDirectory((Split-Path -Parent $destination))
        Copy-Item -LiteralPath $sourcePayload -Destination $destination
    }
    # These immutable predecessor closures are verifier dependencies pinned by
    # the R52 manifest, not production source bindings. Materialize their exact
    # historical Git blobs so the replay never substitutes today's checkout.
    foreach ($relative in @(
        "sdk/turning/r23d31_cycle_integrated_directional_response_closure_v1.json",
        "sdk/turning/r23d32_finite_rapier_turning_replication_closure_v1.json"
    )) {
        $destination = Join-Path $tempRoot $relative
        [void][IO.Directory]::CreateDirectory((Split-Path -Parent $destination))
        [IO.File]::WriteAllBytes(
            $destination,
            (Get-R23D52GitBlobBytes $sourceCommit $relative)
        )
    }
    $evaluatorPath = Join-Path $tempRoot (
        "sdk\turning\r23d52_godot_segment_origin_reanchor_evaluator.py"
    )
    $evaluatorOutput = @(& $Python $evaluatorPath evaluate-complete `
        --manifest (Join-Path $attemptRoot "terminal-paths.json") `
        --expected-source-commit $sourceCommit --repo-root $repoRoot 2>&1)
    Assert-R23D52Closure ($LASTEXITCODE -eq 0) ($evaluatorOutput -join "`n")
    $marker = "QSDK_R23D52_COMPLETE_EVALUATION "
    $lines = @($evaluatorOutput | Where-Object { $_.StartsWith($marker) })
    Assert-R23D52Closure ($lines.Count -eq 1) "pinned evaluator marker changed"
    $recomputed = $lines[0].Substring($marker.Length) |
        ConvertFrom-Json -Depth 100
    Assert-R23D52Closure (
        [string]$recomputed.classification -ceq $classification -and
        [bool]$recomputed.engine_result.all_cells_execution_valid -and
        [bool]$recomputed.engine_result.all_common_physical_gates_passed -and
        -not [bool]$recomputed.engine_result.mechanism_selected -and
        -not [bool]$recomputed.engine_result.cycle_integrated_measurement.passed -and
        @($recomputed.cell_evaluations | Where-Object {
            [bool]$_.execution_valid -and [bool]$_.common_physical_gate_passed
        }).Count -eq 3
    ) "pinned evaluator no longer reconstructs the complete negative"
} finally {
    if (Test-Path -LiteralPath $tempRoot) {
        $resolvedCleanup = [IO.Path]::GetFullPath($tempRoot)
        Assert-R23D52Closure (
            $resolvedCleanup.StartsWith(
                $tempPrefix,
                [StringComparison]::OrdinalIgnoreCase
            )
        ) "temporary cleanup target escaped system temp"
        Remove-Item -LiteralPath $resolvedCleanup -Recurse -Force
    }
}

Assert-R23D52Closure (
    [bool]$closure.supervisor_repair_observation.repair_observed_successfully -and
    [int]$closure.supervisor_repair_observation.successful_cell_projection_count -eq 3 -and
    -not [bool]$closure.supervisor_repair_observation.r23d51_root_level_success_count_read_repeated -and
    [int]$closure.supervisor_repair_observation.post_capture_projection_failure_count -eq 0 -and
    [bool]$closure.official_result.all_cells_walked_upright_with_zero_torso_contacts -and
    -not [bool]$closure.official_result.turning_measurement_passed -and
    [bool]$closure.official_result.negative_arm_fails_direction_at_zero_floor -and
    -not [bool]$closure.official_result.segment_origin_reanchor_mechanism_selected -and
    [bool]$closure.scientific_interpretation.threshold_only_successor_not_supported_by_this_result -and
    [bool]$closure.claims.r23d52_supervisor_terminal_projection_route_observed_successfully -and
    [bool]$closure.claims.finite_outcome_exposed_godot_jolt_three_world_common_walking -and
    -not [bool]$closure.claims.segment_origin_reanchor_mechanism_selected_for_held_out_validation -and
    -not [bool]$closure.claims.fresh_godot_jolt_turning -and
    -not [bool]$closure.claims.portable_basic_turning -and
    -not [bool]$closure.claims.finite_three_engine_turning -and
    -not [bool]$closure.claims.q_sdk_r23_satisfied -and
    -not [bool]$closure.claims.cross_engine_equivalence -and
    -not [bool]$closure.claims.population_robustness -and
    -not [bool]$closure.claims.prone_to_standing -and
    -not [bool]$closure.claims.release_authorized -and
    -not [bool]$closure.claims.physical_acceptance_authority
) "scientific or claim boundary changed"

$completedAttempts = @(
    Get-ChildItem -LiteralPath $evidenceRoot -Directory |
        Where-Object {
            $_.Name -like "qsdk-r23d52-*" -and
            (Test-Path -LiteralPath (Join-Path $_.FullName "completion.json"))
        }
)
Assert-R23D52Closure (
    $completedAttempts.Count -eq 1 -and
    $completedAttempts[0].FullName -ceq $attemptRoot
) "R23D52 one-shot attempt count changed"

Write-Host (
    "QSDK_R23D52_CLOSURE_PASS classification=negative_exposed_replay " +
    "worlds=3 exits=3 walking=3 turning=False projection_repaired=True " +
    "zero_floor_negative=True fresh=False three_engine=False rerun=False"
)
