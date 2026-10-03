[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Output,
    [string]$Godot = (
        "C:\Users\Cole\CodeStuff\Misc\Godot\" +
        "Godot_v4.7-stable_mono_win64_console.exe"
    )
)

$ErrorActionPreference = "Stop"
$sdkRoot = [System.IO.Path]::GetFullPath($PSScriptRoot)
$repoRoot = [System.IO.Path]::GetFullPath((Split-Path -Parent $sdkRoot))
$reportPath = [System.IO.Path]::GetFullPath($Output)
$evidenceRoot = [System.IO.Path]::GetDirectoryName($reportPath)
$transcriptPath = Join-Path $evidenceRoot "transcript.log"
$godotPath = [System.IO.Path]::GetFullPath($Godot)

if ([System.IO.Path]::GetFileName($reportPath) -ne "report.json") {
    throw "BW1 output must end in report.json: $reportPath"
}
if (Test-Path -LiteralPath $reportPath) {
    throw "BW1 report already exists and will not be overwritten: $reportPath"
}
if (Test-Path -LiteralPath $transcriptPath) {
    throw "BW1 transcript already exists and will not be overwritten: $transcriptPath"
}
if (-not (Test-Path -LiteralPath $godotPath -PathType Leaf)) {
    throw "Pinned Godot executable not found: $godotPath"
}
if (-not (Test-Path -LiteralPath $evidenceRoot)) {
    [void](New-Item -ItemType Directory -Path $evidenceRoot)
}

function Get-RepositoryState {
    Push-Location -LiteralPath $repoRoot
    try {
        $sourceCommit = (& git rev-parse HEAD).Trim()
        if ($LASTEXITCODE -ne 0) {
            throw "Unable to resolve source HEAD."
        }
        $originMain = (& git rev-parse origin/main).Trim()
        if ($LASTEXITCODE -ne 0) {
            throw "Unable to resolve origin/main."
        }
        $status = @(& git status --porcelain=v1 --untracked-files=all)
        if ($LASTEXITCODE -ne 0) {
            throw "Unable to inspect source worktree."
        }
        return [ordered]@{
            source_commit = $sourceCommit
            origin_main_commit = $originMain
            source_worktree_clean = ($status.Count -eq 0)
            source_matches_origin_main = ($sourceCommit -eq $originMain)
            status_lines = $status
        }
    } finally {
        Pop-Location
    }
}

function Invoke-CapturedCommand {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Id,
        [Parameter(Mandatory = $true)]
        [scriptblock]$Command
    )

    $startedAt = [DateTimeOffset]::UtcNow
    $lines = @(& $Command 2>&1 | ForEach-Object { $_.ToString() })
    $exitCode = $LASTEXITCODE
    $finishedAt = [DateTimeOffset]::UtcNow
    $script:transcript.Add("COMMAND_START $Id $($startedAt.ToString('o'))")
    foreach ($line in $lines) {
        $script:transcript.Add($line)
        Write-Host $line
    }
    $script:transcript.Add("COMMAND_END $Id EXIT=$exitCode $($finishedAt.ToString('o'))")
    return [ordered]@{
        command_id = $Id
        exit_code = $exitCode
        started_at_utc = $startedAt.ToString("o")
        finished_at_utc = $finishedAt.ToString("o")
        output = ($lines -join "`n")
    }
}

function Get-Sha256Receipt {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        [Parameter(Mandatory = $true)]
        [string]$Label
    )

    $resolvedPath = [System.IO.Path]::GetFullPath($Path)
    $item = Get-Item -LiteralPath $resolvedPath
    $hash = Get-FileHash -LiteralPath $resolvedPath -Algorithm SHA256
    return [ordered]@{
        label = $Label
        path = $resolvedPath
        bytes = $item.Length
        sha256 = $hash.Hash.ToLowerInvariant()
    }
}

function Get-RepoSha256Receipt {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RelativePath
    )

    return Get-Sha256Receipt `
        -Path (Join-Path $repoRoot $RelativePath) `
        -Label $RelativePath.Replace("\", "/")
}

