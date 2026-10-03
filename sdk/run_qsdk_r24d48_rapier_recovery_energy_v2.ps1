#requires -Version 7.0

<#
.SYNOPSIS
Runs one prospectively bounded R24D48 Rapier physical stage.

.DESCRIPTION
The integration ghost and paired development attempt share this launcher. It
requires a clean pushed live-equal checkout, a closed content-addressed
zero-world qualification, unchanged qualified physical code, and the exact
retained patched Rapier tree qualified by that closure. Development additionally
requires either the historical ghost authority path or an explicitly bound,
content-addressed predecessor integration closure. Every attempt is retained.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateSet("Ghost", "Development")]
    [string]$Mode,
    [string]$ContractRelativePath =
        "sdk/recovery/r24d48_rapier_recovery_energy_v2_contract_v1.json",
    [string]$StageAuthorityContractRelativePath = "",
    [string]$StageAuthorityContractRawSha256 = "",
    [switch]$AuthorityRouteProbe,
    [string]$EvidenceRoot =
        "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$PSNativeCommandUseErrorActionPreference = $false
$Mode = switch ($Mode.ToLowerInvariant()) {
    "ghost" { "Ghost" }
    "development" { "Development" }
    default { throw "QSDK_R24D48_PHYSICAL:MODE_NORMALIZATION" }
}

$expectedRoot = "C:\Users\Cole\CodeStuff\games\SporeSpore"
$expectedRemote = "https://github.com/Slagathore/sporespore.git"
$expectedEvidenceRoot = "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence"
$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$evidenceRootFull = [IO.Path]::GetFullPath($EvidenceRoot)
$contractPath = Join-Path $repoRoot $ContractRelativePath
$lockScript = Join-Path $repoRoot "sdk/locomotion_operation_lock.ps1"
$cargo = (Get-Command cargo -CommandType Application -ErrorAction Stop).Source
$git = (Get-Command git -CommandType Application -ErrorAction Stop).Source

function Assert-R24D48 {
    param([bool]$Condition, [string]$Code)
    if (-not $Condition) { throw "QSDK_R24D48_PHYSICAL:$Code" }
}

