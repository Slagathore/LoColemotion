#requires -Version 7.0

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$evidenceRoot = "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence"
$artifactRoot = Join-Path $evidenceRoot "artifacts\sha256"
$attemptRoot = Join-Path $evidenceRoot "qsdk-r23d50-20260813T152903Z"
$incidentRoot = Join-Path $evidenceRoot "qsdk-r23d50-20260813T151849Z"
$closurePath = Join-Path $repoRoot (
    "sdk\turning\r23d50_rapier_cas_path_identity_replay_closure_v1.json"
)
$sourceCommit = "4908b3ed2d228897fa1b15a1adcac5a0881b93b1"
$classification = (
    "valid_complete_positive_outcome_exposed_rapier_cas_path_identity_replay"
)
$tolerance = 1.0e-12

function Assert-R23D50Closure([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "QSDK-R23D50 CLOSURE: $Message" }
}

function Assert-Near([double]$Actual, [double]$Expected, [string]$Message) {
    Assert-R23D50Closure (
        [double]::IsFinite($Actual) -and
        [Math]::Abs($Actual - $Expected) -le $tolerance
    ) $Message
}

function Get-Sha256([string]$Path) {
    return "sha256:" + (
        Get-FileHash -LiteralPath $Path -Algorithm SHA256
    ).Hash.ToLowerInvariant()
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
    Assert-R23D50Closure ($process.Start()) "could not start git cat-file"
    $memory = [IO.MemoryStream]::new()
    try {
        $process.StandardOutput.BaseStream.CopyTo($memory)
        $stderr = $process.StandardError.ReadToEnd()
        $process.WaitForExit()
        Assert-R23D50Closure ($process.ExitCode -eq 0) (
            "historical blob unavailable: $RelativePath; $stderr"
        )
        return ,([byte[]]$memory.ToArray())
    } finally {
        $memory.Dispose()
        $process.Dispose()
    }
}

function Assert-Cas([string]$Sha256, [long]$ByteLength) {
    Assert-R23D50Closure ($Sha256 -cmatch '^sha256:[0-9a-f]{64}$') (
        "invalid CAS digest: $Sha256"
    )
    $directory = Join-Path $artifactRoot $Sha256.Substring(7)
    $payload = Join-Path $directory "payload.bin"
    $manifestPath = Join-Path $directory "manifest.json"
    Assert-R23D50Closure (
        (Test-Path -LiteralPath $payload -PathType Leaf) -and
        (Test-Path -LiteralPath $manifestPath -PathType Leaf) -and
        (Get-Item -LiteralPath $payload).Length -eq $ByteLength -and
        (Get-Sha256 $payload) -ceq $Sha256
    ) "CAS payload changed: $Sha256"
    $manifest = Get-Content -Raw -LiteralPath $manifestPath |
        ConvertFrom-Json -Depth 20
    Assert-R23D50Closure (
        [string]$manifest.schema_version -ceq
            "sporespore_content_addressed_artifact_manifest_v1" -and
        [string]$manifest.algorithm -ceq "sha256" -and
        [string]$manifest.sha256 -ceq $Sha256 -and
        [long]$manifest.byte_length -eq $ByteLength -and
        [string]$manifest.payload_name -ceq "payload.bin"
    ) "CAS manifest changed: $Sha256"
    return $payload
}

function Assert-PathAndCas(
    [string]$Path,
    [string]$Sha256,
    [long]$ByteLength
) {
    Assert-R23D50Closure (
        (Test-Path -LiteralPath $Path -PathType Leaf) -and
        (Get-Item -LiteralPath $Path).Length -eq $ByteLength -and
        (Get-Sha256 $Path) -ceq $Sha256
    ) "retained artifact changed: $Path"
    $payload = Assert-Cas $Sha256 $ByteLength
    Assert-R23D50Closure ((Get-Sha256 $payload) -ceq (Get-Sha256 $Path)) (
        "retained artifact and CAS differ: $Path"
    )
    return $payload
}

