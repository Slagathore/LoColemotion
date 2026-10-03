#requires -Version 7.0

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$matrixPath = Join-Path $repoRoot "sdk\release\quadruped_support_matrix.json"

function Assert-R23D31Matrix([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "QSDK-R23D31 RELEASE MATRIX: $Message" }
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
    Assert-R23D31Matrix (Test-Path -LiteralPath $path -PathType Leaf) (
        "bound path is missing: $RelativePath"
    )
    return "sha256:" + (
        Get-FileHash -Algorithm SHA256 -LiteralPath $path
    ).Hash.ToLowerInvariant()
}

$matrix = Get-Content -Raw -LiteralPath $matrixPath |
    ConvertFrom-Json -Depth 100
$r23d30 = @(Find-NamedJsonProperty $matrix "closed_r23d30_attempt")
$r23d31 = @(Find-NamedJsonProperty $matrix "closed_r23d31_attempt")
Assert-R23D31Matrix ($r23d30.Count -eq 1 -and $r23d31.Count -eq 1) (
    "expected one bounded record for each R23D30 and R23D31"
)
$r23d30 = $r23d30[0]
$r23d31 = $r23d31[0]
Assert-R23D31Matrix (
    [string]$r23d30.status -ceq
        "closed_valid_complete_negative_no_measurement_validation_candidate" -and
    (Get-Sha256 ([string]$r23d30.closure_path)) -ceq
        [string]$r23d30.closure_sha256 -and
    (Get-Sha256 ([string]$r23d30.closure_audit_path)) -ceq
        [string]$r23d30.closure_audit_sha256 -and
    [int]$r23d30.world_attempt_count -eq 3 -and
    [int]$r23d30.common_physical_gate_pass_count -eq 3 -and
    [bool]$r23d30.raw_signed_cycle_shift_gate_passed -and
    [bool]$r23d30.reference_conditioned_cycle_shift_gate_passed -and
    -not [bool]$r23d30.every_terminal_swing_reference_conditioned_direction_passed -and
    -not [bool]$r23d30.finite_rapier_cycle_coherent_measurement_validation -and
    -not [bool]$r23d30.physical_acceptance_authority
) "R23D30 bounded record changed"
Assert-R23D31Matrix (
    [string]$r23d31.status -ceq
        "closed_valid_complete_positive_measurement_validation_candidate" -and
    (Get-Sha256 ([string]$r23d31.closure_path)) -ceq
        [string]$r23d31.closure_sha256 -and
    (Get-Sha256 ([string]$r23d31.closure_audit_path)) -ceq
        [string]$r23d31.closure_audit_sha256 -and
    [string]$r23d31.physical_source_commit -ceq
        "fcec5011ec9b1dd29b90ee9f0d5018bcc228a799" -and
    [int]$r23d31.world_attempt_count -eq 3 -and
    [int]$r23d31.world_build_count -eq 3 -and
    [int]$r23d31.execution_valid_cell_count -eq 3 -and
    [int]$r23d31.common_physical_gate_pass_count -eq 3 -and
    [int]$r23d31.eligible_candidate_count -eq 1 -and
    [bool]$r23d31.measurement_candidate_selected -and
    -not [bool]$r23d31.controller_candidate_selected -and
    [bool]$r23d31.raw_signed_cycle_shift_gate_passed -and
    [bool]$r23d31.reference_conditioned_cycle_shift_gate_passed -and
    [bool]$r23d31.every_terminal_swing_raw_direction_passed -and
    -not [bool]$r23d31.every_terminal_swing_reference_conditioned_direction_passed -and
    [bool]$r23d31.finite_rapier_cycle_integrated_measurement_validation -and
    -not [bool]$r23d31.finite_rapier_turning_validation -and
    -not [bool]$r23d31.portable_basic_turning -and
    -not [bool]$r23d31.finite_three_engine_turning -and
    -not [bool]$r23d31.cross_engine_equivalence -and
    -not [bool]$r23d31.q_sdk_r23_satisfied -and
    -not [bool]$r23d31.physical_acceptance_authority -and
    -not [bool]$matrix.claim_boundary.command_conditioned_turning -and
    -not [bool]$matrix.claim_boundary.prone_to_standing -and
    -not [bool]$matrix.claim_boundary.cross_engine_c6 -and
    -not [bool]$matrix.claim_boundary.formal_cross_engine_comparative_inference -and
    -not [bool]$matrix.claim_boundary.submission_ready -and
    -not [bool]$matrix.claim_boundary.physical_acceptance_authority
) "R23D31 bounded record or public claim boundary changed"

Write-Host (
    "QSDK_R23D31_RELEASE_MATRIX_PASS r23d30=negative r23d31=positive_measurement " +
    "turning=False three_engine=False equivalence=False release=False"
)
