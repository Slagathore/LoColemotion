#requires -Version 7.0

[CmdletBinding()]
param(
    [string]$Godot = (
        "C:\Users\Cole\CodeStuff\Misc\Godot\" +
        "Godot_v4.7-stable_mono_win64_console.exe"
    )
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$sdkRoot = Join-Path $repoRoot "sdk"
$contractPath = Join-Path $sdkRoot "turning\physical_development_contract_v1.json"
$freezePath = Join-Path $sdkRoot "turning\physical_development_freeze_v1.json"
$supervisorPath = Join-Path $sdkRoot "run_qsdk_r23d1_supervisor.ps1"
$evidenceRoot = Join-Path (Split-Path -Parent $repoRoot) "SporeSpore_Evidence"
$campaignId = "QSDK-R23D1-THREE-ENGINE-HEADING-RESPONSE-DEVELOPMENT"
$expectedCells = @(
    "godot_jolt__reference_zero",
    "godot_jolt__positive_heading",
    "godot_jolt__negative_heading",
    "rapier_parry__reference_zero",
    "rapier_parry__positive_heading",
    "rapier_parry__negative_heading",
    "mujoco__reference_zero",
    "mujoco__positive_heading",
    "mujoco__negative_heading"
)

function Assert-R23D1Freeze {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function Get-R23D1FreezeRawSha256 {
    param([Parameter(Mandatory)][string]$Path)
    return "sha256:" + (
        Get-FileHash -LiteralPath $Path -Algorithm SHA256
    ).Hash.ToLowerInvariant()
}

Assert-R23D1Freeze (
    (git -C $repoRoot rev-parse --show-toplevel).Replace("/", "\") -ceq $repoRoot -and
    (git -C $repoRoot remote get-url origin) -ceq
        "https://github.com/Slagathore/sporespore.git"
) "QSDK-R23D1 freeze audit repository identity mismatch"

foreach ($path in @($contractPath, $freezePath, $supervisorPath, $Godot)) {
    Assert-R23D1Freeze (Test-Path -LiteralPath $path -PathType Leaf) (
        "QSDK-R23D1 freeze input missing: $path"
    )
}

$contract = Get-Content -Raw -LiteralPath $contractPath |
    ConvertFrom-Json -AsHashtable -Depth 100
$freeze = Get-Content -Raw -LiteralPath $freezePath |
    ConvertFrom-Json -AsHashtable -Depth 100
Assert-R23D1Freeze (
    [string]$contract.schema_version -ceq
        "sporespore_qsdk_r23d1_physical_development_contract_v1" -and
    [string]$contract.campaign_id -ceq $campaignId -and
    [string]$contract.aggregate_supervisor.status -ceq
        "frozen_physical_authorized_pending_exact_source_attestation" -and
    [string]$contract.aggregate_supervisor.supervisor_path -ceq
        "sdk/run_qsdk_r23d1_supervisor.ps1" -and
    [string]$contract.aggregate_supervisor.freeze_path -ceq
        "sdk/turning/physical_development_freeze_v1.json" -and
    [bool]$contract.aggregate_supervisor.serial_one_shot_required -and
    [bool]$contract.aggregate_supervisor.content_addressed_retention_before_consumption_required -and
    -not [bool]$contract.aggregate_supervisor.replacement_or_selective_rerun_permitted -and
    [bool]$contract.authorization.physical_execution_authorized -and
    [bool]$contract.authorization.launch_requires_clean_pushed_live_authorization_source -and
    [bool]$contract.authorization.launch_requires_matching_current_full_godot_v2_attestation -and
    [int]$contract.authorization.authorized_serial_world_count -eq 9 -and
    -not [bool]$contract.authorization.replacement_or_selective_rerun_permitted -and
    -not [bool]$contract.authorization.q_sdk_r23_satisfied -and
    -not [bool]$contract.authorization.physical_acceptance_authority
) "QSDK-R23D1 contract is not the expected physical-authorization boundary"

$preauthorization = $contract.authorization.preauthorization_attestation
$preauthorizationPath = [IO.Path]::GetFullPath([string]$preauthorization.path)
Assert-R23D1Freeze (
    $preauthorizationPath.StartsWith(
        [IO.Path]::GetFullPath($evidenceRoot).TrimEnd("\", "/") +
            [IO.Path]::DirectorySeparatorChar,
        [StringComparison]::OrdinalIgnoreCase
    ) -and
    (Test-Path -LiteralPath $preauthorizationPath -PathType Leaf) -and
    [string]$preauthorization.raw_sha256 -ceq
        (Get-R23D1FreezeRawSha256 $preauthorizationPath) -and
    [string]$preauthorization.source_commit -ceq
        "7e8bc1cb8e6c0273cfb013889ee6e851cacab8dd" -and
    [string]$preauthorization.source_tree_git_oid -ceq
        "41dea4cd420e1926a94a2218868ac3c54fdfdaac" -and
    [bool]$preauthorization.production_verifier_passed_before_authorization_freeze -and
    -not [bool]$preauthorization.new_physical_campaign_executed -and
    -not [bool]$preauthorization.physical_acceptance_authority -and
    (git -C $repoRoot rev-parse "$([string]$preauthorization.source_commit)^{tree}") -ceq
        [string]$preauthorization.source_tree_git_oid
) "QSDK-R23D1 preauthorization attestation identity changed"
$preauthorizationDocument = Get-Content -Raw -LiteralPath $preauthorizationPath |
    ConvertFrom-Json -AsHashtable -Depth 100
Assert-R23D1Freeze (
    [string]$preauthorizationDocument.schema_version -ceq
        "sporespore_full_godot_conformance_attestation_v2" -and
    [string]$preauthorizationDocument.status -ceq
        "full_godot_conformance_passed" -and
    [string]$preauthorizationDocument.source.commit -ceq
        [string]$preauthorization.source_commit -and
    [string]$preauthorizationDocument.source.tree_git_oid -ceq
        [string]$preauthorization.source_tree_git_oid -and
    [bool]$preauthorizationDocument.conformance.passed -and
    -not [bool]$preauthorizationDocument.conformance.skip_godot -and
    -not [bool]$preauthorizationDocument.conformance.one_shot_physical_campaign_executed -and
    @($preauthorizationDocument.claims.Values | Where-Object { [bool]$_ }).Count -eq 0
) "QSDK-R23D1 preauthorization attestation content changed"

Assert-R23D1Freeze (
    [string]$freeze.schema_version -ceq
        "sporespore_qsdk_r23d1_supervisor_freeze_v1" -and
    [string]$freeze.status -ceq
        "frozen_physical_authorized" -and
    [string]$freeze.campaign_id -ceq $campaignId -and
    [string]$freeze.gate_id -ceq "QSDK-R23D1" -and
    [string]$freeze.contract_raw_sha256 -ceq
        (Get-R23D1FreezeRawSha256 $contractPath) -and
    [int]$freeze.declared_cell_count -eq 9 -and
    (@($freeze.ordered_cell_ids) -join "|") -ceq ($expectedCells -join "|") -and
    [int]$freeze.declared_source_binding_count -eq 24 -and
    @($freeze.source_bindings).Count -eq 24 -and
    @($freeze.external_runtime_bindings).Count -eq 14 -and
    @($freeze.attempt_runtime_artifacts).Count -eq 17 -and
    [bool]$freeze.serial_one_shot_required -and
    [bool]$freeze.content_addressed_retention_before_consumption_required -and
    [bool]$freeze.exact_full_godot_v2_attestation_required -and
    -not [bool]$freeze.replacement_or_selective_rerun_permitted -and
    [bool]$freeze.physical_execution_authorized -and
    [bool]$freeze.authorization_requires_clean_pushed_live_source -and
    [bool]$freeze.authorization_requires_matching_current_full_godot_v2_attestation -and
    [string]$freeze.preauthorization_attestation_raw_sha256 -ceq
        [string]$preauthorization.raw_sha256 -and
    -not [bool]$freeze.physical_acceptance_authority
) "QSDK-R23D1 supervisor freeze identity changed"

$sourceNames = @($freeze.source_bindings | ForEach-Object { [string]$_.name })
$sourcePaths = @($freeze.source_bindings | ForEach-Object { [string]$_.path })
Assert-R23D1Freeze (
    @($sourceNames | Sort-Object -Unique).Count -eq $sourceNames.Count -and
    @($sourcePaths | Sort-Object -Unique).Count -eq $sourcePaths.Count -and
    $sourceNames -ccontains "physical_development_tests" -and
    $sourcePaths -ccontains "sdk/turning/test_physical_development.py" -and
    $sourceNames -ccontains "mujoco_worker_tests" -and
    $sourcePaths -ccontains "sdk/adapters/mujoco/test_qsdk_r23d1_heading_response.py" -and
    $sourceNames -ccontains "supervisor_freeze_audit" -and
    $sourcePaths -ccontains "tests/test_qsdk_r23d1_supervisor_freeze.ps1"
) "QSDK-R23D1 source bindings contain a duplicate name or path"
foreach ($binding in @($freeze.source_bindings)) {
    $path = Join-Path $repoRoot ([string]$binding.path)
    Assert-R23D1Freeze (
        (Test-Path -LiteralPath $path -PathType Leaf) -and
        [string]$binding.raw_sha256 -ceq (Get-R23D1FreezeRawSha256 $path)
    ) "QSDK-R23D1 frozen source binding changed: $([string]$binding.path)"
}
foreach ($binding in @($freeze.external_runtime_bindings)) {
    $path = [IO.Path]::GetFullPath([string]$binding.path)
    Assert-R23D1Freeze (
        (Test-Path -LiteralPath $path -PathType Leaf) -and
        [string]$binding.raw_sha256 -ceq (Get-R23D1FreezeRawSha256 $path)
    ) "QSDK-R23D1 frozen external runtime changed: $path"
}

$preflightOutput = @(& pwsh -NoLogo -NoProfile -File $supervisorPath `
    -PreflightOnly -Godot $Godot 2>&1)
$preflightExit = $LASTEXITCODE
$preflightText = $preflightOutput -join "`n"
Assert-R23D1Freeze (
    $preflightExit -eq 0 -and
    $preflightText.Contains("QSDK_R23D1_SUPERVISOR_PASS") -and
    $preflightText.Contains("workers=3") -and
    $preflightText.Contains("entrypoints=9") -and
    $preflightText.Contains("reports=9") -and
    $preflightText.Contains("aggregate_negative_controls=3/3") -and
    $preflightText.Contains("physical_refusal=0") -and
    $preflightText.Contains("worlds=0") -and
    $preflightText.Contains("physical_authority=False") -and
    -not $preflightText.Contains("QSDK_R23D1_PHYSICAL_COMPLETE")
) "QSDK-R23D1 aggregate supervisor preflight failed: $preflightText"

$attemptsBefore = @(Get-ChildItem -LiteralPath $evidenceRoot -Directory |
    Where-Object { $_.Name -like "qsdk-r23d1-*" })
Assert-R23D1Freeze ($attemptsBefore.Count -eq 0) (
    "QSDK-R23D1 physical identity is already consumed; authorization audit must stop"
)
$refusalOutput = @(& pwsh -NoLogo -NoProfile -File $supervisorPath `
    -RunPhysical -Godot $Godot 2>&1)
$refusalExit = $LASTEXITCODE
$refusalText = $refusalOutput -join "`n"
Assert-R23D1Freeze (
    $refusalExit -ne 0 -and
    $refusalText.Contains(
        "QSDK-R23D1 physical execution requires a full-Godot V2 attestation"
    ) -and
    -not $refusalText.Contains("QSDK_R23D1_PHYSICAL_COMPLETE")
) "QSDK-R23D1 unattested physical launch did not fail closed: $refusalText"
$attemptsAfter = @(Get-ChildItem -LiteralPath $evidenceRoot -Directory |
    Where-Object { $_.Name -like "qsdk-r23d1-*" })
Assert-R23D1Freeze ($attemptsAfter.Count -eq 0) (
    "QSDK-R23D1 unattested launch canary created a physical attempt"
)

Write-Host (
    "QSDK_R23D1_PHYSICAL_AUTHORIZATION_FREEZE_PASS source_bindings=24 " +
    "external_runtimes=14 attempt_runtime_artifacts=17 workers=3 " +
    "entrypoints=9 reports=9 aggregate=1/1 negative_controls=3/3 " +
    "physical_authorized=True exact_current_attestation_required=True " +
    "unattested_launch_refusal=1 worlds=0 physical_authority=False"
)
