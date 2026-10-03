#requires -Version 7.0

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$turningRoot = Join-Path $repoRoot "sdk\turning"
$predecessorPath = Join-Path $turningRoot (
    "r23d49_rapier_retention_repair_replay_closure_v1.json"
)
$preregistrationPath = Join-Path $turningRoot (
    "r23d50_rapier_cas_path_identity_replay_preregistration_v1.json"
)
$incidentPath = Join-Path $turningRoot (
    "r23d50_prephysical_authority_root_binding_incident_v1.json"
)
$expectedPredecessorHash = (
    "sha256:0cece97ef6b9bb66e52d349dce89ec2e5ebdff83be7fb1a8d2b205a893ae192a"
)

function Assert-R23D50Lineage([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "QSDK-R23D50 LINEAGE: $Message" }
}

function Get-R23D50Hash([string]$Path) {
    return "sha256:" + (
        Get-FileHash -LiteralPath $Path -Algorithm SHA256
    ).Hash.ToLowerInvariant()
}

Assert-R23D50Lineage (
    (git -C $repoRoot rev-parse --show-toplevel).Trim().Replace('/', '\') -ceq
        $repoRoot -and
    (git -C $repoRoot remote get-url origin).Trim() -ceq
        "https://github.com/Slagathore/sporespore.git"
) "repository identity changed"

$predecessor = Get-Content -Raw -LiteralPath $predecessorPath |
    ConvertFrom-Json -AsHashtable -Depth 100
$preregistration = Get-Content -Raw -LiteralPath $preregistrationPath |
    ConvertFrom-Json -AsHashtable -Depth 100
$incident = Get-Content -Raw -LiteralPath $incidentPath |
    ConvertFrom-Json -AsHashtable -Depth 100
$lineage = $preregistration.immutable_lineage
$repair = $preregistration.implementation_repair_boundary
$matrix = $preregistration.frozen_matrix
$measurement = $preregistration.cycle_integrated_measurement
$retention = $preregistration.production_trace_retention_gate

Assert-R23D50Lineage (
    (Get-R23D50Hash $predecessorPath) -ceq $expectedPredecessorHash -and
    [string]$lineage.r23d49_closure_raw_sha256 -ceq $expectedPredecessorHash -and
    [string]$lineage.r23d49_closure_path -ceq
        "sdk/turning/r23d49_rapier_retention_repair_replay_closure_v1.json"
) "R49 closure binding changed"

Assert-R23D50Lineage (
    [bool]$predecessor.identity_consumed -and
    -not [bool]$predecessor.same_identity_rerun_allowed -and
    [string]$predecessor.official_disposition.classification -ceq
        "invalid_or_incomplete_outcome_exposed_rapier_retention_repair_replay" -and
    [int]$predecessor.physical_evidence.observed_world_build_count -eq 3 -and
    [int]$predecessor.physical_evidence.production_trace_retention_count -eq 3 -and
    [int]$predecessor.physical_evidence.official_evaluator_path_false_negative_count -eq 3 -and
    [bool]$lineage.r23d49_identity_consumed -and
    -not [bool]$lineage.r23d49_same_identity_rerun_permitted -and
    [bool]$lineage.r23d49_rapier_worlds_completed_and_traces_retained -and
    [bool]$lineage.r23d49_outcomes_exposed_before_this_preregistration -and
    -not [bool]$lineage.r23d49_postfailure_diagnostic_reinterpreted_as_official -and
    -not [bool]$lineage.historical_world_reused_as_a_new_cell -and
    -not [bool]$lineage.same_identity_rerun_permitted
) "R49 consumed invalid and no-rerun boundary changed"

Assert-R23D50Lineage (
    [string]$incident.schema_version -ceq
        "sporespore_qsdk_r23d50_prephysical_authority_root_binding_incident_v1" -and
    [string]$incident.source_commit -ceq
        "603f5894472d559c54333498b168b47164e5b4e6" -and
    [string]$incident.failure.failure_code -ceq
        "R23D50_PRODUCTION_CAS_BINDING_INVALID" -and
    [int]$incident.failure.model_construction_count -eq 0 -and
    [int]$incident.failure.physical_process_launch_count -eq 0 -and
    [int]$incident.failure.world_attempt_count -eq 0 -and
    [int]$incident.failure.world_build_count -eq 0 -and
    [string]$incident.retained_inputs.canonical_trace.sha256 -ceq
        "sha256:7c18c69f82758b8cae09e129683b8d074e87940abf080e05cd5c1477533df65d" -and
    [bool]$incident.retained_inputs.canonical_trace.production_cas_objects_exist -and
    -not [bool]$incident.disposition.r23d50_physical_identity_consumed -and
    -not [bool]$incident.disposition.same_source_commit_physical_retry_permitted -and
    [bool]$incident.disposition.fresh_clean_push_required -and
    [bool]$incident.disposition.fresh_scoped_attestation_and_adoption_required -and
    -not [bool]$incident.disposition.physical_result
) "zero-world authority-root incident boundary changed"

Assert-R23D50Lineage (
    [string]$preregistration.status -ceq "prospective_zero_world_only" -and
    [string]$preregistration.study_classification -ceq
        "prospective_exact_outcome_exposed_rapier_evidence_implementation_repair_replay" -and
    [string]$repair.single_permitted_change -ceq
        "Compare each existing CAS payload and manifest path with os.path.samefile instead of textual Path equality." -and
    [bool]$repair.complete_cas_binding_verifier_required_before_first_world -and
    [bool]$repair.ordinary_and_windows_extended_same_file_positive_control_required -and
    [bool]$repair.wrong_existing_file_negative_control_required -and
    [bool]$repair.exact_rust_to_python_to_powershell_to_cas_canary_required_before_first_world -and
    [int]$repair.synthetic_trace_row_count -eq 2992 -and
    -not [bool]$repair.controller_behavior_changed -and
    -not [bool]$repair.physics_or_adapter_actuation_changed -and
    -not [bool]$repair.startup_transform_changed -and
    -not [bool]$repair.fixture_or_seed_changed -and
    -not [bool]$repair.command_schedule_changed -and
    -not [bool]$repair.measurement_changed -and
    -not [bool]$repair.physical_threshold_changed -and
    -not [bool]$repair.other_implementation_changes_permitted
) "single-change path-identity repair boundary changed"

Assert-R23D50Lineage (
    @($matrix.ordered_engine_ids).Count -eq 1 -and
    [string]$matrix.ordered_engine_ids[0] -ceq "rapier_parry" -and
    [int]$matrix.declared_cell_count -eq 3 -and
    [int]$matrix.declared_world_count -eq 3 -and
    [int]$matrix.seed -eq 21512 -and
    [bool]$matrix.seed_was_outcome_exposed_before_preregistration -and
    [bool]$matrix.serial_execution_required -and
    [bool]$matrix.all_cells_run_regardless_of_intermediate_outcome -and
    [bool]$measurement.inherited_unchanged_from_r23d31 -and
    -not [bool]$measurement.threshold_changed_from_r23d49 -and
    [bool]$retention.complete_cas_binding_verifier_exercised_required -and
    [int]$retention.ordinary_and_windows_extended_path_positive_control_count -eq 1 -and
    [int]$retention.wrong_existing_file_rejection_count -eq 1 -and
    -not [bool]$preregistration.claims.fresh_rapier_turning_replication -and
    -not [bool]$preregistration.claims.finite_three_engine_turning -and
    -not [bool]$preregistration.claims.cross_engine_equivalence
) "outcome-exposed exact replay boundary changed"

Write-Host (
    "QSDK_R23D50_LINEAGE_PASS predecessor=R23D49 seed=21512 worlds=3 " +
    "preworld_incidents=1 controller_changes=0 evidence_repairs=1 physical=False"
)
