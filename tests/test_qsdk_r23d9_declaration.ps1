[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$declarationPath = Join-Path $repoRoot "sdk\turning\r23d9_support_handoff_preregistration_v1.json"
$designPath = Join-Path $repoRoot "sdk\turning\r23d9_support_handoff.py"
$pythonTestPath = Join-Path $repoRoot "sdk\turning\test_r23d9_support_handoff.py"
$closurePath = Join-Path $repoRoot "sdk\turning\r23d8_physical_closure_v1.json"
$attributesPath = Join-Path $repoRoot ".gitattributes"

function Assert-R23D9([bool]$Condition, [string]$Message) {
    if (-not $Condition) {
        throw $Message
    }
}

function Get-RawSha256([string]$Path) {
    return "sha256:" + (
        Get-FileHash -Algorithm SHA256 -LiteralPath $Path
    ).Hash.ToLowerInvariant()
}

function Get-GitBlobBytes([string]$Oid) {
    $start = [Diagnostics.ProcessStartInfo]::new()
    $start.FileName = "git"
    $start.WorkingDirectory = $repoRoot
    $start.UseShellExecute = $false
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    foreach ($argument in @("cat-file", "blob", $Oid)) {
        [void]$start.ArgumentList.Add($argument)
    }
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $start
    [void]$process.Start()
    $memory = [IO.MemoryStream]::new()
    try {
        $process.StandardOutput.BaseStream.CopyTo($memory)
        $stderr = $process.StandardError.ReadToEnd()
        $process.WaitForExit()
        Assert-R23D9 ($process.ExitCode -eq 0) (
            "QSDK_R23D9_GIT_BLOB_UNREADABLE:${Oid}:$stderr"
        )
        return $memory.ToArray()
    } finally {
        $memory.Dispose()
        $process.Dispose()
    }
}

function Get-BytesSha256([byte[]]$Bytes) {
    $sha = [Security.Cryptography.SHA256]::Create()
    try {
        return "sha256:" + [Convert]::ToHexString(
            $sha.ComputeHash($Bytes)
        ).ToLowerInvariant()
    } finally {
        $sha.Dispose()
    }
}

Assert-R23D9 (
    (git -C $repoRoot rev-parse --show-toplevel).Replace("/", "\") -ceq
        $repoRoot -and
    (git -C $repoRoot remote get-url origin) -ceq
        "https://github.com/Slagathore/sporespore.git"
) "QSDK_R23D9_REPOSITORY_IDENTITY_INVALID"

foreach ($path in @(
    $declarationPath,
    $designPath,
    $pythonTestPath,
    $closurePath,
    $attributesPath
)) {
    Assert-R23D9 (Test-Path -LiteralPath $path -PathType Leaf) (
        "QSDK_R23D9_DECLARATION_MISSING:$path"
    )
}

$declaration = Get-Content -Raw -LiteralPath $declarationPath |
    ConvertFrom-Json -AsHashtable -Depth 100
$closure = Get-Content -Raw -LiteralPath $closurePath |
    ConvertFrom-Json -AsHashtable -Depth 100
$closureRelative = "sdk/turning/r23d8_physical_closure_v1.json"
$blobLine = (git -C $repoRoot ls-tree HEAD -- $closureRelative).Trim()
$blobParts = $blobLine -split "\s+"
Assert-R23D9 (
    $blobParts.Count -ge 3 -and
    $blobParts[1] -ceq "blob" -and
    $blobParts[2] -ceq [string]$declaration.lineage.predecessor_closure_git_blob_oid -and
    (Get-BytesSha256 (Get-GitBlobBytes $blobParts[2])) -ceq
        [string]$declaration.lineage.predecessor_closure_raw_sha256 -and
    (Get-RawSha256 $closurePath) -ceq
        [string]$declaration.lineage.predecessor_closure_raw_sha256
) "QSDK_R23D9_PREDECESSOR_BLOB_IDENTITY_INVALID"

$schedule = $declaration.frozen_schedule_and_gate_snapshot
$machine = $declaration.handoff_state_machine_contract
$changed = $declaration.inherited_unchanged_scientific_contract
Assert-R23D9 (
    [string]$declaration.schema_version -ceq
        "sporespore_qsdk_r23d9_support_handoff_preregistration_v1" -and
    [string]$declaration.status -ceq
        "stage_zero_preregistered_support_confirmed_irreversible_handoff_successor_no_workers_no_physical_authorization" -and
    [string]$declaration.campaign_id -ceq
        "QSDK-R23D9-SUPPORT-CONFIRMED-ACTIVE-TO-PASSIVE-HANDOFF-BILATERAL-TURN-DEVELOPMENT" -and
    [string]$declaration.gate_id -ceq "QSDK-R23D9" -and
    [string]$declaration.release_gate_id -ceq "QSDK-R23" -and
    [string]$declaration.lineage.predecessor_status -ceq
        [string]$closure.status -and
    [string]$declaration.lineage.predecessor_result_classification -ceq
        [string]$closure.immutable_completion_record.result_classification -and
    [bool]$declaration.lineage.predecessor_scientific_negative -and
    -not [bool]$declaration.lineage.predecessor_same_identity_rerun_allowed -and
    [int]$declaration.lineage.predecessor_signed_yaw_response_pass_count -eq 2 -and
    [int]$declaration.lineage.predecessor_passive_all_four_contact_settle_pass_count -eq 2 -and
    [bool]$declaration.declared_use_of_predecessor_data.development_informed_successor -and
    -not [bool]$declaration.declared_use_of_predecessor_data.independent_validation -and
    [string]$declaration.scientifically_distinct_successor.terminal_policy_id -ceq
        "sporespore_support_confirmed_irreversible_passive_handoff_v1" -and
    [bool]$declaration.scientifically_distinct_successor.handoff_is_irreversible -and
    -not [bool]$declaration.scientifically_distinct_successor.post_handoff_reactivation_permitted -and
    -not [bool]$declaration.scientifically_distinct_successor.deadline_forced_handoff_can_pass -and
    [int]$declaration.numeric_derivation.unchanged_terminal_and_settle_total_steps -eq 780 -and
    [int]$declaration.numeric_derivation.maximum_active_acquisition_steps -eq 420 -and
    [int]$declaration.numeric_derivation.minimum_post_handoff_zero_actuation_steps -eq 360 -and
    [double]$declaration.numeric_derivation.support_confirmation_seconds -eq 0.25 -and
    -not [bool]$changed.terminal_and_settle_total_horizon_changed -and
    -not [bool]$changed.walking_turning_and_safety_numeric_thresholds_changed -and
    [bool]$changed.contact_acquisition_deadline_changed -and
    [bool]$changed.active_contact_hold_requirement_changed -and
    [bool]$changed.passive_stability_requirement_changed -and
    [int]$schedule.turning_controller_semantic_step_count -eq 2992 -and
    [int]$schedule.terminal_support_handoff_step_count -eq 780 -and
    [int]$schedule.maximum_active_neutral_acquisition_steps -eq 420 -and
    [int]$schedule.support_confirmation_step_count -eq 30 -and
    [int]$schedule.minimum_post_handoff_zero_actuation_steps -eq 360 -and
    [int]$schedule.total_traced_step_count -eq 3772 -and
    [int]$schedule.minimum_total_active_native_application_count -eq 24176 -and
    [int]$schedule.maximum_total_active_native_application_count -eq 27296 -and
    [int]$schedule.exact_post_handoff_native_application_count -eq 0 -and
    [string]$machine.initial_mode -ceq "active_neutral_acquisition" -and
    [string]$machine.passive_mode -ceq "irreversible_zero_actuation_stability" -and
    [int]$machine.support_confirmation_requires_consecutive_completed_steps -eq 30 -and
    [int]$machine.latest_first_passive_step_zero_based -eq 420 -and
    -not [bool]$machine.mode_reactivation_permitted -and
    [bool]$machine.all_780_steps_execute -and
    [int]$declaration.stage_a_mujoco_support_handoff_screen.declared_world_count -eq 2 -and
    [int]$declaration.stage_b_three_engine_confirmation.declared_world_count_if_launched -eq 9 -and
    -not [bool]$declaration.authorization.physical_execution_authorized -and
    [bool]$declaration.authorization.worker_implementation_authorized -and
    -not [bool]$declaration.claim_boundary.command_conditioned_turning -and
    -not [bool]$declaration.claim_boundary.physical_acceptance_authority
) "QSDK_R23D9_DECLARATION_INVALID"

$attributes = Get-Content -Raw -LiteralPath $attributesPath
foreach ($rule in @(
    "sdk/turning/r23d9_* text eol=lf",
    "sdk/run_qsdk_r23d9_*.ps1 text eol=lf",
    "tests/test_qsdk_r23d9_*.ps1 text eol=lf",
    "tests/test_sdk_qsdk_r23d9_*.gd text eol=lf",
    "sdk/adapters/rapier/src/bin/qsdk_r23d9_*.rs text eol=lf",
    "sdk/adapters/mujoco/sporespore_mujoco_adapter/qsdk_r23d9_*.py text eol=lf"
)) {
    Assert-R23D9 ($attributes.Contains($rule)) (
        "QSDK_R23D9_GIT_ATTRIBUTE_RULE_MISSING:$rule"
    )
}

$futureWorkerPaths = @(
    "sdk\adapters\mujoco\sporespore_mujoco_adapter\qsdk_r23d9_support_handoff.py",
    "sdk\adapters\rapier\src\bin\qsdk_r23d9_support_handoff.rs",
    "tests\test_sdk_qsdk_r23d9_support_handoff_godot_jolt_worker.gd",
    "sdk\run_qsdk_r23d9_supervisor.ps1"
)
foreach ($relative in $futureWorkerPaths) {
    Assert-R23D9 (-not (Test-Path -LiteralPath (Join-Path $repoRoot $relative))) (
        "QSDK_R23D9_STAGE_ZERO_ALREADY_HAS_WORKER:$relative"
    )
}

$python = Join-Path $repoRoot "sdk\adapters\mujoco\.venv\Scripts\python.exe"
Assert-R23D9 (Test-Path -LiteralPath $python -PathType Leaf) (
    "QSDK_R23D9_PYTHON_MISSING:$python"
)
$env:PYTHONPATH = @(
    (Join-Path $repoRoot "sdk\turning"),
    (Join-Path $repoRoot "sdk\python"),
    (Join-Path $repoRoot "sdk\adapters\mujoco")
) -join [IO.Path]::PathSeparator
try {
    $unitOutput = & $python -m unittest -v $pythonTestPath 2>&1
    Assert-R23D9 ($LASTEXITCODE -eq 0) (
        "QSDK_R23D9_UNIT_FAILED:$($unitOutput -join [Environment]::NewLine)"
    )
    $preflightText = & $python $designPath 2>&1
    Assert-R23D9 ($LASTEXITCODE -eq 0) (
        "QSDK_R23D9_PREFLIGHT_FAILED:$($preflightText -join [Environment]::NewLine)"
    )
} finally {
    Remove-Item Env:PYTHONPATH -ErrorAction SilentlyContinue
}
$preflight = ($preflightText -join [Environment]::NewLine) |
    ConvertFrom-Json -AsHashtable -Depth 100
Assert-R23D9 (
    [bool]$preflight.ok -and
    [int]$preflight.terminal_step_count -eq 780 -and
    [int]$preflight.maximum_active_step_count -eq 420 -and
    [int]$preflight.minimum_passive_step_count -eq 360 -and
    [int]$preflight.support_confirmation_step_count -eq 30 -and
    [int]$preflight.oracle_canary_count -eq 5 -and
    [int]$preflight.mutation_control_count -eq 12 -and
    [int]$preflight.physics_adapter_start_count -eq 0 -and
    [int]$preflight.physical_process_launch_count -eq 0 -and
    [int]$preflight.model_construction_count -eq 0 -and
    [int]$preflight.world_attempt_count -eq 0 -and
    [int]$preflight.world_build_count -eq 0 -and
    -not [bool]$preflight.physical_execution_authorized -and
    -not [bool]$preflight.physical_acceptance_authority
) "QSDK_R23D9_PREFLIGHT_INVALID"

Write-Output (
    (
        "QSDK_R23D9_DECLARATION_PASS policy={0} canaries={1} mutations={2} " +
        "active_max={3} passive_min={4} worlds={5} physical_authority={6}"
    ) -f
        $declaration.scientifically_distinct_successor.terminal_policy_id,
        $preflight.oracle_canary_count,
        $preflight.mutation_control_count,
        $preflight.maximum_active_step_count,
        $preflight.minimum_passive_step_count,
        $preflight.world_attempt_count,
        $preflight.physical_acceptance_authority
)
