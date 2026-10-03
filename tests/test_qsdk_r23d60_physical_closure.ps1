#requires -Version 7.0

[CmdletBinding()]
param(
    [string]$Python = "python"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$expectedRoot = [IO.Path]::GetFullPath(
    "C:\Users\Cole\CodeStuff\games\SporeSpore"
)
$expectedRemote = "https://github.com/Slagathore/sporespore.git"
$evidenceRoot = "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence"
$artifactRoot = Join-Path $evidenceRoot "artifacts\sha256"
$closurePath = Join-Path $repoRoot (
    "sdk\turning\r23d60_godot_fixture_knee_held_out_turning_validation_closure_v1.json"
)
$auditPath = [IO.Path]::GetFullPath($PSCommandPath)
$sourceCommit = "3d884af6dc0a15aa9bd2cde15de4535a24bb44a2"
$sourceTree = "980eac3511c531f7d93863bfd421dc21d46e1075"
$initialQualificationCommit = "66b7ea6d1e37ff1e00252571c9253beffc8a916e"
$initialQualificationTree = "d571bb344e709a8aae78b7441b4bf1da4b86265e"
$campaignId = (
    "QSDK-R23D60-GODOT-KNEE-SOURCE-FROZEN-PROFILE-" +
    "HELD-OUT-TURNING-VALIDATION"
)
$attemptId = "e83966133e6e4f2c955306d6f843f308"
$classification = (
    "valid_complete_positive_exact_held_out_godot_jolt_turning_validation"
)
$closedStatus = (
    "closed_consumed_valid_complete_positive_exact_held_out_godot_jolt_" +
    "turning_validation"
)
$attemptRoot = Join-Path $evidenceRoot "qsdk-r23d60-physical-20260816T000359Z"
$failedQualificationRoot = Join-Path $evidenceRoot (
    "qsdk-r23d60-qualification-20260815T234728Z"
)
$expectedCellIds = @(
    "godot_jolt__s21516__portable_hip__fixture_knee__reference_zero",
    "godot_jolt__s21516__portable_hip__fixture_knee__positive_heading",
    "godot_jolt__s21516__portable_hip__fixture_knee__negative_heading"
)

function Assert-R23D60Closure([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "QSDK-R23D60 closure: $Message" }
}

function Get-R23D60Sha256([string]$Path) {
    return "sha256:" + (
        Get-FileHash -LiteralPath $Path -Algorithm SHA256
    ).Hash.ToLowerInvariant()
}

function Get-R23D60BytesSha256([byte[]]$Bytes) {
    $stream = [IO.MemoryStream]::new($Bytes, $false)
    try {
        return "sha256:" + [Convert]::ToHexString(
            [Security.Cryptography.SHA256]::HashData($stream)
        ).ToLowerInvariant()
    } finally { $stream.Dispose() }
}

function Get-R23D60GitBlobBytes([string]$Commit, [string]$RelativePath) {
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
    Assert-R23D60Closure ($process.Start()) "could not start git cat-file"
    $memory = [IO.MemoryStream]::new()
    try {
        $process.StandardOutput.BaseStream.CopyTo($memory)
        $stderr = $process.StandardError.ReadToEnd()
        $process.WaitForExit()
        Assert-R23D60Closure ($process.ExitCode -eq 0) (
            "historical blob unavailable: $RelativePath; $stderr"
        )
        return ,([byte[]]$memory.ToArray())
    } finally {
        $memory.Dispose()
        $process.Dispose()
    }
}

function Add-R23D60CasReceipts(
    $Value,
    [Collections.Generic.List[object]]$Receipts
) {
    if ($null -eq $Value) { return }
    if ($Value -is [Management.Automation.PSCustomObject]) {
        $schema = $Value.PSObject.Properties["schema_version"]
        if (
            $null -ne $schema -and
            [string]$schema.Value -ceq
                "sporespore_content_addressed_artifact_receipt_v1"
        ) { $Receipts.Add($Value) }
        foreach ($property in $Value.PSObject.Properties) {
            Add-R23D60CasReceipts $property.Value $Receipts
        }
        return
    }
    if ($Value -is [Collections.IDictionary]) {
        foreach ($child in $Value.Values) {
            Add-R23D60CasReceipts $child $Receipts
        }
        return
    }
    if ($Value -is [Collections.IEnumerable] -and $Value -isnot [string]) {
        foreach ($child in $Value) {
            Add-R23D60CasReceipts $child $Receipts
        }
    }
}

function Assert-R23D60CasGroup($Group) {
    $first = @($Group.Group)[0]
    $sha = [string]$first.sha256
    $byteLength = [long]$first.byte_length
    Assert-R23D60Closure ($sha -cmatch '^sha256:[0-9a-f]{64}$') (
        "invalid CAS digest: $sha"
    )
    foreach ($receipt in @($Group.Group)) {
        Assert-R23D60Closure (
            [string]$receipt.schema_version -ceq
                "sporespore_content_addressed_artifact_receipt_v1" -and
            [string]$receipt.sha256 -ceq $sha -and
            [long]$receipt.byte_length -eq $byteLength -and
            -not [bool]$receipt.test_only -and
            -not [bool]$receipt.physical_acceptance_authority
        ) "CAS receipt semantics changed: $sha"
    }
    $directory = Join-Path $artifactRoot $sha.Substring(7)
    $payload = Join-Path $directory "payload.bin"
    $manifestPath = Join-Path $directory "manifest.json"
    Assert-R23D60Closure (
        (Test-Path -LiteralPath $payload -PathType Leaf) -and
        (Test-Path -LiteralPath $manifestPath -PathType Leaf) -and
        (Get-Item -LiteralPath $payload).Length -eq $byteLength -and
        (Get-R23D60Sha256 $payload) -ceq $sha
    ) "CAS payload changed: $sha"
    $manifest = Get-Content -Raw -LiteralPath $manifestPath |
        ConvertFrom-Json -Depth 20
    Assert-R23D60Closure (
        [string]$manifest.schema_version -ceq
            "sporespore_content_addressed_artifact_manifest_v1" -and
        [string]$manifest.algorithm -ceq "sha256" -and
        [string]$manifest.sha256 -ceq $sha -and
        [long]$manifest.byte_length -eq $byteLength -and
        [string]$manifest.payload_name -ceq "payload.bin"
    ) "CAS manifest changed: $sha"
}

function Find-R23D60ClosedRecord($Value) {
    if ($null -eq $Value) { return $null }
    if ($Value -is [Collections.IDictionary]) {
        if ($Value.Contains("closed_r23d60_attempt")) {
            return $Value["closed_r23d60_attempt"]
        }
        foreach ($child in $Value.Values) {
            $found = Find-R23D60ClosedRecord $child
            if ($null -ne $found) { return $found }
        }
        return $null
    }
    if ($Value -is [Management.Automation.PSCustomObject]) {
        $property = $Value.PSObject.Properties["closed_r23d60_attempt"]
        if ($null -ne $property) { return $property.Value }
        foreach ($childProperty in $Value.PSObject.Properties) {
            $found = Find-R23D60ClosedRecord $childProperty.Value
            if ($null -ne $found) { return $found }
        }
        return $null
    }
    if ($Value -is [Collections.IEnumerable] -and $Value -isnot [string]) {
        foreach ($child in $Value) {
            $found = Find-R23D60ClosedRecord $child
            if ($null -ne $found) { return $found }
        }
    }
    return $null
}

function Test-R23D60ClaimVector($Value) {
    try {
        return (
            [bool]$Value.r23d60_complete_three_world_attempt_executed -and
            [bool]$Value.r23d60_all_three_cells_execution_valid -and
            [bool]$Value.r23d60_all_three_common_gate_passed -and
            [bool]$Value.r23d60_full_precision_traces_retained -and
            [bool]$Value.r23d60_complete_dependency_inventory_proved -and
            [bool]$Value.r23d60_held_out_turning_positive -and
            [bool]$Value.godot_jolt_turning -and
            -not [bool]$Value.finite_three_engine_turning -and
            -not [bool]$Value.portable_basic_turning -and
            -not [bool]$Value.cross_engine_equivalence -and
            -not [bool]$Value.population_robustness -and
            -not [bool]$Value.arbitrary_quadruped_coverage -and
            -not [bool]$Value.prone_to_standing -and
            -not [bool]$Value.q_sdk_r23_satisfied -and
            -not [bool]$Value.release_authorized -and
            -not [bool]$Value.physical_acceptance_authority
        )
    } catch { return $false }
}

function Test-R23D60ClosureSemanticVector($Value) {
    try {
        return (
            [string]$Value.status -ceq $closedStatus -and
            [string]$Value.source_commit -ceq $sourceCommit -and
            [string]$Value.source_tree_git_oid -ceq $sourceTree -and
            [string]$Value.attempt_id -ceq $attemptId -and
            [bool]$Value.identity_consumed -and
            -not [bool]$Value.same_identity_rerun_allowed -and
            -not [bool]$Value.selective_rerun_allowed -and
            -not [bool]$Value.replacement_rerun_allowed -and
            [bool]$Value.held_out_seed_consumed -and
            -not [bool]$Value.successor_campaign_opened -and
            [bool]$Value.physical_series_paused_before_successor -and
            [bool]$Value.declaration_and_zero_world_provenance.complete_zero_world_gate_passed -and
            [int]$Value.declaration_and_zero_world_provenance.transitive_path_count -eq 136 -and
            [int]$Value.declaration_and_zero_world_provenance.transitive_edge_count -eq 159 -and
            [int]$Value.declaration_and_zero_world_provenance.zero_world_model_construction_count -eq 0 -and
            [int]$Value.declaration_and_zero_world_provenance.zero_world_world_attempt_count -eq 0 -and
            [int]$Value.declaration_and_zero_world_provenance.zero_world_world_build_count -eq 0 -and
            -not [bool]$Value.declaration_and_zero_world_provenance.controller_threshold_selector_evaluator_or_result_changed_after_preregistration -and
            [string]$Value.qualification_history.initial_failed_qualification.source_commit -ceq
                $initialQualificationCommit -and
            [int]$Value.qualification_history.initial_failed_qualification.retained_file_count -eq 13 -and
            -not [bool]$Value.qualification_history.initial_failed_qualification.campaign_local_qualification_passed -and
            -not [bool]$Value.qualification_history.initial_failed_qualification.reusable -and
            [int]$Value.qualification_history.initial_failed_qualification.corrected_inventory_counts.audit_count -eq 158 -and
            [bool]$Value.qualification_history.correction_scope.only_executable_provenance_inventory_extended -and
            -not [bool]$Value.qualification_history.correction_scope.physics_changed -and
            -not [bool]$Value.qualification_history.correction_scope.result_or_interpretation_changed -and
            [int]$Value.physical_evidence.retained_file_count -eq 28 -and
            [long]$Value.physical_evidence.retained_byte_count -eq 206736332 -and
            [int]$Value.physical_evidence.content_addressed_receipt_reference_count -eq 374 -and
            [int]$Value.physical_evidence.content_addressed_unique_object_count -eq 205 -and
            [int]$Value.physical_evidence.invalid_content_addressed_reference_count -eq 0 -and
            [int]$Value.physical_evidence.physical_freeze_source_binding_count -eq 136 -and
            [int]$Value.physical_evidence.physical_freeze_transitive_edge_count -eq 159 -and
            [bool]$Value.physical_evidence.complete_dependency_inventory_proved -and
            [string]$Value.official_result.classification -ceq $classification -and
            [int]$Value.official_result.observed_world_attempt_count -eq 3 -and
            [int]$Value.official_result.observed_world_build_count -eq 3 -and
            [int]$Value.official_result.execution_valid_cell_count -eq 3 -and
            [int]$Value.official_result.common_physical_gate_pass_cell_count -eq 3 -and
            [int]$Value.official_result.common_physical_gate_fail_cell_count -eq 0 -and
            [int]$Value.official_result.retained_trace_row_count -eq 8976 -and
            [int]$Value.official_result.retained_actuator_application_count -eq 71808 -and
            [bool]$Value.official_result.matrix_execution_valid -and
            [bool]$Value.official_result.all_common_physical_gates_passed -and
            [bool]$Value.official_result.turning_gate_invoked -and
            [bool]$Value.official_result.strict_finite_three_arm_conjunction_used -and
            [bool]$Value.official_result.held_out_turning_positive -and
            [bool]$Value.official_result.raw_signed_cycle_shift_gate_passed -and
            [bool]$Value.official_result.reference_conditioned_cycle_shift_gate_passed -and
            -not [bool]$Value.official_result.superiority_test_invoked -and
            -not [bool]$Value.official_result.equivalence_or_non_inferiority_test_invoked -and
            -not [bool]$Value.official_result.pass_rate_estimated -and
            -not [bool]$Value.official_result.population_inference_attempted -and
            -not [bool]$Value.official_result.posthoc_threshold_or_selector_change_performed -and
            [bool]$Value.bounded_interpretation.exact_bounded_native_godot_jolt_turning_established -and
            -not [bool]$Value.bounded_interpretation.three_engine_turning_established -and
            -not [bool]$Value.bounded_interpretation.cross_engine_equivalence_established -and
            -not [bool]$Value.bounded_interpretation.portable_basic_turning_established -and
            -not [bool]$Value.bounded_interpretation.prone_to_standing_established -and
            [bool]$Value.successor_requirements.r23d60_rerun_forbidden -and
            [bool]$Value.successor_requirements.distinct_campaign_identity_required_for_any_further_physics -and
            -not [bool]$Value.successor_requirements.prone_to_standing_campaign_opened -and
            -not [bool]$Value.successor_requirements.physical_successor_authorized_by_this_closure -and
            (Test-R23D60ClaimVector $Value.claims)
        )
    } catch { return $false }
}

function Assert-R23D60Close(
    [double]$Actual,
    [double]$Expected,
    [string]$Name
) {
    Assert-R23D60Closure ([Math]::Abs($Actual - $Expected) -le 1e-12) (
        "$Name changed: expected $Expected, observed $Actual"
    )
}

Assert-R23D60Closure ($repoRoot -ceq $expectedRoot) "repository root changed"
$observedTop = (& git -C $repoRoot rev-parse --show-toplevel).Trim()
$observedRemote = (& git -C $repoRoot remote get-url origin).Trim()
Assert-R23D60Closure (
    $LASTEXITCODE -eq 0 -and
    [IO.Path]::GetFullPath($observedTop) -ceq $expectedRoot -and
    $observedRemote -ceq $expectedRemote
) "repository identity changed"

Assert-R23D60Closure (Test-Path -LiteralPath $closurePath -PathType Leaf) (
    "closure is missing: $closurePath"
)
$closure = Get-Content -Raw -LiteralPath $closurePath | ConvertFrom-Json -Depth 100
Assert-R23D60Closure (
    [string]$closure.schema_version -ceq
        "sporespore_qsdk_r23d60_godot_fixture_knee_held_out_turning_validation_closure_v1" -and
    [string]$closure.campaign_id -ceq $campaignId -and
    [string]$closure.gate_id -ceq "QSDK-R23D60" -and
    [string]$closure.release_gate_id -ceq "QSDK-R23" -and
    [string]$closure.question_class -ceq "finite_decision" -and
    @($closure.ordered_cells).Count -eq 3 -and
    (Test-R23D60ClosureSemanticVector $closure)
) "closure identity or semantic vector changed"

$observedTree = (& git -C $repoRoot rev-parse "$sourceCommit`^{tree}").Trim()
$observedInitialTree = (& git -C $repoRoot rev-parse (
    "$initialQualificationCommit`^{tree}"
)).Trim()
Assert-R23D60Closure (
    $LASTEXITCODE -eq 0 -and
    $observedTree -ceq $sourceTree -and
    $observedInitialTree -ceq $initialQualificationTree
) "physical or failed-qualification source tree changed or is unavailable"

$failedSpec = $closure.qualification_history.initial_failed_qualification
$failedFiles = @(Get-ChildItem -LiteralPath $failedQualificationRoot -Recurse -File)
$failedInventory = @($failedSpec.file_inventory)
Assert-R23D60Closure (
    $failedInventory.Count -eq 13 -and
    $failedFiles.Count -eq 13 -and
    [long]($failedFiles | Measure-Object Length -Sum).Sum -eq 12820
) "initial failed qualification inventory cardinality changed"
$failedExpectedPaths = @($failedInventory | ForEach-Object {
    [string]$_.path
} | Sort-Object)
$failedActualPaths = @($failedFiles | ForEach-Object {
    $_.FullName.Substring($failedQualificationRoot.Length + 1).Replace('\', '/')
} | Sort-Object)
Assert-R23D60Closure (
    ($failedExpectedPaths -join "`n") -ceq ($failedActualPaths -join "`n")
) "initial failed qualification file set changed"
foreach ($entry in $failedInventory) {
    $path = Join-Path $failedQualificationRoot ([string]$entry.path).Replace('/', '\')
    Assert-R23D60Closure (
        (Test-Path -LiteralPath $path -PathType Leaf) -and
        (Get-Item -LiteralPath $path).Length -eq [long]$entry.byte_length -and
        (Get-R23D60Sha256 $path) -ceq [string]$entry.raw_sha256
    ) "initial failed qualification bytes changed: $($entry.path)"
}
$failure = Get-Content -Raw -LiteralPath (
    Join-Path $failedQualificationRoot "failure.json"
) | ConvertFrom-Json -Depth 50
$failedGate = Get-Content -Raw -LiteralPath (
    Join-Path $failedQualificationRoot (
        "004-CAK1-EVIDENCE-PROVENANCE.receipt.json"
    )
) | ConvertFrom-Json -Depth 50
Assert-R23D60Closure (
    [string]$failure.schema_version -ceq
        "sporespore_locomotion_campaign_attestation_failure_v1" -and
    [string]$failure.campaign_id -ceq $campaignId -and
    [string]$failure.source_commit -ceq $initialQualificationCommit -and
    [string]$failure.message -ceq
        "Campaign-local attestation gate failed: CAK1-EVIDENCE-PROVENANCE exit=1 timeout=False marker_count=0" -and
    -not [bool]$failure.campaign_local_qualification_passed -and
    -not [bool]$failure.physical_launch_prerequisite_satisfied -and
    -not [bool]$failure.physical_acceptance_authority -and
    -not [bool]$failure.release_authority -and
    [string]$failedGate.gate_id -ceq "CAK1-EVIDENCE-PROVENANCE" -and
    [int]$failedGate.ordinal -eq 4 -and
    [int]$failedGate.exit_code -eq 1 -and
    -not [bool]$failedGate.passed -and
    [int]$failedGate.physical_world_count -eq 0 -and
    [int]$failedGate.physical_process_launch_count -eq 0
) "initial qualification failure was lost or reinterpreted"

$attestationSpec = $closure.qualification_history.accepted_scoped_attestation
$adoptionSpec = $closure.qualification_history.adoption
foreach ($spec in @($attestationSpec, $adoptionSpec)) {
    $path = [IO.Path]::GetFullPath([string]$spec.path)
    Assert-R23D60Closure (
        (Test-Path -LiteralPath $path -PathType Leaf) -and
        (Get-Item -LiteralPath $path).Length -eq [long]$spec.byte_length -and
        (Get-R23D60Sha256 $path) -ceq [string]$spec.raw_sha256
    ) "qualification artifact changed: $path"
}
$attestation = Get-Content -Raw -LiteralPath ([string]$attestationSpec.path) |
    ConvertFrom-Json -Depth 100
$adoption = Get-Content -Raw -LiteralPath ([string]$adoptionSpec.path) |
    ConvertFrom-Json -Depth 100
Assert-R23D60Closure (
    [string]$attestation.status -ceq
        "campaign_local_godot_including_qualification_passed" -and
    [string]$attestation.source.commit -ceq $sourceCommit -and
    [string]$attestation.source.tree_git_oid -ceq $sourceTree -and
    [bool]$attestation.source.worktree_clean -and
    [bool]$attestation.source.clean_pushed_live -and
    [int]$attestation.executed_gate_count -eq 22 -and
    [int]$attestation.declared_physical_world_count -eq 3 -and
    @($attestation.gate_receipts).Count -eq 22 -and
    (@($attestation.gate_receipts | Where-Object { -not [bool]$_.passed }).Count -eq 0) -and
    (@($attestation.gate_receipts | Measure-Object physical_world_count -Sum).Sum -eq 0) -and
    -not [bool]$attestation.claims.physical_campaign_executed -and
    -not [bool]$attestation.claims.turning_acceptance -and
    -not [bool]$attestation.claims.physical_acceptance_authority -and
    [string]$adoption.status -ceq
        "commissioned_campaign_local_qualification_adopted_for_physical_launch" -and
    [string]$adoption.source_commit -ceq $sourceCommit -and
    [string]$adoption.source_tree_git_oid -ceq $sourceTree -and
    [string]$adoption.scoped_attestation_raw_sha256 -ceq
        [string]$attestationSpec.raw_sha256 -and
    [int]$adoption.declared_physical_world_count -eq 3 -and
    [int]$adoption.executed_gate_count -eq 22 -and
    [int]$adoption.gate_cas_object_count -eq 66 -and
    [bool]$adoption.physical_launch_prerequisite_satisfied -and
    [bool]$adoption.all_gate_cas_objects_verified -and
    [bool]$adoption.scoped_attestation_cas_verified -and
    [bool]$adoption.clean_pushed_live_source_verified -and
    -not [bool]$adoption.physical_acceptance_authority -and
    -not [bool]$adoption.release_authority
) "corrected qualification or adoption authority changed"

$inventory = @($closure.physical_evidence.file_inventory)
$actualFiles = @(Get-ChildItem -LiteralPath $attemptRoot -Recurse -File)
Assert-R23D60Closure (
    $inventory.Count -eq 28 -and
    $actualFiles.Count -eq 28 -and
    [long]($actualFiles | Measure-Object Length -Sum).Sum -eq 206736332
) "retained physical evidence inventory cardinality changed"
$inventoryPaths = @($inventory | ForEach-Object { [string]$_.path } | Sort-Object)
$actualPaths = @($actualFiles | ForEach-Object {
    $_.FullName.Substring($attemptRoot.Length + 1).Replace('\', '/')
} | Sort-Object)
Assert-R23D60Closure (
    ($inventoryPaths -join "`n") -ceq ($actualPaths -join "`n")
) "retained physical evidence file set changed"
foreach ($entry in $inventory) {
    $path = Join-Path $attemptRoot ([string]$entry.path).Replace('/', '\')
    Assert-R23D60Closure (
        (Test-Path -LiteralPath $path -PathType Leaf) -and
        (Get-Item -LiteralPath $path).Length -eq [long]$entry.byte_length -and
        (Get-R23D60Sha256 $path) -ceq [string]$entry.raw_sha256
    ) "retained physical evidence bytes changed: $($entry.path)"
}

$metadataFiles = @($inventory | Where-Object {
    [string]$_.path -like "*.json" -and
    [string]$_.path -notlike "pending-traces/*"
} | ForEach-Object {
    Join-Path $attemptRoot ([string]$_.path).Replace('/', '\')
}) + @([string]$attestationSpec.path, [string]$adoptionSpec.path)
Assert-R23D60Closure ($metadataFiles.Count -eq 12) (
    "CAS-bearing metadata file count changed"
)
$receipts = [Collections.Generic.List[object]]::new()
foreach ($metadataPath in $metadataFiles) {
    Add-R23D60CasReceipts (
        Get-Content -Raw -LiteralPath $metadataPath | ConvertFrom-Json -Depth 100
    ) $receipts
}
$receiptGroups = @($receipts | Group-Object { [string]$_.sha256 })
Assert-R23D60Closure (
    $receipts.Count -eq 374 -and
    $receiptGroups.Count -eq 205
) "CAS receipt counts changed"
foreach ($group in $receiptGroups) { Assert-R23D60CasGroup $group }

$freeze = Get-Content -Raw -LiteralPath (Join-Path $attemptRoot "physical-freeze.json") |
    ConvertFrom-Json -Depth 100
$authorization = Get-Content -Raw -LiteralPath (
    Join-Path $attemptRoot "attempt-authorization.json"
) | ConvertFrom-Json -Depth 100
$authorizationPreflight = Get-Content -Raw -LiteralPath (
    Join-Path $attemptRoot "authorization-preflight.json"
) | ConvertFrom-Json -Depth 100
$terminalManifest = @(Get-Content -Raw -LiteralPath (
    Join-Path $attemptRoot "terminal-paths.json"
) | ConvertFrom-Json -Depth 20)
$evaluation = Get-Content -Raw -LiteralPath (
    Join-Path $attemptRoot "complete-evaluation.json"
) | ConvertFrom-Json -Depth 100
$report = Get-Content -Raw -LiteralPath (Join-Path $attemptRoot "report.json") |
    ConvertFrom-Json -Depth 100
$completion = Get-Content -Raw -LiteralPath (
    Join-Path $attemptRoot "completion.json"
) | ConvertFrom-Json -Depth 100

Assert-R23D60Closure (
    [string]$freeze.schema_version -ceq
        "sporespore_qsdk_r23d60_physical_freeze_v1" -and
    [string]$freeze.status -ceq "frozen_supervisor_only_physical_authorized" -and
    [string]$freeze.source_commit -ceq $sourceCommit -and
    [string]$freeze.source_tree_git_oid -ceq $sourceTree -and
    [string]$freeze.origin_main_commit -ceq $sourceCommit -and
    [string]$freeze.live_github_main_commit -ceq $sourceCommit -and
    [bool]$freeze.dependency_inventory_complete -and
    [int]$freeze.dependency_inventory.transitive_path_count -eq 136 -and
    [int]$freeze.dependency_inventory.edge_count -eq 159 -and
    [string]$freeze.dependency_inventory.inventory_projection_sha256 -ceq
        "sha256:5f29293d2bdac29661c267a1960b38adc32417809b7634363c6a3d4e9fbeed6e" -and
    [bool]$freeze.dependency_inventory.expected_transitive_path_set_exact -and
    [bool]$freeze.dependency_inventory.checkout_bytes_equal_git_blobs -and
    [bool]$freeze.dependency_inventory.all_paths_tracked_with_exact_case -and
    [bool]$freeze.dependency_inventory.recursive_local_python_import_inventory_complete -and
    [bool]$freeze.dependency_inventory.recursive_gdscript_preload_and_load_inventory_complete -and
    [bool]$freeze.dependency_inventory.powershell_static_dot_source_and_subprocess_path_inventory_complete -and
    [bool]$freeze.dependency_inventory.declaration_bound_source_inventory_complete -and
    [int]$freeze.dependency_inventory.model_construction_count -eq 0 -and
    [int]$freeze.dependency_inventory.world_attempt_count -eq 0 -and
    [int]$freeze.dependency_inventory.world_build_count -eq 0 -and
    @($freeze.source_bindings).Count -eq 136 -and
    @($freeze.runtime_artifacts).Count -eq 1 -and
    @($freeze.external_runtime_bindings).Count -eq 3 -and
    [int]$freeze.declared_world_count -eq 3 -and
    (@($freeze.ordered_matrix_cell_ids) -join "`n") -ceq
        ($expectedCellIds -join "`n") -and
    [bool]$freeze.serial_execution_required -and
    [bool]$freeze.all_cells_run_regardless_of_intermediate_outcome -and
    [bool]$freeze.complete_zero_world_gate_passed -and
    [bool]$freeze.source_checkout_bytes_equal_git_blobs -and
    [bool]$freeze.reproducible_runtime_materialization_passed -and
    [bool]$freeze.physical_execution_authorized -and
    -not [bool]$freeze.terminal_restoration_or_taper_invoked -and
    -not [bool]$freeze.physical_acceptance_authority
) "physical freeze changed"

$sourceBindings = @($freeze.source_bindings)
Assert-R23D60Closure (
    @($sourceBindings.path | Sort-Object -Unique).Count -eq 136 -and
    @($sourceBindings.git_blob_oid | Sort-Object -Unique).Count -eq 136
) "source binding cardinality or uniqueness changed"
$sourceBytes = [Collections.Generic.Dictionary[string, byte[]]]::new(
    [StringComparer]::Ordinal
)
foreach ($binding in $sourceBindings) {
    $relative = [string]$binding.path
    $bytes = Get-R23D60GitBlobBytes $sourceCommit $relative
    $oid = (& git -C $repoRoot rev-parse "$sourceCommit`:$relative").Trim()
    Assert-R23D60Closure (
        $LASTEXITCODE -eq 0 -and
        $oid -ceq [string]$binding.git_blob_oid -and
        (Get-R23D60BytesSha256 $bytes) -ceq [string]$binding.raw_sha256 -and
        [bool]$binding.raw_checkout_equals_git_blob
    ) "historical source binding changed: $relative"
    $sourceBytes[$relative] = $bytes
}

Assert-R23D60Closure (
    [string]$authorization.schema_version -ceq
        "sporespore_qsdk_r23d60_attempt_v1" -and
    [string]$authorization.source_commit -ceq $sourceCommit -and
    [string]$authorization.attempt_id -ceq $attemptId -and
    (@($authorization.ordered_matrix_cell_ids) -join "`n") -ceq
        ($expectedCellIds -join "`n") -and
    [bool]$authorization.physical_execution_authorized -and
    [bool]$authorization.single_use_supervisor_authorization -and
    [bool]$authorization.matrix_authorization_immutable_before_first_world -and
    [bool]$authorization.source_worktree_clean -and
    [bool]$authorization.source_matches_live_github_main -and
    [bool]$authorization.operation_lock_held -and
    [bool]$authorization.campaign_attestation_adoption_valid -and
    [bool]$authorization.content_addressed_inputs_retained -and
    [bool]$authorization.one_shot_attempt_unconsumed -and
    [bool]$authorization.all_cells_run_regardless_of_intermediate_outcome -and
    -not [bool]$authorization.physical_acceptance_authority
) "attempt authorization changed"
Assert-R23D60Closure (
    [string]$authorizationPreflight.schema_version -ceq
        "sporespore_qsdk_r23d60_authorization_preflight_matrix_v1" -and
    [string]$authorizationPreflight.source_commit -ceq $sourceCommit -and
    [int]$authorizationPreflight.receipt_count -eq 3 -and
    [int]$authorizationPreflight.model_construction_count -eq 0 -and
    [int]$authorizationPreflight.world_attempt_count -eq 0 -and
    [int]$authorizationPreflight.world_build_count -eq 0 -and
    -not [bool]$authorizationPreflight.physical_acceptance_authority
) "authorization preflight summary changed"
$preflightIds = @($authorizationPreflight.ordered_receipts | ForEach-Object {
    [string]$_.cell_id
})
Assert-R23D60Closure (($preflightIds -join "`n") -ceq ($expectedCellIds -join "`n")) (
    "authorization preflight order changed"
)
foreach ($entry in @($authorizationPreflight.ordered_receipts)) {
    Assert-R23D60Closure (
        [bool]$entry.worker_receipt.authorization_passed -and
        [bool]$entry.worker_receipt.returned_before_model -and
        [int]$entry.worker_receipt.model_construction_count -eq 0 -and
        [int]$entry.worker_receipt.world_attempt_count -eq 0 -and
        [int]$entry.worker_receipt.world_build_count -eq 0 -and
        [int]$entry.process.exit_code -eq 0 -and
        -not [bool]$entry.process.timed_out -and
        [bool]$entry.process.supervisor_terminated -and
        [bool]$entry.process.termination_protocol_valid -and
        -not [bool]$entry.physical_acceptance_authority
    ) "authorization preflight receipt changed: $($entry.cell_id)"
}

Assert-R23D60Closure ($terminalManifest.Count -eq 3) "terminal manifest changed"
$terminals = @($terminalManifest | ForEach-Object {
    $path = [IO.Path]::GetFullPath([string]$_)
    Assert-R23D60Closure (
        $path.StartsWith(
            [IO.Path]::GetFullPath($artifactRoot) + [IO.Path]::DirectorySeparatorChar,
            [StringComparison]::OrdinalIgnoreCase
        ) -and
        (Test-Path -LiteralPath $path -PathType Leaf)
    ) "terminal manifest escaped or is missing: $path"
    Get-Content -Raw -LiteralPath $path | ConvertFrom-Json -Depth 100
})
$terminalIds = @($terminals | ForEach-Object { [string]$_.cell_id })
Assert-R23D60Closure (($terminalIds -join "`n") -ceq ($expectedCellIds -join "`n")) (
    "terminal order changed"
)

Assert-R23D60Closure (
    [string]$evaluation.schema_version -ceq
        "sporespore_qsdk_r23d60_complete_held_out_turning_evaluation_v1" -and
    [string]$evaluation.classification -ceq $classification -and
    [string]$evaluation.source_commit -ceq $sourceCommit -and
    [string]$evaluation.question_class -ceq "finite_decision" -and
    [int]$evaluation.cell_count -eq 3 -and
    [bool]$evaluation.all_declared_cells_executed_or_retained_as_failures -and
    [bool]$evaluation.all_cells_run_regardless_of_intermediate_outcome -and
    [int]$evaluation.fresh_held_out_seed_count -eq 1 -and
    [bool]$evaluation.fresh_held_out_seed_consumed -and
    [string]$evaluation.selected_profile_id -ceq "portable_hip__fixture_knee" -and
    [bool]$evaluation.turning_gate_invoked -and
    [bool]$evaluation.finite_decision.matrix_execution_valid -and
    [bool]$evaluation.finite_decision.all_common_physical_gates_passed -and
    [bool]$evaluation.finite_decision.strict_finite_three_arm_conjunction_used -and
    [bool]$evaluation.finite_decision.held_out_turning_positive -and
    @($evaluation.finite_decision.measurement_failure_codes).Count -eq 0 -and
    -not [bool]$evaluation.finite_decision.superiority_test_invoked -and
    -not [bool]$evaluation.finite_decision.equivalence_or_non_inferiority_test_invoked -and
    -not [bool]$evaluation.finite_decision.pass_rate_estimated -and
    -not [bool]$evaluation.posthoc_threshold_or_selector_change_performed -and
    [bool]$evaluation.claims.r23d60_held_out_turning_positive -and
    [bool]$evaluation.claims.godot_jolt_turning -and
    -not [bool]$evaluation.claims.finite_three_engine_turning -and
    -not [bool]$evaluation.claims.portable_basic_turning -and
    -not [bool]$evaluation.claims.cross_engine_equivalence -and
    -not [bool]$evaluation.claims.prone_to_standing -and
    -not [bool]$evaluation.claims.q_sdk_r23_satisfied -and
    -not [bool]$evaluation.claims.release_authority -and
    -not [bool]$evaluation.physical_acceptance_authority
) "complete evaluator result changed"

$evaluationByCell = @{}
foreach ($entry in @($evaluation.cell_evaluations)) {
    $evaluationByCell[[string]$entry.cell_id] = $entry
}
$terminalByCell = @{}
foreach ($entry in $terminals) { $terminalByCell[[string]$entry.cell_id] = $entry }
foreach ($expected in @($closure.ordered_cells)) {
    $cellId = [string]$expected.cell_id
    $terminal = $terminalByCell[$cellId]
    $cellEvaluation = $evaluationByCell[$cellId]
    Assert-R23D60Closure ($null -ne $terminal -and $null -ne $cellEvaluation) (
        "cell is missing: $cellId"
    )
    $terminalLocal = Join-Path $attemptRoot "cells\$cellId\terminal.json"
    Assert-R23D60Closure (
        [string]$terminal.schema_version -ceq
            "sporespore_qsdk_r23d60_engine_cell_report_v1" -and
        [string]$terminal.campaign_id -ceq $campaignId -and
        [string]$terminal.source_commit -ceq $sourceCommit -and
        [string]$terminal.profile_id -ceq "portable_hip__fixture_knee" -and
        [string]$terminal.arm_id -ceq [string]$expected.arm_id -and
        [int]$terminal.campaign_seed -eq 21516 -and
        [bool]$terminal.execution.integrity_passed -and
        [int]$terminal.execution.world_attempt_count -eq 1 -and
        [int]$terminal.execution.world_build_count -eq 1 -and
        [int]$terminal.execution.controller_semantic_step_count -eq 2992 -and
        [int]$terminal.execution.validated_portable_command_count -eq 23936 -and
        [int]$terminal.execution.native_actuation_application_count -eq 23936 -and
        [int]$terminal.execution.portable_impulse_violation_count -eq 0 -and
        [bool]$terminal.execution.trace_retained_before_terminal_entry -and
        [bool]$terminal.godot_execution_predicates.ok -and
        @($terminal.godot_execution_predicates.failed_predicate_ids).Count -eq 0 -and
        [string]$terminal.trace_artifact.sha256 -ceq [string]$expected.trace_raw_sha256 -and
        [long]$terminal.trace_artifact.byte_length -eq [long]$expected.trace_byte_length -and
        [bool]$terminal.trace_artifact.godot_json_full_precision -and
        [bool]$terminal.trace_artifact.godot_json_sorted_keys -and
        [int]$terminal.trace_summary.row_count -eq 2992 -and
        [int]$terminal.trace_summary.observation_application_count -eq 23936 -and
        [bool]$cellEvaluation.execution_valid -and
        [bool]$cellEvaluation.common_physical_gate_passed -and
        @($cellEvaluation.failed_gate_ids).Count -eq 0 -and
        (Get-R23D60Sha256 $terminalLocal) -ceq
            [string]$expected.terminal_raw_sha256 -and
        -not [bool]$terminal.claims.r23d60_held_out_turning_positive -and
        -not [bool]$terminal.claims.godot_jolt_turning -and
        -not [bool]$terminal.claims.finite_three_engine_turning -and
        -not [bool]$terminal.claims.prone_to_standing -and
        -not [bool]$terminal.claims.physical_acceptance_authority
    ) "terminal or evaluation cell changed: $cellId"
    foreach ($limb in @("front_left", "front_right", "rear_left", "rear_right")) {
        Assert-R23D60Closure (
            [int]$terminal.measurements.contact_cycle_count_by_limb.$limb -eq
                [int]$expected.common_gate_contact_cycle_count_by_limb.$limb
        ) "contact-cycle value changed: $cellId/$limb"
    }
    Assert-R23D60Close ([double]$terminal.turn_heading_offset_rad) `
        ([double]$expected.turn_heading_offset_rad) "$cellId heading offset"
    Assert-R23D60Close ([double]$terminal.measurements.final_forward_displacement_m) `
        ([double]$expected.final_forward_displacement_m) "$cellId forward displacement"
    Assert-R23D60Close ([double]$terminal.measurements.turn_phase_yaw_delta_rad) `
        ([double]$expected.turn_phase_yaw_delta_rad_descriptive_only) "$cellId yaw context"
    Assert-R23D60Close ([double]$terminal.measurements.minimum_torso_height_m) `
        ([double]$expected.minimum_torso_height_m) "$cellId torso height"
    Assert-R23D60Close ([double]$terminal.measurements.maximum_tilt_rad) `
        ([double]$expected.maximum_tilt_rad) "$cellId maximum tilt"
    Assert-R23D60Closure (
        [int]$terminal.measurements.torso_ground_contact_step_count -eq 0
    ) "torso-ground contact changed: $cellId"
}

$measurement = $evaluation.finite_decision.cycle_integrated_measurement
Assert-R23D60Closure (
    [string]$measurement.schema_version -ceq
        "sporespore_qsdk_r23d31_cycle_integrated_measurement_v1" -and
    [bool]$measurement.passed -and
    [bool]$measurement.gates.raw_signed_cycle_shift -and
    [bool]$measurement.gates.reference_conditioned_cycle_shift -and
    [double]$measurement.measurement_configuration.minimum_cycle_shift_rad -eq 0.01 -and
    (@($measurement.measurement_configuration.selecting_gate_ids) -join "`n") -ceq
        "raw_signed_cycle_shift`nreference_conditioned_cycle_shift" -and
    [bool]$measurement.nonselecting_diagnostics.every_terminal_swing_raw_direction -and
    -not [bool]$measurement.nonselecting_diagnostics.every_terminal_swing_reference_conditioned_direction -and
    [int]$measurement.engine_identity_input_count -eq 0 -and
    -not [bool]$measurement.physical_acceptance_authority
) "selecting measurement gates or nonselecting diagnostics changed"
Assert-R23D60Close ([double]$measurement.arms.reference_zero.cycle_shift_rad) `
    -0.022523073875138966 "reference raw cycle shift"
Assert-R23D60Close ([double]$measurement.arms.positive_heading.cycle_shift_rad) `
    0.20035480789390414 "positive raw cycle shift"
Assert-R23D60Close ([double]$measurement.arms.negative_heading.cycle_shift_rad) `
    -0.24345978790448441 "negative raw cycle shift"
Assert-R23D60Close ([double]$measurement.positive_reference_conditioned_cycle_shift_rad) `
    0.2228778817690431 "positive reference-conditioned cycle shift"
Assert-R23D60Close ([double]$measurement.negative_reference_conditioned_cycle_shift_rad) `
    0.22093671402934545 "negative reference-conditioned cycle shift"
Assert-R23D60Close ([double]$measurement.bilateral_reference_conditioned_cycle_separation_rad) `
    0.44381459579838856 "bilateral reference-conditioned separation"
Assert-R23D60Closure (
    (@($measurement.positive_terminal_swing_conditioned_shift_rad) -join "|") -ceq
        (@($closure.official_result.positive_terminal_swing_conditioned_shift_rad) -join "|") -and
    (@($measurement.negative_terminal_swing_conditioned_shift_rad) -join "|") -ceq
        (@($closure.official_result.negative_terminal_swing_conditioned_shift_rad) -join "|")
) "terminal-swing diagnostic vectors changed"

Assert-R23D60Closure (
    [string]$report.schema_version -ceq
        "sporespore_qsdk_r23d60_campaign_report_v1" -and
    [string]$report.source.commit -ceq $sourceCommit -and
    [string]$report.attempt_id -ceq $attemptId -and
    [string]$report.result_classification -ceq $classification -and
    [int]$report.authorization_preflight_count -eq 3 -and
    @($report.ordered_cells).Count -eq 3 -and
    [bool]$report.all_three_cells_executed_or_retained_as_failures -and
    [bool]$report.world_build_count_exact -and
    [int]$report.world_build_count_lower_bound -eq 3 -and
    [int]$report.world_build_count_upper_bound -eq 3 -and
    -not [bool]$report.terminal_restoration_or_taper_invoked -and
    [string]$report.complete_evaluation_cas.sha256 -ceq
        "sha256:ee4691009d9869478d0b30ef0b8fee15783d0893a8d727c20677e3ec0ede0513" -and
    [bool]$report.claims.r23d60_held_out_turning_positive -and
    [bool]$report.claims.godot_jolt_turning -and
    -not [bool]$report.claims.finite_three_engine_turning -and
    -not [bool]$report.claims.portable_basic_turning -and
    -not [bool]$report.claims.prone_to_standing -and
    -not [bool]$report.claims.release_authority -and
    [string]$completion.schema_version -ceq
        "sporespore_qsdk_r23d60_completion_v1" -and
    [string]$completion.status -ceq $classification -and
    [string]$completion.source_commit -ceq $sourceCommit -and
    [string]$completion.attempt_id -ceq $attemptId -and
    [int]$completion.cell_count -eq 3 -and
    [int]$completion.world_count -eq 3 -and
    [bool]$completion.world_count_exact -and
    [string]$completion.selected_profile_id -ceq "portable_hip__fixture_knee" -and
    [bool]$completion.held_out_turning_positive -and
    [bool]$completion.one_shot_attempt_consumed -and
    -not [bool]$completion.replacement_or_selective_rerun_permitted -and
    -not [bool]$completion.physical_acceptance_authority -and
    [string]$completion.report_cas.sha256 -ceq
        "sha256:e2c8bd8bb1ed96f795e4441892c2b86e9ca0ec35ca81f70686b5e617b129e6d7"
) "report or completion changed"

$tempBase = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\', '/')
$tempRoot = Join-Path $tempBase (
    "sporespore-r23d60-closure-" + [Guid]::NewGuid().ToString("N")
)
Assert-R23D60Closure (
    $tempRoot.StartsWith(
        $tempBase + [IO.Path]::DirectorySeparatorChar,
        [StringComparison]::OrdinalIgnoreCase
    )
) "temporary evaluator root escaped system temp"
New-Item -ItemType Directory -Path $tempRoot -ErrorAction Stop | Out-Null
try {
    foreach ($relative in $sourceBytes.Keys) {
        $target = Join-Path $tempRoot ([string]$relative).Replace('/', '\')
        $parent = Split-Path -Parent $target
        if (-not (Test-Path -LiteralPath $parent -PathType Container)) {
            New-Item -ItemType Directory -Path $parent -Force | Out-Null
        }
        [IO.File]::WriteAllBytes($target, [byte[]]$sourceBytes[$relative])
    }
    $evaluatorPath = Join-Path $tempRoot (
        "sdk\turning\r23d60_godot_fixture_knee_held_out_turning_validation_evaluator.py"
    )
    $evaluatorOutput = @(& $Python $evaluatorPath evaluate-complete `
        --manifest (Join-Path $attemptRoot "terminal-paths.json") `
        --expected-source-commit $sourceCommit --repo-root $repoRoot 2>&1)
    Assert-R23D60Closure ($LASTEXITCODE -eq 0) ($evaluatorOutput -join "`n")
    $marker = "QSDK_R23D60_COMPLETE_EVALUATION "
    $lines = @($evaluatorOutput | Where-Object {
        [string]$_ -and ([string]$_).StartsWith($marker, [StringComparison]::Ordinal)
    })
    Assert-R23D60Closure ($lines.Count -eq 1) "pinned evaluator marker changed"
    $replayed = ([string]$lines[0]).Substring($marker.Length) |
        ConvertFrom-Json -Depth 100
    Assert-R23D60Closure (
        [string]$replayed.classification -ceq $classification -and
        [string]$replayed.source_commit -ceq $sourceCommit -and
        [int]$replayed.cell_count -eq 3 -and
        [bool]$replayed.finite_decision.matrix_execution_valid -and
        [bool]$replayed.finite_decision.all_common_physical_gates_passed -and
        [bool]$replayed.finite_decision.held_out_turning_positive -and
        [bool]$replayed.turning_gate_invoked -and
        -not [bool]$replayed.posthoc_threshold_or_selector_change_performed -and
        [bool]$replayed.claims.godot_jolt_turning -and
        -not [bool]$replayed.claims.finite_three_engine_turning -and
        -not [bool]$replayed.claims.prone_to_standing -and
        -not [bool]$replayed.claims.physical_acceptance_authority
    ) "pinned evaluator no longer reproduces the complete result"
} finally {
    if (
        (Test-Path -LiteralPath $tempRoot -PathType Container) -and
        $tempRoot.StartsWith(
            $tempBase + [IO.Path]::DirectorySeparatorChar,
            [StringComparison]::OrdinalIgnoreCase
        )
    ) { Remove-Item -LiteralPath $tempRoot -Recurse -Force }
}

$mutations = @(
    { param($v) $v.status = "closed_negative" },
    { param($v) $v.source_commit = "0" * 40 },
    { param($v) $v.attempt_id = "wrong" },
    { param($v) $v.identity_consumed = $false },
    { param($v) $v.same_identity_rerun_allowed = $true },
    { param($v) $v.selective_rerun_allowed = $true },
    { param($v) $v.held_out_seed_consumed = $false },
    { param($v) $v.successor_campaign_opened = $true },
    { param($v) $v.declaration_and_zero_world_provenance.transitive_path_count = 135 },
    { param($v) $v.declaration_and_zero_world_provenance.transitive_edge_count = 158 },
    { param($v) $v.qualification_history.initial_failed_qualification.reusable = $true },
    { param($v) $v.qualification_history.correction_scope.physics_changed = $true },
    { param($v) $v.physical_evidence.complete_dependency_inventory_proved = $false },
    { param($v) $v.official_result.observed_world_build_count = 2 },
    { param($v) $v.official_result.execution_valid_cell_count = 2 },
    { param($v) $v.official_result.common_physical_gate_pass_cell_count = 2 },
    { param($v) $v.official_result.held_out_turning_positive = $false },
    { param($v) $v.official_result.raw_signed_cycle_shift_gate_passed = $false },
    { param($v) $v.official_result.reference_conditioned_cycle_shift_gate_passed = $false },
    { param($v) $v.official_result.superiority_test_invoked = $true },
    { param($v) $v.official_result.equivalence_or_non_inferiority_test_invoked = $true },
    { param($v) $v.official_result.population_inference_attempted = $true },
    { param($v) $v.official_result.posthoc_threshold_or_selector_change_performed = $true },
    { param($v) $v.bounded_interpretation.three_engine_turning_established = $true },
    { param($v) $v.bounded_interpretation.cross_engine_equivalence_established = $true },
    { param($v) $v.bounded_interpretation.prone_to_standing_established = $true },
    { param($v) $v.successor_requirements.physical_successor_authorized_by_this_closure = $true },
    { param($v) $v.claims.godot_jolt_turning = $false },
    { param($v) $v.claims.finite_three_engine_turning = $true },
    { param($v) $v.claims.prone_to_standing = $true },
    { param($v) $v.claims.release_authorized = $true }
)
$mutationRejectionCount = 0
foreach ($mutation in $mutations) {
    $candidate = $closure | ConvertTo-Json -Depth 100 | ConvertFrom-Json -Depth 100
    & $mutation $candidate
    if (-not (Test-R23D60ClosureSemanticVector $candidate)) {
        $mutationRejectionCount++
    }
}
Assert-R23D60Closure ($mutationRejectionCount -eq $mutations.Count) (
    "closure semantic mutation controls changed"
)

$releaseContract = Get-Content -Raw -LiteralPath (
    Join-Path $repoRoot "sdk\release\quadruped_release_contract.json"
) | ConvertFrom-Json -Depth 100
$supportMatrix = Get-Content -Raw -LiteralPath (
    Join-Path $repoRoot "sdk\release\quadruped_support_matrix.json"
) | ConvertFrom-Json -Depth 100
$turningGates = @($releaseContract.gates | Where-Object {
    [string]$_.gate_id -ceq "QSDK-R23"
})
$contractRecord = if ($turningGates.Count -eq 1) {
    $turningGates[0].proof.closed_r23d60_attempt
} else { $null }
$matrixRecord = Find-R23D60ClosedRecord $supportMatrix
$closureHash = Get-R23D60Sha256 $closurePath
$auditHash = Get-R23D60Sha256 $auditPath
Assert-R23D60Closure (
    $turningGates.Count -eq 1 -and
    $null -ne $contractRecord -and
    $null -ne $matrixRecord -and
    [string]$contractRecord.status -ceq $closedStatus -and
    [string]$matrixRecord.status -ceq $closedStatus -and
    [string]$contractRecord.closure_path -ceq
        "sdk/turning/r23d60_godot_fixture_knee_held_out_turning_validation_closure_v1.json" -and
    [string]$matrixRecord.closure_path -ceq [string]$contractRecord.closure_path -and
    [string]$contractRecord.closure_raw_sha256 -ceq $closureHash -and
    [string]$matrixRecord.closure_sha256 -ceq $closureHash -and
    [string]$contractRecord.closure_audit_path -ceq
        "tests/test_qsdk_r23d60_physical_closure.ps1" -and
    [string]$matrixRecord.closure_audit_path -ceq
        [string]$contractRecord.closure_audit_path -and
    [string]$contractRecord.closure_audit_raw_sha256 -ceq $auditHash -and
    [string]$matrixRecord.closure_audit_sha256 -ceq $auditHash -and
    [string]$contractRecord.physical_source_commit -ceq $sourceCommit -and
    [string]$matrixRecord.physical_source_commit -ceq $sourceCommit -and
    [string]$contractRecord.attempt_id -ceq $attemptId -and
    [string]$matrixRecord.attempt_id -ceq $attemptId -and
    [int]$contractRecord.world_count -eq 3 -and
    [int]$matrixRecord.world_count -eq 3 -and
    [int]$contractRecord.execution_valid_cell_count -eq 3 -and
    [int]$matrixRecord.execution_valid_cell_count -eq 3 -and
    [int]$contractRecord.common_gate_pass_cell_count -eq 3 -and
    [int]$matrixRecord.common_gate_pass_cell_count -eq 3 -and
    [bool]$contractRecord.complete_dependency_inventory_proved -and
    [bool]$matrixRecord.complete_dependency_inventory_proved -and
    [bool]$contractRecord.held_out_turning_positive -and
    [bool]$matrixRecord.held_out_turning_positive -and
    [bool]$contractRecord.godot_jolt_turning -and
    [bool]$matrixRecord.godot_jolt_turning -and
    -not [bool]$contractRecord.finite_three_engine_turning -and
    -not [bool]$matrixRecord.finite_three_engine_turning -and
    -not [bool]$contractRecord.portable_basic_turning -and
    -not [bool]$matrixRecord.portable_basic_turning -and
    -not [bool]$contractRecord.cross_engine_equivalence -and
    -not [bool]$matrixRecord.cross_engine_equivalence -and
    -not [bool]$contractRecord.prone_to_standing -and
    -not [bool]$matrixRecord.prone_to_standing -and
    -not [bool]$contractRecord.release_authorized -and
    -not [bool]$matrixRecord.release_authorized -and
    -not [bool]$contractRecord.physical_acceptance_authority -and
    -not [bool]$matrixRecord.physical_acceptance_authority
) "release contract or support matrix closure boundary changed"

$catalog = Get-Content -Raw -LiteralPath (
    Join-Path $repoRoot "sdk\workbench\experiment_catalog.json"
) | ConvertFrom-Json -Depth 100
$workbenchRuns = @($catalog.runs | Where-Object {
    [string]$_.id -ceq "qsdk_r23d60_physical_closure"
})
Assert-R23D60Closure (
    $workbenchRuns.Count -eq 1 -and
    [string]$workbenchRuns[0].kind -ceq "closure_audit" -and
    [string]$workbenchRuns[0].world_policy -ceq "retained_evidence_only" -and
    [string]$workbenchRuns[0].risk -ceq "safe" -and
    [string]$workbenchRuns[0].runner_path -ceq
        "tests/test_qsdk_r23d60_physical_closure.ps1" -and
    @($workbenchRuns[0].arguments).Count -eq 0 -and
    @($workbenchRuns[0].proofs).Count -eq 2 -and
    [string]$workbenchRuns[0].proofs[0].expected_sha256 -ceq
        $closureHash.Substring(7) -and
    [string]$workbenchRuns[0].proofs[1].expected_sha256 -ceq
        $auditHash.Substring(7)
) "workbench closure exposure changed"

$attempts = @(Get-ChildItem -LiteralPath $evidenceRoot -Directory | Where-Object {
    $_.Name -like "qsdk-r23d60-physical-*" -and
    (Test-Path -LiteralPath (Join-Path $_.FullName "attempt-authorization.json") -PathType Leaf)
})
Assert-R23D60Closure (
    $attempts.Count -eq 1 -and
    [IO.Path]::GetFullPath($attempts[0].FullName) -ceq
        [IO.Path]::GetFullPath($attemptRoot)
) "R23D60 one-shot physical attempt count changed"

Write-Host (
    "QSDK_R23D60_CLOSURE_PASS classification=valid_complete_positive " +
    "worlds=3 execution_valid=3 common_pass=3 common_fail=0 " +
    "raw_reference=-0.022523073875138966 raw_positive=0.20035480789390414 " +
    "raw_negative=-0.24345978790448441 conditioned_positive=0.2228778817690431 " +
    "conditioned_negative=0.22093671402934545 bilateral=0.44381459579838856 " +
    "rows=8976 applications=71808 cas_refs=374 cas_unique=205 " +
    "source_paths=136 dependency_edges=159 evaluator_replay=True " +
    "mutations=$mutationRejectionCount rerun=False godot_turning=True " +
    "three_engine=False prone=False physical_authority=False release=False"
)
