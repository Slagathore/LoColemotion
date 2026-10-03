#requires -Version 7.0

[CmdletBinding()]
param(
    [string]$Manifest = (
        Join-Path $PSScriptRoot (
            "trace_analysis\r23d26_lineage_analysis_manifest_v1.json"
        )
    ),
    [string]$EvidenceRoot = (
        Join-Path (
            Split-Path -Parent (
                [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
            )
        ) "SporeSpore_Evidence"
    ),
    [Parameter(Mandatory)][string]$OutputDirectory
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$expectedRemote = "https://github.com/Slagathore/sporespore.git"
$manifestPath = [IO.Path]::GetFullPath($Manifest)
$evidenceRootPath = [IO.Path]::GetFullPath($EvidenceRoot).TrimEnd('\', '/')
$outputRoot = [IO.Path]::GetFullPath($OutputDirectory).TrimEnd('\', '/')
$analyzerPath = Join-Path `
    $PSScriptRoot "trace_analysis\analyze_retained_trace_lineage.py"
$contractPath = Join-Path `
    $PSScriptRoot "trace_analysis\retained_trace_lineage_contract_v1.json"
$artifactStorePath = Join-Path $PSScriptRoot "content_addressed_artifact_store.ps1"

. $artifactStorePath

function Assert-TraceLineage([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "RETAINED_TRACE_LINEAGE: $Message" }
}

function Get-TraceLineageGitBlobSha256(
    [string]$Commit,
    [string]$RelativePath
) {
    $start = [Diagnostics.ProcessStartInfo]::new()
    $start.FileName = "git"
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    foreach ($argument in @(
        "-C", $repoRoot, "cat-file", "blob", "${Commit}:$RelativePath"
    )) { [void]$start.ArgumentList.Add($argument) }
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $start
    try {
        Assert-TraceLineage $process.Start() "could not start Git blob reader"
        $stderrTask = $process.StandardError.ReadToEndAsync()
        $hasher = [Security.Cryptography.SHA256]::Create()
        try { $digest = $hasher.ComputeHash($process.StandardOutput.BaseStream) }
        finally { $hasher.Dispose() }
        $process.WaitForExit()
        $stderr = $stderrTask.GetAwaiter().GetResult()
        Assert-TraceLineage ($process.ExitCode -eq 0) (
            "Git blob read failed for ${RelativePath}: $stderr"
        )
        return "sha256:" + [Convert]::ToHexString($digest).ToLowerInvariant()
    } finally { $process.Dispose() }
}

Assert-TraceLineage (
    (git -C $repoRoot rev-parse --show-toplevel).Trim() -ceq
        $repoRoot.Replace('\', '/') -and
    (git -C $repoRoot remote get-url origin).Trim() -ceq $expectedRemote
) "repository identity changed"

$sourceCommit = (git -C $repoRoot rev-parse HEAD).Trim()
$originMain = (git -C $repoRoot rev-parse origin/main).Trim()
$liveLine = (git -C $repoRoot ls-remote origin refs/heads/main).Trim()
$liveMain = ($liveLine -split '\s+')[0]
$statusEntries = @(git -C $repoRoot status --short)
Assert-TraceLineage (
    $sourceCommit -match '^[0-9a-f]{40}$' -and
    $sourceCommit -ceq $originMain -and
    $sourceCommit -ceq $liveMain -and
    $statusEntries.Count -eq 0
) "analysis source must be clean, pushed, and equal to live GitHub main"

foreach ($path in @(
    $manifestPath,
    $analyzerPath,
    $contractPath,
    $artifactStorePath,
    $evidenceRootPath
)) {
    Assert-TraceLineage (Test-Path -LiteralPath $path) "required path missing: $path"
}

$expectedOutputPrefix = $evidenceRootPath + [IO.Path]::DirectorySeparatorChar
Assert-TraceLineage (
    $outputRoot.StartsWith(
        $expectedOutputPrefix,
        [StringComparison]::OrdinalIgnoreCase
    ) -and
    (Split-Path -Leaf $outputRoot).StartsWith(
        "trace-lineage-",
        [StringComparison]::Ordinal
    ) -and
    -not (Test-Path -LiteralPath $outputRoot)
) "output must be a new trace-lineage-* directory under the durable evidence root"

$manifestRelative = [IO.Path]::GetRelativePath($repoRoot, $manifestPath).
    Replace('\', '/')
$analyzerRelative = [IO.Path]::GetRelativePath($repoRoot, $analyzerPath).
    Replace('\', '/')
$contractRelative = [IO.Path]::GetRelativePath($repoRoot, $contractPath).
    Replace('\', '/')
foreach ($relativePath in @(
    $manifestRelative,
    $analyzerRelative,
    $contractRelative
)) {
    $checkoutSha = "sha256:" + (
        Get-FileHash -LiteralPath (Join-Path $repoRoot $relativePath) `
            -Algorithm SHA256
    ).Hash.ToLowerInvariant()
    Assert-TraceLineage (
        $checkoutSha -ceq (
            Get-TraceLineageGitBlobSha256 $sourceCommit $relativePath
        )
    ) "checkout bytes differ from the source Git blob: $relativePath"
}

$manifestObject = Get-Content -LiteralPath $manifestPath -Raw |
    ConvertFrom-Json -AsHashtable -Depth 100
$sourceClosure = $manifestObject.source_closure
$closureCommit = [string]$sourceClosure.source_commit
$closureRelative = [string]$sourceClosure.path
Assert-TraceLineage (
    [string]$manifestObject.schema_version -ceq
        "sporespore_retained_trace_lineage_manifest_v1" -and
    [string]$manifestObject.question_class -ceq
        "postclosure_development_diagnosis" -and
    (git -C $repoRoot rev-parse "${closureCommit}:${closureRelative}").Trim() -ceq
        [string]$sourceClosure.git_blob_oid -and
    (Get-TraceLineageGitBlobSha256 $closureCommit $closureRelative) -ceq
        [string]$sourceClosure.raw_sha256
) "immutable source-closure binding changed"

$pythonMatches = @(
    Get-Command python.exe -CommandType Application -ErrorAction Stop
)
Assert-TraceLineage ($pythonMatches.Count -ge 1) "python.exe is unavailable"
$python = [IO.Path]::GetFullPath([string]$pythonMatches[0].Source)
Assert-TraceLineage (Test-Path -LiteralPath $python -PathType Leaf) (
    "resolved Python executable is missing"
)

[void][IO.Directory]::CreateDirectory($outputRoot)
$reportPath = Join-Path $outputRoot "report.json"
$receiptPath = Join-Path $outputRoot "receipt.json"
$analyzerOutput = & $python $analyzerPath `
    --manifest $manifestPath `
    --evidence-root $evidenceRootPath `
    --analyzer-source-commit $sourceCommit `
    --output $reportPath 2>&1 | Out-String
$analyzerExit = $LASTEXITCODE
Assert-TraceLineage ($analyzerExit -eq 0) "analyzer failed: $analyzerOutput"

$markerPrefix = "RETAINED_TRACE_LINEAGE_PASS "
$markers = @(
    ($analyzerOutput -split '\r?\n') | Where-Object {
        $_.StartsWith($markerPrefix, [StringComparison]::Ordinal)
    }
)
Assert-TraceLineage ($markers.Count -eq 1) "analyzer marker count changed"
$report = $markers[0].Substring($markerPrefix.Length) |
    ConvertFrom-Json -AsHashtable -Depth 100
Assert-TraceLineage (
    [string]$report.schema_version -ceq
        "sporespore_retained_trace_lineage_report_v1" -and
    [string]$report.analyzer_source_commit -ceq $sourceCommit -and
    [int]$report.input_summary.cell_count -gt 0 -and
    [int]$report.input_summary.live_attempt_path_input_count -eq 0 -and
    [int]$report.model_construction_count -eq 0 -and
    [int]$report.world_attempt_count -eq 0 -and
    [int]$report.world_build_count -eq 0 -and
    -not [bool]$report.closed_campaign_reinterpreted -and
    -not [bool]$report.candidate_selection_authorized -and
    -not [bool]$report.threshold_change_authorized -and
    -not [bool]$report.physical_campaign_opened -and
    -not [bool]$report.physical_execution_authorized -and
    -not [bool]$report.turning_validation -and
    -not [bool]$report.cross_engine_equivalence -and
    -not [bool]$report.release_authorized -and
    -not [bool]$report.physical_acceptance_authority
) "report boundary changed"

$artifact = Publish-SporeSporeContentAddressedArtifact `
    -RepoRoot $repoRoot `
    -ArtifactPath $reportPath `
    -MediaType "application/json"
$receipt = [ordered]@{
    schema_version = "sporespore_retained_trace_lineage_receipt_v1"
    analysis_id = [string]$report.analysis_id
    generated_utc = [DateTime]::UtcNow.ToString("o")
    analyzer_source_commit = $sourceCommit
    manifest_path = $manifestRelative
    manifest_sha256 = [string]$report.manifest.sha256
    report_path = $reportPath
    report_sha256 = [string]$artifact.sha256
    report_byte_length = [long]$artifact.byte_length
    report_cas_payload_path = [string]$artifact.payload_path
    report_cas_manifest_path = [string]$artifact.manifest_path
    model_construction_count = 0
    world_attempt_count = 0
    world_build_count = 0
    physical_execution_authorized = $false
    physical_acceptance_authority = $false
}
[IO.File]::WriteAllText(
    $receiptPath,
    ($receipt | ConvertTo-Json -Depth 20) + "`n",
    [Text.UTF8Encoding]::new($false)
)

Write-Host (
    "RETAINED_TRACE_LINEAGE_RETAINED " +
    "analysis=$($receipt.analysis_id) cells=$($report.input_summary.cell_count) " +
    "rows=$($report.input_summary.total_trace_row_count) " +
    "report=$($receipt.report_sha256) models=0 worlds=0 physical=False"
)
