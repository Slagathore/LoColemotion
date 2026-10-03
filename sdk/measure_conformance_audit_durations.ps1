#requires -Version 7.0

[CmdletBinding()]
param(
    [string]$InventoryPathOverride = "",
    [string[]]$IncludePath = @(),
    [string]$EvidenceRootOverride = "",
    [ValidateRange(30, 1800)][int]$HardSafetyTimeoutSeconds = 900,
    [switch]$TestOnly
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$sdkRoot = [IO.Path]::GetFullPath($PSScriptRoot)
$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $sdkRoot))
$contractPath = Join-Path $sdkRoot "conformance_audit_profiler_contract_v1.json"
$productionInventoryPath = Join-Path $sdkRoot "closure_evidence_mode_inventory.json"
$artifactStorePath = Join-Path $sdkRoot "content_addressed_artifact_store.ps1"
$scriptPath = $PSCommandPath

foreach ($path in @($contractPath, $productionInventoryPath, $artifactStorePath)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "CAP1 input is missing: $path"
    }
}
. $artifactStorePath

function Assert-Cap1 {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw "CAP1 profiler refused: $Message" }
}

function Get-Cap1RawSha256 {
    param([Parameter(Mandatory)][string]$Path)
    return "sha256:" + (
        Get-FileHash -LiteralPath $Path -Algorithm SHA256
    ).Hash.ToLowerInvariant()
}

function Invoke-Cap1Git {
    param([Parameter(Mandatory)][string[]]$Arguments)
    $output = @(& git -C $repoRoot @Arguments 2>&1)
    if ($LASTEXITCODE -ne 0) {
        throw "CAP1 Git probe failed: git $($Arguments -join ' '): $($output -join ' ')"
    }
    return ($output -join "`n").Trim()
}

function Write-Cap1NewUtf8File {
    param(
        [Parameter(Mandatory)][string]$Path,
        [AllowEmptyString()][string]$Text = ""
    )
    [void][IO.Directory]::CreateDirectory((Split-Path -Parent $Path))
    $bytes = [Text.UTF8Encoding]::new($false).GetBytes($Text)
    $stream = [IO.File]::Open(
        $Path,
        [IO.FileMode]::CreateNew,
        [IO.FileAccess]::Write,
        [IO.FileShare]::None
    )
    try { $stream.Write($bytes, 0, $bytes.Length) }
    finally { $stream.Dispose() }
}

function ConvertTo-Cap1CanonicalText {
    param([AllowEmptyString()][string]$Text = "")
    if ($null -eq $Text) { return "" }
    return $Text.Replace("`r`n", "`n").Replace("`r", "`n")
}

$contract = Get-Content -LiteralPath $contractPath -Raw |
    ConvertFrom-Json -AsHashtable -Depth 32
Assert-Cap1 (
    [string]$contract.schema_version -ceq
        "sporespore_conformance_audit_profiler_contract_v1" -and
    [string]$contract.status -ceq
        "prospective_development_profiler_no_reuse_authority" -and
    [bool]$contract.claims.development_observation_only -and
    -not [bool]$contract.claims.production_cache_lookup_permitted -and
    -not [bool]$contract.claims.production_result_reuse_permitted -and
    -not [bool]$contract.claims.physical_execution_authorized -and
    -not [bool]$contract.claims.scientific_authority -and
    -not [bool]$contract.claims.release_authority
) "contract identity or authority changed"

# CAP1-C1 is already frozen. Preserve this implementation for its focused
# regression gate, but refuse any new durable/production profile so a future
# run cannot silently lose incremental duration receipts. CAP2 is the only live
# production profiler successor.
if (-not $TestOnly) {
    throw (
        "CAP1 profiler is retired for new production runs after CAP1-C1; " +
        "use sdk/measure_conformance_audit_durations_v2.ps1"
    )
}

if (-not $TestOnly) {
    Assert-Cap1 ([string]::IsNullOrWhiteSpace($InventoryPathOverride)) (
        "production inventory override is forbidden"
    )
    Assert-Cap1 (@($IncludePath).Count -eq 0) (
        "production subset profiling is forbidden"
    )
    Assert-Cap1 (
        $HardSafetyTimeoutSeconds -eq [int]$contract.execution.hard_safety_timeout_seconds
    ) "production hard-safety timeout changed"
}

