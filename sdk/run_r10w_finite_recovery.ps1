#requires -Version 7.5
<# The same production runner serves the development ghost and held-out cells.
Default: complete zero-world checks only. -Run adds the declared fresh worlds.
Held-out execution additionally requires the committed single-use authority. #>
[CmdletBinding()]
param(
    [ValidateSet('development_ghost','held_out_finite_decision')][string]$Mode='development_ghost',
    [switch]$Run,
    [switch]$Library,
    [string]$HostRequest
)
$r10wHostRequest = $HostRequest
$r10wMode = $Mode
$r10wRun = $Run.IsPresent
$r10wLibrary = $Library.IsPresent
if ($r10wLibrary -and $r10wRun) { throw 'R10W_LIBRARY_CANNOT_RUN' }
. (Join-Path $PSScriptRoot 'run_development_recovery_smoke.ps1') -Library -R10WCampaignLibrary -ProfileSteps -ReuseContextChecks `
    -CandidateProfile 'sdk/development/recovery_candidates/r10w-v56-campaign-v1.json'
$script:WorkerResource = 'res://sdk/adapters/godot/gdscript/r10w_campaign_worker_v1.gd'
$TimeoutSeconds = 1740

$r10wStageContract = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'development/r10w_safety_stage_contract_v1.json') -Raw | ConvertFrom-Json -AsHashtable -Depth 100
$r10wStages = @($r10wStageContract.stages)
. (Join-Path $PSScriptRoot 'r10w_host_progress.ps1')

function Get-R10WLiveHostContext {
    if (-not $r10wHostRequest) { throw 'R10W_OWNED_HOST_REQUIRED' }
    $output=@(& $pythonPath -B (Join-Path $PSScriptRoot 'conformance/r10w_durable_host_v1.py') --context $r10wHostRequest --supervisor-pid $PID)
    if ($LASTEXITCODE -ne 0 -or $output.Count -ne 1) { throw 'R10W_HOST_CONTEXT_REFUSED' }
    $context=$output[0] | ConvertFrom-Json -AsHashtable
    $expectedLane=if ($r10wRun) {'production_campaign'} else {'production_gate'}
    if ($context.lane -cne $expectedLane -or $context.mode -cne $r10wMode) { throw 'R10W_HOST_MODE_CROSSED' }
    return $context
}

function Assert-R10WSourceAndRuntime($Source,[string]$Key) {
    if ((ConvertTo-SporeSporeExactJson -Value $Source) -cne (ConvertTo-SporeSporeExactJson -Value (Get-DevelopmentSourceSnapshot))) { throw 'R10W_SOURCE_CHANGED' }
    if ((Invoke-R10WJson 'r10w_dependency_manifest' @('snapshot')).production_route_key -cne $Key) { throw 'R10W_RUNTIME_CHANGED' }
    $null=Get-R10WLiveHostContext
}

function Invoke-R10WJson {
    param([string]$Module,[string[]]$Arguments)
    $lines = @(& $pythonPath -B (Join-Path $PSScriptRoot ('conformance/'+$Module+'.py')) @Arguments)
    if ($LASTEXITCODE -ne 0 -or $lines.Count -ne 1) { throw ('R10W_COMPONENT_REFUSED:'+ $Module + ':' + ($lines -join ' ')) }
    $result = ConvertFrom-Json -InputObject $lines[0] -AsHashtable -Depth 100
    if (-not $result.ok) { throw ('R10W_COMPONENT_INVALID:'+ $Module) }
    return $result.result
}

function Get-R10WCells([string]$CampaignMode) {
    return @(Invoke-R10WJson 'r10w_campaign_authority' @('population','--mode',$CampaignMode))
}

function New-R10WPairPlan {
    param([object[]]$Cells,[string]$CampaignAttemptId)
    if ($CampaignAttemptId -cnotmatch '^[0-9a-f]{32}$') { throw 'R10W_CAMPAIGN_ATTEMPT_DOMAIN' }
    $expected = @(Get-R10WCells $(if ($Cells.Count -eq 2) {'development_ghost'} else {'held_out_finite_decision'}))
    if ((ConvertTo-SporeSporeExactJson -Value $Cells) -cne (ConvertTo-SporeSporeExactJson -Value $expected)) { throw 'R10W_EXACT_PLAN_POPULATION' }
    $pairs = [Collections.Generic.List[object]]::new()
    foreach ($seed in @($Cells | ForEach-Object { $_.seed.seed } | Select-Object -Unique)) {
        $id = [Guid]::NewGuid().ToString('N')
        $root = Join-Path $evidenceRoot ('development-recovery-smoke-'+$id)
        $children = @($Cells | Where-Object { $_.seed.seed -eq $seed } | ForEach-Object {
            @{cell_id=$_.cell_id;role=$_.role;campaign_attempt_id=$CampaignAttemptId;child_attempt_id=[Guid]::NewGuid().ToString('N');
              parent_attempt_id=$id;termination_nonce=[Guid]::NewGuid().ToString('N');
              evidence_path=(Join-Path $root ('children/'+$_.role))}
        })
        if ($children.Count -ne 2) { throw 'R10W_PAIR_POPULATION' }
        $pairs.Add(@{attempt_id=$id;root=$root;seed=($Cells | Where-Object { $_.seed.seed -eq $seed } | Select-Object -First 1).seed;children=$children})
    }
    return $pairs.ToArray()
}

function New-R10WDeclaration {
    param($Pair,$Source,$Runtime,$Expectation,$Context,[object[]]$SafetyStages,$HostContext=$null)
    $value = [ordered]@{
        schema_version='sporespore_development_recovery_candidate_declaration_v1'
        ledger_scope=@{subsystem='recovery';engine_scope='godot_jolt';authority_mode=$Context.mode;question_class=$(if ($Context.mode -eq 'development_ghost') {'development'} else {'finite decision'})}
        attempt_id=$Pair.attempt_id;source_snapshot=$Source;runtime=$Runtime;seed=$Pair.seed.seed
        children=$Pair.children;safety_stages=$SafetyStages;prepared_context_expectation=$Expectation
        maximum_precondition_steps=320;walking_prefix_steps=30;interaction_steps=1;after_interaction_steps=3400
        maximum_steps_per_child=3752;timeout_seconds_per_child=1740;independent_replay_timeout_seconds=900
        telemetry_profile='unchanged_full_per_step_capture';official_qualification=$false
        physical_acceptance_authority=$false;release_authority=$false
        step_cost_profile_id='recovery_step_cost_wall_clock_v1';worker_resource=$script:WorkerResource
        timing_scope='Monotonic wall time; no solver timing or capture changes'
        context_cache_profile_id='recovery_exact_context_checks_v1';context_cache_call_sites=@('epoch_preflight','global_context_validation')
        r10w_campaign=$Context
    }
    $fields = Get-DevelopmentCandidateFields
    foreach ($key in $fields.Keys) {
        if ($key -ne 'ledger_scope' -and -not $key.StartsWith('r10')) { $value[$key]=$fields[$key] }
    }
    $value.development_execution_mode = if ($Pair.children.Count -eq 1) { $candidateSelection.single_mode } else { $candidateSelection.paired_mode }
    $value.coverage_adequacy = $candidateSelection.candidate.coverage_question
    $value.worker_resource = $script:WorkerResource
    $value.timeout_seconds_per_child = 1740
    if ($null -ne $HostContext) { $value.r10w_host=$HostContext }
    return $value
}

function Invoke-R10WPairChildren {
    param($Pair,$r10wSource,[string]$r10wKey,$r10wRuntime,$Binding)
            foreach ($descriptor in $pair.children) {
                Assert-R10WSourceAndRuntime $r10wSource $r10wKey
                $null=New-Item -ItemType Directory -Path $descriptor.evidence_path -ErrorAction Stop
                Write-JsonCreateNew (Join-Path $descriptor.evidence_path 'child_attempt_identity.json') $descriptor
                Write-JsonCreateNew (Join-Path $descriptor.evidence_path 'campaign_launch_started.json') @{
                    cell_id=$descriptor.cell_id;child_attempt_id=$descriptor.child_attempt_id;
                    source_commit=$r10wSource.head;started_utc=[DateTime]::UtcNow.ToString('o');
                    world_build_count_known=$false;physical_acceptance_authority=$false;release_authority=$false
                }
                Write-R10WHostProgress -Stage child -State start -Role $descriptor.cell_id -Subject $descriptor
                Write-Output ('R10W_CHILD_START '+$descriptor.cell_id)
                $script:r10wPhysicalStarted=$true
                try {
                    $child=Invoke-L9ChildProcess -Descriptor $descriptor -Binding $binding -GodotPath $Godot -RequireL15LaunchRelationship -RetainR10wCompactEnvelope
                    $launchContext=New-QsdkR10fL15ProductionLaunchContext $pair.attempt_id $descriptor $r10wSource.head $binding.authority_sha256 $r10wRuntime
                    $null=Assert-QsdkR10fL15ChildLaunchRelationship $child $launchContext
                    if ($child.exit_code -ne 0 -or -not $child.raw_marker_valid -or -not $child.engine_health_passed) { throw 'R10W_CHILD_INVALID' }
                    Write-R10WHostProgress -Stage child -State end -Role $descriptor.cell_id -Subject @{child_attempt_id=$child.child_attempt_id;exit_code=$child.exit_code;envelope=$child.retained_envelope_binding;launch_relationship=$child.r10f_l15_launch_relationship}
                    Write-Output ('R10W_CHILD_END '+$descriptor.cell_id)
                    $child=$null
                } catch {
                    $r10wCellFailures.Add(@{cell_id=$descriptor.cell_id;failure=$_.Exception.Message})
                    Write-JsonCreateNew (Join-Path $descriptor.evidence_path 'campaign_launch_failure.json') @{failure=$_.Exception.Message}
                    # Failed ownership/serialization is infrastructure-invalid. Stop
                    # opening worlds; all planned remaining cells stay unopened.
                    throw
                }
            }

}

function Invoke-R10WPairPostprocess {
    param($Pair)
            foreach ($descriptor in $pair.children) {
                if (Test-Path -LiteralPath (Join-Path $descriptor.evidence_path 'campaign_launch_failure.json')) { continue }
                $process=Invoke-R10WHostPython -Arguments @((Join-Path $PSScriptRoot 'conformance/development_passive_entry_profile.py'),(Join-Path $descriptor.evidence_path 'worker_report.json'),'--run') -Stage replay -Role $descriptor.cell_id -OutputBase (Join-Path $descriptor.evidence_path 'host_replay') -TimeoutSeconds 960
                $replayOutput=$process.output; $replayExit=$process.exit_code
                Write-Utf8CreateNew (Join-Path $descriptor.evidence_path 'passive_entry_replay_result.json') (($replayOutput -join "`n")+"`n")
                if ($replayExit -ne 0 -or $replayOutput.Count -ne 1) { $r10wCellFailures.Add(@{cell_id=$descriptor.cell_id;failure='R10W_REPLAY_FAILED'}) }
            }
            $process=Invoke-R10WHostPython -Arguments @((Join-Path $PSScriptRoot 'conformance/r10w_pair_audit.py'),$pair.root) -Stage pair_audit -Role ([string]$pair.seed.seed) -OutputBase (Join-Path $pair.root 'host_pair_audit') -TimeoutSeconds 1800
            $auditOutput=$process.output; $auditExit=$process.exit_code
            Write-Utf8CreateNew (Join-Path $pair.root 'independent_audit.stdout.json') (($auditOutput -join "`n")+"`n")
            if ($auditExit -ne 0 -or $auditOutput.Count -ne 1) { $r10wCellFailures.Add(@{pair_id=$pair.attempt_id;failure='R10W_PAIR_AUDIT_FAILED'}) }
}

function Invoke-R10WCampaignAudit([string]$Root) {
    $process=Invoke-R10WHostPython -Arguments @((Join-Path $PSScriptRoot 'conformance/r10w_campaign_audit.py'),$Root) -Stage campaign_audit -Role '' -OutputBase (Join-Path $Root 'host_campaign_audit') -TimeoutSeconds 1800
    if ($process.exit_code -ne 0 -or $process.output.Count -ne 1) { throw 'R10W_CAMPAIGN_AUDIT_FAILED' }
    $audited=$process.output[0] | ConvertFrom-Json -AsHashtable -Depth 100
    if (-not $audited.ok) { throw 'R10W_CAMPAIGN_AUDIT_REFUSED' }
    return $audited.result
}

if ($r10wLibrary) { return }
# Establish live kill-on-close ownership before acquiring the lock or creating
# any campaign directory. Direct invocation cannot open a world.
$r10wHostContext=Get-R10WLiveHostContext
Initialize-R10WHostProgress -RequestPath $r10wHostRequest -Context $r10wHostContext
$r10wHostValue=Get-Content -LiteralPath $r10wHostRequest -Raw | ConvertFrom-Json -AsHashtable
$r10wId = $r10wHostContext.attempt_id
$r10wRoot = Join-Path $evidenceRoot $(if (-not $r10wRun) {'r10w-zero-world-check-'+$r10wId} elseif ($r10wMode -eq 'development_ghost') {'r10w-production-ghost-'+$r10wId} else {'r10w-held-out-finite-decision-v1'})
$r10wLock=$null; $r10wFailure=''; $r10wAudit=$null; $r10wSource=$null; $r10wKey=''; $r10wPhysicalStarted=$false
$r10wOwnRoot=$false; $r10wAuditAttempted=$false
$r10wCompleted=[Collections.Generic.List[object]]::new()
$r10wPairs=@(); $r10wCellFailures=[Collections.Generic.List[object]]::new()
$r10wStarted=[DateTime]::UtcNow.ToString('o')
try {
    $r10wLock = Enter-SporeSporeLocomotionOperationLock -Role $(if (-not $r10wRun) {'conformance'} elseif ($r10wMode -eq 'held_out_finite_decision') {'physical'} else {'physical_development'}) -TimeoutMilliseconds 0
    if (-not $r10wLock.acquired -or $r10wLock.abandoned_owner_recovered) { throw 'R10W_OPERATION_LOCK' }
    $r10wSource = Get-DevelopmentSourceSnapshot
    if ($r10wSource.dirty) { throw 'R10W_REQUIRES_CLEAN_COMMITTED_SOURCE' }
    if ((Invoke-R10WJson 'r10w_campaign_authority' @('repository')).head -cne $r10wSource.head) { throw 'R10W_REPOSITORY_DRIFT' }
    $r10wManifest = Invoke-R10WJson 'r10w_dependency_manifest' @('snapshot')
    $r10wKey = $r10wManifest.production_route_key
    $r10wAuthority=$null
    if ($r10wRun -and $r10wMode -eq 'held_out_finite_decision') {
        $r10wAuthority = Invoke-R10WJson 'r10w_campaign_authority' @('validate')
        $null = Invoke-R10WJson 'r10w_dependency_manifest' @('validate')
    }
    if (Test-Path -LiteralPath $r10wRoot) { throw 'R10W_CAMPAIGN_IDENTITY_ALREADY_CONSUMED' }
    $null = New-Item -ItemType Directory -Path $r10wRoot -ErrorAction Stop
    $r10wOwnRoot=$true
    Write-JsonCreateNew (Join-Path $r10wRoot 'source_manifest.json') $r10wManifest
    $r10wRuntime = Get-QsdkR10fL14RuntimeBinding -Godot $Godot
    Write-R10WHostProgress -Stage safety_gate -State start
    if ($r10wRun -and $r10wMode -eq 'held_out_finite_decision') {
        # Authority validation above independently verified the original complete gate.
        $qualification=Get-Content -LiteralPath (Join-Path $repoRoot 'sdk/recovery/r10w_held_out_zero_world_qualification_v1.json') -Raw | ConvertFrom-Json -AsHashtable -Depth 100
        $captureRoot=$qualification.safety_gate_root
        $frozenGate=Get-Content -LiteralPath (Join-Path $captureRoot 'supervisor_result.json') -Raw | ConvertFrom-Json -AsHashtable -Depth 100
        foreach ($stageResult in $frozenGate.safety_stages) { $r10wCompleted.Add($stageResult) }
    } else {
        $null=Invoke-R10WJson 'r10w_safety_gate' @()
        if ($r10wStageContract.additional_required_controls.Count -ne 0) { throw 'R10W_INTEGRATION_CONTROLS_PENDING' }
        foreach ($stage in $r10wStages) {
            if ($stage.id -in $r10wStageContract.prehost_stage_ids) { continue }
            $stage.tests=[int]$stage.tests; $stage.timeout_seconds=[int]$stage.timeout_seconds
            $stageResult=Invoke-DevelopmentStage $stage $r10wRoot
            $r10wCompleted.Add($stageResult)
            Write-Output ('R10W_STAGE '+(ConvertTo-SporeSporeExactJson -Value $stageResult))
            if (-not $stageResult.passed) { throw ('R10W_SAFETY_GATE_FAILED:'+$stage.id) }
        }
        $import=@(& $pythonPath -B (Join-Path $PSScriptRoot 'conformance/r10w_prehost_qualification.py') --import-stages $r10wHostValue.prehost_qualification.path --target $r10wRoot)
        if ($LASTEXITCODE -ne 0 -or $import.Count -ne 1) { throw 'R10W_PREHOST_IMPORT_REFUSED' }
        $imported=$import[0] | ConvertFrom-Json -AsHashtable -Depth 100
        foreach ($stageResult in $imported.stages) { $r10wCompleted.Add($stageResult) }
        $captureRoot=$r10wRoot
    }
    Write-JsonCreateNew (Join-Path $r10wRoot 'safety_stages.json') $r10wCompleted.ToArray()
    $safety=Invoke-R10WJson 'r10w_safety_gate' @('--root',$captureRoot,'--stages',(Join-Path $r10wRoot 'safety_stages.json'))
    Write-R10WHostProgress -Stage safety_gate -State end -Subject $safety
    if ((ConvertTo-SporeSporeExactJson -Value $r10wSource) -cne (ConvertTo-SporeSporeExactJson -Value (Get-DevelopmentSourceSnapshot))) { throw 'R10W_SOURCE_CHANGED_DURING_GATE' }
    if ($r10wRun) {
        # Held-out uses the exact frozen qualification capture; ghost uses its
        # own fresh complete gate. Neither branch synthesizes native context.
        $captureRoot = $r10wRoot
        if ($r10wMode -eq 'held_out_finite_decision') {
            $qualification = Get-Content (Join-Path $repoRoot 'sdk/recovery/r10w_held_out_zero_world_qualification_v1.json') -Raw | ConvertFrom-Json -AsHashtable -Depth 100
            $captureRoot = $qualification.safety_gate_root
        }
        $native = Get-OptionalSingleMarkerJson -Stdout ([IO.File]::ReadAllText((Join-Path $captureRoot 'smoke_native_safety.stdout.log'))) -Marker 'DEVELOPMENT_SMOKE_ZERO_WORLD '
        if ($null -eq $native -or -not $native.ok) { throw 'R10W_NATIVE_CAPTURE_MISSING' }
        $capture=$native.native.l15_prepared_collection_context
        $prepared=ConvertFrom-Json -InputObject $capture.utf8_text -AsHashtable -Depth 100
        $expectation=@{raw_capture_binding=@{utf8_byte_length=$capture.utf8_byte_length;raw_sha256=$capture.raw_sha256};collection_identity=(ConvertFrom-Json -InputObject $prepared.expected_identity.utf8_text -AsHashtable -Depth 100)}
        if ($r10wMode -eq 'development_ghost' -and @(Get-ChildItem -LiteralPath $evidenceRoot -Directory -Filter 'r10w-production-ghost-*' | Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName 'campaign_claim.json') }).Count -gt 0) { throw 'R10W_GHOST_POPULATION_CONSUMED' }
        $cells=Get-R10WCells $r10wMode
        $r10wPairs=@(New-R10WPairPlan $cells $r10wId)
        $claim=@{schema_version='sporespore_r10w_campaign_claim_v1';mode=$r10wMode;attempt_id=$r10wId;source_commit=$r10wSource.head;
                 ledger_scope=@{subsystem='recovery';engine_scope='godot_jolt';authority_mode=$r10wMode;question_class=$(if ($r10wMode -eq 'development_ghost') {'development'} else {'finite decision'})};
                 candidate_profile=$candidateSelection.candidate_profile;production_route_key=$r10wKey;cells=$cells;
                 children=@($r10wPairs | ForEach-Object {$_.children});pairs=$r10wPairs;runtime=$r10wRuntime;
                 physical_acceptance_authority=$false;release_authority=$false}
        $claimPath=Join-Path $r10wRoot 'campaign_claim.json'
        Write-JsonCreateNew $claimPath $claim
        $claimBinding=@{path=$claimPath.Replace('\','/');raw_sha256=(Get-PrefixedSha256 $claimPath)}
        foreach ($pair in $r10wPairs) {
            $null=New-Item -ItemType Directory -Path $pair.root -ErrorAction Stop
            $context=@{schema_version='sporespore_r10w_campaign_child_context_v1';mode=$r10wMode;seed=$pair.seed;source_commit=$r10wSource.head;
                       campaign_attempt_id=$r10wId;candidate_profile=$candidateSelection.candidate_profile;claim_binding=$claimBinding}
            if ($r10wMode -eq 'held_out_finite_decision') {
                $context.authority_binding=@{path='res://sdk/recovery/r10w_held_out_execution_authority_v1.json';raw_sha256=$r10wAuthority.authority_file.raw_sha256}
                $context.preregistration_binding=@{path='res://sdk/recovery/r10w_held_out_preregistration_v1.json';raw_sha256=(Get-PrefixedSha256 (Join-Path $repoRoot 'sdk/recovery/r10w_held_out_preregistration_v1.json'))}
            }
            $declaration=New-R10WDeclaration $pair $r10wSource $r10wRuntime $expectation $context $r10wCompleted.ToArray() $r10wHostContext
            Write-JsonCreateNew (Join-Path $pair.root 'declaration.json') $declaration
            $script:PhysicalAttemptId=$pair.attempt_id; $script:PhysicalAttemptRoot=$pair.root; $script:RepairId='QSDK-R10F-L15'
            $script:DevelopmentSeed=$pair.seed.seed; $script:DevelopmentSeedLabel=$pair.seed.label; $script:DevelopmentSeedSha256=$pair.seed.sha256
            $binding=@{authority=@{source_commit=$r10wSource.head};authority_sha256=(Get-PrefixedSha256 (Join-Path $pair.root 'declaration.json'));
                       l14_exact_runtime_images=$r10wRuntime;l15_prepared_context_expectation=$expectation}
            Invoke-R10WPairChildren $pair $r10wSource $r10wKey $r10wRuntime $binding
            Invoke-R10WPairPostprocess $pair
        }
        $r10wAuditAttempted=$true
        $r10wAudit=Invoke-R10WCampaignAudit $r10wRoot
        if (-not $r10wAudit.execution_valid -or $r10wCellFailures.Count -gt 0) { throw 'R10W_CAMPAIGN_INVALID' }
    }
    if ((ConvertTo-SporeSporeExactJson -Value $r10wSource) -cne (ConvertTo-SporeSporeExactJson -Value (Get-DevelopmentSourceSnapshot))) { throw 'R10W_SOURCE_CHANGED_BEFORE_PUBLICATION' }
    if ((Invoke-R10WJson 'r10w_dependency_manifest' @('snapshot')).production_route_key -cne $r10wKey) { throw 'R10W_RUNTIME_CHANGED_BEFORE_PUBLICATION' }
 } catch {
    $r10wFailure=$_.Exception.Message
    # One original read-only audit accounts for invalid and unopened cells too.
    # Never retry an audit that has already started or reauthorize changed source.
    if ($r10wOwnRoot -and -not $r10wAuditAttempted -and (Test-Path -LiteralPath (Join-Path $r10wRoot 'campaign_claim.json'))) {
        try {
            Assert-R10WSourceAndRuntime $r10wSource $r10wKey
            $r10wAuditAttempted=$true
            $r10wAudit=Invoke-R10WCampaignAudit $r10wRoot
        } catch {
            Write-JsonCreateNew (Join-Path $r10wRoot 'campaign_audit_failure.json') @{failure=$_.Exception.Message;original_failure=$r10wFailure;retry_authorized=$false}
        }
    }
} finally {
    if ($null -ne $r10wLock) { Exit-SporeSporeLocomotionOperationLock -Receipt $r10wLock }
}
$receipt=@{schema_version='sporespore_r10w_campaign_supervisor_v1';mode=$r10wMode;attempt_id=$r10wId;
    ledger_scope=@{subsystem='recovery';engine_scope='godot_jolt';authority_mode=$(if ($r10wRun) {$r10wMode} else {'zero_world_component_gate'});question_class=$(if ($r10wMode -eq 'development_ghost') {'development'} else {'finite decision'})};
    ok=($r10wFailure -eq '');failure_code=$r10wFailure;source_snapshot=$r10wSource;production_route_key=$r10wKey;
    safety_stages=$r10wCompleted.ToArray();physical_attempt_started=$r10wPhysicalStarted;pairs=$r10wPairs;run_requested=$r10wRun;
    r10w_host=$r10wHostContext;prehost_qualification=$r10wHostValue.prehost_qualification;
    evidence_root=$r10wRoot.Replace('\','/');
    cell_failures=$r10wCellFailures.ToArray();independent_audit=$r10wAudit;started_utc=$r10wStarted;completed_utc=[DateTime]::UtcNow.ToString('o');
    physical_acceptance_authority=$false;release_authority=$false}
if ($r10wOwnRoot) {
    Write-R10WHostProgress -Stage publication -State start
    Write-JsonCreateNew (Join-Path $r10wRoot 'supervisor_result.json') $receipt
    $script:PhysicalAttemptRoot=$r10wRoot
    $script:PhysicalMarker='R10W_CAMPAIGN_COMPLETE '
    $script:L15PrimaryReportBinding=Get-R10fRetainedFileBinding (Join-Path $r10wRoot 'supervisor_result.json')
    $script:L15PrimaryReportWriteCompleted=$true
    $published=@(Publish-L15SupervisorResult $receipt)
    if ($published.Count -ne 1) { throw 'R10W_PUBLICATION_COUNT' }
    Write-Utf8CreateNew (Join-Path $r10wRoot 'published_marker.txt') ($published[0]+"`n")
    Write-R10WHostProgress -Stage publication -State end -Subject @{terminal=(Get-R10fRetainedFileBinding (Join-Path $r10wRoot 'supervisor_result.json'));marker=(Get-R10fRetainedFileBinding (Join-Path $r10wRoot 'published_marker.txt'))}
    Write-Output $published[0]
} else {
    Write-Output ('R10W_CAMPAIGN_REFUSED '+$r10wFailure)
}
if ($r10wFailure) { exit 1 }
