#requires -Version 7.0

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$sdkRoot = Join-Path $repoRoot "sdk"
$closurePath = Join-Path $sdkRoot (
    "conformance_audit_profiler_resume_closure_v1.json"
)
$contractPath = Join-Path $sdkRoot "conformance_audit_profiler_contract_v2.json"
$profilerPath = Join-Path $sdkRoot "measure_conformance_audit_durations_v2.ps1"
$commissioningRunnerPath = Join-Path $sdkRoot (
    "run_conformance_audit_profiler_resume_commissioning.ps1"
)
$artifactStorePath = Join-Path $sdkRoot "content_addressed_artifact_store.ps1"
$dependencyKeyPath = Join-Path $sdkRoot "conformance_dependency_key.ps1"
$auditDependencyPath = Join-Path $sdkRoot "conformance_audit_dependency.ps1"
$runnerPath = Join-Path $sdkRoot "run_conformance.ps1"

function Assert-Cap2Closure {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw "CAP2 closure audit failed: $Message" }
}

foreach ($path in @(
    $closurePath, $contractPath, $profilerPath, $commissioningRunnerPath,
    $artifactStorePath, $dependencyKeyPath, $auditDependencyPath, $runnerPath
)) {
    Assert-Cap2Closure (Test-Path -LiteralPath $path -PathType Leaf) (
        "missing input: $path"
    )
}
. $artifactStorePath
. $dependencyKeyPath
. $auditDependencyPath

$closure = Get-Content -LiteralPath $closurePath -Raw |
    ConvertFrom-Json -AsHashtable -Depth 64
$contract = Get-Content -LiteralPath $contractPath -Raw |
    ConvertFrom-Json -AsHashtable -Depth 32
$runnerSource = Get-Content -LiteralPath $runnerPath -Raw
Assert-Cap2Closure (
    [string]$closure.schema_version -ceq
        "sporespore_conformance_audit_profiler_resume_closure_v1" -and
    [string]$closure.status -ceq
        "valid_positive_controlled_interruption_resume_no_reuse_authority" -and
    [string]$contract.status -ceq
        "prospective_crash_resilient_development_profiler_uncommissioned" -and
    [bool]$contract.predecessor.new_production_runs_through_v1_refuse -and
    $runnerSource.Contains(
        "tests\test_conformance_audit_profiler_resume_commissioning.ps1",
        [StringComparison]::Ordinal
    )
) "closure, contract, predecessor retirement, or canonical route changed"

