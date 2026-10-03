#requires -Version 7.0

<#
QSDK-R10F development supervisor.

Preflight is zero-world and is the default. Physical mode is fail-closed and
single use: it requires an explicit switch, the exact future authority path,
a clean live-main checkout, a two-commit freeze/authority graph, and a new
durable evidence identity. Creating that identity consumes the attempt even
if the worker later returns invalid or incomplete evidence.
#>

[CmdletBinding()]
param(
    [ValidateSet("Preflight", "Physical")][string]$Mode = "Preflight",
    [switch]$RunPhysical,
    [switch]$L15,
    [switch]$DevelopmentLibrary,
    [string]$AuthorizationPath = "",
    [string]$Godot = (
        "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence\" +
        "qsdk-r24d157-godot-jolt-rotation-integration-energy-v6\" +
        "development-cold-build-ed4ec00a\" +
        "godot.windows.editor.dev.x86_64.console.exe"
    ),
    [string]$EvidenceRoot = "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence",
    [ValidateRange(300, 7200)][int]$TimeoutSeconds = 3600
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "qsdk_r10f_l14_runtime_binding.ps1")
. (Join-Path $PSScriptRoot "qsdk_r10f_l15_launch_relationship.ps1")
. (Join-Path $PSScriptRoot "exact_json_transport.ps1")

$script:RepoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$script:ExpectedRoot = [IO.Path]::GetFullPath(
    "C:\Users\Cole\CodeStuff\games\SporeSpore"
)
$script:ExpectedRemote = "https://github.com/Slagathore/sporespore.git"
$script:ExpectedEvidenceRoot = [IO.Path]::GetFullPath(
    "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence"
)
$script:WorkerResource = (
    "res://tests/test_sdk_qsdk_r10f_continuous_passive_recovery_worker.gd"
)
$script:WorkerPath = Join-Path $script:RepoRoot (
    "tests\test_sdk_qsdk_r10f_continuous_passive_recovery_worker.gd"
)
$script:ManifestPath = Join-Path $PSScriptRoot "qsdk_r10f_dependency_manifest_v19.json"
$script:DesignPath = Join-Path $PSScriptRoot (
    "qsdk_r10f_continuous_passive_fall_recovery_successor_design_v1.json"
)
$script:RepairDesignPath = Join-Path $PSScriptRoot (
    "qsdk_r10f_l14_terminal_boundary_successor_design_v1.json"
)
$script:ExpectedRepairDesignBytes = 13371
$script:ExpectedRepairDesignSha256 = (
    "sha256:ef04ca607078dbd67e2944f5970ba100fd8cbf970539fccc4dabdfd5c2d5691f"
)
$script:BranchCompletenessAddendumPath = Join-Path $PSScriptRoot (
    "qsdk_r10f_l14_no_resume_branch_completeness_addendum_v1.json"
)
$script:ExpectedBranchCompletenessAddendumSha256 = (
    "sha256:01f40035e6cbae84621b28bdca1cd8d18a7a15876ceb44adfd668956d6b14f76"
)
$script:AuthorityContractPython = "C:\Program Files\Python311\python.exe"
# Required source-only coverage, not an assertion that qualification ran.
$script:ExpectedL14ComponentReceiptJson = '{"base_design_raw_sha256":"sha256:ef04ca607078dbd67e2944f5970ba100fd8cbf970539fccc4dabdfd5c2d5691f","branch_completeness_addendum_sha256":"sha256:01f40035e6cbae84621b28bdca1cd8d18a7a15876ceb44adfd668956d6b14f76","coverage":{"actual_independent_report_and_v15_closure_builder_consumed":true,"actual_powershell_binding_receipt_corruption_count":48,"actual_powershell_complete_pair_source_consumed":true,"actual_powershell_frozen_binding_corruption_count":83,"actual_powershell_source_binding_positive_count":3,"actual_runtime_guards_before_identity_and_each_child":true,"addendum_design_corruption_count":23,"addendum_design_positive_count":1,"authority_binding_test_count":9,"base_design_corruption_count":18,"base_design_positive_count":1,"complete_proven_no_resume_negative_handoff_count":3,"complete_resumed_route_four_handoffs_preserved":true,"failed_health_or_missing_peer_never_qualifies_a_route":true,"frozen_no_resume_diagnosis_test_count":1,"future_authority_graph_is_in_memory_test_fixture_only":true,"missing_resume_alone_never_qualifies_a_negative":true,"no_resume_test_count":18,"pre_resume_terminal_cause_count":7,"python_test_count":55,"retained_physical_result_reclassified":false,"runtime_binding_test_count":11,"sdk1_m07_satisfied":false,"selected_runtime_image_count":5,"shared_authority_corruption_count":31,"shared_authority_positive_count":4,"terminal_consumer_test_count":10,"walking_v2_control_count":32,"walking_v2_malformed_input_count":20,"walking_v2_retained_segment_count":2,"worker_retention_test_count":6,"worker_source_control_count":14},"gate_id":"QSDK-R10F","ledger_scope":{"authority_mode":"zero_world_production_component_qualification","engine_scope":"godot_jolt","question_class":"development","subsystem":"recovery"},"model_construction_count":0,"native_readback_count":0,"ok":true,"physical_acceptance_authority":false,"physical_execution_authorized":false,"physics_state_modified":false,"release_authority":false,"repair_id":"QSDK-R10F-L14","scene_tree_insertion_count":0,"schema_version":"sporespore_qsdk_r10f_l14_complete_component_qualification_v1","solver_step_count":0,"test_suites":[{"passed":true,"path":"tests/test_qsdk_r10f_l14_terminal_consumers.py","test_count":10},{"passed":true,"path":"tests/test_qsdk_r10f_l14_production_terminal_paths.py","test_count":6},{"passed":true,"path":"tests/test_qsdk_r10f_l14_no_resume_terminal.py","test_count":18},{"passed":true,"path":"tests/test_qsdk_r10f_l14_authority_contract.py","test_count":9},{"passed":true,"path":"tests/test_qsdk_r10f_l14_no_resume_diagnosis.py","test_count":1},{"passed":true,"path":"tests/test_qsdk_r10f_l14_runtime_binding.py","test_count":11}],"world_attempt_count":0,"world_build_count":0}'
$script:L12RepairDesignPath = Join-Path $PSScriptRoot (
    "qsdk_r10f_l12_walking_actuation_handoff_successor_design_v1.json"
)
$script:ExpectedL12RepairDesignBytes = 26010
$script:ExpectedL12RepairDesignSha256 = (
    "sha256:d10684da1566d9a0e4684ff1b13c3ddbc583d44b23088fc2485731c89a0a6de8"
)
$script:L11RepairDesignPath = Join-Path $PSScriptRoot (
    "qsdk_r10f_l11_precondition_release_owner_source_successor_design_v1.json"
)
$script:ExpectedL11RepairDesignBytes = 17978
$script:ExpectedL11RepairDesignSha256 = (
    "sha256:31027c3ea6fed3085a8486bd3d5e4cab318cd23cdc939d49375c81f8b78fa812"
)
$script:ExpectedAuthorityRelativePath = (
    "sdk/qsdk_r10f_development_route_ghost_execution_authority_v15.json"
)
$script:ExpectedFreezeRelativePath = (
    "sdk/qsdk_r10f_development_route_ghost_zero_world_qualification_closure_v15.json"
)
$script:AuthoritySchema = (
    "sporespore_qsdk_r10f_development_route_ghost_execution_authority_v15"
)
$script:FreezeSchema = (
    "sporespore_qsdk_r10f_development_route_ghost_zero_world_qualification_closure_v15"
)
$script:RepairId = "QSDK-R10F-L14"
$script:SupervisorRefusalPath = Join-Path $PSScriptRoot (
    "qsdk_r10f_development_route_ghost_physical_supervisor_refusal_v2.json"
)
$script:ExpectedSupervisorRefusalBytes = 6486
$script:ExpectedSupervisorRefusalSha256 = (
    "sha256:93e60e8fe747a8ba7a5b6a1621175ce4bf877f537a2a5d03d01ff9e186e1140f"
)
$script:PredecessorPhysicalClosurePath = Join-Path $PSScriptRoot (
    "qsdk_r10f_development_route_ghost_physical_closure_v14.json"
)
$script:ExpectedPredecessorPhysicalClosureBytes = 9998
$script:ExpectedPredecessorPhysicalClosureSha256 = (
    "sha256:1df9bd1896deb23989d6a3c080948a21805a1465b2682748d7e31c7fa1bdd4cb"
)
$script:L12PredecessorPhysicalClosurePath = Join-Path $PSScriptRoot (
    "qsdk_r10f_development_route_ghost_physical_closure_v12.json"
)
$script:RawSchema = "sporespore_qsdk_r10f_process_isolated_child_raw_v1"
$script:RawMarker = "QSDK_R10F_CONTINUOUS_PASSIVE_RECOVERY_RAW "
$script:ReadyMarker = "QSDK_R10F_CONTINUOUS_PASSIVE_RECOVERY_READY "
$script:PreflightMarker = "QSDK_R10F_SUPERVISOR_ZERO_WORLD_PASS "
$script:PhysicalMarker = "QSDK_R10F_SUPERVISOR_PHYSICAL_COMPLETE "
$script:RefusalMarker = "QSDK_R10F_SUPERVISOR_REFUSAL "
$script:GateId = "QSDK-R10F"
$script:GateToken = "R10F"
$script:CampaignId = "QSDK-R10F-CONTINUOUS-S169-KICK-PASSIVE-FALL-RECOVERY-RESUME"
$script:WorkId = "QSDK-R10F-L14-GODOT-JOLT-PROCESS-ISOLATED-CHILD-DEVELOPMENT"
$script:DevelopmentSeed = 40200
$script:DevelopmentSeedLabel = (
    "QSDK-R10F/development/godot/event-triggered-passive-recovery-v1"
)
$script:DevelopmentSeedSha256 = (
    "sha256:efa3c38b428cc5f2daa6b156a8e3e35769623c7c23af6f9079b1d27c66e190fa"
)
$script:ActuatorMode = "solver_coupled_native_constraint_motor_v1"
$script:ControllerId = "sporespore_exact_s169_prone_to_standing_controller_v6"
$script:EnergyRouteId = (
    "sporespore_qsdk_r24d148_godot_jolt_discrete_staging_" +
    "complete_energy_recovery_observation_v3_route_v1"
)
$script:MaximumWorldCount = 2
$script:MaximumChildWorldCount = 1
$script:MaximumSolverStepCount = 7684
$script:MaximumChildSolverStepCount = 3842
$script:OrderedChildRoles = @(
    "matched_no_kick_continuation",
    "kick_passive_recovery_resume"
)
$script:PhysicalAttemptIdentityConsumed = $false
$script:PhysicalAttemptRoot = ""
$script:PhysicalAttemptId = ""
$script:ObservedChildEnvelopes = [System.Collections.Generic.List[object]]::new()
$script:L15PrimaryReportWriteCompleted = $false
$script:L15PrimaryReportBinding = $null
$script:L15PrimaryMarkerPublished = $false
$script:EnvironmentNames = @(
    "SPORESPORE_GODOT_RECOVERY_AUTHORIZATION_SHA256",
    "SPORESPORE_GODOT_RECOVERY_SOURCE_COMMIT",
    "SPORESPORE_GODOT_RECOVERY_ATTEMPT_ID",
    "SPORESPORE_GODOT_RECOVERY_SUPERVISED_TERMINATION",
    "SPORESPORE_GODOT_RECOVERY_TERMINATION_NONCE",
    "SPORESPORE_GODOT_RECOVERY_GATE_ID",
    "SPORESPORE_GODOT_RECOVERY_GATE_TOKEN",
    "SPORESPORE_GODOT_RECOVERY_RAW_SCHEMA",
    "SPORESPORE_GODOT_RECOVERY_WORK_ID",
    "SPORESPORE_GODOT_RECOVERY_RAW_MARKER",
    "SPORESPORE_GODOT_RECOVERY_READY_MARKER",
    "SPORESPORE_GODOT_RECOVERY_PROGRESS_MARKER",
    "SPORESPORE_GODOT_RECOVERY_PROGRESS_CADENCE_STEPS",
    "SPORESPORE_GODOT_RECOVERY_SEED",
    "SPORESPORE_GODOT_RECOVERY_SEED_LABEL",
    "SPORESPORE_GODOT_RECOVERY_SEED_SHA256",
    "SPORESPORE_GODOT_RECOVERY_ACTUATOR_MODE",
    "SPORESPORE_GODOT_RECOVERY_CONTROLLER_ID",
    "SPORESPORE_GODOT_RECOVERY_ENERGY_ROUTE_ID",
    "SPORESPORE_GODOT_RECOVERY_PARENT_ATTEMPT_ID",
    "SPORESPORE_GODOT_RECOVERY_CHILD_ROLE"
)

. (Join-Path $PSScriptRoot "locomotion_operation_lock.ps1")
. (Join-Path $PSScriptRoot "godot_receipt_terminated_process.ps1")
. (Join-Path $PSScriptRoot "qsdk_r10f_process_isolated_pair_evaluator.ps1")


function Assert-R10f {
    param(
        [Parameter(Mandatory)][bool]$Condition,
        [Parameter(Mandatory)][string]$Code
    )
    if (-not $Condition) { throw $Code }
}


function Get-R10fLedgerScope {
    param([Parameter(Mandatory)][string]$AuthorityMode)
    return [ordered]@{
        subsystem = "recovery"
        engine_scope = "godot_jolt"
        authority_mode = $AuthorityMode
        question_class = "development"
    }
}


function Get-PrefixedSha256 {
    param([Parameter(Mandatory)][string]$Path)
    return "sha256:" + (
        Get-FileHash -LiteralPath $Path -Algorithm SHA256
    ).Hash.ToLowerInvariant()
}


function Read-JsonHashtable {
    param([Parameter(Mandatory)][string]$Path)
    Assert-R10f (Test-Path -LiteralPath $Path -PathType Leaf) "JSON_PATH_MISSING"
    try {
        return Get-Content -Raw -LiteralPath $Path |
            ConvertFrom-Json -AsHashtable -Depth 100
    } catch {
        throw ("JSON_INVALID:" + $_.Exception.Message)
    }
}


function Write-Utf8CreateNew {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][AllowEmptyString()][string]$Text
    )
    $stream = [IO.File]::Open(
        [IO.Path]::GetFullPath($Path),
        [IO.FileMode]::CreateNew,
        [IO.FileAccess]::Write,
        [IO.FileShare]::None
    )
    try {
        $bytes = [Text.UTF8Encoding]::new($false).GetBytes($Text)
        $stream.Write($bytes, 0, $bytes.Length)
        $stream.Flush($true)
    } finally {
        $stream.Dispose()
    }
}


function Write-JsonCreateNew {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][object]$Value
    )
    $json = ConvertTo-SporeSporeExactJson -Value $Value -Depth 100 -Indented
    Write-Utf8CreateNew -Path $Path -Text ($json.Replace("`r`n", "`n") + "`n")
}


function Invoke-GitText {
    param(
        [Parameter(Mandatory)][string[]]$Arguments,
        [Parameter(Mandatory)][string]$Code,
        [switch]$AllowEmpty
    )
    $value = & git -C $script:RepoRoot @Arguments 2>&1
    Assert-R10f ($LASTEXITCODE -eq 0) ("GIT_FAILED:" + $Code)
    $text = ($value -join "`n").Trim()
    Assert-R10f ($AllowEmpty -or $text.Length -gt 0) ("GIT_EMPTY:" + $Code)
    return $text
}


function Get-SingleMarkerJson {
    param(
        [Parameter(Mandatory)][string]$Stdout,
        [Parameter(Mandatory)][string]$Marker
    )
    $lines = @(
        $Stdout -split "`r?`n" |
            Where-Object { $_.StartsWith($Marker, [StringComparison]::Ordinal) }
    )
    Assert-R10f ($lines.Count -eq 1) "RAW_MARKER_COUNT"
    try {
        return $lines[0].Substring($Marker.Length) |
            ConvertFrom-Json -AsHashtable -Depth 100
    } catch {
        throw ("RAW_MARKER_JSON:" + $_.Exception.Message)
    }
}


function Get-OptionalSingleMarkerJson {
    param(
        [Parameter(Mandatory)][string]$Stdout,
        [Parameter(Mandatory)][string]$Marker
    )
    $lines = @(
        $Stdout -split "`r?`n" |
            Where-Object { $_.StartsWith($Marker, [StringComparison]::Ordinal) }
    )
    if ($lines.Count -ne 1) { return $null }
    try {
        return $lines[0].Substring($Marker.Length) |
            ConvertFrom-Json -AsHashtable -Depth 100
    } catch {
        return $null
    }
}


function ConvertFrom-R10fGitPathText {
    param(
        [Parameter(Mandatory)][AllowEmptyString()][string]$Text
    )
    return @(
        $Text -split "`r?`n" |
            Where-Object { $_.Length -gt 0 }
    )
}


function Test-R10fExactOrdinalPathSet {
    param(
        [Parameter(Mandatory)][AllowEmptyCollection()][string[]]$Actual,
        [Parameter(Mandatory)][AllowEmptyCollection()][string[]]$Expected
    )
    if ($Actual.Count -ne $Expected.Count) { return $false }
    [string[]]$actualSorted = @($Actual)
    [string[]]$expectedSorted = @($Expected)
    [Array]::Sort($actualSorted, [StringComparer]::Ordinal)
    [Array]::Sort($expectedSorted, [StringComparer]::Ordinal)
    for ($index = 0; $index -lt $actualSorted.Count; $index++) {
        if (-not [StringComparer]::Ordinal.Equals(
            $actualSorted[$index], $expectedSorted[$index]
        )) {
            return $false
        }
    }
    return $true
}


function Get-SourceBoundary {
    param([switch]$RequireLiveCleanMain)
    $root = Invoke-GitText @("rev-parse", "--show-toplevel") "ROOT"
    $remote = Invoke-GitText @("remote", "get-url", "origin") "REMOTE"
    $head = Invoke-GitText @("rev-parse", "HEAD") "HEAD"
    $origin = Invoke-GitText @("rev-parse", "origin/main") "ORIGIN"
    $branch = Invoke-GitText @("branch", "--show-current") "BRANCH"
    $status = Invoke-GitText @(
        "status", "--porcelain=v1", "--untracked-files=all"
    ) "STATUS" -AllowEmpty
    Assert-R10f (
        [IO.Path]::GetFullPath($root) -ceq $script:ExpectedRoot
    ) "CANONICAL_ROOT"
    Assert-R10f ($remote -ceq $script:ExpectedRemote) "CANONICAL_REMOTE"
    $liveCommit = ""
    if ($RequireLiveCleanMain) {
        $live = Invoke-GitText @("ls-remote", "origin", "refs/heads/main") "LIVE_MAIN"
        $fields = @($live -split "\s+")
        Assert-R10f ($fields.Count -eq 2) "LIVE_MAIN_SHAPE"
        $liveCommit = $fields[0]
        Assert-R10f (
            $branch -ceq "main" -and
            $status.Length -eq 0 -and
            $head -ceq $origin -and
            $head -ceq $liveCommit
        ) "PHYSICAL_REQUIRES_CLEAN_PUSHED_LIVE_MAIN"
    }
    return [ordered]@{
        root = $root
        remote = $remote
        head = $head
        origin_main = $origin
        live_main = $liveCommit
        branch = $branch
        clean = $status.Length -eq 0
    }
}


function Test-ExactInteger {
    param([AllowNull()][object]$Value, [Parameter(Mandatory)][int64]$Expected)
    return (
        ($Value -is [int32] -or $Value -is [int64]) -and
        [int64]$Value -eq $Expected
    )
}


