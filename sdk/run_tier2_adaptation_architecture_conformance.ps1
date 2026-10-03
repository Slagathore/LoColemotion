[CmdletBinding()]
param(
    [string]$Output = "",
    [switch]$SkipBuild
)

$ErrorActionPreference = "Stop"
$sdkRoot = [System.IO.Path]::GetFullPath($PSScriptRoot)
$architecturePath = Join-Path (
    $sdkRoot
) "adaptation_provider\tier2_architecture_v1.json"
$coreLibraryPath = Join-Path (
    $sdkRoot
) "target\release\sporespore_locomotion_core.dll"

function Assert-Exact {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

Assert-Exact (
    Test-Path -LiteralPath $architecturePath -PathType Leaf
) "Tier 2 architecture contract is missing: $architecturePath"
Get-Content -Raw -LiteralPath $architecturePath | ConvertFrom-Json | Out-Null

if (-not $SkipBuild) {
    & cargo build `
        --manifest-path (Join-Path $sdkRoot "Cargo.toml") `
        --workspace `
        --release `
        --offline
    Assert-Exact (
        $LASTEXITCODE -eq 0
    ) "Tier 2 architecture release build failed with exit code $LASTEXITCODE"
}
Assert-Exact (
    Test-Path -LiteralPath $coreLibraryPath -PathType Leaf
) "Release core library is missing: $coreLibraryPath"

$previousLibrary = [Environment]::GetEnvironmentVariable(
    "SPORESPORE_LOCOMOTION_LIBRARY", "Process"
)
[Environment]::SetEnvironmentVariable(
    "SPORESPORE_LOCOMOTION_LIBRARY", $coreLibraryPath, "Process"
)
try {
    Push-Location -LiteralPath $sdkRoot
    try {
        & python -m unittest -v adaptation_provider.test_tier2_architecture
        Assert-Exact (
            $LASTEXITCODE -eq 0
        ) "Tier 2 architecture tests failed with exit code $LASTEXITCODE"

        $arguments = @("-m", "adaptation_provider.tier2_conformance")
        if (-not [string]::IsNullOrWhiteSpace($Output)) {
            $outputPath = [System.IO.Path]::GetFullPath($Output)
            Assert-Exact (
                [System.IO.Path]::GetFileName($outputPath) -ceq "report.json"
            ) "Tier 2 report filename must be exactly report.json"
            Assert-Exact (
                -not (Test-Path -LiteralPath $outputPath)
            ) "Refusing to overwrite Tier 2 report: $outputPath"
            $arguments += @("--output", $outputPath)
        }
        & python @arguments
        Assert-Exact (
            $LASTEXITCODE -eq 0
        ) "Tier 2 report compiler failed with exit code $LASTEXITCODE"
    } finally {
        Pop-Location
    }
} finally {
    [Environment]::SetEnvironmentVariable(
        "SPORESPORE_LOCOMOTION_LIBRARY", $previousLibrary, "Process"
    )
}

if (-not [string]::IsNullOrWhiteSpace($Output)) {
    $retainedPath = [System.IO.Path]::GetFullPath($Output)
    Assert-Exact (
        Test-Path -LiteralPath $retainedPath -PathType Leaf
    ) "Tier 2 report was not retained: $retainedPath"
    $retained = Get-Content -Raw -LiteralPath $retainedPath | ConvertFrom-Json
    Assert-Exact (
        [string]$retained.schema_version -ceq
        "sporespore_tier2_architecture_conformance_report_v1" -and
        [bool]$retained.ok -and
        [int]$retained.passed_cells -eq 7 -and
        [int]$retained.failed_cells -eq 0 -and
        [bool]$retained.architecture_fixture_only -and
        -not [bool]$retained.engine_qualification_executed -and
        [int]$retained.world_build_count -eq 0 -and
        -not [bool]$retained.physical_acceptance_authority
    ) "Retained Tier 2 report failed its exact terminal contract"
    Write-Host "Tier 2 architecture evidence retained: $retainedPath"
}

Write-Host (
    "Tier 2 architecture conformance passed: T0-T6, " +
    "training-only promotion refused, zero worlds."
)
