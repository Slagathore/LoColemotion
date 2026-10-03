#requires -Version 7.0

[CmdletBinding()]
param(
    [switch]$PreflightOnly,
    [switch]$RunPhysical,
    [string]$OutputRoot = "",
    [string]$Python = "",
    [string]$PowerShell = "pwsh",
    [ValidateRange(60, 1800)][int]$PhysicalTimeoutSeconds = 600
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$sdkRoot = [IO.Path]::GetFullPath($PSScriptRoot)
$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $sdkRoot))
$turningRoot = Join-Path $sdkRoot "turning"
$mujocoRoot = Join-Path $sdkRoot "adapters\mujoco"
$defaultPython = Join-Path $mujocoRoot ".venv\Scripts\python.exe"
$pythonHost = if ([string]::IsNullOrWhiteSpace($Python)) {
    $defaultPython
} else {
    [IO.Path]::GetFullPath($Python)
}
$workerModule = "sporespore_mujoco_adapter.qsdk_r23d72_preturn_startup_development"
$workerPath = Join-Path $mujocoRoot (
    "sporespore_mujoco_adapter\qsdk_r23d72_preturn_startup_development.py"
)
$contractPath = Join-Path $turningRoot (
    "r23d72_mujoco_selected_profile_preturn_startup_development_v1.json"
)
$corePath = Join-Path $sdkRoot "target\release\sporespore_locomotion_core.dll"
$runtimeHelperPath = Join-Path $sdkRoot "r23d3_reproducible_runtime_materialization.ps1"
$lockHelperPath = Join-Path $sdkRoot "locomotion_operation_lock.ps1"

$campaignId = "QSDK-R23D72-MUJOCO-SELECTED-PROFILE-PRETURN-STARTUP-DEVELOPMENT"
$gateId = "QSDK-R23D72"
$stageId = "mujoco_selected_profile_preturn_startup_development"
$cellId = "r23d72__mujoco__s23191__reference_zero__unconditional_startup_ramp"
$engineId = "mujoco"
$expectedRemote = "https://github.com/Slagathore/sporespore.git"
$evidenceRoot = [IO.Path]::GetFullPath(
    (Join-Path (Split-Path -Parent $repoRoot) "SporeSpore_Evidence")
)
$pythonPath = @(
    $mujocoRoot,
    (Join-Path $sdkRoot "python"),
    $turningRoot
) -join [IO.Path]::PathSeparator

$sourceRelativePaths = @(
    "sdk/adapters/mujoco/sporespore_mujoco_adapter/qsdk_r23d72_preturn_startup_development.py",
    "sdk/turning/r23d72_mujoco_selected_profile_preturn_startup_development_v1.json",
    "sdk/adapters/mujoco/sporespore_mujoco_adapter/qsdk_r23d3_phase_balanced.py",
    "sdk/turning/r23d38_mujoco_startup_ramp_stabilization.py",
    "sdk/adapters/mujoco/sporespore_mujoco_adapter/qsdk_r23d65_selected_profile_turning.py",
    "sdk/adapters/mujoco/sporespore_mujoco_adapter/qsdk_r23d65_public_profile_route.py",
    "sdk/run_qsdk_r23d72_supervisor.ps1"
)

function Assert-R23D72([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "[turning/mujoco] R23D72 supervisor: $Message" }
}

function Get-R23D72Sha256([string]$Path) {
    return "sha256:" + (
        Get-FileHash -LiteralPath $Path -Algorithm SHA256
    ).Hash.ToLowerInvariant()
}

function Write-R23D72NewJson([string]$Path, [object]$Value) {
    $json = $Value | ConvertTo-Json -Depth 100
    $encoding = [Text.UTF8Encoding]::new($false)
    $stream = [IO.File]::Open($Path, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write)
    try {
        $bytes = $encoding.GetBytes($json + "`n")
        $stream.Write($bytes, 0, $bytes.Length)
    } finally {
        $stream.Dispose()
    }
}

