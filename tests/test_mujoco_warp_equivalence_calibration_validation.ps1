#requires -Version 7.0

[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = [System.IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$manifestPath = Join-Path $repoRoot (
    "sdk\adaptation_provider\" +
    "mujoco_warp_equivalence_calibration_validation_manifest.json"
)
$expectedRoot = "C:\Users\Cole\CodeStuff\games\LoColemotion"
$expectedRemote = "https://github.com/Slagathore/LoColemotion.git"
$expectedSource = "daca13321288ba27e5c619509c554bf2126e362e"
$expectedCells = @(
    "mjcal0_contract_and_predecessor_boundary",
    "mjcal1_adequacy_formula",
    "mjcal2_plan_compilation",
    "mjcal3_positive_calibration_projection",
    "mjcal4_negative_calibration_retention",
    "mjcal5_disjoint_heldout_freeze",
    "mjcal6_mutation_and_leakage_controls",
    "mjcal7_authority_boundary"
)
$expectedMutations = @(
    "inadequate_calibration_cohort",
    "duplicate_condition_id",
    "calibration_heldout_overlap",
    "duplicate_or_overlapping_seed",
    "partition_binding_mutation",
    "missing_factor_coverage",
    "outcome_exposed_condition",
    "training_condition_leakage",
    "margin_widened_beyond_semantic_ceiling",
    "nonfinite_margin",
    "insufficient_fresh_process_repeats",
    "sensitivity_role_omission",
    "heldout_result_in_calibration",
    "nonfinite_calibration_result",
    "incomplete_calibration_result"
)
$authorityFields = @(
    "production_plan_frozen",
    "calibration_executed",
    "production_margins_frozen",
    "heldout_execution_authorized",
    "supported_physics_subset_qualified",
    "training_data_authority",
    "training_plane_authorized",
    "scientific_result",
    "physical_acceptance_authority",
    "release_authority"
)

function Assert-MjcalEvidence([bool]$Condition, [string]$Message) {
    if (-not $Condition) {
        throw "MJWARP_CALIBRATION_EVIDENCE $Message"
    }
}

function Get-GitBlobBytes {
    param(
        [Parameter(Mandatory = $true)][string]$Commit,
        [Parameter(Mandatory = $true)][string]$RepoRelativePath
    )

    $objectId = (& git -C $repoRoot rev-parse "$Commit`:$RepoRelativePath").Trim()
    Assert-MjcalEvidence ($LASTEXITCODE -eq 0) (
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
        Assert-MjcalEvidence ($process.ExitCode -eq 0) (
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

function Get-Cell([hashtable]$Report, [string]$CellId) {
    $matches = @($Report["cells"] | Where-Object {
        [string]$_['cell_id'] -ceq $CellId
    })
    Assert-MjcalEvidence ($matches.Count -eq 1) (
        "report cell is missing or duplicated: $CellId"
    )
    return $matches[0]
}

Assert-MjcalEvidence (
    [System.IO.Path]::GetFullPath($repoRoot).TrimEnd("\") -ceq
        $expectedRoot.TrimEnd("\")
) "repository root differs from the canonical checkout"
$actualRoot = (& git -C $repoRoot rev-parse --show-toplevel).Trim()
$actualRemote = (& git -C $repoRoot remote get-url origin).Trim()
Assert-MjcalEvidence ($LASTEXITCODE -eq 0) "repository identity query failed"
Assert-MjcalEvidence (
    $actualRoot.Replace("/", "\").TrimEnd("\") -ceq
        $expectedRoot.TrimEnd("\") -and
    $actualRemote -ceq $expectedRemote
) "repository root or origin remote changed"
Assert-MjcalEvidence (Test-Path -LiteralPath $manifestPath -PathType Leaf) (
    "validation manifest is missing"
)

$manifest = Get-Content -LiteralPath $manifestPath -Raw |
    ConvertFrom-Json -AsHashtable -Depth 64
Assert-MjcalEvidence (
    [string]$manifest["schema_version"] -ceq
        "sporespore_mujoco_warp_equivalence_calibration_validation_manifest_v1" -and
    [string]$manifest["status"] -ceq "accepted_zero_world_source_conformance" -and
    [string]$manifest["question_class"] -ceq "development" -and
    [string]$manifest["release_gate_id"] -ceq "none" -and
    [string]$manifest["source_commit"] -ceq $expectedSource -and
    [string]$manifest["source_remote"] -ceq "origin/main" -and
    [bool]$manifest["source_clean"] -and
    [bool]$manifest["source_matches_origin_main"]
) "manifest identity or frozen source boundary changed"

& git -C $repoRoot cat-file -e "$expectedSource^{commit}"
Assert-MjcalEvidence ($LASTEXITCODE -eq 0) "frozen source commit is unavailable"

$frozenFiles = @($manifest["implementation"]) + @($manifest["contract"])
Assert-MjcalEvidence ($frozenFiles.Count -eq 5) (
    "manifest must bind exactly five frozen source files"
)
foreach ($binding in $frozenFiles) {
    $path = [string]$binding["path"]
    Assert-MjcalEvidence (
        $path -cmatch "^sdk/[A-Za-z0-9_./-]+$" -and
        -not $path.Contains("..", [StringComparison]::Ordinal)
    ) "frozen source path is not repository-relative: $path"
    $bytes = Get-GitBlobBytes -Commit $expectedSource -RepoRelativePath $path
    Assert-MjcalEvidence (
        $bytes.Length -eq [int]$binding["byte_length"] -and
        (Get-ByteSha256 $bytes) -ceq
            [string]$binding["git_blob_raw_sha256"]
    ) "frozen Git blob identity changed: $path"
}

$contract = $manifest["contract"]
Assert-MjcalEvidence (
    [string]$contract["contract_id"] -ceq
        "sporespore_mujoco_warp_repeatability_sensitivity_and_margin_protocol_v1" -and
    [string]$contract["git_blob_raw_sha256"] -ceq
        "sha256:c38f26211882f3349266f7381fcc5dc34acc9b20e5485d3b18d7f1185c35e374" -and
    [string]$contract["predecessor_contract_raw_sha256"] -ceq
        "sha256:8f2c3dd7122156a82dc4dd85db27aef5843e3419192b62ad6d4a47613020b1d3"
) "contract or immutable predecessor identity changed"

$reportBinding = $manifest["report"]
$reportPath = [string]$reportBinding["path"]
Assert-MjcalEvidence (
    $reportPath.StartsWith(
        "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence\",
        [StringComparison]::Ordinal
    ) -and
    (Test-Path -LiteralPath $reportPath -PathType Leaf)
) "retained report is absent from the deliberate evidence root"
$reportBytes = [System.IO.File]::ReadAllBytes($reportPath)
Assert-MjcalEvidence (
    $reportBytes.Length -eq [int]$reportBinding["byte_length"] -and
    (Get-ByteSha256 $reportBytes) -ceq [string]$reportBinding["sha256"]
) "retained report bytes changed"
$report = [System.Text.Encoding]::UTF8.GetString($reportBytes) |
    ConvertFrom-Json -AsHashtable -Depth 64

Assert-MjcalEvidence (
    [string]$report["schema_version"] -ceq
        [string]$reportBinding["schema_version"] -and
    [bool]$report["ok"] -and
    [string]$report["contract_id"] -ceq [string]$contract["contract_id"] -and
    [string]$report["contract_raw_sha256"] -ceq
        [string]$contract["git_blob_raw_sha256"] -and
    [string]$report["source"]["commit"] -ceq $expectedSource -and
    [string]$report["source"]["origin_main"] -ceq $expectedSource -and
    [bool]$report["source"]["clean"] -and
    [bool]$report["source"]["matches_origin_main"] -and
    @($report["source"]["status_entries"]).Count -eq 0
) "report is not bound to the exact clean pushed source"
Assert-MjcalEvidence (
    [int]$report["passed_cells"] -eq [int]$reportBinding["passed_cells"] -and
    [int]$report["failed_cells"] -eq [int]$reportBinding["failed_cells"] -and
    [int]$report["mutation_control_count"] -eq
        [int]$reportBinding["mutation_control_count"] -and
    [int]$report["metric_family_count"] -eq
        [int]$reportBinding["metric_family_count"] -and
    [int]$report["minimum_unique_calibration_condition_groups"] -eq
        [int]$reportBinding["minimum_unique_calibration_condition_groups"] -and
    [int]$report["minimum_unique_heldout_condition_groups"] -eq
        [int]$reportBinding["minimum_unique_heldout_condition_groups"] -and
    [int]$report["model_construction_count"] -eq
        [int]$reportBinding["model_construction_count"] -and
    [int]$report["step_invocation_count"] -eq
        [int]$reportBinding["step_invocation_count"] -and
    [int]$report["world_attempt_count"] -eq
        [int]$reportBinding["world_attempt_count"] -and
    [int]$report["world_build_count"] -eq
        [int]$reportBinding["world_build_count"] -and
    @($report["cells"]).Count -eq $expectedCells.Count
) "report totals, adequacy minimums, or zero-world counts changed"
for ($index = 0; $index -lt $expectedCells.Count; $index++) {
    $cell = $report["cells"][$index]
    Assert-MjcalEvidence (
        [string]$cell["cell_id"] -ceq $expectedCells[$index] -and
        [bool]$cell["passed"] -and
        [int]$cell["world_build_count"] -eq 0 -and
        -not [bool]$cell["physical_acceptance_authority"]
    ) "report cell order, result, or zero-world boundary changed at index $index"
}

$boundaryCell = Get-Cell -Report $report `
    -CellId "mjcal0_contract_and_predecessor_boundary"
$adequacyCell = Get-Cell -Report $report -CellId "mjcal1_adequacy_formula"
$planCell = Get-Cell -Report $report -CellId "mjcal2_plan_compilation"
$positiveCell = Get-Cell -Report $report `
    -CellId "mjcal3_positive_calibration_projection"
$negativeCell = Get-Cell -Report $report `
    -CellId "mjcal4_negative_calibration_retention"
$heldoutCell = Get-Cell -Report $report `
    -CellId "mjcal5_disjoint_heldout_freeze"
$mutationCell = Get-Cell -Report $report `
    -CellId "mjcal6_mutation_and_leakage_controls"
$authorityCell = Get-Cell -Report $report -CellId "mjcal7_authority_boundary"
Assert-MjcalEvidence (
    [string]$boundaryCell["contract_raw_sha256"] -ceq
        [string]$contract["git_blob_raw_sha256"] -and
    [string]$boundaryCell["predecessor_contract_raw_sha256"] -ceq
        [string]$contract["predecessor_contract_raw_sha256"] -and
    -not [bool]$boundaryCell["production_plan_exists"] -and
    [int]$adequacyCell["minimum_unique_condition_groups"] -eq 59 -and
    [double]$adequacyCell["coverage_probability"] -eq 0.95 -and
    [double]$adequacyCell["confidence_probability"] -eq 0.95 -and
    [bool]$adequacyCell["condition_level_familywise_outcome"] -and
    [string]$planCell["plan_sha256"] -ceq
        [string]$reportBinding["fixture_plan_sha256"] -and
    [int]$planCell["calibration_condition_count"] -eq 59 -and
    [int]$planCell["heldout_condition_count"] -eq 59 -and
    [int]$planCell["metric_count"] -eq 5
) "predecessor, adequacy, or fixture-plan binding changed"
Assert-MjcalEvidence (
    [string]$positiveCell["classification"] -ceq
        "valid_complete_positive_resolvable_calibration_fixture" -and
    [bool]$positiveCell["all_metrics_resolvable"] -and
    -not [bool]$positiveCell["production_margin_authority"] -and
    [string]$negativeCell["classification"] -ceq
        "valid_complete_negative_unresolvable_calibration_fixture" -and
    [bool]$negativeCell["negative_result_retained"] -and
    -not [bool]$negativeCell["margin_widened"] -and
    [int]$heldoutCell["heldout_condition_count"] -eq 59 -and
    -not [bool]$heldoutCell["heldout_results_observed"] -and
    -not [bool]$heldoutCell["production_freeze"]
) "positive, negative, or held-out fixture semantics changed"

$rejectedMutations = $mutationCell["rejected_mutations"]
Assert-MjcalEvidence (
    [int]$mutationCell["mutation_control_count"] -eq
        $expectedMutations.Count -and
    $rejectedMutations.Count -eq $expectedMutations.Count
) "mutation-control count changed"
foreach ($mutation in $expectedMutations) {
    Assert-MjcalEvidence (
        $rejectedMutations.ContainsKey($mutation) -and
        [bool]$rejectedMutations[$mutation]
    ) "required mutation was not rejected: $mutation"
}

Assert-MjcalEvidence (
    [bool]$report["positive_and_negative_calibration_fixtures_retained"] -and
    [bool]$report["fixture_only"] -and
    -not [bool]$report["physics_state_modified"] -and
    [bool]$authorityCell["fixture_only"] -and
    -not [bool]$authorityCell["training_plane_authorized"]
) "fixture retention or zero-physics boundary changed"
Assert-MjcalEvidence (
    [bool]$manifest["positive_and_negative_calibration_fixtures_retained"] -and
    [bool]$manifest["fixture_only"]
) "manifest omitted the evidenced finite fixture boundary"
foreach ($authority in $authorityFields) {
    Assert-MjcalEvidence (
        -not [bool]$manifest[$authority] -and
        -not [bool]$report[$authority]
    ) "manifest or report authority became true: $authority"
}
Assert-MjcalEvidence (
    -not [bool]$authorityCell["production_plan_frozen"] -and
    -not [bool]$authorityCell["calibration_executed"] -and
    -not [bool]$authorityCell["production_margins_frozen"] -and
    -not [bool]$authorityCell["heldout_execution_authorized"] -and
    -not [bool]$authorityCell["training_plane_authorized"] -and
    -not [bool]$authorityCell["scientific_result"] -and
    -not [bool]$authorityCell["physical_acceptance_authority"] -and
    -not [bool]$authorityCell["release_authority"]
) "terminal authority cell exceeded source-development scope"

Write-Host (
    "MJWARP_CALIBRATION_EVIDENCE_PASS source=daca133 cells=8 " +
    "mutations=15 calibration_min=59 heldout_min=59 models=0 steps=0 " +
    "attempts=0 worlds=0 plan=false calibration=false margins=false " +
    "heldout=false subset=false training=false"
)
