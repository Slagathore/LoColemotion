#requires -Version 7.0

[CmdletBinding()]
param(
    [string]$Godot = (
        "C:\Users\Cole\CodeStuff\Misc\Godot\" +
        "Godot_v4.7-stable_mono_win64_console.exe"
    ),
    [string]$Python = "",
    [string]$PowerShell = "pwsh",
    [string]$Cargo = "",
    [switch]$ExpectProductionConformanceLockHeld
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$runner = Join-Path $repoRoot "sdk\run_qsdk_r23d67_zero_world.ps1"
$supervisor = Join-Path $repoRoot "sdk\run_qsdk_r23d67_supervisor.ps1"

function Assert-R23D67ZeroWorldAudit([bool]$Condition, [string]$Message) {
    if (-not $Condition) {
        throw "QSDK-R23D67 ZERO-WORLD AUDIT: $Message"
    }
}

Assert-R23D67ZeroWorldAudit (Test-Path -LiteralPath $runner -PathType Leaf) (
    "runner missing: $runner"
)
Assert-R23D67ZeroWorldAudit (Test-Path -LiteralPath $supervisor -PathType Leaf) (
    "supervisor missing: $supervisor"
)
$runnerArguments = @(
    "-NoLogo", "-NoProfile", "-File", $runner,
    "-Godot", $Godot,
    "-Python", $Python,
    "-PowerShell", $PowerShell,
    "-Cargo", $Cargo
)
if ($ExpectProductionConformanceLockHeld) {
    $runnerArguments += "-ExpectProductionConformanceLockHeld"
}
$output = @(& $PowerShell @runnerArguments 2>&1 | ForEach-Object {
    [string]$_
})
Assert-R23D67ZeroWorldAudit ($LASTEXITCODE -eq 0) (
    "runner failed: $($output -join ' ')"
)
$prefix = "QSDK_R23D67_COMPLETE_ZERO_WORLD_PASS "
$markers = @($output | Where-Object {
    ([string]$_).StartsWith($prefix, [StringComparison]::Ordinal)
})
Assert-R23D67ZeroWorldAudit ($markers.Count -eq 1) "receipt marker changed"
$receipt = ([string]$markers[0]).Substring($prefix.Length) |
    ConvertFrom-Json -AsHashtable -Depth 100
Assert-R23D67ZeroWorldAudit (
    [string]$receipt.schema_version -ceq
        "sporespore_qsdk_r23d67_complete_zero_world_gate_v1" -and
    [string]$receipt.gate_id -ceq "QSDK-R23D67" -and
    [string]$receipt.question_class -ceq "finite_decision" -and
    [int]$receipt.declared_cell_count -eq 9 -and
    [int]$receipt.representative_worker_preflight_count -eq 3 -and
    [int]$receipt.native_selector_negative_count -eq 3 -and
    [int]$receipt.physical_authorization_negative_count -eq 3 -and
    [bool]$receipt.complete_nine_cell_production_supervisor_authorization_ghost_passed -and
    [int]$receipt.authorization_ghost_receipt_count -eq 9 -and
    [int]$receipt.authorization_ghost_missing_ok_negative_count -eq 3 -and
    [string]$receipt.authorization_ghost_operation_lock_mode -ceq $(
        if ($ExpectProductionConformanceLockHeld) {
            "active_parent_conformance_lock_verified"
        } else {
            "standalone_conformance_lock_acquired"
        }
    ) -and
    [bool]$receipt.authorization_ghost_active_outer_conformance_lock_verified -eq
        [bool]$ExpectProductionConformanceLockHeld -and
    [bool]$receipt.common_authorization_receipt_contract_gate_passed -and
    [int]$receipt.evaluator_outcome_control_count -eq 4 -and
    [int]$receipt.declaration_mutation_rejection_count -eq 13 -and
    [bool]$receipt.full_matrix_and_schedule_evaluator_preflight_passed -and
    [bool]$receipt.shared_operation_lock_gate_passed -and
    [string]$receipt.shared_operation_lock_gate_mode -ceq $(
        if ($ExpectProductionConformanceLockHeld) {
            "active_production_conformance_lock_verified"
        } else {
            "standalone_physical_conformance_entrypoint_interlock_verified"
        }
    ) -and
    [bool]$receipt.shared_append_only_json_gate_passed -and
    [bool]$receipt.accepted_production_route_closure_reused_exactly -and
    [bool]$receipt.complete_zero_world_gate_passed -and
    [bool]$receipt.all_physical_claims_false -and
    [int]$receipt.model_construction_count -eq 0 -and
    [int]$receipt.world_attempt_count -eq 0 -and
    [int]$receipt.world_build_count -eq 0 -and
    -not [bool]$receipt.physical_execution_authorized -and
    -not [bool]$receipt.physical_acceptance_authority -and
    -not [bool]$receipt.finite_three_engine_turning -and
    -not [bool]$receipt.q_sdk_r23_satisfied -and
    -not [bool]$receipt.cross_engine_equivalence -and
    -not [bool]$receipt.prone_to_standing -and
    -not [bool]$receipt.release_authorized
) "receipt semantics changed"

# The qualification-only outer-lock assertion must never become a physical
# lock bypass. This refusal occurs before adoption resolution, model
# construction, evidence-root creation, or any worker launch.
$physicalBypassOutput = @(& $PowerShell -NoLogo -NoProfile -File $supervisor `
    -RunPhysical -ExpectProductionConformanceLockHeld 2>&1 | ForEach-Object {
        [string]$_
    })
Assert-R23D67ZeroWorldAudit ($LASTEXITCODE -ne 0) (
    "physical mode accepted the qualification-only outer-lock assertion"
)
Assert-R23D67ZeroWorldAudit (
    ($physicalBypassOutput -join "`n").Contains(
        "physical execution must acquire its own production operation lock",
        [StringComparison]::Ordinal
    )
) "physical outer-lock-bypass refusal changed"

Write-Output (
    "[turning/3e] PASS R23D67 complete zero-world gate: " +
    "workers=3 authorization_ghost=9/9 missing_ok=3/3 " +
    "selector_negatives=3 auth_negatives=3 outer_lock_bypass_negatives=1 " +
    "models=0 worlds=0"
)
