#requires -Version 7.0

[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$expectedRoot = [IO.Path]::GetFullPath(
    "C:\Users\Cole\CodeStuff\games\SporeSpore"
)
$expectedRemote = "https://github.com/Slagathore/sporespore.git"
$contractPath = Join-Path $repoRoot (
    "sdk\turning\r23d64_rapier_launcher_contract.ps1"
)
$supervisorPath = Join-Path $repoRoot "sdk\run_qsdk_r23d64_supervisor.ps1"
$binarySourcePath = Join-Path $repoRoot (
    "sdk\adapters\rapier\src\bin\qsdk_r23d64_physical.rs"
)
$manifestPath = Join-Path $repoRoot "sdk\adapters\rapier\Cargo.toml"
$stageId = (
    "rapier_launch_contract_repaired_selected_profile_matched_three_engine_" +
    "turning_validation"
)
$onsetId = "onset_600"
$campaignSeed = 23171
$profileId = "sporespore_qsdk_r23d60_selected_s169_actuator_cap_profile_v1"
$sourceCommit = (& git -C $repoRoot rev-parse HEAD).Trim()
$authorizationEnvironmentNames = @(
    "SPORESPORE_QSDK_R23D64_FREEZE",
    "SPORESPORE_QSDK_R23D64_ATTEMPT",
    "SPORESPORE_QSDK_R23D64_TOKEN",
    "SPORESPORE_QSDK_R23D64_STAGE",
    "SPORESPORE_QSDK_R23D64_CELL",
    "SPORESPORE_QSDK_R23D64_ENGINE",
    "SPORESPORE_QSDK_R23D64_ATTEMPT_ROOT",
    "SPORESPORE_QSDK_R23D64_AUTHORITY_REPO_ROOT",
    "SPORESPORE_QSDK_R23D64_PYTHON",
    "SPORESPORE_QSDK_R23D64_POWERSHELL"
)

function Assert-R23D64RapierLauncher {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) {
        throw "QSDK-R23D64 Rapier launcher-contract audit failed: $Message"
    }
}

function Invoke-R23D64RapierLauncher {
    param([Parameter(Mandatory)][string[]]$Arguments)
    $output = @(
        & cargo run `
            --quiet `
            --offline `
            --manifest-path $manifestPath `
            --bin qsdk_r23d64_physical `
            -- @Arguments 2>&1
    )
    return [ordered]@{
        exit_code = $LASTEXITCODE
        lines = @($output | ForEach-Object { [string]$_ })
        text = ($output | ForEach-Object { [string]$_ }) -join "`n"
    }
}

function Get-R23D64MarkerReceipt {
    param(
        [Parameter(Mandatory)]$Process,
        [Parameter(Mandatory)][string]$Marker
    )
    $matches = @($Process.lines | Where-Object {
        $_.StartsWith($Marker, [StringComparison]::Ordinal)
    })
    Assert-R23D64RapierLauncher ($matches.Count -eq 1) (
        "marker population changed: $Marker`n$($Process.text)"
    )
    return ([string]$matches[0]).Substring($Marker.Length) |
        ConvertFrom-Json -AsHashtable -Depth 100
}

Assert-R23D64RapierLauncher (
    $repoRoot -ceq $expectedRoot -and
    (& git -C $repoRoot remote get-url origin).Trim() -ceq $expectedRemote -and
    $LASTEXITCODE -eq 0 -and
    $sourceCommit -cmatch '^[0-9a-f]{40}$'
) "canonical repository identity changed"
foreach ($path in @($contractPath, $supervisorPath, $binarySourcePath, $manifestPath)) {
    Assert-R23D64RapierLauncher (Test-Path -LiteralPath $path -PathType Leaf) (
        "required source is missing: $path"
    )
}

. $contractPath

