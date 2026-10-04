#requires -Version 7.0

$script:SporeSporeFullConformanceAttestationSchema =
    "sporespore_full_godot_conformance_attestation_v2"
$script:SporeSporeEvidenceDirectoryName = "SporeSpore_Evidence"
$script:SporeSporeAttestationBindingPaths = @(
    "sdk/run_conformance.ps1",
    "sdk/locomotion_operation_lock.ps1",
    "sdk/locomotion_full_conformance_attestation.ps1",
    "sdk/locomotion_operation_attestation_contract.json"
)
$script:SporeSporeFullConformanceClaimNames = @(
    "new_physical_campaign_executed",
    "new_scientific_outcome_exposed",
    "physical_acceptance_authority",
    "walking_acceptance",
    "turning_acceptance",
    "material_robustness",
    "cross_engine_equivalence",
    "arbitrary_quadruped_coverage",
    "release_authorized",
    "completed_engine_neutral_sdk"
)

function Get-SporeSporeSha256 {
    param([Parameter(Mandatory)][string]$Path)
    return "sha256:" + (
        Get-FileHash -LiteralPath $Path -Algorithm SHA256
    ).Hash.ToLowerInvariant()
}

function Get-SporeSporeAttestationPowerShellIdentity {
    [CmdletBinding()]
    param()
    $executable = [System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
    return [ordered]@{
        executable_path = [System.IO.Path]::GetFullPath($executable)
        executable_sha256 = Get-SporeSporeSha256 $executable
        version = $PSVersionTable.PSVersion.ToString()
        edition = [string]$PSVersionTable.PSEdition
        process_architecture = (
            [System.Runtime.InteropServices.RuntimeInformation]::ProcessArchitecture
        ).ToString()
    }
}

function ConvertTo-SporeSporeAttestationUtcDateTime {
    param([Parameter(Mandatory)][object]$Value)
    if ($Value -is [DateTime]) {
        return ([DateTime]$Value).ToUniversalTime()
    }
    if ($Value -is [DateTimeOffset]) {
        return ([DateTimeOffset]$Value).UtcDateTime
    }
    return [DateTime]::Parse(
        [string]$Value,
        [System.Globalization.CultureInfo]::InvariantCulture,
        [System.Globalization.DateTimeStyles]::RoundtripKind
    ).ToUniversalTime()
}

function Invoke-SporeSporeAttestationGit {
    param(
        [Parameter(Mandatory)][string]$RepoRoot,
        [Parameter(Mandatory)][string[]]$Arguments
    )
    $lines = @(& git -C $RepoRoot @Arguments 2>&1)
    if ($LASTEXITCODE -ne 0) {
        throw "Git failed for attestation: git $($Arguments -join ' '): $($lines -join ' ')"
    }
    return ($lines -join "`n").Trim()
}

function Get-SporeSporeAttestationSourceIdentity {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$RepoRoot,
        [switch]$RequireCleanPushedLive
    )
    $root = [System.IO.Path]::GetFullPath($RepoRoot).TrimEnd(
        [System.IO.Path]::DirectorySeparatorChar,
        [System.IO.Path]::AltDirectorySeparatorChar
    )
    $head = Invoke-SporeSporeAttestationGit $root @("rev-parse", "HEAD")
    $tree = Invoke-SporeSporeAttestationGit $root @("rev-parse", "HEAD^{tree}")
    $origin = Invoke-SporeSporeAttestationGit $root @("rev-parse", "origin/main")
    $remoteUrl = Invoke-SporeSporeAttestationGit $root @("remote", "get-url", "origin")
    $statusText = Invoke-SporeSporeAttestationGit $root @("status", "--short")
    $liveLine = Invoke-SporeSporeAttestationGit $root @(
        "ls-remote", "origin", "refs/heads/main"
    )
    $live = if ([string]::IsNullOrWhiteSpace($liveLine)) {
        ""
    } else { ($liveLine -split '\s+')[0] }
    $clean = [string]::IsNullOrWhiteSpace($statusText)
    $eligible = (
        $clean -and $head -ceq $origin -and $head -ceq $live -and
        $remoteUrl -ceq "https://github.com/Slagathore/LoColemotion.git"
    )
    if ($RequireCleanPushedLive -and -not $eligible) {
        throw (
            "Full-conformance attestation requires clean pushed live source: " +
            "head=$head origin=$origin live=$live clean=$clean remote=$remoteUrl"
        )
    }
    return [ordered]@{
        repository_root = $root
        remote_url = $remoteUrl
        commit = $head
        tree_git_oid = $tree
        origin_main = $origin
        live_github_main = $live
        worktree_clean = $clean
        clean_pushed_live = $eligible
        status_entries = if ($clean) { @() } else { @($statusText -split "`r?`n") }
    }
}

