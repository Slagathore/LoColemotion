#requires -Version 7.0

[CmdletBinding()]
param(
    [switch]$PreflightOnly,
    [switch]$RunPhysical,
    [string]$CampaignAttestationAdoption = "",
    [string]$OutputRoot = "",
    [string]$Godot = "C:\Users\Cole\CodeStuff\Misc\Godot\Godot_v4.7-stable_mono_win64_console.exe",
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
$campaignId = "QSDK-R23D60-GODOT-KNEE-SOURCE-FROZEN-PROFILE-HELD-OUT-TURNING-VALIDATION"
$gateId = "QSDK-R23D60"
$stageId = "godot_fixture_knee_held_out_turning_validation"
$engineId = "godot_jolt"
$campaignSeed = 21516
$profileId = "portable_hip__fixture_knee"
$armOffsets = [ordered]@{
    reference_zero = 0.0
    positive_heading = 0.2
    negative_heading = -0.2
}
$cellIds = @(
    foreach ($armId in $armOffsets.Keys) {
        "$engineId`__s$campaignSeed`__$profileId`__$armId"
    }
)

$preregistrationPath = Join-Path $turningRoot "r23d60_godot_fixture_knee_held_out_turning_validation_preregistration_v1.json"
$implementationPath = Join-Path $turningRoot "r23d60_godot_fixture_knee_held_out_turning_validation_implementation_v1.json"
$campaignManifestPath = Join-Path $turningRoot "r23d60_campaign_attestation_manifest_v1.json"
$dependencyToolPath = Join-Path $turningRoot "r23d60_dependency_closure.py"
$evaluatorPath = Join-Path $turningRoot "r23d60_godot_fixture_knee_held_out_turning_validation_evaluator.py"
$workerResourcePath = "res://tests/test_sdk_qsdk_r23d60_godot_jolt_physical_worker.gd"
$preregistrationGatePath = Join-Path $repoRoot "tests\test_qsdk_r23d60_preregistration.ps1"
$dependencyGatePath = Join-Path $repoRoot "tests\test_qsdk_r23d60_dependency_closure.ps1"
$parentClosureGatePath = Join-Path $repoRoot "tests\test_qsdk_r23d59_physical_closure.ps1"
$terminalProjectionGatePath = Join-Path $repoRoot "tests\test_locomotion_terminal_execution_projection.ps1"
$taskOriginGateResource = "res://tests/test_sdk_qsdk_r23d53_task_frame_origin_policy.gd"
$capSourceGatePath = Join-Path $repoRoot "tests\test_qsdk_r23d55_live_fixture_actuator_cap_contract.ps1"
$capRuntimeGateResource = "res://tests/test_sdk_qsdk_r23d55_godot_live_fixture_actuator_cap_conformance.gd"
$actuatorPhaseGateResource = "res://tests/test_sdk_godot_actuator_phase_observation.gd"
$runtimeHelperPath = Join-Path $sdkRoot "r23d3_reproducible_runtime_materialization.ps1"
$godotAdapterPath = Join-Path $sdkRoot "target\debug\sporespore_godot_adapter.dll"
$godotReadyMarker = "QSDK_R23D60_GODOT_SUPERVISOR_TERMINATION_READY "

$physicalEnvironmentNames = @(
    "SPORESPORE_QSDK_R23D60_FREEZE",
    "SPORESPORE_QSDK_R23D60_ATTEMPT",
    "SPORESPORE_QSDK_R23D60_TOKEN",
    "SPORESPORE_QSDK_R23D60_STAGE",
    "SPORESPORE_QSDK_R23D60_CELL",
    "SPORESPORE_QSDK_R23D60_ENGINE",
    "SPORESPORE_QSDK_R23D60_ATTEMPT_ROOT",
    "SPORESPORE_QSDK_R23D60_PYTHON",
    "SPORESPORE_QSDK_R23D60_POWERSHELL",
    "SPORESPORE_QSDK_R23D60_SUPERVISED_TERMINATION",
    "SPORESPORE_QSDK_R23D60_TERMINATION_NONCE",
    "SPORESPORE_QSDK_R23D59_FREEZE",
    "SPORESPORE_QSDK_R23D59_ATTEMPT",
    "SPORESPORE_QSDK_R23D58_FREEZE",
    "SPORESPORE_QSDK_R23D58_ATTEMPT",
    "SPORESPORE_QSDK_R23D48_FREEZE",
    "SPORESPORE_QSDK_R23D48_ATTEMPT"
)

. (Join-Path $sdkRoot "content_addressed_artifact_store.ps1")
. (Join-Path $sdkRoot "godot_receipt_terminated_process.ps1")
. (Join-Path $sdkRoot "locomotion_operation_lock.ps1")
. (Join-Path $sdkRoot "locomotion_full_conformance_attestation.ps1")
. (Join-Path $sdkRoot "locomotion_campaign_attestation_adoption.ps1")
. (Join-Path $sdkRoot "locomotion_terminal_execution_projection.ps1")
. $runtimeHelperPath

$terminalSuccessSchemas = @("sporespore_qsdk_r23d60_engine_cell_report_v1")
$terminalFailureSchemas = @(
    "sporespore_qsdk_r23d60_worker_failure_v1",
    "sporespore_qsdk_r23d60_supervisor_failure_v1"
)

function Assert-R23D60([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "QSDK-R23D60: $Message" }
}

function Resolve-R23D60Application([string]$Command) {
    if ([IO.Path]::IsPathFullyQualified($Command)) {
        $resolved = [IO.Path]::GetFullPath($Command)
        Assert-R23D60 (Test-Path -LiteralPath $resolved -PathType Leaf) (
            "application is missing: $resolved"
        )
        return $resolved
    }
    $candidate = Get-Command $Command -CommandType Application -ErrorAction Stop |
        Select-Object -First 1
    return [IO.Path]::GetFullPath([string]$candidate.Source)
}

function Get-R23D60Sha256([string]$Path) {
    return "sha256:" + (
        Get-FileHash -LiteralPath $Path -Algorithm SHA256
    ).Hash.ToLowerInvariant()
}

function Invoke-R23D60Git([string[]]$Arguments) {
    $lines = @(& git -C $repoRoot @Arguments 2>&1)
    if ($LASTEXITCODE -ne 0) {
        throw "QSDK-R23D60 git $($Arguments -join ' ') failed: $($lines -join ' ')"
    }
    return ($lines -join "`n").Trim()
}

function Write-R23D60NewJson([string]$Path, $Value) {
    $resolved = [IO.Path]::GetFullPath($Path)
    if (Test-Path -LiteralPath $resolved) {
        throw "QSDK-R23D60 refuses to overwrite: $resolved"
    }
    [void][IO.Directory]::CreateDirectory((Split-Path -Parent $resolved))
    [IO.File]::WriteAllText(
        $resolved,
        ($Value | ConvertTo-Json -Depth 100) + "`n",
        [Text.UTF8Encoding]::new($false)
    )
}

function Get-R23D60MediaType([string]$Path) {
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

function Invoke-R23D60Process {
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

function Invoke-R23D60GodotWorkerProcess {
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
    $workerEnvironment["SPORESPORE_QSDK_R23D60_SUPERVISED_TERMINATION"] = "1"
    $workerEnvironment["SPORESPORE_QSDK_R23D60_TERMINATION_NONCE"] = $terminationNonce
    return Invoke-SporeSporeGodotReceiptTerminatedProcess -FileName $Godot `
        -Arguments $Arguments -WorkingDirectory $repoRoot `
        -ReadyMarkerPrefix $godotReadyMarker -ExpectedNonce $terminationNonce `
        -Environment $workerEnvironment `
        -ScrubEnvironmentNames $physicalEnvironmentNames `
        -TimeoutSeconds $TimeoutSeconds
}

function Get-R23D60MarkerJson([string]$Text, [string]$Prefix) {
    $lines = @($Text -split "`r?`n" | Where-Object {
        ([string]$_).StartsWith($Prefix, [StringComparison]::Ordinal)
    })
    Assert-R23D60 ($lines.Count -eq 1) (
        "expected one '$Prefix' marker, observed $($lines.Count)"
    )
    return $lines[0].Substring($Prefix.Length) |
        ConvertFrom-Json -AsHashtable -Depth 100
}

function Assert-R23D60PlainMarker(
    [string]$Text,
    [string]$Prefix,
    [string]$GateName
) {
    $matches = @($Text -split "`r?`n" | Where-Object {
        ([string]$_).StartsWith($Prefix, [StringComparison]::Ordinal)
    })
    Assert-R23D60 ($matches.Count -eq 1) "$GateName marker changed"
    return [string]$matches[0]
}

function Get-R23D60PythonEnvironment {
    return @{
        "PYTHONPATH" = (@(
            (Join-Path $sdkRoot "python"),
            $turningRoot
        ) -join [IO.Path]::PathSeparator)
    }
}

function Get-R23D60DependencyInventory(
    [string]$PythonHost,
    [bool]$RequireCleanGitBytes
) {
    $arguments = @(
        $dependencyToolPath,
        "--repo-root", $repoRoot,
        "--contract", $implementationPath
    )
    if ($RequireCleanGitBytes) { $arguments += "--require-clean-git-bytes" }
    $process = Invoke-R23D60Process -FileName $PythonHost `
        -Arguments $arguments -WorkingDirectory $repoRoot `
        -Environment (Get-R23D60PythonEnvironment) -TimeoutSeconds 300
    Assert-R23D60 ($process.exit_code -eq 0 -and -not $process.timed_out) (
        "dependency inventory failed: $($process.stderr) $($process.stdout)"
    )
    $receipt = Get-R23D60MarkerJson $process.stdout (
        "QSDK_R23D60_DEPENDENCY_INVENTORY "
    )
    Assert-R23D60 (
        [string]$receipt.schema_version -ceq
            "sporespore_qsdk_r23d60_dependency_inventory_v1" -and
        [string]$receipt.campaign_id -ceq $campaignId -and
        [string]$receipt.gate_id -ceq $gateId -and
        [bool]$receipt.expected_transitive_path_set_exact -and
        [int]$receipt.transitive_path_count -gt 0 -and
        [int]$receipt.model_construction_count -eq 0 -and
        [int]$receipt.world_attempt_count -eq 0 -and
        [int]$receipt.world_build_count -eq 0 -and
        [bool]$receipt.checkout_bytes_equal_git_blobs -eq $RequireCleanGitBytes
    ) "dependency inventory receipt changed"
    return $receipt
}

function Invoke-R23D60Gate(
    [string]$FileName,
    [string[]]$Arguments,
    [string]$Marker,
    [string]$Name,
    [hashtable]$Environment = @{},
    [int]$TimeoutSeconds = 300
) {
    $result = Invoke-R23D60Process -FileName $FileName -Arguments $Arguments `
        -WorkingDirectory $repoRoot -Environment $Environment `
        -TimeoutSeconds $TimeoutSeconds
    Assert-R23D60 ($result.exit_code -eq 0 -and -not $result.timed_out) (
        "$Name failed: $($result.stderr) $($result.stdout)"
    )
    [void](Assert-R23D60PlainMarker $result.stdout $Marker $Name)
    return $result
}

function Invoke-R23D60ZeroWorld(
    [string]$PythonHost,
    [string]$PowerShellHost
) {
    foreach ($path in @(
        $preregistrationPath,
        $implementationPath,
        $dependencyToolPath,
        $dependencyGatePath,
        $parentClosureGatePath,
        $evaluatorPath,
        (Join-Path $repoRoot "sdk\target\debug\sporespore_godot_adapter.dll")
    )) {
        Assert-R23D60 (Test-Path -LiteralPath $path -PathType Leaf) (
            "zero-world dependency is missing: $path"
        )
    }
    $inventory = Get-R23D60DependencyInventory $PythonHost $false
    $preregistration = Invoke-R23D60Gate -FileName $PowerShellHost -Arguments @(
        "-NoLogo", "-NoProfile", "-File", $preregistrationGatePath,
        "-Python", $PythonHost, "-Godot", $Godot
    ) -Marker "QSDK_R23D60_PREREGISTRATION_PASS " -Name "R23D60 preregistration"
    $dependency = Invoke-R23D60Gate -FileName $PowerShellHost -Arguments @(
        "-NoLogo", "-NoProfile", "-File", $dependencyGatePath,
        "-Python", $PythonHost
    ) -Marker "QSDK_R23D60_DEPENDENCY_CLOSURE_PASS " -Name "R23D60 dependency closure"
    $parent = Invoke-R23D60Gate -FileName $PowerShellHost -Arguments @(
        "-NoLogo", "-NoProfile", "-File", $parentClosureGatePath
    ) -Marker "QSDK_R23D59_CLOSURE_PASS " -Name "immutable R23D59 parent closure"
    $terminalProjection = Invoke-R23D60Gate -FileName $PowerShellHost -Arguments @(
        "-NoLogo", "-NoProfile", "-File", $terminalProjectionGatePath
    ) -Marker "LOCOMOTION_TERMINAL_EXECUTION_PROJECTION_PASS " `
        -Name "terminal execution projection"
    $capSource = Invoke-R23D60Gate -FileName $PowerShellHost -Arguments @(
        "-NoLogo", "-NoProfile", "-File", $capSourceGatePath
    ) -Marker "QSDK_R23D55_LIVE_FIXTURE_ACTUATOR_CAP_CONTRACT_PASS " `
        -Name "live fixture cap source contract"

    $ordinaryGodotGates = @(
        [ordered]@{
            name = "task-frame origin"
            resource = $taskOriginGateResource
            marker = "QSDK_R23D53_TASK_FRAME_ORIGIN_PASS "
        },
        [ordered]@{
            name = "live fixture cap runtime"
            resource = $capRuntimeGateResource
            marker = "QSDK_R23D55_GODOT_LIVE_FIXTURE_ACTUATOR_CAP_CONFORMANCE "
        },
        [ordered]@{
            name = "actuator phase observation"
            resource = $actuatorPhaseGateResource
            marker = "SDK_GODOT_ACTUATOR_PHASE_OBSERVATION_PREFLIGHT "
        }
    )
    $ordinaryReceipts = [Collections.Generic.List[object]]::new()
    foreach ($definition in $ordinaryGodotGates) {
        $gate = Invoke-R23D60Gate -FileName $Godot -Arguments @(
            "--headless", "--path", $repoRoot, "--script", [string]$definition.resource
        ) -Marker ([string]$definition.marker) -Name ([string]$definition.name)
        $ordinaryReceipt = Get-R23D60MarkerJson $gate.stdout (
            [string]$definition.marker
        )
        switch ([string]$definition.name) {
            "task-frame origin" {
                Assert-R23D60 (
                    [bool]$ordinaryReceipt.ok -and
                    [string]$ordinaryReceipt.policy_id -ceq
                        "warmup_preserving_command_onset_origin_reanchor_v1" -and
                    [int]$ordinaryReceipt.assertion_count -eq 34 -and
                    [int]$ordinaryReceipt.rejected_mutation_count -eq 6 -and
                    [int]$ordinaryReceipt.model_construction_count -eq 0 -and
                    [int]$ordinaryReceipt.world_build_count -eq 0
                ) "task-frame origin zero-world receipt changed"
            }
            "live fixture cap runtime" {
                Assert-R23D60 (
                    [bool]$ordinaryReceipt.ok -and
                    [string]$ordinaryReceipt.schema_version -ceq
                        "sporespore_qsdk_r23d55_godot_live_fixture_actuator_cap_conformance_v1" -and
                    [string]$ordinaryReceipt.question_class -ceq "development" -and
                    [string]$ordinaryReceipt.policy_id -ceq
                        "sporespore_godot_jolt_live_fixture_compiled_actuator_cap_binding_v1" -and
                    [bool]$ordinaryReceipt.physical_entrypoint_option_normalized -and
                    [bool]$ordinaryReceipt.wrong_physical_entrypoint_policy_rejected -and
                    [int]$ordinaryReceipt.validated_actuator_count -eq 8 -and
                    [int]$ordinaryReceipt.validated_limb_count -eq 4 -and
                    [int]$ordinaryReceipt.unique_host_joint_object_count -eq 8 -and
                    [int]$ordinaryReceipt.write_count -eq 8 -and
                    [int]$ordinaryReceipt.readback_count -eq 8 -and
                    [double]$ordinaryReceipt.maximum_postbinding_readback_error_nms -le 2.5e-7 -and
                    [int]$ordinaryReceipt.mutation_rejection_count -eq 14 -and
                    [bool]$ordinaryReceipt.configured_parameter_readback_only -and
                    -not [bool]$ordinaryReceipt.measured_motor_torque_available -and
                    -not [bool]$ordinaryReceipt.measured_motor_impulse_available -and
                    [int]$ordinaryReceipt.scene_tree_insertion_count -eq 0 -and
                    [int]$ordinaryReceipt.model_construction_count -eq 0 -and
                    [int]$ordinaryReceipt.world_attempt_count -eq 0 -and
                    [int]$ordinaryReceipt.world_build_count -eq 0 -and
                    -not [bool]$ordinaryReceipt.physics_state_modified -and
                    -not [bool]$ordinaryReceipt.physical_successor_opened -and
                    -not [bool]$ordinaryReceipt.turning_claimed -and
                    -not [bool]$ordinaryReceipt.prone_to_standing_claimed -and
                    -not [bool]$ordinaryReceipt.physical_acceptance_authority
                ) "live fixture cap runtime zero-world receipt changed"
            }
            "actuator phase observation" {
                Assert-R23D60 (
                    [bool]$ordinaryReceipt.ok -and
                    [string]$ordinaryReceipt.observation_schema_version -ceq
                        "sporespore_godot_jolt_actuator_phase_observation_v1" -and
                    [string]$ordinaryReceipt.application_receipt_schema_version -ceq
                        "sporespore_godot_jolt_full_authority_application_receipt_v1" -and
                    [int]$ordinaryReceipt.validated_application_count -eq 8 -and
                    [int]$ordinaryReceipt.validated_limb_count -eq 4 -and
                    [int]$ordinaryReceipt.production_receipt_mutation_rejection_count -eq 2 -and
                    [int]$ordinaryReceipt.retained_row_mutation_rejection_count -eq 7 -and
                    [bool]$ordinaryReceipt.configured_motor_parameters_only -and
                    -not [bool]$ordinaryReceipt.measured_motor_torque_available -and
                    -not [bool]$ordinaryReceipt.measured_motor_impulse_available -and
                    [int]$ordinaryReceipt.scene_tree_insertion_count -eq 0 -and
                    [int]$ordinaryReceipt.model_construction_count -eq 0 -and
                    [int]$ordinaryReceipt.world_attempt_count -eq 0 -and
                    [int]$ordinaryReceipt.world_build_count -eq 0
                ) "actuator phase observation zero-world receipt changed"
            }
            default { throw "QSDK-R23D60: undeclared ordinary Godot gate" }
        }
        $ordinaryReceipts.Add([ordered]@{
            name = [string]$definition.name
            marker = [string]$definition.marker
            receipt_schema_version = [string]$ordinaryReceipt.schema_version
            stdout_sha256 = "sha256:" + [Convert]::ToHexString(
                [Security.Cryptography.SHA256]::HashData(
                    [Text.Encoding]::UTF8.GetBytes([string]$gate.stdout)
                )
            ).ToLowerInvariant()
        })
    }

    $evaluator = Invoke-R23D60Process -FileName $PythonHost -Arguments @(
        $evaluatorPath, "preflight"
    ) -WorkingDirectory $repoRoot -Environment (Get-R23D60PythonEnvironment) `
        -TimeoutSeconds 300
    Assert-R23D60 ($evaluator.exit_code -eq 0 -and -not $evaluator.timed_out) (
        "R23D60 evaluator preflight failed: $($evaluator.stderr) $($evaluator.stdout)"
    )
    $evaluatorReceipt = Get-R23D60MarkerJson $evaluator.stdout (
        "QSDK_R23D60_EVALUATOR_PREFLIGHT "
    )
    Assert-R23D60 (
        [string]$evaluatorReceipt.schema_version -ceq
            "sporespore_qsdk_r23d60_evaluator_preflight_v1" -and
        [string]$evaluatorReceipt.campaign_id -ceq $campaignId -and
        [string]$evaluatorReceipt.gate_id -ceq $gateId -and
        [string]$evaluatorReceipt.question_class -ceq "finite_decision" -and
        [int]$evaluatorReceipt.declared_cell_count -eq 3 -and
        [int]$evaluatorReceipt.valid_trace_canary_count -eq 3 -and
        [int]$evaluatorReceipt.trace_mutation_rejection_count -eq 30 -and
        [int]$evaluatorReceipt.observation_mutation_rejection_count -eq 20 -and
        [int]$evaluatorReceipt.live_fixture_cap_binding_projection_positive_control_count -eq 3 -and
        [int]$evaluatorReceipt.live_fixture_cap_binding_projection_mutation_rejection_count -eq 21 -and
        [int]$evaluatorReceipt.cycle_integrated_positive_control_count -eq 1 -and
        [int]$evaluatorReceipt.turning_decision_mutation_rejection_count -eq 4 -and
        [int]$evaluatorReceipt.complete_matrix_order_mutation_rejection_count -eq 7 -and
        [int]$evaluatorReceipt.observation_row_count_per_trace -eq 2992 -and
        [int]$evaluatorReceipt.observation_application_count_per_trace -eq 23936 -and
        -not [bool]$evaluatorReceipt.superiority_test_invoked -and
        -not [bool]$evaluatorReceipt.equivalence_or_non_inferiority_test_invoked -and
        -not [bool]$evaluatorReceipt.population_inference_attempted -and
        [int]$evaluatorReceipt.model_construction_count -eq 0 -and
        [int]$evaluatorReceipt.world_attempt_count -eq 0 -and
        [int]$evaluatorReceipt.world_build_count -eq 0 -and
        [bool]$evaluatorReceipt.turning_gate_invoked -and
        [double]$evaluatorReceipt.minimum_raw_signed_cycle_shift_rad -eq 0.01 -and
        [double]$evaluatorReceipt.minimum_reference_conditioned_cycle_shift_rad -eq 0.01 -and
        -not [bool]$evaluatorReceipt.physical_execution_authorized -and
        -not [bool]$evaluatorReceipt.physical_acceptance_authority
    ) "evaluator preflight receipt changed"

    $workerReceipts = [Collections.Generic.List[object]]::new()
    foreach ($armId in $armOffsets.Keys) {
        $expectedHeading = [double]$armOffsets[$armId]
        $cellId = "$engineId`__s$campaignSeed`__$profileId`__$armId"
        $arguments = @(
            "--headless", "--path", $repoRoot, "--script", $workerResourcePath,
            "--", "--preflight-only", "--stage", $stageId,
            "--onset", "onset_600", "--seed", [string]$campaignSeed,
            "--profile", $profileId, "--arm", $armId
        )
        $worker = Invoke-R23D60GodotWorkerProcess -Arguments $arguments `
            -TimeoutSeconds 300
        Assert-R23D60 (
            [int]$worker.exit_code -eq 0 -and
            -not [bool]$worker.timed_out -and
            [bool]$worker.termination_protocol_valid -and
            [bool]$worker.supervisor_terminated -and
            [string]$worker.termination_ready_receipt.worker_receipt_kind -ceq "preflight"
        ) "Godot worker preflight termination invalid: $armId"
        $receipt = Get-R23D60MarkerJson $worker.stdout (
            "QSDK_R23D60_GODOT_JOLT_PREFLIGHT "
        )
        Assert-R23D60 (
            [string]$receipt.schema_version -ceq
                "sporespore_qsdk_r23d60_godot_jolt_worker_preflight_v1" -and
            [bool]$receipt.ok -and
            [string]$receipt.campaign_id -ceq $campaignId -and
            [string]$receipt.gate_id -ceq $gateId -and
            [string]$receipt.engine_id -ceq $engineId -and
            [string]$receipt.stage_id -ceq $stageId -and
            [string]$receipt.cell_id -ceq $cellId -and
            [int]$receipt.campaign_seed -eq $campaignSeed -and
            [string]$receipt.profile_id -ceq $profileId -and
            [string]$receipt.arm_id -ceq $armId -and
            [double]$receipt.turn_heading_offset_rad -eq $expectedHeading -and
            [string]$receipt.hip_cap_source -ceq "portable_compiled_morphology" -and
            [string]$receipt.knee_cap_source -ceq "fixture_realized_prebinding" -and
            [string]$receipt.controller_policy_id -ceq
                "sporespore_balanced_wave_r23d29_two_swing_persistent_predictive_stability_guarded_steering_v1" -and
            [string]$receipt.task_frame_origin_policy_id -ceq
                "warmup_preserving_command_onset_origin_reanchor_v1" -and
            [string]$receipt.live_fixture_actuator_cap_binding_policy_id -ceq
                "sporespore_godot_jolt_live_fixture_cap_source_factorial_binding_v1" -and
            [string]$receipt.live_fixture_actuator_cap_binding_profile_id -ceq $profileId -and
            [bool]$receipt.live_fixture_actuator_cap_binding_required -and
            -not [bool]$receipt.live_fixture_actuator_cap_binding_executed -and
            [bool]$receipt.live_fixture_actuator_cap_binding_execution_deferred_until_after_world_build -and
            [string]$receipt.trace_transport_id -ceq
                "godot_4_7_sorted_full_precision_authoritative_json_v1" -and
            [string]$receipt.godot_runtime_version -ceq "4.7-stable (official)" -and
            [bool]$receipt.godot_json_full_precision -and
            [bool]$receipt.compiled_initial_perturbation_matches_declaration -and
            [bool]$receipt.selected_profile_fixed_before_world -and
            [int]$receipt.fixed_controller_horizon_step_count -eq 2992 -and
            -not [bool]$receipt.terminal_restoration_or_taper_invoked -and
            [int]$receipt.model_construction_count -eq 0 -and
            [int]$receipt.world_attempt_count -eq 0 -and
            [int]$receipt.world_build_count -eq 0 -and
            [bool]$receipt.turning_gate_invoked -and
            -not [bool]$receipt.superiority_or_equivalence_evaluator_invoked -and
            -not [bool]$receipt.physical_execution_authorized -and
            -not [bool]$receipt.physical_acceptance_authority
        ) "Godot worker preflight receipt invalid: $armId"
        $workerReceipts.Add($receipt)
    }


    $invalidCellControls = @(
        [ordered]@{
            id = "stage"; stage = $stageId + "_mutated"; onset = "onset_600"
            seed = "21516"; profile = $profileId; arm = "reference_zero"
            extra = @(); failure = "QSDK_R23D60_GJT_CELL_IDENTITY_INVALID"
        },
        [ordered]@{
            id = "onset"; stage = $stageId; onset = "onset_601"
            seed = "21516"; profile = $profileId; arm = "reference_zero"
            extra = @(); failure = "QSDK_R23D60_GJT_CELL_IDENTITY_INVALID"
        },
        [ordered]@{
            id = "seed"; stage = $stageId; onset = "onset_600"
            seed = "21515"; profile = $profileId; arm = "reference_zero"
            extra = @(); failure = "QSDK_R23D60_GJT_CELL_IDENTITY_INVALID"
        },
        [ordered]@{
            id = "profile"; stage = $stageId; onset = "onset_600"
            seed = "21516"; profile = "portable_hip__portable_knee"; arm = "reference_zero"
            extra = @(); failure = "QSDK_R23D60_GJT_CELL_IDENTITY_INVALID"
        },
        [ordered]@{
            id = "arm"; stage = $stageId; onset = "onset_600"
            seed = "21516"; profile = $profileId; arm = "mutated"
            extra = @(); failure = "QSDK_R23D60_GJT_CELL_IDENTITY_INVALID"
        },
        [ordered]@{
            id = "duplicate_arm_argument"; stage = $stageId; onset = "onset_600"
            seed = "21516"; profile = $profileId; arm = "reference_zero"
            extra = @("--arm", "positive_heading")
            failure = "QSDK_R23D60_GJT_ARGUMENT_DUPLICATE_OR_MISSING"
        }
    )
    foreach ($control in $invalidCellControls) {
        $invalidArguments = @(
            "--headless", "--path", $repoRoot, "--script", $workerResourcePath,
            "--", "--preflight-only", "--stage", [string]$control.stage,
            "--onset", [string]$control.onset, "--seed", [string]$control.seed,
            "--profile", [string]$control.profile, "--arm", [string]$control.arm
        ) + @($control.extra)
        $invalid = Invoke-R23D60GodotWorkerProcess `
            -Arguments $invalidArguments -TimeoutSeconds 300
        Assert-R23D60 (
            [int]$invalid.exit_code -eq 1 -and
            -not [bool]$invalid.timed_out -and
            [bool]$invalid.termination_protocol_valid -and
            [bool]$invalid.supervisor_terminated -and
            [string]$invalid.termination_ready_receipt.worker_receipt_kind -ceq "failure"
        ) "invalid-cell termination changed: $($control.id)"
        $invalidFailure = Get-R23D60MarkerJson $invalid.stdout (
            "QSDK_R23D60_GODOT_JOLT_FAILURE "
        )
        Assert-R23D60 (
            [string]$invalidFailure.failure_code -ceq [string]$control.failure -and
            [int]$invalidFailure.world_attempt_count -eq 0 -and
            [int]$invalidFailure.world_build_count -eq 0 -and
            -not [bool]$invalidFailure.physical_acceptance_authority
        ) "invalid cell was not rejected before world: $($control.id)"
    }


    $authorizationArguments = @(
        "--headless", "--path", $repoRoot, "--script", $workerResourcePath,
        "--", "--authorization-preflight-only", "--stage", $stageId,
        "--onset", "onset_600", "--seed", "21516",
        "--profile", $profileId, "--arm", "reference_zero",
        "--source-commit", ("0" * 40)
    )
    $authorization = Invoke-R23D60GodotWorkerProcess `
        -Arguments $authorizationArguments -TimeoutSeconds 300
    Assert-R23D60 (
        [int]$authorization.exit_code -eq 1 -and
        -not [bool]$authorization.timed_out -and
        [bool]$authorization.termination_protocol_valid -and
        [bool]$authorization.supervisor_terminated -and
        [string]$authorization.termination_ready_receipt.worker_receipt_kind -ceq "failure"
    ) "authorization-negative worker termination invalid"
    $authorizationFailure = Get-R23D60MarkerJson $authorization.stdout (
        "QSDK_R23D60_GODOT_JOLT_FAILURE "
    )
    Assert-R23D60 (
        [string]$authorizationFailure.failure_code -ceq
            "QSDK_R23D60_GJT_PHYSICAL_AUTHORIZATION_REQUIRED" -and
        [int]$authorizationFailure.world_attempt_count -eq 0 -and
        [int]$authorizationFailure.world_build_count -eq 0
    ) "missing physical authorization was not rejected before world"

    return [ordered]@{
        schema_version = "sporespore_qsdk_r23d60_complete_zero_world_receipt_v1"
        campaign_id = $campaignId
        gate_id = $gateId
        question_class = "finite_decision"
        dependency_inventory = $inventory
        preregistration_gate_stdout_sha256 = "sha256:" + [Convert]::ToHexString(
            [Security.Cryptography.SHA256]::HashData(
                [Text.Encoding]::UTF8.GetBytes([string]$preregistration.stdout)
            )
        ).ToLowerInvariant()
        dependency_gate_stdout_sha256 = "sha256:" + [Convert]::ToHexString(
            [Security.Cryptography.SHA256]::HashData(
                [Text.Encoding]::UTF8.GetBytes([string]$dependency.stdout)
            )
        ).ToLowerInvariant()
        parent_closure_gate_stdout_sha256 = "sha256:" + [Convert]::ToHexString(
            [Security.Cryptography.SHA256]::HashData(
                [Text.Encoding]::UTF8.GetBytes([string]$parent.stdout)
            )
        ).ToLowerInvariant()
        terminal_projection_gate_stdout_sha256 = "sha256:" + [Convert]::ToHexString(
            [Security.Cryptography.SHA256]::HashData(
                [Text.Encoding]::UTF8.GetBytes([string]$terminalProjection.stdout)
            )
        ).ToLowerInvariant()
        cap_source_gate_stdout_sha256 = "sha256:" + [Convert]::ToHexString(
            [Security.Cryptography.SHA256]::HashData(
                [Text.Encoding]::UTF8.GetBytes([string]$capSource.stdout)
            )
        ).ToLowerInvariant()
        ordinary_godot_gate_receipts = @($ordinaryReceipts)
        evaluator = $evaluatorReceipt
        ordered_worker_receipts = @($workerReceipts)
        worker_preflight_count = $workerReceipts.Count
        invalid_cell_negative_control_count = $invalidCellControls.Count
        authorization_negative_control_count = 1
        declared_cell_count = 3
        declared_world_count = 3
        complete_dependency_inventory_proved = $true
        immutable_parent_closure_replayed = $true
        all_worker_cells_preflighted = $true
        turning_gate_invoked = $true
        superiority_or_equivalence_evaluator_invoked = $false
        model_construction_count = 0
        world_attempt_count = 0
        world_build_count = 0
        physical_execution_authorized = $false
        physical_acceptance_authority = $false
    }
}

function Assert-R23D60FrozenBindings($Freeze) {
    foreach ($binding in @($Freeze.source_bindings)) {
        $relative = [string]$binding.path
        $path = Join-Path $repoRoot $relative
        Assert-R23D60 (
            (Test-Path -LiteralPath $path -PathType Leaf) -and
            [string]$binding.raw_sha256 -ceq (Get-R23D60Sha256 $path) -and
            [string]$binding.git_blob_oid -ceq
                (Invoke-R23D60Git @("rev-parse", "HEAD:$relative")) -and
            [string]$binding.git_blob_oid -ceq
                (Invoke-R23D60Git @("hash-object", "--no-filters", "--", $relative))
        ) "frozen source binding changed: $relative"
    }
    foreach ($runtime in @($Freeze.runtime_artifacts) + @($Freeze.external_runtime_bindings)) {
        $path = [IO.Path]::GetFullPath([string]$runtime.path)
        Assert-R23D60 (
            (Test-Path -LiteralPath $path -PathType Leaf) -and
            [string]$runtime.raw_sha256 -ceq (Get-R23D60Sha256 $path)
        ) "frozen runtime changed: $path"
    }
}

function Publish-R23D60Inputs(
    $SourceBindings,
    $RuntimeArtifacts,
    $ExternalRuntimeBindings,
    [string]$AdoptionPath
) {
    $source = @(
        foreach ($binding in @($SourceBindings)) {
            Publish-SporeSporeContentAddressedArtifact -RepoRoot $repoRoot `
                -ArtifactPath (Join-Path $repoRoot ([string]$binding.path)) `
                -MediaType (Get-R23D60MediaType ([string]$binding.path))
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

function Get-R23D60TerminalFailure(
    [string]$ArmId,
    [string]$SourceCommit,
    [string]$Code,
    [int]$WorldAttemptCount = 0,
    [int]$WorldBuildCount = 0,
    [bool]$WorldBuildCountExact = $true,
    [int]$WorldBuildCountUpperBound = $WorldBuildCount
) {
    return [ordered]@{
        schema_version = "sporespore_qsdk_r23d60_supervisor_failure_v1"
        campaign_id = $campaignId
        gate_id = $gateId
        stage_id = $stageId
        cell_id = "$engineId`__s$campaignSeed`__$profileId`__$ArmId"
        engine_id = $engineId
        campaign_seed = $campaignSeed
        profile_id = $profileId
        hip_cap_source = "portable_compiled_morphology"
        knee_cap_source = "fixture_realized_prebinding"
        onset_id = "onset_600"
        turn_start_semantic_step = 600
        arm_id = $ArmId
        turn_heading_offset_rad = [double]$armOffsets[$ArmId]
        source_commit = $SourceCommit
        failure_stage = "supervisor_transport"
        failure_code = $Code
        world_attempt_count = $WorldAttemptCount
        world_build_count = $WorldBuildCount
        world_build_count_exact = $WorldBuildCountExact
        world_build_count_lower_bound = $WorldBuildCount
        world_build_count_upper_bound = $WorldBuildCountUpperBound
        claims = [ordered]@{
            r23d60_held_out_turning_positive = $false
            godot_jolt_turning = $false
            finite_three_engine_turning = $false
            portable_basic_turning = $false
            cross_engine_equivalence = $false
            population_robustness = $false
            prone_to_standing = $false
            release_authority = $false
            physical_acceptance_authority = $false
        }
    }
}

function Invoke-R23D60Cell {
    param(
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
    [void][IO.Directory]::CreateDirectory($CellRoot)
    $cellId = "$engineId`__s$campaignSeed`__$profileId`__$ArmId"
    $environment = @{
        "SPORESPORE_QSDK_R23D60_FREEZE" = $FreezePayload
        "SPORESPORE_QSDK_R23D60_ATTEMPT" = $AttemptPayload
        "SPORESPORE_QSDK_R23D60_TOKEN" = $Token
        "SPORESPORE_QSDK_R23D60_STAGE" = $stageId
        "SPORESPORE_QSDK_R23D60_CELL" = $cellId
        "SPORESPORE_QSDK_R23D60_ENGINE" = $engineId
        "SPORESPORE_QSDK_R23D60_ATTEMPT_ROOT" = $AttemptRoot
        "SPORESPORE_QSDK_R23D60_PYTHON" = $PythonHost
        "SPORESPORE_QSDK_R23D60_POWERSHELL" = $PowerShellHost
    }
    $arguments = @(
        "--headless", "--path", $repoRoot, "--script", $workerResourcePath, "--",
        "--stage", $stageId, "--onset", "onset_600",
        "--seed", [string]$campaignSeed, "--profile", $profileId,
        "--arm", $ArmId, "--source-commit", $SourceCommit
    )
    $process = Invoke-R23D60GodotWorkerProcess -Arguments $arguments `
        -Environment $environment -TimeoutSeconds $CellTimeoutSeconds
    $stdoutPath = Join-Path $CellRoot "stdout.txt"
    $stderrPath = Join-Path $CellRoot "stderr.txt"
    [IO.File]::WriteAllText(
        $stdoutPath, [string]$process.stdout, [Text.UTF8Encoding]::new($false)
    )
    [IO.File]::WriteAllText(
        $stderrPath, [string]$process.stderr, [Text.UTF8Encoding]::new($false)
    )
    $stdoutCas = Publish-SporeSporeContentAddressedArtifact -RepoRoot $repoRoot `
        -ArtifactPath $stdoutPath -MediaType "text/plain"
    $stderrCas = Publish-SporeSporeContentAddressedArtifact -RepoRoot $repoRoot `
        -ArtifactPath $stderrPath -MediaType "text/plain"
    try {
        if ([bool]$process.timed_out) { throw "R23D60_CELL_TIMEOUT" }
        if (-not [bool]$process.termination_protocol_valid) {
            throw "R23D60_GODOT_TERMINATION_PROTOCOL_INVALID"
        }
        if (-not [bool]$process.supervisor_terminated) {
            throw "R23D60_GODOT_SUPERVISOR_TERMINATION_MISSING"
        }
        if ([string]$process.termination_ready_receipt.worker_receipt_kind -cne "terminal") {
            throw "R23D60_GODOT_TERMINATION_RECEIPT_KIND_INVALID"
        }
        $terminal = Get-R23D60MarkerJson $process.stdout (
            "QSDK_R23D60_GODOT_JOLT_TERMINAL "
        )
        if ([string]$terminal.cell_id -cne $cellId) { throw "R23D60_CELL_MARKER_ID" }
        if ([int]$terminal.campaign_seed -ne $campaignSeed) { throw "R23D60_CELL_SEED" }
        if ([string]$terminal.profile_id -cne $profileId) { throw "R23D60_CELL_PROFILE" }
        if ([string]$terminal.arm_id -cne $ArmId) { throw "R23D60_CELL_ARM" }
        if ([double]$terminal.turn_heading_offset_rad -ne [double]$armOffsets[$ArmId]) {
            throw "R23D60_CELL_HEADING_OFFSET"
        }
        $terminalProjection = Get-SporeSporeTerminalExecutionProjection `
            -Terminal $terminal -SuccessSchemas $terminalSuccessSchemas `
            -FailureSchemas $terminalFailureSchemas
    } catch {
        $terminal = Get-R23D60TerminalFailure -ArmId $ArmId `
            -SourceCommit $SourceCommit `
            -Code ("R23D60_SUPERVISOR_TERMINAL_CAPTURE:" + $_.Exception.Message) `
            -WorldAttemptCount 1 -WorldBuildCount 0 `
            -WorldBuildCountExact $false -WorldBuildCountUpperBound 1
        $terminalProjection = Get-SporeSporeTerminalExecutionProjection `
            -Terminal $terminal -SuccessSchemas $terminalSuccessSchemas `
            -FailureSchemas $terminalFailureSchemas
    }
    $terminalPath = Join-Path $CellRoot "terminal.json"
    Write-R23D60NewJson $terminalPath $terminal
    $terminalCas = Publish-SporeSporeContentAddressedArtifact -RepoRoot $repoRoot `
        -ArtifactPath $terminalPath -MediaType "application/json"
    return [ordered]@{
        cell_id = $cellId
        engine_id = $engineId
        campaign_seed = $campaignSeed
        profile_id = $profileId
        arm_id = $ArmId
        turn_heading_offset_rad = [double]$armOffsets[$ArmId]
        process = [ordered]@{
            exit_code = [int]$process.exit_code
            host_exit_code = [int]$process.host_exit_code
            timed_out = [bool]$process.timed_out
            supervisor_terminated = [bool]$process.supervisor_terminated
            termination_protocol_valid = [bool]$process.termination_protocol_valid
            termination_protocol_failure_code = [string]$process.termination_protocol_failure_code
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
        world_build_count_lower_bound = [int]$terminalProjection.world_build_count_lower_bound
        world_build_count_upper_bound = [int]$terminalProjection.world_build_count_upper_bound
        physical_acceptance_authority = $false
    }
}
Assert-R23D60 ($PreflightOnly -xor $RunPhysical) (
    "select exactly one of -PreflightOnly or -RunPhysical"
)
Assert-R23D60 (Test-Path -LiteralPath $Godot -PathType Leaf) "Godot executable is missing"
$pythonHost = Resolve-R23D60Application $Python
$powerShellHost = Resolve-R23D60Application $PowerShell

if ($PreflightOnly) {
    Assert-R23D60 ([string]::IsNullOrWhiteSpace($CampaignAttestationAdoption)) (
        "preflight does not accept physical authorization"
    )
    Assert-R23D60 ([string]::IsNullOrWhiteSpace($OutputRoot)) (
        "preflight does not accept a physical output root"
    )
    $receipt = Invoke-R23D60ZeroWorld $pythonHost $powerShellHost
    Write-Host (
        "QSDK_R23D60_ZERO_WORLD_PASS " +
        ($receipt | ConvertTo-Json -Depth 100 -Compress)
    )
    exit 0
}

Assert-R23D60 (-not [string]::IsNullOrWhiteSpace($CampaignAttestationAdoption)) (
    "physical execution requires a campaign-attestation adoption"
)
foreach ($path in @($preregistrationPath, $implementationPath, $campaignManifestPath)) {
    Assert-R23D60 (Test-Path -LiteralPath $path -PathType Leaf) "missing contract: $path"
}
$source = Get-SporeSporeAttestationSourceIdentity -RepoRoot $repoRoot `
    -RequireCleanPushedLive
$adoption = Test-SporeSporeCampaignAttestationAdoptionFile -RepoRoot $repoRoot `
    -ManifestPath $campaignManifestPath `
    -AdoptionPath ([IO.Path]::GetFullPath($CampaignAttestationAdoption)) `
    -Godot $Godot -Python $pythonHost -ExpectedCampaignId $campaignId
Assert-R23D60 ([bool]$adoption.ok) (
    "campaign-attestation adoption failed: $(@($adoption.failure_codes) -join ',')"
)
Assert-R23D60 (
    [string]$adoption.source.commit -ceq [string]$source.commit -and
    [string]$adoption.source.tree_git_oid -ceq [string]$source.tree_git_oid
) "adoption source differs from the live source"

$lock = Enter-SporeSporeLocomotionOperationLock -Role physical
Assert-R23D60 ([bool]$lock.acquired) "global locomotion operation lock is held"
$attemptConsumed = $false
$completionPath = ""
try {
    $evidenceRoot = Get-SporeSporeArtifactEvidenceRoot -RepoRoot $repoRoot
    $prior = @(Get-ChildItem -LiteralPath $evidenceRoot -Directory | Where-Object {
        $_.Name -like "qsdk-r23d60-*" -and (
            (Test-Path -LiteralPath (Join-Path $_.FullName "attempt-authorization.json")) -or
            (Test-Path -LiteralPath (Join-Path $_.FullName "completion.json"))
        )
    })
    Assert-R23D60 ($prior.Count -eq 0) "one-shot R23D60 identity already exists"
    $resolvedOutput = if ([string]::IsNullOrWhiteSpace($OutputRoot)) {
        Join-Path $evidenceRoot (
            "qsdk-r23d60-" + [DateTime]::UtcNow.ToString("yyyyMMddTHHmmssZ")
        )
    } else { [IO.Path]::GetFullPath($OutputRoot) }
    $prefix = $evidenceRoot.TrimEnd("\", "/") + [IO.Path]::DirectorySeparatorChar
    Assert-R23D60 (
        $resolvedOutput.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase) -and
        -not (Test-Path -LiteralPath $resolvedOutput)
    ) "output must be a new directory under $evidenceRoot"
    [void][IO.Directory]::CreateDirectory($resolvedOutput)
    $completionPath = Join-Path $resolvedOutput "completion.json"

    $godotBuild = Invoke-SporeSporeR23D3PinnedCargo -RepoRoot $repoRoot `
        -SourceCommit ([string]$source.commit) -TargetRoot (Join-Path $sdkRoot "target") `
        -CargoArguments @(
            "build", "--quiet", "--locked", "--offline",
            "--manifest-path", (Join-Path $sdkRoot "Cargo.toml"),
            "--package", "sporespore-godot-adapter"
        )
    Assert-R23D60 (Test-Path -LiteralPath $godotAdapterPath -PathType Leaf) (
        "reproducible Godot adapter is missing"
    )
    $zeroWorld = Invoke-R23D60ZeroWorld $pythonHost $powerShellHost
    $inventory = Get-R23D60DependencyInventory $pythonHost $true
    $sourceAfter = Get-SporeSporeAttestationSourceIdentity -RepoRoot $repoRoot `
        -RequireCleanPushedLive
    Assert-R23D60 (
        [string]$sourceAfter.commit -ceq [string]$source.commit -and
        [string]$sourceAfter.tree_git_oid -ceq [string]$source.tree_git_oid
    ) "source changed during runtime materialization or zero-world gate"

    $sourceBindings = @($inventory.source_receipts)
    $runtimeArtifacts = @(
        [ordered]@{
            name = "godot_adapter_debug"
            path = $godotAdapterPath
            raw_sha256 = Get-R23D60Sha256 $godotAdapterPath
            media_type = "application/vnd.microsoft.portable-executable"
            build_receipt = $godotBuild
        }
    )
    $externalRuntimeBindings = @(
        [ordered]@{
            name = "godot_jolt_host"
            path = $Godot
            raw_sha256 = Get-R23D60Sha256 $Godot
            media_type = "application/vnd.microsoft.portable-executable"
        },
        [ordered]@{
            name = "evaluator_python_host"
            path = $pythonHost
            raw_sha256 = Get-R23D60Sha256 $pythonHost
            media_type = "application/vnd.microsoft.portable-executable"
        },
        [ordered]@{
            name = "powershell_trace_host"
            path = $powerShellHost
            raw_sha256 = Get-R23D60Sha256 $powerShellHost
            media_type = "application/vnd.microsoft.portable-executable"
        }
    )
    $inputCas = Publish-R23D60Inputs $sourceBindings $runtimeArtifacts `
        $externalRuntimeBindings ([IO.Path]::GetFullPath($CampaignAttestationAdoption))
    $freeze = [ordered]@{
        schema_version = "sporespore_qsdk_r23d60_physical_freeze_v1"
        status = "frozen_supervisor_only_physical_authorized"
        campaign_id = $campaignId
        gate_id = $gateId
        question_class = "finite_decision"
        preregistration_raw_sha256 = Get-R23D60Sha256 $preregistrationPath
        implementation_contract_raw_sha256 = Get-R23D60Sha256 $implementationPath
        source_commit = [string]$source.commit
        source_tree_git_oid = [string]$source.tree_git_oid
        origin_main_commit = [string]$source.origin_main
        live_github_main_commit = [string]$source.live_github_main
        dependency_inventory_complete = $true
        dependency_inventory = $inventory
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
    Write-R23D60NewJson $freezePath $freeze
    $freezeCas = Publish-SporeSporeContentAddressedArtifact -RepoRoot $repoRoot `
        -ArtifactPath $freezePath -MediaType "application/json"
    Assert-R23D60FrozenBindings $freeze

    $attemptId = [Guid]::NewGuid().ToString("N")
    $token = [Guid]::NewGuid().ToString("N")
    $attempt = [ordered]@{
        schema_version = "sporespore_qsdk_r23d60_attempt_v1"
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
    Write-R23D60NewJson $attemptPath $attempt
    $attemptCas = Publish-SporeSporeContentAddressedArtifact -RepoRoot $repoRoot `
        -ArtifactPath $attemptPath -MediaType "application/json"
    $attemptConsumed = $true

    $authorizationPreflights = [Collections.Generic.List[object]]::new()
    foreach ($armId in $armOffsets.Keys) {
        Assert-R23D60FrozenBindings $freeze
        $cellId = "$engineId`__s$campaignSeed`__$profileId`__$armId"
        $environment = @{
            "SPORESPORE_QSDK_R23D60_FREEZE" = [string]$freezeCas.payload_path
            "SPORESPORE_QSDK_R23D60_ATTEMPT" = [string]$attemptCas.payload_path
            "SPORESPORE_QSDK_R23D60_TOKEN" = $token
            "SPORESPORE_QSDK_R23D60_STAGE" = $stageId
            "SPORESPORE_QSDK_R23D60_CELL" = $cellId
            "SPORESPORE_QSDK_R23D60_ENGINE" = $engineId
            "SPORESPORE_QSDK_R23D60_ATTEMPT_ROOT" = $resolvedOutput
            "SPORESPORE_QSDK_R23D60_PYTHON" = $pythonHost
            "SPORESPORE_QSDK_R23D60_POWERSHELL" = $powerShellHost
        }
        $authorizationProcess = Invoke-R23D60GodotWorkerProcess -Arguments @(
            "--headless", "--path", $repoRoot, "--script", $workerResourcePath,
            "--", "--authorization-preflight-only", "--stage", $stageId,
            "--onset", "onset_600", "--seed", [string]$campaignSeed,
            "--profile", $profileId, "--arm", $armId,
            "--source-commit", [string]$source.commit
        ) -Environment $environment -TimeoutSeconds 300
        $authorizationRoot = Join-Path $resolvedOutput (
            "authorization-preflight\$cellId"
        )
        [void][IO.Directory]::CreateDirectory($authorizationRoot)
        $authorizationStdoutPath = Join-Path $authorizationRoot "stdout.txt"
        $authorizationStderrPath = Join-Path $authorizationRoot "stderr.txt"
        [IO.File]::WriteAllText(
            $authorizationStdoutPath,
            [string]$authorizationProcess.stdout,
            [Text.UTF8Encoding]::new($false)
        )
        [IO.File]::WriteAllText(
            $authorizationStderrPath,
            [string]$authorizationProcess.stderr,
            [Text.UTF8Encoding]::new($false)
        )
        $authorizationStdoutCas = Publish-SporeSporeContentAddressedArtifact `
            -RepoRoot $repoRoot -ArtifactPath $authorizationStdoutPath `
            -MediaType "text/plain"
        $authorizationStderrCas = Publish-SporeSporeContentAddressedArtifact `
            -RepoRoot $repoRoot -ArtifactPath $authorizationStderrPath `
            -MediaType "text/plain"
        Assert-R23D60 (
            [int]$authorizationProcess.exit_code -eq 0 -and
            -not [bool]$authorizationProcess.timed_out -and
            [bool]$authorizationProcess.termination_protocol_valid -and
            [bool]$authorizationProcess.supervisor_terminated -and
            [string]$authorizationProcess.termination_ready_receipt.worker_receipt_kind -ceq
                "authorization_preflight"
        ) "strict physical authorization preflight termination invalid: $cellId"
        $authorizationReceipt = Get-R23D60MarkerJson `            $authorizationProcess.stdout (
                "QSDK_R23D60_GODOT_JOLT_AUTHORIZATION_PREFLIGHT "
            )
        Assert-R23D60 (
            [string]$authorizationReceipt.schema_version -ceq
                "sporespore_qsdk_r23d60_godot_jolt_production_authorization_preflight_v1" -and
            [string]$authorizationReceipt.campaign_id -ceq $campaignId -and
            [string]$authorizationReceipt.gate_id -ceq $gateId -and
            [string]$authorizationReceipt.engine_id -ceq $engineId -and
            [string]$authorizationReceipt.stage_id -ceq $stageId -and
            [string]$authorizationReceipt.cell_id -ceq $cellId -and
            [int]$authorizationReceipt.campaign_seed -eq $campaignSeed -and
            [string]$authorizationReceipt.profile_id -ceq $profileId -and
            [string]$authorizationReceipt.arm_id -ceq $armId -and
            [double]$authorizationReceipt.turn_heading_offset_rad -eq
                [double]$armOffsets[$armId] -and
            [bool]$authorizationReceipt.authorization_passed -and
            [bool]$authorizationReceipt.returned_before_model -and
            [int]$authorizationReceipt.model_construction_count -eq 0 -and
            [int]$authorizationReceipt.world_attempt_count -eq 0 -and
            [int]$authorizationReceipt.world_build_count -eq 0 -and
            -not [bool]$authorizationReceipt.physical_acceptance_authority
        ) "strict physical authorization preflight receipt invalid: $cellId"
        $authorizationPreflights.Add([ordered]@{
            cell_id = $cellId
            worker_receipt = $authorizationReceipt
            process = [ordered]@{
                exit_code = [int]$authorizationProcess.exit_code
                host_exit_code = [int]$authorizationProcess.host_exit_code
                timed_out = [bool]$authorizationProcess.timed_out
                supervisor_terminated = [bool]$authorizationProcess.supervisor_terminated
                termination_protocol_valid = [bool]$authorizationProcess.termination_protocol_valid
                termination_ready_receipt = $authorizationProcess.termination_ready_receipt
                started_utc = [string]$authorizationProcess.started_utc
                completed_utc = [string]$authorizationProcess.completed_utc
                stdout_cas = $authorizationStdoutCas
                stderr_cas = $authorizationStderrCas
            }
            physical_acceptance_authority = $false
        })
    }
    Assert-R23D60 ($authorizationPreflights.Count -eq 3) (
        "strict physical authorization preflight matrix incomplete"
    )


    $authorizationPreflightPath = Join-Path $resolvedOutput (
        "authorization-preflight.json"
    )
    Write-R23D60NewJson $authorizationPreflightPath ([ordered]@{
        schema_version = "sporespore_qsdk_r23d60_authorization_preflight_matrix_v1"
        campaign_id = $campaignId
        gate_id = $gateId
        source_commit = [string]$source.commit
        ordered_receipts = @($authorizationPreflights)
        receipt_count = $authorizationPreflights.Count
        model_construction_count = 0
        world_attempt_count = 0
        world_build_count = 0
        physical_acceptance_authority = $false
    })
    $authorizationPreflightCas = Publish-SporeSporeContentAddressedArtifact `
        -RepoRoot $repoRoot -ArtifactPath $authorizationPreflightPath `
        -MediaType "application/json"

    $cells = [Collections.Generic.List[object]]::new()
    foreach ($armId in $armOffsets.Keys) {
        Assert-R23D60FrozenBindings $freeze
        $sourceBeforeCell = Get-SporeSporeAttestationSourceIdentity `
            -RepoRoot $repoRoot -RequireCleanPushedLive
        Assert-R23D60 (
            [string]$sourceBeforeCell.commit -ceq [string]$source.commit -and
            [string]$sourceBeforeCell.tree_git_oid -ceq [string]$source.tree_git_oid
        ) "source changed before cell $armId"
        $cellRoot = Join-Path $resolvedOutput (
            "cells\$engineId`__s$campaignSeed`__$profileId`__$armId"
        )
        $cells.Add((Invoke-R23D60Cell -ArmId $armId `
            -SourceCommit ([string]$source.commit) `
            -FreezePayload ([string]$freezeCas.payload_path) `
            -AttemptPayload ([string]$attemptCas.payload_path) -Token $token `
            -AttemptRoot $resolvedOutput -CellRoot $cellRoot `
            -PythonHost $pythonHost -PowerShellHost $powerShellHost))
    }

    Assert-R23D60FrozenBindings $freeze
    $sourceAfterCells = Get-SporeSporeAttestationSourceIdentity `
        -RepoRoot $repoRoot -RequireCleanPushedLive
    Assert-R23D60 (
        [string]$sourceAfterCells.commit -ceq [string]$source.commit -and
        [string]$sourceAfterCells.tree_git_oid -ceq [string]$source.tree_git_oid
    ) "source changed during the serialized physical matrix"
    $terminalPaths = @($cells | ForEach-Object {
        [string]$_.terminal_entry_cas.payload_path
    })
    $terminalManifestPath = Join-Path $resolvedOutput "terminal-paths.json"
    Write-R23D60NewJson $terminalManifestPath $terminalPaths
    $terminalManifestCas = Publish-SporeSporeContentAddressedArtifact `
        -RepoRoot $repoRoot -ArtifactPath $terminalManifestPath `
        -MediaType "application/json"
    $evaluationProcess = Invoke-R23D60Process -FileName $pythonHost -Arguments @(
        $evaluatorPath, "evaluate-complete", "--manifest",
        [string]$terminalManifestCas.payload_path, "--expected-source-commit",
        [string]$source.commit, "--repo-root", $repoRoot
    ) -WorkingDirectory $repoRoot -Environment (Get-R23D60PythonEnvironment) `
        -TimeoutSeconds 600
    Assert-R23D60 ($evaluationProcess.exit_code -eq 0 -and -not $evaluationProcess.timed_out) (
        "complete evaluator failed: $($evaluationProcess.stderr) $($evaluationProcess.stdout)"
    )
    $evaluation = Get-R23D60MarkerJson $evaluationProcess.stdout (
        "QSDK_R23D60_COMPLETE_EVALUATION "
    )
    $evaluationPath = Join-Path $resolvedOutput "complete-evaluation.json"
    Write-R23D60NewJson $evaluationPath $evaluation
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
        schema_version = "sporespore_qsdk_r23d60_campaign_report_v1"
        campaign_id = $campaignId
        gate_id = $gateId
        question_class = "finite_decision"
        source = $source
        attempt_id = $attemptId
        freeze_cas = $freezeCas
        attempt_authorization_cas = $attemptCas
        authorization_preflight_cas = $authorizationPreflightCas
        authorization_preflight_count = $authorizationPreflights.Count
        terminal_manifest_cas = $terminalManifestCas
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
    Write-R23D60NewJson $reportPath $report
    $reportCas = Publish-SporeSporeContentAddressedArtifact -RepoRoot $repoRoot `
        -ArtifactPath $reportPath -MediaType "application/json"
    $completion = [ordered]@{
        schema_version = "sporespore_qsdk_r23d60_completion_v1"
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
        selected_profile_id = [string]$evaluation.selected_profile_id
        held_out_turning_positive = [bool]$evaluation.finite_decision.held_out_turning_positive
        report_cas = $reportCas
        complete_evaluation_cas = $evaluationCas
        authorization_preflight_cas = $authorizationPreflightCas
        authorization_preflight_count = $authorizationPreflights.Count
        one_shot_attempt_consumed = $true
        replacement_or_selective_rerun_permitted = $false
        completed_utc = [DateTime]::UtcNow.ToString("o")
        physical_acceptance_authority = $false
    }
    Write-R23D60NewJson $completionPath $completion
    $completionCas = Publish-SporeSporeContentAddressedArtifact -RepoRoot $repoRoot `
        -ArtifactPath $completionPath -MediaType "application/json"
    Write-Host (
        "QSDK_R23D60_PHYSICAL_COMPLETE classification=$($evaluation.classification) " +
        "turning=$($evaluation.finite_decision.held_out_turning_positive) " +
        "cells=$($cells.Count) report_sha256=$($reportCas.sha256) " +
        "completion_sha256=$($completionCas.sha256) output=$resolvedOutput"
    )
    if (([string]$evaluation.classification).StartsWith(
        "invalid_", [StringComparison]::Ordinal
    )) {
        throw "QSDK-R23D60 retained an invalid complete first attempt: $resolvedOutput"
    }
} catch {
    if ($attemptConsumed -and -not [string]::IsNullOrWhiteSpace($completionPath) -and
        -not (Test-Path -LiteralPath $completionPath)) {
        $emergency = [ordered]@{
            schema_version = "sporespore_qsdk_r23d60_completion_v1"
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
        Write-R23D60NewJson $completionPath $emergency
        [void](Publish-SporeSporeContentAddressedArtifact -RepoRoot $repoRoot `
            -ArtifactPath $completionPath -MediaType "application/json")
    }
    throw
} finally {
    Exit-SporeSporeLocomotionOperationLock $lock
}
