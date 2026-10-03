#requires -Version 7.0

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$sdkRoot = Join-Path $repoRoot "sdk"
$mujocoRoot = Join-Path $sdkRoot "adapters\mujoco"
$python = Join-Path $mujocoRoot ".venv\Scripts\python.exe"
$rapierBinary = Join-Path $sdkRoot (
    "target\release\cross_engine_discrete_material_validation_xv1_rapier.exe"
)
$closurePath = Join-Path $sdkRoot (
    "cross_engine_c6_bw19v_discrete_material_validation_xv1_closure.json"
)
$runnerPath = Join-Path $sdkRoot (
    "run_cross_engine_c6_bw19v_discrete_material_validation_xv1.ps1"
)
$sourceCommit = "88a7b870ac2e7f05fa11b468aa93a41748ac4ef6"
$sourceTree = "9457f5f646c73da40b348634c4c488dfa699edf6"
$campaignId = "C6-CROSS-ENGINE-BW19V-DISCRETE-MATERIAL-VALIDATION-XV1"
$gateId = "C6-XE-BW19V-XV1"
$expectedClosureSha256 =
    "67f1347a77a997de25809fd7ceef638e95020ab30df666e4cd9de3490acf8e03"
$attemptRoot = [IO.Path]::GetFullPath(
    "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence\" +
    "c6-cross-engine-bw19v-xv1-88a7b87"
)
$attestationPath = [IO.Path]::GetFullPath(
    "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence\" +
    "full-godot-conformance-v2-88a7b87-20260804T065343Z\attestation.json"
)

. (Join-Path $PSScriptRoot "closed_experiment_source_audit.ps1")

