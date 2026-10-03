#requires -Version 7.0

[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = [System.IO.Path]::GetFullPath(
    (Split-Path -Parent $PSScriptRoot)
)
$expectedRemote = "https://github.com/Slagathore/sporespore.git"
$contractPath = Join-Path (
    $repoRoot
) "sdk\recovery\r24d2_portable_recovery_semantics_v1.json"
$manifestPath = Join-Path (
    $repoRoot
) "sdk\recovery\r24d2_portable_recovery_semantics_validation_manifest.json"
$r24d1Path = Join-Path (
    $repoRoot
) "sdk\recovery\r24d1_canonical_prone_to_standing_design_v1.json"
$corePath = Join-Path $repoRoot "sdk\core\src\recovery.rs"
$rapierPath = Join-Path (
    $repoRoot
) "sdk\adapters\rapier\src\recovery_capability.rs"
$mujocoPath = Join-Path (
    $repoRoot
) "sdk\adapters\mujoco\sporespore_mujoco_adapter\recovery_capability.py"
$godotPath = Join-Path (
    $repoRoot
) "sdk\adapters\godot\gdscript\recovery_capability.gd"
$godotTestPath = Join-Path (
    $repoRoot
) "tests\test_sdk_qsdk_r24d2_godot_recovery_zero_world.gd"
$abiPath = Join-Path $repoRoot "sdk\versioning\c_abi_manifest_v1.json"
$schemaRegistryPath = Join-Path (
    $repoRoot
) "sdk\versioning\schema_registry_v1.json"
$headerPath = Join-Path $repoRoot "sdk\include\sporespore_locomotion.h"
$pythonPath = Join-Path $repoRoot "sdk\python\sporespore_locomotion.py"
$godotExtensionPath = Join-Path $repoRoot "sdk\adapters\godot\src\lib.rs"
$releasePath = Join-Path $repoRoot "sdk\release\quadruped_release_contract.json"
$matrixPath = Join-Path $repoRoot "sdk\release\quadruped_support_matrix.json"

function Assert-R24D2 {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw "QSDK-R24D2: $Message" }
}

function Get-RawSha256 {
    param([Parameter(Mandatory)][string]$Path)
    return "sha256:" + (
        Get-FileHash -Algorithm SHA256 -LiteralPath $Path
    ).Hash.ToLowerInvariant()
}

function Get-GitValue {
    param([Parameter(Mandatory)][string[]]$Arguments)
    $output = @(& git -C $repoRoot @Arguments 2>&1)
    Assert-R24D2 ($LASTEXITCODE -eq 0) (
        "git $($Arguments -join ' ') failed: $($output -join ' | ')"
    )
    return ($output -join "`n").Trim()
}

foreach ($path in @(
    $contractPath,
    $manifestPath,
    $r24d1Path,
    $corePath,
    $rapierPath,
    $mujocoPath,
    $godotPath,
    $godotTestPath,
    $abiPath,
    $schemaRegistryPath,
    $headerPath,
    $pythonPath,
    $godotExtensionPath,
    $releasePath,
    $matrixPath
)) {
    Assert-R24D2 (
        Test-Path -LiteralPath $path -PathType Leaf
    ) "Required source is missing: $path"
}

$root = Get-GitValue @("rev-parse", "--show-toplevel")
$remote = Get-GitValue @("remote", "get-url", "origin")
$branch = Get-GitValue @("branch", "--show-current")
Assert-R24D2 (
    [System.IO.Path]::GetFullPath($root) -ceq $repoRoot
) "Canonical repository root changed: $root"
Assert-R24D2 ($remote -ceq $expectedRemote) "Origin changed: $remote"
Assert-R24D2 ($branch -ceq "main") "Branch changed: $branch"

$contract = Get-Content -Raw -LiteralPath $contractPath |
    ConvertFrom-Json -Depth 100
$manifest = Get-Content -Raw -LiteralPath $manifestPath |
    ConvertFrom-Json -Depth 100
$r24d1 = Get-Content -Raw -LiteralPath $r24d1Path |
    ConvertFrom-Json -Depth 100
$abi = Get-Content -Raw -LiteralPath $abiPath |
    ConvertFrom-Json -Depth 100
