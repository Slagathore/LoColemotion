#requires -Version 7.0

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$sdkRoot = [IO.Path]::GetFullPath($PSScriptRoot)
$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $sdkRoot))
$closurePath = Join-Path $sdkRoot (
    "turning\r23d73_mujoco_selected_profile_positive_turn_development_closure_v1.json"
)
$mujocoRoot = Join-Path $sdkRoot "adapters\mujoco"
$turningRoot = Join-Path $sdkRoot "turning"
$pythonHost = Join-Path $mujocoRoot ".venv\Scripts\python.exe"
$supervisorPath = Join-Path $sdkRoot "run_qsdk_r23d73_supervisor.ps1"
$r72ClosureAuditPath = Join-Path $sdkRoot (
    "audit_r23d72_mujoco_preturn_startup_development_closure.ps1"
)
$originParityAuditPath = Join-Path $sdkRoot (
    "audit_forward_displacement_measurement_origin_parity_v1.ps1"
)
$expectedRepoRoot = "C:\Users\Cole\CodeStuff\games\SporeSpore"
$expectedRemote = "https://github.com/Slagathore/sporespore.git"
$sourceCommit = "08a217c71622546dff2c4e9e74abb95c5aaebbfe"
$tolerance = 1.0e-12
$exactTolerance = 1.0e-14

function Assert-R23D73Closure([bool]$Condition, [string]$Message) {
    if (-not $Condition) {
        throw "[turning/mujoco] R23D73 closure audit: $Message"
    }
}

function Get-R23D73ClosureSha256([string]$Path) {
    return "sha256:" + (
        Get-FileHash -LiteralPath $Path -Algorithm SHA256
    ).Hash.ToLowerInvariant()
}

function Get-R23D73GitBlobRawSha256([string]$Commit, [string]$RelativePath) {
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
    try {
        Assert-R23D73Closure $process.Start() "could not start Git blob reader"
        $stderrTask = $process.StandardError.ReadToEndAsync()
        $hasher = [Security.Cryptography.SHA256]::Create()
        try { $digest = $hasher.ComputeHash($process.StandardOutput.BaseStream) }
        finally { $hasher.Dispose() }
        $process.WaitForExit()
        $stderr = $stderrTask.GetAwaiter().GetResult()
        Assert-R23D73Closure ($process.ExitCode -eq 0) (
            "Git blob read failed for $RelativePath`: $stderr"
        )
        return "sha256:" + [Convert]::ToHexString($digest).ToLowerInvariant()
    } finally { $process.Dispose() }
}

function Read-R23D73Json([string]$Path) {
    return Get-Content -Raw -LiteralPath $Path |
        ConvertFrom-Json -AsHashtable -Depth 100
}

function Invoke-R23D73ClosureProcess([string]$FileName, [string[]]$Arguments) {
    $lines = @(& $FileName @Arguments 2>&1)
    $exitCode = $LASTEXITCODE
    Assert-R23D73Closure ($exitCode -eq 0) (
        "$FileName failed with exit $exitCode`: $($lines -join ' ')"
    )
    return $lines
}

