#requires -Version 7.0

$script:ProcessRunnerContainmentHostPath = Join-Path (
    $PSScriptRoot
) "process_runner_containment_host.ps1"

if (-not ("SporeSporeProcessRunnerJob" -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.ComponentModel;
using System.Diagnostics;
using System.Runtime.InteropServices;

public static class SporeSporeProcessRunnerJob
{
    private const UInt32 JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE = 0x00002000;
    private const Int32 JobObjectExtendedLimitInformation = 9;

    [StructLayout(LayoutKind.Sequential)]
    private struct JOBOBJECT_BASIC_LIMIT_INFORMATION
    {
        public Int64 PerProcessUserTimeLimit;
        public Int64 PerJobUserTimeLimit;
        public UInt32 LimitFlags;
        public UIntPtr MinimumWorkingSetSize;
        public UIntPtr MaximumWorkingSetSize;
        public UInt32 ActiveProcessLimit;
        public UIntPtr Affinity;
        public UInt32 PriorityClass;
        public UInt32 SchedulingClass;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct IO_COUNTERS
    {
        public UInt64 ReadOperationCount;
        public UInt64 WriteOperationCount;
        public UInt64 OtherOperationCount;
        public UInt64 ReadTransferCount;
        public UInt64 WriteTransferCount;
        public UInt64 OtherTransferCount;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct JOBOBJECT_EXTENDED_LIMIT_INFORMATION
    {
        public JOBOBJECT_BASIC_LIMIT_INFORMATION BasicLimitInformation;
        public IO_COUNTERS IoInfo;
        public UIntPtr ProcessMemoryLimit;
        public UIntPtr JobMemoryLimit;
        public UIntPtr PeakProcessMemoryUsed;
        public UIntPtr PeakJobMemoryUsed;
    }

    [DllImport("kernel32.dll", CharSet = CharSet.Unicode,
        SetLastError = true)]
    private static extern IntPtr CreateJobObject(
        IntPtr jobAttributes,
        String name);

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern Boolean SetInformationJobObject(
        IntPtr job,
        Int32 informationClass,
        IntPtr information,
        UInt32 informationLength);

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern Boolean AssignProcessToJobObject(
        IntPtr job,
        IntPtr process);

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern Boolean CloseHandle(IntPtr handle);

    public static IntPtr CreateKillOnClose()
    {
        IntPtr job = CreateJobObject(IntPtr.Zero, null);
        if (job == IntPtr.Zero)
        {
            throw new Win32Exception(
                Marshal.GetLastWin32Error(),
                "CreateJobObject failed.");
        }

        JOBOBJECT_EXTENDED_LIMIT_INFORMATION information =
            new JOBOBJECT_EXTENDED_LIMIT_INFORMATION();
        information.BasicLimitInformation.LimitFlags =
            JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE;
        Int32 size = Marshal.SizeOf(information);
        IntPtr buffer = Marshal.AllocHGlobal(size);
        try
        {
            Marshal.StructureToPtr(information, buffer, false);
            if (!SetInformationJobObject(
                job,
                JobObjectExtendedLimitInformation,
                buffer,
                (UInt32)size))
            {
                Int32 error = Marshal.GetLastWin32Error();
                CloseHandle(job);
                throw new Win32Exception(
                    error,
                    "SetInformationJobObject failed.");
            }
        }
        finally
        {
            Marshal.FreeHGlobal(buffer);
        }
        return job;
    }

    public static void Assign(IntPtr job, Int32 processId)
    {
        using (Process process = Process.GetProcessById(processId))
        {
            if (!AssignProcessToJobObject(job, process.Handle))
            {
                throw new Win32Exception(
                    Marshal.GetLastWin32Error(),
                    "AssignProcessToJobObject failed.");
            }
        }
    }

    public static void Close(IntPtr job)
    {
        if (job != IntPtr.Zero && !CloseHandle(job))
        {
            throw new Win32Exception(
                Marshal.GetLastWin32Error(),
                "CloseHandle(job) failed.");
        }
    }
}
'@
}


function New-ProcessRunnerControlDirectory {
    $basePath = Join-Path (
        [System.IO.Path]::GetTempPath()
    ) "sporespore_process_runner_control_v1"
    if (-not (Test-Path -LiteralPath $basePath -PathType Container)) {
        [void][System.IO.Directory]::CreateDirectory($basePath)
    }
    $baseInfo = [System.IO.DirectoryInfo]::new($basePath)
    if (
        (
            $baseInfo.Attributes -band
            [System.IO.FileAttributes]::ReparsePoint
        ) -ne 0
    ) {
        throw "Process-runner control root cannot be a reparse point."
    }

    $path = Join-Path $basePath (
        "control-" + [System.Guid]::NewGuid().ToString("N")
    )
    $directory = [System.IO.DirectoryInfo]::new($path)
    $directory.Create()
    if (
        (
            $directory.Attributes -band
            [System.IO.FileAttributes]::ReparsePoint
        ) -ne 0
    ) {
        throw "Process-runner control directory cannot be a reparse point."
    }

    # The exit marker is process-control authority, not evidence output.
    # Protect it from other local accounts and from any writer limited to the
    # caller's transcript/evidence directory.
    $owner = [System.Security.Principal.WindowsIdentity]::GetCurrent().User
    $system = [System.Security.Principal.SecurityIdentifier]::new(
        "S-1-5-18"
    )
    $inheritance = (
        [System.Security.AccessControl.InheritanceFlags]::ContainerInherit -bor
        [System.Security.AccessControl.InheritanceFlags]::ObjectInherit
    )
    $security = [System.Security.AccessControl.DirectorySecurity]::new()
    $security.SetAccessRuleProtection($true, $false)
    $security.SetOwner($owner)
    foreach ($identity in @($owner, $system)) {
        $rule = [System.Security.AccessControl.FileSystemAccessRule]::new(
            $identity,
            [System.Security.AccessControl.FileSystemRights]::FullControl,
            $inheritance,
            [System.Security.AccessControl.PropagationFlags]::None,
            [System.Security.AccessControl.AccessControlType]::Allow
        )
        [void]$security.AddAccessRule($rule)
    }
    try {
        [System.IO.FileSystemAclExtensions]::SetAccessControl(
            $directory,
            $security
        )
    } catch {
        # No control authority has been written yet. Remove the empty
        # reservation so a sandbox/ACL denial leaves no accumulating debris.
        if (
            $directory.Exists -and
            $directory.GetFiles().Count -eq 0 -and
            $directory.GetDirectories().Count -eq 0
        ) {
            $directory.Delete()
        }
        throw
    }
    return $directory.FullName
}


function Remove-ProcessRunnerControlDirectory {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return
    }
    $resolved = [System.IO.Path]::GetFullPath($Path)
    $basePath = [System.IO.Path]::GetFullPath(
        (Join-Path (
            [System.IO.Path]::GetTempPath()
        ) "sporespore_process_runner_control_v1")
    ).TrimEnd("\", "/")
    if (
        -not $resolved.StartsWith(
            $basePath + [System.IO.Path]::DirectorySeparatorChar,
            [System.StringComparison]::OrdinalIgnoreCase
        ) -or
        -not ([System.IO.Path]::GetFileName($resolved) -match
            '^control-[a-f0-9]{32}$')
    ) {
        throw "Refusing to remove an unowned process-runner control path."
    }
    if (-not [System.IO.Directory]::Exists($resolved)) {
        return
    }
    $directory = [System.IO.DirectoryInfo]::new($resolved)
    if (
        (
            $directory.Attributes -band
            [System.IO.FileAttributes]::ReparsePoint
        ) -ne 0 -or
        $directory.GetDirectories().Count -ne 0
    ) {
        throw "Process-runner control directory shape changed."
    }
    foreach ($file in $directory.GetFiles()) {
        $file.Delete()
    }
    $directory.Delete()
}


function Invoke-ProcessWithTimeout {
    <#
    .SYNOPSIS
    Runs one native process with a bounded lifetime and complete output capture.

    .DESCRIPTION
    The requested target runs inside a Windows Job Object configured with
    JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE. A host waits for the job assignment
    before starting the target, eliminating the start-before-containment race.
    When the target exits, it publishes the real exit code into a random,
    owner-only control directory outside caller output. Closing the job then
    terminates the host and every surviving descendant, including an orphan
    that inherited stdout/stderr after its immediate parent exited.

    The target deadline and the fixed three-second termination/output-drain
    grace are both bounded. No parameterless WaitForExit or unbounded Task
    result is used by the owner.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$FilePath,

        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [string[]]$ArgumentList,

        [Parameter(Mandatory = $true)]
        [ValidateRange(1, 86400)]
        [int]$TimeoutSeconds,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$TranscriptPath
    )

    $transcriptDirectory = Split-Path -Parent $TranscriptPath
    if (
        -not [string]::IsNullOrWhiteSpace($transcriptDirectory) -and
        -not (Test-Path -LiteralPath $transcriptDirectory -PathType Container)
    ) {
        New-Item -ItemType Directory -Path $transcriptDirectory -Force |
            Out-Null
    }
    if (-not (
        Test-Path `
            -LiteralPath $script:ProcessRunnerContainmentHostPath `
            -PathType Leaf
    )) {
        throw (
            "Process-runner containment host not found: " +
            $script:ProcessRunnerContainmentHostPath
        )
    }

    $controlDirectory = New-ProcessRunnerControlDirectory
    $exitMarkerPath = Join-Path $controlDirectory "target-exit.json"
    $readyMarkerPath = Join-Path $controlDirectory "job-ready.nonce"
    $nonceBytes = [byte[]]::new(32)
    [System.Security.Cryptography.RandomNumberGenerator]::Fill($nonceBytes)
    $controlNonce = [System.Convert]::ToHexString(
        $nonceBytes
    ).ToLowerInvariant()
    $argumentJson = ConvertTo-Json `
        -InputObject ([object[]]@($ArgumentList)) `
        -Compress `
        -Depth 4
    $argumentsBase64 = [System.Convert]::ToBase64String(
        [System.Text.Encoding]::UTF8.GetBytes($argumentJson)
    )

    $powerShellExecutable = Join-Path $PSHOME "pwsh.exe"
    if (-not (Test-Path -LiteralPath $powerShellExecutable -PathType Leaf)) {
        throw "PowerShell 7 executable not found: $powerShellExecutable"
    }
    $startInfo = [System.Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = $powerShellExecutable
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    foreach ($argument in @(
        "-NoLogo",
        "-NoProfile",
        "-NonInteractive",
        "-ExecutionPolicy",
        "Bypass",
        "-File",
        $script:ProcessRunnerContainmentHostPath,
        "-FilePath",
        $FilePath,
        "-ArgumentsBase64",
        $argumentsBase64,
        "-ExitMarkerPath",
        $exitMarkerPath,
        "-ReadyMarkerPath",
        $readyMarkerPath,
        "-ControlNonce",
        $controlNonce
    )) {
        [void]$startInfo.ArgumentList.Add($argument)
    }

    $process = [System.Diagnostics.Process]::new()
    $process.StartInfo = $startInfo
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    $stdoutTask = $null
    $stderrTask = $null
    $stdoutText = ""
    $stderrText = ""
    $startError = ""
    $terminationError = ""
    $timedOut = $false
    $killedProcessTree = $false
    $containmentTreeClosed = $false
    $started = $false
    $exitCode = [int]::MinValue
    $markerObserved = $false
    $hostProcessId = [int64]0
    $targetProcessId = [int64]0
    $targetStartedUtc = ""
    $targetEndedUtc = ""
    $jobHandle = [IntPtr]::Zero
    $terminationGraceMilliseconds = 3000

    try {
        $jobHandle = [SporeSporeProcessRunnerJob]::CreateKillOnClose()
        $started = $process.Start()
        if (-not $started) {
            throw "System.Diagnostics.Process.Start returned false."
        }
        $hostProcessId = [int64]$process.Id
        $stdoutTask = $process.StandardOutput.ReadToEndAsync()
        $stderrTask = $process.StandardError.ReadToEndAsync()

        # The host cannot start the target until this assignment completes.
        [SporeSporeProcessRunnerJob]::Assign($jobHandle, $process.Id)
        $utf8NoBom = [System.Text.UTF8Encoding]::new($false)
        $readyBytes = $utf8NoBom.GetBytes($controlNonce)
        $readyFile = [System.IO.FileStream]::new(
            $readyMarkerPath,
            [System.IO.FileMode]::CreateNew,
            [System.IO.FileAccess]::Write,
            [System.IO.FileShare]::Read
        )
        try {
            $readyFile.Write($readyBytes, 0, $readyBytes.Length)
            $readyFile.Flush($true)
        } finally {
            $readyFile.Dispose()
        }

        $deadlineMilliseconds = [int64]$TimeoutSeconds * 1000
        while ($stopwatch.ElapsedMilliseconds -lt $deadlineMilliseconds) {
            if (Test-Path -LiteralPath $exitMarkerPath -PathType Leaf) {
                $markerObserved = $true
                break
            }
            if ($process.HasExited) {
                $startError = (
                    "Process-runner containment host exited before " +
                    "publishing the target exit marker. host_exit=" +
                    $process.ExitCode
                )
                break
            }
            $remaining = (
                $deadlineMilliseconds - $stopwatch.ElapsedMilliseconds
            )
            Start-Sleep -Milliseconds ([int][Math]::Min(25, $remaining))
        }
        if (-not $markerObserved -and [string]::IsNullOrWhiteSpace(
            $startError
        )) {
            $timedOut = $true
        }

        if ($markerObserved) {
            try {
                $marker = Get-Content `
                    -LiteralPath $exitMarkerPath `
                    -Raw `
                    -ErrorAction Stop |
                    ConvertFrom-Json -ErrorAction Stop
                $markerTargetStarted = $marker.target_started -eq $true
                if (
                    $marker.schema -cne
                        "sporespore.process_runner_exit.v1" -or
                    [int64]$marker.host_process_id -ne [int64]$process.Id -or
                    [int64]$marker.target_process_id -lt 0 -or
                    $marker.control_nonce -cne $controlNonce
                ) {
                    throw "Target exit marker identity is invalid."
                }
                $targetProcessId = [int64]$marker.target_process_id
                if (-not $markerTargetStarted) {
                    $startError = [string]$marker.target_start_error
                    if ([string]::IsNullOrWhiteSpace($startError)) {
                        $startError = (
                            "Target failed to start without an error record."
                        )
                    }
                } else {
                    if (
                        $targetProcessId -lt 1 -or
                        $targetProcessId -eq [int64]$process.Id -or
                        [string]::IsNullOrWhiteSpace(
                            [string]$marker.target_started_utc
                        ) -or
                        [string]::IsNullOrWhiteSpace(
                            [string]$marker.target_ended_utc
                        ) -or
                        -not ([string]$marker.target_started_utc).StartsWith(
                            "utc:",
                            [System.StringComparison]::Ordinal
                        ) -or
                        -not ([string]$marker.target_ended_utc).StartsWith(
                            "utc:",
                            [System.StringComparison]::Ordinal
                        )
                    ) {
                        throw "Started target process witness is incomplete."
                    }
                    $targetStartedInstant = [DateTimeOffset]::Parse(
                        ([string]$marker.target_started_utc).Substring(4)
                    )
                    $targetEndedInstant = [DateTimeOffset]::Parse(
                        ([string]$marker.target_ended_utc).Substring(4)
                    )
                    if ($targetEndedInstant -lt $targetStartedInstant) {
                        throw "Target process time window is reversed."
                    }
                    $targetStartedUtc = $targetStartedInstant.UtcDateTime.
                        ToString("o")
                    $targetEndedUtc = $targetEndedInstant.UtcDateTime.
                        ToString("o")
                    $exitCode = [int]$marker.target_exit_code
                }
            } catch {
                $startError = (
                    "Target exit marker could not be validated. " +
                    $_.Exception.ToString()
                )
            }
        }

        # Closing the kill-on-close job is the authoritative tree shutdown.
        [SporeSporeProcessRunnerJob]::Close($jobHandle)
        $jobHandle = [IntPtr]::Zero
        $containmentTreeClosed = $true
        if ($timedOut) {
            $killedProcessTree = $true
        }

        if (
            -not $process.HasExited -and
            -not $process.WaitForExit($terminationGraceMilliseconds)
        ) {
            $terminationError += (
                "Contained process tree did not exit within the fixed " +
                "$terminationGraceMilliseconds-ms termination grace."
            )
        }
        $outputCompleted = [System.Threading.Tasks.Task]::WaitAll(
            [System.Threading.Tasks.Task[]]@($stdoutTask, $stderrTask),
            $terminationGraceMilliseconds
        )
        if (-not $outputCompleted) {
            $terminationError += (
                [Environment]::NewLine +
                "Contained output streams did not close within the fixed " +
                "$terminationGraceMilliseconds-ms drain grace."
            )
        } else {
            $stdoutText = $stdoutTask.GetAwaiter().GetResult()
            $stderrText = $stderrTask.GetAwaiter().GetResult()
        }
    } catch {
        if ([string]::IsNullOrWhiteSpace($startError)) {
            $startError = $_.Exception.ToString()
        }
        if ($jobHandle -ne [IntPtr]::Zero) {
            try {
                [SporeSporeProcessRunnerJob]::Close($jobHandle)
                $jobHandle = [IntPtr]::Zero
                $containmentTreeClosed = $started
                if ($timedOut -and $started) {
                    $killedProcessTree = $true
                }
            } catch {
                $terminationError += (
                    [Environment]::NewLine +
                    $_.Exception.ToString()
                )
            }
        }
        if (
            $started -and
            -not $process.HasExited
        ) {
            try {
                $process.Kill($true)
                [void]$process.WaitForExit($terminationGraceMilliseconds)
            } catch {
                $terminationError += (
                    [Environment]::NewLine +
                    $_.Exception.ToString()
                )
            }
        }
        if ($null -ne $stdoutTask -and $stdoutTask.IsCompleted) {
            $stdoutText = $stdoutTask.GetAwaiter().GetResult()
        }
        if ($null -ne $stderrTask -and $stderrTask.IsCompleted) {
            $stderrText = $stderrTask.GetAwaiter().GetResult()
        }
    } finally {
        if ($jobHandle -ne [IntPtr]::Zero) {
            try {
                [SporeSporeProcessRunnerJob]::Close($jobHandle)
                $containmentTreeClosed = $started
            } catch {
                $terminationError += (
                    [Environment]::NewLine +
                    $_.Exception.ToString()
                )
            }
        }
        $process.Dispose()
        try {
            Remove-ProcessRunnerControlDirectory -Path $controlDirectory
        } catch {
            $terminationError += (
                [Environment]::NewLine +
                "Process-runner control cleanup failed. " +
                $_.Exception.ToString()
            )
        }
    }

    $terminationError = $terminationError.Trim()
    $sections = [System.Collections.Generic.List[string]]::new()
    if (-not [string]::IsNullOrEmpty($stdoutText)) {
        $sections.Add($stdoutText.TrimEnd("`r", "`n"))
    }
    if (-not [string]::IsNullOrEmpty($stderrText)) {
        $sections.Add($stderrText.TrimEnd("`r", "`n"))
    }
    if ($timedOut) {
        $sections.Add(
            "HARNESS_TIMEOUT seconds=$TimeoutSeconds process_tree_killed=$killedProcessTree"
        )
    }
    if (-not [string]::IsNullOrWhiteSpace($startError)) {
        $sections.Add("HARNESS_PROCESS_FAILURE $startError")
    }
    if (-not [string]::IsNullOrWhiteSpace($terminationError)) {
        $sections.Add("HARNESS_TERMINATION_FAILURE $terminationError")
    }
    $combinedText = $sections -join [Environment]::NewLine
    Set-Content `
        -LiteralPath $TranscriptPath `
        -Value $combinedText `
        -Encoding utf8
    $outputLines = if ([string]::IsNullOrEmpty($combinedText)) {
        @()
    } else {
        @([regex]::Split($combinedText, "\r?\n"))
    }
    $stopwatch.Stop()

    return [pscustomobject]@{
        ExitCode = [int]$exitCode
        TimedOut = [bool]$timedOut
        TimeoutSeconds = [int]$TimeoutSeconds
        KilledProcessTree = [bool]$killedProcessTree
        ContainmentTreeClosed = [bool]$containmentTreeClosed
        ExitMarkerObserved = [bool]$markerObserved
        HostProcessId = [int64]$hostProcessId
        TargetProcessId = [int64]$targetProcessId
        TargetStartedUtc = [string]$targetStartedUtc
        TargetEndedUtc = [string]$targetEndedUtc
        StartError = [string]$startError
        TerminationError = [string]$terminationError
        DurationMs = [int64]$stopwatch.ElapsedMilliseconds
        Lines = $outputLines
        Text = $combinedText
        Stdout = $stdoutText
        Stderr = $stderrText
        TranscriptPath = $TranscriptPath
    }
}
