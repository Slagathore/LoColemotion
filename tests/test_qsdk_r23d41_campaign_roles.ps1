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
$rapierDebug = Join-Path $sdkRoot "target\debug\qsdk_r23d41_physical.exe"
$evaluator = Join-Path $turningRoot (
    "r23d41_three_engine_startup_ramp_turning_evaluator.py"
)
$supervisor = Join-Path $sdkRoot "run_qsdk_r23d41_supervisor.ps1"
$stageId = "three_engine_authorization_repaired_startup_ramp_turning_validation"
$candidateId = "r23d29_startup_ramp_turning_validation"
$policyId = (
    "sporespore_balanced_wave_r23d29_two_swing_persistent_predictive_" +
    "stability_guarded_steering_v1"
)
$arms = @(
    [ordered]@{ id = "reference_zero"; offset = 0.0 },
    [ordered]@{ id = "positive_heading"; offset = 0.2 },
    [ordered]@{ id = "negative_heading"; offset = -0.2 }
)

function Assert-R23D41Role([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "QSDK-R23D41 $Role role: $Message" }
}

function Resolve-R23D41Application([string]$Command) {
    if ([IO.Path]::IsPathFullyQualified($Command)) {
        $resolved = [IO.Path]::GetFullPath($Command)
        Assert-R23D41Role (Test-Path -LiteralPath $resolved -PathType Leaf) (
            "application is missing: $resolved"
        )
        return $resolved
    }
    return [IO.Path]::GetFullPath([string](
        Get-Command $Command -CommandType Application -ErrorAction Stop |
            Select-Object -First 1
    ).Source)
}

function Get-R23D41Marker([object[]]$Output, [string]$Prefix) {
    $matches = @($Output | Where-Object {
        ([string]$_).StartsWith($Prefix, [StringComparison]::Ordinal)
    })
    Assert-R23D41Role ($matches.Count -eq 1) ($Output -join "`n")
    return ([string]$matches[0]).Substring($Prefix.Length) |
        ConvertFrom-Json -AsHashtable -Depth 100
}

