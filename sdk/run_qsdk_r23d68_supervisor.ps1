#requires -Version 7.0

[CmdletBinding()]
param(
    [switch]$RolePreflight,
    [switch]$AuthorizationGhost,
    [switch]$RunPhysical,
    [switch]$ExpectProductionConformanceLockHeld,
    [string]$CampaignAttestationAdoption = "",
    [string]$OutputRoot = "",
    [string]$Godot = (
        "C:\Users\Cole\CodeStuff\Misc\Godot\" +
        "Godot_v4.7-stable_mono_win64_console.exe"
    ),
    [string]$Python = "",
    [string]$PowerShell = "pwsh",
    [ValidateRange(300, 3600)][int]$CellTimeoutSeconds = 900
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$sdkRoot = [IO.Path]::GetFullPath($PSScriptRoot)
$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $sdkRoot))
$turningRoot = Join-Path $sdkRoot "turning"
$mujocoRoot = Join-Path $sdkRoot "adapters\mujoco"
$mujocoSitePackages = Join-Path $mujocoRoot ".venv\Lib\site-packages"
$mujocoPython = Join-Path $mujocoRoot ".venv\Scripts\python.exe"

$campaignId = (
    "QSDK-R23D68-PRODUCTION-PATH-CONFORMANCE-REPAIRED-" +
    "THREE-ENGINE-TURNING-VALIDATION"
)
$gateId = "QSDK-R23D68"
$stageId = "production_path_conformance_repaired_three_engine_turning_validation"
$campaignSeed = 23185
$profileId = "sporespore_qsdk_r23d60_selected_s169_actuator_cap_profile_v1"
$onsetId = "onset_600"
$engineOrder = @("godot_jolt", "rapier_parry", "mujoco")
$armOffsets = [ordered]@{
    reference_zero = 0.0
    positive_heading = 0.2
    negative_heading = -0.2
}
$hostMappingIds = [ordered]@{
    godot_jolt = "sporespore_godot_hinge_maximum_impulse_cap_mapping_v1"
    rapier_parry = "sporespore_rapier_force_based_outer_impulse_cap_mapping_v1"
    mujoco = "sporespore_mujoco_velocity_force_range_cap_mapping_v1"
}
$cellIds = @(
    foreach ($engineId in $engineOrder) {
        foreach ($armId in $armOffsets.Keys) {
            "r23d68__${engineId}__s${campaignSeed}__${armId}"
        }
    }
)

$preregistrationPath = Join-Path $turningRoot (
    "r23d68_production_path_conformance_repaired_three_engine_turning_" +
    "preregistration_v1.json"
)
$implementationPath = Join-Path $turningRoot (
    "r23d68_production_route_three_engine_turning_implementation_v1.json"
)
$campaignManifestPath = Join-Path $turningRoot (
    "r23d68_campaign_attestation_manifest_v1.json"
)
$materializerPath = Join-Path $turningRoot "materialize_r23d68_implementation.py"
$evaluatorPath = Join-Path $turningRoot (
    "r23d68_production_route_three_engine_turning_evaluator.py"
)
$workerResourcePath = "res://tests/test_sdk_qsdk_r23d68_godot_jolt_worker.gd"
$mujocoWorkerModule = "sporespore_mujoco_adapter.qsdk_r23d68_turning_route"
$coreReleasePath = Join-Path $sdkRoot "target\release\sporespore_locomotion_core.dll"
$godotAdapterPath = Join-Path $sdkRoot "target\debug\sporespore_godot_adapter.dll"
$rapierReleasePath = Join-Path $sdkRoot "target\release\qsdk_r23d68_turning_route.exe"
$rapierManifestPath = Join-Path $sdkRoot "Cargo.toml"
$runtimeHelperPath = Join-Path $sdkRoot "r23d3_reproducible_runtime_materialization.ps1"
$godotReadyMarker = "QSDK_R23D65_GODOT_SUPERVISOR_TERMINATION_READY "

$terminalSuccessSchemas = @("sporespore_qsdk_r23d68_engine_cell_report_v1")
$terminalFailureSchemas = @("sporespore_qsdk_r23d68_worker_failure_v1")
$physicalEnvironmentNames = @(
    "SPORESPORE_QSDK_R23D68_FREEZE",
    "SPORESPORE_QSDK_R23D68_ATTEMPT",
    "SPORESPORE_QSDK_R23D68_TOKEN",
    "SPORESPORE_QSDK_R23D68_STAGE",
    "SPORESPORE_QSDK_R23D68_CELL",
    "SPORESPORE_QSDK_R23D68_ENGINE",
    "SPORESPORE_QSDK_R23D68_ATTEMPT_ROOT",
    "SPORESPORE_QSDK_R23D68_AUTHORITY_REPO_ROOT",
    "SPORESPORE_QSDK_R23D68_PYTHON",
    "SPORESPORE_QSDK_R23D68_POWERSHELL",
    "SPORESPORE_QSDK_R23D65_SUPERVISED_TERMINATION",
    "SPORESPORE_QSDK_R23D65_TERMINATION_NONCE",
    "SPORESPORE_QSDK_R23D65_FREEZE",
    "SPORESPORE_QSDK_R23D65_ATTEMPT",
    "SPORESPORE_QSDK_R23D60_FREEZE",
    "SPORESPORE_QSDK_R23D60_ATTEMPT",
    "SPORESPORE_QSDK_R23D59_FREEZE",
    "SPORESPORE_QSDK_R23D59_ATTEMPT",
    "SPORESPORE_QSDK_R23D58_FREEZE",
    "SPORESPORE_QSDK_R23D58_ATTEMPT",
    "SPORESPORE_QSDK_R23D48_FREEZE",
    "SPORESPORE_QSDK_R23D48_ATTEMPT"
)

. (Join-Path $sdkRoot "content_addressed_artifact_store.ps1")
. (Join-Path $sdkRoot "godot_receipt_terminated_process.ps1")
. (Join-Path $sdkRoot "locomotion_operation_lock.ps1")
. (Join-Path $sdkRoot "locomotion_full_conformance_attestation.ps1")
. (Join-Path $sdkRoot "locomotion_campaign_attestation_adoption.ps1")
. (Join-Path $sdkRoot "locomotion_terminal_execution_projection.ps1")
. (Join-Path $sdkRoot "process_result_projection.ps1")
. (Join-Path $sdkRoot "three_engine_authorization_receipt.ps1")
. $runtimeHelperPath

function Assert-R23D68([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "QSDK-R23D68: $Message" }
}

function Resolve-R23D68Application([string]$Value, [string]$Fallback) {
    $candidate = if ([string]::IsNullOrWhiteSpace($Value)) { $Fallback } else { $Value }
    if (Test-Path -LiteralPath $candidate -PathType Leaf) {
        return [IO.Path]::GetFullPath($candidate)
    }
    $command = Get-Command $candidate -CommandType Application -ErrorAction Stop |
        Select-Object -First 1
    return [IO.Path]::GetFullPath([string]$command.Source)
}

function Get-R23D68Sha256([string]$Path) {
    return "sha256:" + (
        Get-FileHash -LiteralPath $Path -Algorithm SHA256
    ).Hash.ToLowerInvariant()
}

function Get-R23D68ObjectSha256Hex($Value) {
    $raw = $Value | ConvertTo-Json -Compress -Depth 100
    return [Convert]::ToHexString(
        [Security.Cryptography.SHA256]::HashData(
            [Text.Encoding]::UTF8.GetBytes($raw)
        )
    ).ToLowerInvariant()
}

function Invoke-R23D68Git([string[]]$Arguments) {
    $lines = @(& git -C $repoRoot @Arguments 2>&1 | ForEach-Object { [string]$_ })
    if ($LASTEXITCODE -ne 0) {
        throw "QSDK-R23D68 git $($Arguments -join ' ') failed: $($lines -join ' ')"
    }
    return ($lines -join "`n").Trim()
}

function Write-R23D68NewJson([string]$Path, $Value) {
    $resolved = [IO.Path]::GetFullPath($Path)
    if (Test-Path -LiteralPath $resolved) {
        throw "QSDK-R23D68 refuses to overwrite retained evidence: $resolved"
    }
    [void][IO.Directory]::CreateDirectory((Split-Path -Parent $resolved))
    [IO.File]::WriteAllText(
        $resolved,
        ($Value | ConvertTo-Json -Depth 100) + "`n",
        [Text.UTF8Encoding]::new($false)
    )
}

function Write-R23D68NewText([string]$Path, [string]$Value) {
    $resolved = [IO.Path]::GetFullPath($Path)
    if (Test-Path -LiteralPath $resolved) {
        throw "QSDK-R23D68 refuses to overwrite retained evidence: $resolved"
    }
    [void][IO.Directory]::CreateDirectory((Split-Path -Parent $resolved))
    [IO.File]::WriteAllText($resolved, $Value, [Text.UTF8Encoding]::new($false))
}

function Get-R23D68MediaType([string]$Path) {
    switch ([IO.Path]::GetExtension($Path).ToLowerInvariant()) {
        ".json" { return "application/json" }
        ".ps1" { return "text/x-powershell" }
        ".py" { return "text/x-python" }
        ".gd" { return "text/x-gdscript" }
        ".rs" { return "text/x-rust" }
        ".toml" { return "application/toml" }
        ".dll" { return "application/vnd.microsoft.portable-executable" }
        ".exe" { return "application/vnd.microsoft.portable-executable" }
        default { return "application/octet-stream" }
    }
}

function Resolve-R23D68ContentByteSource([string]$Path) {
    $resolved = [IO.Path]::GetFullPath($Path)
    $item = Get-Item -LiteralPath $resolved -Force
    if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -eq 0) {
        return $resolved
    }
    $targets = @($item.Target)
    Assert-R23D68 (
        [string]$item.LinkType -ceq "SymbolicLink" -and
        $targets.Count -eq 1 -and
        -not [string]::IsNullOrWhiteSpace([string]$targets[0])
    ) "content-addressed runtime reparse point is not one exact symbolic link: $resolved"
    $target = [string]$targets[0]
    if (-not [IO.Path]::IsPathFullyQualified($target)) {
        $target = Join-Path (Split-Path -Parent $resolved) $target
    }
    $target = [IO.Path]::GetFullPath($target)
    Assert-R23D68 (Test-Path -LiteralPath $target -PathType Leaf) (
        "content-addressed runtime symbolic-link target is missing: $resolved -> $target"
    )
    return $target
}

