#requires -Version 7.0

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$sdkRoot = Join-Path $repoRoot "sdk"
$turningRoot = Join-Path $sdkRoot "turning"
$traceRoot = Join-Path $sdkRoot "trace_analysis"
$preregistrationPath = Join-Path $turningRoot (
    "r23d54_godot_actuator_phase_characterization_preregistration_v1.json"
)
$implementationPath = Join-Path $turningRoot (
    "r23d54_godot_actuator_phase_characterization_implementation_v1.json"
)
$manifestPath = Join-Path $turningRoot "r23d54_campaign_attestation_manifest_v1.json"
$incidentPath = Join-Path $turningRoot (
    "r23d54_first_scoped_qualification_incident_v1.json"
)
$secondIncidentPath = Join-Path $turningRoot (
    "r23d54_second_scoped_qualification_incident_v1.json"
)
$inventoryIncidentPath = Join-Path $turningRoot (
    "r23d54_post_rc5_pre_attestation_inventory_incident_v1.json"
)
$adoptionIncidentPath = Join-Path $turningRoot (
    "r23d54_campaign_attestation_adoption_executor_drift_incident_v1.json"
)
$rc2FreezePath = Join-Path $sdkRoot (
    "locomotion_campaign_attestation_v1_recommissioning_rc2_freeze.json"
)
$rc2ManifestPath = Join-Path $sdkRoot (
    "locomotion_campaign_attestation_v1_recommissioning_rc2_manifest.json"
)
$rc2IncidentPath = Join-Path $sdkRoot (
    "locomotion_campaign_attestation_v1_recommissioning_rc2_incident.json"
)
$rc3FreezePath = Join-Path $sdkRoot (
    "locomotion_campaign_attestation_v1_recommissioning_rc3_freeze.json"
)
$rc3ManifestPath = Join-Path $sdkRoot (
    "locomotion_campaign_attestation_v1_recommissioning_rc3_manifest.json"
)
$rc3IncidentPath = Join-Path $sdkRoot (
    "locomotion_campaign_attestation_v1_recommissioning_rc3_incident.json"
)
$rc4FreezePath = Join-Path $sdkRoot (
    "locomotion_campaign_attestation_v1_recommissioning_rc4_freeze.json"
)
$rc4ManifestPath = Join-Path $sdkRoot (
    "locomotion_campaign_attestation_v1_recommissioning_rc4_manifest.json"
)
$rc4IncidentPath = Join-Path $sdkRoot (
    "locomotion_campaign_attestation_v1_recommissioning_rc4_incident.json"
)
$rc5FreezePath = Join-Path $sdkRoot (
    "locomotion_campaign_attestation_v1_recommissioning_rc5_freeze.json"
)
$rc5ManifestPath = Join-Path $sdkRoot (
    "locomotion_campaign_attestation_v1_recommissioning_rc5_manifest.json"
)
$rc5ClosurePath = Join-Path $sdkRoot (
    "locomotion_campaign_attestation_v1_recommissioning_rc5_closure.json"
)
$rc5ClosureAuditPath = Join-Path $repoRoot (
    "tests\test_locomotion_campaign_attestation_v1_recommissioning_rc5_closure.ps1"
)
$r53ClosurePath = Join-Path $turningRoot (
    "r23d53_godot_warmup_preserving_origin_reanchor_closure_v1.json"
)
$diagnosisPath = Join-Path $traceRoot (
    "r23d53_godot_command_contrast_diagnosis_closure_v1.json"
)
$observationContractPath = Join-Path $traceRoot (
    "godot_actuator_phase_observation_contract_v1.json"
)
$releasePath = Join-Path $sdkRoot "release\quadruped_release_contract.json"
$matrixPath = Join-Path $sdkRoot "release\quadruped_support_matrix.json"
$workerPath = Join-Path $repoRoot (
    "tests\test_sdk_qsdk_r23d54_godot_jolt_physical_worker.gd"
)
$r53WorkerPath = Join-Path $repoRoot (
    "tests\test_sdk_qsdk_r23d53_godot_jolt_physical_worker.gd"
)
$evaluatorPath = Join-Path $turningRoot (
    "r23d54_godot_actuator_phase_characterization_evaluator.py"
)
$supervisorPath = Join-Path $sdkRoot "run_qsdk_r23d54_supervisor.ps1"

function Assert-R23D54Lineage([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "QSDK-R23D54 lineage: $Message" }
}

function Read-R23D54Json([string]$Path) {
    Assert-R23D54Lineage (Test-Path -LiteralPath $Path -PathType Leaf) (
        "missing authority: $Path"
    )
    return Get-Content -Raw -LiteralPath $Path |
        ConvertFrom-Json -AsHashtable -Depth 100
}

function Get-R23D54Hash([string]$Path) {
    return "sha256:" + (
        Get-FileHash -LiteralPath $Path -Algorithm SHA256
    ).Hash.ToLowerInvariant()
}

function Get-R23D54GdscriptFunctionSource(
    [string]$Source,
    [string]$FunctionName
) {
    $pattern = (
        "(?ms)^func " + [regex]::Escape($FunctionName) +
        "\(.*?(?=^(?:static )?func |\z)"
    )
    $match = [regex]::Match($Source, $pattern)
    Assert-R23D54Lineage $match.Success (
        "missing GDScript function source: $FunctionName"
    )
    return $match.Value.TrimEnd()
}

function Find-R23D54Record($Value) {
    if ($Value -is [Collections.IDictionary]) {
        if ($Value.Contains("prospective_r23d54_actuator_phase_characterization")) {
            return $Value["prospective_r23d54_actuator_phase_characterization"]
        }
        foreach ($child in $Value.Values) {
            $found = Find-R23D54Record $child
            if ($null -ne $found) { return $found }
        }
    } elseif ($Value -is [Collections.IEnumerable] -and $Value -isnot [string]) {
        foreach ($child in $Value) {
            $found = Find-R23D54Record $child
            if ($null -ne $found) { return $found }
        }
    }
    return $null
}

$preregistration = Read-R23D54Json $preregistrationPath
$implementation = Read-R23D54Json $implementationPath
$manifest = Read-R23D54Json $manifestPath
$incident = Read-R23D54Json $incidentPath
$secondIncident = Read-R23D54Json $secondIncidentPath
$inventoryIncident = Read-R23D54Json $inventoryIncidentPath
$adoptionIncident = Read-R23D54Json $adoptionIncidentPath
$rc2Freeze = Read-R23D54Json $rc2FreezePath
$rc2Manifest = Read-R23D54Json $rc2ManifestPath
$rc2Incident = Read-R23D54Json $rc2IncidentPath
$rc3Freeze = Read-R23D54Json $rc3FreezePath
$rc3Manifest = Read-R23D54Json $rc3ManifestPath
$rc3Incident = Read-R23D54Json $rc3IncidentPath
$rc4Freeze = Read-R23D54Json $rc4FreezePath
$rc4Manifest = Read-R23D54Json $rc4ManifestPath
$rc4Incident = Read-R23D54Json $rc4IncidentPath
$rc5Freeze = Read-R23D54Json $rc5FreezePath
$rc5Manifest = Read-R23D54Json $rc5ManifestPath
$rc5Closure = Read-R23D54Json $rc5ClosurePath
$r53 = Read-R23D54Json $r53ClosurePath
$diagnosis = Read-R23D54Json $diagnosisPath
$observationContract = Read-R23D54Json $observationContractPath
$release = Read-R23D54Json $releasePath
$matrix = Read-R23D54Json $matrixPath

$lineage = $preregistration.immutable_lineage
$successor = $preregistration.scientifically_distinct_successor
$frozen = $preregistration.frozen_matrix
$required = $preregistration.required_observation
$characterization = $preregistration.predeclared_characterization
$thresholds = $preregistration.threshold_provenance
$adequacy = $preregistration.adequacy
$claims = $preregistration.claims

Assert-R23D54Lineage (
    [string]$r53.status -ceq
        "closed_consumed_valid_complete_negative_outcome_exposed_godot_warmup_preserving_origin_reanchor_development" -and
    [bool]$r53.identity_consumed -and
    -not [bool]$r53.same_identity_rerun_allowed -and
    [int]$r53.physical_evidence.observed_world_build_count -eq 3 -and
    [bool]$r53.official_result.all_cells_execution_valid -and
    [bool]$r53.official_result.all_cells_common_physical_gates_passed -and
    -not [bool]$r53.official_result.turning_measurement_passed -and
    -not [bool]$r53.claims.finite_three_engine_turning
) "consumed R53 negative boundary changed"

Assert-R23D54Lineage (
    [string]$diagnosis.status -ceq
        "closed_complete_postoutcome_godot_command_contrast_diagnosis" -and
    [bool]$diagnosis.findings.all_600_warmup_rows_identical_across_arms -and
    [bool]$diagnosis.findings.both_desired_heading_contrasts_correct_all_turn_rows -and
    [bool]$diagnosis.findings.negative_held_contrast_majority_correct -and
    -not [bool]$diagnosis.findings.negative_yaw_effect_majority_correct -and
    -not [bool]$diagnosis.findings.actuator_level_attribution_available -and
    [bool]$diagnosis.interpretation.controller_to_physics_directional_conversion_requires_further_attribution -and
    -not [bool]$diagnosis.interpretation.current_trace_can_choose_actuator_or_contact_phase_mechanism -and
    -not [bool]$diagnosis.claim_limits.physical_campaign_opened
) "R53 diagnosis boundary changed"

