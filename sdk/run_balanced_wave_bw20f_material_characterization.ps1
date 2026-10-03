#requires -Version 7.0

[CmdletBinding()]
param(
    [switch]$PreflightOnly,
    [switch]$RunPhysical,
    [string]$Godot = (
        "C:\Users\Cole\CodeStuff\Misc\Godot\" +
        "Godot_v4.7-stable_mono_win64_console.exe"
    ),
    [string]$LogRoot = (
        Join-Path $env:TEMP "sporespore_bw20f_material_preflight"
    ),
    [string]$OutputRoot = ""
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$sdkRoot = [System.IO.Path]::GetFullPath($PSScriptRoot)
$repoRoot = [System.IO.Path]::GetFullPath((Split-Path -Parent $sdkRoot))
$evidenceRoot = [System.IO.Path]::GetFullPath(
    (Join-Path (Split-Path -Parent $repoRoot) "SporeSpore_Evidence")
)
$campaignId = "BW20F-BW19V-COLD-MATERIAL"
$gateId = "BW20F"
$implementationParentCommit = "23f76a41ba0f96a56094350632081acffcc96abe"
$preregistrationPath = Join-Path (
    $sdkRoot
) "balanced_wave_bw20f_cold_material_preregistration.json"
$productionGatePath = Join-Path (
    $sdkRoot
) "balanced_wave_bw20f_material_characterization_gate.ps1"
$fixturePreflightPath = Join-Path (
    $repoRoot
) "tests\test_sdk_balanced_wave_bw20f_material_characterization_preflight.gd"
$physicalHarnessPath = Join-Path (
    $repoRoot
) "tests\test_sdk_godot_jolt_friction_ladder_characterization.gd"
$rigPath = Join-Path (
    $repoRoot
) "scripts\lab\rigs\sdk_friction_ladder_sled_rig.gd"
$genericRunnerPath = Join-Path (
    $sdkRoot
) "run_godot_jolt_friction_ladder_characterization.ps1"
$captureClockPath = Join-Path $repoRoot "scripts\lab\capture_clock.gd"
$observerProfilePath = Join-Path $repoRoot "scripts\lab\observer_profile.gd"
$baseRigPath = Join-Path $repoRoot "scripts\lab\rigs\friction_sled_rig.gd"
$observedRigidBodyPath = Join-Path (
    $repoRoot
) "scripts\lab\mechanics\observed_rigid_body.gd"
$contactCapacityPath = Join-Path (
    $repoRoot
) "scripts\lab\mechanics\contact_capacity.gd"
$canonicalizerPath = Join-Path (
    $repoRoot
) "scripts\lab\mechanics\contact_canonicalizer.gd"
$slipObserverPath = Join-Path (
    $repoRoot
) "scripts\lab\mechanics\contact_slip_observer.gd"
$breakawayAnalyzerPath = Join-Path (
    $repoRoot
) "scripts\lab\mechanics\friction_breakaway_analyzer.gd"
$canonicalJsonPath = Join-Path $repoRoot "scripts\lab\canonical_json.gd"
$frozenValuePath = Join-Path $repoRoot "scripts\lab\frozen_value.gd"
$failureCodesPath = Join-Path $repoRoot "scripts\lab\failure_codes.gd"
$finiteSanitizerPath = Join-Path $repoRoot "scripts\lab\finite_sanitizer.gd"
$freezeAuditPath = Join-Path (
    $repoRoot
) "tests\test_bw20f_material_characterization_freeze.ps1"
$gateTestPath = Join-Path (
    $repoRoot
) "tests\test_bw20f_material_characterization_gate.ps1"
$closurePath = Join-Path (
    $sdkRoot
) "balanced_wave_bw20f_material_characterization_closure.json"
$expectedHashes = [ordered]@{
    $preregistrationPath = "7f90a75611c34dd27c3e2a6f1b04b30a58368be9d9871075fb6ef1d0d2caf999"
    $productionGatePath = "969e82bd9a603692211d6cf573e1f536a066432559563b0e62b0768334cbd9c3"
    $fixturePreflightPath = "0fc048f3b36d560bd56eebd11391ee34872117d68ef6eed4dc4d8f2ae49bdd21"
    $physicalHarnessPath = "2c07053fcce9d0982cf533b1eac65955bb4e3a57e1507fdb20284fc7c6f17c1e"
    $rigPath = "bcd40080800669492dbc0633d5aa95ed11461d7ae29756c05e892b3467ccd014"
    $genericRunnerPath = "47a84a2611f7050739c2aa96cf8dbfac0f80892220419ac688c79cc03748c5d7"
    $gateTestPath = "273b396c4af2fb4343b4281774c7f5b27f5ce34b419b38b1267f72190c4b16ac"
    $captureClockPath = "f2f0305ce698d17d892057e160928bbebd29bac21c290aa22bf4b112205f1291"
    $observerProfilePath = "645844c8534d8c1c0fe693b7dc2c926a3732c3fa020c81cc2240edc5639f8fd2"
    $baseRigPath = "92f7983a47257e7d3ee7e262ad57aee2c7cd5c345f54f6ce9981da8dd3beb487"
    $observedRigidBodyPath = "04c95729af1f755f270d07caa97d822d4b86afeeb3b6bcb246b4d68a5284be91"
    $contactCapacityPath = "8d91b6a9b774f6d51a14fa4eb5672f7779051ed35075cd73d1ac31ecea63c2ca"
    $canonicalizerPath = "ecc22a205123ef486faa61cbf66c33b6d05b98d3bf1ff2e8b24021bba326089c"
    $slipObserverPath = "b153ecd8e6d7a4cc867ef8787d9a8cc97ea15cc4a35994dcd4be3640f2c3834b"
    $breakawayAnalyzerPath = "b9efc3397d41609ea6d00d6d3e14c96ea0bb1a61ec0b7a9145a63ab5edcc8a14"
    $canonicalJsonPath = "b1f0f4df813663008824d223165577e281bffb97e81080d33d77c1ffb031501f"
    $frozenValuePath = "b45d91510d6f42a3cccc87bb9ea40c602469fed11338860512a832361a835d10"
    $failureCodesPath = "9cc79d962ad70b12c932685f8aee3996d62b631d664af57525df8726edfc3456"
    $finiteSanitizerPath = "40428eb592bda785be76d32869f63fb55fe8e40ac038a8daf94c976414e6e444"
}

function Assert-Exact {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) {
        throw $Message
    }
}

