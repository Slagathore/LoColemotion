// Test-only batch around the real loaded observer. This contains no alternate
// identity implementation and does not load or launch another process.
using System;
using System.Diagnostics;
using System.Reflection;
using System.Runtime.InteropServices;

public sealed class R10XNativeHandleSample {
    public uint Before;
    public uint After;
    public int SuccessfulReads;
    public double Seconds;
}

public static class R10XNativeHandleProbe {
    [DllImport("kernel32.dll")]
    static extern IntPtr GetCurrentProcess();
    [DllImport("kernel32.dll", SetLastError = true)]
    static extern bool GetProcessHandleCount(IntPtr process, out uint count);

    static uint Count() {
        uint count;
        if (!GetProcessHandleCount(GetCurrentProcess(), out count))
            throw new InvalidOperationException("R10X_TEST_HANDLE_COUNT_FAILED");
        return count;
    }

    public static R10XNativeHandleSample Run(int pid, int samples) {
        if (samples < 1 || samples > 100) throw new ArgumentOutOfRangeException("samples");
        Type observer = null;
        foreach (Assembly assembly in AppDomain.CurrentDomain.GetAssemblies()) {
            observer = assembly.GetType("SporeSpore.R10X.ProcessObservationV1", false);
            if (observer != null) break;
        }
        if (observer == null) throw new InvalidOperationException("R10X_OBSERVER_NOT_LOADED");
        MethodInfo read = observer.GetMethod("Read", BindingFlags.Public | BindingFlags.Static);
        object[] arguments = { pid };
        // Warm reflection and the observer before measuring. Unlike a PS loop,
        // this batch does not compile new PowerShell invocation scopes per call.
        for (int index = 0; index < 16; index++) read.Invoke(null, arguments);
        GC.Collect(); GC.WaitForPendingFinalizers(); GC.Collect();
        var result = new R10XNativeHandleSample { Before = Count() };
        var timer = Stopwatch.StartNew();
        for (int index = 0; index < samples; index++) {
            read.Invoke(null, arguments);
            result.SuccessfulReads++;
        }
        timer.Stop();
        result.After = Count();
        result.Seconds = timer.Elapsed.TotalSeconds;
        return result;
    }
}
