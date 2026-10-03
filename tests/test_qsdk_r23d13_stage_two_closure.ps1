#requires -Version 7.0

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$stageTwoCommit = "18525137a0364219f431ef49636ce5e01381c419"
$stageTwoParent = "8d2998c4d8d7a4b4e78232bfd34799945bec656a"
$fixedBlobs = [ordered]@{
    "docs/ENGINE_NEUTRAL_LOCOMOTION_SDK_BOOTSTRAP.md" =
        "e802afc7737e4dd8caa2798cb5953a5ce8b56964844ed118c0b124563488ad9a"
    "docs/README.md" =
        "a36b51f892e73f8cc82e37005dae6a68bf3f27bdd44e19fa58dfc02a8822970d"
    "docs/SDK_PORTABLE_BALANCED_WAVE_SUCCESSOR_BOOTSTRAP.md" =
        "218e4cb507b96bcf56ba9d84761c3b22386d82f7b333355cf152ad888316c5ab"
    "docs/SDK_PRODUCT_AND_ADAPTATION_ROADMAP.md" =
        "325f9132df70d45d3fc7df339905f107ea08e04465fea05162f9fa42187b4113"
    "sdk/closure_evidence_mode_inventory.json" =
        "03266fea7f1121eada4dd3ead00f3a0a314e1c2d42029eeb4a6483ef42984c1e"
    "sdk/closure_evidence_provenance_contract.json" =
        "9434896f0e2fde8a33ad31894697d1a91fce6ee2506009640778b089368c1b1c"
    "sdk/publish_qsdk_r23d13_trace.ps1" =
        "f2806cb172b669d7bfd7368971706a2700fcba0dce42a2a800b2fb0013be7542"
    "sdk/release/quadruped_release_contract.json" =
        "7b2befda24f5eeb1624586095e89fde81316b93052fda710176c756d7d6992aa"
    "sdk/release/quadruped_support_matrix.json" =
        "d8e437e659ecee7bd85adefbfa0b1fa9380ba69e5e4061a5e646e1b201c1bb78"
    "sdk/run_conformance.ps1" =
        "58ee78e5572faeadca0c451d4997fba0f512673ddf16d968732d7e65b0317d10"
    "sdk/run_qsdk_r23d13_stage_two_gate.ps1" =
        "f022f91cd509d4063cd5ea7529e4507a4cf9593da1ce6ad3979533be39b74e2d"
    "sdk/turning/README.md" =
        "e630e32c8f849b6310f16dbe654df9ba01d9fe658dbd7468b771f54d4d9ac8fa"
    "sdk/turning/r23d13_physical_evaluator.py" =
        "a22dc0f5b0f819374f8b321cdb1cc2aad8bf82364a70cb15b7b4e4e46c00f9cd"
    "sdk/turning/r23d13_physical_trace.py" =
        "87b52387f8a70fc99b2d1fb579ec1845f59749e7c1d58fc0fd8963ed6d1ea072"
    "sdk/turning/r23d13_stage_two_evidence_contract_v1.json" =
        "a57652e8f2d900994cf88293894d77aada5e29b2b7877b211f87b9a99f182347"
    "sdk/turning/test_r23d13_physical_evaluator.py" =
        "2224130d98294d4d919ed4c99b7a98fb9b4fb3d52beda542cb191b208f99a605"
    "sdk/turning/test_r23d13_physical_trace.py" =
        "94702e3e5fd44d062e1943e8f0c57779947fd078dd5f3a04712f950ec7f892aa"
    "sdk/workbench/experiment_catalog.json" =
        "ef3eafa030e76a22346df1166778ca05e2c32e1e148698b6725ee2cfa92be717"
    "tests/test_closure_evidence_provenance_contract.ps1" =
        "21cc4cbce7452c5ac36e674df5e5a1a34606d3d915da28ef81559e762a73f7d6"
    "tests/test_locomotion_experiment_workbench.ps1" =
        "5f981a3cfb8c6225cfbeb498f187251d4a936e09bc62ab3343b28a1c066f20bb"
    "tests/test_qsdk_r23d13_stage_one_closure.ps1" =
        "37ff1a83948cf22110f9a7e49164efa9de5ecf940d49d7293c93ac49d8dde2a5"
    "tests/test_qsdk_r23d13_stage_two_evidence.ps1" =
        "26da17d7ce5b4b0f23a4b42c191c00ff8648aa1b2f2ae040eaaec7813428dfc0"
}
$expectedChangedPaths = @(
    "docs/ENGINE_NEUTRAL_LOCOMOTION_SDK_BOOTSTRAP.md",
    "docs/README.md",
    "docs/SDK_PORTABLE_BALANCED_WAVE_SUCCESSOR_BOOTSTRAP.md",
    "docs/SDK_PRODUCT_AND_ADAPTATION_ROADMAP.md",
    "sdk/closure_evidence_mode_inventory.json",
    "sdk/closure_evidence_provenance_contract.json",
    "sdk/publish_qsdk_r23d13_trace.ps1",
    "sdk/release/quadruped_release_contract.json",
    "sdk/release/quadruped_support_matrix.json",
    "sdk/run_conformance.ps1",
    "sdk/run_qsdk_r23d13_stage_two_gate.ps1",
    "sdk/turning/README.md",
    "sdk/turning/r23d13_physical_evaluator.py",
    "sdk/turning/r23d13_physical_trace.py",
    "sdk/turning/r23d13_stage_two_evidence_contract_v1.json",
    "sdk/turning/test_r23d13_physical_evaluator.py",
    "sdk/turning/test_r23d13_physical_trace.py",
    "sdk/workbench/experiment_catalog.json",
    "tests/test_closure_evidence_provenance_contract.ps1",
    "tests/test_locomotion_experiment_workbench.ps1",
    "tests/test_qsdk_r23d13_stage_one_closure.ps1",
    "tests/test_qsdk_r23d13_stage_two_evidence.ps1"
)
$futurePaths = @(
    "sdk/adapters/mujoco/sporespore_mujoco_adapter/qsdk_r23d13_residual_pose_authority_physical.py",
    "sdk/adapters/mujoco/test_qsdk_r23d13_residual_pose_authority_physical.py",
    "sdk/adapters/rapier/src/qsdk_r23d3_phase_balanced/r23d13_physical.rs",
    "tests/test_sdk_qsdk_r23d13_residual_pose_authority_godot_jolt_physical_worker.gd",
    "sdk/turning/r23d13_physical_implementation_contract_v1.json",
    "sdk/turning/r23d13_dependency_closure.ps1",
    "sdk/turning/r23d13_terminal_marker_classifier.ps1",
    "sdk/run_qsdk_r23d13_mujoco_worker_preflight.ps1",
    "sdk/run_qsdk_r23d13_rapier_worker_preflight.ps1",
    "sdk/run_qsdk_r23d13_godot_jolt_worker_preflight.ps1",
    "sdk/run_qsdk_r23d13_authorization_canaries.ps1",
    "sdk/run_qsdk_r23d13_supervisor.ps1",
    "sdk/run_qsdk_r23d13_zero_world_gate.ps1",
    "tests/test_qsdk_r23d13_dependency_and_marker_contract.ps1",
    "tests/test_qsdk_r23d13_implementation.ps1"
)

