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
    "sdk\turning\r23d63_selected_profile_three_engine_turning_validation_" +
    "preregistration_v1.json"
)
$designPath = Join-Path $repoRoot (
    "sdk\turning\r23d63_selected_profile_three_engine_turning_validation.py"
)
$seedCompilerPath = Join-Path $repoRoot (
    "sdk\turning\r23d63_seed_fixture_compiler.gd"
)
$predecessorClosurePath = Join-Path $repoRoot (
    "sdk\turning\r23d62_selected_profile_three_engine_turning_validation_" +
    "closure_v1.json"
)
$predecessorAuditPath = Join-Path $repoRoot (
    "tests\test_qsdk_r23d62_physical_closure.ps1"
)
$receiptSchemaGatePath = Join-Path $repoRoot (
    "tests\test_qsdk_r23d63_authorization_receipt_schema.ps1"
)
$implementationPath = Join-Path $repoRoot (
    "sdk\turning\r23d63_selected_profile_three_engine_turning_validation_" +
    "implementation_v1.json"
)
$releaseContractPath = Join-Path $repoRoot (
    "sdk\release\quadruped_release_contract.json"
)
$supportMatrixPath = Join-Path $repoRoot (
    "sdk\release\quadruped_support_matrix.json"
)

function Assert-R23D63Preregistration {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) {
        throw "QSDK-R23D63 preregistration audit failed: $Message"
    }
}

function Get-R23D63PreregistrationSha256 {
    param([Parameter(Mandatory)][string]$Path)
    return (
        "sha256:" +
        (Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash.ToLowerInvariant()
    )
}

function Find-R23D63SupportAuthorityParent {
    param(
        [Parameter(Mandatory)]$Node,
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [System.Collections.Generic.List[object]]$Matches
    )
    $targetKey =
        "prospective_r23d63_receipt_schema_repaired_selected_profile_" +
        "three_engine_turning_validation"
    if ($Node -is [System.Collections.IDictionary]) {
        if ($Node.Contains($targetKey)) {
            [void]$Matches.Add($Node)
        }
        foreach ($value in $Node.Values) {
            if ($null -ne $value) {
                Find-R23D63SupportAuthorityParent -Node $value -Matches $Matches
            }
        }
        return
    }
    if ($Node -is [System.Collections.IEnumerable] -and
        $Node -isnot [string]) {
        foreach ($value in $Node) {
            if ($null -ne $value) {
                Find-R23D63SupportAuthorityParent -Node $value -Matches $Matches
            }
        }
    }
}

Assert-R23D63Preregistration ($repoRoot -ceq $expectedRoot) (
    "repository root changed: $repoRoot"
)
$gitRoot = [IO.Path]::GetFullPath(
    (& git -C $repoRoot rev-parse --show-toplevel).Trim()
)
$remote = (& git -C $repoRoot remote get-url origin).Trim()
Assert-R23D63Preregistration (
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
    $implementationPath,
    $releaseContractPath,
    $supportMatrixPath
)) {
    Assert-R23D63Preregistration (Test-Path -LiteralPath $path -PathType Leaf) (
        "required source is missing: $path"
    )
}

$declaration = Get-Content -Raw -LiteralPath $declarationPath |
    ConvertFrom-Json -AsHashtable -Depth 100
$implementation = Get-Content -Raw -LiteralPath $implementationPath |
    ConvertFrom-Json -AsHashtable -Depth 100
$releaseContract = Get-Content -Raw -LiteralPath $releaseContractPath |
    ConvertFrom-Json -AsHashtable -Depth 100
$supportMatrix = Get-Content -Raw -LiteralPath $supportMatrixPath |
    ConvertFrom-Json -AsHashtable -Depth 100
$releaseGate = @($releaseContract.gates | Where-Object {
    [string]$_.gate_id -ceq "QSDK-R23"
})
Assert-R23D63Preregistration ($releaseGate.Count -eq 1) (
    "release contract QSDK-R23 gate population changed"
)
$releaseProof = $releaseGate[0].proof
$releaseRecord =
    $releaseProof.prospective_r23d63_receipt_schema_repaired_selected_profile_three_engine_turning_validation
