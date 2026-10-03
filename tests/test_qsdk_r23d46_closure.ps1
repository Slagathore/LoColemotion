#requires -Version 7.0

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$closurePath = Join-Path $repoRoot (
    "sdk\turning\r23d46_support_loss_conditioned_startup_closure_v1.json"
)
$sourceCommit = "341e7ba3bcf0c12231f715c62da54034bc67d6b6"
$artifactRoot = Join-Path (
    (Split-Path -Parent $repoRoot)
) "SporeSpore_Evidence\artifacts\sha256"

function Assert-R46Closure([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "QSDK-R23D46 CLOSURE: $Message" }
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
    Assert-R46Closure ($process.Start()) "could not start git cat-file"
    $memory = [IO.MemoryStream]::new()
    try {
        $process.StandardOutput.BaseStream.CopyTo($memory)
        $stderr = $process.StandardError.ReadToEnd()
        $process.WaitForExit()
        Assert-R46Closure ($process.ExitCode -eq 0) (
            "historical blob unavailable: $RelativePath; $stderr"
        )
        return ,([byte[]]$memory.ToArray())
    } finally {
        $memory.Dispose()
        $process.Dispose()
    }
}

function Get-CasPayload([string]$Sha256, [long]$ByteLength) {
    Assert-R46Closure ($Sha256 -cmatch '^sha256:[0-9a-f]{64}$') (
        "invalid artifact digest: $Sha256"
    )
    $directory = Join-Path $artifactRoot $Sha256.Substring(7)
    $payload = Join-Path $directory "payload.bin"
    $manifestPath = Join-Path $directory "manifest.json"
    Assert-R46Closure (
        (Test-Path -LiteralPath $payload -PathType Leaf) -and
        (Test-Path -LiteralPath $manifestPath -PathType Leaf) -and
        (Get-Item -LiteralPath $payload).Length -eq $ByteLength -and
        ("sha256:" + (Get-FileHash -LiteralPath $payload -Algorithm SHA256).
            Hash.ToLowerInvariant()) -ceq $Sha256
    ) "CAS payload changed: $Sha256"
    $manifest = Get-Content -Raw -LiteralPath $manifestPath |
        ConvertFrom-Json -Depth 20
    Assert-R46Closure (
        [string]$manifest.schema_version -ceq
            "sporespore_content_addressed_artifact_manifest_v1" -and
        [string]$manifest.sha256 -ceq $Sha256 -and
        [long]$manifest.byte_length -eq $ByteLength -and
        [string]$manifest.payload_name -ceq "payload.bin"
    ) "CAS manifest changed: $Sha256"
    return $payload
}

function Assert-Near([double]$Actual, [double]$Expected, [string]$Message) {
    Assert-R46Closure (
        [double]::IsFinite($Actual) -and
        [Math]::Abs($Actual - $Expected) -le 1.0e-12
    ) $Message
}

