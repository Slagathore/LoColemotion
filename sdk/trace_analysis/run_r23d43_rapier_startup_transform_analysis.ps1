#requires -Version 7.0

[CmdletBinding()]
param(
    [string]$Manifest = (
        Join-Path $PSScriptRoot (
            "r23d43_rapier_startup_transform_analysis_manifest_v1.json"
        )
    ),
    [string]$EvidenceRoot = (
        Join-Path (
            Split-Path -Parent (
                [IO.Path]::GetFullPath((Join-Path $PSScriptRoot "..\.."))
            )
        ) "SporeSpore_Evidence"
    ),
    [Parameter(Mandatory)][string]$OutputDirectory
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot "..\.."))
$expectedRemote = "https://github.com/Slagathore/sporespore.git"
$manifestPath = [IO.Path]::GetFullPath($Manifest)
$evidenceRootPath = [IO.Path]::GetFullPath($EvidenceRoot).TrimEnd('\', '/')
$outputRoot = [IO.Path]::GetFullPath($OutputDirectory).TrimEnd('\', '/')
$analyzerPath = Join-Path $PSScriptRoot (
    "analyze_r23d43_rapier_startup_transform.py"
)
$artifactStorePath = Join-Path $repoRoot "sdk\content_addressed_artifact_store.ps1"
$runnerPath = [IO.Path]::GetFullPath($PSCommandPath)

. $artifactStorePath

function Assert-R23D43StartupAnalysis([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "R23D43_STARTUP_ANALYSIS: $Message" }
}

function Get-R23D43GitBlobSha256([string]$Commit, [string]$RelativePath) {
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
        Assert-R23D43StartupAnalysis $process.Start() (
            "could not start Git blob reader"
        )
        $stderrTask = $process.StandardError.ReadToEndAsync()
        $hasher = [Security.Cryptography.SHA256]::Create()
        try { $digest = $hasher.ComputeHash($process.StandardOutput.BaseStream) }
        finally { $hasher.Dispose() }
        $process.WaitForExit()
        $stderr = $stderrTask.GetAwaiter().GetResult()
        Assert-R23D43StartupAnalysis ($process.ExitCode -eq 0) (
            "Git blob read failed for ${RelativePath}: $stderr"
        )
        return "sha256:" + [Convert]::ToHexString($digest).ToLowerInvariant()
    } finally { $process.Dispose() }
}

Assert-R23D43StartupAnalysis (
    (git -C $repoRoot rev-parse --show-toplevel).Trim() -ceq
        $repoRoot.Replace('\', '/') -and
    (git -C $repoRoot remote get-url origin).Trim() -ceq $expectedRemote
) "repository identity changed"

$sourceCommit = (git -C $repoRoot rev-parse HEAD).Trim()
$originMain = (git -C $repoRoot rev-parse origin/main).Trim()
$liveLine = (git -C $repoRoot ls-remote origin refs/heads/main).Trim()
$liveMain = ($liveLine -split '\s+')[0]
$statusEntries = @(git -C $repoRoot status --short)
Assert-R23D43StartupAnalysis (
    $sourceCommit -match '^[0-9a-f]{40}$' -and
    $sourceCommit -ceq $originMain -and
    $sourceCommit -ceq $liveMain -and
    $statusEntries.Count -eq 0
) "analysis source must be clean, pushed, and equal to live GitHub main"

foreach ($path in @(
    $manifestPath,
    $analyzerPath,
    $artifactStorePath,
    $runnerPath,
    $evidenceRootPath
)) {
    Assert-R23D43StartupAnalysis (Test-Path -LiteralPath $path) (
        "required path missing: $path"
    )
}

$expectedOutputPrefix = $evidenceRootPath + [IO.Path]::DirectorySeparatorChar
Assert-R23D43StartupAnalysis (
    $outputRoot.StartsWith(
        $expectedOutputPrefix,
        [StringComparison]::OrdinalIgnoreCase
    ) -and
    (Split-Path -Leaf $outputRoot).StartsWith(
        "trace-lineage-r23d43-startup-transform-",
        [StringComparison]::Ordinal
    ) -and
    -not (Test-Path -LiteralPath $outputRoot)
) "output must be a new trace-lineage-r23d43-startup-transform-* directory under the durable evidence root"

$sourcePaths = @($manifestPath, $analyzerPath, $artifactStorePath, $runnerPath)
foreach ($path in $sourcePaths) {
    $relativePath = [IO.Path]::GetRelativePath($repoRoot, $path).Replace('\', '/')
    $checkoutSha = "sha256:" + (
        Get-FileHash -LiteralPath $path -Algorithm SHA256
    ).Hash.ToLowerInvariant()
    Assert-R23D43StartupAnalysis (
        $checkoutSha -ceq (
            Get-R23D43GitBlobSha256 $sourceCommit $relativePath
        )
    ) "checkout bytes differ from the source Git blob: $relativePath"
}

$manifestObject = Get-Content -LiteralPath $manifestPath -Raw |
    ConvertFrom-Json -AsHashtable -Depth 100
Assert-R23D43StartupAnalysis (
    [string]$manifestObject.schema_version -ceq
        "sporespore_r23d43_rapier_startup_transform_analysis_manifest_v1" -and
    [string]$manifestObject.question_class -ceq
        "postclosure_development_diagnosis" -and
    @($manifestObject.campaigns).Count -eq 6
) "analysis manifest identity changed"

foreach ($campaign in $manifestObject.campaigns) {
    $closure = $campaign.closure
    $closureCommit = [string]$closure.git_commit
    $closureRelative = [string]$closure.path
    Assert-R23D43StartupAnalysis (
        (git -C $repoRoot rev-parse "${closureCommit}:${closureRelative}").Trim() -ceq
            [string]$closure.git_blob_oid -and
        (Get-R23D43GitBlobSha256 $closureCommit $closureRelative) -ceq
            [string]$closure.raw_sha256
    ) "immutable source-closure binding changed for $($campaign.campaign_key)"
}

$pythonMatches = @(
    Get-Command python.exe -CommandType Application -ErrorAction Stop
)
Assert-R23D43StartupAnalysis ($pythonMatches.Count -ge 1) (
    "python.exe is unavailable"
)
$python = [IO.Path]::GetFullPath([string]$pythonMatches[0].Source)
Assert-R23D43StartupAnalysis (Test-Path -LiteralPath $python -PathType Leaf) (
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
Assert-R23D43StartupAnalysis ($analyzerExit -eq 0) (
    "analyzer failed: $analyzerOutput"
)

$markerPrefix = "R23D43_STARTUP_TRANSFORM_ANALYSIS_PASS "
$markers = @(
    ($analyzerOutput -split '\r?\n') | Where-Object {
        $_.StartsWith($markerPrefix, [StringComparison]::Ordinal)
    }
)
Assert-R23D43StartupAnalysis ($markers.Count -eq 1) (
    "analyzer marker count changed"
)
$report = $markers[0].Substring($markerPrefix.Length) |
    ConvertFrom-Json -AsHashtable -Depth 100
$claims = $manifestObject.claim_limits
Assert-R23D43StartupAnalysis (
    [string]$report.schema_version -ceq
        "sporespore_r23d43_rapier_startup_transform_analysis_report_v1" -and
    [string]$report.analyzer_source_commit -ceq $sourceCommit -and
    [int]$report.input_summary.campaign_count -eq 6 -and
    [int]$report.input_summary.cell_count -eq 18 -and
    [int]$report.input_summary.total_trace_row_count -eq 53856 -and
    [long]$report.input_summary.total_trace_byte_length -eq 233763048 -and
    [int]$report.input_summary.live_attempt_path_input_count -eq 0 -and
    [int]$report.model_construction_count -eq 0 -and
    [int]$report.world_attempt_count -eq 0 -and
    [int]$report.world_build_count -eq 0 -and
    [bool]$report.direct_observations.startup_transform_and_seed_remain_confounded -and
    -not [bool]$report.direct_observations.causal_effect_or_population_inference_permitted -and
    @($claims.Keys | Where-Object { [bool]$report[$_] }).Count -eq 0
) "report boundary changed"

$artifact = Publish-SporeSporeContentAddressedArtifact `
    -RepoRoot $repoRoot `
    -ArtifactPath $reportPath `
    -MediaType "application/json"
$manifestRelative = [IO.Path]::GetRelativePath($repoRoot, $manifestPath).
    Replace('\', '/')
$analyzerRelative = [IO.Path]::GetRelativePath($repoRoot, $analyzerPath).
    Replace('\', '/')
$receipt = [ordered]@{
    schema_version = (
        "sporespore_r23d43_rapier_startup_transform_analysis_receipt_v1"
    )
    analysis_id = [string]$report.analysis_id
    generated_utc = [DateTime]::UtcNow.ToString("o")
    analyzer_source_commit = $sourceCommit
    manifest_path = $manifestRelative
    manifest_sha256 = [string]$report.manifest.sha256
    analyzer_path = $analyzerRelative
    report_path = $reportPath
    report_sha256 = [string]$artifact.sha256
    report_byte_length = [long]$artifact.byte_length
    report_cas_payload_path = [string]$artifact.payload_path
    report_cas_manifest_path = [string]$artifact.manifest_path
    campaign_count = 6
    content_addressed_input_count = 18
    total_trace_row_count = 53856
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
    "R23D43_STARTUP_TRANSFORM_RETAINED " +
    "analysis=$($receipt.analysis_id) campaigns=6 cells=18 rows=53856 " +
    "report=$($receipt.report_sha256) models=0 worlds=0 physical=False"
)
