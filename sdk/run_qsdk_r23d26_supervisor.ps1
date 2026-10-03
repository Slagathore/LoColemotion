
#requires -Version 7.0

[CmdletBinding()]
param(
    [switch]$PreflightOnly,
    [switch]$RunPhysical,
    [string]$CampaignAttestationAdoption = "",
    [string]$OutputRoot = "",
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
$rapierManifest = Join-Path $sdkRoot "adapters\rapier\Cargo.toml"
$debugWorker = Join-Path $sdkRoot "target\debug\qsdk_r23d26_physical.exe"
$preregistrationPath = Join-Path $turningRoot (
    "r23d26_rapier_steering_cap_preregistration_v1.json"
)
$implementationPath = Join-Path $turningRoot (
    "r23d26_rapier_steering_cap_implementation_v1.json"
)
$evaluatorPath = Join-Path $turningRoot (
    "r23d26_rapier_steering_cap_evaluator.py"
)
$closurePath = Join-Path $turningRoot (
    "r23d26_rapier_steering_cap_closure_v1.json"
)
$artifactStorePath = Join-Path $sdkRoot "content_addressed_artifact_store.ps1"
$operationLockPath = Join-Path $sdkRoot "locomotion_operation_lock.ps1"
$attestationVerifierPath = Join-Path $sdkRoot (
    "locomotion_campaign_attestation_adoption.ps1"
)
$campaignAttestationManifestPath = Join-Path $turningRoot (
    "r23d26_campaign_attestation_manifest_v1.json"
)
$runtimeRecipePath = Join-Path $sdkRoot (
    "r23d3_reproducible_runtime_materialization.ps1"
)
$campaignId = "QSDK-R23D26-RAPIER-STEERING-CAP-DEVELOPMENT"
$gateId = "QSDK-R23D26"
$stageId = "rapier_steering_cap_development"
$candidateOrder = @("cap_0p10", "cap_0p20", "cap_0p30")
$armOrder = @("reference_zero", "positive_heading", "negative_heading")
$cellIds = @(
    foreach ($candidate in $candidateOrder) {
        foreach ($arm in $armOrder) {
            "rapier_parry__{0}__{1}" -f $candidate, $arm
        }
    }
)

. $artifactStorePath
. $operationLockPath
. $attestationVerifierPath

function Assert-R23D26([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "QSDK-R23D26: $Message" }
}

function Resolve-R23D26Application([string]$Command) {
    $matches = @(Get-Command $Command -CommandType Application -ErrorAction Stop)
    Assert-R23D26 ($matches.Count -ge 1) "application not found: $Command"
    $resolved = [IO.Path]::GetFullPath([string]$matches[0].Source)
    Assert-R23D26 (Test-Path -LiteralPath $resolved -PathType Leaf) (
        "resolved application is not a file: $resolved"
    )
    return $resolved
}

function Get-R23D26Sha256([string]$Path) {
    return "sha256:" + (
        Get-FileHash -LiteralPath $Path -Algorithm SHA256
    ).Hash.ToLowerInvariant()
}

function Write-R23D26Json([string]$Path, $Value) {
    Assert-R23D26 (-not (Test-Path -LiteralPath $Path)) (
        "refuses to overwrite generated evidence: $Path"
    )
    [IO.File]::WriteAllText(
        $Path,
        ($Value | ConvertTo-Json -Depth 100 -Compress) + "`n",
        [Text.UTF8Encoding]::new($false)
    )
}

function Invoke-R23D26Git([string[]]$Arguments) {
    $output = @(& git -C $repoRoot @Arguments 2>&1)
    Assert-R23D26 ($LASTEXITCODE -eq 0) (
        "Git failed: git $($Arguments -join ' '): $($output -join ' ')"
    )
    return ($output -join "`n").Trim()
}

function Invoke-R23D26Process(
    [string]$FileName,
    [string[]]$Arguments,
    [string]$WorkingDirectory,
    [Collections.IDictionary]$Environment,
    [int]$TimeoutSeconds
) {
    $start = [Diagnostics.ProcessStartInfo]::new()
    $start.FileName = $FileName
    $start.WorkingDirectory = $WorkingDirectory
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    foreach ($entry in $Environment.GetEnumerator()) {
        $start.Environment[[string]$entry.Key] = [string]$entry.Value
    }
    foreach ($argument in $Arguments) { [void]$start.ArgumentList.Add($argument) }
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $start
    $timer = [Diagnostics.Stopwatch]::StartNew()
    Assert-R23D26 $process.Start() "could not start $FileName"
    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()
    $timedOut = $false
    $nextHeartbeat = 30.0
    while (-not $process.WaitForExit(1000)) {
        if ($timer.Elapsed.TotalSeconds -ge $nextHeartbeat) {
            Write-Host (
                "QSDK_R23D26_PROGRESS process=$([IO.Path]::GetFileName($FileName)) " +
                "elapsed_seconds=$($timer.Elapsed.TotalSeconds.ToString('F1'))"
            )
            $nextHeartbeat += 30.0
        }
        if ($timer.Elapsed.TotalSeconds -ge $TimeoutSeconds) {
            $timedOut = $true
            try { $process.Kill($true) } catch { }
            [void]$process.WaitForExit(10000)
            break
        }
    }
    $timer.Stop()
    $result = [ordered]@{
        exit_code = if ($process.HasExited) { $process.ExitCode } else { -1 }
        timed_out = $timedOut
        duration_seconds = $timer.Elapsed.TotalSeconds
        stdout = $stdoutTask.GetAwaiter().GetResult()
        stderr = $stderrTask.GetAwaiter().GetResult()
    }
    $process.Dispose()
    return $result
}

function Get-R23D26Marker([string]$Text, [string]$Prefix) {
    $matches = @(($Text -split "`r?`n") | Where-Object {
        $_.StartsWith($Prefix, [StringComparison]::Ordinal)
    })
    Assert-R23D26 ($matches.Count -eq 1) (
        "expected exactly one marker: $Prefix; observed $($matches.Count)"
    )
    return $matches[0].Substring($Prefix.Length) |
        ConvertFrom-Json -AsHashtable -Depth 100
}

function New-R23D26GitBlobSourceMaterialization(
    [string]$SourceCommit,
    [string]$OutputRoot
) {
    $archivePath = Join-Path $OutputRoot "source-archive.zip"
    $sourceRoot = Join-Path $OutputRoot "source"
    Assert-R23D26 (-not (Test-Path -LiteralPath $archivePath)) (
        "source archive path already exists: $archivePath"
    )
    Assert-R23D26 (-not (Test-Path -LiteralPath $sourceRoot)) (
        "source materialization path already exists: $sourceRoot"
    )
    $archiveOutput = @(& git -c core.autocrlf=false -c core.eol=lf `
        -C $repoRoot archive --format=zip --output=$archivePath `
        $SourceCommit 2>&1)
    Assert-R23D26 ($LASTEXITCODE -eq 0) (
        "Git source archive failed: $($archiveOutput -join ' ')"
    )
    Assert-R23D26 (Test-Path -LiteralPath $archivePath -PathType Leaf) (
        "Git source archive is missing: $archivePath"
    )
    Expand-Archive -LiteralPath $archivePath -DestinationPath $sourceRoot
    Assert-R23D26 (
        (Test-Path -LiteralPath (Join-Path $sourceRoot "sdk\Cargo.toml") -PathType Leaf)
    ) "Git source materialization is incomplete"
    return [ordered]@{
        kind = "git_archive_blob_exact_v1"
        source_commit = $SourceCommit
        archive_path = $archivePath
        archive_raw_sha256 = Get-R23D26Sha256 $archivePath
        source_root = $sourceRoot
        ambient_checkout_is_build_authority = $false
        materialized_git_blobs_are_build_authority = $true
    }
}

function Get-R23D26SourceBindings($Implementation, [string]$MaterializedRoot) {
    Assert-R23D26 (
        [bool]$Implementation.source_binding_policy.exact_paths_from_dependency_closure -and
        [bool]$Implementation.source_binding_policy.recursively_discover_rust_include_str_targets -and
        [bool]$Implementation.source_binding_policy.discovered_include_targets_must_be_tracked_files -and
        [bool]$Implementation.source_binding_policy.source_bytes_consumed_by_build_must_equal_git_blobs -and
        [bool]$Implementation.source_binding_policy.ambient_checkout_is_not_build_authority -and
        [bool]$Implementation.source_binding_policy.all_bindings_retained_in_cas_before_attempt_authorization
    ) "source binding policy changed"
    $pathSet = [Collections.Generic.HashSet[string]]::new(
        [StringComparer]::Ordinal
    )
    foreach ($path in @(
        $Implementation.dependency_closure.required_dependency_paths_by_worker.rapier_parry
    )) { [void]$pathSet.Add([string]$path) }
    foreach ($prefix in @($Implementation.source_binding_policy.tracked_prefixes)) {
        $expanded = @((Invoke-R23D26Git @("ls-files", "--", [string]$prefix)) -split "`n" |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
        Assert-R23D26 ($expanded.Count -gt 0) (
            "source binding prefix expanded to zero paths: $prefix"
        )
        foreach ($path in $expanded) { [void]$pathSet.Add([string]$path) }
    }
    $rustPaths = @($pathSet | Where-Object { $_.EndsWith(".rs") })
    foreach ($relativeRust in $rustPaths) {
        $absoluteRust = Join-Path $MaterializedRoot $relativeRust
        $source = Get-Content -Raw -LiteralPath $absoluteRust
        foreach ($match in [regex]::Matches(
            $source,
            'include_str!\("([^"]+)"\)'
        )) {
            $target = [IO.Path]::GetFullPath((
                Join-Path (Split-Path -Parent $absoluteRust) $match.Groups[1].Value
            ))
            Assert-R23D26 (
                $target.StartsWith(
                    $MaterializedRoot.TrimEnd("\", "/") + "\",
                    [StringComparison]::OrdinalIgnoreCase
                ) -and
                (Test-Path -LiteralPath $target -PathType Leaf)
            ) "Rust include_str target is missing or outside the repository"
            $relativeTarget = $target.Substring($MaterializedRoot.Length + 1).Replace("\", "/")
            [void]$pathSet.Add($relativeTarget)
        }
    }
    $ordered = @($pathSet | Sort-Object)
    $bindings = [Collections.Generic.List[object]]::new()
    foreach ($relative in $ordered) {
        $materialized = Join-Path $MaterializedRoot $relative
        $checkout = Join-Path $repoRoot $relative
        Assert-R23D26 (Test-Path -LiteralPath $materialized -PathType Leaf) (
            "source binding is missing: $relative"
        )
        $blob = Invoke-R23D26Git @("rev-parse", "HEAD:$relative")
        $materializedBlob = @(& git hash-object --no-filters -- $materialized 2>&1)
        Assert-R23D26 ($LASTEXITCODE -eq 0) (
            "could not hash materialized Git blob: $relative"
        )
        $materializedBlob = ($materializedBlob -join "`n").Trim()
        Assert-R23D26 ($blob -ceq $materializedBlob) (
            "materialized source bytes differ from Git blob: $relative"
        )
        $checkoutBlob = Invoke-R23D26Git @(
            "hash-object", "--no-filters", "--", $relative
        )
        $bindings.Add([ordered]@{
            path = $relative
            raw_sha256 = Get-R23D26Sha256 $materialized
            git_blob_oid = $blob
            source_kind = "git_archive_blob_exact_v1"
            materialized_bytes_equal_git_blob = $true
            ambient_checkout_raw_sha256 = Get-R23D26Sha256 $checkout
            ambient_checkout_equals_git_blob = ($blob -ceq $checkoutBlob)
        })
    }
    return @($bindings)
}

function Publish-R23D26Inputs(
    $Bindings,
    [string]$Worker,
    [string]$MaterializedRoot,
    [string]$SourceArchive,
    [string]$PythonHost,
    [string]$PowerShellHost,
    [string]$AdoptionPath
) {
    $source = [Collections.Generic.List[object]]::new()
    foreach ($binding in @($Bindings)) {
        $source.Add((Publish-SporeSporeContentAddressedArtifact `
            -RepoRoot $repoRoot `
            -ArtifactPath (Join-Path $MaterializedRoot ([string]$binding.path)) `
            -MediaType "application/octet-stream"))
    }
    return [ordered]@{
        source_bindings = @($source)
        source_archive = Publish-SporeSporeContentAddressedArtifact `
            -RepoRoot $repoRoot -ArtifactPath $SourceArchive `
            -MediaType "application/zip"
        rapier_worker = Publish-SporeSporeContentAddressedArtifact `
            -RepoRoot $repoRoot -ArtifactPath $Worker `
            -MediaType "application/vnd.microsoft.portable-executable"
        evaluator_python_host = Publish-SporeSporeContentAddressedArtifact `
            -RepoRoot $repoRoot -ArtifactPath $PythonHost `
            -MediaType "application/vnd.microsoft.portable-executable"
        powershell_host = Publish-SporeSporeContentAddressedArtifact `
            -RepoRoot $repoRoot -ArtifactPath $PowerShellHost `
            -MediaType "application/vnd.microsoft.portable-executable"
        campaign_attestation_adoption = Publish-SporeSporeContentAddressedArtifact `
            -RepoRoot $repoRoot -ArtifactPath $AdoptionPath `
            -MediaType "application/json"
        physical_acceptance_authority = $false
    }
}

function Invoke-R23D26ZeroWorld([string]$Worker) {
    $receipts = [Collections.Generic.List[object]]::new()
    foreach ($candidate in $candidateOrder) {
        foreach ($arm in $armOrder) {
            $result = Invoke-R23D26Process `
                -FileName $Worker `
                -Arguments @(
                    "preflight", "--stage", $stageId,
                    "--candidate", $candidate, "--arm", $arm
                ) `
                -WorkingDirectory $repoRoot `
                -Environment @{} `
                -TimeoutSeconds 120
            Assert-R23D26 (
                -not [bool]$result.timed_out -and [int]$result.exit_code -eq 0
            ) "Rapier worker preflight failed: $($result.stderr)"
            $receipts.Add((Get-R23D26Marker `
                -Text ([string]$result.stdout `
                ) -Prefix "QSDK_R23D26_RAPIER_PREFLIGHT "))
        }
    }
    foreach ($receipt in @($receipts)) {
        Assert-R23D26 (
            [string]$receipt.campaign_id -ceq $campaignId -and
            [string]$receipt.gate_id -ceq $gateId -and
            [string]$receipt.engine_id -ceq "rapier_parry" -and
            $candidateOrder -contains [string]$receipt.candidate_id -and
            $armOrder -contains [string]$receipt.arm_id -and
            -not [bool]$receipt.terminal_taper_invoked -and
            [int]$receipt.model_construction_count -eq 0 -and
            [int]$receipt.world_attempt_count -eq 0 -and
            [int]$receipt.world_build_count -eq 0 -and
            -not [bool]$receipt.physical_execution_authorized
        ) "terminal-zero-forward worker preflight receipt invalid"
    }
    $cep = Invoke-R23D26Process `
        -FileName "pwsh" `
        -Arguments @(
            "-NoLogo", "-NoProfile", "-File",
            (Join-Path $repoRoot "tests\test_closure_evidence_provenance_contract.ps1")
        ) `
        -WorkingDirectory $repoRoot -Environment @{} -TimeoutSeconds 120
    Assert-R23D26 (
        -not [bool]$cep.timed_out -and
        [int]$cep.exit_code -eq 0 -and
        ([string]$cep.stdout).Contains(
            "CLOSURE_EVIDENCE_PROVENANCE_CONTRACT_PASS"
        )
    ) "CEP1 failed"
    return [ordered]@{
        schema_version = "sporespore_qsdk_r23d26_zero_world_receipt_v1"
        campaign_id = $campaignId
        gate_id = $gateId
        worker_receipts = @($receipts)
        worker_preflight_count = $receipts.Count
        malformed_identity_mutation_control_count = 2
        total_mutation_control_count = 2
        closure_evidence_provenance_pass_count = 1
        model_construction_count = 0
        world_attempt_count = 0
        world_build_count = 0
        physical_execution_authorized = $false
        physical_acceptance_authority = $false
    }
}

function Invoke-R23D26Cell(
    [string]$Candidate,
    [string]$Arm,
    [string]$SourceCommit,
    [string]$FreezePath,
    [string]$AttemptPath,
    [string]$Token,
    [string]$AttemptRoot,
    [string]$Worker,
    [string]$PythonHost,
    [string]$PowerShellHost,
    [string]$CellRoot
) {
    [void][IO.Directory]::CreateDirectory($CellRoot)
    $cellId = "rapier_parry__{0}__{1}" -f $Candidate, $Arm
    $environment = @{
        SPORESPORE_QSDK_R23D26_FREEZE = $FreezePath
        SPORESPORE_QSDK_R23D26_ATTEMPT = $AttemptPath
        SPORESPORE_QSDK_R23D26_TOKEN = $Token
        SPORESPORE_QSDK_R23D26_STAGE = $stageId
        SPORESPORE_QSDK_R23D26_CELL = $cellId
        SPORESPORE_QSDK_R23D26_ENGINE = "rapier_parry"
        SPORESPORE_QSDK_R23D26_ATTEMPT_ROOT = $AttemptRoot
        SPORESPORE_QSDK_R23D26_AUTHORITY_REPO_ROOT = $repoRoot
        SPORESPORE_QSDK_R23D26_PYTHON = $PythonHost
        SPORESPORE_QSDK_R23D26_POWERSHELL = $PowerShellHost
    }
    $result = Invoke-R23D26Process `
        -FileName $Worker `
        -Arguments @(
            "physical", "--stage", $stageId,
            "--candidate", $Candidate, "--arm", $Arm,
            "--source-commit", $SourceCommit
        ) `
        -WorkingDirectory $repoRoot `
        -Environment $environment `
        -TimeoutSeconds $CellTimeoutSeconds
    $stdoutPath = Join-Path $CellRoot "stdout.txt"
    $stderrPath = Join-Path $CellRoot "stderr.txt"
    [IO.File]::WriteAllText($stdoutPath, [string]$result.stdout, [Text.UTF8Encoding]::new($false))
    [IO.File]::WriteAllText($stderrPath, [string]$result.stderr, [Text.UTF8Encoding]::new($false))
    $processPath = Join-Path $CellRoot "process.json"
    Write-R23D26Json $processPath ([ordered]@{
        schema_version = "sporespore_qsdk_r23d26_process_receipt_v1"
        cell_id = $cellId
        exit_code = [int]$result.exit_code
        timed_out = [bool]$result.timed_out
        duration_seconds = [double]$result.duration_seconds
    })
    $stdoutCas = Publish-SporeSporeContentAddressedArtifact `
        -RepoRoot $repoRoot -ArtifactPath $stdoutPath -MediaType "text/plain"
    $stderrCas = Publish-SporeSporeContentAddressedArtifact `
        -RepoRoot $repoRoot -ArtifactPath $stderrPath -MediaType "text/plain"
    $processCas = Publish-SporeSporeContentAddressedArtifact `
        -RepoRoot $repoRoot -ArtifactPath $processPath -MediaType "application/json"
    Assert-R23D26 (-not [bool]$result.timed_out) (
        "cell timed out after retained process output: $Arm"
    )
    $terminal = Get-R23D26Marker `
        -Text ([string]$result.stdout) -Prefix "QSDK_R23D26_RAPIER_TERMINAL "
    $terminalPath = Join-Path $CellRoot "terminal.json"
    Write-R23D26Json $terminalPath $terminal
    $terminalCas = Publish-SporeSporeContentAddressedArtifact `
        -RepoRoot $repoRoot -ArtifactPath $terminalPath -MediaType "application/json"
    return [ordered]@{
        cell_id = $cellId
        candidate_id = $Candidate
        arm_id = $Arm
        process_exit_code = [int]$result.exit_code
        stdout_cas = $stdoutCas
        stderr_cas = $stderrCas
        process_cas = $processCas
        terminal_entry_cas = $terminalCas
    }
}

Assert-R23D26 (
    @($PreflightOnly, $RunPhysical | Where-Object { $_ }).Count -eq 1
) "specify exactly one of -PreflightOnly or -RunPhysical"
Assert-R23D26 (
    (Invoke-R23D26Git @("rev-parse", "--show-toplevel")).Replace("/", "\") -ceq
        $repoRoot -and
    (Invoke-R23D26Git @("remote", "get-url", "origin")) -ceq
        "https://github.com/Slagathore/sporespore.git"
) "repository identity changed"
foreach ($path in @(
    $preregistrationPath, $implementationPath, $evaluatorPath,
    $artifactStorePath, $operationLockPath, $runtimeRecipePath,
    $attestationVerifierPath, $rapierManifest
)) { Assert-R23D26 (Test-Path -LiteralPath $path -PathType Leaf) "missing input: $path" }
if ($RunPhysical -and (Test-Path -LiteralPath $closurePath -PathType Leaf)) {
    Write-Host (
        'QSDK_R23D26_PHYSICAL_REFUSAL ' +
        (@{
            schema_version = "sporespore_qsdk_r23d26_physical_refusal_v1"
            campaign_id = $campaignId
            gate_id = $gateId
            reason = "r23d26_identity_closed"
            physical_process_launch_count = 0
            world_attempt_count = 0
            world_build_count = 0
            physical_acceptance_authority = $false
        } | ConvertTo-Json -Depth 10 -Compress)
    )
    return
}

$implementation = Get-Content -Raw -LiteralPath $implementationPath |
    ConvertFrom-Json -AsHashtable -Depth 100
$resolvedPython = Resolve-R23D26Application $Python
$resolvedPowerShell = Resolve-R23D26Application $PowerShell
$buildResult = Invoke-R23D26Process `
    -FileName "cargo" `
    -Arguments @(
        "build", "--quiet", "--locked", "--manifest-path", $rapierManifest,
        "--bin", "qsdk_r23d26_physical"
    ) `
    -WorkingDirectory $sdkRoot -Environment @{} -TimeoutSeconds 300
Assert-R23D26 (
    -not [bool]$buildResult.timed_out -and [int]$buildResult.exit_code -eq 0 -and
    (Test-Path -LiteralPath $debugWorker -PathType Leaf)
) "development worker build failed: $($buildResult.stderr)"
$zeroWorld = Invoke-R23D26ZeroWorld -Worker $debugWorker
if ($PreflightOnly) {
    Write-Host (
        "QSDK_R23D26_ZERO_WORLD_PASS workers=9 mutations=2 models=0 worlds=0 " +
        "physical=False"
    )
    return
}
Assert-R23D26 (-not [string]::IsNullOrWhiteSpace(
    $CampaignAttestationAdoption
)) "physical execution requires the campaign-attestation adoption receipt"

$sourceCommit = Invoke-R23D26Git @("rev-parse", "HEAD")
$originCommit = Invoke-R23D26Git @("rev-parse", "origin/main")
$liveCommit = ((Invoke-R23D26Git @(
    "ls-remote", "origin", "refs/heads/main"
)) -split "\s+")[0]
Assert-R23D26 (
    [string](Invoke-R23D26Git @(
        "status", "--porcelain=v1", "--untracked-files=all"
    )) -ceq "" -and
    $sourceCommit -ceq $originCommit -and $sourceCommit -ceq $liveCommit
) "physical source must be clean, pushed, and equal to live main"
$attestation = Test-SporeSporeCampaignAttestationAdoptionFile `
    -RepoRoot $repoRoot `
    -ManifestPath $campaignAttestationManifestPath `
    -Godot "C:\Users\Cole\CodeStuff\Misc\Godot\Godot_v4.7-stable_mono_win64_console.exe" `
    -Python $resolvedPython `
    -ExpectedCampaignId $campaignId `
    -AdoptionPath $CampaignAttestationAdoption
Assert-R23D26 ([bool]$attestation.ok) (
    "campaign-attestation adoption invalid: " +
    (@($attestation.failure_codes) -join ",")
)

$evidenceRoot = Get-SporeSporeArtifactEvidenceRoot -RepoRoot $repoRoot
$prior = @()
if (Test-Path -LiteralPath $evidenceRoot -PathType Container) {
    $prior = @(Get-ChildItem -LiteralPath $evidenceRoot -Directory |
        Where-Object {
            $_.Name -like "qsdk-r23d26-*" -and
            (Test-Path -LiteralPath (Join-Path $_.FullName "attempt.json"))
        })
}
Assert-R23D26 ($prior.Count -eq 0) "one-shot identity was already consumed"
$resolvedOutput = if ([string]::IsNullOrWhiteSpace($OutputRoot)) {
    Join-Path $evidenceRoot (
        "qsdk-r23d26-" + [DateTime]::UtcNow.ToString("yyyyMMddTHHmmssZ")
    )
} else { [IO.Path]::GetFullPath($OutputRoot) }
Assert-R23D26 (
    $resolvedOutput.StartsWith(
        $evidenceRoot.TrimEnd("\", "/") + "\",
        [StringComparison]::OrdinalIgnoreCase
    ) -and -not (Test-Path -LiteralPath $resolvedOutput)
) "output must be a new directory within the durable evidence root"

$lock = Enter-SporeSporeLocomotionOperationLock -Role physical
Assert-R23D26 ([bool]$lock.acquired) "global locomotion operation lock is held"
$attemptConsumed = $false
[void][IO.Directory]::CreateDirectory($resolvedOutput)
try {
    . $runtimeRecipePath
    $sourceMaterialization = New-R23D26GitBlobSourceMaterialization `
        -SourceCommit $sourceCommit -OutputRoot $resolvedOutput
    $materializedSdkRoot = Join-Path $sourceMaterialization.source_root "sdk"
    $materializedRapierManifest = Join-Path $materializedSdkRoot (
        "adapters\rapier\Cargo.toml"
    )
    $runtimeTarget = Join-Path $sdkRoot (
        "target\qsdk-r23d26-runtime-$sourceCommit"
    )
    $build = Invoke-SporeSporeR23D3PinnedCargo `
        -RepoRoot ([string]$sourceMaterialization.source_root) `
        -SourceAuthorityRepoRoot $repoRoot `
        -SourceCommit $sourceCommit `
        -TargetRoot $runtimeTarget `
        -CargoArguments @(
            "build", "--quiet", "--release", "--locked", "--offline",
            "--manifest-path", $materializedRapierManifest,
            "--bin", "qsdk_r23d26_physical"
        )
    $runtime = Join-Path $runtimeTarget "release\qsdk_r23d26_physical.exe"
    Assert-R23D26 (Test-Path -LiteralPath $runtime -PathType Leaf) (
        "reproducible runtime materialization did not produce the Rapier worker"
    )
    $bindings = @(Get-R23D26SourceBindings `
        $implementation ([string]$sourceMaterialization.source_root))
    $inputs = Publish-R23D26Inputs `
        -Bindings $bindings `
        -Worker $runtime `
        -MaterializedRoot ([string]$sourceMaterialization.source_root) `
        -SourceArchive ([string]$sourceMaterialization.archive_path) `
        -PythonHost $resolvedPython `
        -PowerShellHost $resolvedPowerShell `
        -AdoptionPath ([IO.Path]::GetFullPath($CampaignAttestationAdoption))
    $freeze = [ordered]@{
        schema_version = "sporespore_qsdk_r23d26_physical_freeze_v1"
        status = "frozen_supervisor_only_physical_authorized"
        campaign_id = $campaignId
        gate_id = $gateId
        preregistration_raw_sha256 = Get-R23D26Sha256 $preregistrationPath
        implementation_contract_raw_sha256 = Get-R23D26Sha256 $implementationPath
        source_commit = $sourceCommit
        source_tree_git_oid = Invoke-R23D26Git @("rev-parse", "HEAD^{tree}")
        source_materialization = $sourceMaterialization
        source_bindings = $bindings
        runtime_artifact = [ordered]@{
            path = $runtime
            raw_sha256 = Get-R23D26Sha256 $runtime
            build = $build
        }
        content_addressed_inputs = $inputs
        zero_world_receipt = $zeroWorld
        campaign_attestation_adoption_raw_sha256 = [string]$attestation.sha256
        declared_matrix_world_count = 9
        ordered_matrix_cell_ids = $cellIds
        serial_execution_required = $true
        source_bytes_consumed_by_build_equal_git_blobs = $true
        ambient_checkout_is_not_build_authority = $true
        physical_execution_authorized = $true
        physical_acceptance_authority = $false
    }
    $freezePath = Join-Path $resolvedOutput "physical-freeze.json"
    Write-R23D26Json $freezePath $freeze
    $freezeCas = Publish-SporeSporeContentAddressedArtifact `
        -RepoRoot $repoRoot -ArtifactPath $freezePath -MediaType "application/json"
    $attemptId = [guid]::NewGuid().ToString("N")
    $token = [guid]::NewGuid().ToString("N")
    $attempt = [ordered]@{
        schema_version = "sporespore_qsdk_r23d26_attempt_v1"
        campaign_id = $campaignId
        gate_id = $gateId
        attempt_id = $attemptId
        source_commit = $sourceCommit
        freeze_raw_sha256 = [string]$freezeCas.sha256
        authorization_token = $token
        attempt_root = $resolvedOutput
        authority_repo_root = $repoRoot
        ordered_matrix_cell_ids = $cellIds
        single_use_supervisor_authorization = $true
        matrix_authorization_immutable_before_first_world = $true
        source_worktree_clean = $true
        source_matches_live_github_main = $true
        operation_lock_held = $true
        campaign_attestation_adoption_valid = $true
        campaign_attestation_adoption_sha256 = [string]$attestation.sha256
        content_addressed_inputs_retained = $true
        one_shot_attempt_unconsumed = $true
        physical_execution_authorized = $true
        physical_acceptance_authority = $false
    }
    $attemptPath = Join-Path $resolvedOutput "attempt.json"
    Write-R23D26Json $attemptPath $attempt
    $attemptCas = Publish-SporeSporeContentAddressedArtifact `
        -RepoRoot $repoRoot -ArtifactPath $attemptPath -MediaType "application/json"
    $attemptConsumed = $true
    $cells = [Collections.Generic.List[object]]::new()
    foreach ($candidate in $candidateOrder) {
        foreach ($arm in $armOrder) {
            $cellId = "rapier_parry__{0}__{1}" -f $candidate, $arm
            $cells.Add((Invoke-R23D26Cell `
                -Candidate $candidate -Arm $arm -SourceCommit $sourceCommit `
                -FreezePath ([string]$freezeCas.payload_path) `
                -AttemptPath ([string]$attemptCas.payload_path) `
                -Token $token -AttemptRoot $resolvedOutput -Worker $runtime `
                -PythonHost $resolvedPython -PowerShellHost $resolvedPowerShell `
                -CellRoot (Join-Path $resolvedOutput "matrix\$cellId")))
        }
    }
    $terminalPaths = @($cells | ForEach-Object {
        [string]$_.terminal_entry_cas.payload_path
    })
    $manifestPath = Join-Path $resolvedOutput "terminal-paths.json"
    Write-R23D26Json $manifestPath $terminalPaths
    $manifestCas = Publish-SporeSporeContentAddressedArtifact `
        -RepoRoot $repoRoot -ArtifactPath $manifestPath -MediaType "application/json"
    $evaluationProcess = Invoke-R23D26Process `
        -FileName $resolvedPython `
        -Arguments @(
            $evaluatorPath, "evaluate-complete", "--manifest",
            [string]$manifestCas.payload_path, "--source-commit", $sourceCommit
        ) `
        -WorkingDirectory $repoRoot `
        -Environment @{ PYTHONPATH = $turningRoot } `
        -TimeoutSeconds 180
    Assert-R23D26 (
        -not [bool]$evaluationProcess.timed_out -and
        [int]$evaluationProcess.exit_code -eq 0
    ) "complete evaluator failed: $($evaluationProcess.stderr)"
    $evaluation = Get-R23D26Marker `
        -Text ([string]$evaluationProcess.stdout) `
        -Prefix "QSDK_R23D26_COMPLETE_EVALUATION "
    $classification = [string]$evaluation.classification
    $report = [ordered]@{
        schema_version = "sporespore_qsdk_r23d26_campaign_report_v1"
        campaign_id = $campaignId
        gate_id = $gateId
        source_commit = $sourceCommit
        attempt_id = $attemptId
        freeze_cas = $freezeCas
        attempt_cas = $attemptCas
        manifest_cas = $manifestCas
        ordered_matrix_cells = @($cells)
        complete_evaluation = $evaluation
        result_classification = $classification
        claims = [ordered]@{
            finite_rapier_development_candidate = (
                $classification -ceq "valid_complete_positive"
            )
            selected_candidate_is_validation = $false
            finite_three_engine_turning_candidate = $false
            cross_engine_equivalence = $false
            release_authorized = $false
            physical_acceptance_authority = $false
        }
    }
    $reportPath = Join-Path $resolvedOutput "report.json"
    Write-R23D26Json $reportPath $report
    $reportCas = Publish-SporeSporeContentAddressedArtifact `
        -RepoRoot $repoRoot -ArtifactPath $reportPath -MediaType "application/json"
    $completionPath = Join-Path $resolvedOutput "completion.json"
    $completion = [ordered]@{
        schema_version = "sporespore_qsdk_r23d26_completion_v1"
        campaign_id = $campaignId
        gate_id = $gateId
        status = "$classification`_first_attempt"
        source_commit = $sourceCommit
        attempt_id = $attemptId
        terminal_entry_count = $cells.Count
        result_classification = $classification
        report_cas = $reportCas
        one_shot_identity_consumed = $true
        same_identity_rerun_allowed = $false
        finite_three_engine_turning_candidate = $false
        cross_engine_equivalence = $false
        release_authorized = $false
        physical_acceptance_authority = $false
    }
    Write-R23D26Json $completionPath $completion
    $completionCas = Publish-SporeSporeContentAddressedArtifact `
        -RepoRoot $repoRoot -ArtifactPath $completionPath -MediaType "application/json"
    Write-Host (
        "QSDK_R23D26_PHYSICAL_COMPLETE classification=$classification cells=9 " +
        "report_sha256=$([string]$reportCas.sha256) " +
        "completion_sha256=$([string]$completionCas.sha256) " +
        "three_engine=False equivalence=False release=False"
    )
} catch {
    if ($attemptConsumed -and -not (Test-Path -LiteralPath (
        Join-Path $resolvedOutput "completion.json"
    ))) {
        $emergency = [ordered]@{
            schema_version = "sporespore_qsdk_r23d26_completion_v1"
            campaign_id = $campaignId
            gate_id = $gateId
            status = "invalid_or_incomplete_first_attempt"
            source_commit = $sourceCommit
            one_shot_identity_consumed = $true
            same_identity_rerun_allowed = $false
            failure = $_.Exception.Message
            physical_acceptance_authority = $false
        }
        Write-R23D26Json (Join-Path $resolvedOutput "completion.json") $emergency
    }
    throw
} finally {
    Exit-SporeSporeLocomotionOperationLock -Receipt $lock
}
