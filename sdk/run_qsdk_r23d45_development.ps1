#requires -Version 7.0

[CmdletBinding()]
param(
    [switch]$PreflightOnly,
    [switch]$RunPhysical,
    [string]$OutputRoot = "",
    [string]$Python = "python",
    [string]$PowerShell = "pwsh",
    [ValidateRange(60, 1800)][int]$TimeoutSeconds = 900
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$sdkRoot = [IO.Path]::GetFullPath($PSScriptRoot)
$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $sdkRoot))
$turningRoot = Join-Path $sdkRoot "turning"
$mujocoRoot = Join-Path $sdkRoot "adapters\mujoco"
$sitePackages = Join-Path $mujocoRoot ".venv\Lib\site-packages"
$campaignId = "QSDK-R23D45-SUPPORT-LOSS-CONDITIONED-STARTUP-DEVELOPMENT"
$gateId = "QSDK-R23D45"
$stageId = "mujoco_support_loss_conditioned_startup_development"
$armId = "reference_zero"
$cellId = "mujoco__r23d29_support_loss_conditioned_startup_v1__reference_zero"
$expectedRemote = "https://github.com/Slagathore/sporespore.git"
$preregistrationPath = Join-Path $turningRoot (
    "r23d45_support_loss_conditioned_startup_preregistration_v1.json"
)
$implementationPath = Join-Path $turningRoot (
    "r23d45_support_loss_conditioned_startup_implementation_v1.json"
)
$closurePath = Join-Path $turningRoot (
    "r23d45_support_loss_conditioned_startup_closure_v1.json"
)
$workerModule = (
    "sporespore_mujoco_adapter." +
    "qsdk_r23d45_support_loss_conditioned_startup"
)
$coreDebugPath = Join-Path $sdkRoot "target\debug\sporespore_locomotion_core.dll"
$coreReleasePath = Join-Path $sdkRoot "target\release\sporespore_locomotion_core.dll"

. (Join-Path $sdkRoot "locomotion_operation_lock.ps1")
. (Join-Path $sdkRoot "locomotion_full_conformance_attestation.ps1")
. (Join-Path $sdkRoot "r23d3_reproducible_runtime_materialization.ps1")

function Assert-R45([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "$gateId`: $Message" }
}

function Resolve-R45Application([string]$Command) {
    if ([IO.Path]::IsPathFullyQualified($Command)) {
        $resolved = [IO.Path]::GetFullPath($Command)
        Assert-R45 (Test-Path -LiteralPath $resolved -PathType Leaf) (
            "application is missing: $resolved"
        )
        return $resolved
    }
    $candidate = Get-Command $Command -ErrorAction Stop
    return [IO.Path]::GetFullPath($candidate.Source)
}

