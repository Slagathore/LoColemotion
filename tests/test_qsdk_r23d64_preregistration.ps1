[CmdletBinding()]
param(
    [string]$Python = "python",
    [string]$Godot = (
        "C:\Users\Cole\CodeStuff\Misc\Godot\" +
        "Godot_v4.7-stable_mono_win64_console.exe"
    ),
    [switch]$SkipGodot
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$expectedRoot = [IO.Path]::GetFullPath(
    "C:\Users\Cole\CodeStuff\games\SporeSpore"
)
$expectedRemote = "https://github.com/Slagathore/sporespore.git"
$declarationPath = Join-Path $repoRoot (
    "sdk\turning\r23d64_selected_profile_three_engine_turning_validation_" +
    "preregistration_v1.json"
)
$designPath = Join-Path $repoRoot (
    "sdk\turning\r23d64_selected_profile_three_engine_turning_validation.py"
)
$seedCompilerPath = Join-Path $repoRoot (
    "sdk\turning\r23d64_seed_fixture_compiler.gd"
)
$predecessorClosurePath = Join-Path $repoRoot (
    "sdk\turning\r23d63_selected_profile_three_engine_turning_validation_" +
    "closure_v1.json"
)
$predecessorAuditPath = Join-Path $repoRoot (
    "tests\test_qsdk_r23d63_physical_closure.ps1"
)
$receiptSchemaGatePath = Join-Path $repoRoot (
    "tests\test_qsdk_r23d64_authorization_receipt_schema.ps1"
)
$launcherContractPath = Join-Path $repoRoot (
    "sdk\turning\r23d64_rapier_launcher_contract.ps1"
)
$launcherGatePath = Join-Path $repoRoot (
    "tests\test_qsdk_r23d64_rapier_launcher_contract.ps1"
)

function Assert-R23D64Preregistration {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) {
        throw "QSDK-R23D64 preregistration audit failed: $Message"
    }
}

