#requires -Version 7.0

[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$evidenceRoot = "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence"
$artifactRoot = Join-Path $evidenceRoot "artifacts\sha256"
$attemptPopulationRoot = Join-Path $evidenceRoot "turning\production-route-ghost-v1"
$closurePath = Join-Path $repoRoot (
    "sdk\turning\three_engine_turning_production_route_development_closure_v1.json"
)
$routeContractPath = Join-Path $repoRoot (
    "sdk\turning\three_engine_turning_production_route_v1.json"
)
$supportMatrixPath = Join-Path $repoRoot "sdk\release\quadruped_support_matrix.json"
$releaseContractPath = Join-Path $repoRoot "sdk\release\quadruped_release_contract.json"
$auditPath = $MyInvocation.MyCommand.Path
$sourceCommit = "c93bcc479d3f882ce61e4ff21d036d3aae3f877d"
$sourceTree = "48264e307c262312e5a031cb45f6cfce3d518af2"
$passingAttemptId = "2f586ca10fc4421b9e133f0801061cb7"

function Assert-RouteClosure([bool]$Condition, [string]$Message) {
    if (-not $Condition) {
        throw "THREE-ENGINE TURNING ROUTE CLOSURE: $Message"
    }
}

function Get-RouteClosureSha256([string]$Path) {
    return "sha256:" + (
        Get-FileHash -LiteralPath $Path -Algorithm SHA256
    ).Hash.ToLowerInvariant()
}

function Invoke-RouteClosureGit([string[]]$Arguments) {
    $lines = @(& git -C $repoRoot @Arguments 2>&1)
    Assert-RouteClosure ($LASTEXITCODE -eq 0) (
        "git $($Arguments -join ' ') failed: $($lines -join ' ')"
    )
    return ($lines -join "`n").Trim()
}

function Get-RouteClosureJson([string]$Path) {
    return Get-Content -LiteralPath $Path -Raw |
        ConvertFrom-Json -AsHashtable -Depth 100
}

function Assert-RouteClosureArtifact(
    [string]$Path,
    [long]$ByteLength,
    [string]$RawSha256
) {
    Assert-RouteClosure (Test-Path -LiteralPath $Path -PathType Leaf) (
        "artifact is missing: $Path"
    )
    Assert-RouteClosure ((Get-Item -LiteralPath $Path).Length -eq $ByteLength) (
        "artifact byte length changed: $Path"
    )
    Assert-RouteClosure ((Get-RouteClosureSha256 $Path) -ceq $RawSha256) (
        "artifact digest changed: $Path"
    )
}

Assert-RouteClosure (
    (Invoke-RouteClosureGit @("rev-parse", "--show-toplevel")) -ceq
        $repoRoot.Replace("\", "/")
) "repository root changed"
Assert-RouteClosure (
    (Invoke-RouteClosureGit @("remote", "get-url", "origin")) -ceq
        "https://github.com/Slagathore/sporespore.git"
) "repository remote changed"

foreach ($path in @(
    $closurePath,
    $routeContractPath,
    $supportMatrixPath,
    $releaseContractPath,
    $auditPath,
    $attemptPopulationRoot
)) {
    Assert-RouteClosure (Test-Path -LiteralPath $path) "path is missing: $path"
}

$closure = Get-RouteClosureJson $closurePath
Assert-RouteClosure (
    [string]$closure.schema_version -ceq
        "sporespore_three_engine_turning_production_route_development_closure_v1"
) "closure schema changed"
Assert-RouteClosure (
    [string]$closure.status -ceq
        "closed_complete_execution_valid_development_route_ghost"
) "closure status changed"
Assert-RouteClosure (
    [string]$closure.route_id -ceq
        "sporespore_three_engine_turning_production_route_v1"
) "route identity changed"
Assert-RouteClosure ([string]$closure.release_gate_id -ceq "QSDK-R23") (
    "release gate identity changed"
)
Assert-RouteClosure (
    [string]$closure.ledger_scope.subsystem -ceq "turning" -and
    [string]$closure.ledger_scope.engine_scope -ceq "3e" -and
    [string]$closure.ledger_scope.authority_mode -ceq "development_ghost" -and
    [string]$closure.ledger_scope.question_class -ceq "development" -and
    [string]$closure.physical_question_class -ceq "development"
) "ledger classification changed"
Assert-RouteClosure (
    [string]$closure.source_commit -ceq $sourceCommit -and
    [string]$closure.source_tree_git_oid -ceq $sourceTree -and
    (Invoke-RouteClosureGit @("rev-parse", "$sourceCommit^{tree}")) -ceq $sourceTree
) "passing source identity changed"
Assert-RouteClosure (
    [string]$closure.route_contract.path -ceq
        "sdk/turning/three_engine_turning_production_route_v1.json" -and
    [string]$closure.route_contract.raw_sha256 -ceq
        "sha256:478e53b21cfd331ab0aa137596d43d6fb86c80ab11d517ce7dfca1113e35f44c" -and
    (Get-RouteClosureSha256 $routeContractPath) -ceq
        [string]$closure.route_contract.raw_sha256
) "route contract identity changed"

$question = $closure.development_question
Assert-RouteClosure (
    [string]$question.configuration_id -ceq
        "turning_3e_positive_heading_two_step_ghost_v1" -and
    [int]$question.campaign_seed -eq 21516 -and
    [string]$question.arm_id -ceq "positive_heading" -and
    [double]$question.turn_heading_offset_rad -eq 0.2 -and
    [int]$question.controller_semantic_step_count -eq 2 -and
    [int]$question.declared_world_count -eq 3 -and
    -not [bool]$question.physical_behavior_thresholds_applied -and
    -not [bool]$question.behavioral_success_question_asked -and
    [bool]$question.valid_physics_negative_would_have_satisfied_question
) "development question changed"
Assert-RouteClosure (
    [string]::IsNullOrWhiteSpace([string]$question.adequacy_argument) -eq $false
) "development adequacy argument is missing"
Assert-RouteClosure (
    (@($question.ordered_engine_ids) -join "|") -ceq
        "godot_jolt|rapier_parry|mujoco"
) "ordered engine population changed"

$zeroWorld = $closure.zero_world_gate
Assert-RouteClosureArtifact (
    [string]$zeroWorld.artifact_path
) ([long]$zeroWorld.byte_length) ([string]$zeroWorld.raw_sha256)
$zeroWorldRecord = Get-RouteClosureJson ([string]$zeroWorld.artifact_path)
Assert-RouteClosure (
    [bool]$zeroWorld.complete_zero_world_gate_passed -and
    [bool]$zeroWorldRecord.complete_zero_world_gate_passed -and
    [int]$zeroWorld.serialized_process_count -eq 8 -and
    [int]$zeroWorldRecord.process_count -eq 8 -and
    [int]$zeroWorld.evaluator_preflight_count -eq 1 -and
    [int]$zeroWorldRecord.evaluator_preflight_count -eq 1 -and
    [int]$zeroWorld.worker_preflight_count -eq 3 -and
    [int]$zeroWorldRecord.worker_preflight_count -eq 3 -and
    [int]$zeroWorld.embedded_negative_control_count -eq 10 -and
    [int]$zeroWorldRecord.embedded_negative_control_count -eq 10 -and
    [int]$zeroWorld.authorization_negative_control_count -eq 3 -and
    [int]$zeroWorldRecord.authorization_negative_count -eq 3 -and
    [int]$zeroWorld.total_negative_control_count -eq 13 -and
    [int]$zeroWorldRecord.total_negative_control_count -eq 13 -and
    [int]$zeroWorldRecord.model_construction_count -eq 0 -and
    [int]$zeroWorldRecord.world_attempt_count -eq 0 -and
    [int]$zeroWorldRecord.world_build_count -eq 0 -and
    -not [bool]$zeroWorldRecord.physical_execution_authorized
) "complete zero-world gate changed"

$population = $closure.complete_attempt_population
$attempts = @($population.ordered_attempts)
Assert-RouteClosure (
    [string]$population.durable_root -ceq $attemptPopulationRoot -and
    [int]$population.attempt_count -eq 4 -and
    $attempts.Count -eq 4 -and
    [int]$population.retained_file_count -eq 210 -and
    [long]$population.retained_byte_count -eq 984122 -and
    [bool]$population.every_positive_negative_invalid_and_incomplete_attempt_retained
) "attempt-population declaration changed"

$expectedAttemptIds = @(
    "843b1e6848024df5b2a80696adc89f07",
    "23a120d0f0c7461e9a0087bcae769909",
    "fa1b5fdf25304f70ac401a78606a52f5",
    $passingAttemptId
)
$observedPopulationFileCount = 0
$observedPopulationByteCount = 0L
for ($index = 0; $index -lt $attempts.Count; $index += 1) {
    $attempt = $attempts[$index]
    Assert-RouteClosure (
        [string]$attempt.attempt_id -ceq $expectedAttemptIds[$index]
    ) "attempt order or identity changed at index $index"
    $attemptRoot = Join-Path $attemptPopulationRoot (
        [string]$attempt.attempt_root_name
    )
    Assert-RouteClosure (Test-Path -LiteralPath $attemptRoot -PathType Container) (
        "attempt root is missing: $attemptRoot"
    )
    $files = @(Get-ChildItem -LiteralPath $attemptRoot -Recurse -File)
    $bytes = [long](($files | Measure-Object -Property Length -Sum).Sum)
    Assert-RouteClosure (
        $files.Count -eq [int]$attempt.retained_file_count -and
        $bytes -eq [long]$attempt.retained_byte_count
    ) "attempt population changed: $($attempt.attempt_id)"
    $observedPopulationFileCount += $files.Count
    $observedPopulationByteCount += $bytes
    $terminalRecordPath = Join-Path $attemptRoot (
        [string]$attempt.terminal_record_relative_path
    )
    Assert-RouteClosureArtifact $terminalRecordPath (
        (Get-Item -LiteralPath $terminalRecordPath).Length
    ) ([string]$attempt.terminal_record_raw_sha256)
    $terminalRecord = Get-RouteClosureJson $terminalRecordPath
    Assert-RouteClosure (
        [string]$terminalRecord.attempt_id -ceq [string]$attempt.attempt_id -and
        [string]$terminalRecord.source_commit -ceq [string]$attempt.source_commit -and
        [bool]$terminalRecord.route_execution_valid -eq
            [bool]$attempt.route_execution_valid
    ) "attempt terminal record changed: $($attempt.attempt_id)"
}
Assert-RouteClosure (
    $observedPopulationFileCount -eq [int]$population.retained_file_count -and
    $observedPopulationByteCount -eq [long]$population.retained_byte_count
) "aggregate attempt population changed"

$firstAttempt = $attempts[0]
$firstRecordPath = Join-Path (
    (Join-Path $attemptPopulationRoot ([string]$firstAttempt.attempt_root_name))
) ([string]$firstAttempt.terminal_record_relative_path)
$firstRecord = Get-RouteClosureJson $firstRecordPath
Assert-RouteClosure (
    [string]$firstAttempt.disposition -ceq
        "infrastructure_invalid_or_incomplete_before_world_open" -and
    [string]$firstRecord.failure_code -ceq [string]$firstAttempt.failure_code -and
    [int]$firstAttempt.physical_worker_process_count -eq 0 -and
    [int]$firstAttempt.complete_evaluator_invocation_count -eq 0
) "first incomplete attempt changed"

foreach ($attempt in @($attempts[1], $attempts[2], $attempts[3])) {
    $attemptRoot = Join-Path $attemptPopulationRoot (
        [string]$attempt.attempt_root_name
    )
    $result = Get-RouteClosureJson (
        (Join-Path $attemptRoot ([string]$attempt.terminal_record_relative_path))
    )
    Assert-RouteClosure (
        [int]$result.physical_worker_process_count -eq
            [int]$attempt.physical_worker_process_count -and
        [int]$result.execution_valid_worker_count -eq
            [int]$attempt.execution_valid_worker_count -and
        [int]$result.complete_evaluator_invocation_count -eq
            [int]$attempt.complete_evaluator_invocation_count -and
        [int]$result.evaluation_process_record.exit_code -eq
            [int]$attempt.complete_evaluator_exit_code
    ) "attempt result counts changed: $($attempt.attempt_id)"
}

$passing = $closure.passing_attempt
$expectedPassingAttemptRoot = Join-Path $attemptPopulationRoot (
    "20260825T184503322241Z__2f586ca10fc4421b9e133f0801061cb7"
)
Assert-RouteClosure (
    [string]$passing.attempt_id -ceq $passingAttemptId -and
    [string]$passing.attempt_root -ceq $expectedPassingAttemptRoot
) "passing attempt identity changed"
$supervisorPath = Join-Path ([string]$passing.attempt_root) (
    [string]$passing.supervisor_result.relative_path
)
Assert-RouteClosureArtifact $supervisorPath (
    [long]$passing.supervisor_result.byte_length
) ([string]$passing.supervisor_result.raw_sha256)
$supervisor = Get-RouteClosureJson $supervisorPath
Assert-RouteClosure (
    [string]$supervisor.outcome_class -ceq
        "execution_valid_development_route_ghost" -and
    [bool]$supervisor.route_execution_valid -and
    [int]$supervisor.execution_valid_worker_count -eq 3 -and
    [int]$supervisor.complete_evaluator_invocation_count -eq 1 -and
    [int]$supervisor.physical_worker_process_count -eq 3 -and
    [int]$supervisor.declared_world_count -eq 3 -and
    -not [bool]$supervisor.physical_behavior_thresholds_applied -and
    -not [bool]$supervisor.physical_acceptance_authority
) "passing supervisor result changed"

$engineResults = @($passing.ordered_engine_results)
Assert-RouteClosure ($engineResults.Count -eq 3) "engine result count changed"
for ($index = 0; $index -lt $engineResults.Count; $index += 1) {
    $declared = $engineResults[$index]
    $terminalPath = Join-Path ([string]$passing.attempt_root) (
        ([string]$declared.terminal_relative_path).Replace("/", "\")
    )
    Assert-RouteClosureArtifact $terminalPath (
        [long]$declared.terminal_byte_length
    ) ([string]$declared.terminal_raw_sha256)
    $terminal = Get-RouteClosureJson $terminalPath
    Assert-RouteClosure (
        [string]$terminal.schema_version -ceq
            "sporespore_three_engine_turning_route_cell_report_v1" -and
        [string]$terminal.source_commit -ceq $sourceCommit -and
        [string]$terminal.engine_id -ceq [string]$declared.engine_id -and
        [int]$terminal.campaign_seed -eq 21516 -and
        [string]$terminal.arm_id -ceq "positive_heading" -and
        [double]$terminal.turn_heading_offset_rad -eq 0.2 -and
        [int]$terminal.execution.world_attempt_count -eq 1 -and
        [int]$terminal.execution.world_build_count -eq 1 -and
        [int]$terminal.execution.controller_semantic_step_count -eq 2 -and
        [int]$terminal.execution.validated_portable_command_count -eq 16 -and
        [int]$terminal.execution.native_actuation_application_count -eq 16 -and
        [int]$terminal.execution.portable_impulse_violation_count -eq 0 -and
        [bool]$terminal.execution.integrity_passed -and
        [int]$terminal.trace_retention.row_count -eq 2 -and
        [int]$terminal.trace_retention.nonzero_turn_command_step_count -eq 2 -and
        [bool]$terminal.trace_retention.retained_before_terminal_entry -and
        [string]$terminal.trace_retention.trace_artifact.sha256 -ceq
            [string]$declared.trace_raw_sha256 -and
        [long]$terminal.trace_retention.trace_artifact.byte_length -eq
            [long]$declared.trace_byte_length -and
        -not [bool]$terminal.physical_behavior_thresholds_applied -and
        -not [bool]$terminal.physical_acceptance_authority
    ) "passing terminal changed: $($declared.engine_id)"
    foreach ($claimName in @(
        "arbitrary_quadruped_coverage",
        "cross_engine_equivalence",
        "physical_acceptance_authority",
        "portable_basic_turning",
        "q_sdk_r23_satisfied",
        "release_authorized",
        "turning_established"
    )) {
        Assert-RouteClosure (-not [bool]$terminal.claims[$claimName]) (
            "terminal claim became true: $($declared.engine_id)/$claimName"
        )
    }
    $digest = ([string]$declared.trace_raw_sha256).Substring(7)
    $payloadPath = Join-Path $artifactRoot "$digest\payload.bin"
    Assert-RouteClosureArtifact $payloadPath (
        [long]$declared.trace_byte_length
    ) ([string]$declared.trace_raw_sha256)
}

$evaluation = $passing.complete_evaluation
$evaluationPath = Join-Path ([string]$passing.attempt_root) (
    ([string]$evaluation.relative_path).Replace("/", "\")
)
$evaluationStdoutPath = Join-Path ([string]$passing.attempt_root) (
    ([string]$evaluation.stdout_relative_path).Replace("/", "\")
)
Assert-RouteClosureArtifact $evaluationPath (
    [long]$evaluation.byte_length
) ([string]$evaluation.raw_sha256)
Assert-RouteClosureArtifact $evaluationStdoutPath (
    [long]$evaluation.stdout_byte_length
) ([string]$evaluation.stdout_raw_sha256)
$evaluationRecord = Get-RouteClosureJson $evaluationPath
Assert-RouteClosure (
    [string]$evaluationRecord.behavioral_outcome -ceq
        "not_evaluated_development_route_ghost" -and
    [int]$evaluationRecord.declared_engine_count -eq 3 -and
    [int]$evaluationRecord.execution_valid_engine_count -eq 3 -and
    [int]$evaluationRecord.complete_evaluator_invocation_count -eq 1 -and
    [bool]$evaluationRecord.route_execution_valid -and
    -not [bool]$evaluationRecord.physical_behavior_thresholds_applied -and
    @($evaluationRecord.engine_evaluations).Count -eq 3
) "complete evaluator result changed"
foreach ($engineEvaluation in @($evaluationRecord.engine_evaluations)) {
    Assert-RouteClosure (
        [bool]$engineEvaluation.execution_valid -and
        [int]$engineEvaluation.trace_row_count -eq 2 -and
        [string]$engineEvaluation.physics_behavior_classification -ceq
            "not_evaluated_development_route_ghost"
    ) "engine evaluation changed: $($engineEvaluation.engine_id)"
}

$interpretation = $closure.observed_result_interpretation
Assert-RouteClosure (
    [string]$interpretation.direct_supervisor_outcome_class -ceq
        [string]$supervisor.outcome_class -and
    [bool]$interpretation.direct_supervisor_route_execution_valid -eq
        [bool]$supervisor.route_execution_valid -and
    [bool]$interpretation.direct_complete_evaluator_route_execution_valid -eq
        [bool]$evaluationRecord.route_execution_valid -and
    [string]$interpretation.direct_complete_evaluator_behavioral_outcome -ceq
        [string]$evaluationRecord.behavioral_outcome -and
    [bool]$interpretation.supervisor_top_level_claim_vector_retained_without_rewrite -and
    -not [bool]$interpretation.supervisor_top_level_development_ghost_execution_valid_claim_value -and
    -not [bool]$supervisor.claims.development_ghost_execution_valid
) "observed-result interpretation changed"

$claims = $closure.claims
Assert-RouteClosure (
    [bool]$claims.development_route_closed_execution_valid -and
    -not [bool]$claims.turning_established -and
    -not [bool]$claims.finite_three_engine_turning -and
    -not [bool]$claims.portable_basic_turning -and
    -not [bool]$claims.cross_engine_equivalence -and
    -not [bool]$claims.arbitrary_quadruped_coverage -and
    -not [bool]$claims.prone_to_standing -and
    -not [bool]$claims.q_sdk_r23_satisfied -and
    -not [bool]$claims.physical_acceptance_authority -and
    -not [bool]$claims.release_authorized -and
    [string]$claims.release_score_before -ceq "10/25" -and
    [string]$claims.release_score_after -ceq "10/25" -and
    -not [bool]$claims.release_score_changed
) "closure claim boundary changed"
$successor = $closure.successor_boundary
Assert-RouteClosure (
    -not [bool]$successor.held_out_successor_opened_at_closure -and
    [bool]$successor.scientifically_distinct_finite_decision_required -and
    [bool]$successor.fresh_held_out_seed_required -and
    [bool]$successor.prospective_threshold_provenance_required -and
    [bool]$successor.prospective_margin_and_adequacy_argument_required -and
    [bool]$successor.zero_command_straight_compatibility_required -and
    [bool]$successor.bilateral_commanded_turning_required -and
    [bool]$successor.all_three_genuine_engines_required -and
    -not [bool]$successor.development_attempts_may_be_reused_as_held_out_behavioral_evidence
) "successor boundary changed"

$support = Get-RouteClosureJson $supportMatrixPath
$supportRoute = $support.locomotion_modes.three_engine_turning_production_route
Assert-RouteClosure ($null -ne $supportRoute) "support-matrix route closure is missing"
Assert-RouteClosure (
    [string]$supportRoute.status -ceq [string]$closure.status -and
    [string]$supportRoute.question_class -ceq "development" -and
    [string]$supportRoute.source_commit -ceq $sourceCommit -and
    [string]$supportRoute.closure_path -ceq
        "sdk/turning/three_engine_turning_production_route_development_closure_v1.json" -and
    [string]$supportRoute.closure_raw_sha256 -ceq
        (Get-RouteClosureSha256 $closurePath) -and
    [string]$supportRoute.closure_audit_path -ceq
        "tests/test_three_engine_turning_production_route_development_closure.ps1" -and
    [string]$supportRoute.closure_audit_raw_sha256 -ceq
        (Get-RouteClosureSha256 $auditPath) -and
    [bool]$supportRoute.route_execution_valid -and
    [int]$supportRoute.execution_valid_engine_count -eq 3 -and
    [int]$supportRoute.trace_row_count_per_engine -eq 2 -and
    [int]$supportRoute.complete_evaluator_invocation_count -eq 1 -and
    [string]$supportRoute.behavioral_outcome -ceq
        "not_evaluated_development_route_ghost" -and
    -not [bool]$supportRoute.physical_behavior_thresholds_applied -and
    -not [bool]$supportRoute.turning_established -and
    -not [bool]$supportRoute.q_sdk_r23_satisfied -and
    -not [bool]$supportRoute.release_authorized
) "support-matrix route closure changed"
Assert-RouteClosure (
    -not [bool]$support.locomotion_modes.command_conditioned_turning -and
    -not [bool]$support.claim_boundary.command_conditioned_turning -and
    -not [bool]$support.release_authorized
) "public support boundary changed"

$release = Get-RouteClosureJson $releaseContractPath
$turningGate = @($release.gates | Where-Object {
    [string]$_.gate_id -ceq "QSDK-R23"
})
Assert-RouteClosure (
    $turningGate.Count -eq 1 -and
    [string]$turningGate[0].proof.kind -ceq "missing"
) "QSDK-R23 was promoted by a development route ghost"
Assert-RouteClosure (
    [string]$release.contract_status -ne "release_authorized"
) "release contract was authorized by a development route ghost"

Write-Output (
    "[turning/3e] PASS production-route development closure: " +
    "4 retained attempts, 3 genuine execution-valid engines, 2 rows each, " +
    "1 complete evaluator; behavioral and QSDK-R23 claims remain false."
)
