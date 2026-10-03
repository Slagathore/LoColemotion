[CmdletBinding()]
param(
    [string]$Python = ""
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
    throw "QSDK-R23D62 MuJoCo route repository root changed: $repoRoot"
}
$gitRoot = [System.IO.Path]::GetFullPath(
    (& git -C $repoRoot rev-parse --show-toplevel).Trim()
)
if ($LASTEXITCODE -ne 0 -or $gitRoot -cne $expectedRoot) {
    throw "QSDK-R23D62 MuJoCo route canonical Git root changed: $gitRoot"
}
$remote = (& git -C $repoRoot remote get-url origin).Trim()
if ($LASTEXITCODE -ne 0 -or $remote -cne $expectedRemote) {
    throw "QSDK-R23D62 MuJoCo route origin changed: $remote"
}

if ([string]::IsNullOrWhiteSpace($Python)) {
    $Python = Join-Path (
        $repoRoot
    ) "sdk\adapters\mujoco\.venv\Scripts\python.exe"
}
if (-not (Test-Path -LiteralPath $Python -PathType Leaf)) {
    throw "QSDK-R23D62 MuJoCo pinned Python is missing: $Python"
}
$auditPath = Join-Path (
    $repoRoot
) "tests\test_qsdk_r23d62_mujoco_public_profile_physical_route.py"

& $Python $auditPath --repo-root $repoRoot
if ($LASTEXITCODE -ne 0) {
    throw (
        "QSDK-R23D62 MuJoCo public-profile route audit failed with exit code " +
        "$LASTEXITCODE"
    )
}
