$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = [System.IO.Path]::GetFullPath(
    (Join-Path $PSScriptRoot "..")
)
$sdkRoot = Join-Path $repoRoot "sdk"
$evidenceRoot = [System.IO.Path]::GetFullPath(
    (Join-Path (Split-Path -Parent $repoRoot) "SporeSpore_Evidence")
)
$preregistrationPath = Join-Path (
    $sdkRoot
) "rapier_c6_bw19v_selected_policy_commissioning_c2_preregistration.json"
$c1PreregistrationPath = Join-Path (
    $sdkRoot
) "rapier_c6_bw19v_selected_policy_commissioning_c1_preregistration.json"
$c1ClosurePath = Join-Path (
    $sdkRoot
) "rapier_c6_bw19v_selected_policy_commissioning_c1_closure.json"
$c2ClosurePath = Join-Path (
    $sdkRoot
) "rapier_c6_bw19v_selected_policy_commissioning_c2_closure.json"
$compositionPath = Join-Path (
    $sdkRoot
) "adapters\rapier\src\bw19v_composition.rs"
$commissioningPath = Join-Path (
    $sdkRoot
) "adapters\rapier\src\bw19v_commissioning.rs"
$binaryPath = Join-Path (
    $sdkRoot
) "adapters\rapier\src\bin\bw19v_commissioning_c2.rs"
$runnerPath = Join-Path (
    $sdkRoot
) "run_rapier_c6_bw19v_selected_policy_commissioning_c2.ps1"
$expectedPreregistrationRawSha256 = (
    "sha256:" +
    "c2f4c071c7b55e20dd77f32b72370f6891c3b1b2426baa2fca2ac0e23730da27"
)
$expectedC1ClosureRawSha256 = (
    "sha256:" +
    "e2919cc899df78aebe5d2486bb7250a1388044f2f040f53f23f581d113aa8fae"
)

function Assert-Exact {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) {
        throw $Message
    }
}

function Get-RawSha256 {
    param([Parameter(Mandatory)][string]$Path)
    return "sha256:" + (
        Get-FileHash -Algorithm SHA256 -LiteralPath $Path
    ).Hash.ToLowerInvariant()
}

function Get-CompactJson {
    param([Parameter(Mandatory)][object]$Value)
    return $Value | ConvertTo-Json -Depth 50 -Compress
}

function Assert-TextContains {
    param(
        [Parameter(Mandatory)][string]$Text,
        [Parameter(Mandatory)][string]$Needle,
        [Parameter(Mandatory)][string]$Message
    )
    Assert-Exact ($Text.Contains($Needle)) $Message
}

Assert-Exact (
    (Test-Path -LiteralPath $preregistrationPath -PathType Leaf) -and
    (Get-RawSha256 $preregistrationPath) -ceq
        $expectedPreregistrationRawSha256
) "The C2 preregistration is missing or byte-changed"
Assert-Exact (
    (Test-Path -LiteralPath $c1ClosurePath -PathType Leaf) -and
    (Get-RawSha256 $c1ClosurePath) -ceq $expectedC1ClosureRawSha256
) "The immutable C1 predecessor closure changed"
Assert-Exact (
    -not (Test-Path -LiteralPath $c2ClosurePath)
) "C2 already has a closure; its prospective freeze audit is no longer authoritative"

$preregistration = Get-Content -Raw -LiteralPath $preregistrationPath |
    ConvertFrom-Json
$c1Preregistration = Get-Content -Raw -LiteralPath $c1PreregistrationPath |
    ConvertFrom-Json
$c1Closure = Get-Content -Raw -LiteralPath $c1ClosurePath |
    ConvertFrom-Json
