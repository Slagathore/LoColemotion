#requires -Version 7.0

[CmdletBinding()]
param(
    [ValidateSet(
        "Preflight",
        "Physical",
        "RawBindingControl",
        "ProjectionControl",
        "AuthorizationControl",
        "RuntimeIdentity"
    )]
    [string]$Mode = "Preflight",
    [switch]$RunPhysical,
    [string]$AuthorizationPath = "",
    [string]$CoreLibrary = "sdk/target/debug/sporespore_locomotion_core.dll",
    [string]$EvidenceRoot = "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence",
    [string]$ConsolePath = (
        "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence\" +
        "qsdk-r24d10-exact-step-numerical-telemetry\zero-world\" +
        "20260826T190352433Z-11df9b56-65f7856d452f\artifacts\" +
        "godot.windows.editor.dev.x86_64.console.exe"
    ),
    [string]$ExpectedConsoleSha256 =
        "sha256:ff655a567d31f51628d5b21742a0618e53f9fbf8a94937dd07d9882a0739872f",
    [long]$ExpectedConsoleByteLength = 293376,
    [string]$GateId = "QSDK-R24D57",
    [string]$GateToken = "R24D57",
    [string]$ContractRelativePath =
        "sdk/recovery/r24d57_godot_jolt_native_recovery_route_contract_v1.json",
    [string]$ClosureRelativePath =
        "sdk/recovery/r24d57_godot_native_recovery_route_zero_world_qualification_closure_v1.json",
    [string]$AuthorizationClosureSchema =
        "sporespore_qsdk_r24d57_godot_native_recovery_route_zero_world_qualification_closure_v1",
    [string]$AuthorizationProjectionSchema = "",
    [string]$AuthorizationControlSchema = "",
    [string]$RuntimeIdentitySchema =
        "sporespore_qsdk_runtime_identity_control_v1",
    [string]$RawBindingControlSchema = "",
    [string]$SourceAuditRelativePath =
        "sdk/conformance/r24d57_godot_native_recovery_route.py",
    [string]$WorkerRelativePath =
        "tests/test_sdk_qsdk_r24d57_godot_native_recovery_route_ghost.gd",
    [string]$EvidenceDirectoryName =
        "qsdk-r24d57-godot-native-recovery-route-ghost",
    [string]$RawMarker =
        "QSDK_R24D57_GODOT_NATIVE_RECOVERY_ROUTE_GHOST_RAW ",
    [string]$ReadyMarker =
        "QSDK_R24D57_GODOT_SUPERVISOR_TERMINATION_READY ",
    [string]$SupervisorMarker = "QSDK_R24D57_GHOST_SUPERVISOR ",
    [int]$Seed = 1656561876,
    [string]$SeedLabel = "QSDK-R24D57/ghost/godot/route-smoke-v1",
    [string]$SeedSha256 =
        "sha256:e2bd20d4ef59f793681f47e1639dcf4b4079f321368f85dd414ad08dd714669d",
    [string]$PreflightSchema = "sporespore_qsdk_r24d57_ghost_preflight_v1",
    [string]$AttemptSchema = "sporespore_qsdk_r24d57_ghost_attempt_v1",
    [string]$RawSchema =
        "sporespore_qsdk_r24d57_godot_native_recovery_route_ghost_raw_v1",
    [string]$MissingRawSchema =
        "sporespore_qsdk_r24d57_ghost_missing_raw_result_v1",
    [string]$TerminalSchema = "sporespore_qsdk_r24d57_ghost_terminal_v1",
    [string]$SupervisorResultSchema =
        "sporespore_qsdk_r24d57_ghost_supervisor_result_v1",
    [ValidateSet("integration_ghost", "behavior_development")]
    [string]$PhysicalQuestionKind = "integration_ghost",
    [ValidateSet(
        "legacy_velocity_motor_v1",
        "solver_coupled_native_constraint_motor_v1",
        "force_based_joint_impulse_v1",
        "force_based_native_angular_velocity_guarded_v1",
        "force_based_nested_native_angular_velocity_guarded_v1",
        "force_based_component_norm_nested_native_angular_velocity_guarded_v1",
        "force_based_refinement_safe_component_norm_nested_native_angular_velocity_guarded_v1",
        "force_based_order_neutral_population_native_angular_velocity_guarded_v1",
        "force_based_order_neutral_joint_target_monotone_population_native_angular_velocity_guarded_v2",
        "force_based_order_neutral_joint_space_effective_inertia_native_angular_velocity_guarded_v3"
    )]
    [string]$ActuatorMode = "legacy_velocity_motor_v1",
    [ValidateSet(
        "sporespore_exact_s169_prone_to_standing_controller_v1",
        "sporespore_exact_s169_prone_to_standing_controller_v2",
        "sporespore_exact_s169_prone_to_standing_controller_v3",
        "sporespore_exact_s169_prone_to_standing_controller_v4",
        "sporespore_exact_s169_prone_to_standing_controller_v5",
        "sporespore_exact_s169_prone_to_standing_controller_v6"
    )]
    [string]$RecoveryControllerId =
        "sporespore_exact_s169_prone_to_standing_controller_v1",
    [ValidateSet(
        "sporespore_qsdk_r24d57_godot_jolt_recovery_observation_v3_route_v1",
        "sporespore_qsdk_r24d136_godot_jolt_complete_energy_recovery_observation_v3_route_v1",
        "sporespore_qsdk_r24d144_godot_jolt_solver_coupled_complete_energy_recovery_observation_v3_route_v1",
        "sporespore_qsdk_r24d148_godot_jolt_discrete_staging_complete_energy_recovery_observation_v3_route_v1"
    )]
    [string]$RecoveryEnergyRouteId =
        "sporespore_qsdk_r24d57_godot_jolt_recovery_observation_v3_route_v1",
    [int]$MaximumModelConstructionAttemptCount = 1,
    [int]$MaximumModelConstructionCount = 1,
    [int]$MaximumWorldAttemptCount = 1,
    [int]$MaximumWorldBuildCount = 1,
    [long]$MaximumOuterSolverSteps = 2,
    [int]$ExpectedModelConstructionCount = 1,
    [int]$ExpectedWorldAttemptCount = 1,
    [int]$ExpectedWorldBuildCount = 1,
    [long]$MinimumCompletedSolverSteps = 2,
    [int]$ExpectedBehaviorEvaluatorInvocationCount = 0,
    [string]$ValidCompleteStatus = "valid_complete_integration_ghost",
    [string]$InvalidOrIncompleteStatus = "invalid_or_incomplete_integration_ghost",
    [string]$PhysicalWorkId = "",
    [string]$ProgressMarker = "",
    [int]$ProgressCadenceSteps = 0,
    [int]$ProgressStallTimeoutSeconds = 0,
    [int]$MinimumProgressMarkerCount = 0,
    [int]$PhysicalTimeoutSeconds = 120,
    [string[]]$QualifiedPhysicalPaths = @(
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
        "tests/test_sdk_qsdk_r24d57_godot_native_recovery_route_ghost.gd"
    )
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$expectedRoot = "C:\Users\Cole\CodeStuff\games\SporeSpore"
$expectedRemote = "https://github.com/Slagathore/sporespore.git"
$expectedEvidenceRoot = "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence"
$contractRelative = $ContractRelativePath
$closureRelative = $ClosureRelativePath
$sourceAuditRelative = $SourceAuditRelativePath
$workerRelative = $WorkerRelativePath
$consolePath = [IO.Path]::GetFullPath($ConsolePath)
$expectedConsoleSha = $ExpectedConsoleSha256
$expectedConsoleBytes = $ExpectedConsoleByteLength
$rawMarker = $RawMarker
$readyMarker = $ReadyMarker
$progressMarker = $ProgressMarker
$supervisorMarker = $SupervisorMarker
$seed = $Seed
$seedSha = $SeedSha256
$physicsHz = 120
$outerStepDurationS = 1.0 / [double]$physicsHz
$qualifiedPhysicalPaths = @($QualifiedPhysicalPaths)
$behaviorDevelopment = $PhysicalQuestionKind -ceq "behavior_development"
$actuatorModeValue = $ActuatorMode
$recoveryControllerIdValue = $RecoveryControllerId
$recoveryEnergyRouteIdValue = $RecoveryEnergyRouteId
$progressEnabled = -not [string]::IsNullOrEmpty($progressMarker)
$physicalWorkIdValue = if ([string]::IsNullOrWhiteSpace($PhysicalWorkId)) {
    "$GateId-GODOT-JOLT-NATIVE-RECOVERY-ROUTE-GHOST"
} else { $PhysicalWorkId }

if ($MaximumModelConstructionAttemptCount -lt 1 -or
    $MaximumModelConstructionCount -lt 1 -or
    $MaximumWorldAttemptCount -lt 1 -or
    $MaximumWorldBuildCount -lt 1 -or
    $MaximumOuterSolverSteps -lt 1 -or
    $ExpectedModelConstructionCount -lt 1 -or
    $ExpectedWorldAttemptCount -lt 1 -or
    $ExpectedWorldBuildCount -lt 1 -or
    $MinimumCompletedSolverSteps -lt 1 -or
    $MinimumCompletedSolverSteps -gt $MaximumOuterSolverSteps -or
    $ExpectedBehaviorEvaluatorInvocationCount -lt 0 -or
    [string]::IsNullOrWhiteSpace($ValidCompleteStatus) -or
    [string]::IsNullOrWhiteSpace($InvalidOrIncompleteStatus) -or
    [string]::IsNullOrWhiteSpace($physicalWorkIdValue) -or
    -not ($expectedConsoleSha -cmatch '^sha256:[0-9a-f]{64}$') -or
    $expectedConsoleBytes -lt 1 -or
    $PhysicalTimeoutSeconds -lt 1 -or
    (
        $progressEnabled -and (
            $ProgressCadenceSteps -lt 1 -or
            $ProgressCadenceSteps -gt $MaximumOuterSolverSteps -or
            $ProgressStallTimeoutSeconds -lt 1 -or
            $ProgressStallTimeoutSeconds -ge $PhysicalTimeoutSeconds -or
            $MinimumProgressMarkerCount -lt 1
        )
    ) -or
    (
        -not $progressEnabled -and (
            $ProgressCadenceSteps -ne 0 -or
            $ProgressStallTimeoutSeconds -ne 0 -or
            $MinimumProgressMarkerCount -ne 0
        )
    )) {
    throw "$GateId ghost supervisor: physical_configuration_invalid"
}

. (Join-Path $PSScriptRoot "locomotion_operation_lock.ps1")
. (Join-Path $PSScriptRoot "godot_receipt_terminated_process.ps1")
. (Join-Path $PSScriptRoot "content_addressed_artifact_store.ps1")
. (Join-Path $PSScriptRoot "physical_authorization_projection.ps1")

function Assert-R57 {
    param([bool]$Condition, [string]$Code)
    if (-not $Condition) { throw "$GateId ghost supervisor: $Code" }
}

function Test-R57RawBinding {
    param(
        [Parameter(Mandatory)][System.Collections.IDictionary]$Raw,
        [Parameter(Mandatory)][string]$ExpectedSourceCommit,
        [Parameter(Mandatory)][string]$ExpectedAttemptId,
        [Parameter(Mandatory)][string]$ExpectedAuthorizationSha256,
        [Parameter(Mandatory)][int]$ExpectedSeed,
        [Parameter(Mandatory)][string]$ExpectedSeedSha256
    )
    return (
        $Raw.Contains("energy_route_id") -and
        ([string]$Raw["schema_version"]) -ceq $RawSchema -and
        ([string]$Raw["gate_id"]) -ceq $GateId -and
        ([string]$Raw["question_class"]) -ceq "development" -and
        ([string]$Raw["source_commit"]) -ceq $ExpectedSourceCommit -and
        ([string]$Raw["attempt_id"]) -ceq $ExpectedAttemptId -and
        ([string]$Raw["authorization_sha256"]) -ceq
            $ExpectedAuthorizationSha256 -and
        ([int]$Raw["seed"]) -eq $ExpectedSeed -and
        ([string]$Raw["seed_sha256"]) -ceq $ExpectedSeedSha256 -and
        ([string]$Raw["recovery_controller_id"]) -ceq
            $recoveryControllerIdValue -and
        ([string]$Raw["energy_route_id"]) -ceq $recoveryEnergyRouteIdValue -and
        ($behaviorDevelopment -or
            ([string]$Raw["actuator_mode"]) -ceq $actuatorModeValue) -and
        ([int]$Raw["physics_ticks_per_second"]) -eq $physicsHz -and
        ([double]$Raw["outer_step_duration_s"]) -eq $outerStepDurationS -and
        -not ([bool]$Raw["held_out"]) -and
        ([int]$Raw["model_construction_attempt_count"]) -le
            $MaximumModelConstructionAttemptCount -and
        ([int]$Raw["model_construction_count"]) -le
            $MaximumModelConstructionCount -and
        ([int]$Raw["world_attempt_count"]) -le $MaximumWorldAttemptCount -and
        ([int]$Raw["world_build_count"]) -le $MaximumWorldBuildCount -and
        ([long]$Raw["solver_step_count"]) -le $MaximumOuterSolverSteps -and
        ($behaviorDevelopment -or
            -not ([bool]$Raw["prone_to_standing_claimed"])) -and
        -not ([bool]$Raw["physical_acceptance_authority"]) -and
        -not ([bool]$Raw["release_authority"])
    )
}

function New-R57SupervisorProjection {
    param(
        [Parameter(Mandatory)][System.Collections.IDictionary]$Summary,
        [Parameter(Mandatory)][int]$ExitCode
    )
    return [pscustomobject]@{
        output_line = $supervisorMarker + (
            $Summary | ConvertTo-Json -Depth 40 -Compress
        )
        exit_code = $ExitCode
    }
}

function Get-R57Git {
    param([Parameter(Mandatory)][string[]]$Arguments)
    $output = @(& git -C $repoRoot @Arguments 2>&1)
    Assert-R57 ($LASTEXITCODE -eq 0) "git_$($Arguments -join '_'):$($output -join '|')"
    return ($output -join "`n").Trim()
}

function Get-R57Sha {
    param([Parameter(Mandatory)][string]$Path)
    return "sha256:" + (
        Get-FileHash -LiteralPath $Path -Algorithm SHA256
    ).Hash.ToLowerInvariant()
}

function Write-R57Json {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][object]$Value
    )
    [IO.File]::WriteAllText(
        $Path,
        ($Value | ConvertTo-Json -Depth 100 -Compress) + "`n",
        [Text.UTF8Encoding]::new($false)
    )
}

