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
$semanticsPath = Join-Path $repoRoot "docs\LOCOMOTION_SEMANTICS_V3.md"
$bootstrapPath = Join-Path $repoRoot (
    "docs\SDK_GODOT_JOLT_STABILITY_INFLUENCE_BOOTSTRAP.md"
)
$corePath = Join-Path $sdkRoot "core\src\stability.rs"
$ffiPath = Join-Path $sdkRoot "core\src\ffi.rs"
$headerPath = Join-Path $sdkRoot "include\sporespore_locomotion.h"
$pythonBindingPath = Join-Path $sdkRoot "python\sporespore_locomotion.py"
$pythonTestPath = Join-Path $sdkRoot "python\test_ctypes_smoke.py"
$godotBindingPath = Join-Path $sdkRoot "adapters\godot\src\lib.rs"
$godotTestPath = Join-Path $repoRoot (
    "tests\test_sdk_stability_v3_subset_map.gd"
)
$nativeTestPath = Join-Path $repoRoot "tests\test_sdk_godot_adapter_c0_c1.gd"
$runnerPath = $MyInvocation.MyCommand.Path
$godotPath = [System.IO.Path]::GetFullPath($Godot)

foreach ($requiredPath in @(
    $manifestPath,
    $semanticsPath,
    $bootstrapPath,
    $corePath,
    $ffiPath,
    $headerPath,
    $pythonBindingPath,
    $pythonTestPath,
    $godotBindingPath,
    $godotTestPath,
    $nativeTestPath,
    $runnerPath,
    $godotPath
)) {
    if (-not (Test-Path -LiteralPath $requiredPath -PathType Leaf)) {
        throw "Required stability-v3 conformance input not found: $requiredPath"
    }
}

$startedUtc = [DateTime]::UtcNow.ToString("o")
$runId = [DateTime]::UtcNow.ToString("yyyyMMddTHHmmssfff")
$temporaryRoot = Join-Path (
    [System.IO.Path]::GetTempPath()
) "sporespore_sdk_stability_v3_subset_map\$runId"
[System.IO.Directory]::CreateDirectory($temporaryRoot) | Out-Null
$temporaryTranscriptPath = Join-Path $temporaryRoot "transcript.log"
$transcriptLines = [System.Collections.Generic.List[string]]::new()

function Add-Transcript {
    param([object[]]$Lines)
    foreach ($line in $Lines) {
        $text = "$line"
        $transcriptLines.Add($text)
        Write-Host $text
    }
}

Push-Location -LiteralPath $sdkRoot
try {
    $formatOutput = @(& cargo fmt --all -- --check 2>&1)
    $formatExitCode = $LASTEXITCODE
    Add-Transcript -Lines $formatOutput
    if ($formatExitCode -ne 0) {
        throw "Rust formatting check failed with exit code $formatExitCode"
    }

    $rustOutput = @(
        & cargo test `
            --manifest-path $manifestPath `
            --package sporespore-locomotion-core `
            --lib `
            "endpoint_force_joint_map_v3_" `
            --offline 2>&1
    )
    $rustExitCode = $LASTEXITCODE
    Add-Transcript -Lines $rustOutput
    if ($rustExitCode -ne 0) {
        throw "Rust stability-v3 conformance failed with exit code $rustExitCode"
    }
    $rustSummary = $rustOutput | Select-String -Pattern (
        "test result: ok\. 5 passed; 0 failed; 0 ignored; 0 measured;"
    )
    if ($rustSummary.Count -ne 1) {
        throw "Rust stability-v3 conformance did not report exact 5/5"
    }

    $debugBuildOutput = @(
        & cargo build `
            --manifest-path $manifestPath `
            --package sporespore-godot-adapter `
            --offline 2>&1
    )
    $debugBuildExitCode = $LASTEXITCODE
    Add-Transcript -Lines $debugBuildOutput
    if ($debugBuildExitCode -ne 0) {
        throw "Godot adapter debug build failed with exit code $debugBuildExitCode"
    }

    $releaseBuildOutput = @(
        & cargo build `
            --manifest-path $manifestPath `
            --package sporespore-locomotion-core `
            --release `
            --offline 2>&1
    )
    $releaseBuildExitCode = $LASTEXITCODE
    Add-Transcript -Lines $releaseBuildOutput
    if ($releaseBuildExitCode -ne 0) {
        throw "Core release build failed with exit code $releaseBuildExitCode"
    }
} finally {
    Pop-Location
}

