#requires -Version 7.0

[CmdletBinding()]
param(
    [switch]$PreflightOnly,
    [switch]$RunPhysical,
    [string]$Godot = (
        "C:\Users\Cole\CodeStuff\Misc\Godot\" +
        "Godot_v4.7-stable_mono_win64_console.exe"
    ),
    [string]$LogRoot = (
        Join-Path $PSScriptRoot "target\bw28y-yaw-development-preflight"
    ),
    [string]$OutputRoot = "",
    [string]$FullConformanceAttestation = "",
    [int]$CellTimeoutSeconds = 300
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$sdkRoot = [System.IO.Path]::GetFullPath($PSScriptRoot)
$repoRoot = [System.IO.Path]::GetFullPath((Split-Path -Parent $sdkRoot))
$evidenceRoot = [System.IO.Path]::GetFullPath(
    (Join-Path (Split-Path -Parent $repoRoot) "SporeSpore_Evidence")
)
. (Join-Path $sdkRoot "locomotion_operation_lock.ps1")
. (Join-Path $sdkRoot "locomotion_full_conformance_attestation.ps1")
$campaignId = "BW28Y-FRESH-MATERIAL-YAW-DEVELOPMENT"
$gateId = "BW28Y"
$supervisorPath = Join-Path $sdkRoot "run_balanced_wave_bw28y_yaw_development.ps1"
$preregistrationPath = Join-Path (
    $sdkRoot
) "balanced_wave_bw28y_yaw_development_preregistration.json"
$candidatesPath = Join-Path (
    $sdkRoot
) "balanced_wave_bw28y_yaw_development_candidates.json"
$manifestPath = Join-Path (
    $sdkRoot
) "balanced_wave_bw28y_yaw_development_manifest.json"
$freezePath = Join-Path (
    $sdkRoot
) "balanced_wave_bw28y_yaw_development_freeze.json"
$productionGatePath = Join-Path (
    $sdkRoot
) "balanced_wave_bw28y_yaw_development_gate.ps1"
$declarationAuditPath = Join-Path (
    $repoRoot
) "tests\test_bw28y_yaw_development_declaration.ps1"
$receiptParityPath = Join-Path (
    $repoRoot
) "tests\test_bw28y_yaw_development_receipt_parity.ps1"
$authorityContractPath = Join-Path (
    $repoRoot
) "tests\test_sdk_balanced_wave_bw28y_authority_contract.gd"
$zeroWorldGatePath = Join-Path (
    $sdkRoot
) "run_balanced_wave_bw28y_yaw_development_zero_world_gate.ps1"
$actualReceiptPath = Join-Path (
    $repoRoot
) "tests\test_sdk_balanced_wave_bw28y_actual_receipt_path.gd"
$physicalHarnessPath = Join-Path (
    $repoRoot
) "tests\test_sdk_balanced_wave_bw28y_yaw_development.gd"
$bw25yClosurePath = Join-Path (
    $sdkRoot
) "balanced_wave_bw25y_yaw_development_closure.json"
$bw27pProfileClosurePath = Join-Path (
    $sdkRoot
) "balanced_wave_bw27p_material_profile_publication_closure.json"
$adapterArtifactPath = Join-Path $sdkRoot "target\debug\sporespore_godot_adapter.dll"
$closurePath = Join-Path (
    $sdkRoot
) "balanced_wave_bw28y_yaw_development_closure.json"
$expectedGodotVersion = "4.7.stable.mono.official.5b4e0cb0f"
$expectedGodotSha256 = "c5fc2d0bb24826a6757fa1e6bf2991effb294859c7dd03d09a122ef217484896"
$expectedGodotRuntimeSha256 = "baa909d0a905021da80cfc831713e9d3ba4bd0935ac3b93ba4c77dc140cfecc4"
$preflightPrefix = "BW28Y_YAW_DEVELOPMENT_PREFLIGHT "
$authorizationPreflightPrefix = (
    "BW28Y_YAW_DEVELOPMENT_AUTHORIZATION_PREFLIGHT "
)
$rawCellPrefix = "BW28Y_YAW_DEVELOPMENT_RAW_CELL "

function Assert-Exact {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function Get-RawSha256 {
    param([Parameter(Mandatory)][string]$Path)
    return (
        Get-FileHash -Algorithm SHA256 -LiteralPath $Path
    ).Hash.ToLowerInvariant()
}

function Write-Utf8NoBom {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][AllowEmptyString()][string]$Text
    )
    [System.IO.File]::WriteAllText(
        $Path,
        $Text,
        [System.Text.UTF8Encoding]::new($false)
    )
}

function Write-NewJsonArtifact {
    param(
        [Parameter(Mandatory)][object]$Value,
        [Parameter(Mandatory)][string]$Path
    )
    Assert-Exact (-not (Test-Path -LiteralPath $Path)) (
        "Refusing to overwrite a $gateId artifact: $Path"
    )
    [void][System.IO.Directory]::CreateDirectory((Split-Path -Parent $Path))
    $temporaryPath = $Path + ".tmp"
    Assert-Exact (-not (Test-Path -LiteralPath $temporaryPath)) (
        "Refusing stale $gateId temporary artifact: $temporaryPath"
    )
    Write-Utf8NoBom `
        -Path $temporaryPath `
        -Text (($Value | ConvertTo-Json -Depth 64) + [Environment]::NewLine)
    Move-Item -LiteralPath $temporaryPath -Destination $Path
}

function Test-ExactKeySet {
    param(
        [Parameter(Mandatory)][System.Collections.IDictionary]$Value,
        [Parameter(Mandatory)][string[]]$ExpectedKeys
    )
    $actual = @($Value.Keys | ForEach-Object { [string]$_ } | Sort-Object)
    $expected = @($ExpectedKeys | Sort-Object)
    return $actual.Count -eq $expected.Count -and
        (($actual -join "`n") -ceq ($expected -join "`n"))
}

function Get-Bw28yPrimaryWorldAttemptIds {
    return @($orderedCellIds | ForEach-Object { "BW28Y-P1::$_" })
}

function Get-Bw28yReplacementWorldAttemptIds {
    return @($orderedCellIds | ForEach-Object { "BW28Y-R1::$_" })
}

function Get-Bw28yReceiptDisposition {
    <#
    Decides only whether an identity-bound receipt structurally exists.  It
    intentionally accepts no walking, mechanism, application, or integrity
    outcome.  A complete negative observation is final; only an absent or
    structurally incomplete primary receipt may consume the declared R1 slot.
    #>
    param(
        [Parameter(Mandatory)]
        [ValidateSet("primary", "replacement")]
        [string]$AttemptKind,
        [Parameter(Mandatory)][bool]$TimedOut,
        [Parameter(Mandatory)][int]$ExitCode,
        [Parameter(Mandatory)][bool]$RawReceiptParsed,
        [Parameter(Mandatory)][bool]$RawIdentityExact,
        [Parameter(Mandatory)][bool]$RawReceiptStructurallyComplete,
        [Parameter(Mandatory)][bool]$CompositionSucceeded
    )

    $complete = (
        -not $TimedOut -and $ExitCode -eq 0 -and $RawReceiptParsed -and
        $RawIdentityExact -and $RawReceiptStructurallyComplete -and
        $CompositionSucceeded
    )
    $reason = if ($complete) {
        "complete_identity_bound_receipt"
    } elseif ($TimedOut) {
        "worker_timeout"
    } elseif (-not $RawReceiptParsed) {
        "raw_receipt_absent_or_malformed"
    } elseif (-not $RawIdentityExact) {
        "raw_receipt_identity_invalid"
    } elseif ($ExitCode -ne 0) {
        "worker_nonzero_exit_without_complete_contract"
    } elseif (-not $RawReceiptStructurallyComplete) {
        "worker_receipt_declared_structurally_incomplete"
    } else {
        "final_receipt_composition_failed"
    }
    $action = if ($complete) {
        "finalize_cell"
    } elseif ($AttemptKind -ceq "primary") {
        "run_declared_replacement"
    } else {
        "close_cell_incomplete_recovery_exhausted"
    }
    return [ordered]@{
        structural_receipt_complete = $complete
        recovery_action = $action
        recovery_reason = $reason
        replacement_eligible = (
            -not $complete -and $AttemptKind -ceq "primary"
        )
        locomotion_outcome_consulted = $false
        mechanism_outcome_consulted = $false
        integrity_outcome_consulted = $false
    }
}