function Write-R23D72Text([string]$Path, [string]$Value) {
    $encoding = [Text.UTF8Encoding]::new($false)
    $stream = [IO.File]::Open($Path, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write)
    try {
        $bytes = $encoding.GetBytes($Value)
        $stream.Write($bytes, 0, $bytes.Length)
    } finally {
        $stream.Dispose()
    }
}

function Invoke-R23D72Git([string[]]$Arguments) {
    $lines = @(& git -C $repoRoot @Arguments 2>&1)
    if ($LASTEXITCODE -ne 0) {
        throw "[turning/mujoco] git $($Arguments -join ' ') failed: $($lines -join ' ')"
    }
    return ($lines -join "`n").Trim()
}

function Get-R23D72SourceIdentity([switch]$RequireCleanPushedLive) {
    $top = [IO.Path]::GetFullPath((Invoke-R23D72Git @("rev-parse", "--show-toplevel")))
    $remote = Invoke-R23D72Git @("remote", "get-url", "origin")
    $branch = Invoke-R23D72Git @("branch", "--show-current")
    $head = Invoke-R23D72Git @("rev-parse", "HEAD")
    $origin = Invoke-R23D72Git @("rev-parse", "origin/main")
    $status = Invoke-R23D72Git @("status", "--porcelain=v1", "--untracked-files=all")
    $remoteLines = @(& git -C $repoRoot ls-remote origin refs/heads/main 2>&1)
    Assert-R23D72 ($LASTEXITCODE -eq 0) "live remote main could not be read"
    $remoteMatches = @(
        $remoteLines | Where-Object { $_ -match '^([0-9a-f]{40})\s+refs/heads/main$' }
    )
    Assert-R23D72 ($remoteMatches.Count -eq 1) "live remote main was not unique"
    $live = ([regex]::Match([string]$remoteMatches[0], '^[0-9a-f]{40}')).Value
    Assert-R23D72 ($top -ceq $repoRoot) "repository root mismatch: $top"
    Assert-R23D72 ($remote -ceq $expectedRemote) "origin mismatch: $remote"
    Assert-R23D72 ($branch -ceq "main") "branch is not main: $branch"
    if ($RequireCleanPushedLive) {
        Assert-R23D72 ([string]::IsNullOrEmpty($status)) "source worktree is not clean"
        Assert-R23D72 (
            $head -ceq $origin -and $head -ceq $live
        ) "HEAD, origin/main, and live GitHub main are not equal"
    }
    return [ordered]@{
        root = $top
        remote = $remote
        branch = $branch
        commit = $head
        origin_main_commit = $origin
        live_github_main_commit = $live
        source_worktree_clean = [string]::IsNullOrEmpty($status)
    }
}

function Invoke-R23D72Process {
    param(
        [Parameter(Mandatory)][string]$FileName,
        [Parameter(Mandatory)][string[]]$Arguments,
        [Parameter(Mandatory)][hashtable]$Environment,
        [int]$TimeoutSeconds = 120
    )
    $start = [Diagnostics.ProcessStartInfo]::new()
    $start.FileName = $FileName
    $start.WorkingDirectory = $repoRoot
    $start.UseShellExecute = $false
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    $start.CreateNoWindow = $true
    foreach ($argument in $Arguments) { [void]$start.ArgumentList.Add($argument) }
    foreach ($entry in $Environment.GetEnumerator()) {
        $start.Environment[[string]$entry.Key] = [string]$entry.Value
    }
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $start
    Assert-R23D72 ($process.Start()) "could not start $FileName"
    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()
    if (-not $process.WaitForExit($TimeoutSeconds * 1000)) {
        try { $process.Kill($true) } catch { }
        [void]$process.WaitForExit(10000)
        throw "[turning/mujoco] process timed out after ${TimeoutSeconds}s: $FileName"
    }
    $stdout = $stdoutTask.GetAwaiter().GetResult()
    $stderr = $stderrTask.GetAwaiter().GetResult()
    return [ordered]@{
        exit_code = $process.ExitCode
        stdout = $stdout
        stderr = $stderr
    }
}

function Get-R23D72Marker([object]$Process, [string]$Marker) {
    $matches = @(
        ([string]$Process.stdout -split "`r?`n") |
            Where-Object { $_.StartsWith($Marker, [StringComparison]::Ordinal) }
    )
    Assert-R23D72 ($matches.Count -eq 1) "expected one $Marker marker"
    return ($matches[0].Substring($Marker.Length) | ConvertFrom-Json -Depth 100)
}

