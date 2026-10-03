#requires -Version 7.0

[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$sdkRoot = Join-Path $repoRoot "sdk"
$closurePath = Join-Path $sdkRoot "turning\physical_development_closure_v1.json"
$runnerPath = Join-Path $sdkRoot "run_qsdk_r23d1_supervisor.ps1"
$sourceAuditPath = Join-Path $PSScriptRoot "closed_experiment_source_audit.ps1"
$currentRapierWorkerPath = Join-Path $sdkRoot `
    "adapters\rapier\src\qsdk_r23d1_heading_response.rs"
$currentMujocoWorkerPath = Join-Path $sdkRoot `
    "adapters\mujoco\sporespore_mujoco_adapter\qsdk_r23d1_heading_response.py"
$currentGodotWorkerPath = Join-Path $PSScriptRoot `
    "test_sdk_qsdk_r23d1_godot_jolt_worker.gd"
$expectedClosureSha256 = "022b42ae025abc3ee4eb502ee1857d5b43c1f6bc0e67b7e84c07bd6aa7076717"
$campaignId = "QSDK-R23D1-THREE-ENGINE-HEADING-RESPONSE-DEVELOPMENT"
$gateId = "QSDK-R23D1"
$sourceCommit = "dd61a90ee32d756f94f826cd0e5b2df6520cbe33"
$sourceTree = "cb7a2b8de9916d6c45864218dc26fe0697075872"
$attemptId = "4b0be9b0b64c49e5bfbfcf7c093c10c7"
$expectedCells = @(
    "godot_jolt__reference_zero",
    "godot_jolt__positive_heading",
    "godot_jolt__negative_heading",
    "rapier_parry__reference_zero",
    "rapier_parry__positive_heading",
    "rapier_parry__negative_heading",
    "mujoco__reference_zero",
    "mujoco__positive_heading",
    "mujoco__negative_heading"
)

function Assert-R23D1Closure {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function Get-R23D1RawSha256 {
    param([Parameter(Mandatory)][string]$Path)
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Test-R23D1SequenceEqual {
    param(
        [Parameter(Mandatory)][AllowEmptyCollection()][object[]]$Actual,
        [Parameter(Mandatory)][AllowEmptyCollection()][object[]]$Expected
    )
    if ($Actual.Count -ne $Expected.Count) { return $false }
    for ($index = 0; $index -lt $Expected.Count; $index += 1) {
        if ([string]$Actual[$index] -cne [string]$Expected[$index]) { return $false }
    }
    return $true
}

function Get-R23D1EvidenceTreeDigest {
    param([Parameter(Mandatory)][string]$Root)
    $files = @(Get-ChildItem -LiteralPath $Root -File -Recurse)
    $rows = @(
        $files |
            ForEach-Object {
                $relative = [IO.Path]::GetRelativePath($Root, $_.FullName).Replace("\", "/")
                "{0}`t{1}`t{2}" -f $relative, $_.Length, (Get-R23D1RawSha256 $_.FullName)
            } |
            Sort-Object
    )
    $text = ($rows -join "`n") + "`n"
    return [ordered]@{
        file_count = $files.Count
        total_byte_length = [long]($files | Measure-Object Length -Sum).Sum
        tree_sha256 = [Convert]::ToHexString(
            [Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($text))
        ).ToLowerInvariant()
    }
}

function Assert-R23D1CasReceipt {
    param(
        [Parameter(Mandatory)]$Receipt,
        [Parameter(Mandatory)][string]$Label
    )
    $digest = [string]$Receipt.sha256
    Assert-R23D1Closure (
        [string]$Receipt.schema_version -ceq
            "sporespore_content_addressed_artifact_receipt_v1" -and
        $digest -cmatch '^sha256:[0-9a-f]{64}$' -and
        -not [bool]$Receipt.test_only -and
        -not [bool]$Receipt.physical_acceptance_authority
    ) "$gateId $Label CAS receipt contract changed"
    $rawDigest = $digest.Substring("sha256:".Length)
    $payloadPath = [IO.Path]::GetFullPath([string]$Receipt.payload_path)
    $manifestPath = [IO.Path]::GetFullPath([string]$Receipt.manifest_path)
    $expectedDirectory = [IO.Path]::GetFullPath(
        "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence\artifacts\sha256\$rawDigest"
    )
    Assert-R23D1Closure (
        (Split-Path -Parent $payloadPath) -ceq $expectedDirectory -and
        (Split-Path -Parent $manifestPath) -ceq $expectedDirectory -and
        (Test-Path -LiteralPath $payloadPath -PathType Leaf) -and
        (Test-Path -LiteralPath $manifestPath -PathType Leaf) -and
        (Get-Item -LiteralPath $payloadPath).Length -eq [long]$Receipt.byte_length -and
        (Get-R23D1RawSha256 $payloadPath) -ceq $rawDigest
    ) "$gateId $Label CAS payload is missing or changed"
    $manifest = Get-Content -Raw -LiteralPath $manifestPath |
        ConvertFrom-Json -AsHashtable -Depth 32
    Assert-R23D1Closure (
        [string]$manifest.schema_version -ceq
            "sporespore_content_addressed_artifact_manifest_v1" -and
        [string]$manifest.algorithm -ceq "sha256" -and
        [string]$manifest.sha256 -ceq $digest -and
        [long]$manifest.byte_length -eq [long]$Receipt.byte_length -and
        [string]$manifest.payload_name -ceq "payload.bin"
    ) "$gateId $Label CAS manifest changed"
}

function Assert-R23D1CloseNumber {
    param(
        [Parameter(Mandatory)][double]$Actual,
        [Parameter(Mandatory)][double]$Expected,
        [Parameter(Mandatory)][string]$Label,
        [double]$Tolerance = 1.0e-12
    )
    Assert-R23D1Closure ([math]::Abs($Actual - $Expected) -le $Tolerance) (
        "$gateId $Label changed: actual=$Actual expected=$Expected"
    )
}

Assert-R23D1Closure (
    (git -C $repoRoot rev-parse --show-toplevel).Replace("/", "\") -ceq $repoRoot -and
    (git -C $repoRoot remote get-url origin) -ceq
        "https://github.com/Slagathore/sporespore.git"
) "$gateId closure audit repository identity mismatch"
Assert-R23D1Closure (Test-Path -LiteralPath $sourceAuditPath -PathType Leaf) (
    "$gateId historical source audit helper is missing"
)
. $sourceAuditPath

Assert-R23D1Closure (
    (Test-Path -LiteralPath $closurePath -PathType Leaf) -and
    (Get-R23D1RawSha256 $closurePath) -ceq $expectedClosureSha256
) "$gateId closure is missing or changed"
& git -C $repoRoot cat-file -e "$sourceCommit`^{commit}"
Assert-R23D1Closure ($LASTEXITCODE -eq 0) "$gateId source commit is unavailable"
Assert-R23D1Closure (
    (& git -C $repoRoot rev-parse "$sourceCommit`^{tree}").Trim() -ceq $sourceTree
) "$gateId source tree changed"

$closure = Get-Content -Raw -LiteralPath $closurePath |
    ConvertFrom-Json -AsHashtable -Depth 128
$attemptRecord = [Collections.IDictionary]$closure.consumed_attempt
$evidenceRoot = [IO.Path]::GetFullPath([string]$attemptRecord.evidence_root)
Assert-R23D1Closure (
    [string]$closure.schema_version -ceq
        "sporespore_qsdk_r23d1_physical_development_closure_v1" -and
    [string]$closure.status -ceq
        "closed_consumed_implementation_invalid_incomplete_no_three_engine_result" -and
    [string]$closure.campaign_id -ceq $campaignId -and
    [string]$closure.gate_id -ceq $gateId -and
    [string]$closure.release_gate_id -ceq "QSDK-R23" -and
    [string]$closure.experiment_source_commit -ceq $sourceCommit -and
    [string]$closure.experiment_source_tree_git_oid -ceq $sourceTree -and
    [bool]$closure.source_was_clean_and_equal_to_origin_main_and_live_github_main -and
    [int]$closure.declared_study.declared_engine_count -eq 3 -and
    [int]$closure.declared_study.declared_arm_count -eq 3 -and
    [int]$closure.declared_study.declared_cell_count -eq 9 -and
    [bool]$closure.declared_study.complete_nine_report_aggregate_required_for_scientific_interpretation
) "$gateId closure identity or declared study changed"

Assert-R23D1Closure (Test-Path -LiteralPath $evidenceRoot -PathType Container) (
    "$gateId retained attempt root is missing"
)
foreach ($artifact in @($attemptRecord.artifacts)) {
    $artifactPath = Join-Path $evidenceRoot ([string]$artifact.relative_path)
    Assert-R23D1Closure (
        (Test-Path -LiteralPath $artifactPath -PathType Leaf) -and
        (Get-Item -LiteralPath $artifactPath).Length -eq [long]$artifact.size_bytes -and
        "sha256:$(Get-R23D1RawSha256 $artifactPath)" -ceq [string]$artifact.raw_sha256
    ) "$gateId retained artifact is missing or changed: $([string]$artifact.relative_path)"
}
$treeBefore = Get-R23D1EvidenceTreeDigest $evidenceRoot
Assert-R23D1Closure (
    [string]$attemptRecord.evidence_tree.algorithm -ceq
        "sha256_utf8_sorted_relative_path_tab_bytes_tab_raw_sha256_lf_v1" -and
    @($attemptRecord.artifacts).Count -eq 19 -and
    [int]$treeBefore.file_count -eq 19 -and
    [int]$treeBefore.file_count -eq [int]$attemptRecord.evidence_tree.file_count -and
    [long]$treeBefore.total_byte_length -eq 207564 -and
    [long]$treeBefore.total_byte_length -eq [long]$attemptRecord.evidence_tree.total_byte_length -and
    [string]$treeBefore.tree_sha256 -ceq
        "5a00d15a364f4c8eaddb06c94bc2273839a67d4807cc6b1bf5aab4d4aba2c8c1" -and
    [string]$treeBefore.tree_sha256 -ceq [string]$attemptRecord.evidence_tree.tree_sha256
) "$gateId retained evidence tree changed"

$attempt = Get-Content -Raw -LiteralPath (Join-Path $evidenceRoot "attempt.json") |
    ConvertFrom-Json -AsHashtable -Depth 128
$aggregateInput = Get-Content -Raw -LiteralPath (
    Join-Path $evidenceRoot "aggregate-input.json"
) | ConvertFrom-Json -AsHashtable -Depth 128
$report = Get-Content -Raw -LiteralPath (Join-Path $evidenceRoot "report.json") |
    ConvertFrom-Json -AsHashtable -Depth 128
$completion = Get-Content -Raw -LiteralPath (Join-Path $evidenceRoot "completion.json") |
    ConvertFrom-Json -AsHashtable -Depth 128

Assert-R23D1Closure (
    [string]$attempt.schema_version -ceq "sporespore_qsdk_r23d1_attempt_v1" -and
    [string]$attempt.attempt_id -ceq $attemptId -and
    [string]$attempt.campaign_id -ceq $campaignId -and
    [string]$attempt.gate_id -ceq $gateId -and
    [string]$attempt.source_commit -ceq $sourceCommit -and
    [string]$attempt.origin_main_commit -ceq $sourceCommit -and
    [string]$attempt.live_main_commit -ceq $sourceCommit -and
    [bool]$attempt.physical_execution_authorized -and
    [bool]$attempt.single_use_supervisor_authorization -and
    [bool]$attempt.source_worktree_clean -and
    [bool]$attempt.source_matches_live_github_main -and
    [bool]$attempt.operation_lock_held -and
    [bool]$attempt.full_godot_attestation_valid -and
    [bool]$attempt.content_addressed_inputs_retained -and
    [bool]$attempt.complete_zero_world_gate_passed -and
    [bool]$attempt.one_shot_attempt_unconsumed -and
    (Test-R23D1SequenceEqual @($attempt.ordered_cell_ids) $expectedCells) -and
    -not [bool]$attempt.replacement_or_selective_rerun_permitted -and
    -not [bool]$attempt.physical_acceptance_authority
) "$gateId retained attempt authorization changed"
Assert-R23D1Closure (
    [string]$attempt.contract_sha256 -ceq
        [string]$attempt.content_addressed_inputs.physical_development_contract.sha256 -and
    [string]$attempt.freeze_sha256 -ceq
        "sha256:4be3b9c7b6c3bed6feb01c99b8af3b8ae635ee7ddb74ea350df1293e24bf6669" -and
    [string]$attempt.full_godot_attestation_sha256 -ceq
        [string]$closure.launch_attestation.raw_sha256 -and
    [string]$attempt.full_godot_attestation_sha256 -ceq
        [string]$attempt.content_addressed_inputs.full_godot_attestation.sha256
) "$gateId retained attempt source or attestation binding changed"

$casInputs = [Collections.IDictionary]$attempt.content_addressed_inputs
Assert-R23D1Closure (
    $casInputs.Count -eq 42 -and
    [int]$attemptRecord.content_addressed_input_count -eq 42
) "$gateId retained input CAS inventory changed"
foreach ($entry in $casInputs.GetEnumerator()) {
    Assert-R23D1CasReceipt $entry.Value "input $($entry.Key)"
}

$freezeBytes = Get-SporeGitBlobBytes `
    -RepositoryRoot $repoRoot `
    -Commit $sourceCommit `
    -Path "sdk/turning/physical_development_freeze_v1.json"
Assert-R23D1Closure (
    "sha256:$(Get-SporeByteSha256 -Bytes $freezeBytes)" -ceq [string]$attempt.freeze_sha256
) "$gateId historical freeze digest changed"
$freeze = [Text.Encoding]::UTF8.GetString($freezeBytes) |
    ConvertFrom-Json -AsHashtable -Depth 128
Assert-R23D1Closure (
    [string]$freeze.schema_version -ceq "sporespore_qsdk_r23d1_supervisor_freeze_v1" -and
    [string]$freeze.status -ceq "frozen_physical_authorized" -and
    [int]$freeze.declared_source_binding_count -eq 24 -and
    @($freeze.source_bindings).Count -eq 24 -and
    @($freeze.external_runtime_bindings).Count -eq 14 -and
    @($freeze.attempt_runtime_artifacts).Count -eq 17 -and
    (Test-R23D1SequenceEqual @($freeze.ordered_cell_ids) $expectedCells)
) "$gateId historical freeze content changed"
foreach ($binding in @($freeze.source_bindings)) {
    $name = [string]$binding.name
    Assert-R23D1Closure ($casInputs.Contains($name)) (
        "$gateId source CAS receipt is missing: $name"
    )
    Assert-R23D1Closure (
        [string]$casInputs[$name].sha256 -ceq [string]$binding.raw_sha256 -and
        (Test-SporeHistoricalSourceSha256 `
            -RepositoryRoot $repoRoot `
            -Commit $sourceCommit `
            -Path ([string]$binding.path) `
            -ExpectedSha256 ([string]$binding.raw_sha256))
    ) "$gateId historical source binding changed: $([string]$binding.path)"
}
foreach ($binding in @($freeze.external_runtime_bindings)) {
    $name = [string]$binding.name
    Assert-R23D1Closure (
        $casInputs.Contains($name) -and
        [string]$casInputs[$name].sha256 -ceq [string]$binding.raw_sha256
    ) "$gateId retained external runtime binding changed: $name"
}
foreach ($artifact in @($freeze.attempt_runtime_artifacts)) {
    Assert-R23D1Closure ($casInputs.Contains([string]$artifact.name)) (
        "$gateId retained runtime artifact receipt is missing: $([string]$artifact.name)"
    )
}

Assert-R23D1Closure (
    [string]$aggregateInput.schema_version -ceq
        "sporespore_qsdk_r23d1_aggregate_input_v1" -and
    (Test-R23D1SequenceEqual @($aggregateInput.ordered_cell_ids) $expectedCells) -and
    [int]$aggregateInput.retained_report_count -eq 3 -and
    @($aggregateInput.ordered_report_cas).Count -eq 3 -and
    (Test-R23D1SequenceEqual @($aggregateInput.missing_cell_ids) $expectedCells[3..8]) -and
    -not [bool]$aggregateInput.physical_acceptance_authority
) "$gateId aggregate input changed"
foreach ($receipt in @($aggregateInput.ordered_report_cas)) {
    Assert-R23D1CasReceipt $receipt "ordered complete report"
}

Assert-R23D1Closure (
    [string]$report.schema_version -ceq "sporespore_qsdk_r23d1_campaign_report_v1" -and
    [string]$report.campaign_id -ceq $campaignId -and
    [string]$report.gate_id -ceq $gateId -and
    [string]$report.source.commit -ceq $sourceCommit -and
    [int]$report.complete_report_count -eq 3 -and
    @($report.ordered_cells).Count -eq 9 -and
    -not [bool]$report.development_screen_passed -and
    [bool]$report.claims.development_screen_only -and
    @($report.claims.GetEnumerator() | Where-Object {
        [string]$_.Key -cne "development_screen_only" -and [bool]$_.Value
    }).Count -eq 0
) "$gateId diagnostic campaign report changed"
Assert-R23D1Closure (
    [string]$report.aggregate_evaluation.schema_version -ceq
        "sporespore_qsdk_r23d1_aggregate_evaluation_v1" -and
    [int]$report.aggregate_evaluation.report_count -eq 3 -and
    -not [bool]$report.aggregate_evaluation.development_screen_passed -and
    (Test-R23D1SequenceEqual @($report.aggregate_evaluation.failure_codes) @(
        "R23D1_AGGREGATE_REPORT_COUNT",
        "R23D1_AGGREGATE_ORDER_OR_COMPLETENESS",
        "R23D1_AGGREGATE_CELL_FAILURE"
    )) -and
    [int]$report.aggregate_evaluation.world_build_count -eq 0 -and
    -not [bool]$report.aggregate_evaluation.command_conditioned_turning -and
    -not [bool]$report.aggregate_evaluation.cross_engine_equivalence -and
    -not [bool]$report.aggregate_evaluation.q_sdk_r23_satisfied -and
    -not [bool]$report.aggregate_evaluation.release_authorized -and
    -not [bool]$report.aggregate_evaluation.physical_acceptance_authority
) "$gateId incomplete aggregate diagnostic changed"

$godotExpectations = [ordered]@{
    godot_jolt__reference_zero = [ordered]@{
        duration = 44.02599
        failures = @("R23D1_ZERO_STRAIGHT_WALK")
        forward = 0.964761793613434
        yaw = -0.118800280009468
        heading = -0.0852757517677416
        tilt = 0.111268201247145
        height = 0.429033517837524
        report_sha = "sha256:c6567d2cf1d5620c2de28f38fac51a8cea8ac8c8ac210739193e25d69543fb05"
    }
    godot_jolt__positive_heading = [ordered]@{
        duration = 45.3467697
        failures = @(
            "R23D1_SIGNED_YAW_RESPONSE",
            "R23D1_SIGNED_CONTROLLER_RESPONSE",
            "R23D1_TURN_WALK"
        )
        forward = 1.00485932826996
        yaw = -0.107375230994726
        heading = 0.0930677618556843
        tilt = 0.162961467985508
        height = 0.427207499742508
        report_sha = "sha256:91040154f31ef7996c91db9a5065fc75effc4bb911f84e8f2bfc58975c8a231f"
    }
    godot_jolt__negative_heading = [ordered]@{
        duration = 46.2613919
        failures = @("R23D1_TURN_WALK")
        forward = 0.73380035161972
        yaw = -0.0517322445148429
        heading = 0.161506142605651
        tilt = 0.101787032317642
        height = 0.425757735967636
        report_sha = "sha256:1c823d3bf5a01201f6943cede9bb04dffa39040ae6b1616a881edcf453fae390"
    }
}

for ($index = 0; $index -lt $expectedCells.Count; $index += 1) {
    $cell = [Collections.IDictionary]$report.ordered_cells[$index]
    Assert-R23D1Closure (
        [string]$cell.cell_id -ceq $expectedCells[$index] -and
        -not [bool]$cell.process_timed_out -and
        -not [bool]$cell.physical_acceptance_authority
    ) "$gateId process order or timeout disposition changed: $($expectedCells[$index])"
    Assert-R23D1CasReceipt $cell.engine_log_cas "engine log $($expectedCells[$index])"
    if ($index -lt 3) {
        $expected = $godotExpectations[$expectedCells[$index]]
        $cellReport = [Collections.IDictionary]$cell.report
        $evaluation = [Collections.IDictionary]$report.aggregate_evaluation.cell_evaluations[$index]
        Assert-R23D1Closure (
            [int]$cell.process_exit_code -eq 0 -and
            [string]$cell.process_failure -ceq "" -and
            $null -ne $cellReport -and
            [string]$cellReport.schema_version -ceq
                "sporespore_qsdk_r23d1_engine_cell_report_v2" -and
            [string]$cellReport.cell_id -ceq $expectedCells[$index] -and
            [string]$cellReport.source_commit -ceq $sourceCommit -and
            [int]$cellReport.execution.world_attempt_count -eq 1 -and
            [int]$cellReport.execution.world_build_count -eq 1 -and
            [int]$cellReport.execution.world_reset_count -eq 0 -and
            [int]$cellReport.execution.controller_error_count -eq 0 -and
            [int]$cellReport.execution.safe_no_actuation_count -eq 0 -and
            [int]$cellReport.physics.torso_ground_contact_step_count -eq 0 -and
            [string]$cell.report_cas.sha256 -ceq [string]$expected.report_sha -and
            (Test-R23D1SequenceEqual @($evaluation.failure_codes) @($expected.failures)) -and
            -not [bool]$evaluation.screen_cell_passed -and
            -not [bool]$evaluation.execution_valid
        ) "$gateId retained Godot/Jolt report changed: $($expectedCells[$index])"
        Assert-R23D1CasReceipt $cell.report_cas "cell report $($expectedCells[$index])"
        Assert-R23D1CloseNumber $cell.process_duration_seconds $expected.duration (
            "$($expectedCells[$index]) duration"
        ) 1.0e-7
        Assert-R23D1CloseNumber $cellReport.physics.final_forward_displacement_m `
            $expected.forward "$($expectedCells[$index]) forward displacement"
        Assert-R23D1CloseNumber $cellReport.physics.turn_phase_yaw_delta_rad `
            $expected.yaw "$($expectedCells[$index]) yaw delta"
        Assert-R23D1CloseNumber $cellReport.physics.final_reference_heading_error_rad `
            $expected.heading "$($expectedCells[$index]) heading error"
        Assert-R23D1CloseNumber $cellReport.physics.maximum_tilt_rad `
            $expected.tilt "$($expectedCells[$index]) maximum tilt"
        Assert-R23D1CloseNumber $cellReport.physics.minimum_torso_height_m `
            $expected.height "$($expectedCells[$index]) minimum torso height"
    } else {
        Assert-R23D1Closure (
            [int]$cell.process_exit_code -eq 1 -and
            [string]$cell.process_failure -ceq "PROCESS_EXIT_1" -and
            $null -eq $cell.report -and
            $null -eq $cell.report_cas
        ) "$gateId non-Godot failure disposition changed: $($expectedCells[$index])"
    }
}

