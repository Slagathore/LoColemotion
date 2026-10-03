#requires -Version 7.0

[CmdletBinding()]
param(
    [string]$Godot = (
        "C:\Users\Cole\CodeStuff\Misc\Godot\" +
        "Godot_v4.7-stable_mono_win64_console.exe"
    ),
    [string]$Python = "",
    [string]$PowerShell = "pwsh",
    [string]$Cargo = "",
    [switch]$ExpectProductionConformanceLockHeld
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$sdkRoot = [IO.Path]::GetFullPath($PSScriptRoot)
$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $sdkRoot))
$turningRoot = Join-Path $sdkRoot "turning"
$mujocoRoot = Join-Path $sdkRoot "adapters\mujoco"
$mujocoPython = Join-Path $mujocoRoot ".venv\Scripts\python.exe"
$sourceMaterializer = Join-Path $turningRoot "materialize_r23d74_native_bindings.py"
$implementationMaterializer = Join-Path $turningRoot "materialize_r23d74_implementation.py"
$implementationPath = Join-Path $turningRoot (
    "r23d74_production_route_three_engine_turning_implementation_v1.json"
)
$runtimeContractGate = Join-Path $repoRoot "tests\test_qsdk_r23d74_runtime_contract.py"
$successTerminalGate = Join-Path $repoRoot (
    "tests\test_qsdk_r23d74_success_terminal_projection_ghost.ps1"
)
$declarationAudit = Join-Path $sdkRoot (
    "audit_r23d74_fresh_finite_three_engine_turning_decision.ps1"
)
$evaluatorPath = Join-Path $turningRoot (
    "r23d74_production_route_three_engine_turning_evaluator.py"
)
$supervisor = Join-Path $sdkRoot "run_qsdk_r23d74_supervisor.ps1"
$authorizationReceiptGate = Join-Path $repoRoot (
    "tests\test_three_engine_authorization_receipt.ps1"
)
$operationLockGate = Join-Path $repoRoot "tests\test_locomotion_operation_lock.ps1"
$strictJsonGate = Join-Path $repoRoot "tests\test_strict_json_array_document.ps1"
$godotTerminationHelper = Join-Path $sdkRoot "godot_receipt_terminated_process.ps1"
$godotWorker = "res://tests/test_sdk_qsdk_r23d74_godot_jolt_worker.gd"
$mujocoModule = "sporespore_mujoco_adapter.qsdk_r23d74_turning_route"
$rapierManifest = Join-Path $sdkRoot "Cargo.toml"
$rapierBinary = Join-Path $sdkRoot "target\release\qsdk_r23d74_turning_route.exe"

$campaignId = "QSDK-R23D74-FRESH-FINITE-THREE-ENGINE-TURNING-DECISION"
$gateId = "QSDK-R23D74"
$stageId = "fresh_finite_three_engine_turning_decision"
$onsetId = "onset_600"
$campaignSeed = 23193
$profileId = "sporespore_qsdk_r23d60_selected_s169_actuator_cap_profile_v1"
$referenceArm = "reference_zero"
$invalidArm = "zero_world_invalid_arm"
$godotReadyMarker = "QSDK_R23D65_GODOT_SUPERVISOR_TERMINATION_READY "
$physicalEnvironmentNames = @(
    "SPORESPORE_QSDK_R23D74_FREEZE",
    "SPORESPORE_QSDK_R23D74_ATTEMPT",
    "SPORESPORE_QSDK_R23D74_TOKEN",
    "SPORESPORE_QSDK_R23D74_STAGE",
    "SPORESPORE_QSDK_R23D74_CELL",
    "SPORESPORE_QSDK_R23D74_ENGINE",
    "SPORESPORE_QSDK_R23D74_ATTEMPT_ROOT",
    "SPORESPORE_QSDK_R23D74_AUTHORITY_REPO_ROOT",
    "SPORESPORE_QSDK_R23D74_PYTHON",
    "SPORESPORE_QSDK_R23D74_POWERSHELL",
    "SPORESPORE_QSDK_R23D65_SUPERVISED_TERMINATION",
    "SPORESPORE_QSDK_R23D65_TERMINATION_NONCE",
    "SPORESPORE_QSDK_R23D65_FREEZE",
    "SPORESPORE_QSDK_R23D65_ATTEMPT",
    "SPORESPORE_QSDK_R23D60_FREEZE",
    "SPORESPORE_QSDK_R23D60_ATTEMPT",
    "SPORESPORE_QSDK_R23D59_FREEZE",
    "SPORESPORE_QSDK_R23D59_ATTEMPT",
    "SPORESPORE_QSDK_R23D58_FREEZE",
    "SPORESPORE_QSDK_R23D58_ATTEMPT",
    "SPORESPORE_QSDK_R23D48_FREEZE",
    "SPORESPORE_QSDK_R23D48_ATTEMPT"
)