function Invoke-R23D72ZeroWorld {
    $environment = @{
        PYTHONPATH = $pythonPath
        SPORESPORE_LOCOMOTION_LIBRARY = $corePath
    }
    $process = Invoke-R23D72Process -FileName $pythonHost -Arguments @(
        "-m", $workerModule, "preflight"
    ) -Environment $environment -TimeoutSeconds 120
    Assert-R23D72 ($process.exit_code -eq 0) (
        "zero-world worker failed: $([string]$process.stderr)"
    )
    $receipt = Get-R23D72Marker $process "QSDK_R23D72_MUJOCO_PREFLIGHT "
    Assert-R23D72 (
        [bool]$receipt.ok -and
        [string]$receipt.question_class -ceq "development" -and
        [bool]$receipt.outcome_exposed_fixture -and
        [int]$receipt.fixed_controller_horizon_step_count -eq 601 -and
        [int]$receipt.commanded_turn_step_count -eq 0 -and
        -not [bool]$receipt.turning_tested -and
        [int]$receipt.negative_control_class_count -eq 5 -and
        [bool]$receipt.returned_before_mjmodel -and
        [int]$receipt.model_construction_count -eq 0 -and
        [int]$receipt.world_attempt_count -eq 0 -and
        [int]$receipt.world_build_count -eq 0 -and
        [int]$receipt.solver_step_count -eq 0
    ) "zero-world receipt was not exact"
    return [ordered]@{
        receipt = $receipt
        stdout = [string]$process.stdout
        stderr = [string]$process.stderr
    }
}

Assert-R23D72 ($PreflightOnly -xor $RunPhysical) (
    "select exactly one of -PreflightOnly or -RunPhysical"
)
Assert-R23D72 (Test-Path -LiteralPath $pythonHost -PathType Leaf) (
    "MuJoCo Python host is missing: $pythonHost"
)
Assert-R23D72 (Test-Path -LiteralPath $contractPath -PathType Leaf) (
    "prospective contract is missing"
)
Assert-R23D72 (Test-Path -LiteralPath $workerPath -PathType Leaf) (
    "MuJoCo worker is missing"
)

