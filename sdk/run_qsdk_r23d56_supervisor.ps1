#requires -Version 7.0

[CmdletBinding()]
param(
    [switch]$PreflightOnly,
    [switch]$RunPhysical,
    [string]$CampaignAttestationAdoption = "",
    [string]$OutputRoot = "",
    [string]$Godot = (
        "C:\Users\Cole\CodeStuff\Misc\Godot\" +
        "Godot_v4.7-stable_mono_win64_console.exe"
    ),
    [string]$Python = "python",
    [string]$PowerShell = "pwsh",
    [ValidateRange(300, 3600)][int]$CellTimeoutSeconds = 900
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$sdkRoot = [IO.Path]::GetFullPath($PSScriptRoot)
$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $sdkRoot))
$turningRoot = Join-Path $sdkRoot "turning"
$campaignId = "QSDK-R23D56-GODOT-VALID-ROUTE-ACTUATOR-PHASE-CHARACTERIZATION-DEVELOPMENT"
$gateId = "QSDK-R23D56"
$stageId = "godot_valid_route_actuator_phase_characterization_development"
$candidateId = "r23d29_r23d53_condition_post_r23d55_valid_route_actuator_phase_characterization_development"
$policyId = (
    "sporespore_balanced_wave_r23d29_two_swing_persistent_predictive_" +
    "stability_guarded_steering_v1"
)
$preregistrationPath = Join-Path $turningRoot (
    "r23d56_godot_valid_route_actuator_phase_characterization_preregistration_v1.json"
)
$implementationPath = Join-Path $turningRoot (
    "r23d56_godot_valid_route_actuator_phase_characterization_implementation_v1.json"
)
$manifestPath = Join-Path $turningRoot "r23d56_campaign_attestation_manifest_v1.json"
$evaluatorPath = Join-Path $turningRoot (
    "r23d56_godot_valid_route_actuator_phase_characterization_evaluator.py"
)
$taskOriginGatePath = Join-Path $repoRoot (
    "tests\test_sdk_qsdk_r23d53_task_frame_origin_policy.gd"
)
$taskOriginGateResource = "res://tests/test_sdk_qsdk_r23d53_task_frame_origin_policy.gd"
$actuatorPhaseGatePath = Join-Path $repoRoot (
    "tests\test_sdk_godot_actuator_phase_observation.gd"
)
$actuatorPhaseGateResource = "res://tests/test_sdk_godot_actuator_phase_observation.gd"
$r23d55CapSourceAuditPath = Join-Path $repoRoot (
    "tests\test_qsdk_r23d55_live_fixture_actuator_cap_contract.ps1"
)
$r23d55CapRuntimeGatePath = Join-Path $repoRoot (
    "tests\test_sdk_qsdk_r23d55_godot_live_fixture_actuator_cap_conformance.gd"
)
$r23d55CapRuntimeGateResource = (
    "res://tests/test_sdk_qsdk_r23d55_godot_live_fixture_actuator_cap_conformance.gd"
)
$liveFixtureCapBindingPolicyId = (
    "sporespore_godot_jolt_live_fixture_compiled_actuator_cap_binding_v1"
)
$godotWorkerPath = "res://tests/test_sdk_qsdk_r23d56_godot_jolt_physical_worker.gd"
$godotReadyMarker = "QSDK_R23D56_GODOT_SUPERVISOR_TERMINATION_READY "
$runtimeHelperPath = Join-Path $sdkRoot "r23d3_reproducible_runtime_materialization.ps1"
$godotAdapterPath = Join-Path $sdkRoot "target\debug\sporespore_godot_adapter.dll"
$armOrder = @("reference_zero", "positive_heading", "negative_heading")
$engineOrder = @("godot_jolt")
$cellIds = @(
    foreach ($engine in $engineOrder) {
        foreach ($arm in $armOrder) { "$engine`__$candidateId`__$arm" }
    }
)
$physicalEnvironmentNames = @(
    "SPORESPORE_QSDK_R23D56_FREEZE",
    "SPORESPORE_QSDK_R23D56_ATTEMPT",
    "SPORESPORE_QSDK_R23D56_TOKEN",
    "SPORESPORE_QSDK_R23D56_STAGE",
    "SPORESPORE_QSDK_R23D56_CELL",
    "SPORESPORE_QSDK_R23D56_ENGINE",
    "SPORESPORE_QSDK_R23D56_ATTEMPT_ROOT",
    "SPORESPORE_QSDK_R23D56_PYTHON",
    "SPORESPORE_QSDK_R23D56_POWERSHELL",
    "SPORESPORE_QSDK_R23D56_SUPERVISED_TERMINATION",
    "SPORESPORE_QSDK_R23D56_TERMINATION_NONCE"
)

. (Join-Path $sdkRoot "content_addressed_artifact_store.ps1")
. (Join-Path $sdkRoot "godot_receipt_terminated_process.ps1")
. (Join-Path $sdkRoot "locomotion_operation_lock.ps1")
. (Join-Path $sdkRoot "locomotion_full_conformance_attestation.ps1")
. (Join-Path $sdkRoot "locomotion_campaign_attestation_adoption.ps1")
. (Join-Path $sdkRoot "locomotion_terminal_execution_projection.ps1")

$terminalSuccessSchemas = @(
    "sporespore_qsdk_r23d56_engine_cell_report_v1"
)
$terminalFailureSchemas = @(
    "sporespore_qsdk_r23d56_worker_failure_v1",
    "sporespore_qsdk_r23d56_supervisor_failure_v1"
)

function Assert-R23D56([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "QSDK-R23D56: $Message" }
}

function Resolve-R23D56Application([string]$Command) {
    if ([IO.Path]::IsPathFullyQualified($Command)) {
        $resolved = [IO.Path]::GetFullPath($Command)
        Assert-R23D56 (Test-Path -LiteralPath $resolved -PathType Leaf) (
            "application is missing: $resolved"
        )
        return $resolved
    }
    $candidate = Get-Command $Command -CommandType Application -ErrorAction Stop |
        Select-Object -First 1
    return [IO.Path]::GetFullPath([string]$candidate.Source)
}

function Get-R23D56Sha256([string]$Path) {
    return "sha256:" + (
        Get-FileHash -LiteralPath $Path -Algorithm SHA256
    ).Hash.ToLowerInvariant()
}

function Invoke-R23D56Git([string[]]$Arguments) {
    $lines = @(& git -C $repoRoot @Arguments 2>&1)
    if ($LASTEXITCODE -ne 0) {
        throw "QSDK-R23D56 git $($Arguments -join ' ') failed: $($lines -join ' ')"
    }
    return ($lines -join "`n").Trim()
}

function Write-R23D56NewJson([string]$Path, $Value) {
    $resolved = [IO.Path]::GetFullPath($Path)
    if (Test-Path -LiteralPath $resolved) {
        throw "QSDK-R23D56 refuses to overwrite: $resolved"
    }
    [void][IO.Directory]::CreateDirectory((Split-Path -Parent $resolved))
    [IO.File]::WriteAllText(
        $resolved,
        ($Value | ConvertTo-Json -Depth 100) + "`n",
        [Text.UTF8Encoding]::new($false)
    )
}

function Get-R23D56MediaType([string]$Path) {
    switch ([IO.Path]::GetExtension($Path).ToLowerInvariant()) {
        ".json" { return "application/json" }
        ".ps1" { return "text/x-powershell" }
        ".py" { return "text/x-python" }
        ".gd" { return "text/x-gdscript" }
        ".rs" { return "text/x-rust" }
        ".toml" { return "application/toml" }
        ".dll" { return "application/vnd.microsoft.portable-executable" }
        ".exe" { return "application/vnd.microsoft.portable-executable" }
        default { return "application/octet-stream" }
    }
}