Assert-Exact (
    [string]$preregistration.schema_version -ceq
        "sporespore_rapier_c6_bw19v_selected_policy_commissioning_c2_preregistration_v1" -and
    [string]$preregistration.campaign_id -ceq
        "C6-RAPIER-BW19V-SELECTED-POLICY-COMMISSIONING-C2" -and
    [string]$preregistration.gate_id -ceq "C6-RAP-BW19V-C2" -and
    [string]$preregistration.status -ceq
        "frozen_before_first_c6_rap_bw19v_c2_physics_world" -and
    [string]$preregistration.implementation_parent_commit -ceq
        "800a495f5347573f64ee7030293799b5b7a7455c" -and
    [string]$preregistration.study_class.classification -ceq
        "outcome_exposed_single_body_technical_commissioning" -and
    [int]$preregistration.study_class.world_count -eq 1 -and
    [int]$preregistration.study_class.morphology_count -eq 1 -and
    -not [bool]$preregistration.study_class.independent_validation -and
    -not [bool]$preregistration.study_class.population_inference -and
    [bool]$preregistration.study_class.technical_commissioning_authority_if_passed
) "C2 identity or study class changed"
Assert-Exact (
    [string]$c1Closure.status -ceq
        "closed_negative_portable_observation_availability_routing_failure" -and
    -not [bool]$c1Closure.disposition.same_identity_rerun_allowed -and
    [string]$preregistration.predecessor_interlocks.c1_closure_raw_sha256 -ceq
        $expectedC1ClosureRawSha256.Substring(7) -and
    [string]$preregistration.predecessor_interlocks.c1_closure_status -ceq
        [string]$c1Closure.status -and
    -not [bool]$preregistration.predecessor_interlocks.c1_same_identity_rerun -and
    -not [bool]$preregistration.predecessor_interlocks.c1_result_reinterpreted_or_rethresholded -and
    -not [bool]$preregistration.predecessor_interlocks.c1_physical_result_is_policy_performance_authority
) "C2 no longer preserves the C1 negative boundary"

Assert-Exact (
    [int]$preregistration.prospective_change_under_test.changed_surface_count -eq 3 -and
    @($preregistration.prospective_change_under_test.changed_surfaces).Count -eq 3 -and
    -not [bool]$preregistration.prospective_change_under_test.controller_or_policy_parameter_changed -and
    -not [bool]$preregistration.prospective_change_under_test.physical_fixture_changed -and
    -not [bool]$preregistration.prospective_change_under_test.host_solver_or_motor_changed -and
    -not [bool]$preregistration.prospective_change_under_test.walking_threshold_changed -and
    -not [bool]$preregistration.prospective_change_under_test.material_or_friction_changed -and
    -not [bool]$preregistration.prospective_change_under_test.clock_or_schedule_changed -and
    -not [bool]$preregistration.prospective_change_under_test.morphology_changed -and
    [int]$preregistration.prospective_change_under_test.outcome_conditioned_choice_count -eq 0
) "C2 expanded beyond the declared host-integration correction"
Assert-Exact (
    [string]$preregistration.portable_observation_availability_contract.observation_unavailable_reason -ceq
        "NO_QUALIFIED_SUPPORT_CONTACT" -and
    -not [bool]$preregistration.portable_observation_availability_contract.observation_available -and
    [bool]$preregistration.portable_observation_availability_contract.emitted_stability_state_retained_for_audit -and
    [string]$preregistration.portable_observation_availability_contract.portable_planning_availability -ceq
        "observation_unavailable" -and
    [string]$preregistration.portable_observation_availability_contract.portable_planning_outcome_code -ceq
        "OBSERVATION_UNAVAILABLE:NO_QUALIFIED_SUPPORT_CONTACT" -and
    [bool]$preregistration.portable_observation_availability_contract.portable_fail_zero_required -and
    [bool]$preregistration.portable_observation_availability_contract.ordered_stability_contributions_are_exact_zero -and
    [bool]$preregistration.portable_observation_availability_contract.final_position_targets_equal_portable_base_targets -and
    [bool]$preregistration.portable_observation_availability_contract.final_velocity_targets_equal_portable_base_targets -and
    [bool]$preregistration.portable_observation_availability_contract.all_eight_final_application_receipts_retained
) "C2 portable observation-unavailable contract changed"

Assert-Exact (
    (Get-CompactJson $preregistration.portable_policy_identity) -ceq
        (Get-CompactJson $c1Preregistration.portable_policy_identity) -and
    (Get-CompactJson $preregistration.host_contract) -ceq
        (Get-CompactJson $c1Preregistration.host_contract) -and
    (Get-CompactJson $preregistration.source_derived_response_contract) -ceq
        (Get-CompactJson $c1Preregistration.source_derived_response_contract) -and
    (Get-CompactJson $preregistration.host_source_semantics) -ceq
        (Get-CompactJson $c1Preregistration.host_source_semantics) -and
    (Get-CompactJson $preregistration.physical_fixture.descriptor) -ceq
        (Get-CompactJson $c1Preregistration.physical_fixture.descriptor)
) "A C1 policy, host, source-response, source, or morphology identity changed in C2"
foreach ($field in @(
    "compiled_s169_runtime_profile_sha256",
    "runtime_profile_hash_differs_from_reference_because_torso_length_scale_is_descriptor_dependent",
    "settle_steps",
    "contact_gated_start_step",
    "evidence_gait_steps_per_limb",
    "maximum_evidence_extension_steps",
    "cooldown_steps",
    "terminal_settle_steps",
    "maximum_controller_semantic_steps",
    "desired_forward_velocity_m_s"
)) {
    Assert-Exact (
        (Get-CompactJson $preregistration.physical_fixture.$field) -ceq
            (Get-CompactJson $c1Preregistration.physical_fixture.$field)
    ) "C2 changed the C1 physical fixture field: $field"
}
foreach ($property in $c1Preregistration.walking_and_integrity_gate.PSObject.Properties) {
    if ($property.Name -eq "threshold_provenance") {
        continue
    }
    Assert-Exact (
        (Get-CompactJson $preregistration.walking_and_integrity_gate.($property.Name)) -ceq
            (Get-CompactJson $property.Value)
    ) "C2 changed the C1 physical gate field: $($property.Name)"
}

