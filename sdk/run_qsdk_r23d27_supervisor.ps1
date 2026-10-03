
#requires -Version 7.0

[CmdletBinding()]
param(
    [switch]$PreflightOnly,
    [switch]$RunPhysical,
    [string]$CampaignAttestationAdoption = "",
    [string]$OutputRoot = "",
    [string]$Python = "python",
    [string]$PowerShell = "pwsh",
    [ValidateRange(300, 3600)][int]$CellTimeoutSeconds = 900,
    [ValidateSet("R23D27", "R23D28", "R23D29", "R23D30", "R23D31", "R23D32", "R23D43", "R23D44", "R23D49", "R23D50")][string]$CampaignVariant = "R23D27"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$sdkRoot = [IO.Path]::GetFullPath($PSScriptRoot)
$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $sdkRoot))
$turningRoot = Join-Path $sdkRoot "turning"
$rapierManifest = Join-Path $sdkRoot "adapters\rapier\Cargo.toml"
$predictive = $CampaignVariant -cne "R23D27"
$cycleCoherent = $CampaignVariant -ceq "R23D30"
$retentionHardenedReplication = $CampaignVariant -ceq "R23D43"
$pairedStartupTransform = $CampaignVariant -ceq "R23D44"
$r49RetentionRepairReplay = $CampaignVariant -ceq "R23D49"
$r50PathIdentityReplay = $CampaignVariant -ceq "R23D50"
$implementationRepairReplay = $r49RetentionRepairReplay -or $r50PathIdentityReplay
$hardenedEvidenceRoute = $CampaignVariant -in @("R23D43", "R23D44", "R23D49", "R23D50")
$turningReplication = $CampaignVariant -in @("R23D32", "R23D43", "R23D49", "R23D50")
$cycleIntegrated = $CampaignVariant -in @("R23D31", "R23D32", "R23D43", "R23D44", "R23D49", "R23D50")
$measurementValidation = $CampaignVariant -in @("R23D30", "R23D31")
$persistent = $CampaignVariant -in @("R23D29", "R23D30", "R23D31", "R23D32", "R23D43", "R23D44", "R23D49", "R23D50")
$variantLower = $CampaignVariant.ToLowerInvariant()
$markerStem = "QSDK_" + $CampaignVariant
$identitySlug = "qsdk-" + $variantLower
$workerBinaryName = "qsdk_${variantLower}_physical"
$debugWorker = Join-Path $sdkRoot ("target\debug\{0}.exe" -f $workerBinaryName)
$preregistrationPath = Join-Path $turningRoot $(if ($r50PathIdentityReplay) {
    "r23d50_rapier_cas_path_identity_replay_preregistration_v1.json"
} elseif ($r49RetentionRepairReplay) {
    "r23d49_rapier_retention_repair_replay_preregistration_v1.json"
} elseif ($pairedStartupTransform) {
    "r23d44_rapier_paired_startup_transform_preregistration_v1.json"
} elseif ($retentionHardenedReplication) {
    "r23d43_rapier_retention_hardened_turning_preregistration_v1.json"
} elseif ($turningReplication) {
    "r23d32_finite_rapier_turning_replication_preregistration_v1.json"
} elseif ($cycleIntegrated) {
    "r23d31_cycle_integrated_directional_response_preregistration_v1.json"
} elseif ($cycleCoherent) {
    "r23d30_cycle_coherent_directional_response_preregistration_v1.json"
} elseif ($persistent) {
    "r23d29_two_swing_persistent_predictive_stability_guarded_steering_preregistration_v1.json"
} elseif ($predictive) {
    "r23d28_predictive_stability_guarded_steering_preregistration_v1.json"
} else {
    "r23d27_stability_guarded_steering_preregistration_v1.json"
})
$implementationPath = Join-Path $turningRoot $(if ($r50PathIdentityReplay) {
    "r23d50_rapier_cas_path_identity_replay_implementation_v1.json"
} elseif ($r49RetentionRepairReplay) {
    "r23d49_rapier_retention_repair_replay_implementation_v1.json"
} elseif ($pairedStartupTransform) {
    "r23d44_rapier_paired_startup_transform_implementation_v1.json"
} elseif ($retentionHardenedReplication) {
    "r23d43_rapier_retention_hardened_turning_implementation_v1.json"
} elseif ($turningReplication) {
    "r23d32_finite_rapier_turning_replication_implementation_v1.json"
} elseif ($cycleIntegrated) {
    "r23d31_cycle_integrated_directional_response_implementation_v1.json"
} elseif ($cycleCoherent) {
    "r23d30_cycle_coherent_directional_response_implementation_v1.json"
} elseif ($persistent) {
    "r23d29_two_swing_persistent_predictive_stability_guarded_steering_implementation_v1.json"
} elseif ($predictive) {
    "r23d28_predictive_stability_guarded_steering_implementation_v1.json"
} else {
    "r23d27_stability_guarded_steering_implementation_v1.json"
})
$evaluatorPath = Join-Path $turningRoot $(if ($r50PathIdentityReplay) {
    "r23d50_rapier_cas_path_identity_replay_evaluator.py"
} elseif ($r49RetentionRepairReplay) {
    "r23d49_rapier_retention_repair_replay_evaluator.py"
} elseif ($pairedStartupTransform) {
    "r23d44_rapier_paired_startup_transform_evaluator.py"
} elseif ($retentionHardenedReplication) {
    "r23d43_rapier_retention_hardened_turning_evaluator.py"
} elseif ($turningReplication) {
    "r23d32_finite_rapier_turning_replication_evaluator.py"
} elseif ($cycleIntegrated) {
    "r23d31_cycle_integrated_directional_response_evaluator.py"
} elseif ($cycleCoherent) {
    "r23d30_cycle_coherent_directional_response_evaluator.py"
} elseif ($persistent) {
    "r23d29_two_swing_persistent_predictive_stability_guarded_steering_evaluator.py"
} elseif ($predictive) {
    "r23d28_predictive_stability_guarded_steering_evaluator.py"
} else {
    "r23d27_stability_guarded_steering_evaluator.py"
})
$closurePath = Join-Path $turningRoot $(if ($r50PathIdentityReplay) {
    "r23d50_rapier_cas_path_identity_replay_closure_v1.json"
} elseif ($r49RetentionRepairReplay) {
    "r23d49_rapier_retention_repair_replay_closure_v1.json"
} elseif ($pairedStartupTransform) {
    "r23d44_rapier_paired_startup_transform_closure_v1.json"
} elseif ($retentionHardenedReplication) {
    "r23d43_rapier_retention_hardened_turning_closure_v1.json"
} elseif ($turningReplication) {
    "r23d32_finite_rapier_turning_replication_closure_v1.json"
} elseif ($cycleIntegrated) {
    "r23d31_cycle_integrated_directional_response_closure_v1.json"
} elseif ($cycleCoherent) {
    "r23d30_cycle_coherent_directional_response_closure_v1.json"
} elseif ($persistent) {
    "r23d29_two_swing_persistent_predictive_stability_guarded_steering_closure_v1.json"
} elseif ($predictive) {
    "r23d28_predictive_stability_guarded_steering_closure_v1.json"
} else {
    "r23d27_stability_guarded_steering_closure_v1.json"
})
$artifactStorePath = Join-Path $sdkRoot "content_addressed_artifact_store.ps1"
$operationLockPath = Join-Path $sdkRoot "locomotion_operation_lock.ps1"
$attestationVerifierPath = Join-Path $sdkRoot (
    "locomotion_campaign_attestation_adoption.ps1"
)
$campaignAttestationManifestPath = Join-Path $turningRoot (
    "${variantLower}_campaign_attestation_manifest_v1.json"
)
$runtimeRecipePath = Join-Path $sdkRoot (
    "r23d3_reproducible_runtime_materialization.ps1"
)
$campaignId = if ($r50PathIdentityReplay) {
    "QSDK-R23D50-RAPIER-CAS-PATH-IDENTITY-REPLAY"
} elseif ($r49RetentionRepairReplay) {
    "QSDK-R23D49-RAPIER-RETENTION-REPAIR-REPLAY"
} elseif ($pairedStartupTransform) {
    "QSDK-R23D44-RAPIER-PAIRED-STARTUP-TRANSFORM-DEVELOPMENT"
} elseif ($retentionHardenedReplication) {
    "QSDK-R23D43-RAPIER-RETENTION-HARDENED-TURNING-REPLICATION"
} elseif ($turningReplication) {
    "QSDK-R23D32-RAPIER-FINITE-TURNING-REPLICATION-VALIDATION"
} elseif ($cycleIntegrated) {
    "QSDK-R23D31-RAPIER-CYCLE-INTEGRATED-DIRECTIONAL-RESPONSE-MEASUREMENT-VALIDATION"
} elseif ($cycleCoherent) {
    "QSDK-R23D30-RAPIER-CYCLE-COHERENT-DIRECTIONAL-RESPONSE-MEASUREMENT-VALIDATION"
} elseif ($persistent) {
    "QSDK-R23D29-RAPIER-TWO-SWING-PERSISTENT-PREDICTIVE-STABILITY-GUARDED-STEERING-DEVELOPMENT"
} elseif ($predictive) {
    "QSDK-R23D28-RAPIER-PREDICTIVE-STABILITY-GUARDED-STEERING-DEVELOPMENT"
} else { "QSDK-R23D27-RAPIER-STABILITY-GUARDED-STEERING-VALIDATION" }
$gateId = "QSDK-" + $CampaignVariant
$stageId = if ($r50PathIdentityReplay) {
    "rapier_r49_cas_path_identity_replay"
} elseif ($r49RetentionRepairReplay) {
    "rapier_r48_retention_repair_replay"
} elseif ($pairedStartupTransform) {
    "rapier_paired_startup_transform_development"
} elseif ($retentionHardenedReplication) {
    "rapier_retention_hardened_turning_replication"
} elseif ($turningReplication) {
    "rapier_finite_turning_replication_validation"
} elseif ($cycleIntegrated) {
    "rapier_cycle_integrated_directional_response_measurement_validation"
} elseif ($cycleCoherent) {
    "rapier_cycle_coherent_directional_response_measurement_validation"
} elseif ($persistent) {
    "rapier_two_swing_persistent_predictive_stability_guarded_steering_development"
} elseif ($predictive) {
    "rapier_predictive_stability_guarded_steering_development"
} else { "rapier_stability_guarded_steering_validation" }
$candidateOrder = @(
    if ($implementationRepairReplay) {
        "r23d29_support_loss_conditioned_turning_validation"
    } elseif ($pairedStartupTransform) {
        "r23d29_no_startup_ramp_control"
        "r23d29_canonical_startup_ramp_treatment"
    } elseif ($retentionHardenedReplication) {
        "r23d29_startup_ramp_turning_validation"
    } elseif ($measurementValidation -or $turningReplication) {
        "two_swing_persistent_predictive_stability_guarded_0p20_to_0p28"
    } elseif ($persistent) {
        "two_swing_persistent_predictive_stability_guarded_0p20_to_0p28"
    } elseif ($predictive) {
        "predictive_stability_guarded_0p20_to_0p28"
    } else { "stability_guarded_0p20_to_0p28" }
)
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

