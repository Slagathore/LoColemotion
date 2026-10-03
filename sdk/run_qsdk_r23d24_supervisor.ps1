#requires -Version 7.0

[CmdletBinding()]
param(
    [switch]$PreflightOnly,
    [switch]$RunPhysical,
    [string]$OutputRoot = "",
    [ValidateRange(300, 3600)][int]$CellTimeoutSeconds = 900
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$sdkRoot = [IO.Path]::GetFullPath($PSScriptRoot)
$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $sdkRoot))
$turningRoot = Join-Path $sdkRoot "turning"
$mujocoRoot = Join-Path $sdkRoot "adapters\mujoco"
$pythonRoot = Join-Path $sdkRoot "python"
$python = Join-Path $mujocoRoot ".venv\Scripts\python.exe"
$preregistrationPath = Join-Path $turningRoot (
    "r23d24_mujoco_receipt_recovery_preregistration_v1.json"
)
$implementationPath = Join-Path $turningRoot (
    "r23d24_mujoco_receipt_recovery_implementation_v1.json"
)
$evaluatorPath = Join-Path $turningRoot (
    "r23d24_mujoco_receipt_recovery_evaluator.py"
)
$closurePath = Join-Path $turningRoot (
    "r23d24_mujoco_receipt_recovery_closure_v1.json"
)
$artifactStorePath = Join-Path $sdkRoot "content_addressed_artifact_store.ps1"
$operationLockPath = Join-Path $sdkRoot "locomotion_operation_lock.ps1"
$runtimeRecipePath = Join-Path $sdkRoot (
    "r23d3_reproducible_runtime_materialization.ps1"
)
$campaignId = "QSDK-R23D24-MUJOCO-FORWARD-RECEIPT-RECOVERY"
$gateId = "QSDK-R23D24"
$stageId = "mujoco_forward_receipt_implementation_recovery"
$armOrder = @("reference_zero", "positive_heading", "negative_heading")
$cellIds = @($armOrder | ForEach-Object {
    "mujoco__tight_gated_horizon__$_"
})

. $artifactStorePath
. $operationLockPath

function Assert-R23D24([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "QSDK-R23D24: $Message" }
}

function Get-R23D24Sha256([string]$Path) {
    return "sha256:" + (
        Get-FileHash -LiteralPath $Path -Algorithm SHA256
    ).Hash.ToLowerInvariant()
}

function Write-R23D24Json([string]$Path, $Value) {
    Assert-R23D24 (-not (Test-Path -LiteralPath $Path)) (
        "refuses to overwrite generated evidence: $Path"
    )
    [IO.File]::WriteAllText(
        $Path,
        ($Value | ConvertTo-Json -Depth 100 -Compress) + "`n",
        [Text.UTF8Encoding]::new($false)
    )
}

function Invoke-R23D24Git([string[]]$Arguments) {
    $output = @(& git -C $repoRoot @Arguments 2>&1)
    Assert-R23D24 ($LASTEXITCODE -eq 0) (
        "Git failed: git $($Arguments -join ' '): $($output -join ' ')"
    )
    return ($output -join "`n").Trim()
}

