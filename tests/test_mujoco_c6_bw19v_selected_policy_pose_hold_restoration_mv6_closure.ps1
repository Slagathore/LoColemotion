#requires -Version 7.0

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$sdkRoot = Join-Path $repoRoot "sdk"
$mujocoRoot = Join-Path $sdkRoot "adapters\mujoco"
$python = Join-Path $mujocoRoot ".venv\Scripts\python.exe"
$campaignId = "C6-MUJOCO-BW19V-SELECTED-POLICY-POSE-HOLD-RESTORATION-MV6"
$gateId = "C6-MJC-BW19V-MV6"
$sourceCommit = "3ad4d5fb1920fef863330d39200007f09fed7b9d"
$sourceTree = "68346ead077bd4531aa6b976d9c4e8d281dcaa63"
$closurePath = Join-Path $sdkRoot (
    "mujoco_c6_bw19v_selected_policy_pose_hold_restoration_mv6_closure.json"
)
$runnerPath = Join-Path $sdkRoot (
    "run_mujoco_c6_bw19v_selected_policy_pose_hold_restoration_mv6.ps1"
)
$expectedClosureSha256 = (
    "5da3675d848c1d127419c43f009fb430c4f02abd2a55da730ea70fca6d3cee09"
)
$evidenceRoot = [IO.Path]::GetFullPath(
    "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence\" +
    "c6-mujoco-bw19v-mv6-3ad4d5f"
)
$attestationPath = [IO.Path]::GetFullPath(
    "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence\" +
    "full-godot-conformance-v2-3ad4d5fb-20260804T030317Z\attestation.json"
)
$reportPath = Join-Path $evidenceRoot "report.json"