function Get-R23D64PreregistrationSha256 {
    param([Parameter(Mandatory)][string]$Path)
    return (
        "sha256:" +
        (Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash.ToLowerInvariant()
    )
}

Assert-R23D64Preregistration ($repoRoot -ceq $expectedRoot) (
    "repository root changed: $repoRoot"
)
$gitRoot = [IO.Path]::GetFullPath(
    (& git -C $repoRoot rev-parse --show-toplevel).Trim()
)
$remote = (& git -C $repoRoot remote get-url origin).Trim()
Assert-R23D64Preregistration (
    $LASTEXITCODE -eq 0 -and
    $gitRoot -ceq $expectedRoot -and
    $remote -ceq $expectedRemote
) "canonical repository identity changed"
foreach ($path in @(
    $declarationPath,
    $designPath,
    $seedCompilerPath,
    $predecessorClosurePath,
    $predecessorAuditPath,
    $receiptSchemaGatePath,
    $launcherContractPath,
    $launcherGatePath
)) {
    Assert-R23D64Preregistration (Test-Path -LiteralPath $path -PathType Leaf) (
        "required source is missing: $path"
    )
}

$declaration = Get-Content -Raw -LiteralPath $declarationPath |
    ConvertFrom-Json -AsHashtable -Depth 100
$parentCommit = [string]$declaration.immutable_lineage.declaration_parent_commit
$parentTree = (& git -C $repoRoot rev-parse "$parentCommit^{tree}").Trim()
Assert-R23D64Preregistration (
    $LASTEXITCODE -eq 0 -and
    $parentCommit -ceq "3d48f06dd22825c5aef7c638e64eb1788023795a" -and
    $parentTree -ceq "4859d20946afe479539c93acccfb0287aa1078dc"
) "declaration parent identity changed"

$seedOccurrences = @(
    & git -C $repoRoot grep -n -E `
        "(^|[^0-9A-Za-z])23171([^0-9A-Za-z]|$)|23_171" `
        $parentCommit -- . 2>$null
)
$seedGrepExit = $LASTEXITCODE
Assert-R23D64Preregistration (
    $seedGrepExit -eq 1 -and
    $seedOccurrences.Count -eq 0 -and
    [int]$declaration.immutable_lineage.r23d64_seed_identity_occurrence_count_at_parent_commit -eq 0 -and
    -not [bool]$declaration.immutable_lineage.r23d64_seed_had_prior_repository_occurrence
) "fresh seed identity was not absent at the declaration parent"

$predecessor = $declaration.predecessor_closure
$receiptContract = $declaration.authorization_receipt_schema_conformance
$launcherContract = $declaration.rapier_launcher_contract_conformance
$changeBudget = $declaration.successor_change_budget
$matrix = $declaration.frozen_matrix
$gates = $declaration.frozen_common_physical_gates
$decision = $declaration.finite_decision_rule
$requirements = $declaration.implementation_and_execution_requirements
$controls = $declaration.required_zero_world_negative_controls
Assert-R23D64Preregistration (
    [string]$declaration.schema_version -ceq
        "sporespore_qsdk_r23d64_selected_profile_three_engine_turning_validation_preregistration_v1" -and
    [string]$declaration.status -ceq "prospective_zero_world_only_physical_not_opened" -and
    [string]$declaration.gate_id -ceq "QSDK-R23D64" -and
    [string]$declaration.question_class -ceq "finite_decision" -and
    [bool]$declaration.physical_question_declared -and
    -not [bool]$declaration.physical_campaign_opened -and
    [string]$predecessor.gate_id -ceq "QSDK-R23D63" -and
    [string]$predecessor.campaign_id -ceq
        "QSDK-R23D63-RECEIPT-SCHEMA-REPAIRED-SELECTED-PROFILE-MATCHED-THREE-ENGINE-TURNING-VALIDATION" -and
    [string]$predecessor.classification -ceq
        "invalid_or_incomplete_exact_matched_three_engine_portable_turning_validation" -and
    [bool]$predecessor.campaign_identity_consumed -and
    -not [bool]$predecessor.physical_outcome_exposed -and
    [int]$predecessor.world_attempt_count -eq 0 -and
    -not [bool]$predecessor.same_identity_repair_or_rerun_permitted -and
    [string]$predecessor.closure_raw_sha256 -ceq
        (Get-R23D64PreregistrationSha256 $predecessorClosurePath) -and
    [string]$predecessor.closure_audit_raw_sha256 -ceq
        (Get-R23D64PreregistrationSha256 $predecessorAuditPath) -and
    @($changeBudget.allowed_mechanism_changes).Count -eq 4 -and
    [bool]$changeBudget.selected_public_profile_preserved -and
    [bool]$changeBudget.controller_and_policy_semantics_preserved -and
    [bool]$changeBudget.physics_and_native_engine_bindings_preserved -and
    [bool]$changeBudget.common_physical_thresholds_preserved -and
    [bool]$changeBudget.turning_thresholds_preserved -and
    [bool]$changeBudget.selector_evaluator_and_interpretation_preserved -and
    [string]$receiptContract.question_class -ceq "equivalence_non_inferiority" -and
    [int]$receiptContract.declared_producer_count -eq 3 -and
    [int]$receiptContract.required_conforming_producer_count -eq 3 -and
    [string]$receiptContract.required_field -ceq
        "complete_ordered_nine_cell_matrix_validated" -and
    [string]$receiptContract.required_json_type -ceq "boolean" -and
    $receiptContract.required_value -is [bool] -and
    [bool]$receiptContract.required_value -and
    [int]$receiptContract.equivalence_margin -eq 0 -and
    [int]$receiptContract.non_inferiority_margin -eq 0 -and
    -not [bool]$receiptContract.sampling_used -and
    [int]$receiptContract.total_negative_control_count -eq 12 -and
    [bool]$receiptContract.must_pass_before_physical_freeze -and
    [bool]$receiptContract.must_pass_before_attempt_authorization -and
    -not [bool]$receiptContract.physical_equivalence_claimed -and
    [string]$launcherContract.question_class -ceq "equivalence_non_inferiority" -and
    [string]$launcherContract.population -ceq
        "complete_two_supervisor_rapier_production_call_sites" -and
    [int]$launcherContract.declared_call_site_count -eq 2 -and
    [int]$launcherContract.required_conforming_call_site_count -eq 2 -and
    [int]$launcherContract.required_shared_builder_count -eq 1 -and
    [string]$launcherContract.required_seed_option -ceq "--seed" -and
    [string]$launcherContract.forbidden_seed_alias -ceq "--campaign-seed" -and
    [int]$launcherContract.exact_vectors_executed_through_production_parser -eq 2 -and
    [int]$launcherContract.required_parser_negative_control_count -eq 6 -and
    [int]$launcherContract.equivalence_margin -eq 0 -and
    [int]$launcherContract.non_inferiority_margin -eq 0 -and
    -not [bool]$launcherContract.sampling_used -and
    [bool]$launcherContract.must_pass_before_physical_freeze -and
    [bool]$launcherContract.must_pass_before_attempt_authorization -and
    -not [bool]$launcherContract.physical_equivalence_claimed -and
    [int]$matrix.declared_cell_count -eq 9 -and
    [int]$matrix.declared_world_count -eq 9 -and
    [int]$matrix.seed -eq 23171 -and
    @($matrix.cells).Count -eq 9 -and
    [double]$gates.minimum_final_forward_displacement_m -eq 0.030123046875 -and
    [double]$gates.maximum_tilt_rad -eq 0.6 -and
    [double]$gates.minimum_torso_height_m -eq 0.2499708652072946 -and
    [double]$declaration.cycle_integrated_measurement.minimum_raw_signed_cycle_shift_rad -eq 0.01 -and
    [double]$declaration.cycle_integrated_measurement.minimum_reference_conditioned_cycle_shift_rad -eq 0.01 -and
    [bool]$decision.complete_execution_valid_nine_cell_matrix_required -and
    [bool]$decision.all_nine_cells_must_pass_every_common_physical_gate -and
    [bool]$decision.positive_qsdk_r23_transition_permitted -and
    -not [bool]$decision.positive_cross_engine_equivalence -and
    -not [bool]$decision.early_stop_or_selective_rerun_permitted -and
    [bool]$requirements.authorization_receipt_schema_conformance_gate_required -and
    [bool]$requirements.authorization_receipt_schema_conformance_gate_must_precede_freeze -and
    [bool]$requirements.authorization_receipt_schema_conformance_gate_must_precede_attempt_authorization -and
    [bool]$requirements.rapier_launcher_contract_conformance_gate_required -and
    [bool]$requirements.rapier_launcher_complete_call_site_population_required -and
    [bool]$requirements.rapier_launcher_exact_vectors_must_reach_production_parser_before_freeze -and
    [bool]$requirements.rapier_launcher_contract_gate_must_precede_attempt_authorization -and
    [bool]$controls.authorization_receipt_complete_matrix_field_missing_rejected_per_engine -and
    [bool]$controls.authorization_receipt_complete_matrix_field_false_rejected_per_engine -and
    [bool]$controls.authorization_receipt_complete_matrix_field_wrong_type_rejected_per_engine -and
    [bool]$controls.authorization_receipt_complete_matrix_field_alias_rejected_per_engine -and
    [bool]$controls.rapier_campaign_seed_alias_rejected_for_authorization_and_physical_vectors -and
    [bool]$controls.rapier_duplicate_seed_rejected -and
    [bool]$controls.rapier_missing_seed_rejected -and
    [bool]$controls.rapier_wrong_type_seed_rejected -and
    [bool]$controls.rapier_underscore_seed_alias_rejected -and
    -not [bool]$declaration.claims.r23d64_complete_zero_world_gate_passed -and
    -not [bool]$declaration.claims.r23d64_physical_campaign_opened -and
    -not [bool]$declaration.claims.q_sdk_r23_satisfied -and
    -not [bool]$declaration.claims.release_authorized
) "prospective declaration contract changed"

$designOutput = @(& $Python $designPath 2>&1)
Assert-R23D64Preregistration ($LASTEXITCODE -eq 0) (
    "declaration validator failed`n" +
    ($designOutput -join [Environment]::NewLine)
)
$designMarker = @($designOutput | Where-Object {
    ([string]$_).StartsWith("QSDK_R23D64_DECLARATION_PASS ")
})
Assert-R23D64Preregistration ($designMarker.Count -eq 1) (
    "declaration validator marker changed"
)
$designReceipt = ([string]$designMarker[0]).Substring(
    "QSDK_R23D64_DECLARATION_PASS ".Length
) | ConvertFrom-Json -AsHashtable -Depth 100
Assert-R23D64Preregistration (
    [int]$designReceipt.mutation_rejection_count -eq 51 -and
    [int]$designReceipt.cell_count -eq 9 -and
    [int]$designReceipt.reserved_seed -eq 23171 -and
    [int]$designReceipt.model_construction_count -eq 0 -and
    [int]$designReceipt.world_attempt_count -eq 0 -and
    [int]$designReceipt.world_build_count -eq 0 -and
    -not [bool]$designReceipt.physical_campaign_opened -and
    -not [bool]$designReceipt.physical_acceptance_authority
) "declaration validator receipt changed"

$closureOutput = @(
    & pwsh -NoLogo -NoProfile -File $predecessorAuditPath 2>&1
)
Assert-R23D64Preregistration (
    $LASTEXITCODE -eq 0 -and
    @($closureOutput | Where-Object {
        ([string]$_).StartsWith("QSDK_R23D63_PHYSICAL_CLOSURE_PASS ")
    }).Count -eq 1
) (
    "immutable R23D63 closure replay failed`n" +
    ($closureOutput -join [Environment]::NewLine)
)

$godotCompilerRun = $false
if (-not $SkipGodot) {
    Assert-R23D64Preregistration (Test-Path -LiteralPath $Godot -PathType Leaf) (
        "Godot executable missing: $Godot"
    )
    $godotOutput = @(
        & $Godot --headless --path $repoRoot --script `
            "res://sdk/turning/r23d64_seed_fixture_compiler.gd" 2>&1
    )
    Assert-R23D64Preregistration ($LASTEXITCODE -eq 0) (
        "Godot seed compiler failed`n" +
        ($godotOutput -join [Environment]::NewLine)
    )
    $seedMarker = @($godotOutput | Where-Object {
        ([string]$_).StartsWith("QSDK_R23D64_SEED_FIXTURES ")
    })
    Assert-R23D64Preregistration ($seedMarker.Count -eq 1) (
        "Godot seed compiler marker changed"
    )
    $seedReceipt = ([string]$seedMarker[0]).Substring(
        "QSDK_R23D64_SEED_FIXTURES ".Length
    ) | ConvertFrom-Json -AsHashtable -Depth 100
    $fixture = @($seedReceipt.fixtures)[0]
    Assert-R23D64Preregistration (
        @($seedReceipt.fixtures).Count -eq 1 -and
        [int]$fixture.campaign_seed -eq 23171 -and
        [double]$fixture.fixture_vertical_clearance_m -eq 0.00019987707491964102 -and
        [double]$fixture.fixture_yaw_rad -eq -0.0002881120890378952 -and
        @($fixture.initial_linear_velocity_world_m_s).Count -eq 3 -and
        [double]$fixture.initial_linear_velocity_world_m_s[0] -eq -0.0008049334865063429 -and
        [double]$fixture.initial_linear_velocity_world_m_s[1] -eq 0.0 -and
        [double]$fixture.initial_linear_velocity_world_m_s[2] -eq -0.0012137130834162235 -and
        @($fixture.initial_torso_angular_velocity_world_rad_s).Count -eq 3 -and
        [double]$fixture.initial_torso_angular_velocity_world_rad_s[0] -eq 0.0019662503618746996 -and
        [double]$fixture.initial_torso_angular_velocity_world_rad_s[1] -eq 0.0014073625206947327 -and
        [double]$fixture.initial_torso_angular_velocity_world_rad_s[2] -eq 0.0009790030308067799 -and
        [int]$fixture.gait_phase_offset_ticks -eq -2 -and
        [int]$seedReceipt.model_construction_count -eq 0 -and
        [int]$seedReceipt.world_attempt_count -eq 0 -and
        [int]$seedReceipt.world_build_count -eq 0
    ) "Godot seed compiler output changed"
    $godotCompilerRun = $true
}

Write-Output (
    "QSDK_R23D64_PREREGISTRATION_PASS " +
    "cells=9 seed=23171 declaration_mutations=51 receipt_producers=3 " +
    "receipt_negative_controls=12 launcher_call_sites=2 launcher_negatives=6 " +
    "seed_occurrences_at_parent=0 " +
    "godot_compiler=$godotCompilerRun models=0 worlds=0 physical=False " +
    "turning=False qsdk_r23=False equivalence=False release=False"
)