Assert-Exact (
    [int]$preregistration.preflight_contract.sustained_zero_qualified_support_segment_start_step_inclusive -eq 1440 -and
    [int]$preregistration.preflight_contract.sustained_zero_qualified_support_segment_end_step_exclusive -eq 1800 -and
    [int]$preregistration.preflight_contract.sustained_zero_qualified_support_segment_steps -eq 360 -and
    [int]$preregistration.preflight_contract.explicit_host_observation_unavailable_receipt_count -eq 360 -and
    [int]$preregistration.preflight_contract.expected_available_plan_count -eq 1920 -and
    [int]$preregistration.preflight_contract.expected_observation_unavailable_plan_count -eq 1312 -and
    [int]$preregistration.preflight_contract.expected_observed_planning_unavailable_plan_count -eq 952 -and
    [int]$preregistration.preflight_contract.expected_upstream_infeasible_plan_count -eq 0 -and
    [int]$preregistration.preflight_contract.expected_fail_zero_receipt_count -eq 1312 -and
    [int]$preregistration.preflight_contract.expected_partial_support_mapping_count -eq 960 -and
    [int]$preregistration.preflight_contract.explicit_host_observation_unavailable_final_base_application_count -eq 2880 -and
    [int]$preregistration.preflight_contract.explicit_host_observation_unavailable_exact_zero_stability_output_count -eq 2880 -and
    [bool]$preregistration.preflight_contract.ordinary_support_receipt_required_before_zero_segment -and
    [bool]$preregistration.preflight_contract.ordinary_support_receipt_required_after_zero_segment -and
    [int]$preregistration.preflight_contract.preflight_world_build_count -eq 0 -and
    [int]$preregistration.preflight_contract.preflight_scene_insertion_count -eq 0 -and
    [int]$preregistration.preflight_contract.preflight_physics_state_mutation_count -eq 0
) "C2 complete zero-world preflight contract changed"
Assert-Exact (
    [int]$preregistration.composition_integrity_gate.composition_error_count -eq 0 -and
    $null -eq $preregistration.composition_integrity_gate.first_composition_error_semantic_step -and
    $null -eq $preregistration.composition_integrity_gate.first_composition_error_code -and
    [int]$preregistration.composition_integrity_gate.observation_unavailable_reason_mismatch_count -eq 0 -and
    [int]$preregistration.composition_integrity_gate.observation_unavailable_base_command_mismatch_count -eq 0 -and
    [int]$preregistration.composition_integrity_gate.observation_unavailable_stability_zero_mismatch_count -eq 0 -and
    [bool]$preregistration.composition_integrity_gate.all_eight_final_motor_writes_once_per_controller_step
) "C2 composition accounting or causal observability gate changed"
Assert-Exact (
    [bool]$preregistration.claim_boundary.technical_commissioning_only -and
    -not [bool]$preregistration.claim_boundary.independent_validation -and
    -not [bool]$preregistration.claim_boundary.arbitrary_quadruped_coverage -and
    -not [bool]$preregistration.claim_boundary.continuous_full_volume_coverage -and
    -not [bool]$preregistration.claim_boundary.material_robustness -and
    -not [bool]$preregistration.claim_boundary.cross_engine_c6 -and
    -not [bool]$preregistration.claim_boundary.locomotion_acceptance -and
    -not [bool]$preregistration.claim_boundary.release_authorized -and
    -not [bool]$preregistration.claim_boundary.physical_acceptance_authority -and
    -not [bool]$preregistration.claim_boundary.completed_engine_neutral_sdk
) "C2 claim boundary inflated"

