#requires -Version 7.0

[CmdletBinding()]
param(
    [string]$InventoryPathOverride = "",
    [string[]]$IncludePath = @(),
    [string]$EvidenceRootOverride = "",
    [string]$ResumeRunId = "",
    [ValidateRange(30, 1800)][int]$HardSafetyTimeoutSeconds = 900,
    [ValidateRange(0, 95)][int]$StopAfterPublishedReceiptCount = 0,
    [switch]$Commissioning,
    [switch]$TestOnly
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$sdkRoot = [IO.Path]::GetFullPath($PSScriptRoot)
$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $sdkRoot))
$contractPath = Join-Path $sdkRoot "conformance_audit_profiler_contract_v2.json"
$productionInventoryPath = Join-Path $sdkRoot "closure_evidence_mode_inventory.json"
$artifactStorePath = Join-Path $sdkRoot "content_addressed_artifact_store.ps1"
$dependencyKeyPath = Join-Path $sdkRoot "conformance_dependency_key.ps1"
$scriptPath = $PSCommandPath

foreach ($path in @(
    $contractPath, $productionInventoryPath, $artifactStorePath,
    $dependencyKeyPath
)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "CAP2 input is missing: $path"
    }
}
. $artifactStorePath
. $dependencyKeyPath

function Assert-Cap2 {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw "CAP2 profiler refused: $Message" }
}

function Get-Cap2RawSha256 {
    param([Parameter(Mandatory)][string]$Path)
    return "sha256:" + (
        Get-FileHash -LiteralPath $Path -Algorithm SHA256
    ).Hash.ToLowerInvariant()
}

function Invoke-Cap2Git {
    param([Parameter(Mandatory)][string[]]$Arguments)
    $output = @(& git -C $repoRoot @Arguments 2>&1)
    if ($LASTEXITCODE -ne 0) {
        throw "CAP2 Git probe failed: git $($Arguments -join ' '): $($output -join ' ')"
    }
    return ($output -join "`n").Trim()
}

function ConvertTo-Cap2CanonicalText {
    param([AllowEmptyString()][string]$Text = "")
    if ($null -eq $Text) { return "" }
    return $Text.Replace("`r`n", "`n").Replace("`r", "`n")
}

function Write-Cap2NewUtf8File {
    param(
        [Parameter(Mandatory)][string]$Path,
        [AllowEmptyString()][string]$Text = ""
    )
    [void][IO.Directory]::CreateDirectory((Split-Path -Parent $Path))
    $bytes = [Text.UTF8Encoding]::new($false).GetBytes($Text)
    $stream = [IO.File]::Open(
        $Path,
        [IO.FileMode]::CreateNew,
        [IO.FileAccess]::Write,
        [IO.FileShare]::None
    )
    try { $stream.Write($bytes, 0, $bytes.Length) }
    finally { $stream.Dispose() }
}

