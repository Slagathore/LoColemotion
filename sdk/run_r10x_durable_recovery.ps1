#requires -Version 7.5
param([Parameter(Mandatory)][string]$Request)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$hostRepo=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$hostPython='C:/Program Files/Python311/python.exe'
$hostModule=Join-Path $PSScriptRoot 'conformance/r10x_durable_host_v1.py'
$hostRequestValue=Get-Content -LiteralPath $Request -Raw | ConvertFrom-Json -AsHashtable
$hostRoot=Split-Path -Parent $Request
$hostContextOutput=@(& $hostPython -B $hostModule --register-supervisor $Request --supervisor-pid $PID)
if ($LASTEXITCODE -ne 0 -or $hostContextOutput.Count -ne 1) { throw 'R10X_HOST_REGISTRATION_REFUSED' }
$hostContext=$hostContextOutput[0] | ConvertFrom-Json -AsHashtable
if ($hostRequestValue.lane -ceq 'production_interface_probe') {
    . (Join-Path $PSScriptRoot 'locomotion_operation_lock.ps1')
    $hostProbeLock=Enter-SporeSporeLocomotionOperationLock -Role conformance -TimeoutMilliseconds 0
    if (-not $hostProbeLock.acquired -or $hostProbeLock.abandoned_owner_recovered) {
        if ($hostProbeLock.acquired) { Exit-SporeSporeLocomotionOperationLock -Receipt $hostProbeLock }
        throw 'R10X_HOST_INTERFACE_LOCK_REFUSED'
    }
    try {
        . (Join-Path $PSScriptRoot 'run_r10x_finite_recovery.ps1') -Library -Mode $hostRequestValue.mode
        . (Join-Path $PSScriptRoot 'r10x_host_progress.ps1')
        Initialize-R10XHostProgress -RequestPath $Request -Context $hostContext
        Write-R10XHostProgress -Stage interface -State start
        $cells=@(Get-R10XCells $hostRequestValue.mode)
        $pairs=@(New-R10XPairPlan $cells $hostRequestValue.attempt_id)
        $pair=$pairs[0]
        $context=@{schema_version='sporespore_r10x_campaign_child_context_v1';mode=$hostRequestValue.mode;
            seed=$pair.seed;source_commit=$hostRequestValue.source_snapshot.head;campaign_attempt_id=$hostRequestValue.attempt_id;
            candidate_profile=$candidateSelection.candidate_profile}
        $hostFields=New-R10XDeclaration $pair @{head=$hostRequestValue.source_snapshot.head;dirty=$false;status=@();changed_file_bindings=@()} @{} @{} $context @() $hostContext
        if ($script:WorkerResource -cne 'res://sdk/adapters/godot/gdscript/r10x_campaign_worker_v1.gd' -or $r10vSelected -or $null -eq $hostFields.r10x_host) { throw 'R10X_HOST_INTERFACE_SELECTION' }
        Write-JsonCreateNew (Join-Path $hostRoot 'interface_lock.json') @{acquired=$hostProbeLock.acquired;abandoned_owner_recovered=$hostProbeLock.abandoned_owner_recovered;test_only=$hostProbeLock.test_only;mutex_name=$hostProbeLock.mutex_name;role=$hostProbeLock.role}
        $hostInterface=@{host_context=$hostContext;worker=$script:WorkerResource;mode=$hostRequestValue.mode;
            cells=$cells;pairs=$pairs;fields=$hostFields;world_build_count=0;solver_step_count=0;physical_acceptance_authority=$false;release_authority=$false}
        Write-JsonCreateNew (Join-Path $hostRoot 'interface_receipt.json') $hostInterface
        Write-R10XHostProgress -Stage interface -State end -Subject @{receipt=(Get-R10fRetainedFileBinding (Join-Path $hostRoot 'interface_receipt.json'))}
        $hostPythonArguments=if ($hostRequestValue.probe_case -ceq 'python_nonzero') { @('-c','raise SystemExit(7)') } elseif ($hostRequestValue.probe_case -ceq 'python_timeout') { @('-c','import time; time.sleep(45)') } else { @('--version') }
        $hostPythonProbe=Invoke-R10XHostPython -Arguments $hostPythonArguments -Stage interface_python -Role '' -OutputBase (Join-Path $hostRoot 'interface_python') -TimeoutSeconds 30
        if ($hostPythonProbe.exit_code -ne 0) { throw 'R10X_HOST_INTERFACE_PYTHON_FAILED' }
        Write-JsonCreateNew (Join-Path $hostRoot 'probe_terminal.json') @{invocation_id=$hostRequestValue.invocation_id;ok=$true;
            world_build_count=0;solver_step_count=0;interface_receipt=(Get-R10fRetainedFileBinding (Join-Path $hostRoot 'interface_receipt.json'))}
        Write-Output 'R10X_PRODUCTION_INTERFACE_PROBE_FINISHED'
    } finally { Exit-SporeSporeLocomotionOperationLock -Receipt $hostProbeLock }
    exit 0
}
if ($hostRequestValue.lane -notin @('production_gate','production_campaign')) { throw 'R10X_HOST_PRODUCTION_LANE_REQUIRED' }
& (Join-Path $PSScriptRoot 'run_r10x_finite_recovery.ps1') -HostRequest $Request -Mode $hostRequestValue.mode -Run:($hostRequestValue.lane -ceq 'production_campaign')
exit $LASTEXITCODE
