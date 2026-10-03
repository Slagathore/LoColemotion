#requires -Version 7.0

[CmdletBinding()]
param(
    [switch]$SkipGodotExecution,
    [switch]$SkipSupervisorPreflight,
    [string]$Godot = (
        "C:\Users\Cole\CodeStuff\Misc\Godot\" +
        "Godot_v4.7-stable_mono_win64_console.exe"
    ),
    [string]$LogRoot = (
        Join-Path $env:TEMP "sporespore_bw20f_material_locomotion_freeze"
    )
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [System.IO.Path]::GetFullPath(
    (Split-Path -Parent $PSScriptRoot)
)
$sdkRoot = Join-Path $repoRoot "sdk"
$campaignId = "BW20F-BW19V-COLD-MATERIAL-LOCOMOTION"
$gateId = "BW20F-LOCOMOTION"
$implementationParentCommit = "283a868e24dbbe87661289560fd3a06cba31f8e6"
$preregistrationPath = Join-Path (
    $sdkRoot
) "balanced_wave_bw20f_material_locomotion_preregistration.json"
$productionGatePath = Join-Path (
    $sdkRoot
) "balanced_wave_bw20f_material_locomotion_gate.ps1"
$gateTestPath = Join-Path $repoRoot "tests\test_bw20f_material_locomotion_gate.ps1"
$physicalHarnessPath = Join-Path (
    $repoRoot
) "tests\test_sdk_balanced_wave_bw20f_material_locomotion.gd"
$supervisorPath = Join-Path (
    $sdkRoot
) "run_balanced_wave_bw20f_material_locomotion.ps1"
$closurePath = Join-Path (
    $sdkRoot
) "balanced_wave_bw20f_material_locomotion_closure.json"
$stage1ReportPath = [System.IO.Path]::GetFullPath(
    "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence\" +
    "balanced-wave-bw20f-material-characterization-476aa4e\report.json"
)
$stage2ReportPath = [System.IO.Path]::GetFullPath(
    "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence\" +
    "balanced-wave-bw20f-material-profiles-cf9431e\report.json"
)
$frozenFiles = [ordered]@{
    "sdk/balanced_wave_bw20f_material_locomotion_preregistration.json" =
        "fc3749e6ce0d7a68603884c89e0ac8d5060aef8f419a375cb1ab3db39975797d"
    "sdk/balanced_wave_bw20f_material_locomotion_gate.ps1" =
        "354bc346d39774eda41c1c56672c932266a0c6978c535f9c0e7e22616c303257"
    "tests/test_bw20f_material_locomotion_gate.ps1" =
        "29755f581b17b81f6896655315203d5c5c74904087d47442bae9819fd0d92cb2"
    "tests/test_sdk_balanced_wave_bw20f_material_locomotion.gd" =
        "462f5bb05bf75dd437112da13e72692decd007f2edb9c6bf37b176394b0984d5"
    "sdk/run_balanced_wave_bw20f_material_locomotion.ps1" =
        "239fc45ae29fd5bdc7b3cb14dab0c84504dc8e00d726e50cd8be93853f342ca9"
    "sdk/balanced_wave_bw20f_cold_material_preregistration.json" =
        "7f90a75611c34dd27c3e2a6f1b04b30a58368be9d9871075fb6ef1d0d2caf999"
    "sdk/balanced_wave_bw20f_material_characterization_closure.json" =
        "68d1ba699d1dcfd9b190423fd542b18843823374cdd8f69029c4e05548e3bf2a"
    "sdk/balanced_wave_bw20f_material_profile_publication_closure.json" =
        "d5e08e0602f745e78b1c34cc10a95f1399a969f9ccab0fd62ff68f6a53e25f1e"
    "sdk/balanced_wave_bw19v_closure_manifest.json" =
        "ea8df6a574e1b9be1050afa8ed57982a102982ada0f0d5babccf3c937c7067f7"
    "sdk/balanced_wave_bw19v_validation_candidates.json" =
        "02124811891638efaad30fc6e04b3a10b600a5eab913984c1d4c8abbd1a963a3"
    "sdk/balanced_wave_bw15f_selected_policy.json" =
        "6e114c809df93ff6b7059a9e203ae1538f2f6a12a45cadc6760f379bf1c99bed"
    "scripts/lab/gait/sdk_godot_jolt_material_profiles.gd" =
        "6344363c1218a85ffd5bed79b00e9615a74456f31787c2a8e5c48272e044255d"
    "tests/test_sdk_balanced_wave_bw19v_independent_validation.gd" =
        "4024bb8135c5f2b9feccc8c6501fdacfade8d63cfe382937dae4cae5c28ae7c6"
    "tests/test_sdk_qsdk_independent_morphology_v2.gd" =
        "3365582b076ccaedf2ec5a4562abed006f42a89af85be9193436f94e179ba90e"
    "scripts/lab/gait/physical_wave_gait_quadruped.gd" =
        "9bdd7c3098116f2a94a4fb704ca951eea3eab49b7b490edb8ca64e62cfba1ba0"
    "scripts/lab/gait/sdk_godot_jolt_adapter.gd" =
        "5cf58a7d89a385b3cf9e37c62a6d27f2e13f6f644a0bcbe9d972ce70d274d2b1"
    "scripts/lab/gait/physical_quadruped_fixture_spec.gd" =
        "6e005493982a55c113706101b1e4b3ab857473becbbea03ee48ba213b4d3b050"
    "scripts/lab/gait/physical_gait_clock_spec.gd" =
        "55a8495f16842808487eccdfbc6bd695ef385d807c2221ab5a9c01017ed137d3"
}
$expectedProfileIds = @(
    "godot_jolt_bw20f_mu009_v1",
    "godot_jolt_bw20f_mu037_v1",
    "godot_jolt_bw20f_mu076_v1",
    "godot_jolt_bw20f_mu118_v1"
)
$expectedProfileDigests = @(
    "sha256:92891cfbed2b30c5d6c72fa02a30770fcf75880416a92fe2f69d9ece8246ee55",
    "sha256:690e5c2f035a7a3efc32fa31c86cfab03299f8c539500e110b5ddf9e35b6dfb9",
    "sha256:76f42bc89da95e09d081d17d5e3aa520de25fa6a352067dd8c30ace3834667b0",
    "sha256:e0c6a6d78ae63a129e7ae44088aeb86da44941dba8cfcfd5680f73a236c9b297"
)

function Assert-Exact {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) {
        throw $Message
    }
}