function New-Bw28yAttemptRecord {
    param(
        [Parameter(Mandatory)][bool]$Synthetic,
        [Parameter(Mandatory)][string]$AttemptId,
        [Parameter(Mandatory)][string]$AuthorizationToken,
        [string]$SourceCommit = "",
        [string]$GodotVersion = $expectedGodotVersion,
        [string]$GodotSha256 = $expectedGodotSha256,
        [string]$GodotRuntimeSha256 = $expectedGodotRuntimeSha256,
        [string]$AdapterArtifactSha256 = "",
        [string]$AttestationPath = "",
        [string]$AttestationSha256 = ""
    )
    $resolvedSource = if ($Synthetic) {
        "synthetic_preflight_no_source_identity"
    } else { $SourceCommit }
    $resolvedAdapter = if ([string]::IsNullOrWhiteSpace($AdapterArtifactSha256)) {
        Get-RawSha256 -Path $adapterArtifactPath
    } else { $AdapterArtifactSha256 }
    return [ordered]@{
        schema_version =
            "sporespore_balanced_wave_bw28y_yaw_development_attempt_v1"
        campaign_id = $campaignId
        gate_id = $gateId
        synthetic_contract_preflight = $Synthetic
        attempt_id = $AttemptId
        launched_at_utc = [DateTime]::UtcNow.ToString("o")
        source_commit = $resolvedSource
        origin_main_commit = if ($Synthetic) { "" } else { $SourceCommit }
        remote_main_commit = if ($Synthetic) { "" } else { $SourceCommit }
        source_worktree_clean = -not $Synthetic
        source_matches_live_github_main = -not $Synthetic
        godot_version = $GodotVersion
        godot_executable_sha256 = $GodotSha256
        godot_runtime_executable_sha256 = $GodotRuntimeSha256
        godot_adapter_artifact_sha256 = $resolvedAdapter
        preregistration_raw_sha256 = Get-RawSha256 -Path $preregistrationPath
        candidates_raw_sha256 = Get-RawSha256 -Path $candidatesPath
        manifest_raw_sha256 = Get-RawSha256 -Path $manifestPath
        declaration_audit_raw_sha256 = Get-RawSha256 -Path $declarationAuditPath
        evaluator_raw_sha256 = Get-RawSha256 -Path $productionGatePath
        physical_worker_raw_sha256 = Get-RawSha256 -Path $physicalHarnessPath
        physical_supervisor_raw_sha256 = Get-RawSha256 -Path $supervisorPath
        actual_receipt_path_raw_sha256 = Get-RawSha256 -Path $actualReceiptPath
        zero_world_gate_raw_sha256 = Get-RawSha256 -Path $zeroWorldGatePath
        stage_one_freeze_raw_sha256 = Get-RawSha256 -Path $freezePath
        full_godot_v2_attestation_path = if ($Synthetic) {
            "synthetic_preflight_no_attestation"
        } else { $AttestationPath }
        full_godot_v2_attestation_sha256 = if ($Synthetic) {
            "0" * 64
        } else { $AttestationSha256 }
        complete_zero_world_gate_passed = $true
        declaration_audit_passed = $true
        actual_receipt_path_preflight_passed = $true
        production_composer_evaluator_preflight_passed = $true
        worker_entrypoint_preflight_passed = $true
        attempt_contract_preflight_passed = $true
        stage_one_freeze_verified = $true
        expected_gate_count = 50
        expected_world_count = 28
        expected_adapter_start_count = 27
        ordered_cell_ids = @($orderedCellIds)
        primary_world_attempt_ids = @(Get-Bw28yPrimaryWorldAttemptIds)
        replacement_world_attempt_ids = @(Get-Bw28yReplacementWorldAttemptIds)
        replacement_budget_per_incomplete_cell = 1
        authorization_token = $AuthorizationToken
        physical_identity_consumed = -not $Synthetic
        same_identity_rerun_allowed = $false
        locomotion_outcome_exposed_at_attempt = $false
        physical_acceptance_authority = $false
        retained_physical_execution_serialized = $true
    }
}

function Test-Bw28yAttemptRecord {
    param(
        [Parameter(Mandatory)][System.Collections.IDictionary]$Attempt,
        [Parameter(Mandatory)][bool]$Synthetic
    )
    $expectedKeys = @(
        "schema_version", "campaign_id", "gate_id",
        "synthetic_contract_preflight", "attempt_id", "launched_at_utc",
        "source_commit", "origin_main_commit", "remote_main_commit",
        "source_worktree_clean", "source_matches_live_github_main",
        "godot_version", "godot_executable_sha256",
        "godot_runtime_executable_sha256", "godot_adapter_artifact_sha256",
        "preregistration_raw_sha256", "candidates_raw_sha256", "manifest_raw_sha256",
        "declaration_audit_raw_sha256",
        "evaluator_raw_sha256", "physical_worker_raw_sha256",
        "physical_supervisor_raw_sha256", "actual_receipt_path_raw_sha256",
        "zero_world_gate_raw_sha256", "stage_one_freeze_raw_sha256",
        "full_godot_v2_attestation_path", "full_godot_v2_attestation_sha256",
        "complete_zero_world_gate_passed", "declaration_audit_passed",
        "actual_receipt_path_preflight_passed",
        "production_composer_evaluator_preflight_passed",
        "worker_entrypoint_preflight_passed",
        "attempt_contract_preflight_passed", "stage_one_freeze_verified",
        "expected_gate_count", "expected_world_count",
        "expected_adapter_start_count", "ordered_cell_ids",
        "primary_world_attempt_ids", "replacement_world_attempt_ids",
        "replacement_budget_per_incomplete_cell", "authorization_token",
        "physical_identity_consumed", "same_identity_rerun_allowed",
        "locomotion_outcome_exposed_at_attempt", "physical_acceptance_authority",
        "retained_physical_execution_serialized"
    )
    if (-not (Test-ExactKeySet -Value $Attempt -ExpectedKeys $expectedKeys)) {
        return $false
    }
    $sourceExact = if ($Synthetic) {
        [string]$Attempt.source_commit -ceq
            "synthetic_preflight_no_source_identity" -and
        [string]::IsNullOrEmpty([string]$Attempt.origin_main_commit) -and
        [string]::IsNullOrEmpty([string]$Attempt.remote_main_commit) -and
        -not [bool]$Attempt.source_worktree_clean -and
        -not [bool]$Attempt.source_matches_live_github_main
    } else {
        [string]$Attempt.source_commit -cmatch "^[0-9a-f]{40}$" -and
        [string]$Attempt.origin_main_commit -ceq [string]$Attempt.source_commit -and
        [string]$Attempt.remote_main_commit -ceq [string]$Attempt.source_commit -and
        [bool]$Attempt.source_worktree_clean -and
        [bool]$Attempt.source_matches_live_github_main
    }
    $attestationExact = if ($Synthetic) {
        [string]$Attempt.full_godot_v2_attestation_path -ceq
            "synthetic_preflight_no_attestation" -and
        [string]$Attempt.full_godot_v2_attestation_sha256 -ceq ("0" * 64)
    } else {
        -not [string]::IsNullOrWhiteSpace(
            [string]$Attempt.full_godot_v2_attestation_path
        ) -and
        (Test-Path -LiteralPath (
            [string]$Attempt.full_godot_v2_attestation_path
        ) -PathType Leaf) -and
        [string]$Attempt.full_godot_v2_attestation_sha256 -ceq
            (Get-RawSha256 -Path (
                [string]$Attempt.full_godot_v2_attestation_path
            ))
    }
    return (
        [string]$Attempt.schema_version -ceq
            "sporespore_balanced_wave_bw28y_yaw_development_attempt_v1" -and
        [string]$Attempt.campaign_id -ceq $campaignId -and
        [string]$Attempt.gate_id -ceq $gateId -and
        [bool]$Attempt.synthetic_contract_preflight -eq $Synthetic -and
        [string]$Attempt.attempt_id -cmatch "^[0-9a-f]{32}$" -and
        [string]$Attempt.authorization_token -cmatch "^[0-9a-f]{32}$" -and
        -not [string]::IsNullOrWhiteSpace([string]$Attempt.launched_at_utc) -and
        $sourceExact -and
        [string]$Attempt.godot_version -ceq $expectedGodotVersion -and
        [string]$Attempt.godot_executable_sha256 -ceq $expectedGodotSha256 -and
        [string]$Attempt.godot_runtime_executable_sha256 -ceq
            $expectedGodotRuntimeSha256 -and
        [string]$Attempt.godot_adapter_artifact_sha256 -ceq
            (Get-RawSha256 -Path $adapterArtifactPath) -and
        [string]$Attempt.preregistration_raw_sha256 -ceq
            (Get-RawSha256 -Path $preregistrationPath) -and
        [string]$Attempt.candidates_raw_sha256 -ceq
            (Get-RawSha256 -Path $candidatesPath) -and
        [string]$Attempt.manifest_raw_sha256 -ceq
            (Get-RawSha256 -Path $manifestPath) -and
        [string]$Attempt.declaration_audit_raw_sha256 -ceq
            (Get-RawSha256 -Path $declarationAuditPath) -and
        [string]$Attempt.evaluator_raw_sha256 -ceq
            (Get-RawSha256 -Path $productionGatePath) -and
        [string]$Attempt.physical_worker_raw_sha256 -ceq
            (Get-RawSha256 -Path $physicalHarnessPath) -and
        [string]$Attempt.physical_supervisor_raw_sha256 -ceq
            (Get-RawSha256 -Path $supervisorPath) -and
        [string]$Attempt.actual_receipt_path_raw_sha256 -ceq
            (Get-RawSha256 -Path $actualReceiptPath) -and
        [string]$Attempt.zero_world_gate_raw_sha256 -ceq
            (Get-RawSha256 -Path $zeroWorldGatePath) -and
        [string]$Attempt.stage_one_freeze_raw_sha256 -ceq
            (Get-RawSha256 -Path $freezePath) -and
        $attestationExact -and
        [bool]$Attempt.complete_zero_world_gate_passed -and
        [bool]$Attempt.declaration_audit_passed -and
        [bool]$Attempt.actual_receipt_path_preflight_passed -and
        [bool]$Attempt.production_composer_evaluator_preflight_passed -and
        [bool]$Attempt.worker_entrypoint_preflight_passed -and
        [bool]$Attempt.attempt_contract_preflight_passed -and
        [bool]$Attempt.stage_one_freeze_verified -and
        [int]$Attempt.expected_gate_count -eq 50 -and
        [int]$Attempt.expected_world_count -eq 28 -and
        [int]$Attempt.expected_adapter_start_count -eq 27 -and
        (@($Attempt.ordered_cell_ids) -join "`n") -ceq
            (@($orderedCellIds) -join "`n") -and
        (@($Attempt.primary_world_attempt_ids) -join "`n") -ceq
            (@(Get-Bw28yPrimaryWorldAttemptIds) -join "`n") -and
        (@($Attempt.replacement_world_attempt_ids) -join "`n") -ceq
            (@(Get-Bw28yReplacementWorldAttemptIds) -join "`n") -and
        [int]$Attempt.replacement_budget_per_incomplete_cell -eq 1 -and
        [bool]$Attempt.physical_identity_consumed -eq (-not $Synthetic) -and
        -not [bool]$Attempt.same_identity_rerun_allowed -and
        -not [bool]$Attempt.locomotion_outcome_exposed_at_attempt -and
        -not [bool]$Attempt.physical_acceptance_authority -and
        [bool]$Attempt.retained_physical_execution_serialized
    )
}

