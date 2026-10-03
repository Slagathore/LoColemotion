#requires -Version 7.0

[CmdletBinding()]
param(
    [switch]$PreflightOnly,
    [switch]$RunPhysical,
    [string]$OutputRoot = "",
    [string]$FullConformanceAttestation = "",
    [string]$Godot = (
        "C:\Users\Cole\CodeStuff\Misc\Godot\" +
        "Godot_v4.7-stable_mono_win64_console.exe"
    )
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

function Assert-Exact {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function Get-RawSha256 {
    param([Parameter(Mandatory)][string]$Path)
    return "sha256:" + (
        Get-FileHash -Algorithm SHA256 -LiteralPath $Path
    ).Hash.ToLowerInvariant()
}

function Write-NewUtf8TextFile {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][AllowEmptyString()][string]$Text
    )
    $bytes = [Text.UTF8Encoding]::new($false).GetBytes($Text)
    $stream = [IO.File]::Open(
        $Path,
        [IO.FileMode]::CreateNew,
        [IO.FileAccess]::Write,
        [IO.FileShare]::None
    )
    try {
        $stream.Write($bytes, 0, $bytes.Length)
        $stream.Flush($true)
    } finally {
        $stream.Dispose()
    }
}

function Write-NewJsonFile {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][object]$Value
    )
    Write-NewUtf8TextFile `
        -Path $Path `
        -Text (($Value | ConvertTo-Json -Depth 64) + [Environment]::NewLine)
}

function Assert-DeclaredRepoFile {
    param(
        [Parameter(Mandatory)][string]$RelativePath,
        [Parameter(Mandatory)][string]$ExpectedRawSha256,
        [Parameter(Mandatory)][string]$RepoRoot
    )
    $path = [IO.Path]::GetFullPath((Join-Path $RepoRoot $RelativePath))
    $prefix = $RepoRoot.TrimEnd(
        [IO.Path]::DirectorySeparatorChar,
        [IO.Path]::AltDirectorySeparatorChar
    ) + [IO.Path]::DirectorySeparatorChar
    Assert-Exact (
        $path.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase) -and
        (Test-Path -LiteralPath $path -PathType Leaf) -and
        (Get-RawSha256 -Path $path) -ceq
            ("sha256:" + $ExpectedRawSha256.Replace("sha256:", ""))
    ) "$gateId pinned repository file mismatch: $RelativePath"
}

Assert-Exact (
    $PreflightOnly.IsPresent -xor $RunPhysical.IsPresent
) "Specify exactly one of -PreflightOnly or -RunPhysical"
Assert-Exact (
    $RunPhysical.IsPresent -or
    ([string]::IsNullOrWhiteSpace($OutputRoot) -and
        [string]::IsNullOrWhiteSpace($FullConformanceAttestation))
) "-OutputRoot and -FullConformanceAttestation are valid only with -RunPhysical"

