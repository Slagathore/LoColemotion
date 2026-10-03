#requires -Version 7.0

param(
    [string]$Godot = "C:\Users\Cole\CodeStuff\Misc\Godot\Godot_v4.7-stable_mono_win64_console.exe",
    [string]$Pattern = "test_lab_*.gd",
    [string]$LogRoot = (
        Join-Path $env:TEMP "sporespore_lab_tests"
    ),
    [ValidateRange(1, 3600)]
    [int]$TestTimeoutSeconds = 120
)

$ErrorActionPreference = "Stop"
$suiteMutexName = "Local\SporeSpore.RunLabTests.Serial.v1"
$suiteMutex = [System.Threading.Mutex]::new($false, $suiteMutexName)
$suiteMutexAcquired = $false
$suiteMutexWasAbandoned = $false

try {
    try {
        $suiteMutexAcquired = $suiteMutex.WaitOne(0)
    } catch [System.Threading.AbandonedMutexException] {
        # WaitOne grants ownership when it reports an abandoned mutex. Preserve
        # that recovery in the report rather than treating a dead prior owner
        # as a live concurrent harness.
        $suiteMutexAcquired = $true
        $suiteMutexWasAbandoned = $true
    }
    if (-not $suiteMutexAcquired) {
        throw (
            "Another SporeSpore lab-test harness owns the suite mutex " +
            "'$suiteMutexName'. Refusing overlapping physics execution."
        )
    }

$repo = Split-Path -Parent $PSScriptRoot
$processRunner = Join-Path $PSScriptRoot "process_runner.ps1"
if (-not (Test-Path -LiteralPath $processRunner -PathType Leaf)) {
    Write-Error "Process runner not found: $processRunner"
}
. $processRunner
if (-not (Test-Path -LiteralPath $Godot -PathType Leaf)) {
    Write-Error "Godot executable not found: $Godot"
}
$engineErrorRegistry = @{
    # A test must print the exact marker
    # HARNESS_EXPECT_ENGINE_ERROR=CHILD_PROCESS_CREATE_FAILED before invoking
    # this intentional platform failure. Undeclared engine errors still fail.
    CHILD_PROCESS_CREATE_FAILED = '^ERROR:\s+Could not create child process:'
}

# Physics tick-rate tests intentionally run one process at a time. Parallel
# execution can make unrelated fixtures contend for CPU time and manufacture
# apparent timing drift.
$runStamp = Get-Date -Format "yyyyMMddTHHmmssfff"
$runLogRoot = Join-Path $LogRoot $runStamp
New-Item -ItemType Directory -Path $runLogRoot -Force | Out-Null

$testsPath = Join-Path $repo "tests"
# Evidence order is part of the report identity. Sort-Object is culture-aware,
# so punctuation can reorder names across machines/locales (for example,
# `observer_ab.gd` versus `observer_ab_bundle.gd`). Use ordinal code-unit order,
# matching Godot Array.sort() and the source-controlled inventory contract.
[string[]]$testNames = @(
    Get-ChildItem -LiteralPath $testsPath -Filter $Pattern -File |
        ForEach-Object { [string]$_.Name }
)
[Array]::Sort($testNames, [StringComparer]::Ordinal)
$tests = @(
    $testNames |
        ForEach-Object { Get-Item -LiteralPath (Join-Path $testsPath $_) }
)
if ($tests.Count -eq 0) {
    Write-Error "No lab tests matched: $Pattern"
}

$suiteStarted = (Get-Date).ToUniversalTime().ToString("o")
$results = @()
foreach ($test in $tests) {
    $stem = [System.IO.Path]::GetFileNameWithoutExtension($test.Name)
    $engineLog = Join-Path $runLogRoot "$stem.engine.log"
    $transcriptLog = Join-Path $runLogRoot "$stem.transcript.log"
    $started = Get-Date
    Write-Host "=== $($test.Name) ==="

    $invocation = Invoke-ProcessWithTimeout `
        -FilePath $Godot `
        -ArgumentList @(
            "--headless",
            "--path",
            $repo,
            "--log-file",
            $engineLog,
            "--script",
            "res://tests/$($test.Name)"
        ) `
        -TimeoutSeconds $TestTimeoutSeconds `
        -TranscriptPath $transcriptLog
    $ended = Get-Date
    $processExitCode = $invocation.ExitCode
    $outputLines = @($invocation.Lines)
    $outputText = $outputLines -join [Environment]::NewLine
    $outputLines | ForEach-Object { Write-Host $_ }
    $engineLogExists = Test-Path `
        -LiteralPath $engineLog `
        -PathType Leaf
    $engineLogReadable = $false
    $engineLogText = ""
    if ($engineLogExists) {
        try {
            $engineLogText = Get-Content `
                -LiteralPath $engineLog `
                -Raw `
                -ErrorAction Stop
            $engineLogReadable = $true
        } catch {
            $engineLogText = ""
        }
    }
    $engineLogSha256 = if ($engineLogReadable) {
        "sha256:$(
            (Get-FileHash -LiteralPath $engineLog -Algorithm SHA256).
                Hash.ToLowerInvariant()
        )"
    } else { "" }
    $engineLogBytes = if ($engineLogReadable) {
        [int64](Get-Item -LiteralPath $engineLog).Length
    } else { -1 }
    $transcriptLogExists = Test-Path `
        -LiteralPath $transcriptLog `
        -PathType Leaf
    $transcriptLogReadable = $false
    $transcriptLogSha256 = ""
    $transcriptLogBytes = [int64]-1
    if ($transcriptLogExists) {
        try {
            [void](Get-Content `
                -LiteralPath $transcriptLog `
                -Raw `
                -ErrorAction Stop)
            $transcriptLogReadable = $true
            $transcriptLogSha256 = "sha256:$(
                (Get-FileHash -LiteralPath $transcriptLog -Algorithm SHA256).
                    Hash.ToLowerInvariant()
            )"
            $transcriptLogBytes = [int64](
                Get-Item -LiteralPath $transcriptLog
            ).Length
        } catch {
            $transcriptLogReadable = $false
        }
    }

    # Godot can report a script/parse error yet return process exit code 0.
    # A lab test therefore passes only when all three independent witnesses
    # agree: native exit, no engine error record, and an explicit assertion
    # footer with zero failures.
    $footerMatches = [regex]::Matches(
        $outputText,
        '(?m)^===\s+(\d+)\s+passed,\s+(\d+)\s+failed\s+===\s*$'
    )
    # Exactly one footer is authority. Multiple contradictory footers must not
    # let a later forged "0 failed" line overwrite an earlier failure.
    $footerCount = $footerMatches.Count
    $footerFound = $footerCount -eq 1
    $assertionsPassed = $null
    $assertionsFailed = $null
    if ($footerFound) {
        $footer = $footerMatches[0]
        $assertionsPassed = [int]$footer.Groups[1].Value
        $assertionsFailed = [int]$footer.Groups[2].Value
    }
    $engineErrors = @([regex]::Matches(
        ($outputText + [Environment]::NewLine + $engineLogText),
        '(?im)^\s*(?:SCRIPT ERROR:|ERROR:).*$'
    ) | ForEach-Object { $_.Value.Trim() } | Sort-Object -Unique)
    $expectedEngineErrorCodes = @([regex]::Matches(
        $outputText,
        '(?m)^HARNESS_EXPECT_ENGINE_ERROR=([A-Z][A-Z0-9_]*)\s*$'
    ) | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique)
    $unknownExpectedEngineErrorCodes = @(
        $expectedEngineErrorCodes |
            Where-Object { -not $engineErrorRegistry.ContainsKey($_) }
    )
    $missingExpectedEngineErrorCodes = @()
    foreach ($code in $expectedEngineErrorCodes) {
        if (-not $engineErrorRegistry.ContainsKey($code)) {
            continue
        }
        $expectedEngineErrorPattern = $engineErrorRegistry[$code]
        if (
            @(
                $engineErrors |
                    Where-Object { $_ -match $expectedEngineErrorPattern }
            ).Count -eq 0
        ) {
            $missingExpectedEngineErrorCodes += $code
        }
    }
    $unexpectedEngineErrors = @()
    foreach ($engineError in $engineErrors) {
        $declaredMatch = $false
        foreach ($code in $expectedEngineErrorCodes) {
            if (
                $engineErrorRegistry.ContainsKey($code) -and
                $engineError -match $engineErrorRegistry[$code]
            ) {
                $declaredMatch = $true
                break
            }
        }
        if (-not $declaredMatch) {
            $unexpectedEngineErrors += $engineError
        }
    }
    $targetTimeWindowValid = $false
    try {
        if (
            -not [string]::IsNullOrWhiteSpace(
                $invocation.TargetStartedUtc
            ) -and
            -not [string]::IsNullOrWhiteSpace(
                $invocation.TargetEndedUtc
            )
        ) {
            $targetStartedInstant = [DateTimeOffset]::Parse(
                $invocation.TargetStartedUtc
            )
            $targetEndedInstant = [DateTimeOffset]::Parse(
                $invocation.TargetEndedUtc
            )
            $outerStartedInstant = [DateTimeOffset]$started.ToUniversalTime()
            $outerEndedInstant = [DateTimeOffset]$ended.ToUniversalTime()
            $targetTimeWindowValid = (
                $targetStartedInstant -ge $outerStartedInstant -and
                $targetEndedInstant -ge $targetStartedInstant -and
                $targetEndedInstant -le $outerEndedInstant
            )
        }
    } catch {
        $targetTimeWindowValid = $false
    }
    $passedTest = (
        -not $invocation.TimedOut -and
        [string]::IsNullOrWhiteSpace($invocation.StartError) -and
        [string]::IsNullOrWhiteSpace($invocation.TerminationError) -and
        $processExitCode -eq 0 -and
        $engineLogExists -and
        $engineLogReadable -and
        $transcriptLogExists -and
        $transcriptLogReadable -and
        $footerFound -and
        $assertionsPassed -gt 0 -and
        $assertionsFailed -eq 0 -and
        $unexpectedEngineErrors.Count -eq 0 -and
        $missingExpectedEngineErrorCodes.Count -eq 0 -and
        $unknownExpectedEngineErrorCodes.Count -eq 0 -and
        $targetTimeWindowValid
    )

    $status = if ($passedTest) { "pass" } else { "fail" }
    $results += [ordered]@{
        test = $test.Name
        status = $status
        process_exit_code = $processExitCode
        timed_out = $invocation.TimedOut
        timeout_seconds = $invocation.TimeoutSeconds
        killed_process_tree = $invocation.KilledProcessTree
        containment_tree_closed = $invocation.ContainmentTreeClosed
        exit_marker_observed = $invocation.ExitMarkerObserved
        containment_host_process_id = $invocation.HostProcessId
        target_process_id = $invocation.TargetProcessId
        target_started_utc = $invocation.TargetStartedUtc
        target_ended_utc = $invocation.TargetEndedUtc
        target_time_window_valid = $targetTimeWindowValid
        process_start_error = $invocation.StartError
        process_termination_error = $invocation.TerminationError
        footer_found = $footerFound
        footer_count = $footerCount
        assertions_passed = $assertionsPassed
        assertions_failed = $assertionsFailed
        engine_error_count = $engineErrors.Count
        engine_errors = $engineErrors
        expected_engine_error_codes = $expectedEngineErrorCodes
        unexpected_engine_errors = $unexpectedEngineErrors
        missing_expected_engine_error_codes = $missingExpectedEngineErrorCodes
        unknown_expected_engine_error_codes = $unknownExpectedEngineErrorCodes
        duration_ms = [int](($ended - $started).TotalMilliseconds)
        engine_log = $engineLog
        engine_log_exists = $engineLogExists
        engine_log_readable = $engineLogReadable
        engine_log_sha256 = $engineLogSha256
        engine_log_bytes = $engineLogBytes
        transcript_log = $transcriptLog
        transcript_log_exists = $transcriptLogExists
        transcript_log_readable = $transcriptLogReadable
        transcript_log_sha256 = $transcriptLogSha256
        transcript_log_bytes = $transcriptLogBytes
    }
    Write-Host (
        "$($status.ToUpperInvariant()) $($test.Name) " +
        "exit=$processExitCode assertions=$assertionsPassed/$assertionsFailed " +
        "timed_out=$($invocation.TimedOut) " +
        "engine_errors=$($engineErrors.Count) " +
        "unexpected_engine_errors=$($unexpectedEngineErrors.Count)"
    )
}

$failed = @($results | Where-Object { $_.status -eq "fail" })
$report = [ordered]@{
    schema = "sporespore.lab.test_report.v1"
    started_utc = $suiteStarted
    generated_utc = (Get-Date).ToUniversalTime().ToString("o")
    godot = $Godot
    repository = $repo
    pattern = $Pattern
    test_timeout_seconds = $TestTimeoutSeconds
    suite_mutex_name = $suiteMutexName
    suite_mutex_acquired = $suiteMutexAcquired
    suite_mutex_was_abandoned = $suiteMutexWasAbandoned
    total = $results.Count
    passed = $results.Count - $failed.Count
    failed = $failed.Count
    results = $results
}
$reportPath = Join-Path $runLogRoot "report.json"
$report | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $reportPath -Encoding utf8

Write-Host "SUMMARY total=$($results.Count) passed=$($report.passed) failed=$($report.failed)"
Write-Host "REPORT $reportPath"
if ($failed.Count -gt 0) {
    Write-Host "FAILED: $((@($failed.test)) -join ', ')"
    exit 1
}
exit 0
} finally {
    if ($suiteMutexAcquired) {
        $suiteMutex.ReleaseMutex()
    }
    $suiteMutex.Dispose()
}
