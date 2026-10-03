#requires -Version 7.0

[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$sdkRoot = Join-Path $repoRoot "sdk"
$contractPath = Join-Path $sdkRoot "turning\r23d8_implementation_contract_v1.json"
$preregistrationPath = Join-Path $sdkRoot (
    "turning\r23d8_scientific_execution_contract_v1.json"
)
$stageZeroPath = Join-Path $sdkRoot (
    "turning\r23d8_authorization_closed_preregistration_v1.json"
)
$inheritedScientificPath = Join-Path $sdkRoot (
    "turning\r23d7_neutral_stance_preregistration_v1.json"
)
$r23d7ClosurePath = Join-Path $sdkRoot "turning\r23d7_physical_closure_v1.json"
$incidentPath = Join-Path $sdkRoot (
    "turning\r23d8_pre_attempt_authorization_canary_incident_v1.json"
)
$incidentAuditPath = Join-Path $repoRoot (
    "tests\test_qsdk_r23d8_pre_attempt_authorization_canary_incident.ps1"
)
$dependencyComposerPath = Join-Path $sdkRoot "turning\r23d8_dependency_closure.ps1"
$terminalClassifierPath = Join-Path $sdkRoot "turning\r23d8_terminal_marker_classifier.ps1"
$mujocoClosurePath = Join-Path $sdkRoot (
    "mujoco_c6_bw19v_selected_policy_pose_hold_restoration_mv6_closure.json"
)
$rapierClosurePath = Join-Path $sdkRoot (
    "rapier_c6_bw19v_velocity_only_pose_hold_restoration_ph1_closure.json"
)

. $dependencyComposerPath

function Assert-R23D8ImplementationExact {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function Get-R23D8ImplementationRawSha256 {
    param([Parameter(Mandatory)][string]$Path)
    return "sha256:" + (
        Get-FileHash -LiteralPath $Path -Algorithm SHA256
    ).Hash.ToLowerInvariant()
}

function Invoke-R23D8ImplementationGit {
    param([Parameter(Mandatory)][string[]]$Arguments)
    $output = @(& git -C $repoRoot @Arguments 2>&1)
    Assert-R23D8ImplementationExact ($LASTEXITCODE -eq 0) (
        "QSDK-R23D8 implementation audit git failure: git " +
        ($Arguments -join " ") + ": " + ($output -join " ")
    )
    return ($output -join "`n").Trim()
}

function Assert-R23D8SourceContains {
    param(
        [Parameter(Mandatory)][string]$RelativePath,
        [Parameter(Mandatory)][string[]]$Tokens
    )
    $path = Join-Path $repoRoot $RelativePath
    Assert-R23D8ImplementationExact (
        Test-Path -LiteralPath $path -PathType Leaf
    ) "QSDK-R23D8 implementation source missing: $RelativePath"
    $source = [IO.File]::ReadAllText($path)
    foreach ($token in $Tokens) {
        Assert-R23D8ImplementationExact ($source.Contains($token)) (
            "QSDK-R23D8 implementation seam missing from ${RelativePath}: $token"
        )
    }
}

Assert-R23D8ImplementationExact (
    (Invoke-R23D8ImplementationGit @("rev-parse", "--show-toplevel")).Replace("/", "\") `
        -ceq $repoRoot -and
    (Invoke-R23D8ImplementationGit @("remote", "get-url", "origin")) -ceq
        "https://github.com/Slagathore/sporespore.git"
) "QSDK-R23D8 implementation audit repository identity mismatch"

foreach ($path in @(
    $contractPath,
    $preregistrationPath,
    $stageZeroPath,
    $inheritedScientificPath,
    $r23d7ClosurePath,
    $incidentPath,
    $incidentAuditPath,
    $dependencyComposerPath,
    $terminalClassifierPath,
    $mujocoClosurePath,
    $rapierClosurePath
)) {
    Assert-R23D8ImplementationExact (
        Test-Path -LiteralPath $path -PathType Leaf
    ) "QSDK-R23D8 implementation authority missing: $path"
}

$contract = Get-Content -Raw -LiteralPath $contractPath |
    ConvertFrom-Json -AsHashtable -Depth 100
$preregistration = Get-Content -Raw -LiteralPath $preregistrationPath |
    ConvertFrom-Json -AsHashtable -Depth 100

Assert-R23D8ImplementationExact (
    [string]$contract.schema_version -ceq
        "sporespore_qsdk_r23d8_implementation_contract_v1" -and
    [string]$contract.status -ceq
        "implementation_complete_zero_world_requalified_after_retained_pre_attempt_canary_manifest_field_repair_pending_clean_push_full_attestation_and_production_authorization_canaries" -and
    [string]$contract.campaign_id -ceq
        "QSDK-R23D8-AUTHORIZATION-CLOSED-NEUTRAL-STANCE-BILATERAL-TURN-DEVELOPMENT" -and
    [string]$contract.gate_id -ceq "QSDK-R23D8" -and
    @($contract.workers).Count -eq 3 -and
    @($contract.workers.engine_id) -join "," -ceq
        "mujoco,rapier_parry,godot_jolt" -and
    [int]$contract.fixed_schedule.turning_controller_step_count -eq 2992 -and
    [int]$contract.fixed_schedule.terminal_stance_step_count -eq 540 -and
    [int]$contract.fixed_schedule.passive_zero_actuation_step_count -eq 240 -and
    [int]$contract.fixed_schedule.total_trace_row_count_per_cell -eq 3772 -and
    [int]$contract.fixed_schedule.active_native_application_count_per_cell -eq 28256 -and
    [int]$contract.supervisor.stage_a_world_count -eq 2 -and
    [int]$contract.supervisor.stage_b_world_count_if_launched -eq 9 -and
    [bool]$contract.supervisor.stage_a_serial_without_outcome_early_stop -and
    [bool]$contract.supervisor.stage_b_serial_without_outcome_early_stop -and
    [bool]$contract.supervisor.stage_a_authorization_is_immutable_before_first_stage_a_world -and
    [bool]$contract.supervisor.stage_b_authorization_is_fresh_immutable_and_created_only_after_valid_selection -and
    [bool]$contract.supervisor.stage_a_authorization_is_never_mutated_to_open_stage_b -and
    [bool]$contract.supervisor.source_binding_path_composer_exercised_in_preflight -and
    [bool]$contract.supervisor.external_runtime_binding_path_resolver_exercised_in_preflight -and
    [bool]$contract.supervisor.external_runtime_binding_uses_first_application_match_only -and
    [bool]$contract.supervisor.resolved_runtime_paths_used_for_process_launch_and_worker_trace_retention -and
    [bool]$contract.supervisor.mutable_lifecycle_status_is_not_duplicated_in_physical_supervisor -and
    [bool]$contract.supervisor.evaluator_stdout_stderr_exit_code_and_output_manifest_retained -and
    [bool]$contract.supervisor.dependency_manifest_composer_exercised_before_input_cas_and_attempt_authorization -and
    [bool]$contract.supervisor.worker_required_sets_are_verified_as_source_binding_subsets -and
    [bool]$contract.supervisor.process_stdout_stderr_and_required_engine_log_retained_before_marker_interpretation -and
    [bool]$contract.supervisor.shared_terminal_marker_classifier_required -and
    [bool]$contract.supervisor.every_launched_process_gets_a_content_addressed_terminal_entry -and
    [bool]$contract.supervisor.production_authorization_canaries_required_before_physical_attempt_authorization -and
    [bool]$contract.supervisor.production_authorization_canary_receipt_embedded_in_stage_authorization -and
    [bool]$contract.supervisor.source_reverified_after_canaries_before_physical_lock -and
    [bool]$contract.supervisor.authorization_canary_runner_preflight_required_in_complete_zero_world_gate -and
    [int]$contract.dependency_closure.declared_worker_count -eq 3 -and
    [int]$contract.dependency_closure.declared_unique_dependency_count -eq 28 -and
    [bool]$contract.dependency_closure.one_required_dependency_manifest_authority -and
    -not [bool]$contract.dependency_closure.worker_local_ordered_dependency_tuple_permitted -and
    -not [bool]$contract.dependency_closure.worker_local_duplicate_dependency_manifest_permitted -and
    [bool]$contract.dependency_closure.workers_must_parse_required_paths_from_this_object -and
    [bool]$contract.production_authorization_canaries.same_function_as_physical_execution_required -and
    -not [bool]$contract.production_authorization_canaries.canary_specific_authorization_shortcut_permitted -and
    [int]$contract.production_authorization_canaries.positive_canary_count -eq 3 -and
    [int]$contract.production_authorization_canaries.mutated_binding_refusal_canary_count -eq 3 -and
    [bool]$contract.production_authorization_canaries.full_godot_attestation_required -and
    [bool]$contract.production_authorization_canaries.clean_pushed_live_source_required -and
    [bool]$contract.production_authorization_canaries.test_only_evidence_root_deleted_before_pass_receipt -and
    [string]$contract.production_authorization_canaries.runner_preflight_marker -ceq
        "QSDK_R23D8_AUTHORIZATION_CANARY_PREFLIGHT_PASS" -and
    [bool]$contract.production_authorization_canaries.runner_preflight_requires_no_attestation -and
    [int]$contract.production_authorization_canaries.runner_preflight_process_launch_count -eq 0 -and
    [bool]$contract.production_authorization_canaries.runner_manifest_worker_count_derived_from_ordered_worker_ids -and
    [int]$contract.production_authorization_canaries.model_construction_count -eq 0 -and
    [int]$contract.production_authorization_canaries.world_build_count -eq 0 -and
    [bool]$contract.terminal_marker_contract.retained_before_marker_interpretation_required -and
    [bool]$contract.terminal_marker_contract.zero_many_mixed_malformed_and_exit_marker_mismatch_fail_closed -and
    [bool]$contract.terminal_marker_contract.process_start_exceptions_and_classifier_failures_still_require_terminal_entry_cas -and
    [bool]$contract.runtime_freeze.source_bindings_must_equal_git_blob_bytes -and
    [bool]$contract.runtime_freeze.msvc_brepro_required -and
    [bool]$contract.runtime_freeze.pdb_alt_path_bare_name_required -and
    [bool]$contract.runtime_freeze.cargo_locked_offline_required -and
    -not [bool]$contract.authorization.physical_execution_authorized -and
    -not [bool]$contract.authorization.physical_acceptance_authority -and
    [int]$contract.authorization.world_attempt_count -eq 0 -and
    [int]$contract.authorization.world_build_count -eq 0
) "QSDK-R23D8 implementation contract identity changed"

Assert-R23D8ImplementationExact (
    [string]$preregistration.schema_version -ceq
        "sporespore_qsdk_r23d8_neutral_stance_preregistration_v1" -and
    [string]$preregistration.campaign_id -ceq [string]$contract.campaign_id -and
    [string]$preregistration.gate_id -ceq [string]$contract.gate_id -and
    [int]$preregistration.stage_a_mujoco_terminal_stance_screen.declared_cell_count -eq 2 -and
    [int]$preregistration.stage_b_three_engine_confirmation.declared_cell_count_if_launched -eq 9 -and
    -not [bool]$preregistration.authorization.physical_execution_authorized
) "QSDK-R23D8 preregistration identity changed"

Assert-R23D8ImplementationExact (
    (Get-R23D8ImplementationRawSha256 $preregistrationPath) -ceq
        [string]$contract.preregistration_raw_sha256 -and
    (Get-R23D8ImplementationRawSha256 $stageZeroPath) -ceq
        [string]$contract.stage_zero_declaration_raw_sha256 -and
    (Get-R23D8ImplementationRawSha256 $inheritedScientificPath) -ceq
        [string]$contract.inherited_scientific_contract_raw_sha256 -and
    (Get-R23D8ImplementationRawSha256 $r23d7ClosurePath) -ceq
        [string]$contract.closed_predecessor_raw_sha256 -and
    [string]$contract.pre_attempt_incident_path -ceq
        "sdk/turning/r23d8_pre_attempt_authorization_canary_incident_v1.json" -and
    (Get-R23D8ImplementationRawSha256 $incidentPath) -ceq
        [string]$contract.pre_attempt_incident_raw_sha256 -and
    (Get-R23D8ImplementationRawSha256 $mujocoClosurePath) -ceq
        "sha256:5da3675d848c1d127419c43f009fb430c4f02abd2a55da730ea70fca6d3cee09" -and
    (Get-R23D8ImplementationRawSha256 $rapierClosurePath) -ceq
        "sha256:e2fd42545d59908db69f9fe34a18453afafe4273a02618be0b531f6443e040db"
) "QSDK-R23D8 frozen lineage digest changed"

$paths = [Collections.Generic.List[string]]::new()
foreach ($relative in @($contract.source_binding_policy.exact_paths)) {
    $paths.Add(([string]$relative).Replace("\", "/"))
}
foreach ($prefix in @($contract.source_binding_policy.tracked_prefixes)) {
    $expanded = @((Invoke-R23D8ImplementationGit @(
        "ls-files", "--", [string]$prefix
    )) -split "`n" | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    Assert-R23D8ImplementationExact ($expanded.Count -gt 0) (
        "QSDK-R23D8 source prefix expanded to zero files: $prefix"
    )
    foreach ($relative in $expanded) { $paths.Add($relative.Replace("\", "/")) }
}
$duplicates = @($paths | Group-Object | Where-Object Count -gt 1)
Assert-R23D8ImplementationExact ($duplicates.Count -eq 0) (
    "QSDK-R23D8 source binding policy contains duplicates: " +
    (@($duplicates | ForEach-Object { [string]$_.Name }) -join ",")
)
foreach ($relative in $paths) {
    Assert-R23D8ImplementationExact (
        Test-Path -LiteralPath (Join-Path $repoRoot $relative) -PathType Leaf
    ) "QSDK-R23D8 declared source binding is missing: $relative"
}
$dependencyManifest = Get-R23D8DependencyManifest -RepoRoot $repoRoot
$sourcePathSet = [Collections.Generic.HashSet[string]]::new(
    [StringComparer]::Ordinal
)
foreach ($relative in $paths) { [void]$sourcePathSet.Add([string]$relative) }
$dependencyPathsMissingFromFreeze = @(
    @($dependencyManifest.union_paths) | Where-Object {
        -not $sourcePathSet.Contains([string]$_)
    }
)
Assert-R23D8ImplementationExact (
    [int]$dependencyManifest.unique_dependency_count -eq 28 -and
    $dependencyPathsMissingFromFreeze.Count -eq 0
) (
    "QSDK-R23D8 implementation freeze does not cover dependency union: " +
    ($dependencyPathsMissingFromFreeze -join ",")
)

Assert-R23D8SourceContains "sdk/run_qsdk_r23d8_supervisor.ps1" @(
    "Get-SporeSporeAttestationSourceIdentity",
    "Publish-SporeSporeContentAddressedArtifact",
    "Get-R23D8DependencyManifest",
    "Test-R23D8DependencyReceiptClosure",
    "Get-R23D8TerminalMarkerClassification",
    "sporespore_qsdk_r23d8_process_retention_receipt_v1",
    "retained_before_marker_interpretation = `$true",
    "terminal_marker_classification = `$classification",
    "Initialize-R23D8RuntimeArtifacts",
    "Resolve-R23D8ApplicationPath",
    "Get-Command",
    "-CommandType Application",
    "`$matches[0].Source",
    "`$developmentExternalRuntimeBindings.Count -eq 4",
    "SPORESPORE_QSDK_R23D8_PYTHON = `$resolvedPythonPath",
    "SPORESPORE_QSDK_R23D8_POWERSHELL = `$resolvedPowerShellPath",
    "Write-R23D8Manifest",
    "QSDK_R23D8_STAGE_A_EVALUATION ",
    "QSDK_R23D8_COMPLETE_EVALUATION ",
    "stage_b_launch_authorized",
    "selected_terminal_restoration_policy_id",
    "frozen_supervisor_only_physical_authorized",
    "QSDK_R23D8_AUTHORIZATION_CANARIES_PASS ",
    "production_authorization_canaries_valid = `$true",
    "production_authorization_canaries = `$AuthorizationCanaryReceipt",
    "source_changed_during_authorization_canaries",
    "replacement_or_selective_rerun_permitted = `$false"
)
Assert-R23D8SourceContains ".gitattributes" @(
    "sdk/turning/r23d8_* text eol=lf",
    "sdk/run_qsdk_r23d8_*.ps1 text eol=lf",
    "tests/test_sdk_qsdk_r23d8_*.gd text eol=lf",
    "sdk/adapters/rapier/src/bin/qsdk_r23d8_*.rs text eol=lf",
    "sdk/adapters/mujoco/sporespore_mujoco_adapter/qsdk_r23d8_*.py text eol=lf"
)
Assert-R23D8ImplementationExact (
    -not [IO.File]::ReadAllText(
        (Join-Path $repoRoot "sdk/run_qsdk_r23d8_supervisor.ps1")
    ).Contains(
        "implementation.status"
    )
) "QSDK-R23D8 supervisor duplicates mutable implementation status"
$supervisorSource = [IO.File]::ReadAllText(
    (Join-Path $repoRoot "sdk/run_qsdk_r23d8_supervisor.ps1")
)
Assert-R23D8ImplementationExact (
    $supervisorSource.Contains(
        '"$engineId`__neutral_stance__$armId"',
        [StringComparison]::Ordinal
    ) -and
    -not $supervisorSource.Contains(
        '"$engineId`__onset_600__$armId"',
        [StringComparison]::Ordinal
    )
) "QSDK-R23D8 supervisor Stage B cell identity is not neutral-stance exact"
$evaluatorSource = [IO.File]::ReadAllText(
    (Join-Path $repoRoot "sdk/turning/r23d8_physical_evaluator.py")
)
Assert-R23D8ImplementationExact (
    $supervisorSource.Contains(
        "selected_policy_id_if_passing",
        [StringComparison]::Ordinal
    ) -and
    $supervisorSource.Contains(
        '$selectedPolicy -ceq $selectedNeutralStancePolicyId',
        [StringComparison]::Ordinal
    ) -and
    $evaluatorSource.Contains(
        "else design.RESTORATION_POLICY_ID",
        [StringComparison]::Ordinal
    ) -and
    -not $supervisorSource.Contains(
        '"contact_acquisition_pose_hold_v1"',
        [StringComparison]::Ordinal
    ) -and
    -not $evaluatorSource.Contains(
        '"contact_acquisition_pose_hold_v1"',
        [StringComparison]::Ordinal
    )
) "QSDK-R23D8 Stage A selection does not bind the declared neutral-stance policy"
$processCasIndex = $supervisorSource.IndexOf(
    '$processCas = Publish-SporeSporeContentAddressedArtifact',
    [StringComparison]::Ordinal
)
$classifierIndex = $supervisorSource.IndexOf(
    '$classification = Get-R23D8TerminalMarkerClassification',
    [StringComparison]::Ordinal
)
$terminalCasIndex = $supervisorSource.IndexOf(
    '$terminalCas = Publish-SporeSporeContentAddressedArtifact',
    [StringComparison]::Ordinal
)
Assert-R23D8ImplementationExact (
    $processCasIndex -ge 0 -and
    $classifierIndex -gt $processCasIndex -and
    $terminalCasIndex -gt $classifierIndex -and
    -not $supervisorSource.Contains('$terminalLines.Count')
) "QSDK-R23D8 process retention, classification, and terminal CAS order changed"
Assert-R23D8SourceContains (
    "sdk/adapters/mujoco/sporespore_mujoco_adapter/qsdk_r23d8_neutral_stance.py"
) @(
    "_physical_authorization(cell, source_commit)",
    'declared_value = implementation["dependency_closure"]',
    'len(set(declared_value)) != len(declared_value)',
    "QSDK_R23D8_MUJOCO_AUTHORIZATION_PREFLIGHT ",
    '_retain_trace(cell, rows, authorization["attempt_root"])',
    'f"{cell.stage_id}__{cell.cell_id}.rows.json"',
    "design.phase_for_trace_step(",
    'counters["neutral_stance_receipt_count"] += 1',
    "QSDK_R23D8_TERMINAL "
)
Assert-R23D8SourceContains (
    "sdk/adapters/rapier/src/qsdk_r23d3_phase_balanced.rs"
) @(
    "fn r23d8_physical_authorization(",
    'implementation["dependency_closure"]["required_dependency_paths_by_worker"]["rapier_parry"]',
    "run_qsdk_r23d8_rapier_authorization_preflight",
    "fn r23d8_retain_trace(",
    'format!("{}__{}.rows.json", cell.stage_id, cell.cell_id)',
    "r23d8_compose_neutral_stance",
    "R23D8_TRACE_ROW_SCHEMA",
    "run_qsdk_r23d8_rapier_physical"
)
Assert-R23D8SourceContains "tests/test_sdk_qsdk_r23d8_neutral_stance_godot_jolt_worker.gd" @(
    "_r8_physical_authorization(",
    "var retention := _r8_retain_trace(",
    '"%s__%s.rows.json" % [String(cell["stage_id"]), String(cell["cell_id"])]',
    'paths_by_worker.get(R8_ENGINE_ID, null)',
    "QSDK_R23D8_GODOT_JOLT_AUTHORIZATION_PREFLIGHT ",
    "terminal_neutral_stance_acquisition",
    "terminal_neutral_stance_hold",
    "QSDK_R23D8_GODOT_JOLT_CELL "
)
Assert-R23D8ImplementationExact (
    -not [IO.File]::ReadAllText(
        (Join-Path $repoRoot (
            "sdk/adapters/mujoco/sporespore_mujoco_adapter/" +
            "qsdk_r23d8_neutral_stance.py"
        ))
    ).Contains("expected_paths = (") -and
    -not [IO.File]::ReadAllText(
        (Join-Path $repoRoot "tests/test_sdk_qsdk_r23d8_neutral_stance_godot_jolt_worker.gd")
    ).Contains("R8_REQUIRED_DEPENDENCY_PATHS") -and
    -not [IO.File]::ReadAllText(
        (Join-Path $repoRoot "tests/test_sdk_qsdk_r23d8_neutral_stance_godot_jolt_worker.gd")
    ).Contains("_r8_dependency_manifest_exact")
) "QSDK-R23D8 worker-local dependency authority reappeared"
Assert-R23D8SourceContains "sdk/run_qsdk_r23d8_authorization_canaries.ps1" @(
    "Get-SporeSporeAttestationSourceIdentity",
    "Test-SporeSporeFullConformanceAttestationFile",
    "Enter-SporeSporeLocomotionOperationLock -Role conformance",
    "@(`$manifest.ordered_worker_ids).Count -eq 3",
    "QSDK_R23D8_AUTHORIZATION_CANARY_PREFLIGHT_PASS",
    "authorization_canary_process_launch_count = 0",
    "actual_production_authorization_function_execution_count = 6",
    "positive_authorization_canary_count = `$positiveCount",
    "mutated_binding_refusal_canary_count = `$refusalCount",
    "Remove-Item -LiteralPath `$resolvedRoot -Recurse -Force"
)
$authorizationCanarySource = [IO.File]::ReadAllText(
    (Join-Path $repoRoot "sdk/run_qsdk_r23d8_authorization_canaries.ps1")
)
Assert-R23D8ImplementationExact (
    -not $authorizationCanarySource.Contains(
        '[int]$manifest.worker_count',
        [StringComparison]::Ordinal
    )
) "QSDK-R23D8 authorization canary runner reads the removed worker_count field"
Assert-R23D8SourceContains "scripts/lab/gait/physical_wave_gait_quadruped.gd" @(
    "requested_sdk_terminal_restoration_options",
    "sdk_godot_jolt_neutral_stance.gd",
    "terminal_neutral_stance_acquisition",
    "QSDK_R23D4_TOTAL_TRACE_STEP_COUNT := 3772",
    "QSDK_R23D4_PASSIVE_SETTLE_STEP_COUNT := 240"
)
Assert-R23D8SourceContains "sdk/turning/r23d8_physical_evaluator.py" @(
    "def evaluate_stage_a_entries(",
    "def evaluate_complete_entries(",
    'f"{cell.stage_id}__{cell.cell_id}.ndjson"',
    'if not value and raw != b"[]\n":'
)

$canonicalConformanceSource = [IO.File]::ReadAllText(
    (Join-Path $repoRoot "sdk/run_conformance.ps1")
)
foreach ($token in @(
    "tests\test_qsdk_r23d8_declaration.ps1",
    "tests\test_qsdk_r23d8_pre_attempt_authorization_canary_incident.ps1",
    "tests\test_qsdk_r23d8_neutral_stance_implementation.ps1",
    "tests\test_qsdk_r23d8_dependency_and_marker_contract.ps1",
    "tests\test_qsdk_r23d8_implementation.ps1",
    "run_qsdk_r23d8_mujoco_worker_preflight.ps1",
    "run_qsdk_r23d8_rapier_worker_preflight.ps1",
    "sdk.turning.test_r23d8_physical_evaluator",
    "run_qsdk_r23d8_godot_jolt_worker_preflight.ps1"
)) {
    Assert-R23D8ImplementationExact (
        $canonicalConformanceSource.Contains($token, [StringComparison]::Ordinal)
    ) "QSDK-R23D8 canonical component route is missing: $token"
}
Assert-R23D8ImplementationExact (
    -not $canonicalConformanceSource.Contains(
        '& (Join-Path $sdkRoot "run_qsdk_r23d8_zero_world_gate.ps1")',
        [StringComparison]::Ordinal
    )
) "QSDK-R23D8 canonical conformance illegally nests the lock-owning aggregate gate"

$publisherSource = [IO.File]::ReadAllText(
    (Join-Path $repoRoot "sdk/publish_qsdk_r23d8_trace.ps1")
)
$publishIndex = $publisherSource.IndexOf(
    "Publish-SporeSporeContentAddressedArtifact", [StringComparison]::Ordinal
)
$markerIndex = $publisherSource.IndexOf(
    "QSDK_R23D8_TRACE_CAS ", [StringComparison]::Ordinal
)
Assert-R23D8ImplementationExact (
    $publishIndex -ge 0 -and $markerIndex -gt $publishIndex
) "QSDK-R23D8 trace publisher can emit before content-addressed retention"

$receipt = [ordered]@{
    schema_version = "sporespore_qsdk_r23d8_implementation_audit_v1"
    campaign_id = [string]$contract.campaign_id
    gate_id = [string]$contract.gate_id
    implementation_contract_raw_sha256 = Get-R23D8ImplementationRawSha256 $contractPath
    declared_source_binding_count = $paths.Count
    worker_implementation_count = 3
    native_terminal_stance_route_count = 3
    complete_trace_retention_path_count = 3
    production_evaluator_count = 1
    single_supervisor_count = 1
    frozen_lineage_digest_count = 6
    retained_pre_attempt_incident_count = 1
    declared_worker_dependency_count = 28
    dependency_composer_count = 1
    terminal_marker_classifier_count = 1
    physical_process_launch_count = 0
    world_attempt_count = 0
    world_build_count = 0
    physical_execution_authorized = $false
    command_conditioned_turning = $false
    bilateral_signed_turning = $false
    portable_basic_turning = $false
    cross_engine_equivalence = $false
    q_sdk_r23_satisfied = $false
    release_authorized = $false
    physical_acceptance_authority = $false
}
Write-Host (
    "QSDK_R23D8_IMPLEMENTATION_AUDIT " +
    ($receipt | ConvertTo-Json -Depth 20 -Compress)
)
Write-Host (
    "QSDK_R23D8_IMPLEMENTATION_PASS workers=3 stance_routes=3 trace_paths=3 " +
    "dependencies=28 evaluator=1 supervisor=1 marker_classifier=1 incident=1 " +
    "worlds=0 physical_authority=False"
)
