$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = [System.IO.Path]::GetFullPath(
    (Join-Path $PSScriptRoot "..")
)
$closurePath = Join-Path $repoRoot (
    "sdk\turning\r23d61_selected_actuator_profile_publication_closure_v1.json"
)
$publicationContractPath = Join-Path $repoRoot (
    "sdk\turning\r23d61_selected_actuator_profile_publication_v1.json"
)
$publicationAuditPath = Join-Path $repoRoot (
    "sdk\turning\r23d61_selected_actuator_profile_publication_audit.py"
)
$releasePath = Join-Path $repoRoot "sdk\release\quadruped_release_contract.json"
$supportPath = Join-Path $repoRoot "sdk\release\quadruped_support_matrix.json"
$sourceCommit = "c61e56907d255e920297f088b93fc3e09ba12aef"
$sourceTree = "fb55ede695e7dda1784946382e556e7730dff8a6"
$profileId = "sporespore_qsdk_r23d60_selected_s169_actuator_cap_profile_v1"
$profileSha256 = (
    "sha256:b65d41e3f30c42e0a8207f1385fe00daa8f03975f4e266a0bd0867970f674964"
)
$cleanRunId = "20260816T040404Z-c61e5690-2c5cb8a699f445538ca746eca6d59329"
$cleanRunRoot = [System.IO.Path]::GetFullPath(
    "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence\conformance-runs\$cleanRunId"
)

function Assert-R23D61Closure {
    param(
        [Parameter(Mandatory = $true)]
        [bool]$Condition,
        [Parameter(Mandatory = $true)]
        [string]$Message
    )
    if (-not $Condition) {
        throw "QSDK-R23D61 closure: $Message"
    }
}

function Get-R23D61RawSha256 {
    param([Parameter(Mandatory = $true)][string]$Path)
    return "sha256:" + (
        Get-FileHash -Algorithm SHA256 -LiteralPath $Path
    ).Hash.ToLowerInvariant()
}

function Copy-R23D61JsonValue {
    param([Parameter(Mandatory = $true)]$Value)
    return $Value | ConvertTo-Json -Depth 100 -Compress |
        ConvertFrom-Json -AsHashtable -Depth 100
}