Assert-R23D50Closure (
    (git -C $repoRoot rev-parse --show-toplevel).Trim().Replace('/', '\') -ceq
        $repoRoot -and
    (git -C $repoRoot remote get-url origin).Trim() -ceq
        "https://github.com/Slagathore/sporespore.git"
) "repository identity changed"

$closure = Get-Content -Raw -LiteralPath $closurePath |
    ConvertFrom-Json -Depth 100
Assert-R23D50Closure (
    [string]$closure.schema_version -ceq
        "sporespore_qsdk_r23d50_rapier_cas_path_identity_replay_closure_v1" -and
    [string]$closure.status -ceq
        "closed_consumed_valid_complete_positive_outcome_exposed_rapier_cas_path_identity_replay" -and
    [string]$closure.source_commit -ceq $sourceCommit -and
    (git -C $repoRoot rev-parse "$sourceCommit`^{tree}").Trim() -ceq
        [string]$closure.source_tree_git_oid -and
    [string]$closure.attempt_id -ceq "af5e516c258f4317b142b4746eaa30cf" -and
    [int]$closure.campaign_seed -eq 21512 -and
    [bool]$closure.identity_consumed -and
    -not [bool]$closure.same_identity_rerun_allowed -and
    -not [bool]$closure.selective_rerun_allowed -and
    -not [bool]$closure.fresh_held_out_condition_consumed -and
    -not [bool]$closure.successor_campaign_opened -and
    [bool]$closure.physical_series_paused_before_successor
) "immutable disposition changed"

foreach ($input in @($closure.prospective_inputs)) {
    $relative = [string]$input.path
    $bytes = Get-GitBlobBytes $sourceCommit $relative
    Assert-R23D50Closure (
        $bytes.Length -eq [long]$input.byte_length -and
        (Get-BytesSha256 $bytes) -ceq [string]$input.raw_sha256 -and
        (git -C $repoRoot rev-parse "$sourceCommit`:$relative").Trim() -ceq
            [string]$input.git_blob_oid
    ) "prospective source identity changed: $relative"
}

$attestationPayload = Assert-PathAndCas (
    [string]$closure.qualification.attestation_path
) ([string]$closure.qualification.attestation_sha256) (
    [long]$closure.qualification.attestation_byte_length
)
$adoptionPayload = Assert-PathAndCas (
    [string]$closure.qualification.adoption_path
) ([string]$closure.qualification.adoption_sha256) (
    [long]$closure.qualification.adoption_byte_length
)
$attestation = Get-Content -Raw -LiteralPath $attestationPayload |
    ConvertFrom-Json -Depth 100
$adoption = Get-Content -Raw -LiteralPath $adoptionPayload |
    ConvertFrom-Json -Depth 100
Assert-R23D50Closure (
    [string]$attestation.source.commit -ceq $sourceCommit -and
    [int]$attestation.global_gate_count -eq 12 -and
    [int]$attestation.lineage_gate_count -eq 2 -and
    [int]$attestation.campaign_gate_count -eq 3 -and
    @($attestation.gate_receipts).Count -eq 17 -and
    @($attestation.gate_receipts | Where-Object {
        [int]$_.physical_world_count -ne 0 -or
        [int]$_.physical_process_launch_count -ne 0
    }).Count -eq 0 -and
    [string]$adoption.source_commit -ceq $sourceCommit -and
    [bool]$adoption.physical_launch_prerequisite_satisfied -and
    -not [bool]$adoption.physical_acceptance_authority
) "qualification identity changed"

Assert-R23D50Closure (
    [string]$closure.prephysical_incident.source_commit -ceq
        "603f5894472d559c54333498b168b47164e5b4e6" -and
    [string]$closure.prephysical_incident.attempt_root -ceq $incidentRoot -and
    [string]$closure.prephysical_incident.failure_code -ceq
        "R23D50_PRODUCTION_CAS_BINDING_INVALID" -and
    [int]$closure.prephysical_incident.model_construction_count -eq 0 -and
    [int]$closure.prephysical_incident.world_attempt_count -eq 0 -and
    [int]$closure.prephysical_incident.world_build_count -eq 0 -and
    -not [bool]$closure.prephysical_incident.physical_identity_consumed -and
    -not [bool]$closure.prephysical_incident.same_source_commit_retry_permitted -and
    -not [bool]$closure.prephysical_incident.historical_incident_reclassified
) "prephysical incident boundary changed"

$rootArtifacts = [ordered]@{
    "physical-freeze.json" = $closure.physical_evidence.physical_freeze
    "attempt.json" = $closure.physical_evidence.attempt_authorization
    "authorization-preflights.json" =
        $closure.physical_evidence.production_authorization_preflights
    "terminal-paths.json" = $closure.physical_evidence.terminal_manifest
    "report.json" = $closure.physical_evidence.report
    "completion.json" = $closure.physical_evidence.completion
    "source-archive.zip" = $closure.physical_evidence.source_archive
}
$rootPayloads = @{}
foreach ($entry in $rootArtifacts.GetEnumerator()) {
    $rootPayloads[$entry.Key] = Assert-PathAndCas (
        (Join-Path $attemptRoot $entry.Key)
    ) ([string]$entry.Value.sha256) ([long]$entry.Value.byte_length)
}

$freeze = Get-Content -Raw -LiteralPath $rootPayloads["physical-freeze.json"] |
    ConvertFrom-Json -Depth 100
$attempt = Get-Content -Raw -LiteralPath $rootPayloads["attempt.json"] |
    ConvertFrom-Json -Depth 100
$authorization = @(Get-Content -Raw -LiteralPath (
    $rootPayloads["authorization-preflights.json"]
) | ConvertFrom-Json -Depth 100)
$terminalPaths = @(Get-Content -Raw -LiteralPath (
    $rootPayloads["terminal-paths.json"]
) | ConvertFrom-Json)
$report = Get-Content -Raw -LiteralPath $rootPayloads["report.json"] |
    ConvertFrom-Json -Depth 100
$completion = Get-Content -Raw -LiteralPath $rootPayloads["completion.json"] |
    ConvertFrom-Json -Depth 100
$evaluation = $report.complete_evaluation

Assert-R23D50Closure (
    [string]$freeze.source_commit -ceq $sourceCommit -and
    @($freeze.source_bindings).Count -eq 231 -and
    [bool]$freeze.source_bytes_consumed_by_build_equal_git_blobs -and
    -not [bool]$freeze.source_materialization.ambient_checkout_is_build_authority -and
    [string]$freeze.source_materialization.archive_raw_sha256 -ceq
        [string]$closure.runtime_materialization.source_archive_sha256 -and
    [string]$freeze.runtime_artifact.raw_sha256 -ceq
        [string]$closure.runtime_materialization.rapier_worker_release_sha256 -and
    [int]$freeze.runtime_artifact.build.source_date_epoch -eq 1786634770 -and
    -not [bool]$freeze.runtime_artifact.build.cargo_incremental -and
    [bool]$freeze.runtime_artifact.build.msvc_brepro -and
    [bool]$freeze.runtime_artifact.build.pdb_alt_path_bare_name -and
    -not [bool]$freeze.runtime_artifact.build.codegen_units_forced -and
    [int]$freeze.declared_matrix_world_count -eq 3
) "source or runtime materialization changed"

$sourceRoot = [string]$freeze.source_materialization.source_root
foreach ($binding in @($freeze.source_bindings)) {
    $relative = [string]$binding.path
    $bytes = Get-GitBlobBytes $sourceCommit $relative
    $materializedPath = Join-Path $sourceRoot $relative
    Assert-R23D50Closure (
        [bool]$binding.materialized_bytes_equal_git_blob -and
        [string]$binding.source_kind -ceq "git_archive_blob_exact_v1" -and
        (Get-BytesSha256 $bytes) -ceq [string]$binding.raw_sha256 -and
        (git -C $repoRoot rev-parse "$sourceCommit`:$relative").Trim() -ceq
            [string]$binding.git_blob_oid -and
        (Test-Path -LiteralPath $materializedPath -PathType Leaf) -and
        (Get-Sha256 $materializedPath) -ceq [string]$binding.raw_sha256
    ) "materialized source binding changed: $relative"
}

$canary = $freeze.production_retention_preflight
Assert-R23D50Closure (
    [bool]$canary.complete_cas_binding_verifier_exercised -and
    [bool]$canary.exact_production_cas_path_exercised -and
    [bool]$canary.exact_rust_to_python_to_powershell_to_artifact_store_route_exercised -and
    [bool]$canary.process_scoped_execution_policy_bypass_exercised -and
    [bool]$canary.rust_worker_outer_route_validated -and
    [int]$canary.ordinary_and_windows_extended_path_spelling_positive_control_count -eq 1 -and
    [int]$canary.wrong_existing_file_rejection_count -eq 1 -and
    [int]$canary.synthetic_trace_row_count -eq 2992 -and
    [int]$canary.model_construction_count -eq 0 -and
    [int]$canary.world_attempt_count -eq 0 -and
    [int]$canary.world_build_count -eq 0 -and
    -not [bool]$canary.physical_acceptance_authority -and
    [string]$canary.trace_retention.trace_artifact.sha256 -ceq
        "sha256:7c18c69f82758b8cae09e129683b8d074e87940abf080e05cd5c1477533df65d"
) "complete production canary changed"

Assert-R23D50Closure (
    [string]$attempt.attempt_id -ceq [string]$closure.attempt_id -and
    [bool]$attempt.production_retention_preflight_passed -and
    [bool]$attempt.one_shot_attempt_unconsumed -and
    $authorization.Count -eq 3 -and
    @($authorization | Where-Object {
        [bool]$_.authorization_passed -and
        [bool]$_.returned_before_model -and
        [int]$_.physical_process_launch_count -eq 0 -and
        [int]$_.world_build_count -eq 0
    }).Count -eq 3 -and
    $terminalPaths.Count -eq 3
) "attempt or per-cell authorization changed"

Assert-R23D50Closure (
    [string]$report.result_classification -ceq $classification -and
    [string]$evaluation.classification -ceq $classification -and
    [int]$evaluation.cell_count -eq 3 -and
    [bool]$evaluation.all_cells_execution_valid -and
    [bool]$evaluation.all_common_physical_gates_passed -and
    [bool]$evaluation.turning_measurement_passed -and
    @($evaluation.cell_evaluations | Where-Object {
        [bool]$_.execution_valid -and
        [bool]$_.common_physical_gate_passed -and
        @($_.failed_gate_ids).Count -eq 0 -and
        [int]$_.world_attempt_count -eq 1 -and
        [int]$_.world_build_count -eq 1
    }).Count -eq 3 -and
    [string]$completion.result_classification -ceq $classification -and
    [bool]$completion.one_shot_identity_consumed -and
    -not [bool]$completion.same_identity_rerun_allowed -and
    -not [bool]$completion.finite_three_engine_turning_candidate -and
    -not [bool]$completion.physical_acceptance_authority
) "official positive disposition changed"

for ($index = 0; $index -lt 3; $index++) {
    $cell = $report.ordered_matrix_cells[$index]
    $closedCell = $closure.ordered_cells[$index]
    Assert-R23D50Closure (
        [int]$cell.process_exit_code -eq 0 -and
        [string]$terminalPaths[$index] -ceq
            [string]$cell.terminal_entry_cas.payload_path -and
        [string]$cell.arm_id -ceq [string]$closedCell.arm_id -and
        [string]$cell.cell_id -ceq [string]$closedCell.cell_id
    ) "process or terminal order changed: $index"
    $terminalPayload = Assert-Cas (
        [string]$cell.terminal_entry_cas.sha256
    ) ([long]$cell.terminal_entry_cas.byte_length)
    $terminal = Get-Content -Raw -LiteralPath $terminalPayload |
        ConvertFrom-Json -Depth 100
    $trace = $terminal.trace_artifact
    $expectedTracePayload = Assert-Cas (
        [string]$trace.sha256
    ) ([long]$trace.byte_length)
    Assert-R23D50Closure (
        [string]$trace.sha256 -ceq [string]$closedCell.trace_sha256 -and
        [long]$trace.byte_length -eq [long]$closedCell.trace_byte_length -and
        (Get-Sha256 ([string]$trace.payload_path)) -ceq
            (Get-Sha256 $expectedTracePayload) -and
        [string]$terminal.schema_version -ceq
            "sporespore_qsdk_r23d50_engine_cell_report_v1" -and
        [string]$terminal.source_commit -ceq $sourceCommit -and
        [bool]$terminal.execution.integrity_passed -and
        [bool]$terminal.execution.trace_retained_before_terminal_entry -and
        [int]$terminal.execution.world_attempt_count -eq 1 -and
        [int]$terminal.execution.world_build_count -eq 1 -and
        [int]$terminal.measurements.controller_error_count -eq 0 -and
        [int]$terminal.measurements.nonfinite_observation_count -eq 0 -and
        [int]$terminal.measurements.actuator_application_mismatch_count -eq 0 -and
        [int]$terminal.measurements.torso_ground_contact_step_count -eq 0 -and
        [double]$terminal.measurements.final_forward_displacement_m -ge
            0.030123046875 -and
        [double]$terminal.measurements.maximum_tilt_rad -le 0.6 -and
        [double]$terminal.measurements.minimum_torso_height_m -ge
            0.2499708652072946 -and
        @($terminal.measurements.contact_cycle_count_by_limb.PSObject.Properties |
            Where-Object { [int]$_.Value -ge 2 }).Count -eq 4
    ) "retained live terminal changed: $($cell.cell_id)"
}

$measurement = $evaluation.cycle_integrated_measurement
Assert-Near ([double]$measurement.arms.reference_zero.cycle_shift_rad) `
    0.0025661495546947487 "reference shift changed"
Assert-Near ([double]$measurement.arms.positive_heading.cycle_shift_rad) `
    0.016544441316987724 "positive shift changed"
Assert-Near ([double]$measurement.arms.negative_heading.cycle_shift_rad) `
    -0.014735136859300405 "negative shift changed"
Assert-Near ([double]$measurement.positive_reference_conditioned_cycle_shift_rad) `
    0.013978291762292976 "conditioned positive changed"
Assert-Near ([double]$measurement.negative_reference_conditioned_cycle_shift_rad) `
    0.017301286413995153 "conditioned negative changed"
Assert-R23D50Closure (
    [bool]$measurement.gates.raw_signed_cycle_shift -and
    [bool]$measurement.gates.reference_conditioned_cycle_shift -and
    [bool]$measurement.passed
) "turning measurement changed"

# Re-run the pinned evaluator from the verified Git-blob-exact materialization.
$evaluationOutput = @(& python (
    Join-Path $sourceRoot (
        "sdk\turning\r23d50_rapier_cas_path_identity_replay_evaluator.py"
    )
) evaluate-complete --manifest (
    Join-Path $attemptRoot "terminal-paths.json"
) --source-commit $sourceCommit --repo-root $repoRoot 2>&1)
Assert-R23D50Closure ($LASTEXITCODE -eq 0) (
    "pinned evaluator failed: $($evaluationOutput -join ' | ')"
)
$marker = "QSDK_R23D50_COMPLETE_EVALUATION "
$line = @($evaluationOutput | Where-Object { $_.StartsWith($marker) })
Assert-R23D50Closure ($line.Count -eq 1) "pinned evaluator marker changed"
$recomputed = $line[0].Substring($marker.Length) |
    ConvertFrom-Json -Depth 100
Assert-R23D50Closure (
    [string]$recomputed.classification -ceq $classification -and
    [bool]$recomputed.all_cells_execution_valid -and
    [bool]$recomputed.all_common_physical_gates_passed -and
    [bool]$recomputed.turning_measurement_passed -and
    @($recomputed.cell_evaluations | Where-Object {
        [bool]$_.execution_valid -and
        @($_.failed_gate_ids).Count -eq 0
    }).Count -eq 3
) "pinned evaluator no longer reconstructs the positive result"

Assert-R23D50Closure (
    [bool]$closure.claims.r23d50_repaired_cas_path_identity_route_observed_successfully -and
    [bool]$closure.claims.finite_outcome_exposed_rapier_cas_path_identity_replay -and
    -not [bool]$closure.claims.fresh_rapier_turning_replication -and
    -not [bool]$closure.claims.portable_basic_turning -and
    -not [bool]$closure.claims.finite_three_engine_turning -and
    -not [bool]$closure.claims.q_sdk_r23_satisfied -and
    -not [bool]$closure.claims.cross_engine_equivalence -and
    -not [bool]$closure.claims.population_robustness -and
    -not [bool]$closure.claims.prone_to_standing -and
    -not [bool]$closure.claims.release_authorized -and
    -not [bool]$closure.claims.physical_acceptance_authority
) "claim boundary changed"

$completedAttempts = @(
    Get-ChildItem -LiteralPath $evidenceRoot -Directory |
        Where-Object {
            $_.Name -like "qsdk-r23d50-*" -and
            (Test-Path -LiteralPath (Join-Path $_.FullName "completion.json"))
        }
)
Assert-R23D50Closure (
    $completedAttempts.Count -eq 1 -and
    $completedAttempts[0].FullName -ceq $attemptRoot -and
    (Test-Path -LiteralPath $incidentRoot -PathType Container) -and
    -not (Test-Path -LiteralPath (Join-Path $incidentRoot "completion.json"))
) "R23D50 one-shot attempt count changed"

Write-Host (
    "QSDK_R23D50_CLOSURE_PASS classification=positive_exposed_replay " +
    "worlds=3 exits=3 walking=3 turning=True samefile=True " +
    "fresh=False three_engine=False release=False rerun=False"
)
