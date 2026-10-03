#requires -Version 7.0

[CmdletBinding()]
param(
    [switch]$PreflightOnly,
    [switch]$RunPhysical,
    [string]$CampaignAttestationAdoption = "",
    [string]$OutputRoot = "",
    [string]$Godot = (
        "C:\Users\Cole\CodeStuff\Misc\Godot\" +
        "Godot_v4.7-stable_mono_win64_console.exe"
    ),
    [string]$Python = "python",
    [string]$PowerShell = "pwsh",
    [ValidateRange(300, 3600)][int]$CellTimeoutSeconds = 900
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$sdkRoot = [IO.Path]::GetFullPath($PSScriptRoot)
$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $sdkRoot))
$turningRoot = Join-Path $sdkRoot "turning"
$mujocoRoot = Join-Path $sdkRoot "adapters\mujoco"
$mujocoSitePackages = Join-Path $mujocoRoot ".venv\Lib\site-packages"
$campaignId = "QSDK-R23D39-MUJOCO-R23D29-STARTUP-RAMP-TURNING-DEVELOPMENT"
$gateId = "QSDK-R23D39"
$stageId = "mujoco_r23d29_startup_ramp_turning_development"
$candidateId = "r23d29_startup_ramp_turning_development"
$matrix = @(
    [ordered]@{
        arm_id = "reference_zero"
        turn_heading_offset_rad = 0.0
        cell_id = "mujoco`__$candidateId`__reference_zero"
    },
    [ordered]@{
        arm_id = "positive_heading"
        turn_heading_offset_rad = 0.2
        cell_id = "mujoco`__$candidateId`__positive_heading"
    },
    [ordered]@{
        arm_id = "negative_heading"
        turn_heading_offset_rad = -0.2
        cell_id = "mujoco`__$candidateId`__negative_heading"
    }
)
$cellIds = @($matrix | ForEach-Object { [string]$_.cell_id })
$preregistrationPath = Join-Path $turningRoot (
    "r23d39_mujoco_startup_ramp_turning_preregistration_v1.json"
)
$implementationPath = Join-Path $turningRoot (
    "r23d39_mujoco_startup_ramp_turning_implementation_v1.json"
)
$manifestPath = Join-Path $turningRoot "r23d39_campaign_attestation_manifest_v1.json"
$evaluatorPath = Join-Path $turningRoot (
    "r23d39_mujoco_startup_ramp_turning_evaluator.py"
)
$runtimeHelperPath = Join-Path $sdkRoot "r23d3_reproducible_runtime_materialization.ps1"
$coreDebugPath = Join-Path $sdkRoot "target\debug\sporespore_locomotion_core.dll"
$coreReleasePath = Join-Path $sdkRoot "target\release\sporespore_locomotion_core.dll"
$physicalEnvironmentNames = @(
    "SPORESPORE_QSDK_R23D39_FREEZE",
    "SPORESPORE_QSDK_R23D39_ATTEMPT",
    "SPORESPORE_QSDK_R23D39_TOKEN",
    "SPORESPORE_QSDK_R23D39_STAGE",
    "SPORESPORE_QSDK_R23D39_CELL",
    "SPORESPORE_QSDK_R23D39_ENGINE",
    "SPORESPORE_QSDK_R23D39_ATTEMPT_ROOT",
    "SPORESPORE_QSDK_R23D39_PYTHON",
    "SPORESPORE_QSDK_R23D39_POWERSHELL"
)

. (Join-Path $sdkRoot "content_addressed_artifact_store.ps1")
. (Join-Path $sdkRoot "locomotion_operation_lock.ps1")
. (Join-Path $sdkRoot "locomotion_full_conformance_attestation.ps1")
. (Join-Path $sdkRoot "locomotion_campaign_attestation_adoption.ps1")
. (Join-Path $sdkRoot "strict_json_array_document.ps1")

function Assert-R23D39([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "QSDK-R23D39: $Message" }
}

function Resolve-R23D39Application([string]$Command) {
    if ([IO.Path]::IsPathFullyQualified($Command)) {
        $resolved = [IO.Path]::GetFullPath($Command)
        Assert-R23D39 (Test-Path -LiteralPath $resolved -PathType Leaf) (
            "application is missing: $resolved"
        )
        return $resolved
    }
    $candidate = Get-Command $Command -CommandType Application -ErrorAction Stop |
        Select-Object -First 1
    return [IO.Path]::GetFullPath([string]$candidate.Source)
}

function Get-R23D39Sha256([string]$Path) {
    return "sha256:" + (
        Get-FileHash -LiteralPath $Path -Algorithm SHA256
    ).Hash.ToLowerInvariant()
}

function Invoke-R23D39Git([string[]]$Arguments) {
    $lines = @(& git -C $repoRoot @Arguments 2>&1)
    if ($LASTEXITCODE -ne 0) {
        throw "QSDK-R23D39 git $($Arguments -join ' ') failed: $($lines -join ' ')"
    }
    return ($lines -join "`n").Trim()
}

