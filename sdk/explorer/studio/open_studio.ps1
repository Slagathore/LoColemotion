[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Config,
    [Parameter(Mandatory)][string]$EvidenceRoot,
    [Parameter(Mandatory)][string]$Python,
    [switch]$SelfTest,
    [switch]$Headless
)
$ErrorActionPreference = 'Stop'
if (-not (Test-Path -LiteralPath $Config -PathType Leaf)) { throw "Dependency configuration missing: $Config" }
if (-not (Test-Path -LiteralPath $Python -PathType Leaf)) { throw "Python executable missing: $Python" }
Push-Location $PSScriptRoot
try {
    $arguments = @('-B', '-X', 'utf8', (Join-Path $PSScriptRoot 'studio_owner.py'), '--config', $Config, '--evidence-root', $EvidenceRoot, '--mujoco-python', $Python)
    if ($SelfTest) { $arguments += '--ui-self-test' }
    if ($Headless) { $arguments += '--headless-ui' }
    & $Python @arguments
    if ($LASTEXITCODE -ne 0) { throw "Studio exited with code $LASTEXITCODE; inspect the retained session under $EvidenceRoot" }
} finally { Pop-Location }
