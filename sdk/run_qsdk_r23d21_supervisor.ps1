#requires -Version 7.0

[CmdletBinding()]
param(
    [switch]$PreflightOnly,
    [switch]$CampaignRolePreflight,
    [switch]$RunPhysical,
    [string]$CampaignAttestationAdoption = "",
    [string]$OutputRoot = "",
    [string]$Python = "python",
    [string]$PowerShell = "pwsh",
    [string]$Godot = (
        "C:\Users\Cole\CodeStuff\Misc\Godot\" +
        "Godot_v4.7-stable_mono_win64_console.exe"
    ),
    [ValidateRange(300, 3600)][int]$CellTimeoutSeconds = 900
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$sdkRoot = [IO.Path]::GetFullPath($PSScriptRoot)
$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $sdkRoot))
$turningRoot = Join-Path $sdkRoot "turning"
$implementationPath = Join-Path $turningRoot "r23d21_physical_implementation_contract_v1.json"
$preregistrationPath = Join-Path $turningRoot "r23d21_reduced_yaw_authority_preregistration_v1.json"
$closurePath = Join-Path $turningRoot "r23d21_physical_closure_v1.json"
$evaluatorPath = Join-Path $turningRoot "r23d21_physical_evaluator.py"
$manifestPath = Join-Path $turningRoot "r23d21_campaign_attestation_manifest_v1.json"
$workerResource = "res://tests/test_sdk_qsdk_r23d21_godot_jolt_physical_worker.gd"
$campaignId = "QSDK-R23D21-REDUCED-YAW-AUTHORITY-GODOT-DEVELOPMENT"
$gateId = "QSDK-R23D21"
$stageId = "godot_jolt_reduced_yaw_authority_development"
$arms = @("reference_zero", "positive_heading", "negative_heading")
$cellIds = @($arms | ForEach-Object { "godot_jolt__tight_gated_horizon__$_" })
$attemptEnvironmentNames = @(
    "SPORESPORE_QSDK_R23D21_FREEZE",
    "SPORESPORE_QSDK_R23D21_ATTEMPT",
    "SPORESPORE_QSDK_R23D21_TOKEN",
    "SPORESPORE_QSDK_R23D21_STAGE",
    "SPORESPORE_QSDK_R23D21_CELL",
    "SPORESPORE_QSDK_R23D21_ENGINE",
    "SPORESPORE_QSDK_R23D21_ATTEMPT_ROOT",
    "SPORESPORE_QSDK_R23D21_PYTHON",
    "SPORESPORE_QSDK_R23D21_POWERSHELL"
)

. (Join-Path $sdkRoot "content_addressed_artifact_store.ps1")
. (Join-Path $sdkRoot "locomotion_operation_lock.ps1")
. (Join-Path $sdkRoot "locomotion_campaign_attestation_adoption.ps1")
. (Join-Path $sdkRoot "r23d3_reproducible_runtime_materialization.ps1")

