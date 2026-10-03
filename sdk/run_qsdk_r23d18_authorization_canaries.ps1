#requires -Version 7.0

[CmdletBinding()]
param(
    [string]$CampaignAttestationAdoption = "",
    [switch]$PreflightOnly,
    [string]$Godot = (
        "C:\Users\Cole\CodeStuff\Misc\Godot\" +
        "Godot_v4.7-stable_mono_win64_console.exe"
    ),
    [ValidateRange(30, 600)][int]$ProcessTimeoutSeconds = 120
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$sdkRoot = [IO.Path]::GetFullPath($PSScriptRoot)
$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $sdkRoot))
$evidenceRoot = [IO.Path]::GetFullPath("${repoRoot}_Evidence")
$implementationPath = Join-Path $sdkRoot (
    "turning\r23d18_physical_implementation_contract_v1.json"
)
$preregistrationPath = Join-Path $sdkRoot (
    "turning\r23d18_receipt_integrity_recovery_preregistration_v1.json"
)
$dependencyComposerPath = Join-Path $sdkRoot "turning\r23d18_dependency_closure.ps1"
$operationLockPath = Join-Path $sdkRoot "locomotion_operation_lock.ps1"
$attestationVerifierPath = Join-Path $sdkRoot (
    "locomotion_campaign_attestation_adoption.ps1"
)
$campaignAttestationManifestPath = Join-Path $sdkRoot (
    "turning\r23d18_campaign_attestation_manifest_v1.json"
)
$mujocoRoot = Join-Path $sdkRoot "adapters\mujoco"
$mujocoPython = Join-Path $mujocoRoot ".venv\Scripts\python.exe"
$pythonRoot = Join-Path $sdkRoot "python"
$releaseLibrary = Join-Path $sdkRoot "target\release\sporespore_locomotion_core.dll"
$rapierWorker = Join-Path $sdkRoot "target\release\qsdk_r23d18_physical.exe"
$godotWorkerResource = "res://tests/test_sdk_qsdk_r23d18_godot_jolt_physical_worker.gd"
$campaignId = "QSDK-R23D18-RECEIPT-INTEGRITY-RECOVERY-THREE-ENGINE-TURN-CONFIRMATION"
$gateId = "QSDK-R23D18"
$stageId = "finite_three_engine_confirmation_receipt_integrity_recovery"
$armId = "reference_zero"
$utf8NoBom = [Text.UTF8Encoding]::new($false)

. $dependencyComposerPath
. $operationLockPath
. $attestationVerifierPath

function Assert-R23D18AuthorizationCanary {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function Get-R23D18AuthorizationRawSha256 {
    param([Parameter(Mandatory)][string]$Path)
    return "sha256:" + (
        Get-FileHash -LiteralPath $Path -Algorithm SHA256
    ).Hash.ToLowerInvariant()
}

function Write-R23D18AuthorizationJson {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)]$Value
    )
    Assert-R23D18AuthorizationCanary (-not (Test-Path -LiteralPath $Path)) (
        "QSDK-R23D18 authorization canary refuses to overwrite: $Path"
    )
    $json = $Value | ConvertTo-Json -Depth 100
    [IO.File]::WriteAllText($Path, $json + "`n", $utf8NoBom)
}

