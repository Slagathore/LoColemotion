#requires -Version 7.0

[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$sdkRoot = [IO.Path]::GetFullPath($PSScriptRoot)
$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $sdkRoot))
$mujocoRoot = Join-Path $sdkRoot "adapters\mujoco"
$pythonRoot = Join-Path $sdkRoot "python"
$python = Join-Path $mujocoRoot ".venv\Scripts\python.exe"
$releaseLibrary = Join-Path $sdkRoot "target\release\sporespore_locomotion_core.dll"
$manifest = Join-Path $sdkRoot "Cargo.toml"
$materializer = Join-Path $sdkRoot "r23d3_reproducible_runtime_materialization.ps1"
$module = "sporespore_mujoco_adapter.qsdk_r23d11_stability_assisted_taper"
$campaignId = (
    "QSDK-R23D11-SUPPORT-CENTROID-ASSISTED-QUIESCENT-TAPER-" +
    "BILATERAL-TURN-DEVELOPMENT"
)
function Assert-R23D11Mujoco([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

function Invoke-R23D11Mujoco {
    param(
        [Parameter(Mandatory)][string[]]$Arguments,
        [Parameter(Mandatory)][string]$Label
    )
    $start = [Diagnostics.ProcessStartInfo]::new()
    $start.FileName = $python
    $start.WorkingDirectory = $repoRoot
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    $start.Environment["SPORESPORE_LOCOMOTION_LIBRARY"] = $releaseLibrary
    $start.Environment["PYTHONPATH"] = (
        $mujocoRoot + [IO.Path]::PathSeparator +
        $pythonRoot + [IO.Path]::PathSeparator +
        (Join-Path $sdkRoot "turning")
    )
    [void]$start.ArgumentList.Add("-m")
    [void]$start.ArgumentList.Add($module)
    foreach ($argument in $Arguments) {
        [void]$start.ArgumentList.Add($argument)
    }
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $start
    Assert-R23D11Mujoco $process.Start() (
        "QSDK-R23D11 MuJoCo process did not start: $Label"
    )
    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()
    $timedOut = -not $process.WaitForExit(60000)
    if ($timedOut) {
        $process.Kill($true)
        $process.WaitForExit()
    }
    return [ordered]@{
        label = $Label
        exit_code = $process.ExitCode
        timed_out = $timedOut
        stdout = $stdoutTask.GetAwaiter().GetResult()
        stderr = $stderrTask.GetAwaiter().GetResult()
    }
}

function Get-R23D11MujocoMarker {
    param(
        [Parameter(Mandatory)][Collections.IDictionary]$Execution,
        [Parameter(Mandatory)][string]$Prefix
    )
    $markers = @(([string]$Execution.stdout -split "\r?\n") | Where-Object {
        $_.StartsWith($Prefix, [StringComparison]::Ordinal)
    })
    Assert-R23D11Mujoco ($markers.Count -eq 1) (
        "QSDK-R23D11 expected one $Prefix marker from $($Execution.label)"
    )
    return $markers[0].Substring($Prefix.Length) |
        ConvertFrom-Json -AsHashtable -Depth 100
}

foreach ($path in @(
    $python,
    $manifest,
    $materializer,
    (Join-Path $mujocoRoot "sporespore_mujoco_adapter\qsdk_r23d11_stability_assisted_taper.py"),
    (Join-Path $mujocoRoot "sporespore_mujoco_adapter\qsdk_r23d11_stability_assisted_taper_physical.py"),
    (Join-Path $mujocoRoot "test_qsdk_r23d11_stability_assisted_taper.py"),
    (Join-Path $mujocoRoot "test_qsdk_r23d11_stability_assisted_taper_physical.py")
)) {
    Assert-R23D11Mujoco (Test-Path -LiteralPath $path -PathType Leaf) (
        "QSDK-R23D11 MuJoCo input missing: $path"
    )
}
Assert-R23D11Mujoco (
    (git -C $repoRoot rev-parse --show-toplevel).Trim() -ceq
        $repoRoot.Replace("\", "/") -and
    (git -C $repoRoot remote get-url origin).Trim() -ceq
        "https://github.com/Slagathore/sporespore.git"
) "QSDK-R23D11 MuJoCo repository identity changed"

. $materializer
$sourceCommit = (git -C $repoRoot rev-parse HEAD).Trim()
$buildParameters = @{
    RepoRoot = $repoRoot
    SourceCommit = $sourceCommit
    TargetRoot = (Join-Path $sdkRoot "target")
    CargoArguments = @(
        "build", "--quiet", "--release", "--locked", "--offline",
        "--manifest-path", $manifest,
        "--package", "sporespore-locomotion-core"
    )
}
$build = Invoke-SporeSporeR23D3PinnedCargo @buildParameters
Assert-R23D11Mujoco (
    [int]$build.exit_code -eq 0 -and
    (Test-Path -LiteralPath $releaseLibrary -PathType Leaf)
) "QSDK-R23D11 MuJoCo public-core build failed"

$oldLibrary = $env:SPORESPORE_LOCOMOTION_LIBRARY
$oldPythonPath = $env:PYTHONPATH
try {
    $env:SPORESPORE_LOCOMOTION_LIBRARY = $releaseLibrary
    $env:PYTHONPATH = (
        $mujocoRoot + [IO.Path]::PathSeparator +
        $pythonRoot + [IO.Path]::PathSeparator +
        (Join-Path $sdkRoot "turning")
    )
    $unitOutput = & $python -m unittest -v `
        test_qsdk_r23d11_stability_assisted_taper `
        test_qsdk_r23d11_stability_assisted_taper_physical 2>&1 |
        Out-String
    Assert-R23D11Mujoco ($LASTEXITCODE -eq 0) (
        "QSDK-R23D11 MuJoCo tests failed: $unitOutput"
    )
} finally {
    $env:SPORESPORE_LOCOMOTION_LIBRARY = $oldLibrary
    $env:PYTHONPATH = $oldPythonPath
}

$cells = @(
    @{ stage = "mujoco_stability_assisted_taper_screen"; arm = "positive_heading" },
    @{ stage = "mujoco_stability_assisted_taper_screen"; arm = "negative_heading" },
    @{ stage = "three_engine_confirmation"; arm = "reference_zero" },
    @{ stage = "three_engine_confirmation"; arm = "positive_heading" },
    @{ stage = "three_engine_confirmation"; arm = "negative_heading" }
)
foreach ($cell in $cells) {
    $execution = Invoke-R23D11Mujoco -Label "$($cell.stage):$($cell.arm)" -Arguments @(
        "preflight", "--stage-id", $cell.stage, "--arm-id", $cell.arm
    )
    Assert-R23D11Mujoco (
        -not [bool]$execution.timed_out -and [int]$execution.exit_code -eq 0
    ) "QSDK-R23D11 MuJoCo preflight failed: $($execution.label)"
    $receipt = Get-R23D11MujocoMarker $execution "QSDK_R23D11_MUJOCO_PREFLIGHT "
    Assert-R23D11Mujoco (
        [string]$receipt.schema_version -ceq
            "sporespore_qsdk_r23d11_mujoco_composition_preflight_v1" -and
        [string]$receipt.campaign_id -ceq $campaignId -and
        [int]$receipt.composition_canary_count -eq 7 -and
        [int]$receipt.mutation_control_count -eq 18 -and
        [int]$receipt.inherited_temporal_canary_count -eq 5 -and
        [bool]$receipt.native_composition_mirror -and
        [bool]$receipt.physical_worker_implemented -and
        [bool]$receipt.physical_worker_dormant_behind_supervisor_authorization -and
        [int]$receipt.model_construction_count -eq 0 -and
        [int]$receipt.world_attempt_count -eq 0 -and
        [int]$receipt.world_build_count -eq 0 -and
        -not [bool]$receipt.physical_execution_authorized
    ) "QSDK-R23D11 MuJoCo receipt changed: $($execution.label)"
}

$bypass = Invoke-R23D11Mujoco -Label "physical-refusal" -Arguments @(
    "physical", "--stage-id", "mujoco_stability_assisted_taper_screen",
    "--arm-id", "positive_heading", "--source-commit", $sourceCommit
)
Assert-R23D11Mujoco (
    -not [bool]$bypass.timed_out -and [int]$bypass.exit_code -ne 0
) "QSDK-R23D11 MuJoCo physical route did not fail closed"
$terminal = Get-R23D11MujocoMarker $bypass "QSDK_R23D11_TERMINAL "
Assert-R23D11Mujoco (
    [string]$terminal.failure_stage -ceq "before_world" -and
    [string]$terminal.failure_code -ceq
        "QSDK_R23D11_MJC_PHYSICAL_AUTHORIZATION_REQUIRED" -and
    [int]$terminal.world_attempt_count -eq 0 -and
    [int]$terminal.world_build_count -eq 0
) "QSDK-R23D11 MuJoCo physical refusal changed"

Write-Host (
    "QSDK_R23D11_MUJOCO_NATIVE_ROUTE_PASS identities=5 canaries=7 " +
    "mutations=18 temporal_canaries=5 physical_worker=True dormant=True models=0 worlds=0 " +
    "physical_authority=False"
)