$sdkRoot = [IO.Path]::GetFullPath($PSScriptRoot)
$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $sdkRoot))
$mujocoRoot = Join-Path $sdkRoot "adapters\mujoco"
$python = Join-Path $mujocoRoot ".venv\Scripts\python.exe"
$preregistrationPath = Join-Path $sdkRoot (
    "mujoco_c6_bw19v_selected_policy_walking_mv3_preregistration.json"
)
$implementationPath = Join-Path $mujocoRoot (
    "sporespore_mujoco_adapter\selected_policy_walking_mv3.py"
)
$bridgePath = Join-Path $mujocoRoot (
    "sporespore_mujoco_adapter\selected_policy_development.py"
)
$vh5ClosurePath = Join-Path $sdkRoot (
    "mujoco_c6_s169_per_actuator_force_limit_host_characterization_vh5_closure.json"
)
$lc1PreregistrationPath = Join-Path $sdkRoot (
    "rapier_c6_bw19v_velocity_only_long_horizon_commissioning_lc1_preregistration.json"
)
$mv2ClosurePath = Join-Path $sdkRoot (
    "mujoco_c6_bw19v_selected_policy_walking_mv2_closure.json"
)
$pythonCoreWrapperPath = Join-Path $sdkRoot "python\sporespore_locomotion.py"
$releaseLibraryPath = Join-Path $sdkRoot (
    "target\release\sporespore_locomotion_core.dll"
)
$selectedPolicyClosurePath = Join-Path $sdkRoot "balanced_wave_bw19v_closure_manifest.json"
$requirementsLockPath = Join-Path $mujocoRoot "requirements-lock.txt"
$closurePath = Join-Path $sdkRoot (
    "mujoco_c6_bw19v_selected_policy_walking_mv3_closure.json"
)
$operationLockPath = Join-Path $sdkRoot "locomotion_operation_lock.ps1"
$attestationVerifierPath = Join-Path $sdkRoot (
    "locomotion_full_conformance_attestation.ps1"
)
$expectedPreregistrationSha256 = (
    "sha256:77aa6696024af4b0bb8e289b798a4460773ff9f85940776bc24503cb88d18726"
)
$campaignId = "C6-MUJOCO-BW19V-SELECTED-POLICY-WALKING-MV3"
$gateId = "C6-MJC-BW19V-MV3"
$evidenceRoot = [IO.Path]::GetFullPath(
    (Join-Path (Split-Path -Parent $repoRoot) "SporeSpore_Evidence")
)

if ($RunPhysical.IsPresent -and (Test-Path -LiteralPath $closurePath -PathType Leaf)) {
    throw "$gateId is closed and may not open another world; audit the closure instead"
}

