#requires -Version 7.0

[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$qualificationPath = Join-Path $repoRoot (
    "sdk\recovery\" +
    "r24d3_godot_jolt_motor_telemetry_post_adoption_" +
    "full_cold_conformance_qualification_v1.json"
)
$adoptionPath = Join-Path $repoRoot (
    "sdk\recovery\" +
    "r24d3_godot_jolt_motor_telemetry_cold_qualification_adoption_v2.json"
)
$manifestPath = Join-Path $repoRoot (
    "sdk\recovery\" +
    "r24d3_godot_jolt_motor_telemetry_source_validation_manifest.json"
)
$releasePath = Join-Path $repoRoot "sdk\release\quadruped_release_contract.json"
$supportPath = Join-Path $repoRoot "sdk\release\quadruped_support_matrix.json"
$artifactStorePath = Join-Path $repoRoot "sdk\content_addressed_artifact_store.ps1"
. $artifactStorePath

$expectedRepoRoot = "C:\Users\Cole\CodeStuff\games\SporeSpore"
$expectedRepoRemote = "https://github.com/Slagathore/sporespore.git"
$expectedSourceCommit = "e0626fad670e74f1f6b195eb771892e7de054624"
$expectedSourceTree = "a6529241634de923ea79f090a12ae6fd8adb4c0e"
$expectedRunReceiptHash = (
    "1ab1342391ceaf972500b2221781ce52d2e266cf52ddb0c863f02c52c6c46157"
)
$expectedLogHash = (
    "2970af8bf96a5075fa3c58f0151a01565bfb375ce715256c33ee8453255e9264"
)
$expectedAttestationHash = (
    "15692faad3f5fdd20d4a8c32fbf650457120a90e398c41208d00374bc7ccfcff"
)
$expectedHistoricalGodotPath = (
    "C:\Users\Cole\CodeStuff\Misc\Godot\" +
    "Godot_v4.7-stable_mono_win64_console.exe"
)
$expectedHistoricalGodotHash = (
    "sha256:c5fc2d0bb24826a6757fa1e6bf2991effb294859c7dd03d09a122ef217484896"
)
$expectedHistoricalPowerShellPath = "C:\Program Files\PowerShell\7\pwsh.exe"
$expectedHistoricalPowerShellHash = (
    "sha256:db6dd81183fe57d22e03b911ec9a30a2fd7c40542e97743615355a6fb44f458f"
)

function Assert-R24D3FullCold {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) {
        throw "QSDK-R24D3 POST-ADOPTION FULL-COLD: $Message"
    }
}

function Get-R24D3RawSha256 {
    param([Parameter(Mandatory)][string]$Path)
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).
        Hash.ToLowerInvariant()
}

function Get-R24D3ByteSha256 {
    param([Parameter(Mandatory)][byte[]]$Bytes)
    return [Convert]::ToHexString(
        [Security.Cryptography.SHA256]::HashData($Bytes)
    ).ToLowerInvariant()
}

function Get-R24D3GitValue {
    param(
        [Parameter(Mandatory)][string]$Root,
        [Parameter(Mandatory)][string[]]$Arguments
    )
    $output = @(& git -C $Root @Arguments 2>&1)
    Assert-R24D3FullCold ($LASTEXITCODE -eq 0) (
        "git $($Arguments -join ' ') failed: $($output -join ' | ')"
    )
    return ($output -join "`n").Trim()
}

function Get-R24D3GitBlobBytes {
    param(
        [Parameter(Mandatory)][string]$Root,
        [Parameter(Mandatory)][string]$ObjectId
    )
    $start = [Diagnostics.ProcessStartInfo]::new()
    $start.FileName = "git"
    $start.UseShellExecute = $false
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    [void]$start.ArgumentList.Add("-C")
    [void]$start.ArgumentList.Add($Root)
    [void]$start.ArgumentList.Add("cat-file")
    [void]$start.ArgumentList.Add("blob")
    [void]$start.ArgumentList.Add($ObjectId)
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $start
    Assert-R24D3FullCold ($process.Start()) "Could not start git cat-file."
    $errorTask = $process.StandardError.ReadToEndAsync()
    $memory = [IO.MemoryStream]::new()
    try {
        $process.StandardOutput.BaseStream.CopyTo($memory)
        $process.WaitForExit()
        $errorText = $errorTask.GetAwaiter().GetResult()
        Assert-R24D3FullCold ($process.ExitCode -eq 0) (
            "git cat-file failed for $ObjectId`: $errorText"
        )
        return $memory.ToArray()
    }
    finally {
        $memory.Dispose()
        $process.Dispose()
    }
}