$schemaRegistry = Get-Content -Raw -LiteralPath $schemaRegistryPath |
    ConvertFrom-Json -Depth 100
$release = Get-Content -Raw -LiteralPath $releasePath |
    ConvertFrom-Json -Depth 100
$matrix = Get-Content -Raw -LiteralPath $matrixPath |
    ConvertFrom-Json -Depth 100

Assert-R24D2 (
    [string]$contract.schema_version -ceq
        "sporespore_qsdk_r24d2_portable_recovery_semantics_contract_v1" -and
    [string]$contract.gate_id -ceq "QSDK-R24D2" -and
    [string]$contract.work_id -ceq
        "QSDK-R24D2-PORTABLE-RECOVERY-SEMANTICS-AND-CAPABILITY-MAPPINGS" -and
    [string]$contract.release_gate_id -ceq "QSDK-R24" -and
    [string]$contract.status -ceq
        "implemented_partial_native_capability_conjunction_failed_physical_execution_blocked" -and
    [string]$contract.question_class -ceq "non_physical_source_conformance" -and
    [string]$contract.answer -ceq "partial_fail_closed"
) "Contract identity or result changed"

Assert-R24D2 (
    [string]$contract.predecessor.gate_id -ceq "QSDK-R24D1" -and
    [string]$contract.predecessor.source_commit -ceq
        "07aee8b9113026fdf4894ce6b3235a9bbaef7434" -and
    [string]$contract.predecessor.source_tree -ceq
        "5f5af1ae409c5769c243125c035070d931de27d7" -and
    [bool]$contract.predecessor.all_stages_passed -and
    -not [bool]$contract.predecessor.result_reused -and
    [int]$contract.predecessor.true_claim_count -eq 0 -and
    [int]$contract.predecessor.physical_world_count -eq 0 -and
    [string]$contract.predecessor.contract_raw_sha256 -ceq
        (Get-RawSha256 -Path $r24d1Path)
) "Qualified R24D1 predecessor changed"

$scope = $contract.exact_scope
Assert-R24D2 (
    [string]$scope.task_id -ceq
        "sporespore_canonical_ventral_prone_to_four_foot_stance_v1" -and
    [string]$scope.semantics_id -ceq
        "sporespore_qsdk_r24d2_portable_recovery_semantics_v1" -and
    [string]$scope.morphology_id -ceq "qsdk_r05_generated_s169" -and
    [string]$scope.actuator_profile_sha256 -ceq
        "sha256:b65d41e3f30c42e0a8207f1385fe00daa8f03975f4e266a0bd0867970f674964" -and
    -not [bool]$scope.arbitrary_valid_quadruped_support -and
    -not [bool]$scope.continuous_morphology_claim -and
    -not [bool]$scope.morphology_transfer_claim
) "Exact support scope changed"

$semantics = $contract.portable_semantics
$expectedStatuses = @(
    "supported_exact",
    "out_of_domain_morphology",
    "unsupported_profile",
    "unsupported_capability",
    "invalid_observation"
)
$expectedPhases = @(
    "confirm_prone",
    "establish_distal_support",
    "raise_body",
    "stance_handoff",
    "stance_dwell",
    "complete"
)
$expectedChannels = @(
    "canonical_body_pose_and_twist",
    "whole_system_center_of_mass_position_and_velocity",
    "ordered_joint_position_and_velocity",
    "ordered_foot_bearing_contact_observations",
    "classified_nonfoot_contact_observations",
    "applied_actuation_receipts",
    "external_intervention_ledger",
    "controller_ownership_receipt",
    "energy_balance_ledger",
    "engine_step_identity"
)
Assert-R24D2 (
    [bool]$semantics.observation_schema_implemented -and
    [bool]$semantics.pose_and_contact_classifier_implemented -and
    [bool]$semantics.ordered_phase_supervisor_implemented -and
    [bool]$semantics.candidate_and_matched_zero_evaluator_implemented -and
    [bool]$semantics.content_addressed_capability_receipts_implemented -and
    (@($semantics.typed_support_statuses) -join "|") -ceq
        ($expectedStatuses -join "|") -and
    (@($semantics.ordered_success_phases) -join "|") -ceq
        ($expectedPhases -join "|") -and
    (@($semantics.required_observation_channels) -join "|") -ceq
        ($expectedChannels -join "|") -and
    [int]$semantics.exact_zero_no_cheat_counter_count -eq 13 -and
    [int]$semantics.declared_negative_control_count -eq 12 -and
    [int]$semantics.declared_negative_controls_passed -eq 12 -and
    [bool]$semantics.invalid_nonfinite_observation_rejected -and
    [bool]$semantics.published_actuator_budget_violation_rejected -and
    -not [bool]$semantics.controller_implemented -and
    -not [bool]$semantics.control_output_produced
) "Portable semantics boundary changed"