function Assert-R23D27([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "QSDK-${CampaignVariant}: $Message" }
}

function Resolve-R23D27Application([string]$Command) {
    $matches = @(Get-Command $Command -CommandType Application -ErrorAction Stop)
    Assert-R23D27 ($matches.Count -ge 1) "application not found: $Command"
    $resolved = [IO.Path]::GetFullPath([string]$matches[0].Source)
    Assert-R23D27 (Test-Path -LiteralPath $resolved -PathType Leaf) (
        "resolved application is not a file: $resolved"
    )
    return $resolved
}

function Get-R23D27Sha256([string]$Path) {
    return "sha256:" + (
        Get-FileHash -LiteralPath $Path -Algorithm SHA256
    ).Hash.ToLowerInvariant()
}

function Write-R23D27Json([string]$Path, $Value) {
    Assert-R23D27 (-not (Test-Path -LiteralPath $Path)) (
        "refuses to overwrite generated evidence: $Path"
    )
    [IO.File]::WriteAllText(
        $Path,
        ($Value | ConvertTo-Json -Depth 100 -Compress) + "`n",
        [Text.UTF8Encoding]::new($false)
    )
}

function Invoke-R23D27Git([string[]]$Arguments) {
    $output = @(& git -C $repoRoot @Arguments 2>&1)
    Assert-R23D27 ($LASTEXITCODE -eq 0) (
        "Git failed: git $($Arguments -join ' '): $($output -join ' ')"
    )
    return ($output -join "`n").Trim()
}

