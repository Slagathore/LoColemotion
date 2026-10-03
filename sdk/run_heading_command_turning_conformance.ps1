[CmdletBinding()]
param(
    [string]$Output = "",
    [switch]$SkipBuild
)

$ErrorActionPreference = "Stop"
$sdkRoot = [System.IO.Path]::GetFullPath($PSScriptRoot)
$contractPath = Join-Path (
    $sdkRoot
) "turning\heading_command_contract_v1.json"
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
) "Heading-command contract is missing: $contractPath"
Get-Content -Raw -LiteralPath $contractPath | ConvertFrom-Json | Out-Null

if (-not $SkipBuild) {
    & cargo build `
        --manifest-path (Join-Path $sdkRoot "Cargo.toml") `
        --workspace `
        --release `
        --offline
    Assert-Exact (
        $LASTEXITCODE -eq 0
    ) "Heading-command release build failed with exit code $LASTEXITCODE"
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
        & python -m unittest -v turning.test_conformance
        Assert-Exact (
            $LASTEXITCODE -eq 0
        ) "Heading-command conformance tests failed with exit code $LASTEXITCODE"

        $arguments = @("-m", "turning.conformance")
        if (-not [string]::IsNullOrWhiteSpace($Output)) {
            $outputPath = [System.IO.Path]::GetFullPath($Output)
            Assert-Exact (
                [System.IO.Path]::GetFileName($outputPath) -ceq "report.json"
            ) "Heading-command report filename must be exactly report.json"
            Assert-Exact (
                -not (Test-Path -LiteralPath $outputPath)
            ) "Refusing to overwrite heading-command report: $outputPath"
            $arguments += @("--output", $outputPath)
        }
        & python @arguments
        Assert-Exact (
            $LASTEXITCODE -eq 0
        ) "Heading-command report compiler failed with exit code $LASTEXITCODE"
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
    ) "Heading-command report was not retained: $retainedPath"
    $retained = Get-Content -Raw -LiteralPath $retainedPath | ConvertFrom-Json
    Assert-Exact (
        [string]$retained.schema_version -ceq
        "sporespore_heading_command_turning_conformance_report_v1" -and
        [bool]$retained.ok -and
        -not [bool]$retained.release_gate_satisfied -and
        [int]$retained.passed_cells -eq 9 -and
        [int]$retained.failed_cells -eq 0 -and
        [int]$retained.descriptor_vertex_count -eq 64 -and
        [int]$retained.world_build_count -eq 0 -and
        -not [bool]$retained.turning_acceptance -and
        -not [bool]$retained.physical_acceptance_authority
    ) "Retained heading-command report failed its exact terminal contract"
    Write-Host "Heading-command source evidence retained: $retainedPath"
}

Write-Host (
    "Heading-command source conformance passed: H0-H8, 64 descriptor " +
    "vertices, exact zero compatibility, zero worlds, R23 still missing."
)
