#requires -Version 7.0

[CmdletBinding()]
param(
    [switch]$PreflightOnly,
    [switch]$RunPhysical,
    [string]$FullConformanceAttestation = "",
    [string]$OutputRoot = "",
    [string]$Godot = (
        "C:\Users\Cole\CodeStuff\Misc\Godot\" +
        "Godot_v4.7-stable_mono_win64_console.exe"
    ),
    [ValidateRange(300, 1800)][int]$CellTimeoutSeconds = 600
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$sdkRoot = [IO.Path]::GetFullPath($PSScriptRoot)
$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $sdkRoot))
$contractPath = Join-Path $sdkRoot "turning\physical_development_contract_v1.json"
$freezePath = Join-Path $sdkRoot "turning\physical_development_freeze_v1.json"
$closurePath = Join-Path $sdkRoot "turning\physical_development_closure_v1.json"
$evaluatorPath = Join-Path $sdkRoot "turning\physical_development.py"
$designGatePath = Join-Path $sdkRoot "run_qsdk_r23d1_physical_development_preflight.ps1"
$godotGatePath = Join-Path $sdkRoot "run_qsdk_r23d1_godot_jolt_worker_preflight.ps1"
$rapierGatePath = Join-Path $sdkRoot "run_qsdk_r23d1_rapier_worker_preflight.ps1"
$mujocoGatePath = Join-Path $sdkRoot "run_qsdk_r23d1_mujoco_worker_preflight.ps1"
$artifactStorePath = Join-Path $sdkRoot "content_addressed_artifact_store.ps1"
$operationLockPath = Join-Path $sdkRoot "locomotion_operation_lock.ps1"
$attestationVerifierPath = Join-Path $sdkRoot "locomotion_full_conformance_attestation.ps1"
$attestationClosurePath = Join-Path $sdkRoot (
    "locomotion_full_conformance_attestation_v2_closure.json"
)
$godotWorkerResource = "res://tests/test_sdk_qsdk_r23d1_godot_jolt_worker.gd"
$rapierBinaryPath = Join-Path $sdkRoot "target\debug\qsdk_r23d1_heading_response.exe"
$mujocoRoot = Join-Path $sdkRoot "adapters\mujoco"
$mujocoPython = Join-Path $mujocoRoot ".venv\Scripts\python.exe"
$pythonCoreRoot = Join-Path $sdkRoot "python"
$coreLibraryPath = Join-Path $sdkRoot "target\release\sporespore_locomotion_core.dll"
$campaignId = "QSDK-R23D1-THREE-ENGINE-HEADING-RESPONSE-DEVELOPMENT"
$gateId = "QSDK-R23D1"
$attemptEnvironmentNames = @(
    "SPORESPORE_QSDK_R23D1_ATTEMPT",
    "SPORESPORE_QSDK_R23D1_TOKEN",
    "SPORESPORE_QSDK_R23D1_CELL",
    "SPORESPORE_QSDK_R23D1_ENGINE"
)
$engineOrder = @("godot_jolt", "rapier_parry", "mujoco")
$armOrder = @("reference_zero", "positive_heading", "negative_heading")
$orderedCellIds = @(
    foreach ($engineId in $engineOrder) {
        foreach ($armId in $armOrder) { "$engineId`__$armId" }
    }
)

. $artifactStorePath
. $operationLockPath
. $attestationVerifierPath

function Assert-R23D1Exact {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function Get-R23D1RawSha256 {
    param([Parameter(Mandatory)][string]$Path)
    return "sha256:" + (
        Get-FileHash -LiteralPath $Path -Algorithm SHA256
    ).Hash.ToLowerInvariant()
}

function Write-R23D1NewJson {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)]$Value
    )
    Assert-R23D1Exact (-not (Test-Path -LiteralPath $Path)) (
        "QSDK-R23D1 refuses to overwrite retained bytes: $Path"
    )
    [IO.File]::WriteAllText(
        $Path,
        ($Value | ConvertTo-Json -Depth 100) + [Environment]::NewLine,
        [Text.UTF8Encoding]::new($false)
    )
}

function Invoke-R23D1Git {
    param([Parameter(Mandatory)][string[]]$Arguments)
    $output = @(& git -C $repoRoot @Arguments 2>&1)
    if ($LASTEXITCODE -ne 0) {
        throw "QSDK-R23D1 git failed: git $($Arguments -join ' '): $($output -join ' ')"
    }
    return ($output -join "`n").Trim()
}

