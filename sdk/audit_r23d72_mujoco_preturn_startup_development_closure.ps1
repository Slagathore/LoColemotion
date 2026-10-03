#requires -Version 7.0

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$sdkRoot = [IO.Path]::GetFullPath($PSScriptRoot)
$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $sdkRoot))
$closurePath = Join-Path $sdkRoot (
    "turning\r23d72_mujoco_selected_profile_preturn_startup_development_closure_v1.json"
)
$prospectiveAuditPath = Join-Path $sdkRoot (
    "audit_r23d72_mujoco_preturn_startup_development.ps1"
)
$mujocoRoot = Join-Path $sdkRoot "adapters\mujoco"
$turningRoot = Join-Path $sdkRoot "turning"
$pythonHost = Join-Path $mujocoRoot ".venv\Scripts\python.exe"
$supervisorPath = Join-Path $sdkRoot "run_qsdk_r23d72_supervisor.ps1"
$r42AuditPath = Join-Path $repoRoot "tests\test_qsdk_r23d42_closure.ps1"
$r71DiagnosisAuditPath = Join-Path $sdkRoot (
    "audit_r23d71_forward_displacement_measurement_origin_diagnosis.ps1"
)
$expectedRepoRoot = "C:\Users\Cole\CodeStuff\games\SporeSpore"
$expectedRemote = "https://github.com/Slagathore/sporespore.git"
$sourceCommit = "b35ea21d87459a4c33fc3f5c7105606f2da83d83"
$tolerance = 1.0e-14

function Assert-R23D72Closure([bool]$Condition, [string]$Message) {
    if (-not $Condition) {
        throw "[turning/mujoco] R23D72 closure audit: $Message"
    }
}

function Get-R23D72ClosureSha256([string]$Path) {
    return "sha256:" + (
        Get-FileHash -LiteralPath $Path -Algorithm SHA256
    ).Hash.ToLowerInvariant()
}

function Get-R23D72GitBlobRawSha256([string]$Commit, [string]$RelativePath) {
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
        Assert-R23D72Closure $process.Start() "could not start Git blob reader"
        $stderrTask = $process.StandardError.ReadToEndAsync()
        $hasher = [Security.Cryptography.SHA256]::Create()
        try { $digest = $hasher.ComputeHash($process.StandardOutput.BaseStream) }
        finally { $hasher.Dispose() }
        $process.WaitForExit()
        $stderr = $stderrTask.GetAwaiter().GetResult()
        Assert-R23D72Closure ($process.ExitCode -eq 0) (
            "Git blob read failed for $RelativePath`: $stderr"
        )
        return "sha256:" + [Convert]::ToHexString($digest).ToLowerInvariant()
    } finally { $process.Dispose() }
}

function Read-R23D72Json([string]$Path) {
    return Get-Content -Raw -LiteralPath $Path |
        ConvertFrom-Json -AsHashtable -Depth 100
}

function Invoke-R23D72ClosureProcess([string]$FileName, [string[]]$Arguments) {
    $lines = @(& $FileName @Arguments 2>&1)
    $exitCode = $LASTEXITCODE
    Assert-R23D72Closure ($exitCode -eq 0) (
        "$FileName failed with exit $exitCode`: $($lines -join ' ')"
    )
    return $lines
}

