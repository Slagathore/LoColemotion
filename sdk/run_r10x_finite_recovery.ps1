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
$r10xHostRequest = $HostRequest
$r10xMode = $Mode
$r10xRun = $Run.IsPresent
$r10xLibrary = $Library.IsPresent
if ($r10xLibrary -and $r10xRun) { throw 'R10X_LIBRARY_CANNOT_RUN' }
. (Join-Path $PSScriptRoot 'run_development_recovery_smoke.ps1') -Library -R10XCampaignLibrary -ProfileSteps -ReuseContextChecks `
    -CandidateProfile 'sdk/development/recovery_candidates/r10x-v56-campaign-v1.json'
$script:WorkerResource = 'res://sdk/adapters/godot/gdscript/r10x_campaign_worker_v1.gd'
$TimeoutSeconds = 1740

$r10xStageContract = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'development/r10x_safety_stage_contract_v1.json') -Raw | ConvertFrom-Json -AsHashtable -Depth 100
$r10xStages = @($r10xStageContract.stages)
. (Join-Path $PSScriptRoot 'r10x_host_progress.ps1')

function Get-R10XLiveHostContext {
    if (-not $r10xHostRequest) { throw 'R10X_OWNED_HOST_REQUIRED' }
    $output=@(& $pythonPath -B (Join-Path $PSScriptRoot 'conformance/r10x_durable_host_v1.py') --context $r10xHostRequest --supervisor-pid $PID)
    if ($LASTEXITCODE -ne 0 -or $output.Count -ne 1) { throw 'R10X_HOST_CONTEXT_REFUSED' }
    $context=$output[0] | ConvertFrom-Json -AsHashtable
    $expectedLane=if ($r10xRun) {'production_campaign'} else {'production_gate'}
    if ($context.lane -cne $expectedLane -or $context.mode -cne $r10xMode) { throw 'R10X_HOST_MODE_CROSSED' }
    return $context
}

function Assert-R10XSourceAndRuntime($Source,[string]$Key) {
    if ((ConvertTo-SporeSporeExactJson -Value $Source) -cne (ConvertTo-SporeSporeExactJson -Value (Get-DevelopmentSourceSnapshot))) { throw 'R10X_SOURCE_CHANGED' }
    if ((Invoke-R10XJson 'r10x_dependency_manifest' @('snapshot')).production_route_key -cne $Key) { throw 'R10X_RUNTIME_CHANGED' }
    $null=Get-R10XLiveHostContext
}

function Invoke-R10XJson {
    param([string]$Module,[string[]]$Arguments)
    $lines = @(& $pythonPath -B (Join-Path $PSScriptRoot ('conformance/'+$Module+'.py')) @Arguments)
    if ($LASTEXITCODE -ne 0 -or $lines.Count -ne 1) { throw ('R10X_COMPONENT_REFUSED:'+ $Module + ':' + ($lines -join ' ')) }
    $result = ConvertFrom-Json -InputObject $lines[0] -AsHashtable -Depth 100
    if (-not $result.ok) { throw ('R10X_COMPONENT_INVALID:'+ $Module) }
    return $result.result
}

function Get-R10XCells([string]$CampaignMode) {
    return @(Invoke-R10XJson 'r10x_campaign_authority' @('population','--mode',$CampaignMode))
}

function New-R10XPairPlan {
    param([object[]]$Cells,[string]$CampaignAttemptId)
    if ($CampaignAttemptId -cnotmatch '^[0-9a-f]{32}$') { throw 'R10X_CAMPAIGN_ATTEMPT_DOMAIN' }
    $expected = @(Get-R10XCells $(if ($Cells.Count -eq 2) {'development_ghost'} else {'held_out_finite_decision'}))
    if ((ConvertTo-SporeSporeExactJson -Value $Cells) -cne (ConvertTo-SporeSporeExactJson -Value $expected)) { throw 'R10X_EXACT_PLAN_POPULATION' }
    $pairs = [Collections.Generic.List[object]]::new()
    foreach ($seed in @($Cells | ForEach-Object { $_.seed.seed } | Select-Object -Unique)) {
        $id = [Guid]::NewGuid().ToString('N')
        $root = Join-Path $evidenceRoot ('development-recovery-smoke-'+$id)
        $children = @($Cells | Where-Object { $_.seed.seed -eq $seed } | ForEach-Object {
            @{cell_id=$_.cell_id;role=$_.role;campaign_attempt_id=$CampaignAttemptId;child_attempt_id=[Guid]::NewGuid().ToString('N');
              parent_attempt_id=$id;termination_nonce=[Guid]::NewGuid().ToString('N');
              evidence_path=(Join-Path $root ('children/'+$_.role))}
        })
        if ($children.Count -ne 2) { throw 'R10X_PAIR_POPULATION' }
        $pairs.Add(@{attempt_id=$id;root=$root;seed=($Cells | Where-Object { $_.seed.seed -eq $seed } | Select-Object -First 1).seed;children=$children})
    }
    return $pairs.ToArray()
}

function New-R10XDeclaration {
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
        process_observation=@{profile_id='r10x_native_process_observation_v1';explicit_selection=$true;l15_context_required=$true;cim_fallback_permitted=$false}
        r10x_campaign=$Context
    }
    $fields = Get-DevelopmentCandidateFields
    foreach ($key in $fields.Keys) {
        if ($key -ne 'ledger_scope' -and -not $key.StartsWith('r10')) { $value[$key]=$fields[$key] }
    }
    $value.development_execution_mode = if ($Pair.children.Count -eq 1) { $candidateSelection.single_mode } else { $candidateSelection.paired_mode }
    $value.coverage_adequacy = $candidateSelection.candidate.coverage_question
    $value.worker_resource = $script:WorkerResource
    $value.timeout_seconds_per_child = 1740
    if ($null -ne $HostContext) { $value.r10x_host=$HostContext }
    return $value
}

function Invoke-R10XPairChildren {
    param($Pair,$r10xSource,[string]$r10xKey,$r10xRuntime,$Binding)
            foreach ($descriptor in $pair.children) {
                Assert-R10XSourceAndRuntime $r10xSource $r10xKey
                $null=New-Item -ItemType Directory -Path $descriptor.evidence_path -ErrorAction Stop
                Write-JsonCreateNew (Join-Path $descriptor.evidence_path 'child_attempt_identity.json') $descriptor
                Write-JsonCreateNew (Join-Path $descriptor.evidence_path 'campaign_launch_started.json') @{
                    cell_id=$descriptor.cell_id;child_attempt_id=$descriptor.child_attempt_id;
                    source_commit=$r10xSource.head;started_utc=[DateTime]::UtcNow.ToString('o');
                    world_build_count_known=$false;physical_acceptance_authority=$false;release_authority=$false
                }
                Write-R10XHostProgress -Stage child -State start -Role $descriptor.cell_id -Subject $descriptor
                Write-Output ('R10X_CHILD_START '+$descriptor.cell_id)
                $script:r10xPhysicalStarted=$true
                try {
                    $child=Invoke-L9ChildProcess -Descriptor $descriptor -Binding $binding -GodotPath $Godot -RequireL15LaunchRelationship -RetainR10xCompactEnvelope -R10xNativeProcessObservation
                    $launchContext=New-QsdkR10fL15ProductionLaunchContext $pair.attempt_id $descriptor $r10xSource.head $binding.authority_sha256 $r10xRuntime
                    $null=Assert-QsdkR10fL15ChildLaunchRelationship $child $launchContext
                    if ($child.exit_code -ne 0 -or -not $child.raw_marker_valid -or -not $child.engine_health_passed) { throw 'R10X_CHILD_INVALID' }
                    Write-R10XHostProgress -Stage child -State end -Role $descriptor.cell_id -Subject @{child_attempt_id=$child.child_attempt_id;exit_code=$child.exit_code;envelope=$child.retained_envelope_binding;launch_relationship=$child.r10f_l15_launch_relationship}
                    Write-Output ('R10X_CHILD_END '+$descriptor.cell_id)
                    $child=$null
                } catch {
                    $r10xCellFailures.Add(@{cell_id=$descriptor.cell_id;failure=$_.Exception.Message})
                    Write-JsonCreateNew (Join-Path $descriptor.evidence_path 'campaign_launch_failure.json') @{failure=$_.Exception.Message}
                    # Failed ownership/serialization is infrastructure-invalid. Stop
                    # opening worlds; all planned remaining cells stay unopened.
                    throw
                }
            }

}

function Invoke-R10XPairPostprocess {
    param($Pair)
            foreach ($descriptor in $pair.children) {
                if (Test-Path -LiteralPath (Join-Path $descriptor.evidence_path 'campaign_launch_failure.json')) { continue }
                $process=Invoke-R10XHostPython -Arguments @((Join-Path $PSScriptRoot 'conformance/development_passive_entry_profile.py'),(Join-Path $descriptor.evidence_path 'worker_report.json'),'--run') -Stage replay -Role $descriptor.cell_id -OutputBase (Join-Path $descriptor.evidence_path 'host_replay') -TimeoutSeconds 960
                $replayOutput=$process.output; $replayExit=$process.exit_code
                Write-Utf8CreateNew (Join-Path $descriptor.evidence_path 'passive_entry_replay_result.json') (($replayOutput -join "`n")+"`n")
                if ($replayExit -ne 0 -or $replayOutput.Count -ne 1) { $r10xCellFailures.Add(@{cell_id=$descriptor.cell_id;failure='R10X_REPLAY_FAILED'}) }
            }
            $process=Invoke-R10XHostPython -Arguments @((Join-Path $PSScriptRoot 'conformance/r10x_pair_audit.py'),$pair.root) -Stage pair_audit -Role ([string]$pair.seed.seed) -OutputBase (Join-Path $pair.root 'host_pair_audit') -TimeoutSeconds 1800
            $auditOutput=$process.output; $auditExit=$process.exit_code
            Write-Utf8CreateNew (Join-Path $pair.root 'independent_audit.stdout.json') (($auditOutput -join "`n")+"`n")
            if ($auditExit -ne 0 -or $auditOutput.Count -ne 1) { $r10xCellFailures.Add(@{pair_id=$pair.attempt_id;failure='R10X_PAIR_AUDIT_FAILED'}) }
}

function Invoke-R10XCampaignAudit([string]$Root) {
    $process=Invoke-R10XHostPython -Arguments @((Join-Path $PSScriptRoot 'conformance/r10x_campaign_audit.py'),$Root) -Stage campaign_audit -Role '' -OutputBase (Join-Path $Root 'host_campaign_audit') -TimeoutSeconds 1800
    if ($process.exit_code -ne 0 -or $process.output.Count -ne 1) { throw 'R10X_CAMPAIGN_AUDIT_FAILED' }
    $audited=$process.output[0] | ConvertFrom-Json -AsHashtable -Depth 100
    if (-not $audited.ok) { throw 'R10X_CAMPAIGN_AUDIT_REFUSED' }
    return $audited.result
}

if ($r10xLibrary) { return }
# Establish live kill-on-close ownership before acquiring the lock or creating
# any campaign directory. Direct invocation cannot open a world.
$r10xHostContext=Get-R10XLiveHostContext
Initialize-R10XHostProgress -RequestPath $r10xHostRequest -Context $r10xHostContext
$r10xHostValue=Get-Content -LiteralPath $r10xHostRequest -Raw | ConvertFrom-Json -AsHashtable
$r10xId = $r10xHostContext.attempt_id
$r10xRoot = Join-Path $evidenceRoot $(if (-not $r10xRun) {'r10x-zero-world-check-'+$r10xId} elseif ($r10xMode -eq 'development_ghost') {'r10x-production-ghost-'+$r10xId} else {'r10x-held-out-finite-decision-v1'})
$r10xLock=$null; $r10xFailure=''; $r10xAudit=$null; $r10xSource=$null; $r10xKey=''; $r10xPhysicalStarted=$false
$r10xOwnRoot=$false; $r10xAuditAttempted=$false
$r10xCompleted=[Collections.Generic.List[object]]::new()
$r10xPairs=@(); $r10xCellFailures=[Collections.Generic.List[object]]::new()
$r10xStarted=[DateTime]::UtcNow.ToString('o')
try {
    $r10xLock = Enter-SporeSporeLocomotionOperationLock -Role $(if (-not $r10xRun) {'conformance'} elseif ($r10xMode -eq 'held_out_finite_decision') {'physical'} else {'physical_development'}) -TimeoutMilliseconds 0
    if (-not $r10xLock.acquired -or $r10xLock.abandoned_owner_recovered) { throw 'R10X_OPERATION_LOCK' }
    $r10xSource = Get-DevelopmentSourceSnapshot
    if ($r10xSource.dirty) { throw 'R10X_REQUIRES_CLEAN_COMMITTED_SOURCE' }
    if ((Invoke-R10XJson 'r10x_campaign_authority' @('repository')).head -cne $r10xSource.head) { throw 'R10X_REPOSITORY_DRIFT' }
    $r10xManifest = Invoke-R10XJson 'r10x_dependency_manifest' @('snapshot')
    $r10xKey = $r10xManifest.production_route_key
    $r10xAuthority=$null
    if ($r10xRun -and $r10xMode -eq 'held_out_finite_decision') {
        $r10xAuthority = Invoke-R10XJson 'r10x_campaign_authority' @('validate')
        $null = Invoke-R10XJson 'r10x_dependency_manifest' @('validate')
    }
    if (Test-Path -LiteralPath $r10xRoot) { throw 'R10X_CAMPAIGN_IDENTITY_ALREADY_CONSUMED' }
    $null = New-Item -ItemType Directory -Path $r10xRoot -ErrorAction Stop
    $r10xOwnRoot=$true
    Write-JsonCreateNew (Join-Path $r10xRoot 'source_manifest.json') $r10xManifest
    $r10xRuntime = Get-QsdkR10fL14RuntimeBinding -Godot $Godot
    Write-R10XHostProgress -Stage safety_gate -State start
    if ($r10xRun -and $r10xMode -eq 'held_out_finite_decision') {
        # Authority validation above independently verified the original complete gate.
        $qualification=Get-Content -LiteralPath (Join-Path $repoRoot 'sdk/recovery/r10x_held_out_zero_world_qualification_v1.json') -Raw | ConvertFrom-Json -AsHashtable -Depth 100
        $captureRoot=$qualification.safety_gate_root
        $frozenGate=Get-Content -LiteralPath (Join-Path $captureRoot 'supervisor_result.json') -Raw | ConvertFrom-Json -AsHashtable -Depth 100
        foreach ($stageResult in $frozenGate.safety_stages) { $r10xCompleted.Add($stageResult) }
    } else {
        $null=Invoke-R10XJson 'r10x_safety_gate' @()
        if ($r10xStageContract.additional_required_controls.Count -ne 0) { throw 'R10X_INTEGRATION_CONTROLS_PENDING' }
        foreach ($stage in $r10xStages) {
            if ($stage.id -in $r10xStageContract.prehost_stage_ids) { continue }
            $stage.tests=[int]$stage.tests; $stage.timeout_seconds=[int]$stage.timeout_seconds
            $stageResult=Invoke-DevelopmentStage $stage $r10xRoot
            $r10xCompleted.Add($stageResult)
            Write-Output ('R10X_STAGE '+(ConvertTo-SporeSporeExactJson -Value $stageResult))
            if (-not $stageResult.passed) { throw ('R10X_SAFETY_GATE_FAILED:'+$stage.id) }
        }
        $import=@(& $pythonPath -B (Join-Path $PSScriptRoot 'conformance/r10x_prehost_qualification.py') --import-stages $r10xHostValue.prehost_qualification.path --target $r10xRoot)
        if ($LASTEXITCODE -ne 0 -or $import.Count -ne 1) { throw 'R10X_PREHOST_IMPORT_REFUSED' }
        $imported=$import[0] | ConvertFrom-Json -AsHashtable -Depth 100
        foreach ($stageResult in $imported.stages) { $r10xCompleted.Add($stageResult) }
        $captureRoot=$r10xRoot
    }
    Write-JsonCreateNew (Join-Path $r10xRoot 'safety_stages.json') $r10xCompleted.ToArray()
    $safety=Invoke-R10XJson 'r10x_safety_gate' @('--root',$captureRoot,'--stages',(Join-Path $r10xRoot 'safety_stages.json'))
    Write-R10XHostProgress -Stage safety_gate -State end -Subject $safety
    if ((ConvertTo-SporeSporeExactJson -Value $r10xSource) -cne (ConvertTo-SporeSporeExactJson -Value (Get-DevelopmentSourceSnapshot))) { throw 'R10X_SOURCE_CHANGED_DURING_GATE' }
    if ($r10xRun) {
        # Held-out uses the exact frozen qualification capture; ghost uses its
        # own fresh complete gate. Neither branch synthesizes native context.
        $captureRoot = $r10xRoot
        if ($r10xMode -eq 'held_out_finite_decision') {
            $qualification = Get-Content (Join-Path $repoRoot 'sdk/recovery/r10x_held_out_zero_world_qualification_v1.json') -Raw | ConvertFrom-Json -AsHashtable -Depth 100
            $captureRoot = $qualification.safety_gate_root
        }
        $native = Get-OptionalSingleMarkerJson -Stdout ([IO.File]::ReadAllText((Join-Path $captureRoot 'smoke_native_safety.stdout.log'))) -Marker 'DEVELOPMENT_SMOKE_ZERO_WORLD '
        if ($null -eq $native -or -not $native.ok) { throw 'R10X_NATIVE_CAPTURE_MISSING' }
        $capture=$native.native.l15_prepared_collection_context
        $prepared=ConvertFrom-Json -InputObject $capture.utf8_text -AsHashtable -Depth 100
        $expectation=@{raw_capture_binding=@{utf8_byte_length=$capture.utf8_byte_length;raw_sha256=$capture.raw_sha256};collection_identity=(ConvertFrom-Json -InputObject $prepared.expected_identity.utf8_text -AsHashtable -Depth 100)}
        if ($r10xMode -eq 'development_ghost' -and @(Get-ChildItem -LiteralPath $evidenceRoot -Directory -Filter 'r10x-production-ghost-*' | Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName 'campaign_claim.json') }).Count -gt 0) { throw 'R10X_GHOST_POPULATION_CONSUMED' }
        $cells=Get-R10XCells $r10xMode
        $r10xPairs=@(New-R10XPairPlan $cells $r10xId)
        $claim=@{schema_version='sporespore_r10x_campaign_claim_v1';mode=$r10xMode;attempt_id=$r10xId;source_commit=$r10xSource.head;
                 ledger_scope=@{subsystem='recovery';engine_scope='godot_jolt';authority_mode=$r10xMode;question_class=$(if ($r10xMode -eq 'development_ghost') {'development'} else {'finite decision'})};
                 candidate_profile=$candidateSelection.candidate_profile;production_route_key=$r10xKey;cells=$cells;
                 children=@($r10xPairs | ForEach-Object {$_.children});pairs=$r10xPairs;runtime=$r10xRuntime;
                 physical_acceptance_authority=$false;release_authority=$false}
        $claimPath=Join-Path $r10xRoot 'campaign_claim.json'
        Write-JsonCreateNew $claimPath $claim
        $claimBinding=@{path=$claimPath.Replace('\','/');raw_sha256=(Get-PrefixedSha256 $claimPath)}
        foreach ($pair in $r10xPairs) {
            $null=New-Item -ItemType Directory -Path $pair.root -ErrorAction Stop
            $context=@{schema_version='sporespore_r10x_campaign_child_context_v1';mode=$r10xMode;seed=$pair.seed;source_commit=$r10xSource.head;
                       campaign_attempt_id=$r10xId;candidate_profile=$candidateSelection.candidate_profile;claim_binding=$claimBinding}
            if ($r10xMode -eq 'held_out_finite_decision') {
                $context.authority_binding=@{path='res://sdk/recovery/r10x_held_out_execution_authority_v1.json';raw_sha256=$r10xAuthority.authority_file.raw_sha256}
                $context.preregistration_binding=@{path='res://sdk/recovery/r10x_held_out_preregistration_v1.json';raw_sha256=(Get-PrefixedSha256 (Join-Path $repoRoot 'sdk/recovery/r10x_held_out_preregistration_v1.json'))}
            }
            $declaration=New-R10XDeclaration $pair $r10xSource $r10xRuntime $expectation $context $r10xCompleted.ToArray() $r10xHostContext
            Write-JsonCreateNew (Join-Path $pair.root 'declaration.json') $declaration
            $script:PhysicalAttemptId=$pair.attempt_id; $script:PhysicalAttemptRoot=$pair.root; $script:RepairId='QSDK-R10F-L15'
            $script:DevelopmentSeed=$pair.seed.seed; $script:DevelopmentSeedLabel=$pair.seed.label; $script:DevelopmentSeedSha256=$pair.seed.sha256
            $binding=@{authority=@{source_commit=$r10xSource.head};authority_sha256=(Get-PrefixedSha256 (Join-Path $pair.root 'declaration.json'));
                       l14_exact_runtime_images=$r10xRuntime;l15_prepared_context_expectation=$expectation}
            Invoke-R10XPairChildren $pair $r10xSource $r10xKey $r10xRuntime $binding
            Invoke-R10XPairPostprocess $pair
        }
        $r10xAuditAttempted=$true
        $r10xAudit=Invoke-R10XCampaignAudit $r10xRoot
        if (-not $r10xAudit.execution_valid -or $r10xCellFailures.Count -gt 0) { throw 'R10X_CAMPAIGN_INVALID' }
    }
    if ((ConvertTo-SporeSporeExactJson -Value $r10xSource) -cne (ConvertTo-SporeSporeExactJson -Value (Get-DevelopmentSourceSnapshot))) { throw 'R10X_SOURCE_CHANGED_BEFORE_PUBLICATION' }
    if ((Invoke-R10XJson 'r10x_dependency_manifest' @('snapshot')).production_route_key -cne $r10xKey) { throw 'R10X_RUNTIME_CHANGED_BEFORE_PUBLICATION' }
 } catch {
    $r10xFailure=$_.Exception.Message
    # One original read-only audit accounts for invalid and unopened cells too.
    # Never retry an audit that has already started or reauthorize changed source.
    if ($r10xOwnRoot -and -not $r10xAuditAttempted -and (Test-Path -LiteralPath (Join-Path $r10xRoot 'campaign_claim.json'))) {
        try {
            Assert-R10XSourceAndRuntime $r10xSource $r10xKey
            $r10xAuditAttempted=$true
            $r10xAudit=Invoke-R10XCampaignAudit $r10xRoot
        } catch {
            Write-JsonCreateNew (Join-Path $r10xRoot 'campaign_audit_failure.json') @{failure=$_.Exception.Message;original_failure=$r10xFailure;retry_authorized=$false}
        }
    }
} finally {
    if ($null -ne $r10xLock) { Exit-SporeSporeLocomotionOperationLock -Receipt $r10xLock }
}
$receipt=@{schema_version='sporespore_r10x_campaign_supervisor_v1';mode=$r10xMode;attempt_id=$r10xId;
    ledger_scope=@{subsystem='recovery';engine_scope='godot_jolt';authority_mode=$(if ($r10xRun) {$r10xMode} else {'zero_world_component_gate'});question_class=$(if ($r10xMode -eq 'development_ghost') {'development'} else {'finite decision'})};
    ok=($r10xFailure -eq '');failure_code=$r10xFailure;source_snapshot=$r10xSource;production_route_key=$r10xKey;
    safety_stages=$r10xCompleted.ToArray();physical_attempt_started=$r10xPhysicalStarted;pairs=$r10xPairs;run_requested=$r10xRun;
    r10x_host=$r10xHostContext;prehost_qualification=$r10xHostValue.prehost_qualification;
    evidence_root=$r10xRoot.Replace('\','/');
    cell_failures=$r10xCellFailures.ToArray();independent_audit=$r10xAudit;started_utc=$r10xStarted;completed_utc=[DateTime]::UtcNow.ToString('o');
    physical_acceptance_authority=$false;release_authority=$false}
if ($r10xOwnRoot) {
    Write-R10XHostProgress -Stage publication -State start
    Write-JsonCreateNew (Join-Path $r10xRoot 'supervisor_result.json') $receipt
    $script:PhysicalAttemptRoot=$r10xRoot
    $script:PhysicalMarker='R10X_CAMPAIGN_COMPLETE '
    $script:L15PrimaryReportBinding=Get-R10fRetainedFileBinding (Join-Path $r10xRoot 'supervisor_result.json')
    $script:L15PrimaryReportWriteCompleted=$true
    $published=@(Publish-L15SupervisorResult $receipt)
    if ($published.Count -ne 1) { throw 'R10X_PUBLICATION_COUNT' }
    Write-Utf8CreateNew (Join-Path $r10xRoot 'published_marker.txt') ($published[0]+"`n")
    Write-R10XHostProgress -Stage publication -State end -Subject @{terminal=(Get-R10fRetainedFileBinding (Join-Path $r10xRoot 'supervisor_result.json'));marker=(Get-R10fRetainedFileBinding (Join-Path $r10xRoot 'published_marker.txt'))}
    Write-Output $published[0]
} else {
    Write-Output ('R10X_CAMPAIGN_REFUSED '+$r10xFailure)
}
if ($r10xFailure) { exit 1 }
