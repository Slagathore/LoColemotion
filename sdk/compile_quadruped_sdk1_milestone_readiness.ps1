[CmdletBinding()]
param(
    [string]$Mapping = (
        Join-Path $PSScriptRoot "release\quadruped_sdk1_milestone_mapping_v1.json"
    ),
    [string]$FullProgramCompiler = (
        Join-Path $PSScriptRoot "compile_quadruped_sdk_release_readiness.ps1"
    ),
    [string]$Output = "",
    [switch]$RequireCandidate,
    [string]$Python = 'C:/Program Files/Python311/python.exe'
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$sdkRoot = [IO.Path]::GetFullPath($PSScriptRoot)
$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $sdkRoot))
$mappingPath = [IO.Path]::GetFullPath($Mapping)
$fullCompilerPath = [IO.Path]::GetFullPath($FullProgramCompiler)

function Assert-Exact([bool]$Condition, [string]$Message) {
    if (-not $Condition) {
        throw $Message
    }
}

function Read-JsonObject([string]$Path) {
    Assert-Exact (Test-Path -LiteralPath $Path -PathType Leaf) (
        "Required SDK1 readiness source is missing: $Path"
    )
    try {
        $value = Get-Content -Raw -LiteralPath $Path | ConvertFrom-Json -Depth 100
    } catch {
        throw "Invalid JSON at ${Path}: $($_.Exception.Message)"
    }
    Assert-Exact ($null -ne $value -and $value -is [pscustomobject]) (
        "Expected one JSON object at $Path"
    )
    return $value
}

function Get-RawSha256([string]$Path) {
    return "sha256:" + (
        Get-FileHash -Algorithm SHA256 -LiteralPath $Path
    ).Hash.ToLowerInvariant()
}

function Get-StringSha256([string]$Value) {
    $bytes = [Text.Encoding]::UTF8.GetBytes($Value)
    $hasher = [Security.Cryptography.SHA256]::Create()
    try {
        return "sha256:" + [Convert]::ToHexString(
            $hasher.ComputeHash($bytes)
        ).ToLowerInvariant()
    } finally {
        $hasher.Dispose()
    }
}

function Get-UniqueStrings([object[]]$Values, [string]$Label) {
    $items = @($Values | ForEach-Object { [string]$_ })
    Assert-Exact (@($items | Where-Object { [string]::IsNullOrWhiteSpace($_) }).Count -eq 0) (
        "$Label contains an empty value"
    )
    $unique = @($items | Sort-Object -Unique)
    Assert-Exact ($unique.Count -eq $items.Count) "$Label contains duplicates"
    return $unique
}

$mappingObject = Read-JsonObject $mappingPath
Assert-Exact (
    [string]$mappingObject.schema_version -ceq
        "sporespore_quadruped_sdk1_milestone_mapping_v1"
) "Unexpected SDK1 milestone mapping schema"
Assert-Exact (
    [string]$mappingObject.status -ceq "active_bounded_sdk1_scope_mapping"
) "SDK1 milestone mapping is not active"
$ledgerScope = $mappingObject.ledger_scope
Assert-Exact (
    [string]$ledgerScope.subsystem -ceq "release" -and
    [string]$ledgerScope.engine_scope -ceq "engine_neutral" -and
    [string]$ledgerScope.authority_mode -ceq
        "bounded_sdk1_milestone_and_candidate_authorization" -and
    [string]$ledgerScope.question_class -ceq "development"
) "SDK1 milestone mapping ledger scope is invalid"

$scope = $mappingObject.scope_provenance
$scopeCommit = [string]$scope.source_commit
$scopePath = [string]$scope.source_path
$scopeBlob = [string]$scope.source_git_blob_oid
$observedBlobType = @(
    & git -C $repoRoot cat-file -t $scopeBlob 2>&1 |
        ForEach-Object { [string]$_ }
) -join "`n"
Assert-Exact ($LASTEXITCODE -eq 0 -and $observedBlobType.Trim() -ceq "blob") (
    "SDK1 scope provenance Git object is not a blob: $scopeBlob"
)
$observedBlobSize = @(
    & git -C $repoRoot cat-file -s $scopeBlob 2>&1 |
        ForEach-Object { [string]$_ }
) -join "`n"
Assert-Exact ($LASTEXITCODE -eq 0) "Could not read SDK1 scope provenance blob size"
Assert-Exact ([long]$observedBlobSize.Trim() -eq [long]$scope.source_git_blob_byte_length) (
    "SDK1 scope provenance blob byte length drifted"
)
$observedCommitBlob = @(
    & git -C $repoRoot rev-parse "${scopeCommit}:$scopePath" 2>&1 |
        ForEach-Object { [string]$_ }
) -join "`n"
Assert-Exact ($LASTEXITCODE -eq 0 -and $observedCommitBlob.Trim() -ceq $scopeBlob) (
    "SDK1 scope decision commit/path no longer resolves to the declared blob"
)
Assert-Exact (-not [bool]$scope.historical_gate_or_result_reinterpreted) (
    "SDK1 scope mapping may not reinterpret a historical gate or result"
)

