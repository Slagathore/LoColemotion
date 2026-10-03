#requires -Version 7.0

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$closurePath = Join-Path $repoRoot (
    "sdk\turning\r23d33_native_r23d29_transfer_closure_v1.json"
)
$artifactRoot = Join-Path (
    "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence"
) "artifacts\sha256"
$sourceCommit = "c0282f2b26e112f26cebf9e3f01462cb6bf5c480"
$expectedGodotFailures = @(
    "ADAPTER_BALANCED_WAVE_RECEIPT_INVALID",
    "ADAPTER_BALANCED_WAVE_MEMORY_VERSION_MISMATCH",
    "ADAPTER_AUTHORITY_STEP_INVALID:ADAPTER_BALANCED_WAVE_SHADOW_INVALID"
)

function Assert-R23D33([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "QSDK-R23D33 CLOSURE: $Message" }
}

function Get-Sha256([string]$Path) {
    return "sha256:" + (
        Get-FileHash -LiteralPath $Path -Algorithm SHA256
    ).Hash.ToLowerInvariant()
}

function Assert-Artifact($Record) {
    $path = [string]$Record.path
    Assert-R23D33 (Test-Path -LiteralPath $path -PathType Leaf) (
        "retained artifact missing: $path"
    )
    Assert-R23D33 ((Get-Item -LiteralPath $path).Length -eq [long]$Record.byte_length) (
        "retained artifact length changed: $path"
    )
    Assert-R23D33 ((Get-Sha256 $path) -ceq [string]$Record.sha256) (
        "retained artifact digest changed: $path"
    )
}

function Get-CasPayload([string]$Sha256) {
    Assert-R23D33 ($Sha256 -cmatch '^sha256:[0-9a-f]{64}$') (
        "invalid CAS digest: $Sha256"
    )
    return Join-Path (
        Join-Path $artifactRoot $Sha256.Substring(7)
    ) "payload.bin"
}

function Assert-Cas([string]$Sha256, [long]$ByteLength) {
    $path = Get-CasPayload $Sha256
    Assert-R23D33 (Test-Path -LiteralPath $path -PathType Leaf) (
        "CAS payload missing: $Sha256"
    )
    Assert-R23D33 ((Get-Item -LiteralPath $path).Length -eq $ByteLength) (
        "CAS payload length changed: $Sha256"
    )
    Assert-R23D33 ((Get-Sha256 $path) -ceq $Sha256) (
        "CAS payload digest changed: $Sha256"
    )
    return $path
}

function Read-CasJson([string]$Sha256, [long]$ByteLength) {
    $path = Assert-Cas $Sha256 $ByteLength
    return Get-Content -Raw -LiteralPath $path |
        ConvertFrom-Json -Depth 100
}

$closure = Get-Content -Raw -LiteralPath $closurePath |
    ConvertFrom-Json -Depth 100

