#requires -Version 7.0

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$sdkRoot = Join-Path $repoRoot "sdk"
$mujocoRoot = Join-Path $sdkRoot "adapters\mujoco"
$python = Join-Path $mujocoRoot ".venv\Scripts\python.exe"
$campaignId = "C6-MUJOCO-BW19V-SELECTED-POLICY-WALKING-MV3"
$gateId = "C6-MJC-BW19V-MV3"
$sourceCommit = "a52af71de64f43b8d742d17d4cf9905b778a134f"
$sourceTree = "dac3b2f5e25b1636063d4287b65ebfd7ac7ba36e"
$closurePath = Join-Path $sdkRoot (
    "mujoco_c6_bw19v_selected_policy_walking_mv3_closure.json"
)
$posthocPath = Join-Path $mujocoRoot (
    "sporespore_mujoco_adapter\selected_policy_walking_mv3_posthoc.py"
)
$runnerPath = Join-Path $sdkRoot (
    "run_mujoco_c6_bw19v_selected_policy_walking_mv3.ps1"
)
$attestationHelperPath = Join-Path $sdkRoot (
    "locomotion_full_conformance_attestation.ps1"
)
$operationLockHelperPath = Join-Path $sdkRoot "locomotion_operation_lock.ps1"
$godot = (
    "C:\Users\Cole\CodeStuff\Misc\Godot\" +
    "Godot_v4.7-stable_mono_win64_console.exe"
)
$attestationPath = [IO.Path]::GetFullPath(
    "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence\" +
    "full-godot-conformance-v2-a52af71-20260803T201218Z\attestation.json"
)
$evidenceRoot = [IO.Path]::GetFullPath(
    "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence\" +
    "c6-mujoco-bw19v-mv3-a52af71"
)

. $operationLockHelperPath
. $attestationHelperPath