$godotOutput = @(
    & $godotPath `
        --headless `
        --path $repoRoot `
        --script "res://tests/test_sdk_stability_v3_subset_map.gd" 2>&1
)
$godotExitCode = $LASTEXITCODE
Add-Transcript -Lines $godotOutput
if ($godotExitCode -ne 0) {
    throw "Godot stability-v3 oracle failed with exit code $godotExitCode"
}
$godotSummary = $godotOutput | Select-String -SimpleMatch (
    "SDK stability v3 subset-map summary: 12 passed, 0 failed"
)
if ($godotSummary.Count -ne 1) {
    throw "Godot stability-v3 oracle did not report exact 12/12"
}
$receiptPrefix = "SDK_STABILITY_V3_SUBSET_MAP_RECEIPT "
$receiptLines = @(
    $godotOutput | Where-Object { "$_".StartsWith($receiptPrefix) }
)
if ($receiptLines.Count -ne 1) {
    throw "Godot stability-v3 oracle did not emit exactly one machine receipt"
}
$receipt = "$($receiptLines[0])".Substring($receiptPrefix.Length) |
    ConvertFrom-Json -Depth 100
if (
    -not $receipt.ok -or
    $receipt.schema_version -cne "sporespore_stability_v3_subset_map_receipt_v1"
) {
    throw "Godot stability-v3 machine receipt rejected"
}

$nativeOutput = @(
    & $godotPath `
        --headless `
        --path $repoRoot `
        --script "res://tests/test_sdk_godot_adapter_c0_c1.gd" 2>&1
)
$nativeExitCode = $LASTEXITCODE
Add-Transcript -Lines $nativeOutput
if ($nativeExitCode -ne 0) {
    throw "Godot native boundary failed with exit code $nativeExitCode"
}
$nativeSummary = $nativeOutput | Select-String -SimpleMatch (
    "SDK Godot-adapter summary: 27 passed, 0 failed"
)
if ($nativeSummary.Count -ne 1) {
    throw "Godot native boundary did not report exact 27/27"
}

Push-Location -LiteralPath (Split-Path -Parent $pythonTestPath)
try {
    $pythonOutput = @(
        & python -m unittest -v (Split-Path -Leaf $pythonTestPath) 2>&1
    )
    $pythonExitCode = $LASTEXITCODE
} finally {
    Pop-Location
}
Add-Transcript -Lines $pythonOutput
if ($pythonExitCode -ne 0) {
    throw "Python real-DLL suite failed with exit code $pythonExitCode"
}
$pythonSummary = $pythonOutput | Select-String -Pattern "^Ran 10 tests in "
if ($pythonSummary.Count -ne 1) {
    throw "Python real-DLL suite did not report exact 10/10"
}

[System.IO.File]::WriteAllLines(
    $temporaryTranscriptPath,
    $transcriptLines,
    [System.Text.UTF8Encoding]::new($false)
)
$transcriptSha256 = (
    Get-FileHash -Algorithm SHA256 -LiteralPath $temporaryTranscriptPath
).Hash.ToLowerInvariant()

$sourceCommit = (& git -C $repoRoot rev-parse HEAD).Trim()
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($sourceCommit)) {
    throw "Unable to resolve the source commit"
}
$originMain = (& git -C $repoRoot rev-parse origin/main).Trim()
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($originMain)) {
    throw "Unable to resolve origin/main"
}
$worktreeStatus = @(
    & git -C $repoRoot status --porcelain=v1 --untracked-files=all
)
if ($LASTEXITCODE -ne 0) {
    throw "Unable to inspect the source worktree"
}
$worktreeClean = $worktreeStatus.Count -eq 0
$sourceMatchesOriginMain = $sourceCommit -ceq $originMain
$godotVersion = (& $godotPath --version).Trim()
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($godotVersion)) {
    throw "Unable to resolve the Godot version"
}