function Test-R23D73ClosureShape([hashtable]$Value) {
    return (
        [string]$Value.schema_version -ceq
            "sporespore_qsdk_r23d73_mujoco_selected_profile_positive_turn_development_closure_v1" -and
        [string]$Value.campaign_id -ceq
            "QSDK-R23D73-MUJOCO-SELECTED-PROFILE-POSITIVE-TURN-DEVELOPMENT" -and
        [string]$Value.gate_id -ceq "QSDK-R23D73" -and
        [string]$Value.status -ceq
            "closed_valid_complete_positive_turn_development" -and
        [string]$Value.question_class -ceq "development" -and
        [string]$Value.source.commit -ceq $sourceCommit -and
        [string]$Value.evidence.root -ceq
            "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence\qsdk-r23d73-positive-turn-20260826T091337Z-08a217c7-56f4f573" -and
        [int]$Value.evidence.file_count -eq 13 -and
        [long]$Value.evidence.total_byte_length -eq 34449115 -and
        [string]$Value.execution.classification -ceq
            "valid_complete_positive_turn_development" -and
        [int]$Value.execution.controller_semantic_step_count -eq 2992 -and
        [int]$Value.execution.trace_row_count -eq 2992 -and
        [int]$Value.fixture.commanded_turn_step_count -eq 1200 -and
        [bool]$Value.fixture.turning_tested -and
        [bool]$Value.common_physical_gate_vector.all_passed -and
        @($Value.common_physical_gate_vector.failure_ids).Count -eq 0 -and
        [double]$Value.directional_measurement.minimum_raw_signed_cycle_shift_rad -eq 0.01 -and
        [double]$Value.directional_measurement.observed_raw_signed_cycle_shift_rad -eq
            0.14718188227060067 -and
        [bool]$Value.directional_measurement.raw_signed_cycle_shift_gate_passed -and
        -not [bool]$Value.directional_measurement.reference_conditioned_gate_evaluated -and
        -not [bool]$Value.directional_measurement.bilateral_directional_response_evaluated -and
        [bool]$Value.claims.exact_mujoco_positive_heading_turning_cell_established -and
        [bool]$Value.claims.positive_heading_turning_cell_established -and
        -not [bool]$Value.claims.turning_established -and
        -not [bool]$Value.claims.portable_basic_turning -and
        -not [bool]$Value.claims.cross_engine_equivalence -and
        [bool]$Value.claims.fresh_finite_three_engine_turning_decision_may_be_authored -and
        -not [bool]$Value.claims.fresh_finite_three_engine_turning_decision_physical_execution_authorized -and
        -not [bool]$Value.claims.release_readiness_score_changed -and
        [string]$Value.claims.release_score_before -ceq "10/25" -and
        [string]$Value.claims.release_score_after -ceq "10/25" -and
        -not [bool]$Value.claims.release_authorized
    )
}

$top = [IO.Path]::GetFullPath((git -C $repoRoot rev-parse --show-toplevel).Trim())
$remote = (git -C $repoRoot remote get-url origin).Trim()
Assert-R23D73Closure ($LASTEXITCODE -eq 0) "repository identity unreadable"
Assert-R23D73Closure ($top -ceq $expectedRepoRoot) "repository root mismatch"
Assert-R23D73Closure ($remote -ceq $expectedRemote) "origin mismatch"
foreach ($path in @(
    $closurePath,
    $pythonHost,
    $supervisorPath,
    $r72ClosureAuditPath,
    $originParityAuditPath
)) {
    Assert-R23D73Closure (Test-Path -LiteralPath $path -PathType Leaf) (
        "required closure path missing: $path"
    )
}

$closure = Read-R23D73Json $closurePath
Assert-R23D73Closure (Test-R23D73ClosureShape $closure) (
    "closure identity, result, or claim boundary changed"
)
$observedTree = (git -C $repoRoot rev-parse "${sourceCommit}^{tree}").Trim()
Assert-R23D73Closure ($LASTEXITCODE -eq 0) "source tree unavailable"
Assert-R23D73Closure (
    $observedTree -ceq [string]$closure.source.tree_git_oid
) "source tree Git OID changed"

foreach ($binding in @(
    @([string]$closure.source.contract_path, [string]$closure.source.contract_raw_sha256),
    @([string]$closure.source.implementation_path, [string]$closure.source.implementation_raw_sha256),
    @([string]$closure.source.prospective_audit_path, [string]$closure.source.prospective_audit_raw_sha256),
    @([string]$closure.source.worker_path, [string]$closure.source.worker_raw_sha256),
    @([string]$closure.source.focused_test_path, [string]$closure.source.focused_test_raw_sha256),
    @([string]$closure.source.supervisor_path, [string]$closure.source.supervisor_raw_sha256)
)) {
    Assert-R23D73Closure (
        (Get-R23D73GitBlobRawSha256 $sourceCommit $binding[0]) -ceq $binding[1]
    ) "pinned source digest changed: $($binding[0])"
}

