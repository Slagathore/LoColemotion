#requires -Version 7.0

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$sdkRoot = Join-Path $repoRoot "sdk"
$contractPath = Join-Path $sdkRoot (
    "conformance_transitive_historical_audit_contract_v1.json"
)
$inventoryPath = Join-Path $sdkRoot "closure_evidence_mode_inventory.json"
$artifactStorePath = Join-Path $sdkRoot "content_addressed_artifact_store.ps1"
$runnerPath = Join-Path $sdkRoot "run_conformance.ps1"

function Assert-Tha1 {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw "THA1 transitive audit failed: $Message" }
}

foreach ($path in @(
    $contractPath, $inventoryPath, $artifactStorePath, $runnerPath
)) {
    Assert-Tha1 (Test-Path -LiteralPath $path -PathType Leaf) (
        "missing input: $path"
    )
}
. $artifactStorePath

$contract = Get-Content -LiteralPath $contractPath -Raw |
    ConvertFrom-Json -AsHashtable -Depth 64
$inventory = Get-Content -LiteralPath $inventoryPath -Raw |
    ConvertFrom-Json -AsHashtable -Depth 32
$runnerSource = Get-Content -LiteralPath $runnerPath -Raw
Assert-Tha1 (
    [string]$contract.schema_version -ceq
        "sporespore_conformance_transitive_historical_audit_contract_v1" -and
    [string]$contract.status -ceq
        "prospective_duplicate_top_level_execution_removal_uncommissioned" -and
    [string]$contract.classification -ceq
        "zero_world_conformance_execution_graph_optimization" -and
    [int]$contract.canonical_root.world_build_count -eq 0 -and
    [int]$contract.canonical_root.expected_unique_audit_count -eq 8 -and
    [int]$contract.canonical_root.expected_terminal_marker_count -eq 10 -and
    @($contract.direct_invocations_removed_from_canonical_runner).Count -eq 7 -and
    @($contract.direct_invocations_retained).Count -eq 2 -and
    -not [bool]$contract.claims.transitive_execution_commissioned -and
    -not [bool]$contract.claims.historical_audit_waiver_permitted -and
    -not [bool]$contract.claims.production_cache_lookup_permitted -and
    -not [bool]$contract.claims.production_result_reuse_permitted -and
    -not [bool]$contract.claims.physical_execution_authorized -and
    -not [bool]$contract.claims.scientific_locomotion_authority -and
    -not [bool]$contract.claims.release_authority -and
    $runnerSource.Contains(
        "tests\test_conformance_transitive_historical_audit.ps1",
        [StringComparison]::Ordinal
    )
) "contract identity, cardinality, authority, or canonical binding changed"

$inventoryByPath = [Collections.Generic.Dictionary[string, object]]::new(
    [StringComparer]::Ordinal
)
foreach ($entry in @($inventory.entries)) {
    Assert-Tha1 ($inventoryByPath.TryAdd([string]$entry.path, $entry)) (
        "CEP1 contains a duplicate path"
    )
}

$graphSources = [Collections.Generic.HashSet[string]]::new(
    [StringComparer]::Ordinal
)
foreach ($edge in @($contract.transitive_graph)) {
    [void]$graphSources.Add([string]$edge.parent)
    foreach ($child in @($edge.ordered_children)) {
        [void]$graphSources.Add([string]$child)
    }
}
Assert-Tha1 ($graphSources.Count -eq 8) "transitive graph unique audit count changed"
foreach ($relativePath in $graphSources) {
    $entry = $null
    Assert-Tha1 ($inventoryByPath.TryGetValue($relativePath, [ref]$entry)) (
        "graph audit is absent from CEP1: $relativePath"
    )
    $absolutePath = Join-Path $repoRoot $relativePath
    Assert-Tha1 (
        (Test-Path -LiteralPath $absolutePath -PathType Leaf) -and
        (Get-FileHash -LiteralPath $absolutePath -Algorithm SHA256).
            Hash.ToLowerInvariant() -ceq [string]$entry.raw_sha256
    ) "graph audit bytes differ from CEP1: $relativePath"
}

