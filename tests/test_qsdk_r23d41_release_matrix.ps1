#requires -Version 7.0

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$releaseContractPath = Join-Path $repoRoot "sdk\release\quadruped_release_contract.json"
$supportMatrixPath = Join-Path $repoRoot "sdk\release\quadruped_support_matrix.json"
$closurePath = Join-Path $repoRoot (
    "sdk\turning\r23d41_three_engine_startup_ramp_turning_closure_v1.json"
)
$closureAuditPath = Join-Path $repoRoot "tests\test_qsdk_r23d41_closure.ps1"

function Assert-R23D41Matrix([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "QSDK-R23D41 RELEASE MATRIX: $Message" }
}

function Get-Sha256([string]$Path) {
    return "sha256:" + (
        Get-FileHash -LiteralPath $Path -Algorithm SHA256
    ).Hash.ToLowerInvariant()
}

function Find-NamedProperty($Node, [string]$Name, [string]$Path = '$') {
    $found = @()
    if ($null -eq $Node) { return $found }
    if ($Node -is [pscustomobject]) {
        foreach ($property in $Node.PSObject.Properties) {
            $childPath = "$Path.$($property.Name)"
            if ([string]$property.Name -ceq $Name) {
                $found += [pscustomobject]@{ path = $childPath; value = $property.Value }
            }
            $found += @(Find-NamedProperty $property.Value $Name $childPath)
        }
    } elseif ($Node -is [Collections.IEnumerable] -and -not ($Node -is [string])) {
        $index = 0
        foreach ($item in $Node) {
            $found += @(Find-NamedProperty $item $Name "$Path[$index]")
            $index++
        }
    }
    return $found
}

function Get-DigestProperty($Record, [string]$RawName, [string]$MatrixName) {
    $properties = @($Record.PSObject.Properties | Where-Object {
        [string]$_.Name -ceq $RawName -or [string]$_.Name -ceq $MatrixName
    })
    Assert-R23D41Matrix ($properties.Count -eq 1) (
        "expected exactly one $RawName/$MatrixName property"
    )
    return [string]$properties[0].Value
}

