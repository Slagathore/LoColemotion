#requires -Version 7.5
<# The same production runner serves the development ghost and held-out cells.
Default: complete zero-world checks only. -Run adds the declared fresh worlds.
Held-out execution additionally requires the committed single-use authority. #>
[CmdletBinding()]
param(
    [ValidateSet('development_ghost','held_out_finite_decision')][string]$Mode='development_ghost',
    [switch]$Run,
    [switch]$Library
)
$r10pMode = $Mode
$r10pRun = $Run.IsPresent
$r10pLibrary = $Library.IsPresent
if ($r10pLibrary -and $r10pRun) { throw 'R10P_LIBRARY_CANNOT_RUN' }
. (Join-Path $PSScriptRoot 'run_development_recovery_smoke.ps1') -Library -ProfileSteps -ReuseContextChecks `
    -CandidateProfile 'sdk/development/recovery_candidates/r10p-v55-campaign-v1.json'
$script:WorkerResource = 'res://sdk/adapters/godot/gdscript/r10p_campaign_worker_v1.gd'
$r10pStages = @($stages) + @(
    @{id='r10p_authority_graph';pattern='test_r10p_campaign_authority.py';tests=9},
    @{id='r10p_native_seed_boundary';pattern='test_r10p_campaign_seed.py';tests=3},
    @{id='r10p_worker_boundary';pattern='test_r10p_worker_boundary.py';tests=4},
    @{id='r10p_finite_task';pattern='test_r10p_finite_task_audit.py';tests=8},
    @{id='r10p_campaign_runner';pattern='test_r10p_campaign_runner.py';tests=4},
    @{id='r10p_pair_header';pattern='test_r10p_pair_audit.py';tests=3},
    @{id='r10p_dependency_closure';pattern='test_r10p_dependency_manifest.py';tests=4},
    @{id='r10p_qualification_retention';pattern='test_r10p_qualification.py';tests=4},
    @{id='r10p_closure_adoption';pattern='test_r10p_campaign_closure.py';tests=6},
    @{id='r10p_incomplete_campaign_audit';pattern='test_r10p_campaign_audit.py';tests=4}
)

function Invoke-R10PJson {
    param([string]$Module,[string[]]$Arguments)
    $lines = @(& $pythonPath -B (Join-Path $PSScriptRoot ('conformance/'+$Module+'.py')) @Arguments)
    if ($LASTEXITCODE -ne 0 -or $lines.Count -ne 1) { throw ('R10P_COMPONENT_REFUSED:'+ $Module + ':' + ($lines -join ' ')) }
    $result = ConvertFrom-Json -InputObject $lines[0] -AsHashtable -Depth 100
    if (-not $result.ok) { throw ('R10P_COMPONENT_INVALID:'+ $Module) }
    return $result.result
}

function Get-R10PCells([string]$CampaignMode) {
    return @(Invoke-R10PJson 'r10p_campaign_authority' @('population','--mode',$CampaignMode))
}

function New-R10PPairPlan {
    param([object[]]$Cells,[string]$CampaignAttemptId)
    if ($CampaignAttemptId -cnotmatch '^[0-9a-f]{32}$') { throw 'R10P_CAMPAIGN_ATTEMPT_DOMAIN' }
    $expected = @(Get-R10PCells $(if ($Cells.Count -eq 3) {'development_ghost'} else {'held_out_finite_decision'}))
    if ((ConvertTo-SporeSporeExactJson -Value $Cells) -cne (ConvertTo-SporeSporeExactJson -Value $expected)) { throw 'R10P_EXACT_PLAN_POPULATION' }
    $pairs = [Collections.Generic.List[object]]::new()
    foreach ($seed in @($Cells | ForEach-Object { $_.seed.seed } | Select-Object -Unique)) {
        $id = [Guid]::NewGuid().ToString('N')
        $root = Join-Path $evidenceRoot ('development-recovery-smoke-'+$id)
        $children = @($Cells | Where-Object { $_.seed.seed -eq $seed } | ForEach-Object {
            @{cell_id=$_.cell_id;role=$_.role;campaign_attempt_id=$CampaignAttemptId;child_attempt_id=[Guid]::NewGuid().ToString('N');
              parent_attempt_id=$id;termination_nonce=[Guid]::NewGuid().ToString('N');
              evidence_path=(Join-Path $root ('children/'+$_.role))}
        })
        if ($children.Count -ne $(if ($seed -eq 40743) {1} else {2})) { throw 'R10P_PAIR_POPULATION' }
        $pairs.Add(@{attempt_id=$id;root=$root;seed=($Cells | Where-Object { $_.seed.seed -eq $seed } | Select-Object -First 1).seed;children=$children})
    }
    return $pairs.ToArray()
}

function New-R10PDeclaration {
    param($Pair,$Source,$Runtime,$Expectation,$Context,[object[]]$SafetyStages)
    $value = [ordered]@{
        schema_version='sporespore_development_recovery_candidate_declaration_v1'
        ledger_scope=@{subsystem='recovery';engine_scope='godot_jolt';authority_mode=$Context.mode;question_class=$(if ($Context.mode -eq 'development_ghost') {'development'} else {'finite decision'})}
        attempt_id=$Pair.attempt_id;source_snapshot=$Source;runtime=$Runtime;seed=$Pair.seed.seed
        children=$Pair.children;safety_stages=$SafetyStages;prepared_context_expectation=$Expectation
        maximum_precondition_steps=320;walking_prefix_steps=30;interaction_steps=1;after_interaction_steps=3160
        maximum_steps_per_child=3512;timeout_seconds_per_child=1500;independent_replay_timeout_seconds=900
        telemetry_profile='unchanged_full_per_step_capture';official_qualification=$false
        physical_acceptance_authority=$false;release_authority=$false
        step_cost_profile_id='recovery_step_cost_wall_clock_v1';worker_resource=$script:WorkerResource
        timing_scope='Monotonic wall time; no solver timing or capture changes'
        context_cache_profile_id='recovery_exact_context_checks_v1';context_cache_call_sites=@('epoch_preflight','global_context_validation')
        r10p_campaign=$Context
    }
    $fields = Get-DevelopmentCandidateFields
    foreach ($key in $fields.Keys) {
        if ($key -ne 'ledger_scope' -and -not $key.StartsWith('r10')) { $value[$key]=$fields[$key] }
    }
    $value.development_execution_mode = if ($Pair.children.Count -eq 1) { $candidateSelection.single_mode } else { $candidateSelection.paired_mode }
    $value.coverage_adequacy = $candidateSelection.diagnostic_schedule.coverage_adequacy
    $value.worker_resource = $script:WorkerResource
    return $value
}

if ($r10pLibrary) { return }
$r10pId = [Guid]::NewGuid().ToString('N')
$r10pRoot = Join-Path $evidenceRoot $(if (-not $r10pRun) {'r10p-zero-world-check-'+$r10pId} elseif ($r10pMode -eq 'development_ghost') {'r10p-production-ghost-'+$r10pId} else {'r10p-held-out-finite-decision-v1'})
$r10pLock=$null; $r10pFailure=''; $r10pAudit=$null; $r10pSource=$null; $r10pKey=''; $r10pPhysicalStarted=$false
$r10pOwnRoot=$false
$r10pCompleted=[Collections.Generic.List[object]]::new()
$r10pPairs=@(); $r10pCellFailures=[Collections.Generic.List[object]]::new()
$r10pStarted=[DateTime]::UtcNow.ToString('o')
try {
    $r10pLock = Enter-SporeSporeLocomotionOperationLock -Role $(if (-not $r10pRun) {'conformance'} elseif ($r10pMode -eq 'held_out_finite_decision') {'physical'} else {'physical_development'}) -TimeoutMilliseconds 0
    if (-not $r10pLock.acquired -or $r10pLock.abandoned_owner_recovered) { throw 'R10P_OPERATION_LOCK' }
    $r10pSource = Get-DevelopmentSourceSnapshot
    if ($r10pSource.dirty) { throw 'R10P_REQUIRES_CLEAN_COMMITTED_SOURCE' }
    if ((Invoke-R10PJson 'r10p_campaign_authority' @('repository')).head -cne $r10pSource.head) { throw 'R10P_REPOSITORY_DRIFT' }
    $r10pManifest = Invoke-R10PJson 'r10p_dependency_manifest' @('snapshot')
    $r10pKey = $r10pManifest.production_route_key
    $r10pAuthority=$null
    if ($r10pRun -and $r10pMode -eq 'held_out_finite_decision') {
        $r10pAuthority = Invoke-R10PJson 'r10p_campaign_authority' @('validate')
        $null = Invoke-R10PJson 'r10p_dependency_manifest' @('validate')
    }
    if (Test-Path -LiteralPath $r10pRoot) { throw 'R10P_CAMPAIGN_IDENTITY_ALREADY_CONSUMED' }
    $null = New-Item -ItemType Directory -Path $r10pRoot -ErrorAction Stop
    $r10pOwnRoot=$true
    Write-JsonCreateNew (Join-Path $r10pRoot 'source_manifest.json') $r10pManifest
    $r10pRuntime = Get-QsdkR10fL14RuntimeBinding -Godot $Godot
    if (-not ($r10pRun -and $r10pMode -eq 'held_out_finite_decision')) {
        foreach ($stage in $r10pStages) {
            $stageResult=Invoke-DevelopmentStage $stage $r10pRoot
            $r10pCompleted.Add($stageResult)
            Write-Output ('R10P_STAGE '+(ConvertTo-SporeSporeExactJson -Value $stageResult))
            if (-not $stageResult.passed) { throw ('R10P_SAFETY_GATE_FAILED:'+$stage.id) }
        }
    }
    if ((ConvertTo-SporeSporeExactJson -Value $r10pSource) -cne (ConvertTo-SporeSporeExactJson -Value (Get-DevelopmentSourceSnapshot))) { throw 'R10P_SOURCE_CHANGED_DURING_GATE' }
    if ($r10pRun) {
        # Held-out uses the exact frozen qualification capture; ghost uses its
        # own fresh complete gate. Neither branch synthesizes native context.
        $captureRoot = $r10pRoot
        if ($r10pMode -eq 'held_out_finite_decision') {
            $qualification = Get-Content (Join-Path $repoRoot 'sdk/recovery/r10p_held_out_zero_world_qualification_v1.json') -Raw | ConvertFrom-Json -AsHashtable -Depth 100
            $captureRoot = $qualification.safety_gate_root
        }
        $native = Get-OptionalSingleMarkerJson -Stdout ([IO.File]::ReadAllText((Join-Path $captureRoot 'smoke_native_safety.stdout.log'))) -Marker 'DEVELOPMENT_SMOKE_ZERO_WORLD '
        if ($null -eq $native -or -not $native.ok) { throw 'R10P_NATIVE_CAPTURE_MISSING' }
        $capture=$native.native.l15_prepared_collection_context
        $prepared=ConvertFrom-Json -InputObject $capture.utf8_text -AsHashtable -Depth 100
        $expectation=@{raw_capture_binding=@{utf8_byte_length=$capture.utf8_byte_length;raw_sha256=$capture.raw_sha256};collection_identity=(ConvertFrom-Json -InputObject $prepared.expected_identity.utf8_text -AsHashtable -Depth 100)}
        $cells=Get-R10PCells $r10pMode
        $r10pPairs=@(New-R10PPairPlan $cells $r10pId)
        $claim=@{schema_version='sporespore_r10p_campaign_claim_v1';mode=$r10pMode;attempt_id=$r10pId;source_commit=$r10pSource.head;
                 ledger_scope=@{subsystem='recovery';engine_scope='godot_jolt';authority_mode=$r10pMode;question_class=$(if ($r10pMode -eq 'development_ghost') {'development'} else {'finite decision'})};
                 candidate_profile=$candidateSelection.candidate_profile;production_route_key=$r10pKey;cells=$cells;
                 children=@($r10pPairs | ForEach-Object {$_.children});pairs=$r10pPairs;runtime=$r10pRuntime;
                 physical_acceptance_authority=$false;release_authority=$false}
        $claimPath=Join-Path $r10pRoot 'campaign_claim.json'
        Write-JsonCreateNew $claimPath $claim
        $claimBinding=@{path=$claimPath.Replace('\','/');raw_sha256=(Get-PrefixedSha256 $claimPath)}
        foreach ($pair in $r10pPairs) {
            $null=New-Item -ItemType Directory -Path $pair.root -ErrorAction Stop
            $context=@{schema_version='sporespore_r10p_campaign_child_context_v1';mode=$r10pMode;seed=$pair.seed;source_commit=$r10pSource.head;
                       campaign_attempt_id=$r10pId;candidate_profile=$candidateSelection.candidate_profile;claim_binding=$claimBinding}
            if ($r10pMode -eq 'held_out_finite_decision') {
                $context.authority_binding=@{path='res://sdk/recovery/r10p_held_out_execution_authority_v1.json';raw_sha256=$r10pAuthority.authority_file.raw_sha256}
                $context.preregistration_binding=@{path='res://sdk/recovery/r10p_held_out_preregistration_v1.json';raw_sha256=(Get-PrefixedSha256 (Join-Path $repoRoot 'sdk/recovery/r10p_held_out_preregistration_v1.json'))}
            }
            $declaration=New-R10PDeclaration $pair $r10pSource $r10pRuntime $expectation $context $r10pCompleted.ToArray()
            Write-JsonCreateNew (Join-Path $pair.root 'declaration.json') $declaration
            $script:PhysicalAttemptId=$pair.attempt_id; $script:PhysicalAttemptRoot=$pair.root; $script:RepairId='QSDK-R10F-L15'
            $script:DevelopmentSeed=$pair.seed.seed; $script:DevelopmentSeedLabel=$pair.seed.label; $script:DevelopmentSeedSha256=$pair.seed.sha256
            $binding=@{authority=@{source_commit=$r10pSource.head};authority_sha256=(Get-PrefixedSha256 (Join-Path $pair.root 'declaration.json'));
                       l14_exact_runtime_images=$r10pRuntime;l15_prepared_context_expectation=$expectation}
            foreach ($descriptor in $pair.children) {
                if ((ConvertTo-SporeSporeExactJson -Value $r10pSource) -cne (ConvertTo-SporeSporeExactJson -Value (Get-DevelopmentSourceSnapshot))) { throw 'R10P_SOURCE_CHANGED_BEFORE_CHILD' }
                if ((Invoke-R10PJson 'r10p_dependency_manifest' @('snapshot')).production_route_key -cne $r10pKey) { throw 'R10P_RUNTIME_CHANGED_BEFORE_CHILD' }
                $null=New-Item -ItemType Directory -Path $descriptor.evidence_path -ErrorAction Stop
                Write-JsonCreateNew (Join-Path $descriptor.evidence_path 'child_attempt_identity.json') $descriptor
                Write-JsonCreateNew (Join-Path $descriptor.evidence_path 'campaign_launch_started.json') @{
                    cell_id=$descriptor.cell_id;child_attempt_id=$descriptor.child_attempt_id;
                    source_commit=$r10pSource.head;started_utc=[DateTime]::UtcNow.ToString('o');
                    world_build_count_known=$false;physical_acceptance_authority=$false;release_authority=$false
                }
                Write-Output ('R10P_CHILD_START '+$descriptor.cell_id)
                $r10pPhysicalStarted=$true
                try {
                    $child=Invoke-L9ChildProcess -Descriptor $descriptor -Binding $binding -GodotPath $Godot -RequireL15LaunchRelationship
                    $launchContext=New-QsdkR10fL15ProductionLaunchContext $pair.attempt_id $descriptor $r10pSource.head $binding.authority_sha256 $r10pRuntime
                    $null=Assert-QsdkR10fL15ChildLaunchRelationship $child $launchContext
                    if ($child.exit_code -ne 0 -or -not $child.raw_marker_valid -or -not $child.engine_health_passed) { throw 'R10P_CHILD_INVALID' }
                    Write-Output ('R10P_CHILD_END '+$descriptor.cell_id)
                } catch {
                    $r10pCellFailures.Add(@{cell_id=$descriptor.cell_id;failure=$_.Exception.Message})
                    Write-JsonCreateNew (Join-Path $descriptor.evidence_path 'campaign_launch_failure.json') @{failure=$_.Exception.Message}
                    # Consume and retain every named cell; a failed child is
                    # never retried or substituted. Source drift still aborts.
                }
            }
            foreach ($descriptor in $pair.children) {
                if (Test-Path -LiteralPath (Join-Path $descriptor.evidence_path 'campaign_launch_failure.json')) { continue }
                $replayOutput=@(& $pythonPath -B (Join-Path $PSScriptRoot 'conformance/development_passive_entry_profile.py') (Join-Path $descriptor.evidence_path 'worker_report.json') --run)
                $replayExit=$LASTEXITCODE
                Write-Utf8CreateNew (Join-Path $descriptor.evidence_path 'passive_entry_replay_result.json') (($replayOutput -join "`n")+"`n")
                if ($replayExit -ne 0 -or $replayOutput.Count -ne 1) { $r10pCellFailures.Add(@{cell_id=$descriptor.cell_id;failure='R10P_REPLAY_FAILED'}) }
            }
            $auditOutput=@(& $pythonPath -B (Join-Path $PSScriptRoot 'conformance/r10p_pair_audit.py') $pair.root)
            $auditExit=$LASTEXITCODE
            Write-Utf8CreateNew (Join-Path $pair.root 'independent_audit.stdout.json') (($auditOutput -join "`n")+"`n")
            if ($auditExit -ne 0 -or $auditOutput.Count -ne 1) { $r10pCellFailures.Add(@{pair_id=$pair.attempt_id;failure='R10P_PAIR_AUDIT_FAILED'}) }
        }
        $r10pAudit=Invoke-R10PJson 'r10p_campaign_audit' @($r10pRoot)
        if (-not $r10pAudit.execution_valid -or $r10pCellFailures.Count -gt 0) { throw 'R10P_CAMPAIGN_INVALID' }
    }
    if ((ConvertTo-SporeSporeExactJson -Value $r10pSource) -cne (ConvertTo-SporeSporeExactJson -Value (Get-DevelopmentSourceSnapshot))) { throw 'R10P_SOURCE_CHANGED_BEFORE_PUBLICATION' }
    if ((Invoke-R10PJson 'r10p_dependency_manifest' @('snapshot')).production_route_key -cne $r10pKey) { throw 'R10P_RUNTIME_CHANGED_BEFORE_PUBLICATION' }
} catch { $r10pFailure=$_.Exception.Message } finally {
    if ($null -ne $r10pLock) { Exit-SporeSporeLocomotionOperationLock -Receipt $r10pLock }
}
$receipt=@{schema_version='sporespore_r10p_campaign_supervisor_v1';mode=$r10pMode;attempt_id=$r10pId;
    ledger_scope=@{subsystem='recovery';engine_scope='godot_jolt';authority_mode=$(if ($r10pRun) {$r10pMode} else {'zero_world_component_gate'});question_class=$(if ($r10pMode -eq 'development_ghost') {'development'} else {'finite decision'})};
    ok=($r10pFailure -eq '');failure_code=$r10pFailure;source_snapshot=$r10pSource;production_route_key=$r10pKey;
    safety_stages=$r10pCompleted.ToArray();physical_attempt_started=$r10pPhysicalStarted;pairs=$r10pPairs;run_requested=$r10pRun;
    evidence_root=$r10pRoot.Replace('\','/');
    cell_failures=$r10pCellFailures.ToArray();independent_audit=$r10pAudit;started_utc=$r10pStarted;completed_utc=[DateTime]::UtcNow.ToString('o');
    physical_acceptance_authority=$false;release_authority=$false}
if ($r10pOwnRoot) {
    Write-JsonCreateNew (Join-Path $r10pRoot 'supervisor_result.json') $receipt
    $script:PhysicalAttemptRoot=$r10pRoot
    $script:PhysicalMarker='R10P_CAMPAIGN_COMPLETE '
    $script:L15PrimaryReportBinding=Get-R10fRetainedFileBinding (Join-Path $r10pRoot 'supervisor_result.json')
    $script:L15PrimaryReportWriteCompleted=$true
    $published=@(Publish-L15SupervisorResult $receipt)
    if ($published.Count -ne 1) { throw 'R10P_PUBLICATION_COUNT' }
    Write-Utf8CreateNew (Join-Path $r10pRoot 'published_marker.txt') ($published[0]+"`n")
    Write-Output $published[0]
} else {
    Write-Output ('R10P_CAMPAIGN_REFUSED '+$r10pFailure)
}
if ($r10pFailure) { exit 1 }
