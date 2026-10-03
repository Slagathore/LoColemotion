#requires -Version 7.0

[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot)).TrimEnd(
    '\', '/'
)
$expectedRemote = "https://github.com/Slagathore/sporespore.git"
$closurePath = Join-Path $repoRoot (
    "sdk\turning\" +
    "r23d57_godot_full_precision_trace_transport_closure_v1.json"
)
$closureAuditPath = [IO.Path]::GetFullPath($PSCommandPath)
$releaseContractPath = Join-Path $repoRoot (
    "sdk\release\quadruped_release_contract.json"
)
$supportMatrixPath = Join-Path $repoRoot (
    "sdk\release\quadruped_support_matrix.json"
)
$workbenchCatalogPath = Join-Path $repoRoot (
    "sdk\workbench\experiment_catalog.json"
)
$sourceCommit = "95f6acf3d52bcaffda84833dc59d39a38f8c7f42"
$sourceTree = "ade202681a8a58454026819fcede5499a818e546"
$initialClosureBoundaryCommit = "7fbc2bf7e6194a8f7f98e42a157d9451bca3d53d"
$initialClosureAuditRawSha256 = (
    "sha256:0e4523146cbe5ae78049ef36a1f291a9a59bbaa0b15eb9cfcca7a709eb4f4fb9"
)
$contractId = "QSDK-R23D57-GODOT-FULL-PRECISION-TRACE-TRANSPORT"
$validatorMarker = "QSDK_R23D57_FULL_PRECISION_TRACE_TRANSPORT_PASS "

function Assert-R23D57Closure([bool]$Condition, [string]$Message) {
    if (-not $Condition) {
        throw "QSDK-R23D57 TRANSPORT CLOSURE: $Message"
    }
}

function Get-R23D57ClosureRawSha256([string]$Path) {
    return "sha256:" + (
        Get-FileHash -LiteralPath $Path -Algorithm SHA256
    ).Hash.ToLowerInvariant()
}

function Get-R23D57ClosureBytesSha256([byte[]]$Bytes) {
    return "sha256:" + [Convert]::ToHexString(
        [Security.Cryptography.SHA256]::HashData($Bytes)
    ).ToLowerInvariant()
}

