#requires -Version 7.0

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$matrixPath = Join-Path $repoRoot "sdk\release\quadruped_support_matrix.json"
$contractPath = Join-Path $repoRoot "sdk\release\quadruped_release_contract.json"

function Assert-R23D34Matrix([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "QSDK-R23D34 RELEASE MATRIX: $Message" }
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
    if ($Node -is [Collections.IEnumerable]) {
        foreach ($item in $Node) { Find-NamedJsonProperty $item $Name }
    }
}

function Get-Sha256([string]$RelativePath) {
    $path = Join-Path $repoRoot $RelativePath
    Assert-R23D34Matrix (Test-Path -LiteralPath $path -PathType Leaf) (
        "bound path is missing: $RelativePath"
    )
    return "sha256:" + (
        Get-FileHash -Algorithm SHA256 -LiteralPath $path
    ).Hash.ToLowerInvariant()
}

$matrix = Get-Content -Raw -LiteralPath $matrixPath | ConvertFrom-Json -Depth 100
$contract = Get-Content -Raw -LiteralPath $contractPath | ConvertFrom-Json -Depth 100
$matrixRows = @(Find-NamedJsonProperty $matrix "closed_r23d34_attempt")
$contractRows = @(Find-NamedJsonProperty $contract "closed_r23d34_attempt")
$successorStatuses = @(Find-NamedJsonProperty $contract "current_successor_status")
Assert-R23D34Matrix (
    $matrixRows.Count -eq 1 -and
    $contractRows.Count -eq 1 -and
    $successorStatuses.Count -eq 1 -and
    -not [string]::IsNullOrWhiteSpace([string]$successorStatuses[0])
) "expected one retained closed R23D34 record in each release authority"

$matrixRow = $matrixRows[0]
$contractRow = $contractRows[0]
foreach ($row in @($matrixRow, $contractRow)) {
    Assert-R23D34Matrix (
        [string]$row.gate_id -ceq "QSDK-R23D34" -and
        [string]$row.campaign_id -ceq
            "QSDK-R23D34-NATIVE-R23D29-IMPLEMENTATION-REPAIR-TRANSFER" -and
        [string]$row.status -ceq
            "closed_consumed_invalid_complete_with_valid_mujoco_locomotion_negative" -and
        [string]$row.physical_source_commit -ceq
            "7c76df6f4b77c5feac082cf9f5be48af69613565" -and
        [string]$row.attempt_id -ceq "8df7c56fdc94459d93391d184199ab21" -and
        [int]$row.fresh_seed -eq 21507 -and
        [int]$row.qualification_gate_count -eq 18 -and
        [int]$row.declared_cell_count -eq 6 -and
        [int]$row.terminal_cell_count -eq 6 -and
        [int]$row.world_attempt_count -eq 6 -and
        [int]$row.world_build_count -eq 6 -and
        [int]$row.execution_valid_cell_count -eq 3 -and
        [int]$row.common_physical_gate_pass_count -eq 0 -and
        [int]$row.worker_failure_count -eq 3 -and
        [int]$row.godot_jolt_native_motor_application_count -eq 71808 -and
        [string]$row.godot_jolt_outcome -ceq
            "invalid_trace_incomplete_diagnostics_not_retained" -and
        [int]$row.mujoco_valid_locomotion_negative_cell_count -eq 3 -and
        [int]$row.mujoco_first_torso_contact_step -eq 194 -and
        [int]$row.turn_command_start_step -eq 600 -and
        [bool]$row.implementation_repairs_physically_held -and
        [bool]$row.one_shot_identity_consumed -and
        -not [bool]$row.same_identity_rerun_allowed -and
        -not [bool]$row.aggregate_scientific_locomotion_negative -and
        [bool]$row.mujoco_finite_locomotion_negative -and
        -not [bool]$row.godot_jolt_walking_outcome_observed -and
        -not [bool]$row.godot_jolt_turning_outcome_observed -and
        -not [bool]$row.native_godot_jolt_r23d29_walking -and
        -not [bool]$row.native_godot_jolt_r23d29_turning -and
        -not [bool]$row.native_mujoco_r23d29_walking -and
        -not [bool]$row.native_mujoco_r23d29_turning -and
        -not [bool]$row.portable_basic_turning -and
        -not [bool]$row.finite_three_engine_turning -and
        -not [bool]$row.cross_engine_equivalence -and
        -not [bool]$row.q_sdk_r23_satisfied -and
        -not [bool]$row.physical_acceptance_authority
    ) "release row changed"
}

Assert-R23D34Matrix (
    (Get-Sha256 ([string]$matrixRow.preregistration_path)) -ceq
        [string]$matrixRow.preregistration_sha256 -and
    (Get-Sha256 ([string]$matrixRow.implementation_path)) -ceq
        [string]$matrixRow.implementation_sha256 -and
    (Get-Sha256 ([string]$matrixRow.closure_path)) -ceq
        [string]$matrixRow.closure_sha256 -and
    (Get-Sha256 ([string]$matrixRow.closure_audit_path)) -ceq
        [string]$matrixRow.closure_audit_sha256 -and
    (Get-Sha256 ([string]$matrixRow.release_matrix_audit_path)) -ceq
        [string]$matrixRow.release_matrix_audit_sha256 -and
    (Get-Sha256 ([string]$contractRow.preregistration_path)) -ceq
        [string]$contractRow.preregistration_raw_sha256 -and
    (Get-Sha256 ([string]$contractRow.implementation_path)) -ceq
        [string]$contractRow.implementation_raw_sha256 -and
    (Get-Sha256 ([string]$contractRow.closure_path)) -ceq
        [string]$contractRow.closure_raw_sha256 -and
    (Get-Sha256 ([string]$contractRow.closure_audit_path)) -ceq
        [string]$contractRow.closure_audit_raw_sha256 -and
    (Get-Sha256 ([string]$contractRow.release_matrix_audit_path)) -ceq
        [string]$contractRow.release_matrix_audit_raw_sha256 -and
    -not [bool]$matrix.claim_boundary.command_conditioned_turning -and
    -not [bool]$matrix.claim_boundary.prone_to_standing -and
    -not [bool]$matrix.claim_boundary.cross_engine_c6 -and
    -not [bool]$matrix.claim_boundary.submission_ready -and
    -not [bool]$matrix.claim_boundary.physical_acceptance_authority
) "digests or public claim boundary changed"

Write-Output (
    "QSDK_R23D34_RELEASE_MATRIX_PASS closed=True cells=6 worlds=6 " +
    "godot_valid=False mujoco_negative=True three_engine=False " +
    "equivalence=False release=False"
)
