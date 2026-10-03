#requires -Version 7.0

[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$evidenceRoot = "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence"
$artifactRoot = Join-Path $evidenceRoot "artifacts\sha256"
$attemptRoot = Join-Path $evidenceRoot (
    "qsdk-r23d63-physical-20260825T085510Z-649277e3"
)
$closurePath = Join-Path $repoRoot (
    "sdk\turning\r23d63_selected_profile_three_engine_turning_validation_closure_v1.json"
)
$sourceCommit = "649277e3abc8cfd481cfc6cd22719f32ebc9a332"
$sourceTree = "0e6aed54cb392354b87b5269e0a49055f767af9b"
$attemptId = "a48bcdec043e453497d1097754d47630"
$campaignId = (
    "QSDK-R23D63-RECEIPT-SCHEMA-REPAIRED-SELECTED-PROFILE-" +
    "MATCHED-THREE-ENGINE-TURNING-VALIDATION"
)
$closedStatus = (
    "closed_consumed_invalid_incomplete_before_first_world_" +
    "rapier_cli_argument_contract_failure"
)
$expectedCells = @(
    "godot_jolt__s23169__selected_profile__reference_zero",
    "godot_jolt__s23169__selected_profile__positive_heading",
    "godot_jolt__s23169__selected_profile__negative_heading",
    "rapier_parry__s23169__selected_profile__reference_zero",
    "rapier_parry__s23169__selected_profile__positive_heading",
    "rapier_parry__s23169__selected_profile__negative_heading",
    "mujoco__s23169__selected_profile__reference_zero",
    "mujoco__s23169__selected_profile__positive_heading",
    "mujoco__s23169__selected_profile__negative_heading"
)

function Assert-R23D63Closure([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "QSDK-R23D63 CLOSURE: $Message" }
}

function Get-R23D63Sha256([string]$Path) {
    return "sha256:" + (
        Get-FileHash -LiteralPath $Path -Algorithm SHA256
    ).Hash.ToLowerInvariant()
}

function Get-R23D63GitBlobBytes([string]$Commit, [string]$RelativePath) {
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
    Assert-R23D63Closure ($process.Start()) "could not start git cat-file"
    $memory = [IO.MemoryStream]::new()
    try {
        $process.StandardOutput.BaseStream.CopyTo($memory)
        $stderr = $process.StandardError.ReadToEnd()
        $process.WaitForExit()
        Assert-R23D63Closure ($process.ExitCode -eq 0) (
            "historical blob unavailable: $RelativePath; $stderr"
        )
        return ,([byte[]]$memory.ToArray())
    } finally {
        $memory.Dispose()
        $process.Dispose()
    }
}

function Get-R23D63BytesSha256([byte[]]$Bytes) {
    return "sha256:" + [Convert]::ToHexString(
        [Security.Cryptography.SHA256]::HashData($Bytes)
    ).ToLowerInvariant()
}

function Assert-R23D63Cas([string]$Sha256, [long]$ByteLength) {
    Assert-R23D63Closure ($Sha256 -cmatch '^sha256:[0-9a-f]{64}$') (
        "invalid CAS digest: $Sha256"
    )
    $directory = Join-Path $artifactRoot $Sha256.Substring(7)
    $payload = Join-Path $directory "payload.bin"
    $manifestPath = Join-Path $directory "manifest.json"
    Assert-R23D63Closure (
        (Test-Path -LiteralPath $payload -PathType Leaf) -and
        (Test-Path -LiteralPath $manifestPath -PathType Leaf) -and
        (Get-Item -LiteralPath $payload).Length -eq $ByteLength -and
        (Get-R23D63Sha256 $payload) -ceq $Sha256
    ) "CAS payload changed: $Sha256"
    $manifest = Get-Content -LiteralPath $manifestPath -Raw |
        ConvertFrom-Json -Depth 20
    Assert-R23D63Closure (
        [string]$manifest.schema_version -ceq
            "sporespore_content_addressed_artifact_manifest_v1" -and
        [string]$manifest.algorithm -ceq "sha256" -and
        [string]$manifest.sha256 -ceq $Sha256 -and
        [long]$manifest.byte_length -eq $ByteLength -and
        [string]$manifest.payload_name -ceq "payload.bin"
    ) "CAS manifest changed: $Sha256"
}

function Assert-R23D63RetainedFile($File) {
    $relative = ([string]$File.relative_path).Replace('/', [IO.Path]::DirectorySeparatorChar)
    $path = Join-Path $attemptRoot $relative
    Assert-R23D63Closure (
        (Test-Path -LiteralPath $path -PathType Leaf) -and
        (Get-Item -LiteralPath $path).Length -eq [long]$File.byte_length -and
        (Get-R23D63Sha256 $path) -ceq [string]$File.raw_sha256
    ) "retained file changed: $relative"
    Assert-R23D63Cas ([string]$File.raw_sha256) ([long]$File.byte_length)
}

function Test-R23D63ClosureVector($Value) {
    return (
        [string]$Value.status -ceq $closedStatus -and
        [string]$Value.campaign_id -ceq $campaignId -and
        [string]$Value.source_commit -ceq $sourceCommit -and
        [string]$Value.source_tree_git_oid -ceq $sourceTree -and
        [string]$Value.attempt_id -ceq $attemptId -and
        [int]$Value.campaign_seed -eq 23169 -and
        [bool]$Value.campaign_identity_consumed -and
        -not [bool]$Value.same_identity_rerun_allowed -and
        -not [bool]$Value.replacement_or_selective_rerun_allowed -and
        -not [bool]$Value.physical_outcome_exposed -and
        [bool]$Value.qualification.qualification_passed -and
        [bool]$Value.qualification.adoption_passed -and
        [int]$Value.qualification.executed_gate_count -eq 23 -and
        [int]$Value.declaration_and_zero_world_provenance.transitive_path_count -eq 228 -and
        [int]$Value.declaration_and_zero_world_provenance.transitive_edge_count -eq 228 -and
        [int]$Value.physical_evidence.complete_retained_file_population_count -eq 11 -and
        [int]$Value.physical_evidence.authorization_preflight_process_count -eq 4 -and
        [int]$Value.physical_evidence.authorization_preflight_receipt_count -eq 3 -and
        [int]$Value.physical_evidence.physical_cell_process_count -eq 0 -and
        [int]$Value.physical_evidence.world_build_count -eq 0 -and
        [string]$Value.failure_mechanism.failure_class -ceq
            "supervisor_to_rapier_production_worker_cli_argument_contract_mismatch" -and
        [string]$Value.failure_mechanism.process_stderr -ceq
            "unknown or duplicate argument: --campaign-seed`n" -and
        [bool]$Value.failure_mechanism.failure_occurred_before_first_world -and
        [int]$Value.launcher_argument_conformance.supervisor_rapier_production_call_site_count -eq 2 -and
        [int]$Value.launcher_argument_conformance.supervisor_conforming_call_site_count -eq 0 -and
        [int]$Value.launcher_argument_conformance.supervisor_nonconforming_call_site_count -eq 2 -and
        [double]$Value.launcher_argument_conformance.equivalence_margin -eq 0.0 -and
        [double]$Value.launcher_argument_conformance.non_inferiority_margin -eq 0.0 -and
        -not [bool]$Value.launcher_argument_conformance.exact_conformance_passed -and
        -not [bool]$Value.official_result.physical_result_exists -and
        -not [bool]$Value.official_result.finite_three_engine_turning -and
        -not [bool]$Value.official_result.q_sdk_r23_satisfied -and
        -not [bool]$Value.claims.prone_to_standing -and
        -not [bool]$Value.claims.release_authorized
    )
}

Assert-R23D63Closure (Test-Path -LiteralPath $closurePath -PathType Leaf) (
    "closure missing"
)
$closure = Get-Content -LiteralPath $closurePath -Raw |
    ConvertFrom-Json -Depth 100
Assert-R23D63Closure (Test-R23D63ClosureVector $closure) "closure vector changed"

$actualRelative = @(
    Get-ChildItem -LiteralPath $attemptRoot -Recurse -File |
        ForEach-Object {
            $_.FullName.Substring($attemptRoot.Length + 1).Replace('\', '/')
        } | Sort-Object
)
$declaredRelative = @(
    $closure.physical_evidence.files |
        ForEach-Object { [string]$_.relative_path } | Sort-Object
)
Assert-R23D63Closure (
    $actualRelative.Count -eq 11 -and
    ($actualRelative -join "`n") -ceq ($declaredRelative -join "`n")
) "retained file population changed"
foreach ($file in @($closure.physical_evidence.files)) {
    Assert-R23D63RetainedFile $file
}
$uniqueDigests = @(
    $closure.physical_evidence.files.raw_sha256 | Sort-Object -Unique
)
Assert-R23D63Closure ($uniqueDigests.Count -eq 8) "unique digest count changed"

foreach ($qualificationArtifact in @(
    $closure.qualification.attestation,
    $closure.qualification.adoption
)) {
    Assert-R23D63Closure (
        (Test-Path -LiteralPath $qualificationArtifact.path -PathType Leaf) -and
        (Get-Item -LiteralPath $qualificationArtifact.path).Length -eq
            [long]$qualificationArtifact.byte_length -and
        (Get-R23D63Sha256 $qualificationArtifact.path) -ceq
            [string]$qualificationArtifact.raw_sha256
    ) "qualification artifact changed: $($qualificationArtifact.path)"
    Assert-R23D63Cas (
        [string]$qualificationArtifact.raw_sha256
    ) ([long]$qualificationArtifact.byte_length)
}

$freeze = Get-Content -LiteralPath (Join-Path $attemptRoot "physical-freeze.json") -Raw |
    ConvertFrom-Json -Depth 100
$attempt = Get-Content -LiteralPath (Join-Path $attemptRoot "attempt-authorization.json") -Raw |
    ConvertFrom-Json -Depth 100
$completion = Get-Content -LiteralPath (Join-Path $attemptRoot "completion.json") -Raw |
    ConvertFrom-Json -Depth 20
Assert-R23D63Closure (
    [string]$freeze.schema_version -ceq "sporespore_qsdk_r23d63_physical_freeze_v1" -and
    [string]$freeze.source_commit -ceq $sourceCommit -and
    [string]$freeze.source_tree_git_oid -ceq $sourceTree -and
    [bool]$freeze.complete_zero_world_gate_passed -and
    [int]$freeze.zero_world_receipt.campaign_gate_count -eq 13 -and
    [int]$freeze.zero_world_receipt.worker_preflight_count -eq 9 -and
    [int]$freeze.zero_world_receipt.model_construction_count -eq 0 -and
    [int]$freeze.zero_world_receipt.world_build_count -eq 0 -and
    [int]$freeze.authorization_receipt_schema_conformance.conforming_producer_count -eq 3 -and
    [int]$freeze.authorization_receipt_schema_conformance.negative_controls_passed -eq 12 -and
    [bool]$freeze.physical_execution_authorized
) "physical freeze changed"
Assert-R23D63Closure (
    [string]$attempt.schema_version -ceq "sporespore_qsdk_r23d63_attempt_v1" -and
    [string]$attempt.attempt_id -ceq $attemptId -and
    [string]$attempt.source_commit -ceq $sourceCommit -and
    [string]$attempt.freeze_raw_sha256 -ceq
        [string]$closure.physical_evidence.files[0].raw_sha256 -and
    ($attempt.ordered_matrix_cell_ids -join "`n") -ceq ($expectedCells -join "`n") -and
    [bool]$attempt.physical_execution_authorized -and
    [bool]$attempt.all_cells_run_regardless_of_intermediate_outcome
) "attempt authorization changed"
Assert-R23D63Closure (
    [string]$completion.status -ceq "invalid_or_incomplete_first_attempt" -and
    [string]$completion.source_commit -ceq $sourceCommit -and
    [bool]$completion.one_shot_attempt_consumed -and
    -not [bool]$completion.replacement_or_selective_rerun_permitted -and
    [string]$completion.failure_message -ceq
        "QSDK-R23D63: strict physical authorization preflight process invalid: rapier_parry__s23169__selected_profile__reference_zero" -and
    -not [bool]$completion.physical_acceptance_authority
) "completion changed"

$godotArms = @("reference_zero", "positive_heading", "negative_heading")
foreach ($armId in $godotArms) {
    $cellId = "godot_jolt__s23169__selected_profile__$armId"
    $stdoutPath = Join-Path $attemptRoot "authorization-preflight\$cellId\stdout.txt"
    $line = @(
        Get-Content -LiteralPath $stdoutPath |
            Where-Object { $_.StartsWith("QSDK_R23D63_GODOT_JOLT_AUTHORIZATION_PREFLIGHT ") }
    )
    Assert-R23D63Closure ($line.Count -eq 1) "Godot receipt count changed: $armId"
    $receipt = $line[0].Substring(
        "QSDK_R23D63_GODOT_JOLT_AUTHORIZATION_PREFLIGHT ".Length
    ) | ConvertFrom-Json -Depth 20
    Assert-R23D63Closure (
        [string]$receipt.cell_id -ceq $cellId -and
        [bool]$receipt.authorization_passed -and
        [bool]$receipt.complete_ordered_nine_cell_matrix_validated -and
        [bool]$receipt.returned_before_model -and
        [int]$receipt.model_construction_count -eq 0 -and
        [int]$receipt.world_build_count -eq 0
    ) "Godot authorization receipt changed: $armId"
}
$rapierStderr = Get-Content -LiteralPath (
    Join-Path $attemptRoot (
        "authorization-preflight\rapier_parry__s23169__selected_profile__" +
        "reference_zero\stderr.txt"
    )
) -Raw
Assert-R23D63Closure (
    $rapierStderr -ceq "unknown or duplicate argument: --campaign-seed`n"
) "Rapier process rejection changed"
Assert-R23D63Closure (
    -not (Test-Path -LiteralPath (Join-Path $attemptRoot "cells")) -and
    -not (Test-Path -LiteralPath (Join-Path $attemptRoot "authorization-preflight.json")) -and
    -not (Test-Path -LiteralPath (Join-Path $attemptRoot "campaign-report.json"))
) "post-failure physical output unexpectedly exists"

foreach ($binding in @($closure.source_bindings)) {
    $bytes = Get-R23D63GitBlobBytes $sourceCommit ([string]$binding.path)
    Assert-R23D63Closure (
        $bytes.Length -eq [long]$binding.byte_length -and
        (Get-R23D63BytesSha256 $bytes) -ceq [string]$binding.raw_sha256
    ) "source binding changed: $($binding.path)"
}
$supervisorText = [Text.Encoding]::UTF8.GetString((
    Get-R23D63GitBlobBytes $sourceCommit "sdk/run_qsdk_r23d63_supervisor.ps1"
))
$binaryText = [Text.Encoding]::UTF8.GetString((
    Get-R23D63GitBlobBytes $sourceCommit "sdk/adapters/rapier/src/bin/qsdk_r23d63_physical.rs"
))
$workerGateText = [Text.Encoding]::UTF8.GetString((
    Get-R23D63GitBlobBytes $sourceCommit "tests/test_qsdk_r23d63_rapier_physical_worker.ps1"
))
$campaignSeedOccurrences = [regex]::Matches(
    $supervisorText,
    [regex]::Escape('"--campaign-seed", [string]$campaignSeed')
).Count
Assert-R23D63Closure ($campaignSeedOccurrences -eq 4) (
    "complete supervisor seed-alias population changed"
)
Assert-R23D63Closure (
    $supervisorText.Contains('} elseif ($EngineId -ceq "rapier_parry") {') -and
    $supervisorText.Contains('} elseif ($engineId -ceq "rapier_parry") {') -and
    [regex]::IsMatch(
        $supervisorText,
        'rapier_parry"\) \{.{0,500}"physical".{0,500}"--campaign-seed"',
        [Text.RegularExpressions.RegexOptions]::Singleline
    ) -and
    [regex]::IsMatch(
        $supervisorText,
        'rapier_parry"\) \{.{0,500}"authorization-preflight".{0,500}"--campaign-seed"',
        [Text.RegularExpressions.RegexOptions]::Singleline
    )
) "both Rapier supervisor call sites were not proved nonconforming"
Assert-R23D63Closure (
    $binaryText.Contains('"--seed" if campaign_seed.is_none()') -and
    -not $binaryText.Contains('"--campaign-seed"') -and
    $workerGateText.Contains('"--seed", $seed') -and
    -not $workerGateText.Contains('"--campaign-seed"')
) "Rapier parser or worker-gate conformance finding changed"

$mutations = @(
    @{ path = "status"; value = "passing" },
    @{ path = "attempt_id"; value = "replacement" },
    @{ path = "same_identity_rerun_allowed"; value = $true },
    @{ path = "physical_outcome_exposed"; value = $true },
    @{ path = "physical_evidence.world_build_count"; value = 1 },
    @{ path = "physical_evidence.physical_cell_process_count"; value = 1 },
    @{ path = "failure_mechanism.failure_class"; value = "physics_failure" },
    @{ path = "launcher_argument_conformance.supervisor_conforming_call_site_count"; value = 2 },
    @{ path = "launcher_argument_conformance.supervisor_nonconforming_call_site_count"; value = 0 },
    @{ path = "launcher_argument_conformance.equivalence_margin"; value = 0.1 },
    @{ path = "launcher_argument_conformance.exact_conformance_passed"; value = $true },
    @{ path = "official_result.physical_result_exists"; value = $true },
    @{ path = "official_result.finite_three_engine_turning"; value = $true },
    @{ path = "official_result.q_sdk_r23_satisfied"; value = $true },
    @{ path = "claims.prone_to_standing"; value = $true },
    @{ path = "claims.release_authorized"; value = $true }
)
foreach ($mutation in $mutations) {
    $candidate = $closure | ConvertTo-Json -Depth 100 -Compress |
        ConvertFrom-Json -Depth 100
    $parts = ([string]$mutation.path).Split('.')
    $parent = $candidate
    for ($index = 0; $index -lt $parts.Count - 1; $index++) {
        $parent = $parent.($parts[$index])
    }
    $parent.($parts[-1]) = $mutation.value
    Assert-R23D63Closure (-not (Test-R23D63ClosureVector $candidate)) (
        "closure mutation accepted: $($mutation.path)"
    )
}

Write-Output (
    "QSDK_R23D63_PHYSICAL_CLOSURE_PASS " +
    "files=11 unique_digests=8 authorization_processes=4 " +
    "authorization_receipts=3 cells=0 models=0 worlds=0 " +
    "rapier_supervisor_call_sites=2 conforming_call_sites=0 " +
    "mutations=$($mutations.Count) q_sdk_r23=False release_authority=False"
)
