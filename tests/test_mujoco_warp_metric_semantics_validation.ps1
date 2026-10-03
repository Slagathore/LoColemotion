#requires -Version 7.0

[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = [System.IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$manifestPath = Join-Path $repoRoot (
    "sdk\adaptation_provider\" +
    "mujoco_warp_metric_semantics_validation_manifest.json"
)
$expectedRoot = "C:\Users\Cole\CodeStuff\games\SporeSpore"
$expectedRemote = "https://github.com/Slagathore/sporespore.git"
$expectedSource = "ba3ba521a8570c623ce26c06fb0c4148ac2e0a27"
$expectedPriorSource = "6ccc6c99c3f76f2176e13aea4e00ec4862416315"
$expectedContractHash = (
    "sha256:b6dbcf86ad6d49dbeba814640530a2e26f44091695b262e2f961a987d0dc368f"
)
$expectedCalibrationHash = (
    "sha256:c38f26211882f3349266f7381fcc5dc34acc9b20e5485d3b18d7f1185c35e374"
)
$expectedSemanticContractHash = (
    "sha256:eddc0afaabdafd483319007384cb5184e3fae792a74ae19002dd2b982caa1ceb"
)
$expectedSemanticManifestHash = (
    "sha256:270a98b21008bacccdfc446712bc3c66fb9eec4f9b75d47c2b7b886cf39483dc"
)
$expectedSemanticSource = "faaf057ad6379ba66ec1a4425f479082f28cb1b6"
$expectedSemanticReportHash = (
    "sha256:8102f0cbc8153f724d408ea4fc0393dfdb226b4a70c8521fb9e7b45b6be4b3fe"
)
$expectedSemanticIntegration = "dd553b6e669c8875eaff71fb0d35c59d65c5c329"
$expectedSemanticReceiptHash = (
    "sha256:67b6eedcb9aed2a2b2c16d8290c1452d4d2f8256c65f14d9f554c26d6487cfe9"
)
$expectedReportPath = (
    "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence\" +
    "mujoco-warp-metric-semantics-ba3ba52\report.json"
)
$expectedReportHash = (
    "sha256:d3d8e68fa904e1712642e0767b93b3f4c9395c36da3a46660aee123937d7a7e9"
)
$expectedPriorReportPath = (
    "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence\" +
    "mujoco-warp-metric-semantics-6ccc6c9\report.json"
)
$expectedPriorReportHash = (
    "sha256:f3bed691726530d98dbf5d0a6c73918a885bae5cd30b7c309233c5e42ff0def0"
)
$expectedSuiteHash = (
    "sha256:2b293a2ba2a156a7fe48be6e32556f2be545e8dea6a0e6526998729bed22d604"
)
$expectedReferenceTraceHash = (
    "sha256:4525383dc484644234e1689e242d7f657731be9d0870afb73aae09d95922a12c"
)
$expectedCandidateTraceHash = (
    "sha256:2498c7ea1c717d46e1e60671580041fcb75f0d6ed03c41e6f45681e2c0595481"
)
$expectedEvaluationHash = (
    "sha256:31d7e1bab623d47f0362da152d176086f1901dddd7dfb72ce851ab305d931b30"
)
$expectedCells = @(
    "mjms0_contract_and_predecessor_boundary",
    "mjms1_current_incomplete_inventory",
    "mjms2_fixture_suite_compilation",
    "mjms3_positive_fixture_evaluation",
    "mjms4_component_and_normalization_controls",
    "mjms5_trace_and_horizon_controls",
    "mjms6_energy_contact_and_failure_controls",
    "mjms7_authority_boundary"
)
$expectedMutations = @(
    "boolean_suite_world_count",
    "broad_component_population_claim",
    "component_reorder_changes_hash",
    "contact_event_reorder",
    "contact_identity_mismatch_retained",
    "contact_numeric_substitution",
    "contact_occurrence_gap",
    "declared_exact_failure_retained",
    "duplicate_component",
    "duplicate_contact_event",
    "empty_contact_set_is_exact_zero",
    "energy_denominator_floor_exact",
    "energy_observable_mutation",
    "extra_trace_component",
    "fixture_role_leak",
    "missing_contact_adequacy",
    "missing_energy_adequacy",
    "missing_normalization_adequacy",
    "missing_normalization_provenance",
    "missing_trace_component",
    "nonfinite_energy_floor",
    "nonfinite_normalization_scale",
    "nonfinite_trace_component",
    "nonfinite_trace_energy",
    "noninteger_suite_step_origin",
    "noninteger_trace_step_index",
    "nonpositive_energy_floor",
    "nonpositive_normalization_scale",
    "paired_horizon_mismatch",
    "periodic_shortest_arc_exact",
    "periodic_unit_mismatch",
    "postoutcome_contact_rule",
    "postoutcome_energy_rule",
    "postoutcome_normalization",
    "production_authority_injection",
    "quaternion_error_unit_mismatch",
    "quaternion_geodesic_and_scale_normalization",
    "quaternion_sign_invariance",
    "runtime_role_collision",
    "suite_contract_hash_mutation",
    "suite_world_count_injection",
    "trace_content_mutation_changes_hash",
    "trace_fixture_role_leak",
    "trace_sample_count_mismatch",
    "trace_step_reorder",
    "trace_suite_hash_mutation",
    "trace_world_count_injection",
    "unknown_contact_event_kind",
    "unknown_suite_field",
    "unknown_trace_field",
    "weakened_contact_matching",
    "zero_norm_quaternion"
)
$authorityFields = @(
    "production_metric_semantics_complete",
    "production_semantic_ceiling_sources_complete",
    "production_plan_frozen",
    "calibration_executed",
    "production_margins_frozen",
    "heldout_execution_authorized",
    "supported_physics_subset_qualified",
    "training_data_authority",
    "training_plane_authorized",
    "scientific_result",
    "physical_acceptance_authority",
    "release_authority"
)
$expectedBindings = @{
    "sdk/adaptation_provider/mujoco_warp_metric_semantics_contract_v1.json" = @{
        hash = $expectedContractHash
        length = 11001
    }
    "sdk/adaptation_provider/mujoco_warp_metric_semantics.py" = @{
        hash = "sha256:e0698dfdb68168eabbc2a1d30c1bb76be612b7c8ced1cecdd433e79cf8d0caf9"
        length = 43831
    }
    "sdk/adaptation_provider/mujoco_warp_metric_semantics_conformance.py" = @{
        hash = "sha256:b6a9046b64aa982bfe1160d57ec8576279f0e5f589352db01b2b9fa7124e4439"
        length = 39948
    }
    "sdk/adaptation_provider/test_mujoco_warp_metric_semantics.py" = @{
        hash = "sha256:e600ed9dc851b9865da01bca6bb38d559775164d981aa42e338b2440a604ce56"
        length = 4583
    }
    "sdk/run_mujoco_warp_metric_semantics_conformance.ps1" = @{
        hash = "sha256:e608a31dfe28977c7d6e6b2317763450adf4f86b693d9196f0dc9696227fcd73"
        length = 8404
    }
}

function Assert-MjmsEvidence([bool]$Condition, [string]$Message) {
    if (-not $Condition) {
        throw "MJWARP_METRIC_SEMANTICS_EVIDENCE $Message"
    }
}

function Get-GitBlobBytes {
    param(
        [Parameter(Mandatory = $true)][string]$Commit,
        [Parameter(Mandatory = $true)][string]$RepoRelativePath
    )

    $objectId = (& git -C $repoRoot rev-parse "$Commit`:$RepoRelativePath").Trim()
    Assert-MjmsEvidence ($LASTEXITCODE -eq 0) (
        "cannot resolve frozen Git blob: $RepoRelativePath"
    )
    $startInfo = [System.Diagnostics.ProcessStartInfo]::new("git")
    $startInfo.WorkingDirectory = $repoRoot
    $startInfo.ArgumentList.Add("cat-file")
    $startInfo.ArgumentList.Add("blob")
    $startInfo.ArgumentList.Add($objectId)
    $startInfo.UseShellExecute = $false
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $process = [System.Diagnostics.Process]::Start($startInfo)
    $stream = [System.IO.MemoryStream]::new()
    try {
        $process.StandardOutput.BaseStream.CopyTo($stream)
        $process.WaitForExit()
        $errorText = $process.StandardError.ReadToEnd()
        Assert-MjmsEvidence ($process.ExitCode -eq 0) (
            "cannot read frozen Git blob $RepoRelativePath`: $errorText"
        )
        return $stream.ToArray()
    } finally {
        $stream.Dispose()
        $process.Dispose()
    }
}

function Get-ByteSha256([byte[]]$Bytes) {
    return (
        "sha256:" +
        [Convert]::ToHexString(
            [System.Security.Cryptography.SHA256]::HashData($Bytes)
        ).ToLowerInvariant()
    )
}

function Get-Cell([hashtable]$Report, [string]$CellId) {
    $matches = @($Report["cells"] | Where-Object {
        [string]$_['cell_id'] -ceq $CellId
    })
    Assert-MjmsEvidence ($matches.Count -eq 1) (
        "report cell is missing or duplicated: $CellId"
    )
    return $matches[0]
}

Assert-MjmsEvidence (
    [System.IO.Path]::GetFullPath($repoRoot).TrimEnd("\") -ceq
        $expectedRoot.TrimEnd("\")
) "repository root differs from the canonical checkout"
$actualRoot = (& git -C $repoRoot rev-parse --show-toplevel).Trim()
$actualRemote = (& git -C $repoRoot remote get-url origin).Trim()
Assert-MjmsEvidence ($LASTEXITCODE -eq 0) "repository identity query failed"
Assert-MjmsEvidence (
    $actualRoot.Replace("/", "\").TrimEnd("\") -ceq
        $expectedRoot.TrimEnd("\") -and
    $actualRemote -ceq $expectedRemote
) "repository root or origin remote changed"
Assert-MjmsEvidence (Test-Path -LiteralPath $manifestPath -PathType Leaf) (
    "validation manifest is missing"
)

$manifest = Get-Content -LiteralPath $manifestPath -Raw |
    ConvertFrom-Json -AsHashtable -Depth 64
Assert-MjmsEvidence (
    [string]$manifest["schema_version"] -ceq
        "sporespore_mujoco_warp_metric_semantics_validation_manifest_v1" -and
    [string]$manifest["status"] -ceq
        "accepted_zero_world_source_conformance_with_prior_invalid_attempt_retained" -and
    [string]$manifest["question_class"] -ceq "development" -and
    [string]$manifest["release_gate_id"] -ceq "none" -and
    [string]$manifest["source_commit"] -ceq $expectedSource -and
    [string]$manifest["source_remote"] -ceq "origin/main" -and
    [bool]$manifest["source_clean"] -and
    [bool]$manifest["source_matches_origin_main"]
) "manifest identity or frozen source boundary changed"

foreach ($commit in @($expectedPriorSource, $expectedSource)) {
    & git -C $repoRoot cat-file -e "$commit^{commit}"
    Assert-MjmsEvidence ($LASTEXITCODE -eq 0) (
        "frozen source commit is unavailable: $commit"
    )
    & git -C $repoRoot merge-base --is-ancestor $commit origin/main
    Assert-MjmsEvidence ($LASTEXITCODE -eq 0) (
        "frozen source commit is not on origin/main: $commit"
    )
}

$frozenFiles = @($manifest["implementation"]) + @($manifest["contract"])
Assert-MjmsEvidence ($frozenFiles.Count -eq $expectedBindings.Count) (
    "manifest must bind exactly five frozen source files"
)
$observedPaths = @{}
foreach ($binding in $frozenFiles) {
    $path = [string]$binding["path"]
    Assert-MjmsEvidence (
        $path -cmatch "^sdk/[A-Za-z0-9_./-]+$" -and
        -not $path.Contains("..", [StringComparison]::Ordinal) -and
        $expectedBindings.ContainsKey($path) -and
        -not $observedPaths.ContainsKey($path)
    ) "frozen source path is unexpected or duplicated: $path"
    $observedPaths[$path] = $true
    $expected = $expectedBindings[$path]
    Assert-MjmsEvidence (
        [int]$binding["byte_length"] -eq [int]$expected["length"] -and
        [string]$binding["git_blob_raw_sha256"] -ceq [string]$expected["hash"]
    ) "manifest source binding changed: $path"
    $bytes = Get-GitBlobBytes -Commit $expectedSource -RepoRelativePath $path
    Assert-MjmsEvidence (
        $bytes.Length -eq [int]$expected["length"] -and
        (Get-ByteSha256 $bytes) -ceq [string]$expected["hash"]
    ) "frozen Git blob identity changed: $path"
}
Assert-MjmsEvidence ($observedPaths.Count -eq $expectedBindings.Count) (
    "manifest source coverage is incomplete"
)

$contract = $manifest["contract"]
Assert-MjmsEvidence (
    [string]$contract["contract_id"] -ceq
        "sporespore_mujoco_warp_precalibration_metric_semantics_readiness_v1" -and
    [string]$contract["git_blob_raw_sha256"] -ceq $expectedContractHash -and
    [string]$contract["calibration_contract_raw_sha256"] -ceq
        $expectedCalibrationHash -and
    [string]$contract["semantic_ceiling_contract_raw_sha256"] -ceq
        $expectedSemanticContractHash -and
    [string]$contract["semantic_ceiling_validation_manifest_raw_sha256"] -ceq
        $expectedSemanticManifestHash -and
    [string]$contract["semantic_ceiling_source_commit"] -ceq
        $expectedSemanticSource -and
    [string]$contract["semantic_ceiling_source_report_sha256"] -ceq
        $expectedSemanticReportHash -and
    [string]$contract["semantic_ceiling_integration_commit"] -ceq
        $expectedSemanticIntegration -and
    [string]$contract["semantic_ceiling_integration_receipt_sha256"] -ceq
        $expectedSemanticReceiptHash
) "contract or immutable predecessor identity changed"

$reportBinding = $manifest["report"]
$reportPath = [string]$reportBinding["path"]
Assert-MjmsEvidence (
    $reportPath -ceq $expectedReportPath -and
    $reportPath.StartsWith(
        "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence\",
        [StringComparison]::Ordinal
    ) -and
    (Test-Path -LiteralPath $reportPath -PathType Leaf)
) "accepted report is absent from the deliberate evidence root"
Assert-MjmsEvidence (
    [string]$reportBinding["sha256"] -ceq $expectedReportHash -and
    [int]$reportBinding["byte_length"] -eq 6037
) "accepted report binding changed"
$reportBytes = [System.IO.File]::ReadAllBytes($reportPath)
Assert-MjmsEvidence (
    $reportBytes.Length -eq [int]$reportBinding["byte_length"] -and
    (Get-ByteSha256 $reportBytes) -ceq [string]$reportBinding["sha256"]
) "accepted report bytes changed"
$report = [System.Text.Encoding]::UTF8.GetString($reportBytes) |
    ConvertFrom-Json -AsHashtable -Depth 64

Assert-MjmsEvidence (
    [string]$report["schema_version"] -ceq
        [string]$reportBinding["schema_version"] -and
    [bool]$report["ok"] -and
    [string]$report["contract_id"] -ceq [string]$contract["contract_id"] -and
    [string]$report["contract_raw_sha256"] -ceq $expectedContractHash -and
    [string]$report["source"]["commit"] -ceq $expectedSource -and
    [string]$report["source"]["origin_main"] -ceq $expectedSource -and
    [bool]$report["source"]["clean"] -and
    [bool]$report["source"]["matches_origin_main"] -and
    @($report["source"]["status_entries"]).Count -eq 0
) "accepted report is not bound to the exact clean pushed source"
Assert-MjmsEvidence (
    [int]$report["passed_cells"] -eq 8 -and
    [int]$report["passed_cells"] -eq [int]$reportBinding["passed_cells"] -and
    [int]$report["failed_cells"] -eq 0 -and
    [int]$report["failed_cells"] -eq [int]$reportBinding["failed_cells"] -and
    [int]$report["mutation_control_count"] -eq $expectedMutations.Count -and
    [int]$report["mutation_control_count"] -eq
        [int]$reportBinding["mutation_control_count"] -and
    [int]$report["required_metric_count"] -eq 5 -and
    [int]$report["production_metric_definition_count"] -eq 0 -and
    [int]$report["unresolved_metric_count"] -eq 5 -and
    [bool]$report["all_unresolved_reasons_retained"] -and
    [int]$report["positive_fixture_metric_count"] -eq 5 -and
    @($report["cells"]).Count -eq $expectedCells.Count
) "accepted report totals or finite inventory boundary changed"
Assert-MjmsEvidence (
    [int]$report["model_construction_count"] -eq 0 -and
    [int]$report["step_invocation_count"] -eq 0 -and
    [int]$report["world_attempt_count"] -eq 0 -and
    [int]$report["world_build_count"] -eq 0 -and
    -not [bool]$report["physics_state_modified"]
) "accepted report exceeded its zero-world source-only boundary"

for ($index = 0; $index -lt $expectedCells.Count; $index++) {
    $cell = $report["cells"][$index]
    Assert-MjmsEvidence (
        [string]$cell["cell_id"] -ceq $expectedCells[$index] -and
        [bool]$cell["passed"] -and
        [int]$cell["world_build_count"] -eq 0 -and
        -not [bool]$cell["physical_acceptance_authority"]
    ) "report cell order, result, or zero-world boundary changed at index $index"
}

$boundaryCell = Get-Cell -Report $report `
    -CellId "mjms0_contract_and_predecessor_boundary"
$currentCell = Get-Cell -Report $report `
    -CellId "mjms1_current_incomplete_inventory"
$fixtureCell = Get-Cell -Report $report `
    -CellId "mjms2_fixture_suite_compilation"
$evaluationCell = Get-Cell -Report $report `
    -CellId "mjms3_positive_fixture_evaluation"
$componentCell = Get-Cell -Report $report `
    -CellId "mjms4_component_and_normalization_controls"
$traceCell = Get-Cell -Report $report `
    -CellId "mjms5_trace_and_horizon_controls"
$semanticCell = Get-Cell -Report $report `
    -CellId "mjms6_energy_contact_and_failure_controls"
$authorityCell = Get-Cell -Report $report `
    -CellId "mjms7_authority_boundary"

Assert-MjmsEvidence (
    [string]$boundaryCell["contract_raw_sha256"] -ceq $expectedContractHash -and
    [string]$boundaryCell["calibration_contract_raw_sha256"] -ceq
        $expectedCalibrationHash -and
    [string]$boundaryCell["semantic_ceiling_contract_raw_sha256"] -ceq
        $expectedSemanticContractHash -and
    [string]$boundaryCell["semantic_ceiling_validation_manifest_raw_sha256"] -ceq
        $expectedSemanticManifestHash -and
    [string]$boundaryCell["semantic_ceiling_source_commit"] -ceq
        $expectedSemanticSource -and
    [string]$boundaryCell["semantic_ceiling_source_report_sha256"] -ceq
        $expectedSemanticReportHash -and
    [string]$boundaryCell["semantic_ceiling_integration_commit"] -ceq
        $expectedSemanticIntegration -and
    [string]$boundaryCell["semantic_ceiling_integration_receipt_sha256"] -ceq
        $expectedSemanticReceiptHash
) "report predecessor boundary changed"
Assert-MjmsEvidence (
    [int]$currentCell["production_metric_definition_count"] -eq 0 -and
    [int]$currentCell["unresolved_metric_count"] -eq 5 -and
    [bool]$currentCell["all_unresolved_reasons_retained"]
) "current incomplete metric inventory changed"
Assert-MjmsEvidence (
    [string]$fixtureCell["suite_sha256"] -ceq $expectedSuiteHash -and
    [string]$fixtureCell["suite_sha256"] -ceq
        [string]$reportBinding["fixture_suite_sha256"] -and
    [int]$fixtureCell["component_count"] -eq 7 -and
    [bool]$fixtureCell["compiler_fixture_complete"] -and
    -not [bool]$fixtureCell["production_metric_semantics_complete"]
) "fixture-only suite binding changed"
Assert-MjmsEvidence (
    [string]$evaluationCell["reference_trace_sha256"] -ceq
        $expectedReferenceTraceHash -and
    [string]$evaluationCell["reference_trace_sha256"] -ceq
        [string]$reportBinding["fixture_reference_trace_sha256"] -and
    [string]$evaluationCell["candidate_trace_sha256"] -ceq
        $expectedCandidateTraceHash -and
    [string]$evaluationCell["candidate_trace_sha256"] -ceq
        [string]$reportBinding["fixture_candidate_trace_sha256"] -and
    [string]$evaluationCell["evaluation_sha256"] -ceq
        $expectedEvaluationHash -and
    [string]$evaluationCell["evaluation_sha256"] -ceq
        [string]$reportBinding["fixture_evaluation_sha256"] -and
    [int]$evaluationCell["metric_count"] -eq 5 -and
    [bool]$evaluationCell["valid_metric_vector"]
) "content-addressed fixture evaluation binding changed"
Assert-MjmsEvidence (
    [int]$componentCell["rejected_control_count"] -eq 13 -and
    [int]$traceCell["rejected_control_count"] -eq 14 -and
    [int]$semanticCell["rejected_control_count"] -eq 18
) "mutation-family totals changed"

$rejectedMutations = $report["rejected_mutations"]
Assert-MjmsEvidence (
    $rejectedMutations.Count -eq $expectedMutations.Count
) "mutation-control count changed"
foreach ($mutation in $expectedMutations) {
    Assert-MjmsEvidence (
        $rejectedMutations.ContainsKey($mutation) -and
        [bool]$rejectedMutations[$mutation]
    ) "required mutation/property control did not pass: $mutation"
}

$priorBinding = $manifest["prior_invalid_attempt"]
Assert-MjmsEvidence (
    [string]$priorBinding["status"] -ceq
        "invalid_incomplete_terminal_audit" -and
    [string]$priorBinding["source_commit"] -ceq $expectedPriorSource -and
    [string]$priorBinding["report_path"] -ceq $expectedPriorReportPath -and
    [string]$priorBinding["report_sha256"] -ceq $expectedPriorReportHash -and
    [int]$priorBinding["report_byte_length"] -eq 6037 -and
    [string]$priorBinding["runner_path"] -ceq
        "sdk/run_mujoco_warp_metric_semantics_conformance.ps1" -and
    [string]$priorBinding["runner_git_blob_raw_sha256"] -ceq
        "sha256:d6d84a4fa4793944aa68182b076490075e94f8edcbd6662a271d9196fa178c4d" -and
    [int]$priorBinding["runner_byte_length"] -eq 5505 -and
    [string]$priorBinding["failure_code"] -ceq
        "powershell_strict_mode_property_collection_count" -and
    [string]$priorBinding["failing_expression"] -ceq
        '[int]$retained.rejected_mutations.psobject.Properties.Count' -and
    -not [bool]$priorBinding["terminal_audit_completed"] -and
    -not [bool]$priorBinding["accepted_source_conformance"] -and
    [int]$priorBinding["world_build_count"] -eq 0 -and
    -not [bool]$priorBinding["physical_acceptance_authority"] -and
    -not [bool]$priorBinding["release_authority"]
) "prior invalid/incomplete attempt binding changed"
Assert-MjmsEvidence (
    $expectedPriorReportPath.StartsWith(
        "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence\",
        [StringComparison]::Ordinal
    ) -and
    (Test-Path -LiteralPath $expectedPriorReportPath -PathType Leaf)
) "prior invalid report is missing from the deliberate evidence root"
$priorReportBytes = [System.IO.File]::ReadAllBytes($expectedPriorReportPath)
Assert-MjmsEvidence (
    $priorReportBytes.Length -eq 6037 -and
    (Get-ByteSha256 $priorReportBytes) -ceq $expectedPriorReportHash
) "prior invalid report bytes changed"
$priorReport = [System.Text.Encoding]::UTF8.GetString($priorReportBytes) |
    ConvertFrom-Json -AsHashtable -Depth 64
Assert-MjmsEvidence (
    [bool]$priorReport["ok"] -and
    [string]$priorReport["source"]["commit"] -ceq $expectedPriorSource -and
    [string]$priorReport["source"]["origin_main"] -ceq $expectedPriorSource -and
    [bool]$priorReport["source"]["clean"] -and
    [bool]$priorReport["source"]["matches_origin_main"] -and
    [int]$priorReport["passed_cells"] -eq 8 -and
    [int]$priorReport["failed_cells"] -eq 0 -and
    [int]$priorReport["mutation_control_count"] -eq 52 -and
    [int]$priorReport["world_build_count"] -eq 0 -and
    [string]$priorReport["cells"][2]["suite_sha256"] -ceq
        $expectedSuiteHash -and
    [string]$priorReport["cells"][3]["reference_trace_sha256"] -ceq
        $expectedReferenceTraceHash -and
    [string]$priorReport["cells"][3]["candidate_trace_sha256"] -ceq
        $expectedCandidateTraceHash -and
    [string]$priorReport["cells"][3]["evaluation_sha256"] -ceq
        $expectedEvaluationHash
) "prior invalid report body changed"

$priorRunnerBytes = Get-GitBlobBytes -Commit $expectedPriorSource `
    -RepoRelativePath ([string]$priorBinding["runner_path"])
$priorRunnerText = [System.Text.Encoding]::UTF8.GetString($priorRunnerBytes)
Assert-MjmsEvidence (
    $priorRunnerBytes.Length -eq [int]$priorBinding["runner_byte_length"] -and
    (Get-ByteSha256 $priorRunnerBytes) -ceq
        [string]$priorBinding["runner_git_blob_raw_sha256"] -and
    $priorRunnerText.Contains(
        [string]$priorBinding["failing_expression"],
        [StringComparison]::Ordinal
    )
) "prior invalid runner or exact failing expression changed"
$acceptedRunnerBytes = Get-GitBlobBytes -Commit $expectedSource `
    -RepoRelativePath ([string]$priorBinding["runner_path"])
$acceptedRunnerText = [System.Text.Encoding]::UTF8.GetString(
    $acceptedRunnerBytes
)
Assert-MjmsEvidence (
    -not $acceptedRunnerText.Contains(
        [string]$priorBinding["failing_expression"],
        [StringComparison]::Ordinal
    ) -and
    $acceptedRunnerText.Contains(
        '$retainedControls = @(',
        [StringComparison]::Ordinal
    ) -and
    $acceptedRunnerText.Contains(
        'retained report requires exact clean pushed live source',
        [StringComparison]::Ordinal
    )
) "accepted verifier-only repair boundary changed"

Assert-MjmsEvidence (
    [bool]$manifest["all_unresolved_reasons_retained"] -and
    [bool]$manifest["positive_fixture_only"] -and
    [bool]$report["fixture_only"] -and
    [bool]$authorityCell["current_inventory_incomplete"]
) "manifest or report omitted the incomplete fixture-only boundary"
foreach ($authority in $authorityFields) {
    Assert-MjmsEvidence (
        -not [bool]$manifest[$authority] -and
        -not [bool]$report[$authority] -and
        -not [bool]$priorReport[$authority]
    ) "manifest, accepted report, or prior invalid report gained authority: $authority"
}
Assert-MjmsEvidence (
    -not [bool]$authorityCell["production_metric_semantics_complete"] -and
    -not [bool]$authorityCell["production_semantic_ceiling_sources_complete"] -and
    -not [bool]$authorityCell["production_plan_frozen"] -and
    -not [bool]$authorityCell["calibration_authorized"] -and
    -not [bool]$authorityCell["heldout_qualification_authorized"] -and
    -not [bool]$authorityCell["supported_physics_subset_qualified"] -and
    -not [bool]$authorityCell["training_plane_authorized"] -and
    -not [bool]$authorityCell["scientific_result"] -and
    -not [bool]$authorityCell["physical_acceptance_authority"] -and
    -not [bool]$authorityCell["release_authority"]
) "terminal authority cell exceeded source-development scope"

Write-Host (
    "MJWARP_METRIC_SEMANTICS_EVIDENCE_PASS source=ba3ba52 cells=8 " +
    "controls=52 required=5 definitions=0 unresolved=5 fixture_metrics=5 " +
    "prior_invalid=1 models=0 steps=0 attempts=0 worlds=0 plan=false " +
    "calibration=false subset=false training=false"
)