function Invoke-R23D18AuthorizationProcess {
    param(
        [Parameter(Mandatory)][string]$FileName,
        [Parameter(Mandatory)][AllowEmptyCollection()][string[]]$Arguments,
        [Parameter(Mandatory)][Collections.IDictionary]$Environment,
        [Parameter(Mandatory)][string]$Label
    )
    $start = [Diagnostics.ProcessStartInfo]::new()
    $start.FileName = $FileName
    $start.WorkingDirectory = $repoRoot
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    foreach ($entry in $Environment.GetEnumerator()) {
        $start.Environment[[string]$entry.Key] = [string]$entry.Value
    }
    foreach ($argument in $Arguments) {
        [void]$start.ArgumentList.Add($argument)
    }
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $start
    Assert-R23D18AuthorizationCanary $process.Start() (
        "QSDK-R23D18 authorization canary failed to start: $Label"
    )
    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()
    $timedOut = -not $process.WaitForExit($ProcessTimeoutSeconds * 1000)
    if ($timedOut) {
        $process.Kill($true)
        $process.WaitForExit()
    }
    return [ordered]@{
        label = $Label
        exit_code = $process.ExitCode
        timed_out = $timedOut
        stdout = $stdoutTask.GetAwaiter().GetResult()
        stderr = $stderrTask.GetAwaiter().GetResult()
    }
}

function Get-R23D18AuthorizationEnvironment {
    param(
        [Parameter(Mandatory)][string]$EngineId,
        [Parameter(Mandatory)][string]$FreezePath,
        [Parameter(Mandatory)][string]$AttemptPath,
        [Parameter(Mandatory)][string]$AttemptRoot,
        [Parameter(Mandatory)][string]$Token
    )
    $cellId = "$EngineId`__tight_gated_horizon__reference_zero"
    return [ordered]@{
        SPORESPORE_QSDK_R23D18_FREEZE = $FreezePath
        SPORESPORE_QSDK_R23D18_ATTEMPT = $AttemptPath
        SPORESPORE_QSDK_R23D18_TOKEN = $Token
        SPORESPORE_QSDK_R23D18_STAGE = $stageId
        SPORESPORE_QSDK_R23D18_CELL = $cellId
        SPORESPORE_QSDK_R23D18_ENGINE = $EngineId
        SPORESPORE_QSDK_R23D18_ATTEMPT_ROOT = $AttemptRoot
        SPORESPORE_QSDK_R23D18_PYTHON = $mujocoPython
        SPORESPORE_QSDK_R23D18_POWERSHELL = (Get-Process -Id $PID).Path
        SPORESPORE_LOCOMOTION_LIBRARY = $releaseLibrary
        PYTHONPATH = $mujocoRoot + [IO.Path]::PathSeparator + $pythonRoot
    }
}

function Get-R23D18AuthorizationCommand {
    param(
        [Parameter(Mandatory)][string]$EngineId,
        [Parameter(Mandatory)][string]$SourceCommit,
        [Parameter(Mandatory)][string]$GodotLogPath
    )
    if ($EngineId -ceq "mujoco") {
        return [ordered]@{
            file = $mujocoPython
            arguments = @(
                "-m",
                "sporespore_mujoco_adapter.qsdk_r23d18_physical",
                "authorization-preflight",
                "--stage-id", $stageId,
                "--arm-id", $armId,
                "--source-commit", $SourceCommit
            )
            positive_marker = "QSDK_R23D18_MUJOCO_AUTHORIZATION_PREFLIGHT "
            refusal_code = "QSDK_R23D18_MJC_PHYSICAL_AUTHORIZATION_INVALID"
        }
    }
    if ($EngineId -ceq "rapier_parry") {
        return [ordered]@{
            file = $rapierWorker
            arguments = @(
                "authorization-preflight",
                "--stage", $stageId,
                "--arm", $armId,
                "--source-commit", $SourceCommit
            )
            positive_marker = "QSDK_R23D18_RAPIER_AUTHORIZATION_PREFLIGHT "
            refusal_code = "QSDK_R23D18_RAP_PHYSICAL_AUTHORIZATION_INVALID"
        }
    }
    if ($EngineId -ceq "godot_jolt") {
        return [ordered]@{
            file = $Godot
            arguments = @(
                "--headless",
                "--path", $repoRoot,
                "--log-file", $GodotLogPath,
                "--script", $godotWorkerResource,
                "--",
                "--stage", $stageId,
                "--arm", $armId,
                "--authorization-preflight",
                "--source-commit", $SourceCommit
            )
            positive_marker = "QSDK_R23D18_GODOT_JOLT_AUTHORIZATION_PREFLIGHT "
            refusal_code = "QSDK_R23D18_GJT_PHYSICAL_AUTHORIZATION_INVALID"
        }
    }
    throw "QSDK-R23D18 unknown authorization-canary engine: $EngineId"
}