$supportAuthorityParents = [System.Collections.Generic.List[object]]::new()
Find-R23D63SupportAuthorityParent `
    -Node $supportMatrix `
    -Matches $supportAuthorityParents
Assert-R23D63Preregistration ($supportAuthorityParents.Count -eq 1) (
    "support matrix R23D63 authority population changed"
)
$supportTurning = $supportAuthorityParents[0]
$supportRecord =
    $supportTurning.prospective_r23d63_receipt_schema_repaired_selected_profile_three_engine_turning_validation
$qualificationHistory = $implementation.qualification_history
$initialQualification = $qualificationHistory.initial_clean_pushed_qualification
$inventoryExtension = $qualificationHistory.provenance_inventory_extension
$nextTransition = $qualificationHistory.next_required_transition
$expectedLifecycleStatus =
    "complete_zero_world_passed_initial_clean_pushed_qualification_failed_" +
    "global_provenance_inventory_extended_fresh_qualification_pending_" +
    "physical_not_opened"
$expectedCurrentLifecycleStatus = "r23d63_$expectedLifecycleStatus"
$parentCommit = [string]$declaration.immutable_lineage.declaration_parent_commit
$parentTree = (& git -C $repoRoot rev-parse "$parentCommit^{tree}").Trim()
Assert-R23D63Preregistration (
    $LASTEXITCODE -eq 0 -and
    $parentCommit -ceq "11eb2d3918d8f254d07b3ee7fe99dd51957b82f1" -and
    $parentTree -ceq "91a597da16ffdc871641939c302bc5a4082208d1"
) "declaration parent identity changed"

$seedOccurrences = @(
    & git -C $repoRoot grep -n -E `
        "(^|[^0-9A-Za-z])23169([^0-9A-Za-z]|$)|23_169" `
        $parentCommit -- . 2>$null
)
$seedGrepExit = $LASTEXITCODE
Assert-R23D63Preregistration (
    $seedGrepExit -eq 1 -and
    $seedOccurrences.Count -eq 0 -and
    [int]$declaration.immutable_lineage.r23d63_seed_identity_occurrence_count_at_parent_commit -eq 0 -and
    -not [bool]$declaration.immutable_lineage.r23d63_seed_had_prior_repository_occurrence
) "fresh seed identity was not absent at the declaration parent"

$predecessor = $declaration.predecessor_closure
$receiptContract = $declaration.authorization_receipt_schema_conformance
$changeBudget = $declaration.successor_change_budget
$matrix = $declaration.frozen_matrix
$gates = $declaration.frozen_common_physical_gates
$decision = $declaration.finite_decision_rule
$requirements = $declaration.implementation_and_execution_requirements
$controls = $declaration.required_zero_world_negative_controls
Assert-R23D63Preregistration (
    [string]$declaration.schema_version -ceq
        "sporespore_qsdk_r23d63_selected_profile_three_engine_turning_validation_preregistration_v1" -and
    [string]$declaration.status -ceq "prospective_zero_world_only_physical_not_opened" -and
    [string]$declaration.gate_id -ceq "QSDK-R23D63" -and
    [string]$declaration.question_class -ceq "finite_decision" -and
    [bool]$declaration.physical_question_declared -and
    -not [bool]$declaration.physical_campaign_opened -and
    [string]$predecessor.gate_id -ceq "QSDK-R23D62" -and
    [string]$predecessor.classification -ceq "invalid_or_incomplete_first_attempt" -and
    [bool]$predecessor.campaign_identity_consumed -and
    -not [bool]$predecessor.physical_outcome_exposed -and
    [int]$predecessor.world_attempt_count -eq 0 -and
    -not [bool]$predecessor.same_identity_repair_or_rerun_permitted -and
    [string]$predecessor.closure_raw_sha256 -ceq
        (Get-R23D63PreregistrationSha256 $predecessorClosurePath) -and
    [string]$predecessor.closure_audit_raw_sha256 -ceq
        (Get-R23D63PreregistrationSha256 $predecessorAuditPath) -and
    @($changeBudget.allowed_mechanism_changes).Count -eq 3 -and
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
    [int]$matrix.declared_cell_count -eq 9 -and
    [int]$matrix.declared_world_count -eq 9 -and
    [int]$matrix.seed -eq 23169 -and
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
    [bool]$controls.authorization_receipt_complete_matrix_field_missing_rejected_per_engine -and
    [bool]$controls.authorization_receipt_complete_matrix_field_false_rejected_per_engine -and
    [bool]$controls.authorization_receipt_complete_matrix_field_wrong_type_rejected_per_engine -and
    [bool]$controls.authorization_receipt_complete_matrix_field_alias_rejected_per_engine -and
    -not [bool]$declaration.claims.r23d63_complete_zero_world_gate_passed -and
    -not [bool]$declaration.claims.r23d63_physical_campaign_opened -and
    -not [bool]$declaration.claims.q_sdk_r23_satisfied -and
    -not [bool]$declaration.claims.release_authorized
) "prospective declaration contract changed"