function Get-RawSha256 {
    param([Parameter(Mandatory)][string]$Path)
    return (
        Get-FileHash -Algorithm SHA256 -LiteralPath $Path
    ).Hash.ToLowerInvariant()
}

function Assert-SourceContains {
    param(
        [Parameter(Mandatory)][string]$Source,
        [Parameter(Mandatory)][string[]]$Needles,
        [Parameter(Mandatory)][string]$Label
    )
    foreach ($needle in $Needles) {
        Assert-Exact (
            $Source.Contains($needle, [StringComparison]::Ordinal)
        ) "$gateId $Label lost required surface: $needle"
    }
}

function Invoke-ExpectedFailure {
    param(
        [Parameter(Mandatory)][string[]]$Arguments,
        [Parameter(Mandatory)][string]$ExpectedText,
        [Parameter(Mandatory)][string]$Label
    )
    $output = (& pwsh @Arguments 2>&1 | Out-String)
    $exitCode = $LASTEXITCODE
    Assert-Exact (
        $exitCode -ne 0 -and
        $output.Contains($ExpectedText, [StringComparison]::Ordinal)
    ) "$gateId $Label negative control did not fail closed"
}

Assert-Exact (
    -not ($SkipGodotExecution -and -not $SkipSupervisorPreflight)
) "$gateId -SkipGodotExecution requires -SkipSupervisorPreflight"