$expectedFailureCodes = [ordered]@{
    rapier_parry = "QSDK_R23D1_RAP_CONTROLLER_RECEIPT_INVALID"
    mujoco = "QSDK_R23D1_MJC_NATIVE_STEP_INVALID"
}
foreach ($engine in $expectedFailureCodes.Keys) {
    foreach ($arm in @("reference_zero", "positive_heading", "negative_heading")) {
        $logPath = Join-Path $evidenceRoot "$engine`__$arm\engine.log"
        $logText = Get-Content -Raw -LiteralPath $logPath
        Assert-R23D1Closure ($logText.Contains([string]$expectedFailureCodes[$engine])) (
            "$gateId retained failure marker changed: $engine/$arm"
        )
        $jsonLine = @($logText -split '\r?\n' | Where-Object { $_.Contains("{") })[0]
        $failure = $jsonLine.Substring($jsonLine.IndexOf("{")) |
            ConvertFrom-Json -AsHashtable -Depth 32
        Assert-R23D1Closure (
            [string]$failure.arm_id -ceq $arm -and
            [string]$failure.engine_id -ceq $engine -and
            [string]$failure.failure_code -ceq [string]$expectedFailureCodes[$engine] -and
            -not [bool]$failure.release_authorized -and
            -not [bool]$failure.physical_acceptance_authority
        ) "$gateId retained failure receipt changed: $engine/$arm"
        if ($engine -ceq "rapier_parry") {
            Assert-R23D1Closure (
                [int]$failure.world_attempt_count -eq 0 -and
                [int]$failure.world_build_count -eq 0
            ) "$gateId Rapier failure-counter defect changed"
        } else {
            Assert-R23D1Closure (
                [int]$failure.world_attempt_count -eq 1 -and
                [int]$failure.world_build_count -eq 1
            ) "$gateId MuJoCo failure-stage count changed"
        }
    }
}

