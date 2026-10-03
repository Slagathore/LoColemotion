#requires -Version 7.0

[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$sdkRoot = [IO.Path]::GetFullPath($PSScriptRoot)
$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $sdkRoot))
$manifest = Join-Path $sdkRoot "adapters\rapier\Cargo.toml"
$binary = Join-Path $sdkRoot "target\debug\qsdk_r23d9_support_handoff.exe"
$campaignId = (
    "QSDK-R23D9-SUPPORT-CONFIRMED-ACTIVE-TO-PASSIVE-HANDOFF-" +
    "BILATERAL-TURN-DEVELOPMENT"
)

function Assert-R23D9Rapier([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

function Invoke-R23D9Rapier {
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

function Get-R23D9RapierMarker {
    param(
        [Parameter(Mandatory)][Collections.IDictionary]$Execution,
        [Parameter(Mandatory)][string]$Prefix
    )
    $markers = @(([string]$Execution.output -split "\r?\n") | Where-Object {
        $_.StartsWith($Prefix, [StringComparison]::Ordinal)
    })
    Assert-R23D9Rapier ($markers.Count -eq 1) (
        "QSDK-R23D9 expected one $Prefix marker from $($Execution.label)"
    )
    return $markers[0].Substring($Prefix.Length) |
        ConvertFrom-Json -AsHashtable -Depth 100
}

foreach ($path in @(
    $manifest,
    (Join-Path $sdkRoot "adapters\rapier\src\qsdk_r23d3_phase_balanced.rs"),
    (Join-Path $sdkRoot "adapters\rapier\src\qsdk_r23d9_support_handoff.rs"),
    (Join-Path $sdkRoot "adapters\rapier\src\bin\qsdk_r23d9_support_handoff.rs")
)) {
    Assert-R23D9Rapier (Test-Path -LiteralPath $path -PathType Leaf) (
        "QSDK-R23D9 Rapier input missing: $path"
    )
}
Assert-R23D9Rapier (
    (git -C $repoRoot rev-parse --show-toplevel).Trim() -ceq
        $repoRoot.Replace("\", "/") -and
    (git -C $repoRoot remote get-url origin).Trim() -ceq
        "https://github.com/Slagathore/sporespore.git"
) "QSDK-R23D9 Rapier repository identity changed"
$sourceCommit = (git -C $repoRoot rev-parse HEAD).Trim()

$testArguments = @(
    "test", "--quiet", "--locked", "--offline",
    "--manifest-path", $manifest,
    "qsdk_r23d9_support_handoff"
)
$testOutput = & cargo @testArguments 2>&1 | Out-String
Assert-R23D9Rapier ($LASTEXITCODE -eq 0) (
    "QSDK-R23D9 Rapier unit tests failed: $testOutput"
)
$buildArguments = @(
    "build", "--quiet", "--locked", "--offline",
    "--manifest-path", $manifest,
    "--bin", "qsdk_r23d9_support_handoff"
)
$buildOutput = & cargo @buildArguments 2>&1 | Out-String
Assert-R23D9Rapier (
    $LASTEXITCODE -eq 0 -and
    (Test-Path -LiteralPath $binary -PathType Leaf)
) "QSDK-R23D9 Rapier binary build failed: $buildOutput"

foreach ($arm in @("reference_zero", "positive_heading", "negative_heading")) {
    $execution = Invoke-R23D9Rapier -Label $arm -Arguments @(
        "preflight", "--stage", "three_engine_confirmation", "--arm", $arm
    )
    Assert-R23D9Rapier ([int]$execution.exit_code -eq 0) (
        "QSDK-R23D9 Rapier preflight failed: $arm; $($execution.output)"
    )
    $receipt = Get-R23D9RapierMarker $execution "QSDK_R23D9_RAPIER_PREFLIGHT "
    Assert-R23D9Rapier (
        [string]$receipt.schema_version -ceq
            "sporespore_qsdk_r23d9_rapier_worker_preflight_v1" -and
        [string]$receipt.campaign_id -ceq $campaignId -and
        [string]$receipt.engine_id -ceq "rapier_parry" -and
        [string]$receipt.arm_id -ceq $arm -and
        [int]$receipt.fixed_controller_horizon_step_count -eq 2992 -and
        [int]$receipt.fixed_terminal_handoff_step_count -eq 780 -and
        [int]$receipt.fixed_total_trace_step_count -eq 3772 -and
        [int]$receipt.maximum_active_neutral_acquisition_step_count -eq 420 -and
        [int]$receipt.support_confirmation_step_count -eq 30 -and
        [int]$receipt.minimum_post_handoff_zero_actuation_step_count -eq 360 -and
        [int]$receipt.support_handoff_oracle_canary_count -eq 5 -and
        [int]$receipt.support_handoff_mutation_control_count -eq 12 -and
        [bool]$receipt.native_temporal_mirror -and
        [bool]$receipt.physical_worker_implemented -and
        [bool]$receipt.physical_worker_dormant_behind_supervisor_authorization -and
        [int]$receipt.model_construction_count -eq 0 -and
        [int]$receipt.world_attempt_count -eq 0 -and
        [int]$receipt.world_build_count -eq 0 -and
        -not [bool]$receipt.physical_execution_authorized
    ) "QSDK-R23D9 Rapier receipt changed: $arm"
}

$authorizationEnvironmentNames = @(
    "SPORESPORE_QSDK_R23D9_FREEZE",
    "SPORESPORE_QSDK_R23D9_ATTEMPT",
    "SPORESPORE_QSDK_R23D9_TOKEN",
    "SPORESPORE_QSDK_R23D9_STAGE",
    "SPORESPORE_QSDK_R23D9_CELL",
    "SPORESPORE_QSDK_R23D9_ENGINE",
    "SPORESPORE_QSDK_R23D9_ATTEMPT_ROOT"
)
$savedAuthorizationEnvironment = @{}
try {
    foreach ($name in $authorizationEnvironmentNames) {
        $savedAuthorizationEnvironment[$name] = [Environment]::GetEnvironmentVariable(
            $name, "Process"
        )
        [Environment]::SetEnvironmentVariable($name, $null, "Process")
    }
    $bypass = Invoke-R23D9Rapier -Label "physical-refusal" -Arguments @(
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
Assert-R23D9Rapier ([int]$bypass.exit_code -ne 0) (
    "QSDK-R23D9 Rapier physical route did not fail closed"
)
$terminal = Get-R23D9RapierMarker $bypass "QSDK_R23D9_RAPIER_TERMINAL "
Assert-R23D9Rapier (
    [string]$terminal.failure_stage -ceq "before_world" -and
    [string]$terminal.failure_code -ceq
        "QSDK_R23D9_RAP_PHYSICAL_AUTHORIZATION_REQUIRED" -and
    [int]$terminal.world_attempt_count -eq 0 -and
    [int]$terminal.world_build_count -eq 0
) "QSDK-R23D9 Rapier physical refusal changed"

Write-Host (
    "QSDK_R23D9_RAPIER_NATIVE_ROUTE_PASS identities=3 canaries=5 " +
    "mutations=12 physical_worker=True dormant=True models=0 worlds=0 " +
    "physical_authority=False"
)
