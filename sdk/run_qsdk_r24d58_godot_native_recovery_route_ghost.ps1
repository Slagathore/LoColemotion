#requires -Version 7.0

<#
.SYNOPSIS
Thin R58 binding for the shared bounded Godot recovery-route ghost supervisor.

.DESCRIPTION
R58 changes only campaign identity, authority paths, the prospectively selected
non-held-out seed, and exact source population. All process, termination, CAS,
and terminal mechanics remain in the already exercised shared R57 supervisor.
#>

[CmdletBinding()]
param(
    [ValidateSet("Preflight", "Physical", "ProjectionControl")]
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
    "sdk/conformance/r24d58_godot_initializer_projection_successor.py",
    "sdk/recovery/r24d58_godot_initializer_projection_successor_contract_v1.json",
    "sdk/run_qsdk_r24d57_godot_native_recovery_route_ghost.ps1",
    "sdk/run_qsdk_r24d58_godot_native_recovery_route_ghost.ps1",
    "tests/test_sdk_qsdk_r24d57_godot_native_recovery_route_ghost.gd",
    "tests/test_sdk_qsdk_r24d58_godot_initializer_projection_zero_world.gd"
)

& $shared `
    -Mode $Mode `
    -RunPhysical:$RunPhysical `
    -AuthorizationPath $AuthorizationPath `
    -CoreLibrary $CoreLibrary `
    -EvidenceRoot $EvidenceRoot `
    -GateId "QSDK-R24D58" `
    -GateToken "R24D58" `
    -ContractRelativePath (
        "sdk/recovery/r24d58_godot_initializer_projection_successor_contract_v1.json"
    ) `
    -ClosureRelativePath (
        "sdk/recovery/r24d58_godot_initializer_projection_zero_world_qualification_closure_v1.json"
    ) `
    -AuthorizationClosureSchema (
        "sporespore_qsdk_r24d58_godot_initializer_projection_zero_world_qualification_closure_v1"
    ) `
    -SourceAuditRelativePath (
        "sdk/conformance/r24d58_godot_initializer_projection_successor.py"
    ) `
    -WorkerRelativePath (
        "tests/test_sdk_qsdk_r24d57_godot_native_recovery_route_ghost.gd"
    ) `
    -EvidenceDirectoryName (
        "qsdk-r24d58-godot-native-recovery-route-ghost"
    ) `
    -RawMarker "QSDK_R24D58_GODOT_NATIVE_RECOVERY_ROUTE_GHOST_RAW " `
    -ReadyMarker "QSDK_R24D58_GODOT_SUPERVISOR_TERMINATION_READY " `
    -SupervisorMarker "QSDK_R24D58_GHOST_SUPERVISOR " `
    -Seed 408048331 `
    -SeedLabel "QSDK-R24D58/ghost/godot/route-smoke-v1" `
    -SeedSha256 (
        "sha256:985252cbf34630f91b5eb70d2b58c8cbc38d9cc63af5f30a2405864a4f824a90"
    ) `
    -PreflightSchema "sporespore_qsdk_r24d58_ghost_preflight_v1" `
    -AttemptSchema "sporespore_qsdk_r24d58_ghost_attempt_v1" `
    -RawSchema (
        "sporespore_qsdk_r24d58_godot_native_recovery_route_ghost_raw_v1"
    ) `
    -MissingRawSchema "sporespore_qsdk_r24d58_ghost_missing_raw_result_v1" `
    -TerminalSchema "sporespore_qsdk_r24d58_ghost_terminal_v1" `
    -SupervisorResultSchema (
        "sporespore_qsdk_r24d58_ghost_supervisor_result_v1"
    ) `
    -QualifiedPhysicalPaths $qualifiedPhysicalPaths
exit $LASTEXITCODE
