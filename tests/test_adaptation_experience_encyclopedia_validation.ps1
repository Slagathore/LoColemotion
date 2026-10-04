#requires -Version 7.0

[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = [System.IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$manifestPath = Join-Path $repoRoot `
    "sdk\adaptation_provider\experience_encyclopedia_validation_manifest.json"
$expectedRoot = "C:\Users\Cole\CodeStuff\games\LoColemotion"
$expectedRemote = "https://github.com/Slagathore/LoColemotion.git"
$expectedSource = "ac20bcdbca7d3f76fa01f2024f44d062c298ade7"
$resultClasses = @("positive", "negative", "rejected", "invalid", "incomplete")

function Assert-AecEvidence([bool]$Condition, [string]$Message) {
    if (-not $Condition) {
        throw "ADAPTATION_EXPERIENCE_EVIDENCE $Message"
    }
}

function Get-GitBlobBytes {
    param(
        [Parameter(Mandatory = $true)][string]$Commit,
        [Parameter(Mandatory = $true)][string]$RepoRelativePath
    )

    $objectId = (& git -C $repoRoot rev-parse "$Commit`:$RepoRelativePath").Trim()
    Assert-AecEvidence ($LASTEXITCODE -eq 0) `
        "cannot resolve frozen Git blob: $RepoRelativePath"

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
        Assert-AecEvidence ($process.ExitCode -eq 0) `
            "cannot read frozen Git blob $RepoRelativePath`: $errorText"
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

Assert-AecEvidence (
    [System.IO.Path]::GetFullPath($repoRoot).TrimEnd("\") -ceq
        $expectedRoot.TrimEnd("\")
) "repository root differs from the canonical checkout"
$actualRoot = (& git -C $repoRoot rev-parse --show-toplevel).Trim()
$actualRemote = (& git -C $repoRoot remote get-url origin).Trim()
Assert-AecEvidence ($LASTEXITCODE -eq 0) "repository identity query failed"
Assert-AecEvidence (
    $actualRoot.Replace("/", "\").TrimEnd("\") -ceq
        $expectedRoot.TrimEnd("\") -and
    $actualRemote -ceq $expectedRemote
) "repository root or origin remote changed"
Assert-AecEvidence (Test-Path -LiteralPath $manifestPath -PathType Leaf) `
    "validation manifest is missing"

$manifest = Get-Content -LiteralPath $manifestPath -Raw |
    ConvertFrom-Json -AsHashtable -Depth 64
Assert-AecEvidence (
    [string]$manifest["schema_version"] -ceq
        "sporespore_adaptation_experience_encyclopedia_validation_manifest_v1" -and
    [string]$manifest["status"] -ceq "accepted_zero_world_source_conformance" -and
    [string]$manifest["question_class"] -ceq "development" -and
    [string]$manifest["release_gate_id"] -ceq "none" -and
    [string]$manifest["source_commit"] -ceq $expectedSource -and
    [string]$manifest["source_remote"] -ceq "origin/main" -and
    [bool]$manifest["source_clean"] -and
    [bool]$manifest["source_matches_origin_main"]
) "manifest identity or frozen source boundary changed"

& git -C $repoRoot cat-file -e "$expectedSource^{commit}"
Assert-AecEvidence ($LASTEXITCODE -eq 0) "frozen source commit is unavailable"

$frozenFiles = @($manifest["implementation"]) + @($manifest["contract"])
Assert-AecEvidence ($frozenFiles.Count -eq 6) `
    "manifest must bind exactly six frozen source files"
foreach ($binding in $frozenFiles) {
    $path = [string]$binding["path"]
    Assert-AecEvidence (
        $path -cmatch "^sdk/[A-Za-z0-9_./-]+$" -and
        -not $path.Contains("..", [StringComparison]::Ordinal)
    ) "frozen source path is not repository-relative: $path"
    $bytes = Get-GitBlobBytes -Commit $expectedSource -RepoRelativePath $path
    Assert-AecEvidence (
        $bytes.Length -eq [int]$binding["byte_length"] -and
        (Get-ByteSha256 $bytes) -ceq [string]$binding["git_blob_raw_sha256"]
    ) "frozen Git blob identity changed: $path"
}

$contract = $manifest["contract"]
Assert-AecEvidence (
    [string]$contract["contract_id"] -ceq
        "sporespore_deterministic_online_characterization_and_append_only_experience_v1" -and
    [string]$contract["canonical_sha256"] -ceq
        "sha256:f31d676d59f5a6c8ffe7c522c860bdaaf8f56ed671ca2a828aeaa837c049d390"
) "contract identity or canonical digest changed"

$reportBinding = $manifest["report"]
$reportPath = [string]$reportBinding["path"]
Assert-AecEvidence (
    $reportPath.StartsWith(
        "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence\",
        [StringComparison]::Ordinal
    ) -and
    (Test-Path -LiteralPath $reportPath -PathType Leaf)
) "retained report is absent from the deliberate evidence root"
$reportBytes = [System.IO.File]::ReadAllBytes($reportPath)
Assert-AecEvidence (
    $reportBytes.Length -eq [int]$reportBinding["byte_length"] -and
    (Get-ByteSha256 $reportBytes) -ceq [string]$reportBinding["sha256"]
) "retained report bytes changed"
$report = [System.Text.Encoding]::UTF8.GetString($reportBytes) |
    ConvertFrom-Json -AsHashtable -Depth 64

Assert-AecEvidence (
    [string]$report["schema_version"] -ceq
        [string]$reportBinding["schema_version"] -and
    [bool]$report["ok"] -and
    [string]$report["contract_id"] -ceq [string]$contract["contract_id"] -and
    [string]$report["source"]["commit"] -ceq $expectedSource -and
    [string]$report["source"]["origin_main"] -ceq $expectedSource -and
    [bool]$report["source"]["clean"] -and
    [bool]$report["source"]["matches_origin_main"] -and
    @($report["source"]["status_entries"]).Count -eq 0
) "report is not bound to the exact clean pushed source"
Assert-AecEvidence (
    [int]$report["passed_cells"] -eq [int]$reportBinding["passed_cells"] -and
    [int]$report["failed_cells"] -eq [int]$reportBinding["failed_cells"] -and
    [int]$report["mutation_control_count"] -eq
        [int]$reportBinding["mutation_control_count"] -and
    [int]$report["world_build_count"] -eq [int]$reportBinding["world_build_count"] -and
    @($report["cells"]).Count -eq 8 -and
    @($report["cells"] | Where-Object { -not [bool]$_['passed'] }).Count -eq 0 -and
    @($report["cells"] | Where-Object { [int]$_['world_build_count'] -ne 0 }).Count -eq 0
) "report cell, mutation, or zero-world totals changed"

$retentionCell = @($report["cells"] | Where-Object {
    [string]$_['cell_id'] -ceq "aec3_append_all_result_classes"
})
Assert-AecEvidence ($retentionCell.Count -eq 1) `
    "finite result-class retention cell is missing or duplicated"
foreach ($resultClass in $resultClasses) {
    Assert-AecEvidence (
        [int]$retentionCell[0]["result_counts"][$resultClass] -eq 1
    ) "result class was not retained exactly once: $resultClass"
}

$characterizationCell = @($report["cells"] | Where-Object {
    [string]$_['cell_id'] -ceq "aec1_deterministic_characterization"
})
$characterizationControls = @($report["cells"] | Where-Object {
    [string]$_['cell_id'] -ceq "aec2_characterization_negative_controls"
})
$appendControls = @($report["cells"] | Where-Object {
    [string]$_['cell_id'] -ceq "aec4_duplicate_and_stale_parent_refusal"
})
$mutationControls = @($report["cells"] | Where-Object {
    [string]$_['cell_id'] -ceq "aec5_event_and_object_mutation_controls"
})
$incompleteControl = @($report["cells"] | Where-Object {
    [string]$_['cell_id'] -ceq "aec6_incomplete_store_retention"
})
$authorityCell = @($report["cells"] | Where-Object {
    [string]$_['cell_id'] -ceq "aec7_authority_boundary"
})
Assert-AecEvidence (
    $characterizationCell.Count -eq 1 -and
    -not [bool]$characterizationCell[0]["thresholds_applied"] -and
    -not [bool]$characterizationCell[0]["outcome_classified"] -and
    $characterizationControls.Count -eq 1 -and
    [bool]$characterizationControls[0]["rejected_mutations"]["unknown_field"] -and
    [bool]$characterizationControls[0]["rejected_mutations"]["nonfinite"] -and
    [bool]$characterizationControls[0]["rejected_mutations"]["reordered"] -and
    $appendControls.Count -eq 1 -and
    [bool]$appendControls[0]["duplicate_rejected"] -and
    [bool]$appendControls[0]["stale_parent_rejected"] -and
    [bool]$appendControls[0]["store_unchanged"] -and
    $mutationControls.Count -eq 1 -and
    [bool]$mutationControls[0]["event_mutation_rejected"] -and
    [bool]$mutationControls[0]["object_mutation_rejected"] -and
    [bool]$mutationControls[0]["embedded_binding_mutation_rejected"] -and
    $incompleteControl.Count -eq 1 -and
    [int]$incompleteControl[0]["orphan_object_count"] -eq 1 -and
    [bool]$incompleteControl[0]["incomplete_append_rejected"] -and
    $authorityCell.Count -eq 1 -and
    [bool]$authorityCell[0]["candidate_only"] -and
    -not [bool]$authorityCell[0]["training_data_authority"] -and
    -not [bool]$authorityCell[0]["encyclopedia_promotion_authority"] -and
    -not [bool]$authorityCell[0]["scientific_result"] -and
    -not [bool]$authorityCell[0]["physical_acceptance_authority"] -and
    -not [bool]$authorityCell[0]["release_authority"]
) "threshold-free characterization or candidate-only authority changed"

Assert-AecEvidence (
    [bool]$report["deterministic_online_characterization_implemented"] -and
    [bool]$report["append_only_experience_store_implemented"] -and
    [bool]$report["positive_negative_rejected_invalid_incomplete_retained"] -and
    [bool]$report["self_contained_experience_objects"] -and
    -not [bool]$report["training_data_authority"] -and
    -not [bool]$report["encyclopedia_promotion_authority"] -and
    -not [bool]$report["scientific_result"] -and
    -not [bool]$report["physics_state_modified"] -and
    -not [bool]$report["physical_acceptance_authority"] -and
    -not [bool]$report["release_authority"]
) "report exceeded its source-development claim boundary"
Assert-AecEvidence (
    [bool]$manifest["deterministic_online_characterization_implemented"] -and
    [bool]$manifest["append_only_experience_store_implemented"] -and
    [bool]$manifest["self_contained_experience_objects"] -and
    [bool]$manifest["positive_negative_rejected_invalid_incomplete_retained"]
) "manifest omitted an evidenced source-development capability"
foreach ($authority in @(
    "training_data_authority",
    "encyclopedia_promotion_authority",
    "scientific_result",
    "physical_acceptance_authority",
    "release_authority"
)) {
    Assert-AecEvidence (-not [bool]$manifest[$authority]) `
        "manifest authority became true: $authority"
}

Write-Host (
    "ADAPTATION_EXPERIENCE_EVIDENCE_OK " +
    "source=$expectedSource passed=8 failed=0 mutations=9 worlds=0 " +
    "result_classes=5 authority=source_development_only"
)
