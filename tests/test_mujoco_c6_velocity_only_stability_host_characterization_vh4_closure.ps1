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
            "C6-MJC-HC-VH4 could not start historical blob reader: $RelativePath"
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
            "C6-MJC-HC-VH4 could not read historical blob $RelativePath`: " +
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
    "mujoco_c6_velocity_only_stability_host_characterization_vh4_closure.json"
)
$runnerPath = Join-Path $sdkRoot (
    "run_mujoco_c6_velocity_only_stability_host_characterization_vh4.ps1"
)
$attestationHelperPath = Join-Path $sdkRoot (
    "locomotion_full_conformance_attestation.ps1"
)
$operationLockPath = Join-Path $sdkRoot "locomotion_operation_lock.ps1"
$expectedClosureSha256 = (
    "faf6aabe9d5bb36a410a4447416c63697666640b458bae49ee1662aa045e4cb9"
)

Assert-Exact (
    (git -C $repoRoot rev-parse --show-toplevel).Trim() -ceq
        $repoRoot.Replace("\", "/")
) "C6-MJC-HC-VH4 closure audit ran outside SporeSpore"
Assert-Exact (
    (git -C $repoRoot remote get-url origin).Trim() -ceq
        "https://github.com/Slagathore/sporespore.git"
) "C6-MJC-HC-VH4 closure audit origin mismatch"
foreach ($path in @(
    $python,
    $closurePath,
    $runnerPath,
    $attestationHelperPath,
    $operationLockPath
)) {
    Assert-Exact (
        Test-Path -LiteralPath $path -PathType Leaf
    ) "C6-MJC-HC-VH4 closure dependency missing: $path"
}
Assert-Exact (
    (Get-RawSha256 -Path $closurePath) -ceq $expectedClosureSha256
) "C6-MJC-HC-VH4 closure bytes changed"

$closure = Get-Content -Raw -LiteralPath $closurePath |
    ConvertFrom-Json -AsHashtable -Depth 64
Assert-Exact (
    [string]$closure.schema_version -ceq
        "sporespore_mujoco_c6_velocity_only_stability_host_characterization_vh4_closure_v1" -and
    [string]$closure.campaign_id -ceq
        "C6-MUJOCO-VELOCITY-ONLY-STABILITY-HOST-CHARACTERIZATION-VH4" -and
    [string]$closure.gate_id -ceq "C6-MJC-HC-VH4" -and
    [string]$closure.status -ceq
        "closed_complete_valid_positive_exact_finite_host_characterization" -and
    [string]$closure.source.commit -ceq
        "2722c2b1220c91993c1c8263769bd834e2b51c27" -and
    [string]$closure.source.tree_git_oid -ceq
        "1d1cafbbf93a9f5830f4c1b87566c9e9e12ed3de" -and
    [bool]$closure.source.worktree_clean_at_execution
) "C6-MJC-HC-VH4 closure identity changed"

$sourceCommit = [string]$closure.source.commit
& git -C $repoRoot cat-file -e "$sourceCommit`^{commit}"
Assert-Exact ($LASTEXITCODE -eq 0) "C6-MJC-HC-VH4 source commit is not retained"
& git -C $repoRoot merge-base --is-ancestor $sourceCommit origin/main
Assert-Exact (
    $LASTEXITCODE -eq 0
) "C6-MJC-HC-VH4 source commit is not retained by origin/main"

foreach ($declared in @(
    $closure.declared_study.preregistration,
    $closure.declared_study.implementation,
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
    ) "C6-MJC-HC-VH4 frozen source blob changed: $relativePath"

    # Get-GitBlobRawSha256 above verifies the retained source object directly.
    # A later checkout is neither historical identity nor a safe proxy for it.
}

$attestationPath = [IO.Path]::GetFullPath(
    [string]$closure.qualification.full_godot_v2_attestation_path
)
Assert-Exact (
    (Get-RawSha256 -Path $attestationPath) -ceq
        [string]$closure.qualification.full_godot_v2_attestation_raw_sha256
) "C6-MJC-HC-VH4 qualification attestation hash changed"
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
    [string]$attestedSource.commit -ceq [string]$closure.source.commit -and
    [bool]$attestedSource.clean_pushed_live -and
    [bool]$attestation.conformance.godot_including -and
    -not [bool]$attestation.conformance.one_shot_physical_campaign_executed -and
    @($attestation.claims.Values | Where-Object { [bool]$_ }).Count -eq 0
) "C6-MJC-HC-VH4 qualification attestation no longer verifies"
foreach ($binding in $attestedBindings) {
    $blobSpec = [string]$closure.source.commit + ":" + [string]$binding.path
    Assert-Exact (
        (git -C $repoRoot rev-parse $blobSpec).Trim() -ceq
            [string]$binding.git_blob_oid
    ) "C6-MJC-HC-VH4 attested historical source binding changed"
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
) "C6-MJC-HC-VH4 evidence inventory changed"
$treeRows = [System.Collections.Generic.List[string]]::new()
for ($index = 0; $index -lt $actualFiles.Count; $index += 1) {
    $file = $actualFiles[$index]
    $declared = $declaredFiles[$index]
    $hash = Get-RawSha256 -Path $file.FullName
    Assert-Exact (
        [string]$declared.name -ceq $file.Name -and
        [int64]$declared.bytes -eq $file.Length -and
        [string]$declared.raw_sha256 -ceq $hash
    ) "C6-MJC-HC-VH4 retained artifact changed: $($file.Name)"
    $treeRows.Add("$($file.Name)`t$($file.Length)`t$hash`n")
}
$treeBytes = [Text.Encoding]::UTF8.GetBytes(($treeRows -join ""))
$treeHash = [Convert]::ToHexString(
    [Security.Cryptography.SHA256]::HashData($treeBytes)
).ToLowerInvariant()
Assert-Exact (
    $treeHash -ceq [string]$closure.physical_evidence.tree_sha256
) "C6-MJC-HC-VH4 evidence tree hash changed"

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
    ConvertFrom-Json -AsHashtable -Depth 64
