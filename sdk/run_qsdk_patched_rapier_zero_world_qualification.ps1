#requires -Version 7.0

<#
.SYNOPSIS
Reusable isolated zero-world qualifier for a version-pinned Rapier patch.

.DESCRIPTION
Reads gate-specific identities from the declared contract, verifies a durable
patched dependency tree, builds through an isolated Cargo harness so the
workspace lockfile is untouched, runs the compact source audit and production
preflight, and retains an append-only receipt. It has no physical worker path.
#>

[CmdletBinding()]
param(
    [ValidateSet("development", "qualification")]
    [string]$Mode = "development",
    [string]$ContractRelativePath =
        "sdk/recovery/r24d46_rapier_exact_solver_work_observer_contract_v1.json",
    [string]$EvidenceRoot =
        "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$PSNativeCommandUseErrorActionPreference = $false
$Mode = $Mode.ToLowerInvariant()

$expectedRoot = "C:\Users\Cole\CodeStuff\games\SporeSpore"
$expectedRemote = "https://github.com/Slagathore/sporespore.git"
$expectedEvidenceRoot = "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence"
$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$evidenceRootFull = [IO.Path]::GetFullPath($EvidenceRoot)
$contractPath = Join-Path $repoRoot $ContractRelativePath
$workspaceManifest = Join-Path $repoRoot "sdk/Cargo.toml"
$lockScript = Join-Path $repoRoot "sdk/locomotion_operation_lock.ps1"
$cargo = (Get-Command cargo -CommandType Application -ErrorAction Stop).Source
$git = (Get-Command git -CommandType Application -ErrorAction Stop).Source
$python = (Get-Command python -CommandType Application -ErrorAction Stop).Source
$tar = (Get-Command tar -CommandType Application -ErrorAction Stop).Source

function Assert-PatchedRapier {
    param([bool]$Condition, [string]$Code)
    if (-not $Condition) { throw "QSDK_PATCHED_RAPIER_ZERO_WORLD:$Code" }
}

function Get-JsonPointerValue {
    param(
        [Parameter(Mandatory)][object]$Root,
        [Parameter(Mandatory)][string]$Pointer
    )
    Assert-PatchedRapier ($Pointer.StartsWith("/", [StringComparison]::Ordinal)) (
        "PREFLIGHT_EXPECTATION_POINTER_INVALID:$Pointer"
    )
    $current = $Root
    foreach ($rawSegment in $Pointer.Substring(1).Split('/')) {
        $segment = $rawSegment.Replace("~1", "/").Replace("~0", "~")
        if ($current -is [System.Collections.IDictionary]) {
            Assert-PatchedRapier ($current.Contains($segment)) (
                "PREFLIGHT_EXPECTATION_POINTER_MISSING:$Pointer"
            )
            $current = $current[$segment]
            continue
        }
        if ($current -is [System.Collections.IList]) {
            $index = 0
            Assert-PatchedRapier (
                [int]::TryParse($segment, [ref]$index) -and
                $index -ge 0 -and $index -lt $current.Count
            ) "PREFLIGHT_EXPECTATION_POINTER_INDEX_INVALID:$Pointer"
            $current = $current[$index]
            continue
        }
        Assert-PatchedRapier $false "PREFLIGHT_EXPECTATION_POINTER_SCALAR:$Pointer"
    }
    return $current
}

function Assert-JsonValueEqual {
    param(
        [object]$Observed,
        [object]$Expected,
        [Parameter(Mandatory)][string]$Code
    )
    $observedJson = ConvertTo-Json -InputObject $Observed -Depth 80 -Compress
    $expectedJson = ConvertTo-Json -InputObject $Expected -Depth 80 -Compress
    Assert-PatchedRapier ($observedJson -ceq $expectedJson) (
        "$Code`:EXPECTED=$expectedJson`:OBSERVED=$observedJson"
    )
}

function Assert-DeclaredPreflightExpectations {
    param(
        [Parameter(Mandatory)][System.Collections.IDictionary]$Preflight,
        [Parameter(Mandatory)][System.Collections.IDictionary]$Contract,
        [Parameter(Mandatory)][object[]]$Expectations
    )
    Assert-PatchedRapier ($Expectations.Count -gt 0) "PREFLIGHT_EXPECTATIONS_EMPTY"
    foreach ($expectation in $Expectations) {
        Assert-PatchedRapier (
            $expectation -is [System.Collections.IDictionary] -and
            $expectation.Contains("json_pointer")
        ) "PREFLIGHT_EXPECTATION_INVALID"
        $pointer = [string]$expectation.json_pointer
        $hasLiteral = $expectation.Contains("expected_value")
        $hasContractPointer = $expectation.Contains("expected_contract_json_pointer")
        Assert-PatchedRapier ($hasLiteral -xor $hasContractPointer) (
            "PREFLIGHT_EXPECTATION_SOURCE_INVALID:$pointer"
        )
        $expected = if ($hasLiteral) {
            $expectation.expected_value
        } else {
            Get-JsonPointerValue -Root $Contract -Pointer (
                [string]$expectation.expected_contract_json_pointer
            )
        }
        $observed = Get-JsonPointerValue -Root $Preflight -Pointer $pointer
        Assert-JsonValueEqual -Observed $observed -Expected $expected -Code (
            "PREFLIGHT_EXPECTATION_MISMATCH:$pointer"
        )
    }
}

function Get-Git {
    param([Parameter(Mandatory)][string[]]$Arguments)
    $output = @(& $git -C $repoRoot @Arguments 2>&1)
    Assert-PatchedRapier ($LASTEXITCODE -eq 0) (
        "GIT:$($Arguments -join ':'):$($output -join '|')"
    )
    return ($output -join "`n").Trim()
}

function Get-RawSha256 {
    param([Parameter(Mandatory)][string]$Path)
    return "sha256:" + (
        Get-FileHash -Algorithm SHA256 -LiteralPath $Path
    ).Hash.ToLowerInvariant()
}

function Write-TextExclusive {
    param([string]$Path, [string]$Text)
    Assert-PatchedRapier (-not (Test-Path -LiteralPath $Path)) "EVIDENCE_EXISTS:$Path"
    [IO.File]::WriteAllText($Path, $Text, [Text.UTF8Encoding]::new($false))
}

function Write-JsonExclusive {
    param([string]$Path, [object]$Value)
    Write-TextExclusive $Path (($Value | ConvertTo-Json -Depth 80 -Compress) + "`n")
}

function Invoke-Logged {
    param(
        [string]$FilePath,
        [string[]]$Arguments,
        [string]$LogPath,
        [string]$Code
    )
    $lines = @(& $FilePath @Arguments 2>&1 | ForEach-Object { [string]$_ })
    $exitCode = $LASTEXITCODE
    Write-TextExclusive $LogPath (($lines -join "`n") + "`n")
    Assert-PatchedRapier ($exitCode -eq 0) "$Code`:EXIT=$exitCode"
    return ,$lines
}

function Invoke-ExpectedFailureLogged {
    param(
        [string]$FilePath,
        [string[]]$Arguments,
        [string]$LogPath,
        [string]$ExpectedMarker,
        [string]$Code
    )
    $lines = @(& $FilePath @Arguments 2>&1 | ForEach-Object { [string]$_ })
    $exitCode = $LASTEXITCODE
    Write-TextExclusive $LogPath (($lines -join "`n") + "`n")
    Assert-PatchedRapier ($exitCode -ne 0) "$Code`:UNEXPECTED_SUCCESS"
    Assert-PatchedRapier (($lines -join "`n").Contains($ExpectedMarker)) (
        "$Code`:EXPECTED_MARKER_MISSING:$ExpectedMarker"
    )
    return ,$lines
}

Assert-PatchedRapier ($repoRoot -ceq $expectedRoot) "ROOT:$repoRoot"
Assert-PatchedRapier ($evidenceRootFull -ceq $expectedEvidenceRoot) "EVIDENCE_ROOT"
foreach ($path in @($contractPath, $workspaceManifest, $lockScript)) {
    Assert-PatchedRapier (Test-Path -LiteralPath $path -PathType Leaf) "MISSING:$path"
}
$contract = Get-Content -Raw -LiteralPath $contractPath | ConvertFrom-Json -AsHashtable
$gateId = [string]$contract.gate_id
$runner = $contract.qualification_runner
$patchProfileRunner = $null
if ($runner.Contains("patch_profile_contract_path")) {
    $patchProfilePath = [IO.Path]::GetFullPath((
        Join-Path $repoRoot ([string]$runner.patch_profile_contract_path)
    ))
    Assert-PatchedRapier (
        $patchProfilePath.StartsWith(
            $repoRoot + [IO.Path]::DirectorySeparatorChar,
            [StringComparison]::OrdinalIgnoreCase
        ) -and
        (Test-Path -LiteralPath $patchProfilePath -PathType Leaf) -and
        (Get-RawSha256 $patchProfilePath) -ceq
            [string]$runner.patch_profile_contract_raw_sha256
    ) "PATCH_PROFILE_CONTRACT"
    $patchProfile = Get-Content -Raw -LiteralPath $patchProfilePath |
        ConvertFrom-Json -AsHashtable
    Assert-PatchedRapier (
        $patchProfile.Contains("qualification_runner") -and
        $patchProfile.qualification_runner.Contains("successor_patch_sequence") -and
        $patchProfile.qualification_runner.Contains("successor_patched_files")
    ) "PATCH_PROFILE_SHAPE"
    $patchProfileRunner = $patchProfile.qualification_runner
}
$dependency = if ($contract.Contains("pinned_dependency")) {
    $contract.pinned_dependency
} elseif ($runner.Contains("pinned_dependency_contract_path")) {
    $dependencyContractPath = Join-Path $repoRoot (
        [string]$runner.pinned_dependency_contract_path
    )
    Assert-PatchedRapier (
        (Test-Path -LiteralPath $dependencyContractPath -PathType Leaf) -and
        (Get-RawSha256 $dependencyContractPath) -ceq
            [string]$runner.pinned_dependency_contract_raw_sha256
    ) "PINNED_DEPENDENCY_CONTRACT"
    $dependencyContract = Get-Content -Raw -LiteralPath $dependencyContractPath |
        ConvertFrom-Json -AsHashtable
    Assert-PatchedRapier ($dependencyContract.Contains("pinned_dependency")) (
        "PINNED_DEPENDENCY_MISSING"
    )
    $dependencyContract.pinned_dependency
} else {
    throw "QSDK_PATCHED_RAPIER_ZERO_WORLD:PINNED_DEPENDENCY_AUTHORITY_MISSING"
}
$observer = if ($contract.Contains("observer_semantics")) {
    $contract.observer_semantics
} else { $null }
$zeroWorld = $contract.complete_zero_world_gate
$auditPath = Join-Path $repoRoot ([string]$runner.audit_path)
$patchPath = Join-Path $repoRoot ([string]$dependency.patch_path)
foreach ($path in @($auditPath, $patchPath)) {
    Assert-PatchedRapier (Test-Path -LiteralPath $path -PathType Leaf) "MISSING:$path"
}
$successorPatches = @()
$successorPatchedFiles = @()
$patchDeclarationRunner = if ($runner.Contains("successor_patch_sequence")) {
    $runner
} elseif ($null -ne $patchProfileRunner) { $patchProfileRunner } else { $runner }
if ($patchDeclarationRunner.Contains("successor_patch_sequence")) {
    $seenSuccessorPatchIds = @{}
    $seenSuccessorPatchPaths = @{}
    foreach ($declaredPatch in @($patchDeclarationRunner.successor_patch_sequence)) {
        Assert-PatchedRapier (
            $declaredPatch -is [System.Collections.IDictionary] -and
            $declaredPatch.Contains("id") -and
            $declaredPatch.Contains("path") -and
            $declaredPatch.Contains("byte_length") -and
            $declaredPatch.Contains("raw_sha256")
        ) "SUCCESSOR_PATCH_DECLARATION_INVALID"
        $patchId = [string]$declaredPatch.id
        $patchRelativePath = [string]$declaredPatch.path
        $patchByteLength = [long]$declaredPatch.byte_length
        $patchRawSha256 = [string]$declaredPatch.raw_sha256
        Assert-PatchedRapier ($patchId -cmatch '^[a-z0-9-]+$') (
            "SUCCESSOR_PATCH_ID_INVALID:$patchId"
        )
        Assert-PatchedRapier (
            -not $seenSuccessorPatchIds.ContainsKey($patchId) -and
            -not $seenSuccessorPatchPaths.ContainsKey($patchRelativePath)
        ) "SUCCESSOR_PATCH_DUPLICATE:$patchId`:$patchRelativePath"
        $successorPatchPath = [IO.Path]::GetFullPath((
            Join-Path $repoRoot $patchRelativePath
        ))
        Assert-PatchedRapier (
            $successorPatchPath.StartsWith(
                $repoRoot + [IO.Path]::DirectorySeparatorChar,
                [StringComparison]::OrdinalIgnoreCase
            ) -and
            (Test-Path -LiteralPath $successorPatchPath -PathType Leaf) -and
            (Get-Item -LiteralPath $successorPatchPath).Length -eq $patchByteLength -and
            (Get-RawSha256 $successorPatchPath) -ceq $patchRawSha256
        ) "SUCCESSOR_PATCH_BINDING:$patchId"
        $seenSuccessorPatchIds[$patchId] = $true
        $seenSuccessorPatchPaths[$patchRelativePath] = $true
        $successorPatches += [ordered]@{
            id = $patchId
            path = $patchRelativePath.Replace("\", "/")
            byte_length = $patchByteLength
            raw_sha256 = $patchRawSha256
            resolved_path = $successorPatchPath
        }
    }
    Assert-PatchedRapier ($successorPatches.Count -gt 0) "SUCCESSOR_PATCH_SEQUENCE_EMPTY"
}
if ($patchDeclarationRunner.Contains("successor_patched_files")) {
    $seenSuccessorPatchedPaths = @{}
    foreach ($declaredFile in @($patchDeclarationRunner.successor_patched_files)) {
        Assert-PatchedRapier (
            $declaredFile -is [System.Collections.IDictionary] -and
            $declaredFile.Contains("path") -and
            $declaredFile.Contains("byte_length") -and
            $declaredFile.Contains("raw_sha256")
        ) "SUCCESSOR_PATCHED_FILE_DECLARATION_INVALID"
        $fileRelativePath = [string]$declaredFile.path
        Assert-PatchedRapier (-not $seenSuccessorPatchedPaths.ContainsKey($fileRelativePath)) (
            "SUCCESSOR_PATCHED_FILE_DUPLICATE:$fileRelativePath"
        )
        $seenSuccessorPatchedPaths[$fileRelativePath] = $true
        $successorPatchedFiles += [ordered]@{
            path = $fileRelativePath.Replace("\", "/")
            byte_length = [long]$declaredFile.byte_length
            raw_sha256 = [string]$declaredFile.raw_sha256
        }
    }
}
Assert-PatchedRapier (
    ($successorPatches.Count -eq 0 -and $successorPatchedFiles.Count -eq 0) -or
    ($successorPatches.Count -gt 0 -and $successorPatchedFiles.Count -gt 0)
) "SUCCESSOR_PATCH_SEQUENCE_AND_BINDINGS_MUST_COINCIDE"
Assert-PatchedRapier (
    [string]$contract.question_class -ceq "development" -and
    (
        -not [bool]$contract.physical_question_declared -or
        (
            $contract.complete_zero_world_gate.Contains(
                "prospectively_declared_physical_question_permitted"
            ) -and
            [bool]$contract.complete_zero_world_gate.
                prospectively_declared_physical_question_permitted
        )
    ) -and
    [bool]$contract.complete_zero_world_gate.must_pass_before_physics -and
    [int]$contract.complete_zero_world_gate.world_build_count -eq 0 -and
    [long]$contract.complete_zero_world_gate.solver_step_count -eq 0 -and
    -not [bool]$contract.complete_zero_world_gate.physical_execution_authorized -and
    [long]$contract.complete_zero_world_gate.maximum_physical_steps_authorized -eq 0
) "CONTRACT"
$registryCache = Join-Path ([Environment]::GetFolderPath("UserProfile")) ".cargo/registry/cache"
$archiveCandidates = @(Get-ChildItem -Path $registryCache -Recurse -File `
    -Filter ([string]$dependency.registry_archive_file_name) | Where-Object {
        $_.Length -eq [long]$dependency.registry_archive_byte_length -and
        (Get-RawSha256 $_.FullName).Substring(7) -ceq [string]$dependency.cargo_registry_checksum
    })
Assert-PatchedRapier ($archiveCandidates.Count -eq 1) (
    "REGISTRY_ARCHIVE_COUNT:$($archiveCandidates.Count)"
)
$registryArchive = $archiveCandidates[0].FullName

$root = [IO.Path]::GetFullPath((Get-Git @("rev-parse", "--show-toplevel")))
$remote = Get-Git @("remote", "get-url", "origin")
$branch = Get-Git @("branch", "--show-current")
$head = Get-Git @("rev-parse", "HEAD")
$tracking = Get-Git @("rev-parse", "origin/main")
$status = Get-Git @("status", "--short")
$worktreeCount = @((Get-Git @("worktree", "list", "--porcelain")) -split "`r?`n" |
    Where-Object { $_.StartsWith("worktree ", [StringComparison]::Ordinal) }).Count
Assert-PatchedRapier ($root -ceq $expectedRoot -and $remote -ceq $expectedRemote) "IDENTITY"
Assert-PatchedRapier ($worktreeCount -eq 1) "WORKTREE_COUNT:$worktreeCount"
$live = $null
if ($Mode -ceq "qualification") {
    $live = (Get-Git @("ls-remote", "origin", "refs/heads/main")).Split("`t")[0]
    Assert-PatchedRapier (
        $branch -ceq "main" -and [string]::IsNullOrEmpty($status) -and
        $head -ceq $tracking -and $head -ceq $live
    ) "SOURCE_NOT_CLEAN_PUSHED_EQUAL"
    $prior = @(Get-ChildItem -LiteralPath $evidenceRootFull -Directory |
        Where-Object { $_.Name -like "$($runner.qualification_directory_prefix)*" } |
        Where-Object {
            $attempt = Join-Path $_.FullName "qualification_attempt.json"
            if (-not (Test-Path -LiteralPath $attempt -PathType Leaf)) { return $false }
            $value = Get-Content -Raw -LiteralPath $attempt | ConvertFrom-Json
            return [string]$value.gate_id -ceq $gateId -and
                [string]$value.source_commit -ceq $head
        })
    Assert-PatchedRapier ($prior.Count -eq 0) "EXACT_SOURCE_ALREADY_ATTEMPTED"
}

. $lockScript
$lock = $null
$lockPublic = $null
$runRoot = $null
$caught = $null
$preflight = $null
$sourceManifest = $null
$toolchain = $null
$checks = [ordered]@{}
$previousTarget = $env:CARGO_TARGET_DIR
try {
    $lock = Enter-SporeSporeLocomotionOperationLock -Role conformance
    Assert-PatchedRapier (
        [bool]$lock.acquired -and -not [bool]$lock.test_only -and
        -not [bool]$lock.abandoned_owner_recovered
    ) "OPERATION_LOCK"
    $lockPublic = Get-SporeSporeLocomotionOperationLockPublicReceipt $lock
    Assert-PatchedRapier ((Get-Git @("rev-parse", "HEAD")) -ceq $head) "HEAD_DRIFT"
    Assert-PatchedRapier ((Get-Git @("status", "--short")) -ceq $status) "STATUS_DRIFT"

    $timestamp = [DateTime]::UtcNow.ToString("yyyyMMddTHHmmssfffZ")
    $prefix = if ($Mode -ceq "qualification") {
        [string]$runner.qualification_directory_prefix
    } else { [string]$runner.development_directory_prefix }
    $runRoot = Join-Path $evidenceRootFull "$prefix$timestamp-$($head.Substring(0, 8))"
    New-Item -ItemType Directory -Path $runRoot -ErrorAction Stop | Out-Null
    $attemptName = if ($Mode -ceq "qualification") {
        "qualification_attempt.json"
    } else { "development_attempt.json" }
    Write-JsonExclusive (Join-Path $runRoot $attemptName) ([ordered]@{
        schema_version = [string]$runner.attempt_schema
        gate_id = $gateId
        mode = $Mode
        started_utc = [DateTime]::UtcNow.ToString("o")
        source_commit = $head
        branch = $branch
        remote = $remote
        upstream_commit = $tracking
        live_remote_commit = $live
        worktree_clean_at_start = [string]::IsNullOrEmpty($status)
        operation_lock = $lockPublic
        model_construction_count = 0
        world_attempt_count = 0
        world_build_count = 0
        solver_step_count = 0
        physics_state_modified = $false
        physical_question_opened = $false
        physical_acceptance_authority = $false
        release_authority = $false
    })

    $dependencyParent = Join-Path $runRoot "isolated-dependency"
    New-Item -ItemType Directory -Path $dependencyParent -ErrorAction Stop | Out-Null
    Invoke-Logged $tar @(
        "-xf", $registryArchive, "-C", $dependencyParent
    ) (Join-Path $runRoot "00a-registry-archive-extract.log") "ARCHIVE_EXTRACT" | Out-Null
    $patchedRoot = Join-Path $dependencyParent (
        [string]$dependency.fresh_extract_directory_name
    )
    Assert-PatchedRapier (Test-Path -LiteralPath $patchedRoot -PathType Container) (
        "FRESH_EXTRACT_MISSING:$patchedRoot"
    )
    Invoke-Logged $git @(
        "-c", "core.autocrlf=false", "-C", $patchedRoot,
        "apply", "--check", $patchPath
    ) (Join-Path $runRoot "00b-patch-check.log") "PATCH_CHECK" | Out-Null
    Invoke-Logged $git @(
        "-c", "core.autocrlf=false", "-C", $patchedRoot,
        "apply", $patchPath
    ) (Join-Path $runRoot "00c-patch-application.log") "PATCH_APPLICATION" | Out-Null
    foreach ($binding in @($dependency.upstream_and_patched_files)) {
        $path = Join-Path $patchedRoot ([string]$binding.path)
        Assert-PatchedRapier (
            (Test-Path -LiteralPath $path -PathType Leaf) -and
            (Get-Item -LiteralPath $path).Length -eq [long]$binding.patched_byte_length -and
            (Get-RawSha256 $path) -ceq [string]$binding.patched_raw_sha256
        ) "PATCHED_DEPENDENCY_BINDING:$($binding.path)"
    }
    $checks.fresh_registry_archive_patched_and_bound = $true
    for ($patchIndex = 0; $patchIndex -lt $successorPatches.Count; $patchIndex++) {
        $successorPatch = $successorPatches[$patchIndex]
        $sequenceNumber = "{0:D2}" -f ($patchIndex + 1)
        $logStem = "00d-successor-$sequenceNumber-$($successorPatch.id)"
        Invoke-Logged $git @(
            "-c", "core.autocrlf=false", "-C", $patchedRoot,
            "apply", "--check", [string]$successorPatch.resolved_path
        ) (Join-Path $runRoot "$logStem-check.log") (
            "SUCCESSOR_PATCH_CHECK:$($successorPatch.id)"
        ) | Out-Null
        Invoke-Logged $git @(
            "-c", "core.autocrlf=false", "-C", $patchedRoot,
            "apply", [string]$successorPatch.resolved_path
        ) (Join-Path $runRoot "$logStem-application.log") (
            "SUCCESSOR_PATCH_APPLICATION:$($successorPatch.id)"
        ) | Out-Null
    }
    foreach ($binding in $successorPatchedFiles) {
        $path = Join-Path $patchedRoot ([string]$binding.path)
        Assert-PatchedRapier (
            (Test-Path -LiteralPath $path -PathType Leaf) -and
            (Get-Item -LiteralPath $path).Length -eq [long]$binding.byte_length -and
            (Get-RawSha256 $path) -ceq [string]$binding.raw_sha256
        ) "SUCCESSOR_PATCHED_DEPENDENCY_BINDING:$($binding.path)"
    }
    if ($successorPatches.Count -gt 0) {
        $checks.successor_patch_sequence_applied_and_bound = $true
    }

    $harness = Join-Path $runRoot "isolated-harness"
    $harnessSource = Join-Path $harness "src"
    New-Item -ItemType Directory -Path $harnessSource -ErrorAction Stop | Out-Null
    $adapterPath = (Join-Path $repoRoot "sdk/adapters/rapier").Replace("\", "/")
    $patchedPath = $patchedRoot.Replace("\", "/")
    $manifest = @"
[package]
name = "$($runner.isolated_harness_package)"
version = "0.0.0"
edition = "2024"
publish = false

[workspace]

[dependencies]
rapier3d = { version = "=$($dependency.version)", features = ["$($runner.patched_dependency_feature)"] }
serde_json = "=$($runner.serde_json_version)"
sporespore-rapier-adapter = { path = "$adapterPath", features = ["$($runner.adapter_feature)"] }

[patch.crates-io]
rapier3d = { path = "$patchedPath" }
"@
    $main = @"
fn main() {
    let receipt = sporespore_rapier_adapter::$($runner.preflight_entrypoint)()
        .expect("patched Rapier zero-world preflight must pass");
    println!(
        "$($runner.preflight_terminal_marker){}",
        serde_json::to_string(&receipt).expect("receipt must serialize")
    );
}
"@
    Write-TextExclusive (Join-Path $harness "Cargo.toml") $manifest
    Write-TextExclusive (Join-Path $harnessSource "main.rs") $main
    $env:CARGO_TARGET_DIR = Join-Path $evidenceRootFull (
        "build-cache/patched-rapier-zero-world/$head"
    )

    $auditArguments = @($auditPath)
    if ($runner.Contains("audit_accepts_contract_path") -and
        [bool]$runner.audit_accepts_contract_path) {
        $auditArguments += @("--contract", $contractPath)
    }
    $auditOutput = Invoke-Logged $python $auditArguments (
        Join-Path $runRoot "01-source-audit.log"
    ) "SOURCE_AUDIT"
    Assert-PatchedRapier (($auditOutput -join "`n").Contains(
        [string]$runner.audit_pass_marker
    )) "SOURCE_AUDIT_MARKER"
    $checks.source_contract_audit_passed = $true

    Invoke-Logged $cargo @(
        "check", "--locked", "--offline", "-p", [string]$runner.adapter_package,
        "--manifest-path", $workspaceManifest
    ) (Join-Path $runRoot "02-stock-adapter-check.log") "STOCK_ADAPTER_CHECK" | Out-Null
    $checks.stock_adapter_check_passed = $true

    if ($runner.Contains("workspace_zero_world_tests")) {
        foreach ($test in @($runner.workspace_zero_world_tests)) {
            $testId = [string]$test.id
            $testPackage = [string]$test.package
            $testFilter = [string]$test.filter
            Assert-PatchedRapier (
                $testId -cmatch '^[a-z0-9-]+$' -and
                -not [string]::IsNullOrWhiteSpace($testPackage) -and
                -not [string]::IsNullOrWhiteSpace($testFilter)
            ) "WORKSPACE_ZERO_WORLD_TEST_DECLARATION:$testId"
            Invoke-Logged $cargo @(
                "test", "--locked", "--offline", "-p", $testPackage,
                "--manifest-path", $workspaceManifest, $testFilter, "--", "--nocapture"
            ) (Join-Path $runRoot "02-test-$testId.log") (
                "WORKSPACE_ZERO_WORLD_TEST:$testId"
            ) | Out-Null
            $checks["workspace_zero_world_test_$($testId.Replace('-', '_'))"] = $true
        }
    }

    $harnessManifest = Join-Path $harness "Cargo.toml"
    Invoke-Logged $cargo @(
        "check", "--offline", "--manifest-path", $harnessManifest
    ) (Join-Path $runRoot "03-isolated-patched-check.log") "PATCHED_CHECK" | Out-Null
    $checks.isolated_patched_rapier_and_adapter_check_passed = $true

    $refusalRunner = if ($runner.Contains("expected_compile_refusals")) {
        $runner
    } elseif ($null -ne $patchProfileRunner) { $patchProfileRunner } else { $runner }
    if ($refusalRunner.Contains("expected_compile_refusals")) {
        foreach ($refusal in @($refusalRunner.expected_compile_refusals)) {
            $refusalId = [string]$refusal.id
            Assert-PatchedRapier ($refusalId -cmatch '^[a-z0-9-]+$') (
                "COMPILE_REFUSAL_ID_INVALID:$refusalId"
            )
            $features = @($refusal.features | ForEach-Object { [string]$_ })
            Assert-PatchedRapier ($features.Count -gt 0) (
                "COMPILE_REFUSAL_FEATURES_EMPTY:$refusalId"
            )
            Invoke-ExpectedFailureLogged $cargo @(
                "check", "--offline", "--manifest-path", (Join-Path $patchedRoot "Cargo.toml"),
                "--features", ($features -join ",")
            ) (Join-Path $runRoot "03-refusal-$refusalId.log") (
                [string]$refusal.expected_marker
            ) "COMPILE_REFUSAL:$refusalId" | Out-Null
            $checks["expected_compile_refusal_$($refusalId.Replace('-', '_'))"] = $true
        }
    }

    $preflightOutput = Invoke-Logged $cargo @(
        "run", "--locked", "--offline", "--manifest-path", $harnessManifest
    ) (Join-Path $runRoot "04-production-preflight.log") "PRODUCTION_PREFLIGHT"
    $markers = @($preflightOutput | Where-Object {
        $_.StartsWith([string]$runner.preflight_terminal_marker, [StringComparison]::Ordinal)
    })
    Assert-PatchedRapier ($markers.Count -eq 1) "PREFLIGHT_MARKER_COUNT:$($markers.Count)"
    $preflight = $markers[0].Substring(
        ([string]$runner.preflight_terminal_marker).Length
    ) | ConvertFrom-Json -AsHashtable -Depth 80
    foreach ($commonExpectation in @(
        @{ json_pointer = "/ok"; expected_value = $true },
        @{ json_pointer = "/gate_id"; expected_value = $gateId },
        @{ json_pointer = "/world_build_count"; expected_value = 0 },
        @{ json_pointer = "/solver_step_count"; expected_value = 0 },
        @{ json_pointer = "/physics_state_modified"; expected_value = $false },
        @{ json_pointer = "/physical_acceptance_authority"; expected_value = $false },
        @{ json_pointer = "/release_authority"; expected_value = $false }
    )) {
        Assert-JsonValueEqual `
            -Observed (Get-JsonPointerValue -Root $preflight -Pointer $commonExpectation.json_pointer) `
            -Expected $commonExpectation.expected_value `
            -Code "PREFLIGHT_COMMON_INVARIANT:$($commonExpectation.json_pointer)"
    }
    if ($runner.Contains("preflight_expectations")) {
        Assert-DeclaredPreflightExpectations `
            -Preflight $preflight `
            -Contract $contract `
            -Expectations @($runner.preflight_expectations)
        $checks.contract_declared_preflight_expectations_passed = $true
    } else {
        Assert-PatchedRapier (
            [int]$preflight.expected_small_step_count -eq
                [int]$observer.active_solver_small_steps -and
            [int]$preflight.expected_applications_per_small_step -eq
                [int]$observer.active_applications_per_small_step -and
            [int]$preflight.expected_application_count -eq
                [int]$observer.active_applications_per_outer_step -and
            [int]$preflight.mutation_rejection_count -eq
                [int]$zeroWorld.collector_mutation_rejection_count -and
            [bool]$preflight.unmeasured_energy_channels_typed_refused -and
            -not [bool]$preflight.complete_energy_partition_claimed -and
            -not [bool]$preflight.physical_execution_authorized
        ) "PREFLIGHT_RECEIPT_LEGACY_R24D46"
        $checks.legacy_preflight_expectations_passed = $true
    }
    $checks.production_preflight_passed = $true

    $sourceManifest = @($contract.source_inventory | ForEach-Object {
        $relative = [string]$_
        $path = Join-Path $repoRoot $relative
        Assert-PatchedRapier (
            Test-Path -LiteralPath $path -PathType Leaf
        ) "SOURCE_MISSING:$relative"
        $blobOid = if ($Mode -ceq "qualification") {
            Get-Git @("rev-parse", "$head`:$relative")
        } else {
            Get-Git @("hash-object", "--", $relative)
        }
        [ordered]@{
            path = $relative.Replace("\", "/")
            raw_sha256 = Get-RawSha256 $path
            byte_length = (Get-Item -LiteralPath $path).Length
            git_blob_oid = $blobOid
            git_blob_committed = $Mode -ceq "qualification"
        }
    })
    $checks.source_manifest_bound = $true
    $toolchain = [ordered]@{
        rustc = (& rustc --version).Trim()
        cargo = (& $cargo --version).Trim()
        python = (& $python --version 2>&1).Trim()
        powershell = [string]$PSVersionTable.PSVersion
    }
    Assert-PatchedRapier ((Get-Git @("status", "--short")) -ceq $status) "WORKTREE_DRIFT"
    Assert-PatchedRapier ((Get-Git @("rev-parse", "HEAD")) -ceq $head) "FINAL_HEAD_DRIFT"
    $checks.worktree_unchanged = $true
    $checks.source_commit_unchanged = $true
    if ($Mode -ceq "qualification") {
        $finalLive = (Get-Git @("ls-remote", "origin", "refs/heads/main")).Split("`t")[0]
        Assert-PatchedRapier ($finalLive -ceq $live) "LIVE_REMOTE_DRIFT"
        $checks.live_remote_unchanged = $true
    }
} catch {
    $caught = $_
} finally {
    $env:CARGO_TARGET_DIR = $previousTarget
    if ($null -ne $lock -and [bool]$lock.acquired -and -not [bool]$lock.released) {
        Exit-SporeSporeLocomotionOperationLock -Receipt $lock
    }
}

if ($null -ne $caught) {
    if ($null -ne $runRoot) {
        $failureName = if ($Mode -ceq "qualification") {
            "qualification_failure.json"
        } else { "development_failure.json" }
        Write-JsonExclusive (Join-Path $runRoot $failureName) ([ordered]@{
            schema_version = [string]$runner.failure_schema
            gate_id = $gateId
            mode = $Mode
            failed_utc = [DateTime]::UtcNow.ToString("o")
            source_commit = $head
            error = [string]$caught.Exception.Message
            completed_checks = $checks
            operation_lock_released = $null -ne $lock -and [bool]$lock.released
            model_construction_count = 0
            world_attempt_count = 0
            world_build_count = 0
            solver_step_count = 0
            physics_state_modified = $false
            physical_question_opened = $false
            physical_acceptance_authority = $false
            release_authority = $false
        })
    }
    throw $caught
}
try {
$receipt = [ordered]@{
    schema_version = [string]$runner.receipt_schema
    gate_id = $gateId
    mode = $Mode
    completed_utc = [DateTime]::UtcNow.ToString("o")
    ok = $true
    source_commit = $head
    branch = $branch
    remote = $remote
    upstream_commit = $tracking
    live_remote_commit = $live
    contract_path = $ContractRelativePath.Replace("\", "/")
    contract_raw_sha256 = Get-RawSha256 $contractPath
    patch_raw_sha256 = Get-RawSha256 $patchPath
    registry_archive = [ordered]@{
        path = $registryArchive.Replace("\", "/")
        raw_sha256 = Get-RawSha256 $registryArchive
        byte_length = (Get-Item -LiteralPath $registryArchive).Length
    }
    patched_dependency_root = $patchedRoot.Replace("\", "/")
    patched_dependency_files = @($dependency.upstream_and_patched_files | ForEach-Object {
        [ordered]@{
            path = [string]$_.path
            raw_sha256 = [string]$_.patched_raw_sha256
            byte_length = [long]$_.patched_byte_length
        }
    })
    isolated_harness_cargo_lock = [ordered]@{
        path = "isolated-harness/Cargo.lock"
        raw_sha256 = Get-RawSha256 (Join-Path $harness "Cargo.lock")
        byte_length = (Get-Item -LiteralPath (Join-Path $harness "Cargo.lock")).Length
    }
    source_manifest = $sourceManifest
    source_manifest_raw_representation = "observed_checkout_plus_git_blob"
    toolchain = $toolchain
    operation_lock = $lockPublic
    operation_lock_released = [bool]$lock.released
    checks = $checks
    production_preflight = $preflight
    held_out_cell_access_count = 0
    held_out_selector_invocation_count = 0
    model_construction_count = 0
    world_attempt_count = 0
    world_build_count = 0
    solver_step_count = 0
    physics_state_modified = $false
    physical_question_opened = $false
    controller_physical_viability_proven = $false
    prone_to_standing_claimed = $false
    physical_acceptance_authority = $false
    release_authority = $false
}
if ($successorPatches.Count -gt 0) {
    $receipt.successor_patch_sequence = @($successorPatches | ForEach-Object {
        [ordered]@{
            id = [string]$_.id
            path = [string]$_.path
            raw_sha256 = [string]$_.raw_sha256
            byte_length = [long]$_.byte_length
        }
    })
    $receipt.successor_patched_dependency_files = @($successorPatchedFiles | ForEach-Object {
        [ordered]@{
            path = [string]$_.path
            raw_sha256 = [string]$_.raw_sha256
            byte_length = [long]$_.byte_length
        }
    })
}
$receiptName = if ($Mode -ceq "qualification") {
    "qualification_receipt.json"
} else { "development_receipt.json" }
$receiptPath = Join-Path $runRoot $receiptName
Write-JsonExclusive $receiptPath $receipt
Write-Output (
    "$($gateId.Replace('-', '_'))_PATCHED_RAPIER_ZERO_WORLD_PASS " +
    "mode=$Mode source=$head worlds=0 solver_steps=0 receipt=$receiptPath"
)
} catch {
    $finalizationError = $_
    $failureName = if ($Mode -ceq "qualification") {
        "qualification_failure.json"
    } else { "development_failure.json" }
    $failurePath = Join-Path $runRoot $failureName
    if (-not (Test-Path -LiteralPath $failurePath)) {
        Write-JsonExclusive $failurePath ([ordered]@{
            schema_version = [string]$runner.failure_schema
            gate_id = $gateId
            mode = $Mode
            failed_utc = [DateTime]::UtcNow.ToString("o")
            source_commit = $head
            error = [string]$finalizationError.Exception.Message
            completed_checks = $checks
            operation_lock_released = $null -ne $lock -and [bool]$lock.released
            model_construction_count = 0
            world_attempt_count = 0
            world_build_count = 0
            solver_step_count = 0
            physics_state_modified = $false
            physical_question_opened = $false
            physical_acceptance_authority = $false
            release_authority = $false
        })
    }
    throw $finalizationError
}