$sourceObjects = Get-SporeSporeGitObjectSetInventory `
    -RepoRoot $repoRoot `
    -Objects @(
        [ordered]@{
            role = "cap2_source_commit"
            object_id = [string]$closure.prospective_boundary.source_commit
            object_type = "commit"
        },
        [ordered]@{
            role = "cap2_source_tree"
            object_id = [string]$closure.prospective_boundary.source_tree
            object_type = "tree"
        }
    ) `
    -InventoryId "cap2_resume_commissioning_source"
Assert-Cap2Closure (
    [int]$sourceObjects.object_count -eq 2 -and
    [bool]$sourceObjects.git_object_ids_recomputed -and
    [string]$sourceObjects.inventory_sha256 -ceq
        [string]$closure.prospective_boundary.source_git_object_inventory_sha256 -and
    [string]$closure.prospective_boundary.origin_url -ceq
        "https://github.com/Slagathore/sporespore.git" -and
    [bool]$closure.prospective_boundary.local_origin_and_live_main_equal_source -and
    [bool]$closure.prospective_boundary.source_was_clean -and
    [bool]$closure.prospective_boundary.clean_pushed_negative_control_gate_passed -and
    [int]$closure.prospective_boundary.world_build_count -eq 0
) "clean pushed source commit/tree boundary changed or disappeared"

$relativeRunPath = [string]$closure.retained_run.evidence_root_relative_path
Assert-Cap2Closure (
    -not [IO.Path]::IsPathRooted($relativeRunPath) -and
    -not $relativeRunPath.Contains("..", [StringComparison]::Ordinal)
) "retained run path is not bounded and relative"
$evidenceRoot = Get-SporeSporeArtifactEvidenceRoot -RepoRoot $repoRoot
$runRoot = Join-Path $evidenceRoot $relativeRunPath
Assert-Cap2Closure (Test-Path -LiteralPath $runRoot -PathType Container) (
    "retained run is missing"
)

function Assert-Cap2ClosureFileAndCas {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Sha256,
        [Parameter(Mandatory)][long]$ByteLength,
        [Parameter(Mandatory)][string]$Label
    )
    Assert-Cap2Closure (
        (Test-Path -LiteralPath $Path -PathType Leaf) -and
        (Get-Item -LiteralPath $Path).Length -eq $ByteLength -and
        ("sha256:" + (
            Get-FileHash -LiteralPath $Path -Algorithm SHA256
        ).Hash.ToLowerInvariant()) -ceq $Sha256
    ) "$Label retained bytes changed"
    $hex = $Sha256.Substring(7)
    Assert-Cap2Closure (Test-SporeSporeStoredArtifact `
        -Directory (Join-Path $evidenceRoot "artifacts\sha256\$hex") `
        -ExpectedSha256 $hex `
        -ExpectedByteLength $ByteLength) "$Label CAS verification failed"
}

$manifestPath = Join-Path $runRoot "run_manifest.json"
$profilePath = Join-Path $runRoot "profile.json"
Assert-Cap2ClosureFileAndCas -Path $manifestPath `
    -Sha256 ([string]$closure.retained_run.manifest_sha256) `
    -ByteLength ([long]$closure.retained_run.manifest_byte_length) `
    -Label "run manifest"
Assert-Cap2ClosureFileAndCas -Path $profilePath `
    -Sha256 ([string]$closure.retained_run.profile_sha256) `
    -ByteLength ([long]$closure.retained_run.profile_byte_length) `
    -Label "final profile"

$manifest = Get-Content -LiteralPath $manifestPath -Raw |
    ConvertFrom-Json -AsHashtable -Depth 64
$profile = Get-Content -LiteralPath $profilePath -Raw |
    ConvertFrom-Json -AsHashtable -Depth 64
$recomputedInputKey = Get-SporeSporeDependencyObjectSha256 $manifest.input
Assert-Cap2Closure (
    [string]$manifest.schema_version -ceq
        "sporespore_conformance_audit_run_manifest_v2" -and
    [string]$manifest.run_id -ceq [string]$closure.retained_run.run_id -and
    [string]$manifest.input_key_sha256 -ceq
        [string]$closure.retained_run.input_key_sha256 -and
    $recomputedInputKey -ceq [string]$closure.retained_run.input_key_sha256 -and
    [string]$manifest.input.source.head -ceq
        [string]$closure.prospective_boundary.source_commit -and
    [string]$manifest.input.source.head_tree -ceq
        [string]$closure.prospective_boundary.source_tree -and
    [string]$manifest.input.source.origin_main -ceq
        [string]$closure.prospective_boundary.source_commit -and
    [string]$manifest.input.source.live_main -ceq
        [string]$closure.prospective_boundary.source_commit -and
    [string]$manifest.input.source.remote_url -ceq
        [string]$closure.prospective_boundary.origin_url -and
    [bool]$manifest.input.source.clean_equal_origin_main -and
    [bool]$manifest.input.source.live_remote_main_equal_head -and
    [string]$manifest.input.mode -ceq "commissioning_two_audit_recovery" -and
    -not [bool]$manifest.input.test_only -and
    [bool]$manifest.input.commissioning -and
    [int]$manifest.input.selected_audit_count -eq 2 -and
    [int]$manifest.input.world_build_count -eq 0 -and
    [int]$manifest.input.complete_process_environment_name_count -eq
        [int]$closure.retained_run.complete_process_environment_name_count
) "manifest input key, source, environment, or mode changed"

