#requires -Version 7.0

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$sdkRoot = Join-Path $repoRoot "sdk"
$closurePath = Join-Path $sdkRoot (
    "mujoco_c6_bw19v_selected_policy_pose_hold_restoration_mv5_closure.json"
)
$runnerPath = Join-Path $sdkRoot (
    "run_mujoco_c6_bw19v_selected_policy_pose_hold_restoration_mv5.ps1"
)
$implementationPath = Join-Path $sdkRoot (
    "adapters\mujoco\sporespore_mujoco_adapter\" +
    "selected_policy_pose_hold_restoration_mv5.py"
)
$ph1ClosurePath = Join-Path $sdkRoot (
    "rapier_c6_bw19v_velocity_only_pose_hold_restoration_ph1_closure.json"
)
$evidenceRoot = [IO.Path]::GetFullPath(
    (Join-Path (Split-Path -Parent $repoRoot) "SporeSpore_Evidence")
)
$attemptRoot = Join-Path $evidenceRoot "c6-mujoco-bw19v-mv5-899093e"
$attestationPath = Join-Path $evidenceRoot (
    "full-godot-conformance-v2-899093ee-20260804T003944Z\attestation.json"
)
$campaignId = "C6-MUJOCO-BW19V-SELECTED-POLICY-POSE-HOLD-RESTORATION-MV5"
$gateId = "C6-MJC-BW19V-MV5"
$sourceCommit = "899093ee97773ad30a76cce8f385f227de119d22"
$sourceTree = "df15225598d0e97ed8f597d21c5dbd28cb022714"
$expectedClosureSha256 = "1f0a48bbeda23042196f26db551ef12bce2fd2e1fbc617e84414bdb3d0809329"

