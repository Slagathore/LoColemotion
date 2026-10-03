#requires -Version 7.0

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path $PSScriptRoot -Parent
. (Join-Path $repoRoot "sdk\godot_receipt_terminated_process.ps1")

function Assert-Projection {
    param(
        [Parameter(Mandatory)][bool]$Condition,
        [Parameter(Mandatory)][string]$Code
    )
    if (-not $Condition) { throw $Code }
}

$empty = Get-SporeSporeGodotEngineHealthProjection -StandardError ""
Assert-Projection (
    [bool]$empty.passed -and
    [int]$empty.stderr_raw_byte_length -eq 0 -and
    [string]$empty.stderr_raw_sha256 -ceq
        "sha256:e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855" -and
    [int]$empty.fatal_diagnostic_line_count -eq 0
) "EMPTY_STDERR_NOT_GREEN"

$benign = Get-SporeSporeGodotEngineHealthProjection -StandardError (
    "Godot Engine v4.7.custom`nWARNING: retained warning`n"
)
Assert-Projection (
    [bool]$benign.passed -and
    [int]$benign.stderr_nonempty_line_count -eq 2 -and
    [int]$benign.fatal_diagnostic_line_count -eq 0
) "NON_FATAL_STDERR_NOT_GREEN"

$ordinaryError = Get-SporeSporeGodotEngineHealthProjection -StandardError (
    "ERROR: forced engine failure`n"
)
Assert-Projection (
    -not [bool]$ordinaryError.passed -and
    [int]$ordinaryError.engine_error_line_count -eq 1 -and
    [int]$ordinaryError.fatal_diagnostic_line_count -eq 1
) "ENGINE_ERROR_NOT_REJECTED"

$scriptError = Get-SporeSporeGodotEngineHealthProjection -StandardError (
    "SCRIPT ERROR: forced script failure`n"
)
Assert-Projection (
    -not [bool]$scriptError.passed -and
    [int]$scriptError.engine_error_line_count -eq 1
) "SCRIPT_ERROR_NOT_REJECTED"

$fatal = Get-SporeSporeGodotEngineHealthProjection -StandardError (
    "FATAL: forced fatal failure`n"
)
Assert-Projection (-not [bool]$fatal.passed) "FATAL_NOT_REJECTED"

$crash = Get-SporeSporeGodotEngineHealthProjection -StandardError (
    "CRASH: forced crash failure`n"
)
Assert-Projection (-not [bool]$crash.passed) "CRASH_NOT_REJECTED"

$assertionLine = (
    "ERROR: Jolt Physics assertion 'inAngularVelocity.Length() <= " +
    "mMaxAngularVelocity' failed with message '' at " +
    "'thirdparty\jolt_physics\Jolt/Physics/Body/MotionProperties.h:55'"
)
$assertionSite = "   at: jolt_assert (modules\jolt_physics\jolt_globals.cpp:88)"
$assertionStderr = (
    "$assertionLine`n$assertionSite`n$assertionLine`n$assertionSite`n"
)
$assertion = Get-SporeSporeGodotEngineHealthProjection `
    -StandardError $assertionStderr
Assert-Projection (
    -not [bool]$assertion.passed -and
    [int]$assertion.stderr_nonempty_line_count -eq 4 -and
    [int]$assertion.engine_error_line_count -eq 2 -and
    [int]$assertion.native_assertion_failure_line_count -eq 2 -and
    [int]$assertion.native_assertion_site_line_count -eq 2 -and
    [int]$assertion.fatal_diagnostic_line_count -eq 4 -and
    [int]$assertion.fatal_diagnostic_unique_line_count -eq 2 -and
    @($assertion.ordered_unique_fatal_diagnostic_lines).Count -eq 2
) "JOLT_ASSERTION_POPULATION_NOT_REJECTED"

$receipt = [ordered]@{
    schema_version = "sporespore_godot_engine_health_projection_test_v1"
    ok = $true
    positive_case_count = 2
    forced_failure_case_count = 5
    typed_fatal_selector_count = 6
    jolt_assertion_failure_line_count = 2
    jolt_assertion_site_line_count = 2
    model_construction_count = 0
    world_attempt_count = 0
    world_build_count = 0
    solver_step_count = 0
    physics_state_modified = $false
    physical_acceptance_authority = $false
    release_authority = $false
}
Write-Output (
    "SPORESPORE_GODOT_ENGINE_HEALTH_PROJECTION_PASS " +
    ($receipt | ConvertTo-Json -Depth 10 -Compress)
)
