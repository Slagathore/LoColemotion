#requires -Version 7.0

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateSet("worker", "evaluator", "supervisor")]
    [string]$Role,
    [string]$Python = "python",
    [string]$Godot = (
        "C:\Users\Cole\CodeStuff\Misc\Godot\" +
        "Godot_v4.7-stable_mono_win64_console.exe"
    )
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$sdkRoot = Join-Path $repoRoot "sdk"
$turningRoot = Join-Path $sdkRoot "turning"
$mujocoRoot = Join-Path $sdkRoot "adapters\mujoco"
$mujocoSitePackages = Join-Path $mujocoRoot ".venv\Lib\site-packages"
$coreDebug = Join-Path $sdkRoot "target\debug\sporespore_locomotion_core.dll"
$rapierDebug = Join-Path $sdkRoot "target\debug\qsdk_r23d48_physical.exe"
$evaluator = Join-Path $turningRoot (
    "r23d48_support_loss_conditioned_three_engine_turning_evaluator.py"
)
$supervisor = Join-Path $sdkRoot "run_qsdk_r23d48_supervisor.ps1"
$stageId = "three_engine_support_loss_conditioned_turning_validation"
$candidateId = "r23d29_support_loss_conditioned_turning_validation"
$policyId = (
    "sporespore_balanced_wave_r23d29_two_swing_persistent_predictive_" +
    "stability_guarded_steering_v1"
)
$transformId = "support_loss_latched_smoothstep_one_cycle_v1"
$arms = @("reference_zero", "positive_heading", "negative_heading")

function Assert-R23D48Role([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "QSDK-R23D48 $Role role: $Message" }
}

function Resolve-R23D48Application([string]$Command) {
    if ([IO.Path]::IsPathFullyQualified($Command)) {
        $resolved = [IO.Path]::GetFullPath($Command)
        Assert-R23D48Role (Test-Path -LiteralPath $resolved -PathType Leaf) (
            "application is missing: $resolved"
        )
        return $resolved
    }
    return [IO.Path]::GetFullPath([string](
        Get-Command $Command -CommandType Application -ErrorAction Stop |
            Select-Object -First 1
    ).Source)
}

function Get-R23D48Marker([object[]]$Output, [string]$Prefix) {
    $matches = @($Output | Where-Object {
        ([string]$_).StartsWith($Prefix, [StringComparison]::Ordinal)
    })
    Assert-R23D48Role ($matches.Count -eq 1) ($Output -join "`n")
    return ([string]$matches[0]).Substring($Prefix.Length) |
        ConvertFrom-Json -AsHashtable -Depth 100
}