function Assert-Exact {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function Assert-Close {
    param(
        [double]$Actual,
        [double]$Expected,
        [string]$Message,
        [double]$Tolerance = 1e-12
    )
    if ([Math]::Abs($Actual - $Expected) -gt $Tolerance) { throw $Message }
}

function Get-RawSha256 {
    param([Parameter(Mandatory)][string]$Path)
    return (Get-FileHash -Algorithm SHA256 -LiteralPath $Path).
        Hash.ToLowerInvariant()
}

function Get-ByteSha256 {
    param([Parameter(Mandatory)][byte[]]$Bytes)
    return [Convert]::ToHexString(
        [Security.Cryptography.SHA256]::HashData($Bytes)
    ).ToLowerInvariant()
}

function Get-GitBlobBytes {
    param([Parameter(Mandatory)][string]$ObjectId)
    $startInfo = [Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = "git"
    $startInfo.WorkingDirectory = $repoRoot
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    foreach ($argument in @("cat-file", "blob", $ObjectId)) {
        [void]$startInfo.ArgumentList.Add($argument)
    }
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $startInfo
    $buffer = [IO.MemoryStream]::new()
    try {
        Assert-Exact $process.Start() "failed to read historical Git blob $ObjectId"
        $process.StandardOutput.BaseStream.CopyTo($buffer)
        $stderr = $process.StandardError.ReadToEnd()
        $process.WaitForExit()
        Assert-Exact ($process.ExitCode -eq 0) (
            "failed to read historical Git blob ${ObjectId}: $stderr"
        )
        return $buffer.ToArray()
    } finally {
        $buffer.Dispose()
        $process.Dispose()
    }
}

function Convert-LfToCrLfBytes {
    param([Parameter(Mandatory)][byte[]]$Bytes)
    $converted = [System.Collections.Generic.List[byte]]::new($Bytes.Length)
    for ($index = 0; $index -lt $Bytes.Length; $index += 1) {
        if ($Bytes[$index] -eq 0x0A -and ($index -eq 0 -or $Bytes[$index - 1] -ne 0x0D)) {
            $converted.Add(0x0D)
        }
        $converted.Add($Bytes[$index])
    }
    return $converted.ToArray()
}

function Test-HistoricalRawReceipt {
    param(
        [Parameter(Mandatory)][byte[]]$GitBlobBytes,
        [Parameter(Mandatory)][string]$ExpectedSha256
    )
    if ((Get-ByteSha256 -Bytes $GitBlobBytes) -ceq $ExpectedSha256) {
        return $true
    }
    $nativeWindowsBytes = Convert-LfToCrLfBytes -Bytes $GitBlobBytes
    return (Get-ByteSha256 -Bytes $nativeWindowsBytes) -ceq $ExpectedSha256
}

function Get-EvidenceTreeReceipt {
    param([Parameter(Mandatory)][string]$Root)
    $rows = [System.Collections.Generic.List[string]]::new()
    $total = 0L
    $files = @(
        Get-ChildItem -LiteralPath $Root -Recurse -File |
            Sort-Object FullName
    )
    foreach ($file in $files) {
        $relative = [IO.Path]::GetRelativePath($Root, $file.FullName).
            Replace("\", "/")
        $total += [long]$file.Length
        $rows.Add(
            "$relative`t$($file.Length)`t$(Get-RawSha256 $file.FullName)`n"
        )
    }
    $payload = [Text.Encoding]::UTF8.GetBytes(($rows -join ""))
    return [ordered]@{
        file_count = $files.Count
        total_byte_length = $total
        tree_sha256 = [Convert]::ToHexString(
            [Security.Cryptography.SHA256]::HashData($payload)
        ).ToLowerInvariant()
    }
}

Assert-Exact (
    (git -C $repoRoot rev-parse --show-toplevel).Trim() -ceq
        $repoRoot.Replace("\", "/") -and
    (git -C $repoRoot remote get-url origin).Trim() -ceq
        "https://github.com/Slagathore/sporespore.git"
) "$gateId repository identity changed"
Assert-Exact (
    (Test-Path -LiteralPath $closurePath -PathType Leaf) -and
    (Get-RawSha256 $closurePath) -ceq $expectedClosureSha256
) "$gateId closure is missing or changed"

$closure = Get-Content -Raw -LiteralPath $closurePath |
    ConvertFrom-Json -AsHashtable -Depth 100
Assert-Exact (
    [string]$closure.schema_version -ceq
        "sporespore_mujoco_c6_bw19v_selected_policy_pose_hold_restoration_mv6_closure_v1" -and
    [string]$closure.status -ceq
        "closed_complete_valid_positive_exact_s169_pose_hold_restoration_and_finite_walking_contract" -and
    [string]$closure.campaign_id -ceq $campaignId -and
    [string]$closure.gate_id -ceq $gateId -and
    [string]$closure.experiment_source_commit -ceq $sourceCommit -and
    [string]$closure.experiment_source_tree_git_oid -ceq $sourceTree -and
    [bool]$closure.source_was_clean_and_equal_to_origin_main_and_live_github_main -and
    [int]$closure.declared_study.world_count -eq 1 -and
    [int]$closure.declared_study.morphology_count -eq 1 -and
    [bool]$closure.declared_study.finite_decision -and
    -not [bool]$closure.declared_study.population_inference -and
    -not [bool]$closure.declared_study.independent_validation -and
    -not [bool]$closure.declared_study.physical_acceptance_authority
) "$gateId closure identity or declared study changed"

& git -C $repoRoot cat-file -e "$sourceCommit`^{commit}"
Assert-Exact ($LASTEXITCODE -eq 0) "$gateId source commit is not retained"
Assert-Exact (
    (git -C $repoRoot rev-parse "$sourceCommit`^{tree}").Trim() -ceq $sourceTree
) "$gateId source tree changed"
& git -C $repoRoot merge-base --is-ancestor $sourceCommit HEAD
Assert-Exact ($LASTEXITCODE -eq 0) "$gateId closure history lost its source commit"

$historicalGitBlobCount = 0
$unretainedHistoricalRawPaths = [System.Collections.Generic.List[string]]::new()
foreach ($entry in $closure.bound_source_inventory.GetEnumerator()) {
    $record = $entry.Value
    $relativePath = [string]$record.path
    $expectedRaw = ([string]$record.raw_sha256).Replace("sha256:", "")
    if ($relativePath -eq "sdk/target/release/sporespore_locomotion_core.dll") {
        continue
    }
    $sourceBlob = (git -C $repoRoot rev-parse "$sourceCommit`:$relativePath").Trim()
    $sourceBlobExitCode = $LASTEXITCODE
    Assert-Exact (
        $sourceBlobExitCode -eq 0 -and
        -not [string]::IsNullOrWhiteSpace($sourceBlob)
    ) (
        "$gateId historical Git source unavailable: $relativePath"
    )
    $historicalBytes = Get-GitBlobBytes -ObjectId $sourceBlob
    $historicalGitBlobCount += 1
    if (-not (Test-HistoricalRawReceipt `
        -GitBlobBytes $historicalBytes `
        -ExpectedSha256 $expectedRaw)) {
        $unretainedHistoricalRawPaths.Add($relativePath)
    }
}
Assert-Exact ($historicalGitBlobCount -eq 8) (
    "$gateId historical Git source inventory changed"
)
Assert-Exact ($unretainedHistoricalRawPaths.Count -eq 0) (
    "$gateId historical checkout bytes cannot be reconstructed: " +
    (@($unretainedHistoricalRawPaths | Sort-Object) -join ",")
)

$frozenDllSha256 = (
    [string]$closure.bound_source_inventory.release_locomotion_core_library.raw_sha256
).Replace("sha256:", "")
$frozenDllCasPath = Join-Path (
    "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence\artifacts\sha256"
) $frozenDllSha256
$frozenDllRetained = (
    (Test-Path -LiteralPath $frozenDllCasPath -PathType Leaf) -and
    (Get-RawSha256 $frozenDllCasPath) -ceq $frozenDllSha256
)
# MV6 predates content-addressed artifact retention. Its report, attempt,
# attestation, source commit, and frozen DLL digest survive, but the exact DLL
# bytes do not. Never compare that historical digest to today's mutable release
# path or substitute a later reproducible build.
Assert-Exact (
    $frozenDllRetained -or
    -not (Test-Path -LiteralPath $frozenDllCasPath -PathType Leaf)
) "$gateId frozen DLL CAS object exists with the wrong bytes"

# The campaign runner is executed below only to prove same-identity refusal.
# Require its historical raw bytes at the live path immediately before that
# current runtime-safety check. The frozen evaluator is not executed: its exact
# historical DLL is unavailable, so importing it would substitute today's DLL.
Assert-Exact (
    (Get-RawSha256 $runnerPath) -ceq (
        ([string]$closure.bound_source_inventory.supervisor.raw_sha256).Replace(
            "sha256:", ""
        )
    )
) "$gateId current refusal runner changed"

Assert-Exact (
    (Test-Path -LiteralPath $attestationPath -PathType Leaf) -and
    (Get-RawSha256 $attestationPath) -ceq
        "a80c900202d0df47daeec597d6fb004b72a6dc67cb76bcc047e6a99c554255d9" -and
    (Get-Item -LiteralPath $attestationPath).Length -eq 3563
) "$gateId full-Godot V2 attestation is missing or changed"
$attestation = Get-Content -Raw -LiteralPath $attestationPath |
    ConvertFrom-Json -AsHashtable -Depth 64
Assert-Exact (
    [string]$attestation.schema_version -ceq
        "sporespore_full_godot_conformance_attestation_v2" -and
    [string]$attestation.status -ceq "full_godot_conformance_passed" -and
    -not [bool]$attestation.test_only -and
    [string]$attestation.source.commit -ceq $sourceCommit -and
    [string]$attestation.source.tree_git_oid -ceq $sourceTree -and
    [string]$attestation.source.origin_main -ceq $sourceCommit -and
    [string]$attestation.source.live_github_main -ceq $sourceCommit -and
    [bool]$attestation.source.worktree_clean -and
    [bool]$attestation.source.clean_pushed_live -and
    [bool]$attestation.conformance.passed -and
    [bool]$attestation.conformance.godot_including -and
    -not [bool]$attestation.conformance.one_shot_physical_campaign_executed
) "$gateId full-Godot V2 attestation identity or gate changed"
Assert-Close `
    -Actual ([double]$attestation.conformance.duration_seconds) `
    -Expected 1938.7033881 `
    -Message "$gateId full-Godot V2 duration changed"
foreach ($claim in @($attestation.claims.Keys)) {
    Assert-Exact (-not [bool]$attestation.claims[$claim]) (
        "$gateId attestation inflated claim: $claim"
    )
}

$expectedEvidence = [ordered]@{
    "attempt.json" = "1142e0c395e3f2ed77ef860fd43e3ea69d26e758704961835ea4b43373cc0c9d"
    "completion.json" = "cf028ec9237ca1c35f6f405886ea371b4e8f7d5ac3bd7e4acc8c9ec4b8719f68"
    "preflight.json" = "de67ac77177906daa8aea787fc7a70b08264fe8db1f43522eba3908c4fd976c6"
    "report.json" = "f1a9da1b6ff2fc6917bdc3f1e15d830cce9cc3aedfa0bb32dc09d81c0cea972b"
    "stderr.log" = "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
    "stdout.log" = "61569193e73b0ee1b8a1ccfbc2e215e58315eb877bdbf958ffc5ec71a0a977c8"
}
Assert-Exact (
    (Test-Path -LiteralPath $evidenceRoot -PathType Container) -and
    @(Get-ChildItem -LiteralPath $evidenceRoot -Recurse -File).Count -eq 6
) "$gateId retained evidence cardinality changed"
foreach ($entry in $expectedEvidence.GetEnumerator()) {
    $path = Join-Path $evidenceRoot ([string]$entry.Key)
    Assert-Exact (
        (Test-Path -LiteralPath $path -PathType Leaf) -and
        (Get-RawSha256 $path) -ceq [string]$entry.Value
    ) "$gateId retained evidence changed: $($entry.Key)"
}
$tree = Get-EvidenceTreeReceipt -Root $evidenceRoot
Assert-Exact (
    [int]$tree.file_count -eq 6 -and
    [long]$tree.total_byte_length -eq 221419887 -and
    [string]$tree.tree_sha256 -ceq
        "e1d426c41e99d7cfdba7aa9ae148e8c7ae11ad21d9ec58c88b021348cda88b90"
) "$gateId retained evidence tree changed"

$attempt = Get-Content -Raw -LiteralPath (Join-Path $evidenceRoot "attempt.json") |
    ConvertFrom-Json -AsHashtable -Depth 64
$completion = Get-Content -Raw -LiteralPath (
    Join-Path $evidenceRoot "completion.json"
) | ConvertFrom-Json -AsHashtable -Depth 64
$preflight = Get-Content -Raw -LiteralPath (
    Join-Path $evidenceRoot "preflight.json"
) | ConvertFrom-Json -AsHashtable -Depth 100
Assert-Exact (
    [string]$attempt.attempt_id -ceq "97037172aeef4afaa38de3ef901816e4" -and
    [string]$attempt.status -ceq
        "physical_process_launch_reserved_identity_consumed" -and
    [string]$attempt.campaign_id -ceq $campaignId -and
    [string]$attempt.gate_id -ceq $gateId -and
    [string]$attempt.source_commit -ceq $sourceCommit -and
    [string]$attempt.source_origin_main -ceq $sourceCommit -and
    [string]$attempt.source_live_github_main -ceq $sourceCommit -and
    [string]$attempt.full_conformance_attestation_raw_sha256 -ceq
        "sha256:a80c900202d0df47daeec597d6fb004b72a6dc67cb76bcc047e6a99c554255d9" -and
    [int]$attempt.declared_world_count -eq 1 -and
    [int]$attempt.declared_controller_steps -eq 2992 -and
    [int]$attempt.declared_required_consecutive_all_four_contact_steps -eq 360 -and
    [bool]$attempt.physical_process_launch_consumes_identity -and
    -not [bool]$attempt.same_identity_rerun_allowed -and
    [bool]$attempt.operation_lock.acquired -and
    [string]$attempt.operation_lock.role -ceq "physical" -and
    [string]$completion.attempt_id -ceq [string]$attempt.attempt_id -and
    [string]$completion.source_commit -ceq $sourceCommit -and
    [bool]$completion.process_launched -and
    [int]$completion.process_exit_code -eq 0 -and
    $null -eq $completion.launch_error -and
    [bool]$completion.report_present -and
    [string]$completion.report_raw_sha256 -ceq
        "sha256:f1a9da1b6ff2fc6917bdc3f1e15d830cce9cc3aedfa0bb32dc09d81c0cea972b" -and
    -not [bool]$completion.same_identity_rerun_allowed -and
    [bool]$preflight.ok -and
    [int]$preflight.negative_control_count -eq 43 -and
    [int]$preflight.synthetic_report_negative_control_count -eq 18 -and
    [int]$preflight.world_build_count -eq 0 -and
    -not [bool]$preflight.physical_acceptance_authority -and
    [bool]$preflight.real_controller_trace_projection_canary.ok -and
    [int]$preflight.real_controller_trace_projection_canary.negative_control_count -eq 5 -and
    [bool]$preflight.engine_neutral_terminal_restoration_canary.ok -and
    [int]$preflight.engine_neutral_terminal_restoration_canary.negative_control_count -eq 5 -and
    [bool]$preflight.production_kinematic_vector_representation_canary.ok -and
    [int]$preflight.production_kinematic_vector_representation_canary.negative_control_count -eq 5 -and
    [bool]$preflight.shared_report_assembler_authority_schema_canary.ok -and
    [int]$preflight.shared_report_assembler_authority_schema_canary.negative_control_count -eq 6
) "$gateId attempt, completion, or zero-world receipt changed"

$pythonScript = @'
import json
import math
import sys

with open(sys.argv[1], encoding="utf-8") as handle:
    report = json.load(handle)

trace = report["ordered_trace"]
initial = report["initial_snapshot"]
evidence_completion = report["schedule"]["evidence_completion_semantic_step"]
evidence_start = trace[report["schedule"]["clocked_steps"]]["pre_step_snapshot"]
evidence_end = trace[evidence_completion]["post_step_snapshot"]
final = trace[-1]["post_step_snapshot"]

semantic_sequence = all(
    row["semantic_step"] == index
    and row["schema_version"]
    == "sporespore_mujoco_c6_bw19v_selected_policy_pose_hold_restoration_mv6_trace_step_v1"
    for index, row in enumerate(trace)
)
counts = {
    "base": sum(len(row["ordered_portable_base_commands"]) for row in trace),
    "bounded": sum(len(row["ordered_bounded_canonical_residuals"]) for row in trace),
    "canonical": sum(len(row["ordered_canonical_commands"]) for row in trace),
    "host": sum(len(row["ordered_host_commands"]) for row in trace),
    "native": sum(len(row["ordered_native_applications"]) for row in trace),
}
snapshots = [initial] + [row["post_step_snapshot"] for row in trace]
metrics = {
    "evidence_forward_displacement_m": (
        evidence_end["torso_position_m"][0] - evidence_start["torso_position_m"][0]
    ),
    "final_forward_displacement_m": (
        final["torso_position_m"][0] - initial["torso_position_m"][0]
    ),
    "final_lateral_displacement_m": (
        final["torso_position_m"][2] - initial["torso_position_m"][2]
    ),
    "final_yaw_drift_rad": final["torso_yaw_rad"] - initial["torso_yaw_rad"],
    "maximum_tilt_rad": max(item["torso_tilt_rad"] for item in snapshots),
    "minimum_torso_height_m": min(item["torso_position_m"][1] for item in snapshots),
    "torso_ground_contact_step_count": sum(
        bool(row["post_step_snapshot"]["torso_ground_contact"]) for row in trace
    ),
}

first_four = None
completion = None
consecutive = 0
maximum = 0
contact_ids = report["ordered_contact_site_ids"]
for row in trace[evidence_completion + 1:]:
    contacts = row["post_step_snapshot"]["ordered_declared_contacts"]
    all_four = all(contacts[contact_id] for contact_id in contact_ids)
    if all_four:
        if first_four is None:
            first_four = row["semantic_step"]
        consecutive += 1
        maximum = max(maximum, consecutive)
        if consecutive == 360 and completion is None:
            completion = row["semantic_step"]
    else:
        consecutive = 0

limb_evidence = {}
for limb_id, contact_id in zip(
    report["ordered_limb_ids"], report["ordered_contact_site_ids"], strict=True
):
    previous = bool(initial["ordered_declared_contacts"][contact_id])
    airborne = 0
    maximum_airborne = 0
    liftoff = None
    cycles = 0
    relocation = 0.0
    for row in trace:
        snapshot = row["post_step_snapshot"]
        contact = bool(snapshot["ordered_declared_contacts"][contact_id])
        point = snapshot["ordered_contact_site_positions_m"][contact_id]
        if previous and not contact:
            airborne = 1
            maximum_airborne = max(maximum_airborne, airborne)
            liftoff = point
        elif not previous and not contact:
            airborne += 1
            maximum_airborne = max(maximum_airborne, airborne)
        elif not previous and contact:
            maximum_airborne = max(maximum_airborne, airborne)
            if airborne >= 3:
                cycles += 1
                if liftoff is not None:
                    relocation = max(relocation, math.dist(point, liftoff))
            airborne = 0
            liftoff = None
        previous = contact
    limb_evidence[limb_id] = {
        "contact_cycles": cycles,
        "maximum_airborne_dwell_steps": maximum_airborne,
        "maximum_foot_relocation_m": relocation,
    }

print(json.dumps({
    "frozen_evaluator_replay_performed": False,
    "independent_retained_trace_replay_performed": True,
    "semantic_sequence": semantic_sequence,
    "trace_step_count": len(trace),
    "counts": counts,
    "metrics": metrics,
    "first_four_contact": first_four,
    "four_contact_completion": completion,
    "maximum_consecutive_four_contact_steps": maximum,
    "terminal_four_contact_stance": all(
        final["ordered_declared_contacts"][contact_id] for contact_id in contact_ids
    ),
    "limb_evidence": limb_evidence,
    "report_ok": report["ok"],
    "gate_failures": report["gate_failures"],
    "claim_boundary": report["claim_boundary"],
    "source_commit": report["source_commit"],
    "mv3_source_commit": report["mv3_source_commit"],
    "ph1_source_commit": report["ph1_source_commit"],
}, separators=(",", ":"), allow_nan=False))
'@

Push-Location -LiteralPath $mujocoRoot
try {
    $replayLines = @($pythonScript | & $python - $reportPath 2>&1)
    $replayExit = $LASTEXITCODE
} finally {
    Pop-Location
}
Assert-Exact ($replayExit -eq 0) (
    "$gateId independent retained-trace replay failed: " +
    ($replayLines -join "`n")
)
$replay = ($replayLines -join "`n") |
    ConvertFrom-Json -AsHashtable -Depth 100
Assert-Exact (
    -not $frozenDllRetained -and
    -not [bool]$replay.frozen_evaluator_replay_performed -and
    [bool]$replay.independent_retained_trace_replay_performed -and
    [bool]$replay.semantic_sequence -and
    [int]$replay.trace_step_count -eq 2992 -and
    [int]$replay.counts.base -eq 23936 -and
    [int]$replay.counts.bounded -eq 23936 -and
    [int]$replay.counts.canonical -eq 23936 -and
    [int]$replay.counts.host -eq 23936 -and
    [int]$replay.counts.native -eq 23936 -and
    [int]$replay.first_four_contact -eq 1939 -and
    [int]$replay.four_contact_completion -eq 2298 -and
    [int]$replay.maximum_consecutive_four_contact_steps -eq 1053 -and
    [bool]$replay.terminal_four_contact_stance -and
    [bool]$replay.report_ok -and
    @($replay.gate_failures).Count -eq 0 -and
    [string]$replay.source_commit -ceq $sourceCommit -and
    [string]$replay.mv3_source_commit -ceq
        "a52af71de64f43b8d742d17d4cf9905b778a134f" -and
    [string]$replay.ph1_source_commit -ceq
        "91c528e0d0eb494a7ff1d9dc9250ef1af6963249"
) "$gateId independent trace cardinality, schedule, or source replay changed"

$expectedMetrics = $closure.frozen_primary_result.metrics
foreach ($field in @(
    "evidence_forward_displacement_m",
    "final_forward_displacement_m",
    "final_lateral_displacement_m",
    "final_yaw_drift_rad",
    "maximum_tilt_rad",
    "minimum_torso_height_m"
)) {
    Assert-Close `
        -Actual ([double]$replay.metrics[$field]) `
        -Expected ([double]$expectedMetrics[$field]) `
        -Message "$gateId independently reconstructed metric changed: $field"
}
Assert-Exact (
    [int]$replay.metrics.torso_ground_contact_step_count -eq 0
) "$gateId independently reconstructed torso-contact count changed"
foreach ($limbId in @("front_left", "front_right", "rear_left", "rear_right")) {
    Assert-Exact (
        [int]$replay.limb_evidence[$limbId].contact_cycles -eq
            [int]$closure.frozen_primary_result.limb_evidence[$limbId].contact_cycles -and
        [int]$replay.limb_evidence[$limbId].maximum_airborne_dwell_steps -eq
            [int]$closure.frozen_primary_result.limb_evidence[$limbId].maximum_airborne_dwell_steps
    ) "$gateId independently reconstructed limb cycle changed: $limbId"
    Assert-Close `
        -Actual ([double]$replay.limb_evidence[$limbId].maximum_foot_relocation_m) `
        -Expected ([double]$closure.frozen_primary_result.limb_evidence[$limbId].maximum_foot_relocation_m) `
        -Message "$gateId independently reconstructed limb relocation changed: $limbId"
}

$zeroIntegrityFields = @(
    "controller_error_count",
    "composition_error_count",
    "global_scale_mismatch_count",
    "host_mapping_or_readback_mismatch_count",
    "actuator_application_mismatch_count",
    "portable_impulse_limit_violation_count",
    "nonfinite_observation_count",
    "native_position_target_application_count",
    "safe_no_actuation_count"
)
foreach ($field in $zeroIntegrityFields) {
    Assert-Exact (
        [int]$closure.frozen_primary_result.integrity_failure_counts[$field] -eq 0
    ) "$gateId closure integrity result changed: $field"
}
$trueReportClaims = @(
    $replay.claim_boundary.GetEnumerator() |
        Where-Object { [bool]$_.Value } |
        ForEach-Object { [string]$_.Key } |
        Sort-Object
)
Assert-Exact (
    ($trueReportClaims -join "|") -ceq
        "exact_s169_mujoco_bw19v_mv6_pose_hold_restoration_technical_commissioning|finite_single_body_walking_contract" -and
    [bool]$closure.scientific_disposition.separate_rapier_and_mujoco_positive_results_exist -and
    [bool]$closure.scientific_disposition.separate_positive_results_do_not_constitute_formal_equivalence -and
    [bool]$closure.claims.complete_attempt_closure -and
    [bool]$closure.claims.valid_scientific_result -and
    [bool]$closure.claims.scientific_positive_for_declared_exact_finite_contract -and
    [bool]$closure.claims.finite_single_body_walking_contract -and
    [bool]$closure.claims.different_physics_engines_have_separate_exact_finite_positive_records -and
    -not [bool]$closure.claims.general_walking_acceptance -and
    -not [bool]$closure.claims.mujoco_release_selected_policy_physical_c6 -and
    -not [bool]$closure.claims.cross_engine_selected_policy_equivalence -and
    -not [bool]$closure.claims.independent_validation -and
    -not [bool]$closure.claims.population_inference -and
    -not [bool]$closure.claims.release_authorized -and
    -not [bool]$closure.claims.physical_acceptance_authority -and
    -not [bool]$closure.claims.completed_engine_neutral_sdk -and
    [bool]$closure.immutability.campaign_complete -and
    [bool]$closure.immutability.same_identity_rerun_forbidden -and
    -not [bool]$closure.immutability.same_identity_rerun_allowed -and
    [bool]$closure.immutability.future_work_requires_distinct_campaign_identity
) "$gateId positive result, non-claim, or immutability boundary changed"

$treeBeforeRefusal = Get-EvidenceTreeReceipt -Root $evidenceRoot
$refusal = & pwsh `
    -NoLogo `
    -NoProfile `
    -File $runnerPath `
    -RunPhysical `
    -FullConformanceAttestation $attestationPath 2>&1 | Out-String
$refusalExitCode = $LASTEXITCODE
$treeAfterRefusal = Get-EvidenceTreeReceipt -Root $evidenceRoot
Assert-Exact (
    $refusalExitCode -ne 0 -and
    $refusal.Contains("$gateId is closed and may not open another world") -and
    [string]$treeAfterRefusal.tree_sha256 -ceq
        [string]$treeBeforeRefusal.tree_sha256 -and
    [int]$treeAfterRefusal.file_count -eq [int]$treeBeforeRefusal.file_count -and
    [long]$treeAfterRefusal.total_byte_length -eq
        [long]$treeBeforeRefusal.total_byte_length
) "$gateId same-identity physical rerun was not refused before evidence mutation"
$global:LASTEXITCODE = 0

Write-Host (
    "C6_MJC_BW19V_MV6_CLOSURE_PASS status=positive worlds=1 " +
    "trace_steps=2992 advance=1.399553 hold=360/1053 walking=True " +
    "historical_git_blobs=8 unretained_release_dll=$(if ($frozenDllRetained) { 0 } else { 1 }) " +
    "frozen_evaluator_replay=False independent_trace_replay=True " +
    "selected_policy_c6=False cross_engine_equivalence=False " +
    "physical_authority=False rerun_refused=True"
)
