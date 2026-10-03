[CmdletBinding()]
param(
    [string]$Godot = (
        "C:\Users\Cole\CodeStuff\Misc\Godot\" +
        "Godot_v4.7-stable_mono_win64_console.exe"
    )
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = [System.IO.Path]::GetFullPath(
    (Split-Path -Parent $PSScriptRoot)
)
$expectedRoot = [System.IO.Path]::GetFullPath(
    "C:\Users\Cole\CodeStuff\games\SporeSpore"
)
$expectedRemote = "https://github.com/Slagathore/sporespore.git"

if ($repoRoot -cne $expectedRoot) {
    throw "QSDK-R23D65 Godot route repository root changed: $repoRoot"
}
$gitRoot = [System.IO.Path]::GetFullPath(
    (& git -C $repoRoot rev-parse --show-toplevel).Trim()
)
if ($LASTEXITCODE -ne 0 -or $gitRoot -cne $expectedRoot) {
    throw "QSDK-R23D65 Godot route canonical Git root changed: $gitRoot"
}
$remote = (& git -C $repoRoot remote get-url origin).Trim()
if ($LASTEXITCODE -ne 0 -or $remote -cne $expectedRemote) {
    throw "QSDK-R23D65 Godot route origin changed: $remote"
}

$godotPath = [System.IO.Path]::GetFullPath($Godot)
if (-not (Test-Path -LiteralPath $godotPath -PathType Leaf)) {
    throw "QSDK-R23D65 Godot runtime not found: $godotPath"
}
$auditPath = Join-Path (
    $repoRoot
) "tests\test_qsdk_r23d65_godot_public_profile_physical_route.py"

& python $auditPath --godot $godotPath
if ($LASTEXITCODE -ne 0) {
    throw (
        "QSDK-R23D65 Godot public-profile route audit failed with exit code " +
        "$LASTEXITCODE"
    )
}
