#requires -Version 7.0

[CmdletBinding()]
param(
    [string]$Godot = (
        "C:\Users\Cole\CodeStuff\Misc\Godot\" +
        "Godot_v4.7-stable_mono_win64_console.exe"
    ),
    [string]$Python = "",
    [string]$PowerShell = "",
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
$materializer = Join-Path $turningRoot "materialize_r23d66_implementation.py"
$implementationPath = Join-Path $turningRoot (
    "r23d66_production_route_three_engine_turning_implementation_v1.json"
)
$preregistrationGate = Join-Path $repoRoot "tests\test_qsdk_r23d66_preregistration.ps1"
$evaluatorGate = Join-Path $repoRoot "tests\test_qsdk_r23d66_evaluator.ps1"
$operationLockGate = Join-Path $repoRoot "tests\test_locomotion_operation_lock.ps1"
$strictJsonGate = Join-Path $repoRoot "tests\test_strict_json_array_document.ps1"
$godotTerminationHelper = Join-Path $sdkRoot "godot_receipt_terminated_process.ps1"
$godotWorker = "res://tests/test_sdk_qsdk_r23d66_godot_jolt_worker.gd"
$mujocoPython = Join-Path $mujocoRoot ".venv\Scripts\python.exe"
$mujocoModule = "sporespore_mujoco_adapter.qsdk_r23d66_turning_route"
$rapierManifest = Join-Path $sdkRoot "Cargo.toml"
$rapierBinary = Join-Path $sdkRoot "target\debug\qsdk_r23d66_turning_route.exe"

$campaignId = (
    "QSDK-R23D66-PRODUCTION-ROUTE-QUALIFIED-SELECTED-PROFILE-" +
    "THREE-ENGINE-TURNING-VALIDATION"
)
$gateId = "QSDK-R23D66"
$stageId = "production_route_qualified_selected_profile_three_engine_turning_validation"
$onsetId = "onset_600"
$campaignSeed = 23179
$profileId = "sporespore_qsdk_r23d60_selected_s169_actuator_cap_profile_v1"
$referenceArm = "reference_zero"
$invalidArm = "zero_world_invalid_arm"
$godotReadyMarker = "QSDK_R23D65_GODOT_SUPERVISOR_TERMINATION_READY "
$physicalEnvironmentNames = @(
    "SPORESPORE_QSDK_R23D66_FREEZE",
    "SPORESPORE_QSDK_R23D66_ATTEMPT",
    "SPORESPORE_QSDK_R23D66_TOKEN",
    "SPORESPORE_QSDK_R23D66_STAGE",
    "SPORESPORE_QSDK_R23D66_CELL",
    "SPORESPORE_QSDK_R23D66_ENGINE",
    "SPORESPORE_QSDK_R23D66_ATTEMPT_ROOT",
    "SPORESPORE_QSDK_R23D66_AUTHORITY_REPO_ROOT",
    "SPORESPORE_QSDK_R23D66_PYTHON",
    "SPORESPORE_QSDK_R23D66_POWERSHELL",
    "SPORESPORE_QSDK_R23D65_SUPERVISED_TERMINATION",
    "SPORESPORE_QSDK_R23D65_TERMINATION_NONCE"
)

. $godotTerminationHelper

function Assert-R23D66ZeroWorld([bool]$Condition, [string]$Message) {
    if (-not $Condition) {
        throw "QSDK-R23D66 ZERO-WORLD: $Message"
    }
}

function Resolve-R23D66Application([string]$Value, [string]$Fallback) {
    $candidate = if ([string]::IsNullOrWhiteSpace($Value)) { $Fallback } else { $Value }
    if (Test-Path -LiteralPath $candidate -PathType Leaf) {
        return [IO.Path]::GetFullPath($candidate)
    }
    $command = Get-Command $candidate -CommandType Application -ErrorAction Stop
    return [IO.Path]::GetFullPath($command.Source)
}

function Invoke-R23D66Process {
    param(
        [Parameter(Mandatory = $true)][string]$FileName,
        [Parameter(Mandatory = $true)][string[]]$Arguments,
        [Parameter(Mandatory = $true)][string]$WorkingDirectory
    )
    $prior = Get-Location
    try {
        Set-Location -LiteralPath $WorkingDirectory
        $lines = @(
            & $FileName @Arguments 2>&1 | ForEach-Object { [string]$_ }
        )
        $exitCode = $LASTEXITCODE
    } finally {
        Set-Location -LiteralPath $prior.Path
    }
    return [ordered]@{
        exit_code = [int]$exitCode
        lines = @($lines)
        text = (@($lines) -join "`n")
    }
}

function Get-R23D66MarkerJson($Process, [string]$Prefix) {
    $markers = @($Process.lines | Where-Object {
        ([string]$_).StartsWith($Prefix, [StringComparison]::Ordinal)
    })
    Assert-R23D66ZeroWorld ($markers.Count -eq 1) (
        "expected one '$Prefix' marker; exit=$($Process.exit_code); output=$($Process.text)"
    )
    return ([string]$markers[0]).Substring($Prefix.Length) |
        ConvertFrom-Json -AsHashtable -Depth 100
}

function Assert-R23D66NoWorld($Receipt, [string]$Label) {
    Assert-R23D66ZeroWorld (
        [int]$Receipt.model_construction_count -eq 0 -and
        [int]$Receipt.world_attempt_count -eq 0 -and
        [int]$Receipt.world_build_count -eq 0 -and
        -not [bool]$Receipt.physical_acceptance_authority
    ) "$Label crossed the zero-world boundary"
}

function Invoke-R23D66PowerShellGate(
    [string]$Path,
    [string]$ExpectedText,
    [string[]]$AdditionalArguments = @()
) {
    $arguments = @(
        "-NoLogo", "-NoProfile", "-File", $Path
    ) + @($AdditionalArguments)
    $result = Invoke-R23D66Process -FileName $powerShellHost `
        -Arguments $arguments -WorkingDirectory $repoRoot
    Assert-R23D66ZeroWorld (
        [int]$result.exit_code -eq 0 -and
        [string]$result.text -cmatch [Regex]::Escape($ExpectedText)
    ) "gate failed or marker changed: $Path`n$($result.text)"
    return $result
}

function Get-R23D66WorkerCommand([string]$EngineId, [string]$Command, [string]$ArmId) {
    $common = @(
        "--stage", $stageId,
        "--onset", $onsetId,
        "--profile", $profileId,
        "--arm", $ArmId
    )
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
            $arguments = @($Command) + $common[0..3] + @(
                "--seed", "$campaignSeed"
            ) + $common[4..7]
            if ($Command -eq "physical") {
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
                "-m", $mujocoModule, $Command,
                "--stage", $stageId,
                "--onset", $onsetId,
                "--campaign-seed", "$campaignSeed",
                "--profile", $profileId,
                "--arm", $ArmId
            )
            if ($Command -eq "physical") {
                $arguments += @("--source-commit", $sourceCommit)
            }
            return [ordered]@{
                file = $mujocoPython
                working_directory = $mujocoRoot
                arguments = $arguments
            }
        }
        default { throw "unsupported engine: $EngineId" }
    }
}