function Get-SporeSporeAttestationGodotIdentity {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Godot)
    $path = [System.IO.Path]::GetFullPath($Godot)
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "Godot executable is missing: $path"
    }
    $versionLines = @(& $path --version 2>&1)
    if ($LASTEXITCODE -ne 0 -or $versionLines.Count -eq 0) {
        throw "Godot version readback failed for attestation: $path"
    }
    return [ordered]@{
        executable_path = $path
        executable_sha256 = Get-SporeSporeSha256 $path
        version = ([string]$versionLines[0]).Trim()
    }
}

function Get-SporeSporeAttestationSourceBindings {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$RepoRoot,
        [string]$Commit = "HEAD"
    )
    $bindings = [System.Collections.Generic.List[object]]::new()
    foreach ($relativePath in $script:SporeSporeAttestationBindingPaths) {
        $absolutePath = Join-Path $RepoRoot $relativePath
        if (-not (Test-Path -LiteralPath $absolutePath -PathType Leaf)) {
            throw "Attestation source binding is missing: $relativePath"
        }
        $blob = Invoke-SporeSporeAttestationGit $RepoRoot @(
            "rev-parse", "${Commit}:$relativePath"
        )
        $bindings.Add([ordered]@{
            path = $relativePath
            raw_sha256 = Get-SporeSporeSha256 $absolutePath
            git_blob_oid = $blob
        })
    }
    return @($bindings)
}

function New-SporeSporeFullConformanceAttestationDocument {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][System.Collections.IDictionary]$Source,
        [Parameter(Mandatory)][System.Collections.IDictionary]$GodotIdentity,
        [Parameter(Mandatory)][System.Collections.IDictionary]$PowerShellIdentity,
        [Parameter(Mandatory)][object[]]$SourceBindings,
        [Parameter(Mandatory)][System.Collections.IDictionary]$OperationLock,
        [Parameter(Mandatory)][DateTime]$StartedUtc,
        [Parameter(Mandatory)][DateTime]$CompletedUtc,
        [switch]$TestOnly
    )
    return [ordered]@{
        schema_version = $script:SporeSporeFullConformanceAttestationSchema
        status = "full_godot_conformance_passed"
        test_only = [bool]$TestOnly
        conformance = [ordered]@{
            runner = "sdk/run_conformance.ps1"
            skip_godot = $false
            godot_including = $true
            canonical_terminal_marker = "SDK C0/C1 conformance passed."
            passed = $true
            regression_test_physics_permitted = $true
            one_shot_physical_campaign_executed = $false
            started_utc = $StartedUtc.ToUniversalTime().ToString("o")
            completed_utc = $CompletedUtc.ToUniversalTime().ToString("o")
            duration_seconds = ($CompletedUtc - $StartedUtc).TotalSeconds
        }
        source = $Source
        godot = $GodotIdentity
        powershell = $PowerShellIdentity
        source_bindings = @($SourceBindings)
        operation_lock = $OperationLock
        claims = [ordered]@{
            new_physical_campaign_executed = $false
            new_scientific_outcome_exposed = $false
            physical_acceptance_authority = $false
            walking_acceptance = $false
            turning_acceptance = $false
            material_robustness = $false
            cross_engine_equivalence = $false
            arbitrary_quadruped_coverage = $false
            release_authorized = $false
            completed_engine_neutral_sdk = $false
        }
    }
}

