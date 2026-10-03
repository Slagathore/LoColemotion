#requires -Version 7.0

[CmdletBinding()]
param([string]$Python = "C:\Program Files\Python311\python.exe")

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$evidenceRoot = "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence"
$artifactRoot = Join-Path $evidenceRoot "artifacts\sha256"
$attemptRoot = Join-Path $evidenceRoot "qsdk-r23d53-20260814T092529Z"
$failedQualificationRoot = Join-Path $evidenceRoot (
    "qsdk-r23d53-attestation-64a84ef-lca1-runtime"
)
$stableQualificationRoot = Join-Path $evidenceRoot (
    "qsdk-r23d53-attestation-6e200c4-lca1-runtime"
)
$acceptedQualificationRoot = Join-Path $evidenceRoot (
    "qsdk-r23d53-attestation-6e200c4-lca1-preview6-runtime"
)
$closurePath = Join-Path $repoRoot (
    "sdk\turning\r23d53_godot_warmup_preserving_origin_reanchor_closure_v1.json"
)
$sourceCommit = "6e200c465e29ddfa4dfee911f7f11ab48f933019"
$classification = (
    "valid_complete_negative_outcome_exposed_godot_warmup_preserving_" +
    "origin_reanchor_development"
)
$candidateId = "r23d29_warmup_preserving_command_onset_origin_reanchor_development"
$cellIds = @(
    "godot_jolt__${candidateId}__reference_zero",
    "godot_jolt__${candidateId}__positive_heading",
    "godot_jolt__${candidateId}__negative_heading"
)
$tolerance = 1.0e-12

function Assert-R23D53Closure([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "QSDK-R23D53 CLOSURE: $Message" }
}

function Assert-R23D53Near(
    [double]$Actual,
    [double]$Expected,
    [string]$Message
) {
    Assert-R23D53Closure (
        [double]::IsFinite($Actual) -and
        [Math]::Abs($Actual - $Expected) -le $tolerance
    ) $Message
}

function Get-R23D53Sha256([string]$Path) {
    return "sha256:" + (
        Get-FileHash -LiteralPath $Path -Algorithm SHA256
    ).Hash.ToLowerInvariant()
}

function Get-R23D53BytesSha256([byte[]]$Bytes) {
    return "sha256:" + [Convert]::ToHexString(
        [Security.Cryptography.SHA256]::HashData($Bytes)
    ).ToLowerInvariant()
}

function Get-R23D53GitBlobBytes([string]$Commit, [string]$RelativePath) {
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
    Assert-R23D53Closure ($process.Start()) "could not start git cat-file"
    $memory = [IO.MemoryStream]::new()
    try {
        $process.StandardOutput.BaseStream.CopyTo($memory)
        $stderr = $process.StandardError.ReadToEnd()
        $process.WaitForExit()
        Assert-R23D53Closure ($process.ExitCode -eq 0) (
            "historical blob unavailable: $RelativePath; $stderr"
        )
        return ,([byte[]]$memory.ToArray())
    } finally {
        $memory.Dispose()
        $process.Dispose()
    }
}

function Assert-R23D53Cas([string]$Sha256, [long]$ByteLength) {
    Assert-R23D53Closure ($Sha256 -cmatch '^sha256:[0-9a-f]{64}$') (
        "invalid CAS digest: $Sha256"
    )
    $directory = Join-Path $artifactRoot $Sha256.Substring(7)
    $payload = Join-Path $directory "payload.bin"
    $manifestPath = Join-Path $directory "manifest.json"
    Assert-R23D53Closure (
        (Test-Path -LiteralPath $payload -PathType Leaf) -and
        (Test-Path -LiteralPath $manifestPath -PathType Leaf) -and
        (Get-Item -LiteralPath $payload).Length -eq $ByteLength -and
        (Get-R23D53Sha256 $payload) -ceq $Sha256
    ) "CAS payload changed: $Sha256"
    $manifest = Get-Content -Raw -LiteralPath $manifestPath |
        ConvertFrom-Json -Depth 20
    Assert-R23D53Closure (
        [string]$manifest.schema_version -ceq
            "sporespore_content_addressed_artifact_manifest_v1" -and
        [string]$manifest.algorithm -ceq "sha256" -and
        [string]$manifest.sha256 -ceq $Sha256 -and
        [long]$manifest.byte_length -eq $ByteLength -and
        [string]$manifest.payload_name -ceq "payload.bin"
    ) "CAS manifest changed: $Sha256"
    return $payload
}