function Assert-R23D41Record(
    $Record,
    [string]$ClosureHash,
    [string]$ClosureAuditHash,
    [string]$ReleaseAuditHash
) {
    Assert-R23D41Matrix (
        [string]$Record.gate_id -ceq "QSDK-R23D41" -and
        [string]$Record.campaign_id -ceq
            "QSDK-R23D41-THREE-ENGINE-STARTUP-RAMP-TURNING-VALIDATION" -and
        [string]$Record.status -ceq
            "closed_consumed_implementation_invalid_trace_interfaces" -and
        [string]$Record.preregistration_path -ceq
            "sdk/turning/r23d41_three_engine_startup_ramp_turning_preregistration_v1.json" -and
        (Get-DigestProperty $Record "preregistration_raw_sha256" "preregistration_sha256") -ceq
            "sha256:10e19ca614a5833ff28ec101074a632c5dc45a347a60ad7a5e44bd2adbcd7f4f" -and
        [string]$Record.implementation_path -ceq
            "sdk/turning/r23d41_three_engine_startup_ramp_turning_implementation_v1.json" -and
        (Get-DigestProperty $Record "implementation_raw_sha256" "implementation_sha256") -ceq
            "sha256:30668aa0a304fe69d04e0ec42f6c772827830e19eaddf659cafdc3eb17ea3db5" -and
        [string]$Record.campaign_attestation_manifest_path -ceq
            "sdk/turning/r23d41_campaign_attestation_manifest_v1.json" -and
        (Get-DigestProperty $Record "campaign_attestation_manifest_raw_sha256" "campaign_attestation_manifest_sha256") -ceq
            "sha256:f36b2ce464d98d1706f5d560ae9444143435412d74fe0893a2cd4428bffe7ff2" -and
        [string]$Record.closure_path -ceq
            "sdk/turning/r23d41_three_engine_startup_ramp_turning_closure_v1.json" -and
        (Get-DigestProperty $Record "closure_raw_sha256" "closure_sha256") -ceq
            $ClosureHash -and
        [string]$Record.closure_audit_path -ceq
            "tests/test_qsdk_r23d41_closure.ps1" -and
        (Get-DigestProperty $Record "closure_audit_raw_sha256" "closure_audit_sha256") -ceq
            $ClosureAuditHash -and
        [string]$Record.release_matrix_audit_path -ceq
            "tests/test_qsdk_r23d41_release_matrix.ps1" -and
        (Get-DigestProperty $Record "release_matrix_audit_raw_sha256" "release_matrix_audit_sha256") -ceq
            $ReleaseAuditHash -and
        [string]$Record.physical_source_commit -ceq
            "6b4e9f447181ba79670301eef1c12dcf533cd37d" -and
        [string]$Record.attempt_id -ceq "28e61d534bc14a07b7f39de2c3461799" -and
        [int]$Record.fresh_seed -eq 21509 -and
        [int]$Record.qualification_gate_count -eq 17 -and
        [double]$Record.qualification_duration_seconds -eq 163.0478257 -and
        [int]$Record.source_binding_count -eq 117 -and
        [int]$Record.declared_cell_count -eq 9 -and
        [int]$Record.terminal_cell_count -eq 9 -and
        [int]$Record.execution_valid_cell_count -eq 3 -and
        [int]$Record.worker_failure_count -eq 6 -and
        [int]$Record.production_authorization_pass_count -eq 9 -and
        [int]$Record.world_attempt_count -eq 9 -and
        [int]$Record.world_build_count -eq 9 -and
        [int]$Record.complete_attempt_file_count -eq 49 -and
        [bool]$Record.complete_attempt_files_content_addressed -and
        [int]$Record.raw_trace_count -eq 9 -and
        [int]$Record.total_raw_trace_row_count -eq 26928 -and
        [int]$Record.mujoco_trace_count -eq 3 -and
        [int]$Record.total_mujoco_trace_row_count -eq 8976 -and
        [string]$Record.official_classification -ceq
            "invalid_or_incomplete_three_engine_portable_turning_validation" -and
        [string]$Record.controller_policy_id -ceq
            "sporespore_balanced_wave_r23d29_two_swing_persistent_predictive_stability_guarded_steering_v1" -and
        [string]$Record.startup_ramp_id -ceq
            "canonical_velocity_smoothstep_one_gait_cycle_v1" -and
        [string]$Record.rapier_failure_code_prefix -ceq
            "QSDK_R23D27_RAP_TRACE_RETENTION_FAILED" -and
        [string]$Record.godot_jolt_failure_code -ceq
            "QSDK_R23D41_GJT_TRACE_RETENTION_FAILED:1" -and
        [double]$Record.mujoco_positive_reference_conditioned_cycle_shift_rad -eq
            0.13290456871469394 -and
        [double]$Record.mujoco_negative_reference_conditioned_cycle_shift_rad -eq
            0.14177594606165717 -and
        [double]$Record.mujoco_bilateral_reference_conditioned_cycle_separation_rad -eq
            0.27468051477635114 -and
        [bool]$Record.mujoco_raw_signed_cycle_shift_passed -and
        [bool]$Record.mujoco_reference_conditioned_cycle_shift_passed -and
        [double]$Record.rapier_diagnostic_positive_conditioned_cycle_shift_rad -eq
            0.005401148214074572 -and
        [double]$Record.rapier_diagnostic_negative_conditioned_cycle_shift_rad -eq
            0.02650468857654588 -and
        -not [bool]$Record.rapier_diagnostic_reference_conditioned_gate_passed -and
        [double]$Record.godot_jolt_diagnostic_positive_conditioned_cycle_shift_rad -eq
            0.1067857284577487 -and
        [double]$Record.godot_jolt_diagnostic_negative_conditioned_cycle_shift_rad -eq
            -0.11674807001766441 -and
        -not [bool]$Record.godot_jolt_diagnostic_raw_signed_gate_passed -and
        -not [bool]$Record.godot_jolt_diagnostic_reference_conditioned_gate_passed -and
        [bool]$Record.one_shot_identity_consumed -and
        -not [bool]$Record.same_identity_rerun_allowed -and
        -not [bool]$Record.successor_campaign_opened -and
        [bool]$Record.finite_mujoco_seed_21509_walking_and_turning -and
        -not [bool]$Record.accepted_rapier_seed_21509_walking_or_turning -and
        -not [bool]$Record.accepted_godot_jolt_seed_21509_walking_or_turning -and
        -not [bool]$Record.unified_fresh_three_engine_turning_validation -and
        -not [bool]$Record.portable_basic_turning -and
        -not [bool]$Record.finite_three_engine_turning -and
        -not [bool]$Record.cross_engine_equivalence -and
        -not [bool]$Record.q_sdk_r23_satisfied -and
        -not [bool]$Record.physical_acceptance_authority
    ) "R23D41 record changed"
}

