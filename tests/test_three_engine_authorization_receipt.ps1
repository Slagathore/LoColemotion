[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$contractPath = Join-Path $repoRoot (
    "sdk\turning\three_engine_authorization_receipt_contract_v1.json"
)
$validatorPath = Join-Path $repoRoot "sdk\three_engine_authorization_receipt.ps1"
$campaignId = "QSDK-THREE-ENGINE-AUTHORIZATION-CONFORMANCE-FIXTURE-V1"
$gateId = "QSDK-AUTHORIZATION-CONFORMANCE"
$stageId = "production_supervisor_authorization_fixture"
$engines = @("godot_jolt", "rapier_parry", "mujoco")

function Assert-AuthorizationReceipt([bool]$Condition, [string]$Message) {
    if (-not $Condition) {
        throw "THREE-ENGINE AUTHORIZATION RECEIPT: $Message"
    }
}

Assert-AuthorizationReceipt (
    (& git -C $repoRoot rev-parse --show-toplevel).Trim() -ceq
        $repoRoot.Replace("\", "/") -and
    (& git -C $repoRoot remote get-url origin).Trim() -ceq
        "https://github.com/Slagathore/sporespore.git"
) "canonical repository identity changed"
foreach ($path in @($contractPath, $validatorPath)) {
    Assert-AuthorizationReceipt (Test-Path -LiteralPath $path -PathType Leaf) (
        "required path is missing: $path"
    )
}

$contract = Get-Content -LiteralPath $contractPath -Raw |
    ConvertFrom-Json -AsHashtable -Depth 100
Assert-AuthorizationReceipt (
    [string]$contract.schema_version -ceq
        "sporespore_three_engine_authorization_receipt_contract_v1" -and
    [string]$contract.status -ceq
        "development_contract_complete_physical_not_authorized" -and
    [string]$contract.work_class -ceq "development" -and
    [string]$contract.conformance_question_class -ceq
        "equivalence_non_inferiority" -and
    (@($contract.complete_producer_population) -join "|") -ceq
        ($engines -join "|") -and
    [int]$contract.complete_population_size -eq 3 -and
    [bool]$contract.complete_population_compared -and
    -not [bool]$contract.sampling_used -and
    [double]$contract.equivalence_margin -eq 0.0 -and
    [double]$contract.non_inferiority_margin -eq 0.0 -and
    [string]$contract.threshold_origin -ceq
        "exact_complete_three_producer_schema_and_value_comparison_no_statistical_threshold" -and
    [string]$contract.r23d66_failure_class_addressed -ceq
        "supervisor_mujoco_authorization_receipt_schema_mismatch_missing_ok" -and
    $null -eq $contract.physical_question_class -and
    [int]$contract.model_construction_count -eq 0 -and
    [int]$contract.world_attempt_count -eq 0 -and
    [int]$contract.world_build_count -eq 0 -and
    -not [bool]$contract.turning_claimed -and
    -not [bool]$contract.q_sdk_r23_satisfied -and
    -not [bool]$contract.cross_engine_equivalence_claimed -and
    -not [bool]$contract.physical_execution_authorized -and
    -not [bool]$contract.physical_acceptance_authority -and
    -not [bool]$contract.release_authority
) "contract semantics changed"

. $validatorPath

$positiveCount = 0
$negativeCount = 0
foreach ($engine in $engines) {
    $schema = "sporespore_fixture_${engine}_authorization_v1"
    $cellId = "authorization_fixture__${engine}"
    $receipt = [ordered]@{
        schema_version = $schema
        campaign_id = $campaignId
        gate_id = $gateId
        engine_id = $engine
        stage_id = $stageId
        cell_id = $cellId
        ok = $true
        authorization_passed = $true
        returned_before_model = $true
        model_construction_count = 0L
        world_attempt_count = 0L
        world_build_count = 0L
        physical_acceptance_authority = $false
    }
    $arguments = @{
        Receipt = $receipt
        ExpectedSchemaVersion = $schema
        ExpectedCampaignId = $campaignId
        ExpectedGateId = $gateId
        ExpectedEngineId = $engine
        ExpectedStageId = $stageId
        ExpectedCellId = $cellId
    }
    $positive = Test-SporeSporeThreeEngineAuthorizationReceipt @arguments
    Assert-AuthorizationReceipt (
        [bool]$positive.ok -and @($positive.failure_codes).Count -eq 0
    ) "positive $engine receipt was rejected"
    $positiveCount += 1

    $allFields = @(
        "schema_version",
        "campaign_id",
        "gate_id",
        "engine_id",
        "stage_id",
        "cell_id",
        "ok",
        "authorization_passed",
        "returned_before_model",
        "model_construction_count",
        "world_attempt_count",
        "world_build_count",
        "physical_acceptance_authority"
    )
    foreach ($field in $allFields) {
        $copy = [ordered]@{}
        foreach ($entry in $receipt.GetEnumerator()) {
            $copy[[string]$entry.Key] = $entry.Value
        }
        $copy.Remove($field)
        $result = Test-SporeSporeThreeEngineAuthorizationReceipt `
            -Receipt $copy `
            -ExpectedSchemaVersion $schema `
            -ExpectedCampaignId $campaignId `
            -ExpectedGateId $gateId `
            -ExpectedEngineId $engine `
            -ExpectedStageId $stageId `
            -ExpectedCellId $cellId
        Assert-AuthorizationReceipt (
            -not [bool]$result.ok -and
            (@($result.failure_codes) -join "|").Contains(
                "$($field.ToUpperInvariant())_MISSING"
            )
        ) "missing $field was accepted for $engine"
        $negativeCount += 1
    }

    $stringFields = @(
        "schema_version",
        "campaign_id",
        "gate_id",
        "engine_id",
        "stage_id",
        "cell_id"
    )
    $booleanFields = @(
        "ok",
        "authorization_passed",
        "returned_before_model",
        "physical_acceptance_authority"
    )
    $integerFields = @(
        "model_construction_count",
        "world_attempt_count",
        "world_build_count"
    )
    foreach ($field in $allFields) {
        $copy = $receipt | ConvertTo-Json -Depth 20 | ConvertFrom-Json -AsHashtable
        $copy[$field] = if ($field -cin $stringFields) {
            1L
        } elseif ($field -cin $booleanFields) {
            "true"
        } else {
            "0"
        }
        $result = Test-SporeSporeThreeEngineAuthorizationReceipt `
            -Receipt $copy `
            -ExpectedSchemaVersion $schema `
            -ExpectedCampaignId $campaignId `
            -ExpectedGateId $gateId `
            -ExpectedEngineId $engine `
            -ExpectedStageId $stageId `
            -ExpectedCellId $cellId
        Assert-AuthorizationReceipt (-not [bool]$result.ok) (
            "wrong-type $field was accepted for $engine"
        )
        $negativeCount += 1
    }

    foreach ($field in $allFields) {
        $copy = $receipt | ConvertTo-Json -Depth 20 | ConvertFrom-Json -AsHashtable
        $copy[$field] = if ($field -cin $stringFields) {
            ([string]$receipt[$field]) + "__wrong"
        } elseif ($field -cin $booleanFields) {
            -not [bool]$receipt[$field]
        } elseif ($field -cin $integerFields) {
            1L
        } else {
            throw "unclassified authorization field: $field"
        }
        $result = Test-SporeSporeThreeEngineAuthorizationReceipt `
            -Receipt $copy `
            -ExpectedSchemaVersion $schema `
            -ExpectedCampaignId $campaignId `
            -ExpectedGateId $gateId `
            -ExpectedEngineId $engine `
            -ExpectedStageId $stageId `
            -ExpectedCellId $cellId
        Assert-AuthorizationReceipt (-not [bool]$result.ok) (
            "wrong-value $field was accepted for $engine"
        )
        $negativeCount += 1
    }
}

Assert-AuthorizationReceipt (
    $positiveCount -eq 3 -and $negativeCount -eq 117
) "complete positive or negative control population changed"

Write-Host (
    "[turning/3e] AUTHORIZATION_RECEIPT_CONTRACT_PASS producers=3/3 " +
    "negative_controls=117/117 models=0 worlds=0 work=development " +
    "question=equivalence_non_inferiority physical_authority=False"
)
