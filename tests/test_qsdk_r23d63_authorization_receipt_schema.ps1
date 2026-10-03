[CmdletBinding()]
param(
    [string]$Python = "python",
    [string]$Godot = (
        "C:\Users\Cole\CodeStuff\Misc\Godot\" +
        "Godot_v4.7-stable_mono_win64_console.exe"
    )
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$expectedRoot = [IO.Path]::GetFullPath(
    "C:\Users\Cole\CodeStuff\games\SporeSpore"
)
$expectedRemote = "https://github.com/Slagathore/sporespore.git"
$requiredField = "complete_ordered_nine_cell_matrix_validated"
$godotPassMarker = "QSDK_R23D63_GODOT_AUTHORIZATION_RECEIPT_SCHEMA_PASS "
$godotReadyMarker = "QSDK_R23D63_GODOT_SUPERVISOR_TERMINATION_READY "
$godotScript = (
    "res://tests/" +
    "test_sdk_qsdk_r23d63_authorization_receipt_schema_zero_world.gd"
)
$rapierManifest = Join-Path $repoRoot "sdk\adapters\rapier\Cargo.toml"
$mujocoRoot = Join-Path $repoRoot "sdk\adapters\mujoco"
$mujocoVenvPython = Join-Path $mujocoRoot ".venv\Scripts\python.exe"
if ($Python -ceq "python" -and (Test-Path -LiteralPath $mujocoVenvPython -PathType Leaf)) {
    $Python = $mujocoVenvPython
}
$terminationHelper = Join-Path $repoRoot "sdk\godot_receipt_terminated_process.ps1"
$supervisionEnvironmentNames = @(
    "SPORESPORE_QSDK_R23D63_SUPERVISED_TERMINATION",
    "SPORESPORE_QSDK_R23D63_TERMINATION_NONCE"
)

function Assert-R23D63ReceiptSchema {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) {
        throw "QSDK-R23D63 authorization-receipt schema gate failed: $Message"
    }
}

Assert-R23D63ReceiptSchema ($repoRoot -ceq $expectedRoot) (
    "repository root changed: $repoRoot"
)
$gitRoot = [IO.Path]::GetFullPath(
    (& git -C $repoRoot rev-parse --show-toplevel).Trim()
)
$remote = (& git -C $repoRoot remote get-url origin).Trim()
Assert-R23D63ReceiptSchema (
    $LASTEXITCODE -eq 0 -and
    $gitRoot -ceq $expectedRoot -and
    $remote -ceq $expectedRemote
) "canonical repository identity changed"
foreach ($path in @($Godot, $rapierManifest, $mujocoRoot, $terminationHelper)) {
    Assert-R23D63ReceiptSchema (Test-Path -LiteralPath $path) (
        "required dependency missing: $path"
    )
}

. $terminationHelper

$nonce = [Guid]::NewGuid().ToString("N")
$godotEnvironment = @{
    "SPORESPORE_QSDK_R23D63_SUPERVISED_TERMINATION" = "1"
    "SPORESPORE_QSDK_R23D63_TERMINATION_NONCE" = $nonce
}
$godotProcess = Invoke-SporeSporeGodotReceiptTerminatedProcess `
    -FileName $Godot `
    -Arguments @(
        "--headless",
        "--path", $repoRoot,
        "--script", $godotScript
    ) `
    -WorkingDirectory $repoRoot `
    -ReadyMarkerPrefix $godotReadyMarker `
    -ExpectedNonce $nonce `
    -Environment $godotEnvironment `
    -ScrubEnvironmentNames $supervisionEnvironmentNames `
    -TimeoutSeconds 120
$godotLines = @(
    @([string]$godotProcess.stdout -split "`r?`n") |
        Where-Object { -not [string]::IsNullOrEmpty([string]$_) }
)
$godotMatches = @(
    $godotLines | Where-Object {
        $_.StartsWith($godotPassMarker, [StringComparison]::Ordinal)
    }
)
Assert-R23D63ReceiptSchema (
    [int]$godotProcess.exit_code -eq 0 -and
    -not [bool]$godotProcess.timed_out -and
    [bool]$godotProcess.termination_protocol_valid -and
    [bool]$godotProcess.supervisor_terminated -and
    $godotMatches.Count -eq 1 -and
    -not ([string]$godotProcess.stderr).Contains("SCRIPT ERROR")
) (
    "Godot/Jolt producer gate failed`n" +
    ([string]$godotProcess.stdout) +
    ([string]$godotProcess.stderr)
)
$godotReceipt = $godotMatches[0].Substring($godotPassMarker.Length) |
    ConvertFrom-Json -AsHashtable -Depth 100