$expectedAuditPaths = @($closure.retained_run.receipts | ForEach-Object {
    [string]$_.audit_path
})
$manifestAuditPaths = @($manifest.input.selected_audits | ForEach-Object {
    [string]$_.path
})
Assert-Cap2Closure (
    $expectedAuditPaths.Count -eq 2 -and
    [string]$manifestAuditPaths[0] -ceq [string]$expectedAuditPaths[0] -and
    [string]$manifestAuditPaths[1] -ceq [string]$expectedAuditPaths[1]
) "ordered commissioning audit selection changed"

Assert-Cap2Closure (
    [string]$profile.schema_version -ceq
        "sporespore_conformance_audit_duration_profile_v2" -and
    [string]$profile.status -ceq
        "complete_development_observation_all_selected_passed" -and
    [string]$profile.manifest_sha256 -ceq
        [string]$closure.retained_run.manifest_sha256 -and
    [string]$profile.input_key_sha256 -ceq
        [string]$closure.retained_run.input_key_sha256 -and
    [int]$profile.summary.selected_audit_count -eq 2 -and
    [int]$profile.summary.pass_count -eq 2 -and
    [int]$profile.summary.failure_count -eq 0 -and
    [double]$profile.summary.total_audit_seconds -eq
        [double]$closure.commissioning_observation.total_audit_seconds -and
    [int]$profile.summary.resumed_receipt_count -eq 1 -and
    [int]$profile.summary.audit_invocation_count_this_process -eq 1 -and
    [int]$profile.summary.orphan_pending_directory_count -eq 0 -and
    [int]$profile.summary.world_build_count -eq 0 -and
    @($profile.receipt_index).Count -eq 2 -and
    @($profile.receipts).Count -eq 2 -and
    -not [bool]$profile.test_only -and
    [bool]$profile.commissioning -and
    -not [bool]$profile.production_cache_lookup_permitted -and
    -not [bool]$profile.production_result_reuse_permitted -and
    -not [bool]$profile.physical_authority -and
    -not [bool]$profile.scientific_authority -and
    -not [bool]$profile.release_authority
) "final profile summary or authority changed"

$casReferences = [Collections.Generic.List[string]]::new()
$casReferences.Add([string]$closure.retained_run.manifest_sha256)
$casReferences.Add([string]$closure.retained_run.profile_sha256)
for ($index = 0; $index -lt 2; $index += 1) {
    $expected = $closure.retained_run.receipts[$index]
    $receipt = $profile.receipts[$index]
    $ordinal = $index + 1
    $receiptPath = Join-Path $runRoot (
        "receipts\" + $ordinal.ToString("D3") + ".json"
    )
    Assert-Cap2ClosureFileAndCas -Path $receiptPath `
        -Sha256 ([string]$expected.receipt_sha256) `
        -ByteLength ([long]$expected.receipt_byte_length) `
        -Label "receipt ordinal $ordinal"
    $casReferences.Add([string]$expected.receipt_sha256)
    Assert-Cap2Closure (
        [int]$receipt.ordinal -eq $ordinal -and
        [string]$receipt.audit_path -ceq [string]$expected.audit_path -and
        [double]$receipt.duration_seconds -eq [double]$expected.duration_seconds -and
        [int]$receipt.exit_code -eq 0 -and
        [bool]$receipt.passed -and
        -not [bool]$receipt.timed_out -and
        [string]$receipt.stdout_sha256 -ceq [string]$expected.stdout_sha256 -and
        [long]$receipt.stdout_byte_length -eq [long]$expected.stdout_byte_length -and
        [string]$receipt.stderr_sha256 -ceq [string]$expected.stderr_sha256 -and
        [long]$receipt.stderr_byte_length -eq [long]$expected.stderr_byte_length
    ) "receipt ordinal $ordinal projection changed"
    foreach ($streamName in @("stdout", "stderr")) {
        $sha = [string]$receipt["${streamName}_sha256"]
        $bytes = [long]$receipt["${streamName}_byte_length"]
        $hex = $sha.Substring(7)
        Assert-Cap2Closure (Test-SporeSporeStoredArtifact `
            -Directory (Join-Path $evidenceRoot "artifacts\sha256\$hex") `
            -ExpectedSha256 $hex `
            -ExpectedByteLength $bytes) (
            "$streamName CAS failed at ordinal $ordinal"
        )
        $casReferences.Add($sha)
    }
}
$uniqueCas = @($casReferences | Sort-Object -Unique)
Assert-Cap2Closure (
    $casReferences.Count -eq [int]$closure.retained_run.cas_reference_count -and
    $uniqueCas.Count -eq [int]$closure.retained_run.unique_cas_object_count -and
    [bool]$closure.retained_run.all_cas_references_independently_verified
) "CAS reference or unique-object count changed"

