#requires -Version 7.0

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$sdkRoot = Join-Path $repoRoot "sdk"
$sourceCommit = "51ced7fd74bd54a21e5750675c5503cae7d3fe4e"
$campaignId = "C6-MUJOCO-BW19V-SELECTED-POLICY-WALKING-MV1"
$gateId = "C6-MJC-BW19V-MV1"
$profileId = (
    "mujoco_s169_per_actuator_force_limited_five_substep_vh5_validated_v1"
)
$closurePath = Join-Path (
    $sdkRoot
) "mujoco_c6_bw19v_selected_policy_walking_mv1_closure.json"
$runnerPath = Join-Path (
    $sdkRoot
) "run_mujoco_c6_bw19v_selected_policy_walking_mv1.ps1"
$expectedClosureRawSha256 = (
    "97ea7d0cf1ebc1b48a7a508cf5cc41d9f8a7c1609b450a3ef9dea3b57c503e77"
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
        "sporespore_mujoco_c6_bw19v_selected_policy_walking_mv1_closure_v1" -and
    [string]$closure.status -ceq
        "closed_consumed_implementation_invalid_no_physical_report" -and
    [string]$closure.campaign_id -ceq $campaignId -and
    [string]$closure.gate_id -ceq $gateId -and
    [string]$closure.experiment_source_commit -ceq $sourceCommit -and
    [string]$closure.experiment_source_tree_git_oid -ceq
        "030c66eb0c7008e92f63a0f779ea73512364eedc" -and
    [bool]$closure.source_was_clean_and_equal_to_origin_main_and_live_github_main -and
    [int]$closure.declared_study.declared_world_count -eq 1 -and
    [int]$closure.declared_study.declared_controller_step_count -eq 2992 -and
    [int]$closure.declared_study.declared_command_count_per_layer -eq 23936 -and
    [int]$closure.declared_study.declared_negative_control_count -eq 24 -and
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
$historicalCore = [Text.Encoding]::UTF8.GetString(
    (Get-SporeGitBlobBytes `
        -RepositoryRoot $repoRoot `
        -Commit $sourceCommit `
        -Path ([string]$closure.bound_source_inventory.core_canonical_actuation.path))
)
$composeIndex = $historicalImplementation.IndexOf(
    "composition = bridge.compose_bw19v_step("
)
$applyIndex = $historicalImplementation.IndexOf(
    "application = robot.apply_host_mapping(mapping)"
)
Assert-Exact (
    $historicalImplementation.Contains("robot = bridge.MujocoBw19vRobot(core, PROFILE_ID)") -and
    $historicalImplementation.Contains("robot.prepare()") -and
    $composeIndex -ge 0 -and
    $applyIndex -gt $composeIndex -and
    $historicalBridge.Contains("self.model = mujoco.MjModel.from_xml_string(self.model_xml)") -and
    $historicalBridge.Contains("self.data = mujoco.MjData(self.model)") -and
    $historicalBridge.Contains("mujoco.mj_forward(self.model, self.data)") -and
    $historicalBridge.Contains("mujoco.mj_step1(self.model, self.data)") -and
    $historicalBridge.Contains("mujoco.mj_step2(self.model, self.data)") -and
    $historicalBridge.Contains($profileId) -and
    -not $historicalCore.Contains($profileId)
) "$gateId frozen cross-language profile defect or control-flow boundary changed"

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
    [int]$attempt.replacement_processes_allowed -eq 0 -and
    [bool]$attempt.operation_lock.acquired -and
    [string]$attempt.operation_lock.role -ceq "physical" -and
    [string]$completion.attempt_id -ceq [string]$attempt.attempt_id -and
    [bool]$completion.process_launched -and
    [int]$completion.process_exit_code -eq 1 -and
    $null -eq $completion.launch_error -and
    -not [bool]$completion.report_present -and
    $null -eq $completion.report_raw_sha256
) "$gateId attempt or completion receipt changed"
Assert-Exact (
    [bool]$preflight.ok -and
    [bool]$preflight.perfect_synthetic_result_passed -and
    [bool]$preflight.perfect_synthetic_serialization_round_trip_passed -and
    [int]$preflight.negative_control_count -eq 24 -and
    @($preflight.negative_controls_rejected.Values | Where-Object { -not [bool]$_ }).Count -eq 0 -and
    [int]$preflight.world_build_count -eq 0 -and
    -not [bool]$preflight.physics_state_modified
) "$gateId zero-world preflight receipt changed"
Assert-Exact (
    $stderr.Contains("sporespore_locomotion.LocomotionCoreError") -and
    $stderr.Contains(
        "ACTUATION_INVALID:velocity_only_host_profile:$profileId"
    ) -and
    $stderr.Contains("selected_policy_development.py`", line 924") -and
    $stderr.Contains("robot.core.canonical_velocity_host_map_v1")
) "$gateId retained implementation failure changed"

Assert-Exact (
    [string]$closure.implementation_failure.classification -ceq
        "cross_language_host_profile_registration_mismatch" -and
    [string]$closure.implementation_failure.exception_code -ceq
        "ACTUATION_INVALID" -and
    [bool]$closure.implementation_failure.python_bridge_registered_profile -and
    -not [bool]$closure.implementation_failure.rust_core_registered_profile -and
    [int]$closure.implementation_failure.posthoc_control_flow_inference.mjmodel_construction_count_before_exception -eq 1 -and
    [int]$closure.implementation_failure.posthoc_control_flow_inference.mjdata_construction_count_before_exception -eq 1 -and
    [int]$closure.implementation_failure.posthoc_control_flow_inference.mj_forward_call_count_before_exception -eq 1 -and
    [int]$closure.implementation_failure.posthoc_control_flow_inference.mj_step1_call_count_before_exception -eq 1 -and
    [int]$closure.implementation_failure.posthoc_control_flow_inference.mj_step2_call_count_before_exception -eq 0 -and
    [int]$closure.implementation_failure.posthoc_control_flow_inference.native_actuator_application_count_before_exception -eq 0 -and
    [int]$closure.implementation_failure.posthoc_control_flow_inference.completed_controller_step_count_before_exception -eq 0 -and
    -not [bool]$closure.implementation_failure.control_flow_counts_are_physical_report_measurements -and
    [bool]$closure.technical_disposition.campaign_identity_consumed -and
    [bool]$closure.technical_disposition.world_model_constructed -and
    -not [bool]$closure.technical_disposition.complete_physics_step_executed -and
    -not [bool]$closure.technical_disposition.native_actuation_applied -and
    -not [bool]$closure.technical_disposition.valid_complete_physical_report -and
    -not [bool]$closure.technical_disposition.scientific_positive -and
    -not [bool]$closure.technical_disposition.scientific_negative -and
    [string]$closure.scientific_disposition.classification -ceq
        "no_scientific_result_implementation_invalid" -and
    [bool]$closure.immutability.same_identity_rerun_forbidden -and
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
) ("sporespore_mv1_closed_" + [Guid]::NewGuid().ToString("N"))
$refusalOutput = (& pwsh -NoLogo -NoProfile -File $runnerPath `
    -RunPhysical -OutputRoot $refusalRoot 2>&1 | Out-String)
$refusalExit = $LASTEXITCODE
$afterTree = Get-EvidenceTreeDigest -Root $evidenceRoot
Assert-Exact (
    $refusalExit -ne 0 -and
    $refusalOutput.Contains(
        "$gateId is closed and may not open another world"
    ) -and
    -not (Test-Path -LiteralPath $refusalRoot) -and
    [int]$beforeTree.file_count -eq [int]$afterTree.file_count -and
    [long]$beforeTree.total_byte_length -eq [long]$afterTree.total_byte_length -and
    [string]$beforeTree.tree_sha256 -ceq [string]$afterTree.tree_sha256
) "$gateId same-identity physical rerun was not refused without evidence mutation"

Write-Output (
    "C6_MJC_BW19V_MV1_CLOSURE_PASS status=implementation-invalid " +
    "models_inferred=1 complete_steps_inferred=0 report=False " +
    "scientific_result=False walking=False physical_authority=False " +
    "rerun_refused=True"
)
