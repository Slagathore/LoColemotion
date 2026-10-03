#requires -Version 7.0

[CmdletBinding()]
param(
    [ValidateSet("development", "qualification")]
    [string]$Mode = "development",
    [string]$EvidenceRoot =
        "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence",
    [string]$GateId = "QSDK-R24D18",
    [string]$ContractRelativePath =
        "sdk/recovery/r24d18_mujoco_native_recovery_development_contract_v1.json",
    [string]$ContractSchema =
        "sporespore_qsdk_r24d18_mujoco_native_recovery_development_contract_v1",
    [string]$AuditRelativePath =
        "tests/test_qsdk_r24d18_mujoco_native_recovery_route_source.py",
    [string]$SourceAuditPassMarker =
        "QSDK_R24D18_MUJOCO_RECOVERY_SOURCE_PASS",
    [string]$WorkerModule =
        "sporespore_mujoco_adapter.qsdk_r24d18_recovery_development_worker",
    [string]$QualificationDirectoryPrefix = "qsdk-r24d18-qualification-",
    [string]$QualificationAttemptSchema =
        "sporespore_qsdk_r24d18_mujoco_recovery_zero_world_attempt_v1",
    [string]$QualificationFailureSchema =
        "sporespore_qsdk_r24d18_mujoco_recovery_zero_world_failure_v1",
    [string]$QualificationReceiptSchema =
        "sporespore_qsdk_r24d18_mujoco_recovery_zero_world_receipt_v1",
    [ValidateSet("debug", "release")]
    [string]$CoreBuildProfile = "debug"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$PSNativeCommandUseErrorActionPreference = $false

$expectedRepoRoot = "C:\Users\Cole\CodeStuff\games\SporeSpore"
$expectedRemote = "https://github.com/Slagathore/sporespore.git"
$expectedEvidenceRoot =
    "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence"
$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$evidenceRootFull = [IO.Path]::GetFullPath($EvidenceRoot)
$cargoManifest = Join-Path $repoRoot "sdk/Cargo.toml"
$pythonPath = Join-Path $repoRoot `
    "sdk/adapters/mujoco/.venv/Scripts/python.exe"
$coreLibraryPath = Join-Path $repoRoot `
    "sdk/target/$CoreBuildProfile/sporespore_locomotion_core.dll"
$contractPath = Join-Path $repoRoot $ContractRelativePath
$auditPath = Join-Path $repoRoot $AuditRelativePath
$adapterRuntimeTestPath = Join-Path $repoRoot `
    "sdk/adapters/mujoco/test_recovery_runtime.py"
$adapterRouteTestPath = Join-Path $repoRoot `
    "sdk/adapters/mujoco/test_native_recovery_development.py"
$operationLockPath = Join-Path $repoRoot "sdk/locomotion_operation_lock.ps1"
$workerModule = $WorkerModule

function Assert-NativeSuccess {
    param([Parameter(Mandatory)][string]$Operation)
    if ($LASTEXITCODE -ne 0) {
        throw "QSDK_R24D18_ZERO_WORLD_COMMAND_FAILED:$Operation`:$LASTEXITCODE"
    }
}

function Get-RawSha256 {
    param([Parameter(Mandatory)][string]$Path)
    return "sha256:" + (
        Get-FileHash -Algorithm SHA256 -LiteralPath $Path
    ).Hash.ToLowerInvariant()
}

function Write-JsonExclusive {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][object]$Value
    )
    if (Test-Path -LiteralPath $Path) {
        throw "QSDK_R24D18_ZERO_WORLD_EVIDENCE_EXISTS:$Path"
    }
    $Value | ConvertTo-Json -Depth 40 -Compress |
        Set-Content -LiteralPath $Path -Encoding utf8NoBOM -NoNewline
    Add-Content -LiteralPath $Path -Value "" -Encoding utf8NoBOM
}

function Write-Log {
    param(
        [AllowNull()][string]$Directory,
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][object[]]$Lines
    )
    if ([string]::IsNullOrWhiteSpace($Directory)) { return }
    $path = Join-Path $Directory $Name
    @($Lines | ForEach-Object { [string]$_ }) |
        Set-Content -LiteralPath $path -Encoding utf8NoBOM
}

