#requires -Version 7.0

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$releaseContractPath = Join-Path $repoRoot "sdk\release\quadruped_release_contract.json"
$supportMatrixPath = Join-Path $repoRoot "sdk\release\quadruped_support_matrix.json"
$closurePath = Join-Path $repoRoot (
    "sdk\turning\r23d38_mujoco_startup_ramp_stabilization_closure_v1.json"
)
$closureAuditPath = Join-Path $repoRoot "tests\test_qsdk_r23d38_closure.ps1"

function Assert-R23D38Matrix([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "QSDK-R23D38 RELEASE MATRIX: $Message" }
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
                $found += [pscustomobject]@{
                    path = $childPath
                    value = $property.Value
                }
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
    Assert-R23D38Matrix ($properties.Count -eq 1) (
        "expected exactly one $RawName/$MatrixName property"
    )
    return [string]$properties[0].Value
}

function Assert-R23D38Record(
    $Record,
    [string]$ClosureHash,
    [string]$ClosureAuditHash,
    [string]$ReleaseAuditHash
) {
    Assert-R23D38Matrix (
        [string]$Record.gate_id -ceq "QSDK-R23D38" -and
        [string]$Record.campaign_id -ceq
            "QSDK-R23D38-MUJOCO-R23D29-STARTUP-RAMP-STABILIZATION" -and
        [string]$Record.status -ceq
            "closed_consumed_valid_complete_positive_startup_ramp_stabilization" -and
        [string]$Record.preregistration_path -ceq
            "sdk/turning/r23d38_mujoco_startup_ramp_stabilization_preregistration_v1.json" -and
        (Get-DigestProperty $Record "preregistration_raw_sha256" "preregistration_sha256") -ceq
            "sha256:571082bfeec8aeb5dbf512c14127106039378566db591a6c4f77d275f9fcd522" -and
        [string]$Record.implementation_path -ceq
            "sdk/turning/r23d38_mujoco_startup_ramp_stabilization_implementation_v1.json" -and
        (Get-DigestProperty $Record "implementation_raw_sha256" "implementation_sha256") -ceq
            "sha256:bf2054f10c5d6965c93dceb88cdb2667ab8cae42c0251ca2e4c1418e2b4267d9" -and
        [string]$Record.campaign_attestation_manifest_path -ceq
            "sdk/turning/r23d38_campaign_attestation_manifest_v1.json" -and
        (Get-DigestProperty $Record "campaign_attestation_manifest_raw_sha256" "campaign_attestation_manifest_sha256") -ceq
            "sha256:687c44a571cb12f0d9b0ea3d179e374cc86fde1e712107091457769ea4dedadb" -and
        [string]$Record.closure_path -ceq
            "sdk/turning/r23d38_mujoco_startup_ramp_stabilization_closure_v1.json" -and
        (Get-DigestProperty $Record "closure_raw_sha256" "closure_sha256") -ceq
            $ClosureHash -and
        [string]$Record.closure_audit_path -ceq
            "tests/test_qsdk_r23d38_closure.ps1" -and
        (Get-DigestProperty $Record "closure_audit_raw_sha256" "closure_audit_sha256") -ceq
            $ClosureAuditHash -and
        [string]$Record.release_matrix_audit_path -ceq
            "tests/test_qsdk_r23d38_release_matrix.ps1" -and
        (Get-DigestProperty $Record "release_matrix_audit_raw_sha256" "release_matrix_audit_sha256") -ceq
            $ReleaseAuditHash -and
        [string]$Record.preworld_incident_path -ceq
            "sdk/turning/r23d38_first_scoped_attestation_incident_v1.json" -and
        [int]$Record.preworld_incident_world_count -eq 0 -and
        -not [bool]$Record.preworld_incident_consumed_physical_identity -and
        [string]$Record.physical_source_commit -ceq
            "6035f09deae3b5418c54fdeba458b6a8b7e30190" -and
        [string]$Record.attempt_id -ceq "dfa9d90ce1ee4b1c9d4555674b96f137" -and
        [int]$Record.outcome_exposed_seed -eq 21507 -and
        -not [bool]$Record.fresh_held_out_condition_consumed -and
        [int]$Record.qualification_gate_count -eq 20 -and
        [double]$Record.qualification_duration_seconds -eq 110.1023528 -and
        [int]$Record.source_binding_count -eq 66 -and
        [int]$Record.declared_cell_count -eq 1 -and
        [int]$Record.terminal_cell_count -eq 1 -and
        [int]$Record.world_attempt_count -eq 1 -and
        [int]$Record.world_build_count -eq 1 -and
        [int]$Record.trace_count -eq 1 -and
        [int]$Record.trace_row_count -eq 2992 -and
        [string]$Record.official_classification -ceq
            "valid_complete_positive_startup_ramp_stabilization" -and
        [bool]$Record.scientific_selector_legally_completed -and
        [string]$Record.terminal_manifest_json_type -ceq "array" -and
        [bool]$Record.strict_array_boundary_physically_held -and
        [string]$Record.startup_ramp_id -ceq
            "canonical_velocity_smoothstep_one_gait_cycle_v1" -and
        [int]$Record.startup_ramp_step_count -eq 360 -and
        [int]$Record.startup_ramp_active_step_count -eq 359 -and
        [double]$Record.final_forward_displacement_m -eq 1.6546781589105957 -and
        [double]$Record.maximum_tilt_rad -eq 0.07943305657545596 -and
        [double]$Record.minimum_torso_height_m -eq 0.42452487260337624 -and
        [int]$Record.torso_ground_contact_step_count -eq 0 -and
        [int]$Record.contact_cycle_count_by_limb.front_left -eq 28 -and
        [int]$Record.contact_cycle_count_by_limb.front_right -eq 33 -and
        [int]$Record.contact_cycle_count_by_limb.rear_left -eq 16 -and
        [int]$Record.contact_cycle_count_by_limb.rear_right -eq 18 -and
        @($Record.failed_frozen_gate_ids).Count -eq 0 -and
        [bool]$Record.one_shot_identity_consumed -and
        -not [bool]$Record.same_identity_rerun_allowed -and
        -not [bool]$Record.successor_campaign_opened -and
        [bool]$Record.finite_mujoco_r23d29_seed_21507_startup_ramp_walking -and
        [bool]$Record.one_cycle_startup_ramp_selected_as_finite_development_mechanism -and
        -not [bool]$Record.native_mujoco_r23d29_walking_population_claim -and
        -not [bool]$Record.native_mujoco_r23d29_turning -and
        -not [bool]$Record.portable_basic_turning -and
        -not [bool]$Record.finite_three_engine_turning -and
        -not [bool]$Record.cross_engine_equivalence -and
        -not [bool]$Record.q_sdk_r23_satisfied -and
        -not [bool]$Record.physical_acceptance_authority
    ) "R23D38 record changed"
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
Assert-R23D38Matrix (
    $turningGate.Count -eq 1 -and
    [string]$turningGate[0].proof.kind -ceq "missing" -and
    -not [string]::IsNullOrWhiteSpace(
        [string]$turningGate[0].proof.current_successor_status
    )
) "QSDK-R23 boundary changed"

$releaseRecords = @(Find-NamedProperty $release "closed_r23d38_attempt")
$matrixRecords = @(Find-NamedProperty $matrix "closed_r23d38_attempt")
Assert-R23D38Matrix ($releaseRecords.Count -eq 1) (
    "expected one release-contract R23D38 record; got $($releaseRecords.Count)"
)
Assert-R23D38Matrix ($matrixRecords.Count -eq 1) (
    "expected one support-matrix R23D38 record; got $($matrixRecords.Count)"
)
Assert-R23D38Record $releaseRecords[0].value $closureHash $closureAuditHash $releaseAuditHash
Assert-R23D38Record $matrixRecords[0].value $closureHash $closureAuditHash $releaseAuditHash

foreach ($property in @(
    "scoped_attestation_sha256", "adoption_sha256", "report_sha256",
    "completion_sha256", "terminal_manifest_sha256", "terminal_sha256",
    "trace_sha256"
)) {
    Assert-R23D38Matrix (
        [string]$matrixRecords[0].value.$property -ceq
            [string]$releaseRecords[0].value.$property
    ) "release/support evidence digest differs: $property"
}
Assert-R23D38Matrix (
    [string]$releaseRecords[0].value.scoped_attestation_sha256 -ceq
        "sha256:1b1da8afa464987ab9456bf3389672f7d324a8611c373dfe19c7782ba5ff0ef0" -and
    [string]$releaseRecords[0].value.adoption_sha256 -ceq
        "sha256:e17996736ff9896b932cb2d2c608ff2b19c1f0aaff84131698335b5d0b40d5a4" -and
    [string]$releaseRecords[0].value.report_sha256 -ceq
        "sha256:f53b7c735f3787d5f495f41d1b3b6dc326a85967904567a6261495f882181aa2" -and
    [string]$releaseRecords[0].value.completion_sha256 -ceq
        "sha256:f7091448db8a1a796dd32669c21cbbfe9f83d340f138d59f5b590cd14758f1b4" -and
    [string]$releaseRecords[0].value.terminal_manifest_sha256 -ceq
        "sha256:fed01bd7ef9858c644082b4fcf8f07615eaf3ce1d28e06988704d6da5057412c" -and
    [string]$releaseRecords[0].value.terminal_sha256 -ceq
        "sha256:8550fa8a013258de81217fec18d99e77f916fcbc83f5ecfb689ccb3df50cfdc8" -and
    [string]$releaseRecords[0].value.trace_sha256 -ceq
        "sha256:effcc8e2375254802f5e7c0cf2a93e5b484df09cda82371b1e7e8988b9d98ad4" -and
    [bool]$turningGate[0].required_for_release -and
    -not [bool]$matrix.claim_boundary.command_conditioned_turning -and
    -not [bool]$matrix.claim_boundary.formal_cross_engine_comparative_inference -and
    -not [bool]$matrix.claim_boundary.submission_ready -and
    -not [bool]$matrix.claim_boundary.physical_acceptance_authority -and
    [bool]$closure.claims.finite_mujoco_r23d29_seed_21507_startup_ramp_walking -and
    -not [bool]$closure.claims.finite_three_engine_turning
) "retained evidence or release claim boundary changed"

Write-Output (
    "QSDK_R23D38_RELEASE_MATRIX_PASS official=valid_positive " +
    "finite_mujoco_seed_21507=True turning=False " +
    "portable_three_engine=False qsdk_r23=False release=False"
)
