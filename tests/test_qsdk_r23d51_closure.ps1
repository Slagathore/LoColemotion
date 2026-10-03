#requires -Version 7.0

[CmdletBinding()]
param([string]$Python = "python")

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$evidenceRoot = "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence"
$artifactRoot = Join-Path $evidenceRoot "artifacts\sha256"
$attemptRoot = Join-Path $evidenceRoot "qsdk-r23d51-20260814T063943Z"
$closurePath = Join-Path $repoRoot (
    "sdk\turning\r23d51_godot_segment_origin_reanchor_closure_v1.json"
)
$sourceCommit = "d33213a4611ea254556f2cffae4045049a563283"
$referenceCell = (
    "godot_jolt__r23d29_heading_segment_origin_reanchor_development__" +
    "reference_zero"
)
$positiveCell = (
    "godot_jolt__r23d29_heading_segment_origin_reanchor_development__" +
    "positive_heading"
)
$negativeCell = (
    "godot_jolt__r23d29_heading_segment_origin_reanchor_development__" +
    "negative_heading"
)
$tolerance = 1.0e-12

function Assert-R23D51Closure([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "QSDK-R23D51 CLOSURE: $Message" }
}

function Assert-Near([double]$Actual, [double]$Expected, [string]$Message) {
    Assert-R23D51Closure (
        [double]::IsFinite($Actual) -and
        [Math]::Abs($Actual - $Expected) -le $tolerance
    ) $Message
}

function Get-R23D51Sha256([string]$Path) {
    return "sha256:" + (
        Get-FileHash -LiteralPath $Path -Algorithm SHA256
    ).Hash.ToLowerInvariant()
}

function Get-R23D51BytesSha256([byte[]]$Bytes) {
    return "sha256:" + [Convert]::ToHexString(
        [Security.Cryptography.SHA256]::HashData($Bytes)
    ).ToLowerInvariant()
}

function Get-R23D51GitBlobBytes([string]$Commit, [string]$RelativePath) {
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
    Assert-R23D51Closure ($process.Start()) "could not start git cat-file"
    $memory = [IO.MemoryStream]::new()
    try {
        $process.StandardOutput.BaseStream.CopyTo($memory)
        $stderr = $process.StandardError.ReadToEnd()
        $process.WaitForExit()
        Assert-R23D51Closure ($process.ExitCode -eq 0) (
            "historical blob unavailable: $RelativePath; $stderr"
        )
        return ,([byte[]]$memory.ToArray())
    } finally {
        $memory.Dispose()
        $process.Dispose()
    }
}

function Assert-R23D51Cas([string]$Sha256, [long]$ByteLength) {
    Assert-R23D51Closure ($Sha256 -cmatch '^sha256:[0-9a-f]{64}$') (
        "invalid CAS digest: $Sha256"
    )
    $directory = Join-Path $artifactRoot $Sha256.Substring(7)
    $payload = Join-Path $directory "payload.bin"
    $manifestPath = Join-Path $directory "manifest.json"
    Assert-R23D51Closure (
        (Test-Path -LiteralPath $payload -PathType Leaf) -and
        (Test-Path -LiteralPath $manifestPath -PathType Leaf) -and
        (Get-Item -LiteralPath $payload).Length -eq $ByteLength -and
        (Get-R23D51Sha256 $payload) -ceq $Sha256
    ) "CAS payload changed: $Sha256"
    $manifest = Get-Content -Raw -LiteralPath $manifestPath |
        ConvertFrom-Json -Depth 20
    Assert-R23D51Closure (
        [string]$manifest.schema_version -ceq
            "sporespore_content_addressed_artifact_manifest_v1" -and
        [string]$manifest.algorithm -ceq "sha256" -and
        [string]$manifest.sha256 -ceq $Sha256 -and
        [long]$manifest.byte_length -eq $ByteLength -and
        [string]$manifest.payload_name -ceq "payload.bin"
    ) "CAS manifest changed: $Sha256"
    return $payload
}

