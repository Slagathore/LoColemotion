#requires -Version 7.0

[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$sdkRoot = Join-Path $repoRoot "sdk"
$closurePath = Join-Path $sdkRoot "turning\r23d2_physical_closure_v1.json"
$runnerPath = Join-Path $sdkRoot "run_qsdk_r23d2_supervisor.ps1"
$evaluatorPath = Join-Path $sdkRoot "turning\r23d2_development.py"
$sourceAuditPath = Join-Path $PSScriptRoot "closed_experiment_source_audit.ps1"
$pythonPath = Join-Path $sdkRoot "adapters\mujoco\.venv\Scripts\python.exe"
$expectedClosureSha256 = "83fb890445f1355027ff5062c6d9c3f83792f124a9ee3c2561eab85efe249680"
$campaignId = "QSDK-R23D2-THREE-ENGINE-HEADING-RESPONSE-DEVELOPMENT"
$gateId = "QSDK-R23D2"
$sourceCommit = "2b46e0f86f23e5a6fbf0b0ed69e7000cb7f5aeeb"
$sourceTree = "2631456c301a5c2612eb848873ffe3eda9462051"
$attemptId = "62d6630cd1674dc2bf05619ed87911fc"
$expectedCells = @(
    "godot_jolt__reference_zero",
    "godot_jolt__positive_heading",
    "godot_jolt__negative_heading",
    "rapier_parry__reference_zero",
    "rapier_parry__positive_heading",
    "rapier_parry__negative_heading",
    "mujoco__reference_zero",
    "mujoco__positive_heading",
    "mujoco__negative_heading"
)

function Assert-R23D2Closure {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function Get-R23D2RawSha256 {
    param([Parameter(Mandatory)][string]$Path)
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Test-R23D2SequenceEqual {
    param(
        [Parameter(Mandatory)][AllowEmptyCollection()][object[]]$Actual,
        [Parameter(Mandatory)][AllowEmptyCollection()][object[]]$Expected
    )
    if ($Actual.Count -ne $Expected.Count) { return $false }
    for ($index = 0; $index -lt $Expected.Count; $index += 1) {
        if ([string]$Actual[$index] -cne [string]$Expected[$index]) { return $false }
    }
    return $true
}

function Assert-R23D2CloseNumber {
    param(
        [Parameter(Mandatory)][double]$Actual,
        [Parameter(Mandatory)][double]$Expected,
        [Parameter(Mandatory)][string]$Label,
        [double]$Tolerance = 1.0e-12
    )
    Assert-R23D2Closure ([math]::Abs($Actual - $Expected) -le $Tolerance) (
        "$gateId $Label changed: actual=$Actual expected=$Expected"
    )
}

function Get-R23D2EvidenceTreeDigest {
    param([Parameter(Mandatory)][string]$Root)
    $files = @(Get-ChildItem -LiteralPath $Root -File -Recurse)
    $rows = @(
        $files |
            ForEach-Object {
                $relative = [IO.Path]::GetRelativePath($Root, $_.FullName).Replace("\", "/")
                "{0}`t{1}`t{2}" -f $relative, $_.Length, (Get-R23D2RawSha256 $_.FullName)
            } |
            Sort-Object
    )
    $text = ($rows -join "`n") + "`n"
    return [ordered]@{
        file_count = $files.Count
        total_byte_length = [long]($files | Measure-Object Length -Sum).Sum
        tree_sha256 = [Convert]::ToHexString(
            [Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($text))
        ).ToLowerInvariant()
    }
}

function Test-R23D2CasReceipt {
    param([Parameter(Mandatory)]$Receipt)
    try {
        $digest = [string]$Receipt.sha256
        if (
            [string]$Receipt.schema_version -cne
                "sporespore_content_addressed_artifact_receipt_v1" -or
            $digest -cnotmatch '^sha256:[0-9a-f]{64}$' -or
            [bool]$Receipt.test_only -or
            [bool]$Receipt.physical_acceptance_authority
        ) { return $false }
        $rawDigest = $digest.Substring("sha256:".Length)
        $payloadPath = [IO.Path]::GetFullPath([string]$Receipt.payload_path)
        $manifestPath = [IO.Path]::GetFullPath([string]$Receipt.manifest_path)
        $expectedDirectory = [IO.Path]::GetFullPath(
            "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence\artifacts\sha256\$rawDigest"
        )
        if (
            (Split-Path -Parent $payloadPath) -cne $expectedDirectory -or
            (Split-Path -Parent $manifestPath) -cne $expectedDirectory -or
            -not (Test-Path -LiteralPath $payloadPath -PathType Leaf) -or
            -not (Test-Path -LiteralPath $manifestPath -PathType Leaf) -or
            (Get-Item -LiteralPath $payloadPath).Length -ne [long]$Receipt.byte_length -or
            (Get-R23D2RawSha256 $payloadPath) -cne $rawDigest
        ) { return $false }
        $manifest = Get-Content -Raw -LiteralPath $manifestPath |
            ConvertFrom-Json -AsHashtable -Depth 32
        return (
            [string]$manifest.schema_version -ceq
                "sporespore_content_addressed_artifact_manifest_v1" -and
            [string]$manifest.algorithm -ceq "sha256" -and
            [string]$manifest.sha256 -ceq $digest -and
            [long]$manifest.byte_length -eq [long]$Receipt.byte_length -and
            [string]$manifest.payload_name -ceq "payload.bin"
        )
    } catch {
        return $false
    }
}

function Assert-R23D2CasReceipt {
    param(
        [Parameter(Mandatory)]$Receipt,
        [Parameter(Mandatory)][string]$Label
    )
    Assert-R23D2Closure (Test-R23D2CasReceipt $Receipt) (
        "$gateId $Label CAS receipt, payload, or manifest changed"
    )
}

function Invoke-R23D2Evaluator {
    param([Parameter(Mandatory)][string[]]$Arguments)
    $lines = @(& $pythonPath $evaluatorPath @Arguments 2>&1)
    $exitCode = $LASTEXITCODE
    $text = $lines -join "`n"
    $jsonLine = @($lines | Where-Object {
        [string]$_ -match '^QSDK_R23D2_(ENTRY|AGGREGATE)_EVALUATION '
    } | Select-Object -Last 1)
    $document = $null
    if ($jsonLine.Count -eq 1) {
        $document = ([string]$jsonLine[0]).Substring(([string]$jsonLine[0]).IndexOf("{") ) |
            ConvertFrom-Json -AsHashtable -Depth 128
    }
    return [ordered]@{ exit_code = $exitCode; text = $text; document = $document }
}

function Test-R23D2ClaimsFalse {
    param([Parameter(Mandatory)]$Claims)
    return @($Claims.Values | Where-Object { [bool]$_ }).Count -eq 0
}

Assert-R23D2Closure (
    (git -C $repoRoot rev-parse --show-toplevel).Replace("/", "\") -ceq $repoRoot -and
    (git -C $repoRoot remote get-url origin) -ceq
        "https://github.com/Slagathore/sporespore.git"
) "$gateId closure audit repository identity mismatch"
Assert-R23D2Closure (
    (Test-Path -LiteralPath $closurePath -PathType Leaf) -and
    (Get-R23D2RawSha256 $closurePath) -ceq $expectedClosureSha256
) "$gateId closure is missing or changed"
Assert-R23D2Closure (
    (Test-Path -LiteralPath $sourceAuditPath -PathType Leaf) -and
    (Test-Path -LiteralPath $pythonPath -PathType Leaf) -and
    (Test-Path -LiteralPath $evaluatorPath -PathType Leaf)
) "$gateId closure audit dependency is missing"
. $sourceAuditPath

& git -C $repoRoot cat-file -e "$sourceCommit`^{commit}"
Assert-R23D2Closure ($LASTEXITCODE -eq 0) "$gateId source commit is unavailable"
Assert-R23D2Closure (
    (& git -C $repoRoot rev-parse "$sourceCommit`^{tree}").Trim() -ceq $sourceTree
) "$gateId source tree changed"

$closure = Get-Content -Raw -LiteralPath $closurePath |
    ConvertFrom-Json -AsHashtable -Depth 128
$attemptRecord = [Collections.IDictionary]$closure.consumed_attempt
$evidenceRoot = [IO.Path]::GetFullPath([string]$attemptRecord.evidence_root)
Assert-R23D2Closure (
    [string]$closure.schema_version -ceq
        "sporespore_qsdk_r23d2_physical_development_closure_v1" -and
    [string]$closure.status -ceq
        "closed_consumed_invalid_incomplete_three_engine_aggregate_with_six_bounded_cell_results" -and
    [string]$closure.campaign_id -ceq $campaignId -and
    [string]$closure.gate_id -ceq $gateId -and
    [string]$closure.release_gate_id -ceq "QSDK-R23" -and
    [string]$closure.experiment_source_commit -ceq $sourceCommit -and
    [string]$closure.experiment_source_tree_git_oid -ceq $sourceTree -and
    [bool]$closure.source_was_clean_and_equal_to_origin_main_and_live_github_main -and
    [int]$closure.declared_study.declared_engine_count -eq 3 -and
    [int]$closure.declared_study.declared_arm_count -eq 3 -and
    [int]$closure.declared_study.declared_cell_count -eq 9 -and
    [bool]$closure.declared_study.complete_nine_report_aggregate_required_for_three_engine_interpretation
) "$gateId closure identity or declared study changed"

Assert-R23D2Closure (Test-Path -LiteralPath $evidenceRoot -PathType Container) (
    "$gateId retained attempt root is missing"
)
foreach ($artifact in @($attemptRecord.artifacts)) {
    $artifactPath = Join-Path $evidenceRoot ([string]$artifact.relative_path)
    Assert-R23D2Closure (
        (Test-Path -LiteralPath $artifactPath -PathType Leaf) -and
        (Get-Item -LiteralPath $artifactPath).Length -eq [long]$artifact.size_bytes -and
        "sha256:$(Get-R23D2RawSha256 $artifactPath)" -ceq [string]$artifact.raw_sha256
    ) "$gateId retained artifact is missing or changed: $([string]$artifact.relative_path)"
}
$treeBefore = Get-R23D2EvidenceTreeDigest $evidenceRoot
Assert-R23D2Closure (
    [string]$attemptRecord.evidence_tree.algorithm -ceq
        "sha256_utf8_sorted_relative_path_tab_bytes_tab_raw_sha256_lf_v1" -and
    @($attemptRecord.artifacts).Count -eq 35 -and
    [int]$treeBefore.file_count -eq 35 -and
    [int]$treeBefore.file_count -eq [int]$attemptRecord.evidence_tree.file_count -and
    [long]$treeBefore.total_byte_length -eq 260387 -and
    [long]$treeBefore.total_byte_length -eq [long]$attemptRecord.evidence_tree.total_byte_length -and
    [string]$treeBefore.tree_sha256 -ceq
        "23234435c42847ff1d52a925fee4708c1eee7047acf7b442001ba30533654b3f" -and
    [string]$treeBefore.tree_sha256 -ceq [string]$attemptRecord.evidence_tree.tree_sha256
) (
    "$gateId retained evidence tree changed: " +
    ($treeBefore | ConvertTo-Json -Compress)
)

$attemptPath = Join-Path $evidenceRoot "attempt.json"
$aggregateInputPath = Join-Path $evidenceRoot "aggregate-input.json"
$aggregateEvaluationPath = Join-Path $evidenceRoot "aggregate-evaluation.json"
$reportPath = Join-Path $evidenceRoot "report.json"
$completionPath = Join-Path $evidenceRoot "completion.json"
$attempt = Get-Content -Raw -LiteralPath $attemptPath |
    ConvertFrom-Json -AsHashtable -Depth 128
$aggregateInput = Get-Content -Raw -LiteralPath $aggregateInputPath |
    ConvertFrom-Json -AsHashtable -Depth 128
$aggregateEvaluation = Get-Content -Raw -LiteralPath $aggregateEvaluationPath |
    ConvertFrom-Json -AsHashtable -Depth 128
$report = Get-Content -Raw -LiteralPath $reportPath |
    ConvertFrom-Json -AsHashtable -Depth 128
$completion = Get-Content -Raw -LiteralPath $completionPath |
    ConvertFrom-Json -AsHashtable -Depth 128

Assert-R23D2Closure (
    [string]$attempt.schema_version -ceq "sporespore_qsdk_r23d2_attempt_v1" -and
    [string]$attempt.attempt_id -ceq $attemptId -and
    [string]$attempt.campaign_id -ceq $campaignId -and
    [string]$attempt.gate_id -ceq $gateId -and
    [string]$attempt.source_commit -ceq $sourceCommit -and
    [string]$attempt.origin_main_commit -ceq $sourceCommit -and
    [string]$attempt.live_main_commit -ceq $sourceCommit -and
    [bool]$attempt.physical_execution_authorized -and
    [bool]$attempt.single_use_supervisor_authorization -and
    [bool]$attempt.source_worktree_clean -and
    [bool]$attempt.source_matches_live_github_main -and
    [bool]$attempt.operation_lock_held -and
    [bool]$attempt.full_godot_attestation_valid -and
    [bool]$attempt.content_addressed_inputs_retained -and
    [bool]$attempt.complete_zero_world_gate_passed -and
    [bool]$attempt.one_shot_attempt_unconsumed -and
    (Test-R23D2SequenceEqual @($attempt.ordered_cell_ids) $expectedCells) -and
    -not [bool]$attempt.replacement_or_selective_rerun_permitted -and
    -not [bool]$attempt.physical_acceptance_authority
) "$gateId retained launch authorization changed"
Assert-R23D2Closure (
    [string]$attempt.contract_sha256 -ceq
        [string]$attempt.content_addressed_inputs.r23d2_development_contract.sha256 -and
    [string]$attempt.freeze_sha256 -ceq
        "sha256:fa6772d0456ae92250f770ca6130b8d91ec800323cee4ef1c4f3655bb13023ad" -and
    [string]$attempt.full_godot_attestation_sha256 -ceq
        [string]$closure.launch_attestation.raw_sha256 -and
    [string]$attempt.full_godot_attestation_sha256 -ceq
        [string]$attempt.content_addressed_inputs.full_godot_attestation.sha256
) "$gateId attempt source, freeze, contract, or attestation binding changed"

$casInputs = [Collections.IDictionary]$attempt.content_addressed_inputs
Assert-R23D2Closure (
    $casInputs.Count -eq 67 -and
    [int]$attemptRecord.content_addressed_input_count -eq 67
) "$gateId retained input CAS inventory changed"
foreach ($entry in $casInputs.GetEnumerator()) {
    Assert-R23D2CasReceipt $entry.Value "input $($entry.Key)"
}

$freezeBytes = Get-SporeGitBlobBytes `
    -RepositoryRoot $repoRoot `
    -Commit $sourceCommit `
    -Path "sdk/turning/r23d2_physical_freeze_v1.json"
Assert-R23D2Closure (
    "sha256:$(Get-SporeByteSha256 -Bytes $freezeBytes)" -ceq [string]$attempt.freeze_sha256
) "$gateId historical freeze digest changed"
$freeze = [Text.Encoding]::UTF8.GetString($freezeBytes) |
    ConvertFrom-Json -AsHashtable -Depth 128
Assert-R23D2Closure (
    [string]$freeze.schema_version -ceq "sporespore_qsdk_r23d2_physical_freeze_v1" -and
    [string]$freeze.status -ceq "frozen_supervisor_only_physical_authorized" -and
    [int]$freeze.declared_source_binding_count -eq 48 -and
    @($freeze.source_bindings).Count -eq 48 -and
    @($freeze.external_runtime_bindings).Count -eq 14 -and
    @($freeze.attempt_runtime_artifacts).Count -eq 17 -and
    (Test-R23D2SequenceEqual @($freeze.ordered_cell_ids) $expectedCells) -and
    [bool]$freeze.serial_one_shot_required -and
    -not [bool]$freeze.replacement_or_selective_rerun_permitted
) "$gateId historical freeze content changed"
$gitReproducibleSourceCount = 0
$casOnlySourcePaths = @()
$sourceExceptions = [ordered]@{}
foreach ($exception in @($closure.source_checkout_provenance.cas_retained_checkout_bindings)) {
    $sourceExceptions[[string]$exception.path] = $exception
}
foreach ($binding in @($freeze.source_bindings)) {
    $name = [string]$binding.name
    Assert-R23D2Closure (
        $casInputs.Contains($name) -and
        [string]$casInputs[$name].sha256 -ceq [string]$binding.raw_sha256 -and
        (Test-SporeHistoricalSourceAvailable `
            -RepositoryRoot $repoRoot `
            -Commit $sourceCommit `
            -Path ([string]$binding.path))
    ) "$gateId historical source or retained CAS binding changed: $([string]$binding.path)"
    $gitReproducible = Test-SporeHistoricalSourceSha256 `
        -RepositoryRoot $repoRoot `
        -Commit $sourceCommit `
        -Path ([string]$binding.path) `
        -ExpectedSha256 ([string]$binding.raw_sha256)
    if ($gitReproducible) {
        $gitReproducibleSourceCount += 1
        Assert-R23D2Closure (-not $sourceExceptions.Contains([string]$binding.path)) (
            "$gateId reproducible source was falsely classified CAS-only: $([string]$binding.path)"
        )
    } else {
        $path = [string]$binding.path
        $casOnlySourcePaths += $path
        Assert-R23D2Closure ($sourceExceptions.Contains($path)) (
            "$gateId nonregenerable checkout source was not explicitly classified: $path"
        )
        $exception = [Collections.IDictionary]$sourceExceptions[$path]
        $blob = Get-SporeGitBlobBytes `
            -RepositoryRoot $repoRoot `
            -Commit $sourceCommit `
            -Path $path
        Assert-R23D2Closure (
            [string]$exception.name -ceq $name -and
            [string]$exception.frozen_checkout_raw_sha256 -ceq
                [string]$binding.raw_sha256 -and
            "sha256:$(Get-SporeByteSha256 -Bytes $blob)" -ceq
                [string]$exception.git_blob_raw_sha256
        ) "$gateId CAS-only checkout classification changed: $path"
    }
}
Assert-R23D2Closure (
    [int]$closure.source_checkout_provenance.declared_source_binding_count -eq 48 -and
    [int]$closure.source_checkout_provenance.
        git_blob_or_uniform_crlf_reproducible_binding_count -eq 46 -and
    [int]$closure.source_checkout_provenance.
        exact_checkout_bytes_retained_only_by_attempt_cas_count -eq 2 -and
    $gitReproducibleSourceCount -eq 46 -and
    (Test-R23D2SequenceEqual @($casOnlySourcePaths) @(
        "scripts/lab/gait/sdk_godot_jolt_material_profiles.gd",
        "sdk/adapters/rapier/Cargo.toml"
    ))
) "$gateId source checkout provenance classification changed"
foreach ($binding in @($freeze.external_runtime_bindings)) {
    $name = [string]$binding.name
    Assert-R23D2Closure (
        $casInputs.Contains($name) -and
        [string]$casInputs[$name].sha256 -ceq [string]$binding.raw_sha256
    ) "$gateId retained external runtime binding changed: $name"
}
foreach ($artifact in @($freeze.attempt_runtime_artifacts)) {
    Assert-R23D2Closure (
        $casInputs.Contains([string]$artifact.name) -and
        [string]$casInputs[[string]$artifact.name].sha256 -ceq [string]$artifact.raw_sha256
    ) "$gateId retained attempt runtime changed: $([string]$artifact.name)"
}

$attestationRecord = [Collections.IDictionary]$closure.launch_attestation
$attestationPath = [IO.Path]::GetFullPath([string]$attestationRecord.path)
Assert-R23D2Closure (
    (Test-Path -LiteralPath $attestationPath -PathType Leaf) -and
    "sha256:$(Get-R23D2RawSha256 $attestationPath)" -ceq
        [string]$attestationRecord.raw_sha256 -and
    [string]$attestationRecord.source_commit -ceq $sourceCommit -and
    [string]$attestationRecord.source_tree_git_oid -ceq $sourceTree -and
    [bool]$attestationRecord.full_suite_passed -and
    [bool]$attestationRecord.godot_included -and
    -not [bool]$attestationRecord.one_shot_physical_campaign_executed -and
    [bool]$attestationRecord.all_attestation_claims_false -and
    [bool]$attestationRecord.production_verifier_passed_before_launch
) "$gateId launch attestation record changed"
$attestation = Get-Content -Raw -LiteralPath $attestationPath |
    ConvertFrom-Json -AsHashtable -Depth 128
Assert-R23D2Closure (
    [string]$attestation.schema_version -ceq
        "sporespore_full_godot_conformance_attestation_v2" -and
    [string]$attestation.status -ceq "full_godot_conformance_passed" -and
    [bool]$attestation.conformance.passed -and
    -not [bool]$attestation.conformance.skip_godot -and
    [bool]$attestation.conformance.godot_including -and
    -not [bool]$attestation.conformance.one_shot_physical_campaign_executed -and
    [string]$attestation.source.commit -ceq $sourceCommit -and
    [string]$attestation.source.tree_git_oid -ceq $sourceTree -and
    [string]$attestation.source.origin_main -ceq $sourceCommit -and
    [string]$attestation.source.live_github_main -ceq $sourceCommit -and
    [bool]$attestation.source.worktree_clean -and
    [bool]$attestation.source.clean_pushed_live -and
    @($attestation.source_bindings).Count -eq 4 -and
    (Test-R23D2ClaimsFalse $attestation.claims)
) "$gateId retained launch attestation content changed"

Assert-R23D2Closure (
    [string]$aggregateInput.schema_version -ceq
        "sporespore_qsdk_r23d2_aggregate_input_v1" -and
    (Test-R23D2SequenceEqual @($aggregateInput.ordered_cell_ids) $expectedCells) -and
    [int]$aggregateInput.retained_terminal_entry_count -eq 9 -and
    @($aggregateInput.ordered_terminal_entry_cas).Count -eq 9 -and
    -not [bool]$aggregateInput.physical_acceptance_authority
) "$gateId aggregate input changed"
foreach ($receipt in @($aggregateInput.ordered_terminal_entry_cas)) {
    Assert-R23D2CasReceipt $receipt "ordered terminal entry"
}

Assert-R23D2Closure (
    [string]$report.schema_version -ceq "sporespore_qsdk_r23d2_campaign_report_v1" -and
    [string]$report.campaign_id -ceq $campaignId -and
    [string]$report.gate_id -ceq $gateId -and
    [string]$report.source.commit -ceq $sourceCommit -and
    [string]$report.contract_sha256 -ceq [string]$attempt.contract_sha256 -and
    [string]$report.freeze_sha256 -ceq [string]$attempt.freeze_sha256 -and
    @($report.ordered_cells).Count -eq 9 -and
    [int]$report.retained_terminal_entry_count -eq 9 -and
    [string]$report.result_classification -ceq "invalid_or_incomplete" -and
    -not [bool]$report.development_screen_valid -and
    -not [bool]$report.development_screen_passed -and
    [bool]$report.claims.development_screen_only -and
    @($report.claims.GetEnumerator() | Where-Object {
        [string]$_.Key -cne "development_screen_only" -and [bool]$_.Value
    }).Count -eq 0
) "$gateId diagnostic campaign report changed"
foreach ($pair in @(
    @($report.attempt_cas, $attemptPath),
    @($report.aggregate_input_cas, $aggregateInputPath),
    @($report.aggregate_evaluation_cas, $aggregateEvaluationPath),
    @($completion.report_cas, $reportPath)
)) {
    Assert-R23D2CasReceipt $pair[0] "aggregate artifact"
    Assert-R23D2Closure (
        [string]$pair[0].sha256 -ceq "sha256:$(Get-R23D2RawSha256 ([string]$pair[1]))"
    ) "$gateId aggregate artifact CAS chain changed"
}

$expectedClassifications = @(
    "worker_failure", "worker_failure", "worker_failure",
    "valid_positive", "valid_positive", "valid_negative",
    "valid_positive", "valid_positive", "valid_negative"
)
$expectedFailures = [ordered]@{
    rapier_parry__negative_heading = @(
        "R23D2_TORSO_GROUND", "R23D2_TILT", "R23D2_TORSO_HEIGHT",
        "R23D2_CONTACT_CYCLES", "R23D2_SIGNED_CONTROLLER_RESPONSE", "R23D2_TURN_WALK"
    )
    mujoco__negative_heading = @("R23D2_TILT", "R23D2_TURN_WALK")
}
$terminalPaths = @()
for ($index = 0; $index -lt $expectedCells.Count; $index += 1) {
    $cellId = $expectedCells[$index]
    $cell = [Collections.IDictionary]$report.ordered_cells[$index]
    $terminalPath = Join-Path $evidenceRoot "$cellId\terminal-entry.json"
    $evaluationPath = Join-Path $evidenceRoot "$cellId\entry-evaluation.json"
    $terminalPaths += $terminalPath
    $terminal = Get-Content -Raw -LiteralPath $terminalPath |
        ConvertFrom-Json -AsHashtable -Depth 128
    $evaluation = Get-Content -Raw -LiteralPath $evaluationPath |
        ConvertFrom-Json -AsHashtable -Depth 128
    Assert-R23D2Closure (
        [string]$cell.cell_id -ceq $cellId -and
        [bool]$cell.process_launch_succeeded -and
        -not [bool]$cell.process_timed_out -and
        -not [bool]$cell.physical_acceptance_authority -and
        [string]$evaluation.cell_id -ceq $cellId -and
        [string]$evaluation.result_classification -ceq $expectedClassifications[$index] -and
        [bool]$evaluation.entry_valid -and
        [int]$evaluation.world_attempt_count -eq 1 -and
        [int]$evaluation.world_build_count -eq 1 -and
        -not [bool]$evaluation.q_sdk_r23_satisfied -and
        -not [bool]$evaluation.physical_acceptance_authority
    ) "$gateId retained cell disposition changed: $cellId"
    Assert-R23D2CasReceipt $cell.engine_log_cas "engine log $cellId"
    Assert-R23D2CasReceipt $cell.terminal_entry_cas "terminal entry $cellId"
    Assert-R23D2CasReceipt $cell.entry_evaluation_cas "entry evaluation $cellId"
    Assert-R23D2Closure (
        [string]$cell.terminal_entry_cas.sha256 -ceq
            "sha256:$(Get-R23D2RawSha256 $terminalPath)" -and
        [string]$cell.entry_evaluation_cas.sha256 -ceq
            "sha256:$(Get-R23D2RawSha256 $evaluationPath)"
    ) "$gateId retained cell CAS path changed: $cellId"

    $recomputed = Invoke-R23D2Evaluator @("evaluate-entry", $terminalPath)
    Assert-R23D2Closure (
        [int]$recomputed.exit_code -eq 0 -and
        $null -ne $recomputed.document -and
        [string]$recomputed.document.cell_id -ceq $cellId -and
        [string]$recomputed.document.result_classification -ceq
            [string]$evaluation.result_classification -and
        [bool]$recomputed.document.entry_valid -eq [bool]$evaluation.entry_valid -and
        [bool]$recomputed.document.execution_valid -eq [bool]$evaluation.execution_valid -and
        [bool]$recomputed.document.screen_cell_passed -eq [bool]$evaluation.screen_cell_passed -and
        (Test-R23D2SequenceEqual @($recomputed.document.failure_codes) @($evaluation.failure_codes))
    ) "$gateId independent cell recomputation changed: $cellId`n$($recomputed.text)"

    if ($index -lt 3) {
        $logPath = Join-Path $evidenceRoot "$cellId\engine.log"
        $logText = Get-Content -Raw -LiteralPath $logPath
        Assert-R23D2Closure (
            [int]$cell.process_exit_code -eq 1 -and
            [string]$cell.terminal_marker_kind -ceq "worker_failure" -and
            [string]$terminal.schema_version -ceq
                "sporespore_qsdk_r23d2_worker_failure_v1" -and
            [string]$terminal.process_failure_code -ceq
                "QSDK_R23D2_GJT_SDK_EXECUTION_INVALID" -and
            [string]$terminal.stage_id -ceq "settlement_complete" -and
            [int]$terminal.world_attempt_count -eq 1 -and
            [int]$terminal.world_build_count -eq 1 -and
            -not $terminal.Contains("sdk_authority_summary") -and
            [string]$evaluation.entry_kind -ceq "worker_failure" -and
            -not [bool]$evaluation.execution_valid -and
            $logText.Contains("wave_tick=", [StringComparison]::Ordinal) -and
            $logText.Contains("QSDK_R23D2_GODOT_JOLT_FAILURE", [StringComparison]::Ordinal) -and
            $logText.Contains("QSDK_R23D2_GJT_SDK_EXECUTION_INVALID", [StringComparison]::Ordinal)
        ) "$gateId Godot/Jolt retained failure changed: $cellId"
    } else {
        $engine = [string]$terminal.engine_id
        $arm = [string]$terminal.arm_id
        $engineRecord = [Collections.IDictionary]$closure.engine_results[$engine]
        $expected = [Collections.IDictionary]$engineRecord[$arm]
        [object[]]$failures = @()
        if ($expectedFailures.Contains($cellId)) {
            $failures = @($expectedFailures[$cellId])
        }
        Assert-R23D2Closure (
            [int]$cell.process_exit_code -eq 0 -and
            [string]$cell.terminal_marker_kind -ceq "successful_report" -and
            [string]$terminal.schema_version -ceq
                "sporespore_qsdk_r23d2_engine_cell_report_v1" -and
            [string]$terminal.cell_id -ceq $cellId -and
            [string]$terminal.source_commit -ceq $sourceCommit -and
            [int]$terminal.execution.world_attempt_count -eq 1 -and
            [int]$terminal.execution.world_build_count -eq 1 -and
            [int]$terminal.execution.world_reset_count -eq 0 -and
            [int]$terminal.execution.controller_semantic_step_count -eq 2992 -and
            [int]$terminal.execution.validated_portable_command_count -eq 23936 -and
            [int]$terminal.execution.native_actuation_application_count -eq 23936 -and
            [int]$terminal.execution.controller_error_count -eq 0 -and
            [int]$terminal.execution.safe_no_actuation_count -eq 0 -and
            [int]$terminal.execution.actuator_application_mismatch_count -eq 0 -and
            [int]$terminal.execution.nonfinite_observation_count -eq 0 -and
            [int]$terminal.execution.direct_body_write_count -eq 0 -and
            [int]$terminal.command_validation.accepted_receipt_count -eq 2992 -and
            [int]$terminal.command_validation.rejected_receipt_count -eq 0 -and
            [int]$terminal.command_validation.predicate_failure_count -eq 0 -and
            [string]$evaluation.result_classification -ceq [string]$expected.classification -and
            (Test-R23D2SequenceEqual @($evaluation.failure_codes) $failures) -and
            (Test-R23D2SequenceEqual @($evaluation.outcome_failure_codes) $failures) -and
            @($evaluation.integrity_failure_codes).Count -eq 0 -and
            [bool]$evaluation.execution_valid
        ) "$gateId complete engine report changed: $cellId"
        Assert-R23D2CloseNumber $cell.process_duration_seconds $expected.duration_seconds (
            "$cellId duration"
        ) 1.0e-7
        Assert-R23D2CloseNumber $terminal.physics.final_forward_displacement_m `
            $expected.forward_m "$cellId forward displacement"
        Assert-R23D2CloseNumber $terminal.physics.turn_phase_yaw_delta_rad `
            $expected.yaw_delta_rad "$cellId yaw delta"
        Assert-R23D2CloseNumber $terminal.physics.maximum_tilt_rad `
            $expected.maximum_tilt_rad "$cellId maximum tilt"
        Assert-R23D2CloseNumber $terminal.physics.minimum_torso_height_m `
            $expected.minimum_torso_height_m "$cellId minimum torso height"
        Assert-R23D2Closure (
            [int]$terminal.physics.torso_ground_contact_step_count -eq
                [int]$expected.torso_ground_steps
        ) "$gateId $cellId torso-ground count changed"
    }
}

$aggregateArguments = @("evaluate-aggregate") + $terminalPaths
$aggregateRecomputed = Invoke-R23D2Evaluator -Arguments $aggregateArguments
Assert-R23D2Closure (
    [int]$aggregateRecomputed.exit_code -eq 1 -and
    $null -ne $aggregateRecomputed.document -and
    -not [bool]$aggregateRecomputed.document.aggregate_valid -and
    [string]$aggregateRecomputed.document.result_classification -ceq "invalid_or_incomplete" -and
    [int]$aggregateRecomputed.document.entry_count -eq 9 -and
    [int]$aggregateRecomputed.document.report_count -eq 6 -and
    [int]$aggregateRecomputed.document.worker_failure_count -eq 3 -and
    [int]$aggregateRecomputed.document.valid_positive_cell_count -eq 4 -and
    [int]$aggregateRecomputed.document.valid_negative_cell_count -eq 2 -and
    [int]$aggregateRecomputed.document.world_attempt_count -eq 9 -and
    [int]$aggregateRecomputed.document.world_build_count -eq 9 -and
    (Test-R23D2SequenceEqual @($aggregateRecomputed.document.failure_codes) @(
        "R23D2_AGGREGATE_WORKER_FAILURE_PRESENT",
        "R23D2_AGGREGATE_COMPLETE_REPORT_COUNT"
    ))
) "$gateId independent aggregate recomputation changed`n$($aggregateRecomputed.text)"
Assert-R23D2Closure (
    [string]$aggregateEvaluation.schema_version -ceq
        "sporespore_qsdk_r23d2_aggregate_evaluation_v1" -and
    -not [bool]$aggregateEvaluation.aggregate_valid -and
    -not [bool]$aggregateEvaluation.development_screen_valid -and
    -not [bool]$aggregateEvaluation.development_screen_passed -and
    [int]$aggregateEvaluation.entry_count -eq 9 -and
    [int]$aggregateEvaluation.report_count -eq 6 -and
    [int]$aggregateEvaluation.worker_failure_count -eq 3 -and
    [int]$aggregateEvaluation.valid_positive_cell_count -eq 4 -and
    [int]$aggregateEvaluation.valid_negative_cell_count -eq 2 -and
    [int]$aggregateEvaluation.world_attempt_count -eq 9 -and
    [int]$aggregateEvaluation.world_build_count -eq 9 -and
    (Test-R23D2SequenceEqual @($aggregateEvaluation.failure_codes) @(
        "R23D2_AGGREGATE_WORKER_FAILURE_PRESENT",
        "R23D2_AGGREGATE_COMPLETE_REPORT_COUNT"
    )) -and
    -not [bool]$aggregateEvaluation.command_conditioned_turning -and
    -not [bool]$aggregateEvaluation.cross_engine_equivalence -and
    -not [bool]$aggregateEvaluation.q_sdk_r23_satisfied -and
    -not [bool]$aggregateEvaluation.release_authorized -and
    -not [bool]$aggregateEvaluation.physical_acceptance_authority
) "$gateId retained aggregate evaluation changed"

Assert-R23D2Closure (
    [string]$completion.schema_version -ceq "sporespore_qsdk_r23d2_completion_v1" -and
    [string]$completion.campaign_id -ceq $campaignId -and
    [string]$completion.status -ceq "invalid_or_incomplete_first_attempt" -and
    [string]$completion.source_commit -ceq $sourceCommit -and
    [int]$completion.ordered_cell_count -eq 9 -and
    [int]$completion.retained_terminal_entry_count -eq 9 -and
    [string]$completion.result_classification -ceq "invalid_or_incomplete" -and
    [bool]$completion.one_shot_identity_consumed -and
    -not [bool]$completion.same_identity_rerun_allowed -and
    -not [bool]$completion.q_sdk_r23_satisfied -and
    -not [bool]$completion.cross_engine_equivalence -and
    -not [bool]$completion.release_authorized -and
    -not [bool]$completion.physical_acceptance_authority
) "$gateId retained completion changed"
Assert-R23D2Closure (
    [int]$attemptRecord.physical_process_launch_count -eq 9 -and
    [int]$attemptRecord.process_exit_zero_count -eq 6 -and
    [int]$attemptRecord.process_exit_nonzero_count -eq 3 -and
    [int]$attemptRecord.process_timeout_count -eq 0 -and
    [int]$attemptRecord.world_attempt_count -eq 9 -and
    [int]$attemptRecord.world_build_count -eq 9 -and
    [int]$attemptRecord.complete_cell_report_count -eq 6 -and
    [int]$attemptRecord.worker_failure_count -eq 3 -and
    [int]$attemptRecord.valid_positive_cell_count -eq 4 -and
    [int]$attemptRecord.valid_negative_cell_count -eq 2 -and
    -not [bool]$attemptRecord.valid_complete_three_engine_aggregate_present -and
    [bool]$attemptRecord.one_shot_identity_consumed -and
    -not [bool]$attemptRecord.same_identity_rerun_allowed -and
    -not [bool]$attemptRecord.replacement_or_selective_rerun_allowed
) "$gateId consumed-attempt summary changed"

$historicalGodotSource = [Text.Encoding]::UTF8.GetString((Get-SporeGitBlobBytes `
    -RepositoryRoot $repoRoot `
    -Commit $sourceCommit `
    -Path "tests/test_sdk_qsdk_r23d2_godot_jolt_worker.gd"))
Assert-R23D2Closure (
    $historicalGodotSource.Contains('not bool(sdk_summary.get("ok", false))') -and
    $historicalGodotSource.Contains('int(sdk_summary.get("step_count", -1)) != CONTROLLER_STEPS') -and
    $historicalGodotSource.Contains(
        'int(sdk_summary.get("validated_balanced_wave_command_count", -1))'
    ) -and
    $historicalGodotSource.Contains(
        'int(sdk_summary.get("native_actuation_application_count", -1))'
    ) -and
    $historicalGodotSource.Contains('return "QSDK_R23D2_GJT_SDK_EXECUTION_INVALID"') -and
    -not [bool]$closure.implementation_diagnosis.godot_jolt.exact_failed_subpredicate_known -and
    [bool]$closure.implementation_diagnosis.godot_jolt.do_not_guess_or_reconstruct
) "$gateId Godot/Jolt grouped failure diagnosis changed"
Assert-R23D2Closure (
    [string]$closure.aggregate_disposition.result_classification -ceq
        "invalid_or_incomplete" -and
    -not [bool]$closure.aggregate_disposition.aggregate_valid -and
    [bool]$closure.aggregate_disposition.optimization_is_allowed -and
    [bool]$closure.implementation_diagnosis.negative_heading.
        positive_heading_passed_in_both_complete_non_godot_engines -and
    -not [bool]$closure.implementation_diagnosis.negative_heading.
        negative_heading_passed_in_either_complete_non_godot_engine -and
    [bool]$closure.immutability.same_identity_rerun_forbidden -and
    [bool]$closure.immutability.selective_completion_forbidden -and
    [bool]$closure.immutability.replacement_worker_process_forbidden -and
    [bool]$closure.immutability.attempt_or_evidence_rewrite_forbidden -and
    [bool]$closure.immutability.frozen_threshold_or_evaluator_rewrite_forbidden -and
    [bool]$closure.immutability.successor_requires_new_campaign_and_gate_identity -and
    [string]$closure.successor_requirements.successor_id -ceq "QSDK-R23D3" -and
    [bool]$closure.successor_requirements.retain_full_godot_sdk_authority_summary_on_every_post_world_failure -and
    [bool]$closure.successor_requirements.retain_each_grouped_execution_subpredicate_and_observed_value -and
    [bool]$closure.successor_requirements.real_summary_field_mutation_canaries_required_before_physics -and
    [bool]$closure.successor_requirements.negative_heading_directional_mechanism_diagnosis_required -and
    [bool]$closure.successor_requirements.
        all_source_raw_hashes_must_be_git_blob_or_declared_checkout_projection_reproducible
) "$gateId scientific, immutability, or successor boundary changed"
Assert-R23D2Closure (
    [bool]$closure.claims.complete_attempt_closure -and
    @($closure.claims.GetEnumerator() | Where-Object {
        [string]$_.Key -cne "complete_attempt_closure" -and [bool]$_.Value
    }).Count -eq 0
) "$gateId closure claim boundary changed"

# Negative controls prove that a plausible-looking mutation cannot pass the
# retained evaluator or the closure's CAS and claim predicates.
$tamperedCas = $report.attempt_cas | ConvertTo-Json -Depth 32 |
    ConvertFrom-Json -AsHashtable -Depth 32
$tamperedCas.byte_length = [long]$tamperedCas.byte_length + 1
Assert-R23D2Closure (-not (Test-R23D2CasReceipt $tamperedCas)) (
    "$gateId tampered CAS receipt was accepted"
)
$tamperedClaims = $completion | ConvertTo-Json -Depth 32 |
    ConvertFrom-Json -AsHashtable -Depth 32
$tamperedClaims.q_sdk_r23_satisfied = $true
Assert-R23D2Closure (-not (Test-R23D2ClaimsFalse ([ordered]@{
    q_sdk_r23_satisfied = $tamperedClaims.q_sdk_r23_satisfied
    cross_engine_equivalence = $tamperedClaims.cross_engine_equivalence
    release_authorized = $tamperedClaims.release_authorized
    physical_acceptance_authority = $tamperedClaims.physical_acceptance_authority
}))) "$gateId tampered claim was accepted"

$tempRoot = Join-Path ([IO.Path]::GetTempPath()) (
    "sporespore-r23d2-closure-" + [guid]::NewGuid().ToString("N")
)
[void](New-Item -ItemType Directory -Path $tempRoot)
try {
    $tamperedReport = Get-Content -Raw -LiteralPath $terminalPaths[3] |
        ConvertFrom-Json -AsHashtable -Depth 128
    $tamperedReport.execution.controller_semantic_step_count = 2991
    $tamperedReportPath = Join-Path $tempRoot "tampered-report.json"
    $tamperedReport | ConvertTo-Json -Depth 100 -Compress |
        Set-Content -LiteralPath $tamperedReportPath -Encoding utf8NoBOM
    $tamperedReportEvaluation = Invoke-R23D2Evaluator @("evaluate-entry", $tamperedReportPath)
    Assert-R23D2Closure (
        [int]$tamperedReportEvaluation.exit_code -eq 1 -and
        $null -ne $tamperedReportEvaluation.document -and
        -not [bool]$tamperedReportEvaluation.document.entry_valid
    ) "$gateId tampered successful report was accepted"

    $tamperedFailure = Get-Content -Raw -LiteralPath $terminalPaths[0] |
        ConvertFrom-Json -AsHashtable -Depth 128
    $tamperedFailure.world_build_count = 0
    $tamperedFailurePath = Join-Path $tempRoot "tampered-failure.json"
    $tamperedFailure | ConvertTo-Json -Depth 100 -Compress |
        Set-Content -LiteralPath $tamperedFailurePath -Encoding utf8NoBOM
    $tamperedFailureEvaluation = Invoke-R23D2Evaluator @("evaluate-entry", $tamperedFailurePath)
    Assert-R23D2Closure (
        [int]$tamperedFailureEvaluation.exit_code -eq 1 -and
        $null -ne $tamperedFailureEvaluation.document -and
        -not [bool]$tamperedFailureEvaluation.document.entry_valid
    ) "$gateId tampered worker failure was accepted"

    $incompleteAggregateArguments = @("evaluate-aggregate") + $terminalPaths[0..7]
    $incompleteAggregate = Invoke-R23D2Evaluator `
        -Arguments $incompleteAggregateArguments
    Assert-R23D2Closure (
        [int]$incompleteAggregate.exit_code -eq 1 -and
        $null -ne $incompleteAggregate.document -and
        -not [bool]$incompleteAggregate.document.aggregate_valid -and
        [int]$incompleteAggregate.document.entry_count -eq 8
    ) "$gateId incomplete aggregate negative control was accepted"
} finally {
    $resolvedTemp = [IO.Path]::GetFullPath($tempRoot)
    Assert-R23D2Closure (
        $resolvedTemp.StartsWith([IO.Path]::GetFullPath([IO.Path]::GetTempPath())) -and
        (Split-Path -Leaf $resolvedTemp).StartsWith("sporespore-r23d2-closure-")
    ) "$gateId temporary negative-control path escaped"
    Remove-Item -LiteralPath $resolvedTemp -Recurse -Force
}

# Current closure interlocks are deliberately separate from historical source.
# They must appear before contract, authorization, model, or solver loading.
$currentSupervisor = Get-Content -Raw -LiteralPath $runnerPath
$currentRapierPath = Join-Path $sdkRoot "adapters\rapier\src\qsdk_r23d2_heading_response.rs"
$currentMujocoPath = Join-Path $sdkRoot (
    "adapters\mujoco\sporespore_mujoco_adapter\qsdk_r23d2_heading_response.py"
)
$currentGodotPath = Join-Path $PSScriptRoot "test_sdk_qsdk_r23d2_godot_jolt_worker.gd"
$currentRapier = Get-Content -Raw -LiteralPath $currentRapierPath
$currentMujoco = Get-Content -Raw -LiteralPath $currentMujocoPath
$currentGodot = Get-Content -Raw -LiteralPath $currentGodotPath
$rapierPhysical = $currentRapier.IndexOf("pub fn run_qsdk_r23d2_rapier_physical")
$rapierGuard = $currentRapier.IndexOf("if PHYSICAL_IDENTITY_CLOSED", $rapierPhysical)
$rapierContract = $currentRapier.IndexOf("let (oracle_contract, _, development)", $rapierPhysical)
$mujocoPhysical = $currentMujoco.IndexOf("def run_physical(")
$mujocoGuard = $currentMujoco.IndexOf("if PHYSICAL_IDENTITY_CLOSED:", $mujocoPhysical)
$mujocoContract = $currentMujoco.IndexOf("oracle, _, development = _contracts()", $mujocoPhysical)
$godotRun = $currentGodot.IndexOf("func _run() -> void:")
$godotGuard = $currentGodot.IndexOf('mode == "physical" and PHYSICAL_IDENTITY_CLOSED', $godotRun)
$godotContract = $currentGodot.IndexOf(
    "var development_contract := _read_json(DEVELOPMENT_CONTRACT_PATH)", $godotRun
)
$supervisorGuard = $currentSupervisor.IndexOf(
    'if ($RunPhysical -and $physicalIdentityClosed)'
)
$supervisorInputLoad = $currentSupervisor.IndexOf(
    '$contract = Get-Content -Raw -LiteralPath $contractPath'
)
Assert-R23D2Closure (
    $currentSupervisor.Contains('$physicalIdentityClosed = $true') -and
    $supervisorGuard -ge 0 -and $supervisorGuard -lt $supervisorInputLoad -and
    $currentSupervisor.Contains("QSDK-R23D2 is closed and may not open another world") -and
    $currentRapier.Contains("const PHYSICAL_IDENTITY_CLOSED: bool = true;") -and
    $rapierPhysical -ge 0 -and $rapierGuard -gt $rapierPhysical -and
    $rapierGuard -lt $rapierContract -and
    $currentRapier.Contains("QSDK_R23D2_RAP_PHYSICAL_IDENTITY_CLOSED") -and
    $currentMujoco.Contains("PHYSICAL_IDENTITY_CLOSED = True") -and
    $mujocoPhysical -ge 0 -and $mujocoGuard -gt $mujocoPhysical -and
    $mujocoGuard -lt $mujocoContract -and
    $currentMujoco.Contains("QSDK_R23D2_MJC_PHYSICAL_IDENTITY_CLOSED") -and
    $currentGodot.Contains("const PHYSICAL_IDENTITY_CLOSED := true") -and
    $godotRun -ge 0 -and $godotGuard -gt $godotRun -and
    $godotGuard -lt $godotContract -and
    $currentGodot.Contains("QSDK_R23D2_GJT_PHYSICAL_IDENTITY_CLOSED")
) "$gateId current supervisor or worker closure interlock changed"

$attemptRootsBefore = @(
    Get-ChildItem -LiteralPath (Split-Path -Parent $evidenceRoot) -Directory |
        Where-Object { $_.Name -like "qsdk-r23d2-*" }
)
Assert-R23D2Closure (
    $attemptRootsBefore.Count -eq 1 -and
    [IO.Path]::GetFullPath($attemptRootsBefore[0].FullName) -ceq $evidenceRoot
) "$gateId retained attempt cardinality changed"
$canaryAttestation = Join-Path $repoRoot "R23D2_CLOSED_CANARY_DO_NOT_READ.json"
$canaryOutput = Join-Path $repoRoot "R23D2_CLOSED_CANARY_DO_NOT_CREATE"
Assert-R23D2Closure (
    -not (Test-Path -LiteralPath $canaryAttestation) -and
    -not (Test-Path -LiteralPath $canaryOutput)
) "$gateId rerun canary unexpectedly exists"
$rerunOutput = @(& pwsh -NoLogo -NoProfile -File $runnerPath `
    -RunPhysical `
    -FullConformanceAttestation $canaryAttestation `
    -OutputRoot $canaryOutput 2>&1)
$rerunExit = $LASTEXITCODE
$rerunText = $rerunOutput -join "`n"
Assert-R23D2Closure (
    $rerunExit -ne 0 -and
    $rerunText.Contains(
        "QSDK-R23D2 is closed and may not open another world",
        [StringComparison]::Ordinal
    ) -and
    -not $rerunText.Contains("full-Godot V2 attestation", [StringComparison]::Ordinal) -and
    -not (Test-Path -LiteralPath $canaryOutput)
) "$gateId current closed-state rerun interlock changed: $rerunText"
$attemptRootsAfter = @(
    Get-ChildItem -LiteralPath (Split-Path -Parent $evidenceRoot) -Directory |
        Where-Object { $_.Name -like "qsdk-r23d2-*" }
)
$treeAfter = Get-R23D2EvidenceTreeDigest $evidenceRoot
Assert-R23D2Closure (
    $attemptRootsAfter.Count -eq 1 -and
    [IO.Path]::GetFullPath($attemptRootsAfter[0].FullName) -ceq $evidenceRoot -and
    [int]$treeAfter.file_count -eq [int]$treeBefore.file_count -and
    [long]$treeAfter.total_byte_length -eq [long]$treeBefore.total_byte_length -and
    [string]$treeAfter.tree_sha256 -ceq [string]$treeBefore.tree_sha256
) "$gateId rerun canary changed the retained attempt"
$global:LASTEXITCODE = 0

Write-Host (
    "QSDK_R23D2_CLOSURE_PASS status=invalid/incomplete processes=9 worlds=9/9 " +
    "reports=6 worker_failures=3 positives=4 negatives=2 godot_reports=0/3 " +
    "aggregate=False scientific_three_engine_result=False turning=False " +
    "q_sdk_r23=False equivalence=False release=False rerun_refused=True"
)
