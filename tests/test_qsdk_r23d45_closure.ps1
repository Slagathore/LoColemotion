#requires -Version 7.0

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$closurePath = Join-Path $repoRoot (
    "sdk\turning\r23d45_support_loss_conditioned_startup_closure_v1.json"
)
$sourceCommit = "64ce327870886a4a57e5b4a343a9434c559fcc6a"
$artifactRoot = Join-Path (
    (Split-Path -Parent $repoRoot)
) "SporeSpore_Evidence\artifacts\sha256"

function Assert-R45Closure([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "QSDK-R23D45 CLOSURE: $Message" }
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
    Assert-R45Closure ($process.Start()) "could not start git cat-file"
    $memory = [IO.MemoryStream]::new()
    try {
        $process.StandardOutput.BaseStream.CopyTo($memory)
        $stderr = $process.StandardError.ReadToEnd()
        $process.WaitForExit()
        Assert-R45Closure ($process.ExitCode -eq 0) (
            "historical blob unavailable: $RelativePath; $stderr"
        )
        return ,([byte[]]$memory.ToArray())
    } finally {
        $memory.Dispose()
        $process.Dispose()
    }
}

function Get-CasPayload([string]$Sha256, [long]$ByteLength) {
    Assert-R45Closure ($Sha256 -cmatch '^sha256:[0-9a-f]{64}$') (
        "invalid artifact digest: $Sha256"
    )
    $directory = Join-Path $artifactRoot $Sha256.Substring(7)
    $payload = Join-Path $directory "payload.bin"
    $manifestPath = Join-Path $directory "manifest.json"
    Assert-R45Closure (
        (Test-Path -LiteralPath $payload -PathType Leaf) -and
        (Test-Path -LiteralPath $manifestPath -PathType Leaf) -and
        (Get-Item -LiteralPath $payload).Length -eq $ByteLength -and
        ("sha256:" + (Get-FileHash -LiteralPath $payload -Algorithm SHA256).
            Hash.ToLowerInvariant()) -ceq $Sha256
    ) "CAS payload changed: $Sha256"
    $manifest = Get-Content -Raw -LiteralPath $manifestPath |
        ConvertFrom-Json -Depth 20
    Assert-R45Closure (
        [string]$manifest.schema_version -ceq
            "sporespore_content_addressed_artifact_manifest_v1" -and
        [string]$manifest.sha256 -ceq $Sha256 -and
        [long]$manifest.byte_length -eq $ByteLength -and
        [string]$manifest.payload_name -ceq "payload.bin"
    ) "CAS manifest changed: $Sha256"
    return $payload
}

Assert-R45Closure (
    (git -C $repoRoot rev-parse --show-toplevel).Trim().Replace('/', '\') -ceq
        $repoRoot -and
    (git -C $repoRoot remote get-url origin).Trim() -ceq
        "https://github.com/Slagathore/sporespore.git"
) "repository identity changed"

$closure = Get-Content -Raw -LiteralPath $closurePath |
    ConvertFrom-Json -Depth 100
Assert-R45Closure (
    [string]$closure.schema_version -ceq
        "sporespore_qsdk_r23d45_support_loss_conditioned_startup_closure_v1" -and
    [string]$closure.status -ceq
        "closed_consumed_invalid_complete_missing_inherited_phase_offsets_interface" -and
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
    Assert-R45Closure (
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
Assert-R45Closure (
    [string]$terminal.failure_code -ceq
        "QSDK_R23D3_MJC_PHYSICAL_WORKER_ERROR:AttributeError:module 'r23d45_support_loss_conditioned_startup' has no attribute 'PHASE_OFFSETS'" -and
    [string]$terminal.failure_stage -ceq "settlement_complete" -and
    [int]$terminal.world_attempt_count -eq 1 -and
    [int]$terminal.world_build_count -eq 1 -and
    $null -eq $terminal.trace_artifact -and
    [string]$completion.classification -ceq
        "invalid_complete_support_loss_conditioned_startup" -and
    [int]$completion.process_exit_code -eq 1 -and
    [int]$completion.world_attempt_count -eq 1 -and
    [int]$completion.world_build_count -eq 1 -and
    $null -eq $completion.trace_artifact -and
    [bool]$authorization.positive.authorization_passed -and
    -not [bool]$authorization.wrong_token.authorization_passed -and
    [string]$authorization.wrong_token.failure_code -ceq
        "QSDK_R23D45_MJC_AUTHORIZATION_INVALID"
) "retained invalid result changed"

$designBytes = Get-GitBlobBytes $sourceCommit (
    "sdk/turning/r23d45_support_loss_conditioned_startup.py"
)
$workerBytes = Get-GitBlobBytes $sourceCommit (
    "sdk/adapters/mujoco/sporespore_mujoco_adapter/qsdk_r23d3_phase_balanced.py"
)
$designText = [Text.Encoding]::UTF8.GetString($designBytes)
$workerText = [Text.Encoding]::UTF8.GetString($workerBytes)
Assert-R45Closure (
    $designText -cnotmatch '(?m)^PHASE_OFFSETS\s*=' -and
    $workerText.Contains("design.PHASE_OFFSETS") -and
    [string]$closure.official_disposition.classification -ceq
        "invalid_complete_support_loss_conditioned_startup" -and
    -not [bool]$closure.official_disposition.physics_result_interpretable -and
    -not [bool]$closure.official_disposition.walking_tested -and
    -not [bool]$closure.official_disposition.startup_mechanism_tested -and
    -not [bool]$closure.claims.walking -and
    -not [bool]$closure.claims.turning -and
    -not [bool]$closure.claims.cross_engine_equivalence -and
    -not [bool]$closure.claims.release_authorized -and
    -not [bool]$closure.claims.physical_acceptance_authority
) "diagnosis or claim boundary changed"

Write-Host (
    "QSDK_R23D45_CLOSURE_PASS classification=invalid worlds=1 " +
    "controller_steps=0 traces=0 missing=PHASE_OFFSETS rerun=False"
)
