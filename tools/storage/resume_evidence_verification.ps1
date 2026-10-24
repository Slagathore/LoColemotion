[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$PreviousAuditDirectory,
    [Parameter(Mandatory=$true)][string]$AuditDirectory
)

# Reuse a completed data copy, retain its failed verification, repair only the
# copied ACLs, and rehash every file from the beginning in a fresh audit.
$ErrorActionPreference='Stop'
$repoRoot=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$previous=[IO.Path]::GetFullPath($PreviousAuditDirectory)
$audit=[IO.Path]::GetFullPath($AuditDirectory)
$source=Join-Path (Split-Path -Parent $repoRoot) 'SporeSpore_Evidence'
$python=Join-Path $repoRoot 'sdk\adapters\mujoco\.venv\Scripts\python.exe'
$verifier=Join-Path $PSScriptRoot 'verify_evidence_copy.py'
$repair=Join-Path $PSScriptRoot 'repair_evidence_permissions.py'
function Require([bool]$Condition,[string]$Message) { if (-not $Condition) { throw $Message } }
function Hash([string]$Path) { (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant() }
function Read-Previous([string]$Name) { Get-Content -Raw -LiteralPath (Join-Path $previous $Name) | ConvertFrom-Json }
function Write-Record([string]$Name,$Value) {
    $path=Join-Path $audit $Name
    $file=[IO.File]::Open($path,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
    $writer=[IO.StreamWriter]::new($file,[Text.UTF8Encoding]::new($false))
    try { $writer.WriteLine(($Value | ConvertTo-Json -Depth 12)) } finally { $writer.Dispose() }
}
Require ((git -C $repoRoot rev-parse --show-toplevel).Replace('/','\') -eq $repoRoot) 'Repository root mismatch'
Require ((git -C $repoRoot remote get-url origin) -eq 'https://github.com/Slagathore/LoColemotion.git') 'Repository remote mismatch'
Require ((git -C $repoRoot config core.hooksPath) -eq '.githooks') 'Repository hooks mismatch'
Require (-not(Test-Path -LiteralPath $audit)) 'Successor audit already exists'
Require ((Split-Path -Leaf $audit) -match '^evidence-relocation-[a-f0-9]{32}$') 'Successor identity shape'
Require ((Split-Path -Parent $audit) -eq (Split-Path -Parent $previous)) 'Successor audit must be beside predecessor'
$old=Read-Previous 'declaration.json'
$failed=Read-Previous 'verification.json'
$copied=Read-Previous 'copy-terminal.json'
$destination=[IO.Path]::GetFullPath($old.destination)
Require ($old.source -eq $source -and $failed.source -eq $source -and $failed.destination -eq $destination) 'Crossed predecessor roots'
Require ($failed.ok -eq $false -and $failed.error.StartsWith('ValueError: Access rules differ: ')) 'Only the retained ACL failure may resume here'
Require ($copied.exit_code -ge 0 -and $copied.exit_code -lt 8) 'Predecessor data copy did not complete'
Require ((Hash (Join-Path $previous 'manifest.sqlite')) -eq $failed.manifest_sha256) 'Predecessor manifest changed'
Require ((Hash (Join-Path $previous 'verify_evidence_copy.py')) -eq $old.verifier_sha256) 'Predecessor verifier changed'
Require ((Hash (Join-Path $previous 'copy_evidence.ps1')) -eq $old.coordinator_sha256) 'Predecessor copier changed'
Require ($old.deletes_source -eq $false -and $old.follows_stored_junctions -eq $false) 'Unexpected predecessor scope'
Require ([IO.Path]::GetPathRoot($source) -ne [IO.Path]::GetPathRoot($destination)) 'Volumes must differ'
Require (-not $audit.StartsWith($destination.TrimEnd('\')+'\',[StringComparison]::OrdinalIgnoreCase)) 'Audit must remain outside copied tree'
foreach($path in @($source,$destination,$previous)) {
    $item=Get-Item -LiteralPath $path -Force
    Require ($item.PSIsContainer -and -not($item.Attributes -band [IO.FileAttributes]::ReparsePoint)) "Expected ordinary directory: $path"
    $resolved=& $python -B -c 'import pathlib,sys; print(pathlib.Path(sys.argv[1]).resolve(strict=True))' $path
    Require ($LASTEXITCODE -eq 0 -and $resolved -eq $path) "Aliased root: $path"
}

$mutex=[Threading.Mutex]::new($false,'Global\SporeSpore.Locomotion.PhysicalConformance.Serial.v1')
$owned=$false
$watch=[Diagnostics.Stopwatch]::StartNew()
try {
    try { $owned=$mutex.WaitOne(0) } catch [Threading.AbandonedMutexException] { $owned=$true }
    Require $owned 'Another project operation owns the mutex'
    New-Item -ItemType Directory -Path $audit | Out-Null
    $acl=Get-Acl -LiteralPath $source
    $acl.SetAccessRuleProtection($true,$true)
    Set-Acl -LiteralPath $audit -AclObject $acl
    $scope=[ordered]@{subsystem='storage';engine_scope='core';authority_mode='development';question_class='development'}
    Write-Record 'declaration.json' ([ordered]@{
        schema_version='locolemotion_evidence_verification_successor_v1';ledger_scope=$scope
        source=$source;destination=$destination;source_commit=(git -C $repoRoot rev-parse HEAD)
        predecessor_audit=$previous;predecessor_verification_sha256=(Hash (Join-Path $previous 'verification.json'))
        predecessor_manifest_sha256=$failed.manifest_sha256;predecessor_copy_terminal_sha256=(Hash (Join-Path $previous 'copy-terminal.json'))
        predecessor_inventory_sha256=(Hash (Join-Path $previous 'inventory.json'))
        started_at_utc=[DateTime]::UtcNow.ToString('o')
        verifier_sha256=(Hash $verifier);permission_repair_sha256=(Hash $repair);coordinator_sha256=(Hash $PSCommandPath)
        reuses_completed_data_copy=$true;resumes_partial_hashes=$false;deletes_source=$false;follows_stored_junctions=$false
    })
    foreach($path in @($verifier,$repair,$PSCommandPath)) { Copy-Item -LiteralPath $path -Destination $audit }
    foreach($name in @('inventory.json','manifest.sqlite','copy-terminal.json')) {
        Copy-Item -LiteralPath (Join-Path $previous $name) -Destination (Join-Path $audit $name)
    }
    $database=Join-Path $audit 'manifest.sqlite'
    Write-Output 'Checking all source entries and restoring differing copied DACLs without following links.'
    & $python -B $repair --source $source --destination $destination --database $database --output (Join-Path $audit 'permissions')
    Require ($LASTEXITCODE -eq 0) 'Permission repair incomplete; source remains in place'
    Write-Output 'Comparing both complete trees, permissions and every file SHA-256 from the beginning.'
    & $python -B $verifier verify --source $source --destination $destination --database $database --output (Join-Path $audit 'verification.json')
    Require ($LASTEXITCODE -eq 0) 'Successor verification failed; source remains in place'
    Write-Record 'receipt.json' ([ordered]@{
        ok=$true;ledger_scope=$scope;copy_exit_code=$copied.exit_code;wall_s=$watch.Elapsed.TotalSeconds
        source_unchanged=$true;cutover_performed=$false;predecessor_audit=$previous
        permission_repair_sha256=(Hash (Join-Path $audit 'permissions/receipt.json'));worlds_opened=0
    })
} finally {
    if ($owned) { $mutex.ReleaseMutex() }
    $mutex.Dispose()
}