Assert-R23D63Preregistration (
    [string]$implementation.status -ceq
        "prospective_campaign_machinery_implemented_receipt_schema_gate_passed_complete_zero_world_gate_passed_physical_not_opened" -and
    [string]$releaseProof.current_prospective_successor_status -ceq
        $expectedCurrentLifecycleStatus -and
    [string]$supportTurning.current_prospective_successor_status -ceq
        $expectedCurrentLifecycleStatus -and
    [string]$releaseRecord.status -ceq [string]$implementation.status -and
    [string]$supportRecord.status -ceq [string]$implementation.status -and
    [string]$releaseRecord.current_lifecycle_status -ceq
        $expectedLifecycleStatus -and
    [string]$supportRecord.current_lifecycle_status -ceq
        $expectedLifecycleStatus -and
    [string]$releaseRecord.implementation_raw_sha256 -ceq
        (Get-R23D63PreregistrationSha256 $implementationPath) -and
    [string]$supportRecord.implementation_sha256 -ceq
        (Get-R23D63PreregistrationSha256 $implementationPath) -and
    ($qualificationHistory | ConvertTo-Json -Depth 100 -Compress) -ceq
        ($releaseRecord.qualification_history | ConvertTo-Json -Depth 100 -Compress) -and
    ($qualificationHistory | ConvertTo-Json -Depth 100 -Compress) -ceq
        ($supportRecord.qualification_history | ConvertTo-Json -Depth 100 -Compress) -and
    [bool]$implementation.campaign_attestation_boundary.initial_failed_clean_pushed_qualification_retained -and
    -not [bool]$implementation.campaign_attestation_boundary.passing_clean_pushed_qualification_retained -and
    [bool]$implementation.campaign_attestation_boundary.provenance_inventory_corrected -and
    [bool]$implementation.campaign_attestation_boundary.fresh_corrected_clean_pushed_source_required -and
    -not [bool]$implementation.campaign_attestation_boundary.physical_launch_prerequisite_satisfied -and
    [string]$initialQualification.status -ceq
        "failed_incomplete_global_provenance_gate" -and
    [string]$initialQualification.source_commit -ceq
        "2918e29d4899d785b4c8b7ca148e0aaf60264aa6" -and
    [string]$initialQualification.source_tree_git_oid -ceq
        "1d866ceab93cb5eb764a8c5fc59cb8bccc033cbb" -and
    [string]$initialQualification.failed_gate_id -ceq
        "CAK1-EVIDENCE-PROVENANCE" -and
    [string]$initialQualification.failure_raw_sha256 -ceq
        "sha256:64e4a37752b2d3fa13f984b1b4199048572a53ec0144ea66147639f6c98a2d04" -and
    [long]$initialQualification.failure_byte_length -eq 652 -and
    [string]$initialQualification.failed_gate_receipt_raw_sha256 -ceq
        "sha256:d23743a7b141e095d157b972b62d1514891284377c2896a7271b8eb6bfb42432" -and
    [long]$initialQualification.failed_gate_receipt_byte_length -eq 2706 -and
    [string]$initialQualification.failed_gate_stderr_raw_sha256 -ceq
        "sha256:b28acb33c56b6a6174983302ef2fa32bb65da482b57742e30169984c7dd04f48" -and
    [long]$initialQualification.failed_gate_stderr_byte_length -eq 251 -and
    [int]$initialQualification.retained_file_count -eq 13 -and
    [long]$initialQualification.retained_byte_count -eq 12698 -and
    [int]$initialQualification.passed_global_gate_count -eq 3 -and
    [int]$initialQualification.lineage_gate_count -eq 0 -and
    [int]$initialQualification.campaign_role_gate_count -eq 0 -and
    [int]$initialQualification.model_construction_count -eq 0 -and
    [int]$initialQualification.world_attempt_count -eq 0 -and
    [int]$initialQualification.world_build_count -eq 0 -and
    -not [bool]$initialQualification.physical_attempt_identity_consumed -and
    -not [bool]$initialQualification.reusable -and
    [string]$inventoryExtension.question_class -ceq
        "equivalence_non_inferiority" -and
    [string]$inventoryExtension.population_definition -ceq
        "complete_discovered_closure_audit_population" -and
    [int]$inventoryExtension.pre_extension_audit_count -eq 167 -and
    [int]$inventoryExtension.post_extension_audit_count -eq 169 -and
    [bool]$inventoryExtension.population_compared_completely -and
    [int]$inventoryExtension.sample_size -eq 169 -and
    -not [bool]$inventoryExtension.sampling_used -and
    [int]$inventoryExtension.added_audit_count -eq 2 -and
    [int]$inventoryExtension.changed_audit_count -eq 0 -and
    [int]$inventoryExtension.removed_audit_count -eq 0 -and
    [int]$inventoryExtension.equivalence_margin -eq 0 -and
    [int]$inventoryExtension.non_inferiority_margin -eq 0 -and
    (@($inventoryExtension.added_entries.path) -join "|") -ceq
        "tests/test_qsdk_r23d62_physical_closure.ps1|tests/test_qsdk_r23d63_dependency_closure.ps1" -and
    [bool]$inventoryExtension.corrected -and
    [int]$inventoryExtension.route_worker_controller_physics_or_evaluator_semantics_change_count -eq 0 -and
    [int]$inventoryExtension.threshold_selector_result_or_interpretation_change_count -eq 0 -and
    [int]$inventoryExtension.physical_world_count -eq 0 -and
    [string]$nextTransition.status -ceq
        "fresh_distinct_corrected_clean_pushed_qualification_pending" -and
    -not [bool]$nextTransition.failed_source_retry_permitted -and
    [bool]$nextTransition.distinct_corrected_clean_pushed_source_required -and
    [bool]$nextTransition.fresh_scoped_qualification_required -and
    [bool]$nextTransition.separate_fail_closed_adoption_required -and
    -not [bool]$nextTransition.physical_launch_prerequisite_satisfied -and
    -not [bool]$releaseRecord.clean_pushed_qualification_retained -and
    -not [bool]$supportRecord.clean_pushed_qualification_retained -and
    -not [bool]$releaseRecord.campaign_attestation_adopted -and
    -not [bool]$supportRecord.campaign_attestation_adopted -and
    -not [bool]$releaseRecord.physical_campaign_opened -and
    -not [bool]$supportRecord.physical_campaign_opened -and
    [int]$releaseRecord.world_attempt_count -eq 0 -and
    [int]$supportRecord.world_attempt_count -eq 0 -and
    -not [bool]$releaseRecord.q_sdk_r23_satisfied -and
    -not [bool]$supportRecord.q_sdk_r23_satisfied -and
    -not [bool]$releaseRecord.prone_to_standing -and
    -not [bool]$supportRecord.prone_to_standing -and
    -not [bool]$releaseRecord.release_authorized -and
    -not [bool]$supportRecord.release_authorized
) "retained qualification refusal or corrected lifecycle authority changed"

