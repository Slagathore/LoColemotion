#requires -Version 7.0

[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$closingCommit = "ad4a96316fdd18e488f9e4b2105f8f2ab937eba5"
$authorityRelative = "sdk/turning/forward_displacement_measurement_origin_parity_v1.json"
$auditRelative = "sdk/audit_forward_displacement_measurement_origin_parity_v1.ps1"
$rapierRelative = (
    "sdk/adapters/rapier/src/qsdk_r23d3_phase_balanced/r23d27_physical.rs"
)
$authorityPath = Join-Path $repoRoot $authorityRelative
$auditPath = Join-Path $repoRoot $auditRelative
$rapierPath = Join-Path $repoRoot $rapierRelative
$rapierManifest = Join-Path $repoRoot "sdk\adapters\rapier\Cargo.toml"
$mujocoRoot = Join-Path $repoRoot "sdk\adapters\mujoco"
$mujocoPython = Join-Path $mujocoRoot ".venv\Scripts\python.exe"
$pythonCoreRoot = Join-Path $repoRoot "sdk\python"
$coreLibrary = Join-Path $repoRoot "sdk\target\debug\sporespore_locomotion_core.dll"

function Assert-R23D74OriginReplay([bool]$Condition, [string]$Message) {
    if (-not $Condition) {
        throw "[turning/measurement] R23D74 origin predecessor replay: $Message"
    }
}

function Get-R23D74GitBlobBytes([string]$Commit, [string]$RelativePath) {
    $start = [Diagnostics.ProcessStartInfo]::new()
    $start.FileName = "git"
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    foreach ($argument in @(
        "-C", $repoRoot, "cat-file", "blob", "${Commit}:$RelativePath"
    )) {
        [void]$start.ArgumentList.Add($argument)
    }
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $start
    try {
        Assert-R23D74OriginReplay $process.Start() "could not start Git blob reader"
        $stderrTask = $process.StandardError.ReadToEndAsync()
        $memory = [IO.MemoryStream]::new()
        try {
            $process.StandardOutput.BaseStream.CopyTo($memory)
            $process.WaitForExit()
            $stderr = $stderrTask.GetAwaiter().GetResult()
            Assert-R23D74OriginReplay ($process.ExitCode -eq 0) (
                "Git blob read failed for $RelativePath`: $stderr"
            )
            [byte[]]$bytes = $memory.ToArray()
            return ,$bytes
        } finally {
            $memory.Dispose()
        }
    } finally {
        $process.Dispose()
    }
}

function Get-R23D74RawBytesIdentity([byte[]]$Bytes) {
    return [ordered]@{
        sha256 = "sha256:" + [Convert]::ToHexString(
            [Security.Cryptography.SHA256]::HashData($Bytes)
        ).ToLowerInvariant()
        byte_length = [long]$Bytes.Length
    }
}

function Get-R23D74CanonicalLfBytesIdentity([byte[]]$Bytes) {
    $text = [Text.UTF8Encoding]::new($false, $true).GetString($Bytes)
    $canonical = $text.Replace("`r`n", "`n").Replace("`r", "`n")
    return Get-R23D74RawBytesIdentity ([Text.Encoding]::UTF8.GetBytes($canonical))
}

function Get-R23D74CanonicalLfFileIdentity([string]$Path) {
    return Get-R23D74CanonicalLfBytesIdentity ([IO.File]::ReadAllBytes($Path))
}

Assert-R23D74OriginReplay (
    (& git -C $repoRoot rev-parse --show-toplevel).Trim() -ceq
        $repoRoot.Replace("\", "/") -and
    (& git -C $repoRoot remote get-url origin).Trim() -ceq
        "https://github.com/Slagathore/sporespore.git" -and
    (& git -C $repoRoot cat-file -t "${closingCommit}^{commit}").Trim() -ceq "commit"
) "repository, remote, or immutable closing commit changed"
foreach ($path in @(
    $authorityPath,
    $auditPath,
    $rapierPath,
    $rapierManifest,
    $mujocoPython
)) {
    Assert-R23D74OriginReplay (Test-Path -LiteralPath $path -PathType Leaf) (
        "required path missing: $path"
    )
}

# The observed development authority and its original audit remain byte-for-byte
# immutable.  The successor route is checked separately below; the old audit is
# intentionally not edited to bless a later, additive Rust source file.
foreach ($relative in @($authorityRelative, $auditRelative)) {
    [byte[]]$historicalBytes = Get-R23D74GitBlobBytes $closingCommit $relative
    [byte[]]$currentBytes = [IO.File]::ReadAllBytes((Join-Path $repoRoot $relative))
    $historical = Get-R23D74RawBytesIdentity $historicalBytes
    $current = Get-R23D74RawBytesIdentity $currentBytes
    Assert-R23D74OriginReplay (
        [string]$current.sha256 -ceq [string]$historical.sha256 -and
        [long]$current.byte_length -eq [long]$historical.byte_length
    ) "immutable predecessor authority or audit changed: $relative"
}

$authority = Get-Content -LiteralPath $authorityPath -Raw |
    ConvertFrom-Json -AsHashtable -Depth 100
Assert-R23D74OriginReplay (
    [string]$authority.schema_version -ceq
        "sporespore_forward_displacement_measurement_origin_parity_v1" -and
    [string]$authority.status -ceq
        "implemented_complete_zero_world_source_conformance_passed_physical_not_opened" -and
    [string]$authority.ledger_scope.question_class -ceq "development" -and
    [string]$authority.source_authority.implementation_parent_commit -ceq
        "faea0fadf31268699ec7c0ef5d96ca549423c0f5" -and
    [string]$authority.measurement_contract.prospective_policy_id -ceq
        "evidence_window_start_semantic_step_v1" -and
    [int]$authority.measurement_contract.evidence_start_controller_semantic_step -eq 472 -and
    -not [bool]$authority.measurement_contract.terminal_threshold_changed -and
    -not [bool]$authority.measurement_contract.selector_changed -and
    -not [bool]$authority.measurement_contract.evaluator_changed -and
    -not [bool]$authority.measurement_contract.historical_report_changed -and
    [int]$authority.complete_engine_population.declared_engine_count -eq 3 -and
    [int]$authority.complete_engine_population.source_conforming_engine_count -eq 3 -and
    [int]$authority.zero_world_conformance.model_construction_count -eq 0 -and
    [int]$authority.zero_world_conformance.world_attempt_count -eq 0 -and
    [int]$authority.zero_world_conformance.world_build_count -eq 0 -and
    [int]$authority.zero_world_conformance.solver_step_count -eq 0 -and
    -not [bool]$authority.zero_world_conformance.physical_execution_authorized -and
    -not [bool]$authority.claims.finite_three_engine_turning -and
    -not [bool]$authority.claims.cross_engine_physical_equivalence
) "historical measurement-origin claim boundary changed"

$historicalProducerCount = 0
foreach ($engineId in @("godot_jolt", "rapier_parry", "mujoco")) {
    $producer = $authority.complete_engine_population.engines[$engineId]
    $relative = [string]$producer.producer_path
    [byte[]]$historicalBytes = Get-R23D74GitBlobBytes $closingCommit $relative
    $historical = Get-R23D74CanonicalLfBytesIdentity $historicalBytes
    Assert-R23D74OriginReplay (
        [string]$historical.sha256 -ceq
            [string]$producer.producer_canonical_lf_sha256 -and
        [long]$historical.byte_length -eq
            [long]$producer.producer_canonical_lf_byte_length
    ) "historical $engineId producer no longer matches its observed authority"
    $historicalProducerCount += 1
}
Assert-R23D74OriginReplay ($historicalProducerCount -eq 3) (
    "historical producer population changed"
)

# Godot and MuJoCo did not need a successor source edit.  Rapier did: R23D74
# adds a new route to the already-conforming shared kernel.  Preserve the old
# identity as history, require the new route to be visibly additive, then rerun
# the focused live source controls that do not construct a model or world.
foreach ($engineId in @("godot_jolt", "mujoco")) {
    $producer = $authority.complete_engine_population.engines[$engineId]
    $current = Get-R23D74CanonicalLfFileIdentity (
        Join-Path $repoRoot ([string]$producer.producer_path)
    )
    Assert-R23D74OriginReplay (
        [string]$current.sha256 -ceq
            [string]$producer.producer_canonical_lf_sha256 -and
        [long]$current.byte_length -eq
            [long]$producer.producer_canonical_lf_byte_length
    ) "unchanged live $engineId producer drifted"
}
$historicalRapier = $authority.complete_engine_population.engines.rapier_parry
$currentRapier = Get-R23D74CanonicalLfFileIdentity $rapierPath
$rapierText = [IO.File]::ReadAllText(
    $rapierPath,
    [Text.UTF8Encoding]::new($false, $true)
)
Assert-R23D74OriginReplay (
    [string]$currentRapier.sha256 -cne
        [string]$historicalRapier.producer_canonical_lf_sha256 -and
    $rapierText.Contains("R23D74_ROUTE", [StringComparison]::Ordinal) -and
    $rapierText.Contains(
        "ForwardDisplacementMeasurementOriginPlan::EvidenceWindowStart",
        [StringComparison]::Ordinal
    ) -and
    $rapierText.Contains(
        "semantic_step: EVIDENCE_WINDOW_START_SEMANTIC_STEP",
        [StringComparison]::Ordinal
    )
) "Rapier successor source change was not isolated to an explicit R23D74 origin route"

$rapierLines = @(& cargo test --manifest-path $rapierManifest `
    forward_measurement -- --nocapture 2>&1 | ForEach-Object { [string]$_ })
Assert-R23D74OriginReplay (
    $LASTEXITCODE -eq 0 -and
    ($rapierLines -join "`n") -match "2 passed"
) "live Rapier origin controls failed: $($rapierLines -join ' ')"
Assert-R23D74OriginReplay (Test-Path -LiteralPath $coreLibrary -PathType Leaf) (
    "debug locomotion core missing after focused Rapier controls"
)

$mujocoTestPath = Join-Path $mujocoRoot "test_forward_displacement_measurement_origin.py"
$mujocoExistingTestPath = Join-Path $mujocoRoot "test_qsdk_r23d3_phase_balanced.py"
$savedPythonPath = [Environment]::GetEnvironmentVariable("PYTHONPATH", "Process")
$savedLibrary = [Environment]::GetEnvironmentVariable(
    "SPORESPORE_LOCOMOTION_LIBRARY",
    "Process"
)
try {
    $env:PYTHONDONTWRITEBYTECODE = "1"
    $env:PYTHONPATH = $mujocoRoot + [IO.Path]::PathSeparator + $pythonCoreRoot
    $env:SPORESPORE_LOCOMOTION_LIBRARY = $coreLibrary
    Push-Location $mujocoRoot
    try {
        $mujocoLines = @(& $mujocoPython -B -m unittest -v `
            ([IO.Path]::GetFileName($mujocoExistingTestPath)) `
            ([IO.Path]::GetFileName($mujocoTestPath)) 2>&1 |
            ForEach-Object { [string]$_ })
        $mujocoExitCode = $LASTEXITCODE
    } finally {
        Pop-Location
    }
} finally {
    [Environment]::SetEnvironmentVariable("PYTHONPATH", $savedPythonPath, "Process")
    [Environment]::SetEnvironmentVariable(
        "SPORESPORE_LOCOMOTION_LIBRARY",
        $savedLibrary,
        "Process"
    )
}
$mujocoOutput = $mujocoLines -join "`n"
Assert-R23D74OriginReplay (
    $mujocoExitCode -eq 0 -and
    $mujocoOutput -match "Ran 8 tests" -and
    $mujocoOutput -match "OK"
) "live MuJoCo origin controls failed: $mujocoOutput"

$receipt = [ordered]@{
    schema_version = "sporespore_qsdk_r23d74_measurement_origin_predecessor_replay_v1"
    predecessor_authority_commit = $closingCommit
    predecessor_authority_and_audit_immutable = $true
    historical_producer_identity_count = 3
    historical_result_changed = $false
    live_unchanged_producer_count = 2
    live_rapier_successor_route_explicit = $true
    live_rapier_origin_test_count = 2
    live_mujoco_origin_test_count = 8
    r23d74_native_worker_preflight_still_required_by_outer_gate = $true
    model_construction_count = 0
    world_attempt_count = 0
    world_build_count = 0
    solver_step_count = 0
    physical_execution_authorized = $false
    physical_acceptance_authority = $false
}
Write-Output (
    "QSDK_R23D74_MEASUREMENT_ORIGIN_PREDECESSOR_REPLAY_PASS " +
    ($receipt | ConvertTo-Json -Compress -Depth 100)
)
Write-Output (
    "[turning/measurement] R23D74 predecessor replay PASS: " +
    "historical authority immutable, historical producers=3/3, " +
    "live unchanged producers=2/2, Rapier tests=2, MuJoCo tests=8, " +
    "models=0 worlds=0 solver_steps=0"
)