. $godotTerminationHelper

function Assert-R23D74ZeroWorld([bool]$Condition, [string]$Message) {
    if (-not $Condition) {
        throw "QSDK-R23D74 ZERO-WORLD: $Message"
    }
}

function Resolve-R23D74Application([string]$Value, [string]$Fallback) {
    $candidate = if ([string]::IsNullOrWhiteSpace($Value)) { $Fallback } else { $Value }
    if (Test-Path -LiteralPath $candidate -PathType Leaf) {
        return [IO.Path]::GetFullPath($candidate)
    }
    $command = Get-Command $candidate -CommandType Application -ErrorAction Stop
    return [IO.Path]::GetFullPath($command.Source)
}

function Invoke-R23D74Process {
    param(
        [Parameter(Mandatory = $true)][string]$FileName,
        [Parameter(Mandatory = $true)][string[]]$Arguments,
        [Parameter(Mandatory = $true)][string]$WorkingDirectory,
        [ValidateRange(1, 3600)][int]$TimeoutSeconds = 900
    )
    $start = [Diagnostics.ProcessStartInfo]::new()
    $start.FileName = $FileName
    $start.WorkingDirectory = $WorkingDirectory
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    foreach ($argument in $Arguments) {
        [void]$start.ArgumentList.Add($argument)
    }
    foreach ($name in $physicalEnvironmentNames) {
        [void]$start.Environment.Remove($name)
    }
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $start
    try {
        Assert-R23D74ZeroWorld $process.Start() "could not start process: $FileName"
        $stdoutTask = $process.StandardOutput.ReadToEndAsync()
        $stderrTask = $process.StandardError.ReadToEndAsync()
        $completed = $process.WaitForExit($TimeoutSeconds * 1000)
        if (-not $completed) {
            try { $process.Kill($true) } catch { }
            $process.WaitForExit()
        }
        $stdout = $stdoutTask.GetAwaiter().GetResult()
        $stderr = $stderrTask.GetAwaiter().GetResult()
        Assert-R23D74ZeroWorld $completed (
            "process timed out after $TimeoutSeconds seconds: $FileName"
        )
        $lines = @(
            @($stdout -split "`r?`n") + @($stderr -split "`r?`n") |
                Where-Object { -not [string]::IsNullOrEmpty([string]$_) }
        )
        return [ordered]@{
            exit_code = [int]$process.ExitCode
            stdout = [string]$stdout
            stderr = [string]$stderr
            lines = @($lines)
            text = (@($lines) -join "`n")
        }
    } finally {
        $process.Dispose()
    }
}

function Get-R23D74MarkerJson($Process, [string]$Prefix) {
    $markers = @($Process.lines | Where-Object {
        ([string]$_).StartsWith($Prefix, [StringComparison]::Ordinal)
    })
    Assert-R23D74ZeroWorld ($markers.Count -eq 1) (
        "expected one '$Prefix' marker; exit=$($Process.exit_code); output=$($Process.text)"
    )
    return ([string]$markers[0]).Substring($Prefix.Length) |
        ConvertFrom-Json -AsHashtable -Depth 100
}

function Assert-R23D74NoWorld($Receipt, [string]$Label) {
    foreach ($key in @(
        "model_construction_count",
        "world_attempt_count",
        "world_build_count",
        "physical_acceptance_authority"
    )) {
        Assert-R23D74ZeroWorld (@($Receipt.Keys) -ccontains $key) (
            "$Label omitted zero-world field $key"
        )
    }
    $solverZero = (
        -not (@($Receipt.Keys) -ccontains "solver_step_count") -or
        [int]$Receipt.solver_step_count -eq 0
    )
    Assert-R23D74ZeroWorld (
        [int]$Receipt.model_construction_count -eq 0 -and
        [int]$Receipt.world_attempt_count -eq 0 -and
        [int]$Receipt.world_build_count -eq 0 -and
        $solverZero -and
        -not [bool]$Receipt.physical_acceptance_authority
    ) "$Label crossed the zero-world boundary"
}

