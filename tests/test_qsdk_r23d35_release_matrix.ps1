#requires -Version 7.0

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$releaseContractPath = Join-Path $repoRoot "sdk\release\quadruped_release_contract.json"
$supportMatrixPath = Join-Path $repoRoot "sdk\release\quadruped_support_matrix.json"
$closurePath = Join-Path $repoRoot (
    "sdk\turning\r23d35_godot_trace_recovery_closure_v1.json"
)

function Assert-R23D35Matrix([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "QSDK-R23D35 RELEASE MATRIX: $Message" }
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
    } elseif ($Node -is [System.Collections.IEnumerable] -and
        -not ($Node -is [string])) {
        $index = 0
        foreach ($item in $Node) {
            $found += @(Find-NamedProperty $item $Name "$Path[$index]")
            $index += 1
        }
    }
    return $found
}

function Assert-R23D35Record($record, [string]$ExpectedClosureHash) {
    $closureDigestProperties = @($record.PSObject.Properties | Where-Object {
        [string]$_.Name -ceq "closure_raw_sha256" -or
        [string]$_.Name -ceq "closure_sha256"
    })
    Assert-R23D35Matrix (
        $closureDigestProperties.Count -eq 1 -and
        [string]$record.gate_id -ceq "QSDK-R23D35" -and
        [string]$record.campaign_id -ceq
            "QSDK-R23D35-GODOT-R23D29-TRACE-RECOVERY" -and
        [string]$record.status -ceq
            "closed_valid_complete_positive_finite_godot_jolt_r23d29_turning" -and
        [string]$record.closure_path -ceq
            "sdk/turning/r23d35_godot_trace_recovery_closure_v1.json" -and
        [string]$closureDigestProperties[0].Value -ceq $ExpectedClosureHash -and
        [string]$record.physical_source_commit -ceq
            "0649041bf0696c8e879d0238f379edca617eddb4" -and
        [string]$record.attempt_id -ceq "75215456798a49dea56670b9c25a1a0f" -and
        [int]$record.fresh_seed -eq 21507 -and
        [int]$record.qualification_gate_count -eq 17 -and
        [int]$record.declared_cell_count -eq 3 -and
        [int]$record.terminal_cell_count -eq 3 -and
        [int]$record.world_attempt_count -eq 3 -and
        [int]$record.world_build_count -eq 3 -and
        [int]$record.execution_valid_cell_count -eq 3 -and
        [int]$record.common_physical_gate_pass_count -eq 3 -and
        [int]$record.worker_failure_count -eq 0 -and
        [int]$record.trace_count -eq 3 -and
        [int]$record.trace_row_count -eq 8976 -and
        [int]$record.native_motor_application_count -eq 71808 -and
        [int]$record.adapter_mismatch_count -eq 0 -and
        [int]$record.safe_no_actuation_count -eq 0 -and
        [double]$record.positive_reference_conditioned_cycle_shift_rad -eq
            0.10734008848258458 -and
        [double]$record.negative_reference_conditioned_cycle_shift_rad -eq
            0.27183283705480754 -and
        [double]$record.bilateral_reference_conditioned_cycle_separation_rad -eq
            0.3791729255373921 -and
        [bool]$record.raw_signed_cycle_shift_gate_passed -and
        [bool]$record.reference_conditioned_cycle_shift_gate_passed -and
        -not [bool]$record.every_terminal_swing_raw_direction_passed -and
        -not [bool]$record.every_terminal_swing_reference_conditioned_direction_passed -and
        [bool]$record.one_shot_identity_consumed -and
        -not [bool]$record.same_identity_rerun_allowed -and
        [bool]$record.native_godot_jolt_r23d29_walking -and
        [bool]$record.native_godot_jolt_r23d29_turning -and
        -not [bool]$record.native_mujoco_r23d29_walking -and
        -not [bool]$record.native_mujoco_r23d29_turning -and
        -not [bool]$record.portable_basic_turning -and
        -not [bool]$record.finite_three_engine_turning -and
        -not [bool]$record.cross_engine_equivalence -and
        -not [bool]$record.q_sdk_r23_satisfied -and
        -not [bool]$record.physical_acceptance_authority
    ) "R23D35 record changed"
}

$release = Get-Content -Raw -LiteralPath $releaseContractPath |
    ConvertFrom-Json -Depth 100
$matrix = Get-Content -Raw -LiteralPath $supportMatrixPath |
    ConvertFrom-Json -Depth 100
$closure = Get-Content -Raw -LiteralPath $closurePath |
    ConvertFrom-Json -Depth 100
$closureHash = Get-Sha256 $closurePath

$turningGate = @($release.gates | Where-Object {
    [string]$_.gate_id -ceq "QSDK-R23"
})
Assert-R23D35Matrix (
    $turningGate.Count -eq 1 -and
    [string]$turningGate[0].proof.kind -ceq "missing" -and
    -not [string]::IsNullOrWhiteSpace(
        [string]$turningGate[0].proof.current_successor_status
    )
) "QSDK-R23 boundary changed"

$releaseRecords = @(Find-NamedProperty $release "closed_r23d35_attempt")
$matrixRecords = @(Find-NamedProperty $matrix "closed_r23d35_attempt")
Assert-R23D35Matrix ($releaseRecords.Count -eq 1) (
    "expected one release-contract R23D35 record; got $($releaseRecords.Count)"
)
Assert-R23D35Matrix ($matrixRecords.Count -eq 1) (
    "expected one support-matrix R23D35 record; got $($matrixRecords.Count)"
)
Assert-R23D35Record $releaseRecords[0].value $closureHash
Assert-R23D35Record $matrixRecords[0].value $closureHash

Assert-R23D35Matrix (
    [string]$releaseRecords[0].value.report_sha256 -ceq
        "sha256:0b715c4eac4d798b0970275989cb5c84f71dbafaa41d35d1b6318575f2e6961b" -and
    [string]$releaseRecords[0].value.completion_sha256 -ceq
        "sha256:f38ec13704bd627d09e5c698b1a656cf58938529bae310de3cb6447db5591098" -and
    [string]$matrixRecords[0].value.report_sha256 -ceq
        "sha256:0b715c4eac4d798b0970275989cb5c84f71dbafaa41d35d1b6318575f2e6961b" -and
    [string]$matrixRecords[0].value.completion_sha256 -ceq
        "sha256:f38ec13704bd627d09e5c698b1a656cf58938529bae310de3cb6447db5591098" -and
    [bool]$closure.claims.native_godot_jolt_r23d29_turning -and
    -not [bool]$closure.claims.finite_three_engine_turning
) "retained evidence or release boundary changed"

# QSDK-R23 stays required and unsatisfied. The finite Godot/Jolt result must not
# silently promote the product-level or comparative claims.
Assert-R23D35Matrix (
    [bool]$turningGate[0].required_for_release -and
    -not [bool]$matrix.claim_boundary.command_conditioned_turning -and
    -not [bool]$matrix.claim_boundary.formal_cross_engine_comparative_inference -and
    -not [bool]$matrix.claim_boundary.submission_ready -and
    -not [bool]$matrix.claim_boundary.physical_acceptance_authority
) "finite Godot/Jolt evidence was over-promoted"

Write-Output (
    "QSDK_R23D35_RELEASE_MATRIX_PASS finite_godot_jolt=True " +
    "mujoco=False portable_three_engine=False qsdk_r23=False release=False"
)
