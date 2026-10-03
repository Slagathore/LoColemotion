#requires -Version 7.0

[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
. (Join-Path $repoRoot "sdk\qsdk_r05e_execution_authority_contract.ps1")

function Write-TestUtf8 {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][AllowEmptyString()][string]$Text
    )
    [void][IO.Directory]::CreateDirectory((Split-Path -Parent $Path))
    [IO.File]::WriteAllText($Path, $Text, [Text.UTF8Encoding]::new($false))
}

function Write-TestJson {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)]$Value
    )
    Write-TestUtf8 -Path $Path -Text (($Value | ConvertTo-Json -Depth 100) + "`n")
}

function Invoke-TestGit {
    param(
        [Parameter(Mandatory)][string]$Root,
        [Parameter(Mandatory)][string[]]$Arguments
    )
    $output = @(& git -C $Root @Arguments 2>&1)
    if ($LASTEXITCODE -ne 0) {
        throw "TEST_GIT_FAILED:$($Arguments -join ' '):$($output -join '|')"
    }
    return (($output | ForEach-Object { [string]$_ }) -join "`n").Trim()
}

function Copy-TestJsonValue {
    param([Parameter(Mandatory)]$Value)
    return (
        $Value |
            ConvertTo-Json -Depth 100 -Compress |
            ConvertFrom-Json -AsHashtable -Depth 100
    )
}

function Assert-TestRejected {
    param(
        [Parameter(Mandatory)][scriptblock]$Action,
        [Parameter(Mandatory)][string]$Label
    )
    $rejected = $false
    try {
        & $Action
    } catch {
        $rejected = $_.Exception.Message.StartsWith(
            "QSDK_R05E_EXECUTION_AUTHORITY:",
            [StringComparison]::Ordinal
        )
    }
    if (-not $rejected) {
        throw "R05E_AUTHORITY_MUTATION_NOT_REJECTED:$Label"
    }
}

$systemTemp = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd(
    [IO.Path]::DirectorySeparatorChar,
    [IO.Path]::AltDirectorySeparatorChar
)
$tempRoot = [IO.Path]::GetFullPath((Join-Path $systemTemp (
    "sporespore-r05e-authority-contract-test-" + [guid]::NewGuid().ToString("N")
)))
$testRepo = Join-Path $tempRoot "repo"
$evidenceRoot = Join-Path $tempRoot "evidence"
$authorityRelative = "sdk/authority.json"
$qualificationRelative = "sdk/qualification.json"
$implementationRelative = "sdk/conformance/qsdk_r05e_zero_world_implementation.py"
$workerRelative = "tests/worker.gd"
$authorityPath = Join-Path $testRepo $authorityRelative
$qualificationPath = Join-Path $testRepo $qualificationRelative
$qualificationReceiptPath = Join-Path $evidenceRoot "qualification/receipt.json"
$outputPath = [IO.Path]::GetFullPath((Join-Path $evidenceRoot "physical/report.json"))
$designSha = "sha256:" + ("1" * 64)
$preregistrationSha = "sha256:" + ("2" * 64)
$sourcePaths = @($implementationRelative, $workerRelative)