$designOutput = @(& $Python $designPath 2>&1)
Assert-R23D63Preregistration ($LASTEXITCODE -eq 0) (
    "declaration validator failed`n" +
    ($designOutput -join [Environment]::NewLine)
)
$designMarker = @($designOutput | Where-Object {
    ([string]$_).StartsWith("QSDK_R23D63_DECLARATION_PASS ")
})
Assert-R23D63Preregistration ($designMarker.Count -eq 1) (
    "declaration validator marker changed"
)
$designReceipt = ([string]$designMarker[0]).Substring(
    "QSDK_R23D63_DECLARATION_PASS ".Length
) | ConvertFrom-Json -AsHashtable -Depth 100
Assert-R23D63Preregistration (
    [int]$designReceipt.mutation_rejection_count -eq 43 -and
    [int]$designReceipt.cell_count -eq 9 -and
    [int]$designReceipt.reserved_seed -eq 23169 -and
    [int]$designReceipt.model_construction_count -eq 0 -and
    [int]$designReceipt.world_attempt_count -eq 0 -and
    [int]$designReceipt.world_build_count -eq 0 -and
    -not [bool]$designReceipt.physical_campaign_opened -and
    -not [bool]$designReceipt.physical_acceptance_authority
) "declaration validator receipt changed"

