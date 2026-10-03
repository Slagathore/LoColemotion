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
$contractPath = Join-Path $sdkRoot "godot_jolt_phase_timing_gjpt2_contract.json"
$gjpt1ContractPath = Join-Path $sdkRoot "godot_jolt_phase_timing_contract.json"
$gjpt1ClosurePath = Join-Path $sdkRoot "godot_jolt_phase_timing_gjpt1_closure.json"
$gjpt1PreflightPath = Join-Path $sdkRoot "run_godot_jolt_phase_timing.ps1"
$sourceToolPath = Join-Path $sdkRoot "godot_jolt_phase_timing_source.ps1"
$artifactStorePath = Join-Path $sdkRoot "content_addressed_artifact_store.ps1"
$operationLockPath = Join-Path $sdkRoot "locomotion_operation_lock.ps1"
$workerPath = Join-Path $repoRoot "tests\probe_godot_jolt_phase_timing_gjpt2.gd"
$adapterPath = Join-Path $sdkRoot "target\debug\sporespore_godot_adapter.dll"
$runtimePath = Join-Path (Split-Path -Parent $Godot) (
    [System.IO.Path]::GetFileNameWithoutExtension($Godot).Replace("_console", "") + ".exe"
)
$receiptPrefix = "GJPT2_PHASE_TIMING_RECEIPT "

. $sourceToolPath
. $artifactStorePath
. $operationLockPath

function Assert-Gjpt2Exact {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function Get-Gjpt2Hash {
    param([Parameter(Mandatory)][string]$Path)
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).
        Hash.ToLowerInvariant()
}

function Write-Gjpt2NewJson {
    param(
        [Parameter(Mandatory)]$Value,
        [Parameter(Mandatory)][string]$Path
    )
    Assert-Gjpt2Exact (-not (Test-Path -LiteralPath $Path)) (
        "GJPT2 refuses to overwrite retained artifact: $Path"
    )
    [System.IO.File]::WriteAllText(
        $Path,
        ($Value | ConvertTo-Json -Depth 64) + [Environment]::NewLine,
        [System.Text.UTF8Encoding]::new($false)
    )
}

function Invoke-Gjpt2Git {
    param([Parameter(Mandatory)][string[]]$Arguments)
    $output = @(& git -C $repoRoot @Arguments 2>&1)
    if ($LASTEXITCODE -ne 0) {
        throw "GJPT2 git failed: git $($Arguments -join ' '): $($output -join ' ')"
    }
    return ($output -join "`n").Trim()
}

function Get-Gjpt2ReceiptFromOutput {
    param([Parameter(Mandatory)][string]$Output)
    $lines = @($Output -split "\r?\n" | Where-Object {
        $_.StartsWith($receiptPrefix, [System.StringComparison]::Ordinal)
    })
    Assert-Gjpt2Exact ($lines.Count -eq 1) (
        "GJPT2 expected exactly one worker receipt, observed $($lines.Count)"
    )
    return $lines[0].Substring($receiptPrefix.Length) |
        ConvertFrom-Json -AsHashtable -Depth 64
}

