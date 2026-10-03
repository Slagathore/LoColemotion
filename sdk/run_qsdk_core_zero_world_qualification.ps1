#requires -Version 7.0

<#
.SYNOPSIS
Shared clean-source qualification runner for engine-neutral core-only gates.

.DESCRIPTION
Builds and tests the portable core, checks the Godot host binding, crosses the
real C/Python ABI, runs the gate's compact source audit and production
preflight, and retains a content-addressed zero-world receipt. A gate may also
declare one Godot parse target and one pure native zero-world script. It has no
physical worker path and never constructs a native engine model or world.
#>

[CmdletBinding()]
param(
    [ValidateSet("development", "qualification")]
    [string]$Mode = "development",
    [string]$EvidenceRoot =
        "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence",
    [Parameter(Mandatory)][string]$GateId,
    [Parameter(Mandatory)][string]$ContractRelativePath,
    [Parameter(Mandatory)][string]$ContractSchema,
    [Parameter(Mandatory)][string]$AuditRelativePath,
    [Parameter(Mandatory)][string]$SourceAuditPassMarker,
    [Parameter(Mandatory)][string]$PreflightRelativePath,
    [Parameter(Mandatory)][string]$CargoTestFilter,
    [Parameter(Mandatory)][string]$PythonSmokeTest,
    [Parameter(Mandatory)][string]$VersioningTest,
    [Parameter(Mandatory)][string]$QualificationDirectoryPrefix,
    [Parameter(Mandatory)][string]$QualificationAttemptSchema,
    [Parameter(Mandatory)][string]$QualificationFailureSchema,
    [Parameter(Mandatory)][string]$QualificationReceiptSchema,
    [string]$NativeZeroWorldRuntimePath = "",
    [string]$NativeZeroWorldScriptRelativePath = "",
    [string]$NativeZeroWorldPassMarker = "",
    [string]$GodotParseScriptRelativePath = "",
    [switch]$ProspectivePhysicalQuestionDeclared
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
$cargoManifest = Join-Path $repoRoot "sdk\Cargo.toml"
$coreLibraryPath = Join-Path $repoRoot `
    "sdk\target\debug\sporespore_locomotion_core.dll"
$contractPath = Join-Path $repoRoot $ContractRelativePath
$auditPath = Join-Path $repoRoot $AuditRelativePath
$preflightPath = Join-Path $repoRoot $PreflightRelativePath
$operationLockPath = Join-Path $repoRoot "sdk\locomotion_operation_lock.ps1"
$pythonPath = (Get-Command python -ErrorAction Stop).Source
$nativeZeroWorldEnabled = -not [string]::IsNullOrWhiteSpace(
    $NativeZeroWorldRuntimePath
)
$nativeZeroWorldScriptPath = $null
$godotParseScriptPath = $null

function Assert-CoreZeroWorldSuccess {
    param([Parameter(Mandatory)][string]$Operation)
    if ($LASTEXITCODE -ne 0) {
        throw "QSDK_CORE_ZERO_WORLD_COMMAND_FAILED:$Operation`:$LASTEXITCODE"
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
        throw "QSDK_CORE_ZERO_WORLD_EVIDENCE_EXISTS:$Path"
    }
    $Value | ConvertTo-Json -Depth 50 -Compress |
        Set-Content -LiteralPath $Path -Encoding utf8NoBOM -NoNewline
    Add-Content -LiteralPath $Path -Value "" -Encoding utf8NoBOM
}

