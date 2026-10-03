#requires -Version 7.0

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateSet("R23D72", "R23D73")]
    [string]$Campaign,
    [Parameter(Mandatory)]
    [switch]$ExpectProductionConformanceLockHeld,
    [string]$Python = ""
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$sdkRoot = Join-Path $repoRoot "sdk"
$mujocoRoot = Join-Path $sdkRoot "adapters\mujoco"
$turningRoot = Join-Path $sdkRoot "turning"
$pythonHost = if ([string]::IsNullOrWhiteSpace($Python)) {
    Join-Path $mujocoRoot ".venv\Scripts\python.exe"
} else {
    [IO.Path]::GetFullPath($Python)
}
$corePath = Join-Path $sdkRoot "target\release\sporespore_locomotion_core.dll"
$lockHelper = Join-Path $sdkRoot "locomotion_operation_lock.ps1"

function Assert-R23D74LegacyPreflight([bool]$Condition, [string]$Message) {
    if (-not $Condition) {
        throw "[turning/mujoco] R23D74 $Campaign outer-lock preflight: $Message"
    }
}

function Get-R23D74LegacyPreflightSha256([string]$Path) {
    return "sha256:" + (
        Get-FileHash -LiteralPath $Path -Algorithm SHA256
    ).Hash.ToLowerInvariant()
}