function Invoke-R23D24Process(
    [string]$FileName,
    [string[]]$Arguments,
    [string]$WorkingDirectory,
    [Collections.IDictionary]$Environment,
    [int]$TimeoutSeconds
) {
    $start = [Diagnostics.ProcessStartInfo]::new()
    $start.FileName = $FileName
    $start.WorkingDirectory = $WorkingDirectory
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    foreach ($entry in $Environment.GetEnumerator()) {
        $start.Environment[[string]$entry.Key] = [string]$entry.Value
    }
    foreach ($argument in $Arguments) { [void]$start.ArgumentList.Add($argument) }
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $start
    $timer = [Diagnostics.Stopwatch]::StartNew()
    Assert-R23D24 $process.Start() "could not start $FileName"
    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()
    $timedOut = $false
    $nextHeartbeat = 30.0
    while (-not $process.WaitForExit(1000)) {
        if ($timer.Elapsed.TotalSeconds -ge $nextHeartbeat) {
            Write-Host (
                "QSDK_R23D24_PROGRESS process=$([IO.Path]::GetFileName($FileName)) " +
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
    $result = [ordered]@{
        exit_code = if ($process.HasExited) { $process.ExitCode } else { -1 }
        timed_out = $timedOut
        duration_seconds = $timer.Elapsed.TotalSeconds
        stdout = $stdoutTask.GetAwaiter().GetResult()
        stderr = $stderrTask.GetAwaiter().GetResult()
    }
    $process.Dispose()
    return $result
}

function Get-R23D24Marker([string]$Text, [string]$Prefix) {
    $matches = @(($Text -split "`r?`n") | Where-Object {
        $_.StartsWith($Prefix, [StringComparison]::Ordinal)
    })
    Assert-R23D24 ($matches.Count -eq 1) (
        "expected exactly one marker: $Prefix; observed $($matches.Count)"
    )
    return $matches[0].Substring($Prefix.Length) |
        ConvertFrom-Json -AsHashtable -Depth 100
}

function Get-R23D24SourceBindings($Implementation) {
    $paths = [Collections.Generic.List[string]]::new()
    foreach ($path in @(
        ".gitattributes",
        "sdk/Cargo.lock",
        "sdk/Cargo.toml",
        "sdk/adapters/mujoco/requirements-lock.txt",
        "sdk/run_qsdk_r23d24_supervisor.ps1",
        "sdk/r23d3_reproducible_runtime_materialization.ps1",
        "tests/test_closure_evidence_provenance_contract.ps1",
        "tests/test_qsdk_r23d24_implementation.ps1"
    )) { $paths.Add($path) }
    foreach ($path in @(
        $Implementation.dependency_closure.required_dependency_paths_by_worker.mujoco
    )) { $paths.Add([string]$path) }
    foreach ($path in @((Invoke-R23D24Git @(
        "ls-files", "--", "sdk/core/src/"
    )) -split "`n")) {
        if (-not [string]::IsNullOrWhiteSpace($path)) { $paths.Add($path) }
    }
    $ordered = @($paths | Sort-Object -Unique)
    Assert-R23D24 ($ordered.Count -eq $paths.Count) (
        "source binding policy contains a duplicate"
    )
    $bindings = [Collections.Generic.List[object]]::new()
    foreach ($relative in $ordered) {
        $absolute = Join-Path $repoRoot $relative
        Assert-R23D24 (Test-Path -LiteralPath $absolute -PathType Leaf) (
            "source binding is missing: $relative"
        )
        $blob = Invoke-R23D24Git @("rev-parse", "HEAD:$relative")
        $rawBlob = Invoke-R23D24Git @(
            "hash-object", "--no-filters", "--", $relative
        )
        Assert-R23D24 ($blob -ceq $rawBlob) (
            "checkout bytes differ from Git blob: $relative"
        )
        $bindings.Add([ordered]@{
            path = $relative
            raw_sha256 = Get-R23D24Sha256 $absolute
            git_blob_oid = $blob
            raw_checkout_equals_git_blob = $true
        })
    }
    return @($bindings)
}

function Publish-R23D24Inputs($Bindings, [string]$Runtime, [string]$PythonHost) {
    $source = [Collections.Generic.List[object]]::new()
    foreach ($binding in @($Bindings)) {
        $source.Add((Publish-SporeSporeContentAddressedArtifact `
            -RepoRoot $repoRoot `
            -ArtifactPath (Join-Path $repoRoot ([string]$binding.path)) `
            -MediaType "application/octet-stream"))
    }
    return [ordered]@{
        source_bindings = @($source)
        locomotion_core = Publish-SporeSporeContentAddressedArtifact `
            -RepoRoot $repoRoot -ArtifactPath $Runtime `
            -MediaType "application/vnd.microsoft.portable-executable"
        mujoco_python_host = Publish-SporeSporeContentAddressedArtifact `
            -RepoRoot $repoRoot -ArtifactPath $PythonHost `
            -MediaType "application/vnd.microsoft.portable-executable"
        physical_acceptance_authority = $false
    }
}

function Invoke-R23D24ZeroWorld {
    $environment = @{
        SPORESPORE_LOCOMOTION_LIBRARY = (
            Join-Path $sdkRoot "target\release\sporespore_locomotion_core.dll"
        )
        PYTHONPATH = (
            $mujocoRoot + [IO.Path]::PathSeparator +
            $pythonRoot + [IO.Path]::PathSeparator + $turningRoot
        )
    }
    $receipts = [Collections.Generic.List[object]]::new()
    foreach ($arm in $armOrder) {
        $result = Invoke-R23D24Process `
            -FileName $python `
            -Arguments @(
                "-m", "sporespore_mujoco_adapter.qsdk_r23d24_physical",
                "preflight", "--stage-id", $stageId, "--arm-id", $arm
            ) `
            -WorkingDirectory $repoRoot `
            -Environment $environment `
            -TimeoutSeconds 120
        Assert-R23D24 (
            -not [bool]$result.timed_out -and [int]$result.exit_code -eq 0
        ) "MuJoCo worker preflight failed: $($result.stderr)"
        $receipts.Add((Get-R23D24Marker `
            -Text ([string]$result.stdout `
            ) -Prefix "QSDK_R23D24_MUJOCO_PREFLIGHT "))
    }
    $cep = Invoke-R23D24Process `
        -FileName "pwsh" `
        -Arguments @(
            "-NoLogo", "-NoProfile", "-File",
            (Join-Path $repoRoot "tests\test_closure_evidence_provenance_contract.ps1")
        ) `
        -WorkingDirectory $repoRoot -Environment @{} -TimeoutSeconds 120
    Assert-R23D24 (
        -not [bool]$cep.timed_out -and
        [int]$cep.exit_code -eq 0 -and
        ([string]$cep.stdout).Contains(
            "CLOSURE_EVIDENCE_PROVENANCE_CONTRACT_PASS"
        )
    ) "CEP1 failed"
    return [ordered]@{
        schema_version = "sporespore_qsdk_r23d24_zero_world_receipt_v1"
        campaign_id = $campaignId
        gate_id = $gateId
        worker_receipts = @($receipts)
        worker_preflight_count = $receipts.Count
        receipt_mutation_control_count = 22
        closure_evidence_provenance_pass_count = 1
        model_construction_count = 0
        world_attempt_count = 0
        world_build_count = 0
        physical_execution_authorized = $false
        physical_acceptance_authority = $false
    }
}

function Invoke-R23D24Cell(
    [string]$Arm,
    [string]$SourceCommit,
    [string]$FreezePath,
    [string]$AttemptPath,
    [string]$Token,
    [string]$AttemptRoot,
    [string]$Runtime,
    [string]$CellRoot
) {
    [void][IO.Directory]::CreateDirectory($CellRoot)
    $environment = @{
        SPORESPORE_LOCOMOTION_LIBRARY = $Runtime
        PYTHONPATH = (
            $mujocoRoot + [IO.Path]::PathSeparator +
            $pythonRoot + [IO.Path]::PathSeparator + $turningRoot
        )
        SPORESPORE_QSDK_R23D24_FREEZE = $FreezePath
        SPORESPORE_QSDK_R23D24_ATTEMPT = $AttemptPath
        SPORESPORE_QSDK_R23D24_TOKEN = $Token
        SPORESPORE_QSDK_R23D24_STAGE = $stageId
        SPORESPORE_QSDK_R23D24_CELL = "mujoco__tight_gated_horizon__$Arm"
        SPORESPORE_QSDK_R23D24_ENGINE = "mujoco"
        SPORESPORE_QSDK_R23D24_ATTEMPT_ROOT = $AttemptRoot
        SPORESPORE_QSDK_R23D24_POWERSHELL = (Get-Command pwsh).Source
    }
    $result = Invoke-R23D24Process `
        -FileName $python `
        -Arguments @(
            "-m", "sporespore_mujoco_adapter.qsdk_r23d24_physical",
            "physical", "--stage-id", $stageId, "--arm-id", $Arm,
            "--source-commit", $SourceCommit
        ) `
        -WorkingDirectory $repoRoot `
        -Environment $environment `
        -TimeoutSeconds $CellTimeoutSeconds
    $stdoutPath = Join-Path $CellRoot "stdout.txt"
    $stderrPath = Join-Path $CellRoot "stderr.txt"
    [IO.File]::WriteAllText($stdoutPath, [string]$result.stdout, [Text.UTF8Encoding]::new($false))
    [IO.File]::WriteAllText($stderrPath, [string]$result.stderr, [Text.UTF8Encoding]::new($false))
    $processPath = Join-Path $CellRoot "process.json"
    Write-R23D24Json $processPath ([ordered]@{
        schema_version = "sporespore_qsdk_r23d24_process_receipt_v1"
        cell_id = "mujoco__tight_gated_horizon__$Arm"
        exit_code = [int]$result.exit_code
        timed_out = [bool]$result.timed_out
        duration_seconds = [double]$result.duration_seconds
    })
    $stdoutCas = Publish-SporeSporeContentAddressedArtifact `
        -RepoRoot $repoRoot -ArtifactPath $stdoutPath -MediaType "text/plain"
    $stderrCas = Publish-SporeSporeContentAddressedArtifact `
        -RepoRoot $repoRoot -ArtifactPath $stderrPath -MediaType "text/plain"
    $processCas = Publish-SporeSporeContentAddressedArtifact `
        -RepoRoot $repoRoot -ArtifactPath $processPath -MediaType "application/json"
    Assert-R23D24 (-not [bool]$result.timed_out) (
        "cell timed out after retained process output: $Arm"
    )
    $terminal = Get-R23D24Marker `
        -Text ([string]$result.stdout) -Prefix "QSDK_R23D24_TERMINAL "
    $terminalPath = Join-Path $CellRoot "terminal.json"
    Write-R23D24Json $terminalPath $terminal
    $terminalCas = Publish-SporeSporeContentAddressedArtifact `
        -RepoRoot $repoRoot -ArtifactPath $terminalPath -MediaType "application/json"
    return [ordered]@{
        cell_id = "mujoco__tight_gated_horizon__$Arm"
        arm_id = $Arm
        process_exit_code = [int]$result.exit_code
        stdout_cas = $stdoutCas
        stderr_cas = $stderrCas
        process_cas = $processCas
        terminal_entry_cas = $terminalCas
    }
}

Assert-R23D24 (
    @($PreflightOnly, $RunPhysical | Where-Object { $_ }).Count -eq 1
) "specify exactly one of -PreflightOnly or -RunPhysical"
Assert-R23D24 (
    (Invoke-R23D24Git @("rev-parse", "--show-toplevel")).Replace("/", "\") -ceq
        $repoRoot -and
    (Invoke-R23D24Git @("remote", "get-url", "origin")) -ceq
        "https://github.com/Slagathore/sporespore.git"
) "repository identity changed"
foreach ($path in @(
    $python, $preregistrationPath, $implementationPath, $evaluatorPath,
    $artifactStorePath, $operationLockPath, $runtimeRecipePath
)) { Assert-R23D24 (Test-Path -LiteralPath $path -PathType Leaf) "missing input: $path" }
if ($RunPhysical -and (Test-Path -LiteralPath $closurePath -PathType Leaf)) {
    Write-Host (
        'QSDK_R23D24_PHYSICAL_REFUSAL ' +
        (@{
            schema_version = "sporespore_qsdk_r23d24_physical_refusal_v1"
            campaign_id = $campaignId
            gate_id = $gateId
            reason = "r23d24_identity_closed"
            physical_process_launch_count = 0
            world_attempt_count = 0
            world_build_count = 0
            physical_acceptance_authority = $false
        } | ConvertTo-Json -Depth 10 -Compress)
    )
    return
}

$implementation = Get-Content -Raw -LiteralPath $implementationPath |
    ConvertFrom-Json -AsHashtable -Depth 100
$zeroWorld = Invoke-R23D24ZeroWorld
if ($PreflightOnly) {
    Write-Host (
        "QSDK_R23D24_ZERO_WORLD_PASS workers=3 mutations=22 models=0 worlds=0 " +
        "physical=False"
    )
    return
}

$sourceCommit = Invoke-R23D24Git @("rev-parse", "HEAD")
$originCommit = Invoke-R23D24Git @("rev-parse", "origin/main")
$liveCommit = ((Invoke-R23D24Git @(
    "ls-remote", "origin", "refs/heads/main"
)) -split "\s+")[0]
Assert-R23D24 (
    [string](Invoke-R23D24Git @(
        "status", "--porcelain=v1", "--untracked-files=all"
    )) -ceq "" -and
    $sourceCommit -ceq $originCommit -and $sourceCommit -ceq $liveCommit
) "physical source must be clean, pushed, and equal to live main"

$evidenceRoot = Get-SporeSporeArtifactEvidenceRoot -RepoRoot $repoRoot
$prior = @()
if (Test-Path -LiteralPath $evidenceRoot -PathType Container) {
    $prior = @(Get-ChildItem -LiteralPath $evidenceRoot -Directory |
        Where-Object {
            $_.Name -like "qsdk-r23d24-*" -and
            (Test-Path -LiteralPath (Join-Path $_.FullName "attempt.json"))
        })
}
Assert-R23D24 ($prior.Count -eq 0) "one-shot identity was already consumed"
$resolvedOutput = if ([string]::IsNullOrWhiteSpace($OutputRoot)) {
    Join-Path $evidenceRoot (
        "qsdk-r23d24-" + [DateTime]::UtcNow.ToString("yyyyMMddTHHmmssZ")
    )
} else { [IO.Path]::GetFullPath($OutputRoot) }
Assert-R23D24 (
    $resolvedOutput.StartsWith(
        $evidenceRoot.TrimEnd("\", "/") + "\",
        [StringComparison]::OrdinalIgnoreCase
    ) -and -not (Test-Path -LiteralPath $resolvedOutput)
) "output must be a new directory within the durable evidence root"

$lock = Enter-SporeSporeLocomotionOperationLock -Role physical
Assert-R23D24 ([bool]$lock.acquired) "global locomotion operation lock is held"
$attemptConsumed = $false
[void][IO.Directory]::CreateDirectory($resolvedOutput)
try {
    . $runtimeRecipePath
    $runtimeTarget = Join-Path $sdkRoot "target\qsdk-r23d24-runtime"
    $build = Invoke-SporeSporeR23D3PinnedCargo `
        -RepoRoot $repoRoot `
        -SourceCommit $sourceCommit `
        -TargetRoot $runtimeTarget `
        -CargoArguments @(
            "build", "--quiet", "--release", "--locked", "--offline",
            "--manifest-path", (Join-Path $sdkRoot "Cargo.toml"),
            "--package", "sporespore-locomotion-core"
        )
    $runtime = Join-Path $runtimeTarget "release\sporespore_locomotion_core.dll"
    Assert-R23D24 (Test-Path -LiteralPath $runtime -PathType Leaf) (
        "reproducible runtime materialization did not produce the DLL"
    )
    $bindings = @(Get-R23D24SourceBindings $implementation)
    $inputs = Publish-R23D24Inputs $bindings $runtime $python
    $freeze = [ordered]@{
        schema_version = "sporespore_qsdk_r23d24_physical_freeze_v1"
        status = "frozen_supervisor_only_physical_authorized"
        campaign_id = $campaignId
        gate_id = $gateId
        preregistration_raw_sha256 = Get-R23D24Sha256 $preregistrationPath
        implementation_contract_raw_sha256 = Get-R23D24Sha256 $implementationPath
        source_commit = $sourceCommit
        source_tree_git_oid = Invoke-R23D24Git @("rev-parse", "HEAD^{tree}")
        source_bindings = $bindings
        runtime_artifact = [ordered]@{
            path = $runtime
            raw_sha256 = Get-R23D24Sha256 $runtime
            build = $build
        }
        content_addressed_inputs = $inputs
        zero_world_receipt = $zeroWorld
        declared_matrix_world_count = 3
        ordered_matrix_cell_ids = $cellIds
        serial_execution_required = $true
        source_checkout_bytes_equal_git_blobs = $true
        physical_execution_authorized = $true
        physical_acceptance_authority = $false
    }
    $freezePath = Join-Path $resolvedOutput "physical-freeze.json"
    Write-R23D24Json $freezePath $freeze
    $freezeCas = Publish-SporeSporeContentAddressedArtifact `
        -RepoRoot $repoRoot -ArtifactPath $freezePath -MediaType "application/json"
    $attemptId = [guid]::NewGuid().ToString("N")
    $token = [guid]::NewGuid().ToString("N")
    $attempt = [ordered]@{
        schema_version = "sporespore_qsdk_r23d24_attempt_v1"
        campaign_id = $campaignId
        gate_id = $gateId
        attempt_id = $attemptId
        source_commit = $sourceCommit
        freeze_raw_sha256 = [string]$freezeCas.sha256
        authorization_token = $token
        attempt_root = $resolvedOutput
        ordered_matrix_cell_ids = $cellIds
        single_use_supervisor_authorization = $true
        source_worktree_clean = $true
        source_matches_live_github_main = $true
        content_addressed_inputs_retained = $true
        one_shot_attempt_unconsumed = $true
        physical_execution_authorized = $true
        physical_acceptance_authority = $false
    }
    $attemptPath = Join-Path $resolvedOutput "attempt.json"
    Write-R23D24Json $attemptPath $attempt
    $attemptCas = Publish-SporeSporeContentAddressedArtifact `
        -RepoRoot $repoRoot -ArtifactPath $attemptPath -MediaType "application/json"
    $attemptConsumed = $true
    $cells = [Collections.Generic.List[object]]::new()
    foreach ($arm in $armOrder) {
        $cells.Add((Invoke-R23D24Cell `
            -Arm $arm -SourceCommit $sourceCommit `
            -FreezePath ([string]$freezeCas.payload_path) `
            -AttemptPath ([string]$attemptCas.payload_path) `
            -Token $token -AttemptRoot $resolvedOutput -Runtime $runtime `
            -CellRoot (Join-Path $resolvedOutput (
                "matrix\mujoco__tight_gated_horizon__$arm"
            ))))
    }
    $terminalPaths = @($cells | ForEach-Object {
        [string]$_.terminal_entry_cas.payload_path
    })
    $manifestPath = Join-Path $resolvedOutput "terminal-paths.json"
    Write-R23D24Json $manifestPath $terminalPaths
    $manifestCas = Publish-SporeSporeContentAddressedArtifact `
        -RepoRoot $repoRoot -ArtifactPath $manifestPath -MediaType "application/json"
    $evaluationProcess = Invoke-R23D24Process `
        -FileName $python `
        -Arguments @(
            $evaluatorPath, "evaluate-complete", "--manifest",
            [string]$manifestCas.payload_path, "--expected-source-commit", $sourceCommit
        ) `
        -WorkingDirectory $repoRoot `
        -Environment @{ PYTHONPATH = $turningRoot } `
        -TimeoutSeconds 180
    Assert-R23D24 (
        -not [bool]$evaluationProcess.timed_out -and
        [int]$evaluationProcess.exit_code -eq 0
    ) "complete evaluator failed: $($evaluationProcess.stderr)"
    $evaluation = Get-R23D24Marker `
        -Text ([string]$evaluationProcess.stdout) `
        -Prefix "QSDK_R23D24_COMPLETE_EVALUATION "
    $classification = [string]$evaluation.classification
    $report = [ordered]@{
        schema_version = "sporespore_qsdk_r23d24_campaign_report_v1"
        campaign_id = $campaignId
        gate_id = $gateId
        source_commit = $sourceCommit
        attempt_id = $attemptId
        freeze_cas = $freezeCas
        attempt_cas = $attemptCas
        manifest_cas = $manifestCas
        ordered_matrix_cells = @($cells)
        complete_evaluation = $evaluation
        result_classification = $classification
        claims = [ordered]@{
            finite_mujoco_turning_candidate = (
                $classification -ceq "valid_complete_positive"
            )
            finite_three_engine_turning_candidate = $false
            cross_engine_equivalence = $false
            release_authorized = $false
            physical_acceptance_authority = $false
        }
    }
    $reportPath = Join-Path $resolvedOutput "report.json"
    Write-R23D24Json $reportPath $report
    $reportCas = Publish-SporeSporeContentAddressedArtifact `
        -RepoRoot $repoRoot -ArtifactPath $reportPath -MediaType "application/json"
    $completionPath = Join-Path $resolvedOutput "completion.json"
    $completion = [ordered]@{
        schema_version = "sporespore_qsdk_r23d24_completion_v1"
        campaign_id = $campaignId
        gate_id = $gateId
        status = "$classification`_first_attempt"
        source_commit = $sourceCommit
        attempt_id = $attemptId
        terminal_entry_count = $cells.Count
        result_classification = $classification
        report_cas = $reportCas
        one_shot_identity_consumed = $true
        same_identity_rerun_allowed = $false
        finite_three_engine_turning_candidate = $false
        cross_engine_equivalence = $false
        release_authorized = $false
        physical_acceptance_authority = $false
    }
    Write-R23D24Json $completionPath $completion
    $completionCas = Publish-SporeSporeContentAddressedArtifact `
        -RepoRoot $repoRoot -ArtifactPath $completionPath -MediaType "application/json"
    Write-Host (
        "QSDK_R23D24_PHYSICAL_COMPLETE classification=$classification cells=3 " +
        "report_sha256=$([string]$reportCas.sha256) " +
        "completion_sha256=$([string]$completionCas.sha256) " +
        "three_engine=False equivalence=False release=False"
    )
} catch {
    if ($attemptConsumed -and -not (Test-Path -LiteralPath (
        Join-Path $resolvedOutput "completion.json"
    ))) {
        $emergency = [ordered]@{
            schema_version = "sporespore_qsdk_r23d24_completion_v1"
            campaign_id = $campaignId
            gate_id = $gateId
            status = "invalid_or_incomplete_first_attempt"
            source_commit = $sourceCommit
            one_shot_identity_consumed = $true
            same_identity_rerun_allowed = $false
            failure = $_.Exception.Message
            physical_acceptance_authority = $false
        }
        Write-R23D24Json (Join-Path $resolvedOutput "completion.json") $emergency
    }
    throw
} finally {
    Exit-SporeSporeLocomotionOperationLock -Receipt $lock
}
