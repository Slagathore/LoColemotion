#requires -Version 7.0

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$matrixPath = Join-Path $repoRoot "sdk\release\quadruped_support_matrix.json"
$contractPath = Join-Path $repoRoot "sdk\release\quadruped_release_contract.json"

function Assert-R23D33Matrix([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "QSDK-R23D33 RELEASE MATRIX: $Message" }
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
    Assert-R23D33Matrix (Test-Path -LiteralPath $path -PathType Leaf) (
        "bound path is missing: $RelativePath"
    )
    return "sha256:" + (
        Get-FileHash -Algorithm SHA256 -LiteralPath $path
    ).Hash.ToLowerInvariant()
}

$matrix = Get-Content -Raw -LiteralPath $matrixPath | ConvertFrom-Json -Depth 100
$contract = Get-Content -Raw -LiteralPath $contractPath | ConvertFrom-Json -Depth 100
$matrixRows = @(Find-NamedJsonProperty $matrix "closed_r23d33_attempt")
$contractRows = @(Find-NamedJsonProperty $contract "closed_r23d33_attempt")
$successorStatuses = @(Find-NamedJsonProperty $contract "current_successor_status")
Assert-R23D33Matrix (
    $matrixRows.Count -eq 1 -and
    $contractRows.Count -eq 1 -and
    $successorStatuses.Count -eq 1 -and
    -not [string]::IsNullOrWhiteSpace([string]$successorStatuses[0])
) "expected one retained closed R23D33 record in each release authority"

$matrixRow = $matrixRows[0]
$contractRow = $contractRows[0]
foreach ($row in @($matrixRow, $contractRow)) {
    Assert-R23D33Matrix (
        [string]$row.gate_id -ceq "QSDK-R23D33" -and
        [string]$row.campaign_id -ceq
            "QSDK-R23D33-NATIVE-R23D29-TWO-ENGINE-TRANSFER" -and
        [string]$row.status -ceq
            "closed_consumed_invalid_complete_implementation_failures" -and
        [string]$row.physical_source_commit -ceq
            "c0282f2b26e112f26cebf9e3f01462cb6bf5c480" -and
        [string]$row.attempt_id -ceq "577b07a4557c4827b90de9dac32a2959" -and
        [int]$row.fresh_seed -eq 21507 -and
        [int]$row.declared_cell_count -eq 6 -and
        [int]$row.terminal_cell_count -eq 6 -and
        [int]$row.world_attempt_count -eq 3 -and
        [int]$row.world_build_count -eq 3 -and
        [int]$row.execution_valid_cell_count -eq 0 -and
        [int]$row.worker_failure_count -eq 6 -and
        [string]$row.godot_jolt_failure_mechanism -ceq
            "policy_specific_memory_rejected_by_legacy_schema_validator" -and
        [string]$row.mujoco_failure_mechanism -ceq
            "inherited_physical_entrypoint_redispatched_through_wrong_command_schedule_contract" -and
        [bool]$row.one_shot_identity_consumed -and
        -not [bool]$row.same_identity_rerun_allowed -and
        -not [bool]$row.scientific_locomotion_negative -and
        -not [bool]$row.native_godot_jolt_r23d29_turning -and
        -not [bool]$row.native_mujoco_r23d29_turning -and
        -not [bool]$row.portable_basic_turning -and
        -not [bool]$row.finite_three_engine_turning -and
        -not [bool]$row.cross_engine_equivalence -and
        -not [bool]$row.q_sdk_r23_satisfied -and
        -not [bool]$row.physical_acceptance_authority
    ) "release row changed"
}

Assert-R23D33Matrix (
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
    "QSDK_R23D33_RELEASE_MATRIX_PASS closed=True cells=6 worlds=3 " +
    "scientific_negative=False three_engine=False equivalence=False release=False"
)
