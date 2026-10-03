[CmdletBinding()]
param(
    [string]$Python = (
        Join-Path $PSScriptRoot "adapters\mujoco\.venv\Scripts\python.exe"
    ),
    [string]$Output = ""
)

$ErrorActionPreference = "Stop"
$sdkRoot = [System.IO.Path]::GetFullPath($PSScriptRoot)
$adapterRoot = Join-Path $sdkRoot "adapters\mujoco"
$pythonPath = [System.IO.Path]::GetFullPath($Python)

if (-not (Test-Path -LiteralPath $pythonPath -PathType Leaf)) {
    throw (
        "MuJoCo Python environment not found: $pythonPath`n" +
        "Create it with python -m venv .\sdk\adapters\mujoco\.venv, then " +
        "install sdk\adapters\mujoco\requirements-lock.txt."
    )
}

Push-Location -LiteralPath $sdkRoot
try {
    & cargo build `
        --package sporespore-locomotion-core `
        --release `
        --offline
    if ($LASTEXITCODE -ne 0) {
        throw "Portable core release build failed with exit code $LASTEXITCODE"
    }
} finally {
    Pop-Location
}

Push-Location -LiteralPath $adapterRoot
try {
    & $pythonPath -m py_compile `
        "sporespore_mujoco_adapter\__init__.py" `
        "sporespore_mujoco_adapter\conformance.py" `
        "sporespore_mujoco_adapter\selected_policy_development.py" `
        "sporespore_mujoco_adapter\selected_policy_walking_mv1.py" `
        "sporespore_mujoco_adapter\s169_force_limit_characterization_vh5.py" `
        "sporespore_mujoco_adapter\velocity_only_stability_characterization_vh4.py" `
        "test_conformance.py"
    if ($LASTEXITCODE -ne 0) {
        throw "MuJoCo adapter compilation failed with exit code $LASTEXITCODE"
    }

    & $pythonPath -m unittest -v
    if ($LASTEXITCODE -ne 0) {
        throw "MuJoCo adapter tests failed with exit code $LASTEXITCODE"
    }

    if ([string]::IsNullOrWhiteSpace($Output)) {
        & $pythonPath -m sporespore_mujoco_adapter.conformance
    } else {
        $outputPath = [System.IO.Path]::GetFullPath($Output)
        & $pythonPath `
            -m sporespore_mujoco_adapter.conformance `
            --output $outputPath
    }
    if ($LASTEXITCODE -ne 0) {
        throw "MuJoCo C0-C5 conformance failed with exit code $LASTEXITCODE"
    }
} finally {
    Pop-Location
}

Write-Host "MuJoCo SDK C0-C5 conformance passed."