Assert-R23D74LegacyPreflight ([bool]$ExpectProductionConformanceLockHeld) (
    "explicit parent conformance-lock expectation is required"
)
Assert-R23D74LegacyPreflight (
    (& git -C $repoRoot rev-parse --show-toplevel).Trim().Replace("/", "\") -ceq
        $repoRoot.TrimEnd("\", "/") -and
    (& git -C $repoRoot remote get-url origin).Trim() -ceq
        "https://github.com/Slagathore/sporespore.git"
) "repository identity changed"
foreach ($path in @($pythonHost, $corePath, $lockHelper)) {
    Assert-R23D74LegacyPreflight (Test-Path -LiteralPath $path -PathType Leaf) (
        "required zero-world dependency is missing: $path"
    )
}

$configuration = if ($Campaign -ceq "R23D72") {
    [ordered]@{
        module = (
            "sporespore_mujoco_adapter." +
            "qsdk_r23d72_preturn_startup_development"
        )
        marker = "QSDK_R23D72_MUJOCO_PREFLIGHT "
        closure = Join-Path $turningRoot (
            "r23d72_mujoco_selected_profile_" +
            "preturn_startup_development_closure_v1.json"
        )
        supervisor = Join-Path $sdkRoot "run_qsdk_r23d72_supervisor.ps1"
        fixed_steps = 601
        turn_steps = 0
        turning_tested = $false
    }
} else {
    [ordered]@{
        module = (
            "sporespore_mujoco_adapter." +
            "qsdk_r23d73_positive_turn_development"
        )
        marker = "QSDK_R23D73_MUJOCO_PREFLIGHT "
        closure = Join-Path $turningRoot (
            "r23d73_mujoco_selected_profile_" +
            "positive_turn_development_closure_v1.json"
        )
        supervisor = Join-Path $sdkRoot "run_qsdk_r23d73_supervisor.ps1"
        fixed_steps = 2992
        turn_steps = 1200
        turning_tested = $true
    }
}
foreach ($path in @($configuration.closure, $configuration.supervisor)) {
    Assert-R23D74LegacyPreflight (Test-Path -LiteralPath $path -PathType Leaf) (
        "historical source is missing: $path"
    )
}
$closure = Get-Content -LiteralPath $configuration.closure -Raw |
    ConvertFrom-Json -AsHashtable -Depth 100
Assert-R23D74LegacyPreflight (
    (Get-R23D74LegacyPreflightSha256 $configuration.supervisor) -ceq
        [string]$closure.source.supervisor_raw_sha256
) "historical supervisor bytes changed"

. $lockHelper
$lockProbe = Enter-SporeSporeLocomotionOperationLock -Role conformance `
    -TimeoutMilliseconds 0
if ([bool]$lockProbe.acquired) {
    Exit-SporeSporeLocomotionOperationLock -Receipt $lockProbe
    throw (
        "[turning/mujoco] R23D74 $Campaign outer-lock preflight: " +
        "the production conformance mutex was not held by the parent"
    )
}

$start = [Diagnostics.ProcessStartInfo]::new()
$start.FileName = $pythonHost
$start.WorkingDirectory = $repoRoot
$start.UseShellExecute = $false
$start.CreateNoWindow = $true
$start.RedirectStandardOutput = $true
$start.RedirectStandardError = $true
foreach ($argument in @("-B", "-m", [string]$configuration.module, "preflight")) {
    [void]$start.ArgumentList.Add($argument)
}
$start.Environment["PYTHONPATH"] = @(
    $mujocoRoot,
    (Join-Path $sdkRoot "python"),
    $turningRoot
) -join [IO.Path]::PathSeparator
$start.Environment["SPORESPORE_LOCOMOTION_LIBRARY"] = $corePath
$process = [Diagnostics.Process]::new()
$process.StartInfo = $start
try {
    Assert-R23D74LegacyPreflight $process.Start() "could not start Python preflight"
    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()
    $timedOut = -not $process.WaitForExit(120000)
    if ($timedOut) {
        try { $process.Kill($true) } catch {}
        [void]$process.WaitForExit(10000)
    } else {
        $process.WaitForExit()
    }
    $stdout = $stdoutTask.GetAwaiter().GetResult()
    $stderr = $stderrTask.GetAwaiter().GetResult()
    Assert-R23D74LegacyPreflight (
        -not $timedOut -and $process.ExitCode -eq 0
    ) "worker preflight failed: $stderr"
} finally {
    $process.Dispose()
}

$markers = @($stdout -split "`r?`n" | Where-Object {
    ([string]$_).StartsWith(
        [string]$configuration.marker,
        [StringComparison]::Ordinal
    )
})
Assert-R23D74LegacyPreflight ($markers.Count -eq 1) "worker marker changed"
$receipt = $markers[0].Substring(([string]$configuration.marker).Length) |
    ConvertFrom-Json -AsHashtable -Depth 100
Assert-R23D74LegacyPreflight (
    [bool]$receipt.ok -and
    [string]$receipt.question_class -ceq "development" -and
    [bool]$receipt.outcome_exposed_fixture -and
    [int]$receipt.fixed_controller_horizon_step_count -eq
        [int]$configuration.fixed_steps -and
    [int]$receipt.commanded_turn_step_count -eq
        [int]$configuration.turn_steps -and
    [bool]$receipt.turning_tested -eq [bool]$configuration.turning_tested -and
    [int]$receipt.negative_control_class_count -eq 5 -and
    [bool]$receipt.returned_before_mjmodel -and
    [int]$receipt.model_construction_count -eq 0 -and
    [int]$receipt.world_attempt_count -eq 0 -and
    [int]$receipt.world_build_count -eq 0 -and
    [int]$receipt.solver_step_count -eq 0
) "worker zero-world receipt changed"

$public = [ordered]@{
    schema_version = "sporespore_qsdk_r23d74_legacy_mujoco_outer_lock_preflight_v1"
    predecessor_campaign = $Campaign
    historical_supervisor_bytes_unchanged = $true
    active_parent_conformance_lock_verified = $true
    complete_worker_preflight_replayed = $true
    negative_control_class_count = 5
    returned_before_mjmodel = $true
    model_construction_count = 0
    world_attempt_count = 0
    world_build_count = 0
    solver_step_count = 0
    physical_execution_authorized = $false
    physical_acceptance_authority = $false
}
Write-Output (
    "QSDK_R23D74_${Campaign}_OUTER_LOCK_PREFLIGHT_PASS " +
    ($public | ConvertTo-Json -Compress -Depth 100)
)
