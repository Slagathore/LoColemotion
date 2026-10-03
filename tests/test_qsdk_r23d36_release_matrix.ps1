#requires -Version 7.0

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$releaseContractPath = Join-Path $repoRoot "sdk\release\quadruped_release_contract.json"
$supportMatrixPath = Join-Path $repoRoot "sdk\release\quadruped_support_matrix.json"
$closurePath = Join-Path $repoRoot (
    "sdk\turning\r23d36_mujoco_bw19v_walking_restoration_closure_v1.json"
)
$closureAuditPath = Join-Path $repoRoot "tests\test_qsdk_r23d36_closure.ps1"

function Assert-R23D36Matrix([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "QSDK-R23D36 RELEASE MATRIX: $Message" }
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
    Assert-R23D36Matrix ($properties.Count -eq 1) (
        "expected exactly one $RawName/$MatrixName property"
    )
    return [string]$properties[0].Value
}

function Assert-R23D36Record(
    $Record,
    [string]$ClosureHash,
    [string]$ClosureAuditHash,
    [string]$ReleaseAuditHash
) {
    Assert-R23D36Matrix (
        [string]$Record.gate_id -ceq "QSDK-R23D36" -and
        [string]$Record.campaign_id -ceq
            "QSDK-R23D36-MUJOCO-R23D29-BW19V-WALKING-RESTORATION" -and
        [string]$Record.status -ceq
            "closed_consumed_invalid_supervisor_manifest_shape_with_retained_non_authoritative_physical_negative" -and
        [string]$Record.closure_path -ceq
            "sdk/turning/r23d36_mujoco_bw19v_walking_restoration_closure_v1.json" -and
        (Get-DigestProperty $Record "closure_raw_sha256" "closure_sha256") -ceq
            $ClosureHash -and
        [string]$Record.closure_audit_path -ceq
            "tests/test_qsdk_r23d36_closure.ps1" -and
        (Get-DigestProperty $Record "closure_audit_raw_sha256" "closure_audit_sha256") -ceq
            $ClosureAuditHash -and
        [string]$Record.release_matrix_audit_path -ceq
            "tests/test_qsdk_r23d36_release_matrix.ps1" -and
        (Get-DigestProperty $Record "release_matrix_audit_raw_sha256" "release_matrix_audit_sha256") -ceq
            $ReleaseAuditHash -and
        [string]$Record.physical_source_commit -ceq
            "d7036b5ff91d9ad2f4dfaa3ccc71ac161cc67b28" -and
        [string]$Record.attempt_id -ceq "332a9294ea6f42a396fcd9f5f376b4cc" -and
        [int]$Record.fresh_seed -eq 21507 -and
        [int]$Record.qualification_gate_count -eq 18 -and
        [int]$Record.declared_cell_count -eq 1 -and
        [int]$Record.terminal_cell_count -eq 1 -and
        [int]$Record.world_attempt_count -eq 1 -and
        [int]$Record.world_build_count -eq 1 -and
        [int]$Record.trace_count -eq 1 -and
        [int]$Record.trace_row_count -eq 2992 -and
        [string]$Record.official_classification -ceq
            "invalid_or_incomplete_first_attempt" -and
        -not [bool]$Record.scientific_selector_legally_completed -and
        [string]$Record.retained_physical_diagnostic_classification -ceq
            "valid_complete_negative_mujoco_walking_restoration" -and
        -not [bool]$Record.retained_physical_diagnostic_authoritative -and
        [int]$Record.stability_planning_available_step_count -eq 9 -and
        [int]$Record.stability_plan_active_step_count -eq 0 -and
        [int]$Record.stability_nonzero_residual_step_count -eq 9 -and
        [int]$Record.first_torso_ground_contact_semantic_step -eq 192 -and
        [double]$Record.final_forward_displacement_m -eq -0.6249710048622591 -and
        [double]$Record.maximum_tilt_rad -eq 1.865506956107064 -and
        [double]$Record.minimum_torso_height_m -eq 0.2508240260659109 -and
        [int]$Record.torso_ground_contact_step_count -eq 2782 -and
        (@($Record.failed_frozen_gate_ids) -join ',') -ceq
            "R23D36_FORWARD_DISPLACEMENT,R23D36_MAXIMUM_TILT,R23D36_CONTACT_CYCLES,R23D36_TORSO_GROUND_CONTACT" -and
        [bool]$Record.one_shot_identity_consumed -and
        -not [bool]$Record.same_identity_rerun_allowed -and
        -not [bool]$Record.successor_campaign_opened -and
        -not [bool]$Record.mujoco_r23d29_bw19v_walking_restoration -and
        -not [bool]$Record.native_mujoco_r23d29_walking -and
        -not [bool]$Record.native_mujoco_r23d29_turning -and
        -not [bool]$Record.portable_basic_turning -and
        -not [bool]$Record.finite_three_engine_turning -and
        -not [bool]$Record.cross_engine_equivalence -and
        -not [bool]$Record.q_sdk_r23_satisfied -and
        -not [bool]$Record.physical_acceptance_authority
    ) "R23D36 record changed"
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
Assert-R23D36Matrix (
    $turningGate.Count -eq 1 -and
    [string]$turningGate[0].proof.kind -ceq "missing" -and
    -not [string]::IsNullOrWhiteSpace(
        [string]$turningGate[0].proof.current_successor_status
    )
) "QSDK-R23 boundary changed"

$releaseRecords = @(Find-NamedProperty $release "closed_r23d36_attempt")
$matrixRecords = @(Find-NamedProperty $matrix "closed_r23d36_attempt")
Assert-R23D36Matrix ($releaseRecords.Count -eq 1) (
    "expected one release-contract R23D36 record; got $($releaseRecords.Count)"
)
Assert-R23D36Matrix ($matrixRecords.Count -eq 1) (
    "expected one support-matrix R23D36 record; got $($matrixRecords.Count)"
)
Assert-R23D36Record $releaseRecords[0].value $closureHash $closureAuditHash $releaseAuditHash
Assert-R23D36Record $matrixRecords[0].value $closureHash $closureAuditHash $releaseAuditHash

Assert-R23D36Matrix (
    [string]$releaseRecords[0].value.completion_sha256 -ceq
        "sha256:7e91a2dfdc2ddce8fba71b94b2837a708e65bba1e94d0cdd85af608e62d953e7" -and
    [string]$releaseRecords[0].value.terminal_sha256 -ceq
        "sha256:ce805a03c452519a8cb33360f2b25285ebb86b8491edeaff49ee1c0c5593ed91" -and
    [string]$releaseRecords[0].value.trace_sha256 -ceq
        "sha256:7bd88831608f8265cd44bb90d88e48d09d1d019f71942c0750eae3d19d8d562b" -and
    [string]$matrixRecords[0].value.completion_sha256 -ceq
        "sha256:7e91a2dfdc2ddce8fba71b94b2837a708e65bba1e94d0cdd85af608e62d953e7" -and
    [string]$matrixRecords[0].value.terminal_sha256 -ceq
        "sha256:ce805a03c452519a8cb33360f2b25285ebb86b8491edeaff49ee1c0c5593ed91" -and
    [string]$matrixRecords[0].value.trace_sha256 -ceq
        "sha256:7bd88831608f8265cd44bb90d88e48d09d1d019f71942c0750eae3d19d8d562b" -and
    -not [bool]$closure.claims.mujoco_r23d29_bw19v_walking_restoration -and
    -not [bool]$closure.claims.finite_three_engine_turning
) "retained evidence or release boundary changed"

Assert-R23D36Matrix (
    [bool]$turningGate[0].required_for_release -and
    -not [bool]$matrix.claim_boundary.command_conditioned_turning -and
    -not [bool]$matrix.claim_boundary.formal_cross_engine_comparative_inference -and
    -not [bool]$matrix.claim_boundary.submission_ready -and
    -not [bool]$matrix.claim_boundary.physical_acceptance_authority
) "invalid R23D36 attempt or retained diagnostic was over-promoted"

Write-Output (
    "QSDK_R23D36_RELEASE_MATRIX_PASS official=invalid diagnostic=negative " +
    "mujoco_walking=False portable_three_engine=False qsdk_r23=False release=False"
)
