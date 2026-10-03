#requires -Version 7.0

[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$closurePath = Join-Path $repoRoot (
    "sdk\turning\three_engine_turning_success_transport_route_v2_closure.json"
)
$attempt1AuditPath = Join-Path $repoRoot (
    "sdk\audit_three_engine_turning_success_transport_v2_attempt1_closure.ps1"
)
$attempt2AuditPath = Join-Path $repoRoot (
    "sdk\audit_three_engine_turning_success_transport_v2_attempt2_closure.ps1"
)
$zeroWorldRunnerPath = Join-Path $repoRoot (
    "sdk\run_three_engine_turning_success_transport_v2_zero_world.ps1"
)
$supportMatrixPath = Join-Path $repoRoot "sdk\release\quadruped_support_matrix.json"
$releaseContractPath = Join-Path $repoRoot "sdk\release\quadruped_release_contract.json"
$evidenceParent = [IO.Path]::GetFullPath(
    "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence\turning\success-transport-ghost-v2"
)
$expectedRemote = "https://github.com/Slagathore/sporespore.git"
$passingSourceCommit = "d5c5fa5e8ba71b4b427e137e05b9909c868fc4f8"
$passingSourceTree = "6fc8f7a3a5fbc0627dc8df31ab77d2ee0449899b"
$expectedAttemptDirectories = @(
    "20260826T065559127336Z__f8a1110971384270a79c673da6310240",
    "20260826T070915871967Z__d11584853848406e81c5ac7ae816128c",
    "20260826T072513369325Z__e6b716c2edc64e49989a0b597236893c"
)

function Assert-TransportRouteClosure([bool]$Condition, [string]$Message) {
    if (-not $Condition) {
        throw "[turning/transport] v2 route closure audit: $Message"
    }
}

function Invoke-TransportRouteClosureGit([string[]]$Arguments) {
    $lines = @(& git -C $repoRoot @Arguments 2>&1)
    Assert-TransportRouteClosure ($LASTEXITCODE -eq 0) (
        "git $($Arguments -join ' ') failed: $($lines -join ' ')"
    )
    return ($lines -join "`n").Trim()
}

function Get-TransportRouteClosureJson([string]$Path) {
    return Get-Content -LiteralPath $Path -Raw |
        ConvertFrom-Json -AsHashtable -Depth 100
}

function Get-TransportRouteClosureSha256([string]$Path) {
    return "sha256:" + (
        Get-FileHash -LiteralPath $Path -Algorithm SHA256
    ).Hash.ToLowerInvariant()
}

function Get-TransportRoutePopulation([string]$Root) {
    $records = @(
        Get-ChildItem -LiteralPath $Root -Recurse -File | ForEach-Object {
            [pscustomobject]@{
                Relative = [IO.Path]::GetRelativePath($Root, $_.FullName).Replace("\", "/")
                Path = $_.FullName
                Length = [long]$_.Length
            }
        } | Sort-Object -Property Relative
    )
    $manifestLines = @(
        foreach ($record in $records) {
            "$($record.Relative)`t$($record.Length)`t$(Get-TransportRouteClosureSha256 $record.Path)"
        }
    )
    $canonicalManifest = ($manifestLines -join "`n") + "`n"
    return [pscustomobject]@{
        Records = $records
        FileCount = $records.Count
        TotalByteLength = [long](($records | Measure-Object -Property Length -Sum).Sum)
        ManifestSha256 = "sha256:" + [Convert]::ToHexString(
            [Security.Cryptography.SHA256]::HashData(
                [Text.Encoding]::UTF8.GetBytes($canonicalManifest)
            )
        ).ToLowerInvariant()
    }
}

function Invoke-TransportRouteClosureAudit([string]$Path) {
    & pwsh -NoProfile -File $Path
    Assert-TransportRouteClosure ($LASTEXITCODE -eq 0) "audit failed: $Path"
}

Assert-TransportRouteClosure (
    (Invoke-TransportRouteClosureGit @("rev-parse", "--show-toplevel")) -ceq
        $repoRoot.Replace("\", "/")
) "repository root changed"
Assert-TransportRouteClosure (
    (Invoke-TransportRouteClosureGit @("remote", "get-url", "origin")) -ceq $expectedRemote
) "repository remote changed"
Assert-TransportRouteClosure (
    (Invoke-TransportRouteClosureGit @("rev-parse", "$passingSourceCommit^{tree}")) -ceq
        $passingSourceTree
) "passing source tree changed"

$closure = Get-TransportRouteClosureJson $closurePath
Assert-TransportRouteClosure (
    [string]$closure.schema_version -ceq
        "sporespore_three_engine_turning_success_transport_route_closure_v2" -and
    [string]$closure.closure_id -ceq
        "sporespore_three_engine_turning_success_transport_route_v2_closure" -and
    [string]$closure.route_id -ceq
        "sporespore_three_engine_turning_success_transport_route_v2" -and
    [string]$closure.status -ceq
        "closed_complete_execution_valid_development_success_transport_ghost" -and
    [string]$closure.ledger_scope.subsystem -ceq "turning" -and
    [string]$closure.ledger_scope.engine_scope -ceq "3e" -and
    [string]$closure.ledger_scope.question_class -ceq "development" -and
    [string]$closure.source_authority.passing_source_commit -ceq $passingSourceCommit -and
    [string]$closure.source_authority.passing_source_tree_git_oid -ceq $passingSourceTree -and
    [bool]$closure.source_authority.passing_source_was_clean_pushed_and_live_equal
) "closure identity or source changed"

$lineage = $closure.implementation_lineage
foreach ($binding in @(
    @($lineage.route_implementation_path, $lineage.route_implementation_raw_sha256),
    @($lineage.godot_integer_projection_repair_path, $lineage.godot_integer_projection_repair_raw_sha256),
    @($lineage.rapier_retention_question_class_repair_path, $lineage.rapier_retention_question_class_repair_raw_sha256)
)) {
    $path = Join-Path $repoRoot ([string]$binding[0])
    Assert-TransportRouteClosure (
        (Get-TransportRouteClosureSha256 $path) -ceq [string]$binding[1]
    ) "implementation lineage changed: $path"
}
Assert-TransportRouteClosure (
    -not [bool]$lineage.historical_threshold_selector_evaluator_or_interpretation_changed
) "historical interpretation boundary changed"

$attempts = @($closure.retained_attempt_population.attempts)
$attemptDirectories = @(
    Get-ChildItem -LiteralPath $evidenceParent -Directory |
        Sort-Object -Property Name | ForEach-Object { $_.Name }
)
Assert-TransportRouteClosure (
    $attempts.Count -eq 3 -and
    [int]$closure.retained_attempt_population.attempt_count -eq 3 -and
    ($attemptDirectories -join "|") -ceq ($expectedAttemptDirectories -join "|") -and
    [int]$closure.retained_attempt_population.same_source_rerun_count -eq 0 -and
    [int]$closure.retained_attempt_population.selective_engine_rerun_count -eq 0
) "retained attempt population identity changed"
$aggregateFiles = 0
$aggregateBytes = [long]0
for ($index = 0; $index -lt $attempts.Count; $index += 1) {
    $attempt = $attempts[$index]
    $expectedDirectory = $expectedAttemptDirectories[$index]
    $attemptRoot = Join-Path $evidenceParent $expectedDirectory
    $population = Get-TransportRoutePopulation $attemptRoot
    Assert-TransportRouteClosure (
        [int]$attempt.ordinal -eq ($index + 1) -and
        [string]$attempt.attempt_directory -ceq $expectedDirectory -and
        $population.FileCount -eq [int]$attempt.file_count -and
        $population.TotalByteLength -eq [long]$attempt.total_byte_length -and
        $population.ManifestSha256 -ceq [string]$attempt.canonical_manifest_sha256
    ) "attempt population changed: $expectedDirectory"
    $aggregateFiles += $population.FileCount
    $aggregateBytes += $population.TotalByteLength
}
Assert-TransportRouteClosure (
    $aggregateFiles -eq [int]$closure.retained_attempt_population.total_file_count -and
    $aggregateBytes -eq [long]$closure.retained_attempt_population.total_byte_length -and
    $aggregateFiles -eq 184 -and
    $aggregateBytes -eq 1054449
) "aggregate retained population changed"

$passingRoot = [IO.Path]::GetFullPath([string]$closure.passing_attempt.attempt_root)
Assert-TransportRouteClosure (
    $passingRoot -ceq (Join-Path $evidenceParent $expectedAttemptDirectories[2]) -and
    [string]$closure.passing_attempt.attempt_id -ceq
        "e6b716c2edc64e49989a0b597236893c" -and
    [string]$closure.passing_attempt.source_commit -ceq $passingSourceCommit -and
    [bool]$closure.passing_attempt.attempt_identity_consumed -and
    -not [bool]$closure.passing_attempt.same_source_physical_rerun_allowed -and
    -not [bool]$closure.passing_attempt.selective_engine_rerun_allowed
) "passing attempt boundary changed"
foreach ($artifact in @($closure.passing_evidence_population.selected_artifacts)) {
    $path = Join-Path $passingRoot ([string]$artifact.relative_path)
    Assert-TransportRouteClosure (
        (Get-Item -LiteralPath $path).Length -eq [long]$artifact.byte_length -and
        (Get-TransportRouteClosureSha256 $path) -ceq [string]$artifact.raw_sha256
    ) "passing selected artifact changed: $path"
}

$zeroWorld = Get-TransportRouteClosureJson (
    Join-Path $passingRoot "zero-world\complete-gate.json"
)
Assert-TransportRouteClosure (
    [bool]$zeroWorld.complete_zero_world_gate_passed -and
    [int]$zeroWorld.process_count -eq 8 -and
    [int]$zeroWorld.worker_preflight_count -eq 3 -and
    [int]$zeroWorld.evaluator_preflight_count -eq 1 -and
    [int]$zeroWorld.authorization_negative_count -eq 3 -and
    [int]$zeroWorld.embedded_negative_control_count -eq 21 -and
    [int]$zeroWorld.total_negative_control_count -eq 24 -and
    [int]$zeroWorld.model_construction_count -eq 0 -and
    [int]$zeroWorld.world_attempt_count -eq 0 -and
    [int]$zeroWorld.world_build_count -eq 0
) "passing zero-world evidence changed"

$authorization = Get-TransportRouteClosureJson (
    Join-Path $passingRoot "authorization-preflight\complete-matrix.json"
)
Assert-TransportRouteClosure (
    [int]$authorization.receipt_count -eq 3 -and
    @($authorization.worker_receipts | Where-Object {
        [bool]$_.authorization_passed -and [bool]$_.returned_before_model
    }).Count -eq 3 -and
    [bool]$authorization.all_workers_authorized_before_model -and
    [int]$authorization.model_construction_count -eq 0 -and
    [int]$authorization.world_attempt_count -eq 0 -and
    [int]$authorization.world_build_count -eq 0
) "passing authorization evidence changed"

$terminalRelativePaths = @(
    "physical/00__godot_jolt/terminal.json",
    "physical/01__rapier_parry/terminal.json",
    "physical/02__mujoco/terminal.json"
)
$expectedEngines = @("godot_jolt", "rapier_parry", "mujoco")
$casByEngine = @{}
foreach ($artifact in @($closure.cas_artifacts)) {
    $casByEngine[[string]$artifact.engine_id] = $artifact
}
for ($index = 0; $index -lt $terminalRelativePaths.Count; $index += 1) {
    $terminalPath = Join-Path $passingRoot $terminalRelativePaths[$index]
    $terminal = Get-TransportRouteClosureJson $terminalPath
    $engine = $expectedEngines[$index]
    $expectedCas = $casByEngine[$engine]
    Assert-TransportRouteClosure (
        [string]$terminal.schema_version -ceq
            "sporespore_three_engine_turning_success_transport_cell_report_v2" -and
        [string]$terminal.question_class -ceq "development" -and
        [string]$terminal.trace_retention.question_class -ceq "development" -and
        [string]$terminal.engine_id -ceq $engine -and
        [int]$terminal.execution.world_attempt_count -eq 1 -and
        [int]$terminal.execution.world_build_count -eq 1 -and
        [int]$terminal.execution.controller_semantic_step_count -eq 2 -and
        [string]$terminal.trace_artifact.trace_transport_id -ceq
            "sporespore_three_engine_turning_success_transport_v2" -and
        [string]$terminal.trace_artifact.trace_transport_engine_id -ceq $engine -and
        [bool]$terminal.trace_artifact.canonical_ndjson -and
        [bool]$terminal.trace_artifact.full_precision -and
        $terminal.trace_artifact.byte_length.GetType().Name -ceq "Int64" -and
        $terminal.trace_retention.trace_artifact.byte_length.GetType().Name -ceq "Int64"
    ) "passing native terminal changed: $engine"
    Assert-TransportRouteClosure (
        (Get-TransportRouteClosureSha256 ([string]$terminal.trace_artifact.payload_path)) -ceq
            [string]$expectedCas.artifact_sha256 -and
        (Get-Item -LiteralPath ([string]$terminal.trace_artifact.payload_path)).Length -eq
            [long]$expectedCas.byte_length -and
        (Get-TransportRouteClosureSha256 ([string]$terminal.trace_artifact.manifest_path)) -ceq
            [string]$expectedCas.manifest_raw_sha256
    ) "passing CAS artifact changed: $engine"
    $traceRows = @(Get-Content -LiteralPath ([string]$terminal.trace_artifact.payload_path) |
        ForEach-Object { $_ | ConvertFrom-Json -AsHashtable -Depth 100 })
    Assert-TransportRouteClosure (
        $traceRows.Count -eq 2 -and
        [int]$traceRows[0].semantic_step -eq 0 -and
        [int]$traceRows[1].semantic_step -eq 1
    ) "passing trace rows changed: $engine"
}

$evaluationProcess = Get-TransportRouteClosureJson (
    Join-Path $passingRoot "evaluation\processes\00__complete_evaluator\process.json"
)
$evaluation = Get-TransportRouteClosureJson (
    Join-Path $passingRoot "evaluation\evaluation.json"
)
$result = Get-TransportRouteClosureJson (Join-Path $passingRoot "supervisor-result.json")
Assert-TransportRouteClosure (
    [int]$evaluationProcess.exit_code -eq 0 -and
    -not [bool]$evaluationProcess.timed_out -and
    [bool]$evaluation.route_execution_valid -and
    [int]$evaluation.declared_engine_count -eq 3 -and
    [int]$evaluation.execution_valid_engine_count -eq 3 -and
    @($evaluation.engine_evaluations | Where-Object {
        [bool]$_.execution_valid -and [int]$_.trace_row_count -eq 2
    }).Count -eq 3 -and
    -not [bool]$evaluation.physical_behavior_thresholds_applied -and
    [string]$evaluation.behavioral_outcome -ceq
        "not_evaluated_development_success_transport_ghost" -and
    [bool]$result.route_execution_valid -and
    [string]$result.outcome_class -ceq
        "execution_valid_development_success_transport_ghost" -and
    [int]$result.physical_worker_process_count -eq 3 -and
    [int]$result.execution_valid_worker_count -eq 3 -and
    [int]$result.complete_evaluator_invocation_count -eq 1
) "passing supervisor or evaluator result changed"

Assert-TransportRouteClosure (
    [bool]$closure.claims.development_success_transport_route_execution_valid -and
    [bool]$closure.claims.three_native_engine_success_receipt_transport_proved -and
    -not [bool]$closure.claims.turning_established -and
    -not [bool]$closure.claims.portable_basic_turning -and
    -not [bool]$closure.claims.cross_engine_equivalence -and
    -not [bool]$closure.claims.q_sdk_r23_satisfied -and
    -not [bool]$closure.claims.release_authorized -and
    [bool]$closure.next_work.transport_route_closed -and
    -not [bool]$closure.next_work.repeat_transport_smoke_required -and
    [bool]$closure.next_work.rapier_forward_displacement_behavior_development_required -and
    -not [bool]$closure.next_work.new_finite_turning_decision_authorized -and
    [string]$closure.release_score_before -ceq "10/25" -and
    [string]$closure.release_score_after -ceq "10/25"
) "claim or next-work boundary changed"

$support = Get-TransportRouteClosureJson $supportMatrixPath
$supportRoute = $support.locomotion_modes.three_engine_turning_success_transport_route_v2
$release = Get-TransportRouteClosureJson $releaseContractPath
$turningGate = @($release.gates | Where-Object { $_.gate_id -ceq "QSDK-R23" })
$releaseRoute = $turningGate[0].proof.current_transport_development_successor
$closureSha = Get-TransportRouteClosureSha256 $closurePath
$auditSha = Get-TransportRouteClosureSha256 $PSCommandPath
Assert-TransportRouteClosure (
    [string]$supportRoute.status -ceq
        "closed_complete_execution_valid_development_success_transport_ghost" -and
    [string]$supportRoute.route_closure_path -ceq
        "sdk/turning/three_engine_turning_success_transport_route_v2_closure.json" -and
    [string]$supportRoute.route_closure_raw_sha256 -ceq $closureSha -and
    [string]$supportRoute.route_closure_audit_raw_sha256 -ceq $auditSha -and
    [int]$supportRoute.retained_attempt_count -eq 3 -and
    [string]$supportRoute.passing_attempt_id -ceq
        "e6b716c2edc64e49989a0b597236893c" -and
    [bool]$supportRoute.development_ghost_execution_valid -and
    -not [bool]$supportRoute.turning_established -and
    -not [bool]$supportRoute.q_sdk_r23_satisfied -and
    [string]$releaseRoute.route_closure_raw_sha256 -ceq $closureSha -and
    [string]$releaseRoute.route_closure_audit_raw_sha256 -ceq $auditSha -and
    [bool]$releaseRoute.development_ghost_execution_valid -and
    -not [bool]$releaseRoute.turning_established -and
    -not [bool]$releaseRoute.q_sdk_r23_satisfied -and
    [string]$turningGate[0].proof.kind -ceq "missing"
) "live release projection changed"

Invoke-TransportRouteClosureAudit $attempt1AuditPath
Invoke-TransportRouteClosureAudit $attempt2AuditPath
Invoke-TransportRouteClosureAudit $zeroWorldRunnerPath

Write-Host (
    "[turning/transport] PASS v2 route closure: attempts=3 files=184 " +
    "bytes=1054449 worlds=9 traces=9 passing_engines=3 score=10/25"
)