function Invoke-Gjpt2Godot {
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
        "SPORESPORE_GJPT1_WORKER_RECEIPT_PATH",
        "SPORESPORE_GJPT2_AUTHORIZATION_PATH",
        "SPORESPORE_GJPT2_AUTHORIZATION_TOKEN",
        "SPORESPORE_GJPT2_WORKER_RECEIPT_PATH"
    )) { [void]$start.Environment.Remove($name) }
    if ($Mode -ceq "physical") {
        $start.Environment["SPORESPORE_GJPT2_AUTHORIZATION_PATH"] = $AuthorizationPath
        $start.Environment["SPORESPORE_GJPT2_AUTHORIZATION_TOKEN"] = $AuthorizationToken
        $start.Environment["SPORESPORE_GJPT2_WORKER_RECEIPT_PATH"] = $WorkerReceiptPath
    }
    foreach ($argument in @(
        "--headless", "--path", $repoRoot, "--script",
        "res://tests/probe_godot_jolt_phase_timing_gjpt2.gd", "--", $Mode
    )) { [void]$start.ArgumentList.Add($argument) }
    $process = [System.Diagnostics.Process]::new()
    $process.StartInfo = $start
    $timer = [System.Diagnostics.Stopwatch]::StartNew()
    Assert-Gjpt2Exact ([bool]$process.Start()) "GJPT2 failed to start Godot"
    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()
    $timedOut = $false
    $nextHeartbeat = 10.0
    while (-not $process.WaitForExit(1000)) {
        if ($timer.Elapsed.TotalSeconds -ge $nextHeartbeat) {
            Write-Host (
                "GJPT2_PROGRESS mode=$Mode elapsed_seconds=" +
                $timer.Elapsed.TotalSeconds.ToString(
                    "F1", [Globalization.CultureInfo]::InvariantCulture
                )
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

function Assert-Gjpt2ContractAndRuntime {
    param([switch]$RequirePinnedArtifact)
    foreach ($path in @(
        $contractPath, $gjpt1ContractPath, $gjpt1ClosurePath,
        $gjpt1PreflightPath, $sourceToolPath, $artifactStorePath,
        $operationLockPath, $workerPath, $adapterPath, $Godot, $runtimePath
    )) {
        Assert-Gjpt2Exact (Test-Path -LiteralPath $path -PathType Leaf) (
            "GJPT2 required source or runtime is missing: $path"
        )
    }
    Assert-Gjpt2Exact (
        (Invoke-Gjpt2Git @("rev-parse", "--show-toplevel")).Replace("/", "\") -ceq
            $repoRoot -and
        (Invoke-Gjpt2Git @("remote", "get-url", "origin")) -ceq
            "https://github.com/Slagathore/sporespore.git"
    ) "GJPT2 repository identity mismatch"
    $contract = Get-Content -Raw -LiteralPath $contractPath |
        ConvertFrom-Json -AsHashtable -Depth 64
    Assert-Gjpt2Exact (
        [string]$contract.schema_version -ceq
            "sporespore_godot_jolt_phase_timing_gjpt2_contract_v1" -and
        [string]$contract.contract_id -ceq "GJPT2" -and
        [string]$contract.cell.cell_id -ceq "gjpt2_baseline_s21001_bw32n_b" -and
        [int]$contract.cell.expected_world_count -eq 1 -and
        [bool]$contract.execution.complete_zero_world_gate_required_before_physical_world -and
        [bool]$contract.execution.synthetic_projection_canary_required -and
        -not [bool]$contract.claims.physical_acceptance_authority
    ) "GJPT2 contract identity changed"
    foreach ($binding in @($contract.source_bindings)) {
        $path = Join-Path $repoRoot ([string]$binding.path)
        Assert-Gjpt2Exact (
            (Test-Path -LiteralPath $path -PathType Leaf) -and
            ("sha256:$(Get-Gjpt2Hash $path)" -ceq [string]$binding.raw_sha256)
        ) "GJPT2 source binding changed: $([string]$binding.path)"
    }
    Assert-Gjpt2Exact (
        "sha256:$(Get-Gjpt2Hash $Godot)" -ceq
            [string]$contract.runtime_bindings.godot_console_raw_sha256 -and
        "sha256:$(Get-Gjpt2Hash $runtimePath)" -ceq
            [string]$contract.runtime_bindings.godot_runtime_raw_sha256
    ) "GJPT2 Godot runtime binding changed"
    if ($RequirePinnedArtifact) {
        Assert-Gjpt2Exact (
            "sha256:$(Get-Gjpt2Hash $adapterPath)" -ceq
                [string]$contract.runtime_bindings.godot_adapter_artifact_raw_sha256
        ) "GJPT2 physical adapter artifact binding changed"
    }
    $generated = New-Gjpt1InstrumentedRunner -RepoRoot $repoRoot
    Assert-Gjpt2Exact (
        [string]$generated.generated_raw_sha256 -ceq
            [string]$contract.instrumentation.generated_runner.raw_sha256 -and
        [long]$generated.generated_byte_length -eq
            [long]$contract.instrumentation.generated_runner.byte_length
    ) "GJPT2 generated runner did not reproduce its pinned bytes"
    return [ordered]@{ contract = $contract; generated = $generated }
}

function Invoke-Gjpt2CompleteZeroWorldGate {
    param([Parameter(Mandatory)]$Bindings)
    $gjpt1Output = @(& pwsh -NoLogo -NoProfile -File $gjpt1PreflightPath -PreflightOnly 2>&1)
    Assert-Gjpt2Exact (
        $LASTEXITCODE -eq 0 -and
        ($gjpt1Output -join "`n").Contains("GJPT1_PHASE_TIMING_PREFLIGHT_PASS worlds=0")
    ) "GJPT2 inherited instrumented-runner preflight failed: $($gjpt1Output -join ' ')"
    $preflightRoot = Join-Path $sdkRoot (
        "target\gjpt2\preflight-" + [guid]::NewGuid().ToString("N")
    )
    [void][System.IO.Directory]::CreateDirectory($preflightRoot)
    $result = Invoke-Gjpt2Godot -Mode preflight -WorkerRoot $preflightRoot
    $combined = $result.stdout + $result.stderr
    $receipt = if (-not $result.timed_out -and $result.exit_code -eq 0) {
        Get-Gjpt2ReceiptFromOutput $result.stdout
    } else { @{} }
    Assert-Gjpt2Exact (
        -not [bool]$result.timed_out -and
        [int]$result.exit_code -eq 0 -and
        [bool]$receipt.ok -and
        [bool]$receipt.projection_canary_passed -and
        -not [bool]$receipt.projection_calls_frozen_acceptance_composer -and
        [int]$receipt.actual_world_build_count -eq 0 -and
        [int]$receipt.scene_tree_insertion_count -eq 0 -and
        -not [bool]$receipt.physics_state_modified -and
        -not [bool]$receipt.locomotion_outcome_exposed -and
        -not [bool]$receipt.physical_acceptance_authority
    ) "GJPT2 complete zero-world worker gate failed: $combined"
    return [ordered]@{
        receipt = $receipt
        process_duration_seconds = $result.duration_seconds
        generated_runner_raw_sha256 = [string]$Bindings.generated.generated_raw_sha256
        world_count = 0
        physical_acceptance_authority = $false
    }
}

function Invoke-Gjpt2Physical {
    param(
        [Parameter(Mandatory)]$Bindings,
        [Parameter(Mandatory)]$ZeroWorld
    )
    $head = Invoke-Gjpt2Git @("rev-parse", "HEAD")
    $origin = Invoke-Gjpt2Git @("rev-parse", "origin/main")
    $status = Invoke-Gjpt2Git @("status", "--short")
    $remoteLine = Invoke-Gjpt2Git @("ls-remote", "origin", "refs/heads/main")
    $live = if ([string]::IsNullOrWhiteSpace($remoteLine)) {
        ""
    } else { ($remoteLine -split "\s+")[0] }
    Assert-Gjpt2Exact (
        [string]::IsNullOrWhiteSpace($status) -and
        $head -ceq $origin -and $head -ceq $live
    ) "GJPT2 physical execution requires clean pushed live source"
    $evidenceRoot = Get-SporeSporeArtifactEvidenceRoot -RepoRoot $repoRoot
    $prior = @(
        Get-ChildItem -LiteralPath $evidenceRoot -Filter authorization.json -File -Recurse `
            -ErrorAction SilentlyContinue |
        Where-Object {
            try {
                $value = Get-Content -Raw -LiteralPath $_.FullName |
                    ConvertFrom-Json -AsHashtable -Depth 32
                [string]$value.contract_id -ceq "GJPT2"
            } catch { $false }
        }
    )
    Assert-Gjpt2Exact ($prior.Count -eq 0) (
        "GJPT2 first physical identity already has a retained authorization; rerun forbidden"
    )
    if ([string]::IsNullOrWhiteSpace($OutputRoot)) {
        $OutputRoot = Join-Path $evidenceRoot (
            "godot-jolt-phase-timing-gjpt2-" +
            [DateTime]::UtcNow.ToString("yyyyMMddTHHmmssZ")
        )
    }
    $resolvedOutput = [System.IO.Path]::GetFullPath($OutputRoot)
    $prefix = $evidenceRoot.TrimEnd('\', '/') +
        [System.IO.Path]::DirectorySeparatorChar
    Assert-Gjpt2Exact (
        $resolvedOutput.StartsWith(
            $prefix, [System.StringComparison]::OrdinalIgnoreCase
        ) -and -not (Test-Path -LiteralPath $resolvedOutput)
    ) "GJPT2 output must be a new directory under $evidenceRoot"
    [void][System.IO.Directory]::CreateDirectory($resolvedOutput)
    $generatedRetainedPath = Join-Path $resolvedOutput "instrumented_runner.gd"
    Copy-Item -LiteralPath ([string]$Bindings.generated.generated_path) `
        -Destination $generatedRetainedPath
    Assert-Gjpt2Exact (
        (Get-Gjpt2Hash $generatedRetainedPath) -ceq
            ([string]$Bindings.generated.generated_raw_sha256).Replace("sha256:", "")
    ) "GJPT2 retained generated runner changed during copy"
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
        schema_version = "sporespore_godot_jolt_phase_timing_gjpt2_authorization_v1"
        contract_id = "GJPT2"
        cell_id = "gjpt2_baseline_s21001_bw32n_b"
        source_cell_template_id = "baseline_s21001_bw32n_b"
        authorization_token = $token
        source_commit = $head
        origin_main_commit = $origin
        live_github_main_commit = $live
        source_clean_pushed_live = $true
        contract_raw_sha256 = "sha256:$(Get-Gjpt2Hash $contractPath)"
        gjpt1_invalid_closure_raw_sha256 = "sha256:$(Get-Gjpt2Hash $gjpt1ClosurePath)"
        worker_raw_sha256 = "sha256:$(Get-Gjpt2Hash $workerPath)"
        instrumented_runner_sha256 = [string]$Bindings.generated.generated_raw_sha256
        content_addressed_instrumented_runner = $storedRunner
        godot_adapter_artifact_raw_sha256 = "sha256:$(Get-Gjpt2Hash $adapterPath)"
        content_addressed_godot_adapter_artifact = $storedAdapter
        complete_zero_world_gate_passed = [bool]$ZeroWorld.receipt.ok
        synthetic_projection_canary_passed = [bool]$ZeroWorld.receipt.projection_canary_passed
        complete_zero_world_gate_world_count = 0
        physical_identity_consumed = $false
        same_identity_rerun_allowed = $false
        physical_acceptance_authority = $false
    }
    $authorizationPath = Join-Path $resolvedOutput "authorization.json"
    Write-Gjpt2NewJson $authorization $authorizationPath
    $workerReceiptPath = Join-Path $resolvedOutput "evidence_workload.json"
    $result = Invoke-Gjpt2Godot -Mode physical `
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
            $workerReceipt = Get-Gjpt2ReceiptFromOutput $result.stdout
            $workerExact = (
                [string]$workerReceipt.contract_id -ceq "GJPT2" -and
                [string]$workerReceipt.authorization_token -ceq $token -and
                [string]$workerReceipt.cell_id -ceq
                    "gjpt2_baseline_s21001_bw32n_b" -and
                -not [bool]$workerReceipt.physical_acceptance_authority -and
                (Test-Path -LiteralPath $workerReceiptPath -PathType Leaf) -and
                [string]$workerReceipt.development_projection_json_sha256 -ceq
                    "sha256:$(Get-Gjpt2Hash $workerReceiptPath)"
            )
        }
    } catch { $workerExact = $false }
    if (-not $workerExact) {
        $failure = [ordered]@{
            schema_version = "sporespore_godot_jolt_phase_timing_gjpt2_completion_v1"
            contract_id = "GJPT2"
            status = "invalid_or_incomplete_first_attempt"
            source_commit = $head
            process_exit_code = $result.exit_code
            process_timed_out = $result.timed_out
            process_duration_seconds = $result.duration_seconds
            engine_log_raw_sha256 = "sha256:$(Get-Gjpt2Hash $logPath)"
            physical_world_attempt_count = 1
            confirmed_physical_world_count = -1
            physical_identity_consumed = $true
            same_identity_rerun_allowed = $false
            physical_acceptance_authority = $false
        }
        Write-Gjpt2NewJson $failure (Join-Path $resolvedOutput "completion.json")
        throw "GJPT2 retained its first physical attempt as invalid or incomplete: $resolvedOutput"
    }
    $inner = $workerReceipt.world_runner_inner
    Assert-Gjpt2Exact (
        [int]$inner.instrumented_tick_count -eq 3472
    ) "GJPT2 instrumented tick count changed"
    $denominator = [long]$workerReceipt.instrumented_denominator_usec
    Assert-Gjpt2Exact ($denominator -gt 0) "GJPT2 invalid phase denominator"
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
    Assert-Gjpt2Exact ($sum -eq $denominator) (
        "GJPT2 phase accounting did not close: sum=$sum denominator=$denominator"
    )
    $shares = [ordered]@{}
    foreach ($entry in $phases.GetEnumerator()) {
        $shares[$entry.Key.Replace("_usec", "_share")] =
            [double]$entry.Value / [double]$denominator
    }
    $nativeSpeedup = 9.0828
    $estimatedRecoveredSpeedup = 1.0 +
        ([double]$shares.native_boundary_share * ($nativeSpeedup - 1.0))
    $report = [ordered]@{
        schema_version = "sporespore_godot_jolt_phase_timing_gjpt2_report_v1"
        contract_id = "GJPT2"
        status = "completed_development_measurement"
        completed_utc = [DateTime]::UtcNow.ToString("o")
        source_commit = $head
        cell_id = "gjpt2_baseline_s21001_bw32n_b"
        source_cell_template_id = "baseline_s21001_bw32n_b"
        process_duration_seconds = $result.duration_seconds
        instrumented_tick_count = [int]$inner.instrumented_tick_count
        instrumented_denominator_usec = $denominator
        phase_durations = $phases
        phase_shares = $shares
        persistent_session_analysis = [ordered]@{
            gjps1_native_boundary_speedup = $nativeSpeedup
            observed_native_share_is_post_optimization = $true
            estimated_recovered_stateless_to_persistent_total_cell_speedup =
                $estimatedRecoveredSpeedup
            estimate_formula = "1 + post_optimization_native_share * (native_boundary_speedup - 1)"
            estimate_assumes_non_boundary_work_is_unchanged = $true
            direct_total_cell_speedup_measured = $false
            performance_generalization_authorized = $false
        }
        evidence_workload_raw_sha256 = "sha256:$(Get-Gjpt2Hash $workerReceiptPath)"
        evidence_workload_byte_length = (Get-Item -LiteralPath $workerReceiptPath).Length
        engine_log_raw_sha256 = "sha256:$(Get-Gjpt2Hash $logPath)"
        instrumented_runner_content_address = $storedRunner
        godot_adapter_content_address = $storedAdapter
        gjpt1_invalid_closure_raw_sha256 = "sha256:$(Get-Gjpt2Hash $gjpt1ClosurePath)"
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
    Write-Gjpt2NewJson $report $reportPath
    $completion = [ordered]@{
        schema_version = "sporespore_godot_jolt_phase_timing_gjpt2_completion_v1"
        contract_id = "GJPT2"
        status = "completed_development_measurement"
        source_commit = $head
        report_path = "phase_report.json"
        report_raw_sha256 = "sha256:$(Get-Gjpt2Hash $reportPath)"
        physical_world_count = 1
        physical_identity_consumed = $true
        same_identity_rerun_allowed = $false
        physical_acceptance_authority = $false
    }
    Write-Gjpt2NewJson $completion (Join-Path $resolvedOutput "completion.json")
    Write-Host (
        "GJPT2_PHASE_TIMING_PASS worlds=1 ticks=$([int]$inner.instrumented_tick_count) " +
        "native_share=$($shares.native_boundary_share.ToString('F6', [Globalization.CultureInfo]::InvariantCulture)) " +
        "physics_share=$($shares.physics_frame_wait_share.ToString('F6', [Globalization.CultureInfo]::InvariantCulture)) " +
        "evidence_share=$($shares.evidence_writing_total_share.ToString('F6', [Globalization.CultureInfo]::InvariantCulture)) " +
        "estimated_recovered_speedup=$($estimatedRecoveredSpeedup.ToString('F4', [Globalization.CultureInfo]::InvariantCulture)) " +
        "physical_authority=False report=$reportPath"
    )
}

Assert-Gjpt2Exact ($PreflightOnly -xor $RunPhysical) (
    "GJPT2 requires exactly one of -PreflightOnly or -RunPhysical"
)
$bindings = Assert-Gjpt2ContractAndRuntime -RequirePinnedArtifact:$RunPhysical
$zeroWorld = Invoke-Gjpt2CompleteZeroWorldGate -Bindings $bindings
if ($PreflightOnly) {
    Write-Host (
        "GJPT2_PHASE_TIMING_PREFLIGHT_PASS worlds=0 generated_sha256=" +
        "$([string]$bindings.generated.generated_raw_sha256) " +
        "projection_canary=True scene_insertions=0 physics_state_modified=False " +
        "physical_authority=False"
    )
    exit 0
}
$operationLock = Enter-SporeSporeLocomotionOperationLock `
    -Role physical -TimeoutMilliseconds 0
try {
    Assert-Gjpt2Exact ([bool]$operationLock.acquired) (
        "GJPT2 another conformance or physical operation owns the shared lock"
    )
    Invoke-Gjpt2Physical -Bindings $bindings -ZeroWorld $zeroWorld
} finally {
    if ([bool]$operationLock.acquired) {
        Exit-SporeSporeLocomotionOperationLock $operationLock
    }
}
