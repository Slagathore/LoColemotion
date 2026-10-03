#requires -Version 7.0

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateSet("worker", "evaluator", "supervisor")]
    [string]$Role,
    [string]$Python = "python"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false
$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$sdkRoot = Join-Path $repoRoot "sdk"
$mujocoRoot = Join-Path $sdkRoot "adapters\mujoco"
$mujocoSitePackages = Join-Path $mujocoRoot ".venv\Lib\site-packages"
$pythonModuleRoot = Join-Path $sdkRoot "python"
$turningRoot = Join-Path $sdkRoot "turning"
$coreDebug = Join-Path $sdkRoot "target\debug\sporespore_locomotion_core.dll"
$evaluator = Join-Path $turningRoot "r23d37_mujoco_policy_seed_isolation_evaluator.py"
$supervisor = Join-Path $sdkRoot "run_qsdk_r23d37_supervisor.ps1"
$strictArrayTest = Join-Path $PSScriptRoot "test_strict_json_array_document.ps1"
$stageId = "mujoco_r23d21_same_seed_policy_isolation"
$cellId = "mujoco__r23d21_same_seed_policy_isolation__reference_zero"

function Assert-Role([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "QSDK-R23D37 $Role role: $Message" }
}

function Resolve-Application([string]$Command) {
    if ([IO.Path]::IsPathFullyQualified($Command)) {
        $resolved = [IO.Path]::GetFullPath($Command)
        Assert-Role (Test-Path -LiteralPath $resolved -PathType Leaf) (
            "application is missing: $resolved"
        )
        return $resolved
    }
    $candidate = Get-Command $Command -CommandType Application -ErrorAction Stop |
        Select-Object -First 1
    return [IO.Path]::GetFullPath([string]$candidate.Source)
}

function Get-OneMarker([object[]]$Output, [string]$Prefix) {
    $matches = @($Output | Where-Object {
        ([string]$_).StartsWith($Prefix, [StringComparison]::Ordinal)
    })
    Assert-Role ($matches.Count -eq 1) ($Output -join "`n")
    return ([string]$matches[0]).Substring($Prefix.Length) |
        ConvertFrom-Json -AsHashtable -Depth 100
}

$pythonPath = Resolve-Application $Python
Assert-Role (Test-Path -LiteralPath $coreDebug -PathType Leaf) (
    "debug locomotion core is missing; build it before attestation"
)
Assert-Role (Test-Path -LiteralPath $mujocoSitePackages -PathType Container) (
    "locked MuJoCo site-packages are missing"
)

$savedPythonPath = $env:PYTHONPATH
$savedLibrary = $env:SPORESPORE_LOCOMOTION_LIBRARY
try {
    $env:PYTHONPATH = (@(
        $pythonModuleRoot,
        $mujocoRoot,
        $mujocoSitePackages,
        $turningRoot
    ) -join [IO.Path]::PathSeparator)
    $env:SPORESPORE_LOCOMOTION_LIBRARY = $coreDebug
    if ($Role -ceq "worker") {
        $output = @(
            & $pythonPath -m `
                sporespore_mujoco_adapter.qsdk_r23d37_policy_seed_isolation `
                preflight --stage $stageId --onset onset_600 `
                --arm reference_zero 2>&1
        )
        Assert-Role ($LASTEXITCODE -eq 0) ($output -join "`n")
        $receipt = Get-OneMarker $output "QSDK_R23D37_MUJOCO_PREFLIGHT "
        Assert-Role (
            [string]$receipt.cell_id -ceq $cellId -and
            [string]$receipt.controller_policy_id -ceq
                "sporespore_balanced_wave_r23d21_reduced_yaw_authority_v1" -and
            [string]$receipt.controller_memory_schema -ceq
                "sporespore_balanced_wave_memory_v1" -and
            -not [bool]$receipt.turning_tested -and
            [int]$receipt.world_build_count -eq 0
        ) "worker preflight identity changed"

        $negative = @(
            & $pythonPath -m `
                sporespore_mujoco_adapter.qsdk_r23d37_policy_seed_isolation `
                physical --stage $stageId --onset onset_600 `
                --arm reference_zero `
                --source-commit 0000000000000000000000000000000000000000 2>&1
        )
        Assert-Role ($LASTEXITCODE -eq 1) ($negative -join "`n")
        $failure = Get-OneMarker $negative "QSDK_R23D37_MUJOCO_TERMINAL "
        Assert-Role (
            ([string]$failure.failure_code).Contains("AUTHORIZATION_REQUIRED") -and
            [int]$failure.world_attempt_count -eq 0 -and
            [int]$failure.world_build_count -eq 0
        ) "unauthorized physical negative control changed"
        Write-Host (
            "QSDK_R23D37_CAMPAIGN_WORKER_ROLE_PASS cells=1 policy_canaries=2 " +
            "authorization_mutations=1 models=0 worlds=0 physical=False"
        )
    } elseif ($Role -ceq "evaluator") {
        $output = @(& $pythonPath $evaluator preflight 2>&1)
        Assert-Role ($LASTEXITCODE -eq 0) ($output -join "`n")
        $receipt = Get-OneMarker $output "QSDK_R23D37_EVALUATOR_PREFLIGHT "
        Assert-Role (
            [int]$receipt.valid_trace_canary_count -eq 1 -and
            [int]$receipt.trace_mutation_rejection_count -eq 1 -and
            [int]$receipt.valid_manifest_shape_canary_count -eq 3 -and
            [int]$receipt.invalid_manifest_shape_rejection_count -eq 4 -and
            [int]$receipt.world_build_count -eq 0
        ) "evaluator preflight controls changed"
        Write-Host (
            "QSDK_R23D37_CAMPAIGN_EVALUATOR_ROLE_PASS cells=1 " +
            "trace_canaries=1 trace_mutations=1 manifest_shapes=3 " +
            "manifest_mutations=4 models=0 worlds=0 physical=False"
        )
    } else {
        $strictOutput = @(& pwsh -NoLogo -NoProfile -File $strictArrayTest 2>&1)
        Assert-Role ($LASTEXITCODE -eq 0) ($strictOutput -join "`n")
        $strictMarkers = @($strictOutput | Where-Object {
            ([string]$_).StartsWith(
                "STRICT_JSON_ARRAY_DOCUMENT_TEST_PASS ",
                [StringComparison]::Ordinal
            )
        })
        Assert-Role ($strictMarkers.Count -eq 1) ($strictOutput -join "`n")
        $output = @(
            & pwsh -NoLogo -NoProfile -File $supervisor -PreflightOnly `
                -Python $pythonPath 2>&1
        )
        Assert-Role ($LASTEXITCODE -eq 0) ($output -join "`n")
        $receipt = Get-OneMarker $output "QSDK_R23D37_ZERO_WORLD_PASS "
        Assert-Role (
            [int]$receipt.declared_cell_count -eq 1 -and
            [int]$receipt.worker_preflight_count -eq 1 -and
            [bool]$receipt.source_bindings_checkout_bytes_equal_git_blobs -and
            [int]$receipt.world_build_count -eq 0
        ) "supervisor preflight receipt changed"
        Write-Host (
            "QSDK_R23D37_CAMPAIGN_SUPERVISOR_ROLE_PASS cells=1 " +
            "array_shapes=3 models=0 worlds=0 physical=False"
        )
    }
} finally {
    $env:PYTHONPATH = $savedPythonPath
    $env:SPORESPORE_LOCOMOTION_LIBRARY = $savedLibrary
}
