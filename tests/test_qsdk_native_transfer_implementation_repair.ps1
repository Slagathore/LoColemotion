#requires -Version 7.0

[CmdletBinding()]
param(
    [string]$Python = "",
    [string]$Godot = (
        "C:\Users\Cole\CodeStuff\Misc\Godot\" +
        "Godot_v4.7-stable_mono_win64_console.exe"
    )
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false
$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$sdkRoot = Join-Path $repoRoot "sdk"
$mujocoRoot = Join-Path $sdkRoot "adapters\mujoco"
$pythonModuleRoot = Join-Path $sdkRoot "python"
$sitePackages = Join-Path $mujocoRoot ".venv\Lib\site-packages"
$coreDebug = Join-Path $sdkRoot "target\debug\sporespore_locomotion_core.dll"
$contractPath = Join-Path $sdkRoot (
    "turning\native_transfer_implementation_repair_contract_v1.json"
)
$releaseContractPath = Join-Path $sdkRoot "release\quadruped_release_contract.json"
$supportMatrixPath = Join-Path $sdkRoot "release\quadruped_support_matrix.json"
$godotTest = "res://tests/test_sdk_native_transfer_implementation_repair.gd"
$mujocoTest = Join-Path $mujocoRoot (
    "test_qsdk_native_transfer_implementation_repair.py"
)

function Assert-Repair([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "native-transfer implementation repair: $Message" }
}

function Resolve-Application([string]$Command) {
    if ([IO.Path]::IsPathFullyQualified($Command)) {
        $resolved = [IO.Path]::GetFullPath($Command)
        Assert-Repair (Test-Path -LiteralPath $resolved -PathType Leaf) (
            "application is missing: $resolved"
        )
        return $resolved
    }
    $candidate = Get-Command $Command -CommandType Application -ErrorAction Stop |
        Select-Object -First 1
    return [IO.Path]::GetFullPath([string]$candidate.Source)
}

function Find-NamedJsonProperty($Node, [string]$Name) {
    if ($null -eq $Node -or $Node -is [string]) { return }
    if ($Node -is [pscustomobject]) {
        foreach ($property in $Node.PSObject.Properties) {
            if ($property.Name -ceq $Name) { Write-Output $property.Value }
            Find-NamedJsonProperty $property.Value $Name
        }
        return
    }
    if ($Node -is [Collections.IEnumerable]) {
        foreach ($item in $Node) { Find-NamedJsonProperty $item $Name }
    }
}

function Get-Sha256([string]$Path) {
    return "sha256:" + (
        Get-FileHash -Algorithm SHA256 -LiteralPath $Path
    ).Hash.ToLowerInvariant()
}

if ([string]::IsNullOrWhiteSpace($Python)) {
    $Python = Join-Path $mujocoRoot ".venv\Scripts\python.exe"
}
$pythonPath = Resolve-Application $Python
$godotPath = Resolve-Application $Godot
Assert-Repair (Test-Path -LiteralPath $coreDebug -PathType Leaf) (
    "debug locomotion core is missing: $coreDebug"
)
Assert-Repair (Test-Path -LiteralPath $sitePackages -PathType Container) (
    "locked MuJoCo site-packages root is missing: $sitePackages"
)

$contract = Get-Content -Raw -LiteralPath $contractPath | ConvertFrom-Json -Depth 100
$claims = $contract.claims
$gate = $contract.executable_gate
Assert-Repair (
    ([string]$contract.schema_version -ceq
        "sporespore_native_transfer_implementation_repair_contract_v1") -and
    ([string]$contract.status -ceq
        "zero_world_implementation_repair_complete_no_physical_successor_open") -and
    [bool]$contract.closed_predecessor.identity_consumed -and
    (-not [bool]$contract.closed_predecessor.rerun_authorized) -and
    [bool]$claims.implementation_repair_zero_world_verified -and
    (-not [bool]$claims.closed_r23d33_reclassified) -and
    (-not [bool]$claims.closed_r23d33_rerun) -and
    (-not [bool]$claims.new_physical_series_open) -and
    (-not [bool]$claims.finite_three_engine_turning) -and
    (-not [bool]$claims.cross_engine_equivalence) -and
    (-not [bool]$claims.release_authorized) -and
    (-not [bool]$claims.physical_acceptance_authority)
) "contract identity or claim limits drifted"

$releaseContract = Get-Content -Raw -LiteralPath $releaseContractPath |
    ConvertFrom-Json -Depth 100
$supportMatrix = Get-Content -Raw -LiteralPath $supportMatrixPath |
    ConvertFrom-Json -Depth 100
$releaseRows = @(
    Find-NamedJsonProperty $releaseContract "native_transfer_implementation_repair"
)
$matrixRows = @(
    Find-NamedJsonProperty $supportMatrix "native_transfer_implementation_repair"
)
Assert-Repair (
    $releaseRows.Count -eq 1 -and
    $matrixRows.Count -eq 1
) "release authorities must contain exactly one repair boundary each"
$contractSha256 = Get-Sha256 $contractPath
$gateSha256 = Get-Sha256 $PSCommandPath
Assert-Repair (
    ([string]$releaseRows[0].boundary_id -ceq [string]$contract.boundary_id) -and
    ([string]$matrixRows[0].boundary_id -ceq [string]$contract.boundary_id) -and
    ([string]$releaseRows[0].contract_raw_sha256 -ceq $contractSha256) -and
    ([string]$matrixRows[0].contract_sha256 -ceq $contractSha256) -and
    ([string]$releaseRows[0].executable_gate_raw_sha256 -ceq $gateSha256) -and
    ([string]$matrixRows[0].executable_gate_sha256 -ceq $gateSha256) -and
    (-not [bool]$releaseRows[0].new_physical_series_open) -and
    (-not [bool]$matrixRows[0].new_physical_series_open) -and
    (-not [bool]$releaseRows[0].finite_three_engine_turning) -and
    (-not [bool]$matrixRows[0].finite_three_engine_turning) -and
    (-not [bool]$releaseRows[0].physical_acceptance_authority) -and
    (-not [bool]$matrixRows[0].physical_acceptance_authority)
) "release-authority repair record or digest drifted"

$godotOutput = @(
    & $godotPath --headless --path $repoRoot --script $godotTest 2>&1
)
Assert-Repair ($LASTEXITCODE -eq 0) ($godotOutput -join "`n")
$godotMarker = "QSDK_NATIVE_TRANSFER_GODOT_REPAIR "
$godotLines = @($godotOutput | Where-Object {
    ([string]$_).StartsWith($godotMarker, [StringComparison]::Ordinal)
})
Assert-Repair ($godotLines.Count -eq 1) ($godotOutput -join "`n")
$godotReceipt = ([string]$godotLines[0]).Substring($godotMarker.Length) |
    ConvertFrom-Json -Depth 100
Assert-Repair (
    [bool]$godotReceipt.ok -and
    ([int]$godotReceipt.arm_count -eq [int]$gate.godot_arm_count) -and
    ([int]$godotReceipt.production_post_step_validator_count -eq
        [int]$gate.godot_exact_production_post_step_validator_count) -and
    ([int]$godotReceipt.memory_schema_negative_control_count -eq
        [int]$gate.godot_memory_schema_negative_control_count) -and
    ([int]$godotReceipt.model_construction_count -eq 0) -and
    ([int]$godotReceipt.world_attempt_count -eq 0) -and
    ([int]$godotReceipt.world_build_count -eq 0) -and
    (-not [bool]$godotReceipt.physics_state_modified) -and
    (-not [bool]$godotReceipt.physical_execution_authorized) -and
    (-not [bool]$godotReceipt.physical_acceptance_authority)
) "Godot exact-production-seam receipt is invalid"

$savedPythonPath = $env:PYTHONPATH
$savedLibrary = $env:SPORESPORE_LOCOMOTION_LIBRARY
try {
    $repairPythonPath = (
        @($pythonModuleRoot, $mujocoRoot, $sitePackages) -join
            [IO.Path]::PathSeparator
    )
    $env:PYTHONPATH = if ([string]::IsNullOrWhiteSpace($savedPythonPath)) {
        $repairPythonPath
    } else {
        "$repairPythonPath$([IO.Path]::PathSeparator)$savedPythonPath"
    }
    $env:SPORESPORE_LOCOMOTION_LIBRARY = $coreDebug
    $mujocoOutput = @(& $pythonPath $mujocoTest -v 2>&1)
    Assert-Repair ($LASTEXITCODE -eq 0) ($mujocoOutput -join "`n")
    Assert-Repair (
        (@($mujocoOutput | Where-Object {
            ([string]$_) -match "^Ran 3 tests in "
        })).Count -eq 1
    ) ($mujocoOutput -join "`n")
    Assert-Repair (
        (@($mujocoOutput | Where-Object {
            ([string]$_).Trim() -ceq "OK"
        })).Count -eq 1
    ) ($mujocoOutput -join "`n")
} finally {
    $env:PYTHONPATH = $savedPythonPath
    $env:SPORESPORE_LOCOMOTION_LIBRARY = $savedLibrary
}

Write-Host (
    "QSDK_NATIVE_TRANSFER_IMPLEMENTATION_REPAIR_PASS " +
    "godot_arms=$($godotReceipt.arm_count) " +
    "godot_live_validators=$($godotReceipt.production_post_step_validator_count) " +
    "godot_negative_controls=$($godotReceipt.memory_schema_negative_control_count) " +
    "mujoco_tests=3 models=0 worlds=0 physical=False"
)
