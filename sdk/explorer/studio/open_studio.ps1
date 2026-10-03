[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Config,
    [Parameter(Mandatory)][string]$EvidenceRoot,
    [string]$Python = 'C:/Program Files/Python311/python.exe'
)
$ErrorActionPreference = 'Stop'
if (-not (Test-Path -LiteralPath $Config -PathType Leaf)) { throw "Dependency configuration missing: $Config" }
if (-not (Test-Path -LiteralPath $Python -PathType Leaf)) { throw "Python executable missing: $Python" }
Push-Location $PSScriptRoot
try {
    & $Python -B -X utf8 (Join-Path $PSScriptRoot 'studio_owner.py') --config $Config --evidence-root $EvidenceRoot
    if ($LASTEXITCODE -ne 0) { throw "Studio exited with code $LASTEXITCODE; inspect the retained session under $EvidenceRoot" }
} finally { Pop-Location }