function Write-QualificationLog {
    param(
        [AllowNull()][string]$Directory,
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][object[]]$Lines
    )
    if ([string]::IsNullOrWhiteSpace($Directory)) { return }
    @($Lines | ForEach-Object { [string]$_ }) |
        Set-Content -LiteralPath (Join-Path $Directory $Name) `
            -Encoding utf8NoBOM
}

if ($repoRoot -cne $expectedRepoRoot) {
    throw "QSDK_CORE_ZERO_WORLD_REPOSITORY_ROOT_MISMATCH:$repoRoot"
}
if ($evidenceRootFull -cne $expectedEvidenceRoot -or
    -not (Test-Path -LiteralPath $evidenceRootFull -PathType Container)) {
    throw "QSDK_CORE_ZERO_WORLD_EVIDENCE_ROOT_INVALID:$evidenceRootFull"
}
foreach ($required in @(
    $cargoManifest,
    $pythonPath,
    $contractPath,
    $auditPath,
    $preflightPath,
    $operationLockPath
)) {
    if (-not (Test-Path -LiteralPath $required -PathType Leaf)) {
        throw "QSDK_CORE_ZERO_WORLD_DEPENDENCY_MISSING:$required"
    }
}
if ($nativeZeroWorldEnabled -ne (
    -not [string]::IsNullOrWhiteSpace($NativeZeroWorldScriptRelativePath) -and
    -not [string]::IsNullOrWhiteSpace($NativeZeroWorldPassMarker)
)) {
    throw "QSDK_CORE_ZERO_WORLD_NATIVE_GATE_ARGUMENTS_INCOMPLETE"
}
if ($nativeZeroWorldEnabled) {
    $NativeZeroWorldRuntimePath = [IO.Path]::GetFullPath(
        $NativeZeroWorldRuntimePath
    )
    $nativeZeroWorldScriptPath = Join-Path `
        $repoRoot $NativeZeroWorldScriptRelativePath
    if (-not (Test-Path -LiteralPath $NativeZeroWorldRuntimePath -PathType Leaf) -or
        -not (Test-Path -LiteralPath $nativeZeroWorldScriptPath -PathType Leaf)) {
        throw "QSDK_CORE_ZERO_WORLD_NATIVE_GATE_DEPENDENCY_MISSING"
    }
}
if (-not [string]::IsNullOrWhiteSpace($GodotParseScriptRelativePath)) {
    if (-not $nativeZeroWorldEnabled) {
        throw "QSDK_CORE_ZERO_WORLD_GODOT_PARSE_RUNTIME_MISSING"
    }
    $godotParseScriptPath = Join-Path $repoRoot $GodotParseScriptRelativePath
    if (-not (Test-Path -LiteralPath $godotParseScriptPath -PathType Leaf)) {
        throw "QSDK_CORE_ZERO_WORLD_GODOT_PARSE_SCRIPT_MISSING"
    }
}

$topLevelRaw = (& git -C $repoRoot rev-parse --show-toplevel).Trim()
Assert-CoreZeroWorldSuccess "show-toplevel"
$topLevel = [IO.Path]::GetFullPath($topLevelRaw)
$remote = (& git -C $repoRoot remote get-url origin).Trim()
Assert-CoreZeroWorldSuccess "remote"
$branch = (& git -C $repoRoot branch --show-current).Trim()
Assert-CoreZeroWorldSuccess "branch"
$head = (& git -C $repoRoot rev-parse HEAD).Trim()
Assert-CoreZeroWorldSuccess "head"
$initialStatusLines = @(& git -C $repoRoot status --porcelain=v1)
Assert-CoreZeroWorldSuccess "initial-status"
$initialStatus = [string]::Join("`n", $initialStatusLines)
if ($topLevel -cne $expectedRepoRoot -or $remote -cne $expectedRemote) {
    throw "QSDK_CORE_ZERO_WORLD_REPOSITORY_IDENTITY_INVALID"
}

$upstream = $null
$remoteHead = $null
if ($Mode -ceq "qualification") {
    $upstream = (& git -C $repoRoot rev-parse '@{upstream}').Trim()
    Assert-CoreZeroWorldSuccess "upstream"
    $remoteLine = (& git -C $repoRoot ls-remote origin refs/heads/main).Trim()
    Assert-CoreZeroWorldSuccess "live-remote"
    $remoteHead = ($remoteLine -split "\s+")[0]
    if ($branch -cne "main" -or $initialStatusLines.Count -ne 0 -or
        $head -cne $upstream -or $head -cne $remoteHead) {
        throw "QSDK_CORE_ZERO_WORLD_SOURCE_NOT_CLEAN_PUSHED_EQUAL"
    }
}

