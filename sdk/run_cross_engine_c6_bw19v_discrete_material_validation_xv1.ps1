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
    }
    finally {
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
        -Text (($Value | ConvertTo-Json -Depth 100) + [Environment]::NewLine)
}

function Get-IntegerSum {
    param(
        [Parameter(Mandatory)][object]$Map,
        [Parameter(Mandatory)][string[]]$Fields
    )
    $sum = 0L
    foreach ($field in $Fields) {
        $value = Get-Xv1MapValue $Map $field 0
        if ($null -ne $value) {
            $sum += [int64]$value
        }
    }
    return $sum
}

function Test-Xv1PhysicalIntegrity {
    param(
        [Parameter(Mandatory)][string]$RepoRoot,
        [Parameter(Mandatory)][string]$SourceCommit,
        [Parameter(Mandatory)][string]$SourceTree,
        [Parameter(Mandatory)][string]$OriginMain,
        [Parameter(Mandatory)][System.Collections.IDictionary]$FrozenFiles,
        [switch]$CheckLiveRemote
    )

    $failures = [System.Collections.Generic.List[string]]::new()
    $headMatches = $false
    $treeMatches = $false
    $originMainMatches = $false
    $worktreeClean = $false
    $liveMainMatches = -not $CheckLiveRemote.IsPresent
    $frozenFilesMatch = $true
    try {
        $head = (git -C $RepoRoot rev-parse HEAD).Trim()
        $headMatches = $LASTEXITCODE -eq 0 -and $head -ceq $SourceCommit
        if (-not $headMatches) {
            $failures.Add("SOURCE_HEAD_DRIFT")
        }
        $tree = (git -C $RepoRoot rev-parse 'HEAD^{tree}').Trim()
        $treeMatches = $LASTEXITCODE -eq 0 -and $tree -ceq $SourceTree
        if (-not $treeMatches) {
            $failures.Add("SOURCE_TREE_DRIFT")
        }
        $currentOriginMain = (git -C $RepoRoot rev-parse origin/main).Trim()
        $originMainMatches = (
            $LASTEXITCODE -eq 0 -and $currentOriginMain -ceq $OriginMain
        )
        if (-not $originMainMatches) {
            $failures.Add("ORIGIN_MAIN_DRIFT")
        }
        $status = @(git -C $RepoRoot status --porcelain=v1 --untracked-files=all)
        $worktreeClean = $LASTEXITCODE -eq 0 -and $status.Count -eq 0
        if (-not $worktreeClean) {
            $failures.Add("WORKTREE_DRIFT")
        }
        if ($CheckLiveRemote) {
            $remoteLine = @(git -C $RepoRoot ls-remote origin refs/heads/main)
            $liveMain = if ($LASTEXITCODE -eq 0 -and $remoteLine.Count -eq 1) {
                ($remoteLine[0] -split "\s+")[0]
            }
            else { "" }
            $liveMainMatches = $liveMain -ceq $SourceCommit
            if (-not $liveMainMatches) {
                $failures.Add("LIVE_GITHUB_MAIN_DRIFT_OR_UNAVAILABLE")
            }
        }
        foreach ($entry in $FrozenFiles.GetEnumerator()) {
            $path = [string]$entry.Key
            if (
                -not (Test-Path -LiteralPath $path -PathType Leaf) -or
                (Get-RawSha256 $path) -cne [string]$entry.Value
            ) {
                $frozenFilesMatch = $false
                $failures.Add("FROZEN_FILE_DRIFT::$path")
            }
        }
    }
    catch {
        $frozenFilesMatch = $false
        $failures.Add("INTEGRITY_CHECK_EXCEPTION::$($_.Exception.Message)")
    }
    return [ordered]@{
        ok = $failures.Count -eq 0
        failure_codes = @($failures)
        source_head_matches = $headMatches
        source_tree_matches = $treeMatches
        origin_main_matches = $originMainMatches
        worktree_clean = $worktreeClean
        live_github_main_matches = $liveMainMatches
        frozen_files_match = $frozenFilesMatch
    }
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
$rapierBinary = Join-Path $sdkRoot (
    "target\release\cross_engine_discrete_material_validation_xv1_rapier.exe"
)
$preregistrationPath = Join-Path $sdkRoot (
    "cross_engine_c6_bw19v_discrete_material_validation_xv1_preregistration.json"
)
$gatePath = Join-Path $sdkRoot (
    "cross_engine_c6_bw19v_discrete_material_validation_xv1_gate.ps1"
)
$closurePath = Join-Path $sdkRoot (
    "cross_engine_c6_bw19v_discrete_material_validation_xv1_closure.json"
)
$operationLockPath = Join-Path $sdkRoot "locomotion_operation_lock.ps1"
$attestationVerifierPath = Join-Path $sdkRoot (
    "locomotion_full_conformance_attestation.ps1"
)
$campaignId = "C6-CROSS-ENGINE-BW19V-DISCRETE-MATERIAL-VALIDATION-XV1"
$gateId = "C6-XE-BW19V-XV1"
$implementationParentCommit = "f07261c9fd90b70cc3f435ffa63eccee6333ef13"
$evidenceRoot = [IO.Path]::GetFullPath(
    (Join-Path (Split-Path -Parent $repoRoot) "SporeSpore_Evidence")
)

if ($RunPhysical.IsPresent -and (Test-Path -LiteralPath $closurePath -PathType Leaf)) {
    throw "$gateId is closed and may not open another world; audit the closure instead"
}
if (
    $RunPhysical.IsPresent -and
    [string]::IsNullOrWhiteSpace($FullConformanceAttestation)
) {
    throw "$gateId -RunPhysical requires an exact full-Godot V2 attestation"
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
    $gatePath,
    $operationLockPath,
    $attestationVerifierPath
)) {
    Assert-Exact (Test-Path -LiteralPath $path -PathType Leaf) (
        "$gateId required source or environment file is missing: $path"
    )
}

