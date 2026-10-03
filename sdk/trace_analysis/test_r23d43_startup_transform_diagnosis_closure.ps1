#requires -Version 7.0

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot "..\.."))
$evidenceRoot = "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence"
$artifactRoot = Join-Path $evidenceRoot "artifacts\sha256"
$closurePath = Join-Path $repoRoot (
    "sdk\trace_analysis\r23d43_rapier_startup_transform_diagnosis_closure_v1.json"
)
$manifestPath = Join-Path $repoRoot (
    "sdk\trace_analysis\r23d43_rapier_startup_transform_analysis_manifest_v1.json"
)
$tolerance = 1.0e-15

function Assert-R23D43Diagnosis([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "R23D43 STARTUP DIAGNOSIS CLOSURE: $Message" }
}

function Assert-Near(
    [double]$Actual,
    [double]$Expected,
    [string]$Message
) {
    Assert-R23D43Diagnosis (
        [double]::IsFinite($Actual) -and
        [Math]::Abs($Actual - $Expected) -le $tolerance
    ) "$Message actual=$Actual expected=$Expected"
}

function Get-Sha256([string]$Path) {
    return "sha256:" + (
        Get-FileHash -LiteralPath $Path -Algorithm SHA256
    ).Hash.ToLowerInvariant()
}

function Get-BytesSha256([byte[]]$Bytes) {
    return "sha256:" + [Convert]::ToHexString(
        [Security.Cryptography.SHA256]::HashData($Bytes)
    ).ToLowerInvariant()
}

function Get-GitBlobBytes([string]$Commit, [string]$RelativePath) {
    $start = [Diagnostics.ProcessStartInfo]::new()
    $start.FileName = "git"
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    foreach ($argument in @(
        "-C", $repoRoot, "cat-file", "blob", "${Commit}:$RelativePath"
    )) { [void]$start.ArgumentList.Add($argument) }
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $start
    $memory = $null
    try {
        Assert-R23D43Diagnosis $process.Start() "failed to start git cat-file"
        $stderrTask = $process.StandardError.ReadToEndAsync()
        $memory = [IO.MemoryStream]::new()
        $process.StandardOutput.BaseStream.CopyTo($memory)
        $process.WaitForExit()
        $stderr = $stderrTask.GetAwaiter().GetResult()
        Assert-R23D43Diagnosis ($process.ExitCode -eq 0) (
            "historical blob unavailable: $RelativePath; $stderr"
        )
        return ,([byte[]]$memory.ToArray())
    } finally {
        if ($null -ne $memory) { $memory.Dispose() }
        $process.Dispose()
    }
}

function Assert-Cas([string]$Sha256, [long]$ByteLength) {
    Assert-R23D43Diagnosis ($Sha256 -cmatch '^sha256:[0-9a-f]{64}$') (
        "invalid CAS digest: $Sha256"
    )
    $directory = Join-Path $artifactRoot $Sha256.Substring(7)
    $payload = Join-Path $directory "payload.bin"
    $casManifestPath = Join-Path $directory "manifest.json"
    Assert-R23D43Diagnosis (
        (Test-Path -LiteralPath $payload -PathType Leaf) -and
        (Test-Path -LiteralPath $casManifestPath -PathType Leaf) -and
        (Get-Item -LiteralPath $payload).Length -eq $ByteLength -and
        (Get-Sha256 $payload) -ceq $Sha256
    ) "CAS payload changed: $Sha256"
    $casManifest = Get-Content -LiteralPath $casManifestPath -Raw |
        ConvertFrom-Json -AsHashtable -Depth 20
    Assert-R23D43Diagnosis (
        [string]$casManifest.schema_version -ceq
            "sporespore_content_addressed_artifact_manifest_v1" -and
        [string]$casManifest.algorithm -ceq "sha256" -and
        [string]$casManifest.sha256 -ceq $Sha256 -and
        [long]$casManifest.byte_length -eq $ByteLength -and
        [string]$casManifest.payload_name -ceq "payload.bin"
    ) "CAS manifest changed: $Sha256"
}