Assert-R23D33 (
    (git -C $repoRoot rev-parse --show-toplevel).Trim().Replace('/', '\') -ceq
        $repoRoot -and
    (git -C $repoRoot remote get-url origin).Trim() -ceq
        "https://github.com/Slagathore/sporespore.git" -and
    [string]$closure.schema_version -ceq
        "sporespore_qsdk_r23d33_native_r23d29_transfer_closure_v1" -and
    [string]$closure.status -ceq
        "closed_consumed_invalid_complete_implementation_failures" -and
    [string]$closure.campaign_id -ceq
        "QSDK-R23D33-NATIVE-R23D29-TWO-ENGINE-TRANSFER" -and
    [string]$closure.gate_id -ceq "QSDK-R23D33" -and
    [string]$closure.source_commit -ceq $sourceCommit -and
    (git -C $repoRoot rev-parse "${sourceCommit}^{tree}").Trim() -ceq
        [string]$closure.source_tree_git_oid -and
    [string]$closure.attempt_id -ceq "577b07a4557c4827b90de9dac32a2959" -and
    [int]$closure.campaign_seed -eq 21507 -and
    [bool]$closure.identity_consumed -and
    -not [bool]$closure.same_identity_rerun_allowed -and
    -not [bool]$closure.selective_rerun_allowed
) "closure identity changed"

Assert-Artifact ([pscustomobject]@{
    path = $closure.qualification.attestation_path
    sha256 = $closure.qualification.attestation_sha256
    byte_length = $closure.qualification.attestation_byte_length
})
Assert-Artifact ([pscustomobject]@{
    path = $closure.qualification.adoption_path
    sha256 = $closure.qualification.adoption_sha256
    byte_length = $closure.qualification.adoption_byte_length
})
foreach ($name in @(
    "physical_freeze", "attempt_authorization", "terminal_manifest",
    "complete_evaluation", "report", "completion"
)) {
    Assert-Artifact $closure.physical_evidence.$name
}

$attestation = Get-Content -Raw -LiteralPath (
    [string]$closure.qualification.attestation_path
) | ConvertFrom-Json -Depth 100
$adoption = Get-Content -Raw -LiteralPath (
    [string]$closure.qualification.adoption_path
) | ConvertFrom-Json -Depth 100
Assert-R23D33 (
    [string]$attestation.source.commit -ceq $sourceCommit -and
    [string]$attestation.source.tree_git_oid -ceq
        [string]$closure.source_tree_git_oid -and
    [bool]$attestation.source.clean_pushed_live -and
    [int]$attestation.global_gate_count -eq 12 -and
    [int]$attestation.lineage_gate_count -eq 2 -and
    [int]$attestation.campaign_gate_count -eq 3 -and
    [int]$attestation.executed_gate_count -eq 17 -and
    [bool]$attestation.all_gates_executed -and
    [string]$adoption.source_commit -ceq $sourceCommit -and
    [bool]$adoption.physical_launch_prerequisite_satisfied -and
    -not [bool]$adoption.physical_acceptance_authority
) "qualification receipt changed"

$freeze = Get-Content -Raw -LiteralPath (
    [string]$closure.physical_evidence.physical_freeze.path
) | ConvertFrom-Json -Depth 100
$attempt = Get-Content -Raw -LiteralPath (
    [string]$closure.physical_evidence.attempt_authorization.path
) | ConvertFrom-Json -Depth 100
$terminalManifest = Get-Content -Raw -LiteralPath (
    [string]$closure.physical_evidence.terminal_manifest.path
) | ConvertFrom-Json -Depth 100
$evaluation = Get-Content -Raw -LiteralPath (
    [string]$closure.physical_evidence.complete_evaluation.path
) | ConvertFrom-Json -Depth 100
$report = Get-Content -Raw -LiteralPath (
    [string]$closure.physical_evidence.report.path
) | ConvertFrom-Json -Depth 100
$completion = Get-Content -Raw -LiteralPath (
    [string]$closure.physical_evidence.completion.path
) | ConvertFrom-Json -Depth 100

Assert-R23D33 (
    [string]$freeze.source_commit -ceq $sourceCommit -and
    [string]$freeze.source_tree_git_oid -ceq [string]$closure.source_tree_git_oid -and
    [int]$freeze.declared_world_count -eq 6 -and
    [bool]$freeze.serial_execution_required -and
    [bool]$freeze.all_cells_run_regardless_of_intermediate_outcome -and
    -not [bool]$freeze.terminal_restoration_or_taper_invoked -and
    [bool]$freeze.source_checkout_bytes_equal_git_blobs -and
    [bool]$freeze.reproducible_runtime_materialization_passed -and
    [bool]$freeze.complete_zero_world_gate_passed -and
    [int]$freeze.zero_world_receipt.world_attempt_count -eq 0 -and
    [int]$freeze.zero_world_receipt.world_build_count -eq 0 -and
    @($freeze.source_bindings).Count -eq 85 -and
    @($freeze.content_addressed_inputs.source_bindings).Count -eq 85 -and
    @($freeze.runtime_artifacts).Count -eq 2 -and
    @($freeze.content_addressed_inputs.runtime_bindings).Count -eq 5 -and
    [bool]$freeze.physical_execution_authorized -and
    -not [bool]$freeze.physical_acceptance_authority
) "physical freeze changed"

for ($index = 0; $index -lt 85; $index++) {
    $binding = $freeze.source_bindings[$index]
    $retained = $freeze.content_addressed_inputs.source_bindings[$index]
    $relative = [string]$binding.path
    $gitOid = (git -C $repoRoot rev-parse "${sourceCommit}:$relative").Trim()
    Assert-R23D33 (
        $LASTEXITCODE -eq 0 -and
        [string]$binding.git_blob_oid -ceq $gitOid -and
        [bool]$binding.raw_checkout_equals_git_blob -and
        [string]$retained.sha256 -ceq [string]$binding.raw_sha256
    ) "source binding changed: $relative"
    [void](Assert-Cas ([string]$retained.sha256) ([long]$retained.byte_length))
}

$coreRuntime = @($freeze.runtime_artifacts | Where-Object {
    [string]$_.name -ceq "locomotion_core_release"
})
$godotRuntime = @($freeze.runtime_artifacts | Where-Object {
    [string]$_.name -ceq "godot_adapter_debug"
})
Assert-R23D33 (
    $coreRuntime.Count -eq 1 -and
    [string]$coreRuntime[0].raw_sha256 -ceq
        [string]$closure.physical_evidence.locomotion_core_release_sha256 -and
    $godotRuntime.Count -eq 1 -and
    [string]$godotRuntime[0].raw_sha256 -ceq
        [string]$closure.physical_evidence.godot_adapter_debug_sha256
) "runtime binding changed"
foreach ($runtime in @($freeze.content_addressed_inputs.runtime_bindings)) {
    [void](Assert-Cas ([string]$runtime.sha256) ([long]$runtime.byte_length))
}

Assert-R23D33 (
    [string]$attempt.attempt_id -ceq [string]$closure.attempt_id -and
    [string]$attempt.source_commit -ceq $sourceCommit -and
    @($attempt.ordered_matrix_cell_ids).Count -eq 6 -and
    [bool]$attempt.source_worktree_clean -and
    [bool]$attempt.source_matches_live_github_main -and
    [bool]$attempt.operation_lock_held -and
    [bool]$attempt.campaign_attestation_adoption_valid -and
    [bool]$attempt.content_addressed_inputs_retained -and
    [bool]$attempt.one_shot_attempt_unconsumed -and
    [bool]$attempt.all_cells_run_regardless_of_intermediate_outcome -and
    [bool]$attempt.physical_execution_authorized -and
    -not [bool]$attempt.physical_acceptance_authority
) "attempt authorization changed"

Assert-R23D33 (
    @($terminalManifest).Count -eq 6 -and
    @($report.ordered_cells).Count -eq 6 -and
    @($evaluation.cell_evaluations).Count -eq 6 -and
    [string]$report.result_classification -ceq
        "invalid_complete_native_two_engine_transfer" -and
    [string]$evaluation.classification -ceq
        "invalid_complete_native_two_engine_transfer" -and
    [bool]$evaluation.all_cells_run_regardless_of_intermediate_outcome -and
    -not [bool]$evaluation.terminal_restoration_or_taper_invoked -and
    [string]$completion.status -ceq
        "invalid_complete_native_two_engine_transfer" -and
    [int]$completion.cell_count -eq 6 -and
    [int]$completion.world_count -eq 3 -and
    [bool]$completion.one_shot_attempt_consumed -and
    -not [bool]$completion.replacement_or_selective_rerun_permitted -and
    -not [bool]$completion.physical_acceptance_authority -and
    [string]$completion.report_cas.sha256 -ceq
        [string]$closure.physical_evidence.report.sha256 -and
    [string]$completion.complete_evaluation_cas.sha256 -ceq
        [string]$closure.physical_evidence.complete_evaluation.sha256
) "complete evaluation changed"

$observedWorldAttempts = 0
$observedWorldBuilds = 0
foreach ($expected in @($closure.ordered_cells)) {
    $reportCell = @($report.ordered_cells | Where-Object {
        [string]$_.cell_id -ceq [string]$expected.cell_id
    })
    $evaluatedCell = @($evaluation.cell_evaluations | Where-Object {
        [string]$_.cell_id -ceq [string]$expected.cell_id
    })
    Assert-R23D33 ($reportCell.Count -eq 1 -and $evaluatedCell.Count -eq 1) (
        "cell missing or duplicated: $($expected.cell_id)"
    )
    Assert-R23D33 (
        [string]$reportCell[0].terminal_entry_cas.sha256 -ceq
            [string]$expected.terminal_sha256 -and
        [long]$reportCell[0].terminal_entry_cas.byte_length -eq
            [long]$expected.terminal_byte_length -and
        -not [bool]$evaluatedCell[0].execution_valid -and
        -not [bool]$evaluatedCell[0].common_physical_gate_passed -and
        [int]$evaluatedCell[0].world_attempt_count -eq
            [int]$expected.world_attempt_count -and
        [int]$evaluatedCell[0].world_build_count -eq
            [int]$expected.world_build_count -and
        (@($evaluatedCell[0].failed_gate_ids) -join '|') -ceq
            [string]$expected.failure_code
    ) "cell evaluation changed: $($expected.cell_id)"

    $terminal = Read-CasJson `
        ([string]$expected.terminal_sha256) `
        ([long]$expected.terminal_byte_length)
    Assert-R23D33 (
        [string]$terminal.schema_version -ceq
            "sporespore_qsdk_r23d33_worker_failure_v1" -and
        [string]$terminal.source_commit -ceq $sourceCommit -and
        [string]$terminal.campaign_id -ceq [string]$closure.campaign_id -and
        [string]$terminal.cell_id -ceq [string]$expected.cell_id -and
        [string]$terminal.engine_id -ceq [string]$expected.engine_id -and
        [string]$terminal.arm_id -ceq [string]$expected.arm_id -and
        [string]$terminal.failure_code -ceq [string]$expected.failure_code -and
        [string]$terminal.failure_stage -ceq [string]$expected.failure_stage -and
        [int]$terminal.world_attempt_count -eq [int]$expected.world_attempt_count -and
        [int]$terminal.world_build_count -eq [int]$expected.world_build_count -and
        $null -eq $terminal.trace_artifact -and
        -not [bool]$terminal.claims.physical_acceptance_authority
    ) "terminal identity changed: $($expected.cell_id)"
    $observedWorldAttempts += [int]$terminal.world_attempt_count
    $observedWorldBuilds += [int]$terminal.world_build_count

    if ([string]$expected.engine_id -ceq "godot_jolt") {
        $summary = $terminal.godot_execution_predicates.raw_sdk_authority_summary
        Assert-R23D33 (
            [string]$terminal.failure_stage -ceq "controller_horizon_complete" -and
            [int]$summary.step_count -eq 2992 -and
            [int]$summary.validated_balanced_wave_command_count -eq 23936 -and
            [int]$summary.mismatch_count -eq 5984 -and
            [int]$summary.native_actuation_application_count -eq 0 -and
            [int]$summary.native_safe_disable_application_count -eq 23936 -and
            (@($summary.failure_codes) -join '|') -ceq
                ($expectedGodotFailures -join '|')
        ) "Godot fail-closed mechanism changed: $($expected.arm_id)"
    } else {
        Assert-R23D33 (
            [string]$terminal.failure_stage -ceq "before_world" -and
            [int]$terminal.world_attempt_count -eq 0 -and
            [int]$terminal.world_build_count -eq 0
        ) "MuJoCo pre-world mechanism changed: $($expected.arm_id)"
    }
}

Assert-R23D33 (
    $observedWorldAttempts -eq 3 -and
    $observedWorldBuilds -eq 3 -and
    [int]$closure.attempt_summary.declared_cell_count -eq 6 -and
    [int]$closure.attempt_summary.terminal_cell_count -eq 6 -and
    [int]$closure.attempt_summary.execution_valid_cell_count -eq 0 -and
    [int]$closure.attempt_summary.worker_failure_count -eq 6 -and
    [bool]$closure.failure_mechanisms.godot_jolt.observed_on_all_three_arms -and
    [bool]$closure.failure_mechanisms.mujoco.observed_on_all_three_arms -and
    -not [bool]$closure.bounded_interpretation.scientific_locomotion_negative -and
    -not [bool]$closure.bounded_interpretation.walking_outcome_observed -and
    -not [bool]$closure.bounded_interpretation.turning_outcome_observed -and
    -not [bool]$closure.claims.portable_basic_turning -and
    -not [bool]$closure.claims.finite_three_engine_turning -and
    -not [bool]$closure.claims.cross_engine_equivalence -and
    -not [bool]$closure.claims.prone_to_standing -and
    -not [bool]$closure.claims.release_authorized -and
    -not [bool]$closure.claims.physical_acceptance_authority
) "bounded interpretation changed"

Write-Output (
    "QSDK-R23D33 closure audit passed " +
    "(cells=6 worlds=3 classification=invalid_complete_implementation_failures " +
    "same_identity_rerun=false)."
)