function Assert-R23D18PositiveAuthorizationReceipt {
    param(
        [Parameter(Mandatory)][Collections.IDictionary]$Execution,
        [Parameter(Mandatory)][string]$Marker,
        [Parameter(Mandatory)][string]$EngineId,
        [Parameter(Mandatory)][string]$FunctionName
    )
    $lines = @(([string]$Execution.stdout -split "`r?`n") | Where-Object {
        $_.StartsWith($Marker, [StringComparison]::Ordinal)
    })
    Assert-R23D18AuthorizationCanary (
        -not [bool]$Execution.timed_out -and
        [int]$Execution.exit_code -eq 0 -and
        $lines.Count -eq 1
    ) (
        "QSDK-R23D18 positive authorization canary failed: $EngineId; " +
        "stdout=$($Execution.stdout); stderr=$($Execution.stderr)"
    )
    $receipt = $lines[0].Substring($Marker.Length) |
        ConvertFrom-Json -AsHashtable -Depth 100
    Assert-R23D18AuthorizationCanary (
        [string]$receipt.campaign_id -ceq $campaignId -and
        [string]$receipt.gate_id -ceq $gateId -and
        [string]$receipt.engine_id -ceq $EngineId -and
        [string]$receipt.actual_production_authorization_function -ceq $FunctionName -and
        [bool]$receipt.authorization_passed -and
        [bool]$receipt.returned_before_model -and
        [int]$receipt.physical_process_launch_count -eq 0 -and
        [int]$receipt.model_construction_count -eq 0 -and
        [int]$receipt.world_attempt_count -eq 0 -and
        [int]$receipt.world_build_count -eq 0 -and
        -not [bool]$receipt.physical_acceptance_authority
    ) "QSDK-R23D18 positive authorization receipt changed: $EngineId"
}

Assert-R23D18AuthorizationCanary (
    ($PreflightOnly -and [string]::IsNullOrWhiteSpace($CampaignAttestationAdoption)) -or
    (-not $PreflightOnly -and -not [string]::IsNullOrWhiteSpace($CampaignAttestationAdoption))
) "QSDK-R23D18 authorization-canary mode and adoption arguments are inconsistent"

$requiredInputs = @(
    $implementationPath,
    $preregistrationPath,
    $dependencyComposerPath,
    $operationLockPath,
    $attestationVerifierPath,
    $mujocoPython,
    $Godot
)
if (-not $PreflightOnly) {
    $requiredInputs += @(
        $releaseLibrary,
        $rapierWorker,
        $campaignAttestationManifestPath,
        $CampaignAttestationAdoption
    )
}
foreach ($path in $requiredInputs) {
    Assert-R23D18AuthorizationCanary (Test-Path -LiteralPath $path -PathType Leaf) (
        "QSDK-R23D18 authorization-canary input is missing: $path"
    )
}
Assert-R23D18AuthorizationCanary (Test-Path -LiteralPath $evidenceRoot -PathType Container) (
    "QSDK-R23D18 durable evidence root is missing: $evidenceRoot"
)

$implementation = Get-Content -Raw -LiteralPath $implementationPath |
    ConvertFrom-Json -AsHashtable -Depth 100
$manifest = Get-R23D18DependencyManifest -RepoRoot $repoRoot
Assert-R23D18AuthorizationCanary (
    [string]$implementation.campaign_id -ceq $campaignId -and
    [string]$implementation.gate_id -ceq $gateId -and
    @($manifest.ordered_worker_ids).Count -eq 3 -and
    (@($manifest.ordered_worker_ids) -join "|") -ceq
        "mujoco|rapier_parry|godot_jolt" -and
    [int]$manifest.unique_dependency_count -eq 77
) "QSDK-R23D18 authorization-canary implementation identity changed"

