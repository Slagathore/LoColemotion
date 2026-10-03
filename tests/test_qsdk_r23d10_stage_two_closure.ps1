#requires -Version 7.0

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$stageTwoCommit = "94f724adecd1ab6d95339dc8a3224fad2a2d586d"
$stageTwoParent = "60f475352fde6958798b4a0d7c21fb0dc354f87b"
$fixedBlobs = [ordered]@{
    "sdk/turning/r23d10_stage_two_evidence_contract_v1.json" =
        "f307facd3c1051eb1313831dfd2e8236c71fc775df832d5d3e6ee440aa0578be"
    "tests/test_qsdk_r23d10_stage_two_evidence.ps1" =
        "a114e05568f77c850aa06a9c5dd1804bae07e3442b10f8a313c9890e66b054c3"
    "sdk/release/quadruped_release_contract.json" =
        "354ef521295273f0025101d63f52dfa4633dd1803535bd3349b9d40a0f537756"
    "sdk/release/quadruped_support_matrix.json" =
        "55754f4dfc6a8bdc85e77dcd1f8c3cca7cdbf352d316d177dd13528134a47c7e"
}
$expectedChangedPaths = @(
    "docs/ENGINE_NEUTRAL_LOCOMOTION_SDK_BOOTSTRAP.md",
    "docs/README.md",
    "docs/SDK_PORTABLE_BALANCED_WAVE_SUCCESSOR_BOOTSTRAP.md",
    "docs/SDK_PRODUCT_AND_ADAPTATION_ROADMAP.md",
    "sdk/README.md",
    "sdk/closure_evidence_mode_inventory.json",
    "sdk/closure_evidence_provenance_contract.json",
    "sdk/publish_qsdk_r23d10_trace.ps1",
    "sdk/release/README.md",
    "sdk/release/quadruped_release_contract.json",
    "sdk/release/quadruped_support_matrix.json",
    "sdk/run_conformance.ps1",
    "sdk/turning/README.md",
    "sdk/turning/r23d10_physical_evaluator.py",
    "sdk/turning/r23d10_physical_trace.py",
    "sdk/turning/r23d10_stage_two_evidence_contract_v1.json",
    "sdk/turning/test_r23d10_physical_evaluator.py",
    "sdk/turning/test_r23d10_physical_trace.py",
    "sdk/workbench/experiment_catalog.json",
    "tests/test_closure_evidence_provenance_contract.ps1",
    "tests/test_locomotion_experiment_workbench.ps1",
    "tests/test_qsdk_r23d10_stage_one_closure.ps1",
    "tests/test_qsdk_r23d10_stage_two_evidence.ps1"
)
$futurePaths = @(
    "sdk/turning/r23d10_physical_implementation_contract_v1.json",
    "sdk/turning/r23d10_dependency_closure.ps1",
    "sdk/turning/r23d10_terminal_marker_classifier.ps1",
    "sdk/run_qsdk_r23d10_authorization_canaries.ps1",
    "sdk/run_qsdk_r23d10_supervisor.ps1",
    "sdk/run_qsdk_r23d10_zero_world_gate.ps1"
)

function Assert-R23D10StageTwoClosure(
    [bool]$Condition,
    [string]$Message
) {
    if (-not $Condition) { throw $Message }
}

function Get-R23D10StageTwoBlobHash([string]$Commit, [string]$Path) {
    $blobOid = (git -C $repoRoot rev-parse ("$Commit`:$Path")).Trim()
    Assert-R23D10StageTwoClosure ($LASTEXITCODE -eq 0) (
        "QSDK-R23D10 stage-two blob unavailable: $Path"
    )
    $start = [Diagnostics.ProcessStartInfo]::new()
    $start.FileName = "git"
    $start.WorkingDirectory = $repoRoot
    $start.UseShellExecute = $false
    $start.RedirectStandardOutput = $true
    [void]$start.ArgumentList.Add("cat-file")
    [void]$start.ArgumentList.Add("blob")
    [void]$start.ArgumentList.Add($blobOid)
    $process = [Diagnostics.Process]::Start($start)
    $memory = [IO.MemoryStream]::new()
    try {
        $process.StandardOutput.BaseStream.CopyTo($memory)
        $process.WaitForExit()
        Assert-R23D10StageTwoClosure ($process.ExitCode -eq 0) (
            "QSDK-R23D10 stage-two blob read failed: $Path"
        )
        $digest = [Security.Cryptography.SHA256]::HashData($memory.ToArray())
        return [Convert]::ToHexString($digest).ToLowerInvariant()
    }
    finally {
        $memory.Dispose()
        $process.Dispose()
    }
}