$release = Get-Content -Raw -LiteralPath $releaseContractPath |
    ConvertFrom-Json -Depth 100
$matrix = Get-Content -Raw -LiteralPath $supportMatrixPath |
    ConvertFrom-Json -Depth 100
$closure = Get-Content -Raw -LiteralPath $closurePath |
    ConvertFrom-Json -Depth 100
$closureHash = Get-Sha256 $closurePath
$closureAuditHash = Get-Sha256 $closureAuditPath
$releaseAuditHash = Get-Sha256 $PSCommandPath

$turningGate = @($release.gates | Where-Object {
    [string]$_.gate_id -ceq "QSDK-R23"
})
Assert-R23D41Matrix (
    $turningGate.Count -eq 1 -and
    [string]$turningGate[0].proof.kind -ceq "missing" -and
    [string]$turningGate[0].proof.current_successor_status -ceq
        "r23d41_closed_consumed_implementation_invalid_trace_boundaries_mujoco_finite_positive_fresh_successor_required"
) "QSDK-R23 boundary changed"

$releaseRecords = @(Find-NamedProperty $release "closed_r23d41_attempt")
$matrixRecords = @(Find-NamedProperty $matrix "closed_r23d41_attempt")
Assert-R23D41Matrix ($releaseRecords.Count -eq 1) (
    "expected one release-contract R23D41 record; got $($releaseRecords.Count)"
)
Assert-R23D41Matrix ($matrixRecords.Count -eq 1) (
    "expected one support-matrix R23D41 record; got $($matrixRecords.Count)"
)
Assert-R23D41Record $releaseRecords[0].value $closureHash $closureAuditHash $releaseAuditHash
Assert-R23D41Record $matrixRecords[0].value $closureHash $closureAuditHash $releaseAuditHash

foreach ($property in @(
    "scoped_attestation_sha256", "adoption_sha256", "report_sha256",
    "completion_sha256", "terminal_manifest_sha256",
    "complete_evaluation_sha256", "production_authorization_preflight_sha256"
)) {
    Assert-R23D41Matrix (
        [string]$matrixRecords[0].value.$property -ceq
            [string]$releaseRecords[0].value.$property
    ) "release/support evidence digest differs: $property"
}
Assert-R23D41Matrix (
    [string]$releaseRecords[0].value.scoped_attestation_sha256 -ceq
        "sha256:d3d532113da99dae943e7b7d8a1b2efb2400c136a64d4fb40f473982e729218d" -and
    [string]$releaseRecords[0].value.adoption_sha256 -ceq
        "sha256:3c88e6215ed328318430bf225c2c9b9e1baa740598dbb1b0a7c760d7095f5558" -and
    [string]$releaseRecords[0].value.production_authorization_preflight_sha256 -ceq
        "sha256:716d9f08b71ea078fbc5379fc4f60039760c3bb529d193953f4b6e632537af50" -and
    [string]$releaseRecords[0].value.report_sha256 -ceq
        "sha256:ebb0474f95c41933ca0b429c8f53508cf701e3fb41c5481382e13df1ae5e9a59" -and
    [string]$releaseRecords[0].value.completion_sha256 -ceq
        "sha256:ecda7b457b311b03147ea50be11409e68fada44785263793cc83a221a302a350" -and
    [string]$releaseRecords[0].value.terminal_manifest_sha256 -ceq
        "sha256:c755e954090b274886196b817da63e21195bb76416dea3d1809cfd799226f7d6" -and
    [string]$releaseRecords[0].value.complete_evaluation_sha256 -ceq
        "sha256:a8787962931b8c65d789ad915979cd183617bd40dd8b9926c000bd488db858fa" -and
    [bool]$turningGate[0].required_for_release -and
    -not [bool]$matrix.claim_boundary.command_conditioned_turning -and
    -not [bool]$matrix.claim_boundary.formal_cross_engine_comparative_inference -and
    -not [bool]$matrix.claim_boundary.submission_ready -and
    -not [bool]$matrix.claim_boundary.physical_acceptance_authority -and
    [bool]$closure.claims.mujoco_seed_21509_walking_and_turning -and
    -not [bool]$closure.claims.r23d41_three_engine_validation
) "retained evidence or release claim boundary changed"

Write-Output (
    "QSDK_R23D41_RELEASE_MATRIX_PASS official=implementation_invalid " +
    "finite_mujoco_turning=True unified_three_engine_validation=False " +
    "qsdk_r23=False release=False successor_required=True"
)
