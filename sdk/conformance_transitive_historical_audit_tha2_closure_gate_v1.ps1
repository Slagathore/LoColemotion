#requires -Version 7.0

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$closurePath = Join-Path $PSScriptRoot (
    "conformance_transitive_historical_audit_tha2_closure_v1.json"
)
$contractPath = Join-Path $PSScriptRoot (
    "conformance_transitive_historical_audit_contract_v2.json"
)
$prospectiveGatePath = Join-Path $PSScriptRoot (
    "conformance_transitive_historical_audit_gate_v2.ps1"
)
$artifactStorePath = Join-Path $PSScriptRoot "content_addressed_artifact_store.ps1"
$runnerPath = Join-Path $PSScriptRoot "run_conformance.ps1"

function Assert-Tha2Closure {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw "THA2 closure failed: $Message" }
}

function Get-GitBlobRawSha256 {
    param(
        [Parameter(Mandatory)][string]$Commit,
        [Parameter(Mandatory)][string]$RelativePath
    )
    $oid = (& git -C $repoRoot rev-parse "$Commit`:$RelativePath").Trim()
    Assert-Tha2Closure ($LASTEXITCODE -eq 0 -and $oid -cmatch '^[0-9a-f]{40}$') (
        "cannot resolve source blob: $Commit`:$RelativePath"
    )
    $startInfo = [Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = "git"
    $startInfo.WorkingDirectory = $repoRoot
    $startInfo.UseShellExecute = $false
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $startInfo.ArgumentList.Add("cat-file")
    $startInfo.ArgumentList.Add("blob")
    $startInfo.ArgumentList.Add($oid)
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $startInfo
    [void]$process.Start()
    $memory = [IO.MemoryStream]::new()
    $process.StandardOutput.BaseStream.CopyTo($memory)
    $stderr = $process.StandardError.ReadToEnd()
    $process.WaitForExit()
    Assert-Tha2Closure ($process.ExitCode -eq 0) (
        "cannot read source blob: $RelativePath :: $stderr"
    )
    try {
        return "sha256:" + [Convert]::ToHexString(
            [Security.Cryptography.SHA256]::HashData($memory.ToArray())
        ).ToLowerInvariant()
    } finally {
        $memory.Dispose()
        $process.Dispose()
    }
}

foreach ($path in @(
    $closurePath,
    $contractPath,
    $prospectiveGatePath,
    $artifactStorePath,
    $runnerPath
)) {
    Assert-Tha2Closure (Test-Path -LiteralPath $path -PathType Leaf) (
        "missing closure input: $path"
    )
}
. $artifactStorePath

$closure = Get-Content -LiteralPath $closurePath -Raw |
    ConvertFrom-Json -AsHashtable -Depth 100
$source = $closure.source
$run = $closure.commissioning_run
$comparison = $closure.baseline_comparison
$disposition = $closure.disposition

Assert-Tha2Closure (
    [string]$closure.schema_version -ceq
        "sporespore_conformance_transitive_historical_audit_tha2_closure_v1" -and
    [string]$closure.status -ceq
        "closed_positive_execution_graph_whole_suite_speedup_rejected" -and
    [string]$closure.contract_id -ceq
        "THA2-MATERIAL-PUBLICATION-VERIFIER-AWARE-TRANSITIVE-EXECUTION" -and
    [string]$source.commit -ceq
        "7315718bc1404e36aeaa62dc5f23761d1bdb016d" -and
    [string]$source.tree -ceq
        "4d90b40fce50b0b5106835f83cf50d9f6568730a"
) "closure or source identity changed"

Assert-Tha2Closure (
    (Get-GitBlobRawSha256 -Commit $source.commit -RelativePath $source.contract_path) -ceq
        [string]$source.contract_raw_sha256 -and
    (Get-GitBlobRawSha256 -Commit $source.commit -RelativePath $source.gate_path) -ceq
        [string]$source.gate_raw_sha256 -and
    (Get-GitBlobRawSha256 -Commit $source.commit -RelativePath $source.runner_path) -ceq
        [string]$source.runner_raw_sha256 -and
    (& git -C $repoRoot rev-parse "$($source.commit)^{tree}").Trim() -ceq
        [string]$source.tree
) "commissioned source blob or tree changed"

$evidenceRoot = Get-SporeSporeArtifactEvidenceRoot -RepoRoot $repoRoot
function Read-Tha2ReceiptFromCas {
    param([string]$Sha256, [long]$ByteLength)
    $hex = $Sha256.Substring(7)
    $directory = Join-Path $evidenceRoot "artifacts\sha256\$hex"
    Assert-Tha2Closure (Test-SporeSporeStoredArtifact `
        -Directory $directory `
        -ExpectedSha256 $hex `
        -ExpectedByteLength $ByteLength) "receipt CAS failed: $Sha256"
    return Get-Content -LiteralPath (Join-Path $directory "payload.bin") -Raw |
        ConvertFrom-Json -AsHashtable -Depth 100
}

$commissioningReceipt = Read-Tha2ReceiptFromCas `
    -Sha256 ([string]$run.receipt_sha256) `
    -ByteLength ([long]$run.receipt_byte_length)
$baselineReceipt = Read-Tha2ReceiptFromCas `
    -Sha256 ([string]$comparison.baseline_receipt_sha256) `
    -ByteLength ([long]$comparison.baseline_receipt_byte_length)

Assert-Tha2Closure (
    [string]$commissioningReceipt.run_id -ceq [string]$run.run_id -and
    [string]$commissioningReceipt.status -ceq "passed" -and
    [string]$commissioningReceipt.tier -ceq "canonical_no_godot" -and
    [string]$commissioningReceipt.source.head -ceq [string]$source.commit -and
    [string]$commissioningReceipt.source.head_tree -ceq [string]$source.tree -and
    [double]$commissioningReceipt.duration_seconds -eq [double]$run.duration_seconds -and
    @($commissioningReceipt.stage_receipts).Count -eq [int]$run.stage_count -and
    -not [bool]$commissioningReceipt.cache.result_reused -and
    -not [bool]$commissioningReceipt.claims.physical_campaign_executed -and
    -not [bool]$commissioningReceipt.claims.release_authority
) "commissioning receipt changed"

$commissioningStages = @($commissioningReceipt.stage_receipts)
$declaredStages = @($run.stages)
Assert-Tha2Closure (
    $commissioningStages.Count -eq $declaredStages.Count -and
    @($commissioningStages | Where-Object status -ceq 'passed').Count -eq
        [int]$run.passed_stage_count -and
    @($commissioningStages | Where-Object status -ceq 'skipped').Count -eq
        [int]$run.skipped_stage_count
) "commissioning stage cardinality changed"
for ($index = 0; $index -lt $declaredStages.Count; $index += 1) {
    Assert-Tha2Closure (
        [string]$commissioningStages[$index].stage_id -ceq
            [string]$declaredStages[$index].stage_id -and
        [string]$commissioningStages[$index].status -ceq
            [string]$declaredStages[$index].status -and
        [double]$commissioningStages[$index].duration_seconds -eq
            [double]$declaredStages[$index].duration_seconds
    ) "commissioning stage changed at ordinal $($index + 1)"
}

$baselineCampaign = @($baselineReceipt.stage_receipts | Where-Object {
    [string]$_.stage_id -ceq "campaign_closures_and_zero_world_gates"
})
$successorCampaign = @($commissioningStages | Where-Object {
    [string]$_.stage_id -ceq "campaign_closures_and_zero_world_gates"
})
Assert-Tha2Closure (
    [string]$baselineReceipt.run_id -ceq [string]$comparison.baseline_run_id -and
    [string]$baselineReceipt.status -ceq "passed" -and
    [double]$baselineReceipt.duration_seconds -eq
        [double]$comparison.baseline_total_seconds -and
    $baselineCampaign.Count -eq 1 -and $successorCampaign.Count -eq 1 -and
    [double]$baselineCampaign[0].duration_seconds -eq
        [double]$comparison.campaign_closure_stage_baseline_seconds -and
    [double]$successorCampaign[0].duration_seconds -eq
        [double]$comparison.campaign_closure_stage_successor_seconds -and
    [Math]::Abs(
        ([double]$run.duration_seconds - [double]$comparison.baseline_total_seconds) -
        [double]$comparison.total_delta_seconds
    ) -lt 0.000001 -and
    [Math]::Abs(
        ([double]$comparison.campaign_closure_stage_baseline_seconds -
         [double]$comparison.campaign_closure_stage_successor_seconds) -
        [double]$comparison.campaign_closure_stage_reduction_seconds
    ) -lt 0.000001
) "baseline or stage comparison changed"

Assert-Tha2Closure (
    [bool]$disposition.transitive_execution_graph_commissioned -and
    [bool]$disposition.declaration_only_legacy_coverage_registry_commissioned -and
    [bool]$disposition.all_canonical_no_godot_stages_complete -and
    -not [bool]$disposition.whole_suite_speedup_claim_commissioned -and
    [bool]$disposition.performance_estimate_rejected -and
    [bool]$disposition.deduplicated_runner_retained -and
    -not [bool]$comparison.whole_suite_speedup_demonstrated -and
    [bool]$comparison.target_stage_reduction_observed -and
    [bool]$comparison.comparison_is_cross_commit_and_not_causal_isolation -and
    -not [bool]$comparison.inherited_43_8503891_percent_estimate_accepted -and
    -not [bool]$disposition.historical_audit_waiver_permitted -and
    -not [bool]$disposition.production_cache_lookup_permitted -and
    -not [bool]$disposition.production_result_reuse_permitted -and
    -not [bool]$disposition.physical_execution_authorized -and
    -not [bool]$disposition.scientific_locomotion_authority -and
    -not [bool]$disposition.release_authority
) "bounded closure disposition changed"

$runnerSource = Get-Content -LiteralPath $runnerPath -Raw
Assert-Tha2Closure ($runnerSource.Contains(
    "sdk\conformance_transitive_historical_audit_tha2_closure_gate_v1.ps1",
    [StringComparison]::Ordinal
)) "canonical closure binding is missing"

Write-Output (
    "CONFORMANCE_TRANSITIVE_HISTORICAL_AUDIT_V2_CLOSURE_PASS " +
    "run=20260811T032159Z-7315718b stages=8 total_seconds=1652.4179702 " +
    "baseline_seconds=1597.2312833 total_speedup=False target_stage_reduction_seconds=169.9574578 " +
    "target_stage_reduction_percent=23.4331038 graph_commissioned=True registry_commissioned=True " +
    "cache=disabled waiver=False worlds=0 physical_authority=False release_authority=False"
)