function Get-R23D57GitBlobBytes {
    param(
        [Parameter(Mandatory)][string]$Commit,
        [Parameter(Mandatory)][string]$Path
    )

    $startInfo = [Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = "git"
    $startInfo.WorkingDirectory = $repoRoot
    $startInfo.UseShellExecute = $false
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    foreach ($argument in @(
        "-C", $repoRoot, "cat-file", "blob", "${Commit}:$Path"
    )) {
        [void]$startInfo.ArgumentList.Add($argument)
    }

    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $startInfo
    $memory = [IO.MemoryStream]::new()
    try {
        Assert-R23D57Closure ($process.Start()) (
            "unable to launch Git blob reader for $Path"
        )
        $copyTask = $process.StandardOutput.BaseStream.CopyToAsync($memory)
        $errorTask = $process.StandardError.ReadToEndAsync()
        $process.WaitForExit()
        [void]$copyTask.GetAwaiter().GetResult()
        $errorText = $errorTask.GetAwaiter().GetResult()
        Assert-R23D57Closure ($process.ExitCode -eq 0) (
            "unable to reconstruct ${Commit}:$Path from Git: $errorText"
        )
        return ,$memory.ToArray()
    } finally {
        $memory.Dispose()
        $process.Dispose()
    }
}

function Copy-R23D57Json([object]$Value) {
    return $Value | ConvertTo-Json -Depth 100 -Compress |
        ConvertFrom-Json -AsHashtable -Depth 100
}

function Find-R23D57Record([object]$Value, [string]$Key) {
    if ($null -eq $Value) { return $null }
    if ($Value -is [Collections.IDictionary]) {
        if ($Value.Contains($Key)) { return $Value[$Key] }
        foreach ($child in $Value.Values) {
            $found = Find-R23D57Record $child $Key
            if ($null -ne $found) { return $found }
        }
        return $null
    }
    if ($Value -is [Management.Automation.PSCustomObject]) {
        $property = $Value.PSObject.Properties[$Key]
        if ($null -ne $property) { return $property.Value }
        foreach ($property in $Value.PSObject.Properties) {
            $found = Find-R23D57Record $property.Value $Key
            if ($null -ne $found) { return $found }
        }
        return $null
    }
    if ($Value -is [Collections.IEnumerable] -and $Value -isnot [string]) {
        foreach ($child in $Value) {
            $found = Find-R23D57Record $child $Key
            if ($null -ne $found) { return $found }
        }
    }
    return $null
}

function Test-R23D57ClosureCandidate([Collections.IDictionary]$Candidate) {
    try {
        $lineage = $Candidate["immutable_lineage"]
        $change = $Candidate["declared_change"]
        $sourcePolicy = $Candidate["source_binding_policy"]
        $executions = $Candidate["authoritative_executions"]
        $result = $Candidate["result"]
        $closureHistory = $Candidate["closure_process_history"]
        $adequacy = $Candidate["adequacy"]
        $next = $Candidate["next_boundary"]
        $claims = $Candidate["claims"]
        return (
            [string]$Candidate["schema_version"] -ceq
                "sporespore_qsdk_r23d57_godot_full_precision_trace_transport_closure_v1" -and
            [string]$Candidate["status"] -ceq
                "closed_complete_valid_positive_exact_zero_world_transport_conformance_physical_campaign_not_opened" -and
            [string]$Candidate["contract_id"] -ceq $contractId -and
            [string]$Candidate["question_class"] -ceq "development" -and
            [bool]$Candidate["physical_question_declared"] -and
            -not [bool]$Candidate["physical_campaign_opened"] -and
            [string]$lineage["source_freeze_commit"] -ceq $sourceCommit -and
            [string]$lineage["source_freeze_tree_git_oid"] -ceq $sourceTree -and
            [bool]$lineage["r23d56_identity_consumed"] -and
            -not [bool]$lineage["r23d56_rerun_allowed"] -and
            -not [bool]$lineage["r23d56_result_reinterpreted"] -and
            -not [bool]$lineage["r23d56_rows_promoted_to_r23d57_evidence"] -and
            [int]$change["physics_model_change_count"] -eq 0 -and
            [int]$change["controller_change_count"] -eq 0 -and
            [int]$change["measurement_change_count"] -eq 0 -and
            [int]$change["threshold_change_count"] -eq 0 -and
            [int]$change["evidence_transport_change_count"] -eq 1 -and
            [double]$change["configured_readback_tolerance"] -eq 2.5e-7 -and
            [double]$change[
                "reported_error_recomputation_consistency_tolerance"
            ] -eq 1.0e-15 -and
            [int]$change["new_empirical_threshold_count"] -eq 0 -and
            -not [bool]$change[
                "r23d56_observed_maximum_used_to_set_a_threshold"
            ] -and
            [int]$sourcePolicy["source_binding_count"] -eq 12 -and
            @($sourcePolicy["bindings"]).Count -eq 12 -and
            [int]$executions["total_zero_world_godot_process_launch_count"] -eq 2 -and
            [int]$executions["total_physical_process_launch_count"] -eq 0 -and
            [int]$executions["total_model_construction_count"] -eq 0 -and
            [int]$executions["total_world_attempt_count"] -eq 0 -and
            [int]$executions["total_world_build_count"] -eq 0 -and
            [int]$result["fixture_count"] -eq 35 -and
            [int]$result["default_target_consistency_failure_count"] -eq 14 -and
            [int]$result["default_impulse_consistency_failure_count"] -eq 0 -and
            [int]$result["full_precision_target_consistency_failure_count"] -eq 0 -and
            [int]$result["full_precision_impulse_consistency_failure_count"] -eq 0 -and
            [int]$result["full_precision_binary64_roundtrip_mismatch_count"] -eq 0 -and
            [int]$result["mutation_rejection_count"] -eq 12 -and
            [int]$result["boundary_control_count"] -eq 2 -and
            [bool]$result["below_boundary_accepted"] -and
            [bool]$result["above_boundary_rejected"] -and
            [double]$result["below_boundary_residual"] -le 1.0e-15 -and
            [double]$result["above_boundary_residual"] -gt 1.0e-15 -and
            [int]$result["model_construction_count"] -eq 0 -and
            [int]$result["world_attempt_count"] -eq 0 -and
            [int]$result["world_build_count"] -eq 0 -and
            [int]$closureHistory["retained_event_count"] -eq 3 -and
            [string]$closureHistory[
                "local_pre_inventory_closure_audit"
            ]["status"] -ceq "passed" -and
            [int]$closureHistory[
                "local_pre_inventory_closure_audit"
            ]["closure_mutation_rejection_count"] -eq 16 -and
            [string]$closureHistory[
                "initial_provenance_inventory_verification"
            ]["status"] -ceq "failed_closed_expected_inventory_extension" -and
            [string]$closureHistory[
                "initial_provenance_inventory_verification"
            ]["failure_message"] -ceq
                "Closure evidence-mode executable inventory verification failed" -and
            [int]$closureHistory[
                "initial_provenance_inventory_verification"
            ]["world_build_count"] -eq 0 -and
            [string]$closureHistory[
                "initial_integrated_live_mirror_audit"
            ]["status"] -ceq
                "failed_closed_after_frozen_transport_replay" -and
            [int]$closureHistory[
                "initial_integrated_live_mirror_audit"
            ]["world_build_count"] -eq 0 -and
            [bool]$adequacy[
                "adequate_for_exact_godot_4_7_stable_to_cpython_3_11_9_binary64_trace_transport"
            ] -and
            -not [bool]$adequacy["adequate_for_physical_characterization"] -and
            -not [bool]$adequacy["adequate_for_turning_acceptance"] -and
            -not [bool]$adequacy["adequate_for_population_inference"] -and
            -not [bool]$adequacy["adequate_for_cross_engine_equivalence"] -and
            -not [bool]$next["physical_preregistration_complete"] -and
            -not [bool]$next["physical_worker_complete"] -and
            -not [bool]$next["physical_evaluator_complete"] -and
            -not [bool]$next["physical_supervisor_complete"] -and
            -not [bool]$next["campaign_attestation_manifest_complete"] -and
            -not [bool]$next["complete_zero_world_campaign_gate_passed"] -and
            -not [bool]$next["scoped_qualification_passed"] -and
            -not [bool]$next["adoption_passed"] -and
            [bool]$next["fresh_worlds_required"] -and
            -not [bool]$next["physical_execution_authorized"] -and
            [bool]$claims["zero_world_transport_gate_passed"] -and
            [bool]$claims["clean_pushed_zero_world_transport_result_closed"] -and
            -not [bool]$claims["r23d57_physical_implementation_complete"] -and
            -not [bool]$claims["physical_world_opened"] -and
            -not [bool]$claims["actuator_phase_characterization_complete"] -and
            -not [bool]$claims["turning_mechanism_selected"] -and
            -not [bool]$claims["godot_jolt_turning_validation"] -and
            -not [bool]$claims["finite_three_engine_turning"] -and
            -not [bool]$claims["portable_basic_turning"] -and
            -not [bool]$claims["cross_engine_equivalence"] -and
            -not [bool]$claims["population_robustness"] -and
            -not [bool]$claims["q_sdk_r23_satisfied"] -and
            -not [bool]$claims["prone_to_standing"] -and
            -not [bool]$claims["release_authorized"] -and
            -not [bool]$claims["physical_acceptance_authority"]
        )
    } catch {
        return $false
    }
}

Assert-R23D57Closure (Test-Path -LiteralPath $closurePath -PathType Leaf) (
    "closure authority is missing"
)
$actualRoot = (& git -C $repoRoot rev-parse --show-toplevel).Trim()
Assert-R23D57Closure ($LASTEXITCODE -eq 0) "repository root cannot be resolved"
$actualRemote = (& git -C $repoRoot remote get-url origin).Trim()
Assert-R23D57Closure ($LASTEXITCODE -eq 0) "origin cannot be resolved"
Assert-R23D57Closure (
    [IO.Path]::GetFullPath($actualRoot).TrimEnd('\', '/') -ceq $repoRoot -and
    $actualRemote -ceq $expectedRemote
) "repository identity changed"

$commitType = (& git -C $repoRoot cat-file -t $sourceCommit).Trim()
Assert-R23D57Closure (
    $LASTEXITCODE -eq 0 -and $commitType -ceq "commit"
) "source freeze commit is unavailable"
$observedTree = (& git -C $repoRoot show -s --format=%T $sourceCommit).Trim()
Assert-R23D57Closure (
    $LASTEXITCODE -eq 0 -and $observedTree -ceq $sourceTree
) "source freeze tree changed"

$closure = Get-Content -Raw -LiteralPath $closurePath |
    ConvertFrom-Json -AsHashtable -Depth 100
Assert-R23D57Closure (Test-R23D57ClosureCandidate $closure) (
    "closure result or claim boundary changed"
)

$lineage = $closure["immutable_lineage"]
Assert-R23D57Closure (
    [string]$lineage["development_parent_commit"] -ceq
        "5008c44a418eed3f3e1a56d8ef005394d84b68e1" -and
    [string]$lineage["source_branch"] -ceq "main" -and
    [string]$lineage["source_remote"] -ceq $expectedRemote -and
    [bool]$lineage["local_head_upstream_and_live_remote_equal_before_execution"] -and
    [bool]$lineage["worktree_clean_before_execution"] -and
    [bool]$lineage["worktree_clean_after_execution"] -and
    [string]$lineage["r23d56_closure_raw_sha256"] -ceq
        "sha256:34d165fb8aaad4321e2c28e992cd66221179fe2d791aae977528c23227013531"
) "source or parent lineage changed"

$sourcePolicy = $closure["source_binding_policy"]
Assert-R23D57Closure (
    [string]$sourcePolicy["mode"] -ceq
        "sha256_exact_pinned_git_blob_bytes_at_source_freeze_commit" -and
    [bool]$sourcePolicy["duplicate_paths_forbidden"] -and
    [bool]$sourcePolicy["all_declared_paths_required"] -and
    [bool]$sourcePolicy[
        "live_checkout_identity_not_used_as_historical_source_authority"
    ]
) "source-binding policy changed"
$requiredSourcePaths = @(
    "sdk/turning/r23d57_godot_full_precision_trace_transport_contract_v1.json",
    "sdk/turning/r23d57_godot_full_precision_trace_transport.py",
    "tests/test_sdk_qsdk_r23d57_godot_full_precision_trace_transport.gd",
    "tests/test_qsdk_r23d57_godot_full_precision_trace_transport.ps1",
    "sdk/turning/r23d56_godot_valid_route_actuator_phase_characterization_closure_v1.json",
    ".gitattributes",
    "sdk/closure_evidence_provenance_contract.json",
    "tests/test_closure_evidence_provenance_contract.ps1",
    "sdk/release/quadruped_release_contract.json",
    "sdk/release/quadruped_support_matrix.json",
    "sdk/workbench/experiment_catalog.json",
    "project.godot"
)
$sourceBytes = @{}
$seenPaths = [Collections.Generic.HashSet[string]]::new(
    [StringComparer]::Ordinal
)
foreach ($binding in @($sourcePolicy["bindings"])) {
    $relativePath = [string]$binding["path"]
    Assert-R23D57Closure ($seenPaths.Add($relativePath)) (
        "duplicate source binding: $relativePath"
    )
    Assert-R23D57Closure (
        [string]$binding["raw_sha256"] -cmatch '^sha256:[0-9a-f]{64}$' -and
        [string]$binding["git_blob_oid"] -cmatch '^[0-9a-f]{40}$'
    ) "malformed source binding: $relativePath"
    $blobOid = (& git -C $repoRoot rev-parse "${sourceCommit}:$relativePath").Trim()
    Assert-R23D57Closure (
        $LASTEXITCODE -eq 0 -and
        $blobOid -ceq [string]$binding["git_blob_oid"]
    ) "source Git blob changed: $relativePath"
    $bytes = Get-R23D57GitBlobBytes -Commit $sourceCommit -Path $relativePath
    Assert-R23D57Closure (
        (Get-R23D57ClosureBytesSha256 $bytes) -ceq
            [string]$binding["raw_sha256"]
    ) "source raw bytes changed: $relativePath"
    $sourceBytes[$relativePath] = $bytes
}
Assert-R23D57Closure (
    $seenPaths.Count -eq 12 -and
    @($requiredSourcePaths | Where-Object { -not $seenPaths.Contains($_) }).Count -eq 0
) "source dependency closure is incomplete"

$runtimePolicy = $closure["runtime_bindings"]
Assert-R23D57Closure (
    [string]$runtimePolicy["operating_system_description"] -ceq
        "Microsoft Windows 10.0.26100" -and
    [string]$runtimePolicy["operating_system_architecture"] -ceq "X64" -and
    [string]$runtimePolicy["process_architecture"] -ceq "X64" -and
    @($runtimePolicy["bindings"]).Count -eq 4
) "runtime environment boundary changed"
$runtimeByRole = @{}
foreach ($binding in @($runtimePolicy["bindings"])) {
    $role = [string]$binding["role"]
    Assert-R23D57Closure (-not $runtimeByRole.ContainsKey($role)) (
        "duplicate runtime role: $role"
    )
    $runtimePath = [string]$binding["path"]
    Assert-R23D57Closure (Test-Path -LiteralPath $runtimePath -PathType Leaf) (
        "runtime is unavailable: $role"
    )
    $runtimeItem = Get-Item -LiteralPath $runtimePath
    Assert-R23D57Closure (
        [long]$runtimeItem.Length -eq [long]$binding["byte_length"] -and
        (Get-R23D57ClosureRawSha256 $runtimePath) -ceq
            [string]$binding["raw_sha256"]
    ) "runtime identity changed: $role"
    $runtimeByRole[$role] = $binding
}
Assert-R23D57Closure (
    @($runtimeByRole.Keys | Sort-Object) -join "|" -ceq
        "cpython|git|godot_console|powershell" -and
    [string]$runtimeByRole["godot_console"]["version"] -ceq
        "4.7.stable.mono.official.5b4e0cb0f" -and
    [string]$runtimeByRole["cpython"]["version"] -ceq "Python 3.11.9" -and
    [string]$runtimeByRole["powershell"]["version"] -ceq "7.6.4" -and
    [string]$runtimeByRole["git"]["version"] -ceq
        "git version 2.53.0.windows.3"
) "runtime role set or version changed"

$executions = $closure["authoritative_executions"]
$aggregate = $executions["aggregate_audit"]
$direct = $executions["direct_validator"]
Assert-R23D57Closure (
    [datetime]$aggregate["started_utc"] -lt [datetime]$aggregate["ended_utc"] -and
    [int]$aggregate["exit_code"] -eq 0 -and
    [int]$aggregate["marker_count"] -eq 1 -and
    [string]$aggregate["marker"] -ceq (
        "QSDK_R23D57_FULL_PRECISION_TRACE_TRANSPORT_AUDIT_PASS " +
        "fixtures=35 default_target_failures=14 default_impulse_failures=0 " +
        "full_target_failures=0 full_impulse_failures=0 " +
        "full_binary64_mismatches=0 mutations=12 boundary_controls=2 " +
        "godot_processes=1 models=0 worlds=0 threshold_changes=0 " +
        "physical_authority=False " +
        "contract_sha256=857364bb62aa667cd0ee152cd3c241996a462922181f9d675d6fe9d7a6f3fedd " +
        "validator_sha256=d9ece088eb692c126e1d173aa6070be62118fce45b5ffe203d4731aec1940ffd " +
        "godot_sha256=03e46bec904245078ac45ac33da9a260c428d7a1e897197628528ebc8471b749"
    ) -and
    [datetime]$direct["started_utc"] -lt [datetime]$direct["ended_utc"] -and
    [int]$direct["exit_code"] -eq 0 -and
    [int]$direct["marker_count"] -eq 1
) "authoritative execution receipt changed"

$result = $closure["result"]
$expectedMutations = @(
    "full_precision_flag_false",
    "missing_fixture",
    "duplicate_fixture_id",
    "full_precision_replaced_by_default",
    "missing_full_precision_json",
    "reported_target_error_perturbed",
    "readback_operand_perturbed",
    "wrong_contract_id",
    "consistency_tolerance_changed",
    "world_attempt_opened",
    "physical_readback_bound_exceeded",
    "default_negative_control_replaced"
)
Assert-R23D57Closure (
    [string]$result["schema_version"] -ceq
        "sporespore_qsdk_r23d57_full_precision_trace_transport_result_v1" -and
    [int]$result["godot_version"]["major"] -eq 4 -and
    [int]$result["godot_version"]["minor"] -eq 7 -and
    [int]$result["godot_version"]["patch"] -eq 0 -and
    [string]$result["godot_version"]["status"] -ceq "stable" -and
    [string]$result["godot_version"]["build"] -ceq "official" -and
    [string]$result["godot_version"]["hash"] -ceq
        "5b4e0cb0fd279832bbdd69fed5354d4e5ad26f88" -and
    [int]$result["retained_failure_shape_fixture_count"] -eq 1 -and
    [int]$result["independent_literal_fixture_count"] -eq 2 -and
    [int]$result["deterministic_cancellation_fixture_count"] -eq 32 -and
    [double]$result["maximum_default_target_residual"] -eq
        9.769962613392655e-15 -and
    [double]$result["maximum_default_impulse_residual"] -eq
        8.326672715707947e-17 -and
    [double]$result["maximum_full_precision_target_residual"] -eq 0.0 -and
    [double]$result["maximum_full_precision_impulse_residual"] -eq 0.0 -and
    (@($result["mutation_rejections"]) -join "|") -ceq
        ($expectedMutations -join "|")
) "exact result metrics or mutations changed"

$incidents = $closure["development_incidents"]
Assert-R23D57Closure (
    [int]$incidents["retained_incident_count"] -eq 3 -and
    [bool]$incidents[
        "redundant_godot_cpython_default_parse_residual_comparison_rejected"
    ] -and
    [bool]$incidents["powershell_multiple_python_candidate_resolution_rejected"] -and
    [bool]$incidents["workbench_catalog_count_registration_rejected"] -and
    [bool]$incidents["all_incident_world_counts_zero"] -and
    [int]$incidents["incident_threshold_change_count"] -eq 0 -and
    [int]$incidents["incident_transport_result_reinterpretation_count"] -eq 0
) "development incidents were lost or reinterpreted"

$closureHistory = $closure["closure_process_history"]
$initialClosureAuditBytes = Get-R23D57GitBlobBytes `
    -Commit $initialClosureBoundaryCommit `
    -Path "tests/test_qsdk_r23d57_godot_full_precision_trace_transport_closure.ps1"
$reconstructedInitialClosureAuditHash = Get-R23D57ClosureBytesSha256 (
    $initialClosureAuditBytes
)
$preInventoryAudit = $closureHistory["local_pre_inventory_closure_audit"]
$inventoryFailure = $closureHistory[
    "initial_provenance_inventory_verification"
]
$liveMirrorFailure = $closureHistory[
    "initial_integrated_live_mirror_audit"
]
Assert-R23D57Closure (
    [int]$closureHistory["retained_event_count"] -eq 3 -and
    [string]$preInventoryAudit["status"] -ceq "passed" -and
    [string]$preInventoryAudit["audit_raw_sha256"] -ceq
        "sha256:4dc2eca01c0aae92e47dbb9a948c845de989a5b3711674e11ff8fb28ec5a3ee4" -and
    [string]$preInventoryAudit["closure_raw_sha256"] -ceq
        "sha256:f36e976ecab2cc7827d7f7f61f337b51760391ccbffa13306487b35caeb1b478" -and
    [int]$preInventoryAudit["closure_mutation_rejection_count"] -eq 16 -and
    [int]$preInventoryAudit["world_build_count"] -eq 0 -and
    -not [bool]$preInventoryAudit["physical_acceptance_authority"] -and
    [string]$inventoryFailure["status"] -ceq
        "failed_closed_expected_inventory_extension" -and
    [string]$inventoryFailure["failure_message"] -ceq
        "Closure evidence-mode executable inventory verification failed" -and
    [int]$inventoryFailure["pre_audit_count"] -eq 152 -and
    [int]$inventoryFailure["observed_analyzer_audit_count"] -eq 153 -and
    [int]$inventoryFailure["observed_analyzer_cas_path_check_count"] -eq 73 -and
    [int]$inventoryFailure["observed_analyzer_pinned_git_blob_count"] -eq 133 -and
    [int]$inventoryFailure[
        "observed_analyzer_reconstructed_checkout_count"
    ] -eq 2 -and
    [int]$inventoryFailure["observed_analyzer_live_risk_count"] -eq 0 -and
    [int]$inventoryFailure["observed_analyzer_manual_review_count"] -eq 20 -and
    [string]$inventoryFailure["new_audit_path"] -ceq
        "tests/test_qsdk_r23d57_godot_full_precision_trace_transport_closure.ps1" -and
    [string]$inventoryFailure["new_audit_raw_sha256_at_failure"] -ceq
        "sha256:4dc2eca01c0aae92e47dbb9a948c845de989a5b3711674e11ff8fb28ec5a3ee4" -and
    [string]$inventoryFailure["historical_identity_mode"] -ceq
        "pinned_git_blob" -and
    (@($inventoryFailure["detected_modes"]) -join "|") -ceq
        "pinned_git_blob|live_repo_or_checkout_hash" -and
    -not [bool]$inventoryFailure["live_historical_identity_risk"] -and
    -not [bool]$inventoryFailure["manual_review_required"] -and
    [int]$inventoryFailure["threshold_change_count"] -eq 0 -and
    [int]$inventoryFailure["historical_reclassification_count"] -eq 0 -and
    [int]$inventoryFailure["world_attempt_count"] -eq 0 -and
    [int]$inventoryFailure["world_build_count"] -eq 0 -and
    -not [bool]$inventoryFailure["physical_acceptance_authority"] -and
    [string]$liveMirrorFailure["status"] -ceq
        "failed_closed_after_frozen_transport_replay" -and
    [string]$liveMirrorFailure["failure_message"] -ceq
        "QSDK-R23D57 TRANSPORT CLOSURE: workbench live release proof hashes changed" -and
    [string]$liveMirrorFailure["audit_raw_sha256"] -ceq
        "sha256:3f1fdf9033fb66f702f85daa85e12115c35f61ad859baaae5312f062461decfc" -and
    [string]$liveMirrorFailure["closure_raw_sha256"] -ceq
        "sha256:a5237eb44bc579ee6dee8a8e4dc293ee4eb2994477560913a8ba548de294f70b" -and
    [bool]$liveMirrorFailure["frozen_transport_replay_passed_before_failure"] -and
    [string]$liveMirrorFailure["root_cause"] -ceq
        "only_the_first_of_four_workbench_release_support_proof_pairs_was_updated" -and
    [int]$liveMirrorFailure["stale_workbench_proof_pair_count"] -eq 3 -and
    [int]$liveMirrorFailure["threshold_change_count"] -eq 0 -and
    [int]$liveMirrorFailure["result_reinterpretation_count"] -eq 0 -and
    [int]$liveMirrorFailure["godot_process_launch_count"] -eq 1 -and
    [int]$liveMirrorFailure["world_attempt_count"] -eq 0 -and
    [int]$liveMirrorFailure["world_build_count"] -eq 0 -and
    -not [bool]$liveMirrorFailure["physical_acceptance_authority"] -and
    [string]$closureHistory["adopted_closure_audit_path"] -ceq
        "tests/test_qsdk_r23d57_godot_full_precision_trace_transport_closure.ps1" -and
    [string]$closureHistory["adopted_closure_audit_raw_sha256"] -ceq
        $initialClosureAuditRawSha256 -and
    $reconstructedInitialClosureAuditHash -ceq $initialClosureAuditRawSha256
) "closure-process positive and negative history changed"

$mutationRejections = [Collections.Generic.List[string]]::new()
$mutations = @(
    @{ name = "closure_status"; apply = { param($x) $x["status"] = "positive_physical" } },
    @{ name = "source_commit"; apply = { param($x) $x["immutable_lineage"]["source_freeze_commit"] = "0000000000000000000000000000000000000000" } },
    @{ name = "r23d56_rerun"; apply = { param($x) $x["immutable_lineage"]["r23d56_rerun_allowed"] = $true } },
    @{ name = "threshold"; apply = { param($x) $x["declared_change"]["reported_error_recomputation_consistency_tolerance"] = 1.0e-12 } },
    @{ name = "transport_count"; apply = { param($x) $x["declared_change"]["evidence_transport_change_count"] = 0 } },
    @{ name = "fixture_count"; apply = { param($x) $x["result"]["fixture_count"] = 34 } },
    @{ name = "default_control"; apply = { param($x) $x["result"]["default_target_consistency_failure_count"] = 13 } },
    @{ name = "full_target_failure"; apply = { param($x) $x["result"]["full_precision_target_consistency_failure_count"] = 1 } },
    @{ name = "binary64_mismatch"; apply = { param($x) $x["result"]["full_precision_binary64_roundtrip_mismatch_count"] = 1 } },
    @{ name = "mutation_count"; apply = { param($x) $x["result"]["mutation_rejection_count"] = 11 } },
    @{ name = "above_boundary"; apply = { param($x) $x["result"]["above_boundary_rejected"] = $false } },
    @{ name = "world_count"; apply = { param($x) $x["result"]["world_attempt_count"] = 1 } },
    @{ name = "closure_history_count"; apply = { param($x) $x["closure_process_history"]["retained_event_count"] = 1 } },
    @{ name = "inventory_failure_erased"; apply = { param($x) $x["closure_process_history"]["initial_provenance_inventory_verification"]["status"] = "passed" } },
    @{ name = "live_mirror_failure_erased"; apply = { param($x) $x["closure_process_history"]["initial_integrated_live_mirror_audit"]["status"] = "passed" } },
    @{ name = "physical_implementation"; apply = { param($x) $x["claims"]["r23d57_physical_implementation_complete"] = $true } },
    @{ name = "turning"; apply = { param($x) $x["claims"]["godot_jolt_turning_validation"] = $true } },
    @{ name = "prone"; apply = { param($x) $x["claims"]["prone_to_standing"] = $true } },
    @{ name = "release"; apply = { param($x) $x["claims"]["release_authorized"] = $true } }
)
foreach ($mutation in $mutations) {
    $candidate = Copy-R23D57Json $closure
    & $mutation.apply $candidate
    Assert-R23D57Closure (-not (Test-R23D57ClosureCandidate $candidate)) (
        "closure mutation was accepted: $($mutation.name)"
    )
    $mutationRejections.Add([string]$mutation.name)
}
Assert-R23D57Closure (
    $mutationRejections.Count -eq 19 -and
    @($mutationRejections | Select-Object -Unique).Count -eq 19
) "closure mutation cardinality changed"

$temporaryBase = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd(
    '\', '/'
)
$materializedRoot = [IO.Path]::GetFullPath(
    (Join-Path $temporaryBase (
        "sporespore-r23d57-transport-" + [guid]::NewGuid().ToString("N")
    ))
)
Assert-R23D57Closure (
    $materializedRoot.StartsWith(
        $temporaryBase + [IO.Path]::DirectorySeparatorChar,
        [StringComparison]::OrdinalIgnoreCase
    ) -and
    [IO.Path]::GetFileName($materializedRoot).StartsWith(
        "sporespore-r23d57-transport-",
        [StringComparison]::Ordinal
    )
) "temporary materialization path escaped the validated root"
$replayPaths = @(
    "sdk/turning/r23d57_godot_full_precision_trace_transport_contract_v1.json",
    "sdk/turning/r23d57_godot_full_precision_trace_transport.py",
    "tests/test_sdk_qsdk_r23d57_godot_full_precision_trace_transport.gd",
    "project.godot"
)
try {
    [void][IO.Directory]::CreateDirectory($materializedRoot)
    foreach ($relativePath in $replayPaths) {
        $destination = Join-Path $materializedRoot $relativePath
        [void][IO.Directory]::CreateDirectory((Split-Path -Parent $destination))
        [IO.File]::WriteAllBytes($destination, [byte[]]$sourceBytes[$relativePath])
    }
    $priorNoBytecode = $env:PYTHONDONTWRITEBYTECODE
    try {
        $env:PYTHONDONTWRITEBYTECODE = "1"
        $replayOutput = @(
            & ([string]$runtimeByRole["cpython"]["path"]) -B `
                (Join-Path $materializedRoot (
                    "sdk\turning\" +
                    "r23d57_godot_full_precision_trace_transport.py"
                )) `
                --godot ([string]$runtimeByRole["godot_console"]["path"]) `
                --source-root $materializedRoot 2>&1 |
                ForEach-Object { [string]$_ }
        )
        $replayExit = $LASTEXITCODE
    } finally {
        $env:PYTHONDONTWRITEBYTECODE = $priorNoBytecode
    }
    Assert-R23D57Closure ($replayExit -eq 0) (
        "frozen validator replay failed: $($replayOutput -join ' | ')"
    )
    $replayMarkers = @(
        $replayOutput | Where-Object { $_.StartsWith($validatorMarker) }
    )
    Assert-R23D57Closure ($replayMarkers.Count -eq 1) (
        "expected one frozen validator receipt, found $($replayMarkers.Count)"
    )
    $replay = $replayMarkers[0].Substring($validatorMarker.Length) |
        ConvertFrom-Json -AsHashtable -Depth 64
    Assert-R23D57Closure (
        [int]$replay["fixture_count"] -eq 35 -and
        [int]$replay["default_target_consistency_failure_count"] -eq 14 -and
        [int]$replay["default_impulse_consistency_failure_count"] -eq 0 -and
        [int]$replay["full_precision_target_consistency_failure_count"] -eq 0 -and
        [int]$replay["full_precision_impulse_consistency_failure_count"] -eq 0 -and
        [int]$replay["full_precision_binary64_roundtrip_mismatch_count"] -eq 0 -and
        [double]$replay["maximum_residuals"]["default_target"] -eq
            [double]$result["maximum_default_target_residual"] -and
        [double]$replay["maximum_residuals"]["default_impulse"] -eq
            [double]$result["maximum_default_impulse_residual"] -and
        [double]$replay["maximum_residuals"]["full_target"] -eq
            [double]$result["maximum_full_precision_target_residual"] -and
        [double]$replay["maximum_residuals"]["full_impulse"] -eq
            [double]$result["maximum_full_precision_impulse_residual"] -and
        [int]$replay["mutation_rejection_count"] -eq 12 -and
        [int]$replay["boundary_control_count"] -eq 2 -and
        [int]$replay["model_construction_count"] -eq 0 -and
        [int]$replay["world_attempt_count"] -eq 0 -and
        [int]$replay["world_build_count"] -eq 0 -and
        -not [bool]$replay["physical_acceptance_authority"]
    ) "frozen source replay diverged from the retained result"
} finally {
    if (Test-Path -LiteralPath $materializedRoot -PathType Container) {
        $resolvedMaterializedRoot = [IO.Path]::GetFullPath($materializedRoot)
        Assert-R23D57Closure (
            $resolvedMaterializedRoot.StartsWith(
                $temporaryBase + [IO.Path]::DirectorySeparatorChar,
                [StringComparison]::OrdinalIgnoreCase
            ) -and
            [IO.Path]::GetFileName($resolvedMaterializedRoot).StartsWith(
                "sporespore-r23d57-transport-",
                [StringComparison]::Ordinal
            )
        ) "cleanup target escaped the validated temporary root"
        Remove-Item -LiteralPath $resolvedMaterializedRoot -Recurse -Force
    }
}

foreach ($livePath in @(
    $releaseContractPath,
    $supportMatrixPath,
    $workbenchCatalogPath
)) {
    Assert-R23D57Closure (Test-Path -LiteralPath $livePath -PathType Leaf) (
        "live authority is missing: $livePath"
    )
}
$releaseContract = Get-Content -Raw -LiteralPath $releaseContractPath |
    ConvertFrom-Json -AsHashtable -Depth 100
$supportMatrix = Get-Content -Raw -LiteralPath $supportMatrixPath |
    ConvertFrom-Json -AsHashtable -Depth 100
$workbenchCatalog = Get-Content -Raw -LiteralPath $workbenchCatalogPath |
    ConvertFrom-Json -AsHashtable -Depth 100
$recordKey = "prospective_r23d57_full_precision_trace_transport"
$releaseRecord = Find-R23D57Record $releaseContract $recordKey
$supportRecord = Find-R23D57Record $supportMatrix $recordKey
$expectedLiveStatus = (
    "closed_complete_valid_positive_exact_zero_world_transport_" +
    "conformance_physical_campaign_consumed_invalid_complete"
)
$releaseCurrentSuccessor = [string](Find-R23D57Record $releaseContract (
    "current_successor_status"
))
$supportCurrentSuccessor = [string](Find-R23D57Record $supportMatrix (
    "current_successor_status"
))
$releaseCurrentProspective = [string](Find-R23D57Record $releaseContract (
    "current_prospective_successor_status"
))
$supportCurrentProspective = [string](Find-R23D57Record $supportMatrix (
    "current_prospective_successor_status"
))
$releaseCurrentReason = [string](Find-R23D57Record $releaseContract (
    "current_successor_reason"
))
$supportCurrentReason = [string](Find-R23D57Record $supportMatrix (
    "current_successor_reason"
))
Assert-R23D57Closure (
    $null -ne $releaseRecord -and
    $null -ne $supportRecord -and
    -not [string]::IsNullOrWhiteSpace($releaseCurrentSuccessor) -and
    $releaseCurrentSuccessor -ceq $supportCurrentSuccessor -and
    -not [string]::IsNullOrWhiteSpace($releaseCurrentProspective) -and
    $releaseCurrentProspective -ceq $supportCurrentProspective -and
    -not [string]::IsNullOrWhiteSpace($releaseCurrentReason) -and
    $releaseCurrentReason -ceq $supportCurrentReason
) "live turning pointer mirrors diverged"

$closureHash = Get-R23D57ClosureRawSha256 $closurePath
$closureAuditHash = Get-R23D57ClosureRawSha256 $closureAuditPath
foreach ($record in @($releaseRecord, $supportRecord)) {
    Assert-R23D57Closure (
        [string]$record["status"] -ceq $expectedLiveStatus -and
        [string]$record["question_class"] -ceq "development" -and
        [bool]$record["physical_question_declared"] -and
        [bool]$record["physical_campaign_opened"] -and
        [string]$record["source_freeze_commit"] -ceq $sourceCommit -and
        [string]$record["source_freeze_tree_git_oid"] -ceq $sourceTree -and
        [string]$record["closure_path"] -ceq
            "sdk/turning/r23d57_godot_full_precision_trace_transport_closure_v1.json" -and
        [string]$record["closure_audit_path"] -ceq
            "tests/test_qsdk_r23d57_godot_full_precision_trace_transport_closure.ps1" -and
        [bool]$record["local_zero_world_transport_gate_passed"] -and
        [bool]$record["zero_world_transport_result_closed"] -and
        [bool]$record["clean_pushed_zero_world_closure_exists"] -and
        [bool]$record["closure_inventory_failure_retained"] -and
        [bool]$record["physical_implementation_complete"] -and
        [bool]$record["physical_worker_complete"] -and
        [bool]$record["physical_evaluator_complete"] -and
        [bool]$record["physical_supervisor_complete"] -and
        [bool]$record["campaign_attestation_manifest_complete"] -and
        [bool]$record["closure_audit_compatibility_maintenance_active"] -and
        [string]$record["original_closure_audit_boundary_commit"] -ceq
            $initialClosureBoundaryCommit -and
        [string]$record["closure_audit_role"] -ceq
            "live_compatibility_audit_pinning_immutable_initial_closure_audit" -and
        [bool]$record[
            "closure_audit_reused_after_live_physical_implementation_progression"
        ] -and
        [bool]$record["complete_zero_world_campaign_gate_passed"] -and
        [bool]$record["scoped_qualification_passed"] -and
        [bool]$record["adoption_passed"] -and
        [bool]$record["physical_execution_was_authorized"] -and
        [bool]$record["physical_execution_completed"] -and
        [bool]$record["physical_attempt_identity_consumed"] -and
        [bool]$record["fresh_worlds_required_for_any_physical_result"] -and
        -not [bool]$record["physical_execution_authorized"] -and
        -not [bool]$record["actuator_phase_characterization_complete"] -and
        -not [bool]$record["turning_mechanism_selected"] -and
        -not [bool]$record["turning_acceptance"] -and
        -not [bool]$record["godot_jolt_turning_validation"] -and
        -not [bool]$record["finite_three_engine_turning"] -and
        -not [bool]$record["portable_basic_turning"] -and
        -not [bool]$record["prone_to_standing"] -and
        -not [bool]$record["release_authorized"] -and
        -not [bool]$record["physical_acceptance_authority"]
    ) "live release/support closure boundary changed"
}
Assert-R23D57Closure (
    [string]$releaseRecord["closure_raw_sha256"] -ceq $closureHash -and
    [string]$supportRecord["closure_sha256"] -ceq $closureHash -and
    [string]$releaseRecord["closure_audit_raw_sha256"] -ceq
        $closureAuditHash -and
    [string]$supportRecord["closure_audit_sha256"] -ceq
        $closureAuditHash -and
    [string]$releaseRecord["original_closure_audit_raw_sha256"] -ceq
        $initialClosureAuditRawSha256 -and
    [string]$supportRecord["original_closure_audit_sha256"] -ceq
        $initialClosureAuditRawSha256
) "live release/support closure hash binding changed"

$workbenchRuns = @($workbenchCatalog["runs"])
$workbenchEntry = @($workbenchRuns | Where-Object {
    [string]$_["id"] -ceq "qsdk_r23d57_full_precision_trace_transport"
})
Assert-R23D57Closure (
    $workbenchEntry.Count -eq 1 -and
    [string]$workbenchEntry[0]["kind"] -ceq
        "zero_world_conformance_gate" -and
    [string]$workbenchEntry[0]["status"] -ceq
        "closed_positive_transport_physical_campaign_consumed_invalid_complete" -and
    [string]$workbenchEntry[0]["world_policy"] -ceq "zero_world_only" -and
    [string]$workbenchEntry[0]["risk"] -ceq "safe" -and
    [string]$workbenchEntry[0]["runner_path"] -ceq
        "tests/test_qsdk_r23d57_godot_full_precision_trace_transport_closure.ps1"
) "workbench R23D57 closure entry changed"
$workbenchProofs = @{}
foreach ($proof in @($workbenchEntry[0]["proofs"])) {
    $workbenchProofs[[string]$proof["path"]] =
        [string]$proof["expected_sha256"]
}
foreach ($binding in @{
    "sdk/turning/r23d57_godot_full_precision_trace_transport_closure_v1.json" =
        $closurePath
    "tests/test_qsdk_r23d57_godot_full_precision_trace_transport_closure.ps1" =
        $closureAuditPath
}.GetEnumerator()) {
    Assert-R23D57Closure (
        $workbenchProofs.ContainsKey([string]$binding.Key) -and
        [string]$workbenchProofs[[string]$binding.Key] -ceq
            (Get-R23D57ClosureRawSha256 ([string]$binding.Value)).Substring(7)
    ) "workbench R23D57 closure proof changed: $([string]$binding.Key)"
}
$releaseReadiness = @($workbenchRuns | Where-Object {
    [string]$_["id"] -ceq "release_readiness"
})
Assert-R23D57Closure ($releaseReadiness.Count -eq 1) (
    "workbench release-readiness entry changed"
)
$releaseProofs = @{}
foreach ($proof in @($releaseReadiness[0]["proofs"])) {
    $releaseProofs[[string]$proof["path"]] =
        [string]$proof["expected_sha256"]
}
Assert-R23D57Closure (
    [string]$releaseProofs[
        "sdk/release/quadruped_release_contract.json"
    ] -ceq (Get-R23D57ClosureRawSha256 $releaseContractPath).Substring(7) -and
    [string]$releaseProofs[
        "sdk/release/quadruped_support_matrix.json"
    ] -ceq (Get-R23D57ClosureRawSha256 $supportMatrixPath).Substring(7)
) "workbench live release proof hashes changed"

Write-Host (
    "QSDK_R23D57_FULL_PRECISION_TRACE_TRANSPORT_CLOSURE_PASS " +
    "source=95f6acf tree=ade2026 bindings=12 runtimes=4 fixtures=35 " +
    "default_target_failures=14 full_target_failures=0 " +
    "full_impulse_failures=0 binary64_mismatches=0 canary_mutations=12 " +
    "closure_mutations=19 boundary_controls=2 replay=True live_mirrors=True " +
    "historical_audit_pinned=True compatibility=True " +
    "models=0 worlds=0 " +
    "turning=False prone=False release=False physical_authority=False " +
    "closure_sha256=$(Get-R23D57ClosureRawSha256 $closurePath)"
)
