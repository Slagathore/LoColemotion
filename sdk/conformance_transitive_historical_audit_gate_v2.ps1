#requires -Version 7.0

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$contractPath = Join-Path $PSScriptRoot (
    "conformance_transitive_historical_audit_contract_v2.json"
)
$predecessorContractPath = Join-Path $PSScriptRoot (
    "conformance_transitive_historical_audit_contract_v1.json"
)
$predecessorClosurePath = Join-Path $PSScriptRoot (
    "conformance_transitive_historical_audit_tha1_closure_v1.json"
)
$artifactStorePath = Join-Path $PSScriptRoot "content_addressed_artifact_store.ps1"
$runnerPath = Join-Path $PSScriptRoot "run_conformance.ps1"

function Assert-Tha2 {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw "THA2 transitive audit failed: $Message" }
}

function Get-Tha2RawSha256 {
    param([Parameter(Mandatory)][string]$Path)
    return "sha256:" + (
        Get-FileHash -LiteralPath $Path -Algorithm SHA256
    ).Hash.ToLowerInvariant()
}

function Get-Tha2LiteralCount {
    param([string]$Text, [string]$Literal)
    return [Text.RegularExpressions.Regex]::Matches(
        $Text,
        [Text.RegularExpressions.Regex]::Escape($Literal),
        [Text.RegularExpressions.RegexOptions]::CultureInvariant
    ).Count
}

function Test-Tha2BoundHash {
    param([string]$Actual, [string]$Expected)
    return $Actual -ceq $Expected
}

