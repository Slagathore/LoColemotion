#requires -Version 7.0

[CmdletBinding()]
param(
    [switch]$PreflightOnly,
    [switch]$RunPhysical,
    [string]$Godot = (
        "C:\Users\Cole\CodeStuff\Misc\Godot\" +
        "Godot_v4.7-stable_mono_win64_console.exe"
    ),
    [string]$LogRoot = (Join-Path $PSScriptRoot "target\bw34y-rough-yaw-rescue-preflight"),
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
$attemptsRoot = Join-Path $evidenceRoot `
    "balanced-wave-bw34y-rough-yaw-rescue-development-attempts"
$campaignId = "BW34Y-BW33N-ROUGH-YAW-RESCUE-DEVELOPMENT"
$gateId = "BW34Y"
$closurePath = Join-Path $sdkRoot "balanced_wave_bw34y_rough_yaw_rescue_closure.json"
$manifestPath = Join-Path $sdkRoot "balanced_wave_bw34y_rough_yaw_rescue_manifest.json"
$freezePath = Join-Path $sdkRoot "balanced_wave_bw34y_rough_yaw_rescue_freeze.json"
$evaluatorPath = Join-Path $sdkRoot "balanced_wave_bw34y_rough_yaw_rescue_gate.ps1"
$zeroWorldGatePath = Join-Path $sdkRoot "run_balanced_wave_bw34y_rough_yaw_rescue_zero_world_gate.ps1"
$workerPath = Join-Path $repoRoot "tests\test_sdk_balanced_wave_bw34y_rough_yaw_rescue_worker.gd"
$workerResource = "res://tests/test_sdk_balanced_wave_bw34y_rough_yaw_rescue_worker.gd"
$freezeAuditPath = Join-Path $repoRoot "tests\test_bw34y_rough_yaw_rescue_freeze.ps1"
$adapterArtifactPath = Join-Path $sdkRoot "target\debug\sporespore_godot_adapter.dll"
$operationLockPath = Join-Path $sdkRoot "locomotion_operation_lock.ps1"
$attestationVerifierPath = Join-Path $sdkRoot "locomotion_full_conformance_attestation.ps1"
$artifactStorePath = Join-Path $sdkRoot "content_addressed_artifact_store.ps1"
$rawPrefix = "BW34Y_ROUGH_YAW_RESCUE_RAW_CELL "
$preflightPrefix = "BW34Y_ROUGH_YAW_RESCUE_WORKER_PREFLIGHT "
$realShapedPrefix = "BW34Y_ROUGH_YAW_RESCUE_REAL_SHAPED_RECEIPTS "

# This current-source guard is runtime safety only. The closure audit proves
# the historical experiment identity from retained CAS payloads and Git blobs.
if (Test-Path -LiteralPath $closurePath -PathType Leaf) {
    throw "$gateId campaign is closed and may not rerun"
}

. $evaluatorPath
. $operationLockPath
. $attestationVerifierPath
. $artifactStorePath

function Assert-Bw34yExact {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function Get-Bw34yRawSha256 {
    param([Parameter(Mandatory)][string]$Path)
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Write-Bw34yUtf8NoBom {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][AllowEmptyString()][string]$Text
    )
    [System.IO.File]::WriteAllText(
        $Path,
        $Text,
        [System.Text.UTF8Encoding]::new($false)
    )
}

function Write-Bw34yNewJsonArtifact {
    param(
        [Parameter(Mandatory)]$Value,
        [Parameter(Mandatory)][string]$Path
    )
    Assert-Bw34yExact (-not (Test-Path -LiteralPath $Path)) (
        "Refusing to overwrite $gateId artifact: $Path"
    )
    [void][System.IO.Directory]::CreateDirectory((Split-Path -Parent $Path))
    $temporary = $Path + ".tmp"
    Assert-Bw34yExact (-not (Test-Path -LiteralPath $temporary)) (
        "Refusing stale temporary artifact: $temporary"
    )
    Write-Bw34yUtf8NoBom $temporary (
        ($Value | ConvertTo-Json -Depth 64) + [Environment]::NewLine
    )
    Move-Item -LiteralPath $temporary -Destination $Path
}

function Get-Bw34yReceiptFromOutput {
    param(
        [Parameter(Mandatory)][string]$OutputText,
        [Parameter(Mandatory)][string]$Prefix
    )
    $lines = @($OutputText -split "\r?\n" | Where-Object { $_.StartsWith($Prefix) })
    if ($lines.Count -ne 1) {
        throw "Expected one '$Prefix' receipt, found $($lines.Count)"
    }
    return $lines[0].Substring($Prefix.Length) |
        ConvertFrom-Json -AsHashtable -Depth 64
}

function New-Bw34yIsolatedProject {
    param([Parameter(Mandatory)][string]$Root)
    $projectRoot = Join-Path $Root "project"
    [void][System.IO.Directory]::CreateDirectory($projectRoot)
    foreach ($directory in @("scripts", "tests", "sdk")) {
        $link = Join-Path $projectRoot $directory
        if (-not (Test-Path -LiteralPath $link)) {
            [void](New-Item -ItemType Junction -Path $link `
                -Target (Join-Path $repoRoot $directory))
        }
    }
    $attributesLink = Join-Path $projectRoot ".gitattributes"
    if (-not (Test-Path -LiteralPath $attributesLink)) {
        [void](New-Item -ItemType HardLink -Path $attributesLink `
            -Target (Join-Path $repoRoot ".gitattributes"))
    }
    $projectText = @"
; Isolated SporeSpore BW34Y worker.

config_version=5

[application]

config/name="sporespore-bw34y-rough-yaw-rescue"
config/features=PackedStringArray("4.7", "Forward Plus")

[debug]

gdscript/warnings/shadowed_global_identifier=0

[physics]

3d/physics_engine="Jolt Physics"
jolt_physics_3d/simulation/velocity_steps=20
jolt_physics_3d/simulation/position_steps=7
"@
    Write-Bw34yUtf8NoBom (Join-Path $projectRoot "project.godot") $projectText
    return $projectRoot
}

function Invoke-Bw34yGodotCaptured {
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
    foreach ($name in @(
        "SPORESPORE_BW34Y_ATTEMPT", "SPORESPORE_BW34Y_TOKEN",
        "SPORESPORE_BW34Y_CELL", "SPORESPORE_BW34Y_CANDIDATE",
        "SPORESPORE_BW34Y_WORLD_ATTEMPT_ID", "SPORESPORE_BW34Y_CAMPAIGN_ATTEMPT_ID"
    )) { [void]$start.Environment.Remove($name) }
    if (-not [string]::IsNullOrWhiteSpace($AttemptPath)) {
        $start.Environment["SPORESPORE_BW34Y_ATTEMPT"] = $AttemptPath
        $start.Environment["SPORESPORE_BW34Y_TOKEN"] = $AuthorizationToken
        $start.Environment["SPORESPORE_BW34Y_CELL"] = $CellId
        $start.Environment["SPORESPORE_BW34Y_CANDIDATE"] = $CandidateId
        $start.Environment["SPORESPORE_BW34Y_WORLD_ATTEMPT_ID"] = $WorldAttemptId
        $start.Environment["SPORESPORE_BW34Y_CAMPAIGN_ATTEMPT_ID"] = $CampaignAttemptId
    }
    foreach ($argument in $Arguments) { [void]$start.ArgumentList.Add($argument) }
    $process = [System.Diagnostics.Process]::new()
    $process.StartInfo = $start
    $started = [DateTime]::UtcNow
    Assert-Bw34yExact ([bool]$process.Start()) "Failed to start isolated Godot"
    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()
    $timedOut = -not $process.WaitForExit($TimeoutSeconds * 1000)
    $killed = $false
    if ($timedOut) {
        try { $process.Kill($true); $killed = $true } catch { $killed = $false }
        [void]$process.WaitForExit(10000)
    }
    $stdout = $stdoutTask.GetAwaiter().GetResult()
    $stderr = $stderrTask.GetAwaiter().GetResult()
    $result = [ordered]@{
        exit_code = if ($process.HasExited) { $process.ExitCode } else { -1 }
        timed_out = $timedOut
        killed_process_tree = $killed
        duration_seconds = ([DateTime]::UtcNow - $started).TotalSeconds
        stdout = $stdout
        stderr = $stderr
    }
    $process.Dispose()
    return $result
}

function Get-Bw34yFrozenSourceBindings {
    $freeze = Read-Bw34yJsonMap $freezePath
    return [System.Collections.IDictionary]$freeze.source_bindings
}

function Publish-Bw34yInputSet {
    param(
        [Parameter(Mandatory)][string]$GodotPath,
        [Parameter(Mandatory)][string]$RuntimePath,
        [Parameter(Mandatory)][string]$AttestationPath
    )
    $inputs = [ordered]@{}
    foreach ($entry in @(
        @{ name = "godot_console"; path = $GodotPath; media = "application/vnd.microsoft.portable-executable" },
        @{ name = "godot_runtime"; path = $RuntimePath; media = "application/vnd.microsoft.portable-executable" },
        @{ name = "godot_adapter"; path = $adapterArtifactPath; media = "application/vnd.microsoft.portable-executable" },
        @{ name = "full_godot_v2_attestation"; path = $AttestationPath; media = "application/json" },
        @{ name = "stage_one_freeze"; path = $freezePath; media = "application/json" }
    )) {
        $inputs[$entry.name] = Publish-SporeSporeContentAddressedArtifact `
            -RepoRoot $repoRoot -ArtifactPath $entry.path -MediaType $entry.media
    }
    foreach ($bindingEntry in (Get-Bw34yFrozenSourceBindings).GetEnumerator()) {
        $relative = [string]$bindingEntry.Value.path
        $safeName = "source_" + ($bindingEntry.Key -replace '[^A-Za-z0-9_]', '_')
        $inputs[$safeName] = Publish-SporeSporeContentAddressedArtifact `
            -RepoRoot $repoRoot -ArtifactPath (Join-Path $repoRoot $relative) `
            -MediaType "application/octet-stream"
    }
    return $inputs
}

