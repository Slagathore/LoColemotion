[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Installation,
    [Parameter(Mandatory)][string]$EvidenceRoot,
    [Parameter(Mandatory)][string]$Python,
    [string]$ShortcutName = 'LoColemotion Studio'
)
$ErrorActionPreference = 'Stop'
$installationPath = [IO.Path]::GetFullPath($Installation)
$sourcePath = Join-Path $installationPath 'source'
$launcherPath = Join-Path $sourcePath 'sdk/explorer/studio/open_studio.ps1'
$configPath = Join-Path $installationPath 'dependencies.json'
$recordPath = Join-Path $installationPath 'installation.json'
if (Test-Path -LiteralPath $recordPath) { throw 'Installation record already exists' }
$evidencePath = [IO.Path]::GetFullPath($EvidenceRoot)
$Python = [IO.Path]::GetFullPath($Python)
if ($ShortcutName.IndexOfAny([IO.Path]::GetInvalidFileNameChars()) -ge 0 -or [string]::IsNullOrWhiteSpace($ShortcutName)) { throw 'Invalid shortcut name' }
foreach ($path in @($launcherPath, $configPath, $Python)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Missing installation dependency: $path" }
    if ($path.Contains('"')) { throw 'Quoted path is unsupported' }
}
$check = 'import sys; from pathlib import Path; root=Path(sys.argv[1]); sys.path.insert(0,str(root/"sdk/explorer/studio")); from studio_layout import isolated_source; from studio_portability import load_dependencies,evidence_destination; source=isolated_source(root); load_dependencies(Path(sys.argv[2]),source,sys.executable); evidence_destination(Path(sys.argv[3])/"installation-check",Path(sys.argv[3]),source_root=root); print(source)'
$sourceCommit = (& $Python -B -c $check $sourcePath $configPath $evidencePath).Trim()
if ($LASTEXITCODE -ne 0) { throw 'Isolated source validation refused installation' }
$desktop = [Environment]::GetFolderPath('Desktop')
$shortcutPath = Join-Path $desktop ($ShortcutName + '.lnk')
if (Test-Path -LiteralPath $shortcutPath) { throw "Preserve the existing shortcut: $shortcutPath" }
$shell = New-Object -ComObject WScript.Shell
$shortcut = $shell.CreateShortcut($shortcutPath)
$shortcut.TargetPath = Join-Path $env:SystemRoot 'System32/WindowsPowerShell/v1.0/powershell.exe'
$shortcut.Arguments = '-NoLogo -NoProfile -WindowStyle Hidden -File "' + $launcherPath + '" -Config "' + $configPath + '" -EvidenceRoot "' + $evidencePath + '" -Python "' + $Python + '"'
$shortcut.WorkingDirectory = Split-Path $launcherPath -Parent
$shortcut.Description = 'Live native physics, generated bodies, interactive kicks and retained scenario history'
$shortcut.Save()
$retained = $shell.CreateShortcut($shortcutPath)
if ($retained.TargetPath -ne $shortcut.TargetPath -or $retained.Arguments -ne $shortcut.Arguments) { throw 'Shortcut readback mismatch' }
$record = [ordered]@{
    schema_version = 'sporespore_studio_local_installation_v1'
    ledger_scope = @{ subsystem = 'explorer'; engine_scope = '3e'; authority_mode = 'development'; question_class = 'development' }
    source_commit = $sourceCommit
    shortcut = $shortcutPath
    shortcut_sha256 = (Get-FileHash -LiteralPath $shortcutPath).Hash.ToLowerInvariant()
    launcher = $launcherPath
    dependencies = $configPath
    layout_manifest = Join-Path $sourcePath 'studio-layout.json'
    external_runtime_dependencies = $true
    python = $Python
    evidence_root = $evidencePath
    dependencies_sha256 = (Get-FileHash -LiteralPath $configPath).Hash.ToLowerInvariant()
    release_authority = $false
    physical_acceptance_authority = $false
}
[IO.File]::WriteAllText($recordPath, ($record | ConvertTo-Json -Depth 5) + "`n", [Text.UTF8Encoding]::new($false))
$record | ConvertTo-Json -Depth 5
