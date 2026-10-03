#requires -Version 7.0

$ErrorActionPreference = "Stop"
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$expectedRoot = "C:\Users\Cole\CodeStuff\games\SporeSpore"
if ($repoRoot -cne $expectedRoot) {
    throw "LIVE_EXPLORER_TEST_REPOSITORY_ROOT_MISMATCH:$repoRoot"
}
if ((git -C $repoRoot remote get-url origin).Trim() -cne "https://github.com/Slagathore/sporespore.git") {
    throw "LIVE_EXPLORER_TEST_ORIGIN_MISMATCH"
}

$manifest = Join-Path $repoRoot "sdk\adapters\rapier\Cargo.toml"
$python = Join-Path $repoRoot "sdk\adapters\mujoco\.venv\Scripts\python.exe"
$probe = Join-Path $repoRoot "scripts\tools\locomotion_live_explorer_probe.py"
$mujocoWorker = Join-Path (
    $repoRoot
) "sdk\adapters\mujoco\sporespore_mujoco_adapter\live_explorer_worker.py"
foreach ($path in @($manifest, $python, $probe, $mujocoWorker)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "LIVE_EXPLORER_TEST_DEPENDENCY_MISSING:$path"
    }
}
$mujocoWorkerSource = Get-Content -Raw -LiteralPath $mujocoWorker
if (-not $mujocoWorkerSource.Contains(
    "self.socket.settimeout(None)",
    [StringComparison]::Ordinal
) -or -not $mujocoWorkerSource.Contains(
    "self.socket.shutdown(socket.SHUT_RDWR)",
    [StringComparison]::Ordinal
)) {
    throw "LIVE_EXPLORER_MUJOCO_COMMAND_CHANNEL_NOT_BLOCKING"
}

& cargo build --manifest-path $manifest --bin locomotion_live_explorer
if ($LASTEXITCODE -ne 0) {
    throw "LIVE_EXPLORER_RAPIER_BUILD_FAILED:$LASTEXITCODE"
}
& $python $probe --validate-only --timeout-s 240
if ($LASTEXITCODE -ne 0) {
    throw "LIVE_EXPLORER_NATIVE_PREFLIGHT_FAILED:$LASTEXITCODE"
}