Assert-R23D1Closure (
    [string]$completion.schema_version -ceq "sporespore_qsdk_r23d1_completion_v1" -and
    [string]$completion.campaign_id -ceq $campaignId -and
    [string]$completion.status -ceq "invalid_or_incomplete_first_attempt" -and
    [string]$completion.source_commit -ceq $sourceCommit -and
    [int]$completion.ordered_cell_count -eq 9 -and
    [int]$completion.complete_report_count -eq 3 -and
    [bool]$completion.one_shot_identity_consumed -and
    -not [bool]$completion.same_identity_rerun_allowed -and
    -not [bool]$completion.q_sdk_r23_satisfied -and
    -not [bool]$completion.cross_engine_equivalence -and
    -not [bool]$completion.release_authorized -and
    -not [bool]$completion.physical_acceptance_authority
) "$gateId retained completion changed"
Assert-R23D1CasReceipt $completion.report_cas "diagnostic aggregate report"
Assert-R23D1Closure (
    [string]$attemptRecord.attempt_raw_sha256 -ceq
        "sha256:$(Get-R23D1RawSha256 (Join-Path $evidenceRoot 'attempt.json'))" -and
    [string]$attemptRecord.aggregate_input_raw_sha256 -ceq
        "sha256:$(Get-R23D1RawSha256 (Join-Path $evidenceRoot 'aggregate-input.json'))" -and
    [string]$attemptRecord.diagnostic_report_raw_sha256 -ceq
        "sha256:$(Get-R23D1RawSha256 (Join-Path $evidenceRoot 'report.json'))" -and
    [string]$attemptRecord.completion_raw_sha256 -ceq
        "sha256:$(Get-R23D1RawSha256 (Join-Path $evidenceRoot 'completion.json'))" -and
    [string]$completion.report_cas.sha256 -ceq
        [string]$attemptRecord.diagnostic_report_raw_sha256
) "$gateId aggregate artifact chain changed"