function Source-Receipt {
    param([string]$Path, [string]$RelativePath)
    return [ordered]@{
        path = $RelativePath
        sha256 = (
            Get-FileHash -Algorithm SHA256 -LiteralPath $Path
        ).Hash.ToLowerInvariant()
    }
}

$report = [ordered]@{
    schema_version = "sporespore_stability_v3_subset_map_conformance_report_v1"
    generated_at_utc = [DateTime]::UtcNow.ToString("o")
    started_at_utc = $startedUtc
    source_commit = $sourceCommit
    source_worktree_clean = $worktreeClean
    source_matches_origin_main = $sourceMatchesOriginMain
    sources = [ordered]@{
        semantics = Source-Receipt $semanticsPath "docs/LOCOMOTION_SEMANTICS_V3.md"
        bootstrap = Source-Receipt $bootstrapPath (
            "docs/SDK_GODOT_JOLT_STABILITY_INFLUENCE_BOOTSTRAP.md"
        )
        portable_core = Source-Receipt $corePath "sdk/core/src/stability.rs"
        ffi = Source-Receipt $ffiPath "sdk/core/src/ffi.rs"
        public_header = Source-Receipt (
            $headerPath
        ) "sdk/include/sporespore_locomotion.h"
        python_binding = Source-Receipt (
            $pythonBindingPath
        ) "sdk/python/sporespore_locomotion.py"
        python_test = Source-Receipt (
            $pythonTestPath
        ) "sdk/python/test_ctypes_smoke.py"
        godot_binding = Source-Receipt (
            $godotBindingPath
        ) "sdk/adapters/godot/src/lib.rs"
        independent_godot_test = Source-Receipt (
            $godotTestPath
        ) "tests/test_sdk_stability_v3_subset_map.gd"
        native_boundary_test = Source-Receipt (
            $nativeTestPath
        ) "tests/test_sdk_godot_adapter_c0_c1.gd"
        runner = Source-Receipt (
            $runnerPath
        ) "sdk/run_stability_v3_subset_map_conformance.ps1"
    }
    godot = [ordered]@{
        executable_path = $godotPath
        executable_sha256 = (
            Get-FileHash -Algorithm SHA256 -LiteralPath $godotPath
        ).Hash.ToLowerInvariant()
        version = $godotVersion
    }
    gates = [ordered]@{
        rust = [ordered]@{ passed = 5; failed = 0 }
        independent_gdscript = [ordered]@{ passed = 12; failed = 0 }
        native_godot_boundary = [ordered]@{ passed = 27; failed = 0 }
        python_real_dll = [ordered]@{ passed = 10; failed = 0 }
    }
    receipt = $receipt
    transcript = [ordered]@{
        path = "transcript.log"
        sha256 = $transcriptSha256
    }
    result = [ordered]@{
        portable_partial_support_joint_map_v3 = $true
        full_support_v2_v3_equivalent = $true
        inactive_contact_commands_exact_zero = $true
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
    if (-not $sourceMatchesOriginMain) {
        throw (
            "Refusing to retain evidence when source does not match origin/main. " +
            "Push the implementation, fetch origin/main, then rerun."
        )
    }
    $outputPath = [System.IO.Path]::GetFullPath($Output)
    if ([System.IO.Path]::GetFileName($outputPath) -cne "report.json") {
        throw "The retained stability-v3 report filename must be exactly report.json"
    }
    $outputDirectory = Split-Path -Parent $outputPath
    [System.IO.Directory]::CreateDirectory($outputDirectory) | Out-Null
    $retainedTranscriptPath = Join-Path $outputDirectory "transcript.log"
    [System.IO.File]::Copy(
        $temporaryTranscriptPath,
        $retainedTranscriptPath,
        $true
    )
    $temporaryPath = "$outputPath.tmp"
    $json = $report | ConvertTo-Json -Depth 100
    [System.IO.File]::WriteAllText(
        $temporaryPath,
        "$json`n",
        [System.Text.UTF8Encoding]::new($false)
    )
    [System.IO.File]::Move($temporaryPath, $outputPath, $true)
    Write-Host "Retained stability-v3 subset-map report: $outputPath"
}

Write-Host "Transcript: $temporaryTranscriptPath"
Write-Host "SDK stability-v3 subset-map pure conformance passed."
