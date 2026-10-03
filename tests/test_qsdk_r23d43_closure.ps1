#requires -Version 7.0

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$evidenceRoot = "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence"
$artifactRoot = Join-Path $evidenceRoot "artifacts\sha256"
$attemptRoot = Join-Path $evidenceRoot "qsdk-r23d43-20260813T101236Z"
$closurePath = Join-Path $repoRoot (
    "sdk\turning\r23d43_rapier_retention_hardened_turning_closure_v1.json"
)
$sourceCommit = "0fe05a4e761615113e858fd015eef6ece3cd0b00"
$tolerance = 1.0e-12
$twoPi = 2.0 * [Math]::PI

function Assert-R23D43([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "QSDK-R23D43 CLOSURE: $Message" }
}

function Assert-Near(
    [double]$Actual,
    [double]$Expected,
    [string]$Message
) {
    Assert-R23D43 (
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
    Assert-R23D43 ($process.Start()) "failed to start git cat-file"
    $memory = [IO.MemoryStream]::new()
    try {
        $process.StandardOutput.BaseStream.CopyTo($memory)
        $stderr = $process.StandardError.ReadToEnd()
        $process.WaitForExit()
        Assert-R23D43 ($process.ExitCode -eq 0) (
            "historical blob unavailable: $RelativePath; $stderr"
        )
        return ,([byte[]]$memory.ToArray())
    } finally {
        $memory.Dispose()
        $process.Dispose()
    }
}

function Assert-Cas([string]$Sha256, [long]$ByteLength) {
    Assert-R23D43 ($Sha256 -cmatch '^sha256:[0-9a-f]{64}$') (
        "invalid CAS digest: $Sha256"
    )
    $directory = Join-Path $artifactRoot $Sha256.Substring(7)
    $payload = Join-Path $directory "payload.bin"
    $manifestPath = Join-Path $directory "manifest.json"
    Assert-R23D43 (
        (Test-Path -LiteralPath $payload -PathType Leaf) -and
        (Test-Path -LiteralPath $manifestPath -PathType Leaf) -and
        (Get-Item -LiteralPath $payload).Length -eq $ByteLength -and
        (Get-Sha256 $payload) -ceq $Sha256
    ) "CAS payload changed: $Sha256"
    $manifest = Get-Content -Raw -LiteralPath $manifestPath |
        ConvertFrom-Json -Depth 20
    Assert-R23D43 (
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
    Assert-R23D43 (
        (Test-Path -LiteralPath $Path -PathType Leaf) -and
        (Get-Item -LiteralPath $Path).Length -eq $ByteLength -and
        (Get-Sha256 $Path) -ceq $Sha256
    ) "retained artifact changed: $Path"
    $payload = Assert-Cas $Sha256 $ByteLength
    Assert-R23D43 ((Get-Sha256 $payload) -ceq (Get-Sha256 $Path)) (
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

function Measure-R23D43Trace(
    [string]$Payload,
    [string]$CellId,
    [double]$TurnOffset
) {
    $rows = @(Get-Content -LiteralPath $Payload | ForEach-Object {
        $_ | ConvertFrom-Json -Depth 30
    })
    Assert-R23D43 ($rows.Count -eq 2992) "trace row count changed: $CellId"
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
        Assert-R23D43 (
            [string]$row.schema_version -ceq
                "sporespore_qsdk_r23d43_turning_trace_row_v1" -and
            [string]$row.cell_id -ceq $CellId -and
            [int]$row.semantic_step -eq $index -and
            [int]$row.trace_step -eq $index -and
            [string]$row.segment_id -ceq $segment -and
            [double]$row.desired_heading_offset_rad -eq $expectedOffset -and
            [int]$row.validated_portable_command_count -eq 8 -and
            [int]$row.native_actuation_application_count -eq 8 -and
            [bool]$row.oracle_passed -and
            [double]::IsFinite($yaw)
        ) "trace row changed: $CellId/$index"
        if ($index -eq 0) {
            $previousRaw = $yaw
            $previousUnwrapped = $yaw
            $unwrapped.Add($yaw)
            continue
        }
        $delta = [Math]::IEEERemainder($yaw - $previousRaw, $twoPi)
        Assert-R23D43 (
            [double]::IsFinite($delta) -and
            [Math]::Abs([Math]::Abs($delta) - [Math]::PI) -gt $tolerance
        ) "ambiguous yaw unwrap: $CellId/$index"
        $previousUnwrapped += $delta
        $previousRaw = $yaw
        $unwrapped.Add($previousUnwrapped)
    }
    return (Get-WindowMean $unwrapped 1440 1800) -
        (Get-WindowMean $unwrapped 240 600)
}

$closure = Get-Content -Raw -LiteralPath $closurePath |
    ConvertFrom-Json -Depth 100
Assert-R23D43 (
    (git -C $repoRoot rev-parse --show-toplevel).Trim().Replace('/', '\') -ceq
        $repoRoot -and
    (git -C $repoRoot remote get-url origin).Trim() -ceq
        "https://github.com/Slagathore/sporespore.git" -and
    [string]$closure.schema_version -ceq
        "sporespore_qsdk_r23d43_rapier_retention_hardened_turning_closure_v1" -and
    [string]$closure.status -ceq
        "closed_consumed_implementation_invalid_windows_extended_path_cas_verifier" -and
    [string]$closure.source_commit -ceq $sourceCommit -and
    (git -C $repoRoot rev-parse "$sourceCommit`^{tree}").Trim() -ceq
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
    Assert-R23D43 (
        (Get-BytesSha256 $bytes) -ceq
            [string]$closure.prospective_inputs.($property.sha)
    ) "pinned prospective input changed: $relative"
}

$failedQualification = Get-Content -Raw -LiteralPath (
    [string]$closure.qualification.first_failed_attestation_path
) | ConvertFrom-Json -Depth 30
Assert-R23D43 (
    (Get-Sha256 ([string]$closure.qualification.first_failed_attestation_path)) -ceq
        [string]$closure.qualification.first_failed_attestation_sha256 -and
    (Get-Item -LiteralPath (
        [string]$closure.qualification.first_failed_attestation_path
    )).Length -eq [long]$closure.qualification.first_failed_attestation_byte_length -and
    [string]$failedQualification.source_commit -ceq
        "f6eba21ac7c5bddd6763db37a65ed547ed8a3c38" -and
    -not [bool]$failedQualification.campaign_local_qualification_passed -and
    -not [bool]$failedQualification.physical_launch_prerequisite_satisfied -and
    [int]$closure.qualification.first_failure_world_count -eq 0 -and
    -not [bool]$closure.qualification.first_failure_consumed_physical_identity
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
Assert-R23D43 (
    [string]$attestation.source.commit -ceq $sourceCommit -and
    [int]$attestation.global_gate_count -eq 12 -and
    [int]$attestation.lineage_gate_count -eq 2 -and
    [int]$attestation.campaign_gate_count -eq 3 -and
    @($attestation.gate_receipts).Count -eq 17 -and
    [string]$adoption.source_commit -ceq $sourceCommit -and
    [bool]$adoption.physical_launch_prerequisite_satisfied
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
$authorization = Get-Content -Raw -LiteralPath (
    $rootPayloads["authorization-preflights.json"]
) | ConvertFrom-Json -Depth 100
$terminalPaths = @(Get-Content -Raw -LiteralPath (
    $rootPayloads["terminal-paths.json"]
) | ConvertFrom-Json)
$report = Get-Content -Raw -LiteralPath $rootPayloads["report.json"] |
    ConvertFrom-Json -Depth 100
$completion = Get-Content -Raw -LiteralPath $rootPayloads["completion.json"] |
    ConvertFrom-Json -Depth 100
$canary = $freeze.production_retention_preflight
$canaryPayload = Assert-Cas (
    [string]$closure.physical_evidence.production_retention_canary_trace.sha256
) ([long]$closure.physical_evidence.production_retention_canary_trace.byte_length)
Assert-R23D43 (
    [string]$freeze.source_commit -ceq $sourceCommit -and
    [string]$attempt.attempt_id -ceq [string]$closure.attempt_id -and
    [bool]$attempt.production_retention_preflight_passed -and
    [bool]$canary.exact_production_cas_path_exercised -and
    [int]$canary.synthetic_trace_row_count -eq 2992 -and
    [int]$canary.model_construction_count -eq 0 -and
    [int]$canary.world_attempt_count -eq 0 -and
    [int]$canary.world_build_count -eq 0 -and
    (Get-Sha256 $canaryPayload) -ceq
        [string]$canary.trace_retention.trace_artifact.sha256 -and
    @($authorization).Count -eq 3 -and
    @($authorization | Where-Object {
        [bool]$_.authorization_passed -and
        [bool]$_.returned_before_model -and
        [int]$_.model_construction_count -eq 0 -and
        [int]$_.world_build_count -eq 0
    }).Count -eq 3
) "pre-world production authorization changed"

$evaluation = $report.complete_evaluation
Assert-R23D43 (
    [string]$report.result_classification -ceq
        "invalid_or_incomplete_finite_rapier_turning_replication" -and
    [string]$evaluation.classification -ceq
        [string]$report.result_classification -and
    [int]$evaluation.cell_count -eq 3 -and
    -not [bool]$evaluation.all_cells_execution_valid -and
    -not [bool]$evaluation.all_common_physical_gates_passed -and
    $null -eq $evaluation.cycle_integrated_measurement -and
    @($evaluation.cell_evaluations | Where-Object {
        [string]$_.entry_kind -ceq "report" -and
        -not [bool]$_.execution_valid -and
        @($_.failed_gate_ids).Count -eq 1 -and
        [string]$_.failed_gate_ids[0] -ceq "R23D42_TRACE_ARTIFACT_CAS_PATH"
    }).Count -eq 3 -and
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
for ($index = 0; $index -lt $closure.ordered_cells.Count; $index++) {
    $cell = $closure.ordered_cells[$index]
    Assert-R23D43 (
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
    Assert-R23D43 ($recordedPath.StartsWith('\\?\')) (
        "extended path prefix changed: $($cell.cell_id)"
    )
    $ordinaryPath = $recordedPath.Substring(4)
    Assert-R23D43 (
        (Test-Path -LiteralPath $recordedPath -PathType Leaf) -and
        (Test-Path -LiteralPath $ordinaryPath -PathType Leaf) -and
        (Get-Sha256 $recordedPath) -ceq [string]$cell.trace_sha256 -and
        (Get-Sha256 $ordinaryPath) -ceq [string]$cell.trace_sha256 -and
        [IO.Path]::GetFullPath($ordinaryPath) -ceq $tracePayload -and
        [string]$terminal.schema_version -ceq
            "sporespore_qsdk_r23d43_engine_cell_report_v1" -and
        [string]$terminal.source_commit -ceq $sourceCommit -and
        [string]$terminal.cell_id -ceq [string]$cell.cell_id -and
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
        [double]$terminal.measurements.final_forward_displacement_m -ge 0.030123046875 -and
        [double]$terminal.measurements.maximum_tilt_rad -le 0.6 -and
        [double]$terminal.measurements.minimum_torso_height_m -ge 0.2499708652072946 -and
        @($terminal.measurements.contact_cycle_count_by_limb.PSObject.Properties |
            Where-Object { [int]$_.Value -ge 2 }).Count -eq 4
    ) "retained report, CAS, or walking gate changed: $($cell.cell_id)"
    $shifts[[string]$cell.arm_id] = Measure-R23D43Trace `
        -Payload $tracePayload `
        -CellId ([string]$cell.cell_id) `
        -TurnOffset ([double]$offsets[[string]$cell.arm_id])
}

$positiveConditioned = [double]$shifts.positive_heading -
    [double]$shifts.reference_zero
$negativeConditioned = [double]$shifts.reference_zero -
    [double]$shifts.negative_heading
$diagnostic = $closure.postclosure_non_authoritative_path_spelling_diagnostic
Assert-Near ([double]$shifts.reference_zero) 0.007853050194275714 (
    "reference cycle shift changed"
)
Assert-Near ([double]$shifts.positive_heading) 0.01378068411509556 (
    "positive cycle shift changed"
)
Assert-Near ([double]$shifts.negative_heading) -0.019616693639142327 (
    "negative cycle shift changed"
)
Assert-Near $positiveConditioned 0.005927633920819846 (
    "positive conditioned shift changed"
)
Assert-Near $negativeConditioned 0.02746974383341804 (
    "negative conditioned shift changed"
)
Assert-R23D43 (
    [double]$shifts.positive_heading -ge 0.01 -and
    [double]$shifts.negative_heading -le -0.01 -and
    $positiveConditioned -lt 0.01 -and
    $negativeConditioned -ge 0.01 -and
    [bool]$diagnostic.raw_signed_cycle_shift_gate_passed -and
    -not [bool]$diagnostic.reference_conditioned_cycle_shift_gate_passed -and
    -not [bool]$diagnostic.cycle_integrated_measurement_passed -and
    [string]$diagnostic.diagnostic_classification -ceq
        "valid_complete_negative_finite_rapier_turning_replication" -and
    -not [bool]$diagnostic.may_replace_official_invalid_cells_or_create_physical_claim -and
    -not [bool]$diagnostic.historical_result_reinterpreted -and
    -not [bool]$diagnostic.physical_acceptance_authority
) "postclosure diagnostic boundary changed"

Assert-R23D43 (
    [string]$closure.implementation_failure.failure_gate_id -ceq
        "R23D42_TRACE_ARTIFACT_CAS_PATH" -and
    [int]$closure.implementation_failure.failure_count -eq 3 -and
    [bool]$closure.implementation_failure.production_trace_publication_succeeded -and
    [bool]$closure.implementation_failure.both_spellings_resolve_to_same_files -and
    -not [bool]$closure.implementation_failure.same_identity_repair_or_rerun_permitted -and
    -not [bool]$closure.implementation_failure.historical_outcome_reinterpreted -and
    -not [bool]$closure.implementation_failure.successor_opened -and
    -not [bool]$closure.claims.r23d43_finite_rapier_turning_replication -and
    -not [bool]$closure.claims.rapier_parry_seed_21511_accepted_walking_or_turning -and
    -not [bool]$closure.claims.portable_basic_turning -and
    -not [bool]$closure.claims.finite_three_engine_turning -and
    -not [bool]$closure.claims.cross_engine_equivalence -and
    -not [bool]$closure.claims.release_authorized -and
    -not [bool]$closure.claims.physical_acceptance_authority
) "failure mechanism or claims changed"

Write-Host (
    "QSDK_R23D43_CLOSURE_PASS classification=implementation_invalid cells=3 " +
    "worlds=3 traces=3 cas_path_failures=3 posthoc_walking=True " +
    "posthoc_turning=False rerun=False successor=False"
)
