#requires -Version 7.0

[CmdletBinding()]
param([string]$Python = "python")

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$contractRelative = (
    "sdk/recovery/" +
    "r24d4_godot_jolt_one_hinge_telemetry_characterization_" +
    "preregistration_v1.json"
)
$evaluatorRelative = (
    "sdk/recovery/" +
    "r24d4_godot_jolt_one_hinge_telemetry_characterization_evaluator.py"
)
$rigRelative = (
    "scripts/lab/rigs/" +
    "r24d4_godot_jolt_one_hinge_telemetry_rig.gd"
)
$probeRelative = (
    "scripts/lab/rigs/" +
    "r24d4_godot_jolt_telemetry_stepping_probe_body.gd"
)
$workerRelative = (
    "tests/" +
    "test_sdk_qsdk_r24d4_godot_jolt_one_hinge_telemetry_physical_worker.gd"
)
$supervisorRelative = (
    "sdk/run_qsdk_r24d4_one_hinge_telemetry_characterization.ps1"
)
$auditRelative = "tests/test_qsdk_r24d4_one_hinge_telemetry_freeze.ps1"
$manifestRelative = (
    "sdk/recovery/" +
    "r24d4_godot_jolt_one_hinge_telemetry_validation_manifest.json"
)

function Assert-R24D4 {
    param([bool]$Condition, [string]$Code)
    if (-not $Condition) { throw "QSDK-R24D4 freeze: $Code" }
}

function Get-R24D4Path {
    param([Parameter(Mandatory)][string]$Relative)
    return [IO.Path]::GetFullPath((Join-Path $repoRoot $Relative))
}

function Read-R24D4Contract {
    return Get-Content -Raw -LiteralPath (Get-R24D4Path $contractRelative) |
        ConvertFrom-Json -AsHashtable -Depth 100
}

function Copy-R24D4Value {
    param([Parameter(Mandatory)]$Value)
    return $Value | ConvertTo-Json -Depth 100 -Compress |
        ConvertFrom-Json -AsHashtable -Depth 100
}

