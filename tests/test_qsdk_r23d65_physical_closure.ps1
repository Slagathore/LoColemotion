#requires -Version 7.0

[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$evidenceRoot = "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence"
$artifactRoot = Join-Path $evidenceRoot "artifacts\sha256"
$attemptRoot = Join-Path $evidenceRoot (
    "qsdk-r23d65-physical-20260825T151300Z-4ecb24cc"
)
$qualificationOneRoot = Join-Path $evidenceRoot (
    "qsdk-r23d65-qualification-20260825T145433Z-4ecb24cc"
)
$qualificationTwoRoot = Join-Path $evidenceRoot (
    "qsdk-r23d65-qualification-20260825T150425Z-4ecb24cc-commissioned-python"
)
$closurePath = Join-Path $repoRoot (
    "sdk\turning\r23d65_selected_profile_three_engine_turning_validation_closure_v1.json"
)
$releaseContractPath = Join-Path $repoRoot "sdk\release\quadruped_release_contract.json"
$supportMatrixPath = Join-Path $repoRoot "sdk\release\quadruped_support_matrix.json"
$sourceCommit = "4ecb24cc1f5f7bc864578c8915dd7028a99990bf"
$sourceTree = "637b1cafd786037f11060fd5deaa08d3f6b59c06"
$attemptId = "d38c4f5d45e6472bbbc75b64917bb9b8"
$campaignId = (
    "QSDK-R23D65-RUNTIME-INTEGRATION-REPAIRED-SELECTED-PROFILE-" +
    "MATCHED-THREE-ENGINE-TURNING-VALIDATION"
)
$closedStatus = (
    "closed_consumed_invalid_incomplete_after_four_worlds_" +
    "runtime_terminal_and_trace_retention_failures"
)
$expectedNonCas = [string[]]@(
    "pending-traces/godot_jolt__s23175__selected_profile__negative_heading.rows.json",
    "pending-traces/godot_jolt__s23175__selected_profile__positive_heading.rows.json",
    "pending-traces/godot_jolt__s23175__selected_profile__reference_zero.rows.json",
    (
        "pending-traces/runtime_integration_repaired_selected_profile_matched_" +
        "three_engine_turning_validation__rapier_parry__s23175__selected_profile__" +
        "reference_zero.rows.json"
    )
)
[Array]::Sort($expectedNonCas, [StringComparer]::Ordinal)

function Assert-R23D65Closure([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "QSDK-R23D65 CLOSURE: $Message" }
}

function Get-R23D65Sha256([string]$Path) {
    return "sha256:" + (
        Get-FileHash -LiteralPath $Path -Algorithm SHA256
    ).Hash.ToLowerInvariant()
}

function Get-R23D65BytesSha256([byte[]]$Bytes) {
    return "sha256:" + [Convert]::ToHexString(
        [Security.Cryptography.SHA256]::HashData($Bytes)
    ).ToLowerInvariant()
}

function Invoke-R23D65Git([string[]]$Arguments) {
    $lines = @(& git -C $repoRoot @Arguments 2>&1)
    Assert-R23D65Closure ($LASTEXITCODE -eq 0) (
        "git $($Arguments -join ' ') failed: $($lines -join ' ')"
    )
    return ($lines -join "`n").Trim()
}

function Assert-R23D65Binding($Binding) {
    $path = [IO.Path]::GetFullPath([string]$Binding.path)
    Assert-R23D65Closure (
        (Test-Path -LiteralPath $path -PathType Leaf) -and
        (Get-Item -LiteralPath $path).Length -eq [long]$Binding.byte_length -and
        (Get-R23D65Sha256 $path) -ceq [string]$Binding.raw_sha256
    ) "retained qualification binding changed: $path"
    $digest = ([string]$Binding.raw_sha256).Substring(7)
    $payload = Join-Path $artifactRoot "$digest\payload.bin"
    Assert-R23D65Closure (
        (Test-Path -LiteralPath $payload -PathType Leaf) -and
        (Get-Item -LiteralPath $payload).Length -eq [long]$Binding.byte_length -and
        (Get-R23D65Sha256 $payload) -ceq [string]$Binding.raw_sha256
    ) "retained qualification CAS changed: $($Binding.raw_sha256)"
}

function Find-R23D65NamedValues($Node, [string]$Name) {
    if ($Node -is [Collections.IDictionary]) {
        foreach ($key in $Node.Keys) {
            if ([string]$key -ceq $Name) {
                if ($Node[$key] -is [string]) {
                    Write-Output $Node[$key]
                } else {
                    Write-Output -NoEnumerate $Node[$key]
                }
            }
            Find-R23D65NamedValues $Node[$key] $Name
        }
    } elseif ($Node -is [Collections.IEnumerable] -and $Node -isnot [string]) {
        foreach ($item in $Node) {
            Find-R23D65NamedValues $item $Name
        }
    }
}

function Test-R23D65ClosureVector($Value) {
    return (
        [string]$Value.schema_version -ceq
            "sporespore_qsdk_r23d65_selected_profile_three_engine_turning_validation_closure_v1" -and
        [string]$Value.status -ceq $closedStatus -and
        [string]$Value.campaign_id -ceq $campaignId -and
        [string]$Value.gate_id -ceq "QSDK-R23D65" -and
        [string]$Value.release_gate_id -ceq "QSDK-R23" -and
        [string]$Value.ledger_scope.subsystem -ceq "turning" -and
        [string]$Value.ledger_scope.engine_scope -ceq "3e" -and
        [string]$Value.ledger_scope.authority_mode -ceq
            "official_physical_closure" -and
        [string]$Value.ledger_scope.question_class -ceq "finite_decision" -and
        [string]$Value.physical_question_class -ceq "finite_decision" -and
        [string]$Value.runtime_integration_conformance_question_class -ceq
            "equivalence_non_inferiority" -and
        [string]$Value.source_commit -ceq $sourceCommit -and
        [string]$Value.source_tree_git_oid -ceq $sourceTree -and
        [string]$Value.supervisor_source_git_blob_oid -ceq
            "35c7c04337e133a568a1974fc784a573ac9f171c" -and
        [string]$Value.godot_worker_source_git_blob_oid -ceq
            "f09a072f73fa04e1ce81698c827590ac909c5489" -and
        [string]$Value.attempt_id -ceq $attemptId -and
        [int]$Value.campaign_seed -eq 23175 -and
        [bool]$Value.campaign_identity_consumed -and
        -not [bool]$Value.same_identity_rerun_allowed -and
        -not [bool]$Value.replacement_or_selective_rerun_allowed -and
        [bool]$Value.physical_outcome_exposed -and
        [bool]$Value.held_out_seed_physical_outcome_exposed -and
        [bool]$Value.held_out_condition_consumed -and
        -not [bool]$Value.successor_campaign_opened_at_closure -and
        [bool]$Value.qualification_history.passing_nonadoptable_runtime_identity.qualification_passed -and
        -not [bool]$Value.qualification_history.passing_nonadoptable_runtime_identity.adoption_passed -and
        [string]$Value.qualification_history.passing_nonadoptable_runtime_identity.adoption_failure -ceq
            "Runtime or host changed since LCA1 commissioning." -and
        [int]$Value.qualification_history.passing_nonadoptable_runtime_identity.executed_gate_count -eq 25 -and
        [bool]$Value.qualification_history.passing_adopted_commissioned_runtime.qualification_passed -and
        [bool]$Value.qualification_history.passing_adopted_commissioned_runtime.adoption_passed -and
        [int]$Value.qualification_history.passing_adopted_commissioned_runtime.executed_gate_count -eq 25 -and
        [int]$Value.qualification_history.passing_adopted_commissioned_runtime.gate_cas_object_count -eq 75 -and
        [bool]$Value.qualification_history.passing_adopted_commissioned_runtime.physical_launch_prerequisite_satisfied -and
        [int]$Value.declaration_and_zero_world_provenance.transitive_path_count -eq 237 -and
        [int]$Value.declaration_and_zero_world_provenance.transitive_edge_count -eq 238 -and
        [int]$Value.declaration_and_zero_world_provenance.runtime_integration_obligation_population_size -eq 7 -and
        [int]$Value.declaration_and_zero_world_provenance.runtime_integration_conforming_obligation_count -eq 7 -and
        [bool]$Value.declaration_and_zero_world_provenance.runtime_integration_population_compared_completely -and
        -not [bool]$Value.declaration_and_zero_world_provenance.runtime_integration_sampling_claimed -and
        [double]$Value.declaration_and_zero_world_provenance.runtime_integration_equivalence_margin -eq 0.0 -and
        [double]$Value.declaration_and_zero_world_provenance.runtime_integration_non_inferiority_margin -eq 0.0 -and
        [int]$Value.declaration_and_zero_world_provenance.authorization_preflight_receipt_count -eq 9 -and
        [int]$Value.declaration_and_zero_world_provenance.world_build_count -eq 0 -and
        [int]$Value.physical_evidence.complete_retained_file_population_count -eq 41 -and
        [long]$Value.physical_evidence.complete_retained_file_population_byte_count -eq 134685582 -and
        [int]$Value.physical_evidence.retained_unique_digest_count -eq 29 -and
        [int]$Value.physical_evidence.cas_backed_file_count -eq 37 -and
        [int]$Value.physical_evidence.non_cas_retained_file_count -eq 4 -and
        [int]$Value.physical_evidence.canonical_population_manifest_byte_length -eq 6387 -and
        [string]$Value.physical_evidence.canonical_population_manifest_sha256 -ceq
            "sha256:bade316726f84e1c6d08bfa5a0ba960db240d6dc462fd808caf3627feaf249ba" -and
        [int]$Value.physical_evidence.physical_worker_process_count -eq 4 -and
        [int]$Value.physical_evidence.worker_terminal_marker_count -eq 4 -and
        [int]$Value.physical_evidence.supervisor_terminal_entry_count -eq 3 -and
        [int]$Value.physical_evidence.unopened_declared_cell_count -eq 5 -and
        [int]$Value.physical_evidence.actual_worker_reported_world_attempt_count -eq 4 -and
        [int]$Value.physical_evidence.actual_worker_reported_world_build_count -eq 4 -and
        [int]$Value.physical_evidence.official_execution_valid_cell_count -eq 0 -and
        [int]$Value.physical_evidence.turning_evaluated_cell_count -eq 0 -and
        [int]$Value.physical_evidence.complete_evaluator_invocation_count -eq 0 -and
        [string]$Value.failure_mechanisms.godot_jolt.worker_failure_code -ceq
            "QSDK_R23D65_GJT_TRACE_RETENTION_FAILED:1" -and
        [int]$Value.failure_mechanisms.godot_jolt.world_build_count -eq 3 -and
        [int]$Value.failure_mechanisms.godot_jolt.complete_trace_row_count_each -eq 2992 -and
        [int]$Value.failure_mechanisms.rapier_parry.executed_cell_count -eq 1 -and
        [int]$Value.failure_mechanisms.rapier_parry.worker_execution_world_build_count -eq 1 -and
        [int]$Value.failure_mechanisms.rapier_parry.top_level_world_build_count -eq 0 -and
        [bool]$Value.failure_mechanisms.rapier_parry.world_count_projection_mismatch_observed -and
        [int]$Value.failure_mechanisms.rapier_parry.canonical_trace_row_count -eq 2992 -and
        [string]$Value.failure_mechanisms.rapier_parry.canonical_trace_raw_sha256 -ceq
            "sha256:32b7b27469cb2cc9c15b38ca4b48ae7bdbabb4fcd64a4a490cac7c86bfd2bcc8" -and
        -not [bool]$Value.failure_mechanisms.rapier_parry.observed_reference_arm_measurement_interpreted_as_turning_result -and
        [int]$Value.failure_mechanisms.mujoco.executed_cell_count -eq 0 -and
        [string]$Value.failure_mechanisms.supervisor.failure_class -ceq
            "failure_terminal_normalization_handler_runtime_error" -and
        [bool]$Value.failure_mechanisms.supervisor.failure_handler_masked_preceding_rapier_projection_exception -and
        -not [bool]$Value.failure_mechanisms.aggregate.scientific_result_created -and
        -not [bool]$Value.official_result.scientific_result_exists -and
        -not [bool]$Value.official_result.physical_result_exists -and
        -not [bool]$Value.official_result.finite_three_engine_turning -and
        -not [bool]$Value.official_result.q_sdk_r23_satisfied -and
        [string]$Value.official_result.release_score_before -ceq "10/25" -and
        [string]$Value.official_result.release_score_after -ceq "10/25" -and
        -not [bool]$Value.official_result.release_score_changed -and
        [bool]$Value.successor_boundary.distinct_successor_required -and
        -not [bool]$Value.successor_boundary.same_seed_reuse_allowed -and
        -not [bool]$Value.successor_boundary.retained_rows_may_be_promoted_to_successor_physical_evidence -and
        [int]@($Value.successor_boundary.minimum_observed_integration_repair_population).Count -eq 3 -and
        [bool]$Value.claims.campaign_closed -and
        [bool]$Value.claims.retained_evidence_complete -and
        -not [bool]$Value.claims.historical_result_reinterpreted -and
        -not [bool]$Value.claims.turning_claimed -and
        -not [bool]$Value.claims.physical_acceptance_authority
    )
}

Assert-R23D65Closure (
    (Invoke-R23D65Git @("rev-parse", "--show-toplevel")) -ceq
        $repoRoot.Replace("\", "/") -and
    (Invoke-R23D65Git @("remote", "get-url", "origin")) -ceq
        "https://github.com/Slagathore/sporespore.git"
) "repository identity changed"
foreach ($path in @(
    $attemptRoot,
    $qualificationOneRoot,
    $qualificationTwoRoot,
    $closurePath
)) {
    Assert-R23D65Closure (Test-Path -LiteralPath $path) "path is missing: $path"
}

$closure = Get-Content -LiteralPath $closurePath -Raw |
    ConvertFrom-Json -AsHashtable -Depth 100
Assert-R23D65Closure (Test-R23D65ClosureVector $closure) (
    "closure claim vector changed"
)
Assert-R23D65Closure (
    (Invoke-R23D65Git @("rev-parse", "$sourceCommit^{tree}")) -ceq $sourceTree -and
    (Invoke-R23D65Git @("rev-parse", "$sourceCommit`:sdk/run_qsdk_r23d65_supervisor.ps1")) -ceq
        [string]$closure.supervisor_source_git_blob_oid -and
    (Invoke-R23D65Git @("rev-parse", "$sourceCommit`:tests/test_sdk_qsdk_r23d65_godot_jolt_physical_worker.gd")) -ceq
        [string]$closure.godot_worker_source_git_blob_oid
) "consumed source identity changed"
$sourceSupervisor = Invoke-R23D65Git @(
    "show", "$sourceCommit`:sdk/run_qsdk_r23d65_supervisor.ps1"
)
Assert-R23D65Closure (
    [regex]::IsMatch(
        $sourceSupervisor,
        '-WorldBuildCountUpperBound\s*\(\s*if\s*\(\$observedCountsExact\)',
        [Text.RegularExpressions.RegexOptions]::CultureInvariant
    )
) "consumed supervisor failure expression changed"

$qualificationOne = $closure.qualification_history.passing_nonadoptable_runtime_identity
$qualificationTwo = $closure.qualification_history.passing_adopted_commissioned_runtime
Assert-R23D65Binding $qualificationOne.attestation
Assert-R23D65Binding $qualificationTwo.attestation
Assert-R23D65Binding $qualificationTwo.adoption
$attestationOne = Get-Content -LiteralPath ([string]$qualificationOne.attestation.path) -Raw |
    ConvertFrom-Json -Depth 100
$attestationTwo = Get-Content -LiteralPath ([string]$qualificationTwo.attestation.path) -Raw |
    ConvertFrom-Json -Depth 100
$adoption = Get-Content -LiteralPath ([string]$qualificationTwo.adoption.path) -Raw |
    ConvertFrom-Json -Depth 100
Assert-R23D65Closure (
    [string]$attestationOne.runtime.python.executable_path -ceq
        "C:\Users\Cole\CodeStuff\games\SporeSpore\sdk\adapters\mujoco\.venv\Scripts\python.exe" -and
    [string]$attestationOne.runtime.python.executable_sha256 -ceq
        [string]$qualificationOne.python_executable_raw_sha256 -and
    [string]$attestationTwo.runtime.python.executable_path -ceq
        "C:\Program Files\Python311\python.exe" -and
    [string]$attestationTwo.runtime.python.executable_sha256 -ceq
        [string]$qualificationTwo.python_executable_raw_sha256 -and
    [bool]$adoption.runtime_matches_commissioning -and
    [bool]$adoption.physical_launch_prerequisite_satisfied -and
    -not [bool]$adoption.physical_acceptance_authority
) "qualification or adoption runtime boundary changed"

$expectedPaths = [string[]]@($closure.physical_evidence.ordered_relative_paths)
$observedItems = @(Get-ChildItem -LiteralPath $attemptRoot -File -Recurse |
    ForEach-Object {
        [pscustomobject]@{
            relative_path = [IO.Path]::GetRelativePath($attemptRoot, $_.FullName).
                Replace("\", "/")
            full_path = $_.FullName
            byte_length = [long]$_.Length
        }
    })
$observedPaths = [string[]]@($observedItems.relative_path)
[Array]::Sort($observedPaths, [StringComparer]::Ordinal)
Assert-R23D65Closure (
    $expectedPaths.Count -eq 41 -and
    $observedPaths.Count -eq 41 -and
    (@(Compare-Object $expectedPaths $observedPaths -CaseSensitive)).Count -eq 0
) "complete retained physical file population changed"

$manifest = [Text.StringBuilder]::new()
$totalBytes = 0L
$uniqueDigests = [Collections.Generic.HashSet[string]]::new(
    [StringComparer]::Ordinal
)
$casBacked = 0
$nonCas = [Collections.Generic.List[string]]::new()
foreach ($relative in $observedPaths) {
    $item = @($observedItems | Where-Object {
        [string]$_.relative_path -ceq $relative
    })[0]
    $sha256 = Get-R23D65Sha256 ([string]$item.full_path)
    [void]$uniqueDigests.Add($sha256)
    $totalBytes += [long]$item.byte_length
    [void]$manifest.Append($relative).Append("`t").
        Append([long]$item.byte_length).Append("`t").Append($sha256).Append("`n")
    $payload = Join-Path $artifactRoot ($sha256.Substring(7) + "\payload.bin")
    if (Test-Path -LiteralPath $payload -PathType Leaf) {
        Assert-R23D65Closure (
            (Get-Item -LiteralPath $payload).Length -eq [long]$item.byte_length -and
            (Get-R23D65Sha256 $payload) -ceq $sha256
        ) "CAS payload changed: $relative"
        $casBacked += 1
    } else {
        $nonCas.Add($relative)
    }
}
$manifestBytes = [Text.UTF8Encoding]::new($false).GetBytes($manifest.ToString())
$observedNonCas = [string[]]@($nonCas)
[Array]::Sort($observedNonCas, [StringComparer]::Ordinal)
Assert-R23D65Closure (
    $totalBytes -eq 134685582 -and
    $manifestBytes.Length -eq 6387 -and
    (Get-R23D65BytesSha256 $manifestBytes) -ceq
        [string]$closure.physical_evidence.canonical_population_manifest_sha256 -and
    $uniqueDigests.Count -eq 29 -and
    $casBacked -eq 37 -and
    (@(Compare-Object $expectedNonCas $observedNonCas -CaseSensitive)).Count -eq 0
) "retained physical population digest, size, or CAS classification changed"

$attempt = Get-Content -LiteralPath (Join-Path $attemptRoot "attempt-authorization.json") -Raw |
    ConvertFrom-Json -Depth 100
$preflight = Get-Content -LiteralPath (Join-Path $attemptRoot "authorization-preflight.json") -Raw |
    ConvertFrom-Json -Depth 100
$completion = Get-Content -LiteralPath (Join-Path $attemptRoot "completion.json") -Raw |
    ConvertFrom-Json -Depth 100
Assert-R23D65Closure (
    [string]$attempt.attempt_id -ceq $attemptId -and
    [string]$attempt.source_commit -ceq $sourceCommit -and
    [int]@($attempt.ordered_matrix_cell_ids).Count -eq 9 -and
    [bool]$attempt.single_use_supervisor_authorization -and
    [bool]$attempt.all_cells_run_regardless_of_intermediate_outcome -and
    [int]$preflight.receipt_count -eq 9 -and
    [int]$preflight.world_attempt_count -eq 0 -and
    [int]$preflight.world_build_count -eq 0 -and
    [string]$completion.status -ceq "invalid_or_incomplete_first_attempt" -and
    [bool]$completion.one_shot_attempt_consumed -and
    -not [bool]$completion.replacement_or_selective_rerun_permitted -and
    [string]$completion.failure_message -ceq (
        "The term 'if' is not recognized as a name of a cmdlet, function, " +
        "script file, or executable program.`r`nCheck the spelling of the name, " +
        "or if a path was included, verify that the path is correct and try again."
    ) -and
    -not [bool]$completion.physical_acceptance_authority
) "attempt, preflight, or emergency completion changed"

$godotTerminalPaths = @(
    Get-ChildItem -LiteralPath (Join-Path $attemptRoot "cells") -Directory |
        Where-Object { $_.Name -like "godot_jolt__*" } |
        ForEach-Object {
            Get-Item -LiteralPath (Join-Path $_.FullName "terminal.json")
        }
)
Assert-R23D65Closure ($godotTerminalPaths.Count -eq 3) (
    "Godot terminal population changed"
)
foreach ($terminalPath in $godotTerminalPaths) {
    $terminal = Get-Content -LiteralPath $terminalPath.FullName -Raw |
        ConvertFrom-Json -Depth 100
    Assert-R23D65Closure (
        [string]$terminal.schema_version -ceq
            "sporespore_qsdk_r23d65_worker_failure_v1" -and
        [string]$terminal.failure_code -ceq
            "QSDK_R23D65_GJT_TRACE_RETENTION_FAILED:1" -and
        [int]$terminal.world_attempt_count -eq 1 -and
        [int]$terminal.world_build_count -eq 1 -and
        [string]$terminal.trace_diagnostic.schema_version -ceq
            "sporespore_qsdk_r23d65_trace_diagnostic_v1" -and
        [bool]$terminal.trace_diagnostic.complete -and
        [int]$terminal.trace_diagnostic.actual_row_count -eq 2992 -and
        [int]@($terminal.trace_diagnostic.failure_codes).Count -eq 0 -and
        [string]$terminal.trace_diagnostic.trace_retention_failure_code -ceq
            "QSDK_R23D65_GJT_TRACE_RETENTION_FAILED:1" -and
        [string]$terminal.trace_diagnostic_artifact.sha256 -cmatch
            '^sha256:[0-9a-f]{64}$'
    ) "Godot retained failure or complete diagnostic changed: $($terminal.cell_id)"
}

$rapierStdout = Join-Path $attemptRoot (
    "cells\rapier_parry__s23175__selected_profile__reference_zero\stdout.txt"
)
$rapierMarker = @(
    Get-Content -LiteralPath $rapierStdout |
        Where-Object { $_.StartsWith("QSDK_R23D65_RAPIER_TERMINAL ") }
)
Assert-R23D65Closure ($rapierMarker.Count -eq 1) (
    "Rapier reference worker marker population changed"
)
$rapier = $rapierMarker[0].Substring(
    "QSDK_R23D65_RAPIER_TERMINAL ".Length
) | ConvertFrom-Json -Depth 100
Assert-R23D65Closure (
    [string]$rapier.schema_version -ceq
        "sporespore_qsdk_r23d65_engine_cell_report_v1" -and
    [string]$rapier.arm_id -ceq "reference_zero" -and
    [bool]$rapier.execution.integrity_passed -and
    [int]$rapier.execution.world_attempt_count -eq 1 -and
    [int]$rapier.execution.world_build_count -eq 1 -and
    [int]$rapier.world_attempt_count -eq 0 -and
    [int]$rapier.world_build_count -eq 0 -and
    [int]$rapier.trace_summary.row_count -eq 2992 -and
    [string]$rapier.trace_artifact.sha256 -ceq
        "sha256:32b7b27469cb2cc9c15b38ca4b48ae7bdbabb4fcd64a4a490cac7c86bfd2bcc8" -and
    [double]$rapier.measurements.turn_phase_yaw_delta_rad -eq
        0.0032929294827228617 -and
    -not [bool]$rapier.claims.portable_basic_turning -and
    -not [bool]$rapier.claims.q_sdk_r23_satisfied
) "Rapier retained reference worker report changed"

foreach ($mutation in @(
    @{ path = "status"; value = "passing" },
    @{ path = "file_count"; value = 40 },
    @{ path = "manifest"; value = "sha256:" + ("0" * 64) },
    @{ path = "result"; value = $true }
)) {
    $copy = $closure | ConvertTo-Json -Depth 100 | ConvertFrom-Json -AsHashtable -Depth 100
    switch ([string]$mutation.path) {
        "status" { $copy.status = [string]$mutation.value }
        "file_count" { $copy.physical_evidence.complete_retained_file_population_count = [int]$mutation.value }
        "manifest" { $copy.physical_evidence.canonical_population_manifest_sha256 = [string]$mutation.value }
        "result" { $copy.official_result.physical_result_exists = [bool]$mutation.value }
    }
    Assert-R23D65Closure (-not (Test-R23D65ClosureVector $copy)) (
        "closure mutation control passed: $($mutation.path)"
    )
}

$releaseContract = Get-Content -LiteralPath $releaseContractPath -Raw |
    ConvertFrom-Json -AsHashtable -Depth 100
$supportMatrix = Get-Content -LiteralPath $supportMatrixPath -Raw |
    ConvertFrom-Json -AsHashtable -Depth 100
$recordName = (
    "prospective_r23d65_runtime_integration_repaired_selected_profile_" +
    "three_engine_turning_validation"
)
$expectedCurrentStatus = (
    "r23d65_closed_consumed_invalid_incomplete_after_four_worlds_" +
    "runtime_terminal_and_trace_retention_failures_distinct_successor_required"
)
$releaseRecords = @(Find-R23D65NamedValues $releaseContract $recordName)
$supportRecords = @(Find-R23D65NamedValues $supportMatrix $recordName)
$releaseCurrent = @(
    Find-R23D65NamedValues $releaseContract "current_prospective_successor_status"
)
$supportCurrent = @(
    Find-R23D65NamedValues $supportMatrix "current_prospective_successor_status"
)
$releaseReason = @(
    Find-R23D65NamedValues $releaseContract "current_prospective_successor_reason"
)
$supportReason = @(
    Find-R23D65NamedValues $supportMatrix "current_prospective_successor_reason"
)
$closureSha256 = Get-R23D65Sha256 $closurePath
$closureBytes = (Get-Item -LiteralPath $closurePath).Length
$auditSha256 = Get-R23D65Sha256 $PSCommandPath
$auditBytes = (Get-Item -LiteralPath $PSCommandPath).Length
Assert-R23D65Closure (
    $releaseRecords.Count -eq 1 -and
    $supportRecords.Count -eq 1 -and
    $releaseCurrent.Count -eq 1 -and
    $supportCurrent.Count -eq 1 -and
    $releaseReason.Count -eq 1 -and
    $supportReason.Count -eq 1 -and
    [string]$releaseCurrent[0] -ceq $expectedCurrentStatus -and
    [string]$supportCurrent[0] -ceq $expectedCurrentStatus -and
    [string]$releaseReason[0] -ceq [string]$supportReason[0] -and
    [string]$releaseRecords[0].current_lifecycle_status -ceq
        $closure.status -and
    [string]$supportRecords[0].current_lifecycle_status -ceq
        $closure.status -and
    [string]$releaseRecords[0].physical_closure.closure_path -ceq
        "sdk/turning/r23d65_selected_profile_three_engine_turning_validation_closure_v1.json" -and
    [string]$releaseRecords[0].physical_closure.closure_raw_sha256 -ceq
        $closureSha256 -and
    [long]$releaseRecords[0].physical_closure.closure_byte_length -eq
        $closureBytes -and
    [string]$releaseRecords[0].physical_closure.closure_audit_path -ceq
        "tests/test_qsdk_r23d65_physical_closure.ps1" -and
    [string]$releaseRecords[0].physical_closure.closure_audit_raw_sha256 -ceq
        $auditSha256 -and
    [long]$releaseRecords[0].physical_closure.closure_audit_byte_length -eq
        $auditBytes -and
    ($releaseRecords[0].physical_closure | ConvertTo-Json -Depth 30 -Compress) -ceq
        ($supportRecords[0].physical_closure | ConvertTo-Json -Depth 30 -Compress) -and
    [bool]$releaseRecords[0].campaign_identity_consumed -and
    [bool]$releaseRecords[0].physical_outcome_exposed -and
    [bool]$releaseRecords[0].held_out_seed_physical_outcome_exposed -and
    [bool]$releaseRecords[0].fresh_scoped_qualification_passed -and
    [bool]$releaseRecords[0].campaign_attestation_adopted -and
    [bool]$releaseRecords[0].physical_launch_prerequisite_satisfied -and
    [bool]$releaseRecords[0].physical_campaign_opened -and
    [int]$releaseRecords[0].world_attempt_count -eq 4 -and
    [int]$releaseRecords[0].world_build_count -eq 4 -and
    [int]$releaseRecords[0].official_execution_valid_cell_count -eq 0 -and
    [int]$releaseRecords[0].turning_evaluated_cell_count -eq 0 -and
    -not [bool]$releaseRecords[0].finite_three_engine_turning -and
    -not [bool]$releaseRecords[0].q_sdk_r23_satisfied -and
    -not [bool]$releaseRecords[0].release_authorized
) "release contract or support-matrix R23D65 closure projection changed"

Write-Host (
    "QSDK_R23D65_PHYSICAL_CLOSURE_PASS files=41 bytes=134685582 " +
    "cas_backed=37 non_cas_rows=4 preflights=9 workers=4 terminals=3 " +
    "worlds=4 unopened=5 evaluated=0 turning=False qsdk_r23=False " +
    "score=10/25 rerun=False physical_authority=False"
)
