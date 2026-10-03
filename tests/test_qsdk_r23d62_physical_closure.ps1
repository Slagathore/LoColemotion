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
    "qsdk-r23d62-physical-20260825T055552Z-b784368a"
)
$qualificationRoot = Join-Path $evidenceRoot (
    "qsdk-r23d62-qualification-20260825T054144Z-b784368a"
)
$closurePath = Join-Path $repoRoot (
    "sdk\turning\r23d62_selected_profile_three_engine_turning_validation_closure_v1.json"
)
$auditPath = Join-Path $repoRoot "tests\test_qsdk_r23d62_physical_closure.ps1"
$sourceCommit = "b784368aae622924813aa1aa6e6143aa809f04fd"
$sourceTree = "28f99ad999a9f8457683f5603f4c076af2b82604"
$campaignId = "QSDK-R23D62-SELECTED-PROFILE-MATCHED-THREE-ENGINE-TURNING-VALIDATION"
$attemptId = "a2677a58f80b4b2aa73d306526836b14"
$closedStatus = (
    "closed_consumed_invalid_incomplete_before_first_world_" +
    "authorization_receipt_schema_projection_failure"
)
$expectedCells = @(
    "godot_jolt__s23167__selected_profile__reference_zero",
    "godot_jolt__s23167__selected_profile__positive_heading",
    "godot_jolt__s23167__selected_profile__negative_heading",
    "rapier_parry__s23167__selected_profile__reference_zero",
    "rapier_parry__s23167__selected_profile__positive_heading",
    "rapier_parry__s23167__selected_profile__negative_heading",
    "mujoco__s23167__selected_profile__reference_zero",
    "mujoco__s23167__selected_profile__positive_heading",
    "mujoco__s23167__selected_profile__negative_heading"
)

function Assert-R23D62Closure([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "QSDK-R23D62 CLOSURE: $Message" }
}

function Get-R23D62Sha256([string]$Path) {
    return "sha256:" + (
        Get-FileHash -LiteralPath $Path -Algorithm SHA256
    ).Hash.ToLowerInvariant()
}

function Get-R23D62BytesSha256([byte[]]$Bytes) {
    return "sha256:" + [Convert]::ToHexString(
        [Security.Cryptography.SHA256]::HashData($Bytes)
    ).ToLowerInvariant()
}

function Get-R23D62GitBlobBytes([string]$Commit, [string]$RelativePath) {
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
    Assert-R23D62Closure ($process.Start()) "could not start git cat-file"
    $memory = [IO.MemoryStream]::new()
    try {
        $process.StandardOutput.BaseStream.CopyTo($memory)
        $stderr = $process.StandardError.ReadToEnd()
        $process.WaitForExit()
        Assert-R23D62Closure ($process.ExitCode -eq 0) (
            "historical blob unavailable: $RelativePath; $stderr"
        )
        return ,([byte[]]$memory.ToArray())
    } finally {
        $memory.Dispose()
        $process.Dispose()
    }
}

function Assert-R23D62Cas([string]$Sha256, [long]$ByteLength) {
    Assert-R23D62Closure ($Sha256 -cmatch '^sha256:[0-9a-f]{64}$') (
        "invalid CAS digest: $Sha256"
    )
    $directory = Join-Path $artifactRoot $Sha256.Substring(7)
    $payload = Join-Path $directory "payload.bin"
    $manifestPath = Join-Path $directory "manifest.json"
    Assert-R23D62Closure (
        (Test-Path -LiteralPath $payload -PathType Leaf) -and
        (Test-Path -LiteralPath $manifestPath -PathType Leaf) -and
        (Get-Item -LiteralPath $payload).Length -eq $ByteLength -and
        (Get-R23D62Sha256 $payload) -ceq $Sha256
    ) "CAS payload changed: $Sha256"
    $manifest = Get-Content -Raw -LiteralPath $manifestPath |
        ConvertFrom-Json -Depth 20
    Assert-R23D62Closure (
        [string]$manifest.schema_version -ceq
            "sporespore_content_addressed_artifact_manifest_v1" -and
        [string]$manifest.algorithm -ceq "sha256" -and
        [string]$manifest.sha256 -ceq $Sha256 -and
        [long]$manifest.byte_length -eq $ByteLength -and
        [string]$manifest.payload_name -ceq "payload.bin"
    ) "CAS manifest changed: $Sha256"
    return $payload
}