function Invoke-R23D1Process {
    param(
        [Parameter(Mandatory)][string]$FileName,
        [Parameter(Mandatory)][string[]]$Arguments,
        [Parameter(Mandatory)][string]$WorkingDirectory,
        [Collections.IDictionary]$Environment = @{},
        [int]$TimeoutSeconds = 600
    )
    $start = [Diagnostics.ProcessStartInfo]::new()
    $start.FileName = $FileName
    $start.WorkingDirectory = $WorkingDirectory
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    foreach ($name in $attemptEnvironmentNames) {
        [void]$start.Environment.Remove($name)
    }
    foreach ($entry in $Environment.GetEnumerator()) {
        $start.Environment[[string]$entry.Key] = [string]$entry.Value
    }
    foreach ($argument in $Arguments) { [void]$start.ArgumentList.Add($argument) }
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $start
    $timer = [Diagnostics.Stopwatch]::StartNew()
    Assert-R23D1Exact $process.Start() "QSDK-R23D1 failed to start $FileName"
    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()
    $timedOut = $false
    $nextHeartbeat = 30.0
    while (-not $process.WaitForExit(1000)) {
        if ($timer.Elapsed.TotalSeconds -ge $nextHeartbeat) {
            Write-Host (
                "QSDK_R23D1_PROGRESS process=$([IO.Path]::GetFileName($FileName)) " +
                "elapsed_seconds=$($timer.Elapsed.TotalSeconds.ToString('F1', [Globalization.CultureInfo]::InvariantCulture))"
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

function Get-R23D1Marker {
    param(
        [Parameter(Mandatory)][string]$Text,
        [Parameter(Mandatory)][string]$Prefix
    )
    $lines = @($Text -split "`r?`n" | Where-Object {
        $_.StartsWith($Prefix, [StringComparison]::Ordinal)
    })
    Assert-R23D1Exact ($lines.Count -eq 1) (
        "QSDK-R23D1 expected one '$Prefix' marker, observed $($lines.Count)"
    )
    return $lines[0].Substring($Prefix.Length) |
        ConvertFrom-Json -AsHashtable -Depth 100
}

function Get-R23D1ContractAndFreeze {
    foreach ($path in @(
        $contractPath, $freezePath, $evaluatorPath, $designGatePath,
        $godotGatePath, $rapierGatePath, $mujocoGatePath,
        $artifactStorePath, $operationLockPath, $attestationVerifierPath
    )) {
        Assert-R23D1Exact (Test-Path -LiteralPath $path -PathType Leaf) (
            "QSDK-R23D1 supervisor input missing: $path"
        )
    }
    Assert-R23D1Exact (
        (Invoke-R23D1Git @("rev-parse", "--show-toplevel")).Replace("/", "\") -ceq
            $repoRoot -and
        (Invoke-R23D1Git @("remote", "get-url", "origin")) -ceq
            "https://github.com/Slagathore/sporespore.git"
    ) "QSDK-R23D1 supervisor repository identity mismatch"
    $contract = Get-Content -Raw -LiteralPath $contractPath |
        ConvertFrom-Json -AsHashtable -Depth 100
    $freeze = Get-Content -Raw -LiteralPath $freezePath |
        ConvertFrom-Json -AsHashtable -Depth 100
    Assert-R23D1Exact (
        [string]$contract.schema_version -ceq
            "sporespore_qsdk_r23d1_physical_development_contract_v1" -and
        [string]$contract.campaign_id -ceq $campaignId -and
        [string]$contract.gate_id -ceq $gateId -and
        [string]$contract.aggregate_supervisor.supervisor_path -ceq
            "sdk/run_qsdk_r23d1_supervisor.ps1" -and
        [string]$contract.aggregate_supervisor.freeze_path -ceq
            "sdk/turning/physical_development_freeze_v1.json" -and
        [bool]$contract.aggregate_supervisor.serial_one_shot_required -and
        [bool]$contract.aggregate_supervisor.content_addressed_retention_before_consumption_required -and
        -not [bool]$contract.authorization.q_sdk_r23_satisfied
    ) "QSDK-R23D1 supervisor contract identity changed"
    $physicalAuthorized = [bool]$contract.authorization.physical_execution_authorized
    $expectedFreezeStatus = if ($physicalAuthorized) {
        "frozen_physical_authorized"
    } else { "frozen_zero_world_supervisor_physical_unauthorized" }
    Assert-R23D1Exact (
        [string]$freeze.schema_version -ceq
            "sporespore_qsdk_r23d1_supervisor_freeze_v1" -and
        [string]$freeze.status -ceq $expectedFreezeStatus -and
        [string]$freeze.campaign_id -ceq $campaignId -and
        [string]$freeze.gate_id -ceq $gateId -and
        [string]$freeze.contract_raw_sha256 -ceq
            (Get-R23D1RawSha256 $contractPath) -and
        [int]$freeze.declared_cell_count -eq 9 -and
        (@($freeze.ordered_cell_ids) -join "|") -ceq
            ($orderedCellIds -join "|") -and
        @($freeze.source_bindings).Count -ge 18 -and
        [bool]$freeze.physical_execution_authorized -eq $physicalAuthorized -and
        -not [bool]$freeze.physical_acceptance_authority
    ) "QSDK-R23D1 supervisor freeze identity changed"
    foreach ($binding in @($freeze.source_bindings)) {
        $path = Join-Path $repoRoot ([string]$binding.path)
        Assert-R23D1Exact (
            (Test-Path -LiteralPath $path -PathType Leaf) -and
            [string]$binding.raw_sha256 -ceq (Get-R23D1RawSha256 $path)
        ) "QSDK-R23D1 source binding changed: $([string]$binding.path)"
    }
    foreach ($runtime in @($freeze.external_runtime_bindings)) {
        $path = [IO.Path]::GetFullPath([string]$runtime.path)
        Assert-R23D1Exact (
            (Test-Path -LiteralPath $path -PathType Leaf) -and
            [string]$runtime.raw_sha256 -ceq (Get-R23D1RawSha256 $path)
        ) "QSDK-R23D1 external runtime binding changed: $path"
    }
    return [ordered]@{ contract = $contract; freeze = $freeze }
}

function Invoke-R23D1WorkerBundle {
    param(
        [Parameter(Mandatory)][string]$EngineId,
        [Parameter(Mandatory)][string]$ScriptPath,
        [Parameter(Mandatory)][string]$Prefix,
        [Parameter(Mandatory)][bool]$PhysicalAuthorized
    )
    $arguments = @("-NoLogo", "-NoProfile", "-File", $ScriptPath, "-EmitBundle")
    if ($EngineId -ceq "godot_jolt") { $arguments += @("-Godot", $Godot) }
    $result = Invoke-R23D1Process `
        -FileName "pwsh" `
        -Arguments $arguments `
        -WorkingDirectory $repoRoot `
        -TimeoutSeconds 180
    Assert-R23D1Exact (-not $result.timed_out -and $result.exit_code -eq 0) (
        "QSDK-R23D1 worker bundle failed for $EngineId`: $($result.stderr)"
    )
    $bundle = Get-R23D1Marker -Text $result.stdout -Prefix $Prefix
    Assert-R23D1Exact (
        [string]$bundle.schema_version -ceq
            "sporespore_qsdk_r23d1_worker_bundle_v1" -and
        [string]$bundle.campaign_id -ceq $campaignId -and
        [string]$bundle.engine_id -ceq $EngineId -and
        (@($bundle.ordered_arm_ids) -join "|") -ceq ($armOrder -join "|") -and
        @($bundle.ordered_production_reports).Count -eq 3 -and
        [int]$bundle.production_evaluator_pass_count -eq 3 -and
        [int]$bundle.negative_control_rejection_count -eq 2 -and
        [int]$bundle.world_build_count -eq 0 -and
        [bool]$bundle.physical_execution_authorized -eq $PhysicalAuthorized -and
        -not [bool]$bundle.physical_acceptance_authority
    ) "QSDK-R23D1 worker bundle identity changed for $EngineId"
    return $bundle
}

function Invoke-R23D1AggregateEvaluator {
    param([Parameter(Mandatory)][string[]]$ReportPaths)
    $result = Invoke-R23D1Process `
        -FileName "python" `
        -Arguments (@($evaluatorPath, "evaluate-aggregate") + $ReportPaths) `
        -WorkingDirectory $repoRoot `
        -TimeoutSeconds 60
    $evaluation = Get-R23D1Marker `
        -Text $result.stdout `
        -Prefix "QSDK_R23D1_AGGREGATE_EVALUATION "
    return [ordered]@{ process = $result; evaluation = $evaluation }
}

function Invoke-R23D1SupervisorPreflight {
    param([Parameter(Mandatory)]$Bindings)
    $design = Invoke-R23D1Process `
        -FileName "pwsh" `
        -Arguments @("-NoLogo", "-NoProfile", "-File", $designGatePath) `
        -WorkingDirectory $repoRoot `
        -TimeoutSeconds 60
    Assert-R23D1Exact (
        -not $design.timed_out -and $design.exit_code -eq 0 -and
        $design.stdout.Contains("QSDK_R23D1_DESIGN_PASS")
    ) "QSDK-R23D1 shared design gate failed under supervisor"
    $bundleSpecs = @(
        @{
            engine = "godot_jolt"; path = $godotGatePath
            prefix = "QSDK_R23D1_GODOT_JOLT_WORKER_BUNDLE "
        },
        @{
            engine = "rapier_parry"; path = $rapierGatePath
            prefix = "QSDK_R23D1_RAPIER_WORKER_BUNDLE "
        },
        @{
            engine = "mujoco"; path = $mujocoGatePath
            prefix = "QSDK_R23D1_MUJOCO_WORKER_BUNDLE "
        }
    )
    $runRoot = Join-Path $sdkRoot (
        "target\qsdk-r23d1-supervisor-preflight\" +
        [guid]::NewGuid().ToString("N")
    )
    $casRoot = Join-Path $runRoot "cas"
    [void][IO.Directory]::CreateDirectory($runRoot)
    $bundles = [Collections.Generic.List[object]]::new()
    $reportCas = [Collections.Generic.List[object]]::new()
    foreach ($spec in $bundleSpecs) {
        $bundle = Invoke-R23D1WorkerBundle `
            -EngineId $spec.engine `
            -ScriptPath $spec.path `
            -Prefix $spec.prefix `
            -PhysicalAuthorized ([bool]$Bindings.contract.authorization.physical_execution_authorized)
        $bundlePath = Join-Path $runRoot "$($spec.engine)-bundle.json"
        Write-R23D1NewJson -Path $bundlePath -Value $bundle
        $bundleStored = Publish-SporeSporeContentAddressedArtifact `
            -RepoRoot $repoRoot `
            -ArtifactPath $bundlePath `
            -MediaType "application/json" `
            -EvidenceRootOverride $casRoot `
            -TestOnly
        Assert-R23D1Exact (
            Test-SporeSporeStoredArtifact `
                -Directory (Split-Path -Parent $bundleStored.payload_path) `
                -ExpectedSha256 ([string]$bundleStored.sha256).Replace("sha256:", "") `
                -ExpectedByteLength ([long]$bundleStored.byte_length)
        ) "QSDK-R23D1 bundle CAS verification failed: $($spec.engine)"
        $retainedBundle = Get-Content -Raw -LiteralPath $bundleStored.payload_path |
            ConvertFrom-Json -AsHashtable -Depth 100
        $bundles.Add($retainedBundle)
        foreach ($report in @($retainedBundle.ordered_production_reports)) {
            $cellId = [string]$report.cell_id
            $reportPath = Join-Path $runRoot "$cellId-report.json"
            Write-R23D1NewJson -Path $reportPath -Value $report
            $stored = Publish-SporeSporeContentAddressedArtifact `
                -RepoRoot $repoRoot `
                -ArtifactPath $reportPath `
                -MediaType "application/json" `
                -EvidenceRootOverride $casRoot `
                -TestOnly
            $reportCas.Add($stored)
        }
    }
    $actualIds = @($reportCas | ForEach-Object {
        $value = Get-Content -Raw -LiteralPath $_.payload_path |
            ConvertFrom-Json -AsHashtable -Depth 100
        [string]$value.cell_id
    })
    Assert-R23D1Exact (
        $reportCas.Count -eq 9 -and
        ($actualIds -join "|") -ceq ($orderedCellIds -join "|")
    ) "QSDK-R23D1 CAS report order or completeness changed"
    $aggregate = Invoke-R23D1AggregateEvaluator `
        -ReportPaths @($reportCas | ForEach-Object { [string]$_.payload_path })
    Assert-R23D1Exact (
        -not [bool]$aggregate.process.timed_out -and
        [int]$aggregate.process.exit_code -eq 0 -and
        [bool]$aggregate.evaluation.development_screen_passed -and
        [int]$aggregate.evaluation.report_count -eq 9 -and
        [int]$aggregate.evaluation.world_build_count -eq 0 -and
        -not [bool]$aggregate.evaluation.q_sdk_r23_satisfied -and
        -not [bool]$aggregate.evaluation.cross_engine_equivalence -and
        -not [bool]$aggregate.evaluation.physical_acceptance_authority
    ) "QSDK-R23D1 retained aggregate projection failed"
    $paths = @($reportCas | ForEach-Object { [string]$_.payload_path })
    $missing = Invoke-R23D1AggregateEvaluator -ReportPaths $paths[0..7]
    $swappedPaths = @($paths)
    ($swappedPaths[0], $swappedPaths[1]) = ($swappedPaths[1], $swappedPaths[0])
    $swapped = Invoke-R23D1AggregateEvaluator -ReportPaths $swappedPaths
    $tampered = Get-Content -Raw -LiteralPath $paths[0] |
        ConvertFrom-Json -AsHashtable -Depth 100
    $tampered.command_validation.legacy_command_parity_waived_step_count = 1
    $tamperedPath = Join-Path $runRoot "tampered-report.json"
    Write-R23D1NewJson -Path $tamperedPath -Value $tampered
    $tamperedPaths = @($paths)
    $tamperedPaths[0] = $tamperedPath
    $tamperedAggregate = Invoke-R23D1AggregateEvaluator -ReportPaths $tamperedPaths
    Assert-R23D1Exact (
        [int]$missing.process.exit_code -ne 0 -and
        -not [bool]$missing.evaluation.development_screen_passed -and
        [int]$swapped.process.exit_code -ne 0 -and
        -not [bool]$swapped.evaluation.development_screen_passed -and
        [int]$tamperedAggregate.process.exit_code -ne 0 -and
        -not [bool]$tamperedAggregate.evaluation.development_screen_passed
    ) "QSDK-R23D1 aggregate negative controls did not fail closed"
    $testMutexName = "Global\SporeSpore.Locomotion.Test.R23D1Supervisor"
    $testLock = Enter-SporeSporeLocomotionOperationLock `
        -Role physical -MutexName $testMutexName -TestOnly
    Assert-R23D1Exact ([bool]$testLock.acquired) (
        "QSDK-R23D1 could not exercise the physical operation-lock path"
    )
    Exit-SporeSporeLocomotionOperationLock $testLock
    $closure = Get-Content -Raw -LiteralPath $attestationClosurePath |
        ConvertFrom-Json -AsHashtable -Depth 100
    $staleAttestation = Test-SporeSporeFullConformanceAttestationFile `
        -RepoRoot $repoRoot `
        -Godot $Godot `
        -AttestationPath ([string]$closure.retained_attestation.path)
    Assert-R23D1Exact (-not [bool]$staleAttestation.ok) (
        "QSDK-R23D1 stale full-conformance attestation was accepted"
    )
    return [ordered]@{
        schema_version = "sporespore_qsdk_r23d1_supervisor_preflight_v1"
        ok = $true
        campaign_id = $campaignId
        gate_id = $gateId
        contract_sha256 = Get-R23D1RawSha256 $contractPath
        freeze_sha256 = Get-R23D1RawSha256 $freezePath
        source_binding_count = @($Bindings.freeze.source_bindings).Count
        worker_bundle_count = $bundles.Count
        worker_entrypoint_count = 9
        retained_test_cas_cell_report_count = $reportCas.Count
        production_aggregate_pass_count = 1
        aggregate_negative_control_rejection_count = 3
        stale_attestation_rejection_count = 1
        operation_lock_path_exercised = $true
        physical_authorization_refusal_count = [int](
            -not [bool]$Bindings.contract.authorization.physical_execution_authorized
        )
        physical_process_launch_count = 0
        world_build_count = 0
        locomotion_outcome_exposed = $false
        q_sdk_r23_satisfied = $false
        cross_engine_equivalence = $false
        release_authorized = $false
        physical_acceptance_authority = $false
    }
}

function Publish-R23D1InputArtifacts {
    param(
        [Parameter(Mandatory)]$Bindings,
        [Parameter(Mandatory)][string]$AttestationPath
    )
    $receipts = [ordered]@{}
    foreach ($binding in @($Bindings.freeze.source_bindings)) {
        $path = Join-Path $repoRoot ([string]$binding.path)
        $receipts[[string]$binding.name] =
            Publish-SporeSporeContentAddressedArtifact `
                -RepoRoot $repoRoot `
                -ArtifactPath $path `
                -MediaType ([string]$binding.media_type)
    }
    foreach ($runtime in @($Bindings.freeze.attempt_runtime_artifacts)) {
        $path = if ([bool]$runtime.repo_relative) {
            Join-Path $repoRoot ([string]$runtime.path)
        } else { [string]$runtime.path }
        Assert-R23D1Exact (Test-Path -LiteralPath $path -PathType Leaf) (
            "QSDK-R23D1 attempt runtime artifact missing: $path"
        )
        $receipts[[string]$runtime.name] =
            Publish-SporeSporeContentAddressedArtifact `
                -RepoRoot $repoRoot `
                -ArtifactPath $path `
                -MediaType ([string]$runtime.media_type)
    }
    $receipts.full_godot_attestation =
        Publish-SporeSporeContentAddressedArtifact `
            -RepoRoot $repoRoot `
            -ArtifactPath $AttestationPath `
            -MediaType "application/json"
    return $receipts
}

function Invoke-R23D1PhysicalCell {
    param(
        [Parameter(Mandatory)][string]$EngineId,
        [Parameter(Mandatory)][string]$ArmId,
        [Parameter(Mandatory)][string]$SourceCommit,
        [Parameter(Mandatory)][string]$AttemptPayloadPath,
        [Parameter(Mandatory)][string]$Token,
        [Parameter(Mandatory)][string]$CellRoot
    )
    [void][IO.Directory]::CreateDirectory($CellRoot)
    $cellId = "$EngineId`__$ArmId"
    $environment = [ordered]@{
        SPORESPORE_QSDK_R23D1_ATTEMPT = $AttemptPayloadPath
        SPORESPORE_QSDK_R23D1_TOKEN = $Token
        SPORESPORE_QSDK_R23D1_CELL = $cellId
        SPORESPORE_QSDK_R23D1_ENGINE = $EngineId
    }
    $fileName = ""
    $arguments = @()
    $workingDirectory = $repoRoot
    $cellPrefix = ""
    if ($EngineId -ceq "godot_jolt") {
        $fileName = $Godot
        $environment.APPDATA = Join-Path $CellRoot "appdata"
        $environment.LOCALAPPDATA = Join-Path $CellRoot "localappdata"
        [void][IO.Directory]::CreateDirectory($environment.APPDATA)
        [void][IO.Directory]::CreateDirectory($environment.LOCALAPPDATA)
        $arguments = @(
            "--headless", "--path", $repoRoot, "--script",
            $godotWorkerResource, "--", "physical", $ArmId, $SourceCommit
        )
        $cellPrefix = "QSDK_R23D1_GODOT_JOLT_CELL "
    } elseif ($EngineId -ceq "rapier_parry") {
        $fileName = $rapierBinaryPath
        $arguments = @("--arm", $ArmId, "--source-commit", $SourceCommit)
        $cellPrefix = "QSDK_R23D1_RAPIER_CELL "
    } elseif ($EngineId -ceq "mujoco") {
        $fileName = $mujocoPython
        $workingDirectory = $mujocoRoot
        $environment.SPORESPORE_LOCOMOTION_LIBRARY = $coreLibraryPath
        $environment.PYTHONPATH = $pythonCoreRoot
        $arguments = @(
            "-m", "sporespore_mujoco_adapter.qsdk_r23d1_heading_response",
            "--arm", $ArmId, "--source-commit", $SourceCommit
        )
        $cellPrefix = "QSDK_R23D1_MUJOCO_CELL "
    } else { throw "QSDK-R23D1 unknown physical engine: $EngineId" }
    $result = Invoke-R23D1Process `
        -FileName $fileName `
        -Arguments $arguments `
        -WorkingDirectory $workingDirectory `
        -Environment $environment `
        -TimeoutSeconds $CellTimeoutSeconds
    $logPath = Join-Path $CellRoot "engine.log"
    [IO.File]::WriteAllText(
        $logPath,
        $result.stdout + $result.stderr,
        [Text.UTF8Encoding]::new($false)
    )
    $logCas = Publish-SporeSporeContentAddressedArtifact `
        -RepoRoot $repoRoot `
        -ArtifactPath $logPath `
        -MediaType "text/plain"
    $report = $null
    $reportCas = $null
    $failure = ""
    try {
        if (-not $result.timed_out -and $result.exit_code -eq 0) {
            $report = Get-R23D1Marker -Text $result.stdout -Prefix $cellPrefix
            $reportPath = Join-Path $CellRoot "report.json"
            Write-R23D1NewJson -Path $reportPath -Value $report
            $reportCas = Publish-SporeSporeContentAddressedArtifact `
                -RepoRoot $repoRoot `
                -ArtifactPath $reportPath `
                -MediaType "application/json"
        } else {
            $failure = if ($result.timed_out) {
                "PROCESS_TIMEOUT"
            } else { "PROCESS_EXIT_$($result.exit_code)" }
        }
    } catch { $failure = "REPORT_PARSE_OR_RETENTION_FAILED:$($_.Exception.Message)" }
    return [ordered]@{
        cell_id = $cellId
        engine_id = $EngineId
        arm_id = $ArmId
        process_exit_code = $result.exit_code
        process_timed_out = $result.timed_out
        process_duration_seconds = $result.duration_seconds
        process_failure = $failure
        report = $report
        report_cas = $reportCas
        engine_log_cas = $logCas
        physical_acceptance_authority = $false
    }
}

function Invoke-R23D1PhysicalCampaign {
    param([Parameter(Mandatory)]$Bindings)
    Assert-R23D1Exact (
        [bool]$Bindings.contract.authorization.physical_execution_authorized
    ) "QSDK-R23D1 physical execution is not authorized by the frozen contract"
    Assert-R23D1Exact (
        -not [string]::IsNullOrWhiteSpace($FullConformanceAttestation)
    ) "QSDK-R23D1 physical execution requires a full-Godot V2 attestation"
    $source = Get-SporeSporeAttestationSourceIdentity `
        -RepoRoot $repoRoot `
        -RequireCleanPushedLive
    $attestation = Test-SporeSporeFullConformanceAttestationFile `
        -RepoRoot $repoRoot `
        -Godot $Godot `
        -AttestationPath $FullConformanceAttestation
    Assert-R23D1Exact ([bool]$attestation.ok) (
        "QSDK-R23D1 full-conformance attestation invalid: " +
        ($attestation.failure_codes -join ",")
    )
    $lock = Enter-SporeSporeLocomotionOperationLock -Role physical
    Assert-R23D1Exact ([bool]$lock.acquired) (
        "QSDK-R23D1 global locomotion operation lock is held"
    )
    try {
        $zeroWorld = Invoke-R23D1SupervisorPreflight -Bindings $Bindings
        $sourceAfterPreflight = Get-SporeSporeAttestationSourceIdentity `
            -RepoRoot $repoRoot `
            -RequireCleanPushedLive
        Assert-R23D1Exact (
            [string]$sourceAfterPreflight.commit -ceq [string]$source.commit -and
            [string]$sourceAfterPreflight.tree_git_oid -ceq [string]$source.tree_git_oid
        ) "QSDK-R23D1 source changed during preflight"
        $evidenceRoot = Get-SporeSporeArtifactEvidenceRoot -RepoRoot $repoRoot
        $prior = @(Get-ChildItem -LiteralPath $evidenceRoot -Directory |
            Where-Object { $_.Name -like "qsdk-r23d1-*" })
        Assert-R23D1Exact ($prior.Count -eq 0) (
            "QSDK-R23D1 one-shot identity already exists; rerun forbidden"
        )
        $resolvedOutput = if ([string]::IsNullOrWhiteSpace($OutputRoot)) {
            Join-Path $evidenceRoot (
                "qsdk-r23d1-" + [DateTime]::UtcNow.ToString("yyyyMMddTHHmmssZ")
            )
        } else { [IO.Path]::GetFullPath($OutputRoot) }
        $prefix = $evidenceRoot.TrimEnd("\", "/") + [IO.Path]::DirectorySeparatorChar
        Assert-R23D1Exact (
            $resolvedOutput.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase) -and
            -not (Test-Path -LiteralPath $resolvedOutput)
        ) "QSDK-R23D1 output must be a new directory under $evidenceRoot"
        $inputCas = Publish-R23D1InputArtifacts `
            -Bindings $Bindings `
            -AttestationPath $FullConformanceAttestation
        [void][IO.Directory]::CreateDirectory($resolvedOutput)
        $token = [guid]::NewGuid().ToString("N")
        $attempt = [ordered]@{
            schema_version = "sporespore_qsdk_r23d1_attempt_v1"
            attempt_id = [guid]::NewGuid().ToString("N")
            campaign_id = $campaignId
            gate_id = $gateId
            contract_sha256 = Get-R23D1RawSha256 $contractPath
            freeze_sha256 = Get-R23D1RawSha256 $freezePath
            source_commit = [string]$source.commit
            origin_main_commit = [string]$source.origin_main
            live_main_commit = [string]$source.live_github_main
            authorization_token = $token
            physical_execution_authorized = $true
            single_use_supervisor_authorization = $true
            source_worktree_clean = $true
            source_matches_live_github_main = $true
            operation_lock_held = $true
            full_godot_attestation_valid = $true
            full_godot_attestation_sha256 = [string]$attestation.sha256
            content_addressed_inputs_retained = $true
            content_addressed_inputs = $inputCas
            complete_zero_world_gate_passed = [bool]$zeroWorld.ok
            one_shot_attempt_unconsumed = $true
            ordered_cell_ids = $orderedCellIds
            replacement_or_selective_rerun_permitted = $false
            physical_acceptance_authority = $false
        }
        $attemptPath = Join-Path $resolvedOutput "attempt.json"
        Write-R23D1NewJson -Path $attemptPath -Value $attempt
        $attemptCas = Publish-SporeSporeContentAddressedArtifact `
            -RepoRoot $repoRoot `
            -ArtifactPath $attemptPath `
            -MediaType "application/json"
        $cells = [Collections.Generic.List[object]]::new()
        foreach ($cellId in $orderedCellIds) {
            $parts = $cellId -split "__", 2
            $cells.Add((Invoke-R23D1PhysicalCell `
                -EngineId $parts[0] `
                -ArmId $parts[1] `
                -SourceCommit ([string]$source.commit) `
                -AttemptPayloadPath ([string]$attemptCas.payload_path) `
                -Token $token `
                -CellRoot (Join-Path $resolvedOutput $cellId)))
        }
        $retainedReports = @($cells | Where-Object { $null -ne $_.report_cas })
        $aggregateInput = [ordered]@{
            schema_version = "sporespore_qsdk_r23d1_aggregate_input_v1"
            ordered_cell_ids = $orderedCellIds
            retained_report_count = $retainedReports.Count
            ordered_report_cas = @($retainedReports | ForEach-Object { $_.report_cas })
            missing_cell_ids = @($cells | Where-Object { $null -eq $_.report_cas } |
                ForEach-Object { [string]$_.cell_id })
            physical_acceptance_authority = $false
        }
        $aggregateInputPath = Join-Path $resolvedOutput "aggregate-input.json"
        Write-R23D1NewJson -Path $aggregateInputPath -Value $aggregateInput
        $aggregateInputCas = Publish-SporeSporeContentAddressedArtifact `
            -RepoRoot $repoRoot `
            -ArtifactPath $aggregateInputPath `
            -MediaType "application/json"
        $aggregate = if ($retainedReports.Count -gt 0) {
            Invoke-R23D1AggregateEvaluator -ReportPaths @(
                $retainedReports | ForEach-Object {
                    [string]$_.report_cas.payload_path
                }
            )
        } else {
            [ordered]@{
                process = @{ exit_code = 1; timed_out = $false }
                evaluation = @{
                    schema_version = "sporespore_qsdk_r23d1_aggregate_evaluation_v1"
                    development_screen_passed = $false
                    report_count = 0
                    failure_codes = @("R23D1_AGGREGATE_REPORT_COUNT")
                    q_sdk_r23_satisfied = $false
                    cross_engine_equivalence = $false
                    physical_acceptance_authority = $false
                }
            }
        }
        $report = [ordered]@{
            schema_version = "sporespore_qsdk_r23d1_campaign_report_v1"
            campaign_id = $campaignId
            gate_id = $gateId
            source = $source
            contract_sha256 = Get-R23D1RawSha256 $contractPath
            freeze_sha256 = Get-R23D1RawSha256 $freezePath
            attempt_cas = $attemptCas
            aggregate_input_cas = $aggregateInputCas
            ordered_cells = @($cells)
            aggregate_evaluation = $aggregate.evaluation
            complete_report_count = $retainedReports.Count
            development_screen_passed = [bool]$aggregate.evaluation.development_screen_passed
            claims = [ordered]@{
                development_screen_only = $true
                q_sdk_r23_satisfied = $false
                command_conditioned_turning = $false
                cross_engine_equivalence = $false
                release_authorized = $false
                physical_acceptance_authority = $false
            }
        }
        $reportPath = Join-Path $resolvedOutput "report.json"
        Write-R23D1NewJson -Path $reportPath -Value $report
        $reportCas = Publish-SporeSporeContentAddressedArtifact `
            -RepoRoot $repoRoot `
            -ArtifactPath $reportPath `
            -MediaType "application/json"
        $valid = $retainedReports.Count -eq 9
        $completion = [ordered]@{
            schema_version = "sporespore_qsdk_r23d1_completion_v1"
            campaign_id = $campaignId
            status = if ($valid) { "complete_first_attempt" } else {
                "invalid_or_incomplete_first_attempt"
            }
            source_commit = [string]$source.commit
            ordered_cell_count = 9
            complete_report_count = $retainedReports.Count
            report_cas = $reportCas
            one_shot_identity_consumed = $true
            same_identity_rerun_allowed = $false
            q_sdk_r23_satisfied = $false
            cross_engine_equivalence = $false
            release_authorized = $false
            physical_acceptance_authority = $false
        }
        $completionPath = Join-Path $resolvedOutput "completion.json"
        Write-R23D1NewJson -Path $completionPath -Value $completion
        $completionCas = Publish-SporeSporeContentAddressedArtifact `
            -RepoRoot $repoRoot `
            -ArtifactPath $completionPath `
            -MediaType "application/json"
        if (-not $valid) {
            throw "QSDK-R23D1 retained an invalid or incomplete first attempt: $resolvedOutput"
        }
        Write-Host (
            "QSDK_R23D1_PHYSICAL_COMPLETE reports=9 " +
            "development_screen_passed=$([bool]$aggregate.evaluation.development_screen_passed) " +
            "q_sdk_r23=False equivalence=False release=False " +
            "report_sha256=$([string]$reportCas.sha256) " +
            "completion_sha256=$([string]$completionCas.sha256)"
        )
    } finally {
        Exit-SporeSporeLocomotionOperationLock $lock
    }
}

Assert-R23D1Exact ($PreflightOnly.IsPresent -xor $RunPhysical.IsPresent) (
    "Specify exactly one of -PreflightOnly or -RunPhysical"
)
Assert-R23D1Exact (
    $RunPhysical.IsPresent -or (
        [string]::IsNullOrWhiteSpace($FullConformanceAttestation) -and
        [string]::IsNullOrWhiteSpace($OutputRoot)
    )
) "-FullConformanceAttestation and -OutputRoot require -RunPhysical"

if ($RunPhysical.IsPresent -and (Test-Path -LiteralPath $closurePath -PathType Leaf)) {
    throw (
        "QSDK-R23D1 is closed and may not open another world; " +
        "audit sdk/turning/physical_development_closure_v1.json instead"
    )
}

$bindings = Get-R23D1ContractAndFreeze
if ($PreflightOnly) {
    $receipt = Invoke-R23D1SupervisorPreflight -Bindings $bindings
    Write-Host (
        "QSDK_R23D1_SUPERVISOR_PREFLIGHT " +
        ($receipt | ConvertTo-Json -Depth 100 -Compress)
    )
    Write-Host (
        "QSDK_R23D1_SUPERVISOR_PASS workers=3 entrypoints=9 reports=9 " +
        "cell_cas=9 aggregate=1/1 aggregate_negative_controls=3/3 " +
        "stale_attestation_rejected=True " +
        "physical_refusal=$([int]$receipt.physical_authorization_refusal_count) " +
        "worlds=0 physical_authority=False"
    )
    exit 0
}
Invoke-R23D1PhysicalCampaign -Bindings $bindings