function Get-Tha2RegistryBlock {
    param([Collections.IDictionary]$Contract)
    $lines = [Collections.Generic.List[string]]::new()
    $lines.Add('$transitiveHistoricalAuditCoverageRegistry = @(')
    $paths = @($Contract.declaration_only_coverage_registry.audit_paths)
    for ($index = 0; $index -lt $paths.Count; $index += 1) {
        $suffix = if ($index -lt ($paths.Count - 1)) { ',' } else { '' }
        $lines.Add(
            '    "' + ([string]$paths[$index]).Replace('/', '\') + '"' + $suffix
        )
    }
    $lines.Add(')')
    return $lines -join "`n"
}

function Test-Tha2RunnerProjection {
    param(
        [Parameter(Mandatory)][string]$Source,
        [Parameter(Mandatory)][Collections.IDictionary]$Contract
    )
    $normalized = $Source.Replace("`r`n", "`n")
    $tokens = $null
    $errors = $null
    [void][Management.Automation.Language.Parser]::ParseInput(
        $normalized, [ref]$tokens, [ref]$errors
    )
    if (@($errors).Count -ne 0) {
        return $false
    }
    $registry = $Contract.declaration_only_coverage_registry
    $expectedBlock = Get-Tha2RegistryBlock -Contract $Contract
    if (-not $normalized.Contains($expectedBlock, [StringComparison]::Ordinal)) {
        return $false
    }
    $variableToken = '$' + [string]$registry.runner_variable
    if ((Get-Tha2LiteralCount -Text $normalized -Literal $variableToken) -ne 1) {
        return $false
    }
    $blockStart = $normalized.IndexOf($expectedBlock, [StringComparison]::Ordinal)
    $actualBlock = $normalized.Substring($blockStart, $expectedBlock.Length)
    foreach ($forbidden in @('&', '|', 'pwsh', '-File', 'ForEach-Object')) {
        if ($actualBlock.Contains($forbidden, [StringComparison]::Ordinal)) {
            return $false
        }
    }
    foreach ($path in @($registry.audit_paths)) {
        $windowsPath = ([string]$path).Replace('/', '\')
        if ((Get-Tha2LiteralCount -Text $normalized -Literal $windowsPath) -ne 1) {
            return $false
        }
    }
    $rootPath = ([string]$Contract.canonical_root.audit_path).Replace('/', '\')
    if ((Get-Tha2LiteralCount -Text $normalized -Literal $rootPath) -ne 1) {
        return $false
    }
    if ((Get-Tha2LiteralCount -Text $normalized -Literal (
        'tests\test_bw20f_material_characterization_closure.ps1'
    )) -ne 1) {
        return $false
    }
    if ((Get-Tha2LiteralCount -Text $normalized -Literal (
        'sdk\conformance_transitive_historical_audit_gate_v2.ps1'
    )) -ne 1) {
        return $false
    }
    if ($normalized.Contains(
        'tests\test_conformance_transitive_historical_audit.ps1',
        [StringComparison]::Ordinal
    )) {
        return $false
    }
    return $true
}

foreach ($path in @(
    $contractPath,
    $predecessorContractPath,
    $predecessorClosurePath,
    $artifactStorePath,
    $runnerPath
)) {
    Assert-Tha2 (Test-Path -LiteralPath $path -PathType Leaf) "missing input: $path"
}
. $artifactStorePath

$contract = Get-Content -LiteralPath $contractPath -Raw |
    ConvertFrom-Json -AsHashtable -Depth 100
$predecessorClosure = Get-Content -LiteralPath $predecessorClosurePath -Raw |
    ConvertFrom-Json -AsHashtable -Depth 100
$runnerSource = Get-Content -LiteralPath $runnerPath -Raw
$runnerTokens = $null
$runnerErrors = $null
[void][Management.Automation.Language.Parser]::ParseInput(
    $runnerSource, [ref]$runnerTokens, [ref]$runnerErrors
)
Assert-Tha2 (@($runnerErrors).Count -eq 0) "canonical runner does not parse"

Assert-Tha2 (
    [string]$contract.schema_version -ceq
        "sporespore_conformance_transitive_historical_audit_contract_v2" -and
    [string]$contract.contract_id -ceq
        "THA2-MATERIAL-PUBLICATION-VERIFIER-AWARE-TRANSITIVE-EXECUTION" -and
    [string]$contract.status -ceq
        "prospective_verifier_aware_transitive_execution_uncommissioned" -and
    [string]$predecessorClosure.status -ceq
        "closed_negative_legacy_verifier_incompatible" -and
    -not [bool]$contract.claims.transitive_execution_commissioned -and
    -not [bool]$contract.claims.historical_audit_waiver_permitted -and
    -not [bool]$contract.claims.production_cache_lookup_permitted -and
    -not [bool]$contract.claims.production_result_reuse_permitted -and
    -not [bool]$contract.claims.physical_execution_authorized -and
    -not [bool]$contract.claims.scientific_locomotion_authority -and
    -not [bool]$contract.claims.release_authority
) "contract, predecessor, or authority identity changed"

Assert-Tha2 (
    (Get-Tha2RawSha256 $predecessorContractPath) -ceq
        [string]$contract.predecessor.contract_raw_sha256 -and
    (Get-Tha2RawSha256 $predecessorClosurePath) -ceq
        [string]$contract.predecessor.closure_raw_sha256
) "predecessor contract or closure bytes changed"

$evidenceRoot = Get-SporeSporeArtifactEvidenceRoot -RepoRoot $repoRoot
$negativeReceiptSha = [string]$contract.predecessor.eligible_negative_receipt_sha256
$negativeReceiptHex = $negativeReceiptSha.Substring(7)
$negativeReceiptDirectory = Join-Path $evidenceRoot "artifacts\sha256\$negativeReceiptHex"
Assert-Tha2 (Test-SporeSporeStoredArtifact `
    -Directory $negativeReceiptDirectory `
    -ExpectedSha256 $negativeReceiptHex `
    -ExpectedByteLength 14623) "eligible THA1 negative receipt CAS failed"
$negativeReceiptPath = Join-Path $negativeReceiptDirectory "payload.bin"
$negativeReceipt = Get-Content -LiteralPath $negativeReceiptPath -Raw |
    ConvertFrom-Json -AsHashtable -Depth 100
Assert-Tha2 (
    [string]$negativeReceipt.run_id -ceq
        [string]$contract.predecessor.eligible_negative_run_id -and
    [string]$negativeReceipt.status -ceq "failed" -and
    [string]$negativeReceipt.tier -ceq "canonical_no_godot" -and
    [bool]$negativeReceipt.skip_godot -and
    [double]$negativeReceipt.duration_seconds -eq 1165.9176374 -and
    [string]$negativeReceipt.failure.message -ceq
        "BW27P material-profile closure audit failed with exit code 1" -and
    @($negativeReceipt.stage_receipts).Count -eq 4 -and
    -not [bool]$negativeReceipt.claims.physical_campaign_executed -and
    -not [bool]$negativeReceipt.claims.release_authority
) "eligible THA1 negative receipt changed"

$bindingByPath = [Collections.Generic.Dictionary[string, object]]::new(
    [StringComparer]::Ordinal
)
foreach ($binding in @($contract.graph_source_bindings)) {
    Assert-Tha2 ($bindingByPath.TryAdd([string]$binding.path, $binding)) (
        "duplicate graph source binding: $($binding.path)"
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
Assert-Tha2 (
    $graphSources.Count -eq 8 -and $bindingByPath.Count -eq 8
) "transitive graph or binding cardinality changed"
foreach ($relativePath in $graphSources) {
    $binding = $null
    Assert-Tha2 ($bindingByPath.TryGetValue($relativePath, [ref]$binding)) (
        "missing graph source binding: $relativePath"
    )
    $absolutePath = Join-Path $repoRoot $relativePath
    Assert-Tha2 (
        (Test-Path -LiteralPath $absolutePath -PathType Leaf) -and
        (Get-Tha2RawSha256 $absolutePath) -ceq [string]$binding.raw_sha256
    ) "graph audit bytes changed: $relativePath"
}

$edgeBindings = @(
    [ordered]@{
        parent = "tests/test_bw27p_material_profile_publication_closure.ps1"
        children = @(
            [ordered]@{ path = "tests/test_bw27m_material_characterization_closure.ps1"; variable = '$characterizationClosureAuditPath' },
            [ordered]@{ path = "tests/test_bw24p_material_profile_publication_closure.ps1"; variable = '$priorProfileClosureAuditPath' }
        )
    },
    [ordered]@{
        parent = "tests/test_bw24p_material_profile_publication_closure.ps1"
        children = @(
            [ordered]@{ path = "tests/test_bw24m_material_profile_publication_closure.ps1"; variable = '$predecessorClosureAuditPath' },
            [ordered]@{ path = "tests/test_bw24m_material_characterization_closure.ps1"; variable = '$characterizationClosureAuditPath' }
        )
    },
    [ordered]@{
        parent = "tests/test_bw24m_material_profile_publication_closure.ps1"
        children = @(
            [ordered]@{ path = "tests/test_bw24m_material_characterization_closure.ps1"; variable = '$characterizationClosureAuditPath' },
            [ordered]@{ path = "tests/test_bw22m_material_profile_publication_closure.ps1"; variable = '$priorProfileClosureAuditPath' }
        )
    },
    [ordered]@{
        parent = "tests/test_bw22m_material_profile_publication_closure.ps1"
        children = @(
            [ordered]@{ path = "tests/test_bw22m_material_characterization_closure.ps1"; variable = '$characterizationClosureAuditPath' },
            [ordered]@{ path = "tests/test_bw20f_material_profile_publication_closure.ps1"; variable = '$priorProfileClosureAuditPath' }
        )
    }
)
foreach ($binding in $edgeBindings) {
    $source = Get-Content -LiteralPath (Join-Path $repoRoot $binding.parent) -Raw
    $positions = [Collections.Generic.List[int]]::new()
    foreach ($child in $binding.children) {
        $pathLeaf = Split-Path -Leaf ([string]$child.path)
        $pathPosition = $source.IndexOf($pathLeaf, [StringComparison]::Ordinal)
        $invokePosition = $source.IndexOf(
            "-File $($child.variable)", [StringComparison]::Ordinal
        )
        Assert-Tha2 (
            $pathPosition -ge 0 -and $invokePosition -gt $pathPosition
        ) "child binding or execution disappeared: $($binding.parent) -> $($child.path)"
        $positions.Add($invokePosition)
    }
    Assert-Tha2 ($positions[0] -lt $positions[1]) (
        "declared child execution order changed: $($binding.parent)"
    )
}
$leafSource = Get-Content -LiteralPath (
    Join-Path $repoRoot "tests/test_bw20f_material_profile_publication_closure.ps1"
) -Raw
Assert-Tha2 (
    -not $leafSource.Contains("ClosureAuditPath", [StringComparison]::Ordinal)
) "declared BW20F publication leaf gained an unmodeled closure child"

$witness = $contract.retained_cap1_witness
$profileRunRoot = Join-Path $evidenceRoot (
    "conformance-audit-profiles\" + [string]$witness.profile_run_id
)
$profilePath = Join-Path $profileRunRoot "profile.json"
$profile = Get-Content -LiteralPath $profilePath -Raw |
    ConvertFrom-Json -AsHashtable -Depth 100
$matchingReceipts = @($profile.receipts | Where-Object {
    [string]$_.audit_path -ceq [string]$contract.canonical_root.audit_path
})
Assert-Tha2 (
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
Assert-Tha2 (
    (Test-Path -LiteralPath $stdoutPath -PathType Leaf) -and
    (Get-Tha2RawSha256 $stdoutPath) -ceq [string]$witness.stdout_sha256 -and
    (Get-Item -LiteralPath $stdoutPath).Length -eq [long]$witness.stdout_byte_length
) "retained CAP1 root stdout changed"
$stdoutHex = ([string]$witness.stdout_sha256).Substring(7)
Assert-Tha2 (Test-SporeSporeStoredArtifact `
    -Directory (Join-Path $evidenceRoot "artifacts\sha256\$stdoutHex") `
    -ExpectedSha256 $stdoutHex `
    -ExpectedByteLength ([long]$witness.stdout_byte_length)) (
    "retained CAP1 root stdout CAS failed"
)
$stdoutLines = @(Get-Content -LiteralPath $stdoutPath)
$prefixes = @($witness.ordered_terminal_prefixes)
Assert-Tha2 (
    $stdoutLines.Count -eq [int]$contract.canonical_root.expected_terminal_marker_count -and
    $prefixes.Count -eq $stdoutLines.Count
) "retained marker cardinality changed"
for ($index = 0; $index -lt $prefixes.Count; $index += 1) {
    Assert-Tha2 ($stdoutLines[$index].StartsWith(
        [string]$prefixes[$index], [StringComparison]::Ordinal
    )) "retained terminal marker order changed at index $index"
}

Assert-Tha2 (
    @($contract.declaration_only_coverage_registry.audit_paths).Count -eq 7 -and
    [bool]$contract.declaration_only_coverage_registry.must_never_be_read_or_executed -and
    (Test-Tha2RunnerProjection -Source $runnerSource -Contract $contract)
) "canonical runner registry or execution projection changed"

$registryPaths = @($contract.declaration_only_coverage_registry.audit_paths)
$firstWindowsPath = ([string]$registryPaths[0]).Replace('/', '\')
$secondWindowsPath = ([string]$registryPaths[1]).Replace('/', '\')
$registryBlock = Get-Tha2RegistryBlock -Contract $contract
$normalizedRunner = $runnerSource.Replace("`r`n", "`n")
$mutations = [ordered]@{
    missing_registry_entry = $normalizedRunner.Replace(
        "    `"$firstWindowsPath`",`n", ""
    )
    reordered_registry_entry = $normalizedRunner.Replace(
        "    `"$firstWindowsPath`",`n    `"$secondWindowsPath`",",
        "    `"$secondWindowsPath`",`n    `"$firstWindowsPath`","
    )
    duplicate_registry_path = $normalizedRunner.Replace(
        "    `"$secondWindowsPath`",", "    `"$firstWindowsPath`"," 
    )
    registry_variable_second_reference = $normalizedRunner +
        "`n`$transitiveHistoricalAuditCoverageRegistry | Out-Null`n"
    registry_block_execution_token = $normalizedRunner.Replace(
        $registryBlock,
        $registryBlock.Replace("`n)", "`n    & pwsh`n)")
    )
    root_path_missing = $normalizedRunner.Replace(
        ([string]$contract.canonical_root.audit_path).Replace('/', '\'), "root-removed"
    )
    root_path_duplicate = $normalizedRunner + "`n# " +
        ([string]$contract.canonical_root.audit_path).Replace('/', '\')
    runner_syntax_error = $normalizedRunner + "`n@(`n"
}
foreach ($entry in $mutations.GetEnumerator()) {
    Assert-Tha2 (-not (Test-Tha2RunnerProjection `
        -Source ([string]$entry.Value) `
        -Contract $contract)) "negative control survived: $($entry.Key)"
}
$firstBinding = @($contract.graph_source_bindings)[0]
$actualFirstBindingHash = Get-Tha2RawSha256 (
    Join-Path $repoRoot ([string]$firstBinding.path)
)
Assert-Tha2 (-not (Test-Tha2BoundHash `
    -Actual $actualFirstBindingHash `
    -Expected (([string]$firstBinding.raw_sha256).Substring(0, 70) + "0"))) (
    "graph source hash mutation survived"
)
Assert-Tha2 (-not (Test-Tha2BoundHash `
    -Actual $negativeReceiptSha `
    -Expected ($negativeReceiptSha.Substring(0, 70) + "0"))) (
    "predecessor receipt hash mutation survived"
)

Assert-Tha2 (
    @($contract.negative_controls).Count -eq 10 -and
    [bool]$contract.prospective_performance_hypothesis.estimate_is_not_acceptance -and
    [bool]$contract.prospective_performance_hypothesis.complete_clean_serialized_successor_measurement_required
) "negative-control or performance-acceptance boundary changed"

Write-Output (
    "CONFORMANCE_TRANSITIVE_HISTORICAL_AUDIT_V2_PASS root=bw27p " +
    "unique_audits=8 markers=10 registry=7 declaration_only=True " +
    "predecessor_negative=True negative_controls=10 waiver=False cache=disabled " +
    "worlds=0 physical_authority=False release_authority=False"
)