Assert-R23D54Lineage (
    [string]$observationContract.status -ceq
        "prospective_zero_world_instrumentation_development" -and
    [string]$observationContract.question_class -ceq "development" -and
    [string]$observationContract.production_route.observation_schema -ceq
        "sporespore_godot_jolt_actuator_phase_observation_v1" -and
    [bool]$observationContract.runtime_api_provenance.configured_parameter_readback_only -and
    -not [bool]$observationContract.runtime_api_provenance.measured_motor_torque_available -and
    -not [bool]$observationContract.runtime_api_provenance.measured_motor_impulse_available -and
    [int]$observationContract.execution_boundary.world_build_count -eq 0 -and
    -not [bool]$observationContract.source_boundary.parent_outcome_rewritten
) "zero-world actuator observation contract changed"

$r53Hash = Get-R23D54Hash $r53ClosurePath
$diagnosisHash = Get-R23D54Hash $diagnosisPath
$observationHash = Get-R23D54Hash $observationContractPath
Assert-R23D54Lineage (
    [string]$lineage.development_parent_commit -ceq
        "3046e53a1146bd1604c80f110f90ea1afa5e198b" -and
    [string]$lineage.r23d53_closure_raw_sha256 -ceq $r53Hash -and
    [string]$lineage.r23d53_command_contrast_diagnosis_closure_raw_sha256 -ceq
        $diagnosisHash -and
    [string]$lineage.actuator_phase_observation_contract_raw_sha256 -ceq
        $observationHash -and
    [bool]$lineage.r23d53_identity_consumed -and
    -not [bool]$lineage.r23d53_turning_positive -and
    -not [bool]$lineage.r23d53_result_reinterpreted -and
    -not [bool]$lineage.r23d53_world_reused_as_r23d54_cell -and
    -not [bool]$lineage.r23d53_same_identity_rerun_permitted
) "R54 immutable lineage changed"

Assert-R23D54Lineage (
    [string]$preregistration.status -ceq "prospective_zero_world_only" -and
    [string]$preregistration.question_class -ceq "development" -and
    [string]$preregistration.campaign_id -ceq
        "QSDK-R23D54-GODOT-ACTUATOR-PHASE-CHARACTERIZATION-DEVELOPMENT" -and
    [int]$successor.declared_physics_change_count -eq 0 -and
    [int]$successor.declared_controller_change_count -eq 0 -and
    [int]$successor.declared_measurement_change_count -eq 1 -and
    [bool]$successor.complete_three_cell_matrix_must_be_run -and
    -not [bool]$successor.historical_world_reused_as_r23d54_cell -and
    -not [bool]$successor.r23d53_terminal_or_trace_reused_as_r23d54_cell -and
    -not [bool]$successor.threshold_changed -and
    -not [bool]$successor.fresh_held_out_condition_consumed
) "R54 distinct measurement-only successor changed"

Assert-R23D54Lineage (
    [int]$frozen.declared_cell_count -eq 3 -and
    [int]$frozen.declared_world_count -eq 3 -and
    [int]$frozen.seed -eq 21512 -and
    [int]$frozen.controller_step_count -eq 2992 -and
    [int]$frozen.turn_start_step -eq 600 -and
    [int]$frozen.turn_end_step_exclusive -eq 1800 -and
    [string]$frozen.task_frame_origin_policy_id -ceq
        "warmup_preserving_command_onset_origin_reanchor_v1" -and
    (@($frozen.ordered_arm_ids) -join ",") -ceq
        "reference_zero,positive_heading,negative_heading" -and
    (@($frozen.expected_reanchor_semantic_steps) -join ",") -ceq
        "600,1800,2400" -and
    [bool]$frozen.serial_execution_required -and
    [bool]$frozen.all_cells_run_regardless_of_intermediate_outcome
) "R54 finite matrix changed"

Assert-R23D54Lineage (
    [string]$required.schema_version -ceq
        "sporespore_godot_jolt_actuator_phase_observation_v1" -and
    [int]$required.required_trace_row_count_per_cell -eq 2992 -and
    [int]$required.required_application_count_per_trace_row -eq 8 -and
    [int]$required.required_application_count_per_cell -eq 23936 -and
    [int]$required.required_total_trace_row_count -eq 8976 -and
    [int]$required.required_total_application_count -eq 71808 -and
    [bool]$required.configured_parameter_readback_only -and
    -not [bool]$required.measured_motor_torque_available -and
    -not [bool]$required.measured_motor_impulse_available -and
    [bool]$characterization.classification_depends_only_on_complete_execution_and_observation_integrity -and
    [bool]$characterization.common_physical_gates_are_contextual_not_characterization_acceptance_thresholds -and
    -not [bool]$characterization.turning_gate_invoked -and
    [int]$characterization.mechanism_selection_rule_count -eq 0 -and
    -not [bool]$characterization.postoutcome_threshold_creation_permitted
) "R54 observation or characterization plan changed"

Assert-R23D54Lineage (
    -not [bool]$thresholds.observed_r23d53_values_used_to_set_characterization_thresholds -and
    [int]$thresholds.empirical_characterization_threshold_count -eq 0 -and
    [double]$thresholds.observation_numeric_tolerance -eq 2.5e-7 -and
    [int]$thresholds.threshold_change_count -eq 0 -and
    [bool]$adequacy.outcome_exposed_development_characterization -and
    [bool]$adequacy.all_three_arms_required -and
    -not [bool]$adequacy.causal_mechanism_selection_attempted -and
    -not [bool]$adequacy.turning_acceptance_attempted -and
    -not [bool]$adequacy.population_inference_attempted -and
    -not [bool]$adequacy.cross_engine_equivalence_attempted -and
    -not [bool]$adequacy.fresh_held_out_validation_attempted
) "R54 threshold provenance or adequacy changed"

