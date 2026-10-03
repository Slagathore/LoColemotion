[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Config,
    [Parameter(Mandatory)][string]$Output,
    [string]$Python = 'C:/Program Files/Python311/python.exe'
)
$ErrorActionPreference = 'Stop'
# Works from an isolated SDK directory; no Git or game project is needed.
$sdkRoot = Split-Path $PSScriptRoot -Parent
if (-not (Test-Path -LiteralPath $Python -PathType Leaf)) { throw "Python executable not found: $Python" }
if (-not (Test-Path -LiteralPath $Config -PathType Leaf)) { throw "Dependency configuration not found: $Config" }
Push-Location $sdkRoot
try {
    & $Python -B -X utf8 (Join-Path $PSScriptRoot 'showcase_owner.py') --config $Config --output $Output
    if ($LASTEXITCODE -ne 0) { throw "Explorer exited with code $LASTEXITCODE; see the retained UI and native logs in $Output" }
} finally { Pop-Location }