function Get-TestCount {
    param(
        [Parameter(Mandatory = $true)]
        [string]$OutputText
    )

    $counts = @(
        [regex]::Matches($OutputText, "running ([0-9]+) tests?") |
            ForEach-Object { [int]$_.Groups[1].Value }
    )
    return ($counts | Measure-Object -Sum).Sum
}

$before = Get-RepositoryState
if (-not $before.source_worktree_clean) {
    throw "BW1 formal evidence requires a clean source worktree."
}
if (-not $before.source_matches_origin_main) {
    throw "BW1 formal evidence requires HEAD equal to origin/main."
}

$transcript = [System.Collections.Generic.List[string]]::new()
$transcript.Add("BW1_SOURCE $($before.source_commit)")

Push-Location -LiteralPath $sdkRoot
try {
    $format = Invoke-CapturedCommand -Id "cargo_fmt_check" -Command {
        & cargo fmt --all -- --check
    }
    $clippy = Invoke-CapturedCommand -Id "cargo_clippy_workspace" -Command {
        & cargo clippy --workspace --all-targets --offline -- -D warnings
    }
    $legacy = Invoke-CapturedCommand -Id "cargo_test_candidate35_golden" -Command {
        & cargo test -p sporespore-locomotion-core `
            checked_in_gdscript_golden_vectors_match_rust `
            --offline
    }
    $workspace = Invoke-CapturedCommand -Id "cargo_test_workspace" -Command {
        & cargo test --workspace --offline
    }
    $release = Invoke-CapturedCommand -Id "cargo_build_release" -Command {
        & cargo build --workspace --release --offline
    }
    $godotDebug = Invoke-CapturedCommand -Id "cargo_build_godot_debug" -Command {
        & cargo build -p sporespore-godot-adapter --offline
    }
    Push-Location -LiteralPath (Join-Path $sdkRoot "python")
    try {
        $python = Invoke-CapturedCommand -Id "python_ctypes_smoke" -Command {
            & python -m unittest -v test_ctypes_smoke.py
        }
    } finally {
        Pop-Location
    }
} finally {
    Pop-Location
}

Push-Location -LiteralPath $repoRoot
try {
    $profileOracle = Invoke-CapturedCommand -Id "godot_balanced_profile_oracle" -Command {
        & $godotPath `
            --headless `
            --path $repoRoot `
            --script "res://tests/test_sdk_balanced_wave_profile_oracle.gd"
    }
    $nativeBoundary = Invoke-CapturedCommand -Id "godot_native_boundary" -Command {
        & $godotPath `
            --headless `
            --path $repoRoot `
            --script "res://tests/test_sdk_godot_adapter_c0_c1.gd"
    }
    $materialRegression = Invoke-CapturedCommand -Id "godot_material_profile_regression" -Command {
        & $godotPath `
            --headless `
            --path $repoRoot `
            --script "res://tests/test_sdk_godot_jolt_material_profiles.gd"
    }
    $physicalShadow = Invoke-CapturedCommand -Id "godot_balanced_bw1_shadow" -Command {
        & $godotPath `
            --headless `
            --path $repoRoot `
            --script "res://tests/test_sdk_balanced_wave_godot_jolt_shadow.gd"
    }
} finally {
    Pop-Location
}

$legacyTestCount = Get-TestCount -OutputText $legacy.output
$workspaceTestCount = Get-TestCount -OutputText $workspace.output
$pythonMatch = [regex]::Match($python.output, "Ran ([0-9]+) tests")
$pythonTestCount = if ($pythonMatch.Success) {
    [int]$pythonMatch.Groups[1].Value
} else {
    -1
}
$profileSampleMatch = [regex]::Match(
    $profileOracle.output,
    "BALANCED_WAVE_PROFILE_SAMPLES passed=([0-9]+) failed=([0-9]+)"
)
$profileSummaryMatch = [regex]::Match(
    $profileOracle.output,
    "SDK balanced-wave profile summary: ([0-9]+) passed, ([0-9]+) failed"
)
$nativeSummaryMatch = [regex]::Match(
    $nativeBoundary.output,
    "SDK Godot-adapter summary: ([0-9]+) passed, ([0-9]+) failed"
)
$materialSummaryMatch = [regex]::Match(
    $materialRegression.output,
    "SDK Godot/Jolt P5M\.2 material-profile summary: ([0-9]+) passed, ([0-9]+) failed"
)
$bw1SummaryMatch = [regex]::Match(
    $physicalShadow.output,
    "SDK Godot/Jolt balanced-wave BW1 summary: ([0-9]+) passed, ([0-9]+) failed"
)
$bw1ReceiptMatch = [regex]::Match(
    $physicalShadow.output,
    "BALANCED_WAVE_BW1_RECEIPT (\{[^\r\n]+\})"
)
$bw1Receipt = if ($bw1ReceiptMatch.Success) {
    $bw1ReceiptMatch.Groups[1].Value | ConvertFrom-Json
} else {
    $null
}

