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
$engine='C:/Users/Cole/CodeStuff/games/SporeSpore_Evidence/r10ac-contact-frame-build-ac6fc57f978740a8926c9955f4b572b1/build-02/godot.windows.editor.dev.x86_64.exe'
if ((Get-FileHash -LiteralPath $engine).Hash -cne '491663B2F41147938B45EEB0863D68A0BB14EC18C6349D94402DF846F29F9347') {throw 'Observer engine hash'}
$profilePath=Join-Path $root 'sdk/development/recovery_candidates/r10ab-partial-downward-rise-core-v1.json'
$profile=Get-Content -Raw -LiteralPath $profilePath | ConvertFrom-Json
$runtimePath=Join-Path $root ($profile.runtime_binding.Substring(6))
$extensionPath=Join-Path $root ($profile.extension.Substring(6))
if ('sha256:'+(Get-FileHash -LiteralPath $runtimePath).Hash.ToLowerInvariant() -cne $profile.runtime_binding_sha256 -or
    'sha256:'+(Get-FileHash -LiteralPath $extensionPath).Hash.ToLowerInvariant() -cne $profile.extension_sha256) {throw 'Core profile dependency hashes'}
$runtime=Get-Content -Raw -LiteralPath $runtimePath | ConvertFrom-Json
if ('sha256:'+(Get-FileHash -LiteralPath $runtime.runtime.path).Hash.ToLowerInvariant() -cne $profile.runtime_sha256) {throw 'Core runtime hash'}
$inputs=@('sdk/check_r10ac_contact_frame_capture.ps1',
    'sdk/adapters/godot/gdscript/r10ac_contact_frame_capture_v1.gd',
    'sdk/adapters/godot/gdscript/r10ac_capture_worker_v1.gd',
    'sdk/adapters/godot/gdscript/recovery_contact_frames_v1.gd',
    'sdk/adapters/godot/gdscript/recovery_native_world_v1.gd',
    'sdk/adapters/godot/gdscript/recovery_runtime.gd',
    'sdk/trace_analysis/godot_authoritative_json_transport.gd',
    'sdk/conformance/r10ac_contact_frame_replay.py',
    'sdk/conformance/content_addressed_zero_world_closure.py',
    'sdk/development/recovery_candidates/r10ab-partial-downward-rise-core-v1.json',
    'sdk/development/recovery_candidates/r10ab-partial-downward-rise-core-v1.runtime.json',
    'sdk/adapters/godot/development_candidate_runtimes/r10ab-partial-downward-rise-core-v1.gdextension',
    'tests/test_r10ac_contact_frame_capture.gd','tests/test_r10ac_contact_frames_zero_world.gd')
$before=@($inputs | ForEach-Object { $p=Join-Path $root $_; @{path=$_;sha256=(Get-FileHash -LiteralPath $p).Hash;bytes=(Get-Item -LiteralPath $p).Length} })
$before | ConvertTo-Json | Set-Content (Join-Path $outputPath 'source-before.json')
@{engine=$engine;engine_sha256=(Get-FileHash -LiteralPath $engine).Hash;core=$runtime.runtime.path;core_sha256=(Get-FileHash -LiteralPath $runtime.runtime.path).Hash} | ConvertTo-Json | Set-Content (Join-Path $outputPath 'runtime.json')
. (Join-Path $PSScriptRoot 'locomotion_operation_lock.ps1')
$lock=Enter-SporeSporeLocomotionOperationLock -Role conformance
if(-not $lock.acquired){throw 'Native operation busy'}
$result=[ordered]@{ok=$false;world_build_count=0;solver_step_count=0;physical_acceptance_authority=$false;release_authority=$false}
try {
    Get-SporeSporeLocomotionOperationLockPublicReceipt -Receipt $lock | ConvertTo-Json | Set-Content (Join-Path $outputPath 'lock.json')
    foreach($name in @('worker-parse','capture')) {
        $arguments=@('--headless','--path',$root,'--log-file',(Join-Path $outputPath "$name.engine.log"),'--script')
        if($name -eq 'worker-parse') {$arguments+=@('res://sdk/adapters/godot/gdscript/r10ac_capture_worker_v1.gd','--check-only')}
        else {$arguments+=@('res://tests/test_r10ac_contact_frame_capture.gd','--',(Join-Path $outputPath 'fixtures.json'))}
        @{executable=$engine;arguments=$arguments;timeout_ms=60000;working_directory=$root} | ConvertTo-Json | Set-Content (Join-Path $outputPath "$name.command.json")
        $process=Start-Process -FilePath $engine -ArgumentList $arguments -WorkingDirectory $root -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $outputPath "$name.stdout.log") -RedirectStandardError (Join-Path $outputPath "$name.stderr.log")
        $finished=$process.WaitForExit(60000)
        if(-not $finished){Stop-Process -Id $process.Id -Force;$process.WaitForExit()}
        $errors=(Get-Item -LiteralPath (Join-Path $outputPath "$name.stderr.log")).Length
        @{exit_code=$process.ExitCode;timed_out=(-not $finished);stderr_bytes=$errors;process_id=$process.Id} | ConvertTo-Json | Set-Content (Join-Path $outputPath "$name.execution.json")
        if(-not $finished -or $process.ExitCode -ne 0 -or $errors -ne 0){throw "Native check failed: $name"}
    }
    $fixture=Get-Content -Raw -LiteralPath (Join-Path $outputPath 'fixtures.json') | ConvertFrom-Json -Depth 100
    if(-not $fixture.ok -or $fixture.summary.positive_cases -ne 5 -or $fixture.summary.negative_cases -ne 29){throw 'Fixture result invalid'}
    & 'C:/Program Files/Python311/python.exe' (Join-Path $root 'sdk/conformance/r10ac_contact_frame_replay.py') (Join-Path $outputPath 'fixtures.json') 1> (Join-Path $outputPath 'replay.stdout.log') 2> (Join-Path $outputPath 'replay.stderr.log')
    if($LASTEXITCODE -ne 0){throw 'Independent replay failed'}
    $after=@($inputs | ForEach-Object { $p=Join-Path $root $_; @{path=$_;sha256=(Get-FileHash -LiteralPath $p).Hash;bytes=(Get-Item -LiteralPath $p).Length} })
    $after | ConvertTo-Json | Set-Content (Join-Path $outputPath 'source-after.json')
    foreach($item in $before){if((Get-FileHash -LiteralPath (Join-Path $root $item.path)).Hash -cne $item.sha256){throw "Source changed: $($item.path)"}}
    $result.ok=$true
    $result.capture=$fixture.summary
} catch {$result.error=$_.Exception.Message}
finally {
    Exit-SporeSporeLocomotionOperationLock -Receipt $lock
    $result | ConvertTo-Json -Depth 8 | Set-Content (Join-Path $outputPath 'result.json')
}
Write-Output ('R10AC_CAPTURE_CHECK '+($result | ConvertTo-Json -Compress -Depth 8))
if(-not $result.ok){exit 1}
