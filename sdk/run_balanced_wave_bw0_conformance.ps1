[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Output
)

$ErrorActionPreference = "Stop"
$sdkRoot = [System.IO.Path]::GetFullPath($PSScriptRoot)
$repoRoot = [System.IO.Path]::GetFullPath((Split-Path -Parent $sdkRoot))
$reportPath = [System.IO.Path]::GetFullPath($Output)
$evidenceRoot = [System.IO.Path]::GetDirectoryName($reportPath)
$transcriptPath = Join-Path $evidenceRoot "transcript.log"

if ([System.IO.Path]::GetFileName($reportPath) -ne "report.json") {
    throw "BW0 output must end in report.json: $reportPath"
}
if (Test-Path -LiteralPath $reportPath) {
    throw "BW0 report already exists and will not be overwritten: $reportPath"
}
if (Test-Path -LiteralPath $transcriptPath) {
    throw "BW0 transcript already exists and will not be overwritten: $transcriptPath"
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
        [string]$RelativePath
    )

    $path = Join-Path $repoRoot $RelativePath
    $item = Get-Item -LiteralPath $path
    $hash = Get-FileHash -LiteralPath $path -Algorithm SHA256
    return [ordered]@{
        relative_path = $RelativePath.Replace("\", "/")
        bytes = $item.Length
        sha256 = $hash.Hash.ToLowerInvariant()
    }
}

$before = Get-RepositoryState
if (-not $before.source_worktree_clean) {
    throw "BW0 formal evidence requires a clean source worktree."
}
if (-not $before.source_matches_origin_main) {
    throw "BW0 formal evidence requires HEAD equal to origin/main."
}

$transcript = [System.Collections.Generic.List[string]]::new()
$transcript.Add("BW0_SOURCE $($before.source_commit)")

