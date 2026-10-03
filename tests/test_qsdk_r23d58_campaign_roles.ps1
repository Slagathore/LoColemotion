#requires -Version 7.0

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateSet("worker", "evaluator", "supervisor")]
    [string]$Role,
    [string]$Python = "python",
    [string]$Godot = (
        "C:\Users\Cole\CodeStuff\Misc\Godot\" +
        "Godot_v4.7-stable_mono_win64_console.exe"
    )
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$sdkRoot = Join-Path $repoRoot "sdk"
$turningRoot = Join-Path $sdkRoot "turning"
$pythonModuleRoot = Join-Path $sdkRoot "python"
$godotAdapterDebug = Join-Path $sdkRoot "target\debug\sporespore_godot_adapter.dll"
$worker = "res://tests/test_sdk_qsdk_r23d58_godot_jolt_physical_worker.gd"
$originGate = "res://tests/test_sdk_qsdk_r23d53_task_frame_origin_policy.gd"
$observationGate = "res://tests/test_sdk_godot_actuator_phase_observation.gd"
$capRuntimeGate = (
    "res://tests/test_sdk_qsdk_r23d55_godot_live_fixture_actuator_cap_conformance.gd"
)
$evaluator = Join-Path $turningRoot (
    "r23d58_godot_cap_source_factorial_evaluator.py"
)
$supervisor = Join-Path $sdkRoot "run_qsdk_r23d58_supervisor.ps1"
$closure = Join-Path $turningRoot (
    "r23d58_godot_cap_source_factorial_closure_v1.json"
)
$campaignId = "QSDK-R23D58-GODOT-CAP-SOURCE-FACTORIAL-REAR-CONTACT-MECHANISM-DEVELOPMENT"
$gateId = "QSDK-R23D58"
$stageId = "godot_cap_source_factorial_rear_contact_mechanism_development"
$candidateId = (
    "r23d29_r23d53_condition_post_r23d57_cap_source_factorial_" +
    "rear_contact_mechanism_development"
)
$policyId = (
    "sporespore_balanced_wave_r23d29_two_swing_persistent_predictive_" +
    "stability_guarded_steering_v1"
)
$originPolicyId = "warmup_preserving_command_onset_origin_reanchor_v1"
$liveFixtureCapBindingPolicyId = (
    "sporespore_godot_jolt_live_fixture_cap_source_factorial_binding_v1"
)
$inheritedLiveFixtureCapBindingPolicyId = (
    "sporespore_godot_jolt_live_fixture_compiled_actuator_cap_binding_v1"
)
$traceTransportId = "godot_4_7_sorted_full_precision_authoritative_json_v1"
$godotRuntimeVersion = "4.7-stable (official)"
$profiles = @(
    "portable_hip__portable_knee",
    "portable_hip__fixture_knee",
    "fixture_hip__portable_knee",
    "fixture_hip__fixture_knee"
)
$godotReadyMarker = "QSDK_R23D58_GODOT_SUPERVISOR_TERMINATION_READY "
$r23d58EnvironmentNames = @(
    "SPORESPORE_QSDK_R23D58_FREEZE",
    "SPORESPORE_QSDK_R23D58_ATTEMPT",
    "SPORESPORE_QSDK_R23D58_TOKEN",
    "SPORESPORE_QSDK_R23D58_STAGE",
    "SPORESPORE_QSDK_R23D58_CELL",
    "SPORESPORE_QSDK_R23D58_ENGINE",
    "SPORESPORE_QSDK_R23D58_ATTEMPT_ROOT",
    "SPORESPORE_QSDK_R23D58_PYTHON",
    "SPORESPORE_QSDK_R23D58_POWERSHELL",
    "SPORESPORE_QSDK_R23D58_SUPERVISED_TERMINATION",
    "SPORESPORE_QSDK_R23D58_TERMINATION_NONCE"
)

. (Join-Path $sdkRoot "godot_receipt_terminated_process.ps1")

function Assert-R23D58Role([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "QSDK-R23D58 $Role role: $Message" }
}

function Resolve-R23D58Application([string]$Command) {
    if ([IO.Path]::IsPathFullyQualified($Command)) {
        $resolved = [IO.Path]::GetFullPath($Command)
        Assert-R23D58Role (Test-Path -LiteralPath $resolved -PathType Leaf) (
            "application is missing: $resolved"
        )
        return $resolved
    }
    return [IO.Path]::GetFullPath([string](
        Get-Command $Command -CommandType Application -ErrorAction Stop |
            Select-Object -First 1
    ).Source)
}

