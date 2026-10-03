#requires -Version 7.0

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$sdkRoot = [IO.Path]::GetFullPath($PSScriptRoot)
$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $sdkRoot))
$profilerPath = Join-Path $sdkRoot "measure_conformance_audit_durations_v2.ps1"
$artifactStorePath = Join-Path $sdkRoot "content_addressed_artifact_store.ps1"

function Assert-Cap2Commissioning {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw "CAP2 commissioning failed: $Message" }
}

foreach ($path in @($profilerPath, $artifactStorePath)) {
    Assert-Cap2Commissioning (Test-Path -LiteralPath $path -PathType Leaf) (
        "missing input: $path"
    )
}
. $artifactStorePath

function Get-Cap2CommissioningMarker {
    param(
        [Parameter(Mandatory)][object[]]$Output,
        [Parameter(Mandatory)][string]$Prefix
    )
    $lines = @($Output | ForEach-Object { [string]$_ } | Where-Object {
        $_.StartsWith($Prefix, [StringComparison]::Ordinal)
    })
    Assert-Cap2Commissioning ($lines.Count -eq 1) (
        "expected exactly one marker '$Prefix', found $($lines.Count)"
    )
    return $lines[0].Substring($Prefix.Length) |
        ConvertFrom-Json -AsHashtable -Depth 16
}

$pwsh = (Get-Command pwsh -CommandType Application -ErrorAction Stop |
    Select-Object -First 1).Source

# These are deliberately separate child processes. The first process publishes
# one complete receipt and exits at the frozen controlled-stop boundary. The
# second receives only the explicit run id, verifies the exact retained prefix,
# and must invoke only the remaining audit.
$startOutput = @(& $pwsh `
    -NoLogo `
    -NoProfile `
    -File $profilerPath `
    -Commissioning `
    -StopAfterPublishedReceiptCount 1 `
    2>&1)
$startExitCode = $LASTEXITCODE
foreach ($line in $startOutput) { Write-Output $line }
Assert-Cap2Commissioning ($startExitCode -eq 90) (
    "controlled-stop process exited $startExitCode"
)
$created = Get-Cap2CommissioningMarker `
    -Output $startOutput -Prefix "CAP2_RUN_CREATED "
$stopped = Get-Cap2CommissioningMarker `
    -Output $startOutput -Prefix "CAP2_CONTROLLED_STOP "
$runId = [string]$created.run_id
$evidenceRoot = Get-SporeSporeArtifactEvidenceRoot -RepoRoot $repoRoot
$runRoot = Join-Path $evidenceRoot "conformance-audit-profiles-v2\$runId"
$firstReceiptPath = Join-Path $runRoot "receipts\001.json"
Assert-Cap2Commissioning (
    [int]$stopped.published_receipt_count -eq 1 -and
    [int]$stopped.audit_invocation_count -eq 1 -and
    -not [bool]$stopped.authority -and
    (Test-Path -LiteralPath $firstReceiptPath -PathType Leaf) -and
    -not (Test-Path -LiteralPath (Join-Path $runRoot "profile.json"))
) "controlled stop did not leave exactly one completed receipt"
$firstReceiptSha = "sha256:" + (
    Get-FileHash -LiteralPath $firstReceiptPath -Algorithm SHA256
).Hash.ToLowerInvariant()
$firstReceiptBytes = (Get-Item -LiteralPath $firstReceiptPath).Length
$firstReceiptHex = $firstReceiptSha.Substring(7)
Assert-Cap2Commissioning (Test-SporeSporeStoredArtifact `
    -Directory (Join-Path $evidenceRoot "artifacts\sha256\$firstReceiptHex") `
    -ExpectedSha256 $firstReceiptHex `
    -ExpectedByteLength $firstReceiptBytes) "first receipt CAS failed before resume"

$resumeOutput = @(& $pwsh `
    -NoLogo `
    -NoProfile `
    -File $profilerPath `
    -Commissioning `
    -ResumeRunId $runId `
    2>&1)
$resumeExitCode = $LASTEXITCODE
foreach ($line in $resumeOutput) { Write-Output $line }
Assert-Cap2Commissioning ($resumeExitCode -eq 0) (
    "resume process exited ${resumeExitCode}: $($resumeOutput -join ' ')"
)
$completed = Get-Cap2CommissioningMarker `
    -Output $resumeOutput -Prefix "CAP2_PROFILE_COMPLETE "
$firstReceiptAfterSha = "sha256:" + (
    Get-FileHash -LiteralPath $firstReceiptPath -Algorithm SHA256
).Hash.ToLowerInvariant()
$profilePath = Join-Path $runRoot "profile.json"
$profile = Get-Content -LiteralPath $profilePath -Raw |
    ConvertFrom-Json -AsHashtable -Depth 64
$manifest = Get-Content -LiteralPath (Join-Path $runRoot "run_manifest.json") -Raw |
    ConvertFrom-Json -AsHashtable -Depth 64
Assert-Cap2Commissioning (
    $firstReceiptAfterSha -ceq $firstReceiptSha -and
    [string]$profile.mode -ceq "commissioning_two_audit_recovery" -and
    [int]$profile.summary.selected_audit_count -eq 2 -and
    [int]$profile.summary.pass_count -eq 2 -and
    [int]$profile.summary.failure_count -eq 0 -and
    [int]$profile.summary.resumed_receipt_count -eq 1 -and
    [int]$profile.summary.audit_invocation_count_this_process -eq 1 -and
    [int]$profile.summary.world_build_count -eq 0 -and
    [int]$completed.resumed_receipt_count -eq 1 -and
    [int]$completed.audit_invocation_count -eq 1 -and
    [int]$completed.worlds -eq 0 -and
    -not [bool]$profile.test_only -and
    [bool]$profile.commissioning -and
    [bool]$profile.crash_resilient_resume_candidate -and
    -not [bool]$profile.crash_resilient_resume_commissioned -and
    -not [bool]$profile.production_cache_lookup_permitted -and
    -not [bool]$profile.production_result_reuse_permitted -and
    -not [bool]$profile.physical_authority -and
    -not [bool]$profile.scientific_authority -and
    -not [bool]$profile.release_authority
) "distinct-process resume counts, receipt identity, or authority changed"

$profileSha = "sha256:" + (
    Get-FileHash -LiteralPath $profilePath -Algorithm SHA256
).Hash.ToLowerInvariant()
$profileBytes = (Get-Item -LiteralPath $profilePath).Length
$profileHex = $profileSha.Substring(7)
Assert-Cap2Commissioning (Test-SporeSporeStoredArtifact `
    -Directory (Join-Path $evidenceRoot "artifacts\sha256\$profileHex") `
    -ExpectedSha256 $profileHex `
    -ExpectedByteLength $profileBytes) "commissioning profile CAS failed"

Write-Output (
    "CAP2_COMMISSIONING_COMPLETE " + ([ordered]@{
        run_id = $runId
        source_head = [string]$manifest.input.source.head
        source_tree = [string]$manifest.input.source.head_tree
        input_key_sha256 = [string]$manifest.input_key_sha256
        manifest_sha256 = [string]$profile.manifest_sha256
        first_receipt_sha256 = $firstReceiptSha
        first_receipt_unchanged = $true
        profile_sha256 = $profileSha
        profile_byte_length = $profileBytes
        selected_audit_count = 2
        resumed_receipt_count = 1
        resume_audit_invocation_count = 1
        pass_count = 2
        failure_count = 0
        worlds = 0
        cache = "disabled"
        physical_authority = $false
        release_authority = $false
    } | ConvertTo-Json -Compress)
)
