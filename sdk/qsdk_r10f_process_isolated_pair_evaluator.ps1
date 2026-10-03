#requires -Version 7.0

<#
Pure QSDK-R10F-L14 process-population validator and matched-arm evaluator.

This file never starts Godot, constructs a model, reads native state, or steps
a solver. The supervisor supplies two already-terminated child envelopes. We
first validate each child and the serialized process population, then (and
only then) compare the retained role-local interaction measurements. Global
solver steps remain child-local source values; pair alignment uses the frozen
interaction-local step and walking-session-local evidence.
#>

$script:QsdkR10fL9GateId = "QSDK-R10F"
$script:QsdkR10fL9RepairId = "QSDK-R10F-L14"
$script:QsdkR10fL9WorkId = "QSDK-R10F-L14-GODOT-JOLT-PROCESS-ISOLATED-CHILD-DEVELOPMENT"
$script:QsdkR10fL9ChildContractRepairId = "QSDK-R10F-L9"
$script:QsdkR10fL11ReleaseRepairId = "QSDK-R10F-L11"
$script:QsdkR10fL9BaselineRole = "matched_no_kick_continuation"
$script:QsdkR10fL9ActiveRole = "kick_passive_recovery_resume"
$script:QsdkR10fL9Roles = @(
    $script:QsdkR10fL9BaselineRole,
    $script:QsdkR10fL9ActiveRole
)
$script:QsdkR10fL9RawSchema = "sporespore_qsdk_r10f_process_isolated_child_raw_v1"
$script:QsdkR10fL9ArmResultSchema = (
    "sporespore_qsdk_r10f_l9_process_isolated_arm_result_v1"
)
$script:QsdkR10fL9TraceSchema = (
    "sporespore_qsdk_r10f_l9_process_isolated_compact_native_trace_v1"
)
$script:QsdkR10fL9PreconditionSchema = (
    "sporespore_qsdk_r10f_l9_process_isolated_precondition_terminal_receipt_v1"
)
$script:QsdkR10fL9ReleaseSchema = (
    "sporespore_qsdk_r10f_l11_process_isolated_precondition_release_receipt_v1"
)
$script:QsdkR10fL11ReleaseOwnerSourceSchema = (
    "sporespore_qsdk_r10f_l11_precondition_release_owner_source_projection_v1"
)
$script:QsdkR10fL12HandoffSchema = (
    "sporespore_qsdk_r10f_l12_walking_actuation_handoff_receipt_v1"
)
$script:QsdkR10fL12HostCapBindingSchema = (
    "sporespore_qsdk_r10f_l12_walking_host_cap_projection_binding_v1"
)
$script:QsdkR10fL12MotorConfigurationSchema = (
    "sporespore_qsdk_r10f_recovery_native_motor_configuration_v1"
)
$script:QsdkR10fL12MotorReadbackSchema = (
    "sporespore_qsdk_r10f_recovery_native_motor_population_readback_v1"
)
$script:QsdkR10fL12ProjectionId = (
    "godot_jolt_binary32_native_effective_impulse_limit_inverse_projection_v1"
)
$script:QsdkR10fL12ProjectionScope = (
    "exact_s169_published_actuator_profile_at_120_hz_only"
)
$script:QsdkR10fL12FacadeId = (
    "sporespore_qsdk_r10f_recovery_native_s169_locomotion_facade_v1"
)
$script:QsdkR10fL12ActuatorIds = @(
    "front_left_hip_motor", "front_left_knee_motor",
    "front_right_hip_motor", "front_right_knee_motor",
    "rear_left_hip_motor", "rear_left_knee_motor",
    "rear_right_hip_motor", "rear_right_knee_motor"
)
$script:QsdkR10fL12JointIds = @(
    "front_left_hip", "front_left_knee",
    "front_right_hip", "front_right_knee",
    "rear_left_hip", "rear_left_knee",
    "rear_right_hip", "rear_right_knee"
)
$script:QsdkR10fL12PublishedCaps = @(
    0.05362625170687301, 0.4567500054836273,
    0.05362625170687301, 0.4567500054836273,
    0.05637374829312699, 0.4567500054836273,
    0.05637374829312699, 0.4567500054836273
)
$script:QsdkR10fL12HostCaps = @(
    0.05362624675035477, 0.45674997568130493,
    0.05362624675035477, 0.45674997568130493,
    0.05637374147772789, 0.45674997568130493,
    0.05637374147772789, 0.45674997568130493
)
$script:QsdkR10fL9InteractionSchema = (
    "sporespore_qsdk_r10f_l9_process_isolated_interaction_source_v1"
)
$script:QsdkR10fL9MaximumChildSolverSteps = 3842
$script:QsdkR10fL9MaximumTotalSolverSteps = 7684
$script:QsdkR10fL9DevelopmentSeed = 40200
$script:QsdkR10fL9NativeEffectFloor = 0.0001
$script:QsdkR10fL9ImpulseMagnitude = 0.25
$script:QsdkR10fL9UnitAllowance = 1.9073486328125e-6
$script:QsdkR10fL9ImpulseAllowance = 4.76837158203125e-7
$script:QsdkR10fL9PolicyId = "sporespore_balanced_wave_bw5r_b_v1"
$script:QsdkR10fL9PolicyDigest = (
    "sha256:9dfade277ff0dd28f47aa807447c51a24363ce9d10671930ae01b61273d5f59f"
)
$script:QsdkR10fL9ActuatorProfileId = (
    "sporespore_qsdk_r23d60_selected_s169_actuator_cap_profile_v1"
)
$script:QsdkR10fL9MaterialProfileId = "godot_jolt_legacy_mu180_d3d5cd1_v1"
$script:QsdkR10fL9RecoveryMorphologySha = (
    "sha256:926551af3a72eb1fd1f3b71bfb103587a0b906a116775551a2463792e2c160f9"
)
$script:QsdkR10fL9ControllerId = "sporespore_exact_s169_prone_to_standing_controller_v6"


function Test-QsdkR10fL9ExactInteger {
    param(
        [AllowNull()][object]$Value,
        [AllowNull()][object]$Expected,
        [AllowNull()][object]$Minimum,
        [AllowNull()][object]$Maximum
    )
    if ($Value -isnot [int32] -and $Value -isnot [int64]) { return $false }
    $integer = [int64]$Value
    foreach ($boundName in @("Expected", "Minimum", "Maximum")) {
        if (
            $PSBoundParameters.ContainsKey($boundName) -and
            $PSBoundParameters[$boundName] -isnot [int32] -and
            $PSBoundParameters[$boundName] -isnot [int64]
        ) { return $false }
    }
    if (
        $PSBoundParameters.ContainsKey("Expected") -and
        $integer -ne [int64]$Expected
    ) { return $false }
    if (
        $PSBoundParameters.ContainsKey("Minimum") -and
        $integer -lt [int64]$Minimum
    ) { return $false }
    if (
        $PSBoundParameters.ContainsKey("Maximum") -and
        $integer -gt [int64]$Maximum
    ) { return $false }
    return $true
}


function Test-QsdkR10fL9LowerHex {
    param([AllowNull()][object]$Value, [Parameter(Mandatory)][int]$Length)
    return (
        $Value -is [string] -and
        ([string]$Value).Length -eq $Length -and
        [string]$Value -cmatch ("^[0-9a-f]{" + $Length + "}$")
    )
}


function Test-QsdkR10fL9Sha256 {
    param([AllowNull()][object]$Value)
    return $Value -is [string] -and [string]$Value -cmatch '^sha256:[0-9a-f]{64}$'
}


function Test-QsdkR10fL9FiniteNumber {
    param([AllowNull()][object]$Value)
    if (
        $Value -is [bool] -or
        $Value -is [string] -or
        $null -eq $Value -or
        $Value -isnot [ValueType]
    ) { return $false }
    try { $number = [double]$Value } catch { return $false }
    return -not [double]::IsNaN($number) -and -not [double]::IsInfinity($number)
}


function Get-QsdkR10fL9Vector3 {
    param([AllowNull()][object]$Value)
    if ($Value -isnot [System.Collections.IList] -or $Value.Count -ne 3) { return $null }
    $result = [double[]]::new(3)
    for ($index = 0; $index -lt 3; $index++) {
        if (-not (Test-QsdkR10fL9FiniteNumber $Value[$index])) { return $null }
        $result[$index] = [double]$Value[$index]
    }
    return $result
}


function Get-QsdkR10fL9VectorNorm {
    param([Parameter(Mandatory)][double[]]$Value)
    return [Math]::Sqrt(
        $Value[0] * $Value[0] + $Value[1] * $Value[1] + $Value[2] * $Value[2]
    )
}


function Get-QsdkR10fL9VectorSubtract {
    param(
        [Parameter(Mandatory)][double[]]$Left,
        [Parameter(Mandatory)][double[]]$Right
    )
    return [double[]]@(
        ($Left[0] - $Right[0])
        ($Left[1] - $Right[1])
        $Left[2] - $Right[2]
    )
}


function Get-QsdkR10fL9VectorDot {
    param(
        [Parameter(Mandatory)][double[]]$Left,
        [Parameter(Mandatory)][double[]]$Right
    )
    return $Left[0] * $Right[0] + $Left[1] * $Right[1] + $Left[2] * $Right[2]
}


function Test-QsdkR10fL9VectorClose {
    param(
        [Parameter(Mandatory)][double[]]$Left,
        [Parameter(Mandatory)][double[]]$Right,
        [Parameter(Mandatory)][double]$Allowance
    )
    for ($index = 0; $index -lt 3; $index++) {
        if ([Math]::Abs($Left[$index] - $Right[$index]) -gt $Allowance) { return $false }
    }
    return $true
}


function Add-QsdkR10fL9ValidationError {
    param(
        [Parameter(Mandatory)][AllowEmptyCollection()]
        [System.Collections.Generic.List[string]]$Errors,
        [Parameter(Mandatory)][bool]$Condition,
        [Parameter(Mandatory)][string]$Code
    )
    if (-not $Condition) { $Errors.Add($Code) }
}


function Get-QsdkR10fL9DictionaryField {
    param(
        [AllowNull()][object]$Dictionary,
        [Parameter(Mandatory)][string]$Key
    )
    if (
        $Dictionary -is [System.Collections.IDictionary] -and
        $Dictionary.Contains($Key)
    ) { return $Dictionary[$Key] }
    return $null
}


function Test-QsdkR10fL10TerminalFailureProjection {
    param(
        [AllowNull()][object]$Memory,
        [AllowNull()][object]$TerminalPhase,
        [AllowNull()][object]$ProjectedFailureCode
    )
    if (
        $Memory -isnot [System.Collections.IDictionary] -or
        -not $Memory.Contains("phase") -or
        -not $Memory.Contains("terminal_failure_code") -or
        $TerminalPhase -isnot [string] -or
        $ProjectedFailureCode -isnot [string]
    ) { return $false }
    $sourcePhase = $Memory["phase"]
    $sourceFailureCode = $Memory["terminal_failure_code"]
    if ($sourcePhase -isnot [string] -or $sourcePhase -cne $TerminalPhase) {
        return $false
    }
    if ($TerminalPhase -ceq "complete") {
        return $null -eq $sourceFailureCode -and $ProjectedFailureCode -ceq ""
    }
    if ($TerminalPhase -cin @("failed", "refused")) {
        return (
            $sourceFailureCode -is [string] -and
            -not [string]::IsNullOrEmpty($sourceFailureCode) -and
            $ProjectedFailureCode -ceq $sourceFailureCode
        )
    }
    return $false
}


function Test-QsdkR10fL11ReleaseOwnerSource {
    param(
        [AllowNull()][object]$Source,
        [AllowNull()][object]$Terminal,
        [Parameter(Mandatory)][string]$ExpectedRole,
        [Parameter(Mandatory)][string]$ExpectedParentAttemptId,
        [Parameter(Mandatory)][string]$ExpectedChildAttemptId
    )
    if (
        $Source -isnot [System.Collections.IDictionary] -or
        $Terminal -isnot [System.Collections.IDictionary]
    ) { return $false }
    $expectedKeys = @(
        "schema_version", "gate_id", "repair_id", "parent_attempt_id",
        "child_attempt_id", "arm_id", "model_instance_id",
        "completed_terminal_global_semantic_step", "release_global_semantic_step",
        "source_kind", "precondition_terminal_receipt_sha256",
        "recovery_memory_sha256", "recovery_step_receipt_sha256",
        "source_measurement", "outcome_derived_correction",
        "physical_acceptance_authority", "release_authority", "payload_sha256"
    )
    if ($Source.Count -ne $expectedKeys.Count) { return $false }
    foreach ($key in $expectedKeys) {
        if (-not $Source.Contains($key)) { return $false }
    }
    return (
        [string]$Source.schema_version -ceq
            $script:QsdkR10fL11ReleaseOwnerSourceSchema -and
        [string]$Source.gate_id -ceq $script:QsdkR10fL9GateId -and
        [string]$Source.repair_id -ceq $script:QsdkR10fL11ReleaseRepairId -and
        [string]$Source.parent_attempt_id -ceq $ExpectedParentAttemptId -and
        [string]$Source.child_attempt_id -ceq $ExpectedChildAttemptId -and
        [string]$Source.arm_id -ceq $ExpectedRole -and
        [string]$Source.model_instance_id -ceq [string]$Terminal.model_instance_id -and
        (Test-QsdkR10fL9ExactInteger `
            $Source.completed_terminal_global_semantic_step `
            -Expected ([int64]$Terminal.completed_global_semantic_step)) -and
        (Test-QsdkR10fL9ExactInteger `
            $Source.release_global_semantic_step `
            -Expected ([int64]$Terminal.completed_global_semantic_step + 1)) -and
        [string]$Source.source_kind -ceq
            "validated_complete_precondition_release_no_actuation" -and
        [string]$Source.precondition_terminal_receipt_sha256 -ceq
            [string]$Terminal.payload_sha256 -and
        [string]$Source.recovery_memory_sha256 -ceq
            [string]$Terminal.recovery_memory_sha256 -and
        [string]$Source.recovery_step_receipt_sha256 -ceq
            [string]$Terminal.recovery_step_receipt_sha256 -and
        [bool]$Source.source_measurement -and
        -not [bool]$Source.outcome_derived_correction -and
        -not [bool]$Source.physical_acceptance_authority -and
        -not [bool]$Source.release_authority -and
        (Test-QsdkR10fL9Sha256 $Source.payload_sha256)
    )
}