$contract = Get-Content -Raw -LiteralPath $contractPath | ConvertFrom-Json
if ([string]$contract.schema_version -cne $ContractSchema -or
    [string]$contract.gate_id -cne $GateId -or
    [string]$contract.question_class -cne "development" -or
    [bool]$contract.physical_question_declared -ne
        $ProspectivePhysicalQuestionDeclared.IsPresent -or
    -not [bool]$contract.complete_zero_world_gate.must_pass_before_physics -or
    [int]$contract.complete_zero_world_gate.model_construction_count -ne 0 -or
    [int]$contract.complete_zero_world_gate.world_attempt_count -ne 0 -or
    [int]$contract.complete_zero_world_gate.world_build_count -ne 0 -or
    [long]$contract.complete_zero_world_gate.solver_step_count -ne 0) {
    throw "QSDK_CORE_ZERO_WORLD_CONTRACT_INVALID"
}
$sourceInventoryProperty = $contract.PSObject.Properties["source_inventory"]
if ($null -eq $sourceInventoryProperty) {
    throw "QSDK_CORE_ZERO_WORLD_SOURCE_INVENTORY_MISSING"
}
$sourceInventory = @(
    $sourceInventoryProperty.Value | ForEach-Object { [string]$_ }
)
if ($sourceInventory.Count -eq 0 -or
    @($sourceInventory | Sort-Object -Unique).Count -ne $sourceInventory.Count) {
    throw "QSDK_CORE_ZERO_WORLD_SOURCE_INVENTORY_INVALID"
}
foreach ($relative in $sourceInventory) {
    $sourcePath = [IO.Path]::GetFullPath((Join-Path $repoRoot $relative))
    if ([string]::IsNullOrWhiteSpace($relative) -or
        [IO.Path]::IsPathRooted($relative) -or
        -not $sourcePath.StartsWith(
            $repoRoot + [IO.Path]::DirectorySeparatorChar,
            [StringComparison]::OrdinalIgnoreCase
        ) -or
        -not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
        throw "QSDK_CORE_ZERO_WORLD_SOURCE_INVENTORY_PATH_INVALID:$relative"
    }
}

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
        throw "QSDK_CORE_ZERO_WORLD_EXACT_SOURCE_ALREADY_ATTEMPTED"
    }
}

