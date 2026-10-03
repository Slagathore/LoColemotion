#requires -Version 7.0

[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$sdkRoot = Join-Path $repoRoot "sdk"
$incidentPath = Join-Path `
    $sdkRoot "locomotion_campaign_attestation_v1_second_cold_comparison_incident.json"
$artifactStorePath = Join-Path $sdkRoot "content_addressed_artifact_store.ps1"
. $artifactStorePath

function Assert-Lca1Incident2([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "LCA1_SECOND_COLD_COMPARISON $Message" }
}

function Get-Lca1Incident2Sha256([string]$Path) {
    return "sha256:" + (
        Get-FileHash -LiteralPath $Path -Algorithm SHA256
    ).Hash.ToLowerInvariant()
}

function Assert-Lca1Incident2Artifact([hashtable]$Artifact) {
    $path = [string]$Artifact.path
    Assert-Lca1Incident2 (Test-Path -LiteralPath $path -PathType Leaf) `
        "retained artifact is missing: $path"
    Assert-Lca1Incident2 (
        (Get-Item -LiteralPath $path).Length -eq [long]$Artifact.byte_length -and
        (Get-Lca1Incident2Sha256 $path) -ceq [string]$Artifact.raw_sha256
    ) "retained artifact bytes changed: $path"
    if ([bool]$Artifact.cas_required) {
        $digest = ([string]$Artifact.raw_sha256).Substring(7)
        $artifactRoot = Join-Path (
            Get-SporeSporeArtifactEvidenceRoot -RepoRoot $repoRoot
        ) "artifacts\sha256"
        Assert-Lca1Incident2 (
            Test-SporeSporeStoredArtifact `
                -Directory (Join-Path $artifactRoot $digest) `
                -ExpectedSha256 $digest `
                -ExpectedByteLength ([long]$Artifact.byte_length)
        ) "retained CAS object changed: $digest"
    }
}

Assert-Lca1Incident2 (
    (git -C $repoRoot rev-parse --show-toplevel).Replace("/", "\") -ceq
        $repoRoot -and
    (git -C $repoRoot remote get-url origin) -ceq
        "https://github.com/Slagathore/sporespore.git"
) "repository identity mismatch"
$incident = Get-Content -LiteralPath $incidentPath -Raw |
    ConvertFrom-Json -AsHashtable -Depth 100
$source = $incident.observed_source_identity
$full = $incident.cold_full_v2
$scoped = $incident.cold_scoped_lca1
$comparison = $incident.comparison
Assert-Lca1Incident2 (
    [string]$incident.schema_version -ceq
        "sporespore_locomotion_campaign_attestation_commissioning_incident_v1" -and
    [string]$incident.status -ceq
        "closed_negative_native_child_role_markers_absent_from_parent_transcript" -and
    [string]$source.commit -ceq
        "b16dbf3f7a71518c7cb49a6bc313ac02c1e8a4b8" -and
    [string]$source.tree_git_oid -ceq
        "c1c8b57cfa4ea6b75333aba5d64ebd899804db9d" -and
    (git -C $repoRoot rev-parse (([string]$source.commit) + "^{tree}")) -ceq
        [string]$source.tree_git_oid
) "incident or exact source identity changed"

Assert-Lca1Incident2Artifact $full.attestation
Assert-Lca1Incident2Artifact $full.run_receipt
Assert-Lca1Incident2Artifact $full.full_log
$receipt = Get-Content -LiteralPath ([string]$full.run_receipt.path) -Raw |
    ConvertFrom-Json -AsHashtable -Depth 100
$attestation = Get-Content -LiteralPath ([string]$full.attestation.path) -Raw |
    ConvertFrom-Json -AsHashtable -Depth 100
Assert-Lca1Incident2 (
    [string]$receipt.status -ceq "passed" -and
    [string]$receipt.source.head -ceq [string]$source.commit -and
    [string]$receipt.source.head_tree -ceq [string]$source.tree_git_oid -and
    [double]$receipt.duration_seconds -eq [double]$full.duration_seconds -and
    @($receipt.stage_receipts).Count -eq 8 -and
    @($receipt.stage_receipts | Where-Object { $_.status -cne "passed" }).Count -eq 0 -and
    [string]$attestation.source.commit -ceq [string]$source.commit -and
    [string]$attestation.source.tree_git_oid -ceq [string]$source.tree_git_oid
) "retained full-run identity or status changed"

$fullText = Get-Content -LiteralPath ([string]$full.full_log.path) -Raw
foreach ($marker in @(
    "QSDK_R23D17_CLOSURE_PASS",
    "LCA1_COMMISSIONING_WORKER_PASS",
    "LCA1_COMMISSIONING_EVALUATOR_PASS",
    "LCA1_COMMISSIONING_SUPERVISOR_PASS"
)) {
    Assert-Lca1Incident2 (
        [regex]::Matches($fullText, [regex]::Escape($marker)).Count -eq
            [int]$full.terminal_marker_counts[$marker]
    ) "full transcript marker count changed: $marker"
}

Assert-Lca1Incident2 (
    [string]$scoped.status -ceq
        "not_started_after_full_transcript_comparison_failed" -and
    -not [bool]$scoped.attempted -and
    [int]$scoped.physical_worlds_opened -eq 0 -and
    [int]$comparison.required_subset_marker_count -eq 4 -and
    [int]$comparison.matching_full_marker_count -eq 1 -and
    @($comparison.missing_full_runner_markers).Count -eq 3 -and
    [string]$comparison.failure_class -ceq
        "native_child_terminal_markers_not_retained_by_parent_transcript" -and
    -not [bool]$comparison.commissioning_passed -and
    -not [bool]$comparison.physical_launch_prerequisite_satisfied -and
    [bool]$incident.mechanism.source_declared_all_three_role_invocations -and
    [bool]$incident.mechanism.full_run_passed_beyond_role_invocations -and
    -not [bool]$incident.mechanism.retained_role_execution_receipt_exists -and
    -not [bool]$incident.mechanism.physical_rerun_authorized_by_incident -and
    @($incident.claims.GetEnumerator() | Where-Object { [bool]$_.Value }).Count -eq 0
) "negative interpretation or zero-claim boundary changed"

Write-Host (
    "LCA1_SECOND_COLD_COMPARISON_INCIDENT_PASS source=$($source.commit) " +
    "full_seconds=$($full.duration_seconds) stages=8 required_markers=4 matched=1 " +
    "missing_role_markers=3 scoped_started=False worlds=0 commissioned=False " +
    "physical_prerequisite=False physical_authority=False"
)