Assert-R23D10StageTwoClosure (
    (git -C $repoRoot rev-parse --show-toplevel).Trim() -ceq
        $repoRoot.Replace("\", "/") -and
    (git -C $repoRoot remote get-url origin).Trim() -ceq
        "https://github.com/Slagathore/sporespore.git"
) "QSDK-R23D10 stage-two closure repository identity changed"

$resolvedCommit = (git -C $repoRoot rev-parse "$stageTwoCommit^{commit}").Trim()
$resolvedParent = (git -C $repoRoot rev-parse "$stageTwoCommit^").Trim()
Assert-R23D10StageTwoClosure (
    $resolvedCommit -ceq $stageTwoCommit -and
    $resolvedParent -ceq $stageTwoParent
) "QSDK-R23D10 stage-two commit boundary changed"

$actualChangedPaths = @(
    git -C $repoRoot diff --name-only $stageTwoParent $stageTwoCommit
)
Assert-R23D10StageTwoClosure (
    (@($actualChangedPaths | Sort-Object) -join "`n") -ceq
        (@($expectedChangedPaths | Sort-Object) -join "`n")
) "QSDK-R23D10 stage-two changed-path set moved"

$treePaths = @(git -C $repoRoot ls-tree -r --name-only $stageTwoCommit)
foreach ($futurePath in $futurePaths) {
    Assert-R23D10StageTwoClosure ($treePaths -cnotcontains $futurePath) (
        "QSDK-R23D10 stage-two tree already contained future route: $futurePath"
    )
}
foreach ($entry in $fixedBlobs.GetEnumerator()) {
    Assert-R23D10StageTwoClosure (
        (Get-R23D10StageTwoBlobHash $stageTwoCommit $entry.Key) -ceq
            [string]$entry.Value
    ) "QSDK-R23D10 stage-two fixed blob changed: $($entry.Key)"
}

$contractSpec = (
    $stageTwoCommit +
    ":sdk/turning/r23d10_stage_two_evidence_contract_v1.json"
)
$contract = (git -C $repoRoot show $contractSpec | Out-String) |
    ConvertFrom-Json -AsHashtable -Depth 100
$bindings = [Collections.Generic.List[object]]::new()
$bindings.Add([pscustomobject]@{
    path = [string]$contract.stage_one_boundary.historical_closure_audit_path
    hash = ([string]$contract.stage_one_boundary.historical_closure_audit_raw_sha256).
        Substring(7)
})
foreach ($sectionName in @(
    "production_trace_contract",
    "production_evaluator_contract"
)) {
    $section = $contract[$sectionName]
    foreach ($pair in @(
        @("implementation_path", "implementation_raw_sha256"),
        @("test_path", "test_raw_sha256")
    )) {
        $bindings.Add([pscustomobject]@{
            path = [string]$section[$pair[0]]
            hash = ([string]$section[$pair[1]]).Substring(7)
        })
    }
}
foreach ($pair in @(
    @("publisher_path", "publisher_raw_sha256"),
    @("store_path", "store_raw_sha256")
)) {
    $bindings.Add([pscustomobject]@{
        path = [string]$contract.content_addressed_retention[$pair[0]]
        hash = ([string]$contract.content_addressed_retention[$pair[1]]).
            Substring(7)
    })
}

Assert-R23D10StageTwoClosure (
    [string]$contract.schema_version -ceq
        "sporespore_qsdk_r23d10_stage_two_evidence_contract_v1" -and
    [string]$contract.status -ceq
        "stage_two_zero_world_trace_retention_and_production_evaluator_complete_no_physical_workers_or_authorization" -and
    [string]$contract.stage_one_boundary.commit -ceq $stageTwoParent -and
    [int]$contract.production_trace_contract.complete_trace_rows_per_cell -eq
        3892 -and
    [int]$contract.production_trace_contract.declared_trace_identity_count -eq
        11 -and
    [bool]$contract.content_addressed_retention.attempt_trace_staging_uses_exclusive_creation -and
    [bool]$contract.content_addressed_retention.digest_derived_cas_path_shape_revalidated -and
    [bool]$contract.production_evaluator_contract.exact_expected_source_commit_required_by_both_evaluator_commands -and
    [bool]$contract.production_evaluator_contract.all_report_source_commits_must_match_expected_source_commit -and
    [int]$contract.next_implementation_boundary.production_physical_worker_count -eq
        0 -and
    -not [bool]$contract.next_implementation_boundary.serialized_supervisor_implemented -and
    -not [bool]$contract.next_implementation_boundary.physical_execution_authorized -and
    -not [bool]$contract.claim_boundary.command_conditioned_turning -and
    -not [bool]$contract.claim_boundary.cross_engine_equivalence -and
    -not [bool]$contract.claim_boundary.physical_acceptance_authority -and
    $bindings.Count -eq 7
) "QSDK-R23D10 stage-two claim boundary changed"

foreach ($binding in $bindings) {
    Assert-R23D10StageTwoClosure (
        (Get-R23D10StageTwoBlobHash $stageTwoCommit $binding.path) -ceq
            $binding.hash
    ) "QSDK-R23D10 stage-two source binding changed: $($binding.path)"
}

Write-Host (
    "QSDK_R23D10_STAGE_TWO_CLOSURE_PASS commit=$stageTwoCommit " +
    "changed_paths=$($expectedChangedPaths.Count) fixed_blobs=$($fixedBlobs.Count) " +
    "source_bindings=$($bindings.Count) future_routes=0 workers=0 models=0 " +
    "worlds=0 physical_authority=False"
)
