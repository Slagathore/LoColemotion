#requires -Version 7.0

[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$sdkRoot = Join-Path $repoRoot "sdk"
$incidentPath = Join-Path `
    $sdkRoot "locomotion_campaign_attestation_v1_first_cold_comparison_incident.json"
$artifactStorePath = Join-Path $sdkRoot "content_addressed_artifact_store.ps1"

. $artifactStorePath

function Assert-Lca1Incident([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "LCA1_FIRST_COLD_COMPARISON $Message" }
}

function Get-Lca1IncidentSha256([string]$Path) {
    return "sha256:" + (
        Get-FileHash -LiteralPath $Path -Algorithm SHA256
    ).Hash.ToLowerInvariant()
}

function Assert-Lca1IncidentArtifact([hashtable]$Artifact) {
    $path = [string]$Artifact.path
    Assert-Lca1Incident (Test-Path -LiteralPath $path -PathType Leaf) `
        "retained artifact is missing: $path"
    $item = Get-Item -LiteralPath $path
    Assert-Lca1Incident (
        [long]$item.Length -eq [long]$Artifact.byte_length -and
        (Get-Lca1IncidentSha256 $path) -ceq [string]$Artifact.raw_sha256
    ) "retained artifact bytes changed: $path"
    if ([bool]$Artifact.cas_required) {
        $digest = ([string]$Artifact.raw_sha256).Substring(7)
        $artifactRoot = Join-Path (
            Get-SporeSporeArtifactEvidenceRoot -RepoRoot $repoRoot
        ) "artifacts\sha256"
        Assert-Lca1Incident (
            Test-SporeSporeStoredArtifact `
                -Directory (Join-Path $artifactRoot $digest) `
                -ExpectedSha256 $digest `
                -ExpectedByteLength ([long]$Artifact.byte_length)
        ) "retained CAS object changed: $digest"
    }
}

Assert-Lca1Incident (
    (git -C $repoRoot rev-parse --show-toplevel).Replace("/", "\") -ceq
        $repoRoot -and
    (git -C $repoRoot remote get-url origin) -ceq
        "https://github.com/Slagathore/sporespore.git"
) "repository identity mismatch"
Assert-Lca1Incident (Test-Path -LiteralPath $incidentPath -PathType Leaf) `
    "incident declaration is missing"

$incident = Get-Content -LiteralPath $incidentPath -Raw |
    ConvertFrom-Json -AsHashtable -Depth 100
$source = $incident.observed_source_identity
$full = $incident.cold_full_v2
$scoped = $incident.cold_scoped_lca1
$comparison = $incident.comparison
Assert-Lca1Incident (
    [string]$incident.schema_version -ceq
        "sporespore_locomotion_campaign_attestation_commissioning_incident_v1" -and
    [string]$incident.status -ceq
        "closed_negative_full_runner_missing_three_campaign_role_execution_edges" -and
    [string]$source.commit -ceq
        "1f2f71364cbe5d65ab4246211ed09804611a7493" -and
    [string]$source.tree_git_oid -ceq
        "cb3486e9cdef4c950468108fa3bb163b4d7a7e72" -and
    (git -C $repoRoot rev-parse (
        ([string]$source.commit) + "^{tree}"
    )) -ceq [string]$source.tree_git_oid
) "incident or exact source identity changed"

Assert-Lca1IncidentArtifact $full.attestation
Assert-Lca1IncidentArtifact $full.run_receipt
Assert-Lca1IncidentArtifact $full.full_log
Assert-Lca1IncidentArtifact $scoped.attestation

$fullReceipt = Get-Content -LiteralPath ([string]$full.run_receipt.path) -Raw |
    ConvertFrom-Json -AsHashtable -Depth 100
$fullAttestation = Get-Content -LiteralPath ([string]$full.attestation.path) -Raw |
    ConvertFrom-Json -AsHashtable -Depth 100
$scopedAttestation = Get-Content -LiteralPath ([string]$scoped.attestation.path) -Raw |
    ConvertFrom-Json -AsHashtable -Depth 100
Assert-Lca1Incident (
    [string]$fullReceipt.status -ceq "passed" -and
    [string]$fullReceipt.source.head -ceq [string]$source.commit -and
    [string]$fullReceipt.source.head_tree -ceq [string]$source.tree_git_oid -and
    [double]$fullReceipt.duration_seconds -eq [double]$full.duration_seconds -and
    [string]$fullAttestation.source.commit -ceq [string]$source.commit -and
    [string]$scopedAttestation.source.commit -ceq [string]$source.commit -and
    [string]$scopedAttestation.source.tree_git_oid -ceq [string]$source.tree_git_oid -and
    [int]$scopedAttestation.global_gate_count -eq 12 -and
    [int]$scopedAttestation.lineage_gate_count -eq 1 -and
    [int]$scopedAttestation.campaign_gate_count -eq 3 -and
    [int]$scopedAttestation.executed_gate_count -eq 16 -and
    [bool]$scopedAttestation.all_gates_executed -and
    [bool]$scopedAttestation.all_gate_streams_content_addressed -and
    -not [bool]$scopedAttestation.commissioned
) "retained cold-run identity or status changed"

$markers = @(
    "QSDK_R23D17_CLOSURE_PASS",
    "LCA1_COMMISSIONING_WORKER_PASS",
    "LCA1_COMMISSIONING_EVALUATOR_PASS",
    "LCA1_COMMISSIONING_SUPERVISOR_PASS"
)
$fullLogText = Get-Content -LiteralPath ([string]$full.full_log.path) -Raw
foreach ($marker in $markers) {
    $fullCount = [regex]::Matches(
        $fullLogText,
        [regex]::Escape($marker)
    ).Count
    Assert-Lca1Incident (
        $fullCount -eq [int]$full.terminal_marker_counts[$marker]
    ) "full transcript marker count changed: $marker"
    $scopedCount = @($scopedAttestation.gate_receipts | Where-Object {
        [string]$_.terminal_marker_prefix -ceq ($marker + " ") -and
        [int]$_.terminal_marker_count -eq 1 -and
        [bool]$_.passed
    }).Count
    Assert-Lca1Incident (
        $scopedCount -eq [int]$scoped.terminal_marker_counts[$marker]
    ) "scoped transcript marker count changed: $marker"
}

Assert-Lca1Incident (
    [bool]$comparison.same_source -and
    [int]$comparison.required_subset_marker_count -eq 4 -and
    [int]$comparison.matching_marker_count -eq 1 -and
    @($comparison.missing_full_runner_markers).Count -eq 3 -and
    [string]$comparison.failure_class -ceq
        "full_runner_campaign_role_execution_edges_absent" -and
    -not [bool]$comparison.commissioning_passed -and
    -not [bool]$comparison.physical_launch_prerequisite_satisfied -and
    [bool]$incident.interpretation.process_commissioning_failure -and
    -not [bool]$incident.interpretation.physics_failure -and
    -not [bool]$incident.interpretation.scientific_failure -and
    -not [bool]$incident.interpretation.physical_rerun_authorized_by_incident -and
    @($incident.claims.GetEnumerator() | Where-Object { [bool]$_.Value }).Count -eq 0
) "negative interpretation or zero-claim boundary changed"

Write-Host (
    "LCA1_FIRST_COLD_COMPARISON_INCIDENT_PASS source=$($source.commit) " +
    "full_seconds=$($full.duration_seconds) scoped_seconds=$($scoped.duration_seconds) " +
    "required_markers=4 matched=1 missing_role_edges=3 worlds=0 " +
    "commissioned=False physical_prerequisite=False physical_authority=False"
)
