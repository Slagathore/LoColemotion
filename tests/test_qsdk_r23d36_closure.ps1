#requires -Version 7.0

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$closurePath = Join-Path $repoRoot (
    "sdk\turning\r23d36_mujoco_bw19v_walking_restoration_closure_v1.json"
)
$artifactRoot = Join-Path (
    "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence"
) "artifacts\sha256"
$sourceCommit = "d7036b5ff91d9ad2f4dfaa3ccc71ac161cc67b28"
$cellId = "mujoco__r23d29_with_bw19v_load_transfer_residual__reference_zero"

function Assert-R23D36([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "QSDK-R23D36 CLOSURE: $Message" }
}

function Assert-Close(
    [double]$Actual,
    [double]$Expected,
    [double]$Tolerance,
    [string]$Message
) {
    Assert-R23D36 ([Math]::Abs($Actual - $Expected) -le $Tolerance) $Message
}

function Get-Sha256([string]$Path) {
    return "sha256:" + (
        Get-FileHash -LiteralPath $Path -Algorithm SHA256
    ).Hash.ToLowerInvariant()
}

function Get-CasPayload([string]$Sha256) {
    Assert-R23D36 ($Sha256 -cmatch '^sha256:[0-9a-f]{64}$') (
        "invalid CAS digest: $Sha256"
    )
    return Join-Path (
        Join-Path $artifactRoot $Sha256.Substring(7)
    ) "payload.bin"
}

function Assert-Cas([string]$Sha256, [long]$ByteLength) {
    $payload = Get-CasPayload $Sha256
    $manifest = Join-Path (Split-Path -Parent $payload) "manifest.json"
    Assert-R23D36 (Test-Path -LiteralPath $payload -PathType Leaf) (
        "CAS payload missing: $Sha256"
    )
    Assert-R23D36 (Test-Path -LiteralPath $manifest -PathType Leaf) (
        "CAS manifest missing: $Sha256"
    )
    Assert-R23D36 ((Get-Item -LiteralPath $payload).Length -eq $ByteLength) (
        "CAS payload length changed: $Sha256"
    )
    Assert-R23D36 ((Get-Sha256 $payload) -ceq $Sha256) (
        "CAS payload digest changed: $Sha256"
    )
    $record = Get-Content -Raw -LiteralPath $manifest | ConvertFrom-Json -Depth 20
    Assert-R23D36 (
        [string]$record.schema_version -ceq
            "sporespore_content_addressed_artifact_manifest_v1" -and
        [string]$record.sha256 -ceq $Sha256 -and
        [long]$record.byte_length -eq $ByteLength -and
        [string]$record.payload_name -ceq "payload.bin"
    ) "CAS manifest changed: $Sha256"
    return $payload
}

function Assert-Artifact($Record, [bool]$RequireCas = $true) {
    $path = [string]$Record.path
    Assert-R23D36 (Test-Path -LiteralPath $path -PathType Leaf) (
        "retained artifact missing: $path"
    )
    Assert-R23D36 ((Get-Item -LiteralPath $path).Length -eq [long]$Record.byte_length) (
        "retained artifact length changed: $path"
    )
    Assert-R23D36 ((Get-Sha256 $path) -ceq [string]$Record.sha256) (
        "retained artifact digest changed: $path"
    )
    if ($RequireCas) {
        $cas = Assert-Cas ([string]$Record.sha256) ([long]$Record.byte_length)
        Assert-R23D36 (
            (Get-Sha256 $cas) -ceq (Get-Sha256 $path)
        ) "live evidence and CAS payload diverged: $path"
    }
}

$closure = Get-Content -Raw -LiteralPath $closurePath | ConvertFrom-Json -Depth 100