$edgeBindings = @(
    [ordered]@{
        parent = "tests/test_bw27p_material_profile_publication_closure.ps1"
        children = @(
            [ordered]@{
                path = "tests/test_bw27m_material_characterization_closure.ps1"
                variable = '$characterizationClosureAuditPath'
            },
            [ordered]@{
                path = "tests/test_bw24p_material_profile_publication_closure.ps1"
                variable = '$priorProfileClosureAuditPath'
            }
        )
    },
    [ordered]@{
        parent = "tests/test_bw24p_material_profile_publication_closure.ps1"
        children = @(
            [ordered]@{
                path = "tests/test_bw24m_material_profile_publication_closure.ps1"
                variable = '$predecessorClosureAuditPath'
            },
            [ordered]@{
                path = "tests/test_bw24m_material_characterization_closure.ps1"
                variable = '$characterizationClosureAuditPath'
            }
        )
    },
    [ordered]@{
        parent = "tests/test_bw24m_material_profile_publication_closure.ps1"
        children = @(
            [ordered]@{
                path = "tests/test_bw24m_material_characterization_closure.ps1"
                variable = '$characterizationClosureAuditPath'
            },
            [ordered]@{
                path = "tests/test_bw22m_material_profile_publication_closure.ps1"
                variable = '$priorProfileClosureAuditPath'
            }
        )
    },
    [ordered]@{
        parent = "tests/test_bw22m_material_profile_publication_closure.ps1"
        children = @(
            [ordered]@{
                path = "tests/test_bw22m_material_characterization_closure.ps1"
                variable = '$characterizationClosureAuditPath'
            },
            [ordered]@{
                path = "tests/test_bw20f_material_profile_publication_closure.ps1"
                variable = '$priorProfileClosureAuditPath'
            }
        )
    }
)
foreach ($binding in $edgeBindings) {
    $source = Get-Content -LiteralPath (Join-Path $repoRoot $binding.parent) -Raw
    $positions = [Collections.Generic.List[int]]::new()
    foreach ($child in $binding.children) {
        $pathLeaf = Split-Path -Leaf ([string]$child.path)
        $pathPosition = $source.IndexOf($pathLeaf, [StringComparison]::Ordinal)
        $invokeText = "-File $($child.variable)"
        $invokePosition = $source.IndexOf($invokeText, [StringComparison]::Ordinal)
        Assert-Tha1 (
            $pathPosition -ge 0 -and $invokePosition -gt $pathPosition
        ) "child binding or execution disappeared: $($binding.parent) -> $($child.path)"
        $positions.Add($invokePosition)
    }
    Assert-Tha1 ($positions[0] -lt $positions[1]) (
        "declared child execution order changed: $($binding.parent)"
    )
}
$leafSource = Get-Content -LiteralPath (
    Join-Path $repoRoot "tests/test_bw20f_material_profile_publication_closure.ps1"
) -Raw
Assert-Tha1 (
    -not $leafSource.Contains("ClosureAuditPath", [StringComparison]::Ordinal)
) "declared BW20F publication leaf gained an unmodeled closure child"

function Get-Tha1LiteralCount {
    param([string]$Text, [string]$Literal)
    return [Text.RegularExpressions.Regex]::Matches(
        $Text,
        [Text.RegularExpressions.Regex]::Escape($Literal),
        [Text.RegularExpressions.RegexOptions]::CultureInvariant
    ).Count
}