function Get-ReceiptFromOutput {
    param(
        [Parameter(Mandatory)][string]$OutputText,
        [Parameter(Mandatory)][string]$Prefix
    )
    $lines = @(
        $OutputText -split "\r?\n" |
            Where-Object { $_.StartsWith($Prefix) }
    )
    if ($lines.Count -ne 1) {
        throw "Expected one '$Prefix' receipt, found $($lines.Count)"
    }
    return (
        $lines[0].Substring($Prefix.Length) |
            ConvertFrom-Json -AsHashtable
    )
}

function Copy-Bw28yValue {
    param([Parameter(Mandatory)][object]$Value)
    return $Value | ConvertTo-Json -Depth 64 |
        ConvertFrom-Json -AsHashtable -Depth 64
}

function Invoke-GodotCaptured {
    param(
        [Parameter(Mandatory)][string[]]$Arguments,
        [Parameter(Mandatory)][string]$WorkerRoot,
        [Parameter(Mandatory)][int]$TimeoutSeconds,
        [string]$AttemptPath = "",
        [string]$AuthorizationToken = "",
        [string]$CellId = "",
        [string]$WorldAttemptId = "",
        [string]$CampaignAttemptId = ""
    )
    $appData = Join-Path $WorkerRoot "appdata"
    $localAppData = Join-Path $WorkerRoot "localappdata"
    [void][System.IO.Directory]::CreateDirectory($appData)
    [void][System.IO.Directory]::CreateDirectory($localAppData)
    $start = [System.Diagnostics.ProcessStartInfo]::new()
    $start.FileName = $godotPath
    $start.WorkingDirectory = $repoRoot
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    $start.Environment["APPDATA"] = $appData
    $start.Environment["LOCALAPPDATA"] = $localAppData
    foreach ($name in @(
        "SPORESPORE_BW28Y_ATTEMPT", "SPORESPORE_BW28Y_TOKEN",
        "SPORESPORE_BW28Y_CELL", "SPORESPORE_BW28Y_WORLD_ATTEMPT_ID",
        "SPORESPORE_BW28Y_CAMPAIGN_ATTEMPT_ID"
    )) {
        [void]$start.Environment.Remove($name)
    }
    if (-not [string]::IsNullOrWhiteSpace($AttemptPath)) {
        $start.Environment["SPORESPORE_BW28Y_ATTEMPT"] = $AttemptPath
        $start.Environment["SPORESPORE_BW28Y_TOKEN"] = $AuthorizationToken
        $start.Environment["SPORESPORE_BW28Y_CELL"] = $CellId
        $start.Environment["SPORESPORE_BW28Y_WORLD_ATTEMPT_ID"] = $WorldAttemptId
        $start.Environment["SPORESPORE_BW28Y_CAMPAIGN_ATTEMPT_ID"] =
            $CampaignAttemptId
    }
    foreach ($argument in $Arguments) {
        [void]$start.ArgumentList.Add($argument)
    }
    $process = [System.Diagnostics.Process]::new()
    $process.StartInfo = $start
    $startedUtc = [DateTime]::UtcNow
    Assert-Exact ($process.Start()) "Failed to start isolated Godot"
    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()
    $timedOut = -not $process.WaitForExit($TimeoutSeconds * 1000)
    $killedTree = $false
    if ($timedOut) {
        try {
            $process.Kill($true)
            $killedTree = $true
        } catch {
            $killedTree = $false
        }
        [void]$process.WaitForExit(10000)
    }
    $stdout = $stdoutTask.GetAwaiter().GetResult()
    $stderr = $stderrTask.GetAwaiter().GetResult()
    $exitCode = if ($process.HasExited) { $process.ExitCode } else { -1 }
    $durationSeconds = ([DateTime]::UtcNow - $startedUtc).TotalSeconds
    $process.Dispose()
    return [ordered]@{
        exit_code = $exitCode
        timed_out = $timedOut
        killed_process_tree = $killedTree
        duration_seconds = $durationSeconds
        stdout = $stdout
        stderr = $stderr
    }
}

function Assert-NoPriorAttempt {
    $priorAttempts = @()
    if (Test-Path -LiteralPath $evidenceRoot -PathType Container) {
        $priorAttempts = @(
            Get-ChildItem `
                -LiteralPath $evidenceRoot `
                -Recurse `
                -File `
                -Filter "attempt.json" |
            Where-Object {
                try {
                    $attempt = Get-Content -Raw -LiteralPath $_.FullName |
                        ConvertFrom-Json
                    [string]$attempt.campaign_id -ceq $campaignId
                } catch {
                    $false
                }
            }
        )
    }
    Assert-Exact ($priorAttempts.Count -eq 0) (
        "$gateId prior physical attempt exists; this identity may not rerun"
    )
}

Assert-Exact (
    [bool]$PreflightOnly -xor [bool]$RunPhysical
) "Specify exactly one of -PreflightOnly or -RunPhysical"
Assert-Exact (
    $CellTimeoutSeconds -ge 30 -and $CellTimeoutSeconds -le 900
) "$gateId CellTimeoutSeconds must be in [30,900]"
if ($RunPhysical) {
    Assert-Exact (-not [string]::IsNullOrWhiteSpace($OutputRoot)) (
        "$gateId -RunPhysical requires an explicit durable OutputRoot"
    )
    Assert-Exact (-not (Test-Path -LiteralPath $closurePath -PathType Leaf)) (
        "$gateId campaign is already closed and may not rerun"
    )
    Assert-Exact (-not [string]::IsNullOrWhiteSpace($FullConformanceAttestation)) (
        "$gateId -RunPhysical requires an exact full-Godot V2 attestation"
    )
}

$operationLockReceipt = $null
if ($RunPhysical) {
    $operationLockReceipt = Enter-SporeSporeLocomotionOperationLock `
        -Role physical `
        -TimeoutMilliseconds 0
    Assert-Exact ([bool]$operationLockReceipt.acquired) (
        "$gateId another conformance or physical operation owns the shared lock"
    )
}