$compositionSource = Get-Content -Raw -LiteralPath $compositionPath
foreach ($binding in @(
    'BW19V_NO_QUALIFIED_SUPPORT_CONTACT_REASON',
    'any(|contact| contact.bears_support == Some(true))',
    'let observation_available = bw19v_observation_available(&stability_state);',
    'observation_unavailable_reason',
    'Some(stability_state)'
)) {
    Assert-TextContains `
        -Text $compositionSource `
        -Needle $binding `
        -Message "The C2 availability route lost source binding: $binding"
}
$commissioningSource = Get-Content -Raw -LiteralPath $commissioningPath
foreach ($binding in @(
    'C2_ZERO_SUPPORT_START_STEP: u64 = 1440',
    'C2_ZERO_SUPPORT_END_STEP_EXCLUSIVE: u64 = 1800',
    'explicit_host_observation_unavailable_count',
    'first_composition_error_semantic_step',
    'first_composition_error_code',
    'observation_unavailable_base_command_mismatch_count',
    'observation_unavailable_stability_zero_mismatch_count',
    'available_after_zero_segment',
    'world_build_count": 0'
)) {
    Assert-TextContains `
        -Text $commissioningSource `
        -Needle $binding `
        -Message "The C2 preflight or receipt source lost binding: $binding"
}
$binarySource = Get-Content -Raw -LiteralPath $binaryPath
foreach ($binding in @(
    'run_bw19v_selected_policy_commissioning_c2_preflight',
    'run_bw19v_selected_policy_commissioning_c2',
    'refusing to overwrite report',
    'retained a complete negative report'
)) {
    Assert-TextContains `
        -Text $binarySource `
        -Needle $binding `
        -Message "The C2 binary lost fail-closed binding: $binding"
}
$runnerSource = Get-Content -Raw -LiteralPath $runnerPath
foreach ($binding in @(
    'attempt.json',
    'completion.json',
    'process_launch_consumes_identity = $true',
    'HEAD == origin/main == GitHub',
    'Start-Process',
    '--preflight-only',
    'is already closed and may not open another world'
)) {
    Assert-TextContains `
        -Text $runnerSource `
        -Needle $binding `
        -Message "The C2 supervisor lost one-shot binding: $binding"
}

$parentIsAncestor = (& git -C $repoRoot merge-base --is-ancestor `
    800a495f5347573f64ee7030293799b5b7a7455c HEAD)
Assert-Exact (
    $LASTEXITCODE -eq 0
) "Current C2 source is not descended from the pushed C1 closure boundary"
$diffCheck = @(& git -C $repoRoot diff --check 2>&1)
Assert-Exact (
    $LASTEXITCODE -eq 0
) "C2 prospective source has whitespace errors: $($diffCheck -join ' | ')"

if (Test-Path -LiteralPath $evidenceRoot -PathType Container) {
    foreach ($candidate in @(
        Get-ChildItem `
            -LiteralPath $evidenceRoot `
            -Recurse `
            -File `
            -Filter "attempt.json" `
            -ErrorAction Stop
    )) {
        try {
            $receipt = Get-Content -Raw -LiteralPath $candidate.FullName |
                ConvertFrom-Json
            Assert-Exact (
                [string]$receipt.campaign_id -cne
                    "C6-RAPIER-BW19V-SELECTED-POLICY-COMMISSIONING-C2"
            ) "C2 already has a retained attempt and is not prospective"
        } catch {
            if ($_.Exception.Message -eq
                "C2 already has a retained attempt and is not prospective") {
                throw
            }
        }
    }
}

$preflightOutput = (& pwsh `
    -NoLogo `
    -NoProfile `
    -File $runnerPath `
    -PreflightOnly 2>&1) | Out-String
Assert-Exact (
    $LASTEXITCODE -eq 0 -and
    $preflightOutput.Contains(
        "C6-RAP-BW19V-C2 zero-world preflight passed"
    ) -and
    $preflightOutput.Contains("explicit_host_unavailable=360") -and
    $preflightOutput.Contains("observed_planning_unavailable=952") -and
    $preflightOutput.Contains("final_outputs=25856") -and
    $preflightOutput.Contains("worlds=0")
) "The executable C2 zero-world supervisor preflight failed"
$global:LASTEXITCODE = 0

Write-Output (
    "C6_RAP_BW19V_C2_FREEZE_PASS " +
    "steps=3232 available=1920 explicit_host_unavailable=360 " +
    "observed_planning_unavailable=952 partial_support=960 " +
    "final_outputs=25856 worlds=0 physical_authority=false"
)