foreach ($entry in $frozenFiles.GetEnumerator()) {
    $path = Join-Path $repoRoot $entry.Key
    Assert-Exact (
        (Test-Path -LiteralPath $path -PathType Leaf) -and
        (Get-RawSha256 -Path $path) -ceq [string]$entry.Value
    ) "$gateId frozen source or prerequisite changed: $($entry.Key)"
}
Assert-Exact (
    (Test-Path -LiteralPath $stage1ReportPath -PathType Leaf) -and
    (Get-RawSha256 -Path $stage1ReportPath) -ceq
        "f0a279fb9660554a0d4997c6b8adb5c767bc3f92f2497694448429f142155030" -and
    (Test-Path -LiteralPath $stage2ReportPath -PathType Leaf) -and
    (Get-RawSha256 -Path $stage2ReportPath) -ceq
        "96ef9fd50da7e92b668d9552ebf821d8fe02fa8ab0a2247b93cda0a48115968f"
) "$gateId retained prerequisite report is missing or changed"
Assert-Exact (
    -not (Test-Path -LiteralPath $closurePath -PathType Leaf)
) "$gateId is already closed and is no longer prospective"

foreach ($scriptPath in @($productionGatePath, $gateTestPath, $supervisorPath)) {
    [void][scriptblock]::Create((Get-Content -Raw -LiteralPath $scriptPath))
}

$manifest = Get-Content -Raw -LiteralPath $preregistrationPath |
    ConvertFrom-Json -AsHashtable
$study = $manifest.study_class
$matrix = $manifest.matrix
$cells = @($matrix.ordered_cells)
$gate = $manifest.gate_contract
$preflight = $manifest.preflight_contract
$interlocks = $manifest.staged_interlocks
$claimsBefore = $manifest.claims_before_result
$claimsAfter = $manifest.claims_if_accepted
Assert-Exact (
    [string]$manifest.schema_version -ceq
        "sporespore_balanced_wave_bw20f_material_locomotion_preregistration_v1" -and
    [string]$manifest.status -ceq
        "frozen_before_first_bw20f_material_locomotion_world" -and
    [string]$manifest.campaign_id -ceq $campaignId -and
    [string]$manifest.gate_id -ceq $gateId -and
    [string]$manifest.implementation_parent_commit -ceq
        $implementationParentCommit -and
    [string]$study.classification -ceq
        "exact_finite_cell_material_acceptance_decision" -and
    [bool]$study.finite_decision -and
    -not [bool]$study.development_screen -and
    -not [bool]$study.population_inference -and
    -not [bool]$study.superiority_study -and
    -not [bool]$study.noninferiority_or_equivalence_study -and
    [bool]$study.treatment_need_not_outperform_control -and
    -not [bool]$study.terminal_outcome_separation_gate
) "$gateId prospective identity or finite noncomparative study class changed"

Assert-Exact (
    $cells.Count -eq 17 -and
    [int]$matrix.treatment_world_count -eq 12 -and
    [int]$matrix.control_world_count -eq 4 -and
    [int]$matrix.zero_friction_safety_world_count -eq 1 -and
    [int]$matrix.expected_world_count -eq 17 -and
    (@($manifest.profiles | ForEach-Object {
        [string]$_.profile_id
    }) -join "|") -ceq ($expectedProfileIds -join "|") -and
    (@($manifest.profiles | ForEach-Object {
        [string]$_.profile_digest
    }) -join "|") -ceq ($expectedProfileDigests -join "|") -and
    (@($cells | ForEach-Object { [int]$_.campaign_seed } | Select-Object -Unique) -join ",") -ceq
        "23001,23002,23003" -and
    @($cells | Where-Object { [string]$_.role -ceq "treatment" }).Count -eq 12 -and
    @($cells | Where-Object { [string]$_.role -ceq "control" }).Count -eq 4 -and
    @($cells | Where-Object { [string]$_.role -ceq "safety" }).Count -eq 1
) "$gateId matrix, profiles, seeds, or role cardinality changed"
foreach ($cell in $cells) {
    if ([string]$cell.role -ceq "treatment") {
        Assert-Exact (
            [string]$cell.candidate_id -ceq "BW19V-B" -and
            [double]$cell.global_requested_correction_scale -eq 0.5
        ) "$gateId treatment identity changed"
    } elseif ([string]$cell.role -ceq "control") {
        Assert-Exact (
            [string]$cell.candidate_id -ceq "BW19V-A" -and
            [double]$cell.global_requested_correction_scale -eq 0.0
        ) "$gateId control identity changed"
    } else {
        Assert-Exact (
            [string]$cell.cell_id -ceq "negative_mu000_s23001_safety" -and
            [string]$cell.profile_id -ceq "godot_jolt_p5m1r1_mu000_v1"
        ) "$gateId safety identity changed"
    }
}