function Get-ConsumedPredecessorPhysicalClosureRetired {
    param([Parameter(Mandatory)][string]$SourceCommit)
    $path = $script:PredecessorPhysicalClosurePath
    $closure = Read-JsonHashtable $path
    $sha = Get-PrefixedSha256 $path
    Assert-R10f (
        [int64](Get-Item -LiteralPath $path).Length -eq
            $script:ExpectedPredecessorPhysicalClosureBytes -and
        $sha -ceq $script:ExpectedPredecessorPhysicalClosureSha256 -and
        [string]$closure.schema_version -ceq
            "sporespore_qsdk_r10f_development_route_ghost_physical_closure_v12" -and
        [string]$closure.status -ceq
            "closed_consumed_invalid_or_incomplete_no_behavioral_conclusion" -and
        [string]$closure.gate_id -ceq $script:GateId -and
        [string]$closure.repair_id -ceq "QSDK-R10F-L11" -and
        [string]$closure.campaign_role -ceq "development_route_ghost" -and
        [string]$closure.classification -ceq
            "invalid_or_incomplete_no_behavioral_conclusion" -and
        [string]$closure.source_commit -ceq
            "02f7b554a29ed80ad55d9d21930f23a267c07273" -and
        [string]$closure.stage_commit -ceq
            "487584fc851bf6825e7c7de919e6c777fa71215b" -and
        [string]$closure.authority_commit -ceq
            "f0fb74e29d1064ade3d817933d7835ca4927998c" -and
        [string]$closure.closure_audit_commit -ceq
            "02f7b554a29ed80ad55d9d21930f23a267c07273" -and
        [string]$closure.authority_sha256 -ceq
            "sha256:857bc22635e7c31795b3fa10466040ac4debcf881ed12b710d8357950c5936ad" -and
        [string]$closure.attempt_id -ceq "977175976c09461c9fac94dd23e6ab21" -and
        [string]$closure.failure_code -ceq
            "QSDK_R10F_L9_PROCESS_POPULATION_VALIDATION_FAILED" -and
        [bool]$closure.physical_identity_consumed -and
        -not [bool]$closure.same_identity_rerun_permitted -and
        -not [bool]$closure.route_execution_valid -and
        -not [bool]$closure.evidence_valid -and
        -not [bool]$closure.measurement_complete -and
        -not [bool]$closure.outcome_complete -and
        -not [bool]$closure.behavior_passed -and
        [string]$closure.scientific_outcome -ceq "none" -and
        (Test-ExactInteger $closure.campaign_attempt_count 1) -and
        (Test-ExactInteger $closure.maximum_campaign_attempt_count 1) -and
        (Test-ExactInteger $closure.observed_child_process_count 1) -and
        (Test-ExactInteger $closure.model_construction_attempt_count 1) -and
        (Test-ExactInteger $closure.model_construction_count 1) -and
        (Test-ExactInteger $closure.world_attempt_count 1) -and
        (Test-ExactInteger $closure.world_build_count 1) -and
        (Test-ExactInteger $closure.solver_step_count 241) -and
        [string]$closure.process_isolation.ordered_declared_child_roles[0] -ceq
            $script:OrderedChildRoles[0] -and
        [string]$closure.process_isolation.ordered_declared_child_roles[1] -ceq
            $script:OrderedChildRoles[1] -and
        (Test-ExactInteger $closure.process_isolation.declared_child_count 2) -and
        (Test-ExactInteger $closure.process_isolation.observed_child_count 1) -and
        -not [bool]$closure.process_isolation.distinct_child_process_ids -and
        $null -eq $closure.process_isolation.child_process_lifetimes_overlap -and
        -not [bool]$closure.process_isolation.child_retry_or_replacement_used -and
        [string]$closure.topology_validation_errors[0] -ceq "declared_child_missing" -and
        [string]$closure.child_validation_errors.matched_no_kick_continuation -ceq
            "L9_matched_no_kick_continuation_REPORT_FIELDS" -and
        $closure.precondition_terminal_dispositions.disposition_by_arm.Count -eq 0 -and
        $closure.precondition_terminal_dispositions.precondition_negative_roles.Count -eq 0 -and
        [bool]$closure.precondition_terminal_dispositions.independent_population_validation_performed -and
        -not [bool]$closure.precondition_terminal_dispositions.summary_boolean_only -and
        -not [bool]$closure.event_triggered_passive_recovery_observed -and
        -not [bool]$closure.continuous_same_body_recovery_resume_observed -and
        -not [bool]$closure.force_aware_recovery -and
        -not [bool]$closure.l9_process_isolated_topology_independently_validated -and
        -not [bool]$closure.sdk1_m07_satisfied -and
        -not [bool]$closure.physical_acceptance_authority -and
        -not [bool]$closure.release_authority -and
        $closure.evidence_bindings -is [System.Collections.IDictionary]
    ) "CONSUMED_PREDECESSOR_PHYSICAL_CLOSURE_INVALID"
    foreach ($key in @(
        "supervisor_result", "attempt_identity",
        "execution_authority", "stage_freeze", "r10f_design",
        "l11_repair_design",
        "superseded_physical_supervisor_refusal",
        "consumed_predecessor_physical_closure"
    )) {
        $declared = $closure.evidence_bindings[$key]
        Assert-R10f (
            $declared -is [System.Collections.IDictionary]
        ) ("PREDECESSOR_PHYSICAL_BINDING_MISSING:" + $key)
        $declaredPath = [string]$declared.path
        $actualPath = if ([IO.Path]::IsPathRooted($declaredPath)) {
            [IO.Path]::GetFullPath($declaredPath)
        } else {
            [IO.Path]::GetFullPath((Join-Path $script:RepoRoot $declaredPath))
        }
        Assert-R10f (
            (Test-Path -LiteralPath $actualPath -PathType Leaf) -and
            [int64]$declared.byte_length -eq
                [int64](Get-Item -LiteralPath $actualPath).Length -and
            [string]$declared.raw_sha256 -ceq (Get-PrefixedSha256 $actualPath)
        ) ("PREDECESSOR_PHYSICAL_BINDING_INVALID:" + $key)
    }
    $childArtifacts = $closure.evidence_bindings.child_process_artifacts
    Assert-R10f (
        $childArtifacts -is [System.Collections.IDictionary] -and
        $childArtifacts.Count -eq 1 -and
        $childArtifacts.Contains("matched_no_kick_continuation")
    ) "PREDECESSOR_CHILD_ARTIFACT_POPULATION_INVALID"
    $baselineArtifacts = $childArtifacts.matched_no_kick_continuation
    foreach ($key in @(
        "child_attempt_identity", "worker_stdout", "worker_stderr",
        "termination_receipt", "engine_health", "child_envelope", "worker_report"
    )) {
        $declared = $baselineArtifacts[$key]
        Assert-R10f (
            $declared -is [System.Collections.IDictionary]
        ) ("PREDECESSOR_CHILD_BINDING_MISSING:" + $key)
        $actualPath = [IO.Path]::GetFullPath([string]$declared.path)
        Assert-R10f (
            (Test-Path -LiteralPath $actualPath -PathType Leaf) -and
            [int64]$declared.byte_length -eq
                [int64](Get-Item -LiteralPath $actualPath).Length -and
            [string]$declared.raw_sha256 -ceq (Get-PrefixedSha256 $actualPath)
        ) ("PREDECESSOR_CHILD_BINDING_INVALID:" + $key)
    }
    $relative = "sdk/qsdk_r10f_development_route_ghost_physical_closure_v12.json"
    $sourceBlob = Invoke-GitText @(
        "rev-parse", ($SourceCommit + ":" + $relative)
    ) "PREDECESSOR_PHYSICAL_SOURCE_BLOB"
    $workingBlob = Invoke-GitText @(
        "hash-object", $path
    ) "PREDECESSOR_PHYSICAL_WORKING_BLOB"
    Assert-R10f (
        $sourceBlob -ceq $workingBlob
    ) "PREDECESSOR_PHYSICAL_SOURCE_BLOB_DRIFT"
    return [ordered]@{
        closure = $closure
        sha256 = $sha
        path = $path
    }
}


function Get-ConsumedPredecessorPhysicalClosure {
    param([Parameter(Mandatory)][string]$SourceCommit)
    $bindings = Get-L14AuthorityBindings -SourceCommit $SourceCommit
    return [ordered]@{
        closure = Read-JsonHashtable $script:PredecessorPhysicalClosurePath
        binding = $bindings.consumed_predecessor_physical_closure
        sha256 = $bindings.consumed_predecessor_physical_closure.raw_sha256
        path = $script:PredecessorPhysicalClosurePath
    }
}


function Get-L10RepairDesignRetired {
    param([Parameter(Mandatory)][string]$SourceCommit)
    $path = $script:RepairDesignPath
    Assert-R10f (
        (Test-Path -LiteralPath $path -PathType Leaf) -and
        [int64](Get-Item -LiteralPath $path).Length -eq
            $script:ExpectedRepairDesignBytes -and
        (Get-PrefixedSha256 $path) -ceq $script:ExpectedRepairDesignSha256
    ) "L10_REPAIR_DESIGN_IDENTITY_INVALID"
    $design = Read-JsonHashtable $path
    $consumedL9 = @(
        $design.bound_authorities | Where-Object {
            [string]$_.role -ceq "consumed_l9_physical_closure"
        }
    )
    $l9Design = @(
        $design.bound_authorities | Where-Object {
            [string]$_.role -ceq "l9_process_isolation_design"
        }
    )
    Assert-R10f (
        [string]$design.schema_version -ceq
            "sporespore_qsdk_r10f_l10_nullable_terminal_failure_code_successor_design_v1" -and
        [string]$design.status -ceq
            "prospective_zero_world_successor_design_complete_implementation_authorized_physics_blocked" -and
        [string]$design.gate_id -ceq $script:GateId -and
        [string]$design.repair_id -ceq $script:RepairId -and
        [string]$design.parent_repair_id -ceq "QSDK-R10F-L9" -and
        [string]$design.design_id -ceq
            "QSDK-R10F-L10-NULLABLE-TERMINAL-FAILURE-CODE-PROJECTION" -and
        [string]$design.controlled_change.change_class -ceq
            "terminal_receipt_consumer_representation_only" -and
        [string]$design.controlled_change.mechanism -ceq
            "nullable_terminal_failure_code_projection_v1" -and
        [string]$design.controlled_change.source_field -ceq
            "recovery_memory.terminal_failure_code" -and
        [string]$design.controlled_change.source_domain[0] -ceq "null" -and
        [string]$design.controlled_change.source_domain[1] -ceq "nonempty String" -and
        [bool]$design.controlled_change.nested_recovery_memory_retained_without_mutation -and
        [bool]$design.controlled_change.source_nullness_independently_revalidated -and
        -not [bool]$design.controlled_change.generic_string_conversion_permitted -and
        -not [bool]$design.controlled_change.receipt_key_set_changed -and
        -not [bool]$design.controlled_change.receipt_schema_version_changed -and
        -not [bool]$design.controlled_change.canonical_digest_policy_changed -and
        -not [bool]$design.controlled_change.process_isolation_changed -and
        -not [bool]$design.controlled_change.child_order_changed -and
        -not [bool]$design.controlled_change.threshold_changed -and
        -not [bool]$design.controlled_change.controller_changed -and
        -not [bool]$design.controlled_change.selected_policy_changed -and
        -not [bool]$design.controlled_change.physical_schedule_changed -and
        -not [bool]$design.controlled_change.solver_budget_changed -and
        -not [bool]$design.controlled_change.behavior_evaluator_terms_changed -and
        -not [bool]$design.controlled_change.outcome_derived_correction -and
        [bool]$design.frozen_behavioral_terms.one_world_per_child_process -and
        [bool]$design.frozen_behavioral_terms.one_arm_per_child_process -and
        -not [bool]$design.frozen_behavioral_terms.child_processes_overlap_in_wall_clock_time -and
        (Test-ExactInteger $design.prospective_development_population.maximum_child_process_count 2) -and
        (Test-ExactInteger $design.prospective_development_population.maximum_world_attempt_count_per_child 1) -and
        (Test-ExactInteger $design.prospective_development_population.maximum_world_build_count_per_child 1) -and
        (Test-ExactInteger $design.prospective_development_population.maximum_total_world_attempt_count 2) -and
        (Test-ExactInteger $design.prospective_development_population.maximum_total_world_build_count 2) -and
        (Test-ExactInteger $design.prospective_development_population.maximum_solver_step_count_per_child 3842) -and
        (Test-ExactInteger $design.prospective_development_population.maximum_total_solver_step_count 7684) -and
        [bool]$design.prospective_development_population.both_child_reports_required_for_any_pair_outcome -and
        [bool]$design.prospective_development_population.any_invalid_or_incomplete_child_forces_no_behavioral_conclusion -and
        $design.required_positive_zero_world_controls.Count -eq 7 -and
        $design.required_negative_zero_world_controls.Count -eq 17 -and
        $consumedL9.Count -eq 1 -and
        [string]$consumedL9[0].path -ceq
            "sdk/qsdk_r10f_development_route_ghost_physical_closure_v10.json" -and
        (Test-ExactInteger $consumedL9[0].byte_length 8646) -and
        [string]$consumedL9[0].raw_sha256 -ceq
            $script:ExpectedPredecessorPhysicalClosureSha256 -and
        $l9Design.Count -eq 1 -and
        [string]$l9Design[0].path -ceq
            "sdk/qsdk_r10f_l9_process_isolated_matched_arm_successor_design_v1.json" -and
        (Test-ExactInteger $l9Design[0].byte_length 19530) -and
        [string]$l9Design[0].raw_sha256 -ceq
            "sha256:0fc68c2f895afa52a3835d55c0508bc5490b1af98c5da3761eb774aed702f41e" -and
        [string]$design.retained_l9_result.attempt_id -ceq
            "3207ba0528264944b01aefd0640fd616" -and
        (Test-ExactInteger $design.retained_l9_result.world_attempt_count 1) -and
        (Test-ExactInteger $design.retained_l9_result.world_build_count 1) -and
        (Test-ExactInteger $design.retained_l9_result.solver_step_count 240) -and
        -not [bool]$design.retained_l9_result.route_execution_valid -and
        -not [bool]$design.retained_l9_result.same_identity_rerun_permitted -and
        [bool]$design.claim_boundary.zero_world_implementation_authorized -and
        -not [bool]$design.claim_boundary.physical_execution_authorized -and
        -not [bool]$design.claim_boundary.event_triggered_passive_recovery_observed -and
        -not [bool]$design.claim_boundary.force_aware_recovery -and
        -not [bool]$design.claim_boundary.sdk1_m07_satisfied -and
        -not [bool]$design.claim_boundary.physical_acceptance_authority -and
        -not [bool]$design.claim_boundary.release_authority -and
        [string]$design.decision.selected_repair_id -ceq $script:RepairId -and
        [string]$design.decision.selected_successor_kind -ceq
            "nullable_terminal_failure_code_consumer_repair"
    ) "L10_REPAIR_DESIGN_FIELDS_INVALID"
    $relative = "sdk/qsdk_r10f_l10_nullable_terminal_failure_code_successor_design_v1.json"
    $sourceBlob = Invoke-GitText @(
        "rev-parse", ($SourceCommit + ":" + $relative)
    ) "L10_REPAIR_DESIGN_SOURCE_BLOB"
    $workingBlob = Invoke-GitText @("hash-object", $path) "L10_REPAIR_DESIGN_WORKING_BLOB"
    Assert-R10f ($sourceBlob -ceq $workingBlob) "L10_REPAIR_DESIGN_SOURCE_BLOB_DRIFT"
    return [ordered]@{
        design = $design
        sha256 = $script:ExpectedRepairDesignSha256
        path = $path
    }
}


