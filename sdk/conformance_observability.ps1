#requires -Version 7.0

$script:SporeSporeConformanceStageSchema =
    "sporespore_conformance_stage_observation_v1"
$script:SporeSporeConformanceRunSchema =
    "sporespore_conformance_run_observation_v1"
$script:SporeSporeConformanceObservationContractPath = Join-Path `
    $PSScriptRoot "conformance_observability_contract_v1.json"
$script:SporeSporeConformanceArtifactStorePath = Join-Path `
    $PSScriptRoot "content_addressed_artifact_store.ps1"
$script:SporeSporeConformanceDependencyKeyPath = Join-Path `
    $PSScriptRoot "conformance_dependency_key.ps1"

. $script:SporeSporeConformanceArtifactStorePath
. $script:SporeSporeConformanceDependencyKeyPath

function Get-SporeSporeConformanceObservationContract {
    [CmdletBinding()]
    param()
    if (-not (Test-Path -LiteralPath `
        $script:SporeSporeConformanceObservationContractPath -PathType Leaf)) {
        throw "Conformance observability contract is missing."
    }
    $contract = Get-Content -LiteralPath `
        $script:SporeSporeConformanceObservationContractPath -Raw |
        ConvertFrom-Json -AsHashtable -Depth 32
    if ([string]$contract.schema_version -cne
        "sporespore_conformance_observability_contract_v1" -or
        [string]$contract.cache_boundary.status -cne
        "disabled_uncommissioned" -or
        [bool]$contract.cache_boundary.reuse_permitted -or
        [bool]$contract.input_identity_boundary.transitive_dependency_key_complete) {
        throw "Conformance observability contract exceeds its commissioned authority."
    }
    return $contract
}

function Get-SporeSporeConformanceRawSha256 {
    param([Parameter(Mandatory)][string]$Path)
    return "sha256:" + (
        Get-FileHash -LiteralPath $Path -Algorithm SHA256
    ).Hash.ToLowerInvariant()
}

function Get-SporeSporeConformanceObjectSha256 {
    param([Parameter(Mandatory)][object]$Value)
    $json = $Value | ConvertTo-Json -Depth 32 -Compress
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($json)
    $hash = [System.Security.Cryptography.SHA256]::HashData($bytes)
    return "sha256:" + [Convert]::ToHexString($hash).ToLowerInvariant()
}

function Write-SporeSporeConformanceJsonCreateOnly {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][object]$Document
    )
    if (Test-Path -LiteralPath $Path) {
        throw "Conformance observation output is create-only: $Path"
    }
    $json = ($Document | ConvertTo-Json -Depth 32) + [Environment]::NewLine
    [System.IO.File]::WriteAllText(
        $Path,
        $json,
        [System.Text.UTF8Encoding]::new($false)
    )
}

function Invoke-SporeSporeConformanceGit {
    param(
        [Parameter(Mandatory)][string]$RepoRoot,
        [Parameter(Mandatory)][string[]]$Arguments
    )
    $lines = @(& git -C $RepoRoot @Arguments 2>&1)
    if ($LASTEXITCODE -ne 0) {
        throw "Git identity probe failed: git $($Arguments -join ' '): $($lines -join ' ')"
    }
    return ($lines -join "`n").Trim()
}