Assert-Exact (
    [int]$gate.expected_gate_count -eq 28 -and
    [int]$gate.pre_matrix_gate_count -eq 3 -and
    [int]$gate.per_world_execution_integrity_gate_count -eq 17 -and
    [int]$gate.aggregate_gate_count -eq 8 -and
    -not [bool]$gate.treatment_outcome_superiority_required -and
    -not [bool]$gate.terminal_position_separation_required -and
    [bool]$gate.averaging_forbidden -and
    [bool]$gate.outcome_based_early_stop_forbidden -and
    [bool]$gate.selective_cell_rerun_forbidden -and
    [bool]$gate.failed_cell_replacement_forbidden -and
    [bool]$gate.post_result_gate_edit_forbidden -and
    [bool]$gate.first_complete_result_is_final_for_this_source_identity
) "$gateId gate count, stopping rule, or noncomparative boundary changed"
Assert-Exact (
    [bool]$preflight.production_evaluator_must_accept_a_perfect_serialized_17_cell_result -and
    [bool]$preflight.complete_gate_must_run_before_attempt_receipt_and_before_first_world -and
    [bool]$preflight.real_adapter_entrypoint_must_preflight_all_17_cells_without_worlds -and
    [int]$preflight.world_build_count -eq 0 -and
    [int]$preflight.scene_tree_insertion_count -eq 0 -and
    [int]$preflight.physics_state_mutation_count -eq 0 -and
    -not [bool]$preflight.locomotion_outcome_exposed -and
    -not [bool]$preflight.physical_acceptance_authority -and
    [bool]$interlocks.physical_run_requires_clean_pushed_source_matching_live_github_main -and
    [bool]$interlocks.attempt_receipt_must_be_written_before_first_physical_process -and
    [bool]$interlocks.each_world_runs_in_a_fresh_isolated_process -and
    [bool]$interlocks.all_seventeen_cell_attempts_are_retained_even_if_a_cell_fails -and
    -not [bool]$interlocks.same_identity_rerun_allowed
) "$gateId whole-gate preflight or supervisor interlock changed"

foreach ($claimName in $claimsBefore.Keys) {
    Assert-Exact (
        -not [bool]$claimsBefore[$claimName]
    ) "$gateId prospective claim inflated before physical result: $claimName"
}
Assert-Exact (
    [bool]$claimsAfter.exact_finite_godot_jolt_bw19v_b_material_acceptance -and
    [bool]$claimsAfter.walking_acceptance_for_all_twelve_declared_treatment_cells -and
    [bool]$claimsAfter.bounded_discrete_material_robustness -and
    [bool]$claimsAfter.material_robustness -and
    -not [bool]$claimsAfter.continuous_friction_coverage -and
    -not [bool]$claimsAfter.arbitrary_material_robustness -and
    -not [bool]$claimsAfter.population_inference -and
    -not [bool]$claimsAfter.superiority -and
    -not [bool]$claimsAfter.cross_engine_equivalence -and
    -not [bool]$claimsAfter.release_authorized -and
    -not [bool]$claimsAfter.physical_acceptance_authority
) "$gateId conditional claim scope changed"

