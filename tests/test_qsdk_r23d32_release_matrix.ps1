#requires -Version 7.0

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$matrixPath = Join-Path $repoRoot "sdk\release\quadruped_support_matrix.json"
$contractPath = Join-Path $repoRoot "sdk\release\quadruped_release_contract.json"

function Assert-R23D32Matrix([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "QSDK-R23D32 RELEASE MATRIX: $Message" }
}

function Find-NamedJsonProperty($Node, [string]$Name) {
    if ($null -eq $Node -or $Node -is [string]) { return }
    if ($Node -is [pscustomobject]) {
        foreach ($property in $Node.PSObject.Properties) {
            if ($property.Name -ceq $Name) { Write-Output $property.Value }
            Find-NamedJsonProperty $property.Value $Name
        }
        return
    }
    if ($Node -is [System.Collections.IEnumerable]) {
        foreach ($item in $Node) { Find-NamedJsonProperty $item $Name }
    }
}

function Get-Sha256([string]$RelativePath) {
    $path = Join-Path $repoRoot $RelativePath
    Assert-R23D32Matrix (Test-Path -LiteralPath $path -PathType Leaf) (
        "bound path is missing: $RelativePath"
    )
    return "sha256:" + (
        Get-FileHash -Algorithm SHA256 -LiteralPath $path
    ).Hash.ToLowerInvariant()
}

$matrix = Get-Content -Raw -LiteralPath $matrixPath | ConvertFrom-Json -Depth 100
$contract = Get-Content -Raw -LiteralPath $contractPath | ConvertFrom-Json -Depth 100
$matrixRows = @(Find-NamedJsonProperty $matrix "closed_r23d32_attempt")
$contractRows = @(Find-NamedJsonProperty $contract "closed_r23d32_attempt")
Assert-R23D32Matrix ($matrixRows.Count -eq 1 -and $contractRows.Count -eq 1) (
    "expected one closed record in each release authority"
)
$row = $matrixRows[0]
$contractRow = $contractRows[0]
Assert-R23D32Matrix (
    [string]$row.status -ceq
        "closed_valid_complete_positive_finite_rapier_turning_validation" -and
    (Get-Sha256 ([string]$row.preregistration_path)) -ceq
        [string]$row.preregistration_sha256 -and
    (Get-Sha256 ([string]$row.implementation_path)) -ceq
        [string]$row.implementation_sha256 -and
    (Get-Sha256 ([string]$row.closure_path)) -ceq
        [string]$row.closure_sha256 -and
    (Get-Sha256 ([string]$row.closure_audit_path)) -ceq
        [string]$row.closure_audit_sha256 -and
    [int]$row.fresh_seed -eq 21506 -and
    [int]$row.declared_world_count -eq 3 -and
    [string]$row.physical_source_commit -ceq
        "d92ef53681071bb4f25c393dff69004b151901d2" -and
    [string]$row.attempt_id -ceq "4cbefc628ded4863ab712d9d56fff189" -and
    [int]$row.world_attempt_count -eq 3 -and
    [int]$row.world_build_count -eq 3 -and
    [int]$row.execution_valid_cell_count -eq 3 -and
    [int]$row.common_physical_gate_pass_count -eq 3 -and
    [string]$row.failed_attestation_source_commit -ceq
        "95a73d9a54310a8117891de95583727a28a0c6a5" -and
    [int]$row.failed_attestation_world_count -eq 0 -and
    -not [bool]$row.failed_attestation_consumed_physical_identity -and
    -not [bool]$row.controller_behavior_changed -and
    -not [bool]$row.measurement_changed -and
    -not [bool]$row.threshold_changed -and
    [bool]$row.controller_candidate_selected -and
    -not [bool]$row.measurement_candidate_selected -and
    [bool]$row.raw_signed_cycle_shift_gate_passed -and
    [bool]$row.reference_conditioned_cycle_shift_gate_passed -and
    [bool]$row.every_terminal_swing_raw_direction_passed -and
    [bool]$row.every_terminal_swing_reference_conditioned_direction_passed -and
    [int]$row.combined_independently_held_out_positive_fixture_count -eq 2 -and
    (@($row.validated_seed_ids) -join ',') -ceq "21505,21506" -and
    [bool]$row.one_shot_identity_consumed -and
    -not [bool]$row.same_identity_rerun_allowed -and
    [bool]$row.finite_rapier_cycle_integrated_measurement_validation -and
    [bool]$row.finite_rapier_turning_validation -and
    -not [bool]$row.portable_basic_turning -and
    -not [bool]$row.cross_engine_equivalence -and
    -not [bool]$row.physical_acceptance_authority
) "support-matrix prospective boundary changed"
Assert-R23D32Matrix (
    [string]$contractRow.status -ceq
        "closed_valid_complete_positive_finite_rapier_turning_validation" -and
    (Get-Sha256 ([string]$contractRow.closure_path)) -ceq
        [string]$contractRow.closure_raw_sha256 -and
    (Get-Sha256 ([string]$contractRow.closure_audit_path)) -ceq
        [string]$contractRow.closure_audit_raw_sha256 -and
    [int]$contractRow.fresh_seed -eq 21506 -and
    [int]$contractRow.world_attempt_count -eq 3 -and
    [int]$contractRow.world_build_count -eq 3 -and
    [int]$contractRow.execution_valid_cell_count -eq 3 -and
    [int]$contractRow.common_physical_gate_pass_count -eq 3 -and
    [string]$contractRow.failed_attestation_gate_id -ceq
        "CAK1-EVIDENCE-PROVENANCE" -and
    [int]$contractRow.failed_attestation_world_count -eq 0 -and
    -not [bool]$contractRow.failed_attestation_consumed_physical_identity -and
    [bool]$contractRow.one_shot_identity_consumed -and
    -not [bool]$contractRow.same_identity_rerun_allowed -and
    [bool]$contractRow.finite_rapier_turning_validation -and
    -not [bool]$contractRow.portable_basic_turning -and
    -not [bool]$contractRow.q_sdk_r23_satisfied -and
    -not [bool]$contractRow.physical_acceptance_authority -and
    -not [bool]$matrix.claim_boundary.command_conditioned_turning -and
    -not [bool]$matrix.claim_boundary.prone_to_standing -and
    -not [bool]$matrix.claim_boundary.cross_engine_c6 -and
    -not [bool]$matrix.claim_boundary.submission_ready -and
    -not [bool]$matrix.claim_boundary.physical_acceptance_authority
) "release contract or public claim boundary changed"

Write-Host (
    "QSDK_R23D32_RELEASE_MATRIX_PASS closed=True worlds=3 " +
    "rapier_turning=True three_engine=False equivalence=False release=False"
)
