#requires -Version 7.0

<#
.SYNOPSIS
Reusable zero-world controls for Godot progress-aware process supervision.

.DESCRIPTION
Exercises one valid progress stream, one malformed monotonic sequence, and one
progress-stall timeout without starting Godot or constructing a physics world.
It also checks declared total/stall budgets against a retained two-step timing
upper bound. Progress receipts remain liveness-only and carry no evidence or
release authority.
#>

[CmdletBinding()]
param(
    [ValidateRange(1, 100000)][int]$MaximumSolverSteps = 2400,
    [ValidateRange(1, 100000)][int]$ProgressCadenceSteps = 30,
    [ValidateRange(1, 86400)][int]$DeclaredProgressStallTimeoutSeconds = 600,
    [ValidateRange(1, 86400)][int]$DeclaredTotalTimeoutSeconds = 24000,
    [ValidateRange(0.001, 86400.0)][double]$ObservedTwoStepElapsedSeconds = 15.063932,
    [ValidateRange(1.0, 100.0)][double]$RequiredTotalMarginFactor = 1.25,
    [ValidateRange(1.0, 100.0)][double]$RequiredStallMarginFactor = 2.0
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$root = Split-Path $PSScriptRoot -Parent
. (Join-Path $PSScriptRoot "godot_receipt_terminated_process.ps1")

function Assert-ProgressControl {
    param([bool]$Condition, [string]$Code)
    if (-not $Condition) { throw "Godot progress zero-world control: $Code" }
}

$observedUpperSecondsPerStep = $ObservedTwoStepElapsedSeconds / 2.0
$projectedMaximumSeconds = $observedUpperSecondsPerStep * $MaximumSolverSteps
$requiredTotalSeconds = $projectedMaximumSeconds * $RequiredTotalMarginFactor
$projectedCadenceSeconds = $observedUpperSecondsPerStep * $ProgressCadenceSteps
$requiredStallSeconds = $projectedCadenceSeconds * $RequiredStallMarginFactor
Assert-ProgressControl `
    -Condition ($DeclaredTotalTimeoutSeconds -ge $requiredTotalSeconds) `
    -Code "TOTAL_TIMEOUT_MARGIN_INADEQUATE"
Assert-ProgressControl `
    -Condition ($DeclaredProgressStallTimeoutSeconds -ge $requiredStallSeconds) `
    -Code "STALL_TIMEOUT_MARGIN_INADEQUATE"
Assert-ProgressControl `
    -Condition ($DeclaredProgressStallTimeoutSeconds -lt $DeclaredTotalTimeoutSeconds) `
    -Code "STALL_TIMEOUT_NOT_BELOW_TOTAL"

$pwsh = (Get-Process -Id $PID).Path
$nonce = "sporespore-r111-progress-zero-world-control"
$progressMarker = "SPORESPORE_PROGRESS_CONTROL_PROGRESS "
$readyMarker = "SPORESPORE_PROGRESS_CONTROL_READY "
$environment = @{ SPORESPORE_PROGRESS_CONTROL_NONCE = $nonce }

$validChild = @'
$n=$env:SPORESPORE_PROGRESS_CONTROL_NONCE
$p1=[ordered]@{schema_version='sporespore_godot_supervised_progress_v1';progress_protocol_id='godot_4_7_gdscript_non_evidentiary_progress_v1';termination_nonce=$n;process_id=$PID;progress_sequence=1;physics_evidence_authority=$false;physical_acceptance_authority=$false;release_authority=$false}
$p2=[ordered]@{schema_version='sporespore_godot_supervised_progress_v1';progress_protocol_id='godot_4_7_gdscript_non_evidentiary_progress_v1';termination_nonce=$n;process_id=$PID;progress_sequence=2;physics_evidence_authority=$false;physical_acceptance_authority=$false;release_authority=$false}
$r=[ordered]@{schema_version='sporespore_godot_supervised_termination_ready_v1';termination_protocol_id='godot_4_7_gdscript_shutdown_containment_v1';termination_nonce=$n;process_id=$PID;requested_exit_code=0;worker_receipt_emitted=$true}
Write-Output ('SPORESPORE_PROGRESS_CONTROL_PROGRESS '+($p1|ConvertTo-Json -Compress))
Write-Output ('SPORESPORE_PROGRESS_CONTROL_PROGRESS '+($p2|ConvertTo-Json -Compress))
Write-Output ('SPORESPORE_PROGRESS_CONTROL_READY '+($r|ConvertTo-Json -Compress))
Start-Sleep -Seconds 30
'@
$valid = Invoke-SporeSporeGodotReceiptTerminatedProcess `
    -FileName $pwsh `
    -Arguments @("-NoProfile", "-Command", $validChild) `
    -WorkingDirectory $root `
    -ReadyMarkerPrefix $readyMarker `
    -ExpectedNonce $nonce `
    -Environment $environment `
    -ProgressMarkerPrefix $progressMarker `
    -ProgressStallTimeoutSeconds 3 `
    -TimeoutSeconds 10
Assert-ProgressControl `
    -Condition (
        [bool]$valid.termination_protocol_valid -and
        [bool]$valid.progress_binding_valid -and
        [int]$valid.progress_marker_count -eq 2 -and
        [int]$valid.exit_code -eq 0
    ) `
    -Code "VALID_STREAM_FAILED"

$invalidChild = @'
$n=$env:SPORESPORE_PROGRESS_CONTROL_NONCE
$p=[ordered]@{schema_version='sporespore_godot_supervised_progress_v1';progress_protocol_id='godot_4_7_gdscript_non_evidentiary_progress_v1';termination_nonce=$n;process_id=$PID;progress_sequence=2;physics_evidence_authority=$false;physical_acceptance_authority=$false;release_authority=$false}
Write-Output ('SPORESPORE_PROGRESS_CONTROL_PROGRESS '+($p|ConvertTo-Json -Compress))
Start-Sleep -Seconds 30
'@
$invalid = Invoke-SporeSporeGodotReceiptTerminatedProcess `
    -FileName $pwsh `
    -Arguments @("-NoProfile", "-Command", $invalidChild) `
    -WorkingDirectory $root `
    -ReadyMarkerPrefix $readyMarker `
    -ExpectedNonce $nonce `
    -Environment $environment `
    -ProgressMarkerPrefix $progressMarker `
    -ProgressStallTimeoutSeconds 3 `
    -TimeoutSeconds 10
Assert-ProgressControl `
    -Condition (
        -not [bool]$invalid.termination_protocol_valid -and
        -not [bool]$invalid.progress_binding_valid -and
        [string]$invalid.termination_protocol_failure_code -ceq
            "GODOT_PROGRESS_MARKER_BINDING_INVALID"
    ) `
    -Code "INVALID_SEQUENCE_NOT_REJECTED"

$stallChild = @'
$n=$env:SPORESPORE_PROGRESS_CONTROL_NONCE
$p=[ordered]@{schema_version='sporespore_godot_supervised_progress_v1';progress_protocol_id='godot_4_7_gdscript_non_evidentiary_progress_v1';termination_nonce=$n;process_id=$PID;progress_sequence=1;physics_evidence_authority=$false;physical_acceptance_authority=$false;release_authority=$false}
Write-Output ('SPORESPORE_PROGRESS_CONTROL_PROGRESS '+($p|ConvertTo-Json -Compress))
Start-Sleep -Seconds 30
'@
$stall = Invoke-SporeSporeGodotReceiptTerminatedProcess `
    -FileName $pwsh `
    -Arguments @("-NoProfile", "-Command", $stallChild) `
    -WorkingDirectory $root `
    -ReadyMarkerPrefix $readyMarker `
    -ExpectedNonce $nonce `
    -Environment $environment `
    -ProgressMarkerPrefix $progressMarker `
    -ProgressStallTimeoutSeconds 1 `
    -TimeoutSeconds 10
Assert-ProgressControl `
    -Condition (
        [bool]$stall.timed_out -and
        [string]$stall.timeout_kind -ceq "progress_stall" -and
        [int]$stall.exit_code -eq 124
    ) `
    -Code "STALL_TIMEOUT_FAILED"

$receipt = [ordered]@{
    schema_version = "sporespore_godot_progress_observability_zero_world_v1"
    ok = $true
    positive_case_count = 1
    forced_failure_case_count = 2
    valid_progress_marker_count = [int]$valid.progress_marker_count
    invalid_sequence_rejected = $true
    progress_stall_detected = $true
    progress_stall_timeout_kind = [string]$stall.timeout_kind
    maximum_solver_step_count = $MaximumSolverSteps
    progress_cadence_steps = $ProgressCadenceSteps
    declared_progress_stall_timeout_seconds = $DeclaredProgressStallTimeoutSeconds
    declared_total_timeout_seconds = $DeclaredTotalTimeoutSeconds
    observed_two_step_elapsed_seconds = $ObservedTwoStepElapsedSeconds
    observed_upper_seconds_per_step = $observedUpperSecondsPerStep
    projected_maximum_seconds = $projectedMaximumSeconds
    required_total_margin_factor = $RequiredTotalMarginFactor
    actual_total_margin_factor = $DeclaredTotalTimeoutSeconds / $projectedMaximumSeconds
    projected_cadence_seconds = $projectedCadenceSeconds
    required_stall_margin_factor = $RequiredStallMarginFactor
    actual_stall_margin_factor =
        $DeclaredProgressStallTimeoutSeconds / $projectedCadenceSeconds
    model_construction_count = 0
    world_attempt_count = 0
    world_build_count = 0
    solver_step_count = 0
    physics_state_modified = $false
    physics_evidence_authority = $false
    physical_acceptance_authority = $false
    release_authority = $false
}
Write-Output (
    "SPORESPORE_GODOT_PROGRESS_OBSERVABILITY_ZERO_WORLD " +
    ($receipt | ConvertTo-Json -Depth 10 -Compress)
)
