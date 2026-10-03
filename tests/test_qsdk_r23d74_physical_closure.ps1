#requires -Version 7.0

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$sourceCommit = "32b9db7f67c15f72181a5e5ac8a412e5f7a51a57"
$evidenceRoot = [IO.Path]::GetFullPath(
    "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence\qsdk-r23d74-physical-20260826T113149Z-32b9db7f-lca1-system-python"
)
$retainedCasRoot = [IO.Path]::GetFullPath(
    "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence\artifacts\sha256"
)
$materializer = Join-Path $repoRoot "sdk\turning\materialize_r23d74_physical_closure.py"
$python = "C:\Program Files\Python311\python.exe"

if (
    (git -C $repoRoot rev-parse --show-toplevel).Trim() -cne $repoRoot.Replace("\", "/") -or
    (git -C $repoRoot remote get-url origin).Trim() -cne
        "https://github.com/Slagathore/sporespore.git" -or
    (git -C $repoRoot cat-file -t "$sourceCommit`:sdk/run_qsdk_r23d74_supervisor.ps1").Trim() -cne
        "blob" -or
    -not (Test-Path -LiteralPath $evidenceRoot -PathType Container) -or
    -not (Test-Path -LiteralPath $retainedCasRoot -PathType Container) -or
    -not (Test-Path -LiteralPath $materializer -PathType Leaf)
) {
    throw "R23D74 closure pinned Git blob, retained evidence, or CAS authority is unavailable"
}

& $python $materializer --audit
if ($LASTEXITCODE -ne 0) {
    throw "R23D74 physical closure audit failed with exit code $LASTEXITCODE"
}
