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
    $repoPrefix = $RepoRoot.TrimEnd(
        [IO.Path]::DirectorySeparatorChar,
        [IO.Path]::AltDirectorySeparatorChar
    ) + [IO.Path]::DirectorySeparatorChar
    Assert-Exact (
        $path.StartsWith($repoPrefix, [StringComparison]::OrdinalIgnoreCase) -and
        (Test-Path -LiteralPath $path -PathType Leaf) -and
        (Get-RawSha256 -Path $path) -ceq
            ("sha256:" + $ExpectedRawSha256.Replace("sha256:", ""))
    ) "C6-MJC-HC-VH4 pinned repository file mismatch: $RelativePath"
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
$preregistrationPath = Join-Path (
    $sdkRoot
) "mujoco_c6_velocity_only_stability_host_characterization_vh4_preregistration.json"
$closurePath = Join-Path (
    $sdkRoot
) "mujoco_c6_velocity_only_stability_host_characterization_vh4_closure.json"
$implementationPath = Join-Path (
    $mujocoRoot
) "sporespore_mujoco_adapter\velocity_only_stability_characterization_vh4.py"
$requirementsLockPath = Join-Path $mujocoRoot "requirements-lock.txt"
$operationLockPath = Join-Path $sdkRoot "locomotion_operation_lock.ps1"
$attestationVerifierPath = Join-Path (
    $sdkRoot
) "locomotion_full_conformance_attestation.ps1"
$expectedPreregistrationSha256 = (
    "sha256:291c004730a689db9d244fda0ec4e51a171f3abf267fcd01fdd016f8171904b7"
)
$campaignId = "C6-MUJOCO-VELOCITY-ONLY-STABILITY-HOST-CHARACTERIZATION-VH4"
$gateId = "C6-MJC-HC-VH4"
$evidenceRoot = [IO.Path]::GetFullPath(
    (Join-Path (Split-Path -Parent $repoRoot) "SporeSpore_Evidence")
)

# Once an identity-consuming physical process has been retained, closure is
# the first physical-mode authority. Refuse before mutable checkout checks,
# attestation parsing, preflight replay, lock acquisition, or model creation.
if (
    $RunPhysical.IsPresent -and
    (Test-Path -LiteralPath $closurePath -PathType Leaf)
) {
    throw "$gateId is closed and may not open another world; audit the closure instead"
}