function Assert-R23D51PathAndCas(
    [string]$Path,
    [string]$Sha256,
    [long]$ByteLength
) {
    $resolved = [IO.Path]::GetFullPath($Path)
    Assert-R23D51Closure (
        (Test-Path -LiteralPath $resolved -PathType Leaf) -and
        (Get-Item -LiteralPath $resolved).Length -eq $ByteLength -and
        (Get-R23D51Sha256 $resolved) -ceq $Sha256
    ) "retained artifact changed: $resolved"
    $payload = Assert-R23D51Cas $Sha256 $ByteLength
    Assert-R23D51Closure (
        (Get-R23D51Sha256 $payload) -ceq (Get-R23D51Sha256 $resolved)
    ) "retained artifact and CAS differ: $resolved"
    return $payload
}

Assert-R23D51Closure (
    (git -C $repoRoot rev-parse --show-toplevel).Trim().Replace('/', '\') -ceq
        $repoRoot -and
    (git -C $repoRoot remote get-url origin).Trim() -ceq
        "https://github.com/Slagathore/sporespore.git"
) "repository identity changed"

$closure = Get-Content -Raw -LiteralPath $closurePath |
    ConvertFrom-Json -Depth 100
Assert-R23D51Closure (
    [string]$closure.schema_version -ceq
        "sporespore_qsdk_r23d51_godot_segment_origin_reanchor_closure_v1" -and
    [string]$closure.status -ceq
        "closed_consumed_invalid_incomplete_after_valid_reference_cell_supervisor_schema_projection_failure" -and
    [string]$closure.source_commit -ceq $sourceCommit -and
    (git -C $repoRoot rev-parse "$sourceCommit`^{tree}").Trim() -ceq
        [string]$closure.source_tree_git_oid -and
    [string]$closure.attempt_id -ceq "f662f0a88fd94253a959ee80d62f7d29" -and
    [int]$closure.campaign_seed -eq 21512 -and
    [bool]$closure.identity_consumed -and
    -not [bool]$closure.same_identity_rerun_allowed -and
    -not [bool]$closure.selective_rerun_allowed -and
    -not [bool]$closure.fresh_held_out_condition_consumed -and
    -not [bool]$closure.successor_campaign_opened -and
    [bool]$closure.physical_series_paused_before_successor
) "immutable disposition changed"

foreach ($input in @($closure.prospective_inputs)) {
    $relative = [string]$input.path
    $bytes = Get-R23D51GitBlobBytes $sourceCommit $relative
    Assert-R23D51Closure (
        $bytes.Length -eq [long]$input.byte_length -and
        (Get-R23D51BytesSha256 $bytes) -ceq [string]$input.raw_sha256 -and
        (git -C $repoRoot rev-parse "$sourceCommit`:$relative").Trim() -ceq
            [string]$input.git_blob_oid
    ) "prospective source identity changed: $relative"
}

$firstFailure = Assert-R23D51PathAndCas (
    [string]$closure.qualification_history.first_provenance_refusal.retained_failure_path
) ([string]$closure.qualification_history.first_provenance_refusal.retained_failure_sha256) (
    [long]$closure.qualification_history.first_provenance_refusal.retained_failure_byte_length
)
$firstFailureDocument = Get-Content -Raw -LiteralPath $firstFailure |
    ConvertFrom-Json -Depth 30
Assert-R23D51Closure (
    [string]$firstFailureDocument.source_commit -ceq
        "0fcd4d3836dbf86423f1923b66c87d3b20b2ff0b" -and
    -not [bool]$firstFailureDocument.campaign_local_qualification_passed -and
    -not [bool]$firstFailureDocument.physical_launch_prerequisite_satisfied -and
    [int]$closure.qualification_history.first_provenance_refusal.world_build_count -eq 0 -and
    -not [bool]$closure.qualification_history.first_provenance_refusal.physical_attempt_consumed
) "first provenance refusal changed"

$stableQualification = $closure.qualification_history.stable_shell_green_but_nonadoptable
$stableAttestationPath = Assert-R23D51PathAndCas (
    [string]$stableQualification.attestation_path
) ([string]$stableQualification.attestation_sha256) (
    [long]$stableQualification.attestation_byte_length
)
$stableAttestation = Get-Content -Raw -LiteralPath $stableAttestationPath |
    ConvertFrom-Json -Depth 100
Assert-R23D51Closure (
    @($stableAttestation.gate_receipts).Count -eq 17 -and
    @($stableAttestation.gate_receipts | Where-Object {
        [int]$_.physical_world_count -ne 0 -or
        [int]$_.physical_process_launch_count -ne 0
    }).Count -eq 0 -and
    [string]$stableAttestation.runtime.powershell.version -ceq "7.6.4" -and
    [string]$stableAttestation.runtime.host.framework_description -ceq
        ".NET 10.0.10" -and
    [string]$stableQualification.adoption_refusal -ceq
        "Runtime or host changed since LCA1 commissioning." -and
    -not [bool]$stableQualification.physical_attempt_consumed
) "non-adoptable green qualification changed"

$accepted = $closure.qualification_history.accepted_commissioned_runtime
$acceptedAttestationPath = Assert-R23D51PathAndCas (
    [string]$accepted.attestation_path
) ([string]$accepted.attestation_sha256) ([long]$accepted.attestation_byte_length)
$adoptionPath = Assert-R23D51PathAndCas (
    [string]$accepted.adoption_path
) ([string]$accepted.adoption_sha256) ([long]$accepted.adoption_byte_length)
$attestation = Get-Content -Raw -LiteralPath $acceptedAttestationPath |
    ConvertFrom-Json -Depth 100
$adoption = Get-Content -Raw -LiteralPath $adoptionPath |
    ConvertFrom-Json -Depth 100
Assert-R23D51Closure (
    [string]$attestation.source.commit -ceq $sourceCommit -and
    [int]$attestation.global_gate_count -eq 12 -and
    [int]$attestation.lineage_gate_count -eq 2 -and
    [int]$attestation.campaign_gate_count -eq 3 -and
    @($attestation.gate_receipts).Count -eq 17 -and
    @($attestation.gate_receipts | Where-Object {
        [int]$_.physical_world_count -ne 0 -or
        [int]$_.physical_process_launch_count -ne 0
    }).Count -eq 0 -and
    [string]$attestation.runtime.powershell.executable_sha256 -ceq
        "sha256:ab01263f184a0da3612974e5f5c46d75c4e1af1f23919d23c0f46a2cab275af5" -and
    [string]$attestation.runtime.powershell.version -ceq "7.6.0-preview.6" -and
    [string]$attestation.runtime.host.framework_description -ceq ".NET 10.0.0" -and
    [string]$adoption.source_commit -ceq $sourceCommit -and
    [int]$adoption.executed_gate_count -eq 17 -and
    [int]$adoption.gate_cas_object_count -eq 51 -and
    [bool]$adoption.physical_launch_prerequisite_satisfied -and
    -not [bool]$adoption.physical_acceptance_authority -and
    -not [bool]$adoption.release_authority
) "accepted qualification or adoption changed"

$rootArtifacts = [ordered]@{
    "physical-freeze.json" = $closure.physical_evidence.physical_freeze
    "attempt-authorization.json" = $closure.physical_evidence.attempt_authorization
    "completion.json" = $closure.physical_evidence.completion
}
$rootPayloads = @{}
foreach ($entry in $rootArtifacts.GetEnumerator()) {
    $rootPayloads[$entry.Key] = Assert-R23D51PathAndCas (
        (Join-Path $attemptRoot $entry.Key)
    ) ([string]$entry.Value.sha256) ([long]$entry.Value.byte_length)
}
$freeze = Get-Content -Raw -LiteralPath $rootPayloads["physical-freeze.json"] |
    ConvertFrom-Json -Depth 100
$attempt = Get-Content -Raw -LiteralPath $rootPayloads["attempt-authorization.json"] |
    ConvertFrom-Json -Depth 100
$completion = Get-Content -Raw -LiteralPath $rootPayloads["completion.json"] |
    ConvertFrom-Json -Depth 100
Assert-R23D51Closure (
    [string]$freeze.source_commit -ceq $sourceCommit -and
    [string]$freeze.source_tree_git_oid -ceq [string]$closure.source_tree_git_oid -and
    @($freeze.source_bindings).Count -eq 65 -and
    @($freeze.content_addressed_inputs.source_bindings).Count -eq 65 -and
    [int]$freeze.declared_world_count -eq 3 -and
    [bool]$freeze.source_checkout_bytes_equal_git_blobs -and
    [bool]$freeze.reproducible_runtime_materialization_passed -and
    [bool]$freeze.complete_zero_world_gate_passed -and
    [bool]$freeze.serial_execution_required -and
    [bool]$freeze.all_cells_run_regardless_of_intermediate_outcome -and
    [bool]$freeze.physical_execution_authorized -and
    [string]$freeze.campaign_attestation_adoption_sha256 -ceq
        [string]$accepted.adoption_sha256
) "physical freeze changed"

for ($index = 0; $index -lt @($freeze.source_bindings).Count; $index++) {
    $binding = $freeze.source_bindings[$index]
    $cas = $freeze.content_addressed_inputs.source_bindings[$index]
    $relative = [string]$binding.path
    $bytes = Get-R23D51GitBlobBytes $sourceCommit $relative
    Assert-R23D51Closure (
        [bool]$binding.raw_checkout_equals_git_blob -and
        [string]$binding.raw_sha256 -ceq [string]$cas.sha256 -and
        (Get-R23D51BytesSha256 $bytes) -ceq [string]$binding.raw_sha256 -and
        (git -C $repoRoot rev-parse "$sourceCommit`:$relative").Trim() -ceq
            [string]$binding.git_blob_oid
    ) "frozen source binding changed: $relative"
    [void](Assert-R23D51Cas ([string]$cas.sha256) ([long]$cas.byte_length))
}

Assert-R23D51Closure (
    [string]$attempt.attempt_id -ceq [string]$closure.attempt_id -and
    [string]$attempt.source_commit -ceq $sourceCommit -and
    @($attempt.ordered_matrix_cell_ids).Count -eq 3 -and
    [string]$attempt.ordered_matrix_cell_ids[0] -ceq $referenceCell -and
    [string]$attempt.ordered_matrix_cell_ids[1] -ceq $positiveCell -and
    [string]$attempt.ordered_matrix_cell_ids[2] -ceq $negativeCell -and
    [bool]$attempt.physical_execution_authorized -and
    [bool]$attempt.single_use_supervisor_authorization -and
    [bool]$attempt.matrix_authorization_immutable_before_first_world -and
    [bool]$attempt.all_cells_run_regardless_of_intermediate_outcome -and
    [bool]$attempt.one_shot_attempt_unconsumed
) "attempt authorization changed"
Assert-R23D51Closure (
    [string]$completion.status -ceq "invalid_or_incomplete_first_attempt" -and
    [string]$completion.source_commit -ceq $sourceCommit -and
    [bool]$completion.one_shot_attempt_consumed -and
    -not [bool]$completion.replacement_or_selective_rerun_permitted -and
    [string]$completion.failure_message -ceq
        "The property 'world_build_count' cannot be found on this object. Verify that the property exists." -and
    -not [bool]$completion.physical_acceptance_authority
) "emergency completion changed"

$cellRoot = Join-Path $attemptRoot "cells\$referenceCell"
$terminalPath = Join-Path $cellRoot "terminal.json"
$stdoutPath = Join-Path $cellRoot "stdout.txt"
$stderrPath = Join-Path $cellRoot "stderr.txt"
$tracePath = Join-Path $attemptRoot "traces\$referenceCell.ndjson"
$terminalPayload = Assert-R23D51PathAndCas $terminalPath (
    [string]$closure.reference_cell.terminal.sha256
) ([long]$closure.reference_cell.terminal.byte_length)
[void](Assert-R23D51PathAndCas $stdoutPath (
    [string]$closure.reference_cell.stdout.sha256
) ([long]$closure.reference_cell.stdout.byte_length))
[void](Assert-R23D51PathAndCas $stderrPath (
    [string]$closure.reference_cell.stderr.sha256
) ([long]$closure.reference_cell.stderr.byte_length))
[void](Assert-R23D51PathAndCas $tracePath (
    [string]$closure.reference_cell.trace.sha256
) ([long]$closure.reference_cell.trace.byte_length))
$terminal = Get-Content -Raw -LiteralPath $terminalPayload |
    ConvertFrom-Json -Depth 100
$stdout = Get-Content -Raw -LiteralPath $stdoutPath
$traceLineCount = ([IO.File]::ReadLines($tracePath) | Measure-Object).Count
Assert-R23D51Closure (
    [string]$terminal.schema_version -ceq
        "sporespore_qsdk_r23d51_engine_cell_report_v1" -and
    [string]$terminal.cell_id -ceq $referenceCell -and
    [string]$terminal.arm_id -ceq "reference_zero" -and
    [int]$terminal.execution.world_attempt_count -eq 1 -and
    [int]$terminal.execution.world_build_count -eq 1 -and
    [bool]$terminal.execution.integrity_passed -and
    [string]$terminal.execution.worker_failure_code -ceq "" -and
    [int]$terminal.execution.controller_semantic_step_count -eq 2992 -and
    [int]$terminal.execution.validated_portable_command_count -eq 23936 -and
    [int]$terminal.execution.native_actuation_application_count -eq 23936 -and
    [bool]$terminal.trace_summary.ok -and
    @($terminal.trace_summary.failure_codes).Count -eq 0 -and
    [int]$terminal.trace_summary.row_count -eq 2992 -and
    [string]$terminal.trace_summary.raw_sha256 -ceq
        [string]$closure.reference_cell.trace.sha256 -and
    @($terminal.trace_summary.task_frame_origin_transition_steps).Count -eq 4 -and
    (@($terminal.trace_summary.task_frame_origin_transition_steps) -join ',') -ceq
        "0,600,1800,2400" -and
    $traceLineCount -eq 2992 -and
    $stdout.Contains("QSDK_R23D51_GODOT_JOLT_TERMINAL ") -and
    $stdout.Contains("QSDK_R23D51_GODOT_SUPERVISOR_TERMINATION_READY ")
) "reference terminal, trace, or supervised termination changed"
Assert-Near ([double]$terminal.measurements.final_forward_displacement_m) `
    0.918538510799408 "reference displacement changed"
Assert-Near ([double]$terminal.measurements.maximum_tilt_rad) `
    0.165136683910642 "reference tilt changed"
Assert-Near ([double]$terminal.measurements.minimum_torso_height_m) `
    0.427709877490997 "reference height changed"
Assert-R23D51Closure (
    [int]$terminal.measurements.torso_ground_contact_step_count -eq 0 -and
    [int]$terminal.measurements.contact_cycle_count_by_limb.front_left -eq 3 -and
    [int]$terminal.measurements.contact_cycle_count_by_limb.front_right -eq 6 -and
    [int]$terminal.measurements.contact_cycle_count_by_limb.rear_left -eq 5 -and
    [int]$terminal.measurements.contact_cycle_count_by_limb.rear_right -eq 7
) "reference common physical measurements changed"

$cellDirectories = @(Get-ChildItem -LiteralPath (Join-Path $attemptRoot "cells") `
    -Directory | ForEach-Object Name)