$attestationRecord = [Collections.IDictionary]$closure.launch_attestation
$attestationPath = [IO.Path]::GetFullPath([string]$attestationRecord.path)
Assert-R23D1Closure (
    (Test-Path -LiteralPath $attestationPath -PathType Leaf) -and
    "sha256:$(Get-R23D1RawSha256 $attestationPath)" -ceq
        [string]$attestationRecord.raw_sha256 -and
    [string]$attestationRecord.source_commit -ceq $sourceCommit -and
    [string]$attestationRecord.source_tree_git_oid -ceq $sourceTree -and
    [bool]$attestationRecord.full_suite_passed -and
    [bool]$attestationRecord.godot_included -and
    -not [bool]$attestationRecord.one_shot_physical_campaign_executed -and
    [bool]$attestationRecord.all_attestation_claims_false -and
    [bool]$attestationRecord.production_verifier_passed_before_launch
) "$gateId launch attestation record changed"
$attestation = Get-Content -Raw -LiteralPath $attestationPath |
    ConvertFrom-Json -AsHashtable -Depth 128
Assert-R23D1Closure (
    [string]$attestation.schema_version -ceq
        "sporespore_full_godot_conformance_attestation_v2" -and
    [string]$attestation.status -ceq "full_godot_conformance_passed" -and
    [bool]$attestation.conformance.passed -and
    -not [bool]$attestation.conformance.skip_godot -and
    [bool]$attestation.conformance.godot_including -and
    -not [bool]$attestation.conformance.one_shot_physical_campaign_executed -and
    [string]$attestation.source.commit -ceq $sourceCommit -and
    [string]$attestation.source.tree_git_oid -ceq $sourceTree -and
    [string]$attestation.source.origin_main -ceq $sourceCommit -and
    [string]$attestation.source.live_github_main -ceq $sourceCommit -and
    [bool]$attestation.source.worktree_clean -and
    [bool]$attestation.source.clean_pushed_live -and
    @($attestation.source_bindings).Count -eq 4 -and
    @($attestation.claims.Values | Where-Object { [bool]$_ }).Count -eq 0
) "$gateId retained launch attestation content changed"
foreach ($binding in @($attestation.source_bindings)) {
    $oid = (& git -C $repoRoot rev-parse "$sourceCommit`:$([string]$binding.path)").Trim()
    Assert-R23D1Closure (
        $LASTEXITCODE -eq 0 -and
        $oid -ceq [string]$binding.git_blob_oid -and
        (Test-SporeHistoricalSourceSha256 `
            -RepositoryRoot $repoRoot `
            -Commit $sourceCommit `
            -Path ([string]$binding.path) `
            -ExpectedSha256 ([string]$binding.raw_sha256))
    ) "$gateId attestation source binding changed: $([string]$binding.path)"
}
$lockSource = Get-Content -Raw -LiteralPath (
    [string]$casInputs.locomotion_operation_lock.payload_path
)
$validatorSource = Get-Content -Raw -LiteralPath (
    [string]$casInputs.full_conformance_attestation_verifier.payload_path
)
$lockSource = $lockSource -replace '^#requires[^\r\n]*\r?\n', ''
$validatorSource = $validatorSource -replace '^#requires[^\r\n]*\r?\n', ''
Invoke-Expression $lockSource
Invoke-Expression $validatorSource
$historicalVerification = Test-SporeSporeFullConformanceAttestationDocument `
    -Document $attestation `
    -ExpectedSource $attestation.source `
    -ExpectedGodotIdentity $attestation.godot `
    -ExpectedPowerShellIdentity $attestation.powershell `
    -ExpectedSourceBindings @($attestation.source_bindings)
Assert-R23D1Closure (
    [bool]$historicalVerification.ok -and
    @($historicalVerification.failure_codes).Count -eq 0 -and
    -not [bool]$historicalVerification.physical_acceptance_authority
) "$gateId retained historical attestation no longer verifies"

Assert-R23D1Closure (@($closure.mechanism_source_bindings).Count -eq 5) (
    "$gateId mechanism source inventory changed"
)
$mechanismSources = [ordered]@{}
foreach ($binding in @($closure.mechanism_source_bindings)) {
    $bytes = Get-SporeGitBlobBytes `
        -RepositoryRoot $repoRoot `
        -Commit $sourceCommit `
        -Path ([string]$binding.path)
    $oid = (& git -C $repoRoot rev-parse "$sourceCommit`:$([string]$binding.path)").Trim()
    Assert-R23D1Closure (
        $LASTEXITCODE -eq 0 -and
        $oid -ceq [string]$binding.git_blob_oid -and
        $bytes.Length -eq [long]$binding.byte_length -and
        "sha256:$(Get-SporeByteSha256 -Bytes $bytes)" -ceq [string]$binding.raw_sha256
    ) "$gateId mechanism source binding changed: $([string]$binding.path)"
    $mechanismSources[[string]$binding.path] = [Text.Encoding]::UTF8.GetString($bytes)
}
$runtimeSource = $mechanismSources["sdk/core/src/runtime.rs"]
$controllerSource = $mechanismSources["sdk/core/src/controller.rs"]
$rapierSource = $mechanismSources[
    "sdk/adapters/rapier/src/qsdk_r23d1_heading_response.rs"
]
$rapierCliSource = $mechanismSources[
    "sdk/adapters/rapier/src/bin/qsdk_r23d1_heading_response.rs"
]
$mujocoSource = $mechanismSources[
    "sdk/adapters/mujoco/sporespore_mujoco_adapter/qsdk_r23d1_heading_response.py"
]
Assert-R23D1Closure (
    $runtimeSource.Contains(
        "self.profile.cross_track_heading_gain_rad_per_m * cross_track_error_m"
    ) -and
    $runtimeSource.Contains(
        "cross_track_velocity_heading_gain_rad_per_m_s"
    ) -and
    $runtimeSource.Contains("cross_track_velocity_m_s") -and
    $controllerSource.Contains("_ => 1.0 / torso_length_scale") -and
    $controllerSource.Contains("velocity_gain * torso_length_scale.sqrt()") -and
    $rapierSource.Contains(
        "controller_receipt.desired_heading_error_rad - receipt.heading_offset_rad"
    ) -and
    $rapierSource.IndexOf("build_bw19v_velocity_only_v4_robot_with_friction") -lt
        $rapierSource.IndexOf("for _ in 0..SETTLE_STEPS") -and
    $rapierSource.IndexOf("for _ in 0..SETTLE_STEPS") -lt
        $rapierSource.LastIndexOf("validate_native_step") -and
    $rapierCliSource.Contains('"world_attempt_count": 0') -and
    $rapierCliSource.Contains('"world_build_count": 0') -and
    $mujocoSource.Contains('float(receipt["desired_heading_error_rad"])') -and
    $mujocoSource.Contains('float(heading["heading_offset_rad"])') -and
    $mujocoSource.IndexOf("robot = bridge.MujocoBw19vRobot") -lt
        $mujocoSource.IndexOf("for _ in range(SETTLE_STEPS)") -and
    $mujocoSource.IndexOf("for _ in range(SETTLE_STEPS)") -lt
        $mujocoSource.LastIndexOf("native_valid =")
) "$gateId source-grounded shared mechanism or stage ordering changed"

