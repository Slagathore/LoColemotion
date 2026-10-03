#requires -Version 7.0

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$releaseContractPath = Join-Path $repoRoot "sdk\release\quadruped_release_contract.json"
$supportMatrixPath = Join-Path $repoRoot "sdk\release\quadruped_support_matrix.json"
$closurePath = Join-Path $repoRoot (
    "sdk\turning\r23d39_mujoco_startup_ramp_turning_closure_v1.json"
)
$closureAuditPath = Join-Path $repoRoot "tests\test_qsdk_r23d39_closure.ps1"

function Assert-R23D39Matrix([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "QSDK-R23D39 RELEASE MATRIX: $Message" }
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
    Assert-R23D39Matrix ($properties.Count -eq 1) (
        "expected exactly one $RawName/$MatrixName property"
    )
    return [string]$properties[0].Value
}

function Assert-R23D39Record(
    $Record,
    [string]$ClosureHash,
    [string]$ClosureAuditHash,
    [string]$ReleaseAuditHash
) {
    Assert-R23D39Matrix (
        [string]$Record.gate_id -ceq "QSDK-R23D39" -and
        [string]$Record.campaign_id -ceq
            "QSDK-R23D39-MUJOCO-R23D29-STARTUP-RAMP-TURNING-DEVELOPMENT" -and
        [string]$Record.status -ceq
            "closed_consumed_valid_complete_positive_mujoco_startup_ramp_turning_development" -and
        [string]$Record.preregistration_path -ceq
            "sdk/turning/r23d39_mujoco_startup_ramp_turning_preregistration_v1.json" -and
        (Get-DigestProperty $Record "preregistration_raw_sha256" "preregistration_sha256") -ceq
            "sha256:8513e78988c7561d73f5197081d504eb612f3f5c3935e2801f20cca6884b76d1" -and
        [string]$Record.implementation_path -ceq
            "sdk/turning/r23d39_mujoco_startup_ramp_turning_implementation_v1.json" -and
        (Get-DigestProperty $Record "implementation_raw_sha256" "implementation_sha256") -ceq
            "sha256:1aed8679e05e97e90accae7ed4f96ea211da9c64c03ee305ce3522571218a5a5" -and
        [string]$Record.campaign_attestation_manifest_path -ceq
            "sdk/turning/r23d39_campaign_attestation_manifest_v1.json" -and
        (Get-DigestProperty $Record "campaign_attestation_manifest_raw_sha256" "campaign_attestation_manifest_sha256") -ceq
            "sha256:7429da8ea35e361c3da75ad00107bd6d813b91d3e8eec60a09abbc5b07ff5d5c" -and
        [string]$Record.closure_path -ceq
            "sdk/turning/r23d39_mujoco_startup_ramp_turning_closure_v1.json" -and
        (Get-DigestProperty $Record "closure_raw_sha256" "closure_sha256") -ceq
            $ClosureHash -and
        [string]$Record.closure_audit_path -ceq
            "tests/test_qsdk_r23d39_closure.ps1" -and
        (Get-DigestProperty $Record "closure_audit_raw_sha256" "closure_audit_sha256") -ceq
            $ClosureAuditHash -and
        [string]$Record.release_matrix_audit_path -ceq
            "tests/test_qsdk_r23d39_release_matrix.ps1" -and
        (Get-DigestProperty $Record "release_matrix_audit_raw_sha256" "release_matrix_audit_sha256") -ceq
            $ReleaseAuditHash -and
        [string]$Record.physical_source_commit -ceq
            "3bc7b735155dedbe6657161a62537669396536f4" -and
        [string]$Record.attempt_id -ceq "4db8fe11de69444e81efada5f06fe0a5" -and
        [int]$Record.outcome_exposed_seed -eq 21507 -and
        -not [bool]$Record.fresh_held_out_condition_consumed -and
        [int]$Record.qualification_gate_count -eq 17 -and
        [double]$Record.qualification_duration_seconds -eq 87.7164176 -and
        [int]$Record.source_binding_count -eq 71 -and
        [int]$Record.declared_cell_count -eq 3 -and
        [int]$Record.terminal_cell_count -eq 3 -and
        [int]$Record.world_attempt_count -eq 3 -and
        [int]$Record.world_build_count -eq 3 -and
        [int]$Record.trace_count -eq 3 -and
        [int]$Record.total_trace_row_count -eq 8976 -and
        [string]$Record.official_classification -ceq
            "valid_complete_positive_mujoco_startup_ramp_turning_development" -and
        [bool]$Record.scientific_selector_legally_completed -and
        [bool]$Record.outcome_exposed_development_screen -and
        [string]$Record.terminal_manifest_json_type -ceq "array" -and
        [bool]$Record.strict_array_boundary_physically_held -and
        [string]$Record.controller_policy_id -ceq
            "sporespore_balanced_wave_r23d29_two_swing_persistent_predictive_stability_guarded_steering_v1" -and
        [string]$Record.startup_ramp_id -ceq
            "canonical_velocity_smoothstep_one_gait_cycle_v1" -and
        [int]$Record.startup_ramp_step_count_per_cell -eq 360 -and
        [int]$Record.startup_ramp_active_step_count_per_cell -eq 359 -and
        [int]$Record.total_validated_portable_command_count -eq 71808 -and
        [int]$Record.total_native_actuation_application_count -eq 71808 -and
        [double]$Record.reference_cycle_shift_rad -eq 0.02571594605998328 -and
        [double]$Record.positive_cycle_shift_rad -eq 0.15406003781125227 -and
        [double]$Record.negative_cycle_shift_rad -eq -0.12975612368862077 -and
        [double]$Record.positive_reference_conditioned_cycle_shift_rad -eq
            0.12834409175126898 -and
        [double]$Record.negative_reference_conditioned_cycle_shift_rad -eq
            0.15547206974860406 -and
        [double]$Record.bilateral_reference_conditioned_cycle_separation_rad -eq
            0.28381616149987304 -and
        [bool]$Record.raw_signed_cycle_shift_passed -and
        [bool]$Record.reference_conditioned_cycle_shift_passed -and
        [bool]$Record.every_terminal_swing_raw_direction -and
        [bool]$Record.every_terminal_swing_reference_conditioned_direction -and
        @($Record.cells.PSObject.Properties).Count -eq 3 -and
        [bool]$Record.one_shot_identity_consumed -and
        -not [bool]$Record.same_identity_rerun_allowed -and
        -not [bool]$Record.successor_campaign_opened -and
        [bool]$Record.finite_mujoco_r23d29_seed_21507_startup_ramp_walking -and
        [bool]$Record.finite_mujoco_r23d29_seed_21507_startup_ramp_turning -and
        [bool]$Record.separate_finite_turning_positives_on_all_three_engines -and
        -not [bool]$Record.unified_fresh_three_engine_turning_validation -and
        -not [bool]$Record.portable_basic_turning -and
        -not [bool]$Record.finite_three_engine_turning -and
        -not [bool]$Record.cross_engine_equivalence -and
        -not [bool]$Record.q_sdk_r23_satisfied -and
        -not [bool]$Record.physical_acceptance_authority
    ) "R23D39 record changed"
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
Assert-R23D39Matrix (
    $turningGate.Count -eq 1 -and
    [string]$turningGate[0].proof.kind -ceq "missing" -and
    -not [string]::IsNullOrWhiteSpace(
        [string]$turningGate[0].proof.current_successor_status
    )
) "QSDK-R23 boundary changed"

$releaseRecords = @(Find-NamedProperty $release "closed_r23d39_attempt")
$matrixRecords = @(Find-NamedProperty $matrix "closed_r23d39_attempt")
Assert-R23D39Matrix ($releaseRecords.Count -eq 1) (
    "expected one release-contract R23D39 record; got $($releaseRecords.Count)"
)
Assert-R23D39Matrix ($matrixRecords.Count -eq 1) (
    "expected one support-matrix R23D39 record; got $($matrixRecords.Count)"
)
Assert-R23D39Record $releaseRecords[0].value $closureHash $closureAuditHash $releaseAuditHash
Assert-R23D39Record $matrixRecords[0].value $closureHash $closureAuditHash $releaseAuditHash

foreach ($property in @(
    "scoped_attestation_sha256", "adoption_sha256", "report_sha256",
    "completion_sha256", "terminal_manifest_sha256",
    "complete_evaluation_sha256"
)) {
    Assert-R23D39Matrix (
        [string]$matrixRecords[0].value.$property -ceq
            [string]$releaseRecords[0].value.$property
    ) "release/support evidence digest differs: $property"
}
foreach ($armId in @("reference_zero", "positive_heading", "negative_heading")) {
    foreach ($property in @("terminal_sha256", "trace_sha256", "pending_rows_sha256")) {
        Assert-R23D39Matrix (
            [string]$matrixRecords[0].value.cells.$armId.$property -ceq
                [string]$releaseRecords[0].value.cells.$armId.$property
        ) "release/support cell digest differs: $armId/$property"
    }
}
Assert-R23D39Matrix (
    [string]$releaseRecords[0].value.scoped_attestation_sha256 -ceq
        "sha256:5c3d3111889ad168be99bb1e1bc478c7d090c7fb40d27d3cfb0c159989a3e3db" -and
    [string]$releaseRecords[0].value.adoption_sha256 -ceq
        "sha256:f4de79def05d3c4904fece945a405774351058f390d260f3a9a930d4660e51d4" -and
    [string]$releaseRecords[0].value.report_sha256 -ceq
        "sha256:2558043051a720da95435232ca31220aa8ea3fc61c76247f6db1b5c712afd0c3" -and
    [string]$releaseRecords[0].value.completion_sha256 -ceq
        "sha256:ae746eb2ba934993d3f79ac46b5fdfa715161f3993a09f0953f0a24973bdb439" -and
    [string]$releaseRecords[0].value.terminal_manifest_sha256 -ceq
        "sha256:9f71931dbdda41429882c0ec2a99b6c5870343df020c3d9c06e7ab5bf75c024d" -and
    [string]$releaseRecords[0].value.complete_evaluation_sha256 -ceq
        "sha256:e1e0f9de22e092cacb0b64975dfa37cb235f8caacab80746c038d95f8bdf5936" -and
    [bool]$turningGate[0].required_for_release -and
    -not [bool]$matrix.claim_boundary.command_conditioned_turning -and
    -not [bool]$matrix.claim_boundary.formal_cross_engine_comparative_inference -and
    -not [bool]$matrix.claim_boundary.submission_ready -and
    -not [bool]$matrix.claim_boundary.physical_acceptance_authority -and
    [bool]$closure.claims.separate_finite_turning_positives_on_all_three_engines -and
    -not [bool]$closure.claims.finite_three_engine_turning
) "retained evidence or release claim boundary changed"

Write-Output (
    "QSDK_R23D39_RELEASE_MATRIX_PASS official=valid_positive " +
    "finite_mujoco_turning=True separate_three_engine_positives=True " +
    "unified_three_engine_validation=False qsdk_r23=False release=False"
)