function Invoke-R23D56Process {
    param(
        [Parameter(Mandatory)][string]$FileName,
        [Parameter(Mandatory)][string[]]$Arguments,
        [Parameter(Mandatory)][string]$WorkingDirectory,
        [hashtable]$Environment = @{},
        [ValidateRange(1, 7200)][int]$TimeoutSeconds = 900
    )
    $start = [Diagnostics.ProcessStartInfo]::new()
    $start.FileName = $FileName
    $start.WorkingDirectory = $WorkingDirectory
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    foreach ($argument in $Arguments) { [void]$start.ArgumentList.Add($argument) }
    foreach ($name in $physicalEnvironmentNames) { [void]$start.Environment.Remove($name) }
    foreach ($entry in $Environment.GetEnumerator()) {
        $start.Environment[[string]$entry.Key] = [string]$entry.Value
    }
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $start
    $started = [DateTime]::UtcNow
    [void]$process.Start()
    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()
    $timedOut = -not $process.WaitForExit($TimeoutSeconds * 1000)
    if ($timedOut) {
        try { $process.Kill($true) } catch {}
        [void]$process.WaitForExit(10000)
    } else {
        $process.WaitForExit()
    }
    $stdout = $stdoutTask.GetAwaiter().GetResult()
    $stderr = $stderrTask.GetAwaiter().GetResult()
    $exitCode = if ($timedOut) { 124 } else { $process.ExitCode }
    $process.Dispose()
    return [ordered]@{
        exit_code = $exitCode
        timed_out = $timedOut
        stdout = $stdout
        stderr = $stderr
        started_utc = $started.ToString("o")
        completed_utc = [DateTime]::UtcNow.ToString("o")
    }
}

