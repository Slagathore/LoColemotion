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

function Assert-Exact {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function Get-RawSha256 {
    param([Parameter(Mandatory)][string]$Path)
    return (Get-FileHash -Algorithm SHA256 -LiteralPath $Path).
        Hash.ToLowerInvariant()
}

function Get-GitBlobRawSha256 {
    param(
        [Parameter(Mandatory)][string]$RepoRoot,
        [Parameter(Mandatory)][string]$Commit,
        [Parameter(Mandatory)][string]$RelativePath
    )
    $startInfo = [Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = "git"
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    foreach ($argument in @(
        "-C", $RepoRoot, "cat-file", "blob", "${Commit}:$RelativePath"
    )) {
        [void]$startInfo.ArgumentList.Add($argument)
    }
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $startInfo
    try {
        Assert-Exact $process.Start() (
            "C6-MJC-HC-VH5 could not start historical blob reader: $RelativePath"
        )
        $standardErrorTask = $process.StandardError.ReadToEndAsync()
        $hasher = [Security.Cryptography.SHA256]::Create()
        try {
            $digest = $hasher.ComputeHash($process.StandardOutput.BaseStream)
        } finally {
            $hasher.Dispose()
        }
        $process.WaitForExit()
        $standardError = $standardErrorTask.GetAwaiter().GetResult()
        Assert-Exact ($process.ExitCode -eq 0) (
            "C6-MJC-HC-VH5 could not read historical blob $RelativePath`: " +
            $standardError.Trim()
        )
        return [Convert]::ToHexString($digest).ToLowerInvariant()
    } finally {
        $process.Dispose()
    }
}

$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$sdkRoot = Join-Path $repoRoot "sdk"
$mujocoRoot = Join-Path $sdkRoot "adapters\mujoco"
$python = Join-Path $mujocoRoot ".venv\Scripts\python.exe"
$closurePath = Join-Path $sdkRoot (
    "mujoco_c6_s169_per_actuator_force_limit_host_characterization_vh5_closure.json"
)
$runnerPath = Join-Path $sdkRoot (
    "run_mujoco_c6_s169_per_actuator_force_limit_host_characterization_vh5.ps1"
)
$attestationHelperPath = Join-Path $sdkRoot (
    "locomotion_full_conformance_attestation.ps1"
)
$operationLockPath = Join-Path $sdkRoot "locomotion_operation_lock.ps1"
$expectedClosureSha256 = (
    "fbb8441fb8a3907c56155db777de00ce8b6e2f293ef67e77a2a30d2eeeb0f34f"
)
$gateId = "C6-MJC-HC-VH5"

Assert-Exact (
    (git -C $repoRoot rev-parse --show-toplevel).Trim() -ceq
        $repoRoot.Replace("\", "/")
) "$gateId closure audit ran outside SporeSpore"
Assert-Exact (
    (git -C $repoRoot remote get-url origin).Trim() -ceq
        "https://github.com/Slagathore/sporespore.git"
) "$gateId closure audit origin mismatch"
foreach ($path in @(
    $python,
    $closurePath,
    $runnerPath,
    $attestationHelperPath,
    $operationLockPath
)) {
    Assert-Exact (
        Test-Path -LiteralPath $path -PathType Leaf
    ) "$gateId closure dependency missing: $path"
}
Assert-Exact (
    (Get-RawSha256 -Path $closurePath) -ceq $expectedClosureSha256
) "$gateId closure bytes changed"

$closure = Get-Content -Raw -LiteralPath $closurePath |
    ConvertFrom-Json -AsHashtable -Depth 100
Assert-Exact (
    [string]$closure.schema_version -ceq
        "sporespore_mujoco_c6_s169_per_actuator_force_limit_host_characterization_vh5_closure_v1" -and
    [string]$closure.campaign_id -ceq
        "C6-MUJOCO-S169-PER-ACTUATOR-FORCE-LIMIT-HOST-CHARACTERIZATION-VH5" -and
    [string]$closure.gate_id -ceq $gateId -and
    [string]$closure.status -ceq
        "closed_complete_valid_positive_exact_finite_s169_per_actuator_host_characterization" -and
    [string]$closure.source.commit -ceq
        "d11d8ef10a82e11eef78b6a51cd74193bce37e0e" -and
    [string]$closure.source.tree_git_oid -ceq
        "486e5a683766795f0a9059f89175f2ae8727a105" -and
    [bool]$closure.source.worktree_clean_at_execution
) "$gateId closure identity changed"

$sourceCommit = [string]$closure.source.commit
& git -C $repoRoot cat-file -e "$sourceCommit`^{commit}"
Assert-Exact ($LASTEXITCODE -eq 0) "$gateId source commit is not retained"
& git -C $repoRoot merge-base --is-ancestor $sourceCommit origin/main
Assert-Exact (
    $LASTEXITCODE -eq 0
) "$gateId source commit is not retained by origin/main"

foreach ($declared in @(
    $closure.declared_study.preregistration,
    $closure.declared_study.implementation,
    $closure.declared_study.shared_vh4_measurement_implementation,
    $closure.declared_study.supervisor,
    $closure.declared_study.prospective_freeze_audit
)) {
    $relativePath = [string]$declared.path
    $expectedRawSha256 = [string]$declared.raw_sha256
    Assert-Exact (
        (Get-GitBlobRawSha256 `
            -RepoRoot $repoRoot `
            -Commit $sourceCommit `
            -RelativePath $relativePath) -ceq
            $expectedRawSha256.Replace("sha256:", "")
    ) "$gateId frozen source blob changed: $relativePath"

    # Get-GitBlobRawSha256 above verifies the retained source object directly.
    # A later checkout is neither historical identity nor a safe proxy for it.
}

$attestationPath = [IO.Path]::GetFullPath(
    [string]$closure.qualification.full_godot_v2_attestation_path
)
Assert-Exact (
    (Get-RawSha256 -Path $attestationPath) -ceq
        [string]$closure.qualification.full_godot_v2_attestation_raw_sha256
) "$gateId qualification attestation hash changed"
. $operationLockPath
. $attestationHelperPath
$attestation = Get-Content -Raw -LiteralPath $attestationPath |
    ConvertFrom-Json -AsHashtable -Depth 64
$attestedSource = $attestation.source
$attestedBindings = @($attestation.source_bindings)
$attestationVerification = Test-SporeSporeFullConformanceAttestationDocument `
    -Document $attestation `
    -ExpectedSource $attestedSource `
    -ExpectedGodotIdentity $attestation.godot `
    -ExpectedPowerShellIdentity $attestation.powershell `
    -ExpectedSourceBindings $attestedBindings
Assert-Exact (
    [bool]$attestationVerification.ok -and
    @($attestationVerification.failure_codes).Count -eq 0 -and
    [string]$attestedSource.commit -ceq $sourceCommit -and
    [bool]$attestedSource.clean_pushed_live -and
    [bool]$attestation.conformance.godot_including -and
    -not [bool]$attestation.conformance.one_shot_physical_campaign_executed -and
    @($attestation.claims.Values | Where-Object { [bool]$_ }).Count -eq 0
) "$gateId qualification attestation no longer verifies"
foreach ($binding in $attestedBindings) {
    $blobSpec = $sourceCommit + ":" + [string]$binding.path
    Assert-Exact (
        (git -C $repoRoot rev-parse $blobSpec).Trim() -ceq
            [string]$binding.git_blob_oid
    ) "$gateId attested historical source binding changed"
}

$evidenceRoot = [IO.Path]::GetFullPath(
    [string]$closure.physical_evidence.evidence_root
)
$declaredFiles = @($closure.physical_evidence.files)
$actualFiles = @(Get-ChildItem -LiteralPath $evidenceRoot -File | Sort-Object Name)
Assert-Exact (
    $declaredFiles.Count -eq 6 -and
    $actualFiles.Count -eq 6 -and
    [int64]$closure.physical_evidence.total_bytes -eq
        [int64](($actualFiles | Measure-Object Length -Sum).Sum)
) "$gateId evidence inventory changed"
$treeRows = [System.Collections.Generic.List[string]]::new()
for ($index = 0; $index -lt $actualFiles.Count; $index += 1) {
    $file = $actualFiles[$index]
    $declared = $declaredFiles[$index]
    $hash = Get-RawSha256 -Path $file.FullName
    Assert-Exact (
        [string]$declared.name -ceq $file.Name -and
        [int64]$declared.bytes -eq $file.Length -and
        [string]$declared.raw_sha256 -ceq $hash
    ) "$gateId retained artifact changed: $($file.Name)"
    $treeRows.Add("$($file.Name)`t$($file.Length)`t$hash`n")
}
$treeBytes = [Text.Encoding]::UTF8.GetBytes(($treeRows -join ""))
$treeHash = [Convert]::ToHexString(
    [Security.Cryptography.SHA256]::HashData($treeBytes)
).ToLowerInvariant()
Assert-Exact (
    $treeHash -ceq [string]$closure.physical_evidence.tree_sha256
) "$gateId evidence tree hash changed"

$attempt = Get-Content -Raw -LiteralPath (Join-Path $evidenceRoot "attempt.json") |
    ConvertFrom-Json -AsHashtable -Depth 64
$completion = Get-Content -Raw -LiteralPath (
    Join-Path $evidenceRoot "completion.json"
) | ConvertFrom-Json -AsHashtable -Depth 64
$preflight = Get-Content -Raw -LiteralPath (
    Join-Path $evidenceRoot "preflight.json"
) | ConvertFrom-Json -AsHashtable -Depth 64
$reportPath = Join-Path $evidenceRoot "report.json"
$report = Get-Content -Raw -LiteralPath $reportPath |
    ConvertFrom-Json -AsHashtable -Depth 100
Assert-Exact (
    [string]$attempt.attempt_id -ceq
        [string]$closure.physical_evidence.attempt_id -and
    [string]$completion.attempt_id -ceq [string]$attempt.attempt_id -and
    [bool]$attempt.physical_process_launch_consumes_identity -and
    [int]$attempt.replacement_processes_allowed -eq 0 -and
    [string]$attempt.full_conformance_attestation_raw_sha256 -ceq
        ("sha256:" + [string]$closure.qualification.full_godot_v2_attestation_raw_sha256) -and
    [bool]$completion.process_launched -and
    [int]$completion.process_exit_code -eq 0 -and
    $null -eq $completion.launch_error -and
    [bool]$completion.report_present -and
    [string]$completion.report_raw_sha256 -ceq
        ("sha256:" + (Get-RawSha256 -Path $reportPath)) -and
    [bool]$preflight.ok -and
    [int]$preflight.negative_control_count -eq 24 -and
    [int]$preflight.compiled_force_limit_canary_count -eq 4 -and
    [int]$preflight.binding_surface_canary_count -eq 5 -and
    [int]$preflight.world_build_count -eq 0
) "$gateId attempt, completion, or preflight receipt changed"

$forceClassIds = @("front_hip", "front_knee", "rear_hip", "rear_knee")
$baseIds = @(
    "unloaded_vn075", "unloaded_vp075",
    "unloaded_vn225", "unloaded_vp225",
    "loaded_vn150_tn075", "loaded_vn150_tp075",
    "loaded_vn150_tn225", "loaded_vn150_tp225",
    "loaded_vp150_tn075", "loaded_vp150_tp075",
    "loaded_vp150_tn225", "loaded_vp150_tp225"
)
$initialProfiles = @("zero", "adverse")
$expectedIds = @(
    foreach ($forceClassId in $forceClassIds) {
        foreach ($baseId in $baseIds) {
            foreach ($initialProfile in $initialProfiles) {
                "$forceClassId`__$baseId`__i$initialProfile"
            }
        }
    }
)
$cells = @($report.cells)
$pairs = @($report.mirrored_pairs)
Assert-Exact (
    [bool]$report.ok -and
    [int]$report.passed_cells -eq 96 -and
    [int]$report.failed_cells -eq 0 -and
    @($report.failures).Count -eq 0 -and
    ([string[]]@($cells | ForEach-Object { [string]$_.cell_id }) -join "|") -ceq
        ($expectedIds -join "|") -and
    $cells.Count -eq 96 -and
    @($cells | Where-Object { -not [bool]$_.passed }).Count -eq 0 -and
    @($cells | Where-Object {
        @($_.internal_step_trace).Count -ne 1800 -or
        @($_.internal_step_trace[0]).Count -ne 17
    }).Count -eq 0 -and
    $pairs.Count -eq 48 -and
    @($pairs | Where-Object { -not [bool]$_.passed }).Count -eq 0
) "$gateId complete positive report changed"

$declaredLimits = [ordered]@{
    front_hip = 6.435150204824762
    front_knee = 5.265122894856622
    rear_hip = 6.764849795175239
    rear_knee = 5.534877105143378
}
foreach ($forceClassId in $forceClassIds) {
    $classCells = @($cells | Where-Object {
        [string]$_.force_limit_class_id -ceq $forceClassId
    })
    Assert-Exact (
        $classCells.Count -eq 24 -and
        @($classCells | Where-Object { -not [bool]$_.passed }).Count -eq 0 -and
        @($classCells | Where-Object {
            [double]$_.maximum_force_nm -ne [double]$declaredLimits[$forceClassId]
        }).Count -eq 0
    ) "$gateId force-limit class result changed: $forceClassId"
}

$integrity = $report.integrity
$zeroIntegrityNames = @(
    "world_reset_count",
    "model_or_field_mismatch_count",
    "initial_velocity_readback_mismatch_count",
    "trace_cardinality_mismatch_count",
    "nonfinite_observation_count",
    "internal_step_force_time_budget_violation_count",
    "controller_step_cumulative_force_time_budget_violation_count",
    "effective_motor_impulse_limit_violation_count",
    "actuation_space_to_joint_space_force_mismatch_count",
    "applied_torque_readback_mismatch_count",
    "generalized_inertia_readback_mismatch_count",
    "saturated_step_force_time_to_momentum_mismatch_count",
    "unsaturated_post_state_force_time_to_momentum_mismatch_count",
    "temporal_force_distinction_missing_count",
    "state_continuity_mismatch_count"
)
Assert-Exact (
    [int]$integrity.world_attempt_count -eq 96 -and
    [int]$integrity.world_build_count -eq 96 -and
    [int]$integrity.internal_trace_record_count -eq 172800 -and
    @($zeroIntegrityNames | Where-Object { [int]$integrity[$_] -ne 0 }).Count -eq 0
) "$gateId integrity counts changed"

$totalSaturation = [int](($cells | Measure-Object `
    saturated_internal_step_count -Sum).Sum)
$minimumWitnesses = [int](($cells | Measure-Object `
    temporal_force_distinction_witness_count -Minimum).Minimum)
$maximumWitnesses = [int](($cells | Measure-Object `
    temporal_force_distinction_witness_count -Maximum).Maximum)
$maximumSaturatedError = [double](($cells | Measure-Object `
    maximum_saturated_step_force_time_to_momentum_error_nms -Maximum).Maximum)
$maximumUnsaturatedError = [double](($cells | Measure-Object `
    maximum_unsaturated_post_state_force_time_to_momentum_error_nms -Maximum).Maximum)
$maximumVelocityAsymmetry = [double](($pairs | Measure-Object `
    velocity_response_relative_asymmetry -Maximum).Maximum)
$maximumForceAsymmetry = [double](($pairs | Measure-Object `
    force_response_relative_asymmetry -Maximum).Maximum)
Assert-Exact (
    $totalSaturation -eq 470 -and
    $minimumWitnesses -eq 36 -and
    $maximumWitnesses -eq 43 -and
    $maximumSaturatedError -le 1.0e-12 -and
    $maximumUnsaturatedError -le 1.0e-12 -and
    $maximumVelocityAsymmetry -eq 0.0 -and
    $maximumForceAsymmetry -eq 0.0 -and
    @($cells | Where-Object {
        -not [bool]$_.temporal_measurement_valid -or
        [int]$_.longest_acceptable_outer_streak -ne 240
    }).Count -eq 0
) "$gateId temporal, momentum, or symmetry result changed"

# Replay the retained report through the production evaluator. This opens zero
# worlds and guards against trusting only the report's positive summary fields.
Push-Location -LiteralPath $mujocoRoot
try {
    $evaluationLines = @(
        & $python -c (
            "import json; from sporespore_mujoco_adapter." +
            "s169_force_limit_characterization_vh5 import evaluate_report as e; " +
            "r=json.load(open(r'$($reportPath.Replace("\", "/"))'," +
            "encoding='utf-8')); print(json.dumps(e(r)))"
        )
    )
    Assert-Exact ($LASTEXITCODE -eq 0) "$gateId production evaluator replay failed"
} finally {
    Pop-Location
}
$evaluationFailures = ($evaluationLines -join [Environment]::NewLine) |
    ConvertFrom-Json
Assert-Exact (
    @($evaluationFailures).Count -eq 0
) "$gateId retained report no longer passes its frozen evaluator"

Assert-Exact (
    [bool]$closure.technical_disposition.
        scientific_positive_exact_finite_s169_per_actuator_host_characterization -and
    [bool]$closure.claims.exact_finite_vh5_s169_per_actuator_host_characterization_positive -and
    [bool]$closure.claims.all_four_declared_force_limit_classes_positive -and
    -not [bool]$closure.claims.mujoco_selected_policy_locomotion -and
    -not [bool]$closure.claims.mujoco_walking -and
    -not [bool]$closure.claims.cross_engine_equivalence -and
    -not [bool]$closure.claims.release_authorized -and
    -not [bool]$closure.claims.physical_acceptance_authority
) "$gateId scientific claim boundary changed"

$beforeRoots = @(
    Get-ChildItem -LiteralPath (Split-Path -Parent $evidenceRoot) `
        -Directory `
        -Filter "c6-mujoco-s169-force-limit-vh5-*" |
        Select-Object -ExpandProperty FullName
)
$refusal = ""
try {
    & $runnerPath `
        -RunPhysical `
        -FullConformanceAttestation $attestationPath 2>&1 | Out-Null
    $refusal = "RUNNER_UNEXPECTEDLY_RETURNED"
} catch {
    $refusal = $_.Exception.Message
}
$afterRoots = @(
    Get-ChildItem -LiteralPath (Split-Path -Parent $evidenceRoot) `
        -Directory `
        -Filter "c6-mujoco-s169-force-limit-vh5-*" |
        Select-Object -ExpandProperty FullName
)
Assert-Exact (
    $refusal -like "*closed and may not open another world*" -and
    ($beforeRoots -join "|") -ceq ($afterRoots -join "|")
) "$gateId same-identity physical refusal failed"

Write-Host (
    "C6_MJC_HC_VH5_CLOSURE_PASS status=positive worlds=96 passed=96 " +
    "failed=0 pairs=48 traces=172800 saturation=470 witnesses=36..43 " +
    "force_classes=4 temporal_measurement=True momentum_gates=True " +
    "scientific_positive=True walking=False physical_authority=False " +
    "rerun_refused=True"
)