$inventoryPath = if ([string]::IsNullOrWhiteSpace($InventoryPathOverride)) {
    $productionInventoryPath
} else {
    Assert-Cap1 ([bool]$TestOnly) "inventory override is test-only"
    [IO.Path]::GetFullPath($InventoryPathOverride)
}
Assert-Cap1 (Test-Path -LiteralPath $inventoryPath -PathType Leaf) (
    "inventory is missing: $inventoryPath"
)
$inventory = Get-Content -LiteralPath $inventoryPath -Raw |
    ConvertFrom-Json -AsHashtable -Depth 32
Assert-Cap1 (
    [string]$inventory.schema_version -ceq
        "sporespore_closure_evidence_mode_inventory_v1" -and
    [int]$inventory.audit_count -eq @($inventory.entries).Count -and
    [int]$inventory.world_build_count -eq 0 -and
    -not [bool]$inventory.physical_execution_authorized -and
    -not [bool]$inventory.physical_acceptance_authority
) "CEP1 inventory identity or zero-world boundary changed"
if (-not $TestOnly) {
    Assert-Cap1 (
        [int]$inventory.audit_count -eq
            [int]$contract.production_inventory.expected_audit_count
    ) "production CEP1 audit count changed"
}

$entryByPath = [Collections.Generic.Dictionary[string, object]]::new(
    [StringComparer]::Ordinal
)
foreach ($entry in @($inventory.entries)) {
    $path = [string]$entry.path
    Assert-Cap1 (
        -not [string]::IsNullOrWhiteSpace($path) -and
        -not [IO.Path]::IsPathRooted($path) -and
        -not $path.Contains("..", [StringComparison]::Ordinal) -and
        $entryByPath.TryAdd($path, $entry)
    ) "inventory contains an invalid or duplicate audit path"
}
$selectedEntries = if (@($IncludePath).Count -eq 0) {
    [object[]]@($inventory.entries)
} else {
    Assert-Cap1 ([bool]$TestOnly) "audit subset is test-only"
    $subset = [Collections.Generic.List[object]]::new()
    foreach ($selectedPath in $IncludePath) {
        $entry = $null
        Assert-Cap1 ($entryByPath.TryGetValue([string]$selectedPath, [ref]$entry)) (
            "subset audit is not in the inventory: $selectedPath"
        )
        $subset.Add($entry)
    }
    [object[]]$subset.ToArray()
}
Assert-Cap1 ($selectedEntries.Count -gt 0) "selected audit set is empty"

foreach ($entry in $selectedEntries) {
    $auditPath = [string]$entry.path
    $auditAbsolute = Join-Path $repoRoot $auditPath
    Assert-Cap1 (Test-Path -LiteralPath $auditAbsolute -PathType Leaf) (
        "audit source is missing: $auditPath"
    )
    $actualHash = (Get-FileHash -LiteralPath $auditAbsolute -Algorithm SHA256).
        Hash.ToLowerInvariant()
    Assert-Cap1 ($actualHash -ceq [string]$entry.raw_sha256) (
        "audit source hash differs from CEP1: $auditPath"
    )
}

$status = Invoke-Cap1Git @("status", "--short")
$head = Invoke-Cap1Git @("rev-parse", "HEAD")
$headTree = Invoke-Cap1Git @("rev-parse", "HEAD^{tree}")
$originMain = Invoke-Cap1Git @("rev-parse", "origin/main")
$sourceEligible = [string]::IsNullOrWhiteSpace($status) -and $head -ceq $originMain
if (-not $TestOnly) {
    Assert-Cap1 $sourceEligible "production profiling requires clean source equal to origin/main"
}