function Invoke-R23D66Worker([string]$EngineId, [string]$Command, [string]$ArmId) {
    $definition = Get-R23D66WorkerCommand $EngineId $Command $ArmId
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
        Assert-R23D66ZeroWorld (
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
            lines = $lines
            text = ((@($lines) -join "`n") + [string]$result.stderr)
            termination_protocol_valid = $true
            supervisor_terminated = $true
        }
    }
    return Invoke-R23D66Process -FileName $definition.file `
        -Arguments @($definition.arguments) `
        -WorkingDirectory $definition.working_directory
}

$pythonHost = Resolve-R23D66Application $Python "python"
$powerShellHost = Resolve-R23D66Application $PowerShell "pwsh"
$cargoHost = Resolve-R23D66Application $Cargo "cargo"
$godotHost = Resolve-R23D66Application $Godot $Godot

Assert-R23D66ZeroWorld (
    (& git -C $repoRoot rev-parse --show-toplevel).Trim() -ceq
        $repoRoot.Replace("\", "/") -and
    (& git -C $repoRoot remote get-url origin).Trim() -ceq
        "https://github.com/Slagathore/sporespore.git"
) "repository identity changed"
$sourceCommit = (& git -C $repoRoot rev-parse HEAD).Trim()
Assert-R23D66ZeroWorld ($sourceCommit -cmatch '^[0-9a-f]{40}$') "HEAD identity invalid"

foreach ($path in @(
    $materializer,
    $implementationPath,
    $preregistrationGate,
    $evaluatorGate,
    $operationLockGate,
    $strictJsonGate,
    $godotTerminationHelper,
    $mujocoPython,
    $rapierManifest
)) {
    Assert-R23D66ZeroWorld (Test-Path -LiteralPath $path -PathType Leaf) (
        "required path missing: $path"
    )
}
foreach ($name in @($physicalEnvironmentNames | Where-Object {
    ([string]$_).StartsWith("SPORESPORE_QSDK_R23D66_", [StringComparison]::Ordinal)
})) {
    Assert-R23D66ZeroWorld (
        [string]::IsNullOrEmpty([Environment]::GetEnvironmentVariable($name, "Process"))
    ) "physical authorization environment is already populated: $name"
}

$materialization = Invoke-R23D66Process -FileName $pythonHost -Arguments @(
    $materializer, "check"
) -WorkingDirectory $repoRoot
Assert-R23D66ZeroWorld (
    [int]$materialization.exit_code -eq 0 -and
    [string]$materialization.text -cmatch "QSDK_R23D66_IMPLEMENTATION"
) "implementation materialization drifted: $($materialization.text)"
$implementation = Get-Content -LiteralPath $implementationPath -Raw |
    ConvertFrom-Json -AsHashtable -Depth 100
Assert-R23D66ZeroWorld (
    [string]$implementation.schema_version -ceq
        "sporespore_qsdk_r23d66_production_route_three_engine_turning_implementation_v1" -and
    [bool]$implementation.claims.implementation_complete -and
    [bool]$implementation.claims.complete_zero_world_gate_passed -and
    @($implementation.ordered_cell_ids).Count -eq 9 -and
    @($implementation.dependency_digests.Keys).Count -gt 0
) "implementation contract identity changed"

$build = Invoke-R23D66Process -FileName $cargoHost -Arguments @(
    "build", "--quiet", "--manifest-path", $rapierManifest,
    "--bin", "qsdk_r23d66_turning_route"
) -WorkingDirectory $repoRoot
Assert-R23D66ZeroWorld ([int]$build.exit_code -eq 0) (
    "Rapier worker build failed: $($build.text)"
)
Assert-R23D66ZeroWorld (Test-Path -LiteralPath $rapierBinary -PathType Leaf) (
    "Rapier worker binary missing after build"
)

$engineDefinitions = @(
    [ordered]@{
        id = "godot_jolt"
        positive_marker = "QSDK_R23D66_GODOT_JOLT_PREFLIGHT "
        failure_marker = "QSDK_R23D66_GODOT_JOLT_FAILURE "
        terminal_marker = "QSDK_R23D66_GODOT_JOLT_TERMINAL "
        invalid_code = "QSDK_R23D66_GJT_CELL_IDENTITY_INVALID"
        authorization_code = "QSDK_R23D66_GJT_PHYSICAL_AUTHORIZATION_REQUIRED"
    },
    [ordered]@{
        id = "rapier_parry"
        positive_marker = "QSDK_R23D66_RAPIER_PREFLIGHT "
        failure_marker = "QSDK_R23D66_RAPIER_FAILURE "
        terminal_marker = "QSDK_R23D66_RAPIER_TERMINAL "
        invalid_code = "QSDK_R23D66_RAP_ARM_INVALID"
        authorization_code = "QSDK_R23D66_RAP_PHYSICAL_AUTHORIZATION_REQUIRED"
    },
    [ordered]@{
        id = "mujoco"
        positive_marker = "QSDK_R23D66_MUJOCO_PREFLIGHT "
        failure_marker = "QSDK_R23D66_MUJOCO_FAILURE "
        terminal_marker = "QSDK_R23D66_MUJOCO_FAILURE "
        invalid_code = "QSDK_R23D66_MJC_WORKER_FAILURE"
        authorization_code = "QSDK_R23D66_MJC_PHYSICAL_AUTHORIZATION_REQUIRED"
    }
)

$preflights = [Collections.Generic.List[object]]::new()
$selectorNegatives = [Collections.Generic.List[object]]::new()
$authorizationNegatives = [Collections.Generic.List[object]]::new()
foreach ($engine in $engineDefinitions) {
    $engineId = [string]$engine.id
    $positiveProcess = Invoke-R23D66Worker $engineId "preflight" $referenceArm
    Assert-R23D66ZeroWorld ([int]$positiveProcess.exit_code -eq 0) (
        "$engineId positive preflight failed: $($positiveProcess.text)"
    )
    $positive = Get-R23D66MarkerJson $positiveProcess $engine.positive_marker
    Assert-R23D66NoWorld $positive "$engineId positive preflight"
    Assert-R23D66ZeroWorld (
        [string]$positive.campaign_id -ceq $campaignId -and
        [string]$positive.gate_id -ceq $gateId -and
        [string]$positive.engine_id -ceq $engineId -and
        [string]$positive.cell_id -ceq
            "r23d66__${engineId}__s23179__reference_zero"
    ) "$engineId positive preflight identity changed"
    $preflights.Add([ordered]@{
        engine_id = $engineId
        cell_id = [string]$positive.cell_id
        returned_before_model = $true
    })

    $selectorProcess = Invoke-R23D66Worker $engineId "preflight" $invalidArm
    Assert-R23D66ZeroWorld ([int]$selectorProcess.exit_code -ne 0) (
        "$engineId accepted an invalid arm selector"
    )
    $selector = Get-R23D66MarkerJson $selectorProcess $engine.failure_marker
    Assert-R23D66NoWorld $selector "$engineId selector negative"
    Assert-R23D66ZeroWorld (
        [string]$selector.failure_code -cmatch [Regex]::Escape($engine.invalid_code)
    ) "$engineId invalid-selector failure changed: $($selector.failure_code)"
    $selectorNegatives.Add([ordered]@{
        engine_id = $engineId
        failure_code = [string]$selector.failure_code
    })

    $authorizationProcess = Invoke-R23D66Worker $engineId "physical" $referenceArm
    Assert-R23D66ZeroWorld ([int]$authorizationProcess.exit_code -ne 0) (
        "$engineId crossed the physical authorization barrier"
    )
    $authorization = Get-R23D66MarkerJson (
        $authorizationProcess
    ) $engine.terminal_marker
    Assert-R23D66NoWorld $authorization "$engineId authorization negative"
    Assert-R23D66ZeroWorld (
        [string]$authorization.failure_code -cmatch
            [Regex]::Escape($engine.authorization_code)
    ) "$engineId authorization-negative failure changed: $($authorization.failure_code)"
    $authorizationNegatives.Add([ordered]@{
        engine_id = $engineId
        failure_code = [string]$authorization.failure_code
    })
}

# Fast route and authorization checks intentionally run first. The full-volume
# evaluator is a qualification cost, not a development loop or a way to find
# ordinary worker-integration mistakes.
$null = Invoke-R23D66PowerShellGate $preregistrationGate (
    "[turning/3e] PASS R23D66 finite-decision declaration"
)
$null = Invoke-R23D66PowerShellGate $evaluatorGate (
    "[turning/3e] PASS R23D66 accepted evaluator binding"
)
$operationLockArguments = if ($ExpectProductionConformanceLockHeld) {
    @("-ExpectProductionConformanceLockHeld")
} else { @() }
$null = Invoke-R23D66PowerShellGate $operationLockGate `
    "LOCOMOTION_OPERATION_LOCK_PASS" $operationLockArguments
$null = Invoke-R23D66PowerShellGate $strictJsonGate (
    "STRICT_JSON_ARRAY_DOCUMENT_TEST_PASS"
)

$receipt = [ordered]@{
    schema_version = "sporespore_qsdk_r23d66_complete_zero_world_gate_v1"
    campaign_id = $campaignId
    gate_id = $gateId
    question_class = "finite_decision"
    source_commit = $sourceCommit
    implementation_contract_path = (
        "sdk/turning/" +
        "r23d66_production_route_three_engine_turning_implementation_v1.json"
    )
    implementation_dependency_count = @($implementation.dependency_digests.Keys).Count
    declared_cell_count = 9
    representative_worker_preflight_count = $preflights.Count
    worker_preflights = @($preflights)
    native_selector_negative_count = $selectorNegatives.Count
    selector_negatives = @($selectorNegatives)
    physical_authorization_negative_count = $authorizationNegatives.Count
    authorization_negatives = @($authorizationNegatives)
    full_matrix_and_schedule_evaluator_preflight_passed = $true
    evaluator_outcome_control_count = 4
    declaration_mutation_rejection_count = 13
    shared_operation_lock_gate_passed = $true
    shared_operation_lock_gate_mode = if ($ExpectProductionConformanceLockHeld) {
        "active_production_conformance_lock_verified"
    } else {
        "standalone_physical_conformance_entrypoint_interlock_verified"
    }
    shared_append_only_json_gate_passed = $true
    accepted_production_route_closure_reused_exactly = $true
    complete_zero_world_gate_passed = $true
    all_physical_claims_false = $true
    model_construction_count = 0
    world_attempt_count = 0
    world_build_count = 0
    physical_execution_authorized = $false
    physical_acceptance_authority = $false
    finite_three_engine_turning = $false
    q_sdk_r23_satisfied = $false
    cross_engine_equivalence = $false
    prone_to_standing = $false
    release_authorized = $false
}
Write-Output (
    "QSDK_R23D66_COMPLETE_ZERO_WORLD_PASS " +
    ($receipt | ConvertTo-Json -Compress -Depth 100)
)