Assert-R23D63ReceiptSchema (
    [string]$godotReceipt.engine_id -ceq "godot_jolt" -and
    [string]$godotReceipt.required_field -ceq $requiredField -and
    [string]$godotReceipt.required_json_type -ceq "boolean" -and
    [bool]$godotReceipt.required_value -and
    [int]$godotReceipt.negative_control_count -eq 4 -and
    [int]$godotReceipt.negative_controls_passed -eq 4 -and
    [int]$godotReceipt.model_construction_count -eq 0 -and
    [int]$godotReceipt.world_attempt_count -eq 0 -and
    [int]$godotReceipt.world_build_count -eq 0
) "Godot/Jolt producer receipt changed"

$rapierOutput = @(
    & cargo test `
        --quiet `
        --offline `
        --manifest-path $rapierManifest `
        --lib `
        "qsdk_r23d63_rapier_worker::tests::production_authorization_receipt_composer_is_exact_and_fail_closed" `
        -- --exact 2>&1
)
Assert-R23D63ReceiptSchema ($LASTEXITCODE -eq 0) (
    "Rapier/Parry producer gate failed`n" +
    ($rapierOutput -join [Environment]::NewLine)
)

$savedPythonPath = [Environment]::GetEnvironmentVariable(
    "PYTHONPATH",
    [EnvironmentVariableTarget]::Process
)
$mujocoPythonPath = $mujocoRoot
if (-not [string]::IsNullOrWhiteSpace($savedPythonPath)) {
    # The supervisor supplies the MuJoCo venv's site-packages through its
    # inherited PYTHONPATH even when its explicit Python host is system Python.
    # Prepend the package root without erasing that qualified runtime binding.
    $mujocoPythonPath += [IO.Path]::PathSeparator + $savedPythonPath
}
try {
    [Environment]::SetEnvironmentVariable(
        "PYTHONPATH",
        $mujocoPythonPath,
        [EnvironmentVariableTarget]::Process
    )
    $mujocoOutput = @(
        & $Python -m unittest (
            "sporespore_mujoco_adapter." +
            "qsdk_r23d63_selected_profile_turning_test." +
            "R23D63MujocoWorkerTests." +
            "test_authorization_receipt_composer_is_exact_and_fail_closed"
        ) 2>&1
    )
    Assert-R23D63ReceiptSchema ($LASTEXITCODE -eq 0) (
        "MuJoCo producer gate failed`n" +
        ($mujocoOutput -join [Environment]::NewLine)
    )
}
finally {
    [Environment]::SetEnvironmentVariable(
        "PYTHONPATH",
        $savedPythonPath,
        [EnvironmentVariableTarget]::Process
    )
}

$receipt = [ordered]@{
    schema_version = (
        "sporespore_qsdk_r23d63_authorization_receipt_schema_conformance_v1"
    )
    campaign_id = (
        "QSDK-R23D63-RECEIPT-SCHEMA-REPAIRED-SELECTED-PROFILE-MATCHED-" +
        "THREE-ENGINE-TURNING-VALIDATION"
    )
    gate_id = "QSDK-R23D63"
    question_class = "equivalence_non_inferiority"
    population = "complete_three_production_authorization_receipt_producers"
    producer_ids = @("godot_jolt", "rapier_parry", "mujoco")
    declared_producer_count = 3
    conforming_producer_count = 3
    required_field = $requiredField
    required_json_type = "boolean"
    required_value = $true
    equivalence_margin = 0
    non_inferiority_margin = 0
    sampling_used = $false
    actual_production_composer_invoked_per_engine = $true
    negative_control_count_per_engine = 4
    total_negative_control_count = 12
    negative_controls_passed = 12
    missing_false_wrong_type_and_alias_rejected_per_engine = $true
    complete_population_adequacy_argument = (
        "All three production authorization receipt composers are the entire " +
        "advertised-engine producer population, so exact 3/3 field, type, and " +
        "value equality directly answers this source-conformance question " +
        "without sampling or a statistical margin."
    )
    must_pass_before_physical_freeze = $true
    must_pass_before_attempt_authorization = $true
    model_construction_count = 0
    world_attempt_count = 0
    world_build_count = 0
    physical_execution_authorized = $false
    physical_equivalence_claimed = $false
    physical_acceptance_authority = $false
}

Write-Output (
    "QSDK_R23D63_AUTHORIZATION_RECEIPT_SCHEMA_PASS " +
    ($receipt | ConvertTo-Json -Compress -Depth 100)
)