$authorizationArguments = @(
    New-SporeSporeR23D64RapierLaunchArguments `
        -Command "authorization-preflight" `
        -StageId $stageId `
        -OnsetId $onsetId `
        -CampaignSeed $campaignSeed `
        -ProfileId $profileId `
        -ArmId "reference_zero" `
        -SourceCommit $sourceCommit
)
$physicalArguments = @(
    New-SporeSporeR23D64RapierLaunchArguments `
        -Command "physical" `
        -StageId $stageId `
        -OnsetId $onsetId `
        -CampaignSeed $campaignSeed `
        -ProfileId $profileId `
        -ArmId "reference_zero" `
        -SourceCommit $sourceCommit
)
$expectedAuthorization = @(
    "authorization-preflight", "--stage", $stageId, "--onset", $onsetId,
    "--seed", "23171", "--profile", $profileId, "--arm", "reference_zero",
    "--source-commit", $sourceCommit
)
$expectedPhysical = @($expectedAuthorization.Clone())
$expectedPhysical[0] = "physical"
Assert-R23D64RapierLauncher (
    ($authorizationArguments -join "|") -ceq ($expectedAuthorization -join "|") -and
    ($physicalArguments -join "|") -ceq ($expectedPhysical -join "|")
) "shared production vectors changed"

$supervisorText = [IO.File]::ReadAllText($supervisorPath)
$rapierBranches = [regex]::Matches(
    $supervisorText,
    '(?s)\}\s*elseif\s*\(\$(?:EngineId|engineId)\s+-ceq\s+"rapier_parry"\)\s*\{(?<body>.*?)\}\s*(?:elseif|else)'
)
Assert-R23D64RapierLauncher ($rapierBranches.Count -eq 2) (
    "complete supervisor Rapier call-site population changed"
)
foreach ($branch in $rapierBranches) {
    $body = [string]$branch.Groups["body"].Value
    Assert-R23D64RapierLauncher (
        ([regex]::Matches(
            $body,
            'New-SporeSporeR23D64RapierLaunchArguments'
        )).Count -eq 1 -and
        -not $body.Contains("--campaign-seed", [StringComparison]::Ordinal) -and
        -not $body.Contains('"--seed"', [StringComparison]::Ordinal)
    ) "a supervisor Rapier call site bypasses the shared builder"
}
$contractText = [IO.File]::ReadAllText($contractPath)
$binaryText = [IO.File]::ReadAllText($binarySourcePath)
Assert-R23D64RapierLauncher (
    ([regex]::Matches($contractText, '"--seed"')).Count -eq 1 -and
    -not $contractText.Contains("--campaign-seed", [StringComparison]::Ordinal) -and
    ([regex]::Matches($binaryText, '--seed')).Count -eq 3 -and
    -not $binaryText.Contains("--campaign-seed", [StringComparison]::Ordinal)
) "shared builder and sole production parser option identity changed"

$savedEnvironment = @{}
foreach ($name in $authorizationEnvironmentNames) {
    $savedEnvironment[$name] = [Environment]::GetEnvironmentVariable(
        $name,
        [EnvironmentVariableTarget]::Process
    )
    [Environment]::SetEnvironmentVariable(
        $name,
        $null,
        [EnvironmentVariableTarget]::Process
    )
}

