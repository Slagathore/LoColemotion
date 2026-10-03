#requires -Version 7.0

$script:SporeSporeExecutionReceiptContractPath = Join-Path `
    $PSScriptRoot "conformance_execution_receipt_contract_v1.json"
$script:SporeSporeExecutionReceiptModulePath = $PSCommandPath
$script:SporeSporeExecutionReceiptRunnerPath = Join-Path `
    $PSScriptRoot "run_conformance_execution_receipt_commissioning.ps1"
$script:SporeSporeExecutionReceiptArtifactStorePath = Join-Path `
    $PSScriptRoot "content_addressed_artifact_store.ps1"
$script:SporeSporeExecutionReceiptDependencyKeyPath = Join-Path `
    $PSScriptRoot "conformance_dependency_key.ps1"
$script:SporeSporeExecutionReceiptAuditDependencyPath = Join-Path `
    $PSScriptRoot "conformance_audit_dependency.ps1"
$script:SporeSporeExecutionReceiptRuntimeProfilePath = Join-Path `
    $PSScriptRoot "conformance_runtime_profile.ps1"

. $script:SporeSporeExecutionReceiptArtifactStorePath
. $script:SporeSporeExecutionReceiptDependencyKeyPath
. $script:SporeSporeExecutionReceiptAuditDependencyPath
. $script:SporeSporeExecutionReceiptRuntimeProfilePath

