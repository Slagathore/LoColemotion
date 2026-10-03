[CmdletBinding()]
param(
    [string]$Python = "python"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$expectedRoot = [IO.Path]::GetFullPath(
    "C:\Users\Cole\CodeStuff\games\SporeSpore"
)
$expectedRemote = "https://github.com/Slagathore/sporespore.git"
$manifest = Join-Path $repoRoot "sdk\adapters\rapier\Cargo.toml"
$implementationPath = Join-Path $repoRoot (
    "sdk\turning\r23d65_selected_profile_three_engine_turning_validation_" +
    "implementation_v1.json"
)
$routeGate = Join-Path $repoRoot (
    "tests\test_qsdk_r23d65_rapier_public_profile_physical_route.ps1"
)
$launcherContractPath = Join-Path $repoRoot (
    "sdk\turning\r23d65_rapier_launcher_contract.ps1"
)
$stageId = "runtime_integration_repaired_selected_profile_matched_three_engine_turning_validation"
$onsetId = "onset_600"
$seed = "23175"
$profileId = "sporespore_qsdk_r23d60_selected_s169_actuator_cap_profile_v1"
$profileSha256 = (
    "sha256:" +
    "b65d41e3f30c42e0a8207f1385fe00daa8f03975f4e266a0bd0867970f674964"
)
$hostMappingId = "sporespore_rapier_force_based_outer_impulse_cap_mapping_v1"
$preflightMarker = "QSDK_R23D65_RAPIER_PREFLIGHT "
$failureMarker = "QSDK_R23D65_RAPIER_FAILURE "
$terminalMarker = "QSDK_R23D65_RAPIER_TERMINAL "
$orderedArms = @("reference_zero", "positive_heading", "negative_heading")
$authorizationEnvironmentNames = @(
    "SPORESPORE_QSDK_R23D65_FREEZE",
    "SPORESPORE_QSDK_R23D65_ATTEMPT",
    "SPORESPORE_QSDK_R23D65_TOKEN",
    "SPORESPORE_QSDK_R23D65_STAGE",
    "SPORESPORE_QSDK_R23D65_CELL",
    "SPORESPORE_QSDK_R23D65_ENGINE",
    "SPORESPORE_QSDK_R23D65_ATTEMPT_ROOT",
    "SPORESPORE_QSDK_R23D65_AUTHORITY_REPO_ROOT",
    "SPORESPORE_QSDK_R23D65_PYTHON",
    "SPORESPORE_QSDK_R23D65_POWERSHELL"
)

function Assert-R23D65RapierWorker {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function Get-R23D65RapierSha256 {
    param([Parameter(Mandatory)][string]$Path)
    return "sha256:$((Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash.ToLowerInvariant())"
}

. $launcherContractPath

function Invoke-R23D65RapierWorker {
    param(
        [Parameter(Mandatory)][string[]]$WorkerArguments,
        [Parameter(Mandatory)][int]$ExpectedExitCode,
        [AllowEmptyString()][string]$ExpectedMarker = ""
    )
    $output = @(
        & cargo run `
            --quiet `
            --offline `
            --manifest-path $manifest `
            --bin qsdk_r23d65_physical `
            -- @WorkerArguments 2>&1
    )
    $exitCode = $LASTEXITCODE
    $lines = @($output | ForEach-Object { [string]$_ })
    Assert-R23D65RapierWorker ($exitCode -eq $ExpectedExitCode) (
        "R23D65 Rapier worker exit changed: expected=$ExpectedExitCode " +
        "actual=$exitCode`n$($lines -join [Environment]::NewLine)"
    )
    if ([string]::IsNullOrEmpty($ExpectedMarker)) {
        return [ordered]@{ lines = $lines; exit_code = $exitCode }
    }
    $matches = @(
        $lines | Where-Object {
            $_.StartsWith($ExpectedMarker, [StringComparison]::Ordinal)
        }
    )
    Assert-R23D65RapierWorker ($matches.Count -eq 1) (
        "R23D65 Rapier worker marker changed: $ExpectedMarker`n" +
        ($lines -join [Environment]::NewLine)
    )
    return ($matches[0].Substring($ExpectedMarker.Length) |
        ConvertFrom-Json -AsHashtable -Depth 100)
}

Assert-R23D65RapierWorker ($repoRoot -ceq $expectedRoot) (
    "R23D65 Rapier worker repository root changed: $repoRoot"
)
$gitRoot = [IO.Path]::GetFullPath(
    (& git -C $repoRoot rev-parse --show-toplevel).Trim()
)
Assert-R23D65RapierWorker (
    $LASTEXITCODE -eq 0 -and $gitRoot -ceq $expectedRoot
) "R23D65 Rapier worker canonical Git root changed: $gitRoot"
$remote = (& git -C $repoRoot remote get-url origin).Trim()
Assert-R23D65RapierWorker (
    $LASTEXITCODE -eq 0 -and $remote -ceq $expectedRemote
) "R23D65 Rapier worker origin changed: $remote"

$implementation = Get-Content -Raw -LiteralPath $implementationPath |
    ConvertFrom-Json -AsHashtable -Depth 100
$rapier = $implementation.workers.rapier_parry
$hashBindings = @(
    @("path", "raw_sha256"),
    @("production_public_profile_route_path", "production_public_profile_route_raw_sha256"),
    @("production_profile_mapping_path", "production_profile_mapping_raw_sha256"),
    @("production_physical_constructor_path", "production_physical_constructor_raw_sha256"),
    @("production_physical_runner_path", "production_physical_runner_raw_sha256"),
    @("binary_path", "binary_raw_sha256"),
    @("zero_world_worker_gate_path", "zero_world_worker_gate_raw_sha256")
)
foreach ($binding in $hashBindings) {
    $relativePath = [string]$rapier[$binding[0]]
    $declaredDigest = [string]$rapier[$binding[1]]
    $absolutePath = Join-Path $repoRoot $relativePath
    Assert-R23D65RapierWorker (
        -not [string]::IsNullOrEmpty($relativePath) -and
        (Test-Path -LiteralPath $absolutePath -PathType Leaf) -and
        (Get-R23D65RapierSha256 -Path $absolutePath) -ceq $declaredDigest
    ) "R23D65 Rapier worker source binding changed: $relativePath"
}

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
    & cargo test `
        --quiet `
        --offline `
        --manifest-path $manifest `
        --lib `
        qsdk_r23d65_rapier_worker
    Assert-R23D65RapierWorker ($LASTEXITCODE -eq 0) (
        "R23D65 Rapier worker unit tests failed"
    )

    $positiveCells = @()
    $referencePreflight = $null
    foreach ($armId in $orderedArms) {
        $receipt = Invoke-R23D65RapierWorker `
            -WorkerArguments @(
                New-SporeSporeR23D65RapierLaunchArguments `
                    -Command "preflight" `
                    -StageId $stageId `
                    -OnsetId $onsetId `
                    -CampaignSeed ([long]$seed) `
                    -ProfileId $profileId `
                    -ArmId $armId
            ) `
            -ExpectedExitCode 0 `
            -ExpectedMarker $preflightMarker
        $expectedCell = "rapier_parry__s23175__selected_profile__$armId"
        Assert-R23D65RapierWorker (
            [string]$receipt.schema_version -ceq
                "sporespore_qsdk_r23d65_rapier_physical_worker_preflight_v1" -and
            [string]$receipt.campaign_id -ceq
                "QSDK-R23D65-RUNTIME-INTEGRATION-REPAIRED-SELECTED-PROFILE-MATCHED-THREE-ENGINE-TURNING-VALIDATION" -and
            [string]$receipt.gate_id -ceq "QSDK-R23D65" -and
            [string]$receipt.cell_id -ceq $expectedCell -and
            [string]$receipt.engine_id -ceq "rapier_parry" -and
            [string]$receipt.onset_id -ceq $onsetId -and
            [int64]$receipt.campaign_seed -eq 23175 -and
            [string]$receipt.profile_id -ceq $profileId -and
            [string]$receipt.profile_sha256 -ceq $profileSha256 -and
            [string]$receipt.host_mapping_id -ceq $hostMappingId -and
            [int]$receipt.public_profile_force_plan_actuator_count -eq 8 -and
            [int]$receipt.controller_semantic_step_count -eq 2992 -and
            @($receipt.expected_task_origin_reanchor_semantic_steps).Count -eq 3 -and
            [int]$receipt.expected_task_origin_reanchor_semantic_steps[0] -eq 600 -and
            [int]$receipt.expected_task_origin_reanchor_semantic_steps[1] -eq 1800 -and
            [int]$receipt.expected_task_origin_reanchor_semantic_steps[2] -eq 2400 -and
            [bool]$receipt.complete_nine_cell_matrix_required -and
            [bool]$receipt.physical_worker_implemented -and
            [bool]$receipt.physical_worker_dormant_behind_supervisor_authorization -and
            -not [bool]$receipt.physical_execution_authorized -and
            [int]$receipt.model_construction_count -eq 0 -and
            [int]$receipt.world_attempt_count -eq 0 -and
            [int]$receipt.world_build_count -eq 0 -and
            -not [bool]$receipt.physical_acceptance_authority
        ) "R23D65 Rapier preflight receipt changed: $armId"
        $positiveCells += [string]$receipt.cell_id
        if ($armId -ceq "reference_zero") { $referencePreflight = $receipt }
    }

    $canonicalInput = $referencePreflight.actuator_cap_profile_host_mapping_receipt |
        ConvertTo-Json -Compress -Depth 100
    $canonicalDigest = $canonicalInput | & $Python -c (
        "import hashlib,json,sys; value=json.load(sys.stdin); " +
        "raw=json.dumps(value,sort_keys=True,separators=(',',':')," +
        "allow_nan=False).encode(); print('sha256:'+hashlib.sha256(raw).hexdigest())"
    )
    Assert-R23D65RapierWorker (
        $LASTEXITCODE -eq 0 -and
        ([string]$canonicalDigest).Trim() -ceq
            "sha256:7dcdd7b19b3a88351e94b9753b9c2a9c3f7ebed2de08a192bd59f88bd09aef7b"
    ) "R23D65 Rapier host-mapping Python canonical digest changed"

    $base = @(
        New-SporeSporeR23D65RapierLaunchArguments `
            -Command "preflight" `
            -StageId $stageId `
            -OnsetId $onsetId `
            -CampaignSeed ([long]$seed) `
            -ProfileId $profileId `
            -ArmId "reference_zero"
    )
    $identityMutations = @(
        @("wrong_stage", 2, "wrong", "QSDK_R23D65_RAP_STAGE_INVALID"),
        @("wrong_onset", 4, "wrong", "QSDK_R23D65_RAP_ONSET_INVALID"),
        @("wrong_seed", 6, "23168", "QSDK_R23D65_RAP_CAMPAIGN_SEED_INVALID"),
        @("wrong_profile", 8, "wrong", "QSDK_R23D65_RAP_PROFILE_INVALID"),
        @("wrong_arm", 10, "wrong", "QSDK_R23D65_RAP_ARM_INVALID")
    )
    $mutationRejections = 0
    foreach ($case in $identityMutations) {
        $arguments = @($base.Clone())
        $arguments[[int]$case[1]] = [string]$case[2]
        $receipt = Invoke-R23D65RapierWorker `
            -WorkerArguments $arguments `
            -ExpectedExitCode 1 `
            -ExpectedMarker $failureMarker
        Assert-R23D65RapierWorker (
            [string]$receipt.failure_code -ceq [string]$case[3] -and
            [int]$receipt.model_construction_count -eq 0 -and
            [int]$receipt.world_attempt_count -eq 0 -and
            [int]$receipt.world_build_count -eq 0 -and
            -not [bool]$receipt.physical_acceptance_authority
        ) "R23D65 Rapier selector mutation was accepted: $($case[0])"
        $mutationRejections += 1
    }

    $sourceCommit = (& git -C $repoRoot rev-parse HEAD).Trim()
    $authorization = Invoke-R23D65RapierWorker `
        -WorkerArguments @(
            New-SporeSporeR23D65RapierLaunchArguments `
                -Command "authorization-preflight" `
                -StageId $stageId `
                -OnsetId $onsetId `
                -CampaignSeed ([long]$seed) `
                -ProfileId $profileId `
                -ArmId "reference_zero" `
                -SourceCommit $sourceCommit
        ) `
        -ExpectedExitCode 1 `
        -ExpectedMarker $failureMarker
    Assert-R23D65RapierWorker (
        [string]$authorization.failure_code -ceq
            "QSDK_R23D65_RAP_PHYSICAL_AUTHORIZATION_REQUIRED" -and
        [int]$authorization.model_construction_count -eq 0 -and
        [int]$authorization.world_attempt_count -eq 0 -and
        [int]$authorization.world_build_count -eq 0
    ) "R23D65 Rapier missing authorization was accepted by preflight"
    $mutationRejections += 1

    $physical = Invoke-R23D65RapierWorker `
        -WorkerArguments @(
            New-SporeSporeR23D65RapierLaunchArguments `
                -Command "physical" `
                -StageId $stageId `
                -OnsetId $onsetId `
                -CampaignSeed ([long]$seed) `
                -ProfileId $profileId `
                -ArmId "reference_zero" `
                -SourceCommit $sourceCommit
        ) `
        -ExpectedExitCode 1 `
        -ExpectedMarker $terminalMarker
    Assert-R23D65RapierWorker (
        [string]$physical.failure_code -ceq
            "QSDK_R23D65_RAP_PHYSICAL_AUTHORIZATION_REQUIRED" -and
        [int]$physical.world_attempt_count -eq 0 -and
        [int]$physical.world_build_count -eq 0 -and
        -not [bool]$physical.claims.physical_acceptance_authority
    ) "R23D65 Rapier missing authorization opened a physical world"
    $mutationRejections += 1

    foreach ($arguments in @(
        @("preflight", "--stage", "x", "--stage", "y"),
        @("preflight", "--unknown"),
        (@("authorization-preflight") + $base[1..($base.Count - 1)]),
        (@("physical") + $base[1..($base.Count - 1)])
    )) {
        $process = Invoke-R23D65RapierWorker `
            -WorkerArguments ([string[]]$arguments) `
            -ExpectedExitCode 1
        Assert-R23D65RapierWorker (
            @($process.lines).Count -gt 0
        ) "R23D65 Rapier malformed argument control produced no diagnostic"
        $mutationRejections += 1
    }

    $routeOutput = @(
        & pwsh -NoLogo -NoProfile -File $routeGate -Python $Python 2>&1
    )
    $routeExit = $LASTEXITCODE
    Assert-R23D65RapierWorker (
        $routeExit -eq 0 -and
        ($routeOutput -join [Environment]::NewLine).Contains(
            "QSDK_R23D65_RAPIER_PUBLIC_PROFILE_ROUTE_PASS",
            [StringComparison]::Ordinal
        )
    ) (
        "R23D65 Rapier production dependency route failed`n" +
        ($routeOutput -join [Environment]::NewLine)
    )

    Assert-R23D65RapierWorker (
        ($positiveCells -join "|") -ceq (
            "rapier_parry__s23175__selected_profile__reference_zero|" +
            "rapier_parry__s23175__selected_profile__positive_heading|" +
            "rapier_parry__s23175__selected_profile__negative_heading"
        ) -and
        $mutationRejections -eq 11
    ) "R23D65 Rapier matrix or mutation cardinality changed"

    Write-Output (
        "QSDK_R23D65_RAPIER_WORKER_ZERO_WORLD_PASS cells=3 " +
        "mutation_rejections=11 profile_caps=8 models=0 worlds=0 " +
        "physical=False turning=False qsdk_r23=False equivalence=False release=False"
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
