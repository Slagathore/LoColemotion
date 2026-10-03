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
$godotPassMarker = "QSDK_R23D65_GODOT_AUTHORIZATION_RECEIPT_SCHEMA_PASS "
$godotReadyMarker = "QSDK_R23D65_GODOT_SUPERVISOR_TERMINATION_READY "
$godotScript = (
    "res://tests/" +
    "test_sdk_qsdk_r23d65_authorization_receipt_schema_zero_world.gd"
)
$rapierManifest = Join-Path $repoRoot "sdk\adapters\rapier\Cargo.toml"
$mujocoRoot = Join-Path $repoRoot "sdk\adapters\mujoco"
$mujocoVenvPython = Join-Path $mujocoRoot ".venv\Scripts\python.exe"
$mujocoSitePackages = Join-Path $mujocoRoot ".venv\Lib\site-packages"
$mujocoLockPath = Join-Path $mujocoRoot "requirements-lock.txt"
$expectedMujocoLockSha256 =
    "sha256:1c4da4ba7964874fc55c8e16b60d1c6114f40e598f402fb2db1bb6a703b37603"
$expectedMujocoEnvironmentManifestSha256 =
    "sha256:95ea9d7f02a82fc84f62b04cf3c3a7415b62ccab4d04cb56cd12df7cd7696f68"
$expectedMujocoDistributionCount = 9
$expectedMujocoDistributionFileCount = 8094
$expectedMujocoDistributionByteCount = 131440050
$expectedMujocoModuleSha256 =
    "sha256:131342cd035fa2022b8ea46e1380aaa80641ee1d983d65c427a694517c3c6790"
if ($Python -ceq "python" -and (Test-Path -LiteralPath $mujocoVenvPython -PathType Leaf)) {
    $Python = $mujocoVenvPython
}
$terminationHelper = Join-Path $repoRoot "sdk\godot_receipt_terminated_process.ps1"
$supervisionEnvironmentNames = @(
    "SPORESPORE_QSDK_R23D65_SUPERVISED_TERMINATION",
    "SPORESPORE_QSDK_R23D65_TERMINATION_NONCE"
)

function Assert-R23D65ReceiptSchema {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) {
        throw "QSDK-R23D65 authorization-receipt schema gate failed: $Message"
    }
}

function Get-R23D65MujocoPythonPath {
    param([AllowEmptyString()][string]$InheritedPythonPath)
    $entries = [Collections.Generic.List[string]]::new()
    $entries.Add($mujocoRoot)
    $entries.Add($mujocoSitePackages)
    if (-not [string]::IsNullOrWhiteSpace($InheritedPythonPath)) {
        $entries.Add($InheritedPythonPath)
    }
    return $entries -join [IO.Path]::PathSeparator
}

Assert-R23D65ReceiptSchema ($repoRoot -ceq $expectedRoot) (
    "repository root changed: $repoRoot"
)
$gitRoot = [IO.Path]::GetFullPath(
    (& git -C $repoRoot rev-parse --show-toplevel).Trim()
)
$remote = (& git -C $repoRoot remote get-url origin).Trim()
Assert-R23D65ReceiptSchema (
    $LASTEXITCODE -eq 0 -and
    $gitRoot -ceq $expectedRoot -and
    $remote -ceq $expectedRemote
) "canonical repository identity changed"
foreach ($path in @(
    $Godot,
    $rapierManifest,
    $mujocoRoot,
    $mujocoSitePackages,
    $mujocoLockPath,
    $terminationHelper
)) {
    Assert-R23D65ReceiptSchema (Test-Path -LiteralPath $path) (
        "required dependency missing: $path"
    )
}
Assert-R23D65ReceiptSchema (
    ("sha256:" + (Get-FileHash -LiteralPath $mujocoLockPath -Algorithm SHA256).Hash.ToLowerInvariant()) -ceq
        $expectedMujocoLockSha256
) "MuJoCo locked environment declaration changed"

. $terminationHelper