function Get-R23D58Marker([object[]]$Output, [string]$Prefix) {
    $matches = @($Output | Where-Object {
        ([string]$_).StartsWith($Prefix, [StringComparison]::Ordinal)
    })
    Assert-R23D58Role ($matches.Count -eq 1) ($Output -join "`n")
    return ([string]$matches[0]).Substring($Prefix.Length) |
        ConvertFrom-Json -AsHashtable -Depth 100
}

$pythonPath = Resolve-R23D58Application $Python
$godotPath = Resolve-R23D58Application $Godot
Assert-R23D58Role (Test-Path -LiteralPath $godotAdapterDebug -PathType Leaf) (
    "debug Godot adapter is missing; build it before attestation"
)

$savedPythonPath = $env:PYTHONPATH
try {
    $campaignPythonPath = (@(
        $pythonModuleRoot,
        $turningRoot
    ) -join [IO.Path]::PathSeparator)
    $env:PYTHONPATH = if ([string]::IsNullOrWhiteSpace($savedPythonPath)) {
        $campaignPythonPath
    } else {
        "$campaignPythonPath$([IO.Path]::PathSeparator)$savedPythonPath"
    }

    if ($Role -ceq "worker") {
        $originOutput = @(
            & $godotPath --headless --path $repoRoot --script $originGate 2>&1
        )
        Assert-R23D58Role ($LASTEXITCODE -eq 0) ($originOutput -join "`n")
        $origin = Get-R23D58Marker $originOutput (
            "QSDK_R23D53_TASK_FRAME_ORIGIN_PASS "
        )
        Assert-R23D58Role (
            [bool]$origin.ok -and
            [string]$origin.policy_id -ceq $originPolicyId -and
            [int]$origin.assertion_count -eq 34 -and
            [int]$origin.rejected_mutation_count -eq 6 -and
            [int]$origin.model_construction_count -eq 0 -and
            [int]$origin.world_build_count -eq 0
        ) "task-origin gate changed"

        $observationOutput = @(
            & $godotPath --headless --path $repoRoot --script $observationGate 2>&1
        )
        Assert-R23D58Role ($LASTEXITCODE -eq 0) ($observationOutput -join "`n")
        $observation = Get-R23D58Marker $observationOutput (
            "SDK_GODOT_ACTUATOR_PHASE_OBSERVATION_PREFLIGHT "
        )
        Assert-R23D58Role (
            [bool]$observation.ok -and
            [string]$observation.observation_schema_version -ceq
                "sporespore_godot_jolt_actuator_phase_observation_v1" -and
            [int]$observation.validated_application_count -eq 8 -and
            [int]$observation.validated_limb_count -eq 4 -and
            [int]$observation.production_receipt_mutation_rejection_count -eq 2 -and
            [int]$observation.retained_row_mutation_rejection_count -eq 7 -and
            [bool]$observation.configured_motor_parameters_only -and
            -not [bool]$observation.measured_motor_torque_available -and
            -not [bool]$observation.measured_motor_impulse_available -and
            [int]$observation.model_construction_count -eq 0 -and
            [int]$observation.world_build_count -eq 0
        ) "actuator-phase production gate changed"

        $capOutput = @(
            & $godotPath --headless --path $repoRoot --script $capRuntimeGate 2>&1
        )
        Assert-R23D58Role ($LASTEXITCODE -eq 0) ($capOutput -join "`n")
        $cap = Get-R23D58Marker $capOutput (
            "QSDK_R23D55_GODOT_LIVE_FIXTURE_ACTUATOR_CAP_CONFORMANCE "
        )
        Assert-R23D58Role (
            [bool]$cap.ok -and
            [string]$cap.policy_id -ceq $inheritedLiveFixtureCapBindingPolicyId -and
            [int]$cap.validated_actuator_count -eq 8 -and
            [int]$cap.validated_limb_count -eq 4 -and
            [int]$cap.write_count -eq 8 -and
            [int]$cap.readback_count -eq 8 -and
            [double]$cap.maximum_postbinding_readback_error_nms -le 2.5e-7 -and
            [int]$cap.mutation_rejection_count -eq 14 -and
            [int]$cap.scene_tree_insertion_count -eq 0 -and
            [int]$cap.model_construction_count -eq 0 -and
            [int]$cap.world_attempt_count -eq 0 -and
            [int]$cap.world_build_count -eq 0 -and
            -not [bool]$cap.physics_state_modified -and
            -not [bool]$cap.turning_claimed -and
            -not [bool]$cap.prone_to_standing_claimed
        ) "live-fixture cap-binding runtime gate changed"

        foreach ($profile in $profiles) {
            $terminationNonce = [Guid]::NewGuid().ToString("N")
            $workerProcess = Invoke-SporeSporeGodotReceiptTerminatedProcess `
                -FileName $godotPath -WorkingDirectory $repoRoot `
                -Arguments @(
                    "--headless", "--path", $repoRoot, "--script", $worker, "--",
                    "--preflight-only", "--stage", $stageId,
                    "--onset", "onset_600", "--profile", $profile
                ) `
                -ReadyMarkerPrefix $godotReadyMarker `
                -ExpectedNonce $terminationNonce `
                -Environment @{
                    "SPORESPORE_QSDK_R23D58_SUPERVISED_TERMINATION" = "1"
                    "SPORESPORE_QSDK_R23D58_TERMINATION_NONCE" = $terminationNonce
                } `
                -ScrubEnvironmentNames $r23d58EnvironmentNames `
                -TimeoutSeconds 180
            $output = @([string]$workerProcess.stdout -split "`r?`n")
            Assert-R23D58Role (
                [int]$workerProcess.exit_code -eq 0 -and
                -not [bool]$workerProcess.timed_out -and
                [bool]$workerProcess.supervisor_terminated -and
                [bool]$workerProcess.termination_protocol_valid -and
                [string]$workerProcess.termination_ready_receipt.worker_receipt_kind -ceq
                    "preflight"
            ) (([string]$workerProcess.stderr) + "`n" + ([string]$workerProcess.stdout))
            $receipt = Get-R23D58Marker $output (
                "QSDK_R23D58_GODOT_JOLT_PREFLIGHT "
            )
            $originCanary = $receipt.task_frame_origin_transition_canary
            $diagnostic = $receipt.trace_diagnostic_canary
            $shutdown = $receipt.adapter_boundary.controller_session_shutdown
            Assert-R23D58Role (
                [string]$receipt.campaign_id -ceq $campaignId -and
                [string]$receipt.gate_id -ceq $gateId -and
                [string]$receipt.stage_id -ceq $stageId -and
                [string]$receipt.cell_id -ceq
                    "godot_jolt`__$candidateId`__profile_$profile" -and
                [string]$receipt.arm_id -ceq "reference_zero" -and
                [string]$receipt.profile_id -ceq $profile -and
                [string]$receipt.controller_policy_id -ceq $policyId -and
                [string]$receipt.task_frame_origin_policy_id -ceq
                    $originPolicyId -and
                [string]$receipt.actuator_phase_observation_schema_version -ceq
                    "sporespore_godot_jolt_actuator_phase_observation_v1" -and
                [bool]$receipt.actuator_phase_observation_required_on_every_trace_row -and
                [string]$receipt.live_fixture_actuator_cap_binding_policy_id -ceq
                    $liveFixtureCapBindingPolicyId -and
                [string]$receipt.live_fixture_actuator_cap_binding_profile_id -ceq
                    $profile -and
                [bool]$receipt.live_fixture_actuator_cap_binding_required -and
                -not [bool]$receipt.live_fixture_actuator_cap_binding_executed -and
                [bool]$receipt.live_fixture_actuator_cap_binding_execution_deferred_until_after_world_build -and
                [string]$receipt.trace_transport_id -ceq $traceTransportId -and
                [string]$receipt.godot_runtime_version -ceq
                    $godotRuntimeVersion -and
                [bool]$receipt.godot_json_full_precision -and
                [bool]$receipt.entrypoint_preflight.sdk_live_fixture_actuator_cap_binding_enabled -and
                [string]$receipt.entrypoint_preflight.sdk_live_fixture_actuator_cap_binding_policy_id -ceq
                    $liveFixtureCapBindingPolicyId -and
                [string]$receipt.entrypoint_preflight.sdk_live_fixture_actuator_cap_binding_profile_id -ceq
                    $profile -and
                -not [bool]$receipt.entrypoint_preflight.sdk_live_fixture_actuator_cap_binding_executed -and
                [string]$receipt.authoritative_json_transport_receipt.transport_id -ceq
                    $traceTransportId -and
                [bool]$receipt.authoritative_json_transport_receipt.sorted_keys -and
                [bool]$receipt.authoritative_json_transport_receipt.full_precision -and
                [string]$receipt.entrypoint_preflight.sdk_physical_trace_options.actuator_phase_observation_schema_version -ceq
                    "sporespore_godot_jolt_actuator_phase_observation_v1" -and
                [bool]$originCanary.ok -and
                [int]$originCanary.transition_count -eq 3 -and
                [int]$originCanary.initial_schedule_binding_count -eq 1 -and
                [bool]$originCanary.initial_origin_preserved -and
                [int]$originCanary.same_segment_hold_count -eq 4 -and
                [int]$originCanary.rejected_mutation_count -eq 2 -and
                [int]$originCanary.fixed_origin_last_semantic_step -eq 599 -and
                (@($originCanary.expected_transition_steps) -join ",") -ceq
                    "600,1800,2400" -and
                (@($originCanary.production_command_segment_ids) -join ",") -ceq
                    "reference_warmup,commanded_turn,reference_recovery,reference_continuation" -and
                [string]$diagnostic.schema_version -ceq
                    "sporespore_qsdk_r23d58_trace_diagnostic_v1" -and
                [string]$diagnostic.campaign_id -ceq $campaignId -and
                [string]$diagnostic.gate_id -ceq $gateId -and
                [bool]$shutdown.ok -and
                [bool]$shutdown.explicit_shutdown_completed -and
                [int]$shutdown.native_controller_session_destroy_count -eq 1 -and
                [int]$receipt.orderly_exit_drain_process_frame_count -eq 2 -and
                [int]$receipt.model_construction_count -eq 0 -and
                [int]$receipt.world_build_count -eq 0
            ) "worker preflight changed: $profile"
        }

        $actualNonce = [Guid]::NewGuid().ToString("N")
        $wrongExpectedNonce = [Guid]::NewGuid().ToString("N")
        $nonceRejectedProcess = Invoke-SporeSporeGodotReceiptTerminatedProcess `
            -FileName $godotPath -WorkingDirectory $repoRoot `
            -Arguments @(
                "--headless", "--path", $repoRoot, "--script", $worker, "--",
                "--preflight-only", "--stage", $stageId,
                "--onset", "onset_600", "--profile", $profiles[0]
            ) `
            -ReadyMarkerPrefix $godotReadyMarker `
            -ExpectedNonce $wrongExpectedNonce `
            -Environment @{
                "SPORESPORE_QSDK_R23D58_SUPERVISED_TERMINATION" = "1"
                "SPORESPORE_QSDK_R23D58_TERMINATION_NONCE" = $actualNonce
            } `
            -ScrubEnvironmentNames $r23d58EnvironmentNames `
            -TimeoutSeconds 180
        $nonceRejectedOutput = @(
            [string]$nonceRejectedProcess.stdout -split "`r?`n"
        )
        $nonceRejectedReceipt = Get-R23D58Marker $nonceRejectedOutput (
            "QSDK_R23D58_GODOT_JOLT_PREFLIGHT "
        )
        Assert-R23D58Role (
            -not [bool]$nonceRejectedProcess.timed_out -and
            -not [bool]$nonceRejectedProcess.supervisor_terminated -and
            -not [bool]$nonceRejectedProcess.termination_protocol_valid -and
            [string]$nonceRejectedProcess.termination_protocol_failure_code -ceq
                "GODOT_READY_MARKER_BINDING_INVALID" -and
            [string]$nonceRejectedProcess.termination_ready_receipt.termination_nonce -ceq
                $actualNonce -and
            [int]$nonceRejectedReceipt.model_construction_count -eq 0 -and
            [int]$nonceRejectedReceipt.world_build_count -eq 0
        ) "wrong termination nonce was not rejected before world entry"

        $terminationNonce = [Guid]::NewGuid().ToString("N")
        $unauthorizedProcess = Invoke-SporeSporeGodotReceiptTerminatedProcess `
            -FileName $godotPath -WorkingDirectory $repoRoot `
            -Arguments @(
                "--headless", "--path", $repoRoot, "--script", $worker, "--",
                "--stage", $stageId, "--onset", "onset_600",
                "--profile", $profiles[0], "--source-commit",
                "0000000000000000000000000000000000000000"
            ) `
            -ReadyMarkerPrefix $godotReadyMarker `
            -ExpectedNonce $terminationNonce `
            -Environment @{
                "SPORESPORE_QSDK_R23D58_SUPERVISED_TERMINATION" = "1"
                "SPORESPORE_QSDK_R23D58_TERMINATION_NONCE" = $terminationNonce
            } `
            -ScrubEnvironmentNames $r23d58EnvironmentNames `
            -TimeoutSeconds 180
        $unauthorizedOutput = @(
            [string]$unauthorizedProcess.stdout -split "`r?`n"
        )
        Assert-R23D58Role (
            [int]$unauthorizedProcess.exit_code -eq 1 -and
            -not [bool]$unauthorizedProcess.timed_out -and
            [bool]$unauthorizedProcess.supervisor_terminated -and
            [bool]$unauthorizedProcess.termination_protocol_valid -and
            [string]$unauthorizedProcess.termination_ready_receipt.worker_receipt_kind -ceq
                "terminal"
        ) (([string]$unauthorizedProcess.stderr) + "`n" + ([string]$unauthorizedProcess.stdout))
        $unauthorized = Get-R23D58Marker $unauthorizedOutput (
            "QSDK_R23D58_GODOT_JOLT_TERMINAL "
        )
        # Before closure, missing authorization must fail as unauthorized. Once
        # the immutable closure exists, the stronger consumed-campaign guard
        # runs first and must fail as closed. Both paths remain zero-world.
        $expectedAuthorizationFailure = if (
            Test-Path -LiteralPath $closure -PathType Leaf
        ) {
            "QSDK_R23D58_GJT_CLOSED"
        } else {
            "QSDK_R23D58_GJT_PHYSICAL_AUTHORIZATION_REQUIRED"
        }
        Assert-R23D58Role (
            [string]$unauthorized.failure_code -ceq
                $expectedAuthorizationFailure -and
            [int]$unauthorized.world_attempt_count -eq 0 -and
            [int]$unauthorized.world_build_count -eq 0
        ) "closed or unauthorized physical control changed"

        Write-Host (
            "QSDK_R23D58_CAMPAIGN_WORKER_ROLE_PASS cells=4 profiles=4 bindings=1 cap_writes=8 cap_readbacks=8 transitions=3 " +
            "mutations=7 cap_mutations=14 authorization_mutations=1 termination_mutations=1 " +
            "models=0 worlds=0 physical=False"
        )
    } elseif ($Role -ceq "evaluator") {
        $output = @(& $pythonPath $evaluator preflight 2>&1)
        Assert-R23D58Role ($LASTEXITCODE -eq 0) ($output -join "`n")
        $receipt = Get-R23D58Marker $output (
            "QSDK_R23D58_EVALUATOR_PREFLIGHT "
        )
        Assert-R23D58Role (
            [int]$receipt.declared_cell_count -eq 4 -and
            [int]$receipt.valid_trace_canary_count -eq 4 -and
            [int]$receipt.trace_mutation_rejection_count -eq 30 -and
            [int]$receipt.origin_policy_mutation_rejection_count -eq 8 -and
            [int]$receipt.startup_transform_mutation_rejection_count -eq 1 -and
            [int]$receipt.segment_mutation_rejection_count -eq 1 -and
            [int]$receipt.observation_mutation_rejection_count -eq 20 -and
            [int]$receipt.live_fixture_cap_binding_projection_positive_control_count -eq 4 -and
            [int]$receipt.live_fixture_cap_binding_projection_mutation_rejection_count -eq 21 -and
            [int]$receipt.trace_transport_metadata_positive_control_count -eq 1 -and
            [int]$receipt.trace_transport_metadata_mutation_rejection_count -eq 6 -and
            [string]$receipt.trace_transport_id -ceq $traceTransportId -and
            [string]$receipt.godot_runtime_version -ceq $godotRuntimeVersion -and
            [bool]$receipt.godot_json_full_precision -and
            [double]$receipt.reported_error_recomputation_consistency_tolerance -eq
                1.0e-15 -and
            [int]$receipt.descriptive_characterization_canary_count -eq 4 -and
            [int]$receipt.predeclared_factorial_contrast_canary_count -eq 5 -and
            [int]$receipt.observation_row_count_per_trace -eq 2992 -and
            [int]$receipt.observation_application_count_per_trace -eq 23936 -and
            -not [bool]$receipt.turning_gate_invoked -and
            [int]$receipt.mechanism_selection_rule_count -eq 0 -and
            [int]$receipt.same_file_path_spelling_positive_control_count -eq 1 -and
            [int]$receipt.wrong_file_path_rejection_count -eq 1 -and
            [bool]$receipt.production_cas_binding_uses_existing_file_identity -and
            [int]$receipt.complete_evaluation_authority_root_cli_canary_count -eq 1 -and
            [int]$receipt.model_construction_count -eq 0 -and
            [int]$receipt.world_build_count -eq 0
        ) "evaluator preflight controls changed"
        Write-Host (
            "QSDK_R23D58_CAMPAIGN_EVALUATOR_ROLE_PASS cells=4 profiles=4 " +
            "trace_canaries=4 mutations=30 observation_mutations=20 cap_projection_mutations=21 contrasts=5 " +
            "transport_metadata_mutations=6 " +
            "models=0 worlds=0 physical=False"
        )
    } else {
        $output = @(
            & pwsh -NoLogo -NoProfile -File $supervisor -PreflightOnly `
                -Python $pythonPath -Godot $godotPath 2>&1
        )
        Assert-R23D58Role ($LASTEXITCODE -eq 0) ($output -join "`n")
        $receipt = Get-R23D58Marker $output "QSDK_R23D58_ZERO_WORLD_PASS "
        Assert-R23D58Role (
            [int]$receipt.declared_cell_count -eq 4 -and
            [int]$receipt.worker_preflight_count -eq 4 -and
            [int]$receipt.source_binding_count -gt 40 -and
            [bool]$receipt.source_bindings_checkout_bytes_equal_git_blobs -and
            [bool]$receipt.r23d58_lineage_gate_passed -and
            [int]$receipt.r23d58_lineage_gate.factorial_profile_count -eq 4 -and
            [int]$receipt.r23d58_lineage_gate.factorial_binder_mutation_rejection_count -eq 12 -and
            [int]$receipt.r23d58_lineage_gate.terminal_trace_transport_mutation_rejection_count -eq 32 -and
            [int]$receipt.r23d58_lineage_gate.production_route_mutation_rejection_count -eq 20 -and
            [bool]$receipt.task_frame_origin_gate_passed -and
            [bool]$receipt.actuator_phase_observation_gate_passed -and
            [bool]$receipt.r23d55_live_fixture_cap_source_audit_passed -and
            [bool]$receipt.r23d55_live_fixture_cap_runtime_gate_passed -and
            [string]$receipt.live_fixture_actuator_cap_binding_policy_id -ceq
                $liveFixtureCapBindingPolicyId -and
            [int]$receipt.live_fixture_actuator_cap_binding_validated_actuator_count -eq 8 -and
            [int]$receipt.live_fixture_actuator_cap_binding_write_count -eq 8 -and
            [int]$receipt.live_fixture_actuator_cap_binding_readback_count -eq 8 -and
            [int]$receipt.live_fixture_actuator_cap_binding_mutation_rejection_count -eq 14 -and
            [int]$receipt.observation_mutation_rejection_count -eq 20 -and
            [int]$receipt.live_fixture_cap_binding_projection_mutation_rejection_count -eq 21 -and
            [int]$receipt.trace_transport_metadata_mutation_rejection_count -eq 6 -and
            [string]$receipt.trace_transport_id -ceq $traceTransportId -and
            [string]$receipt.godot_runtime_version -ceq $godotRuntimeVersion -and
            [bool]$receipt.godot_json_full_precision -and
            [int]$receipt.positive_terminal_projection_canary_count -eq 1 -and
            [int]$receipt.failure_terminal_projection_canary_count -eq 2 -and
            [int]$receipt.terminal_projection_mutation_rejection_count -eq 10 -and
            [bool]$receipt.terminal_projection_uses_worker_execution_object -and
            [string]$receipt.terminal_execution_projection.schema_version -ceq
                "sporespore_qsdk_r23d58_terminal_projection_preflight_v1" -and
            [int]$receipt.terminal_execution_projection.world_attempt_count -eq 0 -and
            [int]$receipt.terminal_execution_projection.world_build_count -eq 0 -and
            [int]$receipt.model_construction_count -eq 0 -and
            [int]$receipt.world_build_count -eq 0
        ) "supervisor preflight receipt changed"
        Write-Host (
            "QSDK_R23D58_CAMPAIGN_SUPERVISOR_ROLE_PASS cells=4 profiles=4 " +
            "source_bindings=$($receipt.source_binding_count) " +
            "terminal_projection_canaries=3 projection_mutations=10 observation_mutations=20 " +
            "cap_route_mutations=14 cap_projection_mutations=21 " +
            "transport_metadata_mutations=6 " +
            "models=0 worlds=0 physical=False"
        )
    }
} finally {
    $env:PYTHONPATH = $savedPythonPath
}