function Invoke-R23D48DebugBuilds {
    $coreOutput = @(& cargo build --quiet --locked --offline `
        --manifest-path (Join-Path $sdkRoot "Cargo.toml") `
        --package sporespore-locomotion-core `
        --package sporespore-godot-adapter 2>&1)
    Assert-R23D48Role ($LASTEXITCODE -eq 0) ($coreOutput -join "`n")
    $rapierOutput = @(& cargo build --quiet --locked --offline `
        --manifest-path (Join-Path $sdkRoot "adapters\rapier\Cargo.toml") `
        --bin qsdk_r23d48_physical 2>&1)
    Assert-R23D48Role ($LASTEXITCODE -eq 0) ($rapierOutput -join "`n")
    Assert-R23D48Role (
        (Test-Path -LiteralPath $coreDebug -PathType Leaf) -and
        (Test-Path -LiteralPath $rapierDebug -PathType Leaf)
    ) "debug runtimes are missing after build"
}

$pythonPath = Resolve-R23D48Application $Python
$godotPath = Resolve-R23D48Application $Godot
$savedPythonPath = $env:PYTHONPATH
$savedLibrary = $env:SPORESPORE_LOCOMOTION_LIBRARY
try {
    $env:PYTHONPATH = (@(
        (Join-Path $sdkRoot "python"),
        $mujocoRoot,
        $mujocoSitePackages,
        $turningRoot
    ) -join [IO.Path]::PathSeparator)
    $env:SPORESPORE_LOCOMOTION_LIBRARY = $coreDebug

    if ($Role -ceq "worker") {
        Invoke-R23D48DebugBuilds
        foreach ($arm in $arms) {
            $rapierOutput = @(& $rapierDebug preflight --stage $stageId `
                --candidate $candidateId --arm $arm 2>&1)
            Assert-R23D48Role ($LASTEXITCODE -eq 0) ($rapierOutput -join "`n")
            $rapier = Get-R23D48Marker $rapierOutput (
                "QSDK_R23D48_RAPIER_PREFLIGHT "
            )
            Assert-R23D48Role (
                [string]$rapier.cell_id -ceq
                    "rapier_parry`__$candidateId`__$arm" -and
                [string]$rapier.controller_policy_id -ceq $policyId -and
                [string]$rapier.startup_ramp_id -ceq $transformId -and
                [bool]$rapier.support_loss_trigger_branch_canary_passed -and
                [bool]$rapier.support_loss_identity_branch_canary_passed -and
                [int]$rapier.model_construction_count -eq 0 -and
                [int]$rapier.world_build_count -eq 0
            ) "Rapier preflight changed: $arm"

            $godotOutput = @(& $godotPath --headless --path $repoRoot --script `
                res://tests/test_sdk_qsdk_r23d48_godot_jolt_physical_worker.gd -- `
                --stage $stageId --onset onset_600 --arm $arm `
                --preflight-only 2>&1)
            Assert-R23D48Role ($LASTEXITCODE -eq 0) ($godotOutput -join "`n")
            $godotReceipt = Get-R23D48Marker $godotOutput (
                "QSDK_R23D48_GODOT_JOLT_PREFLIGHT "
            )
            Assert-R23D48Role (
                [string]$godotReceipt.cell_id -ceq
                    "godot_jolt`__$candidateId`__$arm" -and
                [string]$godotReceipt.controller_policy_id -ceq $policyId -and
                [string]$godotReceipt.caller_declared_trace_row_schema -ceq
                    "sporespore_qsdk_r23d48_turning_trace_row_v1" -and
                [bool]$godotReceipt.trace_composition_horizon.ok -and
                [int]$godotReceipt.model_construction_count -eq 0 -and
                [int]$godotReceipt.world_build_count -eq 0
            ) "Godot/Jolt preflight changed: $arm"

            $mujocoOutput = @(& $pythonPath -m `
                sporespore_mujoco_adapter.qsdk_r23d48_three_engine_turning `
                preflight --stage $stageId --onset onset_600 --arm $arm 2>&1)
            Assert-R23D48Role ($LASTEXITCODE -eq 0) ($mujocoOutput -join "`n")
            $mujoco = Get-R23D48Marker $mujocoOutput (
                "QSDK_R23D48_MUJOCO_PREFLIGHT "
            )
            Assert-R23D48Role (
                [string]$mujoco.cell_id -ceq "mujoco`__$candidateId`__$arm" -and
                [string]$mujoco.controller_policy_id -ceq $policyId -and
                [bool]$mujoco.startup_ramp_canary.support_loss_trigger_branch_canary_passed -and
                [bool]$mujoco.startup_ramp_canary.support_loss_identity_branch_canary_passed -and
                [int]$mujoco.model_construction_count -eq 0 -and
                [int]$mujoco.world_build_count -eq 0
            ) "MuJoCo preflight changed: $arm"
        }

        $unauthorized = @(& $rapierDebug physical --stage $stageId `
            --candidate $candidateId --arm reference_zero `
            --source-commit 0000000000000000000000000000000000000000 2>&1)
        Assert-R23D48Role ($LASTEXITCODE -eq 1) ($unauthorized -join "`n")
        $failure = Get-R23D48Marker $unauthorized "QSDK_R23D48_RAPIER_TERMINAL "
        Assert-R23D48Role (
            ([string]$failure.failure_code).Contains("AUTHORIZATION_REQUIRED") -and
            [int]$failure.world_build_count -eq 0
        ) "Rapier unauthorized physical control changed"
        Write-Host (
            "QSDK_R23D48_CAMPAIGN_WORKER_ROLE_PASS cells=9 engines=3 " +
            "branches=2 authorization_mutations=1 models=0 worlds=0 physical=False"
        )
    } elseif ($Role -ceq "evaluator") {
        $output = @(& $pythonPath $evaluator preflight 2>&1)
        Assert-R23D48Role ($LASTEXITCODE -eq 0) ($output -join "`n")
        $receipt = Get-R23D48Marker $output "QSDK_R23D48_EVALUATOR_PREFLIGHT "
        Assert-R23D48Role (
            [int]$receipt.declared_cell_count -eq 9 -and
            [int]$receipt.valid_trace_canary_count -eq 9 -and
            [int]$receipt.trace_mutation_rejection_count -eq 2 -and
            [int]$receipt.startup_ramp_mutation_rejection_count -eq 1 -and
            [int]$receipt.cycle_integrated_positive_canary_count -eq 3 -and
            [int]$receipt.invalid_manifest_shape_rejection_count -eq 4 -and
            [int]$receipt.world_build_count -eq 0
        ) "evaluator preflight controls changed"
        Write-Host (
            "QSDK_R23D48_CAMPAIGN_EVALUATOR_ROLE_PASS cells=9 engines=3 " +
            "trace_canaries=9 mutations=3 models=0 worlds=0 physical=False"
        )
    } else {
        Invoke-R23D48DebugBuilds
        $output = @(& pwsh -NoLogo -NoProfile -File $supervisor `
            -PreflightOnly -Python $pythonPath -Godot $godotPath 2>&1)
        Assert-R23D48Role ($LASTEXITCODE -eq 0) ($output -join "`n")
        $receipt = Get-R23D48Marker $output "QSDK_R23D48_ZERO_WORLD_PASS "
        Assert-R23D48Role (
            [int]$receipt.declared_cell_count -eq 9 -and
            [int]$receipt.worker_preflight_count -eq 9 -and
            [int]$receipt.source_binding_count -gt 100 -and
            [bool]$receipt.source_bindings_authority_bytes_equal_git_blobs_after_declared_projection -and
            [int]$receipt.tracked_prefix_exclusion_count -eq 1 -and
            [int]$receipt.declared_deterministic_projection_path_count -eq 1 -and
            [bool]$receipt.campaign_local_policy_ramp_and_worker_gate_passed -and
            [bool]$receipt.production_authorization_preflight_wiring_passed -and
            [int]$receipt.model_construction_count -eq 0 -and
            [int]$receipt.world_build_count -eq 0
        ) "supervisor preflight receipt changed"
        Write-Host (
            "QSDK_R23D48_CAMPAIGN_SUPERVISOR_ROLE_PASS cells=9 engines=3 " +
            "models=0 worlds=0 physical=False"
        )
    }
} finally {
    $env:PYTHONPATH = $savedPythonPath
    $env:SPORESPORE_LOCOMOTION_LIBRARY = $savedLibrary
}
