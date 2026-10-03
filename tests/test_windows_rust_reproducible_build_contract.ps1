#requires -Version 7.0

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = [System.IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$contractPath = Join-Path $repoRoot "sdk\windows_rust_reproducible_build_contract.json"
$storePath = Join-Path $repoRoot "sdk\content_addressed_artifact_store.ps1"
$runnerPath = Join-Path $repoRoot "sdk\run_windows_rust_reproducible_build.ps1"
$receiptPath = (
    "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence\" +
    "mv6-build-repro-characterization-20260805\receipt.json"
)

function Assert-Exact([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}
function Get-RawSha256([string]$Path) {
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).
        Hash.ToLowerInvariant()
}

Assert-Exact (
    (git -C $repoRoot rev-parse --show-toplevel).Trim() -ceq
        $repoRoot.Replace("\", "/") -and
    (git -C $repoRoot remote get-url origin).Trim() -ceq
        "https://github.com/Slagathore/sporespore.git"
) "WRB1 repository identity mismatch"
foreach ($path in @($contractPath, $storePath, $runnerPath, $receiptPath)) {
    Assert-Exact (Test-Path -LiteralPath $path -PathType Leaf) (
        "WRB1 required contract, implementation, or observation is missing: $path"
    )
}
$contract = Get-Content -Raw -LiteralPath $contractPath |
    ConvertFrom-Json -AsHashtable -Depth 64
Assert-Exact (
    [string]$contract.schema_version -ceq
        "sporespore_windows_rust_reproducible_build_contract_v1" -and
    [string]$contract.contract_id -ceq "WRB1" -and
    [string]$contract.target_triple -ceq "x86_64-pc-windows-msvc" -and
    [string]$contract.toolchain.rustc_version -ceq "1.97.0" -and
    [string]$contract.toolchain.rustc_commit -ceq
        "2d8144b7880597b6e6d3dfd63a9a9efae3f533d3" -and
    [string]$contract.toolchain.cargo_version -ceq "1.97.0" -and
    -not [bool]$contract.build.codegen_units_override -and
    [bool]$contract.two_clean_root_gate.required -and
    [int]$contract.two_clean_root_gate.differing_byte_count_required -eq 0 -and
    [int]$contract.two_clean_root_gate.windows_absolute_path_count_required -eq 0 -and
    [bool]$contract.content_addressed_retention.required_before_first_consumer_process
) "WRB1 build contract identity changed"
$flags = @($contract.build.rustflags)
foreach ($required in @(
    "--remap-path-prefix=<source-root>=/sporespore",
    "--remap-path-prefix=<cargo-home>=/cargo-home",
    "--remap-path-prefix=<rust-sysroot>=/rust-sysroot",
    "-Clink-arg=/Brepro",
    "-Clink-arg=/PDBALTPATH:%_PDB%"
)) {
    Assert-Exact ($flags -ccontains $required) "WRB1 missing required flag: $required"
}
Assert-Exact (
    @($contract.pe_nondeterminism_diagnostic.fields).Count -eq 5 -and
    [int]$contract.pe_nondeterminism_diagnostic.characterized_baseline_differing_byte_count -eq 20 -and
    [int]$contract.pe_nondeterminism_diagnostic.fields[0].file_offset -eq 248 -and
    [string]$contract.pe_nondeterminism_diagnostic.fields[0].name -ceq
        "IMAGE_FILE_HEADER.TimeDateStamp" -and
    [int]$contract.pe_nondeterminism_diagnostic.fields[4].file_offset -eq 1394036 -and
    [int]$contract.pe_nondeterminism_diagnostic.fields[4].length -eq 16 -and
    [string]$contract.pe_nondeterminism_diagnostic.fields[4].name -ceq
        "RSDS_CodeView_GUID"
) "WRB1 PE field mapping changed"
Assert-Exact (
    (Get-RawSha256 $receiptPath) -ceq
        ([string]$contract.characterization_observation.receipt_raw_sha256).
            Replace("sha256:", "") -and
    [string]$contract.characterization_observation.winning_artifact_raw_sha256 -ceq
        "sha256:c124f52ceb3ce928950bf31653813fb4787e04cdb9e6ee05b0b2998c3fd5e409" -and
    [int]$contract.characterization_observation.winning_artifact_byte_length -eq 1579008 -and
    [int]$contract.characterization_observation.world_count -eq 0 -and
    [string]$contract.historical_boundary.mv6_expected_artifact_raw_sha256 -ceq
        "sha256:a345625986b7eafdd77a59dd1f9fb96bf5a9bde5bc5e78b54b3d027a356ae957" -and
    -not [bool]$contract.historical_boundary.mv6_original_artifact_bytes_retained -and
    -not [bool]$contract.historical_boundary.mv6_closure_may_be_modified -and
    -not [bool]$contract.historical_boundary.successor_artifact_may_substitute_for_mv6
) "WRB1 observation or immutable MV6 boundary changed"

. $storePath
$testRoot = Join-Path ([System.IO.Path]::GetTempPath()) (
    "sporespore-artifact-store-test-" + [guid]::NewGuid().ToString("N")
)
[void][System.IO.Directory]::CreateDirectory($testRoot)
try {
    $input = Join-Path $testRoot "input.dll"
    [System.IO.File]::WriteAllBytes(
        $input,
        [System.Text.Encoding]::UTF8.GetBytes("WRB1-content-addressed-canary")
    )
    $first = Publish-SporeSporeContentAddressedArtifact `
        -RepoRoot $repoRoot `
        -ArtifactPath $input `
        -EvidenceRootOverride $testRoot `
        -TestOnly
    Assert-Exact (
        -not [bool]$first.already_present -and
        [bool]$first.test_only -and
        (Test-Path -LiteralPath ([string]$first.payload_path) -PathType Leaf) -and
        (Get-RawSha256 ([string]$first.payload_path)) -ceq
            ([string]$first.sha256).Replace("sha256:", "")
    ) "WRB1 first content-addressed publication failed"
    $second = Publish-SporeSporeContentAddressedArtifact `
        -RepoRoot $repoRoot `
        -ArtifactPath $input `
        -EvidenceRootOverride $testRoot `
        -TestOnly
    Assert-Exact (
        [bool]$second.already_present -and
        [string]$second.sha256 -ceq [string]$first.sha256 -and
        [string]$second.payload_path -ceq [string]$first.payload_path
    ) "WRB1 idempotent content-addressed publication failed"
    [System.IO.File]::WriteAllBytes(
        [string]$first.payload_path,
        [System.Text.Encoding]::UTF8.GetBytes("tampered")
    )
    $corruptionRejected = $false
    try {
        [void](Publish-SporeSporeContentAddressedArtifact `
            -RepoRoot $repoRoot `
            -ArtifactPath $input `
            -EvidenceRootOverride $testRoot `
            -TestOnly)
    } catch { $corruptionRejected = $true }
    Assert-Exact $corruptionRejected "WRB1 stored-artifact corruption was accepted"
} finally {
    $resolvedTest = [System.IO.Path]::GetFullPath($testRoot)
    $temp = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath()).TrimEnd('\', '/')
    Assert-Exact (
        $resolvedTest.StartsWith(
            $temp + [System.IO.Path]::DirectorySeparatorChar,
            [System.StringComparison]::OrdinalIgnoreCase
        ) -and
        (Split-Path -Leaf $resolvedTest) -like "sporespore-artifact-store-test-*"
    ) "WRB1 refusing unsafe test cleanup"
    Remove-Item -LiteralPath $resolvedTest -Recurse -Force
}

& pwsh -NoLogo -NoProfile -File $runnerPath -PreflightOnly
Assert-Exact ($LASTEXITCODE -eq 0) "WRB1 real runner preflight failed"

Write-Host (
    "WINDOWS_RUST_REPRODUCIBLE_BUILD_CONTRACT_PASS worlds=0 roots=2 " +
    "baseline_diff_bytes=20 winning_diff_bytes=0 codegen_units_override=False " +
    "content_addressed_store=True mv6_substitution=False physical_authority=False " +
    "contract_sha256=$(Get-RawSha256 $contractPath)"
)
