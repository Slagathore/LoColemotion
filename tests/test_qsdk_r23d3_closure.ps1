#requires -Version 7.0

[CmdletBinding()]
param(
    [string]$EvidenceRoot = (
        "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence\" +
        "qsdk-r23d3-20260807T044542Z"
    )
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$sdkRoot = Join-Path $repoRoot "sdk"
$closurePath = Join-Path $sdkRoot "turning\r23d3_physical_closure_v1.json"
$supervisorPath = Join-Path $sdkRoot "run_qsdk_r23d3_supervisor.ps1"
$conformancePath = Join-Path $sdkRoot "run_conformance.ps1"
$campaignId = "QSDK-R23D3-PHASE-BALANCED-BILATERAL-TURN-DEVELOPMENT"
$gateId = "QSDK-R23D3"
$sourceCommit = "e497785e5bcd676f5710ed376418c0a216920a05"
$orderedCellIds = @(
    "mujoco__onset_600__positive_heading",
    "mujoco__onset_600__negative_heading",
    "mujoco__onset_690__positive_heading",
    "mujoco__onset_690__negative_heading",
    "mujoco__onset_780__positive_heading",
    "mujoco__onset_780__negative_heading",
    "mujoco__onset_870__positive_heading",
    "mujoco__onset_870__negative_heading"
)

function Assert-R23D3Closure {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function Get-R23D3RawSha256 {
    param([Parameter(Mandatory)][string]$Path)
    return "sha256:" + (
        Get-FileHash -LiteralPath $Path -Algorithm SHA256
    ).Hash.ToLowerInvariant()
}

function Get-R23D3BytesSha256 {
    param([Parameter(Mandatory)][byte[]]$Bytes)
    $algorithm = [Security.Cryptography.SHA256]::Create()
    try {
        return "sha256:" + [Convert]::ToHexString(
            $algorithm.ComputeHash($Bytes)
        ).ToLowerInvariant()
    } finally {
        $algorithm.Dispose()
    }
}

function Get-R23D3EvidenceTree {
    param([Parameter(Mandatory)][string]$Root)
    $files = @(Get-ChildItem -LiteralPath $Root -File -Recurse | Sort-Object {
        $_.FullName.Substring($Root.Length + 1).Replace("\", "/")
    })
    $lines = @($files | ForEach-Object {
        $relative = $_.FullName.Substring($Root.Length + 1).Replace("\", "/")
        "{0}`t{1}`t{2}" -f `
            $relative, $_.Length, (Get-R23D3RawSha256 $_.FullName).Substring(7)
    })
    $projection = [Text.Encoding]::UTF8.GetBytes(($lines -join "`n") + "`n")
    return [ordered]@{
        file_count = $files.Count
        total_byte_length = [int64](($files | Measure-Object Length -Sum).Sum)
        raw_sha256 = Get-R23D3BytesSha256 $projection
    }
}

function Get-R23D3GitBlobIdentity {
    param(
        [Parameter(Mandatory)][string]$Commit,
        [Parameter(Mandatory)][string]$Path
    )
    $spec = "$Commit`:$Path"
    $oid = (& git -C $repoRoot rev-parse $spec 2>$null).Trim()
    Assert-R23D3Closure ($LASTEXITCODE -eq 0 -and $oid -match '^[0-9a-f]{40}$') (
        "QSDK-R23D3 historical Git blob is unavailable: $spec"
    )

    $start = [Diagnostics.ProcessStartInfo]::new()
    $start.FileName = "git"
    $start.WorkingDirectory = $repoRoot
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    [void]$start.ArgumentList.Add("cat-file")
    [void]$start.ArgumentList.Add("blob")
    [void]$start.ArgumentList.Add($spec)
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $start
    Assert-R23D3Closure $process.Start() "QSDK-R23D3 could not start git cat-file"
    $memory = [IO.MemoryStream]::new()
    try {
        $process.StandardOutput.BaseStream.CopyTo($memory)
        $stderr = $process.StandardError.ReadToEnd()
        $process.WaitForExit()
        Assert-R23D3Closure ($process.ExitCode -eq 0) (
            "QSDK-R23D3 git cat-file failed for $spec`: $stderr"
        )
        return [ordered]@{
            oid = $oid
            byte_length = $memory.Length
            raw_sha256 = Get-R23D3BytesSha256 $memory.ToArray()
        }
    } finally {
        $memory.Dispose()
        $process.Dispose()
    }
}

function Assert-R23D3CasReceipt {
    param([Parameter(Mandatory)]$Receipt, [Parameter(Mandatory)][string]$Label)
    $digest = [string]$Receipt.sha256
    $payload = [string]$Receipt.payload_path
    $manifest = [string]$Receipt.manifest_path
    Assert-R23D3Closure ($digest -match '^sha256:[0-9a-f]{64}$') (
        "QSDK-R23D3 $Label CAS digest is invalid"
    )
    Assert-R23D3Closure (Test-Path -LiteralPath $payload -PathType Leaf) (
        "QSDK-R23D3 $Label CAS payload is missing"
    )
    Assert-R23D3Closure (Test-Path -LiteralPath $manifest -PathType Leaf) (
        "QSDK-R23D3 $Label CAS manifest is missing"
    )
    Assert-R23D3Closure ((Get-R23D3RawSha256 $payload) -ceq $digest) (
        "QSDK-R23D3 $Label CAS payload digest changed"
    )
    Assert-R23D3Closure (
        [int64](Get-Item -LiteralPath $payload).Length -eq [int64]$Receipt.byte_length
    ) "QSDK-R23D3 $Label CAS payload length changed"
    $casManifest = Get-Content -LiteralPath $manifest -Raw | ConvertFrom-Json -Depth 30
    Assert-R23D3Closure (
        [string]$casManifest.sha256 -ceq $digest -and
        [int64]$casManifest.byte_length -eq [int64]$Receipt.byte_length
    ) "QSDK-R23D3 $Label CAS manifest identity changed"
}

function Test-R23D3Outcome {
    param([Parameter(Mandatory)]$Entry, [Parameter(Mandatory)]$Gates)
    $measurements = $Entry.measurements
    $failures = [Collections.Generic.List[string]]::new()
    if ([Math]::Max(
        [Math]::Abs([double]$measurements.maximum_absolute_requested_steering_fraction),
        [Math]::Abs([double]$measurements.maximum_absolute_held_steering_fraction)
    ) -gt [double]$Gates.maximum_absolute_requested_or_held_steering_fraction + 1e-12) {
        $failures.Add("R23D3_STEERING_LIMIT")
    }
    if ([double]$measurements.final_forward_displacement_m -lt
        [double]$Gates.minimum_final_forward_displacement_m) {
        $failures.Add("R23D3_FORWARD_DISPLACEMENT")
    }
    if ([double]$measurements.maximum_tilt_rad -gt [double]$Gates.maximum_tilt_rad) {
        $failures.Add("R23D3_MAXIMUM_TILT")
    }
    if ([double]$measurements.minimum_torso_height_m -lt
        [double]$Gates.minimum_torso_height_m) {
        $failures.Add("R23D3_MINIMUM_TORSO_HEIGHT")
    }
    foreach ($limb in @("front_left", "front_right", "rear_left", "rear_right")) {
        if ([int]$measurements.contact_cycle_count_by_limb.$limb -lt
            [int]$Gates.minimum_contact_cycles_per_limb) {
            $failures.Add("R23D3_CONTACT_CYCLES:$limb")
        }
    }
    foreach ($item in @(
        @("torso_ground_contact_step_count", "R23D3_TORSO_GROUND_CONTACT"),
        @("controller_error_count", "R23D3_CONTROLLER_ERROR"),
        @("safe_no_actuation_count", "R23D3_SAFE_NO_ACTUATION"),
        @("nonfinite_observation_count", "R23D3_NONFINITE_OBSERVATION"),
        @("actuator_application_mismatch_count", "R23D3_ACTUATOR_APPLICATION_MISMATCH")
    )) {
        if ([int]$measurements.($item[0]) -ne 0) { $failures.Add($item[1]) }
    }
    foreach ($item in @(
        @("controller_semantic_step_count", 2992, "R23D3_CONTROLLER_STEP_COUNT"),
        @("validated_portable_command_count", 23936, "R23D3_VALIDATED_COMMAND_COUNT"),
        @("native_actuation_application_count", 23936, "R23D3_NATIVE_APPLICATION_COUNT")
    )) {
        if ([int]$measurements.($item[0]) -ne [int]$item[1]) { $failures.Add($item[2]) }
    }
    $offset = [double]$Entry.turn_heading_offset_rad
    $yaw = [double]$measurements.turn_phase_yaw_delta_rad
    $signedYaw = if ($offset -gt 0.0) {
        $yaw -ge [double]$Gates.minimum_absolute_signed_turn_phase_yaw_delta_rad
    } elseif ($offset -lt 0.0) {
        $yaw -le -[double]$Gates.minimum_absolute_signed_turn_phase_yaw_delta_rad
    } else { $true }
    return [ordered]@{
        failed_gate_ids = @($failures)
        outcome_gate_passed = $failures.Count -eq 0
        signed_yaw_response_passed = $signedYaw
    }
}

Assert-R23D3Closure (
    (git -C $repoRoot rev-parse --show-toplevel).Replace("/", "\") -ceq $repoRoot -and
    (git -C $repoRoot remote get-url origin) -ceq "https://github.com/Slagathore/sporespore.git"
) "QSDK-R23D3 closure repository identity mismatch"
Assert-R23D3Closure (Test-Path -LiteralPath $closurePath -PathType Leaf) (
    "QSDK-R23D3 closure is missing"
)
Assert-R23D3Closure (Test-Path -LiteralPath $EvidenceRoot -PathType Container) (
    "QSDK-R23D3 retained attempt root is missing"
)

$closure = Get-Content -LiteralPath $closurePath -Raw | ConvertFrom-Json -Depth 100
$freezePath = Join-Path $EvidenceRoot "physical-freeze.json"
$authorizationPath = Join-Path $EvidenceRoot "stage-a-authorization.json"
$stageAManifestPath = Join-Path $EvidenceRoot "stage-a-terminal-paths.json"
$stageAEvaluationPath = Join-Path $EvidenceRoot "stage-a-evaluation.json"
$stageBManifestPath = Join-Path $EvidenceRoot "stage-b-terminal-paths.json"
$completionPath = Join-Path $EvidenceRoot "completion.json"

$keyDigests = [ordered]@{
    "physical-freeze.json" = $closure.attempt.physical_freeze_raw_sha256
    "stage-a-authorization.json" = $closure.attempt.stage_a_authorization_raw_sha256
    "stage-a-terminal-paths.json" = $closure.attempt.stage_a_terminal_manifest_raw_sha256
    "stage-a-evaluation.json" = $closure.attempt.stage_a_evaluation_raw_sha256
    "stage-b-terminal-paths.json" = $closure.attempt.stage_b_terminal_manifest_raw_sha256
    "completion.json" = $closure.attempt.completion_raw_sha256
}
foreach ($item in $keyDigests.GetEnumerator()) {
    $path = Join-Path $EvidenceRoot $item.Key
    Assert-R23D3Closure (Test-Path -LiteralPath $path -PathType Leaf) (
        "QSDK-R23D3 retained key file is missing: $($item.Key)"
    )
    Assert-R23D3Closure ((Get-R23D3RawSha256 $path) -ceq [string]$item.Value) (
        "QSDK-R23D3 retained key file changed: $($item.Key)"
    )
}

$tree = Get-R23D3EvidenceTree $EvidenceRoot
Assert-R23D3Closure (
    [int]$tree.file_count -eq [int]$closure.attempt.evidence_file_count -and
    [int64]$tree.total_byte_length -eq [int64]$closure.attempt.evidence_total_byte_length -and
    [string]$tree.raw_sha256 -ceq [string]$closure.attempt.evidence_tree_raw_sha256
) "QSDK-R23D3 retained evidence tree changed"

$freeze = Get-Content -LiteralPath $freezePath -Raw | ConvertFrom-Json -Depth 100
$authorization = Get-Content -LiteralPath $authorizationPath -Raw | ConvertFrom-Json -Depth 100
$completion = Get-Content -LiteralPath $completionPath -Raw | ConvertFrom-Json -Depth 30
$stageAEvaluation = Get-Content -LiteralPath $stageAEvaluationPath -Raw |
    ConvertFrom-Json -Depth 100

$treeOid = (& git -C $repoRoot rev-parse "$sourceCommit^{tree}").Trim()
Assert-R23D3Closure (
    [string]$freeze.campaign_id -ceq $campaignId -and
    [string]$freeze.gate_id -ceq $gateId -and
    [string]$freeze.source_commit -ceq $sourceCommit -and
    [string]$freeze.source_tree_git_oid -ceq $treeOid -and
    [string]$freeze.origin_main_commit -ceq $sourceCommit -and
    [string]$freeze.live_github_main_commit -ceq $sourceCommit -and
    [bool]$freeze.source_checkout_bytes_equal_git_blobs -and
    [bool]$freeze.reproducible_runtime_materialization_passed -and
    [bool]$freeze.complete_zero_world_gate_passed -and
    [int]$freeze.zero_world_receipt.actual_world_attempt_count -eq 0 -and
    [int]$freeze.zero_world_receipt.actual_world_build_count -eq 0 -and
    -not [bool]$freeze.physical_acceptance_authority
) "QSDK-R23D3 physical freeze identity or zero-world boundary changed"

$sourceBindings = @($freeze.source_bindings)
$sourceReceipts = @($freeze.content_addressed_inputs.source_bindings)
$runtimeReceipts = @($freeze.content_addressed_inputs.runtime_artifacts)
$externalReceipts = @($freeze.content_addressed_inputs.external_runtime_bindings)
$allInputReceipts = @($sourceReceipts) + @($runtimeReceipts) + @($externalReceipts) +
    @($freeze.content_addressed_inputs.full_godot_attestation)
Assert-R23D3Closure (
    $sourceBindings.Count -eq 63 -and
    $sourceReceipts.Count -eq 63 -and
    $runtimeReceipts.Count -eq 3 -and
    $externalReceipts.Count -eq 3 -and
    $allInputReceipts.Count -eq 70
) "QSDK-R23D3 frozen input inventory changed"
for ($index = 0; $index -lt $sourceBindings.Count; $index++) {
    $binding = $sourceBindings[$index]
    $receipt = $sourceReceipts[$index]
    $gitBlob = Get-R23D3GitBlobIdentity `
        -Commit $sourceCommit -Path ([string]$binding.path)
    Assert-R23D3Closure (
        [string]$binding.git_blob_oid -ceq [string]$gitBlob.oid -and
        [string]$binding.raw_sha256 -ceq [string]$gitBlob.raw_sha256 -and
        [string]$binding.raw_sha256 -ceq [string]$receipt.sha256 -and
        [bool]$binding.raw_checkout_equals_git_blob
    ) "QSDK-R23D3 frozen source binding changed: $($binding.path)"
}
for ($index = 0; $index -lt $allInputReceipts.Count; $index++) {
    Assert-R23D3CasReceipt $allInputReceipts[$index] "input[$index]"
}

Assert-R23D3Closure (
    [string]$authorization.schema_version -ceq "sporespore_qsdk_r23d3_attempt_v1" -and
    [string]$authorization.attempt_id -ceq [string]$closure.attempt.attempt_id -and
    [string]$authorization.stage_authorization_id -ceq "stage_a" -and
    [string]$authorization.source_commit -ceq $sourceCommit -and
    [bool]$authorization.physical_execution_authorized -and
    [bool]$authorization.single_use_supervisor_authorization -and
    [bool]$authorization.source_worktree_clean -and
    [bool]$authorization.source_matches_live_github_main -and
    [bool]$authorization.operation_lock_held -and
    [bool]$authorization.full_godot_attestation_valid -and
    [bool]$authorization.content_addressed_inputs_retained -and
    [bool]$authorization.complete_zero_world_gate_passed -and
    [bool]$authorization.one_shot_attempt_unconsumed -and
    -not [bool]$authorization.replacement_or_selective_rerun_permitted -and
    -not [bool]$authorization.stage_a_reports_may_substitute_for_stage_b -and
    -not [bool]$authorization.physical_acceptance_authority
) "QSDK-R23D3 Stage A authorization changed"
Assert-R23D3Closure (
    @($authorization.ordered_stage_a_cell_ids).Count -eq 8 -and
    ((@($authorization.ordered_stage_a_cell_ids) -join "|") -ceq
        ($orderedCellIds -join "|")) -and
    @($authorization.ordered_stage_b_cell_ids).Count -eq 0 -and
    [string]$authorization.selected_onset_id -ceq "NONE"
) "QSDK-R23D3 Stage A authorization order changed"

$stageAPaths = @(Get-Content -LiteralPath $stageAManifestPath -Raw |
    ConvertFrom-Json -Depth 20)
Assert-R23D3Closure ($stageAPaths.Count -eq 8) (
    "QSDK-R23D3 Stage A terminal manifest cardinality changed"
)
$preregistrationIndex = [Array]::FindIndex(
    [object[]]$sourceBindings,
    [Predicate[object]]{ param($item)
        [string]$item.path -ceq "sdk/turning/r23d3_phase_balanced_preregistration_v1.json"
    }
)
Assert-R23D3Closure ($preregistrationIndex -ge 0) (
    "QSDK-R23D3 preregistration source receipt is missing"
)
$preregistration = Get-Content `
    -LiteralPath ([string]$sourceReceipts[$preregistrationIndex].payload_path) `
    -Raw | ConvertFrom-Json -Depth 100
$gates = $preregistration.unchanged_outcome_gates

$positivePasses = 0
$negativeYawPasses = 0
$negativePasses = 0
$negativeTiltFailures = 0
$negativeTraceMaximum = 0.0
$worldAttempts = 0
$worldBuilds = 0
for ($index = 0; $index -lt $orderedCellIds.Count; $index++) {
    $expectedCellId = $orderedCellIds[$index]
    $casPath = [string]$stageAPaths[$index]
    Assert-R23D3Closure (Test-Path -LiteralPath $casPath -PathType Leaf) (
        "QSDK-R23D3 Stage A terminal CAS payload is missing: $expectedCellId"
    )
    $entry = Get-Content -LiteralPath $casPath -Raw | ConvertFrom-Json -Depth 100
    $closureCell = @($closure.cell_results | Where-Object cell_id -CEQ $expectedCellId)
    $evaluationCell = @($stageAEvaluation.cell_evaluations |
        Where-Object cell_id -CEQ $expectedCellId)
    Assert-R23D3Closure ($closureCell.Count -eq 1 -and $evaluationCell.Count -eq 1) (
        "QSDK-R23D3 cell closure/evaluation cardinality changed: $expectedCellId"
    )
    $closureCell = $closureCell[0]
    $evaluationCell = $evaluationCell[0]
    Assert-R23D3Closure (
        [string]$entry.cell_id -ceq $expectedCellId -and
        [string]$entry.campaign_id -ceq $campaignId -and
        [string]$entry.gate_id -ceq $gateId -and
        [string]$entry.engine_id -ceq "mujoco" -and
        [string]$entry.source_commit -ceq $sourceCommit -and
        [bool]$entry.execution.integrity_passed -and
        [int]$entry.execution.controller_semantic_step_count -eq 2992 -and
        [int]$entry.execution.validated_portable_command_count -eq 23936 -and
        [int]$entry.execution.native_actuation_application_count -eq 23936 -and
        [int]$entry.execution.world_attempt_count -eq 1 -and
        [int]$entry.execution.world_build_count -eq 1 -and
        [bool]$entry.execution.trace_retained_before_terminal_entry -and
        -not [bool]$entry.claims.command_conditioned_turning -and
        -not [bool]$entry.claims.cross_engine_equivalence -and
        -not [bool]$entry.claims.release_authorized -and
        -not [bool]$entry.claims.physical_acceptance_authority
    ) "QSDK-R23D3 retained terminal entry changed: $expectedCellId"
    Assert-R23D3Closure (
        (Get-R23D3RawSha256 $casPath) -ceq
            [string]$closureCell.terminal_entry_raw_sha256 -and
        [string]$entry.trace_artifact.sha256 -ceq [string]$closureCell.trace_raw_sha256
    ) "QSDK-R23D3 retained terminal/trace digest changed: $expectedCellId"
    Assert-R23D3CasReceipt $entry.trace_artifact "trace:$expectedCellId"

    $traceMaximum = 0.0
    $traceRows = 0
    foreach ($line in [IO.File]::ReadLines([string]$entry.trace_artifact.payload_path)) {
        $row = $line | ConvertFrom-Json -Depth 30
        Assert-R23D3Closure (
            [string]$row.cell_id -ceq $expectedCellId -and
            [int]$row.semantic_step -eq $traceRows
        ) "QSDK-R23D3 retained trace order changed: $expectedCellId row $traceRows"
        $traceMaximum = [Math]::Max($traceMaximum, [double]$row.torso_tilt_rad)
        $traceRows++
    }
    Assert-R23D3Closure ($traceRows -eq 2992) (
        "QSDK-R23D3 retained trace row count changed: $expectedCellId"
    )

    $outcome = Test-R23D3Outcome -Entry $entry -Gates $gates
    Assert-R23D3Closure (
        [bool]$outcome.outcome_gate_passed -eq [bool]$evaluationCell.outcome.outcome_gate_passed -and
        [bool]$outcome.signed_yaw_response_passed -eq
            [bool]$evaluationCell.outcome.signed_yaw_response_passed -and
        ((@($outcome.failed_gate_ids) -join "|") -ceq
            (@($evaluationCell.outcome.failed_gate_ids) -join "|")) -and
        [bool]$outcome.outcome_gate_passed -eq [bool]$closureCell.outcome_gate_passed -and
        ((@($outcome.failed_gate_ids) -join "|") -ceq
            (@($closureCell.failed_gate_ids) -join "|"))
    ) "QSDK-R23D3 independently recomputed outcome changed: $expectedCellId"
    $worldAttempts += [int]$entry.execution.world_attempt_count
    $worldBuilds += [int]$entry.execution.world_build_count
    if ([string]$entry.arm_id -ceq "positive_heading") {
        $positivePasses += [int][bool]$outcome.outcome_gate_passed
    } else {
        $negativeYawPasses += [int][bool]$outcome.signed_yaw_response_passed
        $negativePasses += [int][bool]$outcome.outcome_gate_passed
        $negativeTiltFailures += [int](@($outcome.failed_gate_ids) -contains
            "R23D3_MAXIMUM_TILT")
        $negativeTraceMaximum = [Math]::Max($negativeTraceMaximum, $traceMaximum)
        Assert-R23D3Closure (
            $traceMaximum -le [double]$gates.maximum_tilt_rad -and
            [double]$entry.measurements.maximum_tilt_rad -gt
                [double]$gates.maximum_tilt_rad
        ) "QSDK-R23D3 terminal-settle localization changed: $expectedCellId"
    }
}

Assert-R23D3Closure (
    [bool]$stageAEvaluation.valid -and
    [string]$stageAEvaluation.classification -ceq "valid_none_stage_a" -and
    [string]$stageAEvaluation.selected_onset_id -ceq "NONE" -and
    @($stageAEvaluation.eligible_onset_ids).Count -eq 0 -and
    -not [bool]$stageAEvaluation.stage_b_launch_authorized -and
    @($stageAEvaluation.failure_codes).Count -eq 0 -and
    @($stageAEvaluation.cell_evaluations).Count -eq 8 -and
    [int]$stageAEvaluation.world_attempt_count -eq 8 -and
    [int]$stageAEvaluation.world_build_count -eq 8 -and
    $worldAttempts -eq 8 -and $worldBuilds -eq 8 -and
    $positivePasses -eq 4 -and $negativeYawPasses -eq 4 -and
    $negativePasses -eq 0 -and $negativeTiltFailures -eq 4 -and
    [Math]::Abs($negativeTraceMaximum -
        [double]$closure.posthoc_mechanism_diagnostic.
            maximum_negative_heading_tilt_within_retained_controller_traces_rad) -le 1e-12
) "QSDK-R23D3 retained valid-NONE Stage A result changed"

$stageBBytes = [IO.File]::ReadAllBytes($stageBManifestPath)
Assert-R23D3Closure (
    $stageBBytes.Length -eq 1 -and $stageBBytes[0] -eq 0x0a -and
    -not (Test-Path -LiteralPath (Join-Path $EvidenceRoot "stage-b") -PathType Container) -and
    -not (Test-Path -LiteralPath (Join-Path $EvidenceRoot "stage-b-authorization.json")) -and
    -not (Test-Path -LiteralPath (Join-Path $EvidenceRoot "complete-evaluation.json")) -and
    -not (Test-Path -LiteralPath (Join-Path $EvidenceRoot "report.json"))
) "QSDK-R23D3 blank Stage B manifest or unopened Stage B boundary changed"
Assert-R23D3Closure (
    [string]$completion.status -ceq "invalid_or_incomplete_first_attempt" -and
    [string]$completion.failure_code -ceq "SUPERVISOR_INFRASTRUCTURE_EXCEPTION" -and
    [string]$completion.failure_detail -ceq
        "Cannot bind argument to parameter 'Text' because it is an empty string." -and
    [bool]$completion.one_shot_identity_consumed -and
    -not [bool]$completion.same_identity_rerun_allowed -and
    -not [bool]$completion.q_sdk_r23_satisfied -and
    -not [bool]$completion.cross_engine_equivalence -and
    -not [bool]$completion.release_authorized -and
    -not [bool]$completion.physical_acceptance_authority -and
    [bool]$closure.immutable_completion_record.must_not_be_rewritten_as_valid -and
    [bool]$closure.retained_stage_a_evaluation.not_a_complete_campaign_reclassification
) "QSDK-R23D3 immutable completion boundary changed"

$supervisor = [IO.File]::ReadAllText($supervisorPath)
$mujocoWorker = [IO.File]::ReadAllText((Join-Path $sdkRoot (
    "adapters\mujoco\sporespore_mujoco_adapter\qsdk_r23d3_phase_balanced.py"
)))
$rapierWorker = [IO.File]::ReadAllText((Join-Path $sdkRoot (
    "adapters\rapier\src\qsdk_r23d3_phase_balanced.rs"
)))
$godotWorker = [IO.File]::ReadAllText((Join-Path $repoRoot (
    "tests\test_sdk_qsdk_r23d3_godot_jolt_worker.gd"
)))
foreach ($item in @(
    @("supervisor", $supervisor),
    @("mujoco", $mujocoWorker),
    @("rapier", $rapierWorker),
    @("godot_jolt", $godotWorker)
)) {
    Assert-R23D3Closure (
        $item[1].Contains("r23d3_physical_closure_v1.json") -and
        $item[1].Contains("R23D3") -and
        $item[1].Contains("CLOSED")
    ) "QSDK-R23D3 $($item[0]) closure interlock is missing"
}

$refusal = @(& pwsh -NoProfile -File $supervisorPath -RunPhysical 2>&1)
$refusalExit = $LASTEXITCODE
Assert-R23D3Closure (
    $refusalExit -ne 0 -and
    ($refusal -join "`n").Contains("QSDK_R23D3_PHYSICAL_REFUSAL") -and
    ($refusal -join "`n").Contains("r23d3_identity_closed")
) "QSDK-R23D3 supervisor did not refuse the closed identity before preflight"
# The nonzero child exit above is the required negative-control result. Clear
# only its process-transport residue after the refusal has been asserted so a
# caller in this PowerShell session does not misclassify this passing closure.
$global:LASTEXITCODE = 0

$conformance = [IO.File]::ReadAllText($conformancePath)
Assert-R23D3Closure (
    $conformance.Contains("tests\test_qsdk_r23d3_closure.ps1") -and
    -not $conformance.Contains(
        '& (Join-Path $repoRoot "tests\test_qsdk_r23d3_implementation.ps1")'
    ) -and
    -not $conformance.Contains(
        '& (Join-Path $sdkRoot "run_qsdk_r23d3_phase_balanced_preflight.ps1")'
    )
) "QSDK-R23D3 canonical conformance did not switch to closure-only authority"

# Closure-time negative controls exercise the independent evaluator surface
# without altering any retained bytes.
$canaryEntry = Get-Content -LiteralPath ([string]$stageAPaths[0]) -Raw |
    ConvertFrom-Json -Depth 100
$canaryEntry.measurements.maximum_tilt_rad = 0.7
$tiltCanary = Test-R23D3Outcome -Entry $canaryEntry -Gates $gates
Assert-R23D3Closure (
    -not [bool]$tiltCanary.outcome_gate_passed -and
    @($tiltCanary.failed_gate_ids) -contains "R23D3_MAXIMUM_TILT"
) "QSDK-R23D3 closure tilt canary was not rejected"
$canaryEntry = Get-Content -LiteralPath ([string]$stageAPaths[0]) -Raw |
    ConvertFrom-Json -Depth 100
$canaryEntry.measurements.native_actuation_application_count = 23935
$countCanary = Test-R23D3Outcome -Entry $canaryEntry -Gates $gates
Assert-R23D3Closure (
    -not [bool]$countCanary.outcome_gate_passed -and
    @($countCanary.failed_gate_ids) -contains "R23D3_NATIVE_APPLICATION_COUNT"
) "QSDK-R23D3 closure application-count canary was not rejected"
Assert-R23D3Closure (
    -not [bool]$closure.claims.onset_timing_alone_sufficient -and
    -not [bool]$closure.claims.command_conditioned_turning -and
    -not [bool]$closure.claims.bilateral_signed_turning -and
    -not [bool]$closure.claims.portable_basic_turning -and
    -not [bool]$closure.claims.cross_engine_equivalence -and
    -not [bool]$closure.claims.q_sdk_r23_satisfied -and
    -not [bool]$closure.claims.prone_to_standing -and
    -not [bool]$closure.claims.release_authorized -and
    -not [bool]$closure.claims.physical_acceptance_authority -and
    [string]$closure.successor_boundary.successor_id -ceq "QSDK-R23D4" -and
    [bool]$closure.immutability.same_identity_rerun_forbidden
) "QSDK-R23D3 closure claim or successor boundary changed"

Write-Host (
    "QSDK_R23D3_CLOSURE_PASS files=$($tree.file_count) bytes=$($tree.total_byte_length) " +
    "inputs=$($allInputReceipts.Count) source_blobs=$($sourceBindings.Count) " +
    "stage_a=8/8 valid_none=True positive=4/4 negative_yaw=4/4 " +
    "negative_walk=0/4 stage_b_worlds=0 completion=invalid_infrastructure " +
    "rerun=False canaries=2 claims=False"
)