Assert-R46Closure (
    (git -C $repoRoot rev-parse --show-toplevel).Trim().Replace('/', '\') -ceq
        $repoRoot -and
    (git -C $repoRoot remote get-url origin).Trim() -ceq
        "https://github.com/Slagathore/sporespore.git"
) "repository identity changed"

$closure = Get-Content -Raw -LiteralPath $closurePath |
    ConvertFrom-Json -Depth 100
Assert-R46Closure (
    [string]$closure.schema_version -ceq
        "sporespore_qsdk_r23d46_support_loss_conditioned_startup_closure_v1" -and
    [string]$closure.status -ceq
        "closed_consumed_invalid_complete_trace_receipt_contract_mismatch" -and
    [string]$closure.source_commit -ceq $sourceCommit -and
    (git -C $repoRoot rev-parse "$sourceCommit`^{tree}").Trim() -ceq
        [string]$closure.source_tree_git_oid -and
    [bool]$closure.identity_consumed -and
    -not [bool]$closure.same_identity_rerun_allowed -and
    -not [bool]$closure.selective_rerun_allowed -and
    -not [bool]$closure.fresh_or_held_out_condition_consumed -and
    [bool]$closure.successor_required_for_any_new_world
) "immutable disposition changed"

foreach ($input in @($closure.prospective_inputs)) {
    $relative = [string]$input.path
    $bytes = Get-GitBlobBytes $sourceCommit $relative
    Assert-R46Closure (
        $bytes.Length -eq [long]$input.byte_length -and
        (Get-BytesSha256 $bytes) -ceq [string]$input.raw_sha256 -and
        (git -C $repoRoot rev-parse "$sourceCommit`:$relative").Trim() -ceq
            [string]$input.git_blob_oid
    ) "prospective source identity changed: $relative"
}

$payloads = @{}
foreach ($property in $closure.physical_evidence.artifacts.PSObject.Properties) {
    $payloads[$property.Name] = Get-CasPayload (
        [string]$property.Value.sha256
    ) ([long]$property.Value.byte_length)
}
$terminal = Get-Content -Raw -LiteralPath $payloads.terminal |
    ConvertFrom-Json -Depth 40
$completion = Get-Content -Raw -LiteralPath $payloads.completion |
    ConvertFrom-Json -Depth 40
$authorization = Get-Content -Raw -LiteralPath $payloads.authorization_preflights |
    ConvertFrom-Json -Depth 40
$traceManifest = Get-Content -Raw -LiteralPath (
    Join-Path (Split-Path -Parent $payloads.diagnostic_trace) "manifest.json"
) | ConvertFrom-Json -Depth 20
Assert-R46Closure (
    [string]$terminal.failure_code -ceq
        "QSDK_R23D45_MJC_TRACE_CAS_RECEIPT_INVALID" -and
    [string]$terminal.failure_stage -ceq "settlement_complete" -and
    [int]$terminal.world_attempt_count -eq 1 -and
    [int]$terminal.world_build_count -eq 1 -and
    $null -eq $terminal.trace_artifact -and
    [string]$completion.classification -ceq
        "invalid_complete_support_loss_conditioned_startup" -and
    [int]$completion.process_exit_code -eq 1 -and
    $null -eq $completion.trace_artifact -and
    [bool]$authorization.positive.authorization_passed -and
    -not [bool]$authorization.wrong_token.authorization_passed -and
    [string]$authorization.wrong_token.failure_code -ceq
        "QSDK_R23D46_MJC_AUTHORIZATION_INVALID" -and
    [string]$traceManifest.media_type -ceq "application/x-ndjson"
) "retained invalid result or published manifest changed"

$rows = @(Get-Content -LiteralPath $payloads.diagnostic_trace | ForEach-Object {
    $_ | ConvertFrom-Json -Depth 30
})
Assert-R46Closure ($rows.Count -eq 2992) "diagnostic trace row count changed"
$active = 0
$zero = 0
$unity = 0
$torsoContacts = 0
$maximumTilt = 0.0
$minimumHeight = [double]::PositiveInfinity
$cycles = @{ rear_left = 0; front_left = 0; rear_right = 0; front_right = 0 }
$limbIds = @("rear_left", "front_left", "rear_right", "front_right")
$previous = @{}
foreach ($limb in $limbIds) {
    $previous[$limb] = [bool]$rows[0].ordered_foot_contacts_before.$limb
}
for ($index = 0; $index -lt $rows.Count; $index++) {
    $row = $rows[$index]
    $scale = [double]$row.startup_velocity_scale
    $expectedScale = if ($index -lt 3) { 1.0 } elseif ($index -eq 3) {
        0.0
    } elseif ($index -lt 362) {
        $local = [double]($index - 3) / 359.0
        $local * $local * (3.0 - 2.0 * $local)
    } else { 1.0 }
    Assert-R46Closure (
        [string]$row.schema_version -ceq
            "sporespore_qsdk_r23d3_turn_diagnostic_trace_row_v1" -and
        [string]$row.cell_id -ceq
            "mujoco__r23d29_support_loss_conditioned_startup_v1__reference_zero" -and
        [int]$row.semantic_step -eq $index -and
        [string]$row.segment_id -ceq "reference_walk" -and
        [bool]$row.oracle_passed -and
        [int]$row.validated_portable_command_count -eq 8 -and
        [int]$row.native_actuation_application_count -eq 8 -and
        [string]$row.startup_transform_id -ceq
            "support_loss_latched_smoothstep_one_cycle_v1" -and
        [Math]::Abs($scale - $expectedScale) -le 1.0e-15
    ) "diagnostic trace row changed: $index"
    $active += [int][bool]$row.startup_ramp_active
    $zero += [int]($scale -eq 0.0)
    $unity += [int]($scale -eq 1.0)
    $torsoContacts += [int][bool]$row.torso_ground_contact
    $maximumTilt = [Math]::Max($maximumTilt, [double]$row.torso_tilt_rad)
    $minimumHeight = [Math]::Min($minimumHeight, [double]$row.torso_height_m)
    foreach ($limb in $limbIds) {
        $present = [bool]$row.ordered_foot_contacts_after.$limb
        if (-not [bool]$previous[$limb] -and $present) { $cycles[$limb]++ }
        $previous[$limb] = $present
    }
}
$xDisplacement = [double]$rows[-1].torso_position_world_m[0] -
    [double]$rows[0].torso_position_world_m[0]
Assert-Near $xDisplacement 1.6388161404959682 "diagnostic displacement changed"
Assert-Near $maximumTilt 0.08961690764757078 "diagnostic tilt changed"
Assert-Near $minimumHeight 0.42436045664314553 "diagnostic height changed"
Assert-R46Closure (
    $active -eq 359 -and $zero -eq 1 -and $unity -eq 2633 -and
    $torsoContacts -eq 0 -and
    [int]$cycles.rear_left -eq 30 -and
    [int]$cycles.front_left -eq 31 -and
    [int]$cycles.rear_right -eq 28 -and
    [int]$cycles.front_right -eq 33 -and
    [bool]$closure.diagnostic_trace_result.consistent_with_successful_reference_walking -and
    -not [bool]$closure.diagnostic_trace_result.may_be_promoted_to_official_positive -and
    -not [bool]$closure.official_disposition.official_physics_result_accepted -and
    -not [bool]$closure.claims.walking -and
    -not [bool]$closure.claims.turning -and
    -not [bool]$closure.claims.cross_engine_equivalence -and
    -not [bool]$closure.claims.release_authorized -and
    -not [bool]$closure.claims.physical_acceptance_authority
) "diagnostic interpretation or claim boundary changed"

Write-Host (
    "QSDK_R23D46_CLOSURE_PASS classification=invalid worlds=1 steps=2992 " +
    "trace_rows=2992 diagnostic_walk_consistent=True official_walk=False rerun=False"
)
