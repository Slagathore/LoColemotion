#requires -Version 7.0

function Assert-QuadrupedSdk1CandidateAuthority {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$Report,

        [Parameter(Mandatory = $true)]
        [string]$ExpectedReleaseId,

        [Parameter(Mandatory = $true)]
        [string]$ExpectedSourceCommit,

        [Parameter(Mandatory = $true)]
        [string]$ExpectedMappingId,

        [Parameter(Mandatory = $true)]
        [string]$ExpectedMappingSha256,

        [Parameter(Mandatory = $true)]
        [string]$ExpectedContractSha256,

        [Parameter(Mandatory = $true)]
        [string]$ExpectedSupportMatrixSha256
    )

    function Assert-Sdk1CandidateValue {
        param(
            [bool]$Condition,
            [string]$Message
        )
        if (-not $Condition) {
            throw $Message
        }
    }

    $validationMilestoneIds = @("SDK1-M01", "SDK1-M11", "SDK1-M15")
    $validationGateIds = @("QSDK-R01", "QSDK-R16", "QSDK-R20")
    $deferredFullProgramGateIds = @(
        "QSDK-R06",
        "QSDK-R07",
        "QSDK-R09",
        "QSDK-R11",
        "QSDK-R12",
        "QSDK-R25"
    )
    $expectedMilestoneIds = @(1..20 | ForEach-Object { "SDK1-M{0:D2}" -f $_ })

    Assert-Sdk1CandidateValue (
        [string]$Report.schema_version -ceq
            "sporespore_quadruped_sdk1_milestone_readiness_report_v1" -and
        [string]$Report.release_id -ceq $ExpectedReleaseId -and
        [string]$Report.mapping_id -ceq $ExpectedMappingId
    ) "SDK1 candidate authorization identity is invalid"
    Assert-Sdk1CandidateValue (
        [string]$Report.status -ceq "blocked" -and
        -not [bool]$Report.sdk1_milestones_complete -and
        -not [bool]$Report.mapping_completion_authorizes_release -and
        [bool]$Report.clean_room_candidate_authorized -and
        -not [bool]$Report.clean_room_candidate_release_authorized -and
        -not [bool]$Report.clean_room_candidate_publication_authorized -and
        [string]$Report.clean_room_candidate_artifact_role -ceq
            "sdk1_clean_room_conformance_candidate"
    ) "SDK1 candidate authorization escaped its nonrelease claim boundary"

    Assert-Sdk1CandidateValue (
        [string]$Report.ledger_scope.subsystem -ceq "release" -and
        [string]$Report.ledger_scope.engine_scope -ceq "engine_neutral" -and
        [string]$Report.ledger_scope.authority_mode -ceq
            "bounded_sdk1_milestone_and_candidate_authorization" -and
        [string]$Report.ledger_scope.question_class -ceq "development"
    ) "SDK1 candidate authorization ledger scope is invalid"
    Assert-Sdk1CandidateValue (
        [string]$Report.source.commit -ceq $ExpectedSourceCommit -and
        [string]$Report.source.origin_main -ceq $ExpectedSourceCommit -and
        [bool]$Report.source.clean -and
        [bool]$Report.source.matches_origin_main -and
        @($Report.source.status_entries).Count -eq 0
    ) "SDK1 candidate authorization does not bind clean pushed source"
    Assert-Sdk1CandidateValue (
        [string]$Report.mapping.path -ceq
            "sdk/release/quadruped_sdk1_milestone_mapping_v1.json" -and
        [string]$Report.mapping.schema_version -ceq
            "sporespore_quadruped_sdk1_milestone_mapping_v1" -and
        [string]$Report.mapping.sha256 -ceq $ExpectedMappingSha256
    ) "SDK1 candidate authorization mapping identity is invalid"
    Assert-Sdk1CandidateValue (
        [string]$Report.contract.schema_version -ceq
            "sporespore_quadruped_sdk_release_contract_v1"
    ) "SDK1 candidate authorization release-contract schema is invalid"
    Assert-Sdk1CandidateValue (
        [string]$Report.contract.sha256 -ceq $ExpectedContractSha256
    ) "SDK1 candidate authorization release-contract hash is invalid"
    Assert-Sdk1CandidateValue (
        [string]$Report.support_matrix.schema_version -ceq
            "sporespore_quadruped_sdk_support_matrix_v1"
    ) "SDK1 candidate authorization support-matrix schema is invalid"
    Assert-Sdk1CandidateValue (
        [string]$Report.support_matrix.sha256 -ceq
            $ExpectedSupportMatrixSha256
    ) "SDK1 candidate authorization support-matrix hash is invalid"
    Assert-Sdk1CandidateValue (
        [bool]$Report.support_matrix.consistent_with_gate_dispositions -and
        @($Report.support_matrix.failures).Count -eq 0
    ) "SDK1 candidate authorization support matrix is inconsistent"
    Assert-Sdk1CandidateValue (
        -not [bool]$Report.full_program.denominator_changed
    ) "SDK1 candidate authorization changed the full-program denominator"

    Assert-Sdk1CandidateValue (
        [int]$Report.sdk1_counts.total -eq 20 -and
        [int]$Report.sdk1_counts.passed -eq 17 -and
        [int]$Report.sdk1_counts.missing -eq 3 -and
        [int]$Report.sdk1_counts.contradicted -eq 0 -and
        [int]$Report.sdk1_counts.invalid_proof -eq 0
    ) "SDK1 candidate authorization does not preserve the exact 17+3 count"
    Assert-Sdk1CandidateValue (
        (@($Report.clean_room_candidate_validation_milestone_ids) -join "|") -ceq
            ($validationMilestoneIds -join "|") -and
        (@($Report.clean_room_candidate_validation_gate_ids) -join "|") -ceq
            ($validationGateIds -join "|") -and
        [int]$Report.clean_room_candidate_prerequisite_milestone_count -eq 17 -and
        [int]$Report.clean_room_candidate_validation_milestone_count -eq 3 -and
        [bool]$Report.two_stage_package_flow_satisfiable
    ) "SDK1 candidate authorization validation partition is invalid"
    Assert-Sdk1CandidateValue (
        @($Report.clean_room_candidate_blocking_milestone_ids).Count -eq 0 -and
        @($Report.clean_room_candidate_blocking_conditions).Count -eq 0 -and
        (@($Report.deferred_full_program_gate_ids) -join "|") -ceq
            ($deferredFullProgramGateIds -join "|") -and
        (@($Report.clean_room_candidate_deferred_full_program_gate_ids_ignored) -join "|") -ceq
            ($deferredFullProgramGateIds -join "|")
    ) "SDK1 candidate authorization blockers or deferred-gate boundary are invalid"

    $milestones = @($Report.milestones)
    $observedMilestoneIds = @(
        $milestones | ForEach-Object { [string]$_.milestone_id }
    )
    Assert-Sdk1CandidateValue (
        $milestones.Count -eq 20 -and
        @($observedMilestoneIds | Select-Object -Unique).Count -eq 20 -and
        (@($observedMilestoneIds | Sort-Object) -join "|") -ceq
            (@($expectedMilestoneIds | Sort-Object) -join "|")
    ) "SDK1 candidate authorization milestone population is invalid"
    $validationMilestones = @(
        $milestones | Where-Object {
            $validationMilestoneIds -ccontains [string]$_.milestone_id
        }
    )
    $prerequisiteMilestones = @(
        $milestones | Where-Object {
            $validationMilestoneIds -cnotcontains [string]$_.milestone_id
        }
    )
    Assert-Sdk1CandidateValue (
        $validationMilestones.Count -eq 3 -and
        @($validationMilestones | Where-Object { [string]$_.disposition -cne "missing" }).Count -eq 0 -and
        $prerequisiteMilestones.Count -eq 17 -and
        @($prerequisiteMilestones | Where-Object { [string]$_.disposition -cne "passed" }).Count -eq 0 -and
        (@($Report.blocking_milestone_ids) -join "|") -ceq
            ($validationMilestoneIds -join "|")
    ) "SDK1 candidate authorization milestone dispositions are invalid"

    Assert-Sdk1CandidateValue (
        [bool]$Report.claims.bounded_sdk1_scope_mapped -and
        -not [bool]$Report.claims.clean_room_candidate_is_full_program_candidate -and
        -not [bool]$Report.claims.clean_room_candidate_is_release -and
        -not [bool]$Report.claims.sdk1_released -and
        -not [bool]$Report.claims.publication_authorized
    ) "SDK1 candidate authorization claims more than bounded validation authority"

    return [ordered]@{
        authority_scope = "bounded_sdk1_17_plus_3"
        schema_version = [string]$Report.schema_version
        release_id = [string]$Report.release_id
        mapping_id = [string]$Report.mapping_id
        source_commit = [string]$Report.source.commit
        clean_room_candidate_authorized = $true
        release_authorized = $false
        publication_authorized = $false
        validation_milestone_ids = $validationMilestoneIds
        validation_gate_ids = $validationGateIds
        deferred_full_program_gate_ids = $deferredFullProgramGateIds
    }
}