$canary = $contract.synthetic_canary
Assert-R24D2 (
    [string]$canary.threshold_profile_sha256 -ceq
        "sha256:f65bd581151f1a631901415afd4bc533289afa88e8db7d840b5108772384a8f6" -and
    [int]$canary.abstract_capability_identity_count -eq 3 -and
    [bool]$canary.candidate_path_completed_for_all_abstract_capability_identities -and
    [bool]$canary.matched_zero_failed_to_complete_for_all_abstract_capability_identities -and
    -not [bool]$canary.abstract_capability_fixture_is_native_adapter_support_proof -and
    -not [bool]$canary.native_observation_collector_executed -and
    -not [bool]$canary.physical_threshold_authority -and
    -not [bool]$canary.physical_execution_permitted -and
    -not [bool]$canary.population_claim -and
    -not [bool]$canary.release_authority
) "Synthetic canary was promoted or changed"

$conjunction = $contract.native_capability_conjunction
Assert-R24D2 (
    [int]$conjunction.required_engine_count -eq 3 -and
    [int]$conjunction.required_channel_count_per_engine -eq 10 -and
    [bool]$conjunction.every_required_engine_must_support_every_required_channel -and
    -not [bool]$conjunction.complete -and
    [string]$conjunction.blocking_engine -ceq "godot_jolt4_7" -and
    (@($conjunction.blocking_channels) -join "|") -ceq
        "applied_actuation_receipts|energy_balance_ledger" -and
    -not [bool]$conjunction.missing_channel_synthesis_permitted -and
    -not [bool]$conjunction.engine_specific_policy_branching_permitted -and
    -not [bool]$conjunction.native_runtime_observation_collection_executed -and
    -not [bool]$conjunction.native_runtime_controller_executed -and
    [int]$conjunction.physical_world_count -eq 0
) "Three-engine capability conjunction no longer fails closed"

$rapier = $contract.adapter_capabilities.rapier_parry_native
$mujoco = $contract.adapter_capabilities.mujoco_native
$godot = $contract.adapter_capabilities.godot_jolt4_7
Assert-R24D2 (
    [int]$rapier.required_channel_count -eq 10 -and
    [int]$rapier.supported_channel_count -eq 10 -and
    [int]$rapier.unsupported_channel_count -eq 0 -and
    [bool]$rapier.compile_time_native_api_surface_present -and
    [int]$rapier.capability_mutation_rejection_count -eq 4 -and
    -not [bool]$rapier.native_runtime_observation_collection_implemented -and
    -not [bool]$rapier.native_runtime_observation_collection_executed -and
    -not [bool]$rapier.physical_support_claimed
) "Rapier source-capability boundary changed"
Assert-R24D2 (
    [int]$mujoco.required_channel_count -eq 10 -and
    [int]$mujoco.supported_channel_count -eq 10 -and
    [int]$mujoco.unsupported_channel_count -eq 0 -and
    [bool]$mujoco.force_to_impulse_integration_rule_explicit -and
    -not [bool]$mujoco.force_sample_relabelled_as_impulse -and
    [int]$mujoco.capability_mutation_rejection_count -eq 4 -and
    [int]$mujoco.mujoco_import_count -eq 0 -and
    -not [bool]$mujoco.native_runtime_observation_collection_implemented -and
    -not [bool]$mujoco.native_runtime_observation_collection_executed -and
    -not [bool]$mujoco.physical_support_claimed
) "MuJoCo source-capability boundary changed"
Assert-R24D2 (
    [int]$godot.required_channel_count -eq 10 -and
    [int]$godot.supported_channel_count -eq 8 -and
    [int]$godot.unsupported_channel_count -eq 2 -and
    (@($godot.unsupported_channels) -join "|") -ceq
        "applied_actuation_receipts|energy_balance_ledger" -and
    [string]$godot.typed_support_status -ceq "unsupported_capability" -and
    [bool]$godot.contact_impulse_api_reachable -and
    -not [bool]$godot.solved_hinge_motor_impulse_public_api_reachable -and
    -not [bool]$godot.solved_actuator_work_public_api_reachable -and
    -not [bool]$godot.configured_motor_limit_relabelled_as_applied_impulse -and
    [bool]$godot.false_capability_promotion_rejected -and
    [bool]$godot.missing_channel_rejected -and
    [bool]$godot.synthesized_channel_rejected -and
    -not [bool]$godot.native_runtime_observation_collection_implemented -and
    -not [bool]$godot.native_runtime_observation_collection_executed -and
    -not [bool]$godot.physical_support_claimed
) "Godot typed partial capability/refusal changed"

