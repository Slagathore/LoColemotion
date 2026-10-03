#requires -Version 7.0

[CmdletBinding()]
param(
    [string]$EvidenceRoot =
        "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence",
    [string]$QualificationReceiptPath = "",
    [string]$GateId = "QSDK-R24D18",
    [string]$CampaignId =
        "QSDK-R24D18-MUJOCO-NATIVE-RECOVERY-ROUTE-DEVELOPMENT-GHOST",
    [string]$ContractRelativePath =
        "sdk/recovery/r24d18_mujoco_native_recovery_development_contract_v1.json",
    [string]$ContractSchema =
        "sporespore_qsdk_r24d18_mujoco_native_recovery_development_contract_v1",
    [string]$QualificationDirectoryPrefix = "qsdk-r24d18-qualification-",
    [string]$PhysicalDirectoryPrefix =
        "qsdk-r24d18-mujoco-recovery-ghost-",
    [string]$QualificationReceiptSchema =
        "sporespore_qsdk_r24d18_mujoco_recovery_zero_world_receipt_v1",
    [string]$WorkerModule =
        "sporespore_mujoco_adapter.qsdk_r24d18_recovery_development_worker",
    [string]$AttemptReservationSchema =
        "sporespore_qsdk_r24d18_recovery_ghost_attempt_reservation_v1",
    [string]$SupervisorCompletionSchema =
        "sporespore_qsdk_r24d18_recovery_ghost_supervisor_completion_v1",
    [string]$ExpectedCellId = "development_nominal",
    [int64]$ExpectedSeed = 1129522465,
    [ValidateRange(1, 1200)]
    [int]$ExpectedHorizonSteps = 14,
    [ValidateRange(1, 2)]
    [int]$ExpectedPairedArmCount = 2,
    [ValidateSet("debug", "release")]
    [string]$CoreBuildProfile = "debug",
    [switch]$ContractValidationOnly,
    [ValidateSet("", "missing_ghost_horizon", "missing_held_out_seal")]
    [string]$ContractValidationMutation = ""
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
$contractPath = Join-Path $repoRoot $ContractRelativePath
$operationLockPath = Join-Path $repoRoot "sdk/locomotion_operation_lock.ps1"
$pythonPath = Join-Path $repoRoot `
    "sdk/adapters/mujoco/.venv/Scripts/python.exe"
$coreLibraryPath = Join-Path $repoRoot `
    "sdk/target/$CoreBuildProfile/sporespore_locomotion_core.dll"
$workerModule = $WorkerModule

function Assert-NativeSuccess {
    param([Parameter(Mandatory)][string]$Operation)
    if ($LASTEXITCODE -ne 0) {
        throw "QSDK_R24D18_NATIVE_COMMAND_FAILED:$Operation`:$LASTEXITCODE"
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
        throw "QSDK_R24D18_EVIDENCE_ALREADY_EXISTS:$Path"
    }
    $Value | ConvertTo-Json -Depth 30 -Compress |
        Set-Content -LiteralPath $Path -Encoding utf8NoBOM -NoNewline
    Add-Content -LiteralPath $Path -Value "" -Encoding utf8NoBOM
}

function Read-ValidatedPhysicalContract {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Schema,
        [Parameter(Mandatory)][string]$ExpectedGateId,
        [Parameter(Mandatory)][string]$ExpectedCampaignId,
        [Parameter(Mandatory)][string]$ExpectedCell,
        [Parameter(Mandatory)][int64]$ExpectedCellSeed,
        [Parameter(Mandatory)][int]$ExpectedOuterSteps,
        [Parameter(Mandatory)][int]$ExpectedArmCount,
        [string]$ValidationMutation = ""
    )
    try {
        $value = Get-Content -Raw -LiteralPath $Path | ConvertFrom-Json
        if ($ValidationMutation -ceq "missing_ghost_horizon") {
            $value.PSObject.Properties.Remove("ghost_horizon")
        } elseif ($ValidationMutation -ceq "missing_held_out_seal") {
            $value.PSObject.Properties.Remove("held_out_seal")
        } elseif (-not [string]::IsNullOrEmpty($ValidationMutation)) {
            throw "QSDK_R24D18_CONTRACT_VALIDATION_MUTATION_INVALID"
        }
        $selectorIsExact = (
            [string]$value.schema_version -ceq $Schema -and
            [string]$value.gate_id -ceq $ExpectedGateId -and
            [string]$value.campaign_id -ceq $ExpectedCampaignId -and
            [string]$value.question_class -ceq "development" -and
            [string]$value.selected_development_cell.cell_id -ceq
                $ExpectedCell -and
            [int64]$value.selected_development_cell.seed -eq
                $ExpectedCellSeed -and
            [int]$value.ghost_horizon.outer_steps_per_arm -eq
                $ExpectedOuterSteps -and
            [int]$value.ghost_horizon.paired_arm_count -eq
                $ExpectedArmCount -and
            [int]$value.held_out_seal.held_out_cell_access_count -eq 0 -and
            [int]$value.held_out_seal.held_out_selector_invocation_count -eq 0
        )
    } catch {
        throw (
            "QSDK_R24D18_CONTRACT_SELECTOR_INVALID:" +
            [string]$_.Exception.Message
        )
    }
    if (-not $selectorIsExact) {
        throw "QSDK_R24D18_CONTRACT_SELECTOR_INVALID"
    }
    return $value
}

