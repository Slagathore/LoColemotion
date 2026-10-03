# Durable progress for the owned R10V supervisor. No retry or reconstruction.
function Initialize-R10VHostProgress([string]$RequestPath, $Context) {
    $script:R10VProgressRequest=Get-Content -LiteralPath $RequestPath -Raw | ConvertFrom-Json -AsHashtable
    $script:R10VProgressRoot=Split-Path -Parent $RequestPath
    $script:R10VProgressContext=$Context
    $script:R10VProgressSequence=0
    if (Test-Path -LiteralPath (Join-Path $script:R10VProgressRoot 'progress.jsonl')) { throw 'R10V_PROGRESS_ALREADY_EXISTS' }
}
function Write-R10VHostProgress([string]$Stage, [string]$State, [string]$Role='', $Subject=$null) {
    if ($State -notin @('start','end') -or $Stage -notin @('interface','interface_python','safety_gate','child','replay','final_audit','publication')) { throw 'R10V_PROGRESS_STAGE' }
    if ($PID -ne $script:R10VProgressContext.supervisor_identity.pid) { throw 'R10V_PROGRESS_OWNER' }
    $value=[ordered]@{schema_version='sporespore_r10v_host_progress_v1';sequence=$script:R10VProgressSequence;
        utc=[DateTime]::UtcNow.ToString('o');stage=$Stage;state=$State;role=$Role;subject=$Subject;
        context=$script:R10VProgressContext;source_commit=$script:R10VProgressRequest.source_snapshot.head;
        runtimes=@{python=$script:R10VProgressRequest.python_runtime;powershell=$script:R10VProgressRequest.runtime}}
    $bytes=[Text.Encoding]::UTF8.GetBytes((ConvertTo-SporeSporeExactJson -Value $value)+"`n")
    $stream=[IO.File]::Open((Join-Path $script:R10VProgressRoot 'progress.jsonl'),[IO.FileMode]::Append,[IO.FileAccess]::Write,[IO.FileShare]::Read)
    try { $stream.Write($bytes,0,$bytes.Length); $stream.Flush($true) } finally { $stream.Dispose() }
    $script:R10VProgressSequence++
}
function Invoke-R10VHostPython([string[]]$Arguments, [string]$Stage, [string]$Role, [string]$OutputBase, [int]$TimeoutSeconds) {
    $expected=if ($Stage -ceq 'replay') { 960 } elseif ($Stage -ceq 'final_audit') { 1800 } elseif ($Stage -ceq 'interface_python') { 30 } else { throw 'R10V_PYTHON_STAGE' }
    if ($TimeoutSeconds -ne $expected) { throw 'R10V_PYTHON_DEADLINE' }
    $start=[Diagnostics.ProcessStartInfo]::new()
    $start.FileName=$script:R10VProgressRequest.python_runtime.path
    $start.WorkingDirectory=$repoRoot
    $start.UseShellExecute=$false; $start.CreateNoWindow=$true
    $start.RedirectStandardOutput=$true; $start.RedirectStandardError=$true
    $start.ArgumentList.Add('-B')
    foreach ($argument in $Arguments) { $start.ArgumentList.Add($argument) }
    $stdout=[IO.File]::Open($OutputBase+'.stdout.txt',[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::Read)
    $stderr=$null; $process=$null; $outCopy=$null; $errCopy=$null; $timedOut=$false
    try {
        $stderr=[IO.File]::Open($OutputBase+'.stderr.txt',[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::Read)
        $process=[Diagnostics.Process]::Start($start)
        $identity=@{pid=$process.Id;creation_filetime=$process.StartTime.ToUniversalTime().ToFileTimeUtc()}
        $outCopy=$process.StandardOutput.BaseStream.CopyToAsync($stdout)
        $errCopy=$process.StandardError.BaseStream.CopyToAsync($stderr)
        Write-R10VHostProgress -Stage $Stage -State start -Role $Role -Subject @{process_identity=$identity;arguments=@($Arguments)}
        $timedOut=-not $process.WaitForExit($TimeoutSeconds*1000)
        if ($timedOut) { $process.Kill($true); $process.WaitForExit() }
        $null = $outCopy.GetAwaiter().GetResult(); $null = $errCopy.GetAwaiter().GetResult()
        $stdout.Flush($true); $stderr.Flush($true)
        $code=$process.ExitCode
    } finally {
        if ($null -ne $process) {
            if (-not $process.HasExited) { $process.Kill($true); $process.WaitForExit() }
            if ($null -ne $outCopy) { $null = $outCopy.GetAwaiter().GetResult() }
            if ($null -ne $errCopy) { $null = $errCopy.GetAwaiter().GetResult() }
            $process.Dispose()
        }
        $stdout.Dispose(); if ($null -ne $stderr) { $stderr.Dispose() }
    }
    $receipt=@{process_identity=$identity;exit_code=$code;timed_out=$timedOut;timeout_seconds=$TimeoutSeconds;
        stdout=(Get-R10fRetainedFileBinding ($OutputBase+'.stdout.txt'));stderr=(Get-R10fRetainedFileBinding ($OutputBase+'.stderr.txt'))}
    Write-JsonCreateNew ($OutputBase+'.execution.json') $receipt
    Write-R10VHostProgress -Stage $Stage -State end -Role $Role -Subject $receipt
    if ($timedOut) { throw ('R10V_PYTHON_TIMEOUT:'+ $Stage) }
    return @{exit_code=$code;output=@([IO.File]::ReadAllLines($OutputBase+'.stdout.txt'))}
}