$closureOutput = @(
    & pwsh -NoLogo -NoProfile -File $predecessorAuditPath 2>&1
)
Assert-R23D63Preregistration (
    $LASTEXITCODE -eq 0 -and
    @($closureOutput | Where-Object {
        ([string]$_).StartsWith("QSDK_R23D62_PHYSICAL_CLOSURE_PASS ")
    }).Count -eq 1
) (
    "immutable R23D62 closure replay failed`n" +
    ($closureOutput -join [Environment]::NewLine)
)

$godotCompilerRun = $false
if (-not $SkipGodot) {
    Assert-R23D63Preregistration (Test-Path -LiteralPath $Godot -PathType Leaf) (
        "Godot executable missing: $Godot"
    )
    $godotOutput = @(
        & $Godot --headless --path $repoRoot --script `
            "res://sdk/turning/r23d63_seed_fixture_compiler.gd" 2>&1
    )
    Assert-R23D63Preregistration ($LASTEXITCODE -eq 0) (
        "Godot seed compiler failed`n" +
        ($godotOutput -join [Environment]::NewLine)
    )
    $seedMarker = @($godotOutput | Where-Object {
        ([string]$_).StartsWith("QSDK_R23D63_SEED_FIXTURES ")
    })
    Assert-R23D63Preregistration ($seedMarker.Count -eq 1) (
        "Godot seed compiler marker changed"
    )
    $seedReceipt = ([string]$seedMarker[0]).Substring(
        "QSDK_R23D63_SEED_FIXTURES ".Length
    ) | ConvertFrom-Json -AsHashtable -Depth 100
    $fixture = @($seedReceipt.fixtures)[0]
    Assert-R23D63Preregistration (
        @($seedReceipt.fixtures).Count -eq 1 -and
        [int]$fixture.campaign_seed -eq 23169 -and
        [double]$fixture.fixture_vertical_clearance_m -eq 0.00007932152220746502 -and
        [double]$fixture.fixture_yaw_rad -eq 0.002175381872802973 -and
        @($fixture.initial_linear_velocity_world_m_s).Count -eq 3 -and
        [double]$fixture.initial_linear_velocity_world_m_s[0] -eq 0.002873786259442568 -and
        [double]$fixture.initial_linear_velocity_world_m_s[1] -eq 0.0 -and
        [double]$fixture.initial_linear_velocity_world_m_s[2] -eq -0.0036080731078982353 -and
        @($fixture.initial_torso_angular_velocity_world_rad_s).Count -eq 3 -and
        [double]$fixture.initial_torso_angular_velocity_world_rad_s[0] -eq -0.00014649319928139448 -and
        [double]$fixture.initial_torso_angular_velocity_world_rad_s[1] -eq 0.002177086193114519 -and
        [double]$fixture.initial_torso_angular_velocity_world_rad_s[2] -eq 0.0017654569819569588 -and
        [int]$fixture.gait_phase_offset_ticks -eq 1 -and
        [int]$seedReceipt.model_construction_count -eq 0 -and
        [int]$seedReceipt.world_attempt_count -eq 0 -and
        [int]$seedReceipt.world_build_count -eq 0
    ) "Godot seed compiler output changed"
    $godotCompilerRun = $true
}

Write-Output (
    "QSDK_R23D63_PREREGISTRATION_PASS " +
    "cells=9 seed=23169 declaration_mutations=43 receipt_producers=3 " +
    "receipt_negative_controls=12 seed_occurrences_at_parent=0 " +
    "godot_compiler=$godotCompilerRun models=0 worlds=0 physical=False " +
    "turning=False qsdk_r23=False equivalence=False release=False"
)
