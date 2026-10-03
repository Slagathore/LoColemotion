#requires -Version 7.0

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$closurePath = Join-Path $repoRoot (
    "sdk\turning\r23d40_three_engine_startup_ramp_turning_closure_v1.json"
)
$artifactRoot = Join-Path (
    "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence"
) "artifacts\sha256"
$sourceCommit = "f2c45811f3f945a088ee93f2d31b97d4a139df31"
$twoPi = 2.0 * [Math]::PI
$tolerance = 1.0e-12

function Assert-R23D40([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "QSDK-R23D40 CLOSURE: $Message" }
}

function Assert-Near(
    [double]$Actual,
    [double]$Expected,
    [double]$Tolerance,
    [string]$Message
) {
    Assert-R23D40 (
        [double]::IsFinite($Actual) -and [double]::IsFinite($Expected) -and
        [Math]::Abs($Actual - $Expected) -le $Tolerance
    ) $Message
}

function Assert-ArrayNear($Actual, $Expected, [double]$Tolerance, [string]$Message) {
    $actualValues = @($Actual)
    $expectedValues = @($Expected)
    Assert-R23D40 ($actualValues.Count -eq $expectedValues.Count) "$Message count"
    for ($index = 0; $index -lt $actualValues.Count; $index++) {
        Assert-Near ([double]$actualValues[$index]) ([double]$expectedValues[$index]) `
            $Tolerance "$Message index=$index"
    }
}

function Get-Sha256([string]$Path) {
    return "sha256:" + (
        Get-FileHash -LiteralPath $Path -Algorithm SHA256
    ).Hash.ToLowerInvariant()
}

function Assert-Cas([string]$Sha256, [long]$ByteLength) {
    Assert-R23D40 ($Sha256 -cmatch '^sha256:[0-9a-f]{64}$') (
        "invalid CAS digest: $Sha256"
    )
    $directory = Join-Path $artifactRoot $Sha256.Substring(7)
    $payload = Join-Path $directory "payload.bin"
    $manifestPath = Join-Path $directory "manifest.json"
    Assert-R23D40 (
        (Test-Path -LiteralPath $payload -PathType Leaf) -and
        (Test-Path -LiteralPath $manifestPath -PathType Leaf) -and
        (Get-Item -LiteralPath $payload).Length -eq $ByteLength -and
        (Get-Sha256 $payload) -ceq $Sha256
    ) "CAS payload changed: $Sha256"
    $manifest = Get-Content -Raw -LiteralPath $manifestPath |
        ConvertFrom-Json -Depth 20
    Assert-R23D40 (
        [string]$manifest.schema_version -ceq
            "sporespore_content_addressed_artifact_manifest_v1" -and
        [string]$manifest.sha256 -ceq $Sha256 -and
        [long]$manifest.byte_length -eq $ByteLength -and
        [string]$manifest.payload_name -ceq "payload.bin"
    ) "CAS manifest changed: $Sha256"
    return $payload
}

function Assert-Artifact($Record) {
    $path = [string]$Record.path
    Assert-R23D40 (
        (Test-Path -LiteralPath $path -PathType Leaf) -and
        (Get-Item -LiteralPath $path).Length -eq [long]$Record.byte_length -and
        (Get-Sha256 $path) -ceq [string]$Record.sha256
    ) "retained artifact changed: $path"
    $payload = Assert-Cas ([string]$Record.sha256) ([long]$Record.byte_length)
    Assert-R23D40 ((Get-Sha256 $payload) -ceq (Get-Sha256 $path)) (
        "retained artifact and CAS differ: $path"
    )
    return $payload
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
    Assert-R23D40 ($process.Start()) "failed to start git cat-file"
    $memory = [IO.MemoryStream]::new()
    try {
        $process.StandardOutput.BaseStream.CopyTo($memory)
        $stderr = $process.StandardError.ReadToEnd()
        $process.WaitForExit()
        Assert-R23D40 ($process.ExitCode -eq 0) (
            "historical blob is missing: $RelativePath; $stderr"
        )
        return ,([byte[]]$memory.ToArray())
    } finally {
        $memory.Dispose()
        $process.Dispose()
    }
}

function Get-BytesSha256([byte[]]$Bytes) {
    return "sha256:" + [Convert]::ToHexString(
        [Security.Cryptography.SHA256]::HashData($Bytes)
    ).ToLowerInvariant()
}

function Get-GitBlobOidFromBytes([byte[]]$Bytes) {
    $header = [Text.Encoding]::ASCII.GetBytes("blob $($Bytes.Length)")
    $payload = [byte[]]::new($header.Length + 1 + $Bytes.Length)
    [Buffer]::BlockCopy($header, 0, $payload, 0, $header.Length)
    $payload[$header.Length] = 0
    [Buffer]::BlockCopy($Bytes, 0, $payload, $header.Length + 1, $Bytes.Length)
    return [Convert]::ToHexString(
        [Security.Cryptography.SHA1]::HashData($payload)
    ).ToLowerInvariant()
}

function ConvertTo-LfProjectedBytes([byte[]]$Bytes) {
    $projected = [Collections.Generic.List[byte]]::new()
    for ($index = 0; $index -lt $Bytes.Length; $index++) {
        if ([int]$Bytes[$index] -ne 13) {
            $projected.Add($Bytes[$index])
            continue
        }
        Assert-R23D40 (
            $index + 1 -lt $Bytes.Length -and [int]$Bytes[$index + 1] -eq 10
        ) "projection encountered a bare CR byte"
        $projected.Add([byte]10)
        $index++
    }
    return ,([byte[]]$projected.ToArray())
}

function Get-WindowMean($Values, [int]$Start, [int]$End) {
    $sum = 0.0
    for ($index = $Start; $index -lt $End; $index++) {
        $sum += [double]$Values[$index]
    }
    return $sum / [double]($End - $Start)
}

$closure = Get-Content -Raw -LiteralPath $closurePath |
    ConvertFrom-Json -Depth 100
Assert-R23D40 (
    (git -C $repoRoot rev-parse --show-toplevel).Trim().Replace('/', '\') -ceq
        $repoRoot -and
    (git -C $repoRoot remote get-url origin).Trim() -ceq
        "https://github.com/Slagathore/sporespore.git" -and
    [string]$closure.schema_version -ceq
        "sporespore_qsdk_r23d40_three_engine_startup_ramp_turning_closure_v1" -and
    [string]$closure.status -ceq
        "closed_consumed_invalid_complete_rapier_godot_authorization_with_valid_mujoco_turning_positive" -and
    [string]$closure.campaign_id -ceq
        "QSDK-R23D40-THREE-ENGINE-STARTUP-RAMP-TURNING-VALIDATION" -and
    [string]$closure.gate_id -ceq "QSDK-R23D40" -and
    [string]$closure.source_commit -ceq $sourceCommit -and
    (git -C $repoRoot rev-parse "$($sourceCommit)^{tree}").Trim() -ceq
        [string]$closure.source_tree_git_oid -and
    [string]$closure.attempt_id -ceq "4f37875ec94943e7a7995b728703609a" -and
    [int]$closure.campaign_seed -eq 21508 -and
    [bool]$closure.identity_consumed -and
    -not [bool]$closure.same_identity_rerun_allowed -and
    -not [bool]$closure.selective_rerun_allowed -and
    [bool]$closure.fresh_held_out_condition_consumed
) "closure identity changed"

foreach ($name in @("preregistration", "implementation", "campaign_attestation_manifest")) {
    $relative = [string]$closure.prospective_inputs."$($name)_path"
    $expected = [string]$closure.prospective_inputs."$($name)_raw_sha256"
    $bytes = Get-GitBlobBytes $sourceCommit $relative
    Assert-R23D40 ((Get-BytesSha256 $bytes) -ceq $expected) (
        "pinned prospective input changed: $relative"
    )
}
Assert-R23D40 (
    -not [bool]$closure.prospective_inputs.controller_fixture_schedule_ramp_measurement_and_thresholds_changed_after_outcome
) "observed design was rewritten"

$attestationRecord = [pscustomobject]@{
    path = $closure.qualification.attestation_path
    sha256 = $closure.qualification.attestation_sha256
    byte_length = $closure.qualification.attestation_byte_length
}
$adoptionRecord = [pscustomobject]@{
    path = $closure.qualification.adoption_path
    sha256 = $closure.qualification.adoption_sha256
    byte_length = $closure.qualification.adoption_byte_length
}
[void](Assert-Artifact $attestationRecord)
[void](Assert-Artifact $adoptionRecord)
foreach ($name in @(
    "physical_freeze", "attempt_authorization", "terminal_manifest",
    "complete_evaluation", "report", "completion"
)) { [void](Assert-Artifact $closure.physical_evidence.$name) }

$attestation = Get-Content -Raw -LiteralPath ([string]$attestationRecord.path) |
    ConvertFrom-Json -Depth 100
$adoption = Get-Content -Raw -LiteralPath ([string]$adoptionRecord.path) |
    ConvertFrom-Json -Depth 100
Assert-R23D40 (
    [string]$attestation.source.commit -ceq $sourceCommit -and
    [string]$attestation.source.tree_git_oid -ceq [string]$closure.source_tree_git_oid -and
    [bool]$attestation.source.clean_pushed_live -and
    [int]$attestation.global_gate_count -eq 12 -and
    [int]$attestation.lineage_gate_count -eq 2 -and
    [int]$attestation.campaign_gate_count -eq 3 -and
    [int]$attestation.executed_gate_count -eq 17 -and
    [bool]$attestation.all_gates_executed -and
    [string]$adoption.source_commit -ceq $sourceCommit -and
    [int]$adoption.executed_gate_count -eq 17 -and
    [int]$adoption.gate_cas_object_count -eq 51 -and
    [bool]$adoption.physical_launch_prerequisite_satisfied -and
    -not [bool]$adoption.physical_acceptance_authority
) "qualification or adoption changed"

$freeze = Get-Content -Raw -LiteralPath (
    [string]$closure.physical_evidence.physical_freeze.path
) | ConvertFrom-Json -Depth 100
$attempt = Get-Content -Raw -LiteralPath (
    [string]$closure.physical_evidence.attempt_authorization.path
) | ConvertFrom-Json -Depth 100
$evaluation = Get-Content -Raw -LiteralPath (
    [string]$closure.physical_evidence.complete_evaluation.path
) | ConvertFrom-Json -Depth 100
$report = Get-Content -Raw -LiteralPath (
    [string]$closure.physical_evidence.report.path
) | ConvertFrom-Json -Depth 100
$completion = Get-Content -Raw -LiteralPath (
    [string]$closure.physical_evidence.completion.path
) | ConvertFrom-Json -Depth 100

$attemptFiles = @(Get-ChildItem -LiteralPath (
    [string]$closure.physical_evidence.attempt_root
) -Recurse -File)
Assert-R23D40 (
    $attemptFiles.Count -eq 39 -and
    [int]$closure.physical_evidence.complete_attempt_file_count -eq 39 -and
    [bool]$closure.physical_evidence.complete_attempt_files_content_addressed
) "complete attempt inventory changed"
foreach ($file in $attemptFiles) {
    [void](Assert-Cas (Get-Sha256 $file.FullName) ([long]$file.Length))
}

Assert-R23D40 (
    [string]$freeze.schema_version -ceq "sporespore_qsdk_r23d40_physical_freeze_v1" -and
    [string]$freeze.source_commit -ceq $sourceCommit -and
    [int]$freeze.declared_world_count -eq 9 -and
    [bool]$freeze.serial_execution_required -and
    [bool]$freeze.all_cells_run_regardless_of_intermediate_outcome -and
    [bool]$freeze.complete_zero_world_gate_passed -and
    [int]$freeze.zero_world_receipt.world_attempt_count -eq 0 -and
    [int]$freeze.zero_world_receipt.world_build_count -eq 0 -and
    [int]$freeze.zero_world_receipt.worker_preflight_count -eq 9 -and
    [int]$freeze.zero_world_receipt.source_binding_count -eq 116 -and
    [int]$freeze.source_raw_checkout_mismatch_count -eq 1 -and
    [int]$freeze.source_deterministic_projection_application_count -eq 1 -and
    -not [bool]$freeze.source_checkout_bytes_equal_git_blobs -and
    [bool]$freeze.source_authority_bytes_equal_git_blobs_after_declared_projection -and
    [bool]$freeze.reproducible_runtime_materialization_passed -and
    [bool]$freeze.physical_execution_authorized -and
    -not [bool]$freeze.physical_acceptance_authority -and
    @($freeze.source_bindings).Count -eq 116 -and
    @($freeze.content_addressed_inputs.source_bindings).Count -eq 116
) "physical freeze changed"

$projectionCount = 0
for ($index = 0; $index -lt 116; $index++) {
    $binding = $freeze.source_bindings[$index]
    $retained = $freeze.content_addressed_inputs.source_bindings[$index]
    $relative = [string]$binding.path
    $commitOid = (git -C $repoRoot rev-parse "$($sourceCommit):$relative").Trim()
    $payload = Assert-Cas ([string]$retained.sha256) ([long]$retained.byte_length)
    Assert-R23D40 (
        [string]$binding.git_blob_oid -ceq $commitOid -and
        [string]$binding.raw_sha256 -ceq [string]$retained.sha256 -and
        (Get-Sha256 $payload) -ceq [string]$binding.raw_sha256 -and
        [bool]$binding.authority_bytes_equal_git_blob_after_declared_projection
    ) "source binding changed: $relative"
    if ([bool]$binding.deterministic_projection_applied) {
        $projectionCount++
        $projected = ConvertTo-LfProjectedBytes ([IO.File]::ReadAllBytes($payload))
        Assert-R23D40 (
            $relative -ceq "sdk/adapters/rapier/src/conformance.rs" -and
            -not [bool]$binding.raw_checkout_equals_git_blob -and
            [string]$binding.deterministic_projection_id -ceq
                "crlf_pairs_to_lf_bytes_reject_bare_cr_v1" -and
            (Get-GitBlobOidFromBytes $projected) -ceq $commitOid -and
            [string]$binding.authority_git_blob_oid_after_declared_projection -ceq $commitOid
        ) "declared source projection changed"
    } else {
        Assert-R23D40 (
            [bool]$binding.raw_checkout_equals_git_blob -and
            (git -C $repoRoot hash-object --no-filters -- $payload).Trim() -ceq $commitOid
        ) "unprojected source bytes differ from Git blob: $relative"
    }
}
Assert-R23D40 ($projectionCount -eq 1) "source projection count changed"

$core = @($freeze.runtime_artifacts | Where-Object name -eq "locomotion_core_release")
$godot = @($freeze.runtime_artifacts | Where-Object name -eq "godot_adapter_debug")
$rapier = @($freeze.runtime_artifacts | Where-Object name -eq "rapier_r23d40_release_worker")
Assert-R23D40 (
    $core.Count -eq 1 -and $godot.Count -eq 1 -and $rapier.Count -eq 1 -and
    [string]$core[0].raw_sha256 -ceq [string]$closure.physical_evidence.locomotion_core_release_sha256 -and
    [string]$godot[0].raw_sha256 -ceq [string]$closure.physical_evidence.godot_adapter_debug_sha256 -and
    [string]$rapier[0].raw_sha256 -ceq [string]$closure.physical_evidence.rapier_worker_release_sha256 -and
    @($freeze.content_addressed_inputs.runtime_bindings).Count -eq 6
) "runtime bindings changed"
foreach ($runtime in @($freeze.content_addressed_inputs.runtime_bindings)) {
    [void](Assert-Cas ([string]$runtime.sha256) ([long]$runtime.byte_length))
}

Assert-R23D40 (
    [string]$attempt.schema_version -ceq "sporespore_qsdk_r23d40_attempt_v1" -and
    [string]$attempt.attempt_id -ceq [string]$closure.attempt_id -and
    [string]$attempt.source_commit -ceq $sourceCommit -and
    @($attempt.ordered_matrix_cell_ids).Count -eq 9 -and
    [bool]$attempt.single_use_supervisor_authorization -and
    [bool]$attempt.source_worktree_clean -and
    [bool]$attempt.source_matches_live_github_main -and
    [bool]$attempt.operation_lock_held -and
    [bool]$attempt.campaign_attestation_adoption_valid -and
    [bool]$attempt.content_addressed_inputs_retained -and
    [bool]$attempt.one_shot_attempt_unconsumed -and
    [bool]$attempt.all_cells_run_regardless_of_intermediate_outcome -and
    [bool]$attempt.physical_execution_authorized -and
    -not [bool]$attempt.physical_acceptance_authority -and
    @($attempt.PSObject.Properties.Name) -cnotcontains
        "matrix_authorization_immutable_before_first_world"
) "attempt authorization or exposed Rapier schema mismatch changed"

$rapierSource = [Text.UTF8Encoding]::new($false, $true).GetString((
    Get-GitBlobBytes $sourceCommit (
        "sdk/adapters/rapier/src/qsdk_r23d3_phase_balanced/r23d27_physical.rs"
    )
))
$godotSource = [Text.UTF8Encoding]::new($false, $true).GetString((
    Get-GitBlobBytes $sourceCommit (
        "tests/test_sdk_qsdk_r23d40_godot_jolt_physical_worker.gd"
    )
))
$supervisorSource = [Text.UTF8Encoding]::new($false, $true).GetString((
    Get-GitBlobBytes $sourceCommit "sdk/run_qsdk_r23d40_supervisor.ps1"
))
Assert-R23D40 (
    $rapierSource.Contains(
        'attempt["matrix_authorization_immutable_before_first_world"] == true'
    ) -and
    -not $supervisorSource.Contains(
        'matrix_authorization_immutable_before_first_world = $true'
    ) -and
    $godotSource.Contains(
        'for arm_id in ["reference_zero", "positive_heading", "negative_heading"]:'
    ) -and
    $godotSource.Contains(
        'attempt.get("ordered_matrix_cell_ids", []) == expected_cells'
    )
) "independent authorization-failure mechanism changed"

$manifest = Get-Content -Raw -LiteralPath (
    [string]$closure.physical_evidence.terminal_manifest.path
) | ConvertFrom-Json -NoEnumerate -Depth 20
Assert-R23D40 (
    $manifest -is [Array] -and @($manifest).Count -eq 9 -and
    @($report.ordered_cells).Count -eq 9 -and
    @($evaluation.cell_evaluations).Count -eq 9 -and
    [string]$report.result_classification -ceq
        "invalid_or_incomplete_three_engine_portable_turning_validation" -and
    [string]$evaluation.classification -ceq [string]$report.result_classification -and
    [string]$completion.status -ceq [string]$report.result_classification -and
    [int]$completion.cell_count -eq 9 -and [int]$completion.world_count -eq 3 -and
    [bool]$completion.one_shot_attempt_consumed -and
    -not [bool]$completion.replacement_or_selective_rerun_permitted
) "evaluation, report, or completion changed"

$measurementsByArm = @{}
$totalRows = 0
$totalCommands = 0
$totalApplications = 0
foreach ($expected in @($closure.ordered_cells)) {
    $cellId = [string]$expected.cell_id
    $reportCell = @($report.ordered_cells | Where-Object cell_id -CEQ $cellId)
    $evaluatedCell = @($evaluation.cell_evaluations | Where-Object cell_id -CEQ $cellId)
    Assert-R23D40 ($reportCell.Count -eq 1 -and $evaluatedCell.Count -eq 1) (
        "cell missing or duplicated: $cellId"
    )
    $terminalPath = Assert-Cas (
        [string]$expected.terminal_sha256
    ) ([long]$expected.terminal_byte_length)
    $terminal = Get-Content -Raw -LiteralPath $terminalPath |
        ConvertFrom-Json -Depth 100
    Assert-R23D40 (
        [string]$reportCell[0].terminal_entry_cas.sha256 -ceq
            [string]$expected.terminal_sha256 -and
        [string]$terminal.source_commit -ceq $sourceCommit -and
        [string]$terminal.cell_id -ceq $cellId -and
        [string]$terminal.engine_id -ceq [string]$expected.engine_id -and
        [string]$terminal.arm_id -ceq [string]$expected.arm_id
    ) "terminal identity changed: $cellId"
    if ([string]$expected.entry_kind -ceq "worker_failure") {
        Assert-R23D40 (
            [string]$terminal.schema_version -ceq
                "sporespore_qsdk_r23d40_worker_failure_v1" -and
            [string]$terminal.failure_code -ceq [string]$expected.failure_code -and
            [string]$terminal.failure_stage -ceq "before_world" -and
            [int]$terminal.world_attempt_count -eq 0 -and
            [int]$terminal.world_build_count -eq 0 -and
            -not [bool]$evaluatedCell[0].execution_valid -and
            -not [bool]$evaluatedCell[0].common_physical_gate_passed -and
            @($evaluatedCell[0].failed_gate_ids).Count -eq 1
        ) "pre-world refusal changed: $cellId"
        continue
    }
    $armId = [string]$expected.arm_id
    Assert-R23D40 (
        [string]$terminal.schema_version -ceq
            "sporespore_qsdk_r23d40_engine_cell_report_v1" -and
        [bool]$terminal.execution.integrity_passed -and
        [int]$terminal.execution.world_attempt_count -eq 1 -and
        [int]$terminal.execution.world_build_count -eq 1 -and
        [int]$terminal.execution.controller_semantic_step_count -eq 2992 -and
        [int]$terminal.execution.validated_portable_command_count -eq 23936 -and
        [int]$terminal.execution.native_actuation_application_count -eq 23936 -and
        [bool]$terminal.execution.trace_retained_before_terminal_entry -and
        [bool]$terminal.execution.startup_ramp_composition_integrity_passed -and
        [string]$terminal.execution.worker_failure_code -ceq "" -and
        [int]$terminal.measurements.controller_error_count -eq 0 -and
        [int]$terminal.measurements.safe_no_actuation_count -eq 0 -and
        [int]$terminal.measurements.nonfinite_observation_count -eq 0 -and
        [int]$terminal.measurements.actuator_application_mismatch_count -eq 0 -and
        [bool]$evaluatedCell[0].execution_valid -and
        [bool]$evaluatedCell[0].common_physical_gate_passed
    ) "MuJoCo execution changed: $armId"
    Assert-R23D40 (
        [double]$terminal.measurements.final_forward_displacement_m -ge 0.030123046875 -and
        [double]$terminal.measurements.maximum_tilt_rad -le 0.6 -and
        [double]$terminal.measurements.minimum_torso_height_m -ge 0.2499708652072946 -and
        [int]$terminal.measurements.torso_ground_contact_step_count -eq 0 -and
        [int]$terminal.measurements.contact_cycle_count_by_limb.front_left -ge 2 -and
        [int]$terminal.measurements.contact_cycle_count_by_limb.front_right -ge 2 -and
        [int]$terminal.measurements.contact_cycle_count_by_limb.rear_left -ge 2 -and
        [int]$terminal.measurements.contact_cycle_count_by_limb.rear_right -ge 2
    ) "MuJoCo walking gate no longer passes: $armId"

    $tracePath = Assert-Cas (
        [string]$expected.trace_sha256
    ) ([long]$expected.trace_byte_length)
    $traceLines = @(Get-Content -LiteralPath $tracePath)
    Assert-R23D40 ($traceLines.Count -eq 2992) "trace row count changed: $armId"
    $unwrappedYaw = [Collections.Generic.List[double]]::new()
    $previousRawYaw = 0.0
    $previousUnwrappedYaw = 0.0
    $maximumTilt = 0.0
    $minimumHeight = [double]::PositiveInfinity
    $torsoContacts = 0
    $activeRampRows = 0
    $cycles = @{front_left = 0; front_right = 0; rear_left = 0; rear_right = 0}
    $previous = @{front_left = $true; front_right = $true; rear_left = $true; rear_right = $true}
    $turnOffset = [double]$terminal.turn_heading_offset_rad
    for ($rowIndex = 0; $rowIndex -lt $traceLines.Count; $rowIndex++) {
        $row = $traceLines[$rowIndex] | ConvertFrom-Json -Depth 30
        $segment = if ($rowIndex -lt 600) { "reference_warmup" } elseif (
            $rowIndex -lt 1800
        ) { "commanded_turn" } elseif ($rowIndex -lt 2400) {
            "reference_recovery"
        } else { "after_declared_schedule" }
        $offset = if ($segment -ceq "commanded_turn") { $turnOffset } else { 0.0 }
        $scale = if ($rowIndex -ge 359) { 1.0 } else {
            $progress = $rowIndex / 359.0
            $progress * $progress * (3.0 - 2.0 * $progress)
        }
        $yaw = [double]$row.measured_yaw_rad
        Assert-R23D40 (
            [string]$row.schema_version -ceq
                "sporespore_qsdk_r23d40_turning_trace_row_v1" -and
            [string]$row.cell_id -ceq $cellId -and
            [int]$row.semantic_step -eq $rowIndex -and
            [string]$row.segment_id -ceq $segment -and
            [double]$row.desired_heading_offset_rad -eq $offset -and
            [int]$row.validated_portable_command_count -eq 8 -and
            [int]$row.native_actuation_application_count -eq 8 -and
            [bool]$row.oracle_passed -and
            [string]$row.startup_ramp_id -ceq
                "canonical_velocity_smoothstep_one_gait_cycle_v1" -and
            [Math]::Abs([double]$row.startup_velocity_scale - $scale) -le 1.0e-15 -and
            [bool]$row.startup_ramp_active -eq ($scale -lt 1.0) -and
            [int]$row.startup_ramp_residual_count -eq 8 -and
            [double]::IsFinite($yaw)
        ) "trace, schedule, or ramp changed: $armId/$rowIndex"
        if ($rowIndex -eq 0) {
            $previousRawYaw = $yaw
            $previousUnwrappedYaw = $yaw
            $unwrappedYaw.Add($yaw)
        } else {
            $delta = [Math]::IEEERemainder($yaw - $previousRawYaw, $twoPi)
            Assert-R23D40 (
                [double]::IsFinite($delta) -and
                [Math]::Abs([Math]::Abs($delta) - [Math]::PI) -gt $tolerance
            ) "ambiguous yaw unwrap: $armId/$rowIndex"
            $previousUnwrappedYaw += $delta
            $unwrappedYaw.Add($previousUnwrappedYaw)
            $previousRawYaw = $yaw
        }
        $maximumTilt = [Math]::Max($maximumTilt, [double]$row.torso_tilt_rad)
        $minimumHeight = [Math]::Min($minimumHeight, [double]$row.torso_height_m)
        $torsoContacts += [int][bool]$row.torso_ground_contact
        $activeRampRows += [int]($scale -lt 1.0)
        if ($rowIndex -ge 472) {
            foreach ($limb in @("front_left", "front_right", "rear_left", "rear_right")) {
                $present = [bool]$row.ordered_foot_contacts_after.$limb
                if (-not $previous[$limb] -and $present) { $cycles[$limb]++ }
                $previous[$limb] = $present
            }
        }
    }
    Assert-R23D40 (
        [Math]::Abs([double]$terminal.measurements.maximum_tilt_rad - $maximumTilt) -le 1.0e-5 -and
        [Math]::Abs([double]$terminal.measurements.minimum_torso_height_m - $minimumHeight) -le 1.0e-5 -and
        $torsoContacts -eq 0 -and $activeRampRows -eq 359 -and
        $cycles.front_left -eq [int]$terminal.measurements.contact_cycle_count_by_limb.front_left -and
        $cycles.front_right -eq [int]$terminal.measurements.contact_cycle_count_by_limb.front_right -and
        $cycles.rear_left -eq [int]$terminal.measurements.contact_cycle_count_by_limb.rear_left -and
        $cycles.rear_right -eq [int]$terminal.measurements.contact_cycle_count_by_limb.rear_right
    ) "trace-derived physical envelope changed: $armId"
    $baselineMean = Get-WindowMean $unwrappedYaw 240 600
    $terminalMean = Get-WindowMean $unwrappedYaw 1440 1800
    $swingShifts = [Collections.Generic.List[double]]::new()
    for ($swing = 0; $swing -lt 5; $swing++) {
        $start = 1440 + $swing * 72
        $swingShifts.Add((Get-WindowMean $unwrappedYaw $start ($start + 72)) - $baselineMean)
    }
    $measurementsByArm[$armId] = [ordered]@{
        cycle_shift_rad = $terminalMean - $baselineMean
        terminal_swing_shift_rad = @($swingShifts)
    }
    $totalRows += $traceLines.Count
    $totalCommands += [int]$terminal.execution.validated_portable_command_count
    $totalApplications += [int]$terminal.execution.native_actuation_application_count
}

$reported = $evaluation.engine_results.mujoco.cycle_integrated_measurement
$reference = $measurementsByArm.reference_zero
$positive = $measurementsByArm.positive_heading
$negative = $measurementsByArm.negative_heading
$positiveConditioned = [double]$positive.cycle_shift_rad - [double]$reference.cycle_shift_rad
$negativeConditioned = [double]$reference.cycle_shift_rad - [double]$negative.cycle_shift_rad
for ($index = 0; $index -lt 5; $index++) {
    Assert-Near (
        [double]$positive.terminal_swing_shift_rad[$index] -
            [double]$reference.terminal_swing_shift_rad[$index]
    ) ([double]$reported.positive_terminal_swing_conditioned_shift_rad[$index]) `
        $tolerance "positive conditioned swing changed: $index"
    Assert-Near (
        [double]$reference.terminal_swing_shift_rad[$index] -
            [double]$negative.terminal_swing_shift_rad[$index]
    ) ([double]$reported.negative_terminal_swing_conditioned_shift_rad[$index]) `
        $tolerance "negative conditioned swing changed: $index"
}
foreach ($armId in @("reference_zero", "positive_heading", "negative_heading")) {
    Assert-Near ([double]$measurementsByArm[$armId].cycle_shift_rad) (
        [double]$reported.arms.$armId.cycle_shift_rad
    ) $tolerance "reported cycle shift changed: $armId"
    Assert-ArrayNear $measurementsByArm[$armId].terminal_swing_shift_rad (
        $reported.arms.$armId.terminal_swing_shift_rad
    ) $tolerance "reported swing shifts changed: $armId"
}
Assert-Near $positiveConditioned (
    [double]$reported.positive_reference_conditioned_cycle_shift_rad
) $tolerance "positive conditioned shift changed"
Assert-Near $negativeConditioned (
    [double]$reported.negative_reference_conditioned_cycle_shift_rad
) $tolerance "negative conditioned shift changed"
Assert-Near ($positiveConditioned + $negativeConditioned) (
    [double]$reported.bilateral_reference_conditioned_cycle_separation_rad
) $tolerance "bilateral separation changed"
Assert-R23D40 (
    [double]$positive.cycle_shift_rad -ge 0.01 -and
    [double]$negative.cycle_shift_rad -le -0.01 -and
    $positiveConditioned -ge 0.01 -and $negativeConditioned -ge 0.01 -and
    [bool]$reported.gates.raw_signed_cycle_shift -and
    [bool]$reported.gates.reference_conditioned_cycle_shift -and
    [bool]$reported.passed -and
    [bool]$evaluation.engine_results.mujoco.passed -and
    -not [bool]$evaluation.engine_results.rapier_parry.passed -and
    -not [bool]$evaluation.engine_results.godot_jolt.passed -and
    $totalRows -eq 8976 -and $totalCommands -eq 71808 -and
    $totalApplications -eq 71808
) "independent MuJoCo measurement or totals changed"

Assert-R23D40 (
    [string]$closure.attempt_summary.result_classification -ceq
        "invalid_or_incomplete_three_engine_portable_turning_validation" -and
    [int]$closure.attempt_summary.worker_failure_count -eq 6 -and
    [int]$closure.physical_evidence.observed_world_attempt_count -eq 3 -and
    [int]$closure.physical_evidence.observed_world_build_count -eq 3 -and
    [bool]$closure.mujoco_finite_positive.finite_mujoco_seed_21508_walking_and_turning_positive -and
    -not [bool]$closure.mujoco_finite_positive.repairs_or_substitutes_for_missing_rapier_or_godot_cells -and
    -not [bool]$closure.claims.r23d40_three_engine_validation -and
    -not [bool]$closure.claims.rapier_parry_seed_21508_walking_or_turning -and
    -not [bool]$closure.claims.godot_jolt_seed_21508_walking_or_turning -and
    [bool]$closure.claims.mujoco_seed_21508_walking_and_turning -and
    -not [bool]$closure.claims.finite_three_engine_turning -and
    -not [bool]$closure.claims.portable_basic_turning -and
    -not [bool]$closure.claims.q_sdk_r23_satisfied -and
    -not [bool]$closure.claims.cross_engine_equivalence -and
    -not [bool]$closure.claims.population_robustness -and
    -not [bool]$closure.claims.prone_to_standing -and
    -not [bool]$closure.claims.release_authorized -and
    -not [bool]$closure.claims.physical_acceptance_authority
) "bounded interpretation or claims changed"

Write-Output (
    "QSDK_R23D40_CLOSURE_PASS classification=implementation_invalid " +
    "cells=9 physical_worlds=3 preworld_refusals=6 rows=$totalRows " +
    "commands=$totalCommands positive_conditioned=$positiveConditioned " +
    "negative_conditioned=$negativeConditioned " +
    "mujoco_seed_21508_turning=True three_engine=False rerun=False"
)