$physical = $contract.physical_threshold_and_cohort_boundary
Assert-R24D2 (
    [int]$physical.registered_physical_threshold_count -eq 16 -and
    [int]$physical.set_physical_threshold_count -eq 0 -and
    -not [bool]$physical.synthetic_canary_thresholds_count_as_physical_thresholds -and
    [bool]$physical.every_physical_threshold_requires_explicit_provenance -and
    [bool]$physical.every_physical_threshold_requires_adequacy_argument -and
    -not [bool]$physical.development_cohort_declared -and
    -not [bool]$physical.held_out_native_validation_cohort_declared -and
    [bool]$physical.every_cohort_requires_explicit_provenance -and
    [bool]$physical.every_cohort_requires_adequacy_argument -and
    [string]$physical.development_question_class -ceq "development" -and
    [string]$physical.held_out_native_validation_question_class -ceq
        "finite_decision" -and
    -not [bool]$physical.physical_question_opened -and
    -not [bool]$physical.physical_campaign_opened
) "Physical threshold, cohort, or question boundary changed"

$zeroWorld = $contract.complete_zero_world_program
foreach ($field in @(
    "r24d1_design_declaration_gate_passed",
    "portable_observation_schema_implemented",
    "portable_pose_classifier_implemented",
    "portable_phase_supervisor_implemented",
    "portable_result_evaluator_implemented",
    "c_abi_and_host_bindings_implemented",
    "rapier_capability_mapping_implemented",
    "mujoco_capability_mapping_implemented",
    "godot_capability_mapping_implemented",
    "all_declared_negative_controls_passed"
)) {
    Assert-R24D2 ([bool]$zeroWorld.$field) "Zero-world implementation missing: $field"
}
foreach ($field in @(
    "all_required_native_capabilities_supported",
    "thresholds_and_cohorts_frozen",
    "controller_implemented",
    "complete_prephysical_gate_passed",
    "clean_pushed_qualification_passed",
    "separate_adoption_passed",
    "physics_state_modified"
)) {
    Assert-R24D2 (-not [bool]$zeroWorld.$field) "Zero-world boundary promoted: $field"
}
foreach ($field in @(
    "model_construction_count",
    "world_attempt_count",
    "world_build_count",
    "solver_step_count"
)) {
    Assert-R24D2 ([int64]$zeroWorld.$field -eq 0) "Zero-world count changed: $field"
}

$claims = $contract.claim_boundary
foreach ($field in @(
    "portable_semantics_implemented",
    "native_source_mappings_implemented"
)) {
    Assert-R24D2 ([bool]$claims.$field) "Implemented source claim missing: $field"
}
foreach ($property in $claims.PSObject.Properties) {
    if ($property.Name -notin @(
        "portable_semantics_implemented",
        "native_source_mappings_implemented"
    )) {
        Assert-R24D2 (-not [bool]$property.Value) (
            "Unlicensed claim became true: $($property.Name)"
        )
    }
}
Assert-R24D2 (
    [int]$contract.release_boundary.passed_gate_count -eq 10 -and
    [int]$contract.release_boundary.total_gate_count -eq 25 -and
    -not [bool]$contract.release_boundary.release_ready -and
    -not [bool]$contract.release_boundary.q_sdk_r24_satisfied -and
    -not [bool]$contract.next_permitted_work.physical_world_permitted_now
) "Release or next-work boundary changed"

