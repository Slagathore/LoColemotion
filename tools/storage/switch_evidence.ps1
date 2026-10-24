[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][ValidateSet('Switch','Cleanup')][string]$Stage,
    [Parameter(Mandatory=$true)][string]$AuditDirectory
)

$ErrorActionPreference = 'Stop'
$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$source = Join-Path (Split-Path -Parent $repoRoot) 'SporeSpore_Evidence'
$audit = [IO.Path]::GetFullPath($AuditDirectory)
$python = Join-Path $repoRoot 'sdk\adapters\mujoco\.venv\Scripts\python.exe'
$verifier = Join-Path $PSScriptRoot 'verify_evidence_copy.py'
function Require([bool]$Condition,[string]$Message) { if (-not $Condition) { throw $Message } }
function Read-Record([string]$Name) { Get-Content -Raw -LiteralPath (Join-Path $audit $Name) | ConvertFrom-Json }
function Hash([string]$Path) { (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant() }
function Write-NewRecord([string]$Name,$Value) {
    $path=Join-Path $audit $Name
    $file=[IO.File]::Open($path,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
    $writer=[IO.StreamWriter]::new($file,[Text.UTF8Encoding]::new($false))
    try { $writer.WriteLine(($Value | ConvertTo-Json -Depth 12)) } finally { $writer.Dispose() }
}
function Ordinary([string]$Path) {
    $item=Get-Item -LiteralPath $Path -Force
    Require ($item.PSIsContainer -and -not($item.Attributes -band [IO.FileAttributes]::ReparsePoint)) "Not an ordinary directory: $Path"
}
function Link-Target([string]$Value) {
    if ($Value.StartsWith('\\?\')) { $Value=$Value.Substring(4) }
    [IO.Path]::GetFullPath($Value).TrimEnd('\')
}
function Check-Junction([string]$Path,[string]$Target) {
    $item=Get-Item -LiteralPath $Path -Force
    Require ($item.LinkType -eq 'Junction') "Expected junction: $Path"
    Require ((Link-Target (@($item.Target)[0])) -eq (Link-Target $Target)) "Crossed junction target: $Path"
}
function Check-PhysicalRoot([string]$Path) {
    Ordinary $Path
    $resolved=& $python -B -c 'import pathlib,sys; print(pathlib.Path(sys.argv[1]).resolve(strict=True))' $Path
    Require ($LASTEXITCODE -eq 0 -and $resolved -eq $Path) "Directory resolves outside its declared path: $Path"
}

Require ((git -C $repoRoot rev-parse --show-toplevel).Replace('/','\') -eq $repoRoot) 'Repository root mismatch'
Require ((git -C $repoRoot remote get-url origin) -eq 'https://github.com/Slagathore/LoColemotion.git') 'Repository remote mismatch'
Require ((git -C $repoRoot config core.hooksPath) -eq '.githooks') 'Repository hooks mismatch'
Check-PhysicalRoot $audit
$declaration=Read-Record 'declaration.json'
$verification=Read-Record 'verification.json'
$inventory=Read-Record 'inventory.json'
$copy=Read-Record 'receipt.json'
$destination=[IO.Path]::GetFullPath($declaration.destination)
$identity=Split-Path -Leaf $audit
Require ($identity -match '^evidence-relocation-([a-f0-9]{32})$') 'Migration identity shape'
$backup=Join-Path (Split-Path -Parent $source) ('SporeSpore_Evidence.before-L-'+$Matches[1])
Require ($declaration.source -eq $source -and $verification.source -eq $source -and $verification.destination -eq $destination) 'Crossed migration roots'
Require ([IO.Path]::GetPathRoot($source) -ne [IO.Path]::GetPathRoot($destination)) 'Migration volumes must differ'
Require ($copy.ok -eq $true -and $verification.ok -eq $true -and $copy.cutover_performed -eq $false) 'Copy verification incomplete'
Require ($verification.files_hashed -eq $inventory.counts.file -and $verification.bytes_hashed_per_tree -eq $inventory.logical_bytes) 'Incomplete verified population'
Require ((Hash (Join-Path $audit 'manifest.sqlite')) -eq $verification.manifest_sha256) 'Verified manifest changed'
Require ((Hash $verifier) -eq $declaration.verifier_sha256) 'Verified reader changed'
Check-PhysicalRoot $destination

$mutex=[Threading.Mutex]::new($false,'Global\SporeSpore.Locomotion.PhysicalConformance.Serial.v1')
$owned=$false
try {
    try { $owned=$mutex.WaitOne(0) } catch [Threading.AbandonedMutexException] { $owned=$true }
    Require $owned 'Another project operation owns the mutex'
    if ($Stage -eq 'Switch') {
        Check-PhysicalRoot $source
        Require (-not(Test-Path -LiteralPath $backup)) 'Backup path already exists'
        Require (-not(Test-Path -LiteralPath (Join-Path $audit 'switch.json'))) 'Switch already consumed'
        & $python -B $verifier check --source $source --destination $destination --database (Join-Path $audit 'manifest.sqlite')
        Require ($LASTEXITCODE -eq 0) 'Tree changed after byte verification'
        Write-Output "Verified rename: $source -> $backup"
        Rename-Item -LiteralPath $source -NewName (Split-Path -Leaf $backup)
        try {
            New-Item -ItemType Junction -Path $source -Target $destination | Out-Null
            Check-Junction $source $destination
        } catch {
            # Keep the ordinary original available if junction construction fails.
            if (Test-Path -LiteralPath $source) {
                Check-Junction $source $destination
                Remove-Item -LiteralPath $source -Force
            }
            Rename-Item -LiteralPath $backup -NewName (Split-Path -Leaf $source)
            throw
        }
        Write-NewRecord 'switch.json' ([ordered]@{
            ok=$true;source=$source;destination=$destination;backup=$backup
            manifest_sha256=$verification.manifest_sha256;completed_at_utc=[DateTime]::UtcNow.ToString('o')
            original_removed=$false;switch_program_sha256=(Hash $PSCommandPath)
        })
        Write-Output 'Junction switched. Original remains intact pending reopened evidence checks.'
    } else {
        $switched=Read-Record 'switch.json'
        $validated=Read-Record 'post-switch-validation.json'
        Require ($switched.ok -eq $true -and $switched.source -eq $source -and $switched.destination -eq $destination -and $switched.backup -eq $backup) 'Crossed switch record'
        Require ($switched.switch_program_sha256 -eq (Hash $PSCommandPath)) 'Switch program changed'
        Require ($validated.ok -eq $true -and $validated.worlds_opened -eq 0) 'Post-switch checks incomplete'
        Require ($validated.manifest_sha256 -eq $verification.manifest_sha256) 'Crossed post-switch manifest'
        Require ((Hash (Join-Path $audit 'post-switch-controls/tests/stderr.log')) -eq $validated.controls_stderr_sha256) 'Post-switch control log changed'
        $log=Get-Content -Raw -LiteralPath (Join-Path $audit 'post-switch-controls/tests/stderr.log')
        Require ($log -match '(?m)^Ran 9 tests in ' -and $log.TrimEnd().EndsWith('OK')) 'Post-switch controls did not all pass'
        $reportPath=Join-Path $audit 'post-switch-readiness/report.json'
        Require ((Hash $reportPath) -eq $validated.readiness_sha256) 'Post-switch readiness changed'
        $report=Get-Content -Raw -LiteralPath $reportPath | ConvertFrom-Json
        Require ($report.source.clean -eq $true -and $report.source.matches_origin_main -eq $true -and $report.gate_counts.required_invalid_proof -eq 0 -and $report.gate_counts.informational_invalid_proof -eq 0 -and $report.support_matrix.consistent_with_gate_dispositions -eq $true) 'Reopened readiness is invalid'
        $baselinePath=[IO.Path]::GetFullPath((Join-Path $destination $validated.baseline_readiness_relative_path))
        Require ($baselinePath.StartsWith($destination+'\',[StringComparison]::OrdinalIgnoreCase)) 'Baseline readiness escaped evidence root'
        Require ((Hash $baselinePath) -eq $validated.baseline_readiness_sha256) 'Baseline readiness changed'
        $baseline=Get-Content -Raw -LiteralPath $baselinePath | ConvertFrom-Json
        foreach($count in $baseline.gate_counts.PSObject.Properties) {
            Require ($report.gate_counts.($count.Name) -eq $count.Value) "Readiness disposition changed: $($count.Name)"
        }
        Check-Junction $source $destination
        Check-PhysicalRoot $backup
        # The deletion target must resolve to the ordinary, explicitly named C:
        # backup. It must never resolve through the new canonical junction.
        $resolved=& $python -B -c 'import pathlib,sys; print(pathlib.Path(sys.argv[1]).resolve(strict=True))' $backup
        Require ($resolved -eq $backup -and (Split-Path -Parent $backup) -eq (Split-Path -Parent $source) -and $backup -ne $source) 'Unsafe original-removal target'
        & $python -B $verifier check --source $backup --destination $destination --database (Join-Path $audit 'manifest.sqlite')
        Require ($LASTEXITCODE -eq 0) 'Tree changed before original removal'
        $links=@($inventory.links)
        Require ($links.Count -eq $inventory.counts.link) 'Stored link population changed'
        foreach($entry in $links) {
            $path=[IO.Path]::GetFullPath((Join-Path $backup $entry.path))
            Require ($path.StartsWith($backup+'\',[StringComparison]::OrdinalIgnoreCase)) 'Stored link escaped backup'
            Require ($entry.reparse_tag -eq 2684354563) 'Only inventoried directory junctions may be removed'
            Check-Junction $path $entry.target
        }
        Write-NewRecord 'removal-declaration.json' ([ordered]@{backup=$backup;destination=$destination;source=$source;stored_links=$links;manifest_sha256=$verification.manifest_sha256;validated_at_utc=[DateTime]::UtcNow.ToString('o')})
        foreach($entry in $links) { Remove-Item -LiteralPath (Join-Path $backup $entry.path) -Force }
        $scan=@'
import os,sys
stack=[sys.argv[1]]
while stack:
    with os.scandir(stack.pop()) as entries:
        for entry in entries:
            info=entry.stat(follow_symlinks=False)
            if info.st_file_attributes & 1024: raise RuntimeError('Reparse point remains: '+entry.path)
            if entry.is_dir(follow_symlinks=False): stack.append(entry.path)
print('Original contains no remaining reparse points')
'@
        & $python -B -c $scan $backup
        Require ($LASTEXITCODE -eq 0) 'Unsafe reparse point remains'
        Ordinary $backup
        Check-Junction $source $destination
        $drive=[IO.Path]::GetPathRoot($backup).Substring(0,1)
        $before=(Get-PSDrive -Name $drive).Free
        Write-Output "Removing verified ordinary backup only: $backup"
        Remove-Item -LiteralPath $backup -Recurse -Force
        Require (-not(Test-Path -LiteralPath $backup)) 'Original removal incomplete'
        Ordinary $destination
        Check-Junction $source $destination
        Write-NewRecord 'cleanup.json' ([ordered]@{
            ok=$true;original_removed=$true;source=$source;destination=$destination;backup=$backup
            original_files=$inventory.counts.file;original_logical_bytes=$inventory.logical_bytes
            observed_free_space_increase_bytes=((Get-PSDrive -Name $drive).Free-$before)
            completed_at_utc=[DateTime]::UtcNow.ToString('o')
        })
    }
} finally {
    if ($owned) { $mutex.ReleaseMutex() }
    $mutex.Dispose()
}
