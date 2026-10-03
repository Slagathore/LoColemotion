#requires -Version 7.0

<#
.SYNOPSIS
Thin R145 binding for the shared serialized Godot/Jolt route supervisor.

.DESCRIPTION
R145 commissions the R144 solver-coupled complete-energy production route in
one genuine world and exactly two solver steps. It proves route completion and
in-run invariant capture, not recovery behavior or prone-to-standing.
#>

[CmdletBinding()]
param(
    [ValidateSet("Preflight", "Physical", "RawBindingControl", "RuntimeIdentity")]
    [string]$Mode = "Preflight",
    [switch]$RunPhysical,
    [string]$AuthorizationPath = "",
    [string]$CoreLibrary = "sdk/target/debug/sporespore_locomotion_core.dll",
    [string]$EvidenceRoot = "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$root = Split-Path $PSScriptRoot -Parent
$contractRelative =
    "sdk/recovery/r24d145_godot_jolt_solver_coupled_complete_energy_route_contract_v1.json"
$contract = Get-Content -Raw -LiteralPath (Join-Path $root $contractRelative) |
    ConvertFrom-Json
$physicalClosureRelative =
    "sdk/recovery/r24d145_godot_jolt_solver_coupled_complete_energy_route_ghost_closure_v1.json"
if ($Mode -ceq "Physical" -and $RunPhysical.IsPresent -and
    (Test-Path -LiteralPath (Join-Path $root $physicalClosureRelative) -PathType Leaf)) {
    throw "QSDK_R24D145_PHYSICAL_IDENTITY_CONSUMED"
}

$question = $contract.prospective_physical_question
$runner = $contract.physical_runner
$shared = Join-Path $PSScriptRoot "run_qsdk_r24d57_godot_native_recovery_route_ghost.ps1"
$arguments = @{
    Mode = $Mode
    RunPhysical = $RunPhysical
    AuthorizationPath = $AuthorizationPath
    CoreLibrary = $CoreLibrary
    EvidenceRoot = $EvidenceRoot
    ConsolePath = [string]$contract.exact_runtime.console_path
    ExpectedConsoleSha256 = [string]$contract.exact_runtime.console_sha256
    ExpectedConsoleByteLength = [long]$contract.exact_runtime.console_byte_length
    GateId = "QSDK-R24D145"
    GateToken = "R24D145"
    ContractRelativePath = $contractRelative
    ClosureRelativePath = [string]$contract.closure.path
    AuthorizationClosureSchema = [string]$contract.closure.schema
    RuntimeIdentitySchema = [string]$runner.runtime_identity_schema
    RawBindingControlSchema = [string]$runner.raw_binding_control_schema
    SourceAuditRelativePath =
        "sdk/conformance/r24d145_godot_jolt_solver_coupled_complete_energy_route.py"
    WorkerRelativePath = [string]$runner.worker_path
    EvidenceDirectoryName =
        "qsdk-r24d145-godot-jolt-solver-coupled-complete-energy-route-ghost"
    RawMarker = [string]$runner.raw_marker
    ReadyMarker = [string]$runner.ready_marker
    SupervisorMarker = [string]$runner.supervisor_marker
    Seed = [int]$question.seed
    SeedLabel = [string]$question.seed_label
    SeedSha256 = [string]$question.seed_sha256
    ActuatorMode = [string]$runner.actuator_mode
    RecoveryControllerId = [string]$runner.recovery_controller_id
    RecoveryEnergyRouteId = [string]$runner.recovery_energy_route_id
    PreflightSchema = [string]$runner.preflight_schema
    AttemptSchema = [string]$runner.attempt_schema
    RawSchema = [string]$runner.raw_schema
    MissingRawSchema = [string]$runner.missing_raw_schema
    TerminalSchema = [string]$runner.terminal_schema
    SupervisorResultSchema = [string]$runner.supervisor_result_schema
    PhysicalQuestionKind = "integration_ghost"
    MaximumModelConstructionAttemptCount = 1
    MaximumModelConstructionCount = 1
    MaximumWorldAttemptCount = 1
    MaximumWorldBuildCount = 1
    MaximumOuterSolverSteps = 2
    ExpectedModelConstructionCount = 1
    ExpectedWorldAttemptCount = 1
    ExpectedWorldBuildCount = 1
    MinimumCompletedSolverSteps = 2
    ExpectedBehaviorEvaluatorInvocationCount = 0
    ValidCompleteStatus = "valid_complete_integration_ghost"
    InvalidOrIncompleteStatus = "invalid_or_incomplete_integration_ghost"
    PhysicalWorkId = "QSDK-R24D145-GODOT-JOLT-SOLVER-COUPLED-COMPLETE-ENERGY-ROUTE-GHOST"
    PhysicalTimeoutSeconds = 60
    QualifiedPhysicalPaths = @($contract.qualified_physical_paths | ForEach-Object {
        [string]$_
    })
}

& $shared @arguments
exit $LASTEXITCODE