function Get-SporeSporeConformanceExecutionReceiptContract {
    [CmdletBinding()]
    param()
    if (-not (Test-Path -LiteralPath `
        $script:SporeSporeExecutionReceiptContractPath -PathType Leaf)) {
        throw "Conformance execution-receipt contract is missing."
    }
    $contract = Get-Content -LiteralPath `
        $script:SporeSporeExecutionReceiptContractPath -Raw |
        ConvertFrom-Json -AsHashtable -Depth 32
    if ([string]$contract.schema_version -cne
            "sporespore_conformance_execution_receipt_contract_v1" -or
        [string]$contract.status -cne
            "prospective_one_audit_cold_equivalence_uncommissioned" -or
        @($contract.candidate_audits).Count -ne 1 -or
        [bool]$contract.claims.cold_equivalence_complete -or
        [bool]$contract.claims.production_cache_lookup_permitted -or
        [bool]$contract.claims.production_result_reuse_permitted -or
        [bool]$contract.claims.historical_audit_waiver_permitted -or
        [bool]$contract.claims.physical_execution_authorized -or
        [bool]$contract.claims.scientific_authority -or
        [bool]$contract.claims.release_authority) {
        throw "Conformance execution-receipt contract exceeds CER1 authority."
    }
    return $contract
}

function ConvertTo-SporeSporeCanonicalExecutionText {
    [CmdletBinding()]
    param([AllowEmptyString()][string]$Text = "")
    if ($null -eq $Text) { return "" }
    return $Text.Replace("`r`n", "`n").Replace("`r", "`n")
}

function Get-SporeSporeExecutionTextBytes {
    param([AllowEmptyString()][string]$Text = "")
    # The unary comma preserves an empty byte array as one pipeline object;
    # otherwise PowerShell converts a legitimate zero-byte stderr payload into
    # no output and the caller receives $null.
    return ,([Text.UTF8Encoding]::new($false).GetBytes(
        (ConvertTo-SporeSporeCanonicalExecutionText $Text)
    ))
}

function Get-SporeSporeExecutionTextSha256 {
    param([AllowEmptyString()][string]$Text = "")
    return Get-SporeSporeDependencyByteSha256 (
        Get-SporeSporeExecutionTextBytes $Text
    )
}

function Invoke-SporeSporeExecutionReceiptGit {
    param(
        [Parameter(Mandatory)][string]$RepoRoot,
        [Parameter(Mandatory)][string[]]$Arguments
    )
    $output = @(& git -C $RepoRoot @Arguments 2>&1)
    if ($LASTEXITCODE -ne 0) {
        throw "Execution-receipt Git probe failed: git $($Arguments -join ' '): $($output -join ' ')"
    }
    return ($output -join "`n").Trim()
}

function Get-SporeSporeExecutionReceiptEvidenceRoot {
    param(
        [Parameter(Mandatory)][string]$RepoRoot,
        [string]$EvidenceRootOverride = "",
        [switch]$TestOnly
    )
    $production = Get-SporeSporeArtifactEvidenceRoot -RepoRoot $RepoRoot
    $selected = if ([string]::IsNullOrWhiteSpace($EvidenceRootOverride)) {
        $production
    } else {
        [IO.Path]::GetFullPath($EvidenceRootOverride).TrimEnd('\', '/')
    }
    if (-not $TestOnly -and $selected -cne $production) {
        throw "Production execution receipts must use $production"
    }
    return $selected
}

function Get-SporeSporeConformanceExecutionInputCandidate {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$RepoRoot,
        [string]$AuditPath = "tests/test_qsdk_r23d13_closure.ps1",
        [switch]$TestOnly
    )
    $repo = [IO.Path]::GetFullPath($RepoRoot).TrimEnd('\', '/')
    $contract = Get-SporeSporeConformanceExecutionReceiptContract
    $spec = @($contract.candidate_audits | Where-Object {
        [string]$_.audit_path -ceq $AuditPath
    })
    if ($spec.Count -ne 1) {
        throw "Audit is not a CER1 candidate: $AuditPath"
    }

    $status = Invoke-SporeSporeExecutionReceiptGit $repo @("status", "--short")
    $head = Invoke-SporeSporeExecutionReceiptGit $repo @("rev-parse", "HEAD")
    $headTree = Invoke-SporeSporeExecutionReceiptGit $repo @("rev-parse", "HEAD^{tree}")
    $originMain = Invoke-SporeSporeExecutionReceiptGit $repo @(
        "rev-parse", "origin/main"
    )
    $sourceEligible = (
        [string]::IsNullOrWhiteSpace($status) -and $head -ceq $originMain
    )
    if (-not $TestOnly -and -not $sourceEligible) {
        throw "Production execution receipt requires clean source equal to origin/main."
    }

    $auditCandidate = Get-SporeSporeConformanceAuditDependencyCandidate `
        -RepoRoot $repo
    $auditEntries = @($auditCandidate.entries | Where-Object {
        [string]$_.audit_path -ceq $AuditPath
    })
    if ($auditEntries.Count -ne 1) {
        throw "CER1 audit dependency entry is absent or ambiguous: $AuditPath"
    }
    $auditEntry = $auditEntries[0]
    if (-not [bool]$auditEntry.external_evidence_complete -or
        -not [bool]$auditEntry.runtime_complete -or
        -not [bool]$auditEntry.transitive_dependency_complete) {
        throw "CER1 audit dependency entry is incomplete: $AuditPath"
    }

    $runtimeCandidate = Get-SporeSporeConformanceRuntimeProfileCandidate `
        -RepoRoot $repo
    $runtimeProfiles = @($runtimeCandidate.profiles | Where-Object {
        @($_.audit_bindings) -ccontains $AuditPath
    })
    if ($runtimeProfiles.Count -ne 1) {
        throw "CER1 runtime profile is absent or ambiguous: $AuditPath"
    }
    $runtimeProfile = $runtimeProfiles[0]
    if (-not [bool]$runtimeProfile.declared_runtime_files_complete -or
        -not [bool]$runtimeProfile.native_child_reads_complete -or
        -not [bool]$runtimeProfile.host_semantics_complete -or
        -not [bool]$runtimeProfile.audit_binding_complete) {
        throw "CER1 runtime profile is incomplete: $AuditPath"
    }

    $processEnvironment = Get-SporeSporeProcessEnvironmentInventory
    $implementationPaths = @(
        "sdk/conformance_execution_receipt.ps1",
        "sdk/conformance_execution_receipt_contract_v1.json",
        "sdk/run_conformance_execution_receipt_commissioning.ps1",
        "sdk/content_addressed_artifact_store.ps1",
        "sdk/conformance_dependency_key.ps1",
        "sdk/conformance_audit_dependency.ps1",
        "sdk/conformance_audit_dependency_contract_v1.json",
        "sdk/conformance_audit_dependency_registry_v1.json",
        "sdk/conformance_runtime_profile.ps1",
        "sdk/conformance_runtime_profile_contract_v1.json",
        "sdk/conformance_runtime_profile_registry_v1.json"
    )
    $implementation = Get-SporeSporeDeclaredFileInventory `
        -Root $repo `
        -RelativePaths $implementationPaths `
        -InventoryId "cer1_execution_receipt_implementation"

    $pwsh = (Get-Command pwsh -CommandType Application -ErrorAction Stop |
        Select-Object -First 1).Source
    $pwshFull = [IO.Path]::GetFullPath($pwsh)
    $auditAbsolute = Join-Path $repo $AuditPath
    if (-not (Test-Path -LiteralPath $auditAbsolute -PathType Leaf)) {
        throw "CER1 audit source is missing: $AuditPath"
    }
    $command = [ordered]@{
        executable_name = [IO.Path]::GetFileName($pwshFull)
        executable_sha256 = Get-SporeSporeDependencyRawSha256 $pwshFull
        arguments = @("-NoLogo", "-NoProfile", "-File", $AuditPath)
        working_directory = "repository_root"
    }
    $auditEntryProjection = [ordered]@{
        audit_path = [string]$auditEntry.audit_path
        status = [string]$auditEntry.status
        audit_raw_sha256 = [string]$auditEntry.audit_raw_sha256
        dependency_shapes = @($auditEntry.dependency_shapes)
        external_evidence_complete = [bool]$auditEntry.external_evidence_complete
        runtime_complete = [bool]$auditEntry.runtime_complete
        transitive_dependency_complete =
            [bool]$auditEntry.transitive_dependency_complete
    }
    $runtimeProjection = [ordered]@{
        profile_id = [string]$runtimeProfile.profile_id
        audit_bindings = @($runtimeProfile.audit_bindings)
        measured_source = $runtimeProfile.measured_source
        powershell = $runtimeProfile.powershell
        git = $runtimeProfile.git
        host = $runtimeProfile.host
        declared_runtime_files_complete =
            [bool]$runtimeProfile.declared_runtime_files_complete
        native_child_reads_complete =
            [bool]$runtimeProfile.native_child_reads_complete
        host_semantics_complete = [bool]$runtimeProfile.host_semantics_complete
        audit_binding_complete = [bool]$runtimeProfile.audit_binding_complete
    }
    $projection = [ordered]@{
        schema_version = "sporespore_conformance_execution_input_v1"
        audit = $auditEntryProjection
        runtime = $runtimeProjection
        process_environment_inventory_sha256 =
            [string]$processEnvironment.inventory_sha256
        command = $command
        implementation_inventory_sha256 =
            [string]$implementation.inventory_sha256
        expected_terminal_prefix = [string]$spec[0].expected_terminal_prefix
        required_exit_code = [int]$spec[0].required_exit_code
    }
    return [ordered]@{
        schema_version = "sporespore_conformance_execution_input_candidate_v1"
        status = "complete_candidate_reuse_uncommissioned"
        audit_path = $AuditPath
        input_key_sha256 = Get-SporeSporeDependencyObjectSha256 $projection
        projection = $projection
        source = [ordered]@{
            head = $head
            head_tree = $headTree
            origin_main = $originMain
            clean_equal_origin_main = $sourceEligible
            dirty_entry_count = if ([string]::IsNullOrWhiteSpace($status)) {
                0
            } else { @($status -split "`r?`n").Count }
        }
        implementation_file_count = [int]$implementation.file_count
        process_environment_name_count =
            [int]$processEnvironment.variable_count
        complete = $true
        production_cache_lookup_permitted = $false
        production_result_reuse_permitted = $false
        physical_authority = $false
        release_authority = $false
    }
}

function Write-SporeSporeExecutionReceiptNewFile {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][AllowEmptyCollection()][byte[]]$Bytes
    )
    $directory = Split-Path -Parent $Path
    [void][IO.Directory]::CreateDirectory($directory)
    $stream = [IO.File]::Open(
        $Path,
        [IO.FileMode]::CreateNew,
        [IO.FileAccess]::Write,
        [IO.FileShare]::None
    )
    try { $stream.Write($Bytes, 0, $Bytes.Length) }
    finally { $stream.Dispose() }
}

function Publish-SporeSporeExecutionTextArtifact {
    param(
        [Parameter(Mandatory)][string]$RepoRoot,
        [Parameter(Mandatory)][string]$EvidenceRoot,
        [Parameter(Mandatory)][string]$StagingRoot,
        [Parameter(Mandatory)][string]$Name,
        [AllowEmptyString()][string]$Text = "",
        [switch]$TestOnly
    )
    $path = Join-Path $StagingRoot $Name
    $bytes = Get-SporeSporeExecutionTextBytes $Text
    Write-SporeSporeExecutionReceiptNewFile -Path $path -Bytes $bytes
    return Publish-SporeSporeContentAddressedArtifact `
        -RepoRoot $RepoRoot `
        -ArtifactPath $path `
        -MediaType "text/plain; charset=utf-8; line-endings=lf" `
        -EvidenceRootOverride $EvidenceRoot `
        -TestOnly:$TestOnly
}

function Publish-SporeSporeConformanceExecutionCandidate {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$RepoRoot,
        [Parameter(Mandatory)][Collections.IDictionary]$InputCandidate,
        [Parameter(Mandatory)][int]$ExitCode,
        [AllowEmptyString()][string]$Stdout = "",
        [AllowEmptyString()][string]$Stderr = "",
        [string]$EvidenceRootOverride = "",
        [switch]$TestOnly
    )
    $repo = [IO.Path]::GetFullPath($RepoRoot).TrimEnd('\', '/')
    $contract = Get-SporeSporeConformanceExecutionReceiptContract
    if (-not [bool]$InputCandidate.complete -or
        [string]$InputCandidate.status -cne
            "complete_candidate_reuse_uncommissioned" -or
        [string]$InputCandidate.input_key_sha256 -cnotmatch
            '^sha256:[0-9a-f]{64}$') {
        throw "CER1 execution input candidate is incomplete or malformed."
    }
    if (-not $TestOnly -and
        -not [bool]$InputCandidate.source.clean_equal_origin_main) {
        throw "CER1 production candidate publication requires clean pushed source."
    }
    $spec = @($contract.candidate_audits | Where-Object {
        [string]$_.audit_path -ceq [string]$InputCandidate.audit_path
    })
    if ($spec.Count -ne 1) {
        throw "CER1 publication audit is not declared."
    }
    if ($ExitCode -ne [int]$spec[0].required_exit_code) {
        throw "CER1 refuses to publish a failed execution: exit=$ExitCode"
    }

    $canonicalStdout = ConvertTo-SporeSporeCanonicalExecutionText $Stdout
    $canonicalStderr = ConvertTo-SporeSporeCanonicalExecutionText $Stderr
    $markerLines = @($canonicalStdout -split "`n" | Where-Object {
        $_.StartsWith(
            [string]$spec[0].expected_terminal_prefix,
            [StringComparison]::Ordinal
        )
    })
    if ($markerLines.Count -ne 1) {
        throw "CER1 requires exactly one declared terminal marker."
    }

    $evidence = Get-SporeSporeExecutionReceiptEvidenceRoot `
        -RepoRoot $repo `
        -EvidenceRootOverride $EvidenceRootOverride `
        -TestOnly:$TestOnly
    [void][IO.Directory]::CreateDirectory($evidence)
    $candidateRoot = Join-Path $evidence "conformance-cache-candidates\v1"
    $keyHex = ([string]$InputCandidate.input_key_sha256).Substring(7)
    $recordPath = Join-Path (Join-Path $candidateRoot $keyHex) "record.json"
    if (Test-Path -LiteralPath $recordPath) {
        throw "CER1 input key already has a create-only candidate record."
    }
    $stagingRoot = Join-Path $evidence (
        "conformance-cache-candidates\.staging-" + [guid]::NewGuid().ToString("N")
    )
    [void][IO.Directory]::CreateDirectory($stagingRoot)
    try {
        $stdoutArtifact = Publish-SporeSporeExecutionTextArtifact `
            -RepoRoot $repo `
            -EvidenceRoot $evidence `
            -StagingRoot $stagingRoot `
            -Name "stdout.txt" `
            -Text $canonicalStdout `
            -TestOnly:$TestOnly
        $stderrArtifact = Publish-SporeSporeExecutionTextArtifact `
            -RepoRoot $repo `
            -EvidenceRoot $evidence `
            -StagingRoot $stagingRoot `
            -Name "stderr.txt" `
            -Text $canonicalStderr `
            -TestOnly:$TestOnly
        $resultProjection = [ordered]@{
            schema_version = "sporespore_conformance_execution_result_v1"
            audit_path = [string]$InputCandidate.audit_path
            exit_code = $ExitCode
            terminal_marker = [string]$markerLines[0]
            stdout_sha256 = [string]$stdoutArtifact.sha256
            stdout_byte_length = [long]$stdoutArtifact.byte_length
            stderr_sha256 = [string]$stderrArtifact.sha256
            stderr_byte_length = [long]$stderrArtifact.byte_length
        }
        $record = [ordered]@{
            schema_version =
                "sporespore_conformance_execution_candidate_record_v1"
            status = "executed_candidate_reuse_uncommissioned"
            audit_path = [string]$InputCandidate.audit_path
            input_key_sha256 = [string]$InputCandidate.input_key_sha256
            executed_source_commit = [string]$InputCandidate.source.head
            command = $InputCandidate.projection.command
            result = $resultProjection
            result_projection_sha256 =
                Get-SporeSporeDependencyObjectSha256 $resultProjection
            created_utc = [DateTime]::UtcNow.ToString("o")
            test_only = [bool]$TestOnly
            cold_equivalence_complete = $false
            production_cache_lookup_permitted = $false
            production_result_reuse_permitted = $false
            historical_audit_waiver_permitted = $false
            physical_authority = $false
            scientific_authority = $false
            release_authority = $false
        }
        $recordBytes = [Text.UTF8Encoding]::new($false).GetBytes(
            ($record | ConvertTo-Json -Depth 64) + "`n"
        )
        Write-SporeSporeExecutionReceiptNewFile `
            -Path $recordPath `
            -Bytes $recordBytes
        $recordArtifact = Publish-SporeSporeContentAddressedArtifact `
            -RepoRoot $repo `
            -ArtifactPath $recordPath `
            -MediaType "application/json" `
            -EvidenceRootOverride $evidence `
            -TestOnly:$TestOnly
        return [ordered]@{
            schema_version =
                "sporespore_conformance_execution_candidate_publication_v1"
            record_path = $recordPath
            record_sha256 = [string]$recordArtifact.sha256
            record_byte_length = [long]$recordArtifact.byte_length
            input_key_sha256 = [string]$InputCandidate.input_key_sha256
            result_projection_sha256 =
                [string]$record.result_projection_sha256
            stdout_sha256 = [string]$stdoutArtifact.sha256
            stderr_sha256 = [string]$stderrArtifact.sha256
            production_result_reuse_permitted = $false
            physical_authority = $false
            release_authority = $false
        }
    } finally {
        if (Test-Path -LiteralPath $stagingRoot) {
            $resolvedStaging = [IO.Path]::GetFullPath($stagingRoot)
            $resolvedEvidence = [IO.Path]::GetFullPath($evidence).TrimEnd('\', '/')
            if (-not $resolvedStaging.StartsWith(
                    $resolvedEvidence + [IO.Path]::DirectorySeparatorChar,
                    [StringComparison]::OrdinalIgnoreCase
                ) -or
                (Split-Path -Leaf $resolvedStaging) -notlike '.staging-*') {
                throw "Refusing unsafe CER1 staging cleanup: $resolvedStaging"
            }
            Remove-Item -LiteralPath $resolvedStaging -Recurse -Force
        }
    }
}

function Read-SporeSporeConformanceExecutionCandidate {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$RepoRoot,
        [Parameter(Mandatory)][string]$ExpectedInputKeySha256,
        [string]$EvidenceRootOverride = "",
        [switch]$TestOnly
    )
    $repo = [IO.Path]::GetFullPath($RepoRoot).TrimEnd('\', '/')
    [void](Get-SporeSporeConformanceExecutionReceiptContract)
    if ($ExpectedInputKeySha256 -cnotmatch '^sha256:[0-9a-f]{64}$') {
        throw "CER1 expected input key is malformed."
    }
    $evidence = Get-SporeSporeExecutionReceiptEvidenceRoot `
        -RepoRoot $repo `
        -EvidenceRootOverride $EvidenceRootOverride `
        -TestOnly:$TestOnly
    $keyHex = $ExpectedInputKeySha256.Substring(7)
    $recordPath = Join-Path $evidence (
        "conformance-cache-candidates\v1\$keyHex\record.json"
    )
    if (-not (Test-Path -LiteralPath $recordPath -PathType Leaf)) {
        throw "CER1 candidate record is missing for input key."
    }
    $recordLength = (Get-Item -LiteralPath $recordPath).Length
    $recordDigest = Get-SporeSporeDependencyRawSha256 $recordPath
    $recordArtifactDirectory = Join-Path $evidence (
        "artifacts\sha256\" + $recordDigest.Substring(7)
    )
    if (-not (Test-SporeSporeStoredArtifact `
            -Directory $recordArtifactDirectory `
            -ExpectedSha256 $recordDigest.Substring(7) `
            -ExpectedByteLength $recordLength)) {
        throw "CER1 candidate record CAS verification failed."
    }
    $record = Get-Content -LiteralPath $recordPath -Raw |
        ConvertFrom-Json -AsHashtable -Depth 64
    if ([string]$record.schema_version -cne
            "sporespore_conformance_execution_candidate_record_v1" -or
        [string]$record.status -cne
            "executed_candidate_reuse_uncommissioned" -or
        [string]$record.input_key_sha256 -cne $ExpectedInputKeySha256 -or
        [int]$record.result.exit_code -ne 0 -or
        [bool]$record.cold_equivalence_complete -or
        [bool]$record.production_cache_lookup_permitted -or
        [bool]$record.production_result_reuse_permitted -or
        [bool]$record.historical_audit_waiver_permitted -or
        [bool]$record.physical_authority -or
        [bool]$record.scientific_authority -or
        [bool]$record.release_authority) {
        throw "CER1 candidate record is malformed or exceeds authority."
    }

    $stdoutHex = ([string]$record.result.stdout_sha256).Substring(7)
    $stderrHex = ([string]$record.result.stderr_sha256).Substring(7)
    $stdoutDirectory = Join-Path $evidence "artifacts\sha256\$stdoutHex"
    $stderrDirectory = Join-Path $evidence "artifacts\sha256\$stderrHex"
    if (-not (Test-SporeSporeStoredArtifact `
            -Directory $stdoutDirectory `
            -ExpectedSha256 $stdoutHex `
            -ExpectedByteLength ([long]$record.result.stdout_byte_length)) -or
        -not (Test-SporeSporeStoredArtifact `
            -Directory $stderrDirectory `
            -ExpectedSha256 $stderrHex `
            -ExpectedByteLength ([long]$record.result.stderr_byte_length))) {
        throw "CER1 output payload CAS verification failed."
    }
    $stdoutText = [Text.UTF8Encoding]::new($false, $true).GetString(
        [IO.File]::ReadAllBytes((Join-Path $stdoutDirectory "payload.bin"))
    )
    $stderrText = [Text.UTF8Encoding]::new($false, $true).GetString(
        [IO.File]::ReadAllBytes((Join-Path $stderrDirectory "payload.bin"))
    )
    $contract = Get-SporeSporeConformanceExecutionReceiptContract
    $spec = @($contract.candidate_audits | Where-Object {
        [string]$_.audit_path -ceq [string]$record.audit_path
    })
    if ($spec.Count -ne 1) {
        throw "CER1 record audit is no longer declared."
    }
    $markerLines = @($stdoutText -split "`n" | Where-Object {
        $_.StartsWith(
            [string]$spec[0].expected_terminal_prefix,
            [StringComparison]::Ordinal
        )
    })
    if ($markerLines.Count -ne 1 -or
        [string]$markerLines[0] -cne [string]$record.result.terminal_marker) {
        throw "CER1 retained terminal marker verification failed."
    }
    $projection = [ordered]@{
        schema_version = "sporespore_conformance_execution_result_v1"
        audit_path = [string]$record.result.audit_path
        exit_code = [int]$record.result.exit_code
        terminal_marker = [string]$record.result.terminal_marker
        stdout_sha256 = [string]$record.result.stdout_sha256
        stdout_byte_length = [long]$record.result.stdout_byte_length
        stderr_sha256 = [string]$record.result.stderr_sha256
        stderr_byte_length = [long]$record.result.stderr_byte_length
    }
    $projectionDigest = Get-SporeSporeDependencyObjectSha256 $projection
    if ($projectionDigest -cne [string]$record.result_projection_sha256) {
        throw "CER1 result projection digest changed."
    }
    return [ordered]@{
        schema_version =
            "sporespore_conformance_execution_candidate_readback_v1"
        status = "verified_read_back_not_production_reuse"
        audit_path = [string]$record.audit_path
        input_key_sha256 = $ExpectedInputKeySha256
        record_sha256 = $recordDigest
        result_projection_sha256 = $projectionDigest
        result = $projection
        stdout = $stdoutText
        stderr = $stderrText
        audit_invocation_count = 0
        cold_equivalence_complete = $false
        production_cache_lookup_permitted = $false
        production_result_reuse_permitted = $false
        physical_authority = $false
        release_authority = $false
    }
}