function Get-RawSha256 {
    param([Parameter(Mandatory)][string]$Path)
    return (Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash.ToLowerInvariant()
}

function Write-NewJsonArtifact {
    param(
        [Parameter(Mandatory)][object]$Value,
        [Parameter(Mandatory)][string]$Path
    )
    Assert-Exact (
        -not (Test-Path -LiteralPath $Path)
    ) "Refusing to overwrite a $gateId artifact: $Path"
    [void][System.IO.Directory]::CreateDirectory((Split-Path -Parent $Path))
    $temporaryPath = $Path + ".tmp"
    Assert-Exact (
        -not (Test-Path -LiteralPath $temporaryPath)
    ) "Refusing stale $gateId temporary artifact: $temporaryPath"
    [System.IO.File]::WriteAllText(
        $temporaryPath,
        (($Value | ConvertTo-Json -Depth 40) + [Environment]::NewLine),
        [System.Text.UTF8Encoding]::new($false)
    )
    Move-Item -LiteralPath $temporaryPath -Destination $Path
}

Assert-Exact (
    [bool]$PreflightOnly -xor [bool]$RunPhysical
) "Specify exactly one of -PreflightOnly or -RunPhysical"
if ($RunPhysical) {
    Assert-Exact (
        -not [string]::IsNullOrWhiteSpace($OutputRoot)
    ) "$gateId -RunPhysical requires an explicit durable OutputRoot"
    Assert-Exact (
        -not (Test-Path -LiteralPath $closurePath -PathType Leaf)
    ) "$gateId characterization is already closed and may not rerun"
}

foreach ($entry in $expectedHashes.GetEnumerator()) {
    Assert-Exact (
        (Test-Path -LiteralPath $entry.Key -PathType Leaf) -and
        (Get-RawSha256 $entry.Key) -ceq [string]$entry.Value
    ) "$gateId frozen source is missing or changed: $($entry.Key)"
}

$preregistration = Get-Content -Raw -LiteralPath $preregistrationPath |
    ConvertFrom-Json -AsHashtable
Assert-Exact (
    [string]$preregistration.schema_version -ceq
        "sporespore_balanced_wave_bw20f_cold_material_preregistration_v1" -and
    [string]$preregistration.status -ceq
        "frozen_before_first_bw20f_characterization_world" -and
    [string]$preregistration.campaign_id -ceq $campaignId -and
    [string]$preregistration.gate_id -ceq $gateId -and
    [string]$preregistration.implementation_parent_commit -ceq
        $implementationParentCommit -and
    [string]$preregistration.host_identity.godot_version -ceq
        "4.7.stable.mono.official.5b4e0cb0f" -and
    [string]$preregistration.host_identity.godot_runtime_version -ceq
        "4.7-stable (official)" -and
    [string]$preregistration.host_identity.godot_executable_sha256 -ceq
        "c5fc2d0bb24826a6757fa1e6bf2991effb294859c7dd03d09a122ef217484896" -and
    [string]$preregistration.host_identity.adapter_id -ceq
        "godot_jolt_gdextension_v1" -and
    [string]$preregistration.study_class.classification -ceq
        "exact_finite_cell_adapter_material_characterization" -and
    [bool]$preregistration.study_class.finite_decision -and
    -not [bool]$preregistration.study_class.population_inference -and
    -not [bool]$preregistration.study_class.superiority_study -and
    -not [bool]$preregistration.study_class.noninferiority_or_equivalence_study -and
    [int]$preregistration.material_characterization.expected_world_count -eq 13 -and
    [int]$preregistration.material_characterization.expected_gate_count -eq 23 -and
    (@($preregistration.material_characterization.authored_friction_values) -join ",") -ceq
        "0.09,0.37,0.76,1.18" -and
    (@($preregistration.cold_reservation.locomotion_campaign_seeds) -join ",") -ceq
        "23001,23002,23003" -and
    [int]$preregistration.future_bw19v_b_cold_locomotion_contract.expected_world_count -eq
        17 -and
    [bool]$preregistration.preflight_contract.wrong_host_identity_canary_must_fail -and
    -not [bool]$preregistration.claims_if_stage_1_passes.bw19v_b_material_robustness -and
    -not [bool]$preregistration.claims_if_stage_1_passes.physical_acceptance_authority
) "$gateId declaration, finite study class, or claim boundary changed"
$referenceCharacterization = (
    $preregistration.numeric_threshold_provenance.accepted_reference_manifest
)
$referenceCharacterizationPath = [System.IO.Path]::GetFullPath(
    [string]$referenceCharacterization.retained_characterization_report
)
Assert-Exact (
    (Test-Path -LiteralPath $referenceCharacterizationPath -PathType Leaf) -and
    (Get-RawSha256 $referenceCharacterizationPath) -ceq
        [string]$referenceCharacterization.retained_characterization_sha256
) "$gateId retained threshold-provenance report is missing or changed"

$resolvedOutputRoot = $null
$sourceCommit = $null
$originMainCommit = $null
$remoteMainCommit = $null
if ($RunPhysical) {
    $resolvedOutputRoot = [System.IO.Path]::GetFullPath($OutputRoot)
    $evidencePrefix = $evidenceRoot.TrimEnd("\") + "\"
    Assert-Exact (
        $resolvedOutputRoot.StartsWith(
            $evidencePrefix,
            [StringComparison]::OrdinalIgnoreCase
        )
    ) "$gateId OutputRoot must be inside $evidenceRoot"
    Assert-Exact (
        -not $resolvedOutputRoot.StartsWith(
            "C:\tmp\",
            [StringComparison]::OrdinalIgnoreCase
        )
    ) "$gateId retained evidence may not use C:\tmp"
    Assert-Exact (
        -not (Test-Path -LiteralPath $resolvedOutputRoot)
    ) "$gateId OutputRoot already exists: $resolvedOutputRoot"

    $sourceStatus = @(
        & git -C $repoRoot status --porcelain=v1 --untracked-files=all
    )
    $sourceCommit = (& git -C $repoRoot rev-parse HEAD).Trim()
    $originMainCommit = (& git -C $repoRoot rev-parse origin/main).Trim()
    $remoteLine = (& git -C $repoRoot ls-remote origin refs/heads/main).Trim()
    $remoteMainCommit = ($remoteLine -split "\s+")[0]
    Assert-Exact (
        $LASTEXITCODE -eq 0 -and
        $sourceStatus.Count -eq 0 -and
        $sourceCommit -cmatch "^[0-9a-f]{40}$" -and
        $sourceCommit -cne $implementationParentCommit -and
        $sourceCommit -ceq $originMainCommit -and
        $sourceCommit -ceq $remoteMainCommit
    ) "$gateId requires clean source with HEAD equal to live GitHub main"
    $expectedLeaf = (
        "balanced-wave-bw20f-material-characterization-" +
        $sourceCommit.Substring(0, 7)
    )
    Assert-Exact (
        (Split-Path -Leaf $resolvedOutputRoot) -ceq $expectedLeaf
    ) "$gateId OutputRoot must be named $expectedLeaf"

    $priorAttempts = @()
    if (Test-Path -LiteralPath $evidenceRoot -PathType Container) {
        $priorAttempts = @(
            Get-ChildItem `
                -LiteralPath $evidenceRoot `
                -Recurse `
                -File `
                -Filter "attempt.json" |
            Where-Object {
                try {
                    $attempt = Get-Content -Raw -LiteralPath $_.FullName |
                        ConvertFrom-Json
                    [string]$attempt.campaign_id -ceq $campaignId
                } catch {
                    $false
                }
            }
        )
    }
    Assert-Exact (
        $priorAttempts.Count -eq 0
    ) "$gateId already has a retained physical attempt and may not rerun"

    Assert-Exact (
        Test-Path -LiteralPath $freezeAuditPath -PathType Leaf
    ) "$gateId freeze audit is missing"
    & pwsh -NoProfile -File $freezeAuditPath -SkipSupervisorPreflight
    $freezeAuditExitCode = $LASTEXITCODE
    Assert-Exact (
        $freezeAuditExitCode -eq 0
    ) "$gateId executable freeze audit failed before physical entry"
}

# The pure evaluator is the production receipt gate used again after physical
# execution. Its test proves a complete perfect receipt and serialization
# round trip pass while six independent host/semantic/claim canaries fail closed.
& pwsh -NoProfile -File $gateTestPath
$gateTestExitCode = $LASTEXITCODE
Assert-Exact (
    $gateTestExitCode -eq 0
) "$gateId complete synthetic production-gate preflight failed"
. $productionGatePath
$perfectReceipt = New-Bw20fPerfectSyntheticCharacterizationReceipt
$perfectEvaluation = Test-Bw20fMaterialCharacterizationReceipt `
    -Receipt $perfectReceipt
Assert-Exact (
    [bool]$perfectEvaluation.ok -and
    [int]$perfectEvaluation.reconstructed_passed_gate_count -eq 23 -and
    [int]$perfectEvaluation.observed_world_count -eq 13 -and
    @($perfectEvaluation.failure_codes).Count -eq 0
) "$gateId perfect synthetic receipt did not pass its production evaluator"

# Run the fixture/source preflight in an isolated project so editor metadata
# cannot alter the repository. The harness constructs nodes but never inserts
# them into a SceneTree, advances physics, or opens an outcome.
$godotPath = [System.IO.Path]::GetFullPath($Godot)
Assert-Exact (
    Test-Path -LiteralPath $godotPath -PathType Leaf
) "Godot executable not found: $godotPath"
$godotExecutableSha256 = Get-RawSha256 $godotPath
$godotVersion = (& $godotPath --version 2>&1 | Out-String).Trim()
$godotVersionExitCode = $LASTEXITCODE
Assert-Exact (
    $godotVersionExitCode -eq 0 -and
    $godotVersion -ceq [string]$preregistration.host_identity.godot_version -and
    $godotExecutableSha256 -ceq
        [string]$preregistration.host_identity.godot_executable_sha256
) "$gateId Godot host identity is not the frozen executable"
$runToken = (
    (Get-Date -Format "yyyyMMddTHHmmssfff") + "-" +
    [Guid]::NewGuid().ToString("N").Substring(0, 8)
)
$preflightRoot = Join-Path ([System.IO.Path]::GetFullPath($LogRoot)) $runToken
$projectRoot = Join-Path $preflightRoot "project"
[void][System.IO.Directory]::CreateDirectory($projectRoot)
foreach ($directory in @("scripts", "tests", "sdk")) {
    [void](New-Item `
        -ItemType Junction `
        -Path (Join-Path $projectRoot $directory) `
        -Target (Join-Path $repoRoot $directory))
}
$projectText = @"
; Isolated SporeSpore BW20F zero-world material preflight.

