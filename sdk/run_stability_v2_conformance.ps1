[CmdletBinding()]
param(
    [string]$Godot = (
        "C:\Users\Cole\CodeStuff\Misc\Godot\" +
        "Godot_v4.7-stable_mono_win64_console.exe"
    ),
    [string]$Output = ""
)

$ErrorActionPreference = "Stop"
$sdkRoot = [System.IO.Path]::GetFullPath($PSScriptRoot)
$repoRoot = [System.IO.Path]::GetFullPath((Split-Path -Parent $sdkRoot))
$manifestPath = Join-Path $sdkRoot "Cargo.toml"
$goldenPath = Join-Path $sdkRoot (
    "conformance\golden\stability_v2_gdscript_oracle_v1.json"
)
$semanticsPath = Join-Path $repoRoot "docs\LOCOMOTION_SEMANTICS_V2.md"
$corePath = Join-Path $sdkRoot "core\src\stability.rs"
$godotTestPath = Join-Path $repoRoot (
    "tests\test_sdk_stability_v2_golden_vectors.gd"
)
$godotPath = [System.IO.Path]::GetFullPath($Godot)

foreach ($requiredPath in @(
    $manifestPath,
    $goldenPath,
    $semanticsPath,
    $corePath,
    $godotTestPath,
    $godotPath
)) {
    if (-not (Test-Path -LiteralPath $requiredPath -PathType Leaf)) {
        throw "Required stability-v2 conformance input not found: $requiredPath"
    }
}

$startedUtc = [DateTime]::UtcNow.ToString("o")

Push-Location -LiteralPath $sdkRoot
try {
    $rustOutput = @(
        & cargo test `
            --manifest-path $manifestPath `
            --package sporespore-locomotion-core `
            --lib `
            "stability::tests::" `
            --offline 2>&1
    )
    $rustExitCode = $LASTEXITCODE
} finally {
    Pop-Location
}
$rustOutput | ForEach-Object { Write-Host $_ }
if ($rustExitCode -ne 0) {
    throw "Rust stability-v2 conformance failed with exit code $rustExitCode"
}
$rustSummary = ($rustOutput | Select-String -Pattern (
    "test result: ok\. 15 passed; 0 failed; 0 ignored; 0 measured;"
))
if ($rustSummary.Count -ne 1) {
    throw "Rust stability-v2 conformance did not report the exact 15/15 gate"
}

$godotOutput = @(
    & $godotPath `
        --headless `
        --path $repoRoot `
        --script "res://tests/test_sdk_stability_v2_golden_vectors.gd" 2>&1
)
$godotExitCode = $LASTEXITCODE
$godotOutput | ForEach-Object { Write-Host $_ }
if ($godotExitCode -ne 0) {
    throw "Godot stability-v2 oracle failed with exit code $godotExitCode"
}
$godotSummary = ($godotOutput | Select-String -SimpleMatch (
    "SDK stability v2 golden summary: 23 passed, 0 failed"
))
if ($godotSummary.Count -ne 1) {
    throw "Godot stability-v2 oracle did not report the exact 23/23 gate"
}

$sourceCommit = (& git -C $repoRoot rev-parse HEAD).Trim()
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($sourceCommit)) {
    throw "Unable to resolve the source commit"
}
$worktreeStatus = @(& git -C $repoRoot status --porcelain=v1 --untracked-files=all)
if ($LASTEXITCODE -ne 0) {
    throw "Unable to inspect the source worktree"
}
$worktreeClean = $worktreeStatus.Count -eq 0
$godotVersion = (& $godotPath --version).Trim()
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($godotVersion)) {
    throw "Unable to resolve the Godot version"
}

$report = [ordered]@{
    schema_version = "sporespore_stability_v2_conformance_report_v1"
    generated_at_utc = [DateTime]::UtcNow.ToString("o")
    started_at_utc = $startedUtc
    source_commit = $sourceCommit
    source_worktree_clean = $worktreeClean
    semantics = [ordered]@{
        version = "sporespore_locomotion_semantics_v2"
        path = "docs/LOCOMOTION_SEMANTICS_V2.md"
        sha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $semanticsPath).Hash.ToLowerInvariant()
    }
    portable_core = [ordered]@{
        path = "sdk/core/src/stability.rs"
        sha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $corePath).Hash.ToLowerInvariant()
        rust_binary64_absolute_tolerance = 1.0e-12
        passed = 15
        failed = 0
    }
    shared_golden_vector = [ordered]@{
        path = "sdk/conformance/golden/stability_v2_gdscript_oracle_v1.json"
        sha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $goldenPath).Hash.ToLowerInvariant()
    }
    godot_oracle = [ordered]@{
        executable_path = $godotPath
        executable_sha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $godotPath).Hash.ToLowerInvariant()
        version = $godotVersion
        test_path = "tests/test_sdk_stability_v2_golden_vectors.gd"
        test_sha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $godotTestPath).Hash.ToLowerInvariant()
        binary32_vector_absolute_tolerance = 1.0e-6
        binary32_force_absolute_tolerance = 1.0e-5
        passed = 23
        failed = 0
    }
    result = [ordered]@{
        pure_stability_semantics_v2 = $true
        portable_endpoint_force_joint_map_v2 = $true
        shared_gdscript_rust_golden_conformance = $true
        actuator_response_characterized = $false
        godot_adapter_state_emission = $false
        adapter_actuation = $false
        physics_world_modified = $false
        physical_balance_recovery = $false
        locomotion = $false
        friction_material_robustness = $false
        cross_engine_c6 = $false
        physical_acceptance_authority = $false
        completed_engine_neutral_sdk = $false
    }
}

if (-not [string]::IsNullOrWhiteSpace($Output)) {
    if (-not $worktreeClean) {
        throw (
            "Refusing to retain evidence from a dirty worktree. " +
            "Commit the implementation, rerun this harness, then retain report.json."
        )
    }
    $outputPath = [System.IO.Path]::GetFullPath($Output)
    if ([System.IO.Path]::GetFileName($outputPath) -cne "report.json") {
        throw "The retained stability-v2 report filename must be exactly report.json"
    }
    $outputDirectory = Split-Path -Parent $outputPath
    [System.IO.Directory]::CreateDirectory($outputDirectory) | Out-Null
    $temporaryPath = "$outputPath.tmp"
    $json = $report | ConvertTo-Json -Depth 8
    [System.IO.File]::WriteAllText(
        $temporaryPath,
        "$json`n",
        [System.Text.UTF8Encoding]::new($false)
    )
    [System.IO.File]::Move($temporaryPath, $outputPath, $true)
    Write-Host "Retained stability-v2 conformance report: $outputPath"
}

Write-Host "SDK stability-v2 pure conformance passed."
