#requires -Version 7.0

[CmdletBinding()]
param(
    [string]$Godot = (
        "C:\Users\Cole\CodeStuff\Misc\Godot\" +
        "Godot_v4.7-stable_mono_win64_console.exe"
    )
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$sdkRoot = Join-Path $repoRoot "sdk"
$declarationPath = Join-Path $sdkRoot (
    "turning\r23d15_composition_recovery_preregistration_v1.json"
)
$closurePath = Join-Path $sdkRoot "turning\r23d14_physical_closure_v1.json"
$closureAuditPath = Join-Path $repoRoot "tests\test_qsdk_r23d14_closure.ps1"
$wavePath = Join-Path $repoRoot "scripts\lab\gait\physical_wave_gait_quadruped.gd"
$rapierModulePath = Join-Path $sdkRoot (
    "adapters\rapier\src\qsdk_r23d15_composition_recovery.rs"
)
$rapierPhysicalPath = Join-Path $sdkRoot (
    "adapters\rapier\src\qsdk_r23d3_phase_balanced\r23d14_physical.rs"
)
$rapierBinarySource = Join-Path $sdkRoot (
    "adapters\rapier\src\bin\qsdk_r23d15_composition_recovery.rs"
)
$rapierBinary = Join-Path $sdkRoot "target\debug\qsdk_r23d15_composition_recovery.exe"
$godotCanary = "res://tests/test_sdk_qsdk_r23d15_composition_recovery.gd"
$manifest = Join-Path $sdkRoot "Cargo.toml"
$attributesPath = Join-Path $repoRoot ".gitattributes"
$stageId = "finite_three_engine_confirmation_recovery"
$campaignId = (
    "QSDK-R23D15-PRODUCTION-COMPOSITION-RECOVERY-" +
    "THREE-ENGINE-TURN-CONFIRMATION"
)

function Assert-R23D15([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

function Get-R23D15Sha256([string]$Path) {
    return "sha256:" + (
        Get-FileHash -Algorithm SHA256 -LiteralPath $Path
    ).Hash.ToLowerInvariant()
}

function Read-R23D15Marker([string]$Text, [string]$Prefix) {
    $matches = @(($Text -split "\r?\n") | Where-Object {
        $_.StartsWith($Prefix, [StringComparison]::Ordinal)
    })
    Assert-R23D15 ($matches.Count -eq 1) "Expected exactly one $Prefix marker"
    return $matches[0].Substring($Prefix.Length) |
        ConvertFrom-Json -AsHashtable -Depth 100
}

$root = (& git -C $repoRoot rev-parse --show-toplevel).Trim().Replace("/", "\")
$origin = (& git -C $repoRoot remote get-url origin).Trim()
Assert-R23D15 (
    $root -ceq "C:\Users\Cole\CodeStuff\games\SporeSpore" -and
    $origin -ceq "https://github.com/Slagathore/sporespore.git"
) "QSDK-R23D15 repository identity mismatch"

foreach ($path in @(
    $Godot, $attributesPath, $declarationPath, $closurePath, $closureAuditPath, $wavePath,
    $rapierModulePath, $rapierPhysicalPath, $rapierBinarySource, $manifest,
    (Join-Path $repoRoot "tests\test_sdk_qsdk_r23d15_composition_recovery.gd")
)) {
    Assert-R23D15 (Test-Path -LiteralPath $path -PathType Leaf) (
        "QSDK-R23D15 required input missing: $path"
    )
}

$declaration = Get-Content -Raw -LiteralPath $declarationPath |
    ConvertFrom-Json -AsHashtable -Depth 100
Assert-R23D15 (
    [string]$declaration.schema_version -ceq
        "sporespore_qsdk_r23d15_composition_recovery_preregistration_v1" -and
    [string]$declaration.status -ceq
        "prospective_stage_zero_repair_implemented_zero_world_only" -and
    [string]$declaration.campaign_id -ceq $campaignId -and
    [string]$declaration.gate_id -ceq "QSDK-R23D15" -and
    [string]$declaration.release_gate_id -ceq "QSDK-R23" -and
    [string]$declaration.study_classification -ceq (
        "prospective_exact_finite_three_engine_confirmation_after_invalid_" +
        "predecessor_implementation_recovery"
    )
) "QSDK-R23D15 declaration identity changed"

$lineage = $declaration.lineage
$closure = Get-Content -Raw -LiteralPath $closurePath |
    ConvertFrom-Json -AsHashtable -Depth 100
Assert-R23D15 (
    [string]$lineage.immutable_predecessor_gate_id -ceq "QSDK-R23D14" -and
    [string]$lineage.predecessor_physical_source_commit -ceq
        "3ead7ec5220e50097a5a0c5ac89ba45db594431a" -and
    [string]$lineage.predecessor_physical_closure_commit -ceq
        "24ca52c4a2450184285f31e9f425155b4ae7b52e" -and
    (Get-R23D15Sha256 $closurePath) -ceq
        [string]$lineage.predecessor_closure_raw_sha256 -and
    (Get-R23D15Sha256 $closureAuditPath) -ceq
        [string]$lineage.predecessor_closure_audit_raw_sha256 -and
    [string]$closure.status -ceq [string]$lineage.predecessor_status -and
    -not [bool]$lineage.predecessor_complete_matrix_valid -and
    -not [bool]$lineage.predecessor_scientific_positive -and
    -not [bool]$lineage.predecessor_scientific_negative -and
    [int]$lineage.predecessor_execution_valid_cell_count -eq 3 -and
    [int]$lineage.predecessor_worker_failure_cell_count -eq 6 -and
    [bool]$lineage.predecessor_same_identity_rerun_forbidden
) "QSDK-R23D15 predecessor boundary changed"

$question = $declaration.frozen_scientific_question
Assert-R23D15 (
    -not [bool]$question.changed_from_r23d14 -and
    [int]$question.controller_step_count -eq 2992 -and
    [int]$question.terminal_step_count -eq 960 -and
    [int]$question.total_trace_row_count_per_cell -eq 3952 -and
    [int]$question.maximum_active_neutral_acquisition_step_count -eq 600 -and
    [int]$question.minimum_confirmed_taper_step_count -eq 120 -and
    [int]$question.minimum_post_handoff_zero_actuation_step_count -eq 360 -and
    [double]$question.tight_maximum_torso_tilt_rad -eq 0.01 -and
    [double]$question.tight_maximum_joint_position_error_rad -eq 0.2 -and
    -not [bool]$question.walking_turning_controller_changed -and
    -not [bool]$question.fixture_changed -and
    -not [bool]$question.threshold_changed -and
    -not [bool]$question.horizon_changed -and
    -not [bool]$question.gain_changed -and
    -not [bool]$question.observed_mujoco_outcomes_used_to_tune_successor
) "QSDK-R23D15 frozen scientific question changed"

$matrix = $declaration.prospective_matrix
Assert-R23D15 (
    [string]$matrix.stage_id -ceq $stageId -and
    [int]$matrix.declared_cell_count -eq 9 -and
    [bool]$matrix.serialized_execution_required -and
    [bool]$matrix.all_cells_run_without_outcome_early_stop -and
    [bool]$matrix.all_cells_must_be_execution_valid -and
    -not [bool]$matrix.selective_replacement_or_rerun_permitted -and
    -not [bool]$matrix.formal_cross_engine_equivalence_study
) "QSDK-R23D15 prospective matrix changed"

$claims = $declaration.claims
Assert-R23D15 (
    -not [bool]$claims.production_composition_repair_zero_world_qualified -and
    -not [bool]$claims.finite_three_engine_result_exists -and
    -not [bool]$claims.command_conditioned_turning -and
    -not [bool]$claims.bilateral_signed_turning -and
    -not [bool]$claims.cross_engine_equivalence -and
    -not [bool]$claims.q_sdk_r23_satisfied -and
    -not [bool]$claims.release_authorized -and
    -not [bool]$claims.physical_acceptance_authority
) "QSDK-R23D15 claims changed"

$qualification = $declaration.stage_zero_qualification
$lfPaths = @(
    "sdk/turning/r23d15_composition_recovery_preregistration_v1.json",
    "sdk/run_qsdk_r23d15_stage_zero_gate.ps1",
    "tests/test_qsdk_r23d15_composition_recovery.ps1",
    "tests/test_sdk_qsdk_r23d15_composition_recovery.gd",
    "sdk/adapters/rapier/src/qsdk_r23d15_composition_recovery.rs",
    "sdk/adapters/rapier/src/bin/qsdk_r23d15_composition_recovery.rs"
)
$attributeOutput = @(& git -C $repoRoot check-attr eol -- $lfPaths)
Assert-R23D15 (
    [bool]$qualification.r23d15_checkout_bytes_must_be_lf_stable -and
    $attributeOutput.Count -eq $lfPaths.Count -and
    @($attributeOutput | Where-Object {
        -not $_.EndsWith(": eol: lf", [StringComparison]::Ordinal)
    }).Count -eq 0
) "QSDK-R23D15 checkout byte-stability rules changed"

$closureOutput = @(
    & pwsh -NoLogo -NoProfile -File $closureAuditPath 2>&1
) -join "`n"
Assert-R23D15 (
    $LASTEXITCODE -eq 0 -and
    $closureOutput.Contains("QSDK_R23D14_CLOSURE_PASS status=invalid matrix=3/9-valid")
) "QSDK-R23D15 predecessor closure audit failed: $closureOutput"

$waveText = Get-Content -Raw -LiteralPath $wavePath
$rapierText = Get-Content -Raw -LiteralPath $rapierPhysicalPath
Assert-R23D15 (
    $waveText.Contains("static func _normalize_sdk_terminal_handoff_reason") -and
    $waveText.Contains("static func run_sdk_terminal_handoff_reason_canary") -and
    $waveText.Contains(
        'var handoff_reason_result := _normalize_sdk_terminal_handoff_reason('
    ) -and
    -not $waveText.Contains(
        'sdk_terminal_taper_state.get("handoff_reason", "")'
    ) -and
    $rapierText.Contains(
        "run_qsdk_r23d15_rapier_inherited_composition_preflight("
    ) -and
    -not $rapierText.Contains("run_qsdk_r23d11_rapier_preflight(")
) "QSDK-R23D15 exact production call-site repair changed"

$cargoTest = @(
    & cargo test --quiet --locked --offline --manifest-path $manifest `
        --package sporespore-rapier-adapter --lib `
        qsdk_r23d15_composition_recovery --no-fail-fast 2>&1
) -join "`n"
Assert-R23D15 ($LASTEXITCODE -eq 0) "QSDK-R23D15 Rapier tests failed: $cargoTest"

& cargo build --quiet --locked --offline --manifest-path $manifest `
    --package sporespore-rapier-adapter --bin qsdk_r23d15_composition_recovery
Assert-R23D15 (
    $LASTEXITCODE -eq 0 -and
    (Test-Path -LiteralPath $rapierBinary -PathType Leaf)
) "QSDK-R23D15 Rapier canary binary build failed"

foreach ($armId in @("reference_zero", "positive_heading", "negative_heading")) {
    $output = @(& $rapierBinary $stageId $armId 2>&1) -join "`n"
    Assert-R23D15 ($LASTEXITCODE -eq 0) "Rapier canary failed: $output"
    $receipt = Read-R23D15Marker $output "QSDK_R23D15_RAPIER_COMPOSITION_RECOVERY "
    Assert-R23D15 (
        [string]$receipt.campaign_id -ceq $campaignId -and
        [string]$receipt.stage_id -ceq $stageId -and
        [string]$receipt.arm_id -ceq $armId -and
        [string]$receipt.inherited_stage_id -ceq "three_engine_confirmation" -and
        [bool]$receipt.predecessor_direct_binding_failure_reproduced -and
        [string]$receipt.predecessor_direct_binding_failure_code -ceq
            "R23D11_RAP_CELL_IDENTITY_INVALID" -and
        [bool]$receipt.explicit_stage_translation_applied -and
        [int]$receipt.composition_canary_count -eq 7 -and
        [int]$receipt.mutation_control_count -eq 18 -and
        [int]$receipt.model_construction_count -eq 0 -and
        [int]$receipt.world_build_count -eq 0 -and
        -not [bool]$receipt.physical_execution_authorized
    ) "QSDK-R23D15 Rapier receipt changed: $armId"
}

$invalidOutput = @(
    & $rapierBinary "three_engine_confirmation" "reference_zero" 2>&1
) -join "`n"
Assert-R23D15 ($LASTEXITCODE -ne 0) "QSDK-R23D15 invalid stage was accepted"
$invalid = Read-R23D15Marker $invalidOutput "QSDK_R23D15_RAPIER_COMPOSITION_FAILURE "
Assert-R23D15 (
    [string]$invalid.failure_code -ceq "R23D15_RAP_STAGE_IDENTITY_INVALID" -and
    [int]$invalid.model_construction_count -eq 0 -and
    [int]$invalid.world_build_count -eq 0
) "QSDK-R23D15 Rapier negative control changed"
$global:LASTEXITCODE = 0

$runRoot = Join-Path $sdkRoot (
    "target\qsdk-r23d15-godot-canary\" + [guid]::NewGuid().ToString("N")
)
[void][IO.Directory]::CreateDirectory($runRoot)
$start = [Diagnostics.ProcessStartInfo]::new()
$start.FileName = $Godot
$start.WorkingDirectory = $repoRoot
$start.UseShellExecute = $false
$start.CreateNoWindow = $true
$start.RedirectStandardOutput = $true
$start.RedirectStandardError = $true
$start.Environment["APPDATA"] = Join-Path $runRoot "appdata"
$start.Environment["LOCALAPPDATA"] = Join-Path $runRoot "localappdata"
foreach ($argument in @(
    "--headless", "--path", $repoRoot,
    "--log-file", (Join-Path $runRoot "godot.log"),
    "--script", $godotCanary
)) {
    [void]$start.ArgumentList.Add($argument)
}
$process = [Diagnostics.Process]::new()
$process.StartInfo = $start
Assert-R23D15 $process.Start() "QSDK-R23D15 Godot canary did not start"
$stdoutTask = $process.StandardOutput.ReadToEndAsync()
$stderrTask = $process.StandardError.ReadToEndAsync()
$timedOut = -not $process.WaitForExit(60000)
if ($timedOut) {
    $process.Kill($true)
    $process.WaitForExit()
}
$stdout = $stdoutTask.GetAwaiter().GetResult()
$stderr = $stderrTask.GetAwaiter().GetResult()
Assert-R23D15 (
    -not $timedOut -and $process.ExitCode -eq 0
) "QSDK-R23D15 Godot canary failed: $stderr"
$godotReceipt = Read-R23D15Marker `
    $stdout "QSDK_R23D15_GODOT_COMPOSITION_RECOVERY "
Assert-R23D15 (
    [string]$godotReceipt.schema_version -ceq
        "sporespore_sdk_terminal_handoff_reason_canary_v1" -and
    [bool]$godotReceipt.ok -and
    [int]$godotReceipt.valid_canary_count -eq 2 -and
    [int]$godotReceipt.mutation_control_count -eq 1 -and
    [bool]$godotReceipt.nullable_active_state_preserved -and
    [bool]$godotReceipt.confirmed_passive_reason_preserved -and
    [bool]$godotReceipt.non_string_reason_refused -and
    [int]$godotReceipt.model_construction_count -eq 0 -and
    [int]$godotReceipt.world_build_count -eq 0 -and
    -not [bool]$godotReceipt.physics_state_modified
) "QSDK-R23D15 Godot runtime canary changed"

Write-Host (
    "QSDK_R23D15_COMPOSITION_RECOVERY_PASS predecessor=invalid-3/9 " +
    "godot_canaries=2 godot_mutations=1 rapier_arms=3 rapier_tests=4 " +
    "controller_changes=0 threshold_changes=0 models=0 worlds=0 " +
    "turning=False equivalence=False physical_authority=False"
)
