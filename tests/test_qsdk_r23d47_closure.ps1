#requires -Version 7.0

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$closurePath = Join-Path $repoRoot (
    "sdk\turning\r23d47_support_loss_conditioned_startup_closure_v1.json"
)
$sourceCommit = "4059eb703428b60a88837e426d38411bdf69058d"
$artifactRoot = Join-Path (
    (Split-Path -Parent $repoRoot)
) "SporeSpore_Evidence\artifacts\sha256"

function Assert-R47Closure([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "QSDK-R23D47 CLOSURE: $Message" }
}

function Assert-Near([double]$Actual, [double]$Expected, [string]$Message) {
    Assert-R47Closure (
        [double]::IsFinite($Actual) -and
        [Math]::Abs($Actual - $Expected) -le 1.0e-12
    ) $Message
}

function Get-BytesSha256([byte[]]$Bytes) {
    return "sha256:" + [Convert]::ToHexString(
        [Security.Cryptography.SHA256]::HashData($Bytes)
    ).ToLowerInvariant()
}

function Get-GitBlobBytes([string]$Commit, [string]$RelativePath) {
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
    Assert-R47Closure ($process.Start()) "could not start git cat-file"
    $memory = [IO.MemoryStream]::new()
    try {
        $process.StandardOutput.BaseStream.CopyTo($memory)
        $stderr = $process.StandardError.ReadToEnd()
        $process.WaitForExit()
        Assert-R47Closure ($process.ExitCode -eq 0) (
            "historical blob unavailable: $RelativePath; $stderr"
        )
        return ,([byte[]]$memory.ToArray())
    } finally {
        $memory.Dispose()
        $process.Dispose()
    }
}

function Get-CasPayload([string]$Sha256, [long]$ByteLength) {
    Assert-R47Closure ($Sha256 -cmatch '^sha256:[0-9a-f]{64}$') (
        "invalid artifact digest: $Sha256"
    )
    $directory = Join-Path $artifactRoot $Sha256.Substring(7)
    $payload = Join-Path $directory "payload.bin"
    $manifestPath = Join-Path $directory "manifest.json"
    Assert-R47Closure (
        (Test-Path -LiteralPath $payload -PathType Leaf) -and
        (Test-Path -LiteralPath $manifestPath -PathType Leaf) -and
        (Get-Item -LiteralPath $payload).Length -eq $ByteLength -and
        ("sha256:" + (Get-FileHash -LiteralPath $payload -Algorithm SHA256).
            Hash.ToLowerInvariant()) -ceq $Sha256
    ) "CAS payload changed: $Sha256"
    $manifest = Get-Content -Raw -LiteralPath $manifestPath |
        ConvertFrom-Json -Depth 20
    Assert-R47Closure (
        [string]$manifest.schema_version -ceq
            "sporespore_content_addressed_artifact_manifest_v1" -and
        [string]$manifest.algorithm -ceq "sha256" -and
        [string]$manifest.sha256 -ceq $Sha256 -and
        [long]$manifest.byte_length -eq $ByteLength -and
        [string]$manifest.payload_name -ceq "payload.bin"
    ) "CAS manifest changed: $Sha256"
    return $payload
}