function Invoke-R23D74PowerShellGate(
    [string]$Path,
    [string]$ExpectedText,
    [string[]]$AdditionalArguments = @(),
    [int]$TimeoutSeconds = 900
) {
    $arguments = @("-NoLogo", "-NoProfile", "-File", $Path) + @($AdditionalArguments)
    $result = Invoke-R23D74Process -FileName $powerShellHost `
        -Arguments $arguments -WorkingDirectory $repoRoot `
        -TimeoutSeconds $TimeoutSeconds
    Assert-R23D74ZeroWorld (
        [int]$result.exit_code -eq 0 -and
        [string]$result.text -cmatch [Regex]::Escape($ExpectedText)
    ) "gate failed or marker changed: $Path`n$($result.text)"
    return $result
}

function Get-R23D74WorkerCommand(
    [string]$EngineId,
    [string]$Command,
    [string]$ArmId
) {
    switch ($EngineId) {
        "godot_jolt" {
            $mode = switch ($Command) {
                "preflight" { @("--preflight-only") }
                "physical" { @("--source-commit", $sourceCommit) }
                default { throw "unsupported Godot command: $Command" }
            }
            return [ordered]@{
                file = $godotHost
                working_directory = $repoRoot
                arguments = @(
                    "--headless", "--path", $repoRoot,
                    "--script", $godotWorker, "--"
                ) + $mode + @(
                    "--stage", $stageId,
                    "--onset", $onsetId,
                    "--seed", "$campaignSeed",
                    "--profile", $profileId,
                    "--arm", $ArmId
                )
            }
        }
        "rapier_parry" {
            $arguments = @(
                $Command,
                "--stage", $stageId,
                "--onset", $onsetId,
                "--seed", "$campaignSeed",
                "--profile", $profileId,
                "--arm", $ArmId
            )
            if ($Command -ceq "physical") {
                $arguments += @("--source-commit", $sourceCommit)
            }
            return [ordered]@{
                file = $rapierBinary
                working_directory = $repoRoot
                arguments = $arguments
            }
        }
        "mujoco" {
            $arguments = @(
                "-B", "-m", $mujocoModule, $Command,
                "--stage", $stageId,
                "--onset", $onsetId,
                "--campaign-seed", "$campaignSeed",
                "--profile", $profileId,
                "--arm", $ArmId
            )
            if ($Command -ceq "physical") {
                $arguments += @("--source-commit", $sourceCommit)
            }
            return [ordered]@{
                file = $pythonHost
                working_directory = $mujocoRoot
                arguments = $arguments
            }
        }
        default { throw "unsupported engine: $EngineId" }
    }
}

function Invoke-R23D74Worker([string]$EngineId, [string]$Command, [string]$ArmId) {
    $definition = Get-R23D74WorkerCommand $EngineId $Command $ArmId
    if ($EngineId -ceq "godot_jolt") {
        $nonce = [Guid]::NewGuid().ToString("N")
        $result = Invoke-SporeSporeGodotReceiptTerminatedProcess `
            -FileName $definition.file `
            -Arguments @($definition.arguments) `
            -WorkingDirectory $definition.working_directory `
            -ReadyMarkerPrefix $godotReadyMarker `
            -ExpectedNonce $nonce `
            -Environment @{
                SPORESPORE_QSDK_R23D65_SUPERVISED_TERMINATION = "1"
                SPORESPORE_QSDK_R23D65_TERMINATION_NONCE = $nonce
            } `
            -ScrubEnvironmentNames $physicalEnvironmentNames `
            -TimeoutSeconds 300
        Assert-R23D74ZeroWorld (
            [bool]$result.termination_protocol_valid -and
            [bool]$result.supervisor_terminated -and
            -not [bool]$result.timed_out
        ) (
            "Godot supervised termination failed: " +
            "$($result.termination_protocol_failure_code) $($result.stderr)"
        )
        $lines = @([string]$result.stdout -split "`r?`n" | Where-Object {
            -not [string]::IsNullOrEmpty([string]$_)
        })
        return [ordered]@{
            exit_code = [int]$result.exit_code
            stdout = [string]$result.stdout
            stderr = [string]$result.stderr
            lines = $lines
            text = ((@($lines) -join "`n") + [string]$result.stderr)
        }
    }
    return Invoke-R23D74Process -FileName $definition.file `
        -Arguments @($definition.arguments) `
        -WorkingDirectory $definition.working_directory
}