Assert-R23D51Closure (
    $cellDirectories.Count -eq 1 -and $cellDirectories[0] -ceq $referenceCell -and
    -not (Test-Path -LiteralPath (Join-Path $attemptRoot "cells\$positiveCell")) -and
    -not (Test-Path -LiteralPath (Join-Path $attemptRoot "cells\$negativeCell")) -and
    -not (Test-Path -LiteralPath (Join-Path $attemptRoot "traces\$positiveCell.ndjson")) -and
    -not (Test-Path -LiteralPath (Join-Path $attemptRoot "traces\$negativeCell.ndjson"))
) "unexecuted turn-arm boundary changed"

$supervisorInput = @($closure.prospective_inputs | Where-Object {
    [string]$_.path -ceq "sdk/run_qsdk_r23d51_supervisor.ps1"
})
Assert-R23D51Closure ($supervisorInput.Count -eq 1) "supervisor binding missing"
$supervisorBytes = Get-R23D51GitBlobBytes $sourceCommit (
    [string]$supervisorInput[0].path
)
$supervisorText = [Text.UTF8Encoding]::new($false, $true).GetString($supervisorBytes)
Assert-R23D51Closure (
    $supervisorText.Contains('$worldBuildCount = [int]$terminal.world_build_count') -and
    $supervisorText.Contains('world_attempt_count = [int]$terminal.world_attempt_count') -and
    -not $terminal.PSObject.Properties.Name.Contains("world_build_count") -and
    -not $terminal.PSObject.Properties.Name.Contains("world_attempt_count") -and
    $terminal.PSObject.Properties.Name.Contains("execution") -and
    [string]$closure.failure_mechanism.failure_class -ceq
        "supervisor_worker_terminal_schema_projection_mismatch" -and
    -not [bool]$closure.failure_mechanism.physics_or_controller_failure -and
    -not [bool]$closure.failure_mechanism.worker_or_trace_integrity_failure
) "supervisor schema-projection mechanism changed"