function New-Bw34yAttemptRecord {
    param(
        [Parameter(Mandatory)][bool]$Synthetic,
        [Parameter(Mandatory)][string]$AttemptId,
        [Parameter(Mandatory)][string]$AuthorizationToken,
        [Parameter(Mandatory)][string]$GodotVersion,
        [Parameter(Mandatory)][string]$GodotSha256,
        [Parameter(Mandatory)][string]$GodotRuntimeSha256,
        [Parameter(Mandatory)][string]$AdapterSha256,
        [Parameter(Mandatory)][System.Collections.IDictionary]$ContentAddressedInputs,
        [string]$SourceCommit = "",
        [string]$AttestationPath = "",
        [string]$AttestationSha256 = ""
    )
    $manifest = Read-Bw34yJsonMap $manifestPath
    $cellIds = @($manifest.ordered_cells | ForEach-Object { [string]$_.cell_id })
    return [ordered]@{
        schema_version = "sporespore_balanced_wave_bw34y_rough_yaw_rescue_attempt_v1"
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
        source_bindings = Get-Bw34yFrozenSourceBindings
        content_addressed_inputs = $ContentAddressedInputs
        complete_zero_world_gate_passed = $true
        stage_one_freeze_verified = $true
        full_godot_v2_attestation_path = if ($Synthetic) {
            "synthetic_preflight_no_attestation"
        } else { $AttestationPath }
        full_godot_v2_attestation_sha256 = if ($Synthetic) {
            "synthetic_preflight_no_attestation"
        } else { $AttestationSha256 }
        physical_identity_consumed = -not $Synthetic
        same_identity_rerun_allowed = $false
        locomotion_outcome_exposed_at_attempt = $false
        retained_physical_execution_serialized = $true
        expected_world_count = 3
        ordered_cell_ids = $cellIds
        primary_world_attempt_ids = @($cellIds | ForEach-Object { "BW34Y-P1::$_" })
        physical_acceptance_authority = $false
    }
}