Assert-Exact (
    [string]$attempt.attempt_id -ceq
        [string]$closure.physical_evidence.attempt_id -and
    [string]$completion.attempt_id -ceq [string]$attempt.attempt_id -and
    [bool]$attempt.physical_process_launch_consumes_identity -and
    [int]$attempt.replacement_processes_allowed -eq 0 -and
    [bool]$completion.process_launched -and
    [int]$completion.process_exit_code -eq 0 -and
    $null -eq $completion.launch_error -and
    [bool]$completion.report_present -and
    [string]$completion.report_raw_sha256 -ceq
        ("sha256:" + (Get-RawSha256 -Path $reportPath)) -and
    [bool]$preflight.ok -and
    [int]$preflight.negative_control_count -eq 23 -and
    [int]$preflight.binding_surface_canary_count -eq 5 -and
    [int]$preflight.world_build_count -eq 0
) "C6-MJC-HC-VH4 attempt, completion, or preflight receipt changed"

$expectedIds = @(
    "unloaded_vn075_izero", "unloaded_vn075_iadverse",
    "unloaded_vp075_izero", "unloaded_vp075_iadverse",
    "unloaded_vn225_izero", "unloaded_vn225_iadverse",
    "unloaded_vp225_izero", "unloaded_vp225_iadverse",
    "loaded_vn150_tn075_izero", "loaded_vn150_tn075_iadverse",
    "loaded_vn150_tp075_izero", "loaded_vn150_tp075_iadverse",
    "loaded_vn150_tn225_izero", "loaded_vn150_tn225_iadverse",
    "loaded_vn150_tp225_izero", "loaded_vn150_tp225_iadverse",
    "loaded_vp150_tn075_izero", "loaded_vp150_tn075_iadverse",
    "loaded_vp150_tp075_izero", "loaded_vp150_tp075_iadverse",
    "loaded_vp150_tn225_izero", "loaded_vp150_tn225_iadverse",
    "loaded_vp150_tp225_izero", "loaded_vp150_tp225_iadverse"
)
$cells = @($report.cells)
$pairs = @($report.mirrored_pairs)
Assert-Exact (
    [bool]$report.ok -and
    [int]$report.passed_cells -eq 24 -and
    [int]$report.failed_cells -eq 0 -and
    @($report.failures).Count -eq 0 -and
    ([string[]]@($cells | ForEach-Object { [string]$_.cell_id }) -join "|") -ceq
        ($expectedIds -join "|") -and
    $cells.Count -eq 24 -and
    @($cells | Where-Object { -not [bool]$_.passed }).Count -eq 0 -and
    @($cells | Where-Object {
        @($_.internal_step_trace).Count -ne 1800 -or
        @($_.internal_step_trace[0]).Count -ne 17
    }).Count -eq 0 -and
    $pairs.Count -eq 12 -and
    @($pairs | Where-Object { -not [bool]$_.passed }).Count -eq 0
) "C6-MJC-HC-VH4 complete positive report changed"

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
    [int]$integrity.world_attempt_count -eq 24 -and
    [int]$integrity.world_build_count -eq 24 -and
    [int]$integrity.internal_trace_record_count -eq 43200 -and
    @($zeroIntegrityNames | Where-Object { [int]$integrity[$_] -ne 0 }).Count -eq 0
) "C6-MJC-HC-VH4 integrity counts changed"

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
Assert-Exact (
    $totalSaturation -eq 114 -and
    $minimumWitnesses -eq 40 -and
    $maximumWitnesses -eq 43 -and
    $maximumSaturatedError -le 1.0e-12 -and
    $maximumUnsaturatedError -le 1.0e-12 -and
    @($cells | Where-Object {
        -not [bool]$_.temporal_measurement_valid -or
        [double]$_.maximum_internal_step_force_time_budget_nms -gt 0.010000000001 -or
        [double]$_.maximum_effective_motor_impulse_nms -gt 0.010000000001
    }).Count -eq 0
) "C6-MJC-HC-VH4 temporal measurement result changed"