function Assert-Cap2CasArtifact {
    param(
        [Parameter(Mandatory)][string]$EvidenceRoot,
        [Parameter(Mandatory)][string]$Sha256,
        [Parameter(Mandatory)][long]$ByteLength,
        [Parameter(Mandatory)][string]$Label
    )
    Assert-Cap2 ($Sha256 -cmatch '^sha256:[0-9a-f]{64}$') (
        "$Label digest is invalid"
    )
    $hex = $Sha256.Substring(7)
    Assert-Cap2 (Test-SporeSporeStoredArtifact `
        -Directory (Join-Path $EvidenceRoot "artifacts\sha256\$hex") `
        -ExpectedSha256 $hex `
        -ExpectedByteLength $ByteLength) "$Label CAS verification failed"
}

$contract = Get-Content -LiteralPath $contractPath -Raw |
    ConvertFrom-Json -AsHashtable -Depth 32
Assert-Cap2 (
    [string]$contract.schema_version -ceq
        "sporespore_conformance_audit_profiler_contract_v2" -and
    [string]$contract.status -ceq
        "prospective_crash_resilient_development_profiler_uncommissioned" -and
    [bool]$contract.incremental_retention.per_audit_receipt_create_only -and
    [bool]$contract.resume.verified_receipts_are_not_reexecuted -and
    -not [bool]$contract.claims.crash_resilient_resume_commissioned -and
    -not [bool]$contract.claims.production_cache_lookup_permitted -and
    -not [bool]$contract.claims.production_result_reuse_permitted -and
    -not [bool]$contract.claims.physical_execution_authorized -and
    -not [bool]$contract.claims.scientific_authority -and
    -not [bool]$contract.claims.release_authority
) "contract identity or authority changed"

Assert-Cap2 (-not ($Commissioning -and $TestOnly)) (
    "commissioning and test-only identities are mutually exclusive"
)
if (-not $TestOnly) {
    Assert-Cap2 ([string]::IsNullOrWhiteSpace($InventoryPathOverride)) (
        "production inventory override is forbidden"
    )
    Assert-Cap2 (@($IncludePath).Count -eq 0) (
        "production subset override is forbidden"
    )
    Assert-Cap2 (
        $HardSafetyTimeoutSeconds -eq
            [int]$contract.execution.hard_safety_timeout_seconds
    ) "production hard-safety timeout changed"
    Assert-Cap2 (
        $StopAfterPublishedReceiptCount -eq 0 -or
        ($Commissioning -and
            $StopAfterPublishedReceiptCount -eq
                [int]$contract.commissioning.controlled_stop_after_published_receipt_count)
    ) "controlled stop is allowed only at the declared commissioning boundary"
} else {
    Assert-Cap2 (-not $Commissioning) "test-only run cannot claim commissioning"
}

$inventoryPath = if ([string]::IsNullOrWhiteSpace($InventoryPathOverride)) {
    $productionInventoryPath
} else {
    Assert-Cap2 ([bool]$TestOnly) "inventory override is test-only"
    [IO.Path]::GetFullPath($InventoryPathOverride)
}
Assert-Cap2 (Test-Path -LiteralPath $inventoryPath -PathType Leaf) (
    "inventory is missing: $inventoryPath"
)
$inventory = Get-Content -LiteralPath $inventoryPath -Raw |
    ConvertFrom-Json -AsHashtable -Depth 32
Assert-Cap2 (
    [string]$inventory.schema_version -ceq
        "sporespore_closure_evidence_mode_inventory_v1" -and
    [int]$inventory.audit_count -eq @($inventory.entries).Count -and
    [int]$inventory.world_build_count -eq 0 -and
    -not [bool]$inventory.physical_execution_authorized -and
    -not [bool]$inventory.physical_acceptance_authority
) "CEP1 inventory identity or zero-world boundary changed"
if (-not $TestOnly) {
    Assert-Cap2 (
        [int]$inventory.audit_count -eq
            [int]$contract.production_inventory.expected_audit_count
    ) "production CEP1 audit count changed"
}

$entryByPath = [Collections.Generic.Dictionary[string, object]]::new(
    [StringComparer]::Ordinal
)
foreach ($entry in @($inventory.entries)) {
    $path = [string]$entry.path
    Assert-Cap2 (
        -not [string]::IsNullOrWhiteSpace($path) -and
        -not [IO.Path]::IsPathRooted($path) -and
        -not $path.Contains("..", [StringComparison]::Ordinal) -and
        $entryByPath.TryAdd($path, $entry)
    ) "inventory contains an invalid or duplicate audit path"
}

$requestedPaths = if ($Commissioning) {
    [string[]]@($contract.commissioning.selected_audits)
} elseif (@($IncludePath).Count -gt 0) {
    Assert-Cap2 ([bool]$TestOnly) "audit subset override is test-only"
    [string[]]@($IncludePath)
} else {
    [string[]]@($inventory.entries | ForEach-Object { [string]$_.path })
}
$selectedEntriesList = [Collections.Generic.List[object]]::new()
$selectedPathSet = [Collections.Generic.HashSet[string]]::new(
    [StringComparer]::Ordinal
)
foreach ($selectedPath in $requestedPaths) {
    Assert-Cap2 ($selectedPathSet.Add($selectedPath)) (
        "selected audit path is duplicated: $selectedPath"
    )
    $entry = $null
    Assert-Cap2 ($entryByPath.TryGetValue($selectedPath, [ref]$entry)) (
        "selected audit is not in CEP1: $selectedPath"
    )
    $selectedEntriesList.Add($entry)
}
$selectedEntries = [object[]]$selectedEntriesList.ToArray()
Assert-Cap2 ($selectedEntries.Count -gt 0) "selected audit set is empty"

foreach ($entry in $selectedEntries) {
    $auditPath = [string]$entry.path
    $auditAbsolute = Join-Path $repoRoot $auditPath
    Assert-Cap2 (Test-Path -LiteralPath $auditAbsolute -PathType Leaf) (
        "audit source is missing: $auditPath"
    )
    $actualHash = (Get-FileHash -LiteralPath $auditAbsolute -Algorithm SHA256).
        Hash.ToLowerInvariant()
    Assert-Cap2 ($actualHash -ceq [string]$entry.raw_sha256) (
        "audit source hash differs from CEP1: $auditPath"
    )
}

$status = Invoke-Cap2Git @("status", "--short")
$head = Invoke-Cap2Git @("rev-parse", "HEAD")
$headTree = Invoke-Cap2Git @("rev-parse", "HEAD^{tree}")
$originMain = Invoke-Cap2Git @("rev-parse", "origin/main")
$remoteUrl = Invoke-Cap2Git @("remote", "get-url", "origin")
$sourceEligible = [string]::IsNullOrWhiteSpace($status) -and
    $head -ceq $originMain
$liveMain = $null
$liveRemoteVerified = $false
if (-not $TestOnly) {
    Assert-Cap2 (
        $remoteUrl -ceq [string]$contract.production_inventory.expected_remote_url
    ) "production profiler remote URL differs from the contract"
    $liveLine = Invoke-Cap2Git @("ls-remote", "origin", "refs/heads/main")
    Assert-Cap2 (
        $liveLine -cmatch '^[0-9a-f]{40}\s+refs/heads/main$'
    ) "live origin/main probe did not return exactly one branch"
    $liveMain = ($liveLine -split '\s+')[0]
    $liveRemoteVerified = $liveMain -ceq $head
    Assert-Cap2 ($sourceEligible -and $liveRemoteVerified) (
        "production or commissioning profiling requires clean source equal " +
        "to local and live origin/main"
    )
}

$productionEvidenceRoot = Get-SporeSporeArtifactEvidenceRoot -RepoRoot $repoRoot
$evidenceRoot = if ([string]::IsNullOrWhiteSpace($EvidenceRootOverride)) {
    $productionEvidenceRoot
} else { [IO.Path]::GetFullPath($EvidenceRootOverride).TrimEnd('\', '/') }
if (-not $TestOnly) {
    Assert-Cap2 ($evidenceRoot -ceq $productionEvidenceRoot) (
        "production profiler must use the durable evidence root"
    )
}
[void][IO.Directory]::CreateDirectory($evidenceRoot)

$pwsh = (Get-Command pwsh -CommandType Application -ErrorAction Stop |
    Select-Object -First 1).Source
$processEnvironment = Get-SporeSporeProcessEnvironmentInventory
$selectedProjection = @($selectedEntries | ForEach-Object {
    [ordered]@{
        path = [string]$_.path
        raw_sha256 = [string]$_.raw_sha256
        historical_identity_mode = [string]$_.historical_identity_mode
        manual_review_required = [bool]$_.manual_review_required
    }
})
$mode = if ($Commissioning) {
    "commissioning_two_audit_recovery"
} elseif ($TestOnly -and @($IncludePath).Count -gt 0) {
    "test_only_subset"
} elseif ($TestOnly) {
    "test_only_full_inventory"
} else { "production_full_inventory" }
$inputProjection = [ordered]@{
    schema_version = "sporespore_conformance_audit_profiler_input_v2"
    source = [ordered]@{
        head = $head
        head_tree = $headTree
        origin_main = $originMain
        remote_url = $remoteUrl
        live_main = $liveMain
        status_sha256 = Get-SporeSporeDependencyStringSha256 $status
        clean_equal_origin_main = $sourceEligible
        live_remote_main_equal_head = $liveRemoteVerified
    }
    implementation = [ordered]@{
        contract_sha256 = Get-Cap2RawSha256 $contractPath
        profiler_sha256 = Get-Cap2RawSha256 $scriptPath
        artifact_store_sha256 = Get-Cap2RawSha256 $artifactStorePath
        dependency_key_sha256 = Get-Cap2RawSha256 $dependencyKeyPath
        pwsh_executable_sha256 = Get-Cap2RawSha256 $pwsh
    }
    inventory_sha256 = Get-Cap2RawSha256 $inventoryPath
    selected_audits_sha256 = Get-SporeSporeDependencyObjectSha256 (
        [ordered]@{
            schema_version = "sporespore_cap2_selected_audits_v1"
            entries = $selectedProjection
        }
    )
    selected_audits = $selectedProjection
    selected_audit_count = $selectedEntries.Count
    production_inventory_count = [int]$inventory.audit_count
    complete_process_environment_sha256 =
        [string]$processEnvironment.inventory_sha256
    complete_process_environment_name_count =
        [int]$processEnvironment.variable_count
    hard_safety_timeout_seconds = $HardSafetyTimeoutSeconds
    timeout_is_proven_hang = $false
    mode = $mode
    test_only = [bool]$TestOnly
    commissioning = [bool]$Commissioning
    serialized = $true
    world_build_count = 0
}
$inputKey = Get-SporeSporeDependencyObjectSha256 $inputProjection

if (-not [string]::IsNullOrWhiteSpace($ResumeRunId)) {
    Assert-Cap2 (
        $ResumeRunId -cmatch
            '^[0-9]{8}T[0-9]{6}Z-[0-9a-f]{8}-[0-9a-f]{32}$'
    ) "resume run id is malformed"
    $runId = $ResumeRunId
} else {
    $runId = (
        [DateTime]::UtcNow.ToString("yyyyMMddTHHmmssZ") + "-" +
        $head.Substring(0, 8) + "-" + [guid]::NewGuid().ToString("N")
    )
}
$profileFamilyRoot = Join-Path $evidenceRoot "conformance-audit-profiles-v2"
$runRoot = Join-Path $profileFamilyRoot $runId
$isResume = -not [string]::IsNullOrWhiteSpace($ResumeRunId)
if ($isResume) {
    Assert-Cap2 (Test-Path -LiteralPath $runRoot -PathType Container) (
        "resume run does not exist: $runId"
    )
} else {
    Assert-Cap2 (-not (Test-Path -LiteralPath $runRoot)) (
        "new run identity already exists"
    )
    [void][IO.Directory]::CreateDirectory($runRoot)
}

$lockPath = Join-Path $runRoot ".cap2.lock"
try {
    $runLease = [IO.File]::Open(
        $lockPath,
        [IO.FileMode]::OpenOrCreate,
        [IO.FileAccess]::ReadWrite,
        [IO.FileShare]::None
    )
} catch {
    throw "CAP2 profiler refused: exclusive run lease unavailable for $runId"
}

try {
    $manifestPath = Join-Path $runRoot "run_manifest.json"
    $profilePath = Join-Path $runRoot "profile.json"
    if ($isResume) {
        Assert-Cap2 (-not (Test-Path -LiteralPath $profilePath)) (
            "completed run cannot be resumed"
        )
        Assert-Cap2 (Test-Path -LiteralPath $manifestPath -PathType Leaf) (
            "resume manifest is missing"
        )
        $manifestSha = Get-Cap2RawSha256 $manifestPath
        $manifestBytes = (Get-Item -LiteralPath $manifestPath).Length
        Assert-Cap2CasArtifact -EvidenceRoot $evidenceRoot `
            -Sha256 $manifestSha -ByteLength $manifestBytes `
            -Label "run manifest"
        $manifest = Get-Content -LiteralPath $manifestPath -Raw |
            ConvertFrom-Json -AsHashtable -Depth 64
        $manifestInputKey = Get-SporeSporeDependencyObjectSha256 $manifest.input
        Assert-Cap2 (
            [string]$manifest.schema_version -ceq
                "sporespore_conformance_audit_run_manifest_v2" -and
            [string]$manifest.status -ceq "immutable_incomplete_run_manifest" -and
            [string]$manifest.run_id -ceq $runId -and
            [string]$manifest.input_key_sha256 -ceq $manifestInputKey -and
            -not [bool]$manifest.production_cache_lookup_permitted -and
            -not [bool]$manifest.production_result_reuse_permitted -and
            -not [bool]$manifest.physical_authority -and
            -not [bool]$manifest.scientific_authority -and
            -not [bool]$manifest.release_authority
        ) "manifest identity or authority differs from the run"
        if ([string]$manifest.input_key_sha256 -cne $inputKey) {
            $driftFields = [Collections.Generic.List[string]]::new()
            foreach ($field in @(
                "head", "head_tree", "origin_main", "remote_url", "live_main",
                "status_sha256", "clean_equal_origin_main",
                "live_remote_main_equal_head"
            )) {
                if ([string]$manifest.input.source[$field] -cne
                    [string]$inputProjection.source[$field]) {
                    $driftFields.Add("source.$field")
                }
            }
            foreach ($field in @(
                "contract_sha256", "profiler_sha256", "artifact_store_sha256",
                "dependency_key_sha256", "pwsh_executable_sha256"
            )) {
                if ([string]$manifest.input.implementation[$field] -cne
                    [string]$inputProjection.implementation[$field]) {
                    $driftFields.Add("implementation.$field")
                }
            }
            foreach ($field in @(
                "inventory_sha256", "selected_audits_sha256",
                "complete_process_environment_sha256",
                "complete_process_environment_name_count",
                "hard_safety_timeout_seconds", "mode", "test_only",
                "commissioning", "serialized", "world_build_count"
            )) {
                if ([string]$manifest.input[$field] -cne
                    [string]$inputProjection[$field]) {
                    $driftFields.Add($field)
                }
            }
            $driftText = if ($driftFields.Count -eq 0) {
                "unprojected_or_serialization_field"
            } else { $driftFields -join "," }
            throw (
                "CAP2 profiler refused: live input key differs from the run; " +
                "fields=$driftText manifest=$($manifest.input_key_sha256) " +
                "live=$inputKey"
            )
        }
        Assert-Cap2 (
            [string]$manifest.input.mode -ceq $mode -and
            [int]$manifest.input.selected_audit_count -eq $selectedEntries.Count
        ) "live mode or selected count differs from the run"
        Write-Output (
            "CAP2_RUN_RESUME " + ([ordered]@{
                run_id = $runId
                input_key_sha256 = $inputKey
                manifest_sha256 = $manifestSha
            } | ConvertTo-Json -Compress)
        )
    } else {
        $manifest = [ordered]@{
            schema_version = "sporespore_conformance_audit_run_manifest_v2"
            status = "immutable_incomplete_run_manifest"
            run_id = $runId
            input_key_sha256 = $inputKey
            input = $inputProjection
            development_observation_only = $true
            production_cache_lookup_permitted = $false
            production_result_reuse_permitted = $false
            historical_audit_waiver_permitted = $false
            physical_authority = $false
            scientific_authority = $false
            release_authority = $false
        }
        $pendingManifestPath = Join-Path $runRoot (
            ".manifest-pending-" + [guid]::NewGuid().ToString("N") + ".json"
        )
        Write-Cap2NewUtf8File -Path $pendingManifestPath `
            -Text (($manifest | ConvertTo-Json -Depth 64) + "`n")
        $manifestArtifact = Publish-SporeSporeContentAddressedArtifact `
            -RepoRoot $repoRoot `
            -ArtifactPath $pendingManifestPath `
            -MediaType "application/json" `
            -EvidenceRootOverride $evidenceRoot `
            -TestOnly:$TestOnly
        Assert-Cap2 (-not (Test-Path -LiteralPath $manifestPath)) (
            "run manifest destination already exists"
        )
        [IO.File]::Move($pendingManifestPath, $manifestPath)
        $manifestSha = Get-Cap2RawSha256 $manifestPath
        $manifestBytes = (Get-Item -LiteralPath $manifestPath).Length
        Assert-Cap2 (
            $manifestSha -ceq [string]$manifestArtifact.sha256 -and
            $manifestBytes -eq [long]$manifestArtifact.byte_length
        ) "published run manifest changed during atomic publication"
        Write-Output (
            "CAP2_RUN_CREATED " + ([ordered]@{
                run_id = $runId
                input_key_sha256 = $inputKey
                manifest_sha256 = $manifestSha
            } | ConvertTo-Json -Compress)
        )
    }

    $receiptsRoot = Join-Path $runRoot "receipts"
    [void][IO.Directory]::CreateDirectory($receiptsRoot)
    $receiptChildren = @(Get-ChildItem -LiteralPath $receiptsRoot -Force)
    foreach ($child in $receiptChildren) {
        Assert-Cap2 (
            -not $child.PSIsContainer -and $child.Name -cmatch '^[0-9]{3}\.json$'
        ) "receipt directory contains an unexpected entry: $($child.Name)"
    }

    function Read-Cap2VerifiedReceipt {
        param(
            [Parameter(Mandatory)][int]$Ordinal,
            [Parameter(Mandatory)][string]$Path
        )
        $receiptSha = Get-Cap2RawSha256 $Path
        $receiptBytes = (Get-Item -LiteralPath $Path).Length
        Assert-Cap2CasArtifact -EvidenceRoot $evidenceRoot `
            -Sha256 $receiptSha -ByteLength $receiptBytes `
            -Label "receipt ordinal $Ordinal"
        $receipt = Get-Content -LiteralPath $Path -Raw |
            ConvertFrom-Json -AsHashtable -Depth 32
        $expectedEntry = $selectedEntries[$Ordinal - 1]
        $expectedPassed = -not [bool]$receipt.timed_out -and
            [int]$receipt.exit_code -eq 0
        Assert-Cap2 (
            [string]$receipt.schema_version -ceq
                "sporespore_conformance_audit_duration_receipt_v2" -and
            [string]$receipt.run_id -ceq $runId -and
            [string]$receipt.manifest_sha256 -ceq $manifestSha -and
            [string]$receipt.input_key_sha256 -ceq $inputKey -and
            [int]$receipt.ordinal -eq $Ordinal -and
            [int]$receipt.selected_audit_count -eq $selectedEntries.Count -and
            [string]$receipt.audit_path -ceq [string]$expectedEntry.path -and
            [string]$receipt.audit_raw_sha256 -ceq
                ("sha256:" + [string]$expectedEntry.raw_sha256) -and
            [double]$receipt.duration_seconds -gt 0 -and
            [bool]$receipt.passed -eq $expectedPassed -and
            (-not [bool]$receipt.timed_out -or [int]$receipt.exit_code -eq 124) -and
            -not [bool]$receipt.timeout_is_proven_hang -and
            -not [bool]$receipt.production_cache_lookup_permitted -and
            -not [bool]$receipt.production_result_reuse_permitted -and
            -not [bool]$receipt.physical_authority -and
            -not [bool]$receipt.scientific_authority -and
            -not [bool]$receipt.release_authority
        ) "receipt ordinal $Ordinal content or authority changed"
        Assert-Cap2CasArtifact -EvidenceRoot $evidenceRoot `
            -Sha256 ([string]$receipt.stdout_sha256) `
            -ByteLength ([long]$receipt.stdout_byte_length) `
            -Label "stdout ordinal $Ordinal"
        Assert-Cap2CasArtifact -EvidenceRoot $evidenceRoot `
            -Sha256 ([string]$receipt.stderr_sha256) `
            -ByteLength ([long]$receipt.stderr_byte_length) `
            -Label "stderr ordinal $Ordinal"
        return [ordered]@{
            receipt = $receipt
            receipt_sha256 = $receiptSha
            receipt_byte_length = $receiptBytes
        }
    }

    $receiptFileCount = $receiptChildren.Count
    Assert-Cap2 ($receiptFileCount -le $selectedEntries.Count) (
        "receipt count exceeds selected audit count"
    )
    $verifiedReceipts = [Collections.Generic.List[object]]::new()
    for ($ordinal = 1; $ordinal -le $receiptFileCount; $ordinal += 1) {
        $receiptPath = Join-Path $receiptsRoot ($ordinal.ToString("D3") + ".json")
        Assert-Cap2 (Test-Path -LiteralPath $receiptPath -PathType Leaf) (
            "receipt prefix is not contiguous at ordinal $ordinal"
        )
        $verifiedReceipts.Add((Read-Cap2VerifiedReceipt `
            -Ordinal $ordinal -Path $receiptPath))
    }
    $initialReceiptCount = $verifiedReceipts.Count
    if ($initialReceiptCount -gt 0) {
        Write-Output (
            "CAP2_RECEIPT_PREFIX_VERIFIED run=$runId receipts=" +
            "$initialReceiptCount next_ordinal=$($initialReceiptCount + 1)"
        )
    }

    $auditInvocationCount = 0
    $publishedThisProcess = 0
    for (
        $ordinal = $initialReceiptCount + 1;
        $ordinal -le $selectedEntries.Count;
        $ordinal += 1
    ) {
        $entry = $selectedEntries[$ordinal - 1]
        $auditPath = [string]$entry.path
        Write-Output (
            "CAP2_AUDIT_START ordinal=$ordinal/$($selectedEntries.Count) " +
            "path=$auditPath"
        )
        $startInfo = [Diagnostics.ProcessStartInfo]::new()
        $startInfo.FileName = $pwsh
        $startInfo.WorkingDirectory = $repoRoot
        $startInfo.UseShellExecute = $false
        $startInfo.CreateNoWindow = $true
        $startInfo.RedirectStandardOutput = $true
        $startInfo.RedirectStandardError = $true
        $startInfo.StandardOutputEncoding = [Text.UTF8Encoding]::new($false)
        $startInfo.StandardErrorEncoding = [Text.UTF8Encoding]::new($false)
        foreach ($argument in @("-NoLogo", "-NoProfile", "-File", $auditPath)) {
            [void]$startInfo.ArgumentList.Add($argument)
        }
        $process = [Diagnostics.Process]::new()
        $process.StartInfo = $startInfo
        $startedUtc = [DateTime]::UtcNow
        $watch = [Diagnostics.Stopwatch]::StartNew()
        $timedOut = $false
        try {
            Assert-Cap2 $process.Start() "audit process did not start: $auditPath"
            $auditInvocationCount += 1
            $stdoutTask = $process.StandardOutput.ReadToEndAsync()
            $stderrTask = $process.StandardError.ReadToEndAsync()
            if (-not $process.WaitForExit($HardSafetyTimeoutSeconds * 1000)) {
                $timedOut = $true
                try { $process.Kill($true) } catch { }
                [void]$process.WaitForExit(30000)
            }
            $stdout = ConvertTo-Cap2CanonicalText (
                $stdoutTask.GetAwaiter().GetResult()
            )
            $stderr = ConvertTo-Cap2CanonicalText (
                $stderrTask.GetAwaiter().GetResult()
            )
            $exitCode = if ($timedOut) { 124 } else { $process.ExitCode }
        } finally {
            $watch.Stop()
            $process.Dispose()
        }
        $endedUtc = [DateTime]::UtcNow
        $passed = -not $timedOut -and $exitCode -eq 0
        $pendingRoot = Join-Path $runRoot (
            "pending\" + $ordinal.ToString("D3") + "-" +
            [guid]::NewGuid().ToString("N")
        )
        [void][IO.Directory]::CreateDirectory($pendingRoot)
        $stdoutPath = Join-Path $pendingRoot "stdout.txt"
        $stderrPath = Join-Path $pendingRoot "stderr.txt"
        Write-Cap2NewUtf8File -Path $stdoutPath -Text $stdout
        Write-Cap2NewUtf8File -Path $stderrPath -Text $stderr
        $stdoutArtifact = Publish-SporeSporeContentAddressedArtifact `
            -RepoRoot $repoRoot -ArtifactPath $stdoutPath `
            -MediaType "text/plain; charset=utf-8; line-endings=lf" `
            -EvidenceRootOverride $evidenceRoot -TestOnly:$TestOnly
        $stderrArtifact = Publish-SporeSporeContentAddressedArtifact `
            -RepoRoot $repoRoot -ArtifactPath $stderrPath `
            -MediaType "text/plain; charset=utf-8; line-endings=lf" `
            -EvidenceRootOverride $evidenceRoot -TestOnly:$TestOnly
        $receipt = [ordered]@{
            schema_version = "sporespore_conformance_audit_duration_receipt_v2"
            status = "completed_audit_receipt_no_reuse_authority"
            run_id = $runId
            manifest_sha256 = $manifestSha
            input_key_sha256 = $inputKey
            ordinal = $ordinal
            selected_audit_count = $selectedEntries.Count
            audit_path = $auditPath
            audit_raw_sha256 = "sha256:" + [string]$entry.raw_sha256
            historical_identity_mode = [string]$entry.historical_identity_mode
            manual_review_required = [bool]$entry.manual_review_required
            started_utc = $startedUtc.ToString("o")
            ended_utc = $endedUtc.ToString("o")
            duration_seconds = $watch.Elapsed.TotalSeconds
            exit_code = $exitCode
            timed_out = $timedOut
            timeout_is_proven_hang = $false
            passed = $passed
            stdout_sha256 = [string]$stdoutArtifact.sha256
            stdout_byte_length = [long]$stdoutArtifact.byte_length
            stderr_sha256 = [string]$stderrArtifact.sha256
            stderr_byte_length = [long]$stderrArtifact.byte_length
            development_observation_only = $true
            production_cache_lookup_permitted = $false
            production_result_reuse_permitted = $false
            historical_audit_waiver_permitted = $false
            physical_authority = $false
            scientific_authority = $false
            release_authority = $false
        }
        $pendingReceiptPath = Join-Path $pendingRoot "receipt.json"
        Write-Cap2NewUtf8File -Path $pendingReceiptPath `
            -Text (($receipt | ConvertTo-Json -Depth 32) + "`n")
        $receiptArtifact = Publish-SporeSporeContentAddressedArtifact `
            -RepoRoot $repoRoot -ArtifactPath $pendingReceiptPath `
            -MediaType "application/json" `
            -EvidenceRootOverride $evidenceRoot -TestOnly:$TestOnly
        $receiptPath = Join-Path $receiptsRoot (
            $ordinal.ToString("D3") + ".json"
        )
        Assert-Cap2 (-not (Test-Path -LiteralPath $receiptPath)) (
            "receipt destination already exists at ordinal $ordinal"
        )
        [IO.File]::Move($pendingReceiptPath, $receiptPath)
        Assert-Cap2 (
            (Get-Cap2RawSha256 $receiptPath) -ceq
                [string]$receiptArtifact.sha256
        ) "receipt changed during atomic publication at ordinal $ordinal"
        $verifiedReceipts.Add((Read-Cap2VerifiedReceipt `
            -Ordinal $ordinal -Path $receiptPath))
        $publishedThisProcess += 1
        Write-Output (
            "CAP2_AUDIT_RECEIPT_PUBLISHED ordinal=$ordinal/" +
            "$($selectedEntries.Count) path=$auditPath passed=$passed " +
            "exit=$exitCode duration_seconds=" +
            $watch.Elapsed.TotalSeconds.ToString(
                "F7", [Globalization.CultureInfo]::InvariantCulture
            ) + " receipt_sha256=$($receiptArtifact.sha256)"
        )
        if (Test-Path -LiteralPath $pendingRoot) {
            $resolvedPending = [IO.Path]::GetFullPath($pendingRoot)
            $resolvedPendingFamily = [IO.Path]::GetFullPath(
                (Join-Path $runRoot "pending")
            ).TrimEnd('\', '/')
            Assert-Cap2 ($resolvedPending.StartsWith(
                $resolvedPendingFamily + [IO.Path]::DirectorySeparatorChar,
                [StringComparison]::OrdinalIgnoreCase
            )) "pending cleanup target escaped its run"
            Remove-Item -LiteralPath $resolvedPending -Recurse -Force
        }
        if (-not $passed) {
            $excerpt = (($stderr + "`n" + $stdout).Trim() -split "`n" |
                Select-Object -Last 8) -join " | "
            Write-Warning "CAP2 audit failure path=$auditPath excerpt=$excerpt"
        }
        if (
            $StopAfterPublishedReceiptCount -gt 0 -and
            $publishedThisProcess -ge $StopAfterPublishedReceiptCount
        ) {
            Write-Output (
                "CAP2_CONTROLLED_STOP " + ([ordered]@{
                    run_id = $runId
                    published_receipt_count = $verifiedReceipts.Count
                    last_receipt_sha256 = [string]$receiptArtifact.sha256
                    audit_invocation_count = $auditInvocationCount
                    worlds = 0
                    authority = $false
                } | ConvertTo-Json -Compress)
            )
            exit 90
        }
    }

    $ranked = [Collections.Generic.List[object]]::new()
    foreach ($verified in $verifiedReceipts) {
        $ranked.Add($verified.receipt)
    }
    $ranked.Sort([Comparison[object]]{
        param($left, $right)
        $durationOrder = ([double]$right.duration_seconds).CompareTo(
            [double]$left.duration_seconds
        )
        if ($durationOrder -ne 0) { return $durationOrder }
        return [string]::CompareOrdinal(
            [string]$left.audit_path,
            [string]$right.audit_path
        )
    })
    $failureCount = 0
    $totalSeconds = 0.0
    foreach ($verified in $verifiedReceipts) {
        if (-not [bool]$verified.receipt.passed) { $failureCount += 1 }
        $totalSeconds += [double]$verified.receipt.duration_seconds
    }
    $pendingFamilyRoot = Join-Path $runRoot "pending"
    $orphanPendingCount = if (Test-Path -LiteralPath $pendingFamilyRoot) {
        @(Get-ChildItem -LiteralPath $pendingFamilyRoot -Directory).Count
    } else { 0 }
    $profile = [ordered]@{
        schema_version = "sporespore_conformance_audit_duration_profile_v2"
        status = if ($failureCount -eq 0) {
            "complete_development_observation_all_selected_passed"
        } else { "complete_development_observation_with_failures" }
        run_id = $runId
        manifest_sha256 = $manifestSha
        input_key_sha256 = $inputKey
        mode = $mode
        summary = [ordered]@{
            selected_audit_count = $verifiedReceipts.Count
            pass_count = $verifiedReceipts.Count - $failureCount
            failure_count = $failureCount
            total_audit_seconds = [double]$totalSeconds
            serialized = $true
            resumed_receipt_count = $initialReceiptCount
            audit_invocation_count_this_process = $auditInvocationCount
            orphan_pending_directory_count = $orphanPendingCount
            world_build_count = 0
        }
        receipt_index = @($verifiedReceipts | ForEach-Object {
            [ordered]@{
                ordinal = [int]$_.receipt.ordinal
                audit_path = [string]$_.receipt.audit_path
                receipt_sha256 = [string]$_.receipt_sha256
                receipt_byte_length = [long]$_.receipt_byte_length
            }
        })
        receipts = @($verifiedReceipts | ForEach-Object { $_.receipt })
        ranking = @($ranked | ForEach-Object {
            [ordered]@{
                audit_path = [string]$_.audit_path
                duration_seconds = [double]$_.duration_seconds
                passed = [bool]$_.passed
            }
        })
        test_only = [bool]$TestOnly
        commissioning = [bool]$Commissioning
        crash_resilient_resume_candidate = $true
        crash_resilient_resume_commissioned = $false
        development_observation_only = $true
        audit_dependency_complete = $false
        runtime_profile_complete = $false
        cold_equivalence_complete = $false
        production_cache_lookup_permitted = $false
        production_result_reuse_permitted = $false
        historical_audit_waiver_permitted = $false
        physical_authority = $false
        scientific_authority = $false
        release_authority = $false
    }
    Write-Cap2NewUtf8File -Path $profilePath `
        -Text (($profile | ConvertTo-Json -Depth 64) + "`n")
    $profileArtifact = Publish-SporeSporeContentAddressedArtifact `
        -RepoRoot $repoRoot -ArtifactPath $profilePath `
        -MediaType "application/json" `
        -EvidenceRootOverride $evidenceRoot -TestOnly:$TestOnly
    Write-Output (
        "CAP2_PROFILE_COMPLETE " + ([ordered]@{
            run_id = $runId
            selected = $verifiedReceipts.Count
            passed = $verifiedReceipts.Count - $failureCount
            failed = $failureCount
            resumed_receipt_count = $initialReceiptCount
            audit_invocation_count = $auditInvocationCount
            total_audit_seconds = [double]$totalSeconds
            profile_sha256 = [string]$profileArtifact.sha256
            orphan_pending_directory_count = $orphanPendingCount
            worlds = 0
            cache = "disabled"
            physical_authority = $false
            release_authority = $false
        } | ConvertTo-Json -Compress)
    )
    if ($failureCount -ne 0) { exit 1 }
} finally {
    $runLease.Dispose()
}
