#requires -Version 7.0

[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$sdkRoot = Join-Path $repoRoot "sdk"
$closurePath = Join-Path `
    $sdkRoot "locomotion_campaign_attestation_v1_commissioning_closure.json"
$artifactStorePath = Join-Path $sdkRoot "content_addressed_artifact_store.ps1"
$sourceCommit = "655d425b25606ca81cb821c8fdc61d7bf771d7af"
$sourceTree = "e3d07ab178c89eb118089d5808fe2de17c18997c"
. $artifactStorePath

function Assert-Lca1Closure([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "LCA1_COMMISSIONING_CLOSURE $Message" }
}

function Get-Lca1ClosureSha256([string]$Path) {
    return "sha256:" + (
        Get-FileHash -LiteralPath $Path -Algorithm SHA256
    ).Hash.ToLowerInvariant()
}

function Get-Lca1ClosureGitBlobSha256([string]$RelativePath) {
    $start = [Diagnostics.ProcessStartInfo]::new()
    $start.FileName = "git"
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    foreach ($argument in @(
        "-C", $repoRoot, "cat-file", "blob", "${sourceCommit}:$RelativePath"
    )) { [void]$start.ArgumentList.Add($argument) }
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $start
    try {
        Assert-Lca1Closure $process.Start() "could not start Git blob reader"
        $stderrTask = $process.StandardError.ReadToEndAsync()
        $hasher = [Security.Cryptography.SHA256]::Create()
        try { $digest = $hasher.ComputeHash($process.StandardOutput.BaseStream) }
        finally { $hasher.Dispose() }
        $process.WaitForExit()
        $stderr = $stderrTask.GetAwaiter().GetResult()
        Assert-Lca1Closure ($process.ExitCode -eq 0) (
            "Git blob read failed for $RelativePath`: $stderr"
        )
        return "sha256:" + [Convert]::ToHexString($digest).ToLowerInvariant()
    } finally { $process.Dispose() }
}

function Assert-Lca1ClosureArtifact([hashtable]$Artifact) {
    $path = [string]$Artifact.path
    Assert-Lca1Closure (Test-Path -LiteralPath $path -PathType Leaf) `
        "retained artifact is missing: $path"
    Assert-Lca1Closure (
        (Get-Item -LiteralPath $path).Length -eq [long]$Artifact.byte_length -and
        (Get-Lca1ClosureSha256 $path) -ceq [string]$Artifact.raw_sha256
    ) "retained artifact bytes changed: $path"
    if ([bool]$Artifact.cas_required) {
        $digest = ([string]$Artifact.raw_sha256).Substring(7)
        $artifactRoot = Join-Path (
            Get-SporeSporeArtifactEvidenceRoot -RepoRoot $repoRoot
        ) "artifacts\sha256"
        Assert-Lca1Closure (
            Test-SporeSporeStoredArtifact `
                -Directory (Join-Path $artifactRoot $digest) `
                -ExpectedSha256 $digest `
                -ExpectedByteLength ([long]$Artifact.byte_length)
        ) "retained CAS object changed: $digest"
    }
}