function Test-R23D61ClosureContract {
    param([Parameter(Mandatory = $true)][hashtable]$Candidate)

    Assert-R23D61Closure (
        [string]$Candidate.schema_version -ceq
            "sporespore_qsdk_r23d61_selected_actuator_profile_publication_closure_v1" -and
        [string]$Candidate.status -ceq
            "closed_complete_valid_positive_non_physical_source_conformance" -and
        [string]$Candidate.gate_id -ceq "QSDK-R23D61" -and
        [string]$Candidate.work_id -ceq
            "QSDK-R23D61-SELECTED-ACTUATOR-PROFILE-PUBLICATION"
    ) "identity changed"
    Assert-R23D61Closure (
        [string]$Candidate.question_class -ceq "non_physical_source_conformance" -and
        [string]$Candidate.result_class -ceq
            "complete_valid_positive_source_conformance" -and
        -not [bool]$Candidate.physical_question_declared -and
        -not [bool]$Candidate.physical_campaign_opened
    ) "question or result classification changed"

    $freeze = $Candidate.publication_source_freeze
    Assert-R23D61Closure (
        [string]$freeze.commit -ceq $sourceCommit -and
        [string]$freeze.tree_git_oid -ceq $sourceTree -and
        [string]$freeze.branch -ceq "main" -and
        [string]$freeze.remote -ceq
            "https://github.com/Slagathore/sporespore.git" -and
        [bool]$freeze.source_worktree_clean -and
        [bool]$freeze.source_matched_upstream -and
        [bool]$freeze.source_matched_live_github_main -and
        [int]$freeze.frozen_source_binding_count -eq 22 -and
        [bool]$freeze.frozen_source_bindings_resolved_from_commit -and
        -not [bool]$freeze.historical_contract_or_binding_rewritten
    ) "publication source freeze changed"

    $profile = $Candidate.profile
    Assert-R23D61Closure (
        [string]$profile.profile_id -ceq $profileId -and
        [string]$profile.profile_sha256 -ceq $profileSha256 -and
        [string]$profile.morphology_id -ceq "qsdk_r05_generated_s169" -and
        [string]$profile.semantics_id -ceq
            "sporespore_outer_control_step_angular_impulse_budget_120hz_v1" -and
        [int]$profile.ordered_actuator_count -eq 8 -and
        @($profile.ordered_maximum_outer_step_impulse_nms).Count -eq 8 -and
        [string]$profile.support_status -ceq "supported_exact" -and
        [string]$profile.other_valid_descriptor_status -ceq
            "out_of_domain_morphology" -and
        [string]$profile.unknown_profile_status -ceq "unsupported_profile" -and
        -not [bool]$profile.implicit_fallback_permitted
    ) "profile identity, support, or refusal boundary changed"

    $history = @($Candidate.qualification_history)
    Assert-R23D61Closure (
        $history.Count -eq 3 -and
        [string]$history[0].status -ceq "failed" -and
        [string]$history[0].classification -ceq
            "retained_incomplete_dirty_source_conformance" -and
        [string]$history[1].status -ceq "failed" -and
        [string]$history[1].classification -ceq
            "retained_incomplete_dirty_source_conformance" -and
        [string]$history[2].status -ceq "passed" -and
        [string]$history[2].classification -ceq
            "retained_complete_dirty_source_conformance_observation" -and
        -not [bool]$history[2].clean_pushed_qualification
    ) "qualification history changed"

    $qualification = $Candidate.clean_pushed_qualification
    Assert-R23D61Closure (
        [string]$qualification.status -ceq "passed" -and
        [string]$qualification.tier -ceq "full_cold" -and
        [string]$qualification.run_id -ceq $cleanRunId -and
        [string]$qualification.source_commit -ceq $sourceCommit -and
        [string]$qualification.source_tree_git_oid -ceq $sourceTree -and
        [string]$qualification.origin_main_commit -ceq $sourceCommit -and
        [bool]$qualification.source_worktree_clean -and
        [bool]$qualification.source_matches_origin_main -and
        [int]$qualification.stage_count -eq 8 -and
        @($qualification.stages).Count -eq 8 -and
        [string]$qualification.cache_status -ceq "disabled_uncommissioned" -and
        -not [bool]$qualification.result_reused -and
        -not [bool]$qualification.transitive_dependency_key_complete -and
        [bool]$qualification.full_exact_conformance_executed -and
        [int]$qualification.true_claim_count -eq 0
    ) "clean-pushed qualification changed"

    $zeroWorld = $Candidate.retained_zero_world_result
    Assert-R23D61Closure (
        [bool]$zeroWorld.complete_zero_world_gate_passed -and
        [int]$zeroWorld.core_test_count -eq 6 -and
        [int]$zeroWorld.python_ffi_test_count -eq 1 -and
        [int]$zeroWorld.rapier_test_count -eq 2 -and
        [int]$zeroWorld.mujoco_test_count -eq 2 -and
        [string]$zeroWorld.godot_runtime_status -ceq "passed" -and
        [int]$zeroWorld.godot_mutation_rejection_count -eq 17 -and
        [int]$zeroWorld.rapier_mutation_rejection_count -eq 9 -and
        [int]$zeroWorld.mujoco_mutation_rejection_count -eq 9 -and
        [int]$zeroWorld.publication_audit_mutation_rejection_count -eq 18 -and
        [int]$zeroWorld.model_construction_count -eq 0 -and
        [int]$zeroWorld.world_attempt_count -eq 0 -and
        [int]$zeroWorld.world_build_count -eq 0 -and
        [int]$zeroWorld.solver_step_count -eq 0 -and
        -not [bool]$zeroWorld.physics_state_modified
    ) "retained zero-world result changed"

    $claims = $Candidate.adequacy_and_claim_boundary
    Assert-R23D61Closure (
        [bool]$claims.adequate_for_exact_profile_publication -and
        [int]$claims.physical_outcome_threshold_count -eq 0 -and
        -not [bool]$claims.superiority_margin_declared -and
        -not [bool]$claims.equivalence_or_non_inferiority_margin_declared -and
        -not [bool]$claims.physical_cohort_declared -and
        -not [bool]$claims.population_claim -and
        [bool]$claims.exact_scope_profile_published -and
        [bool]$claims.godot_configuration_mapping_conformed -and
        [bool]$claims.rapier_configuration_mapping_conformed -and
        [bool]$claims.mujoco_configuration_mapping_conformed -and
        -not [bool]$claims.measured_actuator_response -and
        -not [bool]$claims.new_physical_result -and
        -not [bool]$claims.godot_jolt_turning_result_changed -and
        -not [bool]$claims.rapier_turning -and
        -not [bool]$claims.mujoco_turning -and
        -not [bool]$claims.finite_three_engine_turning -and
        -not [bool]$claims.portable_basic_turning -and
        -not [bool]$claims.cross_engine_equivalence -and
        -not [bool]$claims.stochastic_repeatability -and
        -not [bool]$claims.arbitrary_morphology_support -and
        -not [bool]$claims.prone_to_standing -and
        -not [bool]$claims.q_sdk_r23_satisfied -and
        -not [bool]$claims.physical_acceptance_authority -and
        -not [bool]$claims.release_authority
    ) "adequacy or claim boundary changed"

    Assert-R23D61Closure (
        [int]$Candidate.release_boundary.passed_gate_count -eq 10 -and
        [int]$Candidate.release_boundary.total_gate_count -eq 25 -and
        -not [bool]$Candidate.release_boundary.release_ready -and
        [bool]$Candidate.immutability.publication_contract_and_frozen_source_bindings_may_not_be_rewritten -and
        [bool]$Candidate.immutability.qualification_receipts_logs_stage_receipts_and_interpretations_may_not_be_rewritten -and
        [bool]$Candidate.immutability.failed_incomplete_and_dirty_passing_observations_remain_distinct -and
        [bool]$Candidate.immutability.conformance_reexecution_permitted -and
        [bool]$Candidate.immutability.conformance_reexecution_may_not_replace_this_closure -and
        -not [bool]$Candidate.immutability.historical_physical_results_reinterpreted
    ) "release or immutability boundary changed"

    Assert-R23D61Closure (
        [bool]$Candidate.next_allowed_work.r23d61_publication_closed -and
        [string]$Candidate.next_allowed_work.movement_priority -ceq
            "canonical_prone_to_standing" -and
        -not [bool]$Candidate.next_allowed_work.additional_turning_campaign_required_first -and
        -not [bool]$Candidate.next_allowed_work.physical_question_declared -and
        -not [bool]$Candidate.next_allowed_work.physical_campaign_opened
    ) "next-work boundary changed"
}