Assert-Exact (
    (git -C $repoRoot rev-parse --show-toplevel).Trim() -ceq
        $repoRoot.Replace("\", "/")
) "$gateId repository identity mismatch"
Assert-Exact (
    (git -C $repoRoot remote get-url origin).Trim() -ceq
        "https://github.com/Slagathore/sporespore.git"
) "$gateId origin identity mismatch"
foreach ($path in @(
    $python,
    $preregistrationPath,
    $implementationPath,
    $requirementsLockPath,
    $operationLockPath,
    $attestationVerifierPath
)) {
    Assert-Exact (
        Test-Path -LiteralPath $path -PathType Leaf
    ) "$gateId required source or environment file is missing: $path"
}
Assert-Exact (
    (Get-RawSha256 -Path $preregistrationPath) -ceq
        $expectedPreregistrationSha256
) "$gateId preregistration hash mismatch"

$preregistration = Get-Content -Raw -LiteralPath $preregistrationPath |
    ConvertFrom-Json -AsHashtable -Depth 64
Assert-Exact (
    [string]$preregistration.campaign_id -ceq $campaignId -and
    [string]$preregistration.gate_id -ceq $gateId -and
    [string]$preregistration.status -ceq
        "frozen_before_first_c6_mjc_hc_vh4_physics_world" -and
    [string]$preregistration.implementation_parent_commit -ceq
        "1501e7e278b660810623db9b865082388cc6c27f" -and
    [int]$preregistration.host_identity.solver_iterations -eq 20 -and
    [int]$preregistration.host_identity.line_search_iterations -eq 7 -and
    [int]$preregistration.physical_grid.worlds -eq 24 -and
    [int]$preregistration.physical_grid.replacement_worlds -eq 0 -and
    [bool]$preregistration.execution_contract.
        physical_execution_requires_global_locomotion_operation_lock -and
    [bool]$preregistration.execution_contract.
        physical_execution_requires_exact_full_godot_v2_conformance_attestation -and
    [int]$preregistration.preflight_contract.negative_control_count -eq 23 -and
    [int]$preregistration.preflight_contract.binding_surface_canary_count -eq 5 -and
    [bool]$preregistration.preflight_contract.
        must_verify_python_binding_surface_before_any_world -and
    [bool]$preregistration.fixture.physical_generalized_inertia_readback_required -and
    -not [bool]$preregistration.claim_boundary.mujoco_selected_policy_locomotion -and
    -not [bool]$preregistration.claim_boundary.mujoco_walking -and
    -not [bool]$preregistration.claim_boundary.physical_acceptance_authority
) "$gateId preregistration identity or execution boundary changed"

foreach ($declaredFile in @(
    @{
        path = [string]$preregistration.semantic_parent.profile_path
        hash = [string]$preregistration.semantic_parent.profile_raw_sha256
    },
    @{
        path = [string]$preregistration.semantic_parent.semantics_path
        hash = [string]$preregistration.semantic_parent.semantics_raw_sha256
    },
    @{
        path = [string]$preregistration.semantic_parent.canonical_implementation_path
        hash = [string]$preregistration.semantic_parent.canonical_implementation_raw_sha256
    },
    @{
        path = [string]$preregistration.semantic_parent.rapier_velocity_only_closure_path
        hash = [string]$preregistration.semantic_parent.rapier_velocity_only_closure_raw_sha256
    },
    @{
        path = [string]$preregistration.scientifically_distinct_successor.vh1_closure_path
        hash = [string]$preregistration.scientifically_distinct_successor.vh1_closure_raw_sha256
    },
    @{
        path = [string]$preregistration.scientifically_distinct_successor.vh2_closure_path
        hash = [string]$preregistration.scientifically_distinct_successor.vh2_closure_raw_sha256
    },
    @{
        path = [string]$preregistration.scientifically_distinct_successor.vh3_closure_path
        hash = [string]$preregistration.scientifically_distinct_successor.vh3_closure_raw_sha256
    },
    @{
        path = [string]$preregistration.host_source_semantics.requirements_lock_path
        hash = [string]$preregistration.host_source_semantics.requirements_lock_windows_checkout_raw_sha256
    }
)) {
    Assert-DeclaredRepoFile `
        -RelativePath ([string]$declaredFile.path) `
        -ExpectedRawSha256 ([string]$declaredFile.hash) `
        -RepoRoot $repoRoot
}

# This is the first executable experiment gate. The module verifies the exact
# interpreter/wheel files and Python binding surface, routes a perfect report
# plus twenty-three negative controls through the production evaluator, and does
# not construct an MjModel.
Push-Location -LiteralPath $mujocoRoot
try {
    $preflightLines = @(
        & $python `
            -m sporespore_mujoco_adapter.velocity_only_stability_characterization_vh4 `
            --preflight-only
    )
    Assert-Exact (
        $LASTEXITCODE -eq 0
    ) "$gateId zero-world preflight failed"
} finally {
    Pop-Location
}
$preflightText = $preflightLines -join [Environment]::NewLine
$preflight = $preflightText | ConvertFrom-Json -AsHashtable -Depth 64
Assert-Exact (
    [bool]$preflight.ok -and
    [bool]$preflight.perfect_synthetic_result_passed -and
    [bool]$preflight.perfect_synthetic_serialization_round_trip_passed -and
    [int]$preflight.declared_cell_count -eq 24 -and
    [int]$preflight.declared_internal_trace_record_count -eq 43200 -and
    [int]$preflight.negative_control_count -eq 23 -and
    @($preflight.negative_controls_rejected.Values | Where-Object {
        -not [bool]$_
    }).Count -eq 0 -and
    [int]$preflight.host_identity.verified_wheel_file_count -eq 9 -and
    [int]$preflight.binding_surface_canary_count -eq 5 -and
    @($preflight.binding_surface_canaries_passed.Values | Where-Object {
        -not [bool]$_
    }).Count -eq 0 -and
    [bool]$preflight.host_identity.binding_surface.mjdata_has_M -and
    -not [bool]$preflight.host_identity.binding_surface.mjdata_has_qM -and
    [int]$preflight.host_identity.world_build_count -eq 0 -and
    [int]$preflight.world_build_count -eq 0 -and
    -not [bool]$preflight.physics_state_modified -and
    -not [bool]$preflight.physical_acceptance_authority
) "$gateId zero-world preflight receipt is incomplete or inflated"

if ($PreflightOnly) {
    Write-Host (
        "$gateId zero-world preflight passed: cells=24 traces=43200 " +
        "negative_controls=23 binding_canaries=5 wheel_files=9 " +
        "solver=20/7 worlds=0 " +
        "physical_authority=False"
    )
    return
}

Assert-Exact (
    -not [string]::IsNullOrWhiteSpace($FullConformanceAttestation)
) "$gateId -RunPhysical requires an exact full-Godot V2 attestation"
Assert-Exact (
    -not (Test-Path -LiteralPath $closurePath -PathType Leaf)
) "$gateId is closed and may not open another world; audit the closure instead"
$priorEvidence = @(
    Get-ChildItem -LiteralPath $evidenceRoot `
        -Directory `
        -Filter "c6-mujoco-velocity-only-stability-vh4-*" `
        -ErrorAction SilentlyContinue
)
Assert-Exact (
    $priorEvidence.Count -eq 0
) "$gateId prior evidence exists; same-identity rerun is forbidden"

. $operationLockPath
. $attestationVerifierPath
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
        $sourceCommit -cne [string]$preregistration.implementation_parent_commit -and
        $sourceCommit -ceq $originMain -and
        $sourceCommit -ceq $liveMain -and
        $status.Count -eq 0
    ) "$gateId physical execution requires distinct clean HEAD == origin/main == live GitHub main"

    $godotPath = [IO.Path]::GetFullPath($Godot)
    $resolvedAttestationPath = [IO.Path]::GetFullPath(
        $FullConformanceAttestation
    )
    $attestationVerification = Test-SporeSporeFullConformanceAttestationFile `
        -RepoRoot $repoRoot `
        -Godot $godotPath `
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
    $attestationSha256 = Get-RawSha256 -Path $resolvedAttestationPath

    $shortCommit = $sourceCommit.Substring(0, 7)
    if ([string]::IsNullOrWhiteSpace($OutputRoot)) {
        $OutputRoot = Join-Path (
            $evidenceRoot
        ) "c6-mujoco-velocity-only-stability-vh4-$shortCommit"
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
            "c6-mujoco-velocity-only-stability-vh4-$shortCommit" -and
        -not (Test-Path -LiteralPath $resolvedOutputRoot)
    ) "$gateId output root must be new, exact, and under SporeSpore_Evidence"
    [void][IO.Directory]::CreateDirectory($resolvedOutputRoot)

    $preflightPath = Join-Path $resolvedOutputRoot "preflight.json"
    $attemptPath = Join-Path $resolvedOutputRoot "attempt.json"
    $completionPath = Join-Path $resolvedOutputRoot "completion.json"
    $reportPath = Join-Path $resolvedOutputRoot "report.json"
    $stdoutPath = Join-Path $resolvedOutputRoot "stdout.log"
    $stderrPath = Join-Path $resolvedOutputRoot "stderr.log"
    Write-NewUtf8TextFile `
        -Path $preflightPath `
        -Text ($preflightText + [Environment]::NewLine)

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
        runner_raw_sha256 = Get-RawSha256 -Path $PSCommandPath
        requirements_lock_raw_sha256 = Get-RawSha256 -Path $requirementsLockPath
        preflight_path = $preflightPath.Replace("\", "/")
        preflight_raw_sha256 = Get-RawSha256 -Path $preflightPath
        full_conformance_attestation_path = $resolvedAttestationPath.Replace("\", "/")
        full_conformance_attestation_raw_sha256 = $attestationSha256
        full_conformance_attestation_source_commit = [string]$attestation.source.commit
        operation_lock = $operationLockPublic
        exact_host_identity = $preflight.host_identity
        physical_process_launch_consumes_identity = $true
        replacement_processes_allowed = 0
    }
    Write-NewJsonFile -Path $attemptPath -Value $attempt

    # Recheck source and the byte-pinned study immediately before the one
    # permitted physical process launch.
    Assert-Exact (
        @(git -C $repoRoot status --porcelain=v1 --untracked-files=all).Count -eq 0 -and
        (git -C $repoRoot rev-parse HEAD).Trim() -ceq $sourceCommit -and
        (Get-RawSha256 -Path $preregistrationPath) -ceq
            $expectedPreregistrationSha256 -and
        (Get-RawSha256 -Path $implementationPath) -ceq
            [string]$attempt.implementation_raw_sha256 -and
        (Get-RawSha256 -Path $PSCommandPath) -ceq
            [string]$attempt.runner_raw_sha256 -and
        (Get-RawSha256 -Path $requirementsLockPath) -ceq
            [string]$attempt.requirements_lock_raw_sha256 -and
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
                "sporespore_mujoco_adapter.velocity_only_stability_characterization_vh4",
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
    Assert-Exact (
        Test-Path -LiteralPath $reportPath -PathType Leaf
    ) "$gateId process exited without retaining report.json"
    $report = Get-Content -Raw -LiteralPath $reportPath |
        ConvertFrom-Json -AsHashtable -Depth 64
    Assert-Exact (
        [string]$report.campaign_id -ceq $campaignId -and
        [string]$report.gate_id -ceq $gateId -and
        [string]$report.source.commit -ceq $sourceCommit -and
        [string]$report.preregistration.raw_sha256 -ceq
            $expectedPreregistrationSha256 -and
        [int]$report.host.solver_iterations -eq 20 -and
        [int]$report.host.line_search_iterations -eq 7 -and
        [bool]$report.host.binding_surface.mjdata_has_M -and
        -not [bool]$report.host.binding_surface.mjdata_has_qM -and
        [int]$report.integrity.world_attempt_count -eq 24 -and
        [int]$report.integrity.world_build_count -eq 24 -and
        [int]$report.integrity.internal_trace_record_count -eq 43200 -and
        [int]$report.integrity.generalized_inertia_readback_mismatch_count -eq 0 -and
        [int]$report.integrity.saturated_step_force_time_to_momentum_mismatch_count -eq 0 -and
        [int]$report.integrity.unsaturated_post_state_force_time_to_momentum_mismatch_count -eq 0 -and
        [int]$report.integrity.temporal_force_distinction_missing_count -eq 0 -and
        [int]$report.cells.Count -eq 24 -and
        [int]$report.mirrored_pairs.Count -eq 12 -and
        [bool]$report.motor_profile.finite_dynamic_force_saturation_recovery_characterized_if_passed -and
        -not [bool]$report.controller_policy_authority -and
        -not [bool]$report.selected_policy_physical_authority -and
        -not [bool]$report.physical_acceptance_authority
    ) "$gateId retained report identity, integrity, or claim boundary is invalid"

    Write-Host (
        "$gateId retained at $resolvedOutputRoot; " +
        "passed=$($report.passed_cells)/24 ok=$($report.ok) " +
        "exit=$($process.ExitCode)"
    )
    if ($process.ExitCode -ne 0 -or -not [bool]$report.ok) {
        throw (
            "$gateId retained a complete negative report. Close it without " +
            "rerun, rethresholding, or cell replacement."
        )
    }
} finally {
    if ($null -ne $operationLockReceipt) {
        Exit-SporeSporeLocomotionOperationLock -Receipt $operationLockReceipt
    }
}