function Assert-R24D3FileIdentity {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$ExpectedSha256,
        [Parameter(Mandatory)][long]$ExpectedByteLength
    )
    Assert-R24D3FullCold (Test-Path -LiteralPath $Path -PathType Leaf) (
        "Retained file is missing: $Path"
    )
    $item = Get-Item -LiteralPath $Path
    Assert-R24D3FullCold (
        $item.Length -eq $ExpectedByteLength -and
        "sha256:$(Get-R24D3RawSha256 $Path)" -ceq $ExpectedSha256
    ) "Retained file identity changed: $Path"
}

function Test-R24D3QualificationSemantics {
    param([Parameter(Mandatory)][string]$Text)
    try {
        $value = $Text | ConvertFrom-Json -AsHashtable -Depth 100
    }
    catch {
        return $false
    }
    $source = $value.qualified_source
    $run = $value.canonical_full_cold_conformance
    $attestation = $value.durable_attestation
    $claims = $value.adequacy_and_claim_boundary
    $next = $value.next_permitted_work
    $stages = @($run.stages)
    return (
        [string]$value.schema_version -ceq
            "sporespore_qsdk_r24d3_post_adoption_full_cold_conformance_qualification_v1" -and
        [string]$value.status -ceq
            "qualified_exact_adoption_source_full_cold_conformance_characterization_withheld" -and
        [string]$source.commit -ceq $expectedSourceCommit -and
        [string]$source.tree_git_oid -ceq $expectedSourceTree -and
        [string]$run.receipt_raw_sha256 -ceq
            "sha256:$expectedRunReceiptHash" -and
        [string]$run.receipt_cas_directory -ceq (
            "C:/Users/Cole/CodeStuff/games/SporeSpore_Evidence/artifacts/" +
            "sha256/$expectedRunReceiptHash"
        ) -and
        [string]$attestation.raw_sha256 -ceq
            "sha256:$expectedAttestationHash" -and
        [string]$run.status -ceq "passed" -and
        [string]$run.tier -ceq "full_cold" -and
        [int]$run.stage_count -eq 8 -and
        $stages.Count -eq 8 -and
        [string]$stages[0].receipt_raw_sha256 -ceq
            "sha256:d54a93fe42427f6428df2bf5e4268e69a49368b9bb6228032e5ab7b3c1c93139" -and
        @($stages | Where-Object { [string]$_.status -cne "passed" }).Count -eq 0 -and
        @($stages | Where-Object { [bool]$_.result_reused }).Count -eq 0 -and
        -not [bool]$run.cache_lookup_performed -and
        -not [bool]$run.result_reused -and
        -not [bool]$run.physical_campaign_executed -and
        [bool]$claims.post_adoption_full_cold_conformance_prerequisite_satisfied -and
        -not [bool]$claims.instrumented_godot_capability_promoted -and
        -not [bool]$claims.new_physical_campaign_executed -and
        -not [bool]$claims.release_authority -and
        -not [bool]$next.recovery_world_permitted_now -and
        -not [bool]$next.prone_to_standing_world_permitted_now
    )
}

function Test-R24D3HistoricalToolchainSemantics {
    param([Parameter(Mandatory)][Collections.IDictionary]$Attestation)
    return (
        [string]$Attestation.godot.executable_path -ceq
            $expectedHistoricalGodotPath -and
        [string]$Attestation.godot.executable_sha256 -ceq
            $expectedHistoricalGodotHash -and
        [string]$Attestation.godot.version -ceq
            "4.7.stable.mono.official.5b4e0cb0f" -and
        [string]$Attestation.powershell.executable_path -ceq
            $expectedHistoricalPowerShellPath -and
        [string]$Attestation.powershell.executable_sha256 -ceq
            $expectedHistoricalPowerShellHash -and
        [string]$Attestation.powershell.version -ceq "7.6.4" -and
        [string]$Attestation.powershell.edition -ceq "Core" -and
        [string]$Attestation.powershell.process_architecture -ceq "X64"
    )
}

