#requires -Version 7.5
<#
Fast, non-authoritative real-interface gate. No physical mode exists here.
It runs actual production publication functions, owned host processes, and
the compiled Godot/Rust owner collector with explicitly zero-world fixtures.
This is neither official qualification nor the future bounded physical smoke.
#>
[CmdletBinding()]
param([switch]$Library)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
if ($repoRoot -cne 'C:\Users\Cole\CodeStuff\games\LoColemotion') { throw 'DEVELOPMENT_ROOT' }
if ((& git -C $repoRoot rev-parse --show-toplevel) -cne $repoRoot.Replace('\', '/')) {
    throw 'DEVELOPMENT_GIT_ROOT'
}
if ((& git -C $repoRoot remote get-url origin) -cne 'https://github.com/Slagathore/LoColemotion.git') {
    throw 'DEVELOPMENT_REMOTE'
}
. (Join-Path $PSScriptRoot 'locomotion_operation_lock.ps1')
. (Join-Path $PSScriptRoot 'exact_json_transport.ps1')
$pythonPath = 'C:\Program Files\Python311\python.exe'
$evidenceRoot = 'C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence'
$stages = @(
    @{id='exact_runtime_binding'; pattern='test_qsdk_r10f_l14_runtime_binding.py'; tests=11},
    @{id='host_runtime_successor'; pattern='test_development_host_runtime_successor.py'; tests=3},
    @{id='shared_interface_definitions'; pattern='test_development_shared_interfaces.py'; tests=4},
    @{id='exact_publication'; pattern='test_exact_json_transport.py'; tests=5},
    @{id='production_publication'; pattern='test_qsdk_r10f_l15_publication.py'; tests=8},
    @{id='owned_process_relationship'; pattern='test_qsdk_r10f_l15_launch_relationship.py'; tests=7},
    @{id='godot_rust_owner_contract'; pattern='test_qsdk_r10f_l15_canonical_ownership.py'; tests=2}
)

function Write-DevelopmentFile([string]$Path, [byte[]]$Bytes) {
    $stream = [IO.File]::Open($Path, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::Read)
    try { $stream.Write($Bytes, 0, $Bytes.Length); $stream.Flush($true) }
    finally { $stream.Dispose() }
}

function Get-DevelopmentSourceSnapshot {
    $head = & git -C $repoRoot rev-parse HEAD
    if ($LASTEXITCODE -ne 0) { throw 'DEVELOPMENT_GIT_HEAD' }
    $status = @(& git -C $repoRoot status --porcelain)
    if ($LASTEXITCODE -ne 0) { throw 'DEVELOPMENT_GIT_STATUS' }
    $changed = @(& git -C $repoRoot diff --name-only HEAD)
    if ($LASTEXITCODE -ne 0) { throw 'DEVELOPMENT_GIT_DIFF' }
    $untracked = @(& git -C $repoRoot ls-files --others --exclude-standard)
    if ($LASTEXITCODE -ne 0) { throw 'DEVELOPMENT_GIT_UNTRACKED' }
    $bindings = @(@($changed + $untracked) | Sort-Object -Unique | ForEach-Object {
        $path = Join-Path $repoRoot $_
        [ordered]@{
            path = $_
            exists = Test-Path -LiteralPath $path -PathType Leaf
            sha256 = if (Test-Path -LiteralPath $path -PathType Leaf) {
                (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()
            } else { $null }
        }
    })
    return [ordered]@{head=$head; dirty=($status.Count -ne 0); status=$status; changed_file_bindings=$bindings}
}

function Invoke-DevelopmentStage($Stage, [string]$RunRoot) {
    # A complete multi-process reader suite has an explicit bounded test budget.
    # This changes no worker, solver, recovery or physical-campaign budget.
    $stageTimeoutSeconds = 180
    # R10M's complete preparation reader exceeded 600 s at its last corruption case.
    # The extension applies only to this exact zero-world suite.
    $singleReportStages = @{
        r10v_preparation_refusals='test_development_r10v_preparation_refusals.py'
        r10u_preparation_refusals='test_development_r10u_preparation_refusals.py'
        r10t_preparation_refusals='test_development_r10t_preparation_refusals.py'
        r10v_preparation_positive='test_development_r10v_preparation_positive.py'
        r10u_preparation_positive='test_development_r10u_preparation_positive.py'
        r10t_preparation_positive='test_development_r10t_preparation_positive.py'
        r10v_ready_hold_report='test_development_r10v_ready_hold_report.py'
        r10u_ready_hold_report='test_development_r10u_ready_hold_report.py'
        r10t_ready_hold_report='test_development_r10t_ready_hold_report.py'
        r10v_timeout_hold_report='test_development_r10v_timeout_hold_report.py'
        r10u_timeout_hold_report='test_development_r10u_timeout_hold_report.py'
        r10t_timeout_hold_report='test_development_r10t_timeout_hold_report.py'
    }
    $maximumStageTimeoutSeconds = if (((($Stage.id -ceq 'r10m_preparation_report' -and
        $Stage.pattern -ceq 'test_development_r10m_preparation_report.py') -or ($Stage.id -ceq 'r10n_preparation_report' -and
        $Stage.pattern -ceq 'test_development_r10n_preparation_report.py') -or ($Stage.id -ceq 'r10o_preparation_report' -and
        $Stage.pattern -ceq 'test_development_r10o_preparation_report.py') -or ($Stage.id -ceq 'r10q_preparation_report' -and
        $Stage.pattern -ceq 'test_development_r10q_preparation_report.py') -or ($Stage.id -ceq 'r10r_preparation_report' -and
        $Stage.pattern -ceq 'test_development_r10r_preparation_report.py') -or ($Stage.id -ceq 'r10s_preparation_report' -and
        $Stage.pattern -ceq 'test_development_r10s_preparation_report.py') -or ($Stage.id -ceq 'r10v_preparation_report' -and
        $Stage.pattern -ceq 'test_development_r10v_preparation_report.py') -or ($Stage.id -ceq 'r10u_preparation_report' -and
        $Stage.pattern -ceq 'test_development_r10u_preparation_report.py') -or ($Stage.id -ceq 'r10t_preparation_report' -and
        $Stage.pattern -ceq 'test_development_r10t_preparation_report.py') -or ($Stage.id -ceq 'r10v_complete_hold_report' -and
        $Stage.pattern -ceq 'test_r10v_complete_hold_report.py') -or ($Stage.id -ceq 'r10u_complete_hold_report' -and
        $Stage.pattern -ceq 'test_r10u_complete_hold_report.py') -or ($Stage.id -ceq 'r10t_complete_hold_report' -and
        $Stage.pattern -ceq 'test_r10t_complete_hold_report.py')) -and $Stage.tests -eq 2) -or ($Stage.tests -is [int] -and $Stage.tests -eq 1 -and
        $singleReportStages.Keys -ccontains $Stage.id -and $Stage.pattern -ceq $singleReportStages[$Stage.id])) { 900 } else { 600 }
    if ($Stage.ContainsKey('timeout_seconds')) {
        if ($Stage.timeout_seconds -isnot [int] -or $Stage.timeout_seconds -lt 1 -or $Stage.timeout_seconds -gt $maximumStageTimeoutSeconds) {
            throw 'DEVELOPMENT_STAGE_TIMEOUT_INVALID'
        }
        $stageTimeoutSeconds = $Stage.timeout_seconds
    }
    $stdoutPath = Join-Path $RunRoot ($Stage.id + '.stdout.log')
    $stderrPath = Join-Path $RunRoot ($Stage.id + '.stderr.log')
    $start = [Diagnostics.ProcessStartInfo]::new()
    $start.FileName = $pythonPath
    $start.WorkingDirectory = $repoRoot
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    $start.Environment['PYTHONIOENCODING'] = 'utf-8'
    # Candidate tests use explicit stage-owned data, never an inherited choice.
    $null = $start.Environment.Remove('SPORESPORE_DEVELOPMENT_TEST_CANDIDATE')
    if ($Stage.ContainsKey('candidate_profile')) {
        $start.Environment['SPORESPORE_DEVELOPMENT_TEST_CANDIDATE'] = [string]$Stage.candidate_profile
    }
    foreach ($argument in @('-B','-m','unittest','discover','-s','tests','-p',$Stage.pattern,'-v')) {
        $start.ArgumentList.Add($argument)
    }
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $start
    $out = $null; $err = $null; $outCopy = $null; $errCopy = $null
    $started = $false; $timedOut = $false; $exitCode = -1
    $watch = [Diagnostics.Stopwatch]::StartNew()
    try {
        $out = [IO.File]::Open($stdoutPath, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::Read)
        $err = [IO.File]::Open($stderrPath, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::Read)
        $started = $process.Start()
        if (-not $started) { throw 'DEVELOPMENT_TEST_NOT_STARTED' }
        $outCopy = $process.StandardOutput.BaseStream.CopyToAsync($out)
        $errCopy = $process.StandardError.BaseStream.CopyToAsync($err)
        if (-not $process.WaitForExit($stageTimeoutSeconds * 1000)) {
            $timedOut = $true
            $process.Kill($true)
            $process.WaitForExit()
        }
        $null = $outCopy.GetAwaiter().GetResult()
        $null = $errCopy.GetAwaiter().GetResult()
        $exitCode = $process.ExitCode
    } finally {
        if ($started -and -not $process.HasExited) { $process.Kill($true); $process.WaitForExit() }
        if ($null -ne $out) { $out.Dispose() }
        if ($null -ne $err) { $err.Dispose() }
        $process.Dispose()
        $watch.Stop()
    }
    $strictUtf8 = [Text.UTF8Encoding]::new($false, $true)
    $logs = $strictUtf8.GetString([IO.File]::ReadAllBytes($stdoutPath)) +
            $strictUtf8.GetString([IO.File]::ReadAllBytes($stderrPath))
    $counts = [regex]::Matches($logs, '(?m)^Ran (\d+) tests? in [0-9.]+s\s*$')
    $count = if ($counts.Count -eq 1) { [int]$counts[0].Groups[1].Value } else { 0 }
    $passed = -not $timedOut -and $exitCode -eq 0 -and $count -eq $Stage.tests -and
              [regex]::Matches($logs, '(?m)^OK\s*$').Count -eq 1
    return [ordered]@{
        id=$Stage.id; passed=$passed; test_count=$count; expected_test_count=$Stage.tests
        seconds=$watch.Elapsed.TotalSeconds; exit_code=$exitCode; timed_out=$timedOut
        stdout=[IO.Path]::GetFileName($stdoutPath); stderr=[IO.Path]::GetFileName($stderrPath)
        stdout_sha256=(Get-FileHash -LiteralPath $stdoutPath -Algorithm SHA256).Hash.ToLowerInvariant()
        stderr_sha256=(Get-FileHash -LiteralPath $stderrPath -Algorithm SHA256).Hash.ToLowerInvariant()
    }
}

if ($Library) { return }

$lock = $null; $runRoot = ''; $failure = ''; $completed = [Collections.Generic.List[object]]::new()
$source = $null
$startedUtc = [DateTime]::UtcNow.ToString('o')
try {
    $lock = Enter-SporeSporeLocomotionOperationLock -Role conformance -TimeoutMilliseconds 0
    if (-not $lock.acquired -or $lock.abandoned_owner_recovered) { throw 'DEVELOPMENT_OPERATION_LOCK_BUSY' }
    $source = Get-DevelopmentSourceSnapshot
    $runRoot = Join-Path $evidenceRoot ('development-interfaces-' + [Guid]::NewGuid().ToString('N'))
    $null = New-Item -ItemType Directory -Path $runRoot
    foreach ($stage in $stages) {
        $result = Invoke-DevelopmentStage $stage $runRoot
        $completed.Add($result)
        Write-Output ('DEVELOPMENT_INTERFACE_STAGE ' + (ConvertTo-SporeSporeExactJson -Value $result))
        if (-not $result.passed) { throw ('DEVELOPMENT_STAGE_FAILED:' + $stage.id) }
    }
    if ((ConvertTo-SporeSporeExactJson -Value $source) -cne
        (ConvertTo-SporeSporeExactJson -Value (Get-DevelopmentSourceSnapshot))) { throw 'DEVELOPMENT_SOURCE_CHANGED' }
} catch {
    $failure = $_.Exception.Message
} finally {
    if ($null -ne $lock) { Exit-SporeSporeLocomotionOperationLock -Receipt $lock }
}
$receipt = [ordered]@{
    schema_version='sporespore_sdk1_development_interface_gate_v1'
    ledger_scope=[ordered]@{subsystem='development_workflow';engine_scope='godot_jolt';authority_mode='unofficial_zero_world_interfaces';question_class='development'}
    passed=($failure -ceq '' -and $completed.Count -eq $stages.Count)
    failure_code=$failure; source_snapshot=$source; stages=$completed.ToArray()
    started_utc=$startedUtc; completed_utc=[DateTime]::UtcNow.ToString('o')
    runtime=[ordered]@{
        powershell=(Get-Process -Id $PID).Path; python=$pythonPath
        powershell_sha256=(Get-FileHash -LiteralPath (Get-Process -Id $PID).Path -Algorithm SHA256).Hash.ToLowerInvariant()
        python_sha256=(Get-FileHash -LiteralPath $pythonPath -Algorithm SHA256).Hash.ToLowerInvariant()
        framework=[Runtime.InteropServices.RuntimeInformation]::FrameworkDescription
        corelib_sha256=(Get-FileHash -LiteralPath ([double].Assembly.Location) -Algorithm SHA256).Hash.ToLowerInvariant()
        system_text_json_sha256=(Get-FileHash -LiteralPath ([Text.Json.JsonSerializer].Assembly.Location) -Algorithm SHA256).Hash.ToLowerInvariant()
    }
    output_root=$runRoot; cache_used=$false; official_qualification_passed=$false
    physical_smoke_executed=$false; production_route_proven=$false
    physical_execution_authorized=$false; physical_acceptance_authority=$false; release_authority=$false
}
if ($runRoot -cne '') {
    $json = ConvertTo-SporeSporeExactJson -Value $receipt -Indented
    Write-DevelopmentFile (Join-Path $runRoot 'receipt.json') ([Text.UTF8Encoding]::new($false).GetBytes($json + "`n"))
}
Write-Output ('DEVELOPMENT_INTERFACES_COMPLETE ' + (ConvertTo-SporeSporeExactJson -Value $receipt))
if (-not $receipt.passed) { exit 1 }