function Assert-R23D62PathAndCas(
    [string]$Path,
    [string]$Sha256,
    [long]$ByteLength
) {
    $resolved = [IO.Path]::GetFullPath($Path)
    Assert-R23D62Closure (
        (Test-Path -LiteralPath $resolved -PathType Leaf) -and
        (Get-Item -LiteralPath $resolved).Length -eq $ByteLength -and
        (Get-R23D62Sha256 $resolved) -ceq $Sha256
    ) "retained artifact changed: $resolved"
    $payload = Assert-R23D62Cas $Sha256 $ByteLength
    Assert-R23D62Closure (
        (Get-R23D62Sha256 $payload) -ceq (Get-R23D62Sha256 $resolved)
    ) "retained artifact and CAS differ: $resolved"
    return $payload
}

function Find-R23D62NamedProperty($Value, [string]$Name) {
    if ($null -eq $Value) { return @() }
    $found = [Collections.Generic.List[object]]::new()
    if ($Value -is [pscustomobject]) {
        foreach ($property in $Value.PSObject.Properties) {
            if ([string]$property.Name -ceq $Name) {
                $found.Add($property.Value)
            }
            foreach ($nested in @(Find-R23D62NamedProperty $property.Value $Name)) {
                $found.Add($nested)
            }
        }
    } elseif (
        $Value -is [Collections.IEnumerable] -and
        $Value -isnot [string]
    ) {
        foreach ($item in $Value) {
            foreach ($nested in @(Find-R23D62NamedProperty $item $Name)) {
                $found.Add($nested)
            }
        }
    }
    return @($found)
}

function Test-R23D62ClosureVector($Value) {
    return (
        [string]$Value.status -ceq $closedStatus -and
        [string]$Value.source_commit -ceq $sourceCommit -and
        [string]$Value.source_tree_git_oid -ceq $sourceTree -and
        [string]$Value.attempt_id -ceq $attemptId -and
        [int]$Value.campaign_seed -eq 23167 -and
        [bool]$Value.campaign_identity_consumed -and
        -not [bool]$Value.same_identity_rerun_allowed -and
        -not [bool]$Value.replacement_or_selective_rerun_allowed -and
        -not [bool]$Value.physical_outcome_exposed -and
        -not [bool]$Value.held_out_seed_physical_outcome_exposed -and
        [bool]$Value.qualification.qualification_passed -and
        [bool]$Value.qualification.adoption_passed -and
        [int]$Value.declaration_and_zero_world_provenance.transitive_path_count -eq 221 -and
        [int]$Value.declaration_and_zero_world_provenance.transitive_edge_count -eq 219 -and
        [int]$Value.physical_evidence.complete_retained_file_population_count -eq 5 -and
        [bool]$Value.physical_evidence.one_shot_attempt_consumed -and
        [int]$Value.physical_evidence.world_build_count -eq 0 -and
        [string]$Value.failure_mechanism.failure_class -ceq
            "cross_engine_production_authorization_receipt_schema_projection_mismatch" -and
        [bool]$Value.failure_mechanism.godot_production_authorization_validated_complete_ordered_matrix -and
        [bool]$Value.failure_mechanism.godot_runtime_receipt_omitted_required_field -and
        [bool]$Value.failure_mechanism.rapier_production_authorization_validated_complete_ordered_matrix -and
        [bool]$Value.failure_mechanism.rapier_source_receipt_omitted_required_field -and
        [bool]$Value.failure_mechanism.mujoco_source_receipt_included_required_field -and
        -not [bool]$Value.failure_mechanism.physics_or_controller_failure -and
        [int]$Value.source_receipt_schema_conformance.population_size -eq 3 -and
        [bool]$Value.source_receipt_schema_conformance.population_compared_completely -and
        [double]$Value.source_receipt_schema_conformance.equivalence_margin -eq 0.0 -and
        [double]$Value.source_receipt_schema_conformance.non_inferiority_margin -eq 0.0 -and
        [int]$Value.source_receipt_schema_conformance.field_present_and_true_count -eq 1 -and
        [int]$Value.source_receipt_schema_conformance.field_missing_count -eq 2 -and
        -not [bool]$Value.source_receipt_schema_conformance.exact_conformance_passed -and
        -not [bool]$Value.official_result.scientific_result_exists -and
        [int]$Value.official_result.executed_cell_count -eq 0 -and
        -not [bool]$Value.official_result.finite_three_engine_turning -and
        -not [bool]$Value.official_result.q_sdk_r23_satisfied -and
        [bool]$Value.bounded_interpretation.zero_world_authorization_schema_defect_established -and
        -not [bool]$Value.claims.prone_to_standing -and
        -not [bool]$Value.claims.release_authorized
    )
}

