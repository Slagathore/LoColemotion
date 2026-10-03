#requires -Version 7.0

[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$sdkRoot = Join-Path $repoRoot "sdk"
$contractPath = Join-Path $sdkRoot "turning\r23d3_implementation_contract_v1.json"
$supervisorPath = Join-Path $sdkRoot "run_qsdk_r23d3_supervisor.ps1"
$runtimePath = Join-Path $sdkRoot "r23d3_reproducible_runtime_materialization.ps1"
$evaluatorPath = Join-Path $sdkRoot "turning\r23d3_physical_evaluator.py"
$tracePublisherPath = Join-Path $sdkRoot "publish_qsdk_r23d3_trace.ps1"
$godotWorkerPath = Join-Path $repoRoot "tests\test_sdk_qsdk_r23d3_godot_jolt_worker.gd"
$godotRunnerPath = Join-Path $repoRoot "scripts\lab\gait\physical_wave_gait_quadruped.gd"
$rapierWorkerPath = Join-Path $sdkRoot "adapters\rapier\src\qsdk_r23d3_phase_balanced.rs"
$mujocoWorkerPath = Join-Path $sdkRoot (
    "adapters\mujoco\sporespore_mujoco_adapter\qsdk_r23d3_phase_balanced.py"
)
$campaignId = "QSDK-R23D3-PHASE-BALANCED-BILATERAL-TURN-DEVELOPMENT"
$gateId = "QSDK-R23D3"

function Assert-R23D3Implementation {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function Get-R23D3ImplementationRawSha256 {
    param([Parameter(Mandatory)][string]$Path)
    return "sha256:" + (
        Get-FileHash -LiteralPath $Path -Algorithm SHA256
    ).Hash.ToLowerInvariant()
}

function Get-R23D3ImplementationGit {
    param([Parameter(Mandatory)][string[]]$Arguments)
    $lines = @(& git -C $repoRoot @Arguments 2>&1)
    Assert-R23D3Implementation ($LASTEXITCODE -eq 0) (
        "QSDK-R23D3 implementation audit git failure: " + ($lines -join " ")
    )
    return ($lines -join "`n").Trim()
}

Assert-R23D3Implementation (
    (Get-R23D3ImplementationGit @("rev-parse", "--show-toplevel")).Replace("/", "\") `
        -ceq $repoRoot -and
    (Get-R23D3ImplementationGit @("remote", "get-url", "origin")) -ceq
        "https://github.com/Slagathore/sporespore.git"
) "QSDK-R23D3 implementation audit repository identity mismatch"

foreach ($path in @(
    $contractPath, $supervisorPath, $runtimePath, $evaluatorPath,
    $tracePublisherPath, $godotWorkerPath, $godotRunnerPath,
    $rapierWorkerPath, $mujocoWorkerPath
)) {
    Assert-R23D3Implementation (Test-Path -LiteralPath $path -PathType Leaf) (
        "QSDK-R23D3 implementation input is missing: $path"
    )
}

$contract = Get-Content -Raw -LiteralPath $contractPath |
    ConvertFrom-Json -AsHashtable -Depth 100
Assert-R23D3Implementation (
    [string]$contract.schema_version -ceq
        "sporespore_qsdk_r23d3_implementation_contract_v1" -and
    [string]$contract.status -ceq
        "implementation_complete_physical_unauthorized_pending_clean_pushed_freeze" -and
    [string]$contract.campaign_id -ceq $campaignId -and
    [string]$contract.gate_id -ceq $gateId -and
    [int]$contract.workers.Count -eq 3 -and
    [bool]$contract.production_evaluator.recomputes_complete_trace_contract -and
    [bool]$contract.production_evaluator.recomputes_every_execution_and_outcome_gate -and
    -not [bool]$contract.production_evaluator.worker_authored_outcome_bits_authoritative -and
    [int]$contract.trace_retention.rows_per_complete_cell -eq 2992 -and
    [int]$contract.trace_retention.projected_trace_rows_if_stage_b_launches -eq 50864 -and
    [bool]$contract.trace_retention.content_addressed_before_terminal_entry_required -and
    [int]$contract.supervisor.stage_a_world_count -eq 8 -and
    [int]$contract.supervisor.stage_b_world_count_if_launched -eq 9 -and
    [bool]$contract.supervisor.stage_a_serial_without_outcome_early_stop -and
    [bool]$contract.supervisor.stage_b_serial_without_outcome_early_stop -and
    [bool]$contract.supervisor.stage_a_reports_may_substitute_for_stage_b_mujoco_reports -eq $false -and
    [bool]$contract.supervisor.stage_a_and_conditional_stage_b_share_one_attempt_id -and
    [bool]$contract.supervisor.stage_a_authorization_is_never_mutated_to_open_stage_b -and
    [bool]$contract.supervisor.source_binding_path_composer_exercised_in_preflight -and
    [bool]$contract.runtime_freeze_recipe.generated_only_after_clean_pushed_live_source_equality -and
    [bool]$contract.runtime_freeze_recipe.content_addressed_before_attempt_or_world -and
    [bool]$contract.runtime_freeze_recipe.source_bindings_must_equal_git_blob_bytes -and
    [bool]$contract.runtime_freeze_recipe.msvc_brepro_required -and
    [bool]$contract.runtime_freeze_recipe.pdb_alt_path_bare_name_required -and
    [bool]$contract.runtime_freeze_recipe.cargo_incremental_disabled -and
    -not [bool]$contract.runtime_freeze_recipe.codegen_units_forced -and
    -not [bool]$contract.authorization.physical_execution_authorized -and
    [int]$contract.authorization.world_attempt_count -eq 0 -and
    [int]$contract.authorization.world_build_count -eq 0 -and
    -not [bool]$contract.claims.portable_basic_turning -and
    -not [bool]$contract.claims.cross_engine_equivalence -and
    -not [bool]$contract.claims.release_authorized
) "QSDK-R23D3 implementation contract changed"

$allBindings = [Collections.Generic.List[string]]::new()
foreach ($pathValue in @($contract.source_binding_policy.exact_paths)) {
    $path = ([string]$pathValue).Replace("\", "/")
    Assert-R23D3Implementation (
        Test-Path -LiteralPath (Join-Path $repoRoot $path) -PathType Leaf
    ) "QSDK-R23D3 exact source binding is missing: $path"
    $attributes = @(& git -C $repoRoot check-attr text eol -- $path)
    Assert-R23D3Implementation (
        $LASTEXITCODE -eq 0 -and
        @($attributes | Where-Object { $_ -ceq "$path`: text: set" }).Count -eq 1 -and
        @($attributes | Where-Object { $_ -ceq "$path`: eol: lf" }).Count -eq 1
    ) "QSDK-R23D3 exact source binding is not deterministically LF: $path"
    $allBindings.Add($path)
}
$prefixFileCount = 0
foreach ($prefixValue in @($contract.source_binding_policy.tracked_prefixes)) {
    $prefix = [string]$prefixValue
    $expanded = @((Get-R23D3ImplementationGit @("ls-files", "--", $prefix)) -split "`n" |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    Assert-R23D3Implementation ($expanded.Count -gt 0) (
        "QSDK-R23D3 tracked source prefix is empty: $prefix"
    )
    $prefixFileCount += $expanded.Count
    foreach ($pathValue in $expanded) {
        $path = $pathValue.Replace("\", "/")
        $attributes = @(& git -C $repoRoot check-attr text eol -- $path)
        Assert-R23D3Implementation (
            $LASTEXITCODE -eq 0 -and
            @($attributes | Where-Object { $_ -ceq "$path`: text: set" }).Count -eq 1 -and
            @($attributes | Where-Object { $_ -ceq "$path`: eol: lf" }).Count -eq 1
        ) "QSDK-R23D3 prefix source binding is not deterministically LF: $path"
        $allBindings.Add($path)
    }
}
Assert-R23D3Implementation (
    @($allBindings | Group-Object | Where-Object Count -gt 1).Count -eq 0
) "QSDK-R23D3 source binding declarations overlap"

$supervisor = [IO.File]::ReadAllText($supervisorPath)
$runtime = [IO.File]::ReadAllText($runtimePath)
$evaluator = [IO.File]::ReadAllText($evaluatorPath)
$publisher = [IO.File]::ReadAllText($tracePublisherPath)
$godotWorker = [IO.File]::ReadAllText($godotWorkerPath)
$godotRunner = [IO.File]::ReadAllText($godotRunnerPath)
$rapierWorker = [IO.File]::ReadAllText($rapierWorkerPath)
$mujocoWorker = [IO.File]::ReadAllText($mujocoWorkerPath)

$stageAAuthorizationIndex = $supervisor.IndexOf(
    '"stage-a-authorization.json"', [StringComparison]::Ordinal
)
$stageALoopIndex = $supervisor.IndexOf(
    'foreach ($cellId in $stageACellIds)', [StringComparison]::Ordinal
)
$stageAEvaluationIndex = $supervisor.IndexOf(
    '-Kind "stage-a"', [StringComparison]::Ordinal
)
$stageBGuardIndex = $supervisor.IndexOf(
    'stage_b_launch_authorized', [StringComparison]::Ordinal
)
$stageBAuthorizationIndex = $supervisor.IndexOf(
    '"stage-b-authorization.json"', [StringComparison]::Ordinal
)
$stageBLoopIndex = $supervisor.IndexOf(
    'foreach ($cellId in $stageBCellIds)', [StringComparison]::Ordinal
)
Assert-R23D3Implementation (
    $stageAAuthorizationIndex -ge 0 -and
    $stageALoopIndex -gt $stageAAuthorizationIndex -and
    $stageAEvaluationIndex -gt $stageALoopIndex -and
    $stageBGuardIndex -gt $stageAEvaluationIndex -and
    $stageBAuthorizationIndex -gt $stageBGuardIndex -and
    $stageBLoopIndex -gt $stageBAuthorizationIndex -and
    $supervisor.Contains('Initialize-SporeSporeR23D3AttemptRuntimeArtifacts') -and
    $supervisor.Contains('Get-SporeSporeAttestationSourceIdentity') -and
    $supervisor.Contains('Enter-SporeSporeLocomotionOperationLock') -and
    $supervisor.Contains('Get-R23D3SourceBindingPaths $implementation') -and
    $supervisor.Contains('hash-object", "--no-filters"') -and
    $supervisor.Contains('stage_a_reports_may_substitute_for_stage_b = $false') -and
    -not $supervisor.Contains('Invoke-SporeSporeR23D2')
) "QSDK-R23D3 supervisor ordering or source-bound authorization is incomplete"

Assert-R23D3Implementation (
    $runtime.Contains('"--locked", "--offline"') -and
    $runtime.Contains('CARGO_INCREMENTAL = "0"') -and
    $runtime.Contains('SOURCE_DATE_EPOCH') -and
    $runtime.Contains('"-Clink-arg=/Brepro"') -and
    $runtime.Contains('"-Clink-arg=/PDBALTPATH:%_PDB%"') -and
    $runtime.Contains('--remap-path-prefix=$resolvedTargetRoot=/sporespore-target') -and
    $runtime.Contains('codegen_units_forced = $false')
) "QSDK-R23D3 reproducible runtime recipe changed"

$workerChecks = @(
    [ordered]@{ name = "mujoco"; text = $mujocoWorker },
    [ordered]@{ name = "rapier"; text = $rapierWorker },
    [ordered]@{ name = "godot"; text = $godotWorker }
)
foreach ($worker in $workerChecks) {
    Assert-R23D3Implementation (
        $worker.text.Contains('SPORESPORE_QSDK_R23D3_FREEZE') -and
        $worker.text.Contains('SPORESPORE_QSDK_R23D3_ATTEMPT') -and
        $worker.text.Contains('SPORESPORE_QSDK_R23D3_ATTEMPT_ROOT') -and
        $worker.text.Contains('frozen_supervisor_only_physical_authorized') -and
        $worker.text.Contains('one_shot_attempt_unconsumed') -and
        $worker.text.Contains('trace')
    ) "QSDK-R23D3 $($worker.name) worker authorization or trace surface is incomplete"
}
Assert-R23D3Implementation (
    $godotRunner.Contains('QSDK_R23D3_AUTHORITY_HORIZON_OBSERVATION_COUNT := 2992') -and
    $godotRunner.Contains('_compose_sdk_physical_trace_row(') -and
    $godotWorker.IndexOf('var retention := _retain_trace(', [StringComparison]::Ordinal) -lt
        $godotWorker.IndexOf('"schema_version": REPORT_SCHEMA,', [StringComparison]::Ordinal) -and
    $mujocoWorker.IndexOf('_retain_trace(', [StringComparison]::Ordinal) -lt
        $mujocoWorker.IndexOf('"schema_version": REPORT_SCHEMA,', [StringComparison]::Ordinal) -and
    $rapierWorker.IndexOf('r23d3_retain_trace(', [StringComparison]::Ordinal) -lt
        $rapierWorker.LastIndexOf('"schema_version": R23D3_REPORT_SCHEMA,', [StringComparison]::Ordinal)
) "QSDK-R23D3 trace retention does not visibly precede terminal report creation"
Assert-R23D3Implementation (
    $evaluator.Contains('Worker-authored pass') -and
    $evaluator.Contains('def evaluate_stage_a_entries(') -and
    $evaluator.Contains('def evaluate_complete_entries(') -and
    $evaluator.Contains('R23D3_STAGE_B_OPENED_AFTER_VALID_NONE') -and
    $publisher.Contains('Publish-SporeSporeContentAddressedArtifact')
) "QSDK-R23D3 independent evaluator or CAS trace publisher is incomplete"

$preflightPaths = @(
    "sdk/run_qsdk_r23d3_mujoco_worker_preflight.ps1",
    "sdk/run_qsdk_r23d3_rapier_worker_preflight.ps1"
)
foreach ($relativePath in $preflightPaths) {
    $text = [IO.File]::ReadAllText((Join-Path $repoRoot $relativePath))
    Assert-R23D3Implementation (
        $text.Contains('r23d3_reproducible_runtime_materialization.ps1') -and
        $text.Contains('Invoke-SporeSporeR23D3PinnedCargo') -and
        -not $text.Contains('Invoke-SporeSporeR23D2PinnedCargo')
    ) "QSDK-R23D3 worker preflight uses a stale runtime recipe: $relativePath"
}

$parseCount = 0
foreach ($relativePath in @(
    "sdk/run_qsdk_r23d3_supervisor.ps1",
    "sdk/r23d3_reproducible_runtime_materialization.ps1",
    "sdk/publish_qsdk_r23d3_trace.ps1",
    "sdk/run_qsdk_r23d3_mujoco_worker_preflight.ps1",
    "sdk/run_qsdk_r23d3_rapier_worker_preflight.ps1",
    "sdk/run_qsdk_r23d3_godot_jolt_worker_preflight.ps1"
)) {
    $tokens = $null
    $errors = $null
    [void][Management.Automation.Language.Parser]::ParseFile(
        (Join-Path $repoRoot $relativePath), [ref]$tokens, [ref]$errors
    )
    Assert-R23D3Implementation ($errors.Count -eq 0) (
        "QSDK-R23D3 PowerShell parse failed: $relativePath"
    )
    $parseCount += 1
}

$receipt = [ordered]@{
    schema_version = "sporespore_qsdk_r23d3_implementation_audit_v1"
    campaign_id = $campaignId
    gate_id = $gateId
    implementation_contract_raw_sha256 = Get-R23D3ImplementationRawSha256 $contractPath
    exact_source_binding_count = @($contract.source_binding_policy.exact_paths).Count
    prefix_source_binding_count = $prefixFileCount
    total_declared_source_binding_count = $allBindings.Count
    worker_implementation_count = 3
    powershell_parse_count = $parseCount
    immutable_stage_authorization_count_if_stage_b_launches = 2
    trace_retention_before_terminal_entry_engine_count = 3
    stale_r23d2_runtime_recipe_reference_count = 0
    deterministic_lf_source_binding_count = $allBindings.Count
    physical_process_launch_count = 0
    world_attempt_count = 0
    world_build_count = 0
    physical_execution_authorized = $false
    physical_acceptance_authority = $false
}
Write-Host (
    "QSDK_R23D3_IMPLEMENTATION_AUDIT " +
    ($receipt | ConvertTo-Json -Depth 50 -Compress)
)
Write-Host (
    "QSDK_R23D3_IMPLEMENTATION_PASS workers=3 parsers=$parseCount " +
    "stage_authorizations=2 traces_before_terminal=3 stale_recipes=0 " +
    "worlds=0 physical_authority=False"
)