$implementationFailure = [Collections.IDictionary]$closure.implementation_failure
Assert-R23D1Closure (
    [string]$implementationFailure.classification -ceq
        "physical_state_controller_receipt_oracle_mismatch_with_incomplete_failure_provenance" -and
    [bool]$implementationFailure.shared_mechanism_supported_by_source.
        selected_policy_cross_track_heading_gain_nonzero -and
    [bool]$implementationFailure.shared_mechanism_supported_by_source.
        selected_policy_cross_track_velocity_heading_gain_nonzero -and
    [bool]$implementationFailure.shared_mechanism_supported_by_source.
        rapier_physical_validator_incorrectly_requires_receipt_equal_raw_heading_offset -and
    [bool]$implementationFailure.shared_mechanism_supported_by_source.
        mujoco_physical_validator_incorrectly_requires_receipt_equal_raw_heading_offset -and
    [bool]$implementationFailure.shared_mechanism_supported_by_source.
        worker_preflights_exercised_only_zero_cross_track_synthetic_state -and
    [bool]$implementationFailure.shared_mechanism_supported_by_source.
        all_six_non_godot_cells_failed_on_first_real_controller_step -and
    [bool]$implementationFailure.predictable_before_world
) "$gateId implementation-failure classification changed"

Assert-R23D1Closure (
    [int]$attemptRecord.physical_process_launch_count -eq 9 -and
    [int]$attemptRecord.process_exit_zero_count -eq 3 -and
    [int]$attemptRecord.process_exit_nonzero_count -eq 6 -and
    [int]$attemptRecord.process_timeout_count -eq 0 -and
    [int]$attemptRecord.complete_cell_report_count -eq 3 -and
    [bool]$attemptRecord.incomplete_diagnostic_aggregate_present -and
    -not [bool]$attemptRecord.valid_complete_aggregate_present -and
    [string]$attemptRecord.completion_status -ceq "invalid_or_incomplete_first_attempt" -and
    [bool]$attemptRecord.one_shot_identity_consumed -and
    -not [bool]$attemptRecord.same_identity_rerun_allowed -and
    -not [bool]$attemptRecord.replacement_or_selective_rerun_allowed -and
    [bool]$closure.technical_disposition.campaign_identity_consumed -and
    [bool]$closure.technical_disposition.declared_nine_cell_process_matrix_launched -and
    -not [bool]$closure.technical_disposition.declared_nine_report_matrix_completed -and
    -not [bool]$closure.technical_disposition.valid_complete_aggregate_report -and
    -not [bool]$closure.technical_disposition.scientific_positive -and
    -not [bool]$closure.technical_disposition.scientific_negative -and
    -not [bool]$closure.technical_disposition.implementation_valid_for_declared_contract -and
    -not [bool]$closure.technical_disposition.three_engine_turning_evaluated
) "$gateId technical disposition changed"
Assert-R23D1Closure (
    [string]$closure.scientific_disposition.classification -ceq
        "no_scientific_result_implementation_invalid_incomplete_three_engine_matrix" -and
    [bool]$closure.scientific_disposition.optimization_is_allowed -and
    [bool]$closure.immutability.same_identity_rerun_forbidden -and
    [bool]$closure.immutability.selective_completion_forbidden -and
    [bool]$closure.immutability.replacement_worker_process_forbidden -and
    [bool]$closure.immutability.attempt_or_evidence_rewrite_forbidden -and
    [bool]$closure.immutability.successor_requires_new_campaign_and_gate_identity -and
    [string]$closure.successor_requirements.successor_id -ceq "QSDK-R23D2" -and
    [bool]$closure.successor_requirements.nonzero_cross_track_position_and_velocity_canaries_required_for_each_adapter -and
    [bool]$closure.successor_requirements.retain_first_rejected_receipt_and_per_predicate_failures_required -and
    [bool]$closure.successor_requirements.stage_aware_world_attempt_and_build_counts_required -and
    [bool]$closure.successor_requirements.all_nine_ordered_cells_must_run_without_outcome_based_early_stop
) "$gateId scientific, immutability, or successor boundary changed"
Assert-R23D1Closure (
    [bool]$closure.claims.complete_attempt_closure -and
    @($closure.claims.GetEnumerator() | Where-Object {
        [string]$_.Key -cne "complete_attempt_closure" -and [bool]$_.Value
    }).Count -eq 0
) "$gateId closure claim boundary changed"

