#requires -Version 7.0

[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$sdkRoot = [IO.Path]::GetFullPath($PSScriptRoot)
$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $sdkRoot))
$manifest = Join-Path $sdkRoot "adapters\rapier\Cargo.toml"
$binary = Join-Path $sdkRoot "target\debug\qsdk_r23d11_stability_assisted_taper.exe"
$campaignId = (
    "QSDK-R23D11-SUPPORT-CENTROID-ASSISTED-QUIESCENT-TAPER-" +
    "BILATERAL-TURN-DEVELOPMENT"
)
function Assert-R23D11Rapier([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

function Invoke-R23D11Rapier {
    param(
        [Parameter(Mandatory)][string[]]$Arguments,
        [Parameter(Mandatory)][string]$Label
    )
    $output = & $binary @Arguments 2>&1 | Out-String
    return [ordered]@{
        label = $Label
        exit_code = $LASTEXITCODE
        output = $output
    }
}

function Get-R23D11RapierMarker {
    param(
        [Parameter(Mandatory)][Collections.IDictionary]$Execution,
        [Parameter(Mandatory)][string]$Prefix
    )
    $markers = @(([string]$Execution.output -split "\r?\n") | Where-Object {
        $_.StartsWith($Prefix, [StringComparison]::Ordinal)
    })
    Assert-R23D11Rapier ($markers.Count -eq 1) (
        "QSDK-R23D11 expected one $Prefix marker from $($Execution.label)"
    )
    return $markers[0].Substring($Prefix.Length) |
        ConvertFrom-Json -AsHashtable -Depth 100
}

foreach ($path in @(
    $manifest,
    (Join-Path $sdkRoot "adapters\rapier\src\qsdk_r23d3_phase_balanced.rs"),
    (Join-Path $sdkRoot "adapters\rapier\src\qsdk_r23d3_phase_balanced\r23d11_physical.rs"),
    (Join-Path $sdkRoot "adapters\rapier\src\qsdk_r23d11_stability_assisted_taper.rs"),
    (Join-Path $sdkRoot "adapters\rapier\src\bin\qsdk_r23d11_stability_assisted_taper.rs")
)) {
    Assert-R23D11Rapier (Test-Path -LiteralPath $path -PathType Leaf) (
        "QSDK-R23D11 Rapier input missing: $path"
    )
}
Assert-R23D11Rapier (
    (git -C $repoRoot rev-parse --show-toplevel).Trim() -ceq
        $repoRoot.Replace("\", "/") -and
    (git -C $repoRoot remote get-url origin).Trim() -ceq
        "https://github.com/Slagathore/sporespore.git"
) "QSDK-R23D11 Rapier repository identity changed"
$sourceCommit = (git -C $repoRoot rev-parse HEAD).Trim()

$testArguments = @(
    "test", "--quiet", "--locked", "--offline",
    "--manifest-path", $manifest,
    "qsdk_r23d11_stability_assisted_taper"
)
$testOutput = & cargo @testArguments 2>&1 | Out-String
Assert-R23D11Rapier ($LASTEXITCODE -eq 0) (
    "QSDK-R23D11 Rapier unit tests failed: $testOutput"
)
$buildArguments = @(
    "build", "--quiet", "--locked", "--offline",
    "--manifest-path", $manifest,
    "--bin", "qsdk_r23d11_stability_assisted_taper"
)
$buildOutput = & cargo @buildArguments 2>&1 | Out-String
Assert-R23D11Rapier (
    $LASTEXITCODE -eq 0 -and
    (Test-Path -LiteralPath $binary -PathType Leaf)
) "QSDK-R23D11 Rapier binary build failed: $buildOutput"

foreach ($arm in @("reference_zero", "positive_heading", "negative_heading")) {
    $execution = Invoke-R23D11Rapier -Label $arm -Arguments @(
        "preflight", "--stage", "three_engine_confirmation", "--arm", $arm
    )
    Assert-R23D11Rapier ([int]$execution.exit_code -eq 0) (
        "QSDK-R23D11 Rapier preflight failed: $arm; $($execution.output)"
    )
    $receipt = Get-R23D11RapierMarker $execution "QSDK_R23D11_RAPIER_PREFLIGHT "
    Assert-R23D11Rapier (
        [string]$receipt.schema_version -ceq
            "sporespore_qsdk_r23d11_rapier_composition_preflight_v1" -and
        [string]$receipt.campaign_id -ceq $campaignId -and
        [string]$receipt.engine_id -ceq "rapier_parry" -and
        [string]$receipt.arm_id -ceq $arm -and
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
    ) "QSDK-R23D11 Rapier receipt changed: $arm"
}

$authorizationEnvironmentNames = @(
    "SPORESPORE_QSDK_R23D11_FREEZE",
    "SPORESPORE_QSDK_R23D11_ATTEMPT",
    "SPORESPORE_QSDK_R23D11_TOKEN",
    "SPORESPORE_QSDK_R23D11_STAGE",
    "SPORESPORE_QSDK_R23D11_CELL",
    "SPORESPORE_QSDK_R23D11_ENGINE",
    "SPORESPORE_QSDK_R23D11_ATTEMPT_ROOT"
)
$savedAuthorizationEnvironment = @{}
try {
    foreach ($name in $authorizationEnvironmentNames) {
        $savedAuthorizationEnvironment[$name] = [Environment]::GetEnvironmentVariable(
            $name, "Process"
        )
        [Environment]::SetEnvironmentVariable($name, $null, "Process")
    }
    $bypass = Invoke-R23D11Rapier -Label "physical-refusal" -Arguments @(
        "physical", "--stage", "three_engine_confirmation", "--arm", "positive_heading",
        "--source-commit", $sourceCommit
    )
} finally {
    foreach ($name in $authorizationEnvironmentNames) {
        [Environment]::SetEnvironmentVariable(
            $name, $savedAuthorizationEnvironment[$name], "Process"
        )
    }
}
Assert-R23D11Rapier ([int]$bypass.exit_code -ne 0) (
    "QSDK-R23D11 Rapier physical route did not fail closed"
)
$terminal = Get-R23D11RapierMarker $bypass "QSDK_R23D11_RAPIER_TERMINAL "
Assert-R23D11Rapier (
    [string]$terminal.failure_stage -ceq "before_world" -and
    [string]$terminal.failure_code -ceq
        "QSDK_R23D11_RAP_PHYSICAL_AUTHORIZATION_REQUIRED" -and
    [int]$terminal.world_attempt_count -eq 0 -and
    [int]$terminal.world_build_count -eq 0
) "QSDK-R23D11 Rapier physical refusal changed"

Write-Host (
    "QSDK_R23D11_RAPIER_NATIVE_ROUTE_PASS identities=3 canaries=7 " +
    "mutations=18 temporal_canaries=5 physical_worker=True dormant=True models=0 worlds=0 " +
    "physical_authority=False"
)
