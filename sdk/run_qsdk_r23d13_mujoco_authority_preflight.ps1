#requires -Version 7.0

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$sdkRoot = [IO.Path]::GetFullPath($PSScriptRoot)
$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $sdkRoot))
$adapterRoot = Join-Path $sdkRoot "adapters\mujoco"
$python = Join-Path $adapterRoot ".venv\Scripts\python.exe"
$module = "sporespore_mujoco_adapter.qsdk_r23d13_residual_pose_authority"
$sourcePath = Join-Path (
    $adapterRoot
) "sporespore_mujoco_adapter\qsdk_r23d13_residual_pose_authority.py"
$testPath = Join-Path $adapterRoot "test_qsdk_r23d13_residual_pose_authority.py"

function Assert-R23D13Mujoco([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

function Invoke-R23D13Mujoco([string]$Command) {
    $output = & $python -m $module $Command 2>&1 | Out-String
    return [ordered]@{ exit_code = $LASTEXITCODE; output = $output }
}

function Get-R23D13Marker(
    [Collections.IDictionary]$Execution,
    [string]$Prefix
) {
    $matches = @(([string]$Execution.output -split "\r?\n") | Where-Object {
        $_.StartsWith($Prefix, [StringComparison]::Ordinal)
    })
    Assert-R23D13Mujoco ($matches.Count -eq 1) (
        "QSDK-R23D13 expected one MuJoCo marker $Prefix"
    )
    return $matches[0].Substring($Prefix.Length) |
        ConvertFrom-Json -AsHashtable -Depth 100
}

function Get-TextSha256([string]$Value) {
    $bytes = [Text.Encoding]::UTF8.GetBytes($Value)
    return [Convert]::ToHexString(
        [Security.Cryptography.SHA256]::HashData($bytes)
    ).ToLowerInvariant()
}

Assert-R23D13Mujoco (
    (git -C $repoRoot rev-parse --show-toplevel).Trim() -ceq
        $repoRoot.Replace("\", "/") -and
    (git -C $repoRoot remote get-url origin).Trim() -ceq
        "https://github.com/Slagathore/sporespore.git"
) "QSDK-R23D13 MuJoCo repository identity changed"
foreach ($path in @($python, $sourcePath, $testPath)) {
    Assert-R23D13Mujoco (Test-Path -LiteralPath $path -PathType Leaf) (
        "QSDK-R23D13 MuJoCo input missing: $path"
    )
}
$sourceText = [IO.File]::ReadAllText($sourcePath)
Assert-R23D13Mujoco (
    -not $sourceText.Contains("sdk.turning", [StringComparison]::Ordinal) -and
    -not $sourceText.Contains(
        "r23d13_residual_pose_authority as", [StringComparison]::Ordinal
    )
) "QSDK-R23D13 MuJoCo native implementation imports the reference oracle"

$oldPythonPath = $env:PYTHONPATH
try {
    $env:PYTHONPATH = $adapterRoot
    $unitOutput = & $python -m unittest -v `
        test_qsdk_r23d13_residual_pose_authority 2>&1 | Out-String
    Assert-R23D13Mujoco ($LASTEXITCODE -eq 0) (
        "QSDK-R23D13 MuJoCo unit tests failed: $unitOutput"
    )

    $execution = Invoke-R23D13Mujoco "preflight"
    Assert-R23D13Mujoco ([int]$execution.exit_code -eq 0) (
        "QSDK-R23D13 MuJoCo preflight failed: $($execution.output)"
    )
    $receipt = Get-R23D13Marker (
        $execution
    ) "QSDK_R23D13_MUJOCO_AUTHORITY_PREFLIGHT "
    Assert-R23D13Mujoco (
        [string]$receipt.engine_id -ceq "mujoco" -and
        [string]$receipt.language -ceq "python" -and
        [int]$receipt.valid_canary_count -eq 10 -and
        [int]$receipt.mutation_control_count -eq 20 -and
        [bool]$receipt.critical_r23d12_negative_shape_passed -and
        [bool]$receipt.positive_tight_pose_no_regression_canary_passed -and
        [bool]$receipt.passive_exact_zero_actuation_canary_passed -and
        -not [bool]$receipt.reference_oracle_imported -and
        -not [bool]$receipt.physical_worker_implemented -and
        -not [bool]$receipt.physical_execution_authorized -and
        [int]$receipt.model_construction_count -eq 0 -and
        [int]$receipt.world_attempt_count -eq 0 -and
        [int]$receipt.world_build_count -eq 0 -and
        @($receipt.mutation_failure_codes).Count -eq 20
    ) "QSDK-R23D13 MuJoCo preflight receipt changed"

    $refusal = Invoke-R23D13Mujoco "physical"
    Assert-R23D13Mujoco ([int]$refusal.exit_code -ne 0) (
        "QSDK-R23D13 MuJoCo physical route did not fail closed"
    )
    $failure = Get-R23D13Marker (
        $refusal
    ) "QSDK_R23D13_MUJOCO_AUTHORITY_FAILURE "
    Assert-R23D13Mujoco (
        [string]$failure.failure_stage -ceq "before_model" -and
        [string]$failure.failure_code -ceq
            "QSDK_R23D13_MJC_PHYSICAL_ROUTE_NOT_IMPLEMENTED" -and
        [int]$failure.model_construction_count -eq 0 -and
        [int]$failure.world_build_count -eq 0
    ) "QSDK-R23D13 MuJoCo physical refusal changed"

    $validHash = Get-TextSha256 ([string]$receipt.valid_canary_vector)
    $mutationHash = Get-TextSha256 (
        (@($receipt.mutation_failure_codes) -join "`n")
    )
    Write-Host (
        "QSDK_R23D13_MUJOCO_AUTHORITY_PASS valid=10 mutations=20 " +
        "critical=True valid_vector_sha256=$validHash " +
        "mutation_vector_sha256=$mutationHash physical_refusals=1 " +
        "workers=0 models=0 worlds=0 physical_authority=False"
    )
}
finally {
    $env:PYTHONPATH = $oldPythonPath
}
