#requires -Version 7.0

Set-StrictMode -Version Latest

function New-SporeSporeR23D65RapierLaunchArguments {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet("preflight", "authorization-preflight", "physical")]
        [string]$Command,
        [Parameter(Mandatory)][string]$StageId,
        [Parameter(Mandatory)][string]$OnsetId,
        [Parameter(Mandatory)][long]$CampaignSeed,
        [Parameter(Mandatory)][string]$ProfileId,
        [Parameter(Mandatory)]
        [ValidateSet("reference_zero", "positive_heading", "negative_heading")]
        [string]$ArmId,
        [string]$SourceCommit = ""
    )

    $expectedStage = (
        "runtime_integration_repaired_selected_profile_matched_three_" +
        "engine_turning_validation"
    )
    $expectedProfile = (
        "sporespore_qsdk_r23d60_selected_s169_actuator_cap_profile_v1"
    )
    if ($StageId -cne $expectedStage) {
        throw "QSDK_R23D65_RAPIER_LAUNCH_STAGE_INVALID"
    }
    if ($OnsetId -cne "onset_600") {
        throw "QSDK_R23D65_RAPIER_LAUNCH_ONSET_INVALID"
    }
    if ($CampaignSeed -ne 23175) {
        throw "QSDK_R23D65_RAPIER_LAUNCH_SEED_INVALID"
    }
    if ($ProfileId -cne $expectedProfile) {
        throw "QSDK_R23D65_RAPIER_LAUNCH_PROFILE_INVALID"
    }
    $sourceRequired = $Command -in @("authorization-preflight", "physical")
    if ($sourceRequired -and $SourceCommit -cnotmatch '^[0-9a-f]{40}$') {
        throw "QSDK_R23D65_RAPIER_LAUNCH_SOURCE_COMMIT_REQUIRED"
    }
    if (-not $sourceRequired -and -not [string]::IsNullOrEmpty($SourceCommit)) {
        throw "QSDK_R23D65_RAPIER_LAUNCH_SOURCE_COMMIT_FORBIDDEN"
    }

    $arguments = [Collections.Generic.List[string]]::new()
    foreach ($value in @(
        $Command,
        "--stage", $StageId,
        "--onset", $OnsetId,
        "--seed", [string]$CampaignSeed,
        "--profile", $ProfileId,
        "--arm", $ArmId
    )) {
        $arguments.Add([string]$value)
    }
    if ($sourceRequired) {
        $arguments.Add("--source-commit")
        $arguments.Add($SourceCommit)
    }
    return [string[]]$arguments.ToArray()
}