function Assert-Exact {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function Get-RawSha256 {
    param([Parameter(Mandatory)][string]$Path)
    return (Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash.ToLowerInvariant()
}

function Get-ByteSha256 {
    param([Parameter(Mandatory)][byte[]]$Bytes)
    return [Convert]::ToHexString(
        [Security.Cryptography.SHA256]::HashData($Bytes)
    ).ToLowerInvariant()
}

function Get-GitBlobBytes {
    param([Parameter(Mandatory)][string]$ObjectId)
    $startInfo = [Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = "git"
    $startInfo.WorkingDirectory = $repoRoot
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    foreach ($argument in @("cat-file", "blob", $ObjectId)) {
        [void]$startInfo.ArgumentList.Add($argument)
    }
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $startInfo
    $buffer = [IO.MemoryStream]::new()
    try {
        Assert-Exact $process.Start() "failed to read historical Git blob $ObjectId"
        $process.StandardOutput.BaseStream.CopyTo($buffer)
        $stderr = $process.StandardError.ReadToEnd()
        $process.WaitForExit()
        Assert-Exact ($process.ExitCode -eq 0) (
            "failed to read historical Git blob ${ObjectId}: $stderr"
        )
        return $buffer.ToArray()
    } finally {
        $buffer.Dispose()
        $process.Dispose()
    }
}

function Convert-LfToCrLfBytes {
    param([Parameter(Mandatory)][byte[]]$Bytes)
    $converted = [System.Collections.Generic.List[byte]]::new($Bytes.Length)
    for ($index = 0; $index -lt $Bytes.Length; $index += 1) {
        if ($Bytes[$index] -eq 0x0A -and ($index -eq 0 -or $Bytes[$index - 1] -ne 0x0D)) {
            $converted.Add(0x0D)
        }
        $converted.Add($Bytes[$index])
    }
    return $converted.ToArray()
}

function Test-HistoricalRawReceipt {
    param(
        [Parameter(Mandatory)][byte[]]$GitBlobBytes,
        [Parameter(Mandatory)][long]$ExpectedSize,
        [Parameter(Mandatory)][string]$ExpectedSha256
    )
    if (
        $GitBlobBytes.Length -eq $ExpectedSize -and
        (Get-ByteSha256 -Bytes $GitBlobBytes) -ceq $ExpectedSha256
    ) {
        return $true
    }
    # The MV5 source commit predates universal eol=lf coverage. Its clean
    # Windows checkout could record CRLF bytes for text=auto files while Git
    # canonically retained LF. Reconstruct that one known checkout transform
    # and demand the original size and SHA rather than comparing against HEAD.
    $nativeWindowsBytes = Convert-LfToCrLfBytes -Bytes $GitBlobBytes
    return (
        $nativeWindowsBytes.Length -eq $ExpectedSize -and
        (Get-ByteSha256 -Bytes $nativeWindowsBytes) -ceq $ExpectedSha256
    )
}

function Invoke-CapturedProcess {
    param(
        [Parameter(Mandatory)][string]$FileName,
        [Parameter(Mandatory)][string[]]$ArgumentList,
        [Parameter(Mandatory)][string]$WorkingDirectory
    )
    $startInfo = [Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = $FileName
    $startInfo.WorkingDirectory = $WorkingDirectory
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    foreach ($argument in $ArgumentList) {
        [void]$startInfo.ArgumentList.Add($argument)
    }

    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $startInfo
    try {
        Assert-Exact $process.Start() "failed to start captured process: $FileName"
        $stdoutTask = $process.StandardOutput.ReadToEndAsync()
        $stderrTask = $process.StandardError.ReadToEndAsync()
        $process.WaitForExit()
        return [ordered]@{
            exit_code = $process.ExitCode
            output = (
                $stdoutTask.GetAwaiter().GetResult() +
                $stderrTask.GetAwaiter().GetResult()
            )
        }
    } finally {
        $process.Dispose()
    }
}

function Get-EvidenceTreeReceipt {
    param([Parameter(Mandatory)][string]$Root)
    $rows = [System.Collections.Generic.List[string]]::new()
    $total = 0L
    $files = @(
        Get-ChildItem -LiteralPath $Root -Recurse -File |
            Sort-Object FullName
    )
    foreach ($file in $files) {
        $relative = [IO.Path]::GetRelativePath($Root, $file.FullName).Replace("\", "/")
        $total += [long]$file.Length
        $rows.Add(
            "$relative`t$($file.Length)`t$(Get-RawSha256 -Path $file.FullName)`n"
        )
    }
    $sha = [Security.Cryptography.SHA256]::Create()
    try {
        $payload = [Text.Encoding]::UTF8.GetBytes(($rows -join ""))
        $tree = [Convert]::ToHexString($sha.ComputeHash($payload)).ToLowerInvariant()
    } finally {
        $sha.Dispose()
    }
    return [ordered]@{
        file_count = $files.Count
        total_byte_length = $total
        tree_sha256 = $tree
    }
}

Assert-Exact (
    (git -C $repoRoot rev-parse --show-toplevel).Trim() -ceq $repoRoot.Replace("\", "/") -and
    (git -C $repoRoot remote get-url origin).Trim() -ceq
        "https://github.com/Slagathore/sporespore.git" -and
    (Test-Path -LiteralPath $closurePath -PathType Leaf) -and
    (Get-RawSha256 -Path $closurePath) -ceq $expectedClosureSha256
) "$gateId closure identity changed"

$closure = Get-Content -Raw -LiteralPath $closurePath |
    ConvertFrom-Json -AsHashtable -Depth 100
Assert-Exact (
    [string]$closure.schema_version -ceq
        "sporespore_mujoco_c6_bw19v_selected_policy_pose_hold_restoration_mv5_closure_v1" -and
    [string]$closure.status -ceq
        "closed_consumed_implementation_invalid_no_physical_report" -and
    [string]$closure.campaign_id -ceq $campaignId -and
    [string]$closure.gate_id -ceq $gateId -and
    [string]$closure.experiment_source_commit -ceq $sourceCommit -and
    [string]$closure.experiment_source_tree_git_oid -ceq $sourceTree -and
    [bool]$closure.source_was_clean_and_equal_to_origin_main_and_live_github_main -and
    [int]$closure.declared_study.declared_world_count -eq 1 -and
    [int]$closure.declared_study.declared_controller_step_count -eq 2992 -and
    [int]$closure.declared_study.declared_command_count_per_layer -eq 23936 -and
    [int]$closure.declared_study.declared_negative_control_count -eq 37 -and
    [int]$closure.declared_study.replacement_process_count -eq 0 -and
    [bool]$closure.declared_study.complete_report_required_for_scientific_interpretation
) "$gateId closure source, study, or disposition changed"

& git -C $repoRoot cat-file -e "$sourceCommit`^{commit}"
Assert-Exact ($LASTEXITCODE -eq 0) "$gateId source commit is not retained"
Assert-Exact (
    (git -C $repoRoot rev-parse "$sourceCommit`^{tree}").Trim() -ceq $sourceTree
) "$gateId source tree changed"

$unretainedHistoricalRawPaths = [System.Collections.Generic.List[string]]::new()
foreach ($entry in $closure.bound_source_inventory.GetEnumerator()) {
    $record = $entry.Value
    $relativePath = [string]$record.path
    $expectedRaw = ([string]$record.raw_sha256).Replace("sha256:", "")
    $commitBlobOid = (git -C $repoRoot rev-parse "$sourceCommit`:$relativePath").Trim()
    $commitBlobExitCode = $LASTEXITCODE
    $historicalBytes = Get-GitBlobBytes -ObjectId ([string]$record.git_blob_oid)
    Assert-Exact (
        $commitBlobExitCode -eq 0 -and
        $commitBlobOid -ceq [string]$record.git_blob_oid
    ) (
        "$gateId historical Git source changed: $relativePath"
    )
    if (-not (Test-HistoricalRawReceipt `
        -GitBlobBytes $historicalBytes `
        -ExpectedSize ([long]$record.size_bytes) `
        -ExpectedSha256 $expectedRaw)) {
        # MV5 did not retain content-addressed copies. A clean Git identity and
        # an immutable recorded checkout hash survive, but mixed native line
        # endings in one text=auto file cannot be reconstructed after HEAD
        # legitimately advances. Keep that evidence deficit explicit instead
        # of requiring the current checkout to impersonate the old one.
        $unretainedHistoricalRawPaths.Add($relativePath)
    }
}
Assert-Exact (
    (@($unretainedHistoricalRawPaths | Sort-Object) -join "|") -ceq (
        "sdk/python/sporespore_locomotion.py"
    )
) (
    "$gateId historical checkout-byte retention deficit changed: " +
    (@($unretainedHistoricalRawPaths | Sort-Object) -join ",")
)

Assert-Exact (
    Test-Path -LiteralPath $attestationPath -PathType Leaf
) "$gateId full-Godot V2 attestation is missing"
$attestation = Get-Content -Raw -LiteralPath $attestationPath |
    ConvertFrom-Json -AsHashtable -Depth 64
Assert-Exact (
    (Get-RawSha256 -Path $attestationPath) -ceq
        "60e4bd63a8a09568899f13aecf66f6486012e1bbd7049903e7e15bd1c5035fc1" -and
    (Get-Item -LiteralPath $attestationPath).Length -eq 3563 -and
    [string]$attestation.schema_version -ceq
        "sporespore_full_godot_conformance_attestation_v2" -and
    [string]$attestation.status -ceq "full_godot_conformance_passed" -and
    [string]$attestation.source.commit -ceq $sourceCommit -and
    [string]$attestation.source.tree_git_oid -ceq $sourceTree -and
    [string]$attestation.source.origin_main -ceq $sourceCommit -and
    [string]$attestation.source.live_github_main -ceq $sourceCommit -and
    [bool]$attestation.source.clean_pushed_live -and
    [bool]$attestation.conformance.passed -and
    [bool]$attestation.conformance.godot_including -and
    -not [bool]$attestation.conformance.one_shot_physical_campaign_executed
) "$gateId full-Godot V2 attestation changed"
foreach ($claim in @($attestation.claims.Keys)) {
    Assert-Exact (-not [bool]$attestation.claims[$claim]) (
        "$gateId attestation inflated claim: $claim"
    )
}

$expectedEvidence = [ordered]@{
    "attempt.json" = "feeea087f24823c2f82c01438faf43a9fa81d653b9a99dad518ed73ebb03f3fa"
    "completion.json" = "988effcbcf84daf86d7f55fef352787290bb3f89791c6a83c191c9714b7d5210"
    "preflight.json" = "1cb1dd5806f38ec461474ebb229c19a132f02af4fd962be2d9000c9eeaf588f9"
    "stderr.log" = "478574b24e449564b4b68cb22343951377eb35ed08032695361ceb4c8573cab4"
    "stdout.log" = "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
}
Assert-Exact (
    (Test-Path -LiteralPath $attemptRoot -PathType Container) -and
    @(Get-ChildItem -LiteralPath $attemptRoot -File).Count -eq 5 -and
    -not (Test-Path -LiteralPath (Join-Path $attemptRoot "report.json"))
) "$gateId evidence cardinality or absent-report boundary changed"
foreach ($entry in $expectedEvidence.GetEnumerator()) {
    $path = Join-Path $attemptRoot ([string]$entry.Key)
    Assert-Exact (
        (Test-Path -LiteralPath $path -PathType Leaf) -and
        (Get-RawSha256 -Path $path) -ceq [string]$entry.Value
    ) "$gateId retained evidence changed: $($entry.Key)"
}
$tree = Get-EvidenceTreeReceipt -Root $attemptRoot
Assert-Exact (
    [int]$tree.file_count -eq 5 -and
    [long]$tree.total_byte_length -eq 55837 -and
    [string]$tree.tree_sha256 -ceq
        "a3a07c722920802a90f20d6acd793369fbf153fda463203ae2d483bdbd3e2943"
) "$gateId retained evidence tree changed"

$attempt = Get-Content -Raw -LiteralPath (Join-Path $attemptRoot "attempt.json") |
    ConvertFrom-Json -AsHashtable -Depth 64
$completion = Get-Content -Raw -LiteralPath (Join-Path $attemptRoot "completion.json") |
    ConvertFrom-Json -AsHashtable -Depth 64
$preflight = Get-Content -Raw -LiteralPath (Join-Path $attemptRoot "preflight.json") |
    ConvertFrom-Json -AsHashtable -Depth 100
$stderr = Get-Content -Raw -LiteralPath (Join-Path $attemptRoot "stderr.log")
Assert-Exact (
    [string]$attempt.attempt_id -ceq "016f9505ecf34348864098bc4d369f9f" -and
    [string]$attempt.status -ceq "physical_process_launch_reserved_identity_consumed" -and
    [string]$attempt.source_commit -ceq $sourceCommit -and
    [int]$attempt.declared_world_count -eq 1 -and
    [int]$attempt.declared_controller_steps -eq 2992 -and
    [bool]$attempt.physical_process_launch_consumes_identity -and
    -not [bool]$attempt.same_identity_rerun_allowed -and
    [bool]$attempt.operation_lock.acquired -and
    [string]$attempt.operation_lock.role -ceq "physical" -and
    [string]$completion.attempt_id -ceq [string]$attempt.attempt_id -and
    [bool]$completion.process_launched -and
    [int]$completion.process_exit_code -eq 1 -and
    $null -eq $completion.launch_error -and
    -not [bool]$completion.report_present -and
    -not [bool]$completion.same_identity_rerun_allowed -and
    [bool]$preflight.ok -and
    [int]$preflight.negative_control_count -eq 37 -and
    [int]$preflight.synthetic_report_negative_control_count -eq 18 -and
    [bool]$preflight.production_kinematic_vector_representation_canary.ok -and
    [int]$preflight.production_kinematic_vector_representation_canary.negative_control_count -eq 5 -and
    [int]$preflight.world_build_count -eq 0 -and
    -not [bool]$preflight.physical_acceptance_authority
) "$gateId attempt, completion, or preflight changed"

$ph1HistoricalBytes = Get-GitBlobBytes -ObjectId (
    [string]$closure.bound_source_inventory.rapier_ph1_closure.git_blob_oid
)
$ph1Closure = [Text.Encoding]::UTF8.GetString($ph1HistoricalBytes) |
    ConvertFrom-Json -AsHashtable -Depth 100
$implementationHistoricalBytes = Get-GitBlobBytes -ObjectId (
    [string]$closure.bound_source_inventory.implementation.git_blob_oid
)
$implementationText = [Text.Encoding]::UTF8.GetString($implementationHistoricalBytes)
$loopPosition = $implementationText.IndexOf(
    "for semantic_step in range(TOTAL_STEPS):", [StringComparison]::Ordinal
)
$finalPosition = $implementationText.IndexOf(
    'final = trace[-1]["post_step_snapshot"]', [StringComparison]::Ordinal
)
$reportPosition = $implementationText.IndexOf(
    "report = {", $finalPosition, [StringComparison]::Ordinal
)
$failurePosition = $implementationText.IndexOf(
    'authorities["ph1_closure"]["experiment_source"]',
    $reportPosition,
    [StringComparison]::Ordinal
)
$evaluatorPosition = $implementationText.IndexOf(
    "failures = _evaluate_core(report)", $failurePosition, [StringComparison]::Ordinal
)
Assert-Exact (
    $stderr.Contains("KeyError: 'experiment_source'") -and
    $stderr.Contains("selected_policy_pose_hold_restoration_mv5.py`", line 2191") -and
    $loopPosition -ge 0 -and
    $finalPosition -gt $loopPosition -and
    $reportPosition -gt $finalPosition -and
    $failurePosition -gt $reportPosition -and
    $evaluatorPosition -gt $failurePosition -and
    -not $ph1Closure.ContainsKey("experiment_source") -and
    [string]$ph1Closure.physical_source_commit -ceq
        "91c528e0d0eb494a7ff1d9dc9250ef1af6963249"
) "$gateId traceback, frozen control flow, or PH1 schema changed"

Assert-Exact (
    [string]$closure.implementation_failure.classification -ceq
        "post_horizon_report_authority_schema_mismatch" -and
    [string]$closure.implementation_failure.exception_type -ceq "KeyError" -and
    [string]$closure.implementation_failure.actual_ph1_closure_source_field -ceq
        "physical_source_commit" -and
    [bool]$closure.implementation_failure.posthoc_control_flow_inference.complete_declared_outer_controller_loop_reached -and
    [int]$closure.implementation_failure.posthoc_control_flow_inference.inferred_completed_outer_controller_steps -eq 2992 -and
    [int]$closure.implementation_failure.posthoc_control_flow_inference.inferred_native_commands_applied_per_layer -eq 23936 -and
    [bool]$closure.implementation_failure.posthoc_control_flow_inference.metric_calculation_reached -and
    -not [bool]$closure.implementation_failure.posthoc_control_flow_inference.report_dictionary_construction_completed -and
    -not [bool]$closure.implementation_failure.posthoc_control_flow_inference.report_evaluation_reached -and
    [int]$closure.implementation_failure.posthoc_control_flow_inference.retained_trace_row_count -eq 0 -and
    [int]$closure.implementation_failure.posthoc_control_flow_inference.retained_physical_metrics_count -eq 0 -and
    -not [bool]$closure.technical_disposition.valid_complete_physical_report -and
    -not [bool]$closure.technical_disposition.declared_combined_gate_evaluated -and
    -not [bool]$closure.technical_disposition.physical_measurement_result_available -and
    [string]$closure.scientific_disposition.classification -ceq
        "no_scientific_result_implementation_invalid"
) "$gateId implementation-invalid or scientific boundary changed"

# The same-identity refusal below deliberately invokes the current runner.
# Unlike general historical source, that safety entrypoint must remain byte
# exact before it is executed against the retained attempt root.
Assert-Exact (
    (Get-RawSha256 -Path $runnerPath) -ceq (
        ([string]$closure.bound_source_inventory.supervisor.raw_sha256).Replace(
            "sha256:",
            ""
        )
    )
) "$gateId current refusal runner changed"

foreach ($claim in @($closure.claims.Keys)) {
    if ($claim -ceq "complete_attempt_closure") {
        Assert-Exact ([bool]$closure.claims[$claim]) "$gateId closure claim missing"
    } else {
        Assert-Exact (-not [bool]$closure.claims[$claim]) (
            "$gateId inflated claim: $claim"
        )
    }
}
Assert-Exact (
    [bool]$closure.immutability.same_identity_rerun_forbidden -and
    [bool]$closure.immutability.replacement_process_forbidden -and
    [bool]$closure.immutability.lost_trace_or_metric_reconstruction_forbidden -and
    [bool]$closure.next_allowed_work.use_ph1_physical_source_commit_field_in_a_distinct_successor -and
    [bool]$closure.next_allowed_work.factor_and_zero_world_qualify_the_exact_shared_physical_report_assembler -and
    [bool]$closure.next_allowed_work.require_a_new_clean_pushed_source_and_full_godot_attestation
) "$gateId immutability or successor boundary changed"

$treeBeforeRefusal = Get-EvidenceTreeReceipt -Root $attemptRoot
$refusalReceipt = Invoke-CapturedProcess `
    -FileName (Get-Command pwsh -ErrorAction Stop).Source `
    -ArgumentList @(
        "-NoLogo",
        "-NoProfile",
        "-File", $runnerPath,
        "-RunPhysical",
        "-FullConformanceAttestation", $attestationPath
    ) `
    -WorkingDirectory $repoRoot
$treeAfterRefusal = Get-EvidenceTreeReceipt -Root $attemptRoot
Assert-Exact (
    [int]$refusalReceipt.exit_code -ne 0 -and
    ([string]$refusalReceipt.output).Contains(
        "$gateId is closed and may not open another world"
    ) -and
    [string]$treeAfterRefusal.tree_sha256 -ceq [string]$treeBeforeRefusal.tree_sha256 -and
    [int]$treeAfterRefusal.file_count -eq [int]$treeBeforeRefusal.file_count
) "$gateId same-identity physical rerun was not refused before evidence mutation"

Write-Host (
    "C6_MJC_BW19V_MV5_CLOSURE_PASS status=implementation-invalid " +
    "worlds=1 loop_inferred=True steps_inferred=2992 report=False " +
    "historical_git_blobs=11 unretained_checkout_byte_receipts=1 " +
    "scientific_result=False walking=False physical_authority=False " +
    "rerun_refused=True"
)
