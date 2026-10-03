#requires -Version 7.0

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [switch]$ExpectProductionConformanceLockHeld
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$sdkRoot = Join-Path $repoRoot "sdk"
$closingCommit = "8f7b8fff137beee2df0428d85610a9f523d081f9"
$auditRelative = "sdk/audit_r23d72_mujoco_preturn_startup_development_closure.ps1"
$auditPath = Join-Path $repoRoot $auditRelative
$outerLockPreflight = Join-Path $repoRoot (
    "tests\test_qsdk_r23d74_legacy_mujoco_outer_lock_preflight.ps1"
)

function Assert-R23D74R72OuterReplay([bool]$Condition, [string]$Message) {
    if (-not $Condition) {
        throw "[turning/mujoco] R23D74 R23D72 outer-lock replay: $Message"
    }
}

function Get-R23D74R72OuterReplaySha256([byte[]]$Bytes) {
    return "sha256:" + [Convert]::ToHexString(
        [Security.Cryptography.SHA256]::HashData($Bytes)
    ).ToLowerInvariant()
}

function Get-R23D74R72GitBlobBytes([string]$Commit, [string]$RelativePath) {
    $start = [Diagnostics.ProcessStartInfo]::new()
    $start.FileName = "git"
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    foreach ($argument in @(
        "-C", $repoRoot, "cat-file", "blob", "${Commit}:$RelativePath"
    )) {
        [void]$start.ArgumentList.Add($argument)
    }
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $start
    try {
        Assert-R23D74R72OuterReplay $process.Start() "could not start Git blob reader"
        $stderrTask = $process.StandardError.ReadToEndAsync()
        $memory = [IO.MemoryStream]::new()
        try {
            $process.StandardOutput.BaseStream.CopyTo($memory)
            $process.WaitForExit()
            $stderr = $stderrTask.GetAwaiter().GetResult()
            Assert-R23D74R72OuterReplay ($process.ExitCode -eq 0) (
                "Git blob read failed: $stderr"
            )
            return $memory.ToArray()
        } finally {
            $memory.Dispose()
        }
    } finally {
        $process.Dispose()
    }
}

function Replace-R23D74R72ExactOnce(
    [string]$Text,
    [string]$Anchor,
    [string]$Replacement,
    [string]$Label
) {
    $count = [regex]::Matches(
        $Text,
        [regex]::Escape($Anchor),
        [Text.RegularExpressions.RegexOptions]::CultureInvariant
    ).Count
    Assert-R23D74R72OuterReplay ($count -eq 1) (
        "expected one $Label transformation anchor, observed $count"
    )
    return $Text.Replace($Anchor, $Replacement)
}

Assert-R23D74R72OuterReplay ([bool]$ExpectProductionConformanceLockHeld) (
    "explicit parent conformance-lock expectation is required"
)
Assert-R23D74R72OuterReplay (
    (& git -C $repoRoot rev-parse --show-toplevel).Trim().Replace("/", "\") -ceq
        $repoRoot.TrimEnd("\", "/") -and
    (& git -C $repoRoot remote get-url origin).Trim() -ceq
        "https://github.com/Slagathore/sporespore.git" -and
    (& git -C $repoRoot cat-file -t "${closingCommit}^{commit}").Trim() -ceq
        "commit"
) "repository, remote, or closing commit changed"
foreach ($path in @($auditPath, $outerLockPreflight)) {
    Assert-R23D74R72OuterReplay (Test-Path -LiteralPath $path -PathType Leaf) (
        "required replay path is missing: $path"
    )
}

$legacyBytes = [IO.File]::ReadAllBytes($auditPath)
$closingBytes = Get-R23D74R72GitBlobBytes $closingCommit $auditRelative
Assert-R23D74R72OuterReplay (
    (Get-R23D74R72OuterReplaySha256 $legacyBytes) -ceq
        (Get-R23D74R72OuterReplaySha256 $closingBytes)
) "immutable R23D72 closure audit changed"
$legacyText = [Text.UTF8Encoding]::new($false).GetString($legacyBytes)
$transformed = Replace-R23D74R72ExactOnce $legacyText `
    '$sdkRoot = [IO.Path]::GetFullPath($PSScriptRoot)' `
    '$sdkRoot = [IO.Path]::GetFullPath("C:\Users\Cole\CodeStuff\games\SporeSpore\sdk")' `
    "SDK-root"
$transformed = Replace-R23D74R72ExactOnce $transformed `
    '$supervisorPath = Join-Path $sdkRoot "run_qsdk_r23d72_supervisor.ps1"' `
    '$supervisorPath = Join-Path $repoRoot "tests\test_qsdk_r23d74_legacy_mujoco_outer_lock_preflight.ps1"' `
    "supervisor-path"
$transformed = Replace-R23D74R72ExactOnce $transformed `
    '"-NoProfile", "-File", $supervisorPath, "-PreflightOnly", "-Python", $pythonHost' `
    '"-NoProfile", "-File", $supervisorPath, "-Campaign", "R23D72", "-ExpectProductionConformanceLockHeld", "-Python", $pythonHost' `
    "supervisor-invocation"

$records = [Collections.Generic.List[string]]::new()
$completed = $false
try {
    foreach ($record in @(& ([ScriptBlock]::Create($transformed)) *>&1)) {
        $records.Add([string]$record)
    }
    $completed = $true
} catch {
    $records.Add([string]$_.Exception.ToString())
    if (-not [string]::IsNullOrWhiteSpace([string]$_.ScriptStackTrace)) {
        $records.Add([string]$_.ScriptStackTrace)
    }
}
$text = $records -join "`n"
Assert-R23D74R72OuterReplay ($completed) (
    "lock-aware immutable closure replay failed: $text"
)
Assert-R23D74R72OuterReplay (
    $text.Contains(
        "[turning/mujoco] R23D72 closure PASS:",
        [StringComparison]::Ordinal
    ) -and
    -not $text.Contains(
        "global locomotion operation lock is busy",
        [StringComparison]::Ordinal
    )
) "lock-aware immutable closure replay marker changed: $text"

$transformedBytes = [Text.UTF8Encoding]::new($false).GetBytes($transformed)
$receipt = [ordered]@{
    schema_version = "sporespore_qsdk_r23d74_r23d72_outer_lock_closure_replay_v1"
    predecessor_closing_commit = $closingCommit
    immutable_audit_raw_sha256 = Get-R23D74R72OuterReplaySha256 $legacyBytes
    transformed_audit_raw_sha256 = Get-R23D74R72OuterReplaySha256 $transformedBytes
    exact_transformation_count = 3
    sdk_root_rebound_only_for_in_memory_execution = $true
    supervisor_rebound_to_exact_outer_lock_worker_preflight = $true
    retained_evidence_and_trace_recomputed = $true
    historical_result_changed = $false
    new_physical_world_count = 0
    model_construction_count = 0
    world_attempt_count = 0
    world_build_count = 0
    solver_step_count = 0
    physical_execution_authorized = $false
    physical_acceptance_authority = $false
}
Write-Output (
    "QSDK_R23D74_R23D72_OUTER_LOCK_REPLAY_PASS " +
    ($receipt | ConvertTo-Json -Compress -Depth 100)
)
