#requires -Version 7.0

[CmdletBinding()]
param(
    [switch]$PreflightOnly,
    [switch]$RunPhysical,
    [string]$Godot = (
        "C:\Users\Cole\CodeStuff\Misc\Godot\" +
        "Godot_v4.7-stable_mono_win64_console.exe"
    ),
    [string]$OutputRoot = "",
    [ValidateRange(60, 900)][int]$TimeoutSeconds = 360
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$sdkRoot = [System.IO.Path]::GetFullPath($PSScriptRoot)
$repoRoot = [System.IO.Path]::GetFullPath((Split-Path -Parent $sdkRoot))
$contractPath = Join-Path $sdkRoot "godot_jolt_phase_timing_contract.json"
$sourceToolPath = Join-Path $sdkRoot "godot_jolt_phase_timing_source.ps1"
$artifactStorePath = Join-Path $sdkRoot "content_addressed_artifact_store.ps1"
$operationLockPath = Join-Path $sdkRoot "locomotion_operation_lock.ps1"
$workerPath = Join-Path $repoRoot "tests\probe_godot_jolt_phase_timing.gd"
$adapterPath = Join-Path $sdkRoot "target\debug\sporespore_godot_adapter.dll"
$runtimePath = Join-Path (Split-Path -Parent $Godot) (
    [System.IO.Path]::GetFileNameWithoutExtension($Godot).Replace("_console", "") + ".exe"
)
$receiptPrefix = "GJPT1_PHASE_TIMING_RECEIPT "

. $sourceToolPath
. $artifactStorePath
. $operationLockPath

function Assert-Gjpt1Exact {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function Get-Gjpt1Hash {
    param([Parameter(Mandatory)][string]$Path)
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).
        Hash.ToLowerInvariant()
}

function Write-Gjpt1NewJson {
    param(
        [Parameter(Mandatory)]$Value,
        [Parameter(Mandatory)][string]$Path
    )
    Assert-Gjpt1Exact (-not (Test-Path -LiteralPath $Path)) (
        "GJPT1 refuses to overwrite retained artifact: $Path"
    )
    [System.IO.File]::WriteAllText(
        $Path,
        ($Value | ConvertTo-Json -Depth 64) + [Environment]::NewLine,
        [System.Text.UTF8Encoding]::new($false)
    )
}

function Invoke-Gjpt1Git {
    param([Parameter(Mandatory)][string[]]$Arguments)
    $output = @(& git -C $repoRoot @Arguments 2>&1)
    if ($LASTEXITCODE -ne 0) {
        throw "GJPT1 git failed: git $($Arguments -join ' '): $($output -join ' ')"
    }
    return ($output -join "`n").Trim()
}

function Get-Gjpt1ReceiptFromOutput {
    param([Parameter(Mandatory)][string]$Output)
    $lines = @($Output -split "\r?\n" | Where-Object {
        $_.StartsWith($receiptPrefix, [System.StringComparison]::Ordinal)
    })
    Assert-Gjpt1Exact ($lines.Count -eq 1) (
        "GJPT1 expected exactly one worker receipt, observed $($lines.Count)"
    )
    return $lines[0].Substring($receiptPrefix.Length) |
        ConvertFrom-Json -AsHashtable -Depth 64
}

function Invoke-Gjpt1Godot {
    param(
        [Parameter(Mandatory)][ValidateSet("preflight", "physical")][string]$Mode,
        [Parameter(Mandatory)][string]$WorkerRoot,
        [string]$AuthorizationPath = "",
        [string]$AuthorizationToken = "",
        [string]$WorkerReceiptPath = ""
    )
    $appData = Join-Path $WorkerRoot "appdata"
    $localAppData = Join-Path $WorkerRoot "localappdata"
    [void][System.IO.Directory]::CreateDirectory($appData)
    [void][System.IO.Directory]::CreateDirectory($localAppData)
    $start = [System.Diagnostics.ProcessStartInfo]::new()
    $start.FileName = $Godot
    $start.WorkingDirectory = $repoRoot
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    $start.Environment["APPDATA"] = $appData
    $start.Environment["LOCALAPPDATA"] = $localAppData
    foreach ($name in @(
        "SPORESPORE_GJPT1_AUTHORIZATION_PATH",
        "SPORESPORE_GJPT1_AUTHORIZATION_TOKEN",
        "SPORESPORE_GJPT1_WORKER_RECEIPT_PATH"
    )) { [void]$start.Environment.Remove($name) }
    if ($Mode -ceq "physical") {
        $start.Environment["SPORESPORE_GJPT1_AUTHORIZATION_PATH"] = $AuthorizationPath
        $start.Environment["SPORESPORE_GJPT1_AUTHORIZATION_TOKEN"] = $AuthorizationToken
        $start.Environment["SPORESPORE_GJPT1_WORKER_RECEIPT_PATH"] = $WorkerReceiptPath
    }
    foreach ($argument in @(
        "--headless", "--path", $repoRoot, "--script",
        "res://tests/probe_godot_jolt_phase_timing.gd", "--", $Mode
    )) { [void]$start.ArgumentList.Add($argument) }
    $process = [System.Diagnostics.Process]::new()
    $process.StartInfo = $start
    $timer = [System.Diagnostics.Stopwatch]::StartNew()
    Assert-Gjpt1Exact ([bool]$process.Start()) "GJPT1 failed to start Godot"
    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()
    $timedOut = $false
    $nextHeartbeat = 10.0
    while (-not $process.WaitForExit(1000)) {
        if ($timer.Elapsed.TotalSeconds -ge $nextHeartbeat) {
            Write-Host (
                "GJPT1_PROGRESS mode=$Mode elapsed_seconds=" +
                $timer.Elapsed.TotalSeconds.ToString("F1", [Globalization.CultureInfo]::InvariantCulture)
            )
            $nextHeartbeat += 10.0
        }
        if ($timer.Elapsed.TotalSeconds -ge $TimeoutSeconds) {
            $timedOut = $true
            try { $process.Kill($true) } catch { }
            [void]$process.WaitForExit(10000)
            break
        }
    }
    $timer.Stop()
    $stdout = $stdoutTask.GetAwaiter().GetResult()
    $stderr = $stderrTask.GetAwaiter().GetResult()
    $exitCode = if ($process.HasExited) { $process.ExitCode } else { -1 }
    $process.Dispose()
    return [ordered]@{
        exit_code = $exitCode
        timed_out = $timedOut
        duration_seconds = $timer.Elapsed.TotalSeconds
        stdout = $stdout
        stderr = $stderr
    }
}

function Assert-Gjpt1ContractAndRuntime {
    param([switch]$RequirePinnedArtifact)
    $required = @(
        $contractPath, $sourceToolPath, $artifactStorePath, $operationLockPath,
        $workerPath, $adapterPath, $Godot, $runtimePath
    )
    foreach ($path in $required) {
        Assert-Gjpt1Exact (Test-Path -LiteralPath $path -PathType Leaf) (
            "GJPT1 required source or runtime is missing: $path"
        )
    }
    Assert-Gjpt1Exact (
        (Invoke-Gjpt1Git @("rev-parse", "--show-toplevel")).Replace("/", "\") -ceq
            $repoRoot -and
        (Invoke-Gjpt1Git @("remote", "get-url", "origin")) -ceq
            "https://github.com/Slagathore/sporespore.git"
    ) "GJPT1 repository identity mismatch"
    $contract = Get-Content -Raw -LiteralPath $contractPath |
        ConvertFrom-Json -AsHashtable -Depth 64
    Assert-Gjpt1Exact (
        [string]$contract.schema_version -ceq
            "sporespore_godot_jolt_phase_timing_contract_v1" -and
        [string]$contract.contract_id -ceq "GJPT1" -and
        [string]$contract.cell.cell_id -ceq "gjpt1_baseline_s21001_bw32n_b" -and
        [int]$contract.cell.expected_world_count -eq 1 -and
        [bool]$contract.execution.complete_zero_world_gate_required_before_physical_world -and
        -not [bool]$contract.claims.physical_acceptance_authority
    ) "GJPT1 contract identity changed"
    foreach ($binding in @($contract.source_bindings)) {
        $path = Join-Path $repoRoot ([string]$binding.path)
        Assert-Gjpt1Exact (
            (Test-Path -LiteralPath $path -PathType Leaf) -and
            ("sha256:$(Get-Gjpt1Hash $path)" -ceq [string]$binding.raw_sha256)
        ) "GJPT1 source binding changed: $([string]$binding.path)"
    }
    foreach ($binding in @(
        $contract.instrumentation.base_runner,
        $contract.instrumentation.transformer,
        $contract.instrumentation.worker
    )) {
        $path = Join-Path $repoRoot ([string]$binding.path)
        Assert-Gjpt1Exact (
            (Test-Path -LiteralPath $path -PathType Leaf) -and
            ("sha256:$(Get-Gjpt1Hash $path)" -ceq [string]$binding.raw_sha256)
        ) "GJPT1 instrumentation binding changed: $([string]$binding.path)"
    }
    Assert-Gjpt1Exact (
        "sha256:$(Get-Gjpt1Hash $Godot)" -ceq
            [string]$contract.runtime_bindings.godot_console_raw_sha256 -and
        "sha256:$(Get-Gjpt1Hash $runtimePath)" -ceq
            [string]$contract.runtime_bindings.godot_runtime_raw_sha256
    ) "GJPT1 Godot runtime binding changed"
    if ($RequirePinnedArtifact) {
        Assert-Gjpt1Exact (
            "sha256:$(Get-Gjpt1Hash $adapterPath)" -ceq
                [string]$contract.runtime_bindings.godot_adapter_artifact_raw_sha256
        ) "GJPT1 physical adapter artifact binding changed"
    }
    $generated = New-Gjpt1InstrumentedRunner -RepoRoot $repoRoot
    Assert-Gjpt1Exact (
        [string]$generated.generated_raw_sha256 -ceq
            [string]$contract.instrumentation.generated_runner.raw_sha256 -and
        [long]$generated.generated_byte_length -eq
            [long]$contract.instrumentation.generated_runner.byte_length
    ) "GJPT1 generated runner did not reproduce its pinned bytes"
    return [ordered]@{ contract = $contract; generated = $generated }
}

function Invoke-Gjpt1CompleteZeroWorldGate {
    param([Parameter(Mandatory)]$Bindings)
    $preflightRoot = Join-Path $sdkRoot (
        "target\gjpt1\preflight-" + [guid]::NewGuid().ToString("N")
    )
    [void][System.IO.Directory]::CreateDirectory($preflightRoot)
    $result = Invoke-Gjpt1Godot -Mode preflight -WorkerRoot $preflightRoot
    $combined = $result.stdout + $result.stderr
    $receipt = if (-not $result.timed_out -and $result.exit_code -eq 0) {
        Get-Gjpt1ReceiptFromOutput $result.stdout
    } else { @{} }
    Assert-Gjpt1Exact (
        -not [bool]$result.timed_out -and
        [int]$result.exit_code -eq 0 -and
        [bool]$receipt.ok -and
        [int]$receipt.actual_world_build_count -eq 0 -and
        [int]$receipt.scene_tree_insertion_count -eq 0 -and
        -not [bool]$receipt.physics_state_modified -and
        -not [bool]$receipt.locomotion_outcome_exposed -and
        -not [bool]$receipt.physical_acceptance_authority
    ) "GJPT1 complete zero-world worker gate failed: $combined"
    return [ordered]@{
        receipt = $receipt
        process_duration_seconds = $result.duration_seconds
        generated_runner_raw_sha256 = [string]$Bindings.generated.generated_raw_sha256
        world_count = 0
        physical_acceptance_authority = $false
    }
}

function Invoke-Gjpt1Physical {
    param(
        [Parameter(Mandatory)]$Bindings,
        [Parameter(Mandatory)]$ZeroWorld
    )
    $head = Invoke-Gjpt1Git @("rev-parse", "HEAD")
    $origin = Invoke-Gjpt1Git @("rev-parse", "origin/main")
    $status = Invoke-Gjpt1Git @("status", "--short")
    $remoteLine = Invoke-Gjpt1Git @("ls-remote", "origin", "refs/heads/main")
    $live = if ([string]::IsNullOrWhiteSpace($remoteLine)) {
        ""
    } else { ($remoteLine -split "\s+")[0] }
    Assert-Gjpt1Exact (
        [string]::IsNullOrWhiteSpace($status) -and
        $head -ceq $origin -and $head -ceq $live
    ) "GJPT1 physical execution requires clean pushed live source"
    $evidenceRoot = Get-SporeSporeArtifactEvidenceRoot -RepoRoot $repoRoot
    $prior = @(
        Get-ChildItem -LiteralPath $evidenceRoot -Filter authorization.json -File -Recurse `
            -ErrorAction SilentlyContinue |
        Where-Object {
            try {
                $value = Get-Content -Raw -LiteralPath $_.FullName |
                    ConvertFrom-Json -AsHashtable -Depth 32
                [string]$value.contract_id -ceq "GJPT1"
            } catch { $false }
        }
    )
    Assert-Gjpt1Exact ($prior.Count -eq 0) (
        "GJPT1 first physical identity already has a retained authorization; rerun forbidden"
    )
    if ([string]::IsNullOrWhiteSpace($OutputRoot)) {
        $OutputRoot = Join-Path $evidenceRoot (
            "godot-jolt-phase-timing-" + [DateTime]::UtcNow.ToString("yyyyMMddTHHmmssZ")
        )
    }
    $resolvedOutput = [System.IO.Path]::GetFullPath($OutputRoot)
    $prefix = $evidenceRoot.TrimEnd('\', '/') +
        [System.IO.Path]::DirectorySeparatorChar
    Assert-Gjpt1Exact (
        $resolvedOutput.StartsWith(
            $prefix,
            [System.StringComparison]::OrdinalIgnoreCase
        ) -and -not (Test-Path -LiteralPath $resolvedOutput)
    ) "GJPT1 output must be a new directory under $evidenceRoot"
    [void][System.IO.Directory]::CreateDirectory($resolvedOutput)
    $generatedRetainedPath = Join-Path $resolvedOutput "instrumented_runner.gd"
    Copy-Item -LiteralPath ([string]$Bindings.generated.generated_path) `
        -Destination $generatedRetainedPath
    Assert-Gjpt1Exact (
        (Get-Gjpt1Hash $generatedRetainedPath) -ceq
            ([string]$Bindings.generated.generated_raw_sha256).Replace("sha256:", "")
    ) "GJPT1 retained generated runner changed during copy"
    $storedRunner = Publish-SporeSporeContentAddressedArtifact `
        -RepoRoot $repoRoot `
        -ArtifactPath $generatedRetainedPath `
        -MediaType "text/x-gdscript"
    $storedAdapter = Publish-SporeSporeContentAddressedArtifact `
        -RepoRoot $repoRoot `
        -ArtifactPath $adapterPath `
        -MediaType "application/vnd.microsoft.portable-executable"
    $token = [guid]::NewGuid().ToString("N")
    $authorization = [ordered]@{
        schema_version = "sporespore_godot_jolt_phase_timing_authorization_v1"
        contract_id = "GJPT1"
        cell_id = "gjpt1_baseline_s21001_bw32n_b"
        source_cell_template_id = "baseline_s21001_bw32n_b"
        authorization_token = $token
        source_commit = $head
        origin_main_commit = $origin
        live_github_main_commit = $live
        source_clean_pushed_live = $true
        contract_raw_sha256 = "sha256:$(Get-Gjpt1Hash $contractPath)"
        worker_raw_sha256 = "sha256:$(Get-Gjpt1Hash $workerPath)"
        instrumented_runner_sha256 = [string]$Bindings.generated.generated_raw_sha256
        content_addressed_instrumented_runner = $storedRunner
        godot_adapter_artifact_raw_sha256 = "sha256:$(Get-Gjpt1Hash $adapterPath)"
        content_addressed_godot_adapter_artifact = $storedAdapter
        complete_zero_world_gate_passed = [bool]$ZeroWorld.receipt.ok
        complete_zero_world_gate_world_count = 0
        physical_identity_consumed = $false
        same_identity_rerun_allowed = $false
        physical_acceptance_authority = $false
    }
    $authorizationPath = Join-Path $resolvedOutput "authorization.json"
    Write-Gjpt1NewJson $authorization $authorizationPath
    $workerReceiptPath = Join-Path $resolvedOutput "evidence_workload.json"
    $result = Invoke-Gjpt1Godot -Mode physical `
        -WorkerRoot (Join-Path $resolvedOutput "worker") `
        -AuthorizationPath $authorizationPath `
        -AuthorizationToken $token `
        -WorkerReceiptPath $workerReceiptPath
    $logPath = Join-Path $resolvedOutput "engine.log"
    [System.IO.File]::WriteAllText(
        $logPath,
        $result.stdout + $result.stderr,
        [System.Text.UTF8Encoding]::new($false)
    )
    $workerReceipt = @{}
    $workerExact = $false
    try {
        if (-not $result.timed_out -and $result.exit_code -eq 0) {
            $workerReceipt = Get-Gjpt1ReceiptFromOutput $result.stdout
            $workerExact = (
                [string]$workerReceipt.contract_id -ceq "GJPT1" -and
                [string]$workerReceipt.authorization_token -ceq $token -and
                [string]$workerReceipt.cell_id -ceq
                    "gjpt1_baseline_s21001_bw32n_b" -and
                -not [bool]$workerReceipt.physical_acceptance_authority -and
                (Test-Path -LiteralPath $workerReceiptPath -PathType Leaf) -and
                [string]$workerReceipt.source_projection_json_sha256 -ceq
                    "sha256:$(Get-Gjpt1Hash $workerReceiptPath)"
            )
        }
    } catch { $workerExact = $false }
    if (-not $workerExact) {
        $failure = [ordered]@{
            schema_version = "sporespore_godot_jolt_phase_timing_completion_v1"
            contract_id = "GJPT1"
            status = "invalid_or_incomplete_first_attempt"
            source_commit = $head
            process_exit_code = $result.exit_code
            process_timed_out = $result.timed_out
            process_duration_seconds = $result.duration_seconds
            engine_log_raw_sha256 = "sha256:$(Get-Gjpt1Hash $logPath)"
            physical_world_attempt_count = 1
            confirmed_physical_world_count = -1
            physical_identity_consumed = $true
            same_identity_rerun_allowed = $false
            physical_acceptance_authority = $false
        }
        Write-Gjpt1NewJson $failure (Join-Path $resolvedOutput "completion.json")
        throw "GJPT1 retained its first physical attempt as invalid or incomplete: $resolvedOutput"
    }
    $inner = $workerReceipt.world_runner_inner
    $denominator = [double]$workerReceipt.instrumented_denominator_usec
    Assert-Gjpt1Exact ($denominator -gt 0) "GJPT1 invalid phase denominator"
    $phases = [ordered]@{
        pre_physics_active_exclusive_boundary_usec =
            [long]$inner.pre_physics_active_exclusive_boundary_usec
        native_boundary_usec = [long]$inner.native_boundary_usec
        physics_frame_wait_usec = [long]$inner.physics_frame_wait_usec
        post_physics_observation_evidence_usec =
            [long]$inner.post_physics_observation_evidence_usec
        setup_summary_cleanup_residual_usec =
            [long]$inner.setup_summary_cleanup_residual_usec
        evidence_writing_total_usec = [long]$workerReceipt.evidence_writing_total_usec
    }
    $sum = [long](($phases.Values | Measure-Object -Sum).Sum)
    Assert-Gjpt1Exact ($sum -eq [long]$denominator) (
        "GJPT1 phase accounting did not close: sum=$sum denominator=$denominator"
    )
    $shares = [ordered]@{}
    foreach ($entry in $phases.GetEnumerator()) {
        $shares[$entry.Key.Replace("_usec", "_share")] =
            [double]$entry.Value / $denominator
    }
    $report = [ordered]@{
        schema_version = "sporespore_godot_jolt_phase_timing_report_v1"
        contract_id = "GJPT1"
        status = "completed_development_measurement"
        completed_utc = [DateTime]::UtcNow.ToString("o")
        source_commit = $head
        cell_id = "gjpt1_baseline_s21001_bw32n_b"
        source_cell_template_id = "baseline_s21001_bw32n_b"
        process_duration_seconds = $result.duration_seconds
        instrumented_tick_count = [int]$inner.instrumented_tick_count
        instrumented_denominator_usec = [long]$denominator
        phase_durations = $phases
        phase_shares = $shares
        native_boundary_speedup_observation = [ordered]@{
            gjps1_native_boundary_speedup = 9.0828
            total_cell_speedup_not_measured = $true
            amdahl_upper_bound_from_observed_native_share_requires_analysis = $true
        }
        evidence_workload_raw_sha256 = "sha256:$(Get-Gjpt1Hash $workerReceiptPath)"
        evidence_workload_byte_length = (Get-Item -LiteralPath $workerReceiptPath).Length
        engine_log_raw_sha256 = "sha256:$(Get-Gjpt1Hash $logPath)"
        instrumented_runner_content_address = $storedRunner
        godot_adapter_content_address = $storedAdapter
        source_world_outcome_observed_but_not_interpreted = $true
        physical_world_count = 1
        physical_identity_consumed = $true
        same_identity_rerun_allowed = $false
        walking_claim_authorized = $false
        performance_generalization_authorized = $false
        physical_acceptance_authority = $false
        release_authorized = $false
    }
    $reportPath = Join-Path $resolvedOutput "phase_report.json"
    Write-Gjpt1NewJson $report $reportPath
    $completion = [ordered]@{
        schema_version = "sporespore_godot_jolt_phase_timing_completion_v1"
        contract_id = "GJPT1"
        status = "completed_development_measurement"
        source_commit = $head
        report_path = "phase_report.json"
        report_raw_sha256 = "sha256:$(Get-Gjpt1Hash $reportPath)"
        physical_world_count = 1
        physical_identity_consumed = $true
        same_identity_rerun_allowed = $false
        physical_acceptance_authority = $false
    }
    Write-Gjpt1NewJson $completion (Join-Path $resolvedOutput "completion.json")
    Write-Host (
        "GJPT1_PHASE_TIMING_PASS worlds=1 ticks=$([int]$inner.instrumented_tick_count) " +
        "native_share=$($shares.native_boundary_share.ToString('F6', [Globalization.CultureInfo]::InvariantCulture)) " +
        "physics_share=$($shares.physics_frame_wait_share.ToString('F6', [Globalization.CultureInfo]::InvariantCulture)) " +
        "evidence_share=$($shares.evidence_writing_total_share.ToString('F6', [Globalization.CultureInfo]::InvariantCulture)) " +
        "physical_authority=False report=$reportPath"
    )
}

Assert-Gjpt1Exact ($PreflightOnly -xor $RunPhysical) (
    "GJPT1 requires exactly one of -PreflightOnly or -RunPhysical"
)
$bindings = Assert-Gjpt1ContractAndRuntime -RequirePinnedArtifact:$RunPhysical
$zeroWorld = Invoke-Gjpt1CompleteZeroWorldGate -Bindings $bindings
if ($PreflightOnly) {
    Write-Host (
        "GJPT1_PHASE_TIMING_PREFLIGHT_PASS worlds=0 generated_sha256=" +
        "$([string]$bindings.generated.generated_raw_sha256) " +
        "scene_insertions=0 physics_state_modified=False physical_authority=False"
    )
    exit 0
}
$operationLock = Enter-SporeSporeLocomotionOperationLock `
    -Role physical -TimeoutMilliseconds 0
try {
    Assert-Gjpt1Exact ([bool]$operationLock.acquired) (
        "GJPT1 another conformance or physical operation owns the shared lock"
    )
    Invoke-Gjpt1Physical -Bindings $bindings -ZeroWorld $zeroWorld
} finally {
    if ([bool]$operationLock.acquired) {
        Exit-SporeSporeLocomotionOperationLock $operationLock
    }
}