function Write-R23D39NewJson([string]$Path, $Value) {
    $resolved = [IO.Path]::GetFullPath($Path)
    if (Test-Path -LiteralPath $resolved) {
        throw "QSDK-R23D39 refuses to overwrite: $resolved"
    }
    [void][IO.Directory]::CreateDirectory((Split-Path -Parent $resolved))
    [IO.File]::WriteAllText(
        $resolved,
        ($Value | ConvertTo-Json -Depth 100) + "`n",
        [Text.UTF8Encoding]::new($false)
    )
}

function Get-R23D39MediaType([string]$Path) {
    switch ([IO.Path]::GetExtension($Path).ToLowerInvariant()) {
        ".json" { return "application/json" }
        ".ps1" { return "text/x-powershell" }
        ".py" { return "text/x-python" }
        ".rs" { return "text/x-rust" }
        ".toml" { return "application/toml" }
        ".dll" { return "application/vnd.microsoft.portable-executable" }
        ".exe" { return "application/vnd.microsoft.portable-executable" }
        default { return "application/octet-stream" }
    }
}

function Invoke-R23D39Process {
    param(
        [Parameter(Mandatory)][string]$FileName,
        [Parameter(Mandatory)][string[]]$Arguments,
        [Parameter(Mandatory)][string]$WorkingDirectory,
        [hashtable]$Environment = @{},
        [ValidateRange(1, 7200)][int]$TimeoutSeconds = 900
    )
    $start = [Diagnostics.ProcessStartInfo]::new()
    $start.FileName = $FileName
    $start.WorkingDirectory = $WorkingDirectory
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    foreach ($argument in $Arguments) { [void]$start.ArgumentList.Add($argument) }
    foreach ($name in $physicalEnvironmentNames) { [void]$start.Environment.Remove($name) }
    foreach ($entry in $Environment.GetEnumerator()) {
        $start.Environment[[string]$entry.Key] = [string]$entry.Value
    }
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $start
    $started = [DateTime]::UtcNow
    $timer = [Diagnostics.Stopwatch]::StartNew()
    [void]$process.Start()
    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()
    $timedOut = $false
    $nextHeartbeat = 30.0
    while (-not $process.WaitForExit(1000)) {
        if ($timer.Elapsed.TotalSeconds -ge $nextHeartbeat) {
            Write-Host (
                "QSDK_R23D39_PROGRESS process=$([IO.Path]::GetFileName($FileName)) " +
                "elapsed_seconds=$($timer.Elapsed.TotalSeconds.ToString('F1'))"
            )
            $nextHeartbeat += 30.0
        }
        if ($timer.Elapsed.TotalSeconds -ge $TimeoutSeconds) {
            $timedOut = $true
            try { $process.Kill($true) } catch { }
            [void]$process.WaitForExit(10000)
            break
        }
    }
    $timer.Stop()
    if (-not $timedOut) { $process.WaitForExit() }
    $result = [ordered]@{
        exit_code = if ($timedOut) { 124 } else { $process.ExitCode }
        timed_out = $timedOut
        duration_seconds = $timer.Elapsed.TotalSeconds
        stdout = $stdoutTask.GetAwaiter().GetResult()
        stderr = $stderrTask.GetAwaiter().GetResult()
        started_utc = $started.ToString("o")
        completed_utc = [DateTime]::UtcNow.ToString("o")
    }
    $process.Dispose()
    return $result
}

function Get-R23D39MarkerJson([string]$Text, [string]$Prefix) {
    $lines = @($Text -split "`r?`n" | Where-Object {
        ([string]$_).StartsWith($Prefix, [StringComparison]::Ordinal)
    })
    Assert-R23D39 ($lines.Count -eq 1) (
        "expected one '$Prefix' marker, observed $($lines.Count)"
    )
    return $lines[0].Substring($Prefix.Length) |
        ConvertFrom-Json -AsHashtable -Depth 100
}

function Get-R23D39PythonEnvironment([string]$CoreLibrary) {
    Assert-R23D39 (Test-Path -LiteralPath $mujocoSitePackages -PathType Container) (
        "locked MuJoCo site-packages root is missing: $mujocoSitePackages"
    )
    return @{
        "PYTHONPATH" = (@(
            (Join-Path $sdkRoot "python"),
            $mujocoRoot,
            $mujocoSitePackages,
            $turningRoot
        ) -join [IO.Path]::PathSeparator)
        "SPORESPORE_LOCOMOTION_LIBRARY" = [IO.Path]::GetFullPath($CoreLibrary)
    }
}

