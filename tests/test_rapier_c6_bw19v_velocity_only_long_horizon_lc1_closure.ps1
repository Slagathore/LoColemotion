$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = [System.IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$sdkRoot = Join-Path $repoRoot "sdk"
$closurePath = Join-Path (
    $sdkRoot
) "rapier_c6_bw19v_velocity_only_long_horizon_commissioning_lc1_closure.json"
$expectedClosureRawSha256 = (
    "526ed77562036f1a5e0a039269a053f154f29ec76903c3709006798a8b848206"
)
$campaignId = "C6-RAPIER-BW19V-VELOCITY-ONLY-LONG-HORIZON-COMMISSIONING-LC1"
$gateId = "C6-RAP-BW19V-V4-LC1"
$physicalSourceCommit = "6a1968015dfbc7bb0ab2ff93f3467b5c2187781e"
$posthocSourceCommit = "7ffd75c0b8f418dad1317c0a748ed4fd1e6e5f9b"
$posthocSourceGitBlobOid = "b47bcea08864f71f8a8781e519af63caca80d2df"

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
$expectedPrimaryFailures = @(
    "C6_RAP_V4_LC1_EVIDENCE_COMPLETION_RECOMPUTE",
    "C6_RAP_V4_LC1_EVIDENCE_DEADLINE_OR_COOLDOWN",
    "C6_RAP_V4_LC1_METRIC_RECOMPUTE:/metrics/evidence_forward_displacement_m",
    "C6_RAP_V4_LC1_TERMINAL_STANCE",
    "C6_RAP_V4_LC1_EVIDENCE_ADVANCE"
)
Assert-Exact (
    [string]$closure.campaign_id -ceq $campaignId -and
    [string]$closure.gate_id -ceq $gateId -and
    [string]$closure.status -ceq
        "closed_invalid_primary_report_with_posthoc_single_remaining_terminal_stance_failure" -and
    [string]$closure.physical_source_commit -ceq $physicalSourceCommit -and
    -not [bool]$closure.same_identity_rerun_allowed -and
    -not [bool]$closure.threshold_horizon_schedule_report_or_world_rewrite_allowed -and
    [int]$closure.physical_attempt.process_launch_count -eq 1 -and
    [int]$closure.physical_attempt.world_build_count -eq 1 -and
    [int]$closure.physical_attempt.trace_step_count -eq 2992 -and
    [int]$closure.physical_attempt.command_count_per_layer -eq 23936 -and
    -not [bool]$closure.physical_attempt.retained_primary_report_ok -and
    (@($closure.physical_attempt.original_gate_failure_codes) -join "|") -ceq
        ($expectedPrimaryFailures -join "|") -and
    [bool]$closure.posthoc_diagnostic_result.diagnostic_complete -and
    -not [bool]$closure.posthoc_diagnostic_result.corrected_counterfactual_full_gate_passed -and
    [bool]$closure.posthoc_diagnostic_result.corrected_counterfactual_integrity_reconstructible -and
    (@($closure.posthoc_diagnostic_result.corrected_counterfactual_failure_codes) -join "|") -ceq
        "C6_RAP_V4_LC1_TERMINAL_STANCE" -and
    -not [bool]$closure.claims.valid_primary_lc1_result -and
    -not [bool]$closure.claims.finite_walking_contract_passed -and
    -not [bool]$closure.claims.rapier_selected_policy_physical_c6 -and
    -not [bool]$closure.claims.release_authorized -and
    -not [bool]$closure.claims.physical_acceptance_authority
) "$gateId closure disposition, primary failure set, or claim boundary changed"

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
$diagnosticPath = Join-Path $evidenceRoot "posthoc_diagnostic_v2.json"
$diagnostic = Get-Content -Raw -LiteralPath $diagnosticPath | ConvertFrom-Json
Assert-Exact (
    [string]$attempt.status -ceq
        "physical_process_launch_reserved_identity_consumed" -and
    [string]$attempt.source_commit -ceq $physicalSourceCommit -and
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
        "sporespore_rapier_c6_bw19v_velocity_only_lc1_posthoc_diagnostic_v2" -and
    -not [bool]$diagnostic.retained_primary_report_ok -and
    [bool]$diagnostic.retained_primary_report_remains_invalid -and
    (@($diagnostic.original_primary_failure_codes) -join "|") -ceq
        ($expectedPrimaryFailures -join "|") -and
    -not [bool]$diagnostic.corrected_counterfactual_full_gate_passed -and
    [bool]$diagnostic.corrected_counterfactual_integrity_reconstructible -and
    (@($diagnostic.corrected_counterfactual_failure_codes) -join "|") -ceq
        "C6_RAP_V4_LC1_TERMINAL_STANCE" -and
    (@($diagnostic.diagnosed_evaluator_defect.morphology_limb_order) -join "|") -ceq
        "front_left|front_right|rear_left|rear_right" -and
    (@($diagnostic.diagnosed_evaluator_defect.observed_scheduler_memory_order) -join "|") -ceq
        "rear_left|front_left|rear_right|front_right" -and
    [bool]$diagnostic.diagnosed_evaluator_defect.synthetic_used_morphology_order_and_lacked_permutation_witness -and
    [int]$diagnostic.posthoc_observations.evidence_completion_semantic_step -eq 2091 -and
    [bool]$diagnostic.posthoc_observations.required_post_evidence_steps_completed -and
    [double]$diagnostic.posthoc_observations.evidence_forward_displacement_m -eq
        1.4770497977733612 -and
    [double]$diagnostic.posthoc_observations.final_forward_displacement_m -eq
        1.8938268423080444 -and
    [int]$diagnostic.posthoc_observations.torso_ground_contact_step_count -eq 0 -and
    [bool]$diagnostic.posthoc_observations.evidence_completion_declared_contacts.front_left_foot -and
    [bool]$diagnostic.posthoc_observations.evidence_completion_declared_contacts.front_right_foot -and
    [bool]$diagnostic.posthoc_observations.evidence_completion_declared_contacts.rear_left_foot -and
    [bool]$diagnostic.posthoc_observations.evidence_completion_declared_contacts.rear_right_foot -and
    -not [bool]$diagnostic.posthoc_observations.terminal_declared_contacts.front_left_foot -and
    [bool]$diagnostic.posthoc_observations.terminal_declared_contacts.front_right_foot -and
    [bool]$diagnostic.posthoc_observations.terminal_declared_contacts.rear_left_foot -and
    [bool]$diagnostic.posthoc_observations.terminal_declared_contacts.rear_right_foot -and
    [int]$diagnostic.posthoc_observations.last_contact_semantic_step_by_contact_id.front_left_foot -eq 2093 -and
    [double]$diagnostic.posthoc_observations.final_contact_site_positions_m.front_left_foot.y -eq
        0.09871939569711685 -and
    -not [bool]$diagnostic.claims.primary_lc1_integrity_restored -and
    -not [bool]$diagnostic.claims.finite_walking_contract_passed -and
    -not [bool]$diagnostic.claims.physical_acceptance_authority
) "$gateId post-hoc reconstruction, terminal failure, or non-claim changed"
$completionMemory = @($diagnostic.posthoc_observations.evidence_completion_limb_memory)
$finalMemory = @($diagnostic.posthoc_observations.final_limb_memory)
Assert-Exact (
    $completionMemory.Count -eq 4 -and
    $finalMemory.Count -eq 4 -and
    (@($completionMemory | ForEach-Object { [int]$_.gait_step }) -join "|") -ceq
        "1912|1912|1912|1912" -and
    (@($finalMemory | ForEach-Object { [int]$_.gait_step }) -join "|") -ceq
        "1912|1912|1912|1912"
) "$gateId completed gait memory was not held through the terminal window"
$completionFrontLeftKnee = @(
    $diagnostic.posthoc_observations.evidence_completion_front_left_base_commands |
    Where-Object { [string]$_.actuator_id -ceq "front_left_knee_motor" }
)
$finalFrontLeftKnee = @(
    $diagnostic.posthoc_observations.final_front_left_base_commands |
    Where-Object { [string]$_.actuator_id -ceq "front_left_knee_motor" }
)
Assert-Exact (
    $completionFrontLeftKnee.Count -eq 1 -and
    $finalFrontLeftKnee.Count -eq 1 -and
    [double]$completionFrontLeftKnee[0].clamped_target_position_rad -eq 1.1 -and
    [double]$finalFrontLeftKnee[0].clamped_target_position_rad -eq 1.1
) "$gateId terminal raised-front-left reference witness changed"

$temporaryRoot = [System.IO.Path]::GetFullPath(
    (Join-Path ([System.IO.Path]::GetTempPath()) (
        "sporespore_lc1_closure_" + [Guid]::NewGuid().ToString("N")
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
$recomputedPath = Join-Path $temporaryRoot "posthoc_diagnostic_v2.json"
$reportPath = Join-Path $evidenceRoot "report.json"
try {
    Push-Location -LiteralPath $sdkRoot
    try {
        $recomputedLines = @(
            & cargo run `
                --quiet `
                --package sporespore-rapier-adapter `
                --bin bw19v_velocity_only_long_horizon_lc1_posthoc `
                --offline `
                -- `
                --report $reportPath `
                --output $recomputedPath
        )
        Assert-Exact (
            $LASTEXITCODE -eq 0
        ) "$gateId corrected post-hoc evaluator failed"
    } finally {
        Pop-Location
    }
    Assert-Exact (
        (Test-Path -LiteralPath $recomputedPath -PathType Leaf) -and
        (Get-RawSha256 $recomputedPath) -ceq
            [string]$closure.retained_evidence.posthoc_diagnostic_v2.raw_sha256
    ) "$gateId corrected post-hoc diagnostic is not deterministic"
} finally {
    if (Test-Path -LiteralPath $temporaryRoot -PathType Container) {
        [System.IO.Directory]::Delete($temporaryRoot, $true)
    }
}

$supervisorPath = Join-Path (
    $sdkRoot
) "run_rapier_c6_bw19v_velocity_only_long_horizon_lc1.ps1"
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

Write-Host (
    "C6_RAP_V4_LC1_CLOSURE_PASS primary_ok=False worlds=1 " +
    "trace_steps=2992 posthoc_failures=TERMINAL_STANCE " +
    "final_advance_m=1.8938268423080444 torso_contacts=0 " +
    "walking_authority=False same_identity_rerun=False"
)
