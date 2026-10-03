[CmdletBinding()]
param(
    [string]$Output = "",
    [switch]$SkipBuild
)

$ErrorActionPreference = "Stop"
$sdkRoot = [System.IO.Path]::GetFullPath($PSScriptRoot)
$contractPath = Join-Path (
    $sdkRoot
) "adaptation_provider\provider_contract_v1.json"
$coreLibraryPath = Join-Path (
    $sdkRoot
) "target\release\sporespore_locomotion_core.dll"

function Assert-Exact {
    param(
        [bool]$Condition,
        [string]$Message
    )
    if (-not $Condition) {
        throw $Message
    }
}

Assert-Exact (
    Test-Path -LiteralPath $contractPath -PathType Leaf
) "Adaptation-provider contract is missing: $contractPath"
Get-Content -Raw -LiteralPath $contractPath | ConvertFrom-Json | Out-Null

if (-not $SkipBuild) {
    & cargo build `
        --manifest-path (Join-Path $sdkRoot "Cargo.toml") `
        --workspace `
        --release `
        --offline
    Assert-Exact (
        $LASTEXITCODE -eq 0
    ) "Adaptation-provider release build failed with exit code $LASTEXITCODE"
}
Assert-Exact (
    Test-Path -LiteralPath $coreLibraryPath -PathType Leaf
) "Release core library is missing: $coreLibraryPath"

$previousLibrary = [Environment]::GetEnvironmentVariable(
    "SPORESPORE_LOCOMOTION_LIBRARY",
    "Process"
)
[Environment]::SetEnvironmentVariable(
    "SPORESPORE_LOCOMOTION_LIBRARY",
    $coreLibraryPath,
    "Process"
)
try {
    Push-Location -LiteralPath $sdkRoot
    try {
        & python -m unittest -v adaptation_provider.test_conformance
        Assert-Exact (
            $LASTEXITCODE -eq 0
        ) "Adaptation-provider conformance tests failed with exit code $LASTEXITCODE"

        $arguments = @("-m", "adaptation_provider.conformance")
        if (-not [string]::IsNullOrWhiteSpace($Output)) {
            $outputPath = [System.IO.Path]::GetFullPath($Output)
            Assert-Exact (
                [System.IO.Path]::GetFileName($outputPath) -ceq "report.json"
            ) "Adaptation report filename must be exactly report.json"
            Assert-Exact (
                -not (Test-Path -LiteralPath $outputPath)
            ) "Refusing to overwrite adaptation report: $outputPath"
            $arguments += @("--output", $outputPath)
        }
        & python @arguments
        Assert-Exact (
            $LASTEXITCODE -eq 0
        ) "Adaptation-provider report compiler failed with exit code $LASTEXITCODE"
    } finally {
        Pop-Location
    }
} finally {
    [Environment]::SetEnvironmentVariable(
        "SPORESPORE_LOCOMOTION_LIBRARY",
        $previousLibrary,
        "Process"
    )
}

if (-not [string]::IsNullOrWhiteSpace($Output)) {
    $retainedPath = [System.IO.Path]::GetFullPath($Output)
    Assert-Exact (
        Test-Path -LiteralPath $retainedPath -PathType Leaf
    ) "Adaptation report was not retained: $retainedPath"
    $retained = Get-Content -Raw -LiteralPath $retainedPath | ConvertFrom-Json
    Assert-Exact (
        [string]$retained.schema_version -ceq
        "sporespore_adaptation_provider_conformance_report_v1" -and
        [bool]$retained.ok -and
        [int]$retained.passed_cells -eq 8 -and
        [int]$retained.failed_cells -eq 0 -and
        [int]$retained.world_build_count -eq 0 -and
        -not [bool]$retained.physical_acceptance_authority
    ) "Retained adaptation report failed its exact terminal contract"
    Write-Host "Adaptation-provider evidence retained: $retainedPath"
}

Write-Host (
    "Adaptation-provider conformance passed: A0-A7, " +
    "optional provider, exact baseline fallback, zero worlds."
)