try {
    $authorization = Invoke-R23D64RapierLauncher $authorizationArguments
    $authorizationReceipt = Get-R23D64MarkerReceipt `
        -Process $authorization `
        -Marker "QSDK_R23D64_RAPIER_FAILURE "
    Assert-R23D64RapierLauncher (
        [int]$authorization.exit_code -eq 1 -and
        [string]$authorizationReceipt.failure_code -ceq
            "QSDK_R23D64_RAP_PHYSICAL_AUTHORIZATION_REQUIRED" -and
        [int]$authorizationReceipt.model_construction_count -eq 0 -and
        [int]$authorizationReceipt.world_attempt_count -eq 0 -and
        [int]$authorizationReceipt.world_build_count -eq 0
    ) "authorization vector did not reach the post-parser authorization refusal"

    $physical = Invoke-R23D64RapierLauncher $physicalArguments
    $physicalReceipt = Get-R23D64MarkerReceipt `
        -Process $physical `
        -Marker "QSDK_R23D64_RAPIER_TERMINAL "
    Assert-R23D64RapierLauncher (
        [int]$physical.exit_code -eq 1 -and
        [string]$physicalReceipt.failure_code -ceq
            "QSDK_R23D64_RAP_PHYSICAL_AUTHORIZATION_REQUIRED" -and
        [string]$physicalReceipt.failure_stage -ceq "before_world" -and
        [int]$physicalReceipt.world_attempt_count -eq 0 -and
        [int]$physicalReceipt.world_build_count -eq 0
    ) "physical vector did not reach the post-parser authorization refusal"

    $basePreflight = @(
        New-SporeSporeR23D64RapierLaunchArguments `
            -Command "preflight" `
            -StageId $stageId `
            -OnsetId $onsetId `
            -CampaignSeed $campaignSeed `
            -ProfileId $profileId `
            -ArmId "reference_zero"
    )
    $aliasAuthorization = @($authorizationArguments.Clone())
    $aliasAuthorization[5] = "--campaign-seed"
    $aliasPhysical = @($physicalArguments.Clone())
    $aliasPhysical[5] = "--campaign-seed"
    $duplicateSeed = @($basePreflight + @("--seed", "23171"))
    $missingSeed = @(
        $basePreflight[0..4] + $basePreflight[7..($basePreflight.Count - 1)]
    )
    $invalidSeed = @($basePreflight.Clone())
    $invalidSeed[6] = "not-an-integer"
    $underscoreAlias = @($basePreflight.Clone())
    $underscoreAlias[5] = "--campaign_seed"
    $negativeCases = @(
        @("authorization_alias", $aliasAuthorization, "unknown or duplicate argument: --campaign-seed"),
        @("physical_alias", $aliasPhysical, "unknown or duplicate argument: --campaign-seed"),
        @("duplicate_seed", $duplicateSeed, "unknown or duplicate argument: --seed"),
        @("missing_seed", $missingSeed, "--seed required or invalid"),
        @("invalid_seed", $invalidSeed, "--seed required or invalid"),
        @("underscore_alias", $underscoreAlias, "unknown or duplicate argument: --campaign_seed")
    )
    $negativePassCount = 0
    foreach ($case in $negativeCases) {
        $process = Invoke-R23D64RapierLauncher ([string[]]$case[1])
        Assert-R23D64RapierLauncher (
            [int]$process.exit_code -eq 1 -and
            $process.text.Contains([string]$case[2], [StringComparison]::Ordinal) -and
            -not $process.text.Contains(
                "QSDK_R23D64_RAPIER_TERMINAL ",
                [StringComparison]::Ordinal
            )
        ) "parser negative control failed: $($case[0])`n$($process.text)"
        $negativePassCount += 1
    }

    $receipt = [ordered]@{
        schema_version = "sporespore_qsdk_r23d64_rapier_launcher_contract_conformance_v1"
        campaign_id = "QSDK-R23D64-RAPIER-LAUNCH-CONTRACT-REPAIRED-SELECTED-PROFILE-MATCHED-THREE-ENGINE-TURNING-VALIDATION"
        gate_id = "QSDK-R23D64"
        question_class = "equivalence_non_inferiority"
        population = "complete_two_supervisor_rapier_production_call_sites"
        supervisor_rapier_production_call_site_count = 2
        conforming_call_site_count = 2
        population_compared_completely = $true
        sampling_used = $false
        required_seed_option = "--seed"
        forbidden_seed_alias = "--campaign-seed"
        shared_builder_count = 1
        exact_vectors_executed_through_production_parser = 2
        negative_control_count = $negativeCases.Count
        negative_controls_passed = $negativePassCount
        equivalence_margin = 0
        non_inferiority_margin = 0
        adequacy_argument = "Both production supervisor call sites use the sole shared builder, and both exact command vectors reached the production binary's post-parser authorization refusal. This is complete object equality over two call sites, not sampling or physical equivalence."
        model_construction_count = 0
        world_attempt_count = 0
        world_build_count = 0
        physical_equivalence_claimed = $false
        physical_acceptance_authority = $false
        release_authority = $false
    }
    Write-Output (
        "QSDK_R23D64_RAPIER_LAUNCHER_CONTRACT_PASS " +
        ($receipt | ConvertTo-Json -Depth 20 -Compress)
    )
}
finally {
    foreach ($name in $authorizationEnvironmentNames) {
        [Environment]::SetEnvironmentVariable(
            $name,
            $savedEnvironment[$name],
            [EnvironmentVariableTarget]::Process
        )
    }
}
