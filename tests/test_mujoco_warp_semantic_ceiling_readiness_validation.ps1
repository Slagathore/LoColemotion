#requires -Version 7.0

[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = [System.IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$manifestPath = Join-Path $repoRoot (
    "sdk\adaptation_provider\" +
    "mujoco_warp_semantic_ceiling_readiness_validation_manifest.json"
)
$expectedRoot = "C:\Users\Cole\CodeStuff\games\SporeSpore"
$expectedRemote = "https://github.com/Slagathore/sporespore.git"
$expectedSource = "faaf057ad6379ba66ec1a4425f479082f28cb1b6"
$expectedContractHash = (
    "sha256:eddc0afaabdafd483319007384cb5184e3fae792a74ae19002dd2b982caa1ceb"
)
$expectedPredecessorHash = (
    "sha256:c38f26211882f3349266f7381fcc5dc34acc9b20e5485d3b18d7f1185c35e374"
)
$expectedPredecessorManifestHash = (
    "sha256:d1d3cd016574bca53fbe1447832b3104e5495c7f5de6f63fd9b2b01d3d6d485a"
)
$expectedReportPath = (
    "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence\" +
    "mujoco-warp-semantic-ceiling-readiness-faaf057\report.json"
)
$expectedReportHash = (
    "sha256:8102f0cbc8153f724d408ea4fc0393dfdb226b4a70c8521fb9e7b45b6be4b3fe"
)
$expectedCells = @(
    "mjsc0_contract_and_predecessor_boundary",
    "mjsc1_current_incomplete_inventory",
    "mjsc2_positive_fixture_compilation",
    "mjsc3_content_binding_controls",
    "mjsc4_chronology_and_outcome_controls",
    "mjsc5_unit_scope_and_invariance_controls",
    "mjsc6_mutation_controls",
    "mjsc7_authority_boundary"
)
$expectedMutations = @(
    "unknown_field",
    "duplicate_metric",
    "disallowed_semantic_source",
    "wrong_unit",
    "nonfinite_ceiling",
    "nonpositive_ceiling",
    "fractional_discrete_ceiling",
    "source_digest_mutation",
    "source_length_mutation",
    "source_path_escape",
    "source_bytes_missing",
    "source_locator_mutation",
    "source_bound_value_mutation",
    "unavailable_production_git_blob",
    "postoutcome_source",
    "calibration_outcome_source",
    "heldout_outcome_source",
    "historical_physics_outcome_source",
    "fixture_role_mismatch",
    "fixture_leak_to_production",
    "broad_population_claim",
    "missing_invariance",
    "missing_adequacy_argument",
    "metric_coverage_incomplete",
    "freeze_authority_injection"
)
$authorityFields = @(
    "production_semantic_ceiling_sources_complete",
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
$expectedBindings = @{
    "sdk/adaptation_provider/mujoco_warp_semantic_ceiling_readiness_contract_v1.json" = @{
        hash = $expectedContractHash
        length = 8108
    }
    "sdk/adaptation_provider/mujoco_warp_semantic_ceiling_readiness.py" = @{
        hash = "sha256:1bd9b75e3651589dc18d5722322a4b89fa12df1889d25b5be3beaa66c06cdb89"
        length = 25331
    }
    "sdk/adaptation_provider/mujoco_warp_semantic_ceiling_readiness_conformance.py" = @{
        hash = "sha256:91503860bef6a1f7bacbc90becfcf2f6efad043d58bdc6965df2ee7b4b0b2967"
        length = 22897
    }
    "sdk/adaptation_provider/test_mujoco_warp_semantic_ceiling_readiness.py" = @{
        hash = "sha256:b888999fcc0eb936931f7760761a1a61e74279fb4276d7508b1d9b38ad7f9877"
        length = 2557
    }
    "sdk/run_mujoco_warp_semantic_ceiling_readiness_conformance.ps1" = @{
        hash = "sha256:ad3965fcf9ab00767d91f9b5f0149e83d86b13d5106e3b04884f37f20ba427d1"
        length = 4943
    }
}

function Assert-MjscEvidence([bool]$Condition, [string]$Message) {
    if (-not $Condition) {
        throw "MJWARP_SEMANTIC_CEILING_EVIDENCE $Message"
    }
}

function Get-GitBlobBytes {
    param(
        [Parameter(Mandatory = $true)][string]$Commit,
        [Parameter(Mandatory = $true)][string]$RepoRelativePath
    )

    $objectId = (& git -C $repoRoot rev-parse "$Commit`:$RepoRelativePath").Trim()
    Assert-MjscEvidence ($LASTEXITCODE -eq 0) (
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
        Assert-MjscEvidence ($process.ExitCode -eq 0) (
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
    Assert-MjscEvidence ($matches.Count -eq 1) (
        "report cell is missing or duplicated: $CellId"
    )
    return $matches[0]
}

Assert-MjscEvidence (
    [System.IO.Path]::GetFullPath($repoRoot).TrimEnd("\") -ceq
        $expectedRoot.TrimEnd("\")
) "repository root differs from the canonical checkout"
$actualRoot = (& git -C $repoRoot rev-parse --show-toplevel).Trim()
$actualRemote = (& git -C $repoRoot remote get-url origin).Trim()
Assert-MjscEvidence ($LASTEXITCODE -eq 0) "repository identity query failed"
Assert-MjscEvidence (
    $actualRoot.Replace("/", "\").TrimEnd("\") -ceq
        $expectedRoot.TrimEnd("\") -and
    $actualRemote -ceq $expectedRemote
) "repository root or origin remote changed"
Assert-MjscEvidence (Test-Path -LiteralPath $manifestPath -PathType Leaf) (
    "validation manifest is missing"
)

$manifest = Get-Content -LiteralPath $manifestPath -Raw |
    ConvertFrom-Json -AsHashtable -Depth 64
Assert-MjscEvidence (
    [string]$manifest["schema_version"] -ceq
        "sporespore_mujoco_warp_semantic_ceiling_readiness_validation_manifest_v1" -and
    [string]$manifest["status"] -ceq "accepted_zero_world_source_conformance" -and
    [string]$manifest["question_class"] -ceq "development" -and
    [string]$manifest["release_gate_id"] -ceq "none" -and
    [string]$manifest["source_commit"] -ceq $expectedSource -and
    [string]$manifest["source_remote"] -ceq "origin/main" -and
    [bool]$manifest["source_clean"] -and
    [bool]$manifest["source_matches_origin_main"]
) "manifest identity or frozen source boundary changed"

& git -C $repoRoot cat-file -e "$expectedSource^{commit}"
Assert-MjscEvidence ($LASTEXITCODE -eq 0) "frozen source commit is unavailable"
& git -C $repoRoot merge-base --is-ancestor $expectedSource origin/main
Assert-MjscEvidence ($LASTEXITCODE -eq 0) (
    "frozen source commit is not on the origin/main lineage"
)

$frozenFiles = @($manifest["implementation"]) + @($manifest["contract"])
Assert-MjscEvidence ($frozenFiles.Count -eq $expectedBindings.Count) (
    "manifest must bind exactly five frozen source files"
)
$observedPaths = @{}
foreach ($binding in $frozenFiles) {
    $path = [string]$binding["path"]
    Assert-MjscEvidence (
        $path -cmatch "^sdk/[A-Za-z0-9_./-]+$" -and
        -not $path.Contains("..", [StringComparison]::Ordinal) -and
        $expectedBindings.ContainsKey($path) -and
        -not $observedPaths.ContainsKey($path)
    ) "frozen source path is unexpected or duplicated: $path"
    $observedPaths[$path] = $true
    $expected = $expectedBindings[$path]
    Assert-MjscEvidence (
        [int]$binding["byte_length"] -eq [int]$expected["length"] -and
        [string]$binding["git_blob_raw_sha256"] -ceq [string]$expected["hash"]
    ) "manifest source binding changed: $path"
    $bytes = Get-GitBlobBytes -Commit $expectedSource -RepoRelativePath $path
    Assert-MjscEvidence (
        $bytes.Length -eq [int]$expected["length"] -and
        (Get-ByteSha256 $bytes) -ceq [string]$expected["hash"]
    ) "frozen Git blob identity changed: $path"
}
Assert-MjscEvidence ($observedPaths.Count -eq $expectedBindings.Count) (
    "manifest source coverage is incomplete"
)

$contract = $manifest["contract"]
Assert-MjscEvidence (
    [string]$contract["contract_id"] -ceq
        "sporespore_mujoco_warp_precalibration_semantic_ceiling_readiness_v1" -and
    [string]$contract["git_blob_raw_sha256"] -ceq $expectedContractHash -and
    [string]$contract["predecessor_contract_raw_sha256"] -ceq
        $expectedPredecessorHash -and
    [string]$contract["predecessor_validation_manifest_raw_sha256"] -ceq
        $expectedPredecessorManifestHash
) "contract or immutable predecessor identity changed"

$reportBinding = $manifest["report"]
$reportPath = [string]$reportBinding["path"]
Assert-MjscEvidence (
    $reportPath -ceq $expectedReportPath -and
    $reportPath.StartsWith(
        "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence\",
        [StringComparison]::Ordinal
    ) -and
    (Test-Path -LiteralPath $reportPath -PathType Leaf)
) "retained report is absent from the deliberate evidence root"
Assert-MjscEvidence (
    [string]$reportBinding["sha256"] -ceq $expectedReportHash -and
    [int]$reportBinding["byte_length"] -eq 3926
) "retained report binding changed"
$reportBytes = [System.IO.File]::ReadAllBytes($reportPath)
Assert-MjscEvidence (
    $reportBytes.Length -eq [int]$reportBinding["byte_length"] -and
    (Get-ByteSha256 $reportBytes) -ceq [string]$reportBinding["sha256"]
) "retained report bytes changed"
$report = [System.Text.Encoding]::UTF8.GetString($reportBytes) |
    ConvertFrom-Json -AsHashtable -Depth 64

Assert-MjscEvidence (
    [string]$report["schema_version"] -ceq
        [string]$reportBinding["schema_version"] -and
    [bool]$report["ok"] -and
    [string]$report["contract_id"] -ceq [string]$contract["contract_id"] -and
    [string]$report["contract_raw_sha256"] -ceq $expectedContractHash -and
    [string]$report["source"]["commit"] -ceq $expectedSource -and
    [string]$report["source"]["origin_main"] -ceq $expectedSource -and
    [bool]$report["source"]["clean"] -and
    [bool]$report["source"]["matches_origin_main"] -and
    @($report["source"]["status_entries"]).Count -eq 0
) "report is not bound to the exact clean pushed source"
Assert-MjscEvidence (
    [int]$report["passed_cells"] -eq 8 -and
    [int]$report["passed_cells"] -eq [int]$reportBinding["passed_cells"] -and
    [int]$report["failed_cells"] -eq 0 -and
    [int]$report["failed_cells"] -eq [int]$reportBinding["failed_cells"] -and
    [int]$report["mutation_control_count"] -eq $expectedMutations.Count -and
    [int]$report["mutation_control_count"] -eq
        [int]$reportBinding["mutation_control_count"] -and
    [int]$report["required_metric_count"] -eq 5 -and
    [int]$report["accepted_production_source_count"] -eq 0 -and
    [int]$report["unresolved_metric_count"] -eq 5 -and
    [bool]$report["all_unresolved_reasons_retained"] -and
    [int]$report["positive_fixture_accepted_source_count"] -eq 5 -and
    @($report["cells"]).Count -eq $expectedCells.Count
) "report totals or finite inventory boundary changed"
Assert-MjscEvidence (
    [int]$report["model_construction_count"] -eq 0 -and
    [int]$report["step_invocation_count"] -eq 0 -and
    [int]$report["world_attempt_count"] -eq 0 -and
    [int]$report["world_build_count"] -eq 0 -and
    -not [bool]$report["physics_state_modified"]
) "report exceeded its zero-world source-only boundary"
for ($index = 0; $index -lt $expectedCells.Count; $index++) {
    $cell = $report["cells"][$index]
    Assert-MjscEvidence (
        [string]$cell["cell_id"] -ceq $expectedCells[$index] -and
        [bool]$cell["passed"] -and
        [int]$cell["world_build_count"] -eq 0 -and
        -not [bool]$cell["physical_acceptance_authority"]
    ) "report cell order, result, or zero-world boundary changed at index $index"
}

$boundaryCell = Get-Cell -Report $report `
    -CellId "mjsc0_contract_and_predecessor_boundary"
$currentCell = Get-Cell -Report $report `
    -CellId "mjsc1_current_incomplete_inventory"
$fixtureCell = Get-Cell -Report $report `
    -CellId "mjsc2_positive_fixture_compilation"
$contentCell = Get-Cell -Report $report `
    -CellId "mjsc3_content_binding_controls"
$chronologyCell = Get-Cell -Report $report `
    -CellId "mjsc4_chronology_and_outcome_controls"
$adequacyCell = Get-Cell -Report $report `
    -CellId "mjsc5_unit_scope_and_invariance_controls"
$mutationCell = Get-Cell -Report $report -CellId "mjsc6_mutation_controls"
$authorityCell = Get-Cell -Report $report -CellId "mjsc7_authority_boundary"
Assert-MjscEvidence (
    [string]$boundaryCell["contract_raw_sha256"] -ceq $expectedContractHash -and
    [string]$boundaryCell["predecessor_contract_raw_sha256"] -ceq
        $expectedPredecessorHash -and
    -not [bool]$boundaryCell["production_plan_exists"] -and
    [int]$currentCell["accepted_source_count"] -eq 0 -and
    [int]$currentCell["unresolved_metric_count"] -eq 5 -and
    [bool]$currentCell["all_unresolved_reasons_retained"]
) "predecessor or current incomplete inventory binding changed"
Assert-MjscEvidence (
    [int]$fixtureCell["fixture_accepted_source_count"] -eq 5 -and
    [bool]$fixtureCell["compiler_fixture_complete"] -and
    -not [bool]$fixtureCell["production_semantic_ceiling_sources_complete"] -and
    [int]$contentCell["rejected_control_count"] -eq 7 -and
    [int]$chronologyCell["rejected_control_count"] -eq 6 -and
    [int]$adequacyCell["rejected_control_count"] -eq 9
) "fixture-only compiler or mutation-family totals changed"

$rejectedMutations = $mutationCell["rejected_mutations"]
Assert-MjscEvidence (
    [int]$mutationCell["mutation_control_count"] -eq $expectedMutations.Count -and
    $rejectedMutations.Count -eq $expectedMutations.Count
) "mutation-control count changed"
foreach ($mutation in $expectedMutations) {
    Assert-MjscEvidence (
        $rejectedMutations.ContainsKey($mutation) -and
        [bool]$rejectedMutations[$mutation]
    ) "required mutation was not rejected: $mutation"
}

Assert-MjscEvidence (
    [bool]$manifest["all_unresolved_reasons_retained"] -and
    [bool]$manifest["positive_fixture_only"] -and
    [bool]$report["fixture_only"] -and
    [bool]$authorityCell["current_inventory_incomplete"]
) "manifest or report omitted the finite incomplete/fixture boundary"
foreach ($authority in $authorityFields) {
    Assert-MjscEvidence (
        -not [bool]$manifest[$authority] -and
        -not [bool]$report[$authority]
    ) "manifest or report authority became true: $authority"
}
Assert-MjscEvidence (
    -not [bool]$authorityCell["production_plan_frozen"] -and
    -not [bool]$authorityCell["production_margins_frozen"] -and
    -not [bool]$authorityCell["calibration_authorized"] -and
    -not [bool]$authorityCell["heldout_qualification_authorized"] -and
    -not [bool]$authorityCell["supported_physics_subset_qualified"] -and
    -not [bool]$authorityCell["training_plane_authorized"] -and
    -not [bool]$authorityCell["scientific_result"] -and
    -not [bool]$authorityCell["physical_acceptance_authority"] -and
    -not [bool]$authorityCell["release_authority"]
) "terminal authority cell exceeded source-development scope"

Write-Host (
    "MJWARP_SEMANTIC_CEILING_EVIDENCE_PASS source=faaf057 cells=8 " +
    "mutations=25 required=5 accepted=0 unresolved=5 fixture_accepted=5 " +
    "models=0 steps=0 attempts=0 worlds=0 plan=false calibration=false " +
    "margins=false heldout=false subset=false training=false"
)
