#requires -Version 7.0

param(
    [string]$Godot = "C:\Users\Cole\CodeStuff\Misc\Godot\Godot_v4.7-stable_mono_win64_console.exe",
    [string]$LogRoot = (
        Join-Path $env:TEMP "sporespore_all_tests"
    ),
    [ValidateRange(1, 3600)]
    [int]$TestTimeoutSeconds = 120
)

$ErrorActionPreference = "Stop"
$repo = Split-Path -Parent $PSScriptRoot
$processRunner = Join-Path $PSScriptRoot "process_runner.ps1"
if (-not (Test-Path -LiteralPath $processRunner -PathType Leaf)) {
    Write-Error "Process runner not found: $processRunner"
}
. $processRunner
if (-not (Test-Path -LiteralPath $Godot -PathType Leaf)) {
    Write-Error "Godot executable not found: $Godot"
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
        "Another SporeSpore test harness owns the suite mutex " +
        "'$suiteMutexName'. Refusing overlapping Godot execution."
    )
}
try {
$engineErrorRegistry = @{
    # Intentional platform failures require an explicit marker in test output.
    # Nothing else is allowlisted.
    CHILD_PROCESS_CREATE_FAILED = '^ERROR:\s+Could not create child process:'
}

$runStamp = Get-Date -Format "yyyyMMddTHHmmssfff"
$runLogRoot = Join-Path $LogRoot $runStamp
New-Item -ItemType Directory -Path $runLogRoot -Force | Out-Null

$suiteStarted = (Get-Date).ToUniversalTime().ToString("o")
$results = @()
$tests = @(
    Get-ChildItem -LiteralPath (Join-Path $repo "tests") -Filter "test_*.gd" |
        Sort-Object Name
)
if ($tests.Count -eq 0) {
    Write-Error "No tests matched test_*.gd"
}
foreach ($test in $tests) {
    $scriptPath = "res://tests/$($test.Name)"
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
            $scriptPath
        ) `
        -TimeoutSeconds $TestTimeoutSeconds `
        -TranscriptPath $transcriptLog
    $processExitCode = $invocation.ExitCode
    $outputLines = @($invocation.Lines)
    $outputText = $outputLines -join [Environment]::NewLine
    $outputLines | ForEach-Object { Write-Host $_ }
    $engineLogText = if (Test-Path -LiteralPath $engineLog) {
        Get-Content -LiteralPath $engineLog -Raw
    } else {
        ""
    }

    # Native exit code alone is not an oracle: Godot can emit a script error
    # and still exit 0. Require an explicit assertion footer and a clean engine
    # transcript as separate witnesses.
    $footerMatches = [regex]::Matches(
        $outputText,
        '(?m)^===\s+(\d+)\s+passed,\s+(\d+)\s+failed\s+===\s*$'
    )
    $footerFound = $footerMatches.Count -gt 0
    $assertionsPassed = $null
    $assertionsFailed = $null
    if ($footerFound) {
        $lastFooter = $footerMatches[$footerMatches.Count - 1]
        $assertionsPassed = [int]$lastFooter.Groups[1].Value
        $assertionsFailed = [int]$lastFooter.Groups[2].Value
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
    $passedTest = (
        -not $invocation.TimedOut -and
        [string]::IsNullOrWhiteSpace($invocation.StartError) -and
        [string]::IsNullOrWhiteSpace($invocation.TerminationError) -and
        $processExitCode -eq 0 -and
        $invocation.ContainmentTreeClosed -and
        -not $invocation.KilledProcessTree -and
        $footerFound -and
        $assertionsFailed -eq 0 -and
        $unexpectedEngineErrors.Count -eq 0 -and
        $missingExpectedEngineErrorCodes.Count -eq 0 -and
        $unknownExpectedEngineErrorCodes.Count -eq 0
    )
    $status = if ($passedTest) { "pass" } else { "fail" }
    $ended = Get-Date
    $results += [ordered]@{
        test = $test.Name
        status = $status
        process_exit_code = $processExitCode
        timed_out = $invocation.TimedOut
        timeout_seconds = $invocation.TimeoutSeconds
        killed_process_tree = $invocation.KilledProcessTree
        containment_tree_closed = $invocation.ContainmentTreeClosed
        process_start_error = $invocation.StartError
        process_termination_error = $invocation.TerminationError
        footer_found = $footerFound
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
        transcript_log = $transcriptLog
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
    schema = "sporespore.test_report.v1"
    started_utc = $suiteStarted
    generated_utc = (Get-Date).ToUniversalTime().ToString("o")
    godot = $Godot
    repository = $repo
    test_timeout_seconds = $TestTimeoutSeconds
    suite_mutex_name = $suiteMutexName
    suite_mutex_acquired = $suiteMutexAcquired
    suite_mutex_was_abandoned = $suiteMutexWasAbandoned
    execution_policy = "serialized_contained_workers_v1"
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