config_version=5

[application]

config/name="sporespore-bw20f-material-preflight"
config/features=PackedStringArray("4.7", "Forward Plus")

[debug]

gdscript/warnings/shadowed_global_identifier=0

[physics]

3d/physics_engine="Jolt Physics"
jolt_physics_3d/simulation/velocity_steps=20
jolt_physics_3d/simulation/position_steps=7
"@
[System.IO.File]::WriteAllText(
    (Join-Path $projectRoot "project.godot"),
    $projectText,
    [System.Text.UTF8Encoding]::new($false)
)
$appData = Join-Path $preflightRoot "worker\appdata"
$localAppData = Join-Path $preflightRoot "worker\localappdata"
[void][System.IO.Directory]::CreateDirectory($appData)
[void][System.IO.Directory]::CreateDirectory($localAppData)
$transcriptPath = Join-Path $preflightRoot "transcript.log"
$engineLogPath = Join-Path $preflightRoot "engine.log"
$previousAppData = $env:APPDATA
$previousLocalAppData = $env:LOCALAPPDATA
try {
    $env:APPDATA = $appData
    $env:LOCALAPPDATA = $localAppData
    & $godotPath `
        --headless `
        --path $projectRoot `
        --log-file $engineLogPath `
        --script (
            "res://tests/" +
            "test_sdk_balanced_wave_bw20f_material_characterization_preflight.gd"
        ) 2>&1 | Tee-Object -FilePath $transcriptPath
    $godotExitCode = $LASTEXITCODE
} finally {
    $env:APPDATA = $previousAppData
    $env:LOCALAPPDATA = $previousLocalAppData
}
$receiptPrefix = "BW20F_MATERIAL_CHARACTERIZATION_PREFLIGHT_RECEIPT "
$receiptLines = @(
    Get-Content -LiteralPath $transcriptPath |
        Where-Object { $_.StartsWith($receiptPrefix) }
)
Assert-Exact (
    $godotExitCode -eq 0 -and $receiptLines.Count -eq 1
) "$gateId fixture preflight failed or emitted an ambiguous receipt"
$fixtureReceipt = (
    $receiptLines[0].Substring($receiptPrefix.Length) |
        ConvertFrom-Json -AsHashtable
)
Assert-Exact (
    [bool]$fixtureReceipt.ok -and
    [string]$fixtureReceipt.campaign_id -ceq $campaignId -and
    [string]$fixtureReceipt.gate_id -ceq $gateId -and
    [int]$fixtureReceipt.passed_gate_count -eq 8 -and
    [int]$fixtureReceipt.failed_gate_count -eq 0 -and
    [int]$fixtureReceipt.expected_gate_count -eq 8 -and
    [string]$fixtureReceipt.engine.godot_runtime_version -ceq
        [string]$preregistration.host_identity.godot_runtime_version -and
    [bool]$fixtureReceipt.preregistration_identity_exact -and
    [bool]$fixtureReceipt.candidate_source_bindings_exact -and
    [bool]$fixtureReceipt.reservation_provenance_exact -and
    [bool]$fixtureReceipt.matrix_contract_exact -and
    [bool]$fixtureReceipt.invalid_value_rejected -and
    [int]$fixtureReceipt.fixture_construction_count -eq 5 -and
    @($fixtureReceipt.fixture_receipts).Count -eq 5 -and
    [int]$fixtureReceipt.world_build_count -eq 0 -and
    [int]$fixtureReceipt.scene_tree_insertion_count -eq 0 -and
    [int]$fixtureReceipt.physics_state_mutation_count -eq 0 -and
    -not [bool]$fixtureReceipt.locomotion_outcome_exposed -and
    -not [bool]$fixtureReceipt.characterization_outcome_exposed -and
    -not [bool]$fixtureReceipt.physical_acceptance_authority
) "$gateId zero-world fixture/source receipt is incomplete or changed"