$fullAuthority = $mappingObject.full_program_authority
$releaseContractPath = [IO.Path]::GetFullPath(
    (Join-Path $repoRoot ([string]$fullAuthority.release_contract_path))
)
$supportMatrixPath = [IO.Path]::GetFullPath(
    (Join-Path $repoRoot ([string]$fullAuthority.support_matrix_path))
)
$releaseContract = Read-JsonObject $releaseContractPath
$supportMatrix = Read-JsonObject $supportMatrixPath
Assert-Exact (
    [string]$releaseContract.schema_version -ceq
        [string]$fullAuthority.release_contract_schema_version
) "SDK1 mapping release-contract schema drifted"
Assert-Exact (
    [string]$supportMatrix.schema_version -ceq
        [string]$fullAuthority.support_matrix_schema_version
) "SDK1 mapping support-matrix schema drifted"
Assert-Exact (
    (Get-RawSha256 $releaseContractPath) -ceq
        [string]$fullAuthority.release_contract_raw_sha256
) "SDK1 mapping release-contract identity drifted"
Assert-Exact (
    (Get-RawSha256 $supportMatrixPath) -ceq
        [string]$fullAuthority.support_matrix_raw_sha256
) "SDK1 mapping support-matrix identity drifted"
Assert-Exact (-not [bool]$fullAuthority.full_program_denominator_changed) (
    "SDK1 mapping may not claim to change the full-program denominator"
)

Assert-Exact (Test-Path -LiteralPath $fullCompilerPath -PathType Leaf) (
    "Full-program readiness compiler is missing: $fullCompilerPath"
)
$fullLines = @(
    & pwsh -NoProfile -File $fullCompilerPath 6>$null |
        ForEach-Object { [string]$_ }
)
Assert-Exact ($LASTEXITCODE -eq 0) "Full-program readiness compiler failed"
$fullPrefix = "QUADRUPED_SDK_RELEASE_READINESS "
$fullReportLines = @(
    $fullLines | Where-Object {
        $_.StartsWith($fullPrefix, [StringComparison]::Ordinal)
    }
)
Assert-Exact ($fullReportLines.Count -eq 1) (
    "Expected exactly one full-program readiness marker"
)
$fullReport = $fullReportLines[0].Substring($fullPrefix.Length) |
    ConvertFrom-Json -Depth 100
Assert-Exact (
    [string]$fullReport.contract.sha256 -ceq
        [string]$fullAuthority.release_contract_raw_sha256
) "Full-program compiler used a different release contract"
Assert-Exact (
    [string]$fullReport.support_matrix.sha256 -ceq
        [string]$fullAuthority.support_matrix_raw_sha256
) "Full-program compiler used a different support matrix"
Assert-Exact ([bool]$fullReport.support_matrix.consistent_with_gate_dispositions) (
    "Full-program support matrix is inconsistent with gate dispositions"
)

$fullReleaseGates = @($fullReport.gates | Where-Object { [bool]$_.required_for_release })
Assert-Exact (
    $fullReleaseGates.Count -eq [int]$fullAuthority.full_program_release_gate_count
) "Full-program release-gate count drifted"
$fullGateIds = Get-UniqueStrings @(
    $fullReleaseGates | ForEach-Object { [string]$_.gate_id }
) "Full-program release gate IDs"

