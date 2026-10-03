$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$testsRoot = [System.IO.Path]::GetFullPath($PSScriptRoot)
$repoRoot = [System.IO.Path]::GetFullPath((Split-Path -Parent $testsRoot))
$preregistrationPath = Join-Path (
    $repoRoot
) "sdk\rapier_c6_bw19v_early_horizon_mechanism_development_ed1_preregistration.json"
$c2ClosurePath = Join-Path (
    $repoRoot
) "sdk\rapier_c6_bw19v_selected_policy_commissioning_c2_closure.json"
$closurePath = Join-Path (
    $repoRoot
) "sdk\rapier_c6_bw19v_early_horizon_mechanism_development_ed1_closure.json"
$modulePath = Join-Path (
    $repoRoot
) "sdk\adapters\rapier\src\bw19v_early_horizon_development.rs"
$binaryPath = Join-Path (
    $repoRoot
) "sdk\adapters\rapier\src\bin\bw19v_early_horizon_development.rs"
$libraryPath = Join-Path $repoRoot "sdk\adapters\rapier\src\lib.rs"
$runnerPath = Join-Path (
    $repoRoot
) "sdk\run_rapier_c6_bw19v_early_horizon_mechanism_development_ed1.ps1"
$conformancePath = Join-Path $repoRoot "sdk\run_conformance.ps1"
$evidenceRoot = [System.IO.Path]::GetFullPath(
    (Join-Path (Split-Path -Parent $repoRoot) "SporeSpore_Evidence")
)
$expectedPreregistrationRawSha256 = (
    "sha256:" +
    "8c149f47a87bbd72402a7aa98fec1e75ff05abb36df2802f9b8a333f469b3197"
)
$expectedC2ClosureRawSha256 = (
    "sha256:" +
    "3047c2d9712a7d9b70c7423dab7df19bc8de96b1c39663b2bf0fb6e278fe5590"
)
$campaignId = "C6-RAPIER-BW19V-EARLY-HORIZON-MECHANISM-DEVELOPMENT-ED1"
$gateId = "C6-RAP-BW19V-ED1"

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

foreach ($path in @(
    $preregistrationPath,
    $c2ClosurePath,
    $modulePath,
    $binaryPath,
    $libraryPath,
    $runnerPath,
    $conformancePath
)) {
    Assert-Exact (
        Test-Path -LiteralPath $path -PathType Leaf
    ) "A required $gateId source is missing: $path"
}
Assert-Exact (
    (Get-RawSha256 $preregistrationPath) -ceq
        $expectedPreregistrationRawSha256
) "The ED1 preregistration is byte-changed"
Assert-Exact (
    (Get-RawSha256 $c2ClosurePath) -ceq $expectedC2ClosureRawSha256
) "The immutable C2 closure is byte-changed"
Assert-Exact (
    -not (Test-Path -LiteralPath $closurePath)
) "$gateId is already closed; the prospective freeze audit may not reopen it"

$preregistration = Get-Content -Raw -LiteralPath $preregistrationPath |
    ConvertFrom-Json
Assert-Exact (
    [string]$preregistration.schema_version -ceq
        "sporespore_rapier_c6_bw19v_early_horizon_mechanism_development_ed1_preregistration_v1" -and
    [string]$preregistration.campaign_id -ceq $campaignId -and
    [string]$preregistration.gate_id -ceq $gateId -and
    [string]$preregistration.status -ceq
        "frozen_before_first_c6_rap_bw19v_ed1_physics_world" -and
    [string]$preregistration.implementation_parent_commit -ceq
        "bda540b30617654ef3eeab56d404dd0fee0e13d7" -and
    [string]$preregistration.study_class.classification -ceq
        "outcome_exposed_paired_single_body_mechanism_development_screen" -and
    [int]$preregistration.study_class.world_count -eq 2 -and
    [int]$preregistration.study_class.arm_count -eq 2 -and
    [string]$preregistration.study_class.fixed_arm_order[0] -ceq "ED1-A" -and
    [string]$preregistration.study_class.fixed_arm_order[1] -ceq "ED1-B" -and
    [bool]$preregistration.study_class.development_screen -and
    -not [bool]$preregistration.study_class.finite_decision -and
    -not [bool]$preregistration.study_class.superiority_study -and
    -not [bool]$preregistration.study_class.noninferiority_or_equivalence_study -and
    -not [bool]$preregistration.study_class.population_inference -and
    -not [bool]$preregistration.study_class.walking_acceptance -and
    -not [bool]$preregistration.study_class.physical_acceptance_authority
) "$gateId study classification or authority changed"