function Copy-R24D3HistoricalAttestation {
    param([Parameter(Mandatory)][Collections.IDictionary]$Attestation)
    return $Attestation | ConvertTo-Json -Depth 100 -Compress |
        ConvertFrom-Json -AsHashtable -Depth 100
}

foreach ($path in @(
    $qualificationPath,
    $adoptionPath,
    $manifestPath,
    $releasePath,
    $supportPath,
    $artifactStorePath
)) {
    Assert-R24D3FullCold (Test-Path -LiteralPath $path -PathType Leaf) (
        "Required authority is missing: $path"
    )
}

$root = Get-R24D3GitValue -Root $repoRoot -Arguments @(
    "rev-parse", "--show-toplevel"
)
$remote = Get-R24D3GitValue -Root $repoRoot -Arguments @(
    "remote", "get-url", "origin"
)
$branch = Get-R24D3GitValue -Root $repoRoot -Arguments @(
    "branch", "--show-current"
)
Assert-R24D3FullCold ([IO.Path]::GetFullPath($root) -ceq $expectedRepoRoot) (
    "Canonical repository root changed: $root"
)
Assert-R24D3FullCold ($remote -ceq $expectedRepoRemote) "Origin changed: $remote"
Assert-R24D3FullCold ($branch -ceq "main") "Branch changed: $branch"
[void](Get-R24D3GitValue -Root $repoRoot -Arguments @(
    "cat-file", "-e", "$expectedSourceCommit`^{commit}"
))
$observedTree = Get-R24D3GitValue -Root $repoRoot -Arguments @(
    "rev-parse", "$expectedSourceCommit`^{tree}"
)
Assert-R24D3FullCold ($observedTree -ceq $expectedSourceTree) (
    "Qualified source tree changed: $observedTree"
)
foreach ($descendant in @("HEAD", "origin/main")) {
    & git -C $repoRoot merge-base --is-ancestor $expectedSourceCommit $descendant
    Assert-R24D3FullCold ($LASTEXITCODE -eq 0) (
        "Qualified source is not an ancestor of $descendant."
    )
}
$liveLine = @(& git -C $repoRoot ls-remote origin refs/heads/main 2>&1)
Assert-R24D3FullCold ($LASTEXITCODE -eq 0 -and $liveLine.Count -eq 1) (
    "Could not resolve live origin/main: $($liveLine -join ' | ')"
)
$liveCommit = ([string]$liveLine[0] -split "\s+")[0]
[void](Get-R24D3GitValue -Root $repoRoot -Arguments @(
    "cat-file", "-e", "$liveCommit`^{commit}"
))
& git -C $repoRoot merge-base --is-ancestor $expectedSourceCommit $liveCommit
Assert-R24D3FullCold ($LASTEXITCODE -eq 0) (
    "Qualified source is not an ancestor of live origin/main."
)

$qualificationText = [IO.File]::ReadAllText($qualificationPath)
Assert-R24D3FullCold (
    Test-R24D3QualificationSemantics $qualificationText
) "Qualification semantics changed."
$qualification = $qualificationText |
    ConvertFrom-Json -AsHashtable -Depth 100
$sourceBindings = @($qualification.qualified_source.source_bindings)
Assert-R24D3FullCold (
    [int]$qualification.qualified_source.source_binding_count -eq 8 -and
    $sourceBindings.Count -eq 8
) "Qualified source-binding count changed."
$sourceBlobBytes = @{}
foreach ($binding in $sourceBindings) {
    $path = [string]$binding.path
    $objectId = Get-R24D3GitValue -Root $repoRoot -Arguments @(
        "rev-parse", "$expectedSourceCommit`:$path"
    )
    Assert-R24D3FullCold ($objectId -ceq [string]$binding.git_blob_oid) (
        "Qualified source Git blob changed: $path"
    )
    $bytes = Get-R24D3GitBlobBytes -Root $repoRoot -ObjectId $objectId
    Assert-R24D3FullCold (
        $bytes.LongLength -eq [int64]$binding.byte_length -and
        "sha256:$(Get-R24D3ByteSha256 $bytes)" -ceq
            [string]$binding.raw_sha256
    ) "Qualified source bytes changed: $path"
    $sourceBlobBytes[$path] = $bytes
}