Assert-R23D61Closure (
    (Test-Path -LiteralPath $closurePath -PathType Leaf)
) "closure file is missing"
$closure = Get-Content -Raw -LiteralPath $closurePath |
    ConvertFrom-Json -AsHashtable -Depth 100
Test-R23D61ClosureContract -Candidate $closure

# Resolve the publication against the exact clean-pushed Git tree. Raw checkout
# hashes are retained in the frozen contract; Git blob IDs carry the durable
# content identity across line-ending policies.
& git -C $repoRoot cat-file -e "$sourceCommit`^{commit}"
Assert-R23D61Closure ($LASTEXITCODE -eq 0) "source commit is unavailable"
$observedTree = (& git -C $repoRoot rev-parse "$sourceCommit`^{tree}").Trim()
Assert-R23D61Closure (
    $LASTEXITCODE -eq 0 -and $observedTree -ceq $sourceTree
) "source tree changed"
$contractBinding = $closure.publication_source_freeze.publication_contract
$observedContractBlob = (& git -C $repoRoot rev-parse (
    "$sourceCommit`:$($contractBinding.path)"
)).Trim()
Assert-R23D61Closure (
    $LASTEXITCODE -eq 0 -and
    $observedContractBlob -ceq [string]$contractBinding.git_blob_oid -and
    (Get-R23D61RawSha256 -Path $publicationContractPath) -ceq
        [string]$contractBinding.raw_sha256
) "frozen publication contract changed"

$auditOutput = @(& python $publicationAuditPath 2>&1)
$auditExitCode = $LASTEXITCODE
$auditMarkers = @($auditOutput | Where-Object {
    ([string]$_).StartsWith("QSDK_R23D61_PUBLICATION_AUDIT ")
})
Assert-R23D61Closure (
    $auditExitCode -eq 0 -and $auditMarkers.Count -eq 1
) "publication audit failed"
$auditReceipt = ([string]$auditMarkers[0]).Substring(
    "QSDK_R23D61_PUBLICATION_AUDIT ".Length
) | ConvertFrom-Json -AsHashtable -Depth 100
Assert-R23D61Closure (
    [bool]$auditReceipt.ok -and
    [string]$auditReceipt.source_binding_mode -ceq "frozen_git_commit" -and
    [string]$auditReceipt.source_commit -ceq $sourceCommit -and
    [string]$auditReceipt.source_tree -ceq $sourceTree -and
    [int]$auditReceipt.source_binding_count -eq 22 -and
    [int]$auditReceipt.mutation_rejection_count -eq 18 -and
    [int]$auditReceipt.world_build_count -eq 0 -and
    -not [bool]$auditReceipt.physical_acceptance_authority -and
    -not [bool]$auditReceipt.release_authority
) "publication audit receipt changed"

