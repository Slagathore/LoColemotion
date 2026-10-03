#requires -Version 7.0

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$sdkRoot = Join-Path $repoRoot "sdk"
$closurePath = Join-Path $sdkRoot "conformance_audit_profiler_closure_v1.json"
$contractPath = Join-Path $sdkRoot "conformance_audit_profiler_contract_v1.json"
$dependencyKeyPath = Join-Path $sdkRoot "conformance_dependency_key.ps1"
$auditDependencyPath = Join-Path $sdkRoot "conformance_audit_dependency.ps1"
$artifactStorePath = Join-Path $sdkRoot "content_addressed_artifact_store.ps1"
$runnerPath = Join-Path $sdkRoot "run_conformance.ps1"

function Assert-Cap1Closure {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw "CAP1 closure audit failed: $Message" }
}

foreach ($path in @(
    $closurePath, $contractPath, $dependencyKeyPath, $auditDependencyPath,
    $artifactStorePath, $runnerPath
)) {
    Assert-Cap1Closure (Test-Path -LiteralPath $path -PathType Leaf) (
        "missing input: $path"
    )
}
. $dependencyKeyPath
. $auditDependencyPath
. $artifactStorePath

$closure = Get-Content -LiteralPath $closurePath -Raw |
    ConvertFrom-Json -AsHashtable -Depth 64
$contract = Get-Content -LiteralPath $contractPath -Raw |
    ConvertFrom-Json -AsHashtable -Depth 32
$runnerSource = Get-Content -LiteralPath $runnerPath -Raw
Assert-Cap1Closure (
    [string]$closure.schema_version -ceq
        "sporespore_conformance_audit_profiler_closure_v1" -and
    [string]$closure.status -ceq
        "valid_positive_development_profile_no_reuse_authority" -and
    [string]$contract.status -ceq
        "prospective_development_profiler_no_reuse_authority" -and
    $runnerSource.Contains(
        "tests\test_conformance_audit_profiler_commissioning.ps1",
        [StringComparison]::Ordinal
    )
) "closure, contract, or canonical route changed"

$sourceObjects = Get-SporeSporeGitObjectSetInventory `
    -RepoRoot $repoRoot `
    -Objects @(
        [ordered]@{
            role = "cap1_source_commit"
            object_id = [string]$closure.prospective_boundary.source_commit
            object_type = "commit"
        },
        [ordered]@{
            role = "cap1_source_tree"
            object_id = [string]$closure.prospective_boundary.source_tree
            object_type = "tree"
        }
    ) `
    -InventoryId "cap1_full_profile_source"
Assert-Cap1Closure (
    [int]$sourceObjects.object_count -eq 2 -and
    [bool]$sourceObjects.git_object_ids_recomputed -and
    [string]$sourceObjects.inventory_sha256 -ceq
        [string]$closure.prospective_boundary.source_git_object_inventory_sha256
) "profile source commit/tree changed or disappeared"

$evidenceRoot = Get-SporeSporeArtifactEvidenceRoot -RepoRoot $repoRoot
$relativeProfilePath = [string]$closure.retained_profile.evidence_path
Assert-Cap1Closure (
    -not [IO.Path]::IsPathRooted($relativeProfilePath) -and
    -not $relativeProfilePath.Contains("..", [StringComparison]::Ordinal)
) "profile evidence path is not bounded and relative"
$profilePath = Join-Path $evidenceRoot $relativeProfilePath
Assert-Cap1Closure (
    (Test-Path -LiteralPath $profilePath -PathType Leaf) -and
    (Get-Item -LiteralPath $profilePath).Length -eq
        [long]$closure.retained_profile.byte_length -and
    (Get-SporeSporeDependencyRawSha256 $profilePath) -ceq
        [string]$closure.retained_profile.sha256
) "retained profile bytes changed"
$profileHex = ([string]$closure.retained_profile.sha256).Substring(7)
Assert-Cap1Closure (Test-SporeSporeStoredArtifact `
    -Directory (Join-Path $evidenceRoot "artifacts\sha256\$profileHex") `
    -ExpectedSha256 $profileHex `
    -ExpectedByteLength ([long]$closure.retained_profile.byte_length)) (
    "retained profile CAS failed"
)

$profile = Get-Content -LiteralPath $profilePath -Raw |
    ConvertFrom-Json -AsHashtable -Depth 64
$receipts = @($profile.receipts)
$ranking = @($profile.ranking)
Assert-Cap1Closure (
    [string]$profile.status -ceq
        "complete_development_observation_all_selected_passed" -and
    [string]$profile.run_id -ceq [string]$closure.retained_profile.run_id -and
    [bool]$profile.source.clean_equal_origin_main -and
    [int]$profile.summary.selected_audit_count -eq 95 -and
    [int]$profile.summary.pass_count -eq 95 -and
    [int]$profile.summary.failure_count -eq 0 -and
    $receipts.Count -eq 95 -and
    $ranking.Count -eq 95 -and
    -not [bool]$profile.test_only -and
    [bool]$profile.development_observation_only -and
    -not [bool]$profile.production_cache_lookup_permitted -and
    -not [bool]$profile.production_result_reuse_permitted -and
    -not [bool]$profile.physical_authority -and
    -not [bool]$profile.scientific_authority -and
    -not [bool]$profile.release_authority
) "profile summary or authority changed"

