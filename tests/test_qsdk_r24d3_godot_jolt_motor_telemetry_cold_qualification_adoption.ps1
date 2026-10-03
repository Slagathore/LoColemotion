#requires -Version 7.0

[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$adoptionPath = Join-Path $repoRoot (
    "sdk\recovery\" +
    "r24d3_godot_jolt_motor_telemetry_cold_qualification_adoption_v2.json"
)
$successorPath = Join-Path $repoRoot (
    "sdk\recovery\" +
    "r24d3_godot_jolt_motor_telemetry_artifact_complete_successor_v2.json"
)
$manifestPath = Join-Path $repoRoot (
    "sdk\recovery\r24d3_godot_jolt_motor_telemetry_source_validation_manifest.json"
)
$releasePath = Join-Path $repoRoot "sdk\release\quadruped_release_contract.json"
$supportPath = Join-Path $repoRoot "sdk\release\quadruped_support_matrix.json"
$expectedRepoRoot = "C:\Users\Cole\CodeStuff\games\SporeSpore"
$expectedRepoRemote = "https://github.com/Slagathore/sporespore.git"
$expectedSourceCommit = "2ca77925147db4ef381737b17aedc4af723130b4"
$expectedReceiptHash = (
    "a72e1c6c5b51799bec46fe76737ea23f9998c0af6778bb52dc0b7ed2cd9f36d9"
)
$expectedEngineHash = (
    "d0bb895b996fa98ec69a68b9f98ca6ed99af2eb18ef67a0b176ad1a55220278d"
)

function Assert-R24D3Adoption {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw "QSDK-R24D3 ADOPTION: $Message" }
}

