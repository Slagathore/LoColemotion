#requires -Version 7.0

[CmdletBinding()]
param(
    [string]$Python = "python",
    [string]$Godot = (
        "C:\Users\Cole\CodeStuff\Misc\Godot\" +
        "Godot_v4.7-stable_mono_win64_console.exe"
    ),
    [string]$PowerShell = "pwsh"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

function Assert-R23D65Runtime([bool]$Condition, [string]$Message) {
    if (-not $Condition) {
        throw "QSDK-R23D65 runtime-integration conformance failed: $Message"
    }
}

function Resolve-R23D65RuntimeApplication([string]$Command) {
    if ([IO.Path]::IsPathFullyQualified($Command)) {
        $resolved = [IO.Path]::GetFullPath($Command)
        Assert-R23D65Runtime (Test-Path -LiteralPath $resolved -PathType Leaf) (
            "application missing: $resolved"
        )
        return $resolved
    }
    return [IO.Path]::GetFullPath([string](
        Get-Command $Command -CommandType Application -ErrorAction Stop |
            Select-Object -First 1 -ExpandProperty Source
    ))
}

function Invoke-R23D65RuntimeProcess(
    [string]$FileName,
    [string[]]$Arguments,
    [string]$WorkingDirectory,
    [int]$TimeoutSeconds = 300
) {
    $start = [Diagnostics.ProcessStartInfo]::new()
    $start.FileName = $FileName
    $start.WorkingDirectory = $WorkingDirectory
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    foreach ($argument in $Arguments) {
        [void]$start.ArgumentList.Add($argument)
    }
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $start
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
    $result = [ordered]@{
        exit_code = if ($timedOut) { 124 } else { $process.ExitCode }
        timed_out = $timedOut
        stdout = $stdoutTask.GetAwaiter().GetResult()
        stderr = $stderrTask.GetAwaiter().GetResult()
    }
    $process.Dispose()
    return $result
}

function Assert-R23D65RuntimeSuccess($Result, [string]$Name) {
    Assert-R23D65Runtime (
        [int]$Result.exit_code -eq 0 -and -not [bool]$Result.timed_out
    ) "$Name failed: $($Result.stderr) $($Result.stdout)"
}

function Get-R23D65RuntimeMarkerJson(
    [string]$Text,
    [string]$Prefix,
    [string]$Name
) {
    $lines = @($Text -split "`r?`n" | Where-Object {
        ([string]$_).StartsWith($Prefix, [StringComparison]::Ordinal)
    })
    Assert-R23D65Runtime ($lines.Count -eq 1) (
        "$Name expected one marker, observed $($lines.Count)"
    )
    return $lines[0].Substring($Prefix.Length) |
        ConvertFrom-Json -AsHashtable -Depth 100
}

function Get-R23D65RuntimeSha256([string]$Text) {
    return "sha256:" + [Convert]::ToHexString(
        [Security.Cryptography.SHA256]::HashData(
            [Text.Encoding]::UTF8.GetBytes($Text)
        )
    ).ToLowerInvariant()
}

$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$expectedRoot = [IO.Path]::GetFullPath(
    "C:\Users\Cole\CodeStuff\games\SporeSpore"
)
$expectedRemote = "https://github.com/Slagathore/sporespore.git"
$campaignId = (
    "QSDK-R23D65-RUNTIME-INTEGRATION-REPAIRED-SELECTED-PROFILE-" +
    "MATCHED-THREE-ENGINE-TURNING-VALIDATION"
)
$stageId = (
    "runtime_integration_repaired_selected_profile_matched_three_engine_" +
    "turning_validation"
)
$profileId = "sporespore_qsdk_r23d60_selected_s169_actuator_cap_profile_v1"
$pythonHost = Resolve-R23D65RuntimeApplication $Python
$godotHost = Resolve-R23D65RuntimeApplication $Godot
$powerShellHost = Resolve-R23D65RuntimeApplication $PowerShell
$cargoHost = Resolve-R23D65RuntimeApplication "cargo"

Assert-R23D65Runtime ($repoRoot -ceq $expectedRoot) "repository root changed"
Assert-R23D65Runtime (
    [IO.Path]::GetFullPath(
        (& git -C $repoRoot rev-parse --show-toplevel).Trim()
    ) -ceq $expectedRoot
) "Git top-level changed"
Assert-R23D65Runtime (
    (& git -C $repoRoot remote get-url origin).Trim() -ceq $expectedRemote
) "origin remote changed"

$rapierManifest = Join-Path $repoRoot "sdk\adapters\rapier\Cargo.toml"
$registration = Invoke-R23D65RuntimeProcess -FileName $cargoHost `
    -Arguments @(
        "test", "--manifest-path", $rapierManifest,
        "r23d65_namespaced_campaign_registration_is_exact_and_zero_world"
    ) -WorkingDirectory $repoRoot -TimeoutSeconds 600
Assert-R23D65RuntimeSuccess $registration "Rapier campaign registration"
Assert-R23D65Runtime (
    ($registration.stdout + $registration.stderr).Contains("1 passed")
) "Rapier campaign registration test did not execute exactly one match"

$godotRoute = Invoke-R23D65RuntimeProcess -FileName $godotHost `
    -Arguments @(
        "--headless", "--path", $repoRoot,
        "--script",
        "res://tests/test_sdk_qsdk_r23d65_godot_public_profile_physical_route_zero_world.gd"
    ) -WorkingDirectory $repoRoot
Assert-R23D65RuntimeSuccess $godotRoute "Godot preworld exact hinge route"
$godotRouteReceipt = Get-R23D65RuntimeMarkerJson $godotRoute.stdout (
    "QSDK_R23D65_GODOT_PUBLIC_PROFILE_PHYSICAL_ROUTE_ZERO_WORLD "
) "Godot preworld exact hinge route"
Assert-R23D65Runtime (
    [bool]$godotRouteReceipt.ok -and
    [int]$godotRouteReceipt.host_object_creation_count -eq 8 -and
    [int]$godotRouteReceipt.validated_actuator_count -eq 8 -and
    [int]$godotRouteReceipt.scene_tree_insertion_count -eq 0 -and
    [int]$godotRouteReceipt.model_construction_count -eq 0 -and
    [int]$godotRouteReceipt.world_attempt_count -eq 0 -and
    [int]$godotRouteReceipt.world_build_count -eq 0 -and
    [int]$godotRouteReceipt.solver_step_count -eq 0 -and
    [bool]$godotRouteReceipt.preworld_binding_preparation.binding_completed_before_scene_tree_insertion -and
    [bool]$godotRouteReceipt.preworld_binding_preparation.exact_surface_ready_for_world_builder_handoff -and
    [bool]$godotRouteReceipt.preworld_binding_preparation.world_builder_handoff_validation_is_shared_production_code
) "Godot exact carried hinge receipt changed"

$casCanaryPath = Join-Path $repoRoot (
    "sdk\turning\r23d65_runtime_integration_conformance.py"
)
$cas = Invoke-R23D65RuntimeProcess -FileName $pythonHost `
    -Arguments @($casCanaryPath, "--powershell", $powerShellHost) `
    -WorkingDirectory $repoRoot -TimeoutSeconds 600
Assert-R23D65RuntimeSuccess $cas "Rapier evaluator to CAS chain"
$casReceipt = Get-R23D65RuntimeMarkerJson $cas.stdout (
    "QSDK_R23D65_RAPIER_CAS_INTEGRATION_PASS "
) "Rapier evaluator to CAS chain"
Assert-R23D65Runtime (
    [int]$casReceipt.declared_chain_count -eq 1 -and
    [int]$casReceipt.conforming_chain_count -eq 1 -and
    [bool]$casReceipt.execution_policy_bypass_in_exact_child_vector -and
    [bool]$casReceipt.production_retainer_invoked -and
    [bool]$casReceipt.production_publisher_invoked -and
    [bool]$casReceipt.content_addressed_store_invoked -and
    [int]$casReceipt.canonical_trace_row_count -eq 2992 -and
    [bool]$casReceipt.test_only_artifact -and
    [bool]$casReceipt.test_scratch_removed_after_receipt -and
    [int]$casReceipt.world_build_count -eq 0
) "Rapier evaluator to CAS receipt changed"

$mujocoRoot = Join-Path $repoRoot "sdk\adapters\mujoco"
$testModule = (
    "sporespore_mujoco_adapter.qsdk_r23d65_selected_profile_turning_test." +
    "R23D65MujocoWorkerTests."
)
$mujocoBridge = Invoke-R23D65RuntimeProcess -FileName $pythonHost `
    -Arguments @(
        "-m", "unittest",
        (
            $testModule +
            "test_inherited_private_physical_entry_uses_campaign_preflight_bridge"
        )
    ) -WorkingDirectory $mujocoRoot
Assert-R23D65RuntimeSuccess $mujocoBridge "MuJoCo inherited preflight bridge"

$godotWorker = Invoke-R23D65RuntimeProcess -FileName $godotHost `
    -Arguments @(
        "--headless", "--path", $repoRoot,
        "--script",
        "res://tests/test_sdk_qsdk_r23d65_godot_failure_terminal_projection_zero_world.gd"
    ) -WorkingDirectory $repoRoot
Assert-R23D65RuntimeSuccess $godotWorker "Godot failure terminal projection"
$godotWorkerReceipt = Get-R23D65RuntimeMarkerJson $godotWorker.stdout (
    "QSDK_R23D65_GODOT_FAILURE_TERMINAL_PROJECTION_ZERO_WORLD "
) "Godot failure terminal projection"
Assert-R23D65Runtime (
    [int]$godotWorkerReceipt.complete_identity_projection_canary_count -eq 1 -and
    [int]$godotWorkerReceipt.world_count_preservation_canary_count -eq 1 -and
    [int]$godotWorkerReceipt.world_build_count -eq 0
) "Godot failure terminal projection receipt changed"

$rapierFailure = Invoke-R23D65RuntimeProcess -FileName $cargoHost `
    -Arguments @(
        "test", "--manifest-path", $rapierManifest,
        "failure_terminal_projection_is_complete_and_preserves_observed_world_counts"
    ) -WorkingDirectory $repoRoot -TimeoutSeconds 600
Assert-R23D65RuntimeSuccess $rapierFailure "Rapier failure terminal projection"
Assert-R23D65Runtime (
    ($rapierFailure.stdout + $rapierFailure.stderr).Contains("1 passed")
) "Rapier failure terminal projection test did not execute exactly one match"

$mujocoFailure = Invoke-R23D65RuntimeProcess -FileName $pythonHost `
    -Arguments @(
        "-m", "unittest",
        (
            $testModule +
            "test_failure_terminal_projection_is_complete_and_preserves_world_counts"
        )
    ) -WorkingDirectory $mujocoRoot
Assert-R23D65RuntimeSuccess $mujocoFailure "MuJoCo failure terminal projection"

$supervisorPath = Join-Path $repoRoot "sdk\run_qsdk_r23d65_supervisor.ps1"
$supervisor = Invoke-R23D65RuntimeProcess -FileName $powerShellHost `
    -Arguments @(
        "-NoLogo", "-NoProfile", "-ExecutionPolicy", "Bypass",
        "-File", $supervisorPath, "-TestTerminalNormalization"
    ) -WorkingDirectory $repoRoot
Assert-R23D65RuntimeSuccess $supervisor "supervisor terminal normalization"
$supervisorReceipt = Get-R23D65RuntimeMarkerJson $supervisor.stdout (
    "QSDK_R23D65_SUPERVISOR_TERMINAL_NORMALIZATION_PASS "
) "supervisor terminal normalization"
Assert-R23D65Runtime (
    [int]$supervisorReceipt.declared_engine_count -eq 3 -and
    [int]$supervisorReceipt.conforming_engine_count -eq 3 -and
    [int]$supervisorReceipt.completed_missing_identity_field_count -eq 3 -and
    [int]$supervisorReceipt.identity_and_count_mutation_rejection_count -eq 2 -and
    [int]$supervisorReceipt.world_build_count -eq 0
) "supervisor terminal normalization receipt changed"

$evaluatorPath = Join-Path $repoRoot (
    "sdk\turning\r23d65_selected_profile_three_engine_turning_validation_" +
    "evaluator.py"
)
$evaluator = Invoke-R23D65RuntimeProcess -FileName $pythonHost `
    -Arguments @($evaluatorPath, "failure-terminal-canary") `
    -WorkingDirectory $repoRoot
Assert-R23D65RuntimeSuccess $evaluator "complete evaluator failure terminals"
$evaluatorReceipt = Get-R23D65RuntimeMarkerJson $evaluator.stdout (
    "QSDK_R23D65_FAILURE_TERMINAL_CANARY "
) "complete evaluator failure terminals"
Assert-R23D65Runtime (
    [int]$evaluatorReceipt.declared_engine_count -eq 3 -and
    [int]$evaluatorReceipt.conforming_engine_count -eq 3 -and
    [int]$evaluatorReceipt.declared_cell_count -eq 9 -and
    [int]$evaluatorReceipt.conforming_cell_count -eq 9 -and
    [int]$evaluatorReceipt.identity_mutation_rejection_count -eq 3 -and
    [int]$evaluatorReceipt.world_count_preservation_canary_count -eq 9 -and
    [int]$evaluatorReceipt.world_build_count -eq 0
) "complete evaluator failure-terminal receipt changed"

$obligations = @(
    [ordered]@{
        obligation_id = "rapier_campaign_registration"
        passed = $true
        evidence_stdout_sha256 = Get-R23D65RuntimeSha256 $registration.stdout
    },
    [ordered]@{
        obligation_id = "godot_preworld_exact_hinge_binding_and_carry"
        passed = $true
        exact_host_object_count = 8
    },
    [ordered]@{
        obligation_id = "rapier_worker_evaluator_powershell_cas_chain"
        passed = $true
        canonical_trace_sha256 = [string]$casReceipt.canonical_trace_sha256
        canonical_trace_byte_length = [long]$casReceipt.canonical_trace_byte_length
    },
    [ordered]@{
        obligation_id = "mujoco_inherited_physical_entry_preflight_bridge"
        passed = $true
        declared_arm_count = 3
    },
    [ordered]@{
        obligation_id = "worker_failure_terminal_complete_identity"
        passed = $true
        conforming_engine_count = 3
    },
    [ordered]@{
        obligation_id = "supervisor_terminal_preservation_and_normalization"
        passed = $true
        conforming_engine_count = 3
    },
    [ordered]@{
        obligation_id = "complete_evaluator_failure_terminal_acceptance"
        passed = $true
        conforming_cell_count = 9
    }
)

$receipt = [ordered]@{
    schema_version = "sporespore_qsdk_r23d65_runtime_integration_conformance_v1"
    campaign_id = $campaignId
    gate_id = "QSDK-R23D65"
    question_class = "equivalence_non_inferiority"
    population = (
        "complete_seven_r23d65_successor_obligations_derived_from_" +
        "observed_r23d64_runtime_failures"
    )
    ordered_obligation_ids = @($obligations.obligation_id)
    obligation_receipts = $obligations
    declared_obligation_count = 7
    conforming_obligation_count = 7
    equivalence_margin = 0
    non_inferiority_margin = 0
    sampling_used = $false
    complete_population_adequacy_argument = (
        "All seven declared obligations are the complete successor repair " +
        "population derived from the immutable R23D64 closure; exact 7/7 " +
        "production-shaped conformance is required without sampling."
    )
    model_construction_count = 0
    world_attempt_count = 0
    world_build_count = 0
    physical_equivalence_claimed = $false
    physical_acceptance_authority = $false
}
Write-Output (
    "QSDK_R23D65_RUNTIME_INTEGRATION_PASS " +
    ($receipt | ConvertTo-Json -Compress -Depth 100)
)
