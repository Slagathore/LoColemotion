#requires -Version 7.0

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$incidentPath = Join-Path $repoRoot (
    "sdk\turning\r23d32_pre_attestation_checkout_filter_incident_v1.json"
)

function Assert-Incident([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "QSDK-R23D32 PRE-ATTESTATION INCIDENT: $Message" }
}

function Get-Sha256([string]$Path) {
    return "sha256:" + (
        Get-FileHash -Algorithm SHA256 -LiteralPath $Path
    ).Hash.ToLowerInvariant()
}

$incident = Get-Content -Raw -LiteralPath $incidentPath |
    ConvertFrom-Json -AsHashtable -Depth 100
Assert-Incident (
    [string]$incident.status -ceq "closed_pre_physics_infrastructure_invalid" -and
    [string]$incident.failed_source_commit -ceq
        "95a73d9a54310a8117891de95583727a28a0c6a5" -and
    [string]$incident.failed_gate_receipt.gate_id -ceq
        "CAK1-EVIDENCE-PROVENANCE" -and
    [int]$incident.failed_gate_receipt.ordinal -eq 4 -and
    [int]$incident.failed_gate_receipt.exit_code -eq 1 -and
    -not [bool]$incident.failed_gate_receipt.timed_out -and
    [string]$incident.mechanism.classification -ceq
        "prospective_source_provenance_boundary_violation" -and
    -not [bool]$incident.mechanism.scientific_question_changed -and
    -not [bool]$incident.mechanism.controller_changed -and
    -not [bool]$incident.mechanism.measurement_changed -and
    -not [bool]$incident.mechanism.threshold_changed -and
    [int]$incident.execution.physical_process_launch_count -eq 0 -and
    [int]$incident.execution.model_construction_count -eq 0 -and
    [int]$incident.execution.world_attempt_count -eq 0 -and
    [int]$incident.execution.world_build_count -eq 0 -and
    -not [bool]$incident.execution.one_shot_physical_identity_consumed -and
    [bool]$incident.resolution.remove_nonessential_r23d32_gitattributes_rule -and
    [bool]$incident.resolution.git_blob_exact_source_materialization_remains_required -and
    -not [bool]$incident.resolution.failed_attestation_may_authorize_corrected_source -and
    -not [bool]$incident.claims.scientific_result -and
    -not [bool]$incident.claims.physical_acceptance_authority
) "incident boundary changed"

foreach ($binding in @(
    $incident.failure_receipt,
    $incident.failed_gate_receipt,
    $incident.failure_excerpt
)) {
    $path = [string]$binding.path
    Assert-Incident (Test-Path -LiteralPath $path -PathType Leaf) (
        "retained evidence missing: $path"
    )
    Assert-Incident ((Get-Sha256 $path) -ceq [string]$binding.sha256) (
        "retained evidence hash changed: $path"
    )
    Assert-Incident ((Get-Item -LiteralPath $path).Length -eq [long]$binding.byte_length) (
        "retained evidence length changed: $path"
    )
}

Write-Host (
    "QSDK_R23D32_PRE_ATTESTATION_INCIDENT_PASS failed_commit=95a73d9 " +
    "failed_gate=4 worlds=0 identity_consumed=False physical=False"
)
