#requires -Version 7.5
param([Parameter(Mandatory)][string]$Request)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$hostRepo=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$hostPython='C:/Program Files/Python311/python.exe'
$hostModule=Join-Path $PSScriptRoot 'conformance/r10v_durable_host_v2.py'
$hostRequestValue=Get-Content -LiteralPath $Request -Raw | ConvertFrom-Json -AsHashtable
$hostRoot=Split-Path -Parent $Request
$hostContextOutput=@(& $hostPython -B $hostModule --register-supervisor $Request --supervisor-pid $PID)
if ($LASTEXITCODE -ne 0 -or $hostContextOutput.Count -ne 1) { throw 'R10V_HOST_REGISTRATION_REFUSED' }
$hostContext=$hostContextOutput[0] | ConvertFrom-Json -AsHashtable
$hostArguments=@{ProfileSteps=$true;ReuseContextChecks=$true;CandidateProfile='sdk/development/recovery_candidates/r10v-v56-post-recovery-hold-integrated-v2.json';R10VHostRequest=$Request}
if ($hostRequestValue.seed -ne 41345) {
    $hostArguments.SingleKick=$true
    $hostArguments.R10VDiagnosticSeed=[int]$hostRequestValue.seed
    $hostArguments.R10VPrerequisite=$hostRequestValue.prerequisite_root
}
if ($hostRequestValue.lane -ceq 'production_interface_probe') {
    . (Join-Path $PSScriptRoot 'locomotion_operation_lock.ps1')
    $hostProbeLock=Enter-SporeSporeLocomotionOperationLock -Role conformance -TimeoutMilliseconds 0
    if (-not $hostProbeLock.acquired -or $hostProbeLock.abandoned_owner_recovered) {
        if ($hostProbeLock.acquired) { Exit-SporeSporeLocomotionOperationLock -Receipt $hostProbeLock }
        throw 'R10V_HOST_INTERFACE_LOCK_REFUSED'
    }
    try {
        . (Join-Path $PSScriptRoot 'run_development_recovery_smoke.ps1') @hostArguments -Library
        Write-R10VHostProgress -Stage interface -State start
        $hostFields=Get-DevelopmentCandidateFields
        if (-not $r10vSelected -or $script:DevelopmentSeed -ne $hostRequestValue.seed -or $null -eq $hostFields.r10v_host) { throw 'R10V_HOST_INTERFACE_SELECTION' }
        Write-JsonCreateNew (Join-Path $hostRoot 'interface_lock.json') @{acquired=$hostProbeLock.acquired;abandoned_owner_recovered=$hostProbeLock.abandoned_owner_recovered;test_only=$hostProbeLock.test_only;mutex_name=$hostProbeLock.mutex_name;role=$hostProbeLock.role}
        $hostInterface=@{host_context=$hostFields.r10v_host;worker=$script:WorkerResource;seed=$script:DevelopmentSeed;
            fields=$hostFields;world_build_count=0;solver_step_count=0;physical_acceptance_authority=$false;release_authority=$false}
        Write-JsonCreateNew (Join-Path $hostRoot 'interface_receipt.json') $hostInterface
        Write-R10VHostProgress -Stage interface -State end -Subject @{receipt=(Get-R10fRetainedFileBinding (Join-Path $hostRoot 'interface_receipt.json'))}
        $hostPythonArguments=if ($hostRequestValue.probe_case -ceq 'python_nonzero') { @('-c','raise SystemExit(7)') } elseif ($hostRequestValue.probe_case -ceq 'python_timeout') { @('-c','import time; time.sleep(45)') } else { @('--version') }
        $hostPythonProbe=Invoke-R10VHostPython -Arguments $hostPythonArguments -Stage interface_python -Role '' -OutputBase (Join-Path $hostRoot 'interface_python') -TimeoutSeconds 30
        if ($hostPythonProbe.exit_code -ne 0) { throw 'R10V_HOST_INTERFACE_PYTHON_FAILED' }
        Write-JsonCreateNew (Join-Path $hostRoot 'probe_terminal.json') @{invocation_id=$hostRequestValue.invocation_id;ok=$true;
            world_build_count=0;solver_step_count=0;interface_receipt=(Get-R10fRetainedFileBinding (Join-Path $hostRoot 'interface_receipt.json'))}
        Write-Output 'R10V_PRODUCTION_INTERFACE_PROBE_FINISHED'
    } finally { Exit-SporeSporeLocomotionOperationLock -Receipt $hostProbeLock }
    exit 0
}
if ($hostRequestValue.lane -notin @('production_gate','production_smoke')) { throw 'R10V_HOST_PRODUCTION_LANE_REQUIRED' }
$hostArguments.RunSmoke=($hostRequestValue.lane -ceq 'production_smoke')
& (Join-Path $PSScriptRoot 'run_development_recovery_smoke.ps1') @hostArguments
exit $LASTEXITCODE