$milestones = @($mappingObject.sdk1_contract.milestones)
Assert-Exact (
    $milestones.Count -eq [int]$mappingObject.sdk1_contract.milestone_count
) "SDK1 milestone count does not match its declaration"
Assert-Exact ($milestones.Count -eq 20) "SDK1 v1 must contain exactly 20 milestones"
$milestoneIds = Get-UniqueStrings @(
    $milestones | ForEach-Object { [string]$_.milestone_id }
) "SDK1 milestone IDs"
$expectedMilestoneIds = @(1..20 | ForEach-Object { "SDK1-M{0:D2}" -f $_ })
Assert-Exact (@(Compare-Object $milestoneIds $expectedMilestoneIds).Count -eq 0) (
    "SDK1 milestone ID population drifted"
)

$mappedGateIds = @(
    $milestones |
        Where-Object { [string]$_.source.kind -ceq "full_program_gate" } |
        ForEach-Object { [string]$_.source.gate_id }
)
$mappedGateIds = Get-UniqueStrings $mappedGateIds "SDK1 mapped full-program gate IDs"
$explicitMilestones = @(
    $milestones | Where-Object {
        [string]$_.source.kind -ceq "explicit_sdk1_proof"
    }
)
Assert-Exact ($mappedGateIds.Count -eq 19 -and $explicitMilestones.Count -eq 1) (
    "SDK1 v1 must map 19 full-program gates and one explicit Explorer milestone"
)
Assert-Exact (
    [string]$explicitMilestones[0].milestone_id -ceq "SDK1-M20"
) "SDK1 explicit milestone must be the Explorer/showcase boundary"

$deferred = @($fullAuthority.deferred_full_program_gates)
$deferredIds = Get-UniqueStrings @(
    $deferred | ForEach-Object { [string]$_.gate_id }
) "Deferred full-program gate IDs"
Assert-Exact ($deferredIds.Count -eq 6) "SDK1 v1 must explicitly defer six gates"
Assert-Exact (@($mappedGateIds | Where-Object { $deferredIds -contains $_ }).Count -eq 0) (
    "A full-program gate cannot be both mapped into SDK1 and deferred"
)
$partitionIds = @($mappedGateIds + $deferredIds | Sort-Object -Unique)
Assert-Exact (@(Compare-Object $partitionIds $fullGateIds).Count -eq 0) (
    "SDK1 mapped/deferred gate partition does not cover the exact full program"
)

$candidateStage = $mappingObject.clean_room_candidate_stage
Assert-Exact (
    [string]$candidateStage.status -ceq
        "active_bounded_sdk1_nonrelease_candidate_stage" -and
    [string]$candidateStage.artifact_role -ceq
        "sdk1_clean_room_conformance_candidate" -and
    -not [bool]$candidateStage.deferred_full_program_gates_are_candidate_prerequisites -and
    -not [bool]$candidateStage.satisfies_full_program_candidate_stage -and
    -not [bool]$candidateStage.release_authority -and
    -not [bool]$candidateStage.publication_authority -and
    -not [bool]$candidateStage.physical_acceptance_authority
) "SDK1 clean-room candidate claim boundary is invalid"
$candidateValidationMilestoneIds = Get-UniqueStrings @(
    $candidateStage.validation_milestone_ids | ForEach-Object { [string]$_ }
) "SDK1 clean-room candidate validation milestone IDs"
$candidateValidationGateIds = Get-UniqueStrings @(
    $candidateStage.validation_gate_ids | ForEach-Object { [string]$_ }
) "SDK1 clean-room candidate validation gate IDs"
Assert-Exact (
    ($candidateValidationMilestoneIds -join "|") -ceq
        "SDK1-M01|SDK1-M11|SDK1-M15"
) "SDK1 clean-room candidate validation milestones must be exactly M01, M11, and M15"
Assert-Exact (
    ($candidateValidationGateIds -join "|") -ceq
        "QSDK-R01|QSDK-R16|QSDK-R20"
) "SDK1 clean-room candidate validation gates must be exactly R01, R16, and R20"
$fullCandidateValidationGateIds = Get-UniqueStrings @(
    $releaseContract.clean_room_candidate_stage.validation_gate_ids |
        ForEach-Object { [string]$_ }
) "Full-program clean-room candidate validation gate IDs"
Assert-Exact (
    ($candidateValidationGateIds -join "|") -ceq
        ($fullCandidateValidationGateIds -join "|")
) "SDK1 and full-program package-bound gate populations differ"
for ($candidateIndex = 0; $candidateIndex -lt 3; $candidateIndex++) {
    $candidateMilestoneId = $candidateValidationMilestoneIds[$candidateIndex]
    $candidateGateId = $candidateValidationGateIds[$candidateIndex]
    $candidateMatches = @($milestones | Where-Object {
        [string]$_.milestone_id -ceq $candidateMilestoneId -and
        [string]$_.source.kind -ceq "full_program_gate" -and
        [string]$_.source.gate_id -ceq $candidateGateId
    })
    Assert-Exact ($candidateMatches.Count -eq 1) (
        "SDK1 candidate milestone $candidateMilestoneId must map uniquely to $candidateGateId"
    )
}