function Assert-R23D53PathAndCas(
    [string]$Path,
    [string]$Sha256,
    [long]$ByteLength
) {
    Assert-R23D53Closure (
        (Test-Path -LiteralPath $Path -PathType Leaf) -and
        (Get-Item -LiteralPath $Path).Length -eq $ByteLength -and
        (Get-R23D53Sha256 $Path) -ceq $Sha256
    ) "retained artifact changed: $Path"
    $payload = Assert-R23D53Cas $Sha256 $ByteLength
    Assert-R23D53Closure (
        (Get-R23D53Sha256 $payload) -ceq (Get-R23D53Sha256 $Path)
    ) "retained artifact and CAS diverged: $Path"
    return $payload
}

$gitRoot = [IO.Path]::GetFullPath(
    (git -C $repoRoot rev-parse --show-toplevel).Trim()
).TrimEnd('\', '/')
Assert-R23D53Closure (
    $gitRoot -ieq $repoRoot.TrimEnd('\', '/') -and
    (git -C $repoRoot remote get-url origin).Trim() -ceq
        "https://github.com/Slagathore/sporespore.git"
) "repository authority changed"

$closure = Get-Content -Raw -LiteralPath $closurePath |
    ConvertFrom-Json -Depth 100
Assert-R23D53Closure (
    [string]$closure.schema_version -ceq
        "sporespore_qsdk_r23d53_godot_warmup_preserving_origin_reanchor_closure_v1" -and
    [string]$closure.status -ceq
        "closed_consumed_valid_complete_negative_outcome_exposed_godot_warmup_preserving_origin_reanchor_development" -and
    [string]$closure.campaign_id -ceq
        "QSDK-R23D53-GODOT-WARMUP-PRESERVING-ORIGIN-REANCHOR-DEVELOPMENT" -and
    [string]$closure.gate_id -ceq "QSDK-R23D53" -and
    [string]$closure.release_gate_id -ceq "QSDK-R23" -and
    [string]$closure.source_commit -ceq $sourceCommit -and
    [string]$closure.source_tree_git_oid -ceq
        "594612c72039899b7c2aab12121f1bdc2d653e1e" -and
    [string]$closure.attempt_id -ceq "12f432712e8f46858bcc728e4a9c022b" -and
    [int]$closure.campaign_seed -eq 21512 -and
    [bool]$closure.identity_consumed -and
    -not [bool]$closure.same_identity_rerun_allowed -and
    -not [bool]$closure.selective_rerun_allowed -and
    -not [bool]$closure.fresh_held_out_condition_consumed -and
    -not [bool]$closure.successor_campaign_opened -and
    [bool]$closure.physical_series_paused_before_successor
) "closure identity or immutable disposition changed"

$tree = (git -C $repoRoot rev-parse "${sourceCommit}^{tree}").Trim()
Assert-R23D53Closure (
    $LASTEXITCODE -eq 0 -and $tree -ceq [string]$closure.source_tree_git_oid
) "source commit or tree is unavailable"

Assert-R23D53Closure (@($closure.prospective_inputs).Count -eq 12) (
    "prospective input inventory count changed"
)
foreach ($input in $closure.prospective_inputs) {
    $relative = [string]$input.path
    $bytes = Get-R23D53GitBlobBytes $sourceCommit $relative
    $oid = (git -C $repoRoot rev-parse "$sourceCommit`:$relative").Trim()
    Assert-R23D53Closure (
        $LASTEXITCODE -eq 0 -and
        $oid -ceq [string]$input.git_blob_oid -and
        $bytes.Length -eq [long]$input.byte_length -and
        (Get-R23D53BytesSha256 $bytes) -ceq [string]$input.raw_sha256
    ) "prospective historical input changed: $relative"
    [void](Assert-R23D53Cas (
        [string]$input.raw_sha256
    ) ([long]$input.byte_length))
}

$history = $closure.qualification_history
$failed = $history.initial_provenance_refusal
$failedFiles = [ordered]@{
    "failure.json" = [pscustomobject]@{
        sha256 = [string]$failed.failure_receipt_sha256
        byte_length = [long]$failed.failure_receipt_byte_length
    }
    "004-CAK1-EVIDENCE-PROVENANCE.receipt.json" = [pscustomobject]@{
        sha256 = [string]$failed.failed_gate_receipt_sha256
        byte_length = [long]$failed.failed_gate_receipt_byte_length
    }
    "004-CAK1-EVIDENCE-PROVENANCE.stderr.log" = [pscustomobject]@{
        sha256 = [string]$failed.failed_gate_stderr_sha256
        byte_length = [long]$failed.failed_gate_stderr_byte_length
    }
}
$failedPayloads = @{}
foreach ($entry in $failedFiles.GetEnumerator()) {
    $failedPayloads[$entry.Key] = Assert-R23D53PathAndCas (
        (Join-Path $failedQualificationRoot $entry.Key)
    ) ([string]$entry.Value.sha256) ([long]$entry.Value.byte_length)
}
$failure = Get-Content -Raw -LiteralPath $failedPayloads["failure.json"] |
    ConvertFrom-Json -Depth 30
$failureGate = Get-Content -Raw -LiteralPath (
    $failedPayloads["004-CAK1-EVIDENCE-PROVENANCE.receipt.json"]
) | ConvertFrom-Json -Depth 30
Assert-R23D53Closure (
    [string]$failed.source_commit -ceq
        "64a84efb648cd505c6718e235f30bb9db5c1ca1f" -and
    [string]$failed.source_tree_git_oid -ceq
        "c2e197612db748a48e68afb1c223bc41ec293c54" -and
    [int]$failed.passed_gate_count -eq 3 -and
    [string]$failed.failed_gate_id -ceq "CAK1-EVIDENCE-PROVENANCE" -and
    [int]$failed.physical_process_launch_count -eq 0 -and
    [int]$failed.model_construction_count -eq 0 -and
    [int]$failed.world_build_count -eq 0 -and
    -not [bool]$failed.physical_attempt_consumed -and
    [string]$failure.schema_version -ceq
        "sporespore_locomotion_campaign_attestation_failure_v1" -and
    [string]$failure.source_commit -ceq [string]$failed.source_commit -and
    -not [bool]$failure.campaign_local_qualification_passed -and
    -not [bool]$failure.physical_launch_prerequisite_satisfied -and
    [string]$failureGate.gate_id -ceq "CAK1-EVIDENCE-PROVENANCE" -and
    [int]$failureGate.exit_code -eq 1 -and
    -not [bool]$failureGate.passed -and
    [int]$failureGate.physical_process_launch_count -eq 0 -and
    [int]$failureGate.physical_world_count -eq 0
) "initial fail-closed qualification history changed"

$repair = $history.verifier_repair
$repairBytes = Get-R23D53GitBlobBytes $sourceCommit ([string]$repair.path)
Assert-R23D53Closure (
    $repairBytes.Length -eq [long]$repair.byte_length -and
    (Get-R23D53BytesSha256 $repairBytes) -ceq [string]$repair.raw_sha256 -and
    -not [bool]$repair.changes_frozen_physical_question -and
    -not [bool]$repair.changes_physics_controller_threshold_seed_or_world_count
) "prospective verifier-only repair changed"

$stableSpec = $history.passing_uncommissioned_runtime_attestation
$stablePayload = Assert-R23D53PathAndCas (
    (Join-Path $stableQualificationRoot "attestation.json")
) ([string]$stableSpec.sha256) ([long]$stableSpec.byte_length)
$stable = Get-Content -Raw -LiteralPath $stablePayload |
    ConvertFrom-Json -Depth 100
Assert-R23D53Closure (
    [string]$stable.status -ceq
        "campaign_local_godot_including_qualification_passed" -and
    [string]$stable.source.commit -ceq $sourceCommit -and
    [int]$stable.executed_gate_count -eq 18 -and
    @($stable.gate_receipts).Count -eq 18 -and
    @($stable.gate_receipts | Where-Object {
        -not [bool]$_.passed -or [int]$_.exit_code -ne 0 -or
        [int]$_.physical_process_launch_count -ne 0 -or
        [int]$_.physical_world_count -ne 0
    }).Count -eq 0 -and
    [string]$stable.runtime.powershell.executable_sha256 -ceq
        [string]$stableSpec.powershell_executable_sha256 -and
    [string]$stable.runtime.powershell.version -ceq "7.6.4" -and
    [string]$stable.runtime.host.framework_description -ceq ".NET 10.0.10" -and
    -not [bool]$stableSpec.adoptable_for_lca1 -and
    [string]$stableSpec.nonadoption_reason -ceq
        "runtime_identity_did_not_match_commissioned_lca1_executor"
) "passing but noncommissioned qualification history changed"

$acceptedSpec = $history.accepted_attestation
$acceptedPayload = Assert-R23D53PathAndCas (
    (Join-Path $acceptedQualificationRoot "attestation.json")
) ([string]$acceptedSpec.sha256) ([long]$acceptedSpec.byte_length)
$adoptionSpec = $history.adoption
$adoptionPayload = Assert-R23D53PathAndCas (
    (Join-Path $acceptedQualificationRoot "adoption.json")
) ([string]$adoptionSpec.sha256) ([long]$adoptionSpec.byte_length)
$attestation = Get-Content -Raw -LiteralPath $acceptedPayload |
    ConvertFrom-Json -Depth 100
$adoption = Get-Content -Raw -LiteralPath $adoptionPayload |
    ConvertFrom-Json -Depth 100
Assert-R23D53Closure (
    [string]$attestation.schema_version -ceq
        "sporespore_locomotion_campaign_attestation_v1" -and
    [string]$attestation.status -ceq
        "campaign_local_godot_including_qualification_passed" -and
    [string]$attestation.source.commit -ceq $sourceCommit -and
    [string]$attestation.source.tree_git_oid -ceq
        [string]$closure.source_tree_git_oid -and
    [bool]$attestation.source.clean_pushed_live -and
    [int]$attestation.global_gate_count -eq 12 -and
    [int]$attestation.lineage_gate_count -eq 3 -and
    [int]$attestation.campaign_gate_count -eq 3 -and
    [int]$attestation.executed_gate_count -eq 18 -and
    @($attestation.gate_receipts).Count -eq 18 -and
    @($attestation.gate_receipts | Where-Object {
        -not [bool]$_.passed -or [int]$_.exit_code -ne 0 -or
        [int]$_.physical_process_launch_count -ne 0 -or
        [int]$_.physical_world_count -ne 0
    }).Count -eq 0 -and
    [string]$attestation.runtime.powershell.executable_path -ceq
        "C:\Program Files\PowerShell\7-preview\pwsh.exe" -and
    [string]$attestation.runtime.powershell.executable_sha256 -ceq
        [string]$acceptedSpec.powershell_executable_sha256 -and
    [string]$attestation.runtime.powershell.version -ceq
        "7.6.0-preview.6" -and
    [string]$attestation.runtime.host.framework_description -ceq ".NET 10.0.0" -and
    [string]$adoption.source_commit -ceq $sourceCommit -and
    [string]$adoption.scoped_attestation_raw_sha256 -ceq
        [string]$acceptedSpec.sha256 -and
    [bool]$adoption.runtime_matches_commissioning -and
    [bool]$adoption.physical_launch_prerequisite_satisfied -and
    -not [bool]$adoption.physical_acceptance_authority
) "accepted qualification or adoption identity changed"

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
    $rootPayloads[$entry.Key] = Assert-R23D53PathAndCas (
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

Assert-R23D53Closure (
    [string]$freeze.source_commit -ceq $sourceCommit -and
    [string]$freeze.source_tree_git_oid -ceq [string]$closure.source_tree_git_oid -and
    @($freeze.source_bindings).Count -eq 70 -and
    @($freeze.content_addressed_inputs.source_bindings).Count -eq 70 -and
    [int]$freeze.declared_world_count -eq 3 -and
    [bool]$freeze.source_checkout_bytes_equal_git_blobs -and
    [bool]$freeze.reproducible_runtime_materialization_passed -and
    [bool]$freeze.complete_zero_world_gate_passed -and
    [bool]$freeze.serial_execution_required -and
    [bool]$freeze.all_cells_run_regardless_of_intermediate_outcome -and
    [bool]$freeze.physical_execution_authorized -and
    [string]$freeze.campaign_attestation_adoption_sha256 -ceq
        [string]$adoptionSpec.sha256 -and
    [int]$freeze.zero_world_receipt.task_frame_origin_gate.assertion_count -eq 34 -and
    [bool]$freeze.zero_world_receipt.task_frame_origin_gate.initial_origin_preserved -and
    [int]$freeze.zero_world_receipt.task_frame_origin_gate.turn_onset_reanchor_count -eq 1 -and
    [int]$freeze.zero_world_receipt.terminal_execution_projection.positive_terminal_projection_canary_count -eq 1 -and
    [int]$freeze.zero_world_receipt.terminal_execution_projection.failure_terminal_projection_canary_count -eq 2 -and
    [int]$freeze.zero_world_receipt.terminal_execution_projection.terminal_projection_mutation_rejection_count -eq 10
) "physical freeze or complete zero-world receipt changed"

for ($index = 0; $index -lt @($freeze.source_bindings).Count; $index++) {
    $binding = $freeze.source_bindings[$index]
    $cas = $freeze.content_addressed_inputs.source_bindings[$index]
    $relative = [string]$binding.path
    $bytes = Get-R23D53GitBlobBytes $sourceCommit $relative
    Assert-R23D53Closure (
        [bool]$binding.raw_checkout_equals_git_blob -and
        [string]$binding.raw_sha256 -ceq [string]$cas.sha256 -and
        (Get-R23D53BytesSha256 $bytes) -ceq [string]$binding.raw_sha256 -and
        (git -C $repoRoot rev-parse "$sourceCommit`:$relative").Trim() -ceq
            [string]$binding.git_blob_oid
    ) "frozen source binding changed: $relative"
    [void](Assert-R23D53Cas ([string]$cas.sha256) ([long]$cas.byte_length))
}

[void](Assert-R23D53Cas (
    [string]$closure.runtime_materialization.godot_adapter_debug_sha256
) ([long]$closure.runtime_materialization.godot_adapter_debug_byte_length))
foreach ($runtime in @(
    [pscustomobject]@{
        name = "godot_jolt_host"
        sha256 = [string]$closure.runtime_materialization.godot_executable_sha256
        length = [long]$closure.runtime_materialization.godot_executable_byte_length
    },
    [pscustomobject]@{
        name = "evaluator_python_host"
        sha256 = [string]$closure.runtime_materialization.python_executable_sha256
        length = [long]$closure.runtime_materialization.python_executable_byte_length
    },
    [pscustomobject]@{
        name = "powershell_trace_host"
        sha256 = [string]$closure.runtime_materialization.powershell_executable_sha256
        length = [long]$closure.runtime_materialization.powershell_executable_byte_length
    }
)) {
    $binding = @($freeze.external_runtime_bindings | Where-Object {
        [string]$_.name -ceq [string]$runtime.name
    })
    Assert-R23D53Closure (
        $binding.Count -eq 1 -and
        [string]$binding[0].raw_sha256 -ceq [string]$runtime.sha256
    ) "external runtime binding changed: $($runtime.name)"
    [void](Assert-R23D53Cas ([string]$runtime.sha256) ([long]$runtime.length))
}
Assert-R23D53Closure (
    [string]$freeze.runtime_artifacts[0].raw_sha256 -ceq
        [string]$closure.runtime_materialization.godot_adapter_debug_sha256 -and
    [int]$freeze.runtime_artifacts[0].build_receipt.source_date_epoch -eq
        1786698918 -and
    -not [bool]$freeze.runtime_artifacts[0].build_receipt.cargo_incremental -and
    [int]$freeze.runtime_artifacts[0].build_receipt.remapped_path_count -eq 4 -and
    [bool]$freeze.runtime_artifacts[0].build_receipt.msvc_brepro -and
    [bool]$freeze.runtime_artifacts[0].build_receipt.pdb_alt_path_bare_name -and
    -not [bool]$freeze.runtime_artifacts[0].build_receipt.codegen_units_forced
) "reproducible runtime materialization changed"

Assert-R23D53Closure (
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

Assert-R23D53Closure (
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
    Assert-R23D53Closure (
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
    $terminalPayload = Assert-R23D53PathAndCas $terminalPath (
        [string]$closedCell.terminal_sha256
    ) ([long]$closedCell.terminal_byte_length)
    $terminal = Get-Content -Raw -LiteralPath $terminalPayload |
        ConvertFrom-Json -Depth 100
    $tracePath = Join-Path $attemptRoot "traces\$($cell.cell_id).ndjson"
    [void](Assert-R23D53PathAndCas $tracePath (
        [string]$closedCell.trace_sha256
    ) ([long]$closedCell.trace_byte_length))
    Assert-R23D53Closure (
        [string]$terminal.schema_version -ceq
            "sporespore_qsdk_r23d53_engine_cell_report_v1" -and
        [string]$terminal.source_commit -ceq $sourceCommit -and
        [string]$terminal.cell_id -ceq [string]$closedCell.cell_id -and
        [string]$terminal.task_frame_origin_policy_id -ceq
            "warmup_preserving_command_onset_origin_reanchor_v1" -and
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
        [int]$terminal.trace_summary.task_frame_origin_transition_count -eq 3 -and
        (@($terminal.trace_summary.task_frame_origin_transition_steps) -join ',') -ceq
            "600,1800,2400" -and
        -not [bool]$terminal.trace_summary.startup_ramp_triggered -and
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
    Assert-R23D53Near (
        [double]$terminal.measurements.final_forward_displacement_m
    ) ([double]$closedCell.final_forward_displacement_m) (
        "forward displacement changed: $($cell.arm_id)"
    )
    Assert-R23D53Near ([double]$terminal.measurements.maximum_tilt_rad) (
        [double]$closedCell.maximum_tilt_rad
    ) "maximum tilt changed: $($cell.arm_id)"
    Assert-R23D53Near ([double]$terminal.measurements.minimum_torso_height_m) (
        [double]$closedCell.minimum_torso_height_m
    ) "minimum height changed: $($cell.arm_id)"
    Assert-R23D53Near ([double]$terminal.measurements.turn_phase_yaw_delta_rad) (
        [double]$closedCell.turn_phase_yaw_delta_rad
    ) "turn-phase yaw changed: $($cell.arm_id)"
}

$measurement = $evaluation.engine_result.cycle_integrated_measurement
Assert-R23D53Near ([double]$measurement.arms.reference_zero.cycle_shift_rad) `
    -0.09942303053658974 "reference cycle shift changed"
Assert-R23D53Near ([double]$measurement.arms.positive_heading.cycle_shift_rad) `
    0.09393502242850182 "positive cycle shift changed"
Assert-R23D53Near ([double]$measurement.arms.negative_heading.cycle_shift_rad) `
    -0.0532672479719114 "negative cycle shift changed"
Assert-R23D53Near (
    [double]$measurement.positive_reference_conditioned_cycle_shift_rad
) 0.19335805296509156 "conditioned positive shift changed"
Assert-R23D53Near (
    [double]$measurement.negative_reference_conditioned_cycle_shift_rad
) -0.04615578256467834 "conditioned negative shift changed"
Assert-R23D53Near (
    [double]$measurement.bilateral_reference_conditioned_cycle_separation_rad
) 0.14720227040041323 "bilateral separation changed"
Assert-R23D53Closure (
    [bool]$measurement.gates.raw_signed_cycle_shift -and
    -not [bool]$measurement.gates.reference_conditioned_cycle_shift -and
    -not [bool]$measurement.passed -and
    [double]$measurement.arms.negative_heading.cycle_shift_rad -lt 0.0 -and
    [double]$measurement.negative_reference_conditioned_cycle_shift_rad -lt 0.0 -and
    (@($evaluation.engine_result.measurement_failure_codes) -join ',') -ceq
        "reference_conditioned_cycle_shift"
) "turning negative or command-conditioned sign failure changed"

# Rebuild the evaluator namespace from source CAS objects, never today's files.
$tempBase = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\', '/')
$tempRoot = [IO.Path]::GetFullPath((Join-Path $tempBase (
    "sporespore-r23d53-closure-" + [Guid]::NewGuid().ToString("N")
)))
$tempPrefix = $tempBase + [IO.Path]::DirectorySeparatorChar
Assert-R23D53Closure (
    $tempRoot.StartsWith($tempPrefix, [StringComparison]::OrdinalIgnoreCase)
) "temporary evaluator root escaped system temp"
try {
    for ($index = 0; $index -lt @($freeze.source_bindings).Count; $index++) {
        $binding = $freeze.source_bindings[$index]
        $relative = [string]$binding.path
        if ($relative -notmatch '^sdk/') { continue }
        $sourcePayload = [string](
            $freeze.content_addressed_inputs.source_bindings[$index].payload_path
        )
        $destination = Join-Path $tempRoot $relative
        [void][IO.Directory]::CreateDirectory((Split-Path -Parent $destination))
        Copy-Item -LiteralPath $sourcePayload -Destination $destination
    }
    foreach ($relative in @(
        "sdk/turning/r23d31_cycle_integrated_directional_response_closure_v1.json",
        "sdk/turning/r23d32_finite_rapier_turning_replication_closure_v1.json"
    )) {
        $destination = Join-Path $tempRoot $relative
        [void][IO.Directory]::CreateDirectory((Split-Path -Parent $destination))
        [IO.File]::WriteAllBytes(
            $destination,
            (Get-R23D53GitBlobBytes $sourceCommit $relative)
        )
    }
    $evaluatorPath = Join-Path $tempRoot (
        "sdk\turning\r23d53_godot_warmup_preserving_origin_reanchor_evaluator.py"
    )
    $evaluatorOutput = @(& $Python $evaluatorPath evaluate-complete `
        --manifest (Join-Path $attemptRoot "terminal-paths.json") `
        --expected-source-commit $sourceCommit --repo-root $repoRoot 2>&1)
    Assert-R23D53Closure ($LASTEXITCODE -eq 0) ($evaluatorOutput -join "`n")
    $marker = "QSDK_R23D53_COMPLETE_EVALUATION "
    $lines = @($evaluatorOutput | Where-Object { $_.StartsWith($marker) })
    Assert-R23D53Closure ($lines.Count -eq 1) "pinned evaluator marker changed"
    $recomputed = $lines[0].Substring($marker.Length) |
        ConvertFrom-Json -Depth 100
    Assert-R23D53Closure (
        [string]$recomputed.classification -ceq $classification -and
        [bool]$recomputed.engine_result.all_cells_execution_valid -and
        [bool]$recomputed.engine_result.all_common_physical_gates_passed -and
        -not [bool]$recomputed.engine_result.mechanism_selected -and
        [bool]$recomputed.engine_result.cycle_integrated_measurement.gates.raw_signed_cycle_shift -and
        -not [bool]$recomputed.engine_result.cycle_integrated_measurement.gates.reference_conditioned_cycle_shift -and
        -not [bool]$recomputed.engine_result.cycle_integrated_measurement.passed -and
        @($recomputed.cell_evaluations | Where-Object {
            [bool]$_.execution_valid -and [bool]$_.common_physical_gate_passed
        }).Count -eq 3
    ) "pinned evaluator no longer reconstructs the complete negative"
} finally {
    if (Test-Path -LiteralPath $tempRoot) {
        $resolvedCleanup = [IO.Path]::GetFullPath($tempRoot)
        Assert-R23D53Closure (
            $resolvedCleanup.StartsWith(
                $tempPrefix,
                [StringComparison]::OrdinalIgnoreCase
            )
        ) "temporary cleanup target escaped system temp"
        Remove-Item -LiteralPath $resolvedCleanup -Recurse -Force
    }
}

Assert-R23D53Closure (
    [bool]$closure.official_result.all_cells_walked_upright_with_zero_torso_contacts -and
    [bool]$closure.official_result.all_task_frame_origin_transitions_exact -and
    -not [bool]$closure.official_result.turning_measurement_passed -and
    [bool]$closure.official_result.raw_signed_cycle_shift_gate_passed -and
    -not [bool]$closure.official_result.reference_conditioned_cycle_shift_gate_passed -and
    [bool]$closure.official_result.negative_raw_sign_correct_but_reference_conditioned_direction_wrong -and
    [bool]$closure.official_result.negative_reference_conditioned_fails_direction_at_zero_floor -and
    -not [bool]$closure.official_result.warmup_preserving_origin_reanchor_mechanism_selected -and
    [bool]$closure.scientific_interpretation.threshold_only_successor_not_supported_by_this_result -and
    [bool]$closure.scientific_interpretation.successor_work_paused_pending_process_changes -and
    [bool]$closure.claims.r23d53_checkout_provenance_repair_observed_successfully -and
    [bool]$closure.claims.finite_outcome_exposed_godot_jolt_three_world_common_walking -and
    [bool]$closure.claims.finite_outcome_exposed_raw_signed_cycle_response -and
    -not [bool]$closure.claims.warmup_preserving_origin_reanchor_mechanism_selected_for_held_out_validation -and
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

function Find-R23D53ClosedRecord($Value) {
    if ($null -eq $Value) { return $null }
    if ($Value -is [Collections.IDictionary]) {
        if ($Value.Contains("closed_r23d53_attempt")) {
            return $Value["closed_r23d53_attempt"]
        }
        foreach ($child in $Value.Values) {
            $found = Find-R23D53ClosedRecord $child
            if ($null -ne $found) { return $found }
        }
        return $null
    }
    if ($Value -is [Management.Automation.PSCustomObject]) {
        $property = $Value.PSObject.Properties["closed_r23d53_attempt"]
        if ($null -ne $property) { return $property.Value }
        foreach ($child in $Value.PSObject.Properties.Value) {
            $found = Find-R23D53ClosedRecord $child
            if ($null -ne $found) { return $found }
        }
        return $null
    }
    if ($Value -is [Collections.IEnumerable] -and $Value -isnot [string]) {
        foreach ($child in $Value) {
            $found = Find-R23D53ClosedRecord $child
            if ($null -ne $found) { return $found }
        }
    }
    return $null
}

$releaseContract = Get-Content -Raw -LiteralPath (
    Join-Path $repoRoot "sdk\release\quadruped_release_contract.json"
) | ConvertFrom-Json -Depth 100
$supportMatrix = Get-Content -Raw -LiteralPath (
    Join-Path $repoRoot "sdk\release\quadruped_support_matrix.json"
) | ConvertFrom-Json -Depth 100
$turningGate = @($releaseContract.gates | Where-Object {
    [string]$_.gate_id -ceq "QSDK-R23"
})
$contractRecord = if ($turningGate.Count -eq 1) {
    $turningGate[0].proof.closed_r23d53_attempt
} else { $null }
$matrixRecord = Find-R23D53ClosedRecord $supportMatrix
$closureHash = Get-R23D53Sha256 $closurePath
Assert-R23D53Closure (
    $turningGate.Count -eq 1 -and
    $null -ne $contractRecord -and $null -ne $matrixRecord -and
    [string]$turningGate[0].proof.kind -ceq "missing" -and
    [string]$contractRecord.status -ceq [string]$closure.status -and
    [string]$matrixRecord.status -ceq [string]$closure.status -and
    [string]$contractRecord.closure_path -ceq
        "sdk/turning/r23d53_godot_warmup_preserving_origin_reanchor_closure_v1.json" -and
    [string]$matrixRecord.closure_path -ceq
        [string]$contractRecord.closure_path -and
    [string]$contractRecord.closure_raw_sha256 -ceq $closureHash -and
    [string]$matrixRecord.closure_sha256 -ceq $closureHash -and
    [string]$contractRecord.physical_source_commit -ceq $sourceCommit -and
    [string]$matrixRecord.physical_source_commit -ceq $sourceCommit -and
    [string]$contractRecord.attempt_id -ceq [string]$closure.attempt_id -and
    [string]$matrixRecord.attempt_id -ceq [string]$closure.attempt_id -and
    [int]$contractRecord.observed_world_build_count -eq 3 -and
    [int]$matrixRecord.observed_world_build_count -eq 3 -and
    [int]$contractRecord.common_walking_gate_pass_cell_count -eq 3 -and
    [int]$matrixRecord.common_walking_gate_pass_cell_count -eq 3 -and
    [bool]$contractRecord.raw_signed_cycle_shift_gate_passed -and
    [bool]$matrixRecord.raw_signed_cycle_shift_gate_passed -and
    -not [bool]$contractRecord.reference_conditioned_cycle_shift_gate_passed -and
    -not [bool]$matrixRecord.reference_conditioned_cycle_shift_gate_passed -and
    -not [bool]$contractRecord.threshold_only_successor_supported -and
    -not [bool]$matrixRecord.threshold_only_successor_supported -and
    -not [bool]$contractRecord.warmup_preserving_origin_reanchor_mechanism_selected_for_held_out_validation -and
    -not [bool]$matrixRecord.warmup_preserving_origin_reanchor_mechanism_selected_for_held_out_validation -and
    -not [bool]$contractRecord.successor_campaign_opened -and
    -not [bool]$matrixRecord.successor_campaign_opened -and
    [bool]$contractRecord.physical_series_paused_before_successor -and
    [bool]$matrixRecord.physical_series_paused_before_successor -and
    -not [bool]$contractRecord.fresh_godot_jolt_turning -and
    -not [bool]$matrixRecord.fresh_godot_jolt_turning -and
    -not [bool]$contractRecord.finite_three_engine_turning -and
    -not [bool]$matrixRecord.finite_three_engine_turning -and
    -not [bool]$contractRecord.q_sdk_r23_satisfied -and
    -not [bool]$matrixRecord.q_sdk_r23_satisfied -and
    -not [bool]$contractRecord.prone_to_standing -and
    -not [bool]$matrixRecord.prone_to_standing -and
    -not [bool]$contractRecord.release_authorized -and
    -not [bool]$matrixRecord.release_authorized
) "release contract or support matrix closure boundary changed"

$completedAttempts = @(
    Get-ChildItem -LiteralPath $evidenceRoot -Directory |
        Where-Object {
            $_.Name -like "qsdk-r23d53-20*" -and
            (Test-Path -LiteralPath (Join-Path $_.FullName "completion.json"))
        }
)
Assert-R23D53Closure (
    $completedAttempts.Count -eq 1 -and
    $completedAttempts[0].FullName -ceq $attemptRoot
) "R23D53 one-shot attempt count changed"

Write-Host (
    "QSDK_R23D53_CLOSURE_PASS classification=negative_exposed_development " +
    "worlds=3 exits=3 walking=3 raw_turning=True conditioned_turning=False " +
    "selected=False fresh=False three_engine=False rerun=False"
)
