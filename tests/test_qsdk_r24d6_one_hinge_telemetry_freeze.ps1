#requires -Version 7.0

[CmdletBinding()]
param([string]$Python = "python")

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$contractRelative = (
    "sdk/recovery/" +
    "r24d6_godot_jolt_one_hinge_telemetry_characterization_" +
    "preregistration_v1.json"
)
$evaluatorRelative = (
    "sdk/recovery/" +
    "r24d6_godot_jolt_one_hinge_telemetry_characterization_evaluator.py"
)
$rigRelative = (
    "scripts/lab/rigs/" +
    "r24d6_godot_jolt_one_hinge_telemetry_rig.gd"
)
$probeRelative = (
    "scripts/lab/rigs/" +
    "r24d6_godot_jolt_telemetry_stepping_probe_body.gd"
)
$workerRelative = (
    "tests/" +
    "test_sdk_qsdk_r24d6_godot_jolt_one_hinge_telemetry_physical_worker.gd"
)
$supervisorRelative = (
    "sdk/run_qsdk_r24d6_one_hinge_telemetry_characterization.ps1"
)
$auditRelative = "tests/test_qsdk_r24d6_one_hinge_telemetry_freeze.ps1"
$manifestRelative = (
    "sdk/recovery/" +
    "r24d6_godot_jolt_one_hinge_telemetry_validation_manifest.json"
)
$precommitParserDiagnosticsRelative = (
    "sdk/recovery/r24d6_precommit_godot_parser_diagnostics_v1.json"
)
$qualificationFailureRelative = (
    "sdk/recovery/r24d6_first_official_zero_world_qualification_failure_v1.json"
)
$predecessorClosureRelative = (
    "sdk/recovery/r24d5_godot_jolt_one_hinge_telemetry_" +
    "physical_failure_closure_v1.json"
)
$predecessorClosureAuditRelative = (
    "tests/test_qsdk_r24d5_one_hinge_telemetry_" +
    "physical_failure_closure.ps1"
)

function Assert-R24D6 {
    param([bool]$Condition, [string]$Code)
    if (-not $Condition) { throw "QSDK-R24D6 freeze: $Code" }
}

function Get-R24D6Path {
    param([Parameter(Mandatory)][string]$Relative)
    return [IO.Path]::GetFullPath((Join-Path $repoRoot $Relative))
}

function Read-R24D6Contract {
    return Get-Content -Raw -LiteralPath (Get-R24D6Path $contractRelative) |
        ConvertFrom-Json -AsHashtable -Depth 100
}

function Copy-R24D6Value {
    param([Parameter(Mandatory)]$Value)
    return $Value | ConvertTo-Json -Depth 100 -Compress |
        ConvertFrom-Json -AsHashtable -Depth 100
}

