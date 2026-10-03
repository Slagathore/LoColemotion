#requires -Version 7.0

[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$sdkRoot = [IO.Path]::GetFullPath($PSScriptRoot)
$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $sdkRoot))
$manifest = Join-Path $sdkRoot "Cargo.toml"
$binary = Join-Path $sdkRoot "target\release\qsdk_r23d15_physical.exe"
$stageId = "finite_three_engine_confirmation_recovery"
$campaignId = "QSDK-R23D15-PRODUCTION-COMPOSITION-RECOVERY-THREE-ENGINE-TURN-CONFIRMATION"

function Assert-R23D15Rapier([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

function Invoke-R23D15Rapier([string[]]$Arguments, [string]$Label) {
    $output = & $binary @Arguments 2>&1 | Out-String
    return [ordered]@{
        label = $Label
        exit_code = $LASTEXITCODE
        output = $output
    }
}

function Read-R23D15RapierMarker(
    [Collections.IDictionary]$Execution,
    [string]$Prefix
) {
    $matches = @(([string]$Execution.output -split "\r?\n") | Where-Object {
        $_.StartsWith($Prefix, [StringComparison]::Ordinal)
    })
    Assert-R23D15Rapier ($matches.Count -eq 1) (
        "Expected one $Prefix marker from $($Execution.label): $($Execution.output)"
    )
    return $matches[0].Substring($Prefix.Length) |
        ConvertFrom-Json -AsHashtable -Depth 100
}

foreach ($path in @(
    $manifest,
    (Join-Path $sdkRoot "adapters\rapier\src\bin\qsdk_r23d15_physical.rs"),
    (Join-Path $sdkRoot "adapters\rapier\src\qsdk_r23d14_tight_gated_horizon.rs"),
    (Join-Path $sdkRoot "adapters\rapier\src\qsdk_r23d15_composition_recovery.rs"),
    (Join-Path $sdkRoot "adapters\rapier\src\qsdk_r23d3_phase_balanced\r23d15_physical.rs")
)) {
    Assert-R23D15Rapier (Test-Path -LiteralPath $path -PathType Leaf) (
        "Rapier input missing: $path"
    )
}
Assert-R23D15Rapier (
    (git -C $repoRoot rev-parse --show-toplevel).Trim() -ceq $repoRoot.Replace("\", "/") -and
    (git -C $repoRoot remote get-url origin).Trim() -ceq
        "https://github.com/Slagathore/sporespore.git"
) "Rapier repository identity changed"

$testOutput = & cargo test --quiet --locked --offline `
    --manifest-path $manifest --package sporespore-rapier-adapter `
    r23d15_physical --no-fail-fast 2>&1 | Out-String
Assert-R23D15Rapier ($LASTEXITCODE -eq 0) "Rapier tests failed: $testOutput"
& cargo build --quiet --release --locked --offline `
    --manifest-path $manifest --package sporespore-rapier-adapter `
    --bin qsdk_r23d15_physical
Assert-R23D15Rapier ($LASTEXITCODE -eq 0 -and (Test-Path -LiteralPath $binary)) (
    "Rapier worker build failed"
)

$sourceCommit = (git -C $repoRoot rev-parse HEAD).Trim()
foreach ($armId in @("reference_zero", "positive_heading", "negative_heading")) {
    $execution = Invoke-R23D15Rapier @(
        "preflight", "--stage", $stageId, "--arm", $armId
    ) "$stageId`:$armId"
    Assert-R23D15Rapier ($execution.exit_code -eq 0) "Rapier preflight failed: $armId"
    $receipt = Read-R23D15RapierMarker $execution "QSDK_R23D15_RAPIER_PREFLIGHT "
    Assert-R23D15Rapier (
        [string]$receipt.campaign_id -ceq $campaignId -and
        [string]$receipt.cell_id -ceq "rapier_parry__tight_gated_horizon__$armId" -and
        [bool]$receipt.r23d14_tight_gated_horizon_inherited_unchanged -and
        [bool]$receipt.r23d15_composition_recovery_identity_enabled -and
        [bool]$receipt.physical_worker_implemented -and
        -not [bool]$receipt.physical_execution_authorized -and
        [int]$receipt.model_construction_count -eq 0 -and
        [int]$receipt.world_build_count -eq 0
    ) "Rapier preflight receipt changed: $armId"
}

$refusal = Invoke-R23D15Rapier @(
    "physical", "--stage", $stageId, "--arm", "negative_heading",
    "--source-commit", $sourceCommit
) "physical-refusal"
Assert-R23D15Rapier ($refusal.exit_code -ne 0) "Rapier physical route did not refuse"
$terminal = Read-R23D15RapierMarker $refusal "QSDK_R23D15_RAPIER_TERMINAL "
Assert-R23D15Rapier (
    [string]$terminal.failure_code -ceq "QSDK_R23D15_RAP_PHYSICAL_AUTHORIZATION_REQUIRED" -and
    [int]$terminal.world_attempt_count -eq 0 -and
    [int]$terminal.world_build_count -eq 0
) "Rapier physical refusal changed"

Write-Host (
    "QSDK_R23D15_RAPIER_WORKER_PASS identities=3 tests=3 " +
    "temporal_steps=960 models=0 worlds=0 physical_authority=False"
)