$commands = @(
    $format,
    $clippy,
    $legacy,
    $workspace,
    $release,
    $godotDebug,
    $python,
    $profileOracle,
    $nativeBoundary,
    $materialRegression,
    $physicalShadow
)
$failedCommandCount = @(
    $commands | Where-Object { $_.exit_code -ne 0 }
).Count
$after = Get-RepositoryState

$accepted = (
    $failedCommandCount -eq 0 -and
    $legacyTestCount -eq 1 -and
    $workspaceTestCount -eq 65 -and
    $pythonTestCount -eq 12 -and
    $profileSampleMatch.Success -and
    [int]$profileSampleMatch.Groups[1].Value -eq 10001 -and
    [int]$profileSampleMatch.Groups[2].Value -eq 0 -and
    $profileSummaryMatch.Success -and
    [int]$profileSummaryMatch.Groups[1].Value -eq 10 -and
    [int]$profileSummaryMatch.Groups[2].Value -eq 0 -and
    $nativeSummaryMatch.Success -and
    [int]$nativeSummaryMatch.Groups[1].Value -eq 35 -and
    [int]$nativeSummaryMatch.Groups[2].Value -eq 0 -and
    $materialSummaryMatch.Success -and
    [int]$materialSummaryMatch.Groups[1].Value -eq 19 -and
    [int]$materialSummaryMatch.Groups[2].Value -eq 0 -and
    $bw1SummaryMatch.Success -and
    [int]$bw1SummaryMatch.Groups[1].Value -eq 12 -and
    [int]$bw1SummaryMatch.Groups[2].Value -eq 0 -and
    $null -ne $bw1Receipt -and
    [bool]$bw1Receipt.ok -and
    [int]$bw1Receipt.world_build_count -eq 1 -and
    [string]$bw1Receipt.source_controller_policy_id -eq "sporespore_balanced_wave_v1" -and
    [int]$bw1Receipt.step_count -eq 1514 -and
    [int]$bw1Receipt.validated_command_count -eq 12112 -and
    [int]$bw1Receipt.step_receipt_count -eq 1514 -and
    [int]$bw1Receipt.stability_attempt_count -eq 1514 -and
    [int]$bw1Receipt.mapping_attempt_count -eq 1514 -and
    [int]$bw1Receipt.contribution_attempt_count -eq 1514 -and
    [int]$bw1Receipt.native_motor_write_count -eq 0 -and
    -not [bool]$bw1Receipt.physical_acceptance_authority -and
    $after.source_worktree_clean -and
    $after.source_commit -eq $before.source_commit -and
    $after.source_matches_origin_main
)

$sourceReceipts = @(
    Get-RepoSha256Receipt "sdk\adapters\godot\src\lib.rs"
    Get-RepoSha256Receipt "scripts\lab\gait\sdk_godot_jolt_adapter.gd"
    Get-RepoSha256Receipt "scripts\lab\gait\physical_wave_gait_quadruped.gd"
    Get-RepoSha256Receipt "tests\test_sdk_balanced_wave_profile_oracle.gd"
    Get-RepoSha256Receipt "tests\test_sdk_balanced_wave_godot_jolt_shadow.gd"
    Get-RepoSha256Receipt "tests\test_sdk_godot_adapter_c0_c1.gd"
    Get-RepoSha256Receipt "sdk\run_balanced_wave_bw1_shadow.ps1"
    Get-RepoSha256Receipt "sdk\Cargo.lock"
    Get-RepoSha256Receipt "docs\SDK_PORTABLE_BALANCED_WAVE_SUCCESSOR_BOOTSTRAP.md"
)
$binaryReceipts = @(
    Get-RepoSha256Receipt "sdk\target\debug\sporespore_godot_adapter.dll"
    Get-RepoSha256Receipt "sdk\target\release\sporespore_godot_adapter.dll"
    Get-RepoSha256Receipt "sdk\target\release\sporespore_locomotion_core.dll"
)
$engineReceipt = Get-Sha256Receipt -Path $godotPath -Label "godot"