$nonce = [Guid]::NewGuid().ToString("N")
$godotEnvironment = @{
    "SPORESPORE_QSDK_R23D65_SUPERVISED_TERMINATION" = "1"
    "SPORESPORE_QSDK_R23D65_TERMINATION_NONCE" = $nonce
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
Assert-R23D65ReceiptSchema (
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
Assert-R23D65ReceiptSchema (
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
        "qsdk_r23d65_rapier_worker::tests::production_authorization_receipt_composer_is_exact_and_fail_closed" `
        -- --exact 2>&1
)
Assert-R23D65ReceiptSchema ($LASTEXITCODE -eq 0) (
    "Rapier/Parry producer gate failed`n" +
    ($rapierOutput -join [Environment]::NewLine)
)

$savedPythonPath = [Environment]::GetEnvironmentVariable(
    "PYTHONPATH",
    [EnvironmentVariableTarget]::Process
)
$emptyCallerPythonPath = Get-R23D65MujocoPythonPath ""
$sentinelCallerPythonPath = [IO.Path]::GetFullPath(
    (Join-Path $repoRoot "sdk\target\r23d65-pythonpath-sentinel")
)
$composedSentinelPythonPath = Get-R23D65MujocoPythonPath $sentinelCallerPythonPath
$requiredMujocoPythonPathPrefix = (
    $mujocoRoot + [IO.Path]::PathSeparator + $mujocoSitePackages
)
Assert-R23D65ReceiptSchema (
    $emptyCallerPythonPath -ceq $requiredMujocoPythonPathPrefix -and
    $composedSentinelPythonPath -ceq (
        $requiredMujocoPythonPathPrefix +
        [IO.Path]::PathSeparator +
        $sentinelCallerPythonPath
    )
) "MuJoCo caller-PYTHONPATH independence controls failed"
$runtimePathControlCount = 2
$runtimePathControlsPassed = 2
$mujocoPythonPath = Get-R23D65MujocoPythonPath $savedPythonPath
$mujocoEnvironmentProbe = @'
import hashlib
import importlib.metadata as metadata
import json
import pathlib
import sys

lock_path = pathlib.Path(sys.argv[1]).resolve()
requirements = []
for raw in lock_path.read_text(encoding="utf-8").splitlines():
    line = raw.strip()
    if not line or line.startswith("#"):
        continue
    name, version = line.split("==", 1)
    requirements.append((name, version))

records = []
file_count = 0
byte_count = 0
for lock_name, lock_version in requirements:
    distribution = metadata.distribution(lock_name)
    files = []
    for entry in sorted(
        distribution.files or (),
        key=lambda item: item.as_posix(),
    ):
        path = pathlib.Path(distribution.locate_file(entry)).resolve()
        if not path.is_file():
            continue
        payload = path.read_bytes()
        files.append(
            {
                "path": entry.as_posix(),
                "byte_length": len(payload),
                "sha256": hashlib.sha256(payload).hexdigest(),
            }
        )
        file_count += 1
        byte_count += len(payload)
    records.append(
        {
            "lock_name": lock_name,
            "lock_version": lock_version,
            "installed_name": distribution.metadata["Name"],
            "installed_version": distribution.version,
            "files": files,
        }
    )

import mujoco

module_path = pathlib.Path(mujoco.__file__).resolve()
canonical = json.dumps(
    records,
    ensure_ascii=False,
    separators=(",", ":"),
    sort_keys=True,
).encode("utf-8")
print(
    json.dumps(
        {
            "schema_version": "sporespore_python_lock_environment_identity_v1",
            "python_executable": str(pathlib.Path(sys.executable).resolve()),
            "mujoco_version": mujoco.__version__,
            "mujoco_module_path": str(module_path),
            "mujoco_module_sha256": "sha256:"
            + hashlib.sha256(module_path.read_bytes()).hexdigest(),
            "distribution_count": len(records),
            "distribution_file_count": file_count,
            "distribution_byte_count": byte_count,
            "environment_manifest_sha256": "sha256:"
            + hashlib.sha256(canonical).hexdigest(),
            "versions": {
                record["lock_name"]: record["installed_version"]
                for record in records
            },
        },
        separators=(",", ":"),
        sort_keys=True,
    )
)
'@
try {
    [Environment]::SetEnvironmentVariable(
        "PYTHONPATH",
        $mujocoPythonPath,
        [EnvironmentVariableTarget]::Process
    )
    $mujocoEnvironmentOutput = @(
        & $Python -c $mujocoEnvironmentProbe $mujocoLockPath 2>&1
    )
    $mujocoEnvironmentExitCode = $LASTEXITCODE
    Assert-R23D65ReceiptSchema (
        $mujocoEnvironmentExitCode -eq 0 -and
        $mujocoEnvironmentOutput.Count -eq 1
    ) (
        "MuJoCo locked environment probe failed" +
        [Environment]::NewLine +
        ($mujocoEnvironmentOutput -join [Environment]::NewLine)
    )
    $mujocoEnvironment = ([string]$mujocoEnvironmentOutput[0]) |
        ConvertFrom-Json -AsHashtable -Depth 100
    $expectedMujocoModulePath = Join-Path $mujocoSitePackages "mujoco\__init__.py"
    Assert-R23D65ReceiptSchema (
        [string]$mujocoEnvironment.schema_version -ceq
            "sporespore_python_lock_environment_identity_v1" -and
        [string]$mujocoEnvironment.mujoco_version -ceq "3.11.0" -and
        [IO.Path]::GetFullPath([string]$mujocoEnvironment.mujoco_module_path) -ceq
            [IO.Path]::GetFullPath($expectedMujocoModulePath) -and
        [string]$mujocoEnvironment.mujoco_module_sha256 -ceq
            $expectedMujocoModuleSha256 -and
        [int]$mujocoEnvironment.distribution_count -eq
            $expectedMujocoDistributionCount -and
        [int]$mujocoEnvironment.distribution_file_count -eq
            $expectedMujocoDistributionFileCount -and
        [long]$mujocoEnvironment.distribution_byte_count -eq
            $expectedMujocoDistributionByteCount -and
        [string]$mujocoEnvironment.environment_manifest_sha256 -ceq
            $expectedMujocoEnvironmentManifestSha256 -and
        [string]$mujocoEnvironment.versions."mujoco" -ceq "3.11.0" -and
        [string]$mujocoEnvironment.versions."numpy" -ceq "2.4.6"
    ) "MuJoCo locked environment identity changed"
    $mujocoOutput = @(
        & $Python -m unittest (
            "sporespore_mujoco_adapter." +
            "qsdk_r23d65_selected_profile_turning_test." +
            "R23D65MujocoWorkerTests." +
            "test_authorization_receipt_composer_is_exact_and_fail_closed"
        ) 2>&1
    )
    Assert-R23D65ReceiptSchema ($LASTEXITCODE -eq 0) (
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
        "sporespore_qsdk_r23d65_authorization_receipt_schema_conformance_v1"
    )
    campaign_id = (
        "QSDK-R23D65-RUNTIME-INTEGRATION-REPAIRED-SELECTED-PROFILE-" +
        "MATCHED-" +
        "THREE-ENGINE-TURNING-VALIDATION"
    )
    gate_id = "QSDK-R23D65"
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
    runtime_dependency_question_class = "equivalence_non_inferiority"
    runtime_dependency_population = "complete_locked_mujoco_python_environment"
    runtime_dependency_lock_path = "sdk/adapters/mujoco/requirements-lock.txt"
    runtime_dependency_lock_raw_sha256 = $expectedMujocoLockSha256
    runtime_dependency_distribution_count = $expectedMujocoDistributionCount
    runtime_dependency_distribution_file_count = $expectedMujocoDistributionFileCount
    runtime_dependency_distribution_byte_count = $expectedMujocoDistributionByteCount
    runtime_dependency_environment_manifest_sha256 =
        $expectedMujocoEnvironmentManifestSha256
    runtime_dependency_mujoco_version = [string]$mujocoEnvironment.mujoco_version
    runtime_dependency_mujoco_module_raw_sha256 =
        [string]$mujocoEnvironment.mujoco_module_sha256
    runtime_dependency_path_self_bound = $true
    caller_pythonpath_required = $false
    caller_pythonpath_independence_control_count = $runtimePathControlCount
    caller_pythonpath_independence_controls_passed = $runtimePathControlsPassed
    runtime_dependency_equivalence_margin = 0
    runtime_dependency_non_inferiority_margin = 0
    runtime_dependency_sampling_used = $false
    runtime_dependency_adequacy_argument = (
        "All 9 locked distributions and all 8,094 files declared by their " +
        "installed wheel metadata were hashed, the MuJoCo package root was " +
        "prepended independently of caller PYTHONPATH, and both empty and " +
        "non-empty caller-path compositions were checked exactly."
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
    "QSDK_R23D65_AUTHORIZATION_RECEIPT_SCHEMA_PASS " +
    ($receipt | ConvertTo-Json -Compress -Depth 100)
)