function Assert-Exact {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function Get-RawSha256 {
    param([Parameter(Mandatory)][string]$Path)
    return (Get-FileHash -Algorithm SHA256 -LiteralPath $Path).
        Hash.ToLowerInvariant()
}

function Get-EvidenceTreeSha256 {
    param([Parameter(Mandatory)][string]$Root)
    $text = [Text.StringBuilder]::new()
    foreach ($item in @(
        Get-ChildItem -LiteralPath $Root -File | Sort-Object Name
    )) {
        [void]$text.Append($item.Name).
            Append("`t").
            Append($item.Length).
            Append("`t").
            Append((Get-RawSha256 -Path $item.FullName)).
            Append("`n")
    }
    $bytes = [Text.UTF8Encoding]::new($false).GetBytes($text.ToString())
    $sha = [Security.Cryptography.SHA256]::Create()
    try {
        return [Convert]::ToHexString($sha.ComputeHash($bytes)).ToLowerInvariant()
    } finally {
        $sha.Dispose()
    }
}

Assert-Exact (
    (git -C $repoRoot rev-parse --show-toplevel).Trim() -ceq
        $repoRoot.Replace("\", "/")
) "$gateId repository identity mismatch"
Assert-Exact (
    (git -C $repoRoot remote get-url origin).Trim() -ceq
        "https://github.com/Slagathore/sporespore.git"
) "$gateId origin identity mismatch"

$expectedCurrentFiles = [ordered]@{
    "sdk/mujoco_c6_bw19v_selected_policy_walking_mv3_closure.json" =
        "96e9947628794b9ffdcb1d42f5cfc42b44d89f5f53f7c04007dedf694c8fbf8c"
    "sdk/adapters/mujoco/sporespore_mujoco_adapter/selected_policy_walking_mv3_posthoc.py" =
        "c9e8489da59370ffa73a8b45c10443bcae4a47776e569c540cad1c0214950331"
    "sdk/mujoco_c6_bw19v_selected_policy_walking_mv3_preregistration.json" =
        "77aa6696024af4b0bb8e289b798a4460773ff9f85940776bc24503cb88d18726"
    "sdk/adapters/mujoco/sporespore_mujoco_adapter/selected_policy_walking_mv3.py" =
        "a01cc11c5cb89d90b006b2bf05cee66d119722f0bbc7e1749c22671c8be24078"
    "sdk/run_mujoco_c6_bw19v_selected_policy_walking_mv3.ps1" =
        "9df058a96e99aa1af4989bce410edca89eaee08a47d06c16f397ac9114615d3e"
    "tests/test_mujoco_c6_bw19v_selected_policy_walking_mv3_freeze.ps1" =
        "a4921d11db81eac1bde97e7423ef9381a9d3c2b8818fa8e4b4a70ff8a702debe"
    "sdk/mujoco_c6_bw19v_selected_policy_walking_mv2_closure.json" =
        "0ef035bf76ebfc2c2ded74912cd5219f51304ae13086407324a5fbc491fec51c"
}
foreach ($entry in $expectedCurrentFiles.GetEnumerator()) {
    $path = [IO.Path]::GetFullPath((Join-Path $repoRoot ([string]$entry.Key)))
    Assert-Exact (
        (Test-Path -LiteralPath $path -PathType Leaf) -and
        (Get-RawSha256 -Path $path) -ceq [string]$entry.Value
    ) "$gateId closure source changed: $($entry.Key)"
}

$expectedFrozenBlobs = [ordered]@{
    "sdk/mujoco_c6_bw19v_selected_policy_walking_mv3_preregistration.json" =
        "ee202ae83717e3fb5de66eda670a64847248178d"
    "sdk/adapters/mujoco/sporespore_mujoco_adapter/selected_policy_walking_mv3.py" =
        "de8c8ed08dab5a5b731944ecd5239165ac46b074"
    "sdk/run_mujoco_c6_bw19v_selected_policy_walking_mv3.ps1" =
        "ce897a8cd9d08503026aa27a91957c98e913f7ae"
    "tests/test_mujoco_c6_bw19v_selected_policy_walking_mv3_freeze.ps1" =
        "8f6975d7b201dcfdd5e5ee954122271502972951"
    "sdk/adapters/mujoco/sporespore_mujoco_adapter/selected_policy_development.py" =
        "4e044c95e31342675699ae82d8904ab284cf3d6f"
    "sdk/mujoco_c6_bw19v_selected_policy_walking_mv2_closure.json" =
        "1ff23e6bd344a3c948e588dd6fe15697baac589a"
}
& git -C $repoRoot cat-file -e "$sourceCommit`^{commit}"
Assert-Exact ($LASTEXITCODE -eq 0) "$gateId frozen source commit is unavailable"
Assert-Exact (
    (git -C $repoRoot rev-parse "$sourceCommit`^{tree}").Trim() -ceq $sourceTree
) "$gateId frozen source tree changed"
foreach ($entry in $expectedFrozenBlobs.GetEnumerator()) {
    Assert-Exact (
        (git -C $repoRoot rev-parse "$sourceCommit`:$($entry.Key)").Trim() -ceq
            [string]$entry.Value
    ) "$gateId frozen Git blob changed: $($entry.Key)"
}

$closure = Get-Content -Raw -LiteralPath $closurePath |
    ConvertFrom-Json -AsHashtable -Depth 100
Assert-Exact (
    [string]$closure.status -ceq
        "closed_consumed_complete_valid_negative_combined_walking_and_integrity_contract" -and
    [string]$closure.campaign_id -ceq $campaignId -and
    [string]$closure.gate_id -ceq $gateId -and
    [string]$closure.attempt_id -ceq "b864b875e99f492398f76317605474f4" -and
    [string]$closure.experiment_source.commit -ceq $sourceCommit -and
    [string]$closure.experiment_source.tree_git_oid -ceq $sourceTree -and
    [bool]$closure.frozen_primary_result.scientific_negative_for_declared_combined_contract -and
    -not [bool]$closure.frozen_primary_result.trace_projection_integrity_passed -and
    -not [bool]$closure.frozen_primary_result.terminal_four_contact_stance -and
    -not [bool]$closure.technical_disposition.walking_acceptance -and
    -not [bool]$closure.technical_disposition.mujoco_selected_policy_physical_c6 -and
    -not [bool]$closure.technical_disposition.cross_engine_selected_policy_equivalence -and
    -not [bool]$closure.technical_disposition.release_authorized -and
    -not [bool]$closure.technical_disposition.physical_acceptance_authority -and
    -not [bool]$closure.technical_disposition.same_identity_rerun_allowed
) "$gateId closure identity or claim boundary changed"

Assert-Exact (
    (Test-Path -LiteralPath $evidenceRoot -PathType Container) -and
    @($closure.retained_evidence.files).Count -eq 7 -and
    @(Get-ChildItem -LiteralPath $evidenceRoot -File).Count -eq 7
) "$gateId retained evidence file set changed"
foreach ($file in @($closure.retained_evidence.files)) {
    $path = Join-Path $evidenceRoot ([string]$file.name)
    Assert-Exact (
        (Test-Path -LiteralPath $path -PathType Leaf) -and
        (Get-Item -LiteralPath $path).Length -eq [long]$file.byte_length -and
        (Get-RawSha256 -Path $path) -ceq [string]$file.raw_sha256
    ) "$gateId retained evidence changed: $($file.name)"
}
Assert-Exact (
    (Get-EvidenceTreeSha256 -Root $evidenceRoot) -ceq
        [string]$closure.retained_evidence.tree_sha256 -and
    [string]$closure.retained_evidence.tree_sha256 -ceq
        "3d0fa8399aa70b7b261b29f2e27905bab01364f03782970acf051ffbd80f46d1"
) "$gateId retained evidence tree changed"

$attempt = Get-Content -Raw -LiteralPath (Join-Path $evidenceRoot "attempt.json") |
    ConvertFrom-Json -AsHashtable -Depth 64
$completion = Get-Content -Raw -LiteralPath (
    Join-Path $evidenceRoot "completion.json"
) | ConvertFrom-Json -AsHashtable -Depth 64
$preflight = Get-Content -Raw -LiteralPath (
    Join-Path $evidenceRoot "preflight.json"
) | ConvertFrom-Json -AsHashtable -Depth 100
$report = Get-Content -Raw -LiteralPath (Join-Path $evidenceRoot "report.json") |
    ConvertFrom-Json -AsHashtable -Depth 100
$diagnostic = Get-Content -Raw -LiteralPath (
    Join-Path $evidenceRoot "posthoc_diagnostic_v1.json"
) | ConvertFrom-Json -AsHashtable -Depth 100

Assert-Exact (
    [string]$attempt.attempt_id -ceq [string]$closure.attempt_id -and
    [string]$attempt.source_commit -ceq $sourceCommit -and
    [string]$attempt.source_origin_main -ceq $sourceCommit -and
    [string]$attempt.source_live_github_main -ceq $sourceCommit -and
    [bool]$attempt.operation_lock.acquired -and
    [string]$attempt.operation_lock.role -ceq "physical" -and
    [string]$completion.attempt_id -ceq [string]$closure.attempt_id -and
    [bool]$completion.process_launched -and
    [int]$completion.process_exit_code -eq 1 -and
    [bool]$completion.report_present -and
    [string]$completion.report_raw_sha256 -ceq
        "sha256:e23cb1e07e7aef4288a9a3e75416b79f537794a822fc87a5ff27720204393211" -and
    [bool]$completion.operation_lock.acquired -and
    [string]$completion.operation_lock.role -ceq "physical"
) "$gateId attempt or completion receipt changed"
Assert-Exact (
    [bool]$preflight.ok -and
    [int]$preflight.negative_control_count -eq 31 -and
    [int]$preflight.synthetic_report_negative_control_count -eq 27 -and
    [int]$preflight.real_dynamic_library_negative_control_count -eq 2 -and
    [int]$preflight.compiled_morphology_report_assembly_negative_control_count -eq 2 -and
    [int]$preflight.world_build_count -eq 0 -and
    -not [bool]$preflight.physics_state_modified
) "$gateId retained preflight changed"

$expectedFailures = @(
    "C6_MJC_BW19V_MV3_RECEIPT_PROJECTION",
    "C6_MJC_BW19V_MV3_LIMB_MEMORY_ORDER",
    "C6_MJC_BW19V_MV3_METRIC_RECOMPUTE:evidence_forward_displacement_m",
    "C6_MJC_BW19V_MV3_EVIDENCE_ADVANCE",
    "C6_MJC_BW19V_MV3_SCHEDULE:evidence_limits_reached",
    "C6_MJC_BW19V_MV3_SCHEDULE:evidence_completion_semantic_step",
    "C6_MJC_BW19V_MV3_SCHEDULE:required_post_evidence_steps_completed",
    "C6_MJC_BW19V_MV3_EVIDENCE_DEADLINE",
    "C6_MJC_BW19V_MV3_POST_EVIDENCE_HORIZON",
    "C6_MJC_BW19V_MV3_TERMINAL_STANCE"
)
Assert-Exact (
    [string]$report.campaign_id -ceq $campaignId -and
    [string]$report.gate_id -ceq $gateId -and
    [string]$report.source_commit -ceq $sourceCommit -and
    -not [bool]$report.ok -and
    (@($report.gate_failures) | ConvertTo-Json -Compress) -ceq
        ($expectedFailures | ConvertTo-Json -Compress) -and
    [int]$report.world_attempt_count -eq 1 -and
    [int]$report.world_build_count -eq 1 -and
    [int]$report.world_reset_count -eq 0 -and
    [int]$report.trace_step_count -eq 2992 -and
    @($report.ordered_trace).Count -eq 2992 -and
    [int]$report.base_command_count -eq 23936 -and
    [int]$report.bounded_residual_command_count -eq 23936 -and
    [int]$report.canonical_command_count -eq 23936 -and
    [int]$report.host_command_count -eq 23936 -and
    [int]$report.native_application_count -eq 23936 -and
    [int]$report.nonzero_bounded_residual_count -eq 12813 -and
    [int]$report.nonzero_effective_host_residual_count -eq 12673 -and
    -not [bool]$report.terminal_four_contact_stance -and
    [int]$report.torso_ground_contact_step_count -eq 0 -and
    -not [bool]$report.claim_boundary.exact_s169_mujoco_bw19v_mv3_walking -and
    -not [bool]$report.claim_boundary.cross_engine_selected_policy_equivalence -and
    -not [bool]$report.claim_boundary.release_authorized -and
    -not [bool]$report.claim_boundary.physical_acceptance_authority
) "$gateId primary report or negative decision changed"

$finalContacts = $report.ordered_trace[-1].post_step_snapshot.
    ordered_declared_contacts
Assert-Exact (
    -not [bool]$finalContacts.front_left_foot -and
    [bool]$finalContacts.front_right_foot -and
    [bool]$finalContacts.rear_left_foot -and
    [bool]$finalContacts.rear_right_foot -and
    [double]$report.metrics.evidence_forward_displacement_m -eq
        1.3995530921000026 -and
    [double]$report.metrics.final_forward_displacement_m -eq
        1.8059354058929902 -and
    [double]$report.metrics.final_lateral_displacement_m -eq
        -0.007354776036748467 -and
    [double]$report.metrics.final_yaw_drift_rad -eq
        -0.04314400132495722 -and
    [double]$report.metrics.maximum_tilt_rad -eq
        0.11902485175352155 -and
    [double]$report.metrics.minimum_torso_height_m -eq
        0.4239894132151208
) "$gateId retained physical observations changed"

Assert-Exact (
    -not [bool]$diagnostic.primary_report_ok -and
    [bool]$diagnostic.replay_matches_primary_failures -and
    (@($diagnostic.replayed_evaluator_failures) | ConvertTo-Json -Compress) -ceq
        ($expectedFailures | ConvertTo-Json -Compress) -and
    [int]$diagnostic.receipt_projection_diagnosis.row_count -eq 2992 -and
    [int]$diagnostic.receipt_projection_diagnosis.
        top_level_source_policy_id_match_count -eq 0 -and
    [int]$diagnostic.receipt_projection_diagnosis.
        nested_receipt_policy_id_match_count -eq 2992 -and
    [int]$diagnostic.receipt_projection_diagnosis.
        all_non_policy_projection_fields_match_count -eq 2992 -and
    [int]$diagnostic.limb_memory_order_diagnosis.order_mismatch_row_count -eq
        2992 -and
    [int]$diagnostic.limb_memory_order_diagnosis.
        exact_membership_match_row_count -eq 2992 -and
    [int]$diagnostic.order_normalized_development_only_reconstruction.
        evidence_completion_semantic_step -eq 1936 -and
    [bool]$diagnostic.order_normalized_development_only_reconstruction.
        physical_gate_observations.evidence_advance_passed -and
    -not [bool]$diagnostic.order_normalized_development_only_reconstruction.
        physical_gate_observations.terminal_four_contact_stance_passed -and
    [bool]$diagnostic.order_normalized_development_only_reconstruction.
        development_observation_only -and
    -not [bool]$diagnostic.scientific_boundaries.
        accepted_exact_s169_mujoco_walking -and
    -not [bool]$diagnostic.scientific_boundaries.same_identity_rerun_allowed
) "$gateId deterministic diagnostic changed"

$temporaryDiagnostic = Join-Path (
    [IO.Path]::GetTempPath()
) "sporespore-mv3-posthoc-$([guid]::NewGuid().ToString('N')).json"
try {
    Push-Location -LiteralPath $mujocoRoot
    try {
        & $python `
            -m sporespore_mujoco_adapter.selected_policy_walking_mv3_posthoc `
            --report (Join-Path $evidenceRoot "report.json") `
            --diagnostic $temporaryDiagnostic
        Assert-Exact ($LASTEXITCODE -eq 0) "$gateId post-hoc evaluator failed"
    } finally {
        Pop-Location
    }
    Assert-Exact (
        (Get-RawSha256 -Path $temporaryDiagnostic) -ceq
            "3fd8cadce2623b875108750e826d4b67d4b894b260673a2b1bf40fe747589a02"
    ) "$gateId post-hoc evaluator is not byte deterministic"
} finally {
    if (Test-Path -LiteralPath $temporaryDiagnostic -PathType Leaf) {
        Remove-Item -LiteralPath $temporaryDiagnostic -Force
    }
}

Assert-Exact (
    (Test-Path -LiteralPath $attestationPath -PathType Leaf) -and
    (Get-Item -LiteralPath $attestationPath).Length -eq 3563 -and
    (Get-RawSha256 -Path $attestationPath) -ceq
        "846578bc8f0438f162587445b3c23d4a42b95c4a384259cb50c19ad947532d9c"
) "$gateId exact-source attestation changed"
$attestation = Get-Content -Raw -LiteralPath $attestationPath |
    ConvertFrom-Json -AsHashtable -Depth 64
$trueAttestationClaims = @(
    $attestation.claims.GetEnumerator() | Where-Object { [bool]$_.Value }
)
Assert-Exact (
    [string]$attestation.schema_version -ceq
        "sporespore_full_godot_conformance_attestation_v2" -and
    [string]$attestation.status -ceq "full_godot_conformance_passed" -and
    -not [bool]$attestation.test_only -and
    [string]$attestation.source.commit -ceq $sourceCommit -and
    [string]$attestation.source.tree_git_oid -ceq $sourceTree -and
    [string]$attestation.source.origin_main -ceq $sourceCommit -and
    [string]$attestation.source.live_github_main -ceq $sourceCommit -and
    [bool]$attestation.source.clean_pushed_live -and
    [bool]$attestation.conformance.passed -and
    -not [bool]$attestation.conformance.skip_godot -and
    [bool]$attestation.conformance.godot_including -and
    [double]$attestation.conformance.duration_seconds -eq 1695.4232336 -and
    -not [bool]$attestation.conformance.one_shot_physical_campaign_executed -and
    [bool]$attestation.operation_lock.acquired -and
    [string]$attestation.operation_lock.role -ceq "conformance" -and
    [string]$attestation.godot.version -ceq
        "4.7.stable.mono.official.5b4e0cb0f" -and
    $trueAttestationClaims.Count -eq 0
) "$gateId exact-source attestation no longer verifies"

$rootsBefore = @(
    Get-ChildItem `
        -LiteralPath (Split-Path -Parent $evidenceRoot) `
        -Directory `
        -Filter "c6-mujoco-bw19v-mv3-*" `
        -ErrorAction SilentlyContinue |
        Sort-Object FullName |
        ForEach-Object { $_.FullName }
)
$forbiddenRoot = [IO.Path]::GetFullPath(
    "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence\" +
    "c6-mujoco-bw19v-mv3-forbidden-rerun"
)
$rerunExit = 0
$rerunOutput = ""
try {
    $rerunOutput = @(
        & $runnerPath `
            -RunPhysical `
            -OutputRoot $forbiddenRoot `
            -FullConformanceAttestation $attestationPath 2>&1
    ) | Out-String
    $rerunExit = $LASTEXITCODE
} catch {
    $rerunExit = 1
    $rerunOutput = $_ | Out-String
}
$rootsAfter = @(
    Get-ChildItem `
        -LiteralPath (Split-Path -Parent $evidenceRoot) `
        -Directory `
        -Filter "c6-mujoco-bw19v-mv3-*" `
        -ErrorAction SilentlyContinue |
        Sort-Object FullName |
        ForEach-Object { $_.FullName }
)
Assert-Exact (
    $rerunExit -ne 0 -and
    $rerunOutput.Contains(
        "$gateId is closed and may not open another world",
        [StringComparison]::Ordinal
    ) -and
    ($rootsBefore | ConvertTo-Json -Compress) -ceq
        ($rootsAfter | ConvertTo-Json -Compress) -and
    -not (Test-Path -LiteralPath $forbiddenRoot)
) "$gateId same-identity physical rerun was not refused before mutation"

Write-Host (
    "C6_MJC_BW19V_MV3_CLOSURE_PASS primary_ok=False " +
    "valid_negative=True worlds=1 trace_steps=2992 " +
    "receipt_projection=0/2992 nested_policy=2992/2992 " +
    "memory_order=0/2992 membership=2992/2992 " +
    "advance=1.399553 terminal_contacts=3/4 walking=False " +
    "same_identity_rerun=False"
)