if ($repoRoot -cne $expectedRepoRoot) {
    throw "QSDK_R24D18_ZERO_WORLD_REPOSITORY_ROOT_MISMATCH:$repoRoot"
}
if ($evidenceRootFull -cne $expectedEvidenceRoot -or
    -not (Test-Path -LiteralPath $evidenceRootFull -PathType Container)) {
    throw "QSDK_R24D18_ZERO_WORLD_EVIDENCE_ROOT_INVALID:$evidenceRootFull"
}
foreach ($required in @(
    $cargoManifest,
    $pythonPath,
    $contractPath,
    $auditPath,
    $adapterRuntimeTestPath,
    $adapterRouteTestPath,
    $operationLockPath
)) {
    if (-not (Test-Path -LiteralPath $required -PathType Leaf)) {
        throw "QSDK_R24D18_ZERO_WORLD_DEPENDENCY_MISSING:$required"
    }
}

$topLevelRaw = (& git -C $repoRoot rev-parse --show-toplevel).Trim()
Assert-NativeSuccess "show-toplevel"
$topLevel = [IO.Path]::GetFullPath($topLevelRaw)
$remote = (& git -C $repoRoot remote get-url origin).Trim()
Assert-NativeSuccess "remote"
$branch = (& git -C $repoRoot branch --show-current).Trim()
Assert-NativeSuccess "branch"
$head = (& git -C $repoRoot rev-parse HEAD).Trim()
Assert-NativeSuccess "head"
$status = @(& git -C $repoRoot status --porcelain=v1)
Assert-NativeSuccess "status"
if ($topLevel -cne $expectedRepoRoot -or $remote -cne $expectedRemote) {
    throw "QSDK_R24D18_ZERO_WORLD_REPOSITORY_IDENTITY_INVALID"
}
$upstream = $null
$remoteHead = $null
if ($Mode -ceq "qualification") {
    $upstream = (& git -C $repoRoot rev-parse '@{upstream}').Trim()
    Assert-NativeSuccess "upstream"
    $remoteLine = (& git -C $repoRoot ls-remote origin refs/heads/main).Trim()
    Assert-NativeSuccess "live-remote"
    $remoteHead = ($remoteLine -split "\s+")[0]
    if ($branch -cne "main" -or $status.Count -ne 0 -or
        $head -cne $upstream -or $head -cne $remoteHead) {
        throw "QSDK_R24D18_ZERO_WORLD_SOURCE_NOT_CLEAN_PUSHED_EQUAL"
    }
}

$contract = Get-Content -Raw -LiteralPath $contractPath | ConvertFrom-Json
if ([string]$contract.schema_version -cne
        $ContractSchema -or
    [string]$contract.gate_id -cne $GateId -or
    [bool]$contract.complete_zero_world_gate.must_pass_before_physics -ne $true -or
    [bool]$contract.complete_zero_world_gate.construct_mujoco_model -ne $false -or
    [int]$contract.complete_zero_world_gate.world_attempt_count -ne 0 -or
    [int]$contract.complete_zero_world_gate.world_build_count -ne 0 -or
    [int]$contract.complete_zero_world_gate.solver_step_count -ne 0) {
    throw "QSDK_R24D18_ZERO_WORLD_CONTRACT_INVALID"
}

