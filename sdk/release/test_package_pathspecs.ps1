$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'assert_package_pathspecs.ps1')
$repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$inventory = Get-Content -Raw -LiteralPath (Join-Path $PSScriptRoot 'quadruped_package_source_inventory_v1.json') | ConvertFrom-Json
Assert-QuadrupedPackagePathspecs -Pathspecs $inventory.git_pathspecs
$rejected = 0
foreach ($bad in @('../scripts/**','scripts/**',':(exclude)../scripts/**',':(exclude)sdk/../../scripts/**','sdk/../scripts/**','sdk/./core/**','sdk\core\**',':(top)sdk/**',':(exclude,top)sdk/**','C:/sdk/**','sdk/:*/**')) {
    try { Assert-QuadrupedPackagePathspecs -Pathspecs @('sdk/core/**', $bad) }
    catch { $rejected++; continue }
    throw "Unsafe pathspec was accepted: $bad"
}
try { Assert-QuadrupedPackagePathspecs -Pathspecs @('sdk/core/**','sdk/core/**') }
catch { $rejected++ }
if ($rejected -ne 12) { throw 'Missing pathspec refusal' }
$files = @(& git -C $repo ls-files -- @($inventory.git_pathspecs))
if ($LASTEXITCODE -ne 0 -or $files.Count -eq 0) { throw 'Actual package enumeration failed' }
if (@($files | Where-Object { $_ -cnotlike 'sdk/*' -or $_ -clike 'sdk/explorer/phase74_diagnostic/*' }).Count) { throw 'Actual package selection escaped its boundary' }
if ('sdk/explorer/studio/studio_owner.py' -cnotin $files) { throw 'Live Studio was unexpectedly excluded' }
Write-Output "PACKAGE_PATHSPECS_PASS actual_files=$($files.Count) negative_controls=$rejected worlds=0"
