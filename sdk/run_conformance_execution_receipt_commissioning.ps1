#requires -Version 7.0

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateSet("Execute", "ReadBack")]
    [string]$Mode,
    [string]$EvidenceRootOverride = "",
    [switch]$TestOnly
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$sdkRoot = [IO.Path]::GetFullPath($PSScriptRoot)
$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $sdkRoot))
$modulePath = Join-Path $sdkRoot "conformance_execution_receipt.ps1"
if (-not (Test-Path -LiteralPath $modulePath -PathType Leaf)) {
    throw "CER1 commissioning module is missing."
}
. $modulePath

$auditPath = "tests/test_qsdk_r23d13_closure.ps1"
$inputCandidate = Get-SporeSporeConformanceExecutionInputCandidate `
    -RepoRoot $repoRoot `
    -AuditPath $auditPath `
    -TestOnly:$TestOnly

if ($Mode -ceq "Execute") {
    $pwsh = (Get-Command pwsh -CommandType Application -ErrorAction Stop |
        Select-Object -First 1).Source
    $start = [Diagnostics.ProcessStartInfo]::new()
    $start.FileName = $pwsh
    $start.WorkingDirectory = $repoRoot
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    $start.StandardOutputEncoding = [Text.UTF8Encoding]::new($false)
    $start.StandardErrorEncoding = [Text.UTF8Encoding]::new($false)
    foreach ($argument in @(
        "-NoLogo", "-NoProfile", "-File", $auditPath
    )) {
        [void]$start.ArgumentList.Add($argument)
    }
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $start
    $timer = [Diagnostics.Stopwatch]::StartNew()
    try {
        if (-not $process.Start()) {
            throw "CER1 failed to start the declared audit."
        }
        $stdoutTask = $process.StandardOutput.ReadToEndAsync()
        $stderrTask = $process.StandardError.ReadToEndAsync()
        $process.WaitForExit()
        $stdout = $stdoutTask.GetAwaiter().GetResult()
        $stderr = $stderrTask.GetAwaiter().GetResult()
        $exitCode = $process.ExitCode
    } finally {
        $timer.Stop()
        $process.Dispose()
    }
    $publication = Publish-SporeSporeConformanceExecutionCandidate `
        -RepoRoot $repoRoot `
        -InputCandidate $inputCandidate `
        -ExitCode $exitCode `
        -Stdout $stdout `
        -Stderr $stderr `
        -EvidenceRootOverride $EvidenceRootOverride `
        -TestOnly:$TestOnly
    if (-not [string]::IsNullOrEmpty($stdout)) {
        [Console]::Out.Write(
            (ConvertTo-SporeSporeCanonicalExecutionText $stdout)
        )
    }
    if (-not [string]::IsNullOrEmpty($stderr)) {
        [Console]::Error.Write(
            (ConvertTo-SporeSporeCanonicalExecutionText $stderr)
        )
    }
    $summary = [ordered]@{
        schema_version =
            "sporespore_conformance_execution_candidate_execute_summary_v1"
        input_key_sha256 = [string]$publication.input_key_sha256
        record_sha256 = [string]$publication.record_sha256
        result_projection_sha256 =
            [string]$publication.result_projection_sha256
        audit_invocation_count = 1
        elapsed_seconds = $timer.Elapsed.TotalSeconds
        cold_equivalence_complete = $false
        production_result_reuse_permitted = $false
        physical_authority = $false
        release_authority = $false
    }
    Write-Output (
        "CONFORMANCE_EXECUTION_CANDIDATE_EXECUTED " +
        ($summary | ConvertTo-Json -Depth 16 -Compress)
    )
    exit 0
}

$readBack = Read-SporeSporeConformanceExecutionCandidate `
    -RepoRoot $repoRoot `
    -ExpectedInputKeySha256 ([string]$inputCandidate.input_key_sha256) `
    -EvidenceRootOverride $EvidenceRootOverride `
    -TestOnly:$TestOnly
if (-not [string]::IsNullOrEmpty([string]$readBack.stdout)) {
    [Console]::Out.Write([string]$readBack.stdout)
}
if (-not [string]::IsNullOrEmpty([string]$readBack.stderr)) {
    [Console]::Error.Write([string]$readBack.stderr)
}
$summary = [ordered]@{
    schema_version =
        "sporespore_conformance_execution_candidate_readback_summary_v1"
    input_key_sha256 = [string]$readBack.input_key_sha256
    record_sha256 = [string]$readBack.record_sha256
    result_projection_sha256 = [string]$readBack.result_projection_sha256
    audit_invocation_count = 0
    cold_equivalence_complete = $false
    production_result_reuse_permitted = $false
    physical_authority = $false
    release_authority = $false
}
Write-Output (
    "CONFORMANCE_EXECUTION_CANDIDATE_READBACK " +
    ($summary | ConvertTo-Json -Depth 16 -Compress)
)