$gateSource = Get-Content -Raw -LiteralPath $productionGatePath
$harnessSource = Get-Content -Raw -LiteralPath $physicalHarnessPath
$supervisorSource = Get-Content -Raw -LiteralPath $supervisorPath
Assert-SourceContains $gateSource @(
    'function Test-Bw20fMaterialLocomotionResult',
    'function New-Bw20fPerfectSyntheticMaterialLocomotionResult',
    'expected_gate_count = 28',
    'paired_identity_and_policy_contrast',
    'no treatment-outcome superiority or terminal-separation gate is evaluated',
    'continuous_friction_coverage = $false',
    'physical_acceptance_authority = $false'
) "production evaluator"
Assert-SourceContains $harnessSource @(
    'extends "res://tests/test_sdk_balanced_wave_bw19v_independent_validation.gd"',
    'func _physical_authorization_exact',
    'physical entry requires the supervisor',
    'func _run_bw20f_entrypoint_preflight',
    'func _bw20f_physical_cell_receipt',
    'func _zero_safety_receipt',
    '"stability_influence_global_scale": _candidate_global_scale()',
    '"walking_claim_authorized": false'
) "physical harness"
Assert-SourceContains $supervisorSource @(
    '[bool]$PreflightOnly -xor [bool]$RunPhysical',
    '$gateId -RunPhysical requires an explicit durable OutputRoot',
    'status --porcelain=v1 --untracked-files=all',
    'ls-remote origin refs/heads/main',
    'requires clean source with HEAD equal to live GitHub main',
    'complete_zero_world_gate_passed = $true',
    'physical_identity_consumed = $true',
    'same_identity_rerun_allowed = $false',
    'foreach ($cell in $cells)',
    'Test-Bw20fMaterialLocomotionResult -Result $rawResult',
    'first complete physical result was retained and rejected'
) "physical supervisor"

$evidenceRoot = [System.IO.Path]::GetFullPath(
    (Join-Path (Split-Path -Parent $repoRoot) "SporeSpore_Evidence")
)
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
) "$gateId prior physical attempt exists; prospective freeze is invalid"

& pwsh -NoProfile -File $gateTestPath
Assert-Exact (
    $LASTEXITCODE -eq 0
) "$gateId complete production evaluator and canary test failed"

Invoke-ExpectedFailure `
    -Arguments @("-NoProfile", "-File", $supervisorPath, "-RunPhysical") `
    -ExpectedText "$gateId -RunPhysical requires an explicit durable OutputRoot" `
    -Label "missing durable output root"

if (-not $SkipSupervisorPreflight) {
    & pwsh `
        -NoProfile `
        -File $supervisorPath `
        -PreflightOnly `
        -Godot $Godot `
        -LogRoot (Join-Path $LogRoot "supervisor")
    Assert-Exact (
        $LASTEXITCODE -eq 0
    ) "$gateId supervisor whole-gate preflight failed"
}

