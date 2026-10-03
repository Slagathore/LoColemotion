#requires -Version 7.0

[CmdletBinding()]
param(
    [string]$Python = "python",
    [string]$Godot = (
        "C:\Users\Cole\CodeStuff\Misc\Godot\" +
        "Godot_v4.7-stable_mono_win64_console.exe"
    )
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$sdkRoot = Join-Path $repoRoot "sdk"
$contractPath = Join-Path $sdkRoot "turning\r23d2_development_contract_v1.json"
$freezePath = Join-Path $sdkRoot "turning\r23d2_physical_freeze_v1.json"
$evaluatorPath = Join-Path $sdkRoot "turning\r23d2_development.py"
$evaluatorTestPath = Join-Path $sdkRoot "turning\test_r23d2_development.py"
$evaluatorGatePath = Join-Path $sdkRoot "run_qsdk_r23d2_development_preflight.ps1"
$supervisorPath = Join-Path $sdkRoot "run_qsdk_r23d2_supervisor.ps1"
$conformancePath = Join-Path $sdkRoot "run_conformance.ps1"
$runtimeMaterializationPath = Join-Path `
    $sdkRoot `
    "r23d2_reproducible_runtime_materialization.ps1"

function Assert-R23D2SupervisorAudit {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

foreach ($path in @(
    $contractPath, $freezePath, $evaluatorPath, $evaluatorTestPath, $evaluatorGatePath,
    $supervisorPath, $conformancePath, $runtimeMaterializationPath
)) {
    Assert-R23D2SupervisorAudit (Test-Path -LiteralPath $path -PathType Leaf) (
        "QSDK-R23D2 supervisor audit input is missing: $path"
    )
}

$contract = Get-Content -Raw -LiteralPath $contractPath |
    ConvertFrom-Json -AsHashtable -Depth 100
$freeze = Get-Content -Raw -LiteralPath $freezePath |
    ConvertFrom-Json -AsHashtable -Depth 100
$supervisorSource = Get-Content -Raw -LiteralPath $supervisorPath
$conformanceSource = Get-Content -Raw -LiteralPath $conformancePath
$evaluatorSource = Get-Content -Raw -LiteralPath $evaluatorPath
Assert-R23D2SupervisorAudit (
    [string]$contract.schema_version -ceq
        "sporespore_qsdk_r23d2_development_contract_v1" -and
    [string]$contract.status -ceq
        "frozen_supervisor_only_physical_authorized_pending_exact_source_attestation" -and
    [string]$contract.aggregate_supervisor.supervisor_path -ceq
        "sdk/run_qsdk_r23d2_supervisor.ps1" -and
    [string]$contract.aggregate_supervisor.audit_path -ceq
        "tests/test_qsdk_r23d2_supervisor.ps1" -and
    [string]$contract.aggregate_supervisor.freeze_path -ceq
        "sdk/turning/r23d2_physical_freeze_v1.json" -and
    [bool]$contract.aggregate_supervisor.cargo_target_root_remapped_to_constant_virtual_prefix_required -and
    [bool]$contract.aggregate_supervisor.serial_one_shot_required -and
    [bool]$contract.aggregate_supervisor.content_addressed_retention_before_consumption_required -and
    [bool]$contract.aggregate_supervisor.serial_worker_gate_execution_required -and
    [bool]$contract.aggregate_supervisor.synthetic_cell_entries_content_addressed_before_aggregation -and
    [bool]$contract.aggregate_supervisor.physical_mode_without_complete_authority_must_refuse_before_world -and
    [bool]$contract.authorization.physical_execution_authorized -and
    [int]$contract.authorization.physical_process_launch_count -eq 0 -and
    [int]$contract.authorization.world_attempt_count -eq 0 -and
    [int]$contract.authorization.world_build_count -eq 0 -and
    [int]$contract.claim_boundary.physical_worker_implementation_count -eq 3 -and
    [bool]$contract.claim_boundary.physical_workers_complete -and
    -not [bool]$contract.claim_boundary.command_conditioned_turning -and
    -not [bool]$contract.claim_boundary.cross_engine_equivalence -and
    -not [bool]$contract.claim_boundary.q_sdk_r23_satisfied -and
    -not [bool]$contract.claim_boundary.physical_acceptance_authority
) "QSDK-R23D2 supervisor contract or authorization boundary changed"

Assert-R23D2SupervisorAudit (
    [string]$freeze.schema_version -ceq
        "sporespore_qsdk_r23d2_physical_freeze_v1" -and
    [string]$freeze.status -ceq "frozen_supervisor_only_physical_authorized" -and
    [string]$freeze.campaign_id -ceq [string]$contract.campaign_id -and
    [string]$freeze.gate_id -ceq [string]$contract.gate_id -and
    [int]$freeze.declared_cell_count -eq 9 -and
    (@($freeze.ordered_cell_ids) -join "|") -ceq (
        "godot_jolt__reference_zero|godot_jolt__positive_heading|" +
        "godot_jolt__negative_heading|rapier_parry__reference_zero|" +
        "rapier_parry__positive_heading|rapier_parry__negative_heading|" +
        "mujoco__reference_zero|mujoco__positive_heading|mujoco__negative_heading"
    ) -and
    [int]$freeze.declared_source_binding_count -eq @($freeze.source_bindings).Count -and
    @($freeze.source_bindings).Count -ge 24 -and
    @($freeze.external_runtime_bindings).Count -ge 14 -and
    @($freeze.attempt_runtime_artifacts).Count -ge 17 -and
    [bool]$freeze.serial_one_shot_required -and
    [bool]$freeze.content_addressed_terminal_retention_required -and
    [bool]$freeze.attempt_runtime_artifacts_revalidated_after_zero_world_gates_required -and
    [bool]$freeze.attempt_runtime_artifacts_materialized_by_pinned_reproducible_recipe_before_validation_required -and
    [bool]$freeze.cargo_target_root_remapped_to_constant_virtual_prefix_required -and
    [bool]$freeze.exact_full_godot_v2_attestation_required -and
    [bool]$freeze.physical_execution_authorized -and
    -not [bool]$freeze.replacement_or_selective_rerun_permitted -and
    -not [bool]$freeze.physical_acceptance_authority
) "QSDK-R23D2 physical freeze shape changed"
foreach ($binding in @($freeze.source_bindings)) {
    $path = Join-Path $repoRoot ([string]$binding.path)
    Assert-R23D2SupervisorAudit (Test-Path -LiteralPath $path -PathType Leaf) (
        "QSDK-R23D2 bound source missing: $([string]$binding.path)"
    )
    $sha256 = "sha256:" + (
        Get-FileHash -LiteralPath $path -Algorithm SHA256
    ).Hash.ToLowerInvariant()
    Assert-R23D2SupervisorAudit (
        [string]$binding.raw_sha256 -ceq $sha256
    ) "QSDK-R23D2 bound source changed: $([string]$binding.path)"
}

$cargoEnvironmentNames = @(
    "CARGO_INCREMENTAL",
    "SOURCE_DATE_EPOCH",
    "CARGO_ENCODED_RUSTFLAGS",
    "RUSTFLAGS",
    "CARGO_TARGET_DIR"
)
$processEnvironmentBefore = [Environment]::GetEnvironmentVariables(
    [EnvironmentVariableTarget]::Process
)
$cargoEnvironmentBefore = @{}
foreach ($name in $cargoEnvironmentNames) {
    $cargoEnvironmentBefore[$name] = [ordered]@{
        existed = $processEnvironmentBefore.Contains($name)
        value = [Environment]::GetEnvironmentVariable(
            $name,
            [EnvironmentVariableTarget]::Process
        )
    }
}
. $runtimeMaterializationPath
$environmentProbe = Invoke-SporeSporeR23D2PinnedCargo `
    -RepoRoot $repoRoot `
    -TargetRoot (Join-Path $sdkRoot "target\r23d2-environment-probe") `
    -CargoArguments @("--version")
Assert-R23D2SupervisorAudit (
    [int]$environmentProbe.exit_code -eq 0 -and
    [int]$environmentProbe.remapped_path_count -eq 4 -and
    [bool]$environmentProbe.cargo_target_root_remapped_to_constant_virtual_prefix
) "QSDK-R23D2 reproducible Cargo environment probe failed"
$processEnvironmentAfter = [Environment]::GetEnvironmentVariables(
    [EnvironmentVariableTarget]::Process
)
foreach ($name in $cargoEnvironmentNames) {
    $afterExists = $processEnvironmentAfter.Contains($name)
    $afterValue = [Environment]::GetEnvironmentVariable(
        $name,
        [EnvironmentVariableTarget]::Process
    )
    Assert-R23D2SupervisorAudit (
        $afterExists -eq [bool]$cargoEnvironmentBefore[$name].existed -and
        (
            -not $afterExists -or
            $afterValue -ceq [string]$cargoEnvironmentBefore[$name].value
        )
    ) "QSDK-R23D2 pinned Cargo leaked process environment: $name"
}

foreach ($requiredSurface in @(
    "Test-SporeSporeFullConformanceAttestationFile",
    "Enter-SporeSporeLocomotionOperationLock",
    "Publish-R23D2InputArtifacts",
    "Assert-R23D2FrozenBindings",
    "Initialize-SporeSporeR23D2AttemptRuntimeArtifacts",
    "Invoke-R23D2PhysicalCell",
    "Invoke-R23D2PhysicalCampaign",
    "sporespore_qsdk_r23d2_supervisor_process_failure_v1",
    "ordered_terminal_entry_cas",
    "invalid_or_incomplete_first_attempt",
    "one_shot_identity_consumed",
    "same_identity_rerun_allowed"
)) {
    Assert-R23D2SupervisorAudit (
        $supervisorSource.Contains($requiredSurface, [StringComparison]::Ordinal)
    ) "QSDK-R23D2 supervisor is missing '$requiredSurface'"
}

$postGateRuntimeCheckIndex = $supervisorSource.IndexOf(
    "# The gates are allowed to compile",
    [StringComparison]::Ordinal
)
$inputPublishIndex = $supervisorSource.IndexOf(
    '$inputCas = Publish-R23D2InputArtifacts',
    [StringComparison]::Ordinal
)
Assert-R23D2SupervisorAudit (
    $postGateRuntimeCheckIndex -ge 0 -and
    $inputPublishIndex -gt $postGateRuntimeCheckIndex
) "QSDK-R23D2 runtime artifacts are not revalidated after gates and before CAS"
$runtimeMaterializationIndex = $supervisorSource.IndexOf(
    '$runtimeMaterialization = Initialize-SporeSporeR23D2AttemptRuntimeArtifacts',
    [StringComparison]::Ordinal
)
$runtimeHelperPrehashIndex = $supervisorSource.IndexOf(
    'QSDK-R23D2 reproducible runtime helper changed before import',
    [StringComparison]::Ordinal
)
$runtimeHelperImportIndex = $supervisorSource.IndexOf(
    '. $reproducibleRuntimePath',
    [StringComparison]::Ordinal
)
$initialFrozenBindingMatches = [regex]::Matches(
    $supervisorSource,
    '(?m)^Assert-R23D2FrozenBindings\r?$'
)
$initialFrozenBindingIndex = if ($initialFrozenBindingMatches.Count -eq 1) {
    $initialFrozenBindingMatches[0].Index
} else {
    -1
}
Assert-R23D2SupervisorAudit (
    $runtimeHelperPrehashIndex -ge 0 -and
    $runtimeHelperImportIndex -gt $runtimeHelperPrehashIndex -and
    $runtimeMaterializationIndex -gt $runtimeHelperImportIndex -and
    $initialFrozenBindingIndex -gt $runtimeMaterializationIndex
) "QSDK-R23D2 runtime helper trust or materialization order changed"
$developerExperienceIndex = $conformanceSource.LastIndexOf(
    'run_developer_experience_conformance.ps1',
    [StringComparison]::Ordinal
)
$finalSupervisorIndex = $conformanceSource.IndexOf(
    'QSDK-R23D2 final supervisor audit failed',
    [StringComparison]::Ordinal
)
$attestationPublicationIndex = $conformanceSource.LastIndexOf(
    'if (-not [string]::IsNullOrWhiteSpace($DurableAttestationOutput))',
    [StringComparison]::Ordinal
)
$conformanceSupervisorInvocationCount = [regex]::Matches(
    $conformanceSource,
    [regex]::Escape('tests\test_qsdk_r23d2_supervisor.ps1')
).Count
Assert-R23D2SupervisorAudit (
    $developerExperienceIndex -ge 0 -and
    $finalSupervisorIndex -gt $developerExperienceIndex -and
    $attestationPublicationIndex -gt $finalSupervisorIndex -and
    $conformanceSupervisorInvocationCount -eq 1
) "QSDK-R23D2 is not the final full-Godot consumer-building gate"
$logCasIndex = $supervisorSource.IndexOf(
    '$logCas = Publish-SporeSporeContentAddressedArtifact',
    [StringComparison]::Ordinal
)
$terminalWriteIndex = $supervisorSource.IndexOf(
    '$terminalPath = Join-Path $CellRoot "terminal-entry.json"',
    [StringComparison]::Ordinal
)
$attemptCasIndex = $supervisorSource.IndexOf(
    '$attemptCas = Publish-SporeSporeContentAddressedArtifact',
    [StringComparison]::Ordinal
)
$cellLoopIndex = $supervisorSource.IndexOf(
    'foreach ($cellId in $orderedCellIds)',
    [StringComparison]::Ordinal
)
Assert-R23D2SupervisorAudit (
    $logCasIndex -ge 0 -and $terminalWriteIndex -gt $logCasIndex -and
    $attemptCasIndex -ge 0 -and $cellLoopIndex -gt $attemptCasIndex
) "QSDK-R23D2 retention-before-consumption order changed"

foreach ($forbidden in @(
    "run_qsdk_r23d1_supervisor.ps1",
    "physical_development.py",
    "res://tests/test_sdk_qsdk_r23d1_godot_jolt_worker.gd",
    "qsdk_r23d1_heading_response"
)) {
    Assert-R23D2SupervisorAudit (
        -not $supervisorSource.Contains($forbidden, [StringComparison]::Ordinal)
    ) "QSDK-R23D2 supervisor contains forbidden closed or physical surface '$forbidden'"
}
$closedEvaluatorName = "physical" + "_development"
Assert-R23D2SupervisorAudit (
    $evaluatorSource -cnotmatch "from\s+\.?$closedEvaluatorName\s+import" -and
    $evaluatorSource -cnotmatch "import\s+$closedEvaluatorName(?:\s|$)" -and
    $evaluatorSource.Contains(
        "from . import r23d2_oracle", [StringComparison]::Ordinal
    ) -and
    $evaluatorSource.Contains(
        '"valid_negative"', [StringComparison]::Ordinal
    ) -and
    $evaluatorSource.Contains(
        '"invalid_or_incomplete"', [StringComparison]::Ordinal
    ) -and
    $evaluatorSource.Contains(
        'sum(item["world_attempt_count"] for item in evaluations)',
        [StringComparison]::Ordinal
    ) -and
    $evaluatorSource.Contains(
        'sum(item["world_build_count"] for item in evaluations)',
        [StringComparison]::Ordinal
    )
) "QSDK-R23D2 evaluator independence or classification surface changed"

$output = & pwsh -NoLogo -NoProfile -File $supervisorPath `
    -PreflightOnly -Python $Python -Godot $Godot 2>&1
$exitCode = $LASTEXITCODE
$output | ForEach-Object { Write-Host $_ }
Assert-R23D2SupervisorAudit ($exitCode -eq 0) (
    "QSDK-R23D2 supervisor preflight failed with exit code $exitCode"
)
$prefix = "QSDK_R23D2_SUPERVISOR_PREFLIGHT "
$markers = @($output | Where-Object {
    ([string]$_).StartsWith($prefix, [StringComparison]::Ordinal)
})
Assert-R23D2SupervisorAudit ($markers.Count -eq 1) (
    "QSDK-R23D2 supervisor emitted $($markers.Count) normalized markers"
)
$receipt = ([string]$markers[0]).Substring($prefix.Length) |
    ConvertFrom-Json -AsHashtable -Depth 100
Assert-R23D2SupervisorAudit (
    [string]$receipt.schema_version -ceq
        "sporespore_qsdk_r23d2_supervisor_preflight_v1" -and
    [int]$receipt.stage_zero_oracle_gate_pass_count -eq 1 -and
    [int]$receipt.shared_evaluator_gate_pass_count -eq 1 -and
    [int]$receipt.worker_gate_count -eq 3 -and
    [int]$receipt.worker_entrypoint_count -eq 9 -and
    [int]$receipt.physical_worker_implementation_count -eq 3 -and
    [int]$receipt.retained_test_cas_report_count -eq 9 -and
    [int]$receipt.retained_test_cas_failure_count -eq 3 -and
    [int]$receipt.synthetic_positive_aggregate_pass_count -eq 1 -and
    [int]$receipt.synthetic_valid_negative_aggregate_count -eq 1 -and
    [int]$receipt.aggregate_negative_control_rejection_count -eq 4 -and
    [int]$receipt.stage_aggregate_control_pass_count -eq 3 -and
    [int]$receipt.physical_authorization_refusal_count -eq 1 -and
    [int]$receipt.synthetic_projected_world_attempt_count -eq 9 -and
    [int]$receipt.synthetic_projected_world_build_count -eq 9 -and
    [int]$receipt.actual_physical_process_launch_count -eq 0 -and
    [int]$receipt.actual_world_attempt_count -eq 0 -and
    [int]$receipt.actual_world_build_count -eq 0 -and
    -not [bool]$receipt.locomotion_outcome_exposed -and
    [bool]$receipt.physical_execution_authorized -and
    -not [bool]$receipt.q_sdk_r23_satisfied -and
    -not [bool]$receipt.command_conditioned_turning -and
    -not [bool]$receipt.cross_engine_equivalence -and
    -not [bool]$receipt.release_authorized -and
    -not [bool]$receipt.physical_acceptance_authority
) "QSDK-R23D2 supervisor normalized receipt changed"

Write-Host (
    "QSDK_R23D2_SUPERVISOR_AUDIT_PASS workers=3 entrypoints=9 reports=9 " +
    "failure_receipts=3 aggregate=1/1 valid_negative=1/1 " +
    "negative_controls=4/4 stage_counts=3/3 physical_refusal=1 " +
    "physical_workers=3/3 worlds=0 physical_authority=False"
)