try {
    [void][IO.Directory]::CreateDirectory($testRepo)
    [void][IO.Directory]::CreateDirectory($evidenceRoot)
    $null = Invoke-TestGit -Root $testRepo -Arguments @("init", "-b", "main")
    $null = Invoke-TestGit -Root $testRepo -Arguments @("config", "user.email", "r05e@test.invalid")
    $null = Invoke-TestGit -Root $testRepo -Arguments @("config", "user.name", "R05E Test")
    $null = Invoke-TestGit -Root $testRepo -Arguments @("config", "core.autocrlf", "false")

    Write-TestUtf8 -Path (Join-Path $testRepo $implementationRelative) -Text "print('audit')`n"
    Write-TestUtf8 -Path (Join-Path $testRepo $workerRelative) -Text "extends SceneTree`n"
    $null = Invoke-TestGit -Root $testRepo -Arguments @(
        "add", "--", $implementationRelative, $workerRelative
    )
    $null = Invoke-TestGit -Root $testRepo -Arguments @("commit", "-m", "freeze source")
    $sourceFreeze = Invoke-TestGit -Root $testRepo -Arguments @("rev-parse", "HEAD")

    $sourceBindings = @(
        foreach ($relative in $sourcePaths) {
            $absolute = Join-Path $testRepo $relative
            [ordered]@{
                path = $relative
                git_blob_oid = Invoke-TestGit `
                    -Root $testRepo `
                    -Arguments @("rev-parse", "$sourceFreeze`:$relative")
                raw_sha256 = Get-SporeSporeR05ERawSha256 $absolute
                byte_length = [int64](Get-Item -LiteralPath $absolute).Length
            }
        }
    )
    $qualifiedSourcePathSha256 = Get-SporeSporeR05ETextSha256 `
        -Text ($sourcePaths -join "`n")
    $runtimeIdentity = [ordered]@{
        schema_version = "test_qsdk_r05e_runtime_identity_v1"
        immutable_token = "test-runtime"
    }
    $runtimeProjection = [ordered]@{
        schema_version = "sporespore_qsdk_r05e_runtime_identity_projection_v1"
        identity_sha256 = Get-SporeSporeR05ETextSha256 `
            -Text (ConvertTo-SporeSporeR05ECanonicalJson -Value $runtimeIdentity)
        identity = $runtimeIdentity
    }
    $qualificationToolPath = [IO.Path]::GetFullPath((Join-Path $PSHOME "pwsh.exe"))
    $qualificationToolIdentity = [ordered]@{
        path = $qualificationToolPath.Replace("\", "/")
        raw_sha256 = Get-SporeSporeR05ERawSha256 $qualificationToolPath
        byte_length = [int64](Get-Item -LiteralPath $qualificationToolPath).Length
        version = $PSVersionTable.PSVersion.ToString()
    }
    Write-TestJson -Path $qualificationReceiptPath -Value ([ordered]@{
        schema_version = "sporespore_qsdk_r05e_zero_world_implementation_audit_v1"
        gate_id = "QSDK-R05E"
        ledger_scope = [ordered]@{
            subsystem = "walking"
            engine_scope = "godot_jolt"
            authority_mode = "prospective_zero_world_implementation_audit"
            question_class = "development"
        }
        ok = $true
        source_commit = $sourceFreeze
        branch = "main"
        worktree_clean = $true
        head_origin_main_equal = $true
        head_live_remote_main_equal = $true
        official_qualification_mode = $true
        r05d_design_audit_passed = $true
        dependency_closure_audit_passed = $true
        dependency_gdscript_direct_entry_count = 1
        dependency_gdscript_transitive_path_count = 1
        dependency_rust_build_path_count = 1
        dependency_process_and_audit_path_count = 1
        qualified_source_path_count = $sourcePaths.Count
        qualified_source_path_sha256 = $qualifiedSourcePathSha256
        dependency_mutation_rejection_count = 4
        dependency_all_qualified_paths_lf_checkout_policy = $true
        dependency_all_qualified_paths_tracked = $true
        dependency_tracked_source_required = $true
        runtime_identity_projection = $runtimeProjection
        qualification_tool_identity = $qualificationToolIdentity
        runtime_identity_exact_across_supervisors = $true
        preregistration_count = 2
        supervisor_preflight_count = 2
        serialized_conformance_lock_count = 2
        final_operation_lock_release_probe_passed = $true
        official_descriptor_compile_count_per_supervisor = 12
        development_ghost_descriptor_compile_count_per_supervisor = 1
        source_mutation_control_count_per_supervisor = 32
        worker_authorization_type_mutation_refusal_count = 2
        authority_contract_positive_repository_graph_count = 2
        authority_contract_content_mutation_rejection_count = 35
        authority_contract_repository_binding_rejection_count = 5
        physical_missing_authority_refusal_count = 2
        held_out_locomotion_outcome_exposure_count = 0
        model_construction_count = 0
        world_attempt_count = 0
        world_build_count = 0
        native_readback_count = 0
        solver_step_count = 0
        physics_state_modified = $false
        physical_execution_authorized = $false
        physical_acceptance_authority = $false
        release_authority = $false
    })
    $qualificationReceiptSha = Get-SporeSporeR05ERawSha256 $qualificationReceiptPath
    $implementationSha = [string]$sourceBindings[0].raw_sha256
    $qualification = [ordered]@{
        schema_version = "test_r05e_qualification_v1"
        status = "closed_complete_zero_world_qualification_physics_still_sealed"
        gate_id = "QSDK-R05E-GHOST"
        campaign_id = "QSDK-R05E-DEVELOPMENT-ROUTE-GHOST"
        campaign_role = "development_route_ghost"
        question_class = "development"
        ledger_scope = [ordered]@{
            subsystem = "walking"
            engine_scope = "godot_jolt"
            authority_mode = "closed_content_addressed_zero_world_qualification"
            question_class = "development"
        }
        source = [ordered]@{
            source_freeze_commit = $sourceFreeze
            branch = "main"
            remote = "https://github.com/Slagathore/sporespore.git"
            upstream_equal_at_qualification = $true
            live_remote_equal_at_qualification = $true
            worktree_clean_at_qualification_start_and_end = $true
            qualified_source_file_count = $sourceBindings.Count
            source_bindings = $sourceBindings
        }
        preregistration = [ordered]@{
            path = "sdk/preregistration.json"
            sha256 = $preregistrationSha
            r05d_design_sha256 = $designSha
        }
        qualification = [ordered]@{
            qualification_receipt_path = [IO.Path]::GetFullPath($qualificationReceiptPath)
            qualification_receipt_sha256 = $qualificationReceiptSha
            qualification_receipt_byte_length = [int64](
                Get-Item -LiteralPath $qualificationReceiptPath
            ).Length
            implementation_audit_path = $implementationRelative
            implementation_audit_sha256 = $implementationSha
            official_zero_world_qualification_passed = $true
            qualification_attempt_count_for_source = 1
            supervisor_preflight_count = 2
            serialized_conformance_lock_count = 2
            dependency_closure_audit_passed = $true
            dependency_gdscript_direct_entry_count = 1
            dependency_gdscript_transitive_path_count = 1
            dependency_rust_build_path_count = 1
            dependency_process_and_audit_path_count = 1
            qualified_source_path_count = $sourcePaths.Count
            qualified_source_path_sha256 = $qualifiedSourcePathSha256
            dependency_mutation_rejection_count = 4
            dependency_all_qualified_paths_lf_checkout_policy = $true
            dependency_all_qualified_paths_tracked = $true
            dependency_tracked_source_required = $true
            runtime_identity_exact_across_supervisors = $true
            source_mutation_control_count_per_supervisor = 32
            physical_missing_authority_refusal_count = 2
            model_construction_count = 0
            world_attempt_count = 0
            world_build_count = 0
            native_readback_count = 0
            solver_step_count = 0
            physics_state_modified = $false
            operation_lock_released = $true
        }
        runtime = $runtimeProjection
        prerequisite = [ordered]@{
            development_route_ghost_required = $false
            development_route_ghost_complete = $false
            development_route_ghost_closure_path = ""
            development_route_ghost_closure_sha256 = ""
            development_route_ghost_closure_git_blob_oid = ""
        }
        decision = [ordered]@{
            qualification_complete = $true
            execution_authority_creation_permitted = $true
            physical_execution_authorized = $false
            same_identity_rerun_permitted = $false
            held_out = $false
        }
        claim_boundary = [ordered]@{
            physical_attempted = $false
            locomotion_outcome_exposed = $false
            same_selected_policy_independent_morphology_evidence = $false
            sdk1_milestone_advanced = $false
            physical_acceptance_authority = $false
            release_authority = $false
        }
    }
    Write-TestJson -Path $qualificationPath -Value $qualification
    $null = Invoke-TestGit -Root $testRepo -Arguments @("add", "--", $qualificationRelative)
    $null = Invoke-TestGit -Root $testRepo -Arguments @("commit", "-m", "qualify source")
    $authorizationParent = Invoke-TestGit -Root $testRepo -Arguments @("rev-parse", "HEAD")
    $qualificationSha = Get-SporeSporeR05ERawSha256 $qualificationPath
    $qualificationBlob = Invoke-TestGit `
        -Root $testRepo `
        -Arguments @("rev-parse", "$authorizationParent`:$qualificationRelative")

    $expected = [ordered]@{
        authority_schema = "test_r05e_authority_v1"
        authority_path = $authorityRelative
        qualification_schema = "test_r05e_qualification_v1"
        qualification_closure_path = $qualificationRelative
        campaign_id = "QSDK-R05E-DEVELOPMENT-ROUTE-GHOST"
        gate_id = "QSDK-R05E-GHOST"
        campaign_role = "development_route_ghost"
        question_class = "development"
        remote = "https://github.com/Slagathore/sporespore.git"
        r05d_design_sha256 = $designSha
        preregistration_path = "sdk/preregistration.json"
        preregistration_sha256 = $preregistrationSha
        expected_morphology_count = 1
        expected_world_count = 1
        output_report_path = $outputPath
        held_out = $false
        heldout_access_permitted = $false
        development_route_ghost_required = $false
        development_route_ghost_complete = $false
        development_route_ghost_closure_path = ""
        dependency_gdscript_direct_entry_count = 1
        dependency_gdscript_transitive_path_count = 1
        dependency_rust_build_path_count = 1
        dependency_process_and_audit_path_count = 1
        qualified_source_path_count = $sourcePaths.Count
        qualified_source_path_sha256 = $qualifiedSourcePathSha256
        runtime_identity_projection = $runtimeProjection
    }
    $authority = [ordered]@{
        schema_version = "test_r05e_authority_v1"
        status = "authorized_single_use_unconsumed"
        campaign_id = "QSDK-R05E-DEVELOPMENT-ROUTE-GHOST"
        gate_id = "QSDK-R05E-GHOST"
        campaign_role = "development_route_ghost"
        question_class = "development"
        ledger_scope = [ordered]@{
            subsystem = "walking"
            engine_scope = "godot_jolt"
            authority_mode = "single_use_physical_execution_authorization"
            question_class = "development"
        }
        authorization_commit_derived_from_current_head = $true
        authorization_parent_commit = $authorizationParent
        source_freeze_commit = $sourceFreeze
        qualification_closure_path = $qualificationRelative
        qualification_closure_sha256 = $qualificationSha
        qualification_closure_git_blob_oid = $qualificationBlob
        r05d_design_sha256 = $designSha
        preregistration_sha256 = $preregistrationSha
        expected_morphology_count = 1
        expected_world_count = 1
        output_report_path = $outputPath
        maximum_campaign_attempt_count = 1
        maximum_world_attempt_count = 1
        maximum_world_build_count = 1
        maximum_world_build_count_per_worker = 1
        zero_world_qualification_passed = $true
        physical_execution_authorized = $true
        physical_identity_consumed = $false
        same_identity_rerun_permitted = $false
        held_out = $false
        heldout_access_permitted = $false
        development_route_ghost_complete = $false
        prerequisite_development_route_ghost_closure_path = ""
        prerequisite_development_route_ghost_closure_sha256 = ""
        prerequisite_development_route_ghost_closure_git_blob_oid = ""
        physical_acceptance_authority = $false
        release_authority = $false
    }
    Write-TestJson -Path $authorityPath -Value $authority
    $null = Invoke-TestGit -Root $testRepo -Arguments @("add", "--", $authorityRelative)
    $null = Invoke-TestGit -Root $testRepo -Arguments @("commit", "-m", "authorize exactly once")
    $authorizationHead = Invoke-TestGit -Root $testRepo -Arguments @("rev-parse", "HEAD")

    $positive = Assert-SporeSporeR05EExecutionAuthority `
        -RepoRoot $testRepo `
        -Head $authorizationHead `
        -AuthorityPath $authorityPath `
        -QualificationClosurePath $qualificationPath `
        -EvidenceRoot $evidenceRoot `
        -QualifiedSourcePaths $sourcePaths `
        -Expected $expected
    if (
        -not [bool]$positive.physical_execution_authorized -or
        -not [bool]$positive.authorization_only_commit -or
        [string]$positive.authorization_commit -cne $authorizationHead -or
        [string]$positive.authorization_parent_commit -cne $authorizationParent -or
        [string]$positive.source_freeze_commit -cne $sourceFreeze -or
        [int]$positive.qualified_source_file_count -ne 2
    ) {
        throw "R05E_AUTHORITY_POSITIVE_PROJECTION_INVALID"
    }

    $contentExpected = Copy-TestJsonValue $expected
    $contentExpected["authorization_parent_commit"] = $authorizationParent
    $contentExpected["source_freeze_commit"] = $sourceFreeze
    $contentExpected["implementation_audit_sha256"] = $implementationSha
    $mutations = @(
        @{ id = "authority_extra_key"; target = "authority"; apply = { param($v) $v["extra"] = 1 } },
        @{ id = "authority_integer_string"; target = "authority"; apply = { param($v) $v.expected_world_count = "1" } },
        @{ id = "authority_boolean_integer"; target = "authority"; apply = { param($v) $v.physical_execution_authorized = 1 } },
        @{ id = "authority_parent"; target = "authority"; apply = { param($v) $v.authorization_parent_commit = "0" * 40 } },
        @{ id = "authority_freeze"; target = "authority"; apply = { param($v) $v.source_freeze_commit = "0" * 40 } },
        @{ id = "authority_qualification_sha"; target = "authority"; apply = { param($v) $v.qualification_closure_sha256 = "sha256:" + ("0" * 64) } },
        @{ id = "authority_design"; target = "authority"; apply = { param($v) $v.r05d_design_sha256 = "sha256:" + ("0" * 64) } },
        @{ id = "authority_world_budget"; target = "authority"; apply = { param($v) $v.maximum_world_build_count = 2 } },
        @{ id = "authority_consumed"; target = "authority"; apply = { param($v) $v.physical_identity_consumed = $true } },
        @{ id = "authority_release"; target = "authority"; apply = { param($v) $v.release_authority = $true } },
        @{ id = "qualification_extra_key"; target = "qualification"; apply = { param($v) $v["extra"] = 1 } },
        @{ id = "qualification_schema"; target = "qualification"; apply = { param($v) $v.schema_version = "wrong" } },
        @{ id = "qualification_source_count"; target = "qualification"; apply = { param($v) $v.source.qualified_source_file_count = 3 } },
        @{ id = "qualification_source_blob"; target = "qualification"; apply = { param($v) $v.source.source_bindings[0].git_blob_oid = "0" * 40 } },
        @{ id = "qualification_dependency_count"; target = "qualification"; apply = { param($v) $v.qualification.qualified_source_path_count = 3 } },
        @{ id = "qualification_dependency_eol_policy"; target = "qualification"; apply = { param($v) $v.qualification.dependency_all_qualified_paths_lf_checkout_policy = $false } },
        @{ id = "qualification_dependency_tracking"; target = "qualification"; apply = { param($v) $v.qualification.dependency_all_qualified_paths_tracked = $false } },
        @{ id = "qualification_runtime_sha"; target = "qualification"; apply = { param($v) $v.runtime.identity_sha256 = "sha256:" + ("0" * 64) } },
        @{ id = "qualification_runtime_identity"; target = "qualification"; apply = { param($v) $v.runtime.identity.immutable_token = "mutated" } },
        @{ id = "qualification_receipt_sha_type"; target = "qualification"; apply = { param($v) $v.qualification.qualification_receipt_sha256 = 3 } },
        @{ id = "qualification_physics"; target = "qualification"; apply = { param($v) $v.qualification.physics_state_modified = $true } },
        @{ id = "qualification_world"; target = "qualification"; apply = { param($v) $v.qualification.world_build_count = 1 } },
        @{ id = "qualification_execution"; target = "qualification"; apply = { param($v) $v.decision.physical_execution_authorized = $true } },
        @{ id = "qualification_claim"; target = "qualification"; apply = { param($v) $v.claim_boundary.locomotion_outcome_exposed = $true } },
        @{ id = "qualification_prerequisite"; target = "qualification"; apply = { param($v) $v.prerequisite.development_route_ghost_complete = $true } }
    )
    foreach ($mutation in $mutations) {
        $authorityFixture = Copy-TestJsonValue $authority
        $qualificationFixture = Copy-TestJsonValue $qualification
        $target = if ([string]$mutation.target -ceq "authority") {
            $authorityFixture
        } else {
            $qualificationFixture
        }
        & $mutation.apply $target
        Assert-TestRejected -Label ([string]$mutation.id) -Action {
            $null = Assert-SporeSporeR05EAuthorityContent `
                -Authority $authorityFixture `
                -Qualification $qualificationFixture `
                -Expected $contentExpected `
                -ExpectedSourceBindings $sourceBindings `
                -QualificationRawSha256 $qualificationSha `
                -QualificationGitBlobOid $qualificationBlob
        }
    }

    Write-TestUtf8 -Path (Join-Path $testRepo $workerRelative) -Text "extends Node`n"
    Assert-TestRejected -Label "working_source_drift" -Action {
        $null = Assert-SporeSporeR05EExecutionAuthority `
            -RepoRoot $testRepo -Head $authorizationHead `
            -AuthorityPath $authorityPath `
            -QualificationClosurePath $qualificationPath `
            -EvidenceRoot $evidenceRoot `
            -QualifiedSourcePaths $sourcePaths `
            -Expected $expected
    }
    $null = Invoke-TestGit -Root $testRepo -Arguments @("checkout", "--", $workerRelative)

    $qualificationReceiptOriginal = Get-Content -Raw -LiteralPath $qualificationReceiptPath
    Write-TestUtf8 -Path $qualificationReceiptPath -Text "mutated`n"
    Assert-TestRejected -Label "qualification_receipt_drift" -Action {
        $null = Assert-SporeSporeR05EExecutionAuthority `
            -RepoRoot $testRepo -Head $authorizationHead `
            -AuthorityPath $authorityPath `
            -QualificationClosurePath $qualificationPath `
            -EvidenceRoot $evidenceRoot `
            -QualifiedSourcePaths $sourcePaths `
            -Expected $expected
    }
    Write-TestUtf8 -Path $qualificationReceiptPath -Text $qualificationReceiptOriginal

    $authorityOriginal = Get-Content -Raw -LiteralPath $authorityPath
    Write-TestUtf8 -Path $authorityPath -Text ($authorityOriginal + " ")
    Assert-TestRejected -Label "working_authority_drift" -Action {
        $null = Assert-SporeSporeR05EExecutionAuthority `
            -RepoRoot $testRepo -Head $authorizationHead `
            -AuthorityPath $authorityPath `
            -QualificationClosurePath $qualificationPath `
            -EvidenceRoot $evidenceRoot `
            -QualifiedSourcePaths $sourcePaths `
            -Expected $expected
    }
    Write-TestUtf8 -Path $authorityPath -Text $authorityOriginal

    Write-TestUtf8 -Path (Join-Path $testRepo "docs/extra.txt") -Text "extra`n"
    $null = Invoke-TestGit -Root $testRepo -Arguments @("add", "--", "docs/extra.txt")
    $null = Invoke-TestGit -Root $testRepo -Arguments @("commit", "-m", "forbidden extra commit")
    $extraHead = Invoke-TestGit -Root $testRepo -Arguments @("rev-parse", "HEAD")
    Assert-TestRejected -Label "authorization_not_only_change" -Action {
        $null = Assert-SporeSporeR05EExecutionAuthority `
            -RepoRoot $testRepo -Head $extraHead `
            -AuthorityPath $authorityPath `
            -QualificationClosurePath $qualificationPath `
            -EvidenceRoot $evidenceRoot `
            -QualifiedSourcePaths $sourcePaths `
            -Expected $expected
    }

    $null = Invoke-TestGit -Root $testRepo -Arguments @(
        "checkout", "-b", "qualification-extra", $sourceFreeze
    )
    Write-TestJson -Path $qualificationPath -Value $qualification
    Write-TestUtf8 -Path (Join-Path $testRepo "docs/qualification-extra.txt") `
        -Text "forbidden qualification companion`n"
    $null = Invoke-TestGit -Root $testRepo -Arguments @(
        "add", "--", $qualificationRelative, "docs/qualification-extra.txt"
    )
    $null = Invoke-TestGit -Root $testRepo -Arguments @(
        "commit", "-m", "forbidden qualification companion"
    )
    $badQualificationParent = Invoke-TestGit `
        -Root $testRepo `
        -Arguments @("rev-parse", "HEAD")
    $badQualificationBlob = Invoke-TestGit `
        -Root $testRepo `
        -Arguments @("rev-parse", "$badQualificationParent`:$qualificationRelative")
    $badAuthority = Copy-TestJsonValue $authority
    $badAuthority.authorization_parent_commit = $badQualificationParent
    $badAuthority.qualification_closure_git_blob_oid = $badQualificationBlob
    Write-TestJson -Path $authorityPath -Value $badAuthority
    $null = Invoke-TestGit -Root $testRepo -Arguments @("add", "--", $authorityRelative)
    $null = Invoke-TestGit -Root $testRepo -Arguments @(
        "commit", "-m", "authorize forbidden qualification companion"
    )
    $badQualificationHead = Invoke-TestGit `
        -Root $testRepo `
        -Arguments @("rev-parse", "HEAD")
    Assert-TestRejected -Label "qualification_not_closure_only" -Action {
        $null = Assert-SporeSporeR05EExecutionAuthority `
            -RepoRoot $testRepo -Head $badQualificationHead `
            -AuthorityPath $authorityPath `
            -QualificationClosurePath $qualificationPath `
            -EvidenceRoot $evidenceRoot `
            -QualifiedSourcePaths $sourcePaths `
            -Expected $expected
    }

    # The second positive repository graph is the real, immutable R05E ghost
    # closure and its retained evidence population. This is intentionally
    # read-only: the test never writes to either the canonical repository or
    # SporeSpore_Evidence.
    $canonicalHead = Invoke-TestGit -Root $repoRoot -Arguments @("rev-parse", "HEAD")
    $ghostClosurePath = Join-Path $repoRoot (
        "sdk/qsdk_r05e_development_route_ghost_physical_closure_v1.json"
    )
    $durableEvidenceRoot = Join-Path (Split-Path -Parent $repoRoot) "SporeSpore_Evidence"
    $ghostPositive = Assert-SporeSporeR05EDevelopmentGhostClosure `
        -RepoRoot $repoRoot `
        -Head $canonicalHead `
        -ClosurePath $ghostClosurePath `
        -EvidenceRoot $durableEvidenceRoot
    if (
        -not [bool]$ghostPositive.development_route_ghost_complete -or
        -not [bool]$ghostPositive.route_complete -or
        [bool]$ghostPositive.heldout_evidence -or
        [int64]$ghostPositive.physical_world_count -ne 1 -or
        [int64]$ghostPositive.retained_file_count -ne 9 -or
        [int64]$ghostPositive.retained_total_byte_length -ne 437196 -or
        [string]$ghostPositive.closure_commit -cne
            "6ea17c4e949824f4bda0900ed4755e11181aff36"
    ) {
        throw "R05E_DEVELOPMENT_GHOST_POSITIVE_PROJECTION_INVALID"
    }

    $ghostClosure = Get-Content -Raw -LiteralPath $ghostClosurePath |
        ConvertFrom-Json -AsHashtable -Depth 100
    $ghostReportPath = [string]$ghostClosure.physical_attempt.report_path
    $ghostAttemptPath = [string]$ghostClosure.physical_attempt.attempt_path
    $ghostReport = Get-Content -Raw -LiteralPath $ghostReportPath |
        ConvertFrom-Json -AsHashtable -Depth 100
    $ghostAttempt = Get-Content -Raw -LiteralPath $ghostAttemptPath |
        ConvertFrom-Json -AsHashtable -Depth 100
    $ghostArtifacts = @(Get-SporeSporeR05ERetainedFileArtifacts `
        -Root ([string]$ghostClosure.physical_attempt.evidence_root))
    $ghostMutations = @(
        @{ id = "ghost_status"; target = "closure"; apply = {
            param($v) $v.status = "open"
        } },
        @{ id = "ghost_completion"; target = "closure"; apply = {
            param($v) $v.decision.development_route_ghost_complete = $false
        } },
        @{ id = "ghost_report_digest"; target = "closure"; apply = {
            param($v) $v.physical_attempt.report_raw_sha256 = "sha256:" + ("0" * 64)
        } },
        @{ id = "ghost_recorded_artifact"; target = "closure"; apply = {
            param($v) $v.retained_evidence.artifacts[0].raw_sha256 =
                "sha256:" + ("0" * 64)
        } },
        @{ id = "ghost_heldout_claim"; target = "closure"; apply = {
            param($v) $v.claim_boundary.heldout_evidence = $true
        } },
        @{ id = "ghost_report_route"; target = "report"; apply = {
            param($v) $v.route_complete = $false
        } },
        @{ id = "ghost_report_world_count"; target = "report"; apply = {
            param($v) $v.observed_world_count = 2
        } },
        @{ id = "ghost_report_walking_gate"; target = "report"; apply = {
            param($v) $v.results[0].receipt.walking_gate_receipts.zero_torso_contact = $false
        } },
        @{ id = "ghost_attempt_authorization"; target = "attempt"; apply = {
            param($v) $v.supervisor_physical_authorized = $false
        } },
        @{ id = "ghost_current_artifact"; target = "artifacts"; apply = {
            param($v) $v[0].raw_sha256 = "sha256:" + ("0" * 64)
        } }
    )
    foreach ($mutation in $ghostMutations) {
        $ghostFixture = Copy-TestJsonValue $ghostClosure
        $reportFixture = Copy-TestJsonValue $ghostReport
        $attemptFixture = Copy-TestJsonValue $ghostAttempt
        $artifactFixture = @($ghostArtifacts | ForEach-Object {
            Copy-TestJsonValue $_
        })
        $target = switch ([string]$mutation.target) {
            "closure" { $ghostFixture }
            "report" { $reportFixture }
            "attempt" { $attemptFixture }
            "artifacts" { ,$artifactFixture }
            default { throw "R05E_UNKNOWN_GHOST_MUTATION_TARGET" }
        }
        & $mutation.apply $target
        Assert-TestRejected -Label ([string]$mutation.id) -Action {
            $null = Assert-SporeSporeR05EDevelopmentGhostClosureContent `
                -Closure $ghostFixture `
                -Report $reportFixture `
                -Attempt $attemptFixture `
                -CurrentArtifacts $artifactFixture
        }
    }

    $receipt = [ordered]@{
        schema_version = "sporespore_qsdk_r05e_execution_authority_contract_zero_world_v1"
        ok = $true
        positive_repository_graph_count = 2
        content_mutation_rejection_count = $mutations.Count + $ghostMutations.Count
        repository_binding_rejection_count = 5
        authority_commit_self_reference_required = $false
        authorization_parent_binding_required = $true
        authorization_only_commit_required = $true
        qualification_direct_source_child_required = $true
        qualification_only_commit_required = $true
        qualified_source_blob_equality_required = $true
        qualification_receipt_content_address_required = $true
        qualification_receipt_semantics_required = $true
        runtime_identity_binding_required = $true
        model_construction_count = 0
        world_attempt_count = 0
        world_build_count = 0
        native_readback_count = 0
        solver_step_count = 0
        physics_state_modified = $false
        physical_execution_authorized = $false
        physical_acceptance_authority = $false
        release_authority = $false
    }
    Write-Output (
        "QSDK_R05E_EXECUTION_AUTHORITY_CONTRACT_ZERO_WORLD " +
        ($receipt | ConvertTo-Json -Depth 20 -Compress)
    )
} finally {
    $safePrefix = $systemTemp + [IO.Path]::DirectorySeparatorChar
    if (
        (Test-Path -LiteralPath $tempRoot) -and
        $tempRoot.StartsWith($safePrefix, [StringComparison]::OrdinalIgnoreCase) -and
        (Split-Path -Leaf $tempRoot).StartsWith(
            "sporespore-r05e-authority-contract-test-",
            [StringComparison]::Ordinal
        )
    ) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force
    }
}
