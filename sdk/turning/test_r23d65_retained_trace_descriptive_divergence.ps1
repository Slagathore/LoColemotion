[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$expectedRoot = "C:\Users\Cole\CodeStuff\games\SporeSpore"
$expectedRemote = "https://github.com/Slagathore/sporespore.git"
$contractRelativePath = "sdk/turning/r23d65_retained_trace_descriptive_divergence_contract_v1.json"
$compilerRelativePath = "sdk/turning/compile_r23d65_retained_trace_descriptive_divergence.py"
$closureRelativePath = "sdk/turning/r23d65_selected_profile_three_engine_turning_validation_closure_v1.json"

function Assert-Exact {
    param(
        [Parameter(Mandatory = $true)]
        [bool]$Condition,

        [Parameter(Mandatory = $true)]
        [string]$FailureCode
    )

    if (-not $Condition) {
        throw $FailureCode
    }
}

function Get-Sha256Prefixed {
    param(
        [Parameter(Mandatory = $true)]
        [string]$LiteralPath
    )

    return "sha256:" + (
        Get-FileHash -LiteralPath $LiteralPath -Algorithm SHA256
    ).Hash.ToLowerInvariant()
}

$observedRoot = (& git -C $expectedRoot rev-parse --show-toplevel).Trim()
Assert-Exact ($LASTEXITCODE -eq 0) "R23D65_DIVERGENCE_REPO_ROOT_QUERY_FAILED"
Assert-Exact (
    [System.IO.Path]::GetFullPath($observedRoot) -eq
    [System.IO.Path]::GetFullPath($expectedRoot)
) "R23D65_DIVERGENCE_REPO_ROOT_MISMATCH"
$observedRemote = (& git -C $expectedRoot remote get-url origin).Trim()
Assert-Exact ($LASTEXITCODE -eq 0) "R23D65_DIVERGENCE_REMOTE_QUERY_FAILED"
Assert-Exact ($observedRemote -eq $expectedRemote) "R23D65_DIVERGENCE_REMOTE_MISMATCH"

$contractPath = Join-Path $expectedRoot $contractRelativePath
$compilerPath = Join-Path $expectedRoot $compilerRelativePath
$closurePath = Join-Path $expectedRoot $closureRelativePath
Assert-Exact (Test-Path -LiteralPath $contractPath -PathType Leaf) "R23D65_DIVERGENCE_CONTRACT_MISSING"
Assert-Exact (Test-Path -LiteralPath $compilerPath -PathType Leaf) "R23D65_DIVERGENCE_COMPILER_MISSING"
Assert-Exact (Test-Path -LiteralPath $closurePath -PathType Leaf) "R23D65_DIVERGENCE_CLOSURE_MISSING"

$contract = Get-Content -LiteralPath $contractPath -Raw | ConvertFrom-Json -Depth 100
Assert-Exact (
    $contract.schema_version -eq
    "sporespore_r23d65_retained_trace_descriptive_divergence_contract_v1"
) "R23D65_DIVERGENCE_CONTRACT_SCHEMA_INVALID"
Assert-Exact (
    $contract.status -eq "frozen_retrospective_descriptive_development_analysis"
) "R23D65_DIVERGENCE_CONTRACT_STATUS_INVALID"
Assert-Exact (
    $contract.ledger_scope.question_class -eq "development"
) "R23D65_DIVERGENCE_QUESTION_CLASS_INVALID"
Assert-Exact ([bool]$contract.authority_classification.outcome_aware) (
    "R23D65_DIVERGENCE_OUTCOME_AWARENESS_MISSING"
)
Assert-Exact ([bool]$contract.authority_classification.descriptive_only) (
    "R23D65_DIVERGENCE_DESCRIPTIVE_SCOPE_MISSING"
)
Assert-Exact ([bool]$contract.authority_classification.non_authoritative) (
    "R23D65_DIVERGENCE_NON_AUTHORITY_MISSING"
)
foreach ($field in @(
    "prospective",
    "threshold_bearing",
    "selection_bearing",
    "equivalence_or_non_inferiority_test",
    "superiority_test",
    "population_inference",
    "gate_advancement",
    "historical_campaign_reinterpretation"
)) {
    Assert-Exact (-not [bool]$contract.authority_classification.$field) (
        "R23D65_DIVERGENCE_AUTHORITY_PROMOTED:$field"
    )
}
foreach ($property in $contract.claim_boundary.PSObject.Properties) {
    Assert-Exact (-not [bool]$property.Value) (
        "R23D65_DIVERGENCE_CLAIM_PROMOTED:$($property.Name)"
    )
}

Assert-Exact (@($contract.trace_sources).Count -eq 4) (
    "R23D65_DIVERGENCE_TRACE_COUNT_INVALID"
)
$referenceSources = @(
    $contract.trace_sources |
        Where-Object { $_.comparison_role -eq "matched_cross_engine_reference" }
)
Assert-Exact ($referenceSources.Count -eq 2) (
    "R23D65_DIVERGENCE_MATCHED_PAIR_INVALID"
)
Assert-Exact (
    @($referenceSources.engine_id | Sort-Object) -join "," -eq
    "godot_jolt,rapier_parry"
) "R23D65_DIVERGENCE_MATCHED_ENGINE_SET_INVALID"
$contextSources = @(
    $contract.trace_sources |
        Where-Object { $_.comparison_role -eq "within_godot_command_context_only" }
)
Assert-Exact ($contextSources.Count -eq 2) (
    "R23D65_DIVERGENCE_CONTEXT_TRACE_COUNT_INVALID"
)
Assert-Exact (
    @($contextSources | Where-Object { $_.engine_id -ne "godot_jolt" }).Count -eq 0
) "R23D65_DIVERGENCE_CONTEXT_ENGINE_INVALID"

$jointAvailability = @(
    $contract.requested_measurement_availability |
        Where-Object {
            $_.requested_measurement -eq "per-step joint-angle RMS between engines"
        }
)
$comAvailability = @(
    $contract.requested_measurement_availability |
        Where-Object {
            $_.requested_measurement -eq "center-of-mass trajectory drift"
        }
)
Assert-Exact (
    $jointAvailability.Count -eq 1 -and
    $jointAvailability[0].status -eq "unavailable_not_recorded" -and
    -not [bool]$jointAvailability[0].substitution_permitted
) "R23D65_DIVERGENCE_JOINT_GAP_INVALID"
Assert-Exact (
    $comAvailability.Count -eq 1 -and
    $comAvailability[0].status -eq "unavailable_not_recorded" -and
    -not [bool]$comAvailability[0].substitution_permitted
) "R23D65_DIVERGENCE_COM_GAP_INVALID"
Assert-Exact (
    [bool]$contract.metric_contract.torso_reference_point.must_not_be_labeled_center_of_mass
) "R23D65_DIVERGENCE_TORSO_LABEL_GUARD_MISSING"

$closureItem = Get-Item -LiteralPath $closurePath
Assert-Exact (
    $closureItem.Length -eq [long]$contract.source_campaign.closure_byte_length
) "R23D65_DIVERGENCE_CLOSURE_LENGTH_MISMATCH"
Assert-Exact (
    (Get-Sha256Prefixed -LiteralPath $closurePath) -eq
    [string]$contract.source_campaign.closure_sha256
) "R23D65_DIVERGENCE_CLOSURE_DIGEST_MISMATCH"
$closure = Get-Content -LiteralPath $closurePath -Raw | ConvertFrom-Json -Depth 100
Assert-Exact (
    $closure.status -eq $contract.source_campaign.campaign_status
) "R23D65_DIVERGENCE_CLOSURE_STATUS_MISMATCH"
Assert-Exact (-not [bool]$closure.official_result.scientific_result_exists) (
    "R23D65_DIVERGENCE_HISTORICAL_RESULT_PROMOTED"
)
Assert-Exact (-not [bool]$closure.official_result.physical_result_exists) (
    "R23D65_DIVERGENCE_HISTORICAL_PHYSICS_PROMOTED"
)
Assert-Exact (-not [bool]$closure.official_result.posthoc_trace_evaluation_performed) (
    "R23D65_DIVERGENCE_HISTORICAL_EVALUATION_REWRITTEN"
)

$attemptRoot = [System.IO.Path]::GetFullPath(
    [string]$contract.retained_population.attempt_root
)
Assert-Exact (Test-Path -LiteralPath $attemptRoot -PathType Container) (
    "R23D65_DIVERGENCE_ATTEMPT_ROOT_MISSING"
)
foreach ($trace in $contract.trace_sources) {
    $tracePath = Join-Path $attemptRoot ([string]$trace.path)
    Assert-Exact (Test-Path -LiteralPath $tracePath -PathType Leaf) (
        "R23D65_DIVERGENCE_TRACE_MISSING:$($trace.path)"
    )
    $traceItem = Get-Item -LiteralPath $tracePath
    Assert-Exact ($traceItem.Length -eq [long]$trace.byte_length) (
        "R23D65_DIVERGENCE_TRACE_LENGTH_MISMATCH:$($trace.path)"
    )
    Assert-Exact (
        (Get-Sha256Prefixed -LiteralPath $tracePath) -eq [string]$trace.sha256
    ) "R23D65_DIVERGENCE_TRACE_DIGEST_MISMATCH:$($trace.path)"
}

$env:PYTHONDONTWRITEBYTECODE = "1"
$selfTestText = (& python $compilerPath --self-test 2>&1 | Out-String).Trim()
Assert-Exact ($LASTEXITCODE -eq 0) "R23D65_DIVERGENCE_COMPILER_SELF_TEST_FAILED"
$selfTest = $selfTestText | ConvertFrom-Json -Depth 100
Assert-Exact ([bool]$selfTest.ok) "R23D65_DIVERGENCE_COMPILER_SELF_TEST_NOT_OK"
Assert-Exact ([int]$selfTest.check_count -ge 6) (
    "R23D65_DIVERGENCE_COMPILER_SELF_TEST_COVERAGE_INVALID"
)
Assert-Exact (
    [int]$selfTest.model_construction_count -eq 0 -and
    [int]$selfTest.physics_world_build_count -eq 0 -and
    [int]$selfTest.solver_step_count -eq 0 -and
    [int]$selfTest.native_read_count -eq 0
) "R23D65_DIVERGENCE_SELF_TEST_ZERO_WORLD_INVALID"

$insideRepoOutput = Join-Path $expectedRoot "forbidden-r23d65-divergence-output"
$insideOutputText = (& python $compilerPath `
    --repo-root $expectedRoot `
    --contract $contractPath `
    --attempt-root $attemptRoot `
    --output-dir $insideRepoOutput `
    --source-commit ("0" * 40) 2>&1 | Out-String).Trim()
Assert-Exact ($LASTEXITCODE -ne 0) "R23D65_DIVERGENCE_INSIDE_OUTPUT_ACCEPTED"
Assert-Exact ($insideOutputText -match "OUTPUT_INSIDE_REPOSITORY") (
    "R23D65_DIVERGENCE_INSIDE_OUTPUT_WRONG_REFUSAL"
)
Assert-Exact (-not (Test-Path -LiteralPath $insideRepoOutput)) (
    "R23D65_DIVERGENCE_INSIDE_OUTPUT_CREATED"
)

$receipt = [ordered]@{
    schema_version = "sporespore_r23d65_retained_trace_descriptive_divergence_gate_v1"
    ok = $true
    gate_id = "QSDK-R23D65-RETAINED-TRACE-DESCRIPTIVE-DIVERGENCE-V1"
    trace_source_count = @($contract.trace_sources).Count
    matched_cross_engine_pair_count = 1
    context_only_trace_count = $contextSources.Count
    unavailable_requested_metric_count = 2
    compiler_self_test_check_count = [int]$selfTest.check_count
    input_trace_identity_check_count = @($contract.trace_sources).Count
    inside_repository_output_refused = $true
    descriptive_only = $true
    non_authoritative = $true
    sdk1_m20_satisfied = $false
    cross_engine_equivalence_claimed = $false
    physical_acceptance_authority = $false
    model_construction_count = 0
    physics_world_build_count = 0
    solver_step_count = 0
    native_read_count = 0
    release_authority = $false
}
$receipt | ConvertTo-Json -Depth 10 -Compress