function Get-R57RepositoryBoundary {
    $root = Get-R57Git @("rev-parse", "--show-toplevel")
    $remote = Get-R57Git @("remote", "get-url", "origin")
    $branch = Get-R57Git @("branch", "--show-current")
    $head = Get-R57Git @("rev-parse", "HEAD")
    $upstream = Get-R57Git @("rev-parse", "@{upstream}")
    $cached = Get-R57Git @("rev-parse", "refs/remotes/origin/main")
    $liveText = Get-R57Git @("ls-remote", "--heads", "origin", "refs/heads/main")
    $live = $liveText.Split("`t")[0]
    $status = Get-R57Git @("status", "--short")
    $worktreeText = Get-R57Git @("worktree", "list", "--porcelain")
    $worktreeCount = @($worktreeText -split "`r?`n" | Where-Object {
        $_.StartsWith("worktree ", [StringComparison]::Ordinal)
    }).Count
    Assert-R57 ([IO.Path]::GetFullPath($root) -ceq $expectedRoot) "repository_root"
    Assert-R57 ($repoRoot -ceq $expectedRoot) "runner_root"
    Assert-R57 ($remote -ceq $expectedRemote) "repository_remote"
    Assert-R57 ($branch -ceq "main") "branch"
    Assert-R57 ([string]::IsNullOrEmpty($status)) "dirty_worktree"
    Assert-R57 (
        $head -ceq $upstream -and $head -ceq $cached -and $head -ceq $live
    ) "local_upstream_cached_live_inequality"
    Assert-R57 ($worktreeCount -eq 1) "worktree_count"
    return [ordered]@{
        root = $root.Replace("\", "/")
        remote = $remote
        branch = $branch
        head = $head
        upstream = $upstream
        cached_origin_main = $cached
        live_origin_main = $live
        worktree_count = $worktreeCount
        worktree_clean = $true
    }
}

function Assert-R57Console {
    Assert-R57 (Test-Path -LiteralPath $consolePath -PathType Leaf) "console_missing"
    Assert-R57 ((Get-R57Sha $consolePath) -ceq $expectedConsoleSha) "console_sha"
    Assert-R57 ((Get-Item -LiteralPath $consolePath).Length -eq $expectedConsoleBytes) (
        "console_length"
    )
}

function Invoke-R57RuntimeIdentity {
    Assert-R57 (-not $RunPhysical.IsPresent) "runtime_identity_cannot_run_physics"
    Assert-R57 ($Mode -ceq "RuntimeIdentity") "runtime_identity_mode_required"
    Assert-R57 (-not [string]::IsNullOrWhiteSpace($RuntimeIdentitySchema)) (
        "runtime_identity_schema_required"
    )
    Assert-R57Console
    $check = @(
        & $consolePath --headless --path $repoRoot --check-only --script (
            "res://" + $workerRelative.Replace("\", "/")
        ) 2>&1
    )
    Assert-R57 ($LASTEXITCODE -eq 0) "worker_parse:$($check -join '|')"
    return [ordered]@{
        schema_version = $RuntimeIdentitySchema
        gate_id = $GateId
        ok = $true
        selected_console_path = $consolePath.Replace("\", "/")
        selected_console_sha256 = Get-R57Sha $consolePath
        selected_console_byte_length = (Get-Item -LiteralPath $consolePath).Length
        worker_relative_path = $workerRelative.Replace("\", "/")
        actuator_mode = $actuatorModeValue
        recovery_controller_id = $recoveryControllerIdValue
        recovery_energy_route_id = $recoveryEnergyRouteIdValue
        worker_parse_count = 1
        source_audit_execution_count = 0
        model_construction_count = 0
        world_attempt_count = 0
        world_build_count = 0
        solver_step_count = 0
        physics_state_modified = $false
        physical_execution_authorized = $false
        physical_acceptance_authority = $false
        release_authority = $false
    }
}

function Invoke-R57Preflight {
    $libraryPath = [IO.Path]::GetFullPath((Join-Path $repoRoot $CoreLibrary))
    Assert-R57 (Test-Path -LiteralPath $libraryPath -PathType Leaf) "core_library_missing"
    $auditPath = Join-Path $repoRoot $sourceAuditRelative
    $output = @(& python $auditPath --core-library $libraryPath 2>&1)
    Assert-R57 ($LASTEXITCODE -eq 0) "source_preflight:$($output -join '|')"
    Assert-R57Console
    $check = @(
        & $consolePath --headless --path $repoRoot --check-only --script (
            "res://" + $workerRelative.Replace("\", "/")
        ) 2>&1
    )
    Assert-R57 ($LASTEXITCODE -eq 0) "worker_parse:$($check -join '|')"
    return [ordered]@{
        schema_version = $PreflightSchema
        gate_id = $GateId
        ok = $true
        selected_console_path = $consolePath.Replace("\", "/")
        selected_console_sha256 = Get-R57Sha $consolePath
        selected_console_byte_length = (Get-Item -LiteralPath $consolePath).Length
        source_audit_and_runtime_preflight_count = 1
        worker_parse_count = 1
        actuator_mode = $actuatorModeValue
        recovery_controller_id = $recoveryControllerIdValue
        recovery_energy_route_id = $recoveryEnergyRouteIdValue
        model_construction_count = 0
        world_attempt_count = 0
        world_build_count = 0
        solver_step_count = 0
        physics_state_modified = $false
        physical_execution_authorized = $false
        physical_acceptance_authority = $false
        release_authority = $false
    }
}

function Invoke-R57RawBindingControl {
    Assert-R57 (-not $RunPhysical.IsPresent) "raw_binding_control_cannot_run_physics"
    Assert-R57 ($Mode -ceq "RawBindingControl") "raw_binding_control_mode_required"
    Assert-R57 (-not [string]::IsNullOrWhiteSpace($RawBindingControlSchema)) (
        "raw_binding_control_schema_required"
    )
    $controlSourceCommit = "raw-binding-control-source"
    $controlAttemptId = "raw-binding-control-attempt"
    $controlAuthorizationSha =
        "sha256:0000000000000000000000000000000000000000000000000000000000000000"
    $controlSeed = 1
    $controlSeedSha =
        "sha256:1111111111111111111111111111111111111111111111111111111111111111"
    $controlRaw = [ordered]@{
        schema_version = $RawSchema
        gate_id = $GateId
        question_class = "development"
        source_commit = $controlSourceCommit
        attempt_id = $controlAttemptId
        authorization_sha256 = $controlAuthorizationSha
        seed = $controlSeed
        seed_sha256 = $controlSeedSha
        recovery_controller_id = $recoveryControllerIdValue
        energy_route_id = $recoveryEnergyRouteIdValue
        actuator_mode = $actuatorModeValue
        physics_ticks_per_second = $physicsHz
        outer_step_duration_s = $outerStepDurationS
        held_out = $false
        model_construction_attempt_count = 0
        model_construction_count = 0
        world_attempt_count = 0
        world_build_count = 0
        solver_step_count = 0
        prone_to_standing_claimed = $false
        physical_acceptance_authority = $false
        release_authority = $false
    }
    $bindingArguments = @{
        ExpectedSourceCommit = $controlSourceCommit
        ExpectedAttemptId = $controlAttemptId
        ExpectedAuthorizationSha256 = $controlAuthorizationSha
        ExpectedSeed = $controlSeed
        ExpectedSeedSha256 = $controlSeedSha
    }
    $positivePassed = Test-R57RawBinding -Raw $controlRaw @bindingArguments

    $missingRouteRaw = [ordered]@{} + $controlRaw
    [void]$missingRouteRaw.Remove("energy_route_id")
    $missingRouteRejected = -not (
        Test-R57RawBinding -Raw $missingRouteRaw @bindingArguments
    )

    $wrongRouteRaw = [ordered]@{} + $controlRaw
    $wrongRouteRaw["energy_route_id"] = "raw-binding-control-wrong-route"
    $wrongRouteRejected = -not (
        Test-R57RawBinding -Raw $wrongRouteRaw @bindingArguments
    )

    $legacyOnlyRaw = [ordered]@{} + $missingRouteRaw
    $legacyOnlyRaw["recovery_energy_route_id"] = $recoveryEnergyRouteIdValue
    $legacyOnlyRejected = -not (
        Test-R57RawBinding -Raw $legacyOnlyRaw @bindingArguments
    )

    Assert-R57 (
        $positivePassed -and $missingRouteRejected -and
        $wrongRouteRejected -and $legacyOnlyRejected
    ) "raw_binding_control_predicate"
    return [ordered]@{
        schema_version = $RawBindingControlSchema
        gate_id = $GateId
        ok = $true
        production_route_field = "energy_route_id"
        rejected_legacy_only_route_field = "recovery_energy_route_id"
        positive_case_count = 1
        positive_pass_count = 1
        forced_failure_case_count = 3
        forced_failure_pass_count = 3
        positive_checks = [ordered]@{
            exact_energy_route_id = $positivePassed
        }
        forced_failure_checks = [ordered]@{
            missing_energy_route_id = $missingRouteRejected
            wrong_energy_route_id = $wrongRouteRejected
            legacy_only_recovery_energy_route_id = $legacyOnlyRejected
        }
        model_construction_count = 0
        world_attempt_count = 0
        world_build_count = 0
        solver_step_count = 0
        physics_state_modified = $false
        physics_evidence_authority = $false
        physical_execution_authorized = $false
        physical_acceptance_authority = $false
        release_authority = $false
    }
}

function Get-R57Authorization {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][System.Collections.IDictionary]$Repository
    )
    $expectedPath = [IO.Path]::GetFullPath((Join-Path $repoRoot $closureRelative))
    $resolved = [IO.Path]::GetFullPath($Path)
    Assert-R57 ($resolved -ceq $expectedPath) "authorization_path"
    Assert-R57 (Test-Path -LiteralPath $resolved -PathType Leaf) "authorization_missing"
    $closure = Get-Content -Raw -LiteralPath $resolved |
        ConvertFrom-Json -AsHashtable -Depth 100
    $projection = $null
    if ([string]::IsNullOrWhiteSpace($AuthorizationProjectionSchema)) {
        Assert-R57 (
            [string]$closure.schema_version -ceq $AuthorizationClosureSchema -and
            [string]$closure.gate_id -ceq $GateId -and
            [string]$closure.question_class -ceq "development" -and
            [bool]$closure.qualification.official_zero_world_qualification_passed -and
            [int]$closure.qualification.model_construction_count -eq 0 -and
            [int]$closure.qualification.world_attempt_count -eq 0 -and
            [int]$closure.qualification.world_build_count -eq 0 -and
            [int]$closure.qualification.solver_step_count -eq 0 -and
            (Test-SporeSporeDirectQuestionAuthorization `
                -Closure $closure `
                -PhysicalQuestionKind $PhysicalQuestionKind) -and
            [int]$closure.decision.maximum_world_build_count -eq
                $MaximumWorldBuildCount -and
            [int]$closure.decision.maximum_outer_solver_steps -eq
                $MaximumOuterSolverSteps -and
            [int]$closure.decision.physics_ticks_per_second -eq $physicsHz -and
            [double]$closure.decision.outer_step_duration_s -eq $outerStepDurationS -and
            [int]$closure.decision.seed -eq $seed -and
            [string]$closure.decision.seed_sha256 -ceq $seedSha -and
            -not [bool]$closure.decision.held_out -and
            -not [bool]$closure.claim_boundary.prone_to_standing_claimed -and
            -not [bool]$closure.claim_boundary.physical_acceptance_authority -and
            -not [bool]$closure.claim_boundary.release_authority
        ) "authorization_content"
        $freeze = [string]$closure.source.source_freeze_commit
    } else {
        try {
            $projection = ConvertTo-SporeSporePhysicalAuthorizationProjection `
                -Closure $closure `
                -ClosureSchema $AuthorizationClosureSchema `
                -ProjectionSchema $AuthorizationProjectionSchema `
                -GateId $GateId `
                -Seed $seed `
                -SeedLabel $SeedLabel `
                -SeedSha256 $seedSha `
                -PhysicsTicksPerSecond $physicsHz `
                -MaximumModelConstructionAttemptCount `
                    $MaximumModelConstructionAttemptCount `
                -MaximumModelConstructionCount $MaximumModelConstructionCount `
                -MaximumWorldAttemptCount $MaximumWorldAttemptCount `
                -MaximumWorldBuildCount $MaximumWorldBuildCount `
                -MaximumOuterSolverSteps $MaximumOuterSolverSteps
        } catch {
            Assert-R57 $false "authorization_projection:$($_.Exception.Message)"
        }
        $freeze = [string]$projection.source_freeze_commit
    }
    Assert-R57 ($freeze.Length -eq 40) "freeze_commit"
    $ancestor = Get-R57Git @("merge-base", "--is-ancestor", $freeze, $Repository.head)
    # A successful merge-base invocation has intentionally empty stdout.
    Assert-R57 ([string]::IsNullOrEmpty($ancestor)) "freeze_not_ancestor"
    & git -C $repoRoot diff --quiet $freeze $Repository.head -- @qualifiedPhysicalPaths
    Assert-R57 ($LASTEXITCODE -eq 0) "qualified_physical_source_drift"
    $committed = Get-R57Git @("ls-files", "--error-unmatch", $closureRelative)
    Assert-R57 ($committed -ceq $closureRelative) "authorization_uncommitted"
    return [ordered]@{
        path = $resolved.Replace("\", "/")
        raw_sha256 = Get-R57Sha $resolved
        byte_length = (Get-Item -LiteralPath $resolved).Length
        source_freeze_commit = $freeze
        qualified_physical_path_count = $qualifiedPhysicalPaths.Count
        projection = $projection
        closure = $closure
    }
}

function Get-R57AuthorizationControlReceipt {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][System.Collections.IDictionary]$Repository,
        [Parameter(Mandatory)][System.Collections.IDictionary]$Authorization
    )
    Assert-R57 (-not [string]::IsNullOrWhiteSpace($AuthorizationControlSchema)) (
        "authorization_control_schema_required"
    )
    $resolved = [IO.Path]::GetFullPath($Path)
    $controlRoot = [IO.Path]::GetFullPath((
        Join-Path $EvidenceRoot "$EvidenceDirectoryName-authorization-control"
    ))
    Assert-R57 ($resolved.StartsWith(
        $controlRoot + [IO.Path]::DirectorySeparatorChar,
        [StringComparison]::Ordinal
    )) "authorization_control_path"
    Assert-R57 (Test-Path -LiteralPath $resolved -PathType Leaf) (
        "authorization_control_missing"
    )
    $receipt = Get-Content -Raw -LiteralPath $resolved |
        ConvertFrom-Json -AsHashtable -Depth 100
    $controlCommit = [string]$receipt.source.control_commit
    $receiptProjectionJson = $receipt.authorization.projection |
        ConvertTo-Json -Depth 100 -Compress
    $authorizationProjectionJson = $Authorization.projection |
        ConvertTo-Json -Depth 100 -Compress
    Assert-R57 (
        [string]$receipt.schema_version -ceq $AuthorizationControlSchema -and
        [string]$receipt.gate_id -ceq $GateId -and
        [string]$receipt.question_class -ceq "development" -and
        [bool]$receipt.ok -and
        [string]$receipt.status -ceq "published_closure_authorization_control_passed" -and
        $controlCommit -cmatch '^[0-9a-f]{40}$' -and
        [string]$receipt.authorization.path -ceq $Authorization.path -and
        [string]$receipt.authorization.raw_sha256 -ceq $Authorization.raw_sha256 -and
        [long]$receipt.authorization.byte_length -eq [long]$Authorization.byte_length -and
        [string]$receipt.authorization.source_freeze_commit -ceq
            [string]$Authorization.source_freeze_commit -and
        [string]$receipt.authorization.projection.schema_version -ceq
            $AuthorizationProjectionSchema -and
        [string]$receipt.authorization.projection.gate_id -ceq $GateId -and
        [string]$receipt.authorization.projection.source_freeze_commit -ceq
            [string]$Authorization.source_freeze_commit -and
        [int]$receipt.authorization.projection.seed -eq $seed -and
        [string]$receipt.authorization.projection.seed_sha256 -ceq $seedSha -and
        $receiptProjectionJson -ceq $authorizationProjectionJson -and
        [string]$receipt.source.repository.root -ceq
            $expectedRoot.Replace("\", "/") -and
        [string]$receipt.source.repository.remote -ceq $expectedRemote -and
        [string]$receipt.source.repository.branch -ceq "main" -and
        [string]$receipt.source.repository.head -ceq $controlCommit -and
        [string]$receipt.source.repository.upstream -ceq $controlCommit -and
        [string]$receipt.source.repository.cached_origin_main -ceq $controlCommit -and
        [string]$receipt.source.repository.live_origin_main -ceq $controlCommit -and
        [int]$receipt.source.repository.worktree_count -eq 1 -and
        [bool]$receipt.source.repository.worktree_clean -and
        [bool]$receipt.preflight.ok -and
        [string]$receipt.preflight.gate_id -ceq $GateId -and
        [int]$receipt.preflight.model_construction_count -eq 0 -and
        [int]$receipt.preflight.world_attempt_count -eq 0 -and
        [int]$receipt.preflight.world_build_count -eq 0 -and
        [int]$receipt.preflight.solver_step_count -eq 0 -and
        [bool]$receipt.operation_lock.acquired -and
        [bool]$receipt.operation_lock.released -and
        [string]$receipt.operation_lock.role -ceq "conformance" -and
        -not [bool]$receipt.operation_lock.test_only -and
        -not [bool]$receipt.operation_lock.abandoned_owner_recovered -and
        [int]$receipt.model_construction_count -eq 0 -and
        [int]$receipt.world_attempt_count -eq 0 -and
        [int]$receipt.world_build_count -eq 0 -and
        [int]$receipt.solver_step_count -eq 0 -and
        [int]$receipt.physical_execution_count -eq 0 -and
        -not [bool]$receipt.physics_state_modified -and
        [bool]$receipt.next_physical_invocation_authorized -and
        -not [bool]$receipt.held_out -and
        -not [bool]$receipt.same_identity_rerun_permitted -and
        -not [bool]$receipt.prone_to_standing_claimed -and
        -not [bool]$receipt.physical_acceptance_authority -and
        -not [bool]$receipt.release_authority
    ) "authorization_control_content"
    $ancestor = Get-R57Git @(
        "merge-base", "--is-ancestor", $controlCommit, $Repository.head
    )
    Assert-R57 ([string]::IsNullOrEmpty($ancestor)) (
        "authorization_control_commit_not_ancestor"
    )
    & git -C $repoRoot diff --quiet $controlCommit $Repository.head -- @qualifiedPhysicalPaths
    Assert-R57 ($LASTEXITCODE -eq 0) "authorization_control_source_drift"
    return [ordered]@{
        path = $resolved.Replace("\", "/")
        raw_sha256 = Get-R57Sha $resolved
        byte_length = (Get-Item -LiteralPath $resolved).Length
        control_commit = $controlCommit
        receipt = $receipt
    }
}

function Find-R57AuthorizationControlReceipts {
    param(
        [Parameter(Mandatory)][System.Collections.IDictionary]$Repository,
        [Parameter(Mandatory)][System.Collections.IDictionary]$Authorization
    )
    $root = Join-Path $EvidenceRoot "$EvidenceDirectoryName-authorization-control"
    if (-not (Test-Path -LiteralPath $root -PathType Container)) { return @() }
    $results = @()
    foreach ($candidate in @(Get-ChildItem -LiteralPath $root -File -Recurse |
        Where-Object { $_.Name -ceq "authorization_control.json" } |
        Sort-Object FullName)) {
        $results += ,(Get-R57AuthorizationControlReceipt `
            -Path $candidate.FullName `
            -Repository $Repository `
            -Authorization $Authorization)
    }
    return @($results)
}

function Invoke-R57AuthorizationControl {
    Assert-R57 (-not $RunPhysical.IsPresent) (
        "authorization_control_cannot_run_physics"
    )
    Assert-R57 ($Mode -ceq "AuthorizationControl") (
        "authorization_control_mode_required"
    )
    Assert-R57 (-not [string]::IsNullOrWhiteSpace($AuthorizationProjectionSchema)) (
        "authorization_projection_schema_required"
    )
    Assert-R57 (-not [string]::IsNullOrWhiteSpace($AuthorizationControlSchema)) (
        "authorization_control_schema_required"
    )
    Assert-R57 (
        [IO.Path]::GetFullPath($EvidenceRoot) -ceq $expectedEvidenceRoot
    ) "evidence_root"
    Assert-R57 (-not [string]::IsNullOrWhiteSpace($AuthorizationPath)) (
        "authorization_path_required"
    )

    $lock = Enter-SporeSporeLocomotionOperationLock -Role conformance
    Assert-R57 ([bool]$lock.acquired) "operation_lock"
    $receipt = $null
    $controlRoot = $null
    $receiptPath = $null
    try {
        $repository = Get-R57RepositoryBoundary
        $preflight = Invoke-R57Preflight
        $authorization = Get-R57Authorization `
            -Path $AuthorizationPath `
            -Repository $repository
        $existing = @(Find-R57AuthorizationControlReceipts `
            -Repository $repository `
            -Authorization $authorization)
        Assert-R57 ($existing.Count -eq 0) (
            "authorization_control_already_exists:$($existing.Count)"
        )
        $controlId = [guid]::NewGuid().ToString("N")
        $stamp = [DateTime]::UtcNow.ToString("yyyyMMddTHHmmssfffZ")
        $controlRoot = Join-Path $EvidenceRoot (
            "$EvidenceDirectoryName-authorization-control\" +
            "$stamp-$($repository.head.Substring(0, 8))-$($controlId.Substring(0, 8))"
        )
        $publicLock = Get-SporeSporeLocomotionOperationLockPublicReceipt $lock
        $publicLock["released"] = $false
        $receipt = [ordered]@{
            schema_version = $AuthorizationControlSchema
            gate_id = $GateId
            question_class = "development"
            ok = $true
            status = "published_closure_authorization_control_passed"
            control_id = $controlId
            completed_utc = [DateTimeOffset]::UtcNow.ToString("o")
            source = [ordered]@{
                control_commit = $repository.head
                repository = $repository
            }
            authorization = [ordered]@{
                path = $authorization.path
                raw_sha256 = $authorization.raw_sha256
                byte_length = $authorization.byte_length
                source_freeze_commit = $authorization.source_freeze_commit
                projection = $authorization.projection
            }
            preflight = $preflight
            operation_lock = $publicLock
            model_construction_count = 0
            world_attempt_count = 0
            world_build_count = 0
            solver_step_count = 0
            physical_execution_count = 0
            physics_state_modified = $false
            next_physical_invocation_authorized = $true
            held_out = $false
            same_identity_rerun_permitted = $false
            prone_to_standing_claimed = $false
            physical_acceptance_authority = $false
            release_authority = $false
        }
        # Materialize a fail-closed provisional receipt while the serialized
        # lock is still held. A concurrent control can never observe an empty
        # population between lock release and durable receipt creation.
        [void][IO.Directory]::CreateDirectory($controlRoot)
        $receiptPath = Join-Path $controlRoot "authorization_control.json"
        Write-R57Json -Path $receiptPath -Value $receipt
    } finally {
        Exit-SporeSporeLocomotionOperationLock -Receipt $lock
    }
    Assert-R57 ($null -ne $receipt) "authorization_control_receipt_missing"
    $receipt.operation_lock["released"] = [bool]$lock.released
    Assert-R57 ([bool]$receipt.operation_lock.released) (
        "authorization_control_lock_not_released"
    )
    # Publish the terminal form only after the shared lock reports release.
    Write-R57Json -Path $receiptPath -Value $receipt
    $summary = [ordered]@{
        schema_version = $AuthorizationControlSchema
        gate_id = $GateId
        ok = $true
        status = "published_closure_authorization_control_passed"
        control_id = [string]$receipt.control_id
        evidence_root = $controlRoot.Replace("\", "/")
        authorization_control_sha256 = Get-R57Sha $receiptPath
        model_construction_count = 0
        world_attempt_count = 0
        world_build_count = 0
        solver_step_count = 0
        physical_execution_count = 0
        next_physical_invocation_authorized = $true
        physical_acceptance_authority = $false
        release_authority = $false
    }
    return New-R57SupervisorProjection -Summary $summary -ExitCode 0
}

function Invoke-R57Physical {
    Assert-R57 ($RunPhysical.IsPresent) "physical_switch_required"
    Assert-R57 ($Mode -ceq "Physical") "physical_mode_required"
    Assert-R57 (
        [IO.Path]::GetFullPath($EvidenceRoot) -ceq $expectedEvidenceRoot
    ) "evidence_root"
    $repository = Get-R57RepositoryBoundary
    $preflight = Invoke-R57Preflight
    Assert-R57 (-not [string]::IsNullOrWhiteSpace($AuthorizationPath)) (
        "authorization_path_required"
    )
    $authorization = Get-R57Authorization -Path $AuthorizationPath -Repository $repository
    $authorizationControl = $null
    if (-not [string]::IsNullOrWhiteSpace($AuthorizationProjectionSchema)) {
        Assert-R57 (-not [string]::IsNullOrWhiteSpace($AuthorizationControlSchema)) (
            "authorization_control_schema_required"
        )
        $authorizationControls = @(Find-R57AuthorizationControlReceipts `
            -Repository $repository `
            -Authorization $authorization)
        Assert-R57 ($authorizationControls.Count -eq 1) (
            "authorization_control_count:$($authorizationControls.Count)"
        )
        $authorizationControl = $authorizationControls[0]
    }
    $lock = Enter-SporeSporeLocomotionOperationLock -Role physical_development
    Assert-R57 ([bool]$lock.acquired) "operation_lock"
    try {
        # Recheck after acquiring the global physical/conformance writer lock.
        $repository = Get-R57RepositoryBoundary
        $authorization = Get-R57Authorization `
            -Path $AuthorizationPath `
            -Repository $repository
        if (-not [string]::IsNullOrWhiteSpace($AuthorizationProjectionSchema)) {
            $authorizationControls = @(Find-R57AuthorizationControlReceipts `
                -Repository $repository `
                -Authorization $authorization)
            Assert-R57 ($authorizationControls.Count -eq 1) (
                "authorization_control_count_after_lock:$($authorizationControls.Count)"
            )
            $authorizationControl = $authorizationControls[0]
        }
        $attemptId = [guid]::NewGuid().ToString("N")
        $nonce = [guid]::NewGuid().ToString("N")
        $stamp = [DateTime]::UtcNow.ToString("yyyyMMddTHHmmssfffZ")
        $attemptRoot = Join-Path $EvidenceRoot (
            "$EvidenceDirectoryName\" +
            "$stamp-$($repository.head.Substring(0, 8))-$($attemptId.Substring(0, 8))"
        )
        [void][IO.Directory]::CreateDirectory($attemptRoot)
        $attemptPath = Join-Path $attemptRoot "attempt.json"
        $attempt = [ordered]@{
            schema_version = $AttemptSchema
            gate_id = $GateId
            question_class = "development"
            status = "running"
            attempt_id = $attemptId
            created_utc = [DateTimeOffset]::UtcNow.ToString("o")
            source_commit = $repository.head
            authorization_sha256 = $authorization.raw_sha256
            authorization_control_sha256 = if ($null -ne $authorizationControl) {
                [string]$authorizationControl.raw_sha256
            } else { $null }
            seed = $seed
            seed_sha256 = $seedSha
            held_out = $false
            physical_question_kind = $PhysicalQuestionKind
            actuator_mode = $actuatorModeValue
            recovery_controller_id = $recoveryControllerIdValue
            recovery_energy_route_id = $recoveryEnergyRouteIdValue
            maximum_model_construction_attempt_count =
                $MaximumModelConstructionAttemptCount
            maximum_model_construction_count = $MaximumModelConstructionCount
            maximum_world_attempt_count = $MaximumWorldAttemptCount
            maximum_world_build_count = $MaximumWorldBuildCount
            maximum_solver_step_count = $MaximumOuterSolverSteps
            total_timeout_seconds = $PhysicalTimeoutSeconds
            progress_observability_enabled = $progressEnabled
            progress_cadence_steps = $ProgressCadenceSteps
            progress_stall_timeout_seconds = $ProgressStallTimeoutSeconds
            minimum_progress_marker_count = $MinimumProgressMarkerCount
            operation_lock = Get-SporeSporeLocomotionOperationLockPublicReceipt $lock
            physical_acceptance_authority = $false
            release_authority = $false
        }
        Write-R57Json -Path $attemptPath -Value $attempt

        $process = Invoke-SporeSporeGodotReceiptTerminatedProcess `
            -FileName $consolePath `
            -Arguments @(
                "--headless", "--path", $repoRoot, "--script",
                ("res://" + $workerRelative.Replace("\", "/"))
            ) `
            -WorkingDirectory $repoRoot `
            -ReadyMarkerPrefix $readyMarker `
            -ExpectedNonce $nonce `
            -ProgressMarkerPrefix $progressMarker `
            -ProgressStallTimeoutSeconds $ProgressStallTimeoutSeconds `
            -Environment @{
                SPORESPORE_R24D57_PHYSICAL_AUTHORIZATION_SHA256 = $authorization.raw_sha256
                SPORESPORE_R24D57_SOURCE_COMMIT = $repository.head
                SPORESPORE_R24D57_ATTEMPT_ID = $attemptId
                SPORESPORE_R24D57_SUPERVISED_TERMINATION = "1"
                SPORESPORE_R24D57_TERMINATION_NONCE = $nonce
                SPORESPORE_GODOT_RECOVERY_AUTHORIZATION_SHA256 = $authorization.raw_sha256
                SPORESPORE_GODOT_RECOVERY_SOURCE_COMMIT = $repository.head
                SPORESPORE_GODOT_RECOVERY_ATTEMPT_ID = $attemptId
                SPORESPORE_GODOT_RECOVERY_SUPERVISED_TERMINATION = "1"
                SPORESPORE_GODOT_RECOVERY_TERMINATION_NONCE = $nonce
                SPORESPORE_GODOT_RECOVERY_GATE_ID = $GateId
                SPORESPORE_GODOT_RECOVERY_GATE_TOKEN = $GateToken
                SPORESPORE_GODOT_RECOVERY_RAW_SCHEMA = $RawSchema
                SPORESPORE_GODOT_RECOVERY_WORK_ID = $physicalWorkIdValue
                SPORESPORE_GODOT_RECOVERY_RAW_MARKER = $rawMarker
                SPORESPORE_GODOT_RECOVERY_READY_MARKER = $readyMarker
                SPORESPORE_GODOT_RECOVERY_PROGRESS_MARKER = $progressMarker
                SPORESPORE_GODOT_RECOVERY_PROGRESS_CADENCE_STEPS =
                    [string]$ProgressCadenceSteps
                SPORESPORE_GODOT_RECOVERY_SEED = [string]$seed
                SPORESPORE_GODOT_RECOVERY_SEED_LABEL = $SeedLabel
                SPORESPORE_GODOT_RECOVERY_SEED_SHA256 = $seedSha
                SPORESPORE_GODOT_RECOVERY_ACTUATOR_MODE = $actuatorModeValue
                SPORESPORE_GODOT_RECOVERY_CONTROLLER_ID =
                    $recoveryControllerIdValue
                SPORESPORE_GODOT_RECOVERY_ENERGY_ROUTE_ID =
                    $recoveryEnergyRouteIdValue
            } `
            -TimeoutSeconds $PhysicalTimeoutSeconds

        [IO.File]::WriteAllText(
            (Join-Path $attemptRoot "godot.stdout.log"),
            [string]$process.stdout,
            [Text.UTF8Encoding]::new($false)
        )
        [IO.File]::WriteAllText(
            (Join-Path $attemptRoot "godot.stderr.log"),
            [string]$process.stderr,
            [Text.UTF8Encoding]::new($false)
        )
        $engineHealth = Get-SporeSporeGodotEngineHealthProjection `
            -StandardError ([string]$process.stderr)
        $rawLines = @(([string]$process.stdout -split "`r?`n") | Where-Object {
            $_.StartsWith($rawMarker, [StringComparison]::Ordinal)
        })
        $raw = $null
        $rawBindingValid = $false
        if ($rawLines.Count -eq 1) {
            try {
                $raw = $rawLines[0].Substring($rawMarker.Length) |
                    ConvertFrom-Json -AsHashtable -Depth 100
                $rawBindingValid = Test-R57RawBinding `
                    -Raw $raw `
                    -ExpectedSourceCommit $repository.head `
                    -ExpectedAttemptId $attemptId `
                    -ExpectedAuthorizationSha256 $authorization.raw_sha256 `
                    -ExpectedSeed $seed `
                    -ExpectedSeedSha256 $seedSha
            } catch { $rawBindingValid = $false }
        }
        $rawPath = Join-Path $attemptRoot "raw_result.json"
        if ($null -ne $raw) {
            Write-R57Json -Path $rawPath -Value $raw
        } else {
            Write-R57Json -Path $rawPath -Value ([ordered]@{
                schema_version = $MissingRawSchema
                ok = $false
                failure_code = "SUPERVISOR_RAW_RESULT_MISSING_OR_INVALID"
                raw_marker_count = $rawLines.Count
            })
        }
        $rawCas = Publish-SporeSporeContentAddressedArtifact `
            -RepoRoot $repoRoot `
            -ArtifactPath $rawPath `
            -MediaType "application/json"
        $progressReceipts = @($process.progress_receipts)
        $progressBindingValid = [bool]$process.progress_binding_valid
        $previousProgressStepCount = -1L
        if ($progressEnabled) {
            if ($progressReceipts.Count -lt $MinimumProgressMarkerCount) {
                $progressBindingValid = $false
            }
            for ($progressIndex = 0; $progressIndex -lt $progressReceipts.Count; $progressIndex++) {
                try {
                    $progress = $progressReceipts[$progressIndex]
                    $completedProgressSteps = [long]$progress.completed_solver_step_count
                    $armProgressSteps = [long]$progress.arm_step_count
                    $progressBindingValid = $progressBindingValid -and (
                        [string]$progress.gate_id -ceq $GateId -and
                        [string]$progress.source_commit -ceq $repository.head -and
                        [string]$progress.attempt_id -ceq $attemptId -and
                        [string]$progress.authorization_sha256 -ceq
                            $authorization.raw_sha256 -and
                        [int]$progress.seed -eq $seed -and
                        [string]$progress.seed_sha256 -ceq $seedSha -and
                        [int]$progress.progress_sequence -eq ($progressIndex + 1) -and
                        [string]$progress.milestone -cin @(
                            "worker_ready",
                            "arm_world_ready",
                            "solver_progress",
                            "arm_result_complete",
                            "pair_evaluation_started",
                            "raw_serialization_started",
                            "failure_serialization_started"
                        ) -and
                        [string]$progress.arm_kind -cin @(
                            "",
                            "candidate_command",
                            "matched_zero_command"
                        ) -and
                        $completedProgressSteps -ge $previousProgressStepCount -and
                        $completedProgressSteps -ge 0 -and
                        $completedProgressSteps -le $MaximumOuterSolverSteps -and
                        $armProgressSteps -ge 0 -and
                        $armProgressSteps -le $MaximumOuterSolverSteps -and
                        [long]$progress.maximum_solver_step_count -eq
                            $MaximumOuterSolverSteps -and
                        -not [bool]$progress.physics_evidence_authority -and
                        -not [bool]$progress.physical_acceptance_authority -and
                        -not [bool]$progress.release_authority
                    )
                    $previousProgressStepCount = $completedProgressSteps
                } catch {
                    $progressBindingValid = $false
                }
            }
        } elseif ($progressReceipts.Count -ne 0) {
            $progressBindingValid = $false
        }
        $lastProgressReceipt = if ($progressReceipts.Count -gt 0) {
            $progressReceipts[$progressReceipts.Count - 1]
        } else { $null }
        $resultSpecificValid = $false
        if ($null -ne $raw) {
            if ($behaviorDevelopment) {
                $resultSpecificValid = (
                    [int]$raw.model_construction_count -eq
                        $ExpectedModelConstructionCount -and
                    [int]$raw.world_attempt_count -eq $ExpectedWorldAttemptCount -and
                    [int]$raw.world_build_count -eq $ExpectedWorldBuildCount -and
                    [long]$raw.solver_step_count -ge $MinimumCompletedSolverSteps -and
                    [long]$raw.solver_step_count -le $MaximumOuterSolverSteps -and
                    [int]$raw.behavior_evaluator_invocation_count -eq
                        $ExpectedBehaviorEvaluatorInvocationCount -and
                    [int]$raw.complete_trace_count -eq 2 -and
                    [int]$raw.in_run_invariant_receipt_count -eq
                        [long]$raw.solver_step_count -and
                    [bool]$raw.all_in_run_physical_invariants_passed
                )
            } else {
                $completeEnergyRoute = $recoveryEnergyRouteIdValue -cin @(
                    "sporespore_qsdk_r24d136_godot_jolt_complete_energy_recovery_observation_v3_route_v1",
                    "sporespore_qsdk_r24d144_godot_jolt_solver_coupled_complete_energy_recovery_observation_v3_route_v1",
                    "sporespore_qsdk_r24d148_godot_jolt_discrete_staging_complete_energy_recovery_observation_v3_route_v1"
                )
                $resultSpecificValid = (
                    [int]$raw.model_construction_count -eq
                        $ExpectedModelConstructionCount -and
                    [int]$raw.world_attempt_count -eq $ExpectedWorldAttemptCount -and
                    [int]$raw.world_build_count -eq $ExpectedWorldBuildCount -and
                    [long]$raw.solver_step_count -ge $MinimumCompletedSolverSteps -and
                    [long]$raw.solver_step_count -le $MaximumOuterSolverSteps -and
                    [int]$raw.portable_command_application_count -eq 1 -and
                    [int]$raw.in_run_physical_invariant_step_count -eq 2 -and
                    [bool]$raw.all_in_run_physical_invariants_passed -and
                    (
                        -not $completeEnergyRoute -or (
                            [bool]$raw.complete_energy_profile_selected -and
                            [int]$raw.position_solver_entry_receipt_count -eq 2 -and
                            [bool]$raw.all_complete_energy_position_solver_receipts_passed
                        )
                    )
                )
            }
        }
        $validComplete = (
            $rawBindingValid -and
            $progressBindingValid -and
            [bool]$process.termination_protocol_valid -and
            [int]$process.exit_code -eq 0 -and
            [bool]$engineHealth.passed -and
            [bool]$raw.ok -and
            [string]$raw.status -ceq $ValidCompleteStatus -and
            $resultSpecificValid
        )
        $proneToStandingClaimed = (
            $validComplete -and $behaviorDevelopment -and
            [bool]$raw.prone_to_standing_claimed
        )
        $recoverySuccessObserved = (
            $validComplete -and $behaviorDevelopment -and
            [bool]$raw.recovery_success_observed
        )
        $terminal = [ordered]@{
            schema_version = $TerminalSchema
            gate_id = $GateId
            question_class = "development"
            status = if ($validComplete) {
                $ValidCompleteStatus
            } else { $InvalidOrIncompleteStatus }
            physical_question_kind = $PhysicalQuestionKind
            actuator_mode = $actuatorModeValue
            recovery_controller_id = $recoveryControllerIdValue
            recovery_energy_route_id = $recoveryEnergyRouteIdValue
            integration_ghost_passed = $validComplete -and -not $behaviorDevelopment
            behavior_development_completed = $validComplete -and $behaviorDevelopment
            attempt_id = $attemptId
            completed_utc = [DateTimeOffset]::UtcNow.ToString("o")
            source = $repository
            authorization = [ordered]@{
                path = $authorization.path
                raw_sha256 = $authorization.raw_sha256
                byte_length = $authorization.byte_length
                source_freeze_commit = $authorization.source_freeze_commit
                control = if ($null -ne $authorizationControl) {
                    [ordered]@{
                        path = $authorizationControl.path
                        raw_sha256 = $authorizationControl.raw_sha256
                        byte_length = $authorizationControl.byte_length
                        control_commit = $authorizationControl.control_commit
                    }
                } else { $null }
            }
            preflight = $preflight
            worker = [ordered]@{
                semantic_exit_code = [int]$process.exit_code
                host_exit_code = [int]$process.host_exit_code
                timed_out = [bool]$process.timed_out
                timeout_kind = [string]$process.timeout_kind
                termination_protocol_valid = [bool]$process.termination_protocol_valid
                termination_protocol_failure_code = [string]$process.termination_protocol_failure_code
                raw_marker_count = $rawLines.Count
                raw_binding_valid = $rawBindingValid
                progress_observability_enabled = $progressEnabled
                progress_marker_count = $progressReceipts.Count
                progress_binding_valid = $progressBindingValid
                progress_cadence_steps = $ProgressCadenceSteps
                progress_stall_timeout_seconds = $ProgressStallTimeoutSeconds
                total_timeout_seconds = $PhysicalTimeoutSeconds
                last_progress_receipt = $lastProgressReceipt
                engine_health = $engineHealth
            }
            raw_result = [ordered]@{
                path = "raw_result.json"
                raw_sha256 = Get-R57Sha $rawPath
                byte_length = (Get-Item -LiteralPath $rawPath).Length
                cas = $rawCas
            }
            evidence_root = $attemptRoot.Replace("\", "/")
            same_identity_rerun_permitted = $false
            held_out = $false
            recovery_success_required = $false
            recovery_success_observed = $recoverySuccessObserved
            prone_to_standing_claimed = $proneToStandingClaimed
            physical_acceptance_authority = $false
            release_authority = $false
        }
        $terminalPath = Join-Path $attemptRoot "terminal.json"
        Write-R57Json -Path $terminalPath -Value $terminal
        $attempt.status = [string]$terminal.status
        $attempt.completed_utc = [string]$terminal.completed_utc
        $attempt.terminal_path = "terminal.json"
        Write-R57Json -Path $attemptPath -Value $attempt
        $terminalCas = Publish-SporeSporeContentAddressedArtifact `
            -RepoRoot $repoRoot `
            -ArtifactPath $terminalPath `
            -MediaType "application/json"
        $summary = [ordered]@{
            schema_version = $SupervisorResultSchema
            gate_id = $GateId
            ok = $validComplete
            status = [string]$terminal.status
            attempt_id = $attemptId
            evidence_root = $attemptRoot.Replace("\", "/")
            raw_result_sha256 = [string]$terminal.raw_result.raw_sha256
            terminal_sha256 = Get-R57Sha $terminalPath
            terminal_cas = $terminalCas
            model_construction_count = if ($null -ne $raw) {
                [int]$raw.model_construction_count
            } else { 0 }
            world_attempt_count = if ($null -ne $raw) {
                [int]$raw.world_attempt_count
            } else { 0 }
            world_build_count = if ($null -ne $raw) {
                [int]$raw.world_build_count
            } else { 0 }
            solver_step_count = if ($null -ne $raw) {
                [int]$raw.solver_step_count
            } else { 0 }
            native_engine_health_passed = [bool]$engineHealth.passed
            recovery_controller_id = $recoveryControllerIdValue
            recovery_energy_route_id = $recoveryEnergyRouteIdValue
            recovery_success_observed = $recoverySuccessObserved
            prone_to_standing_claimed = $proneToStandingClaimed
            physical_acceptance_authority = $false
            release_authority = $false
        }
        $semanticExitCode = if ($validComplete) { 0 } else { 1 }
        return New-R57SupervisorProjection `
            -Summary $summary `
            -ExitCode $semanticExitCode
    } finally {
        Exit-SporeSporeLocomotionOperationLock -Receipt $lock
    }
}

try {
    if ($Mode -ceq "RuntimeIdentity") {
        $identity = Invoke-R57RuntimeIdentity
        Write-Output (
            $supervisorMarker + ($identity | ConvertTo-Json -Depth 20 -Compress)
        )
        exit 0
    }
    if ($Mode -ceq "RawBindingControl") {
        $binding = Invoke-R57RawBindingControl
        Write-Output (
            $supervisorMarker + ($binding | ConvertTo-Json -Depth 20 -Compress)
        )
        exit 0
    }
    if ($Mode -ceq "ProjectionControl") {
        Assert-R57 (-not $RunPhysical.IsPresent) "projection_control_cannot_run_physics"
        $forced = [ordered]@{
            schema_version = $SupervisorResultSchema
            gate_id = $GateId
            ok = $false
            status = "forced_failure_projection_control"
            model_construction_count = 0
            world_attempt_count = 0
            world_build_count = 0
            solver_step_count = 0
            physical_acceptance_authority = $false
            release_authority = $false
        }
        $projection = New-R57SupervisorProjection -Summary $forced -ExitCode 23
        Write-Output $projection.output_line
        exit ([int]$projection.exit_code)
    }
    if ($Mode -ceq "AuthorizationControl") {
        $control = Invoke-R57AuthorizationControl
        Write-Output $control.output_line
        exit ([int]$control.exit_code)
    }
    if ($Mode -ceq "Preflight") {
        Assert-R57 (-not $RunPhysical.IsPresent) "preflight_cannot_run_physics"
        $result = Invoke-R57Preflight
        Write-Output ($supervisorMarker + ($result | ConvertTo-Json -Depth 20 -Compress))
        exit 0
    }
    $physical = Invoke-R57Physical
    Write-Output $physical.output_line
    exit ([int]$physical.exit_code)
} catch {
    Write-Error $_
    exit 1
}
