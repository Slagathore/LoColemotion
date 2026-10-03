#requires -Version 7.0

function Test-SporeSporeProcessIsSelfOrDescendant {
    param(
        [Parameter(Mandatory)][int]$RootProcessId,
        [Parameter(Mandatory)][int]$CandidateProcessId
    )
    if ($RootProcessId -le 0 -or $CandidateProcessId -le 0) {
        return $false
    }
    $currentProcessId = $CandidateProcessId
    for ($depth = 0; $depth -lt 16; $depth++) {
        if ($currentProcessId -eq $RootProcessId) {
            return $true
        }
        try {
            $current = Get-CimInstance Win32_Process `
                -Filter "ProcessId = $currentProcessId" -ErrorAction Stop
        } catch {
            return $false
        }
        if ($null -eq $current -or [int]$current.ParentProcessId -le 0) {
            return $false
        }
        $currentProcessId = [int]$current.ParentProcessId
    }
    return $false
}

function Get-SporeSporeGodotEngineHealthProjection {
    [CmdletBinding()]
    param(
        [AllowEmptyString()][string]$StandardError = ""
    )

    $utf8 = [Text.UTF8Encoding]::new($false)
    $stderrBytes = $utf8.GetBytes($StandardError)
    $stderrSha256 = "sha256:" + [Convert]::ToHexString(
        [Security.Cryptography.SHA256]::HashData($stderrBytes)
    ).ToLowerInvariant()
    $nonemptyLines = @(
        $StandardError -split "`r?`n" |
            Where-Object { -not [string]::IsNullOrEmpty([string]$_) }
    )
    $fatalLines = [Collections.Generic.List[string]]::new()
    $uniqueFatalLines = [Collections.Generic.List[string]]::new()
    $seenFatalLines = [Collections.Generic.HashSet[string]]::new(
        [StringComparer]::Ordinal
    )
    $engineErrorLineCount = 0
    $nativeAssertionFailureLineCount = 0
    $nativeAssertionSiteLineCount = 0

    foreach ($lineValue in $nonemptyLines) {
        $line = [string]$lineValue
        $trimmed = $line.TrimStart()
        $engineError = (
            $trimmed.StartsWith("ERROR:", [StringComparison]::Ordinal) -or
            $trimmed.StartsWith("SCRIPT ERROR:", [StringComparison]::Ordinal) -or
            $trimmed.StartsWith("FATAL:", [StringComparison]::Ordinal) -or
            $trimmed.StartsWith("CRASH:", [StringComparison]::Ordinal)
        )
        $nativeAssertionFailure = $trimmed.Contains(
            "Jolt Physics assertion",
            [StringComparison]::Ordinal
        )
        $nativeAssertionSite = $trimmed.StartsWith(
            "at: jolt_assert",
            [StringComparison]::Ordinal
        )
        if ($engineError) { $engineErrorLineCount += 1 }
        if ($nativeAssertionFailure) { $nativeAssertionFailureLineCount += 1 }
        if ($nativeAssertionSite) { $nativeAssertionSiteLineCount += 1 }
        if (-not ($engineError -or $nativeAssertionFailure -or $nativeAssertionSite)) {
            continue
        }
        $fatalLines.Add($line)
        if ($seenFatalLines.Add($line)) {
            $uniqueFatalLines.Add($line)
        }
    }

    return [pscustomobject][ordered]@{
        schema_version = "sporespore_godot_engine_health_projection_v1"
        selector_id = "godot_typed_fatal_diagnostic_selector_v1"
        stderr_raw_byte_length = $stderrBytes.Length
        stderr_raw_sha256 = $stderrSha256
        stderr_nonempty_line_count = $nonemptyLines.Count
        engine_error_line_count = $engineErrorLineCount
        native_assertion_failure_line_count = $nativeAssertionFailureLineCount
        native_assertion_site_line_count = $nativeAssertionSiteLineCount
        fatal_diagnostic_line_count = $fatalLines.Count
        fatal_diagnostic_unique_line_count = $uniqueFatalLines.Count
        ordered_unique_fatal_diagnostic_lines = @($uniqueFatalLines)
        passed = $fatalLines.Count -eq 0
        physical_acceptance_authority = $false
        release_authority = $false
    }
}

function Invoke-SporeSporeGodotReceiptTerminatedProcess {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$FileName,
        [Parameter(Mandatory)][string[]]$Arguments,
        [Parameter(Mandatory)][string]$WorkingDirectory,
        [Parameter(Mandatory)][string]$ReadyMarkerPrefix,
        [Parameter(Mandatory)][string]$ExpectedNonce,
        [hashtable]$Environment = @{},
        [string[]]$ScrubEnvironmentNames = @(),
        [string]$ProgressMarkerPrefix = "",
        [ValidateRange(0, 86400)][int]$ProgressStallTimeoutSeconds = 0,
        [ValidateRange(1, 86400)][int]$TimeoutSeconds = 900,
        [AllowNull()][System.Collections.IDictionary]$R10fL15LaunchContext = $null,
        [switch]$R10xNativeProcessObservation
    )

    if ([string]::IsNullOrWhiteSpace($ExpectedNonce)) {
        throw "Godot receipt-terminated process requires a non-empty nonce"
    }
    if ($R10xNativeProcessObservation -and $null -eq $R10fL15LaunchContext) {
        throw 'R10X_NATIVE_OBSERVER_REQUIRES_L15_CONTEXT'
    }
    if ($null -ne $R10fL15LaunchContext) {
        . (Join-Path $PSScriptRoot 'qsdk_r10f_l15_launch_relationship.ps1')
        Assert-QsdkR10fL15LaunchContext $R10fL15LaunchContext
        Assert-QsdkR10fL15Launch (
            $R10fL15LaunchContext.termination_nonce -ceq $ExpectedNonce -and
            $R10fL15LaunchContext.ready_marker_prefix -ceq $ReadyMarkerPrefix -and
            [string]::Equals([IO.Path]::GetFullPath($FileName),
                [IO.Path]::GetFullPath($R10fL15LaunchContext.root_image.path),
                [StringComparison]::OrdinalIgnoreCase)
        ) 'LAUNCH_ARGUMENT_BINDING'
    }
    if ($R10xNativeProcessObservation) {
        # Import after the invocation-local L15 definitions, so the actual
        # producer and preliminary ancestry guard both use this bound observer.
        . (Join-Path $PSScriptRoot 'process/r10x_native_process_observation_v1.ps1')
    }
    $progressEnabled = -not [string]::IsNullOrEmpty($ProgressMarkerPrefix)
    if ($progressEnabled -ne ($ProgressStallTimeoutSeconds -gt 0)) {
        throw (
            "Godot receipt-terminated process requires progress marker and " +
            "stall timeout to be enabled together"
        )
    }

    $start = [Diagnostics.ProcessStartInfo]::new()
    $start.FileName = [IO.Path]::GetFullPath($FileName)
    $start.WorkingDirectory = [IO.Path]::GetFullPath($WorkingDirectory)
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    foreach ($argument in $Arguments) {
        [void]$start.ArgumentList.Add($argument)
    }
    foreach ($name in $ScrubEnvironmentNames) {
        [void]$start.Environment.Remove($name)
    }
    foreach ($entry in $Environment.GetEnumerator()) {
        $start.Environment[[string]$entry.Key] = [string]$entry.Value
    }

    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $start
    $started = [DateTime]::UtcNow
    $deadline = $started.AddSeconds($TimeoutSeconds)
    $stdoutLines = [Collections.Generic.List[string]]::new()
    $readyLineCount = 0
    $readyReceipt = $null
    $progressLineCount = 0
    $progressReceipts = [Collections.Generic.List[object]]::new()
    $lastProgressSequence = 0
    $lastProgressAt = $started
    $protocolFailure = ""
    $timedOut = $false
    $timeoutKind = ""
    $supervisorTerminated = $false
    $r10fL15LaunchReceipt = $null

    [void]$process.Start()
    $expectedProcessId = $process.Id
    $stderrTask = $process.StandardError.ReadToEndAsync()

    try {
        while ($true) {
            $readTask = $process.StandardOutput.ReadLineAsync()
            while (-not $readTask.Wait(100)) {
                $now = [DateTime]::UtcNow
                if ($now -ge $deadline) {
                    $timedOut = $true
                    $timeoutKind = "total_wall_clock"
                    break
                }
                if ($progressEnabled -and $now -ge $lastProgressAt.AddSeconds(
                    $ProgressStallTimeoutSeconds
                )) {
                    $timedOut = $true
                    $timeoutKind = "progress_stall"
                    break
                }
                if ($process.HasExited) {
                    break
                }
            }

            if ($timedOut) {
                try { $process.Kill($true) } catch {}
                [void]$process.WaitForExit(10000)
                break
            }

            if (-not $readTask.IsCompleted) {
                if ($process.HasExited) {
                    [void]$readTask.Wait(1000)
                }
                if (-not $readTask.IsCompleted) {
                    $protocolFailure = "GODOT_READY_STREAM_ENDED_INCOMPLETELY"
                    break
                }
            }

            $line = $readTask.GetAwaiter().GetResult()
            if ($null -eq $line) {
                break
            }
            $stdoutLines.Add([string]$line)
            if ($progressEnabled -and ([string]$line).StartsWith(
                $ProgressMarkerPrefix,
                [StringComparison]::Ordinal
            )) {
                $progressLineCount += 1
                $progressReceipt = $null
                try {
                    $progressReceipt = (
                        ([string]$line).Substring($ProgressMarkerPrefix.Length) |
                            ConvertFrom-Json -AsHashtable -Depth 20
                    )
                } catch {
                    $protocolFailure = "GODOT_PROGRESS_MARKER_JSON_INVALID"
                    break
                }
                $reportedProgressProcessId = [int]$progressReceipt.process_id
                $progressProcessBindingValid = Test-SporeSporeProcessIsSelfOrDescendant `
                    -RootProcessId $expectedProcessId `
                    -CandidateProcessId $reportedProgressProcessId
                $progressSequence = [int]$progressReceipt.progress_sequence
                if (
                    [string]$progressReceipt.schema_version -cne
                        "sporespore_godot_supervised_progress_v1" -or
                    [string]$progressReceipt.progress_protocol_id -cne
                        "godot_4_7_gdscript_non_evidentiary_progress_v1" -or
                    [string]$progressReceipt.termination_nonce -cne $ExpectedNonce -or
                    -not $progressProcessBindingValid -or
                    $progressSequence -ne ($lastProgressSequence + 1) -or
                    [bool]$progressReceipt.physics_evidence_authority -or
                    [bool]$progressReceipt.physical_acceptance_authority -or
                    [bool]$progressReceipt.release_authority
                ) {
                    $protocolFailure = "GODOT_PROGRESS_MARKER_BINDING_INVALID"
                    break
                }
                $lastProgressSequence = $progressSequence
                $lastProgressAt = [DateTime]::UtcNow
                $progressReceipts.Add($progressReceipt)
                continue
            }
            if (-not ([string]$line).StartsWith(
                $ReadyMarkerPrefix,
                [StringComparison]::Ordinal
            )) {
                continue
            }

            $readyLineCount += 1
            if ($readyLineCount -ne 1) {
                $protocolFailure = "GODOT_READY_MARKER_DUPLICATE"
                break
            }
            try {
                $readyReceipt = ([string]$line).Substring($ReadyMarkerPrefix.Length) |
                    ConvertFrom-Json -AsHashtable -Depth 100
            } catch {
                $protocolFailure = "GODOT_READY_MARKER_JSON_INVALID"
                break
            }
            $reportedProcessId = [int]$readyReceipt.process_id
            if ($null -ne $R10fL15LaunchContext) {
                try {
                    $r10fL15LaunchReceipt = Get-QsdkR10fL15LaunchRelationshipReceipt `
                        -Context $R10fL15LaunchContext `
                        -RootProcessId $expectedProcessId `
                        -WorkerProcessId $readyReceipt.process_id `
                        -StartedUtc $started.ToString('o') `
                        -ReadyLine ([string]$line) -ReadyReceipt $readyReceipt
                    $processBindingValid = $r10fL15LaunchReceipt.ok -eq $true
                } catch {
                    $protocolFailure = 'GODOT_R10F_L15_LAUNCH_RELATIONSHIP_INVALID:' + $_.Exception.Message
                    break
                }
            } else {
                $processBindingValid = Test-SporeSporeProcessIsSelfOrDescendant `
                    -RootProcessId $expectedProcessId `
                    -CandidateProcessId $reportedProcessId
            }
            if (
                [string]$readyReceipt.schema_version -cne
                    "sporespore_godot_supervised_termination_ready_v1" -or
                [string]$readyReceipt.termination_protocol_id -cne
                    "godot_4_7_gdscript_shutdown_containment_v1" -or
                [string]$readyReceipt.termination_nonce -cne $ExpectedNonce -or
                -not $processBindingValid -or
                -not [bool]$readyReceipt.worker_receipt_emitted -or
                [int]$readyReceipt.requested_exit_code -notin @(0, 1)
            ) {
                $protocolFailure = "GODOT_READY_MARKER_BINDING_INVALID"
                break
            }

            try {
                $process.Kill($true)
                $supervisorTerminated = $true
            } catch {
                $protocolFailure = "GODOT_READY_PROCESS_TERMINATION_FAILED"
            }
            [void]$process.WaitForExit(10000)
            break
        }

        if (-not $process.HasExited) {
            try { $process.Kill($true) } catch {}
            [void]$process.WaitForExit(10000)
        }

        $remainingStdout = $process.StandardOutput.ReadToEnd()
        if (-not [string]::IsNullOrEmpty($remainingStdout)) {
            foreach ($remainingLine in @($remainingStdout -split "`r?`n")) {
                if (-not [string]::IsNullOrEmpty($remainingLine)) {
                    $stdoutLines.Add([string]$remainingLine)
                }
            }
        }
        $stderr = $stderrTask.GetAwaiter().GetResult()
        $hostExitCode = if ($process.HasExited) { [int]$process.ExitCode } else { 124 }
        $protocolValid = (
            -not $timedOut -and
            [string]::IsNullOrEmpty($protocolFailure) -and
            $readyLineCount -eq 1 -and
            $null -ne $readyReceipt -and
            $supervisorTerminated
        )
        $semanticExitCode = if ($protocolValid) {
            [int]$readyReceipt.requested_exit_code
        } elseif ($timedOut) {
            124
        } else {
            $hostExitCode
        }
        $runResult = [pscustomobject][ordered]@{
            exit_code = $semanticExitCode
            host_exit_code = $hostExitCode
            timed_out = $timedOut
            timeout_kind = $timeoutKind
            stdout = ($stdoutLines -join "`n") + $(if ($stdoutLines.Count) { "`n" } else { "" })
            stderr = $stderr
            started_utc = $started.ToString("o")
            completed_utc = [DateTime]::UtcNow.ToString("o")
            process_id = $expectedProcessId
            worker_process_id = if ($null -ne $readyReceipt) {
                [int]$readyReceipt.process_id
            } else {
                0
            }
            supervisor_terminated = $supervisorTerminated
            termination_protocol_valid = $protocolValid
            termination_protocol_failure_code = $protocolFailure
            termination_ready_receipt = $readyReceipt
            progress_marker_count = $progressLineCount
            progress_binding_valid = (
                -not $progressEnabled -or
                ($progressLineCount -eq $progressReceipts.Count -and
                    -not $protocolFailure.StartsWith(
                        "GODOT_PROGRESS_",
                        [StringComparison]::Ordinal
                    ))
            )
            progress_receipts = @($progressReceipts)
            progress_stall_timeout_seconds = $ProgressStallTimeoutSeconds
            total_timeout_seconds = $TimeoutSeconds
        }
        # Default callers retain the exact legacy shape. Only the explicit
        # R10F successor gains a structured live relationship receipt.
        if ($null -ne $R10fL15LaunchContext) {
            $runResult | Add-Member -NotePropertyName r10f_l15_launch_relationship `
                -NotePropertyValue $r10fL15LaunchReceipt
        }
        return $runResult
    } finally {
        $process.Dispose()
    }
}