function Get-R23D39SourceBindings($Implementation) {
    $paths = [Collections.Generic.List[string]]::new()
    foreach ($path in @($Implementation.source_binding_policy.exact_paths)) {
        $paths.Add(([string]$path).Replace("\", "/"))
    }
    foreach ($prefix in @($Implementation.source_binding_policy.tracked_prefixes)) {
        $listed = Invoke-R23D39Git @("ls-files", "--", [string]$prefix)
        $expanded = @($listed -split "`n" |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
        Assert-R23D39 ($expanded.Count -gt 0) "empty source-binding prefix: $prefix"
        foreach ($path in $expanded) { $paths.Add($path.Replace("\", "/")) }
    }
    $duplicates = @($paths | Group-Object | Where-Object Count -gt 1)
    Assert-R23D39 ($duplicates.Count -eq 0) "duplicate source-binding paths"
    $bindings = [Collections.Generic.List[object]]::new()
    foreach ($relative in $paths) {
        $absolute = Join-Path $repoRoot $relative
        Assert-R23D39 (Test-Path -LiteralPath $absolute -PathType Leaf) (
            "source binding is missing: $relative"
        )
        $blob = Invoke-R23D39Git @("rev-parse", "HEAD:$relative")
        $checkout = Invoke-R23D39Git @("hash-object", "--no-filters", "--", $relative)
        Assert-R23D39 ($blob -ceq $checkout) (
            "checkout bytes differ from Git blob: $relative"
        )
        $bindings.Add([ordered]@{
            path = $relative
            raw_sha256 = Get-R23D39Sha256 $absolute
            git_blob_oid = $blob
            raw_checkout_equals_git_blob = $true
            media_type = Get-R23D39MediaType $relative
        })
    }
    return @($bindings)
}

function Invoke-R23D39ZeroWorld(
    [string]$PythonHost,
    [string]$CoreLibrary
) {
    Assert-R23D39 (Test-Path -LiteralPath $CoreLibrary -PathType Leaf) (
        "zero-world core library is missing: $CoreLibrary"
    )
    $implementation = Get-Content -Raw -LiteralPath $implementationPath |
        ConvertFrom-Json -AsHashtable -Depth 100
    $sourceBindings = Get-R23D39SourceBindings $implementation
    $environment = Get-R23D39PythonEnvironment $CoreLibrary
    $evaluator = Invoke-R23D39Process -FileName $PythonHost `
        -Arguments @($evaluatorPath, "preflight") -WorkingDirectory $repoRoot `
        -Environment $environment -TimeoutSeconds 180
    Assert-R23D39 ($evaluator.exit_code -eq 0 -and -not $evaluator.timed_out) (
        "evaluator preflight failed: $($evaluator.stderr) $($evaluator.stdout)"
    )
    $evaluatorReceipt = Get-R23D39MarkerJson $evaluator.stdout (
        "QSDK_R23D39_EVALUATOR_PREFLIGHT "
    )
    $workerReceipts = @(
        foreach ($declaredCell in $matrix) {
            $worker = Invoke-R23D39Process -FileName $PythonHost -Arguments @(
                "-m", "sporespore_mujoco_adapter.qsdk_r23d39_startup_ramp_turning",
                "preflight", "--stage", $stageId, "--onset", "onset_600",
                "--arm", [string]$declaredCell.arm_id
            ) -WorkingDirectory $repoRoot -Environment $environment -TimeoutSeconds 180
            Assert-R23D39 ($worker.exit_code -eq 0 -and -not $worker.timed_out) (
                "worker preflight failed for $($declaredCell.cell_id): " +
                "$($worker.stderr) $($worker.stdout)"
            )
            $workerReceipt = Get-R23D39MarkerJson $worker.stdout (
                "QSDK_R23D39_MUJOCO_PREFLIGHT "
            )
            Assert-R23D39 (
                [string]$workerReceipt.cell_id -ceq [string]$declaredCell.cell_id -and
                [string]$workerReceipt.arm_id -ceq [string]$declaredCell.arm_id -and
                [double]$workerReceipt.turn_heading_offset_rad -eq
                    [double]$declaredCell.turn_heading_offset_rad -and
                [string]$workerReceipt.controller_policy_id -ceq
                    "sporespore_balanced_wave_r23d29_two_swing_persistent_predictive_stability_guarded_steering_v1" -and
                [string]$workerReceipt.controller_memory_schema -ceq
                    "sporespore_balanced_wave_persistent_predictive_guard_memory_v1" -and
                [string]$workerReceipt.startup_ramp_id -ceq
                    "canonical_velocity_smoothstep_one_gait_cycle_v1" -and
                [int]$workerReceipt.startup_ramp_step_count -eq 360 -and
                [int]$workerReceipt.startup_ramp_canary.complete_ramp_scale_canary_count -eq 361 -and
                [int]$workerReceipt.startup_ramp_canary.active_ramp_scale_canary_count -eq 359 -and
                [bool]$workerReceipt.startup_ramp_canary.all_scales_finite_bounded_and_monotonic -and
                [bool]$workerReceipt.startup_ramp_canary.exact_zero_start -and
                [bool]$workerReceipt.startup_ramp_canary.exact_unity_at_last_ramp_step -and
                [bool]$workerReceipt.startup_ramp_canary.exact_unity_after_ramp -and
                [bool]$workerReceipt.startup_ramp_canary.residual_order_mutation_rejected -and
                [bool]$workerReceipt.turning_tested -and
                [int]$workerReceipt.world_build_count -eq 0 -and
                [int]$workerReceipt.model_construction_count -eq 0
            ) "worker preflight receipt is invalid: $($declaredCell.cell_id)"
            $workerReceipt
        }
    )
    Assert-R23D39 (
        [int]$evaluatorReceipt.declared_cell_count -eq 3 -and
        [int]$evaluatorReceipt.valid_trace_canary_count -eq 3 -and
        [int]$evaluatorReceipt.trace_mutation_rejection_count -eq 3 -and
        [int]$evaluatorReceipt.startup_ramp_mutation_rejection_count -eq 2 -and
        [int]$evaluatorReceipt.cycle_integrated_positive_canary_count -eq 1 -and
        [int]$evaluatorReceipt.cycle_integrated_negative_control_count -eq 1 -and
        [int]$evaluatorReceipt.world_build_count -eq 0 -and
        @($workerReceipts).Count -eq 3
    ) "joint zero-world preflight receipt is invalid"
    return [ordered]@{
        schema_version = "sporespore_qsdk_r23d39_zero_world_receipt_v1"
        campaign_id = $campaignId
        gate_id = $gateId
        evaluator = $evaluatorReceipt
        workers = @($workerReceipts)
        declared_cell_count = 3
        worker_preflight_count = 3
        source_binding_count = @($sourceBindings).Count
        source_bindings_checkout_bytes_equal_git_blobs = $true
        model_construction_count = 0
        world_attempt_count = 0
        world_build_count = 0
        physical_execution_authorized = $false
        physical_acceptance_authority = $false
    }
}

function Assert-R23D39FrozenBindings($Freeze) {
    foreach ($binding in @($Freeze.source_bindings)) {
        $path = Join-Path $repoRoot ([string]$binding.path)
        Assert-R23D39 (
            (Test-Path -LiteralPath $path -PathType Leaf) -and
            [string]$binding.raw_sha256 -ceq (Get-R23D39Sha256 $path) -and
            [string]$binding.git_blob_oid -ceq
                (Invoke-R23D39Git @("rev-parse", "HEAD:$([string]$binding.path)")) -and
            [string]$binding.git_blob_oid -ceq
                (Invoke-R23D39Git @("hash-object", "--no-filters", "--", [string]$binding.path))
        ) "frozen source binding changed: $([string]$binding.path)"
    }
    foreach ($runtime in @($Freeze.runtime_artifacts) + @($Freeze.external_runtime_bindings)) {
        $path = [IO.Path]::GetFullPath([string]$runtime.path)
        Assert-R23D39 (
            (Test-Path -LiteralPath $path -PathType Leaf) -and
            [string]$runtime.raw_sha256 -ceq (Get-R23D39Sha256 $path)
        ) "frozen runtime changed: $path"
    }
}

function Publish-R23D39Inputs(
    $SourceBindings,
    $RuntimeArtifacts,
    $ExternalRuntimeBindings,
    [string]$AdoptionPath
) {
    $source = @(
        foreach ($binding in @($SourceBindings)) {
            Publish-SporeSporeContentAddressedArtifact -RepoRoot $repoRoot `
                -ArtifactPath (Join-Path $repoRoot ([string]$binding.path)) `
                -MediaType ([string]$binding.media_type)
        }
    )
    $runtime = @(
        foreach ($binding in @($RuntimeArtifacts) + @($ExternalRuntimeBindings)) {
            Publish-SporeSporeContentAddressedArtifact -RepoRoot $repoRoot `
                -ArtifactPath ([string]$binding.path) `
                -MediaType ([string]$binding.media_type)
        }
    )
    $adoption = Publish-SporeSporeContentAddressedArtifact -RepoRoot $repoRoot `
        -ArtifactPath $AdoptionPath -MediaType "application/json"
    return [ordered]@{
        source_bindings = $source
        runtime_bindings = $runtime
        campaign_attestation_adoption = $adoption
        physical_acceptance_authority = $false
    }
}

function Get-R23D39TerminalFailure(
    [string]$SourceCommit,
    [string]$Code,
    [string]$CellId,
    [string]$ArmId,
    [double]$TurnHeadingOffsetRad,
    [int]$WorldAttemptCount = 0,
    [int]$WorldBuildCount = 0
) {
    return [ordered]@{
        schema_version = "sporespore_qsdk_r23d39_worker_failure_v1"
        campaign_id = $campaignId
        gate_id = $gateId
        stage_id = $stageId
        cell_id = $CellId
        engine_id = "mujoco"
        onset_id = "onset_600"
        turn_start_semantic_step = 600
        arm_id = $ArmId
        turn_heading_offset_rad = $TurnHeadingOffsetRad
        source_commit = $SourceCommit
        failure_stage = "supervisor_transport"
        failure_code = $Code
        world_attempt_count = $WorldAttemptCount
        world_build_count = $WorldBuildCount
        claims = [ordered]@{
            finite_mujoco_r23d29_seed_21507_startup_ramp_walking = $false
            finite_mujoco_r23d29_seed_21507_startup_ramp_turning = $false
            mujoco_r23d29_walking_restored = $false
            mujoco_r23d29_turning = $false
            finite_three_engine_turning = $false
            portable_basic_turning = $false
            cross_engine_equivalence = $false
            population_robustness = $false
            prone_to_standing = $false
            release_authorized = $false
            physical_acceptance_authority = $false
        }
    }
}

function Invoke-R23D39Cell {
    param(
        [Parameter(Mandatory)][string]$SourceCommit,
        [Parameter(Mandatory)][string]$FreezePayload,
        [Parameter(Mandatory)][string]$AttemptPayload,
        [Parameter(Mandatory)][string]$Token,
        [Parameter(Mandatory)][string]$AttemptRoot,
        [Parameter(Mandatory)][string]$CellRoot,
        [Parameter(Mandatory)][string]$CellId,
        [Parameter(Mandatory)][string]$ArmId,
        [Parameter(Mandatory)][double]$TurnHeadingOffsetRad,
        [Parameter(Mandatory)][string]$PythonHost,
        [Parameter(Mandatory)][string]$PowerShellHost
    )
    [void][IO.Directory]::CreateDirectory($CellRoot)
    $environment = Get-R23D39PythonEnvironment $coreReleasePath
    $environment["SPORESPORE_QSDK_R23D39_FREEZE"] = $FreezePayload
    $environment["SPORESPORE_QSDK_R23D39_ATTEMPT"] = $AttemptPayload
    $environment["SPORESPORE_QSDK_R23D39_TOKEN"] = $Token
    $environment["SPORESPORE_QSDK_R23D39_STAGE"] = $stageId
    $environment["SPORESPORE_QSDK_R23D39_CELL"] = $CellId
    $environment["SPORESPORE_QSDK_R23D39_ENGINE"] = "mujoco"
    $environment["SPORESPORE_QSDK_R23D39_ATTEMPT_ROOT"] = $AttemptRoot
    $environment["SPORESPORE_QSDK_R23D39_PYTHON"] = $PythonHost
    $environment["SPORESPORE_QSDK_R23D39_POWERSHELL"] = $PowerShellHost
    $process = Invoke-R23D39Process -FileName $PythonHost -Arguments @(
        "-m", "sporespore_mujoco_adapter.qsdk_r23d39_startup_ramp_turning",
        "physical", "--stage", $stageId, "--onset", "onset_600", "--arm", $ArmId,
        "--source-commit", $SourceCommit
    ) -WorkingDirectory $repoRoot -Environment $environment `
        -TimeoutSeconds $CellTimeoutSeconds
    $stdoutPath = Join-Path $CellRoot "stdout.txt"
    $stderrPath = Join-Path $CellRoot "stderr.txt"
    [IO.File]::WriteAllText(
        $stdoutPath, [string]$process.stdout, [Text.UTF8Encoding]::new($false)
    )
    [IO.File]::WriteAllText(
        $stderrPath, [string]$process.stderr, [Text.UTF8Encoding]::new($false)
    )
    $stdoutCas = Publish-SporeSporeContentAddressedArtifact -RepoRoot $repoRoot `
        -ArtifactPath $stdoutPath -MediaType "text/plain"
    $stderrCas = Publish-SporeSporeContentAddressedArtifact -RepoRoot $repoRoot `
        -ArtifactPath $stderrPath -MediaType "text/plain"
    try {
        if ([bool]$process.timed_out) { throw "R23D39_CELL_TIMEOUT" }
        $terminal = Get-R23D39MarkerJson ([string]$process.stdout) (
            "QSDK_R23D39_MUJOCO_TERMINAL "
        )
        if ([string]$terminal.cell_id -cne $CellId) {
            throw "R23D39_CELL_MARKER_ID"
        }
    } catch {
        $terminal = Get-R23D39TerminalFailure -SourceCommit $SourceCommit `
            -Code ("R23D39_SUPERVISOR_TERMINAL_CAPTURE:" + $_.Exception.Message) `
            -CellId $CellId -ArmId $ArmId `
            -TurnHeadingOffsetRad $TurnHeadingOffsetRad
    }
    $terminalPath = Join-Path $CellRoot "terminal.json"
    Write-R23D39NewJson $terminalPath $terminal
    $terminalCas = Publish-SporeSporeContentAddressedArtifact -RepoRoot $repoRoot `
        -ArtifactPath $terminalPath -MediaType "application/json"
    return [ordered]@{
        cell_id = $CellId
        engine_id = "mujoco"
        arm_id = $ArmId
        turn_heading_offset_rad = $TurnHeadingOffsetRad
        process = [ordered]@{
            exit_code = [int]$process.exit_code
            timed_out = [bool]$process.timed_out
            duration_seconds = [double]$process.duration_seconds
            started_utc = [string]$process.started_utc
            completed_utc = [string]$process.completed_utc
            stdout_cas = $stdoutCas
            stderr_cas = $stderrCas
        }
        terminal_entry_cas = $terminalCas
        terminal_schema = [string]$terminal.schema_version
        physical_acceptance_authority = $false
    }
}

Assert-R23D39 ($PreflightOnly -xor $RunPhysical) (
    "select exactly one of -PreflightOnly or -RunPhysical"
)
$pythonHost = Resolve-R23D39Application $Python
$powerShellHost = Resolve-R23D39Application $PowerShell

if ($PreflightOnly) {
    Assert-R23D39 ([string]::IsNullOrWhiteSpace($CampaignAttestationAdoption)) (
        "preflight does not accept physical authorization"
    )
    Assert-R23D39 ([string]::IsNullOrWhiteSpace($OutputRoot)) (
        "preflight does not accept a physical output root"
    )
    $receipt = Invoke-R23D39ZeroWorld $pythonHost $coreDebugPath
    Write-Host (
        "QSDK_R23D39_ZERO_WORLD_PASS " +
        ($receipt | ConvertTo-Json -Depth 100 -Compress)
    )
    exit 0
}

Assert-R23D39 (Test-Path -LiteralPath $Godot -PathType Leaf) (
    "Godot host required by the LCA1 adoption verifier is missing"
)
Assert-R23D39 (-not [string]::IsNullOrWhiteSpace($CampaignAttestationAdoption)) (
    "physical execution requires a campaign-attestation adoption"
)
foreach ($path in @($preregistrationPath, $implementationPath, $manifestPath)) {
    Assert-R23D39 (Test-Path -LiteralPath $path -PathType Leaf) "missing contract: $path"
}
$source = Get-SporeSporeAttestationSourceIdentity -RepoRoot $repoRoot `
    -RequireCleanPushedLive
$adoption = Test-SporeSporeCampaignAttestationAdoptionFile -RepoRoot $repoRoot `
    -ManifestPath $manifestPath `
    -AdoptionPath ([IO.Path]::GetFullPath($CampaignAttestationAdoption)) `
    -Godot ([IO.Path]::GetFullPath($Godot)) -Python $pythonHost `
    -ExpectedCampaignId $campaignId
Assert-R23D39 ([bool]$adoption.ok) (
    "campaign-attestation adoption failed: $(@($adoption.failure_codes) -join ',')"
)
Assert-R23D39 (
    [string]$adoption.source.commit -ceq [string]$source.commit -and
    [string]$adoption.source.tree_git_oid -ceq [string]$source.tree_git_oid
) "adoption source differs from the live source"

$lock = Enter-SporeSporeLocomotionOperationLock -Role physical
Assert-R23D39 ([bool]$lock.acquired) "global locomotion operation lock is held"
$attemptConsumed = $false
$completionPath = ""
try {
    $evidenceRoot = Get-SporeSporeArtifactEvidenceRoot -RepoRoot $repoRoot
    $prior = @(Get-ChildItem -LiteralPath $evidenceRoot -Directory | Where-Object {
        $_.Name -like "qsdk-r23d39-*" -and (
            (Test-Path -LiteralPath (Join-Path $_.FullName "attempt-authorization.json")) -or
            (Test-Path -LiteralPath (Join-Path $_.FullName "completion.json"))
        )
    })
    Assert-R23D39 ($prior.Count -eq 0) "one-shot R23D39 identity already exists"
    $resolvedOutput = if ([string]::IsNullOrWhiteSpace($OutputRoot)) {
        Join-Path $evidenceRoot (
            "qsdk-r23d39-" + [DateTime]::UtcNow.ToString("yyyyMMddTHHmmssZ")
        )
    } else { [IO.Path]::GetFullPath($OutputRoot) }
    $prefix = $evidenceRoot.TrimEnd("\", "/") + [IO.Path]::DirectorySeparatorChar
    Assert-R23D39 (
        $resolvedOutput.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase) -and
        -not (Test-Path -LiteralPath $resolvedOutput)
    ) "output must be a new directory under $evidenceRoot"
    [void][IO.Directory]::CreateDirectory($resolvedOutput)
    $completionPath = Join-Path $resolvedOutput "completion.json"

    . $runtimeHelperPath
    $coreBuild = Invoke-SporeSporeR23D3PinnedCargo -RepoRoot $repoRoot `
        -SourceCommit ([string]$source.commit) -TargetRoot (Join-Path $sdkRoot "target") `
        -CargoArguments @(
            "build", "--quiet", "--release", "--locked", "--offline",
            "--manifest-path", (Join-Path $sdkRoot "Cargo.toml"),
            "--package", "sporespore-locomotion-core"
        )
    Assert-R23D39 (Test-Path -LiteralPath $coreReleasePath -PathType Leaf) (
        "reproducible core runtime is missing"
    )
    $zeroWorld = Invoke-R23D39ZeroWorld $pythonHost $coreReleasePath
    $sourceAfter = Get-SporeSporeAttestationSourceIdentity -RepoRoot $repoRoot `
        -RequireCleanPushedLive
    Assert-R23D39 (
        [string]$sourceAfter.commit -ceq [string]$source.commit -and
        [string]$sourceAfter.tree_git_oid -ceq [string]$source.tree_git_oid
    ) "source changed during runtime materialization or zero-world gate"

    $implementation = Get-Content -Raw -LiteralPath $implementationPath |
        ConvertFrom-Json -AsHashtable -Depth 100
    $sourceBindings = Get-R23D39SourceBindings $implementation
    $runtimeArtifacts = @(
        [ordered]@{
            name = "locomotion_core_release"
            path = $coreReleasePath
            raw_sha256 = Get-R23D39Sha256 $coreReleasePath
            media_type = "application/vnd.microsoft.portable-executable"
            build_receipt = $coreBuild
        }
    )
    $externalRuntimeBindings = @(
        [ordered]@{
            name = "mujoco_python_host"
            path = $pythonHost
            raw_sha256 = Get-R23D39Sha256 $pythonHost
            media_type = "application/vnd.microsoft.portable-executable"
        },
        [ordered]@{
            name = "powershell_trace_host"
            path = $powerShellHost
            raw_sha256 = Get-R23D39Sha256 $powerShellHost
            media_type = "application/vnd.microsoft.portable-executable"
        },
        [ordered]@{
            name = "lca1_godot_host_not_used_for_physics"
            path = [IO.Path]::GetFullPath($Godot)
            raw_sha256 = Get-R23D39Sha256 ([IO.Path]::GetFullPath($Godot))
            media_type = "application/vnd.microsoft.portable-executable"
        }
    )
    $inputCas = Publish-R23D39Inputs $sourceBindings $runtimeArtifacts `
        $externalRuntimeBindings ([IO.Path]::GetFullPath($CampaignAttestationAdoption))
    $freeze = [ordered]@{
        schema_version = "sporespore_qsdk_r23d39_physical_freeze_v1"
        status = "frozen_supervisor_only_physical_authorized"
        campaign_id = $campaignId
        gate_id = $gateId
        preregistration_raw_sha256 = Get-R23D39Sha256 $preregistrationPath
        implementation_contract_raw_sha256 = Get-R23D39Sha256 $implementationPath
        source_commit = [string]$source.commit
        source_tree_git_oid = [string]$source.tree_git_oid
        origin_main_commit = [string]$source.origin_main
        live_github_main_commit = [string]$source.live_github_main
        source_bindings = $sourceBindings
        runtime_artifacts = $runtimeArtifacts
        external_runtime_bindings = $externalRuntimeBindings
        content_addressed_inputs = $inputCas
        campaign_attestation_adoption_sha256 = [string]$adoption.sha256
        complete_zero_world_gate_passed = $true
        zero_world_receipt = $zeroWorld
        declared_world_count = 3
        ordered_matrix_cell_ids = @($cellIds)
        serial_execution_required = $true
        all_cells_run_regardless_of_intermediate_outcome = $true
        terminal_restoration_or_taper_invoked = $false
        source_checkout_bytes_equal_git_blobs = $true
        reproducible_runtime_materialization_passed = $true
        physical_execution_authorized = $true
        physical_acceptance_authority = $false
    }
    $freezePath = Join-Path $resolvedOutput "physical-freeze.json"
    Write-R23D39NewJson $freezePath $freeze
    $freezeCas = Publish-SporeSporeContentAddressedArtifact -RepoRoot $repoRoot `
        -ArtifactPath $freezePath -MediaType "application/json"
    Assert-R23D39FrozenBindings $freeze

    $attemptId = [guid]::NewGuid().ToString("N")
    $token = [guid]::NewGuid().ToString("N")
    $attempt = [ordered]@{
        schema_version = "sporespore_qsdk_r23d39_attempt_v1"
        campaign_id = $campaignId
        gate_id = $gateId
        attempt_id = $attemptId
        authorization_token = $token
        source_commit = [string]$source.commit
        freeze_raw_sha256 = [string]$freezeCas.sha256
        attempt_root = $resolvedOutput
        ordered_matrix_cell_ids = @($cellIds)
        physical_execution_authorized = $true
        single_use_supervisor_authorization = $true
        source_worktree_clean = $true
        source_matches_live_github_main = $true
        operation_lock_held = $true
        campaign_attestation_adoption_valid = $true
        content_addressed_inputs_retained = $true
        content_addressed_inputs = $inputCas
        one_shot_attempt_unconsumed = $true
        all_cells_run_regardless_of_intermediate_outcome = $true
        physical_acceptance_authority = $false
    }
    $attemptPath = Join-Path $resolvedOutput "attempt-authorization.json"
    Write-R23D39NewJson $attemptPath $attempt
    $attemptCas = Publish-SporeSporeContentAddressedArtifact -RepoRoot $repoRoot `
        -ArtifactPath $attemptPath -MediaType "application/json"
    $attemptConsumed = $true

    Assert-R23D39FrozenBindings $freeze
    $cells = @(
        foreach ($declaredCell in $matrix) {
            $cellRoot = Join-Path $resolvedOutput (
                "cells\" + [string]$declaredCell.cell_id
            )
            Invoke-R23D39Cell -SourceCommit ([string]$source.commit) `
                -FreezePayload ([string]$freezeCas.payload_path) `
                -AttemptPayload ([string]$attemptCas.payload_path) -Token $token `
                -AttemptRoot $resolvedOutput -CellRoot $cellRoot `
                -CellId ([string]$declaredCell.cell_id) `
                -ArmId ([string]$declaredCell.arm_id) `
                -TurnHeadingOffsetRad ([double]$declaredCell.turn_heading_offset_rad) `
                -PythonHost $pythonHost -PowerShellHost $powerShellHost
        }
    )
    $terminalPaths = @(
        $cells | ForEach-Object { [string]$_.terminal_entry_cas.payload_path }
    )
    $manifestOutput = Join-Path $resolvedOutput "terminal-paths.json"
    Write-SporeSporeNewJsonArrayDocument -Path $manifestOutput `
        -Items $terminalPaths | Out-Null
    $manifestCas = Publish-SporeSporeContentAddressedArtifact -RepoRoot $repoRoot `
        -ArtifactPath $manifestOutput -MediaType "application/json"
    $evaluationProcess = Invoke-R23D39Process -FileName $pythonHost -Arguments @(
        $evaluatorPath, "evaluate-complete", "--manifest",
        [string]$manifestCas.payload_path, "--expected-source-commit",
        [string]$source.commit
    ) -WorkingDirectory $repoRoot `
        -Environment (Get-R23D39PythonEnvironment $coreReleasePath) `
        -TimeoutSeconds 300
    Assert-R23D39 (
        $evaluationProcess.exit_code -eq 0 -and -not $evaluationProcess.timed_out
    ) "complete evaluator failed: $($evaluationProcess.stderr) $($evaluationProcess.stdout)"
    $evaluation = Get-R23D39MarkerJson $evaluationProcess.stdout (
        "QSDK_R23D39_COMPLETE_EVALUATION "
    )
    $evaluationPath = Join-Path $resolvedOutput "complete-evaluation.json"
    Write-R23D39NewJson $evaluationPath $evaluation
    $evaluationCas = Publish-SporeSporeContentAddressedArtifact -RepoRoot $repoRoot `
        -ArtifactPath $evaluationPath -MediaType "application/json"
    $report = [ordered]@{
        schema_version = "sporespore_qsdk_r23d39_campaign_report_v1"
        campaign_id = $campaignId
        gate_id = $gateId
        source = $source
        attempt_id = $attemptId
        freeze_cas = $freezeCas
        attempt_authorization_cas = $attemptCas
        terminal_manifest_cas = $manifestCas
        complete_evaluation_cas = $evaluationCas
        ordered_cells = @($cells)
        complete_evaluation = $evaluation
        result_classification = [string]$evaluation.classification
        all_declared_cells_executed_or_retained_as_failures = $true
        outcome_exposed_development_screen = $true
        fresh_held_out_condition_consumed = $false
        terminal_restoration_or_taper_invoked = $false
        turning_tested = $true
        claims = $evaluation.claims
    }
    $reportPath = Join-Path $resolvedOutput "report.json"
    Write-R23D39NewJson $reportPath $report
    $reportCas = Publish-SporeSporeContentAddressedArtifact -RepoRoot $repoRoot `
        -ArtifactPath $reportPath -MediaType "application/json"
    $worldCount = [int](
        @($evaluation.cell_evaluations) |
            Measure-Object -Property world_build_count -Sum
    ).Sum
    $completion = [ordered]@{
        schema_version = "sporespore_qsdk_r23d39_completion_v1"
        campaign_id = $campaignId
        gate_id = $gateId
        attempt_id = $attemptId
        status = [string]$evaluation.classification
        source_commit = [string]$source.commit
        cell_count = 3
        world_count = $worldCount
        report_cas = $reportCas
        complete_evaluation_cas = $evaluationCas
        one_shot_attempt_consumed = $true
        replacement_or_selective_rerun_permitted = $false
        completed_utc = [DateTime]::UtcNow.ToString("o")
        physical_acceptance_authority = $false
    }
    Write-R23D39NewJson $completionPath $completion
    $completionCas = Publish-SporeSporeContentAddressedArtifact -RepoRoot $repoRoot `
        -ArtifactPath $completionPath -MediaType "application/json"
    Write-Host (
        "QSDK_R23D39_PHYSICAL_COMPLETE classification=$($evaluation.classification) " +
        "cells=3 report_sha256=$($reportCas.sha256) " +
        "completion_sha256=$($completionCas.sha256) output=$resolvedOutput"
    )
    if ([string]$evaluation.classification -ceq
        "invalid_complete_mujoco_startup_ramp_turning_development") {
        throw "QSDK-R23D39 retained an invalid complete first attempt: $resolvedOutput"
    }
} catch {
    if ($attemptConsumed -and -not [string]::IsNullOrWhiteSpace($completionPath) -and
        -not (Test-Path -LiteralPath $completionPath)) {
        $emergency = [ordered]@{
            schema_version = "sporespore_qsdk_r23d39_completion_v1"
            campaign_id = $campaignId
            gate_id = $gateId
            status = "invalid_or_incomplete_first_attempt"
            source_commit = [string]$source.commit
            one_shot_attempt_consumed = $true
            replacement_or_selective_rerun_permitted = $false
            failure_message = [string]$_.Exception.Message
            completed_utc = [DateTime]::UtcNow.ToString("o")
            physical_acceptance_authority = $false
        }
        Write-R23D39NewJson $completionPath $emergency
        [void](Publish-SporeSporeContentAddressedArtifact -RepoRoot $repoRoot `
            -ArtifactPath $completionPath -MediaType "application/json")
    }
    throw
} finally {
    Exit-SporeSporeLocomotionOperationLock $lock
}
