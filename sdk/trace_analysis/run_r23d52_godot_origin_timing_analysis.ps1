#requires -Version 7.0

[CmdletBinding()]
param(
    [string]$Manifest = (
        Join-Path $PSScriptRoot (
            "r23d52_godot_origin_timing_analysis_manifest_v1.json"
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
$analyzerPath = Join-Path $PSScriptRoot "analyze_r23d52_godot_origin_timing.py"
$testPath = Join-Path $PSScriptRoot "test_r23d52_godot_origin_timing.ps1"
$artifactStorePath = Join-Path $repoRoot "sdk\content_addressed_artifact_store.ps1"
$runnerPath = [IO.Path]::GetFullPath($PSCommandPath)

. $artifactStorePath

function Assert-R23D52OriginAnalysis([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "R23D52_ORIGIN_ANALYSIS: $Message" }
}

function Get-GitBlobSha256([string]$Commit, [string]$RelativePath) {
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
        Assert-R23D52OriginAnalysis $process.Start() "could not start Git blob reader"
        $stderrTask = $process.StandardError.ReadToEndAsync()
        $hasher = [Security.Cryptography.SHA256]::Create()
        try { $digest = $hasher.ComputeHash($process.StandardOutput.BaseStream) }
        finally { $hasher.Dispose() }
        $process.WaitForExit()
        $stderr = $stderrTask.GetAwaiter().GetResult()
        Assert-R23D52OriginAnalysis ($process.ExitCode -eq 0) (
            "Git blob read failed for ${RelativePath}: $stderr"
        )
        return "sha256:" + [Convert]::ToHexString($digest).ToLowerInvariant()
    } finally { $process.Dispose() }
}

Assert-R23D52OriginAnalysis (
    (git -C $repoRoot rev-parse --show-toplevel).Trim() -ceq
        $repoRoot.Replace('\', '/') -and
    (git -C $repoRoot remote get-url origin).Trim() -ceq $expectedRemote
) "repository identity changed"

$sourceCommit = (git -C $repoRoot rev-parse HEAD).Trim()
$originMain = (git -C $repoRoot rev-parse origin/main).Trim()
$liveLine = (git -C $repoRoot ls-remote origin refs/heads/main).Trim()
$liveMain = ($liveLine -split '\s+')[0]
$statusEntries = @(git -C $repoRoot status --short)
Assert-R23D52OriginAnalysis (
    $sourceCommit -match '^[0-9a-f]{40}$' -and
    $sourceCommit -ceq $originMain -and
    $sourceCommit -ceq $liveMain -and
    $statusEntries.Count -eq 0
) "analysis source must be clean, pushed, and equal to live main"

foreach ($path in @(
    $manifestPath,
    $analyzerPath,
    $testPath,
    $artifactStorePath,
    $runnerPath,
    $evidenceRootPath
)) {
    Assert-R23D52OriginAnalysis (Test-Path -LiteralPath $path) (
        "required path missing: $path"
    )
}

$expectedOutputPrefix = $evidenceRootPath + [IO.Path]::DirectorySeparatorChar
Assert-R23D52OriginAnalysis (
    $outputRoot.StartsWith(
        $expectedOutputPrefix,
        [StringComparison]::OrdinalIgnoreCase
    ) -and
    (Split-Path -Leaf $outputRoot).StartsWith(
        "trace-lineage-r23d52-origin-timing-",
        [StringComparison]::Ordinal
    ) -and
    -not (Test-Path -LiteralPath $outputRoot)
) "output must be a new trace-lineage-r23d52-origin-timing-* directory under the durable evidence root"

$sourcePaths = @(
    $manifestPath,
    $analyzerPath,
    $testPath,
    $artifactStorePath,
    $runnerPath
)
$sourceBindings = @()
foreach ($path in $sourcePaths) {
    $relativePath = [IO.Path]::GetRelativePath($repoRoot, $path).Replace('\', '/')
    $checkoutSha = "sha256:" + (
        Get-FileHash -LiteralPath $path -Algorithm SHA256
    ).Hash.ToLowerInvariant()
    Assert-R23D52OriginAnalysis (
        $checkoutSha -ceq (Get-GitBlobSha256 $sourceCommit $relativePath)
    ) "checkout bytes differ from source Git blob: $relativePath"
    $sourceBindings += [ordered]@{
        path = $relativePath
        git_blob_oid = (git -C $repoRoot rev-parse "${sourceCommit}:${relativePath}").Trim()
        raw_sha256 = $checkoutSha
        byte_length = (Get-Item -LiteralPath $path).Length
    }
}

$manifestObject = Get-Content -LiteralPath $manifestPath -Raw |
    ConvertFrom-Json -AsHashtable -Depth 100
Assert-R23D52OriginAnalysis (
    [string]$manifestObject.schema_version -ceq
        "sporespore_r23d52_godot_origin_timing_analysis_manifest_v1" -and
    [string]$manifestObject.analysis_id -ceq
        "QSDK-R23D52-GODOT-ORIGIN-TIMING-D1" -and
    @($manifestObject.pairs).Count -eq 3 -and
    @($manifestObject.claim_limits.Values | Where-Object { [bool]$_ }).Count -eq 0
) "analysis manifest identity or claim boundary changed"

$pythonMatches = @(Get-Command python.exe -CommandType Application -ErrorAction Stop)
Assert-R23D52OriginAnalysis ($pythonMatches.Count -ge 1) "python.exe unavailable"
$python = [IO.Path]::GetFullPath([string]$pythonMatches[0].Source)
Assert-R23D52OriginAnalysis (Test-Path -LiteralPath $python -PathType Leaf) (
    "resolved Python executable is missing"
)

[void][IO.Directory]::CreateDirectory($outputRoot)
$reportPath = Join-Path $outputRoot "report.json"
$receiptPath = Join-Path $outputRoot "receipt.json"
$analyzerOutput = & $python $analyzerPath `
    --manifest $manifestPath `
    --evidence-root $evidenceRootPath `
    --output $reportPath 2>&1 | Out-String
$analyzerExit = $LASTEXITCODE
Assert-R23D52OriginAnalysis ($analyzerExit -eq 0) (
    "analyzer failed: $analyzerOutput"
)
$markerPrefix = "R23D52_ORIGIN_TIMING_DIAGNOSIS_PASS "
$markers = @(($analyzerOutput -split '\r?\n') | Where-Object {
    $_.StartsWith($markerPrefix, [StringComparison]::Ordinal)
})
Assert-R23D52OriginAnalysis ($markers.Count -eq 1) "analyzer marker count changed"
$report = Get-Content -LiteralPath $reportPath -Raw |
    ConvertFrom-Json -AsHashtable -Depth 100
$findings = $report.aggregate_findings
Assert-R23D52OriginAnalysis (
    [string]$report.schema_version -ceq
        "sporespore_r23d52_godot_origin_timing_analysis_report_v1" -and
    [string]$report.analysis_id -ceq
        "QSDK-R23D52-GODOT-ORIGIN-TIMING-D1" -and
    [int]$report.source_trace_count -eq 6 -and
    [int]$report.source_trace_row_count -eq 17952 -and
    [bool]$findings.all_step_zero_physical_observations_equal -and
    [bool]$findings.all_pairs_controller_changed_at_step_zero -and
    [int]$findings.earliest_torso_position_difference_step -eq 5 -and
    [int]$findings.earliest_measured_yaw_difference_step -eq 14 -and
    -not [bool]$findings.warmup_trajectory_isolated_from_origin_policy -and
    [bool]$findings.both_commanded_arms_first_cycle_direction_correct -and
    [bool]$findings.both_commanded_arms_later_cycles_reverse_direction -and
    [bool]$findings.negative_arm_requested_sign_consistent_every_turn_row -and
    [int]$report.model_construction_count -eq 0 -and
    [int]$report.world_attempt_count -eq 0 -and
    [int]$report.world_build_count -eq 0 -and
    -not [bool]$report.historical_result_reinterpreted -and
    -not [bool]$report.physical_execution_authorized -and
    -not [bool]$report.physical_acceptance_authority
) "analysis report boundary changed"

$artifact = Publish-SporeSporeContentAddressedArtifact `
    -RepoRoot $repoRoot `
    -ArtifactPath $reportPath `
    -MediaType "application/json"
$receipt = [ordered]@{
    schema_version = "sporespore_r23d52_godot_origin_timing_analysis_receipt_v1"
    analysis_id = [string]$report.analysis_id
    generated_utc = [DateTime]::UtcNow.ToString("o")
    analyzer_source_commit = $sourceCommit
    source_bindings = $sourceBindings
    python_executable = $python
    python_executable_sha256 = "sha256:" + (
        Get-FileHash -LiteralPath $python -Algorithm SHA256
    ).Hash.ToLowerInvariant()
    powershell_version = $PSVersionTable.PSVersion.ToString()
    report_path = $reportPath
    report_sha256 = [string]$artifact.sha256
    report_byte_length = [long]$artifact.byte_length
    report_cas_payload_path = [string]$artifact.payload_path
    report_cas_manifest_path = [string]$artifact.manifest_path
    source_trace_count = [int]$report.source_trace_count
    source_trace_row_count = [int]$report.source_trace_row_count
    model_construction_count = 0
    world_attempt_count = 0
    world_build_count = 0
    physical_execution_authorized = $false
    physical_acceptance_authority = $false
}
$utf8 = [Text.UTF8Encoding]::new($false)
$receiptJson = $receipt | ConvertTo-Json -Depth 100
[IO.File]::WriteAllText($receiptPath, $receiptJson + "`n", $utf8)
$receiptSha = "sha256:" + (
    Get-FileHash -LiteralPath $receiptPath -Algorithm SHA256
).Hash.ToLowerInvariant()

Write-Host (
    "R23D52_ORIGIN_TIMING_ANALYSIS_RETAINED source=$sourceCommit " +
    "report=$($artifact.sha256) receipt=$receiptSha traces=6 rows=17952 " +
    "controller_step=0 position_step=5 yaw_step=14 models=0 worlds=0"
)