$coreText = Get-Content -Raw -LiteralPath $corePath
foreach ($required in @(
    "pub struct RecoveryObservationV1",
    "pub fn initialize_recovery_v1",
    "pub fn step_recovery_v1",
    "pub fn evaluate_recovery_trace_v1",
    "exact_twelve_declared_negative_controls_fail_closed",
    "synthetic_threshold_profile_is_content_addressed_and_never_physical",
    "sporespore_qsdk_r24d2_synthetic_zero_world_canary_thresholds_v1"
)) {
    Assert-R24D2 (
        $coreText.Contains($required, [StringComparison]::Ordinal)
    ) "Core implementation marker missing: $required"
}

$rapierText = Get-Content -Raw -LiteralPath $rapierPath
foreach ($required in @(
    "rapier_recovery_capability_v1",
    "run_recovery_capability_preflight",
    "compile_time_native_api_surface_present",
    "native_runtime_observation_collection_executed"
)) {
    Assert-R24D2 (
        $rapierText.Contains($required, [StringComparison]::Ordinal)
    ) "Rapier capability marker missing: $required"
}
$mujocoText = Get-Content -Raw -LiteralPath $mujocoPath
foreach ($required in @(
    "mujoco_recovery_capability_v1",
    "run_recovery_capability_preflight",
    "force_sample_relabelled_as_impulse",
    "native_runtime_observation_collection_executed"
)) {
    Assert-R24D2 (
        $mujocoText.Contains($required, [StringComparison]::Ordinal)
    ) "MuJoCo capability marker missing: $required"
}
Assert-R24D2 (
    -not $mujocoText.Contains("import mujoco", [StringComparison]::Ordinal) -and
    -not $mujocoText.Contains("from mujoco", [StringComparison]::Ordinal)
) "MuJoCo zero-world mapping imported the native runtime"

$godotText = Get-Content -Raw -LiteralPath $godotPath
$godotTestText = Get-Content -Raw -LiteralPath $godotTestPath
foreach ($required in @(
    "PhysicsDirectBodyState3D.get_contact_impulse",
    "unsupported_no_public_post_solver_hinge_motor_impulse_readback_v1",
    "unsupported_energy_balance_requires_solved_actuator_work_v1",
    '"applied_actuation_receipts"',
    '"energy_balance_ledger"'
)) {
    Assert-R24D2 (
        $godotText.Contains($required, [StringComparison]::Ordinal)
    ) "Godot capability marker missing: $required"
}
foreach ($required in @(
    '"supported_channel_count": 8',
    '"unsupported_channel_count": 2',
    "false_promotion_rejected",
    "typed_refusal_status"
)) {
    Assert-R24D2 (
        $godotTestText.Contains($required, [StringComparison]::Ordinal)
    ) "Godot executable refusal marker missing: $required"
}

$newSymbols = @(
    [ordered]@{
        name = "ss_recovery_initialize_v1_json"
        schema = "sporespore_recovery_initialize_request_v1"
    },
    [ordered]@{
        name = "ss_recovery_step_v1_json"
        schema = "sporespore_recovery_step_request_v1"
    },
    [ordered]@{
        name = "ss_recovery_evaluate_trace_v1_json"
        schema = "sporespore_recovery_evaluation_request_v1"
    }
)
Assert-R24D2 (@($abi.symbols).Count -eq 32) "C ABI symbol count changed"
Assert-R24D2 (
    @($schemaRegistry.schemas).Count -eq 47 -and
    [int]$contract.abi_and_host_surfaces.schema_registry_entry_count -eq 47
) "Schema registry count changed"
$headerText = Get-Content -Raw -LiteralPath $headerPath
$pythonText = Get-Content -Raw -LiteralPath $pythonPath
$godotExtensionText = Get-Content -Raw -LiteralPath $godotExtensionPath
foreach ($expected in $newSymbols) {
    $matches = @($abi.symbols | Where-Object {
        [string]$_.name -ceq [string]$expected.name
    })
    Assert-R24D2 (
        $matches.Count -eq 1 -and
        [string]$matches[0].signature_class -ceq "json_input_buffer_v1" -and
        [string]$matches[0].status -ceq "active" -and
        [string]$matches[0].input_schema -ceq [string]$expected.schema -and
        $headerText.Contains([string]$expected.name, [StringComparison]::Ordinal) -and
        $pythonText.Contains([string]$expected.name, [StringComparison]::Ordinal)
    ) "C ABI binding changed: $($expected.name)"
}
foreach ($method in @(
    "recovery_initialize_v1_json",
    "recovery_step_v1_json",
    "recovery_evaluate_trace_v1_json"
)) {
    Assert-R24D2 (
        $godotExtensionText.Contains($method, [StringComparison]::Ordinal)
    ) "Godot GDExtension binding missing: $method"
}
$registeredSchemaIds = @(
    $schemaRegistry.schemas | ForEach-Object { [string]$_.schema_id }
)
foreach ($expected in $newSymbols) {
    Assert-R24D2 (
        [string]$expected.schema -cin $registeredSchemaIds
    ) "Recovery schema is not registered: $($expected.schema)"
}