function Test-SporeSporeFullConformanceAttestationDocument {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][System.Collections.IDictionary]$Document,
        [Parameter(Mandatory)][System.Collections.IDictionary]$ExpectedSource,
        [Parameter(Mandatory)][System.Collections.IDictionary]$ExpectedGodotIdentity,
        [Parameter(Mandatory)][System.Collections.IDictionary]$ExpectedPowerShellIdentity,
        [Parameter(Mandatory)][object[]]$ExpectedSourceBindings,
        [switch]$AllowTestOnly
    )
    $failures = [System.Collections.Generic.List[string]]::new()
    if ([string]$Document.schema_version -cne
        $script:SporeSporeFullConformanceAttestationSchema) {
        $failures.Add("ATTESTATION_SCHEMA")
    }
    if ([string]$Document.status -cne "full_godot_conformance_passed") {
        $failures.Add("ATTESTATION_STATUS")
    }
    if ([bool]$Document.test_only -and -not $AllowTestOnly) {
        $failures.Add("TEST_ATTESTATION_FORBIDDEN")
    }
    $conformance = $Document.conformance
    $timestampsValid = $false
    try {
        $started = ConvertTo-SporeSporeAttestationUtcDateTime `
            $conformance.started_utc
        $completed = ConvertTo-SporeSporeAttestationUtcDateTime `
            $conformance.completed_utc
        $timestampsValid = (
            $completed -ge $started -and
            [Math]::Abs(
                ($completed - $started).TotalSeconds -
                [double]$conformance.duration_seconds
            ) -le 0.001
        )
    } catch { $timestampsValid = $false }
    if (-not [bool]$conformance.passed -or [bool]$conformance.skip_godot -or
        -not [bool]$conformance.godot_including -or
        -not [bool]$conformance.regression_test_physics_permitted -or
        [bool]$conformance.one_shot_physical_campaign_executed -or
        [string]$conformance.canonical_terminal_marker -cne
            "SDK C0/C1 conformance passed." -or
        [double]$conformance.duration_seconds -lt 0.0 -or
        -not $timestampsValid) {
        $failures.Add("FULL_GODOT_CONFORMANCE")
    }
    foreach ($field in @(
        "repository_root", "remote_url", "commit", "tree_git_oid", "origin_main",
        "live_github_main"
    )) {
        if ([string]$Document.source[$field] -cne [string]$ExpectedSource[$field]) {
            $failures.Add("SOURCE_$($field.ToUpperInvariant())")
        }
    }
    if (-not [bool]$Document.source.worktree_clean -or
        -not [bool]$Document.source.clean_pushed_live) {
        $failures.Add("SOURCE_NOT_CLEAN_PUSHED_LIVE")
    }
    foreach ($field in @("executable_path", "executable_sha256", "version")) {
        if ([string]$Document.godot[$field] -cne
            [string]$ExpectedGodotIdentity[$field]) {
            $failures.Add("GODOT_$($field.ToUpperInvariant())")
        }
    }
    foreach ($field in @(
        "executable_path", "executable_sha256", "version", "edition",
        "process_architecture"
    )) {
        if ([string]$Document.powershell[$field] -cne
            [string]$ExpectedPowerShellIdentity[$field]) {
            $failures.Add("POWERSHELL_$($field.ToUpperInvariant())")
        }
    }
    $actualBindingJson = @($Document.source_bindings) |
        ConvertTo-Json -Depth 16 -Compress
    $expectedBindingJson = @($ExpectedSourceBindings) |
        ConvertTo-Json -Depth 16 -Compress
    if ($actualBindingJson -cne $expectedBindingJson) {
        $failures.Add("SOURCE_BINDINGS")
    }
    if (-not [bool]$Document.operation_lock.acquired -or
        [string]$Document.operation_lock.role -cne "conformance" -or
        [string]$Document.operation_lock.mutex_name -cne
            (Get-SporeSporeLocomotionOperationMutexName) -or
        [bool]$Document.operation_lock.test_only) {
        $failures.Add("OPERATION_LOCK")
    }
    $actualClaimNames = @($Document.claims.Keys | Sort-Object)
    $expectedClaimNames = @($script:SporeSporeFullConformanceClaimNames |
        Sort-Object)
    if (($actualClaimNames | ConvertTo-Json -Compress) -cne
        ($expectedClaimNames | ConvertTo-Json -Compress)) {
        $failures.Add("CLAIM_SCHEMA")
    }
    foreach ($claimName in $script:SporeSporeFullConformanceClaimNames) {
        if (-not $Document.claims.Contains($claimName) -or
            [bool]$Document.claims[$claimName]) {
            $failures.Add("CLAIM_INFLATION::$claimName")
        }
    }
    return [ordered]@{
        ok = $failures.Count -eq 0
        failure_codes = @($failures | Sort-Object -Unique)
        physical_acceptance_authority = $false
    }
}

