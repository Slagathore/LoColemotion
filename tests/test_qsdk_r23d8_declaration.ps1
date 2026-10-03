#requires -Version 7.0

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$declarationRelativePath = "sdk/turning/r23d8_authorization_closed_preregistration_v1.json"
$predecessorClosureRelativePath = "sdk/turning/r23d7_physical_closure_v1.json"
$predecessorPreregistrationRelativePath = (
    "sdk/turning/r23d7_neutral_stance_preregistration_v1.json"
)
$declarationPath = Join-Path $repoRoot $declarationRelativePath
$predecessorClosurePath = Join-Path $repoRoot $predecessorClosureRelativePath
$predecessorPreregistrationPath = Join-Path (
    $repoRoot
) $predecessorPreregistrationRelativePath
$conformancePath = Join-Path $repoRoot "sdk/run_conformance.ps1"

function Assert-R23D8Declaration {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function Get-R23D8RawSha256 {
    param([Parameter(Mandatory)][string]$Path)
    return "sha256:" + (
        Get-FileHash -LiteralPath $Path -Algorithm SHA256
    ).Hash.ToLowerInvariant()
}

function Get-R23D8GitBlobOid {
    param(
        [Parameter(Mandatory)][string]$Commit,
        [Parameter(Mandatory)][string]$RepoRelativePath
    )
    $revision = "$Commit`:$RepoRelativePath"
    $value = @(& git -C $repoRoot rev-parse $revision 2>&1)
    if ($LASTEXITCODE -ne 0) {
        throw "QSDK-R23D8 Git blob lookup failed: $revision :: $($value -join ' ')"
    }
    return ($value -join "`n").Trim()
}

function Test-R23D8WorkerBindings {
    param(
        [Parameter(Mandatory)][string]$WorkerId,
        [Parameter(Mandatory)][hashtable]$RequiredPathsByWorker,
        [Parameter(Mandatory)][AllowEmptyCollection()][object[]]$SourceBindings
    )

    if (-not $RequiredPathsByWorker.ContainsKey($WorkerId)) { return $false }
    $requiredPaths = @($RequiredPathsByWorker[$WorkerId])
    if ($requiredPaths.Count -eq 0) { return $false }
    if (@($requiredPaths | Group-Object -CaseSensitive | Where-Object Count -gt 1).Count -gt 0) {
        return $false
    }

    $bindingsByPath = @{}
    foreach ($binding in $SourceBindings) {
        if ($binding -isnot [hashtable]) { return $false }
        if (-not $binding.ContainsKey("path") -or -not $binding.ContainsKey("raw_sha256")) {
            return $false
        }
        $path = [string]$binding.path
        $digest = [string]$binding.raw_sha256
        if ($path.Length -eq 0 -or $digest -cnotmatch '^sha256:[0-9a-f]{64}$') {
            return $false
        }
        if ($bindingsByPath.ContainsKey($path)) { return $false }
        $bindingsByPath[$path] = $digest
    }

    if ($bindingsByPath.Count -ne $requiredPaths.Count) { return $false }
    foreach ($path in $requiredPaths) {
        if (-not $bindingsByPath.ContainsKey([string]$path)) { return $false }
        $expectedDigest = "sha256:" + ([string]$path).PadRight(64, "0").Substring(0, 64)
        if ([string]$bindingsByPath[[string]$path] -cne $expectedDigest) {
            return $false
        }
    }
    return $true
}

$actualRoot = [IO.Path]::GetFullPath((git -C $repoRoot rev-parse --show-toplevel).Trim())
Assert-R23D8Declaration (
    $actualRoot -ceq $repoRoot -and
    (git -C $repoRoot remote get-url origin).Trim() -ceq
        "https://github.com/Slagathore/sporespore.git" -and
    (Test-Path -LiteralPath $declarationPath -PathType Leaf) -and
    (Test-Path -LiteralPath $predecessorClosurePath -PathType Leaf) -and
    (Test-Path -LiteralPath $predecessorPreregistrationPath -PathType Leaf) -and
    (Test-Path -LiteralPath $conformancePath -PathType Leaf)
) "QSDK-R23D8 declaration repository or predecessor inputs changed"

$declaration = Get-Content -Raw -LiteralPath $declarationPath |
    ConvertFrom-Json -AsHashtable -Depth 100
$predecessorClosure = Get-Content -Raw -LiteralPath $predecessorClosurePath |
    ConvertFrom-Json -AsHashtable -Depth 100
$predecessorPreregistration = Get-Content -Raw -LiteralPath $predecessorPreregistrationPath |
    ConvertFrom-Json -AsHashtable -Depth 100

$campaignId = "QSDK-R23D8-AUTHORIZATION-CLOSED-NEUTRAL-STANCE-BILATERAL-TURN-DEVELOPMENT"
Assert-R23D8Declaration (
    [string]$declaration.schema_version -ceq
        "sporespore_qsdk_r23d8_authorization_closed_preregistration_v1" -and
    [string]$declaration.status -ceq
        "stage_zero_preregistered_implementation_successor_no_workers_no_physical_authorization" -and
    [string]$declaration.campaign_id -ceq $campaignId -and
    [string]$declaration.gate_id -ceq "QSDK-R23D8" -and
    [string]$declaration.release_gate_id -ceq "QSDK-R23" -and
    [string]$declaration.study_classification -ceq
        "prospective_exact_finite_implementation_successor_after_zero_world_invalid_attempt"
) "QSDK-R23D8 declaration identity changed"

$lineage = $declaration.lineage
$authority = $declaration.inherited_scientific_contract_authority
Assert-R23D8Declaration (
    [string]$lineage.predecessor_id -ceq "QSDK-R23D7" -and
    [string]$lineage.predecessor_campaign_id -ceq
        "QSDK-R23D7-NEUTRAL-STANCE-ACQUISITION-BILATERAL-TURN-DEVELOPMENT" -and
    [string]$lineage.predecessor_closure_path -ceq $predecessorClosureRelativePath -and
    [string]$lineage.predecessor_closure_commit -ceq
        "e3d18cab09d80cb765e4ceeb17a0ceda8dfa03a8" -and
    [string]$lineage.predecessor_closure_git_blob_oid -ceq
        "652ea62f79755422faf4f03abb1afa215d1883bd" -and
    [string]$lineage.predecessor_closure_raw_sha256 -ceq
        (Get-R23D8RawSha256 $predecessorClosurePath) -and
    (Get-R23D8GitBlobOid `
        ([string]$lineage.predecessor_closure_commit) `
        $predecessorClosureRelativePath) -ceq
        [string]$lineage.predecessor_closure_git_blob_oid -and
    [string]$authority.path -ceq $predecessorPreregistrationRelativePath -and
    [string]$authority.git_blob_oid -ceq
        "5db9e025b2b993cc0d44dc985566f83424423008" -and
    [string]$authority.raw_sha256 -ceq
        (Get-R23D8RawSha256 $predecessorPreregistrationPath) -and
    (Get-R23D8GitBlobOid `
        ([string]$lineage.predecessor_source_commit) `
        $predecessorPreregistrationRelativePath) -ceq
        [string]$authority.git_blob_oid -and
    [bool]$authority.inherited_in_full
) "QSDK-R23D8 pinned predecessor authority changed"

$attempt = $predecessorClosure.attempt
$predecessorClaims = $predecessorClosure.claims
Assert-R23D8Declaration (
    [string]$predecessorClosure.status -ceq
        "closed_consumed_implementation_invalid_zero_world" -and
    [string]$predecessorClosure.campaign_id -ceq
        [string]$lineage.predecessor_campaign_id -and
    [string]$predecessorClosure.gate_id -ceq "QSDK-R23D7" -and
    [string]$predecessorClosure.source_identity.commit -ceq
        [string]$lineage.predecessor_source_commit -and
    [bool]$attempt.one_shot_identity_consumed -and
    -not [bool]$attempt.same_identity_rerun_allowed -and
    [int]$attempt.launched_stage_a_worker_process_count -eq 2 -and
    [int]$attempt.terminalized_stage_a_cell_count -eq 2 -and
    [int]$attempt.valid_completed_stage_a_cell_count -eq 0 -and
    [int]$attempt.world_attempt_count -eq 0 -and
    [int]$attempt.world_build_count -eq 0 -and
    -not [bool]$attempt.stage_b_authorization_created -and
    [int]$attempt.stage_b_worker_process_count -eq 0 -and
    [int]$attempt.unopened_stage_b_cell_count -eq 9 -and
    -not [bool]$predecessorClaims.scientific_positive -and
    -not [bool]$predecessorClaims.scientific_negative -and
    -not [bool]$predecessorClaims.command_conditioned_turning -and
    -not [bool]$predecessorClaims.cross_engine_equivalence -and
    [string]$predecessorClosure.successor_boundary.successor_id -ceq "QSDK-R23D8" -and
    [bool]$predecessorClosure.successor_boundary.same_scientific_estimand_may_be_retained_because_no_world_opened -and
    -not [bool]$predecessorClosure.successor_boundary.numeric_threshold_change_required -and
    [bool]$predecessorClosure.successor_boundary.production_shaped_authorization_canary_required_for_every_engine -and
    [bool]$predecessorClosure.successor_boundary.worker_dependency_manifest_must_have_one_nonduplicated_authority
) "QSDK-R23D8 immutable predecessor boundary changed"

Assert-R23D8Declaration (
    [string]$lineage.predecessor_status -ceq [string]$predecessorClosure.status -and
    [bool]$lineage.predecessor_one_shot_identity_consumed -and
    -not [bool]$lineage.predecessor_same_identity_rerun_allowed -and
    [int]$lineage.predecessor_stage_a_worker_process_count -eq 2 -and
    [int]$lineage.predecessor_world_attempt_count -eq 0 -and
    [int]$lineage.predecessor_world_build_count -eq 0 -and
    -not [bool]$lineage.predecessor_stage_b_opened -and
    -not [bool]$lineage.predecessor_scientific_positive -and
    -not [bool]$lineage.predecessor_scientific_negative -and
    [bool]$lineage.predecessor_reclassification_forbidden -and
    [bool]$lineage.predecessor_threshold_rewrite_forbidden
) "QSDK-R23D8 declared lineage changed"

$unchangedFields = @(
    "fixture_changed",
    "morphology_changed",
    "turning_controller_policy_changed",
    "neutral_stance_policy_changed",
    "host_profiles_changed",
    "turn_heading_magnitude_changed",
    "turn_onset_changed",
    "controller_horizon_changed",
    "terminal_stance_horizon_changed",
    "contact_acquisition_deadline_changed",
    "contact_hold_requirement_changed",
    "passive_settle_changed",
    "outcome_numeric_thresholds_changed",
    "stage_a_schedule_changed",
    "stage_a_selector_changed",
    "stage_b_schedule_changed",
    "diagnostic_trace_contract_changed",
    "result_classification_changed"
)
foreach ($field in $unchangedFields) {
    Assert-R23D8Declaration (
        $authority.ContainsKey($field) -and -not [bool]$authority[$field]
    ) "QSDK-R23D8 scientific inheritance changed: $field"
}

$snapshot = $declaration.frozen_identity_snapshot
$parentSnapshot = $predecessorPreregistration.frozen_schedule_and_gate_snapshot
$directSnapshotFields = @(
    "morphology_id",
    "campaign_seed",
    "physics_hz",
    "selected_policy_id",
    "selected_policy_digest",
    "fixed_onset_id",
    "turn_heading_offset_rad_by_arm",
    "turning_controller_semantic_step_count",
    "terminal_stance_step_count",
    "maximum_four_contact_acquisition_steps",
    "required_consecutive_all_four_contact_hold_steps",
    "passive_settle_step_count",
    "total_traced_step_count"
)
foreach ($field in $directSnapshotFields) {
    Assert-R23D8Declaration (
        ($snapshot[$field] | ConvertTo-Json -Compress -Depth 20) -ceq
            ($parentSnapshot[$field] | ConvertTo-Json -Compress -Depth 20)
    ) "QSDK-R23D8 frozen scientific identity changed: $field"
}
Assert-R23D8Declaration (
    [string]$snapshot.terminal_stance_policy_id -ceq
        [string]$predecessorPreregistration.neutral_stance_policy_contract.policy_id -and
    [int]$snapshot.stage_a_declared_cell_count -eq
        [int]$predecessorPreregistration.stage_a_mujoco_terminal_stance_screen.declared_cell_count -and
    [int]$snapshot.stage_b_declared_cell_count_if_selected -eq
        [int]$predecessorPreregistration.stage_b_three_engine_confirmation.declared_cell_count_if_launched -and
    [string]$snapshot.selector_policy_id_if_passing -ceq
        [string]$predecessorPreregistration.stage_a_selector.selected_policy_id_if_passing -and
    [string]$snapshot.selector_policy_id_if_not_passing -ceq
        [string]$predecessorPreregistration.stage_a_selector.selected_policy_id_if_not_passing
) "QSDK-R23D8 inherited stage schedule or selector changed"

$implementation = $declaration.implementation_successor_contract
Assert-R23D8Declaration (
    [string]$implementation.only_permitted_change_class -ceq
        "worker_dependency_authority_and_production_authorization_preflight" -and
    [bool]$implementation.new_campaign_and_gate_identity_required -and
    [bool]$implementation.r23d7_source_or_result_rewrite_forbidden -and
    [bool]$implementation.r23d7_same_identity_rerun_forbidden -and
    [string]$implementation.one_required_dependency_manifest_authority -ceq
        "sdk/turning/r23d8_implementation_contract_v1.json#dependency_closure.required_dependency_paths_by_worker" -and
    -not [bool]$implementation.worker_local_ordered_dependency_tuple_permitted -and
    -not [bool]$implementation.worker_local_duplicate_dependency_manifest_permitted -and
    [bool]$implementation.each_worker_must_parse_its_required_paths_from_the_one_manifest -and
    [bool]$implementation.each_required_path_must_have_exact_frozen_raw_sha256 -and
    [bool]$implementation.missing_extra_duplicate_malformed_and_mismatched_binding_controls_required -and
    [bool]$implementation.worker_unknown_or_empty_dependency_set_must_fail_closed -and
    [bool]$implementation.supervisor_must_prove_union_and_each_worker_subset_before_input_cas -and
    [bool]$implementation.production_authorization_canary_must_use_supervisor_composed_records -and
    [bool]$implementation.production_authorization_canary_must_call_same_function_as_physical_execution -and
    -not [bool]$implementation.canary_specific_authorization_shortcut_permitted -and
    [bool]$implementation.canary_may_return_immediately_after_successful_authorization_before_model -and
    [bool]$implementation.production_authorization_pass_and_mutated_binding_refusal_required_per_engine -and
    [bool]$implementation.closure_interlock_required_for_predecessor_and_successor
) "QSDK-R23D8 one-authority implementation contract changed"

$requiredPathsByWorker = @{
    mujoco = @("a", "b", "c")
    rapier_parry = @("d", "e")
    godot_jolt = @("f", "0")
}
$positiveBindingsByWorker = @{}
foreach ($workerId in @("mujoco", "rapier_parry", "godot_jolt")) {
    $positiveBindingsByWorker[$workerId] = @(
        $requiredPathsByWorker[$workerId] | ForEach-Object {
            @{
                path = [string]$_
                raw_sha256 = "sha256:" + ([string]$_).PadRight(64, "0").Substring(0, 64)
            }
        }
    )
    Assert-R23D8Declaration (
        Test-R23D8WorkerBindings `
            $workerId `
            $requiredPathsByWorker `
            $positiveBindingsByWorker[$workerId]
    ) "QSDK-R23D8 positive source-binding oracle failed: $workerId"
}

$mutationsRejected = @{}
$removedBinding = @($positiveBindingsByWorker.mujoco | Select-Object -Skip 1)
$mutationsRejected.removed_required_binding = -not (
    Test-R23D8WorkerBindings "mujoco" $requiredPathsByWorker $removedBinding
)
$wrongDigest = @($positiveBindingsByWorker.mujoco | ForEach-Object { @{} + $_ })
$wrongDigest[0].raw_sha256 = "sha256:" + ("f" * 64)
$mutationsRejected.mismatched_required_binding_digest = -not (
    Test-R23D8WorkerBindings "mujoco" $requiredPathsByWorker $wrongDigest
)
$duplicateBinding = @($positiveBindingsByWorker.mujoco) + @(
    @{} + $positiveBindingsByWorker.mujoco[0]
)
$mutationsRejected.duplicate_source_binding_path = -not (
    Test-R23D8WorkerBindings "mujoco" $requiredPathsByWorker $duplicateBinding
)
$malformedDigest = @($positiveBindingsByWorker.mujoco | ForEach-Object { @{} + $_ })
$malformedDigest[0].raw_sha256 = "sha256:not-a-digest"
$mutationsRejected.malformed_source_binding_digest = -not (
    Test-R23D8WorkerBindings "mujoco" $requiredPathsByWorker $malformedDigest
)
$mutationsRejected.unknown_worker_id = -not (
    Test-R23D8WorkerBindings "unknown" $requiredPathsByWorker @()
)
$emptySetMap = @{} + $requiredPathsByWorker
$emptySetMap.mujoco = @()
$mutationsRejected.empty_worker_required_set = -not (
    Test-R23D8WorkerBindings "mujoco" $emptySetMap @()
)
$duplicateDeclaredMap = @{} + $requiredPathsByWorker
$duplicateDeclaredMap.mujoco = @("a", "a", "b", "c")
$mutationsRejected.duplicate_declared_required_path = -not (
    Test-R23D8WorkerBindings `
        "mujoco" `
        $duplicateDeclaredMap `
        $positiveBindingsByWorker.mujoco
)
$mutationsRejected.authorization_canary_shortcut_not_shared_with_physical_route = (
    [bool]$implementation.production_authorization_canary_must_call_same_function_as_physical_execution -and
    -not [bool]$implementation.canary_specific_authorization_shortcut_permitted
)

$expectedMutationIds = @(
    "removed_required_binding",
    "mismatched_required_binding_digest",
    "duplicate_source_binding_path",
    "malformed_source_binding_digest",
    "unknown_worker_id",
    "empty_worker_required_set",
    "duplicate_declared_required_path",
    "authorization_canary_shortcut_not_shared_with_physical_route"
)
Assert-R23D8Declaration (
    (@($declaration.required_authorization_mutation_controls) -join "|") -ceq
        ($expectedMutationIds -join "|")
) "QSDK-R23D8 mutation-control inventory changed"
foreach ($mutationId in $expectedMutationIds) {
    Assert-R23D8Declaration ([bool]$mutationsRejected[$mutationId]) (
        "QSDK-R23D8 authorization oracle did not reject mutation: $mutationId"
    )
}

$preflight = $declaration.production_shaped_zero_world_authorization_contract
Assert-R23D8Declaration (
    (@($preflight.engine_order) -join "|") -ceq
        "mujoco|rapier_parry|godot_jolt" -and
    [int]$preflight.engine_count -eq 3 -and
    [int]$preflight.positive_authorization_canary_count -eq 3 -and
    [int]$preflight.mutated_binding_refusal_canary_count -eq 3 -and
    [int]$preflight.actual_production_authorization_function_execution_count -eq 6 -and
    [string]$preflight.mujoco_function -ceq "_physical_authorization" -and
    [string]$preflight.rapier_function -ceq "r23d8_physical_authorization" -and
    [string]$preflight.godot_jolt_function -ceq "_r8_physical_authorization" -and
    [bool]$preflight.source_commit_must_be_valid_lower_hex -and
    [bool]$preflight.attempt_root_must_be_under_durable_evidence_root -and
    [bool]$preflight.freeze_and_attempt_schema_identity_must_be_exact -and
    [bool]$preflight.authorization_environment_identity_must_be_exact -and
    [bool]$preflight.one_shot_unconsumed_flag_must_be_true -and
    [bool]$preflight.all_required_source_bindings_must_match_current_preregistered_source -and
    [int]$preflight.worker_process_launch_count -eq 6 -and
    [int]$preflight.physical_process_launch_count -eq 0 -and
    [int]$preflight.model_construction_count -eq 0 -and
    [int]$preflight.world_attempt_count -eq 0 -and
    [int]$preflight.world_build_count -eq 0 -and
    [bool]$preflight.test_only_evidence_root_must_be_deleted_after_validated_under_project_evidence_root
) "QSDK-R23D8 production authorization preflight changed"

$stageZeroCommit = "f7bb0f8062b4baeef2a9ed29232fa1c17b262b6f"
$stageZeroPaths = @(& git -C $repoRoot ls-tree -r --name-only $stageZeroCommit)
Assert-R23D8Declaration ($LASTEXITCODE -eq 0) (
    "QSDK-R23D8 stage-zero tree is unavailable: $stageZeroCommit"
)
$allowedStageZeroPaths = @(
    $declarationRelativePath,
    "tests/test_qsdk_r23d8_declaration.ps1"
)
$unexpectedStageZeroImplementationPaths = @(
    $stageZeroPaths | Where-Object {
        ($_ -match '(?i)r23d8') -and
        ($allowedStageZeroPaths -cnotcontains [string]$_) -and
        [string]$_ -cne ".gitattributes"
    }
)
$conformanceText = Get-Content -Raw -LiteralPath $conformancePath
$authorization = $declaration.authorization
$claims = $declaration.claim_boundary
Assert-R23D8Declaration (
    $unexpectedStageZeroImplementationPaths.Count -eq 0 -and
    $conformanceText.Contains("tests\test_qsdk_r23d8_declaration.ps1") -and
    -not [bool]$authorization.physical_execution_authorized -and
    [bool]$authorization.worker_implementation_authorized -and
    [bool]$claims.stage_zero_design_complete -and
    -not [bool]$claims.implementation_complete -and
    -not [bool]$claims.production_authorization_proved -and
    -not [bool]$claims.stage_a_result_exists -and
    -not [bool]$claims.stage_b_result_exists -and
    -not [bool]$claims.scientific_positive -and
    -not [bool]$claims.scientific_negative -and
    -not [bool]$claims.command_conditioned_turning -and
    -not [bool]$claims.cross_engine_equivalence -and
    -not [bool]$claims.q_sdk_r23_satisfied -and
    -not [bool]$claims.prone_to_standing -and
    -not [bool]$claims.release_authorized -and
    -not [bool]$claims.physical_acceptance_authority
) "QSDK-R23D8 stage-zero boundary changed or implementation/evidence appeared"

Write-Host (
    "QSDK_R23D8_DECLARATION_PASS predecessor_workers=2 predecessor_worlds=0 " +
    "inherited_fields=18 engines=3 positive_canaries=3 refusal_canaries=3 " +
    "mutation_controls=8 workers_implemented=0 models=0 worlds=0 " +
    "turning=False equivalence=False physical_authority=False"
)
