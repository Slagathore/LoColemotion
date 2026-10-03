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
$expectedGodotLauncherSha256 = (
    "c5fc2d0bb24826a6757fa1e6bf2991effb294859c7dd03d09a122ef217484896"
)
$godotPath = [System.IO.Path]::GetFullPath($Godot)
$testPath = Join-Path $repoRoot `
    "tests\test_sdk_balanced_wave_bw27m_material_preflight.gd"
$terminalMarker = (
    "BW27M_MATERIAL_PREFLIGHT_PASS fixtures=4 positive_values=3 " +
    "worlds=0 scene_insertions=0 wrong_value_rejected=true " +
    "locomotion_exposed=false physical_authority=false"
)

if (-not (Test-Path -LiteralPath $godotPath -PathType Leaf)) {
    throw "Godot executable not found: $godotPath"
}
if ((Get-FileHash -LiteralPath $godotPath -Algorithm SHA256).Hash.
    ToLowerInvariant() -cne $expectedGodotLauncherSha256) {
    throw "BW27M pinned Godot executable identity changed: $godotPath"
}
if (-not (Test-Path -LiteralPath $testPath -PathType Leaf)) {
    throw "BW27M material declaration preflight not found: $testPath"
}

$output = (& $godotPath `
    --headless `
    --path $repoRoot `
    --script res://tests/test_sdk_balanced_wave_bw27m_material_preflight.gd `
    2>&1 | Out-String)
$exitCode = $LASTEXITCODE
Write-Host $output.TrimEnd()
if (
    $exitCode -ne 0 -or
    [System.Text.RegularExpressions.Regex]::IsMatch($output, '(?m)^ERROR:') -or
    -not $output.Contains($terminalMarker, [StringComparison]::Ordinal)
) {
    throw "BW27M material declaration preflight failed with exit code $exitCode"
}
