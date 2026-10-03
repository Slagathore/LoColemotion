#requires -Version 7.0

[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$turningRoot = Join-Path $repoRoot "sdk\turning"
$preregistrationPath = Join-Path $turningRoot (
    "r23d56_godot_valid_route_actuator_phase_characterization_preregistration_v1.json"
)
$implementationPath = Join-Path $turningRoot (
    "r23d56_godot_valid_route_actuator_phase_characterization_implementation_v1.json"
)
$manifestPath = Join-Path $turningRoot "r23d56_campaign_attestation_manifest_v1.json"
$releasePath = Join-Path $repoRoot "sdk\release\quadruped_release_contract.json"
$supportPath = Join-Path $repoRoot "sdk\release\quadruped_support_matrix.json"
$closurePath = Join-Path $turningRoot (
    "r23d56_godot_valid_route_actuator_phase_characterization_closure_v1.json"
)
$campaignId = (
    "QSDK-R23D56-GODOT-VALID-ROUTE-ACTUATOR-PHASE-CHARACTERIZATION-DEVELOPMENT"
)
$policyId = "sporespore_godot_jolt_live_fixture_compiled_actuator_cap_binding_v1"

function Assert-R23D56Lineage([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "QSDK-R23D56 LINEAGE: $Message" }
}

function Get-R23D56RawSha256([string]$Path) {
    return "sha256:" + (
        Get-FileHash -LiteralPath $Path -Algorithm SHA256
    ).Hash.ToLowerInvariant()
}

function Get-R23D56Json([string]$Path) {
    Assert-R23D56Lineage (Test-Path -LiteralPath $Path -PathType Leaf) (
        "required JSON is missing: $Path"
    )
    return Get-Content -Raw -LiteralPath $Path |
        ConvertFrom-Json -AsHashtable -Depth 100
}

function Find-R23D56Container([object]$Value, [string]$PropertyName) {
    $matches = [Collections.Generic.List[object]]::new()
    function Visit-R23D56([object]$Current) {
        if ($Current -is [Collections.IDictionary]) {
            if ($Current.Contains($PropertyName)) { $matches.Add($Current) }
            foreach ($entry in $Current.GetEnumerator()) { Visit-R23D56 $entry.Value }
        } elseif ($Current -is [Collections.IEnumerable] -and
            $Current -isnot [string]) {
            foreach ($item in $Current) { Visit-R23D56 $item }
        }
    }
    Visit-R23D56 $Value
    return @($matches)
}

$actualRoot = (& git -C $repoRoot rev-parse --show-toplevel).Trim()
Assert-R23D56Lineage ($LASTEXITCODE -eq 0) "repository root cannot be resolved"
$actualRemote = (& git -C $repoRoot remote get-url origin).Trim()
Assert-R23D56Lineage ($LASTEXITCODE -eq 0) "origin cannot be resolved"
Assert-R23D56Lineage (
    [IO.Path]::GetFullPath($actualRoot) -ceq $repoRoot -and
    $actualRemote -ceq "https://github.com/Slagathore/sporespore.git"
) "repository identity changed"

$preregistration = Get-R23D56Json $preregistrationPath
$implementation = Get-R23D56Json $implementationPath
$release = Get-R23D56Json $releasePath
$support = Get-R23D56Json $supportPath
$lineage = $preregistration["immutable_lineage"]
$successor = $preregistration["scientifically_distinct_successor"]
$matrix = $preregistration["frozen_matrix"]
$observation = $preregistration["required_observation"]
$capBinding = $preregistration["required_live_fixture_cap_binding"]
$characterization = $preregistration["predeclared_characterization"]
$adequacy = $preregistration["adequacy"]
$preregClaims = $preregistration["claims"]
$development = $implementation["development_boundary"]
$sourcePolicy = $implementation["source_binding_policy"]
$implementationClaims = $implementation["claims"]

Assert-R23D56Lineage (
    [string]$preregistration["schema_version"] -ceq
        "sporespore_qsdk_r23d56_godot_valid_route_actuator_phase_characterization_preregistration_v1" -and
    [string]$implementation["schema_version"] -ceq
        "sporespore_qsdk_r23d56_godot_valid_route_actuator_phase_characterization_implementation_v1" -and
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

Assert-R23D56Lineage (
    [string]$lineage["development_parent_commit"] -ceq
        "169671734bd9d9fa7cdb837262aa6d5a0d911c6c" -and
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
) "immutable R54, R55, or RC7 lineage changed"

Assert-R23D56Lineage (
    [string]$successor["comparator_campaign_id"] -ceq
        "QSDK-R23D54-GODOT-ACTUATOR-PHASE-CHARACTERIZATION-DEVELOPMENT" -and
    [int]$successor["declared_physics_model_change_count"] -eq 0 -and
    [int]$successor["declared_controller_change_count"] -eq 0 -and
    [int]$successor["declared_measurement_change_count"] -eq 0 -and
    [int]$successor["declared_live_host_parameter_binding_change_count"] -eq 1 -and
    -not [bool]$successor["historical_world_reused_as_r23d56_cell"] -and
    -not [bool]$successor["r23d54_terminal_or_trace_reused_as_r23d56_cell"] -and
    -not [bool]$successor["threshold_changed"] -and
    -not [bool]$successor["fresh_held_out_condition_consumed"]
) "scientifically distinct successor boundary changed"

Assert-R23D56Lineage (
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
    -not [bool]$characterization["turning_gate_invoked"] -and
    [int]$characterization["mechanism_selection_rule_count"] -eq 0 -and
    -not [bool]$adequacy["turning_acceptance_attempted"] -and
    -not [bool]$adequacy["fresh_held_out_validation_attempted"]
) "finite matrix, observation, cap-binding, or adequacy boundary changed"

$exactPaths = @($sourcePolicy["exact_paths"] | ForEach-Object { [string]$_ })
$uniquePaths = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
foreach ($relativePath in $exactPaths) {
    Assert-R23D56Lineage ($uniquePaths.Add($relativePath)) (
        "duplicate exact source path: $relativePath"
    )
    Assert-R23D56Lineage (
        Test-Path -LiteralPath (Join-Path $repoRoot $relativePath) -PathType Leaf
    ) "missing exact source path: $relativePath"
}
foreach ($requiredPath in @(
    ".gitattributes",
    "sdk/closure_evidence_provenance_contract.json",
    "sdk/release/quadruped_release_contract.json",
    "sdk/release/quadruped_support_matrix.json",
    "sdk/workbench/experiment_catalog.json",
    "sdk/turning/r23d54_godot_actuator_phase_characterization_closure_v1.json",
    "sdk/turning/r23d55_godot_live_fixture_actuator_cap_conformance_v1.json",
    "sdk/turning/r23d55_post_rc7_audit_compatibility_v1.json",
    "sdk/locomotion_campaign_attestation_v1_recommissioning_rc7_closure.json",
    "sdk/trace_analysis/godot_actuator_phase_observation_contract_v1.json",
    "sdk/turning/r23d56_godot_valid_route_actuator_phase_characterization_preregistration_v1.json",
    "sdk/turning/r23d56_godot_valid_route_actuator_phase_characterization_implementation_v1.json",
    "sdk/turning/r23d56_godot_valid_route_actuator_phase_characterization.py",
    "sdk/turning/r23d56_godot_valid_route_actuator_phase_characterization_evaluator.py",
    "tests/test_sdk_qsdk_r23d56_godot_jolt_physical_worker.gd",
    "tests/test_qsdk_r23d56_lineage.ps1",
    "tests/test_qsdk_r23d56_campaign_roles.ps1",
    "sdk/run_qsdk_r23d56_supervisor.ps1",
    "sdk/turning/r23d56_campaign_attestation_manifest_v1.json"
)) {
    Assert-R23D56Lineage ($uniquePaths.Contains($requiredPath)) (
        "required exact source dependency omitted: $requiredPath"
    )
}
Assert-R23D56Lineage (
    @($sourcePolicy["tracked_prefixes"]).Count -eq 2 -and
    [bool]$sourcePolicy["duplicate_paths_forbidden"] -and
    [bool]$sourcePolicy["empty_prefix_expansion_forbidden"] -and
    [bool]$sourcePolicy["checkout_authority_bytes_must_equal_git_blob_bytes"]
) "source-binding policy changed"

$attributesPath = Join-Path $repoRoot ".gitattributes"
$attributes = Get-Content -Raw -LiteralPath $attributesPath
$cep = Get-R23D56Json (Join-Path $repoRoot "sdk\closure_evidence_provenance_contract.json")
$cepExtension = $cep["checkout_filter_migration"]["r23d56_non_migration_rule_extension"]
$attributesBlob = (& git -C $repoRoot hash-object -- .gitattributes).Trim()
Assert-R23D56Lineage ($LASTEXITCODE -eq 0) ".gitattributes blob cannot be computed"
Assert-R23D56Lineage (
    $attributes.Contains("sdk/turning/r23d56_* text eol=lf") -and
    $attributes.Contains("sdk/run_qsdk_r23d56_* text eol=lf") -and
    $attributes.Contains("tests/test_qsdk_r23d56_* text eol=lf") -and
    $attributes.Contains("tests/test_sdk_qsdk_r23d56_* text eol=lf") -and
    [string]$cep["checkout_filter_migration"]["current_gitattributes_raw_sha256"] -ceq
        (Get-R23D56RawSha256 $attributesPath).Substring(7) -and
    [string]$cep["checkout_filter_migration"]["current_gitattributes_git_blob_oid"] -ceq
        $attributesBlob -and
    [bool]$cepExtension["initial_provenance_failure_observed"] -and
    [int]$cepExtension["added_rule_count"] -eq 4 -and
    [int]$cepExtension["historical_tracked_file_renormalization_count"] -eq 0 -and
    -not [bool]$cepExtension["checkout_filter_migration_executed"] -and
    [int]$cepExtension["physical_world_count"] -eq 0
) "bounded checkout provenance changed"

$releaseContainers = @(Find-R23D56Container $release (
    "prospective_r23d56_valid_route_actuator_phase_characterization"
))
$supportContainers = @(Find-R23D56Container $support (
    "prospective_r23d56_valid_route_actuator_phase_characterization"
))
Assert-R23D56Lineage (
    $releaseContainers.Count -eq 1 -and $supportContainers.Count -eq 1
) "release/support R23D56 block cardinality changed"
$releaseBlock = $releaseContainers[0][
    "prospective_r23d56_valid_route_actuator_phase_characterization"
]
$supportBlock = $supportContainers[0][
    "prospective_r23d56_valid_route_actuator_phase_characterization"
]
Assert-R23D56Lineage (
    ($releaseBlock | ConvertTo-Json -Depth 100 -Compress) -ceq
        ($supportBlock | ConvertTo-Json -Depth 100 -Compress) -and
    [string]$releaseContainers[0]["current_successor_status"] -ceq
        "r23d56_prospective_valid_route_characterization_zero_world_contract_ready" -and
    [string]$supportContainers[0]["current_successor_status"] -ceq
        "r23d56_prospective_valid_route_characterization_zero_world_contract_ready" -and
    [string]$releaseBlock["campaign_id"] -ceq $campaignId -and
    [string]$releaseBlock["question_class"] -ceq "development" -and
    [int]$releaseBlock["declared_world_count"] -eq 3 -and
    [int]$releaseBlock["world_attempt_count"] -eq 0 -and
    [int]$releaseBlock["world_build_count"] -eq 0 -and
    [int]$releaseBlock["source_binding_count"] -eq $exactPaths.Count -and
    [string]$releaseBlock["preregistration_raw_sha256"] -ceq
        (Get-R23D56RawSha256 $preregistrationPath) -and
    [string]$releaseBlock["implementation_raw_sha256"] -ceq
        (Get-R23D56RawSha256 $implementationPath) -and
    [string]$releaseBlock["policy_id"] -ceq $policyId -and
    -not [bool]$releaseBlock["complete_zero_world_gate_passed"] -and
    -not [bool]$releaseBlock["physical_campaign_opened"] -and
    -not [bool]$releaseBlock["turning_acceptance"] -and
    -not [bool]$releaseBlock["prone_to_standing"] -and
    -not [bool]$releaseBlock["release_authority"]
) "release/support prospective boundary changed"

$manifest = Get-R23D56Json $manifestPath
Assert-R23D56Lineage (
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
    Assert-R23D56Lineage (-not [bool]$preregClaims[$claimName]) (
        "preregistration claim became true: $claimName"
    )
}
Assert-R23D56Lineage ([bool]$implementationClaims["implementation_complete"]) (
    "implementation-complete declaration is missing"
)
foreach ($claimName in @($implementationClaims.Keys | Where-Object {
    $_ -cne "implementation_complete"
})) {
    Assert-R23D56Lineage (-not [bool]$implementationClaims[$claimName]) (
        "implementation claim became true: $claimName"
    )
}
Assert-R23D56Lineage (-not (Test-Path -LiteralPath $closurePath)) (
    "R23D56 closure exists before physical execution"
)

$receipt = [ordered]@{
    schema_version = "sporespore_qsdk_r23d56_lineage_receipt_v1"
    campaign_id = $campaignId
    question_class = "development"
    exact_source_path_count = $exactPaths.Count
    declared_cell_count = 3
    declared_world_count = 3
    expected_trace_row_count = 8976
    expected_actuator_application_count = 71808
    live_fixture_cap_write_count = 8
    live_fixture_cap_readback_count = 8
    turning_gate_invoked = $false
    mechanism_selection_rule_count = 0
    physical_campaign_opened = $false
    world_attempt_count = 0
    world_build_count = 0
    prone_to_standing = $false
    release_authority = $false
    physical_acceptance_authority = $false
}
Write-Host (
    "QSDK_R23D56_LINEAGE_PASS " +
    ($receipt | ConvertTo-Json -Depth 20 -Compress)
)