$report = [ordered]@{
    schema_version = "sporespore_balanced_wave_bw1_report_v1"
    generated_at_utc = [DateTimeOffset]::UtcNow.ToString("o")
    accepted = $accepted
    result_status = if ($accepted) { "accepted" } else { "rejected" }
    policy_id = "sporespore_balanced_wave_v1"
    source_commit = $before.source_commit
    source_worktree_clean = $before.source_worktree_clean
    source_matches_origin_main = $before.source_matches_origin_main
    post_run_source_commit = $after.source_commit
    post_run_source_worktree_clean = $after.source_worktree_clean
    post_run_source_matches_origin_main = $after.source_matches_origin_main
    legacy_candidate35_golden_tests = $legacyTestCount
    workspace_tests = $workspaceTestCount
    python_real_dll_tests = $pythonTestCount
    profile_sample_count = if ($profileSampleMatch.Success) {
        [int]$profileSampleMatch.Groups[1].Value
    } else {
        -1
    }
    profile_sample_failure_count = if ($profileSampleMatch.Success) {
        [int]$profileSampleMatch.Groups[2].Value
    } else {
        -1
    }
    profile_oracle_passed_gates = if ($profileSummaryMatch.Success) {
        [int]$profileSummaryMatch.Groups[1].Value
    } else {
        -1
    }
    native_boundary_passed_gates = if ($nativeSummaryMatch.Success) {
        [int]$nativeSummaryMatch.Groups[1].Value
    } else {
        -1
    }
    material_regression_passed_gates = if ($materialSummaryMatch.Success) {
        [int]$materialSummaryMatch.Groups[1].Value
    } else {
        -1
    }
    physical_shadow_passed_gates = if ($bw1SummaryMatch.Success) {
        [int]$bw1SummaryMatch.Groups[1].Value
    } else {
        -1
    }
    physical_shadow_receipt = $bw1Receipt
    branch_surface_count = 0
    physics_world_count = if ($null -ne $bw1Receipt) {
        [int]$bw1Receipt.world_build_count
    } else {
        -1
    }
    adapter_actuation_applied = $false
    native_motor_write_count = if ($null -ne $bw1Receipt) {
        [int]$bw1Receipt.native_motor_write_count
    } else {
        -1
    }
    physical_balance_recovery = $false
    walking = $false
    material_robustness = $false
    cross_engine_c6 = $false
    completed_engine_neutral_sdk = $false
    physical_acceptance_authority = $false
    commands = $commands | ForEach-Object {
        [ordered]@{
            command_id = $_.command_id
            exit_code = $_.exit_code
            started_at_utc = $_.started_at_utc
            finished_at_utc = $_.finished_at_utc
        }
    }
    sources = $sourceReceipts
    binaries = $binaryReceipts
    engine = $engineReceipt
    transcript = [ordered]@{
        relative_path = "transcript.log"
        sha256 = ""
    }
}

$transcript.Add("BW1_RESULT ACCEPTED=$accepted")
[System.IO.File]::WriteAllLines(
    $transcriptPath,
    $transcript,
    [System.Text.UTF8Encoding]::new($false)
)
$transcriptHash = Get-FileHash -LiteralPath $transcriptPath -Algorithm SHA256
$report.transcript.sha256 = $transcriptHash.Hash.ToLowerInvariant()
$json = $report | ConvertTo-Json -Depth 15
[System.IO.File]::WriteAllText(
    $reportPath,
    $json,
    [System.Text.UTF8Encoding]::new($false)
)

Write-Host (
    "BALANCED_WAVE_BW1 accepted=$accepted " +
    "profile_samples=$($report.profile_sample_count) " +
    "steps=$($bw1Receipt.step_count) commands=$($bw1Receipt.validated_command_count) " +
    "report=$reportPath"
)
if (-not $accepted) {
    exit 1
}