# Current runtime safety is deliberately separate from historical identity.
# All historical claims above are proven from retained bytes and Git blobs;
# these checks prove that no individual current worker can selectively complete
# a consumed R23D1 cell even if someone supplies the retained attempt token.
foreach ($path in @(
    $currentRapierWorkerPath,
    $currentMujocoWorkerPath,
    $currentGodotWorkerPath
)) {
    Assert-R23D1Closure (Test-Path -LiteralPath $path -PathType Leaf) (
        "$gateId current closed worker is missing: $path"
    )
}
$currentRapierSource = Get-Content -Raw -LiteralPath $currentRapierWorkerPath
$rapierPhysicalStart = $currentRapierSource.IndexOf(
    "pub fn run_qsdk_r23d1_rapier_physical",
    [StringComparison]::Ordinal
)
$rapierClosedGuard = $currentRapierSource.IndexOf(
    "if PHYSICAL_IDENTITY_CLOSED",
    $rapierPhysicalStart,
    [StringComparison]::Ordinal
)
$rapierContractLoad = $currentRapierSource.IndexOf(
    "let contract = contract()?;",
    $rapierPhysicalStart,
    [StringComparison]::Ordinal
)
$currentMujocoSource = Get-Content -Raw -LiteralPath $currentMujocoWorkerPath
$mujocoPhysicalStart = $currentMujocoSource.IndexOf(
    "def run_physical(",
    [StringComparison]::Ordinal
)
$mujocoClosedGuard = $currentMujocoSource.IndexOf(
    "if PHYSICAL_IDENTITY_CLOSED:",
    $mujocoPhysicalStart,
    [StringComparison]::Ordinal
)
$mujocoContractLoad = $currentMujocoSource.IndexOf(
    "contract = _contract()",
    $mujocoPhysicalStart,
    [StringComparison]::Ordinal
)
$currentGodotSource = Get-Content -Raw -LiteralPath $currentGodotWorkerPath
$godotRunStart = $currentGodotSource.IndexOf(
    "func _run() -> void:",
    [StringComparison]::Ordinal
)
$godotClosedGuard = $currentGodotSource.IndexOf(
    "if PHYSICAL_IDENTITY_CLOSED:",
    $godotRunStart,
    [StringComparison]::Ordinal
)
$godotSolverConfiguration = $currentGodotSource.IndexOf(
    "var solver_configuration := _apply_solver_configuration()",
    $godotRunStart,
    [StringComparison]::Ordinal
)
Assert-R23D1Closure (
    $currentRapierSource.Contains(
        "const PHYSICAL_IDENTITY_CLOSED: bool = true;",
        [StringComparison]::Ordinal
    ) -and
    $rapierPhysicalStart -ge 0 -and
    $rapierClosedGuard -gt $rapierPhysicalStart -and
    $rapierContractLoad -gt $rapierClosedGuard -and
    $currentRapierSource.Contains(
        "QSDK_R23D1_RAP_PHYSICAL_IDENTITY_CLOSED",
        [StringComparison]::Ordinal
    ) -and
    $currentMujocoSource.Contains(
        "PHYSICAL_IDENTITY_CLOSED = True",
        [StringComparison]::Ordinal
    ) -and
    $mujocoPhysicalStart -ge 0 -and
    $mujocoClosedGuard -gt $mujocoPhysicalStart -and
    $mujocoContractLoad -gt $mujocoClosedGuard -and
    $currentMujocoSource.Contains(
        "QSDK_R23D1_MJC_PHYSICAL_IDENTITY_CLOSED",
        [StringComparison]::Ordinal
    ) -and
    $currentGodotSource.Contains(
        "const PHYSICAL_IDENTITY_CLOSED := true",
        [StringComparison]::Ordinal
    ) -and
    $godotRunStart -ge 0 -and
    $godotClosedGuard -gt $godotRunStart -and
    $godotSolverConfiguration -gt $godotClosedGuard -and
    $currentGodotSource.Contains(
        "QSDK_R23D1_GODOT_JOLT_PHYSICAL_IDENTITY_CLOSED",
        [StringComparison]::Ordinal
    )
) "$gateId current individual-worker closure interlock changed"

