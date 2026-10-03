#requires -Version 7.0

param(
    [switch]$VerifyInventory,
    [switch]$UpdateInventory
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$testsRoot = Join-Path $repoRoot "tests"
$inventoryPath = Join-Path $PSScriptRoot "closure_evidence_mode_inventory.json"
$contractPath = Join-Path $PSScriptRoot "closure_evidence_provenance_contract.json"

function Assert-Exact([bool]$Condition, [string]$Message) {
    if (-not $Condition) {
        throw $Message
    }
}

Assert-Exact (
    -not ($VerifyInventory -and $UpdateInventory)
) "Specify at most one of -VerifyInventory or -UpdateInventory"

function Get-RawSha256([string]$Path) {
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Test-SourcePattern([string]$Text, [string]$Pattern) {
    return [regex]::IsMatch(
        $Text,
        $Pattern,
        [Text.RegularExpressions.RegexOptions]::IgnoreCase -bor
            [Text.RegularExpressions.RegexOptions]::CultureInvariant
    )
}

Assert-Exact (
    (git -C $repoRoot rev-parse --show-toplevel).Trim() -ceq
        $repoRoot.Replace("\", "/") -and
    (git -C $repoRoot remote get-url origin).Trim() -ceq
        "https://github.com/Slagathore/sporespore.git" -and
    (Test-Path -LiteralPath $contractPath -PathType Leaf)
) "Closure evidence-mode inventory repository or contract identity changed"

$auditFiles = @(
    Get-ChildItem -LiteralPath $testsRoot -Filter "*.ps1" -File |
        Where-Object {
            ($_.Name -match "closure" -or $_.Name -match "closed") -and
            $_.Name -cne "test_closure_evidence_provenance_contract.ps1"
        } |
        Sort-Object Name
)

$entries = [System.Collections.Generic.List[object]]::new()
foreach ($file in $auditFiles) {
    $text = Get-Content -LiteralPath $file.FullName -Raw
    $relativePath = [IO.Path]::GetRelativePath($repoRoot, $file.FullName).
        Replace("\", "/")

    $casPathCheck = Test-SourcePattern $text (
        "artifacts[\\/]+sha256|retained[_ -]?cas|content.addressed"
    )
    $pinnedGitBlob = Test-SourcePattern $text (
        'Get-(?:Spore)?GitBlobBytes|Get-GitBlob(?:RawSha256|Utf8Text)|' +
        'cat-file[\s\S]{0,80}blob|' +
        'rev-parse[\s\S]{0,160}\$\{?(?:sourceCommit|physicalSourceCommit|posthocSourceCommit)\}?[^\r\n]*:|' +
        'ls-tree[\s\S]{0,160}\$\{?(?:sourceCommit|physicalSourceCommit|posthocSourceCommit)\}?|' +
        'git[\s\S]{0,80}show[\s\S]{0,160}:[^\s]'
    )
    $reconstructedCheckout = Test-SourcePattern $text (
        "Convert-LfToCrLfBytes|Test-HistoricalRawReceipt|" +
        "reconstruct[a-z_-]*checkout|filter[_ -]?state[_ -]?receipt"
    )
    $retainedEvidence = Test-SourcePattern $text (
        "SporeSpore_Evidence|evidenceRoot|retained[_ -]?evidence"
    )
    $hashesRepoCheckout = (
        (Test-SourcePattern $text "Get-FileHash|Get-RawSha256|hash-object") -and
        (Test-SourcePattern $text "repoRoot|sdkRoot|PSScriptRoot")
    )
    $boundInventory = Test-SourcePattern $text (
        "bound_source_inventory|source_bindings|source_inventory|" +
        "bound_sources|frozen_source"
    )
    $liveHistoricalRisk = (
        $boundInventory -and
        $hashesRepoCheckout -and
        -not $pinnedGitBlob
    ) -or (Test-SourcePattern $text (
        'current bytes no longer match the executed source|' +
        'Get-RawSha256[^\r\n]*\$absolutePath|' +
        'Get-FileHash[^\r\n]*\$absolutePath'
    ))
    $runtimeSafetyLiveCheck = Test-SourcePattern $text (
        "current refusal runner|same-identity[^\r\n]*refus|" +
        "rerun[^\r\n]*refus"
    )

    $modes = [System.Collections.Generic.List[string]]::new()
    if ($casPathCheck) { $modes.Add("cas_path_check") }
    if ($pinnedGitBlob) { $modes.Add("pinned_git_blob") }
    if ($reconstructedCheckout) { $modes.Add("reconstructed_checkout") }
    if ($retainedEvidence) { $modes.Add("retained_evidence_bytes") }
    if ($hashesRepoCheckout) { $modes.Add("live_repo_or_checkout_hash") }
    if ($runtimeSafetyLiveCheck) { $modes.Add("live_runtime_safety_check") }
    if ($modes.Count -eq 0) { $modes.Add("record_only_or_unclassified") }

    $historicalIdentityMode = if ($pinnedGitBlob -and $reconstructedCheckout) {
        "pinned_git_blob_with_checkout_reconstruction"
    } elseif ($pinnedGitBlob) {
        "pinned_git_blob"
    } elseif ($liveHistoricalRisk) {
        "legacy_live_path_or_checkout_hash"
    } else {
        "record_retained_evidence_or_manual_review"
    }

    $entries.Add([ordered]@{
        path = $relativePath
        raw_sha256 = Get-RawSha256 $file.FullName
        historical_identity_mode = $historicalIdentityMode
        detected_modes = @($modes)
        live_historical_identity_risk = $liveHistoricalRisk
        manual_review_required = (
            $liveHistoricalRisk -or
            $historicalIdentityMode -ceq
                "record_retained_evidence_or_manual_review"
        )
    })
}

$inventory = [ordered]@{
    schema_version = "sporespore_closure_evidence_mode_inventory_v1"
    analyzer_version = "sporespore_closure_evidence_mode_static_analyzer_v2"
    contract_path = "sdk/closure_evidence_provenance_contract.json"
    scope = "PowerShell closure and closed-experiment audits under tests"
    classification_boundary = (
        "Mechanical source-signature baseline. Multiple modes may apply. " +
        "manual_review_required remains true where static evidence cannot prove " +
        "that a live hash is closure-self/runtime safety rather than historical identity."
    )
    audit_count = $entries.Count
    cas_path_check_signature_count = @(
        $entries | Where-Object { $_.detected_modes -contains "cas_path_check" }
    ).Count
    pinned_git_blob_signature_count = @(
        $entries | Where-Object { $_.detected_modes -contains "pinned_git_blob" }
    ).Count
    reconstructed_checkout_signature_count = @(
        $entries | Where-Object { $_.detected_modes -contains "reconstructed_checkout" }
    ).Count
    live_historical_identity_risk_count = @(
        $entries | Where-Object { [bool]$_.live_historical_identity_risk }
    ).Count
    manual_review_required_count = @(
        $entries | Where-Object { [bool]$_.manual_review_required }
    ).Count
    entries = @($entries)
    world_build_count = 0
    historical_campaign_reclassification_authorized = $false
    physical_execution_authorized = $false
    physical_acceptance_authority = $false
}

$serialized = $inventory | ConvertTo-Json -Depth 10
if ($UpdateInventory) {
    $portableSerialized = $serialized.Replace("`r`n", "`n")
    [IO.File]::WriteAllText(
        $inventoryPath,
        $portableSerialized + "`n",
        [Text.UTF8Encoding]::new($false)
    )
} elseif ($VerifyInventory) {
    Assert-Exact (Test-Path -LiteralPath $inventoryPath -PathType Leaf) (
        "Closure evidence-mode retained inventory is missing"
    )
    $expected = Get-Content -LiteralPath $inventoryPath -Raw |
        ConvertFrom-Json -AsHashtable -Depth 100
    $expectedSerialized = $expected | ConvertTo-Json -Depth 10
    Assert-Exact ($serialized -ceq $expectedSerialized) (
        "Closure evidence-mode inventory drifted; regenerate and review the complete classification"
    )
}

Write-Output $serialized
Write-Host (
    "CLOSURE_EVIDENCE_MODE_INVENTORY_PASS audits=$($inventory.audit_count) " +
    "cas_path_checks=$($inventory.cas_path_check_signature_count) " +
    "git_blob=$($inventory.pinned_git_blob_signature_count) " +
    "reconstructed_checkout=$($inventory.reconstructed_checkout_signature_count) " +
    "live_risk=$($inventory.live_historical_identity_risk_count) " +
    "manual_review=$($inventory.manual_review_required_count) worlds=0 physical_authority=False"
)