function Test-QsdkR10fL12WalkingActuationHandoff {
    param(
        [AllowNull()][object]$Receipt,
        [Parameter(Mandatory)][string]$ExpectedModelInstanceId,
        [Parameter(Mandatory)][ValidateSet(
            "walking_prefix", "matched_continuation", "walking_resume"
        )][string]$ExpectedEvaluationSegment,
        [Parameter(Mandatory)][string]$ExpectedSessionId,
        [Parameter(Mandatory)][int64]$ExpectedGlobalSemanticStep
    )
    if ($Receipt -isnot [System.Collections.IDictionary]) { return $false }
    $expectedFacadeSegment = if ($ExpectedEvaluationSegment -ceq "walking_prefix") {
        "walking_prefix"
    } else { "walking_resume" }
    $configuration = Get-QsdkR10fL9DictionaryField $Receipt "motor_configuration_receipt"
    $readback = Get-QsdkR10fL9DictionaryField `
        $Receipt "precommand_motor_population_readback"
    $binding = Get-QsdkR10fL9DictionaryField $Receipt "host_cap_projection_binding"
    $orderedIds = Get-QsdkR10fL9DictionaryField $Receipt "ordered_actuator_ids"
    $publishedMap = Get-QsdkR10fL9DictionaryField $Receipt "published_cap_by_actuator_id"
    $hostMap = Get-QsdkR10fL9DictionaryField $Receipt "authorized_host_cap_by_actuator_id"
    $reason = "l12_walking_actuation_handoff_precommand:$ExpectedEvaluationSegment"
    if (
        [string]$Receipt.schema_version -cne $script:QsdkR10fL12HandoffSchema -or
        [string]$Receipt.gate_id -cne $script:QsdkR10fL9GateId -or
        -not [bool]$Receipt.ok -or
        [string]$Receipt.facade_id -cne $script:QsdkR10fL12FacadeId -or
        [string]$Receipt.model_instance_id -cne $ExpectedModelInstanceId -or
        [string]$Receipt.facade_segment_id -cne $expectedFacadeSegment -or
        [string]$Receipt.evaluation_segment_id -cne $ExpectedEvaluationSegment -or
        [string]$Receipt.walking_session_id -cne $ExpectedSessionId -or
        -not (Test-QsdkR10fL9ExactInteger $Receipt.global_semantic_step `
            -Expected $ExpectedGlobalSemanticStep) -or
        [string]$Receipt.selected_policy_id -cne $script:QsdkR10fL9PolicyId -or
        [string]$Receipt.selected_policy_digest -cne $script:QsdkR10fL9PolicyDigest -or
        $configuration -isnot [System.Collections.IDictionary] -or
        $readback -isnot [System.Collections.IDictionary] -or
        $binding -isnot [System.Collections.IDictionary] -or
        $orderedIds -isnot [System.Collections.IList] -or
        $publishedMap -isnot [System.Collections.IDictionary] -or
        $hostMap -isnot [System.Collections.IDictionary] -or
        -not (Test-QsdkR10fL9ExactInteger $Receipt.motor_enabled_count -Expected 8) -or
        -not (Test-QsdkR10fL9ExactInteger $Receipt.zero_target_velocity_count -Expected 8) -or
        -not (Test-QsdkR10fL9ExactInteger $Receipt.motor_configuration_write_count -Expected 16) -or
        -not (Test-QsdkR10fL9ExactInteger $Receipt.native_readback_count -Expected 24) -or
        -not (Test-QsdkR10fL9ExactInteger $Receipt.solver_step_count -Expected 0) -or
        -not (Test-QsdkR10fL9ExactInteger $Receipt.body_transform_write_count -Expected 0) -or
        -not (Test-QsdkR10fL9ExactInteger $Receipt.body_velocity_write_count -Expected 0) -or
        -not (Test-QsdkR10fL9ExactInteger $Receipt.body_impulse_write_count -Expected 0) -or
        -not (Test-QsdkR10fL9ExactInteger $Receipt.solver_reset_count -Expected 0) -or
        -not [bool]$Receipt.physics_state_modified -or
        [bool]$Receipt.outcome_derived_correction -or
        [bool]$Receipt.physical_acceptance_authority -or
        [bool]$Receipt.release_authority -or
        -not (Test-QsdkR10fL9Sha256 $Receipt.motor_configuration_receipt_sha256) -or
        -not (Test-QsdkR10fL9Sha256 $Receipt.precommand_motor_population_readback_sha256) -or
        -not (Test-QsdkR10fL9Sha256 $Receipt.host_cap_projection_binding_sha256) -or
        -not (Test-QsdkR10fL9Sha256 $Receipt.payload_sha256)
    ) { return $false }

    $configurationRows = Get-QsdkR10fL9DictionaryField `
        $configuration "ordered_joint_receipts"
    $readbackRows = Get-QsdkR10fL9DictionaryField $readback "ordered_joint_readbacks"
    $bindingIds = Get-QsdkR10fL9DictionaryField $binding "ordered_actuator_ids"
    $bindingPublished = Get-QsdkR10fL9DictionaryField `
        $binding "published_cap_by_actuator_id"
    $bindingSelected = Get-QsdkR10fL9DictionaryField `
        $binding "selected_host_cap_by_actuator_id"
    $projections = Get-QsdkR10fL9DictionaryField $binding "ordered_projection_receipts"
    if (
        [string]$configuration.schema_version -cne
            $script:QsdkR10fL12MotorConfigurationSchema -or
        [string]$configuration.gate_id -cne $script:QsdkR10fL9GateId -or
        -not [bool]$configuration.ok -or
        -not (Test-QsdkR10fL9ExactInteger $configuration.global_semantic_step `
            -Expected $ExpectedGlobalSemanticStep) -or
        [string]$configuration.reason -cne $reason -or
        -not [bool]$configuration.motor_enabled -or
        $configurationRows -isnot [System.Collections.IList] -or
        $configurationRows.Count -ne 8 -or
        -not (Test-QsdkR10fL9ExactInteger `
            $configuration.motor_configuration_write_count -Expected 16) -or
        -not [bool]$configuration.physics_state_modified -or
        [bool]$configuration.physical_acceptance_authority -or
        [bool]$configuration.release_authority -or
        [string]$readback.schema_version -cne $script:QsdkR10fL12MotorReadbackSchema -or
        [string]$readback.gate_id -cne $script:QsdkR10fL9GateId -or
        -not [bool]$readback.ok -or
        -not (Test-QsdkR10fL9ExactInteger $readback.global_semantic_step `
            -Expected $ExpectedGlobalSemanticStep) -or
        [string]$readback.reason -cne $reason -or
        -not [bool]$readback.expected_motor_enabled -or
        $readbackRows -isnot [System.Collections.IList] -or
        $readbackRows.Count -ne 8 -or
        -not (Test-QsdkR10fL9ExactInteger $readback.motor_enabled_count -Expected 8) -or
        -not (Test-QsdkR10fL9ExactInteger $readback.zero_target_velocity_count -Expected 8) -or
        -not (Test-QsdkR10fL9ExactInteger $readback.native_readback_count -Expected 24) -or
        [bool]$readback.physics_state_modified -or
        [bool]$readback.physical_acceptance_authority -or
        [bool]$readback.release_authority -or
        [string]$binding.schema_version -cne $script:QsdkR10fL12HostCapBindingSchema -or
        [string]$binding.gate_id -cne $script:QsdkR10fL9GateId -or
        -not [bool]$binding.ok -or
        [string]$binding.projection_id -cne $script:QsdkR10fL12ProjectionId -or
        [string]$binding.scope -cne $script:QsdkR10fL12ProjectionScope -or
        $bindingIds -isnot [System.Collections.IList] -or
        $bindingPublished -isnot [System.Collections.IDictionary] -or
        $bindingSelected -isnot [System.Collections.IDictionary] -or
        $projections -isnot [System.Collections.IList] -or
        $projections.Count -ne 8 -or
        -not (Test-QsdkR10fL9ExactInteger $binding.projection_count -Expected 8) -or
        [bool]$binding.published_cap_changed -or
        [bool]$binding.empirical_margin_added -or
        [bool]$binding.raw_measurement_clamped -or
        [bool]$binding.physics_state_modified -or
        [bool]$binding.physical_acceptance_authority -or
        [bool]$binding.release_authority -or
        [string]$Receipt.host_cap_projection_binding_sha256 -cne
            [string]$binding.payload_sha256
    ) { return $false }

    for ($index = 0; $index -lt 8; $index++) {
        $actuatorId = [string]$script:QsdkR10fL12ActuatorIds[$index]
        $jointId = [string]$script:QsdkR10fL12JointIds[$index]
        $published = [double]$script:QsdkR10fL12PublishedCaps[$index]
        $hostCap = [double]$script:QsdkR10fL12HostCaps[$index]
        $configurationRow = $configurationRows[$index]
        $readbackRow = $readbackRows[$index]
        $projection = $projections[$index]
        if (
            [string]$orderedIds[$index] -cne $actuatorId -or
            [string]$bindingIds[$index] -cne $actuatorId -or
            -not $publishedMap.Contains($actuatorId) -or
            -not $hostMap.Contains($actuatorId) -or
            -not $bindingPublished.Contains($actuatorId) -or
            -not $bindingSelected.Contains($actuatorId) -or
            [double]$publishedMap[$actuatorId] -ne $published -or
            [double]$bindingPublished[$actuatorId] -ne $published -or
            [double]$hostMap[$actuatorId] -ne $hostCap -or
            [double]$bindingSelected[$actuatorId] -ne $hostCap -or
            $configurationRow -isnot [System.Collections.IDictionary] -or
            [string]$configurationRow.joint_id -cne $jointId -or
            -not [bool]$configurationRow.motor_enabled -or
            [double]$configurationRow.motor_target_velocity_rad_s -ne 0.0 -or
            $readbackRow -isnot [System.Collections.IDictionary] -or
            [string]$readbackRow.joint_id -cne $jointId -or
            [string]$readbackRow.actuator_id -cne $actuatorId -or
            -not [bool]$readbackRow.motor_enabled -or
            [double]$readbackRow.motor_target_velocity_rad_s -ne 0.0 -or
            [double]$readbackRow.motor_maximum_impulse_nms -ne $hostCap -or
            $projection -isnot [System.Collections.IDictionary] -or
            [string]$projection.projection_id -cne $script:QsdkR10fL12ProjectionId -or
            [string]$projection.scope -cne $script:QsdkR10fL12ProjectionScope -or
            [string]$projection.actuator_id -cne $actuatorId -or
            -not (Test-QsdkR10fL9ExactInteger $projection.actuator_index `
                -Expected $index) -or
            [double]$projection.published_maximum_outer_step_impulse_nms -ne $published -or
            [double]$projection.configured_host_maximum_impulse_nms -ne $hostCap -or
            -not [bool]$projection.native_effective_limit_not_above_published -or
            -not [bool]$projection.next_native_effective_limit_above_published -or
            -not (Test-QsdkR10fL9ExactInteger `
                $projection.configured_to_next_binary32_ulp_distance -Expected 1) -or
            [bool]$projection.published_cap_changed -or
            [bool]$projection.empirical_margin_added -or
            [bool]$projection.measurement_clamped
        ) { return $false }
    }
    return $true
}


function Copy-QsdkR10fL9JsonValue {
    param([AllowNull()][object]$Value)
    if ($null -eq $Value) { return $null }
    if ($Value -is [System.Collections.IDictionary]) {
        $copy = [ordered]@{}
        foreach ($key in $Value.Keys) {
            $copy[[string]$key] = Copy-QsdkR10fL9JsonValue $Value[$key]
        }
        return $copy
    }
    if ($Value -is [System.Collections.IList] -and $Value -isnot [string]) {
        $copy = [System.Collections.Generic.List[object]]::new()
        foreach ($item in $Value) {
            $copy.Add((Copy-QsdkR10fL9JsonValue $item))
        }
        Write-Output -NoEnumerate ([object[]]$copy.ToArray())
        return
    }
    return $Value
}


function Get-QsdkR10fL14NoResumeSourceProof {
    param(
        [Parameter(Mandatory)][System.Collections.IDictionary]$Report,
        [Parameter(Mandatory)][System.Collections.IDictionary]$ExpectedIdentity
    )
    # Validate the complete offered source through the same independent closer.
    # No temporary report, physics worker, or evidence identity is created.
    $root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
    # Select the version from the enclosing production family, never from the
    # offered report. The legacy entrypoint/schema/reader remain unchanged.
    $readerVersion = if ($script:QsdkR10fL9RepairId -ceq 'QSDK-R10F-L15') { 'l15' } else { 'l14' }
    $readerRepairId = 'QSDK-R10F-' + $readerVersion.ToUpperInvariant()
    $requestSchema = 'sporespore_qsdk_r10f_' + $readerVersion + '_no_resume_child_source_request_v1'
    $receiptSchema = 'sporespore_qsdk_r10f_' + $readerVersion + '_no_resume_child_source_receipt_v1'
    $readerPath = if ($readerVersion -ceq 'l15') {
        'sdk/conformance/qsdk_r10f_l15_child_source_bridge.py'
    } else { 'sdk/conformance/qsdk_r10f_l14_child_source_bridge.py' }
    $request = [ordered]@{
        schema_version = $requestSchema
        report = $Report
        expected_identity = $ExpectedIdentity
    }
    $utf8 = [Text.UTF8Encoding]::new($false)
    $bytes = $utf8.GetBytes(($request | ConvertTo-Json -Depth 100 -Compress))
    $digest = "sha256:" + [Convert]::ToHexString(
        [Security.Cryptography.SHA256]::HashData($bytes)
    ).ToLowerInvariant()
    $start = [Diagnostics.ProcessStartInfo]::new()
    $start.FileName = "C:\Program Files\Python311\python.exe"
    $start.WorkingDirectory = $root
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $start.RedirectStandardInput = $true
    $start.StandardInputEncoding = $utf8
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    $start.ArgumentList.Add("-B")
    $start.ArgumentList.Add((Join-Path $root $readerPath))
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $start
    $started = $false
    try {
        $started = $process.Start()
        if (-not $started) { throw "L14_NO_RESUME_SOURCE_START" }
        $stdoutTask = $process.StandardOutput.ReadToEndAsync()
        $stderrTask = $process.StandardError.ReadToEndAsync()
        $writeTask = $process.StandardInput.BaseStream.WriteAsync($bytes, 0, $bytes.Length)
        if (-not $writeTask.Wait(60000)) { throw "L14_NO_RESUME_SOURCE_WRITE_TIMEOUT" }
        $process.StandardInput.Close()
        if (-not $process.WaitForExit(60000)) { throw "L14_NO_RESUME_SOURCE_TIMEOUT" }
        $stdout = $stdoutTask.GetAwaiter().GetResult()
        $stderr = $stderrTask.GetAwaiter().GetResult()
        $marker = 'QSDK_R10F_' + $readerVersion.ToUpperInvariant() + '_NO_RESUME_CHILD_SOURCE '
        $lines = @($stdout -split "`r?`n" | Where-Object {
            $_.StartsWith($marker, [StringComparison]::Ordinal)
        })
        if ($lines.Count -ne 1 -or -not [string]::IsNullOrWhiteSpace($stderr)) {
            throw "L14_NO_RESUME_SOURCE_PROCESS_OUTPUT"
        }
        $receipt = $lines[0].Substring($marker.Length) | ConvertFrom-Json -AsHashtable -Depth 100
        if (
            $receipt.schema_version -cne $receiptSchema -or
            $receipt.gate_id -cne "QSDK-R10F" -or $receipt.repair_id -cne $readerRepairId -or
            $receipt.offered_request_raw_sha256 -cne $digest
        ) { throw "L14_NO_RESUME_SOURCE_RESPONSE_BINDING" }
        if ($process.ExitCode -ne 0 -or $receipt.ok -isnot [bool] -or -not $receipt.ok) {
            throw ("L14_NO_RESUME_SOURCE_REFUSED:" + [string]$receipt.failure_code)
        }
        if (
            $receipt.whole_child_source_validation_passed -isnot [bool] -or
            -not $receipt.whole_child_source_validation_passed -or
            $receipt.process_health_and_peer_validation_still_required -isnot [bool] -or
            -not $receipt.process_health_and_peer_validation_still_required -or
            $receipt.no_resume_terminal.source_proven_no_resume_negative -isnot [bool] -or
            -not $receipt.no_resume_terminal.source_proven_no_resume_negative -or
            $receipt.no_resume_terminal.recovery_success_observed -isnot [bool] -or
            $receipt.no_resume_terminal.recovery_success_observed
        ) { throw "L14_NO_RESUME_SOURCE_PROOF_FIELDS" }
        foreach ($key in @(
            "model_construction_count", "world_attempt_count", "world_build_count",
            "scene_tree_insertion_count", "native_readback_count", "solver_step_count"
        )) {
            if (-not (Test-QsdkR10fL9ExactInteger $receipt[$key] -Expected 0)) {
                throw ("L14_NO_RESUME_SOURCE_COUNTER:" + $key)
            }
        }
        foreach ($key in @(
            "physics_state_modified", "physical_execution_authorized",
            "physical_acceptance_authority", "release_authority"
        )) {
            if ($receipt[$key] -isnot [bool] -or $receipt[$key]) {
                throw ("L14_NO_RESUME_SOURCE_CLAIM:" + $key)
            }
        }
        return $receipt.no_resume_terminal
    } finally {
        if ($started -and -not $process.HasExited) {
            $process.Kill($true)
            $process.WaitForExit()
        }
        $process.Dispose()
    }
}


