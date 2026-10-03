#requires -Version 7.0

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$releaseContractPath = Join-Path $repoRoot "sdk\release\quadruped_release_contract.json"
$supportMatrixPath = Join-Path $repoRoot "sdk\release\quadruped_support_matrix.json"
$closurePath = Join-Path $repoRoot (
    "sdk\turning\r23d40_three_engine_startup_ramp_turning_closure_v1.json"
)
$closureAuditPath = Join-Path $repoRoot "tests\test_qsdk_r23d40_closure.ps1"

function Assert-R23D40Matrix([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "QSDK-R23D40 RELEASE MATRIX: $Message" }
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
    Assert-R23D40Matrix ($properties.Count -eq 1) (
        "expected exactly one $RawName/$MatrixName property"
    )
    return [string]$properties[0].Value
}

function Assert-R23D40Record(
    $Record,
    [string]$ClosureHash,
    [string]$ClosureAuditHash,
    [string]$ReleaseAuditHash
) {
    Assert-R23D40Matrix (
        [string]$Record.gate_id -ceq "QSDK-R23D40" -and
        [string]$Record.campaign_id -ceq
            "QSDK-R23D40-THREE-ENGINE-STARTUP-RAMP-TURNING-VALIDATION" -and
        [string]$Record.status -ceq
            "closed_consumed_implementation_invalid_three_engine_validation" -and
        [string]$Record.preregistration_path -ceq
            "sdk/turning/r23d40_three_engine_startup_ramp_turning_preregistration_v1.json" -and
        (Get-DigestProperty $Record "preregistration_raw_sha256" "preregistration_sha256") -ceq
            "sha256:175468729870b262e9c257ceb16caaeeb371e06349007ed43bb1d23865937beb" -and
        [string]$Record.implementation_path -ceq
            "sdk/turning/r23d40_three_engine_startup_ramp_turning_implementation_v1.json" -and
        (Get-DigestProperty $Record "implementation_raw_sha256" "implementation_sha256") -ceq
            "sha256:5b236dfe157dfaa93e484c3acc94c0f2139295f898aacd1050608fca7867c0d9" -and
        [string]$Record.campaign_attestation_manifest_path -ceq
            "sdk/turning/r23d40_campaign_attestation_manifest_v1.json" -and
        (Get-DigestProperty $Record "campaign_attestation_manifest_raw_sha256" "campaign_attestation_manifest_sha256") -ceq
            "sha256:b781fdc5141b3c8b1798a3fd596c697bc3e9dd0e1e5fc7ba2ae30b64d587cb88" -and
        [string]$Record.closure_path -ceq
            "sdk/turning/r23d40_three_engine_startup_ramp_turning_closure_v1.json" -and
        (Get-DigestProperty $Record "closure_raw_sha256" "closure_sha256") -ceq
            $ClosureHash -and
        [string]$Record.closure_audit_path -ceq
            "tests/test_qsdk_r23d40_closure.ps1" -and
        (Get-DigestProperty $Record "closure_audit_raw_sha256" "closure_audit_sha256") -ceq
            $ClosureAuditHash -and
        [string]$Record.release_matrix_audit_path -ceq
            "tests/test_qsdk_r23d40_release_matrix.ps1" -and
        (Get-DigestProperty $Record "release_matrix_audit_raw_sha256" "release_matrix_audit_sha256") -ceq
            $ReleaseAuditHash -and
        [string]$Record.physical_source_commit -ceq
            "f2c45811f3f945a088ee93f2d31b97d4a139df31" -and
        [string]$Record.attempt_id -ceq "4f37875ec94943e7a7995b728703609a" -and
        [int]$Record.fresh_seed -eq 21508 -and
        [int]$Record.qualification_gate_count -eq 17 -and
        [double]$Record.qualification_duration_seconds -eq 166.7470097 -and
        [int]$Record.source_binding_count -eq 116 -and
        [int]$Record.declared_cell_count -eq 9 -and
        [int]$Record.terminal_cell_count -eq 9 -and
        [int]$Record.execution_valid_cell_count -eq 3 -and
        [int]$Record.worker_failure_count -eq 6 -and
        [int]$Record.world_attempt_count -eq 3 -and
        [int]$Record.world_build_count -eq 3 -and
        [int]$Record.mujoco_trace_count -eq 3 -and
        [int]$Record.total_mujoco_trace_row_count -eq 8976 -and
        [string]$Record.official_classification -ceq
            "invalid_or_incomplete_three_engine_portable_turning_validation" -and
        [string]$Record.controller_policy_id -ceq
            "sporespore_balanced_wave_r23d29_two_swing_persistent_predictive_stability_guarded_steering_v1" -and
        [string]$Record.startup_ramp_id -ceq
            "canonical_velocity_smoothstep_one_gait_cycle_v1" -and
        [string]$Record.rapier_failure_code -ceq
            "QSDK_R23D27_RAP_PHYSICAL_AUTHORIZATION_INVALID" -and
        [string]$Record.godot_jolt_failure_code -ceq
            "QSDK_R23D40_GJT_PHYSICAL_AUTHORIZATION_INVALID" -and
        [double]$Record.mujoco_positive_reference_conditioned_cycle_shift_rad -eq
            0.13120013610598003 -and
        [double]$Record.mujoco_negative_reference_conditioned_cycle_shift_rad -eq
            0.1457201672214153 -and
        [double]$Record.mujoco_bilateral_reference_conditioned_cycle_separation_rad -eq
            0.2769203033273953 -and
        [bool]$Record.mujoco_raw_signed_cycle_shift_passed -and
        [bool]$Record.mujoco_reference_conditioned_cycle_shift_passed -and
        [bool]$Record.one_shot_identity_consumed -and
        -not [bool]$Record.same_identity_rerun_allowed -and
        -not [bool]$Record.successor_campaign_opened -and
        [bool]$Record.finite_mujoco_seed_21508_walking_and_turning -and
        -not [bool]$Record.unified_fresh_three_engine_turning_validation -and
        -not [bool]$Record.portable_basic_turning -and
        -not [bool]$Record.finite_three_engine_turning -and
        -not [bool]$Record.cross_engine_equivalence -and
        -not [bool]$Record.q_sdk_r23_satisfied -and
        -not [bool]$Record.physical_acceptance_authority
    ) "R23D40 record changed"
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
Assert-R23D40Matrix (
    $turningGate.Count -eq 1 -and
    [string]$turningGate[0].proof.kind -ceq "missing" -and
    -not [string]::IsNullOrWhiteSpace(
        [string]$turningGate[0].proof.current_successor_status
    )
) "QSDK-R23 boundary changed"

$releaseRecords = @(Find-NamedProperty $release "closed_r23d40_attempt")
$matrixRecords = @(Find-NamedProperty $matrix "closed_r23d40_attempt")
Assert-R23D40Matrix ($releaseRecords.Count -eq 1) (
    "expected one release-contract R23D40 record; got $($releaseRecords.Count)"
)
Assert-R23D40Matrix ($matrixRecords.Count -eq 1) (
    "expected one support-matrix R23D40 record; got $($matrixRecords.Count)"
)
Assert-R23D40Record $releaseRecords[0].value $closureHash $closureAuditHash $releaseAuditHash
Assert-R23D40Record $matrixRecords[0].value $closureHash $closureAuditHash $releaseAuditHash

foreach ($property in @(
    "scoped_attestation_sha256", "adoption_sha256", "report_sha256",
    "completion_sha256", "terminal_manifest_sha256",
    "complete_evaluation_sha256"
)) {
    Assert-R23D40Matrix (
        [string]$matrixRecords[0].value.$property -ceq
            [string]$releaseRecords[0].value.$property
    ) "release/support evidence digest differs: $property"
}
Assert-R23D40Matrix (
    [string]$releaseRecords[0].value.scoped_attestation_sha256 -ceq
        "sha256:be404cef0a8a9478f41d807a9b9cfbe75894ead6ae7bd02ac41af24c640cfff1" -and
    [string]$releaseRecords[0].value.adoption_sha256 -ceq
        "sha256:b096c1e057f64803e63b8d7f77a80dc048515b38ec59177c2d2cb724e0916784" -and
    [string]$releaseRecords[0].value.report_sha256 -ceq
        "sha256:d974a2401b8f75efad7870b4cbf77f1735da6888803dce4213912997b7c1d2ed" -and
    [string]$releaseRecords[0].value.completion_sha256 -ceq
        "sha256:995f7dea1085a43673d5ed3e00872483761d91d8b4c32b7a34e5f67df9e3614c" -and
    [string]$releaseRecords[0].value.terminal_manifest_sha256 -ceq
        "sha256:561733fb55534d90c1023dca1a6f9f07de62c8cbd5169490100c16e9e54618ea" -and
    [string]$releaseRecords[0].value.complete_evaluation_sha256 -ceq
        "sha256:325036b4d83e3a0d6ae6a9e3106702f8902209d120770ad090198a48c801603f" -and
    [bool]$turningGate[0].required_for_release -and
    -not [bool]$matrix.claim_boundary.command_conditioned_turning -and
    -not [bool]$matrix.claim_boundary.formal_cross_engine_comparative_inference -and
    -not [bool]$matrix.claim_boundary.submission_ready -and
    -not [bool]$matrix.claim_boundary.physical_acceptance_authority -and
    [bool]$closure.claims.mujoco_seed_21508_walking_and_turning -and
    -not [bool]$closure.claims.r23d40_three_engine_validation
) "retained evidence or release claim boundary changed"

Write-Output (
    "QSDK_R23D40_RELEASE_MATRIX_PASS official=implementation_invalid " +
    "finite_mujoco_turning=True unified_three_engine_validation=False " +
    "qsdk_r23=False release=False successor_required=True"
)