function Assert-R24D6Contract {
    param([Parameter(Mandatory)][hashtable]$Contract)

    Assert-R24D6 (
        [string]$Contract.schema_version -ceq
        "sporespore_qsdk_r24d6_godot_jolt_one_hinge_telemetry_characterization_preregistration_v1"
    ) "schema_version"
    Assert-R24D6 ([string]$Contract.gate_id -ceq "QSDK-R24D6") "gate_id"
    Assert-R24D6 ([string]$Contract.question_class -ceq "development") (
        "question_class"
    )
    Assert-R24D6 (
        [string]$Contract.status -ceq
        "prospectively_frozen_serialized_envelope_successor_zero_world_gate_pending_physical_execution_forbidden"
    ) "status"

    $parent = [hashtable]$Contract.parent_authority
    Assert-R24D6 ([string]$parent.gate_id -ceq "QSDK-R24D3") "parent_gate"
    Assert-R24D6 (
        [string]$parent.adopted_console_binary_raw_sha256 -ceq
        "sha256:762ed7137d06284742b53abdde9b98c692ab1e8d3a184458db4d8e7a39782462"
    ) "console_binary_digest"
    Assert-R24D6 (
        [string]$parent.adopted_engine_binary_raw_sha256 -ceq
        "sha256:d0bb895b996fa98ec69a68b9f98ca6ed99af2eb18ef67a0b176ad1a55220278d"
    ) "engine_binary_digest"
    Assert-R24D6 (
        [string]$parent.patch_raw_sha256 -ceq
        "sha256:f067543bc6237a38c0c0935a56b3bbebcd318dc6d82cec1321ea5d52e45dae2f"
    ) "patch_digest"
    foreach ($key in @(
        "parent_result_rewritten",
        "stock_godot_result_rewritten",
        "result_reuse_authority_imported",
        "instrumented_profile_promotion_imported"
    )) {
        Assert-R24D6 (-not [bool]$parent[$key]) "parent_boundary_$key"
    }

    $predecessor = [hashtable]$Contract.predecessor_implementation_invalid_result
    Assert-R24D6 (
        [string]$predecessor.gate_id -ceq "QSDK-R24D5" -and
        [string]$predecessor.source_commit -ceq
            "fffb773b408b0cf8bb4a3ba78e773b62c3a0e52a" -and
        [string]$predecessor.closure_id -ceq "QSDK-R24D5-PH1-CLOSURE" -and
        [string]$predecessor.closure_path -ceq $predecessorClosureRelative -and
        [string]$predecessor.closure_audit_path -ceq
            $predecessorClosureAuditRelative -and
        [string]$predecessor.status -ceq
            "worker_execution_complete_evaluation_invalid_fixture_json_identity_mismatch" -and
        [string]$predecessor.result_class -ceq
            "invalid_development_result_no_characterization" -and
        [bool]$predecessor.declared_zero_world_gate_passed -and
        -not [bool]$predecessor.declared_zero_world_gate_adequate_for_full_precision_physical_envelope -and
        [int]$predecessor.physical_world_attempt_count -eq 1 -and
        [int]$predecessor.world_build_count -eq 1 -and
        [int]$predecessor.physics_step_count -eq 20 -and
        [int]$predecessor.retained_raw_sample_count -eq 68 -and
        -not [bool]$predecessor.evaluation_record_written -and
        -not [bool]$predecessor.raw_numerical_outcomes_accepted_as_characterization -and
        [bool]$predecessor.r24d5_source_evaluator_worker_or_result_repair_forbidden -and
        [bool]$predecessor.same_source_physical_open_forbidden -and
        -not [bool]$predecessor.predecessor_result_rewritten_or_reinterpreted
    ) "predecessor_implementation_invalid_result"

    $source = [hashtable]$Contract.prospective_source
    $expectedPaths = [ordered]@{
        rig_path = $rigRelative
        stepping_probe_path = $probeRelative
        worker_path = $workerRelative
        evaluator_path = $evaluatorRelative
        supervisor_path = $supervisorRelative
        freeze_audit_path = $auditRelative
        validation_manifest_path = $manifestRelative
        precommit_parser_diagnostics_path = $precommitParserDiagnosticsRelative
    }
    foreach ($entry in $expectedPaths.GetEnumerator()) {
        Assert-R24D6 ([string]$source[$entry.Key] -ceq [string]$entry.Value) (
            "source_path_$($entry.Key)"
        )
    }
    Assert-R24D6 ([bool]$source.complete_zero_world_gate_required_before_physics) (
        "zero_world_required"
    )
    Assert-R24D6 (
        [bool]$source.real_evaluator_shaped_full_precision_serialized_envelope_gate_required_before_physics -and
        [bool]$source.default_precision_serialized_envelope_negative_control_required_before_physics -and
        [bool]$source.serialized_envelope_template_must_be_synthetic_and_zero_world
    ) "serialized_envelope_required"
    Assert-R24D6 (
        [bool]$source.engine_and_solver_freeze_must_be_verified_zero_world_and_rechecked_before_build
    ) "zero_world_and_prebuild_engine_freeze"
    Assert-R24D6 (-not [bool]$source.same_source_physical_rerun_allowed) (
        "same_source_rerun"
    )
    Assert-R24D6 (-not [bool]$source.r24d5_source_or_result_mutation_allowed) (
        "predecessor_mutation"
    )

    $engine = [hashtable]$Contract.engine_and_solver_freeze
    Assert-R24D6 ([string]$engine.physics_engine -ceq "Jolt Physics") (
        "physics_engine"
    )
    Assert-R24D6 ([int]$engine.physics_ticks_per_second -eq 120) "physics_hz"
    Assert-R24D6 ([int]$engine.solver_velocity_steps -eq 20) "velocity_steps"
    Assert-R24D6 ([int]$engine.solver_position_steps -eq 7) "position_steps"
    Assert-R24D6 ([int]$engine.retained_binary_count -eq 2) "binary_count"
    Assert-R24D6 (
        [string]$engine.godot_source_commit -ceq
            "5b4e0cb0fd279832bbdd69fed5354d4e5ad26f88" -and
        -not [bool]$engine.build_precision_argument_explicitly_supplied -and
        [string]$engine.build_precision_default -ceq "single" -and
        [string]$engine.real_t_storage -ceq "float" -and
        [string]$engine.json_full_precision_conversion -ceq
            "String::num_scientific(double)" -and
        [bool]$engine.json_sort_keys
    ) "engine_numeric_path"
    Assert-R24D6 (-not [bool]$engine.runtime_substitution_allowed) (
        "runtime_substitution"
    )

    $fixture = [hashtable]$Contract.fixture_freeze
    $realTInertiaBits = @(
        $fixture.child_inertia_real_t_binary64_projection_diagonal_kg_m2 |
            ForEach-Object {
                "{0:x16}" -f [BitConverter]::DoubleToInt64Bits([double]$_)
            }
    )
    $fullPrecisionInertiaBits = @(
        $fixture.child_inertia_full_precision_json_stringify_diagonal_kg_m2 |
            ForEach-Object {
                "{0:x16}" -f [BitConverter]::DoubleToInt64Bits([double]$_)
            }
    )
    $defaultPrecisionInertiaBits = @(
        $fixture.child_inertia_default_precision_negative_control_diagonal_kg_m2 |
            ForEach-Object {
                "{0:x16}" -f [BitConverter]::DoubleToInt64Bits([double]$_)
            }
    )
    Assert-R24D6 ([int]$fixture.world_count -eq 1) "world_count"
    Assert-R24D6 ([int]$fixture.isolated_cell_count -eq 9) "cell_count"
    Assert-R24D6 ([int]$fixture.hinges_per_cell -eq 1) "hinges_per_cell"
    Assert-R24D6 ([int]$fixture.contact_count -eq 0) "contact_count"
    Assert-R24D6 (
        (@($fixture.child_inertia_diagonal_kg_m2) -join ",") -ceq
            "0.05,0.05,0.05" -and
        [string]$fixture.child_inertia_godot_real_t_storage -ceq
            "single_precision_Vector3" -and
        ($realTInertiaBits -join ",") -ceq
            "3fa99999a0000000,3fa99999a0000000,3fa99999a0000000" -and
        ($fullPrecisionInertiaBits -join ",") -ceq
            "3fa99999a0000000,3fa99999a0000000,3fa99999a0000000" -and
        ($defaultPrecisionInertiaBits -join ",") -ceq
            "3fa99999a0000006,3fa99999a0000006,3fa99999a0000006" -and
        [bool]$fixture.child_inertia_representation_is_an_exact_identity_not_a_tolerance
    ) "fixture_inertia_representation"
    Assert-R24D6 (
        (@($fixture.hinge_axis_parent_local) -join ",") -ceq "0,0,1" -and
        [string]$fixture.hinge_axis_symbol -ceq "Vector3.BACK" -and
        [string]$fixture.pinned_godot_axis_source_path -ceq
            "core/math/vector3.h" -and
        [string]$fixture.pinned_godot_axis_source_git_blob_oid -ceq
            "f83431b59c6c44ebe372b8c8210b77a617c94b0d" -and
        [string]$fixture.pinned_godot_axis_source_raw_sha256 -ceq
            "sha256:60bd8b6351a45b4e0927bbbda7b605b89ebe0572173c7dc2a1d121f33c9d5ae9" -and
        [string]$fixture.pinned_godot_axis_declaration -ceq
            "inline constexpr Vector3 Vector3::BACK = { 0, 0, 1 };"
    ) "fixture_axis_convention"
    foreach ($key in @(
        "direct_force_write_count",
        "direct_torque_write_count",
        "direct_impulse_write_count",
        "post_activation_transform_write_count"
    )) {
        Assert-R24D6 ([int]$fixture[$key] -eq 0) "fixture_$key"
    }
    Assert-R24D6 (
        [int]$fixture.pre_activation_initial_angular_velocity_write_count -eq 4
    ) "initial_velocity_write_count"
    Assert-R24D6 ([int]$fixture.declared_sleep_input_write_count -eq 1) (
        "sleep_input_count"
    )
    $expectedCellIds = @(
        "drive_positive",
        "drive_negative",
        "brake_positive",
        "brake_negative",
        "disabled_positive",
        "disabled_negative",
        "limit_positive",
        "limit_negative",
        "sleep_stale"
    )
    Assert-R24D6 (
        (@($fixture.cell_ids_in_order) -join "|") -ceq
        ($expectedCellIds -join "|")
    ) "cell_identity_order"

    $numericSource = [hashtable]$Contract.pinned_godot_numeric_source_provenance
    $numericFiles = @($numericSource.files)
    Assert-R24D6 (
        [bool]$numericSource.source_tree_must_remain_read_only -and
        [bool]$numericSource.source_commit_must_match_before_zero_world_and_physical_work -and
        $numericFiles.Count -eq 5 -and
        @($numericFiles | ForEach-Object { [string]$_.path } | Select-Object -Unique).Count -eq 5 -and
        @($numericSource.declared_source_facts).Count -eq 5
    ) "numeric_source_provenance"

    $readbackIdentity = [hashtable]$Contract.declared_vs_real_t_readback_identity
    $projections = @($readbackIdentity.projections)
    Assert-R24D6 (
        [bool]$readbackIdentity.comparison_is_exact_not_toleranced -and
        $projections.Count -eq 5 -and
        (@($projections | ForEach-Object { [string]$_.declared_text }) -join "|") -ceq
            "0.05|0.002|0.01|0.02|-0.02" -and
        (@($projections | ForEach-Object { [string]$_.binary32_hex }) -join "|") -ceq
            "3d4ccccd|3b03126f|3c23d70a|3ca3d70a|bca3d70a" -and
        (@($projections | ForEach-Object { [string]$_.full_precision_json_text }) -join "|") -ceq
            "0.05000000074505806|0.0020000000949949026|0.009999999776482582|0.019999999552965164|-0.019999999552965164" -and
        -not [bool]$readbackIdentity.r24d5_invalid_payload_used_as_numerical_authority -and
        [bool]$readbackIdentity.r24d5_invalid_payload_used_only_as_diagnostic_motivation
    ) "real_t_readback_identity"

    $refusals = [hashtable]$Contract.refusal_and_freshness_controls
    foreach ($key in @(
        "invalid_rid_must_return_null",
        "not_in_tree_joint_read_must_return_null",
        "read_during_integrate_forces_must_return_null",
        "read_during_integrate_forces_attempt_must_be_observed",
        "active_sequence_observed_before_sleep_input",
        "sleeping_sequence_repetition_retained_as_stale_observation"
    )) {
        Assert-R24D6 ([bool]$refusals[$key]) "refusal_control_$key"
    }
    Assert-R24D6 (-not [bool]$refusals.stale_sequence_synthesizes_fresh_data) (
        "stale_sequence_synthesis"
    )
    Assert-R24D6 (-not [bool]$refusals.invalid_read_synthesizes_zero) (
        "invalid_read_synthesis"
    )

    $evaluation = [hashtable]$Contract.evaluation_contract
    Assert-R24D6 (
        [string]$evaluation.classification -ceq
        "complete_valid_or_invalid_descriptive_development_characterization"
    ) "evaluation_class"
    Assert-R24D6 (-not [bool]$evaluation.turning_evaluator_invoked) (
        "turning_evaluator"
    )
    Assert-R24D6 (-not [bool]$evaluation.recovery_evaluator_invoked) (
        "recovery_evaluator"
    )
    Assert-R24D6 ([bool]$evaluation.descriptive_findings_are_not_execution_validity_gates) (
        "descriptive_outcomes"
    )
    Assert-R24D6 (-not [bool]$evaluation.outcome_dependent_early_stop_allowed) (
        "outcome_early_stop"
    )
    Assert-R24D6 (
        [bool]$evaluation.declared_fixture_and_cell_configuration_must_match_exactly
    ) "configuration_identity_gate"
    Assert-R24D6 (
        [bool]$evaluation.runtime_parameter_and_per_sample_public_readbacks_must_match_exactly
    ) "runtime_readback_identity_gate"
    Assert-R24D6 (
        [bool]$evaluation.mandatory_registration_and_refusal_controls_are_validity_gates
    ) "registration_refusal_gate"
    Assert-R24D6 (
        [bool]$evaluation.ordered_cell_and_sample_arrays_remain_semantic -and
        -not [bool]$evaluation.dictionary_key_order_is_semantic -and
        [bool]$evaluation.not_in_tree_refusal_dictionary_requires_exact_key_set -and
        [bool]$evaluation.same_evaluator_used_for_synthetic_zero_world_canaries_and_physical_report -and
        [bool]$evaluation.synthetic_zero_world_envelope_is_never_a_native_measurement -and
        [int]$evaluation.synthetic_zero_world_embedded_execution_shape.world_attempt_count -eq 1 -and
        [int]$evaluation.synthetic_zero_world_actual_execution_counts.world_attempt_count -eq 0
    ) "serialized_evaluation_boundary"

    $serialized = [hashtable]$Contract.serialized_runtime_controls
    Assert-R24D6 (
        [string]$serialized.full_precision_serializer_call -ceq
            'JSON.stringify(report, "", true, true)' -and
        [string]$serialized.default_precision_negative_serializer_call -ceq
            'JSON.stringify(report, "", true, false)' -and
        [bool]$serialized.full_precision_envelope_must_pass_real_evaluator -and
        [bool]$serialized.default_precision_envelope_must_fail_real_evaluator -and
        [string]$serialized.default_precision_required_terminal_error -ceq
            "fixture_inertia_representation" -and
        [bool]$serialized.full_and_default_envelopes_must_be_retained_and_content_addressed -and
        [bool]$serialized.evaluator_zero_world_receipt_must_refuse_native_measurement_authority -and
        [int]$serialized.declared_negative_control_count -eq 1 -and
        [int]$serialized.actual_world_attempt_count -eq 0 -and
        [int]$serialized.actual_world_build_count -eq 0 -and
        [int]$serialized.actual_solver_step_count -eq 0
    ) "serialized_runtime_controls"

    $adequacy = [hashtable]$Contract.threshold_margin_cohort_and_population_adequacy
    foreach ($key in @(
        "empirical_acceptance_threshold_count",
        "superiority_margin_count",
        "equivalence_or_non_inferiority_margin_count",
        "validation_cohort_identity_count",
        "population_claim_count"
    )) {
        Assert-R24D6 ([int]$adequacy[$key] -eq 0) "adequacy_$key"
    }
    Assert-R24D6 ([int]$adequacy.development_fixture_cell_count -eq 9) (
        "development_fixture_count"
    )
    Assert-R24D6 (-not [bool]$adequacy.numerical_residual_acceptance_margin_declared) (
        "numerical_margin"
    )
    Assert-R24D6 (
        ([string]$adequacy.adequacy_argument).Contains(
            "inadequate for profile promotion"
        )
    ) "adequacy_argument"

    $negative = [hashtable]$Contract.negative_controls
    Assert-R24D6 ([int]$negative.declared_count -eq 29) "negative_count"
    Assert-R24D6 (@($negative.required_rejections).Count -eq 29) (
        "negative_identity_count"
    )
    foreach ($requiredRejection in @(
        "fixture_axis_sign_mutation_rejected",
        "fixture_inertia_representation_mutation_rejected",
        "source_identity_mutation_rejected",
        "pre_tree_refusal_key_set_mutation_rejected",
        "cell_configuration_mutation_rejected",
        "parameter_readback_configuration_mutation_rejected",
        "parameter_maximum_impulse_real_t_representation_mutation_rejected",
        "parameter_limit_real_t_representation_mutation_rejected",
        "sample_public_readback_configuration_mutation_rejected",
        "sample_limit_real_t_representation_mutation_rejected",
        "engine_registration_mutation_rejected",
        "invalid_rid_refusal_mutation_rejected",
        "unsafe_read_non_refusal_mutation_rejected"
    )) {
        Assert-R24D6 (
            $requiredRejection -cin @($negative.required_rejections)
        ) "negative_identity_$requiredRejection"
    }

    $authorization = [hashtable]$Contract.physical_authorization
    Assert-R24D6 (-not [bool]$authorization.permitted_now) (
        "physical_permission"
    )
    Assert-R24D6 ([int]$authorization.world_attempt_count -eq 0) (
        "physical_attempt_count"
    )
    Assert-R24D6 ([int]$authorization.world_build_count -eq 0) (
        "physical_world_count"
    )
    Assert-R24D6 (-not [bool]$authorization.physical_result_exists) (
        "physical_result"
    )
    foreach ($requiredAuthorization in @(
        "prove_the_default_precision_serialized_envelope_is_rejected_at_the_preregistered_fixture_inertia_identity",
        "prove_the_full_precision_serialized_envelope_passes_the_real_frozen_evaluator"
    )) {
        Assert-R24D6 (
            $requiredAuthorization -cin @($authorization.required_before_permission)
        ) "physical_authorization_$requiredAuthorization"
    }

    $claims = [hashtable]$Contract.claims
    Assert-R24D6 ([bool]$claims.source_and_oracle_freeze_declared) (
        "source_freeze_claim"
    )
    foreach ($key in @(
        "complete_zero_world_gate_passed",
        "serialized_full_precision_envelope_zero_world_qualified",
        "default_precision_negative_control_passed",
        "physical_characterization_executed",
        "native_sign_characterized",
        "native_impulse_cap_characterized",
        "native_work_energy_characterized",
        "native_limit_separation_characterized",
        "native_motor_disabled_zero_characterized",
        "native_refusal_and_freshness_characterized",
        "instrumented_profile_promoted",
        "stock_godot_profile_promoted",
        "recovery_controller_implemented",
        "recovery_world_opened",
        "prone_to_standing_world_opened",
        "turning_claim_changed",
        "cross_engine_equivalence_claimed",
        "q_sdk_r24_satisfied",
        "physical_acceptance_authority",
        "release_authority"
    )) {
        Assert-R24D6 (-not [bool]$claims[$key]) "claim_$key"
    }
}

