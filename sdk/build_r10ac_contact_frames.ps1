#requires -Version 7.0
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Output,
    [string]$BuildCheckout = 'C:/Users/Cole/CodeStuff/dependencies/godot-sporespore-4.7-r10ac-contact-frames-v7'
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$python = 'C:/Program Files/Python311/python.exe'
$expectedRoot = 'C:/Users/Cole/CodeStuff/games/SporeSpore'
if ((& git -C $root rev-parse --show-toplevel) -cne $expectedRoot) { throw 'Wrong repository root' }
if ((& git -C $root remote get-url origin) -cne 'https://github.com/Slagathore/sporespore.git') { throw 'Wrong origin' }
$outputPath = [IO.Path]::GetFullPath($Output)
$evidenceRoot = [IO.Path]::GetFullPath('C:/Users/Cole/CodeStuff/games/SporeSpore_Evidence') + [IO.Path]::DirectorySeparatorChar
if (-not $outputPath.StartsWith($evidenceRoot, [StringComparison]::OrdinalIgnoreCase)) { throw 'Output outside durable evidence' }
if (Test-Path -LiteralPath $outputPath) { throw 'Build attempt already exists' }
New-Item -ItemType Directory -Path $outputPath | Out-Null
. (Join-Path $PSScriptRoot 'locomotion_operation_lock.ps1')
$lock = Enter-SporeSporeLocomotionOperationLock -Role conformance
if (-not $lock.acquired) { throw 'Native operation lock unavailable' }
$result = [ordered]@{ok=$false; world_build_count=0; solver_step_count=0; physical_acceptance_authority=$false; release_authority=$false}
try {
    Get-SporeSporeLocomotionOperationLockPublicReceipt -Receipt $lock | ConvertTo-Json | Set-Content (Join-Path $outputPath 'lock.json')
    $checker = Join-Path $root 'sdk/conformance/r10ac_contact_frame_patch.py'
    $before = & $python $checker --verify-checkout $BuildCheckout 2> (Join-Path $outputPath 'source-before.stderr.log')
    if ($LASTEXITCODE -ne 0) { throw 'Prospective engine source binding failed' }
    [IO.File]::WriteAllText((Join-Path $outputPath 'source-before.json'), ($before -join "`n"))
    $inputs = @('sdk/build_r10ac_contact_frames.ps1', 'sdk/locomotion_operation_lock.ps1',
        'sdk/conformance/r10ac_contact_frame_patch.py', 'sdk/conformance/r10ac_contact_sampling_component.py',
        'sdk/conformance/r10ac_support_loss_diagnosis.py',
        'sdk/recovery/r10ac_contact_frame_observer_design_v2.json',
        'sdk/adapters/godot/engine_patches/godot_4_7_jolt_contact_frames_v7.patch',
        'sdk/adapters/godot/gdscript/recovery_contact_frames_v1.gd',
        'tests/test_r10ac_contact_frames_zero_world.gd')
    $bindings = @($inputs | ForEach-Object {
        $p=Join-Path $root $_
        @{path=$_;sha256=(Get-FileHash -LiteralPath $p -Algorithm SHA256).Hash;bytes=(Get-Item -LiteralPath $p).Length}
    })
    $bindings | ConvertTo-Json | Set-Content (Join-Path $outputPath 'repository-inputs.json')
    $arguments = @('-m','SCons','-C',$BuildCheckout,'platform=windows','target=editor','dev_build=yes','debug_symbols=no','accesskit=no','d3d12=no','-j12')
    @{executable=$python;arguments=$arguments;working_directory=$root} | ConvertTo-Json | Set-Content (Join-Path $outputPath 'command.json')
    & $python @arguments 1> (Join-Path $outputPath 'build.stdout.log') 2> (Join-Path $outputPath 'build.stderr.log')
    $result.build_exit_code = $LASTEXITCODE
    if ($LASTEXITCODE -ne 0) { throw "Native build failed: $LASTEXITCODE" }
    $after = & $python $checker --verify-checkout $BuildCheckout 2> (Join-Path $outputPath 'source-after.stderr.log')
    if ($LASTEXITCODE -ne 0 -or ($before -join "`n") -cne ($after -join "`n")) { throw 'Engine source changed during build' }
    [IO.File]::WriteAllText((Join-Path $outputPath 'source-after.json'), ($after -join "`n"))
    foreach ($item in $bindings) {
        if ((Get-FileHash -LiteralPath (Join-Path $root $item.path) -Algorithm SHA256).Hash -cne $item.sha256) { throw "Repository input changed: $($item.path)" }
    }
    $artifacts = @()
    foreach ($name in @('godot.windows.editor.dev.x86_64.exe','godot.windows.editor.dev.x86_64.console.exe')) {
        $source = Join-Path $BuildCheckout "bin/$name"
        $destination = Join-Path $outputPath $name
        Copy-Item -LiteralPath $source -Destination $destination
        $artifacts += @{path=$destination;sha256=(Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash;bytes=(Get-Item -LiteralPath $destination).Length}
    }
    $result.artifacts = $artifacts
    $result.ok = $true
} catch {
    $result.error = $_.Exception.Message
} finally {
    Exit-SporeSporeLocomotionOperationLock -Receipt $lock
    $result | ConvertTo-Json -Depth 8 | Set-Content (Join-Path $outputPath 'result.json')
}
Write-Output ('R10AC_CONTACT_FRAME_BUILD ' + ($result | ConvertTo-Json -Compress -Depth 8))
if (-not $result.ok) { exit 1 }
