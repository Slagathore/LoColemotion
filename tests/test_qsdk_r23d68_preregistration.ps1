#requires -Version 7.0

[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$declarationPath = Join-Path $repoRoot (
    "sdk\turning\r23d68_production_path_conformance_repaired_three_engine_" +
    "turning_preregistration_v1.json"
)
$seedCompilerPath = Join-Path $repoRoot "sdk\turning\r23d68_seed_fixture_compiler.gd"
$predecessorClosurePath = Join-Path $repoRoot (
    "sdk\turning\r23d67_authorization_schema_repaired_three_engine_turning_" +
    "validation_closure_v1.json"
)
$predecessorAuditPath = Join-Path $repoRoot "tests\test_qsdk_r23d67_physical_closure.ps1"
$immediateBasePath = Join-Path $repoRoot (
    "sdk\turning\r23d67_authorization_schema_repaired_three_engine_turning_" +
    "preregistration_v1.json"
)
$rootBasePath = Join-Path $repoRoot (
    "sdk\turning\r23d66_production_route_three_engine_turning_validation_" +
    "preregistration_v1.json"
)
$releaseContractPath = Join-Path $repoRoot "sdk\release\quadruped_release_contract.json"
$supportMatrixPath = Join-Path $repoRoot "sdk\release\quadruped_support_matrix.json"
$parentCommit = "970a338d9e05cf65104178f2a5c5d9f8e7f6313e"
$parentTree = "ab411937651b8269de5b600f277d5d4d048f38c3"
$campaignId = (
    "QSDK-R23D68-PRODUCTION-PATH-CONFORMANCE-REPAIRED-THREE-ENGINE-" +
    "TURNING-VALIDATION"
)
$declaredStatus = (
    "prospective_declaration_complete_compact_production_path_ghosts_and_" +
    "implementation_pending_physical_not_authorized"
)
$expectedCellIds = @(
    "r23d68__godot_jolt__s23185__reference_zero",
    "r23d68__godot_jolt__s23185__positive_heading",
    "r23d68__godot_jolt__s23185__negative_heading",
    "r23d68__rapier_parry__s23185__reference_zero",
    "r23d68__rapier_parry__s23185__positive_heading",
    "r23d68__rapier_parry__s23185__negative_heading",
    "r23d68__mujoco__s23185__reference_zero",
    "r23d68__mujoco__s23185__positive_heading",
    "r23d68__mujoco__s23185__negative_heading"
)

function Assert-R23D68([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "QSDK-R23D68 DECLARATION: $Message" }
}

function Get-R23D68Sha256([string]$Path) {
    return "sha256:" + (
        Get-FileHash -LiteralPath $Path -Algorithm SHA256
    ).Hash.ToLowerInvariant()
}

function Invoke-R23D68Git([string[]]$Arguments) {
    $lines = @(& git -C $repoRoot @Arguments 2>&1)
    Assert-R23D68 ($LASTEXITCODE -eq 0) (
        "git $($Arguments -join ' ') failed: $($lines -join ' ')"
    )
    return ($lines -join "`n").Trim()
}

function Get-R23D68TokenOccurrenceCount([int]$Candidate) {
    $grouped = "{0:N0}" -f $Candidate
    $escapedGrouped = [regex]::Escape($grouped)
    $pattern = (
        "(^|[^0-9])$Candidate([^0-9]|$)|" +
        "(^|[^0-9])$escapedGrouped([^0-9]|$)"
    )
    $matches = @(& git -C $repoRoot grep -I -o -E $pattern $parentCommit -- . 2>$null)
    $exitCode = $LASTEXITCODE
    Assert-R23D68 ($exitCode -eq 0 -or $exitCode -eq 1) (
        "token-bounded seed search failed for $Candidate"
    )
    return $matches.Count
}

function Test-R23D68Near([double]$Left, [double]$Right) {
    return [Math]::Abs($Left - $Right) -le 1.0e-15
}

function Test-R23D68DeclarationVector($Value) {
    return (
        [string]$Value.schema_version -ceq
            "sporespore_qsdk_r23d68_production_path_conformance_repaired_three_engine_turning_preregistration_v1" -and
        [string]$Value.status -ceq $declaredStatus -and
        [string]$Value.campaign_id -ceq $campaignId -and
        [string]$Value.gate_id -ceq "QSDK-R23D68" -and
        [string]$Value.release_gate_id -ceq "QSDK-R23" -and
        [string]$Value.ledger_scope.subsystem -ceq "turning" -and
        [string]$Value.ledger_scope.engine_scope -ceq "3e" -and
        [string]$Value.ledger_scope.question_class -ceq "finite_decision" -and
        [string]$Value.physical_question_class -ceq "finite_decision" -and
        [string]$Value.integration_repair_work_class -ceq
            "development_then_complete_population_equivalence_non_inferiority" -and
        [bool]$Value.not_superiority_work -and
        [bool]$Value.not_physical_equivalence_or_non_inferiority_work -and
        [string]$Value.declaration_parent.commit -ceq $parentCommit -and
        [string]$Value.declaration_parent.tree_git_oid -ceq $parentTree -and
        [bool]$Value.declaration_parent.clean_pushed_live_equal -and
        [string]$Value.immutable_predecessor.gate_id -ceq "QSDK-R23D67" -and
        [bool]$Value.immutable_predecessor.campaign_identity_consumed -and
        -not [bool]$Value.immutable_predecessor.same_identity_rerun_allowed -and
        [int]$Value.immutable_predecessor.world_build_count -eq 1 -and
        [int]$Value.immutable_predecessor.retained_row_count -eq 2992 -and
        -not [bool]$Value.immutable_predecessor.turning_result_created -and
        [int]$Value.inherited_behavior_contract.threshold_selector_evaluator_or_interpretation_change_count -eq 0 -and
        [int]$Value.inherited_behavior_contract.controller_profile_schedule_or_measurement_change_count -eq 0 -and
        [int]$Value.scientific_distinction_and_change_budget.fresh_seed -eq 23185 -and
        [int]$Value.scientific_distinction_and_change_budget.first_candidate_after_consumed_seed -eq 23183 -and
        [int]$Value.scientific_distinction_and_change_budget.first_candidate_rejected_token_occurrence_count_at_declaration_parent -eq 7 -and
        [int]$Value.scientific_distinction_and_change_budget.fresh_seed_identity_occurrence_count_at_declaration_parent -eq 0 -and
        [int]@($Value.scientific_distinction_and_change_budget.allowed_integration_changes).Count -eq 5 -and
        [int]@($Value.scientific_distinction_and_change_budget.forbidden_changes).Count -eq 11 -and
        [int]$Value.seed_fixture_compilation.seed -eq 23185 -and
        [int]$Value.seed_fixture_compilation.model_construction_count -eq 0 -and
        [int]$Value.seed_fixture_compilation.world_attempt_count -eq 0 -and
        [int]$Value.seed_fixture_compilation.world_build_count -eq 0 -and
        [string]$Value.production_path_conformance_contract.trace_vocabulary_repair.predecessor_producer_segment_id -ceq
            "after_declared_schedule" -and
        [string]$Value.production_path_conformance_contract.trace_vocabulary_repair.frozen_evaluator_segment_id -ceq
            "reference_continuation" -and
        [string]$Value.production_path_conformance_contract.trace_vocabulary_repair.required_successor_production_segment_id -ceq
            "reference_continuation" -and
        [int]$Value.production_path_conformance_contract.trace_vocabulary_repair.affected_first_semantic_step -eq 2400 -and
        [int]$Value.production_path_conformance_contract.trace_vocabulary_repair.affected_last_semantic_step -eq 2991 -and
        [int]$Value.production_path_conformance_contract.trace_vocabulary_repair.affected_row_count -eq 592 -and
        [string]$Value.production_path_conformance_contract.process_projection_repair.observed_actual_process_type -ceq
            "System.Management.Automation.PSCustomObject" -and
        [string]$Value.production_path_conformance_contract.process_projection_repair.observed_invalid_method -ceq
            "Contains" -and
        [int]@($Value.production_path_conformance_contract.process_projection_repair.supported_shape_population).Count -eq 2 -and
        [int]$Value.production_path_conformance_contract.conformance_margin -eq 0 -and
        [bool]$Value.production_path_conformance_contract.complete_population_required -and
        -not [bool]$Value.production_path_conformance_contract.sampling_used -and
        [int]$Value.production_path_conformance_contract.physical_world_count -eq 0 -and
        [int]@($Value.compact_development_ghosts.trace_boundary_ghost.semantic_steps).Count -eq 7 -and
        [int]$Value.compact_development_ghosts.process_projection_ghost.supported_shape_count -eq 2 -and
        -not [bool]$Value.compact_development_ghosts.full_seeded_world_required -and
        -not [bool]$Value.compact_development_ghosts.behavioral_success_prediction_allowed -and
        [int]$Value.frozen_matrix.campaign_seed -eq 23185 -and
        [int]$Value.frozen_matrix.declared_cell_count -eq 9 -and
        (@($Value.frozen_matrix.ordered_cell_ids) -join "`n") -ceq
            ($expectedCellIds -join "`n") -and
        -not [bool]$Value.prephysical_requirements.implementation_content_addressed -and
        -not [bool]$Value.prephysical_requirements.compact_trace_boundary_ghost_passed -and
        -not [bool]$Value.prephysical_requirements.compact_process_projection_ghost_passed -and
        [bool]$Value.prephysical_requirements.fresh_clean_pushed_qualification_required -and
        [bool]$Value.prephysical_requirements.separate_exact_source_adoption_required -and
        -not [bool]$Value.prephysical_requirements.physical_execution_authorized -and
        [bool]$Value.decision_rule.inherit_exactly_from_base_contract -and
        [bool]$Value.decision_rule.all_nine_cells_must_be_execution_valid_and_pass -and
        -not [bool]$Value.decision_rule.same_identity_rerun_allowed -and
        -not [bool]$Value.decision_rule.selective_completion_allowed -and
        [int]$Value.threshold_and_population_provenance.equivalence_margin -eq 0 -and
        [int]$Value.threshold_and_population_provenance.non_inferiority_margin -eq 0 -and
        [int]$Value.threshold_and_population_provenance.physical_cohort_size -eq 9 -and
        [int]$Value.threshold_and_population_provenance.integration_population_size -eq 2 -and
        [bool]$Value.claims.declaration_complete -and
        [bool]$Value.claims.integration_conformance_contract_complete -and
        -not [bool]$Value.claims.implementation_complete -and
        -not [bool]$Value.claims.compact_production_path_ghosts_passed -and
        -not [bool]$Value.claims.physical_campaign_opened -and
        -not [bool]$Value.claims.q_sdk_r23_satisfied -and
        [string]$Value.claims.release_score_before -ceq "10/25" -and
        [string]$Value.claims.release_score_after -ceq "10/25" -and
        [int]$Value.model_construction_count -eq 0 -and
        [int]$Value.world_attempt_count -eq 0 -and
        [int]$Value.world_build_count -eq 0 -and
        -not [bool]$Value.physical_execution_authorized -and
        -not [bool]$Value.physical_acceptance_authority -and
        -not [bool]$Value.release_authorized
    )
}

Assert-R23D68 (
    (Invoke-R23D68Git @("rev-parse", "--show-toplevel")) -ceq
        $repoRoot.Replace("\", "/") -and
    (Invoke-R23D68Git @("remote", "get-url", "origin")) -ceq
        "https://github.com/Slagathore/sporespore.git"
) "repository identity changed"
foreach ($path in @(
    $declarationPath,
    $seedCompilerPath,
    $predecessorClosurePath,
    $predecessorAuditPath,
    $immediateBasePath,
    $rootBasePath,
    $releaseContractPath,
    $supportMatrixPath
)) { Assert-R23D68 (Test-Path -LiteralPath $path -PathType Leaf) "missing path: $path" }

$declaration = Get-Content -LiteralPath $declarationPath -Raw |
    ConvertFrom-Json -AsHashtable -Depth 100
Assert-R23D68 (Test-R23D68DeclarationVector $declaration) "declaration vector changed"
Assert-R23D68 (
    (Invoke-R23D68Git @("rev-parse", "$parentCommit^{tree}")) -ceq $parentTree -and
    (Invoke-R23D68Git @("rev-parse", "$parentCommit`:scripts/lab/gait/physical_wave_gait_quadruped.gd")) -ceq
        [string]$declaration.production_path_conformance_contract.trace_vocabulary_repair.observed_predecessor_producer_git_blob_oid -and
    (Invoke-R23D68Git @("rev-parse", "$parentCommit`:sdk/turning/r23d67_production_route_runtime.py")) -ceq
        [string]$declaration.production_path_conformance_contract.trace_vocabulary_repair.observed_predecessor_runtime_git_blob_oid -and
    (Invoke-R23D68Git @("rev-parse", "$parentCommit`:sdk/turning/r23d67_production_route_three_engine_turning_evaluator.py")) -ceq
        [string]$declaration.production_path_conformance_contract.trace_vocabulary_repair.observed_predecessor_evaluator_git_blob_oid -and
    (Invoke-R23D68Git @("rev-parse", "$parentCommit`:sdk/run_qsdk_r23d67_supervisor.ps1")) -ceq
        [string]$declaration.production_path_conformance_contract.process_projection_repair.observed_predecessor_supervisor_git_blob_oid
) "declaration-parent source identity changed"
Assert-R23D68 (
    (Get-R23D68TokenOccurrenceCount 23183) -eq 7 -and
    (Get-R23D68TokenOccurrenceCount 23185) -eq 0
) "fresh-seed selection proof changed"

Assert-R23D68 (
    (Get-R23D68Sha256 $predecessorClosurePath) -ceq
        [string]$declaration.immutable_predecessor.closure_raw_sha256 -and
    (Get-R23D68Sha256 $predecessorAuditPath) -ceq
        [string]$declaration.immutable_predecessor.closure_audit_raw_sha256 -and
    (Get-R23D68Sha256 $immediateBasePath) -ceq
        [string]$declaration.inherited_behavior_contract.immediate_base_raw_sha256 -and
    (Get-R23D68Sha256 $rootBasePath) -ceq
        [string]$declaration.inherited_behavior_contract.root_base_raw_sha256 -and
    (Get-R23D68Sha256 $seedCompilerPath) -ceq
        [string]$declaration.seed_fixture_compilation.compiler_raw_sha256
) "declared dependency digest changed"
$predecessor = Get-Content -LiteralPath $predecessorClosurePath -Raw |
    ConvertFrom-Json -AsHashtable -Depth 100
Assert-R23D68 (
    [string]$predecessor.status -ceq [string]$declaration.immutable_predecessor.status -and
    [bool]$predecessor.claims.campaign_identity_consumed -and
    [int]$predecessor.first_world_observation.actual_row_count -eq 2992 -and
    [int]$predecessor.failure_mechanisms[0].affected_row_count -eq 592 -and
    [string]$predecessor.failure_mechanisms[1].invalid_method_call -ceq "Contains" -and
    -not [bool]$predecessor.claims.turning_claimed
) "immutable predecessor boundary changed"

$parentProducer = Invoke-R23D68Git @(
    "show", "$parentCommit`:scripts/lab/gait/physical_wave_gait_quadruped.gd"
)
$parentRuntime = Invoke-R23D68Git @(
    "show", "$parentCommit`:sdk/turning/r23d67_production_route_runtime.py"
)
$parentEvaluator = Invoke-R23D68Git @(
    "show", "$parentCommit`:sdk/turning/r23d67_production_route_three_engine_turning_evaluator.py"
)
$parentSupervisor = Invoke-R23D68Git @(
    "show", "$parentCommit`:sdk/run_qsdk_r23d67_supervisor.ps1"
)
Assert-R23D68 (
    $parentProducer -cmatch 'segment_id = "after_declared_schedule"' -and
    $parentRuntime -cmatch 'return "reference_continuation", 0\.0' -and
    $parentRuntime -cmatch '"reference_continuation": 592' -and
    $parentEvaluator -cmatch 'inherited\.design = design' -and
    $parentSupervisor -cmatch '\$process\.Contains\("host_exit_code"\)'
) "observed predecessor integration failures changed"

$seedSource = Get-Content -LiteralPath $seedCompilerPath -Raw
Assert-R23D68 (
    $seedSource -cmatch 'R23D68_HELD_OUT_SEEDS := \[23185\]' -and
    $seedSource -cmatch 'compile_seeded_initial_perturbation\(seed\)' -and
    $seedSource -cnotmatch '\.instantiate\(' -and
    $seedSource -cnotmatch 'PhysicsServer' -and
    $seedSource -cnotmatch 'RigidBody'
) "pure seed compiler source changed"
$godotPath = "C:\Users\Cole\CodeStuff\Misc\Godot\Godot_v4.7-stable_mono_win64_console.exe"
Assert-R23D68 (Test-Path -LiteralPath $godotPath -PathType Leaf) "Godot host missing"
$seedOutput = @(& $godotPath --headless --path $repoRoot `
    --script res://sdk/turning/r23d68_seed_fixture_compiler.gd 2>&1)
Assert-R23D68 ($LASTEXITCODE -eq 0) "pure seed compiler failed: $($seedOutput -join ' ')"
$seedMarker = @($seedOutput | Where-Object {
    [string]$_ -clike "QSDK_R23D68_SEED_FIXTURES *"
})
Assert-R23D68 ($seedMarker.Count -eq 1) "pure seed marker population changed"
$seedReceipt = ([string]$seedMarker[0]).Substring(
    "QSDK_R23D68_SEED_FIXTURES ".Length
) | ConvertFrom-Json -AsHashtable -Depth 100
$fixture = @($seedReceipt.fixtures)[0]
$declaredFixture = $declaration.seed_fixture_compilation.compiled_initial_perturbation
Assert-R23D68 (
    [int]$seedReceipt.model_construction_count -eq 0 -and
    [int]$seedReceipt.world_attempt_count -eq 0 -and
    [int]$seedReceipt.world_build_count -eq 0 -and
    [int]$fixture.campaign_seed -eq 23185 -and
    [string]$fixture.cohort -ceq [string]$declaredFixture.cohort -and
    (Test-R23D68Near ([double]$fixture.fixture_vertical_clearance_m) ([double]$declaredFixture.fixture_vertical_clearance_m)) -and
    (Test-R23D68Near ([double]$fixture.fixture_yaw_rad) ([double]$declaredFixture.fixture_yaw_rad)) -and
    (Test-R23D68Near ([double]$fixture.initial_linear_velocity_world_m_s[0]) ([double]$declaredFixture.initial_linear_velocity_world_m_s[0])) -and
    (Test-R23D68Near ([double]$fixture.initial_torso_angular_velocity_world_rad_s[1]) ([double]$declaredFixture.initial_torso_angular_velocity_world_rad_s[1])) -and
    [int]$fixture.gait_phase_offset_ticks -eq 0
) "pure seed fixture changed"

$release = Get-Content -LiteralPath $releaseContractPath -Raw |
    ConvertFrom-Json -AsHashtable -Depth 100
$support = Get-Content -LiteralPath $supportMatrixPath -Raw |
    ConvertFrom-Json -AsHashtable -Depth 100
$turningGate = @($release.gates | Where-Object {
    [string]$_.gate_id -ceq "QSDK-R23"
})[0]
$releaseRecord = $turningGate.proof.
    prospective_r23d68_production_path_conformance_repaired_three_engine_turning_validation
$supportRecord = $support.locomotion_modes.three_engine_turning_production_route.
    current_score_bearing_successor
$nestedSupportRecord = $support.locomotion_modes.heading_command_physical_development.
    scientifically_distinct_successor.stage_zero_successor.terminal_stabilization_successor.
    dependency_closed_successor.policy_compatible_restoration_successor.
    neutral_stance_successor.authorization_closed_successor.scientifically_distinct_successor.
    next_scientifically_distinct_successor.consumed_r23d12_successor.
    prospective_r23d68_production_path_conformance_repaired_three_engine_turning_validation
foreach ($record in @($releaseRecord, $supportRecord, $nestedSupportRecord)) {
    Assert-R23D68 (
        [string]$record.gate_id -ceq "QSDK-R23D68" -and
        [string]$record.campaign_id -ceq $campaignId -and
        [string]$record.status -ceq $declaredStatus -and
        [string]$record.preregistration_path -ceq
            "sdk/turning/r23d68_production_path_conformance_repaired_three_engine_turning_preregistration_v1.json" -and
        [string]$record.preregistration_raw_sha256 -ceq
            (Get-R23D68Sha256 $declarationPath) -and
        [string]$record.declaration_audit_path -ceq
            "tests/test_qsdk_r23d68_preregistration.ps1" -and
        [string]$record.declaration_audit_raw_sha256 -ceq
            (Get-R23D68Sha256 $PSCommandPath) -and
        [int]$record.fresh_seed -eq 23185 -and
        [int]$record.first_rejected_seed -eq 23183 -and
        [int]$record.declared_cell_count -eq 9 -and
        [int]$record.compact_production_path_ghost_count -eq 2 -and
        -not [bool]$record.implementation_complete -and
        -not [bool]$record.physical_campaign_opened -and
        -not [bool]$record.q_sdk_r23_satisfied -and
        -not [bool]$record.physical_acceptance_authority
    ) "release declaration record changed"
}
Assert-R23D68 (
    [string]$turningGate.proof.current_prospective_successor_status -ceq
        $declaredStatus
) "current turning successor pointer changed"

$mutationControls = 0
foreach ($mutation in @(
    @{ path = "physical_question_class"; value = "superiority" },
    @{ path = "scientific_distinction_and_change_budget.fresh_seed"; value = 23181 },
    @{ path = "inherited_behavior_contract.threshold_selector_evaluator_or_interpretation_change_count"; value = 1 },
    @{ path = "production_path_conformance_contract.conformance_margin"; value = 1 },
    @{ path = "compact_development_ghosts.full_seeded_world_required"; value = $true },
    @{ path = "prephysical_requirements.physical_execution_authorized"; value = $true },
    @{ path = "claims.q_sdk_r23_satisfied"; value = $true },
    @{ path = "physical_acceptance_authority"; value = $true }
)) {
    $copy = $declaration | ConvertTo-Json -Depth 100 |
        ConvertFrom-Json -AsHashtable -Depth 100
    $parts = [string]$mutation.path -split '\.'
    $target = $copy
    for ($index = 0; $index -lt $parts.Count - 1; $index++) {
        $target = $target[$parts[$index]]
    }
    $target[$parts[-1]] = $mutation.value
    Assert-R23D68 (-not (Test-R23D68DeclarationVector $copy)) (
        "mutation was accepted: $($mutation.path)"
    )
    $mutationControls += 1
}

Write-Output (
    "[turning/3e] PASS R23D68 prospective declaration: seed=23185 " +
    "rejected_seed_23183_occurrences=7 selected_occurrences=0 cells=9 " +
    "compact_ghosts=2 models=0 worlds=0 mutations=$mutationControls " +
    "turning=False QSDK-R23=False score=10/25"
)