Assert-R23D54Lineage (
    [string]$implementation.status -ceq "prospective_zero_world_only" -and
    [string]$implementation.question_class -ceq "development" -and
    [int]$implementation.development_boundary.physics_change_count -eq 0 -and
    [int]$implementation.development_boundary.controller_change_count -eq 0 -and
    [int]$implementation.development_boundary.measurement_change_count -eq 1 -and
    [bool]$implementation.actuator_phase_observation.required_on_every_retained_trace_row -and
    [bool]$implementation.evaluator.classification_is_complete_or_invalid_characterization_only -and
    -not [bool]$implementation.evaluator.turning_gate_invoked -and
    [int]$implementation.evaluator.mechanism_selection_rule_count -eq 0 -and
    [bool]$implementation.supervisor.requires_clean_pushed_live_source -and
    [bool]$implementation.supervisor.requires_complete_campaign_local_zero_world_preflight -and
    [bool]$implementation.supervisor.requires_actuator_phase_native_zero_world_gate -and
    [bool]$implementation.scoped_qualification_and_adoption_boundary.
        scoped_qualification_passed_for_qualified_source -and
    [string]$implementation.scoped_qualification_and_adoption_boundary.adoption_status -ceq
        "pending_post_rc5_role_binding_and_inventory_failures_fresh_repaired_qualification_and_fail_closed_adoption_required" -and
    [string]$implementation.second_scoped_qualification_incident.raw_sha256 -ceq
        (Get-R23D54Hash $secondIncidentPath) -and
    [string]$implementation.second_scoped_qualification_incident.failed_source_commit -ceq
        "b92cbcccf296350ac196c84cb9ea8727ea2b2c21" -and
    -not [bool]$implementation.second_scoped_qualification_incident.output_root_created -and
    [int]$implementation.second_scoped_qualification_incident.executed_gate_count -eq 0 -and
    [int]$implementation.second_scoped_qualification_incident.world_build_count -eq 0 -and
    -not [bool]$implementation.second_scoped_qualification_incident.physical_attempt_consumed -and
    [string]$implementation.post_rc5_pre_attestation_inventory_incident.raw_sha256 -ceq
        (Get-R23D54Hash $inventoryIncidentPath) -and
    [int]$implementation.post_rc5_pre_attestation_inventory_incident.
        retained_inventory_audit_count -eq 148 -and
    [int]$implementation.post_rc5_pre_attestation_inventory_incident.
        regenerated_inventory_audit_count -eq 149 -and
    [int]$implementation.post_rc5_pre_attestation_inventory_incident.
        missing_entry_count -eq 1 -and
    -not [bool]$implementation.post_rc5_pre_attestation_inventory_incident.
        failed_live_campaign_gate -and
    -not [bool]$implementation.post_rc5_pre_attestation_inventory_incident.
        failed_scoped_attestation_gate -and
    [int]$implementation.scoped_qualification_and_adoption_boundary.
        commissioned_core_binding_mismatch_count -eq 1 -and
    [string]$implementation.scoped_qualification_and_adoption_boundary.rc2_status -ceq
        "closed_negative_full_stage_1_runtime_profile_mismatch_scoped_not_started" -and
    -not [bool]$implementation.scoped_qualification_and_adoption_boundary.
        rc2_scoped_attempted -and
    -not [bool]$implementation.scoped_qualification_and_adoption_boundary.
        rc2_same_source_rerun_allowed -and
    [string]$implementation.scoped_qualification_and_adoption_boundary.rc3_status -ceq
        "closed_invalid_complete_process_pair_frozen_claim_vector_contradiction" -and
    [bool]$implementation.scoped_qualification_and_adoption_boundary.
        rc3_full_half_passed -and
    [bool]$implementation.scoped_qualification_and_adoption_boundary.
        rc3_scoped_half_passed -and
    [bool]$implementation.scoped_qualification_and_adoption_boundary.
        rc3_pair_completed -and
    -not [bool]$implementation.scoped_qualification_and_adoption_boundary.
        rc3_exact_acceptance_satisfied -and
    -not [bool]$implementation.scoped_qualification_and_adoption_boundary.
        rc3_commissioning_passed -and
    -not [bool]$implementation.scoped_qualification_and_adoption_boundary.
        rc3_same_source_rerun_allowed -and
    [int]$implementation.scoped_qualification_and_adoption_boundary.
        rc3_world_build_count -eq 0 -and
    [string]$implementation.scoped_qualification_and_adoption_boundary.rc4_status -ceq
        "closed_negative_full_stage_1_workbench_proof_digest_mismatch_scoped_not_started" -and
    [bool]$implementation.scoped_qualification_and_adoption_boundary.
        rc4_full_half_attempted -and
    -not [bool]$implementation.scoped_qualification_and_adoption_boundary.
        rc4_pair_completed -and
    -not [bool]$implementation.scoped_qualification_and_adoption_boundary.
        rc4_scoped_attempted -and
    -not [bool]$implementation.scoped_qualification_and_adoption_boundary.
        rc4_commissioning_passed -and
    -not [bool]$implementation.scoped_qualification_and_adoption_boundary.
        rc4_same_source_rerun_allowed -and
    [int]$implementation.scoped_qualification_and_adoption_boundary.
        rc4_workbench_catalog_expected_sha256_repair_count -eq 8 -and
    [int]$implementation.scoped_qualification_and_adoption_boundary.
        rc4_world_build_count -eq 0 -and
    [string]$implementation.scoped_qualification_and_adoption_boundary.
        recommissioning_program_id -ceq
        "LCA1-RC5-WORKBENCH-PROOF-BINDING-REPAIRED-RECOMMISSIONING" -and
    [string]$implementation.scoped_qualification_and_adoption_boundary.
        recommissioning_status -ceq
        "closed_positive_exact_same_source_full_scoped_pair_cas_claim_vector_and_serialization_verified" -and
    [string]$implementation.scoped_qualification_and_adoption_boundary.
        recommissioning_source_commit -ceq
        "ae2ba9d5eee1fb75a46a7b37016d6167b89fab42" -and
    [string]$implementation.scoped_qualification_and_adoption_boundary.
        recommissioning_source_tree_git_oid -ceq
        "24d3a9f10ad07c87d6d573e0a29c65a1c1f18009" -and
    [string]$implementation.scoped_qualification_and_adoption_boundary.
        recommissioning_closure_raw_sha256 -ceq
        (Get-R23D54Hash $rc5ClosurePath) -and
    [string]$implementation.scoped_qualification_and_adoption_boundary.
        recommissioning_closure_audit_raw_sha256 -ceq
        (Get-R23D54Hash $rc5ClosureAuditPath) -and
    [string]$implementation.scoped_qualification_and_adoption_boundary.
        accepted_powershell_version -ceq "7.6.4" -and
    [long]$implementation.scoped_qualification_and_adoption_boundary.
        accepted_powershell_declared_byte_count -eq 85258167 -and
    [bool]$implementation.scoped_qualification_and_adoption_boundary.
        runtime_profile_candidate_preflight_required -and
    [string]$implementation.scoped_qualification_and_adoption_boundary.
        scoped_required_true_claim_key -ceq
        "campaign_local_qualification_passed" -and
    [int]$implementation.scoped_qualification_and_adoption_boundary.
        scoped_required_false_claim_count -eq 10 -and
    [int]$implementation.scoped_qualification_and_adoption_boundary.
        claim_vector_margin -eq 0 -and
    [bool]$implementation.scoped_qualification_and_adoption_boundary.
        complete_fresh_full_scoped_pair_required -and
    [bool]$implementation.scoped_qualification_and_adoption_boundary.
        complete_fresh_full_scoped_pair_completed -and
    [bool]$implementation.scoped_qualification_and_adoption_boundary.
        recommissioning_exact_acceptance_satisfied -and
    [bool]$implementation.scoped_qualification_and_adoption_boundary.
        exact_campaign_local_executor_commissioned -and
    [int]$implementation.scoped_qualification_and_adoption_boundary.
        recommissioning_full_stage_count -eq 8 -and
    [int]$implementation.scoped_qualification_and_adoption_boundary.
        recommissioning_scoped_gate_count -eq 16 -and
    [int]$implementation.scoped_qualification_and_adoption_boundary.
        recommissioning_scoped_cas_reference_count -eq 48 -and
    [int]$implementation.scoped_qualification_and_adoption_boundary.
        recommissioning_physical_world_count -eq 0 -and
    -not [bool]$implementation.scoped_qualification_and_adoption_boundary.
        current_scoped_attestation_reuse_after_source_change_allowed -and
    -not [bool]$implementation.scoped_qualification_and_adoption_boundary.
        physical_launch_prerequisite_satisfied -and
    [int]$implementation.scoped_qualification_and_adoption_boundary.world_build_count -eq 0 -and
    [int]$implementation.claims.physical_world_opened -eq 0 -and
    -not [bool]$implementation.claims.actuator_phase_characterization_complete -and
    -not [bool]$implementation.claims.turning_mechanism_selected -and
    -not [bool]$implementation.claims.godot_jolt_turning_validation
) "R54 implementation or nonclaims changed"

$workerSource = Get-Content -Raw -LiteralPath $workerPath
$r53WorkerSource = Get-Content -Raw -LiteralPath $r53WorkerPath
$evaluatorSource = Get-Content -Raw -LiteralPath $evaluatorPath
$supervisorSource = Get-Content -Raw -LiteralPath $supervisorPath
Assert-R23D54Lineage (
    $workerSource.Contains("R23D54_ACTUATOR_PHASE_OBSERVATION_SCHEMA") -and
    $workerSource.Contains('trace_options["actuator_phase_observation_schema_version"]') -and
    $workerSource.Contains("R23D54_CLOSURE_PATH") -and
    $evaluatorSource.Contains("def characterize_rows") -and
    $evaluatorSource.Contains('"turning_gate_invoked": False') -and
    $evaluatorSource.Contains('"mechanism_selected": False') -and
    $supervisorSource.Contains("actuatorPhaseGateResource") -and
    $supervisorSource.Contains("Get-SporeSporeAttestationSourceIdentity") -and
    $supervisorSource.Contains("-RequireCleanPushedLive")
) "R54 executable role source boundary changed"