Assert-R47Closure (
    (git -C $repoRoot rev-parse --show-toplevel).Trim().Replace('/', '\') -ceq
        $repoRoot -and
    (git -C $repoRoot remote get-url origin).Trim() -ceq
        "https://github.com/Slagathore/sporespore.git"
) "repository identity changed"

$closure = Get-Content -Raw -LiteralPath $closurePath |
    ConvertFrom-Json -Depth 100
Assert-R47Closure (
    [string]$closure.schema_version -ceq
        "sporespore_qsdk_r23d47_support_loss_conditioned_startup_closure_v1" -and
    [string]$closure.status -ceq
        "closed_consumed_valid_complete_positive_support_loss_conditioned_startup" -and
    [string]$closure.source_commit -ceq $sourceCommit -and
    (git -C $repoRoot rev-parse "$sourceCommit`^{tree}").Trim() -ceq
        [string]$closure.source_tree_git_oid -and
    [bool]$closure.identity_consumed -and
    -not [bool]$closure.same_identity_rerun_allowed -and
    -not [bool]$closure.selective_rerun_allowed -and
    [bool]$closure.outcome_exposed_condition -and
    -not [bool]$closure.fresh_or_held_out_condition_consumed -and
    -not [bool]$closure.successor_campaign_opened -and
    [bool]$closure.physical_series_paused_before_successor
) "immutable disposition changed"

foreach ($input in @($closure.prospective_inputs)) {
    $relative = [string]$input.path
    $bytes = Get-GitBlobBytes $sourceCommit $relative
    Assert-R47Closure (
        $bytes.Length -eq [long]$input.byte_length -and
        (Get-BytesSha256 $bytes) -ceq [string]$input.raw_sha256 -and
        (git -C $repoRoot rev-parse "$sourceCommit`:$relative").Trim() -ceq
            [string]$input.git_blob_oid
    ) "prospective source identity changed: $relative"
}

Assert-R47Closure (
    ("sha256:" + (Get-FileHash -LiteralPath (
        Join-Path $repoRoot ([string]$closure.immutable_parent_closure.path)
    ) -Algorithm SHA256).Hash.ToLowerInvariant()) -ceq
        [string]$closure.immutable_parent_closure.raw_sha256 -and
    -not [bool]$closure.immutable_parent_closure.historical_result_reinterpreted
) "immutable parent closure changed"

$payloads = @{}
foreach ($property in $closure.physical_evidence.artifacts.PSObject.Properties) {
    $payloads[$property.Name] = Get-CasPayload (
        [string]$property.Value.sha256
    ) ([long]$property.Value.byte_length)
}
$attempt = Get-Content -Raw -LiteralPath $payloads.attempt |
    ConvertFrom-Json -Depth 100
$authorization = Get-Content -Raw -LiteralPath $payloads.authorization_preflights |
    ConvertFrom-Json -Depth 40
$completion = Get-Content -Raw -LiteralPath $payloads.completion |
    ConvertFrom-Json -Depth 40
$terminal = Get-Content -Raw -LiteralPath $payloads.terminal |
    ConvertFrom-Json -Depth 100
$process = Get-Content -Raw -LiteralPath $payloads.process |
    ConvertFrom-Json -Depth 40
$traceManifest = Get-Content -Raw -LiteralPath (
    Join-Path (Split-Path -Parent $payloads.trace) "manifest.json"
) | ConvertFrom-Json -Depth 20
$canary = $attempt.zero_world_receipt.production_retention_canary

Assert-R47Closure (
    [string]$attempt.source_commit -ceq $sourceCommit -and
    [string]$attempt.authorization_token -ceq [string]$closure.attempt_id -and
    @($attempt.source_bindings).Count -eq 35 -and
    [bool]$attempt.source_worktree_clean -and
    [bool]$attempt.source_matches_live_github_main -and
    [bool]$attempt.zero_world_preflight_passed -and
    [int]$attempt.zero_world_receipt.model_construction_count -eq 0 -and
    [int]$attempt.zero_world_receipt.world_attempt_count -eq 0 -and
    [int]$attempt.zero_world_receipt.world_build_count -eq 0 -and
    [int]$canary.synthetic_trace_row_count -eq 2992 -and
    [string]$canary.synthetic_trace_sha256 -ceq
        "sha256:443a05bdcb32187c6090729647d94b692d2dc76eb5ea7cc7e85528028971b758" -and
    [bool]$canary.synthetic_trace_summary_ok -and
    [bool]$canary.exact_production_publisher_invoked -and
    -not [bool]$canary.publisher_test_only -and
    [string]$canary.cas_manifest_media_type -ceq "application/x-ndjson" -and
    [bool]$canary.cas_manifest_identity_verified -and
    [int]$canary.receipt_mutation_rejection_count -eq 2 -and
    [bool]$canary.synthetic_source_cleaned_after_cas_publication -and
    [bool]$authorization.positive.authorization_passed -and
    -not [bool]$authorization.wrong_token.authorization_passed -and
    [string]$authorization.wrong_token.failure_code -ceq
        "QSDK_R23D47_MJC_AUTHORIZATION_INVALID"
) "zero-world, source, or authorization evidence changed"

$evaluation = $terminal.development_evaluation
$measurements = $terminal.measurements
$execution = $terminal.execution
Assert-R47Closure (
    [string]$completion.classification -ceq
        "valid_complete_positive_support_loss_conditioned_startup" -and
    [int]$completion.process_exit_code -eq 0 -and
    -not [bool]$completion.process_timed_out -and
    [int]$completion.world_attempt_count -eq 1 -and
    [int]$completion.world_build_count -eq 1 -and
    [int]$process.exit_code -eq 0 -and
    -not [bool]$process.timed_out -and
    [string]$terminal.schema_version -ceq
        "sporespore_qsdk_r23d47_mujoco_development_report_v1" -and
    [string]$terminal.source_commit -ceq $sourceCommit -and
    [string]$evaluation.classification -ceq
        "valid_complete_positive_support_loss_conditioned_startup" -and
    [bool]$evaluation.execution_valid -and
    [bool]$evaluation.mechanism_engaged_at_predeclared_step -and
    [bool]$evaluation.common_physical_walking_gate_passed -and
    @($evaluation.physical_gate_failures).Count -eq 0 -and
    @($evaluation.physical_gate_checks.PSObject.Properties |
        Where-Object { -not [bool]$_.Value }).Count -eq 0 -and
    [bool]$execution.integrity_passed -and
    [int]$execution.world_attempt_count -eq 1 -and
    [int]$execution.world_build_count -eq 1 -and
    [bool]$execution.trace_retained_before_terminal_entry -and
    [bool]$measurements.startup_transform_composition_integrity_passed -and
    [int]$measurements.startup_transform_composition_step_count -eq 2992 -and
    [bool]$measurements.startup_ramp_triggered -and
    [int]$measurements.startup_ramp_trigger_step -eq 3 -and
    [int]$measurements.startup_probe_minimum_support_count -eq 0 -and
    [int]$measurements.startup_ramp_active_step_count -eq 359 -and
    [int]$measurements.startup_ramp_exact_zero_scale_step_count -eq 1 -and
    [int]$measurements.startup_ramp_exact_unity_scale_step_count -eq 2633 -and
    [int]$measurements.controller_semantic_step_count -eq 2992 -and
    [int]$measurements.validated_portable_command_count -eq 23936 -and
    [int]$measurements.native_actuation_application_count -eq 23936 -and
    [int]$measurements.controller_error_count -eq 0 -and
    [int]$measurements.safe_no_actuation_count -eq 0 -and
    [int]$measurements.nonfinite_observation_count -eq 0 -and
    [int]$measurements.actuator_application_mismatch_count -eq 0 -and
    [int]$measurements.torso_ground_contact_step_count -eq 0 -and
    [int]$measurements.contact_cycle_count_by_limb.rear_left -eq 19 -and
    [int]$measurements.contact_cycle_count_by_limb.front_left -eq 29 -and
    [int]$measurements.contact_cycle_count_by_limb.rear_right -eq 21 -and
    [int]$measurements.contact_cycle_count_by_limb.front_right -eq 29
) "terminal execution, mechanism, or walking gate changed"
Assert-Near ([double]$measurements.final_forward_displacement_m) `
    1.638926076250989 "forward displacement changed"
Assert-Near ([double]$measurements.maximum_tilt_rad) `
    0.08961690764757078 "maximum tilt changed"
Assert-Near ([double]$measurements.minimum_torso_height_m) `
    0.42436045664314553 "minimum torso height changed"

Assert-R47Closure (
    [string]$terminal.trace_artifact.sha256 -ceq
        [string]$closure.physical_evidence.artifacts.trace.sha256 -and
    [long]$terminal.trace_artifact.byte_length -eq
        [long]$closure.physical_evidence.artifacts.trace.byte_length -and
    [string]$terminal.trace_artifact.media_type -ceq
        "application/x-ndjson" -and
    [bool]$terminal.trace_artifact.manifest_identity_verified -and
    -not [bool]$terminal.trace_artifact.test_only -and
    -not [bool]$terminal.trace_artifact.physical_acceptance_authority -and
    [string]$traceManifest.media_type -ceq "application/x-ndjson" -and
    [int]$terminal.trace_summary.row_count -eq 2992 -and
    [bool]$terminal.trace_summary.ok -and
    @($terminal.trace_summary.failure_codes).Count -eq 0
) "terminal trace binding changed"

$rows = @(Get-Content -LiteralPath $payloads.trace | ForEach-Object {
    $_ | ConvertFrom-Json -Depth 30
})
Assert-R47Closure ($rows.Count -eq 2992) "production trace row count changed"
$active = 0
$zero = 0
$unity = 0
$torsoContacts = 0
$maximumTilt = 0.0
$minimumHeight = [double]::PositiveInfinity
$limbIds = @("rear_left", "front_left", "rear_right", "front_right")
$cycles = @{ rear_left = 0; front_left = 0; rear_right = 0; front_right = 0 }
$previous = @{}
foreach ($limb in $limbIds) {
    $previous[$limb] = [bool]$rows[0].ordered_foot_contacts_before.$limb
}
for ($index = 0; $index -lt $rows.Count; $index++) {
    $row = $rows[$index]
    $scale = [double]$row.startup_velocity_scale
    $expectedScale = if ($index -lt 3) { 1.0 } elseif ($index -eq 3) {
        0.0
    } elseif ($index -lt 362) {
        $local = [double]($index - 3) / 359.0
        $local * $local * (3.0 - 2.0 * $local)
    } else { 1.0 }
    Assert-R47Closure (
        [string]$row.schema_version -ceq
            "sporespore_qsdk_r23d3_turn_diagnostic_trace_row_v1" -and
        [string]$row.cell_id -ceq
            "mujoco__r23d29_support_loss_conditioned_startup_v1__reference_zero" -and
        [int]$row.semantic_step -eq $index -and
        [string]$row.segment_id -ceq "reference_walk" -and
        [double]$row.desired_heading_offset_rad -eq 0.0 -and
        [bool]$row.oracle_passed -and
        [int]$row.validated_portable_command_count -eq 8 -and
        [int]$row.native_actuation_application_count -eq 8 -and
        [string]$row.startup_transform_id -ceq
            "support_loss_latched_smoothstep_one_cycle_v1" -and
        [Math]::Abs($scale - $expectedScale) -le 1.0e-15
    ) "production trace row changed: $index"
    $active += [int][bool]$row.startup_ramp_active
    $zero += [int]($scale -eq 0.0)
    $unity += [int]($scale -eq 1.0)
    $torsoContacts += [int][bool]$row.torso_ground_contact
    $maximumTilt = [Math]::Max($maximumTilt, [double]$row.torso_tilt_rad)
    $minimumHeight = [Math]::Min($minimumHeight, [double]$row.torso_height_m)
    if ($index -ge 472) {
        foreach ($limb in $limbIds) {
            $present = [bool]$row.ordered_foot_contacts_after.$limb
            if (-not [bool]$previous[$limb] -and $present) { $cycles[$limb]++ }
            $previous[$limb] = $present
        }
    }
}
Assert-Near $maximumTilt 0.08961690764757078 "trace maximum tilt changed"
Assert-Near $minimumHeight 0.42436045664314553 "trace minimum height changed"
Assert-R47Closure (
    $active -eq 359 -and $zero -eq 1 -and $unity -eq 2633 -and
    $torsoContacts -eq 0 -and
    [int]$cycles.rear_left -eq 19 -and
    [int]$cycles.front_left -eq 29 -and
    [int]$cycles.rear_right -eq 21 -and
    [int]$cycles.front_right -eq 29 -and
    [bool]$closure.claims.startup_mechanism_positive_on_exact_mujoco_condition -and
    [bool]$closure.claims.mujoco_seed_21507_reference_walking -and
    -not [bool]$closure.claims.turning_tested -and
    -not [bool]$closure.claims.portable_basic_turning -and
    -not [bool]$closure.claims.finite_three_engine_turning -and
    -not [bool]$closure.claims.cross_engine_equivalence -and
    -not [bool]$closure.claims.q_sdk_r23_satisfied -and
    -not [bool]$closure.claims.release_authorized -and
    -not [bool]$closure.claims.physical_acceptance_authority
) "trace reconstruction or claim boundary changed"

$before = @(
    Get-ChildItem -LiteralPath (Split-Path -Parent $artifactRoot) `
        -Directory -Filter "qsdk-r23d47-physical-*"
).Count
$start = [Diagnostics.ProcessStartInfo]::new()
$start.FileName = Join-Path $PSHOME "pwsh.exe"
$start.WorkingDirectory = $repoRoot
$start.UseShellExecute = $false
$start.CreateNoWindow = $true
$start.RedirectStandardOutput = $true
$start.RedirectStandardError = $true
foreach ($argument in @(
    "-NoProfile", "-File", (Join-Path $repoRoot "sdk\run_qsdk_r23d47_development.ps1"),
    "-RunPhysical"
)) { [void]$start.ArgumentList.Add($argument) }
$refusal = [Diagnostics.Process]::new()
$refusal.StartInfo = $start
Assert-R47Closure ($refusal.Start()) "closed runner refusal did not start"
$refusalStdout = $refusal.StandardOutput.ReadToEnd()
$refusalStderr = $refusal.StandardError.ReadToEnd()
$refusal.WaitForExit()
$refusalExit = $refusal.ExitCode
$refusal.Dispose()
$after = @(
    Get-ChildItem -LiteralPath (Split-Path -Parent $artifactRoot) `
        -Directory -Filter "qsdk-r23d47-physical-*"
).Count
Assert-R47Closure (
    $refusalExit -ne 0 -and
    ($refusalStdout + $refusalStderr) -like "*closed R23D47 identity cannot run*" -and
    $after -eq $before
) "closed identity did not refuse before a new attempt root"

Write-Host (
    "QSDK_R23D47_CLOSURE_PASS classification=valid_positive worlds=1 " +
    "steps=2992 displacement_m=1.638926076250989 trigger_step=3 " +
    "turning=False rerun=False"
)