function Get-RawSha256 {
    param([Parameter(Mandatory)][string]$Path)
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Get-ByteSha256 {
    param([Parameter(Mandatory)][byte[]]$Bytes)
    return [Convert]::ToHexString(
        [Security.Cryptography.SHA256]::HashData($Bytes)
    ).ToLowerInvariant()
}

function Get-GitValue {
    param(
        [Parameter(Mandatory)][string]$Root,
        [Parameter(Mandatory)][string[]]$Arguments
    )
    $output = @(& git -C $Root @Arguments 2>&1)
    Assert-R24D3Adoption ($LASTEXITCODE -eq 0) (
        "git $($Arguments -join ' ') failed: $($output -join ' | ')"
    )
    return ($output -join "`n").Trim()
}

function Get-GitBlobBytes {
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
    Assert-R24D3Adoption ($process.Start()) "Could not start git cat-file."
    $errorTask = $process.StandardError.ReadToEndAsync()
    $memory = [IO.MemoryStream]::new()
    try {
        $process.StandardOutput.BaseStream.CopyTo($memory)
        $process.WaitForExit()
        $errorText = $errorTask.GetAwaiter().GetResult()
        Assert-R24D3Adoption ($process.ExitCode -eq 0) (
            "git cat-file failed for $ObjectId`: $errorText"
        )
        return $memory.ToArray()
    }
    finally {
        $memory.Dispose()
        $process.Dispose()
    }
}

function Test-AdoptionSemantics {
    param([Parameter(Mandatory)][string]$Text)
    try {
        $value = $Text | ConvertFrom-Json -AsHashtable -Depth 100
    }
    catch {
        return $false
    }
    $source = $value.source_freeze
    $evidence = $value.retained_evidence
    $observed = $value.observed_gate
    $reuse = $value.reproducibility_and_reuse_boundary
    $claims = $value.adopted_claim_boundary
    return (
        [string]$value.schema_version -ceq
            "sporespore_qsdk_r24d3_artifact_complete_cold_qualification_adoption_v2" -and
        [string]$value.status -ceq
            "adopted_artifact_complete_cold_build_characterization_withheld" -and
        [string]$source.commit -ceq $expectedSourceCommit -and
        [string]$evidence.receipt_raw_sha256 -ceq
            "sha256:$expectedReceiptHash" -and
        [string]$evidence.engine_binary_raw_sha256 -ceq
            "sha256:$expectedEngineHash" -and
        [int]$evidence.retained_binary_count -eq 2 -and
        [bool]$evidence.execution_used_retained_binary_pair -and
        [int]$observed.world_build_count -eq 0 -and
        [int]$observed.solver_step_count -eq 0 -and
        -not [bool]$reuse.console_binary_hash_repeat_equal -and
        -not [bool]$reuse.reproducible_build_claimed -and
        -not [bool]$reuse.result_reuse_authority -and
        [bool]$claims.clean_pushed_cold_build_qualified -and
        [bool]$claims.artifact_complete_binary_pair_retained -and
        -not [bool]$claims.instrumented_godot_capability_promoted -and
        -not [bool]$claims.physical_question_opened -and
        -not [bool]$claims.release_authority
    )
}

foreach ($path in @(
    $adoptionPath,
    $successorPath,
    $manifestPath,
    $releasePath,
    $supportPath
)) {
    Assert-R24D3Adoption (Test-Path -LiteralPath $path -PathType Leaf) (
        "Required authority is missing: $path"
    )
}

$root = Get-GitValue -Root $repoRoot -Arguments @("rev-parse", "--show-toplevel")
$remote = Get-GitValue -Root $repoRoot -Arguments @("remote", "get-url", "origin")
$branch = Get-GitValue -Root $repoRoot -Arguments @("branch", "--show-current")
Assert-R24D3Adoption ([IO.Path]::GetFullPath($root) -ceq $expectedRepoRoot) (
    "Canonical repository root changed: $root"
)
Assert-R24D3Adoption ($remote -ceq $expectedRepoRemote) "Origin changed: $remote"
Assert-R24D3Adoption ($branch -ceq "main") "Branch changed: $branch"
[void](Get-GitValue -Root $repoRoot -Arguments @("cat-file", "-e", "$expectedSourceCommit`^{commit}"))
& git -C $repoRoot merge-base --is-ancestor $expectedSourceCommit HEAD
Assert-R24D3Adoption ($LASTEXITCODE -eq 0) "Source freeze is not an ancestor of HEAD."
& git -C $repoRoot merge-base --is-ancestor $expectedSourceCommit origin/main
Assert-R24D3Adoption ($LASTEXITCODE -eq 0) (
    "Source freeze is not an ancestor of the locally fetched origin/main."
)

$adoptionText = [IO.File]::ReadAllText($adoptionPath)
Assert-R24D3Adoption (Test-AdoptionSemantics $adoptionText) (
    "Adoption semantics changed."
)
$adoption = $adoptionText | ConvertFrom-Json -AsHashtable -Depth 100
$successor = Get-Content -Raw -LiteralPath $successorPath |
    ConvertFrom-Json -AsHashtable -Depth 100
$manifest = Get-Content -Raw -LiteralPath $manifestPath |
    ConvertFrom-Json -AsHashtable -Depth 100
$release = Get-Content -Raw -LiteralPath $releasePath |
    ConvertFrom-Json -AsHashtable -Depth 100
$support = Get-Content -Raw -LiteralPath $supportPath |
    ConvertFrom-Json -AsHashtable -Depth 100

Assert-R24D3Adoption (
    [string]$successor.immutable_predecessor_observation.receipt_raw_sha256 -ceq
        "sha256:6b1c507e07024912d33171f859fc8c0fe5937b00bf67e372a2414dc42fd4b4b1" -and
    -not [bool]$successor.predecessor_adequacy_disposition.artifact_complete_qualification -and
    -not [bool]$successor.predecessor_adequacy_disposition.post_hoc_hash_or_copy_may_repair_original_receipt -and
    [string]$successor.successor_receipt_contract.schema_version -ceq
        [string]$adoption.retained_evidence.receipt_schema -and
    [int]$successor.successor_receipt_contract.required_retained_binary_count -eq 2
) "The immutable v1 disposition or v2 successor requirement changed."

$sourceBindings = @($adoption.source_freeze.bindings)
Assert-R24D3Adoption ($sourceBindings.Count -eq 8) (
    "Source-freeze binding count changed."
)
foreach ($binding in $sourceBindings) {
    $path = [string]$binding.path
    $objectId = Get-GitValue -Root $repoRoot -Arguments @(
        "rev-parse",
        "$expectedSourceCommit`:$path"
    )
    Assert-R24D3Adoption ($objectId -ceq [string]$binding.git_blob_oid) (
        "Source-freeze Git blob changed: $path"
    )
    $bytes = Get-GitBlobBytes -Root $repoRoot -ObjectId $objectId
    Assert-R24D3Adoption (
        $bytes.LongLength -eq [int64]$binding.byte_length -and
        "sha256:$(Get-ByteSha256 $bytes)" -ceq [string]$binding.raw_sha256
    ) "Source-freeze raw bytes changed: $path"
}

$evidence = $adoption.retained_evidence
$evidenceFiles = @(
    @($evidence.receipt_path, $evidence.receipt_raw_sha256, $evidence.receipt_byte_length),
    @($evidence.clean_log_path, $evidence.clean_log_raw_sha256, $evidence.clean_log_byte_length),
    @($evidence.build_log_path, $evidence.build_log_raw_sha256, $evidence.build_log_byte_length),
    @($evidence.source_audit_log_path, $evidence.source_audit_log_raw_sha256, $evidence.source_audit_log_byte_length),
    @($evidence.binding_log_path, $evidence.binding_log_raw_sha256, $evidence.binding_log_byte_length),
    @($evidence.console_binary_path, $evidence.console_binary_raw_sha256, $evidence.console_binary_byte_length),
    @($evidence.engine_binary_path, $evidence.engine_binary_raw_sha256, $evidence.engine_binary_byte_length)
)
foreach ($entry in $evidenceFiles) {
    $path = [string]$entry[0]
    Assert-R24D3Adoption (Test-Path -LiteralPath $path -PathType Leaf) (
        "Retained evidence is missing: $path"
    )
    $item = Get-Item -LiteralPath $path
    Assert-R24D3Adoption (
        $item.Length -eq [int64]$entry[2] -and
        "sha256:$(Get-RawSha256 $path)" -ceq [string]$entry[1]
    ) "Retained evidence identity changed: $path"
}

$receipt = Get-Content -Raw -LiteralPath ([string]$evidence.receipt_path) |
    ConvertFrom-Json -AsHashtable -Depth 100
Assert-R24D3Adoption (
    [string]$receipt.schema_version -ceq [string]$evidence.receipt_schema -and
    [bool]$receipt.ok -and
    [string]$receipt.result -ceq
        "compile_and_zero_world_binding_pass_characterization_withheld" -and
    [string]$receipt.source.head -ceq $expectedSourceCommit -and
    [string]$receipt.source.upstream -ceq $expectedSourceCommit -and
    [string]$receipt.source.live_main -ceq $expectedSourceCommit -and
    [bool]$receipt.source.clean -and
    [bool]$receipt.source.clean_pushed_required -and
    [string]$receipt.source.patch_sha256 -ceq
        [string]$adoption.source_freeze.patch_raw_sha256 -and
    [string]$receipt.source.source_diff_sha256 -ceq
        [string]$adoption.source_freeze.patch_raw_sha256 -and
    [bool]$receipt.toolchain.cold_build -and
    [int]$receipt.artifacts.retained_binary_count -eq 2 -and
    [bool]$receipt.artifacts.execution_used_retained_binary_pair -and
    [string]$receipt.artifacts.execution_console_binary_path -ceq
        [string]$evidence.console_binary_path -and
    [string]$receipt.artifacts.console_binary_sha256 -ceq
        [string]$evidence.console_binary_raw_sha256 -and
    [string]$receipt.artifacts.engine_binary_sha256 -ceq
        [string]$evidence.engine_binary_raw_sha256 -and
    [int]$receipt.binding_assertion_count -eq 6 -and
    [int]$receipt.binding_failed_assertion_count -eq 0 -and
    [bool]$receipt.invalid_rid_refused -and
    [int]$receipt.world_build_count -eq 0 -and
    [int]$receipt.solver_step_count -eq 0 -and
    -not [bool]$receipt.instrumented_capability_promoted -and
    -not [bool]$receipt.release_authority
) "Retained v2 receipt semantics changed."

$sourceAuditLog = Get-Content -Raw -LiteralPath ([string]$evidence.source_audit_log_path)
$bindingLog = Get-Content -Raw -LiteralPath ([string]$evidence.binding_log_path)
Assert-R24D3Adoption (
    $sourceAuditLog.Contains(
        '"artifact_retention_negative_controls_passed":6',
        [StringComparison]::Ordinal
    ) -and
    $bindingLog.Contains(
        "QSDK_R24D3_GODOT_BINDING_ZERO_WORLD passed=6 failed=0 world_build_count=0 solver_step_count=0",
        [StringComparison]::Ordinal
    )
) "Retained source-audit or binding marker changed."

$releaseR24 = @($release.gates | Where-Object { [string]$_.gate_id -ceq "QSDK-R24" })
Assert-R24D3Adoption ($releaseR24.Count -eq 1) "Release QSDK-R24 gate count changed."
$releaseR24D3 = $releaseR24[0].proof.active_zero_world_boundary.instrumented_godot_motor_telemetry_source_boundary
$matrixR24D3 = $support.locomotion_modes.canonical_prone_to_standing_design.instrumented_godot_motor_telemetry_source_boundary
Assert-R24D3Adoption (
    [string]$releaseR24[0].proof.kind -ceq "missing" -and
    [string]$releaseR24D3.status -ceq
        "artifact_complete_cold_build_and_post_adoption_full_conformance_qualified_characterization_withheld" -and
    [int]$releaseR24D3.cold_build_attempt_count -eq 2 -and
    [bool]$releaseR24D3.artifact_complete_successor_observed -and
    -not [bool]$releaseR24D3.artifact_complete_successor_required -and
    [string]$releaseR24D3.artifact_complete_receipt_raw_sha256 -ceq
        "sha256:$expectedReceiptHash" -and
    [string]$releaseR24D3.artifact_complete_engine_binary_raw_sha256 -ceq
        "sha256:$expectedEngineHash" -and
    [int]$releaseR24D3.retained_binary_count -eq 2 -and
    [bool]$releaseR24D3.execution_used_retained_binary_pair -and
    [bool]$releaseR24D3.clean_pushed_cold_build_qualified -and
    [bool]$releaseR24D3.post_adoption_full_cold_conformance_qualified -and
    [string]$releaseR24D3.post_adoption_full_cold_source_commit -ceq
        "e0626fad670e74f1f6b195eb771892e7de054624" -and
    [string]$releaseR24D3.post_adoption_full_cold_receipt_raw_sha256 -ceq
        "sha256:1ab1342391ceaf972500b2221781ce52d2e266cf52ddb0c863f02c52c6c46157" -and
    [int]$releaseR24D3.post_adoption_full_cold_stage_count -eq 8 -and
    -not [bool]$releaseR24D3.post_adoption_full_cold_result_reused -and
    -not [bool]$releaseR24D3.post_adoption_full_cold_physical_campaign_executed -and
    -not [bool]$releaseR24D3.reproducible_build_claimed -and
    -not [bool]$releaseR24D3.result_reuse_authority -and
    -not [bool]$releaseR24D3.instrumented_native_sign_characterized -and
    -not [bool]$releaseR24D3.instrumented_godot_capability_promoted -and
    -not [bool]$releaseR24D3.native_capability_conjunction_complete -and
    [int]$releaseR24D3.world_build_count -eq 0 -and
    -not [bool]$releaseR24D3.q_sdk_r24_satisfied -and
    -not [bool]$releaseR24D3.release_authority -and
    (($releaseR24D3 | ConvertTo-Json -Depth 50 -Compress) -ceq
        ($matrixR24D3 | ConvertTo-Json -Depth 50 -Compress))
) "Release/support adoption boundary changed or diverged."

$manifestBindings = @($manifest.source_bindings)
Assert-R24D3Adoption (
    [string]$manifest.gate_id -ceq "QSDK-R24D3" -and
    [int]$manifest.source_binding_count -eq 14 -and
    $manifestBindings.Count -eq 14 -and
    @($manifestBindings | Where-Object {
        [string]$_.path -ceq
            "sdk/recovery/r24d3_godot_jolt_motor_telemetry_post_adoption_full_cold_conformance_qualification_v1.json"
    }).Count -eq 1 -and
    @($manifestBindings | Where-Object {
        [string]$_.path -ceq
            "tests/test_qsdk_r24d3_godot_jolt_motor_telemetry_post_adoption_full_cold_conformance_qualification.ps1"
    }).Count -eq 1 -and
    -not [bool]$manifest.includes_self -and
    [int]$manifest.world_build_count -eq 0 -and
    -not [bool]$manifest.instrumented_capability_promoted -and
    -not [bool]$manifest.release_authority
) "Live R24D3 validation manifest boundary changed."
foreach ($binding in $manifestBindings) {
    $path = Join-Path $repoRoot ([string]$binding.path)
    Assert-R24D3Adoption (Test-Path -LiteralPath $path -PathType Leaf) (
        "Manifest source is missing: $($binding.path)"
    )
    $item = Get-Item -LiteralPath $path
    Assert-R24D3Adoption (
        $item.Length -eq [int64]$binding.byte_length -and
        "sha256:$(Get-RawSha256 $path)" -ceq [string]$binding.raw_sha256
    ) "Manifest source binding changed: $($binding.path)"
}

$mutationCases = [ordered]@{
    source_commit_mutation_rejected = @(
        $expectedSourceCommit,
        "0000000000000000000000000000000000000000"
    )
    receipt_digest_mutation_rejected = @(
        $expectedReceiptHash,
        "0000000000000000000000000000000000000000000000000000000000000000"
    )
    engine_digest_mutation_rejected = @(
        $expectedEngineHash,
        "1111111111111111111111111111111111111111111111111111111111111111"
    )
    single_binary_retention_mutation_rejected = @(
        '"retained_binary_count": 2',
        '"retained_binary_count": 1'
    )
    world_count_mutation_rejected = @(
        '"world_build_count": 0',
        '"world_build_count": 1'
    )
    instrumented_capability_promotion_mutation_rejected = @(
        '"instrumented_godot_capability_promoted": false',
        '"instrumented_godot_capability_promoted": true'
    )
    result_reuse_promotion_mutation_rejected = @(
        '"result_reuse_authority": false',
        '"result_reuse_authority": true'
    )
    predecessor_reinterpretation_mutation_rejected = @(
        '"console_binary_hash_repeat_equal": false',
        '"console_binary_hash_repeat_equal": true'
    )
}
Assert-R24D3Adoption ($mutationCases.Count -eq 8) (
    "Adoption mutation inventory changed."
)
Assert-R24D3Adoption (
    (@($mutationCases.Keys) -join "|") -ceq
        (@($adoption.negative_controls.required_rejections) -join "|")
) "Adoption mutation names diverged from the contract."
foreach ($entry in $mutationCases.GetEnumerator()) {
    $from = [string]$entry.Value[0]
    $to = [string]$entry.Value[1]
    Assert-R24D3Adoption (
        $adoptionText.Contains($from, [StringComparison]::Ordinal)
    ) "Adoption mutation source is absent: $($entry.Key)"
    $mutated = $adoptionText.Replace($from, $to, [StringComparison]::Ordinal)
    Assert-R24D3Adoption (-not (Test-AdoptionSemantics $mutated)) (
        "Adoption mutation was not rejected: $($entry.Key)"
    )
}

$result = [ordered]@{
    schema_version = "sporespore_qsdk_r24d3_cold_qualification_adoption_audit_receipt_v1"
    ok = $true
    gate_id = "QSDK-R24D3"
    question_class = "non_physical_source_conformance"
    result = "artifact_complete_cold_compile_and_zero_world_binding_qualified"
    source_commit = $expectedSourceCommit
    source_binding_count = 8
    retained_evidence_file_count = 7
    retained_binary_count = 2
    binding_assertion_count = 6
    binding_failed_assertion_count = 0
    negative_control_count = 8
    negative_controls_passed = 8
    clean_pushed_cold_build_qualified = $true
    reproducible_build_claimed = $false
    result_reuse_authority = $false
    world_build_count = 0
    solver_step_count = 0
    instrumented_capability_promoted = $false
    prone_to_standing_claimed = $false
    q_sdk_r24_satisfied = $false
    physical_acceptance_authority = $false
    release_authority = $false
}
Write-Output (
    "QSDK_R24D3_COLD_QUALIFICATION_ADOPTION_PASS " +
    ($result | ConvertTo-Json -Depth 20 -Compress)
)