function Invoke-R23D41DebugBuilds {
    $coreOutput = @(& cargo build --quiet --locked --offline `
        --manifest-path (Join-Path $sdkRoot "Cargo.toml") `
        --package sporespore-locomotion-core `
        --package sporespore-godot-adapter 2>&1)
    Assert-R23D41Role ($LASTEXITCODE -eq 0) ($coreOutput -join "`n")
    $rapierOutput = @(& cargo build --quiet --locked --offline `
        --manifest-path (Join-Path $sdkRoot "adapters\rapier\Cargo.toml") `
        --bin qsdk_r23d41_physical 2>&1)
    Assert-R23D41Role ($LASTEXITCODE -eq 0) ($rapierOutput -join "`n")
    Assert-R23D41Role (
        (Test-Path -LiteralPath $coreDebug -PathType Leaf) -and
        (Test-Path -LiteralPath $rapierDebug -PathType Leaf)
    ) "debug runtimes are missing after build"
}

$pythonPath = Resolve-R23D41Application $Python
$godotPath = Resolve-R23D41Application $Godot
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
        Invoke-R23D41DebugBuilds
        foreach ($arm in $arms) {
            $armId = [string]$arm.id
            $rapierOutput = @(& $rapierDebug preflight --stage $stageId `
                --candidate $candidateId --arm $armId 2>&1)
            Assert-R23D41Role ($LASTEXITCODE -eq 0) ($rapierOutput -join "`n")
            $rapier = Get-R23D41Marker $rapierOutput "QSDK_R23D41_RAPIER_PREFLIGHT "
            Assert-R23D41Role (
                [string]$rapier.cell_id -ceq
                    "rapier_parry`__$candidateId`__$armId" -and
                [string]$rapier.controller_policy_id -ceq $policyId -and
                [bool]$rapier.startup_velocity_ramp_enabled -and
                [bool]$rapier.startup_ramp_exact_zero_at_step_zero -and
                [bool]$rapier.startup_ramp_exact_unity_from_step_359 -and
                [int]$rapier.world_build_count -eq 0
            ) "Rapier preflight changed: $armId"

            $godotOutput = @(& $godotPath --headless --path $repoRoot --script `
                res://tests/test_sdk_qsdk_r23d41_godot_jolt_physical_worker.gd -- `
                --stage $stageId --onset onset_600 --arm $armId `
                --preflight-only 2>&1)
            Assert-R23D41Role ($LASTEXITCODE -eq 0) ($godotOutput -join "`n")
            $godotReceipt = Get-R23D41Marker $godotOutput (
                "QSDK_R23D41_GODOT_JOLT_PREFLIGHT "
            )
            Assert-R23D41Role (
                [string]$godotReceipt.cell_id -ceq
                    "godot_jolt`__$candidateId`__$armId" -and
                [string]$godotReceipt.controller_policy_id -ceq $policyId -and
                [bool]$godotReceipt.entrypoint_preflight.sdk_startup_velocity_ramp_enabled -and
                [int]$godotReceipt.world_build_count -eq 0
            ) "Godot/Jolt preflight changed: $armId"

            $mujocoOutput = @(& $pythonPath -m `
                sporespore_mujoco_adapter.qsdk_r23d41_three_engine_turning `
                preflight --stage $stageId --onset onset_600 --arm $armId 2>&1)
            Assert-R23D41Role ($LASTEXITCODE -eq 0) ($mujocoOutput -join "`n")
            $mujoco = Get-R23D41Marker $mujocoOutput "QSDK_R23D41_MUJOCO_PREFLIGHT "
            Assert-R23D41Role (
                [string]$mujoco.cell_id -ceq "mujoco`__$candidateId`__$armId" -and
                [string]$mujoco.controller_policy_id -ceq $policyId -and
                [double]$mujoco.turn_heading_offset_rad -eq [double]$arm.offset -and
                [bool]$mujoco.startup_ramp_canary.all_scales_finite_bounded_and_monotonic -and
                [bool]$mujoco.startup_ramp_canary.residual_order_mutation_rejected -and
                [int]$mujoco.world_build_count -eq 0
            ) "MuJoCo preflight changed: $armId"
        }

        $unauthorized = @(& $rapierDebug physical --stage $stageId `
            --candidate $candidateId --arm reference_zero `
            --source-commit 0000000000000000000000000000000000000000 2>&1)
        Assert-R23D41Role ($LASTEXITCODE -eq 1) ($unauthorized -join "`n")
        $failure = Get-R23D41Marker $unauthorized "QSDK_R23D41_RAPIER_TERMINAL "
        Assert-R23D41Role (
            ([string]$failure.failure_code).Contains("AUTHORIZATION_REQUIRED") -and
            [int]$failure.world_build_count -eq 0
        ) "Rapier unauthorized physical control changed"
        Write-Host (
            "QSDK_R23D41_CAMPAIGN_WORKER_ROLE_PASS cells=9 engines=3 " +
            "authorization_mutations=1 models=0 worlds=0 physical=False"
        )
    } elseif ($Role -ceq "evaluator") {
        $output = @(& $pythonPath $evaluator preflight 2>&1)
        Assert-R23D41Role ($LASTEXITCODE -eq 0) ($output -join "`n")
        $receipt = Get-R23D41Marker $output "QSDK_R23D41_EVALUATOR_PREFLIGHT "
        Assert-R23D41Role (
            [int]$receipt.declared_cell_count -eq 9 -and
            [int]$receipt.valid_trace_canary_count -eq 9 -and
            [int]$receipt.trace_mutation_rejection_count -eq 2 -and
            [int]$receipt.startup_ramp_mutation_rejection_count -eq 1 -and
            [int]$receipt.cycle_integrated_positive_canary_count -eq 3 -and
            [int]$receipt.invalid_manifest_shape_rejection_count -eq 4 -and
            [int]$receipt.world_build_count -eq 0
        ) "evaluator preflight controls changed"
        Write-Host (
            "QSDK_R23D41_CAMPAIGN_EVALUATOR_ROLE_PASS cells=9 engines=3 " +
            "trace_canaries=9 mutations=3 models=0 worlds=0 physical=False"
        )
    } else {
        Invoke-R23D41DebugBuilds
        $output = @(& pwsh -NoLogo -NoProfile -File $supervisor `
            -PreflightOnly -Python $pythonPath -Godot $godotPath 2>&1)
        Assert-R23D41Role ($LASTEXITCODE -eq 0) ($output -join "`n")
        $receipt = Get-R23D41Marker $output "QSDK_R23D41_ZERO_WORLD_PASS "
        Assert-R23D41Role (
            [int]$receipt.declared_cell_count -eq 9 -and
            [int]$receipt.worker_preflight_count -eq 9 -and
            [int]$receipt.source_binding_count -eq 117 -and
            -not [bool]$receipt.source_bindings_checkout_bytes_equal_git_blobs -and
            [int]$receipt.source_bindings_raw_checkout_mismatch_count -eq 1 -and
            [int]$receipt.source_bindings_deterministic_projection_application_count -eq 1 -and
            [bool]$receipt.source_bindings_authority_bytes_equal_git_blobs_after_declared_projection -and
            [int]$receipt.tracked_prefix_exclusion_count -eq 1 -and
            [int]$receipt.declared_deterministic_projection_path_count -eq 1 -and
            [bool]$receipt.campaign_local_policy_ramp_and_worker_gate_passed -and
            [bool]$receipt.production_authorization_preflight_wiring_passed -and
            [bool]$receipt.schema_faithful_positive_authorization_preflight_pending_actual_frozen_documents -and
            [int]$receipt.world_build_count -eq 0
        ) "supervisor preflight receipt changed"
        Write-Host (
            "QSDK_R23D41_CAMPAIGN_SUPERVISOR_ROLE_PASS cells=9 engines=3 " +
            "models=0 worlds=0 physical=False"
        )
    }
} finally {
    $env:PYTHONPATH = $savedPythonPath
    $env:SPORESPORE_LOCOMOTION_LIBRARY = $savedLibrary
}