$sourceBindings = @(
    foreach ($relativePath in @($manifest.union_paths)) {
        $absolutePath = Join-Path $repoRoot ([string]$relativePath)
        Assert-R23D18AuthorizationCanary (
            Test-Path -LiteralPath $absolutePath -PathType Leaf
        ) "QSDK-R23D18 authorization dependency is missing: $relativePath"
        [ordered]@{
            path = [string]$relativePath
            raw_sha256 = Get-R23D18AuthorizationRawSha256 $absolutePath
        }
    }
)

if ($PreflightOnly) {
    $preflightCommit = (git -C $repoRoot rev-parse HEAD).Trim()
    Assert-R23D18AuthorizationCanary ($LASTEXITCODE -eq 0) (
        "QSDK-R23D18 authorization-canary preflight could not read HEAD"
    )
    $commandCount = 0
    $environmentCount = 0
    foreach ($engineId in @($manifest.ordered_worker_ids)) {
        $requiredPaths = @($manifest.required_paths_by_worker[$engineId])
        Assert-R23D18AuthorizationCanary ($requiredPaths.Count -gt 0) (
            "QSDK-R23D18 authorization-canary preflight worker is empty: $engineId"
        )
        $command = Get-R23D18AuthorizationCommand `
            -EngineId $engineId `
            -SourceCommit $preflightCommit `
            -GodotLogPath (Join-Path $sdkRoot "target\r23d18-canary-preflight-godot.log")
        $authorizationArgument = if ($engineId -in @("mujoco", "rapier_parry")) {
            "authorization-preflight"
        } else {
            "--authorization-preflight"
        }
        $commandFileValid = if ($engineId -ceq "rapier_parry") {
            [string]$command.file -ceq $rapierWorker
        } else {
            Test-Path -LiteralPath ([string]$command.file) -PathType Leaf
        }
        Assert-R23D18AuthorizationCanary (
            $commandFileValid -and
            @($command.arguments).Count -gt 0 -and
            @($command.arguments) -ccontains $authorizationArgument -and
            -not [string]::IsNullOrWhiteSpace([string]$command.positive_marker) -and
            -not [string]::IsNullOrWhiteSpace([string]$command.refusal_code)
        ) "QSDK-R23D18 authorization-canary preflight command changed: $engineId"
        $commandCount += 1
        $environment = Get-R23D18AuthorizationEnvironment `
            -EngineId $engineId `
            -FreezePath "R23D18_PREFLIGHT_FREEZE" `
            -AttemptPath "R23D18_PREFLIGHT_ATTEMPT" `
            -AttemptRoot $evidenceRoot `
            -Token ("0" * 32)
        Assert-R23D18AuthorizationCanary (
            [string]$environment.SPORESPORE_QSDK_R23D18_ENGINE -ceq $engineId -and
            [string]$environment.SPORESPORE_QSDK_R23D18_STAGE -ceq $stageId -and
            [string]$environment.SPORESPORE_QSDK_R23D18_CELL -ceq
                "$engineId`__tight_gated_horizon__reference_zero"
        ) "QSDK-R23D18 authorization-canary preflight environment changed: $engineId"
        $environmentCount += 1
    }
    $preflightReceipt = [ordered]@{
        schema_version = "sporespore_qsdk_r23d18_authorization_canary_runner_preflight_v1"
        campaign_id = $campaignId
        gate_id = $gateId
        ordered_engine_count = 3
        command_shape_count = $commandCount
        environment_shape_count = $environmentCount
        content_addressed_input_count = $sourceBindings.Count
        authorization_canary_process_launch_count = 0
        model_construction_count = 0
        world_attempt_count = 0
        world_build_count = 0
        physical_acceptance_authority = $false
    }
    Write-Host (
        "QSDK_R23D18_AUTHORIZATION_CANARY_PREFLIGHT_PASS " +
        ($preflightReceipt | ConvertTo-Json -Depth 30 -Compress)
    )
    return
}