function Invoke-R23D56GodotWorkerProcess {
    param(
        [Parameter(Mandatory)][string[]]$Arguments,
        [hashtable]$Environment = @{},
        [ValidateRange(1, 7200)][int]$TimeoutSeconds = 900
    )
    $workerEnvironment = @{}
    foreach ($entry in $Environment.GetEnumerator()) {
        $workerEnvironment[[string]$entry.Key] = [string]$entry.Value
    }
    $terminationNonce = [Guid]::NewGuid().ToString("N")
    $workerEnvironment["SPORESPORE_QSDK_R23D56_SUPERVISED_TERMINATION"] = "1"
    $workerEnvironment["SPORESPORE_QSDK_R23D56_TERMINATION_NONCE"] = $terminationNonce
    return Invoke-SporeSporeGodotReceiptTerminatedProcess -FileName $Godot `
        -Arguments $Arguments -WorkingDirectory $repoRoot `
        -ReadyMarkerPrefix $godotReadyMarker -ExpectedNonce $terminationNonce `
        -Environment $workerEnvironment `
        -ScrubEnvironmentNames $physicalEnvironmentNames `
        -TimeoutSeconds $TimeoutSeconds
}

function Get-R23D56MarkerJson([string]$Text, [string]$Prefix) {
    $lines = @($Text -split "`r?`n" | Where-Object {
        ([string]$_).StartsWith($Prefix, [StringComparison]::Ordinal)
    })
    Assert-R23D56 ($lines.Count -eq 1) (
        "expected one '$Prefix' marker, observed $($lines.Count)"
    )
    return $lines[0].Substring($Prefix.Length) |
        ConvertFrom-Json -AsHashtable -Depth 100
}

function Get-R23D56PythonEnvironment {
    return @{
        # The evaluator is pure Python. Keep the commissioned host and bind
        # only repository modules; this Godot-only successor opens no MuJoCo.
        "PYTHONPATH" = (@(
            (Join-Path $sdkRoot "python"),
            $turningRoot
        ) -join [IO.Path]::PathSeparator)
    }
}

function Invoke-R23D56TerminalProjectionPreflight {
    $successTerminal = [ordered]@{
        schema_version = $terminalSuccessSchemas[0]
        execution = [ordered]@{
            integrity_passed = $true
            world_attempt_count = 1
            world_build_count = 1
        }
    }
    $workerFailureTerminal = [ordered]@{
        schema_version = $terminalFailureSchemas[0]
        world_attempt_count = 1
        world_build_count = 1
    }
    $supervisorFailureTerminal = [ordered]@{
        schema_version = $terminalFailureSchemas[1]
        world_attempt_count = 1
        world_build_count = 0
        world_build_count_exact = $false
        world_build_count_lower_bound = 0
        world_build_count_upper_bound = 1
    }

    $successProjection = Get-SporeSporeTerminalExecutionProjection `
        -Terminal $successTerminal -SuccessSchemas $terminalSuccessSchemas `
        -FailureSchemas $terminalFailureSchemas
    $workerFailureProjection = Get-SporeSporeTerminalExecutionProjection `
        -Terminal $workerFailureTerminal -SuccessSchemas $terminalSuccessSchemas `
        -FailureSchemas $terminalFailureSchemas
    $supervisorFailureProjection = Get-SporeSporeTerminalExecutionProjection `
        -Terminal $supervisorFailureTerminal -SuccessSchemas $terminalSuccessSchemas `
        -FailureSchemas $terminalFailureSchemas

    Assert-R23D56 (
        [string]$successProjection.projection_source -ceq "execution" -and
        [int]$successProjection.world_attempt_count -eq 1 -and
        [int]$successProjection.world_build_count -eq 1 -and
        [bool]$successProjection.world_build_count_exact -and
        [int]$successProjection.world_build_count_lower_bound -eq 1 -and
        [int]$successProjection.world_build_count_upper_bound -eq 1
    ) "success-terminal execution projection canary changed"
    Assert-R23D56 (
        [string]$workerFailureProjection.projection_source -ceq
            "terminal_root_failure" -and
        [int]$workerFailureProjection.world_attempt_count -eq 1 -and
        [int]$workerFailureProjection.world_build_count -eq 1 -and
        [bool]$workerFailureProjection.world_build_count_exact
    ) "worker-failure terminal projection canary changed"
    Assert-R23D56 (
        [string]$supervisorFailureProjection.projection_source -ceq
            "terminal_root_failure" -and
        [int]$supervisorFailureProjection.world_attempt_count -eq 1 -and
        [int]$supervisorFailureProjection.world_build_count -eq 0 -and
        -not [bool]$supervisorFailureProjection.world_build_count_exact -and
        [int]$supervisorFailureProjection.world_build_count_lower_bound -eq 0 -and
        [int]$supervisorFailureProjection.world_build_count_upper_bound -eq 1
    ) "supervisor-failure terminal projection canary changed"

    $mutations = @(
        { $value = $successTerminal.Clone(); $value.Remove("execution"); $value },
        {
            $value = $successTerminal.Clone()
            $value["world_build_count"] = 1
            $value
        },
        {
            $value = $successTerminal.Clone()
            $value["execution"] = [ordered]@{ world_attempt_count = 1 }
            $value
        },
        {
            $value = $successTerminal.Clone()
            $value["execution"] = [ordered]@{
                world_attempt_count = "1"
                world_build_count = 1
            }
            $value
        },
        {
            $value = $successTerminal.Clone()
            $value["execution"] = [ordered]@{
                world_attempt_count = 0
                world_build_count = 1
            }
            $value
        },
        {
            $value = $workerFailureTerminal.Clone()
            $value["execution"] = [ordered]@{}
            $value
        },
        {
            [ordered]@{
                schema_version = "sporespore_unknown_terminal_v1"
                world_attempt_count = 0
                world_build_count = 0
            }
        },
        {
            $value = $supervisorFailureTerminal.Clone()
            $value["world_build_count_exact"] = "false"
            $value
        },
        {
            $value = $supervisorFailureTerminal.Clone()
            $value["world_build_count_lower_bound"] = 1
            $value
        },
        {
            $value = $supervisorFailureTerminal.Clone()
            $value["world_build_count_upper_bound"] = 2
            $value
        }
    )
    $rejected = 0
    foreach ($mutation in $mutations) {
        try {
            $value = & $mutation
            $null = Get-SporeSporeTerminalExecutionProjection `
                -Terminal $value -SuccessSchemas $terminalSuccessSchemas `
                -FailureSchemas $terminalFailureSchemas
        } catch {
            $rejected++
        }
    }
    Assert-R23D56 ($rejected -eq $mutations.Count) (
        "expected $($mutations.Count) rejected terminal mutations, observed $rejected"
    )

    return [ordered]@{
        schema_version = "sporespore_qsdk_r23d56_terminal_projection_preflight_v1"
        positive_terminal_projection_canary_count = 1
        failure_terminal_projection_canary_count = 2
        terminal_projection_mutation_rejection_count = $rejected
        terminal_projection_uses_worker_execution_object = $true
        terminal_projection_failure_schemas_use_root_counts = $true
        model_construction_count = 0
        world_attempt_count = 0
        world_build_count = 0
        physical_acceptance_authority = $false
    }
}

function Invoke-R23D56ZeroWorld(
    [string]$PythonHost
) {
    Assert-R23D56 (Test-Path -LiteralPath $godotAdapterPath -PathType Leaf) (
        "zero-world Godot adapter is missing: $godotAdapterPath"
    )
    $terminalProjection = Invoke-R23D56TerminalProjectionPreflight
    $implementation = Get-Content -Raw -LiteralPath $implementationPath |
        ConvertFrom-Json -AsHashtable -Depth 100
    # Exercise the exact source freezer during every campaign-local preflight.
    # This prevents an overbroad or checkout-filter-sensitive dependency set
    # from surviving commissioning only to fail at the physical boundary.
    $sourceBindings = Get-R23D56SourceBindings $implementation
    $pythonEnvironment = Get-R23D56PythonEnvironment
    $capSourceAudit = Invoke-R23D56Process -FileName $powerShellHost -Arguments @(
        "-NoLogo", "-NoProfile", "-File", $r23d55CapSourceAuditPath
    ) -WorkingDirectory $repoRoot -TimeoutSeconds 300
    Assert-R23D56 (
        $capSourceAudit.exit_code -eq 0 -and -not $capSourceAudit.timed_out
    ) (
        "R23D55 cap source audit failed: $($capSourceAudit.stderr) " +
        "$($capSourceAudit.stdout)"
    )
    $capSourceAuditMarkers = @(
        [string]$capSourceAudit.stdout -split "`r?`n" | Where-Object {
            $_.StartsWith(
                "QSDK_R23D55_LIVE_FIXTURE_ACTUATOR_CAP_CONTRACT_PASS ",
                [StringComparison]::Ordinal
            )
        }
    )
    Assert-R23D56 (
        $capSourceAuditMarkers.Count -eq 1 -and
        $capSourceAuditMarkers[0].Contains("bindings=19 historical_git=5 live=14") -and
        $capSourceAuditMarkers[0].Contains("actuators=8 limbs=4 writes=8 readbacks=8") -and
        $capSourceAuditMarkers[0].Contains("mutations=14 models=0 worlds=0") -and
        $capSourceAuditMarkers[0].Contains("turning=False prone=False physical=False")
    ) "R23D55 cap source-audit receipt changed"
    $capRuntimeGate = Invoke-R23D56Process -FileName $Godot -Arguments @(
        "--headless", "--path", $repoRoot, "--script", $r23d55CapRuntimeGateResource
    ) -WorkingDirectory $repoRoot -TimeoutSeconds 180
    Assert-R23D56 (
        $capRuntimeGate.exit_code -eq 0 -and -not $capRuntimeGate.timed_out
    ) (
        "R23D55 cap runtime gate failed: $($capRuntimeGate.stderr) " +
        "$($capRuntimeGate.stdout)"
    )
    $capRuntimeReceipt = Get-R23D56MarkerJson $capRuntimeGate.stdout (
        "QSDK_R23D55_GODOT_LIVE_FIXTURE_ACTUATOR_CAP_CONFORMANCE "
    )
    Assert-R23D56 (
        [bool]$capRuntimeReceipt.ok -and
        [string]$capRuntimeReceipt.schema_version -ceq
            "sporespore_qsdk_r23d55_godot_live_fixture_actuator_cap_conformance_v1" -and
        [string]$capRuntimeReceipt.question_class -ceq "development" -and
        [string]$capRuntimeReceipt.policy_id -ceq $liveFixtureCapBindingPolicyId -and
        [bool]$capRuntimeReceipt.physical_entrypoint_option_normalized -and
        [bool]$capRuntimeReceipt.wrong_physical_entrypoint_policy_rejected -and
        [int]$capRuntimeReceipt.validated_actuator_count -eq 8 -and
        [int]$capRuntimeReceipt.validated_limb_count -eq 4 -and
        [int]$capRuntimeReceipt.unique_host_joint_object_count -eq 8 -and
        [int]$capRuntimeReceipt.write_count -eq 8 -and
        [int]$capRuntimeReceipt.readback_count -eq 8 -and
        [double]$capRuntimeReceipt.maximum_postbinding_readback_error_nms -le 2.5e-7 -and
        [int]$capRuntimeReceipt.mutation_rejection_count -eq 14 -and
        [bool]$capRuntimeReceipt.configured_parameter_readback_only -and
        -not [bool]$capRuntimeReceipt.measured_motor_torque_available -and
        -not [bool]$capRuntimeReceipt.measured_motor_impulse_available -and
        [int]$capRuntimeReceipt.scene_tree_insertion_count -eq 0 -and
        [int]$capRuntimeReceipt.model_construction_count -eq 0 -and
        [int]$capRuntimeReceipt.world_attempt_count -eq 0 -and
        [int]$capRuntimeReceipt.world_build_count -eq 0 -and
        -not [bool]$capRuntimeReceipt.physics_state_modified -and
        -not [bool]$capRuntimeReceipt.physical_successor_opened -and
        -not [bool]$capRuntimeReceipt.turning_claimed -and
        -not [bool]$capRuntimeReceipt.prone_to_standing_claimed -and
        -not [bool]$capRuntimeReceipt.physical_acceptance_authority
    ) "R23D55 cap runtime zero-world receipt changed"
    $taskOriginGate = Invoke-R23D56Process -FileName $Godot -Arguments @(
        "--headless", "--path", $repoRoot, "--script", $taskOriginGateResource
    ) -WorkingDirectory $repoRoot -TimeoutSeconds 180
    Assert-R23D56 (
        $taskOriginGate.exit_code -eq 0 -and -not $taskOriginGate.timed_out
    ) (
        "task-origin gate failed: $($taskOriginGate.stderr) " +
        "$($taskOriginGate.stdout)"
    )
    $taskOriginReceipt = Get-R23D56MarkerJson $taskOriginGate.stdout (
        "QSDK_R23D53_TASK_FRAME_ORIGIN_PASS "
    )
    Assert-R23D56 (
        [bool]$taskOriginReceipt.ok -and
        [string]$taskOriginReceipt.policy_id -ceq
            "warmup_preserving_command_onset_origin_reanchor_v1" -and
        [int]$taskOriginReceipt.assertion_count -eq 34 -and
        [int]$taskOriginReceipt.rejected_mutation_count -eq 6 -and
        [int]$taskOriginReceipt.model_construction_count -eq 0 -and
        [int]$taskOriginReceipt.world_build_count -eq 0
    ) "task-origin gate receipt changed"
    $actuatorPhaseGate = Invoke-R23D56Process -FileName $Godot -Arguments @(
        "--headless", "--path", $repoRoot, "--script", $actuatorPhaseGateResource
    ) -WorkingDirectory $repoRoot -TimeoutSeconds 180
    Assert-R23D56 (
        $actuatorPhaseGate.exit_code -eq 0 -and -not $actuatorPhaseGate.timed_out
    ) (
        "actuator-phase gate failed: $($actuatorPhaseGate.stderr) " +
        "$($actuatorPhaseGate.stdout)"
    )
    $actuatorPhaseReceipt = Get-R23D56MarkerJson $actuatorPhaseGate.stdout (
        "SDK_GODOT_ACTUATOR_PHASE_OBSERVATION_PREFLIGHT "
    )
    Assert-R23D56 (
        [bool]$actuatorPhaseReceipt.ok -and
        [string]$actuatorPhaseReceipt.observation_schema_version -ceq
            "sporespore_godot_jolt_actuator_phase_observation_v1" -and
        [string]$actuatorPhaseReceipt.application_receipt_schema_version -ceq
            "sporespore_godot_jolt_full_authority_application_receipt_v1" -and
        [int]$actuatorPhaseReceipt.validated_application_count -eq 8 -and
        [int]$actuatorPhaseReceipt.validated_limb_count -eq 4 -and
        [int]$actuatorPhaseReceipt.production_receipt_mutation_rejection_count -eq 2 -and
        [int]$actuatorPhaseReceipt.retained_row_mutation_rejection_count -eq 7 -and
        [bool]$actuatorPhaseReceipt.configured_motor_parameters_only -and
        -not [bool]$actuatorPhaseReceipt.measured_motor_torque_available -and
        -not [bool]$actuatorPhaseReceipt.measured_motor_impulse_available -and
        [int]$actuatorPhaseReceipt.scene_tree_insertion_count -eq 0 -and
        [int]$actuatorPhaseReceipt.model_construction_count -eq 0 -and
        [int]$actuatorPhaseReceipt.world_attempt_count -eq 0 -and
        [int]$actuatorPhaseReceipt.world_build_count -eq 0
    ) "actuator-phase native zero-world receipt changed"
    $evaluator = Invoke-R23D56Process -FileName $PythonHost `
        -Arguments @($evaluatorPath, "preflight") -WorkingDirectory $repoRoot `
        -Environment $pythonEnvironment -TimeoutSeconds 180
    Assert-R23D56 ($evaluator.exit_code -eq 0 -and -not $evaluator.timed_out) (
        "evaluator preflight failed: $($evaluator.stderr) $($evaluator.stdout)"
    )
    $evaluatorReceipt = Get-R23D56MarkerJson $evaluator.stdout (
        "QSDK_R23D56_EVALUATOR_PREFLIGHT "
    )
    Assert-R23D56 (
        [int]$evaluatorReceipt.declared_cell_count -eq 3 -and
        [int]$evaluatorReceipt.valid_trace_canary_count -eq 3 -and
        [int]$evaluatorReceipt.trace_mutation_rejection_count -eq 30 -and
        [int]$evaluatorReceipt.origin_policy_mutation_rejection_count -eq 8 -and
        [int]$evaluatorReceipt.startup_transform_mutation_rejection_count -eq 1 -and
        [int]$evaluatorReceipt.segment_mutation_rejection_count -eq 1 -and
        [int]$evaluatorReceipt.observation_mutation_rejection_count -eq 20 -and
        [int]$evaluatorReceipt.live_fixture_cap_binding_projection_positive_control_count -eq 1 -and
        [int]$evaluatorReceipt.live_fixture_cap_binding_projection_mutation_rejection_count -eq 16 -and
        [int]$evaluatorReceipt.descriptive_characterization_canary_count -eq 3 -and
        [int]$evaluatorReceipt.observation_row_count_per_trace -eq 2992 -and
        [int]$evaluatorReceipt.observation_application_count_per_trace -eq 23936 -and
        -not [bool]$evaluatorReceipt.turning_gate_invoked -and
        [int]$evaluatorReceipt.mechanism_selection_rule_count -eq 0 -and
        [int]$evaluatorReceipt.same_file_path_spelling_positive_control_count -eq 1 -and
        [int]$evaluatorReceipt.wrong_file_path_rejection_count -eq 1 -and
        [bool]$evaluatorReceipt.production_cas_binding_uses_existing_file_identity -and
        [int]$evaluatorReceipt.complete_evaluation_authority_root_cli_canary_count -eq 1 -and
        [int]$evaluatorReceipt.world_build_count -eq 0 -and
        [int]$evaluatorReceipt.model_construction_count -eq 0
    ) "evaluator preflight exposed a world"

    $workerReceipts = [Collections.Generic.List[object]]::new()
    foreach ($arm in $armOrder) {
        $result = Invoke-R23D56GodotWorkerProcess -Arguments @(
            "--headless", "--path", $repoRoot, "--script", $godotWorkerPath, "--",
            "--stage", $stageId, "--onset", "onset_600", "--arm", $arm,
            "--preflight-only"
        ) -TimeoutSeconds 180
        Assert-R23D56 (
            $result.exit_code -eq 0 -and
            -not $result.timed_out -and
            [bool]$result.supervisor_terminated -and
            [bool]$result.termination_protocol_valid -and
            [string]$result.termination_ready_receipt.worker_receipt_kind -ceq
                "preflight"
        ) (
            "Godot $arm preflight failed: $($result.stderr) $($result.stdout)"
        )
        $receipt = Get-R23D56MarkerJson $result.stdout (
            "QSDK_R23D56_GODOT_JOLT_PREFLIGHT "
        )
        $production = $receipt.adapter_boundary.production_post_step_validation
        $traceHorizon = $receipt.trace_composition_horizon
        $traceDiagnostic = $receipt.trace_diagnostic_canary
        $originCanary = $receipt.task_frame_origin_transition_canary
        Assert-R23D56 (
            [string]$receipt.campaign_id -ceq $campaignId -and
            [string]$receipt.gate_id -ceq $gateId -and
            [string]$receipt.stage_id -ceq $stageId -and
            [string]$receipt.cell_id -ceq
                "godot_jolt`__$candidateId`__$arm" -and
            [string]$receipt.arm_id -ceq $arm -and
            [string]$receipt.controller_policy_id -ceq $policyId -and
            [string]$receipt.task_frame_origin_policy_id -ceq
                "warmup_preserving_command_onset_origin_reanchor_v1" -and
            [string]$receipt.actuator_phase_observation_schema_version -ceq
                "sporespore_godot_jolt_actuator_phase_observation_v1" -and
            [bool]$receipt.actuator_phase_observation_required_on_every_trace_row -and
            [string]$receipt.live_fixture_actuator_cap_binding_policy_id -ceq
                $liveFixtureCapBindingPolicyId -and
            [bool]$receipt.live_fixture_actuator_cap_binding_required -and
            -not [bool]$receipt.live_fixture_actuator_cap_binding_executed -and
            [bool]$receipt.live_fixture_actuator_cap_binding_execution_deferred_until_after_world_build -and
            [bool]$receipt.entrypoint_preflight.sdk_live_fixture_actuator_cap_binding_enabled -and
            [string]$receipt.entrypoint_preflight.sdk_live_fixture_actuator_cap_binding_policy_id -ceq
                $liveFixtureCapBindingPolicyId -and
            -not [bool]$receipt.entrypoint_preflight.sdk_live_fixture_actuator_cap_binding_executed -and
            [string]$receipt.entrypoint_preflight.sdk_physical_trace_options.actuator_phase_observation_schema_version -ceq
                "sporespore_godot_jolt_actuator_phase_observation_v1" -and
            [bool]$originCanary.ok -and
            [int]$originCanary.transition_count -eq 3 -and
            [int]$originCanary.initial_schedule_binding_count -eq 1 -and
            [bool]$originCanary.initial_origin_preserved -and
            [int]$originCanary.same_segment_hold_count -eq 4 -and
            [int]$originCanary.rejected_mutation_count -eq 2 -and
            [int]$originCanary.fixed_origin_last_semantic_step -eq 599 -and
            (@($originCanary.expected_transition_steps) -join ",") -ceq
                "600,1800,2400" -and
            (@($originCanary.production_command_segment_ids) -join ",") -ceq
                "reference_warmup,commanded_turn,reference_recovery,reference_continuation" -and
            [bool]$production.ok -and
            [string]$production.controller_receipt_schema -ceq
                "sporespore_controller_step_receipt_v8" -and
            [string]$production.expected_memory_schema -ceq
                "sporespore_balanced_wave_persistent_predictive_guard_memory_v1" -and
            [string]$production.observed_memory_schema -ceq
                "sporespore_balanced_wave_persistent_predictive_guard_memory_v1" -and
            [bool]$traceHorizon.ok -and
            [string]$traceHorizon.arm_id -ceq $arm -and
            [int]$traceHorizon.controller_step_count -eq 2992 -and
            [int]$traceHorizon.trace_row_count -eq 2992 -and
            [int]$traceHorizon.native_controller_command_count -eq 23936 -and
            [string]$traceHorizon.release_hold_variant_type -ceq "float" -and
            -not [bool]$traceHorizon.fractional_counter_rejection.ok -and
            [string]$traceHorizon.fractional_counter_rejection.failure_code -ceq
                "SDK_PHYSICAL_TRACE_LIMB_MEMORY_VALUE_INVALID" -and
            -not [bool]$traceDiagnostic.complete -and
            [int]$traceDiagnostic.declared_row_count -eq 2992 -and
            [int]$traceDiagnostic.reported_row_count -eq 2 -and
            [int]$traceDiagnostic.actual_row_count -eq 2 -and
            [int]$traceDiagnostic.first_missing_semantic_step -eq 2 -and
            @($traceDiagnostic.failure_codes).Count -eq 1 -and
            [string]$traceDiagnostic.failure_codes[0] -ceq
                "SDK_PHYSICAL_TRACE_CANARY" -and
            [string]$traceDiagnostic.schema_version -ceq
                "sporespore_qsdk_r23d56_trace_diagnostic_v1" -and
            [string]$traceDiagnostic.campaign_id -ceq $campaignId -and
            [string]$traceDiagnostic.gate_id -ceq $gateId -and
            [bool]$traceDiagnostic.partial_rows_retained -and
            [bool]$traceDiagnostic.retained_before_terminal_entry -and
            [int]$receipt.world_build_count -eq 0 -and
            [int]$receipt.model_construction_count -eq 0
        ) "Godot $arm preflight receipt is invalid"
        $workerReceipts.Add($receipt)
    }
    return [ordered]@{
        schema_version = "sporespore_qsdk_r23d56_zero_world_receipt_v1"
        campaign_id = $campaignId
        gate_id = $gateId
        evaluator = $evaluatorReceipt
        task_frame_origin_gate = $taskOriginReceipt
        actuator_phase_observation_gate = $actuatorPhaseReceipt
        r23d55_live_fixture_cap_source_audit_marker = $capSourceAuditMarkers[0]
        r23d55_live_fixture_cap_runtime_gate = $capRuntimeReceipt
        terminal_execution_projection = $terminalProjection
        ordered_worker_receipts = @($workerReceipts)
        declared_cell_count = 3
        worker_preflight_count = 3
        source_binding_count = @($sourceBindings).Count
        source_bindings_checkout_bytes_equal_git_blobs = $true
        task_frame_origin_gate_passed = $true
        task_frame_origin_gate_raw_sha256 = Get-R23D56Sha256 $taskOriginGatePath
        actuator_phase_observation_gate_passed = $true
        actuator_phase_observation_gate_raw_sha256 = Get-R23D56Sha256 $actuatorPhaseGatePath
        r23d55_live_fixture_cap_source_audit_passed = $true
        r23d55_live_fixture_cap_source_audit_raw_sha256 = (
            Get-R23D56Sha256 $r23d55CapSourceAuditPath
        )
        r23d55_live_fixture_cap_runtime_gate_passed = $true
        r23d55_live_fixture_cap_runtime_gate_raw_sha256 = (
            Get-R23D56Sha256 $r23d55CapRuntimeGatePath
        )
        live_fixture_actuator_cap_binding_policy_id = $liveFixtureCapBindingPolicyId
        live_fixture_actuator_cap_binding_validated_actuator_count = 8
        live_fixture_actuator_cap_binding_write_count = 8
        live_fixture_actuator_cap_binding_readback_count = 8
        live_fixture_actuator_cap_binding_mutation_rejection_count = 14
        positive_terminal_projection_canary_count = 1
        failure_terminal_projection_canary_count = 2
        terminal_projection_mutation_rejection_count = 10
        observation_mutation_rejection_count = 20
        live_fixture_cap_binding_projection_mutation_rejection_count = 16
        terminal_projection_uses_worker_execution_object = $true
        model_construction_count = 0
        world_attempt_count = 0
        world_build_count = 0
        physical_execution_authorized = $false
        physical_acceptance_authority = $false
    }
}

function Get-R23D56SourceBindings($Implementation) {
    $paths = [Collections.Generic.List[string]]::new()
    foreach ($path in @($Implementation.source_binding_policy.exact_paths)) {
        $paths.Add(([string]$path).Replace("\", "/"))
    }
    foreach ($prefix in @($Implementation.source_binding_policy.tracked_prefixes)) {
        $listed = Invoke-R23D56Git @("ls-files", "--", [string]$prefix)
        $expanded = @($listed -split "`n" |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
        Assert-R23D56 ($expanded.Count -gt 0) "empty source-binding prefix: $prefix"
        foreach ($path in $expanded) { $paths.Add($path.Replace("\", "/")) }
    }
    $duplicates = @($paths | Group-Object | Where-Object Count -gt 1)
    Assert-R23D56 ($duplicates.Count -eq 0) "duplicate source-binding paths"
    $bindings = [Collections.Generic.List[object]]::new()
    foreach ($relative in $paths) {
        $absolute = Join-Path $repoRoot $relative
        Assert-R23D56 (Test-Path -LiteralPath $absolute -PathType Leaf) (
            "source binding is missing: $relative"
        )
        $blob = Invoke-R23D56Git @("rev-parse", "HEAD:$relative")
        $checkout = Invoke-R23D56Git @("hash-object", "--no-filters", "--", $relative)
        Assert-R23D56 ($blob -ceq $checkout) (
            "checkout bytes differ from Git blob: $relative"
        )
        $bindings.Add([ordered]@{
            path = $relative
            raw_sha256 = Get-R23D56Sha256 $absolute
            git_blob_oid = $blob
            raw_checkout_equals_git_blob = $true
            media_type = Get-R23D56MediaType $relative
        })
    }
    return @($bindings)
}

function Assert-R23D56FrozenBindings($Freeze) {
    foreach ($binding in @($Freeze.source_bindings)) {
        $path = Join-Path $repoRoot ([string]$binding.path)
        Assert-R23D56 (
            (Test-Path -LiteralPath $path -PathType Leaf) -and
            [string]$binding.raw_sha256 -ceq (Get-R23D56Sha256 $path) -and
            [string]$binding.git_blob_oid -ceq
                (Invoke-R23D56Git @("rev-parse", "HEAD:$([string]$binding.path)")) -and
            [string]$binding.git_blob_oid -ceq
                (Invoke-R23D56Git @("hash-object", "--no-filters", "--", [string]$binding.path))
        ) "frozen source binding changed: $([string]$binding.path)"
    }
    foreach ($runtime in @($Freeze.runtime_artifacts) + @($Freeze.external_runtime_bindings)) {
        $path = [IO.Path]::GetFullPath([string]$runtime.path)
        Assert-R23D56 (
            (Test-Path -LiteralPath $path -PathType Leaf) -and
            [string]$runtime.raw_sha256 -ceq (Get-R23D56Sha256 $path)
        ) "frozen runtime changed: $path"
    }
}

function Publish-R23D56Inputs(
    $SourceBindings,
    $RuntimeArtifacts,
    $ExternalRuntimeBindings,
    [string]$AdoptionPath
) {
    $source = @(
        foreach ($binding in @($SourceBindings)) {
            Publish-SporeSporeContentAddressedArtifact -RepoRoot $repoRoot `
                -ArtifactPath (Join-Path $repoRoot ([string]$binding.path)) `
                -MediaType ([string]$binding.media_type)
        }
    )
    $runtime = @(
        foreach ($binding in @($RuntimeArtifacts) + @($ExternalRuntimeBindings)) {
            Publish-SporeSporeContentAddressedArtifact -RepoRoot $repoRoot `
                -ArtifactPath ([string]$binding.path) `
                -MediaType ([string]$binding.media_type)
        }
    )
    $adoption = Publish-SporeSporeContentAddressedArtifact -RepoRoot $repoRoot `
        -ArtifactPath $AdoptionPath -MediaType "application/json"
    return [ordered]@{
        source_bindings = $source
        runtime_bindings = $runtime
        campaign_attestation_adoption = $adoption
        physical_acceptance_authority = $false
    }
}

function Get-R23D56TerminalFailure(
    [string]$CellId,
    [string]$EngineId,
    [string]$ArmId,
    [string]$SourceCommit,
    [string]$Code,
    [int]$WorldAttemptCount = 0,
    [int]$WorldBuildCount = 0,
    [bool]$WorldBuildCountExact = $true,
    [int]$WorldBuildCountUpperBound = $WorldBuildCount
) {
    return [ordered]@{
        schema_version = "sporespore_qsdk_r23d56_supervisor_failure_v1"
        campaign_id = $campaignId
        gate_id = $gateId
        stage_id = $stageId
        cell_id = $CellId
        engine_id = $EngineId
        onset_id = "onset_600"
        turn_start_semantic_step = 600
        arm_id = $ArmId
        turn_heading_offset_rad = if ($ArmId -ceq "positive_heading") {
            0.2
        } elseif ($ArmId -ceq "negative_heading") { -0.2 } else { 0.0 }
        source_commit = $SourceCommit
        failure_stage = "supervisor_transport"
        failure_code = $Code
        world_attempt_count = $WorldAttemptCount
        world_build_count = $WorldBuildCount
        world_build_count_exact = $WorldBuildCountExact
        world_build_count_lower_bound = $WorldBuildCount
        world_build_count_upper_bound = $WorldBuildCountUpperBound
        claims = [ordered]@{
            godot_jolt_r23d29_turning = $false
            mujoco_r23d29_turning = $false
            finite_three_engine_turning = $false
            portable_basic_turning = $false
            cross_engine_equivalence = $false
            population_robustness = $false
            prone_to_standing = $false
            release_authorized = $false
            physical_acceptance_authority = $false
        }
    }
}

function Invoke-R23D56Cell {
    param(
        [Parameter(Mandatory)][string]$EngineId,
        [Parameter(Mandatory)][string]$ArmId,
        [Parameter(Mandatory)][string]$SourceCommit,
        [Parameter(Mandatory)][string]$FreezePayload,
        [Parameter(Mandatory)][string]$AttemptPayload,
        [Parameter(Mandatory)][string]$Token,
        [Parameter(Mandatory)][string]$AttemptRoot,
        [Parameter(Mandatory)][string]$CellRoot,
        [Parameter(Mandatory)][string]$PythonHost,
        [Parameter(Mandatory)][string]$PowerShellHost
    )
    Assert-R23D56 ($EngineId -ceq "godot_jolt") (
        "R23D56 is Godot-only; unexpected engine: $EngineId"
    )
    [void][IO.Directory]::CreateDirectory($CellRoot)
    $cellId = "$EngineId`__$candidateId`__$ArmId"
    $environment = @{
        "SPORESPORE_QSDK_R23D56_FREEZE" = $FreezePayload
        "SPORESPORE_QSDK_R23D56_ATTEMPT" = $AttemptPayload
        "SPORESPORE_QSDK_R23D56_TOKEN" = $Token
        "SPORESPORE_QSDK_R23D56_STAGE" = $stageId
        "SPORESPORE_QSDK_R23D56_CELL" = $cellId
        "SPORESPORE_QSDK_R23D56_ENGINE" = $EngineId
        "SPORESPORE_QSDK_R23D56_ATTEMPT_ROOT" = $AttemptRoot
        "SPORESPORE_QSDK_R23D56_PYTHON" = $PythonHost
        "SPORESPORE_QSDK_R23D56_POWERSHELL" = $PowerShellHost
    }
    $fileName = $Godot
    $arguments = @(
        "--headless", "--path", $repoRoot, "--script", $godotWorkerPath, "--",
        "--stage", $stageId, "--onset", "onset_600", "--arm", $ArmId,
        "--source-commit", $SourceCommit
    )
    $marker = "QSDK_R23D56_GODOT_JOLT_TERMINAL "
    $process = Invoke-R23D56GodotWorkerProcess -Arguments $arguments `
        -Environment $environment `
        -TimeoutSeconds $CellTimeoutSeconds
    $stdoutPath = Join-Path $CellRoot "stdout.txt"
    $stderrPath = Join-Path $CellRoot "stderr.txt"
    [IO.File]::WriteAllText($stdoutPath, [string]$process.stdout, [Text.UTF8Encoding]::new($false))
    [IO.File]::WriteAllText($stderrPath, [string]$process.stderr, [Text.UTF8Encoding]::new($false))
    $stdoutCas = Publish-SporeSporeContentAddressedArtifact -RepoRoot $repoRoot `
        -ArtifactPath $stdoutPath -MediaType "text/plain"
    $stderrCas = Publish-SporeSporeContentAddressedArtifact -RepoRoot $repoRoot `
        -ArtifactPath $stderrPath -MediaType "text/plain"
    try {
        if ([bool]$process.timed_out) { throw "R23D56_CELL_TIMEOUT" }
        if (-not [bool]$process.termination_protocol_valid) {
            throw "R23D56_GODOT_TERMINATION_PROTOCOL_INVALID"
        }
        if (-not [bool]$process.supervisor_terminated) {
            throw "R23D56_GODOT_SUPERVISOR_TERMINATION_MISSING"
        }
        if (
            [string]$process.termination_ready_receipt.worker_receipt_kind -cne
                "terminal"
        ) {
            throw "R23D56_GODOT_TERMINATION_RECEIPT_KIND_INVALID"
        }
        $terminal = Get-R23D56MarkerJson ([string]$process.stdout) $marker
        if ([string]$terminal.cell_id -cne $cellId) { throw "R23D56_CELL_MARKER_ID" }
        $terminalProjection = Get-SporeSporeTerminalExecutionProjection `
            -Terminal $terminal -SuccessSchemas $terminalSuccessSchemas `
            -FailureSchemas $terminalFailureSchemas
    } catch {
        $terminal = Get-R23D56TerminalFailure -CellId $cellId -EngineId $EngineId `
            -ArmId $ArmId -SourceCommit $SourceCommit `
            -Code ("R23D56_SUPERVISOR_TERMINAL_CAPTURE:" + $_.Exception.Message) `
            -WorldAttemptCount 1 -WorldBuildCount 0 `
            -WorldBuildCountExact $false -WorldBuildCountUpperBound 1
        $terminalProjection = Get-SporeSporeTerminalExecutionProjection `
            -Terminal $terminal -SuccessSchemas $terminalSuccessSchemas `
            -FailureSchemas $terminalFailureSchemas
    }
    $terminalPath = Join-Path $CellRoot "terminal.json"
    Write-R23D56NewJson $terminalPath $terminal
    $terminalCas = Publish-SporeSporeContentAddressedArtifact -RepoRoot $repoRoot `
        -ArtifactPath $terminalPath -MediaType "application/json"
    return [ordered]@{
        cell_id = $cellId
        engine_id = $EngineId
        arm_id = $ArmId
        process = [ordered]@{
            exit_code = [int]$process.exit_code
            host_exit_code = [int]$process.host_exit_code
            timed_out = [bool]$process.timed_out
            supervisor_terminated = [bool]$process.supervisor_terminated
            termination_protocol_valid = [bool]$process.termination_protocol_valid
            termination_protocol_failure_code = (
                [string]$process.termination_protocol_failure_code
            )
            termination_ready_receipt = $process.termination_ready_receipt
            started_utc = [string]$process.started_utc
            completed_utc = [string]$process.completed_utc
            stdout_cas = $stdoutCas
            stderr_cas = $stderrCas
        }
        terminal_entry_cas = $terminalCas
        terminal_schema = [string]$terminal.schema_version
        terminal_projection_source = [string]$terminalProjection.projection_source
        world_attempt_count = [int]$terminalProjection.world_attempt_count
        world_build_count = [int]$terminalProjection.world_build_count
        world_build_count_exact = [bool]$terminalProjection.world_build_count_exact
        world_build_count_lower_bound = (
            [int]$terminalProjection.world_build_count_lower_bound
        )
        world_build_count_upper_bound = (
            [int]$terminalProjection.world_build_count_upper_bound
        )
        physical_acceptance_authority = $false
    }
}

Assert-R23D56 ($PreflightOnly -xor $RunPhysical) (
    "select exactly one of -PreflightOnly or -RunPhysical"
)
Assert-R23D56 (Test-Path -LiteralPath $Godot -PathType Leaf) "Godot executable is missing"
$pythonHost = Resolve-R23D56Application $Python
$powerShellHost = Resolve-R23D56Application $PowerShell

if ($PreflightOnly) {
    Assert-R23D56 ([string]::IsNullOrWhiteSpace($CampaignAttestationAdoption)) (
        "preflight does not accept physical authorization"
    )
    Assert-R23D56 ([string]::IsNullOrWhiteSpace($OutputRoot)) (
        "preflight does not accept a physical output root"
    )
    $receipt = Invoke-R23D56ZeroWorld $pythonHost
    Write-Host (
        "QSDK_R23D56_ZERO_WORLD_PASS " +
        ($receipt | ConvertTo-Json -Depth 100 -Compress)
    )
    exit 0
}

Assert-R23D56 (-not [string]::IsNullOrWhiteSpace($CampaignAttestationAdoption)) (
    "physical execution requires a campaign-attestation adoption"
)
foreach ($path in @($preregistrationPath, $implementationPath, $manifestPath)) {
    Assert-R23D56 (Test-Path -LiteralPath $path -PathType Leaf) "missing contract: $path"
}
$source = Get-SporeSporeAttestationSourceIdentity -RepoRoot $repoRoot `
    -RequireCleanPushedLive
$adoption = Test-SporeSporeCampaignAttestationAdoptionFile -RepoRoot $repoRoot `
    -ManifestPath $manifestPath `
    -AdoptionPath ([IO.Path]::GetFullPath($CampaignAttestationAdoption)) `
    -Godot $Godot -Python $pythonHost -ExpectedCampaignId $campaignId
Assert-R23D56 ([bool]$adoption.ok) (
    "campaign-attestation adoption failed: $(@($adoption.failure_codes) -join ',')"
)
Assert-R23D56 (
    [string]$adoption.source.commit -ceq [string]$source.commit -and
    [string]$adoption.source.tree_git_oid -ceq [string]$source.tree_git_oid
) "adoption source differs from the live source"

$lock = Enter-SporeSporeLocomotionOperationLock -Role physical
Assert-R23D56 ([bool]$lock.acquired) "global locomotion operation lock is held"
$attemptConsumed = $false
$completionPath = ""
try {
    $evidenceRoot = Get-SporeSporeArtifactEvidenceRoot -RepoRoot $repoRoot
    $prior = @(Get-ChildItem -LiteralPath $evidenceRoot -Directory | Where-Object {
        $_.Name -like "qsdk-r23d56-*" -and (
            (Test-Path -LiteralPath (Join-Path $_.FullName "attempt-authorization.json")) -or
            (Test-Path -LiteralPath (Join-Path $_.FullName "completion.json"))
        )
    })
    Assert-R23D56 ($prior.Count -eq 0) "one-shot R23D56 identity already exists"
    $resolvedOutput = if ([string]::IsNullOrWhiteSpace($OutputRoot)) {
        Join-Path $evidenceRoot (
            "qsdk-r23d56-" + [DateTime]::UtcNow.ToString("yyyyMMddTHHmmssZ")
        )
    } else { [IO.Path]::GetFullPath($OutputRoot) }
    $prefix = $evidenceRoot.TrimEnd("\", "/") + [IO.Path]::DirectorySeparatorChar
    Assert-R23D56 (
        $resolvedOutput.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase) -and
        -not (Test-Path -LiteralPath $resolvedOutput)
    ) "output must be a new directory under $evidenceRoot"
    [void][IO.Directory]::CreateDirectory($resolvedOutput)
    $completionPath = Join-Path $resolvedOutput "completion.json"

    . $runtimeHelperPath
    $godotBuild = Invoke-SporeSporeR23D3PinnedCargo -RepoRoot $repoRoot `
        -SourceCommit ([string]$source.commit) -TargetRoot (Join-Path $sdkRoot "target") `
        -CargoArguments @(
            "build", "--quiet", "--locked", "--offline",
            "--manifest-path", (Join-Path $sdkRoot "Cargo.toml"),
            "--package", "sporespore-godot-adapter"
        )
    foreach ($artifact in @($godotAdapterPath)) {
        Assert-R23D56 (Test-Path -LiteralPath $artifact -PathType Leaf) (
            "reproducible runtime artifact is missing: $artifact"
        )
    }
    $zeroWorld = Invoke-R23D56ZeroWorld $pythonHost
    $sourceAfter = Get-SporeSporeAttestationSourceIdentity -RepoRoot $repoRoot `
        -RequireCleanPushedLive
    Assert-R23D56 (
        [string]$sourceAfter.commit -ceq [string]$source.commit -and
        [string]$sourceAfter.tree_git_oid -ceq [string]$source.tree_git_oid
    ) "source changed during runtime materialization or zero-world gate"

    $implementation = Get-Content -Raw -LiteralPath $implementationPath |
        ConvertFrom-Json -AsHashtable -Depth 100
    $sourceBindings = Get-R23D56SourceBindings $implementation
    $runtimeArtifacts = @(
        [ordered]@{
            name = "godot_adapter_debug"
            path = $godotAdapterPath
            raw_sha256 = Get-R23D56Sha256 $godotAdapterPath
            media_type = "application/vnd.microsoft.portable-executable"
            build_receipt = $godotBuild
        }
    )
    $externalRuntimeBindings = @(
        [ordered]@{
            name = "godot_jolt_host"
            path = $Godot
            raw_sha256 = Get-R23D56Sha256 $Godot
            media_type = "application/vnd.microsoft.portable-executable"
        },
        [ordered]@{
            name = "evaluator_python_host"
            path = $pythonHost
            raw_sha256 = Get-R23D56Sha256 $pythonHost
            media_type = "application/vnd.microsoft.portable-executable"
        },
        [ordered]@{
            name = "powershell_trace_host"
            path = $powerShellHost
            raw_sha256 = Get-R23D56Sha256 $powerShellHost
            media_type = "application/vnd.microsoft.portable-executable"
        }
    )
    $inputCas = Publish-R23D56Inputs $sourceBindings $runtimeArtifacts `
        $externalRuntimeBindings ([IO.Path]::GetFullPath($CampaignAttestationAdoption))
    $freeze = [ordered]@{
        schema_version = "sporespore_qsdk_r23d56_physical_freeze_v1"
        status = "frozen_supervisor_only_physical_authorized"
        campaign_id = $campaignId
        gate_id = $gateId
        preregistration_raw_sha256 = Get-R23D56Sha256 $preregistrationPath
        implementation_contract_raw_sha256 = Get-R23D56Sha256 $implementationPath
        source_commit = [string]$source.commit
        source_tree_git_oid = [string]$source.tree_git_oid
        origin_main_commit = [string]$source.origin_main
        live_github_main_commit = [string]$source.live_github_main
        source_bindings = $sourceBindings
        runtime_artifacts = $runtimeArtifacts
        external_runtime_bindings = $externalRuntimeBindings
        content_addressed_inputs = $inputCas
        campaign_attestation_adoption_sha256 = [string]$adoption.sha256
        complete_zero_world_gate_passed = $true
        zero_world_receipt = $zeroWorld
        declared_world_count = 3
        ordered_matrix_cell_ids = $cellIds
        serial_execution_required = $true
        all_cells_run_regardless_of_intermediate_outcome = $true
        terminal_restoration_or_taper_invoked = $false
        source_checkout_bytes_equal_git_blobs = $true
        reproducible_runtime_materialization_passed = $true
        physical_execution_authorized = $true
        physical_acceptance_authority = $false
    }
    $freezePath = Join-Path $resolvedOutput "physical-freeze.json"
    Write-R23D56NewJson $freezePath $freeze
    $freezeCas = Publish-SporeSporeContentAddressedArtifact -RepoRoot $repoRoot `
        -ArtifactPath $freezePath -MediaType "application/json"
    Assert-R23D56FrozenBindings $freeze

    $attemptId = [guid]::NewGuid().ToString("N")
    $token = [guid]::NewGuid().ToString("N")
    $attempt = [ordered]@{
        schema_version = "sporespore_qsdk_r23d56_attempt_v1"
        campaign_id = $campaignId
        gate_id = $gateId
        attempt_id = $attemptId
        authorization_token = $token
        source_commit = [string]$source.commit
        freeze_raw_sha256 = [string]$freezeCas.sha256
        attempt_root = $resolvedOutput
        ordered_matrix_cell_ids = $cellIds
        physical_execution_authorized = $true
        single_use_supervisor_authorization = $true
        matrix_authorization_immutable_before_first_world = $true
        source_worktree_clean = $true
        source_matches_live_github_main = $true
        operation_lock_held = $true
        campaign_attestation_adoption_valid = $true
        content_addressed_inputs_retained = $true
        content_addressed_inputs = $inputCas
        one_shot_attempt_unconsumed = $true
        all_cells_run_regardless_of_intermediate_outcome = $true
        physical_acceptance_authority = $false
    }
    $attemptPath = Join-Path $resolvedOutput "attempt-authorization.json"
    Write-R23D56NewJson $attemptPath $attempt
    $attemptCas = Publish-SporeSporeContentAddressedArtifact -RepoRoot $repoRoot `
        -ArtifactPath $attemptPath -MediaType "application/json"
    $attemptConsumed = $true

    $cells = [Collections.Generic.List[object]]::new()
    foreach ($engine in $engineOrder) {
        foreach ($arm in $armOrder) {
            Assert-R23D56FrozenBindings $freeze
            $cellRoot = Join-Path $resolvedOutput "cells\$engine`__$candidateId`__$arm"
            $cells.Add((Invoke-R23D56Cell -EngineId $engine -ArmId $arm `
                -SourceCommit ([string]$source.commit) `
                -FreezePayload ([string]$freezeCas.payload_path) `
                -AttemptPayload ([string]$attemptCas.payload_path) -Token $token `
                -AttemptRoot $resolvedOutput -CellRoot $cellRoot `
                -PythonHost $pythonHost -PowerShellHost $powerShellHost))
        }
    }
    $terminalPaths = @($cells | ForEach-Object {
        [string]$_.terminal_entry_cas.payload_path
    })
    $manifestOutput = Join-Path $resolvedOutput "terminal-paths.json"
    Write-R23D56NewJson $manifestOutput $terminalPaths
    $manifestCas = Publish-SporeSporeContentAddressedArtifact -RepoRoot $repoRoot `
        -ArtifactPath $manifestOutput -MediaType "application/json"
    $evaluationProcess = Invoke-R23D56Process -FileName $pythonHost -Arguments @(
        $evaluatorPath, "evaluate-complete", "--manifest",
        [string]$manifestCas.payload_path, "--expected-source-commit",
        [string]$source.commit, "--repo-root", $repoRoot
    ) -WorkingDirectory $repoRoot -Environment (Get-R23D56PythonEnvironment) `
        -TimeoutSeconds 300
    Assert-R23D56 ($evaluationProcess.exit_code -eq 0 -and -not $evaluationProcess.timed_out) (
        "complete evaluator failed: $($evaluationProcess.stderr) $($evaluationProcess.stdout)"
    )
    $evaluation = Get-R23D56MarkerJson $evaluationProcess.stdout (
        "QSDK_R23D56_COMPLETE_EVALUATION "
    )
    $evaluationPath = Join-Path $resolvedOutput "complete-evaluation.json"
    Write-R23D56NewJson $evaluationPath $evaluation
    $evaluationCas = Publish-SporeSporeContentAddressedArtifact -RepoRoot $repoRoot `
        -ArtifactPath $evaluationPath -MediaType "application/json"
    $worldCountLowerBound = 0
    $worldCountUpperBound = 0
    $worldCountExact = $true
    foreach ($cell in @($cells)) {
        $worldCountLowerBound += [int]$cell.world_build_count_lower_bound
        $worldCountUpperBound += [int]$cell.world_build_count_upper_bound
        $worldCountExact = $worldCountExact -and [bool]$cell.world_build_count_exact
    }
    $report = [ordered]@{
        schema_version = "sporespore_qsdk_r23d56_campaign_report_v1"
        campaign_id = $campaignId
        gate_id = $gateId
        source = $source
        attempt_id = $attemptId
        freeze_cas = $freezeCas
        attempt_authorization_cas = $attemptCas
        terminal_manifest_cas = $manifestCas
        complete_evaluation_cas = $evaluationCas
        ordered_cells = @($cells)
        complete_evaluation = $evaluation
        result_classification = [string]$evaluation.classification
        all_three_cells_executed_or_retained_as_failures = $cells.Count -eq 3
        world_build_count_exact = $worldCountExact
        world_build_count_lower_bound = $worldCountLowerBound
        world_build_count_upper_bound = $worldCountUpperBound
        terminal_restoration_or_taper_invoked = $false
        claims = $evaluation.claims
    }
    $reportPath = Join-Path $resolvedOutput "report.json"
    Write-R23D56NewJson $reportPath $report
    $reportCas = Publish-SporeSporeContentAddressedArtifact -RepoRoot $repoRoot `
        -ArtifactPath $reportPath -MediaType "application/json"
    $completion = [ordered]@{
        schema_version = "sporespore_qsdk_r23d56_completion_v1"
        campaign_id = $campaignId
        gate_id = $gateId
        attempt_id = $attemptId
        status = [string]$evaluation.classification
        source_commit = [string]$source.commit
        cell_count = $cells.Count
        world_count = $worldCountLowerBound
        world_count_exact = $worldCountExact
        world_count_lower_bound = $worldCountLowerBound
        world_count_upper_bound = $worldCountUpperBound
        report_cas = $reportCas
        complete_evaluation_cas = $evaluationCas
        one_shot_attempt_consumed = $true
        replacement_or_selective_rerun_permitted = $false
        completed_utc = [DateTime]::UtcNow.ToString("o")
        physical_acceptance_authority = $false
    }
    Write-R23D56NewJson $completionPath $completion
    $completionCas = Publish-SporeSporeContentAddressedArtifact -RepoRoot $repoRoot `
        -ArtifactPath $completionPath -MediaType "application/json"
    Write-Host (
        "QSDK_R23D56_PHYSICAL_COMPLETE classification=$($evaluation.classification) " +
        "cells=$($cells.Count) report_sha256=$($reportCas.sha256) " +
        "completion_sha256=$($completionCas.sha256) output=$resolvedOutput"
    )
    if (([string]$evaluation.classification).StartsWith(
        "invalid_",
        [StringComparison]::Ordinal
    )) {
        throw "QSDK-R23D56 retained an invalid complete first attempt: $resolvedOutput"
    }
} catch {
    if ($attemptConsumed -and -not [string]::IsNullOrWhiteSpace($completionPath) -and
        -not (Test-Path -LiteralPath $completionPath)) {
        $emergency = [ordered]@{
            schema_version = "sporespore_qsdk_r23d56_completion_v1"
            campaign_id = $campaignId
            gate_id = $gateId
            status = "invalid_or_incomplete_first_attempt"
            source_commit = [string]$source.commit
            one_shot_attempt_consumed = $true
            replacement_or_selective_rerun_permitted = $false
            failure_message = [string]$_.Exception.Message
            completed_utc = [DateTime]::UtcNow.ToString("o")
            physical_acceptance_authority = $false
        }
        Write-R23D56NewJson $completionPath $emergency
        [void](Publish-SporeSporeContentAddressedArtifact -RepoRoot $repoRoot `
            -ArtifactPath $completionPath -MediaType "application/json")
    }
    throw
} finally {
    Exit-SporeSporeLocomotionOperationLock $lock
}
