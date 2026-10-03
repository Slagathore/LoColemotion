#requires -Version 7.0

[CmdletBinding()]
param(
    [switch]$PreflightOnly,
    [switch]$RunPhysical,
    [string]$Godot = (
        "C:\Users\Cole\CodeStuff\Misc\Godot\" +
        "Godot_v4.7-stable_mono_win64_console.exe"
    ),
    [string]$LogRoot = (Join-Path $PSScriptRoot "target\bw30n-recovery-preflight"),
    [string]$OutputRoot = "",
    [string]$FullConformanceAttestation = "",
    [int]$CellTimeoutSeconds = 360
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$sdkRoot = [System.IO.Path]::GetFullPath($PSScriptRoot)
$repoRoot = [System.IO.Path]::GetFullPath((Split-Path -Parent $sdkRoot))
$evidenceRoot = [System.IO.Path]::GetFullPath(
    (Join-Path (Split-Path -Parent $repoRoot) "SporeSpore_Evidence")
)
$campaignId = "BW30N-BW29N-IMPLEMENTATION-RECOVERY-DEVELOPMENT"
$gateId = "BW30N"
$preregistrationPath = Join-Path $sdkRoot "balanced_wave_bw30n_recovery_preregistration.json"
$candidatesPath = Join-Path $sdkRoot "balanced_wave_bw30n_recovery_candidates.json"
$manifestPath = Join-Path $sdkRoot "balanced_wave_bw30n_recovery_manifest.json"
$fixedHorizonPath = Join-Path $sdkRoot "balanced_wave_bw30n_fixed_observation_horizon.json"
$freezePath = Join-Path $sdkRoot "balanced_wave_bw30n_recovery_freeze.json"
$evaluatorPath = Join-Path $sdkRoot "balanced_wave_bw30n_recovery_gate.ps1"
$zeroWorldGatePath = Join-Path $sdkRoot "run_balanced_wave_bw30n_recovery_zero_world_gate.ps1"
$supervisorPath = Join-Path $sdkRoot "run_balanced_wave_bw30n_recovery.ps1"
$declarationAuditPath = Join-Path $repoRoot "tests\test_bw30n_recovery_declaration.ps1"
$freezeAuditPath = Join-Path $repoRoot "tests\test_bw30n_recovery_freeze.ps1"
$commonWorkerPath = Join-Path $repoRoot "scripts\lab\gait\sdk_bw30n_worker_common.gd"
$fixedRunnerPath = Join-Path $repoRoot "scripts\lab\gait\physical_wave_gait_quadruped_bw30n_fixed_horizon.gd"
$referenceWorkerPath = Join-Path $repoRoot "tests\test_sdk_balanced_wave_bw30n_reference_worker.gd"
$successorWorkerPath = Join-Path $repoRoot "tests\test_sdk_balanced_wave_bw30n_successor_worker.gd"
$adapterArtifactPath = Join-Path $sdkRoot "target\debug\sporespore_godot_adapter.dll"
$operationLockPath = Join-Path $sdkRoot "locomotion_operation_lock.ps1"
$attestationVerifierPath = Join-Path $sdkRoot "locomotion_full_conformance_attestation.ps1"
$rawPrefix = "BW30N_RECOVERY_RAW_CELL "
$preflightPrefix = "BW30N_RECOVERY_WORKER_PREFLIGHT "

. $evaluatorPath
. $operationLockPath
. $attestationVerifierPath

function Assert-Bw30nExact {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function Get-Bw30nRawSha256 {
    param([Parameter(Mandatory)][string]$Path)
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Write-Bw30nUtf8NoBom {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][AllowEmptyString()][string]$Text
    )
    [System.IO.File]::WriteAllText($Path, $Text, [System.Text.UTF8Encoding]::new($false))
}

function Write-Bw30nNewJsonArtifact {
    param(
        [Parameter(Mandatory)]$Value,
        [Parameter(Mandatory)][string]$Path
    )
    Assert-Bw30nExact (-not (Test-Path -LiteralPath $Path)) "Refusing to overwrite $gateId artifact: $Path"
    [void][System.IO.Directory]::CreateDirectory((Split-Path -Parent $Path))
    $temporaryPath = $Path + ".tmp"
    Assert-Bw30nExact (-not (Test-Path -LiteralPath $temporaryPath)) "Refusing stale temporary artifact: $temporaryPath"
    Write-Bw30nUtf8NoBom -Path $temporaryPath -Text (
        ($Value | ConvertTo-Json -Depth 64) + [Environment]::NewLine
    )
    Move-Item -LiteralPath $temporaryPath -Destination $Path
}

function Get-Bw30nReceiptFromOutput {
    param(
        [Parameter(Mandatory)][string]$OutputText,
        [Parameter(Mandatory)][string]$Prefix
    )
    $lines = @($OutputText -split "\r?\n" | Where-Object { $_.StartsWith($Prefix) })
    if ($lines.Count -ne 1) { throw "Expected one '$Prefix' receipt, found $($lines.Count)" }
    return $lines[0].Substring($Prefix.Length) | ConvertFrom-Json -AsHashtable -Depth 64
}

function New-Bw30nIsolatedProject {
    param([Parameter(Mandatory)][string]$Root)
    $projectRoot = Join-Path $Root "project"
    [void][System.IO.Directory]::CreateDirectory($projectRoot)
    foreach ($directory in @("scripts", "tests", "sdk")) {
        $link = Join-Path $projectRoot $directory
        if (-not (Test-Path -LiteralPath $link)) {
            [void](New-Item -ItemType Junction -Path $link -Target (Join-Path $repoRoot $directory))
        }
    }
    $projectText = @"
; Isolated SporeSpore BW30N recovery worker.

config_version=5

[application]

config/name="sporespore-bw30n-recovery"
config/features=PackedStringArray("4.7", "Forward Plus")

[debug]

gdscript/warnings/shadowed_global_identifier=0

[physics]

3d/physics_engine="Jolt Physics"
jolt_physics_3d/simulation/velocity_steps=20
jolt_physics_3d/simulation/position_steps=7
"@
    Write-Bw30nUtf8NoBom -Path (Join-Path $projectRoot "project.godot") -Text $projectText
    return $projectRoot
}

function Invoke-Bw30nGodotCaptured {
    param(
        [Parameter(Mandatory)][string]$GodotPath,
        [Parameter(Mandatory)][string[]]$Arguments,
        [Parameter(Mandatory)][string]$WorkerRoot,
        [Parameter(Mandatory)][int]$TimeoutSeconds,
        [string]$AttemptPath = "",
        [string]$AuthorizationToken = "",
        [string]$CellId = "",
        [string]$CandidateId = "",
        [string]$WorldAttemptId = "",
        [string]$CampaignAttemptId = ""
    )
    $appData = Join-Path $WorkerRoot "appdata"
    $localAppData = Join-Path $WorkerRoot "localappdata"
    [void][System.IO.Directory]::CreateDirectory($appData)
    [void][System.IO.Directory]::CreateDirectory($localAppData)
    $start = [System.Diagnostics.ProcessStartInfo]::new()
    $start.FileName = $GodotPath
    $start.WorkingDirectory = $repoRoot
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    $start.Environment["APPDATA"] = $appData
    $start.Environment["LOCALAPPDATA"] = $localAppData
    foreach ($authorizationEnvironmentName in @(
        "SPORESPORE_BW30N_ATTEMPT",
        "SPORESPORE_BW30N_TOKEN",
        "SPORESPORE_BW30N_CELL",
        "SPORESPORE_BW30N_CANDIDATE",
        "SPORESPORE_BW30N_WORLD_ATTEMPT_ID",
        "SPORESPORE_BW30N_CAMPAIGN_ATTEMPT_ID"
    )) {
        [void]$start.Environment.Remove($authorizationEnvironmentName)
    }
    if (-not [string]::IsNullOrWhiteSpace($AttemptPath)) {
        $start.Environment["SPORESPORE_BW30N_ATTEMPT"] = $AttemptPath
        $start.Environment["SPORESPORE_BW30N_TOKEN"] = $AuthorizationToken
        $start.Environment["SPORESPORE_BW30N_CELL"] = $CellId
        $start.Environment["SPORESPORE_BW30N_CANDIDATE"] = $CandidateId
        $start.Environment["SPORESPORE_BW30N_WORLD_ATTEMPT_ID"] = $WorldAttemptId
        $start.Environment["SPORESPORE_BW30N_CAMPAIGN_ATTEMPT_ID"] = $CampaignAttemptId
    }
    foreach ($argument in $Arguments) { [void]$start.ArgumentList.Add($argument) }
    $process = [System.Diagnostics.Process]::new()
    $process.StartInfo = $start
    $startedUtc = [DateTime]::UtcNow
    Assert-Bw30nExact ([bool]$process.Start()) "Failed to start isolated Godot"
    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()
    $timedOut = -not $process.WaitForExit($TimeoutSeconds * 1000)
    $killedTree = $false
    if ($timedOut) {
        try { $process.Kill($true); $killedTree = $true } catch { $killedTree = $false }
        [void]$process.WaitForExit(10000)
    }
    $stdout = $stdoutTask.GetAwaiter().GetResult()
    $stderr = $stderrTask.GetAwaiter().GetResult()
    $exitCode = if ($process.HasExited) { $process.ExitCode } else { -1 }
    $duration = ([DateTime]::UtcNow - $startedUtc).TotalSeconds
    $process.Dispose()
    return [ordered]@{
        exit_code = $exitCode
        timed_out = $timedOut
        killed_process_tree = $killedTree
        duration_seconds = $duration
        stdout = $stdout
        stderr = $stderr
    }
}

function Get-Bw30nAttemptKeys {
    return @(
        "schema_version", "campaign_id", "gate_id", "synthetic_contract_preflight",
        "source_commit", "origin_main_commit", "remote_main_commit",
        "source_worktree_clean", "source_matches_live_github_main", "attempt_id",
        "launched_at_utc", "authorization_token", "godot_version",
        "godot_executable_sha256", "godot_runtime_executable_sha256",
        "godot_adapter_artifact_sha256", "preregistration_raw_sha256",
        "candidates_raw_sha256", "manifest_raw_sha256", "fixed_horizon_raw_sha256",
        "declaration_audit_raw_sha256", "common_worker_raw_sha256",
        "fixed_horizon_runner_raw_sha256", "reference_worker_raw_sha256",
        "successor_worker_raw_sha256", "evaluator_raw_sha256",
        "supervisor_raw_sha256", "zero_world_gate_raw_sha256",
        "stage_one_freeze_raw_sha256", "complete_zero_world_gate_passed",
        "declaration_audit_passed", "worker_entrypoint_preflight_passed",
        "real_shaped_receipt_preflight_passed", "shared_receipt_composer_passed",
        "fixed_observation_horizon_preflight_passed",
        "evaluator_negative_controls_passed", "attempt_contract_preflight_passed",
        "stage_one_freeze_verified", "full_godot_v2_attestation_path",
        "full_godot_v2_attestation_sha256", "physical_identity_consumed",
        "same_identity_rerun_allowed", "locomotion_outcome_exposed_at_attempt",
        "physical_acceptance_authority", "retained_physical_execution_serialized",
        "expected_world_count", "ordered_cell_ids", "primary_world_attempt_ids"
    )
}

function New-Bw30nAttemptRecord {
    param(
        [Parameter(Mandatory)][bool]$Synthetic,
        [Parameter(Mandatory)][string]$AttemptId,
        [Parameter(Mandatory)][string]$AuthorizationToken,
        [Parameter(Mandatory)][string]$GodotVersion,
        [Parameter(Mandatory)][string]$GodotSha256,
        [Parameter(Mandatory)][string]$GodotRuntimeSha256,
        [Parameter(Mandatory)][string]$AdapterSha256,
        [string]$SourceCommit = "",
        [string]$AttestationPath = "",
        [string]$AttestationSha256 = ""
    )
    $manifest = Get-Content -Raw -LiteralPath $manifestPath |
        ConvertFrom-Json -AsHashtable -Depth 64
    $cellIds = @($manifest["ordered_cells"] | ForEach-Object { [string]$_["cell_id"] })
    return [ordered]@{
        schema_version = "sporespore_balanced_wave_bw30n_recovery_attempt_v1"
        campaign_id = $campaignId
        gate_id = $gateId
        synthetic_contract_preflight = $Synthetic
        source_commit = if ($Synthetic) { "synthetic_preflight_no_source_identity" } else { $SourceCommit }
        origin_main_commit = if ($Synthetic) { "" } else { $SourceCommit }
        remote_main_commit = if ($Synthetic) { "" } else { $SourceCommit }
        source_worktree_clean = -not $Synthetic
        source_matches_live_github_main = -not $Synthetic
        attempt_id = $AttemptId
        launched_at_utc = [DateTime]::UtcNow.ToString("o")
        authorization_token = $AuthorizationToken
        godot_version = $GodotVersion
        godot_executable_sha256 = $GodotSha256
        godot_runtime_executable_sha256 = $GodotRuntimeSha256
        godot_adapter_artifact_sha256 = $AdapterSha256
        preregistration_raw_sha256 = Get-Bw30nRawSha256 $preregistrationPath
        candidates_raw_sha256 = Get-Bw30nRawSha256 $candidatesPath
        manifest_raw_sha256 = Get-Bw30nRawSha256 $manifestPath
        fixed_horizon_raw_sha256 = Get-Bw30nRawSha256 $fixedHorizonPath
        declaration_audit_raw_sha256 = Get-Bw30nRawSha256 $declarationAuditPath
        common_worker_raw_sha256 = Get-Bw30nRawSha256 $commonWorkerPath
        fixed_horizon_runner_raw_sha256 = Get-Bw30nRawSha256 $fixedRunnerPath
        reference_worker_raw_sha256 = Get-Bw30nRawSha256 $referenceWorkerPath
        successor_worker_raw_sha256 = Get-Bw30nRawSha256 $successorWorkerPath
        evaluator_raw_sha256 = Get-Bw30nRawSha256 $evaluatorPath
        supervisor_raw_sha256 = Get-Bw30nRawSha256 $supervisorPath
        zero_world_gate_raw_sha256 = Get-Bw30nRawSha256 $zeroWorldGatePath
        stage_one_freeze_raw_sha256 = Get-Bw30nRawSha256 $freezePath
        complete_zero_world_gate_passed = $true
        declaration_audit_passed = $true
        worker_entrypoint_preflight_passed = $true
        real_shaped_receipt_preflight_passed = $true
        shared_receipt_composer_passed = $true
        fixed_observation_horizon_preflight_passed = $true
        evaluator_negative_controls_passed = $true
        attempt_contract_preflight_passed = $true
        stage_one_freeze_verified = $true
        full_godot_v2_attestation_path = if ($Synthetic) { "synthetic_preflight_no_attestation" } else { $AttestationPath }
        full_godot_v2_attestation_sha256 = if ($Synthetic) { "synthetic_preflight_no_attestation" } else { $AttestationSha256 }
        physical_identity_consumed = -not $Synthetic
        same_identity_rerun_allowed = $false
        locomotion_outcome_exposed_at_attempt = $true
        physical_acceptance_authority = $false
        retained_physical_execution_serialized = $true
        expected_world_count = 24
        ordered_cell_ids = $cellIds
        primary_world_attempt_ids = @($cellIds | ForEach-Object { "BW30N-P1::$_" })
    }
}

function Test-Bw30nAttemptRecord {
    param(
        [Parameter(Mandatory)][System.Collections.IDictionary]$Attempt,
        [Parameter(Mandatory)][bool]$Synthetic
    )
    $actualKeys = @($Attempt.Keys | ForEach-Object { [string]$_ } | Sort-Object)
    $expectedKeys = @(Get-Bw30nAttemptKeys | Sort-Object)
    $sourceExact = if ($Synthetic) {
        [string]$Attempt["source_commit"] -ceq "synthetic_preflight_no_source_identity" -and
        [string]::IsNullOrEmpty([string]$Attempt["origin_main_commit"]) -and
        [string]::IsNullOrEmpty([string]$Attempt["remote_main_commit"]) -and
        -not [bool]$Attempt["source_worktree_clean"] -and
        -not [bool]$Attempt["source_matches_live_github_main"]
    } else {
        [string]$Attempt["source_commit"] -cmatch "^[0-9a-f]{40}$" -and
        [string]$Attempt["origin_main_commit"] -ceq [string]$Attempt["source_commit"] -and
        [string]$Attempt["remote_main_commit"] -ceq [string]$Attempt["source_commit"] -and
        [bool]$Attempt["source_worktree_clean"] -and [bool]$Attempt["source_matches_live_github_main"]
    }
    return (
        ($actualKeys -join "`n") -ceq ($expectedKeys -join "`n") -and
        [string]$Attempt["schema_version"] -ceq "sporespore_balanced_wave_bw30n_recovery_attempt_v1" -and
        [string]$Attempt["campaign_id"] -ceq $campaignId -and
        [string]$Attempt["gate_id"] -ceq $gateId -and
        [bool]$Attempt["synthetic_contract_preflight"] -eq $Synthetic -and $sourceExact -and
        [string]$Attempt["attempt_id"] -cmatch "^[0-9a-f]{32}$" -and
        [string]$Attempt["authorization_token"] -cmatch "^[0-9a-f]{32}$" -and
        [bool]$Attempt["complete_zero_world_gate_passed"] -and
        [bool]$Attempt["declaration_audit_passed"] -and
        [bool]$Attempt["worker_entrypoint_preflight_passed"] -and
        [bool]$Attempt["real_shaped_receipt_preflight_passed"] -and
        [bool]$Attempt["shared_receipt_composer_passed"] -and
        [bool]$Attempt["fixed_observation_horizon_preflight_passed"] -and
        [bool]$Attempt["evaluator_negative_controls_passed"] -and
        [bool]$Attempt["attempt_contract_preflight_passed"] -and
        [bool]$Attempt["stage_one_freeze_verified"] -and
        [bool]$Attempt["physical_identity_consumed"] -eq (-not $Synthetic) -and
        -not [bool]$Attempt["same_identity_rerun_allowed"] -and
        [bool]$Attempt["locomotion_outcome_exposed_at_attempt"] -and
        -not [bool]$Attempt["physical_acceptance_authority"] -and
        [bool]$Attempt["retained_physical_execution_serialized"] -and
        [int]$Attempt["expected_world_count"] -eq 24 -and
        @($Attempt["ordered_cell_ids"]).Count -eq 24 -and
        @($Attempt["primary_world_attempt_ids"]).Count -eq 24
    )
}

function Invoke-Bw30nWorkerPreflight {
    param(
        [Parameter(Mandatory)][string]$GodotPath,
        [Parameter(Mandatory)][string]$ProjectRoot,
        [Parameter(Mandatory)][string]$TempRoot,
        [Parameter(Mandatory)][string]$WorkerResource,
        [Parameter(Mandatory)][string]$CandidateId
    )
    $execution = Invoke-Bw30nGodotCaptured -GodotPath $GodotPath -Arguments @(
        "--headless", "--path", $ProjectRoot,
        "--log-file", (Join-Path $TempRoot "$CandidateId-preflight-engine.log"),
        "--script", $WorkerResource, "--", "preflight-all"
    ) -WorkerRoot (Join-Path $TempRoot "$CandidateId-preflight") -TimeoutSeconds 300
    $receipt = Get-Bw30nReceiptFromOutput -OutputText ([string]$execution["stdout"]) -Prefix $preflightPrefix
    Assert-Bw30nExact (
        [int]$execution["exit_code"] -eq 0 -and -not [bool]$execution["timed_out"] -and
        [bool]$receipt["ok"] -and [string]$receipt["candidate_id"] -ceq $CandidateId -and
        [int]$receipt["entrypoint_count"] -eq 12 -and
        [int]$receipt["actual_world_build_count"] -eq 0 -and
        [int]$receipt["scene_tree_insertion_count"] -eq 0 -and
        -not [bool]$receipt["physics_state_modified"] -and
        -not [bool]$receipt["locomotion_outcome_exposed"] -and
        -not [bool]$receipt["physical_acceptance_authority"]
    ) "$gateId $CandidateId actual worker preflight failed"
    return $receipt
}

function Invoke-Bw30nSupervisorMain {
    Assert-Bw30nExact ([bool]$PreflightOnly -xor [bool]$RunPhysical) (
        "Specify exactly one of -PreflightOnly or -RunPhysical"
    )
    Assert-Bw30nExact ($CellTimeoutSeconds -ge 60 -and $CellTimeoutSeconds -le 900) (
        "-CellTimeoutSeconds must be between 60 and 900"
    )
    $required = @(
        $preregistrationPath, $candidatesPath, $manifestPath, $fixedHorizonPath, $freezePath,
        $evaluatorPath, $zeroWorldGatePath, $declarationAuditPath, $freezeAuditPath,
        $commonWorkerPath, $fixedRunnerPath, $referenceWorkerPath, $successorWorkerPath,
        $adapterArtifactPath
    )
    foreach ($path in $required) {
        Assert-Bw30nExact (Test-Path -LiteralPath $path -PathType Leaf) "Missing $gateId source: $path"
    }
    $manifest = Get-Content -Raw -LiteralPath $manifestPath |
        ConvertFrom-Json -AsHashtable -Depth 64
    $cells = @($manifest["ordered_cells"])
    Assert-Bw30nExact ($cells.Count -eq 24) "$gateId manifest must contain 24 cells"
    $godotPath = [System.IO.Path]::GetFullPath($Godot)
    Assert-Bw30nExact (Test-Path -LiteralPath $godotPath -PathType Leaf) "Godot executable missing"
    $runtimePath = $godotPath.Replace("_console.exe", ".exe")
    Assert-Bw30nExact (Test-Path -LiteralPath $runtimePath -PathType Leaf) "Godot runtime missing"
    $godotVersion = (& $godotPath --version 2>&1 | Out-String).Trim()
    Assert-Bw30nExact ($godotVersion -ceq "4.7.stable.mono.official.5b4e0cb0f") (
        "Unexpected Godot version: $godotVersion"
    )
    $godotSha = Get-Bw30nRawSha256 $godotPath
    $runtimeSha = Get-Bw30nRawSha256 $runtimePath
    $adapterSha = Get-Bw30nRawSha256 $adapterArtifactPath
    $perfect = New-Bw30nPerfectSyntheticReceiptSet
    $perfectEvaluation = Invoke-Bw30nRecoveryEvaluation -CellReceipts $perfect
    Assert-Bw30nExact (
        [bool]$perfectEvaluation["ok"] -and
        [int]$perfectEvaluation["passed_gate_count"] -eq 14 -and
        [string]$perfectEvaluation["selected_candidate_id"] -ceq "NONE"
    ) "$gateId evaluator rejected the neutral perfect synthetic matrix"

    $runToken = (Get-Date -Format "yyyyMMddTHHmmssfff") + "-" + [Guid]::NewGuid().ToString("N").Substring(0, 8)
    $tempRoot = Join-Path ([System.IO.Path]::GetFullPath($LogRoot)) $runToken
    [void][System.IO.Directory]::CreateDirectory($tempRoot)
    $projectRoot = New-Bw30nIsolatedProject -Root $tempRoot
    $referencePreflight = Invoke-Bw30nWorkerPreflight -GodotPath $godotPath `
        -ProjectRoot $projectRoot -TempRoot $tempRoot `
        -WorkerResource "res://tests/test_sdk_balanced_wave_bw30n_reference_worker.gd" `
        -CandidateId "BW30N-A"
    $successorPreflight = Invoke-Bw30nWorkerPreflight -GodotPath $godotPath `
        -ProjectRoot $projectRoot -TempRoot $tempRoot `
        -WorkerResource "res://tests/test_sdk_balanced_wave_bw30n_successor_worker.gd" `
        -CandidateId "BW30N-B"

    if ($PreflightOnly) {
        Write-Host (
            "$gateId SUPERVISOR_PREFLIGHT_PASS cells=24 reference=12 successor=12 " +
            "adapter_starts=$([int]$successorPreflight['adapter_start_count']) " +
            "gates=14 worlds=0 outcome_exposed=False physical_authority=False"
        )
        return
    }

    & pwsh -NoLogo -NoProfile -File $zeroWorldGatePath -Godot $godotPath
    Assert-Bw30nExact ($LASTEXITCODE -eq 0) (
        "$gateId complete zero-world authorization gate failed before physical entry"
    )

    Assert-Bw30nExact (-not [string]::IsNullOrWhiteSpace($OutputRoot)) (
        "$gateId -RunPhysical requires -OutputRoot under the durable evidence root"
    )
    Assert-Bw30nExact (-not [string]::IsNullOrWhiteSpace($FullConformanceAttestation)) (
        "$gateId -RunPhysical requires an exact full-Godot V2 attestation"
    )
    $status = @(git -C $repoRoot status --short)
    $head = (git -C $repoRoot rev-parse HEAD).Trim()
    $originMain = (git -C $repoRoot rev-parse origin/main).Trim()
    $liveLine = (git -C $repoRoot ls-remote origin refs/heads/main).Trim()
    $liveMain = ($liveLine -split "\s+")[0]
    Assert-Bw30nExact (
        $status.Count -eq 0 -and $head -cmatch "^[0-9a-f]{40}$" -and
        $head -ceq $originMain -and $head -ceq $liveMain
    ) "$gateId requires clean source with HEAD equal to live GitHub main"
    $attestationPath = [System.IO.Path]::GetFullPath($FullConformanceAttestation)
    $attestationVerification = Test-SporeSporeFullConformanceAttestationFile `
        -RepoRoot $repoRoot -Godot $godotPath -AttestationPath $attestationPath
    Assert-Bw30nExact (
        [bool]$attestationVerification.ok -and @($attestationVerification.failure_codes).Count -eq 0
    ) "$gateId full-Godot V2 attestation verification failed"
    $attestation = Get-Content -Raw -LiteralPath $attestationPath |
        ConvertFrom-Json -AsHashtable -Depth 64
    Assert-Bw30nExact (
        [string]$attestation["schema_version"] -ceq "sporespore_full_godot_conformance_attestation_v2" -and
        [string]$attestation["source"]["commit"] -ceq $head
    ) "$gateId attestation source identity changed"
    foreach ($claim in @("walking_acceptance", "release_authorized", "completed_engine_neutral_sdk", "physical_acceptance_authority")) {
        Assert-Bw30nExact (-not [bool]$attestation["claims"][$claim]) "$gateId attestation claim inflated: $claim"
    }
    & pwsh -NoLogo -NoProfile -File $freezeAuditPath -SkipSupervisorPreflight
    Assert-Bw30nExact ($LASTEXITCODE -eq 0) "$gateId freeze audit failed before physical entry"
    $resolvedOutputRoot = [System.IO.Path]::GetFullPath($OutputRoot)
    $prefix = $evidenceRoot.TrimEnd("\") + "\"
    Assert-Bw30nExact ($resolvedOutputRoot.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) (
        "$gateId output must be under $evidenceRoot"
    )
    Assert-Bw30nExact (-not (Test-Path -LiteralPath $resolvedOutputRoot)) (
        "$gateId output root already exists and may not be reused"
    )
    $priorAttempts = @()
    if (Test-Path -LiteralPath $evidenceRoot -PathType Container) {
        $priorAttempts = @(Get-ChildItem -LiteralPath $evidenceRoot -Filter attempt.json -File -Recurse |
            Where-Object {
                try {
                    $candidate = Get-Content -Raw -LiteralPath $_.FullName |
                        ConvertFrom-Json -AsHashtable -Depth 64
                    [string]$candidate["campaign_id"] -ceq $campaignId
                } catch { $false }
            })
    }
    Assert-Bw30nExact ($priorAttempts.Count -eq 0) "$gateId already has a retained attempt and may not rerun"

    [void][System.IO.Directory]::CreateDirectory($resolvedOutputRoot)
    $campaignAttemptId = [Guid]::NewGuid().ToString("N")
    $authorizationToken = [Guid]::NewGuid().ToString("N")
    $attemptPath = Join-Path $resolvedOutputRoot "attempt.json"
    $attempt = New-Bw30nAttemptRecord -Synthetic $false -AttemptId $campaignAttemptId `
        -AuthorizationToken $authorizationToken -GodotVersion $godotVersion `
        -GodotSha256 $godotSha -GodotRuntimeSha256 $runtimeSha `
        -AdapterSha256 $adapterSha -SourceCommit $head `
        -AttestationPath $attestationPath -AttestationSha256 (Get-Bw30nRawSha256 $attestationPath)
    Assert-Bw30nExact (Test-Bw30nAttemptRecord -Attempt $attempt -Synthetic $false) (
        "$gateId attempt constructor failed its exact parser"
    )
    Write-Bw30nNewJsonArtifact -Value $attempt -Path $attemptPath
    $attemptHashAtLaunch = Get-Bw30nRawSha256 $attemptPath

    $receipts = [System.Collections.Generic.List[object]]::new()
    $cellAttempts = [System.Collections.Generic.List[object]]::new()
    $ordinal = 0
    foreach ($cell in $cells) {
        $ordinal += 1
        $cellId = [string]$cell["cell_id"]
        $candidateId = [string]$cell["candidate_id"]
        $workerResource = if ($candidateId -ceq "BW30N-A") {
            "res://tests/test_sdk_balanced_wave_bw30n_reference_worker.gd"
        } else { "res://tests/test_sdk_balanced_wave_bw30n_successor_worker.gd" }
        $worldAttemptId = "BW30N-P1::$cellId"
        Write-Host "$gateId world $ordinal/24: $cellId"
        $cellRoot = Join-Path $resolvedOutputRoot ("cell-{0:D2}-{1}" -f $ordinal, $cellId)
        [void][System.IO.Directory]::CreateDirectory($cellRoot)
        $engineLog = Join-Path $cellRoot "engine.log"
        $execution = Invoke-Bw30nGodotCaptured -GodotPath $godotPath -Arguments @(
            "--headless", "--path", $projectRoot, "--log-file", $engineLog,
            "--script", $workerResource, "--", "physical", $cellId
        ) -WorkerRoot (Join-Path $tempRoot ("worker-{0:D2}" -f $ordinal)) `
            -TimeoutSeconds $CellTimeoutSeconds -AttemptPath $attemptPath `
            -AuthorizationToken $authorizationToken -CellId $cellId `
            -CandidateId $candidateId -WorldAttemptId $worldAttemptId `
            -CampaignAttemptId $campaignAttemptId
        $transcriptPath = Join-Path $cellRoot "transcript.log"
        $stderrPath = Join-Path $cellRoot "stderr.log"
        Write-Bw30nUtf8NoBom $transcriptPath ([string]$execution["stdout"])
        Write-Bw30nUtf8NoBom $stderrPath ([string]$execution["stderr"])
        $receipt = $null
        $parseError = ""
        try {
            $receipt = Get-Bw30nReceiptFromOutput -OutputText ([string]$execution["stdout"]) -Prefix $rawPrefix
        } catch { $parseError = $_.Exception.Message }
        if ($null -eq $receipt) {
            [void]$receipts.Add([ordered]@{
                cell_id = $cellId; receipt_missing = $true; receipt_parse_error = $parseError
            })
        } else { [void]$receipts.Add($receipt) }
        [void]$cellAttempts.Add([ordered]@{
            ordinal = $ordinal
            cell_id = $cellId
            candidate_id = $candidateId
            world_attempt_id = $worldAttemptId
            process_exit_code = [int]$execution["exit_code"]
            timed_out = [bool]$execution["timed_out"]
            killed_process_tree = [bool]$execution["killed_process_tree"]
            duration_seconds = [double]$execution["duration_seconds"]
            receipt_parsed = $null -ne $receipt
            receipt_parse_error = $parseError
            transcript_path = [System.IO.Path]::GetRelativePath($resolvedOutputRoot, $transcriptPath).Replace("\", "/")
            transcript_raw_sha256 = Get-Bw30nRawSha256 $transcriptPath
            stderr_path = [System.IO.Path]::GetRelativePath($resolvedOutputRoot, $stderrPath).Replace("\", "/")
            stderr_raw_sha256 = Get-Bw30nRawSha256 $stderrPath
            engine_log_path = [System.IO.Path]::GetRelativePath($resolvedOutputRoot, $engineLog).Replace("\", "/")
            engine_log_raw_sha256 = if (Test-Path -LiteralPath $engineLog) { Get-Bw30nRawSha256 $engineLog } else { "" }
        })
    }
    $source = [ordered]@{ commit = $head; worktree_clean = $true; matches_live_github_main = $true }
    $input = [ordered]@{
        schema_version = "sporespore_balanced_wave_bw30n_recovery_evaluation_input_v1"
        attempt_id = $campaignAttemptId
        source = $source
        cell_receipts = @($receipts)
    }
    $inputPath = Join-Path $resolvedOutputRoot "evaluation-input.json"
    Write-Bw30nNewJsonArtifact $input $inputPath
    $evaluation = Invoke-Bw30nRecoveryEvaluation -CellReceipts @($receipts) `
        -Source $source -AttemptId $campaignAttemptId
    $evaluationPath = Join-Path $resolvedOutputRoot "evaluation.json"
    Write-Bw30nNewJsonArtifact $evaluation $evaluationPath
    $report = [ordered]@{
        schema_version = "sporespore_balanced_wave_bw30n_recovery_report_v1"
        campaign_id = $campaignId
        gate_id = $gateId
        completed_at_utc = [DateTime]::UtcNow.ToString("o")
        source_commit = $head
        attempt_path = "attempt.json"
        attempt_raw_sha256 = Get-Bw30nRawSha256 $attemptPath
        attempt_immutable = (Get-Bw30nRawSha256 $attemptPath) -ceq $attemptHashAtLaunch
        evaluation_input_path = "evaluation-input.json"
        evaluation_input_raw_sha256 = Get-Bw30nRawSha256 $inputPath
        evaluation_path = "evaluation.json"
        evaluation_raw_sha256 = Get-Bw30nRawSha256 $evaluationPath
        cell_attempts = @($cellAttempts)
        evaluation = $evaluation
        selected_candidate_id = [string]$evaluation["selected_candidate_id"]
        fresh_nuisance_validation_ready = [bool]$evaluation["fresh_nuisance_validation_ready"]
        independent_validation_required = $true
        physical_acceptance_authority = $false
    }
    $reportPath = Join-Path $resolvedOutputRoot "report.json"
    Write-Bw30nNewJsonArtifact $report $reportPath
    $completion = [ordered]@{
        schema_version = "sporespore_balanced_wave_bw30n_recovery_completion_v1"
        campaign_id = $campaignId
        gate_id = $gateId
        completed_at_utc = [DateTime]::UtcNow.ToString("o")
        source_commit = $head
        report_path = "report.json"
        report_raw_sha256 = Get-Bw30nRawSha256 $reportPath
        valid_complete_result = [bool]$evaluation["ok"]
        selected_candidate_id = [string]$evaluation["selected_candidate_id"]
        expected_world_count = 24
        attempted_world_count = 24
        passed_gate_count = [int]$evaluation["passed_gate_count"]
        failed_gate_count = [int]$evaluation["failed_gate_count"]
        same_identity_rerun_allowed = $false
        physical_acceptance_authority = $false
    }
    $completionPath = Join-Path $resolvedOutputRoot "completion.json"
    Write-Bw30nNewJsonArtifact $completion $completionPath
    Write-Host (
        "$gateId CAMPAIGN_COMPLETE valid=$([bool]$evaluation['ok']) " +
        "selected=$([string]$evaluation['selected_candidate_id']) " +
        "gates=$([int]$evaluation['passed_gate_count'])/14 worlds=24 " +
        "fresh_ready=$([bool]$evaluation['fresh_nuisance_validation_ready']) " +
        "physical_authority=False report=$reportPath"
    )
    if (-not [bool]$evaluation["ok"]) {
        throw "$gateId first physical attempt was retained as invalid/incomplete"
    }
}

if ($MyInvocation.InvocationName -ne ".") {
    $operationLock = $null
    try {
        if ($RunPhysical) {
            $operationLock = Enter-SporeSporeLocomotionOperationLock -Role physical -TimeoutMilliseconds 0
            Assert-Bw30nExact ([bool]$operationLock.acquired) (
                "$gateId another conformance or physical operation owns the shared lock"
            )
        }
        Invoke-Bw30nSupervisorMain
    } finally {
        if ($null -ne $operationLock -and [bool]$operationLock.acquired) {
            Exit-SporeSporeLocomotionOperationLock $operationLock
        }
    }
}