function Assert-R23D21 {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function Get-R23D21RawSha256 {
    param([Parameter(Mandatory)][string]$Path)
    return "sha256:" + (
        Get-FileHash -LiteralPath $Path -Algorithm SHA256
    ).Hash.ToLowerInvariant()
}

function Invoke-R23D21Git {
    param([Parameter(Mandatory)][string[]]$Arguments)
    $output = @(& git -C $repoRoot @Arguments 2>&1)
    if ($LASTEXITCODE -ne 0) {
        throw "QSDK-R23D21 git failed: git $($Arguments -join ' '): $($output -join ' ')"
    }
    return ($output -join "`n").Trim()
}

function Resolve-R23D21Application {
    param([Parameter(Mandatory)][string]$Command)
    if ([IO.Path]::IsPathFullyQualified($Command)) {
        $resolved = [IO.Path]::GetFullPath($Command)
    } else {
        $applications = @(Get-Command `
            -Name $Command -CommandType Application -All -ErrorAction Stop)
        Assert-R23D21 ($applications.Count -gt 0) (
            "QSDK-R23D21 application did not resolve: $Command"
        )
        $resolved = [IO.Path]::GetFullPath([string]$applications[0].Source)
    }
    Assert-R23D21 (Test-Path -LiteralPath $resolved -PathType Leaf) (
        "QSDK-R23D21 application is missing: $resolved"
    )
    return $resolved
}

function Write-R23D21NewJson {
    param([Parameter(Mandatory)][string]$Path, [Parameter(Mandatory)]$Value)
    Assert-R23D21 (-not (Test-Path -LiteralPath $Path)) (
        "QSDK-R23D21 create-only JSON path already exists: $Path"
    )
    $json = $Value | ConvertTo-Json -Depth 100
    [IO.File]::WriteAllText($Path, $json + "`n", [Text.UTF8Encoding]::new($false))
}

function Invoke-R23D21Process {
    param(
        [Parameter(Mandatory)][string]$FileName,
        [Parameter(Mandatory)][string[]]$Arguments,
        [Parameter(Mandatory)][string]$WorkingDirectory,
        [Collections.IDictionary]$Environment = @{},
        [int]$TimeoutSeconds = 900
    )
    $start = [Diagnostics.ProcessStartInfo]::new()
    $start.FileName = $FileName
    $start.WorkingDirectory = $WorkingDirectory
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    foreach ($name in $attemptEnvironmentNames) { [void]$start.Environment.Remove($name) }
    foreach ($entry in $Environment.GetEnumerator()) {
        $start.Environment[[string]$entry.Key] = [string]$entry.Value
    }
    foreach ($argument in $Arguments) { [void]$start.ArgumentList.Add($argument) }
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $start
    $clock = [Diagnostics.Stopwatch]::StartNew()
    Assert-R23D21 $process.Start() "QSDK-R23D21 process failed to start: $FileName"
    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()
    $timedOut = $false
    $heartbeat = 30.0
    while (-not $process.WaitForExit(1000)) {
        if ($clock.Elapsed.TotalSeconds -ge $heartbeat) {
            Write-Host (
                "QSDK_R23D21_PROGRESS process=$([IO.Path]::GetFileName($FileName)) " +
                "elapsed_seconds=$($clock.Elapsed.TotalSeconds.ToString('F1', [Globalization.CultureInfo]::InvariantCulture))"
            )
            $heartbeat += 30.0
        }
        if ($clock.Elapsed.TotalSeconds -ge $TimeoutSeconds) {
            $timedOut = $true
            try { $process.Kill($true) } catch { }
            [void]$process.WaitForExit(10000)
            break
        }
    }
    $clock.Stop()
    $result = [ordered]@{
        exit_code = if ($process.HasExited) { $process.ExitCode } else { -1 }
        timed_out = $timedOut
        duration_seconds = $clock.Elapsed.TotalSeconds
        stdout = $stdoutTask.GetAwaiter().GetResult()
        stderr = $stderrTask.GetAwaiter().GetResult()
    }
    $process.Dispose()
    return $result
}

function Get-R23D21Marker {
    param([Parameter(Mandatory)][string]$Text, [Parameter(Mandatory)][string]$Prefix)
    $matches = @($Text -split "`r?`n" | Where-Object {
        $_.StartsWith($Prefix, [StringComparison]::Ordinal)
    })
    Assert-R23D21 ($matches.Count -eq 1) (
        "QSDK-R23D21 expected one '$Prefix' marker; observed $($matches.Count)"
    )
    return $matches[0].Substring($Prefix.Length) |
        ConvertFrom-Json -AsHashtable -Depth 100
}

function Resolve-R23D21WorkerTerminal {
    param(
        [Parameter(Mandatory)]$ProcessResult,
        [Parameter(Mandatory)][string]$ExpectedCellId,
        [Parameter(Mandatory)][string]$ExpectedArmId,
        [Parameter(Mandatory)][string]$ExpectedSourceCommit
    )
    if ([bool]$ProcessResult.timed_out) {
        return [ordered]@{ ok = $false; failure_code = "R23D21_WORKER_TIMED_OUT" }
    }
    try {
        $terminal = Get-R23D21Marker -Text ([string]$ProcessResult.stdout) `
            -Prefix "QSDK_R23D21_GODOT_JOLT_TERMINAL "
    } catch {
        return [ordered]@{
            ok = $false
            failure_code = "R23D21_WORKER_TERMINAL_PARSE_INVALID"
            failure_detail = $_.Exception.Message
        }
    }
    $commonIdentity = (
        [string]$terminal.campaign_id -ceq $campaignId -and
        [string]$terminal.gate_id -ceq $gateId -and
        [string]$terminal.stage_id -ceq $stageId -and
        [string]$terminal.cell_id -ceq $ExpectedCellId -and
        [string]$terminal.engine_id -ceq "godot_jolt" -and
        [string]$terminal.arm_id -ceq $ExpectedArmId -and
        [string]$terminal.source_commit -ceq $ExpectedSourceCommit
    )
    if (-not $commonIdentity) {
        return [ordered]@{ ok = $false; failure_code = "R23D21_WORKER_TERMINAL_IDENTITY_INVALID" }
    }
    $schema = [string]$terminal.schema_version
    $exitCode = [int]$ProcessResult.exit_code
    if ($schema -ceq "sporespore_qsdk_r23d21_engine_cell_report_v1") {
        if ($exitCode -ne 0) {
            return [ordered]@{
                ok = $false
                failure_code = "R23D21_WORKER_REPORT_EXIT_MISMATCH"
            }
        }
        return [ordered]@{
            ok = $true
            failure_code = ""
            marker_kind = "worker_report_terminal"
            terminal = $terminal
        }
    }
    if ($schema -ceq "sporespore_qsdk_r23d21_worker_failure_v1") {
        $attempts = [int]$terminal.world_attempt_count
        $builds = [int]$terminal.world_build_count
        if (
            $exitCode -ne 1 -or
            [string]::IsNullOrWhiteSpace([string]$terminal.failure_code) -or
            [string]::IsNullOrWhiteSpace([string]$terminal.failure_stage) -or
            $attempts -lt 0 -or $attempts -gt 1 -or
            $builds -lt 0 -or $builds -gt $attempts
        ) {
            return [ordered]@{
                ok = $false
                failure_code = "R23D21_WORKER_FAILURE_EXIT_OR_SHAPE_MISMATCH"
            }
        }
        return [ordered]@{
            ok = $true
            failure_code = ""
            marker_kind = "worker_failure_terminal"
            terminal = $terminal
        }
    }
    return [ordered]@{ ok = $false; failure_code = "R23D21_WORKER_TERMINAL_SCHEMA_INVALID" }
}

function Get-R23D21Implementation {
    $value = Get-Content -Raw -LiteralPath $implementationPath |
        ConvertFrom-Json -AsHashtable -Depth 100
    Assert-R23D21 (
        [string]$value.schema_version -ceq
            "sporespore_qsdk_r23d21_physical_implementation_contract_v1" -and
        [string]$value.campaign_id -ceq $campaignId -and
        [string]$value.gate_id -ceq $gateId -and
        [string]$value.supervisor.path -ceq "sdk/run_qsdk_r23d21_supervisor.ps1" -and
        [string]$value.supervisor.stage_id -ceq $stageId -and
        [int]$value.supervisor.declared_world_count -eq 3 -and
        (@($value.supervisor.ordered_matrix_cell_ids) -join "|") -ceq ($cellIds -join "|") -and
        [bool]$value.supervisor.all_cells_serial_without_outcome_early_stop -and
        -not [bool]$value.supervisor.parallel_execution_permitted -and
        -not [bool]$value.supervisor.replacement_or_selective_rerun_permitted -and
        -not [bool]$value.authorization.physical_execution_authorized
    ) "QSDK-R23D21 implementation contract identity changed"
    return $value
}

function Get-R23D21SourceBindings {
    param([Parameter(Mandatory)]$Implementation)
    $paths = @($Implementation.dependency_closure.required_dependency_paths_by_worker.godot_jolt)
    Assert-R23D21 ($paths.Count -gt 0 -and $paths.Count -eq @($paths | Sort-Object -Unique).Count) (
        "QSDK-R23D21 dependency set is empty or duplicated"
    )
    $head = Invoke-R23D21Git @("rev-parse", "HEAD")
    $bindings = @()
    foreach ($relativePath in $paths) {
        $absolute = Join-Path $repoRoot ([string]$relativePath)
        Assert-R23D21 (Test-Path -LiteralPath $absolute -PathType Leaf) (
            "QSDK-R23D21 required dependency is missing: $relativePath"
        )
        $blob = Invoke-R23D21Git @("rev-parse", "$head`:$relativePath")
        $checkout = Invoke-R23D21Git @("hash-object", "--no-filters", "--", $relativePath)
        Assert-R23D21 ($blob -ceq $checkout) (
            "QSDK-R23D21 checkout bytes differ from the frozen Git blob: $relativePath"
        )
        $bindings += [ordered]@{
            path = [string]$relativePath
            git_blob_oid = $blob
            raw_sha256 = Get-R23D21RawSha256 $absolute
        }
    }
    return $bindings
}

function Invoke-R23D21ZeroWorld {
    param([Parameter(Mandatory)][string]$PythonPath)
    $traceCode = @'
import json
from sdk.turning import r23d21_physical_trace as trace
from sdk.turning import r23d21_physical_evaluator as evaluator
evaluator._load_declaration()
print("QSDK_R23D21_PYTHON_PREFLIGHT " + json.dumps(trace.zero_world_receipt(), separators=(",", ":")))
'@
    $pythonResult = Invoke-R23D21Process -FileName $PythonPath `
        -Arguments @("-c", $traceCode) -WorkingDirectory $repoRoot -TimeoutSeconds 300
    Assert-R23D21 (
        -not [bool]$pythonResult.timed_out -and [int]$pythonResult.exit_code -eq 0
    ) "QSDK-R23D21 Python zero-world gate failed: $($pythonResult.stderr)"
    $pythonReceipt = Get-R23D21Marker `
        -Text ([string]$pythonResult.stdout) -Prefix "QSDK_R23D21_PYTHON_PREFLIGHT "
    Assert-R23D21 (
        [int]$pythonReceipt.matrix_cell_count -eq 3 -and
        [int]$pythonReceipt.trace_row_count_per_cell -eq 3952 -and
        [int]$pythonReceipt.world_build_count -eq 0
    ) "QSDK-R23D21 Python zero-world receipt changed"
    $godotReceipts = @()
    foreach ($arm in $arms) {
        $result = Invoke-R23D21Process -FileName $Godot -WorkingDirectory $repoRoot `
            -TimeoutSeconds 300 -Arguments @(
                "--headless", "--path", $repoRoot,
                "--log-file", (Join-Path $sdkRoot "target\r23d21-supervisor-preflight-$arm.log"),
                "--script", $workerResource, "--", "--preflight-only",
                "--stage", $stageId, "--arm", $arm
            )
        Assert-R23D21 (
            -not [bool]$result.timed_out -and [int]$result.exit_code -eq 0
        ) "QSDK-R23D21 Godot zero-world gate failed for $arm`: $($result.stderr)"
        $receipt = Get-R23D21Marker -Text ([string]$result.stdout) `
            -Prefix "QSDK_R23D21_GODOT_JOLT_PREFLIGHT "
        Assert-R23D21 (
            [string]$receipt.arm_id -ceq $arm -and
            [int]$receipt.world_build_count -eq 0 -and
            -not [bool]$receipt.physical_execution_authorized
        ) "QSDK-R23D21 Godot preflight receipt changed for $arm"
        $godotReceipts += $receipt
    }
    return [ordered]@{
        schema_version = "sporespore_qsdk_r23d21_complete_zero_world_v1"
        campaign_id = $campaignId
        gate_id = $gateId
        python = $pythonReceipt
        godot_jolt = $godotReceipts
        physical_process_launch_count = 0
        model_construction_count = 0
        world_attempt_count = 0
        world_build_count = 0
        physical_execution_authorized = $false
        physical_acceptance_authority = $false
    }
}

Assert-R23D21 (
    @(@($PreflightOnly, $CampaignRolePreflight, $RunPhysical) |
        Where-Object { $_.IsPresent }).Count -eq 1
) "Specify exactly one of -PreflightOnly, -CampaignRolePreflight, or -RunPhysical"
Assert-R23D21 (
    (Invoke-R23D21Git @("rev-parse", "--show-toplevel")).Replace("/", "\") -ceq $repoRoot -and
    (Invoke-R23D21Git @("remote", "get-url", "origin")) -ceq
        "https://github.com/Slagathore/sporespore.git"
) "QSDK-R23D21 repository identity mismatch"
foreach ($path in @($implementationPath, $preregistrationPath, $evaluatorPath, $Godot)) {
    Assert-R23D21 (Test-Path -LiteralPath $path -PathType Leaf) (
        "QSDK-R23D21 required input is missing: $path"
    )
}
if ($RunPhysical -and (Test-Path -LiteralPath $closurePath -PathType Leaf)) {
    throw "QSDK-R23D21 CLOSED: the one-shot identity is consumed"
}
$resolvedPython = Resolve-R23D21Application $Python
$resolvedPowerShell = Resolve-R23D21Application $PowerShell
$implementation = Get-R23D21Implementation

if ($CampaignRolePreflight) {
    $canarySource = "1" * 40
    $canaryCell = $cellIds[0]
    $canaryArm = $arms[0]
    $failureTerminal = [ordered]@{
        schema_version = "sporespore_qsdk_r23d21_worker_failure_v1"
        campaign_id = $campaignId
        gate_id = $gateId
        stage_id = $stageId
        cell_id = $canaryCell
        engine_id = "godot_jolt"
        arm_id = $canaryArm
        source_commit = $canarySource
        failure_code = "QSDK_R23D21_GJT_TRACE_INCOMPLETE"
        failure_stage = "settlement_complete"
        world_attempt_count = 1
        world_build_count = 1
    }
    $markerPrefix = "QSDK_R23D21_GODOT_JOLT_TERMINAL "
    $failureJson = $failureTerminal | ConvertTo-Json -Depth 20 -Compress
    $positiveProjection = Resolve-R23D21WorkerTerminal -ProcessResult ([ordered]@{
        exit_code = 1; timed_out = $false; stdout = $markerPrefix + $failureJson
    }) -ExpectedCellId $canaryCell -ExpectedArmId $canaryArm `
        -ExpectedSourceCommit $canarySource
    Assert-R23D21 (
        [bool]$positiveProjection.ok -and
        [string]$positiveProjection.marker_kind -ceq "worker_failure_terminal" -and
        [int]$positiveProjection.terminal.world_attempt_count -eq 1 -and
        [int]$positiveProjection.terminal.world_build_count -eq 1 -and
        [string]$positiveProjection.terminal.failure_stage -ceq "settlement_complete"
    ) "QSDK-R23D21 nonzero-exit structured worker failure was not retained losslessly"

    $wrongIdentity = $failureTerminal | ConvertTo-Json -Depth 20 |
        ConvertFrom-Json -AsHashtable -Depth 20
    $wrongIdentity.cell_id = $cellIds[1]
    $reportOnFailureExit = $failureTerminal | ConvertTo-Json -Depth 20 |
        ConvertFrom-Json -AsHashtable -Depth 20
    $reportOnFailureExit.schema_version = "sporespore_qsdk_r23d21_engine_cell_report_v1"
    $wrongSchema = $failureTerminal | ConvertTo-Json -Depth 20 |
        ConvertFrom-Json -AsHashtable -Depth 20
    $wrongSchema.schema_version = "sporespore_qsdk_r23d21_unknown_terminal_v1"
    $mutations = @(
        [ordered]@{ exit_code = 1; timed_out = $false; stdout = "" },
        [ordered]@{
            exit_code = 1; timed_out = $false
            stdout = ($markerPrefix + $failureJson + "`n" + $markerPrefix + $failureJson)
        },
        [ordered]@{ exit_code = 1; timed_out = $false; stdout = $markerPrefix + "{" },
        [ordered]@{
            exit_code = 1; timed_out = $false
            stdout = $markerPrefix + ($wrongIdentity | ConvertTo-Json -Depth 20 -Compress)
        },
        [ordered]@{ exit_code = 0; timed_out = $false; stdout = $markerPrefix + $failureJson },
        [ordered]@{
            exit_code = 1; timed_out = $false
            stdout = $markerPrefix + ($reportOnFailureExit | ConvertTo-Json -Depth 20 -Compress)
        },
        [ordered]@{
            exit_code = 1; timed_out = $false
            stdout = $markerPrefix + ($wrongSchema | ConvertTo-Json -Depth 20 -Compress)
        }
    )
    foreach ($mutation in $mutations) {
        $projection = Resolve-R23D21WorkerTerminal -ProcessResult $mutation `
            -ExpectedCellId $canaryCell -ExpectedArmId $canaryArm `
            -ExpectedSourceCommit $canarySource
        Assert-R23D21 (-not [bool]$projection.ok) (
            "QSDK-R23D21 worker-terminal mutation was not refused"
        )
    }
    $receipt = [ordered]@{
        schema_version = "sporespore_qsdk_r23d21_campaign_supervisor_role_preflight_v1"
        campaign_id = $campaignId
        gate_id = $gateId
        declared_world_count = 3
        ordered_matrix_cell_ids = $cellIds
        nonzero_exit_structured_failure_retention_canary_count = 1
        worker_terminal_mutation_control_count = $mutations.Count
        all_cells_serial_without_outcome_early_stop = $true
        physical_process_launch_count = 0
        model_construction_count = 0
        world_attempt_count = 0
        world_build_count = 0
        physical_execution_authorized = $false
        physical_acceptance_authority = $false
    }
    Write-Host (
        "QSDK_R23D21_CAMPAIGN_SUPERVISOR_ROLE_PASS " +
        ($receipt | ConvertTo-Json -Depth 20 -Compress)
    )
    return
}

$zeroWorld = Invoke-R23D21ZeroWorld -PythonPath $resolvedPython
if ($PreflightOnly) {
    Write-Host (
        "QSDK_R23D21_SUPERVISOR_PREFLIGHT_PASS " +
        ($zeroWorld | ConvertTo-Json -Depth 100 -Compress)
    )
    return
}

Assert-R23D21 (-not [string]::IsNullOrWhiteSpace($CampaignAttestationAdoption)) (
    "QSDK-R23D21 physical execution requires a commissioned LCA1 adoption receipt"
)
Assert-R23D21 (Test-Path -LiteralPath $manifestPath -PathType Leaf) (
    "QSDK-R23D21 campaign-attestation manifest is missing"
)
$source = Get-SporeSporeAttestationSourceIdentity -RepoRoot $repoRoot -RequireCleanPushedLive
$attestation = Test-SporeSporeCampaignAttestationAdoptionFile `
    -RepoRoot $repoRoot -ManifestPath $manifestPath -Godot $Godot -Python $resolvedPython `
    -ExpectedCampaignId $campaignId -AdoptionPath $CampaignAttestationAdoption
Assert-R23D21 ([bool]$attestation.ok) (
    "QSDK-R23D21 campaign-attestation adoption is invalid: $(@($attestation.failure_codes) -join ',')"
)
$sourceAfterPreflight = Get-SporeSporeAttestationSourceIdentity `
    -RepoRoot $repoRoot -RequireCleanPushedLive
Assert-R23D21 (
    [string]$sourceAfterPreflight.commit -ceq [string]$source.commit -and
    [string]$sourceAfterPreflight.tree_git_oid -ceq [string]$source.tree_git_oid
) "QSDK-R23D21 source changed during preflight"

$operationLock = Enter-SporeSporeLocomotionOperationLock `
    -Role physical -TimeoutMilliseconds 0
Assert-R23D21 ([bool]$operationLock.acquired) (
    "QSDK-R23D21 physical operation lock is already held"
)
$attemptConsumed = $false
$attemptRoot = $null
$attemptId = $null
$terminalPaths = @()
$completionPath = $null
try {
    $evidenceRoot = Get-SporeSporeArtifactEvidenceRoot -RepoRoot $repoRoot
    $prior = @()
    if (Test-Path -LiteralPath $evidenceRoot -PathType Container) {
        $prior = @(Get-ChildItem -LiteralPath $evidenceRoot -Directory | Where-Object {
            $_.Name -like "qsdk-r23d21-*" -and
            (Test-Path -LiteralPath (Join-Path $_.FullName "matrix-authorization.json"))
        })
    }
    Assert-R23D21 ($prior.Count -eq 0) "QSDK-R23D21 one-shot identity already exists"
    $attemptRoot = if ([string]::IsNullOrWhiteSpace($OutputRoot)) {
        Join-Path $evidenceRoot ("qsdk-r23d21-" + [DateTime]::UtcNow.ToString("yyyyMMddTHHmmssZ"))
    } else { [IO.Path]::GetFullPath($OutputRoot) }
    $prefix = $evidenceRoot.TrimEnd("\", "/") + [IO.Path]::DirectorySeparatorChar
    Assert-R23D21 (
        $attemptRoot.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase) -and
        -not (Test-Path -LiteralPath $attemptRoot)
    ) "QSDK-R23D21 output must be a new directory below $evidenceRoot"
    [void][IO.Directory]::CreateDirectory($attemptRoot)

    $targetRoot = Join-Path $sdkRoot "target"
    $coreBuild = Invoke-SporeSporeR23D3PinnedCargo -RepoRoot $repoRoot `
        -SourceCommit ([string]$source.commit) -TargetRoot $targetRoot -CargoArguments @(
            "build", "--quiet", "--release", "--locked", "--offline",
            "--manifest-path", (Join-Path $sdkRoot "Cargo.toml"),
            "--package", "sporespore-locomotion-core"
        )
    $adapterBuild = Invoke-SporeSporeR23D3PinnedCargo -RepoRoot $repoRoot `
        -SourceCommit ([string]$source.commit) -TargetRoot $targetRoot -CargoArguments @(
            "build", "--quiet", "--locked", "--offline",
            "--manifest-path", (Join-Path $sdkRoot "Cargo.toml"),
            "--package", "sporespore-godot-adapter"
        )
    $runtimePaths = @(
        Join-Path $targetRoot "release\sporespore_locomotion_core.dll"
        Join-Path $targetRoot "debug\sporespore_godot_adapter.dll"
    )
    foreach ($runtime in $runtimePaths) {
        Assert-R23D21 (Test-Path -LiteralPath $runtime -PathType Leaf) (
            "QSDK-R23D21 materialized runtime is missing: $runtime"
        )
    }
    $sourceBindings = @(Get-R23D21SourceBindings $implementation)
    $inputCas = @()
    foreach ($binding in $sourceBindings) {
        $inputCas += Publish-SporeSporeContentAddressedArtifact `
            -RepoRoot $repoRoot -ArtifactPath (Join-Path $repoRoot ([string]$binding.path)) `
            -MediaType "application/octet-stream"
    }
    $runtimeArtifacts = @()
    foreach ($runtime in $runtimePaths) {
        $runtimeArtifacts += [ordered]@{
            path = $runtime
            raw_sha256 = Get-R23D21RawSha256 $runtime
            cas = Publish-SporeSporeContentAddressedArtifact `
                -RepoRoot $repoRoot -ArtifactPath $runtime `
                -MediaType "application/vnd.microsoft.portable-executable"
        }
    }
    $attestationCas = Publish-SporeSporeContentAddressedArtifact `
        -RepoRoot $repoRoot -ArtifactPath $CampaignAttestationAdoption `
        -MediaType "application/json"

    $freeze = [ordered]@{
        schema_version = "sporespore_qsdk_r23d21_physical_freeze_v1"
        status = "frozen_supervisor_only_physical_authorized"
        campaign_id = $campaignId
        gate_id = $gateId
        preregistration_raw_sha256 = Get-R23D21RawSha256 $preregistrationPath
        implementation_contract_raw_sha256 = Get-R23D21RawSha256 $implementationPath
        source_commit = [string]$source.commit
        source_tree_git_oid = [string]$source.tree_git_oid
        source_bindings = $sourceBindings
        runtime_artifacts = $runtimeArtifacts
        reproducible_builds = [ordered]@{ core = $coreBuild; godot_adapter = $adapterBuild }
        content_addressed_inputs = $inputCas
        campaign_attestation_adoption = $attestationCas
        complete_zero_world_gate_passed = $true
        zero_world_receipt = $zeroWorld
        declared_matrix_world_count = 3
        ordered_matrix_cell_ids = $cellIds
        serial_execution_required = $true
        physical_execution_authorized = $true
        physical_acceptance_authority = $false
    }
    $freezePath = Join-Path $attemptRoot "physical-freeze.json"
    Write-R23D21NewJson -Path $freezePath -Value $freeze
    $freezeCas = Publish-SporeSporeContentAddressedArtifact `
        -RepoRoot $repoRoot -ArtifactPath $freezePath -MediaType "application/json"
    $attemptId = [guid]::NewGuid().ToString("N")
    $token = [guid]::NewGuid().ToString("N")
    $attempt = [ordered]@{
        schema_version = "sporespore_qsdk_r23d21_attempt_v1"
        attempt_id = $attemptId
        campaign_id = $campaignId
        gate_id = $gateId
        freeze_raw_sha256 = [string]$freezeCas.sha256
        source_commit = [string]$source.commit
        authorization_token = $token
        attempt_root = $attemptRoot
        ordered_matrix_cell_ids = $cellIds
        physical_execution_authorized = $true
        single_use_supervisor_authorization = $true
        matrix_authorization_immutable_before_first_world = $true
        source_worktree_clean = $true
        source_matches_live_github_main = $true
        operation_lock_held = $true
        campaign_attestation_adoption_valid = $true
        content_addressed_inputs_retained = $true
        complete_zero_world_gate_passed = $true
        one_shot_attempt_unconsumed = $true
        replacement_or_selective_rerun_permitted = $false
        all_cells_execute_without_outcome_based_early_stop = $true
        parallel_execution_permitted = $false
        physical_acceptance_authority = $false
    }
    $attemptPath = Join-Path $attemptRoot "matrix-authorization.json"
    Write-R23D21NewJson -Path $attemptPath -Value $attempt
    $attemptCas = Publish-SporeSporeContentAddressedArtifact `
        -RepoRoot $repoRoot -ArtifactPath $attemptPath -MediaType "application/json"
    # Crossing this boundary consumes the preregistered one-shot identity even if
    # a later process, evaluator, or evidence-writing operation fails.
    $attemptConsumed = $true

    $cellRetentions = @()
    foreach ($arm in $arms) {
        $cellId = "godot_jolt__tight_gated_horizon__$arm"
        $cellRoot = Join-Path $attemptRoot "matrix\$cellId"
        [void][IO.Directory]::CreateDirectory($cellRoot)
        $environment = [ordered]@{
            SPORESPORE_QSDK_R23D21_FREEZE = [string]$freezeCas.payload_path
            SPORESPORE_QSDK_R23D21_ATTEMPT = [string]$attemptCas.payload_path
            SPORESPORE_QSDK_R23D21_TOKEN = $token
            SPORESPORE_QSDK_R23D21_STAGE = $stageId
            SPORESPORE_QSDK_R23D21_CELL = $cellId
            SPORESPORE_QSDK_R23D21_ENGINE = "godot_jolt"
            SPORESPORE_QSDK_R23D21_ATTEMPT_ROOT = $attemptRoot
            SPORESPORE_QSDK_R23D21_PYTHON = $resolvedPython
            SPORESPORE_QSDK_R23D21_POWERSHELL = $resolvedPowerShell
            APPDATA = Join-Path $cellRoot "appdata"
            LOCALAPPDATA = Join-Path $cellRoot "localappdata"
        }
        [void][IO.Directory]::CreateDirectory($environment.APPDATA)
        [void][IO.Directory]::CreateDirectory($environment.LOCALAPPDATA)
        Write-Host "QSDK_R23D21_CELL_BEGIN cell=$cellId"
        $result = Invoke-R23D21Process -FileName $Godot -WorkingDirectory $repoRoot `
            -Environment $environment -TimeoutSeconds $CellTimeoutSeconds -Arguments @(
                "--headless", "--path", $repoRoot,
                "--log-file", (Join-Path $cellRoot "godot.log"),
                "--script", $workerResource, "--", "--stage", $stageId,
                "--arm", $arm, "--source-commit", [string]$source.commit
            )
        $stdoutPath = Join-Path $cellRoot "stdout.txt"
        $stderrPath = Join-Path $cellRoot "stderr.txt"
        [IO.File]::WriteAllText($stdoutPath, [string]$result.stdout, [Text.UTF8Encoding]::new($false))
        [IO.File]::WriteAllText($stderrPath, [string]$result.stderr, [Text.UTF8Encoding]::new($false))
        $stdoutCas = Publish-SporeSporeContentAddressedArtifact `
            -RepoRoot $repoRoot -ArtifactPath $stdoutPath -MediaType "text/plain"
        $stderrCas = Publish-SporeSporeContentAddressedArtifact `
            -RepoRoot $repoRoot -ArtifactPath $stderrPath -MediaType "text/plain"
        $godotLogCas = Publish-SporeSporeContentAddressedArtifact `
            -RepoRoot $repoRoot -ArtifactPath (Join-Path $cellRoot "godot.log") `
            -MediaType "text/plain"
        $projection = Resolve-R23D21WorkerTerminal -ProcessResult $result `
            -ExpectedCellId $cellId -ExpectedArmId $arm `
            -ExpectedSourceCommit ([string]$source.commit)
        $terminal = $null
        $markerKind = "supervisor_process_failure"
        if ([bool]$projection.ok) {
            $terminal = $projection.terminal
            $markerKind = [string]$projection.marker_kind
        } else {
            $terminal = [ordered]@{
                schema_version = "sporespore_qsdk_r23d21_supervisor_process_failure_v1"
                campaign_id = $campaignId
                gate_id = $gateId
                stage_id = $stageId
                cell_id = $cellId
                engine_id = "godot_jolt"
                arm_id = $arm
                source_commit = [string]$source.commit
                process_exit_code = [int]$result.exit_code
                process_timed_out = [bool]$result.timed_out
                terminal_projection_failure_code = [string]$projection.failure_code
                terminal_projection_failure_detail = if ($projection.Contains("failure_detail")) {
                    [string]$projection.failure_detail
                } else { "" }
                world_attempt_count_known = $false
                world_build_count_known = $false
                physical_acceptance_authority = $false
            }
        }
        $terminalPath = Join-Path $cellRoot "terminal-entry.json"
        Write-R23D21NewJson -Path $terminalPath -Value $terminal
        $terminalCas = Publish-SporeSporeContentAddressedArtifact `
            -RepoRoot $repoRoot -ArtifactPath $terminalPath -MediaType "application/json"
        $terminalPaths += [string]$terminalCas.payload_path
        $cellRetentions += [ordered]@{
            cell_id = $cellId
            process = $result
            marker_kind = $markerKind
            stdout_cas = $stdoutCas
            stderr_cas = $stderrCas
            godot_log_cas = $godotLogCas
            terminal_cas = $terminalCas
        }
        Write-Host "QSDK_R23D21_CELL_RETAINED cell=$cellId marker=$markerKind"
    }

    $manifest = Join-Path $attemptRoot "matrix-terminal-paths.json"
    Write-R23D21NewJson -Path $manifest -Value $terminalPaths
    $evaluationResult = Invoke-R23D21Process -FileName $resolvedPython `
        -WorkingDirectory $repoRoot -TimeoutSeconds 300 -Arguments @(
            $evaluatorPath, "evaluate-complete", "--manifest", $manifest,
            "--expected-source-commit", [string]$source.commit
        )
    $evaluationStdout = Join-Path $attemptRoot "evaluator-stdout.txt"
    $evaluationStderr = Join-Path $attemptRoot "evaluator-stderr.txt"
    [IO.File]::WriteAllText($evaluationStdout, [string]$evaluationResult.stdout, [Text.UTF8Encoding]::new($false))
    [IO.File]::WriteAllText($evaluationStderr, [string]$evaluationResult.stderr, [Text.UTF8Encoding]::new($false))
    [void](Publish-SporeSporeContentAddressedArtifact `
        -RepoRoot $repoRoot -ArtifactPath $evaluationStdout -MediaType "text/plain")
    [void](Publish-SporeSporeContentAddressedArtifact `
        -RepoRoot $repoRoot -ArtifactPath $evaluationStderr -MediaType "text/plain")
    Assert-R23D21 (
        -not [bool]$evaluationResult.timed_out -and [int]$evaluationResult.exit_code -eq 0
    ) "QSDK-R23D21 evaluator failed after all terminal entries were retained"
    $evaluation = Get-R23D21Marker -Text ([string]$evaluationResult.stdout) `
        -Prefix "QSDK_R23D21_COMPLETE_EVALUATION "
    $evaluationPath = Join-Path $attemptRoot "evaluation.json"
    Write-R23D21NewJson -Path $evaluationPath -Value $evaluation
    $evaluationCas = Publish-SporeSporeContentAddressedArtifact `
        -RepoRoot $repoRoot -ArtifactPath $evaluationPath -MediaType "application/json"
    $report = [ordered]@{
        schema_version = "sporespore_qsdk_r23d21_campaign_report_v1"
        campaign_id = $campaignId
        gate_id = $gateId
        source = $source
        attempt_id = $attemptId
        freeze_cas = $freezeCas
        matrix_authorization_cas = $attemptCas
        ordered_matrix_cells = $cellRetentions
        complete_evaluation = $evaluation
        complete_evaluation_cas = $evaluationCas
        result_classification = [string]$evaluation.classification
        finite_godot_mechanism_candidate = (
            [string]$evaluation.classification -ceq "valid_complete_positive"
        )
        portable_basic_turning = $false
        cross_engine_equivalence = $false
        release_authorized = $false
        physical_acceptance_authority = $false
    }
    $reportPath = Join-Path $attemptRoot "report.json"
    Write-R23D21NewJson -Path $reportPath -Value $report
    $reportCas = Publish-SporeSporeContentAddressedArtifact `
        -RepoRoot $repoRoot -ArtifactPath $reportPath -MediaType "application/json"
    $completion = [ordered]@{
        schema_version = "sporespore_qsdk_r23d21_completion_v1"
        campaign_id = $campaignId
        gate_id = $gateId
        status = "$([string]$evaluation.classification)_first_attempt"
        source_commit = [string]$source.commit
        attempt_id = $attemptId
        matrix_terminal_entry_count = $terminalPaths.Count
        result_classification = [string]$evaluation.classification
        report_cas = $reportCas
        one_shot_identity_consumed = $true
        same_identity_rerun_allowed = $false
        portable_basic_turning = $false
        cross_engine_equivalence = $false
        release_authorized = $false
        physical_acceptance_authority = $false
    }
    $completionPath = Join-Path $attemptRoot "completion.json"
    Write-R23D21NewJson -Path $completionPath -Value $completion
    $completionCas = Publish-SporeSporeContentAddressedArtifact `
        -RepoRoot $repoRoot -ArtifactPath $completionPath -MediaType "application/json"
    Write-Host (
        "QSDK_R23D21_PHYSICAL_COMPLETE classification=$([string]$evaluation.classification) " +
        "matrix_cells=$($terminalPaths.Count) report_sha256=$([string]$reportCas.sha256) " +
        "completion_sha256=$([string]$completionCas.sha256)"
    )
} catch {
    $originalError = $_
    if (
        $attemptConsumed -and
        -not [string]::IsNullOrWhiteSpace([string]$attemptRoot) -and
        -not (Test-Path -LiteralPath (Join-Path $attemptRoot "completion.json"))
    ) {
        try {
            $emergencyCompletion = [ordered]@{
                schema_version = "sporespore_qsdk_r23d21_completion_v1"
                campaign_id = $campaignId
                gate_id = $gateId
                status = "invalid_incomplete_supervisor_error_first_attempt"
                source_commit = [string]$source.commit
                attempt_id = [string]$attemptId
                matrix_terminal_entry_count = @($terminalPaths).Count
                result_classification = "invalid_incomplete"
                supervisor_error_type = [string]$originalError.Exception.GetType().FullName
                supervisor_error = [string]$originalError.Exception.Message
                one_shot_identity_consumed = $true
                same_identity_rerun_allowed = $false
                portable_basic_turning = $false
                cross_engine_equivalence = $false
                release_authorized = $false
                physical_acceptance_authority = $false
            }
            $completionPath = Join-Path $attemptRoot "completion.json"
            Write-R23D21NewJson -Path $completionPath -Value $emergencyCompletion
            $emergencyCompletionCas = Publish-SporeSporeContentAddressedArtifact `
                -RepoRoot $repoRoot -ArtifactPath $completionPath -MediaType "application/json"
            Write-Host (
                "QSDK_R23D21_PHYSICAL_INCOMPLETE classification=invalid_incomplete " +
                "matrix_cells=$(@($terminalPaths).Count) " +
                "completion_sha256=$([string]$emergencyCompletionCas.sha256)"
            )
        } catch {
            Write-Warning (
                "QSDK-R23D21 could not retain its emergency completion after consuming " +
                "the one-shot identity: $($_.Exception.Message)"
            )
        }
    }
    throw $originalError
} finally {
    Exit-SporeSporeLocomotionOperationLock -Receipt $operationLock
}