function Assert-Exact {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function Get-RawSha256 {
    param([Parameter(Mandatory)][string]$Path)
    return (
        Get-FileHash -Algorithm SHA256 -LiteralPath $Path
    ).Hash.ToLowerInvariant()
}

function Get-EvidenceTreeDigest {
    param([Parameter(Mandatory)][string]$Root)
    $files = @(Get-ChildItem -LiteralPath $Root -File -Recurse)
    $lines = foreach ($file in @(
        $files | Sort-Object {
            $_.FullName.Substring($Root.Length + 1).Replace("\", "/")
        }
    )) {
        $relativePath = $file.FullName.Substring(
            $Root.Length + 1
        ).Replace("\", "/")
        "$relativePath`t$($file.Length)`t$(Get-RawSha256 -Path $file.FullName)"
    }
    $text = ($lines -join "`n") + "`n"
    return [ordered]@{
        file_count = $files.Count
        total_byte_length = [long](
            $files | Measure-Object -Property Length -Sum
        ).Sum
        tree_sha256 = [Convert]::ToHexString(
            [Security.Cryptography.SHA256]::HashData(
                [Text.Encoding]::UTF8.GetBytes($text)
            )
        ).ToLowerInvariant()
    }
}

function Assert-AbsoluteArtifact {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][long]$SizeBytes,
        [Parameter(Mandatory)][string]$RawSha256,
        [Parameter(Mandatory)][string]$Label
    )
    Assert-Exact (
        (Test-Path -LiteralPath $Path -PathType Leaf) -and
        (Get-Item -LiteralPath $Path).Length -eq $SizeBytes -and
        (Get-RawSha256 -Path $Path) -ceq $RawSha256.Replace("sha256:", "")
    ) "$gateId retained $Label is missing or changed"
}

Assert-Exact (
    (git -C $repoRoot rev-parse --show-toplevel).Trim() -ceq
        $repoRoot.Replace("\", "/") -and
    (git -C $repoRoot remote get-url origin).Trim() -ceq
        "https://github.com/Slagathore/sporespore.git" -and
    (Test-Path -LiteralPath $closurePath -PathType Leaf) -and
    (Get-RawSha256 -Path $closurePath) -ceq $expectedClosureSha256
) "$gateId closure identity changed"

$closure = Get-Content -Raw -LiteralPath $closurePath |
    ConvertFrom-Json -AsHashtable -Depth 128
Assert-Exact (
    [string]$closure.schema_version -ceq
        "sporespore_cross_engine_c6_bw19v_discrete_material_validation_xv1_closure_v1" -and
    [string]$closure.status -ceq
        "closed_consumed_implementation_invalid_incomplete_no_aggregate_result" -and
    [string]$closure.campaign_id -ceq $campaignId -and
    [string]$closure.gate_id -ceq $gateId -and
    [string]$closure.experiment_source_commit -ceq $sourceCommit -and
    [string]$closure.experiment_source_tree_git_oid -ceq $sourceTree -and
    [bool]$closure.source_was_clean_and_equal_to_origin_main_and_live_github_main -and
    [int]$closure.declared_study.declared_world_count -eq 6 -and
    [int]$closure.declared_study.declared_cell_count -eq 6 -and
    [int]$closure.declared_study.declared_aggregate_gate_count -eq 12 -and
    [int]$closure.declared_study.declared_zero_world_negative_control_count -eq 117 -and
    [int]$closure.declared_study.replacement_worker_process_count -eq 0 -and
    [bool]$closure.declared_study.complete_six_cell_aggregate_required_for_scientific_interpretation
) "$gateId closure source, study, or result boundary changed"

& git -C $repoRoot cat-file -e "$sourceCommit`^{commit}"
Assert-Exact ($LASTEXITCODE -eq 0) "$gateId source commit is not retained"
Assert-Exact (
    (git -C $repoRoot rev-parse "$sourceCommit`^{tree}").Trim() -ceq $sourceTree
) "$gateId source tree changed"
& git -C $repoRoot merge-base --is-ancestor $sourceCommit HEAD
Assert-Exact ($LASTEXITCODE -eq 0) "$gateId source commit is not an ancestor of HEAD"
& git -C $repoRoot merge-base --is-ancestor $sourceCommit origin/main
Assert-Exact ($LASTEXITCODE -eq 0) "$gateId source commit is not on origin/main"

foreach ($binding in $closure.bound_source_inventory.Values) {
    $relativePath = [string]$binding.path
    Assert-Exact (
        Test-SporeHistoricalSourceSha256 `
            -RepositoryRoot $repoRoot `
            -Commit $sourceCommit `
            -Path $relativePath `
            -ExpectedSha256 ([string]$binding.raw_sha256)
    ) "$gateId frozen source bytes changed: $relativePath"
    Assert-Exact (
        (git -C $repoRoot rev-parse "$sourceCommit`:$relativePath").Trim() -ceq
            [string]$binding.git_blob_oid
    ) "$gateId frozen source blob changed: $relativePath"
}

$historicalRunner = [Text.Encoding]::UTF8.GetString(
    (Get-SporeGitBlobBytes `
        -RepositoryRoot $repoRoot `
        -Commit $sourceCommit `
        -Path "sdk/run_cross_engine_c6_bw19v_discrete_material_validation_xv1.ps1")
)
Assert-Exact (
    [regex]::IsMatch(
        $historicalRunner,
        '\) "ok" \$false\)\r?\n\s*-and\r?\n\s*\[bool\]\(Get-Xv1MapValue \(',
        [Text.RegularExpressions.RegexOptions]::CultureInvariant
    ) -and
    ([regex]::Matches(
        $historicalRunner,
        '\r?\n\s*-and\r?\n'
    )).Count -eq 2
) "$gateId historical supervisor no longer reproduces the standalone -and defect"

Assert-AbsoluteArtifact `
    -Path $attestationPath `
    -SizeBytes ([long]$closure.full_godot_v2_attestation.size_bytes) `
    -RawSha256 ([string]$closure.full_godot_v2_attestation.raw_sha256) `
    -Label "full-Godot V2 attestation"
$attestation = Get-Content -Raw -LiteralPath $attestationPath |
    ConvertFrom-Json -AsHashtable -Depth 128
Assert-Exact (
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
    -not [bool]$attestation.conformance.skip_godot -and
    -not [bool]$attestation.conformance.one_shot_physical_campaign_executed -and
    @($attestation.claims.Values | Where-Object { [bool]$_ }).Count -eq 0
) "$gateId full-Godot V2 attestation boundary changed"

Assert-Exact (
    [string]$closure.consumed_attempt.evidence_root -ceq
        $attemptRoot.Replace("\", "/") -and
    (Test-Path -LiteralPath $attemptRoot -PathType Container)
) "$gateId retained evidence root is missing or changed"
foreach ($artifact in @($closure.consumed_attempt.artifacts)) {
    $artifactPath = [IO.Path]::GetFullPath(
        (Join-Path $attemptRoot ([string]$artifact.relative_path))
    )
    Assert-AbsoluteArtifact `
        -Path $artifactPath `
        -SizeBytes ([long]$artifact.size_bytes) `
        -RawSha256 ([string]$artifact.raw_sha256) `
        -Label ([string]$artifact.relative_path)
}
$tree = Get-EvidenceTreeDigest -Root $attemptRoot
Assert-Exact (
    [int]$tree.file_count -eq
        [int]$closure.consumed_attempt.evidence_tree.file_count -and
    [long]$tree.total_byte_length -eq
        [long]$closure.consumed_attempt.evidence_tree.total_byte_length -and
    [string]$tree.tree_sha256 -ceq
        [string]$closure.consumed_attempt.evidence_tree.tree_sha256
) "$gateId retained nineteen-file evidence tree changed"

$attempt = Get-Content -Raw -LiteralPath (Join-Path $attemptRoot "attempt.json") |
    ConvertFrom-Json -AsHashtable -Depth 128
$preflight = Get-Content -Raw -LiteralPath (Join-Path $attemptRoot "preflight.json") |
    ConvertFrom-Json -AsHashtable -Depth 128
$completion = Get-Content -Raw -LiteralPath (Join-Path $attemptRoot "completion.json") |
    ConvertFrom-Json -AsHashtable -Depth 128
Assert-Exact (
    [string]$attempt.attempt_id -ceq
        [string]$closure.consumed_attempt.attempt_id -and
    [string]$attempt.campaign_id -ceq $campaignId -and
    [string]$attempt.gate_id -ceq $gateId -and
    [string]$attempt.source_commit -ceq $sourceCommit -and
    [string]$attempt.source_tree_git_oid -ceq $sourceTree -and
    [string]$attempt.source_origin_main -ceq $sourceCommit -and
    [string]$attempt.source_live_github_main -ceq $sourceCommit -and
    @($attempt.declared_ordered_cells).Count -eq 6 -and
    [int]$attempt.declared_world_count -eq 6 -and
    [bool]$attempt.all_cells_execute_even_after_earlier_failure -and
    [int]$attempt.replacement_processes_allowed -eq 0 -and
    [bool]$attempt.physical_process_launch_consumes_identity -and
    -not [bool]$attempt.same_identity_rerun_allowed -and
    [bool]$attempt.operation_lock.acquired -and
    [string]$attempt.operation_lock.role -ceq "physical" -and
    -not [bool]$attempt.operation_lock.test_only
) "$gateId attempt reservation or operation-lock receipt changed"
Assert-Exact (
    [bool]$preflight.ok -and
    [int]$preflight.aggregate.negative_control_count -eq 22 -and
    [bool]$preflight.aggregate.all_negative_controls_rejected -and
    [int]$preflight.rapier.negative_control_count -eq 38 -and
    [bool]$preflight.rapier.all_negative_controls_rejected -and
    [int]$preflight.mujoco.negative_control_count -eq 57 -and
    @($preflight.mujoco.synthetic_report_negative_controls_rejected.Values |
        Where-Object { -not [bool]$_ }).Count -eq 0 -and
    [bool]$preflight.mujoco.real_dynamic_library_profile_canary.ok -and
    [bool]$preflight.mujoco.compiled_morphology_report_assembly_canary.ok -and
    [bool]$preflight.mujoco.real_controller_trace_projection_canary.ok -and
    [bool]$preflight.mujoco.engine_neutral_terminal_restoration_canary.ok -and
    [bool]$preflight.mujoco.production_kinematic_vector_representation_canary.ok -and
    [bool]$preflight.mujoco.material_xml_authoring_canary.ok -and
    [bool]$preflight.mujoco.shared_report_assembler_authority_schema_canary.ok -and
    [int]$preflight.total_negative_control_count -eq 117 -and
    [int]$preflight.model_or_world_build_count -eq 0 -and
    -not [bool]$preflight.physical_acceptance_authority
) "$gateId retained zero-world preflight changed"
Assert-Exact (
    [string]$completion.attempt_id -ceq [string]$attempt.attempt_id -and
    [string]$completion.status -ceq
        "supervisor_failed_after_identity_consumption" -and
    [int]$completion.physical_process_launch_count -eq 4 -and
    [int]$completion.retained_cell_summary_count -eq 3 -and
    -not [bool]$completion.same_identity_rerun_allowed -and
    [string]$completion.supervisor_failure -ceq (
        "The term '-and' is not recognized as a name of a cmdlet, function, " +
        "script file, or executable program.`r`nCheck the spelling of the name, " +
        "or if a path was included, verify that the path is correct and try again."
    )
) "$gateId implementation-invalid completion receipt changed"

Assert-Exact (
    -not (Test-Path -LiteralPath (Join-Path $attemptRoot "report.json")) -and
    -not (Test-Path -LiteralPath (Join-Path $attemptRoot "evaluation.json")) -and
    -not (Test-Path -LiteralPath (Join-Path $attemptRoot "cells\mujoco_mu060")) -and
    -not (Test-Path -LiteralPath (Join-Path $attemptRoot "cells\mujoco_mu100")) -and
    (@(Get-ChildItem -LiteralPath (Join-Path $attemptRoot "cells") -Directory |
        Sort-Object Name | ForEach-Object { $_.Name }) -join "|") -ceq
        "mujoco_mu020|rapier_mu020|rapier_mu060|rapier_mu100"
) "$gateId aggregate absence or unopened-cell boundary changed"

$expectedCells = @(
    @("rapier_mu020", "rapier", "0.2"),
    @("rapier_mu060", "rapier", "0.6"),
    @("rapier_mu100", "rapier", "1"),
    @("mujoco_mu020", "mujoco", "0.2")
)
Assert-Exact (
    @($closure.retained_cell_observations).Count -eq 4 -and
    @($closure.unopened_cells).Count -eq 2
) "$gateId retained and unopened cell counts changed"
foreach ($expected in $expectedCells) {
    $cellId = [string]$expected[0]
    $engine = [string]$expected[1]
    $observation = @($closure.retained_cell_observations | Where-Object {
        [string]$_.cell_id -ceq $cellId
    })
    Assert-Exact (
        $observation.Count -eq 1 -and
        [string]$observation[0].engine -ceq $engine -and
        [bool]$observation[0].complete_report_present -and
        [bool]$observation[0].worker_report_ok -and
        [bool]$observation[0].retained_cold_evaluation_ok -and
        [bool]$observation[0].fresh_closure_cold_replay_ok -and
        -not [bool]$observation[0].scientific_promotion_permitted
    ) "$gateId diagnostic observation changed for $cellId"
    $cold = Get-Content -Raw -LiteralPath (
        Join-Path $attemptRoot "cells\$cellId\cold_evaluation.json"
    ) | ConvertFrom-Json -AsHashtable -Depth 128
    Assert-Exact (
        [bool]$cold.ok -and
        [string]$cold.campaign_id -ceq $campaignId -and
        [string]$cold.gate_id -ceq $gateId -and
        [string]$cold.cell_id -ceq $cellId -and
        @($cold.failure_codes).Count -eq 0 -and
        [int]$cold.world_build_count -eq 0 -and
        -not [bool]$cold.physical_acceptance_authority
    ) "$gateId retained cold evaluation changed for $cellId"

    $reportPath = Join-Path $attemptRoot "cells\$cellId\report.json"
    if ($engine -ceq "rapier") {
        $coldLines = @(& $rapierBinary --evaluate-report $reportPath)
    }
    else {
        Push-Location -LiteralPath $mujocoRoot
        try {
            $coldLines = @(
                & $python `
                    -m sporespore_mujoco_adapter.cross_engine_discrete_material_validation_xv1_mujoco `
                    --evaluate-report $reportPath
            )
        }
        finally {
            Pop-Location
        }
    }
    Assert-Exact ($LASTEXITCODE -eq 0) (
        "$gateId fresh cold replay failed for $cellId"
    )
    $fresh = ($coldLines -join [Environment]::NewLine) |
        ConvertFrom-Json -AsHashtable -Depth 128
    Assert-Exact (
        [bool]$fresh.ok -and
        [string]$fresh.campaign_id -ceq $campaignId -and
        [string]$fresh.gate_id -ceq $gateId -and
        [string]$fresh.cell_id -ceq $cellId -and
        @($fresh.failure_codes).Count -eq 0 -and
        [int]$fresh.world_build_count -eq 0 -and
        -not [bool]$fresh.physical_acceptance_authority
    ) "$gateId fresh cold replay boundary changed for $cellId"
}

foreach ($unopened in @($closure.unopened_cells)) {
    Assert-Exact (
        -not [bool]$unopened.world_opened -and
        -not [bool]$unopened.worker_process_launched -and
        -not [bool]$unopened.report_present
    ) "$gateId unopened cell was reinterpreted as an outcome"
}
Assert-Exact (
    [string]$closure.implementation_failure.classification -ceq
        "supervisor_post_physical_summary_expression_tokenization_failure" -and
    [int]$closure.implementation_failure.first_failing_source_line -eq 682 -and
    [int]$closure.implementation_failure.second_equivalent_standalone_token_line -eq 686 -and
    -not [bool]$closure.implementation_failure.aggregate_report_assembly_reached -and
    -not [bool]$closure.implementation_failure.aggregate_evaluation_reached -and
    -not [bool]$closure.implementation_failure.remaining_worker_launches_reached -and
    [bool]$closure.technical_disposition.campaign_identity_consumed -and
    -not [bool]$closure.technical_disposition.declared_six_cell_matrix_completed -and
    -not [bool]$closure.technical_disposition.valid_complete_aggregate_report -and
    -not [bool]$closure.technical_disposition.declared_aggregate_gate_evaluated -and
    [bool]$closure.technical_disposition.four_complete_worker_reports_retained -and
    [bool]$closure.technical_disposition.four_worker_reports_pass_their_frozen_cell_evaluators -and
    [bool]$closure.technical_disposition.two_declared_cells_unopened -and
    -not [bool]$closure.technical_disposition.scientific_positive -and
    -not [bool]$closure.technical_disposition.scientific_negative -and
    [string]$closure.scientific_disposition.classification -ceq
        "no_scientific_result_implementation_invalid_incomplete_matrix" -and
    [bool]$closure.scientific_disposition.optimization_is_allowed
) "$gateId implementation or scientific no-result boundary changed"

Assert-Exact (
    [bool]$closure.immutability.same_identity_rerun_forbidden -and
    [bool]$closure.immutability.selective_completion_of_unopened_cells_forbidden -and
    [bool]$closure.immutability.four_passing_worker_reports_may_not_be_promoted_to_aggregate_evidence -and
    [bool]$closure.immutability.unopened_cells_may_not_be_reinterpreted_as_negative_outcomes -and
    [bool]$closure.immutability.successor_requires_new_identity -and
    [bool]$closure.next_allowed_work.preregister_a_distinct_xv2_successor -and
    [bool]$closure.next_allowed_work.factor_and_zero_world_execute_exact_post_worker_summary_projection -and
    [bool]$closure.next_allowed_work.require_new_clean_pushed_source_and_full_godot_attestation -and
    [bool]$closure.claims.complete_attempt_closure
) "$gateId immutability, successor, or closure authority changed"
foreach ($claimName in @($closure.claims.Keys | Where-Object {
    $_ -cne "complete_attempt_closure"
})) {
    Assert-Exact (-not [bool]$closure.claims[$claimName]) (
        "$gateId unsupported closure claim became true: $claimName"
    )
}

$rootsBefore = @(
    Get-ChildItem -LiteralPath (Split-Path -Parent $attemptRoot) -Directory `
        -Filter "c6-cross-engine-bw19v-xv1-*" `
        -ErrorAction SilentlyContinue |
        Sort-Object FullName |
        ForEach-Object { $_.FullName }
)
$rerunOutput = (& pwsh `
    -NoLogo `
    -NoProfile `
    -File $runnerPath `
    -RunPhysical `
    -FullConformanceAttestation "C6_XE_BW19V_XV1_CLOSED_CANARY_MUST_NOT_BE_READ" `
    2>&1 | Out-String)
Assert-Exact (
    $LASTEXITCODE -ne 0 -and
    $rerunOutput.Contains(
        "$gateId is closed and may not open another world; audit the closure instead"
    ) -and
    -not $rerunOutput.Contains("C6_XE_BW19V_XV1_CLOSED_CANARY_MUST_NOT_BE_READ")
) "$gateId real physical entrypoint did not refuse at closure"
$rootsAfter = @(
    Get-ChildItem -LiteralPath (Split-Path -Parent $attemptRoot) -Directory `
        -Filter "c6-cross-engine-bw19v-xv1-*" `
        -ErrorAction SilentlyContinue |
        Sort-Object FullName |
        ForEach-Object { $_.FullName }
)
Assert-Exact (
    ($rootsAfter -join "`n") -ceq ($rootsBefore -join "`n") -and
    (Get-EvidenceTreeDigest -Root $attemptRoot).tree_sha256 -ceq
        [string]$closure.consumed_attempt.evidence_tree.tree_sha256
) "$gateId closed-runner canary changed retained evidence"

Write-Host (
    "C6_XE_BW19V_XV1_CLOSURE_PASS status=implementation-invalid " +
    "declared_cells=6 launched=4 retained_reports=4 unopened=2 " +
    "individual_cold_passes=4 aggregate=False scientific_result=False " +
    "material_validation=False physical_authority=False rerun_refused=True"
)