$pinnedAuthorityFiles = [ordered]@{
    "sdk/cross_engine_c6_host_characterization_r2_closure.json" =
        "a7b1b3c172b98780f574cec9dbb18bebda35429ece5105a0385ecb7d67d6ddd9"
    "sdk/rapier_c6_force_based_selected_configuration_validation_spv1_closure.json" =
        "7830f66de49f1d7c2d5b88d151c0c2d5077782903457837d7ecd0da2fb724203"
    "sdk/rapier_c6_force_based_velocity_only_host_characterization_vh1_closure.json" =
        "d94b20ef4767479172408c1dfbd0b7f66e18e3f4bc8b9d8d84193fc157d284aa"
    "sdk/rapier_c6_bw19v_velocity_only_pose_hold_restoration_ph1_closure.json" =
        "e2fd42545d59908db69f9fe34a18453afafe4273a02618be0b531f6443e040db"
    "sdk/mujoco_c6_s169_per_actuator_force_limit_host_characterization_vh5_closure.json" =
        "fbb8441fb8a3907c56155db777de00ce8b6e2f293ef67e77a2a30d2eeeb0f34f"
    "sdk/mujoco_c6_bw19v_selected_policy_pose_hold_restoration_mv6_closure.json" =
        "5da3675d848c1d127419c43f009fb430c4f02abd2a55da730ea70fca6d3cee09"
}
Assert-Exact (
    (Get-RawSha256 $preregistrationPath) -ceq
        "sha256:63277890098878651c3a30144b1e4d5e00f15b1a8f95917d202cade4dd46ae2f"
) "$gateId preregistration raw hash changed"
foreach ($entry in $pinnedAuthorityFiles.GetEnumerator()) {
    $path = [IO.Path]::GetFullPath((Join-Path $repoRoot ([string]$entry.Key)))
    Assert-Exact (
        (Test-Path -LiteralPath $path -PathType Leaf) -and
        (Get-RawSha256 $path) -ceq ("sha256:" + [string]$entry.Value)
    ) "$gateId bound authority changed: $($entry.Key)"
}
$declaration = Get-Content -Raw -LiteralPath $preregistrationPath |
    ConvertFrom-Json -AsHashtable -Depth 100
Assert-Exact (
    [string]$declaration.campaign_id -ceq $campaignId -and
    [string]$declaration.gate_id -ceq $gateId -and
    [string]$declaration.status -ceq
        "frozen_before_first_c6_xe_bw19v_xv1_physics_world" -and
    [string]$declaration.implementation_parent_commit -ceq $implementationParentCommit -and
    [int]$declaration.matrix.expected_world_count -eq 6 -and
    @($declaration.matrix.ordered_cells).Count -eq 6 -and
    [bool]$declaration.execution_contract.all_six_cells_execute_serially_under_one_operation_lock -and
    [bool]$declaration.execution_contract.all_six_cell_attempts_are_made_even_if_an_earlier_cell_fails -and
    -not [bool]$declaration.claims_if_accepted.formal_cross_engine_equivalence -and
    -not [bool]$declaration.claims_if_accepted.release_authorized -and
    -not [bool]$declaration.claims_if_accepted.physical_acceptance_authority
) "$gateId preregistration identity, matrix, execution, or claim boundary changed"

. $gatePath
$aggregatePreflight = Invoke-CrossEngineC6Bw19vDiscreteMaterialValidationXv1Preflight
Assert-Exact (
    [bool]$aggregatePreflight.ok -and
    [int]$aggregatePreflight.negative_control_count -eq 22 -and
    [int]$aggregatePreflight.model_or_world_build_count -eq 0 -and
    -not [bool]$aggregatePreflight.physical_acceptance_authority
) "$gateId aggregate zero-world preflight failed"

$buildLines = @(& cargo build `
    --manifest-path (Join-Path $sdkRoot "Cargo.toml") `
    --release `
    -p sporespore-rapier-adapter `
    --bin cross_engine_discrete_material_validation_xv1_rapier 2>&1)
Assert-Exact ($LASTEXITCODE -eq 0) (
    "$gateId Rapier release worker build failed: " + ($buildLines -join "`n")
)
Assert-Exact (Test-Path -LiteralPath $rapierBinary -PathType Leaf) (
    "$gateId Rapier release worker is missing after build"
)

$rapierPreflightLines = @(& $rapierBinary --preflight-only)
Assert-Exact ($LASTEXITCODE -eq 0) "$gateId Rapier zero-world preflight failed"
$rapierPreflight = ($rapierPreflightLines -join [Environment]::NewLine) |
    ConvertFrom-Json -AsHashtable -Depth 100
Assert-Exact (
    [bool]$rapierPreflight.ok -and
    [int]$rapierPreflight.declared_material_cell_count -eq 3 -and
    [bool]$rapierPreflight.all_declared_material_synthetic_gates_passed -and
    [int]$rapierPreflight.negative_control_count -eq 38 -and
    [bool]$rapierPreflight.all_negative_controls_rejected -and
    [int]$rapierPreflight.world_build_count -eq 0
) "$gateId Rapier zero-world preflight receipt is incomplete"

Push-Location -LiteralPath $mujocoRoot
try {
    $mujocoPreflightLines = @(
        & $python `
            -m sporespore_mujoco_adapter.cross_engine_discrete_material_validation_xv1_mujoco `
            --preflight-only
    )
    Assert-Exact ($LASTEXITCODE -eq 0) "$gateId MuJoCo zero-world preflight failed"
}
finally {
    Pop-Location
}
$mujocoPreflight = ($mujocoPreflightLines -join [Environment]::NewLine) |
    ConvertFrom-Json -AsHashtable -Depth 100