function Invoke-R23D68Process {
    param(
        [Parameter(Mandatory)][string]$FileName,
        [Parameter(Mandatory)][string[]]$Arguments,
        [Parameter(Mandatory)][string]$WorkingDirectory,
        [hashtable]$Environment = @{},
        [ValidateRange(1, 7200)][int]$TimeoutSeconds = 900
    )
    $start = [Diagnostics.ProcessStartInfo]::new()
    $start.FileName = $FileName
    $start.WorkingDirectory = $WorkingDirectory
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    foreach ($argument in $Arguments) { [void]$start.ArgumentList.Add($argument) }
    foreach ($name in $physicalEnvironmentNames) { [void]$start.Environment.Remove($name) }
    foreach ($entry in $Environment.GetEnumerator()) {
        $start.Environment[[string]$entry.Key] = [string]$entry.Value
    }
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $start
    $started = [DateTime]::UtcNow
    [void]$process.Start()
    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()
    $timedOut = -not $process.WaitForExit($TimeoutSeconds * 1000)
    if ($timedOut) {
        try { $process.Kill($true) } catch {}
        [void]$process.WaitForExit(10000)
    } else {
        $process.WaitForExit()
    }
    $stdout = $stdoutTask.GetAwaiter().GetResult()
    $stderr = $stderrTask.GetAwaiter().GetResult()
    $exitCode = if ($timedOut) { 124 } else { $process.ExitCode }
    $process.Dispose()
    return [ordered]@{
        exit_code = [int]$exitCode
        timed_out = [bool]$timedOut
        stdout = [string]$stdout
        stderr = [string]$stderr
        started_utc = $started.ToString("o")
        completed_utc = [DateTime]::UtcNow.ToString("o")
    }
}

function Invoke-R23D68GodotWorker {
    param(
        [Parameter(Mandatory)][string[]]$Arguments,
        [Parameter(Mandatory)][hashtable]$Environment,
        [ValidateRange(1, 7200)][int]$TimeoutSeconds = 900
    )
    $workerEnvironment = @{}
    foreach ($entry in $Environment.GetEnumerator()) {
        $workerEnvironment[[string]$entry.Key] = [string]$entry.Value
    }
    $nonce = [Guid]::NewGuid().ToString("N")
    $workerEnvironment["SPORESPORE_QSDK_R23D65_SUPERVISED_TERMINATION"] = "1"
    $workerEnvironment["SPORESPORE_QSDK_R23D65_TERMINATION_NONCE"] = $nonce
    return Invoke-SporeSporeGodotReceiptTerminatedProcess `
        -FileName $godotHost `
        -Arguments $Arguments `
        -WorkingDirectory $repoRoot `
        -ReadyMarkerPrefix $godotReadyMarker `
        -ExpectedNonce $nonce `
        -Environment $workerEnvironment `
        -ScrubEnvironmentNames $physicalEnvironmentNames `
        -TimeoutSeconds $TimeoutSeconds
}

function Get-R23D68MarkerJson([string]$Text, [string[]]$Prefixes) {
    $matches = [Collections.Generic.List[object]]::new()
    foreach ($line in @($Text -split "`r?`n")) {
        foreach ($prefix in $Prefixes) {
            if (([string]$line).StartsWith($prefix, [StringComparison]::Ordinal)) {
                $matches.Add([ordered]@{ line = [string]$line; prefix = $prefix })
            }
        }
    }
    Assert-R23D68 ($matches.Count -eq 1) (
        "expected one terminal marker from [$($Prefixes -join ', ')], observed $($matches.Count)"
    )
    return $matches[0].line.Substring($matches[0].prefix.Length) |
        ConvertFrom-Json -AsHashtable -Depth 100
}

function Get-R23D68PythonEnvironment([string]$CoreLibrary = "") {
    $environment = @{
        PYTHONPATH = (@(
            (Join-Path $sdkRoot "python"),
            $turningRoot,
            $mujocoRoot,
            $mujocoSitePackages
        ) -join [IO.Path]::PathSeparator)
    }
    if (-not [string]::IsNullOrWhiteSpace($CoreLibrary)) {
        $environment["SPORESPORE_LOCOMOTION_LIBRARY"] = (
            [IO.Path]::GetFullPath($CoreLibrary)
        )
    }
    return $environment
}

function Get-R23D68Implementation([string]$PythonHost) {
    foreach ($path in @($materializerPath, $implementationPath, $preregistrationPath, $evaluatorPath)) {
        Assert-R23D68 (Test-Path -LiteralPath $path -PathType Leaf) (
            "required implementation path is missing: $path"
        )
    }
    $materialization = Invoke-R23D68Process -FileName $PythonHost -Arguments @(
        $materializerPath, "check"
    ) -WorkingDirectory $repoRoot -Environment (Get-R23D68PythonEnvironment) `
        -TimeoutSeconds 300
    Assert-R23D68 (
        [int]$materialization.exit_code -eq 0 -and
        -not [bool]$materialization.timed_out -and
        [string]$materialization.stdout -cmatch "QSDK_R23D68_IMPLEMENTATION"
    ) "implementation materialization drifted: $($materialization.stderr) $($materialization.stdout)"
    $implementation = Get-Content -LiteralPath $implementationPath -Raw |
        ConvertFrom-Json -AsHashtable -Depth 100
    Assert-R23D68 (
        [string]$implementation.schema_version -ceq
            "sporespore_qsdk_r23d68_production_route_three_engine_turning_implementation_v1" -and
        [string]$implementation.campaign_id -ceq $campaignId -and
        [string]$implementation.gate_id -ceq $gateId -and
        [bool]$implementation.claims.implementation_complete -and
        [bool]$implementation.claims.complete_zero_world_gate_passed -and
        -not [bool]$implementation.claims.physical_campaign_opened -and
        -not [bool]$implementation.claims.q_sdk_r23_satisfied -and
        @($implementation.ordered_cell_ids).Count -eq 9 -and
        (@($implementation.ordered_cell_ids) -join "|") -ceq ($cellIds -join "|") -and
        @($implementation.dependency_digests.Keys).Count -gt 0 -and
        [int]$implementation.model_construction_count -eq 0 -and
        [int]$implementation.world_attempt_count -eq 0 -and
        [int]$implementation.world_build_count -eq 0 -and
        -not [bool]$implementation.physical_execution_authorized -and
        -not [bool]$implementation.physical_acceptance_authority
    ) "implementation contract semantics changed"
    return $implementation
}

function Get-R23D68SourceBindings($Implementation) {
    $bindings = [Collections.Generic.List[object]]::new()
    foreach ($relative in @($Implementation.dependency_digests.Keys | Sort-Object)) {
        $path = Join-Path $repoRoot ([string]$relative)
        Assert-R23D68 (Test-Path -LiteralPath $path -PathType Leaf) (
            "frozen dependency is missing: $relative"
        )
        $actual = Get-R23D68Sha256 $path
        $declared = [string]$Implementation.dependency_digests[$relative]
        $blob = Invoke-R23D68Git @("rev-parse", "HEAD:$relative")
        $blobRaw = Get-SporeSporeCampaignAttestationGitBlobRawSha256 `
            -RepoRoot $repoRoot -Commit HEAD -RelativePath ([string]$relative)
        Assert-R23D68 (
            $actual -ceq $declared -and
            $actual -ceq $blobRaw -and
            $blob -ceq (Invoke-R23D68Git @("hash-object", "--no-filters", "--", [string]$relative))
        ) "dependency bytes differ from the clean Git source: $relative"
        $bindings.Add([ordered]@{
            path = [string]$relative
            raw_sha256 = $actual
            git_blob_oid = $blob
            git_blob_raw_sha256 = $blobRaw
        })
    }
    Assert-R23D68 ($bindings.Count -eq @($Implementation.dependency_digests.Keys).Count) (
        "complete implementation dependency population was not bound"
    )
    return @($bindings)
}