function Assert-R23D13StageTwoClosure(
    [bool]$Condition,
    [string]$Message
) {
    if (-not $Condition) { throw $Message }
}

function Get-R23D13StageTwoBlobHash([string]$Commit, [string]$Path) {
    $blobOid = (git -C $repoRoot rev-parse ("$Commit`:$Path")).Trim()
    Assert-R23D13StageTwoClosure ($LASTEXITCODE -eq 0) (
        "QSDK-R23D13 stage-two blob unavailable: $Path"
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
        Assert-R23D13StageTwoClosure ($process.ExitCode -eq 0) (
            "QSDK-R23D13 stage-two blob read failed: $Path"
        )
        $digest = [Security.Cryptography.SHA256]::HashData($memory.ToArray())
        return [Convert]::ToHexString($digest).ToLowerInvariant()
    }
    finally {
        $memory.Dispose()
        $process.Dispose()
    }
}

Assert-R23D13StageTwoClosure (
    (git -C $repoRoot rev-parse --show-toplevel).Trim() -ceq
        $repoRoot.Replace("\", "/") -and
    (git -C $repoRoot remote get-url origin).Trim() -ceq
        "https://github.com/Slagathore/sporespore.git"
) "QSDK-R23D13 stage-two closure repository identity changed"

$resolvedCommit = (git -C $repoRoot rev-parse "$stageTwoCommit^{commit}").Trim()
$resolvedParent = (git -C $repoRoot rev-parse "$stageTwoCommit^").Trim()
Assert-R23D13StageTwoClosure (
    $resolvedCommit -ceq $stageTwoCommit -and
    $resolvedParent -ceq $stageTwoParent
) "QSDK-R23D13 stage-two commit boundary changed"

$actualChangedPaths = @(
    git -C $repoRoot diff --name-only $stageTwoParent $stageTwoCommit
)
Assert-R23D13StageTwoClosure (
    (@($actualChangedPaths | Sort-Object) -join "`n") -ceq
        (@($expectedChangedPaths | Sort-Object) -join "`n")
) "QSDK-R23D13 stage-two changed-path set moved"

$treePaths = @(git -C $repoRoot ls-tree -r --name-only $stageTwoCommit)
foreach ($futurePath in $futurePaths) {
    Assert-R23D13StageTwoClosure ($treePaths -cnotcontains $futurePath) (
        "QSDK-R23D13 stage-two tree already contained future route: $futurePath"
    )
}
foreach ($entry in $fixedBlobs.GetEnumerator()) {
    Assert-R23D13StageTwoClosure (
        (Get-R23D13StageTwoBlobHash $stageTwoCommit $entry.Key) -ceq
            [string]$entry.Value
    ) "QSDK-R23D13 stage-two fixed blob changed: $($entry.Key)"
}

$contractSpec = (
    $stageTwoCommit +
    ":sdk/turning/r23d13_stage_two_evidence_contract_v1.json"
)
$contract = (git -C $repoRoot show $contractSpec | Out-String) |
    ConvertFrom-Json -AsHashtable -Depth 100
$bindings = [Collections.Generic.List[object]]::new()
$bindings.Add([pscustomobject]@{
    path = [string]$contract.stage_one_boundary.historical_closure_audit_path
    hash = ([string]$contract.stage_one_boundary.historical_closure_audit_raw_sha256).
        Substring(7)
})
foreach ($pair in @(
    @("preregistration_path", "preregistration_raw_sha256"),
    @("oracle_path", "oracle_raw_sha256")
)) {
    $bindings.Add([pscustomobject]@{
        path = [string]$contract.residual_pose_authority_trace_contract[$pair[0]]
        hash = ([string]$contract.residual_pose_authority_trace_contract[$pair[1]]).
            Substring(7)
    })
}
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
$bindings.Add([pscustomobject]@{
    path = [string]$contract.diagnostic_trace_contract.semantics_path
    hash = ([string]$contract.diagnostic_trace_contract.semantics_raw_sha256).
        Substring(7)
})

Assert-R23D13StageTwoClosure (
    [string]$contract.schema_version -ceq
        "sporespore_qsdk_r23d13_stage_two_evidence_contract_v1" -and
    [string]$contract.status -ceq
        "stage_two_zero_world_command_time_residual_pose_authority_trace_retention_and_production_evaluator_complete_no_physical_workers_or_authorization" -and
    [string]$contract.stage_one_boundary.commit -ceq
        $stageTwoParent -and
    [string]$contract.stage_one_boundary.parent_commit -ceq
        "7ba47f7df2fe0965235f2ecc0e4a522278bd6b92" -and
    [string]$contract.stage_one_boundary.tree -ceq
        "02ad589f03aece450ca6fec371752944ad453ef0" -and
    [int]$contract.stage_one_boundary.historical_native_semantics_route_count -eq
        3 -and
    [int]$contract.stage_one_boundary.historical_valid_canary_count -eq 30 -and
    [int]$contract.stage_one_boundary.historical_mutation_refusal_count -eq 60 -and
    [int]$contract.stage_one_boundary.historical_critical_invariant_count -eq 3 -and
    [int]$contract.stage_one_boundary.historical_positive_no_regression_count -eq 3 -and
    [int]$contract.stage_one_boundary.historical_passive_zero_count -eq 3 -and
    [int]$contract.stage_one_boundary.historical_physical_refusal_count -eq 3 -and
    [string]$contract.production_trace_contract.trace_schema -ceq
        "sporespore_qsdk_r23d13_physical_trace_v1" -and
    [string]$contract.production_trace_contract.row_schema -ceq
        "sporespore_qsdk_r23d13_physical_trace_row_v1" -and
    [int]$contract.production_trace_contract.trace_row_field_count -eq 51 -and
    [int]$contract.production_trace_contract.complete_trace_rows_per_cell -eq
        3892 -and
    [int]$contract.production_trace_contract.declared_trace_identity_count -eq
        11 -and
    [int]$contract.production_trace_contract.trace_test_count -eq 11 -and
    [bool]$contract.residual_pose_authority_trace_contract.command_time_feedback_must_equal_previous_trace_row_post_step_observation -and
    [bool]$contract.residual_pose_authority_trace_contract.future_post_step_observation_may_not_drive_current_command -and
    [int]$contract.residual_pose_authority_trace_contract.direct_authority_and_time_order_mutation_refusal_count -eq 10 -and
    [int]$contract.diagnostic_trace_contract.field_count -eq 7 -and
    [bool]$contract.diagnostic_trace_contract.planner_availability_controls_only_stability_fallback -and
    [bool]$contract.diagnostic_trace_contract.support_margin_availability_controls_only_margin_nullability -and
    [bool]$contract.diagnostic_trace_contract.planner_and_support_margin_availability_are_independent -and
    [bool]$contract.diagnostic_trace_contract.all_six_active_cross_product_states_valid -and
    [bool]$contract.diagnostic_trace_contract.both_passive_margin_states_valid -and
    [bool]$contract.diagnostic_trace_contract.r23d11_observation_unavailable_with_measured_finite_margin_shape_valid -and
    [int]$contract.diagnostic_trace_contract.direct_diagnostic_mutation_refusal_count -eq
        11 -and
    [int]$contract.diagnostic_trace_contract.cas_retention_new_field_rewrite_refusal_count -eq
        1 -and
    [int]$contract.diagnostic_trace_contract.new_decision_threshold_count -eq 0 -and
    -not [bool]$contract.diagnostic_trace_contract.fields_grant_outcome_or_acceptance_authority -and
    [bool]$contract.content_addressed_retention.attempt_trace_staging_uses_exclusive_creation -and
    [bool]$contract.content_addressed_retention.digest_derived_cas_path_shape_revalidated -and
    [bool]$contract.production_evaluator_contract.exact_expected_source_commit_required_by_both_evaluator_commands -and
    [bool]$contract.production_evaluator_contract.all_report_source_commits_must_match_expected_source_commit -and
    [int]$contract.production_evaluator_contract.evaluator_test_count -eq 12 -and
    [int]$contract.next_implementation_boundary.production_physical_worker_count -eq
        0 -and
    -not [bool]$contract.next_implementation_boundary.serialized_supervisor_implemented -and
    -not [bool]$contract.next_implementation_boundary.physical_execution_authorized -and
    -not [bool]$contract.claim_boundary.command_conditioned_turning -and
    -not [bool]$contract.claim_boundary.cross_engine_equivalence -and
    -not [bool]$contract.claim_boundary.physical_acceptance_authority -and
    $bindings.Count -eq 10
) "QSDK-R23D13 stage-two claim boundary changed"

foreach ($binding in $bindings) {
    Assert-R23D13StageTwoClosure (
        (Get-R23D13StageTwoBlobHash $stageTwoCommit $binding.path) -ceq
            $binding.hash
    ) "QSDK-R23D13 stage-two source binding changed: $($binding.path)"
}

Write-Host (
    "QSDK_R23D13_STAGE_TWO_CLOSURE_PASS commit=$stageTwoCommit " +
    "changed_paths=$($expectedChangedPaths.Count) fixed_blobs=$($fixedBlobs.Count) " +
    "source_bindings=$($bindings.Count) future_routes=0 workers=0 models=0 " +
    "worlds=0 physical_authority=False"
)
