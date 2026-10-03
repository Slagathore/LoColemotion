#requires -Version 7.0

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$supervisor = Join-Path $repoRoot "sdk\run_qsdk_r23d25_supervisor.ps1"
$worker = Join-Path $repoRoot (
    "sdk\adapters\mujoco\sporespore_mujoco_adapter\qsdk_r23d25_physical.py"
)
$preregistration = Join-Path $repoRoot (
    "sdk\turning\r23d25_mujoco_terminal_zero_forward_preregistration_v1.json"
)
$implementation = Join-Path $repoRoot (
    "sdk\turning\r23d25_mujoco_terminal_zero_forward_implementation_v1.json"
)
$closure = Join-Path $repoRoot (
    "sdk\turning\r23d25_mujoco_terminal_zero_forward_closure_v1.json"
)

function Assert-R23D25Test([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "QSDK-R23D25 test: $Message" }
}

Assert-R23D25Test (
    (git -C $repoRoot rev-parse --show-toplevel).Trim().Replace("/", "\") -ceq
        $repoRoot -and
    (git -C $repoRoot remote get-url origin).Trim() -ceq
        "https://github.com/Slagathore/sporespore.git"
) "repository identity changed"
foreach ($path in @($supervisor, $worker, $preregistration, $implementation)) {
    Assert-R23D25Test (Test-Path -LiteralPath $path -PathType Leaf) (
        "missing source: $path"
    )
}
$closed = Test-Path -LiteralPath $closure -PathType Leaf
if ($closed) {
    $closureRecord = Get-Content -Raw -LiteralPath $closure |
        ConvertFrom-Json -AsHashtable -Depth 100
    Assert-R23D25Test (
        [string]$closureRecord.campaign_id -ceq
            "QSDK-R23D25-MUJOCO-TERMINAL-ZERO-FORWARD" -and
        [bool]$closureRecord.attempt.single_use_identity_consumed -and
        -not [bool]$closureRecord.attempt.same_identity_rerun_allowed
    ) "closed identity record changed"
}

$declaration = Get-Content -Raw -LiteralPath $preregistration |
    ConvertFrom-Json -AsHashtable -Depth 100
$contract = Get-Content -Raw -LiteralPath $implementation |
    ConvertFrom-Json -AsHashtable -Depth 100
$workerText = Get-Content -Raw -LiteralPath $worker
Assert-R23D25Test (
    [string]$declaration.gate_id -ceq "QSDK-R23D25" -and
    [string]$declaration.study_classification -ceq
        "prospective_exact_finite_mujoco_terminal_command_semantic_successor" -and
    [int]$declaration.prospective_matrix.declared_new_world_count -eq 3 -and
    @($declaration.prospective_matrix.ordered_engine_ids).Count -eq 1 -and
    [string]$declaration.prospective_matrix.ordered_engine_ids[0] -ceq "mujoco" -and
    [bool]$declaration.terminal_zero_forward_repair.terminal_command_semantics_changed -and
    -not [bool]$declaration.terminal_zero_forward_repair.physics_semantics_changed -and
    -not [bool]$declaration.terminal_zero_forward_repair.threshold_or_horizon_changed -and
    [double]$declaration.terminal_zero_forward_repair.predecessor_terminal_desired_forward_velocity_m_s -eq 0.2 -and
    [double]$declaration.terminal_zero_forward_repair.successor_terminal_desired_forward_velocity_m_s -eq 0.0 -and
    -not [bool]$declaration.terminal_zero_forward_repair.threshold_change_authorized -and
    [string]$contract.receipt_contract_id -ceq
        "r23d21_forward_velocity_foot_placement_receipt_v2" -and
    [int]$contract.declared_world_count -eq 3 -and
    $workerText.Contains(
        'kwargs["source_forward_velocity_contract_id"] = SOURCE_CONTRACT_ID'
    ) -and
    $workerText.Contains('desired["x"] = TERMINAL_DESIRED_FORWARD_VELOCITY_M_S') -and
    $workerText.Contains("_validate_terminal_zero_forward_receipt") -and
    $workerText.Contains("repair.run_zero_world_preflight()") -and
    $workerText.Contains('receipt_preflight.get("mutation_control_count") != 22') -and
    $workerText.Contains('zero_forward_preflight.get("mutation_control_count") != 4')
) "prospective implementation identity changed"

$output = & pwsh -NoLogo -NoProfile -File $supervisor -PreflightOnly 2>&1 |
    Out-String
Assert-R23D25Test (
    $LASTEXITCODE -eq 0 -and
    $output.Contains(
        "QSDK_R23D25_ZERO_WORLD_PASS workers=3 mutations=26 models=0 worlds=0 physical=False"
    )
) "complete zero-world supervisor preflight failed: $output"

Write-Host (
    "QSDK_R23D25_IMPLEMENTATION_PASS cells=3 workers=3 mutations=26 " +
    "models=0 worlds=0 physical=False three_engine=False equivalence=False"
)