function Get-QsdkR10fL9ChildValidation {
    [CmdletBinding()]
    param(
        [AllowNull()][object]$Report,
        [Parameter(Mandatory)][string]$ExpectedRole,
        [Parameter(Mandatory)][string]$ExpectedParentAttemptId,
        [Parameter(Mandatory)][string]$ExpectedChildAttemptId,
        [Parameter(Mandatory)][string]$ExpectedSourceCommit,
        [Parameter(Mandatory)][string]$ExpectedAuthoritySha256,
        [Parameter(Mandatory)][int]$ExpectedWorkerProcessId,
        [AllowNull()][object]$ExpectedL15ContextBinding = $null,
        [AllowNull()][object]$ExpectedL15CollectionIdentity = $null
    )
    $errors = [System.Collections.Generic.List[string]]::new()
    if ($Report -isnot [System.Collections.IDictionary]) {
        $errors.Add("CHILD_REPORT_MISSING_OR_NOT_OBJECT")
        return [ordered]@{
            ok = $false
            role = $ExpectedRole
            disposition = ""
            validation_errors = @($errors)
        }
    }

    foreach ($key in @(
        "schema_version", "gate_id", "repair_id", "work_id", "status", "ok",
        "measurement_complete", "scientific_outcome", "role_outcome", "source_commit",
        "authorization_sha256", "parent_attempt_id", "child_attempt_id", "attempt_id",
        "arm_id", "process_id", "seed", "seed_label", "seed_sha256", "actuator_mode",
        "recovery_controller_id", "energy_route_id", "physics_ticks_per_second", "held_out",
        "held_out_cell_access_count", "population_inference_claimed", "one_arm_per_process",
        "one_world_per_process", "world_or_body_state_imported_from_peer", "configuration",
        "configuration_sha256", "precondition_terminal_receipt",
        "precondition_terminal_receipt_sha256", "precondition_release_receipt",
        "precondition_release_receipt_sha256", "interaction_source",
        "interaction_source_sha256", "arm_result", "reached_walking_prefix",
        "reached_interaction", "reached_post_kick_recovery", "reached_walking_resume",
        "behavior_evaluator_invocation_count", "complete_trace_count",
        "in_run_invariant_receipt_count", "all_in_run_physical_invariants_passed",
        "same_body_identity_preserved", "model_construction_attempt_count",
        "model_construction_count", "world_attempt_count", "world_build_count",
        "solver_step_count", "maximum_solver_step_count", "global_solver_frame_count",
        "external_kick_application_count", "physical_question_opened",
        "physics_state_modified", "force_aware_recovery", "force_aware_bracing",
        "arbitrary_fall_recovery_claimed", "cross_engine_push_recovery_claimed",
        "physical_acceptance_authority", "release_authority"
    )) {
        Add-QsdkR10fL9ValidationError $errors $Report.Contains($key) ("CHILD_KEY_MISSING:" + $key)
    }
    if ($errors.Count -gt 0) {
        return [ordered]@{
            ok = $false
            role = $ExpectedRole
            disposition = ""
            validation_errors = @($errors)
        }
    }

    Add-QsdkR10fL9ValidationError $errors (
        [string]$Report.schema_version -ceq $script:QsdkR10fL9RawSchema
    ) "CHILD_SCHEMA_INVALID"
    if ($script:QsdkR10fL9RepairId -ceq 'QSDK-R10F-L15' -or $null -ne $ExpectedL15ContextBinding) {
        try {
            . (Join-Path $PSScriptRoot 'qsdk_r10f_l15_context_source.ps1')
            $comparison = if ($Report.Contains('l15_prepared_context_comparison')) {
                $Report.l15_prepared_context_comparison
            } else { $null }
            $null = Get-QsdkR10fL15ContextSourceProof $comparison `
                $ExpectedL15ContextBinding $ExpectedL15CollectionIdentity
        } catch { $errors.Add('CHILD_L15_PREPARED_CONTEXT_INVALID:' + $_.Exception.Message) }
    }
    Add-QsdkR10fL9ValidationError $errors (
        [string]$Report.gate_id -ceq $script:QsdkR10fL9GateId -and
        [string]$Report.repair_id -ceq $script:QsdkR10fL9RepairId -and
        [string]$Report.work_id -ceq $script:QsdkR10fL9WorkId
    ) "CHILD_GATE_OR_REPAIR_INVALID"
    Add-QsdkR10fL9ValidationError $errors (
        [bool]$Report.ok -and [bool]$Report.measurement_complete -and
        [string]$Report.status -ceq "valid_complete_process_isolated_child_development" -and
        [string]$Report.scientific_outcome -ceq "none"
    ) "CHILD_COMPLETION_CLASS_INVALID"
    Add-QsdkR10fL9ValidationError $errors (
        [string]$Report.source_commit -ceq $ExpectedSourceCommit -and
        [string]$Report.authorization_sha256 -ceq $ExpectedAuthoritySha256
    ) "CHILD_SOURCE_OR_AUTHORITY_INVALID"
    Add-QsdkR10fL9ValidationError $errors (
        [string]$Report.parent_attempt_id -ceq $ExpectedParentAttemptId -and
        [string]$Report.child_attempt_id -ceq $ExpectedChildAttemptId -and
        [string]$Report.attempt_id -ceq $ExpectedChildAttemptId -and
        [string]$Report.arm_id -ceq $ExpectedRole -and
        $ExpectedParentAttemptId -cne $ExpectedChildAttemptId
    ) "CHILD_IDENTITY_OR_ROLE_INVALID"
    Add-QsdkR10fL9ValidationError $errors (
        (Test-QsdkR10fL9ExactInteger $Report.process_id -Expected $ExpectedWorkerProcessId) -and
        $ExpectedWorkerProcessId -gt 0
    ) "CHILD_PROCESS_ID_INVALID"
    Add-QsdkR10fL9ValidationError $errors (
        (Test-QsdkR10fL9ExactInteger $Report.seed -Expected $script:QsdkR10fL9DevelopmentSeed) -and
        (Test-QsdkR10fL9Sha256 $Report.seed_sha256) -and
        [string]$Report.recovery_controller_id -ceq $script:QsdkR10fL9ControllerId
    ) "CHILD_FROZEN_SEED_OR_CONTROLLER_INVALID"
    Add-QsdkR10fL9ValidationError $errors (
        (Test-QsdkR10fL9ExactInteger $Report.physics_ticks_per_second -Expected 120) -and
        -not [bool]$Report.held_out -and
        (Test-QsdkR10fL9ExactInteger $Report.held_out_cell_access_count -Expected 0) -and
        -not [bool]$Report.population_inference_claimed
    ) "CHILD_DEVELOPMENT_SCOPE_INVALID"
    Add-QsdkR10fL9ValidationError $errors (
        [bool]$Report.one_arm_per_process -and [bool]$Report.one_world_per_process -and
        -not [bool]$Report.world_or_body_state_imported_from_peer
    ) "CHILD_PROCESS_ISOLATION_INVALID"

    $configuration = $Report.configuration
    $configurationValid = $configuration -is [System.Collections.IDictionary]
    if ($configurationValid) {
        $configurationValid = (
            [bool]$configuration.ok -and
            [string]$configuration.gate_id -ceq $script:QsdkR10fL9GateId -and
            [string]$configuration.selected_policy_id -ceq $script:QsdkR10fL9PolicyId -and
            [string]$configuration.selected_policy_digest -ceq $script:QsdkR10fL9PolicyDigest -and
            [string]$configuration.recovery_morphology_spec_sha256 -ceq
                $script:QsdkR10fL9RecoveryMorphologySha -and
            [string]$configuration.actuator_profile_id -ceq
                $script:QsdkR10fL9ActuatorProfileId -and
            [string]$configuration.material_profile_id -ceq
                $script:QsdkR10fL9MaterialProfileId -and
            -not [bool]$configuration.post_construction_transform_write_permitted -and
            -not [bool]$configuration.post_construction_velocity_write_permitted -and
            -not [bool]$configuration.solver_reset_permitted -and
            [bool]$configuration.event_triggered_passive_recovery -and
            -not [bool]$configuration.force_aware_recovery -and
            (Test-QsdkR10fL9Sha256 $configuration.recovery_context_sha256) -and
            (Test-QsdkR10fL9Sha256 $configuration.material_profile_sha256) -and
            (Test-QsdkR10fL9Sha256 $configuration.actuator_profile_sha256)
        )
    }
    Add-QsdkR10fL9ValidationError $errors (
        $configurationValid -and (Test-QsdkR10fL9Sha256 $Report.configuration_sha256)
    ) "CHILD_FROZEN_CONFIGURATION_INVALID"

    $solverCountValid = Test-QsdkR10fL9ExactInteger $Report.solver_step_count `
        -Minimum 1 -Maximum $script:QsdkR10fL9MaximumChildSolverSteps
    $solverCount = if ($solverCountValid) { [int64]$Report.solver_step_count } else { -1 }
    Add-QsdkR10fL9ValidationError $errors (
        (Test-QsdkR10fL9ExactInteger $Report.model_construction_attempt_count -Expected 1) -and
        (Test-QsdkR10fL9ExactInteger $Report.model_construction_count -Expected 1) -and
        (Test-QsdkR10fL9ExactInteger $Report.world_attempt_count -Expected 1) -and
        (Test-QsdkR10fL9ExactInteger $Report.world_build_count -Expected 1) -and
        $solverCountValid -and
        (Test-QsdkR10fL9ExactInteger $Report.global_solver_frame_count -Expected $solverCount) -and
        (Test-QsdkR10fL9ExactInteger $Report.maximum_solver_step_count `
            -Expected $script:QsdkR10fL9MaximumChildSolverSteps) -and
        (Test-QsdkR10fL9ExactInteger $Report.complete_trace_count -Expected 1) -and
        (Test-QsdkR10fL9ExactInteger $Report.behavior_evaluator_invocation_count -Expected 0)
    ) "CHILD_COUNTERS_INVALID"
    Add-QsdkR10fL9ValidationError $errors (
        [bool]$Report.all_in_run_physical_invariants_passed -and
        [bool]$Report.same_body_identity_preserved -and
        [bool]$Report.physical_question_opened -and [bool]$Report.physics_state_modified -and
        -not [bool]$Report.force_aware_recovery -and -not [bool]$Report.force_aware_bracing -and
        -not [bool]$Report.arbitrary_fall_recovery_claimed -and
        -not [bool]$Report.cross_engine_push_recovery_claimed -and
        -not [bool]$Report.physical_acceptance_authority -and -not [bool]$Report.release_authority
    ) "CHILD_SAFETY_OR_SCOPE_FLAGS_INVALID"

    $armResult = $Report.arm_result
    $armResultValid = $armResult -is [System.Collections.IDictionary]
    if ($armResultValid) {
        $armResultValid = (
            [string]$armResult.schema_version -ceq $script:QsdkR10fL9ArmResultSchema -and
            [string]$armResult.gate_id -ceq $script:QsdkR10fL9GateId -and
            [string]$armResult.repair_id -ceq $script:QsdkR10fL9RepairId -and
            [bool]$armResult.ok -and
            [string]$armResult.parent_attempt_id -ceq $ExpectedParentAttemptId -and
            [string]$armResult.child_attempt_id -ceq $ExpectedChildAttemptId -and
            [string]$armResult.arm_id -ceq $ExpectedRole -and
            [bool]$armResult.same_body_identity_preserved -and
            [bool]$armResult.all_in_run_physical_invariants_passed -and
            (Test-QsdkR10fL9ExactInteger $armResult.outer_step_count -Expected $solverCount) -and
            (Test-QsdkR10fL9ExactInteger $armResult.native_solver_step_count -Expected $solverCount) -and
            (Test-QsdkR10fL9ExactInteger $armResult.body_population_rebuild_count -Expected 0) -and
            (Test-QsdkR10fL9ExactInteger $armResult.body_transform_write_count -Expected 0) -and
            (Test-QsdkR10fL9ExactInteger $armResult.body_velocity_write_count -Expected 0) -and
            (Test-QsdkR10fL9ExactInteger $armResult.solver_reset_count -Expected 0) -and
            -not [bool]$armResult.global_step_values_rewritten_for_pair_alignment -and
            [bool]$armResult.full_trace_retained -and
            -not [bool]$armResult.physical_acceptance_authority -and
            -not [bool]$armResult.release_authority -and
            (Test-QsdkR10fL9Sha256 $armResult.trace_sha256)
        )
    }
    Add-QsdkR10fL9ValidationError $errors $armResultValid "CHILD_ARM_RESULT_INVALID"

    $traceValid = $armResultValid -and $armResult.trace -is [System.Collections.IDictionary]
    $rows = $null
    if ($traceValid) {
        $trace = $armResult.trace
        $rows = Get-QsdkR10fL9DictionaryField $trace "rows"
        $traceValid = (
            [string]$trace.schema_version -ceq $script:QsdkR10fL9TraceSchema -and
            [string]$trace.gate_id -ceq $script:QsdkR10fL9GateId -and
            [string]$trace.repair_id -ceq $script:QsdkR10fL9RepairId -and
            [string]$trace.parent_attempt_id -ceq $ExpectedParentAttemptId -and
            [string]$trace.child_attempt_id -ceq $ExpectedChildAttemptId -and
            [string]$trace.arm_id -ceq $ExpectedRole -and
            $rows -is [System.Collections.IList] -and
            $rows.Count -eq $solverCount
        )
    }
    if ($traceValid) {
        for ($index = 0; $index -lt $rows.Count; $index++) {
            $row = $rows[$index]
            if (
                $row -isnot [System.Collections.IDictionary] -or
                [string]$row.arm_id -cne $ExpectedRole -or
                -not (Test-QsdkR10fL9ExactInteger $row.global_semantic_step -Expected ($index + 1)) -or
                -not [bool]$row.source_measurement
            ) { $traceValid = $false; break }
        }
    }
    Add-QsdkR10fL9ValidationError $errors $traceValid "CHILD_FULL_TRACE_INVALID_OR_TRUNCATED"

    $invariants = if ($armResultValid) {
        Get-QsdkR10fL9DictionaryField $armResult "in_run_invariant_receipts"
    } else { $null }
    $invariantsValid = (
        $invariants -is [System.Collections.IList] -and
        $invariants.Count -eq $solverCount -and
        (Test-QsdkR10fL9ExactInteger $armResult.in_run_invariant_receipt_count `
            -Expected $solverCount) -and
        (Test-QsdkR10fL9ExactInteger $Report.in_run_invariant_receipt_count `
            -Expected $solverCount)
    )
    if ($invariantsValid) {
        for ($index = 0; $index -lt $invariants.Count; $index++) {
            $invariant = $invariants[$index]
            if (
                $invariant -isnot [System.Collections.IDictionary] -or
                [string]$invariant.arm_id -cne $ExpectedRole -or
                -not (Test-QsdkR10fL9ExactInteger $invariant.global_semantic_step `
                    -Expected ($index + 1)) -or
                -not [bool]$invariant.all_in_run_physical_invariants_passed -or
                [bool]$invariant.physical_acceptance_authority -or
                [bool]$invariant.release_authority
            ) { $invariantsValid = $false; break }
        }
    }
    Add-QsdkR10fL9ValidationError $errors $invariantsValid "CHILD_INVARIANT_POPULATION_INVALID"

    $terminal = $Report.precondition_terminal_receipt
    $terminalValid = $terminal -is [System.Collections.IDictionary]
    $disposition = ""
    if ($terminalValid) {
        $disposition = [string]$terminal.disposition
		$terminalMemory = $terminal.recovery_memory
        $terminalValid = (
            [string]$terminal.schema_version -ceq $script:QsdkR10fL9PreconditionSchema -and
            [string]$terminal.gate_id -ceq $script:QsdkR10fL9GateId -and
            [string]$terminal.repair_id -ceq $script:QsdkR10fL9ChildContractRepairId -and
            [string]$terminal.parent_attempt_id -ceq $ExpectedParentAttemptId -and
            [string]$terminal.child_attempt_id -ceq $ExpectedChildAttemptId -and
            [string]$terminal.arm_id -ceq $ExpectedRole -and
            $disposition -cin @(
                "complete_source_retained", "failed_source_retained", "refused_source_retained"
            ) -and
            (Test-QsdkR10fL9ExactInteger $terminal.completed_global_semantic_step `
                -Minimum 1 -Maximum $solverCount) -and
            (Test-QsdkR10fL9ExactInteger $terminal.body_transform_write_count -Expected 0) -and
            (Test-QsdkR10fL9ExactInteger $terminal.body_velocity_write_count -Expected 0) -and
            (Test-QsdkR10fL9ExactInteger $terminal.solver_reset_count -Expected 0) -and
            [bool]$terminal.source_measurement -and
            -not [bool]$terminal.outcome_derived_correction -and
            -not [bool]$terminal.physical_acceptance_authority -and
            -not [bool]$terminal.release_authority -and
            (Test-QsdkR10fL9Sha256 $terminal.payload_sha256) -and
            [string]$Report.precondition_terminal_receipt_sha256 -ceq
                [string]$terminal.payload_sha256 -and
            [string]$armResult.precondition_terminal_receipt_sha256 -ceq
				[string]$terminal.payload_sha256 -and
			$terminalMemory -is [System.Collections.IDictionary]
        )
        if ($terminalValid -and $disposition -ceq "complete_source_retained") {
            $terminalValid = (
				$terminal.recovery_terminal_phase -is [string] -and
				$terminal.recovery_terminal_phase -ceq "complete" -and
				(Test-QsdkR10fL10TerminalFailureProjection `
					-Memory $terminalMemory `
					-TerminalPhase $terminal.recovery_terminal_phase `
					-ProjectedFailureCode $terminal.recovery_terminal_failure_code) -and
                [bool]$terminal.stable_four_foot_stance
            )
        } elseif ($terminalValid) {
            $terminalValid = (
				$terminal.recovery_terminal_phase -is [string] -and
				$terminal.recovery_terminal_phase -cin @("failed", "refused") -and
				(Test-QsdkR10fL10TerminalFailureProjection `
					-Memory $terminalMemory `
					-TerminalPhase $terminal.recovery_terminal_phase `
					-ProjectedFailureCode $terminal.recovery_terminal_failure_code)
            )
        }
    }
    Add-QsdkR10fL9ValidationError $errors $terminalValid "CHILD_PRECONDITION_TERMINAL_INVALID"

    $completePrecondition = $terminalValid -and $disposition -ceq "complete_source_retained"
    $release = $Report.precondition_release_receipt
    $releaseValid = $false
    if ($completePrecondition -and $release -is [System.Collections.IDictionary]) {
        $releaseTerminal = Get-QsdkR10fL9DictionaryField `
            -Dictionary $release -Key "precondition_terminal_receipt"
        $releaseLedger = Get-QsdkR10fL9DictionaryField `
            -Dictionary $release -Key "ledger_application_intent"
        $releaseOwnerSource = Get-QsdkR10fL9DictionaryField `
            -Dictionary $releaseLedger -Key "owner_source_receipt"
        $releaseValid = (
            [string]$release.schema_version -ceq $script:QsdkR10fL9ReleaseSchema -and
            [string]$release.gate_id -ceq $script:QsdkR10fL9GateId -and
            [string]$release.repair_id -ceq $script:QsdkR10fL11ReleaseRepairId -and
            [string]$release.parent_attempt_id -ceq $ExpectedParentAttemptId -and
            [string]$release.child_attempt_id -ceq $ExpectedChildAttemptId -and
            [string]$release.arm_id -ceq $ExpectedRole -and
            [string]$release.model_instance_id -ceq [string]$terminal.model_instance_id -and
            (Test-QsdkR10fL9ExactInteger $release.global_semantic_step `
                -Expected ([int64]$terminal.completed_global_semantic_step + 1)) -and
            [string]$release.action_kind -ceq "process_isolated_no_actuation_release" -and
            $releaseTerminal -is [System.Collections.IDictionary] -and
            [string]$releaseTerminal.payload_sha256 -ceq [string]$terminal.payload_sha256 -and
            [string]$release.precondition_terminal_receipt_sha256 -ceq
                [string]$terminal.payload_sha256 -and
            $releaseLedger -is [System.Collections.IDictionary] -and
            [bool]$releaseLedger.ok -and
            (Test-QsdkR10fL9ExactInteger $releaseLedger.semantic_step `
                -Expected ([int64]$release.global_semantic_step)) -and
            [bool]$releaseLedger.no_actuation_requested -and
            [string]$releaseLedger.controller_owner -ceq "none" -and
            (Test-QsdkR10fL11ReleaseOwnerSource `
                -Source $releaseOwnerSource -Terminal $terminal `
                -ExpectedRole $ExpectedRole `
                -ExpectedParentAttemptId $ExpectedParentAttemptId `
                -ExpectedChildAttemptId $ExpectedChildAttemptId) -and
            (Test-QsdkR10fL9Sha256 $releaseLedger.owner_source_receipt_sha256) -and
            [bool]$release.no_actuation_requested -and
            [string]$release.control_owner -ceq "none" -and
            [string]$release.actuation_owner -ceq "none" -and
            (Test-QsdkR10fL9ExactInteger $release.body_transform_write_count -Expected 0) -and
            (Test-QsdkR10fL9ExactInteger $release.body_velocity_write_count -Expected 0) -and
            (Test-QsdkR10fL9ExactInteger $release.solver_reset_count -Expected 0) -and
            [bool]$release.source_measurement -and
            -not [bool]$release.outcome_derived_correction -and
            -not [bool]$release.physical_acceptance_authority -and
            -not [bool]$release.release_authority -and
            (Test-QsdkR10fL9Sha256 $release.payload_sha256) -and
            [string]$Report.precondition_release_receipt_sha256 -ceq
                [string]$release.payload_sha256 -and
            [string]$armResult.precondition_release_receipt_sha256 -ceq
                [string]$release.payload_sha256 -and
            [bool]$armResult.precondition_release_receipt_valid
        )
    } elseif (-not $completePrecondition) {
        $releaseValid = (
            $release -is [System.Collections.IDictionary] -and $release.Count -eq 0 -and
            [string]$Report.precondition_release_receipt_sha256 -ceq "" -and
            -not [bool]$armResult.precondition_release_receipt_valid
        )
    }
    Add-QsdkR10fL9ValidationError $errors $releaseValid "CHILD_PRECONDITION_RELEASE_INVALID"

    $handoffsPresent = (
        $armResultValid -and $armResult.Contains("walking_actuation_handoff_receipts")
    )
    $walkingSessionsForHandoffPresent = (
        $armResultValid -and $armResult.Contains("walking_sessions")
    )
    $handoffs = $null
    if ($handoffsPresent) {
        $handoffs = $armResult["walking_actuation_handoff_receipts"]
    }
    $walkingSessionsForHandoff = $null
    if ($walkingSessionsForHandoffPresent) {
        $walkingSessionsForHandoff = $armResult["walking_sessions"]
    }
    $noResumeProof = [ordered]@{}
    $transition = Get-QsdkR10fL9DictionaryField $armResult "terminal_orchestrator_transition"
    $stateBefore = Get-QsdkR10fL9DictionaryField $transition "state_before"
    $stateBeforePhase = Get-QsdkR10fL9DictionaryField $stateBefore "phase"
    $noResumeProofRequired = (
        $completePrecondition -and $ExpectedRole -ceq $script:QsdkR10fL9ActiveRole -and (
            $walkingSessionsForHandoff -isnot [System.Collections.IList] -or
            $walkingSessionsForHandoff.Count -ne 2 -or
            $Report.reached_walking_resume -isnot [bool] -or
            -not $Report.reached_walking_resume -or
            $stateBeforePhase -cin @("kick_triggered_zero_actuation_passive_fall", "offset_bound_recovery_epoch")
        )
    )
    if ($noResumeProofRequired) {
        try {
            $noResumeProof = Get-QsdkR10fL14NoResumeSourceProof -Report $Report -ExpectedIdentity ([ordered]@{
                expected_role = $ExpectedRole
                expected_parent_attempt_id = $ExpectedParentAttemptId
                expected_child_attempt_id = $ExpectedChildAttemptId
                expected_source_commit = $ExpectedSourceCommit
                expected_authority_sha256 = $ExpectedAuthoritySha256
                expected_worker_process_id = $ExpectedWorkerProcessId
            })
        } catch {
            $errors.Add("CHILD_L14_NO_RESUME_SOURCE_INVALID:" + $_.Exception.Message)
        }
    }
    $sourceProvenNoResume = $noResumeProof.Count -gt 0
    $expectedHandoffSegments = @(
        if ($completePrecondition) {
            "walking_prefix"
            if ($ExpectedRole -ceq $script:QsdkR10fL9BaselineRole) {
                "matched_continuation"
            } elseif (-not $sourceProvenNoResume) {
                "walking_resume"
            }
        }
    )
    $handoffPopulationValid = (
        $handoffsPresent -and
        $walkingSessionsForHandoffPresent -and
        $handoffs -is [System.Collections.IList] -and
        $walkingSessionsForHandoff -is [System.Collections.IList] -and
        $handoffs.Count -eq $expectedHandoffSegments.Count -and
        $walkingSessionsForHandoff.Count -eq $expectedHandoffSegments.Count
    )
    $priorHandoffStep = if ($completePrecondition) {
        [int64]$release.global_semantic_step
    } else { 0 }
    $handoffSessionIds = [System.Collections.Generic.HashSet[string]]::new(
        [StringComparer]::Ordinal
    )
    if ($handoffPopulationValid) {
        for ($index = 0; $index -lt $expectedHandoffSegments.Count; $index++) {
            $handoff = $handoffs[$index]
            $walkingSession = $walkingSessionsForHandoff[$index]
            $segment = [string]$expectedHandoffSegments[$index]
            if (
                $handoff -isnot [System.Collections.IDictionary] -or
                $walkingSession -isnot [System.Collections.IDictionary] -or
                -not (Test-QsdkR10fL9ExactInteger $handoff.global_semantic_step `
                    -Minimum ($priorHandoffStep + 1) -Maximum $solverCount)
            ) { $handoffPopulationValid = $false; break }
            $sessionId = [string]$handoff.walking_session_id
            $handoffStep = [int64]$handoff.global_semantic_step
            if (
                [string]::IsNullOrEmpty($sessionId) -or
                -not $handoffSessionIds.Add($sessionId) -or
                [string]$walkingSession.evaluation_segment_id -cne $segment -or
                [string]$walkingSession.session_id -cne $sessionId -or
                -not (Test-QsdkR10fL12WalkingActuationHandoff `
                    -Receipt $handoff `
                    -ExpectedModelInstanceId ([string]$armResult.model_instance_id) `
                    -ExpectedEvaluationSegment $segment `
                    -ExpectedSessionId $sessionId `
                    -ExpectedGlobalSemanticStep $handoffStep)
            ) { $handoffPopulationValid = $false; break }
            if ($index -eq 0 -and $handoffStep -ne ([int64]$release.global_semantic_step + 1)) {
                $handoffPopulationValid = $false
                break
            }
            $priorHandoffStep = $handoffStep
        }
    }
    Add-QsdkR10fL9ValidationError $errors $handoffPopulationValid (
        "CHILD_WALKING_ACTUATION_HANDOFF_POPULATION_INVALID"
    )

    $reachedInteraction = [bool]$Report.reached_interaction
    $interaction = $Report.interaction_source
    $interactionValid = $false
    if ($reachedInteraction -and $interaction -is [System.Collections.IDictionary]) {
        $forward = Get-QsdkR10fL9Vector3 $interaction.task_frame_forward_axis_world_host_real
        $lateral = Get-QsdkR10fL9Vector3 $interaction.task_frame_lateral_axis_world_host_real
        $impulse = Get-QsdkR10fL9Vector3 $interaction.scheduled_impulse_world_n_s
        $before = Get-QsdkR10fL9Vector3 $interaction.pre_event_velocity_world_m_s
        $after = Get-QsdkR10fL9Vector3 $interaction.completed_effect_velocity_world_m_s
        $retainedDelta = Get-QsdkR10fL9Vector3 $interaction.raw_velocity_delta_world_m_s
        $vectorsValid = (
            $null -ne $forward -and $null -ne $lateral -and $null -ne $impulse -and
            $null -ne $before -and $null -ne $after -and $null -ne $retainedDelta
        )
        if ($vectorsValid) {
            $computedDelta = Get-QsdkR10fL9VectorSubtract -Left $after -Right $before
            $expectedImpulse = [double[]]@(
                ($lateral[0] * $script:QsdkR10fL9ImpulseMagnitude)
                ($lateral[1] * $script:QsdkR10fL9ImpulseMagnitude)
                $lateral[2] * $script:QsdkR10fL9ImpulseMagnitude
            )
            $roleInteractionValid = if ($ExpectedRole -ceq $script:QsdkR10fL9ActiveRole) {
                (Test-QsdkR10fL9ExactInteger $interaction.application_count -Expected 1) -and
                (Test-QsdkR10fL9VectorClose -Left $impulse -Right $expectedImpulse `
                    -Allowance $script:QsdkR10fL9UnitAllowance) -and
                (Get-QsdkR10fL9VectorNorm $retainedDelta) -ge $script:QsdkR10fL9NativeEffectFloor
            } else {
                (Test-QsdkR10fL9ExactInteger $interaction.application_count -Expected 0) -and
                (Get-QsdkR10fL9VectorNorm $impulse) -eq 0.0
            }
            $interactionValid = (
                [string]$interaction.schema_version -ceq $script:QsdkR10fL9InteractionSchema -and
                [string]$interaction.gate_id -ceq $script:QsdkR10fL9GateId -and
                [string]$interaction.repair_id -ceq $script:QsdkR10fL9ChildContractRepairId -and
                [string]$interaction.parent_attempt_id -ceq $ExpectedParentAttemptId -and
                [string]$interaction.child_attempt_id -ceq $ExpectedChildAttemptId -and
                [string]$interaction.arm_id -ceq $ExpectedRole -and
                (Test-QsdkR10fL9ExactInteger $interaction.completed_effect_global_step `
                    -Minimum 2 -Maximum $solverCount) -and
                (Test-QsdkR10fL9ExactInteger $interaction.interaction_local_step -Expected 1) -and
                (Test-QsdkR10fL9Sha256 $interaction.prefix_session_receipt_sha256) -and
                [Math]::Abs((Get-QsdkR10fL9VectorNorm $forward) - 1.0) -le
                    $script:QsdkR10fL9UnitAllowance -and
                [Math]::Abs((Get-QsdkR10fL9VectorNorm $lateral) - 1.0) -le
                    $script:QsdkR10fL9UnitAllowance -and
                [Math]::Abs((Get-QsdkR10fL9VectorDot -Left $forward -Right $lateral)) -le
                    $script:QsdkR10fL9UnitAllowance -and
                (Test-QsdkR10fL9VectorClose -Left $retainedDelta -Right $computedDelta `
                    -Allowance 1.0e-12) -and
                (Test-QsdkR10fL9FiniteNumber $interaction.raw_velocity_delta_magnitude_m_s) -and
                [Math]::Abs(
                    [double]$interaction.raw_velocity_delta_magnitude_m_s -
                    (Get-QsdkR10fL9VectorNorm $retainedDelta)
                ) -le 1.0e-12 -and
                $roleInteractionValid -and
                [bool]$interaction.source_measurement -and
                -not [bool]$interaction.outcome_derived_correction -and
                -not [bool]$interaction.global_step_rewritten_for_pair_alignment -and
                -not [bool]$interaction.force_aware_recovery_used -and
                -not [bool]$interaction.physical_acceptance_authority -and
                -not [bool]$interaction.release_authority -and
                (Test-QsdkR10fL9Sha256 $interaction.payload_sha256) -and
                [string]$Report.interaction_source_sha256 -ceq [string]$interaction.payload_sha256
            )
        }
    } else {
        $interactionValid = (
            $interaction -is [System.Collections.IDictionary] -and $interaction.Count -eq 0 -and
            [string]$Report.interaction_source_sha256 -ceq "" -and
            (Test-QsdkR10fL9ExactInteger $Report.external_kick_application_count -Expected 0)
        )
    }
    Add-QsdkR10fL9ValidationError $errors $interactionValid "CHILD_INTERACTION_SOURCE_INVALID"

    $expectedKickCount = if (
        $reachedInteraction -and $ExpectedRole -ceq $script:QsdkR10fL9ActiveRole
    ) { 1 } else { 0 }
    Add-QsdkR10fL9ValidationError $errors (
        (Test-QsdkR10fL9ExactInteger $Report.external_kick_application_count `
            -Expected $expectedKickCount) -and
        (Test-QsdkR10fL9ExactInteger $armResult.external_kick_application_count `
            -Expected $expectedKickCount)
    ) "CHILD_KICK_COUNT_INVALID"

    $roleOutcome = [string]$Report.role_outcome
    $roleOutcomeValid = if (-not $completePrecondition) {
        $roleOutcome -ceq "precondition_negative" -and
        -not $reachedInteraction -and -not [bool]$Report.reached_walking_prefix -and
        -not [bool]$Report.reached_post_kick_recovery -and
        -not [bool]$Report.reached_walking_resume
    } elseif ($ExpectedRole -ceq $script:QsdkR10fL9BaselineRole) {
        $roleOutcome -ceq "matched_reference_complete" -and
        [bool]$Report.reached_walking_prefix -and $reachedInteraction
    } else {
        $roleOutcome -cin @("behavior_positive", "behavior_negative") -and
        [bool]$Report.reached_walking_prefix -and $reachedInteraction
    }
    Add-QsdkR10fL9ValidationError $errors $roleOutcomeValid "CHILD_ROLE_OUTCOME_INVALID"

    return [ordered]@{
        schema_version = "sporespore_qsdk_r10f_l9_child_validation_v1"
        gate_id = $script:QsdkR10fL9GateId
        repair_id = $script:QsdkR10fL9RepairId
        ok = $errors.Count -eq 0
        role = $ExpectedRole
        disposition = $disposition
        complete_precondition = $completePrecondition
        reached_interaction = $reachedInteraction
        role_outcome = $roleOutcome
        solver_step_count = $solverCount
        walking_actuation_handoff_count = if ($handoffPopulationValid) {
            $handoffs.Count
        } else { -1 }
        no_resume_terminal = $noResumeProof
        configuration_sha256 = [string]$Report.configuration_sha256
        validation_errors = @($errors)
        physical_acceptance_authority = $false
        release_authority = $false
    }
}


function Get-QsdkR10fL9WalkingProjection {
    param(
        [Parameter(Mandatory)][System.Collections.IDictionary]$Report,
        [Parameter(Mandatory)][string]$Role
    )
    $errors = [System.Collections.Generic.List[string]]::new()
    # A function-return pipeline unwraps a one-element array into its member.
    # Read this field directly so one retained session remains a source array.
    $sessions = $null
    if (
        $Report.arm_result -is [System.Collections.IDictionary] -and
        $Report.arm_result.Contains("walking_sessions")
    ) {
        $sessions = $Report.arm_result["walking_sessions"]
    }
    if ($sessions -isnot [System.Collections.IList]) {
        $errors.Add("WALKING_SESSION_POPULATION_MISSING")
        $sessions = @()
    }
    $bySegment = [ordered]@{}
    $allBehaviorPassed = $true
    foreach ($session in $sessions) {
        if ($session -isnot [System.Collections.IDictionary]) {
            $errors.Add("WALKING_SESSION_NOT_OBJECT")
            continue
        }
        $segment = [string]$session.evaluation_segment_id
        $evaluation = Get-QsdkR10fL9DictionaryField $session "evaluation"
        if (
            $segment -notin @("walking_prefix", "walking_resume", "matched_continuation") -or
            $bySegment.Contains($segment) -or
            $evaluation -isnot [System.Collections.IDictionary] -or
            -not [bool]$evaluation.ok -or
            -not [bool]$evaluation.evidence_valid -or
            -not [bool]$evaluation.outcome_complete -or
            [string]$evaluation.arm_id -cne $Role -or
            [string]$evaluation.segment_id -cne $segment -or
            [bool]$evaluation.physical_acceptance_authority -or
            [bool]$evaluation.release_authority
        ) {
            $errors.Add("WALKING_SESSION_INVALID:" + $segment)
            continue
        }
        $bySegment[$segment] = [bool]$evaluation.behavior_passed
        if (-not [bool]$evaluation.behavior_passed) { $allBehaviorPassed = $false }
    }
    return [ordered]@{
        ok = $errors.Count -eq 0
        role = $Role
        session_count = $sessions.Count
        behavior_by_segment = $bySegment
        all_retained_session_behaviors_passed = $allBehaviorPassed
        errors = @($errors)
    }
}


function Invoke-QsdkR10fL9PairEvaluator {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][System.Collections.IDictionary]$BaselineReport,
        [Parameter(Mandatory)][System.Collections.IDictionary]$ActiveReport
    )
    $baselineTerminal = $BaselineReport.precondition_terminal_receipt
    $activeTerminal = $ActiveReport.precondition_terminal_receipt
    $preconditionNegative = (
        [string]$baselineTerminal.disposition -cne "complete_source_retained" -or
        [string]$activeTerminal.disposition -cne "complete_source_retained"
    )
    if ($preconditionNegative) {
        return [ordered]@{
            schema_version = "sporespore_qsdk_r10f_l9_process_isolated_pair_evaluation_v1"
            gate_id = $script:QsdkR10fL9GateId
            repair_id = $script:QsdkR10fL9RepairId
            ok = $true
            status = "valid_complete_precondition_diagnostic_no_r10f_behavioral_outcome"
            evidence_valid = $true
            measurement_complete = $true
            route_execution_valid = $false
            outcome_complete = $false
            behavior_passed = $false
            scientific_outcome = "none"
            failure_code = "QSDK_R10F_L9_PRECONDITION_NEGATIVE_RETAINED"
            evaluator_invocation_count = 1
            precondition_negative_roles = @(
                foreach ($report in @($BaselineReport, $ActiveReport)) {
                    if (
                        [string]$report.precondition_terminal_receipt.disposition -cne
                            "complete_source_retained"
                    ) { [string]$report.arm_id }
                }
            )
            pair_alignment_basis = "phase_local_receipts_and_walking_session_local_steps"
            global_solver_step_values_rewritten_for_pair_alignment = $false
            trace_truncation_used_for_pair_alignment = $false
            force_aware_recovery = $false
            physical_acceptance_authority = $false
            release_authority = $false
        }
    }

    $baselineSource = $BaselineReport.interaction_source
    $activeSource = $ActiveReport.interaction_source
    $sourceShapeValid = (
        $baselineSource -is [System.Collections.IDictionary] -and
        $activeSource -is [System.Collections.IDictionary]
    )
    $predicates = [ordered]@{ source_shape_valid = $sourceShapeValid }
    $measurements = [ordered]@{}
    if ($sourceShapeValid) {
        $activeForward = Get-QsdkR10fL9Vector3 $activeSource.task_frame_forward_axis_world_host_real
        $activeLateral = Get-QsdkR10fL9Vector3 $activeSource.task_frame_lateral_axis_world_host_real
        $baselineForward = Get-QsdkR10fL9Vector3 $baselineSource.task_frame_forward_axis_world_host_real
        $baselineLateral = Get-QsdkR10fL9Vector3 $baselineSource.task_frame_lateral_axis_world_host_real
        $activeImpulse = Get-QsdkR10fL9Vector3 $activeSource.scheduled_impulse_world_n_s
        $activeDelta = Get-QsdkR10fL9Vector3 $activeSource.raw_velocity_delta_world_m_s
        $baselineDelta = Get-QsdkR10fL9Vector3 $baselineSource.raw_velocity_delta_world_m_s
        $vectorsValid = (
            $null -ne $activeForward -and $null -ne $activeLateral -and
            $null -ne $baselineForward -and $null -ne $baselineLateral -and
            $null -ne $activeImpulse -and $null -ne $activeDelta -and $null -ne $baselineDelta
        )
        $predicates.vectors_valid = $vectorsValid
        if ($vectorsValid) {
            $expectedImpulse = [double[]]@(
                ($activeLateral[0] * $script:QsdkR10fL9ImpulseMagnitude)
                ($activeLateral[1] * $script:QsdkR10fL9ImpulseMagnitude)
                $activeLateral[2] * $script:QsdkR10fL9ImpulseMagnitude
            )
            $pairedDelta = Get-QsdkR10fL9VectorSubtract `
                -Left $activeDelta -Right $baselineDelta
            $pairedMagnitude = Get-QsdkR10fL9VectorNorm $pairedDelta
            $predicates.interaction_local_steps_exact = (
                (Test-QsdkR10fL9ExactInteger $activeSource.interaction_local_step -Expected 1) -and
                (Test-QsdkR10fL9ExactInteger $baselineSource.interaction_local_step -Expected 1)
            )
            $predicates.global_steps_retained_as_separate_sources = (
                (Test-QsdkR10fL9ExactInteger $activeSource.completed_effect_global_step -Minimum 2) -and
                (Test-QsdkR10fL9ExactInteger $baselineSource.completed_effect_global_step -Minimum 2) -and
                -not [bool]$activeSource.global_step_rewritten_for_pair_alignment -and
                -not [bool]$baselineSource.global_step_rewritten_for_pair_alignment
            )
            $predicates.task_frame_forward_axes_link = Test-QsdkR10fL9VectorClose `
                -Left $activeForward -Right $baselineForward `
                -Allowance $script:QsdkR10fL9UnitAllowance
            $predicates.task_frame_lateral_axes_link = Test-QsdkR10fL9VectorClose `
                -Left $activeLateral -Right $baselineLateral `
                -Allowance $script:QsdkR10fL9UnitAllowance
            $predicates.active_impulse_links_to_local_lateral_axis = Test-QsdkR10fL9VectorClose `
                -Left $activeImpulse -Right $expectedImpulse `
                -Allowance $script:QsdkR10fL9UnitAllowance
            $predicates.active_impulse_magnitude_exact = (
                [Math]::Abs(
                    (Get-QsdkR10fL9VectorNorm $activeImpulse) - $script:QsdkR10fL9ImpulseMagnitude
                ) -le $script:QsdkR10fL9ImpulseAllowance
            )
            $predicates.active_kick_count_exact = (
                (Test-QsdkR10fL9ExactInteger $activeSource.application_count -Expected 1) -and
                (Test-QsdkR10fL9ExactInteger $ActiveReport.external_kick_application_count `
                    -Expected 1)
            )
            $predicates.baseline_kick_count_exact = (
                (Test-QsdkR10fL9ExactInteger $baselineSource.application_count -Expected 0) -and
                (Test-QsdkR10fL9ExactInteger $BaselineReport.external_kick_application_count `
                    -Expected 0)
            )
            $predicates.paired_native_effect_meets_frozen_floor = (
                $pairedMagnitude -ge $script:QsdkR10fL9NativeEffectFloor
            )
            $measurements = [ordered]@{
                active_completed_effect_global_step = [int64]$activeSource.completed_effect_global_step
                baseline_completed_effect_global_step = [int64]$baselineSource.completed_effect_global_step
                interaction_local_step = 1
                task_frame_impulse_n_s = @(0.0, 0.0, $script:QsdkR10fL9ImpulseMagnitude)
                active_velocity_delta_world_m_s = @($activeDelta)
                active_velocity_delta_magnitude_m_s = Get-QsdkR10fL9VectorNorm $activeDelta
                baseline_velocity_delta_world_m_s = @($baselineDelta)
                baseline_velocity_delta_magnitude_m_s = Get-QsdkR10fL9VectorNorm $baselineDelta
                paired_kick_effect_delta_world_m_s = @($pairedDelta)
                paired_kick_effect_magnitude_m_s = $pairedMagnitude
                native_effect_floor_m_s = $script:QsdkR10fL9NativeEffectFloor
                matched_no_kick_delta_subtracted = $true
            }
        }
    }
    $failedPredicates = @(
        foreach ($key in $predicates.Keys) { if (-not [bool]$predicates[$key]) { $key } }
    )
    if ($failedPredicates.Count -gt 0) {
        return [ordered]@{
            schema_version = "sporespore_qsdk_r10f_l9_process_isolated_pair_evaluation_v1"
            gate_id = $script:QsdkR10fL9GateId
            repair_id = $script:QsdkR10fL9RepairId
            ok = $false
            status = "invalid_or_incomplete_pair_measurement"
            evidence_valid = $false
            measurement_complete = $false
            route_execution_valid = $false
            outcome_complete = $false
            behavior_passed = $false
            scientific_outcome = "none"
            failure_code = "QSDK_R10F_L9_PAIR_SOURCE_VALIDATION_FAILED"
            evaluator_invocation_count = 1
            pair_source_predicates = $predicates
            failed_pair_source_predicates = $failedPredicates
            computed_measurements = $measurements
            pair_alignment_basis = "phase_local_receipts_and_walking_session_local_steps"
            global_solver_step_values_rewritten_for_pair_alignment = $false
            trace_truncation_used_for_pair_alignment = $false
            force_aware_recovery = $false
            physical_acceptance_authority = $false
            release_authority = $false
        }
    }

    $baselineWalking = Get-QsdkR10fL9WalkingProjection $BaselineReport $script:QsdkR10fL9BaselineRole
    $activeWalking = Get-QsdkR10fL9WalkingProjection $ActiveReport $script:QsdkR10fL9ActiveRole
    $walkingEvidenceValid = [bool]$baselineWalking.ok -and [bool]$activeWalking.ok
    $baselineSegments = $baselineWalking.behavior_by_segment
    $activeSegments = $activeWalking.behavior_by_segment
    $baselineRequiredPresent = (
        $baselineSegments.Contains("walking_prefix") -and
        $baselineSegments.Contains("matched_continuation")
    )
    $activePrefixPresent = $activeSegments.Contains("walking_prefix")
    $activePositive = [string]$ActiveReport.role_outcome -ceq "behavior_positive"
    $activeResumePresentWhenRequired = (
        -not $activePositive -or $activeSegments.Contains("walking_resume")
    )
    $routeEvidenceValid = (
        $walkingEvidenceValid -and $baselineRequiredPresent -and
        $activePrefixPresent -and $activeResumePresentWhenRequired
    )
    if (-not $routeEvidenceValid) {
        return [ordered]@{
            schema_version = "sporespore_qsdk_r10f_l9_process_isolated_pair_evaluation_v1"
            gate_id = $script:QsdkR10fL9GateId
            repair_id = $script:QsdkR10fL9RepairId
            ok = $false
            status = "invalid_or_incomplete_pair_route_evidence"
            evidence_valid = $false
            measurement_complete = $false
            route_execution_valid = $false
            outcome_complete = $false
            behavior_passed = $false
            scientific_outcome = "none"
            failure_code = "QSDK_R10F_L9_PAIR_ROUTE_EVIDENCE_INVALID"
            evaluator_invocation_count = 1
            baseline_walking = $baselineWalking
            active_walking = $activeWalking
            computed_measurements = $measurements
            physical_acceptance_authority = $false
            release_authority = $false
        }
    }

    $behaviorPassed = (
        [string]$BaselineReport.role_outcome -ceq "matched_reference_complete" -and
        $activePositive -and
        [bool]$BaselineReport.reached_walking_prefix -and
        [bool]$BaselineReport.reached_interaction -and
        [bool]$ActiveReport.reached_walking_prefix -and
        [bool]$ActiveReport.reached_interaction -and
        [bool]$ActiveReport.reached_post_kick_recovery -and
        [bool]$ActiveReport.reached_walking_resume -and
        [bool]$baselineWalking.all_retained_session_behaviors_passed -and
        [bool]$activeWalking.all_retained_session_behaviors_passed
    )
    return [ordered]@{
        schema_version = "sporespore_qsdk_r10f_l9_process_isolated_pair_evaluation_v1"
        gate_id = $script:QsdkR10fL9GateId
        repair_id = $script:QsdkR10fL9RepairId
        ok = $true
        status = if ($behaviorPassed) {
            "valid_complete_behavior_positive_development"
        } else {
            "valid_complete_behavior_negative_development"
        }
        evidence_valid = $true
        measurement_complete = $true
        route_execution_valid = $true
        outcome_complete = $true
        behavior_passed = $behaviorPassed
        scientific_outcome = if ($behaviorPassed) { "positive" } else { "negative" }
        failure_code = ""
        evaluator_invocation_count = 1
        pair_source_predicates = $predicates
        failed_pair_source_predicates = @()
        computed_measurements = $measurements
        baseline_walking = $baselineWalking
        active_walking = $activeWalking
        route_receipts = [ordered]@{
            both_children_independently_validated = $true
            both_preconditions_complete = $true
            active_one_native_kick_retained = $true
            baseline_zero_kick_retained = $true
            paired_native_effect_meets_frozen_floor = $true
            full_child_traces_retained = $true
            phase_local_alignment_only = $true
            global_step_rewriting_absent = $true
            trace_truncation_absent = $true
        }
        pair_alignment_basis = "phase_local_receipts_and_walking_session_local_steps"
        global_solver_step_values_rewritten_for_pair_alignment = $false
        trace_truncation_used_for_pair_alignment = $false
        outcome_derived_correction = $false
        force_aware_recovery = $false
        physical_acceptance_authority = $false
        release_authority = $false
    }
}


function Invoke-QsdkR10fL9ProcessPopulationEvaluation {
    [CmdletBinding()]
    param(
        [AllowNull()][object]$ChildEnvelopes,
        [Parameter(Mandatory)][string]$ExpectedParentAttemptId,
        [Parameter(Mandatory)][string]$ExpectedSourceCommit,
        [Parameter(Mandatory)][string]$ExpectedAuthoritySha256,
        [int]$EvaluatorInvocationCountBeforeValidation = 0,
        [switch]$RequireL15LaunchRelationship,
        [AllowNull()][System.Collections.IDictionary]$ExpectedRuntimeBinding = $null,
        [AllowNull()][object]$ExpectedChildManifest = $null,
        [AllowNull()][object]$ExpectedL15ContextBinding = $null,
        [AllowNull()][object]$ExpectedL15CollectionIdentity = $null
    )
    $errors = [System.Collections.Generic.List[string]]::new()
    if ($script:QsdkR10fL9RepairId -ceq 'QSDK-R10F-L15') { $RequireL15LaunchRelationship = $true }
    if ($RequireL15LaunchRelationship) {
        . (Join-Path $PSScriptRoot 'qsdk_r10f_l15_launch_relationship.ps1')
    }
    $envelopesValid = $ChildEnvelopes -is [System.Collections.IList]
    if (-not $envelopesValid) {
        $errors.Add("CHILD_ENVELOPES_NOT_ARRAY")
        $ChildEnvelopes = @()
    }
    Add-QsdkR10fL9ValidationError $errors ($ChildEnvelopes.Count -eq 2) (
        "ORDERED_CHILD_COUNT_INVALID:" + $ChildEnvelopes.Count
    )
    Add-QsdkR10fL9ValidationError $errors (
        Test-QsdkR10fL9LowerHex $ExpectedParentAttemptId -Length 32
    ) "PARENT_ATTEMPT_ID_INVALID"
    Add-QsdkR10fL9ValidationError $errors (
        Test-QsdkR10fL9LowerHex $ExpectedSourceCommit -Length 40
    ) "EXPECTED_SOURCE_COMMIT_INVALID"
    Add-QsdkR10fL9ValidationError $errors (
        Test-QsdkR10fL9Sha256 $ExpectedAuthoritySha256
    ) "EXPECTED_AUTHORITY_SHA_INVALID"
    Add-QsdkR10fL9ValidationError $errors (
        $EvaluatorInvocationCountBeforeValidation -eq 0
    ) "PAIR_EVALUATOR_INVOKED_BEFORE_POPULATION_VALIDATION"

    $childValidations = @()
    $childIds = [System.Collections.Generic.List[string]]::new()
    $nonces = [System.Collections.Generic.List[string]]::new()
    $paths = [System.Collections.Generic.List[string]]::new()
    $processIds = [System.Collections.Generic.List[int]]::new()
    $parsedTimes = @()
    for ($index = 0; $index -lt [Math]::Min(2, $ChildEnvelopes.Count); $index++) {
        $envelope = $ChildEnvelopes[$index]
        $expectedRole = $script:QsdkR10fL9Roles[$index]
        if ($envelope -isnot [System.Collections.IDictionary]) {
            $errors.Add("CHILD_ENVELOPE_NOT_OBJECT:" + $index)
            continue
        }
        foreach ($key in @(
            "role", "child_attempt_id", "termination_nonce", "evidence_path",
            "child_retry_count", "child_replacement_count", "started_utc", "completed_utc",
            "process_id", "worker_process_id", "exit_code", "termination_protocol_valid",
            "engine_health_passed", "raw_marker_valid", "report"
        )) {
            if (-not $envelope.Contains($key)) {
                $errors.Add("CHILD_ENVELOPE_KEY_MISSING:${index}:$key")
            }
        }
        if ($errors.Exists({
            param($value)
            $value.StartsWith("CHILD_ENVELOPE_KEY_MISSING:${index}:")
        })) {
            continue
        }
        Add-QsdkR10fL9ValidationError $errors (
            [string]$envelope.role -ceq $expectedRole
        ) ("ORDERED_CHILD_ROLE_INVALID:" + $index)
        Add-QsdkR10fL9ValidationError $errors (
            (Test-QsdkR10fL9LowerHex $envelope.child_attempt_id -Length 32) -and
            [string]$envelope.child_attempt_id -cne $ExpectedParentAttemptId
        ) ("CHILD_ATTEMPT_ID_INVALID:" + $index)
        Add-QsdkR10fL9ValidationError $errors (
            Test-QsdkR10fL9LowerHex $envelope.termination_nonce -Length 32
        ) ("CHILD_TERMINATION_NONCE_INVALID:" + $index)
        $resolvedPath = ""
        try { $resolvedPath = [IO.Path]::GetFullPath([string]$envelope.evidence_path) } catch { }
        Add-QsdkR10fL9ValidationError $errors (-not [string]::IsNullOrEmpty($resolvedPath)) (
            "CHILD_EVIDENCE_PATH_INVALID:" + $index
        )
        Add-QsdkR10fL9ValidationError $errors (
            (Test-QsdkR10fL9ExactInteger $envelope.child_retry_count -Expected 0) -and
            (Test-QsdkR10fL9ExactInteger $envelope.child_replacement_count -Expected 0)
        ) ("CHILD_RETRY_OR_REPLACEMENT_INVALID:" + $index)
        if ($RequireL15LaunchRelationship) {
            try {
                Assert-QsdkR10fL15Launch (
                    $ExpectedChildManifest -is [System.Collections.IList] -and
                    $ExpectedChildManifest.Count -eq 2
                ) 'EXPECTED_CHILD_MANIFEST'
                $launchContext = New-QsdkR10fL15ProductionLaunchContext `
                    $ExpectedParentAttemptId $ExpectedChildManifest[$index] $ExpectedSourceCommit `
                    $ExpectedAuthoritySha256 $ExpectedRuntimeBinding
                $null = Assert-QsdkR10fL15ChildLaunchRelationship $envelope $launchContext
            } catch {
                $errors.Add("CHILD_PROCESS_RECEIPT_INVALID:${index}:" + $_.Exception.Message)
            }
        } else {
            Add-QsdkR10fL9ValidationError $errors (
                (Test-QsdkR10fL9ExactInteger $envelope.process_id -Minimum 1) -and
                (Test-QsdkR10fL9ExactInteger $envelope.worker_process_id `
                    -Expected ([int64]$envelope.process_id))
            ) ("CHILD_PROCESS_RECEIPT_INVALID:" + $index)
        }
        Add-QsdkR10fL9ValidationError $errors (
            (Test-QsdkR10fL9ExactInteger $envelope.exit_code -Expected 0) -and
            [bool]$envelope.termination_protocol_valid -and
            [bool]$envelope.engine_health_passed -and
            [bool]$envelope.raw_marker_valid
        ) ("CHILD_TERMINATION_OR_ENGINE_HEALTH_INVALID:" + $index)
        $start = [DateTimeOffset]::MinValue
        $complete = [DateTimeOffset]::MinValue
        $startValid = [DateTimeOffset]::TryParse(
            [string]$envelope.started_utc,
            [Globalization.CultureInfo]::InvariantCulture,
            [Globalization.DateTimeStyles]::RoundtripKind,
            [ref]$start
        )
        $completeValid = [DateTimeOffset]::TryParse(
            [string]$envelope.completed_utc,
            [Globalization.CultureInfo]::InvariantCulture,
            [Globalization.DateTimeStyles]::RoundtripKind,
            [ref]$complete
        )
        Add-QsdkR10fL9ValidationError $errors (
            $startValid -and $completeValid -and $complete -ge $start
        ) ("CHILD_PROCESS_LIFETIME_INVALID:" + $index)
        $parsedTimes += ,([ordered]@{ started = $start; completed = $complete })
        $childIds.Add([string]$envelope.child_attempt_id)
        $nonces.Add([string]$envelope.termination_nonce)
        $paths.Add($resolvedPath)
        $processIds.Add([int]$envelope.process_id)
        $validation = Get-QsdkR10fL9ChildValidation `
            -Report $envelope.report `
            -ExpectedRole $expectedRole `
            -ExpectedParentAttemptId $ExpectedParentAttemptId `
            -ExpectedChildAttemptId ([string]$envelope.child_attempt_id) `
            -ExpectedSourceCommit $ExpectedSourceCommit `
            -ExpectedAuthoritySha256 $ExpectedAuthoritySha256 `
            -ExpectedWorkerProcessId ([int]$envelope.worker_process_id) `
            -ExpectedL15ContextBinding $ExpectedL15ContextBinding `
            -ExpectedL15CollectionIdentity $ExpectedL15CollectionIdentity
        $childValidations += ,$validation
        if (-not [bool]$validation.ok) {
            foreach ($childError in $validation.validation_errors) {
                $errors.Add("CHILD_${index}:" + [string]$childError)
            }
        }
    }
    if ($childIds.Count -eq 2) {
        Add-QsdkR10fL9ValidationError $errors (
            $childIds[0] -cne $childIds[1]
        ) "DUPLICATE_CHILD_ATTEMPT_ID"
        Add-QsdkR10fL9ValidationError $errors ($nonces[0] -cne $nonces[1]) (
            "DUPLICATE_CHILD_TERMINATION_NONCE"
        )
        Add-QsdkR10fL9ValidationError $errors (
            -not [StringComparer]::OrdinalIgnoreCase.Equals($paths[0], $paths[1])
        ) "DUPLICATE_CHILD_EVIDENCE_PATH"
        Add-QsdkR10fL9ValidationError $errors (
            $processIds[0] -ne $processIds[1]
        ) "DUPLICATE_CHILD_PROCESS_ID"
    }
    if ($parsedTimes.Count -eq 2) {
        Add-QsdkR10fL9ValidationError $errors (
            $parsedTimes[0].completed -le $parsedTimes[1].started
        ) "CHILD_PROCESS_LIFETIMES_OVERLAP"
    }
    if ($childValidations.Count -eq 2 -and [bool]$childValidations[0].ok -and
        [bool]$childValidations[1].ok) {
        Add-QsdkR10fL9ValidationError $errors (
            [string]$childValidations[0].configuration_sha256 -ceq
                [string]$childValidations[1].configuration_sha256
        ) "CHILD_FROZEN_CONFIGURATION_MISMATCH"
    }

    if ($errors.Count -gt 0) {
        return [ordered]@{
            schema_version = "sporespore_qsdk_r10f_l9_process_population_evaluation_v1"
            gate_id = $script:QsdkR10fL9GateId
            repair_id = $script:QsdkR10fL9RepairId
            ok = $false
            status = "invalid_or_incomplete_process_population"
            evidence_valid = $false
            measurement_complete = $false
            route_execution_valid = $false
            outcome_complete = $false
            behavior_passed = $false
            scientific_outcome = "none"
            failure_code = "QSDK_R10F_L9_PROCESS_POPULATION_VALIDATION_FAILED"
            population_validation_errors = @($errors)
            child_validations = @($childValidations)
            ordered_child_count = $ChildEnvelopes.Count
            process_lifetimes_overlap = $null
            evaluator_invocation_count = 0
            model_construction_count = 0
            world_attempt_count = 0
            world_build_count = 0
            native_readback_count = 0
            solver_step_count = 0
            physics_state_modified = $false
            physical_acceptance_authority = $false
            release_authority = $false
        }
    }

    $baseline = $ChildEnvelopes[0].report
    $active = $ChildEnvelopes[1].report
    $pair = Invoke-QsdkR10fL9PairEvaluator -BaselineReport $baseline -ActiveReport $active
    $totalSolverSteps = [int64]$baseline.solver_step_count + [int64]$active.solver_step_count
    return [ordered]@{
        schema_version = "sporespore_qsdk_r10f_l9_process_population_evaluation_v1"
        gate_id = $script:QsdkR10fL9GateId
        repair_id = $script:QsdkR10fL9RepairId
        ok = [bool]$pair.ok
        status = [string]$pair.status
        evidence_valid = [bool]$pair.evidence_valid
        measurement_complete = [bool]$pair.measurement_complete
        route_execution_valid = [bool]$pair.route_execution_valid
        outcome_complete = [bool]$pair.outcome_complete
        behavior_passed = [bool]$pair.behavior_passed
        scientific_outcome = [string]$pair.scientific_outcome
        failure_code = [string]$pair.failure_code
        population_validation_errors = @()
        child_validations = @($childValidations)
        ordered_child_count = 2
        ordered_child_roles = @($script:QsdkR10fL9Roles)
        child_attempt_ids = @($childIds)
        child_process_ids = @($processIds)
        child_evidence_paths = @($paths)
        process_lifetimes_overlap = $false
        serialized_fresh_processes_valid = $true
        all_declared_children_present = $true
        child_retry_or_replacement_used = $false
        evaluator_invocation_count = [int]$pair.evaluator_invocation_count
        pair_evaluation = $pair
        model_construction_count = 2
        world_attempt_count = 2
        world_build_count = 2
        solver_step_count = $totalSolverSteps
        maximum_solver_step_count = $script:QsdkR10fL9MaximumTotalSolverSteps
        physics_state_modified = $totalSolverSteps -gt 0
        physical_acceptance_authority = $false
        release_authority = $false
    }
}


function New-QsdkR10fL12SyntheticWalkingHandoff {
    param(
        [Parameter(Mandatory)][string]$ModelInstanceId,
        [Parameter(Mandatory)][ValidateSet(
            "walking_prefix", "matched_continuation", "walking_resume"
        )][string]$EvaluationSegment,
        [Parameter(Mandatory)][string]$SessionId,
        [Parameter(Mandatory)][int64]$GlobalSemanticStep
    )
    $shaA = "sha256:" + ("a" * 64)
    $shaB = "sha256:" + ("b" * 64)
    $shaC = "sha256:" + ("c" * 64)
    $reason = "l12_walking_actuation_handoff_precommand:$EvaluationSegment"
    $configurationRows = [System.Collections.Generic.List[object]]::new()
    $readbackRows = [System.Collections.Generic.List[object]]::new()
    $projectionRows = [System.Collections.Generic.List[object]]::new()
    $publishedMap = [ordered]@{}
    $hostMap = [ordered]@{}
    for ($index = 0; $index -lt 8; $index++) {
        $actuatorId = [string]$script:QsdkR10fL12ActuatorIds[$index]
        $jointId = [string]$script:QsdkR10fL12JointIds[$index]
        $published = [double]$script:QsdkR10fL12PublishedCaps[$index]
        $hostCap = [double]$script:QsdkR10fL12HostCaps[$index]
        $publishedMap[$actuatorId] = $published
        $hostMap[$actuatorId] = $hostCap
        $configurationRows.Add([ordered]@{
            joint_id = $jointId
            motor_enabled = $true
            motor_target_velocity_rad_s = 0.0
        })
        $readbackRows.Add([ordered]@{
            joint_id = $jointId
            actuator_id = $actuatorId
            motor_enabled = $true
            motor_target_velocity_rad_s = 0.0
            motor_maximum_impulse_nms = $hostCap
        })
        $projectionRows.Add([ordered]@{
            projection_id = $script:QsdkR10fL12ProjectionId
            scope = $script:QsdkR10fL12ProjectionScope
            actuator_id = $actuatorId
            actuator_index = $index
            published_maximum_outer_step_impulse_nms = $published
            configured_host_maximum_impulse_nms = $hostCap
            next_binary32_host_maximum_impulse_nms = $published
            native_effective_limit_not_above_published = $true
            next_native_effective_limit_above_published = $true
            configured_to_next_binary32_ulp_distance = 1
            published_cap_changed = $false
            empirical_margin_added = $false
            measurement_clamped = $false
        })
    }
    $configuration = [ordered]@{
        schema_version = $script:QsdkR10fL12MotorConfigurationSchema
        gate_id = $script:QsdkR10fL9GateId
        ok = $true
        global_semantic_step = $GlobalSemanticStep
        reason = $reason
        motor_enabled = $true
        ordered_joint_receipts = @($configurationRows)
        motor_configuration_write_count = 16
        body_transform_write_count = 0
        body_velocity_write_count = 0
        body_impulse_write_count = 0
        solver_reset_count = 0
        physics_state_modified = $true
        physical_acceptance_authority = $false
        release_authority = $false
    }
    $readback = [ordered]@{
        schema_version = $script:QsdkR10fL12MotorReadbackSchema
        gate_id = $script:QsdkR10fL9GateId
        ok = $true
        global_semantic_step = $GlobalSemanticStep
        reason = $reason
        expected_motor_enabled = $true
        ordered_joint_readbacks = @($readbackRows)
        motor_enabled_count = 8
        zero_target_velocity_count = 8
        native_readback_count = 24
        body_transform_write_count = 0
        body_velocity_write_count = 0
        body_impulse_write_count = 0
        solver_reset_count = 0
        solver_step_count = 0
        physics_state_modified = $false
        physical_acceptance_authority = $false
        release_authority = $false
    }
    $binding = [ordered]@{
        schema_version = $script:QsdkR10fL12HostCapBindingSchema
        gate_id = $script:QsdkR10fL9GateId
        ok = $true
        projection_id = $script:QsdkR10fL12ProjectionId
        scope = $script:QsdkR10fL12ProjectionScope
        selection_rule = (
            "greatest_binary32_host_input_whose_complete_native_effective_" +
            "impulse_projection_is_not_above_the_unchanged_published_cap"
        )
        ordered_actuator_ids = @($script:QsdkR10fL12ActuatorIds)
        ordered_published_caps_nms = @($script:QsdkR10fL12PublishedCaps)
        ordered_selected_host_caps_nms = @($script:QsdkR10fL12HostCaps)
        published_cap_by_actuator_id = $publishedMap
        selected_host_cap_by_actuator_id = $hostMap
        ordered_projection_receipts = @($projectionRows)
        projection_count = 8
        selected_effective_limit_not_above_published_count = 8
        immediately_higher_effective_limit_above_published_count = 8
        binary32_maximality_proof_count = 8
        published_cap_changed = $false
        empirical_margin_added = $false
        raw_measurement_clamped = $false
        model_construction_count = 0
        world_attempt_count = 0
        world_build_count = 0
        solver_step_count = 0
        physics_state_modified = $false
        physical_acceptance_authority = $false
        release_authority = $false
        payload_sha256 = $shaA
    }
    return [ordered]@{
        schema_version = $script:QsdkR10fL12HandoffSchema
        gate_id = $script:QsdkR10fL9GateId
        ok = $true
        facade_id = $script:QsdkR10fL12FacadeId
        model_instance_id = $ModelInstanceId
        facade_segment_id = if ($EvaluationSegment -ceq "walking_prefix") {
            "walking_prefix"
        } else { "walking_resume" }
        evaluation_segment_id = $EvaluationSegment
        walking_session_id = $SessionId
        global_semantic_step = $GlobalSemanticStep
        selected_policy_id = $script:QsdkR10fL9PolicyId
        selected_policy_digest = $script:QsdkR10fL9PolicyDigest
        motor_configuration_receipt = $configuration
        motor_configuration_receipt_sha256 = $shaA
        precommand_motor_population_readback = $readback
        precommand_motor_population_readback_sha256 = $shaB
        host_cap_projection_binding = $binding
        host_cap_projection_binding_sha256 = $shaA
        ordered_actuator_ids = @($script:QsdkR10fL12ActuatorIds)
        published_cap_by_actuator_id = $publishedMap
        authorized_host_cap_by_actuator_id = $hostMap
        motor_enabled_count = 8
        zero_target_velocity_count = 8
        motor_configuration_write_count = 16
        native_readback_count = 24
        solver_step_count = 0
        body_transform_write_count = 0
        body_velocity_write_count = 0
        body_impulse_write_count = 0
        solver_reset_count = 0
        physics_state_modified = $true
        outcome_derived_correction = $false
        physical_acceptance_authority = $false
        release_authority = $false
        payload_sha256 = $shaC
    }
}


function New-QsdkR10fL9SyntheticChildReport {
    param(
        [Parameter(Mandatory)][string]$Role,
        [Parameter(Mandatory)][string]$ParentAttemptId,
        [Parameter(Mandatory)][string]$ChildAttemptId,
        [Parameter(Mandatory)][string]$SourceCommit,
        [Parameter(Mandatory)][string]$AuthoritySha256,
        [Parameter(Mandatory)][int]$ProcessId,
        [ValidateSet("positive", "behavior_negative", "precondition_negative")]
        [string]$Outcome = "positive"
    )
    $shaA = "sha256:" + ("a" * 64)
    $shaB = "sha256:" + ("b" * 64)
    $shaC = "sha256:" + ("c" * 64)
    $shaD = "sha256:" + ("d" * 64)
    $solverCount = 6
    $preconditionNegative = $Outcome -ceq "precondition_negative"
	$terminalPhase = if ($preconditionNegative) { "failed" } else { "complete" }
	$terminalFailureSource = if ($preconditionNegative) {
		"phase_timeout:stance_dwell"
	} else { $null }
	$projectedFailureCode = if ($preconditionNegative) {
		$terminalFailureSource
	} else { "" }
    $disposition = if ($preconditionNegative) {
        "failed_source_retained"
    } else {
        "complete_source_retained"
    }
    $terminal = [ordered]@{
        schema_version = $script:QsdkR10fL9PreconditionSchema
        gate_id = $script:QsdkR10fL9GateId
        repair_id = $script:QsdkR10fL9ChildContractRepairId
        parent_attempt_id = $ParentAttemptId
        child_attempt_id = $ChildAttemptId
        arm_id = $Role
        model_instance_id = "synthetic-model-$Role"
        completed_global_semantic_step = 1
        disposition = $disposition
        recovery_controller_id = $script:QsdkR10fL9ControllerId
		recovery_terminal_phase = $terminalPhase
		recovery_terminal_failure_code = $projectedFailureCode
		recovery_memory = [ordered]@{
			phase = $terminalPhase
			last_semantic_step = 1
			terminal_failure_code = $terminalFailureSource
		}
        recovery_memory_sha256 = $shaA
        recovery_step_receipt = [ordered]@{ synthetic = $true }
        recovery_step_receipt_sha256 = $shaB
        recovery_classification = [ordered]@{ stable_stance_gate = -not $preconditionNegative }
        recovery_classification_sha256 = $shaC
        stable_four_foot_stance = -not $preconditionNegative
        body_transform_write_count = 0
        body_velocity_write_count = 0
        solver_reset_count = 0
        source_measurement = $true
        outcome_derived_correction = $false
        physical_acceptance_authority = $false
        release_authority = $false
        payload_sha256 = $shaD
    }
    $release = if ($preconditionNegative) { [ordered]@{} } else {
        $releaseOwnerSource = [ordered]@{
            schema_version = $script:QsdkR10fL11ReleaseOwnerSourceSchema
            gate_id = $script:QsdkR10fL9GateId
            repair_id = $script:QsdkR10fL11ReleaseRepairId
            parent_attempt_id = $ParentAttemptId
            child_attempt_id = $ChildAttemptId
            arm_id = $Role
            model_instance_id = "synthetic-model-$Role"
            completed_terminal_global_semantic_step = 1
            release_global_semantic_step = 2
            source_kind = "validated_complete_precondition_release_no_actuation"
            precondition_terminal_receipt_sha256 = $shaD
            recovery_memory_sha256 = $shaA
            recovery_step_receipt_sha256 = $shaB
            source_measurement = $true
            outcome_derived_correction = $false
            physical_acceptance_authority = $false
            release_authority = $false
            payload_sha256 = $shaA
        }
        $configurationReceipt = [ordered]@{
            ok = $true
            global_semantic_step = 2
            motor_enabled = $false
            ordered_joint_receipts = @()
        }
        $populationReadback = [ordered]@{
            ok = $true
            global_semantic_step = 2
            expected_motor_enabled = $false
            motor_enabled_count = 0
            zero_target_velocity_count = 8
            native_readback_count = 24
            ordered_joint_readbacks = @()
        }
        $releaseLedger = [ordered]@{
            ok = $true
            semantic_step = 2
            no_actuation_requested = $true
            controller_owner = "none"
            owner_source_receipt = $releaseOwnerSource
            owner_source_receipt_sha256 = $shaB
            motor_population_readback = $populationReadback
        }
        [ordered]@{
            schema_version = $script:QsdkR10fL9ReleaseSchema
            gate_id = $script:QsdkR10fL9GateId
            repair_id = $script:QsdkR10fL11ReleaseRepairId
            parent_attempt_id = $ParentAttemptId
            child_attempt_id = $ChildAttemptId
            arm_id = $Role
            model_instance_id = "synthetic-model-$Role"
            global_semantic_step = 2
            action_kind = "process_isolated_no_actuation_release"
            precondition_terminal_receipt = $terminal
            precondition_terminal_receipt_sha256 = $shaD
            motor_configuration_receipt = $configurationReceipt
            motor_configuration_receipt_sha256 = $shaA
            motor_population_readback = $populationReadback
            motor_population_readback_sha256 = $shaB
            ledger_application_intent = $releaseLedger
            ledger_application_intent_sha256 = $shaC
            ordered_motor_readbacks = @()
            no_actuation_requested = $true
            control_owner = "none"
            actuation_owner = "none"
            body_transform_write_count = 0
            body_velocity_write_count = 0
            solver_reset_count = 0
            source_measurement = $true
            outcome_derived_correction = $false
            physical_acceptance_authority = $false
            release_authority = $false
            payload_sha256 = $shaC
        }
    }
    $isActive = $Role -ceq $script:QsdkR10fL9ActiveRole
    $interaction = if ($preconditionNegative) { [ordered]@{} } else {
        $before = @(0.10, 0.0, -0.01)
        $delta = if ($isActive) { @(0.0, 0.0, 0.020) } else { @(0.0, 0.0, 0.001) }
        $after = @(
            ([double]$before[0] + [double]$delta[0])
            ([double]$before[1] + [double]$delta[1])
            ([double]$before[2] + [double]$delta[2])
        )
        [ordered]@{
            schema_version = $script:QsdkR10fL9InteractionSchema
            gate_id = $script:QsdkR10fL9GateId
            repair_id = $script:QsdkR10fL9ChildContractRepairId
            parent_attempt_id = $ParentAttemptId
            child_attempt_id = $ChildAttemptId
            arm_id = $Role
            model_instance_id = "synthetic-model-$Role"
            completed_effect_global_step = 4
            interaction_local_step = 1
            prefix_session_id = "synthetic-prefix-$Role"
            prefix_session_receipt_sha256 = $shaA
            task_frame_forward_axis_world_host_real = @(1.0, 0.0, 0.0)
            task_frame_lateral_axis_world_host_real = @(0.0, 0.0, 1.0)
            scheduled_impulse_world_n_s = if ($isActive) { @(0.0, 0.0, 0.25) } else {
                @(0.0, 0.0, 0.0)
            }
            pre_event_velocity_world_m_s = $before
            completed_effect_velocity_world_m_s = $after
            raw_velocity_delta_world_m_s = $delta
            raw_velocity_delta_magnitude_m_s = if ($isActive) { 0.020 } else { 0.001 }
            application_count = if ($isActive) { 1 } else { 0 }
            source_measurement = $true
            outcome_derived_correction = $false
            global_step_rewritten_for_pair_alignment = $false
            force_aware_recovery_used = $false
            physical_acceptance_authority = $false
            release_authority = $false
            payload_sha256 = $shaB
        }
    }
    $rows = @(
        for ($step = 1; $step -le $solverCount; $step++) {
            [ordered]@{
                arm_id = $Role
                global_semantic_step = $step
                source_measurement = $true
            }
        }
    )
    $invariants = @(
        for ($step = 1; $step -le $solverCount; $step++) {
            [ordered]@{
                arm_id = $Role
                global_semantic_step = $step
                all_in_run_physical_invariants_passed = $true
                physical_acceptance_authority = $false
                release_authority = $false
            }
        }
    )
    $segments = @(
        if (-not $preconditionNegative) {
            "walking_prefix"
            if ($isActive) { "walking_resume" } else { "matched_continuation" }
        }
    )
    $walkingHandoffs = @(
        for ($index = 0; $index -lt $segments.Count; $index++) {
            $segment = [string]$segments[$index]
            $handoffStep = if ($index -eq 0) { 3 } else { 5 }
            New-QsdkR10fL12SyntheticWalkingHandoff `
                -ModelInstanceId "synthetic-model-$Role" `
                -EvaluationSegment $segment `
                -SessionId "synthetic-$segment-$Role" `
                -GlobalSemanticStep $handoffStep
        }
    )
    $walkingSessions = @(
        foreach ($segment in $segments) {
            $segmentBehavior = -not ($Outcome -ceq "behavior_negative" -and $segment -ceq "walking_resume")
            [ordered]@{
                session_id = "synthetic-$segment-$Role"
                evaluation_segment_id = $segment
                evaluation = [ordered]@{
                    ok = $true
                    evidence_valid = $true
                    outcome_complete = $true
                    behavior_passed = $segmentBehavior
                    arm_id = $Role
                    segment_id = $segment
                    physical_acceptance_authority = $false
                    release_authority = $false
                }
            }
        }
    )
    $trace = [ordered]@{
        schema_version = $script:QsdkR10fL9TraceSchema
        gate_id = $script:QsdkR10fL9GateId
        repair_id = $script:QsdkR10fL9RepairId
        parent_attempt_id = $ParentAttemptId
        child_attempt_id = $ChildAttemptId
        arm_id = $Role
        model_instance_id = "synthetic-model-$Role"
        body_population_instance_sha256 = $shaA
        rows = $rows
    }
    $roleOutcome = if ($preconditionNegative) {
        "precondition_negative"
    } elseif (-not $isActive) {
        "matched_reference_complete"
    } elseif ($Outcome -ceq "behavior_negative") {
        "behavior_negative"
    } else { "behavior_positive" }
    $armResult = [ordered]@{
        schema_version = $script:QsdkR10fL9ArmResultSchema
        gate_id = $script:QsdkR10fL9GateId
        repair_id = $script:QsdkR10fL9RepairId
        ok = $true
        parent_attempt_id = $ParentAttemptId
        child_attempt_id = $ChildAttemptId
        arm_id = $Role
        model_instance_id = "synthetic-model-$Role"
        same_body_identity_preserved = $true
        precondition_terminal_receipt_sha256 = $shaD
        precondition_release_receipt_sha256 = if ($preconditionNegative) { "" } else { $shaC }
        precondition_release_receipt_valid = -not $preconditionNegative
        walking_sessions = $walkingSessions
        walking_actuation_handoff_receipts = $walkingHandoffs
        interaction_source = $interaction
        external_kick_application_count = if ($isActive -and -not $preconditionNegative) { 1 } else { 0 }
        trace = $trace
        trace_sha256 = $shaA
        outer_step_count = $solverCount
        native_solver_step_count = $solverCount
        in_run_invariant_receipts = $invariants
        in_run_invariant_receipt_count = $solverCount
        all_in_run_physical_invariants_passed = $true
        body_population_rebuild_count = 0
        body_transform_write_count = 0
        body_velocity_write_count = 0
        solver_reset_count = 0
        global_step_values_rewritten_for_pair_alignment = $false
        full_trace_retained = $true
        physical_acceptance_authority = $false
        release_authority = $false
    }
    $configuration = [ordered]@{
        ok = $true
        gate_id = $script:QsdkR10fL9GateId
        selected_policy_id = $script:QsdkR10fL9PolicyId
        selected_policy_digest = $script:QsdkR10fL9PolicyDigest
        recovery_morphology_spec_sha256 = $script:QsdkR10fL9RecoveryMorphologySha
        actuator_profile_id = $script:QsdkR10fL9ActuatorProfileId
        actuator_profile_sha256 = $shaA
        material_profile_id = $script:QsdkR10fL9MaterialProfileId
        material_profile_sha256 = $shaB
        recovery_context_sha256 = $shaC
        post_construction_transform_write_permitted = $false
        post_construction_velocity_write_permitted = $false
        solver_reset_permitted = $false
        event_triggered_passive_recovery = $true
        force_aware_recovery = $false
    }
    return [ordered]@{
        schema_version = $script:QsdkR10fL9RawSchema
        gate_id = $script:QsdkR10fL9GateId
        repair_id = $script:QsdkR10fL9RepairId
        work_id = $script:QsdkR10fL9WorkId
        status = "valid_complete_process_isolated_child_development"
        ok = $true
        measurement_complete = $true
        scientific_outcome = "none"
        role_outcome = $roleOutcome
        source_commit = $SourceCommit
        authorization_sha256 = $AuthoritySha256
        parent_attempt_id = $ParentAttemptId
        child_attempt_id = $ChildAttemptId
        attempt_id = $ChildAttemptId
        arm_id = $Role
        process_id = $ProcessId
        seed = $script:QsdkR10fL9DevelopmentSeed
        seed_label = "QSDK-R10F/development/godot/event-triggered-passive-recovery-v1"
        seed_sha256 = $shaA
        actuator_mode = "solver_coupled_native_constraint_motor_v1"
        recovery_controller_id = $script:QsdkR10fL9ControllerId
        energy_route_id = "synthetic-energy-route"
        physics_ticks_per_second = 120
        held_out = $false
        held_out_cell_access_count = 0
        population_inference_claimed = $false
        one_arm_per_process = $true
        one_world_per_process = $true
        world_or_body_state_imported_from_peer = $false
        configuration = $configuration
        configuration_sha256 = $shaD
        precondition_terminal_receipt = $terminal
        precondition_terminal_receipt_sha256 = $shaD
        precondition_release_receipt = $release
        precondition_release_receipt_sha256 = if ($preconditionNegative) { "" } else { $shaC }
        interaction_source = $interaction
        interaction_source_sha256 = if ($preconditionNegative) { "" } else { $shaB }
        arm_result = $armResult
        reached_walking_prefix = -not $preconditionNegative
        reached_interaction = -not $preconditionNegative
        reached_post_kick_recovery = $isActive -and -not $preconditionNegative
        reached_walking_resume = $isActive -and -not $preconditionNegative
        behavior_evaluator_invocation_count = 0
        complete_trace_count = 1
        in_run_invariant_receipt_count = $solverCount
        all_in_run_physical_invariants_passed = $true
        same_body_identity_preserved = $true
        model_construction_attempt_count = 1
        model_construction_count = 1
        world_attempt_count = 1
        world_build_count = 1
        solver_step_count = $solverCount
        maximum_solver_step_count = $script:QsdkR10fL9MaximumChildSolverSteps
        global_solver_frame_count = $solverCount
        external_kick_application_count = if ($isActive -and -not $preconditionNegative) { 1 } else { 0 }
        physical_question_opened = $true
        physics_state_modified = $true
        force_aware_recovery = $false
        force_aware_bracing = $false
        arbitrary_fall_recovery_claimed = $false
        cross_engine_push_recovery_claimed = $false
        physical_acceptance_authority = $false
        release_authority = $false
    }
}


function Invoke-QsdkR10fL9PairEvaluatorZeroWorld {
    [CmdletBinding()]
    param()
    $parent = "0123456789abcdef0123456789abcdef"
    $source = "0123456789abcdef0123456789abcdef01234567"
    $authority = "sha256:" + ("9" * 64)
    $baselineId = "11111111111111111111111111111111"
    $activeId = "22222222222222222222222222222222"
    $baseline = New-QsdkR10fL9SyntheticChildReport `
        -Role $script:QsdkR10fL9BaselineRole -ParentAttemptId $parent `
        -ChildAttemptId $baselineId -SourceCommit $source `
        -AuthoritySha256 $authority -ProcessId 101
    $active = New-QsdkR10fL9SyntheticChildReport `
        -Role $script:QsdkR10fL9ActiveRole -ParentAttemptId $parent `
        -ChildAttemptId $activeId -SourceCommit $source `
        -AuthoritySha256 $authority -ProcessId 102
    $baseEnvelope = [ordered]@{
        role = $script:QsdkR10fL9BaselineRole
        child_attempt_id = $baselineId
        termination_nonce = "33333333333333333333333333333333"
        evidence_path = "C:\synthetic\baseline"
        child_retry_count = 0
        child_replacement_count = 0
        started_utc = "2026-09-05T00:00:00.0000000Z"
        completed_utc = "2026-09-05T00:00:01.0000000Z"
        process_id = 101
        worker_process_id = 101
        exit_code = 0
        termination_protocol_valid = $true
        engine_health_passed = $true
        raw_marker_valid = $true
        report = $baseline
    }
    $activeEnvelope = [ordered]@{
        role = $script:QsdkR10fL9ActiveRole
        child_attempt_id = $activeId
        termination_nonce = "44444444444444444444444444444444"
        evidence_path = "C:\synthetic\active"
        child_retry_count = 0
        child_replacement_count = 0
        started_utc = "2026-09-05T00:00:02.0000000Z"
        completed_utc = "2026-09-05T00:00:03.0000000Z"
        process_id = 102
        worker_process_id = 102
        exit_code = 0
        termination_protocol_valid = $true
        engine_health_passed = $true
        raw_marker_valid = $true
        report = $active
    }
    $positive = Invoke-QsdkR10fL9ProcessPopulationEvaluation `
        -ChildEnvelopes @($baseEnvelope, $activeEnvelope) `
        -ExpectedParentAttemptId $parent -ExpectedSourceCommit $source `
        -ExpectedAuthoritySha256 $authority

    $negativeActive = New-QsdkR10fL9SyntheticChildReport `
        -Role $script:QsdkR10fL9ActiveRole -ParentAttemptId $parent `
        -ChildAttemptId $activeId -SourceCommit $source `
        -AuthoritySha256 $authority -ProcessId 102 -Outcome behavior_negative
    $negativeEnvelope = Copy-QsdkR10fL9JsonValue $activeEnvelope
    $negativeEnvelope.report = $negativeActive
    $behaviorNegative = Invoke-QsdkR10fL9ProcessPopulationEvaluation `
        -ChildEnvelopes @($baseEnvelope, $negativeEnvelope) `
        -ExpectedParentAttemptId $parent -ExpectedSourceCommit $source `
        -ExpectedAuthoritySha256 $authority

    $preconditionBaseline = New-QsdkR10fL9SyntheticChildReport `
        -Role $script:QsdkR10fL9BaselineRole -ParentAttemptId $parent `
        -ChildAttemptId $baselineId -SourceCommit $source `
        -AuthoritySha256 $authority -ProcessId 101 -Outcome precondition_negative
    $preconditionEnvelope = Copy-QsdkR10fL9JsonValue $baseEnvelope
    $preconditionEnvelope.report = $preconditionBaseline
    $preconditionNegative = Invoke-QsdkR10fL9ProcessPopulationEvaluation `
        -ChildEnvelopes @($preconditionEnvelope, $activeEnvelope) `
        -ExpectedParentAttemptId $parent -ExpectedSourceCommit $source `
        -ExpectedAuthoritySha256 $authority

    $positiveControls = [ordered]@{
        valid_positive_pair_retained = (
            [bool]$positive.ok -and [bool]$positive.route_execution_valid -and
            [bool]$positive.behavior_passed -and [string]$positive.scientific_outcome -ceq "positive" -and
            (Test-QsdkR10fL9ExactInteger $positive.evaluator_invocation_count -Expected 1) -and
            $positive.child_validations.Count -eq 2 -and
            (Test-QsdkR10fL9ExactInteger `
                $positive.child_validations[0].walking_actuation_handoff_count -Expected 2) -and
            (Test-QsdkR10fL9ExactInteger `
                $positive.child_validations[1].walking_actuation_handoff_count -Expected 2)
        )
        valid_behavior_negative_is_complete_evidence = (
            [bool]$behaviorNegative.ok -and [bool]$behaviorNegative.route_execution_valid -and
            -not [bool]$behaviorNegative.behavior_passed -and
            [string]$behaviorNegative.scientific_outcome -ceq "negative" -and
            (Test-QsdkR10fL9ExactInteger $behaviorNegative.evaluator_invocation_count -Expected 1)
        )
        precondition_negative_keeps_both_children_and_no_r10f_outcome = (
            [bool]$preconditionNegative.ok -and [bool]$preconditionNegative.evidence_valid -and
            -not [bool]$preconditionNegative.route_execution_valid -and
            [string]$preconditionNegative.scientific_outcome -ceq "none" -and
            (Test-QsdkR10fL9ExactInteger $preconditionNegative.ordered_child_count -Expected 2) -and
            (Test-QsdkR10fL9ExactInteger $preconditionNegative.evaluator_invocation_count -Expected 1)
        )
    }

    $mutationControls = [ordered]@{}
    function Test-MutatedPopulationRefused {
        param([Parameter(Mandatory)][object[]]$Envelopes, [int]$PriorInvocation = 0)
        $result = Invoke-QsdkR10fL9ProcessPopulationEvaluation `
            -ChildEnvelopes $Envelopes -ExpectedParentAttemptId $parent `
            -ExpectedSourceCommit $source -ExpectedAuthoritySha256 $authority `
            -EvaluatorInvocationCountBeforeValidation $PriorInvocation
        return -not [bool]$result.ok -and [int]$result.evaluator_invocation_count -eq 0
    }
    $sharedProcess = Copy-QsdkR10fL9JsonValue $activeEnvelope; $sharedProcess.process_id = 101
    $sharedProcess.worker_process_id = 101; $sharedProcess.report = Copy-QsdkR10fL9JsonValue $active
    $sharedProcess.report.process_id = 101
    $mutationControls.shared_process_id_refused = Test-MutatedPopulationRefused @($baseEnvelope, $sharedProcess)
    $overlap = Copy-QsdkR10fL9JsonValue $activeEnvelope
    $overlap.started_utc = "2026-09-05T00:00:00.5000000Z"
    $mutationControls.overlapping_process_lifetime_refused = Test-MutatedPopulationRefused @($baseEnvelope, $overlap)
    $duplicateChild = Copy-QsdkR10fL9JsonValue $activeEnvelope
    $duplicateChild.child_attempt_id = $baselineId
    $mutationControls.duplicate_child_attempt_id_refused = Test-MutatedPopulationRefused @($baseEnvelope, $duplicateChild)
    $duplicatePath = Copy-QsdkR10fL9JsonValue $activeEnvelope
    $duplicatePath.evidence_path = $baseEnvelope.evidence_path
    $mutationControls.duplicate_evidence_path_refused = Test-MutatedPopulationRefused @($baseEnvelope, $duplicatePath)
    $sourceMismatch = Copy-QsdkR10fL9JsonValue $activeEnvelope
    $sourceMismatch.report.source_commit = "f" * 40
    $mutationControls.source_mismatch_refused = Test-MutatedPopulationRefused @($baseEnvelope, $sourceMismatch)
    $authorityMismatch = Copy-QsdkR10fL9JsonValue $activeEnvelope
    $authorityMismatch.report.authorization_sha256 = "sha256:" + ("f" * 64)
    $mutationControls.authority_mismatch_refused = Test-MutatedPopulationRefused @($baseEnvelope, $authorityMismatch)
    $seedMismatch = Copy-QsdkR10fL9JsonValue $activeEnvelope
    $seedMismatch.report.seed = 40201
    $mutationControls.seed_mismatch_refused = Test-MutatedPopulationRefused @($baseEnvelope, $seedMismatch)
    $configurationMismatch = Copy-QsdkR10fL9JsonValue $activeEnvelope
    $configurationMismatch.report.configuration_sha256 = "sha256:" + ("e" * 64)
    $mutationControls.configuration_mismatch_refused = Test-MutatedPopulationRefused @($baseEnvelope, $configurationMismatch)
    $mutationControls.missing_child_refused = Test-MutatedPopulationRefused @($baseEnvelope)
    $mutationControls.extra_child_refused = Test-MutatedPopulationRefused @($baseEnvelope, $activeEnvelope, $activeEnvelope)
    $missingOutput = Copy-QsdkR10fL9JsonValue $activeEnvelope; $missingOutput.report = $null
    $mutationControls.missing_child_output_refused = Test-MutatedPopulationRefused @($baseEnvelope, $missingOutput)
    $truncated = Copy-QsdkR10fL9JsonValue $activeEnvelope
    $truncated.report.arm_result.trace.rows = @($active.arm_result.trace.rows | Select-Object -First 3)
    $mutationControls.truncated_trace_refused = Test-MutatedPopulationRefused @($baseEnvelope, $truncated)
    $counterMismatch = Copy-QsdkR10fL9JsonValue $activeEnvelope
    $counterMismatch.report.solver_step_count = 5
    $mutationControls.counter_aggregation_source_mismatch_refused = Test-MutatedPopulationRefused @($baseEnvelope, $counterMismatch)
    $stepRewrite = Copy-QsdkR10fL9JsonValue $activeEnvelope
    $stepRewrite.report.arm_result.trace.rows = @($active.arm_result.trace.rows)
    $stepRewrite.report.arm_result.trace.rows[0].global_semantic_step = 1.0
    $mutationControls.native_step_number_kind_rewrite_refused = Test-MutatedPopulationRefused @($baseEnvelope, $stepRewrite)
    $secondKick = Copy-QsdkR10fL9JsonValue $activeEnvelope
    $secondKick.report.interaction_source.application_count = 2
    $secondKick.report.external_kick_application_count = 2
    $mutationControls.second_active_kick_refused = Test-MutatedPopulationRefused @($baseEnvelope, $secondKick)
    $baselineKick = Copy-QsdkR10fL9JsonValue $baseEnvelope
    $baselineKick.report.interaction_source.application_count = 1
    $baselineKick.report.interaction_source.scheduled_impulse_world_n_s = @(0.0, 0.0, 0.25)
    $baselineKick.report.external_kick_application_count = 1
    $mutationControls.baseline_kick_refused = Test-MutatedPopulationRefused @($baselineKick, $activeEnvelope)
    $bodyWrite = Copy-QsdkR10fL9JsonValue $activeEnvelope
    $bodyWrite.report.arm_result.body_transform_write_count = 1
    $mutationControls.post_construction_body_write_refused = Test-MutatedPopulationRefused @($baseEnvelope, $bodyWrite)
    $retry = Copy-QsdkR10fL9JsonValue $activeEnvelope; $retry.child_retry_count = 1
    $mutationControls.child_retry_refused = Test-MutatedPopulationRefused @($baseEnvelope, $retry)
    $replacement = Copy-QsdkR10fL9JsonValue $activeEnvelope
    $replacement.child_replacement_count = 1
    $mutationControls.child_replacement_refused = Test-MutatedPopulationRefused @($baseEnvelope, $replacement)
    $roleSwap = Copy-QsdkR10fL9JsonValue $activeEnvelope
    $roleSwap.role = $script:QsdkR10fL9BaselineRole
    $mutationControls.role_swap_refused = Test-MutatedPopulationRefused @($baseEnvelope, $roleSwap)
    $duplicateRole = Copy-QsdkR10fL9JsonValue $activeEnvelope
    $duplicateRole.role = $script:QsdkR10fL9BaselineRole
    $mutationControls.duplicate_role_refused = Test-MutatedPopulationRefused @($baseEnvelope, $duplicateRole)
    $mutationControls.early_evaluator_invocation_refused = Test-MutatedPopulationRefused `
        @($baseEnvelope, $activeEnvelope) -PriorInvocation 1
	$completeEmptySource = Copy-QsdkR10fL9JsonValue $activeEnvelope
	$completeEmptySource.report.precondition_terminal_receipt.recovery_memory.terminal_failure_code = ""
	$mutationControls.complete_empty_failure_source_refused = Test-MutatedPopulationRefused `
		@($baseEnvelope, $completeEmptySource)
	$completeNonemptySource = Copy-QsdkR10fL9JsonValue $activeEnvelope
	$completeNonemptySource.report.precondition_terminal_receipt.recovery_memory.terminal_failure_code = (
		"invented_failure"
	)
	$mutationControls.complete_nonempty_failure_source_refused = Test-MutatedPopulationRefused `
		@($baseEnvelope, $completeNonemptySource)
	$missingFailureSource = Copy-QsdkR10fL9JsonValue $activeEnvelope
	$missingFailureSource.report.precondition_terminal_receipt.recovery_memory.Remove(
		"terminal_failure_code"
	)
	$mutationControls.missing_failure_source_refused = Test-MutatedPopulationRefused `
		@($baseEnvelope, $missingFailureSource)
	$failedNullSource = Copy-QsdkR10fL9JsonValue $preconditionEnvelope
	$failedNullSource.report.precondition_terminal_receipt.recovery_memory.terminal_failure_code = $null
	$mutationControls.failed_null_source_refused = Test-MutatedPopulationRefused `
		@($failedNullSource, $activeEnvelope)
	$projectionMismatch = Copy-QsdkR10fL9JsonValue $activeEnvelope
	$projectionMismatch.report.precondition_terminal_receipt.recovery_terminal_failure_code = (
		"invented_failure"
	)
	$mutationControls.failure_projection_mismatch_refused = Test-MutatedPopulationRefused `
		@($baseEnvelope, $projectionMismatch)
	$foreignReleaseOwner = Copy-QsdkR10fL9JsonValue $activeEnvelope
	$foreignReleaseOwner.report.precondition_release_receipt.ledger_application_intent.
		owner_source_receipt.child_attempt_id = "eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee"
	$mutationControls.foreign_release_owner_source_refused = Test-MutatedPopulationRefused `
		@($baseEnvelope, $foreignReleaseOwner)
	$releaseOwnerDigestMismatch = Copy-QsdkR10fL9JsonValue $activeEnvelope
	$releaseOwnerDigestMismatch.report.precondition_release_receipt.ledger_application_intent.
		owner_source_receipt_sha256 = "sha256:" + ("9" * 64)
	$mutationControls.release_owner_digest_mismatch_refused = Test-MutatedPopulationRefused `
		@($baseEnvelope, $releaseOwnerDigestMismatch)
	$releaseOwnerOutcome = Copy-QsdkR10fL9JsonValue $activeEnvelope
	$releaseOwnerOutcome.report.precondition_release_receipt.ledger_application_intent.
		owner_source_receipt.physical_result = $true
	$mutationControls.release_owner_outcome_field_refused = Test-MutatedPopulationRefused `
		@($baseEnvelope, $releaseOwnerOutcome)
	$releaseOwnerStepDigest = Copy-QsdkR10fL9JsonValue $activeEnvelope
	$releaseOwnerStepDigest.report.precondition_release_receipt.ledger_application_intent.
		owner_source_receipt.recovery_step_receipt_sha256 = "sha256:" + ("9" * 64)
	$mutationControls.release_owner_step_digest_mismatch_refused = Test-MutatedPopulationRefused `
		@($baseEnvelope, $releaseOwnerStepDigest)

    $missingHandoff = Copy-QsdkR10fL9JsonValue $activeEnvelope
    $missingHandoff.report.arm_result.walking_actuation_handoff_receipts = @(
        $active.arm_result.walking_actuation_handoff_receipts | Select-Object -First 1
    )
    $mutationControls.missing_walking_actuation_handoff_refused = Test-MutatedPopulationRefused `
        @($baseEnvelope, $missingHandoff)
    $disabledHandoffReadback = Copy-QsdkR10fL9JsonValue $activeEnvelope
    $disabledHandoffReadback.report.arm_result.walking_actuation_handoff_receipts[0].
        precommand_motor_population_readback.ordered_joint_readbacks[0].motor_enabled = $false
    $mutationControls.disabled_precommand_motor_readback_refused = Test-MutatedPopulationRefused `
        @($baseEnvelope, $disabledHandoffReadback)
    $wrongSelectedHostCap = Copy-QsdkR10fL9JsonValue $activeEnvelope
    $wrongSelectedHostCap.report.arm_result.walking_actuation_handoff_receipts[0].
        host_cap_projection_binding.selected_host_cap_by_actuator_id["front_left_hip_motor"] = (
            [double]$script:QsdkR10fL12HostCaps[1]
        )
    $mutationControls.wrong_selected_host_cap_refused = Test-MutatedPopulationRefused `
        @($baseEnvelope, $wrongSelectedHostCap)
    $duplicateHandoffSession = Copy-QsdkR10fL9JsonValue $activeEnvelope
    $duplicateHandoffSession.report.arm_result.walking_actuation_handoff_receipts[1].
        walking_session_id = [string]$duplicateHandoffSession.report.arm_result.
            walking_actuation_handoff_receipts[0].walking_session_id
    $mutationControls.duplicate_walking_handoff_session_refused = Test-MutatedPopulationRefused `
        @($baseEnvelope, $duplicateHandoffSession)

    $positiveCount = @($positiveControls.Values | Where-Object { [bool]$_ }).Count
    $mutationCount = @($mutationControls.Values | Where-Object { [bool]$_ }).Count
    return [ordered]@{
        schema_version = "sporespore_qsdk_r10f_l9_pair_evaluator_zero_world_v1"
        gate_id = $script:QsdkR10fL9GateId
        repair_id = $script:QsdkR10fL9RepairId
        ok = (
            $positiveCount -eq $positiveControls.Count -and
            $mutationCount -eq $mutationControls.Count -and
			$positiveControls.Count -eq 3 -and $mutationControls.Count -eq 35
        )
        positive_control_count = $positiveCount
        mutation_rejection_count = $mutationCount
        positive_controls = $positiveControls
        mutation_controls = $mutationControls
        model_construction_count = 0
        world_attempt_count = 0
        world_build_count = 0
        scene_tree_insertion_count = 0
        native_readback_count = 0
        solver_step_count = 0
        physics_state_modified = $false
        physical_acceptance_authority = $false
        release_authority = $false
    }
}