$adoptionBytes = [byte[]]$sourceBlobBytes[
    "sdk/recovery/r24d3_godot_jolt_motor_telemetry_cold_qualification_adoption_v2.json"
]
$adoption = [Text.Encoding]::UTF8.GetString($adoptionBytes) |
    ConvertFrom-Json -AsHashtable -Depth 100
Assert-R24D3FullCold (
    [string]$adoption.status -ceq
        "adopted_artifact_complete_cold_build_characterization_withheld" -and
    [bool]$adoption.adopted_claim_boundary.clean_pushed_cold_build_qualified -and
    -not [bool]$adoption.reproducibility_and_reuse_boundary.result_reuse_authority -and
    -not [bool]$adoption.adopted_claim_boundary.instrumented_godot_capability_promoted -and
    -not [bool]$adoption.adopted_claim_boundary.release_authority
) "Artifact-complete adoption was reinterpreted."

$run = $qualification.canonical_full_cold_conformance
$receiptPath = [IO.Path]::GetFullPath([string]$run.receipt_path)
$logPath = [IO.Path]::GetFullPath([string]$run.log_path)
Assert-R24D3FileIdentity -Path $receiptPath `
    -ExpectedSha256 ([string]$run.receipt_raw_sha256) `
    -ExpectedByteLength ([long]$run.receipt_byte_length)
Assert-R24D3FileIdentity -Path $logPath `
    -ExpectedSha256 ([string]$run.log_raw_sha256) `
    -ExpectedByteLength ([long]$run.log_byte_length)
Assert-R24D3FullCold (
    Test-SporeSporeStoredArtifact `
        -Directory ([string]$run.receipt_cas_directory) `
        -ExpectedSha256 $expectedRunReceiptHash `
        -ExpectedByteLength ([long]$run.receipt_byte_length)
) "Canonical run-receipt CAS object changed."
Assert-R24D3FullCold (
    Test-SporeSporeStoredArtifact `
        -Directory ([string]$run.log_cas_directory) `
        -ExpectedSha256 $expectedLogHash `
        -ExpectedByteLength ([long]$run.log_byte_length)
) "Canonical conformance-log CAS object changed."

$receipt = Get-Content -Raw -LiteralPath $receiptPath |
    ConvertFrom-Json -AsHashtable -Depth 100
$trueClaims = @($receipt.claims.GetEnumerator() | Where-Object {
    [bool]$_.Value
})
Assert-R24D3FullCold (
    [string]$receipt.schema_version -ceq
        "sporespore_conformance_run_observation_v1" -and
    [string]$receipt.run_id -ceq [string]$run.run_id -and
    [string]$receipt.status -ceq "passed" -and
    [string]$receipt.tier -ceq "full_cold" -and
    -not [bool]$receipt.test_only -and
    [string]$receipt.source.head -ceq $expectedSourceCommit -and
    [string]$receipt.source.head_tree -ceq $expectedSourceTree -and
    [string]$receipt.source.origin_main -ceq $expectedSourceCommit -and
    [string]$receipt.source.remote_url -ceq $expectedRepoRemote -and
    [bool]$receipt.source.worktree_clean -and
    [string]$receipt.input_identity.status -ceq "observed_not_transitive" -and
    -not [bool]$receipt.input_identity.transitive_dependency_key_complete -and
    [string]$receipt.cache.status -ceq "disabled_uncommissioned" -and
    -not [bool]$receipt.cache.lookup_performed -and
    -not [bool]$receipt.cache.result_reused -and
    -not [bool]$receipt.cache.reuse_authority -and
    [bool]$receipt.cache.full_source_exact_conformance_remains_required -and
    $trueClaims.Count -eq 0 -and
    @($receipt.stage_receipts).Count -eq 8
) "Canonical full-cold receipt semantics changed."

