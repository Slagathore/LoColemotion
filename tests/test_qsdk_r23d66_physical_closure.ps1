#requires -Version 7.0

[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$evidenceRoot = "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence"
$artifactRoot = Join-Path $evidenceRoot "artifacts\sha256"
$qualificationRoot = Join-Path $evidenceRoot (
    "qsdk-r23d66-qualification-20260825T221128Z-2d57cac4-scoped-symlink"
)
$attemptRoot = Join-Path $evidenceRoot (
    "qsdk-r23d66-physical-20260825T221718Z-2d57cac4-adopted"
)
$closurePath = Join-Path $repoRoot (
    "sdk\turning\r23d66_production_route_three_engine_turning_" +
    "validation_closure_v1.json"
)
$auditPath = $PSCommandPath
$releaseContractPath = Join-Path $repoRoot "sdk\release\quadruped_release_contract.json"
$supportMatrixPath = Join-Path $repoRoot "sdk\release\quadruped_support_matrix.json"
$sourceCommit = "2d57cac49744337a80e4558bc1a44c44cf631bed"
$sourceTree = "39615ec94f227c94836d19d49d7420f5c2bf9f76"
$campaignId = (
    "QSDK-R23D66-PRODUCTION-ROUTE-QUALIFIED-SELECTED-PROFILE-" +
    "THREE-ENGINE-TURNING-VALIDATION"
)
$closedStatus = (
    "closed_consumed_invalid_incomplete_at_nine_cell_authorization_" +
    "preflight_before_any_world_mujoco_receipt_schema_mismatch"
)
$exactReceiptFailure = (
    "The property 'ok' cannot be found on this object. " +
    "Verify that the property exists."
)
$expectedCellIds = @(
    "r23d66__godot_jolt__s23179__reference_zero",
    "r23d66__godot_jolt__s23179__positive_heading",
    "r23d66__godot_jolt__s23179__negative_heading",
    "r23d66__rapier_parry__s23179__reference_zero",
    "r23d66__rapier_parry__s23179__positive_heading",
    "r23d66__rapier_parry__s23179__negative_heading",
    "r23d66__mujoco__s23179__reference_zero",
    "r23d66__mujoco__s23179__positive_heading",
    "r23d66__mujoco__s23179__negative_heading"
)

function Assert-R23D66Closure([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "QSDK-R23D66 CLOSURE: $Message" }
}

function Get-R23D66Sha256([string]$Path) {
    return "sha256:" + (
        Get-FileHash -LiteralPath $Path -Algorithm SHA256
    ).Hash.ToLowerInvariant()
}

function Get-R23D66BytesSha256([byte[]]$Bytes) {
    return "sha256:" + [Convert]::ToHexString(
        [Security.Cryptography.SHA256]::HashData($Bytes)
    ).ToLowerInvariant()
}

function Invoke-R23D66Git([string[]]$Arguments) {
    $lines = @(& git -C $repoRoot @Arguments 2>&1)
    Assert-R23D66Closure ($LASTEXITCODE -eq 0) (
        "git $($Arguments -join ' ') failed: $($lines -join ' ')"
    )
    return ($lines -join "`n").Trim()
}

function Assert-R23D66RetainedBinding($Binding) {
    $path = [IO.Path]::GetFullPath([string]$Binding.path)
    Assert-R23D66Closure (
        (Test-Path -LiteralPath $path -PathType Leaf) -and
        (Get-Item -LiteralPath $path).Length -eq [long]$Binding.byte_length -and
        (Get-R23D66Sha256 $path) -ceq [string]$Binding.raw_sha256
    ) "retained binding changed: $path"
}

function Assert-R23D66CasPayload([string]$Path) {
    $digest = (Get-R23D66Sha256 $Path).Substring(7)
    $payload = Join-Path $artifactRoot "$digest\payload.bin"
    Assert-R23D66Closure (
        (Test-Path -LiteralPath $payload -PathType Leaf) -and
        (Get-Item -LiteralPath $payload).Length -eq (Get-Item -LiteralPath $Path).Length -and
        (Get-R23D66Sha256 $payload) -ceq "sha256:$digest"
    ) "CAS payload changed or is missing: $Path"
}

function Test-R23D66ClosureVector($Value) {
    return (
        [string]$Value.schema_version -ceq
            "sporespore_qsdk_r23d66_production_route_three_engine_turning_validation_closure_v1" -and
        [string]$Value.status -ceq $closedStatus -and
        [string]$Value.campaign_id -ceq $campaignId -and
        [string]$Value.gate_id -ceq "QSDK-R23D66" -and
        [string]$Value.release_gate_id -ceq "QSDK-R23" -and
        [string]$Value.ledger_scope.subsystem -ceq "turning" -and
        [string]$Value.ledger_scope.engine_scope -ceq "3e" -and
        [string]$Value.ledger_scope.question_class -ceq "finite_decision" -and
        [string]$Value.physical_question_class -ceq "finite_decision" -and
        [string]$Value.observed_failure_question_class -ceq "integration_schema_failure" -and
        [string]$Value.source.commit -ceq $sourceCommit -and
        [string]$Value.source.tree_git_oid -ceq $sourceTree -and
        [string]$Value.source.supervisor_git_blob_oid -ceq
            "714b0ca4f0ae69dcad722df86ab8c1866ac327d6" -and
        [string]$Value.source.mujoco_route_git_blob_oid -ceq
            "a350719a79e2419f51cc3921233541958807b67a" -and
        [string]$Value.source.mujoco_receipt_composer_git_blob_oid -ceq
            "6c4fb2052adda03d32d3309129b75369fed897f6" -and
        [bool]$Value.source.clean_pushed_live_equal_at_launch -and
        [int]$Value.qualification.complete_retained_file_count -eq 50 -and
        [long]$Value.qualification.complete_retained_byte_count -eq 491079 -and
        [int]$Value.qualification.global_gate_count -eq 12 -and
        [int]$Value.qualification.lineage_gate_count -eq 1 -and
        [int]$Value.qualification.campaign_role_gate_count -eq 3 -and
        [int]$Value.qualification.executed_gate_count -eq 16 -and
        [bool]$Value.qualification.qualification_passed -and
        [bool]$Value.qualification.adoption_passed -and
        [bool]$Value.qualification.physical_launch_prerequisite_satisfied -and
        [int]$Value.qualification.world_build_count -eq 0 -and
        -not [bool]$Value.qualification.physical_acceptance_authority -and
        [string]$Value.attempt.attempt_id -ceq "e7383c544f114ba1ace1f94a78707a11" -and
        [int]$Value.attempt.campaign_seed -eq 23179 -and
        [bool]$Value.attempt.campaign_identity_consumed -and
        [bool]$Value.attempt.held_out_condition_consumed -and
        -not [bool]$Value.attempt.same_identity_rerun_allowed -and
        -not [bool]$Value.attempt.replacement_or_selective_rerun_allowed -and
        -not [bool]$Value.attempt.physical_outcome_exposed -and
        -not [bool]$Value.attempt.behavioral_measurement_exposed -and
        [int]$Value.frozen_input_population.source_binding_count -eq 201 -and
        [int]$Value.frozen_input_population.runtime_binding_count -eq 8 -and
        [int]$Value.frozen_input_population.complete_content_addressed_input_count -eq 210 -and
        [string]$Value.frozen_input_population.cargo_and_rustc_content_byte_source -ceq
            "C:/Users/Cole/.cargo/bin/rustup.exe" -and
        [int]$Value.retained_evidence.complete_file_population_count -eq 22 -and
        [long]$Value.retained_evidence.complete_file_population_byte_count -eq 484991 -and
        [int]$Value.retained_evidence.retained_unique_digest_count -eq 14 -and
        [int]$Value.retained_evidence.explicitly_cas_backed_file_count -eq 21 -and
        [int]$Value.retained_evidence.non_cas_retained_file_count -eq 1 -and
        [int]$Value.retained_evidence.canonical_population_manifest_byte_length -eq 3174 -and
        [string]$Value.retained_evidence.canonical_population_manifest_sha256 -ceq
            "sha256:a2099f6c514d7ce9c0c33fa8428147c38b487bae029c2174111b7ec0093ded75" -and
        [int]$Value.authorization_population.retained_receipt_count -eq 9 -and
        [int]$Value.authorization_population.accepted_receipt_count -eq 6 -and
        [int]$Value.authorization_population.rejected_receipt_count -eq 3 -and
        [int]$Value.authorization_population.mujoco_rejected_receipt_count -eq 3 -and
        [bool]$Value.authorization_population.all_worker_receipts_reported_authorization_passed -and
        [bool]$Value.authorization_population.all_worker_receipts_reported_zero_world_builds -and
        -not [bool]$Value.authorization_population.complete_matrix_passed -and
        [int]$Value.authorization_population.physical_worker_process_count -eq 0 -and
        [int]$Value.authorization_population.retained_physical_cell_count -eq 0 -and
        [int]$Value.authorization_population.complete_evaluator_invocation_count -eq 0 -and
        [string]$Value.failure_mechanism.class -ceq
            "supervisor_mujoco_authorization_receipt_schema_mismatch" -and
        [string]$Value.failure_mechanism.supervisor_required_field -ceq "ok" -and
        [string]$Value.failure_mechanism.mujoco_receipt_missing_field -ceq "ok" -and
        [string]$Value.failure_mechanism.exact_failure_message -ceq $exactReceiptFailure -and
        -not [bool]$Value.failure_mechanism.physics_opened -and
        -not [bool]$Value.failure_mechanism.behavior_thresholds_applied -and
        -not [bool]$Value.failure_mechanism.turning_evaluator_invoked -and
        -not [bool]$Value.official_result.scientific_result_exists -and
        -not [bool]$Value.official_result.physical_result_exists -and
        -not [bool]$Value.official_result.q_sdk_r23_satisfied -and
        [string]$Value.official_result.release_score_before -ceq "10/25" -and
        [string]$Value.official_result.release_score_after -ceq "10/25" -and
        -not [bool]$Value.official_result.release_score_changed -and
        [bool]$Value.successor_boundary.distinct_successor_required -and
        -not [bool]$Value.successor_boundary.same_seed_reuse_allowed -and
        -not [bool]$Value.successor_boundary.selective_completion_allowed -and
        [int]@($Value.successor_boundary.minimum_integration_repair_population).Count -eq 4 -and
        [bool]$Value.claims.campaign_closed -and
        [bool]$Value.claims.retained_evidence_complete -and
        [bool]$Value.claims.campaign_identity_consumed -and
        -not [bool]$Value.claims.historical_result_reinterpreted -and
        -not [bool]$Value.claims.turning_claimed -and
        -not [bool]$Value.claims.physical_acceptance_authority
    )
}

Assert-R23D66Closure (
    (Invoke-R23D66Git @("rev-parse", "--show-toplevel")) -ceq
        $repoRoot.Replace("\", "/") -and
    (Invoke-R23D66Git @("remote", "get-url", "origin")) -ceq
        "https://github.com/Slagathore/sporespore.git"
) "repository identity changed"
foreach ($path in @($qualificationRoot, $attemptRoot, $closurePath, $auditPath)) {
    Assert-R23D66Closure (Test-Path -LiteralPath $path) "path is missing: $path"
}

$closure = Get-Content -LiteralPath $closurePath -Raw |
    ConvertFrom-Json -AsHashtable -Depth 100
Assert-R23D66Closure (Test-R23D66ClosureVector $closure) "closure claim vector changed"
Assert-R23D66Closure (
    (Invoke-R23D66Git @("rev-parse", "$sourceCommit^{tree}")) -ceq $sourceTree -and
    (Invoke-R23D66Git @("rev-parse", "$sourceCommit`:sdk/run_qsdk_r23d66_supervisor.ps1")) -ceq
        [string]$closure.source.supervisor_git_blob_oid -and
    (Invoke-R23D66Git @("rev-parse", "$sourceCommit`:sdk/adapters/mujoco/sporespore_mujoco_adapter/qsdk_r23d66_turning_route.py")) -ceq
        [string]$closure.source.mujoco_route_git_blob_oid -and
    (Invoke-R23D66Git @("rev-parse", "$sourceCommit`:sdk/adapters/mujoco/sporespore_mujoco_adapter/qsdk_r23d65_selected_profile_turning.py")) -ceq
        [string]$closure.source.mujoco_receipt_composer_git_blob_oid
) "consumed source identity changed"
$sourceSupervisor = Invoke-R23D66Git @(
    "show", "$sourceCommit`:sdk/run_qsdk_r23d66_supervisor.ps1"
)
$sourceComposer = Invoke-R23D66Git @(
    "show", "$sourceCommit`:sdk/adapters/mujoco/sporespore_mujoco_adapter/qsdk_r23d65_selected_profile_turning.py"
)
Assert-R23D66Closure (
    $sourceSupervisor -cmatch '\[bool\]\$authorizationReceipt\.ok' -and
    $sourceComposer -cmatch '"authorization_passed"\s*:\s*True' -and
    $sourceComposer -cnotmatch '"ok"\s*:'
) "observed receipt-schema mismatch source changed"

Assert-R23D66RetainedBinding $closure.qualification.attestation
Assert-R23D66RetainedBinding $closure.qualification.adoption
$qualificationFiles = @(Get-ChildItem -LiteralPath $qualificationRoot -Recurse -File)
Assert-R23D66Closure (
    $qualificationFiles.Count -eq 50 -and
    [long](($qualificationFiles | Measure-Object Length -Sum).Sum) -eq 491079
) "qualification retained population changed"
$attestation = Get-Content -LiteralPath ([string]$closure.qualification.attestation.path) -Raw |
    ConvertFrom-Json -AsHashtable -Depth 100
$adoption = Get-Content -LiteralPath ([string]$closure.qualification.adoption.path) -Raw |
    ConvertFrom-Json -AsHashtable -Depth 100
Assert-R23D66Closure (
    [string]$attestation.status -ceq "campaign_local_godot_including_qualification_passed" -and
    [string]$attestation.source.commit -ceq $sourceCommit -and
    [bool]$attestation.source.clean_pushed_live -and
    [int]$attestation.global_gate_count -eq 12 -and
    [int]$attestation.lineage_gate_count -eq 1 -and
    [int]$attestation.campaign_gate_count -eq 3 -and
    [int]$attestation.executed_gate_count -eq 16 -and
    [bool]$attestation.all_gates_executed -and
    [bool]$attestation.all_gate_streams_content_addressed -and
    [int]$attestation.declared_physical_world_count -eq 9 -and
    -not [bool]$attestation.claims.physical_campaign_executed -and
    -not [bool]$attestation.claims.turning_acceptance -and
    [string]$adoption.status -ceq
        "commissioned_campaign_local_qualification_adopted_for_physical_launch" -and
    [string]$adoption.source_commit -ceq $sourceCommit -and
    [bool]$adoption.physical_launch_prerequisite_satisfied -and
    -not [bool]$adoption.physical_acceptance_authority -and
    -not [bool]$adoption.release_authority
) "qualification or adoption semantics changed"

$attemptFiles = @(Get-ChildItem -LiteralPath $attemptRoot -Recurse -File |
    Sort-Object { $_.FullName.Substring($attemptRoot.Length + 1).Replace("\", "/") })
$relativePaths = @($attemptFiles | ForEach-Object {
    $_.FullName.Substring($attemptRoot.Length + 1).Replace("\", "/")
})
Assert-R23D66Closure (
    $attemptFiles.Count -eq 22 -and
    [long](($attemptFiles | Measure-Object Length -Sum).Sum) -eq 484991 -and
    ($relativePaths -join "`n") -ceq
        (@($closure.retained_evidence.ordered_relative_paths) -join "`n")
) "complete retained physical population changed"
$manifestText = ($attemptFiles | ForEach-Object {
    $relative = $_.FullName.Substring($attemptRoot.Length + 1).Replace("\", "/")
    "$relative`t$($_.Length)`t$(Get-R23D66Sha256 $_.FullName)`n"
}) -join ""
$manifestBytes = [Text.UTF8Encoding]::new($false).GetBytes($manifestText)
$uniqueDigests = @($attemptFiles | ForEach-Object {
    Get-R23D66Sha256 $_.FullName
} | Sort-Object -Unique)
Assert-R23D66Closure (
    $manifestBytes.Length -eq 3174 -and
    (Get-R23D66BytesSha256 $manifestBytes) -ceq
        "sha256:a2099f6c514d7ce9c0c33fa8428147c38b487bae029c2174111b7ec0093ded75" -and
    $uniqueDigests.Count -eq 14
) "canonical retained-population manifest changed"
foreach ($file in $attemptFiles) {
    $relative = $file.FullName.Substring($attemptRoot.Length + 1).Replace("\", "/")
    if ($relative -cne "completion.json") { Assert-R23D66CasPayload $file.FullName }
}

$freeze = Get-Content -LiteralPath ([string]$closure.attempt.physical_freeze.path) -Raw |
    ConvertFrom-Json -AsHashtable -Depth 100
$attempt = Get-Content -LiteralPath ([string]$closure.attempt.attempt_authorization.path) -Raw |
    ConvertFrom-Json -AsHashtable -Depth 100
$authorization = Get-Content -LiteralPath ([string]$closure.attempt.authorization_preflight.path) -Raw |
    ConvertFrom-Json -AsHashtable -Depth 100
$completion = Get-Content -LiteralPath ([string]$closure.attempt.completion.path) -Raw |
    ConvertFrom-Json -AsHashtable -Depth 100
foreach ($binding in @(
    $closure.attempt.physical_freeze,
    $closure.attempt.attempt_authorization,
    $closure.attempt.authorization_preflight,
    $closure.attempt.completion
)) { Assert-R23D66RetainedBinding $binding }
Assert-R23D66Closure (
    [string]$freeze.status -ceq "frozen_supervisor_only_physical_authorized" -and
    [string]$freeze.source_commit -ceq $sourceCommit -and
    [string]$freeze.source_tree_git_oid -ceq $sourceTree -and
    [int]@($freeze.implementation_dependency_digests.Keys).Count -eq 201 -and
    [int]@($freeze.source_bindings).Count -eq 201 -and
    [int]@($freeze.runtime_artifacts).Count -eq 3 -and
    [int]@($freeze.external_runtime_bindings).Count -eq 5 -and
    [int]@($freeze.content_addressed_inputs.source_bindings).Count -eq 201 -and
    [int]@($freeze.content_addressed_inputs.runtime_bindings).Count -eq 8 -and
    [int]$freeze.declared_world_count -eq 9 -and
    [bool]$freeze.physical_execution_authorized -and
    -not [bool]$freeze.physical_acceptance_authority -and
    (@($freeze.ordered_cell_ids) -join "`n") -ceq ($expectedCellIds -join "`n")
) "physical freeze changed"
$cargoBinding = @($freeze.external_runtime_bindings | Where-Object {
    [string]$_.name -ceq "cargo_host"
})[0]
$rustcBinding = @($freeze.external_runtime_bindings | Where-Object {
    [string]$_.name -ceq "rustc_host"
})[0]
Assert-R23D66Closure (
    [IO.Path]::GetFullPath([string]$cargoBinding.content_byte_source_path) -ceq
        "C:\Users\Cole\.cargo\bin\rustup.exe" -and
    [IO.Path]::GetFullPath([string]$rustcBinding.content_byte_source_path) -ceq
        "C:\Users\Cole\.cargo\bin\rustup.exe" -and
    [string]$cargoBinding.raw_sha256 -ceq
        "sha256:86478e53f769379d7f0ebfa7c9aa97cb76ca92233f79aa2cc0dbee2efaac73c7" -and
    [string]$rustcBinding.raw_sha256 -ceq [string]$cargoBinding.raw_sha256
) "scoped Rustup content-byte bindings changed"
Assert-R23D66Closure (
    [string]$attempt.attempt_id -ceq "e7383c544f114ba1ace1f94a78707a11" -and
    [string]$attempt.source_commit -ceq $sourceCommit -and
    [bool]$attempt.physical_execution_authorized -and
    [bool]$attempt.single_use_supervisor_authorization -and
    [bool]$attempt.one_shot_attempt_unconsumed -and
    [bool]$attempt.operation_lock_held -and
    [bool]$attempt.campaign_attestation_adoption_valid -and
    [bool]$attempt.content_addressed_inputs_retained -and
    -not [bool]$attempt.physical_acceptance_authority
) "attempt authorization changed"

Assert-R23D66Closure (
    [int]$authorization.receipt_count -eq 9 -and
    [int]$authorization.pass_count -eq 6 -and
    -not [bool]$authorization.complete_matrix_passed -and
    [int]$authorization.model_construction_count -eq 0 -and
    [int]$authorization.world_attempt_count -eq 0 -and
    [int]$authorization.world_build_count -eq 0 -and
    (@($authorization.ordered_receipts.cell_id) -join "`n") -ceq
        ($expectedCellIds -join "`n")
) "authorization population changed"
$mujocoFailures = 0
foreach ($receipt in @($authorization.ordered_receipts)) {
    Assert-R23D66Closure (
        [int]$receipt.process.exit_code -eq 0 -and
        -not [bool]$receipt.process.timed_out -and
        [bool]$receipt.worker_receipt.authorization_passed -and
        [bool]$receipt.worker_receipt.returned_before_model -and
        [int]$receipt.worker_receipt.model_construction_count -eq 0 -and
        [int]$receipt.worker_receipt.world_attempt_count -eq 0 -and
        [int]$receipt.worker_receipt.world_build_count -eq 0
    ) "worker authorization receipt changed: $($receipt.cell_id)"
    if ([string]$receipt.engine_id -ceq "mujoco") {
        $mujocoFailures += 1
        Assert-R23D66Closure (
            -not [bool]$receipt.valid -and
            [string]$receipt.failure_message -ceq $exactReceiptFailure -and
            -not $receipt.worker_receipt.Contains("ok")
        ) "MuJoCo schema failure changed: $($receipt.cell_id)"
    } else {
        Assert-R23D66Closure (
            [bool]$receipt.valid -and
            $receipt.worker_receipt.Contains("ok") -and
            [bool]$receipt.worker_receipt.ok
        ) "accepted authorization receipt changed: $($receipt.cell_id)"
    }
}
Assert-R23D66Closure ($mujocoFailures -eq 3) "MuJoCo failure population changed"
Assert-R23D66Closure (
    [string]$completion.status -ceq "invalid_or_incomplete_first_attempt" -and
    [string]$completion.attempt_id -ceq [string]$attempt.attempt_id -and
    [int]$completion.retained_cell_count -eq 0 -and
    [bool]$completion.one_shot_attempt_consumed -and
    -not [bool]$completion.replacement_or_selective_rerun_permitted -and
    [string]$completion.failure_message -ceq
        "QSDK-R23D66: complete nine-cell physical authorization preflight did not pass" -and
    -not [bool]$completion.physical_acceptance_authority -and
    -not (Test-Path -LiteralPath (Join-Path $attemptRoot "cells")) -and
    -not (Test-Path -LiteralPath (Join-Path $attemptRoot "traces")) -and
    -not (Test-Path -LiteralPath (Join-Path $attemptRoot "pending-traces"))
) "terminal zero-world completion changed"

$release = Get-Content -LiteralPath $releaseContractPath -Raw |
    ConvertFrom-Json -AsHashtable -Depth 100
$support = Get-Content -LiteralPath $supportMatrixPath -Raw |
    ConvertFrom-Json -AsHashtable -Depth 100
$turningGate = @($release.gates | Where-Object {
    [string]$_.gate_id -ceq "QSDK-R23"
})
$releaseSuccessor = $turningGate[0].proof.
    prospective_r23d66_production_route_three_engine_turning_validation
$supportSuccessor = $support.locomotion_modes.three_engine_turning_production_route.
    prospective_held_out_successor
foreach ($successor in @($releaseSuccessor, $supportSuccessor)) {
    Assert-R23D66Closure (
        [string]$successor.current_lifecycle_status -ceq $closedStatus -and
        [string]$successor.current_lifecycle.closure_path -ceq
            "sdk/turning/r23d66_production_route_three_engine_turning_validation_closure_v1.json" -and
        [string]$successor.current_lifecycle.closure_raw_sha256 -ceq
            (Get-R23D66Sha256 $closurePath) -and
        [string]$successor.current_lifecycle.closure_audit_path -ceq
            "tests/test_qsdk_r23d66_physical_closure.ps1" -and
        [string]$successor.current_lifecycle.closure_audit_raw_sha256 -ceq
            (Get-R23D66Sha256 $auditPath) -and
        [int]$successor.current_lifecycle.authorization_receipt_count -eq 9 -and
        [int]$successor.current_lifecycle.authorization_pass_count -eq 6 -and
        [int]$successor.current_lifecycle.model_construction_count -eq 0 -and
        [int]$successor.current_lifecycle.world_attempt_count -eq 0 -and
        [int]$successor.current_lifecycle.world_build_count -eq 0 -and
        [bool]$successor.current_lifecycle.campaign_identity_consumed -and
        -not [bool]$successor.current_lifecycle.q_sdk_r23_satisfied -and
        -not [bool]$successor.current_lifecycle.physical_acceptance_authority
    ) "release lifecycle closure changed"
}

$mutationControls = 0
foreach ($mutation in @(
    @{ path = "status"; value = "passing" },
    @{ path = "attempt.physical_outcome_exposed"; value = $true },
    @{ path = "authorization_population.accepted_receipt_count"; value = 9 },
    @{ path = "failure_mechanism.physics_opened"; value = $true },
    @{ path = "official_result.q_sdk_r23_satisfied"; value = $true },
    @{ path = "claims.turning_claimed"; value = $true }
)) {
    $copy = $closure | ConvertTo-Json -Depth 100 |
        ConvertFrom-Json -AsHashtable -Depth 100
    $parts = [string]$mutation.path -split '\.'
    $target = $copy
    for ($index = 0; $index -lt $parts.Count - 1; $index++) {
        $target = $target[$parts[$index]]
    }
    $target[$parts[-1]] = $mutation.value
    Assert-R23D66Closure (-not (Test-R23D66ClosureVector $copy)) (
        "mutation was accepted: $($mutation.path)"
    )
    $mutationControls += 1
}

Write-Output (
    "[turning/3e] PASS R23D66 immutable physical closure: " +
    "qualification=16/16 adoption=True authorization=6/9 " +
    "mujoco_schema_failures=3 models=0 worlds=0 files=22 bytes=484991 " +
    "mutations=$mutationControls turning=False QSDK-R23=False score=10/25"
)
