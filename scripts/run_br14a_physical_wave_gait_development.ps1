#requires -Version 7.0

<#
.SYNOPSIS
Runs the isolated BR14A.6 physical quadruped walking development campaign.

.DESCRIPTION
Creates fresh minimal Godot projects pinned to Jolt velocity/position solver
steps 20/6, runs the exact physical wave-gait test in serialized, contained
hidden processes, retains every log, and writes a hashed development report.

The repository-wide project remains pinned to 20/4 for prior exact BR14A
evidence. This runner does not create a promotion decision, attest a report,
admit knowledge, or authorize automatic creature guidance.
#>

[CmdletBinding()]
param(
    [string]$Godot = (
        "C:\Users\Cole\CodeStuff\Misc\Godot\" +
        "Godot_v4.7-stable_mono_win64_console.exe"
    ),
    [ValidateRange(1, 10)]
    [int]$Repetitions = 3,
    [ValidateRange(10, 300)]
    [int]$TestTimeoutSeconds = 60,
    [string]$LogRoot = (
        Join-Path $env:TEMP "sporespore_br14a_physical_wave_gait"
    )
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [System.IO.Path]::GetFullPath(
    (Split-Path -Parent $PSScriptRoot)
)
$godotPath = [System.IO.Path]::GetFullPath($Godot)
$testRelativePath = (
    "tests\test_experimental_br14a_6_physical_wave_gait_quadruped.gd"
)
$runnerRelativePath = "scripts\run_br14a_physical_wave_gait_development.ps1"
$processRunnerRelativePath = "scripts\process_runner.ps1"
$containmentHostRelativePath = "scripts\process_runner_containment_host.ps1"
$processRunner = Join-Path $repoRoot $processRunnerRelativePath
$sourceRelativePaths = @(
    "scripts\lab\gait\physical_wave_gait_quadruped.gd",
    "scripts\lab\gait\physical_quadruped_fixture_spec.gd",
    "scripts\lab\mechanics\semantic_contact_rigid_body.gd",
    "scripts\lab\canonical_json.gd",
    "scripts\lab\finite_sanitizer.gd",
    $processRunnerRelativePath,
    $containmentHostRelativePath,
    $runnerRelativePath,
    $testRelativePath
)

if (-not (Test-Path -LiteralPath $godotPath -PathType Leaf)) {
    throw "Godot executable not found: $godotPath"
}
foreach ($relativePath in $sourceRelativePaths) {
    $sourcePath = Join-Path $repoRoot $relativePath
    if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
        throw "Required source file not found: $sourcePath"
    }
}
. $processRunner

$runStamp = Get-Date -Format "yyyyMMddTHHmmssfff"
$campaignRoot = Join-Path (
    [System.IO.Path]::GetFullPath($LogRoot)
) $runStamp
[void][System.IO.Directory]::CreateDirectory($campaignRoot)

$projectText = @'
; Isolated SporeSpore BR14A.6 physical wave-gait development project.

config_version=5

[application]

config/name="sporespore-br14a-physical-wave-gait-development"
config/features=PackedStringArray("4.7", "Forward Plus")

[debug]

gdscript/warnings/shadowed_global_identifier=0

[physics]

3d/physics_engine="Jolt Physics"
jolt_physics_3d/simulation/velocity_steps=20
jolt_physics_3d/simulation/position_steps=6
'@

$sourceHashes = [ordered]@{}
foreach ($relativePath in $sourceRelativePaths) {
    $normalizedRelativePath = $relativePath.Replace("\", "/")
    $hash = Get-FileHash `
        -LiteralPath (Join-Path $repoRoot $relativePath) `
        -Algorithm SHA256
    $sourceHashes[$normalizedRelativePath] = (
        "sha256:" + $hash.Hash.ToLowerInvariant()
    )
}
$godotHash = Get-FileHash -LiteralPath $godotPath -Algorithm SHA256

Push-Location $repoRoot
try {
    $sourceCommit = (& git rev-parse HEAD).Trim()
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($sourceCommit)) {
        throw "Unable to resolve the source commit."
    }
    $scopedStatus = @(
        & git status --porcelain=v1 -- @sourceRelativePaths
    )
    if ($LASTEXITCODE -ne 0) {
        throw "Unable to inspect the scoped source status."
    }
} finally {
    Pop-Location
}

$suiteMutexName = "Local\SporeSpore.RunLabTests.Serial.v1"
$suiteMutex = [System.Threading.Mutex]::new($false, $suiteMutexName)
$suiteMutexAcquired = $false
$suiteMutexWasAbandoned = $false
try {
    $suiteMutexAcquired = $suiteMutex.WaitOne(0)
} catch [System.Threading.AbandonedMutexException] {
    $suiteMutexAcquired = $true
    $suiteMutexWasAbandoned = $true
}
if (-not $suiteMutexAcquired) {
    throw (
        "Another SporeSpore lab-test harness owns the suite mutex " +
        "'$suiteMutexName'. Refusing overlapping physics execution."
    )
}

