#requires -Version 7.0

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$sdkRoot = Join-Path $repoRoot "sdk"
$sourceCommit = "9173439f92ec455d988a6ffd2c57fe5335cca439"
$campaignId = "C6-MUJOCO-BW19V-SELECTED-POLICY-POSE-HOLD-RESTORATION-MV4"
$gateId = "C6-MJC-BW19V-MV4"
$closurePath = Join-Path (
    $sdkRoot
) "mujoco_c6_bw19v_selected_policy_pose_hold_restoration_mv4_closure.json"
$runnerPath = Join-Path (
    $sdkRoot
) "run_mujoco_c6_bw19v_selected_policy_pose_hold_restoration_mv4.ps1"
$expectedClosureRawSha256 = (
    "ee8c6805a63adda4c0711e99d2e527b3b9c2a37a8dbea7146a3b67cc033fdd28"
)

. (Join-Path $PSScriptRoot "closed_experiment_source_audit.ps1")

function Assert-Exact {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function Get-RawSha256 {
    param([Parameter(Mandatory)][string]$Path)
    return (
        Get-FileHash -Algorithm SHA256 -LiteralPath $Path
    ).Hash.ToLowerInvariant()
}

function Assert-AbsoluteArtifact {
    param(
        [Parameter(Mandatory)][System.Collections.IDictionary]$Artifact,
        [Parameter(Mandatory)][string]$Label
    )
    $path = [IO.Path]::GetFullPath([string]$Artifact.path)
    Assert-Exact (
        (Test-Path -LiteralPath $path -PathType Leaf) -and
        (Get-Item -LiteralPath $path).Length -eq
            [long]$Artifact.size_bytes -and
        (Get-RawSha256 -Path $path) -ceq
            ([string]$Artifact.raw_sha256).Replace("sha256:", "")
    ) "$gateId retained $Label is missing or changed"
}

function Test-BoundHistoricalSource {
    param([Parameter(Mandatory)][System.Collections.IDictionary]$Binding)
    if (
        $Binding.ContainsKey("byte_basis") -and
        [string]$Binding.byte_basis -ceq
            "frozen_windows_worktree_mixed_line_endings"
    ) {
        return Test-SporeHistoricalSourceAvailable `
            -RepositoryRoot $repoRoot `
            -Commit $sourceCommit `
            -Path ([string]$Binding.path)
    }
    $bytes = Get-SporeGitBlobBytes `
        -RepositoryRoot $repoRoot `
        -Commit $sourceCommit `
        -Path ([string]$Binding.path)
    $expectedHash = ([string]$Binding.raw_sha256).Replace(
        "sha256:", ""
    ).ToLowerInvariant()
    if (
        $bytes.Length -eq [long]$Binding.size_bytes -and
        (Get-SporeByteSha256 -Bytes $bytes) -ceq $expectedHash
    ) {
        return $true
    }
    $crlf = Convert-SporeLfBlobToCrlfBytes -Bytes $bytes
    return (
        $crlf.Length -eq [long]$Binding.size_bytes -and
        (Get-SporeByteSha256 -Bytes $crlf) -ceq $expectedHash
    )
}

function Get-EvidenceTreeDigest {
    param([Parameter(Mandatory)][string]$Root)
    $files = @(Get-ChildItem -LiteralPath $Root -File -Recurse)
    $lines = foreach ($file in @(
        $files | Sort-Object {
            $_.FullName.Substring($Root.Length + 1).Replace("\", "/")
        }
    )) {
        $relativePath = $file.FullName.Substring(
            $Root.Length + 1
        ).Replace("\", "/")
        "$relativePath`t$($file.Length)`t$(Get-RawSha256 -Path $file.FullName)"
    }
    $text = ($lines -join "`n") + "`n"
    return [ordered]@{
        file_count = $files.Count
        total_byte_length = [long](
            $files | Measure-Object -Property Length -Sum
        ).Sum
        tree_sha256 = [Convert]::ToHexString(
            [Security.Cryptography.SHA256]::HashData(
                [Text.Encoding]::UTF8.GetBytes($text)
            )
        ).ToLowerInvariant()
    }
}

Assert-Exact (
    (Test-Path -LiteralPath $closurePath -PathType Leaf) -and
    (Get-RawSha256 -Path $closurePath) -ceq $expectedClosureRawSha256
) "$gateId closure manifest is missing or changed"
$closure = Get-Content -Raw -LiteralPath $closurePath |
    ConvertFrom-Json -AsHashtable -Depth 128

Assert-Exact (
    [string]$closure.schema_version -ceq
        "sporespore_mujoco_c6_bw19v_selected_policy_pose_hold_restoration_mv4_closure_v1" -and
    [string]$closure.status -ceq
        "closed_consumed_implementation_invalid_no_physical_report" -and
    [string]$closure.campaign_id -ceq $campaignId -and
    [string]$closure.gate_id -ceq $gateId -and
    [string]$closure.experiment_source_commit -ceq $sourceCommit -and
    [string]$closure.experiment_source_tree_git_oid -ceq
        "104f3c1808f8d6518605b924cff0d80a256d3be4" -and
    [bool]$closure.source_was_clean_and_equal_to_origin_main_and_live_github_main -and
    [int]$closure.declared_study.declared_world_count -eq 1 -and
    [int]$closure.declared_study.declared_controller_step_count -eq 2992 -and
    [int]$closure.declared_study.declared_command_count_per_layer -eq 23936 -and
    [int]$closure.declared_study.declared_negative_control_count -eq 31 -and
    [int]$closure.declared_study.replacement_process_count -eq 0
) "$gateId closure identity or declared study changed"

& git -C $repoRoot cat-file -e "$sourceCommit`^{commit}"
Assert-Exact ($LASTEXITCODE -eq 0) "$gateId source commit is not retained"
Assert-Exact (
    (& git -C $repoRoot rev-parse "$sourceCommit`^{tree}").Trim() -ceq
        [string]$closure.experiment_source_tree_git_oid
) "$gateId experiment source tree changed"
& git -C $repoRoot merge-base --is-ancestor $sourceCommit HEAD
Assert-Exact ($LASTEXITCODE -eq 0) "$gateId source commit is not an ancestor"
$originMain = (& git -C $repoRoot rev-parse origin/main).Trim()
Assert-Exact ($LASTEXITCODE -eq 0) "$gateId origin/main could not be resolved"
& git -C $repoRoot merge-base --is-ancestor $sourceCommit $originMain
Assert-Exact ($LASTEXITCODE -eq 0) "$gateId source commit is not on origin/main"

foreach ($binding in $closure.bound_source_inventory.GetEnumerator()) {
    Assert-Exact (
        Test-BoundHistoricalSource -Binding $binding.Value
    ) "$gateId frozen source bytes changed: $($binding.Key)"
    $blob = (& git -C $repoRoot rev-parse (
        $sourceCommit + ":" + [string]$binding.Value.path
    )).Trim()
    Assert-Exact (
        $LASTEXITCODE -eq 0 -and
        $blob -ceq [string]$binding.Value.git_blob_oid
    ) "$gateId frozen Git blob changed: $($binding.Key)"
}

$historicalImplementation = [Text.Encoding]::UTF8.GetString(
    (Get-SporeGitBlobBytes `
        -RepositoryRoot $repoRoot `
        -Commit $sourceCommit `
        -Path ([string]$closure.bound_source_inventory.implementation.path))
)
$historicalBridge = [Text.Encoding]::UTF8.GetString(
    (Get-SporeGitBlobBytes `
        -RepositoryRoot $repoRoot `
        -Commit $sourceCommit `
        -Path ([string]$closure.bound_source_inventory.bridge.path))
)
$loopIndex = $historicalImplementation.IndexOf(
    "for semantic_step in range(TOTAL_STEPS):"
)
$walkingIndex = $historicalImplementation.IndexOf(
    "composition = bridge.compose_bw19v_step(", $loopIndex
)
$restorationIndex = $historicalImplementation.IndexOf(
    "restoration = _terminal_restoration_composition(", $walkingIndex
)
$axisFailureIndex = $historicalImplementation.IndexOf(
    'np.asarray(item["joint_axis_world_unit"], dtype=np.float64)'
)
$terminalApplicationIndex = $historicalImplementation.IndexOf(
    "application = robot.apply_host_mapping(mapping)", $restorationIndex
)
$traceIndex = $historicalImplementation.IndexOf("trace.append(", $terminalApplicationIndex)
$evidenceTransitionIndex = $historicalImplementation.IndexOf(
    "evidence_completion = semantic_step", $traceIndex
)
Assert-Exact (
    $historicalImplementation.Contains("TOTAL_STEPS = mv3.TOTAL_STEPS") -and
    $historicalImplementation.Contains(
        '"joint_axis_world_unit": [0.0, 0.0, 1.0]'
    ) -and
    $historicalImplementation.Contains(
        'np.asarray(item["endpoint_world_m"], dtype=np.float64)'
    ) -and
    $historicalImplementation.Contains(
        'np.asarray(item["joint_anchor_world_m"], dtype=np.float64)'
    ) -and
    $loopIndex -ge 0 -and
    $walkingIndex -gt $loopIndex -and
    $restorationIndex -gt $walkingIndex -and
    $axisFailureIndex -ge 0 -and
    $restorationIndex -gt $axisFailureIndex -and
    $terminalApplicationIndex -gt $restorationIndex -and
    $traceIndex -gt $terminalApplicationIndex -and
    $evidenceTransitionIndex -gt $traceIndex -and
    $historicalBridge.Contains(
        'return {"x": values[0], "y": values[1], "z": values[2]}'
    ) -and
    $historicalBridge.Contains('"joint_axis_world_unit": _vec_json(axis)') -and
    $historicalBridge.Contains('"joint_anchor_world_m": _vec_json(anchor)')
) "$gateId frozen vector-representation defect or control-flow boundary changed"

Assert-AbsoluteArtifact `
    -Artifact $closure.full_godot_v2_attestation `
    -Label "full-Godot V2 attestation"
$attestation = Get-Content -Raw -LiteralPath (
    [string]$closure.full_godot_v2_attestation.path
) | ConvertFrom-Json -AsHashtable -Depth 128
Assert-Exact (
    [string]$attestation.schema_version -ceq
        "sporespore_full_godot_conformance_attestation_v2" -and
    [string]$attestation.source.commit -ceq $sourceCommit -and
    [string]$attestation.source.tree_git_oid -ceq
        [string]$closure.experiment_source_tree_git_oid -and
    [bool]$attestation.source.clean_pushed_live -and
    [bool]$attestation.conformance.passed -and
    [bool]$attestation.conformance.godot_including -and
    -not [bool]$attestation.conformance.skip_godot -and
    -not [bool]$attestation.conformance.one_shot_physical_campaign_executed -and
    @($attestation.claims.Values | Where-Object { [bool]$_ }).Count -eq 0
) "$gateId full-Godot V2 attestation boundary changed"

$attemptSection = $closure.consumed_attempt
$evidenceRoot = [IO.Path]::GetFullPath([string]$attemptSection.evidence_root)
$expectedEvidencePrefix = [IO.Path]::GetFullPath(
    (Join-Path (Split-Path -Parent $repoRoot) "SporeSpore_Evidence")
).TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
Assert-Exact (
    $evidenceRoot.StartsWith(
        $expectedEvidencePrefix,
        [StringComparison]::OrdinalIgnoreCase
    ) -and
    (Test-Path -LiteralPath $evidenceRoot -PathType Container)
) "$gateId retained evidence root is missing or outside the durable root"
foreach ($name in @("attempt", "preflight", "stdout", "stderr", "completion")) {
    Assert-AbsoluteArtifact -Artifact $attemptSection[$name] -Label $name
}
Assert-Exact (
    -not [bool]$attemptSection.report_present -and
    -not (Test-Path -LiteralPath ([string]$attemptSection.report_path))
) "$gateId absent report declaration changed"
$tree = Get-EvidenceTreeDigest -Root $evidenceRoot
Assert-Exact (
    [int]$tree.file_count -eq [int]$attemptSection.evidence_tree.file_count -and
    [long]$tree.total_byte_length -eq
        [long]$attemptSection.evidence_tree.total_byte_length -and
    [string]$tree.tree_sha256 -ceq
        [string]$attemptSection.evidence_tree.tree_sha256
) "$gateId retained evidence tree changed"

$attempt = Get-Content -Raw -LiteralPath ([string]$attemptSection.attempt.path) |
    ConvertFrom-Json -AsHashtable -Depth 128
$completion = Get-Content -Raw -LiteralPath (
    [string]$attemptSection.completion.path
) | ConvertFrom-Json -AsHashtable -Depth 128
$preflight = Get-Content -Raw -LiteralPath (
    [string]$attemptSection.preflight.path
) | ConvertFrom-Json -AsHashtable -Depth 128
$stderr = Get-Content -Raw -LiteralPath ([string]$attemptSection.stderr.path)
Assert-Exact (
    [string]$attempt.attempt_id -ceq [string]$attemptSection.attempt_id -and
    [string]$attempt.campaign_id -ceq $campaignId -and
    [string]$attempt.gate_id -ceq $gateId -and
    [string]$attempt.source_commit -ceq $sourceCommit -and
    [bool]$attempt.physical_process_launch_consumes_identity -and
    -not [bool]$attempt.same_identity_rerun_allowed -and
    [bool]$attempt.operation_lock.acquired -and
    [string]$attempt.operation_lock.role -ceq "physical" -and
    [string]$completion.attempt_id -ceq [string]$attempt.attempt_id -and
    [bool]$completion.process_launched -and
    [int]$completion.process_exit_code -eq 1 -and
    $null -eq $completion.launch_error -and
    -not [bool]$completion.report_present -and
    $null -eq $completion.report_raw_sha256 -and
    -not [bool]$completion.same_identity_rerun_allowed
) "$gateId attempt or completion receipt changed"
Assert-Exact (
    [bool]$preflight.ok -and
    [bool]$preflight.perfect_synthetic_result_passed -and
    [bool]$preflight.perfect_synthetic_serialization_round_trip_passed -and
    [int]$preflight.negative_control_count -eq 31 -and
    [int]$preflight.synthetic_report_negative_control_count -eq 17 -and
    @($preflight.synthetic_report_negative_controls_rejected.Values |
        Where-Object { -not [bool]$_ }).Count -eq 0 -and
    [int]$preflight.real_dynamic_library_profile_canary.negative_control_count -eq 2 -and
    [int]$preflight.compiled_morphology_report_assembly_canary.negative_control_count -eq 2 -and
    [int]$preflight.real_controller_trace_projection_canary.negative_control_count -eq 5 -and
    [int]$preflight.engine_neutral_terminal_restoration_canary.negative_control_count -eq 5 -and
    [int]$preflight.world_build_count -eq 0 -and
    -not [bool]$preflight.physics_state_modified
) "$gateId zero-world preflight receipt changed"
Assert-Exact (
    $stderr.Contains(
        "TypeError: float() argument must be a string or a real number, not 'dict'"
    ) -and
    $stderr.Contains("selected_policy_pose_hold_restoration_mv4.py`", line 471") -and
    $stderr.Contains('np.asarray(item["joint_axis_world_unit"], dtype=np.float64)')
) "$gateId retained implementation failure changed"

$flow = $closure.implementation_failure.posthoc_control_flow_inference
Assert-Exact (
    [string]$closure.implementation_failure.classification -ceq
        "terminal_restoration_runtime_vector_representation_mismatch" -and
    [string]$closure.implementation_failure.exception_type -ceq "TypeError" -and
    [string]$closure.implementation_failure.production_vector_shape -ceq
        "object with numeric x, y, and z fields" -and
    [string]$closure.implementation_failure.synthetic_canary_vector_shape -ceq
        "three-element numeric list" -and
    [int]$flow.mujoco_model_construction_count_before_exception -eq 1 -and
    [int]$flow.mujoco_data_construction_count_before_exception -eq 1 -and
    [bool]$flow.walking_evidence_limit_transition_reached -and
    [bool]$flow.terminal_restoration_composition_entered -and
    -not [bool]$flow.first_terminal_host_mapping_constructed -and
    -not [bool]$flow.first_terminal_native_application_reached -and
    -not [bool]$flow.complete_declared_outer_controller_horizon_reached -and
    -not [bool]$flow.metric_calculation_reached -and
    -not [bool]$flow.report_dictionary_construction_completed -and
    -not [bool]$flow.report_evaluation_reached -and
    -not [bool]$flow.report_serialization_reached -and
    -not [bool]$flow.exact_completed_walking_step_count_recoverable -and
    -not [bool]$flow.exact_in_memory_trace_row_count_recoverable -and
    -not [bool]$closure.implementation_failure.
        control_flow_facts_are_recovered_physical_report_measurements -and
    -not [bool]$closure.implementation_failure.
        lost_in_memory_trace_may_be_reconstructed_or_scientifically_interpreted -and
    [bool]$closure.technical_disposition.campaign_identity_consumed -and
    [bool]$closure.technical_disposition.world_model_constructed -and
    [bool]$closure.technical_disposition.walking_phase_native_actuation_applied -and
    [bool]$closure.technical_disposition.
        walking_evidence_limit_transition_reached_in_control_flow -and
    -not [bool]$closure.technical_disposition.
        terminal_restoration_native_actuation_applied -and
    -not [bool]$closure.technical_disposition.complete_declared_physics_horizon -and
    -not [bool]$closure.technical_disposition.valid_complete_physical_report -and
    -not [bool]$closure.technical_disposition.scientific_positive -and
    -not [bool]$closure.technical_disposition.scientific_negative -and
    [string]$closure.scientific_disposition.classification -ceq
        "no_scientific_result_implementation_invalid" -and
    [bool]$closure.immutability.same_identity_rerun_forbidden -and
    [bool]$closure.immutability.lost_trace_reconstruction_forbidden -and
    [bool]$closure.immutability.successor_requires_new_identity -and
    [bool]$closure.claims.complete_attempt_closure -and
    -not [bool]$closure.claims.valid_scientific_result -and
    -not [bool]$closure.claims.exact_s169_mujoco_bw19v_walking -and
    -not [bool]$closure.claims.mujoco_selected_policy_physical_c6 -and
    -not [bool]$closure.claims.cross_engine_selected_policy_equivalence -and
    -not [bool]$closure.claims.release_authorized -and
    -not [bool]$closure.claims.physical_acceptance_authority
) "$gateId implementation-invalid disposition or claim boundary changed"

$beforeTree = Get-EvidenceTreeDigest -Root $evidenceRoot
$refusalRoot = Join-Path (
    [IO.Path]::GetTempPath()
) ("sporespore_mv4_closed_" + [Guid]::NewGuid().ToString("N"))
$refusalOutput = (& pwsh -NoLogo -NoProfile -File $runnerPath `
    -RunPhysical -OutputRoot $refusalRoot 2>&1 | Out-String)
$refusalExit = $LASTEXITCODE
$afterTree = Get-EvidenceTreeDigest -Root $evidenceRoot
Assert-Exact (
    $refusalExit -ne 0 -and
    $refusalOutput.Contains(
        "$gateId is closed and may not open another world; audit the closure instead"
    ) -and
    -not (Test-Path -LiteralPath $refusalRoot) -and
    [int]$beforeTree.file_count -eq [int]$afterTree.file_count -and
    [long]$beforeTree.total_byte_length -eq [long]$afterTree.total_byte_length -and
    [string]$beforeTree.tree_sha256 -ceq [string]$afterTree.tree_sha256
) "$gateId same-identity physical rerun was not refused without evidence mutation"

Write-Output (
    "C6_MJC_BW19V_MV4_CLOSURE_PASS status=implementation-invalid " +
    "worlds=1 evidence_transition=True terminal_commands=0 report=False " +
    "scientific_result=False walking=False physical_authority=False " +
    "rerun_refused=True"
)