Assert-Exact (
    [string]$preregistration.predecessor_interlocks.c2_closure_raw_sha256 -ceq
        $expectedC2ClosureRawSha256.Substring(7) -and
    [string]$preregistration.predecessor_interlocks.c2_status -ceq
        "closed_negative_corrected_composition_complete_physical_walking_gate_failed" -and
    -not [bool]$preregistration.predecessor_interlocks.c2_same_identity_rerun -and
    -not [bool]$preregistration.predecessor_interlocks.c2_result_reinterpreted_or_rethresholded -and
    [bool]$preregistration.predecessor_interlocks.c2_composition_integration_contract_passed -and
    -not [bool]$preregistration.predecessor_interlocks.c2_technical_commissioning_passed -and
    [int]$preregistration.predecessor_interlocks.c2_first_torso_ground_contact_semantic_step -eq 117 -and
    [int]$preregistration.predecessor_interlocks.c2_contact_gated_start_semantic_step -eq 472 -and
    -not [bool]$preregistration.predecessor_interlocks.c2_physical_failure_cause_identified
) "$gateId changed or overstated the C2 predecessor"

Assert-Exact (
    [bool]$preregistration.causal_intervention.single_changed_mechanism -and
    -not [bool]$preregistration.causal_intervention.controller_identity_changed -and
    -not [bool]$preregistration.causal_intervention.controller_memory_or_phase_logic_changed -and
    -not [bool]$preregistration.causal_intervention.stability_plan_or_residual_computation_changed -and
    -not [bool]$preregistration.causal_intervention.host_fixture_changed -and
    -not [bool]$preregistration.causal_intervention.host_solver_or_motor_changed -and
    -not [bool]$preregistration.causal_intervention.material_or_friction_changed -and
    -not [bool]$preregistration.causal_intervention.timestep_or_schedule_changed -and
    -not [bool]$preregistration.causal_intervention.morphology_changed -and
    -not [bool]$preregistration.causal_intervention.numeric_threshold_changed -and
    [string]$preregistration.causal_intervention.arm_a.arm_id -ceq "ED1-A" -and
    [bool]$preregistration.causal_intervention.arm_a.bw19v_plan_and_residual_computed_for_shadow_trace -and
    -not [bool]$preregistration.causal_intervention.arm_a.bw19v_stability_contribution_applied_to_host -and
    [bool]$preregistration.causal_intervention.arm_a.all_applied_residual_position_and_velocity_values_are_exact_zero -and
    [string]$preregistration.causal_intervention.arm_b.arm_id -ceq "ED1-B" -and
    [bool]$preregistration.causal_intervention.arm_b.bw19v_stability_contribution_applied_to_host -and
    [double]$preregistration.causal_intervention.arm_b.global_requested_correction_scale -eq 0.5
) "$gateId intervention no longer isolates residual application"

Assert-Exact (
    [int]$preregistration.physical_fixture.settle_steps_per_arm -eq 240 -and
    [int]$preregistration.physical_fixture.controller_semantic_steps_per_arm -eq 472 -and
    [int]$preregistration.physical_fixture.first_semantic_step_inclusive -eq 0 -and
    [int]$preregistration.physical_fixture.last_semantic_step_inclusive -eq 471 -and
    [int]$preregistration.physical_fixture.contact_gated_start_step_excluded -eq 472 -and
    [string]$preregistration.physical_fixture.phase_progression_mode -ceq "clocked" -and
    [bool]$preregistration.physical_fixture.early_stop_after_observed_failure_forbidden -and
    [bool]$preregistration.physical_fixture.both_arms_always_complete_declared_horizon -and
    [int]$preregistration.per_step_trace_contract.trace_step_count_per_arm -eq 472 -and
    [bool]$preregistration.per_step_trace_contract.command_provenance_before_application -and
    [bool]$preregistration.per_step_trace_contract.first_failure_event_recorded_or_explicitly_null -and
    [bool]$preregistration.preflight_contract.nested_state_schema_canary_fails
) "$gateId horizon or trace contract changed"