# Preserve the two incomplete attempts, the complete dirty observation, and the
# authoritative clean-pushed qualification as four different process records.
foreach ($observation in @($closure.qualification_history)) {
    $runRoot = [System.IO.Path]::GetFullPath([string]$observation.run_root)
    $receiptPath = Join-Path $runRoot "receipt.json"
    $logPath = Join-Path $runRoot "conformance.log"
    Assert-R23D61Closure (
        (Test-Path -LiteralPath $receiptPath -PathType Leaf) -and
        (Test-Path -LiteralPath $logPath -PathType Leaf) -and
        (Get-R23D61RawSha256 -Path $receiptPath) -ceq
            [string]$observation.receipt_raw_sha256 -and
        (Get-Item -LiteralPath $receiptPath).Length -eq
            [long]$observation.receipt_byte_length -and
        (Get-R23D61RawSha256 -Path $logPath) -ceq
            [string]$observation.log_raw_sha256 -and
        (Get-Item -LiteralPath $logPath).Length -eq
            [long]$observation.log_byte_length
    ) "retained qualification observation changed: $($observation.run_id)"
    $receipt = Get-Content -Raw -LiteralPath $receiptPath |
        ConvertFrom-Json -AsHashtable -Depth 100
    $trueClaims = @($receipt.claims.GetEnumerator() | Where-Object {
        [bool]$_.Value
    })
    Assert-R23D61Closure (
        [string]$receipt.run_id -ceq [string]$observation.run_id -and
        [string]$receipt.status -ceq [string]$observation.status -and
        [string]$receipt.source.head -ceq [string]$observation.source_head -and
        [bool]$receipt.source.worktree_clean -eq
            [bool]$observation.source_worktree_clean -and
        @($receipt.stage_receipts).Count -eq
            [int]$observation.completed_stage_count -and
        $trueClaims.Count -eq 0
    ) "retained qualification receipt semantics changed: $($observation.run_id)"
}

$qualification = $closure.clean_pushed_qualification
$cleanReceiptPath = [System.IO.Path]::GetFullPath(
    [string]$qualification.receipt_path
)
$cleanLogPath = [System.IO.Path]::GetFullPath([string]$qualification.log_path)
Assert-R23D61Closure (
    [System.IO.Path]::GetFullPath([string]$qualification.run_root) -ceq
        $cleanRunRoot -and
    (Test-Path -LiteralPath $cleanReceiptPath -PathType Leaf) -and
    (Test-Path -LiteralPath $cleanLogPath -PathType Leaf) -and
    (Get-R23D61RawSha256 -Path $cleanReceiptPath) -ceq
        [string]$qualification.receipt_raw_sha256 -and
    (Get-Item -LiteralPath $cleanReceiptPath).Length -eq
        [long]$qualification.receipt_byte_length -and
    (Get-R23D61RawSha256 -Path $cleanLogPath) -ceq
        [string]$qualification.log_raw_sha256 -and
    (Get-Item -LiteralPath $cleanLogPath).Length -eq
        [long]$qualification.log_byte_length
) "clean-pushed evidence changed"
$cleanReceipt = Get-Content -Raw -LiteralPath $cleanReceiptPath |
    ConvertFrom-Json -AsHashtable -Depth 100
$cleanTrueClaims = @($cleanReceipt.claims.GetEnumerator() | Where-Object {
    [bool]$_.Value
})
Assert-R23D61Closure (
    [string]$cleanReceipt.schema_version -ceq
        "sporespore_conformance_run_observation_v1" -and
    [string]$cleanReceipt.status -ceq "passed" -and
    [string]$cleanReceipt.tier -ceq "full_cold" -and
    -not [bool]$cleanReceipt.test_only -and
    [string]$cleanReceipt.source.head -ceq $sourceCommit -and
    [string]$cleanReceipt.source.head_tree -ceq $sourceTree -and
    [string]$cleanReceipt.source.origin_main -ceq $sourceCommit -and
    [string]$cleanReceipt.source.remote_url -ceq
        "https://github.com/Slagathore/sporespore.git" -and
    [bool]$cleanReceipt.source.worktree_clean -and
    -not [bool]$cleanReceipt.cache.lookup_performed -and
    -not [bool]$cleanReceipt.cache.result_reused -and
    -not [bool]$cleanReceipt.cache.reuse_authority -and
    @($cleanReceipt.stage_receipts).Count -eq 8 -and
    $cleanTrueClaims.Count -eq 0
) "clean-pushed receipt source or claim boundary changed"

