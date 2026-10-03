#requires -Version 7.0

Set-StrictMode -Version Latest

function Test-SporeSporeThreeEngineAuthorizationReceipt {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [Collections.IDictionary]$Receipt,
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()][string]$ExpectedSchemaVersion,
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()][string]$ExpectedCampaignId,
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()][string]$ExpectedGateId,
        [Parameter(Mandatory)]
        [ValidateSet("godot_jolt", "rapier_parry", "mujoco")]
        [string]$ExpectedEngineId,
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()][string]$ExpectedStageId,
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()][string]$ExpectedCellId
    )

    $failures = [Collections.Generic.List[string]]::new()

    $identities = [ordered]@{
        schema_version = $ExpectedSchemaVersion
        campaign_id = $ExpectedCampaignId
        gate_id = $ExpectedGateId
        engine_id = $ExpectedEngineId
        stage_id = $ExpectedStageId
        cell_id = $ExpectedCellId
    }
    foreach ($entry in $identities.GetEnumerator()) {
        $field = [string]$entry.Key
        if (-not $Receipt.Contains($field)) {
            $failures.Add("$($field.ToUpperInvariant())_MISSING")
            continue
        }
        if ($Receipt[$field] -isnot [string]) {
            $failures.Add("$($field.ToUpperInvariant())_TYPE_INVALID")
            continue
        }
        if ([string]$Receipt[$field] -cne [string]$entry.Value) {
            $failures.Add("$($field.ToUpperInvariant())_VALUE_INVALID")
        }
    }

    $booleans = [ordered]@{
        ok = $true
        authorization_passed = $true
        returned_before_model = $true
        physical_acceptance_authority = $false
    }
    foreach ($entry in $booleans.GetEnumerator()) {
        $field = [string]$entry.Key
        if (-not $Receipt.Contains($field)) {
            $failures.Add("$($field.ToUpperInvariant())_MISSING")
            continue
        }
        if ($Receipt[$field] -isnot [bool]) {
            $failures.Add("$($field.ToUpperInvariant())_TYPE_INVALID")
            continue
        }
        if ([bool]$Receipt[$field] -ne [bool]$entry.Value) {
            $failures.Add("$($field.ToUpperInvariant())_VALUE_INVALID")
        }
    }

    foreach ($field in @(
        "model_construction_count",
        "world_attempt_count",
        "world_build_count"
    )) {
        if (-not $Receipt.Contains($field)) {
            $failures.Add("$($field.ToUpperInvariant())_MISSING")
            continue
        }
        if ($Receipt[$field] -isnot [long]) {
            $failures.Add("$($field.ToUpperInvariant())_TYPE_INVALID")
            continue
        }
        if ([long]$Receipt[$field] -ne 0L) {
            $failures.Add("$($field.ToUpperInvariant())_VALUE_INVALID")
        }
    }

    return [ordered]@{
        schema_version = "sporespore_three_engine_authorization_receipt_validation_v1"
        ok = $failures.Count -eq 0
        failure_codes = @($failures)
        expected_engine_id = $ExpectedEngineId
        model_construction_count = 0
        world_attempt_count = 0
        world_build_count = 0
        physical_acceptance_authority = $false
    }
}