$evidenceRoot = [IO.Path]::GetFullPath([string]$closure.evidence.root)
Assert-R23D73Closure (Test-Path -LiteralPath $evidenceRoot -PathType Container) (
    "durable evidence root is missing"
)
$expectedInventory = @{}
foreach ($entry in @($closure.evidence.inventory)) {
    $expectedInventory[[string]$entry.path] = $entry
}
$observedFiles = @(
    Get-ChildItem -LiteralPath $evidenceRoot -Recurse -File | Sort-Object FullName
)
Assert-R23D73Closure ($observedFiles.Count -eq 13) "evidence file count changed"
[long]$totalBytes = 0
foreach ($file in $observedFiles) {
    $relative = $file.FullName.Substring($evidenceRoot.Length + 1).Replace("\", "/")
    Assert-R23D73Closure ($expectedInventory.ContainsKey($relative)) (
        "unexpected evidence file: $relative"
    )
    $entry = $expectedInventory[$relative]
    Assert-R23D73Closure (
        [long]$file.Length -eq [long]$entry.byte_length -and
        (Get-R23D73ClosureSha256 $file.FullName) -ceq [string]$entry.raw_sha256
    ) "evidence bytes changed: $relative"
    $totalBytes += $file.Length
}
Assert-R23D73Closure (
    $totalBytes -eq [long]$closure.evidence.total_byte_length
) "evidence total byte length changed"

$freezePath = Join-Path $evidenceRoot "physical-freeze.json"
$attemptPath = Join-Path $evidenceRoot "attempt-authorization.json"
$authorizationPath = Join-Path $evidenceRoot "authorization-preflight-receipt.json"
$zeroWorldPath = Join-Path $evidenceRoot "zero-world-receipt.json"
$terminalPath = Join-Path $evidenceRoot "terminal-report.json"
$completionPath = Join-Path $evidenceRoot "completion.json"
$tracePath = Join-Path $evidenceRoot (
    "traces\r23d73__mujoco__s23191__positive_heading__unconditional_startup_ramp.ndjson"
)
$freeze = Read-R23D73Json $freezePath
$attempt = Read-R23D73Json $attemptPath
$authorization = Read-R23D73Json $authorizationPath
$zeroWorld = Read-R23D73Json $zeroWorldPath
$terminal = Read-R23D73Json $terminalPath
$completion = Read-R23D73Json $completionPath

Assert-R23D73Closure (
    [string]$freeze.source_commit -ceq $sourceCommit -and
    [string]$freeze.origin_main_commit -ceq $sourceCommit -and
    [string]$freeze.live_github_main_commit -ceq $sourceCommit -and
    [bool]$freeze.source_worktree_clean -and
    [bool]$freeze.complete_zero_world_gate_passed -and
    [int]$freeze.declared_world_count -eq 1 -and
    [bool]$freeze.serial_execution_required -and
    [bool]$freeze.operation_lock.acquired -and
    [string]$freeze.operation_lock.role -ceq "physical" -and
    [bool]$freeze.physical_execution_authorized -and
    [bool]$freeze.physical_behavior_thresholds_applied -and
    [double]$freeze.primary_behavior_threshold.minimum_raw_signed_cycle_shift_rad -eq 0.01 -and
    [bool]$freeze.outcome_exposed_fixture -and
    [bool]$freeze.turning_tested
) "physical freeze changed"
Assert-R23D73Closure (@($freeze.source_bindings).Count -eq 9) (
    "physical source-binding population changed"
)
foreach ($binding in @($freeze.source_bindings)) {
    Assert-R23D73Closure (
        (Get-R23D73GitBlobRawSha256 $sourceCommit ([string]$binding.path)) -ceq
            [string]$binding.raw_sha256
    ) "physical source binding changed: $($binding.path)"
}
Assert-R23D73Closure (
    [string]$attempt.attempt_id -ceq [string]$closure.evidence.attempt_id -and
    [string]$attempt.source_commit -ceq $sourceCommit -and
    [string]$attempt.freeze_raw_sha256 -ceq (Get-R23D73ClosureSha256 $freezePath) -and
    [bool]$attempt.single_use_supervisor_authorization -and
    [bool]$attempt.operation_lock_held -and
    [bool]$attempt.one_shot_attempt_unconsumed -and
    [bool]$attempt.physical_execution_authorized
) "attempt authorization changed"
Assert-R23D73Closure (
    [bool]$authorization.authorization_passed -and
    [bool]$authorization.returned_before_model -and
    [int]$authorization.model_construction_count -eq 0 -and
    [int]$authorization.world_attempt_count -eq 0 -and
    [int]$authorization.world_build_count -eq 0
) "authorization preflight changed"
Assert-R23D73Closure (
    [bool]$zeroWorld.ok -and
    [int]$zeroWorld.fixed_controller_horizon_step_count -eq 2992 -and
    [int]$zeroWorld.commanded_turn_step_count -eq 1200 -and
    [double]$zeroWorld.turn_heading_offset_rad -eq 0.2 -and
    [int]$zeroWorld.negative_control_class_count -eq 5 -and
    [int]$zeroWorld.startup_ramp_ghost.synthetic_composition_count -eq 4 -and
    [bool]$zeroWorld.returned_before_mjmodel -and
    [int]$zeroWorld.model_construction_count -eq 0 -and
    [int]$zeroWorld.world_attempt_count -eq 0 -and
    [int]$zeroWorld.world_build_count -eq 0 -and
    [int]$zeroWorld.solver_step_count -eq 0 -and
    [bool]$zeroWorld.turning_tested
) "zero-world receipt changed"
Assert-R23D73Closure (
    [string]$completion.attempt_id -ceq [string]$closure.evidence.attempt_id -and
    [string]$completion.classification -ceq
        "valid_complete_positive_turn_development" -and
    [int]$completion.worker_exit_code -eq 0 -and
    [bool]$completion.one_shot_attempt_consumed -and
    [bool]$completion.retained_every_terminal_class -and
    [bool]$completion.turning_tested -and
    [string]$completion.freeze_raw_sha256 -ceq (Get-R23D73ClosureSha256 $freezePath) -and
    [string]$completion.attempt_authorization_raw_sha256 -ceq
        (Get-R23D73ClosureSha256 $attemptPath) -and
    [string]$completion.terminal_report_raw_sha256 -ceq
        (Get-R23D73ClosureSha256 $terminalPath)
) "completion receipt changed"

$cycle = $terminal.measurements.positive_cycle_integrated_measurement
$contacts = $terminal.measurements.contact_cycle_count_by_limb
Assert-R23D73Closure (
    [string]$terminal.classification -ceq
        "valid_complete_positive_turn_development" -and
    [string]$terminal.question_class -ceq "development" -and
    [bool]$terminal.outcome_exposed_fixture -and
    [bool]$terminal.turning_tested -and
    [bool]$terminal.execution.integrity_passed -and
    [int]$terminal.execution.controller_semantic_step_count -eq 2992 -and
    [int]$terminal.execution.validated_portable_command_count -eq 23936 -and
    [int]$terminal.execution.native_actuation_application_count -eq 23936 -and
    [int]$terminal.execution.portable_impulse_violation_count -eq 0 -and
    [int]$terminal.execution.world_attempt_count -eq 1 -and
    [int]$terminal.execution.world_build_count -eq 1 -and
    [int]$terminal.execution.startup_ramp_active_step_count -eq 359 -and
    [int]$terminal.execution.startup_ramp_exact_zero_scale_step_count -eq 1 -and
    [int]$terminal.execution.startup_ramp_exact_unity_scale_step_count -eq 2633 -and
    [bool]$terminal.execution.startup_ramp_composition_integrity_passed -and
    [bool]$terminal.execution.startup_transform_composition_integrity_passed -and
    [bool]$terminal.execution.runtime_capture_integrity_passed -and
    [int]$terminal.execution.task_frame_origin_reanchor_count -eq 3 -and
    [int]$terminal.execution.commanded_turn_step_count -eq 1200 -and
    [bool]$terminal.execution.turning_tested -and
    [int]$terminal.measurements.torso_ground_contact_step_count -eq 0 -and
    [int]$terminal.measurements.controller_error_count -eq 0 -and
    [int]$terminal.measurements.safe_no_actuation_count -eq 0 -and
    [int]$terminal.measurements.nonfinite_observation_count -eq 0 -and
    [int]$terminal.measurements.actuator_application_mismatch_count -eq 0 -and
    [int]$contacts.front_left -eq 23 -and
    [int]$contacts.front_right -eq 36 -and
    [int]$contacts.rear_left -eq 29 -and
    [int]$contacts.rear_right -eq 25 -and
    [bool]$terminal.measurements.common_physical_gates_passed -and
    @($terminal.measurements.common_physical_gate_failures).Count -eq 0 -and
    [bool]$terminal.measurements.raw_positive_cycle_shift_gate_passed -and
    [bool]$terminal.development_observation.criterion_passed -and
    [double]$terminal.development_observation.minimum_raw_signed_cycle_shift_rad -eq 0.01 -and
    -not [bool]$terminal.development_observation.reference_conditioned_gate_evaluated -and
    -not [bool]$terminal.development_observation.bilateral_turning_inference_allowed -and
    [string]$terminal.trace_artifact.sha256 -ceq
        [string]$closure.execution.trace_raw_sha256 -and
    [long]$terminal.trace_artifact.byte_length -eq
        [long]$closure.execution.trace_byte_length
) "terminal report changed"

Assert-R23D73Closure (
    [double]$terminal.measurements.final_forward_displacement_m -ge
        [double]$closure.common_physical_gate_vector.minimum_final_forward_displacement_m -and
    [double]$terminal.measurements.maximum_tilt_rad -le
        [double]$closure.common_physical_gate_vector.maximum_tilt_rad -and
    [double]$terminal.measurements.minimum_torso_height_m -ge
        [double]$closure.common_physical_gate_vector.minimum_torso_height_m -and
    [double]$cycle.cycle_shift_rad -ge
        [double]$closure.directional_measurement.minimum_raw_signed_cycle_shift_rad
) "prospective physical threshold conjunction changed"

$lineCount = 0
$groundCount = 0
$rampActiveCount = 0
$zeroScaleCount = 0
$unityScaleCount = 0
$reanchorSteps = @()
$minimumHeight = [double]::PositiveInfinity
$maximumTilt = 0.0
$minimumSupport = [int]::MaxValue
$yaw = [System.Collections.Generic.List[double]]::new()
$segmentCounts = @{
    reference_warmup = 0
    commanded_turn = 0
    reference_recovery = 0
    after_declared_schedule = 0
}
$contactCycles = @{
    front_left = 0
    front_right = 0
    rear_left = 0
    rear_right = 0
}
$previousContacts = $null
Get-Content -LiteralPath $tracePath | ForEach-Object {
    $row = $_ | ConvertFrom-Json -AsHashtable -Depth 100
    $step = $lineCount
    $expectedScale = if ($step -ge 359) {
        1.0
    } else {
        $progress = $step / 359.0
        $progress * $progress * (3.0 - 2.0 * $progress)
    }
    $expectedPhase = if ($step -lt 600) {
        "reference_warmup"
    } elseif ($step -lt 1800) {
        "commanded_turn"
    } elseif ($step -lt 2400) {
        "reference_recovery"
    } else {
        "reference_continuation"
    }
    $expectedSegment = if ($step -lt 2400) {
        $expectedPhase
    } else {
        "after_declared_schedule"
    }
    $expectedHeading = if ($step -ge 600 -and $step -lt 1800) { 0.2 } else { 0.0 }
    Assert-R23D73Closure (
        [string]$row.schema_version -ceq
            "sporespore_qsdk_r23d73_mujoco_positive_turn_trace_row_v1" -and
        [string]$row.campaign_id -ceq
            "QSDK-R23D73-MUJOCO-SELECTED-PROFILE-POSITIVE-TURN-DEVELOPMENT" -and
        [string]$row.gate_id -ceq "QSDK-R23D73" -and
        [string]$row.cell_id -ceq
            "r23d73__mujoco__s23191__positive_heading__unconditional_startup_ramp" -and
        [string]$row.engine_id -ceq "mujoco" -and
        [int]$row.campaign_seed -eq 23191 -and
        [int]$row.semantic_step -eq $step -and
        [int]$row.trace_step -eq $step -and
        [string]$row.phase_id -ceq $expectedPhase -and
        [string]$row.segment_id -ceq $expectedSegment -and
        [Math]::Abs([double]$row.desired_heading_offset_rad - $expectedHeading) -le
            $exactTolerance -and
        [string]$row.question_class -ceq "development" -and
        [bool]$row.outcome_exposed_fixture -and
        [bool]$row.turning_tested -and
        -not [bool]$row.physical_acceptance_authority -and
        [bool]$row.oracle_passed -and
        -not [bool]$row.torso_ground_contact -and
        [string]$row.startup_ramp_id -ceq
            "canonical_velocity_smoothstep_one_gait_cycle_v1" -and
        [Math]::Abs([double]$row.startup_velocity_scale - $expectedScale) -le
            $exactTolerance -and
        [int]$row.validated_portable_command_count -eq 8 -and
        [int]$row.native_actuation_application_count -eq 8 -and
        [double]::IsFinite([double]$row.measured_yaw_rad)
    ) "trace row invalid at semantic step $step"
    $segmentCounts[$expectedSegment] += 1
    $groundCount += [int][bool]$row.torso_ground_contact
    $rampActiveCount += [int]([double]$row.startup_velocity_scale -lt 1.0)
    $zeroScaleCount += [int]([double]$row.startup_velocity_scale -eq 0.0)
    $unityScaleCount += [int]([double]$row.startup_velocity_scale -eq 1.0)
    if ([bool]$row.task_frame_origin_reanchored_this_step) { $reanchorSteps += $step }
    $minimumHeight = [Math]::Min($minimumHeight, [double]$row.torso_height_m)
    $maximumTilt = [Math]::Max($maximumTilt, [double]$row.torso_tilt_rad)
    $minimumSupport = [Math]::Min($minimumSupport, [int]$row.observed_support_count)
    [void]$yaw.Add([double]$row.measured_yaw_rad)
    if ($step -eq 0) {
        $previousContacts = @{}
        foreach ($limb in @("front_left", "front_right", "rear_left", "rear_right")) {
            $previousContacts[$limb] = [bool]$row.ordered_foot_contacts_before[$limb]
        }
    }
    if ($step -ge 472) {
        foreach ($limb in @("front_left", "front_right", "rear_left", "rear_right")) {
            $present = [bool]$row.ordered_foot_contacts_after[$limb]
            if (-not [bool]$previousContacts[$limb] -and $present) {
                $contactCycles[$limb] += 1
            }
            $previousContacts[$limb] = $present
        }
    }
    $lineCount += 1
}
Assert-R23D73Closure (
    $lineCount -eq 2992 -and
    $groundCount -eq 0 -and
    $rampActiveCount -eq 359 -and
    $zeroScaleCount -eq 1 -and
    $unityScaleCount -eq 2633 -and
    $segmentCounts.reference_warmup -eq 600 -and
    $segmentCounts.commanded_turn -eq 1200 -and
    $segmentCounts.reference_recovery -eq 600 -and
    $segmentCounts.after_declared_schedule -eq 592 -and
    $reanchorSteps.Count -eq 3 -and
    $reanchorSteps[0] -eq 600 -and
    $reanchorSteps[1] -eq 1800 -and
    $reanchorSteps[2] -eq 2400 -and
    $minimumSupport -eq 1 -and
    $contactCycles.front_left -eq 23 -and
    $contactCycles.front_right -eq 36 -and
    $contactCycles.rear_left -eq 29 -and
    $contactCycles.rear_right -eq 25 -and
    [Math]::Abs($minimumHeight - 0.4221253419558551) -le $exactTolerance -and
    [Math]::Abs($maximumTilt - 0.08800670805139185) -le $exactTolerance
) "complete trace summary changed"

$unwrapped = [System.Collections.Generic.List[double]]::new()
[void]$unwrapped.Add($yaw[0])
$previousYaw = $yaw[0]
$twoPi = 2.0 * [Math]::PI
for ($index = 1; $index -lt $yaw.Count; $index += 1) {
    $delta = [Math]::IEEERemainder($yaw[$index] - $previousYaw, $twoPi)
    Assert-R23D73Closure (
        [double]::IsFinite($delta) -and
        [Math]::Abs([Math]::Abs($delta) - [Math]::PI) -gt 1.0e-12
    ) "yaw unwrap became ambiguous at semantic step $index"
    [void]$unwrapped.Add($unwrapped[$index - 1] + $delta)
    $previousYaw = $yaw[$index]
}
$baselineSum = 0.0
for ($index = 240; $index -lt 600; $index += 1) {
    $baselineSum += $unwrapped[$index]
}
$terminalSum = 0.0
for ($index = 1440; $index -lt 1800; $index += 1) {
    $terminalSum += $unwrapped[$index]
}
$baselineMean = $baselineSum / 360.0
$terminalMean = $terminalSum / 360.0
$cycleShift = $terminalMean - $baselineMean
$swingShifts = @()
for ($swingIndex = 0; $swingIndex -lt 5; $swingIndex += 1) {
    $swingSum = 0.0
    $start = 1440 + ($swingIndex * 72)
    for ($index = $start; $index -lt ($start + 72); $index += 1) {
        $swingSum += $unwrapped[$index]
    }
    $swingShifts += (($swingSum / 72.0) - $baselineMean)
}
$endpointDelta = [Math]::IEEERemainder($yaw[1799] - $yaw[600], $twoPi)
Assert-R23D73Closure (
    [Math]::Abs($baselineMean - [double]$cycle.baseline_cycle_mean_unwrapped_yaw_rad) -le
        $tolerance -and
    [Math]::Abs($terminalMean - [double]$cycle.terminal_cycle_mean_unwrapped_yaw_rad) -le
        $tolerance -and
    [Math]::Abs($cycleShift - [double]$cycle.cycle_shift_rad) -le $tolerance -and
    [Math]::Abs($cycleShift - 0.14718188227060067) -le $tolerance -and
    $cycleShift -ge 0.01 -and
    [Math]::Abs($endpointDelta - [double]$cycle.legacy_endpoint_yaw_delta_rad) -le
        $tolerance
) "cycle-integrated directional measurement changed"
for ($index = 0; $index -lt 5; $index += 1) {
    Assert-R23D73Closure (
        [Math]::Abs(
            $swingShifts[$index] - [double]$cycle.terminal_swing_shift_rad[$index]
        ) -le $tolerance
    ) "terminal swing measurement changed at index $index"
}

$mutationRejections = 0
foreach ($mutation in @(
    { param($value) $value.status = "closed_negative" },
    { param($value) $value.evidence.total_byte_length += 1 },
    { param($value) $value.execution.trace_row_count = 2991 },
    { param($value) $value.fixture.commanded_turn_step_count = 1199 },
    { param($value) $value.directional_measurement.observed_raw_signed_cycle_shift_rad = 0.0 },
    { param($value) $value.claims.positive_heading_turning_cell_established = $false },
    { param($value) $value.claims.turning_established = $true },
    { param($value) $value.claims.release_score_after = "11/25" }
)) {
    $candidate = $closure | ConvertTo-Json -Depth 100 |
        ConvertFrom-Json -AsHashtable -Depth 100
    & $mutation $candidate
    if (-not (Test-R23D73ClosureShape $candidate)) { $mutationRejections += 1 }
}
Assert-R23D73Closure ($mutationRejections -eq 8) (
    "closure mutation controls did not all reject"
)

$prospectiveReplay = @'
import pathlib
import sys
import unittest

from sporespore_mujoco_adapter import qsdk_r23d73_positive_turn_development as route

route.CLOSURE_PATH = pathlib.Path(
    r"C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence"
) / "__r23d73_prospective_replay_closure_must_not_exist__"
if route.CLOSURE_PATH.exists():
    raise SystemExit("prospective replay sentinel unexpectedly exists")
suite = unittest.defaultTestLoader.loadTestsFromName(
    "sdk.adapters.mujoco.test_r23d73_positive_turn_development"
)
result = unittest.TextTestRunner(verbosity=0).run(suite)
raise SystemExit(0 if result.wasSuccessful() else 1)
'@
$priorPythonPath = $env:PYTHONPATH
try {
    $env:PYTHONPATH = @(
        $mujocoRoot,
        (Join-Path $sdkRoot "python"),
        $turningRoot
    ) -join [IO.Path]::PathSeparator
    [void](Invoke-R23D73ClosureProcess $pythonHost @("-c", $prospectiveReplay))
} finally {
    $env:PYTHONPATH = $priorPythonPath
}
[void](Invoke-R23D73ClosureProcess "pwsh" @(
    "-NoProfile", "-File", $supervisorPath, "-PreflightOnly", "-Python", $pythonHost
))
[void](Invoke-R23D73ClosureProcess "pwsh" @(
    "-NoProfile", "-File", $r72ClosureAuditPath
))
[void](Invoke-R23D73ClosureProcess "pwsh" @(
    "-NoProfile", "-File", $originParityAuditPath
))

Write-Output (
    "[turning/mujoco] R23D73 closure PASS: 13 files, 34,449,115 bytes, " +
    "2,992/2,992 trace rows, raw cycle shift 0.14718188227060067 rad, " +
    "all common gates passed, 8/8 closure mutations rejected, " +
    "1 retained world, score 10/25"
)