Push-Location -LiteralPath $sdkRoot
try {
    $format = Invoke-CapturedCommand -Id "cargo_fmt_check" -Command {
        & cargo fmt --all -- --check
    }
    $clippy = Invoke-CapturedCommand -Id "cargo_clippy_workspace" -Command {
        & cargo clippy --workspace --all-targets --offline -- -D warnings
    }
    $focused = Invoke-CapturedCommand -Id "cargo_test_balanced_wave" -Command {
        & cargo test -p sporespore-locomotion-core balanced_wave --offline
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

$focusedCounts = @(
    [regex]::Matches($focused.output, "running ([0-9]+) tests?") |
        ForEach-Object { [int]$_.Groups[1].Value }
)
$focusedTestCount = ($focusedCounts | Measure-Object -Sum).Sum
$legacyCounts = @(
    [regex]::Matches($legacy.output, "running ([0-9]+) tests?") |
        ForEach-Object { [int]$_.Groups[1].Value }
)
$legacyTestCount = ($legacyCounts | Measure-Object -Sum).Sum
$workspaceCounts = @(
    [regex]::Matches($workspace.output, "running ([0-9]+) tests") |
        ForEach-Object { [int]$_.Groups[1].Value }
)
$workspaceTestCount = ($workspaceCounts | Measure-Object -Sum).Sum
$pythonMatch = [regex]::Match($python.output, "Ran ([0-9]+) tests")
$pythonTestCount = if ($pythonMatch.Success) {
    [int]$pythonMatch.Groups[1].Value
} else {
    -1
}

$after = Get-RepositoryState
$allExitCodesZero = @(
    $format,
    $clippy,
    $focused,
    $legacy,
    $workspace,
    $release,
    $python
) | ForEach-Object { $_.exit_code -eq 0 } | Where-Object { -not $_ } |
    Measure-Object | Select-Object -ExpandProperty Count
$allExitCodesZero = ($allExitCodesZero -eq 0)

$accepted = (
    $allExitCodesZero -and
    $focusedTestCount -eq 8 -and
    $legacyTestCount -eq 1 -and
    $workspaceTestCount -eq 68 -and
    $pythonTestCount -eq 12 -and
    $after.source_worktree_clean -and
    $after.source_commit -eq $before.source_commit -and
    $after.source_matches_origin_main
)

$sourceReceipts = @(
    Get-Sha256Receipt "sdk\core\src\controller.rs"
    Get-Sha256Receipt "sdk\core\src\runtime.rs"
    Get-Sha256Receipt "sdk\core\src\ffi.rs"
    Get-Sha256Receipt "sdk\core\src\lib.rs"
    Get-Sha256Receipt "sdk\include\sporespore_locomotion.h"
    Get-Sha256Receipt "sdk\python\sporespore_locomotion.py"
    Get-Sha256Receipt "sdk\python\test_ctypes_smoke.py"
    Get-Sha256Receipt "sdk\run_balanced_wave_bw0_conformance.ps1"
    Get-Sha256Receipt "sdk\Cargo.lock"
    Get-Sha256Receipt "docs\SDK_PORTABLE_BALANCED_WAVE_SUCCESSOR_BOOTSTRAP.md"
    Get-Sha256Receipt "docs\adr\ADR-017_PORTABLE_BALANCED_WAVE_SUCCESSOR.md"
    Get-Sha256Receipt "sdk\target\release\sporespore_locomotion_core.dll"
)

$report = [ordered]@{
    schema_version = "sporespore_balanced_wave_bw0_report_v1"
    generated_at_utc = [DateTimeOffset]::UtcNow.ToString("o")
    accepted = $accepted
    result_status = if ($accepted) { "accepted" } else { "rejected" }
    policy_id = "sporespore_balanced_wave_v1"
    profile_schema_version = "sporespore_balanced_wave_profile_v1"
    runtime_schema_version = "sporespore_balanced_wave_runtime_v1"
    memory_schema_version = "sporespore_balanced_wave_memory_v1"
    source_commit = $before.source_commit
    source_worktree_clean = $before.source_worktree_clean
    source_matches_origin_main = $before.source_matches_origin_main
    post_run_source_commit = $after.source_commit
    post_run_source_worktree_clean = $after.source_worktree_clean
    post_run_source_matches_origin_main = $after.source_matches_origin_main
    expected_focused_balanced_wave_tests = 8
    observed_focused_balanced_wave_tests = $focusedTestCount
    expected_candidate35_golden_tests = 1
    observed_candidate35_golden_tests = $legacyTestCount
    expected_workspace_tests = 68
    observed_workspace_tests = $workspaceTestCount
    expected_python_real_dll_tests = 12
    observed_python_real_dll_tests = $pythonTestCount
    branch_surface_count = 0
    profile_domain_sample_count = 10001
    physics_world_count = 0
    locomotion_outcome_exposed = $false
    adapter_actuation_applied = $false
    physics_state_modified = $false
    physical_acceptance_authority = $false
    material_robustness = $false
    cross_engine_c6 = $false
    completed_engine_neutral_sdk = $false
    commands = @(
        $format,
        $clippy,
        $focused,
        $legacy,
        $workspace,
        $release,
        $python
    ) | ForEach-Object {
        [ordered]@{
            command_id = $_.command_id
            exit_code = $_.exit_code
            started_at_utc = $_.started_at_utc
            finished_at_utc = $_.finished_at_utc
        }
    }
    sources = $sourceReceipts
    transcript = [ordered]@{
        relative_path = "transcript.log"
        sha256 = ""
    }
}

$transcript.Add("BW0_RESULT ACCEPTED=$accepted")
[System.IO.File]::WriteAllLines(
    $transcriptPath,
    $transcript,
    [System.Text.UTF8Encoding]::new($false)
)
$transcriptHash = Get-FileHash -LiteralPath $transcriptPath -Algorithm SHA256
$report.transcript.sha256 = $transcriptHash.Hash.ToLowerInvariant()
$json = $report | ConvertTo-Json -Depth 12
[System.IO.File]::WriteAllText(
    $reportPath,
    $json,
    [System.Text.UTF8Encoding]::new($false)
)

Write-Host (
    "BALANCED_WAVE_BW0 accepted=$accepted " +
    "focused=$focusedTestCount legacy=$legacyTestCount " +
    "workspace=$workspaceTestCount python=$pythonTestCount " +
    "report=$reportPath"
)
if (-not $accepted) {
    exit 1
}