function Test-R23D72ClosureShape([hashtable]$Value) {
    return (
        [string]$Value.schema_version -ceq
            "sporespore_qsdk_r23d72_mujoco_selected_profile_preturn_startup_development_closure_v1" -and
        [string]$Value.campaign_id -ceq
            "QSDK-R23D72-MUJOCO-SELECTED-PROFILE-PRETURN-STARTUP-DEVELOPMENT" -and
        [string]$Value.gate_id -ceq "QSDK-R23D72" -and
        [string]$Value.status -ceq
            "closed_valid_complete_positive_preturn_startup_development" -and
        [string]$Value.question_class -ceq "development" -and
        [string]$Value.source.commit -ceq $sourceCommit -and
        [string]$Value.evidence.root -ceq
            "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence\qsdk-r23d72-preturn-20260826T084300Z-b35ea21d-55f51fa0" -and
        [int]$Value.evidence.file_count -eq 13 -and
        [long]$Value.evidence.total_byte_length -eq 6988899 -and
        [string]$Value.execution.classification -ceq
            "valid_complete_positive_preturn_startup_development" -and
        [int]$Value.execution.controller_semantic_step_count -eq 601 -and
        [int]$Value.execution.trace_row_count -eq 601 -and
        [int]$Value.fixture.commanded_turn_step_count -eq 0 -and
        -not [bool]$Value.fixture.turning_tested -and
        [int]$Value.measurements.observed_torso_ground_contact_step_count -eq 0 -and
        [bool]$Value.measurements.criterion_passed -and
        $null -eq $Value.measurements.first_torso_ground_contact_semantic_step -and
        [bool]$Value.claims.startup_ramp_prevented_pre_turn_torso_contact_on_exact_exposed_fixture -and
        -not [bool]$Value.claims.turning_established -and
        -not [bool]$Value.claims.cross_engine_equivalence -and
        -not [bool]$Value.claims.release_readiness_score_changed -and
        [string]$Value.claims.release_score_before -ceq "10/25" -and
        [string]$Value.claims.release_score_after -ceq "10/25" -and
        -not [bool]$Value.claims.release_authorized
    )
}

$top = [IO.Path]::GetFullPath((git -C $repoRoot rev-parse --show-toplevel).Trim())
$remote = (git -C $repoRoot remote get-url origin).Trim()
Assert-R23D72Closure ($LASTEXITCODE -eq 0) "repository identity unreadable"
Assert-R23D72Closure ($top -ceq $expectedRepoRoot) "repository root mismatch"
Assert-R23D72Closure ($remote -ceq $expectedRemote) "origin mismatch"
Assert-R23D72Closure (Test-Path -LiteralPath $closurePath -PathType Leaf) (
    "closure authority missing"
)
Assert-R23D72Closure (Test-Path -LiteralPath $prospectiveAuditPath -PathType Leaf) (
    "prospective audit missing"
)
foreach ($path in @(
    $pythonHost,
    $supervisorPath,
    $r42AuditPath,
    $r71DiagnosisAuditPath
)) {
    Assert-R23D72Closure (Test-Path -LiteralPath $path -PathType Leaf) (
        "required replay path missing: $path"
    )
}

$closure = Read-R23D72Json $closurePath
Assert-R23D72Closure (Test-R23D72ClosureShape $closure) (
    "closure identity, result, or claim boundary changed"
)
$observedTree = (git -C $repoRoot rev-parse "${sourceCommit}^{tree}").Trim()
Assert-R23D72Closure ($LASTEXITCODE -eq 0) "source tree unavailable"
Assert-R23D72Closure (
    $observedTree -ceq [string]$closure.source.tree_git_oid
) "source tree Git OID changed"

foreach ($binding in @(
    @([string]$closure.source.contract_path, [string]$closure.source.contract_raw_sha256),
    @([string]$closure.source.implementation_path, [string]$closure.source.implementation_raw_sha256),
    @([string]$closure.source.prospective_audit_path, [string]$closure.source.prospective_audit_raw_sha256),
    @([string]$closure.source.worker_path, [string]$closure.source.worker_raw_sha256),
    @([string]$closure.source.supervisor_path, [string]$closure.source.supervisor_raw_sha256)
)) {
    Assert-R23D72Closure (
        (Get-R23D72GitBlobRawSha256 $sourceCommit $binding[0]) -ceq $binding[1]
    ) "pinned source digest changed: $($binding[0])"
}

