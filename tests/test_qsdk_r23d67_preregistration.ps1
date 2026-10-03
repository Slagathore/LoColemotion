[CmdletBinding()]
param(
    [string]$Godot = (
        "C:\Users\Cole\CodeStuff\Misc\Godot\" +
        "Godot_v4.7-stable_mono_win64_console.exe"
    )
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$declarationPath = Join-Path $repoRoot (
    "sdk\turning\r23d67_authorization_schema_repaired_" +
    "three_engine_turning_preregistration_v1.json"
)
$seedCompilerPath = Join-Path $repoRoot "sdk\turning\r23d67_seed_fixture_compiler.gd"
$basePath = Join-Path $repoRoot (
    "sdk\turning\r23d66_production_route_three_engine_turning_" +
    "validation_preregistration_v1.json"
)
$predecessorClosurePath = Join-Path $repoRoot (
    "sdk\turning\r23d66_production_route_three_engine_turning_" +
    "validation_closure_v1.json"
)
$predecessorAuditPath = Join-Path $repoRoot "tests\test_qsdk_r23d66_physical_closure.ps1"
$schemaContractPath = Join-Path $repoRoot (
    "sdk\turning\three_engine_authorization_receipt_contract_v1.json"
)
$schemaValidatorPath = Join-Path $repoRoot "sdk\three_engine_authorization_receipt.ps1"
$schemaAuditPath = Join-Path $repoRoot "tests\test_three_engine_authorization_receipt.ps1"
$implementationPath = Join-Path $repoRoot (
    "sdk\turning\r23d67_production_route_three_engine_turning_" +
    "implementation_v1.json"
)
$materializerPath = Join-Path $repoRoot (
    "sdk\turning\materialize_r23d67_implementation.py"
)
$zeroWorldRunnerPath = Join-Path $repoRoot "sdk\run_qsdk_r23d67_zero_world.ps1"
$zeroWorldAuditPath = Join-Path $repoRoot "tests\test_qsdk_r23d67_zero_world.ps1"
$supervisorPath = Join-Path $repoRoot "sdk\run_qsdk_r23d67_supervisor.ps1"
$evaluatorPath = Join-Path $repoRoot (
    "sdk\turning\r23d67_production_route_three_engine_turning_evaluator.py"
)
$evaluatorAuditPath = Join-Path $repoRoot "tests\test_qsdk_r23d67_evaluator.ps1"
$campaignManifestPath = Join-Path $repoRoot (
    "sdk\turning\r23d67_campaign_attestation_manifest_v1.json"
)
$campaignManifestMaterializerPath = Join-Path $repoRoot (
    "sdk\turning\materialize_r23d67_campaign_attestation_manifest.py"
)
$campaignRoleAuditPath = Join-Path $repoRoot (
    "tests\test_qsdk_r23d67_campaign_roles.ps1"
)
$releaseContractPath = Join-Path $repoRoot "sdk\release\quadruped_release_contract.json"
$supportMatrixPath = Join-Path $repoRoot "sdk\release\quadruped_support_matrix.json"
$parentCommit = "d58505385e47923cb8e1404a559607cacc471232"
$parentTree = "2c57970188c79d38727978acecbc73916e2ad02a"
$seed = 23181
$expectedCells = @(
    "r23d67__godot_jolt__s23181__reference_zero",
    "r23d67__godot_jolt__s23181__positive_heading",
    "r23d67__godot_jolt__s23181__negative_heading",
    "r23d67__rapier_parry__s23181__reference_zero",
    "r23d67__rapier_parry__s23181__positive_heading",
    "r23d67__rapier_parry__s23181__negative_heading",
    "r23d67__mujoco__s23181__reference_zero",
    "r23d67__mujoco__s23181__positive_heading",
    "r23d67__mujoco__s23181__negative_heading"
)

function Assert-R23D67([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "QSDK-R23D67 DECLARATION: $Message" }
}

function Get-R23D67Sha256([string]$Path) {
    return "sha256:" + (
        Get-FileHash -Algorithm SHA256 -LiteralPath $Path
    ).Hash.ToLowerInvariant()
}

function Invoke-R23D67Git([string[]]$Arguments) {
    $lines = @(& git -C $repoRoot @Arguments 2>&1 | ForEach-Object { [string]$_ })
    if ($LASTEXITCODE -ne 0) {
        throw "git $($Arguments -join ' ') failed: $($lines -join ' ')"
    }
    return ($lines -join "`n").Trim()
}

function Find-R23D67NamedValues($Value, [string]$Name) {
    $found = [Collections.Generic.List[object]]::new()
    if ($Value -is [Collections.IDictionary]) {
        foreach ($key in @($Value.Keys)) {
            if ([string]$key -ceq $Name) { $found.Add($Value[$key]) }
            foreach ($nested in @(Find-R23D67NamedValues $Value[$key] $Name)) {
                $found.Add($nested)
            }
        }
    } elseif ($Value -is [Collections.IEnumerable] -and $Value -isnot [string]) {
        foreach ($item in @($Value)) {
            foreach ($nested in @(Find-R23D67NamedValues $item $Name)) {
                $found.Add($nested)
            }
        }
    }
    return @($found)
}

function Test-R23D67DeclarationVector($Value) {
    return (
        [string]$Value.schema_version -ceq
            "sporespore_qsdk_r23d67_authorization_schema_repaired_three_engine_turning_preregistration_v1" -and
        [string]$Value.status -ceq
            "prospective_declaration_complete_implementation_and_complete_authorization_ghost_pending_physical_not_authorized" -and
        [string]$Value.campaign_id -ceq
            "QSDK-R23D67-AUTHORIZATION-SCHEMA-REPAIRED-THREE-ENGINE-TURNING-VALIDATION" -and
        [string]$Value.gate_id -ceq "QSDK-R23D67" -and
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
        [string]$Value.immutable_predecessor.gate_id -ceq "QSDK-R23D66" -and
        [string]$Value.immutable_predecessor.status -ceq
            "closed_consumed_invalid_incomplete_at_nine_cell_authorization_preflight_before_any_world_mujoco_receipt_schema_mismatch" -and
        [bool]$Value.immutable_predecessor.campaign_identity_consumed -and
        -not [bool]$Value.immutable_predecessor.same_identity_rerun_allowed -and
        -not [bool]$Value.immutable_predecessor.replacement_or_selective_completion_allowed -and
        [int]$Value.immutable_predecessor.model_construction_count -eq 0 -and
        [int]$Value.immutable_predecessor.world_attempt_count -eq 0 -and
        [int]$Value.immutable_predecessor.world_build_count -eq 0 -and
        -not [bool]$Value.immutable_predecessor.turning_result_created -and
        [int]$Value.inherited_behavior_contract.threshold_selector_evaluator_or_interpretation_change_count -eq 0 -and
        [int]$Value.inherited_behavior_contract.controller_profile_schedule_or_measurement_change_count -eq 0 -and
        [int]$Value.inherited_behavior_contract.engine_or_arm_population_change_count -eq 0 -and
        [int]$Value.scientific_distinction_and_change_budget.fresh_seed -eq $seed -and
        [int]$Value.scientific_distinction_and_change_budget.fresh_seed_identity_occurrence_count_at_declaration_parent -eq 0 -and
        [string]$Value.scientific_distinction_and_change_budget.allowed_behavioral_input_change -ceq
            "fresh_seed_23181_and_its_purely_compiled_initial_perturbation" -and
        [int]$Value.seed_fixture_compilation.seed -eq $seed -and
        [int]$Value.seed_fixture_compilation.compiled_initial_perturbation.campaign_seed -eq $seed -and
        [int]$Value.seed_fixture_compilation.model_construction_count -eq 0 -and
        [int]$Value.seed_fixture_compilation.world_attempt_count -eq 0 -and
        [int]$Value.seed_fixture_compilation.world_build_count -eq 0 -and
        [int]$Value.authorization_schema_repair.complete_producer_population_size -eq 3 -and
        [int]$Value.authorization_schema_repair.positive_producer_count -eq 3 -and
        [int]$Value.authorization_schema_repair.negative_control_count -eq 117 -and
        [string]$Value.authorization_schema_repair.required_common_positive_field -ceq "ok" -and
        [string]$Value.authorization_schema_repair.required_common_positive_type -ceq "boolean" -and
        [bool]$Value.authorization_schema_repair.required_common_positive_value -and
        [int]$Value.authorization_schema_repair.physical_execution_count -eq 0 -and
        [int]$Value.frozen_matrix.campaign_seed -eq $seed -and
        (@($Value.frozen_matrix.engine_order) -join "|") -ceq
            "godot_jolt|rapier_parry|mujoco" -and
        (@($Value.frozen_matrix.arm_order) -join "|") -ceq
            "reference_zero|positive_heading|negative_heading" -and
        [double]$Value.frozen_matrix.arm_heading_offsets_rad.reference_zero -eq 0.0 -and
        [double]$Value.frozen_matrix.arm_heading_offsets_rad.positive_heading -eq 0.2 -and
        [double]$Value.frozen_matrix.arm_heading_offsets_rad.negative_heading -eq -0.2 -and
        (@($Value.frozen_matrix.ordered_cell_ids) -join "|") -ceq
            ($expectedCells -join "|") -and
        [int]$Value.frozen_matrix.declared_cell_count -eq 9 -and
        [bool]$Value.frozen_matrix.complete_population_required -and
        -not [bool]$Value.frozen_matrix.sampling_used -and
        -not [bool]$Value.prephysical_requirements.implementation_content_addressed -and
        -not [bool]$Value.prephysical_requirements.complete_zero_world_gate_passed -and
        -not [bool]$Value.prephysical_requirements.all_three_positive_worker_receipts_pass_common_validator -and
        -not [bool]$Value.prephysical_requirements.all_three_missing_ok_negatives_rejected -and
        -not [bool]$Value.prephysical_requirements.complete_nine_cell_production_supervisor_authorization_ghost_passed -and
        [bool]$Value.prephysical_requirements.ghost_must_run_before_physical_freeze_or_attempt_authorization -and
        [bool]$Value.prephysical_requirements.fresh_clean_pushed_qualification_required -and
        [bool]$Value.prephysical_requirements.separate_exact_source_adoption_required -and
        -not [bool]$Value.prephysical_requirements.physical_execution_authorized -and
        [bool]$Value.decision_rule.inherit_exactly_from_base_contract -and
        [bool]$Value.decision_rule.all_nine_cells_must_be_execution_valid_and_pass -and
        [bool]$Value.decision_rule.all_cells_run_regardless_of_intermediate_outcome -and
        -not [bool]$Value.decision_rule.same_identity_rerun_allowed -and
        -not [bool]$Value.decision_rule.selective_completion_allowed -and
        [string]$Value.decision_rule.positive_classification -ceq
            "valid_complete_positive_exact_seed_23181_three_engine_portable_turning" -and
        [double]$Value.threshold_and_population_provenance.equivalence_margin -eq 0.0 -and
        [double]$Value.threshold_and_population_provenance.non_inferiority_margin -eq 0.0 -and
        [int]$Value.threshold_and_population_provenance.cohort_size -eq 9 -and
        [bool]$Value.claims.declaration_complete -and
        [bool]$Value.claims.integration_schema_contract_complete -and
        -not [bool]$Value.claims.implementation_complete -and
        -not [bool]$Value.claims.complete_authorization_ghost_passed -and
        -not [bool]$Value.claims.physical_campaign_opened -and
        -not [bool]$Value.claims.finite_three_engine_turning -and
        -not [bool]$Value.claims.portable_basic_turning -and
        -not [bool]$Value.claims.q_sdk_r23_satisfied -and
        -not [bool]$Value.claims.cross_engine_equivalence -and
        -not [bool]$Value.claims.prone_to_standing -and
        -not [bool]$Value.claims.physical_acceptance_authority -and
        -not [bool]$Value.claims.release_authority -and
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

Assert-R23D67 (
    (Invoke-R23D67Git @("rev-parse", "--show-toplevel")) -ceq
        $repoRoot.Replace("\", "/") -and
    (Invoke-R23D67Git @("remote", "get-url", "origin")) -ceq
        "https://github.com/Slagathore/sporespore.git" -and
    (Invoke-R23D67Git @("rev-parse", "${parentCommit}^{tree}")) -ceq $parentTree
) "repository or declaration-parent identity changed"
foreach ($path in @(
    $declarationPath,
    $seedCompilerPath,
    $basePath,
    $predecessorClosurePath,
    $predecessorAuditPath,
    $schemaContractPath,
    $schemaValidatorPath,
    $schemaAuditPath,
    $implementationPath,
    $materializerPath,
    $zeroWorldRunnerPath,
    $zeroWorldAuditPath,
    $supervisorPath,
    $evaluatorPath,
    $evaluatorAuditPath,
    $campaignManifestPath,
    $campaignManifestMaterializerPath,
    $campaignRoleAuditPath,
    $releaseContractPath,
    $supportMatrixPath,
    $Godot
)) {
    Assert-R23D67 (Test-Path -LiteralPath $path -PathType Leaf) (
        "required path is missing: $path"
    )
}

$declaration = Get-Content -LiteralPath $declarationPath -Raw |
    ConvertFrom-Json -AsHashtable -Depth 100
Assert-R23D67 (Test-R23D67DeclarationVector $declaration) (
    "declaration semantics changed"
)
Assert-R23D67 (
    [string]$declaration.inherited_behavior_contract.base_raw_sha256 -ceq
        (Get-R23D67Sha256 $basePath) -and
    [string]$declaration.immutable_predecessor.closure_raw_sha256 -ceq
        (Get-R23D67Sha256 $predecessorClosurePath) -and
    [string]$declaration.immutable_predecessor.closure_audit_raw_sha256 -ceq
        (Get-R23D67Sha256 $predecessorAuditPath) -and
    [string]$declaration.seed_fixture_compilation.compiler_raw_sha256 -ceq
        (Get-R23D67Sha256 $seedCompilerPath) -and
    [string]$declaration.authorization_schema_repair.contract_raw_sha256 -ceq
        (Get-R23D67Sha256 $schemaContractPath) -and
    [string]$declaration.authorization_schema_repair.validator_raw_sha256 -ceq
        (Get-R23D67Sha256 $schemaValidatorPath) -and
    [string]$declaration.authorization_schema_repair.audit_raw_sha256 -ceq
        (Get-R23D67Sha256 $schemaAuditPath)
) "content-addressed declaration binding changed"

$seedPattern = "(^|[^0-9A-Za-z])23181([^0-9A-Za-z]|$)|23_181"
$seedOccurrences = @(
    & git -C $repoRoot grep -n -E $seedPattern $parentCommit -- . 2>$null
)
$seedGrepExit = $LASTEXITCODE
Assert-R23D67 (
    $seedGrepExit -eq 1 -and $seedOccurrences.Count -eq 0
) "seed 23181 was not absent at the declaration parent"

$predecessorOutput = @(& pwsh -NoLogo -NoProfile -File $predecessorAuditPath 2>&1)
Assert-R23D67 ($LASTEXITCODE -eq 0) (
    "immutable R23D66 closure audit failed: $($predecessorOutput -join ' ')"
)
$schemaOutput = @(& pwsh -NoLogo -NoProfile -File $schemaAuditPath 2>&1)
Assert-R23D67 (
    $LASTEXITCODE -eq 0 -and
    (@($schemaOutput | Where-Object {
        ([string]$_).StartsWith(
            "[turning/3e] AUTHORIZATION_RECEIPT_CONTRACT_PASS ",
            [StringComparison]::Ordinal
        )
    })).Count -eq 1
) "authorization schema audit failed: $($schemaOutput -join ' ')"

$seedOutput = @(
    & $Godot --headless --path $repoRoot --script (
        "res://sdk/turning/r23d67_seed_fixture_compiler.gd"
    ) 2>&1
)
Assert-R23D67 ($LASTEXITCODE -eq 0) (
    "pure seed fixture compiler failed: $($seedOutput -join ' ')"
)
$seedMarkers = @($seedOutput | Where-Object {
    ([string]$_).StartsWith("QSDK_R23D67_SEED_FIXTURES ")
})
Assert-R23D67 ($seedMarkers.Count -eq 1) "seed compiler marker changed"
$seedReceipt = ([string]$seedMarkers[0]).Substring(
    "QSDK_R23D67_SEED_FIXTURES ".Length
) | ConvertFrom-Json -AsHashtable -Depth 100
$fixture = @($seedReceipt.fixtures)[0]
$frozenFixture = $declaration.seed_fixture_compilation.compiled_initial_perturbation
Assert-R23D67 (
    [string]$seedReceipt.schema_version -ceq
        "sporespore_qsdk_r23d67_seed_fixtures_v1" -and
    @($seedReceipt.fixtures).Count -eq 1 -and
    [int]$fixture.campaign_seed -eq $seed -and
    [string]$fixture.cohort -ceq "r23d67_unopened_three_engine_held_out_turning" -and
    [double]$fixture.fixture_vertical_clearance_m -eq
        [double]$frozenFixture.fixture_vertical_clearance_m -and
    [double]$fixture.fixture_yaw_rad -eq [double]$frozenFixture.fixture_yaw_rad -and
    (@($fixture.initial_linear_velocity_world_m_s) -join "|") -ceq
        (@($frozenFixture.initial_linear_velocity_world_m_s) -join "|") -and
    (@($fixture.initial_torso_angular_velocity_world_rad_s) -join "|") -ceq
        (@($frozenFixture.initial_torso_angular_velocity_world_rad_s) -join "|") -and
    [int]$fixture.gait_phase_offset_ticks -eq
        [int]$frozenFixture.gait_phase_offset_ticks -and
    [int]$seedReceipt.model_construction_count -eq 0 -and
    [int]$seedReceipt.world_attempt_count -eq 0 -and
    [int]$seedReceipt.world_build_count -eq 0
) "pure seed fixture changed"

$implementation = Get-Content -LiteralPath $implementationPath -Raw |
    ConvertFrom-Json -AsHashtable -Depth 100
Assert-R23D67 (
    [string]$implementation.schema_version -ceq
        "sporespore_qsdk_r23d67_production_route_three_engine_turning_implementation_v1" -and
    [string]$implementation.status -ceq
        "implementation_complete_complete_zero_world_gate_passed_physical_not_authorized" -and
    [int]$implementation.dependency_inventory.transitive_path_count -eq 206 -and
    [int]$implementation.authorization_ghost.declared_cell_count -eq 9 -and
    [int]$implementation.authorization_ghost.model_construction_count -eq 0 -and
    [int]$implementation.authorization_ghost.world_attempt_count -eq 0 -and
    [int]$implementation.authorization_ghost.world_build_count -eq 0 -and
    [int]$implementation.complete_zero_world_gate.authorization_receipt_positive_count -eq 9 -and
    [int]$implementation.complete_zero_world_gate.missing_ok_negative_count -eq 3 -and
    [bool]$implementation.complete_zero_world_gate.passed -and
    [bool]$implementation.claims.implementation_complete -and
    [bool]$implementation.claims.complete_zero_world_gate_passed -and
    [bool]$implementation.claims.complete_authorization_ghost_passed -and
    [bool]$implementation.claims.all_three_positive_worker_receipts_pass_common_validator -and
    [bool]$implementation.claims.all_three_missing_ok_negatives_rejected -and
    -not [bool]$implementation.claims.physical_campaign_opened -and
    -not [bool]$implementation.claims.finite_three_engine_turning -and
    -not [bool]$implementation.claims.q_sdk_r23_satisfied -and
    -not [bool]$implementation.physical_execution_authorized -and
    -not [bool]$implementation.physical_acceptance_authority -and
    [int]$implementation.model_construction_count -eq 0 -and
    [int]$implementation.world_attempt_count -eq 0 -and
    [int]$implementation.world_build_count -eq 0
) "implementation or complete zero-world projection changed"

$campaignManifest = Get-Content -LiteralPath $campaignManifestPath -Raw |
    ConvertFrom-Json -AsHashtable -Depth 100
Assert-R23D67 (
    [string]$campaignManifest.schema_version -ceq
        "sporespore_locomotion_campaign_attestation_manifest_v1" -and
    [string]$campaignManifest.status -ceq
        "prospective_zero_world_physical_candidate" -and
    [string]$campaignManifest.campaign_id -ceq
        "QSDK-R23D67-AUTHORIZATION-SCHEMA-REPAIRED-THREE-ENGINE-TURNING-VALIDATION" -and
    [string]$campaignManifest.question_class -ceq "finite_decision" -and
    [int]$campaignManifest.declared_physical_world_count -eq 9 -and
    [int]$campaignManifest.declared_lineage_gate_count -eq 1 -and
    [int]$campaignManifest.declared_campaign_gate_count -eq 3 -and
    [int]$campaignManifest.declared_total_gate_count -eq 4 -and
    [int]$campaignManifest.declared_role_binding_count -eq 3 -and
    @($campaignManifest.source_bindings).Count -eq 209 -and
    -not [bool]$campaignManifest.physical_execution_authorized -and
    -not [bool]$campaignManifest.physical_acceptance_authority -and
    -not [bool]$campaignManifest.release_authority
) "campaign-attestation manifest changed"

$release = Get-Content -LiteralPath $releaseContractPath -Raw |
    ConvertFrom-Json -AsHashtable -Depth 100
$support = Get-Content -LiteralPath $supportMatrixPath -Raw |
    ConvertFrom-Json -AsHashtable -Depth 100
$turningGate = @($release.gates | Where-Object {
    [string]$_.gate_id -ceq "QSDK-R23"
})
$releaseSuccessor =
    $turningGate[0].proof.prospective_r23d67_authorization_schema_repaired_three_engine_turning_validation
$supportSuccessor =
    $support.locomotion_modes.three_engine_turning_production_route.current_prospective_held_out_successor
$supportNested = @(Find-R23D67NamedValues $support (
    "prospective_r23d67_authorization_schema_repaired_" +
    "three_engine_turning_validation"
))
$releaseStatus = @(Find-R23D67NamedValues $release "current_prospective_successor_status")
$supportStatus = @(Find-R23D67NamedValues $support "current_prospective_successor_status")
$releaseReason = @(Find-R23D67NamedValues $release "current_prospective_successor_reason")
$supportReason = @(Find-R23D67NamedValues $support "current_prospective_successor_reason")
$expectedStatus = (
    "r23d67_implementation_and_zero_world_complete_qualification_attempts_2_" +
    "failed_closed_latest_nested_lock_repair_implemented_fresh_clean_pushed_" +
    "qualification_and_adoption_pending_physical_not_authorized"
)
Assert-R23D67 (
    $turningGate.Count -eq 1 -and
    [string]$turningGate[0].proof.kind -ceq "missing" -and
    $null -ne $releaseSuccessor -and
    $null -ne $supportSuccessor -and
    $supportNested.Count -eq 1 -and
    ($releaseSuccessor | ConvertTo-Json -Depth 50 -Compress) -ceq
        ($supportSuccessor | ConvertTo-Json -Depth 50 -Compress) -and
    ($releaseSuccessor | ConvertTo-Json -Depth 50 -Compress) -ceq
        ($supportNested[0] | ConvertTo-Json -Depth 50 -Compress) -and
    $releaseStatus.Count -eq 1 -and
    $supportStatus.Count -eq 1 -and
    [string]$releaseStatus[0] -ceq $expectedStatus -and
    [string]$supportStatus[0] -ceq $expectedStatus -and
    $releaseReason.Count -eq 1 -and
    $supportReason.Count -eq 1 -and
    [string]$releaseReason[0] -ceq [string]$supportReason[0] -and
    [string]$releaseSuccessor.preregistration_raw_sha256 -ceq
        (Get-R23D67Sha256 $declarationPath) -and
    [string]$releaseSuccessor.declaration_audit_raw_sha256 -ceq
        (Get-R23D67Sha256 $PSCommandPath) -and
    [string]$releaseSuccessor.seed_fixture_compiler_raw_sha256 -ceq
        (Get-R23D67Sha256 $seedCompilerPath) -and
    [string]$releaseSuccessor.inherited_behavior_contract_raw_sha256 -ceq
        (Get-R23D67Sha256 $basePath) -and
    [string]$releaseSuccessor.immutable_predecessor_closure_raw_sha256 -ceq
        (Get-R23D67Sha256 $predecessorClosurePath) -and
    [string]$releaseSuccessor.authorization_receipt_contract_raw_sha256 -ceq
        (Get-R23D67Sha256 $schemaContractPath) -and
    [string]$releaseSuccessor.authorization_receipt_validator_raw_sha256 -ceq
        (Get-R23D67Sha256 $schemaValidatorPath) -and
    [string]$releaseSuccessor.authorization_receipt_audit_raw_sha256 -ceq
        (Get-R23D67Sha256 $schemaAuditPath) -and
    [string]$releaseSuccessor.implementation_path -ceq
        "sdk/turning/r23d67_production_route_three_engine_turning_implementation_v1.json" -and
    [string]$releaseSuccessor.implementation_raw_sha256 -ceq
        (Get-R23D67Sha256 $implementationPath) -and
    [string]$releaseSuccessor.implementation_materializer_path -ceq
        "sdk/turning/materialize_r23d67_implementation.py" -and
    [string]$releaseSuccessor.implementation_materializer_raw_sha256 -ceq
        (Get-R23D67Sha256 $materializerPath) -and
    [string]$releaseSuccessor.complete_zero_world_runner_path -ceq
        "sdk/run_qsdk_r23d67_zero_world.ps1" -and
    [string]$releaseSuccessor.complete_zero_world_runner_raw_sha256 -ceq
        (Get-R23D67Sha256 $zeroWorldRunnerPath) -and
    [string]$releaseSuccessor.complete_zero_world_audit_path -ceq
        "tests/test_qsdk_r23d67_zero_world.ps1" -and
    [string]$releaseSuccessor.complete_zero_world_audit_raw_sha256 -ceq
        (Get-R23D67Sha256 $zeroWorldAuditPath) -and
    [string]$releaseSuccessor.physical_supervisor_path -ceq
        "sdk/run_qsdk_r23d67_supervisor.ps1" -and
    [string]$releaseSuccessor.physical_supervisor_raw_sha256 -ceq
        (Get-R23D67Sha256 $supervisorPath) -and
    [string]$releaseSuccessor.evaluator_path -ceq
        "sdk/turning/r23d67_production_route_three_engine_turning_evaluator.py" -and
    [string]$releaseSuccessor.evaluator_raw_sha256 -ceq
        (Get-R23D67Sha256 $evaluatorPath) -and
    [string]$releaseSuccessor.evaluator_audit_path -ceq
        "tests/test_qsdk_r23d67_evaluator.ps1" -and
    [string]$releaseSuccessor.evaluator_audit_raw_sha256 -ceq
        (Get-R23D67Sha256 $evaluatorAuditPath) -and
    [string]$releaseSuccessor.campaign_attestation_manifest_path -ceq
        "sdk/turning/r23d67_campaign_attestation_manifest_v1.json" -and
    [string]$releaseSuccessor.campaign_attestation_manifest_raw_sha256 -ceq
        (Get-R23D67Sha256 $campaignManifestPath) -and
    [string]$releaseSuccessor.campaign_attestation_manifest_materializer_path -ceq
        "sdk/turning/materialize_r23d67_campaign_attestation_manifest.py" -and
    [string]$releaseSuccessor.campaign_attestation_manifest_materializer_raw_sha256 -ceq
        (Get-R23D67Sha256 $campaignManifestMaterializerPath) -and
    [string]$releaseSuccessor.campaign_role_audit_path -ceq
        "tests/test_qsdk_r23d67_campaign_roles.ps1" -and
    [string]$releaseSuccessor.campaign_role_audit_raw_sha256 -ceq
        (Get-R23D67Sha256 $campaignRoleAuditPath) -and
    [int]$releaseSuccessor.implementation_dependency_count -eq 206 -and
    [int]$releaseSuccessor.authorization_ghost_positive_receipt_count -eq 9 -and
    [int]$releaseSuccessor.authorization_ghost_missing_ok_negative_count -eq 3 -and
    [bool]$releaseSuccessor.qualification_machinery_implemented -and
    [int]$releaseSuccessor.qualification_global_gate_count -eq 12 -and
    [int]$releaseSuccessor.qualification_lineage_gate_count -eq 1 -and
    [int]$releaseSuccessor.qualification_campaign_role_gate_count -eq 3 -and
    [int]$releaseSuccessor.qualification_total_gate_count -eq 16 -and
    [int]$releaseSuccessor.qualification_attempt_count -eq 2 -and
    [int]$releaseSuccessor.failed_qualification_count -eq 2 -and
    [string]$releaseSuccessor.first_failed_qualification_source_commit -ceq
        "6e6e72e8568ec57b477f3e961945cdc873220630" -and
    [string]$releaseSuccessor.first_failed_qualification_gate_id -ceq
        "CAK1-EVIDENCE-PROVENANCE" -and
    [int]$releaseSuccessor.first_failed_qualification_passed_gate_count -eq 3 -and
    [string]$releaseSuccessor.second_failed_qualification_source_commit -ceq
        "f24537e56a04b98693657dcd41720377ff7dfe56" -and
    [string]$releaseSuccessor.second_failed_qualification_gate_id -ceq
        "R23D67-COMPLETE-ZERO-WORLD" -and
    [int]$releaseSuccessor.second_failed_qualification_global_gate_pass_count -eq 12 -and
    [int]$releaseSuccessor.second_failed_qualification_lineage_gate_pass_count -eq 0 -and
    [int]$releaseSuccessor.second_failed_qualification_campaign_role_gate_pass_count -eq 0 -and
    [bool]$releaseSuccessor.nested_authorization_ghost_lock_mode_repair_implemented -and
    [bool]$releaseSuccessor.qualification_retry_requires_distinct_corrected_clean_pushed_source -and
    [bool]$releaseSuccessor.implementation_complete -and
    [bool]$releaseSuccessor.complete_zero_world_gate_passed -and
    [bool]$releaseSuccessor.complete_nine_cell_authorization_ghost_passed -and
    -not [bool]$releaseSuccessor.qualification_passed -and
    -not [bool]$releaseSuccessor.campaign_attestation_adopted -and
    -not [bool]$releaseSuccessor.physical_campaign_opened -and
    [int]$releaseSuccessor.model_construction_count -eq 0 -and
    [int]$releaseSuccessor.world_attempt_count -eq 0 -and
    [int]$releaseSuccessor.world_build_count -eq 0 -and
    [string]$support.locomotion_modes.three_engine_turning_production_route.prospective_held_out_successor.gate_id -ceq
        "QSDK-R23D66" -and
    -not [bool]$support.locomotion_modes.command_conditioned_turning -and
    -not [bool]$support.claim_boundary.command_conditioned_turning -and
    -not [bool]$support.release_authorized
) "release-contract or support-matrix declaration projection changed"

foreach ($mutation in @(
    "seed",
    "predecessor",
    "base",
    "schema",
    "matrix",
    "ghost_order",
    "implementation",
    "turning",
    "score",
    "world"
)) {
    $copy = $declaration | ConvertTo-Json -Depth 100 |
        ConvertFrom-Json -AsHashtable -Depth 100
    switch ($mutation) {
        "seed" { $copy.scientific_distinction_and_change_budget.fresh_seed = 23179 }
        "predecessor" { $copy.immutable_predecessor.campaign_identity_consumed = $false }
        "base" { $copy.inherited_behavior_contract.threshold_selector_evaluator_or_interpretation_change_count = 1 }
        "schema" { $copy.authorization_schema_repair.required_common_positive_field = "authorization_passed" }
        "matrix" { $copy.frozen_matrix.ordered_cell_ids[8] = $copy.frozen_matrix.ordered_cell_ids[7] }
        "ghost_order" { $copy.prephysical_requirements.ghost_must_run_before_physical_freeze_or_attempt_authorization = $false }
        "implementation" { $copy.claims.implementation_complete = $true }
        "turning" { $copy.claims.q_sdk_r23_satisfied = $true }
        "score" { $copy.claims.release_score_after = "11/25" }
        "world" { $copy.world_build_count = 1 }
    }
    Assert-R23D67 (-not (Test-R23D67DeclarationVector $copy)) (
        "declaration mutation passed: $mutation"
    )
}

Write-Host (
    "[turning/3e] PASS R23D67 finite-decision declaration: seed=23181 " +
    "cells=9 schema_producers=3 schema_negatives=117 implementation=True " +
    "authorization_ghost=9/9 missing_ok=3/3 qualification_attempts=2 " +
    "failed_qualifications=2 nested_lock_repair=True qualification=False " +
    "models=0 worlds=0 QSDK-R23=False score=10/25"
)