Assert-R23D36 (
    (git -C $repoRoot rev-parse --show-toplevel).Trim().Replace('/', '\') -ceq
        $repoRoot -and
    (git -C $repoRoot remote get-url origin).Trim() -ceq
        "https://github.com/Slagathore/sporespore.git" -and
    [string]$closure.schema_version -ceq
        "sporespore_qsdk_r23d36_mujoco_bw19v_walking_restoration_closure_v1" -and
    [string]$closure.status -ceq
        "closed_consumed_invalid_supervisor_manifest_shape_with_retained_non_authoritative_physical_negative" -and
    [string]$closure.campaign_id -ceq
        "QSDK-R23D36-MUJOCO-R23D29-BW19V-WALKING-RESTORATION" -and
    [string]$closure.gate_id -ceq "QSDK-R23D36" -and
    [string]$closure.source_commit -ceq $sourceCommit -and
    (git -C $repoRoot rev-parse "${sourceCommit}^{tree}").Trim() -ceq
        [string]$closure.source_tree_git_oid -and
    [string]$closure.attempt_id -ceq "332a9294ea6f42a396fcd9f5f376b4cc" -and
    [int]$closure.campaign_seed -eq 21507 -and
    [bool]$closure.identity_consumed -and
    -not [bool]$closure.same_identity_rerun_allowed -and
    -not [bool]$closure.selective_rerun_allowed -and
    -not [bool]$closure.successor_campaign_opened
) "closure identity changed"

$freezeRecord = $closure.physical_evidence.physical_freeze
$attemptRecord = $closure.physical_evidence.attempt_authorization
$manifestRecord = $closure.physical_evidence.terminal_manifest
$completionRecord = $closure.physical_evidence.completion
$stdoutRecord = $closure.physical_evidence.stdout
$stderrRecord = $closure.physical_evidence.stderr
$terminalRecord = $closure.physical_evidence.terminal
$traceRecord = $closure.physical_evidence.trace
foreach ($record in @(
    $freezeRecord, $attemptRecord, $manifestRecord, $completionRecord,
    $stdoutRecord, $stderrRecord, $terminalRecord, $traceRecord
)) {
    Assert-Artifact $record
}
Assert-Artifact ([pscustomobject]@{
    path = $closure.qualification.accepted_attestation_path
    sha256 = $closure.qualification.accepted_attestation_sha256
    byte_length = $closure.qualification.accepted_attestation_byte_length
})
Assert-Artifact ([pscustomobject]@{
    path = $closure.qualification.adoption_path
    sha256 = $closure.qualification.adoption_sha256
    byte_length = $closure.qualification.adoption_byte_length
})

$attestation = Get-Content -Raw -LiteralPath (
    [string]$closure.qualification.accepted_attestation_path
) | ConvertFrom-Json -Depth 100
$adoption = Get-Content -Raw -LiteralPath (
    [string]$closure.qualification.adoption_path
) | ConvertFrom-Json -Depth 100
Assert-R23D36 (
    [string]$attestation.source.commit -ceq $sourceCommit -and
    [string]$attestation.source.tree_git_oid -ceq
        [string]$closure.source_tree_git_oid -and
    [bool]$attestation.source.clean_pushed_live -and
    [int]$attestation.global_gate_count -eq 12 -and
    [int]$attestation.lineage_gate_count -eq 3 -and
    [int]$attestation.campaign_gate_count -eq 3 -and
    [int]$attestation.executed_gate_count -eq 18 -and
    [bool]$attestation.all_gates_executed -and
    [string]$adoption.source_commit -ceq $sourceCommit -and
    [int]$adoption.executed_gate_count -eq 18 -and
    [bool]$adoption.physical_launch_prerequisite_satisfied -and
    -not [bool]$adoption.physical_acceptance_authority
) "qualification receipt changed"

$freeze = Get-Content -Raw -LiteralPath ([string]$freezeRecord.path) |
    ConvertFrom-Json -Depth 100
$attempt = Get-Content -Raw -LiteralPath ([string]$attemptRecord.path) |
    ConvertFrom-Json -Depth 100
$completion = Get-Content -Raw -LiteralPath ([string]$completionRecord.path) |
    ConvertFrom-Json -Depth 100
Assert-R23D36 (
    [string]$freeze.schema_version -ceq
        "sporespore_qsdk_r23d36_physical_freeze_v1" -and
    [string]$freeze.source_commit -ceq $sourceCommit -and
    [string]$freeze.source_tree_git_oid -ceq
        [string]$closure.source_tree_git_oid -and
    [string]$freeze.origin_main_commit -ceq $sourceCommit -and
    [string]$freeze.live_github_main_commit -ceq $sourceCommit -and
    [bool]$freeze.physical_execution_authorized -and
    -not [bool]$freeze.physical_acceptance_authority -and
    [string]$attempt.attempt_id -ceq [string]$closure.attempt_id -and
    [string]$attempt.source_commit -ceq $sourceCommit -and
    [bool]$attempt.physical_execution_authorized -and
    [bool]$attempt.single_use_supervisor_authorization -and
    [bool]$attempt.source_worktree_clean -and
    [bool]$attempt.source_matches_live_github_main -and
    [bool]$attempt.operation_lock_held -and
    [bool]$attempt.campaign_attestation_adoption_valid -and
    [bool]$attempt.content_addressed_inputs_retained -and
    [bool]$attempt.one_shot_attempt_unconsumed -and
    [string]$completion.status -ceq "invalid_or_incomplete_first_attempt" -and
    [bool]$completion.one_shot_attempt_consumed -and
    -not [bool]$completion.replacement_or_selective_rerun_permitted -and
    -not [bool]$completion.physical_acceptance_authority -and
    [string]$completion.failure_message -cmatch
        "QSDK_R23D36_EVALUATOR_FAILURE FileNotFoundError:.*'C'"
) "freeze, authorization, or one-shot invalid completion changed"

Assert-R23D36 ([int]$freeze.source_bindings.Count -eq 52) (
    "physical source binding count changed"
)
Assert-R23D36 (
    [int]$freeze.content_addressed_inputs.source_bindings.Count -eq 52
) "source CAS receipt count changed"
$receiptByDigest = @{}
foreach ($receipt in @($freeze.content_addressed_inputs.source_bindings)) {
    $receiptByDigest[[string]$receipt.sha256] = $receipt
}
foreach ($binding in @($freeze.source_bindings)) {
    $relative = [string]$binding.path
    $digest = [string]$binding.raw_sha256
    Assert-R23D36 ([bool]$binding.raw_checkout_equals_git_blob) (
        "frozen checkout/blob equality was false: $relative"
    )
    Assert-R23D36 ($receiptByDigest.ContainsKey($digest)) (
        "source CAS receipt missing: $relative"
    )
    $receipt = $receiptByDigest[$digest]
    $payload = Assert-Cas $digest ([long]$receipt.byte_length)
    $commitBlob = (git -C $repoRoot rev-parse "${sourceCommit}:$relative").Trim()
    $payloadBlob = (git -C $repoRoot hash-object --no-filters -- $payload).Trim()
    Assert-R23D36 (
        $commitBlob -ceq [string]$binding.git_blob_oid -and
        $payloadBlob -ceq [string]$binding.git_blob_oid
    ) "source commit, frozen blob OID, and CAS bytes diverged: $relative"
}

Assert-R23D36 (
    [int]$freeze.runtime_artifacts.Count -eq 1 -and
    [int]$freeze.external_runtime_bindings.Count -eq 3 -and
    [int]$freeze.content_addressed_inputs.runtime_bindings.Count -eq 4 -and
    [string]$freeze.runtime_artifacts[0].raw_sha256 -ceq
        "sha256:304da183803c061964412540d02e2df15defbb7dda525d5724a42017690422cd" -and
    [bool]$freeze.runtime_artifacts[0].build_receipt.msvc_brepro -and
    [bool]$freeze.runtime_artifacts[0].build_receipt.pdb_alt_path_bare_name
) "runtime freeze changed"
foreach ($receipt in @($freeze.content_addressed_inputs.runtime_bindings)) {
    [void](Assert-Cas ([string]$receipt.sha256) ([long]$receipt.byte_length))
}

$terminalManifest = Get-Content -Raw -LiteralPath ([string]$manifestRecord.path) |
    ConvertFrom-Json -Depth 20
Assert-R23D36 ($terminalManifest -is [string]) (
    "the retained one-item manifest is no longer a JSON scalar string"
)
Assert-R23D36 (
    [string]$terminalManifest -ceq [string]$terminalRecord.cas_payload_path -and
    [string]$closure.official_classification.mechanism.retained_terminal_manifest_json_type -ceq
        "string" -and
    -not [bool]$closure.official_classification.complete_evaluator_received_valid_terminal_array -and
    -not [bool]$closure.official_classification.physical_acceptance_authority -and
    -not [bool]$closure.official_classification.mechanism.scientific_selector_legally_completed -and
    -not [bool]$closure.official_classification.mechanism.same_identity_can_be_repaired_or_rerun
) "manifest serializer defect classification changed"

$terminal = Get-Content -Raw -LiteralPath ([string]$terminalRecord.cas_payload_path) |
    ConvertFrom-Json -Depth 100
Assert-R23D36 (
    [string]$terminal.schema_version -ceq
        "sporespore_qsdk_r23d36_engine_cell_report_v1" -and
    [string]$terminal.campaign_id -ceq [string]$closure.campaign_id -and
    [string]$terminal.gate_id -ceq "QSDK-R23D36" -and
    [string]$terminal.source_commit -ceq $sourceCommit -and
    [string]$terminal.cell_id -ceq $cellId -and
    [string]$terminal.engine_id -ceq "mujoco" -and
    [string]$terminal.arm_id -ceq "reference_zero" -and
    [int]$terminal.execution.world_attempt_count -eq 1 -and
    [int]$terminal.execution.world_build_count -eq 1 -and
    [bool]$terminal.execution.integrity_passed -and
    [bool]$terminal.execution.trace_retained_before_terminal_entry -and
    -not [bool]$terminal.claims.mujoco_r23d29_bw19v_walking_restoration -and
    -not [bool]$terminal.claims.mujoco_r23d29_turning -and
    -not [bool]$terminal.claims.cross_engine_equivalence -and
    -not [bool]$terminal.claims.release_authorized -and
    -not [bool]$terminal.claims.physical_acceptance_authority
) "retained terminal identity, execution integrity, or claims changed"

$tracePath = Assert-Cas ([string]$traceRecord.sha256) ([long]$traceRecord.byte_length)
$lines = @(Get-Content -LiteralPath $tracePath)
Assert-R23D36 ($lines.Count -eq 2992) "trace row count changed"
$expectedActuatorOrder = @(
    "front_left_hip_motor", "front_left_knee_motor",
    "front_right_hip_motor", "front_right_knee_motor",
    "rear_left_hip_motor", "rear_left_knee_motor",
    "rear_right_hip_motor", "rear_right_knee_motor"
)
$availableSteps = [Collections.Generic.List[int]]::new()
$activeSteps = [Collections.Generic.List[int]]::new()
$nonzeroSteps = [Collections.Generic.List[int]]::new()
$maximumTilt = 0.0
$minimumHeight = [double]::PositiveInfinity
$maximumResidual = 0.0
$traceTorsoContactCount = 0
$firstTorsoContactStep = -1
$contactCycles = @{
    front_left = 0
    front_right = 0
    rear_left = 0
    rear_right = 0
}
$previousContacts = @{
    front_left = $true
    front_right = $true
    rear_left = $true
    rear_right = $true
}
foreach ($lineIndex in 0..($lines.Count - 1)) {
    $row = $lines[$lineIndex] | ConvertFrom-Json -Depth 100
    Assert-R23D36 (
        [string]$row.schema_version -ceq
            "sporespore_qsdk_r23d36_walking_restoration_trace_row_v1" -and
        [string]$row.cell_id -ceq $cellId -and
        [int]$row.semantic_step -eq $lineIndex -and
        [string]$row.segment_id -ceq "reference_walk" -and
        [int]$row.validated_portable_command_count -eq 8 -and
        [int]$row.native_actuation_application_count -eq 8 -and
        [bool]$row.oracle_passed -and
        [bool]$row.stability_composition_integrity_passed -and
        @($row.ordered_stability_velocity_residuals).Count -eq 8
    ) "trace row integrity changed at step $lineIndex"
    $actuatorIds = @(
        $row.ordered_stability_velocity_residuals |
            ForEach-Object { [string]$_.actuator_id }
    )
    Assert-R23D36 (
        ($actuatorIds -join ',') -ceq ($expectedActuatorOrder -join ',')
    ) "residual actuator order changed at step $lineIndex"
    foreach ($residual in @($row.ordered_stability_velocity_residuals)) {
        $value = [Math]::Abs([double]$residual.canonical_velocity_delta_rad_s)
        Assert-R23D36 ([double]::IsFinite($value)) (
            "nonfinite residual at step $lineIndex"
        )
        $maximumResidual = [Math]::Max($maximumResidual, $value)
    }
    if ([string]$row.stability_planning_availability -ceq "available") {
        $availableSteps.Add($lineIndex)
    }
    if ([bool]$row.stability_plan_active) { $activeSteps.Add($lineIndex) }
    if ([int]$row.stability_nonzero_residual_count -gt 0) {
        $nonzeroSteps.Add($lineIndex)
    }
    $maximumTilt = [Math]::Max($maximumTilt, [double]$row.torso_tilt_rad)
    $minimumHeight = [Math]::Min($minimumHeight, [double]$row.torso_height_m)
    if ([bool]$row.torso_ground_contact) {
        $traceTorsoContactCount += 1
        if ($firstTorsoContactStep -lt 0) { $firstTorsoContactStep = $lineIndex }
    }
    if ($lineIndex -ge 472) {
        foreach ($limb in @("front_left", "front_right", "rear_left", "rear_right")) {
            $present = [bool]$row.ordered_foot_contacts_after.$limb
            if (-not $previousContacts[$limb] -and $present) {
                $contactCycles[$limb] += 1
            }
            $previousContacts[$limb] = $present
        }
    }
}

$diagnostic = $closure.retained_physical_diagnostic
$measurements = $terminal.measurements
Assert-R23D36 (
    ($availableSteps -join ',') -ceq "0,1,4,5,6,10,11,85,86" -and
    $activeSteps.Count -eq 0 -and
    ($nonzeroSteps -join ',') -ceq "0,1,4,5,6,10,11,85,86" -and
    $firstTorsoContactStep -eq 192 -and
    $traceTorsoContactCount -eq 2781 -and
    $contactCycles.front_left -eq 0 -and
    $contactCycles.front_right -eq 0 -and
    $contactCycles.rear_left -eq 27 -and
    $contactCycles.rear_right -eq 23 -and
    [int]$measurements.controller_semantic_step_count -eq 2992 -and
    [int]$measurements.validated_portable_command_count -eq 23936 -and
    [int]$measurements.native_actuation_application_count -eq 23936 -and
    [int]$measurements.actuator_application_mismatch_count -eq 0 -and
    [int]$measurements.controller_error_count -eq 0 -and
    [int]$measurements.safe_no_actuation_count -eq 0 -and
    [int]$measurements.nonfinite_observation_count -eq 0 -and
    [bool]$measurements.stability_composition_integrity_passed -and
    [int]$measurements.stability_composition_step_count -eq 2992 -and
    [int]$measurements.stability_planning_available_step_count -eq 9 -and
    [int]$measurements.stability_plan_active_step_count -eq 0 -and
    [int]$measurements.stability_nonzero_residual_step_count -eq 9 -and
    [int]$measurements.torso_ground_contact_step_count -eq 2782
) "retained trace mechanism or terminal counters changed"
Assert-Close $maximumResidual 0.02 1.0e-12 "trace residual maximum changed"
Assert-Close $maximumTilt 1.865506956107064 1.0e-12 "trace maximum tilt changed"
Assert-Close $minimumHeight 0.2508240260659109 1.0e-12 "trace minimum height changed"
Assert-Close ([double]$measurements.final_forward_displacement_m) (
    -0.6249710048622591
) 1.0e-12 "final displacement changed"

$failedGates = [Collections.Generic.List[string]]::new()
if ([double]$measurements.final_forward_displacement_m -lt 0.030123046875) {
    $failedGates.Add("R23D36_FORWARD_DISPLACEMENT")
}
if ([double]$measurements.maximum_tilt_rad -gt 0.6) {
    $failedGates.Add("R23D36_MAXIMUM_TILT")
}
if ([double]$measurements.minimum_torso_height_m -lt 0.2499708652072946) {
    $failedGates.Add("R23D36_MINIMUM_TORSO_HEIGHT")
}
if (@($contactCycles.Values | Where-Object { $_ -lt 2 }).Count -gt 0) {
    $failedGates.Add("R23D36_CONTACT_CYCLES")
}
if ([int]$measurements.torso_ground_contact_step_count -ne 0) {
    $failedGates.Add("R23D36_TORSO_GROUND_CONTACT")
}
Assert-R23D36 (
    ($failedGates -join ',') -ceq
        "R23D36_FORWARD_DISPLACEMENT,R23D36_MAXIMUM_TILT,R23D36_CONTACT_CYCLES,R23D36_TORSO_GROUND_CONTACT" -and
    ($failedGates -join ',') -ceq
        (@($diagnostic.independently_failed_frozen_gate_ids) -join ',') -and
    [string]$diagnostic.classification -ceq
        "valid_complete_negative_mujoco_walking_restoration" -and
    -not [bool]$diagnostic.authoritative_campaign_result -and
    -not [bool]$diagnostic.posthoc_or_release_acceptance_permitted
) "independent retained-trace diagnostic changed"

Assert-R23D36 (
    -not [bool]$closure.bounded_interpretation.r23d36_valid_physical_acceptance_result_exists -and
    [bool]$closure.bounded_interpretation.retained_complete_physical_trace_exists -and
    [bool]$closure.bounded_interpretation.retained_trace_is_a_negative_mechanism_diagnostic -and
    -not [bool]$closure.bounded_interpretation.bw19v_overlay_restored_mujoco_walking -and
    -not [bool]$closure.bounded_interpretation.mujoco_r23d29_turning_exposed -and
    -not [bool]$closure.bounded_interpretation.portable_or_three_engine_turning_validated -and
    -not [bool]$closure.claims.mujoco_r23d29_bw19v_walking_restoration -and
    -not [bool]$closure.claims.mujoco_r23d29_unassisted_walking -and
    -not [bool]$closure.claims.mujoco_r23d29_turning -and
    -not [bool]$closure.claims.portable_basic_turning -and
    -not [bool]$closure.claims.finite_three_engine_turning -and
    -not [bool]$closure.claims.cross_engine_equivalence -and
    -not [bool]$closure.claims.prone_to_standing -and
    -not [bool]$closure.claims.q_sdk_r23_satisfied -and
    -not [bool]$closure.claims.release_authorized -and
    -not [bool]$closure.claims.physical_acceptance_authority
) "bounded interpretation or claims changed"

Write-Output (
    "QSDK_R23D36_CLOSURE_PASS official=invalid worlds=1 " +
    "diagnostic=negative steps=2992 overlay_available=9 overlay_active=0 " +
    "first_torso_contact=192 same_identity_rerun=false successor_open=false"
)