function Assert-R24D4Contract {
    param([Parameter(Mandatory)][hashtable]$Contract)

    Assert-R24D4 (
        [string]$Contract.schema_version -ceq
        "sporespore_qsdk_r24d4_godot_jolt_one_hinge_telemetry_characterization_preregistration_v1"
    ) "schema_version"
    Assert-R24D4 ([string]$Contract.gate_id -ceq "QSDK-R24D4") "gate_id"
    Assert-R24D4 ([string]$Contract.question_class -ceq "development") (
        "question_class"
    )
    Assert-R24D4 (
        [string]$Contract.status -ceq
        "prospectively_frozen_zero_world_gate_pending_physical_execution_forbidden"
    ) "status"

    $parent = [hashtable]$Contract.parent_authority
    Assert-R24D4 ([string]$parent.gate_id -ceq "QSDK-R24D3") "parent_gate"
    Assert-R24D4 (
        [string]$parent.adopted_console_binary_raw_sha256 -ceq
        "sha256:762ed7137d06284742b53abdde9b98c692ab1e8d3a184458db4d8e7a39782462"
    ) "console_binary_digest"
    Assert-R24D4 (
        [string]$parent.adopted_engine_binary_raw_sha256 -ceq
        "sha256:d0bb895b996fa98ec69a68b9f98ca6ed99af2eb18ef67a0b176ad1a55220278d"
    ) "engine_binary_digest"
    Assert-R24D4 (
        [string]$parent.patch_raw_sha256 -ceq
        "sha256:f067543bc6237a38c0c0935a56b3bbebcd318dc6d82cec1321ea5d52e45dae2f"
    ) "patch_digest"
    foreach ($key in @(
        "parent_result_rewritten",
        "stock_godot_result_rewritten",
        "result_reuse_authority_imported",
        "instrumented_profile_promotion_imported"
    )) {
        Assert-R24D4 (-not [bool]$parent[$key]) "parent_boundary_$key"
    }

    $source = [hashtable]$Contract.prospective_source
    $expectedPaths = [ordered]@{
        rig_path = $rigRelative
        stepping_probe_path = $probeRelative
        worker_path = $workerRelative
        evaluator_path = $evaluatorRelative
        supervisor_path = $supervisorRelative
        freeze_audit_path = $auditRelative
        validation_manifest_path = $manifestRelative
    }
    foreach ($entry in $expectedPaths.GetEnumerator()) {
        Assert-R24D4 ([string]$source[$entry.Key] -ceq [string]$entry.Value) (
            "source_path_$($entry.Key)"
        )
    }
    Assert-R24D4 ([bool]$source.complete_zero_world_gate_required_before_physics) (
        "zero_world_required"
    )
    Assert-R24D4 (
        [bool]$source.engine_and_solver_freeze_must_be_verified_zero_world_and_rechecked_before_build
    ) "zero_world_and_prebuild_engine_freeze"
    Assert-R24D4 (-not [bool]$source.same_source_physical_rerun_allowed) (
        "same_source_rerun"
    )

    $engine = [hashtable]$Contract.engine_and_solver_freeze
    Assert-R24D4 ([string]$engine.physics_engine -ceq "Jolt Physics") (
        "physics_engine"
    )
    Assert-R24D4 ([int]$engine.physics_ticks_per_second -eq 120) "physics_hz"
    Assert-R24D4 ([int]$engine.solver_velocity_steps -eq 20) "velocity_steps"
    Assert-R24D4 ([int]$engine.solver_position_steps -eq 7) "position_steps"
    Assert-R24D4 ([int]$engine.retained_binary_count -eq 2) "binary_count"
    Assert-R24D4 (-not [bool]$engine.runtime_substitution_allowed) (
        "runtime_substitution"
    )

    $fixture = [hashtable]$Contract.fixture_freeze
    Assert-R24D4 ([int]$fixture.world_count -eq 1) "world_count"
    Assert-R24D4 ([int]$fixture.isolated_cell_count -eq 9) "cell_count"
    Assert-R24D4 ([int]$fixture.hinges_per_cell -eq 1) "hinges_per_cell"
    Assert-R24D4 ([int]$fixture.contact_count -eq 0) "contact_count"
    foreach ($key in @(
        "direct_force_write_count",
        "direct_torque_write_count",
        "direct_impulse_write_count",
        "post_activation_transform_write_count"
    )) {
        Assert-R24D4 ([int]$fixture[$key] -eq 0) "fixture_$key"
    }
    Assert-R24D4 (
        [int]$fixture.pre_activation_initial_angular_velocity_write_count -eq 4
    ) "initial_velocity_write_count"
    Assert-R24D4 ([int]$fixture.declared_sleep_input_write_count -eq 1) (
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
    Assert-R24D4 (
        (@($fixture.cell_ids_in_order) -join "|") -ceq
        ($expectedCellIds -join "|")
    ) "cell_identity_order"

    $refusals = [hashtable]$Contract.refusal_and_freshness_controls
    foreach ($key in @(
        "invalid_rid_must_return_null",
        "not_in_tree_joint_read_must_return_null",
        "read_during_integrate_forces_must_return_null",
        "read_during_integrate_forces_attempt_must_be_observed",
        "active_sequence_observed_before_sleep_input",
        "sleeping_sequence_repetition_retained_as_stale_observation"
    )) {
        Assert-R24D4 ([bool]$refusals[$key]) "refusal_control_$key"
    }
    Assert-R24D4 (-not [bool]$refusals.stale_sequence_synthesizes_fresh_data) (
        "stale_sequence_synthesis"
    )
    Assert-R24D4 (-not [bool]$refusals.invalid_read_synthesizes_zero) (
        "invalid_read_synthesis"
    )

    $evaluation = [hashtable]$Contract.evaluation_contract
    Assert-R24D4 (
        [string]$evaluation.classification -ceq
        "complete_valid_or_invalid_descriptive_development_characterization"
    ) "evaluation_class"
    Assert-R24D4 (-not [bool]$evaluation.turning_evaluator_invoked) (
        "turning_evaluator"
    )
    Assert-R24D4 (-not [bool]$evaluation.recovery_evaluator_invoked) (
        "recovery_evaluator"
    )
    Assert-R24D4 ([bool]$evaluation.descriptive_findings_are_not_execution_validity_gates) (
        "descriptive_outcomes"
    )
    Assert-R24D4 (-not [bool]$evaluation.outcome_dependent_early_stop_allowed) (
        "outcome_early_stop"
    )
    Assert-R24D4 (
        [bool]$evaluation.declared_fixture_and_cell_configuration_must_match_exactly
    ) "configuration_identity_gate"
    Assert-R24D4 (
        [bool]$evaluation.runtime_parameter_and_per_sample_public_readbacks_must_match_exactly
    ) "runtime_readback_identity_gate"
    Assert-R24D4 (
        [bool]$evaluation.mandatory_registration_and_refusal_controls_are_validity_gates
    ) "registration_refusal_gate"

    $adequacy = [hashtable]$Contract.threshold_margin_cohort_and_population_adequacy
    foreach ($key in @(
        "empirical_acceptance_threshold_count",
        "superiority_margin_count",
        "equivalence_or_non_inferiority_margin_count",
        "validation_cohort_identity_count",
        "population_claim_count"
    )) {
        Assert-R24D4 ([int]$adequacy[$key] -eq 0) "adequacy_$key"
    }
    Assert-R24D4 ([int]$adequacy.development_fixture_cell_count -eq 9) (
        "development_fixture_count"
    )
    Assert-R24D4 (-not [bool]$adequacy.numerical_residual_acceptance_margin_declared) (
        "numerical_margin"
    )
    Assert-R24D4 (
        ([string]$adequacy.adequacy_argument).Contains(
            "inadequate for profile promotion"
        )
    ) "adequacy_argument"

    $negative = [hashtable]$Contract.negative_controls
    Assert-R24D4 ([int]$negative.declared_count -eq 22) "negative_count"
    Assert-R24D4 (@($negative.required_rejections).Count -eq 22) (
        "negative_identity_count"
    )
    foreach ($requiredRejection in @(
        "cell_configuration_mutation_rejected",
        "parameter_readback_configuration_mutation_rejected",
        "sample_public_readback_configuration_mutation_rejected",
        "engine_registration_mutation_rejected",
        "invalid_rid_refusal_mutation_rejected",
        "unsafe_read_non_refusal_mutation_rejected"
    )) {
        Assert-R24D4 (
            $requiredRejection -cin @($negative.required_rejections)
        ) "negative_identity_$requiredRejection"
    }

    $authorization = [hashtable]$Contract.physical_authorization
    Assert-R24D4 (-not [bool]$authorization.permitted_now) (
        "physical_permission"
    )
    Assert-R24D4 ([int]$authorization.world_attempt_count -eq 0) (
        "physical_attempt_count"
    )
    Assert-R24D4 ([int]$authorization.world_build_count -eq 0) (
        "physical_world_count"
    )
    Assert-R24D4 (-not [bool]$authorization.physical_result_exists) (
        "physical_result"
    )

    $claims = [hashtable]$Contract.claims
    Assert-R24D4 ([bool]$claims.source_and_oracle_freeze_declared) (
        "source_freeze_claim"
    )
    foreach ($key in @(
        "complete_zero_world_gate_passed",
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
        Assert-R24D4 (-not [bool]$claims[$key]) "claim_$key"
    }
}

$root = (& git -C $repoRoot rev-parse --show-toplevel).Trim()
Assert-R24D4 ($LASTEXITCODE -eq 0) "git_root_unavailable"
Assert-R24D4 ([IO.Path]::GetFullPath($root) -ceq $repoRoot) "git_root"
$remote = (& git -C $repoRoot remote get-url origin).Trim()
Assert-R24D4 ($LASTEXITCODE -eq 0) "git_remote_unavailable"
Assert-R24D4 (
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
    $auditRelative
)) {
    Assert-R24D4 (Test-Path -LiteralPath (Get-R24D4Path $relative) -PathType Leaf) (
        "missing_$relative"
    )
}

$contract = Read-R24D4Contract
Assert-R24D4Contract $contract

$rigText = Get-Content -Raw -LiteralPath (Get-R24D4Path $rigRelative)
$probeText = Get-Content -Raw -LiteralPath (Get-R24D4Path $probeRelative)
$workerText = Get-Content -Raw -LiteralPath (Get-R24D4Path $workerRelative)
$evaluatorText = Get-Content -Raw -LiteralPath (Get-R24D4Path $evaluatorRelative)
$supervisorText = Get-Content -Raw -LiteralPath (Get-R24D4Path $supervisorRelative)
Assert-R24D4 (($rigText | Select-String -Pattern '"cell_id":' -AllMatches).Matches.Count -eq 9) (
    "rig_cell_count"
)
Assert-R24D4 ($rigText.Contains("const MAXIMUM_PHYSICS_STEP_COUNT := 20")) (
    "rig_horizon"
)
Assert-R24D4 ($rigText.Contains('-float(spec["canonical_target_velocity_rad_s"])')) (
    "host_sign_mapping"
)
foreach ($forbidden in @(
    ".apply_force(",
    ".apply_central_force(",
    ".apply_torque(",
    ".apply_impulse(",
    ".apply_torque_impulse("
)) {
    Assert-R24D4 (-not $rigText.Contains($forbidden)) "rig_forbidden_$forbidden"
    Assert-R24D4 (-not $workerText.Contains($forbidden)) "worker_forbidden_$forbidden"
}
Assert-R24D4 ($probeText.Contains("func _integrate_forces")) "probe_callback"
Assert-R24D4 ($probeText.Contains("hinge_joint_get_motor_telemetry")) (
    "probe_binding"
)
Assert-R24D4 (-not $probeText.Contains("state.")) "probe_state_write"
Assert-R24D4 ($workerText.Contains('if mode == "zero_world_preflight"')) (
    "worker_zero_world_route"
)
Assert-R24D4 ($workerText.Contains('if mode != "physical"')) (
    "worker_physical_refusal"
)
Assert-R24D4 ($workerText.Contains("func _engine_receipt_is_frozen")) (
    "worker_engine_freeze_predicate"
)
Assert-R24D4 ($workerText.Contains("func _fixture_description_is_frozen")) (
    "worker_fixture_freeze_predicate"
)
Assert-R24D4 (
    (($workerText | Select-String -Pattern 'RigScript\.build\(\)' -AllMatches).Matches.Count) -eq 1
) "worker_build_call_count"
$preflightStart = $workerText.IndexOf("func _run_zero_world_preflight")
$physicalStart = $workerText.IndexOf("func _run_physical")
Assert-R24D4 ($preflightStart -ge 0 -and $physicalStart -gt $preflightStart) (
    "worker_function_order"
)
$preflightText = $workerText.Substring($preflightStart, $physicalStart - $preflightStart)
Assert-R24D4 (-not $preflightText.Contains("RigScript.build")) (
    "zero_world_build_call"
)
Assert-R24D4 ($preflightText.Contains("_engine_receipt_is_frozen(engine)")) (
    "zero_world_engine_freeze_check"
)
Assert-R24D4 ($preflightText.Contains("_fixture_description_is_frozen(description)")) (
    "zero_world_fixture_freeze_check"
)
$physicalText = $workerText.Substring($physicalStart)
$physicalEngineFreeze = $physicalText.IndexOf("_engine_receipt_is_frozen(engine)")
$physicalFixtureFreeze = $physicalText.IndexOf(
    "_fixture_description_is_frozen(description)"
)
$physicalBuild = $physicalText.IndexOf("RigScript.build()")
Assert-R24D4 (
    $physicalEngineFreeze -ge 0 -and
    $physicalFixtureFreeze -gt $physicalEngineFreeze -and
    $physicalBuild -gt $physicalFixtureFreeze
) "physical_freeze_checks_before_world_build"
Assert-R24D4 ($workerText.Contains("QSDK_R24D4_PHYSICAL_RAW_REPORT")) (
    "physical_marker"
)
Assert-R24D4 ($workerText.Contains("QSDK_R24D4_GODOT_SUPERVISOR_TERMINATION_READY")) (
    "termination_marker"
)
Assert-R24D4 ($evaluatorText.Contains("descriptive_findings_are_acceptance_gates")) (
    "threshold_free_evaluation"
)
Assert-R24D4 ($evaluatorText.Contains("accepted_outcome_mutation_count")) (
    "outcome_mutation_control"
)
foreach ($requiredSupervisorToken in @(
    "Enter-SporeSporeLocomotionOperationLock",
    "local_upstream_cached_live_inequality",
    "Assert-R24D4ManifestAndBindings",
    "Get-R24D4MatchingPhysicalAttempts",
    "retained_physical_attempt_unreadable",
    "same_source_physical_attempt_already_exists",
    "physical_run_path_exists",
    "yyyyMMddTHHmmssfffZ",
    "consumed_before_worker_launch",
    "Invoke-SporeSporeGodotReceiptTerminatedProcess",
    "Publish-SporeSporeContentAddressedArtifact",
    "Assert-R24D4RetainedFileAndCas",
    "QSDK_R24D3_COLD_QUALIFICATION_ADOPTION_PASS",
    "zero_world_receipt_identity",
    "zeroReceipt.engine.solver_velocity_steps",
    "zero_world_worker_receipt_log_binding",
    "physical_raw_identity",
    "pre_physical_source_drift"
)) {
    Assert-R24D4 ($supervisorText.Contains($requiredSupervisorToken)) (
        "supervisor_token_$requiredSupervisorToken"
    )
}

$manifest = Get-Content -Raw -LiteralPath (Get-R24D4Path $manifestRelative) |
    ConvertFrom-Json -AsHashtable -Depth 100
Assert-R24D4 (
    [string]$manifest.schema_version -ceq
    "sporespore_qsdk_r24d4_one_hinge_telemetry_validation_manifest_v1"
) "manifest_schema"
Assert-R24D4 ([int]$manifest.source_binding_count -eq 7) (
    "manifest_binding_count"
)
$expectedBindingPaths = @(
    $contractRelative,
    $evaluatorRelative,
    $rigRelative,
    $probeRelative,
    $workerRelative,
    $supervisorRelative,
    $auditRelative
)
$bindings = @($manifest.bindings)
Assert-R24D4 ($bindings.Count -eq 7) "manifest_bindings"
Assert-R24D4 (
    (@($bindings | ForEach-Object { [string]$_.path }) -join "|") -ceq
    ($expectedBindingPaths -join "|")
) "manifest_binding_order"
foreach ($binding in $bindings) {
    $absolute = Get-R24D4Path ([string]$binding.path)
    $hash = (Get-FileHash -LiteralPath $absolute -Algorithm SHA256).
        Hash.ToLowerInvariant()
    $length = (Get-Item -LiteralPath $absolute).Length
    $blob = (& git -C $repoRoot hash-object -- $absolute).Trim()
    Assert-R24D4 ($LASTEXITCODE -eq 0) "manifest_blob_$($binding.path)"
    Assert-R24D4 (
        [string]$binding.raw_sha256 -ceq "sha256:$hash" -and
        [long]$binding.byte_length -eq [long]$length -and
        [string]$binding.git_blob_oid -ceq $blob
    ) "manifest_bytes_$($binding.path)"
}
foreach ($key in @(
    "complete_zero_world_gate_passed",
    "physical_characterization_executed",
    "instrumented_profile_promoted",
    "physical_acceptance_authority",
    "release_authority"
)) {
    Assert-R24D4 (-not [bool]$manifest[$key]) "manifest_claim_$key"
}

$pythonOutput = @(
    & $Python (Get-R24D4Path $evaluatorRelative) --self-test 2>&1
)
Assert-R24D4 ($LASTEXITCODE -eq 0) (
    "evaluator_self_test_exit:$($pythonOutput -join ' | ')"
)
$prefix = "QSDK_R24D4_EVALUATOR_ZERO_WORLD "
$markers = @($pythonOutput | Where-Object {
    ([string]$_).StartsWith($prefix, [StringComparison]::Ordinal)
})
Assert-R24D4 ($markers.Count -eq 1) "evaluator_marker_count"
$evaluatorReceipt = ([string]$markers[0]).Substring($prefix.Length) |
    ConvertFrom-Json -AsHashtable -Depth 100
Assert-R24D4 ([bool]$evaluatorReceipt.ok) "evaluator_ok"
Assert-R24D4 (
    [int]$evaluatorReceipt.rejected_negative_control_count -eq 22
) "evaluator_negative_count"
foreach ($requiredRejection in @(
    "cell_configuration",
    "parameter_readback_configuration",
    "sample_public_readback_configuration",
    "engine_registration",
    "invalid_rid_refusal",
    "unsafe_read_non_refusal"
)) {
    Assert-R24D4 (
        $requiredRejection -cin @($evaluatorReceipt.rejected_negative_controls)
    ) "evaluator_negative_identity_$requiredRejection"
}
Assert-R24D4 (
    [int]$evaluatorReceipt.accepted_outcome_mutation_count -eq 2
) "evaluator_outcome_count"
Assert-R24D4 (
    [int]$evaluatorReceipt.empirical_acceptance_threshold_count -eq 0
) "evaluator_threshold_count"
Assert-R24D4 (
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
    @{ name = "native_sign"; path = @("claims", "native_sign_characterized"); value = $true },
    @{ name = "profile_promotion"; path = @("claims", "instrumented_profile_promoted"); value = $true },
    @{ name = "release"; path = @("claims", "release_authority"); value = $true }
)
$rejectedContractMutations = 0
foreach ($mutation in $contractMutations) {
    $candidate = Copy-R24D4Value $contract
    $target = $candidate
    $mutationPath = @($mutation.path)
    for ($index = 0; $index -lt $mutationPath.Count - 1; $index++) {
        $target = [hashtable]$target[$mutationPath[$index]]
    }
    $target[$mutationPath[-1]] = $mutation.value
    try {
        Assert-R24D4Contract $candidate
    } catch {
        $rejectedContractMutations += 1
        continue
    }
    throw "QSDK-R24D4 freeze accepted contract mutation: $($mutation.name)"
}
Assert-R24D4 ($rejectedContractMutations -eq 12) "contract_mutation_count"

$receipt = [ordered]@{
    ok = $true
    gate_id = "QSDK-R24D4"
    question_class = "development"
    fixture_cell_count = 9
    retained_sample_count = 68
    evaluator_negative_control_count = 22
    accepted_outcome_mutation_count = 2
    contract_mutation_rejection_count = 12
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
    "QSDK_R24D4_ONE_HINGE_TELEMETRY_FREEZE_PASS " +
    ($receipt | ConvertTo-Json -Depth 20 -Compress)
)
