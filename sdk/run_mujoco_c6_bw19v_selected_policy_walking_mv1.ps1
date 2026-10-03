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
    "mujoco_c6_bw19v_selected_policy_walking_mv1_preregistration.json"
)
$implementationPath = Join-Path $mujocoRoot (
    "sporespore_mujoco_adapter\selected_policy_walking_mv1.py"
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
$selectedPolicyClosurePath = Join-Path $sdkRoot "balanced_wave_bw19v_closure_manifest.json"
$requirementsLockPath = Join-Path $mujocoRoot "requirements-lock.txt"
$closurePath = Join-Path $sdkRoot (
    "mujoco_c6_bw19v_selected_policy_walking_mv1_closure.json"
)
$operationLockPath = Join-Path $sdkRoot "locomotion_operation_lock.ps1"
$attestationVerifierPath = Join-Path $sdkRoot (
    "locomotion_full_conformance_attestation.ps1"
)
$expectedPreregistrationSha256 = (
    "sha256:586ca4df0eed8040cfbf6a94eee3913ebec96b0e1c0d899a468b71d43cd0a050"
)
$campaignId = "C6-MUJOCO-BW19V-SELECTED-POLICY-WALKING-MV1"
$gateId = "C6-MJC-BW19V-MV1"
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
    "sdk/mujoco_c6_bw19v_selected_policy_walking_mv1_preregistration.json" = "586ca4df0eed8040cfbf6a94eee3913ebec96b0e1c0d899a468b71d43cd0a050"
    "sdk/adapters/mujoco/sporespore_mujoco_adapter/selected_policy_walking_mv1.py" = "5f69ebb4e10fb00a6da760667cd643920970d07026feb1341458e8051f822cac"
    "sdk/adapters/mujoco/sporespore_mujoco_adapter/selected_policy_development.py" = "306669481601cc91c8146e84a202a57228672e23c3f9daa0c531d2eb9d077e46"
    "sdk/mujoco_c6_s169_per_actuator_force_limit_host_characterization_vh5_closure.json" = "fbb8441fb8a3907c56155db777de00ce8b6e2f293ef67e77a2a30d2eeeb0f34f"
    "sdk/rapier_c6_bw19v_velocity_only_long_horizon_commissioning_lc1_preregistration.json" = "a5e88d5e0f69772c7dec67cc0d8bd83aa903ab2fe642a301fbf8ed3f09b47d0b"
    "sdk/balanced_wave_bw19v_closure_manifest.json" = "ea8df6a574e1b9be1050afa8ed57982a102982ada0f0d5babccf3c937c7067f7"
    "sdk/core/src/canonical_actuation.rs" = "33082ebac939141dc6999a9e9d5743a156fa8f89f67b077042fb906518a6e198"
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
        "frozen_before_first_c6_mjc_bw19v_mv1_physics_world" -and
    [int]$declaration.physical_horizon.expected_world_count -eq 1 -and
    [int]$declaration.physical_horizon.total_controller_semantic_steps -eq 2992 -and
    [int]$declaration.physical_horizon.expected_commands_per_layer -eq 23936 -and
    [int]$declaration.preflight_contract.negative_control_count -eq 24 -and
    [bool]$declaration.claims_if_passed.exact_s169_mujoco_bw19v_mv1_walking -and
    -not [bool]$declaration.claims_if_passed.cross_engine_selected_policy_equivalence -and
    -not [bool]$declaration.claims_if_passed.release_authorized -and
    -not [bool]$declaration.claims_if_passed.physical_acceptance_authority
) "$gateId preregistration identity, horizon, or claim boundary changed"

Push-Location -LiteralPath $mujocoRoot
try {
    $preflightLines = @(
        & $python `
            -m sporespore_mujoco_adapter.selected_policy_walking_mv1 `
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
    [int]$preflight.negative_control_count -eq 24 -and
    @($preflight.negative_controls_rejected.Values | Where-Object { -not [bool]$_ }).Count -eq 0 -and
    [int]$preflight.world_build_count -eq 0 -and
    [int]$preflight.scene_insertion_count -eq 0 -and
    -not [bool]$preflight.physics_state_modified -and
    -not [bool]$preflight.locomotion_outcome_exposed -and
    -not [bool]$preflight.physical_acceptance_authority
) "$gateId zero-world preflight receipt is incomplete or inflated"

if ($PreflightOnly) {
    Write-Host (
        "C6_MJC_BW19V_MV1_FREEZE_PASS worlds=0 steps=2992 commands=23936 " +
        "canaries=24 physical_authority=False"
    )
    return
}

Assert-Exact (
    -not [string]::IsNullOrWhiteSpace($FullConformanceAttestation)
) "$gateId -RunPhysical requires an exact full-Godot V2 attestation"
$priorEvidence = @(
    Get-ChildItem -LiteralPath $evidenceRoot `
        -Directory `
        -Filter "c6-mujoco-bw19v-mv1-*" `
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
        $OutputRoot = Join-Path $evidenceRoot "c6-mujoco-bw19v-mv1-$shortCommit"
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
            "c6-mujoco-bw19v-mv1-$shortCommit" -and
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
                "sporespore_mujoco_adapter.selected_policy_walking_mv1",
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
