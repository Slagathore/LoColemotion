#requires -Version 7.0

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$releaseContractPath = Join-Path $repoRoot "sdk\release\quadruped_release_contract.json"
$supportMatrixPath = Join-Path $repoRoot "sdk\release\quadruped_support_matrix.json"
$closurePath = Join-Path $repoRoot (
    "sdk\turning\r23d37_mujoco_policy_seed_isolation_closure_v1.json"
)
$closureAuditPath = Join-Path $repoRoot "tests\test_qsdk_r23d37_closure.ps1"

function Assert-R23D37Matrix([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "QSDK-R23D37 RELEASE MATRIX: $Message" }
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
            $index += 1
        }
    }
    return $found
}

function Get-DigestProperty($Record, [string]$RawName, [string]$MatrixName) {
    $properties = @($Record.PSObject.Properties | Where-Object {
        [string]$_.Name -ceq $RawName -or [string]$_.Name -ceq $MatrixName
    })
    Assert-R23D37Matrix ($properties.Count -eq 1) (
        "expected exactly one $RawName/$MatrixName property"
    )
    return [string]$properties[0].Value
}

function Assert-R23D37Record(
    $Record,
    [string]$ClosureHash,
    [string]$ClosureAuditHash,
    [string]$ReleaseAuditHash
) {
    Assert-R23D37Matrix (
        [string]$Record.gate_id -ceq "QSDK-R23D37" -and
        [string]$Record.campaign_id -ceq
            "QSDK-R23D37-MUJOCO-R23D21-POLICY-SEED-ISOLATION" -and
        [string]$Record.status -ceq
            "closed_consumed_valid_complete_negative_policy_seed_isolation" -and
        [string]$Record.preregistration_path -ceq
            "sdk/turning/r23d37_mujoco_policy_seed_isolation_preregistration_v1.json" -and
        (Get-DigestProperty $Record "preregistration_raw_sha256" "preregistration_sha256") -ceq
            "sha256:6b7a6c829c83d87e1a288556c269601aab00e342ec5c35baec7fa88d914bf5a3" -and
        [string]$Record.implementation_path -ceq
            "sdk/turning/r23d37_mujoco_policy_seed_isolation_implementation_v1.json" -and
        (Get-DigestProperty $Record "implementation_raw_sha256" "implementation_sha256") -ceq
            "sha256:aa1c36cb5018608a71d39dd39455cf94de57f2ab91b7c9408dc89c6126f288c4" -and
        [string]$Record.campaign_attestation_manifest_path -ceq
            "sdk/turning/r23d37_campaign_attestation_manifest_v1.json" -and
        (Get-DigestProperty $Record "campaign_attestation_manifest_raw_sha256" "campaign_attestation_manifest_sha256") -ceq
            "sha256:166199ab293f579619bc5e6a203fc21b67bcd69c9521aa695a30f7125bc4a33a" -and
        [string]$Record.closure_path -ceq
            "sdk/turning/r23d37_mujoco_policy_seed_isolation_closure_v1.json" -and
        (Get-DigestProperty $Record "closure_raw_sha256" "closure_sha256") -ceq
            $ClosureHash -and
        [string]$Record.closure_audit_path -ceq
            "tests/test_qsdk_r23d37_closure.ps1" -and
        (Get-DigestProperty $Record "closure_audit_raw_sha256" "closure_audit_sha256") -ceq
            $ClosureAuditHash -and
        [string]$Record.release_matrix_audit_path -ceq
            "tests/test_qsdk_r23d37_release_matrix.ps1" -and
        (Get-DigestProperty $Record "release_matrix_audit_raw_sha256" "release_matrix_audit_sha256") -ceq
            $ReleaseAuditHash -and
        [string]$Record.physical_source_commit -ceq
            "1235008d7da676e619e17b50f98735965c5a44e7" -and
        [string]$Record.attempt_id -ceq "fe75493747d544559be7db1356972b0c" -and
        [int]$Record.outcome_exposed_seed -eq 21507 -and
        -not [bool]$Record.fresh_held_out_condition_consumed -and
        [int]$Record.qualification_gate_count -eq 19 -and
        [double]$Record.qualification_duration_seconds -eq 109.0568863 -and
        [int]$Record.source_binding_count -eq 63 -and
        [int]$Record.declared_cell_count -eq 1 -and
        [int]$Record.terminal_cell_count -eq 1 -and
        [int]$Record.world_attempt_count -eq 1 -and
        [int]$Record.world_build_count -eq 1 -and
        [int]$Record.trace_count -eq 1 -and
        [int]$Record.trace_row_count -eq 2992 -and
        [string]$Record.official_classification -ceq
            "valid_complete_negative_policy_seed_isolation" -and
        [bool]$Record.scientific_selector_legally_completed -and
        [string]$Record.terminal_manifest_json_type -ceq "array" -and
        [bool]$Record.strict_array_boundary_physically_held -and
        [int]$Record.first_policy_difference_semantic_step -eq 134 -and
        [int]$Record.first_state_difference_semantic_step -eq 135 -and
        [int]$Record.first_torso_ground_contact_semantic_step -eq 193 -and
        [double]$Record.final_forward_displacement_m -eq -0.5908297647386241 -and
        [double]$Record.maximum_tilt_rad -eq 1.8316205777362669 -and
        [double]$Record.minimum_torso_height_m -eq 0.2507483361149111 -and
        [int]$Record.torso_ground_contact_step_count -eq 2785 -and
        [int]$Record.contact_cycle_count_by_limb.front_left -eq 0 -and
        [int]$Record.contact_cycle_count_by_limb.front_right -eq 0 -and
        [int]$Record.contact_cycle_count_by_limb.rear_left -eq 18 -and
        [int]$Record.contact_cycle_count_by_limb.rear_right -eq 25 -and
        (@($Record.failed_frozen_gate_ids) -join ',') -ceq
            "R23D34_FORWARD_DISPLACEMENT,R23D34_MAXIMUM_TILT,R23D34_CONTACT_CYCLES,R23D34_TORSO_GROUND_CONTACT" -and
        [bool]$Record.one_shot_identity_consumed -and
        -not [bool]$Record.same_identity_rerun_allowed -and
        -not [bool]$Record.successor_campaign_opened -and
        -not [bool]$Record.finite_mujoco_r23d21_seed_21507_walking -and
        -not [bool]$Record.r23d21_to_r23d29_policy_change_is_sufficient_cause_of_failure -and
        [bool]$Record.fixture_sensitive_baseline_stabilization_required_before_turning -and
        -not [bool]$Record.native_mujoco_r23d29_walking -and
        -not [bool]$Record.native_mujoco_r23d29_turning -and
        -not [bool]$Record.portable_basic_turning -and
        -not [bool]$Record.finite_three_engine_turning -and
        -not [bool]$Record.cross_engine_equivalence -and
        -not [bool]$Record.q_sdk_r23_satisfied -and
        -not [bool]$Record.physical_acceptance_authority
    ) "R23D37 record changed"
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
Assert-R23D37Matrix (
    $turningGate.Count -eq 1 -and
    [string]$turningGate[0].proof.kind -ceq "missing" -and
    -not [string]::IsNullOrWhiteSpace(
        [string]$turningGate[0].proof.current_successor_status
    )
) "QSDK-R23 boundary changed"

$releaseRecords = @(Find-NamedProperty $release "closed_r23d37_attempt")
$matrixRecords = @(Find-NamedProperty $matrix "closed_r23d37_attempt")
Assert-R23D37Matrix ($releaseRecords.Count -eq 1) (
    "expected one release-contract R23D37 record; got $($releaseRecords.Count)"
)
Assert-R23D37Matrix ($matrixRecords.Count -eq 1) (
    "expected one support-matrix R23D37 record; got $($matrixRecords.Count)"
)
Assert-R23D37Record $releaseRecords[0].value $closureHash $closureAuditHash $releaseAuditHash
Assert-R23D37Record $matrixRecords[0].value $closureHash $closureAuditHash $releaseAuditHash

Assert-R23D37Matrix (
    [string]$releaseRecords[0].value.scoped_attestation_sha256 -ceq
        "sha256:5ddf991e5f0af3b9be4a9d3d6554f38e2dd641a0ac668214ac2bb91d1e9c0b32" -and
    [string]$releaseRecords[0].value.adoption_sha256 -ceq
        "sha256:076925bf0afc1e9d8ebfb22b49a4a3974d8d8f07c4ddb1d89515aeeab3911513" -and
    [string]$releaseRecords[0].value.completion_sha256 -ceq
        "sha256:162e9c42bbb09b5b6f624c2af97087b51f389dd9b276662d69236f5c0acd0d06" -and
    [string]$releaseRecords[0].value.terminal_manifest_sha256 -ceq
        "sha256:fa5411442048f6635351eeb5ac86d10b0779376e613971d04d4a1baf6dd9eb28" -and
    [string]$releaseRecords[0].value.terminal_sha256 -ceq
        "sha256:fe4444753650c74b37b4a360b70fb58146be8bdde25f2de64343b9df121a5715" -and
    [string]$releaseRecords[0].value.trace_sha256 -ceq
        "sha256:8e823fe8a07049786d1d6b0f9718d9c346d4633fb526981f126d04f75d3f15e8" -and
    [string]$matrixRecords[0].value.scoped_attestation_sha256 -ceq
        [string]$releaseRecords[0].value.scoped_attestation_sha256 -and
    [string]$matrixRecords[0].value.adoption_sha256 -ceq
        [string]$releaseRecords[0].value.adoption_sha256 -and
    [string]$matrixRecords[0].value.completion_sha256 -ceq
        [string]$releaseRecords[0].value.completion_sha256 -and
    [string]$matrixRecords[0].value.terminal_manifest_sha256 -ceq
        [string]$releaseRecords[0].value.terminal_manifest_sha256 -and
    [string]$matrixRecords[0].value.terminal_sha256 -ceq
        [string]$releaseRecords[0].value.terminal_sha256 -and
    [string]$matrixRecords[0].value.trace_sha256 -ceq
        [string]$releaseRecords[0].value.trace_sha256 -and
    -not [bool]$closure.claims.finite_mujoco_r23d21_seed_21507_walking -and
    -not [bool]$closure.claims.finite_three_engine_turning
) "retained evidence or release boundary changed"

Assert-R23D37Matrix (
    [bool]$turningGate[0].required_for_release -and
    -not [bool]$matrix.claim_boundary.command_conditioned_turning -and
    -not [bool]$matrix.claim_boundary.formal_cross_engine_comparative_inference -and
    -not [bool]$matrix.claim_boundary.submission_ready -and
    -not [bool]$matrix.claim_boundary.physical_acceptance_authority
) "negative R23D37 result was over-promoted"

Write-Output (
    "QSDK_R23D37_RELEASE_MATRIX_PASS official=valid_negative array=True " +
    "mujoco_seed_21507_walking=False portable_three_engine=False qsdk_r23=False release=False"
)