foreach ($removed in @($contract.direct_invocations_removed_from_canonical_runner)) {
    $windowsPath = ([string]$removed.audit_path).Replace('/', '\')
    Assert-Tha1 ((Get-Tha1LiteralCount -Text $runnerSource -Literal $windowsPath) -eq 0) (
        "canonical runner still directly names removed descendant: $windowsPath"
    )
}
$rootWindowsPath = ([string]$contract.canonical_root.audit_path).Replace('/', '\')
Assert-Tha1 (
    (Get-Tha1LiteralCount -Text $runnerSource -Literal $rootWindowsPath) -eq 1 -and
    (Get-Tha1LiteralCount -Text $runnerSource -Literal (
        "tests\test_bw20f_material_characterization_closure.ps1"
    )) -eq 1 -and
    $runnerSource.Contains(
        "BW27P material-profile closure audit failed with exit code",
        [StringComparison]::Ordinal
    )
) "canonical root/retained audit count or fail-closed root handling changed"

$witness = $contract.retained_cap1_witness
$evidenceRoot = Get-SporeSporeArtifactEvidenceRoot -RepoRoot $repoRoot
$profileRunRoot = Join-Path $evidenceRoot (
    "conformance-audit-profiles\" + [string]$witness.profile_run_id
)
$profilePath = Join-Path $profileRunRoot "profile.json"
$profile = Get-Content -LiteralPath $profilePath -Raw |
    ConvertFrom-Json -AsHashtable -Depth 64
$matchingReceipts = @($profile.receipts | Where-Object {
    [string]$_.audit_path -ceq [string]$contract.canonical_root.audit_path
})
Assert-Tha1 (
    $matchingReceipts.Count -eq 1 -and
    [int]$matchingReceipts[0].ordinal -eq [int]$witness.audit_ordinal -and
    [double]$matchingReceipts[0].duration_seconds -eq
        [double]$witness.audit_duration_seconds -and
    [string]$matchingReceipts[0].stdout_sha256 -ceq
        [string]$witness.stdout_sha256 -and
    [long]$matchingReceipts[0].stdout_byte_length -eq
        [long]$witness.stdout_byte_length -and
    [bool]$matchingReceipts[0].passed
) "retained CAP1 root receipt changed"
$stdoutPath = Join-Path $profileRunRoot (
    "streams\" + ([int]$witness.audit_ordinal).ToString("D3") + "\stdout.txt"
)
Assert-Tha1 (
    (Test-Path -LiteralPath $stdoutPath -PathType Leaf) -and
    (Get-Item -LiteralPath $stdoutPath).Length -eq [long]$witness.stdout_byte_length -and
    ("sha256:" + (Get-FileHash -LiteralPath $stdoutPath -Algorithm SHA256).
        Hash.ToLowerInvariant()) -ceq [string]$witness.stdout_sha256
) "retained CAP1 root stdout changed"
$stdoutHex = ([string]$witness.stdout_sha256).Substring(7)
Assert-Tha1 (Test-SporeSporeStoredArtifact `
    -Directory (Join-Path $evidenceRoot "artifacts\sha256\$stdoutHex") `
    -ExpectedSha256 $stdoutHex `
    -ExpectedByteLength ([long]$witness.stdout_byte_length)) (
    "retained CAP1 root stdout CAS failed"
)
$stdoutLines = @(Get-Content -LiteralPath $stdoutPath)
$prefixes = @($witness.ordered_terminal_prefixes)
Assert-Tha1 (
    $stdoutLines.Count -eq [int]$contract.canonical_root.expected_terminal_marker_count -and
    $prefixes.Count -eq $stdoutLines.Count
) "retained marker cardinality changed"
for ($index = 0; $index -lt $prefixes.Count; $index += 1) {
    Assert-Tha1 ($stdoutLines[$index].StartsWith(
        [string]$prefixes[$index],
        [StringComparison]::Ordinal
    )) "retained terminal marker order changed at index $index"
}

$removedDuration = 0.0
foreach ($removed in @($contract.direct_invocations_removed_from_canonical_runner)) {
    $removedDuration += [double]$removed.cap1_duration_seconds
}
$hypothesis = $contract.prospective_performance_hypothesis
Assert-Tha1 (
    [Math]::Abs(
        $removedDuration -
        [double]$hypothesis.sum_of_removed_standalone_cap1_durations_seconds
    ) -lt 0.000001 -and
    [Math]::Abs(
        ([double]$hypothesis.cap1_baseline_no_godot_seconds - $removedDuration) -
        [double]$hypothesis.estimated_successor_seconds
    ) -lt 0.000001 -and
    [bool]$hypothesis.estimate_is_not_acceptance -and
    [bool]$hypothesis.clean_serialized_successor_measurement_required -and
    [string]$contract.development_mechanism_observation.status -ceq
        "posthoc_read_only_target_characterization_no_acceptance_authority" -and
    [int]$contract.development_mechanism_observation.publication_levels_with_global_recursive_attempt_scan -eq 4 -and
    [bool]$contract.development_mechanism_observation.directory_cache_did_not_remove_scan_tax
) "performance hypothesis or development-only mechanism boundary changed"

Write-Output (
    "CONFORMANCE_TRANSITIVE_HISTORICAL_AUDIT_PASS root=bw27p " +
    "unique_audits=8 markers=10 direct_removed=7 direct_retained=2 " +
    "cap1_removed_seconds=700.392132 estimated_reduction_percent=43.8503891 " +
    "witness_cas=True graph_hashes=True waiver=False cache=disabled worlds=0 " +
    "physical_authority=False release_authority=False"
)