function Get-Git {
    param([Parameter(Mandatory)][string[]]$Arguments)
    $output = @(& $git -C $repoRoot @Arguments 2>&1)
    Assert-R24D48 ($LASTEXITCODE -eq 0) (
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

function Get-TextSha256 {
    param([Parameter(Mandatory)][string]$Text)
    $bytes = [Text.UTF8Encoding]::new($false).GetBytes($Text)
    $hash = [Security.Cryptography.SHA256]::HashData($bytes)
    return "sha256:" + [Convert]::ToHexString($hash).ToLowerInvariant()
}

function Get-RepositoryTextSha256 {
    param([Parameter(Mandatory)][string]$Path)
    $text = [IO.File]::ReadAllText($Path).Replace("`r`n", "`n")
    return Get-TextSha256 $text
}

function Get-JsonPointerValue {
    param([object]$Root, [string]$Pointer)
    Assert-R24D48 ($Pointer.StartsWith("/", [StringComparison]::Ordinal)) (
        "JSON_POINTER_INVALID:$Pointer"
    )
    $current = $Root
    foreach ($rawSegment in $Pointer.Substring(1).Split('/')) {
        $segment = $rawSegment.Replace("~1", "/").Replace("~0", "~")
        Assert-R24D48 (
            $current -is [System.Collections.IDictionary] -and
            $current.Contains($segment)
        ) "JSON_POINTER_MISSING:$Pointer"
        $current = $current[$segment]
    }
    return $current
}

function Write-TextExclusive {
    param([string]$Path, [string]$Text)
    Assert-R24D48 (-not (Test-Path -LiteralPath $Path)) "EVIDENCE_EXISTS:$Path"
    [IO.File]::WriteAllText($Path, $Text, [Text.UTF8Encoding]::new($false))
}

function Write-JsonExclusive {
    param([string]$Path, [object]$Value)
    Write-TextExclusive $Path (($Value | ConvertTo-Json -Depth 100 -Compress) + "`n")
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
    Assert-R24D48 ($exitCode -eq 0) "$Code`:EXIT=$exitCode"
    return ,$lines
}

foreach ($path in @($contractPath, $lockScript)) {
    Assert-R24D48 (Test-Path -LiteralPath $path -PathType Leaf) "MISSING:$path"
}
Assert-R24D48 ($repoRoot -ceq $expectedRoot) "ROOT:$repoRoot"
Assert-R24D48 ($evidenceRootFull -ceq $expectedEvidenceRoot) "EVIDENCE_ROOT"
$contract = Get-Content -Raw -LiteralPath $contractPath | ConvertFrom-Json -AsHashtable
$runner = $contract.physical_runner
$developmentRequiresPriorGhost = if ($runner.Contains("development_requires_prior_ghost")) {
    [bool]$runner.development_requires_prior_ghost
} else { $true }
$qualificationRunner = $contract.qualification_runner
$patchProfileRunner = $null
if ($qualificationRunner.Contains("patch_profile_contract_path")) {
    $patchProfilePath = [IO.Path]::GetFullPath((
        Join-Path $repoRoot ([string]$qualificationRunner.patch_profile_contract_path)
    ))
    Assert-R24D48 (
        $patchProfilePath.StartsWith(
            $repoRoot + [IO.Path]::DirectorySeparatorChar,
            [StringComparison]::OrdinalIgnoreCase
        ) -and
        (Test-Path -LiteralPath $patchProfilePath -PathType Leaf) -and
        (Get-RawSha256 $patchProfilePath) -ceq
            [string]$qualificationRunner.patch_profile_contract_raw_sha256
    ) "PATCH_PROFILE_CONTRACT"
    $patchProfile = Get-Content -Raw -LiteralPath $patchProfilePath |
        ConvertFrom-Json -AsHashtable
    Assert-R24D48 ($patchProfile.Contains("qualification_runner")) "PATCH_PROFILE_SHAPE"
    $patchProfileRunner = $patchProfile.qualification_runner
}
$gateId = [string]$contract.gate_id
$gateCacheId = $gateId.ToLowerInvariant().Replace("-", "")
$closureStatus = if ($runner.Contains("qualification_closure_status")) {
    [string]$runner.qualification_closure_status
} else {
    "closed_complete_zero_world_rapier_recovery_energy_v2_qualified_physics_staged"
}
$runtimeBindingField = if ($runner.Contains("runtime_binding_result_field")) {
    [string]$runner.runtime_binding_result_field
} else { "runtime_qualification_sha256" }
$ghostResultShape = if ($runner.Contains("ghost_result_shape")) {
    [string]$runner.ghost_result_shape
} else { "paired_candidate_matched_zero_v1" }
$physicalPassMarker = if ($runner.Contains("physical_pass_marker")) {
    [string]$runner.physical_pass_marker
} else { "QSDK_R24D48_RAPIER_RECOVERY_ENERGY_V2_PHYSICAL_PASS" }
$closurePath = Join-Path $repoRoot ([string]$runner.qualification_closure_path)
Assert-R24D48 (Test-Path -LiteralPath $closurePath -PathType Leaf) "QUALIFICATION_CLOSURE_MISSING"
$closure = Get-Content -Raw -LiteralPath $closurePath | ConvertFrom-Json -AsHashtable
Assert-R24D48 (
    $gateId -cmatch '^QSDK-R24D[0-9]+$' -and
    [string]$contract.question_class -ceq "development" -and
    [bool]$contract.physical_question_declared -and
    [string]$closure.gate_id -ceq $gateId -and
    [string]$closure.closure_status -ceq $closureStatus -and
    [bool]$runner.qualification_harness_cargo_lock_reused_exactly -and
    [bool]$runner.locked_dependency_resolution_required
) "AUTHORITY"
Assert-R24D48 (
    $Mode -cne "Development" -or
    -not ($runner.Contains("development_disabled") -and [bool]$runner.development_disabled)
) "DEVELOPMENT_DISABLED"
Assert-R24D48 (
    $Mode -cne "Ghost" -or
    -not ($runner.Contains("ghost_disabled") -and [bool]$runner.ghost_disabled)
) "GHOST_DISABLED"
if ($runner.Contains("qualification_claim_json_pointer")) {
    Assert-R24D48 (
        [bool](Get-JsonPointerValue -Root $closure -Pointer (
            [string]$runner.qualification_claim_json_pointer
        ))
    ) "QUALIFICATION_CLAIM"
}
if ($runner.Contains("unexercised_claim_json_pointer")) {
    Assert-R24D48 (
        -not [bool](Get-JsonPointerValue -Root $closure -Pointer (
            [string]$runner.unexercised_claim_json_pointer
        ))
    ) "UNEXERCISED_CLAIM"
}

$root = [IO.Path]::GetFullPath((Get-Git @("rev-parse", "--show-toplevel")))
$remote = Get-Git @("remote", "get-url", "origin")
$branch = Get-Git @("branch", "--show-current")
$head = Get-Git @("rev-parse", "HEAD")
$tracking = Get-Git @("rev-parse", "origin/main")
$live = (Get-Git @("ls-remote", "origin", "refs/heads/main")).Split("`t")[0]
$status = Get-Git @("status", "--short")
Assert-R24D48 (
    $root -ceq $expectedRoot -and $remote -ceq $expectedRemote -and
    $branch -ceq "main" -and [string]::IsNullOrEmpty($status) -and
    $head -ceq $tracking -and $head -ceq $live
) "SOURCE_NOT_CLEAN_PUSHED_EQUAL"

$qualificationSource = [string]$closure.source.commit
Assert-R24D48 ($qualificationSource -cmatch '^[0-9a-f]{40}$') "QUALIFICATION_SOURCE"
$codePaths = @($runner.qualification_source_code_paths | ForEach-Object { [string]$_ })
Assert-R24D48 ($codePaths.Count -gt 0 -and $codePaths.Count -eq @($codePaths | Select-Object -Unique).Count) (
    "CODE_PATHS"
)
$stageAuthority = $null
$stageAuthoritySupplied = -not [string]::IsNullOrEmpty(
    $StageAuthorityContractRelativePath
) -or -not [string]::IsNullOrEmpty($StageAuthorityContractRawSha256)
Assert-R24D48 (
    -not $stageAuthoritySupplied -or (
        $Mode -ceq "Development" -and
        -not [string]::IsNullOrEmpty($StageAuthorityContractRelativePath) -and
        $StageAuthorityContractRawSha256 -cmatch '^sha256:[0-9a-f]{64}$'
    )
) "STAGE_AUTHORITY_ARGUMENTS"
$qualifiedCodePaths = $codePaths
$stageAuthorityKind = $null
if ($stageAuthoritySupplied) {
    $stageAuthorityPath = [IO.Path]::GetFullPath((
        Join-Path $repoRoot $StageAuthorityContractRelativePath
    ))
    Assert-R24D48 (
        $stageAuthorityPath.StartsWith(
            $repoRoot + [IO.Path]::DirectorySeparatorChar,
            [StringComparison]::Ordinal
        ) -and
        (Test-Path -LiteralPath $stageAuthorityPath -PathType Leaf) -and
        (Get-RepositoryTextSha256 $stageAuthorityPath) -ceq
            $StageAuthorityContractRawSha256
    ) "STAGE_AUTHORITY_CONTRACT"
    $stageAuthority = Get-Content -Raw -LiteralPath $stageAuthorityPath |
        ConvertFrom-Json -AsHashtable
    $exclusions = @(
        $stageAuthority.authority_only_qualified_path_exclusions |
            ForEach-Object { [string]$_ }
    )
    $stageAuthoritySchema = [string]$stageAuthority.schema_version
    if ($stageAuthoritySchema -ceq
        "sporespore_qsdk_r24d49_stage_b_ghost_authority_contract_v1") {
        Assert-R24D48 (
            [string]$stageAuthority.gate_id -ceq $gateId -and
            [string]$stageAuthority.stage_id -ceq "R24D49-B" -and
            [string]$stageAuthority.question_class -ceq
                "development_launch_authority_repair" -and
            [bool]$stageAuthority.physical_question_declared -and
            $exclusions.Count -eq 2 -and
            $exclusions -contains [string]$runner.shared_script_path -and
            $exclusions -contains [string]$runner.script_path
        ) "STAGE_AUTHORITY_IDENTITY"
        $stageAuthorityKind = "r24d49_stage_b"
    } elseif ($stageAuthoritySchema -cin @(
        "sporespore_qsdk_r24d54_rapier_integration_authority_routing_repair_closure_v1",
        "sporespore_qsdk_r24d54_rapier_authority_route_probe_repair_v1",
        "sporespore_qsdk_r24d54_rapier_authority_route_probe_repair_closure_v1"
    )) {
        $isProbeDeclaration = $stageAuthoritySchema -ceq
            "sporespore_qsdk_r24d54_rapier_authority_route_probe_repair_v1"
        $isProbeClosure = $stageAuthoritySchema -ceq
            "sporespore_qsdk_r24d54_rapier_authority_route_probe_repair_closure_v1"
        $repairSource = if ($isProbeDeclaration) {
            $head
        } else {
            [string]$stageAuthority.repair_source.commit
        }
        $expectedStageId = if ($isProbeDeclaration -or $isProbeClosure) {
            "R24D54-L2"
        } else { "R24D54-L1" }
        $expectedStatus = if ($isProbeDeclaration) {
            [string]$stageAuthority.status -ceq
                "prospective_zero_world_production_route_authority_probe_unqualified"
        } elseif ($isProbeClosure) {
            [string]$stageAuthority.closure_status -ceq (
                "closed_complete_zero_world_production_route_authority_" +
                "probe_repair_qualified"
            )
        } else {
            [string]$stageAuthority.closure_status -ceq (
                "closed_complete_zero_world_integration_authority_" +
                "routing_repair_qualified"
            )
        }
        $closureDecisionValid = if ($isProbeDeclaration) {
            [bool]$AuthorityRouteProbe -and
            [bool]$stageAuthority.claim_boundary.routing_repair_implemented -and
            -not [bool]$stageAuthority.claim_boundary.routing_repair_qualified -and
            -not [bool]$stageAuthority.claim_boundary.physical_execution_authorized
        } else {
            [bool]$stageAuthority.decision.observed_launcher_failure_pre_physics -and
            -not [bool]$stageAuthority.decision.physical_attempt_consumed -and
            [bool]$stageAuthority.decision.full_cold_equivalence_development_qualification_passed -and
            [bool]$stageAuthority.decision.integration_authority_routing_qualified -and
            [bool]$stageAuthority.decision.launcher_repair_authority -and
            (-not $isProbeClosure -or
                [bool]$stageAuthority.decision.production_route_authority_probe_passed) -and
            -not [bool]$stageAuthority.decision.physical_acceptance_authority -and
            -not [bool]$stageAuthority.decision.release_authority
        }
        if ($isProbeDeclaration -or $isProbeClosure) {
            $predecessorRepairPath = [IO.Path]::GetFullPath((
                Join-Path $repoRoot (
                    [string]$stageAuthority.predecessor_launcher_repair.closure_path
                )
            ))
            Assert-R24D48 (
                (Test-Path -LiteralPath $predecessorRepairPath -PathType Leaf) -and
                (Get-RepositoryTextSha256 $predecessorRepairPath) -ceq
                    [string]$stageAuthority.predecessor_launcher_repair.closure_raw_sha256
            ) "STAGE_AUTHORITY_PREDECESSOR_REPAIR"
        }
        Assert-R24D48 (
            [string]$stageAuthority.gate_id -ceq $gateId -and
            [string]$stageAuthority.stage_id -ceq $expectedStageId -and
            $expectedStatus -and
            [string]$stageAuthority.question_class -ceq
                "development_launch_authority_repair" -and
            -not [bool]$stageAuthority.physical_question_declared -and
            [string]$stageAuthority.base_qualification.source_commit -ceq
                $qualificationSource -and
            $repairSource -cmatch '^[0-9a-f]{40}$' -and
            $closureDecisionValid -and
            $exclusions.Count -eq 1 -and
            $exclusions[0] -ceq [string]$runner.script_path
        ) "STAGE_AUTHORITY_IDENTITY"
        $repairDiffArguments = @(
            "diff", "--name-only", $qualificationSource, $repairSource, "--"
        ) + $codePaths
        $repairDiffOutput = Get-Git $repairDiffArguments
        [string[]]$repairChangedPaths = @(
            if (-not [string]::IsNullOrEmpty($repairDiffOutput)) {
                $repairDiffOutput.Split("`n") | ForEach-Object { $_.Trim() }
            }
        )
        Assert-R24D48 (
            $repairChangedPaths.Count -eq 1 -and
            $repairChangedPaths[0] -ceq $exclusions[0]
        ) "STAGE_AUTHORITY_REPAIR_SCOPE"
        & $git -C $repoRoot diff --quiet $repairSource HEAD -- @exclusions
        Assert-R24D48 ($LASTEXITCODE -eq 0) "STAGE_AUTHORITY_REPAIR_DRIFT"
        $stageAuthorityKind = "r24d54_launcher_repair"
    } else {
        Assert-R24D48 $false "STAGE_AUTHORITY_SCHEMA"
    }
    $qualifiedCodePaths = @($codePaths | Where-Object { $exclusions -notcontains $_ })
    Assert-R24D48 (
        @($stageAuthority.qualified_unchanged_source_paths).Count -eq
            $qualifiedCodePaths.Count -and
        -not (Compare-Object -CaseSensitive -ReferenceObject $qualifiedCodePaths `
            -DifferenceObject @($stageAuthority.qualified_unchanged_source_paths))
    ) "STAGE_AUTHORITY_SOURCE_POPULATION"
}
& $git -C $repoRoot diff --quiet $qualificationSource HEAD -- @qualifiedCodePaths
Assert-R24D48 ($LASTEXITCODE -eq 0) "QUALIFIED_CODE_DRIFT"

$qualificationRoot = [IO.Path]::GetFullPath([string]$closure.qualification.evidence_root)
$qualificationReceiptPath = Join-Path $qualificationRoot `
    ([string]$closure.qualification.receipt_path)
Assert-R24D48 (
    $qualificationRoot.StartsWith($expectedEvidenceRoot + [IO.Path]::DirectorySeparatorChar) -and
    (Test-Path -LiteralPath $qualificationReceiptPath -PathType Leaf) -and
    (Get-Item -LiteralPath $qualificationReceiptPath).Length -eq
        [long]$closure.qualification.receipt_byte_length -and
    (Get-RawSha256 $qualificationReceiptPath) -ceq
        [string]$closure.qualification.receipt_raw_sha256
) "QUALIFICATION_RECEIPT"
$qualificationReceipt = Get-Content -Raw -LiteralPath $qualificationReceiptPath |
    ConvertFrom-Json -AsHashtable
$expectedQualificationCargoLockRelative =
    [string]$runner.qualification_harness_cargo_lock_path
Assert-R24D48 (
    [string]$qualificationReceipt.gate_id -ceq $gateId -and
    [string]$qualificationReceipt.mode -ceq "qualification" -and
    [bool]$qualificationReceipt.ok -and
    [string]$qualificationReceipt.source_commit -ceq $qualificationSource -and
    $expectedQualificationCargoLockRelative -ceq "isolated-harness/Cargo.lock" -and
    [string]$qualificationReceipt.isolated_harness_cargo_lock.path -ceq
        $expectedQualificationCargoLockRelative
) "QUALIFICATION_RECEIPT_IDENTITY"
$qualificationCargoLockPath = Join-Path $qualificationRoot `
    ([string]$qualificationReceipt.isolated_harness_cargo_lock.path)
Assert-R24D48 (
    (Test-Path -LiteralPath $qualificationCargoLockPath -PathType Leaf) -and
    (Get-Item -LiteralPath $qualificationCargoLockPath).Length -eq
        [long]$qualificationReceipt.isolated_harness_cargo_lock.byte_length -and
    (Get-RawSha256 $qualificationCargoLockPath) -ceq
        [string]$qualificationReceipt.isolated_harness_cargo_lock.raw_sha256
) "QUALIFICATION_CARGO_LOCK"
$qualificationCargoLockSha256 = Get-RawSha256 $qualificationCargoLockPath
$runtimeQualificationSha256 = if ($runner.Contains("runtime_binding_closure_json_pointer")) {
    [string](Get-JsonPointerValue -Root $closure -Pointer (
        [string]$runner.runtime_binding_closure_json_pointer
    ))
} else { [string]$closure.qualification.production_preflight_canonical_sha256 }
Assert-R24D48 ($runtimeQualificationSha256 -cmatch '^sha256:[0-9a-f]{64}$') (
    "RUNTIME_QUALIFICATION_SHA"
)

$dependencyContractRelative = if (
    $contract.qualification_runner.Contains("pinned_dependency_contract_path")
) { [string]$contract.qualification_runner.pinned_dependency_contract_path } else {
    [string]$contract.predecessor.contract_path
}
$dependencyContractSha256 = if (
    $contract.qualification_runner.Contains("pinned_dependency_contract_raw_sha256")
) { [string]$contract.qualification_runner.pinned_dependency_contract_raw_sha256 } else {
    [string]$contract.predecessor.contract_raw_sha256
}
$dependencyContractPath = Join-Path $repoRoot $dependencyContractRelative
Assert-R24D48 (
    (Get-RawSha256 $dependencyContractPath) -ceq $dependencyContractSha256
) "DEPENDENCY_CONTRACT"
$dependencyContract = Get-Content -Raw -LiteralPath $dependencyContractPath |
    ConvertFrom-Json -AsHashtable
$dependency = $dependencyContract.pinned_dependency
$patchedRoot = Join-Path $qualificationRoot (
    "isolated-dependency/" + [string]$dependency.fresh_extract_directory_name
)
Assert-R24D48 (Test-Path -LiteralPath $patchedRoot -PathType Container) "PATCHED_ROOT"
$successorBindings = @{}
# Legacy R53 audit marker: $contract.qualification_runner.successor_patched_files
$patchBindingRunner = if ($qualificationRunner.Contains("successor_patched_files")) {
    $qualificationRunner
} elseif ($null -ne $patchProfileRunner) { $patchProfileRunner } else { $qualificationRunner }
if ($patchBindingRunner.Contains("successor_patched_files")) {
    foreach ($binding in @($patchBindingRunner.successor_patched_files)) {
        $relative = [string]$binding.path
        Assert-R24D48 (
            -not [string]::IsNullOrEmpty($relative) -and
            -not $successorBindings.ContainsKey($relative)
        ) "SUCCESSOR_PATCHED_BINDING_DUPLICATE:$relative"
        $successorBindings[$relative] = $binding
    }
}
$basePaths = @{}
foreach ($binding in @($dependency.upstream_and_patched_files)) {
    $relative = [string]$binding.path
    $basePaths[$relative] = $true
    $expected = if ($successorBindings.ContainsKey($relative)) {
        $successorBindings[$relative]
    } else { $binding }
    $expectedLength = if ($successorBindings.ContainsKey($relative)) {
        [long]$expected.byte_length
    } else { [long]$expected.patched_byte_length }
    $expectedSha256 = if ($successorBindings.ContainsKey($relative)) {
        [string]$expected.raw_sha256
    } else { [string]$expected.patched_raw_sha256 }
    $path = Join-Path $patchedRoot $relative
    Assert-R24D48 (
        (Test-Path -LiteralPath $path -PathType Leaf) -and
        (Get-Item -LiteralPath $path).Length -eq $expectedLength -and
        (Get-RawSha256 $path) -ceq $expectedSha256
    ) "PATCHED_BINDING:$relative"
}
foreach ($relative in @($successorBindings.Keys | Sort-Object)) {
    if ($basePaths.ContainsKey($relative)) { continue }
    $binding = $successorBindings[$relative]
    $path = Join-Path $patchedRoot $relative
    Assert-R24D48 (
        (Test-Path -LiteralPath $path -PathType Leaf) -and
        (Get-Item -LiteralPath $path).Length -eq [long]$binding.byte_length -and
        (Get-RawSha256 $path) -ceq [string]$binding.raw_sha256
    ) "SUCCESSOR_ONLY_PATCHED_BINDING:$relative"
}

$toolchain = [ordered]@{
    rustc = (& rustc --version).Trim()
    cargo = (& $cargo --version).Trim()
    powershell = $PSVersionTable.PSVersion.ToString()
    os = [Environment]::OSVersion.VersionString
    architecture = [Runtime.InteropServices.RuntimeInformation]::OSArchitecture.ToString()
    qualification_harness_cargo_lock_sha256 = $qualificationCargoLockSha256
}
$environmentJson = $toolchain | ConvertTo-Json -Depth 10 -Compress
$environmentSha256 = Get-TextSha256 $environmentJson

$modeName = $Mode.ToLowerInvariant()
$prefix = if ($Mode -ceq "Ghost") {
    [string]$runner.ghost_directory_prefix
} else { [string]$runner.development_directory_prefix }
$priorAttempts = @(Get-ChildItem -LiteralPath $evidenceRootFull -Directory |
    Where-Object { $_.Name -like "$prefix*" } |
    Where-Object {
        $attempt = Join-Path $_.FullName "physical_attempt.json"
        if (-not (Test-Path -LiteralPath $attempt -PathType Leaf)) { return $false }
        $value = Get-Content -Raw -LiteralPath $attempt | ConvertFrom-Json
        return [string]$value.source_commit -ceq $head -and
            [string]$value.mode -ceq $modeName
    })
Assert-R24D48 ($priorAttempts.Count -eq 0) "EXACT_SOURCE_STAGE_ALREADY_ATTEMPTED"

$ghostAuthority = $null
$developmentIntegrationAuthority = $null
if ($Mode -ceq "Development") {
    if (-not $developmentRequiresPriorGhost) {
        Assert-R24D48 (
            ($null -eq $stageAuthority -and -not $stageAuthoritySupplied) -or
            $stageAuthorityKind -ceq "r24d54_launcher_repair"
        ) (
            "INTEGRATION_AUTHORITY_CANNOT_COMBINE_WITH_STAGE_AUTHORITY"
        )
        Assert-R24D48 ($runner.Contains("development_integration_authority")) (
            "DEVELOPMENT_INTEGRATION_AUTHORITY_MISSING"
        )
        $integrationClaim = $runner.development_integration_authority
        $integrationClosurePath = [IO.Path]::GetFullPath((
            Join-Path $repoRoot ([string]$integrationClaim.closure_path)
        ))
        Assert-R24D48 (
            $integrationClosurePath.StartsWith(
                $repoRoot + [IO.Path]::DirectorySeparatorChar,
                [StringComparison]::Ordinal
            ) -and
            (Test-Path -LiteralPath $integrationClosurePath -PathType Leaf) -and
            (Get-RepositoryTextSha256 $integrationClosurePath) -ceq
                [string]$integrationClaim.closure_raw_sha256
        ) "DEVELOPMENT_INTEGRATION_CLOSURE"
        $integrationClosure = Get-Content -Raw -LiteralPath $integrationClosurePath |
            ConvertFrom-Json -AsHashtable
        Assert-R24D48 (
            [string]$integrationClosure.gate_id -ceq [string]$integrationClaim.gate_id -and
            [string]$integrationClosure.closure_status -ceq
                [string]$integrationClaim.closure_status
        ) "DEVELOPMENT_INTEGRATION_IDENTITY"
        foreach ($pointer in @($integrationClaim.required_true_json_pointers)) {
            Assert-R24D48 ([bool](Get-JsonPointerValue -Root $integrationClosure -Pointer (
                [string]$pointer
            ))) "DEVELOPMENT_INTEGRATION_REQUIRED_TRUE:$pointer"
        }
        foreach ($pointer in @($integrationClaim.required_false_json_pointers)) {
            Assert-R24D48 (-not [bool](Get-JsonPointerValue -Root $integrationClosure -Pointer (
                [string]$pointer
            ))) "DEVELOPMENT_INTEGRATION_REQUIRED_FALSE:$pointer"
        }
        $integrationEvidenceRoot = [IO.Path]::GetFullPath(
            [string]$integrationClosure.physical_attempt.evidence_root
        )
        $integrationResultClaim = $integrationClosure.physical_attempt.result
        $integrationResultPath = Join-Path $integrationEvidenceRoot (
            [string]$integrationResultClaim.path
        )
        Assert-R24D48 (
            $integrationEvidenceRoot.StartsWith(
                $expectedEvidenceRoot + [IO.Path]::DirectorySeparatorChar,
                [StringComparison]::Ordinal
            ) -and
            (Test-Path -LiteralPath $integrationResultPath -PathType Leaf) -and
            (Get-Item -LiteralPath $integrationResultPath).Length -eq
                [long]$integrationResultClaim.byte_length -and
            (Get-RawSha256 $integrationResultPath) -ceq
                [string]$integrationResultClaim.raw_sha256
        ) "DEVELOPMENT_INTEGRATION_RESULT_BINDING"
        $developmentIntegrationAuthority = [ordered]@{
            closure_path = $integrationClosurePath
            closure_raw_sha256 = [string]$integrationClaim.closure_raw_sha256
            result_path = $integrationResultPath
            result_raw_sha256 = [string]$integrationResultClaim.raw_sha256
        }
    } elseif ($null -ne $stageAuthority) {
        $ghostClaim = $stageAuthority.ghost_authority
        $ghostClosurePath = [IO.Path]::GetFullPath((
            Join-Path $repoRoot ([string]$ghostClaim.closure_path)
        ))
        Assert-R24D48 (
            $ghostClosurePath.StartsWith(
                $repoRoot + [IO.Path]::DirectorySeparatorChar,
                [StringComparison]::Ordinal
            ) -and
            (Test-Path -LiteralPath $ghostClosurePath -PathType Leaf) -and
            (Get-RepositoryTextSha256 $ghostClosurePath) -ceq
                [string]$ghostClaim.closure_raw_sha256
        ) "STAGE_AUTHORITY_GHOST_CLOSURE"
        $ghostClosure = Get-Content -Raw -LiteralPath $ghostClosurePath |
            ConvertFrom-Json -AsHashtable
        Assert-R24D48 (
            [string]$ghostClosure.gate_id -ceq $gateId -and
            [string]$ghostClosure.closure_status -ceq
                "closed_valid_complete_integration_ghost_live_chain_exercised_stage_b_authorized" -and
            [string]$ghostClosure.source.commit -ceq
                [string]$ghostClaim.source_commit -and
            [string]$ghostClosure.physical_attempt.runtime_binding_sha256 -ceq
                $runtimeQualificationSha256 -and
            [bool]$ghostClosure.decision.integration_ghost_passed -and
            [bool]$ghostClosure.decision.paired_development_authorized -and
            -not [bool]$ghostClosure.claim_boundary.prone_to_standing_claimed -and
            -not [bool]$ghostClosure.claim_boundary.physical_acceptance_authority -and
            -not [bool]$ghostClosure.claim_boundary.release_authority
        ) "STAGE_AUTHORITY_GHOST_DECISION"
        $ghostSource = [string]$ghostClosure.source.commit
        Assert-R24D48 ($ghostSource -cmatch '^[0-9a-f]{40}$') (
            "STAGE_AUTHORITY_GHOST_SOURCE"
        )
        & $git -C $repoRoot diff --quiet $ghostSource HEAD -- @qualifiedCodePaths
        Assert-R24D48 ($LASTEXITCODE -eq 0) "STAGE_AUTHORITY_PHYSICAL_CODE_DRIFT"
        $receiptClaim = $ghostClosure.physical_attempt.receipt
        $ghostRoot = [IO.Path]::GetFullPath(
            [string]$ghostClosure.physical_attempt.evidence_root
        )
        $receiptPath = Join-Path $ghostRoot ([string]$receiptClaim.path)
        Assert-R24D48 (
            $ghostRoot.StartsWith(
                $expectedEvidenceRoot + [IO.Path]::DirectorySeparatorChar,
                [StringComparison]::Ordinal
            ) -and
            (Test-Path -LiteralPath $receiptPath -PathType Leaf) -and
            (Get-Item -LiteralPath $receiptPath).Length -eq
                [long]$receiptClaim.byte_length -and
            (Get-RawSha256 $receiptPath) -ceq [string]$receiptClaim.raw_sha256
        ) "STAGE_AUTHORITY_GHOST_RECEIPT"
        $value = Get-Content -Raw -LiteralPath $receiptPath |
            ConvertFrom-Json -AsHashtable
        Assert-R24D48 (
            [string]$value.mode -ceq "ghost" -and
            [string]$value.source_commit -ceq $ghostSource -and
            [string]$value[$runtimeBindingField] -ceq
                $runtimeQualificationSha256 -and
            [string]$value.environment_sha256 -ceq $environmentSha256 -and
            [bool]$value.stage_valid -and
            [long]$value.actual_total_outer_steps -eq 4 -and
            [long]$value.held_out_cell_access_count -eq 0 -and
            [long]$value.held_out_selector_invocation_count -eq 0 -and
            [bool]$value.operation_lock_released -and
            -not [bool]$value.physical_acceptance_authority -and
            -not [bool]$value.release_authority
        ) "STAGE_AUTHORITY_GHOST_RECEIPT_IDENTITY"
        $ghostAuthority = [ordered]@{ path = $receiptPath; value = $value }
    } else {
        $ghostReceipts = @(Get-ChildItem -LiteralPath $evidenceRootFull -Directory |
            Where-Object { $_.Name -like "$([string]$runner.ghost_directory_prefix)*" } |
            ForEach-Object {
                $receiptPath = Join-Path $_.FullName "physical_receipt.json"
                if (Test-Path -LiteralPath $receiptPath -PathType Leaf) {
                    $value = Get-Content -Raw -LiteralPath $receiptPath |
                        ConvertFrom-Json -AsHashtable
                    if ([string]$value.mode -ceq "ghost" -and
                        [string]$value.source_commit -ceq $head -and
                        [string]$value[$runtimeBindingField] -ceq
                            $runtimeQualificationSha256 -and
                        [string]$value.environment_sha256 -ceq $environmentSha256 -and
                        [bool]$value.stage_valid) {
                        [ordered]@{ path = $receiptPath; value = $value }
                    }
                }
            })
        Assert-R24D48 ($ghostReceipts.Count -eq 1) (
            "PASSING_SAME_SOURCE_GHOST_COUNT:$($ghostReceipts.Count)"
        )
        $ghostAuthority = $ghostReceipts[0]
    }
    if ($null -ne $ghostAuthority) {
        $ghostResultPath = Join-Path (Split-Path -Parent $ghostAuthority.path) `
            ([string]$ghostAuthority.value.result_path)
        Assert-R24D48 (
            (Test-Path -LiteralPath $ghostResultPath -PathType Leaf) -and
            (Get-Item -LiteralPath $ghostResultPath).Length -eq
                [long]$ghostAuthority.value.result_byte_length -and
            (Get-RawSha256 $ghostResultPath) -ceq
                [string]$ghostAuthority.value.result_raw_sha256
        ) "GHOST_RESULT_BINDING"
    } else {
        Assert-R24D48 ($null -ne $developmentIntegrationAuthority) (
            "DEVELOPMENT_AUTHORITY_ROUTE"
        )
    }
}

if ($AuthorityRouteProbe) {
    Assert-R24D48 (
        $Mode -ceq "Development" -and
        $stageAuthorityKind -ceq "r24d54_launcher_repair" -and
        $stageAuthoritySchema -ceq
            "sporespore_qsdk_r24d54_rapier_authority_route_probe_repair_v1" -and
        $null -ne $developmentIntegrationAuthority -and
        $null -eq $ghostAuthority
    ) "AUTHORITY_ROUTE_PROBE_SCOPE"
    $probePrefix =
        "qsdk-r24d54-rapier-recovery-energy-v3-authority-route-probe-"
    $priorProbeRoots = @(Get-ChildItem -LiteralPath $evidenceRootFull -Directory |
        Where-Object { $_.Name -like "$probePrefix*" } |
        Where-Object {
            $receiptPath = Join-Path $_.FullName "authority_route_probe_receipt.json"
            if (-not (Test-Path -LiteralPath $receiptPath -PathType Leaf)) {
                return $false
            }
            $value = Get-Content -Raw -LiteralPath $receiptPath |
                ConvertFrom-Json -AsHashtable
            return [string]$value.source_commit -ceq $head
        })
    Assert-R24D48 ($priorProbeRoots.Count -eq 0) (
        "AUTHORITY_ROUTE_PROBE_ALREADY_RETAINED"
    )
    . $lockScript
    $probeLock = $null
    $probeRoot = $null
    $probeReceipt = $null
    try {
        $probeLock = Enter-SporeSporeLocomotionOperationLock -Role "conformance"
        Assert-R24D48 (
            [bool]$probeLock.acquired -and -not [bool]$probeLock.test_only
        ) "AUTHORITY_ROUTE_PROBE_LOCK"
        Assert-R24D48 ((Get-Git @("rev-parse", "HEAD")) -ceq $head) (
            "AUTHORITY_ROUTE_PROBE_HEAD_DRIFT"
        )
        Assert-R24D48 ((Get-Git @("status", "--short")) -ceq $status) (
            "AUTHORITY_ROUTE_PROBE_STATUS_DRIFT"
        )
        $probeTimestamp = [DateTime]::UtcNow.ToString("yyyyMMddTHHmmssfffZ")
        $probeRoot = Join-Path $evidenceRootFull (
            "$probePrefix$probeTimestamp-$($head.Substring(0, 8))"
        )
        New-Item -ItemType Directory -Path $probeRoot -ErrorAction Stop |
            Out-Null
        $probeReceipt = [ordered]@{
            schema_version =
                "sporespore_qsdk_r24d54_rapier_authority_route_probe_receipt_v1"
            gate_id = $gateId
            stage_id = "R24D54-L2"
            mode = "authority_route_probe"
            completed_utc = [DateTime]::UtcNow.ToString("o")
            source_commit = $head
            qualification_source_commit = $qualificationSource
            repair_source_commit = $repairSource
            branch = $branch
            remote = $remote
            upstream_commit = $tracking
            live_remote_commit = $live
            worktree_clean = $true
            stage_authority_relative_path = $StageAuthorityContractRelativePath
            stage_authority_raw_sha256 = $StageAuthorityContractRawSha256
            stage_authority_kind = $stageAuthorityKind
            integration_closure_path = [IO.Path]::GetRelativePath(
                $repoRoot, [string]$developmentIntegrationAuthority.closure_path
            ).Replace("\", "/")
            integration_closure_raw_sha256 =
                [string]$developmentIntegrationAuthority.closure_raw_sha256
            integration_result_path =
                [string]$developmentIntegrationAuthority.result_path
            integration_result_raw_sha256 =
                [string]$developmentIntegrationAuthority.result_raw_sha256
            operation_lock = Get-SporeSporeLocomotionOperationLockPublicReceipt (
                $probeLock
            )
            operation_lock_released = $false
            authority_route_validated = $true
            ghost_authority_present = $false
            development_integration_authority_present = $true
            evidence_root_created = $true
            physical_attempt_record_created = $false
            model_construction_count = 0
            world_attempt_count = 0
            world_build_count = 0
            solver_step_count = 0
            physics_state_modified = $false
            physical_question_opened = $false
            physical_attempt_consumed = $false
            physical_acceptance_authority = $false
            release_authority = $false
        }
    } finally {
        if ($null -ne $probeLock) {
            Exit-SporeSporeLocomotionOperationLock $probeLock | Out-Null
        }
    }
    Assert-R24D48 ($null -ne $probeReceipt -and [bool]$probeLock.released) (
        "AUTHORITY_ROUTE_PROBE_INCOMPLETE"
    )
    $probeReceipt.operation_lock_released = $true
    $probeReceiptPath = Join-Path $probeRoot "authority_route_probe_receipt.json"
    Write-JsonExclusive $probeReceiptPath $probeReceipt
    Write-Output (
        "QSDK_R24D54_AUTHORITY_ROUTE_PROBE_PASS " +
        "source=$head models=0 worlds=0 solver_steps=0 physical=false " +
        "receipt=$probeReceiptPath"
    )
    exit 0
}

. $lockScript
$lock = $null
$runRoot = $null
$caught = $null
$result = $null
$previousTarget = $env:CARGO_TARGET_DIR
try {
    $lock = Enter-SporeSporeLocomotionOperationLock -Role ([string]$runner.operation_lock_role)
    Assert-R24D48 ([bool]$lock.acquired -and -not [bool]$lock.test_only) "OPERATION_LOCK"
    Assert-R24D48 ((Get-Git @("rev-parse", "HEAD")) -ceq $head) "HEAD_DRIFT"
    Assert-R24D48 ((Get-Git @("status", "--short")) -ceq $status) "STATUS_DRIFT"

    $timestamp = [DateTime]::UtcNow.ToString("yyyyMMddTHHmmssfffZ")
    $runRoot = Join-Path $evidenceRootFull "$prefix$timestamp-$($head.Substring(0, 8))"
    New-Item -ItemType Directory -Path $runRoot -ErrorAction Stop | Out-Null
    $attemptReceipt = [ordered]@{
        schema_version = [string]$runner.attempt_schema
        gate_id = $gateId
        mode = $modeName
        started_utc = [DateTime]::UtcNow.ToString("o")
        source_commit = $head
        qualification_source_commit = $qualificationSource
        branch = $branch
        remote = $remote
        upstream_commit = $tracking
        live_remote_commit = $live
        worktree_clean_at_start = $true
        environment = $toolchain
        environment_sha256 = $environmentSha256
        ghost_authority_path = if ($null -eq $ghostAuthority) { $null } else {
            [IO.Path]::GetRelativePath($evidenceRootFull, [string]$ghostAuthority.path).Replace("\", "/")
        }
        development_integration_authority = if (
            $null -eq $developmentIntegrationAuthority
        ) { $null } else {
            [ordered]@{
                closure_path = [IO.Path]::GetRelativePath(
                    $repoRoot, [string]$developmentIntegrationAuthority.closure_path
                ).Replace("\", "/")
                closure_raw_sha256 =
                    [string]$developmentIntegrationAuthority.closure_raw_sha256
                result_path = [string]$developmentIntegrationAuthority.result_path
                result_raw_sha256 =
                    [string]$developmentIntegrationAuthority.result_raw_sha256
            }
        }
        physical_acceptance_authority = $false
        release_authority = $false
    }
    $attemptReceipt[$runtimeBindingField] = $runtimeQualificationSha256
    Write-JsonExclusive (Join-Path $runRoot "physical_attempt.json") $attemptReceipt

    $harness = Join-Path $runRoot "isolated-harness"
    $harnessSource = Join-Path $harness "src"
    New-Item -ItemType Directory -Path $harnessSource -ErrorAction Stop | Out-Null
    $adapterPath = (Join-Path $repoRoot "sdk/adapters/rapier").Replace("\", "/")
    $patchedPath = $patchedRoot.Replace("\", "/")
    $manifest = @"
[package]
name = "$([string]$contract.qualification_runner.isolated_harness_package)"
version = "0.0.0"
edition = "2024"
publish = false

[workspace]

[dependencies]
rapier3d = { version = "=$($dependency.version)", features = ["$($contract.qualification_runner.patched_dependency_feature)"] }
serde_json = "=$($contract.qualification_runner.serde_json_version)"
sporespore-rapier-adapter = { path = "$adapterPath", features = ["$($contract.qualification_runner.adapter_feature)"] }

[patch.crates-io]
rapier3d = { path = "$patchedPath" }
"@
    $command = if ($Mode -ceq "Ghost") {
        [string]$runner.ghost_command
    } else { [string]$runner.development_command }
    $terminalMarker = if ($Mode -ceq "Ghost") {
        [string]$runner.ghost_terminal_marker
    } else { [string]$runner.development_terminal_marker }
    $ghostEntrypoint = if ($runner.Contains("ghost_entrypoint")) {
        [string]$runner.ghost_entrypoint
    } else { "run_qsdk_r24d48_rapier_recovery_energy_v2_ghost" }
    $developmentEntrypoint = if ($runner.Contains("development_entrypoint")) {
        [string]$runner.development_entrypoint
    } else { "run_qsdk_r24d48_rapier_recovery_energy_v2_development_attempt" }
    $main = @"
fn main() {
    let result = if "$command" == "ghost" {
        sporespore_rapier_adapter::$ghostEntrypoint(
            "$runtimeQualificationSha256",
        )
    } else {
        sporespore_rapier_adapter::$developmentEntrypoint(
            "$runtimeQualificationSha256",
        )
    }.expect("$gateId physical stage must return a retained result");
    println!(
        "$terminalMarker{}",
        serde_json::to_string(&result).expect("$gateId result must serialize"),
    );
}
"@
    Write-TextExclusive (Join-Path $harness "Cargo.toml") $manifest
    Write-TextExclusive (Join-Path $harnessSource "main.rs") $main
    [IO.File]::Copy(
        $qualificationCargoLockPath,
        (Join-Path $harness "Cargo.lock"),
        $false
    )
    Assert-R24D48 (
        (Get-RawSha256 (Join-Path $harness "Cargo.lock")) -ceq
            $qualificationCargoLockSha256
    ) "COPIED_QUALIFICATION_CARGO_LOCK"
    $env:CARGO_TARGET_DIR = Join-Path $evidenceRootFull (
        "build-cache/$gateCacheId-rapier-physical/$head"
    )
    $workerOutput = Invoke-Logged $cargo @(
        "run", "--locked", "--offline", "--manifest-path", (Join-Path $harness "Cargo.toml")
    ) (Join-Path $runRoot "01-worker.log") "WORKER"
    Assert-R24D48 (
        (Get-RawSha256 (Join-Path $harness "Cargo.lock")) -ceq
            $qualificationCargoLockSha256
    ) "HARNESS_CARGO_LOCK_DRIFT"
    $markers = @($workerOutput | Where-Object {
        $_.StartsWith($terminalMarker, [StringComparison]::Ordinal)
    })
    Assert-R24D48 ($markers.Count -eq 1) "TERMINAL_MARKER_COUNT:$($markers.Count)"
    $resultText = $markers[0].Substring($terminalMarker.Length)
    $result = $resultText | ConvertFrom-Json -AsHashtable -Depth 100
    $resultPath = Join-Path $runRoot "physical_result.json"
    Write-TextExclusive $resultPath ($resultText + "`n")
    Assert-R24D48 (
        [bool]$result.ok -and [string]$result.gate_id -ceq $gateId -and
        [string]$result[$runtimeBindingField] -ceq $runtimeQualificationSha256 -and
        [int]$result.held_out_cell_access_count -eq 0 -and
        [int]$result.held_out_selector_invocation_count -eq 0 -and
        -not [bool]$result.physical_acceptance_authority -and
        -not [bool]$result.release_authority
    ) "RESULT_COMMON"
    if ($Mode -ceq "Ghost") {
        if ($ghostResultShape -ceq "single_arm_transport_v1") {
            $armField = [string]$runner.ghost_transport_arm_field
            $expectedTotal = [long]$runner.ghost_maximum_total_outer_steps
            Assert-R24D48 (
                $armField -cmatch '^[a-z0-9_]+$' -and
                $null -ne $result[$armField] -and
                [long]$result.maximum_total_outer_steps -eq $expectedTotal -and
                [long]$result.actual_total_outer_steps -eq $expectedTotal -and
                [long]$result[$armField].outer_step_count -eq $expectedTotal -and
                [long]$result[$armField].native_solver_step_count -eq $expectedTotal -and
                [long]$result.native_staging_record_count -eq $expectedTotal -and
                [long]$result.portable_v3_increment_count -eq $expectedTotal -and
                [bool]$result.native_staging_transport_observed -and
                [bool]$result.portable_v3_mapping_observed -and
                -not [bool]$result.behavior_success_required -and
                -not [bool]$result.official_behavior_evidence -and
                -not [bool]$result.prone_to_standing_claimed
            ) "GHOST_SINGLE_ARM_TRANSPORT_RESULT"
        } else {
            Assert-R24D48 (
                $ghostResultShape -ceq "paired_candidate_matched_zero_v1" -and
                [long]$result.maximum_total_outer_steps -eq 4 -and
                [long]$result.actual_total_outer_steps -eq 4 -and
                [long]$result.candidate.outer_step_count -eq 2 -and
                [long]$result.matched_zero_command.outer_step_count -eq 2 -and
                -not [bool]$result.behavior_success_required -and
                -not [bool]$result.official_behavior_evidence -and
                -not [bool]$result.prone_to_standing_claimed
            ) "GHOST_RESULT"
        }
    } else {
        Assert-R24D48 (
            [long]$result.maximum_total_outer_steps -eq 2400 -and
            [long]$result.actual_total_outer_steps -le 2400 -and
            [long]$result.candidate_outer_steps -le 1200 -and
            [long]$result.matched_zero_outer_steps -le 1200 -and
            $null -ne $result.evaluation
        ) "DEVELOPMENT_RESULT"
    }
} catch {
    $caught = $_
} finally {
    $env:CARGO_TARGET_DIR = $previousTarget
    if ($null -ne $lock) {
        Exit-SporeSporeLocomotionOperationLock $lock | Out-Null
    }
}

if ($null -ne $caught) {
    if ($null -ne $runRoot) {
        Write-JsonExclusive (Join-Path $runRoot "physical_failure.json") ([ordered]@{
            schema_version = [string]$runner.failure_schema
            gate_id = $gateId
            mode = $modeName
            failed_utc = [DateTime]::UtcNow.ToString("o")
            source_commit = $head
            $runtimeBindingField = $runtimeQualificationSha256
            error = [string]$caught.Exception.Message
            operation_lock_released = $null -ne $lock -and [bool]$lock.released
            physical_acceptance_authority = $false
            release_authority = $false
        })
    }
    throw $caught
}

Assert-R24D48 ($null -ne $lock -and [bool]$lock.released) "LOCK_RELEASE"
Assert-R24D48 ((Get-Git @("rev-parse", "HEAD")) -ceq $head) "FINAL_HEAD_DRIFT"
Assert-R24D48 ((Get-Git @("status", "--short")) -ceq $status) "FINAL_STATUS_DRIFT"
$resultPath = Join-Path $runRoot "physical_result.json"
$receipt = [ordered]@{
    schema_version = [string]$runner.receipt_schema
    gate_id = $gateId
    mode = $modeName
    stage_valid = $true
    completed_utc = [DateTime]::UtcNow.ToString("o")
    source_commit = $head
    qualification_source_commit = $qualificationSource
    $runtimeBindingField = $runtimeQualificationSha256
    environment = $toolchain
    environment_sha256 = $environmentSha256
    qualification_harness_cargo_lock_sha256 = $qualificationCargoLockSha256
    result_path = "physical_result.json"
    result_byte_length = (Get-Item -LiteralPath $resultPath).Length
    result_raw_sha256 = Get-RawSha256 $resultPath
    actual_total_outer_steps = [long]$result.actual_total_outer_steps
    candidate_outer_steps = if ($Mode -ceq "Ghost") {
        if ($ghostResultShape -ceq "single_arm_transport_v1") {
            [long]$result[[string]$runner.ghost_transport_arm_field].outer_step_count
        } else { [long]$result.candidate.outer_step_count }
    } else { [long]$result.candidate_outer_steps }
    matched_zero_outer_steps = if ($Mode -ceq "Ghost") {
        if ($ghostResultShape -ceq "single_arm_transport_v1") {
            0
        } else { [long]$result.matched_zero_command.outer_step_count }
    } else { [long]$result.matched_zero_outer_steps }
    ghost_result_shape = if ($Mode -ceq "Ghost") { $ghostResultShape } else { $null }
    ghost_authority_path = if ($null -eq $ghostAuthority) { $null } else {
        [IO.Path]::GetRelativePath($evidenceRootFull, [string]$ghostAuthority.path).Replace("\", "/")
    }
    operation_lock_released = [bool]$lock.released
    held_out_cell_access_count = 0
    held_out_selector_invocation_count = 0
    physical_acceptance_authority = $false
    release_authority = $false
}
$receiptPath = Join-Path $runRoot "physical_receipt.json"
Write-JsonExclusive $receiptPath $receipt
Write-Output (
    $physicalPassMarker + " " +
    "mode=$modeName source=$head steps=$($receipt.actual_total_outer_steps) " +
    "receipt=$receiptPath"
)
