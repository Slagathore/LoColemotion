#requires -Version 7.0

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$evidenceRoot = "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence"
$artifactRoot = Join-Path $evidenceRoot "artifacts\sha256"
$attemptRoot = Join-Path $evidenceRoot "qsdk-r23d42-20260813T075636Z"
$closurePath = Join-Path $repoRoot (
    "sdk\turning\r23d42_three_engine_startup_ramp_turning_closure_v1.json"
)
$sourceCommit = "91db8559e4545e2ff1cb8061f631cfb6734dd0a2"
$tolerance = 1.0e-12
$twoPi = 2.0 * [Math]::PI

function Assert-R23D42([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "QSDK-R23D42 CLOSURE: $Message" }
}

function Assert-Near(
    [double]$Actual,
    [double]$Expected,
    [string]$Message
) {
    Assert-R23D42 (
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
    Assert-R23D42 ($process.Start()) "failed to start git cat-file"
    $memory = [IO.MemoryStream]::new()
    try {
        $process.StandardOutput.BaseStream.CopyTo($memory)
        $stderr = $process.StandardError.ReadToEnd()
        $process.WaitForExit()
        Assert-R23D42 ($process.ExitCode -eq 0) (
            "historical blob unavailable: $RelativePath; $stderr"
        )
        return ,([byte[]]$memory.ToArray())
    } finally {
        $memory.Dispose()
        $process.Dispose()
    }
}

function Assert-Cas([string]$Sha256, [long]$ByteLength) {
    Assert-R23D42 ($Sha256 -cmatch '^sha256:[0-9a-f]{64}$') (
        "invalid CAS digest: $Sha256"
    )
    $directory = Join-Path $artifactRoot $Sha256.Substring(7)
    $payload = Join-Path $directory "payload.bin"
    $manifestPath = Join-Path $directory "manifest.json"
    Assert-R23D42 (
        (Test-Path -LiteralPath $payload -PathType Leaf) -and
        (Test-Path -LiteralPath $manifestPath -PathType Leaf) -and
        (Get-Item -LiteralPath $payload).Length -eq $ByteLength -and
        (Get-Sha256 $payload) -ceq $Sha256
    ) "CAS payload changed: $Sha256"
    $manifest = Get-Content -Raw -LiteralPath $manifestPath |
        ConvertFrom-Json -Depth 20
    Assert-R23D42 (
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
    Assert-R23D42 (
        (Test-Path -LiteralPath $Path -PathType Leaf) -and
        (Get-Item -LiteralPath $Path).Length -eq $ByteLength -and
        (Get-Sha256 $Path) -ceq $Sha256
    ) "retained artifact changed: $Path"
    $payload = Assert-Cas $Sha256 $ByteLength
    Assert-R23D42 ((Get-Sha256 $payload) -ceq (Get-Sha256 $Path)) (
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

function Measure-RapierTrace(
    [string]$Payload,
    [string]$CellId,
    [double]$TurnOffset
) {
    $rows = @(Get-Content -LiteralPath $Payload | ForEach-Object {
        $_ | ConvertFrom-Json -Depth 30
    })
    Assert-R23D42 ($rows.Count -eq 2992) "Rapier trace row count changed: $CellId"
    $unwrapped = [Collections.Generic.List[double]]::new()
    $previousRaw = 0.0
    $previousUnwrapped = 0.0
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
        $yaw = [double]$row.measured_yaw_rad
        Assert-R23D42 (
            [string]$row.schema_version -ceq
                "sporespore_qsdk_r23d42_turning_trace_row_v1" -and
            [string]$row.cell_id -ceq $CellId -and
            [int]$row.semantic_step -eq $index -and
            [int]$row.trace_step -eq $index -and
            [string]$row.segment_id -ceq $segment -and
            [double]$row.desired_heading_offset_rad -eq $expectedOffset -and
            [int]$row.validated_portable_command_count -eq 8 -and
            [int]$row.native_actuation_application_count -eq 8 -and
            [bool]$row.oracle_passed -and
            [double]::IsFinite($yaw)
        ) "Rapier posthoc row changed: $CellId/$index"
        if ($index -eq 0) {
            $previousRaw = $yaw
            $previousUnwrapped = $yaw
            $unwrapped.Add($yaw)
            continue
        }
        $delta = [Math]::IEEERemainder($yaw - $previousRaw, $twoPi)
        Assert-R23D42 (
            [double]::IsFinite($delta) -and
            [Math]::Abs([Math]::Abs($delta) - [Math]::PI) -gt $tolerance
        ) "ambiguous Rapier yaw unwrap: $CellId/$index"
        $previousUnwrapped += $delta
        $previousRaw = $yaw
        $unwrapped.Add($previousUnwrapped)
    }
    return (Get-WindowMean $unwrapped 1440 1800) -
        (Get-WindowMean $unwrapped 240 600)
}

$closure = Get-Content -Raw -LiteralPath $closurePath |
    ConvertFrom-Json -Depth 100
Assert-R23D42 (
    (git -C $repoRoot rev-parse --show-toplevel).Trim().Replace('/', '\') -ceq
        $repoRoot -and
    (git -C $repoRoot remote get-url origin).Trim() -ceq
        "https://github.com/Slagathore/sporespore.git" -and
    [string]$closure.schema_version -ceq
        "sporespore_qsdk_r23d42_three_engine_startup_ramp_turning_closure_v1" -and
    [string]$closure.status -ceq
        "closed_consumed_implementation_invalid_rapier_production_trace_cas_with_valid_godot_negative_and_mujoco_positive" -and
    [string]$closure.source_commit -ceq $sourceCommit -and
    (git -C $repoRoot rev-parse "$($sourceCommit)^{tree}").Trim() -ceq
        [string]$closure.source_tree_git_oid -and
    [bool]$closure.identity_consumed -and
    -not [bool]$closure.same_identity_rerun_allowed -and
    -not [bool]$closure.selective_rerun_allowed -and
    -not [bool]$closure.successor_campaign_opened -and
    [bool]$closure.physical_series_paused_before_successor
) "closure identity or immutable disposition changed"

foreach ($property in @(
    @{ path = "preregistration_path"; sha = "preregistration_raw_sha256" },
    @{ path = "implementation_path"; sha = "implementation_raw_sha256" },
    @{ path = "campaign_attestation_manifest_path"; sha = "campaign_attestation_manifest_raw_sha256" }
)) {
    $relative = [string]$closure.prospective_inputs.($property.path)
    $bytes = Get-GitBlobBytes $sourceCommit $relative
    Assert-R23D42 (
        (Get-BytesSha256 $bytes) -ceq
            [string]$closure.prospective_inputs.($property.sha)
    ) "pinned prospective input changed: $relative"
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
Assert-R23D42 (
    [string]$attestation.source.commit -ceq $sourceCommit -and
    [int]$closure.qualification.executed_gate_count -eq 17 -and
    [int]$closure.qualification.worlds_during_qualification -eq 0 -and
    [string]$adoption.source_commit -ceq $sourceCommit -and
    [bool]$adoption.physical_launch_prerequisite_satisfied
) "qualification identity changed"

$rootArtifacts = [ordered]@{
    "physical-freeze.json" = $closure.physical_evidence.physical_freeze
    "attempt-authorization.json" = $closure.physical_evidence.attempt_authorization
    "production-authorization-preflight.json" =
        $closure.physical_evidence.production_authorization_preflight
    "terminal-paths.json" = $closure.physical_evidence.terminal_manifest
    "complete-evaluation.json" = $closure.physical_evidence.complete_evaluation
    "report.json" = $closure.physical_evidence.report
    "completion.json" = $closure.physical_evidence.completion
}
$rootPayloads = @{}
foreach ($entry in $rootArtifacts.GetEnumerator()) {
    $record = $entry.Value
    $rootPayloads[$entry.Key] = Assert-PathAndCas (
        (Join-Path $attemptRoot $entry.Key)
    ) ([string]$record.sha256) ([long]$record.byte_length)
}

$freeze = Get-Content -Raw -LiteralPath $rootPayloads["physical-freeze.json"] |
    ConvertFrom-Json -Depth 100
$authorization = Get-Content -Raw -LiteralPath (
    $rootPayloads["attempt-authorization.json"]
) | ConvertFrom-Json -Depth 100
$production = Get-Content -Raw -LiteralPath (
    $rootPayloads["production-authorization-preflight.json"]
) | ConvertFrom-Json -Depth 100
$evaluation = Get-Content -Raw -LiteralPath (
    $rootPayloads["complete-evaluation.json"]
) | ConvertFrom-Json -Depth 100
$report = Get-Content -Raw -LiteralPath $rootPayloads["report.json"] |
    ConvertFrom-Json -Depth 100
$completion = Get-Content -Raw -LiteralPath $rootPayloads["completion.json"] |
    ConvertFrom-Json -Depth 100
Assert-R23D42 (
    [string]$freeze.source_commit -ceq $sourceCommit -and
    [int]$freeze.declared_world_count -eq 9 -and
    [bool]$freeze.physical_execution_authorized -and
    [string]$authorization.attempt_id -ceq [string]$closure.attempt_id -and
    [bool]$authorization.physical_execution_authorized -and
    [int]$production.exact_production_authorization_predicate_count -eq 9 -and
    [bool]$production.all_authorizations_passed -and
    [int]$production.world_build_count -eq 0 -and
    [string]$evaluation.classification -ceq
        "invalid_or_incomplete_three_engine_portable_turning_validation" -and
    [int]$evaluation.cell_count -eq 9 -and
    [string]$report.result_classification -ceq
        [string]$evaluation.classification -and
    [int]$completion.cell_count -eq 9 -and
    [int]$completion.world_count -eq 9 -and
    [bool]$completion.one_shot_attempt_consumed -and
    -not [bool]$completion.replacement_or_selective_rerun_permitted
) "official attempt envelope changed"

$evaluationCells = @($evaluation.cell_evaluations)
$rapierEvaluation = @($evaluationCells | Where-Object engine_id -ceq "rapier_parry")
$godotEvaluation = @($evaluationCells | Where-Object engine_id -ceq "godot_jolt")
$mujocoEvaluation = @($evaluationCells | Where-Object engine_id -ceq "mujoco")
Assert-R23D42 (
    $rapierEvaluation.Count -eq 3 -and
    @($rapierEvaluation | Where-Object {
        [string]$_.entry_kind -ceq "worker_failure" -and
        -not [bool]$_.execution_valid -and
        @($_.failed_gate_ids).Count -eq 1 -and
        [string]$_.failed_gate_ids[0] -ceq
            "QSDK_R23D27_RAP_TRACE_RETENTION_FAILED:exit code: 1:"
    }).Count -eq 3 -and
    $godotEvaluation.Count -eq 3 -and
    @($godotEvaluation | Where-Object {
        [string]$_.entry_kind -ceq "report" -and
        [bool]$_.execution_valid -and [bool]$_.common_physical_gate_passed
    }).Count -eq 3 -and
    $mujocoEvaluation.Count -eq 3 -and
    @($mujocoEvaluation | Where-Object {
        [string]$_.entry_kind -ceq "report" -and
        [bool]$_.execution_valid -and [bool]$_.common_physical_gate_passed
    }).Count -eq 3
) "official cell classification changed"

Assert-R23D42 (
    -not [bool]$evaluation.engine_results.godot_jolt.passed -and
    -not [bool]$evaluation.engine_results.godot_jolt.cycle_integrated_measurement.gates.raw_signed_cycle_shift -and
    -not [bool]$evaluation.engine_results.godot_jolt.cycle_integrated_measurement.gates.reference_conditioned_cycle_shift -and
    [bool]$evaluation.engine_results.mujoco.passed -and
    [bool]$evaluation.engine_results.mujoco.cycle_integrated_measurement.gates.raw_signed_cycle_shift -and
    [bool]$evaluation.engine_results.mujoco.cycle_integrated_measurement.gates.reference_conditioned_cycle_shift -and
    -not [bool]$evaluation.engine_results.rapier_parry.passed -and
    $null -eq $evaluation.engine_results.rapier_parry.cycle_integrated_measurement
) "official engine disposition changed"
Assert-Near (
    [double]$evaluation.engine_results.godot_jolt.cycle_integrated_measurement.positive_reference_conditioned_cycle_shift_rad
) 0.37912843078341085 "Godot positive conditioned shift changed"
Assert-Near (
    [double]$evaluation.engine_results.godot_jolt.cycle_integrated_measurement.negative_reference_conditioned_cycle_shift_rad
) -0.21039702380968173 "Godot negative conditioned shift changed"
Assert-Near (
    [double]$evaluation.engine_results.mujoco.cycle_integrated_measurement.positive_reference_conditioned_cycle_shift_rad
) 0.13535838391442867 "MuJoCo positive conditioned shift changed"
Assert-Near (
    [double]$evaluation.engine_results.mujoco.cycle_integrated_measurement.negative_reference_conditioned_cycle_shift_rad
) 0.14007451270823182 "MuJoCo negative conditioned shift changed"

foreach ($cell in @($closure.ordered_cells)) {
    $terminalPayload = Assert-Cas (
        [string]$cell.terminal_sha256
    ) ([long]$cell.terminal_byte_length)
    $pendingPayload = Assert-Cas (
        [string]$cell.pending_rows_sha256
    ) ([long]$cell.pending_rows_byte_length)
    $terminal = Get-Content -Raw -LiteralPath $terminalPayload |
        ConvertFrom-Json -Depth 100
    Assert-R23D42 (
        [string]$terminal.cell_id -ceq [string]$cell.cell_id -and
        [string]$terminal.source_commit -ceq $sourceCommit
    ) "terminal identity changed: $($cell.cell_id)"
    if ([string]$cell.entry_kind -ceq "worker_failure") {
        Assert-R23D42 (
            [string]$terminal.schema_version -ceq
                "sporespore_qsdk_r23d42_worker_failure_v1" -and
            [string]$terminal.failure_stage -ceq "settlement_complete" -and
            [string]$terminal.failure_code -ceq
                "QSDK_R23D27_RAP_TRACE_RETENTION_FAILED:exit code: 1:"
        ) "Rapier failure changed: $($cell.cell_id)"
        $tracePayload = Assert-Cas (
            [string]$cell.postclosure_trace_sha256
        ) ([long]$cell.postclosure_trace_byte_length)
    } else {
        Assert-R23D42 (
            [string]$terminal.schema_version -ceq
                "sporespore_qsdk_r23d42_engine_cell_report_v1" -and
            [bool]$terminal.execution.integrity_passed -and
            [int]$terminal.execution.world_build_count -eq 1 -and
            [string]$terminal.trace_artifact.sha256 -ceq
                [string]$cell.trace_sha256
        ) "valid terminal changed: $($cell.cell_id)"
        $tracePayload = Assert-Cas (
            [string]$cell.trace_sha256
        ) ([long]$cell.trace_byte_length)
    }
    # Force enumeration so the audit checks every terminal, pending file, and trace.
    $null = $pendingPayload
    $null = $tracePayload
}

$rapierCells = @($closure.ordered_cells | Where-Object {
    [string]$_.engine_id -ceq "rapier_parry"
})
$rapierShifts = @{}
foreach ($cell in $rapierCells) {
    $offset = switch ([string]$cell.arm_id) {
        "positive_heading" { 0.2 }
        "negative_heading" { -0.2 }
        default { 0.0 }
    }
    $payload = Assert-Cas (
        [string]$cell.postclosure_trace_sha256
    ) ([long]$cell.postclosure_trace_byte_length)
    $rapierShifts[[string]$cell.arm_id] = Measure-RapierTrace (
        $payload
    ) ([string]$cell.cell_id) $offset
}
$positiveConditioned = [double]$rapierShifts.positive_heading -
    [double]$rapierShifts.reference_zero
$negativeConditioned = [double]$rapierShifts.reference_zero -
    [double]$rapierShifts.negative_heading
$bilateral = [double]$rapierShifts.positive_heading -
    [double]$rapierShifts.negative_heading
Assert-Near ([double]$rapierShifts.reference_zero) 0.007878593049818083 (
    "Rapier posthoc reference shift changed"
)
Assert-Near ([double]$rapierShifts.positive_heading) 0.01385659557264482 (
    "Rapier posthoc positive shift changed"
)
Assert-Near ([double]$rapierShifts.negative_heading) -0.0200632650905428 (
    "Rapier posthoc negative shift changed"
)
Assert-Near $positiveConditioned 0.005978002522826736 (
    "Rapier posthoc positive conditioned shift changed"
)
Assert-Near $negativeConditioned 0.027941858140360883 (
    "Rapier posthoc negative conditioned shift changed"
)
Assert-Near $bilateral 0.03391986066318762 (
    "Rapier posthoc bilateral shift changed"
)
Assert-R23D42 (
    [double]$rapierShifts.positive_heading -ge 0.01 -and
    [double]$rapierShifts.negative_heading -le -0.01 -and
    $positiveConditioned -lt 0.01 -and
    $negativeConditioned -ge 0.01 -and
    -not [bool]$closure.postclosure_non_authoritative_rapier_diagnostic.may_replace_official_worker_failures_or_create_physical_claim -and
    -not [bool]$closure.postclosure_non_authoritative_rapier_diagnostic.cycle_integrated_measurement_passed
) "Rapier posthoc non-authority or negative result changed"

$rustText = [Text.Encoding]::UTF8.GetString((Get-GitBlobBytes $sourceCommit (
    "sdk/adapters/rapier/src/qsdk_r23d3_phase_balanced/r23d27_physical.rs"
)))
$evaluatorText = [Text.Encoding]::UTF8.GetString((Get-GitBlobBytes $sourceCommit (
    "sdk/turning/r23d42_three_engine_startup_ramp_turning_evaluator.py"
)))
Assert-R23D42 (
    $rustText -match
        'QSDK_R23D27_RAP_TRACE_RETENTION_FAILED:[\s\S]{0,220}output\.stderr' -and
    $evaluatorText.Contains('print(f"QSDK_R23D42_EVALUATOR_FAILURE') -and
    [string]$closure.implementation_failure.underlying_production_time_cas_failure_mechanism -ceq
        "unresolved" -and
    -not [bool]$closure.implementation_failure.repo_root_mismatch_supported -and
    -not [bool]$closure.implementation_failure.persistent_cas_corruption_supported -and
    [bool]$closure.implementation_failure.successor_must_capture_child_stdout_and_stderr
) "observability boundary or failure restraint changed"

Assert-R23D42 (
    [int]$closure.physical_evidence.complete_attempt_file_count -eq 52 -and
    [long]$closure.physical_evidence.complete_attempt_byte_count -eq 144997334 -and
    [bool]$closure.physical_evidence.complete_attempt_files_content_addressed_at_closure -and
    [int]$closure.physical_evidence.postclosure_pending_row_file_cas_retention_count -eq 9 -and
    [int]$closure.physical_evidence.postclosure_orphaned_rapier_trace_cas_retention_count -eq 3 -and
    -not [bool]$closure.physical_evidence.postclosure_retention_repairs_execution_timing_or_official_cell_validity -and
    [bool]$closure.claims.godot_jolt_seed_21510_walking -and
    -not [bool]$closure.claims.godot_jolt_seed_21510_turning -and
    [bool]$closure.claims.mujoco_seed_21510_walking_and_turning -and
    -not [bool]$closure.claims.rapier_parry_seed_21510_accepted_walking_or_turning -and
    -not [bool]$closure.claims.finite_three_engine_turning -and
    -not [bool]$closure.claims.portable_basic_turning -and
    -not [bool]$closure.claims.q_sdk_r23_satisfied -and
    -not [bool]$closure.claims.cross_engine_equivalence -and
    -not [bool]$closure.claims.prone_to_standing -and
    -not [bool]$closure.claims.release_authorized -and
    -not [bool]$closure.claims.physical_acceptance_authority
) "retention boundary or claim limits changed"

Write-Output (
    "QSDK_R23D42_CLOSURE_PASS classification=implementation_invalid " +
    "cells=9 worlds=9 execution_valid=6 rapier_retention_failures=3 " +
    "godot_turning=False mujoco_turning=True three_engine=False rerun=False"
)
