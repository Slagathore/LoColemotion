$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = [System.IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$sdkRoot = Join-Path $repoRoot "sdk"
$closurePath = Join-Path (
    $sdkRoot
) "rapier_c6_bw19v_velocity_only_terminal_stance_commissioning_ts1_closure.json"
$expectedClosureRawSha256 = (
    "375fdec1e04efede7beefc80b0fd5a916f201e9b83fb40b572c28c20b9d43891"
)
$campaignId = (
    "C6-RAPIER-BW19V-VELOCITY-ONLY-TERMINAL-STANCE-COMMISSIONING-TS1"
)
$gateId = "C6-RAP-BW19V-V4-TS1"
$physicalSourceCommit = "9cb55a581efe0b3743bcb2bee82eb3be6802efd0"
$posthocSourceCommit = "23f76a41ba0f96a56094350632081acffcc96abe"
$posthocSourceGitBlobOid = "9ce5529164dcccd6ad95917a78146fe1f4479698"
$terminalFailure = "C6_RAP_V4_TS1_TERMINAL_STANCE"

function Assert-Exact {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) {
        throw $Message
    }
}

function Get-RawSha256 {
    param([Parameter(Mandatory)][string]$Path)
    return (Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash.ToLowerInvariant()
}

Assert-Exact (
    (Test-Path -LiteralPath $closurePath -PathType Leaf) -and
    (Get-RawSha256 $closurePath) -ceq $expectedClosureRawSha256
) "$gateId closure is missing or changed"
$closure = Get-Content -Raw -LiteralPath $closurePath | ConvertFrom-Json
Assert-Exact (
    [string]$closure.campaign_id -ceq $campaignId -and
    [string]$closure.gate_id -ceq $gateId -and
    [string]$closure.status -ceq
        "closed_complete_valid_negative_terminal_four_contact_failure" -and
    [string]$closure.physical_source_commit -ceq $physicalSourceCommit -and
    -not [bool]$closure.same_identity_rerun_allowed -and
    -not [bool]$closure.threshold_horizon_schedule_report_or_world_rewrite_allowed -and
    [int]$closure.physical_attempt.process_launch_count -eq 1 -and
    [int]$closure.physical_attempt.world_attempt_count -eq 1 -and
    [int]$closure.physical_attempt.world_build_count -eq 1 -and
    [int]$closure.physical_attempt.world_reset_count -eq 0 -and
    [int]$closure.physical_attempt.trace_step_count -eq 3172 -and
    [int]$closure.physical_attempt.command_count_per_layer -eq 25376 -and
    -not [bool]$closure.physical_attempt.retained_primary_report_ok -and
    [bool]$closure.physical_attempt.retained_primary_report_is_complete_valid_negative -and
    (@($closure.physical_attempt.gate_failure_codes) -join "|") -ceq $terminalFailure -and
    [bool]$closure.posthoc_diagnostic_result.diagnostic_complete -and
    [bool]$closure.posthoc_diagnostic_result.retained_primary_report_is_complete_valid_negative -and
    (@($closure.posthoc_diagnostic_result.frozen_evaluator_recomputed_failure_codes) -join "|") -ceq
        $terminalFailure -and
    [bool]$closure.posthoc_diagnostic_result.only_failure_is_terminal_four_contact_stance -and
    [bool]$closure.posthoc_diagnostic_result.valid_primary_ts1_negative_result -and
    -not [bool]$closure.posthoc_diagnostic_result.finite_walking_contract_passed -and
    -not [bool]$closure.claims.exact_s169_rapier_v4_terminal_return_technical_commissioning -and
    -not [bool]$closure.claims.finite_walking_contract_passed -and
    -not [bool]$closure.claims.rapier_selected_policy_physical_c6 -and
    -not [bool]$closure.claims.release_authorized -and
    -not [bool]$closure.claims.physical_acceptance_authority
) "$gateId closure disposition, failure set, or claim boundary changed"

foreach ($binding in @($closure.frozen_source_blobs.PSObject.Properties)) {
    $entry = $binding.Value
    $blob = (& git -C $repoRoot rev-parse (
        $physicalSourceCommit + ":" + [string]$entry.path
    )).Trim()
    Assert-Exact (
        $LASTEXITCODE -eq 0 -and
        [string]$entry.raw_sha256 -cmatch "^[0-9a-f]{64}$" -and
        $blob -ceq [string]$entry.git_blob_oid
    ) "$gateId physical source Git blob changed: $($entry.path)"
}
foreach ($binding in @($closure.closure_implementation_bindings.PSObject.Properties)) {
    $entry = $binding.Value
    $relativePath = [string]$entry.path
    $path = [System.IO.Path]::GetFullPath(
        (Join-Path $repoRoot $relativePath)
    )
    $posthocBlob = (& git -C $repoRoot rev-parse (
        $posthocSourceCommit + ":" + $relativePath
    )).Trim()
    Assert-Exact (
        $LASTEXITCODE -eq 0 -and
        $posthocBlob -ceq $posthocSourceGitBlobOid -and
        (Test-Path -LiteralPath $path -PathType Leaf) -and
        (Get-RawSha256 $path) -ceq [string]$entry.raw_sha256
    ) "$gateId post-hoc implementation binding changed: $path"
}

$evidenceRoot = [System.IO.Path]::GetFullPath(
    [string]$closure.retained_evidence.root
)
$expectedEvidencePrefix = [System.IO.Path]::GetFullPath(
    (Join-Path (Split-Path -Parent $repoRoot) "SporeSpore_Evidence")
).TrimEnd(
    [System.IO.Path]::DirectorySeparatorChar,
    [System.IO.Path]::AltDirectorySeparatorChar
) + [System.IO.Path]::DirectorySeparatorChar
Assert-Exact (
    $evidenceRoot.StartsWith(
        $expectedEvidencePrefix,
        [StringComparison]::OrdinalIgnoreCase
    )
) "$gateId evidence root escaped SporeSpore_Evidence"
foreach ($binding in @($closure.retained_evidence.PSObject.Properties)) {
    if ($binding.Name -ceq "root") {
        continue
    }
    $entry = $binding.Value
    $path = Join-Path $evidenceRoot ([string]$entry.path)
    Assert-Exact (
        (Test-Path -LiteralPath $path -PathType Leaf) -and
        (Get-RawSha256 $path) -ceq [string]$entry.raw_sha256 -and
        (Get-Item -LiteralPath $path).Length -eq [long]$entry.byte_length
    ) "$gateId retained evidence changed: $path"
}

$attempt = Get-Content -Raw -LiteralPath (
    Join-Path $evidenceRoot "attempt.json"
) | ConvertFrom-Json
$completion = Get-Content -Raw -LiteralPath (
    Join-Path $evidenceRoot "completion.json"
) | ConvertFrom-Json
$diagnosticPath = Join-Path $evidenceRoot "posthoc_diagnostic_v1.json"
$diagnostic = Get-Content -Raw -LiteralPath $diagnosticPath | ConvertFrom-Json
Assert-Exact (
    [string]$attempt.status -ceq
        "physical_process_launch_reserved_identity_consumed" -and
    [string]$attempt.source_commit -ceq $physicalSourceCommit -and
    [int]$attempt.declared_world_count -eq 1 -and
    [int]$attempt.declared_controller_steps -eq 3172 -and
    [int]$attempt.declared_terminal_target_gait_step -eq 1970 -and
    [int]$attempt.declared_terminal_target_global_cycle_step -eq 170 -and
    -not [bool]$attempt.same_identity_rerun_allowed -and
    [string]$completion.status -ceq "physical_process_exited_with_report" -and
    [int]$completion.process_exit_code -eq 1 -and
    [bool]$completion.report_retained -and
    [string]$completion.report_raw_sha256 -ceq (
        "sha256:" + [string]$closure.retained_evidence.primary_report.raw_sha256
    ) -and
    -not [bool]$completion.same_identity_rerun_allowed
) "$gateId attempt or completion receipt changed"

Assert-Exact (
    [bool]$diagnostic.ok -and
    [string]$diagnostic.schema_version -ceq
        "sporespore_rapier_c6_bw19v_velocity_only_ts1_posthoc_diagnostic_v1" -and
    -not [bool]$diagnostic.retained_primary_report_ok -and
    [bool]$diagnostic.retained_primary_report_is_complete_valid_negative -and
    (@($diagnostic.original_primary_failure_codes) -join "|") -ceq $terminalFailure -and
    (@($diagnostic.frozen_evaluator_recomputed_failure_codes) -join "|") -ceq
        $terminalFailure -and
    [bool]$diagnostic.frozen_evaluator_recomputed_only_failure_is_terminal_four_contact_stance -and
    (@($diagnostic.explicit_limb_identity_reconstruction.morphology_ordered_limb_ids) -join "|") -ceq
        "front_left|front_right|rear_left|rear_right" -and
    (@($diagnostic.explicit_limb_identity_reconstruction.observed_scheduler_memory_order) -join "|") -ceq
        "rear_left|front_left|rear_right|front_right" -and
    [bool]$diagnostic.explicit_limb_identity_reconstruction.identity_set_complete_unique_and_stable_at_every_trace_layer -and
    [int]$diagnostic.posthoc_observations.trace_step_count -eq 3172 -and
    [int]$diagnostic.posthoc_observations.evidence_completion_semantic_step -eq 2091 -and
    [int]$diagnostic.posthoc_observations.terminal_activation_semantic_step -eq 2092 -and
    [int]$diagnostic.posthoc_observations.terminal_completion_semantic_step -eq 2151 -and
    [int]$diagnostic.posthoc_observations.terminal_acquisition_semantic_steps -eq 60 -and
    [int]$diagnostic.posthoc_observations.required_post_terminal_steps -eq 360 -and
    [int]$diagnostic.posthoc_observations.observed_post_terminal_steps -eq 1020 -and
    (@($diagnostic.posthoc_observations.post_evidence_all_four_contact_semantic_steps) -join "|") -ceq
        "2092|2093" -and
    [int]$diagnostic.posthoc_observations.front_left_last_contact_semantic_step -eq 2093 -and
    [int]$diagnostic.posthoc_observations.front_left_contact_loss_semantic_step -eq 2094 -and
    [int]$diagnostic.posthoc_observations.front_left_final_airborne_dwell_steps -eq 1078 -and
    [int]$diagnostic.posthoc_observations.front_left_maximum_post_evidence_contact_site_height.semantic_step -eq 2130 -and
    [double]$diagnostic.posthoc_observations.front_left_maximum_post_evidence_contact_site_height.height_m -eq
        0.12096497416496277 -and
    -not [bool]$diagnostic.posthoc_observations.terminal_declared_contacts.front_left_foot -and
    [bool]$diagnostic.posthoc_observations.terminal_declared_contacts.front_right_foot -and
    [bool]$diagnostic.posthoc_observations.terminal_declared_contacts.rear_left_foot -and
    [bool]$diagnostic.posthoc_observations.terminal_declared_contacts.rear_right_foot -and
    (@($diagnostic.posthoc_observations.missing_terminal_contact_ids) -join "|") -ceq
        "front_left_foot" -and
    [double]$diagnostic.posthoc_observations.final_front_left_contact_site_height_m -eq
        0.06796658784151077 -and
    [double]$diagnostic.posthoc_observations.final_front_left_height_above_other_contact_site_mean_m -eq
        0.030245651801427208 -and
    -not [bool]$diagnostic.development_mechanism_interpretation.terminal_stance_threshold_retroactively_waived -and
    -not [bool]$diagnostic.development_mechanism_interpretation.ts1_reclassified_as_passing -and
    [bool]$diagnostic.claims.valid_primary_ts1_negative_result -and
    -not [bool]$diagnostic.claims.finite_walking_contract_passed -and
    -not [bool]$diagnostic.claims.physical_acceptance_authority
) "$gateId post-hoc reconstruction, terminal failure, or non-claim changed"

$keySteps = @($diagnostic.posthoc_observations.key_trace_steps)
$targetStep = @($keySteps | Where-Object { [int]$_.semantic_step -eq 2151 })
$finalStep = @($keySteps | Where-Object { [int]$_.semantic_step -eq 3171 })
Assert-Exact (
    $targetStep.Count -eq 1 -and
    $finalStep.Count -eq 1
) "$gateId key terminal trace steps are incomplete or duplicated"
$targetMemory = @($targetStep[0].ordered_limb_controller_memory_after)
$finalMemory = @($finalStep[0].ordered_limb_controller_memory_after)
Assert-Exact (
    $targetMemory.Count -eq 4 -and
    $finalMemory.Count -eq 4 -and
    (@($targetMemory | ForEach-Object { [int]$_.gait_step }) -join "|") -ceq
        "1970|1970|1970|1970" -and
    (@($targetMemory | ForEach-Object { [int]$_.evidence_gait_step_limit }) -join "|") -ceq
        "1970|1970|1970|1970" -and
    (@($finalMemory | ForEach-Object { [int]$_.gait_step }) -join "|") -ceq
        "1970|1970|1970|1970"
) "$gateId terminal gait memory target was not reached and held"
$targetKnee = @(
    $targetStep[0].front_left_portable_base_commands |
    Where-Object { [string]$_.actuator_id -ceq "front_left_knee_motor" }
)
$targetHip = @(
    $targetStep[0].front_left_portable_base_commands |
    Where-Object { [string]$_.actuator_id -ceq "front_left_hip_motor" }
)
$finalKnee = @(
    $finalStep[0].front_left_portable_base_commands |
    Where-Object { [string]$_.actuator_id -ceq "front_left_knee_motor" }
)
$finalHip = @(
    $finalStep[0].front_left_portable_base_commands |
    Where-Object { [string]$_.actuator_id -ceq "front_left_hip_motor" }
)
$finalKneeMotor = @(
    $finalStep[0].front_left_motor_readbacks_and_impulses |
    Where-Object { [string]$_.actuator_id -ceq "front_left_knee_motor" }
)
$finalHipMotor = @(
    $finalStep[0].front_left_motor_readbacks_and_impulses |
    Where-Object { [string]$_.actuator_id -ceq "front_left_hip_motor" }
)
Assert-Exact (
    $targetKnee.Count -eq 1 -and
    $targetHip.Count -eq 1 -and
    $finalKnee.Count -eq 1 -and
    $finalHip.Count -eq 1 -and
    [double]$targetKnee[0].clamped_target_position_rad -eq 0.0 -and
    [double]$targetHip[0].clamped_target_position_rad -eq 0.29631179778154393 -and
    [double]$finalKnee[0].clamped_target_position_rad -eq 0.0 -and
    [double]$finalHip[0].clamped_target_position_rad -eq 0.30905633355797696 -and
    $finalKneeMotor.Count -eq 1 -and
    $finalHipMotor.Count -eq 1 -and
    [double]$finalKneeMotor[0].stiffness_nm_per_rad -eq 0.0 -and
    [double]$finalHipMotor[0].stiffness_nm_per_rad -eq 0.0 -and
    [string]$finalKneeMotor[0].motor_model -ceq "ForceBased" -and
    [string]$finalHipMotor[0].motor_model -ceq "ForceBased"
) "$gateId off-ground terminal-reference witness changed"

$temporaryRoot = [System.IO.Path]::GetFullPath(
    (Join-Path ([System.IO.Path]::GetTempPath()) (
        "sporespore_ts1_closure_" + [Guid]::NewGuid().ToString("N")
    ))
)
$temporaryPrefix = [System.IO.Path]::GetFullPath(
    [System.IO.Path]::GetTempPath()
).TrimEnd(
    [System.IO.Path]::DirectorySeparatorChar,
    [System.IO.Path]::AltDirectorySeparatorChar
) + [System.IO.Path]::DirectorySeparatorChar
Assert-Exact (
    $temporaryRoot.StartsWith(
        $temporaryPrefix,
        [StringComparison]::OrdinalIgnoreCase
    )
) "$gateId temporary audit root escaped the system temporary directory"
[void][System.IO.Directory]::CreateDirectory($temporaryRoot)
$recomputedPath = Join-Path $temporaryRoot "posthoc_diagnostic_v1.json"
$reportPath = Join-Path $evidenceRoot "report.json"
try {
    Push-Location -LiteralPath $sdkRoot
    try {
        $recomputedLines = @(
            & cargo run `
                --quiet `
                --package sporespore-rapier-adapter `
                --bin bw19v_velocity_only_terminal_stance_ts1_posthoc `
                --offline `
                -- `
                --report $reportPath `
                --output $recomputedPath
        )
        Assert-Exact (
            $LASTEXITCODE -eq 0
        ) "$gateId post-hoc evaluator failed"
    } finally {
        Pop-Location
    }
    Assert-Exact (
        (Test-Path -LiteralPath $recomputedPath -PathType Leaf) -and
        (Get-RawSha256 $recomputedPath) -ceq
            [string]$closure.retained_evidence.posthoc_diagnostic_v1.raw_sha256
    ) "$gateId post-hoc diagnostic is not deterministic"
} finally {
    if (Test-Path -LiteralPath $temporaryRoot -PathType Container) {
        [System.IO.Directory]::Delete($temporaryRoot, $true)
    }
}

$supervisorPath = Join-Path (
    $sdkRoot
) "run_rapier_c6_bw19v_velocity_only_terminal_stance_ts1.ps1"
$supervisor = Get-Content -Raw -LiteralPath $supervisorPath
$closureCheckIndex = $supervisor.IndexOf(
    '$gateId is already closed and may not open another world'
)
$preregistrationCheckIndex = $supervisor.IndexOf(
    '$gateId preregistration is missing or changed'
)
Assert-Exact (
    $closureCheckIndex -ge 0 -and
    $preregistrationCheckIndex -gt $closureCheckIndex
) "$gateId supervisor no longer fails closed before mutable checkout inputs"
$interlockOutput = @(
    & pwsh -NoProfile -File $supervisorPath -RunPhysical 2>&1
)
$interlockExitCode = $LASTEXITCODE
Assert-Exact (
    $interlockExitCode -ne 0 -and
    ($interlockOutput -join "`n").Contains(
        "$gateId is already closed and may not open another world"
    )
) "$gateId executable same-identity rerun interlock failed"
# The nonzero child exit is the expected evidence for the fail-closed physical
# interlock. Do not leak that expected child status to a caller that invokes
# this audit in-process and interprets LASTEXITCODE as the audit's own status.
$global:LASTEXITCODE = 0

Write-Host (
    "C6_RAP_V4_TS1_CLOSURE_PASS primary_ok=False valid_negative=True " +
    "worlds=1 trace_steps=3172 failure=TERMINAL_STANCE " +
    "target_step=2151 front_left_last_contact=2093 " +
    "final_airborne_dwell=1078 walking_authority=False " +
    "same_identity_rerun=False"
)