function Get-L11RepairDesign {
    param([Parameter(Mandatory)][string]$SourceCommit)
    $path = $script:L11RepairDesignPath
    Assert-R10f (
        (Test-Path -LiteralPath $path -PathType Leaf) -and
        [int64](Get-Item -LiteralPath $path).Length -eq
            $script:ExpectedL11RepairDesignBytes -and
        (Get-PrefixedSha256 $path) -ceq $script:ExpectedL11RepairDesignSha256
    ) "L11_REPAIR_DESIGN_IDENTITY_INVALID"
    $design = Read-JsonHashtable $path
    $consumedL10 = @(
        $design.bound_authorities | Where-Object {
            [string]$_.role -ceq "consumed_l10_physical_closure"
        }
    )
    $l10Design = @(
        $design.bound_authorities | Where-Object {
            [string]$_.role -ceq "l10_nullable_terminal_failure_design"
        }
    )
    $observedRoles = [ordered]@{
        observed_l10_worker_source = [ordered]@{
            path = "tests/test_sdk_qsdk_r10f_continuous_passive_recovery_worker.gd"
            blob = "ea48b5cf80caf5d1c3cca8b161f19a64641732ca"
        }
        observed_l10_child_contract_source = [ordered]@{
            path = (
                "sdk/adapters/godot/gdscript/" +
                "qsdk_r10f_process_isolated_child_contract_v1.gd"
            )
            blob = "9638c5739980860789dadc27f370649d87013c44"
        }
        observed_l10_no_actuation_ledger_source = [ordered]@{
            path = (
                "sdk/adapters/godot/gdscript/" +
                "qsdk_r10f_recovery_native_locomotion_facade_v1.gd"
            )
            blob = "2615ba0921675fecaeff0f9d59c7cf392a8b3e13"
        }
    }
    Assert-R10f (
        [string]$design.schema_version -ceq
            "sporespore_qsdk_r10f_l11_precondition_release_owner_source_successor_design_v1" -and
        [string]$design.status -ceq
            "prospective_zero_world_successor_design_complete_implementation_authorized_physics_blocked" -and
        [string]$design.gate_id -ceq $script:GateId -and
        [string]$design.repair_id -ceq "QSDK-R10F-L11" -and
        [string]$design.parent_repair_id -ceq "QSDK-R10F-L10" -and
        [string]$design.design_id -ceq
            "QSDK-R10F-L11-PRECONDITION-RELEASE-OWNER-SOURCE-PROJECTION" -and
        [string]$design.controlled_change.change_class -ceq
            "precondition_release_no_actuation_owner_source_representation_only" -and
        [string]$design.controlled_change.mechanism -ceq
            "precondition_release_owner_source_projection_v1" -and
        [string]$design.controlled_change.source_contract -ceq
            "a fully validated complete precondition terminal receipt" -and
        [bool]$design.controlled_change.full_terminal_receipt_retained_without_mutation -and
        [bool]$design.controlled_change.full_recovery_step_receipt_retained_without_mutation -and
        [bool]$design.controlled_change.terminal_and_step_digests_revalidated -and
        -not [bool]$design.controlled_change.broad_no_actuation_outcome_guard_changed -and
        [bool]$design.controlled_change.release_receipt_schema_advanced_to_l11 -and
        -not [bool]$design.controlled_change.release_receipt_key_set_changed -and
        -not [bool]$design.controlled_change.terminal_receipt_schema_changed -and
        -not [bool]$design.controlled_change.interaction_source_schema_changed -and
        -not [bool]$design.controlled_change.canonical_digest_policy_changed -and
        -not [bool]$design.controlled_change.process_isolation_changed -and
        -not [bool]$design.controlled_change.child_order_changed -and
        -not [bool]$design.controlled_change.threshold_changed -and
        -not [bool]$design.controlled_change.controller_changed -and
        -not [bool]$design.controlled_change.selected_policy_changed -and
        -not [bool]$design.controlled_change.physical_schedule_changed -and
        -not [bool]$design.controlled_change.solver_budget_changed -and
        -not [bool]$design.controlled_change.behavior_evaluator_terms_changed -and
        -not [bool]$design.controlled_change.outcome_derived_correction -and
        [bool]$design.frozen_behavioral_terms.one_world_per_child_process -and
        [bool]$design.frozen_behavioral_terms.one_arm_per_child_process -and
        -not [bool]$design.frozen_behavioral_terms.child_processes_overlap_in_wall_clock_time -and
        (Test-ExactInteger $design.prospective_development_population.maximum_child_process_count 2) -and
        (Test-ExactInteger $design.prospective_development_population.maximum_world_attempt_count_per_child 1) -and
        (Test-ExactInteger $design.prospective_development_population.maximum_world_build_count_per_child 1) -and
        (Test-ExactInteger $design.prospective_development_population.maximum_total_world_attempt_count 2) -and
        (Test-ExactInteger $design.prospective_development_population.maximum_total_world_build_count 2) -and
        (Test-ExactInteger $design.prospective_development_population.maximum_solver_step_count_per_child 3842) -and
        (Test-ExactInteger $design.prospective_development_population.maximum_total_solver_step_count 7684) -and
        [bool]$design.prospective_development_population.both_child_reports_required_for_any_pair_outcome -and
        [bool]$design.prospective_development_population.any_invalid_or_incomplete_child_forces_no_behavioral_conclusion -and
        $design.required_positive_zero_world_controls.Count -eq 7 -and
        $design.required_negative_zero_world_controls.Count -eq 15 -and
        $design.bound_authorities.Count -eq 5 -and
        $consumedL10.Count -eq 1 -and
        [string]$consumedL10[0].path -ceq
            "sdk/qsdk_r10f_development_route_ghost_physical_closure_v11.json" -and
        (Test-ExactInteger $consumedL10[0].byte_length 8651) -and
        [string]$consumedL10[0].raw_sha256 -ceq
            "sha256:56cce9da3c85a8b8187f0e1f9f8986fe004d587db262ef0ec11687ff37c7462e" -and
        $l10Design.Count -eq 1 -and
        [string]$l10Design[0].path -ceq
            "sdk/qsdk_r10f_l10_nullable_terminal_failure_code_successor_design_v1.json" -and
        (Test-ExactInteger $l10Design[0].byte_length 16553) -and
        [string]$l10Design[0].raw_sha256 -ceq
            "sha256:2d186f41fcb73427ef7021a1050e4175791784212bfb9c219d712595370a4817" -and
        [string]$design.retained_l10_result.attempt_id -ceq
            "f141e4523d6b44ee9cb80ec054788780" -and
        (Test-ExactInteger $design.retained_l10_result.world_attempt_count 1) -and
        (Test-ExactInteger $design.retained_l10_result.world_build_count 1) -and
        (Test-ExactInteger $design.retained_l10_result.solver_step_count 240) -and
        -not [bool]$design.retained_l10_result.route_execution_valid -and
        -not [bool]$design.retained_l10_result.same_identity_rerun_permitted -and
        [string]$design.retained_diagnosis.first_child_inner_failure_code -ceq
            "QSDK_R10F_NO_ACTUATION_LEDGER_INPUT_INVALID" -and
        [string]$design.retained_diagnosis.retained_owner_source_has_forbidden_top_level_key -ceq
            "physical_result" -and
        [bool]$design.retained_diagnosis.broad_outcome_guard_correctly_refused_runtime_source -and
        [bool]$design.retained_diagnosis.runtime_source_was_too_broad_for_the_no_actuation_ledger_role -and
        [bool]$design.retained_diagnosis.l10_nullable_terminal_failure_projection_passed_runtime_boundary -and
        -not [bool]$design.retained_diagnosis.precondition_release_receipt_built -and
        -not [bool]$design.retained_diagnosis.behavior_question_reached -and
        [bool]$design.claim_boundary.zero_world_implementation_authorized -and
        -not [bool]$design.claim_boundary.physical_execution_authorized -and
        -not [bool]$design.claim_boundary.event_triggered_passive_recovery_observed -and
        -not [bool]$design.claim_boundary.force_aware_recovery -and
        -not [bool]$design.claim_boundary.sdk1_m07_satisfied -and
        -not [bool]$design.claim_boundary.physical_acceptance_authority -and
        -not [bool]$design.claim_boundary.release_authority -and
        [string]$design.decision.selected_repair_id -ceq "QSDK-R10F-L11" -and
        [string]$design.decision.selected_successor_kind -ceq
            "precondition_release_no_actuation_owner_source_projection"
    ) "L11_REPAIR_DESIGN_FIELDS_INVALID"
    foreach ($entry in $observedRoles.GetEnumerator()) {
        $declared = @(
            $design.bound_authorities | Where-Object {
                [string]$_.role -ceq [string]$entry.Key
            }
        )
        Assert-R10f (
            $declared.Count -eq 1 -and
            [string]$declared[0].path -ceq [string]$entry.Value.path -and
            [string]$declared[0].source_commit -ceq
                "3a3203d2cd1f85d5f401bf12dc094398dbe02354" -and
            [string]$declared[0].git_blob_oid -ceq [string]$entry.Value.blob -and
            (Invoke-GitText @(
                "rev-parse",
                ([string]$declared[0].source_commit + ":" + [string]$entry.Value.path)
            ) ("L11_REPAIR_DESIGN_HISTORICAL_BLOB:" + [string]$entry.Key)) -ceq
                [string]$entry.Value.blob
        ) ("L11_REPAIR_DESIGN_HISTORICAL_IDENTITY:" + [string]$entry.Key)
    }
    $relative = "sdk/qsdk_r10f_l11_precondition_release_owner_source_successor_design_v1.json"
    $sourceBlob = Invoke-GitText @(
        "rev-parse", ($SourceCommit + ":" + $relative)
    ) "L11_REPAIR_DESIGN_SOURCE_BLOB"
    $workingBlob = Invoke-GitText @("hash-object", $path) "L11_REPAIR_DESIGN_WORKING_BLOB"
    Assert-R10f ($sourceBlob -ceq $workingBlob) "L11_REPAIR_DESIGN_SOURCE_BLOB_DRIFT"
    return [ordered]@{
        design = $design
        sha256 = $script:ExpectedL11RepairDesignSha256
        path = $path
    }
}


