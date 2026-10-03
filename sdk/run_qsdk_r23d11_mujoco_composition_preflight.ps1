#requires -Version 7.0

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$sdkRoot = [IO.Path]::GetFullPath($PSScriptRoot)
$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $sdkRoot))
$adapterRoot = Join-Path $sdkRoot "adapters\mujoco"
$python = Join-Path $adapterRoot ".venv\Scripts\python.exe"
$module = "sporespore_mujoco_adapter.qsdk_r23d11_stability_assisted_taper"

function Assert-R23D11Mujoco([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

function Invoke-R23D11Mujoco([string[]]$Arguments) {
    $output = & $python -m $module @Arguments 2>&1 | Out-String
    return [ordered]@{ exit_code = $LASTEXITCODE; output = $output }
}

function Get-R23D11MujocoMarker(
    [Collections.IDictionary]$Execution,
    [string]$Prefix
) {
    $matches = @(([string]$Execution.output -split "\r?\n") | Where-Object {
        $_.StartsWith($Prefix, [StringComparison]::Ordinal)
    })
    Assert-R23D11Mujoco ($matches.Count -eq 1) (
        "QSDK-R23D11 expected one MuJoCo marker $Prefix"
    )
    return $matches[0].Substring($Prefix.Length) |
        ConvertFrom-Json -AsHashtable -Depth 100
}

foreach ($path in @(
    $python,
    (Join-Path $adapterRoot "sporespore_mujoco_adapter\qsdk_r23d11_stability_assisted_taper.py"),
    (Join-Path $adapterRoot "test_qsdk_r23d11_stability_assisted_taper.py")
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

$oldPythonPath = $env:PYTHONPATH
try {
    $env:PYTHONPATH = $adapterRoot
    $unitOutput = & $python -m unittest -v test_qsdk_r23d11_stability_assisted_taper 2>&1 |
        Out-String
    Assert-R23D11Mujoco ($LASTEXITCODE -eq 0) (
        "QSDK-R23D11 MuJoCo unit tests failed: $unitOutput"
    )

    $cells = @(
        @{ stage = "mujoco_stability_assisted_taper_screen"; arm = "positive_heading" },
        @{ stage = "mujoco_stability_assisted_taper_screen"; arm = "negative_heading" },
        @{ stage = "three_engine_confirmation"; arm = "reference_zero" },
        @{ stage = "three_engine_confirmation"; arm = "positive_heading" },
        @{ stage = "three_engine_confirmation"; arm = "negative_heading" }
    )
    foreach ($cell in $cells) {
        $execution = Invoke-R23D11Mujoco @(
            "preflight", "--stage-id", $cell.stage, "--arm-id", $cell.arm
        )
        Assert-R23D11Mujoco ([int]$execution.exit_code -eq 0) (
            "QSDK-R23D11 MuJoCo preflight failed: $($execution.output)"
        )
        $receipt = Get-R23D11MujocoMarker (
            $execution
        ) "QSDK_R23D11_MUJOCO_PREFLIGHT "
        Assert-R23D11Mujoco (
            [string]$receipt.engine_id -ceq "mujoco" -and
            [string]$receipt.stage_id -ceq [string]$cell.stage -and
            [string]$receipt.arm_id -ceq [string]$cell.arm -and
            [int]$receipt.composition_canary_count -eq 7 -and
            [int]$receipt.mutation_control_count -eq 18 -and
            [int]$receipt.inherited_temporal_canary_count -eq 5 -and
            [bool]$receipt.native_composition_mirror -and
            -not [bool]$receipt.physical_worker_implemented -and
            -not [bool]$receipt.physical_execution_authorized -and
            [int]$receipt.model_construction_count -eq 0 -and
            [int]$receipt.world_attempt_count -eq 0 -and
            [int]$receipt.world_build_count -eq 0
        ) "QSDK-R23D11 MuJoCo preflight receipt changed"
    }

    $refusal = Invoke-R23D11Mujoco @(
        "physical", "--stage-id", "mujoco_stability_assisted_taper_screen",
        "--arm-id", "positive_heading"
    )
    Assert-R23D11Mujoco ([int]$refusal.exit_code -ne 0) (
        "QSDK-R23D11 MuJoCo physical command did not fail closed"
    )
    $failure = Get-R23D11MujocoMarker (
        $refusal
    ) "QSDK_R23D11_MUJOCO_FAILURE "
    Assert-R23D11Mujoco (
        [string]$failure.failure_stage -ceq "before_model" -and
        [string]$failure.failure_code -ceq
            "QSDK_R23D11_MJC_PHYSICAL_ROUTE_NOT_IMPLEMENTED" -and
        [int]$failure.model_construction_count -eq 0 -and
        [int]$failure.world_build_count -eq 0
    ) "QSDK-R23D11 MuJoCo physical refusal changed"
}
finally {
    $env:PYTHONPATH = $oldPythonPath
}

Write-Host (
    "QSDK_R23D11_MUJOCO_COMPOSITION_PASS identities=5 canaries=7 " +
    "mutations=18 temporal_canaries=5 workers=0 models=0 worlds=0 " +
    "physical_authority=False"
)