$source = Get-SporeSporeAttestationSourceIdentity `
    -RepoRoot $repoRoot `
    -RequireCleanPushedLive
$attestation = Test-SporeSporeCampaignAttestationAdoptionFile `
    -RepoRoot $repoRoot `
    -ManifestPath $campaignAttestationManifestPath `
    -Godot $Godot `
    -Python "python" `
    -ExpectedCampaignId $campaignId `
    -AdoptionPath $CampaignAttestationAdoption
Assert-R23D18AuthorizationCanary ([bool]$attestation.ok) (
    "QSDK-R23D18 authorization canaries require valid campaign adoption: " +
    (@($attestation.failure_codes) -join ",")
)

$operationLock = $null
$canaryRoot = $null
$receipt = $null
try {
    $operationLock = Enter-SporeSporeLocomotionOperationLock -Role conformance
    Assert-R23D18AuthorizationCanary ([bool]$operationLock.acquired) (
        "QSDK-R23D18 authorization canary could not acquire the global operation lock"
    )

    $leaf = "qsdk-r23d18-authorization-canary-" + [guid]::NewGuid().ToString("N")
    $canaryRoot = [IO.Path]::GetFullPath((Join-Path $evidenceRoot $leaf))
    Assert-R23D18AuthorizationCanary (
        [IO.Path]::GetDirectoryName($canaryRoot) -ceq $evidenceRoot -and
        [IO.Path]::GetFileName($canaryRoot).StartsWith(
            "qsdk-r23d18-authorization-canary-",
            [StringComparison]::Ordinal
        ) -and
        -not (Test-Path -LiteralPath $canaryRoot)
    ) "QSDK-R23D18 authorization canary root is not an exact new evidence child"
    [void][IO.Directory]::CreateDirectory($canaryRoot)

    $casRoot = Join-Path $canaryRoot "artifacts\sha256"
    [void][IO.Directory]::CreateDirectory($casRoot)
    foreach ($binding in $sourceBindings) {
        $digest = ([string]$binding.raw_sha256).Substring(7)
        $casPath = Join-Path $casRoot $digest
        if (-not (Test-Path -LiteralPath $casPath)) {
            Copy-Item -LiteralPath (Join-Path $repoRoot ([string]$binding.path)) `
                -Destination $casPath
        }
        Assert-R23D18AuthorizationCanary (
            (Get-R23D18AuthorizationRawSha256 $casPath) -ceq
                [string]$binding.raw_sha256
        ) "QSDK-R23D18 authorization source CAS mismatch: $($binding.path)"
    }

    $token = [guid]::NewGuid().ToString("N")
    $attemptId = [guid]::NewGuid().ToString("N")
    $sourceCommit = [string]$source.commit
    $baseFreeze = [ordered]@{
        schema_version = "sporespore_qsdk_r23d18_physical_freeze_v1"
        campaign_id = $campaignId
        gate_id = $gateId
        status = "frozen_supervisor_only_physical_authorized"
        preregistration_raw_sha256 = Get-R23D18AuthorizationRawSha256 $preregistrationPath
        implementation_contract_raw_sha256 = (
            Get-R23D18AuthorizationRawSha256 $implementationPath
        )
        source_commit = $sourceCommit
        physical_execution_authorized = $true
        source_bindings = $sourceBindings
    }
    $matrixCellIds = @(
        foreach ($engine in @("godot_jolt", "rapier_parry", "mujoco")) {
            foreach ($arm in @("reference_zero", "positive_heading", "negative_heading")) {
                "$engine`__tight_gated_horizon__$arm"
            }
        }
    )
    $baseAttempt = [ordered]@{
        schema_version = "sporespore_qsdk_r23d18_attempt_v1"
        campaign_id = $campaignId
        gate_id = $gateId
        source_commit = $sourceCommit
        authorization_token = $token
        attempt_id = $attemptId
        attempt_root = $canaryRoot.Replace("\", "/")
        physical_execution_authorized = $true
        single_use_supervisor_authorization = $true
        matrix_authorization_immutable_before_first_world = $true
        source_worktree_clean = $true
        source_matches_live_github_main = $true
        operation_lock_held = $true
        campaign_attestation_adoption_valid = $true
        content_addressed_inputs_retained = $true
        one_shot_attempt_unconsumed = $true
        ordered_matrix_cell_ids = $matrixCellIds
        selected_terminal_policy_id = (
            "sporespore_tight_gated_acquisition_active600_v1"
        )
    }

    $functionNames = [ordered]@{
        mujoco = "physical_authorization"
        rapier_parry = "r23d18_physical_authorization"
        godot_jolt = "_r23d18_physical_authorization"
    }
    $positiveCount = 0
    $refusalCount = 0
    foreach ($engineId in @("mujoco", "rapier_parry", "godot_jolt")) {
        $engineRoot = Join-Path $canaryRoot $engineId
        [void][IO.Directory]::CreateDirectory($engineRoot)
        $freezePath = Join-Path $engineRoot "freeze.json"
        Write-R23D18AuthorizationJson $freezePath $baseFreeze
        $attempt = [ordered]@{} + $baseAttempt
        $attempt["freeze_raw_sha256"] = Get-R23D18AuthorizationRawSha256 $freezePath
        $attemptPath = Join-Path $engineRoot "attempt.json"
        Write-R23D18AuthorizationJson $attemptPath $attempt
        $environment = Get-R23D18AuthorizationEnvironment `
            -EngineId $engineId `
            -FreezePath $freezePath `
            -AttemptPath $attemptPath `
            -AttemptRoot $canaryRoot `
            -Token $token
        $command = Get-R23D18AuthorizationCommand `
            -EngineId $engineId `
            -SourceCommit $sourceCommit `
            -GodotLogPath (Join-Path $engineRoot "positive-godot.log")
        $positive = Invoke-R23D18AuthorizationProcess `
            -FileName ([string]$command.file) `
            -Arguments @($command.arguments) `
            -Environment $environment `
            -Label "$engineId-positive"
        Assert-R23D18PositiveAuthorizationReceipt `
            -Execution $positive `
            -Marker ([string]$command.positive_marker) `
            -EngineId $engineId `
            -FunctionName ([string]$functionNames[$engineId])
        $positiveCount += 1

        $mutatedFreeze = $baseFreeze | ConvertTo-Json -Depth 100 |
            ConvertFrom-Json -AsHashtable -Depth 100
        $requiredPaths = @(
            $implementation.dependency_closure.required_dependency_paths_by_worker[$engineId]
        )
        Assert-R23D18AuthorizationCanary ($requiredPaths.Count -gt 0) (
            "QSDK-R23D18 authorization mutation has no required paths: $engineId"
        )
        $mutatedPath = [string]$requiredPaths[0]
        $targetBindings = @($mutatedFreeze.source_bindings | Where-Object {
            [string]$_.path -ceq $mutatedPath
        })
        Assert-R23D18AuthorizationCanary ($targetBindings.Count -eq 1) (
            "QSDK-R23D18 authorization mutation target is not unique: $mutatedPath"
        )
        $targetBindings[0].raw_sha256 = "sha256:" + ("0" * 64)
        $mutatedFreezePath = Join-Path $engineRoot "freeze-mutated.json"
        Write-R23D18AuthorizationJson $mutatedFreezePath $mutatedFreeze
        $mutatedAttempt = [ordered]@{} + $baseAttempt
        $mutatedAttempt["freeze_raw_sha256"] = Get-R23D18AuthorizationRawSha256 (
            $mutatedFreezePath
        )
        $mutatedAttemptPath = Join-Path $engineRoot "attempt-mutated.json"
        Write-R23D18AuthorizationJson $mutatedAttemptPath $mutatedAttempt
        $mutatedEnvironment = Get-R23D18AuthorizationEnvironment `
            -EngineId $engineId `
            -FreezePath $mutatedFreezePath `
            -AttemptPath $mutatedAttemptPath `
            -AttemptRoot $canaryRoot `
            -Token $token
        $mutatedCommand = Get-R23D18AuthorizationCommand `
            -EngineId $engineId `
            -SourceCommit $sourceCommit `
            -GodotLogPath (Join-Path $engineRoot "mutated-godot.log")
        $refusal = Invoke-R23D18AuthorizationProcess `
            -FileName ([string]$mutatedCommand.file) `
            -Arguments @($mutatedCommand.arguments) `
            -Environment $mutatedEnvironment `
            -Label "$engineId-mutated-binding"
        $combined = [string]$refusal.stdout + "`n" + [string]$refusal.stderr
        Assert-R23D18AuthorizationCanary (
            -not [bool]$refusal.timed_out -and
            [int]$refusal.exit_code -ne 0 -and
            $combined.Contains(
                [string]$mutatedCommand.refusal_code,
                [StringComparison]::Ordinal
            ) -and
            -not $combined.Contains(
                [string]$mutatedCommand.positive_marker,
                [StringComparison]::Ordinal
            )
        ) (
            "QSDK-R23D18 mutated binding was not refused: $engineId; " +
            "stdout=$($refusal.stdout); stderr=$($refusal.stderr)"
        )
        $refusalCount += 1
    }

    Assert-R23D18AuthorizationCanary (
        $positiveCount -eq 3 -and
        $refusalCount -eq 3
    ) "QSDK-R23D18 production authorization canary counts changed"
    $receipt = [ordered]@{
        schema_version = "sporespore_qsdk_r23d18_production_authorization_canaries_v1"
        campaign_id = $campaignId
        gate_id = $gateId
        source_commit = $sourceCommit
        campaign_attestation_adoption_raw_sha256 = (
            Get-R23D18AuthorizationRawSha256 $CampaignAttestationAdoption
        )
        engine_count = 3
        worker_process_launch_count = 6
        actual_production_authorization_function_execution_count = 6
        positive_authorization_canary_count = $positiveCount
        mutated_binding_refusal_canary_count = $refusalCount
        content_addressed_input_count = $sourceBindings.Count
        physical_process_launch_count = 0
        model_construction_count = 0
        world_attempt_count = 0
        world_build_count = 0
        test_only_evidence_root_deleted = $true
        physical_acceptance_authority = $false
    }
} finally {
    if ($null -ne $canaryRoot -and (Test-Path -LiteralPath $canaryRoot)) {
        $resolvedRoot = [IO.Path]::GetFullPath($canaryRoot)
        $safeLeaf = [IO.Path]::GetFileName($resolvedRoot)
        Assert-R23D18AuthorizationCanary (
            [IO.Path]::GetDirectoryName($resolvedRoot) -ceq $evidenceRoot -and
            $safeLeaf.StartsWith(
                "qsdk-r23d18-authorization-canary-",
                [StringComparison]::Ordinal
            )
        ) "QSDK-R23D18 refused unsafe authorization-canary cleanup"
        Remove-Item -LiteralPath $resolvedRoot -Recurse -Force
    }
    if ($null -ne $operationLock) {
        Exit-SporeSporeLocomotionOperationLock $operationLock
    }
}

Assert-R23D18AuthorizationCanary (
    $null -ne $receipt -and
    -not (Test-Path -LiteralPath $canaryRoot)
) "QSDK-R23D18 authorization-canary cleanup did not complete"
Write-Host (
    "QSDK_R23D18_AUTHORIZATION_CANARIES_PASS " +
    ($receipt | ConvertTo-Json -Depth 30 -Compress)
)