Assert-R23D43Diagnosis (
    (git -C $repoRoot rev-parse --show-toplevel).Trim() -ceq
        $repoRoot.Replace('\', '/') -and
    (git -C $repoRoot remote get-url origin).Trim() -ceq
        "https://github.com/Slagathore/sporespore.git" -and
    (Test-Path -LiteralPath $closurePath -PathType Leaf) -and
    (Test-Path -LiteralPath $manifestPath -PathType Leaf)
) "repository identity or required path changed"

$closure = Get-Content -LiteralPath $closurePath -Raw |
    ConvertFrom-Json -AsHashtable -Depth 100
$manifest = Get-Content -LiteralPath $manifestPath -Raw |
    ConvertFrom-Json -AsHashtable -Depth 100
$source = $closure.source
Assert-R23D43Diagnosis (
    [string]$closure.schema_version -ceq
        "sporespore_r23d43_rapier_startup_transform_diagnosis_closure_v1" -and
    [string]$closure.analysis_id -ceq
        "QSDK-R23D43-RAPIER-STARTUP-TRANSFORM-D1" -and
    [string]$closure.status -ceq
        "closed_complete_postoutcome_cross_seed_development_diagnosis" -and
    [string]$source.commit -ceq
        "dca648a0bda18231ca8e904403942087917f0ebf" -and
    (git -C $repoRoot rev-parse "$($source.commit)^{tree}").Trim() -ceq
        [string]$source.tree_git_oid -and
    [bool]$source.clean_pushed_live_main_verified -and
    @($source.source_bindings).Count -eq 5 -and
    @($closure.immutable_parents).Count -eq 6
) "closure or source identity changed"

foreach ($binding in $source.source_bindings) {
    $bytes = Get-GitBlobBytes ([string]$source.commit) ([string]$binding.path)
    Assert-R23D43Diagnosis (
        (git -C $repoRoot rev-parse (
            "$($source.commit):$($binding.path)"
        )).Trim() -ceq [string]$binding.git_blob_oid -and
        $bytes.LongLength -eq [long]$binding.byte_length -and
        (Get-BytesSha256 $bytes) -ceq [string]$binding.raw_sha256
    ) "source binding changed: $($binding.path)"
}

$parentKeys = @()
foreach ($parent in $closure.immutable_parents) {
    $parentKeys += [string]$parent.campaign_key
    $bytes = Get-GitBlobBytes (
        [string]$parent.closure_source_commit
    ) ([string]$parent.closure_path)
    Assert-R23D43Diagnosis (
        (git -C $repoRoot rev-parse (
            "$($parent.closure_source_commit):$($parent.closure_path)"
        )).Trim() -ceq [string]$parent.closure_git_blob_oid -and
        (Get-BytesSha256 $bytes) -ceq [string]$parent.closure_raw_sha256 -and
        -not [bool]$parent.parent_reinterpreted -and
        -not [bool]$parent.parent_rerun
    ) "immutable parent changed: $($parent.campaign_key)"
}
Assert-R23D43Diagnosis (
    ($parentKeys -join ',') -ceq "r23d30,r23d31,r23d32,r23d41,r23d42,r23d43"
) "immutable parent order changed"

$retained = $closure.retained_evidence
$reportRecord = $retained.report
$receiptRecord = $retained.receipt
Assert-R23D43Diagnosis (
    (Test-Path -LiteralPath $reportRecord.path -PathType Leaf) -and
    (Get-Item -LiteralPath $reportRecord.path).Length -eq
        [long]$reportRecord.byte_length -and
    (Get-Sha256 ([string]$reportRecord.path)) -ceq
        [string]$reportRecord.sha256 -and
    (Test-Path -LiteralPath $receiptRecord.path -PathType Leaf) -and
    (Get-Item -LiteralPath $receiptRecord.path).Length -eq
        [long]$receiptRecord.byte_length -and
    (Get-Sha256 ([string]$receiptRecord.path)) -ceq
        [string]$receiptRecord.sha256 -and
    (Get-Sha256 ([string]$reportRecord.cas_manifest_path)) -ceq
        [string]$reportRecord.cas_manifest_sha256 -and
    (Get-Item -LiteralPath $reportRecord.cas_manifest_path).Length -eq
        [long]$reportRecord.cas_manifest_byte_length -and
    [int]$retained.input_campaign_count -eq 6 -and
    [int]$retained.input_trace_count -eq 18 -and
    [int]$retained.input_trace_row_count -eq 53856 -and
    [long]$retained.input_trace_byte_length -eq 233763048 -and
    [int]$retained.content_addressed_input_count -eq 18 -and
    [int]$retained.live_attempt_path_input_count -eq 0
) "retained report or receipt identity changed"
Assert-Cas ([string]$reportRecord.sha256) ([long]$reportRecord.byte_length)

$receipt = Get-Content -LiteralPath $receiptRecord.path -Raw |
    ConvertFrom-Json -AsHashtable -Depth 50
$report = Get-Content -LiteralPath $reportRecord.path -Raw |
    ConvertFrom-Json -AsHashtable -Depth 100
Assert-R23D43Diagnosis (
    [string]$receipt.schema_version -ceq
        "sporespore_r23d43_rapier_startup_transform_analysis_receipt_v1" -and
    [string]$receipt.analyzer_source_commit -ceq [string]$source.commit -and
    [string]$receipt.report_sha256 -ceq [string]$reportRecord.sha256 -and
    [long]$receipt.report_byte_length -eq [long]$reportRecord.byte_length -and
    [string]$receipt.manifest_sha256 -ceq
        "sha256:071a884b6ea469ee395ce676f5f599ebb88db2572a77e857d9cc991791d20fd4" -and
    -not [bool]$receipt.physical_execution_authorized -and
    -not [bool]$receipt.physical_acceptance_authority -and
    [string]$report.schema_version -ceq
        "sporespore_r23d43_rapier_startup_transform_analysis_report_v1" -and
    [int]$report.input_summary.campaign_count -eq 6 -and
    [int]$report.input_summary.cell_count -eq 18 -and
    [int]$report.input_summary.total_trace_row_count -eq 53856 -and
    [long]$report.input_summary.total_trace_byte_length -eq 233763048 -and
    [int]$report.model_construction_count -eq 0 -and
    [int]$report.world_attempt_count -eq 0 -and
    [int]$report.world_build_count -eq 0
) "receipt or report boundary changed"

foreach ($campaign in $manifest.campaigns) {
    foreach ($cell in $campaign.cells) {
        Assert-Cas ([string]$cell.trace_sha256) ([long]$cell.trace_byte_length)
    }
}

$byGroup = @{}
foreach ($group in $report.groups) {
    $byGroup[[string]$group.group_id] = $group
}
$noRamp = $byGroup.no_startup_ramp
$ramped = $byGroup.canonical_startup_ramp
Assert-R23D43Diagnosis (
    [int]$noRamp.raw_signed_gate_pass_count -eq 3 -and
    [int]$noRamp.conditioned_gate_pass_count -eq 3 -and
    [int]$ramped.raw_signed_gate_pass_count -eq 3 -and
    [int]$ramped.conditioned_gate_pass_count -eq 0 -and
    [bool]$report.direct_observations.all_three_ramped_triplets_fail_only_the_positive_conditioned_floor -and
    [bool]$report.direct_observations.r23d43_verifier_projection_would_remain_turning_negative -and
    [bool]$report.direct_observations.startup_transform_and_seed_remain_confounded -and
    -not [bool]$report.direct_observations.causal_effect_or_population_inference_permitted -and
    [bool]$closure.interpretation.paired_same_seed_development_supported -and
    -not [bool]$closure.interpretation.verifier_only_successor_sufficient -and
    [string]$closure.successor_constraints.question_class -ceq
        "outcome_exposed_paired_development_screen" -and
    [bool]$closure.successor_constraints.both_startup_transform_states_required_on_each_declared_seed -and
    [bool]$closure.successor_constraints.reference_positive_and_negative_arms_required_per_transform_state -and
    -not [bool]$closure.successor_constraints.paired_screen_can_satisfy_qsdk_r23 -and
    -not [bool]$closure.successor_constraints.paired_screen_can_consume_fresh_held_out_validation_seed -and
    @($closure.claim_limits.Values | Where-Object { [bool]$_ }).Count -eq 0
) "finding, successor, or claim boundary changed"

Assert-Near (
    [double]$noRamp.positive_reference_conditioned_cycle_shift_rad.minimum
) 0.010030533017876247 "no-ramp positive minimum changed"
Assert-Near (
    [double]$noRamp.positive_reference_conditioned_cycle_shift_rad.maximum
) 0.012882768312606334 "no-ramp positive maximum changed"
Assert-Near (
    [double]$ramped.positive_reference_conditioned_cycle_shift_rad.minimum
) 0.005401148214074572 "ramped positive minimum changed"
Assert-Near (
    [double]$ramped.positive_reference_conditioned_cycle_shift_rad.maximum
) 0.005978002522826736 "ramped positive maximum changed"
Assert-Near (
    [double]$report.descriptive_group_contrast.ramped_minus_no_ramp_mean_positive_conditioned_cycle_shift_rad
) -0.005336150788865706 "descriptive positive contrast changed"

$requiredDocumentation = @(
    "docs\README.md",
    "docs\ENGINE_NEUTRAL_LOCOMOTION_SDK_BOOTSTRAP.md",
    "docs\SDK_PORTABLE_BALANCED_WAVE_SUCCESSOR_BOOTSTRAP.md",
    "docs\LOCOMOTION_GROUND_UP_RESEARCH_PROGRAM.md",
    "sdk\trace_analysis\README.md"
)
foreach ($relativePath in $requiredDocumentation) {
    $text = Get-Content -LiteralPath (Join-Path $repoRoot $relativePath) -Raw
    Assert-R23D43Diagnosis (
        $text.Contains(
            "sha256:a9fed5d706c10437362cbc0b794792b476621b60c780a2f1216df1f0e4bd339e"
        ) -and
        $text.Contains("53,856") -and
        $text.Contains("same-seed")
    ) "documentation closure boundary missing: $relativePath"
}

Write-Host (
    "R23D43_STARTUP_DIAGNOSIS_CLOSURE_PASS parents=6 traces=18 rows=53856 " +
    "no_ramp_conditioned=3/3 ramped_conditioned=0/3 confounded=True " +
    "paired_development=True models=0 worlds=0 turning=False physical=False"
)