$declaredStages = @($qualification.stages)
$observedStages = @($cleanReceipt.stage_receipts)
for ($index = 0; $index -lt $declaredStages.Count; $index++) {
    Assert-R23D61Closure (
        [int]$observedStages[$index].ordinal -eq [int]$declaredStages[$index].ordinal -and
        [string]$observedStages[$index].stage_id -ceq
            [string]$declaredStages[$index].stage_id -and
        [string]$observedStages[$index].status -ceq "passed" -and
        [double]$observedStages[$index].duration_seconds -eq
            [double]$declaredStages[$index].duration_seconds -and
        [string]$observedStages[$index].receipt_raw_sha256 -ceq
            [string]$declaredStages[$index].receipt_raw_sha256 -and
        -not [bool]$observedStages[$index].result_reused
    ) "clean-pushed stage receipt changed at ordinal $($index + 1)"
}

$zeroWorldMarkers = @(Select-String -LiteralPath $cleanLogPath -Pattern (
    '^QSDK_R23D61_ZERO_WORLD_GATE '
))
Assert-R23D61Closure (
    $zeroWorldMarkers.Count -eq
        [int]$closure.retained_zero_world_result.integrated_marker_count
) "integrated zero-world marker count changed"
$zeroWorldReceipt = $zeroWorldMarkers[0].Line.Substring(
    "QSDK_R23D61_ZERO_WORLD_GATE ".Length
) | ConvertFrom-Json -AsHashtable -Depth 100
Assert-R23D61Closure (
    [bool]$zeroWorldReceipt.ok -and
    [string]$zeroWorldReceipt.source.head -ceq $sourceCommit -and
    [string]$zeroWorldReceipt.source.upstream -ceq $sourceCommit -and
    [bool]$zeroWorldReceipt.source.clean -and
    [bool]$zeroWorldReceipt.source.matches_upstream -and
    [bool]$zeroWorldReceipt.complete_zero_world_gate_passed -and
    [int]$zeroWorldReceipt.model_construction_count -eq 0 -and
    [int]$zeroWorldReceipt.world_attempt_count -eq 0 -and
    [int]$zeroWorldReceipt.world_build_count -eq 0 -and
    [int]$zeroWorldReceipt.solver_step_count -eq 0 -and
    -not [bool]$zeroWorldReceipt.physics_state_modified -and
    -not [bool]$zeroWorldReceipt.physical_question_declared -and
    -not [bool]$zeroWorldReceipt.physical_campaign_opened -and
    -not [bool]$zeroWorldReceipt.turning_claimed -and
    -not [bool]$zeroWorldReceipt.prone_to_standing_claimed -and
    -not [bool]$zeroWorldReceipt.cross_engine_equivalence_claimed -and
    -not [bool]$zeroWorldReceipt.physical_acceptance_authority -and
    -not [bool]$zeroWorldReceipt.release_authority
) "integrated zero-world receipt changed"

$release = Get-Content -Raw -LiteralPath $releasePath |
    ConvertFrom-Json -AsHashtable -Depth 100
$r23 = @($release.gates | Where-Object {
    [string]$_.gate_id -ceq "QSDK-R23"
})
Assert-R23D61Closure ($r23.Count -eq 1) "release QSDK-R23 gate is not unique"
$releasePublication = $r23[0].proof.r23d61_selected_actuator_profile_publication
$support = Get-Content -Raw -LiteralPath $supportPath |
    ConvertFrom-Json -AsHashtable -Depth 100