$compiledMilestones = [Collections.Generic.List[object]]::new()
foreach ($milestone in $milestones) {
    $sourceKind = [string]$milestone.source.kind
    $disposition = ""
    $detail = ""
    $sourceGateId = $null
    switch ($sourceKind) {
        "full_program_gate" {
            $sourceGateId = [string]$milestone.source.gate_id
            $matches = @($fullReleaseGates | Where-Object {
                [string]$_.gate_id -ceq $sourceGateId
            })
            Assert-Exact ($matches.Count -eq 1) (
                "SDK1 milestone source gate is not unique: $sourceGateId"
            )
            $disposition = [string]$matches[0].disposition
            $detail = [string]$matches[0].detail
        }
        "explicit_sdk1_proof" {
            $proof = $milestone.source.proof
            if ([string]$proof.kind -ceq "missing") {
                $disposition = "missing"
                $detail = [string]$proof.reason
            } elseif ([string]$proof.kind -ceq "explorer_interface_closure_v1") {
                # Reopen the original retained streams and desktop receipts;
                # a hand-edited passed flag cannot satisfy this milestone.
                try {
                    Assert-Exact ([string]$milestone.milestone_id -ceq "SDK1-M20") "Explorer proof belongs only to M20"
                    Assert-Exact ([string]$proof.path -ceq "sdk/explorer/showcase_closure_v1.json") "Unexpected Explorer closure path"
                    Assert-Exact ([string]$proof.auditor_path -ceq "sdk/release/check_explorer.py") "Unexpected Explorer auditor path"
                    $explorerClosure = Join-Path $repoRoot ([string]$proof.path)
                    $explorerAuditor = Join-Path $repoRoot ([string]$proof.auditor_path)
                    Assert-Exact ((Get-RawSha256 $explorerClosure) -ceq [string]$proof.raw_sha256) "Explorer closure identity drift"
                    Assert-Exact ((Get-RawSha256 $explorerAuditor) -ceq [string]$proof.auditor_raw_sha256) "Explorer auditor identity drift"
                    $explorerLines = @(& $Python -B -X utf8 $explorerAuditor --closure $explorerClosure)
                    Assert-Exact ($LASTEXITCODE -eq 0 -and $explorerLines.Count -eq 1) "Explorer evidence audit refused"
                    $explorerResult = $explorerLines[0] | ConvertFrom-Json -Depth 100
                    Assert-Exact (
                        $explorerResult.schema_version -ceq "sporespore_explorer_interface_audit_v1" -and
                        $explorerResult.ok -eq $true -and $explorerResult.sdk1_m20_passed -eq $true -and
                        $explorerResult.desktop_interactions_passed -eq $true -and
                        $explorerResult.world_build_count -eq 0 -and $explorerResult.solver_step_count -eq 0 -and
                        $explorerResult.physical_acceptance_authority -eq $false -and $explorerResult.release_authority -eq $false
                    ) "Explorer audit scope or result mismatch"
                    $disposition = "passed"
                    $detail = "Isolated three-engine native desktop, bounded construction edits, interaction, provenance and recorded replay verified. No new physical acceptance or release authority."
                } catch {
                    $disposition = "invalid_proof"
                    $detail = "Explorer closure refused: " + $_.Exception.Message
                }
            } else {
                throw "Unsupported explicit SDK1 proof kind: $($proof.kind)"
            }
        }
        default {
            throw "Unsupported SDK1 milestone source kind: $sourceKind"
        }
    }
    Assert-Exact (
        @("passed", "missing", "contradicted", "invalid_proof") -contains
            $disposition
    ) "Unsupported SDK1 milestone disposition: $disposition"
    [void]$compiledMilestones.Add([ordered]@{
        milestone_id = [string]$milestone.milestone_id
        label = [string]$milestone.label
        plain_english_requirement = [string]$milestone.plain_english_requirement
        source_kind = $sourceKind
        source_gate_id = $sourceGateId
        disposition = $disposition
        source_detail_byte_length = [Text.Encoding]::UTF8.GetByteCount($detail)
        source_detail_raw_sha256 = if ($detail.Length -gt 0) {
            Get-StringSha256 $detail
        } else {
            $null
        }
        explicit_sdk1_reason = if ($sourceKind -ceq "explicit_sdk1_proof") {
            $detail
        } else {
            ""
        }
    })
}