function Test-Bw34yAttemptRecord {
    param(
        [Parameter(Mandatory)][System.Collections.IDictionary]$Attempt,
        [Parameter(Mandatory)][bool]$Synthetic
    )
    try {
    $sourceExact = if ($Synthetic) {
        [string]$Attempt.source_commit -ceq "synthetic_preflight_no_source_identity" -and
        [string]::IsNullOrEmpty([string]$Attempt.origin_main_commit) -and
        [string]::IsNullOrEmpty([string]$Attempt.remote_main_commit) -and
        -not [bool]$Attempt.source_worktree_clean -and
        -not [bool]$Attempt.source_matches_live_github_main
    } else {
        [string]$Attempt.source_commit -cmatch '^[0-9a-f]{40}$' -and
        [string]$Attempt.origin_main_commit -ceq [string]$Attempt.source_commit -and
        [string]$Attempt.remote_main_commit -ceq [string]$Attempt.source_commit -and
        [bool]$Attempt.source_worktree_clean -and
        [bool]$Attempt.source_matches_live_github_main
    }
    $casExact = if ($Synthetic) {
        ([System.Collections.IDictionary]$Attempt.content_addressed_inputs).Count -eq 0
    } else {
        $cas = [System.Collections.IDictionary]$Attempt.content_addressed_inputs
        $bindings = [System.Collections.IDictionary]$Attempt.source_bindings
        $linked = (
            [string]$cas.godot_console.sha256 -ceq
                "sha256:$([string]$Attempt.godot_executable_sha256)" -and
            [string]$cas.godot_runtime.sha256 -ceq
                "sha256:$([string]$Attempt.godot_runtime_executable_sha256)" -and
            [string]$cas.godot_adapter.sha256 -ceq
                "sha256:$([string]$Attempt.godot_adapter_artifact_sha256)" -and
            [string]$cas.full_godot_v2_attestation.sha256 -ceq
                "sha256:$([string]$Attempt.full_godot_v2_attestation_sha256)" -and
            [string]$cas.stage_one_freeze.sha256 -ceq
                "sha256:$(Get-Bw34yRawSha256 $freezePath)"
        )
        foreach ($bindingEntry in $bindings.GetEnumerator()) {
            $key = "source_" + $bindingEntry.Key
            $linked = $linked -and $cas.Contains($key) -and
                [string]$cas[$key].sha256 -ceq "sha256:$([string]$bindingEntry.Value.raw_sha256)"
        }
        $cas.Count -ge (5 + $bindings.Count) -and $linked -and @($cas.Values | Where-Object {
            -not (Test-Path -LiteralPath ([string]$_.payload_path) -PathType Leaf) -or
            ("sha256:" + (Get-Bw34yRawSha256 ([string]$_.payload_path))) -cne [string]$_.sha256
        }).Count -eq 0
    }
    return (
        [string]$Attempt.schema_version -ceq
            "sporespore_balanced_wave_bw34y_rough_yaw_rescue_attempt_v1" -and
        [string]$Attempt.campaign_id -ceq $campaignId -and
        [string]$Attempt.gate_id -ceq $gateId -and
        [bool]$Attempt.synthetic_contract_preflight -eq $Synthetic -and
        $sourceExact -and $casExact -and
        [string]$Attempt.attempt_id -cmatch '^[0-9a-f]{32}$' -and
        [string]$Attempt.authorization_token -cmatch '^[0-9a-f]{32}$' -and
        [bool]$Attempt.complete_zero_world_gate_passed -and
        [bool]$Attempt.stage_one_freeze_verified -and
        [bool]$Attempt.physical_identity_consumed -eq (-not $Synthetic) -and
        -not [bool]$Attempt.same_identity_rerun_allowed -and
        -not [bool]$Attempt.locomotion_outcome_exposed_at_attempt -and
        [bool]$Attempt.retained_physical_execution_serialized -and
        [int]$Attempt.expected_world_count -eq 3 -and
        @($Attempt.ordered_cell_ids).Count -eq 3 -and
        @($Attempt.primary_world_attempt_ids).Count -eq 3 -and
        -not [bool]$Attempt.physical_acceptance_authority
    )
    } catch {
        return $false
    }
}