function Get-SporeSporeConformanceToolIdentity {
    param(
        [Parameter(Mandatory)][string]$Command,
        [Parameter(Mandatory)][string[]]$VersionArguments
    )
    $resolved = Get-Command $Command -CommandType Application -ErrorAction SilentlyContinue |
        Select-Object -First 1
    if ($null -eq $resolved) {
        return [ordered]@{
            command = $Command
            available = $false
            executable_path = $null
            executable_sha256 = $null
            version = $null
            version_exit_code = $null
        }
    }
    $path = [System.IO.Path]::GetFullPath($resolved.Source)
    $startInfo = [System.Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = $path
    $startInfo.UseShellExecute = $false
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $startInfo.CreateNoWindow = $true
    foreach ($argument in $VersionArguments) {
        [void]$startInfo.ArgumentList.Add($argument)
    }
    $process = [System.Diagnostics.Process]::new()
    $process.StartInfo = $startInfo
    try {
        if (-not $process.Start()) {
            throw "Tool identity process did not start: $Command"
        }
        $stdout = $process.StandardOutput.ReadToEnd()
        $stderr = $process.StandardError.ReadToEnd()
        $process.WaitForExit()
        $version = (($stdout + [Environment]::NewLine + $stderr).Trim() -split "`r?`n")[0]
        return [ordered]@{
            command = $Command
            available = $true
            executable_path = $path
            executable_sha256 = Get-SporeSporeConformanceRawSha256 $path
            version = $version
            version_exit_code = $process.ExitCode
        }
    } finally {
        $process.Dispose()
    }
}

function Get-SporeSporeConformanceSourceObservation {
    param(
        [Parameter(Mandatory)][string]$RepoRoot,
        [Parameter(Mandatory)][string[]]$BindingPaths
    )
    $status = Invoke-SporeSporeConformanceGit $RepoRoot @("status", "--short")
    $bindings = [System.Collections.Generic.List[object]]::new()
    $bytesHashed = 0L
    foreach ($relativePath in $BindingPaths) {
        $absolutePath = Join-Path $RepoRoot $relativePath
        if (-not (Test-Path -LiteralPath $absolutePath -PathType Leaf)) {
            throw "Conformance observation binding is missing: $relativePath"
        }
        $length = (Get-Item -LiteralPath $absolutePath).Length
        $bytesHashed += $length
        $bindings.Add([ordered]@{
            path = $relativePath
            raw_sha256 = Get-SporeSporeConformanceRawSha256 $absolutePath
            byte_length = $length
        })
    }
    $identity = [ordered]@{
        status = "observed_not_transitive"
        repository_root = [System.IO.Path]::GetFullPath($RepoRoot)
        head = Invoke-SporeSporeConformanceGit $RepoRoot @("rev-parse", "HEAD")
        head_tree = Invoke-SporeSporeConformanceGit $RepoRoot @("rev-parse", "HEAD^{tree}")
        origin_main = Invoke-SporeSporeConformanceGit $RepoRoot @("rev-parse", "origin/main")
        remote_url = Invoke-SporeSporeConformanceGit $RepoRoot @("remote", "get-url", "origin")
        worktree_clean = [string]::IsNullOrWhiteSpace($status)
        status_entries = if ([string]::IsNullOrWhiteSpace($status)) {
            @()
        } else { @($status -split "`r?`n") }
        status_sha256 = Get-SporeSporeConformanceObjectSha256 @($status -split "`r?`n")
        bound_files = @($bindings)
        bound_file_set_sha256 = Get-SporeSporeConformanceObjectSha256 @($bindings)
        bound_file_bytes_hashed = $bytesHashed
        transitive_dependency_key_complete = $false
        cache_key_authority = $false
    }
    return $identity
}

function New-SporeSporeConformanceObservationSession {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$RepoRoot,
        [Parameter(Mandatory)][string]$RunnerPath,
        [Parameter(Mandatory)][bool]$SkipGodot,
        [string]$Godot = "",
        [string]$EvidenceRootOverride = "",
        [switch]$TestOnly,
        [switch]$SkipToolProbes,
        [switch]$SkipDependencyKeyCandidate,
        [switch]$SuppressConsoleReceipts
    )
    if ($SkipToolProbes -and -not $TestOnly) {
        throw "Skipping conformance tool probes is test-only."
    }
    if ($SuppressConsoleReceipts -and -not $TestOnly) {
        throw "Suppressing conformance receipts is test-only."
    }
    if ($SkipDependencyKeyCandidate -and -not $TestOnly) {
        throw "Skipping the conformance dependency-key candidate is test-only."
    }
    $repo = [System.IO.Path]::GetFullPath($RepoRoot).TrimEnd('\', '/')
    $runner = [System.IO.Path]::GetFullPath($RunnerPath)
    if (-not (Test-Path -LiteralPath $runner -PathType Leaf)) {
        throw "Conformance runner is missing: $runner"
    }
    $contract = Get-SporeSporeConformanceObservationContract
    $productionEvidenceRoot = Get-SporeSporeArtifactEvidenceRoot -RepoRoot $repo
    $evidenceRoot = if ([string]::IsNullOrWhiteSpace($EvidenceRootOverride)) {
        $productionEvidenceRoot
    } else { [System.IO.Path]::GetFullPath($EvidenceRootOverride).TrimEnd('\', '/') }
    if (-not $TestOnly -and $evidenceRoot -cne $productionEvidenceRoot) {
        throw "Production conformance observations must use $productionEvidenceRoot"
    }
    [void][System.IO.Directory]::CreateDirectory($evidenceRoot)
    $head = Invoke-SporeSporeConformanceGit $repo @("rev-parse", "HEAD")
    $runId = (
        [DateTime]::UtcNow.ToString("yyyyMMddTHHmmssZ") + "-" +
        $head.Substring(0, 8) + "-" + [guid]::NewGuid().ToString("N")
    )
    $runRoot = Join-Path $evidenceRoot ("conformance-runs\" + $runId)
    if (Test-Path -LiteralPath $runRoot) {
        throw "Conformance observation run identity already exists: $runRoot"
    }
    [void][System.IO.Directory]::CreateDirectory($runRoot)
    $stageRoot = Join-Path $runRoot "stages"
    [void][System.IO.Directory]::CreateDirectory($stageRoot)

    $bindingPaths = @($contract.input_identity_boundary.bound_files)
    $source = Get-SporeSporeConformanceSourceObservation `
        -RepoRoot $repo `
        -BindingPaths $bindingPaths
    $dependencyKeyCandidate = if ($SkipDependencyKeyCandidate) {
        [ordered]@{
            schema_version = "sporespore_conformance_dependency_key_test_fixture_v1"
            status = "test_fixture_candidate_skipped"
            key_sha256 = $null
            transitive_dependency_key_complete = $false
            undeclared_dependency_detection_complete = $false
            host_semantics_key_complete = $false
            cache_lookup_permitted = $false
            result_reuse_permitted = $false
            physical_authority = $false
            release_authority = $false
        }
    } else { $null }
    $toolchains = if ($SkipToolProbes) {
        [ordered]@{
            status = "test_fixture_tool_probes_skipped"
            test_only = $true
        }
    } else {
        $currentExecutable = [System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
        $identity = [ordered]@{
            status = "observed"
            operating_system = [System.Runtime.InteropServices.RuntimeInformation]::OSDescription
            process_architecture = (
                [System.Runtime.InteropServices.RuntimeInformation]::ProcessArchitecture
            ).ToString()
            powershell = [ordered]@{
                executable_path = [System.IO.Path]::GetFullPath($currentExecutable)
                executable_sha256 = Get-SporeSporeConformanceRawSha256 $currentExecutable
                version = $PSVersionTable.PSVersion.ToString()
                edition = [string]$PSVersionTable.PSEdition
            }
            python = Get-SporeSporeConformanceToolIdentity python @("--version")
            cargo = Get-SporeSporeConformanceToolIdentity cargo @("--version")
            rustc = Get-SporeSporeConformanceToolIdentity rustc @("--version")
            godot = if ($SkipGodot) {
                [ordered]@{ status = "skipped_by_declared_mode" }
            } else {
                if ([string]::IsNullOrWhiteSpace($Godot)) {
                    throw "Godot identity is required when SkipGodot is false."
                }
                Get-SporeSporeConformanceToolIdentity `
                    ([System.IO.Path]::GetFullPath($Godot)) @("--version")
            }
        }
        $identity
    }
    $toolchainDigest = Get-SporeSporeConformanceObjectSha256 $toolchains
    $tier = if ($SkipGodot) {
        [string]$contract.tier_by_mode.skip_godot
    } else { [string]$contract.tier_by_mode.godot_including }
    if ($tier -cnotin @("full_cold", "canonical_no_godot")) {
        throw "Conformance observability contract has an invalid mode tier."
    }

    return [pscustomobject]@{
        schema_version = "sporespore_conformance_observation_session_v1"
        run_id = $runId
        repo_root = $repo
        runner_path = $runner
        evidence_root = $evidenceRoot
        run_root = $runRoot
        stage_root = $stageRoot
        log_path = (Join-Path $runRoot "conformance.log")
        run_receipt_path = (Join-Path $runRoot "receipt.json")
        failure_excerpt_path = (Join-Path $runRoot "failure_excerpt.txt")
        contract = $contract
        source = $source
        source_digest = Get-SporeSporeConformanceObjectSha256 $source
        dependency_key_candidate = $dependencyKeyCandidate
        dependency_key_candidate_digest = if ($null -eq $dependencyKeyCandidate) {
            $null
        } elseif (
            [string]::IsNullOrWhiteSpace([string]$dependencyKeyCandidate.key_sha256)
        ) {
            Get-SporeSporeConformanceObjectSha256 $dependencyKeyCandidate
        } else { [string]$dependencyKeyCandidate.key_sha256 }
        dependency_key_candidate_required = -not [bool]$SkipDependencyKeyCandidate
        toolchains = $toolchains
        toolchain_digest = $toolchainDigest
        started_utc = [DateTime]::UtcNow
        stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
        tier = $tier
        skip_godot = $SkipGodot
        test_only = [bool]$TestOnly
        suppress_console_receipts = [bool]$SuppressConsoleReceipts
        stage_records = [System.Collections.Generic.List[object]]::new()
        current_stage = $null
        failure = $null
        finalized = $false
    }
}

function Start-SporeSporeConformanceStage {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object]$Session,
        [Parameter(Mandatory)][string]$StageId
    )
    if ([bool]$Session.finalized) {
        throw "A finalized conformance observation cannot start another stage."
    }
    if ($null -ne $Session.current_stage) {
        throw "Conformance stage '$($Session.current_stage.stage_id)' is still active."
    }
    $index = $Session.stage_records.Count
    if ($index -ge $Session.contract.stage_order.Count) {
        throw "Conformance stage '$StageId' exceeds the declared stage order."
    }
    $expected = $Session.contract.stage_order[$index]
    if ([string]$expected.stage_id -cne $StageId) {
        throw "Conformance stage order mismatch: expected '$($expected.stage_id)', got '$StageId'."
    }
    $Session.current_stage = [pscustomobject]@{
        stage_id = $StageId
        ordinal = [int]$expected.ordinal
        description = [string]$expected.description
        started_utc = [DateTime]::UtcNow
        stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    }
    if ($index -eq 0 -and [bool]$Session.dependency_key_candidate_required) {
        try {
            $candidate = New-SporeSporeConformanceDependencyKeyCandidate `
                -RepoRoot $Session.repo_root
            $Session.dependency_key_candidate = $candidate
            $Session.dependency_key_candidate_digest = [string]$candidate.key_sha256
        } catch {
            $candidateFailure = [ordered]@{
                schema_version = (
                    "sporespore_conformance_dependency_key_candidate_failure_v1"
                )
                status = "candidate_construction_failed"
                exception_type = $_.Exception.GetType().FullName
                message_sha256 = Get-SporeSporeConformanceObjectSha256 `
                    ([string]$_.Exception.Message)
                transitive_dependency_key_complete = $false
                cache_lookup_permitted = $false
                result_reuse_permitted = $false
                physical_authority = $false
                release_authority = $false
            }
            $Session.dependency_key_candidate = $candidateFailure
            $Session.dependency_key_candidate_digest = `
                Get-SporeSporeConformanceObjectSha256 $candidateFailure
            throw
        }
    }
}

function Complete-SporeSporeConformanceStage {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object]$Session,
        [ValidateSet("passed", "skipped", "failed")]
        [string]$Status = "passed",
        [int]$ExitCode = 0,
        [object]$ErrorIdentity = $null
    )
    if ($null -eq $Session.current_stage) {
        throw "No conformance stage is active."
    }
    $active = $Session.current_stage
    if ($null -eq $Session.dependency_key_candidate -or
        [string]::IsNullOrWhiteSpace(
            [string]$Session.dependency_key_candidate_digest)) {
        throw "Conformance stage cannot close without a dependency-key candidate."
    }
    $active.stopwatch.Stop()
    $completed = [DateTime]::UtcNow
    $receiptPath = Join-Path $Session.stage_root (
        "{0:D2}-{1}.json" -f $active.ordinal, $active.stage_id
    )
    $document = [ordered]@{
        schema_version = $script:SporeSporeConformanceStageSchema
        run_id = [string]$Session.run_id
        tier = [string]$Session.tier
        skip_godot = [bool]$Session.skip_godot
        stage_id = [string]$active.stage_id
        ordinal = [int]$active.ordinal
        description = [string]$active.description
        status = $Status
        started_utc = $active.started_utc.ToUniversalTime().ToString("o")
        completed_utc = $completed.ToUniversalTime().ToString("o")
        duration_seconds = [double]$active.stopwatch.Elapsed.TotalSeconds
        exit_code = $ExitCode
        observed_input_identity_sha256 = [string]$Session.source_digest
        observed_input_status = "observed_not_transitive"
        transitive_dependency_key_complete = $false
        dependency_key_candidate = [ordered]@{
            status = [string]$Session.dependency_key_candidate.status
            key_sha256 = [string]$Session.dependency_key_candidate_digest
            transitive_dependency_key_complete = $false
            undeclared_dependency_detection_complete = $false
            host_semantics_key_complete = $false
            cache_lookup_permitted = $false
            result_reuse_permitted = $false
        }
        toolchain_runtime_identity_sha256 = [string]$Session.toolchain_digest
        bytes_hashed = [long]$Session.source.bound_file_bytes_hashed
        cache = [ordered]@{
            status = "disabled_uncommissioned"
            lookup_performed = $false
            result_reused = $false
            reuse_authority = $false
        }
        full_log_paths = @([string]$Session.log_path)
        error = $ErrorIdentity
        claims = [ordered]@{
            cache_commissioned = $false
            historical_audit_waiver = $false
            physical_campaign_executed = $false
            physical_acceptance_authority = $false
            scientific_result = $false
            release_authority = $false
        }
    }
    Write-SporeSporeConformanceJsonCreateOnly -Path $receiptPath -Document $document
    $rawSha = Get-SporeSporeConformanceRawSha256 $receiptPath
    $cas = Publish-SporeSporeContentAddressedArtifact `
        -RepoRoot $Session.repo_root `
        -ArtifactPath $receiptPath `
        -MediaType "application/json" `
        -EvidenceRootOverride $Session.evidence_root `
        -TestOnly:$Session.test_only
    $projection = [ordered]@{
        stage_id = [string]$active.stage_id
        ordinal = [int]$active.ordinal
        status = $Status
        duration_seconds = [double]$active.stopwatch.Elapsed.TotalSeconds
        exit_code = $ExitCode
        receipt_path = $receiptPath
        receipt_raw_sha256 = $rawSha
        receipt_cas_payload_path = [string]$cas.payload_path
        receipt_cas_manifest_path = [string]$cas.manifest_path
        cache_status = "disabled_uncommissioned"
        result_reused = $false
    }
    $Session.stage_records.Add($projection)
    $Session.current_stage = $null
    $console = [ordered]@{
        stage_id = $projection.stage_id
        status = $projection.status
        duration_seconds = $projection.duration_seconds
        cache_status = $projection.cache_status
        receipt = $projection.receipt_path
        sha256 = $projection.receipt_raw_sha256
    } | ConvertTo-Json -Compress
    if (-not [bool]$Session.suppress_console_receipts) {
        if ($Status -ceq "failed") {
            Write-Host ("CONFORMANCE_STAGE_FAILURE " + $console)
        } else {
            Write-Host ("CONFORMANCE_STAGE_RECEIPT " + $console)
        }
    }
    return $projection
}

function Fail-SporeSporeConformanceStage {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object]$Session,
        [Parameter(Mandatory)][System.Management.Automation.ErrorRecord]$ErrorRecord,
        [int]$ExitCode = 1
    )
    $identity = [ordered]@{
        exception_type = $ErrorRecord.Exception.GetType().FullName
        message = $ErrorRecord.Exception.Message
        fully_qualified_error_id = [string]$ErrorRecord.FullyQualifiedErrorId
        script_stack_trace = [string]$ErrorRecord.ScriptStackTrace
    }
    $Session.failure = $identity
    if ($null -ne $Session.current_stage) {
        return Complete-SporeSporeConformanceStage `
            -Session $Session `
            -Status failed `
            -ExitCode $ExitCode `
            -ErrorIdentity $identity
    }
    return $null
}

function Complete-SporeSporeConformanceObservation {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object]$Session,
        [ValidateSet("passed", "failed")][string]$Status
    )
    if ([bool]$Session.finalized) {
        throw "Conformance observation was already finalized."
    }
    if ($null -ne $Session.current_stage) {
        throw "Active conformance stage was not closed before run finalization."
    }
    if ($Status -ceq "passed") {
        if ($Session.stage_records.Count -ne $Session.contract.stage_order.Count) {
            throw (
                "Passing conformance observation requires all declared stages: " +
                "$($Session.stage_records.Count)/$($Session.contract.stage_order.Count)"
            )
        }
        if (@($Session.stage_records | Where-Object {
            $_.status -cnotin @("passed", "skipped")
        }).Count -ne 0) {
            throw "Passing conformance observation contains a failed stage."
        }
    } elseif (@($Session.stage_records | Where-Object {
        $_.status -ceq "failed"
    }).Count -ne 1) {
        throw "Failed conformance observation requires exactly one failed stage."
    }
    if (-not (Test-Path -LiteralPath $Session.log_path -PathType Leaf)) {
        throw "Conformance transcript is missing: $($Session.log_path)"
    }
    $Session.stopwatch.Stop()
    $completed = [DateTime]::UtcNow
    $logCas = Publish-SporeSporeContentAddressedArtifact `
        -RepoRoot $Session.repo_root `
        -ArtifactPath $Session.log_path `
        -MediaType "text/plain" `
        -EvidenceRootOverride $Session.evidence_root `
        -TestOnly:$Session.test_only
    $failureExcerpt = $null
    if ($Status -ceq "failed") {
        $maxLines = [int]$Session.contract.receipt_requirements.failure_excerpt_max_lines
        $maxCharacters = [int]$Session.contract.receipt_requirements.failure_excerpt_max_characters
        $tail = @(
            Get-Content -LiteralPath $Session.log_path -Tail $maxLines
        ) -join [Environment]::NewLine
        $prefix = "exception: $($Session.failure.message)" + [Environment]::NewLine
        $excerpt = $prefix + $tail
        if ($excerpt.Length -gt $maxCharacters) {
            $excerpt = $excerpt.Substring($excerpt.Length - $maxCharacters)
        }
        [System.IO.File]::WriteAllText(
            $Session.failure_excerpt_path,
            $excerpt + [Environment]::NewLine,
            [System.Text.UTF8Encoding]::new($false)
        )
        $excerptCas = Publish-SporeSporeContentAddressedArtifact `
            -RepoRoot $Session.repo_root `
            -ArtifactPath $Session.failure_excerpt_path `
            -MediaType "text/plain" `
            -EvidenceRootOverride $Session.evidence_root `
            -TestOnly:$Session.test_only
        $failureExcerpt = [ordered]@{
            path = [string]$Session.failure_excerpt_path
            raw_sha256 = Get-SporeSporeConformanceRawSha256 $Session.failure_excerpt_path
            byte_length = (Get-Item -LiteralPath $Session.failure_excerpt_path).Length
            cas_payload_path = [string]$excerptCas.payload_path
            cas_manifest_path = [string]$excerptCas.manifest_path
            max_lines = $maxLines
            max_characters = $maxCharacters
        }
    }
    $runDocument = [ordered]@{
        schema_version = $script:SporeSporeConformanceRunSchema
        contract_schema_version = [string]$Session.contract.schema_version
        run_id = [string]$Session.run_id
        status = $Status
        tier = [string]$Session.tier
        skip_godot = [bool]$Session.skip_godot
        test_only = [bool]$Session.test_only
        started_utc = $Session.started_utc.ToUniversalTime().ToString("o")
        completed_utc = $completed.ToUniversalTime().ToString("o")
        duration_seconds = [double]$Session.stopwatch.Elapsed.TotalSeconds
        source = $Session.source
        observed_input_identity_sha256 = [string]$Session.source_digest
        input_identity = [ordered]@{
            status = "observed_not_transitive"
            transitive_dependency_key_complete = $false
            undeclared_dependency_detection_complete = $false
            host_semantics_key_complete = $false
            dependency_key_candidate = $Session.dependency_key_candidate
        }
        toolchain_runtime_identity = $Session.toolchains
        toolchain_runtime_identity_sha256 = [string]$Session.toolchain_digest
        cache = [ordered]@{
            status = "disabled_uncommissioned"
            lookup_performed = $false
            result_reused = $false
            reuse_authority = $false
            full_source_exact_conformance_remains_required = $true
        }
        full_log = [ordered]@{
            path = [string]$Session.log_path
            raw_sha256 = Get-SporeSporeConformanceRawSha256 $Session.log_path
            byte_length = (Get-Item -LiteralPath $Session.log_path).Length
            cas_payload_path = [string]$logCas.payload_path
            cas_manifest_path = [string]$logCas.manifest_path
        }
        failure_excerpt = $failureExcerpt
        stage_receipts = @($Session.stage_records)
        failure = $Session.failure
        claims = [ordered]@{
            cache_commissioned = $false
            historical_audit_waiver = $false
            physical_campaign_executed = $false
            physical_acceptance_authority = $false
            scientific_result = $false
            release_authority = $false
        }
    }
    Write-SporeSporeConformanceJsonCreateOnly `
        -Path $Session.run_receipt_path `
        -Document $runDocument
    $runCas = Publish-SporeSporeContentAddressedArtifact `
        -RepoRoot $Session.repo_root `
        -ArtifactPath $Session.run_receipt_path `
        -MediaType "application/json" `
        -EvidenceRootOverride $Session.evidence_root `
        -TestOnly:$Session.test_only
    $Session.finalized = $true
    $summary = [ordered]@{
        status = $Status
        tier = [string]$Session.tier
        duration_seconds = [double]$Session.stopwatch.Elapsed.TotalSeconds
        stage_count = $Session.stage_records.Count
        cache_status = "disabled_uncommissioned"
        result_reused = $false
        receipt = [string]$Session.run_receipt_path
        sha256 = Get-SporeSporeConformanceRawSha256 $Session.run_receipt_path
        cas_payload = [string]$runCas.payload_path
        full_log = [string]$Session.log_path
    }
    if (-not [bool]$Session.suppress_console_receipts) {
        Write-Host (
            "CONFORMANCE_RUN_RECEIPT " +
            ($summary | ConvertTo-Json -Compress)
        )
    }
    return $summary
}