function Get-L12RepairDesign {
    param([Parameter(Mandatory)][string]$SourceCommit)
    $path = $script:L12RepairDesignPath
    Assert-R10f (
        (Test-Path -LiteralPath $path -PathType Leaf) -and
        [int64](Get-Item -LiteralPath $path).Length -eq
            $script:ExpectedL12RepairDesignBytes -and
        (Get-PrefixedSha256 $path) -ceq $script:ExpectedL12RepairDesignSha256
    ) "L12_REPAIR_DESIGN_IDENTITY_INVALID"
    $design = Read-JsonHashtable $path
    $change = $design.controlled_change
    $frozen = $design.frozen_behavioral_terms
    $population = $design.prospective_development_population
    $positiveControls = @($design.required_positive_zero_world_controls)
    $negativeControls = @($design.required_negative_zero_world_controls)
    Assert-R10f (
        [string]$design.schema_version -ceq
            "sporespore_qsdk_r10f_l12_walking_actuation_handoff_successor_design_v1" -and
        [string]$design.status -ceq
            "prospective_zero_world_successor_design_complete_implementation_authorized_physics_blocked" -and
        [string]$design.gate_id -ceq $script:GateId -and
        [string]$design.repair_id -ceq "QSDK-R10F-L12" -and
        [string]$design.parent_repair_id -ceq "QSDK-R10F-L11" -and
        [string]$design.design_id -ceq
            "QSDK-R10F-L12-WALKING-ACTUATION-OWNERSHIP-HANDOFF" -and
        $design.bound_authorities -is [System.Collections.IList] -and
        $design.bound_authorities.Count -eq 8 -and
        $change -is [System.Collections.IDictionary] -and
        [string]$change.change_class -ceq
            "r10f_walking_actuation_ownership_handoff_and_existing_host_cap_binding_only" -and
        [string]$change.mechanism -ceq "walking_actuation_ownership_handoff_v1" -and
        [string]$change.covered_evaluation_segments[0] -ceq "walking_prefix" -and
        [string]$change.covered_evaluation_segments[1] -ceq "matched_continuation" -and
        [string]$change.covered_evaluation_segments[2] -ceq "walking_resume" -and
        (Test-ExactInteger $change.motor_enable_write_count_per_fresh_session 8) -and
        (Test-ExactInteger $change.zero_target_write_count_per_fresh_session 8) -and
        (Test-ExactInteger $change.handoff_solver_step_count 0) -and
        [bool]$change.existing_complete_override_interface_used -and
        -not [bool]$change.extra_solver_step_inserted -and
        -not [bool]$change.release_step_changed -and
        -not [bool]$change.release_motors_disabled_invariant_changed -and
        -not [bool]$change.shared_adapter_enable_behavior_changed -and
        -not [bool]$change.shared_adapter_cap_resolution_behavior_changed -and
        -not [bool]$change.published_actuator_profile_changed -and
        -not [bool]$change.selected_host_cap_changed_from_r69 -and
        -not [bool]$change.new_tolerance_or_margin_added -and
        -not [bool]$change.raw_measurement_clamped -and
        -not [bool]$change.threshold_changed -and
        -not [bool]$change.controller_changed -and
        -not [bool]$change.selected_policy_changed -and
        -not [bool]$change.outcome_derived_correction -and
        $frozen -is [System.Collections.IDictionary] -and
        [string]$frozen.ordered_child_roles[0] -ceq $script:OrderedChildRoles[0] -and
        [string]$frozen.ordered_child_roles[1] -ceq $script:OrderedChildRoles[1] -and
        [bool]$frozen.one_arm_per_child_process -and
        [bool]$frozen.one_world_per_child_process -and
        (Test-ExactInteger $frozen.maximum_child_process_count 2) -and
        (Test-ExactInteger $frozen.maximum_world_count_per_child 1) -and
        (Test-ExactInteger $frozen.maximum_total_world_count 2) -and
        (Test-ExactInteger $frozen.maximum_solver_steps_per_child 3842) -and
        (Test-ExactInteger $frozen.maximum_total_solver_steps 7684) -and
        -not [bool]$frozen.force_aware_recovery -and
        $population -is [System.Collections.IDictionary] -and
        (Test-ExactInteger $population.maximum_campaign_attempt_count 1) -and
        (Test-ExactInteger $population.maximum_child_process_count 2) -and
        (Test-ExactInteger $population.maximum_total_world_build_count 2) -and
        (Test-ExactInteger $population.maximum_solver_step_count_per_child 3842) -and
        (Test-ExactInteger $population.maximum_total_solver_step_count 7684) -and
        [bool]$population.both_child_reports_required_for_any_pair_outcome -and
        [bool]$population.any_invalid_or_incomplete_child_forces_no_behavioral_conclusion -and
        $positiveControls.Count -eq 13 -and
        @($positiveControls | Sort-Object -Unique).Count -eq 13 -and
        $negativeControls.Count -eq 19 -and
        @($negativeControls | Sort-Object -Unique).Count -eq 19 -and
        [bool]$design.claim_boundary.zero_world_implementation_authorized -and
        -not [bool]$design.claim_boundary.physical_execution_authorized -and
        -not [bool]$design.claim_boundary.sdk1_m07_satisfied -and
        -not [bool]$design.claim_boundary.physical_acceptance_authority -and
        -not [bool]$design.claim_boundary.release_authority -and
        [string]$design.decision.selected_repair_id -ceq "QSDK-R10F-L12" -and
        [string]$design.decision.selected_successor_kind -ceq
            "r10f_walking_actuation_ownership_handoff_with_qualified_host_cap_binding"
    ) "L12_REPAIR_DESIGN_FIELDS_INVALID"

    $boundByRole = [ordered]@{}
    foreach ($declared in $design.bound_authorities) {
        Assert-R10f (
            $declared -is [System.Collections.IDictionary] -and
            $declared.role -is [string] -and
            -not $boundByRole.Contains([string]$declared.role)
        ) "L12_REPAIR_DESIGN_BOUND_AUTHORITY_SHAPE"
        $boundByRole[[string]$declared.role] = $declared
    }
    [string[]]$expectedRoles = @(
        "consumed_l11_physical_closure",
        "l11_release_owner_projection_design",
        "qualified_r69_host_cap_projection_contract",
        "qualified_r69_zero_world_projection_population",
        "observed_l11_worker_source",
        "observed_l11_locomotion_facade_source",
        "observed_l11_shared_walking_adapter_source",
        "observed_l11_recovery_world_host_cap_source"
    )
    Assert-R10f (
        Test-R10fExactOrdinalPathSet -Actual @($boundByRole.Keys) -Expected $expectedRoles
    ) "L12_REPAIR_DESIGN_BOUND_AUTHORITY_SET"

    $currentAuthorities = [ordered]@{
        consumed_l11_physical_closure = $script:L12PredecessorPhysicalClosurePath
        l11_release_owner_projection_design = $script:L11RepairDesignPath
        qualified_r69_host_cap_projection_contract = Join-Path $script:RepoRoot (
            "sdk/recovery/r24d69_godot_native_effective_impulse_limit_contract_v1.json"
        )
        qualified_r69_zero_world_projection_population = Join-Path $script:RepoRoot (
            "sdk/recovery/r24d69_godot_native_effective_impulse_limit_zero_world_qualification_closure_v1.json"
        )
    }
    foreach ($entry in $currentAuthorities.GetEnumerator()) {
        $declared = $boundByRole[[string]$entry.Key]
        $authorityPath = [IO.Path]::GetFullPath([string]$entry.Value)
        $relativePath = [IO.Path]::GetRelativePath(
            $script:RepoRoot, $authorityPath
        ).Replace("\", "/")
        Assert-R10f (
            [string]$declared.path -ceq $relativePath -and
            (Test-ExactInteger $declared.byte_length `
                ([int64](Get-Item -LiteralPath $authorityPath).Length)) -and
            [string]$declared.raw_sha256 -ceq (Get-PrefixedSha256 $authorityPath) -and
            [string]$declared.git_blob_oid -ceq (
                Invoke-GitText @("hash-object", $authorityPath) (
                    "L12_REPAIR_DESIGN_CURRENT_BLOB:" + [string]$entry.Key
                )
            )
        ) ("L12_REPAIR_DESIGN_CURRENT_IDENTITY:" + [string]$entry.Key)
    }

    $historicalCommit = "02f7b554a29ed80ad55d9d21930f23a267c07273"
    $historicalAuthorities = [ordered]@{
        observed_l11_worker_source = [ordered]@{
            path = "tests/test_sdk_qsdk_r10f_continuous_passive_recovery_worker.gd"
            blob = "5c13fb1c50b1aa24d0e63456c6dd6bdacce86015"
        }
        observed_l11_locomotion_facade_source = [ordered]@{
            path = (
                "sdk/adapters/godot/gdscript/" +
                "qsdk_r10f_recovery_native_locomotion_facade_v1.gd"
            )
            blob = "2615ba0921675fecaeff0f9d59c7cf392a8b3e13"
        }
        observed_l11_shared_walking_adapter_source = [ordered]@{
            path = "scripts/lab/gait/sdk_godot_jolt_adapter.gd"
            blob = "ef793ede82d63ee266ee815f2b0dd19866ef9596"
        }
        observed_l11_recovery_world_host_cap_source = [ordered]@{
            path = "sdk/adapters/godot/gdscript/recovery_native_world_v1.gd"
            blob = "c418010d7dd22baf00af8ad6f4cd9f0b870957f0"
        }
    }
    foreach ($entry in $historicalAuthorities.GetEnumerator()) {
        $declared = $boundByRole[[string]$entry.Key]
        Assert-R10f (
            [string]$declared.path -ceq [string]$entry.Value.path -and
            [string]$declared.source_commit -ceq $historicalCommit -and
            [string]$declared.git_blob_oid -ceq [string]$entry.Value.blob -and
            (Invoke-GitText @(
                "rev-parse", ($historicalCommit + ":" + [string]$entry.Value.path)
            ) ("L12_REPAIR_DESIGN_HISTORICAL_BLOB:" + [string]$entry.Key)) -ceq
                [string]$entry.Value.blob
        ) ("L12_REPAIR_DESIGN_HISTORICAL_IDENTITY:" + [string]$entry.Key)
    }

    $relative = "sdk/qsdk_r10f_l12_walking_actuation_handoff_successor_design_v1.json"
    $sourceBlob = Invoke-GitText @(
        "rev-parse", ($SourceCommit + ":" + $relative)
    ) "L12_REPAIR_DESIGN_SOURCE_BLOB"
    $workingBlob = Invoke-GitText @("hash-object", $path) "L12_REPAIR_DESIGN_WORKING_BLOB"
    Assert-R10f ($sourceBlob -ceq $workingBlob) "L12_REPAIR_DESIGN_SOURCE_BLOB_DRIFT"
    return [ordered]@{
        design = $design
        sha256 = $script:ExpectedL12RepairDesignSha256
        path = $path
    }
}


function Test-R10fExactSourceValue {
    param([AllowNull()]$Actual, [AllowNull()]$Expected)
    # JSON number kinds stay distinct; a floating count is not an integer count.
    if ($null -eq $Actual -or $null -eq $Expected) {
        return ($null -eq $Actual -and $null -eq $Expected)
    }
    if ($Expected -is [System.Collections.IDictionary]) {
        if ($Actual -isnot [System.Collections.IDictionary]) { return $false }
        if (-not (Test-R10fExactOrdinalPathSet -Actual @($Actual.Keys) -Expected @($Expected.Keys))) {
            return $false
        }
        foreach ($key in $Expected.Keys) {
            if (-not (Test-R10fExactSourceValue -Actual $Actual[$key] -Expected $Expected[$key])) {
                return $false
            }
        }
        return $true
    }
    if ($Expected -is [System.Collections.IList]) {
        if ($Actual -isnot [System.Collections.IList] -or $Actual.Count -ne $Expected.Count) {
            return $false
        }
        for ($index = 0; $index -lt $Expected.Count; $index++) {
            if (-not (Test-R10fExactSourceValue -Actual $Actual[$index] -Expected $Expected[$index])) {
                return $false
            }
        }
        return $true
    }
    if ($Expected -is [int] -or $Expected -is [long]) {
        return (Test-ExactInteger -Value $Actual -Expected $Expected)
    }
    if ($Actual.GetType() -ne $Expected.GetType()) { return $false }
    if ($Expected -is [string]) {
        return [StringComparer]::Ordinal.Equals($Actual, $Expected)
    }
    return ($Actual -ceq $Expected)
}


function Assert-R10fL14ContractReceipt {
    param(
        [Parameter(Mandatory)][System.Collections.IDictionary]$Receipt,
        [Parameter(Mandatory)][string]$SourceCommit
    )
    Assert-R10f (
        $Receipt.schema_version -ceq "sporespore_qsdk_r10f_l14_authority_contract_receipt_v1" -and
        $Receipt.gate_id -ceq "QSDK-R10F" -and
        $Receipt.repair_id -ceq $script:RepairId -and
        $Receipt.command -ceq "authority-bindings" -and
        $Receipt.source_commit -ceq $SourceCommit -and
        ($Receipt.ok -is [bool]) -and $Receipt.ok -and
        $Receipt.binding -is [System.Collections.IDictionary] -and
        (Test-R10fExactOrdinalPathSet -Actual @($Receipt.binding.Keys) -Expected @(
            "repair_design", "branch_completeness_addendum", "consumed_predecessor_physical_closure"
        )) -and
        $Receipt.binding.repair_design.raw_sha256 -ceq $script:ExpectedRepairDesignSha256 -and
        $Receipt.binding.branch_completeness_addendum.raw_sha256 -ceq
            $script:ExpectedBranchCompletenessAddendumSha256 -and
        $Receipt.binding.consumed_predecessor_physical_closure.raw_sha256 -ceq
            $script:ExpectedPredecessorPhysicalClosureSha256
    ) "L14_AUTHORITY_CONTRACT_RECEIPT"
    foreach ($key in @(
        "model_construction_count", "world_attempt_count", "world_build_count",
        "scene_tree_insertion_count", "native_readback_count", "solver_step_count"
    )) {
        Assert-R10f (Test-ExactInteger $Receipt[$key] 0) ("L14_AUTHORITY_CONTRACT_COUNTER:" + $key)
    }
    foreach ($key in @(
        "physics_state_modified", "physical_execution_authorized",
        "physical_acceptance_authority", "release_authority"
    )) {
        Assert-R10f (
            $Receipt[$key] -is [bool] -and $Receipt[$key] -eq $false
        ) ("L14_AUTHORITY_CONTRACT_CLAIM:" + $key)
    }
}


function Get-L14AuthorityBindings {
    param([Parameter(Mandatory)][ValidatePattern('^[0-9a-f]{40}$')][string]$SourceCommit)
    # The same read-only Python contract is used by the materializer and closer.
    $start = [Diagnostics.ProcessStartInfo]::new()
    $start.FileName = $script:AuthorityContractPython
    $start.WorkingDirectory = $script:RepoRoot
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    foreach ($argument in @(
        "-B", (Join-Path $script:RepoRoot "sdk/conformance/qsdk_r10f_l14_authority_contract.py"),
        "authority-bindings", "--source-commit", $SourceCommit
    )) { $start.ArgumentList.Add($argument) }
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $start
    $started = $false
    try {
        $started = $process.Start()
        Assert-R10f $started "L14_AUTHORITY_CONTRACT_START"
        $stdoutTask = $process.StandardOutput.ReadToEndAsync()
        $stderrTask = $process.StandardError.ReadToEndAsync()
        if (-not $process.WaitForExit(60000)) {
            $process.Kill($true)
            $process.WaitForExit()
            throw "L14_AUTHORITY_CONTRACT_TIMEOUT"
        }
        $stdout = $stdoutTask.GetAwaiter().GetResult()
        $stderr = $stderrTask.GetAwaiter().GetResult()
        Assert-R10f (
            $process.ExitCode -eq 0 -and [string]::IsNullOrWhiteSpace($stderr)
        ) "L14_AUTHORITY_CONTRACT_PROCESS_FAILED"
        $receipt = Get-SingleMarkerJson -Stdout $stdout -Marker "QSDK_R10F_L14_AUTHORITY_CONTRACT_PASS "
        Assert-R10fL14ContractReceipt -Receipt $receipt -SourceCommit $SourceCommit
        return $receipt.binding
    } finally {
        if ($started -and -not $process.HasExited) {
            $process.Kill($true)
            $process.WaitForExit()
        }
        $process.Dispose()
    }
}


function Get-L14RepairDesign {
    param([Parameter(Mandatory)][string]$SourceCommit)
    $bindings = Get-L14AuthorityBindings -SourceCommit $SourceCommit
    return [ordered]@{
        design = Read-JsonHashtable $script:RepairDesignPath
        sha256 = $bindings.repair_design.raw_sha256
        path = $script:RepairDesignPath
        authority_bindings = $bindings
    }
}


function Assert-R10fL14FrozenAuthorityBindings {
    param(
        [Parameter(Mandatory)][System.Collections.IDictionary]$Freeze,
        [Parameter(Mandatory)][System.Collections.IDictionary]$Bindings
    )
    $selected = [ordered]@{
        repair_design = $Freeze["repair_design"]
        branch_completeness_addendum = $Freeze["branch_completeness_addendum"]
        consumed_predecessor_physical_closure = $Freeze["consumed_predecessor_physical_closure"]
    }
    Assert-R10f (
        Test-R10fExactSourceValue -Actual $selected -Expected $Bindings
    ) "L14_FROZEN_AUTHORITY_BINDINGS"
}


function Assert-R10fL14FrozenComponentQualification {
    param(
        [Parameter(Mandatory)][System.Collections.IDictionary]$Document,
        [Parameter(Mandatory)][string]$AuthorityName
    )
    $expected = $script:ExpectedL14ComponentReceiptJson | ConvertFrom-Json -AsHashtable -Depth 100
    Assert-R10f (
        $Document.Contains("l14_component_qualification") -and
        (Test-R10fExactSourceValue $Document["l14_component_qualification"] $expected)
    ) ("L14_FROZEN_COMPONENT_QUALIFICATION:" + $AuthorityName)
}


function Select-L15ProductionFamily {
    # Explicit prospective selection; default L14 constants and readers stay intact.
    $selection = @{
        RepairId = 'QSDK-R10F-L15'
        WorkId = 'QSDK-R10F-L15-GODOT-JOLT-PROCESS-ISOLATED-CHILD-DEVELOPMENT'
        ManifestPath = (Join-Path $script:RepoRoot 'sdk/qsdk_r10f_dependency_manifest_v20.json')
        ExpectedAuthorityRelativePath = 'sdk/qsdk_r10f_development_route_ghost_execution_authority_v16.json'
        ExpectedFreezeRelativePath = 'sdk/qsdk_r10f_development_route_ghost_zero_world_qualification_closure_v16.json'
    }
    foreach ($name in $selection.Keys) { Set-Variable -Scope Script -Name $name -Value $selection[$name] }
    Set-Variable -Scope Script -Name QsdkR10fL9RepairId -Value $selection.RepairId
    Set-Variable -Scope Script -Name QsdkR10fL9WorkId -Value $selection.WorkId
}


function Get-L15CommittedGraphBinding {
    # Read the complete qualified graph before allocating either child identity.
    $start = [Diagnostics.ProcessStartInfo]::new()
    $start.FileName = $script:AuthorityContractPython
    $start.WorkingDirectory = $script:RepoRoot
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    $start.StandardOutputEncoding = [Text.UTF8Encoding]::new($false, $true)
    $start.StandardErrorEncoding = [Text.UTF8Encoding]::new($false, $true)
    foreach ($argument in @('-B', (Join-Path $script:RepoRoot 'sdk/conformance/qsdk_r10f_authority_materializer.py'), 'graph-check-l15')) {
        $start.ArgumentList.Add($argument)
    }
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $start
    $started = $false
    try {
        $started = $process.Start()
        Assert-R10f $started 'L15_GRAPH_READER_START'
        $stdoutTask = $process.StandardOutput.ReadToEndAsync()
        $stderrTask = $process.StandardError.ReadToEndAsync()
        Assert-R10f ($process.WaitForExit(120000)) 'L15_GRAPH_READER_TIMEOUT'
        $stdout = $stdoutTask.GetAwaiter().GetResult()
        $stderr = $stderrTask.GetAwaiter().GetResult()
        Assert-R10f ($process.ExitCode -eq 0 -and $stderr.Length -eq 0) ('L15_GRAPH_READER_FAILED:' + $stderr)
        $lines = @($stdout -split "`r?`n" | Where-Object { $_.Length -gt 0 })
        Assert-R10f ($lines.Count -eq 1) 'L15_GRAPH_READER_OUTPUT_COUNT'
        $binding = Get-SingleMarkerJson -Stdout $stdout -Marker 'QSDK_R10F_L15_COMMITTED_GRAPH_BINDING '
        Assert-R10f ($binding -is [System.Collections.IDictionary] -and
            $binding.authority.repair_id -ceq 'QSDK-R10F-L15' -and
            $binding.freeze.repair_id -ceq 'QSDK-R10F-L15' -and
            $binding.Contains('l15_prepared_context_expectation')) 'L15_GRAPH_READER_FAMILY'
        return $binding
    } finally {
        if ($started -and -not $process.HasExited) {
            $process.Kill($true)
            $process.WaitForExit()
        }
        $process.Dispose()
    }
}


function Get-PhysicalAuthority {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][System.Collections.IDictionary]$Boundary
    )
    Assert-R10f ($Path.Length -gt 0) "PHYSICAL_AUTHORIZATION_PATH_REQUIRED"
    $resolved = [IO.Path]::GetFullPath($Path)
    $expected = [IO.Path]::GetFullPath(
        (Join-Path $script:RepoRoot $script:ExpectedAuthorityRelativePath)
    )
    Assert-R10f ($resolved -ceq $expected) "PHYSICAL_AUTHORIZATION_PATH_NOT_EXACT"
    if ($script:RepairId -ceq 'QSDK-R10F-L15') {
        $binding = Get-L15CommittedGraphBinding
        Assert-R10f ([IO.Path]::GetFullPath($binding.authority_path) -ceq $resolved) 'L15_GRAPH_READER_PATH'
        Assert-R10f ((Get-PrefixedSha256 $resolved) -ceq $binding.authority_sha256) 'L15_GRAPH_READER_AUTHORITY_BYTES'
        Assert-R10f ((Invoke-GitText @('rev-parse', 'HEAD') 'L15_GRAPH_HEAD') -ceq $Boundary.head) 'L15_GRAPH_BOUNDARY_DRIFT'
        return $binding
    }
    $authority = Read-JsonHashtable $resolved
    $freezePath = [IO.Path]::GetFullPath(
        (Join-Path $script:RepoRoot $script:ExpectedFreezeRelativePath)
    )
    $freeze = Read-JsonHashtable $freezePath
    $authoritySha = Get-PrefixedSha256 $resolved
    $freezeSha = Get-PrefixedSha256 $freezePath
    $designSha = Get-PrefixedSha256 $script:DesignPath
    $manifestSha = Get-PrefixedSha256 $script:ManifestPath
    $manifest = Read-JsonHashtable $script:ManifestPath
    $policy = $manifest.policy
    $supervisorRefusal = Read-JsonHashtable $script:SupervisorRefusalPath
    $supervisorRefusalSha = Get-PrefixedSha256 $script:SupervisorRefusalPath
    $predecessorPhysical = Get-ConsumedPredecessorPhysicalClosure `
        -SourceCommit ([string]$authority.source_commit)
    $null = Get-L11RepairDesign `
        -SourceCommit ([string]$authority.source_commit)
    $null = Get-L12RepairDesign `
        -SourceCommit ([string]$authority.source_commit)
    $repairDesign = Get-L14RepairDesign `
        -SourceCommit ([string]$authority.source_commit)
    $expectedSourceCount = [int64]$policy.expected_qualified_source_count
    Assert-R10f (
        [string]$manifest.schema_version -ceq
            "sporespore_qsdk_r10f_dependency_manifest_v19" -and
        [string]$manifest.repair_id -ceq $script:RepairId -and
        [string]$manifest.status -ceq
            "prospective_complete_transitive_source_closure_zero_world" -and
        $expectedSourceCount -gt 0 -and
        [string]$policy.expected_qualified_source_path_sha256 -cmatch
            '^sha256:[0-9a-f]{64}$'
    ) "SOURCE_BINDING_NOT_FINALIZED"
    Assert-R10f (
        [int64](Get-Item -LiteralPath $script:SupervisorRefusalPath).Length -eq
            $script:ExpectedSupervisorRefusalBytes -and
        $supervisorRefusalSha -ceq $script:ExpectedSupervisorRefusalSha256 -and
        [string]$supervisorRefusal.schema_version -ceq
            "sporespore_qsdk_r10f_physical_supervisor_refusal_v2" -and
        [string]$supervisorRefusal.status -ceq
            "closed_infrastructure_invalid_pre_physics_output_identity_unconsumed" -and
        [string]$supervisorRefusal.gate_id -ceq $script:GateId -and
        [string]$supervisorRefusal.repair_id -ceq "QSDK-R10F-L2" -and
        -not [bool]$supervisorRefusal.execution_boundary.physical_attempt_identity_consumed -and
        (Test-ExactInteger $supervisorRefusal.execution_boundary.world_attempt_count 0) -and
        (Test-ExactInteger $supervisorRefusal.execution_boundary.world_build_count 0) -and
        (Test-ExactInteger $supervisorRefusal.execution_boundary.solver_step_count 0) -and
        -not [bool]$supervisorRefusal.claim_boundary.physical_acceptance_authority -and
        -not [bool]$supervisorRefusal.claim_boundary.release_authority
    ) "SUPERSEDED_SUPERVISOR_REFUSAL_INVALID"
    Assert-R10f (
        [string]$authority.schema_version -ceq $script:AuthoritySchema -and
        [string]$authority.status -ceq "authorized_single_use_unconsumed" -and
        [string]$authority.gate_id -ceq $script:GateId -and
        [string]$authority.repair_id -ceq $script:RepairId -and
        [string]$authority.campaign_id -ceq $script:CampaignId -and
        [string]$authority.question_class -ceq "development" -and
        [string]$authority.campaign_role -ceq "development_route_ghost" -and
        [string]$authority.ledger_scope.subsystem -ceq "recovery" -and
        [string]$authority.ledger_scope.engine_scope -ceq "godot_jolt" -and
        [string]$authority.ledger_scope.authority_mode -ceq
            "single_use_physical_execution_authority" -and
        [string]$authority.ledger_scope.question_class -ceq "development" -and
        [bool]$authority.authorization_commit_derived_from_current_head -and
        [string]$authority.source_commit -cmatch "^[0-9a-f]{40}$" -and
        [string]$authority.authorization_parent_commit -cmatch "^[0-9a-f]{40}$" -and
        [string]$authority.qualification_parent_commit -ceq
            [string]$authority.source_commit -and
        [string]$authority.zero_world_qualification_closure_path -ceq
            $script:ExpectedFreezeRelativePath -and
        [string]$authority.zero_world_qualification_closure_sha256 -ceq $freezeSha -and
        [string]$authority.dependency_manifest_raw_sha256 -ceq $manifestSha -and
        [string]$authority.r10f_design_sha256 -ceq $designSha -and
        [string]$authority.repair_design_sha256 -ceq
            $script:ExpectedRepairDesignSha256 -and
        [string]$authority.branch_completeness_addendum_sha256 -ceq
            $script:ExpectedBranchCompletenessAddendumSha256 -and
        [string]$authority.superseded_physical_supervisor_refusal_sha256 -ceq
            $script:ExpectedSupervisorRefusalSha256 -and
        [string]$authority.consumed_predecessor_physical_closure_sha256 -ceq
            $script:ExpectedPredecessorPhysicalClosureSha256 -and
        [string]$authority.worker_resource_path -ceq $script:WorkerResource -and
        (Test-ExactInteger $authority.seed $script:DevelopmentSeed) -and
        [string]$authority.seed_sha256 -ceq $script:DevelopmentSeedSha256 -and
        (Test-ExactInteger $authority.maximum_campaign_attempt_count 1) -and
        (Test-ExactInteger $authority.maximum_child_process_count 2) -and
        (Test-ExactInteger $authority.maximum_world_count_per_child 1) -and
        (Test-ExactInteger $authority.maximum_world_count $script:MaximumWorldCount) -and
        (Test-ExactInteger $authority.maximum_solver_step_count_per_child 3842) -and
        (Test-ExactInteger $authority.maximum_solver_step_count $script:MaximumSolverStepCount) -and
        [string]$authority.ordered_child_roles[0] -ceq $script:OrderedChildRoles[0] -and
        [string]$authority.ordered_child_roles[1] -ceq $script:OrderedChildRoles[1] -and
        [bool]$authority.zero_world_qualification_passed -and
        [bool]$authority.physical_execution_authorized -and
        -not [bool]$authority.physical_identity_consumed -and
        -not [bool]$authority.same_identity_rerun_permitted -and
        -not [bool]$authority.physical_acceptance_authority -and
        -not [bool]$authority.release_authority -and
        (Test-ExactInteger -Value $authority.qualified_source_path_count `
            -Expected $expectedSourceCount) -and
        [string]$authority.qualified_source_path_sha256 -ceq
            [string]$policy.expected_qualified_source_path_sha256
    ) "PHYSICAL_AUTHORITY_INVALID"
    Assert-R10f (
        [string]$freeze.schema_version -ceq $script:FreezeSchema -and
        [string]$freeze.status -ceq
            "closed_passing_official_zero_world_qualification" -and
        [string]$freeze.gate_id -ceq $script:GateId -and
        [string]$freeze.repair_id -ceq $script:RepairId -and
        [string]$freeze.campaign_id -ceq $script:CampaignId -and
        [string]$freeze.campaign_role -ceq "development_route_ghost" -and
        [string]$freeze.question_class -ceq "development" -and
        [string]$freeze.ledger_scope.subsystem -ceq "recovery" -and
        [string]$freeze.ledger_scope.engine_scope -ceq "godot_jolt" -and
        [string]$freeze.ledger_scope.authority_mode -ceq
            "official_zero_world_qualification" -and
        [string]$freeze.ledger_scope.question_class -ceq "development" -and
        [string]$freeze.source_commit -ceq [string]$authority.source_commit -and
        [string]$freeze.qualification_parent_commit -ceq
            [string]$authority.source_commit -and
        [string]$freeze.dependency_manifest_raw_sha256 -ceq $manifestSha -and
        [string]$freeze.r10f_design_sha256 -ceq $designSha -and
        [string]$freeze.repair_design_sha256 -ceq
            $script:ExpectedRepairDesignSha256 -and
        [string]$freeze.branch_completeness_addendum_sha256 -ceq
            $script:ExpectedBranchCompletenessAddendumSha256 -and
        [string]$freeze.superseded_physical_supervisor_refusal.raw_sha256 -ceq
            $script:ExpectedSupervisorRefusalSha256 -and
        [string]$freeze.superseded_physical_supervisor_refusal.repair_id -ceq
            "QSDK-R10F-L2" -and
        -not [bool]$freeze.superseded_physical_supervisor_refusal.physical_attempt_identity_consumed -and
        [string]$freeze.worker_resource_path -ceq $script:WorkerResource -and
        (Test-ExactInteger $freeze.seed $script:DevelopmentSeed) -and
        [string]$freeze.seed_sha256 -ceq $script:DevelopmentSeedSha256 -and
        (Test-ExactInteger $freeze.maximum_campaign_attempt_count 1) -and
        (Test-ExactInteger $freeze.maximum_child_process_count 2) -and
        (Test-ExactInteger $freeze.maximum_world_count_per_child 1) -and
        (Test-ExactInteger $freeze.maximum_world_count $script:MaximumWorldCount) -and
        (Test-ExactInteger $freeze.maximum_solver_step_count_per_child 3842) -and
        (Test-ExactInteger $freeze.maximum_solver_step_count $script:MaximumSolverStepCount) -and
        [string]$freeze.ordered_child_roles[0] -ceq $script:OrderedChildRoles[0] -and
        [string]$freeze.ordered_child_roles[1] -ceq $script:OrderedChildRoles[1] -and
        [string]$freeze.qualified_source_path_sha256 -ceq
            [string]$policy.expected_qualified_source_path_sha256 -and
        (Test-ExactInteger -Value $freeze.qualified_source_path_count `
            -Expected $expectedSourceCount) -and
        [bool]$freeze.official_zero_world_qualification_passed -and
        -not [bool]$freeze.physical_execution_authorized_by_freeze -and
        [bool]$freeze.claim_boundary.process_isolation_qualified_zero_world -and
        [bool]$freeze.claim_boundary.nullable_terminal_failure_code_projection_qualified_zero_world -and
        [bool]$freeze.claim_boundary.precondition_release_owner_source_projection_qualified_zero_world -and
        [bool]$freeze.claim_boundary.walking_actuation_handoff_qualified_zero_world -and
        [bool]$freeze.claim_boundary.walking_native_preparse_transport_verification_qualified_zero_world -and
        [bool]$freeze.claim_boundary.walking_binary32_host_target_projection_qualified_zero_world -and
        [bool]$freeze.claim_boundary.walking_ledger_v2_named_predicates_qualified_zero_world -and
        [bool]$freeze.claim_boundary.walking_failed_step_source_retention_qualified_zero_world -and
        (Test-ExactInteger $freeze.claim_boundary.walking_ledger_l13_positive_control_count 15) -and
        (Test-ExactInteger $freeze.claim_boundary.walking_ledger_l13_mutation_rejection_count 16) -and
        (Test-ExactInteger $freeze.claim_boundary.walking_ledger_failure_retention_positive_control_count 1) -and
        (Test-ExactInteger $freeze.claim_boundary.walking_ledger_failure_retention_mutation_rejection_count 15) -and
        (Test-ExactInteger $freeze.claim_boundary.production_shaped_walking_fixture_count 3) -and
        (Test-ExactInteger $freeze.claim_boundary.detached_hinge_parameter_container_count 24) -and
        (Test-ExactInteger $freeze.claim_boundary.qualified_r69_host_cap_projection_count 8) -and
        -not [bool]$freeze.claim_boundary.shared_adapter_enable_behavior_changed -and
        -not [bool]$freeze.claim_boundary.published_actuator_profile_changed -and
        (Test-ExactInteger $freeze.claim_boundary.walking_handoff_extra_solver_step_count 0) -and
        -not [bool]$freeze.claim_boundary.threshold_or_controller_changed -and
        -not [bool]$freeze.claim_boundary.sdk1_m07_satisfied -and
        -not [bool]$freeze.claim_boundary.physical_acceptance_authority -and
        -not [bool]$freeze.claim_boundary.release_authority -and
        -not [bool]$freeze.physical_acceptance_authority -and
        -not [bool]$freeze.release_authority
    ) "ZERO_WORLD_FREEZE_INVALID"
    Assert-R10fL14FrozenAuthorityBindings -Freeze $freeze -Bindings $repairDesign.authority_bindings
    Assert-R10fL14FrozenComponentQualification -Document $authority -AuthorityName "authority"
    Assert-R10fL14FrozenComponentQualification -Document $freeze -AuthorityName "freeze"
    Assert-QsdkR10fL14RuntimeBinding $authority.l14_exact_runtime_images
    Assert-QsdkR10fL14RuntimeBinding $freeze.l14_exact_runtime_images
    $expectedRuntimePath = Join-Path $script:ExpectedEvidenceRoot (
        "qsdk-r10f-development-route-ghost-zero-world-qualification-" +
        ([string]$authority.source_commit).Substring(0, 12) + "/runtime_identity.json"
    )
    $runtimePath = [IO.Path]::GetFullPath([string]$freeze.qualified_runtime_identity.path)
    Assert-R10f (
        $runtimePath -ceq [IO.Path]::GetFullPath($expectedRuntimePath) -and
        (Test-Path -LiteralPath $runtimePath -PathType Leaf) -and
        (Test-ExactInteger -Value $freeze.qualified_runtime_identity.byte_length -Expected (Get-Item -LiteralPath $runtimePath).Length) -and
        (Get-PrefixedSha256 $runtimePath) -ceq $freeze.qualified_runtime_identity.raw_sha256
    ) "L14_QUALIFIED_RUNTIME_FILE_BINDING"
    $qualifiedRuntime = Read-JsonHashtable $runtimePath
    Assert-QsdkR10fL14RuntimeBinding $qualifiedRuntime.l14_exact_runtime_images
    $headParent = Invoke-GitText @("rev-parse", "HEAD^") "HEAD_PARENT"
    $headGrandparent = Invoke-GitText @("rev-parse", "HEAD^^") "HEAD_GRANDPARENT"
    Assert-R10f (
        [string]$Boundary.head -cne [string]$authority.source_commit -and
        $headParent -ceq [string]$authority.authorization_parent_commit -and
        $headGrandparent -ceq [string]$authority.source_commit
    ) "AUTHORITY_COMMIT_GRAPH_INVALID"
    $changedText = Invoke-GitText @(
            "diff", "--name-only", [string]$authority.source_commit,
            [string]$Boundary.head
        ) "AUTHORITY_GRAPH_DIFF" -AllowEmpty
    $changed = @(ConvertFrom-R10fGitPathText -Text $changedText)
    Assert-R10f (Test-R10fExactOrdinalPathSet `
        -Actual $changed `
        -Expected @(
            $script:ExpectedAuthorityRelativePath,
            $script:ExpectedFreezeRelativePath
        )
    ) "AUTHORITY_GRAPH_CHANGED_PATHS_INVALID"
    return [ordered]@{
        authority = $authority
        authority_sha256 = $authoritySha
        authority_path = $resolved
        freeze = $freeze
        freeze_sha256 = $freezeSha
        l14_exact_runtime_images = $qualifiedRuntime.l14_exact_runtime_images
        superseded_physical_supervisor_refusal = $supervisorRefusal
        superseded_physical_supervisor_refusal_sha256 = $supervisorRefusalSha
        consumed_predecessor_physical_closure = $predecessorPhysical.closure
        consumed_predecessor_physical_closure_sha256 = $predecessorPhysical.sha256
        repair_design = $repairDesign.design
        repair_design_sha256 = $repairDesign.sha256
        branch_completeness_addendum = $repairDesign.authority_bindings.branch_completeness_addendum
        branch_completeness_addendum_sha256 = $script:ExpectedBranchCompletenessAddendumSha256
    }
}


function Invoke-Preflight {
    $boundary = Get-SourceBoundary
    Assert-R10f (-not $RunPhysical) "PREFLIGHT_CANNOT_RUN_PHYSICAL"
    Assert-R10f ($AuthorizationPath.Length -eq 0) "PREFLIGHT_CANNOT_ACCEPT_AUTHORITY"
    Assert-R10f (Test-Path -LiteralPath $script:WorkerPath -PathType Leaf) "WORKER_MISSING"
    Assert-R10f (Test-Path -LiteralPath $script:ManifestPath -PathType Leaf) "MANIFEST_MISSING"
    Assert-R10f (
        (Test-Path -LiteralPath $script:SupervisorRefusalPath -PathType Leaf) -and
        [int64](Get-Item -LiteralPath $script:SupervisorRefusalPath).Length -eq
            $script:ExpectedSupervisorRefusalBytes -and
        (Get-PrefixedSha256 $script:SupervisorRefusalPath) -ceq
            $script:ExpectedSupervisorRefusalSha256
    ) "SUPERSEDED_SUPERVISOR_REFUSAL_BINDING"
    $predecessorPhysical = Get-ConsumedPredecessorPhysicalClosure `
        -SourceCommit ([string]$boundary.head)
    $null = Get-L11RepairDesign -SourceCommit ([string]$boundary.head)
    $null = Get-L12RepairDesign -SourceCommit ([string]$boundary.head)
    $repairDesign = Get-L14RepairDesign -SourceCommit ([string]$boundary.head)
    $pairEvaluator = Invoke-QsdkR10fL9PairEvaluatorZeroWorld
    Assert-R10f (
        [bool]$pairEvaluator.ok -and
        (Test-ExactInteger $pairEvaluator.positive_control_count 3) -and
        (Test-ExactInteger $pairEvaluator.mutation_rejection_count 35) -and
        (Test-ExactInteger $pairEvaluator.model_construction_count 0) -and
        (Test-ExactInteger $pairEvaluator.world_attempt_count 0) -and
        (Test-ExactInteger $pairEvaluator.world_build_count 0) -and
        (Test-ExactInteger $pairEvaluator.native_readback_count 0) -and
        (Test-ExactInteger $pairEvaluator.solver_step_count 0) -and
        -not [bool]$pairEvaluator.physics_state_modified -and
        -not [bool]$pairEvaluator.physical_acceptance_authority -and
        -not [bool]$pairEvaluator.release_authority
    ) "L9_PAIR_EVALUATOR_ZERO_WORLD_CONTROL"
    $projectionControl = @(
        ConvertFrom-R10fGitPathText -Text "sdk/a.json`r`nsdk/b.json`n"
    )
    $emptyProjectionControl = @(ConvertFrom-R10fGitPathText -Text "")
    Assert-R10f (
        $projectionControl.Count -eq 2 -and
        [string]$projectionControl[0] -ceq "sdk/a.json" -and
        [string]$projectionControl[1] -ceq "sdk/b.json" -and
        $emptyProjectionControl.Count -eq 0
    ) "AUTHORITY_GRAPH_PATH_PROJECTION_ZERO_WORLD_CONTROL"
    [string[]]$expectedSet = @("sdk/a.json", "sdk/b.json")
    Assert-R10f (
        (Test-R10fExactOrdinalPathSet -Actual $expectedSet -Expected $expectedSet) -and
        (Test-R10fExactOrdinalPathSet `
            -Actual @("sdk/b.json", "sdk/a.json") -Expected $expectedSet) -and
        -not (Test-R10fExactOrdinalPathSet `
            -Actual @("sdk/a.json") -Expected $expectedSet) -and
        -not (Test-R10fExactOrdinalPathSet `
            -Actual @("sdk/a.json", "sdk/a.json") -Expected $expectedSet) -and
        -not (Test-R10fExactOrdinalPathSet `
            -Actual @("sdk/a.json", "sdk/b.json", "sdk/c.json") `
            -Expected $expectedSet)
    ) "AUTHORITY_GRAPH_PATH_SET_ZERO_WORLD_CONTROL"
    $receipt = [ordered]@{
        schema_version = "sporespore_qsdk_r10f_supervisor_zero_world_preflight_v1"
        gate_id = $script:GateId
        repair_id = $script:RepairId
        campaign_id = $script:CampaignId
        campaign_role = "development_route_ghost"
        question_class = "development"
        ledger_scope = Get-R10fLedgerScope "zero_world_supervisor_preflight"
        ok = $true
        mode = "Preflight"
        source_boundary = $boundary
        worker_resource_path = $script:WorkerResource
        worker_raw_sha256 = Get-PrefixedSha256 $script:WorkerPath
        dependency_manifest_raw_sha256 = Get-PrefixedSha256 $script:ManifestPath
        design_raw_sha256 = Get-PrefixedSha256 $script:DesignPath
        repair_design_raw_sha256 = [string]$repairDesign.sha256
        branch_completeness_addendum_raw_sha256 = $script:ExpectedBranchCompletenessAddendumSha256
        pair_evaluator_raw_sha256 = Get-PrefixedSha256 (
            Join-Path $PSScriptRoot "qsdk_r10f_process_isolated_pair_evaluator.ps1"
        )
        pair_evaluator_zero_world = $pairEvaluator
        pair_evaluator_positive_control_count = 3
        pair_evaluator_mutation_rejection_count = 35
        ordered_child_roles = @($script:OrderedChildRoles)
        child_processes_overlap_in_wall_clock_time = $false
        one_arm_per_child_process = $true
        one_world_per_child_process = $true
        superseded_physical_supervisor_refusal_sha256 = (
            $script:ExpectedSupervisorRefusalSha256
        )
        consumed_predecessor_physical_closure_sha256 = (
            [string]$predecessorPhysical.sha256
        )
        authority_graph_path_projection_zero_world_control_count = 2
        authority_graph_path_set_zero_world_control_count = 5
        physical_execution_requested = $false
        physical_execution_authorized = $false
        event_triggered_passive_recovery = $true
        force_aware_recovery = $false
        model_construction_count = 0
        world_attempt_count = 0
        world_build_count = 0
        scene_tree_insertion_count = 0
        native_readback_count = 0
        solver_step_count = 0
        physics_state_modified = $false
        physical_acceptance_authority = $false
        release_authority = $false
    }
    Write-Output ($script:PreflightMarker + (ConvertTo-SporeSporeExactJson -Value $receipt))
}


function Invoke-RetiredL8Physical {
    throw "QSDK_R10F_L8_SINGLE_PROCESS_SUPERVISOR_RETIRED"
    Assert-R10f $RunPhysical "PHYSICAL_MODE_REQUIRES_RUNPHYSICAL"
    Assert-R10f (
        [IO.Path]::GetFullPath($EvidenceRoot) -ceq $script:ExpectedEvidenceRoot
    ) "EVIDENCE_ROOT_NOT_EXACT"
    $boundary = Get-SourceBoundary -RequireLiveCleanMain
    $binding = Get-PhysicalAuthority -Path $AuthorizationPath -Boundary $boundary
    $godotPath = [IO.Path]::GetFullPath($Godot)
    Assert-R10f (Test-Path -LiteralPath $godotPath -PathType Leaf) "GODOT_MISSING"
    $authoritySlug = ([string]$binding.authority_sha256).Substring(7, 16)
    $attemptRoot = Join-Path $script:ExpectedEvidenceRoot (
        "qsdk-r10f-development-route-ghost-" + $authoritySlug
    )
    Assert-R10f (-not (Test-Path -LiteralPath $attemptRoot)) (
        "PHYSICAL_IDENTITY_ALREADY_CONSUMED:" + $attemptRoot
    )
    $null = New-Item -ItemType Directory -Path $attemptRoot
    $attemptId = [Guid]::NewGuid().ToString("N").ToLowerInvariant()
    $nonce = [Guid]::NewGuid().ToString("N").ToLowerInvariant()
    $attempt = [ordered]@{
        schema_version = "sporespore_qsdk_r10f_physical_attempt_identity_v1"
        gate_id = $script:GateId
        repair_id = $script:RepairId
        campaign_id = $script:CampaignId
        campaign_role = "development_route_ghost"
        question_class = "development"
        ledger_scope = Get-R10fLedgerScope "consumed_physical_attempt_identity"
        status = "physical_identity_consumed_before_worker_start"
        source_commit = [string]$binding.authority.source_commit
        authority_sha256 = [string]$binding.authority_sha256
        consumed_predecessor_physical_closure_sha256 = (
            [string]$binding.consumed_predecessor_physical_closure_sha256
        )
        repair_design_sha256 = [string]$binding.repair_design_sha256
        attempt_id = $attemptId
        termination_nonce = $nonce
        seed = $script:DevelopmentSeed
        same_identity_rerun_permitted = $false
        maximum_campaign_attempt_count = 1
        maximum_world_count = $script:MaximumWorldCount
        created_utc = [DateTime]::UtcNow.ToString("o")
        physical_execution_authorized = $true
        physical_acceptance_authority = $false
        release_authority = $false
    }
    Write-JsonCreateNew (Join-Path $attemptRoot "attempt_identity.json") $attempt
    $script:PhysicalAttemptIdentityConsumed = $true
    $script:PhysicalAttemptRoot = $attemptRoot
    $environment = @{
        SPORESPORE_GODOT_RECOVERY_AUTHORIZATION_SHA256 = [string]$binding.authority_sha256
        SPORESPORE_GODOT_RECOVERY_SOURCE_COMMIT = [string]$binding.authority.source_commit
        SPORESPORE_GODOT_RECOVERY_ATTEMPT_ID = $attemptId
        SPORESPORE_GODOT_RECOVERY_SUPERVISED_TERMINATION = "1"
        SPORESPORE_GODOT_RECOVERY_TERMINATION_NONCE = $nonce
        SPORESPORE_GODOT_RECOVERY_GATE_ID = $script:GateId
        SPORESPORE_GODOT_RECOVERY_GATE_TOKEN = $script:GateToken
        SPORESPORE_GODOT_RECOVERY_RAW_SCHEMA = $script:RawSchema
        SPORESPORE_GODOT_RECOVERY_WORK_ID = $script:WorkId
        SPORESPORE_GODOT_RECOVERY_RAW_MARKER = $script:RawMarker
        SPORESPORE_GODOT_RECOVERY_READY_MARKER = $script:ReadyMarker
        SPORESPORE_GODOT_RECOVERY_PROGRESS_MARKER = ""
        SPORESPORE_GODOT_RECOVERY_PROGRESS_CADENCE_STEPS = "0"
        SPORESPORE_GODOT_RECOVERY_SEED = [string]$script:DevelopmentSeed
        SPORESPORE_GODOT_RECOVERY_SEED_LABEL = $script:DevelopmentSeedLabel
        SPORESPORE_GODOT_RECOVERY_SEED_SHA256 = $script:DevelopmentSeedSha256
        SPORESPORE_GODOT_RECOVERY_ACTUATOR_MODE = $script:ActuatorMode
        SPORESPORE_GODOT_RECOVERY_CONTROLLER_ID = $script:ControllerId
        SPORESPORE_GODOT_RECOVERY_ENERGY_ROUTE_ID = $script:EnergyRouteId
    }
    $run = Invoke-SporeSporeGodotReceiptTerminatedProcess `
        -FileName $godotPath `
        -Arguments @("--headless", "--path", $script:RepoRoot, "--script", $script:WorkerResource) `
        -WorkingDirectory $script:RepoRoot `
        -ReadyMarkerPrefix $script:ReadyMarker `
        -ExpectedNonce $nonce `
        -Environment $environment `
        -ScrubEnvironmentNames $script:EnvironmentNames `
        -TimeoutSeconds $TimeoutSeconds
    Write-Utf8CreateNew (Join-Path $attemptRoot "worker.stdout.txt") ([string]$run.stdout)
    Write-Utf8CreateNew (Join-Path $attemptRoot "worker.stderr.txt") ([string]$run.stderr)
    $engineHealth = Get-SporeSporeGodotEngineHealthProjection `
        -StandardError ([string]$run.stderr)
    $raw = Get-OptionalSingleMarkerJson `
        -Stdout ([string]$run.stdout) `
        -Marker $script:RawMarker
    $rawMarkerValid = $null -ne $raw
    $validRaw = $false
    if ($rawMarkerValid) {
        $rawShapeValid = $true
        foreach ($requiredKey in @(
            "schema_version", "gate_id", "source_commit", "authorization_sha256",
            "attempt_id", "ok", "status", "scientific_outcome", "seed",
            "world_attempt_count", "world_build_count", "model_construction_count",
            "complete_trace_count", "behavior_evaluator_invocation_count",
            "external_kick_application_count", "solver_step_count",
            "maximum_solver_step_count", "route_evaluation", "arm_results",
            "precondition_pair_barrier_state", "precondition_pair_barrier_state_sha256",
            "precondition_pair_barrier_state_valid", "precondition_pair_barrier_released",
            "precondition_pair_barrier_evidence_by_arm",
            "all_in_run_physical_invariants_passed", "same_body_identity_preserved",
            "physical_question_opened", "physics_state_modified", "held_out",
            "force_aware_recovery", "physical_acceptance_authority", "release_authority"
        )) {
            if (-not $raw.Contains($requiredKey)) { $rawShapeValid = $false }
        }
        $routeEvaluation = if (
            $raw.Contains("route_evaluation") -and
            $raw["route_evaluation"] -is [System.Collections.IDictionary]
        ) { $raw["route_evaluation"] } else { $null }
        $behaviorFieldValid = (
            $null -ne $routeEvaluation -and
            $routeEvaluation.Contains("behavior_passed") -and
            $routeEvaluation["behavior_passed"] -is [bool]
        )
        $behaviorPassed = $behaviorFieldValid -and [bool]$routeEvaluation["behavior_passed"]
        $expectedOutcome = if ($behaviorPassed) { "positive" } else { "negative" }
        $pairState = if (
            $raw.Contains("precondition_pair_barrier_state") -and
            $raw["precondition_pair_barrier_state"] -is [System.Collections.IDictionary]
        ) { $raw["precondition_pair_barrier_state"] } else { $null }
        $pairEvidence = if (
            $raw.Contains("precondition_pair_barrier_evidence_by_arm") -and
            $raw["precondition_pair_barrier_evidence_by_arm"] -is
                [System.Collections.IDictionary]
        ) { $raw["precondition_pair_barrier_evidence_by_arm"] } else { $null }
        $armResults = if (
            $raw.Contains("arm_results") -and
            $raw["arm_results"] -is [System.Collections.IDictionary]
        ) { $raw["arm_results"] } else { $null }
        $routeReceipts = if (
            $null -ne $routeEvaluation -and
            $routeEvaluation.Contains("route_receipts") -and
            $routeEvaluation["route_receipts"] -is [System.Collections.IDictionary]
        ) { $routeEvaluation["route_receipts"] } else { $null }
        $pairStateShapeValid = $null -ne $pairState
        if ($pairStateShapeValid) {
            foreach ($requiredKey in @(
                "schema_version", "repair_id", "attempt_id", "released",
                "payload_sha256"
            )) {
                if (-not $pairState.Contains($requiredKey)) {
                    $pairStateShapeValid = $false
                }
            }
        }
        $routeBarrierShapeValid = $null -ne $routeEvaluation
        if ($routeBarrierShapeValid) {
            foreach ($requiredKey in @(
                "precondition_pair_barrier_state_sha256",
                "precondition_pair_barrier_released"
            )) {
                if (-not $routeEvaluation.Contains($requiredKey)) {
                    $routeBarrierShapeValid = $false
                }
            }
        }
        $routeReceiptBarrierShapeValid = $null -ne $routeReceipts
        if (
            $routeReceiptBarrierShapeValid -and
            -not $routeReceipts.Contains(
                "precondition_pair_barrier_released_from_two_source_terminals"
            )
        ) {
            $routeReceiptBarrierShapeValid = $false
        }
        $pairBarrierValid = (
            $rawShapeValid -and
            $pairStateShapeValid -and
            $null -ne $pairEvidence -and
            $null -ne $armResults -and
            $routeBarrierShapeValid -and
            $routeReceiptBarrierShapeValid -and
            [string]$pairState.schema_version -ceq
                "sporespore_qsdk_r10f_precondition_pair_barrier_state_v1" -and
            [string]$pairState.repair_id -ceq $script:RepairId -and
            [string]$pairState.attempt_id -ceq $attemptId -and
            [bool]$pairState.released -and
            [string]$pairState.payload_sha256 -cmatch '^sha256:[0-9a-f]{64}$' -and
            [string]$raw.precondition_pair_barrier_state_sha256 -ceq
                [string]$pairState.payload_sha256 -and
            [bool]$raw.precondition_pair_barrier_state_valid -and
            [bool]$raw.precondition_pair_barrier_released -and
            [string]$routeEvaluation.precondition_pair_barrier_state_sha256 -ceq
                [string]$pairState.payload_sha256 -and
            [bool]$routeEvaluation.precondition_pair_barrier_released -and
            [bool]$routeReceipts.precondition_pair_barrier_released_from_two_source_terminals
        )
        if ($pairBarrierValid) {
            foreach ($armId in @(
                "kick_passive_recovery_resume", "matched_no_kick_continuation"
            )) {
                $armShapeValid = (
                    $pairEvidence.Contains($armId) -and
                    $armResults.Contains($armId) -and
                    $pairEvidence[$armId] -is [System.Collections.IDictionary] -and
                    $armResults[$armId] -is [System.Collections.IDictionary]
                )
                if ($armShapeValid) {
                    foreach ($requiredKey in @(
                        "precondition_pair_barrier_retention_valid",
                        "precondition_pair_barrier_release_application_count",
                        "precondition_pair_barrier_application_projection_count"
                    )) {
                        if (-not $armResults[$armId].Contains($requiredKey)) {
                            $armShapeValid = $false
                        }
                    }
                }
                if (
                    -not $armShapeValid -or
                    -not [bool]$armResults[$armId].precondition_pair_barrier_retention_valid -or
                    [int64]$armResults[$armId].precondition_pair_barrier_release_application_count -ne 1 -or
                    [int64]$armResults[$armId].precondition_pair_barrier_application_projection_count -lt 1
                ) {
                    $pairBarrierValid = $false
                }
            }
        }
        $validRaw = (
            $rawShapeValid -and
            [bool]$run.termination_protocol_valid -and
            [int]$run.exit_code -eq 0 -and
            [bool]$engineHealth.passed -and
            [string]$raw.schema_version -ceq $script:RawSchema -and
            [string]$raw.gate_id -ceq $script:GateId -and
            [string]$raw.source_commit -ceq [string]$binding.authority.source_commit -and
            [string]$raw.authorization_sha256 -ceq [string]$binding.authority_sha256 -and
            [string]$raw.attempt_id -ceq $attemptId -and
            [bool]$raw.ok -and
            [string]$raw.status -ceq "valid_complete_behavior_development" -and
            $behaviorFieldValid -and
            [string]$raw.scientific_outcome -ceq $expectedOutcome -and
            (Test-ExactInteger $raw.seed $script:DevelopmentSeed) -and
            (Test-ExactInteger $raw.world_attempt_count 2) -and
            (Test-ExactInteger $raw.world_build_count 2) -and
            (Test-ExactInteger $raw.model_construction_count 2) -and
            (Test-ExactInteger $raw.complete_trace_count 2) -and
            (Test-ExactInteger $raw.behavior_evaluator_invocation_count 1) -and
            (Test-ExactInteger $raw.external_kick_application_count 1) -and
            (Test-ExactInteger $raw.maximum_solver_step_count $script:MaximumSolverStepCount) -and
            [int64]$raw.solver_step_count -gt 0 -and
            [int64]$raw.solver_step_count -le $script:MaximumSolverStepCount -and
            [bool]$raw.all_in_run_physical_invariants_passed -and
            [bool]$raw.same_body_identity_preserved -and
            $pairBarrierValid -and
            [bool]$raw.physical_question_opened -and
            [bool]$raw.physics_state_modified -and
            -not [bool]$raw.held_out -and
            -not [bool]$raw.force_aware_recovery -and
            -not [bool]$raw.physical_acceptance_authority -and
            -not [bool]$raw.release_authority
        )
    }
    $worldAttemptCount = if (
        $rawMarkerValid -and
        $raw.Contains("world_attempt_count") -and
        ($raw.world_attempt_count -is [int32] -or $raw.world_attempt_count -is [int64])
    ) { [int64]$raw.world_attempt_count } else { -1 }
    $worldBuildCount = if (
        $rawMarkerValid -and
        $raw.Contains("world_build_count") -and
        ($raw.world_build_count -is [int32] -or $raw.world_build_count -is [int64])
    ) { [int64]$raw.world_build_count } else { -1 }
    $modelConstructionCount = if (
        $rawMarkerValid -and
        $raw.Contains("model_construction_count") -and
        (
            $raw.model_construction_count -is [int32] -or
            $raw.model_construction_count -is [int64]
        )
    ) { [int64]$raw.model_construction_count } else { -1 }
    $solverStepCount = if (
        $rawMarkerValid -and
        $raw.Contains("solver_step_count") -and
        ($raw.solver_step_count -is [int32] -or $raw.solver_step_count -is [int64])
    ) { [int64]$raw.solver_step_count } else { -1 }
    $failureCode = ""
    if (-not $validRaw) {
        if (-not $rawMarkerValid) {
            $failureCode = "RAW_MARKER_MISSING_AMBIGUOUS_OR_INVALID"
        } elseif ($raw.Contains("failure_code") -and [string]$raw.failure_code) {
            $failureCode = [string]$raw.failure_code
        } elseif (-not [bool]$run.termination_protocol_valid) {
            $failureCode = "SUPERVISED_TERMINATION_PROTOCOL_INVALID"
        } elseif (-not [bool]$engineHealth.passed) {
            $failureCode = "ENGINE_HEALTH_INVALID"
        } else {
            $failureCode = "RAW_RECEIPT_VALIDATION_FAILED"
        }
    }
    $supervisor = [ordered]@{
        schema_version = "sporespore_qsdk_r10f_physical_supervisor_result_v1"
        gate_id = $script:GateId
        repair_id = $script:RepairId
        campaign_id = $script:CampaignId
        campaign_role = "development_route_ghost"
        question_class = "development"
        ledger_scope = Get-R10fLedgerScope "consumed_physical_campaign_report"
        ok = $validRaw
        status = if ($validRaw) {
            "valid_complete_behavior_development"
        } else {
            "invalid_or_incomplete_behavior_development"
        }
        scientific_outcome = if ($validRaw) { [string]$raw.scientific_outcome } else { "none" }
        failure_code = $failureCode
        source_commit = [string]$binding.authority.source_commit
        authority_sha256 = [string]$binding.authority_sha256
        consumed_predecessor_physical_closure_sha256 = (
            [string]$binding.consumed_predecessor_physical_closure_sha256
        )
        repair_design_sha256 = [string]$binding.repair_design_sha256
        attempt_id = $attemptId
        attempt_identity_consumed = $true
        same_identity_rerun_permitted = $false
        maximum_campaign_attempt_count = 1
        maximum_world_count = $script:MaximumWorldCount
        maximum_solver_step_count = $script:MaximumSolverStepCount
        raw_marker_valid = $rawMarkerValid
        route_execution_valid = $validRaw
        behavior_passed = if ($validRaw) { $behaviorPassed } else { $false }
        count_fields_known = (
            $worldAttemptCount -ge 0 -and
            $worldBuildCount -ge 0 -and
            $modelConstructionCount -ge 0 -and
            $solverStepCount -ge 0
        )
        model_construction_count = $modelConstructionCount
        world_attempt_count = $worldAttemptCount
        world_build_count = $worldBuildCount
        solver_step_count = $solverStepCount
        physical_question_opened = $true
        physics_state_modified = if ($solverStepCount -ge 0) {
            $solverStepCount -gt 0
        } else {
            $null
        }
        worker_receipt = $raw
        termination = $run
        engine_health = $engineHealth
        operation_lock = Get-SporeSporeLocomotionOperationLockPublicReceipt $lock
        evidence_root = $attemptRoot.Replace("\", "/")
        physical_acceptance_authority = $false
        release_authority = $false
    }
    Write-JsonCreateNew (Join-Path $attemptRoot "supervisor_result.json") $supervisor
    Write-Output ($script:PhysicalMarker + (ConvertTo-SporeSporeExactJson -Value $supervisor))
    if (-not $validRaw) { exit 1 }
}


function Get-R10fRetainedFileBinding {
    param([Parameter(Mandatory)][string]$Path)
    $resolved = [IO.Path]::GetFullPath($Path)
    Assert-R10f (Test-Path -LiteralPath $resolved -PathType Leaf) (
        "RETAINED_FILE_MISSING:" + $resolved
    )
    return [ordered]@{
        path = $resolved.Replace("\", "/")
        byte_length = [int64](Get-Item -LiteralPath $resolved).Length
        raw_sha256 = Get-PrefixedSha256 $resolved
    }
}


function Get-L9ObservedCounterProjection {
    param(
        [Parameter(Mandatory)][AllowEmptyCollection()][object[]]$ChildEnvelopes
    )
    $fields = [ordered]@{
        model_construction_attempt_count = "model_construction_attempt_count"
        model_construction_count = "model_construction_count"
        world_attempt_count = "world_attempt_count"
        world_build_count = "world_build_count"
        solver_step_count = "solver_step_count"
        explicit_worker_extra_native_readback_count = (
            "explicit_worker_extra_native_readback_count"
        )
    }
    $values = [ordered]@{}
    $knownByField = [ordered]@{}
    foreach ($outputName in $fields.Keys) {
        $sourceName = [string]$fields[$outputName]
        $known = $ChildEnvelopes.Count -gt 0
        [int64]$total = 0
        foreach ($envelope in $ChildEnvelopes) {
            if (
                $envelope -isnot [System.Collections.IDictionary] -or
                $envelope.report -isnot [System.Collections.IDictionary] -or
                -not $envelope.report.Contains($sourceName) -or
                (
                    $envelope.report[$sourceName] -isnot [int32] -and
                    $envelope.report[$sourceName] -isnot [int64]
                ) -or
                [int64]$envelope.report[$sourceName] -lt 0
            ) {
                $known = $false
                break
            }
            $total += [int64]$envelope.report[$sourceName]
        }
        $values[$outputName] = if ($known) { $total } else { -1 }
        $knownByField[$outputName] = $known
    }
    $coreKnown = (
        [bool]$knownByField.model_construction_count -and
        [bool]$knownByField.world_attempt_count -and
        [bool]$knownByField.world_build_count -and
        [bool]$knownByField.solver_step_count
    )
    return [ordered]@{
        observed_completed_child_count = $ChildEnvelopes.Count
        core_count_fields_known = $coreKnown
        count_field_known = $knownByField
        model_construction_attempt_count = $values.model_construction_attempt_count
        model_construction_count = $values.model_construction_count
        world_attempt_count = $values.world_attempt_count
        world_build_count = $values.world_build_count
        solver_step_count = $values.solver_step_count
        explicit_worker_extra_native_readback_count = (
            $values.explicit_worker_extra_native_readback_count
        )
        physics_state_modified = if ([bool]$knownByField.solver_step_count) {
            [int64]$values.solver_step_count -gt 0
        } else { $null }
    }
}


function Get-L9ChildLaunchValidation {
    param(
        [Parameter(Mandatory)][System.Collections.IDictionary]$Envelope,
        [Parameter(Mandatory)][System.Collections.IDictionary]$Descriptor,
        [Parameter(Mandatory)][System.Collections.IDictionary]$Binding,
        [switch]$RequireL15LaunchRelationship
    )
    if ($script:RepairId -ceq 'QSDK-R10F-L15') { $RequireL15LaunchRelationship = $true }
    $l15ContextArguments = @{}
    if ($script:RepairId -ceq 'QSDK-R10F-L15') {
        . (Join-Path $script:RepoRoot 'sdk/qsdk_r10f_l15_context_source.ps1')
        $l15ContextArguments = Get-QsdkR10fL15ContextArguments $Binding
    }
    $child = Get-QsdkR10fL9ChildValidation @l15ContextArguments `
        -Report $Envelope.report `
        -ExpectedRole ([string]$Descriptor.role) `
        -ExpectedParentAttemptId $script:PhysicalAttemptId `
        -ExpectedChildAttemptId ([string]$Descriptor.child_attempt_id) `
        -ExpectedSourceCommit ([string]$Binding.authority.source_commit) `
        -ExpectedAuthoritySha256 ([string]$Binding.authority_sha256) `
        -ExpectedWorkerProcessId ([int]$Envelope.worker_process_id)
    $launchValid = (
        (Test-ExactInteger $Envelope.child_retry_count 0) -and
        (Test-ExactInteger $Envelope.child_replacement_count 0) -and
        (Test-ExactInteger $Envelope.exit_code 0) -and
        [bool]$Envelope.termination_protocol_valid -and
        [bool]$Envelope.engine_health_passed -and
        [bool]$Envelope.raw_marker_valid -and
        [bool]$child.ok
    )
    $relationshipFailure = ''
    if ($RequireL15LaunchRelationship) {
        try {
            $context = New-QsdkR10fL15ProductionLaunchContext `
                $script:PhysicalAttemptId $Descriptor $Binding.authority.source_commit `
                $Binding.authority_sha256 $Binding.l14_exact_runtime_images
            $null = Assert-QsdkR10fL15ChildLaunchRelationship $Envelope $context
        } catch {
            $launchValid = $false
            $relationshipFailure = $_.Exception.Message
        }
    }
    $validation = [ordered]@{
        ok = $launchValid
        child_validation = $child
        physical_acceptance_authority = $false
        release_authority = $false
    }
    if ($RequireL15LaunchRelationship) { $validation.l15_launch_relationship_failure = $relationshipFailure }
    return $validation
}


function New-QsdkR10fL9ChildEnvironment {
    param([Parameter(Mandatory)]$Descriptor, [Parameter(Mandatory)]$Binding)
    $environment = @{
        SPORESPORE_GODOT_RECOVERY_AUTHORIZATION_SHA256 = [string]$Binding.authority_sha256
        SPORESPORE_GODOT_RECOVERY_SOURCE_COMMIT = [string]$Binding.authority.source_commit
        SPORESPORE_GODOT_RECOVERY_ATTEMPT_ID = [string]$Descriptor.child_attempt_id
        SPORESPORE_GODOT_RECOVERY_SUPERVISED_TERMINATION = "1"
        SPORESPORE_GODOT_RECOVERY_TERMINATION_NONCE = [string]$Descriptor.termination_nonce
        SPORESPORE_GODOT_RECOVERY_GATE_ID = $script:GateId
        SPORESPORE_GODOT_RECOVERY_GATE_TOKEN = $script:GateToken
        SPORESPORE_GODOT_RECOVERY_RAW_SCHEMA = $script:RawSchema
        SPORESPORE_GODOT_RECOVERY_WORK_ID = $script:WorkId
        SPORESPORE_GODOT_RECOVERY_RAW_MARKER = $script:RawMarker
        SPORESPORE_GODOT_RECOVERY_READY_MARKER = $script:ReadyMarker
        SPORESPORE_GODOT_RECOVERY_PROGRESS_MARKER = ""
        SPORESPORE_GODOT_RECOVERY_PROGRESS_CADENCE_STEPS = "0"
        SPORESPORE_GODOT_RECOVERY_SEED = [string]$script:DevelopmentSeed
        SPORESPORE_GODOT_RECOVERY_SEED_LABEL = $script:DevelopmentSeedLabel
        SPORESPORE_GODOT_RECOVERY_SEED_SHA256 = $script:DevelopmentSeedSha256
        SPORESPORE_GODOT_RECOVERY_ACTUATOR_MODE = $script:ActuatorMode
        SPORESPORE_GODOT_RECOVERY_CONTROLLER_ID = $script:ControllerId
        SPORESPORE_GODOT_RECOVERY_ENERGY_ROUTE_ID = $script:EnergyRouteId
        SPORESPORE_GODOT_RECOVERY_PARENT_ATTEMPT_ID = $script:PhysicalAttemptId
        SPORESPORE_GODOT_RECOVERY_CHILD_ROLE = [string]$Descriptor.role
    }
    # Work on this child's environment only; never grow the shared scrub list
    # or allow inherited parent context to replace the enclosing expectation.
    $scrubEnvironmentNames = @($script:EnvironmentNames)
    if ($script:RepairId -ceq 'QSDK-R10F-L15') {
        . (Join-Path $script:RepoRoot 'sdk/qsdk_r10f_l15_context_source.ps1')
        $expectedContext = Get-QsdkR10fL15ContextArguments $Binding
        $contextEnvironment = Get-QsdkR10fL15ContextEnvironment $expectedContext.ExpectedL15ContextBinding
        foreach ($entry in $contextEnvironment.GetEnumerator()) {
            $environment[$entry.Key] = $entry.Value
            $scrubEnvironmentNames += $entry.Key
        }
    }
    return @{ environment=$environment; scrub_names=$scrubEnvironmentNames }
}

function Invoke-L9ChildProcess {
    param(
        [Parameter(Mandatory)][System.Collections.IDictionary]$Descriptor,
        [Parameter(Mandatory)][System.Collections.IDictionary]$Binding,
        [Parameter(Mandatory)][string]$GodotPath,
        [switch]$RequireL15LaunchRelationship,
        [switch]$RetainR10vCompactEnvelope,
        [switch]$RetainR10wCompactEnvelope,
        [switch]$RetainR10xCompactEnvelope,
        [switch]$RetainR10yCompactEnvelope,
        [switch]$RetainR10aaCompactEnvelope,
        [switch]$RetainR10abCompactEnvelope,
        [switch]$RetainR10apCompactEnvelope,
        [switch]$RetainR10amCompactEnvelope,
        [switch]$RetainR10ajCompactEnvelope,
        [switch]$RetainR10aiCompactEnvelope,
        [switch]$RetainR10agCompactEnvelope,
        [switch]$RetainR10afCompactEnvelope,
        [switch]$RetainR10aeCompactEnvelope,
        [switch]$RetainR10adCompactEnvelope,
        [switch]$RetainR10acCompactEnvelope,
        [switch]$RetainR10zCompactEnvelope,
        [switch]$R10xNativeProcessObservation
    )
    if ($script:RepairId -ceq 'QSDK-R10F-L15') { $RequireL15LaunchRelationship = $true }
    Assert-R10f (([int]$RetainR10vCompactEnvelope.IsPresent + [int]$RetainR10wCompactEnvelope.IsPresent + [int]$RetainR10xCompactEnvelope.IsPresent + [int]$RetainR10yCompactEnvelope.IsPresent + [int]$RetainR10zCompactEnvelope.IsPresent + [int]$RetainR10aaCompactEnvelope.IsPresent + [int]$RetainR10abCompactEnvelope.IsPresent + [int]$RetainR10acCompactEnvelope.IsPresent + [int]$RetainR10adCompactEnvelope.IsPresent + [int]$RetainR10aeCompactEnvelope.IsPresent + [int]$RetainR10afCompactEnvelope.IsPresent + [int]$RetainR10agCompactEnvelope.IsPresent + [int]$RetainR10apCompactEnvelope.IsPresent + [int]$RetainR10amCompactEnvelope.IsPresent + [int]$RetainR10ajCompactEnvelope.IsPresent + [int]$RetainR10aiCompactEnvelope.IsPresent) -le 1) 'COMPACT_ROUTE_AMBIGUOUS'
    if ($RetainR10xCompactEnvelope -or $R10xNativeProcessObservation) {
        Assert-R10f ($RetainR10xCompactEnvelope -and $R10xNativeProcessObservation -and $RequireL15LaunchRelationship -and $script:WorkerResource -ceq 'res://sdk/adapters/godot/gdscript/r10x_campaign_worker_v1.gd') 'R10X_NATIVE_COMPACT_ROUTE_REQUIRED'
    }
    if ((Get-Variable -Name WorkerResource -Scope Script -ValueOnly -ErrorAction SilentlyContinue) -ceq 'res://sdk/adapters/godot/gdscript/r10x_campaign_worker_v1.gd') {
        Assert-R10f ($RetainR10xCompactEnvelope -and $R10xNativeProcessObservation -and $RequireL15LaunchRelationship) 'R10X_NATIVE_OBSERVER_REQUIRED'
    }
    if ($RetainR10wCompactEnvelope) {
        Assert-R10f ($RequireL15LaunchRelationship -and $script:WorkerResource -ceq 'res://sdk/adapters/godot/gdscript/r10w_campaign_worker_v1.gd') 'R10W_COMPACT_ROUTE_REQUIRED'
    }
    if ($RetainR10apCompactEnvelope) {
        Assert-R10f ($RequireL15LaunchRelationship -and $script:WorkerResource -ceq 'res://sdk/adapters/godot/gdscript/r10ap_development_worker_v1.gd') 'R10AP_COMPACT_ROUTE_REQUIRED'
    }
    elseif ($RetainR10amCompactEnvelope) {
        Assert-R10f ($RequireL15LaunchRelationship -and $script:WorkerResource -ceq 'res://sdk/adapters/godot/gdscript/r10am_development_worker_v1.gd') 'R10AM_COMPACT_ROUTE_REQUIRED'
    }
    elseif ($RetainR10ajCompactEnvelope) {
        Assert-R10f ($RequireL15LaunchRelationship -and $script:WorkerResource -ceq 'res://sdk/adapters/godot/gdscript/r10aj_development_worker_v1.gd') 'R10AJ_COMPACT_ROUTE_REQUIRED'
    }
    elseif ($RetainR10aiCompactEnvelope) {
        Assert-R10f ($RequireL15LaunchRelationship -and $script:WorkerResource -ceq 'res://sdk/adapters/godot/gdscript/r10ai_development_worker_v1.gd') 'R10AI_COMPACT_ROUTE_REQUIRED'
    }
    if ($RetainR10agCompactEnvelope) {
        Assert-R10f ($RequireL15LaunchRelationship -and $script:WorkerResource -ceq 'res://sdk/adapters/godot/gdscript/r10ag_development_worker_v1.gd') 'R10AG_COMPACT_ROUTE_REQUIRED'
    }
    if ($RetainR10afCompactEnvelope) {
        Assert-R10f ($RequireL15LaunchRelationship -and $script:WorkerResource -ceq 'res://sdk/adapters/godot/gdscript/r10af_development_worker_v1.gd') 'R10AF_COMPACT_ROUTE_REQUIRED'
    } elseif ($RetainR10aeCompactEnvelope) {
        Assert-R10f ($RequireL15LaunchRelationship -and $script:WorkerResource -ceq 'res://sdk/adapters/godot/gdscript/r10ae_development_worker_v1.gd') 'R10AE_COMPACT_ROUTE_REQUIRED'
    }
    if ($RetainR10adCompactEnvelope) {
        Assert-R10f ($RequireL15LaunchRelationship -and $script:WorkerResource -ceq 'res://sdk/adapters/godot/gdscript/r10ad_development_worker_v1.gd') 'R10AD_COMPACT_ROUTE_REQUIRED'
    }
    if ((Get-Variable -Name WorkerResource -Scope Script -ValueOnly -ErrorAction SilentlyContinue) -ceq 'res://sdk/adapters/godot/gdscript/r10ap_development_worker_v1.gd') {
        Assert-R10f ($RetainR10apCompactEnvelope -and $RequireL15LaunchRelationship) 'R10AP_NATIVE_OBSERVER_REQUIRED'
    }
    elseif ((Get-Variable -Name WorkerResource -Scope Script -ValueOnly -ErrorAction SilentlyContinue) -ceq 'res://sdk/adapters/godot/gdscript/r10am_development_worker_v1.gd') {
        Assert-R10f ($RetainR10amCompactEnvelope -and $RequireL15LaunchRelationship) 'R10AM_NATIVE_OBSERVER_REQUIRED'
    }
    elseif ((Get-Variable -Name WorkerResource -Scope Script -ValueOnly -ErrorAction SilentlyContinue) -ceq 'res://sdk/adapters/godot/gdscript/r10aj_development_worker_v1.gd') {
        Assert-R10f ($RetainR10ajCompactEnvelope -and $RequireL15LaunchRelationship) 'R10AJ_NATIVE_OBSERVER_REQUIRED'
    }
    elseif ((Get-Variable -Name WorkerResource -Scope Script -ValueOnly -ErrorAction SilentlyContinue) -ceq 'res://sdk/adapters/godot/gdscript/r10ai_development_worker_v1.gd') {
        Assert-R10f ($RetainR10aiCompactEnvelope -and $RequireL15LaunchRelationship) 'R10AI_NATIVE_OBSERVER_REQUIRED'
    }
    if ((Get-Variable -Name WorkerResource -Scope Script -ValueOnly -ErrorAction SilentlyContinue) -ceq 'res://sdk/adapters/godot/gdscript/r10ag_development_worker_v1.gd') {
        Assert-R10f ($RetainR10agCompactEnvelope -and $RequireL15LaunchRelationship) 'R10AG_NATIVE_OBSERVER_REQUIRED'
    }
    if ((Get-Variable -Name WorkerResource -Scope Script -ValueOnly -ErrorAction SilentlyContinue) -ceq 'res://sdk/adapters/godot/gdscript/r10af_development_worker_v1.gd') {
        Assert-R10f ($RetainR10afCompactEnvelope -and $RequireL15LaunchRelationship) 'R10AF_NATIVE_OBSERVER_REQUIRED'
    } elseif ((Get-Variable -Name WorkerResource -Scope Script -ValueOnly -ErrorAction SilentlyContinue) -ceq 'res://sdk/adapters/godot/gdscript/r10ae_development_worker_v1.gd') {
        Assert-R10f ($RetainR10aeCompactEnvelope -and $RequireL15LaunchRelationship) 'R10AE_NATIVE_OBSERVER_REQUIRED'
    }
    if ((Get-Variable -Name WorkerResource -Scope Script -ValueOnly -ErrorAction SilentlyContinue) -ceq 'res://sdk/adapters/godot/gdscript/r10ad_development_worker_v1.gd') {
        Assert-R10f ($RetainR10adCompactEnvelope -and $RequireL15LaunchRelationship) 'R10AD_NATIVE_OBSERVER_REQUIRED'
    }
    if ($RetainR10acCompactEnvelope) {
        Assert-R10f ($RequireL15LaunchRelationship -and $script:WorkerResource -ceq 'res://sdk/adapters/godot/gdscript/r10ac_development_worker_v1.gd') 'R10AC_COMPACT_ROUTE_REQUIRED'
    }
    if ((Get-Variable -Name WorkerResource -Scope Script -ValueOnly -ErrorAction SilentlyContinue) -ceq 'res://sdk/adapters/godot/gdscript/r10ac_development_worker_v1.gd') {
        Assert-R10f ($RetainR10acCompactEnvelope -and $RequireL15LaunchRelationship) 'R10AC_NATIVE_OBSERVER_REQUIRED'
    }
    if ($RetainR10abCompactEnvelope) {
        Assert-R10f ($RequireL15LaunchRelationship -and $script:WorkerResource -ceq 'res://sdk/adapters/godot/gdscript/r10ab_development_worker_v1.gd') 'R10AB_COMPACT_ROUTE_REQUIRED'
    }
    if ((Get-Variable -Name WorkerResource -Scope Script -ValueOnly -ErrorAction SilentlyContinue) -ceq 'res://sdk/adapters/godot/gdscript/r10ab_development_worker_v1.gd') {
        Assert-R10f ($RetainR10abCompactEnvelope -and $RequireL15LaunchRelationship) 'R10AB_NATIVE_OBSERVER_REQUIRED'
    }
    if ($RetainR10aaCompactEnvelope) {
        Assert-R10f ($RequireL15LaunchRelationship -and $script:WorkerResource -ceq 'res://sdk/adapters/godot/gdscript/r10aa_development_worker_v1.gd') 'R10AA_COMPACT_ROUTE_REQUIRED'
    }
    if ((Get-Variable -Name WorkerResource -Scope Script -ValueOnly -ErrorAction SilentlyContinue) -ceq 'res://sdk/adapters/godot/gdscript/r10aa_development_worker_v1.gd') {
        Assert-R10f ($RetainR10aaCompactEnvelope -and $RequireL15LaunchRelationship) 'R10AA_NATIVE_OBSERVER_REQUIRED'
    }
    if ($RetainR10zCompactEnvelope) {
        Assert-R10f ($RequireL15LaunchRelationship -and $script:WorkerResource -ceq 'res://sdk/adapters/godot/gdscript/r10z_development_worker_v1.gd') 'R10Z_COMPACT_ROUTE_REQUIRED'
    }
    if ((Get-Variable -Name WorkerResource -Scope Script -ValueOnly -ErrorAction SilentlyContinue) -ceq 'res://sdk/adapters/godot/gdscript/r10z_development_worker_v1.gd') {
        Assert-R10f ($RetainR10zCompactEnvelope -and $RequireL15LaunchRelationship) 'R10Z_NATIVE_OBSERVER_REQUIRED'
    }
    if ($RetainR10yCompactEnvelope) {
        Assert-R10f ($RequireL15LaunchRelationship -and $script:WorkerResource -ceq 'res://sdk/adapters/godot/gdscript/r10y_development_worker_v1.gd') 'R10Y_COMPACT_ROUTE_REQUIRED'
    }
    if ((Get-Variable -Name WorkerResource -Scope Script -ValueOnly -ErrorAction SilentlyContinue) -ceq 'res://sdk/adapters/godot/gdscript/r10y_development_worker_v1.gd') {
        Assert-R10f ($RetainR10yCompactEnvelope -and $RequireL15LaunchRelationship) 'R10Y_NATIVE_OBSERVER_REQUIRED'
    }
    if ($RetainR10vCompactEnvelope) {
        Assert-R10f ($RequireL15LaunchRelationship -and $script:WorkerResource -ceq 'res://sdk/adapters/godot/gdscript/r10v_recovery_worker_v1.gd') 'R10V_COMPACT_ROUTE_REQUIRED'
    }
    # Recheck each serialized child: an image may change after its peer exits.
    if ($RetainR10apCompactEnvelope) {
        . (Join-Path $script:RepoRoot 'sdk/r10ap_host_runtime.ps1')
        Assert-R10apRuntimeBinding $Binding.l14_exact_runtime_images
        $null = Get-R10apRuntimeBinding -Godot $GodotPath
    }
    elseif ($RetainR10amCompactEnvelope) {
        . (Join-Path $script:RepoRoot 'sdk/r10am_host_runtime.ps1')
        Assert-R10amRuntimeBinding $Binding.l14_exact_runtime_images
        $null = Get-R10amRuntimeBinding -Godot $GodotPath
    }
    elseif ($RetainR10ajCompactEnvelope) {
        . (Join-Path $script:RepoRoot 'sdk/r10aj_host_runtime.ps1')
        Assert-R10ajRuntimeBinding $Binding.l14_exact_runtime_images
        $null = Get-R10ajRuntimeBinding -Godot $GodotPath
    }
    elseif ($RetainR10aiCompactEnvelope) {
        . (Join-Path $script:RepoRoot 'sdk/r10ai_host_runtime.ps1')
        Assert-R10aiRuntimeBinding $Binding.l14_exact_runtime_images
        $null = Get-R10aiRuntimeBinding -Godot $GodotPath
    } elseif ($RetainR10agCompactEnvelope) {
        . (Join-Path $script:RepoRoot 'sdk/r10ag_host_runtime.ps1')
        Assert-R10agRuntimeBinding $Binding.l14_exact_runtime_images
        $null = Get-R10agRuntimeBinding -Godot $GodotPath
    } elseif ($RetainR10afCompactEnvelope) {
        . (Join-Path $script:RepoRoot 'sdk/r10af_host_runtime.ps1')
        Assert-R10afRuntimeBinding $Binding.l14_exact_runtime_images
        $null = Get-R10afRuntimeBinding -Godot $GodotPath
    } elseif ($RetainR10aeCompactEnvelope) {
        . (Join-Path $script:RepoRoot 'sdk/r10ae_host_runtime.ps1')
        Assert-R10aeRuntimeBinding $Binding.l14_exact_runtime_images
        $null = Get-R10aeRuntimeBinding -Godot $GodotPath
    }
    elseif ($RetainR10adCompactEnvelope) {
        . (Join-Path $script:RepoRoot 'sdk/r10ad_host_runtime.ps1')
        Assert-R10adRuntimeBinding $Binding.l14_exact_runtime_images
        $null = Get-R10adRuntimeBinding -Godot $GodotPath
    } elseif ($RetainR10acCompactEnvelope) {
        . (Join-Path $script:RepoRoot 'sdk/r10ac_host_runtime.ps1')
        Assert-R10acRuntimeBinding $Binding.l14_exact_runtime_images
        $null = Get-R10acRuntimeBinding -Godot $GodotPath
    } else {
        $null = Get-QsdkR10fL14RuntimeBinding -Godot $GodotPath -ExpectedBinding $Binding.l14_exact_runtime_images
    }
    $childRoot = [IO.Path]::GetFullPath([string]$Descriptor.evidence_path)
    Assert-R10f (Test-Path -LiteralPath $childRoot -PathType Container) (
        "L9_CHILD_EVIDENCE_ROOT_MISSING:" + [string]$Descriptor.role
    )
    $preparedEnvironment = New-QsdkR10fL9ChildEnvironment -Descriptor $Descriptor -Binding $Binding
    $environment = $preparedEnvironment.environment
    $scrubEnvironmentNames = $preparedEnvironment.scrub_names
    $l15LaunchArguments = @{}
    if ($RequireL15LaunchRelationship) {
        $l15LaunchArguments.R10fL15LaunchContext = New-QsdkR10fL15ProductionLaunchContext `
            $script:PhysicalAttemptId $Descriptor $Binding.authority.source_commit `
            $Binding.authority_sha256 $Binding.l14_exact_runtime_images
    }
    # The explicit R10Y route uses the same handle-pinned native observer.
    if ($R10xNativeProcessObservation -or $RetainR10yCompactEnvelope -or $RetainR10zCompactEnvelope -or $RetainR10aaCompactEnvelope -or $RetainR10abCompactEnvelope -or $RetainR10acCompactEnvelope -or $RetainR10adCompactEnvelope -or $RetainR10aeCompactEnvelope -or $RetainR10afCompactEnvelope -or $RetainR10agCompactEnvelope -or $RetainR10apCompactEnvelope -or $RetainR10amCompactEnvelope -or $RetainR10ajCompactEnvelope -or $RetainR10aiCompactEnvelope) { $l15LaunchArguments.R10xNativeProcessObservation = $true }
    $run = Invoke-SporeSporeGodotReceiptTerminatedProcess @l15LaunchArguments `
        -FileName $GodotPath `
        -Arguments @(
            "--headless", "--path", $script:RepoRoot,
            "--script", $script:WorkerResource
        ) `
        -WorkingDirectory $script:RepoRoot `
        -ReadyMarkerPrefix $script:ReadyMarker `
        -ExpectedNonce ([string]$Descriptor.termination_nonce) `
        -Environment $environment `
        -ScrubEnvironmentNames $scrubEnvironmentNames `
        -TimeoutSeconds $TimeoutSeconds

    $stdoutPath = Join-Path $childRoot "worker.stdout.txt"
    $stderrPath = Join-Path $childRoot "worker.stderr.txt"
    $terminationPath = Join-Path $childRoot "termination_receipt.json"
    $engineHealthPath = Join-Path $childRoot "engine_health.json"
    Write-Utf8CreateNew $stdoutPath ([string]$run.stdout)
    Write-Utf8CreateNew $stderrPath ([string]$run.stderr)
    Write-JsonCreateNew $terminationPath $run
    $engineHealth = Get-SporeSporeGodotEngineHealthProjection `
        -StandardError ([string]$run.stderr)
    Write-JsonCreateNew $engineHealthPath $engineHealth
    $raw = Get-OptionalSingleMarkerJson `
        -Stdout ([string]$run.stdout) `
        -Marker $script:RawMarker
    $rawMarkerValid = $null -ne $raw
    $reportBinding = $null
    if ($rawMarkerValid) {
        $reportPath = Join-Path $childRoot "worker_report.json"
        Write-JsonCreateNew $reportPath $raw
        $reportBinding = Get-R10fRetainedFileBinding $reportPath
    }
    $envelope = [ordered]@{
        role = [string]$Descriptor.role
        child_attempt_id = [string]$Descriptor.child_attempt_id
        termination_nonce = [string]$Descriptor.termination_nonce
        evidence_path = $childRoot
        child_retry_count = 0
        child_replacement_count = 0
        started_utc = [string]$run.started_utc
        completed_utc = [string]$run.completed_utc
        process_id = [int]$run.process_id
        worker_process_id = [int]$run.worker_process_id
        exit_code = [int]$run.exit_code
        termination_protocol_valid = [bool]$run.termination_protocol_valid
        engine_health_passed = [bool]$engineHealth.passed
        raw_marker_valid = $rawMarkerValid
        report = $raw
        retained_artifact_bindings = [ordered]@{
            child_attempt_identity = Get-R10fRetainedFileBinding (
                Join-Path $childRoot "child_attempt_identity.json"
            )
            worker_stdout = Get-R10fRetainedFileBinding $stdoutPath
            worker_stderr = Get-R10fRetainedFileBinding $stderrPath
            termination_receipt = Get-R10fRetainedFileBinding $terminationPath
            engine_health = Get-R10fRetainedFileBinding $engineHealthPath
            worker_report = $reportBinding
        }
        physical_acceptance_authority = $false
        release_authority = $false
    }
    if ($RequireL15LaunchRelationship) {
        $envelope.r10f_l15_launch_relationship = $run.r10f_l15_launch_relationship
        $envelope.termination_ready_receipt = $run.termination_ready_receipt
    }
    $script:ObservedChildEnvelopes.Add($envelope)
    if ($RetainR10vCompactEnvelope -or $RetainR10wCompactEnvelope -or $RetainR10xCompactEnvelope -or $RetainR10yCompactEnvelope -or $RetainR10zCompactEnvelope -or $RetainR10aaCompactEnvelope -or $RetainR10abCompactEnvelope -or $RetainR10acCompactEnvelope -or $RetainR10adCompactEnvelope -or $RetainR10aeCompactEnvelope -or $RetainR10afCompactEnvelope -or $RetainR10agCompactEnvelope -or $RetainR10apCompactEnvelope -or $RetainR10amCompactEnvelope -or $RetainR10aiCompactEnvelope) {
        # Reuse the unchanged exact serializer; retain the full original report.
        . (Join-Path $script:RepoRoot 'sdk/r10v_compact_child_retention.ps1')
        $compact = Write-R10vCompactChildEnvelope -Envelope $envelope -ExpectedContext $l15LaunchArguments.R10fL15LaunchContext
        $script:ObservedChildEnvelopes[$script:ObservedChildEnvelopes.Count - 1] = $compact
        return $compact
    }
    elseif ($RetainR10vCompactEnvelope -or $RetainR10wCompactEnvelope -or $RetainR10xCompactEnvelope -or $RetainR10yCompactEnvelope -or $RetainR10zCompactEnvelope -or $RetainR10aaCompactEnvelope -or $RetainR10abCompactEnvelope -or $RetainR10acCompactEnvelope -or $RetainR10adCompactEnvelope -or $RetainR10aeCompactEnvelope -or $RetainR10afCompactEnvelope -or $RetainR10agCompactEnvelope -or $RetainR10ajCompactEnvelope -or $RetainR10aiCompactEnvelope) {
        # Reuse the unchanged exact serializer; retain the full original report.
        . (Join-Path $script:RepoRoot 'sdk/r10v_compact_child_retention.ps1')
        $compact = Write-R10vCompactChildEnvelope -Envelope $envelope -ExpectedContext $l15LaunchArguments.R10fL15LaunchContext
        $script:ObservedChildEnvelopes[$script:ObservedChildEnvelopes.Count - 1] = $compact
        return $compact
    }
    Write-JsonCreateNew (Join-Path $childRoot "child_envelope.json") $envelope
    return $envelope
}


function Write-L9SupervisorResult {
    param(
        [Parameter(Mandatory)][System.Collections.IDictionary]$Population,
        [Parameter(Mandatory)][System.Collections.IDictionary]$Binding,
        [Parameter(Mandatory)][System.Collections.IDictionary]$AttemptIdentity
    )
    $envelopes = [object[]]$script:ObservedChildEnvelopes.ToArray()
    $counts = Get-L9ObservedCounterProjection -ChildEnvelopes $envelopes
    $populationOk = [bool]$Population.ok
    $supervisor = [ordered]@{
        schema_version = "sporespore_qsdk_r10f_l9_physical_supervisor_result_v1"
        gate_id = $script:GateId
        repair_id = $script:RepairId
        campaign_id = $script:CampaignId
        campaign_role = "development_route_ghost"
        question_class = "development"
        ledger_scope = Get-R10fLedgerScope "consumed_physical_campaign_report"
        ok = $populationOk
        status = [string]$Population.status
        evidence_valid = [bool]$Population.evidence_valid
        measurement_complete = [bool]$Population.measurement_complete
        route_execution_valid = [bool]$Population.route_execution_valid
        outcome_complete = [bool]$Population.outcome_complete
        behavior_passed = [bool]$Population.behavior_passed
        scientific_outcome = [string]$Population.scientific_outcome
        failure_code = [string]$Population.failure_code
        source_commit = [string]$Binding.authority.source_commit
        authority_sha256 = [string]$Binding.authority_sha256
        repair_design_sha256 = [string]$Binding.repair_design_sha256
        branch_completeness_addendum_sha256 = [string]$Binding.branch_completeness_addendum_sha256
        consumed_predecessor_physical_closure_sha256 = (
            [string]$Binding.consumed_predecessor_physical_closure_sha256
        )
        attempt_id = $script:PhysicalAttemptId
        attempt_identity_consumed = $true
        same_identity_rerun_permitted = $false
        maximum_campaign_attempt_count = 1
        maximum_child_process_count = 2
        maximum_world_count_per_child = $script:MaximumChildWorldCount
        maximum_total_world_count = $script:MaximumWorldCount
        maximum_solver_step_count_per_child = $script:MaximumChildSolverStepCount
        maximum_total_solver_step_count = $script:MaximumSolverStepCount
        ordered_child_manifest = $AttemptIdentity.ordered_child_manifest
        ordered_child_count = $envelopes.Count
        all_declared_children_present = $envelopes.Count -eq 2
        child_processes_overlap_in_wall_clock_time = if (
            $Population.Contains("process_lifetimes_overlap")
        ) { $Population.process_lifetimes_overlap } else { $null }
        serialized_fresh_processes_valid = if (
            $Population.Contains("serialized_fresh_processes_valid")
        ) { [bool]$Population.serialized_fresh_processes_valid } else { $false }
        child_retry_or_replacement_used = if (
            $Population.Contains("child_retry_or_replacement_used")
        ) { [bool]$Population.child_retry_or_replacement_used } else { $false }
        evaluator_invocation_count = if (
            $Population.Contains("evaluator_invocation_count")
        ) { [int]$Population.evaluator_invocation_count } else { 0 }
        process_population_evaluation = $Population
        child_envelopes = $envelopes
        observed_completed_child_count_fields_known = $counts.core_count_fields_known
        observed_count_field_known = $counts.count_field_known
        model_construction_attempt_count = $counts.model_construction_attempt_count
        model_construction_count = $counts.model_construction_count
        world_attempt_count = $counts.world_attempt_count
        world_build_count = $counts.world_build_count
        solver_step_count = $counts.solver_step_count
        explicit_worker_extra_native_readback_count = (
            $counts.explicit_worker_extra_native_readback_count
        )
        physical_question_opened = $true
        physics_state_modified = $counts.physics_state_modified
        event_triggered_passive_recovery_observed = (
            $populationOk -and [bool]$Population.behavior_passed
        )
        continuous_same_body_recovery_resume_observed = (
            $populationOk -and [bool]$Population.behavior_passed
        )
        force_aware_recovery = $false
        force_aware_bracing = $false
        arbitrary_fall_recovery_claimed = $false
        cross_engine_push_recovery_claimed = $false
        sdk1_m07_satisfied = $false
        operation_lock = Get-SporeSporeLocomotionOperationLockPublicReceipt $lock
        evidence_root = $script:PhysicalAttemptRoot.Replace("\", "/")
        physical_acceptance_authority = $false
        release_authority = $false
    }
    Write-JsonCreateNew (
        Join-Path $script:PhysicalAttemptRoot "supervisor_result.json"
    ) $supervisor
    $script:L15PrimaryReportWriteCompleted = $true
    $script:L15PrimaryReportBinding = Get-R10fRetainedFileBinding (
        Join-Path $script:PhysicalAttemptRoot 'supervisor_result.json'
    )
    # A PowerShell function's success stream is its return channel. Printing
    # here would turn this dictionary into a two-object caller result.
    return $supervisor
}


function Publish-L15SupervisorResult {
    param([Parameter(Mandatory)][System.Collections.IDictionary]$Supervisor)
    Assert-R10f (-not $script:L15PrimaryMarkerPublished) 'L15_PRIMARY_MARKER_ALREADY_PUBLISHED'
    Assert-R10f ($script:L15PrimaryReportWriteCompleted -and
        $null -ne $script:L15PrimaryReportBinding) 'L15_PRIMARY_REPORT_NOT_WRITTEN'
    $actualBinding = Get-R10fRetainedFileBinding (
        Join-Path $script:PhysicalAttemptRoot 'supervisor_result.json'
    )
    Assert-R10f (Test-QsdkR10fL15ExactValue $actualBinding $script:L15PrimaryReportBinding) 'L15_PRIMARY_FILE_CHANGED'
    # Match the writer's exact UTF-8 encoding, not a re-parsed/rounded object.
    # A changed caller dictionary must not publish data other than the file.
    $json = ConvertTo-SporeSporeExactJson -Value $Supervisor -Depth 100 -Indented
    $memoryBinding = Get-QsdkR10fL15TextBinding ($json.Replace("`r`n", "`n") + "`n")
    Assert-R10f ($memoryBinding.byte_length -eq $actualBinding.byte_length -and
        $memoryBinding.raw_sha256 -ceq $actualBinding.raw_sha256) 'L15_PRIMARY_RETURN_FILE_MISMATCH'
    Write-Output ($script:PhysicalMarker + (ConvertTo-SporeSporeExactJson -Value $Supervisor))
    $script:L15PrimaryMarkerPublished = $true
}


function Get-L15PrimaryReportFailureRetention {
    # A later exception can describe the primary, but cannot overwrite it or
    # treat its existence as proof of valid publication or physical success.
    $binding = $null
    $bindingFailure = ''
    $exists = $false
    if ($script:PhysicalAttemptIdentityConsumed -and -not [string]::IsNullOrEmpty($script:PhysicalAttemptRoot)) {
        $primaryPath = Join-Path $script:PhysicalAttemptRoot 'supervisor_result.json'
        $exists = Test-Path -LiteralPath $primaryPath -PathType Leaf
        if ($exists) {
            try { $binding = Get-R10fRetainedFileBinding $primaryPath }
            catch { $bindingFailure = $_.Exception.Message }
        }
    }
    return [ordered]@{
        schema_version = 'sporespore_qsdk_r10f_l15_primary_report_failure_retention_v1'
        ledger_scope = Get-R10fLedgerScope 'development_primary_report_failure_retention'
        primary_file_exists = $exists
        primary_file_binding = $binding
        primary_file_binding_failure = $bindingFailure
        primary_written_binding = $script:L15PrimaryReportBinding
        primary_write_completed = $script:L15PrimaryReportWriteCompleted
        primary_marker_published = $script:L15PrimaryMarkerPublished
        primary_report_replaced = $false
        physical_acceptance_authority = $false
        release_authority = $false
    }
}


function Invoke-Physical {
    Assert-R10f $RunPhysical "PHYSICAL_MODE_REQUIRES_RUNPHYSICAL"
    Assert-R10f (
        [IO.Path]::GetFullPath($EvidenceRoot) -ceq $script:ExpectedEvidenceRoot
    ) "EVIDENCE_ROOT_NOT_EXACT"
    $boundary = Get-SourceBoundary -RequireLiveCleanMain
    $binding = Get-PhysicalAuthority -Path $AuthorizationPath -Boundary $boundary
    $godotPath = [IO.Path]::GetFullPath($Godot)
    Assert-R10f (Test-Path -LiteralPath $godotPath -PathType Leaf) "GODOT_MISSING"
    $null = Get-QsdkR10fL14RuntimeBinding -Godot $godotPath -ExpectedBinding $binding.l14_exact_runtime_images
    $authoritySlug = ([string]$binding.authority_sha256).Substring(7, 16)
    $attemptRoot = Join-Path $script:ExpectedEvidenceRoot (
        "qsdk-r10f-development-route-ghost-" + $authoritySlug
    )
    Assert-R10f (-not (Test-Path -LiteralPath $attemptRoot)) (
        "PHYSICAL_IDENTITY_ALREADY_CONSUMED:" + $attemptRoot
    )

    $parentAttemptId = [Guid]::NewGuid().ToString("N").ToLowerInvariant()
    $childDescriptors = [System.Collections.Generic.List[object]]::new()
    for ($index = 0; $index -lt $script:OrderedChildRoles.Count; $index++) {
        $role = [string]$script:OrderedChildRoles[$index]
        $childSlug = ("{0:D2}-{1}" -f ($index + 1), $role)
        $childDescriptors.Add([ordered]@{
            launch_index = $index + 1
            role = $role
            child_attempt_id = [Guid]::NewGuid().ToString("N").ToLowerInvariant()
            termination_nonce = [Guid]::NewGuid().ToString("N").ToLowerInvariant()
            evidence_path = [IO.Path]::GetFullPath(
                (Join-Path (Join-Path $attemptRoot "children") $childSlug)
            )
            child_retry_count = 0
            child_replacement_count = 0
        })
    }
    Assert-R10f (
        $childDescriptors.Count -eq 2 -and
        [string]$childDescriptors[0].role -ceq $script:OrderedChildRoles[0] -and
        [string]$childDescriptors[1].role -ceq $script:OrderedChildRoles[1] -and
        [string]$childDescriptors[0].child_attempt_id -cne
            [string]$childDescriptors[1].child_attempt_id -and
        [string]$childDescriptors[0].termination_nonce -cne
            [string]$childDescriptors[1].termination_nonce -and
        [string]$childDescriptors[0].evidence_path -cne
            [string]$childDescriptors[1].evidence_path
    ) "L9_CHILD_MANIFEST_DERIVATION_INVALID"

    $null = New-Item -ItemType Directory -Path $attemptRoot
    $script:PhysicalAttemptIdentityConsumed = $true
    $script:PhysicalAttemptRoot = [IO.Path]::GetFullPath($attemptRoot)
    $script:PhysicalAttemptId = $parentAttemptId
    $childrenRoot = Join-Path $script:PhysicalAttemptRoot "children"
    $null = New-Item -ItemType Directory -Path $childrenRoot
    foreach ($descriptor in $childDescriptors) {
        $null = New-Item -ItemType Directory -Path ([string]$descriptor.evidence_path)
    }
    $attempt = [ordered]@{
        schema_version = "sporespore_qsdk_r10f_l9_physical_attempt_identity_v1"
        gate_id = $script:GateId
        repair_id = $script:RepairId
        campaign_id = $script:CampaignId
        campaign_role = "development_route_ghost"
        question_class = "development"
        ledger_scope = Get-R10fLedgerScope "consumed_physical_attempt_identity"
        status = "physical_identity_and_ordered_children_consumed_before_first_child_start"
        source_commit = [string]$binding.authority.source_commit
        authority_sha256 = [string]$binding.authority_sha256
        consumed_predecessor_physical_closure_sha256 = (
            [string]$binding.consumed_predecessor_physical_closure_sha256
        )
        repair_design_sha256 = [string]$binding.repair_design_sha256
        branch_completeness_addendum_sha256 = [string]$binding.branch_completeness_addendum_sha256
        attempt_id = $parentAttemptId
        ordered_child_manifest = [object[]]$childDescriptors.ToArray()
        seed = $script:DevelopmentSeed
        same_identity_rerun_permitted = $false
        child_retry_permitted = $false
        child_replacement_permitted = $false
        maximum_campaign_attempt_count = 1
        maximum_child_process_count = 2
        maximum_world_count_per_child = $script:MaximumChildWorldCount
        maximum_total_world_count = $script:MaximumWorldCount
        maximum_solver_step_count_per_child = $script:MaximumChildSolverStepCount
        maximum_total_solver_step_count = $script:MaximumSolverStepCount
        created_utc = [DateTime]::UtcNow.ToString("o")
        physical_execution_authorized = $true
        physical_acceptance_authority = $false
        release_authority = $false
    }
    Write-JsonCreateNew (Join-Path $script:PhysicalAttemptRoot "attempt_identity.json") $attempt
    foreach ($descriptor in $childDescriptors) {
        $childIdentity = [ordered]@{
            schema_version = "sporespore_qsdk_r10f_l9_child_attempt_identity_v1"
            gate_id = $script:GateId
            repair_id = $script:RepairId
            status = "reserved_and_retained_before_first_child_start"
            parent_attempt_id = $parentAttemptId
            child_attempt_id = [string]$descriptor.child_attempt_id
            launch_index = [int]$descriptor.launch_index
            role = [string]$descriptor.role
            termination_nonce = [string]$descriptor.termination_nonce
            evidence_path = ([string]$descriptor.evidence_path).Replace("\", "/")
            source_commit = [string]$binding.authority.source_commit
            authority_sha256 = [string]$binding.authority_sha256
            child_retry_count = 0
            child_replacement_count = 0
            physical_acceptance_authority = $false
            release_authority = $false
        }
        Write-JsonCreateNew (
            Join-Path ([string]$descriptor.evidence_path) "child_attempt_identity.json"
        ) $childIdentity
    }

    $baseline = Invoke-L9ChildProcess `
        -Descriptor $childDescriptors[0] -Binding $binding -GodotPath $godotPath `
        -RequireL15LaunchRelationship:($script:RepairId -ceq 'QSDK-R10F-L15')
    $l15ContextArguments = @{}
    if ($script:RepairId -ceq 'QSDK-R10F-L15') {
        . (Join-Path $script:RepoRoot 'sdk/qsdk_r10f_l15_context_source.ps1')
        $l15ContextArguments = Get-QsdkR10fL15ContextArguments $binding
    }
    $baselineValidation = Get-L9ChildLaunchValidation `
        -Envelope $baseline -Descriptor $childDescriptors[0] -Binding $binding `
        -RequireL15LaunchRelationship:($script:RepairId -ceq 'QSDK-R10F-L15')
    if (-not [bool]$baselineValidation.ok) {
        $population = Invoke-QsdkR10fL9ProcessPopulationEvaluation @l15ContextArguments `
            -ChildEnvelopes ([object[]]$script:ObservedChildEnvelopes.ToArray()) `
            -ExpectedParentAttemptId $parentAttemptId `
            -ExpectedSourceCommit ([string]$binding.authority.source_commit) `
            -ExpectedAuthoritySha256 ([string]$binding.authority_sha256) `
            -RequireL15LaunchRelationship:($script:RepairId -ceq 'QSDK-R10F-L15') `
            -ExpectedRuntimeBinding $binding.l14_exact_runtime_images `
            -ExpectedChildManifest ([object[]]$childDescriptors.ToArray())
        $supervisor = Write-L9SupervisorResult `
            -Population $population -Binding $binding -AttemptIdentity $attempt
        Publish-L15SupervisorResult -Supervisor $supervisor
        exit 1
    }

    $active = Invoke-L9ChildProcess `
        -Descriptor $childDescriptors[1] -Binding $binding -GodotPath $godotPath `
        -RequireL15LaunchRelationship:($script:RepairId -ceq 'QSDK-R10F-L15')
    $population = Invoke-QsdkR10fL9ProcessPopulationEvaluation @l15ContextArguments `
        -ChildEnvelopes ([object[]]$script:ObservedChildEnvelopes.ToArray()) `
        -ExpectedParentAttemptId $parentAttemptId `
        -ExpectedSourceCommit ([string]$binding.authority.source_commit) `
        -ExpectedAuthoritySha256 ([string]$binding.authority_sha256) `
        -RequireL15LaunchRelationship:($script:RepairId -ceq 'QSDK-R10F-L15') `
        -ExpectedRuntimeBinding $binding.l14_exact_runtime_images `
        -ExpectedChildManifest ([object[]]$childDescriptors.ToArray())
    $supervisor = Write-L9SupervisorResult `
        -Population $population -Binding $binding -AttemptIdentity $attempt
    Publish-L15SupervisorResult -Supervisor $supervisor
    if (-not [bool]$supervisor.ok) { exit 1 }
}


if ($DevelopmentLibrary) {
    # Load the actual launch/publication functions without running a campaign.
    if ($Mode -cne 'Preflight' -or $RunPhysical -or $L15 -or $AuthorizationPath -cne '') {
        throw 'DEVELOPMENT_LIBRARY_EXECUTION_FLAGS_FORBIDDEN'
    }
    return
}

$lock = $null
try {
    if ($L15) {
        Select-L15ProductionFamily
        Assert-R10f ($Mode -ceq 'Physical') 'L15_USE_EXPLICIT_ZERO_WORLD_QUALIFICATION_WRAPPER'
    }
    $role = if ($Mode -ceq "Physical") { "physical_development" } else { "conformance" }
    $lock = Enter-SporeSporeLocomotionOperationLock -Role $role
    Assert-R10f ([bool]$lock.acquired) "LOCOMOTION_OPERATION_LOCK_UNAVAILABLE"
    if ($Mode -ceq "Preflight") {
        Invoke-Preflight
    } else {
        Invoke-Physical
    }
} catch {
    $supervisorError = [string]$_.Exception.Message
    $postAttemptUnknown = [bool]$script:PhysicalAttemptIdentityConsumed
    $observedChildren = [object[]]$script:ObservedChildEnvelopes.ToArray()
    $observedCounts = if ($postAttemptUnknown) {
        Get-L9ObservedCounterProjection -ChildEnvelopes $observedChildren
    } else {
        [ordered]@{
            core_count_fields_known = $true
            model_construction_count = 0
            world_attempt_count = 0
            world_build_count = 0
            solver_step_count = 0
            explicit_worker_extra_native_readback_count = 0
            physics_state_modified = $false
        }
    }
    $refusalLedgerAuthorityMode = if ($postAttemptUnknown) {
        "consumed_physical_supervisor_failure"
    } else {
        "zero_world_supervisor_refusal"
    }
    $receipt = [ordered]@{
        schema_version = "sporespore_qsdk_r10f_supervisor_refusal_v1"
        gate_id = $script:GateId
        repair_id = $script:RepairId
        campaign_id = $script:CampaignId
        campaign_role = "development_route_ghost"
        question_class = "development"
        ledger_scope = Get-R10fLedgerScope $refusalLedgerAuthorityMode
        ok = $false
        mode = $Mode
        failure_code = $supervisorError
        physical_execution_requested = [bool]$RunPhysical
        physical_attempt_identity_consumed = $postAttemptUnknown
        attempt_id = $script:PhysicalAttemptId
        physical_attempt_root = $script:PhysicalAttemptRoot.Replace("\", "/")
        physical_question_opened = $postAttemptUnknown
        observed_completed_child_count = $observedChildren.Count
        observed_child_envelopes = $observedChildren
        count_fields_known = [bool]$observedCounts.core_count_fields_known
        model_construction_count = $observedCounts.model_construction_count
        world_attempt_count = $observedCounts.world_attempt_count
        world_build_count = $observedCounts.world_build_count
        scene_tree_insertion_count = if ($postAttemptUnknown) { -1 } else { 0 }
        native_readback_count = $observedCounts.explicit_worker_extra_native_readback_count
        solver_step_count = $observedCounts.solver_step_count
        physics_state_modified = $observedCounts.physics_state_modified
        physical_acceptance_authority = $false
        release_authority = $false
    }
    if ($script:RepairId -ceq 'QSDK-R10F-L15') {
        $receipt.l15_primary_report_failure_retention = Get-L15PrimaryReportFailureRetention
    }
    if (
        $postAttemptUnknown -and
        (Test-Path -LiteralPath $script:PhysicalAttemptRoot -PathType Container)
    ) {
        $failurePath = Join-Path $script:PhysicalAttemptRoot (
            "terminal_supervisor_failure.json"
        )
        if (-not (Test-Path -LiteralPath $failurePath)) {
            try { Write-JsonCreateNew $failurePath $receipt } catch { }
        }
    }
    Write-Output ($script:RefusalMarker + (ConvertTo-SporeSporeExactJson -Value $receipt -Depth 20))
    exit 1
} finally {
    if ($null -ne $lock -and [bool]$lock.acquired -and -not [bool]$lock.released) {
        Exit-SporeSporeLocomotionOperationLock -Receipt $lock
    }
}
