#requires -Version 7.0

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$evidenceRoot = "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence"
$artifactRoot = Join-Path $evidenceRoot "artifacts\sha256"
$attemptRoot = Join-Path $evidenceRoot "qsdk-r23d44-physical-a3e76a1"
$closurePath = Join-Path $repoRoot (
    "sdk\turning\r23d44_rapier_paired_startup_transform_closure_v1.json"
)
$sourceCommit = "a3e76a1bebb5a1a6bc57b024b4de78946c92e07a"
$tolerance = 1.0e-12
$twoPi = 2.0 * [Math]::PI

function Assert-R23D44([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "QSDK-R23D44 CLOSURE: $Message" }
}

function Assert-Near(
    [double]$Actual,
    [double]$Expected,
    [string]$Message
) {
    Assert-R23D44 (
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
    Assert-R23D44 ($process.Start()) "failed to start git cat-file"
    $memory = [IO.MemoryStream]::new()
    try {
        $process.StandardOutput.BaseStream.CopyTo($memory)
        $stderr = $process.StandardError.ReadToEnd()
        $process.WaitForExit()
        Assert-R23D44 ($process.ExitCode -eq 0) (
            "historical blob unavailable: $RelativePath; $stderr"
        )
        return ,([byte[]]$memory.ToArray())
    } finally {
        $memory.Dispose()
        $process.Dispose()
    }
}

function Assert-Cas([string]$Sha256, [long]$ByteLength) {
    Assert-R23D44 ($Sha256 -cmatch '^sha256:[0-9a-f]{64}$') (
        "invalid CAS digest: $Sha256"
    )
    $directory = Join-Path $artifactRoot $Sha256.Substring(7)
    $payload = Join-Path $directory "payload.bin"
    $manifestPath = Join-Path $directory "manifest.json"
    Assert-R23D44 (
        (Test-Path -LiteralPath $payload -PathType Leaf) -and
        (Test-Path -LiteralPath $manifestPath -PathType Leaf) -and
        (Get-Item -LiteralPath $payload).Length -eq $ByteLength -and
        (Get-Sha256 $payload) -ceq $Sha256
    ) "CAS payload changed: $Sha256"
    $manifest = Get-Content -Raw -LiteralPath $manifestPath |
        ConvertFrom-Json -Depth 20
    Assert-R23D44 (
        [string]$manifest.schema_version -ceq
            "sporespore_content_addressed_artifact_manifest_v1" -and
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
    Assert-R23D44 (
        (Test-Path -LiteralPath $Path -PathType Leaf) -and
        (Get-Item -LiteralPath $Path).Length -eq $ByteLength -and
        (Get-Sha256 $Path) -ceq $Sha256
    ) "retained artifact changed: $Path"
    $payload = Assert-Cas $Sha256 $ByteLength
    Assert-R23D44 ((Get-Sha256 $payload) -ceq (Get-Sha256 $Path)) (
        "retained artifact and CAS differ: $Path"
    )
    return $payload
}

function Get-WindowMean($Values, [int]$Start, [int]$End) {
    $sum = 0.0
    for ($index = $Start; $index -lt $End; $index++) {
        $sum += [double]$Values[$index]
    }
    return $sum / [double]($End - $Start)
}

function Measure-R23D44Trace(
    [string]$Payload,
    [string]$CellId,
    [string]$CandidateId,
    [double]$TurnOffset,
    [bool]$RampEnabled
) {
    $rows = @(Get-Content -LiteralPath $Payload | ForEach-Object {
        $_ | ConvertFrom-Json -Depth 30
    })
    Assert-R23D44 ($rows.Count -eq 2992) "trace row count changed: $CellId"
    $unwrapped = [Collections.Generic.List[double]]::new()
    $previousRaw = 0.0
    $previousUnwrapped = 0.0
    $activeCount = 0
    $zeroCount = 0
    $unityCount = 0
    for ($index = 0; $index -lt $rows.Count; $index++) {
        $row = $rows[$index]
        $segment = if ($index -lt 600) { "reference_warmup" } elseif (
            $index -lt 1800
        ) { "commanded_turn" } elseif ($index -lt 2400) {
            "reference_recovery"
        } else { "after_declared_schedule" }
        $expectedOffset = if ($segment -ceq "commanded_turn") {
            $TurnOffset
        } else { 0.0 }
        $expectedRampId = if ($RampEnabled) {
            "canonical_velocity_smoothstep_one_gait_cycle_v1"
        } else { "none" }
        $yaw = [double]$row.measured_yaw_rad
        $scale = [double]$row.startup_velocity_scale
        if ([bool]$row.startup_ramp_active) { $activeCount++ }
        if ($scale -eq 0.0) { $zeroCount++ }
        if ($scale -eq 1.0) { $unityCount++ }
        Assert-R23D44 (
            [string]$row.schema_version -ceq
                "sporespore_qsdk_r23d44_turning_trace_row_v1" -and
            [string]$row.cell_id -ceq $CellId -and
            [int]$row.semantic_step -eq $index -and
            [int]$row.trace_step -eq $index -and
            [string]$row.segment_id -ceq $segment -and
            [double]$row.desired_heading_offset_rad -eq $expectedOffset -and
            [int]$row.validated_portable_command_count -eq 8 -and
            [int]$row.native_actuation_application_count -eq 8 -and
            [string]$row.startup_ramp_id -ceq $expectedRampId -and
            [bool]$row.oracle_passed -and
            [double]::IsFinite($scale) -and
            [double]::IsFinite($yaw)
        ) "trace row changed: $CellId/$index"
        if ($index -eq 0) {
            $previousRaw = $yaw
            $previousUnwrapped = $yaw
            $unwrapped.Add($yaw)
            continue
        }
        $delta = [Math]::IEEERemainder($yaw - $previousRaw, $twoPi)
        Assert-R23D44 (
            [double]::IsFinite($delta) -and
            [Math]::Abs([Math]::Abs($delta) - [Math]::PI) -gt $tolerance
        ) "ambiguous yaw unwrap: $CellId/$index"
        $previousUnwrapped += $delta
        $previousRaw = $yaw
        $unwrapped.Add($previousUnwrapped)
    }
    $expectedActive = if ($RampEnabled) { 359 } else { 0 }
    $expectedZero = if ($RampEnabled) { 1 } else { 0 }
    $expectedUnity = if ($RampEnabled) { 2633 } else { 2992 }
    Assert-R23D44 (
        $activeCount -eq $expectedActive -and
        $zeroCount -eq $expectedZero -and
        $unityCount -eq $expectedUnity
    ) "startup transform counts changed: $CandidateId/$CellId"
    return (Get-WindowMean $unwrapped 1440 1800) -
        (Get-WindowMean $unwrapped 240 600)
}

$closure = Get-Content -Raw -LiteralPath $closurePath |
    ConvertFrom-Json -Depth 100
Assert-R23D44 (
    (git -C $repoRoot rev-parse --show-toplevel).Trim().Replace('/', '\') -ceq
        $repoRoot -and
    (git -C $repoRoot remote get-url origin).Trim() -ceq
        "https://github.com/Slagathore/sporespore.git" -and
    [string]$closure.schema_version -ceq
        "sporespore_qsdk_r23d44_rapier_paired_startup_transform_closure_v1" -and
    [string]$closure.status -ceq
        "closed_consumed_valid_complete_ramp_induced_turning_gate_regression_at_seed_21504" -and
    [string]$closure.source_commit -ceq $sourceCommit -and
    (git -C $repoRoot rev-parse "$sourceCommit`^{tree}").Trim() -ceq
        [string]$closure.source_tree_git_oid -and
    [bool]$closure.identity_consumed -and
    -not [bool]$closure.same_identity_rerun_allowed -and
    -not [bool]$closure.selective_rerun_allowed -and
    [bool]$closure.outcome_exposed_seed_consumed -and
    -not [bool]$closure.fresh_or_held_out_condition_consumed -and
    -not [bool]$closure.successor_campaign_opened -and
    [bool]$closure.physical_series_paused_before_successor
) "closure identity or immutable disposition changed"

foreach ($property in @(
    @{ path = "preregistration_path"; sha = "preregistration_raw_sha256"; oid = "preregistration_git_blob_oid" },
    @{ path = "implementation_path"; sha = "implementation_raw_sha256"; oid = "implementation_git_blob_oid" },
    @{ path = "campaign_attestation_manifest_path"; sha = "campaign_attestation_manifest_raw_sha256"; oid = "campaign_attestation_manifest_git_blob_oid" }
)) {
    $relative = [string]$closure.prospective_inputs.($property.path)
    $bytes = Get-GitBlobBytes $sourceCommit $relative
    $oid = (git -C $repoRoot rev-parse "$sourceCommit`:$relative").Trim()
    Assert-R23D44 (
        (Get-BytesSha256 $bytes) -ceq
            [string]$closure.prospective_inputs.($property.sha) -and
        $oid -ceq [string]$closure.prospective_inputs.($property.oid)
    ) "pinned prospective input changed: $relative"
}

$failedQualification = Get-Content -Raw -LiteralPath (
    [string]$closure.qualification.first_failed_attestation_path
) | ConvertFrom-Json -Depth 30
Assert-R23D44 (
    (Get-Sha256 ([string]$closure.qualification.first_failed_attestation_path)) -ceq
        [string]$closure.qualification.first_failed_attestation_sha256 -and
    (Get-Item -LiteralPath (
        [string]$closure.qualification.first_failed_attestation_path
    )).Length -eq [long]$closure.qualification.first_failed_attestation_byte_length -and
    [string]$failedQualification.source_commit -ceq
        "256622b189e31397e028951f0f7b35c991c66f6d" -and
    [string]$failedQualification.message -like "*CAK1-EVIDENCE-PROVENANCE*" -and
    -not [bool]$failedQualification.campaign_local_qualification_passed -and
    -not [bool]$failedQualification.physical_launch_prerequisite_satisfied -and
    [int]$closure.qualification.first_failure_world_count -eq 0 -and
    -not [bool]$closure.qualification.first_failure_consumed_physical_identity -and
    -not [bool]$closure.qualification.science_changed_by_repair
) "first qualification failure changed"

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
Assert-R23D44 (
    [string]$attestation.source.commit -ceq $sourceCommit -and
    [int]$attestation.global_gate_count -eq 12 -and
    [int]$attestation.lineage_gate_count -eq 2 -and
    [int]$attestation.campaign_gate_count -eq 3 -and
    @($attestation.gate_receipts).Count -eq 17 -and
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
$canary = $freeze.production_retention_preflight
foreach ($trace in @(
    $closure.production_retention_canary.no_ramp_trace,
    $closure.production_retention_canary.ramp_trace
)) { [void](Assert-Cas ([string]$trace.sha256) ([long]$trace.byte_length)) }
Assert-R23D44 (
    [string]$freeze.source_commit -ceq $sourceCommit -and
    [string]$freeze.source_tree_git_oid -ceq [string]$closure.source_tree_git_oid -and
    @($freeze.source_bindings).Count -eq 223 -and
    [string]$freeze.runtime_artifact.raw_sha256 -ceq
        [string]$closure.physical_evidence.rapier_worker_release_sha256 -and
    [bool]$freeze.runtime_artifact.build.msvc_brepro -and
    [bool]$freeze.runtime_artifact.build.pdb_alt_path_bare_name -and
    -not [bool]$freeze.runtime_artifact.build.codegen_units_forced -and
    [string]$attempt.attempt_id -ceq [string]$closure.attempt_id -and
    [bool]$attempt.production_retention_preflight_passed -and
    [bool]$canary.exact_production_cas_path_exercised -and
    [bool]$canary.complete_cas_binding_verifier_exercised -and
    [int]$canary.synthetic_trace_count -eq 2 -and
    [int]$canary.synthetic_trace_row_count -eq 5984 -and
    [int]$canary.model_construction_count -eq 0 -and
    [int]$canary.world_attempt_count -eq 0 -and
    [int]$canary.world_build_count -eq 0 -and
    [int]$canary.ordinary_and_windows_extended_path_spelling_positive_control_count -eq 2 -and
    [int]$canary.wrong_existing_file_rejection_count -eq 1 -and
    $authorization.Count -eq 6 -and
    @($authorization | Where-Object {
        [bool]$_.authorization_passed -and
        [bool]$_.returned_before_model -and
        [int]$_.model_construction_count -eq 0 -and
        [int]$_.world_build_count -eq 0
    }).Count -eq 6
) "pre-world retention, path identity, or authorization changed"

$evaluation = $report.complete_evaluation
Assert-R23D44 (
    [string]$report.result_classification -ceq
        "valid_complete_ramp_induced_turning_gate_regression_at_seed_21504" -and
    [string]$evaluation.classification -ceq
        [string]$report.result_classification -and
    [int]$evaluation.cell_count -eq 6 -and
    [bool]$evaluation.all_cells_execution_valid -and
    @($evaluation.cell_evaluations | Where-Object {
        [string]$_.entry_kind -ceq "report" -and
        [bool]$_.execution_valid -and
        [bool]$_.common_physical_gate_passed -and
        @($_.failed_gate_ids).Count -eq 0 -and
        [int]$_.world_attempt_count -eq 1 -and
        [int]$_.world_build_count -eq 1
    }).Count -eq 6 -and
    [string]$completion.result_classification -ceq
        [string]$report.result_classification -and
    [bool]$completion.one_shot_identity_consumed -and
    -not [bool]$completion.same_identity_rerun_allowed
) "official attempt disposition changed"

$offsets = @{
    reference_zero = 0.0
    positive_heading = 0.2
    negative_heading = -0.2
}
$shifts = @{}
foreach ($candidate in @(
    "r23d29_no_startup_ramp_control",
    "r23d29_canonical_startup_ramp_treatment"
)) { $shifts[$candidate] = @{} }
for ($index = 0; $index -lt $closure.ordered_cells.Count; $index++) {
    $cell = $closure.ordered_cells[$index]
    Assert-R23D44 (
        [string]$terminalPaths[$index] -ceq
            [string]$report.ordered_matrix_cells[$index].terminal_entry_cas.payload_path
    ) "terminal manifest order changed: $($cell.cell_id)"
    $terminalPayload = Assert-Cas (
        [string]$cell.terminal_sha256
    ) ([long]$cell.terminal_byte_length)
    $terminal = Get-Content -Raw -LiteralPath $terminalPayload |
        ConvertFrom-Json -Depth 100
    $trace = $terminal.trace_artifact
    $tracePayload = Assert-Cas (
        [string]$cell.trace_sha256
    ) ([long]$cell.trace_byte_length)
    $recordedPath = [string]$trace.payload_path
    Assert-R23D44 ($recordedPath.StartsWith('\\?\')) (
        "extended path prefix changed: $($cell.cell_id)"
    )
    $ordinaryPath = $recordedPath.Substring(4)
    $rampEnabled = [string]$cell.candidate_id -ceq
        "r23d29_canonical_startup_ramp_treatment"
    Assert-R23D44 (
        (Test-Path -LiteralPath $recordedPath -PathType Leaf) -and
        (Test-Path -LiteralPath $ordinaryPath -PathType Leaf) -and
        (Get-Sha256 $recordedPath) -ceq [string]$cell.trace_sha256 -and
        (Get-Sha256 $ordinaryPath) -ceq [string]$cell.trace_sha256 -and
        [IO.Path]::GetFullPath($ordinaryPath) -ceq $tracePayload -and
        [string]$terminal.schema_version -ceq
            "sporespore_qsdk_r23d44_engine_cell_report_v1" -and
        [string]$terminal.source_commit -ceq $sourceCommit -and
        [string]$terminal.cell_id -ceq [string]$cell.cell_id -and
        [string]$terminal.candidate_id -ceq [string]$cell.candidate_id -and
        [string]$trace.sha256 -ceq [string]$cell.trace_sha256 -and
        [long]$trace.byte_length -eq [long]$cell.trace_byte_length -and
        [int]$terminal.trace_summary.row_count -eq 2992 -and
        [bool]$terminal.execution.integrity_passed -and
        [int]$terminal.execution.world_attempt_count -eq 1 -and
        [int]$terminal.execution.world_build_count -eq 1 -and
        [int]$terminal.measurements.controller_error_count -eq 0 -and
        [int]$terminal.measurements.nonfinite_observation_count -eq 0 -and
        [int]$terminal.measurements.actuator_application_mismatch_count -eq 0 -and
        [int]$terminal.measurements.torso_ground_contact_step_count -eq 0 -and
        [bool]$terminal.measurements.startup_ramp_composition_integrity_passed -and
        [double]$terminal.measurements.final_forward_displacement_m -ge 0.030123046875 -and
        [double]$terminal.measurements.maximum_tilt_rad -le 0.6 -and
        [double]$terminal.measurements.minimum_torso_height_m -ge 0.2499708652072946 -and
        @($terminal.measurements.contact_cycle_count_by_limb.PSObject.Properties |
            Where-Object { [int]$_.Value -ge 2 }).Count -eq 4
    ) "retained report, CAS, transform, or walking gate changed: $($cell.cell_id)"
    $shifts[[string]$cell.candidate_id][[string]$cell.arm_id] =
        Measure-R23D44Trace `
            -Payload $tracePayload `
            -CellId ([string]$cell.cell_id) `
            -CandidateId ([string]$cell.candidate_id) `
            -TurnOffset ([double]$offsets[[string]$cell.arm_id]) `
            -RampEnabled $rampEnabled
}

$control = $shifts["r23d29_no_startup_ramp_control"]
$treatment = $shifts["r23d29_canonical_startup_ramp_treatment"]
$controlPositive = [double]$control.positive_heading - [double]$control.reference_zero
$controlNegative = [double]$control.reference_zero - [double]$control.negative_heading
$treatmentPositive = [double]$treatment.positive_heading - [double]$treatment.reference_zero
$treatmentNegative = [double]$treatment.reference_zero - [double]$treatment.negative_heading
Assert-Near ([double]$control.reference_zero) 0.004813174182859457 "control reference shift changed"
Assert-Near ([double]$control.positive_heading) 0.014843707200735703 "control positive shift changed"
Assert-Near ([double]$control.negative_heading) -0.016598260046613304 "control negative shift changed"
Assert-Near $controlPositive 0.010030533017876247 "control conditioned positive changed"
Assert-Near $controlNegative 0.02141143422947276 "control conditioned negative changed"
Assert-Near ([double]$treatment.reference_zero) 0.007956418379890473 "treatment reference shift changed"
Assert-Near ([double]$treatment.positive_heading) 0.013402228756669826 "treatment positive shift changed"
Assert-Near ([double]$treatment.negative_heading) -0.019892380741927226 "treatment negative shift changed"
Assert-Near $treatmentPositive 0.005445810376779353 "treatment conditioned positive changed"
Assert-Near $treatmentNegative 0.0278487991218177 "treatment conditioned negative changed"
Assert-Near ($treatmentPositive - $controlPositive) -0.004584722641096894 "paired positive contrast changed"
Assert-Near ($treatmentNegative - $controlNegative) 0.0064373648923449385 "paired negative contrast changed"

Assert-R23D44 (
    [double]$control.positive_heading -ge 0.01 -and
    [double]$control.negative_heading -le -0.01 -and
    $controlPositive -ge 0.01 -and
    $controlNegative -ge 0.01 -and
    [double]$treatment.positive_heading -ge 0.01 -and
    [double]$treatment.negative_heading -le -0.01 -and
    $treatmentPositive -lt 0.01 -and
    $treatmentNegative -ge 0.01 -and
    [bool]$closure.candidate_results.r23d29_no_startup_ramp_control.full_three_arm_gate_passed -and
    -not [bool]$closure.candidate_results.r23d29_canonical_startup_ramp_treatment.full_three_arm_gate_passed -and
    [bool]$closure.scientific_interpretation.both_candidates_walked_and_passed_every_common_physical_gate -and
    [bool]$closure.claims.paired_same_seed_startup_transform_effect_characterized -and
    [bool]$closure.claims.rapier_parry_seed_21504_both_candidates_walked -and
    -not [bool]$closure.claims.finite_rapier_turning_validation -and
    -not [bool]$closure.claims.portable_basic_turning -and
    -not [bool]$closure.claims.finite_three_engine_turning -and
    -not [bool]$closure.claims.cross_engine_equivalence -and
    -not [bool]$closure.claims.release_authorized -and
    -not [bool]$closure.claims.physical_acceptance_authority
) "causal result or claim boundary changed"

$refusal = & (Join-Path $PSHOME "pwsh.exe") `
    -NoLogo -NoProfile -ExecutionPolicy Bypass `
    -File (Join-Path $repoRoot "sdk\run_qsdk_r23d44_supervisor.ps1") `
    -RunPhysical 2>&1
Assert-R23D44 ($LASTEXITCODE -eq 0) "closed-identity refusal exited nonzero"
$refusalText = @($refusal | ForEach-Object { [string]$_ }) -join "`n"
Assert-R23D44 (
    $refusalText -like "*QSDK_R23D44_PHYSICAL_REFUSAL*" -and
    $refusalText -like '*"world_attempt_count":0*' -and
    $refusalText -like '*"world_build_count":0*' -and
    $refusalText -like '*"physical_process_launch_count":0*'
) "closed-identity zero-world refusal changed"

Write-Host (
    "QSDK_R23D44_CLOSURE_PASS classification=ramp_induced_turning_gate_regression " +
    "cells=6 worlds=6 traces=6 canary_rows=5984 control_turning=True " +
    "ramp_turning=False both_walk=True rerun=False successor=False"
)
