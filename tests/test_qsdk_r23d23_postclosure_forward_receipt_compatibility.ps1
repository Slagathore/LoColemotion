#requires -Version 7.0

[CmdletBinding()]
param(
    [string]$EvidenceRoot = "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$sdkRoot = Join-Path $repoRoot "sdk"
$turningRoot = Join-Path $sdkRoot "turning"
$mujocoRoot = Join-Path $sdkRoot "adapters\mujoco"
$pythonRoot = Join-Path $sdkRoot "python"
$python = Join-Path $mujocoRoot ".venv\Scripts\python.exe"
$library = Join-Path $sdkRoot "target\release\sporespore_locomotion_core.dll"
$declarationPath = Join-Path `
    $turningRoot "r23d23_mujoco_forward_receipt_diagnosis_v1.json"
$diagnosisPath = Join-Path `
    $turningRoot "r23d23_postclosure_retained_trace_diagnosis.py"
$compositionPath = Join-Path $mujocoRoot (
    "sporespore_mujoco_adapter\qsdk_r23d8_neutral_stance_composition.py"
)
$repairPath = Join-Path $mujocoRoot (
    "sporespore_mujoco_adapter\" +
    "qsdk_r23d23_postclosure_forward_receipt_compatibility.py"
)

function Assert-R23D23D1([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "QSDK-R23D23-D1: $Message" }
}

function Get-R23D23D1GitBlobSha256(
    [string]$Commit,
    [string]$RelativePath
) {
    $start = [Diagnostics.ProcessStartInfo]::new()
    $start.FileName = "git"
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    foreach ($argument in @(
        "-C", $repoRoot, "cat-file", "blob", "${Commit}:$RelativePath"
    )) { [void]$start.ArgumentList.Add($argument) }
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $start
    try {
        Assert-R23D23D1 $process.Start() (
            "could not start Git blob reader for $RelativePath"
        )
        $stderrTask = $process.StandardError.ReadToEndAsync()
        $hasher = [Security.Cryptography.SHA256]::Create()
        try { $digest = $hasher.ComputeHash($process.StandardOutput.BaseStream) }
        finally { $hasher.Dispose() }
        $process.WaitForExit()
        $stderr = $stderrTask.GetAwaiter().GetResult()
        Assert-R23D23D1 ($process.ExitCode -eq 0) (
            "Git blob read failed for $RelativePath`: $stderr"
        )
        return "sha256:" + [Convert]::ToHexString($digest).ToLowerInvariant()
    } finally { $process.Dispose() }
}

function Read-R23D23D1Marker([string]$Text, [string]$Prefix) {
    $matches = @(($Text -split "\r?\n") | Where-Object {
        $_.StartsWith($Prefix, [StringComparison]::Ordinal)
    })
    Assert-R23D23D1 ($matches.Count -eq 1) "marker count changed: $Prefix"
    return $matches[0].Substring($Prefix.Length) |
        ConvertFrom-Json -AsHashtable -Depth 100
}

Assert-R23D23D1 (
    (git -C $repoRoot rev-parse --show-toplevel).Trim() -ceq
        $repoRoot.Replace("\", "/") -and
    (git -C $repoRoot remote get-url origin).Trim() -ceq
        "https://github.com/Slagathore/sporespore.git"
) "repository identity changed"
foreach ($path in @(
    $python,
    $library,
    $declarationPath,
    $diagnosisPath,
    $compositionPath,
    $repairPath,
    $EvidenceRoot
)) {
    Assert-R23D23D1 (Test-Path -LiteralPath $path) "required path missing: $path"
}

$declaration = Get-Content -LiteralPath $declarationPath -Raw |
    ConvertFrom-Json -AsHashtable -Depth 100
Assert-R23D23D1 (
    [string]$declaration.schema_version -ceq
        "sporespore_qsdk_r23d23_mujoco_forward_receipt_diagnosis_v1" -and
    [string]$declaration.status -ceq
        "postclosure_diagnosis_and_zero_world_compatibility_repair" -and
    [string]$declaration.gate_id -ceq
        "QSDK-R23D23-MJC-FORWARD-RECEIPT-D1" -and
    [string]$declaration.declared_from_parent_commit -ceq
        "4c34c3d2bbcfdba6ebcbcb87b0c462d44507e216" -and
    [string]$declaration.question_class -ceq "development_diagnosis" -and
    -not [bool]$declaration.physical_campaign_identity
) "diagnosis identity changed"

Assert-R23D23D1 (@($declaration.immutable_closure_bindings).Count -eq 2) (
    "closure binding count changed"
)
foreach ($binding in @($declaration.immutable_closure_bindings)) {
    $sourceCommit = "4c34c3d2bbcfdba6ebcbcb87b0c462d44507e216"
    $relativePath = [string]$binding.path
    Assert-R23D23D1 (
        (Get-R23D23D1GitBlobSha256 $sourceCommit $relativePath) -ceq
            [string]$binding.raw_sha256 -and
        (git -C $repoRoot rev-parse (
            "${sourceCommit}:$relativePath"
        )).Trim() -ceq [string]$binding.git_blob_oid
    ) "immutable closure binding changed: $($binding.gate_id)"
}

$observed = $declaration.observed_failure
$mechanism = $declaration.mechanism
$repair = $declaration.compatibility_repair
Assert-R23D23D1 (
    [string]$observed.engine_id -ceq "mujoco" -and
    [int]$observed.affected_cell_count -eq 3 -and
    [int]$observed.world_attempt_count -eq 3 -and
    [int]$observed.world_build_count -eq 3 -and
    [string]$observed.failure_stage -ceq "settlement_complete" -and
    [string]$observed.failure_code -ceq (
        "QSDK_R23D23_MJC_RUNTIME_ERROR:RuntimeError:" +
        "QSDK_R23D8_NEUTRAL_UNEXPECTED_FORWARD_RECEIPT"
    ) -and
    -not [bool]$observed.turning_outcome_available -and
    [string]$mechanism.real_controller_receipt_schema -ceq
        "sporespore_controller_step_receipt_v5" -and
    [string]$mechanism.required_member_schema -ceq
        "sporespore_forward_velocity_foot_placement_receipt_v2" -and
    [bool]$mechanism.adapter_contract_mismatch -and
    -not [bool]$mechanism.physics_mechanism -and
    [string]$repair.source_contract_id -ceq
        "r23d21_forward_velocity_foot_placement_receipt_v2" -and
    [bool]$repair.opt_in_only -and
    [bool]$repair.historical_r23d8_default_behavior_preserved -and
    [bool]$repair.full_source_actuation_preserved_through_canonical_composition -and
    [bool]$repair.member_may_not_be_silently_removed -and
    [int]$repair.source_and_terminal_mutation_control_count -eq 22 -and
    [int]$repair.world_build_count -eq 0 -and
    -not [bool]$repair.physical_execution_authorized
) "mechanism or compatibility-repair declaration changed"

$compositionText = Get-Content -LiteralPath $compositionPath -Raw
$repairText = Get-Content -LiteralPath $repairPath -Raw
Assert-R23D23D1 (
    $compositionText.Contains(
        "source_forward_velocity_contract_id: str = ("
    ) -and
    $compositionText.Contains(
        "R23D21_FORWARD_VELOCITY_SOURCE_CONTRACT_ID"
    ) -and
    $compositionText.Contains("QSDK_R23D8_NEUTRAL_UNEXPECTED_FORWARD_RECEIPT") -and
    $compositionText.Contains("QSDK_R23D8_NEUTRAL_FORWARD_RECEIPT_LIMB_EQUATION") -and
    -not $compositionText.Contains(
        "pop(FORWARD_VELOCITY_RECEIPT_MEMBER"
    ) -and
    $repairText.Contains("core.balanced_wave_policy_step(") -and
    $repairText.Contains("source_forward_velocity_contract_id=SOURCE_CONTRACT_ID") -and
    $repairText.Contains("mutation_control_count")
) "production repair source or no-strip invariant changed"

$oldLibrary = $env:SPORESPORE_LOCOMOTION_LIBRARY
$oldPythonPath = $env:PYTHONPATH
try {
    $env:SPORESPORE_LOCOMOTION_LIBRARY = $library
    $env:PYTHONPATH = (
        $mujocoRoot + [IO.Path]::PathSeparator +
        $pythonRoot + [IO.Path]::PathSeparator +
        $turningRoot
    )
    $repairOutput = & $python -m (
        "sporespore_mujoco_adapter." +
        "qsdk_r23d23_postclosure_forward_receipt_compatibility"
    ) 2>&1 | Out-String
    $repairExit = $LASTEXITCODE
    $traceOutput = & $python $diagnosisPath `
        --declaration $declarationPath `
        --evidence-root $EvidenceRoot 2>&1 | Out-String
    $traceExit = $LASTEXITCODE
} finally {
    $env:SPORESPORE_LOCOMOTION_LIBRARY = $oldLibrary
    $env:PYTHONPATH = $oldPythonPath
}
Assert-R23D23D1 ($repairExit -eq 0) "source-receipt preflight failed: $repairOutput"
Assert-R23D23D1 ($traceExit -eq 0) "retained-trace diagnosis failed: $traceOutput"

$repairReport = Read-R23D23D1Marker `
    $repairOutput "QSDK_R23D23_MJC_FORWARD_RECEIPT_D1 "
Assert-R23D23D1 (
    [string]$repairReport.status -ceq "zero_world_compatibility_repair_passed" -and
    [int]$repairReport.arm_count -eq 3 -and
    @($repairReport.arm_receipts).Count -eq 3 -and
    [int]$repairReport.mutation_control_count -eq 22 -and
    @($repairReport.mutation_controls.Values | Where-Object { -not [bool]$_ }).Count -eq 0 -and
    [bool]$repairReport.historical_r23d8_default_preserved -and
    [int]$repairReport.model_construction_count -eq 0 -and
    [int]$repairReport.world_attempt_count -eq 0 -and
    [int]$repairReport.world_build_count -eq 0 -and
    -not [bool]$repairReport.physical_execution_authorized -and
    -not [bool]$repairReport.turning_acceptance -and
    -not [bool]$repairReport.physical_acceptance_authority
) "source-receipt preflight projection changed"

$traceReport = Read-R23D23D1Marker `
    $traceOutput "QSDK_R23D23_RETAINED_TRACE_D1 "
$expectedCells = @($declaration.threshold_provenance_query.retained_cells)
$observedCells = @($traceReport.cells)
Assert-R23D23D1 (
    [int]$traceReport.source_closure_count -eq 2 -and
    [int]$traceReport.cell_count -eq 6 -and
    $observedCells.Count -eq 6 -and
    [int]$traceReport.model_construction_count -eq 0 -and
    [int]$traceReport.world_attempt_count -eq 0 -and
    [int]$traceReport.world_build_count -eq 0 -and
    -not [bool]$traceReport.threshold_change_authorized -and
    -not [bool]$traceReport.physical_execution_authorized -and
    -not [bool]$traceReport.physical_acceptance_authority
) "retained-trace summary changed"

foreach ($expectedCell in $expectedCells) {
    $matches = @($observedCells | Where-Object {
        [string]$_.cell_id -ceq [string]$expectedCell.cell_id
    })
    Assert-R23D23D1 ($matches.Count -eq 1) (
        "retained cell missing: $($expectedCell.cell_id)"
    )
    $actual = $matches[0]
    foreach ($field in $expectedCell.expected_projection.Keys) {
        $expectedValue = $expectedCell.expected_projection[$field]
        $actualValue = $actual[$field]
        if ($null -eq $expectedValue) {
            Assert-R23D23D1 ($null -eq $actualValue) (
                "retained null projection changed: $($expectedCell.cell_id):$field"
            )
        } elseif ($expectedValue -is [double]) {
            Assert-R23D23D1 ([double]$actualValue -eq [double]$expectedValue) (
                "retained numeric projection changed: $($expectedCell.cell_id):$field"
            )
        } else {
            Assert-R23D23D1 ($actualValue -eq $expectedValue) (
                "retained projection changed: $($expectedCell.cell_id):$field"
            )
        }
    }
}

$query = $declaration.threshold_provenance_query
$claims = $declaration.claims
Assert-R23D23D1 (
    [double]$query.tight_maximum_torso_tilt_rad -eq 0.01 -and
    [double]$query.tight_maximum_joint_position_error_rad -eq 0.2 -and
    -not [bool]$query.threshold_change_authorized -and
    [bool]$query.controller_or_stability_successor_required_for_rapier -and
    -not [bool]$claims.r23d23_result_reinterpreted -and
    -not [bool]$claims.r23d23_same_identity_rerun_authorized -and
    -not [bool]$claims.physical_campaign_opened -and
    -not [bool]$claims.physical_execution_authorized -and
    -not [bool]$claims.turning_acceptance -and
    -not [bool]$claims.rapier_turning_candidate -and
    -not [bool]$claims.finite_three_engine_turning -and
    -not [bool]$claims.cross_engine_equivalence -and
    -not [bool]$claims.q_sdk_r23_satisfied -and
    -not [bool]$claims.release_authorized -and
    -not [bool]$claims.physical_acceptance_authority
) "threshold or claim boundary changed"

Write-Host (
    "QSDK_R23D23_POSTCLOSURE_FORWARD_RECEIPT_D1_PASS " +
    "real_arms=3 mutations=22 retained_cells=6 tight_godot_rows=2880 " +
    "rapier_reference_tight_rows=207 models=0 worlds=0 " +
    "threshold_change=False physical=False turning=False release=False"
)