$evidenceRoot = [IO.Path]::GetFullPath([string]$closure.evidence.root)
Assert-R23D72Closure (Test-Path -LiteralPath $evidenceRoot -PathType Container) (
    "durable evidence root is missing"
)
$expectedInventory = @{}
foreach ($entry in @($closure.evidence.inventory)) {
    $expectedInventory[[string]$entry.path] = $entry
}
$observedFiles = @(
    Get-ChildItem -LiteralPath $evidenceRoot -Recurse -File | Sort-Object FullName
)
Assert-R23D72Closure ($observedFiles.Count -eq 13) "evidence file count changed"
[long]$totalBytes = 0
foreach ($file in $observedFiles) {
    $relative = $file.FullName.Substring($evidenceRoot.Length + 1).Replace("\", "/")
    Assert-R23D72Closure ($expectedInventory.ContainsKey($relative)) (
        "unexpected evidence file: $relative"
    )
    $entry = $expectedInventory[$relative]
    Assert-R23D72Closure (
        [long]$file.Length -eq [long]$entry.byte_length -and
        (Get-R23D72ClosureSha256 $file.FullName) -ceq [string]$entry.raw_sha256
    ) "evidence bytes changed: $relative"
    $totalBytes += $file.Length
}
Assert-R23D72Closure (
    $totalBytes -eq [long]$closure.evidence.total_byte_length
) "evidence total byte length changed"

$freezePath = Join-Path $evidenceRoot "physical-freeze.json"
$attemptPath = Join-Path $evidenceRoot "attempt-authorization.json"
$authorizationPath = Join-Path $evidenceRoot "authorization-preflight-receipt.json"
$zeroWorldPath = Join-Path $evidenceRoot "zero-world-receipt.json"
$terminalPath = Join-Path $evidenceRoot "terminal-report.json"
$completionPath = Join-Path $evidenceRoot "completion.json"
$tracePath = Join-Path $evidenceRoot (
    "traces\r23d72__mujoco__s23191__reference_zero__unconditional_startup_ramp.ndjson"
)
$freeze = Read-R23D72Json $freezePath
$attempt = Read-R23D72Json $attemptPath
$authorization = Read-R23D72Json $authorizationPath
$zeroWorld = Read-R23D72Json $zeroWorldPath
$terminal = Read-R23D72Json $terminalPath
$completion = Read-R23D72Json $completionPath

Assert-R23D72Closure (
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
    [bool]$freeze.outcome_exposed_fixture -and
    -not [bool]$freeze.turning_tested
) "physical freeze changed"
Assert-R23D72Closure (
    [string]$attempt.attempt_id -ceq [string]$closure.evidence.attempt_id -and
    [string]$attempt.source_commit -ceq $sourceCommit -and
    [string]$attempt.freeze_raw_sha256 -ceq (Get-R23D72ClosureSha256 $freezePath) -and
    [bool]$attempt.single_use_supervisor_authorization -and
    [bool]$attempt.operation_lock_held -and
    [bool]$attempt.one_shot_attempt_unconsumed -and
    [bool]$attempt.physical_execution_authorized
) "attempt authorization changed"
Assert-R23D72Closure (
    [bool]$authorization.authorization_passed -and
    [bool]$authorization.returned_before_model -and
    [int]$authorization.model_construction_count -eq 0 -and
    [int]$authorization.world_attempt_count -eq 0 -and
    [int]$authorization.world_build_count -eq 0
) "authorization preflight changed"
Assert-R23D72Closure (
    [bool]$zeroWorld.ok -and
    [int]$zeroWorld.fixed_controller_horizon_step_count -eq 601 -and
    [int]$zeroWorld.commanded_turn_step_count -eq 0 -and
    [int]$zeroWorld.negative_control_class_count -eq 5 -and
    [bool]$zeroWorld.returned_before_mjmodel -and
    [int]$zeroWorld.model_construction_count -eq 0 -and
    [int]$zeroWorld.world_attempt_count -eq 0 -and
    [int]$zeroWorld.world_build_count -eq 0 -and
    [int]$zeroWorld.solver_step_count -eq 0
) "zero-world receipt changed"
Assert-R23D72Closure (
    [string]$completion.attempt_id -ceq [string]$closure.evidence.attempt_id -and
    [string]$completion.classification -ceq
        "valid_complete_positive_preturn_startup_development" -and
    [int]$completion.worker_exit_code -eq 0 -and
    [bool]$completion.one_shot_attempt_consumed -and
    [bool]$completion.retained_every_terminal_class -and
    [string]$completion.freeze_raw_sha256 -ceq (Get-R23D72ClosureSha256 $freezePath) -and
    [string]$completion.attempt_authorization_raw_sha256 -ceq
        (Get-R23D72ClosureSha256 $attemptPath) -and
    [string]$completion.terminal_report_raw_sha256 -ceq
        (Get-R23D72ClosureSha256 $terminalPath)
) "completion receipt changed"

Assert-R23D72Closure (
    [string]$terminal.classification -ceq
        "valid_complete_positive_preturn_startup_development" -and
    [string]$terminal.question_class -ceq "development" -and
    [bool]$terminal.outcome_exposed_fixture -and
    -not [bool]$terminal.turning_tested -and
    [bool]$terminal.execution.integrity_passed -and
    [int]$terminal.execution.controller_semantic_step_count -eq 601 -and
    [int]$terminal.execution.validated_portable_command_count -eq 4808 -and
    [int]$terminal.execution.native_actuation_application_count -eq 4808 -and
    [int]$terminal.execution.portable_impulse_violation_count -eq 0 -and
    [int]$terminal.execution.world_attempt_count -eq 1 -and
    [int]$terminal.execution.world_build_count -eq 1 -and
    [int]$terminal.execution.startup_ramp_active_step_count -eq 359 -and
    [int]$terminal.execution.startup_ramp_exact_zero_scale_step_count -eq 1 -and
    [int]$terminal.execution.startup_ramp_exact_unity_scale_step_count -eq 242 -and
    [bool]$terminal.execution.startup_ramp_composition_integrity_passed -and
    [bool]$terminal.execution.runtime_capture_integrity_passed -and
    [int]$terminal.execution.commanded_turn_step_count -eq 0 -and
    -not [bool]$terminal.execution.turning_tested -and
    [int]$terminal.measurements.torso_ground_contact_step_count -eq 0 -and
    [bool]$terminal.development_observation.criterion_passed -and
    [string]$terminal.trace_artifact.sha256 -ceq
        [string]$closure.execution.trace_raw_sha256 -and
    [long]$terminal.trace_artifact.byte_length -eq
        [long]$closure.execution.trace_byte_length
) "terminal report changed"

$lineCount = 0
$groundCount = 0
$rampActiveCount = 0
$zeroScaleCount = 0
$unityScaleCount = 0
$reanchorSteps = @()
$minimumHeight = [double]::PositiveInfinity
$maximumTilt = 0.0
$minimumSupport = [int]::MaxValue
$row146 = $null
$row600 = $null
Get-Content -LiteralPath $tracePath | ForEach-Object {
    $row = $_ | ConvertFrom-Json -AsHashtable -Depth 100
    $step = $lineCount
    $expectedScale = if ($step -ge 359) {
        1.0
    } else {
        $progress = $step / 359.0
        $progress * $progress * (3.0 - 2.0 * $progress)
    }
    Assert-R23D72Closure (
        [string]$row.schema_version -ceq
            "sporespore_qsdk_r23d72_mujoco_preturn_trace_row_v1" -and
        [string]$row.campaign_id -ceq
            "QSDK-R23D72-MUJOCO-SELECTED-PROFILE-PRETURN-STARTUP-DEVELOPMENT" -and
        [string]$row.cell_id -ceq
            "r23d72__mujoco__s23191__reference_zero__unconditional_startup_ramp" -and
        [int]$row.semantic_step -eq $step -and
        [int]$row.trace_step -eq $step -and
        [string]$row.segment_id -ceq "reference_walk" -and
        [double]$row.desired_heading_offset_rad -eq 0.0 -and
        [bool]$row.outcome_exposed_fixture -and
        -not [bool]$row.turning_tested -and
        -not [bool]$row.torso_ground_contact -and
        [string]$row.startup_ramp_id -ceq
            "canonical_velocity_smoothstep_one_gait_cycle_v1" -and
        [Math]::Abs([double]$row.startup_velocity_scale - $expectedScale) -le
            $tolerance
    ) "trace row invalid at semantic step $step"
    $groundCount += [int][bool]$row.torso_ground_contact
    $rampActiveCount += [int]([double]$row.startup_velocity_scale -lt 1.0)
    $zeroScaleCount += [int]([double]$row.startup_velocity_scale -eq 0.0)
    $unityScaleCount += [int]([double]$row.startup_velocity_scale -eq 1.0)
    if ([bool]$row.task_frame_origin_reanchored_this_step) { $reanchorSteps += $step }
    $minimumHeight = [Math]::Min($minimumHeight, [double]$row.torso_height_m)
    $maximumTilt = [Math]::Max($maximumTilt, [double]$row.torso_tilt_rad)
    $minimumSupport = [Math]::Min($minimumSupport, [int]$row.observed_support_count)
    if ($step -eq 146) { $row146 = $row }
    if ($step -eq 600) { $row600 = $row }
    $lineCount += 1
}
Assert-R23D72Closure (
    $lineCount -eq 601 -and
    $groundCount -eq 0 -and
    $rampActiveCount -eq 359 -and
    $zeroScaleCount -eq 1 -and
    $unityScaleCount -eq 242 -and
    $reanchorSteps.Count -eq 1 -and
    $reanchorSteps[0] -eq 600 -and
    $minimumSupport -eq 1 -and
    [Math]::Abs($minimumHeight - 0.424519889757661) -le $tolerance -and
    [Math]::Abs($maximumTilt - 0.08800670805139185) -le $tolerance -and
    $null -ne $row146 -and
    $null -ne $row600 -and
    [Math]::Abs([double]$row146.torso_height_m - 0.4381560073777793) -le
        $tolerance -and
    [Math]::Abs([double]$row146.torso_tilt_rad - 0.0028013975922728048) -le
        $tolerance -and
    -not [bool]$row146.torso_ground_contact -and
    [Math]::Abs([double]$row600.torso_height_m - 0.4331011546908549) -le
        $tolerance -and
    [Math]::Abs([double]$row600.torso_tilt_rad - 0.02521726611221377) -le
        $tolerance -and
    -not [bool]$row600.torso_ground_contact
) "complete trace summary changed"

$mutationRejections = 0
foreach ($mutation in @(
    { param($value) $value.status = "closed_negative" },
    { param($value) $value.evidence.total_byte_length += 1 },
    { param($value) $value.execution.trace_row_count = 600 },
    { param($value) $value.fixture.commanded_turn_step_count = 1 },
    { param($value) $value.measurements.observed_torso_ground_contact_step_count = 1 },
    { param($value) $value.claims.turning_established = $true },
    { param($value) $value.claims.release_score_after = "11/25" }
)) {
    $candidate = $closure | ConvertTo-Json -Depth 100 |
        ConvertFrom-Json -AsHashtable -Depth 100
    & $mutation $candidate
    if (-not (Test-R23D72ClosureShape $candidate)) { $mutationRejections += 1 }
}
Assert-R23D72Closure ($mutationRejections -eq 7) (
    "closure mutation controls did not all reject"
)

# Replay the prospective gate without hiding or rewriting the now-observed
# closure.  The only historical negative whose result necessarily changes
# after closure is the missing-authorization test: the live worker correctly
# returns CLOSED first.  Patch only its in-memory path to a guaranteed-absent
# sentinel, run the complete six-test module, then run the unchanged supervisor
# zero-world preflight and inherited immutable evidence audits.
$prospectiveReplay = @'
import pathlib
import sys
import unittest

from sporespore_mujoco_adapter import qsdk_r23d72_preturn_startup_development as route

route.CLOSURE_PATH = pathlib.Path(
    r"C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence"
) / "__r23d72_prospective_replay_closure_must_not_exist__"
if route.CLOSURE_PATH.exists():
    raise SystemExit("prospective replay sentinel unexpectedly exists")
suite = unittest.defaultTestLoader.loadTestsFromName(
    "sdk.adapters.mujoco.test_r23d72_preturn_startup_development"
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
    [void](Invoke-R23D72ClosureProcess $pythonHost @("-c", $prospectiveReplay))
} finally {
    $env:PYTHONPATH = $priorPythonPath
}
[void](Invoke-R23D72ClosureProcess "pwsh" @(
    "-NoProfile", "-File", $supervisorPath, "-PreflightOnly", "-Python", $pythonHost
))
[void](Invoke-R23D72ClosureProcess "pwsh" @(
    "-NoProfile", "-File", $r42AuditPath
))
[void](Invoke-R23D72ClosureProcess "pwsh" @(
    "-NoProfile", "-File", $r71DiagnosisAuditPath
))

Write-Output (
    "[turning/mujoco] R23D72 closure PASS: 13 files, 6,988,899 bytes, " +
    "601/601 trace rows, 0 torso contacts, 7/7 closure mutations rejected, " +
    "1 retained world, turning not tested, score 10/25"
)