# Re-run the frozen production evaluator over the retained report. This opens
# zero worlds and provides stronger coverage than trusting summary fields.
Push-Location -LiteralPath $mujocoRoot
try {
    $evaluationLines = @(
        & $python -c (
            "import json; from sporespore_mujoco_adapter." +
            "velocity_only_stability_characterization_vh4 import " +
            "evaluate_stability_host_report as e; " +
            "r=json.load(open(r'$($reportPath.Replace("\", "/"))'," +
            "encoding='utf-8')); print(json.dumps(e(r)))"
        )
    )
    Assert-Exact ($LASTEXITCODE -eq 0) (
        "C6-MJC-HC-VH4 production evaluator replay failed"
    )
} finally {
    Pop-Location
}
$evaluationFailures = ($evaluationLines -join [Environment]::NewLine) |
    ConvertFrom-Json
Assert-Exact (
    @($evaluationFailures).Count -eq 0
) "C6-MJC-HC-VH4 retained report no longer passes its frozen evaluator"

Assert-Exact (
    [bool]$closure.technical_disposition.
        scientific_positive_exact_finite_host_characterization -and
    [bool]$closure.claims.exact_finite_vh4_host_characterization_positive -and
    [bool]$closure.claims.exact_finite_dynamic_saturation_recovery_positive -and
    -not [bool]$closure.claims.mujoco_selected_policy_locomotion -and
    -not [bool]$closure.claims.mujoco_walking -and
    -not [bool]$closure.claims.cross_engine_equivalence -and
    -not [bool]$closure.claims.release_authorized -and
    -not [bool]$closure.claims.physical_acceptance_authority
) "C6-MJC-HC-VH4 scientific claim boundary changed"

# The closure must reject physical replay before mutable source, attestation,
# output, or model checks. No second evidence directory may appear.
$beforeRoots = @(
    Get-ChildItem -LiteralPath (Split-Path -Parent $evidenceRoot) `
        -Directory `
        -Filter "c6-mujoco-velocity-only-stability-vh4-*" |
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
        -Filter "c6-mujoco-velocity-only-stability-vh4-*" |
        Select-Object -ExpandProperty FullName
)
Assert-Exact (
    $refusal -like "*closed and may not open another world*" -and
    ($beforeRoots -join "|") -ceq ($afterRoots -join "|")
) "C6-MJC-HC-VH4 same-identity physical refusal failed"

Write-Host (
    "C6_MJC_HC_VH4_CLOSURE_PASS status=positive worlds=24 " +
    "passed=24 failed=0 traces=43200 saturation=114 witnesses=40..43 " +
    "temporal_measurement=True momentum_gates=True scientific_positive=True " +
    "walking=False physical_authority=False rerun_refused=True"
)
