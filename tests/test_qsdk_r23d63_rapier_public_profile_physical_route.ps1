[CmdletBinding()]
param(
    [string]$Python = "python"
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
    throw "QSDK-R23D63 Rapier route repository root changed: $repoRoot"
}
$gitRoot = [System.IO.Path]::GetFullPath(
    (& git -C $repoRoot rev-parse --show-toplevel).Trim()
)
if ($LASTEXITCODE -ne 0 -or $gitRoot -cne $expectedRoot) {
    throw "QSDK-R23D63 Rapier route canonical Git root changed: $gitRoot"
}
$remote = (& git -C $repoRoot remote get-url origin).Trim()
if ($LASTEXITCODE -ne 0 -or $remote -cne $expectedRemote) {
    throw "QSDK-R23D63 Rapier route origin changed: $remote"
}

$auditPath = Join-Path (
    $repoRoot
) "tests\test_qsdk_r23d63_rapier_public_profile_physical_route.py"

& $Python $auditPath --repo-root $repoRoot
if ($LASTEXITCODE -ne 0) {
    throw (
        "QSDK-R23D63 Rapier public-profile route audit failed with exit code " +
        "$LASTEXITCODE"
    )
}
