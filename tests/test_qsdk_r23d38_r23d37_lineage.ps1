#requires -Version 7.0

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$closurePath = Join-Path $repoRoot (
    "sdk\turning\r23d37_mujoco_policy_seed_isolation_closure_v1.json"
)
$incidentPath = Join-Path $repoRoot (
    "sdk\turning\r23d38_first_scoped_attestation_incident_v1.json"
)
$artifactRoot = Join-Path (
    "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence"
) "artifacts\sha256"
$sourceCommit = "1235008d7da676e619e17b50f98735965c5a44e7"
$expectedClosureSha256 = (
    "sha256:5c20b77a88e8070bbb2bfa8dbdcd64e77abd4d952696d6758a057770da76acd8"
)

function Assert-R23D38Lineage([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "QSDK-R23D38 R23D37 LINEAGE: $Message" }
}

function Get-R23D38LineageSha256([string]$Path) {
    return "sha256:" + (
        Get-FileHash -LiteralPath $Path -Algorithm SHA256
    ).Hash.ToLowerInvariant()
}

function Assert-R23D38LineageCas([string]$Sha256, [long]$ByteLength) {
    Assert-R23D38Lineage ($Sha256 -cmatch '^sha256:[0-9a-f]{64}$') (
        "invalid CAS digest: $Sha256"
    )
    $directory = Join-Path $artifactRoot $Sha256.Substring(7)
    $payload = Join-Path $directory "payload.bin"
    $manifestPath = Join-Path $directory "manifest.json"
    Assert-R23D38Lineage (
        (Test-Path -LiteralPath $payload -PathType Leaf) -and
        (Test-Path -LiteralPath $manifestPath -PathType Leaf) -and
        (Get-Item -LiteralPath $payload).Length -eq $ByteLength -and
        (Get-R23D38LineageSha256 $payload) -ceq $Sha256
    ) "CAS payload changed: $Sha256"
    $manifest = Get-Content -Raw -LiteralPath $manifestPath |
        ConvertFrom-Json -Depth 20
    Assert-R23D38Lineage (
        [string]$manifest.schema_version -ceq
            "sporespore_content_addressed_artifact_manifest_v1" -and
        [string]$manifest.sha256 -ceq $Sha256 -and
        [long]$manifest.byte_length -eq $ByteLength -and
        [string]$manifest.payload_name -ceq "payload.bin"
    ) "CAS manifest changed: $Sha256"
    return $payload
}

$incident = Get-Content -Raw -LiteralPath $incidentPath |
    ConvertFrom-Json -Depth 100
Assert-R23D38Lineage (
    [string]$incident.schema_version -ceq
        "sporespore_qsdk_r23d38_scoped_attestation_incident_v1" -and
    [string]$incident.status -ceq "closed_preworld_qualification_failure" -and
    [string]$incident.source_commit -ceq
        "5040ca6c79e889c4cedd5860aaffd666b020d327" -and
    [int]$incident.global_gate_count_passed -eq 12 -and
    [int]$incident.lineage_gate_count_passed_before_failure -eq 3 -and
    [int]$incident.failed_ordinal -eq 16 -and
    [int]$incident.physical_world_count -eq 0 -and
    -not [bool]$incident.r23d38_physical_identity_consumed -and
    -not [bool]$incident.physical_launch_prerequisite_satisfied -and
    -not [bool]$incident.scientific_result
) "preworld qualification incident changed"
foreach ($record in @(
    $incident.failure_receipt,
    $incident.failed_gate_receipt
)) {
    $payload = Assert-R23D38LineageCas (
        [string]$record.sha256
    ) ([long]$record.byte_length)
    Assert-R23D38Lineage (
        (Test-Path -LiteralPath ([string]$record.path) -PathType Leaf) -and
        (Get-R23D38LineageSha256 ([string]$record.path)) -ceq
            [string]$record.sha256 -and
        (Get-R23D38LineageSha256 $payload) -ceq [string]$record.sha256
    ) "qualification incident receipt changed: $([string]$record.path)"
}
[void](Assert-R23D38LineageCas (
    [string]$incident.failed_gate_receipt.stderr_sha256
) ([long]$incident.failed_gate_receipt.stderr_byte_length))