. $lockHelperPath
$operationRole = if ($RunPhysical) { "physical" } else { "conformance" }
$lock = Enter-SporeSporeLocomotionOperationLock -Role $operationRole `
    -TimeoutMilliseconds 0
Assert-R23D72 ([bool]$lock.acquired) "global locomotion operation lock is busy"

try {
    if ($PreflightOnly) {
        Assert-R23D72 (Test-Path -LiteralPath $corePath -PathType Leaf) (
            "release locomotion core is missing"
        )
        $zeroWorld = Invoke-R23D72ZeroWorld
        Write-Output (
            "[turning/mujoco] R23D72 zero-world PASS: " +
            "1 selected-profile route, 4 synthetic ramp steps, " +
            "5/5 negative-control classes, 0 models/worlds/solver steps"
        )
        return
    }

    $source = Get-R23D72SourceIdentity -RequireCleanPushedLive
    Assert-R23D72 ($source.commit -match '^[0-9a-f]{40}$') "source commit invalid"
    Assert-R23D72 (Test-Path -LiteralPath $evidenceRoot -PathType Container) (
        "durable evidence root is missing: $evidenceRoot"
    )

    . $runtimeHelperPath
    $build = Invoke-SporeSporeR23D3PinnedCargo -RepoRoot $repoRoot `
        -SourceCommit ([string]$source.commit) -TargetRoot (Join-Path $sdkRoot "target") `
        -CargoArguments @(
            "build", "--quiet", "--release", "--locked", "--offline",
            "--manifest-path", (Join-Path $sdkRoot "Cargo.toml"),
            "--package", "sporespore-locomotion-core"
        )
    Assert-R23D72 (Test-Path -LiteralPath $corePath -PathType Leaf) (
        "reproducible release locomotion core is missing"
    )
    $zeroWorld = Invoke-R23D72ZeroWorld
    $sourceAfter = Get-R23D72SourceIdentity -RequireCleanPushedLive
    Assert-R23D72 (
        [string]$sourceAfter.commit -ceq [string]$source.commit
    ) "source drifted during runtime build or zero-world qualification"

    $resolvedOutput = if ([string]::IsNullOrWhiteSpace($OutputRoot)) {
        Join-Path $evidenceRoot (
            "qsdk-r23d72-preturn-" +
            [DateTime]::UtcNow.ToString("yyyyMMddTHHmmssZ") + "-" +
            ([string]$source.commit).Substring(0, 8) + "-" +
            ([guid]::NewGuid().ToString("N").Substring(0, 8))
        )
    } else {
        [IO.Path]::GetFullPath($OutputRoot)
    }
    $prefix = $evidenceRoot.TrimEnd("\", "/") + [IO.Path]::DirectorySeparatorChar
    Assert-R23D72 (
        $resolvedOutput.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase) -and
        -not (Test-Path -LiteralPath $resolvedOutput)
    ) "output must be a new directory under the durable evidence root"
    [void][IO.Directory]::CreateDirectory($resolvedOutput)

    $zeroWorldPath = Join-Path $resolvedOutput "zero-world-receipt.json"
    Write-R23D72NewJson $zeroWorldPath $zeroWorld.receipt
    Write-R23D72Text (Join-Path $resolvedOutput "zero-world.stdout.log") $zeroWorld.stdout
    Write-R23D72Text (Join-Path $resolvedOutput "zero-world.stderr.log") $zeroWorld.stderr

    $sourceBindings = @(
        foreach ($relative in $sourceRelativePaths) {
            $absolute = Join-Path $repoRoot $relative
            Assert-R23D72 (Test-Path -LiteralPath $absolute -PathType Leaf) (
                "required source path missing: $relative"
            )
            $tracked = Invoke-R23D72Git @("ls-files", "--error-unmatch", "--", $relative)
            Assert-R23D72 ($tracked -ceq $relative) "source path is not tracked: $relative"
            [ordered]@{
                path = $relative.Replace("\", "/")
                raw_sha256 = Get-R23D72Sha256 $absolute
            }
        }
    )
    $freeze = [ordered]@{
        schema_version = "sporespore_qsdk_r23d72_mujoco_preturn_physical_freeze_v1"
        campaign_id = $campaignId
        gate_id = $gateId
        status = "frozen_development_physical_authorized"
        ledger_scope = [ordered]@{
            subsystem = "turning"
            engine_scope = "mujoco"
            authority_mode = "physical_development"
            question_class = "development"
        }
        source_commit = [string]$source.commit
        origin_main_commit = [string]$source.origin_main_commit
        live_github_main_commit = [string]$source.live_github_main_commit
        source_worktree_clean = $true
        contract_raw_sha256 = Get-R23D72Sha256 $contractPath
        worker_raw_sha256 = Get-R23D72Sha256 $workerPath
        core_library_path = $corePath
        core_library_raw_sha256 = Get-R23D72Sha256 $corePath
        python_host = $pythonHost
        python_host_raw_sha256 = Get-R23D72Sha256 $pythonHost
        zero_world_receipt_raw_sha256 = Get-R23D72Sha256 $zeroWorldPath
        complete_zero_world_gate_passed = $true
        zero_world_model_construction_count = 0
        zero_world_world_attempt_count = 0
        zero_world_world_build_count = 0
        zero_world_solver_step_count = 0
        declared_world_count = 1
        ordered_cell_ids = @($cellId)
        source_bindings = $sourceBindings
        serial_execution_required = $true
        operation_lock = Get-SporeSporeLocomotionOperationLockPublicReceipt $lock
        physical_behavior_thresholds_applied = $true
        primary_behavior_threshold = [ordered]@{
            field = "torso_ground_contact_step_count_through_semantic_step_600"
            positive_value = 0
            provenance = "R23D71 pre-turn torso contact at step 146 versus retained R23D42 zero-contact startup-ramp reference"
        }
        outcome_exposed_fixture = $true
        turning_tested = $false
        physical_execution_authorized = $true
        physical_acceptance_authority = $false
    }
    $freezePath = Join-Path $resolvedOutput "physical-freeze.json"
    Write-R23D72NewJson $freezePath $freeze

    $attemptId = [guid]::NewGuid().ToString("N")
    $token = [guid]::NewGuid().ToString("N")
    $attempt = [ordered]@{
        schema_version = "sporespore_qsdk_r23d72_mujoco_preturn_attempt_v1"
        campaign_id = $campaignId
        gate_id = $gateId
        attempt_id = $attemptId
        source_commit = [string]$source.commit
        freeze_raw_sha256 = Get-R23D72Sha256 $freezePath
        authorization_token = $token
        attempt_root = $resolvedOutput
        ordered_cell_ids = @($cellId)
        single_use_supervisor_authorization = $true
        operation_lock_held = $true
        one_shot_attempt_unconsumed = $true
        physical_execution_authorized = $true
        physical_acceptance_authority = $false
    }
    $attemptPath = Join-Path $resolvedOutput "attempt-authorization.json"
    Write-R23D72NewJson $attemptPath $attempt

    $environment = @{
        PYTHONPATH = $pythonPath
        SPORESPORE_LOCOMOTION_LIBRARY = $corePath
        SPORESPORE_QSDK_R23D72_FREEZE = $freezePath
        SPORESPORE_QSDK_R23D72_ATTEMPT = $attemptPath
        SPORESPORE_QSDK_R23D72_TOKEN = $token
        SPORESPORE_QSDK_R23D72_STAGE = $stageId
        SPORESPORE_QSDK_R23D72_CELL = $cellId
        SPORESPORE_QSDK_R23D72_ENGINE = $engineId
        SPORESPORE_QSDK_R23D72_ATTEMPT_ROOT = $resolvedOutput
        SPORESPORE_QSDK_R23D72_AUTHORITY_REPO_ROOT = $repoRoot
        SPORESPORE_QSDK_R23D72_PYTHON = $pythonHost
        SPORESPORE_QSDK_R23D72_POWERSHELL = $PowerShell
    }

    $authorizationProcess = Invoke-R23D72Process -FileName $pythonHost -Arguments @(
        "-m", $workerModule, "authorization-preflight",
        "--source-commit", [string]$source.commit
    ) -Environment $environment -TimeoutSeconds 120
    Write-R23D72Text (
        Join-Path $resolvedOutput "authorization-preflight.stdout.log"
    ) ([string]$authorizationProcess.stdout)
    Write-R23D72Text (
        Join-Path $resolvedOutput "authorization-preflight.stderr.log"
    ) ([string]$authorizationProcess.stderr)
    Assert-R23D72 ($authorizationProcess.exit_code -eq 0) (
        "authorization preflight failed before the world opened"
    )
    $authorization = Get-R23D72Marker $authorizationProcess (
        "QSDK_R23D72_MUJOCO_AUTHORIZATION "
    )
    Assert-R23D72 (
        [bool]$authorization.authorization_passed -and
        [bool]$authorization.returned_before_model -and
        [int]$authorization.world_attempt_count -eq 0 -and
        [int]$authorization.world_build_count -eq 0
    ) "authorization receipt was not exact"
    Write-R23D72NewJson (
        Join-Path $resolvedOutput "authorization-preflight-receipt.json"
    ) $authorization

    $sourceBeforeWorld = Get-R23D72SourceIdentity -RequireCleanPushedLive
    Assert-R23D72 (
        [string]$sourceBeforeWorld.commit -ceq [string]$source.commit
    ) "source drifted immediately before the physical world"

    $physical = Invoke-R23D72Process -FileName $pythonHost -Arguments @(
        "-m", $workerModule, "physical",
        "--source-commit", [string]$source.commit
    ) -Environment $environment -TimeoutSeconds $PhysicalTimeoutSeconds
    $stdoutPath = Join-Path $resolvedOutput "physical.stdout.log"
    $stderrPath = Join-Path $resolvedOutput "physical.stderr.log"
    Write-R23D72Text $stdoutPath ([string]$physical.stdout)
    Write-R23D72Text $stderrPath ([string]$physical.stderr)
    $terminalMarker = "QSDK_R23D72_MUJOCO_TERMINAL "
    $terminalLines = @(
        ([string]$physical.stdout -split "`r?`n") |
            Where-Object {
                $_.StartsWith($terminalMarker, [StringComparison]::Ordinal)
            }
    )
    $terminal = if ($terminalLines.Count -eq 1) {
        try {
            $terminalLines[0].Substring($terminalMarker.Length) |
                ConvertFrom-Json -Depth 100
        } catch {
            [ordered]@{
                schema_version = "sporespore_qsdk_r23d72_mujoco_preturn_worker_failure_v1"
                campaign_id = $campaignId
                gate_id = $gateId
                question_class = "development"
                engine_id = $engineId
                cell_id = $cellId
                source_commit = [string]$source.commit
                failure_stage = "terminal_transport"
                failure_code = "QSDK_R23D72_TERMINAL_JSON_INVALID"
                world_attempt_count = 1
                world_build_count = 1
                classification = "invalid_or_incomplete_preturn_startup_development"
                physical_acceptance_authority = $false
            }
        }
    } else {
        [ordered]@{
            schema_version = "sporespore_qsdk_r23d72_mujoco_preturn_worker_failure_v1"
            campaign_id = $campaignId
            gate_id = $gateId
            question_class = "development"
            engine_id = $engineId
            cell_id = $cellId
            source_commit = [string]$source.commit
            failure_stage = "terminal_transport"
            failure_code = "QSDK_R23D72_TERMINAL_MARKER_COUNT_INVALID:$($terminalLines.Count)"
            world_attempt_count = 1
            world_build_count = 1
            classification = "invalid_or_incomplete_preturn_startup_development"
            physical_acceptance_authority = $false
        }
    }
    $terminalPath = Join-Path $resolvedOutput "terminal-report.json"
    Write-R23D72NewJson $terminalPath $terminal

    $classification = [string]$terminal.classification
    $validClassifications = @(
        "valid_complete_positive_preturn_startup_development",
        "valid_complete_negative_preturn_startup_development",
        "invalid_or_incomplete_preturn_startup_development"
    )
    Assert-R23D72 ($classification -cin $validClassifications) (
        "terminal classification is unknown: $classification"
    )
    $traceArtifact = if (
        $null -ne $terminal.PSObject.Properties["trace_artifact"]
    ) { $terminal.trace_artifact } else { $null }
    $completion = [ordered]@{
        schema_version = "sporespore_qsdk_r23d72_mujoco_preturn_completion_v1"
        campaign_id = $campaignId
        gate_id = $gateId
        attempt_id = $attemptId
        source_commit = [string]$source.commit
        attempt_root = $resolvedOutput
        classification = $classification
        worker_exit_code = [int]$physical.exit_code
        freeze_raw_sha256 = Get-R23D72Sha256 $freezePath
        attempt_authorization_raw_sha256 = Get-R23D72Sha256 $attemptPath
        terminal_report_raw_sha256 = Get-R23D72Sha256 $terminalPath
        physical_stdout_raw_sha256 = Get-R23D72Sha256 $stdoutPath
        physical_stderr_raw_sha256 = Get-R23D72Sha256 $stderrPath
        trace_artifact = $traceArtifact
        one_shot_attempt_consumed = $true
        retained_every_terminal_class = $true
        outcome_exposed_fixture = $true
        turning_tested = $false
        physical_acceptance_authority = $false
        completed_utc = [DateTime]::UtcNow.ToString("o")
    }
    $completionPath = Join-Path $resolvedOutput "completion.json"
    Write-R23D72NewJson $completionPath $completion

    Write-Output (
        "[turning/mujoco] R23D72 physical complete: " +
        "classification=$classification evidence=$resolvedOutput"
    )
    if ($classification -ceq "invalid_or_incomplete_preturn_startup_development") {
        throw "[turning/mujoco] R23D72 retained an invalid/incomplete development result"
    }
} finally {
    Exit-SporeSporeLocomotionOperationLock -Receipt $lock
}
