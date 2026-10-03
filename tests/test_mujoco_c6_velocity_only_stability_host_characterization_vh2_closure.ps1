#requires -Version 7.0

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$sdkRoot = Join-Path $repoRoot "sdk"
$mujocoRoot = Join-Path $sdkRoot "adapters\mujoco"
$campaignId = "C6-MUJOCO-VELOCITY-ONLY-STABILITY-HOST-CHARACTERIZATION-VH2"
$gateId = "C6-MJC-HC-VH2"
$sourceCommit = "d6c38c5f11e389fe0f2f1356f2eb1918403e46e6"
$closurePath = Join-Path (
    $sdkRoot
) "mujoco_c6_velocity_only_stability_host_characterization_vh2_closure.json"
$runnerPath = Join-Path (
    $sdkRoot
) "run_mujoco_c6_velocity_only_stability_host_characterization_vh2.ps1"
$python = Join-Path $mujocoRoot ".venv\Scripts\python.exe"
$expectedClosureSha256 =
    "ac0207f33a66c06e13e24b4f4149922c3bd25aa2db11229ab2184f32801ccc7c"

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

function Assert-AbsoluteArtifact {
    param(
        [Parameter(Mandatory)][System.Collections.IDictionary]$Artifact,
        [Parameter(Mandatory)][string]$Label
    )
    $path = [IO.Path]::GetFullPath([string]$Artifact.path)
    Assert-Exact (
        (Test-Path -LiteralPath $path -PathType Leaf) -and
        (Get-Item -LiteralPath $path).Length -eq
            [long]$Artifact.size_bytes -and
        (Get-RawSha256 -Path $path) -ceq
            ([string]$Artifact.raw_sha256).Replace("sha256:", "")
    ) "$gateId retained $Label is missing or changed"
}

