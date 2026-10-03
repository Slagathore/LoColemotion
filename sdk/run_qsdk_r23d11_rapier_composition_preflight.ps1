#requires -Version 7.0

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$sdkRoot = [IO.Path]::GetFullPath($PSScriptRoot)
$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $sdkRoot))
$manifest = Join-Path $sdkRoot "adapters\rapier\Cargo.toml"
$binary = Join-Path $sdkRoot "target\debug\qsdk_r23d11_stability_assisted_taper.exe"

function Assert-R23D11Rapier([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

function Invoke-R23D11Rapier([string[]]$Arguments) {
    $output = & $binary @Arguments 2>&1 | Out-String
    return [ordered]@{ exit_code = $LASTEXITCODE; output = $output }
}

function Get-R23D11RapierMarker(
    [Collections.IDictionary]$Execution,
    [string]$Prefix
) {
    $matches = @(([string]$Execution.output -split "\r?\n") | Where-Object {
        $_.StartsWith($Prefix, [StringComparison]::Ordinal)
    })
    Assert-R23D11Rapier ($matches.Count -eq 1) (
        "QSDK-R23D11 expected one Rapier marker $Prefix"
    )
    return $matches[0].Substring($Prefix.Length) |
        ConvertFrom-Json -AsHashtable -Depth 100
}

Assert-R23D11Rapier (
    (git -C $repoRoot rev-parse --show-toplevel).Trim() -ceq
        $repoRoot.Replace("\", "/") -and
    (git -C $repoRoot remote get-url origin).Trim() -ceq
        "https://github.com/Slagathore/sporespore.git"
) "QSDK-R23D11 Rapier repository identity changed"

$testOutput = & cargo test --quiet --locked --offline --manifest-path $manifest qsdk_r23d11 2>&1 |
    Out-String
Assert-R23D11Rapier ($LASTEXITCODE -eq 0) (
    "QSDK-R23D11 Rapier unit tests failed: $testOutput"
)
$buildOutput = & cargo build --quiet --locked --offline --manifest-path $manifest `
    --bin qsdk_r23d11_stability_assisted_taper 2>&1 | Out-String
Assert-R23D11Rapier (
    $LASTEXITCODE -eq 0 -and (Test-Path -LiteralPath $binary -PathType Leaf)
) "QSDK-R23D11 Rapier binary build failed: $buildOutput"

foreach ($arm in @("reference_zero", "positive_heading", "negative_heading")) {
    $execution = Invoke-R23D11Rapier @(
        "preflight", "--stage", "three_engine_confirmation", "--arm", $arm
    )
    Assert-R23D11Rapier ([int]$execution.exit_code -eq 0) (
        "QSDK-R23D11 Rapier preflight failed: $($execution.output)"
    )
    $receipt = Get-R23D11RapierMarker (
        $execution
    ) "QSDK_R23D11_RAPIER_PREFLIGHT "
    Assert-R23D11Rapier (
        [string]$receipt.engine_id -ceq "rapier_parry" -and
        [string]$receipt.arm_id -ceq $arm -and
        [int]$receipt.composition_canary_count -eq 7 -and
        [int]$receipt.mutation_control_count -eq 18 -and
        [int]$receipt.inherited_temporal_canary_count -eq 5 -and
        [bool]$receipt.native_composition_mirror -and
        -not [bool]$receipt.physical_worker_implemented -and
        -not [bool]$receipt.physical_execution_authorized -and
        [int]$receipt.model_construction_count -eq 0 -and
        [int]$receipt.world_attempt_count -eq 0 -and
        [int]$receipt.world_build_count -eq 0
    ) "QSDK-R23D11 Rapier preflight receipt changed"
}

$refusal = Invoke-R23D11Rapier @(
    "physical", "--stage", "three_engine_confirmation", "--arm", "positive_heading"
)
Assert-R23D11Rapier ([int]$refusal.exit_code -ne 0) (
    "QSDK-R23D11 Rapier physical command did not fail closed"
)
$failure = Get-R23D11RapierMarker $refusal "QSDK_R23D11_RAPIER_FAILURE "
Assert-R23D11Rapier (
    [string]$failure.failure_stage -ceq "before_model" -and
    [string]$failure.failure_code -ceq
        "QSDK_R23D11_RAP_PHYSICAL_ROUTE_NOT_IMPLEMENTED" -and
    [int]$failure.model_construction_count -eq 0 -and
    [int]$failure.world_build_count -eq 0
) "QSDK-R23D11 Rapier physical refusal changed"

Write-Host (
    "QSDK_R23D11_RAPIER_COMPOSITION_PASS identities=3 canaries=7 " +
    "mutations=18 temporal_canaries=5 workers=0 models=0 worlds=0 " +
    "physical_authority=False"
)
