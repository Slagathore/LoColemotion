#requires -Version 7.0

[CmdletBinding()]
param(
    [string]$Python = "python",
    [string]$Godot = (
        "C:\Users\Cole\CodeStuff\Misc\Godot\" +
        "Godot_v4.7-stable_mono_win64_console.exe"
    )
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$turningRoot = Join-Path $repoRoot "sdk\turning"
$preregistrationPath = Join-Path $turningRoot (
    "r23d57_godot_full_precision_trace_actuator_phase_characterization_preregistration_v1.json"
)
$implementationPath = Join-Path $turningRoot (
    "r23d57_godot_full_precision_trace_actuator_phase_characterization_implementation_v1.json"
)
$manifestPath = Join-Path $turningRoot "r23d57_campaign_attestation_manifest_v1.json"
$transportValidatorPath = Join-Path $turningRoot (
    "r23d57_godot_full_precision_trace_transport.py"
)
$releasePath = Join-Path $repoRoot "sdk\release\quadruped_release_contract.json"
$supportPath = Join-Path $repoRoot "sdk\release\quadruped_support_matrix.json"
$closurePath = Join-Path $turningRoot (
    "r23d57_godot_full_precision_trace_actuator_phase_characterization_closure_v1.json"
)
$closureAuditPath = Join-Path $repoRoot "tests\test_qsdk_r23d57_physical_closure.ps1"
$campaignId = (
    "QSDK-R23D57-GODOT-FULL-PRECISION-TRACE-ACTUATOR-PHASE-CHARACTERIZATION-DEVELOPMENT"
)
$policyId = "sporespore_godot_jolt_live_fixture_compiled_actuator_cap_binding_v1"

function Assert-R23D57Lineage([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "QSDK-R23D57 LINEAGE: $Message" }
}

function Get-R23D57RawSha256([string]$Path) {
    return "sha256:" + (
        Get-FileHash -LiteralPath $Path -Algorithm SHA256
    ).Hash.ToLowerInvariant()
}

function Get-R23D57Json([string]$Path) {
    Assert-R23D57Lineage (Test-Path -LiteralPath $Path -PathType Leaf) (
        "required JSON is missing: $Path"
    )
    return Get-Content -Raw -LiteralPath $Path |
        ConvertFrom-Json -AsHashtable -Depth 100
}

function Find-R23D57Container([object]$Value, [string]$PropertyName) {
    $matches = [Collections.Generic.List[object]]::new()
    function Visit-R23D57([object]$Current) {
        if ($Current -is [Collections.IDictionary]) {
            if ($Current.Contains($PropertyName)) { $matches.Add($Current) }
            foreach ($entry in $Current.GetEnumerator()) { Visit-R23D57 $entry.Value }
        } elseif ($Current -is [Collections.IEnumerable] -and
            $Current -isnot [string]) {
            foreach ($item in $Current) { Visit-R23D57 $item }
        }
    }
    Visit-R23D57 $Value
    return @($matches)
}

$actualRoot = (& git -C $repoRoot rev-parse --show-toplevel).Trim()
Assert-R23D57Lineage ($LASTEXITCODE -eq 0) "repository root cannot be resolved"
$actualRemote = (& git -C $repoRoot remote get-url origin).Trim()
Assert-R23D57Lineage ($LASTEXITCODE -eq 0) "origin cannot be resolved"
Assert-R23D57Lineage (
    [IO.Path]::GetFullPath($actualRoot) -ceq $repoRoot -and
    $actualRemote -ceq "https://github.com/Slagathore/sporespore.git"
) "repository identity changed"

Assert-R23D57Lineage (Test-Path -LiteralPath $Godot -PathType Leaf) (
    "Godot 4.7 runtime is missing: $Godot"
)
$transportOutput = @(
    & $Python -B $transportValidatorPath --godot $Godot `
        --source-root $repoRoot 2>&1
)
Assert-R23D57Lineage ($LASTEXITCODE -eq 0) ($transportOutput -join "`n")
$transportMarkerPrefix = "QSDK_R23D57_FULL_PRECISION_TRACE_TRANSPORT_PASS "
$transportMarkers = @($transportOutput | Where-Object {
    ([string]$_).StartsWith($transportMarkerPrefix, [StringComparison]::Ordinal)
})
Assert-R23D57Lineage ($transportMarkers.Count -eq 1) ($transportOutput -join "`n")
$transportReceipt = ([string]$transportMarkers[0]).Substring(
    $transportMarkerPrefix.Length
) | ConvertFrom-Json -AsHashtable -Depth 100
Assert-R23D57Lineage (
    [int]$transportReceipt["fixture_count"] -eq 35 -and
    [int]$transportReceipt["default_target_consistency_failure_count"] -eq 14 -and
    [int]$transportReceipt["default_impulse_consistency_failure_count"] -eq 0 -and
    [int]$transportReceipt["full_precision_target_consistency_failure_count"] -eq 0 -and
    [int]$transportReceipt["full_precision_impulse_consistency_failure_count"] -eq 0 -and
    [int]$transportReceipt["full_precision_binary64_roundtrip_mismatch_count"] -eq 0 -and
    [int]$transportReceipt["mutation_rejection_count"] -eq 12 -and
    [int]$transportReceipt["boundary_control_count"] -eq 2 -and
    [int]$transportReceipt["model_construction_count"] -eq 0 -and
    [int]$transportReceipt["world_attempt_count"] -eq 0 -and
    [int]$transportReceipt["world_build_count"] -eq 0 -and
    -not [bool]$transportReceipt["physical_acceptance_authority"]
) "live R23D57 full-precision transport replay changed"

$preregistration = Get-R23D57Json $preregistrationPath
$implementation = Get-R23D57Json $implementationPath
$release = Get-R23D57Json $releasePath
$support = Get-R23D57Json $supportPath
$lineage = $preregistration["immutable_lineage"]
$successor = $preregistration["scientifically_distinct_successor"]
$matrix = $preregistration["frozen_matrix"]
$observation = $preregistration["required_observation"]
$capBinding = $preregistration["required_live_fixture_cap_binding"]
$traceTransport = $preregistration["required_trace_transport"]
$characterization = $preregistration["predeclared_characterization"]
$adequacy = $preregistration["adequacy"]
$preregClaims = $preregistration["claims"]
$development = $implementation["development_boundary"]
$sourcePolicy = $implementation["source_binding_policy"]
$implementationClaims = $implementation["claims"]

Assert-R23D57Lineage (
    [string]$preregistration["schema_version"] -ceq
        "sporespore_qsdk_r23d57_godot_full_precision_trace_actuator_phase_characterization_preregistration_v1" -and
    [string]$implementation["schema_version"] -ceq
        "sporespore_qsdk_r23d57_godot_full_precision_trace_actuator_phase_characterization_implementation_v1" -and
    [string]$preregistration["status"] -ceq "prospective_zero_world_only" -and
    [string]$implementation["status"] -ceq "prospective_zero_world_only" -and
    [string]$preregistration["campaign_id"] -ceq $campaignId -and
    [string]$implementation["campaign_id"] -ceq $campaignId -and
    [string]$preregistration["question_class"] -ceq "development" -and
    [string]$implementation["question_class"] -ceq "development" -and
    [bool]$preregistration["physical_question_declared"] -and
    [bool]$implementation["physical_question_declared"] -and
    -not [bool]$preregistration["physical_campaign_opened"] -and
    -not [bool]$implementation["physical_campaign_opened"]
) "prospective development identity changed"

Assert-R23D57Lineage (
    [string]$lineage["development_parent_commit"] -ceq
        "7fbc2bf7e6194a8f7f98e42a157d9451bca3d53d" -and
    [string]$lineage["r23d56_closure_raw_sha256"] -ceq
        (Get-R23D57RawSha256 (Join-Path $turningRoot (
            "r23d56_godot_valid_route_actuator_phase_characterization_closure_v1.json"
        ))) -and
    [string]$lineage["r23d56_status"] -ceq
        "closed_consumed_invalid_complete_outcome_exposed_godot_valid_route_actuator_phase_characterization_development" -and
    [bool]$lineage["r23d56_identity_consumed"] -and
    -not [bool]$lineage["r23d56_same_identity_rerun_permitted"] -and
    -not [bool]$lineage["r23d56_result_reinterpreted"] -and
    -not [bool]$lineage["r23d56_world_reused_as_r23d57_cell"] -and
    -not [bool]$lineage["r23d56_trace_or_terminal_promoted_to_r23d57_evidence"] -and
    [int]$lineage["r23d56_observed_world_count"] -eq 3 -and
    [int]$lineage["r23d56_diagnostic_complete_raw_trace_row_count"] -eq 8976 -and
    [int]$lineage["r23d56_valid_trace_row_count"] -eq 0 -and
    [int]$lineage["r23d56_target_report_consistency_over_1e_15_count"] -eq
        2203 -and
    [string]$lineage["r23d57_transport_contract_raw_sha256"] -ceq
        "sha256:857364bb62aa667cd0ee152cd3c241996a462922181f9d675d6fe9d7a6f3fedd" -and
    [string]$lineage["r23d57_transport_closure_raw_sha256"] -ceq
        "sha256:92e903daa814e8ec243a75a9a7f33be4a4565cd9afab804e420d591a03b00b62" -and
    [string]$lineage["r23d57_transport_initial_closure_audit_boundary_commit"] -ceq
        "7fbc2bf7e6194a8f7f98e42a157d9451bca3d53d" -and
    [string]$lineage["r23d57_transport_closure_audit_raw_sha256"] -ceq
        "sha256:0e4523146cbe5ae78049ef36a1f291a9a59bbaa0b15eb9cfcca7a709eb4f4fb9" -and
    [string]$lineage["r23d57_transport_live_compatibility_audit_raw_sha256"] -ceq
        "sha256:e13a175cc5e5e3a9e3acd8bade96f223d7b5f16b8e71e2e001af481b30aba64f" -and
    [string]$lineage["r23d57_transport_closure_audit_role"] -ceq
        "live_compatibility_audit_pinning_immutable_initial_closure_audit" -and
    [bool]$lineage["r23d57_zero_world_transport_gate_passed"] -and
    [int]$lineage["r23d57_transport_physical_world_count"] -eq 0 -and
    [string]$lineage["r23d54_closure_raw_sha256"] -ceq
        "sha256:35f5d4d5a65486bdb86662cdda92428282a99bbf18de7563cde8a4018cff7217" -and
    [string]$lineage["r23d54_result"] -ceq
        "invalid_complete_outcome_exposed_godot_actuator_phase_characterization_development" -and
    [string]$lineage["r23d54_observed_failure_code"] -ceq
        "SDK_ACTUATOR_PHASE_APPLICATION_MISMATCH:front_left_hip_motor" -and
    [int]$lineage["r23d54_valid_observation_row_count"] -eq 0 -and
    -not [bool]$lineage["r23d54_same_identity_rerun_permitted"] -and
    -not [bool]$lineage["r23d54_result_reinterpreted"] -and
    [string]$lineage["r23d55_contract_raw_sha256"] -ceq
        "sha256:07dde7aafb3cefdd31bf4fa52f2abb231f6783a1d270361776a63041d3583838" -and
    [string]$lineage["r23d55_audit_compatibility_raw_sha256"] -ceq
        "sha256:3564fd65cd9191f583bfc2b759f4b8a2935f9a47ad4e34a894d851540e1bcde8" -and
    [bool]$lineage["r23d55_zero_world_result_passed"] -and
    [int]$lineage["r23d55_physical_world_count"] -eq 0 -and
    [string]$lineage["lca1_rc7_closure_raw_sha256"] -ceq
        "sha256:cd809da2a18508e923c1b7809d2d93b8c3a257ff246cd0e91014317bade549b5"
) "immutable R56, R57 transport, R54, R55, or RC7 lineage changed"

Assert-R23D57Lineage (
    [string]$successor["comparator_campaign_id"] -ceq
        "QSDK-R23D56-GODOT-VALID-ROUTE-ACTUATOR-PHASE-CHARACTERIZATION-DEVELOPMENT" -and
    [int]$successor["declared_physics_model_change_count"] -eq 0 -and
    [int]$successor["declared_controller_change_count"] -eq 0 -and
    [int]$successor["declared_measurement_change_count"] -eq 0 -and
    [int]$successor["declared_live_host_parameter_binding_change_count"] -eq 0 -and
    [int]$successor["declared_evidence_transport_change_count"] -eq 1 -and
    [bool]$successor["same_live_fixture_cap_route_as_r23d56"] -and
    [bool]$successor["same_actuator_phase_observation_as_r23d56"] -and
    -not [bool]$successor["historical_world_reused_as_r23d57_cell"] -and
    -not [bool]$successor["r23d56_terminal_or_trace_reused_as_r23d57_cell"] -and
    -not [bool]$successor["threshold_changed"] -and
    -not [bool]$successor["fresh_held_out_condition_consumed"]
) "scientifically distinct successor boundary changed"

Assert-R23D57Lineage (
    [int]$matrix["declared_cell_count"] -eq 3 -and
    [int]$matrix["declared_world_count"] -eq 3 -and
    [int]$matrix["seed"] -eq 21512 -and
    [int]$matrix["controller_step_count"] -eq 2992 -and
    (@($matrix["ordered_arm_ids"]) -join ",") -ceq
        "reference_zero,positive_heading,negative_heading" -and
    (@($matrix["ordered_heading_offsets_rad"]) -join ",") -ceq "0,0.2,-0.2" -and
    [int]$observation["required_total_trace_row_count"] -eq 8976 -and
    [int]$observation["required_total_application_count"] -eq 71808 -and
    [string]$capBinding["policy_id"] -ceq $policyId -and
    [int]$capBinding["expected_actuator_count"] -eq 8 -and
    [int]$capBinding["exact_write_count"] -eq 8 -and
    [int]$capBinding["exact_readback_count"] -eq 8 -and
    [double]$capBinding["maximum_readback_error_nms"] -eq 2.5e-7 -and
    [string]$traceTransport["transport_id"] -ceq
        "godot_4_7_json_stringify_full_precision_binary64_v1" -and
    [string]$traceTransport["godot_runtime_version"] -ceq
        "4.7-stable (official)" -and
    [string]$traceTransport["selected_godot_invocation"] -ceq
        'JSON.stringify(rows, "", true, true)' -and
    [bool]$traceTransport["sorted_keys_required"] -and
    [bool]$traceTransport["full_precision_required"] -and
    [double]$traceTransport["reported_error_recomputation_consistency_tolerance"] -eq
        1.0e-15 -and
    [int]$traceTransport["transport_gate_fixture_count"] -eq 35 -and
    [int]$traceTransport["transport_gate_default_target_failure_count"] -eq 14 -and
    [int]$traceTransport["transport_gate_full_precision_target_failure_count"] -eq 0 -and
    [int]$traceTransport["transport_gate_full_precision_impulse_failure_count"] -eq 0 -and
    [int]$traceTransport["transport_gate_binary64_mismatch_count"] -eq 0 -and
    [int]$traceTransport["transport_gate_mutation_rejection_count"] -eq 12 -and
    [int]$traceTransport["transport_closure_mutation_rejection_count"] -eq 19 -and
    -not [bool]$characterization["turning_gate_invoked"] -and
    [int]$characterization["mechanism_selection_rule_count"] -eq 0 -and
    -not [bool]$adequacy["turning_acceptance_attempted"] -and
    -not [bool]$adequacy["fresh_held_out_validation_attempted"]
) "finite matrix, observation, cap-binding, or adequacy boundary changed"

$exactPaths = @($sourcePolicy["exact_paths"] | ForEach-Object { [string]$_ })
$uniquePaths = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
foreach ($relativePath in $exactPaths) {
    Assert-R23D57Lineage ($uniquePaths.Add($relativePath)) (
        "duplicate exact source path: $relativePath"
    )
    Assert-R23D57Lineage (
        Test-Path -LiteralPath (Join-Path $repoRoot $relativePath) -PathType Leaf
    ) "missing exact source path: $relativePath"
}
foreach ($requiredPath in @(
    ".gitattributes",
    "sdk/closure_evidence_provenance_contract.json",
    "sdk/release/quadruped_release_contract.json",
    "sdk/release/quadruped_support_matrix.json",
    "sdk/workbench/experiment_catalog.json",
    "sdk/turning/r23d56_godot_valid_route_actuator_phase_characterization_closure_v1.json",
    "sdk/turning/r23d56_godot_valid_route_actuator_phase_characterization_preregistration_v1.json",
    "sdk/turning/r23d56_godot_valid_route_actuator_phase_characterization_implementation_v1.json",
    "sdk/turning/r23d56_godot_valid_route_actuator_phase_characterization_evaluator.py",
    "tests/test_sdk_qsdk_r23d56_godot_jolt_physical_worker.gd",
    "sdk/run_qsdk_r23d56_supervisor.ps1",
    "sdk/turning/r23d57_godot_full_precision_trace_transport_contract_v1.json",
    "sdk/turning/r23d57_godot_full_precision_trace_transport.py",
    "sdk/turning/r23d57_godot_full_precision_trace_transport_closure_v1.json",
    "tests/test_sdk_qsdk_r23d57_godot_full_precision_trace_transport.gd",
    "tests/test_qsdk_r23d57_godot_full_precision_trace_transport.ps1",
    "tests/test_qsdk_r23d57_godot_full_precision_trace_transport_closure.ps1",
    "sdk/turning/r23d54_godot_actuator_phase_characterization_closure_v1.json",
    "sdk/turning/r23d55_godot_live_fixture_actuator_cap_conformance_v1.json",
    "sdk/turning/r23d55_post_rc7_audit_compatibility_v1.json",
    "sdk/locomotion_campaign_attestation_v1_recommissioning_rc7_closure.json",
    "sdk/trace_analysis/godot_actuator_phase_observation_contract_v1.json",
    "sdk/turning/r23d57_godot_full_precision_trace_actuator_phase_characterization_preregistration_v1.json",
    "sdk/turning/r23d57_godot_full_precision_trace_actuator_phase_characterization_implementation_v1.json",
    "sdk/turning/r23d57_godot_full_precision_trace_actuator_phase_characterization.py",
    "sdk/turning/r23d57_godot_full_precision_trace_actuator_phase_characterization_evaluator.py",
    "tests/test_sdk_qsdk_r23d57_godot_jolt_physical_worker.gd",
    "tests/test_qsdk_r23d57_lineage.ps1",
    "tests/test_qsdk_r23d57_campaign_roles.ps1",
    "sdk/run_qsdk_r23d57_supervisor.ps1",
    "sdk/turning/r23d57_campaign_attestation_manifest_v1.json"
)) {
    Assert-R23D57Lineage ($uniquePaths.Contains($requiredPath)) (
        "required exact source dependency omitted: $requiredPath"
    )
}
Assert-R23D57Lineage (
    @($sourcePolicy["tracked_prefixes"]).Count -eq 2 -and
    [bool]$sourcePolicy["duplicate_paths_forbidden"] -and
    [bool]$sourcePolicy["empty_prefix_expansion_forbidden"] -and
    [bool]$sourcePolicy["checkout_authority_bytes_must_equal_git_blob_bytes"]
) "source-binding policy changed"

$attributesPath = Join-Path $repoRoot ".gitattributes"
$attributes = Get-Content -Raw -LiteralPath $attributesPath
$cep = Get-R23D57Json (Join-Path $repoRoot "sdk\closure_evidence_provenance_contract.json")
$cepExtension = $cep["checkout_filter_migration"]["r23d57_non_migration_rule_extension"]
$cepWorkbenchExtension = $cep["checkout_filter_migration"][
    "r23d57_workbench_audit_non_migration_rule_extension"
]
$attributesBlob = (& git -C $repoRoot hash-object -- .gitattributes).Trim()
Assert-R23D57Lineage ($LASTEXITCODE -eq 0) ".gitattributes blob cannot be computed"
Assert-R23D57Lineage (
    $attributes.Contains("sdk/turning/r23d57_* text eol=lf") -and
    $attributes.Contains("sdk/run_qsdk_r23d57_* text eol=lf") -and
    $attributes.Contains("tests/test_qsdk_r23d57_* text eol=lf") -and
    $attributes.Contains("tests/test_sdk_qsdk_r23d57_* text eol=lf") -and
    $attributes.Contains(
        "tests/test_locomotion_experiment_workbench.ps1 text eol=lf"
    ) -and
    [string]$cep["checkout_filter_migration"]["current_gitattributes_raw_sha256"] -ceq
        (Get-R23D57RawSha256 $attributesPath).Substring(7) -and
    [string]$cep["checkout_filter_migration"]["current_gitattributes_git_blob_oid"] -ceq
        $attributesBlob -and
    -not [bool]$cepExtension["initial_provenance_failure_observed"] -and
    [int]$cepExtension["added_rule_count"] -eq 4 -and
    [int]$cepExtension["historical_tracked_file_renormalization_count"] -eq 0 -and
    -not [bool]$cepExtension["checkout_filter_migration_executed"] -and
    [int]$cepExtension["physical_world_count"] -eq 0 -and
    [string]$cepWorkbenchExtension["declared_from_parent_commit"] -ceq
        "7fbc2bf7e6194a8f7f98e42a157d9451bca3d53d" -and
    [string]$cepWorkbenchExtension["source_rule_commit"] -ceq
        "fb460ab6828e6e38342c305faf58c80eb3744b08" -and
    [string]$cepWorkbenchExtension["path_rule"] -ceq
        "tests/test_locomotion_experiment_workbench.ps1 text eol=lf" -and
    [int]$cepWorkbenchExtension["added_rule_count"] -eq 1 -and
    [bool]$cepWorkbenchExtension[
        "first_clean_pushed_preflight_failure_observed"
    ] -and
    [string]$cepWorkbenchExtension["failure_message"] -ceq
        "QSDK-R23D57 LINEAGE: bounded checkout provenance changed" -and
    [bool]$cepWorkbenchExtension["repair_qualification_pending"] -and
    [int]$cepWorkbenchExtension["physical_world_count"] -eq 0 -and
    -not [bool]$cepWorkbenchExtension["physical_acceptance_authority"]
) "bounded checkout provenance changed"

$releaseContainers = @(Find-R23D57Container $release (
    "prospective_r23d57_full_precision_trace_transport"
))
$supportContainers = @(Find-R23D57Container $support (
    "prospective_r23d57_full_precision_trace_transport"
))
$releaseClosedContainers = @(Find-R23D57Container $release "closed_r23d57_attempt")
$supportClosedContainers = @(Find-R23D57Container $support "closed_r23d57_attempt")
Assert-R23D57Lineage (
    $releaseContainers.Count -eq 1 -and $supportContainers.Count -eq 1 -and
    $releaseClosedContainers.Count -eq 1 -and $supportClosedContainers.Count -eq 1
) "release/support R23D57 block cardinality changed"
$releaseBlock = $releaseContainers[0][
    "prospective_r23d57_full_precision_trace_transport"
]
$supportBlock = $supportContainers[0][
    "prospective_r23d57_full_precision_trace_transport"
]
$releaseClosed = $releaseClosedContainers[0]["closed_r23d57_attempt"]
$supportClosed = $supportClosedContainers[0]["closed_r23d57_attempt"]
Assert-R23D57Lineage (
    -not [string]::IsNullOrWhiteSpace(
        [string]$releaseContainers[0]["current_successor_status"]
    ) -and
    [string]$releaseContainers[0]["current_successor_status"] -ceq
        [string]$supportContainers[0]["current_successor_status"] -and
    -not [string]::IsNullOrWhiteSpace(
        [string]$releaseContainers[0]["current_prospective_successor_status"]
    ) -and
    [string]$releaseContainers[0]["current_prospective_successor_status"] -ceq
        [string]$supportContainers[0]["current_prospective_successor_status"] -and
    [string]$releaseContainers[0]["current_successor_reason"] -ceq
        [string]$supportContainers[0]["current_successor_reason"] -and
    [string]$releaseBlock["campaign_id"] -ceq $campaignId -and
    [string]$releaseBlock["status"] -ceq
        "closed_complete_valid_positive_exact_zero_world_transport_conformance_physical_campaign_consumed_invalid_complete" -and
    [string]$supportBlock["status"] -ceq [string]$releaseBlock["status"] -and
    [string]$releaseBlock["question_class"] -ceq "development" -and
    [int]$releaseBlock["world_attempt_count"] -eq 0 -and
    [int]$releaseBlock["world_build_count"] -eq 0 -and
    [int]$releaseBlock["physical_source_binding_exact_path_count"] -eq
        $exactPaths.Count -and
    [string]$releaseBlock["physical_preregistration_raw_sha256"] -ceq
        (Get-R23D57RawSha256 $preregistrationPath) -and
    [string]$supportBlock["physical_preregistration_sha256"] -ceq
        [string]$releaseBlock["physical_preregistration_raw_sha256"] -and
    [string]$releaseBlock["physical_implementation_raw_sha256"] -ceq
        (Get-R23D57RawSha256 $implementationPath) -and
    [string]$supportBlock["physical_implementation_sha256"] -ceq
        [string]$releaseBlock["physical_implementation_raw_sha256"] -and
    [string]$releaseBlock["physical_trace_selected_godot_invocation"] -ceq
        'JSON.stringify(rows, "", true, true)' -and
    [string]$supportBlock["physical_trace_selected_godot_invocation"] -ceq
        [string]$releaseBlock["physical_trace_selected_godot_invocation"] -and
    [bool]$releaseBlock["physical_implementation_complete"] -and
    [bool]$supportBlock["physical_implementation_complete"] -and
    [bool]$releaseBlock["physical_worker_complete"] -and
    [bool]$releaseBlock["physical_evaluator_complete"] -and
    [bool]$releaseBlock["physical_supervisor_complete"] -and
    [bool]$releaseBlock["campaign_attestation_manifest_complete"] -and
    [bool]$releaseBlock["complete_zero_world_campaign_gate_passed"] -and
    [bool]$supportBlock["complete_zero_world_campaign_gate_passed"] -and
    [bool]$releaseBlock["scoped_qualification_passed"] -and
    [bool]$releaseBlock["adoption_passed"] -and
    [bool]$releaseBlock["physical_campaign_opened"] -and
    [bool]$supportBlock["physical_campaign_opened"] -and
    [bool]$releaseBlock["physical_execution_was_authorized"] -and
    [bool]$releaseBlock["physical_execution_completed"] -and
    [bool]$releaseBlock["physical_attempt_identity_consumed"] -and
    -not [bool]$releaseBlock["physical_execution_authorized"] -and
    -not [bool]$releaseBlock["turning_acceptance"] -and
    -not [bool]$releaseBlock["prone_to_standing"] -and
    -not [bool]$releaseBlock["release_authorized"] -and
    -not [bool]$releaseBlock["physical_acceptance_authority"]
) "release/support prospective boundary changed"

Assert-R23D57Lineage (
    [string]$releaseClosed["status"] -ceq
        "closed_consumed_invalid_complete_outcome_exposed_godot_full_precision_trace_actuator_phase_characterization_development" -and
    [string]$supportClosed["status"] -ceq [string]$releaseClosed["status"] -and
    [string]$releaseClosed["closure_raw_sha256"] -ceq
        (Get-R23D57RawSha256 $closurePath) -and
    [string]$supportClosed["closure_sha256"] -ceq
        [string]$releaseClosed["closure_raw_sha256"] -and
    [string]$releaseClosed["closure_audit_raw_sha256"] -ceq
        (Get-R23D57RawSha256 $closureAuditPath) -and
    [string]$supportClosed["closure_audit_sha256"] -ceq
        [string]$releaseClosed["closure_audit_raw_sha256"] -and
    [string]$releaseClosed["physical_source_commit"] -ceq
        "f0993e7e4886ff51254fb4de47f22a1bf0cc7ebe" -and
    [string]$supportClosed["physical_source_commit"] -ceq
        [string]$releaseClosed["physical_source_commit"] -and
    [int]$releaseClosed["observed_world_build_count"] -eq 3 -and
    [int]$supportClosed["observed_world_build_count"] -eq 3 -and
    [int]$releaseClosed["execution_valid_cell_count"] -eq 0 -and
    [int]$releaseClosed["retained_trace_row_count"] -eq 8976 -and
    [int]$releaseClosed["retained_actuator_application_count"] -eq 71808 -and
    [int]$releaseClosed["declared_cap_exact_mismatch_count"] -eq 24 -and
    [int]$releaseClosed["rear_contact_cycle_count"] -eq 0 -and
    [int]$releaseClosed["rear_contact_true_step_count"] -eq 17952 -and
    [bool]$releaseClosed["identity_consumed"] -and
    -not [bool]$releaseClosed["same_identity_rerun_allowed"] -and
    [bool]$releaseClosed[
        "terminal_trace_serialization_precision_is_sufficient_cap_identity_failure_cause"
    ] -and
    -not [bool]$releaseClosed[
        "compiled_cap_route_is_proved_to_cause_continuous_rear_contact"
    ] -and
    -not [bool]$releaseClosed["turning_mechanism_selected"] -and
    -not [bool]$releaseClosed["godot_jolt_turning_validation"] -and
    -not [bool]$releaseClosed["prone_to_standing"] -and
    -not [bool]$releaseClosed["release_authorized"] -and
    -not [bool]$releaseClosed["physical_acceptance_authority"]
) "release/support closed R23D57 boundary changed"

$manifest = Get-R23D57Json $manifestPath
Assert-R23D57Lineage (
    [string]$manifest["schema_version"] -ceq
        "sporespore_locomotion_campaign_attestation_manifest_v1" -and
    [string]$manifest["campaign_id"] -ceq $campaignId -and
    [string]$manifest["question_class"] -ceq "development" -and
    [int]$manifest["declared_physical_world_count"] -eq 3 -and
    -not [bool]$manifest["physical_execution_authorized"] -and
    -not [bool]$manifest["physical_acceptance_authority"] -and
    -not [bool]$manifest["release_authority"]
) "campaign-attestation manifest boundary changed"

foreach ($claimName in @($preregClaims.Keys)) {
    Assert-R23D57Lineage (-not [bool]$preregClaims[$claimName]) (
        "preregistration claim became true: $claimName"
    )
}
Assert-R23D57Lineage ([bool]$implementationClaims["implementation_complete"]) (
    "implementation-complete declaration is missing"
)
foreach ($claimName in @($implementationClaims.Keys | Where-Object {
    $_ -cne "implementation_complete"
})) {
    Assert-R23D57Lineage (-not [bool]$implementationClaims[$claimName]) (
        "implementation claim became true: $claimName"
    )
}
$closure = Get-R23D57Json $closurePath
Assert-R23D57Lineage (
    [string]$closure["status"] -ceq
        "closed_consumed_invalid_complete_outcome_exposed_godot_full_precision_trace_actuator_phase_characterization_development" -and
    [string]$closure["source_commit"] -ceq
        "f0993e7e4886ff51254fb4de47f22a1bf0cc7ebe" -and
    [bool]$closure["identity_consumed"] -and
    -not [bool]$closure["same_identity_rerun_allowed"] -and
    [int]$closure["official_result"]["observed_world_build_count"] -eq 3 -and
    [int]$closure["official_result"]["execution_valid_cell_count"] -eq 0 -and
    -not [bool]$closure["claims"]["godot_jolt_r23d29_turning"] -and
    -not [bool]$closure["claims"]["prone_to_standing"] -and
    -not [bool]$closure["claims"]["release_authorized"]
) "closed R23D57 disposition changed"

$receipt = [ordered]@{
    schema_version = "sporespore_qsdk_r23d57_lineage_receipt_v1"
    campaign_id = $campaignId
    question_class = "development"
    exact_source_path_count = $exactPaths.Count
    declared_cell_count = 3
    declared_world_count = 3
    expected_trace_row_count = 8976
    expected_actuator_application_count = 71808
    live_fixture_cap_write_count = 8
    live_fixture_cap_readback_count = 8
    transport_fixture_count = 35
    transport_default_target_failure_count = 14
    transport_full_precision_failure_count = 0
    transport_mutation_rejection_count = 12
    transport_boundary_control_count = 2
    turning_gate_invoked = $false
    mechanism_selection_rule_count = 0
    physical_campaign_opened = $true
    world_attempt_count = 3
    world_build_count = 3
    execution_valid_cell_count = 0
    retained_trace_row_count = 8976
    retained_actuator_application_count = 71808
    declared_cap_exact_mismatch_count = 24
    rear_contact_cycle_count = 0
    prone_to_standing = $false
    release_authority = $false
    physical_acceptance_authority = $false
}
Write-Host (
    "QSDK_R23D57_LINEAGE_PASS " +
    ($receipt | ConvertTo-Json -Depth 20 -Compress)
)
