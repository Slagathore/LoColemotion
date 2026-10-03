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
$r10jMode = $Mode
$r10jRun = $Run.IsPresent
$r10jLibrary = $Library.IsPresent
if ($r10jLibrary -and $r10jRun) { throw 'R10J_LIBRARY_CANNOT_RUN' }
. (Join-Path $PSScriptRoot 'run_development_recovery_smoke.ps1') -Library -ProfileSteps -ReuseContextChecks `
    -CandidateProfile 'sdk/development/recovery_candidates/r10j-v50-campaign-v4.json'
$r10jStages = @($stages) + @(
    @{id='r10j_authority_graph';pattern='test_r10j_campaign_authority.py';tests=8},
    @{id='r10j_native_seed_boundary';pattern='test_r10j_campaign_seed.py';tests=3},
    @{id='r10j_finite_task';pattern='test_r10j_finite_task*.py';tests=8},
    @{id='r10j_campaign_runner';pattern='test_r10j_campaign_runner.py';tests=4},
    @{id='r10j_dependency_closure';pattern='test_r10j_dependency_manifest.py';tests=3},
    @{id='r10j_qualification_retention';pattern='test_r10j_qualification.py';tests=4},
    @{id='r10j_closure_adoption';pattern='test_r10j_campaign_closure.py';tests=4}
)

function Invoke-R10JJson {
    param([string]$Module,[string[]]$Arguments)
    $lines = @(& $pythonPath -B (Join-Path $PSScriptRoot ('conformance/'+$Module+'.py')) @Arguments)
    if ($LASTEXITCODE -ne 0 -or $lines.Count -ne 1) { throw ('R10J_COMPONENT_REFUSED:'+ $Module + ':' + ($lines -join ' ')) }
    $result = ConvertFrom-Json -InputObject $lines[0] -AsHashtable -Depth 100
    if (-not $result.ok) { throw ('R10J_COMPONENT_INVALID:'+ $Module) }
    return $result.result
}

function Get-R10JCells([string]$CampaignMode) {
    return @(Invoke-R10JJson 'r10j_campaign_authority' @('population','--mode',$CampaignMode))
}

function New-R10JPairPlan {
    param([object[]]$Cells,[string]$CampaignAttemptId)
    if ($CampaignAttemptId -cnotmatch '^[0-9a-f]{32}$') { throw 'R10J_CAMPAIGN_ATTEMPT_DOMAIN' }
    $expected = @(Get-R10JCells $(if ($Cells.Count -eq 2) {'development_ghost'} else {'held_out_finite_decision'}))
    if ((ConvertTo-SporeSporeExactJson -Value $Cells) -cne (ConvertTo-SporeSporeExactJson -Value $expected)) { throw 'R10J_EXACT_PLAN_POPULATION' }
    $pairs = [Collections.Generic.List[object]]::new()
    foreach ($seed in @($Cells | ForEach-Object { $_.seed.seed } | Select-Object -Unique)) {
        $id = [Guid]::NewGuid().ToString('N')
        $root = Join-Path $evidenceRoot ('development-recovery-smoke-'+$id)
        $children = @($Cells | Where-Object { $_.seed.seed -eq $seed } | ForEach-Object {
            @{cell_id=$_.cell_id;role=$_.role;campaign_attempt_id=$CampaignAttemptId;child_attempt_id=[Guid]::NewGuid().ToString('N');
              parent_attempt_id=$id;termination_nonce=[Guid]::NewGuid().ToString('N');
              evidence_path=(Join-Path $root ('children/'+$_.role))}
        })
        if ($children.Count -ne 2) { throw 'R10J_PAIR_POPULATION' }
        $pairs.Add(@{attempt_id=$id;root=$root;seed=($Cells | Where-Object { $_.seed.seed -eq $seed } | Select-Object -First 1).seed;children=$children})
    }
    return $pairs.ToArray()
}

function New-R10JDeclaration {
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
        r10j_campaign=$Context
    }
    $fields = Get-DevelopmentCandidateFields
    foreach ($key in $fields.Keys) { $value[$key]=$fields[$key] }
    return $value
}

if ($r10jLibrary) { return }
$r10jId = [Guid]::NewGuid().ToString('N')
$r10jRoot = Join-Path $evidenceRoot $(if (-not $r10jRun) {'r10j-zero-world-check-'+$r10jId} elseif ($r10jMode -eq 'development_ghost') {'r10j-production-ghost-'+$r10jId} else {'r10j-held-out-finite-decision-v1'})
$r10jLock=$null; $r10jFailure=''; $r10jAudit=$null; $r10jSource=$null; $r10jKey=''; $r10jPhysicalStarted=$false
$r10jOwnRoot=$false
$r10jCompleted=[Collections.Generic.List[object]]::new()
$r10jPairs=@(); $r10jCellFailures=[Collections.Generic.List[object]]::new()
$r10jStarted=[DateTime]::UtcNow.ToString('o')
try {
    $r10jLock = Enter-SporeSporeLocomotionOperationLock -Role $(if (-not $r10jRun) {'conformance'} elseif ($r10jMode -eq 'held_out_finite_decision') {'physical'} else {'physical_development'}) -TimeoutMilliseconds 0
    if (-not $r10jLock.acquired -or $r10jLock.abandoned_owner_recovered) { throw 'R10J_OPERATION_LOCK' }
    $r10jSource = Get-DevelopmentSourceSnapshot
    if ($r10jSource.dirty) { throw 'R10J_REQUIRES_CLEAN_COMMITTED_SOURCE' }
    if ((Invoke-R10JJson 'r10j_campaign_authority' @('repository')).head -cne $r10jSource.head) { throw 'R10J_REPOSITORY_DRIFT' }
    $r10jManifest = Invoke-R10JJson 'r10j_dependency_manifest' @('snapshot')
    $r10jKey = $r10jManifest.production_route_key
    $r10jAuthority=$null
    if ($r10jRun -and $r10jMode -eq 'held_out_finite_decision') {
        $r10jAuthority = Invoke-R10JJson 'r10j_campaign_authority' @('validate')
        $null = Invoke-R10JJson 'r10j_dependency_manifest' @('validate')
    }
    if (Test-Path -LiteralPath $r10jRoot) { throw 'R10J_CAMPAIGN_IDENTITY_ALREADY_CONSUMED' }
    $null = New-Item -ItemType Directory -Path $r10jRoot -ErrorAction Stop
    $r10jOwnRoot=$true
    Write-JsonCreateNew (Join-Path $r10jRoot 'source_manifest.json') $r10jManifest
    $r10jRuntime = Get-QsdkR10fL14RuntimeBinding -Godot $Godot
    if (-not ($r10jRun -and $r10jMode -eq 'held_out_finite_decision')) {
        foreach ($stage in $r10jStages) {
            $stageResult=Invoke-DevelopmentStage $stage $r10jRoot
            $r10jCompleted.Add($stageResult)
            Write-Output ('R10J_STAGE '+(ConvertTo-SporeSporeExactJson -Value $stageResult))
            if (-not $stageResult.passed) { throw ('R10J_SAFETY_GATE_FAILED:'+$stage.id) }
        }
    }
    if ((ConvertTo-SporeSporeExactJson -Value $r10jSource) -cne (ConvertTo-SporeSporeExactJson -Value (Get-DevelopmentSourceSnapshot))) { throw 'R10J_SOURCE_CHANGED_DURING_GATE' }
    if ($r10jRun) {
        # Held-out uses the exact frozen qualification capture; ghost uses its
        # own fresh complete gate. Neither branch synthesizes native context.
        $captureRoot = $r10jRoot
        if ($r10jMode -eq 'held_out_finite_decision') {
            $qualification = Get-Content (Join-Path $repoRoot 'sdk/recovery/r10j_held_out_zero_world_qualification_v1.json') -Raw | ConvertFrom-Json -AsHashtable -Depth 100
            $captureRoot = $qualification.safety_gate_root
        }
        $native = Get-OptionalSingleMarkerJson -Stdout ([IO.File]::ReadAllText((Join-Path $captureRoot 'smoke_native_safety.stdout.log'))) -Marker 'DEVELOPMENT_SMOKE_ZERO_WORLD '
        if ($null -eq $native -or -not $native.ok) { throw 'R10J_NATIVE_CAPTURE_MISSING' }
        $capture=$native.native.l15_prepared_collection_context
        $prepared=ConvertFrom-Json -InputObject $capture.utf8_text -AsHashtable -Depth 100
        $expectation=@{raw_capture_binding=@{utf8_byte_length=$capture.utf8_byte_length;raw_sha256=$capture.raw_sha256};collection_identity=(ConvertFrom-Json -InputObject $prepared.expected_identity.utf8_text -AsHashtable -Depth 100)}
        $cells=Get-R10JCells $r10jMode
        $r10jPairs=@(New-R10JPairPlan $cells $r10jId)
        $claim=@{schema_version='sporespore_r10j_campaign_claim_v1';mode=$r10jMode;attempt_id=$r10jId;source_commit=$r10jSource.head;
                 ledger_scope=@{subsystem='recovery';engine_scope='godot_jolt';authority_mode=$r10jMode;question_class=$(if ($r10jMode -eq 'development_ghost') {'development'} else {'finite decision'})};
                 candidate_profile=$candidateSelection.candidate_profile;production_route_key=$r10jKey;cells=$cells;
                 children=@($r10jPairs | ForEach-Object {$_.children});pairs=$r10jPairs;runtime=$r10jRuntime;
                 physical_acceptance_authority=$false;release_authority=$false}
        $claimPath=Join-Path $r10jRoot 'campaign_claim.json'
        Write-JsonCreateNew $claimPath $claim
        $claimBinding=@{path=$claimPath.Replace('\','/');raw_sha256=(Get-PrefixedSha256 $claimPath)}
        foreach ($pair in $r10jPairs) {
            $null=New-Item -ItemType Directory -Path $pair.root -ErrorAction Stop
            $context=@{schema_version='sporespore_r10j_campaign_child_context_v1';mode=$r10jMode;seed=$pair.seed;source_commit=$r10jSource.head;
                       campaign_attempt_id=$r10jId;candidate_profile=$candidateSelection.candidate_profile;claim_binding=$claimBinding}
            if ($r10jMode -eq 'held_out_finite_decision') {
                $context.authority_binding=@{path='res://sdk/recovery/r10j_held_out_execution_authority_v1.json';raw_sha256=$r10jAuthority.authority_file.raw_sha256}
                $context.preregistration_binding=@{path='res://sdk/recovery/r10j_held_out_preregistration_v4.json';raw_sha256=(Get-PrefixedSha256 (Join-Path $repoRoot 'sdk/recovery/r10j_held_out_preregistration_v4.json'))}
            }
            $declaration=New-R10JDeclaration $pair $r10jSource $r10jRuntime $expectation $context $r10jCompleted.ToArray()
            Write-JsonCreateNew (Join-Path $pair.root 'declaration.json') $declaration
            $script:PhysicalAttemptId=$pair.attempt_id; $script:PhysicalAttemptRoot=$pair.root; $script:RepairId='QSDK-R10F-L15'
            $script:DevelopmentSeed=$pair.seed.seed; $script:DevelopmentSeedLabel=$pair.seed.label; $script:DevelopmentSeedSha256=$pair.seed.sha256
            $binding=@{authority=@{source_commit=$r10jSource.head};authority_sha256=(Get-PrefixedSha256 (Join-Path $pair.root 'declaration.json'));
                       l14_exact_runtime_images=$r10jRuntime;l15_prepared_context_expectation=$expectation}
            foreach ($descriptor in $pair.children) {
                if ((ConvertTo-SporeSporeExactJson -Value $r10jSource) -cne (ConvertTo-SporeSporeExactJson -Value (Get-DevelopmentSourceSnapshot))) { throw 'R10J_SOURCE_CHANGED_BEFORE_CHILD' }
                if ((Invoke-R10JJson 'r10j_dependency_manifest' @('snapshot')).production_route_key -cne $r10jKey) { throw 'R10J_RUNTIME_CHANGED_BEFORE_CHILD' }
                $null=New-Item -ItemType Directory -Path $descriptor.evidence_path -ErrorAction Stop
                Write-JsonCreateNew (Join-Path $descriptor.evidence_path 'child_attempt_identity.json') $descriptor
                Write-Output ('R10J_CHILD_START '+$descriptor.cell_id)
                $r10jPhysicalStarted=$true
                try {
                    $child=Invoke-L9ChildProcess -Descriptor $descriptor -Binding $binding -GodotPath $Godot -RequireL15LaunchRelationship
                    $launchContext=New-QsdkR10fL15ProductionLaunchContext $pair.attempt_id $descriptor $r10jSource.head $binding.authority_sha256 $r10jRuntime
                    $null=Assert-QsdkR10fL15ChildLaunchRelationship $child $launchContext
                    if ($child.exit_code -ne 0 -or -not $child.raw_marker_valid -or -not $child.engine_health_passed) { throw 'R10J_CHILD_INVALID' }
                    Write-Output ('R10J_CHILD_END '+$descriptor.cell_id)
                } catch {
                    $r10jCellFailures.Add(@{cell_id=$descriptor.cell_id;failure=$_.Exception.Message})
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
                if ($replayExit -ne 0 -or $replayOutput.Count -ne 1) { $r10jCellFailures.Add(@{cell_id=$descriptor.cell_id;failure='R10J_REPLAY_FAILED'}) }
            }
            $auditOutput=@(& $pythonPath -B (Join-Path $PSScriptRoot 'conformance/development_recovery_smoke.py') $pair.root)
            $auditExit=$LASTEXITCODE
            Write-Utf8CreateNew (Join-Path $pair.root 'independent_audit.stdout.json') (($auditOutput -join "`n")+"`n")
            if ($auditExit -ne 0 -or $auditOutput.Count -ne 1) { $r10jCellFailures.Add(@{pair_id=$pair.attempt_id;failure='R10J_PAIR_AUDIT_FAILED'}) }
        }
        $r10jAudit=Invoke-R10JJson 'r10j_campaign_audit' @($r10jRoot)
        if (-not $r10jAudit.execution_valid -or $r10jCellFailures.Count -gt 0) { throw 'R10J_CAMPAIGN_INVALID' }
    }
    if ((ConvertTo-SporeSporeExactJson -Value $r10jSource) -cne (ConvertTo-SporeSporeExactJson -Value (Get-DevelopmentSourceSnapshot))) { throw 'R10J_SOURCE_CHANGED_BEFORE_PUBLICATION' }
    if ((Invoke-R10JJson 'r10j_dependency_manifest' @('snapshot')).production_route_key -cne $r10jKey) { throw 'R10J_RUNTIME_CHANGED_BEFORE_PUBLICATION' }
} catch { $r10jFailure=$_.Exception.Message } finally {
    if ($null -ne $r10jLock) { Exit-SporeSporeLocomotionOperationLock $r10jLock }
}
$receipt=@{schema_version='sporespore_r10j_campaign_supervisor_v1';mode=$r10jMode;attempt_id=$r10jId;
    ledger_scope=@{subsystem='recovery';engine_scope='godot_jolt';authority_mode=$(if ($r10jRun) {$r10jMode} else {'zero_world_component_gate'});question_class=$(if ($r10jMode -eq 'development_ghost') {'development'} else {'finite decision'})};
    ok=($r10jFailure -eq '');failure_code=$r10jFailure;source_snapshot=$r10jSource;production_route_key=$r10jKey;
    safety_stages=$r10jCompleted.ToArray();physical_attempt_started=$r10jPhysicalStarted;pairs=$r10jPairs;run_requested=$r10jRun;
    evidence_root=$r10jRoot.Replace('\','/');
    cell_failures=$r10jCellFailures.ToArray();independent_audit=$r10jAudit;started_utc=$r10jStarted;completed_utc=[DateTime]::UtcNow.ToString('o');
    physical_acceptance_authority=$false;release_authority=$false}
if ($r10jOwnRoot) {
    Write-JsonCreateNew (Join-Path $r10jRoot 'supervisor_result.json') $receipt
    $script:PhysicalAttemptRoot=$r10jRoot
    $script:PhysicalMarker='R10J_CAMPAIGN_COMPLETE '
    $script:L15PrimaryReportBinding=Get-R10fRetainedFileBinding (Join-Path $r10jRoot 'supervisor_result.json')
    $script:L15PrimaryReportWriteCompleted=$true
    $published=@(Publish-L15SupervisorResult $receipt)
    if ($published.Count -ne 1) { throw 'R10J_PUBLICATION_COUNT' }
    Write-Utf8CreateNew (Join-Path $r10jRoot 'published_marker.txt') ($published[0]+"`n")
    Write-Output $published[0]
} else {
    Write-Output ('R10J_CAMPAIGN_REFUSED '+$r10jFailure)
}
if ($r10jFailure) { exit 1 }