if ($PreflightOnly) {
    Write-Host (
        "$gateId PREFLIGHT_PASS production_gates=23 fixture_gates=8 " +
        "fixtures=5 canaries=6 worlds=0 scene_insertions=0 " +
        "locomotion_seeds_opened=0 physical_authority=False"
    )
    return
}

[void][System.IO.Directory]::CreateDirectory($resolvedOutputRoot)
$attemptPath = Join-Path $resolvedOutputRoot "attempt.json"
$attempt = [ordered]@{
    schema_version = "sporespore_balanced_wave_bw20f_attempt_v1"
    campaign_id = $campaignId
    gate_id = $gateId
    launched_at_utc = [DateTime]::UtcNow.ToString("o")
    source_commit = $sourceCommit
    origin_main_commit = $originMainCommit
    remote_main_commit = $remoteMainCommit
    source_worktree_clean = $true
    source_matches_live_github_main = $true
    godot_version = $godotVersion
    godot_executable_sha256 = $godotExecutableSha256
    preregistration_raw_sha256 = Get-RawSha256 $preregistrationPath
    complete_synthetic_production_gate_passed = $true
    zero_world_fixture_preflight_passed = $true
    preflight_world_build_count = 0
    physical_process_launch_reserved_identity_consumed = $true
    same_identity_rerun_allowed = $false
    expected_world_count = 13
    expected_gate_count = 23
    locomotion_seed_world_count = 0
    physical_acceptance_authority = $false
}
Write-NewJsonArtifact -Value $attempt -Path $attemptPath