$r53Prepare = Get-R23D54GdscriptFunctionSource `
    $r53WorkerSource "_campaign_prepare"
$r54Prepare = (
    Get-R23D54GdscriptFunctionSource $workerSource "_campaign_prepare"
).Replace("R23D54", "R23D53").Replace("r23d54", "r23d53")
Assert-R23D54Lineage ($r54Prepare -ceq $r53Prepare) (
    "R54 physical/controller preparation differs from R53 after identity normalization"
)

$r53RunWave = Get-R23D54GdscriptFunctionSource $r53WorkerSource "_run_wave"
$r54RunWave = Get-R23D54GdscriptFunctionSource $workerSource "_run_wave"
$measurementBlockPattern = (
    '(?ms)\tvar trace_options: Dictionary = \(.*?\n' +
    '\tconfigured\["trace_configuration_sha256"\] = String\(\n' +
    '\t\ttrace_result\.get\("sdk_physical_trace_configuration_sha256", ""\)\n' +
    '\t\)\r?\n'
)
$measurementBlocks = [regex]::Matches($r54RunWave, $measurementBlockPattern)
Assert-R23D54Lineage (
    $measurementBlocks.Count -eq 1 -and
    $measurementBlocks[0].Value.Contains(
        'trace_options["actuator_phase_observation_schema_version"]'
    ) -and
    $measurementBlocks[0].Value.Contains(
        "R23D54WaveGaitScript.compile_sdk_physical_trace_options"
    ) -and
    $measurementBlocks[0].Value.Contains(
        'configured["trace_options"] = trace_options'
    ) -and
    $measurementBlocks[0].Value -cnotmatch
        '(?m)\b(apply_force|apply_impulse|linear_velocity|angular_velocity|global_transform)\b'
) "R54 run-wave measurement block changed or writes physical state"
$r54RunWaveWithoutMeasurement = [regex]::Replace(
    $r54RunWave,
    $measurementBlockPattern,
    "",
    1
).Replace("R23D54", "R23D53").Replace("r23d54", "r23d53")
Assert-R23D54Lineage ($r54RunWaveWithoutMeasurement -ceq $r53RunWave) (
    "R54 run-wave delta exceeds the one declared observation block"
)

Assert-R23D54Lineage (
    [string]$manifest.schema_version -ceq
        "sporespore_locomotion_campaign_attestation_manifest_v1" -and
    [string]$manifest.status -ceq "prospective_zero_world_physical_candidate" -and
    [string]$manifest.campaign_id -ceq $preregistration.campaign_id -and
    [string]$manifest.question_class -ceq "development" -and
    [int]$manifest.declared_physical_world_count -eq 3 -and
    [int]$manifest.declared_lineage_gate_count -eq 3 -and
    [int]$manifest.declared_campaign_gate_count -eq 3 -and
    [int]$manifest.declared_total_gate_count -eq 6 -and
    [int]$manifest.declared_role_binding_count -eq 3 -and
    @($manifest.source_bindings).Count -eq 55 -and
    -not [bool]$manifest.physical_execution_authorized -and
    -not [bool]$manifest.physical_acceptance_authority
) "R54 campaign attestation manifest changed"

$manifestRoleBindings = @($manifest.campaign_role_bindings)
foreach ($role in @("worker", "evaluator", "supervisor")) {
    $roleBinding = @($manifestRoleBindings | Where-Object {
        [string]$_.role -ceq $role
    })
    Assert-R23D54Lineage ($roleBinding.Count -eq 1) (
        "manifest must bind the $role role exactly once"
    )
    $sourcePath = [string]$roleBinding[0].source_path
    $testPath = [string]$roleBinding[0].test_path
    $sourceRows = @($manifest.source_bindings | Where-Object {
        [string]$_.path -ceq $sourcePath
    })
    $testRows = @($manifest.source_bindings | Where-Object {
        [string]$_.path -ceq $testPath
    })
    Assert-R23D54Lineage (
        $sourceRows.Count -eq 1 -and
        $testRows.Count -eq 1 -and
        [string]$roleBinding[0].source_raw_sha256 -ceq
            [string]$sourceRows[0].raw_sha256 -and
        [string]$roleBinding[0].source_raw_sha256 -ceq
            (Get-R23D54Hash (Join-Path $repoRoot $sourcePath)) -and
        [string]$roleBinding[0].test_raw_sha256 -ceq
            [string]$testRows[0].raw_sha256 -and
        [string]$roleBinding[0].test_raw_sha256 -ceq
            (Get-R23D54Hash (Join-Path $repoRoot $testPath))
    ) "manifest $role cross-table source/test digest binding drifted"
}

Assert-R23D54Lineage (
    [string]$incident.status -ceq
        "retained_zero_world_pre_gate_manifest_claim_schema_failure_requires_fresh_clean_push" -and
    [string]$incident.failed_source.commit -ceq
        "be5091cd9dbe6206639df203cf484df51e4167da" -and
    [string]$incident.failed_source.tree_git_oid -ceq
        "5db7a1223be7f1fa73d744420a72d3ecfe033981" -and
    [string]$incident.failed_qualification.failure_boundary -ceq
        "campaign_manifest_validation_before_output_root_creation_operation_lock_or_gate_execution" -and
    [string]$incident.failed_qualification.failure_message -ceq
        "Campaign-local attestation manifest claim schema drifted." -and
    -not [bool]$incident.failed_qualification.output_root_created -and
    [int]$incident.failed_qualification.executed_gate_count -eq 0 -and
    [int]$incident.failed_qualification.world_build_count -eq 0 -and
    -not [bool]$incident.failed_qualification.physical_attempt_consumed -and
    (@($incident.failed_manifest.extra_claim_names) -join ",") -ceq
        "turning_mechanism_selected" -and
    [int]$incident.failed_manifest.declared_claim_count -eq 12 -and
    [int]$incident.failed_manifest.commissioned_claim_count -eq 11 -and
    [bool]$incident.diagnosis.manifest_schema_defect -and
    -not [bool]$incident.diagnosis.controller_or_physics_defect -and
    [bool]$incident.prospective_repair.same_failed_source_qualification_rerun_allowed -eq $false -and
    -not [bool]$incident.prospective_repair.changes_physical_question -and
    -not [bool]$incident.prospective_repair.changes_physics_controller_measurement_threshold_seed_cohort_or_world_count -and
    [bool]$incident.claims.repair_implemented -and
    -not [bool]$incident.claims.repair_qualified -and
    -not [bool]$incident.claims.physical_campaign_executed -and
    -not [bool]$incident.claims.scientific_result
) "R54 first scoped-qualification incident changed"

Assert-R23D54Lineage (
    [string]$secondIncident.status -ceq
        "retained_zero_world_pre_gate_worker_role_digest_binding_failure_requires_fresh_clean_push" -and
    [string]$secondIncident.failed_source.commit -ceq
        "b92cbcccf296350ac196c84cb9ea8727ea2b2c21" -and
    [string]$secondIncident.failed_source.tree_git_oid -ceq
        "57ea7c1e32fde5b0240d80c1d17b7a72f7af5535" -and
    [string]$secondIncident.failed_qualification.failure_message -ceq
        "Campaign-local 'worker' source/test digest binding drifted." -and
    -not [bool]$secondIncident.failed_qualification.output_root_created -and
    [int]$secondIncident.failed_qualification.executed_gate_count -eq 0 -and
    [int]$secondIncident.failed_qualification.world_build_count -eq 0 -and
    -not [bool]$secondIncident.failed_qualification.physical_attempt_consumed -and
    [int]$secondIncident.failed_manifest.mismatching_role_binding_count -eq 1 -and
    [string]$secondIncident.worker_role_binding_mismatch.role -ceq "worker" -and
    [bool]$secondIncident.worker_role_binding_mismatch.source_binding_table_matches_checkout -and
    [bool]$secondIncident.worker_role_binding_mismatch.test_binding_matches_checkout -and
    -not [bool]$secondIncident.worker_role_binding_mismatch.role_source_binding_matches_checkout -and
    [bool]$secondIncident.diagnosis.duplicate_worker_role_binding_digest_stale -and
    -not [bool]$secondIncident.diagnosis.controller_or_physics_defect -and
    -not [bool]$secondIncident.prospective_repair.same_failed_source_qualification_rerun_allowed -and
    [bool]$secondIncident.prospective_repair.same_campaign_identity_may_requalify_from_new_clean_pushed_source -and
    -not [bool]$secondIncident.prospective_repair.physical_campaign_identity_consumed -and
    -not [bool]$secondIncident.prospective_repair.changes_physical_question -and
    -not [bool]$secondIncident.claims.repair_qualified -and
    -not [bool]$secondIncident.claims.physical_campaign_executed -and
    -not [bool]$secondIncident.claims.scientific_result
) "R54 second scoped-qualification incident changed"

Assert-R23D54Lineage (
    [string]$inventoryIncident.status -ceq
        "retained_post_failure_static_zero_world_closure_inventory_drift_requires_fresh_clean_push" -and
    [string]$inventoryIncident.source_where_defect_was_present.commit -ceq
        "b92cbcccf296350ac196c84cb9ea8727ea2b2c21" -and
    [string]$inventoryIncident.discovery.failure_message -ceq
        "Closure evidence-mode executable inventory verification failed" -and
    -not [bool]$inventoryIncident.discovery.failed_live_campaign_gate -and
    -not [bool]$inventoryIncident.discovery.failed_scoped_attestation_gate -and
    [int]$inventoryIncident.discovery.world_build_count -eq 0 -and
    [int]$inventoryIncident.retained_inventory_before_repair.audit_count -eq 148 -and
    [int]$inventoryIncident.executable_regeneration_before_repair.audit_count -eq 149 -and
    [int]$inventoryIncident.executable_regeneration_before_repair.
        cas_path_check_signature_count -eq 70 -and
    [int]$inventoryIncident.executable_regeneration_before_repair.
        pinned_git_blob_signature_count -eq 129 -and
    [int]$inventoryIncident.executable_regeneration_before_repair.
        differing_entry_count -eq 1 -and
    [string]$inventoryIncident.missing_inventory_entry.path -ceq
        "tests/test_locomotion_campaign_attestation_v1_recommissioning_rc5_closure.ps1" -and
    -not [bool]$inventoryIncident.missing_inventory_entry.live_historical_identity_risk -and
    -not [bool]$inventoryIncident.diagnosis.rc5_closure_or_interpretation_changed -and
    -not [bool]$inventoryIncident.prospective_repair.same_b92cbcc_qualification_rerun_allowed -and
    -not [bool]$inventoryIncident.prospective_repair.physical_campaign_identity_consumed -and
    -not [bool]$inventoryIncident.prospective_repair.changes_physical_question -and
    -not [bool]$inventoryIncident.claims.repair_qualified -and
    -not [bool]$inventoryIncident.claims.physical_campaign_executed -and
    -not [bool]$inventoryIncident.claims.scientific_result
) "R54 post-RC5 pre-attestation inventory incident changed"

Assert-R23D54Lineage (
    [string]$adoptionIncident.status -ceq
        "retained_zero_world_adoption_verification_refusal_requires_prospective_full_lca1_recommissioning" -and
    [string]$adoptionIncident.qualified_source.commit -ceq
        "846295d1506626f7909d8045b992e2aa6a16f1c7" -and
    [string]$adoptionIncident.qualified_source.tree_git_oid -ceq
        "5564205d632170eba928c3568627c1f842933d52" -and
    [string]$adoptionIncident.scoped_qualification.raw_sha256 -ceq
        "sha256:298d25f9a4218e51271924954823ffdcdf96ec4fb6caeeb87f1723431f290b1e" -and
    [int]$adoptionIncident.scoped_qualification.executed_gate_count -eq 18 -and
    [int]$adoptionIncident.scoped_qualification.gate_cas_object_count -eq 54 -and
    [int]$adoptionIncident.scoped_qualification.physical_world_count -eq 0 -and
    [bool]$adoptionIncident.scoped_qualification.campaign_local_qualification_passed -and
    -not [bool]$adoptionIncident.scoped_qualification.physical_launch_prerequisite_satisfied -and
    [string]$adoptionIncident.adoption_verification_refusal.failure_message -ceq
        "Commissioned executor source changed: sdk/run_conformance.ps1" -and
    -not [bool]$adoptionIncident.adoption_verification_refusal.adoption_document_created -and
    [int]$adoptionIncident.commissioned_executor_comparison.matching_core_source_binding_count -eq 9 -and
    [int]$adoptionIncident.commissioned_executor_comparison.mismatching_core_source_binding_count -eq 1 -and
    [string]$adoptionIncident.commissioned_executor_comparison.mismatching_path -ceq
        "sdk/run_conformance.ps1" -and
    [bool]$adoptionIncident.required_successor_boundary.complete_fresh_full_godot_v2_required -and
    [bool]$adoptionIncident.required_successor_boundary.fresh_scoped_lca1_required -and
    -not [bool]$adoptionIncident.claims.r23d54_scoped_qualification_adopted -and
    -not [bool]$adoptionIncident.claims.physical_campaign_executed
) "R54 scoped qualification or adoption-refusal incident changed"

$qualifiedAttestationPath = [string]$adoptionIncident.scoped_qualification.path
$qualifiedAttestation = Read-R23D54Json $qualifiedAttestationPath
Assert-R23D54Lineage (
    (Get-R23D54Hash $qualifiedAttestationPath) -ceq
        [string]$adoptionIncident.scoped_qualification.raw_sha256 -and
    (Get-Item -LiteralPath $qualifiedAttestationPath).Length -eq
        [long]$adoptionIncident.scoped_qualification.byte_length -and
    [string]$qualifiedAttestation.source.commit -ceq
        [string]$adoptionIncident.qualified_source.commit -and
    [string]$qualifiedAttestation.source.tree_git_oid -ceq
        [string]$adoptionIncident.qualified_source.tree_git_oid -and
    [int]$qualifiedAttestation.executed_gate_count -eq 18 -and
    @($qualifiedAttestation.gate_receipts).Count -eq 18 -and
    @($qualifiedAttestation.gate_receipts | Where-Object {
        -not [bool]$_.passed -or [int]$_.physical_world_count -ne 0
    }).Count -eq 0 -and
    [bool]$qualifiedAttestation.claims.campaign_local_qualification_passed -and
    -not [bool]$qualifiedAttestation.claims.physical_launch_prerequisite_satisfied
) "retained R54 scoped qualification changed"

Assert-R23D54Lineage (
    [string]$rc2Freeze.status -ceq
        "prospective_zero_world_complete_cold_full_scoped_pair_required" -and
    [string]$rc2Freeze.program_id -ceq
        "LCA1-RC2-EXPANDED-CANONICAL-RUNNER-RECOMMISSIONING" -and
    [string]$rc2Freeze.question_class -ceq "equivalence_non_inferiority" -and
    -not [bool]$rc2Freeze.physical_question -and
    [int]$rc2Freeze.prospective_pair.pair_count -eq 1 -and
    -not [bool]$rc2Freeze.prospective_pair.prior_result_reuse_allowed -and
    [int]$rc2Freeze.estimand_and_exact_acceptance.full_required_stage_count -eq 8 -and
    [int]$rc2Freeze.estimand_and_exact_acceptance.scoped_required_executed_gate_count -eq 16 -and
    [int]$rc2Freeze.estimand_and_exact_acceptance.scoped_required_gate_cas_object_count -eq 48 -and
    [int]$rc2Freeze.estimand_and_exact_acceptance.numeric_equivalence_margin -eq 0 -and
    [bool]$rc2Freeze.estimand_and_exact_acceptance.duration_ratio_is_descriptive_only -and
    -not [bool]$rc2Freeze.claims.rc2_pair_executed -and
    -not [bool]$rc2Freeze.claims.current_executor_commissioned -and
    [string]$rc2Manifest.campaign_id -ceq [string]$rc2Freeze.program_id -and
    [string]$rc2Manifest.question_class -ceq "equivalence_non_inferiority" -and
    [int]$rc2Manifest.declared_physical_world_count -eq 0 -and
    @($rc2Manifest.claims.Values | Where-Object { [bool]$_ }).Count -eq 0
) "immutable prospective LCA1 RC2 declaration changed"

Assert-R23D54Lineage (
    [string]$rc2Incident.status -ceq
        "closed_negative_full_stage_1_runtime_profile_mismatch_scoped_not_started" -and
    [string]$rc2Incident.question_class -ceq "equivalence_non_inferiority" -and
    -not [bool]$rc2Incident.physical_question -and
    [string]$rc2Incident.observed_source_identity.commit -ceq
        "0d5c44986a4783269fead70b14472fcdbace7736" -and
    [int]$rc2Incident.cold_full_v2.stage_receipt_count -eq 1 -and
    [string]$rc2Incident.cold_full_v2.failure_message -ceq
        "PowerShell runtime profile file count or byte count changed." -and
    -not [bool]$rc2Incident.cold_scoped_lca1.attempted -and
    [int]$rc2Incident.cold_scoped_lca1.gate_execution_count -eq 0 -and
    [long]$rc2Incident.runtime_profile_comparison.attempted_runtime.byte_count_delta -eq
        145113 -and
    -not [bool]$rc2Incident.interpretation.same_source_rerun_authorized -and
    -not [bool]$rc2Incident.claims.rc2_pair_completed -and
    -not [bool]$rc2Incident.claims.current_executor_commissioned -and
    -not [bool]$rc2Incident.claims.physical_campaign_executed
) "retained LCA1 RC2 negative changed"

Assert-R23D54Lineage (
    [string]$rc3Freeze.status -ceq
        "prospective_zero_world_runtime_pinned_complete_cold_full_scoped_pair_required" -and
    [string]$rc3Freeze.program_id -ceq
        "LCA1-RC3-RUNTIME-PINNED-EXPANDED-CANONICAL-RUNNER-RECOMMISSIONING" -and
    [string]$rc3Freeze.question_class -ceq "equivalence_non_inferiority" -and
    -not [bool]$rc3Freeze.physical_question -and
    [string]$rc3Freeze.immutable_rc2_negative.incident_raw_sha256 -ceq
        (Get-R23D54Hash $rc2IncidentPath) -and
    -not [bool]$rc3Freeze.immutable_rc2_negative.same_source_rerun_allowed -and
    [string]$rc3Freeze.accepted_runtime.powershell_version -ceq "7.6.4" -and
    [int]$rc3Freeze.accepted_runtime.declared_file_count -eq 86 -and
    [long]$rc3Freeze.accepted_runtime.declared_byte_count -eq 85258167 -and
    [bool]$rc3Freeze.accepted_runtime.runtime_profile_candidate_preflight_required -and
    [int]$rc3Freeze.prospective_pair.pair_count -eq 1 -and
    -not [bool]$rc3Freeze.prospective_pair.prior_result_reuse_allowed -and
    [int]$rc3Freeze.estimand_and_exact_acceptance.full_required_stage_count -eq 8 -and
    [int]$rc3Freeze.estimand_and_exact_acceptance.scoped_required_executed_gate_count -eq 16 -and
    [int]$rc3Freeze.estimand_and_exact_acceptance.scoped_required_gate_cas_object_count -eq 48 -and
    [int]$rc3Freeze.estimand_and_exact_acceptance.numeric_equivalence_margin -eq 0 -and
    -not [bool]$rc3Freeze.claims.rc3_pair_executed -and
    -not [bool]$rc3Freeze.claims.current_executor_commissioned -and
    [string]$rc3Manifest.campaign_id -ceq [string]$rc3Freeze.program_id -and
    [string]$rc3Manifest.question_class -ceq "equivalence_non_inferiority" -and
    [int]$rc3Manifest.declared_physical_world_count -eq 0 -and
    @($rc3Manifest.claims.Values | Where-Object { [bool]$_ }).Count -eq 0
) "immutable LCA1 RC3 preregistration boundary changed"

Assert-R23D54Lineage (
    [string]$rc3Incident.status -ceq
        "closed_invalid_complete_process_pair_frozen_claim_vector_contradiction" -and
    [string]$rc3Incident.question_class -ceq "equivalence_non_inferiority" -and
    -not [bool]$rc3Incident.physical_question -and
    [string]$rc3Incident.observed_source_identity.commit -ceq
        "3cdc4a8cafecf40051c5f6dea1b186fccb991cc8" -and
    [int]$rc3Incident.cold_full_v2.stage_receipt_count -eq 8 -and
    [int]$rc3Incident.cold_full_v2.failed_stage_count -eq 0 -and
    [int]$rc3Incident.cold_scoped_lca1.executed_gate_count -eq 16 -and
    [int]$rc3Incident.cold_scoped_lca1.gate_cas_reference_count -eq 48 -and
    (@($rc3Incident.cold_scoped_lca1.observed_true_claim_keys) -join "|") -ceq
        "campaign_local_qualification_passed" -and
    -not [bool]$rc3Incident.exact_acceptance_comparison.
        literal_frozen_claim_vector_condition_satisfied -and
    -not [bool]$rc3Incident.exact_acceptance_comparison.
        complete_exact_acceptance_satisfied -and
    -not [bool]$rc3Incident.interpretation.commissioning_passed -and
    -not [bool]$rc3Incident.interpretation.same_source_rerun_authorized -and
    [int]$rc3Incident.cold_scoped_lca1.physical_worlds_opened -eq 0 -and
    -not [bool]$rc3Incident.claims.current_executor_commissioned
) "retained LCA1 RC3 invalid result changed"

Assert-R23D54Lineage (
    [string]$rc4Freeze.status -ceq
        "prospective_zero_world_schema_aligned_claim_vector_complete_cold_full_scoped_pair_required" -and
    [string]$rc4Freeze.program_id -ceq
        "LCA1-RC4-SCHEMA-ALIGNED-CLAIM-VECTOR-RECOMMISSIONING" -and
    [string]$rc4Freeze.question_class -ceq "equivalence_non_inferiority" -and
    -not [bool]$rc4Freeze.physical_question -and
    [string]$rc4Freeze.trigger.rc3_incident_raw_sha256 -ceq
        (Get-R23D54Hash $rc3IncidentPath) -and
    -not [bool]$rc4Freeze.trigger.rc3_exact_acceptance_satisfied -and
    -not [bool]$rc4Freeze.trigger.rc3_same_source_rerun_allowed -and
    [bool]$rc4Freeze.candidate_executor.runner_bytes_match_rc3_candidate -and
    -not [bool]$rc4Freeze.candidate_executor.complete_source_tree_matches_rc3 -and
    -not [bool]$rc4Freeze.candidate_executor.complete_transitive_dependency_key -and
    [string]$rc4Freeze.accepted_runtime.powershell_version -ceq "7.6.4" -and
    [int]$rc4Freeze.accepted_runtime.declared_file_count -eq 86 -and
    [long]$rc4Freeze.accepted_runtime.declared_byte_count -eq 85258167 -and
    [int]$rc4Freeze.prospective_pair.pair_count -eq 1 -and
    -not [bool]$rc4Freeze.prospective_pair.prior_result_reuse_allowed -and
    [int]$rc4Freeze.estimand_and_exact_acceptance.full_required_stage_count -eq 8 -and
    [int]$rc4Freeze.estimand_and_exact_acceptance.
        scoped_required_executed_gate_count -eq 16 -and
    [int]$rc4Freeze.estimand_and_exact_acceptance.
        scoped_required_gate_cas_object_count -eq 48 -and
    (@($rc4Freeze.estimand_and_exact_acceptance.
        scoped_attestation_required_true_claim_keys) -join "|") -ceq
        "campaign_local_qualification_passed" -and
    @($rc4Freeze.estimand_and_exact_acceptance.
        scoped_attestation_required_false_claim_keys).Count -eq 10 -and
    [int]$rc4Freeze.estimand_and_exact_acceptance.claim_vector_margin -eq 0 -and
    [string]$rc4Manifest.campaign_id -ceq [string]$rc4Freeze.program_id -and
    [string]$rc4Manifest.question_class -ceq "equivalence_non_inferiority" -and
    [int]$rc4Manifest.declared_physical_world_count -eq 0 -and
    @($rc4Manifest.claims.Values | Where-Object { [bool]$_ }).Count -eq 0 -and
    @($rc4Freeze.claims.Values | Where-Object { [bool]$_ }).Count -eq 0
) "immutable LCA1 RC4 preregistration boundary changed"

Assert-R23D54Lineage (
    [string]$rc4Incident.status -ceq
        "closed_negative_full_stage_1_workbench_proof_digest_mismatch_scoped_not_started" -and
    [string]$rc4Incident.question_class -ceq "equivalence_non_inferiority" -and
    -not [bool]$rc4Incident.physical_question -and
    [string]$rc4Incident.observed_source_identity.commit -ceq
        "78aee8886209102f5cb9d5c167886c739cbe0ff7" -and
    [int]$rc4Incident.cold_full_v2.stage_receipt_count -eq 1 -and
    [int]$rc4Incident.cold_full_v2.failed_stage_count -eq 1 -and
    [string]$rc4Incident.cold_full_v2.first_failed_stage_id -ceq
        "authority_and_historical_closures" -and
    [string]$rc4Incident.workbench_proof_binding_diagnosis.
        observed_first_failed_proof_path -ceq
        "sdk/release/quadruped_release_contract.json" -and
    [int]$rc4Incident.workbench_proof_binding_diagnosis.
        release_contract.catalog_reference_count -eq 4 -and
    [int]$rc4Incident.workbench_proof_binding_diagnosis.
        support_matrix.catalog_reference_count -eq 4 -and
    [int]$rc4Incident.workbench_proof_binding_diagnosis.
        catalog_expected_sha256_field_repair_count -eq 8 -and
    -not [bool]$rc4Incident.cold_scoped_lca1.attempted -and
    -not [bool]$rc4Incident.interpretation.executor_semantics_evaluated -and
    -not [bool]$rc4Incident.interpretation.same_source_rerun_authorized -and
    [int]$rc4Incident.cold_full_v2.world_build_count -eq 0 -and
    -not [bool]$rc4Incident.claims.current_executor_commissioned
) "retained LCA1 RC4 process-input negative changed"

Assert-R23D54Lineage (
    [string]$rc5Freeze.status -ceq
        "prospective_zero_world_workbench_proof_binding_repaired_complete_cold_full_scoped_pair_required" -and
    [string]$rc5Freeze.program_id -ceq
        "LCA1-RC5-WORKBENCH-PROOF-BINDING-REPAIRED-RECOMMISSIONING" -and
    [string]$rc5Freeze.question_class -ceq "equivalence_non_inferiority" -and
    -not [bool]$rc5Freeze.physical_question -and
    [string]$rc5Freeze.trigger.rc4_incident_raw_sha256 -ceq
        (Get-R23D54Hash $rc4IncidentPath) -and
    -not [bool]$rc5Freeze.trigger.rc4_pair_completed -and
    -not [bool]$rc5Freeze.trigger.rc4_same_source_rerun_allowed -and
    [int]$rc5Freeze.workbench_proof_binding_repair.
        catalog_expected_sha256_field_repair_count -eq 8 -and
    [bool]$rc5Freeze.workbench_proof_binding_repair.
        every_repaired_proof_matches_current_ledger_bytes -and
    [bool]$rc5Freeze.workbench_proof_binding_repair.
        workbench_audit_passed_after_repair -and
    -not [bool]$rc5Freeze.workbench_proof_binding_repair.
        executor_runner_source_changed -and
    [bool]$rc5Freeze.candidate_executor.runner_bytes_match_rc4_candidate -and
    -not [bool]$rc5Freeze.candidate_executor.complete_source_tree_matches_rc4 -and
    -not [bool]$rc5Freeze.candidate_executor.complete_transitive_dependency_key -and
    [string]$rc5Freeze.accepted_runtime.powershell_version -ceq "7.6.4" -and
    [int]$rc5Freeze.prospective_pair.pair_count -eq 1 -and
    -not [bool]$rc5Freeze.prospective_pair.prior_result_reuse_allowed -and
    [int]$rc5Freeze.estimand_and_exact_acceptance.full_required_stage_count -eq 8 -and
    [int]$rc5Freeze.estimand_and_exact_acceptance.
        scoped_required_executed_gate_count -eq 16 -and
    [int]$rc5Freeze.estimand_and_exact_acceptance.
        scoped_required_gate_cas_object_count -eq 48 -and
    (@($rc5Freeze.estimand_and_exact_acceptance.
        scoped_attestation_required_true_claim_keys) -join "|") -ceq
        "campaign_local_qualification_passed" -and
    @($rc5Freeze.estimand_and_exact_acceptance.
        scoped_attestation_required_false_claim_keys).Count -eq 10 -and
    [int]$rc5Freeze.estimand_and_exact_acceptance.claim_vector_margin -eq 0 -and
    [string]$rc5Manifest.campaign_id -ceq [string]$rc5Freeze.program_id -and
    [string]$rc5Manifest.question_class -ceq "equivalence_non_inferiority" -and
    [int]$rc5Manifest.declared_physical_world_count -eq 0 -and
    @($rc5Manifest.source_bindings).Count -eq 39 -and
    @($rc5Manifest.claims.Values | Where-Object { [bool]$_ }).Count -eq 0 -and
    @($rc5Freeze.claims.Values | Where-Object { [bool]$_ }).Count -eq 0
) "prospective LCA1 RC5 recommissioning boundary changed"

$rc5ClosureAuditOutput = @(
    & pwsh -NoLogo -NoProfile -File $rc5ClosureAuditPath 2>&1
)
Assert-R23D54Lineage (
    $LASTEXITCODE -eq 0 -and
    @($rc5ClosureAuditOutput | Where-Object {
        [string]$_ -clike "LCA1_RC5_CLOSURE_PASS *"
    }).Count -eq 1 -and
    [string]$rc5Closure.status -ceq
        "closed_positive_exact_same_source_full_scoped_pair_cas_claim_vector_and_serialization_verified" -and
    [string]$rc5Closure.question_class -ceq "equivalence_non_inferiority" -and
    [string]$rc5Closure.commissioned_implementation_source.commit -ceq
        "ae2ba9d5eee1fb75a46a7b37016d6167b89fab42" -and
    [bool]$rc5Closure.comparison.exact_acceptance_satisfied -and
    [bool]$rc5Closure.comparison.commissioning_passed -and
    [int]$rc5Closure.full_v2.required_stage_count -eq 8 -and
    [int]$rc5Closure.scoped_lca1.executed_gate_count -eq 16 -and
    [int]$rc5Closure.scoped_lca1.gate_cas_reference_count -eq 48 -and
    [int]$rc5Closure.scoped_lca1.physical_world_count -eq 0 -and
    [bool]$rc5Closure.claims.campaign_local_attestation_implementation_commissioned -and
    -not [bool]$rc5Closure.claims.r23d54_physical_launch_prerequisite_satisfied -and
    -not [bool]$rc5Closure.claims.turning_acceptance -and
    -not [bool]$rc5Closure.claims.prone_to_stand_acceptance -and
    -not [bool]$rc5Closure.claims.physical_acceptance_authority
) "positive LCA1 RC5 closure or audit changed"

$turningGate = @(
    $release.gates |
        Where-Object { [string]$_['gate_id'] -ceq "QSDK-R23" }
)
Assert-R23D54Lineage ($turningGate.Count -eq 1) (
    "release contract must contain exactly one QSDK-R23 gate"
)
$releaseRecord = $turningGate[0]['proof']['prospective_r23d54_actuator_phase_characterization']
$matrixRecord = Find-R23D54Record $matrix
$preregistrationHash = Get-R23D54Hash $preregistrationPath
$implementationHash = Get-R23D54Hash $implementationPath
Assert-R23D54Lineage (
    $null -ne $releaseRecord -and
    $null -ne $matrixRecord -and
    [string]$releaseRecord.status -ceq "prospective_zero_world_only" -and
    [string]$matrixRecord.status -ceq "prospective_zero_world_only" -and
    [string]$releaseRecord.campaign_id -ceq $preregistration.campaign_id -and
    [string]$matrixRecord.campaign_id -ceq $preregistration.campaign_id -and
    [string]$releaseRecord.preregistration_raw_sha256 -ceq $preregistrationHash -and
    [string]$matrixRecord.preregistration_sha256 -ceq $preregistrationHash -and
    [string]$releaseRecord.implementation_raw_sha256 -ceq $implementationHash -and
    [string]$matrixRecord.implementation_sha256 -ceq $implementationHash -and
    [string]$releaseRecord.campaign_local_qualification_status -ceq
        "failed_b92cbcc_pre_gate_worker_role_digest_binding_with_postfailure_static_rc5_closure_inventory_drift_zero_world_fresh_repaired_source_qualification_required" -and
    [string]$matrixRecord.campaign_local_qualification_status -ceq
        "failed_b92cbcc_pre_gate_worker_role_digest_binding_with_postfailure_static_rc5_closure_inventory_drift_zero_world_fresh_repaired_source_qualification_required" -and
    [string]$releaseRecord.campaign_local_adoption_status -ceq
        "pending_post_rc5_role_binding_and_inventory_failures_fresh_repaired_source_qualification_and_fail_closed_adoption_required" -and
    [string]$matrixRecord.campaign_local_adoption_status -ceq
        "pending_post_rc5_role_binding_and_inventory_failures_fresh_repaired_source_qualification_and_fail_closed_adoption_required" -and
    [string]$releaseRecord.second_scoped_qualification_incident_raw_sha256 -ceq
        (Get-R23D54Hash $secondIncidentPath) -and
    [string]$matrixRecord.second_scoped_qualification_incident_sha256 -ceq
        (Get-R23D54Hash $secondIncidentPath) -and
    [string]$releaseRecord.second_scoped_qualification_source_commit -ceq
        "b92cbcccf296350ac196c84cb9ea8727ea2b2c21" -and
    [string]$matrixRecord.second_scoped_qualification_source_commit -ceq
        "b92cbcccf296350ac196c84cb9ea8727ea2b2c21" -and
    -not [bool]$releaseRecord.second_scoped_qualification_output_root_created -and
    -not [bool]$matrixRecord.second_scoped_qualification_output_root_created -and
    [int]$releaseRecord.second_scoped_qualification_executed_gate_count -eq 0 -and
    [int]$matrixRecord.second_scoped_qualification_executed_gate_count -eq 0 -and
    -not [bool]$releaseRecord.second_scoped_qualification_physical_attempt_consumed -and
    -not [bool]$matrixRecord.second_scoped_qualification_physical_attempt_consumed -and
    [string]$releaseRecord.post_rc5_pre_attestation_inventory_incident_raw_sha256 -ceq
        (Get-R23D54Hash $inventoryIncidentPath) -and
    [string]$matrixRecord.post_rc5_pre_attestation_inventory_incident_sha256 -ceq
        (Get-R23D54Hash $inventoryIncidentPath) -and
    [int]$releaseRecord.post_rc5_pre_attestation_inventory_audit_count_before -eq 148 -and
    [int]$matrixRecord.post_rc5_pre_attestation_inventory_audit_count_before -eq 148 -and
    [int]$releaseRecord.post_rc5_pre_attestation_inventory_audit_count_after -eq 149 -and
    [int]$matrixRecord.post_rc5_pre_attestation_inventory_audit_count_after -eq 149 -and
    -not [bool]$releaseRecord.post_rc5_pre_attestation_inventory_failed_live_campaign_gate -and
    -not [bool]$matrixRecord.post_rc5_pre_attestation_inventory_failed_live_campaign_gate -and
    -not [bool]$releaseRecord.post_rc5_pre_attestation_inventory_physical_attempt_consumed -and
    -not [bool]$matrixRecord.post_rc5_pre_attestation_inventory_physical_attempt_consumed -and
    [string]$releaseRecord.lca1_rc2_status -ceq [string]$rc2Incident.status -and
    [string]$matrixRecord.lca1_rc2_status -ceq [string]$rc2Incident.status -and
    [string]$releaseRecord.lca1_rc2_incident_raw_sha256 -ceq
        (Get-R23D54Hash $rc2IncidentPath) -and
    [string]$matrixRecord.lca1_rc2_incident_sha256 -ceq
        (Get-R23D54Hash $rc2IncidentPath) -and
    -not [bool]$releaseRecord.lca1_rc2_same_source_rerun_allowed -and
    -not [bool]$matrixRecord.lca1_rc2_same_source_rerun_allowed -and
    [string]$releaseRecord.lca1_rc3_freeze_path -ceq
        "sdk/locomotion_campaign_attestation_v1_recommissioning_rc3_freeze.json" -and
    [string]$matrixRecord.lca1_rc3_freeze_path -ceq
        "sdk/locomotion_campaign_attestation_v1_recommissioning_rc3_freeze.json" -and
    [string]$releaseRecord.lca1_rc3_accepted_powershell_version -ceq "7.6.4" -and
    [string]$matrixRecord.lca1_rc3_accepted_powershell_version -ceq "7.6.4" -and
    [long]$releaseRecord.lca1_rc3_accepted_powershell_declared_byte_count -eq
        85258167 -and
    [long]$matrixRecord.lca1_rc3_accepted_powershell_declared_byte_count -eq
        85258167 -and
    [bool]$releaseRecord.lca1_rc3_runtime_profile_candidate_preflight_required -and
    [bool]$matrixRecord.lca1_rc3_runtime_profile_candidate_preflight_required -and
    [string]$releaseRecord.lca1_rc3_status -ceq [string]$rc3Incident.status -and
    [string]$matrixRecord.lca1_rc3_status -ceq [string]$rc3Incident.status -and
    [string]$releaseRecord.lca1_rc3_incident_raw_sha256 -ceq
        (Get-R23D54Hash $rc3IncidentPath) -and
    [string]$matrixRecord.lca1_rc3_incident_sha256 -ceq
        (Get-R23D54Hash $rc3IncidentPath) -and
    [bool]$releaseRecord.lca1_rc3_full_half_passed -and
    [bool]$matrixRecord.lca1_rc3_full_half_passed -and
    [bool]$releaseRecord.lca1_rc3_scoped_half_passed -and
    [bool]$matrixRecord.lca1_rc3_scoped_half_passed -and
    -not [bool]$releaseRecord.lca1_rc3_exact_acceptance_satisfied -and
    -not [bool]$matrixRecord.lca1_rc3_exact_acceptance_satisfied -and
    -not [bool]$releaseRecord.lca1_rc3_commissioning_passed -and
    -not [bool]$matrixRecord.lca1_rc3_commissioning_passed -and
    -not [bool]$releaseRecord.lca1_rc3_same_source_rerun_allowed -and
    -not [bool]$matrixRecord.lca1_rc3_same_source_rerun_allowed -and
    [string]$releaseRecord.lca1_rc4_freeze_path -ceq
        "sdk/locomotion_campaign_attestation_v1_recommissioning_rc4_freeze.json" -and
    [string]$matrixRecord.lca1_rc4_freeze_path -ceq
        "sdk/locomotion_campaign_attestation_v1_recommissioning_rc4_freeze.json" -and
    [string]$releaseRecord.lca1_rc4_manifest_path -ceq
        "sdk/locomotion_campaign_attestation_v1_recommissioning_rc4_manifest.json" -and
    [string]$matrixRecord.lca1_rc4_manifest_path -ceq
        "sdk/locomotion_campaign_attestation_v1_recommissioning_rc4_manifest.json" -and
    [string]$releaseRecord.lca1_rc4_required_scoped_true_claim_key -ceq
        "campaign_local_qualification_passed" -and
    [string]$matrixRecord.lca1_rc4_required_scoped_true_claim_key -ceq
        "campaign_local_qualification_passed" -and
    [int]$releaseRecord.lca1_rc4_required_scoped_false_claim_count -eq 10 -and
    [int]$matrixRecord.lca1_rc4_required_scoped_false_claim_count -eq 10 -and
    [int]$releaseRecord.lca1_rc4_claim_vector_margin -eq 0 -and
    [int]$matrixRecord.lca1_rc4_claim_vector_margin -eq 0 -and
    [string]$releaseRecord.lca1_rc4_status -ceq [string]$rc4Incident.status -and
    [string]$matrixRecord.lca1_rc4_status -ceq [string]$rc4Incident.status -and
    [string]$releaseRecord.lca1_rc4_incident_raw_sha256 -ceq
        (Get-R23D54Hash $rc4IncidentPath) -and
    [string]$matrixRecord.lca1_rc4_incident_sha256 -ceq
        (Get-R23D54Hash $rc4IncidentPath) -and
    [bool]$releaseRecord.lca1_rc4_full_half_attempted -and
    [bool]$matrixRecord.lca1_rc4_full_half_attempted -and
    -not [bool]$releaseRecord.lca1_rc4_pair_completed -and
    -not [bool]$matrixRecord.lca1_rc4_pair_completed -and
    -not [bool]$releaseRecord.lca1_rc4_scoped_attempted -and
    -not [bool]$matrixRecord.lca1_rc4_scoped_attempted -and
    -not [bool]$releaseRecord.lca1_rc4_commissioning_passed -and
    -not [bool]$matrixRecord.lca1_rc4_commissioning_passed -and
    -not [bool]$releaseRecord.lca1_rc4_same_source_rerun_allowed -and
    -not [bool]$matrixRecord.lca1_rc4_same_source_rerun_allowed -and
    [int]$releaseRecord.lca1_rc4_workbench_catalog_expected_sha256_repair_count -eq 8 -and
    [int]$matrixRecord.lca1_rc4_workbench_catalog_expected_sha256_repair_count -eq 8 -and
    [string]$releaseRecord.lca1_rc5_freeze_path -ceq
        "sdk/locomotion_campaign_attestation_v1_recommissioning_rc5_freeze.json" -and
    [string]$matrixRecord.lca1_rc5_freeze_path -ceq
        "sdk/locomotion_campaign_attestation_v1_recommissioning_rc5_freeze.json" -and
    [string]$releaseRecord.lca1_rc5_manifest_path -ceq
        "sdk/locomotion_campaign_attestation_v1_recommissioning_rc5_manifest.json" -and
    [string]$matrixRecord.lca1_rc5_manifest_path -ceq
        "sdk/locomotion_campaign_attestation_v1_recommissioning_rc5_manifest.json" -and
    [int]$releaseRecord.lca1_rc5_workbench_catalog_expected_sha256_repair_count -eq 8 -and
    [int]$matrixRecord.lca1_rc5_workbench_catalog_expected_sha256_repair_count -eq 8 -and
    [string]$releaseRecord.lca1_rc5_required_scoped_true_claim_key -ceq
        "campaign_local_qualification_passed" -and
    [string]$matrixRecord.lca1_rc5_required_scoped_true_claim_key -ceq
        "campaign_local_qualification_passed" -and
    [int]$releaseRecord.lca1_rc5_required_scoped_false_claim_count -eq 10 -and
    [int]$matrixRecord.lca1_rc5_required_scoped_false_claim_count -eq 10 -and
    [int]$releaseRecord.lca1_rc5_claim_vector_margin -eq 0 -and
    [int]$matrixRecord.lca1_rc5_claim_vector_margin -eq 0 -and
    [string]$releaseRecord.lca1_rc5_status -ceq [string]$rc5Closure.status -and
    [string]$matrixRecord.lca1_rc5_status -ceq [string]$rc5Closure.status -and
    [string]$releaseRecord.lca1_rc5_closure_raw_sha256 -ceq
        (Get-R23D54Hash $rc5ClosurePath) -and
    [string]$matrixRecord.lca1_rc5_closure_sha256 -ceq
        (Get-R23D54Hash $rc5ClosurePath) -and
    [string]$releaseRecord.lca1_rc5_closure_audit_raw_sha256 -ceq
        (Get-R23D54Hash $rc5ClosureAuditPath) -and
    [string]$matrixRecord.lca1_rc5_closure_audit_sha256 -ceq
        (Get-R23D54Hash $rc5ClosureAuditPath) -and
    [int]$releaseRecord.lca1_rc5_full_stage_count -eq 8 -and
    [int]$matrixRecord.lca1_rc5_full_stage_count -eq 8 -and
    [int]$releaseRecord.lca1_rc5_scoped_executed_gate_count -eq 16 -and
    [int]$matrixRecord.lca1_rc5_scoped_executed_gate_count -eq 16 -and
    [int]$releaseRecord.lca1_rc5_scoped_gate_cas_reference_count -eq 48 -and
    [int]$matrixRecord.lca1_rc5_scoped_gate_cas_reference_count -eq 48 -and
    [bool]$releaseRecord.lca1_rc5_exact_acceptance_satisfied -and
    [bool]$matrixRecord.lca1_rc5_exact_acceptance_satisfied -and
    [bool]$releaseRecord.lca1_rc5_executor_commissioned -and
    [bool]$matrixRecord.lca1_rc5_executor_commissioned -and
    -not [bool]$releaseRecord.physical_launch_prerequisite_satisfied -and
    -not [bool]$matrixRecord.physical_launch_prerequisite_satisfied -and
    [int]$releaseRecord.declared_world_count -eq 3 -and
    [int]$matrixRecord.declared_world_count -eq 3 -and
    [int]$releaseRecord.world_build_count -eq 0 -and
    [int]$matrixRecord.world_build_count -eq 0 -and
    -not [bool]$releaseRecord.physical_execution_authorized -and
    -not [bool]$matrixRecord.physical_execution_authorized -and
    -not [bool]$releaseRecord.turning_acceptance -and
    -not [bool]$matrixRecord.turning_acceptance -and
    -not [bool]$releaseRecord.release_authority -and
    -not [bool]$matrixRecord.release_authority
) "release/support prospective R54 mirror changed"

Assert-R23D54Lineage (
    -not [bool]$claims.physical_world_opened -and
    -not [bool]$claims.actuator_phase_characterization_complete -and
    -not [bool]$claims.turning_mechanism_selected -and
    -not [bool]$claims.godot_jolt_turning_validation -and
    -not [bool]$claims.finite_three_engine_turning -and
    -not [bool]$claims.portable_basic_turning -and
    -not [bool]$claims.prone_to_standing -and
    -not [bool]$claims.release_authorized -and
    -not [bool]$claims.physical_acceptance_authority
) "R54 prospective claims inflated"

Write-Host (
    "QSDK_R23D54_LINEAGE_PASS class=development cells=3 worlds=0 " +
    "physics_changes=0 controller_changes=0 measurement_changes=1 " +
    "observation_rows=8976 applications=71808 qualification_incidents=2 pre_attestation_incidents=1 rc5_commissioned=True " +
    "physical_prerequisite=False mechanism=False turning=False"
)
