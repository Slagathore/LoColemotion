[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$Destination,
    [Parameter(Mandatory=$true)][string]$AuditDirectory
)

# Copy and verify only. A successful receipt is required before the separately
# reviewed junction switch and removal of the original ordinary directory.
$ErrorActionPreference = 'Stop'
$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$source = Join-Path (Split-Path -Parent $repoRoot) 'SporeSpore_Evidence'
$destinationRoot = [IO.Path]::GetFullPath($Destination)
$auditRoot = [IO.Path]::GetFullPath($AuditDirectory)
$verifier = Join-Path $PSScriptRoot 'verify_evidence_copy.py'
$python = Join-Path $repoRoot 'sdk\adapters\mujoco\.venv\Scripts\python.exe'
if ((git -C $repoRoot rev-parse --show-toplevel).Replace('/', '\') -ne $repoRoot -or
    (git -C $repoRoot remote get-url origin) -ne 'https://github.com/Slagathore/LoColemotion.git' -or
    (git -C $repoRoot config core.hooksPath) -ne '.githooks') { throw 'Repository identity mismatch' }
if ((Get-Item -LiteralPath $source).Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'Source is already a link' }
if ([IO.Path]::GetPathRoot($source) -eq [IO.Path]::GetPathRoot($destinationRoot)) { throw 'Destination must be on a different volume' }
if (Test-Path -LiteralPath $destinationRoot) { throw 'Destination already exists' }
if (Test-Path -LiteralPath $auditRoot) { throw 'Audit directory already exists' }
if ($auditRoot.StartsWith($destinationRoot.TrimEnd('\')+'\', [StringComparison]::OrdinalIgnoreCase)) { throw 'Audit must be outside copied tree' }

$mutex = [Threading.Mutex]::new($false, 'Global\SporeSpore.Locomotion.PhysicalConformance.Serial.v1')
$owned = $false
$watch = [Diagnostics.Stopwatch]::StartNew()
try {
    try { $owned = $mutex.WaitOne(0) } catch [Threading.AbandonedMutexException] { $owned = $true }
    if (-not $owned) { throw 'Another project operation owns the mutex' }
    New-Item -ItemType Directory -Path $auditRoot | Out-Null
    Copy-Item -LiteralPath $PSCommandPath -Destination (Join-Path $auditRoot 'copy_evidence.ps1')
    Copy-Item -LiteralPath $verifier -Destination (Join-Path $auditRoot 'verify_evidence_copy.py')
    $declaration = [ordered]@{
        schema_version='locolemotion_evidence_copy_v1'; source=$source; destination=$destinationRoot
        source_commit=(git -C $repoRoot rev-parse HEAD); started_at_utc=[DateTime]::UtcNow.ToString('o')
        verifier_sha256=(Get-FileHash -LiteralPath $verifier -Algorithm SHA256).Hash.ToLowerInvariant()
        coordinator_sha256=(Get-FileHash -LiteralPath $PSCommandPath -Algorithm SHA256).Hash.ToLowerInvariant()
        copy_flags=@('/E','/COPY:DAT','/DCOPY:DAT','/SJ','/SL','/R:1','/W:1','/MT:4','/NP','/NFL','/NDL','/BYTES')
        deletes_source=$false; follows_stored_junctions=$false
    }
    $declaration | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $auditRoot 'declaration.json') -Encoding utf8NoBOM
    $database = Join-Path $auditRoot 'manifest.sqlite'
    Write-Output "Inventory: $source"
    & $python -B $verifier inventory --source $source --database $database --output (Join-Path $auditRoot 'inventory.json')
    if ($LASTEXITCODE -ne 0) { throw 'Source inventory failed' }
    $inventory = Get-Content -Raw -LiteralPath (Join-Path $auditRoot 'inventory.json') | ConvertFrom-Json
    $driveName = [IO.Path]::GetPathRoot($destinationRoot).Substring(0,1)
    if ((Get-PSDrive -Name $driveName).Free -lt ($inventory.logical_bytes + 10GB)) { throw 'Insufficient destination headroom' }
    New-Item -ItemType Directory -Path $destinationRoot | Out-Null
    # Retain the source access rules as explicit protected rules at the new
    # root. Otherwise the destination would inherit the drive's broader ACL.
    $rootAcl = Get-Acl -LiteralPath $source
    $rootAcl.SetAccessRuleProtection($true,$true)
    Set-Acl -LiteralPath $destinationRoot -AclObject $rootAcl
    Write-Output "Copying to $destinationRoot; progress retained in robocopy.log"
    $copyLog = Join-Path $auditRoot 'robocopy.log'
    & robocopy.exe $source $destinationRoot @($declaration.copy_flags) "/LOG:$copyLog"
    $copyExit = $LASTEXITCODE
    [ordered]@{exit_code=$copyExit;completed_at_utc=[DateTime]::UtcNow.ToString('o')} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $auditRoot 'copy-terminal.json') -Encoding utf8NoBOM
    if ($copyExit -ge 8) { throw "Robocopy failed: $copyExit" }
    Write-Output 'Copy finished; verifying every ordinary file by SHA-256 and checking stored link targets.'
    & $python -B $verifier verify --source $source --destination $destinationRoot --database $database --output (Join-Path $auditRoot 'verification.json')
    if ($LASTEXITCODE -ne 0) { throw 'Copy verification failed; original evidence remains in place' }
    [ordered]@{ok=$true;copy_exit_code=$copyExit;wall_s=$watch.Elapsed.TotalSeconds;source_unchanged=$true;cutover_performed=$false} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $auditRoot 'receipt.json') -Encoding utf8NoBOM
    Write-Output "Copy and verification complete: $auditRoot"
} finally {
    if ($owned) { $mutex.ReleaseMutex() }
    $mutex.Dispose()
}
