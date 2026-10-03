#requires -Version 7.0

[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$contractPath = Join-Path $repoRoot "sdk\trace_analysis\godot_actuator_phase_observation_contract_v1.json"
$releasePath = Join-Path $repoRoot "sdk\release\quadruped_release_contract.json"
$supportPath = Join-Path $repoRoot "sdk\release\quadruped_support_matrix.json"
$runnerPath = Join-Path $repoRoot "sdk\run_conformance.ps1"

function Assert-Exact([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

function Get-RawSha256([string]$Path) {
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Get-GitBlobRawSha256 {
    param(
        [Parameter(Mandatory = $true)][string]$Commit,
        [Parameter(Mandatory = $true)][string]$RepoRelativePath
    )

    Assert-Exact (
        $RepoRelativePath -cmatch "^[A-Za-z0-9_./-]+$" -and
        -not $RepoRelativePath.Contains("..", [StringComparison]::Ordinal)
    ) "Historical source path is not repository-relative: $RepoRelativePath"

    $objectId = (& git -C $repoRoot rev-parse "$Commit`:$RepoRelativePath").Trim()
    Assert-Exact ($LASTEXITCODE -eq 0) (
        "Cannot resolve historical Git blob: $Commit`:$RepoRelativePath"
    )

    $startInfo = [Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = "git"
    $startInfo.WorkingDirectory = $repoRoot
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    foreach ($argument in @("cat-file", "blob", $objectId)) {
        [void]$startInfo.ArgumentList.Add($argument)
    }

    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $startInfo
    Assert-Exact ($process.Start()) "Could not start git cat-file."
    $memory = [IO.MemoryStream]::new()
    try {
        $process.StandardOutput.BaseStream.CopyTo($memory)
        $stderr = $process.StandardError.ReadToEnd()
        $process.WaitForExit()
        Assert-Exact ($process.ExitCode -eq 0) (
            "Cannot read historical Git blob $RepoRelativePath`: $stderr"
        )
        return [Convert]::ToHexString(
            [Security.Cryptography.SHA256]::HashData($memory.ToArray())
        ).ToLowerInvariant()
    } finally {
        $memory.Dispose()
        $process.Dispose()
    }
}

function Find-ObjectsWithKey {
    param(
        [AllowNull()]$Value,
        [Parameter(Mandatory = $true)][string]$Key
    )

    $found = @()
    if ($null -eq $Value) { return $found }
    if ($Value -is [System.Collections.IDictionary]) {
        if ($Value.Contains($Key)) { $found += ,$Value }
        foreach ($child in $Value.Values) {
            $found += @(Find-ObjectsWithKey -Value $child -Key $Key)
        }
    } elseif (
        $Value -is [System.Collections.IEnumerable] -and
        $Value -isnot [string]
    ) {
        foreach ($child in $Value) {
            $found += @(Find-ObjectsWithKey -Value $child -Key $Key)
        }
    }
    return $found
}

foreach ($path in @($contractPath, $releasePath, $supportPath, $runnerPath)) {
    Assert-Exact (Test-Path -LiteralPath $path -PathType Leaf) "Missing authority: $path"
}

$contract = Get-Content -LiteralPath $contractPath -Raw |
    ConvertFrom-Json -AsHashtable -Depth 64
$release = Get-Content -LiteralPath $releasePath -Raw |
    ConvertFrom-Json -AsHashtable -Depth 128
$support = Get-Content -LiteralPath $supportPath -Raw |
    ConvertFrom-Json -AsHashtable -Depth 128

$releaseParents = @(Find-ObjectsWithKey -Value $release -Key "closed_r23d53_attempt")
$supportParents = @(Find-ObjectsWithKey -Value $support -Key "closed_r23d53_attempt")
Assert-Exact ($releaseParents.Count -eq 1) "Release contract must expose exactly one R23D53 block."
Assert-Exact ($supportParents.Count -eq 1) "Support matrix must expose exactly one R23D53 block."
$releaseR53 = $releaseParents[0]["closed_r23d53_attempt"]
$supportR53 = $supportParents[0]["closed_r23d53_attempt"]

Assert-Exact (
    [string]$contract["schema_version"] -ceq
        "sporespore_godot_actuator_phase_observation_contract_v1" -and
    [string]$contract["contract_id"] -ceq
        "QSDK-GODOT-ACTUATOR-PHASE-OBSERVATION-V1" -and
    [string]$contract["status"] -ceq
        "prospective_zero_world_instrumentation_development" -and
    [string]$contract["question_class"] -ceq "development"
) "Actuator-phase observation contract identity changed."

$source = $contract["source_boundary"]
$runtime = $contract["runtime_api_provenance"]
$route = $contract["production_route"]
$adequacy = $contract["threshold_and_adequacy_argument"]
$controls = $contract["negative_controls"]
$execution = $contract["execution_boundary"]
$nonclaims = $contract["nonclaims"]

Assert-Exact (
    [string]$source["parent_commit"] -ceq
        "2047ef092f52d907d44df66c2dcd6946e2e7e07a" -and
    -not [bool]$source["parent_outcome_rewritten"] -and
    -not [bool]$source["physical_successor_opened"]
) "The prospective source boundary no longer preserves the closed R53 parent."
Assert-Exact (
    [string]$runtime["commissioned_runtime_observed_by_preflight"] -ceq
        "Godot 4.7.stable.official" -and
    [bool]$runtime["configured_parameter_readback_only"] -and
    -not [bool]$runtime["measured_motor_torque_available"] -and
    -not [bool]$runtime["measured_motor_impulse_available"]
) "Configured Godot motor readbacks were inflated into measured response."
Assert-Exact (
    [string]$route["application_receipt_schema"] -ceq
        "sporespore_godot_jolt_full_authority_application_receipt_v1" -and
    [string]$route["observation_schema"] -ceq
        "sporespore_godot_jolt_actuator_phase_observation_v1"
) "Production observation schema identity changed."
Assert-Exact (
    -not [bool]$adequacy["observed_r23d53_values_used_to_set_thresholds"] -and
    [int]$adequacy["empirical_acceptance_threshold_count"] -eq 0 -and
    [double]$adequacy["numeric_tolerance"] -eq 2.5e-7 -and
    -not [bool]$adequacy["population_claim_authorized"] -and
    -not [bool]$adequacy["turning_mechanism_selected"] -and
    -not [bool]$adequacy["physical_acceptance_authority"]
) "Threshold, adequacy, or population authority changed."

$requiredControls = @(
    "wrong_observation_schema_rejected",
    "application_order_mutation_rejected",
    "application_impulse_readback_mutation_rejected",
    "retained_target_readback_mutation_rejected",
    "retained_impulse_readback_mutation_rejected",
    "retained_actuator_order_mutation_rejected",
    "retained_phase_mutation_rejected",
    "retained_before_contact_mutation_rejected",
    "retained_after_contact_mutation_rejected",
    "retained_limb_identity_mutation_rejected"
)
foreach ($control in $requiredControls) {
    Assert-Exact ([bool]$controls[$control]) "Negative control is not required: $control"
}
Assert-Exact (
    [int]$execution["unparented_hinge_object_count"] -eq 8 -and
    [int]$execution["scene_tree_insertion_count"] -eq 0 -and
    [int]$execution["model_construction_count"] -eq 0 -and
    [int]$execution["world_attempt_count"] -eq 0 -and
    [int]$execution["world_build_count"] -eq 0 -and
    -not [bool]$execution["physics_state_modified"] -and
    -not [bool]$execution["physical_work_authorized"] -and
    -not [bool]$execution["r23d54_or_successor_authorized"]
) "The zero-world execution boundary changed."
foreach ($claim in @(
    "r23d53_verdict_changed",
    "actuator_cause_identified",
    "contact_phase_cause_identified",
    "measured_torque_claimed",
    "measured_impulse_claimed",
    "godot_turning_claimed",
    "cross_engine_equivalence_claimed",
    "release_gate_satisfied"
)) {
    Assert-Exact (-not [bool]$nonclaims[$claim]) "Nonclaim became true: $claim"
}

$mirroredKeys = @(
    "postclosure_next_zero_world_actuator_and_contact_phase_schema_required",
    "postclosure_actuator_phase_observation_contract_status",
    "postclosure_actuator_phase_observation_question_class",
    "postclosure_actuator_phase_observation_contract_path",
    "postclosure_actuator_phase_observation_contract_raw_sha256",
    "postclosure_actuator_phase_observation_contract_source_commit",
    "postclosure_actuator_phase_observation_audit_path",
    "postclosure_actuator_phase_observation_audit_raw_sha256",
    "postclosure_actuator_phase_observation_audit_original_raw_sha256",
    "postclosure_actuator_phase_observation_test_path",
    "postclosure_actuator_phase_observation_test_raw_sha256",
    "postclosure_actuator_phase_observation_test_source_commit",
    "postclosure_actuator_phase_observation_adapter_path",
    "postclosure_actuator_phase_observation_adapter_raw_sha256",
    "postclosure_actuator_phase_observation_adapter_source_commit",
    "postclosure_actuator_phase_observation_trace_composer_path",
    "postclosure_actuator_phase_observation_trace_composer_raw_sha256",
    "postclosure_actuator_phase_observation_trace_composer_source_commit",
    "postclosure_actuator_phase_observation_historical_source_binding_repair",
    "postclosure_actuator_phase_observation_historical_git_binding_count",
    "postclosure_actuator_phase_observation_live_checkout_binding_count",
    "postclosure_actuator_phase_observation_result_reinterpreted_by_binding_repair",
    "postclosure_actuator_phase_observation_threshold_changed_by_binding_repair",
    "postclosure_actuator_phase_observation_parent_commit",
    "postclosure_actuator_phase_observation_schema_version",
    "postclosure_actuator_phase_application_receipt_schema_version",
    "postclosure_actuator_phase_runtime",
    "postclosure_actuator_phase_configured_parameter_readback_only",
    "postclosure_actuator_phase_measured_motor_torque_available",
    "postclosure_actuator_phase_measured_motor_impulse_available",
    "postclosure_actuator_phase_numeric_tolerance",
    "postclosure_actuator_phase_numeric_tolerance_fitted_from_r23d53",
    "postclosure_actuator_phase_maximum_target_velocity_readback_error_rad_s",
    "postclosure_actuator_phase_maximum_impulse_readback_error_nms",
    "postclosure_actuator_phase_validated_application_count",
    "postclosure_actuator_phase_validated_limb_count",
    "postclosure_actuator_phase_production_receipt_mutation_rejection_count",
    "postclosure_actuator_phase_retained_row_mutation_rejection_count",
    "postclosure_actuator_phase_wrong_schema_rejected",
    "postclosure_actuator_phase_scene_tree_insertion_count",
    "postclosure_actuator_phase_model_construction_count",
    "postclosure_actuator_phase_world_attempt_count",
    "postclosure_actuator_phase_world_build_count",
    "postclosure_actuator_phase_population_claim_authorized",
    "postclosure_actuator_phase_physical_acceptance_authority",
    "postclosure_actuator_phase_r23d54_or_successor_authorized"
)
foreach ($key in $mirroredKeys) {
    Assert-Exact ($releaseR53.Contains($key)) "Release R53 block is missing $key."
    Assert-Exact ($supportR53.Contains($key)) "Support R53 block is missing $key."
    Assert-Exact (
        ([string]$releaseR53[$key] -ceq [string]$supportR53[$key])
    ) "Release/support R53 values differ for $key."
}

Assert-Exact (
    [string]$releaseR53[
        "postclosure_actuator_phase_observation_historical_source_binding_repair"
    ] -ceq "pinned_git_blob_repair_without_result_or_threshold_change" -and
    [int]$releaseR53[
        "postclosure_actuator_phase_observation_historical_git_binding_count"
    ] -eq 4 -and
    [int]$releaseR53[
        "postclosure_actuator_phase_observation_live_checkout_binding_count"
    ] -eq 1 -and
    -not [bool]$releaseR53[
        "postclosure_actuator_phase_observation_result_reinterpreted_by_binding_repair"
    ] -and
    -not [bool]$releaseR53[
        "postclosure_actuator_phase_observation_threshold_changed_by_binding_repair"
    ]
) "Historical-source binding repair metadata changed."

$historicalBindings = @(
    @(
        "postclosure_actuator_phase_observation_contract_path",
        "postclosure_actuator_phase_observation_contract_raw_sha256",
        "postclosure_actuator_phase_observation_contract_source_commit"
    ),
    @(
        "postclosure_actuator_phase_observation_test_path",
        "postclosure_actuator_phase_observation_test_raw_sha256",
        "postclosure_actuator_phase_observation_test_source_commit"
    ),
    @(
        "postclosure_actuator_phase_observation_adapter_path",
        "postclosure_actuator_phase_observation_adapter_raw_sha256",
        "postclosure_actuator_phase_observation_adapter_source_commit"
    ),
    @(
        "postclosure_actuator_phase_observation_trace_composer_path",
        "postclosure_actuator_phase_observation_trace_composer_raw_sha256",
        "postclosure_actuator_phase_observation_trace_composer_source_commit"
    )
)
foreach ($binding in $historicalBindings) {
    $relativePath = [string]$releaseR53[$binding[0]]
    $boundPath = Join-Path $repoRoot $relativePath
    $expectedHash = ([string]$releaseR53[$binding[1]]).Replace("sha256:", "")
    $sourceCommit = [string]$releaseR53[$binding[2]]
    Assert-Exact (Test-Path -LiteralPath $boundPath -PathType Leaf) (
        "Historical source path is absent from the live tree: $boundPath"
    )
    Assert-Exact (
        (Get-GitBlobRawSha256 -Commit $sourceCommit -RepoRelativePath $relativePath) -ceq
            $expectedHash
    ) "Historical Git blob hash mismatch for $sourceCommit`:$relativePath"
}

$auditPath = Join-Path $repoRoot (
    [string]$releaseR53["postclosure_actuator_phase_observation_audit_path"]
)
$auditExpectedHash = ([string]$releaseR53[
    "postclosure_actuator_phase_observation_audit_raw_sha256"
]).Replace("sha256:", "")
$auditOriginalHash = ([string]$releaseR53[
    "postclosure_actuator_phase_observation_audit_original_raw_sha256"
]).Replace("sha256:", "")
Assert-Exact (Test-Path -LiteralPath $auditPath -PathType Leaf) (
    "Live audit is missing: $auditPath"
)
Assert-Exact (
    (Get-RawSha256 $auditPath) -ceq $auditExpectedHash -and
    $auditOriginalHash -ceq
        "4a85019ee25ce11ba1670364e0ce16c55ba41111066b80996221162f5288f55e" -and
    $auditExpectedHash -cne $auditOriginalHash
) "Live audit binding or retained original audit digest changed."

foreach ($binding in @(
    @(
        "postclosure_actuator_phase_observation_contract_source_commit",
        "d60e6f16338e609c1c29237cdc837da35afb4973"
    ),
    @(
        "postclosure_actuator_phase_observation_test_source_commit",
        "d60e6f16338e609c1c29237cdc837da35afb4973"
    ),
    @(
        "postclosure_actuator_phase_observation_adapter_source_commit",
        "d60e6f16338e609c1c29237cdc837da35afb4973"
    ),
    @(
        "postclosure_actuator_phase_observation_trace_composer_source_commit",
        "0d173d385f22fb8a30e7cc2234be8b17799512d9"
    )
)) {
    Assert-Exact (
        [string]$releaseR53[$binding[0]] -ceq [string]$binding[1]
    ) "Historical source commit changed: $($binding[0])"
}

Assert-Exact (
    [int]$releaseR53["postclosure_actuator_phase_validated_application_count"] -eq 8 -and
    [int]$releaseR53["postclosure_actuator_phase_validated_limb_count"] -eq 4 -and
    [int]$releaseR53["postclosure_actuator_phase_production_receipt_mutation_rejection_count"] -eq 2 -and
    [int]$releaseR53["postclosure_actuator_phase_retained_row_mutation_rejection_count"] -eq 7 -and
    [bool]$releaseR53["postclosure_actuator_phase_wrong_schema_rejected"] -and
    [double]$releaseR53["postclosure_actuator_phase_maximum_target_velocity_readback_error_rad_s"] -eq 1.15736031425229e-7 -and
    [double]$releaseR53["postclosure_actuator_phase_maximum_impulse_readback_error_nms"] -eq 1.85094532756391e-9 -and
    [int]$releaseR53["postclosure_actuator_phase_world_build_count"] -eq 0 -and
    -not [bool]$releaseR53["postclosure_actuator_phase_physical_acceptance_authority"] -and
    -not [bool]$releaseR53["postclosure_actuator_phase_r23d54_or_successor_authorized"]
) "The finite qualified observation boundary changed."

$runner = Get-Content -LiteralPath $runnerPath -Raw
Assert-Exact (
    $runner.Contains("test_godot_actuator_phase_observation_contract.ps1") -and
    $runner.Contains("test_sdk_godot_actuator_phase_observation.gd")
) "Normal conformance does not require both actuator-phase audits."

$contractHash = Get-RawSha256 $contractPath
Write-Host (
    "GODOT_ACTUATOR_PHASE_OBSERVATION_SOURCE_CONTRACT_PASS " +
    "question=development actuators=8 limbs=4 receipt_mutations=2 " +
    "row_mutations=7 historical_git_bindings=4 live_bindings=1 " +
    "binding_repair=True worlds=0 physical_authority=False " +
    "contract_sha256=sha256:$contractHash"
)
