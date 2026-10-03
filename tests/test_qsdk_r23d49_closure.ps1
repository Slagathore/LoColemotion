#requires -Version 7.0

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$evidenceRoot = "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence"
$artifactRoot = Join-Path $evidenceRoot "artifacts\sha256"
$attemptRoot = Join-Path $evidenceRoot "qsdk-r23d49-20260813T143652Z"
$closurePath = Join-Path $repoRoot (
    "sdk\turning\r23d49_rapier_retention_repair_replay_closure_v1.json"
)
$diagnosticSourcePath = Join-Path $repoRoot (
    "sdk\turning\r23d49_postfailure_path_identity_diagnostic.py"
)
$sourceCommit = "5f79f244e517dd7d2cd55164d1db92cd5eb9d638"
$officialClassification = (
    "invalid_or_incomplete_outcome_exposed_rapier_retention_repair_replay"
)
$tolerance = 1.0e-12

function Assert-R23D49Closure([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "QSDK-R23D49 CLOSURE: $Message" }
}

function Assert-Near([double]$Actual, [double]$Expected, [string]$Message) {
    Assert-R23D49Closure (
        [double]::IsFinite($Actual) -and
        [Math]::Abs($Actual - $Expected) -le $tolerance
    ) $Message
}

function Get-Sha256([string]$Path) {
    return "sha256:" + (
        Get-FileHash -LiteralPath $Path -Algorithm SHA256
    ).Hash.ToLowerInvariant()
}

function Get-BytesSha256([byte[]]$Bytes) {
    return "sha256:" + [Convert]::ToHexString(
        [Security.Cryptography.SHA256]::HashData($Bytes)
    ).ToLowerInvariant()
}

function Get-GitBlobBytes([string]$Commit, [string]$RelativePath) {
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
    Assert-R23D49Closure ($process.Start()) "could not start git cat-file"
    $memory = [IO.MemoryStream]::new()
    try {
        $process.StandardOutput.BaseStream.CopyTo($memory)
        $stderr = $process.StandardError.ReadToEnd()
        $process.WaitForExit()
        Assert-R23D49Closure ($process.ExitCode -eq 0) (
            "historical blob unavailable: $RelativePath; $stderr"
        )
        return ,([byte[]]$memory.ToArray())
    } finally {
        $memory.Dispose()
        $process.Dispose()
    }
}

function Assert-Cas([string]$Sha256, [long]$ByteLength) {
    Assert-R23D49Closure ($Sha256 -cmatch '^sha256:[0-9a-f]{64}$') (
        "invalid CAS digest: $Sha256"
    )
    $directory = Join-Path $artifactRoot $Sha256.Substring(7)
    $payload = Join-Path $directory "payload.bin"
    $manifestPath = Join-Path $directory "manifest.json"
    Assert-R23D49Closure (
        (Test-Path -LiteralPath $payload -PathType Leaf) -and
        (Test-Path -LiteralPath $manifestPath -PathType Leaf) -and
        (Get-Item -LiteralPath $payload).Length -eq $ByteLength -and
        (Get-Sha256 $payload) -ceq $Sha256
    ) "CAS payload changed: $Sha256"
    $manifest = Get-Content -Raw -LiteralPath $manifestPath |
        ConvertFrom-Json -Depth 20
    Assert-R23D49Closure (
        [string]$manifest.schema_version -ceq
            "sporespore_content_addressed_artifact_manifest_v1" -and
        [string]$manifest.algorithm -ceq "sha256" -and
        [string]$manifest.sha256 -ceq $Sha256 -and
        [long]$manifest.byte_length -eq $ByteLength -and
        [string]$manifest.payload_name -ceq "payload.bin"
    ) "CAS manifest changed: $Sha256"
    return $payload
}

function Assert-PathAndCas(
    [string]$Path,
    [string]$Sha256,
    [long]$ByteLength
) {
    Assert-R23D49Closure (
        (Test-Path -LiteralPath $Path -PathType Leaf) -and
        (Get-Item -LiteralPath $Path).Length -eq $ByteLength -and
        (Get-Sha256 $Path) -ceq $Sha256
    ) "retained artifact changed: $Path"
    $payload = Assert-Cas $Sha256 $ByteLength
    Assert-R23D49Closure ((Get-Sha256 $payload) -ceq (Get-Sha256 $Path)) (
        "retained artifact and CAS differ: $Path"
    )
    return $payload
}