$bypassCanaryCount = 1
if (-not $SkipGodotExecution) {
    $godotPath = [System.IO.Path]::GetFullPath($Godot)
    Assert-Exact (
        (Test-Path -LiteralPath $godotPath -PathType Leaf) -and
        (Get-RawSha256 -Path $godotPath) -ceq
            "c5fc2d0bb24826a6757fa1e6bf2991effb294859c7dd03d09a122ef217484896"
    ) "$gateId pinned Godot executable changed"
    $projectRoot = Join-Path (
        [System.IO.Path]::GetFullPath($LogRoot)
    ) ("bypass-project-" + [Guid]::NewGuid().ToString("N"))
    [void][System.IO.Directory]::CreateDirectory($projectRoot)
    foreach ($directory in @("scripts", "tests", "sdk")) {
        [void](New-Item `
            -ItemType Junction `
            -Path (Join-Path $projectRoot $directory) `
            -Target (Join-Path $repoRoot $directory))
    }
    $projectText = @"
config_version=5
[application]
config/name="sporespore-bw20f-locomotion-bypass-canary"
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
    $previousAttempt = $env:SPORESPORE_BW20F_LOCOMOTION_ATTEMPT
    $previousToken = $env:SPORESPORE_BW20F_LOCOMOTION_TOKEN
    $previousCell = $env:SPORESPORE_BW20F_LOCOMOTION_CELL
    try {
        Remove-Item Env:SPORESPORE_BW20F_LOCOMOTION_ATTEMPT -ErrorAction SilentlyContinue
        Remove-Item Env:SPORESPORE_BW20F_LOCOMOTION_TOKEN -ErrorAction SilentlyContinue
        Remove-Item Env:SPORESPORE_BW20F_LOCOMOTION_CELL -ErrorAction SilentlyContinue
        $directOutput = (& $godotPath `
            --headless `
            --path $projectRoot `
            --script "res://tests/test_sdk_balanced_wave_bw20f_material_locomotion.gd" `
            -- physical "validation_mu009_s23001_treatment" 2>&1 | Out-String)
        $directExitCode = $LASTEXITCODE
        Assert-Exact (
            $directExitCode -ne 0 -and
            $directOutput.Contains(
                "physical entry requires the supervisor's exact retained attempt authorization",
                [StringComparison]::Ordinal
            ) -and
            -not $directOutput.Contains(
                "BW20F_MATERIAL_LOCOMOTION_CELL ",
                [StringComparison]::Ordinal
            )
        ) "$gateId direct physical-worker bypass did not fail before a world"
        $bypassCanaryCount += 1

        $env:SPORESPORE_BW20F_LOCOMOTION_ATTEMPT = Join-Path (
            $projectRoot
        ) "nonexistent-attempt.json"
        $env:SPORESPORE_BW20F_LOCOMOTION_TOKEN = "forged"
        $env:SPORESPORE_BW20F_LOCOMOTION_CELL =
            "validation_mu009_s23001_treatment"
        $forgedOutput = (& $godotPath `
            --headless `
            --path $projectRoot `
            --script "res://tests/test_sdk_balanced_wave_bw20f_material_locomotion.gd" `
            -- physical "validation_mu009_s23001_treatment" 2>&1 | Out-String)
        $forgedExitCode = $LASTEXITCODE
        Assert-Exact (
            $forgedExitCode -ne 0 -and
            $forgedOutput.Contains(
                "physical entry requires the supervisor's exact retained attempt authorization",
                [StringComparison]::Ordinal
            ) -and
            -not $forgedOutput.Contains(
                "BW20F_MATERIAL_LOCOMOTION_CELL ",
                [StringComparison]::Ordinal
            )
        ) "$gateId forged physical-worker authorization did not fail before a world"
        $bypassCanaryCount += 1
    } finally {
        if ($null -eq $previousAttempt) {
            Remove-Item Env:SPORESPORE_BW20F_LOCOMOTION_ATTEMPT -ErrorAction SilentlyContinue
        } else { $env:SPORESPORE_BW20F_LOCOMOTION_ATTEMPT = $previousAttempt }
        if ($null -eq $previousToken) {
            Remove-Item Env:SPORESPORE_BW20F_LOCOMOTION_TOKEN -ErrorAction SilentlyContinue
        } else { $env:SPORESPORE_BW20F_LOCOMOTION_TOKEN = $previousToken }
        if ($null -eq $previousCell) {
            Remove-Item Env:SPORESPORE_BW20F_LOCOMOTION_CELL -ErrorAction SilentlyContinue
        } else { $env:SPORESPORE_BW20F_LOCOMOTION_CELL = $previousCell }
    }
}

Write-Host (
    "$gateId FREEZE_PASS worlds=0 production_gates=28 cells=17 " +
    "treatments=12 controls=4 safety=1 profiles=4 seeds=3 canaries=12 " +
    "bypass_canaries=$bypassCanaryCount terminal_separation_gate=False " +
    "superiority=False material_robustness=False physical_authority=False"
)