try {

Assert-Exact (
    Test-Path -LiteralPath $freezePath -PathType Leaf
) "$gateId distinct stage-one freeze is missing"
$freeze = Get-Content -Raw -LiteralPath $freezePath |
    ConvertFrom-Json -AsHashtable
$freezeStudy = $freeze.study_class
$freezeMatrix = $freeze.physical_matrix
$freezeGate = $freeze.gate_contract
$freezePreflight = $freeze.zero_world_authorization_preflight
$freezeExecution = $freeze.one_shot_execution_contract
$freezeClaims = $freeze.claims_before_physical_execution
$sourceBindings = $freeze.source_bindings
Assert-Exact (
    [string]$freeze.schema_version -ceq
        "sporespore_balanced_wave_bw28y_yaw_development_freeze_v1" -and
    [string]$freeze.status -ceq
        "frozen_before_first_bw28y_physical_world" -and
    [string]$freeze.campaign_id -ceq $campaignId -and
    [string]$freeze.gate_id -ceq $gateId -and
    [string]$freeze.freeze_parent_commit -ceq
        "96835e39a68f4c0ae4931338a44d7c72008c8c9a" -and
    [string]$freezeStudy.classification -ceq
        "paired_outcome_unexposed_finite_controller_development_screen" -and
    [int]$freezeMatrix.expected_world_count -eq 28 -and
    [int]$freezeMatrix.candidate_world_count -eq 24 -and
    [int]$freezeMatrix.control_world_count -eq 3 -and
    [int]$freezeMatrix.safety_world_count -eq 1 -and
    [int]$freezeGate.expected_gate_count -eq 50 -and
    [int]$freezeGate.pre_matrix_gate_count -eq 4 -and
    [int]$freezeGate.per_world_gate_count -eq 28 -and
    [int]$freezeGate.aggregate_gate_count -eq 18
) "$gateId stage-one freeze identity, study class, matrix, or gate changed"
Assert-Exact (
    [int]$freezePreflight.production_evaluator_negative_canary_count -eq 19 -and
    [int]$freezePreflight.candidate_authority_check_count -eq 13 -and
    [int]$freezePreflight.worker_entrypoint_count -eq 28 -and
    [int]$freezePreflight.adapter_start_count -eq 27 -and
    [int]$freezePreflight.real_shaped_receipt_count -eq 28 -and
    [int]$freezePreflight.receipt_composition_defect_canary_count -eq 5 -and
    [int]$freezePreflight.attempt_record_canary_count -eq 16 -and
    [int]$freezePreflight.authorization_and_bypass_canary_count -eq 5 -and
    [int]$freezePreflight.world_build_count -eq 0 -and
    [int]$freezePreflight.scene_tree_insertion_count -eq 0 -and
    [int]$freezePreflight.physics_state_mutation_count -eq 0 -and
    -not [bool]$freezePreflight.locomotion_outcome_exposed -and
    -not [bool]$freezePreflight.physical_acceptance_authority -and
    [bool]$freezeExecution.only_complete_supervisor_may_open_physical_worlds -and
    [bool]$freezeExecution.worker_requires_exact_retained_attempt_and_matching_authorization_token -and
    [bool]$freezeExecution.output_root_must_be_new_durable_and_inside_sporespore_evidence -and
    [bool]$freezeExecution.head_must_equal_origin_main_and_live_github_main -and
    [bool]$freezeExecution.worktree_must_be_clean -and
    [bool]$freezeExecution.prior_attempt_count_must_be_zero -and
    [bool]$freezeExecution.attempt_receipt_written_and_identity_consumed_before_first_world -and
    [bool]$freezeExecution.all_twenty_eight_cells_attempted_even_after_cell_failure -and
    [bool]$freezeExecution.valid_negative_cell_is_final_and_does_not_fail_process -and
    [bool]$freezeExecution.one_automatic_replacement_only_for_incomplete_receipt -and
    [bool]$freezeExecution.replacement_never_depends_on_locomotion_outcome -and
    [bool]$freezeExecution.first_complete_result_final_for_source_identity -and
    -not [bool]$freezeExecution.same_identity_rerun_allowed
) "$gateId zero-world or one-shot freeze contract changed"
foreach ($claimName in @($freezeClaims.Keys)) {
    Assert-Exact (-not [bool]$freezeClaims[$claimName]) (
        "$gateId prephysical freeze claim inflated: $claimName"
    )
}
Assert-Exact (
    $sourceBindings.Count -ge 25 -and
    [string]$sourceBindings.supervisor.path -ceq
        "sdk/run_balanced_wave_bw28y_yaw_development.ps1" -and
    [string]$sourceBindings.physical_harness.path -ceq
        "tests/test_sdk_balanced_wave_bw28y_yaw_development.gd" -and
    [string]$sourceBindings.receipt_parity_preflight.path -ceq
        "tests/test_bw28y_yaw_development_receipt_parity.ps1" -and
    [string]$sourceBindings.candidate_authority_contract.path -ceq
        "tests/test_sdk_balanced_wave_bw28y_authority_contract.gd"
) "$gateId stage-one source-binding surface changed"
foreach ($binding in $sourceBindings.GetEnumerator()) {
    $relativePath = [string]$binding.Value.path
    $expectedSha256 = [string]$binding.Value.raw_sha256
    $absolutePath = Join-Path $repoRoot $relativePath
    Assert-Exact (
        $expectedSha256 -cmatch "^[0-9a-f]{64}$" -and
        (Test-Path -LiteralPath $absolutePath -PathType Leaf) -and
        (Get-RawSha256 -Path $absolutePath) -ceq $expectedSha256
    ) "$gateId frozen source is missing or changed: $relativePath"
}

$preregistration = Get-Content -Raw -LiteralPath $preregistrationPath |
    ConvertFrom-Json -AsHashtable
$manifest = Get-Content -Raw -LiteralPath $manifestPath |
    ConvertFrom-Json -AsHashtable
$cells = @($manifest.ordered_cells)
$orderedCellIds = @($cells | ForEach-Object { [string]$_.cell_id })
Assert-Exact (
    [string]$preregistration.schema_version -ceq
        "sporespore_balanced_wave_bw28y_yaw_development_preregistration_v1" -and
    [string]$preregistration.status -ceq
        "prospective_stage_zero_zero_world_only_physical_execution_blocked" -and
    [string]$preregistration.campaign_id -ceq $campaignId -and
    [string]$preregistration.gate_id -ceq $gateId -and
    [string]$manifest.schema_version -ceq
        "sporespore_balanced_wave_bw28y_yaw_development_manifest_v1" -and
    [string]$manifest.status -ceq
        "prospective_zero_world_manifest_physical_execution_blocked" -and
    -not [bool]$manifest.physical_execution_authorized -and
    $cells.Count -eq 28 -and
    @($cells | Where-Object role -CEQ "candidate").Count -eq 24 -and
    @($cells | Where-Object role -CEQ "control").Count -eq 3 -and
    @($cells | Where-Object role -CEQ "safety").Count -eq 1
) "$gateId frozen manifest identity or matrix changed"

if ($RunPhysical) {
    Assert-NoPriorAttempt
}

& pwsh -NoProfile -File $declarationAuditPath
Assert-Exact ($LASTEXITCODE -eq 0) (
    "$gateId stage-zero declaration audit failed"
)

$godotPath = [System.IO.Path]::GetFullPath($Godot)
Assert-Exact (
    (Test-Path -LiteralPath $godotPath -PathType Leaf) -and
    (Get-RawSha256 -Path $godotPath) -ceq
        $expectedGodotSha256
) "$gateId pinned Godot executable changed"
$godotRuntimePath = $godotPath.Replace("_console.exe", ".exe")
Assert-Exact (
    (Test-Path -LiteralPath $godotRuntimePath -PathType Leaf) -and
    (Get-RawSha256 -Path $godotRuntimePath) -ceq $expectedGodotRuntimeSha256
) "$gateId pinned Godot runtime executable changed"
$godotVersion = (& $godotPath --version).Trim()
Assert-Exact (
    $LASTEXITCODE -eq 0 -and $godotVersion -ceq $expectedGodotVersion
) "$gateId pinned Godot version changed"

& cargo build `
    --manifest-path (Join-Path $sdkRoot "Cargo.toml") `
    -p sporespore-godot-adapter `
    --offline
Assert-Exact ($LASTEXITCODE -eq 0) "$gateId Godot adapter build failed"

$preflightBaseRoot = [System.IO.Path]::GetFullPath($LogRoot)
$preflightRoot = Join-Path $preflightBaseRoot (
    [DateTime]::UtcNow.ToString("yyyyMMddTHHmmssfff") + "-" +
    [Guid]::NewGuid().ToString("N").Substring(0, 8)
)
[void][System.IO.Directory]::CreateDirectory($preflightRoot)
$zeroWorldGateOutput = (& pwsh `
    -NoLogo `
    -NoProfile `
    -File $zeroWorldGatePath `
    -Godot $godotPath 2>&1 | Out-String)
Write-Host $zeroWorldGateOutput.TrimEnd()
Assert-Exact (
    $LASTEXITCODE -eq 0 -and
    $zeroWorldGateOutput.Contains(
        "BW28Y_ZERO_WORLD_GATE_PASS gates=50 neutral_selection=NONE " +
        "constructors=28 composers=28 canaries=19 " +
        "actual_path_identity_veto=True selection_authority_veto=True " +
        "worlds=0",
        [StringComparison]::Ordinal
    )
) "$gateId complete actual-path production zero-world gate failed"

$receiptParityOutput = (& pwsh `
    -NoLogo `
    -NoProfile `
    -File $receiptParityPath 2>&1 | Out-String)