function Invoke-Bw34yWorkerMode {
    param(
        [Parameter(Mandatory)][string]$GodotPath,
        [Parameter(Mandatory)][string]$ProjectRoot,
        [Parameter(Mandatory)][string]$TempRoot,
        [Parameter(Mandatory)][string]$Mode,
        [Parameter(Mandatory)][string]$Prefix
    )
    $execution = Invoke-Bw34yGodotCaptured -GodotPath $GodotPath -Arguments @(
        "--headless", "--path", $ProjectRoot,
        "--log-file", (Join-Path $TempRoot "$Mode-engine.log"),
        "--script", $workerResource, "--", $Mode
    ) -WorkerRoot (Join-Path $TempRoot $Mode) -TimeoutSeconds 300
    $receipt = Get-Bw34yReceiptFromOutput `
        -OutputText ([string]$execution.stdout) -Prefix $Prefix
    Assert-Bw34yExact (
        [int]$execution.exit_code -eq 0 -and
        -not [bool]$execution.timed_out -and
        [bool]$receipt.ok -and
        [int]$receipt.entrypoint_count -eq 3 -and
        [int]$receipt.actual_world_build_count -eq 0 -and
        [int]$receipt.scene_tree_insertion_count -eq 0 -and
        -not [bool]$receipt.physics_state_modified -and
        -not [bool]$receipt.locomotion_outcome_exposed -and
        -not [bool]$receipt.physical_acceptance_authority
    ) "$gateId worker mode failed: $Mode"
    return $receipt
}

function Invoke-Bw34ySupervisorMain {
    Assert-Bw34yExact ([bool]$PreflightOnly -xor [bool]$RunPhysical) (
        "Specify exactly one of -PreflightOnly or -RunPhysical"
    )
    Assert-Bw34yExact ($CellTimeoutSeconds -ge 60 -and $CellTimeoutSeconds -le 900) (
        "-CellTimeoutSeconds must be between 60 and 900"
    )
    foreach ($path in @(
        $manifestPath, $freezePath, $evaluatorPath, $zeroWorldGatePath,
        $workerPath, $freezeAuditPath, $adapterArtifactPath,
        $operationLockPath, $attestationVerifierPath, $artifactStorePath
    )) {
        Assert-Bw34yExact (Test-Path -LiteralPath $path -PathType Leaf) (
            "Missing $gateId source: $path"
        )
    }
    $manifest = Read-Bw34yJsonMap $manifestPath
    $cells = @($manifest.ordered_cells)
    Assert-Bw34yExact ($cells.Count -eq 3) "$gateId manifest must contain 3 cells"
    $godotPath = [System.IO.Path]::GetFullPath($Godot)
    $runtimePath = $godotPath.Replace("_console.exe", ".exe")
    Assert-Bw34yExact (Test-Path -LiteralPath $godotPath -PathType Leaf) "Godot executable missing"
    Assert-Bw34yExact (Test-Path -LiteralPath $runtimePath -PathType Leaf) "Godot runtime missing"
    $godotVersion = (& $godotPath --version 2>&1 | Out-String).Trim()
    Assert-Bw34yExact ($godotVersion -ceq "4.7.stable.mono.official.5b4e0cb0f") (
        "Unexpected Godot version: $godotVersion"
    )
    $godotSha = Get-Bw34yRawSha256 $godotPath
    $runtimeSha = Get-Bw34yRawSha256 $runtimePath
    $adapterSha = Get-Bw34yRawSha256 $adapterArtifactPath
    $runToken = (Get-Date -Format "yyyyMMddTHHmmssfff") + "-" +
        [Guid]::NewGuid().ToString("N").Substring(0, 8)
    $tempRoot = Join-Path ([System.IO.Path]::GetFullPath($LogRoot)) $runToken
    [void][System.IO.Directory]::CreateDirectory($tempRoot)
    $projectRoot = New-Bw34yIsolatedProject $tempRoot
    $entrypointPreflight = Invoke-Bw34yWorkerMode -GodotPath $godotPath `
        -ProjectRoot $projectRoot -TempRoot $tempRoot `
        -Mode "preflight-all" -Prefix $preflightPrefix
    $realShaped = Invoke-Bw34yWorkerMode -GodotPath $godotPath `
        -ProjectRoot $projectRoot -TempRoot $tempRoot `
        -Mode "receipt-preflight-all" -Prefix $realShapedPrefix
    $source = [ordered]@{
        commit = "synthetic_preflight_no_source_identity"
        worktree_clean = $false
        matches_live_github_main = $false
    }
    $evaluation = Invoke-Bw34yRoughYawRescueEvaluation `
        -CellReceipts @($realShaped.cell_receipts) `
        -Source $source -AttemptId ("a" * 32)
    Assert-Bw34yExact (
        [bool]$evaluation.ok -and
        [int]$evaluation.observed_receipt_count -eq 3 -and
        [int]$evaluation.invalid_cell_count -eq 0 -and
        [int]$evaluation.valid_walking_negative_count -eq 2 -and
        [string]$evaluation.selected_candidate_id -ceq "NONE"
    ) "$gateId evaluator rejected actual-composer real-shaped receipts"
    $syntheticAttempt = New-Bw34yAttemptRecord -Synthetic $true `
        -AttemptId ("b" * 32) -AuthorizationToken ("c" * 32) `
        -GodotVersion $godotVersion -GodotSha256 $godotSha `
        -GodotRuntimeSha256 $runtimeSha -AdapterSha256 $adapterSha `
        -ContentAddressedInputs ([ordered]@{})
    Assert-Bw34yExact (Test-Bw34yAttemptRecord $syntheticAttempt $true) (
        "$gateId synthetic attempt constructor failed"
    )
    if ($PreflightOnly) {
        Write-Host (
            "$gateId SUPERVISOR_PREFLIGHT_PASS cells=3 adapter_starts=" +
            "$([int]$entrypointPreflight.adapter_start_count) real_receipts=3 " +
            "valid_walking_negatives=$([int]$evaluation.valid_walking_negative_count) " +
            "selected_canary=NONE worlds=0 physical_authority=False"
        )
        return
    }

    & pwsh -NoLogo -NoProfile -File $zeroWorldGatePath -Godot $godotPath
    Assert-Bw34yExact ($LASTEXITCODE -eq 0) (
        "$gateId complete zero-world gate failed before physical entry"
    )
    Assert-Bw34yExact (-not [string]::IsNullOrWhiteSpace($OutputRoot)) (
        "$gateId -RunPhysical requires a new -OutputRoot under $attemptsRoot"
    )
    Assert-Bw34yExact (-not [string]::IsNullOrWhiteSpace($FullConformanceAttestation)) (
        "$gateId -RunPhysical requires an exact full-Godot V2 attestation"
    )
    $status = @(git -C $repoRoot status --short)
    $head = (git -C $repoRoot rev-parse HEAD).Trim()
    $originMain = (git -C $repoRoot rev-parse origin/main).Trim()
    $liveLine = (git -C $repoRoot ls-remote origin refs/heads/main).Trim()
    $liveMain = ($liveLine -split '\s+')[0]
    Assert-Bw34yExact (
        $status.Count -eq 0 -and
        $head -cmatch '^[0-9a-f]{40}$' -and
        $head -ceq $originMain -and $head -ceq $liveMain
    ) "$gateId requires clean source with HEAD equal to live GitHub main"
    $attestationPath = [System.IO.Path]::GetFullPath($FullConformanceAttestation)
    $attestationVerification = Test-SporeSporeFullConformanceAttestationFile `
        -RepoRoot $repoRoot -Godot $godotPath -AttestationPath $attestationPath
    Assert-Bw34yExact (
        [bool]$attestationVerification.ok -and
        @($attestationVerification.failure_codes).Count -eq 0
    ) "$gateId full-Godot V2 attestation verification failed"
    $attestation = Read-Bw34yJsonMap $attestationPath
    Assert-Bw34yExact (
        [string]$attestation.schema_version -ceq
            "sporespore_full_godot_conformance_attestation_v2" -and
        [string]$attestation.source.commit -ceq $head
    ) "$gateId attestation source identity changed"
    & pwsh -NoLogo -NoProfile -File $freezeAuditPath -SkipSupervisorPreflight
    Assert-Bw34yExact ($LASTEXITCODE -eq 0) "$gateId freeze audit failed"
    $resolvedOutput = [System.IO.Path]::GetFullPath($OutputRoot)
    $requiredPrefix = [System.IO.Path]::GetFullPath($attemptsRoot).TrimEnd('\') + '\'
    Assert-Bw34yExact (
        $resolvedOutput.StartsWith($requiredPrefix, [StringComparison]::OrdinalIgnoreCase)
    ) "$gateId output must be a child of $attemptsRoot"
    Assert-Bw34yExact (-not (Test-Path -LiteralPath $resolvedOutput)) (
        "$gateId output root already exists and may not be reused"
    )
    $priorAttempts = @()
    if (Test-Path -LiteralPath $attemptsRoot -PathType Container) {
        $priorAttempts = @(Get-ChildItem -LiteralPath $attemptsRoot `
            -Filter attempt.json -File -Recurse)
    }
    Assert-Bw34yExact ($priorAttempts.Count -eq 0) (
        "$gateId already has a retained attempt and may not rerun"
    )
    [void][System.IO.Directory]::CreateDirectory($resolvedOutput)
    $casInputs = Publish-Bw34yInputSet -GodotPath $godotPath `
        -RuntimePath $runtimePath -AttestationPath $attestationPath
    $campaignAttemptId = [Guid]::NewGuid().ToString("N")
    $authorizationToken = [Guid]::NewGuid().ToString("N")
    $attempt = New-Bw34yAttemptRecord -Synthetic $false `
        -AttemptId $campaignAttemptId -AuthorizationToken $authorizationToken `
        -GodotVersion $godotVersion -GodotSha256 $godotSha `
        -GodotRuntimeSha256 $runtimeSha -AdapterSha256 $adapterSha `
        -ContentAddressedInputs $casInputs -SourceCommit $head `
        -AttestationPath $attestationPath `
        -AttestationSha256 (Get-Bw34yRawSha256 $attestationPath)
    Assert-Bw34yExact (Test-Bw34yAttemptRecord $attempt $false) (
        "$gateId physical attempt constructor failed"
    )
    $attemptPath = Join-Path $resolvedOutput "attempt.json"
    Write-Bw34yNewJsonArtifact $attempt $attemptPath
    $attemptHashAtLaunch = Get-Bw34yRawSha256 $attemptPath

    $receipts = [System.Collections.Generic.List[object]]::new()
    $cellAttempts = [System.Collections.Generic.List[object]]::new()
    $ordinal = 0
    foreach ($cell in $cells) {
        $ordinal += 1
        $cellId = [string]$cell.cell_id
        $candidateId = [string]$cell.candidate_id
        $worldAttemptId = "BW34Y-P1::$cellId"
        Write-Host "$gateId world $ordinal/3: $cellId"
        $cellRoot = Join-Path $resolvedOutput ("cell-{0:D2}-{1}" -f $ordinal, $cellId)
        [void][System.IO.Directory]::CreateDirectory($cellRoot)
        $engineLog = Join-Path $cellRoot "engine.log"
        $execution = Invoke-Bw34yGodotCaptured -GodotPath $godotPath -Arguments @(
            "--headless", "--path", $projectRoot, "--log-file", $engineLog,
            "--script", $workerResource, "--", "physical", $cellId
        ) -WorkerRoot (Join-Path $tempRoot ("worker-{0:D2}" -f $ordinal)) `
            -TimeoutSeconds $CellTimeoutSeconds -AttemptPath $attemptPath `
            -AuthorizationToken $authorizationToken -CellId $cellId `
            -CandidateId $candidateId -WorldAttemptId $worldAttemptId `
            -CampaignAttemptId $campaignAttemptId
        $transcriptPath = Join-Path $cellRoot "transcript.log"
        $stderrPath = Join-Path $cellRoot "stderr.log"
        Write-Bw34yUtf8NoBom $transcriptPath ([string]$execution.stdout)
        Write-Bw34yUtf8NoBom $stderrPath ([string]$execution.stderr)
        $receipt = $null
        $receiptCas = $null
        $parseError = ""
        try {
            $receipt = Get-Bw34yReceiptFromOutput `
                -OutputText ([string]$execution.stdout) -Prefix $rawPrefix
        } catch { $parseError = $_.Exception.Message }
        if ($null -eq $receipt) {
            [void]$receipts.Add([ordered]@{
                cell_id = $cellId
                receipt_missing = $true
                receipt_parse_error = $parseError
            })
        } else {
            $receiptPath = Join-Path $cellRoot "raw-receipt.json"
            Write-Bw34yNewJsonArtifact $receipt $receiptPath
            $receiptCas = Publish-SporeSporeContentAddressedArtifact `
                -RepoRoot $repoRoot -ArtifactPath $receiptPath -MediaType "application/json"
            [void]$receipts.Add($receipt)
        }
        $transcriptCas = Publish-SporeSporeContentAddressedArtifact `
            -RepoRoot $repoRoot -ArtifactPath $transcriptPath -MediaType "text/plain"
        $stderrCas = Publish-SporeSporeContentAddressedArtifact `
            -RepoRoot $repoRoot -ArtifactPath $stderrPath -MediaType "text/plain"
        $engineCas = if (Test-Path -LiteralPath $engineLog -PathType Leaf) {
            Publish-SporeSporeContentAddressedArtifact `
                -RepoRoot $repoRoot -ArtifactPath $engineLog -MediaType "text/plain"
        } else { $null }
        [void]$cellAttempts.Add([ordered]@{
            ordinal = $ordinal
            cell_id = $cellId
            candidate_id = $candidateId
            world_attempt_id = $worldAttemptId
            process_exit_code = [int]$execution.exit_code
            timed_out = [bool]$execution.timed_out
            killed_process_tree = [bool]$execution.killed_process_tree
            duration_seconds = [double]$execution.duration_seconds
            receipt_parsed = $null -ne $receipt
            receipt_parse_error = $parseError
            receipt_content_addressed = if ($null -ne $receipt) { $receiptCas } else { $null }
            transcript_content_addressed = $transcriptCas
            stderr_content_addressed = $stderrCas
            engine_log_content_addressed = $engineCas
        })
    }
    $source = [ordered]@{
        commit = $head
        worktree_clean = $true
        matches_live_github_main = $true
    }
    $input = [ordered]@{
        schema_version = "sporespore_balanced_wave_bw34y_rough_yaw_rescue_evaluation_input_v1"
        attempt_id = $campaignAttemptId
        source = $source
        cell_receipts = @($receipts)
    }
    $inputPath = Join-Path $resolvedOutput "evaluation-input.json"
    Write-Bw34yNewJsonArtifact $input $inputPath
    $inputCas = Publish-SporeSporeContentAddressedArtifact `
        -RepoRoot $repoRoot -ArtifactPath $inputPath -MediaType "application/json"
    $evaluationPath = Join-Path $resolvedOutput "evaluation.json"
    & pwsh -NoLogo -NoProfile -File $evaluatorPath `
        -InputPath ([string]$inputCas.payload_path) -OutputPath $evaluationPath
    $evaluationExit = $LASTEXITCODE
    Assert-Bw34yExact (Test-Path -LiteralPath $evaluationPath -PathType Leaf) (
        "$gateId cold evaluator did not retain an evaluation"
    )
    $evaluation = Read-Bw34yJsonMap $evaluationPath
    $evaluationCas = Publish-SporeSporeContentAddressedArtifact `
        -RepoRoot $repoRoot -ArtifactPath $evaluationPath -MediaType "application/json"
    $report = [ordered]@{
        schema_version = "sporespore_balanced_wave_bw34y_rough_yaw_rescue_report_v1"
        campaign_id = $campaignId
        gate_id = $gateId
        completed_at_utc = [DateTime]::UtcNow.ToString("o")
        source_commit = $head
        attempt_path = "attempt.json"
        attempt_raw_sha256 = Get-Bw34yRawSha256 $attemptPath
        attempt_immutable = (Get-Bw34yRawSha256 $attemptPath) -ceq $attemptHashAtLaunch
        evaluation_input_content_addressed = $inputCas
        evaluation_content_addressed = $evaluationCas
        cold_evaluator_exit_code = $evaluationExit
        cell_attempts = @($cellAttempts)
        evaluation = $evaluation
        selected_candidate_id = [string]$evaluation.selected_candidate_id
        full_nuisance_development_successor_may_be_declared = (
            [bool]$evaluation.ok -and
            [string]$evaluation.selected_candidate_id -notin @("NONE", "INVALID")
        )
        fresh_validation_authority = $false
        rough_terrain_acceptance = $false
        release_authorized = $false
        physical_acceptance_authority = $false
    }
    $reportPath = Join-Path $resolvedOutput "report.json"
    Write-Bw34yNewJsonArtifact $report $reportPath
    $reportCas = Publish-SporeSporeContentAddressedArtifact `
        -RepoRoot $repoRoot -ArtifactPath $reportPath -MediaType "application/json"
    $completion = [ordered]@{
        schema_version = "sporespore_balanced_wave_bw34y_rough_yaw_rescue_completion_v1"
        campaign_id = $campaignId
        gate_id = $gateId
        completed_at_utc = [DateTime]::UtcNow.ToString("o")
        source_commit = $head
        report_content_addressed = $reportCas
        valid_complete_result = [bool]$evaluation.ok
        selected_candidate_id = [string]$evaluation.selected_candidate_id
        expected_world_count = 3
        attempted_world_count = 3
        same_identity_rerun_allowed = $false
        fresh_validation_authority = $false
        rough_terrain_acceptance = $false
        release_authorized = $false
        physical_acceptance_authority = $false
    }
    $completionPath = Join-Path $resolvedOutput "completion.json"
    Write-Bw34yNewJsonArtifact $completion $completionPath
    $completionCas = Publish-SporeSporeContentAddressedArtifact `
        -RepoRoot $repoRoot -ArtifactPath $completionPath -MediaType "application/json"
    Write-Host (
        "$gateId CAMPAIGN_COMPLETE valid=$([bool]$evaluation.ok) " +
        "selected=$([string]$evaluation.selected_candidate_id) worlds=3 " +
        "valid_walking_negatives=$([int]$evaluation.valid_walking_negative_count) " +
        "completion_cas=$([string]$completionCas.sha256) physical_authority=False"
    )
    if (-not [bool]$evaluation.ok) {
        throw "$gateId first physical attempt was retained as invalid/incomplete"
    }
}

if ($MyInvocation.InvocationName -ne ".") {
    $operationLock = $null
    try {
        if ($RunPhysical) {
            $operationLock = Enter-SporeSporeLocomotionOperationLock `
                -Role physical -TimeoutMilliseconds 0
            Assert-Bw34yExact ([bool]$operationLock.acquired) (
                "$gateId another conformance or physical operation owns the shared lock"
            )
        }
        Invoke-Bw34ySupervisorMain
    } finally {
        if ($null -ne $operationLock -and [bool]$operationLock.acquired) {
            Exit-SporeSporeLocomotionOperationLock $operationLock
        }
    }
}
