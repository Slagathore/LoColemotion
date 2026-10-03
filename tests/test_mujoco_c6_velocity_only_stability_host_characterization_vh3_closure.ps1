#requires -Version 7.0

[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

function Assert-Exact {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function Get-RawSha256 {
    param([Parameter(Mandatory)][string]$Path)
    (Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash.ToLowerInvariant()
}

function Get-TreeReceipt {
    param([Parameter(Mandatory)][string]$Root)
    $files = @(Get-ChildItem -LiteralPath $Root -File | Sort-Object Name)
    $text = foreach ($file in $files) {
        $file.Name + "`t" + $file.Length + "`t" +
            (Get-RawSha256 -Path $file.FullName) + "`n"
    }
    $bytes = [Text.Encoding]::UTF8.GetBytes(($text -join ""))
    [ordered]@{
        file_count = $files.Count
        total_bytes = [long](($files | Measure-Object Length -Sum).Sum)
        tree_sha256 = [Convert]::ToHexString(
            [Security.Cryptography.SHA256]::HashData($bytes)
        ).ToLowerInvariant()
    }
}

$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$sdkRoot = Join-Path $repoRoot "sdk"
$mujocoRoot = Join-Path $sdkRoot "adapters\mujoco"
$campaignId = "C6-MUJOCO-VELOCITY-ONLY-STABILITY-HOST-CHARACTERIZATION-VH3"
$gateId = "C6-MJC-HC-VH3"
$sourceCommit = "57e97f2f08636ef42b38511e11650e89b674dfaf"
$sourceTree = "d9b69587477446dc060d97dd82da65aca82b45f7"
$closurePath = Join-Path $sdkRoot (
    "mujoco_c6_velocity_only_stability_host_characterization_vh3_closure.json"
)
$runnerPath = Join-Path $sdkRoot (
    "run_mujoco_c6_velocity_only_stability_host_characterization_vh3.ps1"
)
$posthocPath = Join-Path $mujocoRoot (
    "sporespore_mujoco_adapter\velocity_only_stability_characterization_vh3_posthoc.py"
)
$python = Join-Path $mujocoRoot ".venv\Scripts\python.exe"
$evidenceRoot = (
    "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence\" +
    "c6-mujoco-velocity-only-stability-vh3-57e97f2"
)
$diagnosticPath = (
    "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence\" +
    "c6-mujoco-velocity-only-stability-vh3-posthoc-57e97f2\" +
    "temporal-measurement-diagnostic.json"
)
$attestationPath = (
    "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence\" +
    "full-godot-conformance-v2-57e97f2-20260803T030216Z\attestation.json"
)
$godotPath = (
    "C:\Users\Cole\CodeStuff\Misc\Godot\" +
    "Godot_v4.7-stable_mono_win64_console.exe"
)
$expectedEvidence = [ordered]@{
    "attempt.json" = @("4939", "41d8bb2326956f83894627ee5530bf7d515b9d46d51e0a6128d79f13894726d6")
    "completion.json" = @("1239", "189bb826d1c2a15a514263a82d4ebefaa48d67df1de84045191b69fb1df5ecb2")
    "preflight.json" = @("5055", "9c364e48e87b0fbdf31412a05786ba4590c0eb4ebce30249756605da2c54443e")
    "report.json" = @("11361222", "7710a3fd4b6ccc6836ab152f5827ce12a5d967d7a169b7597b5a521f38507b4f")
    "stderr.log" = @("0", "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855")
    "stdout.log" = @("5332424", "bebf4afcb3b5d818954163499202343a4fc6ef0869e2ec5c9e5bb5fc147427ff")
}

Assert-Exact (
    (git -C $repoRoot rev-parse --show-toplevel).Trim() -ceq
        $repoRoot.Replace("\", "/")
) "$gateId audit ran outside SporeSpore"
Assert-Exact (
    (git -C $repoRoot remote get-url origin).Trim() -ceq
        "https://github.com/Slagathore/sporespore.git"
) "$gateId origin mismatch"
Assert-Exact (
    (Get-RawSha256 -Path $closurePath) -ceq
        "06a85f029ba05e9fa45ee4499304e38bbb79c9c598dac60361390bc7d4b77217"
) "$gateId closure changed"
$closure = Get-Content -Raw -LiteralPath $closurePath |
    ConvertFrom-Json -AsHashtable -Depth 128
Assert-Exact (
    [string]$closure.schema_version -ceq
        "sporespore_mujoco_c6_velocity_only_stability_host_characterization_vh3_closure_v1" -and
    [string]$closure.campaign_id -ceq $campaignId -and
    [string]$closure.gate_id -ceq $gateId -and
    [string]$closure.status -ceq
        "closed_consumed_temporal_measurement_invalid_complete_report_no_scientific_result" -and
    [string]$closure.source.commit -ceq $sourceCommit -and
    [string]$closure.source.tree_git_oid -ceq $sourceTree -and
    [bool]$closure.source.worktree_clean_at_execution -and
    [bool]$closure.declared_study.all_cells_required -and
    -not [bool]$closure.declared_study.thresholds_changed_after_execution
) "$gateId closure boundary changed"

Assert-Exact (
    (git -C $repoRoot rev-parse "$sourceCommit^{tree}").Trim() -ceq $sourceTree
) "$gateId source tree changed"
& git -C $repoRoot merge-base --is-ancestor $sourceCommit HEAD
Assert-Exact ($LASTEXITCODE -eq 0) "$gateId source is not retained"
foreach ($binding in @(
    $closure.declared_study.preregistration,
    $closure.declared_study.implementation,
    $closure.declared_study.supervisor,
    $closure.declared_study.prospective_freeze_audit
)) {
    $path = Join-Path $repoRoot ([string]$binding.path)
    Assert-Exact (
        (Test-Path -LiteralPath $path -PathType Leaf) -and
        (Get-RawSha256 -Path $path) -ceq [string]$binding.raw_sha256
    ) "$gateId frozen source changed: $($binding.path)"
}

$historical = git -C $repoRoot show (
    $sourceCommit + ":sdk/adapters/mujoco/sporespore_mujoco_adapter/" +
    "velocity_only_stability_characterization_vh3.py"
)
Assert-Exact ($LASTEXITCODE -eq 0) "$gateId historical implementation missing"
$historicalText = $historical -join "`n"
$stepIndex = $historicalText.IndexOf("mujoco.mj_step(model, data)")
$copyIndex = $historicalText.IndexOf("observation.qvel[:] = data.qvel", $stepIndex)
$forwardIndex = $historicalText.IndexOf(
    "mujoco.mj_forward(model, observation)", $copyIndex
)
$forceIndex = $historicalText.IndexOf(
    "actuator_force = float(observation.actuator_force[actuator_id])",
    $forwardIndex
)
Assert-Exact (
    $stepIndex -ge 0 -and $copyIndex -gt $stepIndex -and
    $forwardIndex -gt $copyIndex -and $forceIndex -gt $forwardIndex
) "$gateId historical temporal defect changed"

Assert-Exact (
    (Get-RawSha256 -Path $attestationPath) -ceq
        "ffabcc0f9d3289528c83cafb8acf1f439416c377b410af051fd255e14752de0e"
) "$gateId full-Godot attestation changed"
. (Join-Path $sdkRoot "locomotion_operation_lock.ps1")
. (Join-Path $sdkRoot "locomotion_full_conformance_attestation.ps1")
$attestation = Get-Content -Raw -LiteralPath $attestationPath |
    ConvertFrom-Json -AsHashtable -Depth 64
$source = $attestation.source
$attestedBindings = @($attestation.source_bindings)
$validation = Test-SporeSporeFullConformanceAttestationDocument `
    -Document $attestation `
    -ExpectedSource $source `
    -ExpectedGodotIdentity $attestation.godot `
    -ExpectedPowerShellIdentity $attestation.powershell `
    -ExpectedSourceBindings $attestedBindings
Assert-Exact (
    [bool]$validation.ok -and @($validation.failure_codes).Count -eq 0 -and
    [string]$source.commit -ceq $sourceCommit -and
    [bool]$source.clean_pushed_live -and
    [bool]$attestation.conformance.godot_including -and
    -not [bool]$attestation.conformance.one_shot_physical_campaign_executed -and
    @($attestation.claims.Values | Where-Object { [bool]$_ }).Count -eq 0
) "$gateId full-Godot attestation no longer verifies"
foreach ($binding in $attestedBindings) {
    $blobSpec = $sourceCommit + ":" + [string]$binding.path
    Assert-Exact (
        (git -C $repoRoot rev-parse $blobSpec).Trim() -ceq
            [string]$binding.git_blob_oid
    ) "$gateId attested historical source binding changed: $($binding.path)"
}

Assert-Exact (
    Test-Path -LiteralPath $evidenceRoot -PathType Container
) "$gateId evidence root missing"
$names = @(
    Get-ChildItem -LiteralPath $evidenceRoot -File |
        Sort-Object Name | Select-Object -ExpandProperty Name
)
Assert-Exact (
    ($names -join "|") -ceq (($expectedEvidence.Keys | Sort-Object) -join "|")
) "$gateId evidence inventory changed"
foreach ($entry in $expectedEvidence.GetEnumerator()) {
    $path = Join-Path $evidenceRoot $entry.Key
    Assert-Exact (
        (Get-Item -LiteralPath $path).Length -eq [long]$entry.Value[0] -and
        (Get-RawSha256 -Path $path) -ceq [string]$entry.Value[1]
    ) "$gateId evidence changed: $($entry.Key)"
}
$tree = Get-TreeReceipt -Root $evidenceRoot
Assert-Exact (
    [int]$tree.file_count -eq 6 -and
    [long]$tree.total_bytes -eq 16704879 -and
    [string]$tree.tree_sha256 -ceq
        "61b30ea907da38c052ef4543ac102188ee7f78691e0386938b98bf1a35519e73"
) "$gateId evidence tree changed"

$attempt = Get-Content -Raw (Join-Path $evidenceRoot "attempt.json") |
    ConvertFrom-Json -AsHashtable -Depth 64
$completion = Get-Content -Raw (Join-Path $evidenceRoot "completion.json") |
    ConvertFrom-Json -AsHashtable -Depth 64
$preflight = Get-Content -Raw (Join-Path $evidenceRoot "preflight.json") |
    ConvertFrom-Json -AsHashtable -Depth 64
$reportPath = Join-Path $evidenceRoot "report.json"
$report = Get-Content -Raw $reportPath | ConvertFrom-Json -AsHashtable -Depth 64
Assert-Exact (
    [string]$attempt.attempt_id -ceq [string]$closure.physical_evidence.attempt_id -and
    [string]$attempt.campaign_id -ceq $campaignId -and
    [string]$attempt.source_commit -ceq $sourceCommit -and
    [bool]$attempt.physical_process_launch_consumes_identity -and
    [int]$attempt.replacement_processes_allowed -eq 0 -and
    [bool]$attempt.operation_lock.acquired -and
    [bool]$completion.process_launched -and
    [int]$completion.process_exit_code -eq 1 -and
    [bool]$completion.report_present -and
    [bool]$preflight.ok -and
    [int]$preflight.world_build_count -eq 0 -and
    [int]$preflight.negative_control_count -eq 18
) "$gateId attempt, completion, or preflight changed"

$expectedFailures = @(
    "C6_MJC_HC_VH3_CELL_GATE:unloaded_vn075_izero",
    "C6_MJC_HC_VH3_CELL_GATE:unloaded_vp075_izero",
    "C6_MJC_HC_VH3_TRACE_SATURATION:unloaded_vn075_izero",
    "C6_MJC_HC_VH3_TRACE_SATURATION:unloaded_vp075_izero"
)
$failedIds = @(
    $report.cells | Where-Object { -not [bool]$_.passed } |
        Select-Object -ExpandProperty cell_id
)
Assert-Exact (
    [string]$report.campaign_id -ceq $campaignId -and
    [string]$report.source.commit -ceq $sourceCommit -and
    -not [bool]$report.ok -and [int]$report.passed_cells -eq 22 -and
    [int]$report.failed_cells -eq 2 -and @($report.cells).Count -eq 24 -and
    @($report.mirrored_pairs).Count -eq 12 -and
    @($report.mirrored_pairs | Where-Object { -not [bool]$_.passed }).Count -eq 0 -and
    (@($report.failures) -join "|") -ceq ($expectedFailures -join "|") -and
    ($failedIds -join "|") -ceq "unloaded_vn075_izero|unloaded_vp075_izero"
) "$gateId retained reported result changed"
$integrity = $report.integrity
Assert-Exact (
    [int]$integrity.world_attempt_count -eq 24 -and
    [int]$integrity.world_build_count -eq 24 -and
    [int]$integrity.internal_trace_record_count -eq 43200 -and
    [int]$integrity.model_or_field_mismatch_count -eq 0 -and
    [int]$integrity.initial_velocity_readback_mismatch_count -eq 0 -and
    [int]$integrity.trace_cardinality_mismatch_count -eq 0 -and
    [int]$integrity.nonfinite_observation_count -eq 0 -and
    [int]$integrity.actuation_space_to_joint_space_force_mismatch_count -eq 0 -and
    [int]$integrity.applied_torque_readback_mismatch_count -eq 0 -and
    [int]$integrity.generalized_inertia_readback_mismatch_count -eq 0 -and
    [bool]$report.host.binding_surface.mjdata_has_M -and
    -not [bool]$report.host.binding_surface.mjdata_has_qM
) "$gateId retained non-temporal integrity changed"

Assert-Exact (
    (Get-Item -LiteralPath $posthocPath).Length -eq 11874 -and
    (Get-RawSha256 -Path $posthocPath) -ceq
        "b30b725e4f5b01d9a770fd6e899f4fad12b68a5d608ce731e496bcb44c315406" -and
    (Get-Item -LiteralPath $diagnosticPath).Length -eq 18123 -and
    (Get-RawSha256 -Path $diagnosticPath) -ceq
        "c5264b57c41e8606f520012acfbf9c1741a664fd60c3b59af31d39ec83da1706"
) "$gateId post-hoc source or artifact changed"
$diagnostic = Get-Content -Raw $diagnosticPath |
    ConvertFrom-Json -AsHashtable -Depth 128
$finding = $diagnostic.temporal_measurement_finding
$disposition = $diagnostic.technical_disposition
Assert-Exact (
    [string]$diagnostic.status -ceq
        "posthoc_temporal_measurement_invalid_no_scientific_result" -and
    [int]$diagnostic.frozen_result.internal_trace_record_count -eq 43200 -and
    [int]$finding.retained_post_state_saturation_count -eq 90 -and
    [int]$finding.reconstructed_pre_step_saturation_count -eq 114 -and
    [int]$finding.saturation_events_lost_by_post_state_sampling -eq 24 -and
    [bool]$finding.all_24_cells_reconstruct_at_least_one_saturated_step -and
    [bool]$finding.all_24_cells_lose_exactly_one_saturation_event -and
    [double]$finding.maximum_saturated_momentum_vs_cap_impulse_error_nms -le 4e-18 -and
    @($diagnostic.cell_diagnostics).Count -eq 24 -and
    @($diagnostic.cell_diagnostics | Where-Object {
        [int]$_.reconstructed_pre_step_saturation_count -lt 1 -or
        [int]$_.saturation_events_lost_by_post_state_sampling -ne 1
    }).Count -eq 0 -and
    @($diagnostic.failed_cell_forensics).Count -eq 2 -and
    -not [bool]$disposition.declared_saturation_measurement_valid -and
    -not [bool]$disposition.declared_internal_step_impulse_measurement_valid -and
    -not [bool]$disposition.scientific_positive -and
    -not [bool]$disposition.scientific_negative
) "$gateId temporal diagnosis changed"

$temporary = Join-Path ([IO.Path]::GetTempPath()) (
    "sporespore-vh3-posthoc-" + [guid]::NewGuid().ToString("N") + ".json"
)
try {
    & $python $posthocPath --report $reportPath --output $temporary *> $null
    Assert-Exact ($LASTEXITCODE -eq 0) "$gateId post-hoc replay failed"
    Assert-Exact (
        (Get-RawSha256 -Path $temporary) -ceq
            "c5264b57c41e8606f520012acfbf9c1741a664fd60c3b59af31d39ec83da1706"
    ) "$gateId post-hoc replay is not byte-exact"
}
finally {
    if (Test-Path -LiteralPath $temporary) {
        Remove-Item -LiteralPath $temporary -Force
    }
}

Assert-Exact (
    [bool]$closure.technical_disposition.campaign_identity_consumed -and
    [bool]$closure.technical_disposition.complete_twenty_four_cell_physical_report_exists -and
    -not [bool]$closure.technical_disposition.declared_during_step_force_measurement_valid -and
    -not [bool]$closure.technical_disposition.twenty_four_cell_acceptance_gate_validly_evaluated -and
    -not [bool]$closure.technical_disposition.scientific_positive -and
    -not [bool]$closure.technical_disposition.scientific_negative -and
    [string]$closure.scientific_disposition.classification -ceq
        "no_scientific_result_temporal_instrumentation_invalid" -and
    [bool]$closure.scientific_disposition.optimization_is_allowed -and
    [bool]$closure.immutability.same_identity_rerun_forbidden -and
    [bool]$closure.immutability.retroactive_rescore_or_promotion_forbidden -and
    -not [bool]$closure.claims.exact_finite_vh3_host_characterization_positive -and
    -not [bool]$closure.claims.exact_finite_vh3_host_characterization_negative -and
    -not [bool]$closure.claims.mujoco_walking
) "$gateId scientific disposition changed"

$before = @(
    Get-ChildItem -LiteralPath (Split-Path -Parent $evidenceRoot) -Directory `
        -Filter "c6-mujoco-velocity-only-stability-vh3-57e97f2"
)
$rerun = @(
    & pwsh -NoLogo -NoProfile -File $runnerPath `
        -RunPhysical `
        -FullConformanceAttestation "C6_MJC_HC_VH3_CLOSED_CANARY" 2>&1
)
Assert-Exact (
    $LASTEXITCODE -ne 0 -and
    ($rerun -join "`n").Contains(
        "$gateId is closed and may not open another world; audit the closure instead"
    ) -and
    -not ($rerun -join "`n").Contains("C6_MJC_HC_VH3_CLOSED_CANARY")
) "$gateId runner did not refuse before mutable inputs"
$after = @(
    Get-ChildItem -LiteralPath (Split-Path -Parent $evidenceRoot) -Directory `
        -Filter "c6-mujoco-velocity-only-stability-vh3-57e97f2"
)
Assert-Exact ($after.Count -eq $before.Count) "$gateId audit changed evidence"

Write-Host (
    "C6_MJC_HC_VH3_CLOSURE_PASS status=temporal-measurement-invalid " +
    "worlds=24 reported_passed=22 reported_failed=2 retained_saturation=90 " +
    "reconstructed_saturation=114 lost_events=24 integrity_otherwise=True " +
    "scientific_positive=False scientific_negative=False walking=False " +
    "physical_authority=False rerun_refused=True"
)
