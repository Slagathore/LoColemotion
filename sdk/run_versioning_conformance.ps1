[CmdletBinding()]
param(
    [string]$Output = "",
    [switch]$SkipBuild
)

$ErrorActionPreference = "Stop"
$sdkRoot = [System.IO.Path]::GetFullPath($PSScriptRoot)
$versioningRoot = Join-Path $sdkRoot "versioning"
$coreLibraryPath = Join-Path (
    $sdkRoot
) "target\release\sporespore_locomotion_core.dll"
$contractPaths = @(
    (Join-Path $versioningRoot "compatibility_policy_v1.json"),
    (Join-Path $versioningRoot "c_abi_manifest_v1.json"),
    (Join-Path $versioningRoot "schema_registry_v1.json"),
    (Join-Path $versioningRoot "deprecation_registry_v1.json")
)

function Assert-Exact {
    param(
        [bool]$Condition,
        [string]$Message
    )
    if (-not $Condition) {
        throw $Message
    }
}

foreach ($path in $contractPaths) {
    Assert-Exact (
        Test-Path -LiteralPath $path -PathType Leaf
    ) "Versioning contract is missing: $path"
    Get-Content -Raw -LiteralPath $path |
        ConvertFrom-Json |
        Out-Null
}

if (-not $SkipBuild) {
    & cargo build `
        --manifest-path (Join-Path $sdkRoot "Cargo.toml") `
        --workspace `
        --release `
        --offline
    Assert-Exact (
        $LASTEXITCODE -eq 0
    ) "Versioning release build failed with exit code $LASTEXITCODE"
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
        & python -m unittest -v versioning.test_conformance
        Assert-Exact (
            $LASTEXITCODE -eq 0
        ) "Versioning unit conformance failed with exit code $LASTEXITCODE"

        $arguments = @("-m", "versioning.conformance")
        if (-not [string]::IsNullOrWhiteSpace($Output)) {
            $outputPath = [System.IO.Path]::GetFullPath($Output)
            Assert-Exact (
                [System.IO.Path]::GetFileName($outputPath) -ceq "report.json"
            ) "Versioning report filename must be exactly report.json"
            Assert-Exact (
                -not (Test-Path -LiteralPath $outputPath)
            ) "Refusing to overwrite versioning report: $outputPath"
            $arguments += @("--output", $outputPath)
        }
        & python @arguments
        Assert-Exact (
            $LASTEXITCODE -eq 0
        ) "Versioning report compiler failed with exit code $LASTEXITCODE"
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
    ) "Versioning report was not retained: $retainedPath"
    $retained = Get-Content -Raw -LiteralPath $retainedPath |
        ConvertFrom-Json
    Assert-Exact (
        [string]$retained.schema_version -ceq
        "sporespore_sdk_versioning_conformance_report_v1" -and
        [bool]$retained.ok -and
        [string]$retained.sdk_version -ceq "0.1.0" -and
        [int]$retained.abi_generation -eq 1 -and
        [int]$retained.passed_cells -eq 7 -and
        [int]$retained.failed_cells -eq 0 -and
        [int]$retained.world_build_count -eq 0 -and
        -not [bool]$retained.release_ready -and
        -not [bool]$retained.publication_authorized -and
        -not [bool]$retained.physical_acceptance_authority
    ) "Retained versioning report failed its exact terminal contract"
    Write-Host "Versioning evidence retained: $retainedPath"
}

Write-Host (
    "Versioning conformance passed: V0-V6, ABI generation 1, " +
    "strict migration and deprecation interlocks, zero worlds."
)
