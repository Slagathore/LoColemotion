#requires -Version 7.0

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$sdkRoot = [IO.Path]::GetFullPath($PSScriptRoot)
$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $sdkRoot))
$manifest = Join-Path $sdkRoot "adapters\rapier\Cargo.toml"
$sourcePath = Join-Path (
    $sdkRoot
) "adapters\rapier\src\qsdk_r23d12_measurement_semantics.rs"
$binary = Join-Path $sdkRoot "target\debug\qsdk_r23d12_measurement_semantics.exe"

function Assert-R23D12Rapier([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

function Invoke-R23D12Rapier([string]$Command) {
    $output = & $binary $Command 2>&1 | Out-String
    return [ordered]@{ exit_code = $LASTEXITCODE; output = $output }
}

function Get-R23D12Marker(
    [Collections.IDictionary]$Execution,
    [string]$Prefix
) {
    $matches = @(([string]$Execution.output -split "\r?\n") | Where-Object {
        $_.StartsWith($Prefix, [StringComparison]::Ordinal)
    })
    Assert-R23D12Rapier ($matches.Count -eq 1) (
        "QSDK-R23D12 expected one Rapier marker $Prefix"
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

Assert-R23D12Rapier (
    (git -C $repoRoot rev-parse --show-toplevel).Trim() -ceq
        $repoRoot.Replace("\", "/") -and
    (git -C $repoRoot remote get-url origin).Trim() -ceq
        "https://github.com/Slagathore/sporespore.git"
) "QSDK-R23D12 Rapier repository identity changed"
foreach ($path in @($manifest, $sourcePath)) {
    Assert-R23D12Rapier (Test-Path -LiteralPath $path -PathType Leaf) (
        "QSDK-R23D12 Rapier input missing: $path"
    )
}
$sourceText = [IO.File]::ReadAllText($sourcePath)
Assert-R23D12Rapier (
    -not $sourceText.Contains("sdk/turning", [StringComparison]::Ordinal) -and
    -not $sourceText.Contains("r23d12_measurement_semantics.py", [StringComparison]::Ordinal)
) "QSDK-R23D12 Rapier native implementation imports the reference oracle"

$testOutput = & cargo test --quiet --locked --offline --manifest-path $manifest `
    qsdk_r23d12 2>&1 | Out-String
Assert-R23D12Rapier ($LASTEXITCODE -eq 0) (
    "QSDK-R23D12 Rapier unit tests failed: $testOutput"
)
$buildOutput = & cargo build --quiet --locked --offline --manifest-path $manifest `
    --bin qsdk_r23d12_measurement_semantics 2>&1 | Out-String
Assert-R23D12Rapier (
    $LASTEXITCODE -eq 0 -and (Test-Path -LiteralPath $binary -PathType Leaf)
) "QSDK-R23D12 Rapier binary build failed: $buildOutput"

$execution = Invoke-R23D12Rapier "preflight"
Assert-R23D12Rapier ([int]$execution.exit_code -eq 0) (
    "QSDK-R23D12 Rapier preflight failed: $($execution.output)"
)
$receipt = Get-R23D12Marker (
    $execution
) "QSDK_R23D12_RAPIER_SEMANTICS_PREFLIGHT "
Assert-R23D12Rapier (
    [string]$receipt.engine_id -ceq "rapier_parry" -and
    [string]$receipt.language -ceq "rust" -and
    [int]$receipt.valid_canary_count -eq 7 -and
    [int]$receipt.active_cross_product_count -eq 6 -and
    [int]$receipt.mutation_control_count -eq 14 -and
    [bool]$receipt.critical_r23d11_failure_shape_passed -and
    [bool]$receipt.planner_and_support_margin_availability_are_independent -and
    -not [bool]$receipt.reference_oracle_imported -and
    -not [bool]$receipt.physical_worker_implemented -and
    -not [bool]$receipt.physical_execution_authorized -and
    [int]$receipt.model_construction_count -eq 0 -and
    [int]$receipt.world_attempt_count -eq 0 -and
    [int]$receipt.world_build_count -eq 0 -and
    @($receipt.mutation_failure_codes).Count -eq 14
) "QSDK-R23D12 Rapier preflight receipt changed"

$refusal = Invoke-R23D12Rapier "physical"
Assert-R23D12Rapier ([int]$refusal.exit_code -ne 0) (
    "QSDK-R23D12 Rapier physical route did not fail closed"
)
$failure = Get-R23D12Marker (
    $refusal
) "QSDK_R23D12_RAPIER_SEMANTICS_FAILURE "
Assert-R23D12Rapier (
    [string]$failure.failure_stage -ceq "before_model" -and
    [string]$failure.failure_code -ceq
        "QSDK_R23D12_RAP_PHYSICAL_ROUTE_NOT_IMPLEMENTED" -and
    [int]$failure.model_construction_count -eq 0 -and
    [int]$failure.world_build_count -eq 0
) "QSDK-R23D12 Rapier physical refusal changed"

$validHash = Get-TextSha256 ([string]$receipt.valid_canary_vector)
$crossHash = Get-TextSha256 ([string]$receipt.active_cross_product_vector)
Write-Host (
    "QSDK_R23D12_RAPIER_SEMANTICS_PASS valid=7 cross_product=6 " +
    "mutations=14 critical=True valid_vector_sha256=$validHash " +
    "cross_vector_sha256=$crossHash workers=0 models=0 worlds=0 " +
    "physical_authority=False"
)