$r24Gate = @($release.gates | Where-Object {
    [string]$_.gate_id -ceq "QSDK-R24"
})
Assert-R24D2 (
    $r24Gate.Count -eq 1 -and
    [string]$r24Gate[0].proof.kind -ceq "missing" -and
    [string]$r24Gate[0].proof.active_zero_world_boundary.gate_id -ceq
        "QSDK-R24D2" -and
    -not [bool]$r24Gate[0].proof.active_zero_world_boundary.native_capability_conjunction_complete -and
    [int]$r24Gate[0].proof.active_zero_world_boundary.godot_supported_channel_count -eq 8 -and
    [int]$r24Gate[0].proof.active_zero_world_boundary.godot_required_channel_count -eq 10 -and
    -not [bool]$r24Gate[0].proof.active_zero_world_boundary.complete_prephysical_gate_passed -and
    [int]$r24Gate[0].proof.active_zero_world_boundary.world_build_count -eq 0 -and
    -not [bool]$r24Gate[0].proof.active_zero_world_boundary.q_sdk_r24_satisfied -and
    -not [bool]$r24Gate[0].proof.active_zero_world_boundary.release_authority
) "Live QSDK-R24 release refusal changed"

$matrixR24 = $matrix.locomotion_modes.canonical_prone_to_standing_design
Assert-R24D2 (
    [string]$matrixR24.gate_id -ceq "QSDK-R24D2" -and
    [bool]$matrixR24.portable_observation_schema_implemented -and
    [bool]$matrixR24.portable_pose_classifier_implemented -and
    [bool]$matrixR24.portable_phase_supervisor_implemented -and
    [bool]$matrixR24.portable_result_evaluator_implemented -and
    [bool]$matrixR24.adapter_capability_mappings_implemented -and
    [int]$matrixR24.godot_supported_channel_count -eq 8 -and
    [int]$matrixR24.godot_unsupported_channel_count -eq 2 -and
    -not [bool]$matrixR24.native_capability_conjunction_complete -and
    -not [bool]$matrixR24.complete_prephysical_gate_passed -and
    [int]$matrixR24.world_build_count -eq 0 -and
    -not [bool]$matrixR24.prone_to_standing -and
    -not [bool]$matrixR24.q_sdk_r24_satisfied -and
    -not [bool]$matrixR24.release_authority
) "Support-matrix R24D2 boundary changed"