$evidenceDirectory = $null
if ($Mode -ceq "qualification") {
    $priorAttempts = @(
        Get-ChildItem -LiteralPath $evidenceRootFull -Directory `
            -Filter "$QualificationDirectoryPrefix*" |
        ForEach-Object {
            $attemptPath = Join-Path $_.FullName "qualification_attempt.json"
            if (Test-Path -LiteralPath $attemptPath -PathType Leaf) {
                Get-Content -Raw -LiteralPath $attemptPath | ConvertFrom-Json
            }
        } |
        Where-Object {
            [string]$_.gate_id -ceq $GateId -and
            [string]$_.source_commit -ceq $head
        }
    )
    if ($priorAttempts.Count -ne 0) {
        throw "QSDK_R24D18_ZERO_WORLD_EXACT_SOURCE_ALREADY_QUALIFIED_OR_ATTEMPTED"
    }
}

. $operationLockPath
$operationLockReceipt = $null
$operationLockPublic = $null
$caughtError = $null
$preflight = $null
$checks = [ordered]@{}
$previousPythonPath = $env:PYTHONPATH
try {
    $operationLockReceipt =
        Enter-SporeSporeLocomotionOperationLock -Role conformance
    if (-not [bool]$operationLockReceipt.acquired -or
        [bool]$operationLockReceipt.test_only -or
        [bool]$operationLockReceipt.abandoned_owner_recovered) {
        throw "QSDK_R24D18_ZERO_WORLD_OPERATION_LOCK_REFUSED"
    }
    $operationLockPublic =
        Get-SporeSporeLocomotionOperationLockPublicReceipt $operationLockReceipt
    if ($Mode -ceq "qualification") {
        $timestamp = [DateTime]::UtcNow.ToString("yyyyMMddTHHmmssfffZ")
        $directoryName =
            "$QualificationDirectoryPrefix$timestamp-$($head.Substring(0, 8))"
        $evidenceDirectory = Join-Path $evidenceRootFull $directoryName
        New-Item -ItemType Directory -Path $evidenceDirectory -ErrorAction Stop |
            Out-Null
        $attempt = [ordered]@{
            schema_version = $QualificationAttemptSchema
            gate_id = $GateId
            mode = "qualification"
            started_utc = [DateTime]::UtcNow.ToString("o")
            source_commit = $head
            branch = $branch
            remote = $remote
            upstream_commit = $upstream
            live_remote_commit = $remoteHead
            worktree_clean_at_start = $true
            operation_lock = $operationLockPublic
            model_construction_count = 0
            world_attempt_count = 0
            world_build_count = 0
            solver_step_count = 0
            physics_state_modified = $false
            physical_question_opened = $false
            prone_to_standing_claimed = $false
            physical_acceptance_authority = $false
            release_authority = $false
        }
        Write-JsonExclusive `
            (Join-Path $evidenceDirectory "qualification_attempt.json") `
            $attempt
    }

    $cargoBuildArguments = @(
        "build",
        "--offline",
        "-p",
        "sporespore-locomotion-core",
        "--lib",
        "--manifest-path",
        $cargoManifest
    )
    if ($CoreBuildProfile -ceq "release") {
        $cargoBuildArguments += "--release"
    }
    $cargoBuildOutput = @(& cargo @cargoBuildArguments 2>&1)
    Write-Log $evidenceDirectory "cargo_build.log" $cargoBuildOutput
    Assert-NativeSuccess "cargo-build"
    $checks["core_dynamic_library_rebuilt"] = $true

    $cargoTestOutput = @(
        & cargo test --offline -p sporespore-locomotion-core --lib recovery `
            --manifest-path $cargoManifest 2>&1
    )
    Write-Log $evidenceDirectory "cargo_recovery_tests.log" $cargoTestOutput
    Assert-NativeSuccess "cargo-recovery-tests"
    $checks["core_recovery_tests_passed"] = $true

    $env:PYTHONPATH =
        (Join-Path $repoRoot "sdk/python") + ";" +
        (Join-Path $repoRoot "sdk/adapters/mujoco")
    $runtimeTestOutput = @(
        & $pythonPath -m unittest -v $adapterRuntimeTestPath 2>&1
    )
    Write-Log $evidenceDirectory "mujoco_runtime_tests.log" $runtimeTestOutput
    Assert-NativeSuccess "mujoco-runtime-tests"
    $routeTestOutput = @(
        & $pythonPath -m unittest -v $adapterRouteTestPath 2>&1
    )
    Write-Log $evidenceDirectory "mujoco_route_tests.log" $routeTestOutput
    Assert-NativeSuccess "mujoco-route-tests"
    $checks["mujoco_adapter_zero_world_tests_passed"] = $true

    $auditOutput = @(& $pythonPath $auditPath 2>&1)
    Write-Log $evidenceDirectory "source_audit.log" $auditOutput
    Assert-NativeSuccess "source-audit"
    if (-not (@($auditOutput) -join "`n").Contains($SourceAuditPassMarker)) {
        throw "QSDK_R24D18_ZERO_WORLD_SOURCE_AUDIT_MARKER_MISSING"
    }
    $checks["source_contract_audit_passed"] = $true

    $preflightOutput = @(
        & $pythonPath -m $workerModule preflight `
            --core-library $coreLibraryPath 2>&1
    )
    Write-Log $evidenceDirectory "production_preflight.log" $preflightOutput
    Assert-NativeSuccess "production-preflight"
    $preflightRaw = [string]$preflightOutput[-1]
    $preflight = $preflightRaw | ConvertFrom-Json
    if (-not [bool]$preflight.ok -or
        [string]$preflight.engine -cne "mujoco_native" -or
        [string]$preflight.engine_version -cne "3.11.0" -or
        [int]$preflight.model_construction_count -ne 0 -or
        [int]$preflight.world_attempt_count -ne 0 -or
        [int]$preflight.world_build_count -ne 0 -or
        [int]$preflight.solver_step_count -ne 0 -or
        [bool]$preflight.physics_state_modified -or
        [bool]$preflight.physical_question_opened -or
        [bool]$preflight.prone_to_standing_claimed) {
        throw "QSDK_R24D18_ZERO_WORLD_PRODUCTION_PREFLIGHT_INVALID"
    }
    $checks["production_preflight_passed"] = $true

    $finalStatus = @(& git -C $repoRoot status --porcelain=v1)
    Assert-NativeSuccess "final-status"
    if ($Mode -ceq "qualification" -and $finalStatus.Count -ne 0) {
        throw "QSDK_R24D18_ZERO_WORLD_WORKTREE_DRIFT"
    }
    $checks["worktree_unchanged"] = $true
} catch {
    $caughtError = $_
} finally {
    $env:PYTHONPATH = $previousPythonPath
    if ($null -ne $operationLockReceipt -and
        [bool]$operationLockReceipt.acquired -and
        -not [bool]$operationLockReceipt.released) {
        Exit-SporeSporeLocomotionOperationLock $operationLockReceipt
    }
}

if ($null -ne $caughtError) {
    if ($null -ne $evidenceDirectory) {
        $failure = [ordered]@{
            schema_version = $QualificationFailureSchema
            gate_id = $GateId
            mode = $Mode
            failed_utc = [DateTime]::UtcNow.ToString("o")
            source_commit = $head
            error = [string]$caughtError.Exception.Message
            completed_checks = $checks
            operation_lock_released =
                $null -ne $operationLockReceipt -and
                [bool]$operationLockReceipt.released
            model_construction_count = 0
            world_attempt_count = 0
            world_build_count = 0
            solver_step_count = 0
            physics_state_modified = $false
            physical_question_opened = $false
            prone_to_standing_claimed = $false
            physical_acceptance_authority = $false
            release_authority = $false
        }
        Write-JsonExclusive `
            (Join-Path $evidenceDirectory "qualification_failure.json") `
            $failure
    }
    throw $caughtError
}

$sourceManifest = @()
foreach ($relative in @($contract.source_inventory)) {
    $sourcePath = Join-Path $repoRoot ([string]$relative)
    $blob = (& git -C $repoRoot hash-object -- $sourcePath).Trim()
    Assert-NativeSuccess "source-blob:$relative"
    $sourceManifest += [ordered]@{
        path = [string]$relative
        raw_sha256 = Get-RawSha256 $sourcePath
        byte_length = (Get-Item -LiteralPath $sourcePath).Length
        git_blob_oid = $blob
    }
}
$rustcVersion = (& rustc --version).Trim()
Assert-NativeSuccess "rustc-version"
$cargoVersion = (& cargo --version).Trim()
Assert-NativeSuccess "cargo-version"
$pythonVersion = (& $pythonPath --version 2>&1).Trim()
Assert-NativeSuccess "python-version"
$numpyVersion = $null
if ($null -ne $preflight.PSObject.Properties["numpy_version"]) {
    $numpyVersion = [string]$preflight.numpy_version
}
$receipt = [ordered]@{
    schema_version = $QualificationReceiptSchema
    gate_id = $GateId
    mode = $Mode
    completed_utc = [DateTime]::UtcNow.ToString("o")
    ok = $true
    source_commit = $head
    branch = $branch
    remote = $remote
    upstream_commit = $upstream
    live_remote_commit = $remoteHead
    contract_path = $ContractRelativePath
    contract_raw_sha256 = Get-RawSha256 $contractPath
    source_manifest = $sourceManifest
    toolchain = [ordered]@{
        rustc = $rustcVersion
        cargo = $cargoVersion
        python = $pythonVersion
        python_executable_raw_sha256 = Get-RawSha256 $pythonPath
        mujoco = [string]$preflight.engine_version
        numpy = $numpyVersion
        powershell = [string]$PSVersionTable.PSVersion
        core_build_profile = $CoreBuildProfile
        core_library_raw_sha256 = Get-RawSha256 $coreLibraryPath
    }
    operation_lock = $operationLockPublic
    operation_lock_released = [bool]$operationLockReceipt.released
    checks = $checks
    production_preflight = $preflight
    selected_physical_question_class = "development"
    selected_physical_cell_count = 1
    held_out_cell_access_count = 0
    held_out_selector_invocation_count = 0
    model_construction_count = 0
    world_attempt_count = 0
    world_build_count = 0
    solver_step_count = 0
    physics_state_modified = $false
    physical_question_opened = $false
    controller_physical_viability_proven = $false
    prone_to_standing_claimed = $false
    physical_acceptance_authority = $false
    release_authority = $false
}
if ($Mode -ceq "qualification") {
    $receiptPath = Join-Path $evidenceDirectory "qualification_receipt.json"
    Write-JsonExclusive $receiptPath $receipt
    Write-Output (
        "$($GateId.Replace('-', '_'))_MUJOCO_RECOVERY_ZERO_WORLD_PASS " +
        "mode=qualification " +
        "source=$head receipt=$receiptPath worlds=0 solver_steps=0"
    )
} else {
    Write-Output ($receipt | ConvertTo-Json -Depth 40 -Compress)
}