Assert-R23D38Lineage (
    (git -C $repoRoot rev-parse --show-toplevel).Trim().Replace('/', '\') -ceq
        $repoRoot -and
    (git -C $repoRoot remote get-url origin).Trim() -ceq
        "https://github.com/Slagathore/sporespore.git" -and
    (Get-R23D38LineageSha256 $closurePath) -ceq $expectedClosureSha256
) "repository or closure identity changed"

$closure = Get-Content -Raw -LiteralPath $closurePath |
    ConvertFrom-Json -Depth 100
Assert-R23D38Lineage (
    [string]$closure.schema_version -ceq
        "sporespore_qsdk_r23d37_mujoco_policy_seed_isolation_closure_v1" -and
    [string]$closure.status -ceq
        "closed_consumed_valid_complete_negative_policy_seed_isolation" -and
    [string]$closure.campaign_id -ceq
        "QSDK-R23D37-MUJOCO-R23D21-POLICY-SEED-ISOLATION" -and
    [string]$closure.source_commit -ceq $sourceCommit -and
    (git -C $repoRoot rev-parse "${sourceCommit}^{tree}").Trim() -ceq
        [string]$closure.source_tree_git_oid -and
    [bool]$closure.identity_consumed -and
    -not [bool]$closure.same_identity_rerun_allowed -and
    -not [bool]$closure.selective_rerun_allowed -and
    [string]$closure.official_result.classification -ceq
        "valid_complete_negative_policy_seed_isolation" -and
    [bool]$closure.official_result.execution_valid -and
    -not [bool]$closure.official_result.common_physical_gate_passed -and
    [bool]$closure.official_result.scientific_selector_legally_completed
) "consumed R23D37 result changed"

foreach ($record in @(
    $closure.physical_evidence.terminal,
    $closure.physical_evidence.complete_evaluation,
    $closure.physical_evidence.report,
    $closure.physical_evidence.completion,
    $closure.physical_evidence.trace
)) {
    $payload = Assert-R23D38LineageCas (
        [string]$record.sha256
    ) ([long]$record.byte_length)
    Assert-R23D38Lineage (
        (Test-Path -LiteralPath ([string]$record.path) -PathType Leaf) -and
        (Get-R23D38LineageSha256 ([string]$record.path)) -ceq
            [string]$record.sha256 -and
        (Get-R23D38LineageSha256 $payload) -ceq [string]$record.sha256
    ) "retained evidence path and CAS differ: $([string]$record.path)"
}

$terminal = Get-Content -Raw -LiteralPath (
    [string]$closure.physical_evidence.terminal.path
) | ConvertFrom-Json -Depth 100
$evaluation = Get-Content -Raw -LiteralPath (
    [string]$closure.physical_evidence.complete_evaluation.path
) | ConvertFrom-Json -Depth 100
Assert-R23D38Lineage (
    [string]$terminal.source_commit -ceq $sourceCommit -and
    [int]$terminal.execution.world_build_count -eq 1 -and
    [int]$terminal.execution.controller_semantic_step_count -eq 2992 -and
    [int]$terminal.execution.native_actuation_application_count -eq 23936 -and
    [double]$terminal.measurements.final_forward_displacement_m -eq
        -0.5908297647386241 -and
    [double]$terminal.measurements.maximum_tilt_rad -eq
        1.8316205777362669 -and
    [int]$terminal.measurements.torso_ground_contact_step_count -eq 2785 -and
    [string]$evaluation.classification -ceq
        "valid_complete_negative_policy_seed_isolation" -and
    [bool]$evaluation.cell_evaluations[0].execution_valid -and
    -not [bool]$evaluation.cell_evaluations[0].common_physical_gate_passed
) "retained R23D37 terminal result changed"

$freeze = Get-Content -Raw -LiteralPath (
    [string]$closure.physical_evidence.physical_freeze.path
) | ConvertFrom-Json -Depth 100
$prospectiveNames = @(
    "preregistration", "implementation", "campaign_attestation_manifest",
    "worker", "design", "evaluator", "supervisor", "strict_array_writer"
)
foreach ($name in $prospectiveNames) {
    $relative = [string]$closure.prospective_inputs."${name}_path"
    $expectedRaw = [string]$closure.prospective_inputs."${name}_raw_sha256"
    $indices = @(
        for ($index = 0; $index -lt @($freeze.source_bindings).Count; $index++) {
            if ([string]$freeze.source_bindings[$index].path -ceq $relative) {
                $index
            }
        }
    )
    Assert-R23D38Lineage ($indices.Count -eq 1) (
        "frozen source binding missing: $relative"
    )
    $binding = $freeze.source_bindings[$indices[0]]
    $retained = $freeze.content_addressed_inputs.source_bindings[$indices[0]]
    Assert-R23D38Lineage (
        [string]$binding.raw_sha256 -ceq $expectedRaw -and
        [string]$retained.sha256 -ceq $expectedRaw -and
        (git -C $repoRoot rev-parse "${sourceCommit}:$relative").Trim() -ceq
            [string]$binding.git_blob_oid -and
        [bool]$binding.raw_checkout_equals_git_blob
    ) "frozen source binding changed: $relative"
    [void](Assert-R23D38LineageCas (
        [string]$retained.sha256
    ) ([long]$retained.byte_length))
}

$sdkRoot = Join-Path $repoRoot "sdk"
$mujocoRoot = Join-Path $sdkRoot "adapters\mujoco"
$savedPythonPath = $env:PYTHONPATH
$savedLibrary = $env:SPORESPORE_LOCOMOTION_LIBRARY
try {
    $env:PYTHONPATH = (@(
        (Join-Path $sdkRoot "python"),
        $mujocoRoot,
        (Join-Path $mujocoRoot ".venv\Lib\site-packages"),
        (Join-Path $sdkRoot "turning")
    ) -join [IO.Path]::PathSeparator)
    $env:SPORESPORE_LOCOMOTION_LIBRARY = Join-Path (
        $sdkRoot
    ) "target\debug\sporespore_locomotion_core.dll"
    $refusal = @(
        & python -m `
            sporespore_mujoco_adapter.qsdk_r23d37_policy_seed_isolation `
            preflight --stage "mujoco_r23d21_same_seed_policy_isolation" `
            --onset "onset_600" --arm "reference_zero" 2>&1
    ) | Out-String
    $refusalExitCode = $LASTEXITCODE
} finally {
    $env:PYTHONPATH = $savedPythonPath
    $env:SPORESPORE_LOCOMOTION_LIBRARY = $savedLibrary
}
Assert-R23D38Lineage (
    $refusalExitCode -ne 0 -and
    $refusal.Contains('"failure_code":"QSDK_R23D37_MJC_CLOSED"')
) "closed R23D37 worker refusal changed: $refusal"

Write-Host (
    "QSDK_R23D38_R23D37_LINEAGE_PASS closure_sha256=$expectedClosureSha256 " +
    "evidence_objects=5 source_bindings=8 closed_worker=True worlds=0"
)
