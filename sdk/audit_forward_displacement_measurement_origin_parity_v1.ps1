#requires -Version 7.0

[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$expectedRemote = "https://github.com/Slagathore/sporespore.git"
$authorityPath = Join-Path $repoRoot (
    "sdk\turning\forward_displacement_measurement_origin_parity_v1.json"
)
$godotPath = Join-Path $repoRoot "scripts\lab\gait\physical_wave_gait_quadruped.gd"
$rapierPath = Join-Path $repoRoot (
    "sdk\adapters\rapier\src\qsdk_r23d3_phase_balanced\r23d27_physical.rs"
)
$mujocoRoot = Join-Path $repoRoot "sdk\adapters\mujoco"
$mujocoPath = Join-Path $mujocoRoot (
    "sporespore_mujoco_adapter\qsdk_r23d3_phase_balanced.py"
)
$mujocoTestPath = Join-Path $mujocoRoot (
    "test_forward_displacement_measurement_origin.py"
)
$mujocoExistingTestPath = Join-Path $mujocoRoot "test_qsdk_r23d3_phase_balanced.py"
$mujocoPython = Join-Path $mujocoRoot ".venv\Scripts\python.exe"
$pythonCoreRoot = Join-Path $repoRoot "sdk\python"
$coreLibrary = Join-Path $repoRoot "sdk\target\debug\sporespore_locomotion_core.dll"
$rapierManifest = Join-Path $repoRoot "sdk\adapters\rapier\Cargo.toml"
$releaseContractPath = Join-Path $repoRoot "sdk\release\quadruped_release_contract.json"
$supportMatrixPath = Join-Path $repoRoot "sdk\release\quadruped_support_matrix.json"

$expectedIdentity = [ordered]@{
    $authorityPath = @(
        "sha256:2894e9c561b82803d2072faf3055a02f3042d596c99f9ade3169f4d1cb6084fb",
        7232
    )
    $godotPath = @(
        "sha256:0205268af835da3c390032a8ecb865779a1ecc756b4d824236fb1ad93cc44c73",
        429155
    )
    $rapierPath = @(
        "sha256:8b6b02bd22ac6f6dfb6c09a2028a244177e50a12fdb5312d48bd45b552d497f6",
        476480
    )
    $mujocoPath = @(
        "sha256:e87c51e56db57600e5d68e88db45b2a9894898d2ebc25f5e8fce1048d8315b98",
        43933
    )
    $mujocoTestPath = @(
        "sha256:eafb74619b2201fe01b8eb2434e3cd2b6dd2609cd0ed684be165c2c2ff06772a",
        6893
    )
}

function Assert-OriginParity([bool]$Condition, [string]$Message) {
    if (-not $Condition) {
        throw "[turning/measurement] origin parity audit: $Message"
    }
}

function Invoke-OriginParityGit([string[]]$Arguments) {
    $lines = @(& git -C $repoRoot @Arguments 2>&1)
    Assert-OriginParity ($LASTEXITCODE -eq 0) (
        "git $($Arguments -join ' ') failed: $($lines -join ' ')"
    )
    return ($lines -join "`n").Trim()
}

function Get-CanonicalLfIdentity([string]$Path) {
    $text = [IO.File]::ReadAllText(
        $Path,
        [Text.UTF8Encoding]::new($false, $true)
    ).Replace("`r`n", "`n").Replace("`r", "`n")
    $bytes = [Text.Encoding]::UTF8.GetBytes($text)
    return [ordered]@{
        sha256 = "sha256:" + [Convert]::ToHexString(
            [Security.Cryptography.SHA256]::HashData($bytes)
        ).ToLowerInvariant()
        byte_length = [long]$bytes.Length
    }
}

function Assert-CommandPassed(
    [string[]]$Lines,
    [int]$ExitCode,
    [string]$Name
) {
    Assert-OriginParity ($ExitCode -eq 0) (
        "$Name failed: $($Lines -join ' ')"
    )
}

Assert-OriginParity (
    (Invoke-OriginParityGit @("rev-parse", "--show-toplevel")) -ceq
        $repoRoot.Replace("\", "/")
) "repository root changed"
Assert-OriginParity (
    (Invoke-OriginParityGit @("remote", "get-url", "origin")) -ceq $expectedRemote
) "repository remote changed"

foreach ($entry in $expectedIdentity.GetEnumerator()) {
    Assert-OriginParity (Test-Path -LiteralPath $entry.Key -PathType Leaf) (
        "required file missing: $($entry.Key)"
    )
    $observed = Get-CanonicalLfIdentity $entry.Key
    Assert-OriginParity (
        [string]$observed.sha256 -ceq [string]$entry.Value[0] -and
        [long]$observed.byte_length -eq [long]$entry.Value[1]
    ) "canonical source identity changed: $($entry.Key)"
}

$authority = Get-Content -LiteralPath $authorityPath -Raw |
    ConvertFrom-Json -AsHashtable -Depth 100
Assert-OriginParity (
    [string]$authority.schema_version -ceq
        "sporespore_forward_displacement_measurement_origin_parity_v1" -and
    [string]$authority.status -ceq
        "implemented_complete_zero_world_source_conformance_passed_physical_not_opened" -and
    [string]$authority.ledger_scope.subsystem -ceq "turning" -and
    [string]$authority.ledger_scope.engine_scope -ceq "3e" -and
    [string]$authority.ledger_scope.question_class -ceq "development" -and
    [string]$authority.source_authority.implementation_parent_commit -ceq
        "faea0fadf31268699ec7c0ef5d96ca549423c0f5"
) "authority identity changed"
Assert-OriginParity (
    [string]$authority.measurement_contract.prospective_policy_id -ceq
        "evidence_window_start_semantic_step_v1" -and
    [int]$authority.measurement_contract.evidence_start_controller_semantic_step -eq 472 -and
    [int]$authority.measurement_contract.turn_command_start_semantic_step -eq 600 -and
    [int]$authority.measurement_contract.last_selected_profile_task_frame_reanchor_semantic_step -eq 2400 -and
    -not [bool]$authority.measurement_contract.controller_task_frame_reanchors_change_measurement_origin -and
    -not [bool]$authority.measurement_contract.controller_task_frame_reanchors_changed -and
    -not [bool]$authority.measurement_contract.terminal_threshold_changed -and
    -not [bool]$authority.measurement_contract.selector_changed -and
    -not [bool]$authority.measurement_contract.evaluator_changed -and
    -not [bool]$authority.measurement_contract.historical_report_changed
) "measurement contract changed"
Assert-OriginParity (
    [int]$authority.complete_engine_population.declared_engine_count -eq 3 -and
    [int]$authority.complete_engine_population.source_conforming_engine_count -eq 3 -and
    -not [bool]$authority.complete_engine_population.sampled -and
    [bool]$authority.complete_engine_population.engines.rapier_parry.historical_execution_plans_remain_legacy -and
    [bool]$authority.complete_engine_population.engines.mujoco.default_preflight_and_physical_routes_remain_legacy
) "complete producer population changed"
Assert-OriginParity (
    @($authority.zero_world_conformance.negative_control_classes).Count -eq 8 -and
    [int]$authority.zero_world_conformance.model_construction_count -eq 0 -and
    [int]$authority.zero_world_conformance.world_attempt_count -eq 0 -and
    [int]$authority.zero_world_conformance.world_build_count -eq 0 -and
    [int]$authority.zero_world_conformance.solver_step_count -eq 0 -and
    -not [bool]$authority.zero_world_conformance.physical_execution_authorized -and
    -not [bool]$authority.zero_world_conformance.physical_acceptance_authority
) "zero-world conformance boundary changed"
Assert-OriginParity (
    [bool]$authority.historical_preservation.legacy_measurement_is_still_the_default -and
    [bool]$authority.historical_preservation.prospective_opt_in_required -and
    -not [bool]$authority.historical_preservation.r23d71_official_result_changed -and
    -not [bool]$authority.historical_preservation.r23d71_threshold_changed -and
    -not [bool]$authority.historical_preservation.r23d71_selector_changed -and
    -not [bool]$authority.historical_preservation.r23d71_evaluator_changed -and
    -not [bool]$authority.historical_preservation.r23d71_interpretation_changed -and
    -not [bool]$authority.historical_preservation.same_identity_rerun_performed -and
    -not [bool]$authority.historical_preservation.retained_evidence_rewritten
) "historical preservation changed"
Assert-OriginParity (
    [bool]$authority.claims.prospective_measurement_origin_source_parity -and
    -not [bool]$authority.claims.historical_result_reinterpreted -and
    -not [bool]$authority.claims.finite_three_engine_turning -and
    -not [bool]$authority.claims.portable_basic_turning -and
    -not [bool]$authority.claims.q_sdk_r23_satisfied -and
    -not [bool]$authority.claims.cross_engine_physical_equivalence -and
    -not [bool]$authority.claims.population_robustness -and
    -not [bool]$authority.claims.arbitrary_quadruped_coverage -and
    -not [bool]$authority.claims.prone_to_standing -and
    -not [bool]$authority.claims.physical_acceptance_authority -and
    -not [bool]$authority.claims.release_authorized -and
    [string]$authority.next_work.release_score_before -ceq "10/25" -and
    [string]$authority.next_work.release_score_after -ceq "10/25"
) "claim or release-score boundary changed"

$releaseContract = Get-Content -LiteralPath $releaseContractPath -Raw |
    ConvertFrom-Json -AsHashtable -Depth 100
$supportMatrix = Get-Content -LiteralPath $supportMatrixPath -Raw |
    ConvertFrom-Json -AsHashtable -Depth 100
$turningGates = @(
    $releaseContract.gates | Where-Object { $_.gate_id -ceq "QSDK-R23" }
)
Assert-OriginParity ($turningGates.Count -eq 1) "QSDK-R23 release gate changed"
$releaseParity = $turningGates[0].proof.current_forward_displacement_measurement_origin_parity
$supportParity = $supportMatrix.locomotion_modes.forward_displacement_measurement_origin_parity_v1
foreach ($projection in @($releaseParity, $supportParity)) {
    Assert-OriginParity (
        [string]$projection.implementation_id -ceq [string]$authority.implementation_id -and
        [string]$projection.status -ceq [string]$authority.status -and
        [string]$projection.question_class -ceq "development" -and
        [string]$projection.authority_path -ceq
            "sdk/turning/forward_displacement_measurement_origin_parity_v1.json" -and
        [string]$projection.authority_canonical_lf_sha256 -ceq
            [string]$expectedIdentity[$authorityPath][0] -and
        [int]$projection.declared_native_producer_count -eq 3 -and
        [int]$projection.source_conforming_native_producer_count -eq 3 -and
        [int]$projection.evidence_window_origin_semantic_step -eq 472 -and
        [int]$projection.rapier_focused_test_count -eq 2 -and
        [int]$projection.mujoco_focused_and_existing_test_count -eq 8 -and
        [int]$projection.negative_control_class_count -eq 8 -and
        [int]$projection.model_construction_count -eq 0 -and
        [int]$projection.world_attempt_count -eq 0 -and
        [int]$projection.world_build_count -eq 0 -and
        [int]$projection.solver_step_count -eq 0 -and
        [bool]$projection.historical_routes_remain_legacy_by_default -and
        [bool]$projection.prospective_opt_in_required -and
        [bool]$projection.measurement_origin_source_repair_complete -and
        -not [bool]$projection.historical_r23d71_result_changed -and
        [string]$projection.next_work_class -ceq
            "mujoco_pre_turn_stability_development" -and
        -not [bool]$projection.new_finite_turning_decision_authorized -and
        -not [bool]$projection.q_sdk_r23_satisfied -and
        [string]$projection.release_score_before -ceq "10/25" -and
        [string]$projection.release_score_after -ceq "10/25" -and
        -not [bool]$projection.physical_acceptance_authority -and
        -not [bool]$projection.release_authorized
    ) "release or support projection changed"
}
Assert-OriginParity (
    [string]$turningGates[0].proof.current_transport_development_successor.next_work_class -ceq
        "mujoco_pre_turn_stability_development" -and
    [string]$turningGates[0].proof.current_r23d71_measurement_origin_diagnosis.next_work_class -ceq
        "prospective_measurement_origin_repair_then_mujoco_pre_turn_stability_development" -and
    [string]$supportMatrix.locomotion_modes.three_engine_turning_success_transport_route_v2.next_work_class -ceq
        "mujoco_pre_turn_stability_development" -and
    [string]$supportMatrix.locomotion_modes.r23d71_measurement_origin_diagnosis_v1.next_work_class -ceq
        "prospective_measurement_origin_repair_then_mujoco_pre_turn_stability_development"
) "live next-work projection changed"

$godotSource = Get-Content -LiteralPath $godotPath -Raw
$rapierSource = Get-Content -LiteralPath $rapierPath -Raw
$mujocoSource = Get-Content -LiteralPath $mujocoPath -Raw
Assert-OriginParity (
    $godotSource.Contains(
        "torso.global_position - evidence_start_torso_position"
    )
) "Godot evidence-window measurement origin missing"
Assert-OriginParity (
    $rapierSource.Contains(
        "EvidenceWindowStart { semantic_step: u64 }"
    ) -and
    $rapierSource.Contains(
        '"task_frame_reanchors_change_measurement_origin": false'
    ) -and
    ([regex]::Matches(
        $rapierSource,
        "ForwardDisplacementMeasurementOriginPlan::LegacyMutableTaskFrame,"
    ).Count -ge 8)
) "Rapier opt-in or historical default missing"
Assert-OriginParity (
    $mujocoSource.Contains(
        "EVIDENCE_WINDOW_START_SEMANTIC_STEP = 472"
    ) -and
    $mujocoSource.Contains(
        "forward_displacement_measurement_origin_plan"
    ) -and
    $mujocoSource.Contains(
        '"task_frame_reanchors_change_measurement_origin": False'
    )
) "MuJoCo opt-in or immutable-origin receipt missing"

$rustLines = @(
    & cargo test --manifest-path $rapierManifest --lib forward_measurement -- --nocapture 2>&1
)
$rustExitCode = $LASTEXITCODE
Assert-CommandPassed $rustLines $rustExitCode "Rapier focused tests"
$rustOutput = $rustLines -join "`n"
Assert-OriginParity (
    $rustOutput -match "2 passed; 0 failed" -and
    $rustOutput -match "197 filtered out"
) "Rapier test population changed"

Assert-OriginParity (Test-Path -LiteralPath $mujocoPython -PathType Leaf) (
    "locked MuJoCo Python missing: $mujocoPython"
)
Assert-OriginParity (Test-Path -LiteralPath $coreLibrary -PathType Leaf) (
    "debug locomotion core missing: $coreLibrary"
)
$savedPythonPath = [Environment]::GetEnvironmentVariable("PYTHONPATH", "Process")
$savedLibrary = [Environment]::GetEnvironmentVariable(
    "SPORESPORE_LOCOMOTION_LIBRARY",
    "Process"
)
try {
    $env:PYTHONDONTWRITEBYTECODE = "1"
    $env:PYTHONPATH = $mujocoRoot + [IO.Path]::PathSeparator + $pythonCoreRoot
    $env:SPORESPORE_LOCOMOTION_LIBRARY = $coreLibrary
    Push-Location $mujocoRoot
    try {
        $mujocoLines = @(
            & $mujocoPython -B -m unittest -v (
                [IO.Path]::GetFileName($mujocoExistingTestPath)
            ) (
                [IO.Path]::GetFileName($mujocoTestPath)
            ) 2>&1
        )
        $mujocoExitCode = $LASTEXITCODE
    } finally {
        Pop-Location
    }
} finally {
    [Environment]::SetEnvironmentVariable("PYTHONPATH", $savedPythonPath, "Process")
    [Environment]::SetEnvironmentVariable(
        "SPORESPORE_LOCOMOTION_LIBRARY",
        $savedLibrary,
        "Process"
    )
}
Assert-CommandPassed $mujocoLines $mujocoExitCode "MuJoCo focused tests"
$mujocoOutput = $mujocoLines -join "`n"
Assert-OriginParity (
    $mujocoOutput -match "Ran 8 tests" -and
    $mujocoOutput -match "OK"
) "MuJoCo test population changed"

$fmtLines = @(& cargo fmt --manifest-path $rapierManifest -- --check 2>&1)
Assert-CommandPassed $fmtLines $LASTEXITCODE "Rapier formatting check"
$diffLines = @(& git -C $repoRoot diff --check 2>&1)
Assert-CommandPassed $diffLines $LASTEXITCODE "working diff check"

Write-Output (
    "[turning/measurement] forward-displacement origin parity PASS: " +
    "3/3 native producer sources, 2 Rapier + 8 MuJoCo tests, " +
    "8 negative-control classes, 0 models/worlds/solver steps"
)