if ($ContractValidationOnly) {
    if ($repoRoot -cne $expectedRepoRoot) {
        throw "QSDK_R24D18_REPOSITORY_ROOT_MISMATCH:$repoRoot"
    }
    if (-not (Test-Path -LiteralPath $contractPath -PathType Leaf)) {
        throw "QSDK_R24D18_CONTRACT_MISSING:$contractPath"
    }
    $validationContract = Read-ValidatedPhysicalContract `
        -Path $contractPath `
        -Schema $ContractSchema `
        -ExpectedGateId $GateId `
        -ExpectedCampaignId $CampaignId `
        -ExpectedCell $ExpectedCellId `
        -ExpectedCellSeed $ExpectedSeed `
        -ExpectedOuterSteps $ExpectedHorizonSteps `
        -ExpectedArmCount $ExpectedPairedArmCount `
        -ValidationMutation $ContractValidationMutation
    [ordered]@{
        schema_version =
            "sporespore_shared_physical_launcher_contract_validation_v1"
        ok = $true
        gate_id = $GateId
        campaign_id = $CampaignId
        contract_path = $ContractRelativePath
        contract_raw_sha256 = Get-RawSha256 $contractPath
        selected_cell_id = [string]$validationContract.selected_development_cell.cell_id
        selected_seed = [int64]$validationContract.selected_development_cell.seed
        horizon_steps_per_arm = [int]$validationContract.ghost_horizon.outer_steps_per_arm
        paired_arm_count = [int]$validationContract.ghost_horizon.paired_arm_count
        held_out_cell_access_count = 0
        held_out_selector_invocation_count = 0
        model_construction_count = 0
        world_attempt_count = 0
        world_build_count = 0
        solver_step_count = 0
        physics_state_modified = $false
        physical_question_opened = $false
    } | ConvertTo-Json -Depth 8 -Compress
    return
}
if (-not [string]::IsNullOrEmpty($ContractValidationMutation)) {
    throw "QSDK_R24D18_CONTRACT_VALIDATION_MUTATION_REQUIRES_VALIDATION_ONLY"
}

if ($repoRoot -cne $expectedRepoRoot) {
    throw "QSDK_R24D18_REPOSITORY_ROOT_MISMATCH:$repoRoot"
}
if ($evidenceRootFull -cne $expectedEvidenceRoot) {
    throw "QSDK_R24D18_EVIDENCE_ROOT_MISMATCH:$evidenceRootFull"
}
if (-not (Test-Path -LiteralPath $evidenceRootFull -PathType Container)) {
    throw "QSDK_R24D18_EVIDENCE_ROOT_MISSING:$evidenceRootFull"
}
if (-not (Test-Path -LiteralPath $pythonPath -PathType Leaf) -or
    -not (Test-Path -LiteralPath $coreLibraryPath -PathType Leaf)) {
    throw "QSDK_R24D18_RUNTIME_DEPENDENCY_MISSING"
}

$topLevelRaw = (& git -C $repoRoot rev-parse --show-toplevel).Trim()
Assert-NativeSuccess "show-toplevel"
$topLevel = [IO.Path]::GetFullPath($topLevelRaw)
$remote = (& git -C $repoRoot remote get-url origin).Trim()
Assert-NativeSuccess "remote"
$branch = (& git -C $repoRoot branch --show-current).Trim()
Assert-NativeSuccess "branch"
$status = @(& git -C $repoRoot status --porcelain=v1)
Assert-NativeSuccess "status"
$head = (& git -C $repoRoot rev-parse HEAD).Trim()
Assert-NativeSuccess "head"
$upstream = (& git -C $repoRoot rev-parse '@{upstream}').Trim()
Assert-NativeSuccess "upstream"
$remoteLine = (& git -C $repoRoot ls-remote origin refs/heads/main).Trim()
Assert-NativeSuccess "live-remote"
$remoteHead = ($remoteLine -split "\s+")[0]
if ($topLevel -cne $expectedRepoRoot -or $remote -cne $expectedRemote -or
    $branch -cne "main" -or $status.Count -ne 0 -or
    $head -cne $upstream -or $head -cne $remoteHead) {
    throw "QSDK_R24D18_SOURCE_NOT_CLEAN_PUSHED_EQUAL"
}

$contract = Read-ValidatedPhysicalContract `
    -Path $contractPath `
    -Schema $ContractSchema `
    -ExpectedGateId $GateId `
    -ExpectedCampaignId $CampaignId `
    -ExpectedCell $ExpectedCellId `
    -ExpectedCellSeed $ExpectedSeed `
    -ExpectedOuterSteps $ExpectedHorizonSteps `
    -ExpectedArmCount $ExpectedPairedArmCount
$contractRawSha256 = Get-RawSha256 $contractPath

if ([string]::IsNullOrWhiteSpace($QualificationReceiptPath)) {
    $matches = @(
        Get-ChildItem -LiteralPath $evidenceRootFull -Directory `
            -Filter "$QualificationDirectoryPrefix*" |
        ForEach-Object {
            $candidate = Join-Path $_.FullName "qualification_receipt.json"
            if (Test-Path -LiteralPath $candidate -PathType Leaf) {
                $receipt = Get-Content -Raw -LiteralPath $candidate |
                    ConvertFrom-Json
                if ([string]$receipt.schema_version -ceq
                        $QualificationReceiptSchema -and
                    [string]$receipt.gate_id -ceq $GateId -and
                    [string]$receipt.mode -ceq "qualification" -and
                    [bool]$receipt.ok -and
                    [string]$receipt.source_commit -ceq $head) {
                    $candidate
                }
            }
        }
    )
    if ($matches.Count -ne 1) {
        throw "QSDK_R24D18_EXACT_QUALIFICATION_RECEIPT_COUNT:$($matches.Count)"
    }
    $QualificationReceiptPath = $matches[0]
}
$qualificationFull = [IO.Path]::GetFullPath($QualificationReceiptPath)
$evidencePrefix = $evidenceRootFull.TrimEnd('\') + '\'
if (-not $qualificationFull.StartsWith(
        $evidencePrefix,
        [StringComparison]::OrdinalIgnoreCase
    ) -or -not (Test-Path -LiteralPath $qualificationFull -PathType Leaf)) {
    throw "QSDK_R24D18_QUALIFICATION_RECEIPT_OUTSIDE_EVIDENCE_ROOT"
}
$qualification = Get-Content -Raw -LiteralPath $qualificationFull |
    ConvertFrom-Json
$qualificationCoreBuildProfile = if (
    $null -ne $qualification.toolchain.PSObject.Properties["core_build_profile"]
) {
    [string]$qualification.toolchain.core_build_profile
} else {
    "debug"
}
if ([string]$qualification.schema_version -cne
        $QualificationReceiptSchema -or
    [string]$qualification.gate_id -cne $GateId -or
    [string]$qualification.mode -cne "qualification" -or
    -not [bool]$qualification.ok -or
    [string]$qualification.source_commit -cne $head -or
    [int]$qualification.model_construction_count -ne 0 -or
    [int]$qualification.world_attempt_count -ne 0 -or
    [int]$qualification.world_build_count -ne 0 -or
    [int]$qualification.solver_step_count -ne 0 -or
    [bool]$qualification.physics_state_modified -or
    $qualificationCoreBuildProfile -cne $CoreBuildProfile -or
    [string]$qualification.toolchain.core_library_raw_sha256 -cne
        (Get-RawSha256 $coreLibraryPath)) {
    throw "QSDK_R24D18_QUALIFICATION_RECEIPT_INVALID"
}
$qualificationRawSha256 = Get-RawSha256 $qualificationFull

$priorReservations = @(
    Get-ChildItem -LiteralPath $evidenceRootFull -Directory `
        -Filter "$PhysicalDirectoryPrefix*" |
    ForEach-Object {
        $reservationPath = Join-Path $_.FullName "attempt_reservation.json"
        if (Test-Path -LiteralPath $reservationPath -PathType Leaf) {
            Get-Content -Raw -LiteralPath $reservationPath | ConvertFrom-Json
        }
    } |
    Where-Object {
        [string]$_.campaign_id -ceq $CampaignId -and
        [string]$_.source_commit -ceq $head
    }
)
if ($priorReservations.Count -ne 0) {
    throw "QSDK_R24D18_EXACT_SOURCE_GHOST_ALREADY_RESERVED"
}

. $operationLockPath
$operationLockReceipt = $null
$operationLockPublic = $null
$evidenceDirectory = $null
$workerExitCode = -1
$workerStarted = $false
$workerStdoutPath = $null
$workerStderrPath = $null
$caughtError = $null
$previousPythonPath = $env:PYTHONPATH
try {
    $operationLockReceipt = Enter-SporeSporeLocomotionOperationLock -Role physical
    if (-not [bool]$operationLockReceipt.acquired -or
        [bool]$operationLockReceipt.test_only -or
        [bool]$operationLockReceipt.abandoned_owner_recovered) {
        throw "QSDK_R24D18_PHYSICAL_OPERATION_LOCK_REFUSED"
    }
    $operationLockPublic =
        Get-SporeSporeLocomotionOperationLockPublicReceipt $operationLockReceipt
    $timestamp = [DateTime]::UtcNow.ToString("yyyyMMddTHHmmssfffZ")
    $directoryName =
        "$PhysicalDirectoryPrefix$timestamp-$($head.Substring(0, 8))"
    $evidenceDirectory = Join-Path $evidenceRootFull $directoryName
    New-Item -ItemType Directory -Path $evidenceDirectory -ErrorAction Stop |
        Out-Null
    $operationLockReceiptPath = Join-Path $evidenceDirectory "operation_lock.json"
    Write-JsonExclusive $operationLockReceiptPath $operationLockPublic
    $reservation = [ordered]@{
        schema_version = $AttemptReservationSchema
        gate_id = $GateId
        campaign_id = $CampaignId
        reserved_utc = [DateTime]::UtcNow.ToString("o")
        question_class = "development"
        source_commit = $head
        branch = $branch
        remote = $remote
        contract_path = $contractPath
        contract_raw_sha256 = $contractRawSha256
        qualification_receipt_path = $qualificationFull
        qualification_receipt_raw_sha256 = $qualificationRawSha256
        selected_cell_id = $ExpectedCellId
        selected_seed = $ExpectedSeed
        horizon_steps_per_arm = $ExpectedHorizonSteps
        paired_arm_count = $ExpectedPairedArmCount
        core_build_profile = $CoreBuildProfile
        core_library_raw_sha256 = Get-RawSha256 $coreLibraryPath
        held_out_cell_access_count = 0
        held_out_selector_invocation_count = 0
        operation_lock_held = $true
        operation_lock = $operationLockPublic
        model_construction_count = 0
        world_attempt_count = 0
        world_build_count = 0
        solver_step_count = 0
        physics_state_modified = $false
        prone_to_standing_claimed = $false
        physical_acceptance_authority = $false
        release_authority = $false
    }
    Write-JsonExclusive `
        (Join-Path $evidenceDirectory "attempt_reservation.json") `
        $reservation
    $workerStdoutPath = Join-Path $evidenceDirectory "worker_stdout.log"
    $workerStderrPath = Join-Path $evidenceDirectory "worker_stderr.log"
    $env:PYTHONPATH =
        (Join-Path $repoRoot "sdk/python") + ";" +
        (Join-Path $repoRoot "sdk/adapters/mujoco")
    $workerArguments = @(
        "-m",
        $workerModule,
        "run",
        "--core-library",
        $coreLibraryPath,
        "--contract",
        $contractPath,
        "--output-directory",
        $evidenceDirectory,
        "--source-commit",
        $head,
        "--qualification-receipt",
        $qualificationFull,
        "--operation-lock-receipt",
        $operationLockReceiptPath
    )
    $workerStarted = $true
    $workerProcess = Start-Process `
        -FilePath $pythonPath `
        -ArgumentList $workerArguments `
        -NoNewWindow `
        -Wait `
        -PassThru `
        -RedirectStandardOutput $workerStdoutPath `
        -RedirectStandardError $workerStderrPath
    $workerExitCode = [int]$workerProcess.ExitCode
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

if ($null -ne $evidenceDirectory) {
    $completion = [ordered]@{
        schema_version = $SupervisorCompletionSchema
        gate_id = $GateId
        campaign_id = $CampaignId
        completed_utc = [DateTime]::UtcNow.ToString("o")
        source_commit = $head
        worker_started = $workerStarted
        worker_exit_code = $workerExitCode
        worker_stdout_path = $workerStdoutPath
        worker_stderr_path = $workerStderrPath
        route_coverage_passed = $workerExitCode -eq 0
        invalid_or_incomplete_retained = $workerExitCode -ne 0
        operation_lock_released =
            $null -ne $operationLockReceipt -and
            [bool]$operationLockReceipt.released
        caught_error = if ($null -eq $caughtError) {
            $null
        } else {
            [string]$caughtError.Exception.Message
        }
        held_out_cell_access_count = 0
        held_out_selector_invocation_count = 0
        prone_to_standing_claimed = $false
        physical_acceptance_authority = $false
        release_authority = $false
    }
    Write-JsonExclusive `
        (Join-Path $evidenceDirectory "supervisor_completion.json") `
        $completion
}
if ($null -ne $caughtError) {
    throw $caughtError
}
if ($workerExitCode -ne 0) {
    throw "QSDK_R24D18_GHOST_RETAINED_WITH_EXIT_CODE:$workerExitCode"
}
Write-Output (
    "$($GateId.Replace('-', '_'))_MUJOCO_RECOVERY_GHOST_PASS " +
    "evidence=$evidenceDirectory " +
    "source=$head heldout_access=0 prone_to_standing_claimed=False"
)