. $operationLockPath
$operationLockReceipt = $null
$operationLockPublic = $null
$evidenceDirectory = $null
$caughtError = $null
$preflight = $null
$nativeZeroWorld = $null
$sourceManifest = @()
$checks = [ordered]@{}
$previousPythonPath = $env:PYTHONPATH
$previousLibraryPath = $env:SPORESPORE_LOCOMOTION_LIBRARY
try {
    $operationLockReceipt =
        Enter-SporeSporeLocomotionOperationLock -Role conformance
    if (-not [bool]$operationLockReceipt.acquired -or
        [bool]$operationLockReceipt.test_only -or
        [bool]$operationLockReceipt.abandoned_owner_recovered) {
        throw "QSDK_CORE_ZERO_WORLD_OPERATION_LOCK_REFUSED"
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
            prospective_physical_question_declared =
                $ProspectivePhysicalQuestionDeclared.IsPresent
            prone_to_standing_claimed = $false
            physical_acceptance_authority = $false
            release_authority = $false
        }
        Write-JsonExclusive `
            (Join-Path $evidenceDirectory "qualification_attempt.json") `
            $attempt
    }

    foreach ($relative in $sourceInventory) {
        $sourcePath = Join-Path $repoRoot $relative
        $blob = (& git -C $repoRoot hash-object -- $sourcePath).Trim()
        Assert-CoreZeroWorldSuccess "source-blob:$relative"
        $sourceManifest += [ordered]@{
            path = $relative
            raw_sha256 = Get-RawSha256 $sourcePath
            byte_length = (Get-Item -LiteralPath $sourcePath).Length
            git_blob_oid = $blob
        }
    }
    $checks["source_manifest_frozen"] = $true

    $cargoBuildOutput = @(
        & cargo build --offline -p sporespore-locomotion-core --lib `
            --manifest-path $cargoManifest 2>&1
    )
    Write-QualificationLog $evidenceDirectory "cargo_build.log" $cargoBuildOutput
    Assert-CoreZeroWorldSuccess "cargo-build"
    $checks["core_dynamic_library_rebuilt"] = $true

    $cargoTestOutput = @(
        & cargo test --offline -p sporespore-locomotion-core --lib `
            $CargoTestFilter --manifest-path $cargoManifest 2>&1
    )
    Write-QualificationLog $evidenceDirectory "cargo_targeted_tests.log" $cargoTestOutput
    Assert-CoreZeroWorldSuccess "cargo-targeted-tests"
    $checks["core_targeted_tests_passed"] = $true

    # Build the debug GDExtension before any Python process loads the shared
    # core DLL. On Windows, rebuilding afterward can race a transient loader
    # handle even though the Python process has already exited.
    $godotCheckOutput = @(
        & cargo build --offline -p sporespore-godot-adapter `
            --manifest-path $cargoManifest 2>&1
    )
    Write-QualificationLog $evidenceDirectory "godot_adapter_check.log" $godotCheckOutput
    Assert-CoreZeroWorldSuccess "godot-adapter-check"
    $checks["godot_adapter_binding_check_passed"] = $true
    $checks["godot_adapter_debug_build_passed"] = $true

    if ($null -ne $godotParseScriptPath) {
        $parseResourcePath = "res://" + (
            $GodotParseScriptRelativePath.Replace("\", "/")
        )
        $godotParseOutput = @(
            & $NativeZeroWorldRuntimePath --headless --path $repoRoot `
                --check-only --script $parseResourcePath 2>&1
        )
        Write-QualificationLog `
            $evidenceDirectory "godot_production_worker_parse.log" `
            $godotParseOutput
        Assert-CoreZeroWorldSuccess "godot-production-worker-parse"
        $checks["godot_production_worker_parse_passed"] = $true
    }

    if ($nativeZeroWorldEnabled) {
        $nativeResourcePath = "res://" + (
            $NativeZeroWorldScriptRelativePath.Replace("\", "/")
        )
        $nativeZeroWorldOutput = @(
            & $NativeZeroWorldRuntimePath --headless --path $repoRoot `
                --script $nativeResourcePath 2>&1
        )
        Write-QualificationLog `
            $evidenceDirectory "native_zero_world.log" $nativeZeroWorldOutput
        Assert-CoreZeroWorldSuccess "native-zero-world"
        $nativeLines = @(
            $nativeZeroWorldOutput |
                Where-Object { ([string]$_).StartsWith($NativeZeroWorldPassMarker) }
        )
        if ($nativeLines.Count -ne 1) {
            throw "QSDK_CORE_ZERO_WORLD_NATIVE_GATE_MARKER_INVALID"
        }
        $nativeRaw = ([string]$nativeLines[0]).Substring(
            $NativeZeroWorldPassMarker.Length
        )
        $nativeZeroWorld = $nativeRaw | ConvertFrom-Json
        if (-not [bool]$nativeZeroWorld.ok -or
            [string]$nativeZeroWorld.gate_id -cne $GateId -or
            [int]$nativeZeroWorld.model_construction_count -ne 0 -or
            [int]$nativeZeroWorld.world_attempt_count -ne 0 -or
            [int]$nativeZeroWorld.world_build_count -ne 0 -or
            [long]$nativeZeroWorld.solver_step_count -ne 0 -or
            [bool]$nativeZeroWorld.physics_state_modified -or
            [bool]$nativeZeroWorld.physical_question_opened -or
            [bool]$nativeZeroWorld.prone_to_standing_claimed -or
            [bool]$nativeZeroWorld.physical_acceptance_authority -or
            [bool]$nativeZeroWorld.release_authority) {
            throw "QSDK_CORE_ZERO_WORLD_NATIVE_GATE_RECEIPT_INVALID"
        }
        $checks["native_zero_world_gate_passed"] = $true
    }

    $env:PYTHONPATH =
        (Join-Path $repoRoot "sdk\python") + ";" +
        (Join-Path $repoRoot "sdk")
    $env:SPORESPORE_LOCOMOTION_LIBRARY = $coreLibraryPath
    $pythonSmokeOutput = @(
        & $pythonPath -m unittest -v $PythonSmokeTest 2>&1
    )
    Write-QualificationLog $evidenceDirectory "python_binding_smoke.log" $pythonSmokeOutput
    Assert-CoreZeroWorldSuccess "python-binding-smoke"
    $checks["python_binding_smoke_passed"] = $true

    $versioningOutput = @(
        & $pythonPath -m unittest -v $VersioningTest 2>&1
    )
    Write-QualificationLog $evidenceDirectory "versioning_conformance.log" $versioningOutput
    Assert-CoreZeroWorldSuccess "versioning-conformance"
    $checks["versioning_conformance_passed"] = $true

    $auditOutput = @(& $pythonPath $auditPath 2>&1)
    Write-QualificationLog $evidenceDirectory "source_audit.log" $auditOutput
    Assert-CoreZeroWorldSuccess "source-audit"
    if (-not (@($auditOutput) -join "`n").Contains($SourceAuditPassMarker)) {
        throw "QSDK_CORE_ZERO_WORLD_SOURCE_AUDIT_MARKER_MISSING"
    }
    $checks["source_contract_audit_passed"] = $true

    $preflightOutput = @(
        & $pythonPath $preflightPath --core-library $coreLibraryPath 2>&1
    )
    Write-QualificationLog $evidenceDirectory "production_preflight.log" $preflightOutput
    Assert-CoreZeroWorldSuccess "production-preflight"
    $preflightRaw = [string]$preflightOutput[-1]
    $preflight = $preflightRaw | ConvertFrom-Json
    if (-not [bool]$preflight.ok -or
        [string]$preflight.gate_id -cne $GateId -or
        [string]::IsNullOrWhiteSpace([string]$preflight.runtime_id) -or
        [string]::IsNullOrWhiteSpace([string]$preflight.runtime_version) -or
        [int]$preflight.model_construction_count -ne 0 -or
        [int]$preflight.world_attempt_count -ne 0 -or
        [int]$preflight.world_build_count -ne 0 -or
        [long]$preflight.solver_step_count -ne 0 -or
        [bool]$preflight.physics_state_modified -or
        [bool]$preflight.physical_question_opened -or
        [bool]$preflight.prone_to_standing_claimed -or
        [bool]$preflight.physical_acceptance_authority -or
        [bool]$preflight.release_authority) {
        throw "QSDK_CORE_ZERO_WORLD_PRODUCTION_PREFLIGHT_INVALID"
    }
    $checks["production_preflight_passed"] = $true

    $finalStatusLines = @(& git -C $repoRoot status --porcelain=v1)
    Assert-CoreZeroWorldSuccess "final-status"
    $finalStatus = [string]::Join("`n", $finalStatusLines)
    if ($finalStatus -cne $initialStatus) {
        throw "QSDK_CORE_ZERO_WORLD_WORKTREE_DRIFT"
    }
    $checks["worktree_unchanged"] = $true
} catch {
    $caughtError = $_
} finally {
    $env:PYTHONPATH = $previousPythonPath
    $env:SPORESPORE_LOCOMOTION_LIBRARY = $previousLibraryPath
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

$rustcVersion = (& rustc --version).Trim()
Assert-CoreZeroWorldSuccess "rustc-version"
$cargoVersion = (& cargo --version).Trim()
Assert-CoreZeroWorldSuccess "cargo-version"
$pythonVersion = (& $pythonPath --version 2>&1).Trim()
Assert-CoreZeroWorldSuccess "python-version"
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
        powershell = [string]$PSVersionTable.PSVersion
        core_library_raw_sha256 = Get-RawSha256 $coreLibraryPath
    }
    operation_lock = $operationLockPublic
    operation_lock_released = [bool]$operationLockReceipt.released
    checks = $checks
    production_preflight = $preflight
    declared_question_class = "development"
    prospective_physical_question_declared =
        $ProspectivePhysicalQuestionDeclared.IsPresent
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
if ($nativeZeroWorldEnabled) {
    $receipt["native_zero_world"] = $nativeZeroWorld
    $receipt["native_zero_world_runtime"] = [ordered]@{
        path = $NativeZeroWorldRuntimePath
        raw_sha256 = Get-RawSha256 $NativeZeroWorldRuntimePath
        script_relative_path = $NativeZeroWorldScriptRelativePath
        production_parse_script_relative_path = $GodotParseScriptRelativePath
    }
}
if ($Mode -ceq "qualification") {
    $receiptPath = Join-Path $evidenceDirectory "qualification_receipt.json"
    Write-JsonExclusive $receiptPath $receipt
}
$receipt | ConvertTo-Json -Depth 50 -Compress