$productionEvidenceRoot = Get-SporeSporeArtifactEvidenceRoot -RepoRoot $repoRoot
$evidenceRoot = if ([string]::IsNullOrWhiteSpace($EvidenceRootOverride)) {
    $productionEvidenceRoot
} else { [IO.Path]::GetFullPath($EvidenceRootOverride).TrimEnd('\', '/') }
if (-not $TestOnly) {
    Assert-Cap1 ($evidenceRoot -ceq $productionEvidenceRoot) (
        "production profiler must use the durable evidence root"
    )
}
[void][IO.Directory]::CreateDirectory($evidenceRoot)
$runId = (
    [DateTime]::UtcNow.ToString("yyyyMMddTHHmmssZ") + "-" +
    $head.Substring(0, 8) + "-" + [guid]::NewGuid().ToString("N")
)
$runRoot = Join-Path $evidenceRoot "conformance-audit-profiles\$runId"
Assert-Cap1 (-not (Test-Path -LiteralPath $runRoot)) (
    "profile run identity already exists"
)
[void][IO.Directory]::CreateDirectory($runRoot)
$streamRoot = Join-Path $runRoot "streams"
[void][IO.Directory]::CreateDirectory($streamRoot)

$pwsh = (Get-Command pwsh -CommandType Application -ErrorAction Stop |
    Select-Object -First 1).Source
$receipts = [Collections.Generic.List[object]]::new()
$ordinal = 0
foreach ($entry in $selectedEntries) {
    $ordinal += 1
    $auditPath = [string]$entry.path
    Write-Output (
        "CAP1_AUDIT_START ordinal=$ordinal/$($selectedEntries.Count) path=$auditPath"
    )
    $startInfo = [Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = $pwsh
    $startInfo.WorkingDirectory = $repoRoot
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $startInfo.StandardOutputEncoding = [Text.UTF8Encoding]::new($false)
    $startInfo.StandardErrorEncoding = [Text.UTF8Encoding]::new($false)
    foreach ($argument in @("-NoLogo", "-NoProfile", "-File", $auditPath)) {
        [void]$startInfo.ArgumentList.Add($argument)
    }
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $startInfo
    $startedUtc = [DateTime]::UtcNow
    $watch = [Diagnostics.Stopwatch]::StartNew()
    $timedOut = $false
    try {
        Assert-Cap1 $process.Start() "audit process did not start: $auditPath"
        $stdoutTask = $process.StandardOutput.ReadToEndAsync()
        $stderrTask = $process.StandardError.ReadToEndAsync()
        if (-not $process.WaitForExit($HardSafetyTimeoutSeconds * 1000)) {
            $timedOut = $true
            try { $process.Kill($true) } catch { }
            [void]$process.WaitForExit(30000)
        }
        $stdout = ConvertTo-Cap1CanonicalText (
            $stdoutTask.GetAwaiter().GetResult()
        )
        $stderr = ConvertTo-Cap1CanonicalText (
            $stderrTask.GetAwaiter().GetResult()
        )
        $exitCode = if ($timedOut) { 124 } else { $process.ExitCode }
    } finally {
        $watch.Stop()
        $process.Dispose()
    }
    $endedUtc = [DateTime]::UtcNow
    $ordinalName = $ordinal.ToString("D3")
    $auditStreamRoot = Join-Path $streamRoot $ordinalName
    $stdoutPath = Join-Path $auditStreamRoot "stdout.txt"
    $stderrPath = Join-Path $auditStreamRoot "stderr.txt"
    Write-Cap1NewUtf8File -Path $stdoutPath -Text $stdout
    Write-Cap1NewUtf8File -Path $stderrPath -Text $stderr
    $stdoutArtifact = Publish-SporeSporeContentAddressedArtifact `
        -RepoRoot $repoRoot `
        -ArtifactPath $stdoutPath `
        -MediaType "text/plain; charset=utf-8; line-endings=lf" `
        -EvidenceRootOverride $evidenceRoot `
        -TestOnly:$TestOnly
    $stderrArtifact = Publish-SporeSporeContentAddressedArtifact `
        -RepoRoot $repoRoot `
        -ArtifactPath $stderrPath `
        -MediaType "text/plain; charset=utf-8; line-endings=lf" `
        -EvidenceRootOverride $evidenceRoot `
        -TestOnly:$TestOnly
    $passed = -not $timedOut -and $exitCode -eq 0
    $receipts.Add([ordered]@{
        ordinal = $ordinal
        audit_path = $auditPath
        audit_raw_sha256 = "sha256:" + [string]$entry.raw_sha256
        historical_identity_mode = [string]$entry.historical_identity_mode
        manual_review_required = [bool]$entry.manual_review_required
        started_utc = $startedUtc.ToString("o")
        ended_utc = $endedUtc.ToString("o")
        duration_seconds = $watch.Elapsed.TotalSeconds
        exit_code = $exitCode
        timed_out = $timedOut
        timeout_is_proven_hang = $false
        passed = $passed
        stdout_sha256 = [string]$stdoutArtifact.sha256
        stdout_byte_length = [long]$stdoutArtifact.byte_length
        stderr_sha256 = [string]$stderrArtifact.sha256
        stderr_byte_length = [long]$stderrArtifact.byte_length
    })
    Write-Output (
        "CAP1_AUDIT_RESULT ordinal=$ordinal/$($selectedEntries.Count) " +
        "path=$auditPath passed=$passed exit=$exitCode duration_seconds=" +
        $watch.Elapsed.TotalSeconds.ToString(
            "F7", [Globalization.CultureInfo]::InvariantCulture
        )
    )
    if (-not $passed) {
        $excerpt = (($stderr + "`n" + $stdout).Trim() -split "`n" |
            Select-Object -Last 8) -join " | "
        Write-Warning "CAP1 audit failure path=$auditPath excerpt=$excerpt"
    }
}

$ranked = [Collections.Generic.List[object]]::new()
foreach ($receipt in $receipts) { $ranked.Add($receipt) }
$ranked.Sort([Comparison[object]]{
    param($left, $right)
    $durationOrder = ([double]$right.duration_seconds).CompareTo(
        [double]$left.duration_seconds
    )
    if ($durationOrder -ne 0) { return $durationOrder }
    return [string]::CompareOrdinal(
        [string]$left.audit_path,
        [string]$right.audit_path
    )
})
$failureCount = 0
$totalSeconds = 0.0
foreach ($receipt in $receipts) {
    if (-not [bool]$receipt.passed) { $failureCount += 1 }
    $totalSeconds += [double]$receipt.duration_seconds
}
$profile = [ordered]@{
    schema_version = "sporespore_conformance_audit_duration_profile_v1"
    status = if ($failureCount -eq 0) {
        "complete_development_observation_all_selected_passed"
    } else { "complete_development_observation_with_failures" }
    run_id = $runId
    source = [ordered]@{
        head = $head
        head_tree = $headTree
        origin_main = $originMain
        clean_equal_origin_main = $sourceEligible
    }
    input = [ordered]@{
        inventory_sha256 = Get-Cap1RawSha256 $inventoryPath
        contract_sha256 = Get-Cap1RawSha256 $contractPath
        profiler_sha256 = Get-Cap1RawSha256 $scriptPath
        artifact_store_sha256 = Get-Cap1RawSha256 $artifactStorePath
        pwsh_executable_sha256 = Get-Cap1RawSha256 $pwsh
        selected_audit_count = $receipts.Count
        production_inventory_count = [int]$inventory.audit_count
        hard_safety_timeout_seconds = $HardSafetyTimeoutSeconds
        timeout_is_proven_hang = $false
    }
    summary = [ordered]@{
        selected_audit_count = $receipts.Count
        pass_count = $receipts.Count - $failureCount
        failure_count = $failureCount
        total_audit_seconds = [double]$totalSeconds
        serialized = $true
    }
    receipts = @($receipts)
    ranking = @($ranked | ForEach-Object {
        [ordered]@{
            audit_path = [string]$_.audit_path
            duration_seconds = [double]$_.duration_seconds
            passed = [bool]$_.passed
        }
    })
    test_only = [bool]$TestOnly
    development_observation_only = $true
    audit_dependency_complete = $false
    runtime_profile_complete = $false
    cold_equivalence_complete = $false
    production_cache_lookup_permitted = $false
    production_result_reuse_permitted = $false
    historical_audit_waiver_permitted = $false
    physical_authority = $false
    scientific_authority = $false
    release_authority = $false
}
$profilePath = Join-Path $runRoot "profile.json"
Write-Cap1NewUtf8File `
    -Path $profilePath `
    -Text (($profile | ConvertTo-Json -Depth 64) + "`n")
$profileArtifact = Publish-SporeSporeContentAddressedArtifact `
    -RepoRoot $repoRoot `
    -ArtifactPath $profilePath `
    -MediaType "application/json" `
    -EvidenceRootOverride $evidenceRoot `
    -TestOnly:$TestOnly

Write-Output (
    "CAP1_PROFILE_COMPLETE run=$runId selected=$($receipts.Count) " +
    "passed=$($receipts.Count - $failureCount) failed=$failureCount " +
    "total_audit_seconds=" + ([double]$totalSeconds).ToString(
        "F7", [Globalization.CultureInfo]::InvariantCulture
    ) + " profile_sha256=$($profileArtifact.sha256) worlds=0 " +
    "cache=disabled physical_authority=False release_authority=False"
)
if ($failureCount -ne 0) { exit 1 }
