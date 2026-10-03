#requires -Version 7.0

[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot)).TrimEnd('\', '/')
$expectedRemote = "https://github.com/Slagathore/sporespore.git"
$contractRelativePath = "sdk/turning/r23d55_godot_live_fixture_actuator_cap_conformance_v1.json"
$contractPath = Join-Path $repoRoot $contractRelativePath
$compatibilityRelativePath = "sdk/turning/r23d55_post_rc7_audit_compatibility_v1.json"
$compatibilityPath = Join-Path $repoRoot $compatibilityRelativePath
$releasePath = Join-Path $repoRoot "sdk/release/quadruped_release_contract.json"
$supportPath = Join-Path $repoRoot "sdk/release/quadruped_support_matrix.json"
$runnerPath = Join-Path $repoRoot "sdk/run_conformance.ps1"
$blockKey = "prospective_r23d55_live_fixture_actuator_cap_conformance"
$observedSourceCommit = "0d173d385f22fb8a30e7cc2234be8b17799512d9"
$observedSourceTree = "e8339ab265285647a1ccf09a67ade080cea93c08"

function Assert-R23D55([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "QSDK-R23D55 CAP CONFORMANCE: $Message" }
}

function Get-R23D55RawSha256([string]$Path) {
    return "sha256:" + (
        Get-FileHash -LiteralPath $Path -Algorithm SHA256
    ).Hash.ToLowerInvariant()
}

function Get-R23D55GitBlobBytes {
    param(
        [Parameter(Mandatory = $true)][string]$Commit,
        [Parameter(Mandatory = $true)][string]$Path
    )

    $startInfo = [Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = "git"
    $startInfo.WorkingDirectory = $repoRoot
    $startInfo.UseShellExecute = $false
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    foreach ($argument in @("-C", $repoRoot, "cat-file", "blob", "${Commit}:$Path")) {
        [void]$startInfo.ArgumentList.Add($argument)
    }

    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $startInfo
    $memory = [IO.MemoryStream]::new()
    try {
        Assert-R23D55 ($process.Start()) "Unable to start Git blob reader for $Path."
        $copyTask = $process.StandardOutput.BaseStream.CopyToAsync($memory)
        $errorTask = $process.StandardError.ReadToEndAsync()
        $process.WaitForExit()
        [void]$copyTask.GetAwaiter().GetResult()
        $errorText = $errorTask.GetAwaiter().GetResult()
        Assert-R23D55 ($process.ExitCode -eq 0) (
            "Unable to reconstruct $Commit`:$Path from Git: $errorText"
        )
        return ,$memory.ToArray()
    } finally {
        $memory.Dispose()
        $process.Dispose()
    }
}

function Get-R23D55GitBlobRawSha256 {
    param(
        [Parameter(Mandatory = $true)][string]$Commit,
        [Parameter(Mandatory = $true)][string]$Path
    )

    $bytes = Get-R23D55GitBlobBytes -Commit $Commit -Path $Path
    return "sha256:" + [Convert]::ToHexString(
        [Security.Cryptography.SHA256]::HashData($bytes)
    ).ToLowerInvariant()
}

function Find-R23D55ObjectsWithKey {
    param(
        [AllowNull()]$Value,
        [Parameter(Mandatory = $true)][string]$Key
    )

    $found = @()
    if ($null -eq $Value) { return $found }
    if ($Value -is [System.Collections.IDictionary]) {
        if ($Value.Contains($Key)) { $found += ,$Value }
        foreach ($child in $Value.Values) {
            $found += @(Find-R23D55ObjectsWithKey -Value $child -Key $Key)
        }
    } elseif (
        $Value -is [System.Collections.IEnumerable] -and
        $Value -isnot [string]
    ) {
        foreach ($child in $Value) {
            $found += @(Find-R23D55ObjectsWithKey -Value $child -Key $Key)
        }
    }
    return $found
}

foreach ($path in @(
    $contractPath,
    $compatibilityPath,
    $releasePath,
    $supportPath,
    $runnerPath
)) {
    Assert-R23D55 (Test-Path -LiteralPath $path -PathType Leaf) "Missing authority: $path"
}

$observedRoot = [IO.Path]::GetFullPath((& git -C $repoRoot rev-parse --show-toplevel).Trim()).TrimEnd('\', '/')
Assert-R23D55 ($LASTEXITCODE -eq 0) "Unable to resolve repository root."
$observedRemote = (& git -C $repoRoot remote get-url origin).Trim()
Assert-R23D55 ($LASTEXITCODE -eq 0) "Unable to resolve origin remote."
Assert-R23D55 ($observedRoot -ceq $repoRoot) "Repository root changed: $observedRoot"
Assert-R23D55 ($observedRemote -ceq $expectedRemote) "Origin remote changed: $observedRemote"

$contract = Get-Content -LiteralPath $contractPath -Raw |
    ConvertFrom-Json -AsHashtable -Depth 64
$compatibility = Get-Content -LiteralPath $compatibilityPath -Raw |
    ConvertFrom-Json -AsHashtable -Depth 64
$release = Get-Content -LiteralPath $releasePath -Raw |
    ConvertFrom-Json -AsHashtable -Depth 128
$support = Get-Content -LiteralPath $supportPath -Raw |
    ConvertFrom-Json -AsHashtable -Depth 128

Assert-R23D55 (
    [string]$contract["schema_version"] -ceq
        "sporespore_qsdk_r23d55_godot_live_fixture_actuator_cap_conformance_contract_v1" -and
    [string]$contract["status"] -ceq
        "implemented_local_zero_world_conformance_passed_physical_successor_not_opened" -and
    [string]$contract["gate_id"] -ceq "QSDK-R23D55" -and
    [string]$contract["question_class"] -ceq "development" -and
    -not [bool]$contract["physical_question_declared"] -and
    -not [bool]$contract["physical_campaign_opened"]
) "Contract identity or question class changed."

$compatParent = $compatibility["declared_from_parent"]
$compatObservation = $compatibility["immutable_r23d55_observation"]
$successorIncident = $compatibility["r23d58_successor_compatibility_incident"]
$historicalPolicy = $compatibility["historical_binding_verification"]
$livePolicy = $compatibility["live_binding_verification"]
$compatPolicy = $compatibility["audit_compatibility_policy"]
$compatZeroWorld = $compatibility["zero_world_boundary"]
$compatClaims = $compatibility["claims"]
Assert-R23D55 (
    [string]$compatibility["schema_version"] -ceq
        "sporespore_qsdk_r23d55_post_rc7_audit_compatibility_contract_v1" -and
    [string]$compatibility["status"] -ceq
        "implemented_zero_world_historical_and_live_binding_split_extended_for_r23d58_successor" -and
    [string]$compatibility["maintenance_id"] -ceq
        "QSDK-R23D55-POST-RC7-AUDIT-COMPATIBILITY" -and
    [string]$compatibility["question_class"] -ceq "development" -and
    -not [bool]$compatibility["physical_question_declared"] -and
    -not [bool]$compatibility["pre_maintenance_live_audit_failure_invoked"] -and
    [string]$compatParent["commit"] -ceq
        "79ec6b4a4f2b0b2324c0842ead31bdf4d542c4d0" -and
    [string]$compatParent["tree"] -ceq
        "ba445c7305397f6dac1a3b996da63d3541f9f6c7" -and
    [bool]$compatParent["local_upstream_and_live_remote_equal"] -and
    [bool]$compatParent["worktree_clean"] -and
    [string]$compatObservation["source_commit"] -ceq $observedSourceCommit -and
    [string]$compatObservation["source_tree"] -ceq $observedSourceTree -and
    [int]$compatObservation["source_binding_count"] -eq 19 -and
    -not [bool]$compatObservation["observed_result_changed"] -and
    -not [bool]$compatObservation["threshold_changed"] -and
    -not [bool]$compatObservation["selector_changed"] -and
    -not [bool]$compatObservation["evaluator_changed"] -and
    -not [bool]$compatObservation["interpretation_changed"] -and
    -not [bool]$compatObservation["physical_rerun_authorized"]
) "Prospective audit-compatibility boundary changed."

Assert-R23D55 (
    [bool]$successorIncident["observed"] -and
    [string]$successorIncident["status"] -ceq
        "local_zero_world_audit_negative_live_successor_source_coupled_to_immutable_observation" -and
    [string]$successorIncident["failed_gate_path"] -ceq
        "tests/test_qsdk_r23d55_live_fixture_actuator_cap_contract.ps1" -and
    [string]$successorIncident["failure_message"] -ceq
        "QSDK-R23D55 CAP CONFORMANCE: Bound live source drifted: scripts/lab/gait/physical_wave_gait_quadruped.gd" -and
    -not [bool]$successorIncident["failure_reached_r23d55_runtime_reexecution"] -and
    [string]$successorIncident["successor_gate_id"] -ceq "QSDK-R23D58" -and
    [int]$successorIncident["moved_binding_count"] -eq 2 -and
    [int]$successorIncident["physical_process_launch_count"] -eq 0 -and
    [int]$successorIncident["model_construction_count"] -eq 0 -and
    [int]$successorIncident["world_attempt_count"] -eq 0 -and
    [int]$successorIncident["world_build_count"] -eq 0 -and
    -not [bool]$successorIncident["r23d55_observed_result_changed"] -and
    -not [bool]$successorIncident["r23d55_threshold_changed"] -and
    -not [bool]$successorIncident["r23d55_selector_changed"] -and
    -not [bool]$successorIncident["r23d55_evaluator_changed"] -and
    -not [bool]$successorIncident["r23d55_interpretation_changed"] -and
    -not [bool]$successorIncident["physical_acceptance_authority"]
) "The R23D58 successor-source compatibility negative was lost or reinterpreted."

$observedCommitType = (& git -C $repoRoot cat-file -t $observedSourceCommit).Trim()
Assert-R23D55 ($LASTEXITCODE -eq 0 -and $observedCommitType -ceq "commit") (
    "Observed R23D55 source commit is unavailable."
)
$observedTree = (& git -C $repoRoot show -s --format=%T $observedSourceCommit).Trim()
Assert-R23D55 ($LASTEXITCODE -eq 0 -and $observedTree -ceq $observedSourceTree) (
    "Observed R23D55 source tree changed."
)

$parent = $contract["parent_boundary"]
Assert-R23D55 (
    [string]$parent["gate_id"] -ceq "QSDK-R23D54" -and
    [string]$parent["closure_raw_sha256"] -ceq
        "sha256:35f5d4d5a65486bdb86662cdda92428282a99bbf18de7563cde8a4018cff7217" -and
    [string]$parent["original_closure_audit_raw_sha256"] -ceq
        "sha256:d630be1a491987faa594ecae97ddb2c9083e7291eef98378afbd3a3d36406908" -and
    [string]$parent["closure_audit_raw_sha256"] -ceq
        "sha256:9037eac6d5b363a7c98bbc8b24f17a5e6634c164931e131a3947ae0dfb07e0e3" -and
    [bool]$parent["parent_identity_consumed"] -and
    -not [bool]$parent["parent_rerun_allowed"] -and
    -not [bool]$parent["parent_result_reinterpreted"] -and
    [string]$parent["observed_parent_failure_code"] -ceq
        "SDK_ACTUATOR_PHASE_APPLICATION_MISMATCH:front_left_hip_motor"
) "The immutable R23D54 parent boundary changed."

$auditIncident = $contract["historical_audit_compatibility_incident"]
Assert-R23D55 (
    [bool]$auditIncident["observed"] -and
    [string]$auditIncident["status"] -ceq
        "local_zero_world_audit_negative_current_successor_status_coupled_to_immutable_closure" -and
    [string]$auditIncident["failure_message"] -ceq
        "QSDK-R23D54 CLOSURE: release contract or support matrix closure boundary changed" -and
    -not [bool]$auditIncident["failure_reached_r23d54_evidence_reconstruction"] -and
    [string]$auditIncident["original_audit_raw_sha256"] -ceq
        "sha256:d630be1a491987faa594ecae97ddb2c9083e7291eef98378afbd3a3d36406908" -and
    [int]$auditIncident["physical_process_launch_count"] -eq 0 -and
    [int]$auditIncident["model_construction_count"] -eq 0 -and
    [int]$auditIncident["world_attempt_count"] -eq 0 -and
    [int]$auditIncident["world_build_count"] -eq 0 -and
    -not [bool]$auditIncident["r23d54_result_changed"] -and
    -not [bool]$auditIncident["physical_acceptance_authority"]
) "The observed successor-status audit negative was lost or reinterpreted."

$provenanceIncident = $contract["checkout_filter_provenance_incident"]
Assert-R23D55 (
    [bool]$provenanceIncident["observed"] -and
    [string]$provenanceIncident["status"] -ceq
        "local_zero_world_provenance_gate_negative_pre_physics" -and
    [string]$provenanceIncident["failed_gate_path"] -ceq
        "tests/test_closure_evidence_provenance_contract.ps1" -and
    [string]$provenanceIncident["failure_message"] -ceq
        "Checkout-filter migration moved without its distinct provenance boundary" -and
    [bool]$provenanceIncident["inventory_verification_passed_before_failure"] -and
    [int]$provenanceIncident["inventory_audit_count"] -eq 150 -and
    [int]$provenanceIncident["inventory_cas_path_check_signature_count"] -eq 71 -and
    [int]$provenanceIncident["inventory_pinned_git_blob_signature_count"] -eq 130 -and
    [int]$provenanceIncident["inventory_reconstructed_checkout_signature_count"] -eq 2 -and
    [int]$provenanceIncident["inventory_live_historical_identity_risk_count"] -eq 0 -and
    [int]$provenanceIncident["inventory_manual_review_required_count"] -eq 20 -and
    [int]$provenanceIncident["historical_tracked_file_renormalization_count"] -eq 0 -and
    [int]$provenanceIncident["new_uncommitted_source_lf_normalization_count"] -eq 2 -and
    [int]$provenanceIncident["physical_process_launch_count"] -eq 0 -and
    [int]$provenanceIncident["model_construction_count"] -eq 0 -and
    [int]$provenanceIncident["world_attempt_count"] -eq 0 -and
    [int]$provenanceIncident["world_build_count"] -eq 0 -and
    -not [bool]$provenanceIncident["r23d55_runtime_result_changed"] -and
    -not [bool]$provenanceIncident["physical_acceptance_authority"]
) "The observed checkout-filter provenance negative was lost or reinterpreted."

$question = $contract["development_question"]
Assert-R23D55 (
    [int]$question["physics_change_count"] -eq 0 -and
    [int]$question["controller_semantics_change_count"] -eq 0 -and
    [int]$question["outcome_threshold_change_count"] -eq 0 -and
    [int]$question["fixture_composition_change_count"] -eq 1 -and
    [int]$question["adapter_host_parameter_binding_change_count"] -eq 1 -and
    -not [bool]$question["physical_outcome_evaluated"] -and
    -not [bool]$question["turning_evaluator_invoked"] -and
    -not [bool]$question["superiority_evaluator_invoked"] -and
    -not [bool]$question["equivalence_or_non_inferiority_evaluator_invoked"]
) "The zero-world development question was broadened."

$implementation = $contract["implementation"]
Assert-R23D55 (
    [string]$implementation["policy_id"] -ceq
        "sporespore_godot_jolt_live_fixture_compiled_actuator_cap_binding_v1" -and
    [string]$implementation["fixture_composition_schema_version"] -ceq
        "sporespore_godot_jolt_fixture_joint_composition_v1" -and
    [bool]$implementation["same_fixture_hinge_pair_helper_used_by_zero_world_and_physical_paths"] -and
    [bool]$implementation["complete_surface_validated_before_first_cap_write"] -and
    [bool]$implementation["one_time_binding_required"] -and
    [bool]$implementation["every_cap_written_before_first_authoritative_controller_step"] -and
    [bool]$implementation["every_cap_read_back_after_write"] -and
    -not [bool]$implementation["binding_default_enabled_for_historical_campaigns"] -and
    [string]$implementation["opt_in_authority_scope"] -ceq "post_settle_full" -and
    [bool]$implementation["configured_parameter_readback_only"] -and
    -not [bool]$implementation["measured_motor_torque_available"] -and
    -not [bool]$implementation["measured_motor_impulse_available"]
) "The production binding boundary changed."

$sourcePolicy = $contract["source_binding_policy"]
$bindings = @($sourcePolicy["bindings"])
Assert-R23D55 (
    [string]$sourcePolicy["algorithm"] -ceq "sha256_exact_checkout_bytes" -and
    [int]$sourcePolicy["binding_count"] -eq 19 -and
    $bindings.Count -eq 19 -and
    [bool]$sourcePolicy["duplicate_paths_forbidden"] -and
    [bool]$sourcePolicy["all_declared_paths_required"] -and
    [bool]$sourcePolicy["fixture_proportion_and_inherited_development_contract_directly_bound"] -and
    [bool]$sourcePolicy["line_ending_policy_directly_bound"] -and
    [bool]$sourcePolicy["checkout_filter_provenance_dependencies_directly_bound"]
) "Source-binding policy changed."

$historicalBindings = @($historicalPolicy["bindings"])
$historicalPaths = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
$historicalByPath = @{}
foreach ($binding in $historicalBindings) {
    $relativePath = [string]$binding["path"]
    Assert-R23D55 ($historicalPaths.Add($relativePath)) (
        "Duplicate historical compatibility binding: $relativePath"
    )
    $historicalByPath[$relativePath] = $binding
}
$livePaths = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
foreach ($relativePath in @($livePolicy["paths"] | ForEach-Object { [string]$_ })) {
    Assert-R23D55 ($livePaths.Add($relativePath)) (
        "Duplicate live compatibility binding: $relativePath"
    )
    Assert-R23D55 (-not $historicalPaths.Contains($relativePath)) (
        "Historical/live compatibility partition overlaps: $relativePath"
    )
}
Assert-R23D55 (
    [string]$historicalPolicy["mode"] -ceq
        "sha256_exact_pinned_git_blob_bytes_at_observed_source_commit" -and
    [int]$historicalPolicy["binding_count"] -eq 7 -and
    $historicalBindings.Count -eq 7 -and
    -not [bool]$historicalPolicy["live_checkout_identity_required"] -and
    [string]$livePolicy["mode"] -ceq "sha256_exact_live_checkout_bytes" -and
    [int]$livePolicy["binding_count"] -eq 12 -and
    $livePaths.Count -eq 12 -and
    [bool]$compatPolicy["historical_digest_fields_remain_observed_values"] -and
    [bool]$compatPolicy["mutable_current_successor_fields_excluded_from_immutable_r23d55_assertion"] -and
    [bool]$compatPolicy["release_and_support_mirrors_required"] -and
    [bool]$compatPolicy["historical_git_blob_and_live_checkout_partition_must_be_complete_and_disjoint"] -and
    [bool]$compatPolicy["successor_modified_observed_production_paths_use_historical_git_bytes"] -and
    [bool]$compatPolicy["contract_source_binding_count_must_remain_19"]
) "Historical/live compatibility policy changed."

$seenPaths = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
foreach ($binding in $bindings) {
    $relativePath = [string]$binding["path"]
    $expectedHash = [string]$binding["raw_sha256"]
    Assert-R23D55 ($seenPaths.Add($relativePath)) "Duplicate source binding: $relativePath"
    Assert-R23D55 ($expectedHash -cmatch '^sha256:[0-9a-f]{64}$') (
        "Malformed source digest: $relativePath"
    )
    if ($historicalPaths.Contains($relativePath)) {
        $compatBinding = $historicalByPath[$relativePath]
        $observedBlobOid = (& git -C $repoRoot rev-parse "${observedSourceCommit}:$relativePath").Trim()
        Assert-R23D55 ($LASTEXITCODE -eq 0) (
            "Unable to resolve historical Git blob: $relativePath"
        )
        Assert-R23D55 (
            $observedBlobOid -ceq [string]$compatBinding["git_blob_oid"] -and
            $expectedHash -ceq [string]$compatBinding["raw_sha256"] -and
            (Get-R23D55GitBlobRawSha256 -Commit $observedSourceCommit -Path $relativePath) -ceq
                $expectedHash
        ) "Historical Git binding drifted: $relativePath"
    } else {
        Assert-R23D55 ($livePaths.Contains($relativePath)) (
            "Source binding is outside compatibility partition: $relativePath"
        )
        $fullPath = Join-Path $repoRoot $relativePath
        Assert-R23D55 (Test-Path -LiteralPath $fullPath -PathType Leaf) (
            "Bound source is missing: $relativePath"
        )
        Assert-R23D55 ((Get-R23D55RawSha256 $fullPath) -ceq $expectedHash) (
            "Bound live source drifted: $relativePath"
        )
    }
}
Assert-R23D55 (
    $seenPaths.Count -eq ($historicalPaths.Count + $livePaths.Count)
) "Historical/live compatibility partition is incomplete."
foreach ($requiredPath in @(
    ".gitattributes",
    "sdk/closure_evidence_provenance_contract.json",
    "tests/test_closure_evidence_provenance_contract.ps1",
    "sdk/closure_evidence_mode_inventory.json",
    "sdk/audit_closure_evidence_modes.ps1",
    "scripts/lab/gait/physical_quadruped_fixture_spec.gd",
    "scripts/lab/gait/physical_quadruped_proportion_spec.gd",
    "sdk/turning/r23d2_development_contract_v1.json",
    "scripts/lab/gait/sdk_godot_jolt_live_fixture_actuator_cap_binding.gd",
    "scripts/lab/gait/physical_wave_gait_quadruped.gd",
    "tests/test_sdk_qsdk_r23d55_godot_live_fixture_actuator_cap_conformance.gd"
)) {
    Assert-R23D55 ($seenPaths.Contains($requiredPath)) "Direct dependency omitted: $requiredPath"
}

$adequacy = $contract["numeric_threshold_provenance_and_adequacy"]
Assert-R23D55 (
    [double]$adequacy["readback_tolerance_nms"] -eq 2.5e-7 -and
    [double]$adequacy["maximum_policy_accepted_tolerance_nms"] -eq 1.0e-6 -and
    -not [bool]$adequacy["tolerance_fitted_from_r23d54_outcome"] -and
    -not [bool]$adequacy["tolerance_fitted_from_r23d55_observation"] -and
    [int]$adequacy["threshold_change_count"] -eq 0 -and
    -not [bool]$adequacy["margin_declared"]
) "Threshold provenance or adequacy boundary changed."

$cohort = $contract["finite_cohort_and_population_boundary"]
Assert-R23D55 (
    [string]$cohort["morphology_id"] -ceq "qsdk_r05_generated_s169" -and
    [int]$cohort["morphology_count"] -eq 1 -and
    [int]$cohort["fixture_route_count"] -eq 1 -and
    [int]$cohort["engine_count"] -eq 1 -and
    [string]$cohort["engine_id"] -ceq "godot_jolt" -and
    [int]$cohort["expected_limb_count"] -eq 4 -and
    [int]$cohort["expected_actuator_count"] -eq 8 -and
    [int]$cohort["expected_unique_host_joint_object_count"] -eq 8 -and
    -not [bool]$cohort["population_sampling_performed"] -and
    -not [bool]$cohort["held_out_validation_performed"]
) "Finite cohort or population boundary changed."

$result = $contract["observed_local_zero_world_result"]
Assert-R23D55 (
    [string]$result["runtime_api_version"] -ceq "4.7-stable (official)" -and
    [int]$result["validated_limb_count"] -eq 4 -and
    [int]$result["validated_actuator_count"] -eq 8 -and
    [int]$result["unique_host_joint_object_count"] -eq 8 -and
    [int]$result["prebinding_mismatch_count"] -eq 8 -and
    [int]$result["write_count"] -eq 8 -and
    [int]$result["readback_count"] -eq 8 -and
    [double]$result["maximum_postbinding_readback_error_nms"] -le 2.5e-7 -and
    [int]$result["mutation_rejection_count"] -eq 14 -and
    [int]$result["scene_tree_insertion_count"] -eq 0 -and
    [int]$result["model_construction_count"] -eq 0 -and
    [int]$result["world_attempt_count"] -eq 0 -and
    [int]$result["world_build_count"] -eq 0 -and
    -not [bool]$result["physics_state_modified"] -and
    -not [bool]$result["physical_acceptance_authority"]
) "Observed local zero-world result changed."

Assert-R23D55 (
    [int]$compatZeroWorld["physical_process_launch_count"] -eq 0 -and
    [int]$compatZeroWorld["model_construction_count"] -eq 0 -and
    [int]$compatZeroWorld["world_attempt_count"] -eq 0 -and
    [int]$compatZeroWorld["world_build_count"] -eq 0 -and
    -not [bool]$compatZeroWorld["physics_state_modified"]
) "Audit compatibility maintenance exceeded its zero-world boundary."
foreach ($claim in $compatClaims.Keys) {
    Assert-R23D55 (-not [bool]$compatClaims[$claim]) (
        "Audit compatibility false claim became true: $claim"
    )
}

$requiredControls = @(
    "missing_joint_rejected_without_write",
    "extra_joint_rejected_without_write",
    "swapped_joint_rejected_without_write",
    "duplicate_host_object_rejected_without_write",
    "detached_preconfigured_only_rejected",
    "nonfinite_compiled_cap_rejected_without_write",
    "zero_compiled_cap_rejected_without_write",
    "wrong_policy_rejected_without_write",
    "excessive_tolerance_rejected_without_write",
    "wrong_fixture_marker_rejected_without_write",
    "wrong_host_name_rejected_without_write",
    "omitted_write_readback_rejected",
    "wrong_scale_readback_rejected",
    "duplicate_binding_rejected"
)
$observedControls = @($contract["required_negative_controls"] | ForEach-Object { [string]$_ })
Assert-R23D55 (
    [string]::Join('|', $observedControls) -ceq [string]::Join('|', $requiredControls)
) "Required negative controls changed."

$claims = $contract["claims"]
Assert-R23D55 (
    [bool]$claims["implementation_complete"] -and
    [bool]$claims["local_zero_world_source_and_runtime_conformance_passed"]
) "Implemented zero-world claim disappeared."
foreach ($falseClaim in @(
    "complete_dependency_key_for_result_reuse",
    "canonical_full_conformance_recommissioned_for_current_source",
    "fresh_scoped_physical_qualification_passed",
    "physical_successor_opened",
    "physical_world_opened",
    "actuator_phase_characterization_complete",
    "godot_jolt_turning_validation",
    "finite_three_engine_turning",
    "portable_basic_turning",
    "cross_engine_equivalence",
    "population_robustness",
    "arbitrary_morphology_support",
    "prone_to_standing",
    "q_sdk_r23_satisfied",
    "physical_acceptance_authority",
    "release_authority"
)) {
    Assert-R23D55 (-not [bool]$claims[$falseClaim]) "False claim became true: $falseClaim"
}

$binderSource = Get-Content -LiteralPath (
    Join-Path $repoRoot ([string]$implementation["production_binder_path"])
) -Raw
$physicalSource = Get-Content -LiteralPath (
    Join-Path $repoRoot ([string]$implementation["production_fixture_and_authority_path"])
) -Raw
$runtimeTestSource = Get-Content -LiteralPath (
    Join-Path $repoRoot ([string]$implementation["runtime_test_path"])
) -Raw
$runnerSource = Get-Content -LiteralPath $runnerPath -Raw

foreach ($token in @(
    "bind_compiled_actuator_caps",
    "validate_bound_actuator_caps",
    "PARAM_MOTOR_MAX_IMPULSE",
    "LIVE_FIXTURE_CAP_BINDING_ALREADY_COMPLETED",
    "LIVE_FIXTURE_CAP_BINDING_READBACK_MISMATCH",
    "sporespore_fixture_joint_composition_schema_version"
)) {
    Assert-R23D55 ($binderSource.Contains($token)) "Binder source is missing: $token"
}
foreach ($token in @(
    "compose_sdk_live_fixture_actuator_cap_binding_surface",
    "_compose_fixture_hinge_pair",
    "live_fixture_actuator_cap_binding_policy_id",
    "sdk_live_fixture_actuator_cap_binding_receipt",
    "bind_compiled_actuator_caps"
)) {
    Assert-R23D55 ($physicalSource.Contains($token)) "Physical integration is missing: $token"
}
foreach ($token in $requiredControls) {
    Assert-R23D55 ($runtimeTestSource.Contains($token)) "Runtime gate is missing control: $token"
}
foreach ($entrypoint in @(
    "test_qsdk_r23d55_live_fixture_actuator_cap_contract.ps1",
    "test_sdk_qsdk_r23d55_godot_live_fixture_actuator_cap_conformance.gd"
)) {
    Assert-R23D55 (
        ([regex]::Matches($runnerSource, [regex]::Escape($entrypoint))).Count -eq 1
    ) "Canonical runner must invoke exactly one R23D55 entrypoint: $entrypoint"
}

$releaseParents = @(Find-R23D55ObjectsWithKey -Value $release -Key $blockKey)
$supportParents = @(Find-R23D55ObjectsWithKey -Value $support -Key $blockKey)
Assert-R23D55 ($releaseParents.Count -eq 1) "Release ledger must expose exactly one R23D55 block."
Assert-R23D55 ($supportParents.Count -eq 1) "Support ledger must expose exactly one R23D55 block."
$releaseBlock = $releaseParents[0][$blockKey]
$supportBlock = $supportParents[0][$blockKey]

$mirroredKeys = @(
    "gate_id",
    "work_id",
    "status",
    "question_class",
    "audit_compatibility_contract_path",
    "audit_compatibility_contract_raw_sha256",
    "audit_compatibility_status",
    "mutable_current_successor_fields_excluded_from_immutable_audit",
    "observed_source_commit",
    "observed_source_tree",
    "historical_git_blob_binding_count",
    "live_checkout_binding_count",
    "r23d58_successor_compatibility_incident_retained",
    "successor_modified_historical_production_binding_count",
    "line_ending_policy_path",
    "line_ending_policy_raw_sha256",
    "checkout_filter_provenance_contract_path",
    "checkout_filter_provenance_contract_raw_sha256",
    "checkout_filter_provenance_audit_path",
    "checkout_filter_provenance_audit_raw_sha256",
    "closure_evidence_inventory_path",
    "closure_evidence_inventory_raw_sha256",
    "closure_evidence_analyzer_path",
    "closure_evidence_analyzer_raw_sha256",
    "contract_path",
    "contract_raw_sha256",
    "audit_path",
    "audit_raw_sha256",
    "runtime_test_path",
    "runtime_test_raw_sha256",
    "binder_path",
    "binder_raw_sha256",
    "physical_fixture_path",
    "physical_fixture_raw_sha256",
    "adapter_path",
    "adapter_raw_sha256",
    "fixture_compiler_path",
    "fixture_compiler_raw_sha256",
    "proportion_compiler_path",
    "proportion_compiler_raw_sha256",
    "inherited_development_contract_path",
    "inherited_development_contract_raw_sha256",
    "canonical_runner_path",
    "canonical_runner_raw_sha256",
    "parent_closure_path",
    "parent_closure_raw_sha256",
    "policy_id",
    "fixture_composition_schema_version",
    "runtime_api_version",
    "source_binding_count",
    "checkout_filter_provenance_initial_failure_retained",
    "checkout_filter_provenance_repair_zero_world_passed",
    "checkout_filter_migration_executed",
    "historical_tracked_file_renormalization_count",
    "new_uncommitted_source_lf_normalization_count",
    "closure_evidence_inventory_audit_count",
    "validated_limb_count",
    "validated_actuator_count",
    "unique_host_joint_object_count",
    "prebinding_mismatch_count",
    "write_count",
    "readback_count",
    "readback_tolerance_nms",
    "maximum_postbinding_readback_error_nms",
    "mutation_rejection_count",
    "scene_tree_insertion_count",
    "model_construction_count",
    "world_attempt_count",
    "world_build_count",
    "configured_parameter_readback_only",
    "measured_motor_torque_available",
    "measured_motor_impulse_available",
    "canonical_full_conformance_recommissioned_for_current_source",
    "physical_successor_opened",
    "turning_acceptance",
    "prone_to_standing",
    "physical_acceptance_authority",
    "release_authority"
)
foreach ($key in $mirroredKeys) {
    Assert-R23D55 ($releaseBlock.Contains($key)) "Release R23D55 block is missing $key."
    Assert-R23D55 ($supportBlock.Contains($key)) "Support R23D55 block is missing $key."
    Assert-R23D55 (
        [string]$releaseBlock[$key] -ceq [string]$supportBlock[$key]
    ) "Release/support R23D55 values differ for $key."
}

foreach ($bindingPair in @(
    @("audit_compatibility_contract_path", "audit_compatibility_contract_raw_sha256"),
    @("line_ending_policy_path", "line_ending_policy_raw_sha256"),
    @("checkout_filter_provenance_contract_path", "checkout_filter_provenance_contract_raw_sha256"),
    @("checkout_filter_provenance_audit_path", "checkout_filter_provenance_audit_raw_sha256"),
    @("closure_evidence_inventory_path", "closure_evidence_inventory_raw_sha256"),
    @("closure_evidence_analyzer_path", "closure_evidence_analyzer_raw_sha256"),
    @("contract_path", "contract_raw_sha256"),
    @("audit_path", "audit_raw_sha256"),
    @("runtime_test_path", "runtime_test_raw_sha256"),
    @("binder_path", "binder_raw_sha256"),
    @("physical_fixture_path", "physical_fixture_raw_sha256"),
    @("adapter_path", "adapter_raw_sha256"),
    @("fixture_compiler_path", "fixture_compiler_raw_sha256"),
    @("proportion_compiler_path", "proportion_compiler_raw_sha256"),
    @("inherited_development_contract_path", "inherited_development_contract_raw_sha256"),
    @("canonical_runner_path", "canonical_runner_raw_sha256"),
    @("parent_closure_path", "parent_closure_raw_sha256")
)) {
    $relativePath = [string]$releaseBlock[$bindingPair[0]]
    if ($historicalPaths.Contains($relativePath)) {
        Assert-R23D55 (
            (Get-R23D55GitBlobRawSha256 -Commit $observedSourceCommit -Path $relativePath) -ceq
                [string]$releaseBlock[$bindingPair[1]]
        ) "Mirrored historical digest drifted: $relativePath"
    } else {
        $boundPath = Join-Path $repoRoot $relativePath
        Assert-R23D55 (Test-Path -LiteralPath $boundPath -PathType Leaf) (
            "Mirrored path is missing: $boundPath"
        )
        Assert-R23D55 (
            (Get-R23D55RawSha256 $boundPath) -ceq [string]$releaseBlock[$bindingPair[1]]
        ) "Mirrored live digest drifted: $boundPath"
    }
}

Assert-R23D55 (
    [string]$releaseBlock["gate_id"] -ceq "QSDK-R23D55" -and
    [string]$releaseBlock["status"] -ceq
        "implemented_local_zero_world_conformance_passed_physical_successor_not_opened" -and
    [string]$releaseBlock["question_class"] -ceq "development" -and
    [string]$releaseBlock["audit_compatibility_status"] -ceq
        "implemented_zero_world_historical_and_live_binding_split_extended_for_r23d58_successor" -and
    [bool]$releaseBlock["mutable_current_successor_fields_excluded_from_immutable_audit"] -and
    [string]$releaseBlock["observed_source_commit"] -ceq $observedSourceCommit -and
    [string]$releaseBlock["observed_source_tree"] -ceq $observedSourceTree -and
    [int]$releaseBlock["historical_git_blob_binding_count"] -eq 7 -and
    [int]$releaseBlock["live_checkout_binding_count"] -eq 12 -and
    [bool]$releaseBlock["r23d58_successor_compatibility_incident_retained"] -and
    [int]$releaseBlock["successor_modified_historical_production_binding_count"] -eq 2 -and
    [int]$releaseBlock["source_binding_count"] -eq 19 -and
    [bool]$releaseBlock["checkout_filter_provenance_initial_failure_retained"] -and
    [bool]$releaseBlock["checkout_filter_provenance_repair_zero_world_passed"] -and
    -not [bool]$releaseBlock["checkout_filter_migration_executed"] -and
    [int]$releaseBlock["historical_tracked_file_renormalization_count"] -eq 0 -and
    [int]$releaseBlock["new_uncommitted_source_lf_normalization_count"] -eq 2 -and
    [int]$releaseBlock["closure_evidence_inventory_audit_count"] -eq 150 -and
    [int]$releaseBlock["mutation_rejection_count"] -eq 14 -and
    [int]$releaseBlock["world_build_count"] -eq 0 -and
    [bool]$releaseBlock["configured_parameter_readback_only"] -and
    -not [bool]$releaseBlock["measured_motor_torque_available"] -and
    -not [bool]$releaseBlock["measured_motor_impulse_available"] -and
    -not [bool]$releaseBlock["canonical_full_conformance_recommissioned_for_current_source"] -and
    -not [bool]$releaseBlock["physical_successor_opened"] -and
    -not [bool]$releaseBlock["turning_acceptance"] -and
    -not [bool]$releaseBlock["prone_to_standing"] -and
    -not [bool]$releaseBlock["physical_acceptance_authority"] -and
    -not [bool]$releaseBlock["release_authority"]
) "R23D55 ledger claims were broadened."

$contractHash = Get-R23D55RawSha256 $contractPath
$compatibilityHash = Get-R23D55RawSha256 $compatibilityPath
Write-Host (
    "QSDK_R23D55_LIVE_FIXTURE_ACTUATOR_CAP_CONTRACT_PASS " +
    "question=development bindings=19 historical_git=7 live=12 successor_moved=2 actuators=8 limbs=4 writes=8 readbacks=8 " +
    "mutations=14 models=0 worlds=0 turning=False prone=False physical=False " +
    "contract_sha256=$contractHash compatibility_sha256=$compatibilityHash"
)
