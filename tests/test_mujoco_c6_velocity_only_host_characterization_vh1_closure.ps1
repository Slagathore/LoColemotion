#requires -Version 7.0

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$manifestPath = Join-Path $repoRoot `
    "sdk\mujoco_c6_velocity_only_host_characterization_vh1_closure.json"
$expectedManifestSha256 = "e3f6d9a801ac1781b6a3d30d34b13ae7e33db603e5ce55b5cbed4a2627550ca5"
$expectedSourceCommit = "19831738abf8800f572e974898980c2b8aab1c40"
$expectedCellIds = @(
    "unloaded_vn075",
    "unloaded_vp075",
    "unloaded_vn225",
    "unloaded_vp225",
    "loaded_vn150_tn075",
    "loaded_vn150_tp075",
    "loaded_vn150_tn225",
    "loaded_vn150_tp225",
    "loaded_vp150_tn075",
    "loaded_vp150_tp075",
    "loaded_vp150_tn225",
    "loaded_vp150_tp225"
)
$expectedFailures = @(
    "C6_MJC_HC_VH1_CELL_GATE:unloaded_vn075",
    "C6_MJC_HC_VH1_CELL_GATE:unloaded_vp075",
    "C6_MJC_HC_VH1_CELL_GATE:unloaded_vn225",
    "C6_MJC_HC_VH1_CELL_GATE:unloaded_vp225"
)

function Assert-Exact {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function Assert-Close {
    param(
        [double]$Actual,
        [double]$Expected,
        [double]$Tolerance,
        [string]$Message
    )
    Assert-Exact (
        [double]::IsFinite($Actual) -and
        [math]::Abs($Actual - $Expected) -le $Tolerance
    ) $Message
}

function Get-Sha256 {
    param([Parameter(Mandatory)][string]$Path)
    return (Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash.ToLowerInvariant()
}

function Assert-HashedFile {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$ExpectedSha256,
        [Parameter(Mandatory)][long]$ExpectedSize,
        [Parameter(Mandatory)][string]$Message
    )
    Assert-Exact (
        (Test-Path -LiteralPath $Path -PathType Leaf) -and
        (Get-Sha256 -Path $Path) -ceq $ExpectedSha256.Replace("sha256:", "") -and
        (Get-Item -LiteralPath $Path).Length -eq $ExpectedSize
    ) $Message
}

function Get-GitBlobSha256 {
    param(
        [Parameter(Mandatory)][string]$Commit,
        [Parameter(Mandatory)][string]$Path
    )
    $start = [Diagnostics.ProcessStartInfo]::new()
    $start.FileName = (Get-Command git -ErrorAction Stop).Source
    $start.WorkingDirectory = $repoRoot
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    [void]$start.ArgumentList.Add("-C")
    [void]$start.ArgumentList.Add($repoRoot)
    [void]$start.ArgumentList.Add("cat-file")
    [void]$start.ArgumentList.Add("blob")
    [void]$start.ArgumentList.Add("$Commit`:$Path")
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $start
    Assert-Exact $process.Start() "Failed to start the VH1 Git-blob audit"
    $memory = [IO.MemoryStream]::new()
    try {
        $process.StandardOutput.BaseStream.CopyTo($memory)
        $stderr = $process.StandardError.ReadToEnd()
        $process.WaitForExit()
        Assert-Exact ($process.ExitCode -eq 0) `
            "Git blob audit failed for $Commit`:$Path`: $stderr"
        return [Convert]::ToHexString(
            [Security.Cryptography.SHA256]::HashData($memory.ToArray())
        ).ToLowerInvariant()
    } finally {
        $memory.Dispose()
        $process.Dispose()
    }
}

Assert-Exact (
    (Get-Sha256 -Path $manifestPath) -ceq $expectedManifestSha256
) "The C6-MJC-HC-VH1 closure manifest changed"
$manifest = Get-Content -Raw -LiteralPath $manifestPath |
    ConvertFrom-Json -AsHashtable -Depth 64

Assert-Exact (
    [string]$manifest.schema_version -ceq
        "sporespore_mujoco_c6_velocity_only_host_characterization_vh1_closure_v1" -and
    [string]$manifest.status -ceq
        "closed_complete_valid_negative_unloaded_velocity_response" -and
    [string]$manifest.campaign_id -ceq
        "C6-MUJOCO-VELOCITY-ONLY-HOST-CHARACTERIZATION-VH1" -and
    [string]$manifest.gate_id -ceq "C6-MJC-HC-VH1" -and
    [string]$manifest.experiment_source_commit -ceq $expectedSourceCommit -and
    [bool]$manifest.source_was_clean_and_equal_to_origin_main_and_live_github_main -and
    [bool]$manifest.technical_disposition.valid_complete_physical_report -and
    -not [bool]$manifest.technical_disposition.
        exact_finite_velocity_only_host_characterization_passed -and
    [bool]$manifest.technical_disposition.all_loaded_affine_response_cells_passed -and
    [bool]$manifest.technical_disposition.all_unloaded_velocity_response_cells_failed -and
    [bool]$manifest.mechanism_learning.optimization_is_allowed -and
    [bool]$manifest.immutability.same_identity_rerun_forbidden -and
    [bool]$manifest.immutability.report_rewrite_forbidden -and
    [bool]$manifest.immutability.threshold_change_forbidden -and
    [bool]$manifest.immutability.cell_grid_change_forbidden -and
    [bool]$manifest.immutability.loaded_cells_may_not_be_split_out_as_a_retroactive_positive_campaign -and
    [bool]$manifest.immutability.successor_requires_new_identity
) "The C6-MJC-HC-VH1 closure identity, result, or immutability changed"

& git -C $repoRoot cat-file -e "$expectedSourceCommit`^{commit}"
Assert-Exact ($LASTEXITCODE -eq 0) "The VH1 experiment commit is not retained"
& git -C $repoRoot merge-base --is-ancestor $expectedSourceCommit HEAD
Assert-Exact ($LASTEXITCODE -eq 0) "The VH1 experiment commit is not an ancestor"
$originMain = (& git -C $repoRoot rev-parse origin/main).Trim()
Assert-Exact ($LASTEXITCODE -eq 0) "origin/main could not be resolved"
& git -C $repoRoot merge-base --is-ancestor $expectedSourceCommit $originMain
Assert-Exact ($LASTEXITCODE -eq 0) "The VH1 commit is not retained on origin/main"

foreach ($source in @($manifest.bound_source_inventory.Values)) {
    $actualSourceSha256 = Get-GitBlobSha256 `
        -Commit $expectedSourceCommit `
        -Path ([string]$source.path)
    Assert-Exact (
        $actualSourceSha256 -ceq
            ([string]$source.raw_sha256).Replace("sha256:", "")
    ) (
        "Experiment-commit C6-MJC-HC-VH1 source blob mismatch: " +
        "$($source.path); expected=$($source.raw_sha256); actual=$actualSourceSha256"
    )
}

$attempt = $manifest.complete_attempt
foreach ($name in @("attempt", "preflight", "report", "stdout", "stderr", "completion")) {
    Assert-HashedFile `
        -Path ([string]$attempt["${name}_path"]) `
        -ExpectedSha256 ([string]$attempt["${name}_sha256"]) `
        -ExpectedSize ([long]$attempt["${name}_size_bytes"]) `
        -Message "The retained C6-MJC-HC-VH1 $name artifact changed"
}
Assert-HashedFile `
    -Path ([string]$manifest.full_godot_v2_attestation.path) `
    -ExpectedSha256 ([string]$manifest.full_godot_v2_attestation.raw_sha256) `
    -ExpectedSize ((Get-Item -LiteralPath ([string]$manifest.full_godot_v2_attestation.path)).Length) `
    -Message "The retained VH1 full-Godot attestation changed"

$attemptReceipt = Get-Content -Raw -LiteralPath ([string]$attempt.attempt_path) |
    ConvertFrom-Json -AsHashtable -Depth 64
$completion = Get-Content -Raw -LiteralPath ([string]$attempt.completion_path) |
    ConvertFrom-Json -AsHashtable -Depth 64
$preflight = Get-Content -Raw -LiteralPath ([string]$attempt.preflight_path) |
    ConvertFrom-Json -AsHashtable -Depth 64
$report = Get-Content -Raw -LiteralPath ([string]$attempt.report_path) |
    ConvertFrom-Json -AsHashtable -Depth 64
$attestation = Get-Content -Raw -LiteralPath (
    [string]$manifest.full_godot_v2_attestation.path
) | ConvertFrom-Json -AsHashtable -Depth 64

Assert-Exact (
    [string]$attemptReceipt.campaign_id -ceq [string]$manifest.campaign_id -and
    [string]$attemptReceipt.gate_id -ceq [string]$manifest.gate_id -and
    [string]$attemptReceipt.source_commit -ceq $expectedSourceCommit -and
    [bool]$attemptReceipt.physical_process_launch_consumes_identity -and
    [int]$attemptReceipt.replacement_processes_allowed -eq 0 -and
    [bool]$attemptReceipt.operation_lock.acquired -and
    [string]$attemptReceipt.operation_lock.role -ceq "physical" -and
    -not [bool]$attemptReceipt.operation_lock.test_only
) "The VH1 attempt reservation or operation-lock receipt changed"
Assert-Exact (
    [string]$completion.attempt_id -ceq [string]$attemptReceipt.attempt_id -and
    [bool]$completion.process_launched -and
    [int]$completion.process_exit_code -eq 1 -and
    $null -eq $completion.launch_error -and
    [bool]$completion.report_present -and
    [string]$completion.report_raw_sha256 -ceq
        ("sha256:" + [string]$attempt.report_sha256)
) "The complete negative VH1 process receipt changed"
Assert-Exact (
    [bool]$preflight.ok -and
    [bool]$preflight.perfect_synthetic_result_passed -and
    [bool]$preflight.perfect_synthetic_serialization_round_trip_passed -and
    [int]$preflight.negative_control_count -eq 10 -and
    [int]$preflight.world_build_count -eq 0 -and
    -not [bool]$preflight.physics_state_modified -and
    -not [bool]$preflight.physical_acceptance_authority
) "The retained VH1 zero-world preflight changed"
Assert-Exact (
    [string]$attestation.schema_version -ceq
        "sporespore_full_godot_conformance_attestation_v2" -and
    [string]$attestation.source.commit -ceq $expectedSourceCommit -and
    [bool]$attestation.source.clean_pushed_live -and
    [bool]$attestation.conformance.passed -and
    [string]$attestation.conformance.canonical_terminal_marker -ceq
        "SDK C0/C1 conformance passed." -and
    -not [bool]$attestation.conformance.one_shot_physical_campaign_executed -and
    @($attestation.claims.Values | Where-Object { [bool]$_ }).Count -eq 0
) "The VH1 full-Godot attestation boundary changed"

Assert-Exact (
    [string]$report.schema_version -ceq
        "sporespore_mujoco_c6_velocity_only_host_characterization_vh1_report_v1" -and
    -not [bool]$report.ok -and
    [string]$report.source.commit -ceq $expectedSourceCommit -and
    @($report.cells).Count -eq 12 -and
    (@($report.cells | ForEach-Object { $_.cell_id }) -join "`n") -ceq
        ($expectedCellIds -join "`n") -and
    (@($report.failures) -join "`n") -ceq ($expectedFailures -join "`n") -and
    [int]$report.passed_cells -eq 8 -and
    [int]$report.failed_cells -eq 4 -and
    [int]$report.integrity.world_attempt_count -eq 12 -and
    [int]$report.integrity.world_build_count -eq 12 -and
    [int]$report.integrity.world_reset_count -eq 0 -and
    [int]$report.integrity.model_or_field_mismatch_count -eq 0 -and
    [int]$report.integrity.nonfinite_observation_count -eq 0 -and
    [int]$report.integrity.derived_step_impulse_limit_violation_count -eq 0 -and
    [int]$report.integrity.actuation_space_to_joint_space_force_mismatch_count -eq 0 -and
    [int]$report.integrity.applied_torque_readback_mismatch_count -eq 0 -and
    -not [bool]$report.claim_boundary.exact_finite_mujoco_velocity_only_host_characterization_if_passed -and
    -not [bool]$report.claim_boundary.mujoco_selected_policy_locomotion -and
    -not [bool]$report.claim_boundary.mujoco_walking -and
    -not [bool]$report.physical_acceptance_authority
) "The complete negative VH1 report boundary changed"

$unloaded = @($report.cells | Where-Object { $_.kind -ceq "unloaded" })
$loaded = @($report.cells | Where-Object { $_.kind -ceq "loaded" })
Assert-Exact (
    $unloaded.Count -eq 4 -and
    @($unloaded | Where-Object { [bool]$_.passed }).Count -eq 0 -and
    @($loaded | Where-Object { -not [bool]$_.passed }).Count -eq 0
) "The VH1 loaded/unloaded disposition changed"
foreach ($cell in $unloaded) {
    Assert-Close ([double]$cell.terminal_joint_velocity_rad_s) 0.0 0.0 `
        "An unloaded VH1 terminal velocity changed"
    Assert-Close ([math]::Abs([double]$cell.terminal_actuator_force_nm)) 6.0 0.0 `
        "An unloaded VH1 terminal force changed"
    Assert-Close ([math]::Abs([double]$cell.terminal_joint_position_rad)) `
        4.4999999999999964 1e-14 "An unloaded VH1 terminal position changed"
    Assert-Exact (
        [int]$cell.longest_acceptable_streak -eq 0 -and
        $null -eq $cell.first_acceptable_step -and
        [bool]$cell.motor_profile_fields_match -and
        [bool]$cell.all_values_finite -and
        [int]$cell.derived_step_impulse_limit_violation_count -eq 0
    ) "An unloaded VH1 cell gate changed"
}
foreach ($cell in $loaded) {
    Assert-Close ([double]$cell.terminal_normalized_velocity_response) 1.0 1e-14 `
        "A loaded VH1 velocity response changed"
    Assert-Close ([double]$cell.terminal_normalized_force_response) 1.0 0.0 `
        "A loaded VH1 force response changed"
    Assert-Exact (
        [int]$cell.first_acceptable_step -eq 120 -and
        [int]$cell.longest_acceptable_streak -eq 240 -and
        [bool]$cell.target_and_response_signs_match -and
        [bool]$cell.loaded_force_opposes_external_torque
    ) "A loaded VH1 cell gate changed"
}
Assert-Exact (
    @($report.mirrored_pairs).Count -eq 6 -and
    @($report.mirrored_pairs | Where-Object {
        -not [bool]$_.passed -or
        [double]$_.velocity_response_relative_asymmetry -ne 0.0
    }).Count -eq 0
) "The VH1 mirrored-pair result changed"

$runnerPath = Join-Path $repoRoot `
    "sdk\run_mujoco_c6_velocity_only_host_characterization_vh1.ps1"
$runnerText = Get-Content -Raw -LiteralPath $runnerPath
Assert-Exact (
    $runnerText.Contains("prior evidence exists; same-identity rerun is forbidden") -and
    $runnerText.Contains("is closed and may not open another world")
) "The VH1 runner no longer fails closed after closure"

# Exercise the real physical entrypoint after closure. It may replay the
# zero-world synthetic preflight, but it must refuse before reserving an attempt,
# acquiring the physical lock, validating an attestation, or constructing a
# MuJoCo model. The deliberately nonexistent attestation is a downstream canary:
# the closure refusal must win first.
$evidenceParent = Split-Path -Parent ([string]$attempt.root)
$evidenceRootsBefore = @(
    Get-ChildItem -LiteralPath $evidenceParent -Directory `
        -Filter "c6-mujoco-velocity-only-vh1-*" -ErrorAction SilentlyContinue |
        Sort-Object FullName |
        ForEach-Object { $_.FullName }
)
$start = [Diagnostics.ProcessStartInfo]::new()
$start.FileName = (Get-Command pwsh -ErrorAction Stop).Source
$start.WorkingDirectory = $repoRoot
$start.UseShellExecute = $false
$start.CreateNoWindow = $true
$start.RedirectStandardOutput = $true
$start.RedirectStandardError = $true
foreach ($argument in @(
    "-NoLogo",
    "-NoProfile",
    "-File",
    $runnerPath,
    "-RunPhysical",
    "-FullConformanceAttestation",
    "C6_MJC_HC_VH1_CLOSED_CANARY_MUST_NOT_BE_READ"
)) {
    [void]$start.ArgumentList.Add($argument)
}
$process = [Diagnostics.Process]::new()
$process.StartInfo = $start
try {
    Assert-Exact $process.Start() "Failed to start the VH1 closed-runner canary"
    $stdout = $process.StandardOutput.ReadToEnd()
    $stderr = $process.StandardError.ReadToEnd()
    $process.WaitForExit()
    $combinedOutput = $stdout + "`n" + $stderr
    Assert-Exact (
        $process.ExitCode -ne 0 -and
        $combinedOutput.Contains(
            "C6-MJC-HC-VH1 is closed and may not open another world; " +
            "audit the closure instead"
        ) -and
        -not $combinedOutput.Contains("C6_MJC_HC_VH1_CLOSED_CANARY_MUST_NOT_BE_READ")
    ) "The real VH1 physical entrypoint did not refuse at the closure boundary"
} finally {
    $process.Dispose()
}
$evidenceRootsAfter = @(
    Get-ChildItem -LiteralPath $evidenceParent -Directory `
        -Filter "c6-mujoco-velocity-only-vh1-*" -ErrorAction SilentlyContinue |
        Sort-Object FullName |
        ForEach-Object { $_.FullName }
)
Assert-Exact (
    ($evidenceRootsAfter -join "`n") -ceq ($evidenceRootsBefore -join "`n") -and
    (Get-Sha256 -Path ([string]$attempt.attempt_path)) -ceq
        [string]$attempt.attempt_sha256 -and
    (Get-Sha256 -Path ([string]$attempt.completion_path)) -ceq
        [string]$attempt.completion_sha256 -and
    (Get-Sha256 -Path ([string]$attempt.report_path)) -ceq
        [string]$attempt.report_sha256
) "The closed-runner canary changed retained VH1 evidence"

Write-Host (
    "C6_MJC_HC_VH1_CLOSURE_PASS worlds=12 passed=8 failed=4 " +
    "loaded=8/8 unloaded=0/4 pair_asymmetry=0 integrity=True " +
    "physical_authority=False"
)