$supportPublication = $support.locomotion_modes.selected_actuator_cap_profile_publication
foreach ($authority in @($releasePublication, $supportPublication)) {
    Assert-R23D61Closure (
        [string]$authority.status -ceq
            "closed_complete_valid_positive_non_physical_source_conformance" -and
        [string]$authority.closure_path -ceq
            "sdk/turning/r23d61_selected_actuator_profile_publication_closure_v1.json" -and
        [string]$authority.closure_raw_sha256 -ceq
            (Get-R23D61RawSha256 -Path $closurePath) -and
        [string]$authority.closure_audit_path -ceq
            "tests/test_qsdk_r23d61_publication_closure.ps1" -and
        [string]$authority.closure_audit_raw_sha256 -ceq
            (Get-R23D61RawSha256 -Path $PSCommandPath) -and
        [string]$authority.publication_source_commit -ceq $sourceCommit -and
        [string]$authority.publication_source_tree_git_oid -ceq $sourceTree -and
        [string]$authority.clean_pushed_qualification_receipt_raw_sha256 -ceq
            [string]$qualification.receipt_raw_sha256 -and
        [bool]$authority.clean_pushed_source_qualification_retained -and
        [bool]$authority.retained_closure_exists -and
        -not [bool]$authority.three_engine_turning -and
        -not [bool]$authority.cross_engine_equivalence -and
        -not [bool]$authority.arbitrary_morphology_support -and
        -not [bool]$authority.prone_to_standing -and
        -not [bool]$authority.physical_acceptance_authority -and
        -not [bool]$authority.release_authority
    ) "live release/support publication authority changed"
}
Assert-R23D61Closure (
    [string]$r23[0].proof.kind -ceq "missing" -and
    -not [bool]$support.release_authorized -and
    -not [bool]$support.completed_engine_neutral_sdk
) "R23D61 incorrectly satisfied release or QSDK-R23"

# Structural mutation controls prove that closure identity, failed-attempt
# preservation, qualification provenance, zero-world counts, and non-claims
# cannot drift into a passing audit.
$mutations = @()
$candidate = Copy-R23D61JsonValue $closure; $candidate.schema_version = "mutated"; $mutations += ,$candidate
$candidate = Copy-R23D61JsonValue $closure; $candidate.status = "mutated"; $mutations += ,$candidate
$candidate = Copy-R23D61JsonValue $closure; $candidate.question_class = "finite_decision"; $mutations += ,$candidate
$candidate = Copy-R23D61JsonValue $closure; $candidate.physical_question_declared = $true; $mutations += ,$candidate
$candidate = Copy-R23D61JsonValue $closure; $candidate.publication_source_freeze.commit = "0" * 40; $mutations += ,$candidate
$candidate = Copy-R23D61JsonValue $closure; $candidate.profile.profile_sha256 = "sha256:mutated"; $mutations += ,$candidate
$candidate = Copy-R23D61JsonValue $closure; $candidate.qualification_history[0].status = "passed"; $mutations += ,$candidate
$candidate = Copy-R23D61JsonValue $closure; $candidate.qualification_history[1].status = "passed"; $mutations += ,$candidate
$candidate = Copy-R23D61JsonValue $closure; $candidate.clean_pushed_qualification.source_worktree_clean = $false; $mutations += ,$candidate
$candidate = Copy-R23D61JsonValue $closure; $candidate.clean_pushed_qualification.run_id = "mutated"; $mutations += ,$candidate
$candidate = Copy-R23D61JsonValue $closure; $candidate.retained_zero_world_result.world_build_count = 1; $mutations += ,$candidate
$candidate = Copy-R23D61JsonValue $closure; $candidate.adequacy_and_claim_boundary.cross_engine_equivalence = $true; $mutations += ,$candidate
$candidate = Copy-R23D61JsonValue $closure; $candidate.release_boundary.passed_gate_count = 11; $mutations += ,$candidate
$candidate = Copy-R23D61JsonValue $closure; $candidate.next_allowed_work.movement_priority = "more_turning"; $mutations += ,$candidate

$rejectedMutationCount = 0
foreach ($mutation in $mutations) {
    try {
        Test-R23D61ClosureContract -Candidate $mutation
    } catch {
        $rejectedMutationCount += 1
    }
}
Assert-R23D61Closure (
    $rejectedMutationCount -eq 14
) "mutation rejection count changed"

Write-Host (
    "QSDK_R23D61_PUBLICATION_CLOSURE_PASS " +
    "status=positive_source_conformance source=$sourceCommit stages=8 " +
    "failed_attempts=2 dirty_passes=1 clean_passes=1 source_bindings=22 " +
    "adapter_mutations=35 publication_mutations=18 closure_mutations=14 " +
    "worlds=0 turning=False prone=False equivalence=False " +
    "physical_authority=False release_authority=False next=canonical_prone_to_standing"
)