$evaluationPath = Assert-R23D51PathAndCas (
    [string]$closure.reference_cell.closure_evaluation.path
) ([string]$closure.reference_cell.closure_evaluation.sha256) (
    [long]$closure.reference_cell.closure_evaluation.byte_length
)
$evaluationReceipt = Get-Content -Raw -LiteralPath $evaluationPath |
    ConvertFrom-Json -Depth 50
Assert-R23D51Closure (
    [string]$evaluationReceipt.source_commit -ceq $sourceCommit -and
    [string]$evaluationReceipt.terminal.raw_sha256 -ceq
        [string]$closure.reference_cell.terminal.sha256 -and
    [string]$evaluationReceipt.trace.raw_sha256 -ceq
        [string]$closure.reference_cell.trace.sha256 -and
    [int]$evaluationReceipt.trace.retained_row_count -eq 2992 -and
    [bool]$evaluationReceipt.evaluation.execution_valid -and
    [bool]$evaluationReceipt.evaluation.common_physical_gate_passed -and
    @($evaluationReceipt.evaluation.failed_gate_ids).Count -eq 0 -and
    [int]$evaluationReceipt.evaluation.world_attempt_count -eq 1 -and
    [int]$evaluationReceipt.evaluation.world_build_count -eq 1 -and
    -not [bool]$evaluationReceipt.complete_campaign_evaluation -and
    -not [bool]$evaluationReceipt.turning_inference_permitted
) "retained reference-cell evaluation changed"