function Invoke-R23D27Process(
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
    Assert-R23D27 $process.Start() "could not start $FileName"
    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()
    $timedOut = $false
    $nextHeartbeat = 30.0
    while (-not $process.WaitForExit(1000)) {
        if ($timer.Elapsed.TotalSeconds -ge $nextHeartbeat) {
            Write-Host (
                "${markerStem}_PROGRESS process=$([IO.Path]::GetFileName($FileName)) " +
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

function Get-R23D27Marker([string]$Text, [string]$Prefix) {
    $matches = @(($Text -split "`r?`n") | Where-Object {
        $_.StartsWith($Prefix, [StringComparison]::Ordinal)
    })
    Assert-R23D27 ($matches.Count -eq 1) (
        "expected exactly one marker: $Prefix; observed $($matches.Count)"
    )
    return $matches[0].Substring($Prefix.Length) |
        ConvertFrom-Json -AsHashtable -Depth 100
}

function New-R23D27GitBlobSourceMaterialization(
    [string]$SourceCommit,
    [string]$OutputRoot
) {
    $archivePath = Join-Path $OutputRoot "source-archive.zip"
    $sourceRoot = Join-Path $OutputRoot "source"
    Assert-R23D27 (-not (Test-Path -LiteralPath $archivePath)) (
        "source archive path already exists: $archivePath"
    )
    Assert-R23D27 (-not (Test-Path -LiteralPath $sourceRoot)) (
        "source materialization path already exists: $sourceRoot"
    )
    $archiveOutput = @(& git -c core.autocrlf=false -c core.eol=lf `
        -C $repoRoot archive --format=zip --output=$archivePath `
        $SourceCommit 2>&1)
    Assert-R23D27 ($LASTEXITCODE -eq 0) (
        "Git source archive failed: $($archiveOutput -join ' ')"
    )
    Assert-R23D27 (Test-Path -LiteralPath $archivePath -PathType Leaf) (
        "Git source archive is missing: $archivePath"
    )
    Expand-Archive -LiteralPath $archivePath -DestinationPath $sourceRoot
    Assert-R23D27 (
        (Test-Path -LiteralPath (Join-Path $sourceRoot "sdk\Cargo.toml") -PathType Leaf)
    ) "Git source materialization is incomplete"
    return [ordered]@{
        kind = "git_archive_blob_exact_v1"
        source_commit = $SourceCommit
        archive_path = $archivePath
        archive_raw_sha256 = Get-R23D27Sha256 $archivePath
        source_root = $sourceRoot
        ambient_checkout_is_build_authority = $false
        materialized_git_blobs_are_build_authority = $true
    }
}

function Get-R23D27SourceBindings($Implementation, [string]$MaterializedRoot) {
    Assert-R23D27 (
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
        $expanded = @((Invoke-R23D27Git @("ls-files", "--", [string]$prefix)) -split "`n" |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
        Assert-R23D27 ($expanded.Count -gt 0) (
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
            Assert-R23D27 (
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
        Assert-R23D27 (Test-Path -LiteralPath $materialized -PathType Leaf) (
            "source binding is missing: $relative"
        )
        $blob = Invoke-R23D27Git @("rev-parse", "HEAD:$relative")
        $materializedBlob = @(& git hash-object --no-filters -- $materialized 2>&1)
        Assert-R23D27 ($LASTEXITCODE -eq 0) (
            "could not hash materialized Git blob: $relative"
        )
        $materializedBlob = ($materializedBlob -join "`n").Trim()
        Assert-R23D27 ($blob -ceq $materializedBlob) (
            "materialized source bytes differ from Git blob: $relative"
        )
        $checkoutBlob = Invoke-R23D27Git @(
            "hash-object", "--no-filters", "--", $relative
        )
        $bindings.Add([ordered]@{
            path = $relative
            raw_sha256 = Get-R23D27Sha256 $materialized
            git_blob_oid = $blob
            source_kind = "git_archive_blob_exact_v1"
            materialized_bytes_equal_git_blob = $true
            ambient_checkout_raw_sha256 = Get-R23D27Sha256 $checkout
            ambient_checkout_equals_git_blob = ($blob -ceq $checkoutBlob)
        })
    }
    return @($bindings)
}

function Publish-R23D27Inputs(
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

function Invoke-R23D27ZeroWorld([string]$Worker, [string]$PythonHost) {
    $receipts = [Collections.Generic.List[object]]::new()
    foreach ($candidate in $candidateOrder) {
        foreach ($arm in $armOrder) {
            $result = Invoke-R23D27Process `
                -FileName $Worker `
                -Arguments @(
                    "preflight", "--stage", $stageId,
                    "--candidate", $candidate, "--arm", $arm
                ) `
                -WorkingDirectory $repoRoot `
                -Environment @{} `
                -TimeoutSeconds 120
            Assert-R23D27 (
                -not [bool]$result.timed_out -and [int]$result.exit_code -eq 0
            ) "Rapier worker preflight failed: $($result.stderr)"
            $receipts.Add((Get-R23D27Marker `
                -Text ([string]$result.stdout `
                ) -Prefix "${markerStem}_RAPIER_PREFLIGHT "))
        }
    }
    foreach ($receipt in @($receipts)) {
        Assert-R23D27 (
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
    $identityMutationCount = 0
    if ($hardenedEvidenceRoute) {
        foreach ($mutation in @(
            [ordered]@{ candidate = "invalid_candidate"; arm = "reference_zero" },
            [ordered]@{ candidate = $candidateOrder[0]; arm = "invalid_arm" }
        )) {
            $mutationResult = Invoke-R23D27Process `
                -FileName $Worker `
                -Arguments @(
                    "preflight", "--stage", $stageId,
                    "--candidate", [string]$mutation.candidate,
                    "--arm", [string]$mutation.arm
                ) `
                -WorkingDirectory $repoRoot `
                -Environment @{} `
                -TimeoutSeconds 120
            Assert-R23D27 (
                -not [bool]$mutationResult.timed_out -and
                [int]$mutationResult.exit_code -ne 0
            ) "worker identity mutation was not rejected"
            $failure = Get-R23D27Marker `
                -Text ([string]$mutationResult.stdout) `
                -Prefix "${markerStem}_RAPIER_FAILURE "
            Assert-R23D27 (
                [string]$failure.failure_stage -ceq "before_model" -and
                [int]$failure.model_construction_count -eq 0 -and
                [int]$failure.world_attempt_count -eq 0 -and
                [int]$failure.world_build_count -eq 0
            ) "worker identity mutation crossed the zero-world boundary"
            $identityMutationCount++
        }
    } else {
        # Historical variants retain their already-frozen receipt semantics.
        $identityMutationCount = 2
    }
    $evaluatorReceipt = $null
    $closureEvidencePassCount = 0
    if ($hardenedEvidenceRoute) {
        $evaluator = Invoke-R23D27Process `
            -FileName $PythonHost `
            -Arguments @($evaluatorPath, "preflight") `
            -WorkingDirectory $repoRoot `
            -Environment @{ PYTHONPATH = $turningRoot } `
            -TimeoutSeconds 120
        Assert-R23D27 (
            -not [bool]$evaluator.timed_out -and
            [int]$evaluator.exit_code -eq 0
        ) "focused evaluator preflight failed: $($evaluator.stderr)"
        $evaluatorReceipt = Get-R23D27Marker `
            -Text ([string]$evaluator.stdout) `
            -Prefix "${markerStem}_EVALUATOR_PREFLIGHT "
        $expectedEvaluatorMutationCount = if ($pairedStartupTransform) {
            3
        } elseif ($implementationRepairReplay) {
            2
        } else { 1 }
        Assert-R23D27 (
            [string]$evaluatorReceipt.campaign_id -ceq $campaignId -and
            [string]$evaluatorReceipt.gate_id -ceq $gateId -and
            [int]$evaluatorReceipt.trace_mutation_rejection_count -eq
                $expectedEvaluatorMutationCount -and
            (-not ($pairedStartupTransform -or $r50PathIdentityReplay) -or (
                [int]$evaluatorReceipt.same_file_path_spelling_positive_control_count -eq 1 -and
                [int]$evaluatorReceipt.wrong_file_path_rejection_count -eq 1
            )) -and
            [int]$evaluatorReceipt.model_construction_count -eq 0 -and
            [int]$evaluatorReceipt.world_attempt_count -eq 0 -and
            [int]$evaluatorReceipt.world_build_count -eq 0
        ) "focused evaluator receipt invalid"
    } else {
        $cep = Invoke-R23D27Process `
            -FileName "pwsh" `
            -Arguments @(
                "-NoLogo", "-NoProfile", "-File",
                (Join-Path $repoRoot "tests\test_closure_evidence_provenance_contract.ps1")
            ) `
            -WorkingDirectory $repoRoot -Environment @{} -TimeoutSeconds 120
        Assert-R23D27 (
            -not [bool]$cep.timed_out -and
            [int]$cep.exit_code -eq 0 -and
            ([string]$cep.stdout).Contains(
                "CLOSURE_EVIDENCE_PROVENANCE_CONTRACT_PASS"
            )
        ) "CEP1 failed"
        $closureEvidencePassCount = 1
    }
    return [ordered]@{
        schema_version = "sporespore_qsdk_${variantLower}_zero_world_receipt_v1"
        campaign_id = $campaignId
        gate_id = $gateId
        worker_receipts = @($receipts)
        evaluator_preflight_receipt = $evaluatorReceipt
        worker_preflight_count = $receipts.Count
        malformed_identity_mutation_control_count = $identityMutationCount
        total_mutation_control_count = (
            $identityMutationCount +
            $(if ($hardenedEvidenceRoute) {
                [int]$evaluatorReceipt.trace_mutation_rejection_count
            } else { 0 })
        )
        closure_evidence_provenance_pass_count = $closureEvidencePassCount
        closure_evidence_provenance_delegated_to_campaign_attestation = (
            $hardenedEvidenceRoute
        )
        model_construction_count = 0
        world_attempt_count = 0
        world_build_count = 0
        physical_execution_authorized = $false
        physical_acceptance_authority = $false
    }
}

function Invoke-R23D27Cell(
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
    $environmentPrefix = "SPORESPORE_QSDK_" + $CampaignVariant
    $environment = @{}
    $environment["${environmentPrefix}_FREEZE"] = $FreezePath
    $environment["${environmentPrefix}_ATTEMPT"] = $AttemptPath
    $environment["${environmentPrefix}_TOKEN"] = $Token
    $environment["${environmentPrefix}_STAGE"] = $stageId
    $environment["${environmentPrefix}_CELL"] = $cellId
    $environment["${environmentPrefix}_ENGINE"] = "rapier_parry"
    $environment["${environmentPrefix}_ATTEMPT_ROOT"] = $AttemptRoot
    $environment["${environmentPrefix}_AUTHORITY_REPO_ROOT"] = $repoRoot
    $environment["${environmentPrefix}_PYTHON"] = $PythonHost
    $environment["${environmentPrefix}_POWERSHELL"] = $PowerShellHost
    $result = Invoke-R23D27Process `
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
    Write-R23D27Json $processPath ([ordered]@{
        schema_version = "sporespore_qsdk_${variantLower}_process_receipt_v1"
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
    Assert-R23D27 (-not [bool]$result.timed_out) (
        "cell timed out after retained process output: $Arm"
    )
    $terminal = Get-R23D27Marker `
        -Text ([string]$result.stdout) -Prefix "${markerStem}_RAPIER_TERMINAL "
    $terminalPath = Join-Path $CellRoot "terminal.json"
    Write-R23D27Json $terminalPath $terminal
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

Assert-R23D27 (
    @($PreflightOnly, $RunPhysical | Where-Object { $_ }).Count -eq 1
) "specify exactly one of -PreflightOnly or -RunPhysical"
Assert-R23D27 (
    (Invoke-R23D27Git @("rev-parse", "--show-toplevel")).Replace("/", "\") -ceq
        $repoRoot -and
    (Invoke-R23D27Git @("remote", "get-url", "origin")) -ceq
        "https://github.com/Slagathore/sporespore.git"
) "repository identity changed"
foreach ($path in @(
    $preregistrationPath, $implementationPath, $evaluatorPath,
    $artifactStorePath, $operationLockPath, $runtimeRecipePath,
    $attestationVerifierPath, $rapierManifest
)) { Assert-R23D27 (Test-Path -LiteralPath $path -PathType Leaf) "missing input: $path" }
if ($RunPhysical -and (Test-Path -LiteralPath $closurePath -PathType Leaf)) {
    Write-Host (
        "${markerStem}_PHYSICAL_REFUSAL " +
        (@{
            schema_version = "sporespore_qsdk_${variantLower}_physical_refusal_v1"
            campaign_id = $campaignId
            gate_id = $gateId
            reason = "${variantLower}_identity_closed"
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
$resolvedPython = Resolve-R23D27Application $Python
$resolvedPowerShell = Resolve-R23D27Application $PowerShell
$buildResult = Invoke-R23D27Process `
    -FileName "cargo" `
    -Arguments @(
        "build", "--quiet", "--locked", "--manifest-path", $rapierManifest,
        "--bin", $workerBinaryName
    ) `
    -WorkingDirectory $sdkRoot -Environment @{} -TimeoutSeconds 300
Assert-R23D27 (
    -not [bool]$buildResult.timed_out -and [int]$buildResult.exit_code -eq 0 -and
    (Test-Path -LiteralPath $debugWorker -PathType Leaf)
) "development worker build failed: $($buildResult.stderr)"
$zeroWorld = Invoke-R23D27ZeroWorld -Worker $debugWorker -PythonHost $resolvedPython
if ($PreflightOnly) {
    Write-Host (
        "${markerStem}_ZERO_WORLD_PASS workers=$($cellIds.Count) " +
        "mutations=$([int]$zeroWorld.total_mutation_control_count) " +
        "models=0 worlds=0 " +
        "physical=False"
    )
    return
}
Assert-R23D27 (-not [string]::IsNullOrWhiteSpace(
    $CampaignAttestationAdoption
)) "physical execution requires the campaign-attestation adoption receipt"

$sourceCommit = Invoke-R23D27Git @("rev-parse", "HEAD")
$originCommit = Invoke-R23D27Git @("rev-parse", "origin/main")
$liveCommit = ((Invoke-R23D27Git @(
    "ls-remote", "origin", "refs/heads/main"
)) -split "\s+")[0]
Assert-R23D27 (
    [string](Invoke-R23D27Git @(
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
Assert-R23D27 ([bool]$attestation.ok) (
    "campaign-attestation adoption invalid: " +
    (@($attestation.failure_codes) -join ",")
)

$evidenceRoot = Get-SporeSporeArtifactEvidenceRoot -RepoRoot $repoRoot
$prior = @()
if (Test-Path -LiteralPath $evidenceRoot -PathType Container) {
    $prior = @(Get-ChildItem -LiteralPath $evidenceRoot -Directory |
        Where-Object {
            $_.Name -like "${identitySlug}-*" -and
            (Test-Path -LiteralPath (Join-Path $_.FullName "attempt.json"))
        })
}
Assert-R23D27 ($prior.Count -eq 0) "one-shot identity was already consumed"
$resolvedOutput = if ([string]::IsNullOrWhiteSpace($OutputRoot)) {
    Join-Path $evidenceRoot (
        "${identitySlug}-" + [DateTime]::UtcNow.ToString("yyyyMMddTHHmmssZ")
    )
} else { [IO.Path]::GetFullPath($OutputRoot) }
Assert-R23D27 (
    $resolvedOutput.StartsWith(
        $evidenceRoot.TrimEnd("\", "/") + "\",
        [StringComparison]::OrdinalIgnoreCase
    ) -and -not (Test-Path -LiteralPath $resolvedOutput)
) "output must be a new directory within the durable evidence root"

$lock = Enter-SporeSporeLocomotionOperationLock -Role physical
Assert-R23D27 ([bool]$lock.acquired) "global locomotion operation lock is held"
$attemptConsumed = $false
[void][IO.Directory]::CreateDirectory($resolvedOutput)
try {
    . $runtimeRecipePath
    $sourceMaterialization = New-R23D27GitBlobSourceMaterialization `
        -SourceCommit $sourceCommit -OutputRoot $resolvedOutput
    $materializedSdkRoot = Join-Path $sourceMaterialization.source_root "sdk"
    $materializedRapierManifest = Join-Path $materializedSdkRoot (
        "adapters\rapier\Cargo.toml"
    )
    $runtimeTarget = Join-Path $sdkRoot (
        "target\${identitySlug}-runtime-$sourceCommit"
    )
    $build = Invoke-SporeSporeR23D3PinnedCargo `
        -RepoRoot ([string]$sourceMaterialization.source_root) `
        -SourceAuthorityRepoRoot $repoRoot `
        -SourceCommit $sourceCommit `
        -TargetRoot $runtimeTarget `
        -CargoArguments @(
            "build", "--quiet", "--release", "--locked", "--offline",
            "--manifest-path", $materializedRapierManifest,
            "--bin", $workerBinaryName
        )
    $runtime = Join-Path $runtimeTarget ("release\{0}.exe" -f $workerBinaryName)
    Assert-R23D27 (Test-Path -LiteralPath $runtime -PathType Leaf) (
        "reproducible runtime materialization did not produce the Rapier worker"
    )
    $bindings = @(Get-R23D27SourceBindings `
        $implementation ([string]$sourceMaterialization.source_root))
    $inputs = Publish-R23D27Inputs `
        -Bindings $bindings `
        -Worker $runtime `
        -MaterializedRoot ([string]$sourceMaterialization.source_root) `
        -SourceArchive ([string]$sourceMaterialization.archive_path) `
        -PythonHost $resolvedPython `
        -PowerShellHost $resolvedPowerShell `
        -AdoptionPath ([IO.Path]::GetFullPath($CampaignAttestationAdoption))
    $productionRetentionPreflight = $null
    if ($hardenedEvidenceRoute) {
        $materializedEvaluatorPath = Join-Path (
            [string]$sourceMaterialization.source_root
        ) ("sdk\turning\" + (Split-Path -Leaf $evaluatorPath))
        $materializedTurningRoot = Join-Path (
            [string]$sourceMaterialization.source_root
        ) "sdk\turning"
        $productionCanaryRoot = Join-Path $resolvedOutput "pre-world-retention-canary"
        $productionCanary = if ($implementationRepairReplay) {
            Invoke-R23D27Process `
                -FileName $runtime `
                -Arguments @(
                    "retention-preflight",
                    "--stage", $stageId,
                    "--candidate", $candidateOrder[0],
                    "--arm", $armOrder[0],
                    "--source-root", [string]$sourceMaterialization.source_root,
                    "--repo-root", $repoRoot,
                    "--attempt-root", $productionCanaryRoot,
                    "--python", $resolvedPython,
                    "--powershell", $resolvedPowerShell
                ) `
                -WorkingDirectory ([string]$sourceMaterialization.source_root) `
                -Environment @{} `
                -TimeoutSeconds 240
        } else {
            Invoke-R23D27Process `
                -FileName $resolvedPython `
                -Arguments @(
                    $materializedEvaluatorPath,
                    "production-retention-preflight",
                    "--source-root", [string]$sourceMaterialization.source_root,
                    "--repo-root", $repoRoot,
                    "--attempt-root", $productionCanaryRoot,
                    "--powershell", $resolvedPowerShell
                ) `
                -WorkingDirectory ([string]$sourceMaterialization.source_root) `
                -Environment @{ PYTHONPATH = $materializedTurningRoot } `
                -TimeoutSeconds 240
        }
        Assert-R23D27 (
            -not [bool]$productionCanary.timed_out -and
            [int]$productionCanary.exit_code -eq 0
        ) (
            "production retention preflight failed: stdout=$($productionCanary.stdout) " +
            "stderr=$($productionCanary.stderr)"
        )
        $productionRetentionPreflight = Get-R23D27Marker `
            -Text ([string]$productionCanary.stdout) `
            -Prefix "${markerStem}_PRODUCTION_RETENTION_PREFLIGHT "
        Assert-R23D27 (
            [string]$productionRetentionPreflight.campaign_id -ceq $campaignId -and
            [string]$productionRetentionPreflight.gate_id -ceq $gateId -and
            [bool]$productionRetentionPreflight.exact_production_cas_path_exercised -and
            (-not $implementationRepairReplay -or (
                [bool]$productionRetentionPreflight.exact_rust_to_python_to_powershell_to_artifact_store_route_exercised -and
                [bool]$productionRetentionPreflight.process_scoped_execution_policy_bypass_exercised -and
                [bool]$productionRetentionPreflight.rust_worker_outer_route_validated
            )) -and
            [int]$productionRetentionPreflight.synthetic_trace_row_count -eq
                $(if ($pairedStartupTransform) { 5984 } else { 2992 }) -and
            $(if ($pairedStartupTransform) {
                [int]$productionRetentionPreflight.synthetic_trace_count -eq 2 -and
                [bool]$productionRetentionPreflight.complete_cas_binding_verifier_exercised -and
                [int]$productionRetentionPreflight.ordinary_and_windows_extended_path_spelling_positive_control_count -eq 2 -and
                [int]$productionRetentionPreflight.wrong_existing_file_rejection_count -eq 1 -and
                @($productionRetentionPreflight.trace_retentions).Count -eq 2 -and
                @($productionRetentionPreflight.trace_retentions | Where-Object {
                    [bool]$_.trace_artifact.test_only
                }).Count -eq 0
            } elseif ($r50PathIdentityReplay) {
                [bool]$productionRetentionPreflight.complete_cas_binding_verifier_exercised -and
                [int]$productionRetentionPreflight.ordinary_and_windows_extended_path_spelling_positive_control_count -eq 1 -and
                [int]$productionRetentionPreflight.wrong_existing_file_rejection_count -eq 1 -and
                -not [bool]$productionRetentionPreflight.trace_retention.trace_artifact.test_only
            } else {
                -not [bool]$productionRetentionPreflight.trace_retention.trace_artifact.test_only
            }) -and
            [int]$productionRetentionPreflight.model_construction_count -eq 0 -and
            [int]$productionRetentionPreflight.world_attempt_count -eq 0 -and
            [int]$productionRetentionPreflight.world_build_count -eq 0
        ) "production retention preflight receipt invalid"
    }
    $freeze = [ordered]@{
        schema_version = "sporespore_qsdk_${variantLower}_physical_freeze_v1"
        status = "frozen_supervisor_only_physical_authorized"
        campaign_id = $campaignId
        gate_id = $gateId
        preregistration_raw_sha256 = Get-R23D27Sha256 $preregistrationPath
        implementation_contract_raw_sha256 = Get-R23D27Sha256 $implementationPath
        source_commit = $sourceCommit
        source_tree_git_oid = Invoke-R23D27Git @("rev-parse", "HEAD^{tree}")
        source_materialization = $sourceMaterialization
        source_bindings = $bindings
        runtime_artifact = [ordered]@{
            path = $runtime
            raw_sha256 = Get-R23D27Sha256 $runtime
            build = $build
        }
        content_addressed_inputs = $inputs
        zero_world_receipt = $zeroWorld
        production_retention_preflight = $productionRetentionPreflight
        campaign_attestation_adoption_raw_sha256 = [string]$attestation.sha256
        declared_matrix_world_count = $cellIds.Count
        ordered_matrix_cell_ids = $cellIds
        serial_execution_required = $true
        source_bytes_consumed_by_build_equal_git_blobs = $true
        ambient_checkout_is_not_build_authority = $true
        physical_execution_authorized = $true
        physical_acceptance_authority = $false
    }
    $freezePath = Join-Path $resolvedOutput "physical-freeze.json"
    Write-R23D27Json $freezePath $freeze
    $freezeCas = Publish-SporeSporeContentAddressedArtifact `
        -RepoRoot $repoRoot -ArtifactPath $freezePath -MediaType "application/json"
    $attemptId = [guid]::NewGuid().ToString("N")
    $token = [guid]::NewGuid().ToString("N")
    $attempt = [ordered]@{
        schema_version = "sporespore_qsdk_${variantLower}_attempt_v1"
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
        production_retention_preflight_passed = (
            -not $hardenedEvidenceRoute -or
            $null -ne $productionRetentionPreflight
        )
        one_shot_attempt_unconsumed = $true
        physical_execution_authorized = $true
        physical_acceptance_authority = $false
    }
    $attemptPath = Join-Path $resolvedOutput "attempt.json"
    Write-R23D27Json $attemptPath $attempt
    $attemptCas = Publish-SporeSporeContentAddressedArtifact `
        -RepoRoot $repoRoot -ArtifactPath $attemptPath -MediaType "application/json"
    $attemptConsumed = $true
    $authorizationReceipts = [Collections.Generic.List[object]]::new()
    foreach ($candidate in $candidateOrder) {
        foreach ($arm in $armOrder) {
            $cellId = "rapier_parry__{0}__{1}" -f $candidate, $arm
            $environmentPrefix = "SPORESPORE_QSDK_" + $CampaignVariant
            $authorizationEnvironment = @{}
            $authorizationEnvironment["${environmentPrefix}_FREEZE"] = (
                [string]$freezeCas.payload_path
            )
            $authorizationEnvironment["${environmentPrefix}_ATTEMPT"] = (
                [string]$attemptCas.payload_path
            )
            $authorizationEnvironment["${environmentPrefix}_TOKEN"] = $token
            $authorizationEnvironment["${environmentPrefix}_STAGE"] = $stageId
            $authorizationEnvironment["${environmentPrefix}_CELL"] = $cellId
            $authorizationEnvironment["${environmentPrefix}_ENGINE"] = "rapier_parry"
            $authorizationEnvironment["${environmentPrefix}_ATTEMPT_ROOT"] = (
                $resolvedOutput
            )
            $authorizationEnvironment["${environmentPrefix}_AUTHORITY_REPO_ROOT"] = (
                $repoRoot
            )
            $authorizationEnvironment["${environmentPrefix}_PYTHON"] = $resolvedPython
            $authorizationEnvironment["${environmentPrefix}_POWERSHELL"] = (
                $resolvedPowerShell
            )
            $authorizationProcess = Invoke-R23D27Process `
                -FileName $runtime `
                -Arguments @(
                    "authorization-preflight", "--stage", $stageId,
                    "--candidate", $candidate, "--arm", $arm,
                    "--source-commit", $sourceCommit
                ) `
                -WorkingDirectory $repoRoot `
                -Environment $authorizationEnvironment `
                -TimeoutSeconds 120
            Assert-R23D27 (
                -not [bool]$authorizationProcess.timed_out -and
                [int]$authorizationProcess.exit_code -eq 0
            ) (
                "positive production authorization preflight failed: " +
                "cell=$cellId stdout=$($authorizationProcess.stdout) " +
                "stderr=$($authorizationProcess.stderr)"
            )
            $authorizationReceipt = Get-R23D27Marker `
                -Text ([string]$authorizationProcess.stdout) `
                -Prefix "${markerStem}_RAPIER_AUTHORIZATION_PREFLIGHT "
            Assert-R23D27 (
                [string]$authorizationReceipt.campaign_id -ceq $campaignId -and
                [string]$authorizationReceipt.gate_id -ceq $gateId -and
                [string]$authorizationReceipt.cell_id -ceq $cellId -and
                [bool]$authorizationReceipt.authorization_passed -and
                [bool]$authorizationReceipt.returned_before_model -and
                [int]$authorizationReceipt.model_construction_count -eq 0 -and
                [int]$authorizationReceipt.physical_process_launch_count -eq 0 -and
                [int]$authorizationReceipt.world_attempt_count -eq 0 -and
                [int]$authorizationReceipt.world_build_count -eq 0
            ) "positive production authorization receipt invalid: $cellId"
            $authorizationReceipts.Add($authorizationReceipt)
        }
    }
    $authorizationPath = Join-Path $resolvedOutput "authorization-preflights.json"
    Write-R23D27Json $authorizationPath @($authorizationReceipts)
    $authorizationCas = Publish-SporeSporeContentAddressedArtifact `
        -RepoRoot $repoRoot -ArtifactPath $authorizationPath `
        -MediaType "application/json"
    $cells = [Collections.Generic.List[object]]::new()
    foreach ($candidate in $candidateOrder) {
        foreach ($arm in $armOrder) {
            $cellId = "rapier_parry__{0}__{1}" -f $candidate, $arm
            $cells.Add((Invoke-R23D27Cell `
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
    Write-R23D27Json $manifestPath $terminalPaths
    $manifestCas = Publish-SporeSporeContentAddressedArtifact `
        -RepoRoot $repoRoot -ArtifactPath $manifestPath -MediaType "application/json"
    $completeEvaluatorPath = if ($hardenedEvidenceRoute) {
        $materializedEvaluatorPath
    } else { $evaluatorPath }
    $completeEvaluatorPythonPath = if ($hardenedEvidenceRoute) {
        $materializedTurningRoot
    } else { $turningRoot }
    $evaluationArguments = @(
        $completeEvaluatorPath, "evaluate-complete", "--manifest",
        [string]$manifestCas.payload_path, "--source-commit", $sourceCommit
    )
    if ($hardenedEvidenceRoute) {
        $evaluationArguments += @("--repo-root", $repoRoot)
    }
    $evaluationProcess = Invoke-R23D27Process `
        -FileName $resolvedPython `
        -Arguments $evaluationArguments `
        -WorkingDirectory $repoRoot `
        -Environment @{ PYTHONPATH = $completeEvaluatorPythonPath } `
        -TimeoutSeconds 180
    Assert-R23D27 (
        -not [bool]$evaluationProcess.timed_out -and
        [int]$evaluationProcess.exit_code -eq 0
    ) "complete evaluator failed: $($evaluationProcess.stderr)"
    $evaluation = Get-R23D27Marker `
        -Text ([string]$evaluationProcess.stdout) `
        -Prefix "${markerStem}_COMPLETE_EVALUATION "
    $classification = [string]$evaluation.classification
    $positiveTurningClassification = if ($r50PathIdentityReplay) {
        "valid_complete_positive_outcome_exposed_rapier_cas_path_identity_replay"
    } elseif ($r49RetentionRepairReplay) {
        "valid_complete_positive_outcome_exposed_rapier_retention_repair_replay"
    } elseif ($retentionHardenedReplication) {
        "valid_complete_positive_finite_rapier_turning_replication"
    } else { "valid_complete_positive_finite_rapier_turning_validation" }
    $report = [ordered]@{
        schema_version = "sporespore_qsdk_${variantLower}_campaign_report_v1"
        campaign_id = $campaignId
        gate_id = $gateId
        source_commit = $sourceCommit
        attempt_id = $attemptId
        freeze_cas = $freezeCas
        attempt_cas = $attemptCas
        manifest_cas = $manifestCas
        production_authorization_preflights_cas = $authorizationCas
        production_authorization_preflight_count = $authorizationReceipts.Count
        ordered_matrix_cells = @($cells)
        complete_evaluation = $evaluation
        result_classification = $classification
        claims = [ordered]@{
            finite_rapier_development_candidate = (
                -not $measurementValidation -and -not $turningReplication -and
                -not $pairedStartupTransform -and
                $classification.StartsWith("valid_complete_positive", [StringComparison]::Ordinal)
            )
            finite_rapier_cycle_coherent_measurement_validation = (
                $cycleCoherent -and
                $classification -ceq "valid_complete_positive_measurement_validation_candidate"
            )
            finite_rapier_cycle_integrated_measurement_validation = (
                ($cycleIntegrated -and
                $classification -ceq "valid_complete_positive_measurement_validation_candidate") -or
                ($turningReplication -and -not $retentionHardenedReplication -and
                -not $implementationRepairReplay -and
                $classification -ceq $positiveTurningClassification)
            )
            selected_candidate_is_validation = (
                $turningReplication -and -not $implementationRepairReplay -and
                $classification -ceq $positiveTurningClassification
            )
            selected_measurement_is_validation = (
                $measurementValidation -and
                $classification -ceq "valid_complete_positive_measurement_validation_candidate"
            )
            finite_rapier_turning_replication = (
                $retentionHardenedReplication -and
                $classification -ceq $positiveTurningClassification
            )
            finite_outcome_exposed_rapier_retention_repair_replay = (
                $r49RetentionRepairReplay -and
                $classification -ceq $positiveTurningClassification
            )
            finite_outcome_exposed_rapier_cas_path_identity_replay = (
                $r50PathIdentityReplay -and
                $classification -ceq $positiveTurningClassification
            )
            finite_rapier_turning_validation = (
                $turningReplication -and -not $retentionHardenedReplication -and
                -not $implementationRepairReplay -and
                $classification -ceq $positiveTurningClassification
            )
            paired_same_seed_startup_transform_effect_characterized = (
                $pairedStartupTransform -and
                $classification.StartsWith("valid_complete_", [StringComparison]::Ordinal)
            )
            finite_three_engine_turning_candidate = $false
            cross_engine_equivalence = $false
            release_authorized = $false
            physical_acceptance_authority = $false
        }
    }
    $reportPath = Join-Path $resolvedOutput "report.json"
    Write-R23D27Json $reportPath $report
    $reportCas = Publish-SporeSporeContentAddressedArtifact `
        -RepoRoot $repoRoot -ArtifactPath $reportPath -MediaType "application/json"
    $completionPath = Join-Path $resolvedOutput "completion.json"
    $completion = [ordered]@{
        schema_version = "sporespore_qsdk_${variantLower}_completion_v1"
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
    Write-R23D27Json $completionPath $completion
    $completionCas = Publish-SporeSporeContentAddressedArtifact `
        -RepoRoot $repoRoot -ArtifactPath $completionPath -MediaType "application/json"
    Write-Host (
        "${markerStem}_PHYSICAL_COMPLETE classification=$classification cells=$($cells.Count) " +
        "report_sha256=$([string]$reportCas.sha256) " +
        "completion_sha256=$([string]$completionCas.sha256) " +
        "three_engine=False equivalence=False release=False"
    )
} catch {
    if ($attemptConsumed -and -not (Test-Path -LiteralPath (
        Join-Path $resolvedOutput "completion.json"
    ))) {
        $emergency = [ordered]@{
            schema_version = "sporespore_qsdk_${variantLower}_completion_v1"
            campaign_id = $campaignId
            gate_id = $gateId
            status = "invalid_or_incomplete_first_attempt"
            source_commit = $sourceCommit
            one_shot_identity_consumed = $true
            same_identity_rerun_allowed = $false
            failure = $_.Exception.Message
            physical_acceptance_authority = $false
        }
        Write-R23D27Json (Join-Path $resolvedOutput "completion.json") $emergency
    }
    throw
} finally {
    Exit-SporeSporeLocomotionOperationLock -Receipt $lock
}
