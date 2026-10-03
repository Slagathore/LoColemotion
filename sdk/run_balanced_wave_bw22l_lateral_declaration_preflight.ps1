[CmdletBinding()]
param(
    [string]$Godot = (
        "C:\Users\Cole\CodeStuff\Misc\Godot\" +
        "Godot_v4.7-stable_mono_win64_console.exe"
    )
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$sdkRoot = [System.IO.Path]::GetFullPath($PSScriptRoot)
$repoRoot = [System.IO.Path]::GetFullPath((Split-Path -Parent $sdkRoot))
$godotPath = [System.IO.Path]::GetFullPath($Godot)
$expectedGodotSha256 =
    "c5fc2d0bb24826a6757fa1e6bf2991effb294859c7dd03d09a122ef217484896"
$gateTestPath = Join-Path (
    $repoRoot
) "tests\test_bw22l_lateral_development_gate.ps1"
$authorityTestPath = Join-Path (
    $repoRoot
) "tests\test_sdk_balanced_wave_bw22l_authority_contract.gd"
$receiptRunnerPath = Join-Path (
    $sdkRoot
) "run_policy_aware_physical_receipt_composition_preflight.ps1"
$gateMarker = (
    "BW22L_LATERAL_DEVELOPMENT_GATE_PASS gates=50 cells=28 " +
    "candidates=24 controls=3 safety=1 canaries=23 roundtrip=True " +
    "tie_selects_none=True paired_regression_selects_none=True worlds=0 " +
    "development_only=True validation_authority=False physical_authority=False"
)
$authorityMarker = (
    "BW22L_AUTHORITY_PASS candidates=2 materials=3 controls=1 " +
    "worlds=0 branch_surfaces=0 physical_authority=False"
)
$receiptMarker = (
    "POLICY_AWARE_PHYSICAL_RECEIPT_COMPOSITION_PASS " +
    "summaries=5 candidates=4 controls=1 historical_canaries=3 " +
    "mismatch_canaries=5 worlds=0 physical_authority=False"
)

function Assert-Exact {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function Invoke-Captured {
    param(
        [Parameter(Mandatory)][scriptblock]$Operation,
        [Parameter(Mandatory)][string]$TerminalMarker,
        [Parameter(Mandatory)][string]$Label
    )
    $output = (& $Operation 2>&1 | Out-String)
    $exitCode = $LASTEXITCODE
    Write-Host $output.TrimEnd()
    Assert-Exact (
        $exitCode -eq 0 -and
        -not [System.Text.RegularExpressions.Regex]::IsMatch(
            $output,
            '(?m)^ERROR:'
        ) -and
        $output.Contains($TerminalMarker, [StringComparison]::Ordinal)
    ) "BW22L $Label failed with exit code $exitCode"
}

Assert-Exact (
    (Test-Path -LiteralPath $godotPath -PathType Leaf) -and
    (Get-FileHash -LiteralPath $godotPath -Algorithm SHA256).Hash.ToLowerInvariant() -ceq
        $expectedGodotSha256
) "BW22L pinned Godot executable is missing or changed: $godotPath"
foreach ($path in @($gateTestPath, $authorityTestPath, $receiptRunnerPath)) {
    Assert-Exact (
        Test-Path -LiteralPath $path -PathType Leaf
    ) "BW22L declaration preflight dependency is missing: $path"
}

Invoke-Captured `
    -Operation {
        & pwsh -NoLogo -NoProfile -File $gateTestPath
    } `
    -TerminalMarker $gateMarker `
    -Label "complete synthetic evaluator"

Invoke-Captured `
    -Operation {
        & $godotPath `
            --headless `
            --path $repoRoot `
            --script res://tests/test_sdk_balanced_wave_bw22l_authority_contract.gd
    } `
    -TerminalMarker $authorityMarker `
    -Label "native candidate/material authority contract"

Invoke-Captured `
    -Operation {
        & pwsh `
            -NoLogo `
            -NoProfile `
            -File $receiptRunnerPath `
            -Godot $godotPath
    } `
    -TerminalMarker $receiptMarker `
    -Label "policy-aware receipt composition"

Write-Host (
    "BW22L_DECLARATION_PREFLIGHT_PASS candidates=2 materials=3 seeds=4 " +
    "planned_worlds=28 gates=50 canaries=23 worlds_opened=0 " +
    "selector_invocations=0 physical_authority=False"
)
