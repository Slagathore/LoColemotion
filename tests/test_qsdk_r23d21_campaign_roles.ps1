#requires -Version 7.0

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateSet("worker", "evaluator", "supervisor")]
    [string]$Role,
    [string]$Godot = (
        "C:\Users\Cole\CodeStuff\Misc\Godot\" +
        "Godot_v4.7-stable_mono_win64_console.exe"
    ),
    [string]$Python = "python"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$sdkRoot = Join-Path $repoRoot "sdk"
$contractPath = Join-Path $sdkRoot "turning\r23d21_physical_implementation_contract_v1.json"
$preregistrationPath = Join-Path $sdkRoot "turning\r23d21_reduced_yaw_authority_preregistration_v1.json"
$supervisorPath = Join-Path $sdkRoot "run_qsdk_r23d21_supervisor.ps1"
$workerResource = "res://tests/test_sdk_qsdk_r23d21_godot_jolt_physical_worker.gd"
$campaignId = "QSDK-R23D21-REDUCED-YAW-AUTHORITY-GODOT-DEVELOPMENT"
$stageId = "godot_jolt_reduced_yaw_authority_development"

function Assert-R23D21Role {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function Get-R23D21RoleRawSha256 {
    param([Parameter(Mandatory)][string]$Path)
    return "sha256:" + (
        Get-FileHash -LiteralPath $Path -Algorithm SHA256
    ).Hash.ToLowerInvariant()
}

function Write-R23D21RoleJson {
    param([Parameter(Mandatory)][string]$Path, [Parameter(Mandatory)]$Value)
    [IO.File]::WriteAllText(
        $Path,
        (($Value | ConvertTo-Json -Depth 100) + "`n"),
        [Text.UTF8Encoding]::new($false)
    )
}

function Invoke-R23D21RoleGodot {
    param(
        [Parameter(Mandatory)][string[]]$Arguments,
        [Collections.IDictionary]$Environment = @{}
    )
    $names = @(
        "SPORESPORE_QSDK_R23D21_FREEZE", "SPORESPORE_QSDK_R23D21_ATTEMPT",
        "SPORESPORE_QSDK_R23D21_TOKEN", "SPORESPORE_QSDK_R23D21_STAGE",
        "SPORESPORE_QSDK_R23D21_CELL", "SPORESPORE_QSDK_R23D21_ENGINE",
        "SPORESPORE_QSDK_R23D21_ATTEMPT_ROOT", "SPORESPORE_QSDK_R23D21_PYTHON",
        "SPORESPORE_QSDK_R23D21_POWERSHELL"
    )
    $prior = @{}
    foreach ($name in $names) {
        $prior[$name] = [Environment]::GetEnvironmentVariable($name, "Process")
        [Environment]::SetEnvironmentVariable($name, $null, "Process")
    }
    foreach ($entry in $Environment.GetEnumerator()) {
        [Environment]::SetEnvironmentVariable(
            [string]$entry.Key, [string]$entry.Value, "Process"
        )
    }
    try {
        $output = @(& $Godot @Arguments 2>&1)
        return [ordered]@{ exit_code = $LASTEXITCODE; output = ($output -join "`n") }
    } finally {
        foreach ($name in $names) {
            [Environment]::SetEnvironmentVariable($name, $prior[$name], "Process")
        }
    }
}

Assert-R23D21Role (
    (& git -C $repoRoot rev-parse --show-toplevel).Replace("/", "\") -ceq $repoRoot -and
    (& git -C $repoRoot remote get-url origin) -ceq
        "https://github.com/Slagathore/sporespore.git"
) "QSDK-R23D21 campaign-role repository identity mismatch"
foreach ($path in @($contractPath, $preregistrationPath, $supervisorPath, $Godot)) {
    Assert-R23D21Role (Test-Path -LiteralPath $path -PathType Leaf) (
        "QSDK-R23D21 campaign-role input is missing: $path"
    )
}

if ($Role -ceq "evaluator") {
    $code = @'
import json
from sdk.turning import r23d21_physical_trace as trace
from sdk.turning import r23d21_physical_evaluator as evaluator
evaluator._load_declaration()
receipt = trace.zero_world_receipt()
cell = trace.matrix_cells()[1]
rows = trace.synthetic_trace(cell)
rows[600]["cross_track_error_m"] = None
mutation = trace.validate_trace(cell, rows)
assert not mutation["ok"]
assert any(code == "R23D21_PATH_DIAGNOSTIC:600:cross_track_error_m" for code in mutation["failure_codes"])
print("QSDK_R23D21_CAMPAIGN_EVALUATOR_ROLE_PASS " + json.dumps({
    "campaign_id": trace.CAMPAIGN_ID,
    "matrix_cell_count": receipt["matrix_cell_count"],
    "trace_row_count_per_cell": receipt["trace_row_count_per_cell"],
    "path_diagnostic_mutation_refused": True,
    "world_attempt_count": 0,
    "world_build_count": 0,
    "physical_acceptance_authority": False,
}, separators=(",", ":")))
'@
    $output = @(& $Python -c $code 2>&1)
    Assert-R23D21Role ($LASTEXITCODE -eq 0) (
        "QSDK-R23D21 evaluator role failed: $($output -join ' ')"
    )
    Write-Host ($output -join "`n")
    return
}

if ($Role -ceq "supervisor") {
    $output = @(& pwsh -NoLogo -NoProfile -File $supervisorPath `
        -CampaignRolePreflight -Godot $Godot -Python $Python 2>&1)
    Assert-R23D21Role ($LASTEXITCODE -eq 0) (
        "QSDK-R23D21 supervisor role failed: $($output -join ' ')"
    )
    $prefix = "QSDK_R23D21_CAMPAIGN_SUPERVISOR_ROLE_PASS "
    Assert-R23D21Role (
        @($output | Where-Object { ([string]$_).StartsWith($prefix) }).Count -eq 1
    ) "QSDK-R23D21 supervisor role marker changed"
    $supervisorLine = [string](@($output | Where-Object {
        ([string]$_).StartsWith($prefix)
    })[0])
    $supervisorReceipt = $supervisorLine.Substring($prefix.Length) |
        ConvertFrom-Json -AsHashtable -Depth 30
    Assert-R23D21Role (
        [int]$supervisorReceipt.nonzero_exit_structured_failure_retention_canary_count -eq 1 -and
        [int]$supervisorReceipt.worker_terminal_mutation_control_count -eq 7
    ) "QSDK-R23D21 worker-terminal retention controls changed"
    Write-Host (
        "QSDK_R23D21_CAMPAIGN_SUPERVISOR_GATE_PASS " +
        (@{ campaign_id = $campaignId; world_attempt_count = 0; world_build_count = 0;
            physical_acceptance_authority = $false } | ConvertTo-Json -Compress)
    )
    return
}

$arms = @("reference_zero", "positive_heading", "negative_heading")
foreach ($arm in $arms) {
    $result = Invoke-R23D21RoleGodot -Arguments @(
        "--headless", "--path", $repoRoot,
        "--log-file", (Join-Path $sdkRoot "target\r23d21-role-$arm.log"),
        "--script", $workerResource, "--", "--preflight-only",
        "--stage", $stageId, "--arm", $arm
    )
    Assert-R23D21Role ([int]$result.exit_code -eq 0) (
        "QSDK-R23D21 worker preflight failed for $arm`: $([string]$result.output)"
    )
}

$contract = Get-Content -Raw -LiteralPath $contractPath |
    ConvertFrom-Json -AsHashtable -Depth 100
$sourceBindings = @()
foreach ($relativePath in @($contract.dependency_closure.required_dependency_paths_by_worker.godot_jolt)) {
    $absolute = Join-Path $repoRoot ([string]$relativePath)
    Assert-R23D21Role (Test-Path -LiteralPath $absolute -PathType Leaf) (
        "QSDK-R23D21 authorization-canary dependency missing: $relativePath"
    )
    $sourceBindings += [ordered]@{
        path = [string]$relativePath
        raw_sha256 = Get-R23D21RoleRawSha256 $absolute
    }
}
$evidenceRoot = [IO.Path]::GetFullPath((Join-Path $repoRoot "..\SporeSpore_Evidence"))
[void][IO.Directory]::CreateDirectory($evidenceRoot)
$canaryRoot = Join-Path $evidenceRoot ("qsdk-r23d21-role-canary-" + [guid]::NewGuid().ToString("N"))
[void][IO.Directory]::CreateDirectory($canaryRoot)
try {
    $sourceCommit = (& git -C $repoRoot rev-parse HEAD).Trim()
    $token = [guid]::NewGuid().ToString("N")
    $matrixIds = @($arms | ForEach-Object { "godot_jolt__tight_gated_horizon__$_" })
    $freeze = [ordered]@{
        schema_version = "sporespore_qsdk_r23d21_physical_freeze_v1"
        status = "frozen_supervisor_only_physical_authorized"
        campaign_id = $campaignId
        gate_id = "QSDK-R23D21"
        preregistration_raw_sha256 = Get-R23D21RoleRawSha256 $preregistrationPath
        implementation_contract_raw_sha256 = Get-R23D21RoleRawSha256 $contractPath
        source_commit = $sourceCommit
        source_bindings = $sourceBindings
        physical_execution_authorized = $true
    }
    $freezePath = Join-Path $canaryRoot "freeze.json"
    Write-R23D21RoleJson -Path $freezePath -Value $freeze
    $attempt = [ordered]@{
        schema_version = "sporespore_qsdk_r23d21_attempt_v1"
        attempt_id = [guid]::NewGuid().ToString("N")
        campaign_id = $campaignId
        gate_id = "QSDK-R23D21"
        freeze_raw_sha256 = Get-R23D21RoleRawSha256 $freezePath
        source_commit = $sourceCommit
        authorization_token = $token
        attempt_root = $canaryRoot
        ordered_matrix_cell_ids = $matrixIds
        physical_execution_authorized = $true
        single_use_supervisor_authorization = $true
        matrix_authorization_immutable_before_first_world = $true
        source_worktree_clean = $true
        source_matches_live_github_main = $true
        operation_lock_held = $true
        campaign_attestation_adoption_valid = $true
        content_addressed_inputs_retained = $true
        one_shot_attempt_unconsumed = $true
        physical_acceptance_authority = $false
    }
    $attemptPath = Join-Path $canaryRoot "attempt.json"
    Write-R23D21RoleJson -Path $attemptPath -Value $attempt
    $environment = [ordered]@{
        SPORESPORE_QSDK_R23D21_FREEZE = $freezePath
        SPORESPORE_QSDK_R23D21_ATTEMPT = $attemptPath
        SPORESPORE_QSDK_R23D21_TOKEN = $token
        SPORESPORE_QSDK_R23D21_STAGE = $stageId
        SPORESPORE_QSDK_R23D21_CELL = $matrixIds[0]
        SPORESPORE_QSDK_R23D21_ENGINE = "godot_jolt"
        SPORESPORE_QSDK_R23D21_ATTEMPT_ROOT = $canaryRoot
        SPORESPORE_QSDK_R23D21_PYTHON = $Python
        SPORESPORE_QSDK_R23D21_POWERSHELL = "pwsh"
    }
    $positive = Invoke-R23D21RoleGodot -Environment $environment -Arguments @(
        "--headless", "--path", $repoRoot,
        "--log-file", (Join-Path $canaryRoot "positive.log"),
        "--script", $workerResource, "--", "--authorization-preflight",
        "--stage", $stageId, "--arm", "reference_zero", "--source-commit", $sourceCommit
    )
    Assert-R23D21Role (
        [int]$positive.exit_code -eq 0 -and
        ([string]$positive.output).Contains("QSDK_R23D21_GODOT_JOLT_AUTHORIZATION_PREFLIGHT ")
    ) "QSDK-R23D21 intact production authorization canary failed"

    $mutatedFreeze = $freeze | ConvertTo-Json -Depth 100 | ConvertFrom-Json -AsHashtable -Depth 100
    $mutatedFreeze.source_bindings[0].raw_sha256 = "sha256:" + ("0" * 64)
    $mutatedFreezePath = Join-Path $canaryRoot "freeze-mutated.json"
    Write-R23D21RoleJson -Path $mutatedFreezePath -Value $mutatedFreeze
    $mutatedAttempt = $attempt | ConvertTo-Json -Depth 100 | ConvertFrom-Json -AsHashtable -Depth 100
    $mutatedAttempt.freeze_raw_sha256 = Get-R23D21RoleRawSha256 $mutatedFreezePath
    $mutatedAttemptPath = Join-Path $canaryRoot "attempt-mutated.json"
    Write-R23D21RoleJson -Path $mutatedAttemptPath -Value $mutatedAttempt
    $environment.SPORESPORE_QSDK_R23D21_FREEZE = $mutatedFreezePath
    $environment.SPORESPORE_QSDK_R23D21_ATTEMPT = $mutatedAttemptPath
    $mutated = Invoke-R23D21RoleGodot -Environment $environment -Arguments @(
        "--headless", "--path", $repoRoot,
        "--log-file", (Join-Path $canaryRoot "mutated.log"),
        "--script", $workerResource, "--", "--authorization-preflight",
        "--stage", $stageId, "--arm", "reference_zero", "--source-commit", $sourceCommit
    )
    Assert-R23D21Role (
        [int]$mutated.exit_code -ne 0 -and
        ([string]$mutated.output).Contains("QSDK_R23D21_GJT_PHYSICAL_AUTHORIZATION_INVALID")
    ) "QSDK-R23D21 mutated source binding was not refused"
} finally {
    $resolvedCanary = [IO.Path]::GetFullPath($canaryRoot)
    $resolvedEvidence = [IO.Path]::GetFullPath($evidenceRoot).TrimEnd("\", "/") + "\"
    if ($resolvedCanary.StartsWith($resolvedEvidence, [StringComparison]::OrdinalIgnoreCase) -and
        (Split-Path -Leaf $resolvedCanary) -like "qsdk-r23d21-role-canary-*") {
        Remove-Item -LiteralPath $resolvedCanary -Recurse -Force
    }
}

Write-Host (
    "QSDK_R23D21_CAMPAIGN_WORKER_ROLE_PASS " +
    (@{ campaign_id = $campaignId; preflight_cell_count = 3;
        intact_authorization_canary_count = 1; mutated_binding_refusal_count = 1;
        model_construction_count = 0; world_attempt_count = 0; world_build_count = 0;
        physical_acceptance_authority = $false } | ConvertTo-Json -Compress)
)
