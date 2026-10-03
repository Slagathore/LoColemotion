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

$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$sdkRoot = Join-Path $repoRoot "sdk"
$turningRoot = Join-Path $sdkRoot "turning"
$mujocoRoot = Join-Path $sdkRoot "adapters\mujoco"
$mujocoPython = Join-Path $mujocoRoot ".venv\Scripts\python.exe"
$nativeMaterializer = Join-Path $turningRoot "materialize_r23d78_native_bindings.py"
$implementationMaterializer = Join-Path $turningRoot "materialize_r23d78_implementation.py"
$implementationPath = Join-Path $turningRoot (
    "r23d78_production_route_three_engine_turning_implementation_v1.json"
)
$runtimeGate = Join-Path $repoRoot "tests\test_qsdk_r23d78_runtime_contract.py"
$declarationAudit = Join-Path $sdkRoot (
    "audit_r23d78_fresh_finite_three_engine_turning_decision.ps1"
)
$evaluatorPath = Join-Path $turningRoot (
    "r23d78_production_route_three_engine_turning_evaluator.py"
)
$supervisor = Join-Path $sdkRoot "run_qsdk_r23d78_supervisor.ps1"
$godotTerminationHelper = Join-Path $sdkRoot "godot_receipt_terminated_process.ps1"
$godotWorker = "res://tests/test_sdk_qsdk_r23d78_godot_jolt_worker.gd"
$mujocoModule = "sporespore_mujoco_adapter.qsdk_r23d78_turning_route"
$rapierManifest = Join-Path $sdkRoot "Cargo.toml"
$rapierBinary = Join-Path $sdkRoot "target\release\qsdk_r23d78_turning_route.exe"
$r76ClosureAudit = Join-Path $repoRoot "tests\test_qsdk_r23d76_physical_closure.ps1"
$r77ClosureAudit = Join-Path $sdkRoot (
    "audit_r23d77_windows_cas_path_identity_conformance_closure.py"
)