$expectedManifestPaths = @(
    ".gitattributes",
    "sdk/closure_evidence_provenance_contract.json",
    "tests/test_closure_evidence_provenance_contract.ps1",
    "sdk/core/src/recovery.rs",
    "sdk/core/src/lib.rs",
    "sdk/core/src/ffi.rs",
    "sdk/include/sporespore_locomotion.h",
    "sdk/python/sporespore_locomotion.py",
    "sdk/versioning/c_abi_manifest_v1.json",
    "sdk/versioning/schema_registry_v1.json",
    "sdk/versioning/test_conformance.py",
    "sdk/versioning/README.md",
    "sdk/adapters/rapier/src/recovery_capability.rs",
    "sdk/adapters/rapier/src/lib.rs",
    "sdk/adapters/mujoco/sporespore_mujoco_adapter/recovery_capability.py",
    "sdk/adapters/mujoco/test_recovery_capability.py",
    "sdk/adapters/godot/gdscript/recovery_capability.gd",
    "sdk/adapters/godot/src/lib.rs",
    "tests/test_sdk_qsdk_r24d2_godot_recovery_zero_world.gd",
    "sdk/recovery/r24d2_portable_recovery_semantics_v1.json",
    "tests/test_qsdk_r24d2_portable_recovery_semantics.ps1",
    "sdk/run_qsdk_r24d2_zero_world_gate.ps1",
    "sdk/run_conformance.ps1",
    "sdk/recovery/README.md",
    "sdk/release/README.md",
    "sdk/release/quadruped_release_contract.json",
    "sdk/release/quadruped_support_matrix.json",
    "sdk/test_quadruped_sdk_release_readiness.ps1",
    "docs/README.md",
    "docs/ENGINE_NEUTRAL_LOCOMOTION_SDK_BOOTSTRAP.md",
    "docs/SDK_PORTABLE_BALANCED_WAVE_SUCCESSOR_BOOTSTRAP.md",
    "docs/LOCOMOTION_ARCHITECTURE.md",
    "docs/LOCOMOTION_GROUND_UP_RESEARCH_PROGRAM.md"
)
$bindings = @($manifest.source_bindings)
$bindingPaths = @($bindings | ForEach-Object { [string]$_.path })
Assert-R24D2 (
    [string]$manifest.schema_version -ceq
        "sporespore_qsdk_r24d2_validation_manifest_v1" -and
    [string]$manifest.gate_id -ceq "QSDK-R24D2" -and
    [int]$manifest.source_binding_count -eq $expectedManifestPaths.Count -and
    $bindings.Count -eq $expectedManifestPaths.Count -and
    (@($bindingPaths | Select-Object -Unique)).Count -eq $bindingPaths.Count -and
    ($bindingPaths -join "|") -ceq ($expectedManifestPaths -join "|") -and
    -not [bool]$manifest.includes_self -and
    [int]$manifest.world_build_count -eq 0 -and
    -not [bool]$manifest.physical_acceptance_authority -and
    -not [bool]$manifest.release_authority
) "Validation manifest shape changed"
foreach ($binding in $bindings) {
    $relative = [string]$binding.path
    $absolute = Join-Path $repoRoot $relative
    Assert-R24D2 (
        Test-Path -LiteralPath $absolute -PathType Leaf
    ) "Manifest source missing: $relative"
    $bytes = [System.IO.File]::ReadAllBytes($absolute)
    Assert-R24D2 (
        [string]$binding.raw_sha256 -ceq (Get-RawSha256 -Path $absolute) -and
        [int64]$binding.byte_length -eq $bytes.LongLength
    ) "Manifest source binding drifted: $relative"
}

$report = [ordered]@{
    schema_version = "sporespore_qsdk_r24d2_source_audit_receipt_v1"
    ok = $true
    gate_id = "QSDK-R24D2"
    question_class = "non_physical_source_conformance"
    result = "partial_fail_closed"
    portable_semantics_implemented = $true
    required_engine_count = 3
    required_channel_count_per_engine = 10
    rapier_supported_channel_count = 10
    mujoco_supported_channel_count = 10
    godot_supported_channel_count = 8
    godot_unsupported_channel_count = 2
    godot_typed_refusal = $true
    native_capability_conjunction_complete = $false
    negative_control_count = 12
    negative_controls_passed = 12
    source_binding_count = $bindings.Count
    c_abi_symbol_count = @($abi.symbols).Count
    set_physical_threshold_count = 0
    controller_implemented = $false
    native_runtime_observation_collection_executed = $false
    model_construction_count = 0
    world_attempt_count = 0
    world_build_count = 0
    solver_step_count = 0
    physics_state_modified = $false
    physical_question_opened = $false
    prone_to_standing_claimed = $false
    cross_engine_equivalence_claimed = $false
    q_sdk_r24_satisfied = $false
    physical_acceptance_authority = $false
    release_authority = $false
}
Write-Output (
    "QSDK_R24D2_PORTABLE_RECOVERY_SEMANTICS_PASS " +
    ($report | ConvertTo-Json -Depth 20 -Compress)
)
