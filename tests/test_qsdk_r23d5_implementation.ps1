#requires -Version 7.0

[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$sdkRoot = Join-Path $repoRoot "sdk"
$contractPath = Join-Path $sdkRoot "turning\r23d5_implementation_contract_v1.json"
$preregistrationPath = Join-Path $sdkRoot (
    "turning\r23d5_dependency_closed_preregistration_v1.json"
)
$r23d4ClosurePath = Join-Path $sdkRoot "turning\r23d4_physical_closure_v1.json"
$dependencyComposerPath = Join-Path $sdkRoot "turning\r23d5_dependency_closure.ps1"
$terminalClassifierPath = Join-Path $sdkRoot "turning\r23d5_terminal_marker_classifier.ps1"
$mujocoClosurePath = Join-Path $sdkRoot (
    "mujoco_c6_bw19v_selected_policy_pose_hold_restoration_mv6_closure.json"
)
$rapierClosurePath = Join-Path $sdkRoot (
    "rapier_c6_bw19v_velocity_only_pose_hold_restoration_ph1_closure.json"
)

. $dependencyComposerPath

function Assert-R23D5ImplementationExact {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function Get-R23D5ImplementationRawSha256 {
    param([Parameter(Mandatory)][string]$Path)
    return "sha256:" + (
        Get-FileHash -LiteralPath $Path -Algorithm SHA256
    ).Hash.ToLowerInvariant()
}

function Invoke-R23D5ImplementationGit {
    param([Parameter(Mandatory)][string[]]$Arguments)
    $output = @(& git -C $repoRoot @Arguments 2>&1)
    Assert-R23D5ImplementationExact ($LASTEXITCODE -eq 0) (
        "QSDK-R23D5 implementation audit git failure: git " +
        ($Arguments -join " ") + ": " + ($output -join " ")
    )
    return ($output -join "`n").Trim()
}

function Assert-R23D5SourceContains {
    param(
        [Parameter(Mandatory)][string]$RelativePath,
        [Parameter(Mandatory)][string[]]$Tokens
    )
    $path = Join-Path $repoRoot $RelativePath
    Assert-R23D5ImplementationExact (
        Test-Path -LiteralPath $path -PathType Leaf
    ) "QSDK-R23D5 implementation source missing: $RelativePath"
    $source = [IO.File]::ReadAllText($path)
    foreach ($token in $Tokens) {
        Assert-R23D5ImplementationExact ($source.Contains($token)) (
            "QSDK-R23D5 implementation seam missing from ${RelativePath}: $token"
        )
    }
}

Assert-R23D5ImplementationExact (
    (Invoke-R23D5ImplementationGit @("rev-parse", "--show-toplevel")).Replace("/", "\") `
        -ceq $repoRoot -and
    (Invoke-R23D5ImplementationGit @("remote", "get-url", "origin")) -ceq
        "https://github.com/Slagathore/sporespore.git"
) "QSDK-R23D5 implementation audit repository identity mismatch"

foreach ($path in @(
    $contractPath,
    $preregistrationPath,
    $r23d4ClosurePath,
    $dependencyComposerPath,
    $terminalClassifierPath,
    $mujocoClosurePath,
    $rapierClosurePath
)) {
    Assert-R23D5ImplementationExact (
        Test-Path -LiteralPath $path -PathType Leaf
    ) "QSDK-R23D5 implementation authority missing: $path"
}

$contract = Get-Content -Raw -LiteralPath $contractPath |
    ConvertFrom-Json -AsHashtable -Depth 100
$preregistration = Get-Content -Raw -LiteralPath $preregistrationPath |
    ConvertFrom-Json -AsHashtable -Depth 100

Assert-R23D5ImplementationExact (
    [string]$contract.schema_version -ceq
        "sporespore_qsdk_r23d5_implementation_contract_v1" -and
    [string]$contract.status -ceq
        "implementation_complete_zero_world_qualified_pending_clean_push_and_full_attestation" -and
    [string]$contract.campaign_id -ceq
        "QSDK-R23D5-DEPENDENCY-CLOSED-TERMINAL-STABILIZED-BILATERAL-TURN-DEVELOPMENT" -and
    [string]$contract.gate_id -ceq "QSDK-R23D5" -and
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
    [bool]$contract.supervisor.dependency_manifest_composer_exercised_before_input_cas_and_attempt_authorization -and
    [bool]$contract.supervisor.worker_required_sets_are_verified_as_source_binding_subsets -and
    [bool]$contract.supervisor.process_stdout_stderr_and_required_engine_log_retained_before_marker_interpretation -and
    [bool]$contract.supervisor.shared_terminal_marker_classifier_required -and
    [bool]$contract.supervisor.every_launched_process_gets_a_content_addressed_terminal_entry -and
    [int]$contract.dependency_closure.declared_worker_count -eq 3 -and
    [int]$contract.dependency_closure.declared_unique_dependency_count -eq 21 -and
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
) "QSDK-R23D5 implementation contract identity changed"

Assert-R23D5ImplementationExact (
    [string]$preregistration.schema_version -ceq
        "sporespore_qsdk_r23d5_dependency_closed_preregistration_v1" -and
    [string]$preregistration.campaign_id -ceq [string]$contract.campaign_id -and
    [string]$preregistration.gate_id -ceq [string]$contract.gate_id -and
    [int]$preregistration.stage_a_mujoco_terminal_restoration_screen.declared_cell_count -eq 2 -and
    [int]$preregistration.stage_b_three_engine_confirmation.declared_cell_count_if_launched -eq 9 -and
    -not [bool]$preregistration.authorization.physical_execution_authorized
) "QSDK-R23D5 preregistration identity changed"

Assert-R23D5ImplementationExact (
    (Get-R23D5ImplementationRawSha256 $preregistrationPath) -ceq
        [string]$contract.preregistration_raw_sha256 -and
    (Get-R23D5ImplementationRawSha256 $r23d4ClosurePath) -ceq
        [string]$contract.closed_predecessor_raw_sha256 -and
    (Get-R23D5ImplementationRawSha256 $mujocoClosurePath) -ceq
        "sha256:5da3675d848c1d127419c43f009fb430c4f02abd2a55da730ea70fca6d3cee09" -and
    (Get-R23D5ImplementationRawSha256 $rapierClosurePath) -ceq
        "sha256:e2fd42545d59908db69f9fe34a18453afafe4273a02618be0b531f6443e040db"
) "QSDK-R23D5 frozen lineage digest changed"

$paths = [Collections.Generic.List[string]]::new()
foreach ($relative in @($contract.source_binding_policy.exact_paths)) {
    $paths.Add(([string]$relative).Replace("\", "/"))
}
foreach ($prefix in @($contract.source_binding_policy.tracked_prefixes)) {
    $expanded = @((Invoke-R23D5ImplementationGit @(
        "ls-files", "--", [string]$prefix
    )) -split "`n" | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    Assert-R23D5ImplementationExact ($expanded.Count -gt 0) (
        "QSDK-R23D5 source prefix expanded to zero files: $prefix"
    )
    foreach ($relative in $expanded) { $paths.Add($relative.Replace("\", "/")) }
}
$duplicates = @($paths | Group-Object | Where-Object Count -gt 1)
Assert-R23D5ImplementationExact ($duplicates.Count -eq 0) (
    "QSDK-R23D5 source binding policy contains duplicates: " +
    (@($duplicates | ForEach-Object { [string]$_.Name }) -join ",")
)
foreach ($relative in $paths) {
    Assert-R23D5ImplementationExact (
        Test-Path -LiteralPath (Join-Path $repoRoot $relative) -PathType Leaf
    ) "QSDK-R23D5 declared source binding is missing: $relative"
}
$dependencyManifest = Get-R23D5DependencyManifest -RepoRoot $repoRoot
$sourcePathSet = [Collections.Generic.HashSet[string]]::new(
    [StringComparer]::Ordinal
)
foreach ($relative in $paths) { [void]$sourcePathSet.Add([string]$relative) }
$dependencyPathsMissingFromFreeze = @(
    @($dependencyManifest.union_paths) | Where-Object {
        -not $sourcePathSet.Contains([string]$_)
    }
)
Assert-R23D5ImplementationExact (
    [int]$dependencyManifest.unique_dependency_count -eq 21 -and
    $dependencyPathsMissingFromFreeze.Count -eq 0
) (
    "QSDK-R23D5 implementation freeze does not cover dependency union: " +
    ($dependencyPathsMissingFromFreeze -join ",")
)

Assert-R23D5SourceContains "sdk/run_qsdk_r23d5_supervisor.ps1" @(
    "Get-SporeSporeAttestationSourceIdentity",
    "Publish-SporeSporeContentAddressedArtifact",
    "Get-R23D5DependencyManifest",
    "Test-R23D5DependencyReceiptClosure",
    "Get-R23D5TerminalMarkerClassification",
    "sporespore_qsdk_r23d5_process_retention_receipt_v1",
    "retained_before_marker_interpretation = `$true",
    "terminal_marker_classification = `$classification",
    "Initialize-R23D5RuntimeArtifacts",
    "Resolve-R23D5ApplicationPath",
    "Get-Command",
    "-CommandType Application",
    "`$matches[0].Source",
    "`$developmentExternalRuntimeBindings.Count -eq 4",
    "SPORESPORE_QSDK_R23D5_PYTHON = `$resolvedPythonPath",
    "SPORESPORE_QSDK_R23D5_POWERSHELL = `$resolvedPowerShellPath",
    "Write-R23D5Manifest",
    "QSDK_R23D5_STAGE_A_EVALUATION ",
    "QSDK_R23D5_COMPLETE_EVALUATION ",
    "stage_b_launch_authorized",
    "selected_terminal_restoration_policy_id",
    "frozen_supervisor_only_physical_authorized",
    "replacement_or_selective_rerun_permitted = `$false"
)
Assert-R23D5SourceContains ".gitattributes" @(
    "sdk/turning/r23d5_* text eol=lf",
    "sdk/run_qsdk_r23d5_*.ps1 text eol=lf",
    "tests/test_sdk_qsdk_r23d5_*.gd text eol=lf",
    "sdk/adapters/rapier/src/bin/qsdk_r23d5_*.rs text eol=lf",
    "sdk/adapters/mujoco/sporespore_mujoco_adapter/qsdk_r23d5_*.py text eol=lf"
)
Assert-R23D5ImplementationExact (
    -not [IO.File]::ReadAllText(
        (Join-Path $repoRoot "sdk/run_qsdk_r23d5_supervisor.ps1")
    ).Contains(
        "implementation.status"
    )
) "QSDK-R23D5 supervisor duplicates mutable implementation status"
$supervisorSource = [IO.File]::ReadAllText(
    (Join-Path $repoRoot "sdk/run_qsdk_r23d5_supervisor.ps1")
)
$processCasIndex = $supervisorSource.IndexOf(
    '$processCas = Publish-SporeSporeContentAddressedArtifact',
    [StringComparison]::Ordinal
)
$classifierIndex = $supervisorSource.IndexOf(
    '$classification = Get-R23D5TerminalMarkerClassification',
    [StringComparison]::Ordinal
)
$terminalCasIndex = $supervisorSource.IndexOf(
    '$terminalCas = Publish-SporeSporeContentAddressedArtifact',
    [StringComparison]::Ordinal
)
Assert-R23D5ImplementationExact (
    $processCasIndex -ge 0 -and
    $classifierIndex -gt $processCasIndex -and
    $terminalCasIndex -gt $classifierIndex -and
    -not $supervisorSource.Contains('$terminalLines.Count')
) "QSDK-R23D5 process retention, classification, and terminal CAS order changed"
Assert-R23D5SourceContains (
    "sdk/adapters/mujoco/sporespore_mujoco_adapter/qsdk_r23d5_dependency_closed.py"
) @(
    "_physical_authorization(cell, source_commit)",
    '_retain_trace(cell, rows, authorization["attempt_root"])',
    "QSDK_R23D5_TERMINAL "
)
Assert-R23D5SourceContains (
    "sdk/adapters/rapier/src/qsdk_r23d3_phase_balanced.rs"
) @(
    "fn r23d5_physical_authorization(",
    "fn r23d5_retain_trace(",
    "run_qsdk_r23d5_rapier_physical"
)
Assert-R23D5SourceContains "tests/test_sdk_qsdk_r23d5_godot_jolt_worker.gd" @(
    "_r5_physical_authorization(cell, source_commit)",
    "var retention := _r5_retain_trace(",
    "_r5_dependency_manifest_exact(contract)",
    "QSDK_R23D5_GODOT_JOLT_CELL "
)
Assert-R23D5SourceContains "scripts/lab/gait/physical_wave_gait_quadruped.gd" @(
    "requested_sdk_terminal_restoration_options",
    "QSDK_R23D4_TOTAL_TRACE_STEP_COUNT := 3772",
    "QSDK_R23D4_PASSIVE_SETTLE_STEP_COUNT := 240"
)
Assert-R23D5SourceContains "sdk/turning/r23d5_physical_evaluator.py" @(
    "def evaluate_stage_a_entries(",
    "def evaluate_complete_entries(",
    'if not value and raw != b"[]\n":'
)

$publisherSource = [IO.File]::ReadAllText(
    (Join-Path $repoRoot "sdk/publish_qsdk_r23d5_trace.ps1")
)
$publishIndex = $publisherSource.IndexOf(
    "Publish-SporeSporeContentAddressedArtifact", [StringComparison]::Ordinal
)
$markerIndex = $publisherSource.IndexOf(
    "QSDK_R23D5_TRACE_CAS ", [StringComparison]::Ordinal
)
Assert-R23D5ImplementationExact (
    $publishIndex -ge 0 -and $markerIndex -gt $publishIndex
) "QSDK-R23D5 trace publisher can emit before content-addressed retention"

$receipt = [ordered]@{
    schema_version = "sporespore_qsdk_r23d5_implementation_audit_v1"
    campaign_id = [string]$contract.campaign_id
    gate_id = [string]$contract.gate_id
    implementation_contract_raw_sha256 = Get-R23D5ImplementationRawSha256 $contractPath
    declared_source_binding_count = $paths.Count
    worker_implementation_count = 3
    native_terminal_restorer_count = 3
    complete_trace_retention_path_count = 3
    production_evaluator_count = 1
    single_supervisor_count = 1
    frozen_lineage_digest_count = 4
    declared_worker_dependency_count = 21
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
    "QSDK_R23D5_IMPLEMENTATION_AUDIT " +
    ($receipt | ConvertTo-Json -Depth 20 -Compress)
)
Write-Host (
    "QSDK_R23D5_IMPLEMENTATION_PASS workers=3 restorers=3 trace_paths=3 " +
    "dependencies=21 evaluator=1 supervisor=1 marker_classifier=1 " +
    "worlds=0 physical_authority=False"
)