Assert-Exact (
    [bool]$mujocoPreflight.ok -and
    [int]$mujocoPreflight.declared_material_cell_count -eq 3 -and
    [bool]$mujocoPreflight.all_declared_material_synthetic_gates_passed -and
    [int]$mujocoPreflight.negative_control_count -eq 57 -and
    [bool]$mujocoPreflight.material_xml_authoring_canary.ok -and
    [int]$mujocoPreflight.material_xml_authoring_canary.negative_control_count -eq 6 -and
    [int]$mujocoPreflight.model_construction_count -eq 0 -and
    [int]$mujocoPreflight.world_build_count -eq 0
) "$gateId MuJoCo zero-world preflight receipt is incomplete"

$combinedPreflight = [ordered]@{
    schema_version = (
        "sporespore_cross_engine_c6_bw19v_discrete_material_validation_xv1_combined_preflight_v1"
    )
    ok = $true
    campaign_id = $campaignId
    gate_id = $gateId
    aggregate = $aggregatePreflight
    rapier = $rapierPreflight
    mujoco = $mujocoPreflight
    total_negative_control_count = 22 + 38 + 57
    model_or_world_build_count = 0
    locomotion_outcome_exposed = $false
    physical_acceptance_authority = $false
}
if ($PreflightOnly) {
    Write-Host (
        "C6_XE_BW19V_XV1_FREEZE_PASS worlds=0 aggregate=22 " +
        "rapier=38 mujoco=57 material_cells=6 physical_authority=False"
    )
    return
}

if (Test-Path -LiteralPath $evidenceRoot -PathType Container) {
    $priorAttempts = @(
        Get-ChildItem -LiteralPath $evidenceRoot -Recurse -File -Filter "attempt.json" |
        Where-Object {
            try {
                $receipt = Get-Content -Raw -LiteralPath $_.FullName |
                    ConvertFrom-Json
                [string]$receipt.campaign_id -ceq $campaignId
            }
            catch { $false }
        }
    )
    Assert-Exact ($priorAttempts.Count -eq 0) (
        "$gateId already has a retained physical attempt and may not rerun"
    )
}

. $operationLockPath
. $attestationVerifierPath
$operationLockReceipt = $null
$attemptConsumed = $false
$completionWritten = $false
$completionPath = $null
$attemptId = $null
$sourceCommit = $null
$resolvedOutputRoot = $null
$processLaunchCount = 0
$cellSummaries = [System.Collections.Generic.List[object]]::new()
$operationLockReceipt = Enter-SporeSporeLocomotionOperationLock -Role physical
Assert-Exact (
    [bool]$operationLockReceipt.acquired -and
    [string]$operationLockReceipt.role -ceq "physical" -and
    -not [bool]$operationLockReceipt.test_only
) "$gateId could not acquire the global physical-operation lock"

