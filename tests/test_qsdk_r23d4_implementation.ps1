#requires -Version 7.0

[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$sdkRoot = Join-Path $repoRoot "sdk"
$contractPath = Join-Path $sdkRoot "turning\r23d4_implementation_contract_v1.json"
$preregistrationPath = Join-Path $sdkRoot (
    "turning\r23d4_terminal_stabilization_preregistration_v1.json"
)
$r23d3ClosurePath = Join-Path $sdkRoot "turning\r23d3_physical_closure_v1.json"
$preAttemptIncidentPath = Join-Path $sdkRoot (
    "turning\r23d4_pre_attempt_infrastructure_incident_v1.json"
)
$preAttemptContractStatusIncidentPath = Join-Path $sdkRoot (
    "turning\r23d4_pre_attempt_contract_status_incident_v1.json"
)
$mujocoClosurePath = Join-Path $sdkRoot (
    "mujoco_c6_bw19v_selected_policy_pose_hold_restoration_mv6_closure.json"
)
$rapierClosurePath = Join-Path $sdkRoot (
    "rapier_c6_bw19v_velocity_only_pose_hold_restoration_ph1_closure.json"
)

function Assert-R23D4ImplementationExact {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function Get-R23D4ImplementationRawSha256 {
    param([Parameter(Mandatory)][string]$Path)
    return "sha256:" + (
        Get-FileHash -LiteralPath $Path -Algorithm SHA256
    ).Hash.ToLowerInvariant()
}

function Invoke-R23D4ImplementationGit {
    param([Parameter(Mandatory)][string[]]$Arguments)
    $output = @(& git -C $repoRoot @Arguments 2>&1)
    Assert-R23D4ImplementationExact ($LASTEXITCODE -eq 0) (
        "QSDK-R23D4 implementation audit git failure: git " +
        ($Arguments -join " ") + ": " + ($output -join " ")
    )
    return ($output -join "`n").Trim()
}

function Assert-R23D4SourceContains {
    param(
        [Parameter(Mandatory)][string]$RelativePath,
        [Parameter(Mandatory)][string[]]$Tokens
    )
    $path = Join-Path $repoRoot $RelativePath
    Assert-R23D4ImplementationExact (
        Test-Path -LiteralPath $path -PathType Leaf
    ) "QSDK-R23D4 implementation source missing: $RelativePath"
    $source = [IO.File]::ReadAllText($path)
    foreach ($token in $Tokens) {
        Assert-R23D4ImplementationExact ($source.Contains($token)) (
            "QSDK-R23D4 implementation seam missing from ${RelativePath}: $token"
        )
    }
}

Assert-R23D4ImplementationExact (
    (Invoke-R23D4ImplementationGit @("rev-parse", "--show-toplevel")).Replace("/", "\") `
        -ceq $repoRoot -and
    (Invoke-R23D4ImplementationGit @("remote", "get-url", "origin")) -ceq
        "https://github.com/Slagathore/sporespore.git"
) "QSDK-R23D4 implementation audit repository identity mismatch"

foreach ($path in @(
    $contractPath,
    $preregistrationPath,
    $r23d3ClosurePath,
    $preAttemptIncidentPath,
    $preAttemptContractStatusIncidentPath,
    $mujocoClosurePath,
    $rapierClosurePath
)) {
    Assert-R23D4ImplementationExact (
        Test-Path -LiteralPath $path -PathType Leaf
    ) "QSDK-R23D4 implementation authority missing: $path"
}

$contract = Get-Content -Raw -LiteralPath $contractPath |
    ConvertFrom-Json -AsHashtable -Depth 100
$preregistration = Get-Content -Raw -LiteralPath $preregistrationPath |
    ConvertFrom-Json -AsHashtable -Depth 100
$preAttemptIncident = Get-Content -Raw -LiteralPath $preAttemptIncidentPath |
    ConvertFrom-Json -AsHashtable -Depth 100
$preAttemptContractStatusIncident = Get-Content -Raw `
    -LiteralPath $preAttemptContractStatusIncidentPath |
    ConvertFrom-Json -AsHashtable -Depth 100

Assert-R23D4ImplementationExact (
    [string]$contract.schema_version -ceq
        "sporespore_qsdk_r23d4_implementation_contract_v1" -and
    [string]$contract.status -ceq
        "two_pre_attempt_infrastructure_failures_repaired_zero_world_requalified_pending_clean_push_and_attestation" -and
    [string]$contract.campaign_id -ceq
        "QSDK-R23D4-TERMINAL-STABILIZED-BILATERAL-TURN-DEVELOPMENT" -and
    [string]$contract.gate_id -ceq "QSDK-R23D4" -and
    [string]$contract.pre_attempt_incident_path -ceq
        "sdk/turning/r23d4_pre_attempt_infrastructure_incident_v1.json" -and
    @($contract.pre_attempt_incident_paths).Count -eq 2 -and
    @($contract.pre_attempt_incident_paths) -join "," -ceq (
        "sdk/turning/r23d4_pre_attempt_infrastructure_incident_v1.json," +
        "sdk/turning/r23d4_pre_attempt_contract_status_incident_v1.json"
    ) -and
    @($contract.workers).Count -eq 3 -and
    @($contract.workers.engine_id) -join "," -ceq
        "mujoco,rapier_parry,godot_jolt" -and
    [int]$contract.fixed_schedule.turning_controller_step_count -eq 2992 -and
    [int]$contract.fixed_schedule.terminal_restoration_step_count -eq 540 -and
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
    [bool]$contract.runtime_freeze.source_bindings_must_equal_git_blob_bytes -and
    [bool]$contract.runtime_freeze.msvc_brepro_required -and
    [bool]$contract.runtime_freeze.pdb_alt_path_bare_name_required -and
    [bool]$contract.runtime_freeze.cargo_locked_offline_required -and
    -not [bool]$contract.authorization.physical_execution_authorized -and
    -not [bool]$contract.authorization.physical_acceptance_authority -and
    [int]$contract.authorization.world_attempt_count -eq 0 -and
    [int]$contract.authorization.world_build_count -eq 0
) "QSDK-R23D4 implementation contract identity changed"

Assert-R23D4ImplementationExact (
    [string]$preregistration.schema_version -ceq
        "sporespore_qsdk_r23d4_terminal_stabilization_preregistration_v1" -and
    [string]$preregistration.campaign_id -ceq [string]$contract.campaign_id -and
    [string]$preregistration.gate_id -ceq [string]$contract.gate_id -and
    [int]$preregistration.stage_a_mujoco_terminal_restoration_screen.declared_cell_count -eq 2 -and
    [int]$preregistration.stage_b_three_engine_confirmation.declared_cell_count_if_launched -eq 9 -and
    -not [bool]$preregistration.authorization.physical_execution_authorized
) "QSDK-R23D4 preregistration identity changed"

Assert-R23D4ImplementationExact (
    [string]$preAttemptIncident.schema_version -ceq
        "sporespore_qsdk_r23d4_pre_attempt_infrastructure_incident_v1" -and
    [string]$preAttemptIncident.status -ceq
        "pre_attempt_infrastructure_failure_no_scientific_result_no_identity_consumption" -and
    [string]$preAttemptIncident.source_commit -ceq
        "2e189ddecdec19d88a6d96a0d294106c9bb1e9d6" -and
    [int]$preAttemptIncident.supervisor_invocation.output_root_file_count_after_failure -eq 0 -and
    [string]$preAttemptIncident.failure.stage -ceq
        "external_runtime_binding_before_input_cas_freeze_or_stage_authorization" -and
    -not [bool]$preAttemptIncident.boundary.physical_freeze_written -and
    -not [bool]$preAttemptIncident.boundary.stage_a_authorization_written -and
    -not [bool]$preAttemptIncident.boundary.attempt_token_created -and
    -not [bool]$preAttemptIncident.boundary.one_shot_identity_consumed -and
    [int]$preAttemptIncident.boundary.physical_worker_process_launch_count -eq 0 -and
    [int]$preAttemptIncident.boundary.world_build_count -eq 0 -and
    -not [bool]$preAttemptIncident.boundary.scientific_result_exists -and
    -not [bool]$preAttemptIncident.claims.command_conditioned_turning -and
    -not [bool]$preAttemptIncident.claims.physical_acceptance_authority
) "QSDK-R23D4 pre-attempt infrastructure incident boundary changed"

Assert-R23D4ImplementationExact (
    [string]$preAttemptContractStatusIncident.schema_version -ceq
        "sporespore_qsdk_r23d4_pre_attempt_contract_status_incident_v1" -and
    [string]$preAttemptContractStatusIncident.status -ceq
        "pre_attempt_infrastructure_failure_no_scientific_result_no_identity_consumption" -and
    [string]$preAttemptContractStatusIncident.source_commit -ceq
        "69ea18440dfffacccad604182ad0c960a7393be3" -and
    -not [bool]$preAttemptContractStatusIncident.supervisor_invocation.output_root_allocated -and
    [string]$preAttemptContractStatusIncident.failure.stage -ceq
        "implementation_contract_status_interlock_before_zero_world_gate_or_output_root" -and
    -not [bool]$preAttemptContractStatusIncident.boundary.complete_zero_world_gate_started -and
    -not [bool]$preAttemptContractStatusIncident.boundary.attempt_token_created -and
    -not [bool]$preAttemptContractStatusIncident.boundary.one_shot_identity_consumed -and
    [int]$preAttemptContractStatusIncident.boundary.physical_worker_process_launch_count -eq 0 -and
    [int]$preAttemptContractStatusIncident.boundary.world_build_count -eq 0 -and
    -not [bool]$preAttemptContractStatusIncident.boundary.scientific_result_exists -and
    -not [bool]$preAttemptContractStatusIncident.claims.command_conditioned_turning -and
    -not [bool]$preAttemptContractStatusIncident.claims.physical_acceptance_authority
) "QSDK-R23D4 pre-attempt contract-status incident boundary changed"

Assert-R23D4ImplementationExact (
    (Get-R23D4ImplementationRawSha256 $preregistrationPath) -ceq
        [string]$contract.preregistration_raw_sha256 -and
    (Get-R23D4ImplementationRawSha256 $r23d3ClosurePath) -ceq
        [string]$contract.closed_predecessor_raw_sha256 -and
    (Get-R23D4ImplementationRawSha256 $mujocoClosurePath) -ceq
        "sha256:5da3675d848c1d127419c43f009fb430c4f02abd2a55da730ea70fca6d3cee09" -and
    (Get-R23D4ImplementationRawSha256 $rapierClosurePath) -ceq
        "sha256:e2fd42545d59908db69f9fe34a18453afafe4273a02618be0b531f6443e040db"
) "QSDK-R23D4 frozen lineage digest changed"

$paths = [Collections.Generic.List[string]]::new()
foreach ($relative in @($contract.source_binding_policy.exact_paths)) {
    $paths.Add(([string]$relative).Replace("\", "/"))
}
foreach ($prefix in @($contract.source_binding_policy.tracked_prefixes)) {
    $expanded = @((Invoke-R23D4ImplementationGit @(
        "ls-files", "--", [string]$prefix
    )) -split "`n" | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    Assert-R23D4ImplementationExact ($expanded.Count -gt 0) (
        "QSDK-R23D4 source prefix expanded to zero files: $prefix"
    )
    foreach ($relative in $expanded) { $paths.Add($relative.Replace("\", "/")) }
}
$duplicates = @($paths | Group-Object | Where-Object Count -gt 1)
Assert-R23D4ImplementationExact ($duplicates.Count -eq 0) (
    "QSDK-R23D4 source binding policy contains duplicates: " +
    (@($duplicates | ForEach-Object { [string]$_.Name }) -join ",")
)
foreach ($relative in $paths) {
    Assert-R23D4ImplementationExact (
        Test-Path -LiteralPath (Join-Path $repoRoot $relative) -PathType Leaf
    ) "QSDK-R23D4 declared source binding is missing: $relative"
}

Assert-R23D4SourceContains "sdk/run_qsdk_r23d4_supervisor.ps1" @(
    "Get-SporeSporeAttestationSourceIdentity",
    "Publish-SporeSporeContentAddressedArtifact",
    "Initialize-R23D4RuntimeArtifacts",
    "Resolve-R23D4ApplicationPath",
    "Get-Command",
    "-CommandType Application",
    "`$matches[0].Source",
    "`$developmentExternalRuntimeBindings.Count -eq 4",
    "SPORESPORE_QSDK_R23D4_PYTHON = `$resolvedPythonPath",
    "SPORESPORE_QSDK_R23D4_POWERSHELL = `$resolvedPowerShellPath",
    "Write-R23D4Manifest",
    "QSDK_R23D4_STAGE_A_EVALUATION ",
    "QSDK_R23D4_COMPLETE_EVALUATION ",
    "stage_b_launch_authorized",
    "selected_terminal_restoration_policy_id",
    "frozen_supervisor_only_physical_authorized",
    "replacement_or_selective_rerun_permitted = `$false"
)
Assert-R23D4ImplementationExact (
    -not [IO.File]::ReadAllText(
        (Join-Path $repoRoot "sdk/run_qsdk_r23d4_supervisor.ps1")
    ).Contains(
        "implementation.status"
    )
) "QSDK-R23D4 supervisor duplicates mutable implementation status"
Assert-R23D4SourceContains (
    "sdk/adapters/mujoco/sporespore_mujoco_adapter/qsdk_r23d4_terminal_stabilization.py"
) @(
    "_physical_authorization(cell, source_commit)",
    '_retain_trace(cell, rows, authorization["attempt_root"])',
    "QSDK_R23D4_TERMINAL "
)
Assert-R23D4SourceContains (
    "sdk/adapters/rapier/src/qsdk_r23d3_phase_balanced.rs"
) @(
    "fn r23d4_physical_authorization(",
    "fn r23d4_retain_trace(",
    "run_qsdk_r23d4_rapier_physical"
)
Assert-R23D4SourceContains "tests/test_sdk_qsdk_r23d4_godot_jolt_worker.gd" @(
    "_r4_physical_authorization(cell, source_commit)",
    "var retention := _r4_retain_trace(",
    "QSDK_R23D4_GODOT_JOLT_CELL "
)
Assert-R23D4SourceContains "scripts/lab/gait/physical_wave_gait_quadruped.gd" @(
    "requested_sdk_terminal_restoration_options",
    "QSDK_R23D4_TOTAL_TRACE_STEP_COUNT := 3772",
    "QSDK_R23D4_PASSIVE_SETTLE_STEP_COUNT := 240"
)
Assert-R23D4SourceContains "sdk/turning/r23d4_physical_evaluator.py" @(
    "def evaluate_stage_a_entries(",
    "def evaluate_complete_entries(",
    'if not value and raw != b"[]\n":'
)

$publisherSource = [IO.File]::ReadAllText(
    (Join-Path $repoRoot "sdk/publish_qsdk_r23d4_trace.ps1")
)
$publishIndex = $publisherSource.IndexOf(
    "Publish-SporeSporeContentAddressedArtifact", [StringComparison]::Ordinal
)
$markerIndex = $publisherSource.IndexOf(
    "QSDK_R23D4_TRACE_CAS ", [StringComparison]::Ordinal
)
Assert-R23D4ImplementationExact (
    $publishIndex -ge 0 -and $markerIndex -gt $publishIndex
) "QSDK-R23D4 trace publisher can emit before content-addressed retention"

$receipt = [ordered]@{
    schema_version = "sporespore_qsdk_r23d4_implementation_audit_v1"
    campaign_id = [string]$contract.campaign_id
    gate_id = [string]$contract.gate_id
    implementation_contract_raw_sha256 = Get-R23D4ImplementationRawSha256 $contractPath
    declared_source_binding_count = $paths.Count
    worker_implementation_count = 3
    native_terminal_restorer_count = 3
    complete_trace_retention_path_count = 3
    production_evaluator_count = 1
    single_supervisor_count = 1
    frozen_lineage_digest_count = 4
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
    "QSDK_R23D4_IMPLEMENTATION_AUDIT " +
    ($receipt | ConvertTo-Json -Depth 20 -Compress)
)
Write-Host (
    "QSDK_R23D4_IMPLEMENTATION_PASS workers=3 restorers=3 trace_paths=3 " +
    "evaluator=1 supervisor=1 worlds=0 physical_authority=False"
)