$sum = 0.0
$verifiedStreams = 0
foreach ($receipt in $receipts) {
    Assert-Cap1Closure (
        [bool]$receipt.passed -and
        [int]$receipt.exit_code -eq 0 -and
        -not [bool]$receipt.timed_out -and
        -not [bool]$receipt.timeout_is_proven_hang
    ) "profile contains a failed or timed-out audit"
    $sum += [double]$receipt.duration_seconds
    $ordinalName = ([int]$receipt.ordinal).ToString("D3")
    foreach ($streamName in @("stdout", "stderr")) {
        $sha = [string]$receipt["${streamName}_sha256"]
        $bytes = [long]$receipt["${streamName}_byte_length"]
        $streamPath = Join-Path (Split-Path -Parent $profilePath) (
            "streams\$ordinalName\$streamName.txt"
        )
        Assert-Cap1Closure (
            (Test-Path -LiteralPath $streamPath -PathType Leaf) -and
            (Get-Item -LiteralPath $streamPath).Length -eq $bytes -and
            (Get-SporeSporeDependencyRawSha256 $streamPath) -ceq $sha
        ) "retained stream bytes changed: $streamPath"
        $hex = $sha.Substring(7)
        Assert-Cap1Closure (Test-SporeSporeStoredArtifact `
            -Directory (Join-Path $evidenceRoot "artifacts\sha256\$hex") `
            -ExpectedSha256 $hex `
            -ExpectedByteLength $bytes) "stream CAS failed: $sha"
        $verifiedStreams += 1
    }
}
Assert-Cap1Closure (
    $verifiedStreams -eq 190 -and
    [Math]::Abs($sum - [double]$closure.retained_profile.total_audit_seconds) -lt
        0.000001
) "stream count or duration sum changed"

for ($index = 1; $index -lt $ranking.Count; $index += 1) {
    Assert-Cap1Closure (
        [double]$ranking[$index - 1].duration_seconds -ge
            [double]$ranking[$index].duration_seconds
    ) "duration ranking is not descending"
}
$topFive = 0.0
$topTen = 0.0
$topTwenty = 0.0
for ($index = 0; $index -lt 20; $index += 1) {
    $value = [double]$ranking[$index].duration_seconds
    if ($index -lt 5) { $topFive += $value }
    if ($index -lt 10) { $topTen += $value }
    $topTwenty += $value
}
$publications = @($ranking | Where-Object {
    [string]$_.audit_path -like "*material_profile_publication*"
})
$publicationSeconds = 0.0
foreach ($entry in $publications) {
    $publicationSeconds += [double]$entry.duration_seconds
}
Assert-Cap1Closure (
    [Math]::Abs($topFive - [double]$closure.ranked_observation.top_five_seconds) -lt
        0.000001 -and
    [Math]::Abs($topTen - [double]$closure.ranked_observation.top_ten_seconds) -lt
        0.000001 -and
    [Math]::Abs($topTwenty - [double]$closure.ranked_observation.top_twenty_seconds) -lt
        0.000001 -and
    $publications.Count -eq 5 -and
    [Math]::Abs(
        $publicationSeconds -
        [double]$closure.ranked_observation.material_profile_publication_seconds
    ) -lt 0.000001 -and
    [string]$ranking[0].audit_path -ceq
        [string]$closure.target_selection.first_single_audit_candidate -and
    [double]$ranking[0].duration_seconds -eq
        [double]$closure.target_selection.first_single_audit_duration_seconds
) "ranking concentration or selected target changed"

Assert-Cap1Closure (
    [bool]$closure.host_wrapper_incident.outer_tool_timed_out_before_profile_completion -and
    [bool]$closure.host_wrapper_incident.profiler_process_survived_as_orphan_and_completed -and
    -not [bool]$closure.host_wrapper_incident.scientific_result_affected -and
    [bool]$closure.profiler_defect.crash_before_final_profile_would_lose_completed_durations -and
    [bool]$closure.profiler_defect.successor_must_publish_each_duration_receipt_immediately -and
    [bool]$closure.profiler_defect.successor_should_support_exact_resume_from_verified_receipts -and
    [bool]$closure.claims.development_profile_positive -and
    [bool]$closure.claims.all_selected_audits_passed -and
    [bool]$closure.claims.cache_target_selected_for_characterization -and
    -not [bool]$closure.claims.production_cache_lookup_permitted -and
    -not [bool]$closure.claims.production_result_reuse_permitted -and
    -not [bool]$closure.claims.historical_audit_waiver_permitted -and
    -not [bool]$closure.claims.physical_execution_authorized -and
    -not [bool]$closure.claims.scientific_locomotion_authority -and
    -not [bool]$closure.claims.release_authority
) "incident, successor requirement, or claim boundary changed"

Write-Output (
    "CONFORMANCE_AUDIT_PROFILER_COMMISSIONING_PASS audits=95 passed=95 " +
    "streams=190 total_seconds=2274.4750496 top5_share=44.3596 " +
    "publication_share=40.0430 first_target=bw27p crash_resilient=False " +
    "cache=disabled worlds=0 physical_authority=False release_authority=False"
)