$attemptRootsBefore = @(
    Get-ChildItem -LiteralPath (Split-Path -Parent $evidenceRoot) -Directory |
        Where-Object { $_.Name -like "qsdk-r23d1-*" }
)
Assert-R23D1Closure (
    $attemptRootsBefore.Count -eq 1 -and
    [IO.Path]::GetFullPath($attemptRootsBefore[0].FullName) -ceq $evidenceRoot
) "$gateId retained attempt cardinality changed"
$canaryAttestation = Join-Path $repoRoot "R23D1_CLOSED_CANARY_DO_NOT_READ.json"
Assert-R23D1Closure (-not (Test-Path -LiteralPath $canaryAttestation)) (
    "$gateId rerun canary unexpectedly exists"
)
$rerunOutput = @(& pwsh -NoLogo -NoProfile -File $runnerPath `
    -RunPhysical `
    -FullConformanceAttestation $canaryAttestation 2>&1)
$rerunExit = $LASTEXITCODE
$rerunText = $rerunOutput -join "`n"
Assert-R23D1Closure (
    $rerunExit -ne 0 -and
    $rerunText.Contains(
        "QSDK-R23D1 is closed and may not open another world",
        [StringComparison]::Ordinal
    ) -and
    -not $rerunText.Contains("full-Godot V2 attestation", [StringComparison]::Ordinal)
) "$gateId current closed-state rerun interlock changed: $rerunText"
$attemptRootsAfter = @(
    Get-ChildItem -LiteralPath (Split-Path -Parent $evidenceRoot) -Directory |
        Where-Object { $_.Name -like "qsdk-r23d1-*" }
)
$treeAfter = Get-R23D1EvidenceTreeDigest $evidenceRoot
Assert-R23D1Closure (
    $attemptRootsAfter.Count -eq 1 -and
    [IO.Path]::GetFullPath($attemptRootsAfter[0].FullName) -ceq $evidenceRoot -and
    [int]$treeAfter.file_count -eq [int]$treeBefore.file_count -and
    [long]$treeAfter.total_byte_length -eq [long]$treeBefore.total_byte_length -and
    [string]$treeAfter.tree_sha256 -ceq [string]$treeBefore.tree_sha256
) "$gateId rerun canary changed the retained attempt"
$global:LASTEXITCODE = 0

Write-Host (
    "QSDK_R23D1_CLOSURE_PASS status=implementation-invalid processes=9 " +
    "complete_reports=3 godot=3/3 rapier=0/3 mujoco=0/3 timeouts=0 " +
    "aggregate=False scientific_result=False q_sdk_r23=False " +
    "equivalence=False release=False individual_worker_refusals=3 " +
    "rerun_refused=True"
)