Assert-R23D49Closure (
    (git -C $repoRoot rev-parse --show-toplevel).Trim().Replace('/', '\') -ceq
        $repoRoot -and
    (git -C $repoRoot remote get-url origin).Trim() -ceq
        "https://github.com/Slagathore/sporespore.git"
) "repository identity changed"

$closure = Get-Content -Raw -LiteralPath $closurePath |
    ConvertFrom-Json -Depth 100
Assert-R23D49Closure (
    [string]$closure.schema_version -ceq
        "sporespore_qsdk_r23d49_rapier_retention_repair_replay_closure_v1" -and
    [string]$closure.status -ceq
        "closed_consumed_invalid_complete_evaluator_windows_namespace_path_identity_false_negative_with_successful_production_trace_retention" -and
    [string]$closure.source_commit -ceq $sourceCommit -and
    (git -C $repoRoot rev-parse "$sourceCommit`^{tree}").Trim() -ceq
        [string]$closure.source_tree_git_oid -and
    [string]$closure.attempt_id -ceq "6a96746105324921bdbcdc8c8e8bd3fd" -and
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
    $bytes = Get-GitBlobBytes $sourceCommit $relative
    Assert-R23D49Closure (
        $bytes.Length -eq [long]$input.byte_length -and
        (Get-BytesSha256 $bytes) -ceq [string]$input.raw_sha256 -and
        (git -C $repoRoot rev-parse "$sourceCommit`:$relative").Trim() -ceq
            [string]$input.git_blob_oid
    ) "prospective source identity changed: $relative"
}

$attestationPayload = Assert-PathAndCas (
    [string]$closure.qualification.attestation_path
) ([string]$closure.qualification.attestation_sha256) (
    [long]$closure.qualification.attestation_byte_length
)
$adoptionPayload = Assert-PathAndCas (
    [string]$closure.qualification.adoption_path
) ([string]$closure.qualification.adoption_sha256) (
    [long]$closure.qualification.adoption_byte_length
)
$attestation = Get-Content -Raw -LiteralPath $attestationPayload |
    ConvertFrom-Json -Depth 100
$adoption = Get-Content -Raw -LiteralPath $adoptionPayload |
    ConvertFrom-Json -Depth 100
Assert-R23D49Closure (
    [string]$attestation.source.commit -ceq $sourceCommit -and
    [int]$attestation.global_gate_count -eq 12 -and
    [int]$attestation.lineage_gate_count -eq 2 -and
    [int]$attestation.campaign_gate_count -eq 3 -and
    @($attestation.gate_receipts).Count -eq 17 -and
    @($attestation.gate_receipts | Where-Object {
        [int]$_.physical_world_count -ne 0 -or
        [int]$_.physical_process_launch_count -ne 0
    }).Count -eq 0 -and
    [string]$adoption.source_commit -ceq $sourceCommit -and
    [bool]$adoption.physical_launch_prerequisite_satisfied -and
    -not [bool]$adoption.physical_acceptance_authority
) "qualification identity changed"

$rootArtifacts = [ordered]@{
    "physical-freeze.json" = $closure.physical_evidence.physical_freeze
    "attempt.json" = $closure.physical_evidence.attempt_authorization
    "authorization-preflights.json" =
        $closure.physical_evidence.production_authorization_preflights
    "terminal-paths.json" = $closure.physical_evidence.terminal_manifest
    "report.json" = $closure.physical_evidence.report
    "completion.json" = $closure.physical_evidence.completion
}
$rootPayloads = @{}
foreach ($entry in $rootArtifacts.GetEnumerator()) {
    $rootPayloads[$entry.Key] = Assert-PathAndCas (
        (Join-Path $attemptRoot $entry.Key)
    ) ([string]$entry.Value.sha256) ([long]$entry.Value.byte_length)
}

$freeze = Get-Content -Raw -LiteralPath $rootPayloads["physical-freeze.json"] |
    ConvertFrom-Json -Depth 100
$attempt = Get-Content -Raw -LiteralPath $rootPayloads["attempt.json"] |
    ConvertFrom-Json -Depth 100
$authorization = @(Get-Content -Raw -LiteralPath (
    $rootPayloads["authorization-preflights.json"]
) | ConvertFrom-Json -Depth 100)
$terminalPaths = @(Get-Content -Raw -LiteralPath (
    $rootPayloads["terminal-paths.json"]
) | ConvertFrom-Json)
$report = Get-Content -Raw -LiteralPath $rootPayloads["report.json"] |
    ConvertFrom-Json -Depth 100
$completion = Get-Content -Raw -LiteralPath $rootPayloads["completion.json"] |
    ConvertFrom-Json -Depth 100
$evaluation = $report.complete_evaluation

Assert-R23D49Closure (
    [string]$freeze.source_commit -ceq $sourceCommit -and
    @($freeze.source_bindings).Count -eq 227 -and
    [bool]$freeze.source_bytes_consumed_by_build_equal_git_blobs -and
    [int]$freeze.declared_matrix_world_count -eq 3 -and
    [bool]$freeze.production_retention_preflight.
        exact_rust_to_python_to_powershell_to_artifact_store_route_exercised -and
    [bool]$freeze.production_retention_preflight.
        process_scoped_execution_policy_bypass_exercised -and
    [int]$freeze.production_retention_preflight.world_attempt_count -eq 0 -and
    [int]$freeze.production_retention_preflight.world_build_count -eq 0 -and
    [string]$attempt.attempt_id -ceq [string]$closure.attempt_id -and
    [bool]$attempt.production_retention_preflight_passed -and
    [bool]$attempt.one_shot_attempt_unconsumed -and
    $authorization.Count -eq 3 -and
    @($authorization | Where-Object {
        [bool]$_.authorization_passed -and
        [bool]$_.returned_before_model -and
        [int]$_.physical_process_launch_count -eq 0 -and
        [int]$_.world_build_count -eq 0
    }).Count -eq 3 -and
    $terminalPaths.Count -eq 3
) "freeze, canary, attempt, or authorization changed"

Assert-R23D49Closure (
    [string]$report.result_classification -ceq $officialClassification -and
    [string]$evaluation.classification -ceq $officialClassification -and
    [int]$evaluation.cell_count -eq 3 -and
    -not [bool]$evaluation.all_cells_execution_valid -and
    $null -eq $evaluation.cycle_integrated_measurement -and
    @($evaluation.cell_evaluations | Where-Object {
        [string]$_.entry_kind -ceq "report" -and
        -not [bool]$_.execution_valid -and
        -not [bool]$_.common_physical_gate_passed -and
        (@($_.failed_gate_ids) -join "|") -ceq
            "R23D48_TRACE_ARTIFACT_CAS_PATH" -and
        [int]$_.world_attempt_count -eq 1 -and
        [int]$_.world_build_count -eq 1
    }).Count -eq 3 -and
    [string]$completion.result_classification -ceq $officialClassification -and
    [bool]$completion.one_shot_identity_consumed -and
    -not [bool]$completion.same_identity_rerun_allowed -and
    -not [bool]$completion.finite_three_engine_turning_candidate -and
    -not [bool]$completion.physical_acceptance_authority
) "official invalid disposition changed"

$traceDigests = @(
    "sha256:b1ecee57b2a045166a7d392c1c0f9b74fa0bbabae82741b3444ab41c9b864487",
    "sha256:62ec78cf8611a8f8d6d18a7751ef1f2cc1776167b784ca85ced9f41c472ce7ff",
    "sha256:ef78b64ce2745fea56ee22fc342889324b9901ff94666ebe2f610023115c8e54"
)
for ($index = 0; $index -lt 3; $index++) {
    $cell = $report.ordered_matrix_cells[$index]
    Assert-R23D49Closure (
        [int]$cell.process_exit_code -eq 0 -and
        [string]$terminalPaths[$index] -ceq
            [string]$cell.terminal_entry_cas.payload_path
    ) "process or terminal order changed: $index"
    $terminalPayload = Assert-Cas (
        [string]$cell.terminal_entry_cas.sha256
    ) ([long]$cell.terminal_entry_cas.byte_length)
    $terminal = Get-Content -Raw -LiteralPath $terminalPayload |
        ConvertFrom-Json -Depth 100
    $trace = $terminal.trace_artifact
    $expectedTracePayload = Assert-Cas (
        [string]$trace.sha256
    ) ([long]$trace.byte_length)
    Assert-R23D49Closure (
        [string]$trace.sha256 -ceq $traceDigests[$index] -and
        [string]$trace.payload_path -cne $expectedTracePayload -and
        [string]$trace.payload_path -like '\\?\C:\*' -and
        (Get-Sha256 ([string]$trace.payload_path)) -ceq
            (Get-Sha256 $expectedTracePayload) -and
        [string]$terminal.schema_version -ceq
            "sporespore_qsdk_r23d49_engine_cell_report_v1" -and
        [string]$terminal.source_commit -ceq $sourceCommit -and
        [bool]$terminal.execution.integrity_passed -and
        [bool]$terminal.execution.trace_retained_before_terminal_entry -and
        [int]$terminal.execution.world_attempt_count -eq 1 -and
        [int]$terminal.execution.world_build_count -eq 1 -and
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
    ) "retained live terminal changed: $($cell.cell_id)"
}

$diagnostic = $closure.post_failure_path_identity_diagnostic
Assert-R23D49Closure (
    (Get-Sha256 $diagnosticSourcePath) -ceq
        [string]$diagnostic.diagnostic_source.raw_sha256 -and
    (Get-Item -LiteralPath $diagnosticSourcePath).Length -eq
        [long]$diagnostic.diagnostic_source.byte_length
) "diagnostic source changed"
$diagnosticPayload = Assert-PathAndCas (
    (Join-Path $attemptRoot "postfailure-path-identity-diagnostic.json")
) ([string]$diagnostic.diagnostic_artifact.sha256) (
    [long]$diagnostic.diagnostic_artifact.byte_length
)
$diagnosticReceiptPayload = Assert-PathAndCas (
    (Join-Path $attemptRoot "postfailure-path-identity-diagnostic-cas.json")
) ([string]$diagnostic.diagnostic_receipt.sha256) (
    [long]$diagnostic.diagnostic_receipt.byte_length
)
$diagnosticReport = Get-Content -Raw -LiteralPath $diagnosticPayload |
    ConvertFrom-Json -Depth 100
$diagnosticReceipt = Get-Content -Raw -LiteralPath $diagnosticReceiptPayload |
    ConvertFrom-Json -Depth 100
$recomputed = $diagnosticReport.diagnostic_recomputed_evaluation

Assert-R23D49Closure (
    [string]$diagnosticReport.authority -ceq "post_failure_diagnostic_only" -and
    [string]$diagnosticReport.official_classification -ceq
        $officialClassification -and
    [bool]$diagnosticReport.official_r23d49_classification_unchanged -and
    -not [bool]$diagnosticReport.official_result_reclassified -and
    -not [bool]$diagnosticReport.may_be_promoted_to_official_result -and
    -not [bool]$diagnosticReport.creates_turning_claim -and
    -not [bool]$diagnosticReport.all_recorded_paths_textually_equal_to_expected -and
    [bool]$diagnosticReport.all_recorded_paths_identify_expected_files -and
    @($diagnosticReport.file_identity_observations | Where-Object {
        -not [bool]$_.payload_path_text_equal -and
        [bool]$_.payload_same_existing_file -and
        -not [bool]$_.manifest_path_text_equal -and
        [bool]$_.manifest_same_existing_file
    }).Count -eq 3 -and
    [string]$recomputed.classification -ceq
        "valid_complete_positive_outcome_exposed_rapier_retention_repair_replay" -and
    [bool]$recomputed.all_cells_execution_valid -and
    [bool]$recomputed.all_common_physical_gates_passed -and
    [bool]$recomputed.turning_measurement_passed -and
    @($recomputed.cell_evaluations | Where-Object {
        [bool]$_.execution_valid -and
        [bool]$_.common_physical_gate_passed -and
        @($_.failed_gate_ids).Count -eq 0
    }).Count -eq 3 -and
    [string]$diagnosticReceipt.diagnostic_artifact.sha256 -ceq
        [string]$diagnostic.diagnostic_artifact.sha256 -and
    -not [bool]$diagnosticReceipt.may_be_promoted_to_official_result
) "diagnostic authority or corrected file-identity result changed"

$measurement = $recomputed.cycle_integrated_measurement
Assert-Near ([double]$measurement.arms.reference_zero.cycle_shift_rad) `
    0.0025661495546947487 "diagnostic reference shift changed"
Assert-Near ([double]$measurement.arms.positive_heading.cycle_shift_rad) `
    0.016544441316987724 "diagnostic positive shift changed"
Assert-Near ([double]$measurement.arms.negative_heading.cycle_shift_rad) `
    -0.014735136859300405 "diagnostic negative shift changed"
Assert-Near ([double]$measurement.positive_reference_conditioned_cycle_shift_rad) `
    0.013978291762292976 "diagnostic conditioned positive changed"
Assert-Near ([double]$measurement.negative_reference_conditioned_cycle_shift_rad) `
    0.017301286413995153 "diagnostic conditioned negative changed"
Assert-R23D49Closure (
    [bool]$measurement.gates.raw_signed_cycle_shift -and
    [bool]$measurement.gates.reference_conditioned_cycle_shift -and
    [bool]$measurement.passed
) "diagnostic turning measurement changed"

# Independently recompute the diagnostic from the retained terminals without
# writing a new artifact, then require byte-identical canonical JSON.
$pythonCode = @'
import hashlib
import json
import pathlib
import sys
repo = pathlib.Path(sys.argv[1])
sys.path.insert(0, str(repo / "sdk" / "turning"))
import r23d49_postfailure_path_identity_diagnostic as diagnostic
result = diagnostic.diagnose(
    terminal_paths_path=pathlib.Path(sys.argv[2]),
    official_report_path=pathlib.Path(sys.argv[3]),
    expected_source_commit=sys.argv[4],
    authority_repo_root=repo,
)
encoded = (json.dumps(result, sort_keys=True, separators=(",", ":")) + "\n").encode("utf-8")
print("sha256:" + hashlib.sha256(encoded).hexdigest())
print(len(encoded))
'@
$diagnosticRebuild = @(& python -c $pythonCode $repoRoot (
    Join-Path $attemptRoot "terminal-paths.json"
) (Join-Path $attemptRoot "report.json") $sourceCommit)
Assert-R23D49Closure (
    $LASTEXITCODE -eq 0 -and
    $diagnosticRebuild.Count -eq 2 -and
    [string]$diagnosticRebuild[0] -ceq
        [string]$diagnostic.diagnostic_artifact.sha256 -and
    [long]$diagnosticRebuild[1] -eq
        [long]$diagnostic.diagnostic_artifact.byte_length
) "diagnostic does not rebuild from retained evidence"

Assert-R23D49Closure (
    [string]$closure.diagnosis.defect_class -ceq
        "complete_evaluator_windows_extended_namespace_path_text_false_negative" -and
    [bool]$closure.diagnosis.recorded_and_expected_paths_referred_to_the_same_existing_files -and
    -not [bool]$closure.diagnosis.trace_bytes_or_manifests_caused_invalidity -and
    -not [bool]$closure.diagnosis.rapier_physics_or_controller_caused_execution_invalidity -and
    -not [bool]$closure.diagnosis.r48_powershell_authorization_manager_failure_repeated -and
    [bool]$closure.diagnosis.process_scoped_bypass_route_published_canary_and_all_live_traces -and
    [bool]$closure.diagnosis.prior_samefile_verifier_existed_in_r23d44_but_was_not_inherited_by_r23d49 -and
    [bool]$closure.claims.r23d49_process_scoped_bypass_publication_route_observed_successfully -and
    -not [bool]$closure.claims.finite_outcome_exposed_rapier_retention_repair_replay -and
    -not [bool]$closure.claims.rapier_seed_21512_finite_turning_from_r23d49 -and
    -not [bool]$closure.claims.portable_basic_turning -and
    -not [bool]$closure.claims.finite_three_engine_turning -and
    -not [bool]$closure.claims.q_sdk_r23_satisfied -and
    -not [bool]$closure.claims.cross_engine_equivalence -and
    -not [bool]$closure.claims.release_authorized -and
    -not [bool]$closure.claims.physical_acceptance_authority
) "diagnosis or claim boundary changed"

$attemptDirectories = @(
    Get-ChildItem -LiteralPath $evidenceRoot -Directory |
        Where-Object {
            $_.Name -like "qsdk-r23d49-*" -and
            (Test-Path -LiteralPath (Join-Path $_.FullName "completion.json"))
        }
)
Assert-R23D49Closure (
    $attemptDirectories.Count -eq 1 -and
    $attemptDirectories[0].FullName -ceq $attemptRoot
) "R23D49 one-shot attempt count changed"

Write-Host (
    "QSDK_R23D49_CLOSURE_PASS official=invalid_complete worlds=3 exits=3 " +
    "traces=3 path_false_negatives=3 diagnostic_walking=True " +
    "diagnostic_turning=True official_rapier_claim=False rerun=False"
)