Assert-Exact (
    (git -C $repoRoot rev-parse --show-toplevel).Trim() -ceq $repoRoot.Replace("\", "/")
) "$gateId repository identity mismatch"
Assert-Exact (
    (git -C $repoRoot remote get-url origin).Trim() -ceq
        "https://github.com/Slagathore/sporespore.git"
) "$gateId origin identity mismatch"
foreach ($path in @(
    $python,
    $preregistrationPath,
    $implementationPath,
    $bridgePath,
    $vh5ClosurePath,
    $lc1PreregistrationPath,
    $mv2ClosurePath,
    $pythonCoreWrapperPath,
    $releaseLibraryPath,
    $selectedPolicyClosurePath,
    $requirementsLockPath,
    $operationLockPath,
    $attestationVerifierPath
)) {
    Assert-Exact (Test-Path -LiteralPath $path -PathType Leaf) (
        "$gateId required source or environment file is missing: $path"
    )
}

$pinnedFiles = [ordered]@{
    "sdk/mujoco_c6_bw19v_selected_policy_walking_mv3_preregistration.json" = "77aa6696024af4b0bb8e289b798a4460773ff9f85940776bc24503cb88d18726"
    "sdk/adapters/mujoco/sporespore_mujoco_adapter/selected_policy_walking_mv3.py" = "a01cc11c5cb89d90b006b2bf05cee66d119722f0bbc7e1749c22671c8be24078"
    "sdk/adapters/mujoco/sporespore_mujoco_adapter/selected_policy_development.py" = "306669481601cc91c8146e84a202a57228672e23c3f9daa0c531d2eb9d077e46"
    "sdk/mujoco_c6_s169_per_actuator_force_limit_host_characterization_vh5_closure.json" = "fbb8441fb8a3907c56155db777de00ce8b6e2f293ef67e77a2a30d2eeeb0f34f"
    "sdk/rapier_c6_bw19v_velocity_only_long_horizon_commissioning_lc1_preregistration.json" = "a5e88d5e0f69772c7dec67cc0d8bd83aa903ab2fe642a301fbf8ed3f09b47d0b"
    "sdk/balanced_wave_bw19v_closure_manifest.json" = "ea8df6a574e1b9be1050afa8ed57982a102982ada0f0d5babccf3c937c7067f7"
    "sdk/mujoco_c6_bw19v_selected_policy_walking_mv2_closure.json" = "0ef035bf76ebfc2c2ded74912cd5219f51304ae13086407324a5fbc491fec51c"
    "sdk/core/src/canonical_actuation.rs" = "e2d7e27edaf7caa218d95a5ed7966f5c6d317ff8c5990c5cd0e2876e1d485d05"
    "sdk/python/sporespore_locomotion.py" = "53e9be5f192f1424bd2d6c22aeecb563b8d7ed0ae3931901c2dcd576ee1160f7"
    "sdk/adapters/mujoco/requirements-lock.txt" = "38e97a013ec5e7c5bd88cd4dc1c2c54dd151936aa7f24c1f87abac19853b77b9"
}
foreach ($entry in $pinnedFiles.GetEnumerator()) {
    Assert-DeclaredRepoFile `
        -RelativePath ([string]$entry.Key) `
        -ExpectedRawSha256 ([string]$entry.Value) `
        -RepoRoot $repoRoot
}

$declaration = Get-Content -Raw -LiteralPath $preregistrationPath |
    ConvertFrom-Json -AsHashtable -Depth 64
Assert-Exact (
    (Get-RawSha256 -Path $preregistrationPath) -ceq $expectedPreregistrationSha256 -and
    [string]$declaration.campaign_id -ceq $campaignId -and
    [string]$declaration.gate_id -ceq $gateId -and
    [string]$declaration.status -ceq
        "frozen_before_first_c6_mjc_bw19v_mv3_physics_world" -and
    [int]$declaration.physical_horizon.expected_world_count -eq 1 -and
    [int]$declaration.physical_horizon.total_controller_semantic_steps -eq 2992 -and
    [int]$declaration.physical_horizon.expected_commands_per_layer -eq 23936 -and
    [int]$declaration.preflight_contract.negative_control_count -eq 31 -and
    [int]$declaration.preflight_contract.synthetic_report_negative_control_count -eq 27 -and
    [int]$declaration.preflight_contract.real_dynamic_library_negative_control_count -eq 2 -and
    [int]$declaration.preflight_contract.
        compiled_morphology_report_assembly_negative_control_count -eq 2 -and
    [bool]$declaration.claims_if_passed.exact_s169_mujoco_bw19v_mv3_walking -and
    -not [bool]$declaration.claims_if_passed.cross_engine_selected_policy_equivalence -and
    -not [bool]$declaration.claims_if_passed.release_authorized -and
    -not [bool]$declaration.claims_if_passed.physical_acceptance_authority
) "$gateId preregistration identity, horizon, or claim boundary changed"

Push-Location -LiteralPath $mujocoRoot
try {
    $preflightLines = @(
        & $python `
            -m sporespore_mujoco_adapter.selected_policy_walking_mv3 `
            --preflight-only
    )
    Assert-Exact ($LASTEXITCODE -eq 0) "$gateId zero-world preflight failed"
} finally {
    Pop-Location
}
$preflightText = $preflightLines -join [Environment]::NewLine
$preflight = $preflightText | ConvertFrom-Json -AsHashtable -Depth 100
Assert-Exact (
    [bool]$preflight.ok -and
    [bool]$preflight.perfect_synthetic_result_passed -and
    [bool]$preflight.perfect_synthetic_serialization_round_trip_passed -and
    [int]$preflight.negative_control_count -eq 31 -and
    [int]$preflight.synthetic_report_negative_control_count -eq 27 -and
    [int]$preflight.real_dynamic_library_negative_control_count -eq 2 -and
    [int]$preflight.compiled_morphology_report_assembly_negative_control_count -eq 2 -and
    @($preflight.negative_controls_rejected.Values | Where-Object { -not [bool]$_ }).Count -eq 0 -and
    [bool]$preflight.real_dynamic_library_profile_canary.ok -and
    [bool]$preflight.real_dynamic_library_profile_canary.exact_release_library_loaded -and
    [string]$preflight.real_dynamic_library_profile_canary.library_path -ceq
        ([IO.Path]::GetFullPath($releaseLibraryPath).Replace("\", "/")) -and
    [string]$preflight.real_dynamic_library_profile_canary.library_raw_sha256 -ceq
        (Get-RawSha256 -Path $releaseLibraryPath) -and
    [bool]$preflight.real_dynamic_library_profile_canary.positive_mapping_passed -and
    [int]$preflight.real_dynamic_library_profile_canary.negative_control_count -eq 2 -and
    @($preflight.real_dynamic_library_profile_canary.negative_controls_rejected.Values |
        Where-Object { -not [bool]$_ }).Count -eq 0 -and
    [int]$preflight.real_dynamic_library_profile_canary.model_construction_count -eq 0 -and
    [int]$preflight.real_dynamic_library_profile_canary.data_construction_count -eq 0 -and
    [bool]$preflight.compiled_morphology_report_assembly_canary.ok -and
    [bool]$preflight.compiled_morphology_report_assembly_canary.
        shared_physical_assembler_executed -and
    -not [bool]$preflight.compiled_morphology_report_assembly_canary.
        nested_morphology_contains_morphology_id -and
    [bool]$preflight.compiled_morphology_report_assembly_canary.
        serialization_round_trip_passed -and
    [int]$preflight.compiled_morphology_report_assembly_canary.negative_control_count -eq 2 -and
    @($preflight.compiled_morphology_report_assembly_canary.
        negative_controls_rejected.Values | Where-Object { -not [bool]$_ }).Count -eq 0 -and
    [int]$preflight.compiled_morphology_report_assembly_canary.model_construction_count -eq 0 -and
    [int]$preflight.compiled_morphology_report_assembly_canary.data_construction_count -eq 0 -and
    [int]$preflight.compiled_morphology_report_assembly_canary.world_build_count -eq 0 -and
    [int]$preflight.world_build_count -eq 0 -and
    [int]$preflight.scene_insertion_count -eq 0 -and
    -not [bool]$preflight.physics_state_modified -and
    -not [bool]$preflight.locomotion_outcome_exposed -and
    -not [bool]$preflight.physical_acceptance_authority
) "$gateId zero-world preflight receipt is incomplete or inflated"

if ($PreflightOnly) {
    Write-Host (
        "C6_MJC_BW19V_MV3_FREEZE_PASS worlds=0 steps=2992 commands=23936 " +
        "canaries=31 synthetic=27 dynamic=2 report=2 physical_authority=False"
    )
    return
}

Assert-Exact (
    -not [string]::IsNullOrWhiteSpace($FullConformanceAttestation)
) "$gateId -RunPhysical requires an exact full-Godot V2 attestation"
$priorEvidence = @(
    Get-ChildItem -LiteralPath $evidenceRoot `
        -Directory `
        -Filter "c6-mujoco-bw19v-mv3-*" `
        -ErrorAction SilentlyContinue
)
Assert-Exact ($priorEvidence.Count -eq 0) (
    "$gateId prior evidence exists; same-identity rerun is forbidden"
)

. $operationLockPath
. $attestationVerifierPath
$operationLockReceipt = $null
$operationLockReceipt = Enter-SporeSporeLocomotionOperationLock -Role physical
Assert-Exact (
    [bool]$operationLockReceipt.acquired -and
    [string]$operationLockReceipt.role -ceq "physical" -and
    -not [bool]$operationLockReceipt.test_only
) "$gateId could not acquire the global locomotion physical-operation lock"

try {
    $sourceCommit = (git -C $repoRoot rev-parse HEAD).Trim()
    $originMain = (git -C $repoRoot rev-parse origin/main).Trim()
    $status = @(git -C $repoRoot status --porcelain=v1 --untracked-files=all)
    $remoteLine = @(git -C $repoRoot ls-remote origin refs/heads/main)
    $liveMain = if ($remoteLine.Count -eq 1) {
        ($remoteLine[0] -split "\s+")[0]
    } else { "" }
    Assert-Exact (
        $sourceCommit -cmatch "^[0-9a-f]{40}$" -and
        $sourceCommit -cne [string]$declaration.implementation_parent_commit -and
        $sourceCommit -ceq $originMain -and
        $sourceCommit -ceq $liveMain -and
        $status.Count -eq 0
    ) "$gateId physical execution requires distinct clean HEAD == origin/main == live GitHub main"

    $resolvedAttestationPath = [IO.Path]::GetFullPath($FullConformanceAttestation)
    $attestationVerification = Test-SporeSporeFullConformanceAttestationFile `
        -RepoRoot $repoRoot `
        -Godot ([IO.Path]::GetFullPath($Godot)) `
        -AttestationPath $resolvedAttestationPath
    Assert-Exact (
        [bool]$attestationVerification.ok -and
        @($attestationVerification.failure_codes).Count -eq 0
    ) (
        "$gateId exact full-conformance attestation failed: " +
        (@($attestationVerification.failure_codes) -join ",")
    )
    $attestation = Get-Content -Raw -LiteralPath $resolvedAttestationPath |
        ConvertFrom-Json -AsHashtable -Depth 64
    Assert-Exact (
        [string]$attestation.schema_version -ceq
            "sporespore_full_godot_conformance_attestation_v2" -and
        [string]$attestation.source.commit -ceq $sourceCommit -and
        [string]$attestation.source.origin_main -ceq $sourceCommit -and
        [string]$attestation.source.live_github_main -ceq $sourceCommit -and
        [bool]$attestation.source.clean_pushed_live -and
        -not [bool]$attestation.conformance.one_shot_physical_campaign_executed
    ) "$gateId full-conformance attestation source or campaign boundary changed"
    foreach ($claimName in @($attestation.claims.Keys)) {
        Assert-Exact (-not [bool]$attestation.claims[$claimName]) (
            "$gateId full-conformance attestation inflated claim: $claimName"
        )
    }

    $shortCommit = $sourceCommit.Substring(0, 7)
    if ([string]::IsNullOrWhiteSpace($OutputRoot)) {
        $OutputRoot = Join-Path $evidenceRoot "c6-mujoco-bw19v-mv3-$shortCommit"
    }
    $resolvedOutputRoot = [IO.Path]::GetFullPath($OutputRoot)
    $evidencePrefix = $evidenceRoot.TrimEnd(
        [IO.Path]::DirectorySeparatorChar,
        [IO.Path]::AltDirectorySeparatorChar
    ) + [IO.Path]::DirectorySeparatorChar
    Assert-Exact (
        $resolvedOutputRoot.StartsWith(
            $evidencePrefix,
            [StringComparison]::OrdinalIgnoreCase
        ) -and
        [IO.Path]::GetFileName($resolvedOutputRoot) -ceq
            "c6-mujoco-bw19v-mv3-$shortCommit" -and
        -not (Test-Path -LiteralPath $resolvedOutputRoot)
    ) "$gateId output root must be new, exact, and under SporeSpore_Evidence"
    [void][IO.Directory]::CreateDirectory($resolvedOutputRoot)

    $preflightPath = Join-Path $resolvedOutputRoot "preflight.json"
    $attemptPath = Join-Path $resolvedOutputRoot "attempt.json"
    $completionPath = Join-Path $resolvedOutputRoot "completion.json"
    $reportPath = Join-Path $resolvedOutputRoot "report.json"
    $stdoutPath = Join-Path $resolvedOutputRoot "stdout.log"
    $stderrPath = Join-Path $resolvedOutputRoot "stderr.log"
    Write-NewUtf8TextFile -Path $preflightPath -Text (
        $preflightText + [Environment]::NewLine
    )

    $attemptId = [Guid]::NewGuid().ToString("N")
    $operationLockPublic = Get-SporeSporeLocomotionOperationLockPublicReceipt `
        -Receipt $operationLockReceipt
    $attempt = [ordered]@{
        schema_version = "sporespore_physical_attempt_reservation_v1"
        attempt_id = $attemptId
        campaign_id = $campaignId
        gate_id = $gateId
        source_commit = $sourceCommit
        source_origin_main = $originMain
        source_live_github_main = $liveMain
        reserved_utc = [DateTime]::UtcNow.ToString("o")
        output_root = $resolvedOutputRoot.Replace("\", "/")
        preregistration_raw_sha256 = Get-RawSha256 -Path $preregistrationPath
        implementation_raw_sha256 = Get-RawSha256 -Path $implementationPath
        bridge_raw_sha256 = Get-RawSha256 -Path $bridgePath
        runner_raw_sha256 = Get-RawSha256 -Path $PSCommandPath
        requirements_lock_raw_sha256 = Get-RawSha256 -Path $requirementsLockPath
        vh5_closure_raw_sha256 = Get-RawSha256 -Path $vh5ClosurePath
        mv2_closure_raw_sha256 = Get-RawSha256 -Path $mv2ClosurePath
        locomotion_core_library_path = ([IO.Path]::GetFullPath($releaseLibraryPath)).Replace("\", "/")
        locomotion_core_library_raw_sha256 = Get-RawSha256 -Path $releaseLibraryPath
        preworld_mapping_receipt_raw_sha256 = [string]$preflight.
            real_dynamic_library_profile_canary.positive_mapping_receipt_sha256
        preflight_path = $preflightPath.Replace("\", "/")
        preflight_raw_sha256 = Get-RawSha256 -Path $preflightPath
        full_conformance_attestation_path = $resolvedAttestationPath.Replace("\", "/")
        full_conformance_attestation_raw_sha256 = Get-RawSha256 -Path $resolvedAttestationPath
        full_conformance_attestation_source_commit = [string]$attestation.source.commit
        operation_lock = $operationLockPublic
        physical_process_launch_consumes_identity = $true
        replacement_processes_allowed = 0
    }
    Write-NewJsonFile -Path $attemptPath -Value $attempt

    Assert-Exact (
        @(git -C $repoRoot status --porcelain=v1 --untracked-files=all).Count -eq 0 -and
        (git -C $repoRoot rev-parse HEAD).Trim() -ceq $sourceCommit -and
        (Get-RawSha256 -Path $preregistrationPath) -ceq $expectedPreregistrationSha256 -and
        (Get-RawSha256 -Path $implementationPath) -ceq [string]$attempt.implementation_raw_sha256 -and
        (Get-RawSha256 -Path $bridgePath) -ceq [string]$attempt.bridge_raw_sha256 -and
        (Get-RawSha256 -Path $PSCommandPath) -ceq [string]$attempt.runner_raw_sha256 -and
        (Get-RawSha256 -Path $releaseLibraryPath) -ceq
            [string]$attempt.locomotion_core_library_raw_sha256 -and
        (Get-RawSha256 -Path $resolvedAttestationPath) -ceq
            [string]$attempt.full_conformance_attestation_raw_sha256
    ) "$gateId source changed after attempt reservation; physical launch refused"

    $process = $null
    $launchError = $null
    try {
        $process = Start-Process `
            -FilePath $python `
            -ArgumentList @(
                "-m",
                "sporespore_mujoco_adapter.selected_policy_walking_mv3",
                "--run-physical",
                "--source-commit",
                $sourceCommit,
                "--report",
                $reportPath
            ) `
            -WorkingDirectory $mujocoRoot `
            -WindowStyle Hidden `
            -Wait `
            -PassThru `
            -RedirectStandardOutput $stdoutPath `
            -RedirectStandardError $stderrPath
    } catch {
        $launchError = $_.Exception.Message
    }

    $completion = [ordered]@{
        schema_version = "sporespore_physical_attempt_completion_v1"
        attempt_id = $attemptId
        campaign_id = $campaignId
        gate_id = $gateId
        source_commit = $sourceCommit
        completed_utc = [DateTime]::UtcNow.ToString("o")
        process_launched = $null -ne $process
        process_exit_code = if ($null -ne $process) { $process.ExitCode } else { $null }
        launch_error = $launchError
        report_present = Test-Path -LiteralPath $reportPath -PathType Leaf
        report_raw_sha256 = if (Test-Path -LiteralPath $reportPath -PathType Leaf) {
            Get-RawSha256 -Path $reportPath
        } else { $null }
        stdout_raw_sha256 = if (Test-Path -LiteralPath $stdoutPath -PathType Leaf) {
            Get-RawSha256 -Path $stdoutPath
        } else { $null }
        stderr_raw_sha256 = if (Test-Path -LiteralPath $stderrPath -PathType Leaf) {
            Get-RawSha256 -Path $stderrPath
        } else { $null }
        operation_lock = $operationLockPublic
    }
    Write-NewJsonFile -Path $completionPath -Value $completion

    Assert-Exact ($null -ne $process) (
        "$gateId process launch failed after attempt reservation: $launchError"
    )
    Assert-Exact (Test-Path -LiteralPath $reportPath -PathType Leaf) (
        "$gateId process exited without retaining report.json"
    )
    $report = Get-Content -Raw -LiteralPath $reportPath |
        ConvertFrom-Json -AsHashtable -Depth 100
    Assert-Exact (
        [string]$report.campaign_id -ceq $campaignId -and
        [string]$report.gate_id -ceq $gateId -and
        [string]$report.source_commit -ceq $sourceCommit -and
        [string]$report.preregistration_raw_sha256 -ceq $expectedPreregistrationSha256 -and
        [string]$report.mv2_closure_raw_sha256 -ceq
            ("sha256:0ef035bf76ebfc2c2ded74912cd5219f51304ae13086407324a5fbc491fec51c") -and
        [string]$report.preworld_real_dynamic_library_profile_canary.library_raw_sha256 -ceq
            [string]$attempt.locomotion_core_library_raw_sha256 -and
        [string]$report.preworld_real_dynamic_library_profile_canary.
            positive_mapping_receipt_sha256 -ceq
            [string]$attempt.preworld_mapping_receipt_raw_sha256 -and
        [bool]$report.preworld_compiled_morphology_report_assembly_canary.ok -and
        [bool]$report.preworld_compiled_morphology_report_assembly_canary.
            shared_physical_assembler_executed -and
        [string]$report.morphology_id -ceq "qsdk_r05_generated_s169" -and
        [string]$report.descriptor_sha256 -ceq
            "sha256:ae7a0872b8b15dfb294c388931899cf82822293417d125dd72ee2a5a847e09e0" -and
        [int]$report.world_attempt_count -eq 1 -and
        [int]$report.world_build_count -eq 1 -and
        [int]$report.trace_step_count -eq 2992 -and
        [int]$report.ordered_trace.Count -eq 2992 -and
        -not [bool]$report.claim_boundary.cross_engine_selected_policy_equivalence -and
        -not [bool]$report.claim_boundary.release_authorized -and
        -not [bool]$report.claim_boundary.physical_acceptance_authority
    ) "$gateId retained report identity, integrity, or claim boundary is invalid"

    Write-Host (
        "$gateId retained at $resolvedOutputRoot; ok=$($report.ok) " +
        "steps=$($report.trace_step_count) exit=$($process.ExitCode)"
    )
    if ($process.ExitCode -ne 0 -or -not [bool]$report.ok) {
        throw (
            "$gateId retained a complete negative report. Close it without " +
            "rerun, rethresholding, or world replacement."
        )
    }
} finally {
    if ($null -ne $operationLockReceipt) {
        Exit-SporeSporeLocomotionOperationLock -Receipt $operationLockReceipt
    }
}