$integrity = $preregistration.diagnostic_integrity_gate
Assert-Exact (
    [bool]$integrity.report_ok_means_complete_diagnostic_not_physical_success -and
    [int]$integrity.world_attempt_count -eq 2 -and
    [int]$integrity.world_build_count -eq 2 -and
    [bool]$integrity.post_settle_initial_four_contact_stance_per_arm -and
    [int]$integrity.post_settle_declared_failure_event_count -eq 0 -and
    [int]$integrity.trace_step_count_total -eq 944 -and
    [int]$integrity.base_command_count_total -eq 7552 -and
    [int]$integrity.shadow_residual_command_count_total -eq 7552 -and
    [int]$integrity.final_host_command_count_total -eq 7552 -and
    [int]$integrity.post_step_host_observation_count_total -eq 7552 -and
    [int]$integrity.arm_a_applied_residual_nonzero_count -eq 0 -and
    [int]$integrity.arm_a_final_command_mismatch_from_base_count -eq 0 -and
    [bool]$integrity.arm_b_requires_at_least_one_nonzero_shadow_residual -and
    [bool]$integrity.arm_b_shadow_and_applied_residual_match -and
    [bool]$integrity.physical_failure_event_may_be_present_or_absent_in_either_arm -and
    [bool]$integrity.relative_outcome_does_not_change_integrity_acceptance
) "$gateId diagnostic integrity gate changed"

$claims = $preregistration.claim_boundary
Assert-Exact (
    [bool]$claims.complete_mechanism_development_trace_only -and
    -not [bool]$claims.technical_commissioning -and
    -not [bool]$claims.walking_acceptance -and
    -not [bool]$claims.policy_superiority -and
    -not [bool]$claims.independent_validation -and
    -not [bool]$claims.population_inference -and
    -not [bool]$claims.arbitrary_quadruped_coverage -and
    -not [bool]$claims.continuous_full_volume_coverage -and
    -not [bool]$claims.material_robustness -and
    -not [bool]$claims.rapier_selected_policy_physical_c6 -and
    -not [bool]$claims.cross_engine_c6 -and
    -not [bool]$claims.release_authorized -and
    -not [bool]$claims.physical_acceptance_authority -and
    -not [bool]$claims.completed_engine_neutral_sdk
) "$gateId claim boundary inflated"

foreach ($declaration in @(
    @{
        path = [string]$preregistration.predecessor_interlocks.c2_closure_path
        sha256 = $expectedC2ClosureRawSha256
    },
    @{
        path = [string]$preregistration.host_contract.active_configuration_path
        sha256 = "sha256:" + [string]$preregistration.host_contract.active_configuration_raw_sha256
    },
    @{
        path = [string]$preregistration.portable_policy_identity.bw19v_closure_path
        sha256 = "sha256:" + [string]$preregistration.portable_policy_identity.bw19v_closure_raw_sha256
    },
    @{
        path = [string]$preregistration.portable_policy_identity.bw19v_candidate_declaration_path
        sha256 = "sha256:" + [string]$preregistration.portable_policy_identity.bw19v_candidate_declaration_raw_sha256
    },
    @{
        path = [string]$preregistration.portable_policy_identity.bw15f_selected_policy_path
        sha256 = "sha256:" + [string]$preregistration.portable_policy_identity.bw15f_selected_policy_raw_sha256
    },
    @{
        path = [string]$preregistration.host_source_semantics.cargo_lock_path
        sha256 = "sha256:" + [string]$preregistration.host_source_semantics.cargo_lock_raw_sha256
    }
)) {
    $path = [System.IO.Path]::GetFullPath(
        (Join-Path $repoRoot ([string]$declaration.path))
    )
    Assert-Exact (
        (Test-Path -LiteralPath $path -PathType Leaf) -and
        (Get-RawSha256 $path) -ceq [string]$declaration.sha256
    ) "A $gateId pinned input changed: $path"
}
foreach ($source in @(
    $preregistration.method_sources.repository_contracts
) + @($preregistration.method_sources.local_research_inputs)) {
    $path = [System.IO.Path]::GetFullPath(
        (Join-Path $repoRoot ([string]$source.path))
    )
    Assert-Exact (
        (Test-Path -LiteralPath $path -PathType Leaf) -and
        (Get-RawSha256 $path) -ceq [string]$source.sha256
    ) "A $gateId method source changed: $path"
}