$pythonHost = Resolve-R23D74Application $Python $mujocoPython
$powerShellHost = Resolve-R23D74Application $PowerShell "pwsh"
$cargoHost = Resolve-R23D74Application $Cargo "cargo"
$godotHost = Resolve-R23D74Application $Godot $Godot

Assert-R23D74ZeroWorld (
    (& git -C $repoRoot rev-parse --show-toplevel).Trim() -ceq
        $repoRoot.Replace("\", "/") -and
    (& git -C $repoRoot remote get-url origin).Trim() -ceq
        "https://github.com/Slagathore/sporespore.git"
) "repository identity changed"
$sourceCommit = (& git -C $repoRoot rev-parse HEAD).Trim()
Assert-R23D74ZeroWorld ($sourceCommit -cmatch '^[0-9a-f]{40}$') "HEAD identity invalid"

foreach ($path in @(
    $sourceMaterializer,
    $implementationMaterializer,
    $implementationPath,
    $runtimeContractGate,
    $successTerminalGate,
    $declarationAudit,
    $evaluatorPath,
    $supervisor,
    $authorizationReceiptGate,
    $operationLockGate,
    $strictJsonGate,
    $godotTerminationHelper,
    $pythonHost,
    $rapierManifest
)) {
    Assert-R23D74ZeroWorld (Test-Path -LiteralPath $path -PathType Leaf) (
        "required path missing: $path"
    )
}
foreach ($name in @($physicalEnvironmentNames | Where-Object {
    ([string]$_).StartsWith("SPORESPORE_QSDK_R23D74_", [StringComparison]::Ordinal)
})) {
    Assert-R23D74ZeroWorld (
        [string]::IsNullOrEmpty([Environment]::GetEnvironmentVariable($name, "Process"))
    ) "physical authorization environment is already populated: $name"
}

$sourceMaterialization = Invoke-R23D74Process -FileName $pythonHost -Arguments @(
    "-B", $sourceMaterializer, "check"
) -WorkingDirectory $repoRoot
Assert-R23D74ZeroWorld (
    [int]$sourceMaterialization.exit_code -eq 0 -and
    [string]$sourceMaterialization.text -cmatch
        [Regex]::Escape("[turning/3e] R23D74 native bindings check")
) "native binding materialization drifted: $($sourceMaterialization.text)"

$implementationMaterialization = Invoke-R23D74Process -FileName $pythonHost -Arguments @(
    "-B", $implementationMaterializer, "check"
) -WorkingDirectory $repoRoot
Assert-R23D74ZeroWorld (
    [int]$implementationMaterialization.exit_code -eq 0 -and
    [string]$implementationMaterialization.text -cmatch "QSDK_R23D74_IMPLEMENTATION"
) "implementation materialization drifted: $($implementationMaterialization.text)"
$implementation = Get-Content -LiteralPath $implementationPath -Raw |
    ConvertFrom-Json -AsHashtable -Depth 100
Assert-R23D74ZeroWorld (
    [string]$implementation.schema_version -ceq
        "sporespore_qsdk_r23d74_production_route_three_engine_turning_implementation_v1" -and
    [string]$implementation.status -ceq
        "implementation_complete_complete_zero_world_gate_passed_physical_not_authorized" -and
    [string]$implementation.question_class -ceq "finite_decision" -and
    [bool]$implementation.claims.implementation_complete -and
    [bool]$implementation.claims.complete_zero_world_gate_passed -and
    -not [bool]$implementation.claims.physical_campaign_opened -and
    -not [bool]$implementation.claims.finite_three_engine_turning -and
    -not [bool]$implementation.claims.cross_engine_equivalence -and
    @($implementation.ordered_cell_ids).Count -eq 9 -and
    @($implementation.dependency_digests.Keys).Count -gt 0 -and
    [int]$implementation.model_construction_count -eq 0 -and
    [int]$implementation.world_attempt_count -eq 0 -and
    [int]$implementation.world_build_count -eq 0 -and
    [int]$implementation.solver_step_count -eq 0 -and
    -not [bool]$implementation.physical_execution_authorized -and
    -not [bool]$implementation.physical_acceptance_authority
) "implementation contract semantics changed"

$runtimeContract = Invoke-R23D74Process -FileName $pythonHost -Arguments @(
    "-B", $runtimeContractGate
) -WorkingDirectory $repoRoot
Assert-R23D74ZeroWorld (
    [int]$runtimeContract.exit_code -eq 0
) "runtime mutation controls failed: $($runtimeContract.text)"
$runtimeReceipt = Get-R23D74MarkerJson $runtimeContract (
    "QSDK_R23D74_RUNTIME_CONTRACT_PASS "
)
Assert-R23D74NoWorld $runtimeReceipt "runtime contract"
Assert-R23D74ZeroWorld (
    [int]$runtimeReceipt.declaration_mutation_rejection_count -eq 10 -and
    [int]$runtimeReceipt.terminal_mutation_rejection_count -eq 8 -and
    [int]$runtimeReceipt.declared_cell_count -eq 9 -and
    [int]$runtimeReceipt.measurement_origin_semantic_step -eq 472 -and
    [int]$runtimeReceipt.mujoco_startup_ramp_step_count -eq 360
) "runtime mutation-control population changed"

$null = Invoke-R23D74PowerShellGate $declarationAudit (
    "[turning/3e] R23D74 declaration PASS"
) @("-Godot", $godotHost)

$godotBuild = Invoke-R23D74Process -FileName $cargoHost -Arguments @(
    "build", "--quiet", "--manifest-path", $rapierManifest,
    "--package", "sporespore-godot-adapter"
) -WorkingDirectory $repoRoot
Assert-R23D74ZeroWorld ([int]$godotBuild.exit_code -eq 0) (
    "Godot adapter build failed: $($godotBuild.text)"
)
$rapierBuild = Invoke-R23D74Process -FileName $cargoHost -Arguments @(
    "build", "--quiet", "--release", "--manifest-path", $rapierManifest,
    "--bin", "qsdk_r23d74_turning_route"
) -WorkingDirectory $repoRoot
Assert-R23D74ZeroWorld ([int]$rapierBuild.exit_code -eq 0) (
    "Rapier worker build failed: $($rapierBuild.text)"
)
Assert-R23D74ZeroWorld (Test-Path -LiteralPath $rapierBinary -PathType Leaf) (
    "Rapier worker binary missing after build"
)

$engineDefinitions = @(
    [ordered]@{
        id = "godot_jolt"
        positive_marker = "QSDK_R23D74_GODOT_JOLT_PREFLIGHT "
        failure_marker = "QSDK_R23D74_GODOT_JOLT_FAILURE "
        terminal_marker = "QSDK_R23D74_GODOT_JOLT_TERMINAL "
        invalid_code = "QSDK_R23D74_GJT_CELL_IDENTITY_INVALID"
        authorization_code = "QSDK_R23D74_GJT_PHYSICAL_AUTHORIZATION_REQUIRED"
    },
    [ordered]@{
        id = "rapier_parry"
        positive_marker = "QSDK_R23D74_RAPIER_PREFLIGHT "
        failure_marker = "QSDK_R23D74_RAPIER_FAILURE "
        terminal_marker = "QSDK_R23D74_RAPIER_TERMINAL "
        invalid_code = "QSDK_R23D74_RAP_ARM_INVALID"
        authorization_code = "QSDK_R23D74_RAP_PHYSICAL_AUTHORIZATION_REQUIRED"
    },
    [ordered]@{
        id = "mujoco"
        positive_marker = "QSDK_R23D74_MUJOCO_PREFLIGHT "
        failure_marker = "QSDK_R23D74_MUJOCO_FAILURE "
        terminal_marker = "QSDK_R23D74_MUJOCO_FAILURE "
        invalid_code = "QSDK_R23D74_MJC_WORKER_FAILURE"
        authorization_code = "QSDK_R23D74_MJC_PHYSICAL_AUTHORIZATION_REQUIRED"
    }
)

$preflights = [Collections.Generic.List[object]]::new()
$selectorNegatives = [Collections.Generic.List[object]]::new()
$authorizationNegatives = [Collections.Generic.List[object]]::new()
foreach ($engine in $engineDefinitions) {
    $engineId = [string]$engine.id
    $positiveProcess = Invoke-R23D74Worker $engineId "preflight" $referenceArm
    Assert-R23D74ZeroWorld ([int]$positiveProcess.exit_code -eq 0) (
        "$engineId positive preflight failed: $($positiveProcess.text)"
    )
    $positive = Get-R23D74MarkerJson $positiveProcess $engine.positive_marker
    Assert-R23D74NoWorld $positive "$engineId positive preflight"
    Assert-R23D74ZeroWorld (
        [string]$positive.campaign_id -ceq $campaignId -and
        [string]$positive.gate_id -ceq $gateId -and
        [string]$positive.question_class -ceq "finite_decision" -and
        [string]$positive.engine_id -ceq $engineId -and
        [string]$positive.cell_id -ceq
            "r23d74__${engineId}__s23193__reference_zero"
    ) "$engineId positive preflight identity changed"
    $preflights.Add([ordered]@{
        engine_id = $engineId
        cell_id = [string]$positive.cell_id
        returned_before_model = $true
    })

    $selectorProcess = Invoke-R23D74Worker $engineId "preflight" $invalidArm
    Assert-R23D74ZeroWorld ([int]$selectorProcess.exit_code -ne 0) (
        "$engineId accepted an invalid arm selector"
    )
    $selector = Get-R23D74MarkerJson $selectorProcess $engine.failure_marker
    Assert-R23D74NoWorld $selector "$engineId selector negative"
    Assert-R23D74ZeroWorld (
        [string]$selector.failure_code -cmatch [Regex]::Escape($engine.invalid_code)
    ) "$engineId invalid-selector failure changed: $($selector.failure_code)"
    $selectorNegatives.Add([ordered]@{
        engine_id = $engineId
        failure_code = [string]$selector.failure_code
    })

    $authorizationProcess = Invoke-R23D74Worker $engineId "physical" $referenceArm
    Assert-R23D74ZeroWorld ([int]$authorizationProcess.exit_code -ne 0) (
        "$engineId crossed the physical authorization barrier"
    )
    $authorization = Get-R23D74MarkerJson (
        $authorizationProcess
    ) $engine.terminal_marker
    Assert-R23D74NoWorld $authorization "$engineId authorization negative"
    Assert-R23D74ZeroWorld (
        [string]$authorization.failure_code -cmatch
            [Regex]::Escape($engine.authorization_code)
    ) "$engineId authorization-negative failure changed: $($authorization.failure_code)"
    $authorizationNegatives.Add([ordered]@{
        engine_id = $engineId
        failure_code = [string]$authorization.failure_code
    })
}

$authorizationGhostArguments = @(
    "-AuthorizationGhost",
    "-Godot", $godotHost,
    "-Python", $pythonHost,
    "-PowerShell", $powerShellHost
)
if ($ExpectProductionConformanceLockHeld) {
    $authorizationGhostArguments += "-ExpectProductionConformanceLockHeld"
}
$authorizationGhostProcess = Invoke-R23D74PowerShellGate $supervisor (
    "QSDK_R23D74_AUTHORIZATION_GHOST_PASS"
) $authorizationGhostArguments
$authorizationGhost = Get-R23D74MarkerJson $authorizationGhostProcess (
    "QSDK_R23D74_AUTHORIZATION_GHOST_PASS "
)
Assert-R23D74NoWorld $authorizationGhost "complete authorization ghost"
Assert-R23D74ZeroWorld (
    [string]$authorizationGhost.ledger_scope.question_class -ceq "finite_decision" -and
    [string]$authorizationGhost.work_class -ceq
        "zero_world_finite_decision_route_qualification" -and
    [bool]$authorizationGhost.complete_ordered_nine_cell_population_exercised -and
    [bool]$authorizationGhost.actual_production_worker_authorization_entrypoints_used -and
    [bool]$authorizationGhost.common_supervisor_validator_used -and
    [string]$authorizationGhost.operation_lock_mode -ceq $(
        if ($ExpectProductionConformanceLockHeld) {
            "active_parent_conformance_lock_verified"
        } else {
            "standalone_conformance_lock_acquired"
        }
    ) -and
    [bool]$authorizationGhost.active_outer_conformance_lock_verified -eq
        [bool]$ExpectProductionConformanceLockHeld -and
    [int]$authorizationGhost.receipt_count -eq 9 -and
    [int]$authorizationGhost.missing_ok_negative_count -eq 3 -and
    -not [bool]$authorizationGhost.physical_question_asked -and
    -not [bool]$authorizationGhost.physical_execution_authorized
) "complete production-supervisor authorization ghost changed"

$null = Invoke-R23D74PowerShellGate $authorizationReceiptGate (
    "[turning/3e] AUTHORIZATION_RECEIPT_CONTRACT_PASS"
)
$null = Invoke-R23D74PowerShellGate $successTerminalGate (
    "[turning/3e] PASS R23D74 success-terminal ghost"
) @("-Godot", $godotHost, "-Python", $pythonHost, "-Cargo", $cargoHost)

$evaluatorProcess = Invoke-R23D74Process -FileName $pythonHost -Arguments @(
    "-B", $evaluatorPath, "preflight"
) -WorkingDirectory $repoRoot -TimeoutSeconds 900
Assert-R23D74ZeroWorld ([int]$evaluatorProcess.exit_code -eq 0) (
    "evaluator preflight failed: $($evaluatorProcess.text)"
)
$evaluatorReceipt = Get-R23D74MarkerJson $evaluatorProcess (
    "QSDK_R23D74_EVALUATOR_PREFLIGHT "
)
Assert-R23D74NoWorld $evaluatorReceipt "complete evaluator preflight"
Assert-R23D74ZeroWorld (
    [string]$evaluatorReceipt.question_class -ceq "finite_decision" -and
    [int]$evaluatorReceipt.complete_outcome_controls.control_count -eq 4 -and
    [int]$evaluatorReceipt.complete_outcome_controls.positive_control_count -eq 1 -and
    [int]$evaluatorReceipt.complete_outcome_controls.negative_control_count -eq 1 -and
    [int]$evaluatorReceipt.complete_outcome_controls.invalid_control_count -eq 1 -and
    [int]$evaluatorReceipt.complete_outcome_controls.incomplete_control_count -eq 1
) "evaluator outcome-control population changed"

$failureControlProcess = Invoke-R23D74Process -FileName $pythonHost -Arguments @(
    "-B", $evaluatorPath, "failure-terminal-control"
) -WorkingDirectory $repoRoot
Assert-R23D74ZeroWorld ([int]$failureControlProcess.exit_code -eq 0) (
    "failure-terminal transport control failed: $($failureControlProcess.text)"
)
$failureControl = Get-R23D74MarkerJson $failureControlProcess (
    "QSDK_R23D74_FAILURE_TERMINAL_CONTROL "
)
Assert-R23D74NoWorld $failureControl "failure-terminal transport control"

$predecessorDefinitions = @(
    [ordered]@{
        id = "consumed_r23d71_finite_result"
        path = Join-Path $repoRoot "tests\test_qsdk_r23d71_physical_closure.ps1"
        marker = "[turning/3e] PASS R23D71 immutable physical closure"
    },
    [ordered]@{
        id = "closed_three_engine_execution_route"
        path = Join-Path $repoRoot (
            "tests\test_three_engine_turning_production_route_development_closure.ps1"
        )
        marker = "[turning/3e] PASS production-route development closure"
    },
    [ordered]@{
        id = "prospective_measurement_origin_parity"
        path = Join-Path $repoRoot (
            "tests\test_qsdk_r23d74_measurement_origin_predecessor_replay.ps1"
        )
        marker = "[turning/measurement] R23D74 predecessor replay PASS"
    },
    [ordered]@{
        id = "closed_r23d73_mujoco_positive_turn_development"
        path = Join-Path $repoRoot (
            "tests\test_qsdk_r23d74_mujoco_positive_turn_predecessor_replay.ps1"
        )
        marker = "[turning/mujoco] R23D74 R23D73 predecessor replay PASS"
    }
)
$predecessorReplays = [Collections.Generic.List[object]]::new()
foreach ($predecessor in $predecessorDefinitions) {
    $predecessorArguments = @()
    if (
        [string]$predecessor.id -ceq
            "closed_r23d73_mujoco_positive_turn_development" -and
        $ExpectProductionConformanceLockHeld
    ) {
        $predecessorArguments += "-ExpectProductionConformanceLockHeld"
    }
    $null = Invoke-R23D74PowerShellGate $predecessor.path `
        $predecessor.marker $predecessorArguments 1800
    $predecessorReplays.Add([ordered]@{
        id = [string]$predecessor.id
        replay_passed = $true
    })
}

if ($ExpectProductionConformanceLockHeld) {
    $null = Invoke-R23D74PowerShellGate $operationLockGate `
        "LOCOMOTION_OPERATION_LOCK_PASS" @("-ExpectProductionConformanceLockHeld")
} else {
    $null = Invoke-R23D74PowerShellGate $operationLockGate (
        "LOCOMOTION_OPERATION_LOCK_PASS"
    )
}
$null = Invoke-R23D74PowerShellGate $strictJsonGate (
    "STRICT_JSON_ARRAY_DOCUMENT_TEST_PASS"
)

$receipt = [ordered]@{
    schema_version = "sporespore_qsdk_r23d74_complete_zero_world_gate_v1"
    campaign_id = $campaignId
    gate_id = $gateId
    question_class = "finite_decision"
    source_head_at_execution = $sourceCommit
    implementation_contract_path = (
        "sdk/turning/" +
        "r23d74_production_route_three_engine_turning_implementation_v1.json"
    )
    implementation_dependency_count = @($implementation.dependency_digests.Keys).Count
    declared_cell_count = 9
    representative_worker_preflight_count = $preflights.Count
    worker_preflights = @($preflights)
    native_selector_negative_count = $selectorNegatives.Count
    selector_negatives = @($selectorNegatives)
    physical_authorization_negative_count = $authorizationNegatives.Count
    authorization_negatives = @($authorizationNegatives)
    complete_nine_cell_production_supervisor_authorization_ghost_passed = $true
    authorization_ghost_receipt_count = [int]$authorizationGhost.receipt_count
    authorization_ghost_missing_ok_negative_count = (
        [int]$authorizationGhost.missing_ok_negative_count
    )
    authorization_ghost_question_class = (
        [string]$authorizationGhost.ledger_scope.question_class
    )
    authorization_ghost_operation_lock_mode = (
        [string]$authorizationGhost.operation_lock_mode
    )
    authorization_ghost_active_outer_conformance_lock_verified = (
        [bool]$authorizationGhost.active_outer_conformance_lock_verified
    )
    native_binding_materialization_passed = $true
    implementation_materialization_passed = $true
    declaration_runtime_projection_passed = $true
    declaration_mutation_rejection_count = 10
    terminal_contract_mutation_rejection_count = 8
    frozen_declaration_audit_passed_at_declaration_boundary = $true
    common_authorization_receipt_contract_gate_passed = $true
    compact_success_terminal_projection_ghost_passed = $true
    success_terminal_native_producer_count = 3
    success_terminal_shared_projector_count = 1
    success_terminal_positive_projection_decision_count = 3
    success_terminal_negative_projection_decision_count = 15
    compact_ghost_model_construction_count = 0
    compact_ghost_world_attempt_count = 0
    compact_ghost_world_build_count = 0
    full_seeded_world_ghost_used = $false
    full_matrix_and_schedule_evaluator_preflight_passed = $true
    evaluator_outcome_control_count = 4
    failure_terminal_transport_control_passed = $true
    predecessor_replay_count = $predecessorReplays.Count
    predecessor_replays = @($predecessorReplays)
    shared_operation_lock_gate_passed = $true
    shared_operation_lock_gate_mode = $(
        if ($ExpectProductionConformanceLockHeld) {
            "active_production_conformance_lock_verified"
        } else {
            "standalone_physical_conformance_entrypoint_interlock_verified"
        }
    )
    shared_append_only_json_gate_passed = $true
    complete_zero_world_gate_passed = $true
    all_physical_claims_false = $true
    model_construction_count = 0
    world_attempt_count = 0
    world_build_count = 0
    solver_step_count = 0
    physical_execution_authorized = $false
    physical_acceptance_authority = $false
    finite_three_engine_turning = $false
    portable_basic_turning = $false
    q_sdk_r23_satisfied = $false
    cross_engine_equivalence = $false
    population_robustness = $false
    prone_to_standing = $false
    release_authorized = $false
}
Write-Output (
    "QSDK_R23D74_COMPLETE_ZERO_WORLD_PASS " +
    ($receipt | ConvertTo-Json -Compress -Depth 100)
)