function Assert-R23D68FrozenBindings($Freeze) {
    foreach ($binding in @($Freeze.source_bindings)) {
        $relative = [string]$binding.path
        $path = Join-Path $repoRoot $relative
        Assert-R23D68 (
            (Test-Path -LiteralPath $path -PathType Leaf) -and
            [string]$binding.raw_sha256 -ceq (Get-R23D68Sha256 $path) -and
            [string]$binding.git_blob_oid -ceq
                (Invoke-R23D68Git @("rev-parse", "HEAD:$relative")) -and
            [string]$binding.git_blob_raw_sha256 -ceq
                (Get-SporeSporeCampaignAttestationGitBlobRawSha256 `
                    -RepoRoot $repoRoot -Commit HEAD -RelativePath $relative)
        ) "frozen source binding changed: $relative"
    }
    foreach ($runtime in @($Freeze.runtime_artifacts) + @($Freeze.external_runtime_bindings)) {
        $path = [IO.Path]::GetFullPath([string]$runtime.path)
        Assert-R23D68 (
            (Test-Path -LiteralPath $path -PathType Leaf) -and
            [string]$runtime.raw_sha256 -ceq (Get-R23D68Sha256 $path)
        ) "frozen runtime changed: $path"
        if ($runtime.Contains("content_byte_source_path")) {
            $contentPath = [IO.Path]::GetFullPath(
                [string]$runtime.content_byte_source_path
            )
            Assert-R23D68 (
                (Test-Path -LiteralPath $contentPath -PathType Leaf) -and
                [string]$runtime.raw_sha256 -ceq (Get-R23D68Sha256 $contentPath)
            ) "frozen content-byte source changed: $contentPath"
        }
    }
}

function Publish-R23D68Inputs(
    $SourceBindings,
    $RuntimeArtifacts,
    $ExternalRuntimeBindings,
    [string]$AdoptionPath
) {
    $source = @(
        foreach ($binding in @($SourceBindings)) {
            Publish-SporeSporeContentAddressedArtifact -RepoRoot $repoRoot `
                -ArtifactPath (Join-Path $repoRoot ([string]$binding.path)) `
                -MediaType (Get-R23D68MediaType ([string]$binding.path))
        }
    )
    $runtime = @(
        foreach ($binding in @($RuntimeArtifacts) + @($ExternalRuntimeBindings)) {
            $artifactPath = if ($binding.Contains("content_byte_source_path")) {
                [string]$binding.content_byte_source_path
            } else { [string]$binding.path }
            Publish-SporeSporeContentAddressedArtifact -RepoRoot $repoRoot `
                -ArtifactPath $artifactPath `
                -MediaType ([string]$binding.media_type)
        }
    )
    $adoption = Publish-SporeSporeContentAddressedArtifact -RepoRoot $repoRoot `
        -ArtifactPath $AdoptionPath -MediaType "application/json"
    return [ordered]@{
        source_bindings = $source
        runtime_bindings = $runtime
        campaign_attestation_adoption = $adoption
        physical_acceptance_authority = $false
    }
}

function Get-R23D68TerminalFailure(
    [string]$EngineId,
    [string]$ArmId,
    [string]$SourceCommit,
    [string]$Code,
    [int]$WorldAttemptCount = 0,
    [int]$WorldBuildCount = 0,
    [bool]$WorldBuildCountExact = $true,
    [int]$WorldBuildCountLowerBound = $WorldBuildCount,
    [int]$WorldBuildCountUpperBound = $WorldBuildCount
) {
    return [ordered]@{
        schema_version = "sporespore_qsdk_r23d68_worker_failure_v1"
        campaign_id = $campaignId
        gate_id = $gateId
        question_class = "finite_decision"
        stage_id = $stageId
        cell_id = "r23d68__${EngineId}__s${campaignSeed}__${ArmId}"
        engine_id = $EngineId
        campaign_seed = $campaignSeed
        profile_id = $profileId
        host_mapping_id = [string]$hostMappingIds[$EngineId]
        onset_id = $onsetId
        turn_start_semantic_step = 600
        arm_id = $ArmId
        turn_heading_offset_rad = [double]$armOffsets[$ArmId]
        source_commit = $SourceCommit
        failure_stage = "supervisor_transport"
        failure_code = $Code
        model_construction_count = $WorldBuildCount
        world_attempt_count = $WorldAttemptCount
        world_build_count = $WorldBuildCount
        world_build_count_exact = $WorldBuildCountExact
        world_build_count_lower_bound = $WorldBuildCountLowerBound
        world_build_count_upper_bound = $WorldBuildCountUpperBound
        claims = [ordered]@{
            r23d68_finite_three_engine_turning = $false
            finite_three_engine_turning = $false
            portable_basic_turning = $false
            q_sdk_r23_satisfied = $false
            cross_engine_equivalence = $false
            population_robustness = $false
            arbitrary_quadruped_coverage = $false
            prone_to_standing = $false
            release_authorized = $false
            physical_acceptance_authority = $false
        }
        physical_acceptance_authority = $false
    }
}

function Assert-R23D68ObservedTerminal(
    $Terminal,
    [string]$EngineId,
    [string]$ArmId,
    [string]$SourceCommit
) {
    Assert-R23D68 ($Terminal -is [Collections.IDictionary]) (
        "worker terminal is not a JSON object"
    )
    $cellId = "r23d68__${EngineId}__s${campaignSeed}__${ArmId}"
    $expected = [ordered]@{
        campaign_id = $campaignId
        gate_id = $gateId
        stage_id = $stageId
        cell_id = $cellId
        engine_id = $EngineId
        campaign_seed = $campaignSeed
        profile_id = $profileId
        host_mapping_id = [string]$hostMappingIds[$EngineId]
        arm_id = $ArmId
        turn_heading_offset_rad = [double]$armOffsets[$ArmId]
        source_commit = $SourceCommit
    }
    foreach ($entry in $expected.GetEnumerator()) {
        $name = [string]$entry.Key
        Assert-R23D68 ($Terminal.Contains($name)) "worker terminal identity missing: $name"
        $matches = if ($name -ceq "campaign_seed") {
            [int]$Terminal[$name] -eq [int]$entry.Value
        } elseif ($name -ceq "turn_heading_offset_rad") {
            [double]$Terminal[$name] -eq [double]$entry.Value
        } else {
            [string]$Terminal[$name] -ceq [string]$entry.Value
        }
        Assert-R23D68 $matches "worker terminal identity mismatch: $name"
    }
    Assert-R23D68 (
        [string]$Terminal.schema_version -cin
            @($terminalSuccessSchemas + $terminalFailureSchemas) -and
        $Terminal.Contains("model_construction_count") -and
        $Terminal.Contains("world_attempt_count") -and
        $Terminal.Contains("world_build_count") -and
        [int]$Terminal.model_construction_count -ge 0 -and
        [int]$Terminal.world_attempt_count -ge 0 -and
        [int]$Terminal.world_build_count -ge 0 -and
        $Terminal.Contains("physical_acceptance_authority") -and
        -not [bool]$Terminal.physical_acceptance_authority
    ) "worker terminal schema, counts, or authority changed"
}

function Get-R23D68WorkerEnvironment(
    [string]$EngineId,
    [string]$ArmId,
    [string]$FreezePayload,
    [string]$AttemptPayload,
    [string]$Token,
    [string]$AttemptRoot,
    [string]$PythonHost,
    [string]$PowerShellHost,
    [string]$CoreLibrary = ""
) {
    $cellId = "r23d68__${EngineId}__s${campaignSeed}__${ArmId}"
    $environment = @{
        SPORESPORE_QSDK_R23D68_FREEZE = $FreezePayload
        SPORESPORE_QSDK_R23D68_ATTEMPT = $AttemptPayload
        SPORESPORE_QSDK_R23D68_TOKEN = $Token
        SPORESPORE_QSDK_R23D68_STAGE = $stageId
        SPORESPORE_QSDK_R23D68_CELL = $cellId
        SPORESPORE_QSDK_R23D68_ENGINE = $EngineId
        SPORESPORE_QSDK_R23D68_ATTEMPT_ROOT = $AttemptRoot
        SPORESPORE_QSDK_R23D68_AUTHORITY_REPO_ROOT = $repoRoot
        SPORESPORE_QSDK_R23D68_PYTHON = $PythonHost
        SPORESPORE_QSDK_R23D68_POWERSHELL = $PowerShellHost
    }
    if ($EngineId -ceq "mujoco") {
        foreach ($entry in (Get-R23D68PythonEnvironment $CoreLibrary).GetEnumerator()) {
            $environment[[string]$entry.Key] = [string]$entry.Value
        }
    }
    return $environment
}

function Invoke-R23D68Worker {
    param(
        [Parameter(Mandatory)][string]$EngineId,
        [Parameter(Mandatory)][ValidateSet("authorization-preflight", "physical")]
        [string]$Command,
        [Parameter(Mandatory)][string]$ArmId,
        [Parameter(Mandatory)][string]$SourceCommit,
        [Parameter(Mandatory)][hashtable]$Environment,
        [Parameter(Mandatory)][string]$PythonHost,
        [ValidateRange(1, 7200)][int]$TimeoutSeconds = 900
    )
    if ($EngineId -ceq "godot_jolt") {
        $mode = if ($Command -ceq "authorization-preflight") {
            @("--authorization-preflight-only")
        } else { @() }
        $arguments = @(
            "--headless", "--path", $repoRoot,
            "--script", $workerResourcePath, "--"
        ) + $mode + @(
            "--stage", $stageId,
            "--onset", $onsetId,
            "--seed", [string]$campaignSeed,
            "--profile", $profileId,
            "--arm", $ArmId,
            "--source-commit", $SourceCommit
        )
        return Invoke-R23D68GodotWorker -Arguments $arguments `
            -Environment $Environment -TimeoutSeconds $TimeoutSeconds
    }
    if ($EngineId -ceq "rapier_parry") {
        return Invoke-R23D68Process -FileName $rapierReleasePath -Arguments @(
            $Command,
            "--stage", $stageId,
            "--onset", $onsetId,
            "--seed", [string]$campaignSeed,
            "--profile", $profileId,
            "--arm", $ArmId,
            "--source-commit", $SourceCommit
        ) -WorkingDirectory $repoRoot -Environment $Environment `
            -TimeoutSeconds $TimeoutSeconds
    }
    Assert-R23D68 ($EngineId -ceq "mujoco") "undeclared engine: $EngineId"
    return Invoke-R23D68Process -FileName $PythonHost -Arguments @(
        "-m", $mujocoWorkerModule, $Command,
        "--stage", $stageId,
        "--onset", $onsetId,
        "--campaign-seed", [string]$campaignSeed,
        "--profile", $profileId,
        "--arm", $ArmId,
        "--source-commit", $SourceCommit
    ) -WorkingDirectory $repoRoot -Environment $Environment `
        -TimeoutSeconds $TimeoutSeconds
}

function Save-R23D68ProcessStreams($Process, [string]$Root) {
    [void][IO.Directory]::CreateDirectory($Root)
    $stdoutPath = Join-Path $Root "stdout.txt"
    $stderrPath = Join-Path $Root "stderr.txt"
    Write-R23D68NewText $stdoutPath ([string]$Process.stdout)
    Write-R23D68NewText $stderrPath ([string]$Process.stderr)
    return [ordered]@{
        stdout = Publish-SporeSporeContentAddressedArtifact -RepoRoot $repoRoot `
            -ArtifactPath $stdoutPath -MediaType "text/plain"
        stderr = Publish-SporeSporeContentAddressedArtifact -RepoRoot $repoRoot `
            -ArtifactPath $stderrPath -MediaType "text/plain"
    }
}

function Invoke-R23D68Cell {
    param(
        [Parameter(Mandatory)][string]$EngineId,
        [Parameter(Mandatory)][string]$ArmId,
        [Parameter(Mandatory)][string]$SourceCommit,
        [Parameter(Mandatory)][string]$FreezePayload,
        [Parameter(Mandatory)][string]$AttemptPayload,
        [Parameter(Mandatory)][string]$Token,
        [Parameter(Mandatory)][string]$AttemptRoot,
        [Parameter(Mandatory)][string]$CellRoot,
        [Parameter(Mandatory)][string]$PythonHost,
        [Parameter(Mandatory)][string]$PowerShellHost
    )
    [void][IO.Directory]::CreateDirectory($CellRoot)
    $cellId = "r23d68__${EngineId}__s${campaignSeed}__${ArmId}"
    $environment = Get-R23D68WorkerEnvironment `
        -EngineId $EngineId -ArmId $ArmId `
        -FreezePayload $FreezePayload -AttemptPayload $AttemptPayload `
        -Token $Token -AttemptRoot $AttemptRoot `
        -PythonHost $PythonHost -PowerShellHost $PowerShellHost `
        -CoreLibrary $coreReleasePath
    $process = $null
    $streamCas = $null
    $observedTerminal = $null
    try {
        $process = Invoke-R23D68Worker -EngineId $EngineId -Command physical `
            -ArmId $ArmId -SourceCommit $SourceCommit `
            -Environment $environment -PythonHost $PythonHost `
            -TimeoutSeconds $CellTimeoutSeconds
        $streamCas = Save-R23D68ProcessStreams $process $CellRoot
        if ([bool]$process.timed_out) { throw "R23D68_CELL_TIMEOUT" }
        if ($EngineId -ceq "godot_jolt") {
            if (-not [bool]$process.termination_protocol_valid) {
                throw "R23D68_GODOT_TERMINATION_PROTOCOL_INVALID"
            }
            if (-not [bool]$process.supervisor_terminated) {
                throw "R23D68_GODOT_SUPERVISOR_TERMINATION_MISSING"
            }
            if ([string]$process.termination_ready_receipt.worker_receipt_kind -cne "terminal") {
                throw "R23D68_GODOT_TERMINATION_RECEIPT_KIND_INVALID"
            }
        }
        $prefixes = switch ($EngineId) {
            "godot_jolt" {
                @("QSDK_R23D68_GODOT_JOLT_TERMINAL ", "QSDK_R23D68_GODOT_JOLT_FAILURE ")
            }
            "rapier_parry" {
                @("QSDK_R23D68_RAPIER_TERMINAL ", "QSDK_R23D68_RAPIER_FAILURE ")
            }
            default {
                @("QSDK_R23D68_MUJOCO_TERMINAL ", "QSDK_R23D68_MUJOCO_FAILURE ")
            }
        }
        $observedTerminal = Get-R23D68MarkerJson ([string]$process.stdout) $prefixes
        Assert-R23D68ObservedTerminal $observedTerminal $EngineId $ArmId $SourceCommit
        if ([string]$observedTerminal.schema_version -cin $terminalSuccessSchemas) {
            Assert-R23D68 ([int]$process.exit_code -eq 0) (
                "successful worker terminal used a failing process exit code"
            )
        }
        $terminal = $observedTerminal
    } catch {
        if ($null -eq $process) {
            $process = [ordered]@{
                exit_code = 125
                timed_out = $false
                stdout = ""
                stderr = [string]$_.Exception.Message
                started_utc = [DateTime]::UtcNow.ToString("o")
                completed_utc = [DateTime]::UtcNow.ToString("o")
            }
        }
        if ($null -eq $streamCas) {
            $streamCas = Save-R23D68ProcessStreams $process $CellRoot
        }
        $observedAttemptCount = 1
        $observedBuildCount = 1
        $observedCountsExact = $false
        $lowerBound = 0
        if ($observedTerminal -is [Collections.IDictionary] -and
            $observedTerminal.Contains("world_attempt_count") -and
            $observedTerminal.Contains("world_build_count")) {
            $observedAttemptCount = [int]$observedTerminal.world_attempt_count
            $observedBuildCount = [int]$observedTerminal.world_build_count
            $observedCountsExact = $true
            $lowerBound = $observedBuildCount
        }
        $terminal = Get-R23D68TerminalFailure `
            -EngineId $EngineId -ArmId $ArmId -SourceCommit $SourceCommit `
            -Code ("R23D68_SUPERVISOR_TERMINAL_CAPTURE:" + $_.Exception.Message) `
            -WorldAttemptCount $observedAttemptCount `
            -WorldBuildCount $observedBuildCount `
            -WorldBuildCountExact $observedCountsExact `
            -WorldBuildCountLowerBound $lowerBound `
            -WorldBuildCountUpperBound 1
        if ($observedTerminal -is [Collections.IDictionary]) {
            $terminal["observed_worker_terminal"] = $observedTerminal
            $terminal["observed_worker_terminal_preserved"] = $true
        }
    }
    $projection = Get-SporeSporeTerminalExecutionProjection `
        -Terminal $terminal `
        -SuccessSchemas $terminalSuccessSchemas `
        -FailureSchemas $terminalFailureSchemas
    $terminalPath = Join-Path $CellRoot "terminal.json"
    Write-R23D68NewJson $terminalPath $terminal
    $terminalCas = Publish-SporeSporeContentAddressedArtifact -RepoRoot $repoRoot `
        -ArtifactPath $terminalPath -MediaType "application/json"
    $godotProcess = $EngineId -ceq "godot_jolt"
    $processProjection = Get-SporeSporeProcessExecutionProjection `
        -ProcessResult $process -GodotProcess $godotProcess
    return [ordered]@{
        cell_id = $cellId
        engine_id = $EngineId
        campaign_seed = $campaignSeed
        profile_id = $profileId
        arm_id = $ArmId
        turn_heading_offset_rad = [double]$armOffsets[$ArmId]
        process = [ordered]@{
            exit_code = [int]$processProjection.exit_code
            host_exit_code = [int]$processProjection.host_exit_code
            timed_out = [bool]$processProjection.timed_out
            supervisor_terminated = [bool]$processProjection.supervisor_terminated
            termination_protocol_valid = [bool]$processProjection.termination_protocol_valid
            started_utc = [string]$processProjection.started_utc
            completed_utc = [string]$processProjection.completed_utc
            stdout_cas = $streamCas.stdout
            stderr_cas = $streamCas.stderr
        }
        terminal_entry_cas = $terminalCas
        terminal_schema = [string]$terminal.schema_version
        terminal_projection_source = [string]$projection.projection_source
        world_attempt_count = [int]$projection.world_attempt_count
        world_build_count = [int]$projection.world_build_count
        world_build_count_exact = [bool]$projection.world_build_count_exact
        world_build_count_lower_bound = [int]$projection.world_build_count_lower_bound
        world_build_count_upper_bound = [int]$projection.world_build_count_upper_bound
        physical_acceptance_authority = $false
    }
}

function Invoke-R23D68RolePreflight([string]$PythonHost) {
    foreach ($name in @($physicalEnvironmentNames | Where-Object {
        ([string]$_).StartsWith("SPORESPORE_QSDK_R23D68_", [StringComparison]::Ordinal)
    })) {
        Assert-R23D68 (
            [string]::IsNullOrEmpty([Environment]::GetEnvironmentVariable($name, "Process"))
        ) "physical authorization environment is already populated: $name"
    }
    $implementation = Get-R23D68Implementation $PythonHost
    $dependencyCount = 0
    foreach ($relative in @($implementation.dependency_digests.Keys)) {
        $path = Join-Path $repoRoot ([string]$relative)
        Assert-R23D68 (
            (Test-Path -LiteralPath $path -PathType Leaf) -and
            (Get-R23D68Sha256 $path) -ceq
                [string]$implementation.dependency_digests[$relative]
        ) "role-preflight dependency drifted: $relative"
        $dependencyCount += 1
    }
    $terminalControlCount = 0
    foreach ($engineId in $engineOrder) {
        $terminal = Get-R23D68TerminalFailure `
            -EngineId $engineId -ArmId "reference_zero" `
            -SourceCommit ("1" * 40) -Code "R23D68_ROLE_PREFLIGHT_CONTROL"
        $projection = Get-SporeSporeTerminalExecutionProjection `
            -Terminal $terminal -SuccessSchemas $terminalSuccessSchemas `
            -FailureSchemas $terminalFailureSchemas
        Assert-R23D68 (
            [int]$projection.world_attempt_count -eq 0 -and
            [int]$projection.world_build_count -eq 0 -and
            [bool]$projection.world_build_count_exact
        ) "supervisor failure-terminal control changed: $engineId"
        $terminalControlCount += 1
    }
    $cleanGitSourceBindingsChecked = $false
    $cleanGitSourceBindingCount = 0
    $status = Invoke-R23D68Git @("status", "--porcelain=v1", "--untracked-files=all")
    if ([string]::IsNullOrWhiteSpace($status)) {
        $source = Get-SporeSporeAttestationSourceIdentity -RepoRoot $repoRoot `
            -RequireCleanPushedLive
        $sourceBindings = @(Get-R23D68SourceBindings $implementation)
        Assert-R23D68 (
            $sourceBindings.Count -eq @($implementation.dependency_digests.Keys).Count -and
            [string]$source.commit -ceq (Invoke-R23D68Git @("rev-parse", "HEAD"))
        ) "clean Git source-binding preflight was incomplete"
        $cleanGitSourceBindingCount = $sourceBindings.Count
        $cleanGitSourceBindingsChecked = $true
    }
    return [ordered]@{
        schema_version = "sporespore_qsdk_r23d68_supervisor_role_preflight_v1"
        campaign_id = $campaignId
        gate_id = $gateId
        question_class = "finite_decision"
        implementation_dependency_count = $dependencyCount
        terminal_transport_control_count = $terminalControlCount
        clean_git_source_bindings_checked = $cleanGitSourceBindingsChecked
        clean_git_source_binding_count = $cleanGitSourceBindingCount
        supervisor_physical_entry_implemented = $true
        returned_before_model = $true
        model_construction_count = 0
        world_attempt_count = 0
        world_build_count = 0
        physical_execution_authorized = $false
        physical_acceptance_authority = $false
    }
}

function Invoke-R23D68AuthorizationGhost(
    [string]$PythonHost,
    [string]$PowerShellHost,
    [bool]$OuterConformanceLockExpected
) {
    # This is a development/conformance ghost, not a physical question. It
    # drives the same production worker authorization entry points and common
    # supervisor validator over the complete nine-cell population, then
    # destroys its synthetic authorization fixtures before returning.
    $implementation = Get-R23D68Implementation $PythonHost
    foreach ($path in @(
        $coreReleasePath,
        $godotAdapterPath,
        $rapierReleasePath,
        $mujocoPython
    )) {
        Assert-R23D68 (Test-Path -LiteralPath $path -PathType Leaf) (
            "authorization ghost runtime is missing: $path"
        )
    }

    $sourceCommit = Invoke-R23D68Git @("rev-parse", "HEAD")
    $sourceTree = Invoke-R23D68Git @("rev-parse", "HEAD^{tree}")
    Assert-R23D68 (
        $sourceCommit -cmatch '^[0-9a-f]{40}$' -and
        $sourceTree -cmatch '^[0-9a-f]{40}$'
    ) "authorization ghost source identity is invalid"

    $evidenceRoot = [IO.Path]::GetFullPath(
        (Get-SporeSporeArtifactEvidenceRoot -RepoRoot $repoRoot)
    ).TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)
    $ghostLeaf = "r23d68-authorization-ghost-$([Guid]::NewGuid().ToString('N'))"
    $ghostRoot = [IO.Path]::GetFullPath(
        (Join-Path (Join-Path $evidenceRoot "zero-world") $ghostLeaf)
    )
    $requiredPrefix = $evidenceRoot + [IO.Path]::DirectorySeparatorChar
    Assert-R23D68 (
        $ghostRoot.StartsWith($requiredPrefix, [StringComparison]::OrdinalIgnoreCase) -and
        (Split-Path -Leaf $ghostRoot) -cmatch '^r23d68-authorization-ghost-[0-9a-f]{32}$'
    ) "authorization ghost scratch root escaped the durable evidence boundary"

    $lock = $null
    $outerConformanceLockVerified = $false
    if ($OuterConformanceLockExpected) {
        # The campaign-attestation parent already owns the global mutex in a
        # different process. Prove that the production lock is unavailable;
        # do not attempt to reacquire a non-reentrant cross-process mutex.
        $outerProbe = Enter-SporeSporeLocomotionOperationLock -Role physical
        $outerConformanceLockVerified = -not [bool]$outerProbe.acquired
        if ([bool]$outerProbe.acquired) {
            Exit-SporeSporeLocomotionOperationLock -Receipt $outerProbe
        }
        Assert-R23D68 $outerConformanceLockVerified (
            "expected production conformance parent does not hold the global lock"
        )
    } else {
        $lock = Enter-SporeSporeLocomotionOperationLock -Role conformance
        Assert-R23D68 ([bool]$lock.acquired) "global locomotion operation lock is held"
    }
    $receipts = [Collections.Generic.List[object]]::new()
    $missingOkNegatives = [Collections.Generic.List[object]]::new()
    try {
        [void][IO.Directory]::CreateDirectory($ghostRoot)
        $environmentKey = Get-R23D68ObjectSha256Hex ([ordered]@{
            mode = "non_authoritative_zero_world_authorization_ghost"
            source_commit = $sourceCommit
            implementation_raw_sha256 = Get-R23D68Sha256 $implementationPath
            ordered_cell_ids = $cellIds
        })
        $token = [Guid]::NewGuid().ToString("N")
        $attemptId = [Guid]::NewGuid().ToString("N")
        $freeze = [ordered]@{
            schema_version = "sporespore_qsdk_r23d68_physical_freeze_v1"
            status = "frozen_supervisor_only_physical_authorized"
            authorization_fixture_kind = "non_authoritative_zero_world_ghost"
            campaign_id = $campaignId
            gate_id = $gateId
            question_class = "finite_decision"
            preregistration_raw_sha256 = Get-R23D68Sha256 $preregistrationPath
            implementation_contract_raw_sha256 = Get-R23D68Sha256 $implementationPath
            source_commit = $sourceCommit
            origin_main_commit = $sourceCommit
            live_github_main_commit = $sourceCommit
            source_tree_git_oid = $sourceTree
            source_worktree_clean = $true
            complete_zero_world_gate_passed = $true
            implementation_dependency_digests = $implementation.dependency_digests
            dependency_toolchain_environment_key = $environmentKey
            declared_world_count = 9
            ordered_cell_ids = $cellIds
            serial_execution_required = $true
            all_cells_run_regardless_of_intermediate_outcome = $true
            physical_behavior_thresholds_applied = $true
            physical_execution_authorized = $true
            physical_acceptance_authority = $false
        }
        $freezePath = Join-Path $ghostRoot "synthetic-freeze.json"
        Write-R23D68NewJson $freezePath $freeze
        $attempt = [ordered]@{
            schema_version = "sporespore_qsdk_r23d68_physical_attempt_v1"
            authorization_fixture_kind = "non_authoritative_zero_world_ghost"
            campaign_id = $campaignId
            gate_id = $gateId
            question_class = "finite_decision"
            attempt_id = $attemptId
            authorization_token = $token
            source_commit = $sourceCommit
            authority_repo_root = $repoRoot
            freeze_raw_sha256 = Get-R23D68Sha256 $freezePath
            attempt_root = $ghostRoot
            dependency_toolchain_environment_key = $environmentKey
            ordered_cell_ids = $cellIds
            single_use_supervisor_authorization = $true
            operation_lock_held = $true
            one_shot_attempt_unconsumed = $true
            physical_execution_authorized = $true
            physical_acceptance_authority = $false
        }
        $attemptPath = Join-Path $ghostRoot "synthetic-attempt.json"
        Write-R23D68NewJson $attemptPath $attempt

        foreach ($engineId in $engineOrder) {
            foreach ($armId in $armOffsets.Keys) {
                $cellId = "r23d68__${engineId}__s${campaignSeed}__${armId}"
                $environment = Get-R23D68WorkerEnvironment `
                    -EngineId $engineId -ArmId $armId `
                    -FreezePayload $freezePath -AttemptPayload $attemptPath `
                    -Token $token -AttemptRoot $ghostRoot `
                    -PythonHost $PythonHost -PowerShellHost $PowerShellHost `
                    -CoreLibrary $coreReleasePath
                $process = Invoke-R23D68Worker `
                    -EngineId $engineId -Command "authorization-preflight" `
                    -ArmId $armId -SourceCommit $sourceCommit `
                    -Environment $environment -PythonHost $PythonHost `
                    -TimeoutSeconds 300
                Assert-R23D68 (
                    [int]$process.exit_code -eq 0 -and
                    -not [bool]$process.timed_out
                ) "authorization ghost worker failed: $engineId/$armId`n$($process.stderr)`n$($process.stdout)"
                if ($engineId -ceq "godot_jolt") {
                    Assert-R23D68 (
                        [bool]$process.termination_protocol_valid -and
                        [bool]$process.supervisor_terminated -and
                        [string]$process.termination_ready_receipt.worker_receipt_kind -ceq
                            "authorization_preflight"
                    ) "Godot authorization ghost termination protocol failed"
                }
                $marker = switch ($engineId) {
                    "godot_jolt" { "QSDK_R23D68_GODOT_JOLT_AUTHORIZATION " }
                    "rapier_parry" { "QSDK_R23D68_RAPIER_AUTHORIZATION " }
                    default { "QSDK_R23D68_MUJOCO_AUTHORIZATION " }
                }
                $schema = switch ($engineId) {
                    "godot_jolt" { "sporespore_qsdk_r23d68_godot_jolt_authorization_v1" }
                    "rapier_parry" { "sporespore_qsdk_r23d68_rapier_authorization_v1" }
                    default { "sporespore_qsdk_r23d68_mujoco_authorization_v1" }
                }
                $receipt = Get-R23D68MarkerJson ([string]$process.stdout) @($marker)
                $validation = Test-SporeSporeThreeEngineAuthorizationReceipt `
                    -Receipt $receipt -ExpectedSchemaVersion $schema `
                    -ExpectedCampaignId $campaignId -ExpectedGateId $gateId `
                    -ExpectedEngineId $engineId -ExpectedStageId $stageId `
                    -ExpectedCellId $cellId
                Assert-R23D68 ([bool]$validation.ok) (
                    "common authorization receipt rejected ${engineId}/${armId}: " +
                    "$(@($validation.failure_codes) -join ',')"
                )
                $receipts.Add([ordered]@{
                    cell_id = $cellId
                    engine_id = $engineId
                    schema_version = $schema
                    common_validation_passed = $true
                    returned_before_model = $true
                    model_construction_count = 0
                    world_attempt_count = 0
                    world_build_count = 0
                    physical_acceptance_authority = $false
                })

                if ($armId -ceq "reference_zero") {
                    $missingOk = $receipt | ConvertTo-Json -Compress -Depth 100 |
                        ConvertFrom-Json -AsHashtable -Depth 100
                    [void]$missingOk.Remove("ok")
                    $negative = Test-SporeSporeThreeEngineAuthorizationReceipt `
                        -Receipt $missingOk -ExpectedSchemaVersion $schema `
                        -ExpectedCampaignId $campaignId -ExpectedGateId $gateId `
                        -ExpectedEngineId $engineId -ExpectedStageId $stageId `
                        -ExpectedCellId $cellId
                    Assert-R23D68 (
                        -not [bool]$negative.ok -and
                        @($negative.failure_codes).Count -eq 1 -and
                        [string]$negative.failure_codes[0] -ceq "OK_MISSING"
                    ) "missing-ok negative changed for $engineId"
                    $missingOkNegatives.Add([ordered]@{
                        engine_id = $engineId
                        failure_code = "OK_MISSING"
                        rejected = $true
                    })
                }
            }
        }
        Assert-R23D68 (
            $receipts.Count -eq 9 -and
            $missingOkNegatives.Count -eq 3
        ) "authorization ghost population is incomplete"
        return [ordered]@{
            schema_version = "sporespore_qsdk_r23d68_authorization_ghost_v1"
            campaign_id = $campaignId
            gate_id = $gateId
            ledger_scope = [ordered]@{
                subsystem = "turning"
                engine_scope = "3e"
                authority_mode = "zero_world_production_route_ghost"
                question_class = "equivalence_non_inferiority"
            }
            work_class = "development_then_complete_population_equivalence_non_inferiority"
            complete_ordered_nine_cell_population_exercised = $true
            actual_production_worker_authorization_entrypoints_used = $true
            common_supervisor_validator_used = $true
            operation_lock_mode = if ($OuterConformanceLockExpected) {
                "active_parent_conformance_lock_verified"
            } else {
                "standalone_conformance_lock_acquired"
            }
            active_outer_conformance_lock_verified =
                $outerConformanceLockVerified
            receipt_count = $receipts.Count
            ordered_receipts = @($receipts)
            missing_ok_negative_count = $missingOkNegatives.Count
            missing_ok_negatives = @($missingOkNegatives)
            scratch_fixture_retained = $false
            physical_question_asked = $false
            model_construction_count = 0
            world_attempt_count = 0
            world_build_count = 0
            physical_execution_authorized = $false
            physical_acceptance_authority = $false
            q_sdk_r23_satisfied = $false
            release_authority = $false
        }
    } finally {
        try {
            if (Test-Path -LiteralPath $ghostRoot) {
                $resolvedGhost = [IO.Path]::GetFullPath($ghostRoot)
                Assert-R23D68 (
                    $resolvedGhost.StartsWith(
                        $requiredPrefix,
                        [StringComparison]::OrdinalIgnoreCase
                    ) -and
                    (Split-Path -Leaf $resolvedGhost) -ceq $ghostLeaf
                ) "refused unsafe authorization ghost cleanup"
                Remove-Item -LiteralPath $resolvedGhost -Recurse -Force
            }
        } finally {
            if ($null -ne $lock) {
                Exit-SporeSporeLocomotionOperationLock -Receipt $lock
            }
        }
    }
}

$selectedModeCount = @(
    @($RolePreflight, $AuthorizationGhost, $RunPhysical) |
        Where-Object { [bool]$_ }
).Count
Assert-R23D68 ($selectedModeCount -eq 1) (
    "select exactly one of -RolePreflight, -AuthorizationGhost, or -RunPhysical"
)
Assert-R23D68 (
    (Invoke-R23D68Git @("rev-parse", "--show-toplevel")).Replace("/", "\") -ceq
        $repoRoot.TrimEnd("\", "/") -and
    (Invoke-R23D68Git @("remote", "get-url", "origin")) -ceq
        "https://github.com/Slagathore/sporespore.git"
) "repository identity changed"

$pythonHost = Resolve-R23D68Application $Python $mujocoPython
$powerShellHost = Resolve-R23D68Application $PowerShell "pwsh"
$godotHost = Resolve-R23D68Application $Godot $Godot

if ($RolePreflight) {
    Assert-R23D68 (-not $ExpectProductionConformanceLockHeld) (
        "role preflight does not accept an outer conformance-lock assertion"
    )
    Assert-R23D68 ([string]::IsNullOrWhiteSpace($CampaignAttestationAdoption)) (
        "role preflight does not accept physical authorization"
    )
    Assert-R23D68 ([string]::IsNullOrWhiteSpace($OutputRoot)) (
        "role preflight does not accept an evidence output root"
    )
    $receipt = Invoke-R23D68RolePreflight $pythonHost
    Write-Output (
        "QSDK_R23D68_SUPERVISOR_ROLE_PREFLIGHT " +
        ($receipt | ConvertTo-Json -Compress -Depth 100)
    )
    exit 0
}

if ($AuthorizationGhost) {
    Assert-R23D68 ([string]::IsNullOrWhiteSpace($CampaignAttestationAdoption)) (
        "authorization ghost does not accept physical adoption authority"
    )
    Assert-R23D68 ([string]::IsNullOrWhiteSpace($OutputRoot)) (
        "authorization ghost owns only an ephemeral synthetic fixture root"
    )
    $receipt = Invoke-R23D68AuthorizationGhost `
        $pythonHost $powerShellHost ([bool]$ExpectProductionConformanceLockHeld)
    Write-Output (
        "QSDK_R23D68_AUTHORIZATION_GHOST_PASS " +
        ($receipt | ConvertTo-Json -Compress -Depth 100)
    )
    exit 0
}

Assert-R23D68 (-not $ExpectProductionConformanceLockHeld) (
    "physical execution must acquire its own production operation lock"
)
Assert-R23D68 (-not [string]::IsNullOrWhiteSpace($CampaignAttestationAdoption)) (
    "physical execution requires a campaign-attestation adoption"
)
foreach ($path in @(
    $preregistrationPath,
    $implementationPath,
    $campaignManifestPath,
    $rapierManifestPath
)) {
    Assert-R23D68 (Test-Path -LiteralPath $path -PathType Leaf) "missing contract: $path"
}

$source = Get-SporeSporeAttestationSourceIdentity -RepoRoot $repoRoot `
    -RequireCleanPushedLive
$adoptionPath = [IO.Path]::GetFullPath($CampaignAttestationAdoption)
$adoption = Test-SporeSporeCampaignAttestationAdoptionFile -RepoRoot $repoRoot `
    -ManifestPath $campaignManifestPath -AdoptionPath $adoptionPath `
    -Godot $godotHost -Python $pythonHost -ExpectedCampaignId $campaignId
Assert-R23D68 ([bool]$adoption.ok) (
    "campaign-attestation adoption failed: $(@($adoption.failure_codes) -join ',')"
)
Assert-R23D68 (
    [string]$adoption.source.commit -ceq [string]$source.commit -and
    [string]$adoption.source.tree_git_oid -ceq [string]$source.tree_git_oid
) "adoption source differs from the live clean-pushed source"

$lock = Enter-SporeSporeLocomotionOperationLock -Role physical
Assert-R23D68 ([bool]$lock.acquired) "global locomotion operation lock is held"
$attemptConsumed = $false
$completionPath = ""
$resolvedOutput = ""
$attemptId = ""
$cells = [Collections.Generic.List[object]]::new()
try {
    $evidenceRoot = Get-SporeSporeArtifactEvidenceRoot -RepoRoot $repoRoot
    $prior = @(Get-ChildItem -LiteralPath $evidenceRoot -Directory | Where-Object {
        $_.Name -like "qsdk-r23d68-*" -and (
            (Test-Path -LiteralPath (Join-Path $_.FullName "attempt-authorization.json")) -or
            (Test-Path -LiteralPath (Join-Path $_.FullName "completion.json"))
        )
    })
    Assert-R23D68 ($prior.Count -eq 0) "one-shot R23D68 identity already exists"
    $resolvedOutput = if ([string]::IsNullOrWhiteSpace($OutputRoot)) {
        Join-Path $evidenceRoot (
            "qsdk-r23d68-" + [DateTime]::UtcNow.ToString("yyyyMMddTHHmmssZ")
        )
    } else { [IO.Path]::GetFullPath($OutputRoot) }
    $prefix = $evidenceRoot.TrimEnd("\", "/") + [IO.Path]::DirectorySeparatorChar
    $outputParent = [IO.Path]::GetFullPath((Split-Path -Parent $resolvedOutput)).
        TrimEnd("\", "/")
    $outputLeaf = [IO.Path]::GetFileName($resolvedOutput.TrimEnd("\", "/"))
    Assert-R23D68 (
        $resolvedOutput.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase) -and
        $outputParent -ceq $evidenceRoot.TrimEnd("\", "/") -and
        $outputLeaf -clike "qsdk-r23d68-*" -and
        -not (Test-Path -LiteralPath $resolvedOutput)
    ) "output must be a new top-level qsdk-r23d68-* directory under $evidenceRoot"
    [void][IO.Directory]::CreateDirectory($resolvedOutput)
    $completionPath = Join-Path $resolvedOutput "completion.json"

    $implementation = Get-R23D68Implementation $pythonHost
    $coreBuild = Invoke-SporeSporeR23D3PinnedCargo -RepoRoot $repoRoot `
        -SourceCommit ([string]$source.commit) `
        -TargetRoot (Join-Path $sdkRoot "target") `
        -CargoArguments @(
            "build", "--quiet", "--release", "--locked", "--offline",
            "--manifest-path", $rapierManifestPath,
            "--package", "sporespore-locomotion-core"
        )
    $godotBuild = Invoke-SporeSporeR23D3PinnedCargo -RepoRoot $repoRoot `
        -SourceCommit ([string]$source.commit) `
        -TargetRoot (Join-Path $sdkRoot "target") `
        -CargoArguments @(
            "build", "--quiet", "--locked", "--offline",
            "--manifest-path", $rapierManifestPath,
            "--package", "sporespore-godot-adapter"
        )
    $rapierBuild = Invoke-SporeSporeR23D3PinnedCargo -RepoRoot $repoRoot `
        -SourceCommit ([string]$source.commit) `
        -TargetRoot (Join-Path $sdkRoot "target") `
        -CargoArguments @(
            "build", "--quiet", "--release", "--locked", "--offline",
            "--manifest-path", $rapierManifestPath,
            "--bin", "qsdk_r23d68_turning_route"
        )
    foreach ($artifact in @($coreReleasePath, $godotAdapterPath, $rapierReleasePath)) {
        Assert-R23D68 (Test-Path -LiteralPath $artifact -PathType Leaf) (
            "reproducible runtime artifact is missing: $artifact"
        )
    }
    $sourceAfterBuild = Get-SporeSporeAttestationSourceIdentity -RepoRoot $repoRoot `
        -RequireCleanPushedLive
    Assert-R23D68 (
        [string]$sourceAfterBuild.commit -ceq [string]$source.commit -and
        [string]$sourceAfterBuild.tree_git_oid -ceq [string]$source.tree_git_oid
    ) "source changed during reproducible runtime materialization"

    $sourceBindings = Get-R23D68SourceBindings $implementation
    $runtimeArtifacts = @(
        [ordered]@{
            name = "locomotion_core_release"
            path = $coreReleasePath
            raw_sha256 = Get-R23D68Sha256 $coreReleasePath
            media_type = "application/vnd.microsoft.portable-executable"
            build_receipt = $coreBuild
        },
        [ordered]@{
            name = "godot_adapter_debug"
            path = $godotAdapterPath
            raw_sha256 = Get-R23D68Sha256 $godotAdapterPath
            media_type = "application/vnd.microsoft.portable-executable"
            build_receipt = $godotBuild
        },
        [ordered]@{
            name = "rapier_r23d68_release_worker"
            path = $rapierReleasePath
            raw_sha256 = Get-R23D68Sha256 $rapierReleasePath
            media_type = "application/vnd.microsoft.portable-executable"
            build_receipt = $rapierBuild
        }
    )
    $cargoHost = Resolve-R23D68Application "cargo" "cargo"
    $rustcHost = Resolve-R23D68Application "rustc" "rustc"
    $externalRuntimeBindings = @(
        [ordered]@{
            name = "godot_jolt_host"
            path = $godotHost
            content_byte_source_path = Resolve-R23D68ContentByteSource $godotHost
            raw_sha256 = Get-R23D68Sha256 $godotHost
            media_type = "application/vnd.microsoft.portable-executable"
        },
        [ordered]@{
            name = "python_host"
            path = $pythonHost
            content_byte_source_path = Resolve-R23D68ContentByteSource $pythonHost
            raw_sha256 = Get-R23D68Sha256 $pythonHost
            media_type = "application/vnd.microsoft.portable-executable"
        },
        [ordered]@{
            name = "powershell_host"
            path = $powerShellHost
            content_byte_source_path = Resolve-R23D68ContentByteSource $powerShellHost
            raw_sha256 = Get-R23D68Sha256 $powerShellHost
            media_type = "application/vnd.microsoft.portable-executable"
        },
        [ordered]@{
            name = "cargo_host"
            path = $cargoHost
            content_byte_source_path = Resolve-R23D68ContentByteSource $cargoHost
            raw_sha256 = Get-R23D68Sha256 $cargoHost
            media_type = "application/vnd.microsoft.portable-executable"
        },
        [ordered]@{
            name = "rustc_host"
            path = $rustcHost
            content_byte_source_path = Resolve-R23D68ContentByteSource $rustcHost
            raw_sha256 = Get-R23D68Sha256 $rustcHost
            media_type = "application/vnd.microsoft.portable-executable"
        }
    )
    $pipFreeze = Invoke-R23D68Process -FileName $pythonHost -Arguments @(
        "-m", "pip", "freeze", "--all"
    ) -WorkingDirectory $repoRoot -Environment (Get-R23D68PythonEnvironment) `
        -TimeoutSeconds 300
    Assert-R23D68 (
        [int]$pipFreeze.exit_code -eq 0 -and -not [bool]$pipFreeze.timed_out
    ) "Python environment inventory failed: $($pipFreeze.stderr)"
    $environmentProjection = [ordered]@{
        schema_version = "sporespore_qsdk_r23d68_dependency_toolchain_environment_projection_v1"
        source_commit = [string]$source.commit
        source_tree_git_oid = [string]$source.tree_git_oid
        implementation_contract_raw_sha256 = Get-R23D68Sha256 $implementationPath
        implementation_dependency_digests = $implementation.dependency_digests
        runtime_artifacts = @($runtimeArtifacts | ForEach-Object {
            [ordered]@{ name = $_.name; raw_sha256 = $_.raw_sha256 }
        })
        external_runtime_bindings = @($externalRuntimeBindings | ForEach-Object {
            [ordered]@{ name = $_.name; raw_sha256 = $_.raw_sha256 }
        })
        python_package_inventory = @(
            [string]$pipFreeze.stdout -split "`r?`n" |
                Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) } |
                Sort-Object
        )
        campaign_attestation_adoption_sha256 = [string]$adoption.sha256
        operating_system = [Environment]::OSVersion.VersionString
        process_architecture = [Runtime.InteropServices.RuntimeInformation]::ProcessArchitecture.ToString()
        powershell_version = $PSVersionTable.PSVersion.ToString()
        physical_acceptance_authority = $false
    }
    $environmentKey = Get-R23D68ObjectSha256Hex $environmentProjection
    Assert-R23D68 ($environmentKey -cmatch '^[0-9a-f]{64}$') (
        "dependency/toolchain/environment key is invalid"
    )
    $inputCas = Publish-R23D68Inputs $sourceBindings $runtimeArtifacts `
        $externalRuntimeBindings $adoptionPath
    $freeze = [ordered]@{
        schema_version = "sporespore_qsdk_r23d68_physical_freeze_v1"
        status = "frozen_supervisor_only_physical_authorized"
        campaign_id = $campaignId
        gate_id = $gateId
        question_class = "finite_decision"
        preregistration_raw_sha256 = Get-R23D68Sha256 $preregistrationPath
        implementation_contract_raw_sha256 = Get-R23D68Sha256 $implementationPath
        source_commit = [string]$source.commit
        source_tree_git_oid = [string]$source.tree_git_oid
        origin_main_commit = [string]$source.origin_main
        live_github_main_commit = [string]$source.live_github_main
        source_worktree_clean = $true
        complete_zero_world_gate_passed = $true
        clean_pushed_zero_world_qualification_adopted = $true
        campaign_attestation_adoption_sha256 = [string]$adoption.sha256
        implementation_dependency_digests = $implementation.dependency_digests
        source_bindings = $sourceBindings
        runtime_artifacts = $runtimeArtifacts
        external_runtime_bindings = $externalRuntimeBindings
        content_addressed_inputs = $inputCas
        dependency_toolchain_environment_projection = $environmentProjection
        dependency_toolchain_environment_key = $environmentKey
        declared_world_count = 9
        ordered_cell_ids = $cellIds
        serial_execution_required = $true
        all_cells_run_regardless_of_intermediate_outcome = $true
        physical_behavior_thresholds_applied = $true
        posthoc_threshold_or_selector_change_performed = $false
        source_checkout_bytes_equal_git_blobs = $true
        reproducible_runtime_materialization_passed = $true
        physical_execution_authorized = $true
        physical_acceptance_authority = $false
    }
    $freezePath = Join-Path $resolvedOutput "physical-freeze.json"
    Write-R23D68NewJson $freezePath $freeze
    $freezeCas = Publish-SporeSporeContentAddressedArtifact -RepoRoot $repoRoot `
        -ArtifactPath $freezePath -MediaType "application/json"
    Assert-R23D68FrozenBindings $freeze

    $attemptId = [Guid]::NewGuid().ToString("N")
    $token = [Guid]::NewGuid().ToString("N")
    $attempt = [ordered]@{
        schema_version = "sporespore_qsdk_r23d68_physical_attempt_v1"
        campaign_id = $campaignId
        gate_id = $gateId
        question_class = "finite_decision"
        attempt_id = $attemptId
        authorization_token = $token
        source_commit = [string]$source.commit
        authority_repo_root = $repoRoot
        freeze_raw_sha256 = [string]$freezeCas.sha256
        attempt_root = $resolvedOutput
        dependency_toolchain_environment_key = $environmentKey
        ordered_cell_ids = $cellIds
        physical_execution_authorized = $true
        single_use_supervisor_authorization = $true
        matrix_authorization_immutable_before_first_world = $true
        source_worktree_clean = $true
        source_matches_live_github_main = $true
        operation_lock_held = $true
        campaign_attestation_adoption_valid = $true
        content_addressed_inputs_retained = $true
        content_addressed_inputs = $inputCas
        one_shot_attempt_unconsumed = $true
        all_cells_run_regardless_of_intermediate_outcome = $true
        physical_acceptance_authority = $false
    }
    $attemptPath = Join-Path $resolvedOutput "attempt-authorization.json"
    Write-R23D68NewJson $attemptPath $attempt
    $attemptCas = Publish-SporeSporeContentAddressedArtifact -RepoRoot $repoRoot `
        -ArtifactPath $attemptPath -MediaType "application/json"
    $attemptConsumed = $true

    $authorizationPreflights = [Collections.Generic.List[object]]::new()
    $authorizationPassCount = 0
    foreach ($engineId in $engineOrder) {
        foreach ($armId in $armOffsets.Keys) {
            Assert-R23D68FrozenBindings $freeze
            $cellId = "r23d68__${engineId}__s${campaignSeed}__${armId}"
            $authorizationRoot = Join-Path $resolvedOutput (
                "authorization-preflight\$cellId"
            )
            [void][IO.Directory]::CreateDirectory($authorizationRoot)
            $authorizationProcess = $null
            $authorizationReceipt = $null
            $authorizationValid = $false
            $authorizationFailure = ""
            try {
                $environment = Get-R23D68WorkerEnvironment `
                    -EngineId $engineId -ArmId $armId `
                    -FreezePayload ([string]$freezeCas.payload_path) `
                    -AttemptPayload ([string]$attemptCas.payload_path) `
                    -Token $token -AttemptRoot $resolvedOutput `
                    -PythonHost $pythonHost -PowerShellHost $powerShellHost `
                    -CoreLibrary $coreReleasePath
                $authorizationProcess = Invoke-R23D68Worker `
                    -EngineId $engineId -Command "authorization-preflight" `
                    -ArmId $armId -SourceCommit ([string]$source.commit) `
                    -Environment $environment -PythonHost $pythonHost `
                    -TimeoutSeconds 300
                $marker = switch ($engineId) {
                    "godot_jolt" { "QSDK_R23D68_GODOT_JOLT_AUTHORIZATION " }
                    "rapier_parry" { "QSDK_R23D68_RAPIER_AUTHORIZATION " }
                    default { "QSDK_R23D68_MUJOCO_AUTHORIZATION " }
                }
                $schema = switch ($engineId) {
                    "godot_jolt" { "sporespore_qsdk_r23d68_godot_jolt_authorization_v1" }
                    "rapier_parry" { "sporespore_qsdk_r23d68_rapier_authorization_v1" }
                    default { "sporespore_qsdk_r23d68_mujoco_authorization_v1" }
                }
                Assert-R23D68 (
                    [int]$authorizationProcess.exit_code -eq 0 -and
                    -not [bool]$authorizationProcess.timed_out
                ) "authorization-preflight process failed"
                if ($engineId -ceq "godot_jolt") {
                    Assert-R23D68 (
                        [bool]$authorizationProcess.termination_protocol_valid -and
                        [bool]$authorizationProcess.supervisor_terminated -and
                        [string]$authorizationProcess.termination_ready_receipt.worker_receipt_kind -ceq
                            "authorization_preflight"
                    ) "Godot authorization termination invalid"
                }
                $authorizationReceipt = Get-R23D68MarkerJson `
                    ([string]$authorizationProcess.stdout) @($marker)
                $authorizationValidation = `
                    Test-SporeSporeThreeEngineAuthorizationReceipt `
                    -Receipt $authorizationReceipt `
                    -ExpectedSchemaVersion $schema `
                    -ExpectedCampaignId $campaignId `
                    -ExpectedGateId $gateId `
                    -ExpectedEngineId $engineId `
                    -ExpectedStageId $stageId `
                    -ExpectedCellId $cellId
                Assert-R23D68 ([bool]$authorizationValidation.ok) (
                    "authorization-preflight receipt invalid: " +
                    "$(@($authorizationValidation.failure_codes) -join ',')"
                )
                $authorizationValid = $true
                $authorizationPassCount += 1
            } catch {
                $authorizationFailure = [string]$_.Exception.Message
                if ($null -eq $authorizationProcess) {
                    $authorizationProcess = [ordered]@{
                        exit_code = 125
                        timed_out = $false
                        stdout = ""
                        stderr = $authorizationFailure
                        started_utc = [DateTime]::UtcNow.ToString("o")
                        completed_utc = [DateTime]::UtcNow.ToString("o")
                    }
                }
            }
            $streamCas = Save-R23D68ProcessStreams $authorizationProcess $authorizationRoot
            $authorizationPreflights.Add([ordered]@{
                cell_id = $cellId
                engine_id = $engineId
                valid = $authorizationValid
                failure_message = $authorizationFailure
                worker_receipt = $authorizationReceipt
                process = [ordered]@{
                    exit_code = [int]$authorizationProcess.exit_code
                    timed_out = [bool]$authorizationProcess.timed_out
                    started_utc = [string]$authorizationProcess.started_utc
                    completed_utc = [string]$authorizationProcess.completed_utc
                    stdout_cas = $streamCas.stdout
                    stderr_cas = $streamCas.stderr
                }
                physical_acceptance_authority = $false
            })
        }
    }
    $authorizationPreflightPath = Join-Path $resolvedOutput "authorization-preflight.json"
    Write-R23D68NewJson $authorizationPreflightPath ([ordered]@{
        schema_version = "sporespore_qsdk_r23d68_authorization_preflight_matrix_v1"
        campaign_id = $campaignId
        gate_id = $gateId
        source_commit = [string]$source.commit
        ordered_receipts = @($authorizationPreflights)
        receipt_count = $authorizationPreflights.Count
        pass_count = $authorizationPassCount
        complete_matrix_passed = $authorizationPassCount -eq 9
        model_construction_count = 0
        world_attempt_count = 0
        world_build_count = 0
        physical_acceptance_authority = $false
    })
    $authorizationPreflightCas = Publish-SporeSporeContentAddressedArtifact `
        -RepoRoot $repoRoot -ArtifactPath $authorizationPreflightPath `
        -MediaType "application/json"
    Assert-R23D68 (
        $authorizationPreflights.Count -eq 9 -and $authorizationPassCount -eq 9
    ) "complete nine-cell physical authorization preflight did not pass"

    foreach ($engineId in $engineOrder) {
        foreach ($armId in $armOffsets.Keys) {
            Assert-R23D68FrozenBindings $freeze
            $sourceBeforeCell = Get-SporeSporeAttestationSourceIdentity `
                -RepoRoot $repoRoot -RequireCleanPushedLive
            Assert-R23D68 (
                [string]$sourceBeforeCell.commit -ceq [string]$source.commit -and
                [string]$sourceBeforeCell.tree_git_oid -ceq [string]$source.tree_git_oid
            ) "source changed before physical cell $engineId/$armId"
            $cellId = "r23d68__${engineId}__s${campaignSeed}__${armId}"
            $cellRoot = Join-Path $resolvedOutput "cells\$cellId"
            $cells.Add((Invoke-R23D68Cell `
                -EngineId $engineId -ArmId $armId `
                -SourceCommit ([string]$source.commit) `
                -FreezePayload ([string]$freezeCas.payload_path) `
                -AttemptPayload ([string]$attemptCas.payload_path) `
                -Token $token -AttemptRoot $resolvedOutput -CellRoot $cellRoot `
                -PythonHost $pythonHost -PowerShellHost $powerShellHost))
        }
    }

    Assert-R23D68FrozenBindings $freeze
    $sourceAfterCells = Get-SporeSporeAttestationSourceIdentity -RepoRoot $repoRoot `
        -RequireCleanPushedLive
    Assert-R23D68 (
        [string]$sourceAfterCells.commit -ceq [string]$source.commit -and
        [string]$sourceAfterCells.tree_git_oid -ceq [string]$source.tree_git_oid
    ) "source changed during the serialized physical matrix"
    $terminalPaths = @($cells | ForEach-Object {
        [string]$_.terminal_entry_cas.payload_path
    })
    $terminalManifestPath = Join-Path $resolvedOutput "terminal-paths.json"
    Write-R23D68NewJson $terminalManifestPath $terminalPaths
    $terminalManifestCas = Publish-SporeSporeContentAddressedArtifact `
        -RepoRoot $repoRoot -ArtifactPath $terminalManifestPath `
        -MediaType "application/json"
    $evaluationProcess = Invoke-R23D68Process -FileName $pythonHost -Arguments @(
        $evaluatorPath,
        "evaluate-complete",
        "--manifest", [string]$terminalManifestCas.payload_path,
        "--expected-source-commit", [string]$source.commit,
        "--authority-repo-root", $repoRoot
    ) -WorkingDirectory $repoRoot `
        -Environment (Get-R23D68PythonEnvironment $coreReleasePath) `
        -TimeoutSeconds 1200
    $evaluationStreamRoot = Join-Path $resolvedOutput "complete-evaluation-process"
    $evaluationStreamCas = Save-R23D68ProcessStreams $evaluationProcess $evaluationStreamRoot
    Assert-R23D68 (
        [int]$evaluationProcess.exit_code -eq 0 -and
        -not [bool]$evaluationProcess.timed_out
    ) "complete evaluator failed: $($evaluationProcess.stderr) $($evaluationProcess.stdout)"
    $evaluation = Get-R23D68MarkerJson ([string]$evaluationProcess.stdout) `
        @("QSDK_R23D68_COMPLETE_EVALUATION ")
    $evaluationPath = Join-Path $resolvedOutput "complete-evaluation.json"
    Write-R23D68NewJson $evaluationPath $evaluation
    $evaluationCas = Publish-SporeSporeContentAddressedArtifact -RepoRoot $repoRoot `
        -ArtifactPath $evaluationPath -MediaType "application/json"
    $worldCountLowerBound = 0
    $worldCountUpperBound = 0
    $worldCountExact = $true
    foreach ($cell in @($cells)) {
        $worldCountLowerBound += [int]$cell.world_build_count_lower_bound
        $worldCountUpperBound += [int]$cell.world_build_count_upper_bound
        $worldCountExact = $worldCountExact -and [bool]$cell.world_build_count_exact
    }
    $report = [ordered]@{
        schema_version = "sporespore_qsdk_r23d68_campaign_report_v1"
        campaign_id = $campaignId
        gate_id = $gateId
        question_class = "finite_decision"
        source = $source
        attempt_id = $attemptId
        freeze_cas = $freezeCas
        attempt_authorization_cas = $attemptCas
        authorization_preflight_cas = $authorizationPreflightCas
        authorization_preflight_count = $authorizationPreflights.Count
        terminal_manifest_cas = $terminalManifestCas
        complete_evaluation_process = [ordered]@{
            stdout_cas = $evaluationStreamCas.stdout
            stderr_cas = $evaluationStreamCas.stderr
        }
        complete_evaluation_cas = $evaluationCas
        ordered_cells = @($cells)
        complete_evaluation = $evaluation
        result_classification = [string]$evaluation.classification
        all_nine_cells_executed_or_retained_as_failures = $cells.Count -eq 9
        world_build_count_exact = $worldCountExact
        world_build_count_lower_bound = $worldCountLowerBound
        world_build_count_upper_bound = $worldCountUpperBound
        claims = $evaluation.claims
        physical_acceptance_authority = $false
    }
    $reportPath = Join-Path $resolvedOutput "report.json"
    Write-R23D68NewJson $reportPath $report
    $reportCas = Publish-SporeSporeContentAddressedArtifact -RepoRoot $repoRoot `
        -ArtifactPath $reportPath -MediaType "application/json"
    $completion = [ordered]@{
        schema_version = "sporespore_qsdk_r23d68_completion_v1"
        campaign_id = $campaignId
        gate_id = $gateId
        attempt_id = $attemptId
        status = [string]$evaluation.classification
        source_commit = [string]$source.commit
        cell_count = $cells.Count
        world_count = $worldCountLowerBound
        world_count_exact = $worldCountExact
        world_count_lower_bound = $worldCountLowerBound
        world_count_upper_bound = $worldCountUpperBound
        selected_profile_id = [string]$evaluation.selected_public_profile_id
        finite_three_engine_turning_positive = [bool](
            $evaluation.finite_decision.finite_three_engine_turning_positive
        )
        report_cas = $reportCas
        complete_evaluation_cas = $evaluationCas
        authorization_preflight_cas = $authorizationPreflightCas
        authorization_preflight_count = $authorizationPreflights.Count
        one_shot_attempt_consumed = $true
        replacement_or_selective_rerun_permitted = $false
        completed_utc = [DateTime]::UtcNow.ToString("o")
        physical_acceptance_authority = $false
    }
    Write-R23D68NewJson $completionPath $completion
    $completionCas = Publish-SporeSporeContentAddressedArtifact -RepoRoot $repoRoot `
        -ArtifactPath $completionPath -MediaType "application/json"
    Write-Host (
        "[turning/3e] R23D68 PHYSICAL COMPLETE " +
        "classification=$($evaluation.classification) " +
        "turning=$($evaluation.finite_decision.finite_three_engine_turning_positive) " +
        "cells=$($cells.Count) report_sha256=$($reportCas.sha256) " +
        "completion_sha256=$($completionCas.sha256) output=$resolvedOutput"
    )
    if (([string]$evaluation.classification).StartsWith(
        "invalid_", [StringComparison]::Ordinal
    )) {
        throw "QSDK-R23D68 retained an invalid complete first attempt: $resolvedOutput"
    }
} catch {
    if ($attemptConsumed -and -not [string]::IsNullOrWhiteSpace($completionPath) -and
        -not (Test-Path -LiteralPath $completionPath)) {
        $emergency = [ordered]@{
            schema_version = "sporespore_qsdk_r23d68_completion_v1"
            campaign_id = $campaignId
            gate_id = $gateId
            attempt_id = $attemptId
            status = "invalid_or_incomplete_first_attempt"
            source_commit = [string]$source.commit
            retained_cell_count = $cells.Count
            one_shot_attempt_consumed = $true
            replacement_or_selective_rerun_permitted = $false
            failure_message = [string]$_.Exception.Message
            completed_utc = [DateTime]::UtcNow.ToString("o")
            physical_acceptance_authority = $false
        }
        Write-R23D68NewJson $completionPath $emergency
        [void](Publish-SporeSporeContentAddressedArtifact -RepoRoot $repoRoot `
            -ArtifactPath $completionPath -MediaType "application/json")
    }
    throw
} finally {
    Exit-SporeSporeLocomotionOperationLock $lock
}