try {
    $sourceCommit = (git -C $repoRoot rev-parse HEAD).Trim()
    $sourceTree = (git -C $repoRoot rev-parse 'HEAD^{tree}').Trim()
    $originMain = (git -C $repoRoot rev-parse origin/main).Trim()
    $status = @(git -C $repoRoot status --porcelain=v1 --untracked-files=all)
    $remoteLine = @(git -C $repoRoot ls-remote origin refs/heads/main)
    $liveMain = if ($remoteLine.Count -eq 1) {
        ($remoteLine[0] -split "\s+")[0]
    }
    else { "" }
    Assert-Exact (
        (Test-Xv1Commit $sourceCommit) -and
        (Test-Xv1Commit $sourceTree) -and
        $sourceCommit -cne $implementationParentCommit -and
        $sourceCommit -ceq $originMain -and
        $sourceCommit -ceq $liveMain -and
        $status.Count -eq 0
    ) "$gateId requires distinct clean HEAD == origin/main == live GitHub main"

    $resolvedAttestationPath = [IO.Path]::GetFullPath($FullConformanceAttestation)
    $attestationVerification = Test-SporeSporeFullConformanceAttestationFile `
        -RepoRoot $repoRoot `
        -Godot ([IO.Path]::GetFullPath($Godot)) `
        -AttestationPath $resolvedAttestationPath
    Assert-Exact (
        [bool]$attestationVerification.ok -and
        @($attestationVerification.failure_codes).Count -eq 0
    ) (
        "$gateId exact full-Godot V2 attestation failed: " +
        (@($attestationVerification.failure_codes) -join ",")
    )
    $attestation = Get-Content -Raw -LiteralPath $resolvedAttestationPath |
        ConvertFrom-Json -AsHashtable -Depth 100
    Assert-Exact (
        [string]$attestation.schema_version -ceq
            "sporespore_full_godot_conformance_attestation_v2" -and
        [string]$attestation.source.commit -ceq $sourceCommit -and
        [string]$attestation.source.tree_git_oid -ceq $sourceTree -and
        [string]$attestation.source.origin_main -ceq $sourceCommit -and
        [string]$attestation.source.live_github_main -ceq $sourceCommit -and
        [bool]$attestation.source.clean_pushed_live -and
        [bool]$attestation.conformance.passed -and
        -not [bool]$attestation.conformance.one_shot_physical_campaign_executed
    ) "$gateId full-Godot V2 attestation source or campaign boundary changed"
    foreach ($claimName in @($attestation.claims.Keys)) {
        Assert-Exact (-not [bool]$attestation.claims[$claimName]) (
            "$gateId full-Godot V2 attestation inflated claim: $claimName"
        )
    }

    $shortCommit = $sourceCommit.Substring(0, 7)
    if ([string]::IsNullOrWhiteSpace($OutputRoot)) {
        $OutputRoot = Join-Path $evidenceRoot "c6-cross-engine-bw19v-xv1-$shortCommit"
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
            "c6-cross-engine-bw19v-xv1-$shortCommit" -and
        -not (Test-Path -LiteralPath $resolvedOutputRoot)
    ) "$gateId output root must be new, exact, and beneath SporeSpore_Evidence"
    [void][IO.Directory]::CreateDirectory($resolvedOutputRoot)

    $preflightPath = Join-Path $resolvedOutputRoot "preflight.json"
    $attemptPath = Join-Path $resolvedOutputRoot "attempt.json"
    $reportPath = Join-Path $resolvedOutputRoot "report.json"
    $evaluationPath = Join-Path $resolvedOutputRoot "evaluation.json"
    $completionPath = Join-Path $resolvedOutputRoot "completion.json"
    Write-NewJsonFile $preflightPath $combinedPreflight

    $attemptId = [Guid]::NewGuid().ToString("N")
    $operationLockPublic = Get-SporeSporeLocomotionOperationLockPublicReceipt `
        -Receipt $operationLockReceipt
    $attempt = [ordered]@{
        schema_version = "sporespore_physical_attempt_reservation_v1"
        attempt_id = $attemptId
        campaign_id = $campaignId
        gate_id = $gateId
        status = "six_cell_physical_process_launch_reserved_identity_consumed"
        source_commit = $sourceCommit
        source_tree_git_oid = $sourceTree
        source_origin_main = $originMain
        source_live_github_main = $liveMain
        reserved_utc = [DateTime]::UtcNow.ToString("o")
        output_root = $resolvedOutputRoot.Replace("\", "/")
        preregistration_raw_sha256 = Get-RawSha256 $preregistrationPath
        gate_raw_sha256 = Get-RawSha256 $gatePath
        runner_raw_sha256 = Get-RawSha256 $PSCommandPath
        rapier_release_worker_path = $rapierBinary.Replace("\", "/")
        rapier_release_worker_raw_sha256 = Get-RawSha256 $rapierBinary
        combined_preflight_path = $preflightPath.Replace("\", "/")
        combined_preflight_raw_sha256 = Get-RawSha256 $preflightPath
        full_conformance_attestation_path = $resolvedAttestationPath.Replace("\", "/")
        full_conformance_attestation_raw_sha256 = Get-RawSha256 $resolvedAttestationPath
        operation_lock = $operationLockPublic
        declared_ordered_cells = @($declaration.matrix.ordered_cells)
        declared_world_count = 6
        all_cells_execute_even_after_earlier_failure = $true
        replacement_processes_allowed = 0
        physical_process_launch_consumes_identity = $true
        same_identity_rerun_allowed = $false
    }
    Write-NewJsonFile $attemptPath $attempt
    $attemptConsumed = $true

    $frozenPhysicalFiles = [ordered]@{
        $preregistrationPath = [string]$attempt.preregistration_raw_sha256
        $gatePath = [string]$attempt.gate_raw_sha256
        $PSCommandPath = [string]$attempt.runner_raw_sha256
        $rapierBinary = [string]$attempt.rapier_release_worker_raw_sha256
        $resolvedAttestationPath = [string]$attempt.full_conformance_attestation_raw_sha256
    }
    $reservationIntegrity = Test-Xv1PhysicalIntegrity `
        -RepoRoot $repoRoot `
        -SourceCommit $sourceCommit `
        -SourceTree $sourceTree `
        -OriginMain $originMain `
        -FrozenFiles $frozenPhysicalFiles `
        -CheckLiveRemote
    Assert-Exact ([bool]$reservationIntegrity.ok) (
        "$gateId source or executable changed after attempt reservation: " +
        (@($reservationIntegrity.failure_codes) -join ",")
    )

    $integrityAbortUsed = $false
    $integrityAbortCodes = [System.Collections.Generic.List[string]]::new()
    foreach ($cell in @($declaration.matrix.ordered_cells)) {
        $cellId = [string]$cell.cell_id
        $cellRoot = Join-Path $resolvedOutputRoot ("cells\" + $cellId)
        [void][IO.Directory]::CreateDirectory($cellRoot)
        $cellReportPath = Join-Path $cellRoot "report.json"
        $stdoutPath = Join-Path $cellRoot "stdout.log"
        $stderrPath = Join-Path $cellRoot "stderr.log"
        $coldEvaluationPath = Join-Path $cellRoot "cold_evaluation.json"
        $process = $null
        $launchError = $null
        $preCellIntegrity = Test-Xv1PhysicalIntegrity `
            -RepoRoot $repoRoot `
            -SourceCommit $sourceCommit `
            -SourceTree $sourceTree `
            -OriginMain $originMain `
            -FrozenFiles $frozenPhysicalFiles
        if (-not [bool]$preCellIntegrity.ok) {
            $integrityAbortUsed = $true
            foreach ($failure in @($preCellIntegrity.failure_codes)) {
                if (-not $integrityAbortCodes.Contains([string]$failure)) {
                    $integrityAbortCodes.Add([string]$failure)
                }
            }
        }
        if ($integrityAbortUsed) {
            $launchError = (
                "INTEGRITY_ABORT_NO_WORLD_OPENED::" +
                (@($integrityAbortCodes) -join ",")
            )
        }
        else {
          try {
            if ([string]$cell.engine -ceq "rapier") {
                $arguments = @(
                    "--source-commit", $sourceCommit,
                    "--cell-id", $cellId,
                    "--authored-friction", ([string]$cell.authored_sliding_friction),
                    "--material-profile-id", ([string]$cell.material_profile_id),
                    "--output", $cellReportPath
                )
                $process = Start-Process `
                    -FilePath $rapierBinary `
                    -ArgumentList $arguments `
                    -WorkingDirectory $sdkRoot `
                    -WindowStyle Hidden `
                    -Wait `
                    -PassThru `
                    -RedirectStandardOutput $stdoutPath `
                    -RedirectStandardError $stderrPath
            }
            else {
                $arguments = @(
                    "-m",
                    "sporespore_mujoco_adapter.cross_engine_discrete_material_validation_xv1_mujoco",
                    "--run-physical",
                    "--source-commit", $sourceCommit,
                    "--cell-id", $cellId,
                    "--authored-friction", ([string]$cell.authored_sliding_friction),
                    "--material-profile-id", ([string]$cell.material_profile_id),
                    "--report", $cellReportPath
                )
                $process = Start-Process `
                    -FilePath $python `
                    -ArgumentList $arguments `
                    -WorkingDirectory $mujocoRoot `
                    -WindowStyle Hidden `
                    -Wait `
                    -PassThru `
                    -RedirectStandardOutput $stdoutPath `
                    -RedirectStandardError $stderrPath
            }
            $processLaunchCount++
          }
          catch {
            $launchError = $_.Exception.Message
          }
        }

        $reportPresent = Test-Path -LiteralPath $cellReportPath -PathType Leaf
        $workerReport = [ordered]@{}
        $workerReportParseError = $null
        if ($reportPresent) {
            try {
                $workerReport = Get-Content -Raw -LiteralPath $cellReportPath |
                    ConvertFrom-Json -AsHashtable -Depth 100
            }
            catch {
                $workerReportParseError = $_.Exception.Message
            }
        }
        $coldEvaluation = [ordered]@{
            schema_version = "missing"
            ok = $false
            failure_codes = @("REPORT_MISSING")
            world_build_count = 0
        }
        $coldEvaluatorProcessExitCode = -1
        if ($reportPresent) {
            $coldLines = @()
            try {
                if ([string]$cell.engine -ceq "rapier") {
                    $coldLines = @(& $rapierBinary --evaluate-report $cellReportPath)
                    $coldEvaluatorProcessExitCode = $LASTEXITCODE
                }
                else {
                    Push-Location -LiteralPath $mujocoRoot
                    try {
                        $coldLines = @(
                            & $python `
                                -m sporespore_mujoco_adapter.cross_engine_discrete_material_validation_xv1_mujoco `
                                --evaluate-report $cellReportPath
                        )
                        $coldEvaluatorProcessExitCode = $LASTEXITCODE
                    }
                    finally {
                        Pop-Location
                    }
                }
                $coldEvaluation = ($coldLines -join [Environment]::NewLine) |
                    ConvertFrom-Json -AsHashtable -Depth 100
            }
            catch {
                $coldEvaluation = [ordered]@{
                    schema_version = "unreadable"
                    ok = $false
                    failure_codes = @(
                        "COLD_EVALUATION_UNREADABLE_OR_EXCEPTION"
                    )
                    world_build_count = 0
                }
            }
        }
        Write-NewJsonFile $coldEvaluationPath $coldEvaluation

        $rapierIntegrityFields = @(
            "controller_error_count",
            "safe_no_actuation_count",
            "composition_error_count",
            "nonfinite_observation_count",
            "actuator_application_mismatch_count",
            "motor_model_or_field_readback_mismatch_count",
            "small_step_impulse_limit_violation_count",
            "global_scale_mismatch_count",
            "native_position_target_application_count",
            "selected_control_mapping_mismatch_count"
        )
        $mujocoIntegrityFields = @(
            "controller_error_count",
            "safe_no_actuation_count",
            "composition_error_count",
            "global_scale_mismatch_count",
            "host_mapping_or_readback_mismatch_count",
            "actuator_application_mismatch_count",
            "portable_impulse_limit_violation_count",
            "nonfinite_observation_count",
            "native_position_target_application_count"
        )
        $workerPreflightPassed = if ([string]$cell.engine -ceq "rapier") {
            [bool](Get-Xv1MapValue (Get-Xv1MapValue $workerReport "preflight" @{}) "ok" $false)
        }
        else {
            [bool](Get-Xv1MapValue (
                Get-Xv1MapValue $workerReport "preworld_real_controller_trace_projection_canary" @{}
            ) "ok" $false) -and
            [bool](Get-Xv1MapValue (
                Get-Xv1MapValue $workerReport "preworld_engine_neutral_terminal_restoration_canary" @{}
            ) "ok" $false) -and
            [bool](Get-Xv1MapValue (
                Get-Xv1MapValue $workerReport "preworld_production_kinematic_vector_representation_canary" @{}
            ) "ok" $false)
            -and
            [bool](Get-Xv1MapValue (
                Get-Xv1MapValue $workerReport "preworld_material_xml_authoring_canary" @{}
            ) "ok" $false)
            -and
            [bool](Get-Xv1MapValue (
                Get-Xv1MapValue $workerReport "preworld_shared_report_assembler_authority_schema_canary" @{}
            ) "ok" $false)
        }
        $hostMaterialPassed = if ([string]$cell.engine -ceq "rapier") {
            [bool](Get-Xv1MapValue (
                Get-Xv1MapValue $workerReport "host_configuration" @{}
            ) "ground_and_every_robot_collider_use_same_friction" $false)
        }
        else {
            [bool](Get-Xv1MapValue (
                Get-Xv1MapValue $workerReport "host_material" @{}
            ) "all_ground_and_robot_geom_vectors_match_requested" $false)
        }
        $terminal = Get-Xv1MapValue (
            Get-Xv1MapValue $workerReport "schedule" @{}
        ) "terminal_restoration_phase" @{}
        $metrics = Get-Xv1MapValue $workerReport "metrics" @{}
        $claimBoundary = Get-Xv1MapValue $workerReport "claim_boundary" @{}
        try {
            $cellSummary = [ordered]@{
                ordinal = [int]$cell.ordinal
                cell_id = $cellId
                engine = [string]$cell.engine
                engine_version = [string](Get-Xv1MapValue $workerReport "engine_version" "")
                authored_sliding_friction = [double]$cell.authored_sliding_friction
                authored_friction_vector = @($cell.authored_friction_vector)
                material_profile_id = [string]$cell.material_profile_id
                worker_report_schema_version = [string](Get-Xv1MapValue $workerReport "schema_version" "missing")
                cold_evaluation_schema_version = [string](Get-Xv1MapValue $coldEvaluation "schema_version" "missing")
                source_commit = [string](Get-Xv1MapValue $workerReport "source_commit" $sourceCommit)
                report_path = $cellReportPath.Replace("\", "/")
                report_raw_sha256 = $(if ($reportPresent) {
                    Get-RawSha256 $cellReportPath
                } else { "sha256:" + ("0" * 64) })
                report_size_bytes = $(if ($reportPresent) {
                    (Get-Item -LiteralPath $cellReportPath).Length
                } else { 0 })
                process_exit_code = $(if ($null -ne $process) { $process.ExitCode } else { -1 })
                process_launch_error = $launchError
                worker_report_parse_error = $workerReportParseError
                worker_report_ok = [bool](Get-Xv1MapValue $workerReport "ok" $false)
                cold_evaluator_replay_passed = [bool](Get-Xv1MapValue $coldEvaluation "ok" $false)
                cold_evaluator_process_exit_code = $coldEvaluatorProcessExitCode
                cold_evaluator_failure_count = @((Get-Xv1MapValue $coldEvaluation "failure_codes" @())).Count
                cold_evaluation_world_build_count = [int](Get-Xv1MapValue $coldEvaluation "world_build_count" 0)
                worker_preflight_passed = $workerPreflightPassed
                worker_preflight_world_build_count = 0
                world_attempt_count = [int](Get-Xv1MapValue $workerReport "world_attempt_count" 0)
                world_build_count = [int](Get-Xv1MapValue $workerReport "world_build_count" 0)
                world_reset_count = [int](Get-Xv1MapValue $workerReport "world_reset_count" 0)
                trace_step_count = [int](Get-Xv1MapValue $workerReport "trace_step_count" 0)
                gate_failure_count = @((Get-Xv1MapValue $workerReport "gate_failures" @())).Count
                integrity_failure_count = Get-IntegerSum `
                    -Map $workerReport `
                    -Fields $(if ([string]$cell.engine -ceq "rapier") {
                        $rapierIntegrityFields
                    } else { $mujocoIntegrityFields })
                candidate_id = [string](Get-Xv1MapValue $workerReport "candidate_id" "")
                candidate_composition_digest = [string](Get-Xv1MapValue $workerReport "candidate_composition_digest" "")
                selected_policy_id = [string](Get-Xv1MapValue $workerReport "selected_policy_id" "")
                selected_policy_digest = [string](Get-Xv1MapValue $workerReport "selected_policy_digest" "")
                terminal_restoration_policy_id = [string](Get-Xv1MapValue $terminal "restoration_policy_id" "")
                host_material_readback_passed = $hostMaterialPassed
                terminal_four_contact_stance = [bool](Get-Xv1MapValue $workerReport "terminal_four_contact_stance" $false)
                required_consecutive_hold_completed = [bool](Get-Xv1MapValue $terminal "required_consecutive_hold_completed" $false)
                evidence_forward_displacement_m = Get-Xv1MapValue $metrics "evidence_forward_displacement_m" $null
                final_forward_displacement_m = Get-Xv1MapValue $metrics "final_forward_displacement_m" $null
                formal_cross_engine_equivalence = $false
                continuous_friction_coverage = $false
                arbitrary_material_robustness = $false
                release_authorized = [bool](Get-Xv1MapValue $claimBoundary "release_authorized" $false)
                physical_acceptance_authority = [bool](Get-Xv1MapValue $claimBoundary "physical_acceptance_authority" $false)
            }
            $cellSummaries.Add($cellSummary)
        }
        catch {
            # A malformed retained report is an ordinary failed outcome, not permission to
            # abandon the other preregistered cells. Preserve a minimal failed summary and
            # let the loop continue unless the independent source-integrity check aborts it.
            $cellSummaries.Add([ordered]@{
                ordinal = [int]$cell.ordinal
                cell_id = $cellId
                engine = [string]$cell.engine
                engine_version = ""
                authored_sliding_friction = [double]$cell.authored_sliding_friction
                authored_friction_vector = @($cell.authored_friction_vector)
                material_profile_id = [string]$cell.material_profile_id
                worker_report_schema_version = "summary_unreadable"
                cold_evaluation_schema_version = [string](Get-Xv1MapValue $coldEvaluation "schema_version" "missing")
                source_commit = ""
                report_path = $cellReportPath.Replace("\", "/")
                report_raw_sha256 = $(if ($reportPresent) {
                    Get-RawSha256 $cellReportPath
                } else { "sha256:" + ("0" * 64) })
                report_size_bytes = $(if ($reportPresent) {
                    (Get-Item -LiteralPath $cellReportPath).Length
                } else { 0 })
                process_exit_code = $(if ($null -ne $process) { $process.ExitCode } else { -1 })
                process_launch_error = $launchError
                worker_report_parse_error = $workerReportParseError
                summary_extraction_error = $_.Exception.Message
                worker_report_ok = $false
                cold_evaluator_replay_passed = $false
                cold_evaluator_process_exit_code = $coldEvaluatorProcessExitCode
                cold_evaluator_failure_count = @((Get-Xv1MapValue $coldEvaluation "failure_codes" @())).Count
                cold_evaluation_world_build_count = 0
                worker_preflight_passed = $false
                worker_preflight_world_build_count = 0
                world_attempt_count = 0
                world_build_count = 0
                world_reset_count = 0
                trace_step_count = 0
                gate_failure_count = 1
                integrity_failure_count = 1
                candidate_id = ""
                candidate_composition_digest = ""
                selected_policy_id = ""
                selected_policy_digest = ""
                terminal_restoration_policy_id = ""
                host_material_readback_passed = $false
                terminal_four_contact_stance = $false
                required_consecutive_hold_completed = $false
                evidence_forward_displacement_m = $null
                final_forward_displacement_m = $null
                formal_cross_engine_equivalence = $false
                continuous_friction_coverage = $false
                arbitrary_material_robustness = $false
                release_authorized = $false
                physical_acceptance_authority = $false
            })
        }
    }

    $finalIntegrity = Test-Xv1PhysicalIntegrity `
        -RepoRoot $repoRoot `
        -SourceCommit $sourceCommit `
        -SourceTree $sourceTree `
        -OriginMain $originMain `
        -FrozenFiles $frozenPhysicalFiles `
        -CheckLiveRemote
    if (-not [bool]$finalIntegrity.ok) {
        $integrityAbortUsed = $true
        foreach ($failure in @($finalIntegrity.failure_codes)) {
            if (-not $integrityAbortCodes.Contains([string]$failure)) {
                $integrityAbortCodes.Add([string]$failure)
            }
        }
    }

    $allWorkersPassed = @($cellSummaries | Where-Object {
        $_.worker_report_ok -and
        $_.cold_evaluator_replay_passed -and
        $_.process_exit_code -eq 0
    }).Count -eq 6 -and $cellSummaries.Count -eq 6
    $aggregateResult = [ordered]@{
        schema_version = (
            "sporespore_cross_engine_c6_bw19v_discrete_material_validation_xv1_result_v1"
        )
        campaign_id = $campaignId
        gate_id = $gateId
        study_classification = "exact_finite_cell_independent_cross_engine_material_validation"
        expected_gate_count = 12
        expected_world_count = 6
        expected_cell_count = 6
        attempt_id = $attemptId
        evidence_root = $resolvedOutputRoot.Replace("\", "/")
        source = [ordered]@{
            commit = $sourceCommit
            tree_git_oid = $sourceTree
            clean = [bool]$finalIntegrity.worktree_clean
            matches_origin_main = [bool]$finalIntegrity.origin_main_matches
            matches_live_github_main = [bool]$finalIntegrity.live_github_main_matches
        }
        final_integrity_passed = [bool]$finalIntegrity.ok
        final_integrity_failure_codes = @($finalIntegrity.failure_codes)
        preregistration_raw_sha256 = Get-RawSha256 $preregistrationPath
        bound_authority_raw_sha256 = [ordered]@{
            cross_engine_host_characterization_r2 = "sha256:" + [string]$pinnedAuthorityFiles["sdk/cross_engine_c6_host_characterization_r2_closure.json"]
            rapier_spv1 = "sha256:" + [string]$pinnedAuthorityFiles["sdk/rapier_c6_force_based_selected_configuration_validation_spv1_closure.json"]
            rapier_vh1 = "sha256:" + [string]$pinnedAuthorityFiles["sdk/rapier_c6_force_based_velocity_only_host_characterization_vh1_closure.json"]
            rapier_ph1 = "sha256:" + [string]$pinnedAuthorityFiles["sdk/rapier_c6_bw19v_velocity_only_pose_hold_restoration_ph1_closure.json"]
            mujoco_vh5 = "sha256:" + [string]$pinnedAuthorityFiles["sdk/mujoco_c6_s169_per_actuator_force_limit_host_characterization_vh5_closure.json"]
            mujoco_mv6 = "sha256:" + [string]$pinnedAuthorityFiles["sdk/mujoco_c6_bw19v_selected_policy_pose_hold_restoration_mv6_closure.json"]
        }
        full_godot_v2_attestation = [ordered]@{
            path = $resolvedAttestationPath.Replace("\", "/")
            raw_sha256 = Get-RawSha256 $resolvedAttestationPath
            source_commit = $sourceCommit
            source_tree_git_oid = $sourceTree
            complete_suite_passed = [bool]$attestation.conformance.passed
            independent_file_verifier_passed = [bool]$attestationVerification.ok
            verifier_failure_count = @($attestationVerification.failure_codes).Count
            physical_acceptance_authority = $false
        }
        ordered_cells = @($cellSummaries)
        world_attempt_count = [int](($cellSummaries | Measure-Object world_attempt_count -Sum).Sum)
        world_build_count = [int](($cellSummaries | Measure-Object world_build_count -Sum).Sum)
        world_reset_count = [int](($cellSummaries | Measure-Object world_reset_count -Sum).Sum)
        physical_process_launch_count = $processLaunchCount
        replacement_process_count = 0
        all_six_cell_attempts_retained = @($cellSummaries | Where-Object {
            $_.report_size_bytes -gt 0
        }).Count -eq 6
        global_physical_operation_lock_acquired = $true
        outcome_based_early_stop_used = $false
        integrity_abort_used = $integrityAbortUsed
        integrity_abort_failure_codes = @($integrityAbortCodes)
        selective_rerun_or_replacement_used = $false
        claims = [ordered]@{
            accepted = $false
            exact_s169_rapier_three_material_validation = $false
            exact_s169_mujoco_three_material_validation = $false
            qsdk_r14_declared_exact_finite_grid = $false
            qsdk_r15_declared_exact_finite_grid = $false
            different_physics_engines_same_policy_exact_finite_validation = $false
            bounded_discrete_material_validation = $false
            formal_cross_engine_equivalence = $false
            trajectory_equivalence = $false
            continuous_friction_coverage = $false
            arbitrary_material_robustness = $false
            population_inference = $false
            arbitrary_quadruped_coverage = $false
            continuous_morphology_coverage = $false
            rough_terrain_robustness = $false
            external_push_recovery = $false
            sensor_noise_or_latency_robustness = $false
            release_authorized = $false
            completed_engine_neutral_sdk = $false
            physical_acceptance_authority = $false
        }
    }
    $provisionalEvaluation = `
        Test-CrossEngineC6Bw19vDiscreteMaterialValidationXv1Result `
            $aggregateResult
    $promotionEligible = (
        $allWorkersPassed -and
        @($provisionalEvaluation.gates | Where-Object {
            $_.ordinal -ge 1 -and $_.ordinal -le 11 -and $_.passed
        }).Count -eq 11
    )
    foreach ($claimName in @(
        "accepted",
        "exact_s169_rapier_three_material_validation",
        "exact_s169_mujoco_three_material_validation",
        "qsdk_r14_declared_exact_finite_grid",
        "qsdk_r15_declared_exact_finite_grid",
        "different_physics_engines_same_policy_exact_finite_validation",
        "bounded_discrete_material_validation"
    )) {
        $aggregateResult.claims[$claimName] = $promotionEligible
    }
    Write-NewJsonFile $reportPath $aggregateResult
    $aggregateEvaluation = Test-CrossEngineC6Bw19vDiscreteMaterialValidationXv1Result `
        $aggregateResult
    Write-NewJsonFile $evaluationPath $aggregateEvaluation
    $completion = [ordered]@{
        schema_version = (
            "sporespore_cross_engine_c6_bw19v_discrete_material_validation_xv1_completion_v1"
        )
        attempt_id = $attemptId
        campaign_id = $campaignId
        gate_id = $gateId
        source_commit = $sourceCommit
        completed_utc = [DateTime]::UtcNow.ToString("o")
        physical_process_launch_count = $processLaunchCount
        retained_cell_report_count = @($cellSummaries | Where-Object {
            $_.report_size_bytes -gt 0
        }).Count
        aggregate_report_path = $reportPath.Replace("\", "/")
        aggregate_report_raw_sha256 = Get-RawSha256 $reportPath
        aggregate_evaluation_path = $evaluationPath.Replace("\", "/")
        aggregate_evaluation_raw_sha256 = Get-RawSha256 $evaluationPath
        aggregate_accepted = [bool]$aggregateEvaluation.accepted
        aggregate_failure_codes = @($aggregateEvaluation.failure_codes)
        same_identity_rerun_allowed = $false
        status = $(if ([bool]$aggregateEvaluation.accepted) {
            "complete_accepted"
        } else { "complete_negative_invalid_or_incomplete" })
        operation_lock = $operationLockPublic
    }
    Write-NewJsonFile $completionPath $completion
    $completionWritten = $true

    Write-Host (
        "$gateId retained at $resolvedOutputRoot; accepted=$($aggregateEvaluation.accepted) " +
        "cells=$($cellSummaries.Count) launches=$processLaunchCount"
    )
    if (-not [bool]$aggregateEvaluation.accepted) {
        throw (
            "$gateId retained a complete negative or invalid six-cell result. " +
            "Close it without rerun, replacement, rethresholding, or reinterpretation: " +
            (@($aggregateEvaluation.failure_codes) -join ",")
        )
    }
}
catch {
    $supervisorFailure = $_.Exception.Message
    if (
        $attemptConsumed -and
        -not [string]::IsNullOrWhiteSpace([string]$resolvedOutputRoot)
    ) {
        $fallbackCompletionPath = if (
            $null -ne $completionPath -and
            -not (Test-Path -LiteralPath $completionPath)
        ) {
            $completionPath
        }
        else {
            Join-Path $resolvedOutputRoot "completion_supervisor_failure.json"
        }
        if (-not (Test-Path -LiteralPath $fallbackCompletionPath)) {
            try {
                Write-NewJsonFile $fallbackCompletionPath ([ordered]@{
                    schema_version = (
                        "sporespore_cross_engine_c6_bw19v_discrete_material_validation_xv1_completion_v1"
                    )
                    attempt_id = $attemptId
                    campaign_id = $campaignId
                    gate_id = $gateId
                    source_commit = $sourceCommit
                    completed_utc = [DateTime]::UtcNow.ToString("o")
                    status = "supervisor_failed_after_identity_consumption"
                    supervisor_failure = $supervisorFailure
                    physical_process_launch_count = $processLaunchCount
                    retained_cell_summary_count = $cellSummaries.Count
                    same_identity_rerun_allowed = $false
                    operation_lock = $(if ($null -ne $operationLockReceipt) {
                        Get-SporeSporeLocomotionOperationLockPublicReceipt `
                            -Receipt $operationLockReceipt
                    } else { $null })
                })
                $completionWritten = $true
            }
            catch {
                Write-Warning (
                    "$gateId could not write its emergency completion receipt: " +
                    $_.Exception.Message
                )
            }
        }
    }
    throw
}
finally {
    if ($null -ne $operationLockReceipt) {
        Exit-SporeSporeLocomotionOperationLock -Receipt $operationLockReceipt
    }
}
