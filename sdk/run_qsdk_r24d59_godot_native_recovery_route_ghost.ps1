#requires -Version 7.0

<#
.SYNOPSIS
Thin R59 binding for the shared bounded Godot recovery-route supervisor.

.DESCRIPTION
R59 adds a versioned closure-to-runner authorization projection and a required
post-publication, zero-world authorization-control receipt. Controller, pose,
tolerance, evaluator, worker, and physics semantics remain unchanged.
#>

[CmdletBinding()]
param(
    [ValidateSet("Preflight", "Physical", "ProjectionControl", "AuthorizationControl")]
    [string]$Mode = "Preflight",
    [switch]$RunPhysical,
    [string]$AuthorizationPath = "",
    [string]$CoreLibrary = "sdk/target/debug/sporespore_locomotion_core.dll",
    [string]$EvidenceRoot = "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence"
)

$shared = Join-Path $PSScriptRoot `
    "run_qsdk_r24d57_godot_native_recovery_route_ghost.ps1"
$qualifiedPhysicalPaths = @(
    "project.godot",
    "sdk/Cargo.toml",
    "sdk/Cargo.lock",
    "sdk/adapters/godot/Cargo.toml",
    "sdk/adapters/godot/sporespore_locomotion.gdextension",
    "sdk/adapters/godot/src/lib.rs",
    "sdk/adapters/godot/gdscript/actuator_cap_profile_binding.gd",
    "sdk/adapters/godot/gdscript/recovery_capability.gd",
    "sdk/adapters/godot/gdscript/recovery_capability_instrumented_v2.gd",
    "sdk/adapters/godot/gdscript/recovery_runtime.gd",
    "sdk/adapters/godot/gdscript/recovery_native_route_v1.gd",
    "sdk/adapters/godot/gdscript/recovery_native_world_v1.gd",
    "sdk/core/src/lib.rs",
    "sdk/core/src/recovery.rs",
    "sdk/core/src/recovery_energy.rs",
    "sdk/core/src/recovery_energy_v3.rs",
    "sdk/core/src/recovery_morphology.rs",
    "sdk/core/src/recovery_runtime.rs",
    "sdk/trace_analysis/godot_authoritative_json_transport.gd",
    "scripts/lab/mechanics/semantic_contact_rigid_body.gd",
    "sdk/conformance/r24d57_godot_native_recovery_route.py",
    "sdk/conformance/r24d58_godot_initializer_projection_successor.py",
    "sdk/conformance/r24d59_godot_authorization_projection.py",
    "sdk/recovery/r24d58_godot_initializer_projection_successor_contract_v1.json",
    "sdk/recovery/r24d58_godot_initializer_projection_zero_world_qualification_closure_v1.json",
    "sdk/recovery/r24d58_godot_native_recovery_route_ghost_pre_attempt_invalid_closure_v1.json",
    "sdk/recovery/r24d59_godot_authorization_projection_contract_v1.json",
    "sdk/physical_authorization_projection.ps1",
    "sdk/run_qsdk_r24d57_godot_native_recovery_route_ghost.ps1",
    "sdk/run_qsdk_r24d59_godot_native_recovery_route_ghost.ps1",
    "tests/test_qsdk_physical_authorization_projection.ps1",
    "tests/test_sdk_qsdk_r24d57_godot_native_recovery_route_ghost.gd",
    "tests/test_sdk_qsdk_r24d58_godot_initializer_projection_zero_world.gd"
)

& $shared `
    -Mode $Mode `
    -RunPhysical:$RunPhysical `
    -AuthorizationPath $AuthorizationPath `
    -CoreLibrary $CoreLibrary `
    -EvidenceRoot $EvidenceRoot `
    -GateId "QSDK-R24D59" `
    -GateToken "R24D59" `
    -ContractRelativePath (
        "sdk/recovery/r24d59_godot_authorization_projection_contract_v1.json"
    ) `
    -ClosureRelativePath (
        "sdk/recovery/r24d59_godot_authorization_projection_zero_world_qualification_closure_v1.json"
    ) `
    -AuthorizationClosureSchema (
        "sporespore_qsdk_r24d59_godot_authorization_projection_zero_world_qualification_closure_v1"
    ) `
    -AuthorizationProjectionSchema (
        "sporespore_qsdk_physical_route_authorization_projection_v1"
    ) `
    -AuthorizationControlSchema (
        "sporespore_qsdk_r24d59_published_closure_authorization_control_v1"
    ) `
    -SourceAuditRelativePath (
        "sdk/conformance/r24d59_godot_authorization_projection.py"
    ) `
    -WorkerRelativePath (
        "tests/test_sdk_qsdk_r24d57_godot_native_recovery_route_ghost.gd"
    ) `
    -EvidenceDirectoryName (
        "qsdk-r24d59-godot-native-recovery-route-ghost"
    ) `
    -RawMarker "QSDK_R24D59_GODOT_NATIVE_RECOVERY_ROUTE_GHOST_RAW " `
    -ReadyMarker "QSDK_R24D59_GODOT_SUPERVISOR_TERMINATION_READY " `
    -SupervisorMarker "QSDK_R24D59_GHOST_SUPERVISOR " `
    -Seed 1802965793 `
    -SeedLabel "QSDK-R24D59/ghost/godot/route-smoke-v1" `
    -SeedSha256 (
        "sha256:6b7713211af9307aa873e63613a9433a0ec138cbd1e6ec0ed893fcd39a8d99d8"
    ) `
    -PreflightSchema "sporespore_qsdk_r24d59_ghost_preflight_v1" `
    -AttemptSchema "sporespore_qsdk_r24d59_ghost_attempt_v1" `
    -RawSchema (
        "sporespore_qsdk_r24d59_godot_native_recovery_route_ghost_raw_v1"
    ) `
    -MissingRawSchema "sporespore_qsdk_r24d59_ghost_missing_raw_result_v1" `
    -TerminalSchema "sporespore_qsdk_r24d59_ghost_terminal_v1" `
    -SupervisorResultSchema (
        "sporespore_qsdk_r24d59_ghost_supervisor_result_v1"
    ) `
    -QualifiedPhysicalPaths $qualifiedPhysicalPaths
exit $LASTEXITCODE