try {
$workers = @()
for ($repeat = 1; $repeat -le $Repetitions; $repeat++) {
    $runRoot = Join-Path $campaignRoot (
        "repeat-{0:d2}" -f $repeat
    )
    $directories = @(
        $runRoot,
        (Join-Path $runRoot "scripts\lab\gait"),
        (Join-Path $runRoot "scripts\lab\mechanics"),
        (Join-Path $runRoot "tests"),
        (Join-Path $runRoot "worker\appdata"),
        (Join-Path $runRoot "worker\localappdata")
    )
    foreach ($directory in $directories) {
        [void][System.IO.Directory]::CreateDirectory($directory)
    }
    [System.IO.File]::WriteAllText(
        (Join-Path $runRoot "project.godot"),
        $projectText,
        [System.Text.UTF8Encoding]::new($false)
    )
    foreach ($relativePath in $sourceRelativePaths) {
        Copy-Item `
            -LiteralPath (Join-Path $repoRoot $relativePath) `
            -Destination (Join-Path $runRoot $relativePath) `
            -Force
    }

    $stdoutPath = Join-Path $runRoot "stdout.log"
    $stderrPath = Join-Path $runRoot "stderr.log"
    $transcriptPath = Join-Path $runRoot "transcript.log"
    $engineLogPath = Join-Path $runRoot "godot.log"
    $previousAppData = $env:APPDATA
    $previousLocalAppData = $env:LOCALAPPDATA
    try {
        $env:APPDATA = Join-Path $runRoot "worker\appdata"
        $env:LOCALAPPDATA = Join-Path $runRoot "worker\localappdata"
        $invocation = Invoke-ProcessWithTimeout `
            -FilePath $godotPath `
            -ArgumentList @(
                "--headless",
                "--path",
                $runRoot,
                "--script",
                "res://$($testRelativePath.Replace('\', '/'))",
                "--log-file",
                $engineLogPath
            ) `
            -TimeoutSeconds $TestTimeoutSeconds `
            -TranscriptPath $transcriptPath
    } finally {
        $env:APPDATA = $previousAppData
        $env:LOCALAPPDATA = $previousLocalAppData
    }
    [System.IO.File]::WriteAllText(
        $stdoutPath,
        [string]$invocation.Stdout,
        [System.Text.UTF8Encoding]::new($false)
    )
    [System.IO.File]::WriteAllText(
        $stderrPath,
        [string]$invocation.Stderr,
        [System.Text.UTF8Encoding]::new($false)
    )
    $workers += [pscustomobject][ordered]@{
        Repeat = $repeat
        RunRoot = $runRoot
        Invocation = $invocation
        StdoutPath = $stdoutPath
        StderrPath = $stderrPath
        TranscriptPath = $transcriptPath
        EngineLogPath = $engineLogPath
    }
}

$results = @()
foreach ($worker in $workers) {
    $invocation = $worker.Invocation
    if ($invocation.TimedOut) {
        Write-Host (
            (
                "repeat={0} timed_out=true target_pid={1} " +
                "containment_closed={2}"
            ) -f @(
                $worker.Repeat,
                $invocation.TargetProcessId,
                $invocation.ContainmentTreeClosed
            )
        )
        $results += [pscustomobject][ordered]@{
            repeat = $worker.Repeat
            passed = $false
            timed_out = $true
            target_pid = $invocation.TargetProcessId
            exit_code = $invocation.ExitCode
            killed_process_tree = $invocation.KilledProcessTree
            containment_tree_closed = $invocation.ContainmentTreeClosed
            assertions_passed = $null
            assertions_failed = $null
            engine_errors = @()
            run_root = $worker.RunRoot
        }
        continue
    }

    $stdoutText = Get-Content -LiteralPath $worker.StdoutPath -Raw
    $stderrText = Get-Content -LiteralPath $worker.StderrPath -Raw
    $engineLogExists = Test-Path `
        -LiteralPath $worker.EngineLogPath `
        -PathType Leaf
    $engineLogText = if ($engineLogExists) {
        Get-Content -LiteralPath $worker.EngineLogPath -Raw
    } else {
        ""
    }
    $footer = [regex]::Match(
        $stdoutText,
        '(?m)^===\s+(\d+)\s+passed,\s+(\d+)\s+failed\s+===\s*$'
    )
    $assertionsPassed = if ($footer.Success) {
        [int]$footer.Groups[1].Value
    } else {
        $null
    }
    $assertionsFailed = if ($footer.Success) {
        [int]$footer.Groups[2].Value
    } else {
        $null
    }
    $engineErrors = @(
        [regex]::Matches(
            (
                $stdoutText +
                [Environment]::NewLine +
                $stderrText +
                [Environment]::NewLine +
                $engineLogText
            ),
            '(?im)^\s*(?:SCRIPT ERROR:|ERROR:).*$'
        ) |
            ForEach-Object { $_.Value.Trim() } |
            Sort-Object -Unique
    )
    $passed = (
        $invocation.ExitCode -eq 0 -and
        $invocation.ContainmentTreeClosed -and
        -not $invocation.KilledProcessTree -and
        $footer.Success -and
        $assertionsPassed -eq 19 -and
        $assertionsFailed -eq 0 -and
        $engineErrors.Count -eq 0
    )
    $stdoutHash = Get-FileHash `
        -LiteralPath $worker.StdoutPath `
        -Algorithm SHA256
    $stderrHash = Get-FileHash `
        -LiteralPath $worker.StderrPath `
        -Algorithm SHA256
    $engineLogHash = if ($engineLogExists) {
        Get-FileHash `
            -LiteralPath $worker.EngineLogPath `
            -Algorithm SHA256
    } else {
        $null
    }
    $results += [pscustomobject][ordered]@{
        repeat = $worker.Repeat
        passed = $passed
        timed_out = $false
        target_pid = $invocation.TargetProcessId
        exit_code = $invocation.ExitCode
        killed_process_tree = $invocation.KilledProcessTree
        containment_tree_closed = $invocation.ContainmentTreeClosed
        assertions_passed = $assertionsPassed
        assertions_failed = $assertionsFailed
        engine_errors = $engineErrors
        stdout_sha256 = (
            "sha256:" + $stdoutHash.Hash.ToLowerInvariant()
        )
        stderr_sha256 = (
            "sha256:" + $stderrHash.Hash.ToLowerInvariant()
        )
        engine_log_sha256 = if ($null -ne $engineLogHash) {
            "sha256:" + $engineLogHash.Hash.ToLowerInvariant()
        } else { "" }
        run_root = $worker.RunRoot
    }
    Write-Host (
        (
            "repeat={0} passed={1} exit={2} assertions={3}/{4} " +
            "engine_errors={5}"
        ) -f @(
            $worker.Repeat,
            $passed,
            $invocation.ExitCode,
            $assertionsPassed,
            $assertionsFailed,
            $engineErrors.Count
        )
    )
}

$failedResults = @($results | Where-Object { -not $_.passed })
$completedResults = @($results | Where-Object { -not $_.timed_out })
$totalAssertionsPassed = (
    $completedResults |
        Measure-Object -Property assertions_passed -Sum
).Sum
$totalAssertionsFailed = (
    $completedResults |
        Measure-Object -Property assertions_failed -Sum
).Sum
$allPassed = (
    $scopedStatus.Count -eq 0 -and
    $results.Count -eq $Repetitions -and
    $failedResults.Count -eq 0
)
$report = [ordered]@{
    schema_version = (
        "sporespore_br14a_physical_wave_gait_development_report_v1"
    )
    generated_utc = (Get-Date).ToUniversalTime().ToString("o")
    source_commit = $sourceCommit
    source_scope_clean = $scopedStatus.Count -eq 0
    scoped_source_status = $scopedStatus
    source_sha256 = $sourceHashes
    godot_path = $godotPath
    godot_sha256 = (
        "sha256:" + $godotHash.Hash.ToLowerInvariant()
    )
    physics_project_settings = [ordered]@{
        engine = "Jolt Physics"
        physics_hz = 120
        velocity_steps = 20
        position_steps = 6
    }
    suite_mutex_name = $suiteMutexName
    suite_mutex_acquired = $suiteMutexAcquired
    suite_mutex_was_abandoned = $suiteMutexWasAbandoned
    execution_policy = "serialized_contained_workers_v1"
    test_program = $testRelativePath.Replace("\", "/")
    repetition_count = $Repetitions
    total_assertions_passed = $totalAssertionsPassed
    total_assertions_failed = $totalAssertionsFailed
    all_repetitions_passed = $allPassed
    walking_observation_scope = (
        "exact deterministic fresh-process reproduction"
    )
    perturbed_seed_robustness_established = $false
    formal_milestone_acceptance_authorized = $false
    encyclopedia_admission_authorized = $false
    automatic_creature_guidance_allowed = $false
    results = $results
}
$reportPath = Join-Path $campaignRoot "report.json"
$reportJson = $report | ConvertTo-Json -Depth 10
[System.IO.File]::WriteAllText(
    $reportPath,
    $reportJson + [Environment]::NewLine,
    [System.Text.UTF8Encoding]::new($false)
)
$reportHash = Get-FileHash -LiteralPath $reportPath -Algorithm SHA256

Write-Host "REPORT=$reportPath"
Write-Host (
    "REPORT_SHA256=sha256:" + $reportHash.Hash.ToLowerInvariant()
)
Write-Host (
    "CAMPAIGN_PASSED={0} ASSERTIONS={1}/{2}" -f @(
        $allPassed,
        $totalAssertionsPassed,
        $totalAssertionsFailed
    )
)
if ($allPassed) {
    exit 0
}
exit 1
} finally {
    if ($suiteMutexAcquired) {
        $suiteMutex.ReleaseMutex()
    }
    $suiteMutex.Dispose()
}