$root = (& git -C $repoRoot rev-parse --show-toplevel).Trim()
Assert-R24D6 ($LASTEXITCODE -eq 0) "git_root_unavailable"
Assert-R24D6 ([IO.Path]::GetFullPath($root) -ceq $repoRoot) "git_root"
$remote = (& git -C $repoRoot remote get-url origin).Trim()
Assert-R24D6 ($LASTEXITCODE -eq 0) "git_remote_unavailable"
Assert-R24D6 (
    $remote -ceq "https://github.com/Slagathore/sporespore.git"
) "git_remote"

foreach ($relative in @(
    $contractRelative,
    $evaluatorRelative,
    $rigRelative,
    $probeRelative,
    $workerRelative,
    $supervisorRelative,
    $manifestRelative,
    $auditRelative,
    $precommitParserDiagnosticsRelative,
    $qualificationFailureRelative,
    $predecessorClosureRelative,
    $predecessorClosureAuditRelative
)) {
    Assert-R24D6 (Test-Path -LiteralPath (Get-R24D6Path $relative) -PathType Leaf) (
        "missing_$relative"
    )
}

$contract = Read-R24D6Contract
Assert-R24D6Contract $contract

$godotRoot = "C:\Users\Cole\CodeStuff\dependencies\godot-sporespore-4.7"
$godotResolvedRoot = (& git -C $godotRoot rev-parse --show-toplevel).Trim()
$godotCommit = (& git -C $godotRoot rev-parse HEAD).Trim()
Assert-R24D6 (
    $LASTEXITCODE -eq 0 -and
    [IO.Path]::GetFullPath($godotResolvedRoot) -ceq $godotRoot -and
    $godotCommit -ceq "5b4e0cb0fd279832bbdd69fed5354d4e5ad26f88"
) "pinned_godot_root_and_commit"
foreach ($bindingValue in @(
    $contract.pinned_godot_numeric_source_provenance.files
)) {
    $binding = [hashtable]$bindingValue
    $sourcePath = [IO.Path]::GetFullPath(
        (Join-Path $godotRoot ([string]$binding.path))
    )
    $sourceItem = Get-Item -LiteralPath $sourcePath
    $sourceSha = (Get-FileHash -LiteralPath $sourcePath -Algorithm SHA256).
        Hash.ToLowerInvariant()
    $sourceHeadBlob = (& git -C $godotRoot rev-parse (
        "HEAD:" + [string]$binding.path
    )).Trim()
    $sourceLiveBlob = (& git -C $godotRoot hash-object -- $sourcePath).Trim()
    Assert-R24D6 (
        $LASTEXITCODE -eq 0 -and
        [long]$binding.byte_length -eq [long]$sourceItem.Length -and
        [string]$binding.raw_sha256 -ceq "sha256:$sourceSha" -and
        [string]$binding.git_blob_oid -ceq $sourceHeadBlob -and
        $sourceHeadBlob -ceq $sourceLiveBlob
    ) "pinned_godot_numeric_source_$($binding.path)"
}