function Assert-SporeSporeDurableAttestationOutputPath {
    param(
        [Parameter(Mandatory)][string]$RepoRoot,
        [Parameter(Mandatory)][string]$OutputPath,
        [switch]$AllowExisting
    )
    $evidenceRoot = [System.IO.Path]::GetFullPath((Join-Path (
        Split-Path -Parent $RepoRoot
    ) $script:SporeSporeEvidenceDirectoryName)).TrimEnd('\', '/')
    $resolvedOutput = [System.IO.Path]::GetFullPath($OutputPath)
    $prefix = $evidenceRoot + [System.IO.Path]::DirectorySeparatorChar
    if (-not $resolvedOutput.StartsWith(
        $prefix,
        [System.StringComparison]::OrdinalIgnoreCase
    )) {
        throw "Durable conformance attestation must be inside $evidenceRoot"
    }
    if ([System.IO.Path]::GetExtension($resolvedOutput) -cne ".json") {
        throw "Durable conformance attestation output must be a .json file."
    }
    if (-not $AllowExisting -and (Test-Path -LiteralPath $resolvedOutput)) {
        throw "Durable conformance attestation output already exists: $resolvedOutput"
    }
    return $resolvedOutput
}

function Publish-SporeSporeFullConformanceAttestation {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$RepoRoot,
        [Parameter(Mandatory)][string]$Godot,
        [Parameter(Mandatory)][string]$OutputPath,
        [Parameter(Mandatory)][object]$OperationLockReceipt,
        [Parameter(Mandatory)][DateTime]$StartedUtc,
        [Parameter(Mandatory)][System.Collections.IDictionary]$SourceAtStart
    )
    $resolvedOutput = Assert-SporeSporeDurableAttestationOutputPath `
        $RepoRoot $OutputPath
    $source = Get-SporeSporeAttestationSourceIdentity `
        -RepoRoot $RepoRoot `
        -RequireCleanPushedLive
    if ([string]$source.commit -cne [string]$SourceAtStart.commit -or
        [string]$source.tree_git_oid -cne [string]$SourceAtStart.tree_git_oid) {
        throw "Source changed during full conformance; refusing attestation."
    }
    $godotIdentity = Get-SporeSporeAttestationGodotIdentity -Godot $Godot
    $powerShellIdentity = Get-SporeSporeAttestationPowerShellIdentity
    $bindings = @(Get-SporeSporeAttestationSourceBindings `
        -RepoRoot $RepoRoot `
        -Commit ([string]$source.commit))
    $lockPublic = Get-SporeSporeLocomotionOperationLockPublicReceipt `
        $OperationLockReceipt
    $completedUtc = [DateTime]::UtcNow
    $document = New-SporeSporeFullConformanceAttestationDocument `
        -Source $source `
        -GodotIdentity $godotIdentity `
        -PowerShellIdentity $powerShellIdentity `
        -SourceBindings $bindings `
        -OperationLock $lockPublic `
        -StartedUtc $StartedUtc `
        -CompletedUtc $completedUtc
    $validation = Test-SporeSporeFullConformanceAttestationDocument `
        -Document $document `
        -ExpectedSource $source `
        -ExpectedGodotIdentity $godotIdentity `
        -ExpectedPowerShellIdentity $powerShellIdentity `
        -ExpectedSourceBindings $bindings
    if (-not [bool]$validation.ok) {
        throw "Constructed conformance attestation failed: $($validation.failure_codes -join ', ')"
    }
    $parent = Split-Path -Parent $resolvedOutput
    [void][System.IO.Directory]::CreateDirectory($parent)
    $temporary = "$resolvedOutput.tmp-$([guid]::NewGuid().ToString('N'))"
    try {
        $json = $document | ConvertTo-Json -Depth 64
        [System.IO.File]::WriteAllText(
            $temporary,
            $json + [Environment]::NewLine,
            [System.Text.UTF8Encoding]::new($false)
        )
        $serializedDocument = Get-Content -Raw -LiteralPath $temporary |
            ConvertFrom-Json -AsHashtable -Depth 64
        $serializedValidation = Test-SporeSporeFullConformanceAttestationDocument `
            -Document $serializedDocument `
            -ExpectedSource $source `
            -ExpectedGodotIdentity $godotIdentity `
            -ExpectedPowerShellIdentity $powerShellIdentity `
            -ExpectedSourceBindings $bindings
        if (-not [bool]$serializedValidation.ok) {
            throw (
                "Serialized conformance attestation failed before publication: " +
                ($serializedValidation.failure_codes -join ", ")
            )
        }
        [System.IO.File]::Move($temporary, $resolvedOutput, $false)
    } finally {
        if (Test-Path -LiteralPath $temporary) {
            Remove-Item -LiteralPath $temporary -Force
        }
    }
    return [ordered]@{
        path = $resolvedOutput
        sha256 = Get-SporeSporeSha256 $resolvedOutput
        source_commit = [string]$source.commit
        source_tree_git_oid = [string]$source.tree_git_oid
        completed_utc = $completedUtc.ToString("o")
        physical_acceptance_authority = $false
    }
}

function Test-SporeSporeFullConformanceAttestationFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$RepoRoot,
        [Parameter(Mandatory)][string]$Godot,
        [Parameter(Mandatory)][string]$AttestationPath
    )
    try {
        $path = Assert-SporeSporeDurableAttestationOutputPath `
            -RepoRoot $RepoRoot `
            -OutputPath $AttestationPath `
            -AllowExisting
    } catch {
        return [ordered]@{
            ok = $false
            failure_codes = @("ATTESTATION_PATH_NOT_DURABLE")
            physical_acceptance_authority = $false
        }
    }
    $failures = [System.Collections.Generic.List[string]]::new()
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        return [ordered]@{
            ok = $false
            failure_codes = @("ATTESTATION_FILE_MISSING")
            physical_acceptance_authority = $false
        }
    }
    try {
        $document = Get-Content -Raw -LiteralPath $path |
            ConvertFrom-Json -AsHashtable -Depth 64
        $source = Get-SporeSporeAttestationSourceIdentity `
            -RepoRoot $RepoRoot `
            -RequireCleanPushedLive
        $godotIdentity = Get-SporeSporeAttestationGodotIdentity -Godot $Godot
        $powerShellIdentity = Get-SporeSporeAttestationPowerShellIdentity
        $bindings = @(Get-SporeSporeAttestationSourceBindings `
            -RepoRoot $RepoRoot `
            -Commit ([string]$source.commit))
        $validation = Test-SporeSporeFullConformanceAttestationDocument `
            -Document $document `
            -ExpectedSource $source `
            -ExpectedGodotIdentity $godotIdentity `
            -ExpectedPowerShellIdentity $powerShellIdentity `
            -ExpectedSourceBindings $bindings
        foreach ($failure in @($validation.failure_codes)) {
            $failures.Add([string]$failure)
        }
    } catch {
        $failures.Add("ATTESTATION_VERIFICATION_EXCEPTION")
    }
    return [ordered]@{
        ok = $failures.Count -eq 0
        failure_codes = @($failures | Sort-Object -Unique)
        path = $path
        sha256 = Get-SporeSporeSha256 $path
        physical_acceptance_authority = $false
    }
}