$passedCount = @($compiledMilestones | Where-Object { $_.disposition -ceq "passed" }).Count
$missingCount = @($compiledMilestones | Where-Object { $_.disposition -ceq "missing" }).Count
$contradictedCount = @(
    $compiledMilestones | Where-Object { $_.disposition -ceq "contradicted" }
).Count
$invalidCount = @(
    $compiledMilestones | Where-Object { $_.disposition -ceq "invalid_proof" }
).Count
Assert-Exact (
    ($passedCount + $missingCount + $contradictedCount + $invalidCount) -eq 20
) "SDK1 milestone dispositions do not total 20"

$milestonesComplete = $passedCount -eq 20
$candidateValidationMilestones = @(
    $compiledMilestones | Where-Object {
        $candidateValidationMilestoneIds -ccontains $_.milestone_id
    }
)
$candidatePrerequisiteMilestones = @(
    $compiledMilestones | Where-Object {
        $candidateValidationMilestoneIds -cnotcontains $_.milestone_id
    }
)
$twoStagePackageFlowSatisfiable = (
    $candidateValidationMilestones.Count -eq 3 -and
    $candidatePrerequisiteMilestones.Count -eq 17 -and
    (
        $candidateValidationMilestones.Count +
        $candidatePrerequisiteMilestones.Count
    ) -eq $compiledMilestones.Count
)
Assert-Exact $twoStagePackageFlowSatisfiable (
    "SDK1 clean-room candidate does not form an exact 17+3 milestone partition"
)
$candidateBlockingMilestoneIds = @(
    $candidatePrerequisiteMilestones |
        Where-Object { $_.disposition -cne "passed" } |
        ForEach-Object { $_.milestone_id }
)
$candidateBlockingConditions = @($candidateBlockingMilestoneIds)
# This authority opens the original 17+3 validation stage only. Once any of
# those three results has been adopted, a new package needs a distinct route;
# completion must not misleadingly advertise reusable candidate permission.
$candidateValidationUnobserved = @(
    $candidateValidationMilestones | Where-Object { $_.disposition -cne "missing" }
).Count -eq 0
if (-not $candidateValidationUnobserved) {
    $candidateBlockingConditions += "SDK1-CANDIDATE-VALIDATION-ALREADY-OBSERVED"
}
$informationalProofsValid = (
    [int]$fullReport.gate_counts.informational_invalid_proof -eq 0
)
$supportMatrixConsistent = [bool](
    $fullReport.support_matrix.consistent_with_gate_dispositions
)
$sourceClean = [bool]$fullReport.source.clean
$sourceMatchesOriginMain = [bool]$fullReport.source.matches_origin_main
if (-not $informationalProofsValid) {
    $candidateBlockingConditions += "SDK1-INFORMATIONAL-PROOF-INTEGRITY"
}
if (-not $supportMatrixConsistent) {
    $candidateBlockingConditions += "SDK1-SUPPORT-MATRIX-CONSISTENCY"
}
if (-not $sourceClean) {
    $candidateBlockingConditions += "SDK1-SOURCE-CLEAN"
}
if (-not $sourceMatchesOriginMain) {
    $candidateBlockingConditions += "SDK1-SOURCE-ORIGIN-MAIN"
}
$candidateAuthorized = (
    $candidateBlockingMilestoneIds.Count -eq 0 -and
    $candidateValidationUnobserved -and
    $informationalProofsValid -and
    $supportMatrixConsistent -and
    $sourceClean -and
    $sourceMatchesOriginMain
)
$report = [ordered]@{
    schema_version = "sporespore_quadruped_sdk1_milestone_readiness_report_v1"
    release_id = [string]$fullReport.release_id
    mapping_id = [string]$mappingObject.mapping_id
    status = if ($milestonesComplete) { "milestones_complete" } else { "blocked" }
    sdk1_milestones_complete = $milestonesComplete
    mapping_completion_authorizes_release = $false
    clean_room_candidate_authorized = $candidateAuthorized
    clean_room_candidate_release_authorized = $false
    clean_room_candidate_publication_authorized = $false
    clean_room_candidate_artifact_role = [string]$candidateStage.artifact_role
    ledger_scope = $ledgerScope
    source = $fullReport.source
    mapping = [ordered]@{
        path = [IO.Path]::GetRelativePath($repoRoot, $mappingPath).Replace("\", "/")
        sha256 = Get-RawSha256 $mappingPath
        schema_version = [string]$mappingObject.schema_version
    }
    contract = $fullReport.contract
    support_matrix = $fullReport.support_matrix
    full_program = [ordered]@{
        status = [string]$fullReport.status
        required_passed = [int]$fullReport.gate_counts.required_passed
        required_total = [int]$fullReport.gate_counts.required_for_release
        denominator_changed = $false
    }
    sdk1_counts = [ordered]@{
        total = 20
        passed = $passedCount
        missing = $missingCount
        contradicted = $contradictedCount
        invalid_proof = $invalidCount
    }
    deferred_full_program_gate_ids = $deferredIds
    clean_room_candidate_validation_milestone_ids = (
        $candidateValidationMilestoneIds
    )
    clean_room_candidate_validation_gate_ids = $candidateValidationGateIds
    clean_room_candidate_prerequisite_milestone_count = (
        $candidatePrerequisiteMilestones.Count
    )
    clean_room_candidate_validation_milestone_count = (
        $candidateValidationMilestones.Count
    )
    two_stage_package_flow_satisfiable = $twoStagePackageFlowSatisfiable
    clean_room_candidate_blocking_milestone_ids = (
        $candidateBlockingMilestoneIds
    )
    clean_room_candidate_blocking_conditions = $candidateBlockingConditions
    clean_room_candidate_deferred_full_program_gate_ids_ignored = $deferredIds
    blocking_milestone_ids = @(
        $compiledMilestones |
            Where-Object { $_.disposition -cne "passed" } |
            ForEach-Object { $_.milestone_id }
    )
    milestones = @($compiledMilestones)
    claims = [ordered]@{
        bounded_sdk1_scope_mapped = $true
        formal_cross_engine_equivalence_required_for_sdk1 = $false
        arbitrary_or_continuous_morphology_required_for_sdk1 = $false
        same_canonical_semantics_in_three_native_engines_required = $true
        finite_per_engine_support_evidence_required = $true
        clean_room_candidate_is_full_program_candidate = $false
        clean_room_candidate_is_release = $false
        sdk1_released = $false
        publication_authorized = $false
    }
}

$json = $report | ConvertTo-Json -Depth 100 -Compress
if (-not [string]::IsNullOrWhiteSpace($Output)) {
    $outputPath = [IO.Path]::GetFullPath($Output)
    Assert-Exact (-not (Test-Path -LiteralPath $outputPath)) (
        "Refusing to overwrite SDK1 milestone readiness output: $outputPath"
    )
    $outputParent = Split-Path -Parent $outputPath
    if (-not [string]::IsNullOrWhiteSpace($outputParent)) {
        [void][IO.Directory]::CreateDirectory($outputParent)
    }
    [IO.File]::WriteAllText(
        $outputPath,
        ($report | ConvertTo-Json -Depth 100) + "`n",
        [Text.UTF8Encoding]::new($false)
    )
}

Write-Output ("QUADRUPED_SDK1_MILESTONE_READINESS " + $json)
Write-Host (
    "Quadruped SDK1 milestone readiness: status=$($report.status) " +
    "required=$passedCount/20 missing=$missingCount " +
    "contradicted=$contradictedCount invalid=$invalidCount " +
    "full_program=$($fullReport.gate_counts.required_passed)/" +
    "$($fullReport.gate_counts.required_for_release)"
)

if ($RequireCandidate -and -not $candidateAuthorized) {
    throw (
        "Quadruped SDK1 clean-room candidate is blocked by: " +
        ($candidateBlockingConditions -join ", ")
    )
}
