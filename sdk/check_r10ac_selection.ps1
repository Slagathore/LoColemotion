#requires -Version 7.0
[CmdletBinding()]
param([Parameter(Mandatory)][string]$Output)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$root=[IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
if ((& git -C $root rev-parse --show-toplevel) -cne 'C:/Users/Cole/CodeStuff/games/SporeSpore' -or
    (& git -C $root remote get-url origin) -cne 'https://github.com/Slagathore/sporespore.git') {throw 'Repository identity'}
$outputPath=[IO.Path]::GetFullPath($Output)
$evidence=[IO.Path]::GetFullPath('C:/Users/Cole/CodeStuff/games/SporeSpore_Evidence')+[IO.Path]::DirectorySeparatorChar
if (-not $outputPath.StartsWith($evidence,[StringComparison]::OrdinalIgnoreCase) -or (Test-Path -LiteralPath $outputPath)) {throw 'Fresh durable output required'}
New-Item -ItemType Directory -Path $outputPath | Out-Null
$design=Get-Content -Raw -LiteralPath (Join-Path $root 'sdk/recovery/r10ac_contact_frame_development_design_v1.json') | ConvertFrom-Json
$engine=$design.engine.path
if ('sha256:'+(Get-FileHash -LiteralPath $engine).Hash.ToLowerInvariant() -cne $design.engine.raw_sha256) {throw 'Observer engine hash'}
$inputs=@('sdk/check_r10ac_selection.ps1',
    'sdk/conformance/r10ac_development.py','sdk/conformance/r10ac_development_identity_check.py',
    'sdk/adapters/godot/gdscript/r10ac_development_seed_v1.gd',
    'sdk/adapters/godot/gdscript/r10j_campaign_seed_v1.gd',
    'sdk/trace_analysis/godot_authoritative_json_transport.gd',
    'sdk/development/recovery_candidates/r10ab-partial-downward-rise-core-v1.runtime.json',
    'sdk/adapters/godot/development_candidate_runtimes/r10ab-partial-downward-rise-core-v1.gdextension',
    'sdk/recovery/r10ac_contact_frame_development_design_v1.json',
    'sdk/development/recovery_candidates/r10ac-contact-frame-diagnostic-v1.json',
    'sdk/development/recovery_schedules/r10ac-contact-frame-diagnostic-v1.json',
    'sdk/conformance/r10ac_contact_report_check.py',
    'sdk/conformance/r10ac_contact_frame_report.py',
    'sdk/conformance/r10ac_contact_frame_replay.py',
    'sdk/conformance/content_addressed_zero_world_closure.py',
    'sdk/adapters/godot/gdscript/r10ac_contact_frame_report_v1.gd',
    'sdk/adapters/godot/gdscript/r10ac_linked_capture_worker_v1.gd',
    'sdk/adapters/godot/gdscript/r10ac_capture_worker_v1.gd',
    'sdk/adapters/godot/gdscript/r10ac_contact_frame_capture_v1.gd',
    'sdk/adapters/godot/gdscript/recovery_contact_frames_v1.gd',
    'sdk/adapters/godot/gdscript/recovery_runtime.gd',
    'sdk/adapters/godot/gdscript/recovery_native_world_v1.gd',
    'sdk/conformance/r10ac_selection_check.py',
    'sdk/conformance/r10ac_source_key.py',
    'sdk/conformance/r10ac_selection.py',
    'sdk/conformance/r10ac_development_v2.py',
    'sdk/adapters/godot/gdscript/r10ac_capture_selection_v1.gd',
    'sdk/adapters/godot/gdscript/r10ac_complete_report_replay_v1.gd',
    'sdk/adapters/godot/gdscript/r10ac_development_worker_v1.gd',
    'sdk/adapters/godot/gdscript/r10ac_development_seed_v2.gd',
    'sdk/conformance/development_recovery_candidate.py',
    'sdk/adapters/godot/gdscript/development_recovery_candidate_profile_v1.gd',
    'sdk/adapters/godot/gdscript/development_recovery_walking_startup_v1.gd',
    'sdk/adapters/godot/gdscript/development_recovery_walking_start_v1.gd',
    'sdk/adapters/godot/gdscript/development_recovery_cycle_stop_v1.gd',
    'sdk/adapters/godot/gdscript/recovery_finite_cycle_route_v1.gd',
    'sdk/adapters/godot/gdscript/qsdk_r10f_recovery_native_locomotion_facade_v1.gd',
    'sdk/trace_analysis/r10ac_recovery_replay.gd',
    'sdk/recovery/r10ac_contact_frame_development_design_v2.json',
    'sdk/recovery/r10ac_v56_walking_start_contract_v1.json',
    'sdk/development/recovery_candidates/r10ac-contact-frame-diagnostic-v2.json',
    'sdk/development/recovery_schedules/r10ac-contact-frame-diagnostic-v2.json',
    'tests/test_r10ac_selection.gd')
$keyMatches=[regex]::Matches((Get-Content -Raw (Join-Path $root 'sdk/conformance/development_recovery_candidate.py')),'r10ac_v56_walking_entry_contract_v\d+\.json')
if($keyMatches.Count -ne 1){throw 'Unique R10AC source key required'}
$keyPath='sdk/recovery/'+$keyMatches[0].Value
$sourceKey=Get-Content -Raw (Join-Path $root $keyPath) | ConvertFrom-Json
if(-not $sourceKey.source_key_complete){throw 'Complete R10AC source key required'}
foreach($bound in $sourceKey.bound_source_files) {
    if ('sha256:'+(Get-FileHash -LiteralPath (Join-Path $root $bound.path)).Hash.ToLowerInvariant() -cne $bound.raw_sha256) {throw ('Source key drift: '+$bound.path)}
}
$inputs=@(@($inputs)+@($sourceKey.bound_source_files.path)+@($keyPath) | Sort-Object -Unique)
$before=@($inputs | ForEach-Object { $p=Join-Path $root $_; @{path=$_;sha256=(Get-FileHash -LiteralPath $p).Hash;bytes=(Get-Item -LiteralPath $p).Length} })
$before | ConvertTo-Json | Set-Content (Join-Path $outputPath 'source-before.json')
$design.engine | ConvertTo-Json | Set-Content (Join-Path $outputPath 'engine.json')
. (Join-Path $PSScriptRoot 'locomotion_operation_lock.ps1')
$lock=Enter-SporeSporeLocomotionOperationLock -Role conformance
if(-not $lock.acquired){throw 'Native operation busy'}
$result=[ordered]@{ok=$false;world_build_count=0;solver_step_count=0;physical_acceptance_authority=$false;release_authority=$false}
try {
    Get-SporeSporeLocomotionOperationLockPublicReceipt -Receipt $lock | ConvertTo-Json | Set-Content (Join-Path $outputPath 'lock.json')
    $checker=Join-Path $root 'sdk/conformance/r10ac_selection_check.py'
    & 'C:/Program Files/Python311/python.exe' -B $checker --prepare (Join-Path $outputPath 'fixture.json') 1> (Join-Path $outputPath 'prepare.stdout.log') 2> (Join-Path $outputPath 'prepare.stderr.log')
    @{exit_code=$LASTEXITCODE} | ConvertTo-Json | Set-Content (Join-Path $outputPath 'prepare.execution.json')
    if($LASTEXITCODE -ne 0){throw 'Python fixture check failed'}
    foreach($name in @('worker-parse','reader-parse','report')) {
    $arguments=@('--headless','--path',$root,'--log-file',(Join-Path $outputPath "$name.engine.log"),
        '--script')
    if($name -eq 'worker-parse') {$arguments+=@('res://sdk/adapters/godot/gdscript/r10ac_development_worker_v1.gd','--check-only')}
    elseif($name -eq 'reader-parse') {$arguments+=@('res://sdk/trace_analysis/r10ac_recovery_replay.gd','--check-only')}
    else {$arguments+=@('res://tests/test_r10ac_selection.gd','--',(Join-Path $outputPath 'fixture.json'),(Join-Path $outputPath 'native.json'))}
    @{executable=$engine;arguments=$arguments;timeout_ms=60000;working_directory=$root} | ConvertTo-Json | Set-Content (Join-Path $outputPath "$name.command.json")
    $process=Start-Process -FilePath $engine -ArgumentList $arguments -WorkingDirectory $root -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $outputPath "$name.stdout.log") -RedirectStandardError (Join-Path $outputPath "$name.stderr.log")
    $finished=$process.WaitForExit(60000)
    if(-not $finished){Stop-Process -Id $process.Id -Force;$process.WaitForExit()}
    $errors=(Get-Item -LiteralPath (Join-Path $outputPath "$name.stderr.log")).Length
    @{exit_code=$process.ExitCode;timed_out=(-not $finished);stderr_bytes=$errors;process_id=$process.Id} | ConvertTo-Json | Set-Content (Join-Path $outputPath "$name.execution.json")
    if(-not $finished -or $process.ExitCode -ne 0 -or $errors -ne 0){throw "Godot contact report check failed: $name"}
    }
    & 'C:/Program Files/Python311/python.exe' -B $checker --verify (Join-Path $outputPath 'native.json') 1> (Join-Path $outputPath 'verify.stdout.log') 2> (Join-Path $outputPath 'verify.stderr.log')
    @{exit_code=$LASTEXITCODE} | ConvertTo-Json | Set-Content (Join-Path $outputPath 'verify.execution.json')
    if($LASTEXITCODE -ne 0){throw 'Independent report verification failed'}
    $result.observed=Get-Content -Raw (Join-Path $outputPath 'verify.stdout.log') | ConvertFrom-Json
    $result.ok=$true
} catch {$result.error=$_.Exception.Message}
finally {
    $after=@($inputs | ForEach-Object { $p=Join-Path $root $_; @{path=$_;sha256=(Get-FileHash -LiteralPath $p).Hash;bytes=(Get-Item -LiteralPath $p).Length} })
    $after | ConvertTo-Json | Set-Content (Join-Path $outputPath 'source-after.json')
    foreach($item in $before){if((Get-FileHash -LiteralPath (Join-Path $root $item.path)).Hash -cne $item.sha256){$result.ok=$false;$result.error='Source changed: '+$item.path}}
    Exit-SporeSporeLocomotionOperationLock -Receipt $lock
    $result | ConvertTo-Json -Depth 8 | Set-Content (Join-Path $outputPath 'result.json')
}
Write-Output ('R10AC_SELECTION_CHECK '+($result | ConvertTo-Json -Compress -Depth 8))
if(-not $result.ok){exit 1}
