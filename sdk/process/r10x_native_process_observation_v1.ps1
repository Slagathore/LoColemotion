#requires -Version 7.5
# Explicit R10X opt-in: dot-source after the unchanged L15 producer and launcher.
# Loading this module starts no process or world. No R10W selector loads it.
if (-not ('SporeSpore.R10X.ProcessObservationV1' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.ComponentModel;
using System.Runtime.InteropServices;
using System.Text;

namespace SporeSpore.R10X {
    public sealed class ProcessNodeV1 {
        public int ProcessId;
        public int ParentProcessId;
        public long CreationFileTime;
        public string ExecutablePath;
    }

    public static class ProcessObservationV1 {
        const uint QueryLimitedInformation = 0x1000;
        const uint Synchronize = 0x100000;
        const uint SnapshotProcesses = 2;
        const uint WaitTimeout = 258;
        static readonly IntPtr InvalidHandle = new IntPtr(-1);

        [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
        struct ProcessEntry {
            public uint Size;
            public uint Usage;
            public uint ProcessId;
            public UIntPtr DefaultHeapId;
            public uint ModuleId;
            public uint Threads;
            public uint ParentProcessId;
            public int BasePriority;
            public uint Flags;
            [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 260)]
            public string ExecutableName;
        }

        [DllImport("kernel32.dll", SetLastError = true)]
        static extern IntPtr OpenProcess(uint access, bool inherit, uint pid);
        [DllImport("kernel32.dll", SetLastError = true)]
        static extern bool CloseHandle(IntPtr handle);
        [DllImport("kernel32.dll", SetLastError = true)]
        static extern uint GetProcessId(IntPtr process);
        [DllImport("kernel32.dll", SetLastError = true)]
        static extern uint WaitForSingleObject(IntPtr handle, uint milliseconds);
        [DllImport("kernel32.dll", SetLastError = true)]
        static extern bool GetProcessTimes(IntPtr process, out long created,
            out long exited, out long kernel, out long user);
        [DllImport("kernel32.dll", CharSet = CharSet.Unicode, ExactSpelling = true, SetLastError = true)]
        static extern bool QueryFullProcessImageNameW(IntPtr process, uint flags,
            StringBuilder path, ref uint length);
        [DllImport("kernel32.dll", SetLastError = true)]
        static extern IntPtr CreateToolhelp32Snapshot(uint flags, uint pid);
        [DllImport("kernel32.dll", CharSet = CharSet.Unicode, ExactSpelling = true, SetLastError = true)]
        static extern bool Process32FirstW(IntPtr snapshot, ref ProcessEntry entry);
        [DllImport("kernel32.dll", CharSet = CharSet.Unicode, ExactSpelling = true, SetLastError = true)]
        static extern bool Process32NextW(IntPtr snapshot, ref ProcessEntry entry);
        [DllImport("kernel32.dll")]
        static extern IntPtr GetCurrentProcess();
        [DllImport("kernel32.dll", SetLastError = true)]
        static extern bool GetProcessHandleCount(IntPtr process, out uint count);

        static Exception Failure(string code) {
            return new InvalidOperationException(code + ":" + Marshal.GetLastWin32Error());
        }

        static void RequireLive(IntPtr handle, int pid) {
            // The pinned object must still be running; a PID alone is insufficient.
            if (GetProcessId(handle) != (uint)pid || WaitForSingleObject(handle, 0) != WaitTimeout)
                throw Failure("PROCESS_UNAVAILABLE");
        }

        public static uint CurrentHandleCount() {
            uint count;
            if (!GetProcessHandleCount(GetCurrentProcess(), out count))
                throw Failure("HANDLE_COUNT_UNAVAILABLE");
            return count;
        }

        public static ProcessNodeV1 Read(int pid) {
            if (pid <= 0) throw new ArgumentOutOfRangeException("pid");
            IntPtr process = OpenProcess(QueryLimitedInformation | Synchronize, false, (uint)pid);
            if (process == IntPtr.Zero) throw Failure("PROCESS_UNAVAILABLE");
            try {
                RequireLive(process, pid);
                long created, exited, kernel, user;
                if (!GetProcessTimes(process, out created, out exited, out kernel, out user) || created <= 0)
                    throw Failure("PROCESS_SOURCE_UNREADABLE");
                var image = new StringBuilder(32768);
                uint imageLength = (uint)image.Capacity;
                if (!QueryFullProcessImageNameW(process, 0, image, ref imageLength) || imageLength == 0)
                    throw Failure("PROCESS_IMAGE_UNREADABLE");

                // The process handle stays open throughout snapshot enumeration.
                // If the process exits, the final liveness check refuses the sample.
                IntPtr snapshot = CreateToolhelp32Snapshot(SnapshotProcesses, 0);
                if (snapshot == InvalidHandle || snapshot == IntPtr.Zero)
                    throw Failure("PROCESS_SNAPSHOT_UNAVAILABLE");
                uint parent = 0;
                bool found = false;
                try {
                    var entry = new ProcessEntry();
                    entry.Size = (uint)Marshal.SizeOf(typeof(ProcessEntry));
                    bool available = Process32FirstW(snapshot, ref entry);
                    while (available) {
                        if (entry.ProcessId == (uint)pid) {
                            parent = entry.ParentProcessId;
                            found = true;
                            break;
                        }
                        available = Process32NextW(snapshot, ref entry);
                    }
                    if (!found) throw Failure("PROCESS_UNAVAILABLE");
                } finally {
                    if (!CloseHandle(snapshot)) throw Failure("SNAPSHOT_CLOSE_FAILED");
                }
                RequireLive(process, pid);
                long confirmed;
                if (!GetProcessTimes(process, out confirmed, out exited, out kernel, out user) || confirmed != created)
                    throw Failure("PROCESS_IDENTITY_CHANGED");
                if (parent > Int32.MaxValue) throw new InvalidOperationException("PARENT_PID_RANGE");
                return new ProcessNodeV1 {
                    ProcessId = pid, ParentProcessId = (int)parent,
                    CreationFileTime = created, ExecutablePath = image.ToString()
                };
            } finally {
                if (!CloseHandle(process)) throw Failure("PROCESS_CLOSE_FAILED");
            }
        }
    }
}
'@
}

function Get-SporeSporeNativeProcessNodeV1 {
    param([Parameter(Mandatory)][int]$ProcessId)
    $observed = [SporeSpore.R10X.ProcessObservationV1]::Read($ProcessId)
    return [ordered]@{
        process_id = $observed.ProcessId
        parent_process_id = $observed.ParentProcessId
        created_utc = [DateTime]::FromFileTimeUtc($observed.CreationFileTime).ToString('o')
        executable_path = [IO.Path]::GetFullPath($observed.ExecutablePath).Replace('\', '/')
    }
}

function Get-QsdkR10fL15ObservedProcessNode {
    param([int]$ProcessId)
    try { return Get-SporeSporeNativeProcessNodeV1 -ProcessId $ProcessId }
    catch { throw ('QSDK_R10F_L15_LAUNCH_PROCESS_UNAVAILABLE:' + $_.Exception.Message) }
}

function Test-SporeSporeProcessIsSelfOrDescendant {
    param([Parameter(Mandatory)][int]$RootProcessId,
          [Parameter(Mandatory)][int]$CandidateProcessId)
    if ($RootProcessId -le 0 -or $CandidateProcessId -le 0) { return $false }
    $cursor = $CandidateProcessId
    $seen = [Collections.Generic.HashSet[int]]::new()
    $childCreated = $null
    for ($depth = 0; $depth -lt 16; $depth++) {
        if ($cursor -le 0 -or -not $seen.Add($cursor)) { return $false }
        try { $node = Get-SporeSporeNativeProcessNodeV1 -ProcessId $cursor }
        catch { return $false }
        $created = [DateTime]::Parse($node.created_utc, [Globalization.CultureInfo]::InvariantCulture,
            [Globalization.DateTimeStyles]::RoundtripKind)
        if ($null -ne $childCreated -and $created -gt $childCreated) { return $false }
        if ($cursor -eq $RootProcessId) { return $true }
        $childCreated = $created
        $cursor = $node.parent_process_id
    }
    return $false
}