$campaignId = "QSDK-R23D78-FRESH-FINITE-THREE-ENGINE-TURNING-DECISION"
$gateId = "QSDK-R23D78"
$stageId = "fresh_finite_three_engine_turning_decision"
$onsetId = "onset_600"
$campaignSeed = 23199
$profileId = "sporespore_qsdk_r23d60_selected_s169_actuator_cap_profile_v1"
$referenceArm = "reference_zero"
$invalidArm = "zero_world_invalid_arm"
$godotReadyMarker = "QSDK_R23D65_GODOT_SUPERVISOR_TERMINATION_READY "
$physicalEnvironmentNames = @(
    "SPORESPORE_QSDK_R23D78_FREEZE",
    "SPORESPORE_QSDK_R23D78_ATTEMPT",
    "SPORESPORE_QSDK_R23D78_TOKEN",
    "SPORESPORE_QSDK_R23D78_STAGE",
    "SPORESPORE_QSDK_R23D78_CELL",
    "SPORESPORE_QSDK_R23D78_ENGINE",
    "SPORESPORE_QSDK_R23D78_ATTEMPT_ROOT",
    "SPORESPORE_QSDK_R23D78_AUTHORITY_REPO_ROOT",
    "SPORESPORE_QSDK_R23D78_PYTHON",
    "SPORESPORE_QSDK_R23D78_POWERSHELL",
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

function Assert-R23D78([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "[turning/3e] R23D78 zero-world: $Message" }
}

function Resolve-R23D78Application([string]$Value, [string]$Fallback) {
    $candidate = if ([string]::IsNullOrWhiteSpace($Value)) { $Fallback } else { $Value }
    if (Test-Path -LiteralPath $candidate -PathType Leaf) {
        return [IO.Path]::GetFullPath($candidate)
    }
    return [IO.Path]::GetFullPath(
        (Get-Command $candidate -CommandType Application -ErrorAction Stop).Source
    )
}

function Invoke-R23D78Process {
    param(
        [Parameter(Mandatory)][string]$FileName,
        [Parameter(Mandatory)][string[]]$Arguments,
        [Parameter(Mandatory)][string]$WorkingDirectory,
        [ValidateRange(1, 3600)][int]$TimeoutSeconds = 900
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
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $start
    try {
        Assert-R23D78 $process.Start() "could not start process: $FileName"
        $stdoutTask = $process.StandardOutput.ReadToEndAsync()
        $stderrTask = $process.StandardError.ReadToEndAsync()
        $completed = $process.WaitForExit($TimeoutSeconds * 1000)
        if (-not $completed) {
            try { $process.Kill($true) } catch { }
            $process.WaitForExit()
        }
        $stdout = $stdoutTask.GetAwaiter().GetResult()
        $stderr = $stderrTask.GetAwaiter().GetResult()
        Assert-R23D78 $completed "process timed out: $FileName"
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

function Get-R23D78MarkerJson($Process, [string]$Prefix) {
    $markers = @($Process.lines | Where-Object {
        ([string]$_).StartsWith($Prefix, [StringComparison]::Ordinal)
    })
    Assert-R23D78 ($markers.Count -eq 1) (
        "expected one '$Prefix' marker; exit=$($Process.exit_code); output=$($Process.text)"
    )
    return ([string]$markers[0]).Substring($Prefix.Length) |
        ConvertFrom-Json -AsHashtable -Depth 100
}

function Assert-R23D78NoWorld($Receipt, [string]$Label) {
    foreach ($key in @(
        "model_construction_count",
        "world_attempt_count",
        "world_build_count",
        "physical_acceptance_authority"
    )) {
        Assert-R23D78 (@($Receipt.Keys) -ccontains $key) "$Label omitted $key"
    }
    $solverZero = (
        -not (@($Receipt.Keys) -ccontains "solver_step_count") -or
        [int]$Receipt.solver_step_count -eq 0
    )
    Assert-R23D78 (
        [int]$Receipt.model_construction_count -eq 0 -and
        [int]$Receipt.world_attempt_count -eq 0 -and
        [int]$Receipt.world_build_count -eq 0 -and
        $solverZero -and
        -not [bool]$Receipt.physical_acceptance_authority
    ) "$Label crossed the zero-world boundary"
}

function Invoke-R23D78PowerShellGate(
    [string]$Path,
    [string]$ExpectedText,
    [string[]]$AdditionalArguments = @(),
    [int]$TimeoutSeconds = 900
) {
    $result = Invoke-R23D78Process -FileName $powerShellHost `
        -Arguments (@("-NoLogo", "-NoProfile", "-File", $Path) + $AdditionalArguments) `
        -WorkingDirectory $repoRoot -TimeoutSeconds $TimeoutSeconds
    Assert-R23D78 (
        [int]$result.exit_code -eq 0 -and
        [string]$result.text -cmatch [Regex]::Escape($ExpectedText)
    ) "gate failed: $Path`n$($result.text)"
    return $result
}

function Get-R23D78WorkerCommand(
    [string]$EngineId,
    [string]$Command,
    [string]$ArmId,
    [string]$SourceCommit
) {
    switch ($EngineId) {
        "godot_jolt" {
            $mode = if ($Command -ceq "preflight") {
                @("--preflight-only")
            } else {
                @("--source-commit", $SourceCommit)
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
                $arguments += @("--source-commit", $SourceCommit)
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
                $arguments += @("--source-commit", $SourceCommit)
            }
            return [ordered]@{
                file = $pythonHost
                working_directory = $mujocoRoot
                arguments = $arguments
            }
        }
        default { throw "undeclared engine: $EngineId" }
    }
}

function Invoke-R23D78Worker(
    [string]$EngineId,
    [string]$Command,
    [string]$ArmId,
    [string]$SourceCommit
) {
    $definition = Get-R23D78WorkerCommand $EngineId $Command $ArmId $SourceCommit
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
        Assert-R23D78 (
            [bool]$result.termination_protocol_valid -and
            [bool]$result.supervisor_terminated -and
            -not [bool]$result.timed_out
        ) "Godot supervised termination failed: $($result.stderr)"
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
    return Invoke-R23D78Process -FileName $definition.file `
        -Arguments @($definition.arguments) `
        -WorkingDirectory $definition.working_directory
}

$pythonHost = Resolve-R23D78Application $Python $mujocoPython
$powerShellHost = Resolve-R23D78Application $PowerShell "pwsh"
$cargoHost = Resolve-R23D78Application $Cargo "cargo"
$godotHost = Resolve-R23D78Application $Godot $Godot

Assert-R23D78 (
    (& git -C $repoRoot rev-parse --show-toplevel).Trim() -ceq
        $repoRoot.Replace("\", "/") -and
    (& git -C $repoRoot remote get-url origin).Trim() -ceq
        "https://github.com/Slagathore/sporespore.git"
) "repository identity changed"
$sourceCommit = (& git -C $repoRoot rev-parse HEAD).Trim()
Assert-R23D78 ($sourceCommit -cmatch '^[0-9a-f]{40}$') "HEAD identity invalid"

$nativeCheck = Invoke-R23D78Process -FileName $pythonHost `
    -Arguments @("-B", $nativeMaterializer, "check") `
    -WorkingDirectory $repoRoot
Assert-R23D78 (
    $nativeCheck.exit_code -eq 0 -and
    $nativeCheck.text -cmatch "R23D78 native bindings check"
) "native materialization drifted: $($nativeCheck.text)"

$implementationCheck = Invoke-R23D78Process -FileName $pythonHost `
    -Arguments @("-B", $implementationMaterializer, "check") `
    -WorkingDirectory $repoRoot
Assert-R23D78 (
    $implementationCheck.exit_code -eq 0 -and
    $implementationCheck.text -cmatch "QSDK_R23D78_IMPLEMENTATION"
) "implementation materialization drifted: $($implementationCheck.text)"

$runtime = Invoke-R23D78Process -FileName $pythonHost `
    -Arguments @("-B", $runtimeGate) -WorkingDirectory $repoRoot
Assert-R23D78 (
    $runtime.exit_code -eq 0 -and
    $runtime.text -cmatch "QSDK_R23D78_RUNTIME_CONTRACT_PASS"
) "runtime controls failed: $($runtime.text)"

$null = Invoke-R23D78PowerShellGate $declarationAudit (
    "[turning/3e] R23D78 declaration PASS"
) @("-Godot", $godotHost)

$godotBuild = Invoke-R23D78Process -FileName $cargoHost -Arguments @(
    "build", "--quiet", "--manifest-path", $rapierManifest,
    "--package", "sporespore-godot-adapter"
) -WorkingDirectory $repoRoot
Assert-R23D78 ($godotBuild.exit_code -eq 0) "Godot adapter build failed: $($godotBuild.text)"
$rapierBuild = Invoke-R23D78Process -FileName $cargoHost -Arguments @(
    "build", "--quiet", "--release", "--manifest-path", $rapierManifest,
    "--bin", "qsdk_r23d78_turning_route"
) -WorkingDirectory $repoRoot
Assert-R23D78 ($rapierBuild.exit_code -eq 0) "Rapier worker build failed: $($rapierBuild.text)"
Assert-R23D78 (Test-Path -LiteralPath $rapierBinary -PathType Leaf) "Rapier binary missing"

$engines = @(
    [ordered]@{
        id = "godot_jolt"
        positive = "QSDK_R23D78_GODOT_JOLT_PREFLIGHT "
        failure = "QSDK_R23D78_GODOT_JOLT_FAILURE "
        terminal = "QSDK_R23D78_GODOT_JOLT_TERMINAL "
        invalid = "QSDK_R23D78_GJT_CELL_IDENTITY_INVALID"
        unauthorized = "QSDK_R23D78_GJT_PHYSICAL_AUTHORIZATION_REQUIRED"
    },
    [ordered]@{
        id = "rapier_parry"
        positive = "QSDK_R23D78_RAPIER_PREFLIGHT "
        failure = "QSDK_R23D78_RAPIER_FAILURE "
        terminal = "QSDK_R23D78_RAPIER_TERMINAL "
        invalid = "QSDK_R23D78_RAP_ARM_INVALID"
        unauthorized = "QSDK_R23D78_RAP_PHYSICAL_AUTHORIZATION_REQUIRED"
    },
    [ordered]@{
        id = "mujoco"
        positive = "QSDK_R23D78_MUJOCO_PREFLIGHT "
        failure = "QSDK_R23D78_MUJOCO_FAILURE "
        terminal = "QSDK_R23D78_MUJOCO_FAILURE "
        invalid = "QSDK_R23D78_MJC_WORKER_FAILURE"
        unauthorized = "QSDK_R23D78_MJC_PHYSICAL_AUTHORIZATION_REQUIRED"
    }
)

$preflights = [Collections.Generic.List[object]]::new()
$selectorNegatives = [Collections.Generic.List[object]]::new()
$authorizationNegatives = [Collections.Generic.List[object]]::new()
foreach ($engine in $engines) {
    $engineId = [string]$engine.id
    $positiveProcess = Invoke-R23D78Worker $engineId "preflight" $referenceArm $sourceCommit
    Assert-R23D78 ($positiveProcess.exit_code -eq 0) "$engineId preflight failed: $($positiveProcess.text)"
    $positive = Get-R23D78MarkerJson $positiveProcess $engine.positive
    Assert-R23D78NoWorld $positive "$engineId preflight"
    Assert-R23D78 (
        [string]$positive.campaign_id -ceq $campaignId -and
        [string]$positive.gate_id -ceq $gateId -and
        [string]$positive.question_class -ceq "finite_decision" -and
        [string]$positive.engine_id -ceq $engineId -and
        [string]$positive.cell_id -ceq
            "r23d78__${engineId}__s23199__reference_zero"
    ) "$engineId preflight identity changed"
    $preflights.Add([ordered]@{ engine_id = $engineId; cell_id = $positive.cell_id })

    $selectorProcess = Invoke-R23D78Worker $engineId "preflight" $invalidArm $sourceCommit
    Assert-R23D78 ($selectorProcess.exit_code -ne 0) "$engineId accepted invalid arm"
    $selector = Get-R23D78MarkerJson $selectorProcess $engine.failure
    Assert-R23D78NoWorld $selector "$engineId selector negative"
    Assert-R23D78 (
        [string]$selector.failure_code -cmatch [Regex]::Escape($engine.invalid)
    ) "$engineId selector refusal changed: $($selector.failure_code)"
    $selectorNegatives.Add([ordered]@{ engine_id = $engineId; code = $selector.failure_code })

    $authorizationProcess = Invoke-R23D78Worker $engineId "physical" $referenceArm $sourceCommit
    Assert-R23D78 ($authorizationProcess.exit_code -ne 0) "$engineId crossed authorization"
    $authorization = Get-R23D78MarkerJson $authorizationProcess $engine.terminal
    Assert-R23D78NoWorld $authorization "$engineId authorization negative"
    Assert-R23D78 (
        [string]$authorization.failure_code -cmatch [Regex]::Escape($engine.unauthorized)
    ) "$engineId authorization refusal changed: $($authorization.failure_code)"
    $authorizationNegatives.Add([ordered]@{ engine_id = $engineId; code = $authorization.failure_code })
}

$role = Invoke-R23D78PowerShellGate $supervisor "QSDK_R23D78_SUPERVISOR_ROLE_PREFLIGHT " @(
    "-RolePreflight", "-Godot", $godotHost, "-Python", $pythonHost,
    "-PowerShell", $powerShellHost
)
$roleReceipt = Get-R23D78MarkerJson $role "QSDK_R23D78_SUPERVISOR_ROLE_PREFLIGHT "
Assert-R23D78NoWorld $roleReceipt "supervisor role preflight"

$ghostArguments = @(
    "-AuthorizationGhost", "-Godot", $godotHost, "-Python", $pythonHost,
    "-PowerShell", $powerShellHost
)
if ($ExpectProductionConformanceLockHeld) {
    $ghostArguments += "-ExpectProductionConformanceLockHeld"
}
$ghost = Invoke-R23D78PowerShellGate $supervisor `
    "QSDK_R23D78_AUTHORIZATION_GHOST_PASS " $ghostArguments 1800
$ghostReceipt = Get-R23D78MarkerJson $ghost "QSDK_R23D78_AUTHORIZATION_GHOST_PASS "
Assert-R23D78NoWorld $ghostReceipt "authorization ghost"
Assert-R23D78 (
    [int]$ghostReceipt.receipt_count -eq 9 -and
    [int]$ghostReceipt.missing_ok_negative_count -eq 3 -and
    [bool]$ghostReceipt.complete_ordered_nine_cell_population_exercised -and
    [bool]$ghostReceipt.actual_production_worker_authorization_entrypoints_used -and
    -not [bool]$ghostReceipt.physical_execution_authorized
) "complete authorization ghost changed"
Assert-R23D78 (
    [string]$ghostReceipt.operation_lock_mode -ceq $(
        if ($ExpectProductionConformanceLockHeld) {
            "active_parent_conformance_lock_verified"
        } else {
            "standalone_conformance_lock_acquired"
        }
    ) -and
    [bool]$ghostReceipt.active_outer_conformance_lock_verified -eq
        [bool]$ExpectProductionConformanceLockHeld
) "authorization ghost parent-lock composition changed"

$evaluator = Invoke-R23D78Process -FileName $pythonHost -Arguments @(
    "-B", $evaluatorPath, "preflight"
) -WorkingDirectory $repoRoot -TimeoutSeconds 900
Assert-R23D78 (
    $evaluator.exit_code -eq 0 -and
    $evaluator.text -cmatch "QSDK_R23D78_EVALUATOR_PREFLIGHT "
) "evaluator preflight failed: $($evaluator.text)"
$evaluatorReceipt = Get-R23D78MarkerJson $evaluator "QSDK_R23D78_EVALUATOR_PREFLIGHT "
Assert-R23D78NoWorld $evaluatorReceipt "evaluator preflight"
Assert-R23D78 (
    [int]$evaluatorReceipt.startup_binding_control.complete_engine_binding_enumeration_count -eq 3 -and
    [int]$evaluatorReceipt.startup_binding_control.startup_mutation_rejection_count -eq 19 -and
    [int]$evaluatorReceipt.startup_binding_control.unsupported_engine_rejection_count -eq 1 -and
    [int]$evaluatorReceipt.complete_outcome_controls.control_count -eq 4 -and
    [string]$evaluatorReceipt.cas_path_identity_binding.contract_id -ceq
        "QSDK-R23D77-WINDOWS-CAS-PATH-IDENTITY" -and
    [string]$evaluatorReceipt.cas_path_identity_binding.repairable_frozen_failure_code -ceq
        "R23D65_TRACE_ARTIFACT_CAS_PATH" -and
    [string]$evaluatorReceipt.cas_path_identity_binding.successor_failure_code -ceq
        "R23D77_TRACE_ARTIFACT_CAS_FILE_IDENTITY" -and
    [bool]$evaluatorReceipt.cas_path_identity_binding.payload_and_manifest_same_existing_file_required -and
    [bool]$evaluatorReceipt.cas_path_identity_binding.complete_frozen_verifier_replay_required
) "engine-aware evaluator controls changed"

$null = Invoke-R23D78PowerShellGate $r76ClosureAudit (
    "QSDK_R23D76_PHYSICAL_CLOSURE_PASS "
) @() 1800
$r77Closure = Invoke-R23D78Process -FileName $pythonHost -Arguments @(
    "-B", $r77ClosureAudit
) -WorkingDirectory $repoRoot
Assert-R23D78 (
    $r77Closure.exit_code -eq 0 -and
    $r77Closure.text -cmatch "QSDK_R23D77_CLOSURE_AUDIT_PASS receipts=3 negatives=12 mutations=14 worlds=0"
) "R23D77 existing-file identity closure replay failed: $($r77Closure.text)"

$implementation = Get-Content -Raw -LiteralPath $implementationPath |
    ConvertFrom-Json -AsHashtable -Depth 100
$receipt = [ordered]@{
    schema_version = "sporespore_qsdk_r23d78_complete_zero_world_gate_v1"
    campaign_id = $campaignId
    gate_id = $gateId
    question_class = "finite_decision"
    implementation_status_at_gate = [string]$implementation.status
    implementation_dependency_count = @($implementation.dependency_digests.Keys).Count
    native_worker_preflight_count = $preflights.Count
    invalid_selector_negative_count = $selectorNegatives.Count
    missing_physical_authorization_negative_count = $authorizationNegatives.Count
    authorization_receipt_positive_count = [int]$ghostReceipt.receipt_count
    authorization_ghost_operation_lock_mode = [string]$ghostReceipt.operation_lock_mode
    active_outer_conformance_lock_verified =
        [bool]$ghostReceipt.active_outer_conformance_lock_verified
    declaration_mutation_rejection_count = 13
    terminal_contract_mutation_rejection_count = 8
    predecessor_replay_count = 2
    r23d77_existing_file_identity_negative_control_rejection_count = 12
    r23d77_existing_file_identity_successor_binding_proved = $true
    evaluator_outcome_control_count = [int]$evaluatorReceipt.complete_outcome_controls.control_count
    engine_startup_binding_count = [int]$evaluatorReceipt.startup_binding_control.complete_engine_binding_enumeration_count
    startup_mutation_rejection_count = [int]$evaluatorReceipt.startup_binding_control.startup_mutation_rejection_count
    unsupported_engine_rejection_count = [int]$evaluatorReceipt.startup_binding_control.unsupported_engine_rejection_count
    full_seeded_world_ghost_used = $false
    bounded_native_smoke_run = $false
    complete_zero_world_gate_passed = $true
    model_construction_count = 0
    world_attempt_count = 0
    world_build_count = 0
    solver_step_count = 0
    physical_execution_authorized = $false
    physical_acceptance_authority = $false
    q_sdk_r23_satisfied = $false
    release_score_after = "10/25"
}
Write-Output (
    "[turning/3e] R23D78 complete zero-world PASS " +
    ($receipt | ConvertTo-Json -Compress -Depth 100)
)
