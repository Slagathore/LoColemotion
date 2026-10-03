#requires -Version 7.0

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$sourceCommit = "23358ebbc21fa4ddd5208c22a46b21e6abf8c4dc"
$evidenceRoot = [IO.Path]::GetFullPath(
    "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence\qsdk-r23d68-physical-20260826T013723Z-23358ebb"
)
$retainedCasRoot = [IO.Path]::GetFullPath(
    "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence\artifacts\sha256"
)
$materializer = Join-Path $repoRoot "sdk\turning\materialize_r23d68_physical_closure.py"
$python = "C:\Program Files\Python311\python.exe"

if (
    (git -C $repoRoot rev-parse --show-toplevel).Trim() -cne $repoRoot.Replace("\", "/") -or
    (git -C $repoRoot remote get-url origin).Trim() -cne
        "https://github.com/Slagathore/sporespore.git" -or
    (git -C $repoRoot cat-file -t "$sourceCommit`:sdk/run_qsdk_r23d68_supervisor.ps1").Trim() -cne
        "blob" -or
    -not (Test-Path -LiteralPath $evidenceRoot -PathType Container) -or
    -not (Test-Path -LiteralPath $retainedCasRoot -PathType Container) -or
    -not (Test-Path -LiteralPath $materializer -PathType Leaf)
) {
    throw "R23D68 closure pinned Git blob, retained evidence, or CAS authority is unavailable"
}

& $python $materializer --audit
if ($LASTEXITCODE -ne 0) {
    throw "R23D68 physical closure audit failed with exit code $LASTEXITCODE"
}