Assert-R23D62Closure (
    (git -C $repoRoot rev-parse --show-toplevel).Trim().Replace('/', '\') -ceq
        $repoRoot -and
    (git -C $repoRoot remote get-url origin).Trim() -ceq
        "https://github.com/Slagathore/sporespore.git"
) "repository identity changed"

$closure = Get-Content -Raw -LiteralPath $closurePath |
    ConvertFrom-Json -Depth 100
Assert-R23D62Closure (
    [string]$closure.schema_version -ceq
        "sporespore_qsdk_r23d62_selected_profile_three_engine_turning_validation_closure_v1" -and
    [string]$closure.campaign_id -ceq $campaignId -and
    [string]$closure.gate_id -ceq "QSDK-R23D62" -and
    [string]$closure.release_gate_id -ceq "QSDK-R23" -and
    [string]$closure.physical_question_class -ceq "finite_decision" -and
    [string]$closure.source_conformance_question_class -ceq
        "equivalence_non_inferiority" -and
    (git -C $repoRoot rev-parse "$sourceCommit`^{tree}").Trim() -ceq $sourceTree -and
    (Test-R23D62ClosureVector $closure)
) "immutable disposition changed"

$expectedRelativePaths = @($closure.physical_evidence.files.relative_path | Sort-Object)
$actualRelativePaths = @(
    Get-ChildItem -LiteralPath $attemptRoot -Recurse -File |
        ForEach-Object {
            [IO.Path]::GetRelativePath($attemptRoot, $_.FullName).Replace('\', '/')
        } | Sort-Object
)
Assert-R23D62Closure (
    $actualRelativePaths.Count -eq 5 -and
    ($actualRelativePaths -join "`n") -ceq ($expectedRelativePaths -join "`n")
) "attempt-root file population changed"

$retained = @{}
foreach ($file in @($closure.physical_evidence.files)) {
    $path = Join-Path $attemptRoot ([string]$file.relative_path).Replace('/', '\')
    $retained[[string]$file.relative_path] = Assert-R23D62PathAndCas (
        $path
    ) ([string]$file.raw_sha256) ([long]$file.byte_length)
}
Assert-R23D62Closure (
    @($closure.physical_evidence.files.raw_sha256 | Select-Object -Unique).Count -eq 5
) "retained unique digest population changed"

$freeze = Get-Content -Raw -LiteralPath $retained["physical-freeze.json"] |
    ConvertFrom-Json -Depth 100
$attempt = Get-Content -Raw -LiteralPath $retained["attempt-authorization.json"] |
    ConvertFrom-Json -Depth 100
$completion = Get-Content -Raw -LiteralPath $retained["completion.json"] |
    ConvertFrom-Json -Depth 30
Assert-R23D62Closure (
    [string]$freeze.schema_version -ceq "sporespore_qsdk_r23d62_physical_freeze_v1" -and
    [string]$freeze.status -ceq "frozen_supervisor_only_physical_authorized" -and
    [string]$freeze.campaign_id -ceq $campaignId -and
    [string]$freeze.source_commit -ceq $sourceCommit -and
    [string]$freeze.source_tree_git_oid -ceq $sourceTree -and
    [bool]$freeze.dependency_inventory_complete -and
    [int]$freeze.dependency_inventory.transitive_path_count -eq 221 -and
    [int]$freeze.dependency_inventory.edge_count -eq 219 -and
    [bool]$freeze.dependency_inventory.checkout_bytes_equal_git_blobs -and
    [bool]$freeze.complete_zero_world_gate_passed -and
    [int]$freeze.zero_world_receipt.campaign_gate_count -eq 12 -and
    [int]$freeze.zero_world_receipt.worker_preflight_count -eq 9 -and
    [int]$freeze.zero_world_receipt.model_construction_count -eq 0 -and
    [int]$freeze.zero_world_receipt.world_attempt_count -eq 0 -and
    [int]$freeze.zero_world_receipt.world_build_count -eq 0 -and
    [int]$freeze.declared_world_count -eq 9 -and
    (@($freeze.ordered_matrix_cell_ids) -join "`n") -ceq ($expectedCells -join "`n") -and
    [bool]$attempt.single_use_supervisor_authorization -and
    [bool]$attempt.matrix_authorization_immutable_before_first_world -and
    [bool]$attempt.one_shot_attempt_unconsumed -and
    [string]$attempt.source_commit -ceq $sourceCommit -and
    [string]$attempt.attempt_id -ceq $attemptId -and
    (@($attempt.ordered_matrix_cell_ids) -join "`n") -ceq ($expectedCells -join "`n") -and
    [string]$completion.schema_version -ceq "sporespore_qsdk_r23d62_completion_v1" -and
    [string]$completion.status -ceq "invalid_or_incomplete_first_attempt" -and
    [string]$completion.source_commit -ceq $sourceCommit -and
    [bool]$completion.one_shot_attempt_consumed -and
    -not [bool]$completion.replacement_or_selective_rerun_permitted -and
    [string]$completion.failure_message -ceq
        "The property 'complete_ordered_nine_cell_matrix_validated' cannot be found on this object. Verify that the property exists." -and
    -not [bool]$completion.physical_acceptance_authority
) "freeze, attempt authorization, or completion changed"

$stdout = Get-Content -Raw -LiteralPath $retained[
    "authorization-preflight/godot_jolt__s23167__selected_profile__reference_zero/stdout.txt"
]
$marker = "QSDK_R23D62_GODOT_JOLT_AUTHORIZATION_PREFLIGHT "
$markerLines = @($stdout -split '\r?\n' | Where-Object {
    $_.StartsWith($marker, [StringComparison]::Ordinal)
})
Assert-R23D62Closure ($markerLines.Count -eq 1) "Godot authorization marker changed"
$receipt = $markerLines[0].Substring($marker.Length) | ConvertFrom-Json -Depth 30
Assert-R23D62Closure (
    [string]$receipt.schema_version -ceq
        "sporespore_qsdk_r23d62_godot_jolt_production_authorization_preflight_v1" -and
    [string]$receipt.campaign_id -ceq $campaignId -and
    [string]$receipt.cell_id -ceq $expectedCells[0] -and
    [string]$receipt.actual_production_authorization_function -ceq
        "_r23d62_physical_authorization" -and
    [bool]$receipt.authorization_passed -and
    [bool]$receipt.returned_before_model -and
    [int]$receipt.model_construction_count -eq 0 -and
    [int]$receipt.world_attempt_count -eq 0 -and
    [int]$receipt.world_build_count -eq 0 -and
    $receipt.PSObject.Properties.Name -cnotcontains
        "complete_ordered_nine_cell_matrix_validated"
) "Godot authorization receipt boundary changed"

Assert-R23D62Closure (
    -not (Test-Path -LiteralPath (Join-Path $attemptRoot "cells")) -and
    -not (Test-Path -LiteralPath (Join-Path $attemptRoot "terminal-paths.json")) -and
    -not (Test-Path -LiteralPath (Join-Path $attemptRoot "complete-evaluation.json")) -and
    -not (Test-Path -LiteralPath (Join-Path $attemptRoot "campaign-report.json"))
) "post-authorization physical output appeared"

$attestationPath = Assert-R23D62PathAndCas (
    Join-Path $qualificationRoot "attestation.json"
) ([string]$closure.qualification.attestation.raw_sha256) (
    [long]$closure.qualification.attestation.byte_length
)
$adoptionPath = Assert-R23D62PathAndCas (
    Join-Path $qualificationRoot "adoption.json"
) ([string]$closure.qualification.adoption.raw_sha256) (
    [long]$closure.qualification.adoption.byte_length
)
$attestation = Get-Content -Raw -LiteralPath $attestationPath |
    ConvertFrom-Json -Depth 100
$adoption = Get-Content -Raw -LiteralPath $adoptionPath |
    ConvertFrom-Json -Depth 100
Assert-R23D62Closure (
    [string]$attestation.status -ceq
        "campaign_local_godot_including_qualification_passed" -and
    [string]$attestation.campaign_id -ceq $campaignId -and
    [string]$attestation.source.commit -ceq $sourceCommit -and
    [string]$attestation.source.tree_git_oid -ceq $sourceTree -and
    [bool]$attestation.source.clean_pushed_live -and
    [int]$attestation.global_gate_count -eq 12 -and
    [int]$attestation.lineage_gate_count -eq 7 -and
    [int]$attestation.campaign_gate_count -eq 3 -and
    [int]$attestation.executed_gate_count -eq 22 -and
    @($attestation.gate_receipts).Count -eq 22 -and
    @($attestation.gate_receipts | Where-Object {
        -not [bool]$_.passed -or [int]$_.physical_world_count -ne 0 -or
        [int]$_.physical_process_launch_count -ne 0
    }).Count -eq 0 -and
    [string]$adoption.status -ceq
        "commissioned_campaign_local_qualification_adopted_for_physical_launch" -and
    [string]$adoption.source_commit -ceq $sourceCommit -and
    [string]$adoption.source_tree_git_oid -ceq $sourceTree -and
    [int]$adoption.gate_cas_object_count -eq 66 -and
    [bool]$adoption.physical_launch_prerequisite_satisfied -and
    -not [bool]$adoption.physical_acceptance_authority -and
    -not [bool]$adoption.release_authority
) "qualification or adoption changed"

$sourcePaths = @(
    "sdk/run_qsdk_r23d62_supervisor.ps1",
    "tests/test_sdk_qsdk_r23d62_godot_jolt_physical_worker.gd",
    "sdk/adapters/rapier/src/qsdk_r23d62_rapier_worker.rs",
    "sdk/adapters/rapier/src/qsdk_r23d3_phase_balanced/r23d27_physical.rs",
    "sdk/adapters/mujoco/sporespore_mujoco_adapter/qsdk_r23d62_selected_profile_turning.py"
)
$bindingByPath = @{}
foreach ($binding in @($freeze.source_bindings)) {
    $bindingByPath[[string]$binding.path] = [string]$binding.raw_sha256
}
$sourceText = @{}
foreach ($relative in $sourcePaths) {
    $bytes = Get-R23D62GitBlobBytes $sourceCommit $relative
    Assert-R23D62Closure (
        $bindingByPath.ContainsKey($relative) -and
        (Get-R23D62BytesSha256 $bytes) -ceq $bindingByPath[$relative]
    ) "consumed source binding changed: $relative"
    $sourceText[$relative] = [Text.Encoding]::UTF8.GetString($bytes)
}
$supervisorText = $sourceText[$sourcePaths[0]]
$godotText = $sourceText[$sourcePaths[1]]
$rapierWorkerText = $sourceText[$sourcePaths[2]]
$rapierPhysicalText = $sourceText[$sourcePaths[3]]
$mujocoText = $sourceText[$sourcePaths[4]]
Assert-R23D62Closure (
    $supervisorText.Contains('authorizationReceipt.complete_ordered_nine_cell_matrix_validated') -and
    $godotText.Contains('freeze.get("ordered_matrix_cell_ids", []) == expected_cells') -and
    $godotText.Contains('attempt.get("ordered_matrix_cell_ids", []) == expected_cells') -and
    -not $godotText.Contains('"complete_ordered_nine_cell_matrix_validated"') -and
    $rapierPhysicalText.Contains('freeze["ordered_matrix_cell_ids"] == json!(expected_cells)') -and
    $rapierPhysicalText.Contains('attempt["ordered_matrix_cell_ids"] == json!(r23d62_expected_matrix_cell_ids())') -and
    $rapierWorkerText.Contains('run_qsdk_r23d62_rapier_authorization_preflight') -and
    -not $rapierWorkerText.Contains('complete_ordered_nine_cell_matrix_validated') -and
    -not $rapierPhysicalText.Contains('complete_ordered_nine_cell_matrix_validated') -and
    $mujocoText.Contains('freeze.get("ordered_matrix_cell_ids") == _expected_matrix_cell_ids()') -and
    $mujocoText.Contains('attempt.get("ordered_matrix_cell_ids") == _expected_matrix_cell_ids()') -and
    $mujocoText.Contains('"complete_ordered_nine_cell_matrix_validated": True')
) "complete three-producer source-schema diagnosis changed"

$mutations = @(
    { param($v) $v.status = "closed_positive" },
    { param($v) $v.source_commit = "0" * 40 },
    { param($v) $v.attempt_id = "wrong" },
    { param($v) $v.campaign_identity_consumed = $false },
    { param($v) $v.same_identity_rerun_allowed = $true },
    { param($v) $v.replacement_or_selective_rerun_allowed = $true },
    { param($v) $v.physical_outcome_exposed = $true },
    { param($v) $v.qualification.adoption_passed = $false },
    { param($v) $v.declaration_and_zero_world_provenance.transitive_path_count = 220 },
    { param($v) $v.physical_evidence.complete_retained_file_population_count = 4 },
    { param($v) $v.physical_evidence.world_build_count = 1 },
    { param($v) $v.failure_mechanism.physics_or_controller_failure = $true },
    { param($v) $v.source_receipt_schema_conformance.population_compared_completely = $false },
    { param($v) $v.source_receipt_schema_conformance.equivalence_margin = 1 },
    { param($v) $v.source_receipt_schema_conformance.field_missing_count = 1 },
    { param($v) $v.source_receipt_schema_conformance.exact_conformance_passed = $true },
    { param($v) $v.official_result.scientific_result_exists = $true },
    { param($v) $v.official_result.executed_cell_count = 1 },
    { param($v) $v.official_result.finite_three_engine_turning = $true },
    { param($v) $v.official_result.q_sdk_r23_satisfied = $true },
    { param($v) $v.claims.prone_to_standing = $true },
    { param($v) $v.claims.release_authorized = $true }
)
$mutationRejectionCount = 0
foreach ($mutation in $mutations) {
    $candidate = $closure | ConvertTo-Json -Depth 100 |
        ConvertFrom-Json -Depth 100
    & $mutation $candidate
    if (-not (Test-R23D62ClosureVector $candidate)) {
        $mutationRejectionCount++
    }
}
Assert-R23D62Closure ($mutationRejectionCount -eq $mutations.Count) (
    "closure semantic mutation controls changed"
)

$releaseContract = Get-Content -Raw -LiteralPath (
    Join-Path $repoRoot "sdk\release\quadruped_release_contract.json"
) | ConvertFrom-Json -Depth 100
$supportMatrix = Get-Content -Raw -LiteralPath (
    Join-Path $repoRoot "sdk\release\quadruped_support_matrix.json"
) | ConvertFrom-Json -Depth 100
$contractRecords = @(Find-R23D62NamedProperty $releaseContract "closed_r23d62_attempt")
$matrixRecords = @(Find-R23D62NamedProperty $supportMatrix "closed_r23d62_attempt")
$closureHash = Get-R23D62Sha256 $closurePath
$auditHash = Get-R23D62Sha256 $auditPath
Assert-R23D62Closure (
    $contractRecords.Count -eq 1 -and $matrixRecords.Count -eq 1
) "release closure record cardinality changed"
foreach ($record in @($contractRecords[0], $matrixRecords[0])) {
    Assert-R23D62Closure (
        [string]$record.status -ceq $closedStatus -and
        [string]$record.closure_path -ceq
            "sdk/turning/r23d62_selected_profile_three_engine_turning_validation_closure_v1.json" -and
        [string]$record.closure_raw_sha256 -ceq $closureHash -and
        [string]$record.closure_audit_path -ceq
            "tests/test_qsdk_r23d62_physical_closure.ps1" -and
        [string]$record.closure_audit_raw_sha256 -ceq $auditHash -and
        [string]$record.physical_source_commit -ceq $sourceCommit -and
        [string]$record.attempt_id -ceq $attemptId -and
        [int]$record.declared_world_count -eq 9 -and
        [int]$record.world_attempt_count -eq 0 -and
        [int]$record.world_build_count -eq 0 -and
        [int]$record.executed_cell_count -eq 0 -and
        [bool]$record.one_shot_attempt_consumed -and
        -not [bool]$record.same_identity_rerun_allowed -and
        -not [bool]$record.finite_three_engine_turning -and
        -not [bool]$record.q_sdk_r23_satisfied -and
        -not [bool]$record.prone_to_standing -and
        -not [bool]$record.release_authorized
    ) "release closure boundary changed"
}

$catalog = Get-Content -Raw -LiteralPath (
    Join-Path $repoRoot "sdk\workbench\experiment_catalog.json"
) | ConvertFrom-Json -Depth 100
$workbenchRuns = @($catalog.runs | Where-Object {
    [string]$_.id -ceq "qsdk_r23d62_physical_closure"
})
Assert-R23D62Closure (
    $workbenchRuns.Count -eq 1 -and
    [string]$workbenchRuns[0].kind -ceq "closure_audit" -and
    [string]$workbenchRuns[0].world_policy -ceq "retained_evidence_only" -and
    [string]$workbenchRuns[0].risk -ceq "safe" -and
    [string]$workbenchRuns[0].runner_path -ceq
        "tests/test_qsdk_r23d62_physical_closure.ps1" -and
    @($workbenchRuns[0].arguments).Count -eq 0 -and
    @($workbenchRuns[0].proofs).Count -eq 2 -and
    [string]$workbenchRuns[0].proofs[0].expected_sha256 -ceq
        $closureHash.Substring(7) -and
    [string]$workbenchRuns[0].proofs[1].expected_sha256 -ceq
        $auditHash.Substring(7)
) "workbench closure exposure changed"

$attempts = @(Get-ChildItem -LiteralPath $evidenceRoot -Directory | Where-Object {
    $_.Name -like "qsdk-r23d62-physical-*" -and
    (Test-Path -LiteralPath (Join-Path $_.FullName "attempt-authorization.json") -PathType Leaf)
})
Assert-R23D62Closure (
    $attempts.Count -eq 1 -and
    [IO.Path]::GetFullPath($attempts[0].FullName) -ceq
        [IO.Path]::GetFullPath($attemptRoot)
) "R23D62 one-shot physical attempt count changed"

Write-Host (
    "QSDK_R23D62_PHYSICAL_CLOSURE_PASS classification=invalid_incomplete " +
    "attempt_consumed=True files=5 auth_receipts=1 cells=0 models=0 worlds=0 " +
    "schema_population=3 schema_present=1 schema_missing=2 exact_margin=0 " +
    "mutations=$mutationRejectionCount rerun=False turning_result=False " +
    "qsdk_r23=False prone=False physical_authority=False release=False"
)