$reportPath = Join-Path $resolvedOutputRoot "report.json"
$workerLogRoot = Join-Path $resolvedOutputRoot "worker"
& $genericRunnerPath `
    -Campaign BW20F `
    -Godot $godotPath `
    -LogRoot $workerLogRoot `
    -Output $reportPath `
    -Bw20fSupervisorAuthorized `
    -Bw20fSupervisorAttempt $attemptPath
Assert-Exact (
    $LASTEXITCODE -eq 0 -and
    (Test-Path -LiteralPath $reportPath -PathType Leaf)
) "$gateId physical characterization did not produce its retained report"

$report = Get-Content -Raw -LiteralPath $reportPath |
    ConvertFrom-Json -AsHashtable
Assert-Exact (
    [string]$report.schema_version -ceq
        "sporespore_balanced_wave_bw20f_material_characterization_report_v1" -and
    [string]$report.source_commit -ceq $sourceCommit -and
    [bool]$report.source_worktree_clean -and
    [bool]$report.source_matches_origin_main -and
    [string]$report.host_identity.godot_version -ceq $godotVersion -and
    [string]$report.host_identity.godot_executable_sha256 -ceq
        $godotExecutableSha256 -and
    [string]$report.prerequisite_evidence.bw5c_material_characterization.sha256 -ceq
        [string]$referenceCharacterization.retained_characterization_sha256 -and
    [string]$report.prerequisite_evidence.bw5c_material_characterization.threshold_use -ceq
        "inherited_operational_contract_only" -and
    [bool]$report.accepted -and
    [bool]$report.production_gate_evaluation.ok -and
    [int]$report.receipt.observed_world_count -eq 13 -and
    [int]$report.receipt.passed_gate_count -eq 23 -and
    [int]$report.receipt.failed_gate_count -eq 0 -and
    [string]$report.receipt.engine.godot_version -ceq $godotVersion -and
    [string]$report.receipt.engine.godot_runtime_version -ceq
        [string]$preregistration.host_identity.godot_runtime_version -and
    [string]$report.receipt.engine.godot_executable_sha256 -ceq
        $godotExecutableSha256 -and
    -not [bool]$report.receipt.material_robustness -and
    -not [bool]$report.receipt.physical_acceptance_authority
) "$gateId retained report failed final exact reconciliation"

Write-Host (
    "$gateId PHYSICAL_COMPLETE worlds=13 gates=23 accepted=True " +
    "profile_publication_next=True material_robustness=False " +
    "physical_authority=False report=$reportPath"
)
