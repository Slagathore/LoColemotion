$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = [System.IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$sdkRoot = Join-Path $repoRoot "sdk"
$closurePath = Join-Path (
    $sdkRoot
) "rapier_c6_bw19v_velocity_only_pose_hold_restoration_ph1_closure.json"
$expectedClosureRawSha256 = (
    "e2fd42545d59908db69f9fe34a18453afafe4273a02618be0b531f6443e040db"
)
$campaignId = "C6-RAPIER-BW19V-VELOCITY-ONLY-POSE-HOLD-RESTORATION-PH1"
$gateId = "C6-RAP-BW19V-V4-PH1"
$physicalSourceCommit = "91c528e0d0eb494a7ff1d9dc9250ef1af6963249"
$posthocSourceCommit = "04145c9cf0e24c3510da8936a1013c908fbcb3b5"
$posthocSourceGitBlobOid = "9a7bbd7f3b0eadbd949c2819632c40be1f37cbf8"

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
$closure = Get-Content -Raw -LiteralPath $closurePath | ConvertFrom-Json -Depth 64
Assert-Exact (
    [string]$closure.campaign_id -ceq $campaignId -and
    [string]$closure.gate_id -ceq $gateId -and
    [string]$closure.status -ceq
        "closed_complete_valid_positive_exact_s169_pose_hold_restoration_and_finite_walking_contract" -and
    [string]$closure.physical_source_commit -ceq $physicalSourceCommit -and
    -not [bool]$closure.same_identity_rerun_allowed -and
    -not [bool]$closure.threshold_horizon_schedule_report_or_world_rewrite_allowed -and
    [int]$closure.physical_attempt.process_launch_count -eq 1 -and
    [string]$closure.physical_attempt.attempt_id -ceq
        "205904c6b7794201a4a436bb47b6068a" -and
    [int]$closure.physical_attempt.process_exit_code -eq 0 -and
    [int]$closure.physical_attempt.world_attempt_count -eq 1 -and
    [int]$closure.physical_attempt.world_build_count -eq 1 -and
    [int]$closure.physical_attempt.world_reset_count -eq 0 -and
    [int]$closure.physical_attempt.trace_step_count -eq 3172 -and
    [int]$closure.physical_attempt.command_count_per_layer -eq 25376 -and
    [bool]$closure.physical_attempt.retained_primary_report_ok -and
    [bool]$closure.physical_attempt.retained_primary_report_is_complete_valid_positive -and
    @($closure.physical_attempt.gate_failure_codes).Count -eq 0 -and
    [bool]$closure.posthoc_diagnostic_result.diagnostic_complete -and
    [bool]$closure.posthoc_diagnostic_result.retained_primary_report_ok -and
    [bool]$closure.posthoc_diagnostic_result.retained_primary_report_is_complete_valid_positive -and
    @($closure.posthoc_diagnostic_result.frozen_evaluator_recomputed_failure_codes).Count -eq 0 -and
    [bool]$closure.posthoc_diagnostic_result.all_integrity_counters_zero -and
    [bool]$closure.posthoc_diagnostic_result.valid_primary_ph1_positive_result -and
    [bool]$closure.posthoc_diagnostic_result.pose_hold_restoration_gate_passed -and
    [bool]$closure.posthoc_diagnostic_result.walking_safety_contract_passed -and
    [bool]$closure.posthoc_diagnostic_result.finite_walking_contract_passed -and
    -not [bool]$closure.posthoc_diagnostic_result.physical_acceptance_authority -and
    [bool]$closure.claims.valid_primary_ph1_positive_result -and
    [bool]$closure.claims.exact_s169_rapier_v4_pose_hold_restoration_technical_commissioning -and
    [bool]$closure.claims.finite_single_body_walking_contract_passed -and
    -not [bool]$closure.claims.rapier_release_selected_policy_physical_c6 -and
    -not [bool]$closure.claims.rapier_locomotion_acceptance -and
    -not [bool]$closure.claims.independent_validation -and
    -not [bool]$closure.claims.population_inference -and
    -not [bool]$closure.claims.cross_engine_selected_policy_equivalence -and
    -not [bool]$closure.claims.arbitrary_quadruped_coverage -and
    -not [bool]$closure.claims.release_authorized -and
    -not [bool]$closure.claims.physical_acceptance_authority -and
    -not [bool]$closure.claims.completed_engine_neutral_sdk
) "$gateId closure disposition, positive result, or claim boundary changed"

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

$expectedEvidencePrefix = [System.IO.Path]::GetFullPath(
    (Join-Path (Split-Path -Parent $repoRoot) "SporeSpore_Evidence")
).TrimEnd(
    [System.IO.Path]::DirectorySeparatorChar,
    [System.IO.Path]::AltDirectorySeparatorChar
) + [System.IO.Path]::DirectorySeparatorChar
$attestationPath = [System.IO.Path]::GetFullPath(
    [string]$closure.full_conformance_attestation.path
)
Assert-Exact (
    $attestationPath.StartsWith(
        $expectedEvidencePrefix,
        [StringComparison]::OrdinalIgnoreCase
    ) -and
    (Test-Path -LiteralPath $attestationPath -PathType Leaf) -and
    (Get-Item -LiteralPath $attestationPath).Length -eq
        [long]$closure.full_conformance_attestation.byte_length -and
    (Get-RawSha256 $attestationPath) -ceq
        [string]$closure.full_conformance_attestation.raw_sha256
) "$gateId full-conformance attestation changed or escaped durable evidence"
$attestation = Get-Content -Raw -LiteralPath $attestationPath |
    ConvertFrom-Json -Depth 64
$trueAttestationClaims = @(
    $attestation.claims.PSObject.Properties |
        Where-Object { [bool]$_.Value }
)
Assert-Exact (
    [string]$attestation.schema_version -ceq
        "sporespore_full_godot_conformance_attestation_v2" -and
    [string]$attestation.status -ceq "full_godot_conformance_passed" -and
    -not [bool]$attestation.test_only -and
    [string]$attestation.source.commit -ceq $physicalSourceCommit -and
    [string]$attestation.source.origin_main -ceq $physicalSourceCommit -and
    [string]$attestation.source.live_github_main -ceq $physicalSourceCommit -and
    [bool]$attestation.source.clean_pushed_live -and
    -not [bool]$attestation.conformance.skip_godot -and
    [bool]$attestation.conformance.godot_including -and
    -not [bool]$attestation.conformance.one_shot_physical_campaign_executed -and
    $trueAttestationClaims.Count -eq 0
) "$gateId attestation identity, full-Godot gate, or claim boundary changed"

$evidenceRoot = [System.IO.Path]::GetFullPath(
    [string]$closure.retained_evidence.root
)
Assert-Exact (
    $evidenceRoot.StartsWith(
        $expectedEvidencePrefix,
        [StringComparison]::OrdinalIgnoreCase
    )
) "$gateId evidence root escaped SporeSpore_Evidence"
$evidenceEntryNames = @(
    "attempt",
    "completion",
    "posthoc_diagnostic_v1",
    "preflight",
    "primary_report",
    "stderr",
    "stdout"
)
foreach ($entryName in $evidenceEntryNames) {
    $entry = $closure.retained_evidence.$entryName
    $path = Join-Path $evidenceRoot ([string]$entry.path)
    Assert-Exact (
        (Test-Path -LiteralPath $path -PathType Leaf) -and
        (Get-RawSha256 $path) -ceq [string]$entry.raw_sha256 -and
        (Get-Item -LiteralPath $path).Length -eq [long]$entry.byte_length
    ) "$gateId retained evidence changed: $path"
}
$treeRows = @(
    Get-ChildItem -LiteralPath $evidenceRoot -File -Recurse |
        ForEach-Object {
            $relative = [System.IO.Path]::GetRelativePath(
                $evidenceRoot,
                $_.FullName
            ).Replace("\", "/")
            $hash = Get-RawSha256 $_.FullName
            [pscustomobject]@{
                RelativePath = $relative
                Line = "$relative`t$($_.Length)`t$hash`n"
            }
        } |
        Sort-Object RelativePath
)
$treeManifest = ($treeRows.Line -join "")
$treeBytes = [System.Text.Encoding]::UTF8.GetBytes($treeManifest)
$treeSha256 = [Convert]::ToHexString(
    [System.Security.Cryptography.SHA256]::HashData($treeBytes)
).ToLowerInvariant()
Assert-Exact (
    $treeRows.Count -eq $evidenceEntryNames.Count -and
    $treeSha256 -ceq [string]$closure.retained_evidence.tree_sha256
) "$gateId retained evidence tree changed"

$attempt = Get-Content -Raw -LiteralPath (
    Join-Path $evidenceRoot "attempt.json"
) | ConvertFrom-Json -Depth 64
$completion = Get-Content -Raw -LiteralPath (
    Join-Path $evidenceRoot "completion.json"
) | ConvertFrom-Json -Depth 64
$preflight = Get-Content -Raw -LiteralPath (
    Join-Path $evidenceRoot "preflight.json"
) | ConvertFrom-Json -Depth 64
$diagnostic = Get-Content -Raw -LiteralPath (
    Join-Path $evidenceRoot "posthoc_diagnostic_v1.json"
) | ConvertFrom-Json -Depth 64
Assert-Exact (
    [string]$attempt.status -ceq
        "physical_process_launch_reserved_identity_consumed" -and
    [string]$attempt.attempt_id -ceq
        [string]$closure.physical_attempt.attempt_id -and
    [string]$attempt.source_commit -ceq $physicalSourceCommit -and
    [string]$attempt.source_origin_main -ceq $physicalSourceCommit -and
    [string]$attempt.source_live_github_main -ceq $physicalSourceCommit -and
    [string]$attempt.full_conformance_attestation_raw_sha256 -ceq
        ("sha256:" + [string]$closure.full_conformance_attestation.raw_sha256) -and
    [string]$attempt.full_conformance_attestation_source_commit -ceq
        $physicalSourceCommit -and
    [string]$attempt.declared_restoration_policy_id -ceq
        "sporespore_contact_state_gated_pose_hold_heading_preserving_vertical_search_v1" -and
    [int]$attempt.declared_world_count -eq 1 -and
    [int]$attempt.declared_controller_steps -eq 3172 -and
    [int]$attempt.declared_required_consecutive_all_four_contact_steps -eq 360 -and
    -not [bool]$attempt.same_identity_rerun_allowed -and
    [string]$completion.status -ceq "physical_process_exited_with_report" -and
    [string]$completion.source_commit -ceq $physicalSourceCommit -and
    [int]$completion.process_exit_code -eq 0 -and
    [bool]$completion.physical_process_launched -and
    [bool]$completion.report_retained -and
    [string]$completion.report_raw_sha256 -ceq
        ("sha256:" + [string]$closure.retained_evidence.primary_report.raw_sha256) -and
    -not [bool]$completion.same_identity_rerun_allowed -and
    [bool]$preflight.ok -and
    [int]$preflight.negative_control_count -eq 33 -and
    [bool]$preflight.all_negative_controls_rejected -and
    [int]$preflight.world_build_count -eq 0 -and
    -not [bool]$preflight.physical_acceptance_authority
) "$gateId attempt, completion, or preflight receipt changed"

$phaseKey = @(
    $diagnostic.integrity_reconstruction.phase_summaries |
        ForEach-Object {
            "$($_.phase):$($_.count):$($_.first_step):$($_.last_step)"
        }
) -join "|"
Assert-Exact (
    [bool]$diagnostic.ok -and
    [string]$diagnostic.schema_version -ceq
        "sporespore_rapier_c6_bw19v_velocity_only_ph1_posthoc_diagnostic_v1" -and
    [string]$diagnostic.physical_source_commit -ceq $physicalSourceCommit -and
    [bool]$diagnostic.retained_primary_report_ok -and
    [bool]$diagnostic.retained_primary_report_is_complete_valid_positive -and
    @($diagnostic.original_primary_failure_codes).Count -eq 0 -and
    @($diagnostic.frozen_evaluator_recomputed_failure_codes).Count -eq 0 -and
    [bool]$diagnostic.integrity_reconstruction.complete_trace -and
    [int]$diagnostic.integrity_reconstruction.trace_step_count -eq 3172 -and
    [int]$diagnostic.integrity_reconstruction.command_count_per_layer -eq 25376 -and
    [bool]$diagnostic.integrity_reconstruction.all_integrity_counters_zero -and
    $phaseKey -ceq
        "clocked_walking:472:0:471|evidence_walking:1620:472:2091|terminal_acquisition:360:2092:2451|terminal_hold:720:2452:3171" -and
    [int]$diagnostic.pose_hold_restoration_result.activation_semantic_step -eq 2092 -and
    [int]$diagnostic.pose_hold_restoration_result.first_four_contact_acquisition_semantic_step -eq 2092 -and
    [int]$diagnostic.pose_hold_restoration_result.consecutive_four_contact_completion_semantic_step -eq 2451 -and
    [int]$diagnostic.pose_hold_restoration_result.required_consecutive_all_four_contact_steps -eq 360 -and
    [int]$diagnostic.pose_hold_restoration_result.maximum_consecutive_four_contact_steps -eq 1080 -and
    [bool]$diagnostic.pose_hold_restoration_result.required_consecutive_hold_completed -and
    [bool]$diagnostic.pose_hold_restoration_result.terminal_four_contact_stance -and
    [bool]$diagnostic.pose_hold_restoration_result.pose_hold_restoration_gate_passed -and
    [double]$diagnostic.walking_result.evidence_forward_displacement_m -eq
        1.4770498275756836 -and
    [double]$diagnostic.walking_result.final_forward_displacement_m -eq
        1.872812032699585 -and
    [double]$diagnostic.walking_result.final_lateral_displacement_m -eq
        0.00997044239193201 -and
    [double]$diagnostic.walking_result.final_yaw_drift_rad -eq
        0.0038630388055049254 -and
    [double]$diagnostic.walking_result.maximum_tilt_rad -eq
        0.12280438840389252 -and
    [double]$diagnostic.walking_result.minimum_torso_height_m -eq
        0.4231954514980316 -and
    [int]$diagnostic.walking_result.torso_ground_contact_step_count -eq 0 -and
    [int]$diagnostic.walking_result.diagnostic_event_count -eq 0 -and
    [bool]$diagnostic.walking_result.walking_safety_contract_passed -and
    -not [bool]$diagnostic.bounded_interpretation.population_or_release_inference_allowed -and
    [bool]$diagnostic.claims.valid_primary_ph1_positive_result -and
    [bool]$diagnostic.claims.exact_s169_rapier_v4_pose_hold_restoration_technical_commissioning -and
    [bool]$diagnostic.claims.finite_single_body_walking_contract_passed -and
    -not [bool]$diagnostic.claims.rapier_release_selected_policy_physical_c6 -and
    -not [bool]$diagnostic.claims.independent_validation -and
    -not [bool]$diagnostic.claims.cross_engine_selected_policy_equivalence -and
    -not [bool]$diagnostic.claims.release_authorized -and
    -not [bool]$diagnostic.claims.physical_acceptance_authority
) "$gateId post-hoc reconstruction, positive result, or non-claim changed"

$temporaryRoot = [System.IO.Path]::GetFullPath(
    (Join-Path ([System.IO.Path]::GetTempPath()) (
        "sporespore_ph1_closure_" + [Guid]::NewGuid().ToString("N")
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
                --bin bw19v_velocity_only_pose_hold_restoration_ph1_posthoc `
                --offline `
                -- `
                --report $reportPath `
                --output $recomputedPath
        )
        Assert-Exact (
            $LASTEXITCODE -eq 0 -and
            ($recomputedLines -join "`n").Contains(
                "C6_RAP_V4_PH1_POSTHOC_PASS"
            )
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
) "run_rapier_c6_bw19v_velocity_only_pose_hold_restoration_ph1.ps1"
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
$global:LASTEXITCODE = 0

Write-Host (
    "C6_RAP_V4_PH1_CLOSURE_PASS primary_ok=True valid_positive=True " +
    "worlds=1 trace_steps=3172 restoration=True hold=360/1080 " +
    "advance=1.477050 yaw=0.003863 tilt=0.122804 ground_steps=0 " +
    "walking_contract=True selected_policy_c6=False same_identity_rerun=False"
)
