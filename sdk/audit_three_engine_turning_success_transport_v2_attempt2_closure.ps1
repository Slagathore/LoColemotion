#requires -Version 7.0

[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$closurePath = Join-Path $repoRoot (
    "sdk\turning\three_engine_turning_success_transport_route_v2_attempt2_closure.json"
)
$supportMatrixPath = Join-Path $repoRoot "sdk\release\quadruped_support_matrix.json"
$releaseContractPath = Join-Path $repoRoot "sdk\release\quadruped_release_contract.json"
$expectedRemote = "https://github.com/Slagathore/sporespore.git"
$sourceCommit = "4ec0e446e9e3790e929f6fb0a22815606f6948f2"
$sourceTree = "30827876c41c3eb04ad1540c755e0f76b5e973ad"

function Assert-TransportClosure([bool]$Condition, [string]$Message) {
    if (-not $Condition) {
        throw "[turning/transport] v2 attempt-2 closure audit: $Message"
    }
}

function Invoke-TransportClosureGit([string[]]$Arguments) {
    $lines = @(& git -C $repoRoot @Arguments 2>&1)
    Assert-TransportClosure ($LASTEXITCODE -eq 0) (
        "git $($Arguments -join ' ') failed: $($lines -join ' ')"
    )
    return ($lines -join "`n").Trim()
}

function Get-TransportClosureJson([string]$Path) {
    return Get-Content -LiteralPath $Path -Raw |
        ConvertFrom-Json -AsHashtable -Depth 100
}

function Get-TransportClosureSha256([string]$Path) {
    return "sha256:" + (
        Get-FileHash -LiteralPath $Path -Algorithm SHA256
    ).Hash.ToLowerInvariant()
}

Assert-TransportClosure (
    (Invoke-TransportClosureGit @("rev-parse", "--show-toplevel")) -ceq
        $repoRoot.Replace("\", "/")
) "repository root changed"
Assert-TransportClosure (
    (Invoke-TransportClosureGit @("remote", "get-url", "origin")) -ceq $expectedRemote
) "repository remote changed"
Assert-TransportClosure (
    (Invoke-TransportClosureGit @("rev-parse", "$sourceCommit^{tree}")) -ceq $sourceTree
) "source tree changed"
Assert-TransportClosure (Test-Path -LiteralPath $closurePath -PathType Leaf) (
    "closure is missing"
)

$closure = Get-TransportClosureJson $closurePath
Assert-TransportClosure (
    [string]$closure.schema_version -ceq
        "sporespore_three_engine_turning_success_transport_attempt_closure_v2" -and
    [string]$closure.closure_id -ceq
        "sporespore_three_engine_turning_success_transport_attempt2_closure_v2" -and
    [string]$closure.status -ceq
        "closed_consumed_infrastructure_invalid_complete_three_native_worlds_rapier_retention_question_class_omission" -and
    [string]$closure.route_id -ceq
        "sporespore_three_engine_turning_success_transport_route_v2"
) "closure identity changed"
Assert-TransportClosure (
    [string]$closure.ledger_scope.subsystem -ceq "turning" -and
    [string]$closure.ledger_scope.engine_scope -ceq "3e" -and
    [string]$closure.ledger_scope.question_class -ceq "development" -and
    [string]$closure.source_authority.source_commit -ceq $sourceCommit -and
    [string]$closure.source_authority.source_tree_git_oid -ceq $sourceTree -and
    [bool]$closure.source_authority.source_was_clean_pushed_and_live_equal
) "source or ledger authority changed"
Assert-TransportClosure (
    [bool]$closure.attempt.attempt_identity_consumed -and
    -not [bool]$closure.attempt.same_source_physical_rerun_allowed -and
    -not [bool]$closure.attempt.selective_engine_rerun_allowed -and
    [bool]$closure.attempt.distinct_corrected_clean_pushed_source_required
) "attempt consumption changed"

$attemptRoot = [IO.Path]::GetFullPath([string]$closure.attempt.attempt_root)
Assert-TransportClosure (Test-Path -LiteralPath $attemptRoot -PathType Container) (
    "attempt root is missing"
)
$records = @(
    Get-ChildItem -LiteralPath $attemptRoot -Recurse -File | ForEach-Object {
        [pscustomobject]@{
            Relative = [IO.Path]::GetRelativePath($attemptRoot, $_.FullName).Replace("\", "/")
            Path = $_.FullName
            Length = [long]$_.Length
        }
    } | Sort-Object -Property Relative
)
$manifestLines = @(
    foreach ($record in $records) {
        "$($record.Relative)`t$($record.Length)`t$(Get-TransportClosureSha256 $record.Path)"
    }
)
$canonicalManifest = ($manifestLines -join "`n") + "`n"
$manifestDigest = "sha256:" + [Convert]::ToHexString(
    [Security.Cryptography.SHA256]::HashData(
        [Text.Encoding]::UTF8.GetBytes($canonicalManifest)
    )
).ToLowerInvariant()
Assert-TransportClosure (
    $records.Count -eq [int]$closure.evidence_population.file_count -and
    [long](($records | Measure-Object -Property Length -Sum).Sum) -eq
        [long]$closure.evidence_population.total_byte_length -and
    $manifestDigest -ceq [string]$closure.evidence_population.canonical_manifest_sha256
) "attempt population changed"
foreach ($artifact in @($closure.evidence_population.selected_artifacts)) {
    $path = Join-Path $attemptRoot ([string]$artifact.relative_path)
    Assert-TransportClosure (Test-Path -LiteralPath $path -PathType Leaf) (
        "selected artifact is missing: $path"
    )
    Assert-TransportClosure (
        (Get-Item -LiteralPath $path).Length -eq [long]$artifact.byte_length -and
        (Get-TransportClosureSha256 $path) -ceq [string]$artifact.raw_sha256
    ) "selected artifact changed: $path"
}

$zeroWorld = Get-TransportClosureJson (Join-Path $attemptRoot "zero-world\complete-gate.json")
Assert-TransportClosure (
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
) "zero-world evidence changed"

$authorization = Get-TransportClosureJson (
    Join-Path $attemptRoot "authorization-preflight\complete-matrix.json"
)
Assert-TransportClosure (
    [int]$authorization.receipt_count -eq 3 -and
    @($authorization.worker_receipts | Where-Object {
        [bool]$_.authorization_passed -and [bool]$_.returned_before_model
    }).Count -eq 3 -and
    [bool]$authorization.all_workers_authorized_before_model -and
    [int]$authorization.model_construction_count -eq 0 -and
    [int]$authorization.world_attempt_count -eq 0 -and
    [int]$authorization.world_build_count -eq 0
) "authorization evidence changed"

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
    $terminalPath = Join-Path $attemptRoot $terminalRelativePaths[$index]
    $terminalRaw = Get-Content -LiteralPath $terminalPath -Raw
    $terminal = $terminalRaw | ConvertFrom-Json -AsHashtable -Depth 100
    $engine = $expectedEngines[$index]
    $expectedCas = $casByEngine[$engine]
    Assert-TransportClosure (
        [string]$terminal.schema_version -ceq
            "sporespore_three_engine_turning_success_transport_cell_report_v2" -and
        [string]$terminal.question_class -ceq "development" -and
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
    ) "native terminal changed: $engine"
    Assert-TransportClosure (
        (Get-TransportClosureSha256 ([string]$terminal.trace_artifact.payload_path)) -ceq
            [string]$expectedCas.artifact_sha256 -and
        (Get-Item -LiteralPath ([string]$terminal.trace_artifact.payload_path)).Length -eq
            [long]$expectedCas.byte_length -and
        (Get-TransportClosureSha256 ([string]$terminal.trace_artifact.manifest_path)) -ceq
            [string]$expectedCas.manifest_raw_sha256
    ) "CAS artifact changed: $engine"
    $traceRows = @(Get-Content -LiteralPath ([string]$terminal.trace_artifact.payload_path) |
        ForEach-Object { $_ | ConvertFrom-Json -AsHashtable -Depth 100 })
    Assert-TransportClosure (
        $traceRows.Count -eq 2 -and
        [int]$traceRows[0].semantic_step -eq 0 -and
        [int]$traceRows[1].semantic_step -eq 1
    ) "trace rows changed: $engine"
    if ($engine -ceq "rapier_parry") {
        Assert-TransportClosure (
            -not $terminal.trace_retention.ContainsKey("question_class") -and
            [string]$terminal.trace_retention.ledger_scope.question_class -ceq "development"
        ) "Rapier retention question-class omission changed"
    } else {
        Assert-TransportClosure (
            [string]$terminal.trace_retention.question_class -ceq "development"
        ) "native retention question class changed: $engine"
    }
    if ($engine -ceq "godot_jolt") {
        Assert-TransportClosure (
            [regex]::Matches($terminalRaw, '"byte_length"\s*:\s*5414(?![\.0-9])').Count -eq 2
        ) "Godot integer repair observation changed"
    }
}

$evaluationProcess = Get-TransportClosureJson (
    Join-Path $attemptRoot "evaluation\processes\00__complete_evaluator\process.json"
)
$evaluationError = (
    Get-Content -LiteralPath (
        Join-Path $attemptRoot "evaluation\processes\00__complete_evaluator\stderr.txt"
    ) -Raw
).Trim()
$result = Get-TransportClosureJson (Join-Path $attemptRoot "supervisor-result.json")
Assert-TransportClosure (
    [int]$evaluationProcess.exit_code -eq 1 -and
    -not [bool]$evaluationProcess.timed_out -and
    $evaluationError -ceq (
        "SPORESPORE_TURNING_ROUTE_EVALUATOR_ERROR " +
        "TURNING_ROUTE_TRACE_RETENTION_INVALID:rapier_parry"
    ) -and
    -not [bool]$result.route_execution_valid -and
    [string]$result.outcome_class -ceq
        "infrastructure_invalid_or_incomplete_development_success_transport_ghost" -and
    [int]$result.physical_worker_process_count -eq 3 -and
    [int]$result.execution_valid_worker_count -eq 3 -and
    [int]$result.complete_evaluator_invocation_count -eq 1 -and
    $null -eq $result.evaluation -and
    @($result.claims.Values | Where-Object { [bool]$_ }).Count -eq 0
) "supervisor or evaluator result changed"
Assert-TransportClosure (
    [bool]$closure.non_authoritative_diagnostic.performed -and
    -not [bool]$closure.non_authoritative_diagnostic.retained_attempt_modified -and
    -not [bool]$closure.non_authoritative_diagnostic.authoritative_evidence -and
    -not [bool]$closure.non_authoritative_diagnostic.changes_attempt_outcome -and
    -not [bool]$closure.non_authoritative_diagnostic.release_or_behavior_claim_supported -and
    -not [bool]$closure.failure_interpretation.physics_failure -and
    -not [bool]$closure.failure_interpretation.valid_transport_positive -and
    -not [bool]$closure.claims.development_ghost_execution_valid
) "diagnostic or non-claim boundary changed"

$support = Get-TransportClosureJson $supportMatrixPath
$supportRoute = $support.locomotion_modes.three_engine_turning_success_transport_route_v2
$release = Get-TransportClosureJson $releaseContractPath
$turningGate = @($release.gates | Where-Object { $_.gate_id -ceq "QSDK-R23" })
$releaseRoute = $turningGate[0].proof.current_transport_development_successor
$closureSha = Get-TransportClosureSha256 $closurePath
$auditSha = Get-TransportClosureSha256 $PSCommandPath
Assert-TransportClosure (
    [string]$supportRoute.second_physical_smoke_closure_path -ceq
        "sdk/turning/three_engine_turning_success_transport_route_v2_attempt2_closure.json" -and
    [string]$supportRoute.second_physical_smoke_closure_raw_sha256 -ceq $closureSha -and
    [string]$supportRoute.second_physical_smoke_closure_audit_raw_sha256 -ceq $auditSha -and
    [string]$supportRoute.rapier_retention_question_class_repair_id -ceq
        "rapier_trace_retention_question_class_projection_v1" -and
    [string]$releaseRoute.second_physical_smoke_closure_raw_sha256 -ceq $closureSha -and
    [string]$releaseRoute.second_physical_smoke_closure_audit_raw_sha256 -ceq $auditSha -and
    [string]$releaseRoute.rapier_retention_question_class_repair_id -ceq
        "rapier_trace_retention_question_class_projection_v1" -and
    [string]$turningGate[0].proof.kind -ceq "missing"
) "live release projection changed"

Write-Host (
    "[turning/transport] PASS v2 attempt-2 closure: files=61 bytes=349584 " +
    "worlds=3 traces=3 native_success=3 evaluator_valid=0 " +
    "failure=rapier_retention_question_class_omission score=10/25"
)