function Test-BoundHistoricalSource {
    param([Parameter(Mandatory)][System.Collections.IDictionary]$Binding)
    $bytes = Get-SporeGitBlobBytes `
        -RepositoryRoot $repoRoot `
        -Commit $sourceCommit `
        -Path ([string]$Binding.path)
    $expectedHash = ([string]$Binding.raw_sha256).Replace(
        "sha256:", ""
    ).ToLowerInvariant()
    if (
        $bytes.Length -eq [long]$Binding.size_bytes -and
        (Get-SporeByteSha256 -Bytes $bytes) -ceq $expectedHash
    ) {
        return $true
    }
    $crlf = Convert-SporeLfBlobToCrlfBytes -Bytes $bytes
    return (
        $crlf.Length -eq [long]$Binding.size_bytes -and
        (Get-SporeByteSha256 -Bytes $crlf) -ceq $expectedHash
    )
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

Assert-Exact (
    (Test-Path -LiteralPath $closurePath -PathType Leaf) -and
    (Get-RawSha256 -Path $closurePath) -ceq $expectedClosureSha256
) "$gateId closure manifest is missing or changed"
$closure = Get-Content -Raw -LiteralPath $closurePath |
    ConvertFrom-Json -AsHashtable -Depth 128

Assert-Exact (
    [string]$closure.schema_version -ceq
        "sporespore_mujoco_c6_velocity_only_stability_host_characterization_vh2_closure_v1" -and
    [string]$closure.status -ceq
        "closed_consumed_implementation_invalid_no_physical_report" -and
    [string]$closure.campaign_id -ceq $campaignId -and
    [string]$closure.gate_id -ceq $gateId -and
    [string]$closure.experiment_source_commit -ceq $sourceCommit -and
    [string]$closure.experiment_source_tree_git_oid -ceq
        "3c1478d537b5551be7edff392c0b31e38ecd5721" -and
    [bool]$closure.source_was_clean_and_equal_to_origin_main_and_live_github_main -and
    [int]$closure.declared_study.declared_world_count -eq 24 -and
    [int]$closure.declared_study.declared_internal_trace_record_count -eq 43200 -and
    [int]$closure.declared_study.declared_mirrored_pair_count -eq 12 -and
    [int]$closure.declared_study.declared_negative_control_count -eq 18 -and
    [int]$closure.declared_study.replacement_process_count -eq 0
) "$gateId closure identity or declared study changed"

& git -C $repoRoot cat-file -e "$sourceCommit`^{commit}"
Assert-Exact ($LASTEXITCODE -eq 0) "$gateId source commit is not retained"
Assert-Exact (
    (& git -C $repoRoot rev-parse "$sourceCommit`^{tree}").Trim() -ceq
        [string]$closure.experiment_source_tree_git_oid
) "$gateId experiment source tree changed"
& git -C $repoRoot merge-base --is-ancestor $sourceCommit HEAD
Assert-Exact ($LASTEXITCODE -eq 0) "$gateId source commit is not an ancestor"
$originMain = (& git -C $repoRoot rev-parse origin/main).Trim()
Assert-Exact ($LASTEXITCODE -eq 0) "$gateId origin/main could not be resolved"
& git -C $repoRoot merge-base --is-ancestor $sourceCommit $originMain
Assert-Exact ($LASTEXITCODE -eq 0) "$gateId source commit is not on origin/main"

foreach ($binding in $closure.bound_source_inventory.GetEnumerator()) {
    Assert-Exact (
        Test-BoundHistoricalSource -Binding $binding.Value
    ) "$gateId frozen source binding changed: $($binding.Key)"
}
$historicalImplementation = [Text.Encoding]::UTF8.GetString(
    (Get-SporeGitBlobBytes `
        -RepositoryRoot $repoRoot `
        -Commit $sourceCommit `
        -Path ([string]$closure.bound_source_inventory.implementation.path))
)
Assert-Exact (
    ([regex]::Matches($historicalImplementation, "\.qM")).Count -eq 3 -and
    $historicalImplementation.Contains("len(data.qM) == 1") -and
    $historicalImplementation.Contains("float(observation.qM[0])")
) "$gateId historical implementation no longer reproduces the qM defect"

Assert-AbsoluteArtifact `
    -Artifact $closure.full_godot_v2_attestation `
    -Label "full-Godot V2 attestation"
$attestation = Get-Content -Raw -LiteralPath (
    [string]$closure.full_godot_v2_attestation.path
) | ConvertFrom-Json -AsHashtable -Depth 128
Assert-Exact (
    [string]$attestation.schema_version -ceq
        "sporespore_full_godot_conformance_attestation_v2" -and
    [string]$attestation.source.commit -ceq $sourceCommit -and
    [bool]$attestation.source.clean_pushed_live -and
    [bool]$attestation.conformance.passed -and
    [bool]$attestation.conformance.godot_including -and
    -not [bool]$attestation.conformance.skip_godot -and
    -not [bool]$attestation.conformance.one_shot_physical_campaign_executed -and
    @($attestation.claims.Values | Where-Object { [bool]$_ }).Count -eq 0
) "$gateId full-Godot V2 attestation boundary changed"

$attemptSection = $closure.consumed_attempt
$evidenceRoot = [IO.Path]::GetFullPath([string]$attemptSection.evidence_root)
Assert-Exact (
    $evidenceRoot -ceq
        "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence\" +
        "c6-mujoco-velocity-only-stability-vh2-d6c38c5" -and
    (Test-Path -LiteralPath $evidenceRoot -PathType Container)
) "$gateId retained evidence root is missing"
foreach ($name in @(
    "attempt", "preflight", "stdout", "stderr", "completion", "posthoc_diagnostic"
)) {
    Assert-AbsoluteArtifact `
        -Artifact $attemptSection[$name] `
        -Label $name
}
Assert-Exact (
    -not [bool]$attemptSection.report_present -and
    -not (Test-Path -LiteralPath ([string]$attemptSection.report_path))
) "$gateId absent report declaration changed"
$tree = Get-EvidenceTreeDigest -Root $evidenceRoot
Assert-Exact (
    [int]$tree.file_count -eq [int]$attemptSection.evidence_tree.file_count -and
    [long]$tree.total_byte_length -eq
        [long]$attemptSection.evidence_tree.total_byte_length -and
    [string]$tree.tree_sha256 -ceq
        [string]$attemptSection.evidence_tree.tree_sha256
) "$gateId retained evidence tree changed"

$attempt = Get-Content -Raw -LiteralPath ([string]$attemptSection.attempt.path) |
    ConvertFrom-Json -AsHashtable -Depth 128
$completion = Get-Content -Raw -LiteralPath (
    [string]$attemptSection.completion.path
) | ConvertFrom-Json -AsHashtable -Depth 128
$preflight = Get-Content -Raw -LiteralPath (
    [string]$attemptSection.preflight.path
) | ConvertFrom-Json -AsHashtable -Depth 128
$stderr = Get-Content -Raw -LiteralPath ([string]$attemptSection.stderr.path)
$diagnostic = Get-Content -Raw -LiteralPath (
    [string]$attemptSection.posthoc_diagnostic.path
) | ConvertFrom-Json -AsHashtable -Depth 128

Assert-Exact (
    [string]$attempt.attempt_id -ceq [string]$attemptSection.attempt_id -and
    [string]$attempt.campaign_id -ceq $campaignId -and
    [string]$attempt.gate_id -ceq $gateId -and
    [string]$attempt.source_commit -ceq $sourceCommit -and
    [bool]$attempt.physical_process_launch_consumes_identity -and
    [int]$attempt.replacement_processes_allowed -eq 0 -and
    [bool]$attempt.operation_lock.acquired -and
    [string]$attempt.operation_lock.role -ceq "physical" -and
    -not [bool]$attempt.operation_lock.test_only -and
    [int]$attempt.exact_host_identity.world_build_count -eq 0 -and
    -not [bool]$attempt.exact_host_identity.physics_state_modified
) "$gateId attempt reservation or pre-launch host receipt changed"
Assert-Exact (
    [string]$completion.attempt_id -ceq [string]$attempt.attempt_id -and
    [bool]$completion.process_launched -and
    [int]$completion.process_exit_code -eq 1 -and
    $null -eq $completion.launch_error -and
    -not [bool]$completion.report_present -and
    $null -eq $completion.report_raw_sha256 -and
    [string]$completion.stderr_raw_sha256 -ceq
        [string]$attemptSection.stderr.raw_sha256 -and
    [string]$completion.stdout_raw_sha256 -ceq
        [string]$attemptSection.stdout.raw_sha256
) "$gateId implementation-invalid completion receipt changed"
Assert-Exact (
    [bool]$preflight.ok -and
    [bool]$preflight.perfect_synthetic_result_passed -and
    [bool]$preflight.perfect_synthetic_serialization_round_trip_passed -and
    [int]$preflight.declared_cell_count -eq 24 -and
    [int]$preflight.declared_internal_trace_record_count -eq 43200 -and
    [int]$preflight.negative_control_count -eq 18 -and
    @($preflight.negative_controls_rejected.Values | Where-Object {
        -not [bool]$_
    }).Count -eq 0 -and
    [int]$preflight.world_build_count -eq 0 -and
    -not [bool]$preflight.physics_state_modified -and
    -not [bool]$preflight.physical_acceptance_authority
) "$gateId retained zero-world preflight changed"
Assert-Exact (
    $stderr.Contains("AttributeError: 'mujoco._structs.MjData' object has no attribute 'qM'. Did you mean: 'M'?") -and
    $stderr.Contains("int(model.nv) == 1 and len(data.qM) == 1")
) "$gateId retained binding exception changed"

Assert-Exact (
    [string]$diagnostic.schema_version -ceq
        "sporespore_mujoco_c6_velocity_only_stability_host_characterization_vh2_posthoc_diagnostic_v1" -and
    [string]$diagnostic.status -ceq
        "posthoc_implementation_failure_diagnostic_no_scientific_result" -and
    [string]$diagnostic.campaign_id -ceq $campaignId -and
    [string]$diagnostic.experiment_source_commit -ceq $sourceCommit -and
    -not [bool]$diagnostic.installed_binding_observation.observation_constructed_mjmodel -and
    -not [bool]$diagnostic.installed_binding_observation.observation_modified_physics_state -and
    [bool]$diagnostic.installed_binding_observation.mujoco_mjdata_type_has_M -and
    -not [bool]$diagnostic.installed_binding_observation.mujoco_mjdata_type_has_qM -and
    [int]$diagnostic.exact_source_control_flow_inference.mjmodel_construction_count_before_exception -eq 1 -and
    [int]$diagnostic.exact_source_control_flow_inference.mjdata_construction_count_before_exception -eq 2 -and
    [int]$diagnostic.exact_source_control_flow_inference.mj_forward_call_count_before_exception -eq 1 -and
    [int]$diagnostic.exact_source_control_flow_inference.mj_step_call_count_before_exception -eq 0 -and
    [int]$diagnostic.exact_source_control_flow_inference.completed_cell_count_before_exception -eq 0 -and
    -not [bool]$diagnostic.technical_disposition.valid_complete_physical_report -and
    -not [bool]$diagnostic.technical_disposition.scientific_positive -and
    -not [bool]$diagnostic.technical_disposition.scientific_negative
) "$gateId retained posthoc diagnostic changed or inflated"

# Reproduce the exact installed API mismatch without constructing MjModel.
$bindingScript = @'
import json
import mujoco
names = set(dir(mujoco.MjData))
print(json.dumps({
    "version": mujoco.__version__,
    "has_M": "M" in names,
    "has_qM": "qM" in names,
    "mj_fullM_doc": " ".join((mujoco.mj_fullM.__doc__ or "").split()),
}))
'@
$binding = (& $python -c $bindingScript) |
    ConvertFrom-Json -AsHashtable -Depth 16
Assert-Exact (
    [string]$binding.version -ceq "3.11.0" -and
    [bool]$binding.has_M -and
    -not [bool]$binding.has_qM -and
    ([string]$binding.mj_fullM_doc).StartsWith(
        "mj_fullM(m: mujoco._structs.MjModel, d: mujoco._structs.MjData, dst:"
    )
) "$gateId pinned MuJoCo binding surface no longer reproduces the defect"

Assert-Exact (
    [bool]$closure.technical_disposition.campaign_identity_consumed -and
    -not [bool]$closure.technical_disposition.valid_complete_physical_report -and
    -not [bool]$closure.technical_disposition.twenty_four_cell_gate_evaluated -and
    -not [bool]$closure.technical_disposition.physical_measurement_result_available -and
    -not [bool]$closure.technical_disposition.scientific_positive -and
    -not [bool]$closure.technical_disposition.scientific_negative -and
    [string]$closure.scientific_disposition.classification -ceq
        "no_scientific_result_implementation_invalid" -and
    [bool]$closure.scientific_disposition.optimization_is_allowed -and
    [bool]$closure.immutability.same_identity_rerun_forbidden -and
    [bool]$closure.immutability.replacement_process_forbidden -and
    [bool]$closure.immutability.implementation_rewrite_forbidden -and
    [bool]$closure.immutability.successor_requires_new_identity -and
    [bool]$closure.next_allowed_work.preregister_a_distinct_mujoco_velocity_only_host_successor -and
    [bool]$closure.next_allowed_work.add_zero_world_installed_binding_attribute_and_call_shape_canaries -and
    [bool]$closure.next_allowed_work.require_a_new_exact_source_full_godot_attestation
) "$gateId technical, scientific, immutability, or successor boundary changed"
foreach ($claim in $closure.claims.Keys) {
    Assert-Exact (
        -not [bool]$closure.claims[$claim]
    ) "$gateId unsupported closure claim became true: $claim"
}

$rootsBefore = @(
    Get-ChildItem -LiteralPath (Split-Path -Parent $evidenceRoot) -Directory `
        -Filter "c6-mujoco-velocity-only-stability-vh2-*" `
        -ErrorAction SilentlyContinue |
        Sort-Object FullName |
        ForEach-Object { $_.FullName }
)
$rerunOutput = (& pwsh `
    -NoLogo `
    -NoProfile `
    -File $runnerPath `
    -RunPhysical `
    -FullConformanceAttestation "C6_MJC_HC_VH2_CLOSED_CANARY_MUST_NOT_BE_READ" `
    2>&1 | Out-String)
Assert-Exact (
    $LASTEXITCODE -ne 0 -and
    $rerunOutput.Contains(
        "$gateId is closed and may not open another world; audit the closure instead"
    ) -and
    -not $rerunOutput.Contains("C6_MJC_HC_VH2_CLOSED_CANARY_MUST_NOT_BE_READ")
) "$gateId real physical entrypoint did not refuse at closure"
$rootsAfter = @(
    Get-ChildItem -LiteralPath (Split-Path -Parent $evidenceRoot) -Directory `
        -Filter "c6-mujoco-velocity-only-stability-vh2-*" `
        -ErrorAction SilentlyContinue |
        Sort-Object FullName |
        ForEach-Object { $_.FullName }
)
Assert-Exact (
    ($rootsAfter -join "`n") -ceq ($rootsBefore -join "`n") -and
    (Get-EvidenceTreeDigest -Root $evidenceRoot).tree_sha256 -ceq
        [string]$attemptSection.evidence_tree.tree_sha256
) "$gateId closed-runner canary changed retained evidence"

Write-Host (
    "C6_MJC_HC_VH2_CLOSURE_PASS status=implementation-invalid " +
    "models_inferred=1 steps_inferred=0 cells=0 report=False " +
    "binding_M=True binding_qM=False scientific_result=False " +
    "walking=False physical_authority=False rerun_refused=True"
)