Assert-Cap2Closure (
    [bool]$closure.commissioning_observation.start_and_resume_were_distinct_child_processes -and
    [bool]$closure.commissioning_observation.controlled_stop_followed_first_published_receipt -and
    [int]$closure.commissioning_observation.start_process_audit_invocation_count -eq 1 -and
    [int]$closure.commissioning_observation.resume_verified_contiguous_receipt_count -eq 1 -and
    [int]$closure.commissioning_observation.resume_process_audit_invocation_count -eq 1 -and
    [string]$closure.commissioning_observation.first_receipt_sha256_before_resume -ceq
        [string]$closure.commissioning_observation.first_receipt_sha256_after_resume -and
    [bool]$closure.commissioning_observation.first_receipt_unchanged -and
    [bool]$closure.clean_gate_negative_controls.environment_mutation_refused -and
    [bool]$closure.clean_gate_negative_controls.selection_order_mutation_refused -and
    [bool]$closure.clean_gate_negative_controls.concurrent_run_lease_refused -and
    [bool]$closure.clean_gate_negative_controls.manifest_corruption_refused -and
    [bool]$closure.clean_gate_negative_controls.receipt_corruption_refused -and
    [bool]$closure.clean_gate_negative_controls.output_payload_corruption_refused -and
    [bool]$closure.clean_gate_negative_controls.receipt_ordinal_gap_refused -and
    [bool]$closure.clean_gate_negative_controls.completed_run_resume_refused -and
    [bool]$closure.clean_gate_negative_controls.cap1_new_production_route_refused -and
    [bool]$closure.claims.controlled_interruption_resume_commissioned -and
    [bool]$closure.claims.crash_resilient_receipt_protocol_commissioned -and
    [bool]$closure.claims.future_development_profiles_may_use_cap2 -and
    -not [bool]$closure.claims.actual_host_crash_empirically_induced -and
    -not [bool]$closure.claims.production_cache_lookup_permitted -and
    -not [bool]$closure.claims.production_result_reuse_permitted -and
    -not [bool]$closure.claims.historical_audit_waiver_permitted -and
    -not [bool]$closure.claims.physical_execution_authorized -and
    -not [bool]$closure.claims.scientific_locomotion_authority -and
    -not [bool]$closure.claims.release_authority
) "commissioning observation, negative control, or claim boundary changed"

Write-Output (
    "CONFORMANCE_AUDIT_PROFILER_RESUME_COMMISSIONING_PASS audits=2 " +
    "passed=2 interrupted_after=1 resumed_receipts=1 resume_invocations=1 " +
    "first_receipt_unchanged=True cas_references=8 unique_cas=7 " +
    "clean_gate=True controlled_stop=True actual_host_crash=False " +
    "cache=disabled worlds=0 physical_authority=False release_authority=False"
)
