#requires -Version 7.0

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$turningRoot = Join-Path $repoRoot "sdk\turning"
$contractPath = Join-Path $turningRoot (
    "r23d10_stage_two_evidence_contract_v1.json"
)
$stageOneClosurePath = Join-Path $PSScriptRoot (
    "test_qsdk_r23d10_stage_one_closure.ps1"
)
$futurePaths = @(
    "sdk/turning/r23d10_physical_implementation_contract_v1.json",
    "sdk/turning/r23d10_dependency_closure.ps1",
    "sdk/turning/r23d10_terminal_marker_classifier.ps1",
    "sdk/run_qsdk_r23d10_authorization_canaries.ps1",
    "sdk/run_qsdk_r23d10_supervisor.ps1",
    "sdk/run_qsdk_r23d10_zero_world_gate.ps1"
)

function Assert-R23D10StageTwo([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

Assert-R23D10StageTwo (
    (git -C $repoRoot rev-parse --show-toplevel).Trim().Replace("/", "\") -ceq
        $repoRoot -and
    (git -C $repoRoot remote get-url origin).Trim() -ceq
        "https://github.com/Slagathore/sporespore.git"
) "QSDK-R23D10 stage-two repository identity mismatch"

$contract = Get-Content -Raw -LiteralPath $contractPath |
    ConvertFrom-Json -AsHashtable -Depth 100
$bindings = [Collections.Generic.List[object]]::new()
$bindings.Add([pscustomobject]@{
    path = [string]$contract.stage_one_boundary.historical_closure_audit_path
    hash = [string]$contract.stage_one_boundary.historical_closure_audit_raw_sha256
})
foreach ($sectionName in @(
    "production_trace_contract",
    "production_evaluator_contract"
)) {
    $section = $contract[$sectionName]
    foreach ($pair in @(
        @("implementation_path", "implementation_raw_sha256"),
        @("test_path", "test_raw_sha256")
    )) {
        $bindings.Add([pscustomobject]@{
            path = [string]$section[$pair[0]]
            hash = [string]$section[$pair[1]]
        })
    }
}
foreach ($pair in @(
    @("publisher_path", "publisher_raw_sha256"),
    @("store_path", "store_raw_sha256")
)) {
    $bindings.Add([pscustomobject]@{
        path = [string]$contract.content_addressed_retention[$pair[0]]
        hash = [string]$contract.content_addressed_retention[$pair[1]]
    })
}
Assert-R23D10StageTwo ($bindings.Count -eq 7) (
    "QSDK-R23D10 stage-two binding count changed"
)
foreach ($binding in $bindings) {
    $path = Join-Path $repoRoot ([string]$binding.path)
    Assert-R23D10StageTwo (Test-Path -LiteralPath $path -PathType Leaf) (
        "QSDK-R23D10 stage-two binding missing: $($binding.path)"
    )
    $digest = "sha256:" + (
        Get-FileHash -LiteralPath $path -Algorithm SHA256
    ).Hash.ToLowerInvariant()
    Assert-R23D10StageTwo ($digest -ceq [string]$binding.hash) (
        "QSDK-R23D10 stage-two binding changed: $($binding.path)"
    )
}
foreach ($futurePath in $futurePaths) {
    Assert-R23D10StageTwo (
        -not (Test-Path -LiteralPath (Join-Path $repoRoot $futurePath))
    ) "QSDK-R23D10 stage-two already contains future route: $futurePath"
}

Assert-R23D10StageTwo (
    [string]$contract.schema_version -ceq
        "sporespore_qsdk_r23d10_stage_two_evidence_contract_v1" -and
    [string]$contract.status -ceq
        "stage_two_zero_world_trace_retention_and_production_evaluator_complete_no_physical_workers_or_authorization" -and
    [string]$contract.stage_one_boundary.commit -ceq
        "60f475352fde6958798b4a0d7c21fb0dc354f87b" -and
    [int]$contract.production_trace_contract.complete_trace_rows_per_cell -eq 3892 -and
    [int]$contract.production_trace_contract.declared_trace_identity_count -eq 11 -and
    [int]$contract.production_trace_contract.trace_test_count -eq 5 -and
    [int]$contract.production_evaluator_contract.evaluator_test_count -eq 9 -and
    [int]$contract.production_evaluator_contract.actual_cli_subprocess_command_count -eq 2 -and
    [string]$contract.production_evaluator_contract.stage_a_success_marker -ceq
        "QSDK_R23D10_STAGE_A_EVALUATION " -and
    [string]$contract.production_evaluator_contract.complete_success_marker -ceq
        "QSDK_R23D10_COMPLETE_EVALUATION " -and
    [string]$contract.production_evaluator_contract.forbidden_generic_success_marker -ceq
        "QSDK_R23D10_EVALUATION " -and
    [bool]$contract.production_evaluator_contract.exact_expected_source_commit_required_by_both_evaluator_commands -and
    [bool]$contract.production_evaluator_contract.all_report_source_commits_must_match_expected_source_commit -and
    [bool]$contract.content_addressed_retention.attempt_trace_staging_uses_exclusive_creation -and
    [bool]$contract.content_addressed_retention.digest_derived_cas_path_shape_revalidated -and
    [bool]$contract.content_addressed_retention.trace_retention_required_before_terminal_entry -and
    -not [bool]$contract.next_implementation_boundary.serialized_supervisor_implemented -and
    [int]$contract.next_implementation_boundary.production_physical_worker_count -eq 0 -and
    -not [bool]$contract.next_implementation_boundary.physical_execution_authorized -and
    -not [bool]$contract.claim_boundary.command_conditioned_turning -and
    -not [bool]$contract.claim_boundary.cross_engine_equivalence -and
    -not [bool]$contract.claim_boundary.q_sdk_r23_satisfied -and
    -not [bool]$contract.claim_boundary.physical_acceptance_authority
) "QSDK-R23D10 stage-two contract boundary changed"

& $stageOneClosurePath
Assert-R23D10StageTwo ($LASTEXITCODE -eq 0) (
    "QSDK-R23D10 historical stage-one closure failed"
)

Push-Location -LiteralPath $turningRoot
try {
    & python -m unittest -v `
        test_r23d10_physical_trace.py `
        test_r23d10_physical_evaluator.py
    Assert-R23D10StageTwo ($LASTEXITCODE -eq 0) (
        "QSDK-R23D10 stage-two trace/evaluator tests failed"
    )
} finally {
    Pop-Location
}

$receipt = [ordered]@{
    schema_version = "sporespore_qsdk_r23d10_stage_two_evidence_gate_v1"
    source_binding_count = $bindings.Count
    trace_test_count = 5
    evaluator_test_count = 9
    complete_test_count = 14
    declared_trace_identity_count = 11
    actual_evaluator_cli_command_count = 2
    physical_worker_implementation_count = 0
    supervisor_implementation_count = 0
    physical_process_launch_count = 0
    model_construction_count = 0
    world_attempt_count = 0
    world_build_count = 0
    physical_execution_authorized = $false
    command_conditioned_turning = $false
    physical_acceptance_authority = $false
}
Write-Host (
    "QSDK_R23D10_STAGE_TWO_EVIDENCE " +
    ($receipt | ConvertTo-Json -Depth 20 -Compress)
)
