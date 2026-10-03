#requires -Version 7.0

[CmdletBinding()]
param(
    [switch]$PreflightOnly,
    [switch]$RunPhysical,
    [string]$CampaignAttestationAdoption = "",
    [string]$OutputRoot = "",
    [string]$Godot = (
        "C:\Users\Cole\CodeStuff\Misc\Godot\" +
        "Godot_v4.7-stable_mono_win64_console.exe"
    ),
    [string]$Python = "python",
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
$campaignId = "QSDK-R23D40-THREE-ENGINE-STARTUP-RAMP-TURNING-VALIDATION"
$gateId = "QSDK-R23D40"
$stageId = "three_engine_startup_ramp_turning_validation"
$candidateId = "r23d29_startup_ramp_turning_validation"
$policyId = (
    "sporespore_balanced_wave_r23d29_two_swing_persistent_predictive_" +
    "stability_guarded_steering_v1"
)
$preregistrationPath = Join-Path $turningRoot (
    "r23d40_three_engine_startup_ramp_turning_preregistration_v1.json"
)
$implementationPath = Join-Path $turningRoot (
    "r23d40_three_engine_startup_ramp_turning_implementation_v1.json"
)
$manifestPath = Join-Path $turningRoot "r23d40_campaign_attestation_manifest_v1.json"
$evaluatorPath = Join-Path $turningRoot (
    "r23d40_three_engine_startup_ramp_turning_evaluator.py"
)
$godotWorkerPath = "res://tests/test_sdk_qsdk_r23d40_godot_jolt_physical_worker.gd"
$runtimeHelperPath = Join-Path $sdkRoot "r23d3_reproducible_runtime_materialization.ps1"
$coreDebugPath = Join-Path $sdkRoot "target\debug\sporespore_locomotion_core.dll"
$coreReleasePath = Join-Path $sdkRoot "target\release\sporespore_locomotion_core.dll"
$godotAdapterPath = Join-Path $sdkRoot "target\debug\sporespore_godot_adapter.dll"
$rapierDebugPath = Join-Path $sdkRoot "target\debug\qsdk_r23d40_physical.exe"
$rapierReleasePath = Join-Path $sdkRoot "target\release\qsdk_r23d40_physical.exe"
$armOrder = @("reference_zero", "positive_heading", "negative_heading")
$engineOrder = @("rapier_parry", "godot_jolt", "mujoco")
$cellIds = @(
    foreach ($engine in $engineOrder) {
        foreach ($arm in $armOrder) { "$engine`__$candidateId`__$arm" }
    }
)
$physicalEnvironmentNames = @(
    "SPORESPORE_QSDK_R23D40_FREEZE",
    "SPORESPORE_QSDK_R23D40_ATTEMPT",
    "SPORESPORE_QSDK_R23D40_TOKEN",
    "SPORESPORE_QSDK_R23D40_STAGE",
    "SPORESPORE_QSDK_R23D40_CELL",
    "SPORESPORE_QSDK_R23D40_ENGINE",
    "SPORESPORE_QSDK_R23D40_ATTEMPT_ROOT",
    "SPORESPORE_QSDK_R23D40_AUTHORITY_REPO_ROOT",
    "SPORESPORE_QSDK_R23D40_PYTHON",
    "SPORESPORE_QSDK_R23D40_POWERSHELL"
)

. (Join-Path $sdkRoot "content_addressed_artifact_store.ps1")
. (Join-Path $sdkRoot "locomotion_operation_lock.ps1")
. (Join-Path $sdkRoot "locomotion_full_conformance_attestation.ps1")
. (Join-Path $sdkRoot "locomotion_campaign_attestation_adoption.ps1")

function Assert-R23D40([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "QSDK-R23D40: $Message" }
}

function Resolve-R23D40Application([string]$Command) {
    if ([IO.Path]::IsPathFullyQualified($Command)) {
        $resolved = [IO.Path]::GetFullPath($Command)
        Assert-R23D40 (Test-Path -LiteralPath $resolved -PathType Leaf) (
            "application is missing: $resolved"
        )
        return $resolved
    }
    $candidate = Get-Command $Command -CommandType Application -ErrorAction Stop |
        Select-Object -First 1
    return [IO.Path]::GetFullPath([string]$candidate.Source)
}

function Get-R23D40Sha256([string]$Path) {
    return "sha256:" + (
        Get-FileHash -LiteralPath $Path -Algorithm SHA256
    ).Hash.ToLowerInvariant()
}

function Invoke-R23D40Git([string[]]$Arguments) {
    $lines = @(& git -C $repoRoot @Arguments 2>&1)
    if ($LASTEXITCODE -ne 0) {
        throw "QSDK-R23D40 git $($Arguments -join ' ') failed: $($lines -join ' ')"
    }
    return ($lines -join "`n").Trim()
}

function ConvertTo-R23D40LfProjectedBytes(
    [byte[]]$Bytes,
    [string]$RelativePath
) {
    $projected = [Collections.Generic.List[byte]]::new()
    for ($index = 0; $index -lt $Bytes.Length; $index++) {
        $value = [int]$Bytes[$index]
        if ($value -ne 13) {
            $projected.Add([byte]$value)
            continue
        }
        Assert-R23D40 (
            $index + 1 -lt $Bytes.Length -and [int]$Bytes[$index + 1] -eq 10
        ) "declared LF projection encountered a bare CR byte: $RelativePath"
        $projected.Add([byte]10)
        $index++
    }
    return ,([byte[]]$projected.ToArray())
}

function Get-R23D40GitBlobOidFromBytes([byte[]]$Bytes) {
    $header = [Text.Encoding]::ASCII.GetBytes("blob $($Bytes.Length)")
    $payload = [byte[]]::new($header.Length + 1 + $Bytes.Length)
    [Buffer]::BlockCopy($header, 0, $payload, 0, $header.Length)
    $payload[$header.Length] = 0
    [Buffer]::BlockCopy($Bytes, 0, $payload, $header.Length + 1, $Bytes.Length)
    $sha1 = [Security.Cryptography.SHA1]::Create()
    try {
        return ([Convert]::ToHexString($sha1.ComputeHash($payload))).ToLowerInvariant()
    } finally {
        $sha1.Dispose()
    }
}

function Write-R23D40NewJson([string]$Path, $Value) {
    $resolved = [IO.Path]::GetFullPath($Path)
    if (Test-Path -LiteralPath $resolved) {
        throw "QSDK-R23D40 refuses to overwrite: $resolved"
    }
    [void][IO.Directory]::CreateDirectory((Split-Path -Parent $resolved))
    [IO.File]::WriteAllText(
        $resolved,
        ($Value | ConvertTo-Json -Depth 100) + "`n",
        [Text.UTF8Encoding]::new($false)
    )
}

function Get-R23D40MediaType([string]$Path) {
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

function Invoke-R23D40Process {
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
        exit_code = $exitCode
        timed_out = $timedOut
        stdout = $stdout
        stderr = $stderr
        started_utc = $started.ToString("o")
        completed_utc = [DateTime]::UtcNow.ToString("o")
    }
}

function Get-R23D40MarkerJson([string]$Text, [string]$Prefix) {
    $lines = @($Text -split "`r?`n" | Where-Object {
        ([string]$_).StartsWith($Prefix, [StringComparison]::Ordinal)
    })
    Assert-R23D40 ($lines.Count -eq 1) (
        "expected one '$Prefix' marker, observed $($lines.Count)"
    )
    return $lines[0].Substring($Prefix.Length) |
        ConvertFrom-Json -AsHashtable -Depth 100
}

function Get-R23D40PythonEnvironment([string]$CoreLibrary) {
    Assert-R23D40 (Test-Path -LiteralPath $mujocoSitePackages -PathType Container) (
        "locked MuJoCo site-packages root is missing: $mujocoSitePackages"
    )
    return @{
        # LCA1 was commissioned against the system CPython host. Keep that
        # exact host identity while loading this campaign's project-local,
        # requirements-locked MuJoCo wheels explicitly.
        "PYTHONPATH" = (@(
            (Join-Path $sdkRoot "python"),
            $mujocoRoot,
            $mujocoSitePackages
        ) -join [IO.Path]::PathSeparator)
        "SPORESPORE_LOCOMOTION_LIBRARY" = [IO.Path]::GetFullPath($CoreLibrary)
    }
}

function Invoke-R23D40ZeroWorld(
    [string]$PythonHost,
    [string]$PowerShellHost,
    [string]$CoreLibrary,
    [string]$RapierWorker
) {
    Assert-R23D40 (Test-Path -LiteralPath $CoreLibrary -PathType Leaf) (
        "zero-world core library is missing: $CoreLibrary"
    )
    Assert-R23D40 (Test-Path -LiteralPath $godotAdapterPath -PathType Leaf) (
        "zero-world Godot adapter is missing: $godotAdapterPath"
    )
    Assert-R23D40 (Test-Path -LiteralPath $RapierWorker -PathType Leaf) (
        "zero-world Rapier worker is missing: $RapierWorker"
    )
    $implementation = Get-Content -Raw -LiteralPath $implementationPath |
        ConvertFrom-Json -AsHashtable -Depth 100
    # Exercise the exact source freezer during every campaign-local preflight.
    # This prevents an overbroad or checkout-filter-sensitive dependency set
    # from surviving commissioning only to fail at the physical boundary.
    $sourceBindings = Get-R23D40SourceBindings $implementation
    $rawMismatchCount = @($sourceBindings | Where-Object {
        -not [bool]$_.raw_checkout_equals_git_blob
    }).Count
    $projectionApplicationCount = @($sourceBindings | Where-Object {
        [bool]$_.deterministic_projection_applied
    }).Count
    $pythonEnvironment = Get-R23D40PythonEnvironment $CoreLibrary
    $evaluator = Invoke-R23D40Process -FileName $PythonHost `
        -Arguments @($evaluatorPath, "preflight") -WorkingDirectory $repoRoot `
        -Environment $pythonEnvironment -TimeoutSeconds 180
    Assert-R23D40 ($evaluator.exit_code -eq 0 -and -not $evaluator.timed_out) (
        "evaluator preflight failed: $($evaluator.stderr) $($evaluator.stdout)"
    )
    $evaluatorReceipt = Get-R23D40MarkerJson $evaluator.stdout (
        "QSDK_R23D40_EVALUATOR_PREFLIGHT "
    )
    Assert-R23D40 (
        [int]$evaluatorReceipt.world_build_count -eq 0 -and
        [int]$evaluatorReceipt.model_construction_count -eq 0
    ) "evaluator preflight exposed a world"

    $workerReceipts = [Collections.Generic.List[object]]::new()
    foreach ($arm in $armOrder) {
        $result = Invoke-R23D40Process -FileName $RapierWorker -Arguments @(
            "preflight", "--stage", $stageId, "--candidate", $candidateId,
            "--arm", $arm
        ) -WorkingDirectory $repoRoot -TimeoutSeconds 180
        Assert-R23D40 ($result.exit_code -eq 0 -and -not $result.timed_out) (
            "Rapier $arm preflight failed: $($result.stderr) $($result.stdout)"
        )
        $receipt = Get-R23D40MarkerJson $result.stdout (
            "QSDK_R23D40_RAPIER_PREFLIGHT "
        )
        Assert-R23D40 (
            [string]$receipt.arm_id -ceq $arm -and
            [string]$receipt.controller_policy_id -ceq $policyId -and
            [bool]$receipt.startup_velocity_ramp_enabled -and
            [string]$receipt.startup_ramp_id -ceq
                "canonical_velocity_smoothstep_one_gait_cycle_v1" -and
            [bool]$receipt.startup_ramp_exact_zero_at_step_zero -and
            [bool]$receipt.startup_ramp_exact_unity_from_step_359 -and
            [int]$receipt.world_build_count -eq 0 -and
            [int]$receipt.model_construction_count -eq 0
        ) "Rapier $arm preflight receipt is invalid"
        $workerReceipts.Add($receipt)
    }
    foreach ($arm in $armOrder) {
        $result = Invoke-R23D40Process -FileName $Godot -Arguments @(
            "--headless", "--path", $repoRoot, "--script", $godotWorkerPath, "--",
            "--stage", $stageId, "--onset", "onset_600", "--arm", $arm,
            "--preflight-only"
        ) -WorkingDirectory $repoRoot -TimeoutSeconds 180
        Assert-R23D40 ($result.exit_code -eq 0 -and -not $result.timed_out) (
            "Godot $arm preflight failed: $($result.stderr) $($result.stdout)"
        )
        $receipt = Get-R23D40MarkerJson $result.stdout (
            "QSDK_R23D40_GODOT_JOLT_PREFLIGHT "
        )
        $production = $receipt.adapter_boundary.production_post_step_validation
        Assert-R23D40 (
            [string]$receipt.arm_id -ceq $arm -and
            [string]$receipt.controller_policy_id -ceq $policyId -and
            [bool]$production.ok -and
            [string]$production.controller_receipt_schema -ceq
                "sporespore_controller_step_receipt_v8" -and
            [string]$production.expected_memory_schema -ceq
                "sporespore_balanced_wave_persistent_predictive_guard_memory_v1" -and
            [string]$production.observed_memory_schema -ceq
                "sporespore_balanced_wave_persistent_predictive_guard_memory_v1" -and
            [int]$receipt.world_build_count -eq 0 -and
            [int]$receipt.model_construction_count -eq 0
        ) "Godot $arm preflight receipt is invalid"
        $workerReceipts.Add($receipt)
    }
    foreach ($arm in $armOrder) {
        $result = Invoke-R23D40Process -FileName $PythonHost -Arguments @(
            "-m", "sporespore_mujoco_adapter.qsdk_r23d40_three_engine_turning", "preflight",
            "--stage", $stageId, "--onset", "onset_600", "--arm", $arm
        ) -WorkingDirectory $repoRoot -Environment $pythonEnvironment `
            -TimeoutSeconds 180
        Assert-R23D40 ($result.exit_code -eq 0 -and -not $result.timed_out) (
            "MuJoCo $arm preflight failed: $($result.stderr) $($result.stdout)"
        )
        $receipt = Get-R23D40MarkerJson $result.stdout "QSDK_R23D40_MUJOCO_PREFLIGHT "
        Assert-R23D40 (
            [string]$receipt.arm_id -ceq $arm -and
            [string]$receipt.controller_policy_id -ceq $policyId -and
            [int]$receipt.world_build_count -eq 0 -and
            [int]$receipt.model_construction_count -eq 0
        ) "MuJoCo $arm preflight receipt is invalid"
        $workerReceipts.Add($receipt)
    }
    return [ordered]@{
        schema_version = "sporespore_qsdk_r23d40_zero_world_receipt_v1"
        campaign_id = $campaignId
        gate_id = $gateId
        evaluator = $evaluatorReceipt
        ordered_worker_receipts = @($workerReceipts)
        declared_cell_count = 9
        worker_preflight_count = 9
        source_binding_count = @($sourceBindings).Count
        source_bindings_checkout_bytes_equal_git_blobs = ($rawMismatchCount -eq 0)
        source_bindings_raw_checkout_mismatch_count = $rawMismatchCount
        source_bindings_deterministic_projection_application_count =
            $projectionApplicationCount
        source_bindings_authority_bytes_equal_git_blobs_after_declared_projection = $true
        tracked_prefix_exclusion_count =
            @($implementation.source_binding_policy.tracked_prefix_exclusions).Count
        declared_deterministic_projection_path_count = @(
            $implementation.source_binding_policy.deterministic_checkout_projection.exact_paths
        ).Count
        campaign_local_policy_ramp_and_worker_gate_passed = $true
        model_construction_count = 0
        world_attempt_count = 0
        world_build_count = 0
        physical_execution_authorized = $false
        physical_acceptance_authority = $false
    }
}

function Get-R23D40SourceBindings($Implementation) {
    $policy = $Implementation.source_binding_policy
    $excludedPrefixes = @($policy.tracked_prefix_exclusions | ForEach-Object {
        ([string]$_).Replace("\", "/")
    })
    $projectionPolicy = $policy.deterministic_checkout_projection
    Assert-R23D40 (
        [string]$projectionPolicy.projection_id -ceq
            "crlf_pairs_to_lf_bytes_reject_bare_cr_v1" -and
        [string]$projectionPolicy.algorithm -ceq
            "replace_each_crlf_byte_pair_with_one_lf_byte_and_reject_every_bare_cr_byte" -and
        [bool]$projectionPolicy.projected_git_blob_oid_must_equal_head_blob_oid -and
        [bool]$projectionPolicy.raw_checkout_bytes_and_sha256_remain_retained_in_cas
    ) "deterministic checkout projection declaration changed"
    $projectionPaths = @($projectionPolicy.exact_paths | ForEach-Object {
        ([string]$_).Replace("\", "/")
    })
    $paths = [Collections.Generic.List[string]]::new()
    foreach ($path in @($policy.exact_paths)) {
        $paths.Add(([string]$path).Replace("\", "/"))
    }
    foreach ($prefix in @($policy.tracked_prefixes)) {
        $listed = Invoke-R23D40Git @("ls-files", "--", [string]$prefix)
        $expanded = @($listed -split "`n" |
            Where-Object {
                if ([string]::IsNullOrWhiteSpace($_)) { return $false }
                $candidate = ([string]$_).Replace("\", "/")
                foreach ($excludedPrefix in $excludedPrefixes) {
                    if ($candidate.StartsWith(
                        $excludedPrefix,
                        [StringComparison]::Ordinal
                    )) { return $false }
                }
                return $true
            })
        Assert-R23D40 ($expanded.Count -gt 0) "empty source-binding prefix: $prefix"
        foreach ($path in $expanded) { $paths.Add($path.Replace("\", "/")) }
    }
    $duplicates = @($paths | Group-Object | Where-Object Count -gt 1)
    Assert-R23D40 ($duplicates.Count -eq 0) "duplicate source-binding paths"
    foreach ($projectionPath in $projectionPaths) {
        Assert-R23D40 ($paths.Contains($projectionPath)) (
            "declared projection path is outside source bindings: $projectionPath"
        )
    }
    $bindings = [Collections.Generic.List[object]]::new()
    foreach ($relative in $paths) {
        $absolute = Join-Path $repoRoot $relative
        Assert-R23D40 (Test-Path -LiteralPath $absolute -PathType Leaf) (
            "source binding is missing: $relative"
        )
        $blob = Invoke-R23D40Git @("rev-parse", "HEAD:$relative")
        $checkout = Invoke-R23D40Git @("hash-object", "--no-filters", "--", $relative)
        $rawEqualsBlob = $blob -ceq $checkout
        $projectionDeclared = $projectionPaths -ccontains $relative
        $projectionApplied = $false
        $authorityBlob = $checkout
        if (-not $rawEqualsBlob) {
            Assert-R23D40 $projectionDeclared (
                "checkout bytes differ from Git blob without a declared projection: $relative"
            )
            [byte[]]$rawBytes = [IO.File]::ReadAllBytes($absolute)
            [byte[]]$projectedBytes = ConvertTo-R23D40LfProjectedBytes `
                $rawBytes $relative
            $authorityBlob = Get-R23D40GitBlobOidFromBytes $projectedBytes
            Assert-R23D40 ($authorityBlob -ceq $blob) (
                "declared checkout projection differs from Git blob: $relative"
            )
            $projectionApplied = $true
        }
        $bindings.Add([ordered]@{
            path = $relative
            raw_sha256 = Get-R23D40Sha256 $absolute
            git_blob_oid = $blob
            raw_checkout_git_blob_oid = $checkout
            raw_checkout_equals_git_blob = $rawEqualsBlob
            deterministic_projection_id = if ($projectionDeclared) {
                [string]$projectionPolicy.projection_id
            } else { "" }
            deterministic_projection_applied = $projectionApplied
            authority_git_blob_oid_after_declared_projection = $authorityBlob
            authority_bytes_equal_git_blob_after_declared_projection = $true
            media_type = Get-R23D40MediaType $relative
        })
    }
    return @($bindings)
}

function Assert-R23D40FrozenBindings($Freeze) {
    foreach ($binding in @($Freeze.source_bindings)) {
        $path = Join-Path $repoRoot ([string]$binding.path)
        $blob = Invoke-R23D40Git @("rev-parse", "HEAD:$([string]$binding.path)")
        $checkout = Invoke-R23D40Git @(
            "hash-object", "--no-filters", "--", [string]$binding.path
        )
        $rawEqualsBlob = $blob -ceq $checkout
        $projectionApplied = -not $rawEqualsBlob
        $authorityBlob = $checkout
        if ($projectionApplied) {
            Assert-R23D40 (
                [string]$binding.deterministic_projection_id -ceq
                    "crlf_pairs_to_lf_bytes_reject_bare_cr_v1"
            ) "frozen source gained an undeclared projection: $([string]$binding.path)"
            [byte[]]$rawBytes = [IO.File]::ReadAllBytes($path)
            [byte[]]$projectedBytes = ConvertTo-R23D40LfProjectedBytes `
                $rawBytes ([string]$binding.path)
            $authorityBlob = Get-R23D40GitBlobOidFromBytes $projectedBytes
        }
        Assert-R23D40 (
            (Test-Path -LiteralPath $path -PathType Leaf) -and
            [string]$binding.raw_sha256 -ceq (Get-R23D40Sha256 $path) -and
            [string]$binding.git_blob_oid -ceq $blob -and
            [string]$binding.raw_checkout_git_blob_oid -ceq $checkout -and
            [bool]$binding.raw_checkout_equals_git_blob -eq $rawEqualsBlob -and
            [bool]$binding.deterministic_projection_applied -eq $projectionApplied -and
            [string]$binding.authority_git_blob_oid_after_declared_projection -ceq
                $authorityBlob -and
            $authorityBlob -ceq $blob -and
            [bool]$binding.authority_bytes_equal_git_blob_after_declared_projection
        ) "frozen source binding changed: $([string]$binding.path)"
    }
    foreach ($runtime in @($Freeze.runtime_artifacts) + @($Freeze.external_runtime_bindings)) {
        $path = [IO.Path]::GetFullPath([string]$runtime.path)
        Assert-R23D40 (
            (Test-Path -LiteralPath $path -PathType Leaf) -and
            [string]$runtime.raw_sha256 -ceq (Get-R23D40Sha256 $path)
        ) "frozen runtime changed: $path"
    }
}

function Publish-R23D40Inputs(
    $SourceBindings,
    $RuntimeArtifacts,
    $ExternalRuntimeBindings,
    [string]$AdoptionPath
) {
    $source = @(
        foreach ($binding in @($SourceBindings)) {
            Publish-SporeSporeContentAddressedArtifact -RepoRoot $repoRoot `
                -ArtifactPath (Join-Path $repoRoot ([string]$binding.path)) `
                -MediaType ([string]$binding.media_type)
        }
    )
    $runtime = @(
        foreach ($binding in @($RuntimeArtifacts) + @($ExternalRuntimeBindings)) {
            Publish-SporeSporeContentAddressedArtifact -RepoRoot $repoRoot `
                -ArtifactPath ([string]$binding.path) `
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

function Get-R23D40TerminalFailure(
    [string]$CellId,
    [string]$EngineId,
    [string]$ArmId,
    [string]$SourceCommit,
    [string]$Code,
    [int]$WorldAttemptCount = 0,
    [int]$WorldBuildCount = 0
) {
    return [ordered]@{
        schema_version = "sporespore_qsdk_r23d40_worker_failure_v1"
        campaign_id = $campaignId
        gate_id = $gateId
        stage_id = $stageId
        cell_id = $CellId
        engine_id = $EngineId
        onset_id = "onset_600"
        turn_start_semantic_step = 600
        arm_id = $ArmId
        turn_heading_offset_rad = if ($ArmId -ceq "positive_heading") {
            0.2
        } elseif ($ArmId -ceq "negative_heading") { -0.2 } else { 0.0 }
        source_commit = $SourceCommit
        failure_stage = "supervisor_transport"
        failure_code = $Code
        world_attempt_count = $WorldAttemptCount
        world_build_count = $WorldBuildCount
        claims = [ordered]@{
            rapier_parry_r23d29_turning = $false
            godot_jolt_r23d29_turning = $false
            mujoco_r23d29_turning = $false
            finite_three_engine_turning = $false
            portable_basic_turning = $false
            cross_engine_equivalence = $false
            population_robustness = $false
            prone_to_standing = $false
            release_authorized = $false
            physical_acceptance_authority = $false
        }
    }
}

function Invoke-R23D40Cell {
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
    $cellId = "$EngineId`__$candidateId`__$ArmId"
    $environment = @{
        "SPORESPORE_QSDK_R23D40_FREEZE" = $FreezePayload
        "SPORESPORE_QSDK_R23D40_ATTEMPT" = $AttemptPayload
        "SPORESPORE_QSDK_R23D40_TOKEN" = $Token
        "SPORESPORE_QSDK_R23D40_STAGE" = $stageId
        "SPORESPORE_QSDK_R23D40_CELL" = $cellId
        "SPORESPORE_QSDK_R23D40_ENGINE" = $EngineId
        "SPORESPORE_QSDK_R23D40_ATTEMPT_ROOT" = $AttemptRoot
        "SPORESPORE_QSDK_R23D40_AUTHORITY_REPO_ROOT" = $repoRoot
        "SPORESPORE_QSDK_R23D40_PYTHON" = $PythonHost
        "SPORESPORE_QSDK_R23D40_POWERSHELL" = $PowerShellHost
    }
    if ($EngineId -ceq "rapier_parry") {
        $fileName = $rapierReleasePath
        $arguments = @(
            "physical", "--stage", $stageId, "--candidate", $candidateId,
            "--arm", $ArmId, "--source-commit", $SourceCommit
        )
        $marker = "QSDK_R23D40_RAPIER_TERMINAL "
    } elseif ($EngineId -ceq "godot_jolt") {
        $fileName = $Godot
        $arguments = @(
            "--headless", "--path", $repoRoot, "--script", $godotWorkerPath, "--",
            "--stage", $stageId, "--onset", "onset_600", "--arm", $ArmId,
            "--source-commit", $SourceCommit
        )
        $marker = "QSDK_R23D40_GODOT_JOLT_TERMINAL "
    } else {
        $fileName = $PythonHost
        $arguments = @(
            "-m", "sporespore_mujoco_adapter.qsdk_r23d40_three_engine_turning", "physical",
            "--stage", $stageId, "--onset", "onset_600", "--arm", $ArmId,
            "--source-commit", $SourceCommit
        )
        $marker = "QSDK_R23D40_MUJOCO_TERMINAL "
        foreach ($entry in (Get-R23D40PythonEnvironment $coreReleasePath).GetEnumerator()) {
            $environment[[string]$entry.Key] = [string]$entry.Value
        }
    }
    $process = Invoke-R23D40Process -FileName $fileName -Arguments $arguments `
        -WorkingDirectory $repoRoot -Environment $environment `
        -TimeoutSeconds $CellTimeoutSeconds
    $stdoutPath = Join-Path $CellRoot "stdout.txt"
    $stderrPath = Join-Path $CellRoot "stderr.txt"
    [IO.File]::WriteAllText($stdoutPath, [string]$process.stdout, [Text.UTF8Encoding]::new($false))
    [IO.File]::WriteAllText($stderrPath, [string]$process.stderr, [Text.UTF8Encoding]::new($false))
    $stdoutCas = Publish-SporeSporeContentAddressedArtifact -RepoRoot $repoRoot `
        -ArtifactPath $stdoutPath -MediaType "text/plain"
    $stderrCas = Publish-SporeSporeContentAddressedArtifact -RepoRoot $repoRoot `
        -ArtifactPath $stderrPath -MediaType "text/plain"
    try {
        if ([bool]$process.timed_out) { throw "R23D40_CELL_TIMEOUT" }
        $terminal = Get-R23D40MarkerJson ([string]$process.stdout) $marker
        if ([string]$terminal.cell_id -cne $cellId) { throw "R23D40_CELL_MARKER_ID" }
    } catch {
        $terminal = Get-R23D40TerminalFailure -CellId $cellId -EngineId $EngineId `
            -ArmId $ArmId -SourceCommit $SourceCommit `
            -Code ("R23D40_SUPERVISOR_TERMINAL_CAPTURE:" + $_.Exception.Message)
    }
    $terminalPath = Join-Path $CellRoot "terminal.json"
    Write-R23D40NewJson $terminalPath $terminal
    $terminalCas = Publish-SporeSporeContentAddressedArtifact -RepoRoot $repoRoot `
        -ArtifactPath $terminalPath -MediaType "application/json"
    return [ordered]@{
        cell_id = $cellId
        engine_id = $EngineId
        arm_id = $ArmId
        process = [ordered]@{
            exit_code = [int]$process.exit_code
            timed_out = [bool]$process.timed_out
            started_utc = [string]$process.started_utc
            completed_utc = [string]$process.completed_utc
            stdout_cas = $stdoutCas
            stderr_cas = $stderrCas
        }
        terminal_entry_cas = $terminalCas
        terminal_schema = [string]$terminal.schema_version
        physical_acceptance_authority = $false
    }
}

Assert-R23D40 ($PreflightOnly -xor $RunPhysical) (
    "select exactly one of -PreflightOnly or -RunPhysical"
)
Assert-R23D40 (Test-Path -LiteralPath $Godot -PathType Leaf) "Godot executable is missing"
$pythonHost = Resolve-R23D40Application $Python
$powerShellHost = Resolve-R23D40Application $PowerShell

if ($PreflightOnly) {
    Assert-R23D40 ([string]::IsNullOrWhiteSpace($CampaignAttestationAdoption)) (
        "preflight does not accept physical authorization"
    )
    Assert-R23D40 ([string]::IsNullOrWhiteSpace($OutputRoot)) (
        "preflight does not accept a physical output root"
    )
    $receipt = Invoke-R23D40ZeroWorld $pythonHost $powerShellHost $coreDebugPath $rapierDebugPath
    Write-Host (
        "QSDK_R23D40_ZERO_WORLD_PASS " +
        ($receipt | ConvertTo-Json -Depth 100 -Compress)
    )
    exit 0
}

Assert-R23D40 (-not [string]::IsNullOrWhiteSpace($CampaignAttestationAdoption)) (
    "physical execution requires a campaign-attestation adoption"
)
foreach ($path in @($preregistrationPath, $implementationPath, $manifestPath)) {
    Assert-R23D40 (Test-Path -LiteralPath $path -PathType Leaf) "missing contract: $path"
}
$source = Get-SporeSporeAttestationSourceIdentity -RepoRoot $repoRoot `
    -RequireCleanPushedLive
$adoption = Test-SporeSporeCampaignAttestationAdoptionFile -RepoRoot $repoRoot `
    -ManifestPath $manifestPath `
    -AdoptionPath ([IO.Path]::GetFullPath($CampaignAttestationAdoption)) `
    -Godot $Godot -Python $pythonHost -ExpectedCampaignId $campaignId
Assert-R23D40 ([bool]$adoption.ok) (
    "campaign-attestation adoption failed: $(@($adoption.failure_codes) -join ',')"
)
Assert-R23D40 (
    [string]$adoption.source.commit -ceq [string]$source.commit -and
    [string]$adoption.source.tree_git_oid -ceq [string]$source.tree_git_oid
) "adoption source differs from the live source"

$lock = Enter-SporeSporeLocomotionOperationLock -Role physical
Assert-R23D40 ([bool]$lock.acquired) "global locomotion operation lock is held"
$attemptConsumed = $false
$completionPath = ""
try {
    $evidenceRoot = Get-SporeSporeArtifactEvidenceRoot -RepoRoot $repoRoot
    $prior = @(Get-ChildItem -LiteralPath $evidenceRoot -Directory | Where-Object {
        $_.Name -like "qsdk-r23d40-*" -and (
            (Test-Path -LiteralPath (Join-Path $_.FullName "attempt-authorization.json")) -or
            (Test-Path -LiteralPath (Join-Path $_.FullName "completion.json"))
        )
    })
    Assert-R23D40 ($prior.Count -eq 0) "one-shot R23D40 identity already exists"
    $resolvedOutput = if ([string]::IsNullOrWhiteSpace($OutputRoot)) {
        Join-Path $evidenceRoot (
            "qsdk-r23d40-" + [DateTime]::UtcNow.ToString("yyyyMMddTHHmmssZ")
        )
    } else { [IO.Path]::GetFullPath($OutputRoot) }
    $prefix = $evidenceRoot.TrimEnd("\", "/") + [IO.Path]::DirectorySeparatorChar
    Assert-R23D40 (
        $resolvedOutput.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase) -and
        -not (Test-Path -LiteralPath $resolvedOutput)
    ) "output must be a new directory under $evidenceRoot"
    [void][IO.Directory]::CreateDirectory($resolvedOutput)
    $completionPath = Join-Path $resolvedOutput "completion.json"

    . $runtimeHelperPath
    $coreBuild = Invoke-SporeSporeR23D3PinnedCargo -RepoRoot $repoRoot `
        -SourceCommit ([string]$source.commit) -TargetRoot (Join-Path $sdkRoot "target") `
        -CargoArguments @(
            "build", "--quiet", "--release", "--locked", "--offline",
            "--manifest-path", (Join-Path $sdkRoot "Cargo.toml"),
            "--package", "sporespore-locomotion-core"
        )
    $godotBuild = Invoke-SporeSporeR23D3PinnedCargo -RepoRoot $repoRoot `
        -SourceCommit ([string]$source.commit) -TargetRoot (Join-Path $sdkRoot "target") `
        -CargoArguments @(
            "build", "--quiet", "--locked", "--offline",
            "--manifest-path", (Join-Path $sdkRoot "Cargo.toml"),
            "--package", "sporespore-godot-adapter"
        )
    $rapierBuild = Invoke-SporeSporeR23D3PinnedCargo -RepoRoot $repoRoot `
        -SourceCommit ([string]$source.commit) -TargetRoot (Join-Path $sdkRoot "target") `
        -CargoArguments @(
            "build", "--quiet", "--release", "--locked", "--offline",
            "--manifest-path", (Join-Path $sdkRoot "adapters\rapier\Cargo.toml"),
            "--bin", "qsdk_r23d40_physical"
        )
    foreach ($artifact in @($coreReleasePath, $godotAdapterPath, $rapierReleasePath)) {
        Assert-R23D40 (Test-Path -LiteralPath $artifact -PathType Leaf) (
            "reproducible runtime artifact is missing: $artifact"
        )
    }
    $zeroWorld = Invoke-R23D40ZeroWorld $pythonHost $powerShellHost $coreReleasePath $rapierReleasePath
    $sourceAfter = Get-SporeSporeAttestationSourceIdentity -RepoRoot $repoRoot `
        -RequireCleanPushedLive
    Assert-R23D40 (
        [string]$sourceAfter.commit -ceq [string]$source.commit -and
        [string]$sourceAfter.tree_git_oid -ceq [string]$source.tree_git_oid
    ) "source changed during runtime materialization or zero-world gate"

    $implementation = Get-Content -Raw -LiteralPath $implementationPath |
        ConvertFrom-Json -AsHashtable -Depth 100
    $sourceBindings = Get-R23D40SourceBindings $implementation
    $rawSourceMismatchCount = @($sourceBindings | Where-Object {
        -not [bool]$_.raw_checkout_equals_git_blob
    }).Count
    $sourceProjectionApplicationCount = @($sourceBindings | Where-Object {
        [bool]$_.deterministic_projection_applied
    }).Count
    $runtimeArtifacts = @(
        [ordered]@{
            name = "locomotion_core_release"
            path = $coreReleasePath
            raw_sha256 = Get-R23D40Sha256 $coreReleasePath
            media_type = "application/vnd.microsoft.portable-executable"
            build_receipt = $coreBuild
        },
        [ordered]@{
            name = "godot_adapter_debug"
            path = $godotAdapterPath
            raw_sha256 = Get-R23D40Sha256 $godotAdapterPath
            media_type = "application/vnd.microsoft.portable-executable"
            build_receipt = $godotBuild
        },
        [ordered]@{
            name = "rapier_r23d40_release_worker"
            path = $rapierReleasePath
            raw_sha256 = Get-R23D40Sha256 $rapierReleasePath
            media_type = "application/vnd.microsoft.portable-executable"
            build_receipt = $rapierBuild
        }
    )
    $externalRuntimeBindings = @(
        [ordered]@{
            name = "godot_jolt_host"
            path = $Godot
            raw_sha256 = Get-R23D40Sha256 $Godot
            media_type = "application/vnd.microsoft.portable-executable"
        },
        [ordered]@{
            name = "mujoco_python_host"
            path = $pythonHost
            raw_sha256 = Get-R23D40Sha256 $pythonHost
            media_type = "application/vnd.microsoft.portable-executable"
        },
        [ordered]@{
            name = "powershell_trace_host"
            path = $powerShellHost
            raw_sha256 = Get-R23D40Sha256 $powerShellHost
            media_type = "application/vnd.microsoft.portable-executable"
        }
    )
    $inputCas = Publish-R23D40Inputs $sourceBindings $runtimeArtifacts `
        $externalRuntimeBindings ([IO.Path]::GetFullPath($CampaignAttestationAdoption))
    $freeze = [ordered]@{
        schema_version = "sporespore_qsdk_r23d40_physical_freeze_v1"
        status = "frozen_supervisor_only_physical_authorized"
        campaign_id = $campaignId
        gate_id = $gateId
        preregistration_raw_sha256 = Get-R23D40Sha256 $preregistrationPath
        implementation_contract_raw_sha256 = Get-R23D40Sha256 $implementationPath
        source_commit = [string]$source.commit
        source_tree_git_oid = [string]$source.tree_git_oid
        origin_main_commit = [string]$source.origin_main
        live_github_main_commit = [string]$source.live_github_main
        source_bindings = $sourceBindings
        runtime_artifacts = $runtimeArtifacts
        external_runtime_bindings = $externalRuntimeBindings
        content_addressed_inputs = $inputCas
        campaign_attestation_adoption_sha256 = [string]$adoption.sha256
        complete_zero_world_gate_passed = $true
        zero_world_receipt = $zeroWorld
        declared_world_count = 9
        ordered_matrix_cell_ids = $cellIds
        serial_execution_required = $true
        all_cells_run_regardless_of_intermediate_outcome = $true
        terminal_restoration_or_taper_invoked = $false
        source_checkout_bytes_equal_git_blobs = ($rawSourceMismatchCount -eq 0)
        source_raw_checkout_mismatch_count = $rawSourceMismatchCount
        source_deterministic_projection_application_count =
            $sourceProjectionApplicationCount
        source_authority_bytes_equal_git_blobs_after_declared_projection = $true
        reproducible_runtime_materialization_passed = $true
        physical_execution_authorized = $true
        physical_acceptance_authority = $false
    }
    $freezePath = Join-Path $resolvedOutput "physical-freeze.json"
    Write-R23D40NewJson $freezePath $freeze
    $freezeCas = Publish-SporeSporeContentAddressedArtifact -RepoRoot $repoRoot `
        -ArtifactPath $freezePath -MediaType "application/json"
    Assert-R23D40FrozenBindings $freeze

    $attemptId = [guid]::NewGuid().ToString("N")
    $token = [guid]::NewGuid().ToString("N")
    $attempt = [ordered]@{
        schema_version = "sporespore_qsdk_r23d40_attempt_v1"
        campaign_id = $campaignId
        gate_id = $gateId
        attempt_id = $attemptId
        authorization_token = $token
        source_commit = [string]$source.commit
        authority_repo_root = $repoRoot
        freeze_raw_sha256 = [string]$freezeCas.sha256
        attempt_root = $resolvedOutput
        ordered_matrix_cell_ids = $cellIds
        physical_execution_authorized = $true
        single_use_supervisor_authorization = $true
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
    Write-R23D40NewJson $attemptPath $attempt
    $attemptCas = Publish-SporeSporeContentAddressedArtifact -RepoRoot $repoRoot `
        -ArtifactPath $attemptPath -MediaType "application/json"
    $attemptConsumed = $true

    $cells = [Collections.Generic.List[object]]::new()
    foreach ($engine in $engineOrder) {
        foreach ($arm in $armOrder) {
            Assert-R23D40FrozenBindings $freeze
            $cellRoot = Join-Path $resolvedOutput "cells\$engine`__$candidateId`__$arm"
            $cells.Add((Invoke-R23D40Cell -EngineId $engine -ArmId $arm `
                -SourceCommit ([string]$source.commit) `
                -FreezePayload ([string]$freezeCas.payload_path) `
                -AttemptPayload ([string]$attemptCas.payload_path) -Token $token `
                -AttemptRoot $resolvedOutput -CellRoot $cellRoot `
                -PythonHost $pythonHost -PowerShellHost $powerShellHost))
        }
    }
    $terminalPaths = @($cells | ForEach-Object {
        [string]$_.terminal_entry_cas.payload_path
    })
    $manifestOutput = Join-Path $resolvedOutput "terminal-paths.json"
    Write-R23D40NewJson $manifestOutput $terminalPaths
    $manifestCas = Publish-SporeSporeContentAddressedArtifact -RepoRoot $repoRoot `
        -ArtifactPath $manifestOutput -MediaType "application/json"
    $evaluationProcess = Invoke-R23D40Process -FileName $pythonHost -Arguments @(
        $evaluatorPath, "evaluate-complete", "--manifest",
        [string]$manifestCas.payload_path, "--expected-source-commit",
        [string]$source.commit
    ) -WorkingDirectory $repoRoot -Environment (Get-R23D40PythonEnvironment $coreReleasePath) `
        -TimeoutSeconds 300
    Assert-R23D40 ($evaluationProcess.exit_code -eq 0 -and -not $evaluationProcess.timed_out) (
        "complete evaluator failed: $($evaluationProcess.stderr) $($evaluationProcess.stdout)"
    )
    $evaluation = Get-R23D40MarkerJson $evaluationProcess.stdout (
        "QSDK_R23D40_COMPLETE_EVALUATION "
    )
    $evaluationPath = Join-Path $resolvedOutput "complete-evaluation.json"
    Write-R23D40NewJson $evaluationPath $evaluation
    $evaluationCas = Publish-SporeSporeContentAddressedArtifact -RepoRoot $repoRoot `
        -ArtifactPath $evaluationPath -MediaType "application/json"
    $report = [ordered]@{
        schema_version = "sporespore_qsdk_r23d40_campaign_report_v1"
        campaign_id = $campaignId
        gate_id = $gateId
        source = $source
        attempt_id = $attemptId
        freeze_cas = $freezeCas
        attempt_authorization_cas = $attemptCas
        terminal_manifest_cas = $manifestCas
        complete_evaluation_cas = $evaluationCas
        ordered_cells = @($cells)
        complete_evaluation = $evaluation
        result_classification = [string]$evaluation.classification
        all_nine_cells_executed_or_retained_as_failures = $cells.Count -eq 9
        terminal_restoration_or_taper_invoked = $false
        claims = $evaluation.claims
    }
    $reportPath = Join-Path $resolvedOutput "report.json"
    Write-R23D40NewJson $reportPath $report
    $reportCas = Publish-SporeSporeContentAddressedArtifact -RepoRoot $repoRoot `
        -ArtifactPath $reportPath -MediaType "application/json"
    $worldCount = 0
    foreach ($cellEvaluation in @($evaluation.cell_evaluations)) {
        $worldCount += [int]$cellEvaluation.world_build_count
    }
    $completion = [ordered]@{
        schema_version = "sporespore_qsdk_r23d40_completion_v1"
        campaign_id = $campaignId
        gate_id = $gateId
        attempt_id = $attemptId
        status = [string]$evaluation.classification
        source_commit = [string]$source.commit
        cell_count = $cells.Count
        world_count = $worldCount
        report_cas = $reportCas
        complete_evaluation_cas = $evaluationCas
        one_shot_attempt_consumed = $true
        replacement_or_selective_rerun_permitted = $false
        completed_utc = [DateTime]::UtcNow.ToString("o")
        physical_acceptance_authority = $false
    }
    Write-R23D40NewJson $completionPath $completion
    $completionCas = Publish-SporeSporeContentAddressedArtifact -RepoRoot $repoRoot `
        -ArtifactPath $completionPath -MediaType "application/json"
    Write-Host (
        "QSDK_R23D40_PHYSICAL_COMPLETE classification=$($evaluation.classification) " +
        "cells=$($cells.Count) report_sha256=$($reportCas.sha256) " +
        "completion_sha256=$($completionCas.sha256) output=$resolvedOutput"
    )
    if ([string]$evaluation.classification -ceq
        "invalid_or_incomplete_three_engine_portable_turning_validation") {
        throw "QSDK-R23D40 retained an invalid complete first attempt: $resolvedOutput"
    }
} catch {
    if ($attemptConsumed -and -not [string]::IsNullOrWhiteSpace($completionPath) -and
        -not (Test-Path -LiteralPath $completionPath)) {
        $emergency = [ordered]@{
            schema_version = "sporespore_qsdk_r23d40_completion_v1"
            campaign_id = $campaignId
            gate_id = $gateId
            status = "invalid_or_incomplete_first_attempt"
            source_commit = [string]$source.commit
            one_shot_attempt_consumed = $true
            replacement_or_selective_rerun_permitted = $false
            failure_message = [string]$_.Exception.Message
            completed_utc = [DateTime]::UtcNow.ToString("o")
            physical_acceptance_authority = $false
        }
        Write-R23D40NewJson $completionPath $emergency
        [void](Publish-SporeSporeContentAddressedArtifact -RepoRoot $repoRoot `
            -ArtifactPath $completionPath -MediaType "application/json")
    }
    throw
} finally {
    Exit-SporeSporeLocomotionOperationLock $lock
}