$declaredStages = @($run.stages)
$observedStages = @($receipt.stage_receipts)
for ($index = 0; $index -lt $declaredStages.Count; $index++) {
    $declared = $declaredStages[$index]
    $observed = $observedStages[$index]
    Assert-R24D3FullCold (
        [int]$observed.ordinal -eq [int]$declared.ordinal -and
        [string]$observed.stage_id -ceq [string]$declared.stage_id -and
        [string]$observed.status -ceq "passed" -and
        [double]$observed.duration_seconds -eq
            [double]$declared.duration_seconds -and
        [string]$observed.receipt_raw_sha256 -ceq
            [string]$declared.receipt_raw_sha256 -and
        -not [bool]$observed.result_reused
    ) "Stage receipt changed at ordinal $($index + 1)."
    $stagePath = [IO.Path]::GetFullPath([string]$observed.receipt_path)
    Assert-R24D3FileIdentity -Path $stagePath `
        -ExpectedSha256 ([string]$declared.receipt_raw_sha256) `
        -ExpectedByteLength ([long]$declared.receipt_byte_length)
    $stageDigest = ([string]$declared.receipt_raw_sha256).Substring(7)
    $stageCasDirectory = Split-Path -Parent (
        [string]$observed.receipt_cas_payload_path
    )
    Assert-R24D3FullCold (
        Test-SporeSporeStoredArtifact `
            -Directory $stageCasDirectory `
            -ExpectedSha256 $stageDigest `
            -ExpectedByteLength ([long]$declared.receipt_byte_length)
    ) "Stage CAS object changed at ordinal $($index + 1)."
}

$logText = [IO.File]::ReadAllText($logPath)
foreach ($entry in @(
    @("QSDK_R24D3_GODOT_JOLT_MOTOR_TELEMETRY_SOURCE_PASS", 1),
    @("QSDK_R24D3_COLD_QUALIFICATION_ADOPTION_PASS", 1),
    @("SDK C0/C1 conformance passed.", 1)
)) {
    $count = ([regex]::Matches(
        $logText,
        [regex]::Escape([string]$entry[0])
    )).Count
    Assert-R24D3FullCold ($count -eq [int]$entry[1]) (
        "Canonical log marker count changed: $($entry[0])=$count"
    )
}

$attestation = $qualification.durable_attestation
$attestationPath = [IO.Path]::GetFullPath([string]$attestation.path)
Assert-R24D3FileIdentity -Path $attestationPath `
    -ExpectedSha256 ([string]$attestation.raw_sha256) `
    -ExpectedByteLength ([long]$attestation.byte_length)
$attestationDocument = Get-Content -Raw -LiteralPath $attestationPath |
    ConvertFrom-Json -AsHashtable -Depth 64
$attestationTrueClaims = @(
    $attestationDocument.claims.GetEnumerator() | Where-Object {
        [bool]$_.Value
    }
)
$expectedAttestationBindings = @(
    $sourceBindings | Where-Object {
        [string]$_.path -in @(
            "sdk/run_conformance.ps1",
            "sdk/locomotion_operation_lock.ps1",
            "sdk/locomotion_full_conformance_attestation.ps1",
            "sdk/locomotion_operation_attestation_contract.json"
        )
    } | ForEach-Object {
        [ordered]@{
            path = [string]$_.path
            raw_sha256 = [string]$_.raw_sha256
            git_blob_oid = [string]$_.git_blob_oid
        }
    }
)
Assert-R24D3FullCold (
    [string]$attestationDocument.schema_version -ceq
        "sporespore_full_godot_conformance_attestation_v2" -and
    [string]$attestationDocument.status -ceq "full_godot_conformance_passed" -and
    -not [bool]$attestationDocument.test_only -and
    [bool]$attestationDocument.conformance.passed -and
    -not [bool]$attestationDocument.conformance.skip_godot -and
    [bool]$attestationDocument.conformance.godot_including -and
    [bool]$attestationDocument.conformance.regression_test_physics_permitted -and
    -not [bool]$attestationDocument.conformance.one_shot_physical_campaign_executed -and
    [string]$attestationDocument.source.commit -ceq $expectedSourceCommit -and
    [string]$attestationDocument.source.tree_git_oid -ceq $expectedSourceTree -and
    [string]$attestationDocument.source.origin_main -ceq $expectedSourceCommit -and
    [string]$attestationDocument.source.live_github_main -ceq
        $expectedSourceCommit -and
    [bool]$attestationDocument.source.worktree_clean -and
    [bool]$attestationDocument.source.clean_pushed_live -and
    [string]$attestationDocument.operation_lock.role -ceq "conformance" -and
    [string]$attestationDocument.operation_lock.mutex_name -ceq
        "Global\SporeSpore.Locomotion.PhysicalConformance.Serial.v1" -and
    -not [bool]$attestationDocument.operation_lock.test_only -and
    $attestationTrueClaims.Count -eq 0 -and
    ((@($attestationDocument.source_bindings) |
        ConvertTo-Json -Depth 16 -Compress) -ceq
        ($expectedAttestationBindings |
        ConvertTo-Json -Depth 16 -Compress))
) "Durable historical attestation semantics changed."

Assert-R24D3FullCold (
    Test-R24D3HistoricalToolchainSemantics $attestationDocument
) "Historical toolchain observation changed."

# The finite attestation records the exact executables observed on 2026-08-16.
# It does not retain those executables and therefore cannot re-prove their bytes
# by dereferencing a mutable installation path. Requiring today's pwsh.exe to
# equal the recorded PowerShell 7.6.4 bytes invalidates the historical audit
# whenever PowerShell is upgraded. The outer conformance receipt independently
# keys the current runtime; this audit verifies the content-addressed historical
# attestation and rejects changes to every recorded toolchain identity instead.
$historicalToolchainMutations = @(
    @{ name = "godot_path"; apply = {
        param($a) $a.godot.executable_path = "C:\other\godot.exe"
    } },
    @{ name = "godot_hash"; apply = {
        param($a) $a.godot.executable_sha256 = "sha256:" + ("0" * 64)
    } },
    @{ name = "powershell_path"; apply = {
        param($a) $a.powershell.executable_path = "C:\other\pwsh.exe"
    } },
    @{ name = "powershell_hash"; apply = {
        param($a) $a.powershell.executable_sha256 = "sha256:" + ("1" * 64)
    } },
    @{ name = "powershell_version"; apply = {
        param($a) $a.powershell.version = "7.6.5"
    } }
)
foreach ($mutation in $historicalToolchainMutations) {
    $candidate = Copy-R24D3HistoricalAttestation $attestationDocument
    & $mutation.apply $candidate
    Assert-R24D3FullCold (
        -not (Test-R24D3HistoricalToolchainSemantics $candidate)
    ) "Historical toolchain mutation was accepted: $($mutation.name)"
}

$streams = $qualification.supplemental_wrapper_streams
Assert-R24D3FileIdentity -Path ([string]$streams.stdout_path) `
    -ExpectedSha256 ([string]$streams.stdout_raw_sha256) `
    -ExpectedByteLength ([long]$streams.stdout_byte_length)
Assert-R24D3FileIdentity -Path ([string]$streams.stderr_path) `
    -ExpectedSha256 ([string]$streams.stderr_raw_sha256) `
    -ExpectedByteLength ([long]$streams.stderr_byte_length)
Assert-R24D3FullCold (
    -not [bool]$streams.canonical_result_depends_on_these_streams -and
    [int]$streams.wrapper_exit_code -eq 0 -and
    [bool]$streams.stderr_contains_test_runner_progress_not_terminal_failure
) "Supplemental wrapper-stream boundary changed."

$manifest = Get-Content -Raw -LiteralPath $manifestPath |
    ConvertFrom-Json -AsHashtable -Depth 100
$manifestPaths = @($manifest.source_bindings | ForEach-Object {
    [string]$_.path
})
Assert-R24D3FullCold (
    [string]$manifest.gate_id -ceq "QSDK-R24D3" -and
    [int]$manifest.source_binding_count -eq 14 -and
    $manifestPaths.Contains(
        "sdk/recovery/r24d3_godot_jolt_motor_telemetry_post_adoption_full_cold_conformance_qualification_v1.json"
    ) -and
    $manifestPaths.Contains(
        "tests/test_qsdk_r24d3_godot_jolt_motor_telemetry_post_adoption_full_cold_conformance_qualification.ps1"
    ) -and
    -not [bool]$manifest.instrumented_capability_promoted -and
    -not [bool]$manifest.release_authority
) "Live R24D3 validation manifest boundary changed."

$release = Get-Content -Raw -LiteralPath $releasePath |
    ConvertFrom-Json -AsHashtable -Depth 100
$support = Get-Content -Raw -LiteralPath $supportPath |
    ConvertFrom-Json -AsHashtable -Depth 100
$releaseR24 = @($release.gates | Where-Object {
    [string]$_.gate_id -ceq "QSDK-R24"
})
Assert-R24D3FullCold ($releaseR24.Count -eq 1) "Release QSDK-R24 count changed."
$releaseR24D3 = $releaseR24[0].proof.active_zero_world_boundary.
    instrumented_godot_motor_telemetry_source_boundary
$matrixR24D3 = $support.locomotion_modes.canonical_prone_to_standing_design.
    instrumented_godot_motor_telemetry_source_boundary
Assert-R24D3FullCold (
    [string]$releaseR24[0].proof.kind -ceq "missing" -and
    [string]$releaseR24D3.status -ceq
        "artifact_complete_cold_build_and_post_adoption_full_conformance_qualified_characterization_withheld" -and
    [bool]$releaseR24D3.clean_pushed_cold_build_qualified -and
    [bool]$releaseR24D3.post_adoption_full_cold_conformance_qualified -and
    [string]$releaseR24D3.post_adoption_full_cold_source_commit -ceq
        $expectedSourceCommit -and
    [string]$releaseR24D3.post_adoption_full_cold_receipt_raw_sha256 -ceq
        "sha256:$expectedRunReceiptHash" -and
    [string]$releaseR24D3.post_adoption_full_cold_attestation_raw_sha256 -ceq
        "sha256:$expectedAttestationHash" -and
    [int]$releaseR24D3.post_adoption_full_cold_stage_count -eq 8 -and
    -not [bool]$releaseR24D3.result_reuse_authority -and
    -not [bool]$releaseR24D3.instrumented_native_sign_characterized -and
    -not [bool]$releaseR24D3.instrumented_godot_capability_promoted -and
    -not [bool]$releaseR24D3.native_capability_conjunction_complete -and
    -not [bool]$releaseR24D3.q_sdk_r24_satisfied -and
    -not [bool]$releaseR24D3.release_authority -and
    (($releaseR24D3 | ConvertTo-Json -Depth 50 -Compress) -ceq
        ($matrixR24D3 | ConvertTo-Json -Depth 50 -Compress))
) "Release/support full-cold qualification boundary changed."

# Build the intentionally absent CAS digest at runtime. The conformance
# dependency inventory treats every literal artifacts/sha256/<digest> path as
# a live dependency and must continue to fail closed on a genuinely missing
# retained object; this mutation is test input, not a declared dependency.
$missingCasMutationDigest = "3" * 64
$mutationCases = [ordered]@{
    qualified_source_commit_mutation_rejected = @(
        $expectedSourceCommit,
        "0000000000000000000000000000000000000000"
    )
    qualified_source_tree_mutation_rejected = @(
        $expectedSourceTree,
        "1111111111111111111111111111111111111111"
    )
    run_receipt_digest_mutation_rejected = @(
        $expectedRunReceiptHash,
        "2222222222222222222222222222222222222222222222222222222222222222"
    )
    run_receipt_cas_mutation_rejected = @(
        '"receipt_cas_directory": "C:/Users/Cole/CodeStuff/games/SporeSpore_Evidence/artifacts/sha256/1ab1342391ceaf972500b2221781ce52d2e266cf52ddb0c863f02c52c6c46157"',
        ('"receipt_cas_directory": "C:/Users/Cole/CodeStuff/games/SporeSpore_Evidence/artifacts/sha256/' +
            $missingCasMutationDigest + '"')
    )
    attestation_digest_mutation_rejected = @(
        $expectedAttestationHash,
        "4444444444444444444444444444444444444444444444444444444444444444"
    )
    stage_status_mutation_rejected = @(
        '"status": "passed"',
        '"status": "failed"'
    )
    stage_digest_mutation_rejected = @(
        "d54a93fe42427f6428df2bf5e4268e69a49368b9bb6228032e5ab7b3c1c93139",
        "5555555555555555555555555555555555555555555555555555555555555555"
    )
    cache_lookup_promotion_mutation_rejected = @(
        '"cache_lookup_performed": false',
        '"cache_lookup_performed": true'
    )
    result_reuse_promotion_mutation_rejected = @(
        '"result_reused": false',
        '"result_reused": true'
    )
    physical_campaign_promotion_mutation_rejected = @(
        '"new_physical_campaign_executed": false',
        '"new_physical_campaign_executed": true'
    )
    instrumented_capability_promotion_mutation_rejected = @(
        '"instrumented_godot_capability_promoted": false',
        '"instrumented_godot_capability_promoted": true'
    )
    full_cold_prerequisite_reversal_mutation_rejected = @(
        '"post_adoption_full_cold_conformance_prerequisite_satisfied": true',
        '"post_adoption_full_cold_conformance_prerequisite_satisfied": false'
    )
}
Assert-R24D3FullCold ($mutationCases.Count -eq 12) (
    "Qualification mutation inventory changed."
)
Assert-R24D3FullCold (
    (@($mutationCases.Keys) -join "|") -ceq
        (@($qualification.negative_controls.required_rejections) -join "|")
) "Qualification mutation names diverged from the record."
foreach ($entry in $mutationCases.GetEnumerator()) {
    $from = [string]$entry.Value[0]
    $to = [string]$entry.Value[1]
    Assert-R24D3FullCold (
        $qualificationText.Contains($from, [StringComparison]::Ordinal)
    ) "Qualification mutation source is absent: $($entry.Key)"
    $mutated = $qualificationText.Replace(
        $from,
        $to,
        [StringComparison]::Ordinal
    )
    Assert-R24D3FullCold (
        -not (Test-R24D3QualificationSemantics $mutated)
    ) "Qualification mutation was not rejected: $($entry.Key)"
}

$result = [ordered]@{
    schema_version = (
        "sporespore_qsdk_r24d3_post_adoption_full_cold_" +
        "conformance_qualification_audit_receipt_v1"
    )
    ok = $true
    gate_id = "QSDK-R24D3"
    question_class = "non_physical_conformance_qualification"
    result = "complete_valid_positive_non_physical_full_cold_conformance"
    source_commit = $expectedSourceCommit
    source_binding_count = 8
    stage_count = 8
    passed_stage_count = 8
    duration_seconds = [double]$run.duration_seconds
    canonical_receipt_sha256 = "sha256:$expectedRunReceiptHash"
    durable_attestation_sha256 = "sha256:$expectedAttestationHash"
    content_addressed_receipt_and_log = $true
    cache_status = "disabled_uncommissioned"
    result_reused = $false
    negative_control_count = 12
    negative_controls_passed = 12
    historical_toolchain_record_count = 2
    historical_toolchain_record_mutation_count = $historicalToolchainMutations.Count
    historical_toolchain_live_path_revalidation_required = $false
    current_runtime_bound_by_outer_conformance = $true
    post_adoption_full_cold_conformance_prerequisite_satisfied = $true
    instrumented_native_telemetry_characterized = $false
    instrumented_capability_promoted = $false
    physical_campaign_executed = $false
    prone_to_standing_claimed = $false
    q_sdk_r24_satisfied = $false
    physical_acceptance_authority = $false
    release_authority = $false
}
Write-Output (
    "QSDK_R24D3_POST_ADOPTION_FULL_COLD_CONFORMANCE_QUALIFICATION_PASS " +
    ($result | ConvertTo-Json -Depth 20 -Compress)
)
