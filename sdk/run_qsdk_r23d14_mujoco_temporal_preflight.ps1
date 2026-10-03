#requires -Version 7.0

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$sdkRoot = [IO.Path]::GetFullPath($PSScriptRoot)
$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $sdkRoot))
$adapterRoot = Join-Path $sdkRoot "adapters\mujoco"
$python = Join-Path $adapterRoot ".venv\Scripts\python.exe"
$module = "sporespore_mujoco_adapter.qsdk_r23d14_tight_gated_horizon"
$sourcePath = Join-Path (
    $adapterRoot
) "sporespore_mujoco_adapter\qsdk_r23d14_tight_gated_horizon.py"
$testPath = Join-Path $adapterRoot "test_qsdk_r23d14_tight_gated_horizon.py"

function Assert-R23D14Mujoco([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

function Invoke-R23D14Mujoco([string]$Command) {
    $output = & $python -m $module $Command 2>&1 | Out-String
    return [ordered]@{ exit_code = $LASTEXITCODE; output = $output }
}

function Get-R23D14Marker(
    [Collections.IDictionary]$Execution,
    [string]$Prefix
) {
    $matches = @(([string]$Execution.output -split "\r?\n") | Where-Object {
        $_.StartsWith($Prefix, [StringComparison]::Ordinal)
    })
    Assert-R23D14Mujoco ($matches.Count -eq 1) (
        "QSDK-R23D14 expected one MuJoCo marker $Prefix"
    )
    return $matches[0].Substring($Prefix.Length) |
        ConvertFrom-Json -AsHashtable -Depth 100
}

function Get-TextSha256([string]$Value) {
    return [Convert]::ToHexString(
        [Security.Cryptography.SHA256]::HashData(
            [Text.Encoding]::UTF8.GetBytes($Value)
        )
    ).ToLowerInvariant()
}

Assert-R23D14Mujoco (
    (git -C $repoRoot rev-parse --show-toplevel).Trim() -ceq
        $repoRoot.Replace("\", "/") -and
    (git -C $repoRoot remote get-url origin).Trim() -ceq
        "https://github.com/Slagathore/sporespore.git"
) "QSDK-R23D14 MuJoCo repository identity changed"
foreach ($path in @($python, $sourcePath, $testPath)) {
    Assert-R23D14Mujoco (Test-Path -LiteralPath $path -PathType Leaf) (
        "QSDK-R23D14 MuJoCo input missing: $path"
    )
}
$sourceText = [IO.File]::ReadAllText($sourcePath)
Assert-R23D14Mujoco (
    -not $sourceText.Contains("sdk.turning", [StringComparison]::Ordinal) -and
    -not $sourceText.Contains(
        "r23d14_tight_gated_horizon as", [StringComparison]::Ordinal
    ) -and
    -not $sourceText.Contains("import mujoco", [StringComparison]::Ordinal)
) "QSDK-R23D14 MuJoCo implementation imports its oracle or engine"

$oldPythonPath = $env:PYTHONPATH
try {
    $env:PYTHONPATH = $adapterRoot
    $unitOutput = & $python -m unittest -v `
        test_qsdk_r23d14_tight_gated_horizon 2>&1 | Out-String
    Assert-R23D14Mujoco ($LASTEXITCODE -eq 0) (
        "QSDK-R23D14 MuJoCo unit tests failed: $unitOutput"
    )

    $execution = Invoke-R23D14Mujoco "preflight"
    Assert-R23D14Mujoco ([int]$execution.exit_code -eq 0) (
        "QSDK-R23D14 MuJoCo preflight failed: $($execution.output)"
    )
    $receipt = Get-R23D14Marker (
        $execution
    ) "QSDK_R23D14_MUJOCO_TEMPORAL_PREFLIGHT "
    Assert-R23D14Mujoco (
        [string]$receipt.engine_id -ceq "mujoco" -and
        [string]$receipt.language -ceq "python" -and
        [int]$receipt.valid_canary_count -eq 12 -and
        [int]$receipt.mutation_control_count -eq 14 -and
        [bool]$receipt.retained_positive_timing_shape_passed -and
        [bool]$receipt.retained_negative_timing_shape_passed -and
        [bool]$receipt.passive_exact_zero_actuation_canary_passed -and
        -not [bool]$receipt.reference_oracle_imported -and
        -not [bool]$receipt.physical_worker_implemented -and
        -not [bool]$receipt.physical_execution_authorized -and
        [int]$receipt.model_construction_count -eq 0 -and
        [int]$receipt.world_attempt_count -eq 0 -and
        [int]$receipt.world_build_count -eq 0 -and
        @($receipt.mutation_failure_codes).Count -eq 14
    ) "QSDK-R23D14 MuJoCo preflight receipt changed"

    $refusal = Invoke-R23D14Mujoco "physical"
    Assert-R23D14Mujoco ([int]$refusal.exit_code -ne 0) (
        "QSDK-R23D14 MuJoCo physical route did not fail closed"
    )
    $failure = Get-R23D14Marker (
        $refusal
    ) "QSDK_R23D14_MUJOCO_TEMPORAL_FAILURE "
    Assert-R23D14Mujoco (
        [string]$failure.failure_stage -ceq "before_model" -and
        [string]$failure.failure_code -ceq
            "QSDK_R23D14_MJC_PHYSICAL_ROUTE_NOT_IMPLEMENTED" -and
        [int]$failure.model_construction_count -eq 0 -and
        [int]$failure.world_build_count -eq 0
    ) "QSDK-R23D14 MuJoCo physical refusal changed"

    $validHash = Get-TextSha256 ([string]$receipt.valid_canary_vector)
    $mutationHash = Get-TextSha256 (
        (@($receipt.mutation_failure_codes) -join "`n")
    )
    Write-Host (
        "QSDK_R23D14_MUJOCO_TEMPORAL_PASS valid=12 mutations=14 " +
        "positive=True negative=True passive_zero=True " +
        "valid_vector_sha256=$validHash mutation_vector_sha256=$mutationHash " +
        "physical_refusals=1 workers=0 models=0 worlds=0 " +
        "physical_authority=False"
    )
}
finally {
    $env:PYTHONPATH = $oldPythonPath
}
