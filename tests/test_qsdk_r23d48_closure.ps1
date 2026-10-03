#requires -Version 7.0

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$evidenceRoot = "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence"
$artifactRoot = Join-Path $evidenceRoot "artifacts\sha256"
$attemptRoot = Join-Path $evidenceRoot "qsdk-r23d48-20260813T133942Z"
$closurePath = Join-Path $repoRoot (
    "sdk\turning\r23d48_support_loss_conditioned_three_engine_turning_closure_v1.json"
)
$sourceCommit = "0a9edce0e5b85c84020087b121f7c6fb239afc97"
$tolerance = 1.0e-12
$twoPi = 2.0 * [Math]::PI

function Assert-R23D48Closure([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "QSDK-R23D48 CLOSURE: $Message" }
}

function Assert-Near([double]$Actual, [double]$Expected, [string]$Message) {
    Assert-R23D48Closure (
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
    Assert-R23D48Closure ($process.Start()) "could not start git cat-file"
    $memory = [IO.MemoryStream]::new()
    try {
        $process.StandardOutput.BaseStream.CopyTo($memory)
        $stderr = $process.StandardError.ReadToEnd()
        $process.WaitForExit()
        Assert-R23D48Closure ($process.ExitCode -eq 0) (
            "historical blob unavailable: $RelativePath; $stderr"
        )
        return ,([byte[]]$memory.ToArray())
    } finally {
        $memory.Dispose()
        $process.Dispose()
    }
}

function Assert-Cas([string]$Sha256, [long]$ByteLength) {
    Assert-R23D48Closure ($Sha256 -cmatch '^sha256:[0-9a-f]{64}$') (
        "invalid CAS digest: $Sha256"
    )
    $directory = Join-Path $artifactRoot $Sha256.Substring(7)
    $payload = Join-Path $directory "payload.bin"
    $manifestPath = Join-Path $directory "manifest.json"
    Assert-R23D48Closure (
        (Test-Path -LiteralPath $payload -PathType Leaf) -and
        (Test-Path -LiteralPath $manifestPath -PathType Leaf) -and
        (Get-Item -LiteralPath $payload).Length -eq $ByteLength -and
        (Get-Sha256 $payload) -ceq $Sha256
    ) "CAS payload changed: $Sha256"
    $manifest = Get-Content -Raw -LiteralPath $manifestPath |
        ConvertFrom-Json -Depth 20
    Assert-R23D48Closure (
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
    Assert-R23D48Closure (
        (Test-Path -LiteralPath $Path -PathType Leaf) -and
        (Get-Item -LiteralPath $Path).Length -eq $ByteLength -and
        (Get-Sha256 $Path) -ceq $Sha256
    ) "retained artifact changed: $Path"
    $payload = Assert-Cas $Sha256 $ByteLength
    Assert-R23D48Closure ((Get-Sha256 $payload) -ceq (Get-Sha256 $Path)) (
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

function Measure-DiagnosticRapierTrace(
    [string]$Payload,
    [string]$CellId,
    [string]$ArmId
) {
    $yaw = [Collections.Generic.List[double]]::new()
    $previousRaw = 0.0
    $previousUnwrapped = 0.0
    $rowCount = 0
    $minimumSupport = 4
    foreach ($line in Get-Content -LiteralPath $Payload) {
        $row = $line | ConvertFrom-Json -Depth 30
        $expectedSegment = if ($rowCount -lt 600) {
            "reference_warmup"
        } elseif ($rowCount -lt 1800) {
            "commanded_turn"
        } elseif ($rowCount -lt 2400) {
            "reference_recovery"
        } else { "after_declared_schedule" }
        $support = @(
            $row.ordered_foot_contacts_before.PSObject.Properties |
                Where-Object { [bool]$_.Value }
        ).Count
        $minimumSupport = [Math]::Min($minimumSupport, $support)
        Assert-R23D48Closure (
            [string]$row.schema_version -ceq
                "sporespore_qsdk_r23d48_turning_trace_row_v1" -and
            [string]$row.cell_id -ceq $CellId -and
            [int]$row.semantic_step -eq $rowCount -and
            [int]$row.trace_step -eq $rowCount -and
            [string]$row.segment_id -ceq $expectedSegment -and
            [string]$row.startup_transform_id -ceq
                "support_loss_latched_smoothstep_one_cycle_v1" -and
            [string]$row.startup_ramp_id -ceq
                "support_loss_latched_smoothstep_one_cycle_v1" -and
            -not [bool]$row.startup_ramp_triggered -and
            -not [bool]$row.startup_ramp_active -and
            [double]$row.startup_velocity_scale -eq 1.0 -and
            [bool]$row.oracle_passed -and
            [int]$row.validated_portable_command_count -eq 8 -and
            [int]$row.native_actuation_application_count -eq 8 -and
            [double]::IsFinite([double]$row.measured_yaw_rad)
        ) "diagnostic Rapier row changed: $ArmId/$rowCount"
        $raw = [double]$row.measured_yaw_rad
        if ($rowCount -eq 0) {
            $previousRaw = $raw
            $previousUnwrapped = $raw
        } else {
            $delta = [Math]::IEEERemainder($raw - $previousRaw, $twoPi)
            Assert-R23D48Closure (
                [double]::IsFinite($delta) -and
                [Math]::Abs([Math]::Abs($delta) - [Math]::PI) -gt $tolerance
            ) "ambiguous diagnostic yaw unwrap: $ArmId/$rowCount"
            $previousUnwrapped += $delta
            $previousRaw = $raw
        }
        $yaw.Add($previousUnwrapped)
        $rowCount++
    }
    Assert-R23D48Closure (
        $rowCount -eq 2992 -and $yaw.Count -eq 2992 -and
        $minimumSupport -eq 2
    ) "diagnostic Rapier trace horizon or support branch changed: $ArmId"
    return (Get-WindowMean $yaw 1440 1800) - (Get-WindowMean $yaw 240 600)
}

Assert-R23D48Closure (
    (git -C $repoRoot rev-parse --show-toplevel).Trim().Replace('/', '\') -ceq
        $repoRoot -and
    (git -C $repoRoot remote get-url origin).Trim() -ceq
        "https://github.com/Slagathore/sporespore.git"
) "repository identity changed"

$closure = Get-Content -Raw -LiteralPath $closurePath |
    ConvertFrom-Json -Depth 100
Assert-R23D48Closure (
    [string]$closure.schema_version -ceq
        "sporespore_qsdk_r23d48_support_loss_conditioned_three_engine_turning_closure_v1" -and
    [string]$closure.status -ceq
        "closed_consumed_invalid_complete_rapier_trace_publication_failure_with_valid_mujoco_turning_and_godot_turning_negative" -and
    [string]$closure.source_commit -ceq $sourceCommit -and
    (git -C $repoRoot rev-parse "$sourceCommit`^{tree}").Trim() -ceq
        [string]$closure.source_tree_git_oid -and
    [string]$closure.attempt_id -ceq "824211f004f048fcbf0ecd6b7108dbc0" -and
    [int]$closure.campaign_seed -eq 21512 -and
    [bool]$closure.identity_consumed -and
    -not [bool]$closure.same_identity_rerun_allowed -and
    -not [bool]$closure.selective_rerun_allowed -and
    [bool]$closure.fresh_held_out_condition_consumed -and
    -not [bool]$closure.successor_campaign_opened -and
    [bool]$closure.physical_series_paused_before_successor
) "immutable disposition changed"

foreach ($input in @($closure.prospective_inputs)) {
    $relative = [string]$input.path
    $bytes = Get-GitBlobBytes $sourceCommit $relative
    Assert-R23D48Closure (
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
Assert-R23D48Closure (
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
    $rootPayloads[$entry.Key] = Assert-PathAndCas (
        (Join-Path $attemptRoot $entry.Key)
    ) ([string]$entry.Value.sha256) ([long]$entry.Value.byte_length)
}

$freeze = Get-Content -Raw -LiteralPath $rootPayloads["physical-freeze.json"] |
    ConvertFrom-Json -Depth 100
$attempt = Get-Content -Raw -LiteralPath $rootPayloads["attempt-authorization.json"] |
    ConvertFrom-Json -Depth 100
$authorization = Get-Content -Raw -LiteralPath (
    $rootPayloads["production-authorization-preflight.json"]
) | ConvertFrom-Json -Depth 100
$terminalPaths = @(Get-Content -Raw -LiteralPath (
    $rootPayloads["terminal-paths.json"]
) | ConvertFrom-Json)
$report = Get-Content -Raw -LiteralPath $rootPayloads["report.json"] |
    ConvertFrom-Json -Depth 100
$completion = Get-Content -Raw -LiteralPath $rootPayloads["completion.json"] |
    ConvertFrom-Json -Depth 100
$evaluation = $report.complete_evaluation

Assert-R23D48Closure (
    [string]$freeze.source_commit -ceq $sourceCommit -and
    @($freeze.source_bindings).Count -eq 116 -and
    [int]$freeze.source_raw_checkout_mismatch_count -eq 1 -and
    [int]$freeze.source_deterministic_projection_application_count -eq 1 -and
    [bool]$freeze.source_authority_bytes_equal_git_blobs_after_declared_projection -and
    [int]$freeze.declared_world_count -eq 9 -and
    [int]$freeze.zero_world_receipt.world_build_count -eq 0 -and
    [string]$attempt.attempt_id -ceq [string]$closure.attempt_id -and
    [bool]$attempt.one_shot_attempt_unconsumed -and
    @($authorization.ordered_receipts).Count -eq 9 -and
    [bool]$authorization.all_authorizations_passed -and
    [int]$authorization.world_build_count -eq 0 -and
    $terminalPaths.Count -eq 9
) "freeze, attempt, or authorization changed"

Assert-R23D48Closure (
    [string]$report.result_classification -ceq
        "invalid_or_incomplete_three_engine_portable_turning_validation" -and
    [string]$evaluation.classification -ceq [string]$report.result_classification -and
    [int]$evaluation.cell_count -eq 9 -and
    [bool]$evaluation.all_declared_cells_executed_or_retained_as_failures -and
    @($evaluation.cell_evaluations | Where-Object {
        [string]$_.engine_id -ceq "rapier_parry" -and
        [string]$_.entry_kind -ceq "worker_failure" -and
        -not [bool]$_.execution_valid -and
        [int]$_.world_attempt_count -eq 1 -and
        [int]$_.world_build_count -eq 1 -and
        (@($_.failed_gate_ids) -join "|") -like "*AuthorizationManager check failed*"
    }).Count -eq 3 -and
    @($evaluation.cell_evaluations | Where-Object {
        [string]$_.engine_id -in @("godot_jolt", "mujoco") -and
        [string]$_.entry_kind -ceq "report" -and
        [bool]$_.execution_valid -and
        [bool]$_.common_physical_gate_passed -and
        @($_.failed_gate_ids).Count -eq 0 -and
        [int]$_.world_attempt_count -eq 1 -and
        [int]$_.world_build_count -eq 1
    }).Count -eq 6 -and
    [string]$completion.status -ceq [string]$report.result_classification -and
    [int]$completion.cell_count -eq 9 -and
    [int]$completion.world_count -eq 9 -and
    [bool]$completion.one_shot_attempt_consumed -and
    -not [bool]$completion.replacement_or_selective_rerun_permitted
) "official attempt disposition changed"

for ($index = 0; $index -lt $report.ordered_cells.Count; $index++) {
    $cell = $report.ordered_cells[$index]
    Assert-R23D48Closure (
        [string]$terminalPaths[$index] -ceq
            [string]$cell.terminal_entry_cas.payload_path
    ) "terminal manifest order changed: $index"
    $terminalPayload = Assert-Cas (
        [string]$cell.terminal_entry_cas.sha256
    ) ([long]$cell.terminal_entry_cas.byte_length)
    $terminal = Get-Content -Raw -LiteralPath $terminalPayload |
        ConvertFrom-Json -Depth 100
    if ([string]$cell.engine_id -ceq "rapier_parry") {
        Assert-R23D48Closure (
            [string]$terminal.schema_version -ceq
                "sporespore_qsdk_r23d48_worker_failure_v1" -and
            [string]$terminal.failure_stage -ceq "settlement_complete" -and
            [string]$terminal.failure_code -like
                "*R23D34_TRACE_CAS_FAILED:1*AuthorizationManager check failed*" -and
            [int]$terminal.world_attempt_count -eq 1 -and
            [int]$terminal.world_build_count -eq 1 -and
            $null -eq $terminal.trace_artifact
        ) "Rapier terminal failure changed: $($cell.arm_id)"
    } else {
        $trace = $terminal.trace_artifact
        [void](Assert-Cas ([string]$trace.sha256) ([long]$trace.byte_length))
        Assert-R23D48Closure (
            [string]$terminal.schema_version -ceq
                "sporespore_qsdk_r23d48_engine_cell_report_v1" -and
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
        ) "valid engine terminal changed: $($cell.cell_id)"
    }
}

$godot = $evaluation.engine_results.godot_jolt
$mujoco = $evaluation.engine_results.mujoco
Assert-Near ([double]$godot.cycle_integrated_measurement.arms.reference_zero.cycle_shift_rad) `
    -0.19439639698736544 "Godot reference shift changed"
Assert-Near ([double]$godot.cycle_integrated_measurement.arms.positive_heading.cycle_shift_rad) `
    -0.04400865283714195 "Godot positive shift changed"
Assert-Near ([double]$godot.cycle_integrated_measurement.arms.negative_heading.cycle_shift_rad) `
    -0.41251512691045233 "Godot negative shift changed"
Assert-Near ([double]$godot.cycle_integrated_measurement.positive_reference_conditioned_cycle_shift_rad) `
    0.1503877441502235 "Godot conditioned positive changed"
Assert-Near ([double]$godot.cycle_integrated_measurement.negative_reference_conditioned_cycle_shift_rad) `
    0.2181187299230869 "Godot conditioned negative changed"
Assert-Near ([double]$mujoco.cycle_integrated_measurement.arms.reference_zero.cycle_shift_rad) `
    0.0006423365150168248 "MuJoCo reference shift changed"
Assert-Near ([double]$mujoco.cycle_integrated_measurement.arms.positive_heading.cycle_shift_rad) `
    0.1450251833104061 "MuJoCo positive shift changed"
Assert-Near ([double]$mujoco.cycle_integrated_measurement.arms.negative_heading.cycle_shift_rad) `
    -0.12972516704783205 "MuJoCo negative shift changed"
Assert-R23D48Closure (
    -not [bool]$godot.passed -and
    -not [bool]$godot.cycle_integrated_measurement.gates.raw_signed_cycle_shift -and
    [bool]$godot.cycle_integrated_measurement.gates.reference_conditioned_cycle_shift -and
    [bool]$mujoco.passed -and
    [bool]$mujoco.cycle_integrated_measurement.gates.raw_signed_cycle_shift -and
    [bool]$mujoco.cycle_integrated_measurement.gates.reference_conditioned_cycle_shift -and
    [bool]$evaluation.claims.mujoco_r23d29_turning -and
    -not [bool]$evaluation.claims.godot_jolt_r23d29_turning -and
    -not [bool]$evaluation.claims.rapier_parry_r23d29_turning -and
    -not [bool]$evaluation.claims.finite_three_engine_turning
) "engine-specific official interpretation changed"

$diagnostic = $closure.rapier_post_failure_diagnostic
$diagnosticSpecs = [ordered]@{
    reference_zero = $diagnostic.reference_zero_trace
    positive_heading = $diagnostic.positive_heading_trace
    negative_heading = $diagnostic.negative_heading_trace
}
$shifts = @{}
foreach ($entry in $diagnosticSpecs.GetEnumerator()) {
    $payload = Assert-Cas (
        [string]$entry.Value.sha256
    ) ([long]$entry.Value.byte_length)
    $cellId = (
        "rapier_parry__r23d29_support_loss_conditioned_turning_validation__" +
        [string]$entry.Key
    )
    $shifts[[string]$entry.Key] = Measure-DiagnosticRapierTrace `
        -Payload $payload -CellId $cellId -ArmId ([string]$entry.Key)
}
$positiveConditioned = [double]$shifts.positive_heading -
    [double]$shifts.reference_zero
$negativeConditioned = [double]$shifts.reference_zero -
    [double]$shifts.negative_heading
Assert-Near ([double]$shifts.reference_zero) `
    0.0025661495546947487 "diagnostic Rapier reference shift changed"
Assert-Near ([double]$shifts.positive_heading) `
    0.016544441316987724 "diagnostic Rapier positive shift changed"
Assert-Near ([double]$shifts.negative_heading) `
    -0.014735136859300405 "diagnostic Rapier negative shift changed"
Assert-Near $positiveConditioned `
    0.013978291762292976 "diagnostic Rapier conditioned positive changed"
Assert-Near $negativeConditioned `
    0.017301286413995153 "diagnostic Rapier conditioned negative changed"
Assert-R23D48Closure (
    [double]$shifts.positive_heading -ge 0.01 -and
    [double]$shifts.negative_heading -le -0.01 -and
    $positiveConditioned -ge 0.01 -and
    $negativeConditioned -ge 0.01 -and
    [string]$diagnostic.authority -ceq "post_failure_diagnostic_only" -and
    -not [bool]$diagnostic.may_be_promoted_to_official_result -and
    [bool]$diagnostic.trace_schema_validation_passed -and
    [bool]$diagnostic.published_to_content_addressed_storage_after_terminal_failure -and
    -not [bool]$diagnostic.creates_rapier_turning_claim
) "diagnostic Rapier boundary changed"

Assert-R23D48Closure (
    [string]$closure.diagnosis.defect_class -ceq
        "post_world_rapier_child_powershell_authorization_failure_during_trace_cas_publication" -and
    -not [bool]$closure.diagnosis.rapier_physics_or_controller_caused_execution_invalidity -and
    [bool]$closure.diagnosis.godot_turning_negative_is_independent_of_rapier_publication_failure -and
    [bool]$closure.diagnosis.post_failure_direct_powershell_publication_replay_passed -and
    [bool]$closure.diagnosis.post_failure_python_to_powershell_publication_replay_passed -and
    -not [bool]$closure.diagnosis.deeper_process_context_or_transient_policy_root_cause_proven -and
    [bool]$closure.claims.mujoco_seed_21512_finite_turning -and
    [bool]$closure.claims.godot_jolt_seed_21512_all_three_common_walking_gates_passed -and
    -not [bool]$closure.claims.godot_jolt_seed_21512_finite_turning -and
    -not [bool]$closure.claims.rapier_seed_21512_finite_turning -and
    -not [bool]$closure.claims.finite_three_engine_turning -and
    -not [bool]$closure.claims.portable_basic_turning -and
    -not [bool]$closure.claims.q_sdk_r23_satisfied -and
    -not [bool]$closure.claims.cross_engine_equivalence -and
    -not [bool]$closure.claims.release_authorized -and
    -not [bool]$closure.claims.physical_acceptance_authority
) "diagnosis or claim boundary changed"

$attemptDirectories = @(
    Get-ChildItem -LiteralPath $evidenceRoot -Directory |
        Where-Object {
            $_.Name -like "qsdk-r23d48-*" -and
            (Test-Path -LiteralPath (Join-Path $_.FullName "completion.json"))
        }
)
Assert-R23D48Closure (
    $attemptDirectories.Count -eq 1 -and
    $attemptDirectories[0].FullName -ceq $attemptRoot
) "R23D48 one-shot attempt count changed"

Write-Host (
    "QSDK_R23D48_CLOSURE_PASS classification=invalid_complete cells=9 worlds=9 " +
    "valid=6 rapier_failures=3 mujoco_turning=True godot_turning=False " +
    "rapier_diagnostic_turning=True official_three_engine=False rerun=False"
)
