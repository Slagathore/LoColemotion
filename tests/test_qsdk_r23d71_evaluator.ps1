#requires -Version 7.0

[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
$PSNativeCommandUseErrorActionPreference = $false
$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$runtimePath = Join-Path $repoRoot (
    "sdk\turning\r23d71_production_route_runtime.py"
)
$evaluatorPath = Join-Path $repoRoot (
    "sdk\turning\r23d71_production_route_three_engine_turning_evaluator.py"
)

function Assert-R23D71Evaluator([bool]$Condition, [string]$Message) {
    if (-not $Condition) {
        throw "QSDK-R23D71 EVALUATOR: $Message"
    }
}

function Invoke-R23D71Git([string[]]$Arguments) {
    $lines = @(& git -C $repoRoot @Arguments 2>&1)
    Assert-R23D71Evaluator ($LASTEXITCODE -eq 0) (
        "git $($Arguments -join ' ') failed: $($lines -join ' ')"
    )
    return ($lines -join "`n").Trim()
}

Assert-R23D71Evaluator (
    (Invoke-R23D71Git @("rev-parse", "--show-toplevel")) -ceq
        $repoRoot.Replace("\", "/") -and
    (Invoke-R23D71Git @("remote", "get-url", "origin")) -ceq
        "https://github.com/Slagathore/sporespore.git" -and
    (Test-Path -LiteralPath $runtimePath -PathType Leaf) -and
    (Test-Path -LiteralPath $evaluatorPath -PathType Leaf)
) "repository identity or evaluator paths changed"

$python = (Get-Command python -ErrorAction Stop).Source
$output = @(& $python $evaluatorPath preflight 2>&1)
Assert-R23D71Evaluator ($LASTEXITCODE -eq 0) (
    "preflight failed: $($output -join ' ')"
)
$marker = "QSDK_R23D71_EVALUATOR_PREFLIGHT "
$markers = @($output | Where-Object { ([string]$_).StartsWith($marker) })
Assert-R23D71Evaluator ($markers.Count -eq 1) "preflight marker changed"
$receipt = ([string]$markers[0]).Substring($marker.Length) |
    ConvertFrom-Json -AsHashtable -Depth 100
$runtime = $receipt.runtime_projection
$controls = $receipt.complete_outcome_controls
Assert-R23D71Evaluator (
    [string]$receipt.schema_version -ceq
        "sporespore_qsdk_r23d71_evaluator_preflight_v1" -and
    [string]$receipt.gate_id -ceq "QSDK-R23D71" -and
    [string]$receipt.question_class -ceq "finite_decision" -and
    [int]$receipt.declared_cell_count -eq 9 -and
    [int]$receipt.engine_count -eq 3 -and
    [int]$receipt.valid_trace_canary_count -eq 9 -and
    [int]$receipt.observation_row_count_per_trace -eq 2992 -and
    [int]$receipt.observation_application_count_per_trace -eq 23936 -and
    [int]$receipt.turning_decision_mutation_rejection_count -eq 8 -and
    [int]$receipt.complete_matrix_order_mutation_rejection_count -eq 9 -and
    [int]$receipt.complete_failure_terminal_cell_canary_count -eq 9 -and
    [int]$controls.positive_control_count -eq 1 -and
    [int]$controls.negative_control_count -eq 1 -and
    [int]$controls.invalid_control_count -eq 1 -and
    [int]$controls.incomplete_control_count -eq 1 -and
    [int]$controls.control_count -eq 4 -and
    [int]$runtime.cell_count -eq 9 -and
    [int]$runtime.controller_step_count -eq 2992 -and
    [int]$runtime.segment_counts.reference_warmup -eq 600 -and
    [int]$runtime.segment_counts.commanded_turn -eq 1200 -and
    [int]$runtime.segment_counts.reference_recovery -eq 600 -and
    [int]$runtime.segment_counts.reference_continuation -eq 592 -and
    [int]$receipt.model_construction_count -eq 0 -and
    [int]$receipt.world_attempt_count -eq 0 -and
    [int]$receipt.world_build_count -eq 0 -and
    -not [bool]$receipt.physical_execution_authorized -and
    -not [bool]$receipt.physical_acceptance_authority -and
    -not [bool]$receipt.superiority_test_invoked -and
    -not [bool]$receipt.equivalence_or_non_inferiority_test_invoked -and
    -not [bool]$receipt.population_inference_attempted
) "preflight receipt changed"

Write-Output (
    "[turning/3e] PASS R23D71 accepted evaluator binding: " +
    "cells=9 rows=2992 outcome_controls=4 models=0 worlds=0"
)