function Get-R45Sha256([string]$Path) {
    return "sha256:" + (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Write-R45NewText([string]$Path, [string]$Text) {
    $resolved = [IO.Path]::GetFullPath($Path)
    $parent = Split-Path -Parent $resolved
    if (-not (Test-Path -LiteralPath $parent -PathType Container)) {
        [void][IO.Directory]::CreateDirectory($parent)
    }
    $stream = [IO.File]::Open(
        $resolved,
        [IO.FileMode]::CreateNew,
        [IO.FileAccess]::Write,
        [IO.FileShare]::None
    )
    try {
        $writer = [IO.StreamWriter]::new(
            $stream,
            [Text.UTF8Encoding]::new($false)
        )
        try { $writer.Write($Text) } finally { $writer.Dispose() }
    } finally {
        $stream.Dispose()
    }
}

function Write-R45NewJson([string]$Path, $Value) {
    $json = $Value | ConvertTo-Json -Depth 100
    Write-R45NewText -Path $Path -Text ($json + [Environment]::NewLine)
}

function Invoke-R45Git([string[]]$Arguments) {
    $lines = @(& git -C $repoRoot @Arguments 2>&1)
    if ($LASTEXITCODE -ne 0) {
        throw "$gateId git $($Arguments -join ' ') failed: $($lines -join ' ')"
    }
    return $lines
}

function Invoke-R45Process {
    param(
        [Parameter(Mandatory)][string]$FileName,
        [Parameter(Mandatory)][string[]]$Arguments,
        [Parameter(Mandatory)][hashtable]$Environment,
        [int]$Timeout = $TimeoutSeconds
    )
    $start = [Diagnostics.ProcessStartInfo]::new()
    $start.FileName = $FileName
    $start.WorkingDirectory = $repoRoot
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    $start.StandardOutputEncoding = [Text.Encoding]::UTF8
    $start.StandardErrorEncoding = [Text.Encoding]::UTF8
    foreach ($argument in $Arguments) { [void]$start.ArgumentList.Add($argument) }
    foreach ($name in @(
        "SPORESPORE_QSDK_R23D45_ATTEMPT",
        "SPORESPORE_QSDK_R23D45_ATTEMPT_ROOT",
        "SPORESPORE_QSDK_R23D45_TOKEN",
        "SPORESPORE_QSDK_R23D45_PYTHON",
        "SPORESPORE_QSDK_R23D45_POWERSHELL"
    )) { [void]$start.Environment.Remove($name) }
    foreach ($entry in $Environment.GetEnumerator()) {
        $start.Environment[[string]$entry.Key] = [string]$entry.Value
    }
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $start
    $startedUtc = [DateTime]::UtcNow
    if (-not $process.Start()) { throw "$gateId process did not start: $FileName" }
    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()
    $timedOut = -not $process.WaitForExit($Timeout * 1000)
    if ($timedOut) {
        try { $process.Kill($true) } catch {}
        [void]$process.WaitForExit(10000)
    }
    [Threading.Tasks.Task]::WaitAll(@($stdoutTask, $stderrTask))
    $endedUtc = [DateTime]::UtcNow
    $receipt = [ordered]@{
        file_name = $FileName
        arguments = @($Arguments)
        started_utc = $startedUtc.ToString("o")
        ended_utc = $endedUtc.ToString("o")
        duration_seconds = ($endedUtc - $startedUtc).TotalSeconds
        exit_code = if ($timedOut) { -1 } else { $process.ExitCode }
        timed_out = $timedOut
        stdout = $stdoutTask.Result
        stderr = $stderrTask.Result
    }
    $process.Dispose()
    return $receipt
}

function Get-R45MarkerJson([string]$Text, [string]$Prefix) {
    $matches = @(
        $Text -split "`r?`n" |
            Where-Object { $_.StartsWith($Prefix, [StringComparison]::Ordinal) }
    )
    Assert-R45 ($matches.Count -eq 1) (
        "expected one '$Prefix' marker, observed $($matches.Count)"
    )
    return $matches[0].Substring($Prefix.Length) |
        ConvertFrom-Json -AsHashtable -Depth 100
}

function Get-R45PythonEnvironment([string]$CoreLibrary) {
    Assert-R45 (Test-Path -LiteralPath $sitePackages -PathType Container) (
        "locked MuJoCo site-packages are missing: $sitePackages"
    )
    Assert-R45 (Test-Path -LiteralPath $CoreLibrary -PathType Leaf) (
        "locomotion core library is missing: $CoreLibrary"
    )
    return @{
        PYTHONPATH = (@(
            (Join-Path $sdkRoot "python"),
            $mujocoRoot,
            $sitePackages,
            $turningRoot
        ) -join [IO.Path]::PathSeparator)
        SPORESPORE_LOCOMOTION_LIBRARY = [IO.Path]::GetFullPath($CoreLibrary)
    }
}

function Invoke-R45ZeroWorld([string]$PythonHost, [string]$CoreLibrary) {
    $environment = Get-R45PythonEnvironment -CoreLibrary $CoreLibrary
    $unit = Invoke-R45Process -FileName $PythonHost -Arguments @(
        "-m", "unittest",
        "sdk/turning/test_r23d45_support_loss_conditioned_startup.py", "-v"
    ) -Environment $environment
    Assert-R45 (
        -not [bool]$unit.timed_out -and [int]$unit.exit_code -eq 0
    ) "pure startup-transform tests failed: $($unit.stderr)"
    $worker = Invoke-R45Process -FileName $PythonHost -Arguments @(
        "-m", $workerModule, "preflight",
        "--stage", $stageId, "--arm", $armId
    ) -Environment $environment
    Assert-R45 (
        -not [bool]$worker.timed_out -and [int]$worker.exit_code -eq 0
    ) "worker preflight failed: $($worker.stdout) $($worker.stderr)"
    $receipt = Get-R45MarkerJson -Text ([string]$worker.stdout) `
        -Prefix "QSDK_R23D45_MUJOCO_PREFLIGHT "
    $discovery = $receipt.retained_discovery_dispatch_canary
    $composition = $receipt.support_loss_composition_canary
    $traceCanary = $receipt.trace_validation_canary
    Assert-R45 (
        [string]$receipt.campaign_id -ceq $campaignId -and
        [string]$receipt.gate_id -ceq $gateId -and
        [string]$receipt.cell_id -ceq $cellId -and
        [int]$receipt.engine_identity_input_count -eq 0 -and
        [int]$receipt.arm_identity_input_count -eq 0 -and
        [int]$receipt.model_construction_count -eq 0 -and
        [int]$receipt.world_attempt_count -eq 0 -and
        [int]$receipt.world_build_count -eq 0 -and
        [int]$discovery.retained_trace_count -eq 4 -and
        -not [bool]$discovery.engine_identity_used_by_transform -and
        [int]$composition.trigger_step -eq 3 -and
        [int]$composition.model_construction_count -eq 0 -and
        [int]$composition.world_attempt_count -eq 0 -and
        [int]$composition.world_build_count -eq 0 -and
        [int]$traceCanary.valid_trace_row_count -eq 2992 -and
        [int]$traceCanary.valid_trace_trigger_step -eq 3 -and
        [int]$traceCanary.trace_mutation_rejection_count -eq 3 -and
        [int]$traceCanary.model_construction_count -eq 0 -and
        [int]$traceCanary.world_attempt_count -eq 0 -and
        [int]$traceCanary.world_build_count -eq 0 -and
        -not [bool]$receipt.physical_execution_authorized -and
        -not [bool]$receipt.physical_acceptance_authority
    ) "$gateId complete zero-world receipt changed"
    return [ordered]@{
        pure_test_process = $unit
        worker_process = $worker
        receipt = $receipt
        model_construction_count = 0
        world_attempt_count = 0
        world_build_count = 0
        physical_acceptance_authority = $false
    }
}

function Get-R45SourceBindings {
    $implementation = Get-Content -Raw -LiteralPath $implementationPath |
        ConvertFrom-Json -AsHashtable -Depth 100
    $paths = [Collections.Generic.List[string]]::new()
    foreach ($path in @($implementation.source_binding_policy.exact_paths)) {
        $paths.Add(([string]$path).Replace("\", "/"))
    }
    foreach ($prefix in @($implementation.source_binding_policy.inherited_prefixes)) {
        $relative = ([string]$prefix).Replace("\", "/")
        $listed = @(Invoke-R45Git @("ls-files", "--", $relative))
        Assert-R45 ($listed.Count -gt 0) "source-binding prefix is empty: $relative"
        foreach ($path in $listed) { $paths.Add(([string]$path).Replace("\", "/")) }
    }
    $ordered = @($paths | Sort-Object -Unique)
    Assert-R45 ($ordered.Count -eq $paths.Count) "duplicate source binding"
    return @(
        foreach ($relative in $ordered) {
            $absolute = Join-Path $repoRoot $relative
            Assert-R45 (Test-Path -LiteralPath $absolute -PathType Leaf) (
                "source binding is missing: $relative"
            )
            $blob = (Invoke-R45Git @("rev-parse", "HEAD:$relative") | Out-String).Trim()
            $checkout = (
                Invoke-R45Git @("hash-object", "--no-filters", "--", $relative) |
                    Out-String
            ).Trim()
            Assert-R45 ($blob -ceq $checkout) (
                "checkout bytes differ from HEAD blob: $relative"
            )
            [ordered]@{
                path = $relative
                git_blob_oid = $blob
                raw_sha256 = Get-R45Sha256 $absolute
                byte_length = (Get-Item -LiteralPath $absolute).Length
            }
        }
    )
}

Assert-R45 ([bool]$PreflightOnly -xor [bool]$RunPhysical) (
    "specify exactly one of -PreflightOnly or -RunPhysical"
)
Assert-R45 (
    (git rev-parse --show-toplevel).Trim().Replace("\", "/") -ceq
        $repoRoot.Replace("\", "/")
) "wrong repository root"
Assert-R45 ((git remote get-url origin).Trim() -ceq $expectedRemote) "wrong origin"
foreach ($path in @($preregistrationPath, $implementationPath)) {
    Assert-R45 (Test-Path -LiteralPath $path -PathType Leaf) "missing declaration: $path"
}

$pythonCandidate = Join-Path $mujocoRoot ".venv\Scripts\python.exe"
$pythonHost = if (
    $Python -ceq "python" -and
    (Test-Path -LiteralPath $pythonCandidate -PathType Leaf)
) { [IO.Path]::GetFullPath($pythonCandidate) } else { Resolve-R45Application $Python }
$powerShellHost = Resolve-R45Application $PowerShell

if ($PreflightOnly) {
    $receipt = Invoke-R45ZeroWorld -PythonHost $pythonHost -CoreLibrary $coreDebugPath
    Write-Host (
        "QSDK_R23D45_ZERO_WORLD_PASS " +
        (($receipt.receipt | ConvertTo-Json -Depth 100 -Compress))
    )
    return
}

Assert-R45 (-not (Test-Path -LiteralPath $closurePath)) (
    "closed R23D45 identity cannot run"
)
$lock = Enter-SporeSporeLocomotionOperationLock -Role physical
Assert-R45 ([bool]$lock.acquired) "another physical or conformance operation owns the lock"
try {
    $source = Get-SporeSporeAttestationSourceIdentity -RepoRoot $repoRoot `
        -RequireCleanPushedLive
    $head = [string]$source.commit
    $evidenceRoot = [IO.Path]::GetFullPath(
        (Join-Path (Split-Path -Parent $repoRoot) "SporeSpore_Evidence")
    )
    $existing = @(
        Get-ChildItem -LiteralPath $evidenceRoot -Directory -Filter (
            "qsdk-r23d45-physical-*"
        ) -ErrorAction SilentlyContinue
    )
    Assert-R45 ($existing.Count -eq 0) (
        "one-shot R23D45 identity is already consumed or in progress"
    )
    $resolvedOutput = if ([string]::IsNullOrWhiteSpace($OutputRoot)) {
        Join-Path $evidenceRoot ("qsdk-r23d45-physical-" + $head.Substring(0, 7))
    } else { [IO.Path]::GetFullPath($OutputRoot) }
    $evidencePrefix = $evidenceRoot.TrimEnd("\", "/") + [IO.Path]::DirectorySeparatorChar
    Assert-R45 (
        $resolvedOutput.StartsWith(
            $evidencePrefix,
            [StringComparison]::OrdinalIgnoreCase
        ) -and -not (Test-Path -LiteralPath $resolvedOutput)
    ) "output must be a new directory under $evidenceRoot"
    [void][IO.Directory]::CreateDirectory($resolvedOutput)

    $coreBuild = Invoke-SporeSporeR23D3PinnedCargo -RepoRoot $repoRoot `
        -SourceCommit $head -TargetRoot (Join-Path $sdkRoot "target") `
        -CargoArguments @(
            "build", "--quiet", "--release", "--locked", "--offline",
            "--manifest-path", (Join-Path $sdkRoot "Cargo.toml"),
            "--package", "sporespore-locomotion-core"
        )
    Assert-R45 (Test-Path -LiteralPath $coreReleasePath -PathType Leaf) (
        "reproducible release core was not materialized"
    )
    $zeroWorld = Invoke-R45ZeroWorld -PythonHost $pythonHost `
        -CoreLibrary $coreReleasePath
    $sourceAfter = Get-SporeSporeAttestationSourceIdentity -RepoRoot $repoRoot `
        -RequireCleanPushedLive
    Assert-R45 (
        [string]$sourceAfter.commit -ceq $head -and
        [string]$sourceAfter.tree_git_oid -ceq [string]$source.tree_git_oid
    ) "source changed during runtime materialization or zero-world gate"

    $sourceBindings = @(Get-R45SourceBindings)
    $token = [Guid]::NewGuid().ToString("N")
    $attemptPath = Join-Path $resolvedOutput "attempt.json"
    $attempt = [ordered]@{
        schema_version = "sporespore_qsdk_r23d45_development_attempt_v1"
        status = "identity_consumed_before_first_world"
        campaign_id = $campaignId
        gate_id = $gateId
        source_commit = $head
        source_tree_git_oid = [string]$source.tree_git_oid
        origin_main_commit = [string]$source.origin_main
        live_github_main_commit = [string]$source.live_github_main
        source_worktree_clean = $true
        source_matches_live_github_main = $true
        source_bindings = $sourceBindings
        preregistration_raw_sha256 = Get-R45Sha256 $preregistrationPath
        implementation_raw_sha256 = Get-R45Sha256 $implementationPath
        core_release_raw_sha256 = Get-R45Sha256 $coreReleasePath
        core_release_byte_length = (Get-Item -LiteralPath $coreReleasePath).Length
        reproducible_runtime_materialization = $coreBuild
        zero_world_preflight_passed = $true
        zero_world_receipt = $zeroWorld.receipt
        global_physical_lock_held = $true
        operation_lock = Get-SporeSporeLocomotionOperationLockPublicReceipt -Receipt $lock
        cell_id = $cellId
        declared_world_count = 1
        authorization_token = $token
        attempt_root = $resolvedOutput
        development_only = $true
        fresh_held_out_condition_consumed = $false
        physical_acceptance_authority = $false
    }
    Write-R45NewJson -Path $attemptPath -Value $attempt

    $cellRoot = Join-Path $resolvedOutput "cell"
    [void][IO.Directory]::CreateDirectory($cellRoot)
    $environment = Get-R45PythonEnvironment -CoreLibrary $coreReleasePath
    $environment["SPORESPORE_QSDK_R23D45_ATTEMPT"] = $attemptPath
    $environment["SPORESPORE_QSDK_R23D45_ATTEMPT_ROOT"] = $resolvedOutput
    $environment["SPORESPORE_QSDK_R23D45_TOKEN"] = $token
    $environment["SPORESPORE_QSDK_R23D45_PYTHON"] = $pythonHost
    $environment["SPORESPORE_QSDK_R23D45_POWERSHELL"] = $powerShellHost

    $authorization = Invoke-R45Process -FileName $pythonHost -Arguments @(
        "-m", $workerModule, "authorization-preflight",
        "--stage", $stageId, "--arm", $armId,
        "--source-commit", $head
    ) -Environment $environment
    Assert-R45 (
        -not [bool]$authorization.timed_out -and
        [int]$authorization.exit_code -eq 0
    ) "positive production authorization preflight failed"
    $authorizationReceipt = Get-R45MarkerJson `
        -Text ([string]$authorization.stdout) `
        -Prefix "QSDK_R23D45_AUTHORIZATION_PREFLIGHT "
    Assert-R45 (
        [bool]$authorizationReceipt.authorization_passed -and
        [string]$authorizationReceipt.source_commit -ceq $head -and
        [string]$authorizationReceipt.cell_id -ceq $cellId -and
        [int]$authorizationReceipt.model_construction_count -eq 0 -and
        [int]$authorizationReceipt.world_attempt_count -eq 0 -and
        [int]$authorizationReceipt.world_build_count -eq 0
    ) "positive production authorization receipt changed"

    $wrongEnvironment = @{}
    foreach ($entry in $environment.GetEnumerator()) {
        $wrongEnvironment[[string]$entry.Key] = [string]$entry.Value
    }
    $wrongEnvironment["SPORESPORE_QSDK_R23D45_TOKEN"] = ("0" * 32)
    $wrongAuthorization = Invoke-R45Process -FileName $pythonHost -Arguments @(
        "-m", $workerModule, "authorization-preflight",
        "--stage", $stageId, "--arm", $armId,
        "--source-commit", $head
    ) -Environment $wrongEnvironment
    Assert-R45 (
        -not [bool]$wrongAuthorization.timed_out -and
        [int]$wrongAuthorization.exit_code -eq 1
    ) "wrong-token authorization preflight was not rejected"
    $wrongReceipt = Get-R45MarkerJson `
        -Text ([string]$wrongAuthorization.stdout) `
        -Prefix "QSDK_R23D45_AUTHORIZATION_FAILURE "
    Assert-R45 (
        -not [bool]$wrongReceipt.authorization_passed -and
        [string]$wrongReceipt.failure_code -ceq
            "QSDK_R23D45_MJC_AUTHORIZATION_INVALID" -and
        [int]$wrongReceipt.model_construction_count -eq 0 -and
        [int]$wrongReceipt.world_attempt_count -eq 0 -and
        [int]$wrongReceipt.world_build_count -eq 0
    ) "wrong-token authorization failure receipt changed"
    $authorizationPath = Join-Path $resolvedOutput "authorization-preflights.json"
    Write-R45NewJson -Path $authorizationPath -Value ([ordered]@{
        schema_version = "sporespore_qsdk_r23d45_authorization_preflights_v1"
        campaign_id = $campaignId
        gate_id = $gateId
        source_commit = $head
        positive = $authorizationReceipt
        wrong_token = $wrongReceipt
        model_construction_count = 0
        world_attempt_count = 0
        world_build_count = 0
        physical_acceptance_authority = $false
    })

    $process = Invoke-R45Process -FileName $pythonHost -Arguments @(
        "-m", $workerModule, "physical",
        "--stage", $stageId, "--arm", $armId,
        "--source-commit", $head
    ) -Environment $environment

    $stdoutPath = Join-Path $cellRoot "stdout.txt"
    $stderrPath = Join-Path $cellRoot "stderr.txt"
    $processPath = Join-Path $cellRoot "process.json"
    Write-R45NewText -Path $stdoutPath -Text ([string]$process.stdout)
    Write-R45NewText -Path $stderrPath -Text ([string]$process.stderr)
    $processPublic = [ordered]@{
        file_name = [string]$process.file_name
        arguments = @($process.arguments)
        started_utc = [string]$process.started_utc
        ended_utc = [string]$process.ended_utc
        duration_seconds = [double]$process.duration_seconds
        exit_code = [int]$process.exit_code
        timed_out = [bool]$process.timed_out
        stdout = [ordered]@{
            path = $stdoutPath
            raw_sha256 = Get-R45Sha256 $stdoutPath
            byte_length = (Get-Item -LiteralPath $stdoutPath).Length
        }
        stderr = [ordered]@{
            path = $stderrPath
            raw_sha256 = Get-R45Sha256 $stderrPath
            byte_length = (Get-Item -LiteralPath $stderrPath).Length
        }
        development_only = $true
        physical_acceptance_authority = $false
    }
    Write-R45NewJson -Path $processPath -Value $processPublic

    Assert-R45 (-not [bool]$process.timed_out) "physical worker timed out"
    $terminal = Get-R45MarkerJson -Text ([string]$process.stdout) `
        -Prefix "QSDK_R23D45_MUJOCO_TERMINAL "
    $terminalPath = Join-Path $cellRoot "terminal.json"
    Write-R45NewJson -Path $terminalPath -Value $terminal
    $classification = if ($terminal.ContainsKey("development_evaluation")) {
        [string]$terminal.development_evaluation.classification
    } else { "invalid_complete_support_loss_conditioned_startup" }
    $completion = [ordered]@{
        schema_version = "sporespore_qsdk_r23d45_development_completion_v1"
        status = "complete_identity_consumed"
        campaign_id = $campaignId
        gate_id = $gateId
        source_commit = $head
        classification = $classification
        process_exit_code = [int]$process.exit_code
        process_timed_out = [bool]$process.timed_out
        world_attempt_count = if ($terminal.ContainsKey("execution")) {
            [int]$terminal.execution.world_attempt_count
        } else { 1 }
        world_build_count = if ($terminal.ContainsKey("execution")) {
            [int]$terminal.execution.world_build_count
        } else { 1 }
        attempt = [ordered]@{
            path = $attemptPath
            raw_sha256 = Get-R45Sha256 $attemptPath
            byte_length = (Get-Item -LiteralPath $attemptPath).Length
        }
        terminal = [ordered]@{
            path = $terminalPath
            raw_sha256 = Get-R45Sha256 $terminalPath
            byte_length = (Get-Item -LiteralPath $terminalPath).Length
        }
        trace_artifact = if ($terminal.ContainsKey("trace_artifact")) {
            $terminal.trace_artifact
        } else { $null }
        development_only = $true
        fresh_held_out_condition_consumed = $false
        turning_tested = $false
        portable_turning = $false
        cross_engine_equivalence = $false
        release_authorized = $false
        physical_acceptance_authority = $false
    }
    $completionPath = Join-Path $resolvedOutput "completion.json"
    Write-R45NewJson -Path $completionPath -Value $completion
    Write-Host (
        "QSDK_R23D45_PHYSICAL_COMPLETE " +
        "classification=$classification worlds=$($completion.world_build_count) " +
        "completion=$completionPath"
    )
    Assert-R45 ([int]$process.exit_code -eq 0) (
        "physical worker failed after retaining its terminal: $($process.stderr)"
    )
} finally {
    Exit-SporeSporeLocomotionOperationLock -Receipt $lock
}