$tempBase = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\', '/')
$tempRoot = Join-Path $tempBase (
    "sporespore-r23d51-closure-" + [Guid]::NewGuid().ToString("N")
)
$tempRoot = [IO.Path]::GetFullPath($tempRoot)
$tempPrefix = $tempBase + [IO.Path]::DirectorySeparatorChar
Assert-R23D51Closure (
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
    $pythonCode = @'
import json
import sys
from pathlib import Path
root = Path(sys.argv[2])
sys.path.insert(0, str(root / "sdk" / "python"))
sys.path.insert(0, str(root / "sdk" / "turning"))
import r23d51_godot_segment_origin_reanchor as design
import r23d51_godot_segment_origin_reanchor_evaluator as evaluator
entry = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
result, rows = evaluator.evaluate_entry(
    entry,
    design.cells()[0],
    expected_source_commit=sys.argv[4],
    authority_repo_root=Path(sys.argv[3]),
)
print(json.dumps({"evaluation": result, "row_count": len(rows)}, sort_keys=True))
'@
    $pythonOutput = @(& $Python -c $pythonCode $terminalPath $tempRoot `
        $repoRoot $sourceCommit 2>&1)
    Assert-R23D51Closure ($LASTEXITCODE -eq 0) ($pythonOutput -join "`n")
    $recomputed = ($pythonOutput -join "`n") | ConvertFrom-Json -Depth 30
    Assert-R23D51Closure (
        [int]$recomputed.row_count -eq 2992 -and
        [bool]$recomputed.evaluation.execution_valid -and
        [bool]$recomputed.evaluation.common_physical_gate_passed -and
        @($recomputed.evaluation.failed_gate_ids).Count -eq 0 -and
        [int]$recomputed.evaluation.world_attempt_count -eq 1 -and
        [int]$recomputed.evaluation.world_build_count -eq 1
    ) "frozen evaluator did not reproduce the reference-cell result"
} finally {
    if (Test-Path -LiteralPath $tempRoot) {
        $resolvedCleanup = [IO.Path]::GetFullPath($tempRoot)
        Assert-R23D51Closure (
            $resolvedCleanup.StartsWith(
                $tempPrefix,
                [StringComparison]::OrdinalIgnoreCase
            )
        ) "temporary cleanup target escaped system temp"
        Remove-Item -LiteralPath $resolvedCleanup -Recurse -Force
    }
}

Assert-R23D51Closure (
    [string]$closure.official_result.classification -ceq
        "invalid_incomplete_outcome_exposed_godot_segment_origin_development" -and
    [int]$closure.official_result.declared_cell_count -eq 3 -and
    [int]$closure.official_result.executed_cell_count -eq 1 -and
    -not [bool]$closure.official_result.all_declared_cells_executed_or_retained_as_failures -and
    [bool]$closure.official_result.reference_cell_execution_valid -and
    [bool]$closure.official_result.reference_cell_common_physical_gate_passed -and
    -not [bool]$closure.official_result.positive_heading_cell_executed -and
    -not [bool]$closure.official_result.negative_heading_cell_executed -and
    -not [bool]$closure.official_result.cycle_integrated_measurement_available -and
    -not [bool]$closure.official_result.segment_origin_reanchor_mechanism_selected_for_held_out_validation -and
    [bool]$closure.scientific_interpretation.reference_walking_result_may_be_retained -and
    -not [bool]$closure.scientific_interpretation.reference_walking_result_completes_r23d51_turning_question -and
    -not [bool]$closure.scientific_interpretation.missing_commanded_turn_arms_may_be_imputed -and
    [bool]$closure.scientific_interpretation.same_identity_selective_completion_forbidden -and
    [bool]$closure.claims.finite_reference_arm_common_walking_positive -and
    -not [bool]$closure.claims.r23d51_complete -and
    -not [bool]$closure.claims.segment_origin_reanchor_mechanism_selected_for_held_out_validation -and
    -not [bool]$closure.claims.fresh_godot_jolt_turning -and
    -not [bool]$closure.claims.portable_basic_turning -and
    -not [bool]$closure.claims.finite_three_engine_turning -and
    -not [bool]$closure.claims.cross_engine_equivalence -and
    -not [bool]$closure.claims.prone_to_standing -and
    -not [bool]$closure.claims.release_authorized -and
    -not [bool]$closure.claims.physical_acceptance_authority
) "result or claim boundary changed"

Write-Host (
    "QSDK_R23D51_CLOSURE_PASS status=invalid_incomplete " +
    "declared_cells=3 executed_cells=1 worlds=1 reference_execution_valid=True " +
    "reference_common_physical=True turn_cells=0 mechanism_selected=False " +
    "same_identity_rerun=False successor_open=False physical_series_paused=True"
)
