#requires -Version 7.0

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$supervisor = Join-Path $repoRoot "sdk\run_qsdk_r23d24_supervisor.ps1"
$worker = Join-Path $repoRoot (
    "sdk\adapters\mujoco\sporespore_mujoco_adapter\qsdk_r23d24_physical.py"
)
$preregistration = Join-Path $repoRoot (
    "sdk\turning\r23d24_mujoco_receipt_recovery_preregistration_v1.json"
)
$implementation = Join-Path $repoRoot (
    "sdk\turning\r23d24_mujoco_receipt_recovery_implementation_v1.json"
)
$closure = Join-Path $repoRoot (
    "sdk\turning\r23d24_mujoco_receipt_recovery_closure_v1.json"
)

function Assert-R23D24Test([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "QSDK-R23D24 test: $Message" }
}

Assert-R23D24Test (
    (git -C $repoRoot rev-parse --show-toplevel).Trim().Replace("/", "\") -ceq
        $repoRoot -and
    (git -C $repoRoot remote get-url origin).Trim() -ceq
        "https://github.com/Slagathore/sporespore.git"
) "repository identity changed"
foreach ($path in @($supervisor, $worker, $preregistration, $implementation)) {
    Assert-R23D24Test (Test-Path -LiteralPath $path -PathType Leaf) (
        "missing source: $path"
    )
}
$closed = Test-Path -LiteralPath $closure -PathType Leaf
if ($closed) {
    $closureRecord = Get-Content -Raw -LiteralPath $closure |
        ConvertFrom-Json -AsHashtable -Depth 100
    Assert-R23D24Test (
        [string]$closureRecord.status -ceq
            "closed_consumed_valid_complete_negative_reference_post_handoff_contact_loss" -and
        [bool]$closureRecord.attempt.single_use_identity_consumed -and
        -not [bool]$closureRecord.attempt.same_identity_rerun_allowed
    ) "closed identity record changed"
}

$declaration = Get-Content -Raw -LiteralPath $preregistration |
    ConvertFrom-Json -AsHashtable -Depth 100
$contract = Get-Content -Raw -LiteralPath $implementation |
    ConvertFrom-Json -AsHashtable -Depth 100
$workerText = Get-Content -Raw -LiteralPath $worker
Assert-R23D24Test (
    [string]$declaration.gate_id -ceq "QSDK-R23D24" -and
    [string]$declaration.study_classification -ceq
        "prospective_exact_finite_mujoco_implementation_recovery" -and
    [int]$declaration.prospective_matrix.declared_new_world_count -eq 3 -and
    @($declaration.prospective_matrix.ordered_engine_ids).Count -eq 1 -and
    [string]$declaration.prospective_matrix.ordered_engine_ids[0] -ceq "mujoco" -and
    -not [bool]$declaration.receipt_recovery.controller_or_physics_semantics_changed -and
    -not [bool]$declaration.receipt_recovery.threshold_change_authorized -and
    [string]$contract.receipt_contract_id -ceq
        "r23d21_forward_velocity_foot_placement_receipt_v2" -and
    [int]$contract.declared_world_count -eq 3 -and
    $workerText.Contains(
        'kwargs["source_forward_velocity_contract_id"] = SOURCE_CONTRACT_ID'
    ) -and
    $workerText.Contains("repair.run_zero_world_preflight()") -and
    $workerText.Contains('receipt_preflight.get("mutation_control_count") != 22')
) "prospective implementation identity changed"

$output = & pwsh -NoLogo -NoProfile -File $supervisor -PreflightOnly 2>&1 |
    Out-String
Assert-R23D24Test (
    $LASTEXITCODE -eq 0 -and
    $output.Contains(
        "QSDK_R23D24_ZERO_WORLD_PASS workers=3 mutations=22 models=0 worlds=0 physical=False"
    )
) "complete zero-world supervisor preflight failed: $output"

Write-Host (
    "QSDK_R23D24_IMPLEMENTATION_PASS cells=3 workers=3 mutations=22 " +
    "models=0 worlds=0 physical=False three_engine=False equivalence=False"
)
