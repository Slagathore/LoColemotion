#requires -Version 7.0

[CmdletBinding()]
param(
    [string]$Manifest = (Join-Path $PSScriptRoot "r23d53_godot_command_contrast_analysis_manifest_v1.json"),
    [string]$EvidenceRoot = (Join-Path (Split-Path -Parent ([IO.Path]::GetFullPath((Join-Path $PSScriptRoot "..\..")))) "SporeSpore_Evidence"),
    [Parameter(Mandatory)][string]$OutputDirectory
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot "..\.."))
$manifestPath = [IO.Path]::GetFullPath($Manifest)
$evidenceRootPath = [IO.Path]::GetFullPath($EvidenceRoot).TrimEnd('\', '/')
$outputRoot = [IO.Path]::GetFullPath($OutputDirectory).TrimEnd('\', '/')
$analyzerPath = Join-Path $PSScriptRoot "analyze_r23d53_godot_command_contrast.py"
$testPath = Join-Path $PSScriptRoot "test_r23d53_godot_command_contrast.ps1"
$artifactStorePath = Join-Path $repoRoot "sdk\content_addressed_artifact_store.ps1"
$runnerPath = [IO.Path]::GetFullPath($PSCommandPath)
. $artifactStorePath

function Assert-R23D53ContrastRun([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "R23D53_COMMAND_CONTRAST_RUN: $Message" }
}

function Get-GitBlobSha256([string]$Commit, [string]$RelativePath) {
    $start = [Diagnostics.ProcessStartInfo]::new()
    $start.FileName = "git"
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    foreach ($argument in @("-C", $repoRoot, "cat-file", "blob", "${Commit}:$RelativePath")) { [void]$start.ArgumentList.Add($argument) }
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $start
    try {
        Assert-R23D53ContrastRun $process.Start() "could not start Git blob reader"
        $stderrTask = $process.StandardError.ReadToEndAsync()
        $hasher = [Security.Cryptography.SHA256]::Create()
        try { $digest = $hasher.ComputeHash($process.StandardOutput.BaseStream) }
        finally { $hasher.Dispose() }
        $process.WaitForExit()
        $stderr = $stderrTask.GetAwaiter().GetResult()
        Assert-R23D53ContrastRun ($process.ExitCode -eq 0) "Git blob read failed: $stderr"
        return "sha256:" + [Convert]::ToHexString($digest).ToLowerInvariant()
    } finally { $process.Dispose() }
}

Assert-R23D53ContrastRun (
    (git -C $repoRoot rev-parse --show-toplevel).Trim() -ceq $repoRoot.Replace('\', '/') -and
    (git -C $repoRoot remote get-url origin).Trim() -ceq "https://github.com/Slagathore/sporespore.git"
) "repository identity changed"
$sourceCommit = (git -C $repoRoot rev-parse HEAD).Trim()
$originMain = (git -C $repoRoot rev-parse origin/main).Trim()
$liveMain = ((git -C $repoRoot ls-remote origin refs/heads/main).Trim() -split '\s+')[0]
$statusEntries = @(git -C $repoRoot status --short --untracked-files=all)
Assert-R23D53ContrastRun (
    $sourceCommit -match '^[0-9a-f]{40}$' -and
    $sourceCommit -ceq $originMain -and
    $sourceCommit -ceq $liveMain -and
    $statusEntries.Count -eq 0
) "analysis source must be clean, pushed, and equal to live main"
foreach ($path in @($manifestPath, $analyzerPath, $testPath, $artifactStorePath, $runnerPath, $evidenceRootPath)) {
    Assert-R23D53ContrastRun (Test-Path -LiteralPath $path) "required path missing: $path"
}
$expectedPrefix = $evidenceRootPath + [IO.Path]::DirectorySeparatorChar
Assert-R23D53ContrastRun (
    $outputRoot.StartsWith($expectedPrefix, [StringComparison]::OrdinalIgnoreCase) -and
    (Split-Path -Leaf $outputRoot).StartsWith("trace-lineage-r23d53-command-contrast-", [StringComparison]::Ordinal) -and
    -not (Test-Path -LiteralPath $outputRoot)
) "output must be a new durable trace-lineage-r23d53-command-contrast-* directory"

$sourceBindings = @()
foreach ($path in @($manifestPath, $analyzerPath, $testPath, $artifactStorePath, $runnerPath)) {
    $relative = [IO.Path]::GetRelativePath($repoRoot, $path).Replace('\', '/')
    $checkoutSha = "sha256:" + (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()
    Assert-R23D53ContrastRun ($checkoutSha -ceq (Get-GitBlobSha256 $sourceCommit $relative)) "checkout differs from Git blob: $relative"
    $sourceBindings += [ordered]@{
        path = $relative
        git_blob_oid = (git -C $repoRoot rev-parse "${sourceCommit}:${relative}").Trim()
        raw_sha256 = $checkoutSha
        byte_length = (Get-Item -LiteralPath $path).Length
    }
}

$python = [IO.Path]::GetFullPath([string](@(Get-Command python.exe -CommandType Application -ErrorAction Stop)[0].Source))
[void][IO.Directory]::CreateDirectory($outputRoot)
$reportPath = Join-Path $outputRoot "report.json"
$receiptPath = Join-Path $outputRoot "receipt.json"
$analyzerOutput = & $python $analyzerPath --manifest $manifestPath --evidence-root $evidenceRootPath --output $reportPath 2>&1 | Out-String
$analyzerExit = $LASTEXITCODE
Assert-R23D53ContrastRun ($analyzerExit -eq 0 -and $analyzerOutput.Contains("R23D53_COMMAND_CONTRAST_DIAGNOSIS_PASS ")) "analyzer failed: $analyzerOutput"
$report = Get-Content -LiteralPath $reportPath -Raw | ConvertFrom-Json -AsHashtable -Depth 100
$findings = $report.aggregate_findings
Assert-R23D53ContrastRun (
    [int]$report.source_trace_count -eq 3 -and
    [int]$report.source_trace_row_count -eq 8976 -and
    [bool]$findings.origin_timing_confound_removed -and
    [bool]$findings.both_desired_heading_contrasts_correct_all_turn_rows -and
    [bool]$findings.all_turn_rows_report_steering_unsaturated -and
    [int]$findings.negative_held_contrast_correct_row_count -eq 974 -and
    [int]$findings.negative_yaw_effect_correct_row_count -eq 556 -and
    -not [bool]$findings.actuator_level_attribution_available -and
    -not [bool]$findings.physical_successor_selected -and
    [int]$report.model_construction_count -eq 0 -and
    [int]$report.world_attempt_count -eq 0 -and
    [int]$report.world_build_count -eq 0
) "report boundary changed"

$artifact = Publish-SporeSporeContentAddressedArtifact -RepoRoot $repoRoot -ArtifactPath $reportPath -MediaType "application/json"
$receipt = [ordered]@{
    schema_version = "sporespore_r23d53_godot_command_contrast_analysis_receipt_v1"
    analysis_id = [string]$report.analysis_id
    generated_utc = [DateTime]::UtcNow.ToString("o")
    analyzer_source_commit = $sourceCommit
    source_bindings = $sourceBindings
    python_executable = $python
    python_executable_sha256 = "sha256:" + (Get-FileHash -LiteralPath $python -Algorithm SHA256).Hash.ToLowerInvariant()
    powershell_version = $PSVersionTable.PSVersion.ToString()
    report_path = $reportPath
    report_sha256 = [string]$artifact.sha256
    report_byte_length = [long]$artifact.byte_length
    report_cas_payload_path = [string]$artifact.payload_path
    report_cas_manifest_path = [string]$artifact.manifest_path
    source_trace_count = 3
    source_trace_row_count = 8976
    model_construction_count = 0
    world_attempt_count = 0
    world_build_count = 0
    physical_execution_authorized = $false
    physical_acceptance_authority = $false
}
$utf8 = [Text.UTF8Encoding]::new($false)
[IO.File]::WriteAllText($receiptPath, ($receipt | ConvertTo-Json -Depth 100) + "`n", $utf8)
$receiptSha = "sha256:" + (Get-FileHash -LiteralPath $receiptPath -Algorithm SHA256).Hash.ToLowerInvariant()
Write-Host "R23D53_COMMAND_CONTRAST_ANALYSIS_RETAINED source=$sourceCommit report=$($artifact.sha256) receipt=$receiptSha traces=3 rows=8976 negative_held=974 negative_yaw=556 models=0 worlds=0 physical=False"