$rigText = Get-Content -Raw -LiteralPath (Get-R24D6Path $rigRelative)
$probeText = Get-Content -Raw -LiteralPath (Get-R24D6Path $probeRelative)
$workerText = Get-Content -Raw -LiteralPath (Get-R24D6Path $workerRelative)
$evaluatorText = Get-Content -Raw -LiteralPath (Get-R24D6Path $evaluatorRelative)
$supervisorText = Get-Content -Raw -LiteralPath (Get-R24D6Path $supervisorRelative)
$precommitParserDiagnostics = Get-Content -Raw -LiteralPath (
    Get-R24D6Path $precommitParserDiagnosticsRelative
) | ConvertFrom-Json -AsHashtable -Depth 100
$diagnosticAttempts = @($precommitParserDiagnostics.attempts)
Assert-R24D6 (
    [string]$precommitParserDiagnostics.schema_version -ceq
        "sporespore_qsdk_r24d6_precommit_godot_parser_diagnostics_v1" -and
    [string]$precommitParserDiagnostics.record_id -ceq
        "QSDK-R24D6-PRECOMMIT-GODOT-PARSER-DIAGNOSTICS" -and
    [string]$precommitParserDiagnostics.question_class -ceq
        "non_physical_development_diagnostic" -and
    [string]$precommitParserDiagnostics.status -ceq
        "retained_one_parser_negative_then_passing_distinct_source_revision" -and
    $diagnosticAttempts.Count -eq 2 -and
    [int]$precommitParserDiagnostics.finite_counts.parser_negative_count -eq 1 -and
    [int]$precommitParserDiagnostics.finite_counts.parser_pass_count -eq 1 -and
    [int]$precommitParserDiagnostics.finite_counts.world_attempt_count -eq 0 -and
    [int]$precommitParserDiagnostics.finite_counts.world_build_count -eq 0 -and
    [int]$precommitParserDiagnostics.finite_counts.solver_step_count -eq 0 -and
    -not [bool]$precommitParserDiagnostics.source_boundary.official_zero_world_qualification -and
    -not [bool]$precommitParserDiagnostics.claims.complete_zero_world_gate_passed -and
    -not [bool]$precommitParserDiagnostics.claims.physical_characterization_executed -and
    -not [bool]$precommitParserDiagnostics.claims.physical_acceptance_authority -and
    -not [bool]$precommitParserDiagnostics.claims.release_authority
) "precommit_parser_diagnostics_identity"
foreach ($diagnosticAttemptValue in $diagnosticAttempts) {
    $diagnosticAttempt = [hashtable]$diagnosticAttemptValue
    $retainedLog = [hashtable]$diagnosticAttempt.retained_log
    $cas = [hashtable]$diagnosticAttempt.cas
    foreach ($path in @(
        [string]$retainedLog.path,
        [string]$cas.payload_path,
        [string]$cas.manifest_path
    )) {
        Assert-R24D6 (Test-Path -LiteralPath $path -PathType Leaf) (
            "precommit_parser_diagnostic_missing_$path"
        )
    }
    $retainedSha = (Get-FileHash -LiteralPath ([string]$retainedLog.path) -Algorithm SHA256).
        Hash.ToLowerInvariant()
    $payloadSha = (Get-FileHash -LiteralPath ([string]$cas.payload_path) -Algorithm SHA256).
        Hash.ToLowerInvariant()
    Assert-R24D6 (
        [string]$retainedLog.raw_sha256 -ceq "sha256:$retainedSha" -and
        $retainedSha -ceq $payloadSha -and
        [long]$retainedLog.byte_length -eq
            (Get-Item -LiteralPath ([string]$retainedLog.path)).Length -and
        [long]$retainedLog.byte_length -eq
            (Get-Item -LiteralPath ([string]$cas.payload_path)).Length
    ) "precommit_parser_diagnostic_bytes_$($diagnosticAttempt.attempt_index)"
}
$qualificationFailure = Get-Content -Raw -LiteralPath (
    Get-R24D6Path $qualificationFailureRelative
) | ConvertFrom-Json -AsHashtable -Depth 100
$qualificationFailureStages = @($qualificationFailure.stages)
Assert-R24D6 (
    [string]$qualificationFailure.schema_version -ceq
        "sporespore_qsdk_r24d6_first_official_zero_world_qualification_failure_v1" -and
    [string]$qualificationFailure.record_id -ceq "QSDK-R24D6-ZW1-FAILURE" -and
    [string]$qualificationFailure.question_class -ceq
        "non_physical_source_conformance" -and
    [string]$qualificationFailure.status -ceq
        "incomplete_static_dependency_manifest_drift_before_worker_launch" -and
    [string]$qualificationFailure.result_class -ceq
        "zero_world_qualification_incomplete_no_serialized_envelope_result" -and
    [string]$qualificationFailure.attempt.attempt_id -ceq
        "20260816T154956Z-ef540fa5-bf61d4f53544" -and
    [string]$qualificationFailure.attempt.source_commit -ceq
        "ef540fa50ce9d155aa5d78bbef04070b62dc0a76" -and
    [bool]$qualificationFailure.attempt.local_cached_and_live_main_equal_at_launch -and
    [bool]$qualificationFailure.attempt.worktree_clean_at_launch -and
    [int]$qualificationFailure.attempt.worktree_count -eq 1 -and
    [string]$qualificationFailure.attempt.run_root -ceq
        "C:/Users/Cole/CodeStuff/games/SporeSpore_Evidence/qsdk-r24d6-one-hinge-zero-world/20260816T154956Z-ef540fa5-bf61d4f53544" -and
    [int]$qualificationFailure.attempt.supervisor_exit_code -eq 1 -and
    [int]$qualificationFailure.attempt.declared_static_stage_count -eq 5 -and
    [int]$qualificationFailure.attempt.attempted_static_stage_count -eq 3 -and
    [int]$qualificationFailure.attempt.passed_static_stage_count -eq 2 -and
    [int]$qualificationFailure.attempt.failed_static_stage_count -eq 1 -and
    [int]$qualificationFailure.attempt.unattempted_static_stage_count -eq 2 -and
    [int]$qualificationFailure.attempt.worker_launch_count -eq 0 -and
    [int]$qualificationFailure.attempt.godot_process_launch_count -eq 0 -and
    [int]$qualificationFailure.attempt.synthetic_template_emission_count -eq 0 -and
    [int]$qualificationFailure.attempt.default_precision_envelope_count -eq 0 -and
    [int]$qualificationFailure.attempt.full_precision_envelope_count -eq 0 -and
    [int]$qualificationFailure.attempt.real_evaluator_envelope_invocation_count -eq 0 -and
    [int]$qualificationFailure.attempt.world_attempt_count -eq 0 -and
    [int]$qualificationFailure.attempt.world_build_count -eq 0 -and
    [int]$qualificationFailure.attempt.solver_step_count -eq 0 -and
    -not [bool]$qualificationFailure.attempt.physics_state_modified -and
    $qualificationFailureStages.Count -eq 3 -and
    (@($qualificationFailureStages | ForEach-Object { [string]$_.label }) -join "|") -ceq
        "r24d5_physical_failure_closure|r24d6_freeze_audit|r24d3_source_audit" -and
    (@($qualificationFailureStages | ForEach-Object { [int]$_.exit_code }) -join "|") -ceq
        "0|0|1" -and
    (@($qualificationFailureStages | ForEach-Object { [string]$_.status }) -join "|") -ceq
        "passed|passed|failed" -and
    [string]$qualificationFailureStages[2].failure_code -ceq
        "manifest_source_binding_drift_gitattributes" -and
    -not [bool]$qualificationFailure.diagnosis.r24d6_evaluator_or_serialization_result_exists -and
    -not [bool]$qualificationFailure.diagnosis.r24d6_source_oracle_failure_observed -and
    -not [bool]$qualificationFailure.diagnosis.r24d5_result_rewritten_or_reinterpreted -and
    -not [bool]$qualificationFailure.diagnosis.threshold_selector_evaluator_or_physical_result_changed -and
    -not [bool]$qualificationFailure.diagnosis.same_source_replacement_run_allowed -and
    [bool]$qualificationFailure.diagnosis.new_clean_pushed_source_required -and
    -not [bool]$qualificationFailure.claims.complete_zero_world_gate_passed -and
    -not [bool]$qualificationFailure.claims.physical_characterization_executed -and
    -not [bool]$qualificationFailure.claims.turning_claim_changed -and
    -not [bool]$qualificationFailure.claims.physical_acceptance_authority -and
    -not [bool]$qualificationFailure.claims.release_authority
) "first_official_zero_world_qualification_failure_identity"
foreach ($failureStageValue in $qualificationFailureStages) {
    $failureStage = [hashtable]$failureStageValue
    foreach ($path in @(
        [string]$failureStage.log_path,
        [string]$failureStage.cas_payload_path,
        [string]$failureStage.cas_manifest_path
    )) {
        Assert-R24D6 (Test-Path -LiteralPath $path -PathType Leaf) (
            "first_qualification_failure_missing_$path"
        )
    }
    $retainedSha = (Get-FileHash `
        -LiteralPath ([string]$failureStage.log_path) `
        -Algorithm SHA256).Hash.ToLowerInvariant()
    $casSha = (Get-FileHash `
        -LiteralPath ([string]$failureStage.cas_payload_path) `
        -Algorithm SHA256).Hash.ToLowerInvariant()
    $casManifest = Get-Content -Raw `
        -LiteralPath ([string]$failureStage.cas_manifest_path) |
        ConvertFrom-Json -AsHashtable -Depth 30
    Assert-R24D6 (
        [string]$failureStage.raw_sha256 -ceq "sha256:$retainedSha" -and
        $retainedSha -ceq $casSha -and
        [long]$failureStage.byte_length -eq
            (Get-Item -LiteralPath ([string]$failureStage.log_path)).Length -and
        [long]$failureStage.byte_length -eq
            (Get-Item -LiteralPath ([string]$failureStage.cas_payload_path)).Length -and
        [string]$casManifest.schema_version -ceq
            "sporespore_content_addressed_artifact_manifest_v1" -and
        [string]$casManifest.algorithm -ceq "sha256" -and
        [string]$casManifest.sha256 -ceq "sha256:$retainedSha" -and
        [long]$casManifest.byte_length -eq [long]$failureStage.byte_length -and
        [string]$casManifest.payload_name -ceq "payload.bin" -and
        [string]$casManifest.media_type -ceq "text/plain"
    ) "first_qualification_failure_bytes_$($failureStage.index)"
}
$predecessorClosure = Get-Content -Raw -LiteralPath (
    Get-R24D6Path $predecessorClosureRelative
) | ConvertFrom-Json -AsHashtable -Depth 100
Assert-R24D6 (
    [string]$predecessorClosure.closure_id -ceq "QSDK-R24D5-PH1-CLOSURE" -and
    [string]$predecessorClosure.status -ceq
        "worker_execution_complete_evaluation_invalid_fixture_json_identity_mismatch" -and
    [string]$predecessorClosure.result_class -ceq
        "invalid_development_result_no_characterization" -and
    [string]$predecessorClosure.source.commit -ceq
        "fffb773b408b0cf8bb4a3ba78e773b62c3a0e52a" -and
    [int]$predecessorClosure.attempt.world_attempt_count -eq 1 -and
    [int]$predecessorClosure.attempt.world_build_count -eq 1 -and
    [int]$predecessorClosure.attempt.physics_step_count -eq 20 -and
    [int]$predecessorClosure.attempt.retained_sample_count -eq 68 -and
    -not [bool]$predecessorClosure.worker_execution.raw_numerical_outcomes_accepted_as_characterization -and
    [bool]$predecessorClosure.diagnosis.scientifically_distinct_prospectively_frozen_successor_required -and
    [bool]$predecessorClosure.immutability.r24d5_evaluator_repair_forbidden -and
    [bool]$predecessorClosure.immutability.r24d5_worker_repair_forbidden -and
    [bool]$predecessorClosure.immutability.same_source_physical_rerun_forbidden
) "predecessor_closure_boundary"
Assert-R24D6 (($rigText | Select-String -Pattern '"cell_id":' -AllMatches).Matches.Count -eq 9) (
    "rig_cell_count"
)
Assert-R24D6 ($rigText.Contains("const MAXIMUM_PHYSICS_STEP_COUNT := 20")) (
    "rig_horizon"
)
Assert-R24D6 ($rigText.Contains('-float(spec["canonical_target_velocity_rad_s"])')) (
    "host_sign_mapping"
)
Assert-R24D6 (
    $rigText.Contains(
        "const CANONICAL_AXIS_PARENT_LOCAL := Vector3.BACK",
        [StringComparison]::Ordinal
    ) -and
    $workerText.Contains(
        '"hinge_axis_matches": axis == [0.0, 0.0, 1.0]',
        [StringComparison]::Ordinal
    ) -and
    $evaluatorText.Contains(
        '== [0.0, 0.0, 1.0],',
        [StringComparison]::Ordinal
    ) -and
    $evaluatorText.Contains(
        '"fixture_axis_sign",',
        [StringComparison]::Ordinal
    )
) "axis_oracle_alignment"
Assert-R24D6 (
    $workerText.Contains(
        'inertia == _vector(RigScript.CHILD_INERTIA_KG_M2)',
        [StringComparison]::Ordinal
    ) -and
    $evaluatorText.Contains(
        'EXPECTED_CHILD_INERTIA_JSON_COMPONENT_KG_M2 = 0.05000000074505806',
        [StringComparison]::Ordinal
    ) -and
    $evaluatorText.Contains(
        '"fixture_inertia_representation",',
        [StringComparison]::Ordinal
    )
) "inertia_representation_alignment"
foreach ($forbidden in @(
    ".apply_force(",
    ".apply_central_force(",
    ".apply_torque(",
    ".apply_impulse(",
    ".apply_torque_impulse("
)) {
    Assert-R24D6 (-not $rigText.Contains($forbidden)) "rig_forbidden_$forbidden"
    Assert-R24D6 (-not $workerText.Contains($forbidden)) "worker_forbidden_$forbidden"
}
Assert-R24D6 ($probeText.Contains("func _integrate_forces")) "probe_callback"
Assert-R24D6 ($probeText.Contains("hinge_joint_get_motor_telemetry")) (
    "probe_binding"
)
Assert-R24D6 (-not $probeText.Contains("state.")) "probe_state_write"
Assert-R24D6 ($workerText.Contains('if mode == "zero_world_preflight"')) (
    "worker_zero_world_route"
)
Assert-R24D6 (
    $workerText.Contains(
        'if mode != "zero_world_preflight" and mode != "physical"'
    )
) (
    "worker_physical_refusal"
)
Assert-R24D6 ($workerText.Contains("func _engine_receipt_is_frozen")) (
    "worker_engine_freeze_predicate"
)
Assert-R24D6 ($workerText.Contains("func _fixture_description_is_frozen")) (
    "worker_fixture_freeze_predicate"
)
Assert-R24D6 (
    (($workerText | Select-String -Pattern 'RigScript\.build\(\)' -AllMatches).Matches.Count) -eq 1
) "worker_build_call_count"
$preflightStart = $workerText.IndexOf("func _run_zero_world_preflight")
$physicalStart = $workerText.IndexOf("func _run_physical")
Assert-R24D6 ($preflightStart -ge 0 -and $physicalStart -gt $preflightStart) (
    "worker_function_order"
)
$preflightText = $workerText.Substring($preflightStart, $physicalStart - $preflightStart)
Assert-R24D6 (-not $preflightText.Contains("RigScript.build")) (
    "zero_world_build_call"
)
Assert-R24D6 ($preflightText.Contains("_engine_receipt_is_frozen(engine)")) (
    "zero_world_engine_freeze_check"
)
Assert-R24D6 ($preflightText.Contains("_fixture_description_is_frozen(description)")) (
    "zero_world_fixture_freeze_check"
)
foreach ($diagnosticToken in @(
    "engine_freeze_matches",
    "fixture_description_matches",
    "fixture_description_gates",
    "_load_zero_world_template",
    "_template_matches_declared_fixture",
    "_apply_zero_world_runtime_projection",
    'JSON.stringify(report, "", true, false)',
    'JSON.stringify(report, "", true, true)',
    "QSDK_R24D6_ZERO_WORLD_DEFAULT_PRECISION_ENVELOPE",
    "QSDK_R24D6_ZERO_WORLD_FULL_PRECISION_ENVELOPE",
    "active_physics_object_count",
    "active_physics_object_count_is_zero"
)) {
    Assert-R24D6 ($preflightText.Contains($diagnosticToken)) (
        "zero_world_diagnostic_$diagnosticToken"
    )
}
$physicalText = $workerText.Substring($physicalStart)
$physicalEngineFreeze = $physicalText.IndexOf("_engine_receipt_is_frozen(engine)")
$physicalFixtureFreeze = $physicalText.IndexOf(
    "_fixture_description_is_frozen(description)"
)
$physicalBuild = $physicalText.IndexOf("RigScript.build()")
Assert-R24D6 (
    $physicalEngineFreeze -ge 0 -and
    $physicalFixtureFreeze -gt $physicalEngineFreeze -and
    $physicalBuild -gt $physicalFixtureFreeze
) "physical_freeze_checks_before_world_build"
Assert-R24D6 ($workerText.Contains("QSDK_R24D6_PHYSICAL_RAW_REPORT")) (
    "physical_marker"
)
Assert-R24D6 ($workerText.Contains("QSDK_R24D6_GODOT_SUPERVISOR_TERMINATION_READY")) (
    "termination_marker"
)
Assert-R24D6 ($evaluatorText.Contains("descriptive_findings_are_acceptance_gates")) (
    "threshold_free_evaluation"
)
Assert-R24D6 ($evaluatorText.Contains("accepted_outcome_mutation_count")) (
    "outcome_mutation_control"
)
Assert-R24D6 (
    $evaluatorText.Contains(
        'set(pre_tree.keys()) == set(EXPECTED_CELL_IDS)'
    ) -and
    -not $evaluatorText.Contains(
        'list(pre_tree.keys()) == EXPECTED_CELL_IDS'
    ) -and
    $evaluatorText.Contains("EXPECTED_REAL_T_MAXIMUM_IMPULSE") -and
    $evaluatorText.Contains("EXPECTED_REAL_T_LIMIT") -and
    $evaluatorText.Contains("evaluate_zero_world_serialized_envelope") -and
    $evaluatorText.Contains("--emit-zero-world-template") -and
    $evaluatorText.Contains("--zero-world-envelope")
) "evaluator_serialized_envelope_and_key_set_semantics"
foreach ($requiredSupervisorToken in @(
    "Enter-SporeSporeLocomotionOperationLock",
    "local_upstream_cached_live_inequality",
    "Assert-R24D6ManifestAndBindings",
    "Get-R24D6MatchingPhysicalAttempts",
    "retained_physical_attempt_unreadable",
    "same_source_physical_attempt_already_exists",
    "physical_run_path_exists",
    "yyyyMMddTHHmmssfffZ",
    "consumed_before_worker_launch",
    "Invoke-SporeSporeGodotReceiptTerminatedProcess",
    "Publish-SporeSporeContentAddressedArtifact",
    "Assert-R24D6RetainedFileAndCas",
    "QSDK_R24D5_PHYSICAL_FAILURE_CLOSURE_PASS",
    "QSDK_R24D3_COLD_QUALIFICATION_ADOPTION_PASS",
    "zero_world_receipt_identity",
    "zeroReceipt.engine.solver_velocity_steps",
    "zeroReceipt.engine_freeze_matches",
    "zeroReceipt.fixture_description_matches",
    "zeroReceipt.fixture_description_gates",
    "zeroReceipt.active_physics_object_count_is_zero",
    "zero_world_worker_receipt_log_binding",
    "QSDK_R24D6_ZERO_WORLD_TEMPLATE",
    "QSDK_R24D6_ZERO_WORLD_DEFAULT_PRECISION_ENVELOPE",
    "QSDK_R24D6_ZERO_WORLD_FULL_PRECISION_ENVELOPE",
    "QSDK_R24D6_SERIALIZED_ENVELOPE_ZERO_WORLD_EVALUATION",
    "QSDK_R24D6_EVALUATION_ERROR fixture_inertia_representation",
    "zero_world_serialized_oracle_identity",
    "physical_raw_identity",
    "pre_physical_source_drift"
)) {
    Assert-R24D6 ($supervisorText.Contains($requiredSupervisorToken)) (
        "supervisor_token_$requiredSupervisorToken"
    )
}

$manifest = Get-Content -Raw -LiteralPath (Get-R24D6Path $manifestRelative) |
    ConvertFrom-Json -AsHashtable -Depth 100
Assert-R24D6 (
    [string]$manifest.schema_version -ceq
    "sporespore_qsdk_r24d6_one_hinge_telemetry_validation_manifest_v1"
) "manifest_schema"
Assert-R24D6 ([int]$manifest.source_binding_count -eq 11) (
    "manifest_binding_count"
)
$expectedBindingPaths = @(
    $contractRelative,
    $evaluatorRelative,
    $rigRelative,
    $probeRelative,
    $workerRelative,
    $supervisorRelative,
    $auditRelative,
    $precommitParserDiagnosticsRelative,
    $qualificationFailureRelative,
    $predecessorClosureRelative,
    $predecessorClosureAuditRelative
)
$bindings = @($manifest.bindings)
Assert-R24D6 ($bindings.Count -eq 11) "manifest_bindings"
Assert-R24D6 (
    (@($bindings | ForEach-Object { [string]$_.path }) -join "|") -ceq
    ($expectedBindingPaths -join "|")
) "manifest_binding_order"
foreach ($binding in $bindings) {
    $absolute = Get-R24D6Path ([string]$binding.path)
    $hash = (Get-FileHash -LiteralPath $absolute -Algorithm SHA256).
        Hash.ToLowerInvariant()
    $length = (Get-Item -LiteralPath $absolute).Length
    $blob = (& git -C $repoRoot hash-object -- $absolute).Trim()
    Assert-R24D6 ($LASTEXITCODE -eq 0) "manifest_blob_$($binding.path)"
    Assert-R24D6 (
        [string]$binding.raw_sha256 -ceq "sha256:$hash" -and
        [long]$binding.byte_length -eq [long]$length -and
        [string]$binding.git_blob_oid -ceq $blob
    ) "manifest_bytes_$($binding.path)"
}
foreach ($key in @(
    "complete_zero_world_gate_passed",
    "serialized_full_precision_envelope_zero_world_qualified",
    "default_precision_negative_control_passed",
    "physical_characterization_executed",
    "instrumented_profile_promoted",
    "physical_acceptance_authority",
    "release_authority"
)) {
    Assert-R24D6 (-not [bool]$manifest[$key]) "manifest_claim_$key"
}
Assert-R24D6 (
    [string]$manifest.predecessor_gate_id -ceq "QSDK-R24D5" -and
    [string]$manifest.predecessor_source_commit -ceq
        "fffb773b408b0cf8bb4a3ba78e773b62c3a0e52a" -and
    [string]$manifest.predecessor_closure_id -ceq "QSDK-R24D5-PH1-CLOSURE" -and
    [string]$manifest.predecessor_status -ceq
        "worker_execution_complete_evaluation_invalid_fixture_json_identity_mismatch" -and
    [string]$manifest.predecessor_result_class -ceq
        "invalid_development_result_no_characterization" -and
    [int]$manifest.prior_official_zero_world_qualification_failure_count -eq 1 -and
    [string]$manifest.prior_official_zero_world_qualification_failure_source_commit -ceq
        "ef540fa50ce9d155aa5d78bbef04070b62dc0a76" -and
    [int]$manifest.official_zero_world_qualification_count -eq 0 -and
    [int]$manifest.fixture_cell_count -eq 9 -and
    [int]$manifest.retained_sample_count -eq 68 -and
    [int]$manifest.evaluator_negative_control_count -eq 29 -and
    [int]$manifest.accepted_outcome_mutation_count -eq 2 -and
    [int]$manifest.contract_mutation_rejection_count -eq 18 -and
    [int]$manifest.binary32_projection_control_count -eq 5 -and
    [int]$manifest.serialized_runtime_negative_control_count -eq 1 -and
    [int]$manifest.serialized_runtime_positive_control_count -eq 1
) "manifest_successor_boundary"

$pythonOutput = @(
    & $Python (Get-R24D6Path $evaluatorRelative) --self-test 2>&1
)
Assert-R24D6 ($LASTEXITCODE -eq 0) (
    "evaluator_self_test_exit:$($pythonOutput -join ' | ')"
)
$prefix = "QSDK_R24D6_EVALUATOR_ZERO_WORLD "
$markers = @($pythonOutput | Where-Object {
    ([string]$_).StartsWith($prefix, [StringComparison]::Ordinal)
})
Assert-R24D6 ($markers.Count -eq 1) "evaluator_marker_count"
$evaluatorReceipt = ([string]$markers[0]).Substring($prefix.Length) |
    ConvertFrom-Json -AsHashtable -Depth 100
Assert-R24D6 ([bool]$evaluatorReceipt.ok) "evaluator_ok"
Assert-R24D6 (
    [int]$evaluatorReceipt.rejected_negative_control_count -eq 29
) "evaluator_negative_count"
foreach ($requiredRejection in @(
    "fixture_axis_sign",
    "fixture_inertia_representation",
    "source_identity",
    "pre_tree_refusal_key_set",
    "cell_configuration",
    "parameter_readback_configuration",
    "parameter_maximum_impulse_real_t_representation",
    "parameter_limit_real_t_representation",
    "sample_public_readback_configuration",
    "sample_limit_real_t_representation",
    "engine_registration",
    "invalid_rid_refusal",
    "unsafe_read_non_refusal"
)) {
    Assert-R24D6 (
        $requiredRejection -cin @($evaluatorReceipt.rejected_negative_controls)
    ) "evaluator_negative_identity_$requiredRejection"
}
Assert-R24D6 (
    [int]$evaluatorReceipt.accepted_outcome_mutation_count -eq 2
) "evaluator_outcome_count"
Assert-R24D6 (
    [int]$evaluatorReceipt.empirical_acceptance_threshold_count -eq 0
) "evaluator_threshold_count"
Assert-R24D6 (
    [int]$evaluatorReceipt.synthetic_zero_world_envelope_evaluation_count -eq 1 -and
    [int]$evaluatorReceipt.binary32_projection_control_count -eq 5
) "evaluator_serialized_projection_counts"
Assert-R24D6 (
    [int]$evaluatorReceipt.world_attempt_count -eq 0 -and
    [int]$evaluatorReceipt.world_build_count -eq 0 -and
    [int]$evaluatorReceipt.solver_step_count -eq 0
) "evaluator_world_counts"

$contractMutations = @(
    @{ name = "question_class"; path = @("question_class"); value = "finite_decision" },
    @{ name = "status"; path = @("status"); value = "physical_open" },
    @{ name = "rerun"; path = @("prospective_source", "same_source_physical_rerun_allowed"); value = $true },
    @{ name = "world_count"; path = @("fixture_freeze", "world_count"); value = 2 },
    @{ name = "cell_count"; path = @("fixture_freeze", "isolated_cell_count"); value = 8 },
    @{ name = "threshold"; path = @("threshold_margin_cohort_and_population_adequacy", "empirical_acceptance_threshold_count"); value = 1 },
    @{ name = "margin"; path = @("threshold_margin_cohort_and_population_adequacy", "numerical_residual_acceptance_margin_declared"); value = $true },
    @{ name = "physical_permission"; path = @("physical_authorization", "permitted_now"); value = $true },
    @{ name = "physical_world"; path = @("physical_authorization", "world_build_count"); value = 1 },
    @{ name = "fixture_axis"; path = @("fixture_freeze", "hinge_axis_parent_local"); value = @(0.0, 0.0, -1.0) },
    @{ name = "fixture_inertia"; path = @("fixture_freeze", "child_inertia_diagonal_kg_m2"); value = @(0.06, 0.06, 0.06) },
    @{ name = "native_sign"; path = @("claims", "native_sign_characterized"); value = $true },
    @{ name = "profile_promotion"; path = @("claims", "instrumented_profile_promoted"); value = $true },
    @{ name = "release"; path = @("claims", "release_authority"); value = $true }
    @{ name = "predecessor_mutation"; path = @("prospective_source", "r24d5_source_or_result_mutation_allowed"); value = $true }
    @{ name = "default_serializer_control"; path = @("serialized_runtime_controls", "default_precision_envelope_must_fail_real_evaluator"); value = $false }
    @{ name = "dictionary_order"; path = @("evaluation_contract", "dictionary_key_order_is_semantic"); value = $true }
    @{ name = "serialized_claim"; path = @("claims", "serialized_full_precision_envelope_zero_world_qualified"); value = $true }
)
$rejectedContractMutations = 0
foreach ($mutation in $contractMutations) {
    $candidate = Copy-R24D6Value $contract
    $target = $candidate
    $mutationPath = @($mutation.path)
    for ($index = 0; $index -lt $mutationPath.Count - 1; $index++) {
        $target = [hashtable]$target[$mutationPath[$index]]
    }
    $target[$mutationPath[-1]] = $mutation.value
    try {
        Assert-R24D6Contract $candidate
    } catch {
        $rejectedContractMutations += 1
        continue
    }
    throw "QSDK-R24D6 freeze accepted contract mutation: $($mutation.name)"
}
Assert-R24D6 ($rejectedContractMutations -eq 18) "contract_mutation_count"

$receipt = [ordered]@{
    ok = $true
    gate_id = "QSDK-R24D6"
    question_class = "development"
    source_binding_count = 11
    prior_official_zero_world_failure_count = 1
    fixture_cell_count = 9
    retained_sample_count = 68
    evaluator_negative_control_count = 29
    accepted_outcome_mutation_count = 2
    contract_mutation_rejection_count = 18
    binary32_projection_control_count = 5
    serialized_runtime_negative_control_count = 1
    serialized_runtime_positive_control_count = 1
    empirical_acceptance_threshold_count = 0
    superiority_margin_count = 0
    equivalence_or_non_inferiority_margin_count = 0
    population_claim_count = 0
    world_attempt_count = 0
    world_build_count = 0
    solver_step_count = 0
    physical_characterization_executed = $false
    recovery_world_opened = $false
    prone_to_standing_world_opened = $false
    instrumented_profile_promoted = $false
    physical_acceptance_authority = $false
    release_authority = $false
}
Write-Output (
    "QSDK_R24D6_ONE_HINGE_TELEMETRY_FREEZE_PASS " +
    ($receipt | ConvertTo-Json -Depth 20 -Compress)
)