Write-Host $receiptParityOutput.TrimEnd()
Assert-Exact (
    $LASTEXITCODE -eq 0 -and
    $receiptParityOutput.Contains(
        "BW28Y_RECEIPT_PARITY_PASS raw_cells=28 composed_cells=28 " +
        "decision_keys=4 defect_canaries=5",
        [StringComparison]::Ordinal
    )
) "$gateId real-shaped receipt-composition parity preflight failed"

$authority = Invoke-GodotCaptured `
    -Arguments @(
        "--headless", "--path", $repoRoot,
        "--script", "res://tests/test_sdk_balanced_wave_bw28y_authority_contract.gd"
    ) `
    -WorkerRoot (Join-Path $preflightRoot "authority") `
    -TimeoutSeconds 120
Assert-Exact (
    -not [bool]$authority.timed_out -and
    [int]$authority.exit_code -eq 0 -and
    ([string]$authority.stdout).Contains(
        "BW28Y_AUTHORITY_PASS candidates=2 materials=3 routes=6 worlds=0",
        [StringComparison]::Ordinal
    )
) "$gateId zero-world native candidate/material authority contract failed"

$entrypoint = Invoke-GodotCaptured `
    -Arguments @(
        "--headless", "--path", $repoRoot,
        "--script", "res://tests/test_sdk_balanced_wave_bw28y_yaw_development.gd",
        "--", "preflight"
    ) `
    -WorkerRoot (Join-Path $preflightRoot "entrypoint") `
    -TimeoutSeconds 180
Assert-Exact (
    -not [bool]$entrypoint.timed_out -and [int]$entrypoint.exit_code -eq 0
) "$gateId real worker entrypoint preflight failed"
$entrypointReceipt = Get-ReceiptFromOutput `
    -OutputText ([string]$entrypoint.stdout) `
    -Prefix $preflightPrefix
Assert-Exact (
    [bool]$entrypointReceipt.ok -and
    [int]$entrypointReceipt.entrypoint_count -eq 28 -and
    [int]$entrypointReceipt.candidate_entrypoint_count -eq 24 -and
    [int]$entrypointReceipt.control_entrypoint_count -eq 3 -and
    [int]$entrypointReceipt.safety_entrypoint_count -eq 1 -and
    [int]$entrypointReceipt.adapter_start_count -eq 27 -and
    [int]$entrypointReceipt.actual_world_build_count -eq 0 -and
    [int]$entrypointReceipt.scene_tree_insertion_count -eq 0 -and
    -not [bool]$entrypointReceipt.physics_state_modified -and
    -not [bool]$entrypointReceipt.locomotion_outcome_exposed -and
    -not [bool]$entrypointReceipt.physical_acceptance_authority -and
    (@($entrypointReceipt.cell_ids) -join "|") -ceq ($orderedCellIds -join "|")
) "$gateId complete 28-cell no-world entrypoint receipt changed"

$authorizationToken = [Guid]::NewGuid().ToString("N")
$campaignAttemptId = [Guid]::NewGuid().ToString("N")
$authorizationCellId = [string]$orderedCellIds[0]
$authorizationWorldAttemptId = [string](Get-Bw28yPrimaryWorldAttemptIds)[0]
$authorizationAttemptPath = Join-Path (
    $preflightRoot
) ("authorization-attempt-" + $campaignAttemptId + ".json")
$authorizationAttempt = New-Bw28yAttemptRecord `
    -Synthetic $true `
    -AttemptId $campaignAttemptId `
    -AuthorizationToken $authorizationToken
Assert-Exact (
    Test-Bw28yAttemptRecord -Attempt $authorizationAttempt -Synthetic $true
) "$gateId shared synthetic attempt constructor did not satisfy its parser"
Write-NewJsonArtifact -Value $authorizationAttempt -Path $authorizationAttemptPath
$authorizationRoundTrip = Get-Content -Raw -LiteralPath $authorizationAttemptPath |
    ConvertFrom-Json -AsHashtable -Depth 64
Assert-Exact (
    Test-Bw28yAttemptRecord -Attempt $authorizationRoundTrip -Synthetic $true
) "$gateId serialized synthetic attempt did not satisfy the shared parser"

$attemptMutations = @(
    [ordered]@{ name = "schema"; apply = { param($v) $v.schema_version = "wrong" } },
    [ordered]@{ name = "campaign"; apply = { param($v) $v.campaign_id = "wrong" } },
    [ordered]@{ name = "synthetic_flag"; apply = { param($v) $v.synthetic_contract_preflight = $false } },
    [ordered]@{ name = "adapter_hash"; apply = { param($v) $v.godot_adapter_artifact_sha256 = "0" * 64 } },
    [ordered]@{ name = "preregistration_hash"; apply = { param($v) $v.preregistration_raw_sha256 = "0" * 64 } },
    [ordered]@{ name = "manifest_hash"; apply = { param($v) $v.manifest_raw_sha256 = "0" * 64 } },
    [ordered]@{ name = "zero_world_gate_hash"; apply = { param($v) $v.zero_world_gate_raw_sha256 = "0" * 64 } },
    [ordered]@{ name = "attestation_hash"; apply = { param($v) $v.full_godot_v2_attestation_sha256 = "1" * 64 } },
    [ordered]@{ name = "actual_path_preflight"; apply = { param($v) $v.actual_receipt_path_preflight_passed = $false } },
    [ordered]@{ name = "gate_count"; apply = { param($v) $v.expected_gate_count = 49 } },
    [ordered]@{ name = "cell_order"; apply = { param($v) $v.ordered_cell_ids[0] = "wrong" } },
    [ordered]@{ name = "primary_ids"; apply = { param($v) $v.primary_world_attempt_ids[0] = "wrong" } },
    [ordered]@{ name = "replacement_ids"; apply = { param($v) $v.replacement_world_attempt_ids[0] = "wrong" } },
    [ordered]@{ name = "authorization_token"; apply = { param($v) $v.authorization_token = "not-a-token" } },
    [ordered]@{ name = "identity_consumed"; apply = { param($v) $v.physical_identity_consumed = $true } },
    [ordered]@{ name = "outcome_exposure"; apply = { param($v) $v.locomotion_outcome_exposed_at_attempt = $true } }
)
foreach ($mutation in $attemptMutations) {
    $mutatedAttempt = Copy-Bw28yValue $authorizationRoundTrip
    & $mutation.apply $mutatedAttempt
    Assert-Exact (
        -not (Test-Bw28yAttemptRecord -Attempt $mutatedAttempt -Synthetic $true)
    ) "$gateId attempt parser accepted mutation: $($mutation.name)"
}

$authorization = Invoke-GodotCaptured `
    -Arguments @(
        "--headless", "--path", $repoRoot,
        "--script", "res://tests/test_sdk_balanced_wave_bw28y_yaw_development.gd",
        "--", "authorization_preflight", $authorizationCellId
    ) `
    -WorkerRoot (Join-Path $preflightRoot "authorization-valid") `
    -TimeoutSeconds 60 `
    -AttemptPath $authorizationAttemptPath `
    -AuthorizationToken $authorizationToken `
    -CellId $authorizationCellId `
    -WorldAttemptId $authorizationWorldAttemptId `
    -CampaignAttemptId $campaignAttemptId
$authorizationReceipt = Get-ReceiptFromOutput `
    -OutputText ([string]$authorization.stdout) `
    -Prefix $authorizationPreflightPrefix
Assert-Exact (
    -not [bool]$authorization.timed_out -and
    [int]$authorization.exit_code -eq 0 -and
    [bool]$authorizationReceipt.cell_declared -and
    [bool]$authorizationReceipt.authorization_exact -and
    [string]$authorizationReceipt.world_attempt_id -ceq $authorizationWorldAttemptId -and
    [string]$authorizationReceipt.campaign_attempt_id -ceq $campaignAttemptId -and
    [int]$authorizationReceipt.actual_world_build_count -eq 0 -and
    [int]$authorizationReceipt.scene_tree_insertion_count -eq 0 -and
    -not [bool]$authorizationReceipt.physics_state_modified -and
    -not [bool]$authorizationReceipt.locomotion_outcome_exposed -and
    -not [bool]$authorizationReceipt.physical_acceptance_authority
) "$gateId valid authorization path changed or exposed a world"

$wrongToken = Invoke-GodotCaptured `
    -Arguments @(
        "--headless", "--path", $repoRoot,
        "--script", "res://tests/test_sdk_balanced_wave_bw28y_yaw_development.gd",
        "--", "authorization_preflight", $authorizationCellId
    ) `
    -WorkerRoot (Join-Path $preflightRoot "authorization-wrong-token") `
    -TimeoutSeconds 60 `
    -AttemptPath $authorizationAttemptPath `
    -AuthorizationToken ("0" * 32) `
    -CellId $authorizationCellId `
    -WorldAttemptId $authorizationWorldAttemptId `
    -CampaignAttemptId $campaignAttemptId
$wrongTokenReceipt = Get-ReceiptFromOutput `
    -OutputText ([string]$wrongToken.stdout) `
    -Prefix $authorizationPreflightPrefix
Assert-Exact (
    -not [bool]$wrongToken.timed_out -and
    [int]$wrongToken.exit_code -ne 0 -and
    -not [bool]$wrongTokenReceipt.authorization_exact -and
    [int]$wrongTokenReceipt.actual_world_build_count -eq 0
) "$gateId wrong-token authorization canary did not fail before a world"

$staleAttempt = Copy-Bw28yValue $authorizationRoundTrip
$staleAttempt.godot_adapter_artifact_sha256 = "0" * 64
$staleAttemptPath = Join-Path $preflightRoot "authorization-stale-adapter.json"
Write-NewJsonArtifact -Value $staleAttempt -Path $staleAttemptPath
$staleAdapter = Invoke-GodotCaptured `
    -Arguments @(
        "--headless", "--path", $repoRoot,
        "--script", "res://tests/test_sdk_balanced_wave_bw28y_yaw_development.gd",
        "--", "authorization_preflight", $authorizationCellId
    ) `
    -WorkerRoot (Join-Path $preflightRoot "authorization-stale-adapter") `
    -TimeoutSeconds 60 `
    -AttemptPath $staleAttemptPath `
    -AuthorizationToken $authorizationToken `
    -CellId $authorizationCellId `
    -WorldAttemptId $authorizationWorldAttemptId `
    -CampaignAttemptId $campaignAttemptId
$staleAdapterReceipt = Get-ReceiptFromOutput `
    -OutputText ([string]$staleAdapter.stdout) `
    -Prefix $authorizationPreflightPrefix
Assert-Exact (
    -not [bool]$staleAdapter.timed_out -and
    [int]$staleAdapter.exit_code -ne 0 -and
    -not [bool]$staleAdapterReceipt.authorization_exact -and
    [int]$staleAdapterReceipt.actual_world_build_count -eq 0
) "$gateId stale-adapter authorization canary did not fail before a world"

$missingAttemptPath = Join-Path $preflightRoot "authorization-missing-attempt.json"
Assert-Exact (-not (Test-Path -LiteralPath $missingAttemptPath)) (
    "$gateId missing-attempt canary path unexpectedly exists"
)
$missingAttempt = Invoke-GodotCaptured `
    -Arguments @(
        "--headless", "--path", $repoRoot,
        "--script", "res://tests/test_sdk_balanced_wave_bw28y_yaw_development.gd",
        "--", "authorization_preflight", $authorizationCellId
    ) `
    -WorkerRoot (Join-Path $preflightRoot "authorization-missing-attempt") `
    -TimeoutSeconds 60 `
    -AttemptPath $missingAttemptPath `
    -AuthorizationToken $authorizationToken `
    -CellId $authorizationCellId `
    -WorldAttemptId $authorizationWorldAttemptId `
    -CampaignAttemptId $campaignAttemptId
$missingAttemptReceipt = Get-ReceiptFromOutput `
    -OutputText ([string]$missingAttempt.stdout) `
    -Prefix $authorizationPreflightPrefix
Assert-Exact (
    -not [bool]$missingAttempt.timed_out -and
    [int]$missingAttempt.exit_code -ne 0 -and
    -not [bool]$missingAttemptReceipt.authorization_exact -and
    [int]$missingAttemptReceipt.actual_world_build_count -eq 0
) "$gateId nonexistent-attempt authorization canary did not fail before a world"

$bypass = Invoke-GodotCaptured `
    -Arguments @(
        "--headless", "--path", $repoRoot,
        "--script", "res://tests/test_sdk_balanced_wave_bw28y_yaw_development.gd",
        "--", "physical", $authorizationCellId
    ) `
    -WorkerRoot (Join-Path $preflightRoot "physical-bypass") `
    -TimeoutSeconds 60