Assert-Lca1Closure (
    (git -C $repoRoot rev-parse --show-toplevel).Replace("/", "\") -ceq
        $repoRoot -and
    (git -C $repoRoot remote get-url origin) -ceq
        "https://github.com/Slagathore/sporespore.git" -and
    (git -C $repoRoot rev-parse ($sourceCommit + "^{tree}")) -ceq $sourceTree
) "repository or commissioned source identity changed"
$closure = Get-Content -LiteralPath $closurePath -Raw |
    ConvertFrom-Json -AsHashtable -Depth 100
$source = $closure.commissioned_implementation_source
$full = $closure.full_v2
$scoped = $closure.scoped_lca1
$comparison = $closure.comparison
Assert-Lca1Closure (
    [string]$closure.schema_version -ceq
        "sporespore_locomotion_campaign_attestation_commissioning_closure_v1" -and
    [string]$closure.status -ceq
        "closed_positive_same_source_full_scoped_subset_and_cas_verified" -and
    [string]$closure.contract_id -ceq
        "LCA1-GODOT-INCLUSIVE-CAMPAIGN-LOCAL-ATTESTATION" -and
    [string]$source.commit -ceq $sourceCommit -and
    [string]$source.tree_git_oid -ceq $sourceTree
) "closure identity changed"

foreach ($input in @($closure.commissioning_inputs.Values)) {
    $relative = [string]$input.path
    Assert-Lca1Closure (
        (Get-Lca1ClosureGitBlobSha256 $relative) -ceq [string]$input.raw_sha256
    ) "commissioned input Git blob changed: $relative"
}
Assert-Lca1ClosureArtifact $full.attestation
Assert-Lca1ClosureArtifact $full.run_receipt
Assert-Lca1ClosureArtifact $full.full_log
Assert-Lca1ClosureArtifact $scoped.attestation

$fullReceipt = Get-Content -LiteralPath ([string]$full.run_receipt.path) -Raw |
    ConvertFrom-Json -AsHashtable -Depth 100
$fullAttestation = Get-Content -LiteralPath ([string]$full.attestation.path) -Raw |
    ConvertFrom-Json -AsHashtable -Depth 100
$scopedAttestation = Get-Content -LiteralPath ([string]$scoped.attestation.path) -Raw |
    ConvertFrom-Json -AsHashtable -Depth 100
Assert-Lca1Closure (
    [string]$fullReceipt.status -ceq "passed" -and
    [string]$fullReceipt.source.head -ceq $sourceCommit -and
    [string]$fullReceipt.source.head_tree -ceq $sourceTree -and
    [double]$fullReceipt.duration_seconds -eq [double]$full.duration_seconds -and
    @($fullReceipt.stage_receipts).Count -eq 8 -and
    @($fullReceipt.stage_receipts | Where-Object { $_.status -cne "passed" }).Count -eq 0 -and
    [string]$fullAttestation.source.commit -ceq $sourceCommit -and
    [string]$fullAttestation.source.tree_git_oid -ceq $sourceTree -and
    @($fullReceipt.claims.GetEnumerator() | Where-Object { [bool]$_.Value }).Count -eq 0
) "full V2 evidence changed"

$fullText = Get-Content -LiteralPath ([string]$full.full_log.path) -Raw
foreach ($marker in @($comparison.required_terminal_marker_counts.Keys)) {
    Assert-Lca1Closure (
        [regex]::Matches($fullText, [regex]::Escape($marker)).Count -eq
            [int]$comparison.required_terminal_marker_counts[$marker]
    ) "full transcript marker count changed: $marker"
}

Assert-Lca1Closure (
    [string]$scopedAttestation.source.commit -ceq $sourceCommit -and
    [string]$scopedAttestation.source.tree_git_oid -ceq $sourceTree -and
    [string]$scopedAttestation.candidate_inventory_sha256 -ceq
        [string]$scoped.candidate_inventory_sha256 -and
    [string]$scopedAttestation.global_kernel_inventory_sha256 -ceq
        [string]$scoped.global_kernel_inventory_sha256 -and
    [int]$scopedAttestation.global_gate_count -eq 12 -and
    [int]$scopedAttestation.lineage_gate_count -eq 1 -and
    [int]$scopedAttestation.campaign_gate_count -eq 3 -and
    [int]$scopedAttestation.executed_gate_count -eq 16 -and
    @($scopedAttestation.core_source_bindings).Count -eq 11 -and
    @($scopedAttestation.campaign_source_bindings).Count -eq 10 -and
    @($scopedAttestation.campaign_role_bindings).Count -eq 3 -and
    [bool]$scopedAttestation.all_gates_executed -and
    [bool]$scopedAttestation.all_gate_streams_content_addressed -and
    -not [bool]$scopedAttestation.commissioned
) "scoped attestation identity or execution changed"

foreach ($binding in @($scopedAttestation.core_source_bindings) +
    @($scopedAttestation.campaign_source_bindings)) {
    Assert-Lca1Closure (
        (Get-Lca1ClosureGitBlobSha256 ([string]$binding.path)) -ceq
            [string]$binding.git_blob_raw_sha256
    ) "scoped source Git blob changed: $($binding.path)"
}

$casCount = 0
foreach ($gate in @($scopedAttestation.gate_receipts)) {
    $requiresMarker = [string]$gate.role -cne "global_safety_kernel"
    Assert-Lca1Closure (
        [bool]$gate.passed -and -not [bool]$gate.timed_out -and
        [int]$gate.exit_code -eq 0 -and [int]$gate.physical_world_count -eq 0 -and
        [bool]$gate.terminal_marker_required -eq $requiresMarker -and
        [int]$gate.terminal_marker_count -eq $(if ($requiresMarker) { 1 } else { 0 })
    ) "scoped gate execution changed: $($gate.gate_id)"
    foreach ($field in @("stdout_cas", "stderr_cas", "receipt_cas")) {
        $cas = $gate[$field]
        $digest = ([string]$cas.sha256).Substring(7)
        Assert-Lca1Closure (
            Test-SporeSporeStoredArtifact `
                -Directory (Split-Path -Parent ([string]$cas.payload_path)) `
                -ExpectedSha256 $digest `
                -ExpectedByteLength ([long]$cas.byte_length)
        ) "scoped gate CAS changed: $($gate.gate_id)/$field"
        $casCount++
    }
}
Assert-Lca1Closure ($casCount -eq 48) "scoped gate CAS count changed"

$sharedRuntimePairs = @(
    @($fullReceipt.toolchain_runtime_identity.godot, $scopedAttestation.runtime.godot),
    @($fullReceipt.toolchain_runtime_identity.powershell, $scopedAttestation.runtime.powershell),
    @($fullReceipt.toolchain_runtime_identity.python, $scopedAttestation.runtime.python),
    @($fullReceipt.toolchain_runtime_identity.cargo, $scopedAttestation.runtime.cargo),
    @($fullReceipt.toolchain_runtime_identity.rustc, $scopedAttestation.runtime.rustc)
)
foreach ($pair in $sharedRuntimePairs) {
    Assert-Lca1Closure (
        [string]$pair[0].executable_path -ceq [string]$pair[1].executable_path -and
        [string]$pair[0].executable_sha256 -ceq [string]$pair[1].executable_sha256 -and
        [string]$pair[0].version -ceq [string]$pair[1].version
    ) "full/scoped runtime identity diverged"
}
Assert-Lca1Closure (
    [string]$fullReceipt.toolchain_runtime_identity.operating_system -ceq
        [string]$scopedAttestation.runtime.host.os_description -and
    [string]$fullReceipt.toolchain_runtime_identity.process_architecture -ceq
        [string]$scopedAttestation.runtime.host.process_architecture
) "full/scoped host identity diverged"

$ratio = [double]$full.duration_seconds / [double]$scoped.duration_seconds
Assert-Lca1Closure (
    [Math]::Abs($ratio - [double]$comparison.full_over_scoped_speed_ratio) -lt 1e-12 -and
    [bool]$comparison.commissioning_passed -and
    [bool]$closure.negative_history.negative_results_preserved -and
    (Get-Lca1ClosureSha256 (Join-Path $repoRoot `
        ([string]$closure.negative_history.first_incident_path))) -ceq
        [string]$closure.negative_history.first_incident_raw_sha256 -and
    (Get-Lca1ClosureSha256 (Join-Path $repoRoot `
        ([string]$closure.negative_history.second_incident_path))) -ceq
        [string]$closure.negative_history.second_incident_raw_sha256 -and
    [bool]$closure.claims.campaign_local_attestation_implementation_commissioned -and
    @($closure.claims.GetEnumerator() | Where-Object {
        $_.Key -cne "campaign_local_attestation_implementation_commissioned" -and
        [bool]$_.Value
    }).Count -eq 0 -and
    [bool]$closure.adoption_boundary.separate_fail_closed_adoption_composition_required -and
    [bool]$closure.adoption_boundary.original_attestation_document_remains_zero_authority
) "commissioning verdict, history, or adoption boundary changed"

Write-Host (
    "LCA1_COMMISSIONING_CLOSURE_PASS source=$sourceCommit full_seconds=" +
    "$($full.duration_seconds) scoped_seconds=$($scoped.duration_seconds) " +
    "speed_ratio=$($comparison.full_over_scoped_speed_ratio) gates=16 cas=48 " +
    "markers=4/4 incidents=2 worlds=0 implementation_commissioned=True " +
    "physical_prerequisite=False physical_authority=False release_authority=False"
)
