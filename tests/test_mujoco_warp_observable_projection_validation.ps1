#requires -Version 7.0

[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = [System.IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$manifestPath = Join-Path $repoRoot (
    "sdk\adaptation_provider\" +
    "mujoco_warp_observable_projection_validation_manifest.json"
)
$expectedRoot = "C:\Users\Cole\CodeStuff\games\LoColemotion"
$expectedRemote = "https://github.com/Slagathore/LoColemotion.git"
$expectedSource = "c163524c95b4c0dddf6624d1a42825daa4259ab6"
$expectedMetricSource = "ba3ba521a8570c623ce26c06fb0c4148ac2e0a27"
$expectedMetricIntegration = "424992016f3f770930025ceed00c8a0f15a53707"
$expectedContractHash = (
    "sha256:c79e32e8c0802ad0f9165792f9b423681ce1d6addc343892f1b574f749ea6b12"
)
$expectedMetricContractHash = (
    "sha256:b6dbcf86ad6d49dbeba814640530a2e26f44091695b262e2f961a987d0dc368f"
)
$expectedMetricCompilerHash = (
    "sha256:e0698dfdb68168eabbc2a1d30c1bb76be612b7c8ced1cecdd433e79cf8d0caf9"
)
$expectedMetricManifestHash = (
    "sha256:e9fbbeda6812c830d0eebd4a4f10c4e3c25c34390905448a1c988a203d5fb879"
)
$expectedMetricReportHash = (
    "sha256:d3d8e68fa904e1712642e0767b93b3f4c9395c36da3a46660aee123937d7a7e9"
)
$expectedMetricReceiptHash = (
    "sha256:18bf77deb0006f40153582162d4fc7efe8732740b3f5895709fef5e1ae721a98"
)
$expectedReportPath = (
    "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence\" +
    "mujoco-warp-observable-projection-c163524\report.json"
)
$expectedReportHash = (
    "sha256:3afc83d3a49630371386e89b099e9ca832b9e61457c5fc20d38f9bd121afebe2"
)
$expectedMetricReportPath = (
    "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence\" +
    "mujoco-warp-metric-semantics-ba3ba52\report.json"
)
$expectedMetricReceiptPath = (
    "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence\" +
    "conformance-runs\" +
    "20260814T232917Z-42499201-65bcbf37b4ab476986a55ae64064355d\" +
    "receipt.json"
)
$expectedFixtureHashes = [ordered]@{
    "binding_sha256" = (
        "sha256:5b2f2b881b6c6b1b3980aad2f6897d142800a97f696ae9f4c91888f0c6ef9a14"
    )
    "suite_sha256" = (
        "sha256:7b57720b5ec11c66f2c3c750b8fee2227dcccf1acf97ab7d5190bc31d714d4b7"
    )
    "cpu_native_trace_sha256" = (
        "sha256:041a853ea1ef11592dde5df3ad9ee050aa5c31be993c886a5ab5c269348f3fdc"
    )
    "warp_native_trace_sha256" = (
        "sha256:7c2735694739bcfcc1ededf2a9ecb66b697fc2baf78ae8c3e2e8fd5a8102bbf0"
    )
    "cpu_metric_trace_sha256" = (
        "sha256:5b0fb593f97b4be438f28479580528d07563478572b9cbebfb1da48a7e5563b4"
    )
    "warp_metric_trace_sha256" = (
        "sha256:f42a2bb9efd17bb8e72af66c4bf72bbabca37aff62f0d949473c606786096f6e"
    )
    "evaluation_sha256" = (
        "sha256:b4c66ce4bccc9334aa6da1d6a9083d8883bc19eb0bd8b8a3e953ab49d7bddb75"
    )
}
$expectedCellControls = [ordered]@{
    "mjop0_contract_and_predecessor_boundary" = @(
        "contract_schema_and_question_class",
        "predecessor_contract_hash",
        "predecessor_manifest_hash",
        "predecessor_report_hash",
        "predecessor_cold_receipt_hash",
        "native_field_projection_identity"
    )
    "mjop1_current_incomplete_inventory" = @(
        "inventory_zero_production_bindings",
        "inventory_one_unresolved_binding",
        "inventory_zero_metric_definitions",
        "inventory_authorities_false"
    )
    "mjop2_fixture_binding_compilation" = @(
        "fixture_binding_compiles",
        "qpos_qvel_exact_coverage",
        "state_pose_component_order_shared",
        "actuator_force_exact_coverage",
        "contact_binding_order_and_count",
        "wrong_contact_source_rejected"
    )
    "mjop3_positive_native_projection_and_mjms_integration" = @(
        "cpu_projection_metric_eligible",
        "warp_projection_metric_eligible",
        "mjms_evaluation_positive",
        "mjms_five_metric_vector",
        "contact_event_identities_match",
        "wrong_component_registry_rejected"
    )
    "mjop4_model_address_and_dtype_controls" = @(
        "malformed_model_hash_rejected",
        "zero_nq_rejected",
        "duplicate_component_id_rejected",
        "component_coverage_gap_rejected",
        "component_index_out_of_range_rejected",
        "quaternion_order_rejected",
        "layout_shape_rejected",
        "unobserved_dtype_rejected"
    )
    "mjop5_shape_lifecycle_and_horizon_controls" = @(
        "missing_snapshot_rejected",
        "snapshot_step_reorder_rejected",
        "snapshot_binding_rejected",
        "snapshot_dtype_rejected",
        "snapshot_array_shape_rejected",
        "snapshot_nonfinite_rejected",
        "snapshot_capture_point_rejected",
        "warp_contact_world_out_of_range_rejected"
    )
    "mjop6_energy_contact_and_failure_controls" = @(
        "disabled_energy_rejected",
        "nonfinite_energy_rejected",
        "contact_count_mismatch_rejected",
        "overflow_retained_as_exact_failure",
        "unmapped_contact_retained_as_exact_failure",
        "warp_constraint_bit_failure_retained",
        "baseline_contact_is_left_censored",
        "ignored_pair_without_adequacy_rejected"
    )
    "mjop7_authority_boundary" = @(
        "production_binding_injection_rejected",
        "world_count_injection_rejected"
    )
}
$expectedMutations = [ordered]@{
    "component_coverage_gap_rejected" = "MJOP_COMPONENT_COVERAGE"
    "component_index_out_of_range_rejected" = "MJOP_COMPONENT_INDICES"
    "contact_count_mismatch_rejected" = "MJOP_CONTACT_RECORD_COUNT"
    "disabled_energy_rejected" = "MJOP_MODEL_FEATURES"
    "duplicate_component_id_rejected" = "MJOP_COMPONENT_DUPLICATE"
    "ignored_pair_without_adequacy_rejected" = "MJOP_IGNORED_PAIR_ADEQUACY"
    "layout_shape_rejected" = "MJOP_LAYOUT_SHAPE_MISMATCH"
    "malformed_model_hash_rejected" = "MJOP_MODEL_SHA"
    "missing_snapshot_rejected" = "MJOP_TRACE_SNAPSHOT_COUNT"
    "nonfinite_energy_rejected" = "MJOP_SNAPSHOT_ARRAY_SHAPE"
    "production_binding_injection_rejected" = "MJOP_BINDING_AUTHORITY"
    "quaternion_order_rejected" = "MJOP_COMPONENT_QUATERNION"
    "snapshot_array_shape_rejected" = "MJOP_SNAPSHOT_ARRAY_SHAPE"
    "snapshot_binding_rejected" = "MJOP_SNAPSHOT_BINDING"
    "snapshot_capture_point_rejected" = "MJOP_SNAPSHOT_CAPTURE_POINT"
    "snapshot_dtype_rejected" = "MJOP_SNAPSHOT_DTYPE"
    "snapshot_nonfinite_rejected" = "MJOP_SNAPSHOT_ARRAY_SHAPE"
    "snapshot_step_reorder_rejected" = "MJOP_SNAPSHOT_STEP_ORDER"
    "unobserved_dtype_rejected" = "MJOP_LAYOUT_DTYPE_UNOBSERVED"
    "warp_contact_world_out_of_range_rejected" = "MJOP_WARP_CONTACT_WORLD"
    "world_count_injection_rejected" = "MJOP_TRACE_ZERO_WORLD"
    "wrong_component_registry_rejected" = "MJOP_COMPONENT_REGISTRIES"
    "wrong_contact_source_rejected" = "MJOP_LAYOUT_CONTACT_SOURCE"
    "zero_nq_rejected" = "MJOP_MODEL_NQ"
}
$expectedBindings = @{
    "sdk/adaptation_provider/mujoco_warp_observable_projection_contract_v1.json" = @{
        hash = $expectedContractHash
        length = 10372
    }
    "sdk/adaptation_provider/mujoco_warp_observable_projection.py" = @{
        hash = "sha256:a383160375ee8415867260d6c37622c569cae320cda72454a44a4e1d5ebb34b6"
        length = 43978
    }
    "sdk/adaptation_provider/mujoco_warp_observable_projection_conformance.py" = @{
        hash = "sha256:ebc4b8a44908620c78b0396e46b6107f92d3bbb323da8f1278f68df714d3f2c1"
        length = 36014
    }
    "sdk/adaptation_provider/test_mujoco_warp_observable_projection.py" = @{
        hash = "sha256:d166fbfa96a833c0bf9ea3d7b5ed6c099ca8a8e7131788537e55e1edf6097070"
        length = 5220
    }
    "sdk/run_mujoco_warp_observable_projection_conformance.ps1" = @{
        hash = "sha256:c632d789b5f8ded2d4fcd6a6ef48f16ec2cf7cb4c6a05a72f474a76c9a78d99a"
        length = 9332
    }
}
$manifestFalseFields = @(
    "production_native_observable_binding_complete",
    "production_metric_semantics_complete",
    "production_semantic_ceiling_sources_complete",
    "production_plan_frozen",
    "calibration_executed",
    "production_margins_frozen",
    "heldout_execution_authorized",
    "supported_physics_subset_qualified",
    "training_data_authority",
    "training_plane_authorized",
    "native_mujoco_equivalence",
    "cross_engine_equivalence",
    "scientific_result",
    "physical_acceptance_authority",
    "release_authority"
)
$reportFalseFields = @(
    "calibration_authorized",
    "cross_engine_equivalence",
    "native_mujoco_equivalence",
    "physical_acceptance_authority",
    "physics_state_modified",
    "production_metric_semantics_complete",
    "production_native_observable_binding_complete",
    "production_plan_exists",
    "production_semantic_ceiling_sources_complete",
    "release_authority",
    "scientific_result",
    "supported_physics_subset_qualified",
    "training_data_authority",
    "training_plane_authorized"
)

function Assert-MjopEvidence([bool]$Condition, [string]$Message) {
    if (-not $Condition) {
        throw "MJWARP_OBSERVABLE_PROJECTION_EVIDENCE $Message"
    }
}

function Get-GitBlobBytes {
    param(
        [Parameter(Mandatory = $true)][string]$Commit,
        [Parameter(Mandatory = $true)][string]$RepoRelativePath
    )

    $objectId = (& git -C $repoRoot rev-parse "$Commit`:$RepoRelativePath").Trim()
    Assert-MjopEvidence ($LASTEXITCODE -eq 0) (
        "cannot resolve frozen Git blob: $RepoRelativePath"
    )
    $startInfo = [System.Diagnostics.ProcessStartInfo]::new("git")
    $startInfo.WorkingDirectory = $repoRoot
    $startInfo.ArgumentList.Add("cat-file")
    $startInfo.ArgumentList.Add("blob")
    $startInfo.ArgumentList.Add($objectId)
    $startInfo.UseShellExecute = $false
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $process = [System.Diagnostics.Process]::Start($startInfo)
    $stream = [System.IO.MemoryStream]::new()
    try {
        $process.StandardOutput.BaseStream.CopyTo($stream)
        $process.WaitForExit()
        $errorText = $process.StandardError.ReadToEnd()
        Assert-MjopEvidence ($process.ExitCode -eq 0) (
            "cannot read frozen Git blob $RepoRelativePath`: $errorText"
        )
        return $stream.ToArray()
    } finally {
        $stream.Dispose()
        $process.Dispose()
    }
}

function Get-ByteSha256([byte[]]$Bytes) {
    return (
        "sha256:" +
        [Convert]::ToHexString(
            [System.Security.Cryptography.SHA256]::HashData($Bytes)
        ).ToLowerInvariant()
    )
}

function Assert-Sequence {
    param(
        [Parameter(Mandatory = $true)]$Actual,
        [Parameter(Mandatory = $true)][string[]]$Expected,
        [Parameter(Mandatory = $true)][string]$Message
    )

    $observed = @($Actual)
    Assert-MjopEvidence ($observed.Count -eq $Expected.Count) $Message
    for ($index = 0; $index -lt $Expected.Count; $index++) {
        Assert-MjopEvidence (
            [string]$observed[$index] -ceq $Expected[$index]
        ) "$Message at index $index"
    }
}

function Assert-ExternalEvidence {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$ExpectedHash,
        [Parameter(Mandatory = $true)][int]$ExpectedLength,
        [Parameter(Mandatory = $true)][string]$Label
    )

    Assert-MjopEvidence (
        $Path.StartsWith(
            "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence\",
            [StringComparison]::Ordinal
        ) -and
        (Test-Path -LiteralPath $Path -PathType Leaf)
    ) "$Label is absent from the deliberate evidence root"
    $bytes = [System.IO.File]::ReadAllBytes($Path)
    Assert-MjopEvidence (
        $bytes.Length -eq $ExpectedLength -and
        (Get-ByteSha256 $bytes) -ceq $ExpectedHash
    ) "$Label bytes changed"
    return $bytes
}

Assert-MjopEvidence (
    [System.IO.Path]::GetFullPath($repoRoot).TrimEnd("\") -ceq
        $expectedRoot.TrimEnd("\")
) "repository root differs from the canonical checkout"
$actualRoot = (& git -C $repoRoot rev-parse --show-toplevel).Trim()
Assert-MjopEvidence ($LASTEXITCODE -eq 0) "repository root query failed"
$actualRemote = (& git -C $repoRoot remote get-url origin).Trim()
Assert-MjopEvidence ($LASTEXITCODE -eq 0) "origin remote query failed"
Assert-MjopEvidence (
    $actualRoot.Replace("/", "\").TrimEnd("\") -ceq
        $expectedRoot.TrimEnd("\") -and
    $actualRemote -ceq $expectedRemote
) "repository root or origin remote changed"
Assert-MjopEvidence (Test-Path -LiteralPath $manifestPath -PathType Leaf) (
    "validation manifest is missing"
)

$manifest = Get-Content -LiteralPath $manifestPath -Raw |
    ConvertFrom-Json -AsHashtable -Depth 64
Assert-MjopEvidence (
    [string]$manifest["schema_version"] -ceq
        "sporespore_mujoco_warp_observable_projection_validation_manifest_v1" -and
    [string]$manifest["status"] -ceq
        "accepted_zero_world_source_conformance" -and
    [string]$manifest["question_class"] -ceq "development" -and
    [string]$manifest["release_gate_id"] -ceq "none" -and
    [string]$manifest["source_commit"] -ceq $expectedSource -and
    [string]$manifest["source_remote"] -ceq "origin/main" -and
    [bool]$manifest["source_clean"] -and
    [bool]$manifest["source_matches_origin_main"]
) "manifest identity or frozen source boundary changed"

foreach ($commit in @(
    $expectedMetricSource,
    $expectedMetricIntegration,
    $expectedSource
)) {
    & git -C $repoRoot cat-file -e "$commit^{commit}"
    Assert-MjopEvidence ($LASTEXITCODE -eq 0) (
        "frozen source commit is unavailable: $commit"
    )
    & git -C $repoRoot merge-base --is-ancestor $commit origin/main
    Assert-MjopEvidence ($LASTEXITCODE -eq 0) (
        "frozen source commit is not on origin/main: $commit"
    )
}

$frozenFiles = @($manifest["implementation"]) + @($manifest["contract"])
Assert-MjopEvidence ($frozenFiles.Count -eq $expectedBindings.Count) (
    "manifest must bind exactly five frozen source files"
)
$observedPaths = @{}
foreach ($binding in $frozenFiles) {
    $path = [string]$binding["path"]
    Assert-MjopEvidence (
        $path -cmatch "^sdk/[A-Za-z0-9_./-]+$" -and
        -not $path.Contains("..", [StringComparison]::Ordinal) -and
        $expectedBindings.ContainsKey($path) -and
        -not $observedPaths.ContainsKey($path)
    ) "frozen source path is unexpected or duplicated: $path"
    $observedPaths[$path] = $true
    $expected = $expectedBindings[$path]
    Assert-MjopEvidence (
        [int]$binding["byte_length"] -eq [int]$expected["length"] -and
        [string]$binding["git_blob_raw_sha256"] -ceq
            [string]$expected["hash"]
    ) "manifest source binding changed: $path"
    $bytes = Get-GitBlobBytes -Commit $expectedSource -RepoRelativePath $path
    Assert-MjopEvidence (
        $bytes.Length -eq [int]$expected["length"] -and
        (Get-ByteSha256 $bytes) -ceq [string]$expected["hash"]
    ) "frozen Git blob identity changed: $path"
}
Assert-MjopEvidence ($observedPaths.Count -eq $expectedBindings.Count) (
    "manifest source coverage is incomplete"
)

$contract = $manifest["contract"]
Assert-MjopEvidence (
    [string]$contract["contract_id"] -ceq
        "sporespore_mujoco_warp_premetric_native_observable_projection_v1" -and
    [string]$contract["git_blob_raw_sha256"] -ceq $expectedContractHash -and
    [string]$contract["metric_semantics_contract_raw_sha256"] -ceq
        $expectedMetricContractHash -and
    [string]$contract["metric_semantics_compiler_raw_sha256"] -ceq
        $expectedMetricCompilerHash -and
    [string]$contract["metric_semantics_validation_manifest_raw_sha256"] -ceq
        $expectedMetricManifestHash -and
    [string]$contract["metric_semantics_source_commit"] -ceq
        $expectedMetricSource -and
    [string]$contract["metric_semantics_source_report_sha256"] -ceq
        $expectedMetricReportHash -and
    [string]$contract["metric_semantics_integration_commit"] -ceq
        $expectedMetricIntegration -and
    [string]$contract["metric_semantics_integration_receipt_sha256"] -ceq
        $expectedMetricReceiptHash
) "contract or immutable predecessor identity changed"

$metricContractBytes = Get-GitBlobBytes `
    -Commit $expectedMetricSource `
    -RepoRelativePath (
        "sdk/adaptation_provider/" +
        "mujoco_warp_metric_semantics_contract_v1.json"
    )
Assert-MjopEvidence (
    $metricContractBytes.Length -eq 11001 -and
    (Get-ByteSha256 $metricContractBytes) -ceq $expectedMetricContractHash
) "predecessor metric contract Git blob changed"
$metricCompilerBytes = Get-GitBlobBytes `
    -Commit $expectedMetricSource `
    -RepoRelativePath (
        "sdk/adaptation_provider/mujoco_warp_metric_semantics.py"
    )
Assert-MjopEvidence (
    $metricCompilerBytes.Length -eq 43831 -and
    (Get-ByteSha256 $metricCompilerBytes) -ceq $expectedMetricCompilerHash
) "predecessor metric compiler Git blob changed"
$metricManifestBytes = Get-GitBlobBytes `
    -Commit $expectedMetricIntegration `
    -RepoRelativePath (
        "sdk/adaptation_provider/" +
        "mujoco_warp_metric_semantics_validation_manifest.json"
    )
Assert-MjopEvidence (
    $metricManifestBytes.Length -eq 5177 -and
    (Get-ByteSha256 $metricManifestBytes) -ceq $expectedMetricManifestHash
) "predecessor metric validation manifest Git blob changed"
[void](Assert-ExternalEvidence `
    -Path $expectedMetricReportPath `
    -ExpectedHash $expectedMetricReportHash `
    -ExpectedLength 6037 `
    -Label "predecessor metric source report")
[void](Assert-ExternalEvidence `
    -Path $expectedMetricReceiptPath `
    -ExpectedHash $expectedMetricReceiptHash `
    -ExpectedLength 17338 `
    -Label "predecessor metric cold receipt")

$reportBinding = $manifest["report"]
$reportPath = [string]$reportBinding["path"]
Assert-MjopEvidence (
    $reportPath -ceq $expectedReportPath -and
    [string]$reportBinding["sha256"] -ceq $expectedReportHash -and
    [int]$reportBinding["byte_length"] -eq 9494
) "accepted report binding changed"
$reportBytes = Assert-ExternalEvidence `
    -Path $reportPath `
    -ExpectedHash $expectedReportHash `
    -ExpectedLength 9494 `
    -Label "accepted observable-projection report"
$report = [System.Text.Encoding]::UTF8.GetString($reportBytes) |
    ConvertFrom-Json -AsHashtable -Depth 64

Assert-MjopEvidence (
    [string]$report["schema_version"] -ceq
        "sporespore_mujoco_warp_observable_projection_conformance_report_v1" -and
    [string]$report["schema_version"] -ceq
        [string]$reportBinding["schema_version"] -and
    [string]$report["status"] -ceq "passed_zero_world_source_conformance" -and
    [string]$report["question_class"] -ceq "development" -and
    [bool]$report["ok"] -and
    [string]$report["contract_id"] -ceq [string]$contract["contract_id"] -and
    [string]$report["contract_raw_sha256"] -ceq $expectedContractHash -and
    [string]$report["source"]["commit"] -ceq $expectedSource -and
    [string]$report["source"]["origin_main"] -ceq $expectedSource -and
    [bool]$report["source"]["clean"] -and
    [bool]$report["source"]["matches_origin_main"] -and
    @($report["source"]["status_entries"]).Count -eq 0
) "accepted report is not bound to the exact clean pushed source"

$expectedCells = @($expectedCellControls.Keys)
Assert-Sequence `
    -Actual $report["required_cells"] `
    -Expected $expectedCells `
    -Message "required cell order changed"
Assert-MjopEvidence (
    [int]$report["passed_cells"] -eq 8 -and
    [int]$report["passed_cells"] -eq [int]$reportBinding["passed_cells"] -and
    [int]$report["failed_cells"] -eq 0 -and
    [int]$report["failed_cells"] -eq [int]$reportBinding["failed_cells"] -and
    @($report["cells"]).Count -eq $expectedCells.Count
) "accepted report cell totals changed"
for ($index = 0; $index -lt $expectedCells.Count; $index++) {
    $cell = $report["cells"][$index]
    $cellId = $expectedCells[$index]
    Assert-MjopEvidence (
        [string]$cell["cell_id"] -ceq $cellId -and
        [bool]$cell["ok"]
    ) "report cell order or result changed at index $index"
    Assert-Sequence `
        -Actual $cell["control_names"] `
        -Expected @($expectedCellControls[$cellId]) `
        -Message "report cell controls changed for $cellId"
}

$expectedControls = @()
foreach ($cellId in $expectedCells) {
    $expectedControls += @($expectedCellControls[$cellId])
}
Assert-MjopEvidence (
    $expectedControls.Count -eq 48 -and
    [int]$report["control_count"] -eq 48 -and
    [int]$report["control_count"] -eq [int]$reportBinding["control_count"] -and
    $report["controls"].Count -eq 48
) "control count changed"
foreach ($control in $expectedControls) {
    Assert-MjopEvidence (
        $report["controls"].ContainsKey($control) -and
        [bool]$report["controls"][$control]
    ) "required control did not pass: $control"
}

Assert-MjopEvidence (
    [int]$report["rejected_mutation_count"] -eq 24 -and
    [int]$report["rejected_mutation_count"] -eq
        [int]$reportBinding["rejected_mutation_count"] -and
    $report["rejected_mutations"].Count -eq $expectedMutations.Count
) "rejected structural mutation count changed"
foreach ($mutation in $expectedMutations.Keys) {
    Assert-MjopEvidence (
        $report["rejected_mutations"].ContainsKey($mutation) -and
        [string]$report["rejected_mutations"][$mutation] -ceq
            [string]$expectedMutations[$mutation]
    ) "required structural mutation code changed: $mutation"
}

$inventory = $report["current_inventory"]
Assert-MjopEvidence (
    [string]$inventory["schema_version"] -ceq
        "sporespore_mujoco_warp_observable_projection_inventory_v1" -and
    [string]$inventory["inventory_id"] -ceq
        "mujoco_warp_observable_projection_current_unresolved_v1" -and
    [string]$inventory["contract_raw_sha256"] -ceq $expectedContractHash -and
    [string]$inventory["required_initial_topology_bucket"] -ceq
        "bounded_quadruped_gq15" -and
    [int]$inventory["required_initial_topology_binding_count"] -eq 1 -and
    [int]$inventory["production_topology_binding_count"] -eq 0 -and
    [int]$inventory["unresolved_topology_binding_count"] -eq 1 -and
    [int]$inventory["production_metric_definition_count"] -eq 0 -and
    [int]$inventory["model_construction_count"] -eq 0 -and
    [int]$inventory["step_invocation_count"] -eq 0 -and
    [int]$inventory["world_attempt_count"] -eq 0 -and
    [int]$inventory["world_build_count"] -eq 0 -and
    -not [bool]$inventory["physics_state_modified"] -and
    -not [bool]$inventory["production_native_observable_binding_complete"] -and
    -not [bool]$inventory["production_metric_semantics_complete"] -and
    -not [bool]$inventory["production_semantic_ceiling_sources_complete"] -and
    -not [bool]$inventory["production_plan_exists"] -and
    -not [bool]$inventory["calibration_authorized"] -and
    -not [bool]$inventory["scientific_result"] -and
    -not [bool]$inventory["physical_acceptance_authority"] -and
    -not [bool]$inventory["release_authority"]
) "current unresolved production inventory changed"
Assert-MjopEvidence (
    [int]$report["production_topology_binding_count"] -eq 0 -and
    [int]$report["production_topology_binding_count"] -eq
        [int]$reportBinding["production_topology_binding_count"] -and
    [int]$report["unresolved_topology_binding_count"] -eq 1 -and
    [int]$report["unresolved_topology_binding_count"] -eq
        [int]$reportBinding["unresolved_topology_binding_count"] -and
    [int]$report["production_metric_definition_count"] -eq 0 -and
    [int]$report["production_metric_definition_count"] -eq
        [int]$reportBinding["production_metric_definition_count"]
) "top-level unresolved production inventory changed"

$fixture = $report["fixture"]
foreach ($name in $expectedFixtureHashes.Keys) {
    Assert-MjopEvidence (
        [string]$fixture[$name] -ceq [string]$expectedFixtureHashes[$name]
    ) "fixture content address changed: $name"
}
Assert-MjopEvidence (
    [bool]$fixture["fixture_only"] -and
    -not [bool]$fixture["production_authority"] -and
    [int]$fixture["metric_count"] -eq 5 -and
    [int]$fixture["metric_count"] -eq [int]$reportBinding["fixture_metric_count"] -and
    [int]$fixture["contact_event_count_per_role"] -eq 4 -and
    [int]$fixture["contact_event_count_per_role"] -eq
        [int]$reportBinding["fixture_contact_event_count_per_role"] -and
    [int]$fixture["contact_event_time_error_steps"] -eq 1 -and
    [int]$fixture["contact_event_time_error_steps"] -eq
        [int]$reportBinding["fixture_contact_event_time_error_steps"]
) "finite positive fixture boundary changed"
Assert-MjopEvidence (
    [string]$reportBinding["fixture_binding_sha256"] -ceq
        [string]$expectedFixtureHashes["binding_sha256"] -and
    [string]$reportBinding["fixture_suite_sha256"] -ceq
        [string]$expectedFixtureHashes["suite_sha256"] -and
    [string]$reportBinding["fixture_cpu_native_trace_sha256"] -ceq
        [string]$expectedFixtureHashes["cpu_native_trace_sha256"] -and
    [string]$reportBinding["fixture_warp_native_trace_sha256"] -ceq
        [string]$expectedFixtureHashes["warp_native_trace_sha256"] -and
    [string]$reportBinding["fixture_cpu_metric_trace_sha256"] -ceq
        [string]$expectedFixtureHashes["cpu_metric_trace_sha256"] -and
    [string]$reportBinding["fixture_warp_metric_trace_sha256"] -ceq
        [string]$expectedFixtureHashes["warp_metric_trace_sha256"] -and
    [string]$reportBinding["fixture_evaluation_sha256"] -ceq
        [string]$expectedFixtureHashes["evaluation_sha256"]
) "manifest fixture content addresses changed"

$predecessor = $report["predecessor"]
Assert-MjopEvidence (
    [string]$predecessor["metric_contract_sha256"] -ceq
        $expectedMetricContractHash -and
    [string]$predecessor["metric_compiler_sha256"] -ceq
        $expectedMetricCompilerHash -and
    [string]$predecessor["validation_manifest_sha256"] -ceq
        $expectedMetricManifestHash -and
    [string]$predecessor["source_report_sha256"] -ceq
        $expectedMetricReportHash -and
    [string]$predecessor["integration_receipt_sha256"] -ceq
        $expectedMetricReceiptHash -and
    [int]$predecessor["production_metric_definition_count"] -eq 0 -and
    -not [bool]$predecessor["production_metric_semantics_complete"] -and
    -not [bool]$predecessor["physical_authority"]
) "report predecessor boundary changed"

Assert-MjopEvidence (
    [int]$report["model_construction_count"] -eq 0 -and
    [int]$report["model_construction_count"] -eq
        [int]$reportBinding["model_construction_count"] -and
    [int]$report["step_invocation_count"] -eq 0 -and
    [int]$report["step_invocation_count"] -eq
        [int]$reportBinding["step_invocation_count"] -and
    [int]$report["world_attempt_count"] -eq 0 -and
    [int]$report["world_attempt_count"] -eq
        [int]$reportBinding["world_attempt_count"] -and
    [int]$report["world_build_count"] -eq 0 -and
    [int]$report["world_build_count"] -eq
        [int]$reportBinding["world_build_count"] -and
    -not [bool]$report["physics_state_modified"]
) "accepted report exceeded its zero-world source-only boundary"
Assert-MjopEvidence (
    [bool]$manifest["positive_fixture_only"] -and
    -not [bool]$manifest["production_native_observable_binding_complete"]
) "manifest omitted the fixture-only unresolved-binding boundary"
foreach ($field in $manifestFalseFields) {
    Assert-MjopEvidence (-not [bool]$manifest[$field]) (
        "manifest gained authority: $field"
    )
}
foreach ($field in $reportFalseFields) {
    Assert-MjopEvidence (-not [bool]$report[$field]) (
        "report gained authority: $field"
    )
}

Write-Host (
    "MJWARP_OBSERVABLE_PROJECTION_EVIDENCE_PASS source=c163524 " +
    "cells=8 controls=48 rejected=24 metrics=5 bindings=0 unresolved=1 " +
    "models=0 steps=0 worlds=0 plan=false calibration=false"
)