$parentCommit = [string]$preregistration.implementation_parent_commit
& git -C $repoRoot merge-base --is-ancestor $parentCommit HEAD
Assert-Exact (
    $LASTEXITCODE -eq 0
) "$gateId implementation parent is not an ancestor of HEAD"

$moduleSource = Get-Content -Raw -LiteralPath $modulePath
$binarySource = Get-Content -Raw -LiteralPath $binaryPath
$librarySource = Get-Content -Raw -LiteralPath $libraryPath
$runnerSource = Get-Content -Raw -LiteralPath $runnerPath
$conformanceSource = Get-Content -Raw -LiteralPath $conformancePath
foreach ($required in @(
    "const HORIZON_STEPS: u64 = 472;",
    "const SETTLE_STEPS: u64 = 240;",
    'const ARM_A: &str = "ED1-A";',
    'const ARM_B: &str = "ED1-B";',
    "[(ARM_A, false), (ARM_B, true)]",
    "run_bw19v_early_horizon_development_preflight",
    "perfect_synthetic_two_arm_report_passed_complete_integrity_gate",
    "synthetic_outcome_variants_all_integrity_valid",
    "missing_trace_step_canary_rejected",
    "reordered_semantic_step_canary_rejected",
    "arm_a_nonzero_applied_residual_canary_rejected",
    "arm_b_missing_nonzero_shadow_residual_canary_rejected",
    "nested_state_schema_canary_rejected",
    "claim_inflation_canary_rejected",
    "command_provenance_recorded_before_application",
    "physical_failure_events_are_not_diagnostic_gate_failures"
)) {
    Assert-Exact (
        $moduleSource.Contains($required)
    ) "$gateId implementation lost required source text: $required"
}
foreach ($forbidden in @(
    ".set_translation(",
    ".set_position(",
    ".set_linvel(",
    ".set_angvel(",
    ".apply_impulse(",
    ".add_force("
)) {
    Assert-Exact (
        -not $moduleSource.Contains($forbidden)
    ) "$gateId implementation gained a direct body mutation: $forbidden"
}
Assert-Exact (
    $binarySource.Contains("--preflight-only") -and
    $binarySource.Contains("--source-commit") -and
    $binarySource.Contains("refusing to overwrite ED1 report") -and
    $librarySource.Contains("mod bw19v_early_horizon_development;") -and
    $librarySource.Contains("run_bw19v_early_horizon_development_preflight") -and
    $runnerSource.Contains($expectedPreregistrationRawSha256.Substring(7)) -and
    $runnerSource.Contains("fixed_arm_order = @(`"ED1-A`", `"ED1-B`")") -and
    $runnerSource.Contains("process_launch_consumes_identity = `$true") -and
    $runnerSource.Contains("requires clean source with HEAD == origin/main == GitHub") -and
    $conformanceSource.Contains(
        "run_rapier_c6_bw19v_early_horizon_mechanism_development_ed1.ps1"
    ) -and
    $conformanceSource.Contains(
        "test_rapier_c6_bw19v_early_horizon_mechanism_development_ed1_freeze.ps1"
    )
) "$gateId binary, export, runner, or conformance wiring changed"

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
                [string]$receipt.campaign_id -cne $campaignId
            ) "$gateId already has a retained physical attempt"
        } catch {
            if ($_.Exception.Message -like "$gateId already has*") {
                throw
            }
        }
    }
}

$preflightOutput = (& pwsh -NoProfile `
    -File $runnerPath `
    -PreflightOnly 2>&1) | Out-String
Assert-Exact (
    $LASTEXITCODE -eq 0 -and
    $preflightOutput.Contains(
        "C6-RAP-BW19V-ED1 zero-world preflight passed"
    ) -and
    $preflightOutput.Contains("944 trace steps") -and
    $preflightOutput.Contains("7552 commands per layer") -and
    $preflightOutput.Contains("four outcome patterns") -and
    $preflightOutput.Contains("worlds=0")
) "$gateId executable zero-world supervisor preflight failed"
$global:LASTEXITCODE = 0

Write-Output (
    "C6_RAP_BW19V_ED1_FREEZE_PASS arms=2 trace_steps=944 " +
    "commands_per_layer=7552 outcome_patterns=4 worlds=0 " +
    "walking_authority=false physical_authority=false"
)