Assert-Exact (
    -not [bool]$bypass.timed_out -and [int]$bypass.exit_code -ne 0 -and
    (([string]$bypass.stdout) + ([string]$bypass.stderr)).Contains(
        "physical entry requires exact retained supervisor authorization",
        [StringComparison]::Ordinal
    ) -and
    -not (([string]$bypass.stdout).Contains($rawCellPrefix, [StringComparison]::Ordinal))
) "$gateId direct physical-worker bypass did not fail before a world"

# Exercise the exact recovery decision without opening a world.  The four
# complete-result canaries deliberately share identical structural inputs:
# their positive/negative scientific interpretation is not available to this
# function and therefore cannot affect replacement eligibility.
$receiptDispositionParameters = @(
    (Get-Command Get-Bw28yReceiptDisposition).Parameters.Keys
)
foreach ($forbiddenOutcomeParameter in @(
    "WalkingObserved", "MechanismGatePassed", "ApplicationGatePassed",
    "CommonExecutionIntegrity", "OutcomeComplete", "FailureCode"
)) {
    Assert-Exact (
        $forbiddenOutcomeParameter -notin $receiptDispositionParameters
    ) "$gateId recovery decision accepted forbidden outcome parameter"
}
$recoveryCanaries = @(
    [ordered]@{
        name = "complete_positive_primary"; attempt_kind = "primary"
        timed_out = $false; exit_code = 0; parsed = $true
        identity = $true; declared_complete = $true; composed = $true
        expected_action = "finalize_cell"
    },
    [ordered]@{
        name = "complete_negative_walking_primary"; attempt_kind = "primary"
        timed_out = $false; exit_code = 0; parsed = $true
        identity = $true; declared_complete = $true; composed = $true
        expected_action = "finalize_cell"
    },
    [ordered]@{
        name = "complete_negative_mechanism_primary"; attempt_kind = "primary"
        timed_out = $false; exit_code = 0; parsed = $true
        identity = $true; declared_complete = $true; composed = $true
        expected_action = "finalize_cell"
    },
    [ordered]@{
        name = "complete_negative_integrity_primary"; attempt_kind = "primary"
        timed_out = $false; exit_code = 0; parsed = $true
        identity = $true; declared_complete = $true; composed = $true
        expected_action = "finalize_cell"
    },
    [ordered]@{
        name = "timeout_primary"; attempt_kind = "primary"
        timed_out = $true; exit_code = -1; parsed = $false
        identity = $false; declared_complete = $false; composed = $false
        expected_action = "run_declared_replacement"
    },
    [ordered]@{
        name = "missing_receipt_primary"; attempt_kind = "primary"
        timed_out = $false; exit_code = 1; parsed = $false
        identity = $false; declared_complete = $false; composed = $false
        expected_action = "run_declared_replacement"
    },
    [ordered]@{
        name = "identity_invalid_primary"; attempt_kind = "primary"
        timed_out = $false; exit_code = 0; parsed = $true
        identity = $false; declared_complete = $true; composed = $false
        expected_action = "run_declared_replacement"
    },
    [ordered]@{
        name = "composition_failed_primary"; attempt_kind = "primary"
        timed_out = $false; exit_code = 0; parsed = $true
        identity = $true; declared_complete = $true; composed = $false
        expected_action = "run_declared_replacement"
    },
    [ordered]@{
        name = "incomplete_replacement_exhausted"; attempt_kind = "replacement"
        timed_out = $true; exit_code = -1; parsed = $false
        identity = $false; declared_complete = $false; composed = $false
        expected_action = "close_cell_incomplete_recovery_exhausted"
    }
)
foreach ($canary in $recoveryCanaries) {
    $disposition = Get-Bw28yReceiptDisposition `
        -AttemptKind ([string]$canary.attempt_kind) `
        -TimedOut ([bool]$canary.timed_out) `
        -ExitCode ([int]$canary.exit_code) `
        -RawReceiptParsed ([bool]$canary.parsed) `
        -RawIdentityExact ([bool]$canary.identity) `
        -RawReceiptStructurallyComplete ([bool]$canary.declared_complete) `
        -CompositionSucceeded ([bool]$canary.composed)
    Assert-Exact (
        [string]$disposition.recovery_action -ceq
            [string]$canary.expected_action -and
        -not [bool]$disposition.locomotion_outcome_consulted -and
        -not [bool]$disposition.mechanism_outcome_consulted -and
        -not [bool]$disposition.integrity_outcome_consulted
    ) "$gateId recovery canary failed: $($canary.name)"
}

if ($PreflightOnly) {
    Write-Host (
        "$gateId PREFLIGHT_PASS worlds=0 entrypoints=28 adapter_starts=27 " +
        "candidates=24 controls=3 safety=1 production_gates=50 " +
        "evaluator_canaries=19 authority=13/13 receipts=28 " +
        "receipt_canaries=5 attempt_canaries=16 authorization_canaries=5 " +
        "recovery_canaries=$($recoveryCanaries.Count) " +
        "negative_walking_integrity=True outcomes_exposed=False " +
        "validation_authority=False physical_authority=False"
    )
    exit 0
}

$status = @(& git -C $repoRoot status --porcelain=v1 --untracked-files=all)
$head = (& git -C $repoRoot rev-parse HEAD).Trim()
$originMain = (& git -C $repoRoot rev-parse origin/main).Trim()
$liveLine = (& git -C $repoRoot ls-remote origin refs/heads/main).Trim()
$liveMain = if ([string]::IsNullOrWhiteSpace($liveLine)) {
    ""
} else {
    ($liveLine -split "\s+")[0]
}
Assert-Exact (
    $LASTEXITCODE -eq 0 -and $status.Count -eq 0 -and
    $head -cmatch "^[0-9a-f]{40}$" -and
    $head -ceq $originMain -and $head -ceq $liveMain
) "$gateId requires clean source with HEAD equal to live GitHub main"

$resolvedAttestationPath = [System.IO.Path]::GetFullPath(
    $FullConformanceAttestation
)
$attestationVerification = Test-SporeSporeFullConformanceAttestationFile `
    -RepoRoot $repoRoot `
    -Godot $godotPath `
    -AttestationPath $resolvedAttestationPath
Assert-Exact (
    [bool]$attestationVerification.ok -and
    @($attestationVerification.failure_codes).Count -eq 0
) (
    "$gateId exact full-conformance attestation failed: " +
    (@($attestationVerification.failure_codes) -join ",")
)
$attestationDocument = Get-Content -Raw -LiteralPath $resolvedAttestationPath |
    ConvertFrom-Json -AsHashtable -Depth 64
Assert-Exact (
    [string]$attestationDocument.schema_version -ceq
        "sporespore_full_godot_conformance_attestation_v2" -and
    [string]$attestationDocument.source.commit -ceq $head -and
    [string]$attestationDocument.source.origin_main -ceq $head -and
    [string]$attestationDocument.source.live_github_main -ceq $head -and
    [bool]$attestationDocument.source.clean_pushed_live -and
    -not [bool]$attestationDocument.conformance.one_shot_physical_campaign_executed
) "$gateId full-conformance attestation source or campaign boundary changed"
foreach ($claimName in @($attestationDocument.claims.Keys)) {
    Assert-Exact (-not [bool]$attestationDocument.claims[$claimName]) (
        "$gateId full-conformance attestation inflated claim: $claimName"
    )
}
$attestationSha256 = Get-RawSha256 -Path $resolvedAttestationPath

$resolvedOutputRoot = [System.IO.Path]::GetFullPath($OutputRoot)
$resolvedEvidenceRoot = [System.IO.Path]::GetFullPath($evidenceRoot)
Assert-Exact (
    $resolvedOutputRoot.StartsWith(
        $resolvedEvidenceRoot + [System.IO.Path]::DirectorySeparatorChar,
        [StringComparison]::OrdinalIgnoreCase
    ) -and
    -not (Test-Path -LiteralPath $resolvedOutputRoot)
) "$gateId OutputRoot must be new, durable, and inside SporeSpore_Evidence"
$expectedLeaf = "balanced-wave-bw28y-yaw-development-" + $head.Substring(0, 7)
Assert-Exact (
    [System.IO.Path]::GetFileName($resolvedOutputRoot) -ceq $expectedLeaf
) "$gateId OutputRoot leaf must be '$expectedLeaf'"
[void][System.IO.Directory]::CreateDirectory($resolvedOutputRoot)

$attemptPath = Join-Path $resolvedOutputRoot "attempt.json"
$authorizationToken = [Guid]::NewGuid().ToString("N")
$campaignAttemptId = [Guid]::NewGuid().ToString("N")
$attempt = New-Bw28yAttemptRecord `
    -Synthetic $false `
    -AttemptId $campaignAttemptId `
    -AuthorizationToken $authorizationToken `
    -SourceCommit $head `
    -AttestationPath $resolvedAttestationPath `
    -AttestationSha256 $attestationSha256
Assert-Exact (
    Test-Bw28yAttemptRecord -Attempt $attempt -Synthetic $false
) "$gateId physical attempt constructor did not satisfy its shared parser"
Write-NewJsonArtifact -Value $attempt -Path $attemptPath
$attemptRawSha256AtLaunch = Get-RawSha256 -Path $attemptPath

. $productionGatePath
$expectedCells = @(Get-Bw28yExpectedCells)
$cellAttempts = [System.Collections.Generic.List[object]]::new()
$finalCells = [System.Collections.Generic.List[object]]::new()
$completeReceiptCount = 0
$productionCellGatePassCount = 0
$replacementAttemptCount = 0
for ($index = 0; $index -lt $expectedCells.Count; $index += 1) {
    $expected = $expectedCells[$index]
    $cellId = [string]$expected.cell_id
    $finalReceipt = $null
    $cellFinalized = $false
    foreach ($attemptKind in @("primary", "replacement")) {
        if ($attemptKind -ceq "replacement" -and $cellFinalized) { break }
        if ($attemptKind -ceq "replacement") { $replacementAttemptCount += 1 }
        $worldAttemptId = if ($attemptKind -ceq "primary") {
            [string](Get-Bw28yPrimaryWorldAttemptIds)[$index]
        } else {
            [string](Get-Bw28yReplacementWorldAttemptIds)[$index]
        }
        $cellRoot = Join-Path (
            $resolvedOutputRoot
        ) (("cell-{0:D2}-" -f ($index + 1)) + $cellId + "\" + $attemptKind)
        [void][System.IO.Directory]::CreateDirectory($cellRoot)
        $process = Invoke-GodotCaptured `
            -Arguments @(
                "--headless", "--path", $repoRoot,
                "--script", "res://tests/test_sdk_balanced_wave_bw28y_yaw_development.gd",
                "--", "physical", $cellId
            ) `
            -WorkerRoot $cellRoot `
            -TimeoutSeconds $CellTimeoutSeconds `
            -AttemptPath $attemptPath `
            -AuthorizationToken $authorizationToken `
            -CellId $cellId `
            -WorldAttemptId $worldAttemptId `
            -CampaignAttemptId $campaignAttemptId
        $transcriptPath = Join-Path $cellRoot "transcript.log"
        $stderrPath = Join-Path $cellRoot "stderr.log"
        Write-Utf8NoBom -Path $transcriptPath -Text ([string]$process.stdout)
        Write-Utf8NoBom -Path $stderrPath -Text ([string]$process.stderr)

        $rawReceipt = $null
        $composedReceipt = $null
        $receiptError = ""
        $receiptComplete = $false
        $rawIdentityExact = $false
        $rawReceiptStructurallyComplete = $false
        $compositionSucceeded = $false
        $productionCellGatePassed = $false
        try {
            $rawReceipt = Get-ReceiptFromOutput `
                -OutputText ([string]$process.stdout) `
                -Prefix $rawCellPrefix
            $rawReceiptPath = Join-Path $cellRoot "raw-receipt.json"
            Write-NewJsonArtifact -Value $rawReceipt -Path $rawReceiptPath
            $rawIdentityExact = (
                [string]$rawReceipt.schema_version -ceq
                    "sporespore_balanced_wave_bw28y_yaw_development_raw_cell_v1" -and
                [string]$rawReceipt.campaign_id -ceq $campaignId -and
                [string]$rawReceipt.gate_id -ceq $gateId -and
                [string]$rawReceipt.cell_id -ceq $cellId -and
                [string]$rawReceipt.cohort -ceq [string]$expected.cohort -and
                [string]$rawReceipt.role -ceq [string]$expected.role -and
                [int]$rawReceipt.campaign_seed -eq [int]$expected.campaign_seed -and
                [string]$rawReceipt.world_attempt_id -ceq $worldAttemptId -and
                [string]$rawReceipt.campaign_attempt_id -ceq $campaignAttemptId -and
                $rawReceipt.Contains("role_gate_passed") -and
                $rawReceipt.role_gate_passed -is [bool] -and
                -not [bool]$rawReceipt.walking_result_controls_process_exit
            )
            $rawReceiptStructurallyComplete = Test-Bw28yRawWorkerReceipt `
                -RawCell $rawReceipt `
                -Expected $expected `
                -ProcessExitCode ([int]$process.exit_code) `
                -ProcessOutput (
                    ([string]$process.stdout) + [Environment]::NewLine +
                    ([string]$process.stderr)
                )
            if (-not $rawIdentityExact) {
                throw "$gateId raw worker receipt identity contract changed"
            }
            if ([bool]$process.timed_out -or -not $rawReceiptStructurallyComplete) {
                throw (
                    "$gateId worker did not emit a healthy, structurally complete " +
                    "production-route receipt"
                )
            }
            $rawReceipt["worker_process_exit_code"] = [int]$process.exit_code
            $rawReceipt["worker_timed_out"] = [bool]$process.timed_out
            $composedReceipt = ConvertTo-Bw28yFinalCellReceipt `
                -RawCell $rawReceipt `
                -Expected $expected
            $finalReceiptPath = Join-Path $cellRoot "final-receipt.json"
            Write-NewJsonArtifact -Value $composedReceipt -Path $finalReceiptPath
            $compositionSucceeded = $true
            $productionCellGatePassed = Test-Bw28yCell `
                -Cell $composedReceipt `
                -Expected $expected
        } catch {
            $receiptError = $_.Exception.Message
        }
        $disposition = Get-Bw28yReceiptDisposition `
            -AttemptKind $attemptKind `
            -TimedOut ([bool]$process.timed_out) `
            -ExitCode ([int]$process.exit_code) `
            -RawReceiptParsed ($null -ne $rawReceipt) `
            -RawIdentityExact $rawIdentityExact `
            -RawReceiptStructurallyComplete $rawReceiptStructurallyComplete `
            -CompositionSucceeded $compositionSucceeded
        $receiptComplete = [bool]$disposition.structural_receipt_complete
        if ($receiptComplete) {
            $finalReceipt = $composedReceipt
            if ($productionCellGatePassed) {
                $productionCellGatePassCount += 1
            }
        }
        $cellAttempts.Add([ordered]@{
            ordinal = $index + 1
            cell_id = $cellId
            attempt_kind = $attemptKind
            world_attempt_id = $worldAttemptId
            process_exit_code = [int]$process.exit_code
            timed_out = [bool]$process.timed_out
            killed_process_tree = [bool]$process.killed_process_tree
            duration_seconds = [double]$process.duration_seconds
            raw_receipt_parsed = $null -ne $rawReceipt
            complete_final_receipt = $receiptComplete
            role_gate_passed = $(if ($null -eq $rawReceipt) {
                $false
            } else {
                [bool]$rawReceipt.role_gate_passed
            })
            production_cell_gate_passed = $productionCellGatePassed
            recovery_action = [string]$disposition.recovery_action
            recovery_reason = [string]$disposition.recovery_reason
            replacement_eligible = [bool]$disposition.replacement_eligible
            linked_primary_world_attempt_id = $(if ($attemptKind -ceq "replacement") {
                [string](Get-Bw28yPrimaryWorldAttemptIds)[$index]
            } else { "" })
            receipt_error = $receiptError
            transcript_path = $transcriptPath
            transcript_raw_sha256 = Get-RawSha256 -Path $transcriptPath
            stderr_path = $stderrPath
            stderr_raw_sha256 = Get-RawSha256 -Path $stderrPath
            locomotion_outcome_triggered_replacement = $false
        })
        if ($receiptComplete) {
            $cellFinalized = $true
            break
        }
    }
    if ($null -ne $finalReceipt) {
        $finalCells.Add($finalReceipt)
        $completeReceiptCount += 1
    } else {
        $finalCells.Add([ordered]@{})
    }
}

Assert-Exact (
    (Get-RawSha256 -Path $attemptPath) -ceq $attemptRawSha256AtLaunch
) "$gateId immutable attempt receipt changed after physical launch"
$integrityFailureCount = 28 - $productionCellGatePassCount
$completeResult = $completeReceiptCount -eq 28
$rawResult = New-Bw28yPerfectSyntheticYawDevelopmentResult
$rawResult.source.commit = $head
$rawResult.source.worktree_clean = $true
$rawResult.source.matches_live_github_main = $true
$rawResult.source["stage_one_freeze_raw_sha256"] = Get-RawSha256 -Path $freezePath
$rawResult.observed_world_count = $completeReceiptCount
$rawResult.integrity_failure_count = $integrityFailureCount
$rawResult["physical_world_process_attempt_count"] = $cellAttempts.Count
$rawResult["complete_final_receipt_count"] = $completeReceiptCount
$rawResult.cells = @($finalCells)
$rawResultPath = Join-Path $resolvedOutputRoot "raw-result.json"
Write-NewJsonArtifact -Value $rawResult -Path $rawResultPath
$evaluation = Invoke-Bw28yYawDevelopmentEvaluation -Result $rawResult
$evaluationPath = Join-Path $resolvedOutputRoot "evaluation.json"
Write-NewJsonArtifact -Value $evaluation -Path $evaluationPath

$completion = [ordered]@{
    schema_version =
        "sporespore_balanced_wave_bw28y_yaw_development_completion_v1"
    campaign_id = $campaignId
    gate_id = $gateId
    completed_at_utc = [DateTime]::UtcNow.ToString("o")
    source_commit = $head
    campaign_attempt_id = $campaignAttemptId
    expected_cell_count = 28
    worker_process_attempt_count = $cellAttempts.Count
    replacement_attempt_count = $replacementAttemptCount
    complete_final_receipt_count = $completeReceiptCount
    production_cell_gate_pass_count = $productionCellGatePassCount
    integrity_failure_count = $integrityFailureCount
    complete_result = $completeResult
    evaluation_ok = [bool]$evaluation.ok
    selected_candidate_id = [string]$evaluation.selected_candidate_id
    development_selection_authority = [bool]$evaluation.development_selection_authority
    independent_validation_authority = $false
    full_godot_v2_attestation_sha256 = $attestationSha256
    attempt_immutable = (
        (Get-RawSha256 -Path $attemptPath) -ceq $attemptRawSha256AtLaunch
    )
    same_identity_rerun_allowed = $false
    physical_acceptance_authority = $false
}
$completionPath = Join-Path $resolvedOutputRoot "completion.json"
Write-NewJsonArtifact -Value $completion -Path $completionPath

$report = [ordered]@{
    schema_version = "sporespore_balanced_wave_bw28y_yaw_development_report_v1"
    campaign_id = $campaignId
    gate_id = $gateId
    completed_at_utc = [DateTime]::UtcNow.ToString("o")
    source_commit = $head
    campaign_attempt_id = $campaignAttemptId
    first_complete_result_final_for_source_identity = $completeResult
    complete_final_receipt_count = $completeReceiptCount
    production_cell_gate_pass_count = $productionCellGatePassCount
    physical_world_process_attempt_count = $cellAttempts.Count
    recovery_exhausted_incomplete_cell_count = 28 - $completeReceiptCount
    evaluation_ok = [bool]$evaluation.ok
    result_status = $(if (-not $completeResult) {
        "incomplete_execution_recovery_exhausted"
    } elseif ([bool]$evaluation.ok) {
        if ([string]$evaluation.selected_candidate_id -ceq "NONE") {
            "valid_development_no_selection"
        } else {
            "valid_development_hypothesis_selected_requires_fresh_validation"
        }
    } else {
        "invalid_development_execution_retained"
    })
    selected_candidate_id = [string]$evaluation.selected_candidate_id
    development_selection_authority = [bool]$evaluation.development_selection_authority
    independent_validation_authority = $false
    full_godot_v2_attestation = [ordered]@{
        path = $resolvedAttestationPath
        sha256 = $attestationSha256
        source_commit = [string]$attestationDocument.source.commit
        schema_version = [string]$attestationDocument.schema_version
        production_verifier_ok = [bool]$attestationVerification.ok
        failure_codes = @($attestationVerification.failure_codes)
        physical_acceptance_authority = $false
    }
    operation_lock = $(Get-SporeSporeLocomotionOperationLockPublicReceipt `
        -Receipt $operationLockReceipt)
    attempt_path = $attemptPath
    attempt_raw_sha256 = $attemptRawSha256AtLaunch
    raw_result_path = $rawResultPath
    raw_result_raw_sha256 = Get-RawSha256 -Path $rawResultPath
    evaluation_path = $evaluationPath
    evaluation_raw_sha256 = Get-RawSha256 -Path $evaluationPath
    completion_path = $completionPath
    completion_raw_sha256 = Get-RawSha256 -Path $completionPath
    cell_attempts = @($cellAttempts)
    evaluation = $evaluation
    claim_scope = (
        "Outcome-exposed finite development evidence only. Any selected arm " +
        "requires a new campaign, fresh unexposed material values, and fresh " +
        "unexposed seeds before any validation or robustness claim."
    )
    physical_acceptance_authority = $false
}
$reportPath = Join-Path $resolvedOutputRoot "report.json"
Write-NewJsonArtifact -Value $report -Path $reportPath

if (-not $completeResult) {
    $incompleteCellCount = 28 - $completeReceiptCount
    throw (
        "$gateId physical execution was retained incomplete after exhausting " +
        "the single declared replacement for $incompleteCellCount cell(s)"
    )
}
if (-not [bool]$evaluation.ok) {
    throw (
        "$gateId complete physical execution was retained but failed its " +
        "frozen integrity gate; no result-driven rerun is allowed"
    )
}
Write-Host (
    "$gateId PHYSICAL_COMPLETE cells=28 process_attempts=$($cellAttempts.Count) " +
    "replacements=$replacementAttemptCount selected=$($evaluation.selected_candidate_id) " +
    "development_selection=$($evaluation.development_selection_authority) " +
    "validation_authority=False report=$reportPath"
)
} finally {
    if ($null -ne $operationLockReceipt -and [bool]$operationLockReceipt.acquired) {
        Exit-SporeSporeLocomotionOperationLock -Receipt $operationLockReceipt
    }
}
