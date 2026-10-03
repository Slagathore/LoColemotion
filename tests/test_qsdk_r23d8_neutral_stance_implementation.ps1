#requires -Version 7.0

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$sdkRoot = Join-Path $repoRoot "sdk"
$mujocoRoot = Join-Path $sdkRoot "adapters\mujoco"
$pythonRoot = Join-Path $sdkRoot "python"
$python = Join-Path $mujocoRoot ".venv\Scripts\python.exe"
$releaseLibrary = Join-Path $sdkRoot "target\release\sporespore_locomotion_core.dll"
$implementationPath = Join-Path $mujocoRoot (
    "sporespore_mujoco_adapter\qsdk_r23d8_neutral_stance_composition.py"
)
$testPath = Join-Path $mujocoRoot (
    "test_qsdk_r23d8_neutral_stance_composition.py"
)
$declarationPath = Join-Path $sdkRoot (
    "turning\r23d8_scientific_execution_contract_v1.json"
)

function Assert-R23D8NeutralStance {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

Assert-R23D8NeutralStance (
    (git -C $repoRoot rev-parse --show-toplevel).Trim().Replace("/", "\") -ceq
        $repoRoot -and
    (git -C $repoRoot remote get-url origin).Trim() -ceq
        "https://github.com/Slagathore/sporespore.git"
) "QSDK-R23D8 neutral-stance repository identity changed"
foreach ($path in @(
    $python,
    $releaseLibrary,
    $implementationPath,
    $testPath,
    $declarationPath
)) {
    Assert-R23D8NeutralStance (Test-Path -LiteralPath $path -PathType Leaf) (
        "QSDK-R23D8 neutral-stance input missing: $path"
    )
}
Assert-R23D8NeutralStance (
    (Get-FileHash -LiteralPath $declarationPath -Algorithm SHA256).
        Hash.ToLowerInvariant() -ceq
        "4cf6d5e318a4d0c8aa80aff34f9ba34828db71e795c33ffb4a0d15ebbbdfb638"
) "QSDK-R23D8 neutral-stance declaration hash changed"

$oldLibrary = $env:SPORESPORE_LOCOMOTION_LIBRARY
$oldPythonPath = $env:PYTHONPATH
try {
    $env:SPORESPORE_LOCOMOTION_LIBRARY = $releaseLibrary
    $env:PYTHONPATH = $mujocoRoot + [IO.Path]::PathSeparator + $pythonRoot
    $unitOutput = & $python -m unittest -v (
        "test_qsdk_r23d8_neutral_stance_composition"
    ) 2>&1 | Out-String
    Assert-R23D8NeutralStance ($LASTEXITCODE -eq 0) (
        "QSDK-R23D8 neutral-stance unit tests failed:`n$unitOutput"
    )
    $jsonOutput = & $python -m (
        "sporespore_mujoco_adapter." +
        "qsdk_r23d8_neutral_stance_composition"
    ) 2>&1 | Out-String
    Assert-R23D8NeutralStance ($LASTEXITCODE -eq 0) (
        "QSDK-R23D8 neutral-stance preflight failed:`n$jsonOutput"
    )
} finally {
    $env:SPORESPORE_LOCOMOTION_LIBRARY = $oldLibrary
    $env:PYTHONPATH = $oldPythonPath
}

$report = $jsonOutput.Trim() | ConvertFrom-Json -AsHashtable -Depth 100
$mutations = $report.algebra.mutation_controls_rejected
Assert-R23D8NeutralStance (
    [string]$report.schema_version -ceq
        "sporespore_qsdk_r23d8_neutral_stance_composition_preflight_v1" -and
    [string]$report.gate_id -ceq "QSDK-R23D8" -and
    [string]$report.policy_id -ceq
        "sporespore_morphology_neutral_stance_bounded_pd_v1" -and
    [int]$report.algebra.canary_count -eq 5 -and
    [int]$report.algebra.mutation_control_count -eq 10 -and
    @($mutations.Values | Where-Object { -not [bool]$_ }).Count -eq 0 -and
    [int]$report.signed_arm_count -eq 2 -and
    [double]$report.signed_arms[0].held_steering_fraction -gt 0.0 -and
    [double]$report.signed_arms[1].held_steering_fraction -lt 0.0 -and
    [int]$report.production_restoration_composition_complete_count -eq 2 -and
    [int]$report.source_actuator_command_count -eq 16 -and
    [int]$report.terminal_solution_count -eq 16 -and
    [int]$report.physics_adapter_start_count -eq 0 -and
    [int]$report.physical_process_launch_count -eq 0 -and
    [int]$report.model_construction_count -eq 0 -and
    [int]$report.world_attempt_count -eq 0 -and
    [int]$report.world_build_count -eq 0 -and
    -not [bool]$report.command_conditioned_turning -and
    -not [bool]$report.physical_acceptance_authority
) "QSDK-R23D8 neutral-stance zero-world report changed"

Write-Host (
    "QSDK_R23D8_NEUTRAL_STANCE_IMPLEMENTATION_PASS algebra_canaries=5 " +
    "mutation_controls=10 signed_arms=2 source_commands=16 " +
    "terminal_solutions=16 models=0 worlds=0 turning=False " +
    "physical_authority=False"
)
