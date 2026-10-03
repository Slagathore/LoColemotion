#requires -Version 7.0

[CmdletBinding()]
param(
    [switch]$PreflightOnly,
    [switch]$VerifyTwoRoot,
    [string]$OutputRoot = ""
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$sdkRoot = [System.IO.Path]::GetFullPath($PSScriptRoot)
$repoRoot = [System.IO.Path]::GetFullPath((Split-Path -Parent $sdkRoot))
$contractPath = Join-Path $sdkRoot "windows_rust_reproducible_build_contract.json"
$storePath = Join-Path $sdkRoot "content_addressed_artifact_store.ps1"
. $storePath

function Assert-WrbExact([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}
function Get-WrbRawSha256([string]$Path) {
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).
        Hash.ToLowerInvariant()
}
function Invoke-WrbGit([string[]]$Arguments) {
    $output = @(& git -C $repoRoot @Arguments 2>&1)
    if ($LASTEXITCODE -ne 0) {
        throw "WRB1 git failed: git $($Arguments -join ' '): $($output -join ' ')"
    }
    return ($output -join "`n").Trim()
}
function Set-WrbProcessEnvironment(
    [System.Collections.IDictionary]$Values,
    [scriptblock]$Action
) {
    $prior = @{}
    foreach ($name in $Values.Keys) {
        $prior[$name] = [Environment]::GetEnvironmentVariable(
            [string]$name,
            [EnvironmentVariableTarget]::Process
        )
        [Environment]::SetEnvironmentVariable(
            [string]$name,
            [string]$Values[$name],
            [EnvironmentVariableTarget]::Process
        )
    }
    try { return & $Action }
    finally {
        foreach ($name in $Values.Keys) {
            [Environment]::SetEnvironmentVariable(
                [string]$name,
                $prior[$name],
                [EnvironmentVariableTarget]::Process
            )
        }
    }
}
function Invoke-WrbBuild(
    [string]$SourceRoot,
    [string]$TargetRoot,
    [string]$LogPath,
    [string]$SourceDateEpoch,
    [string]$CargoHome,
    [string]$RustSysroot
) {
    $manifest = Join-Path $SourceRoot "sdk\Cargo.toml"
    $flags = @(
        "--remap-path-prefix=$SourceRoot=/sporespore",
        "--remap-path-prefix=$CargoHome=/cargo-home",
        "--remap-path-prefix=$RustSysroot=/rust-sysroot",
        "-Clink-arg=/Brepro",
        "-Clink-arg=/PDBALTPATH:%_PDB%"
    )
    $environment = [ordered]@{
        CARGO_TARGET_DIR = $TargetRoot
        CARGO_INCREMENTAL = "0"
        SOURCE_DATE_EPOCH = $SourceDateEpoch
        CARGO_ENCODED_RUSTFLAGS = ($flags -join [char]0x1f)
        RUSTFLAGS = ""
    }
    $timer = [System.Diagnostics.Stopwatch]::StartNew()
    $lines = Set-WrbProcessEnvironment $environment {
        @(& cargo build `
            --manifest-path $manifest `
            --package "sporespore-locomotion-core" `
            --release `
            --locked `
            --offline 2>&1)
    }
    $exitCode = $LASTEXITCODE
    $timer.Stop()
    [System.IO.File]::WriteAllText(
        $LogPath,
        ($lines -join [Environment]::NewLine) + [Environment]::NewLine,
        [System.Text.UTF8Encoding]::new($false)
    )
    Assert-WrbExact ($exitCode -eq 0) "WRB1 Cargo build failed; inspect $LogPath"
    $artifact = Join-Path $TargetRoot "release\sporespore_locomotion_core.dll"
    Assert-WrbExact (Test-Path -LiteralPath $artifact -PathType Leaf) (
        "WRB1 expected artifact is missing: $artifact"
    )
    return [ordered]@{
        artifact_path = $artifact
        raw_sha256 = Get-WrbRawSha256 $artifact
        byte_length = (Get-Item -LiteralPath $artifact).Length
        duration_seconds = $timer.Elapsed.TotalSeconds
        log_path = $LogPath
        log_raw_sha256 = Get-WrbRawSha256 $LogPath
    }
}
function Get-WrbBinaryPathReceipt([string]$Path) {
    $bytes = [System.IO.File]::ReadAllBytes($Path)
    $ascii = [System.Text.Encoding]::ASCII.GetString($bytes)
    $matches = [regex]::Matches($ascii, "(?i)[a-z]:\\")
    return [ordered]@{
        windows_absolute_path_marker_count = $matches.Count
        contains_user_profile_path = $ascii.Contains(
            [Environment]::GetFolderPath("UserProfile"),
            [System.StringComparison]::OrdinalIgnoreCase
        )
        contains_bare_pdb_name = $ascii.Contains(
            "sporespore_locomotion_core.pdb",
            [System.StringComparison]::Ordinal
        )
    }
}

Assert-WrbExact (
    (Invoke-WrbGit @("rev-parse", "--show-toplevel")) -ceq
        $repoRoot.Replace("\", "/") -and
    (Invoke-WrbGit @("remote", "get-url", "origin")) -ceq
        "https://github.com/Slagathore/sporespore.git"
) "WRB1 repository identity mismatch"
Assert-WrbExact (
    (Test-Path -LiteralPath $contractPath -PathType Leaf) -and
    (Test-Path -LiteralPath $storePath -PathType Leaf)
) "WRB1 contract or artifact store is missing"
$contract = Get-Content -Raw -LiteralPath $contractPath |
    ConvertFrom-Json -AsHashtable -Depth 64
Assert-WrbExact (
    [string]$contract.schema_version -ceq
        "sporespore_windows_rust_reproducible_build_contract_v1" -and
    [string]$contract.contract_id -ceq "WRB1" -and
    [string]$contract.target_triple -ceq "x86_64-pc-windows-msvc" -and
    -not [bool]$contract.build.codegen_units_override -and
    [bool]$contract.two_clean_root_gate.required -and
    [bool]$contract.content_addressed_retention.required_before_first_consumer_process
) "WRB1 contract identity changed"

$rustcIdentity = @(& rustc -vV 2>&1) -join "`n"
$cargoIdentity = @(& cargo -vV 2>&1) -join "`n"
Assert-WrbExact (
    $rustcIdentity -match "release: 1\.97\.0" -and
    $rustcIdentity -match "commit-hash: 2d8144b7880597b6e6d3dfd63a9a9efae3f533d3" -and
    $rustcIdentity -match "host: x86_64-pc-windows-msvc" -and
    $rustcIdentity -match "LLVM version: 22\.1\.6" -and
    $cargoIdentity -match "release: 1\.97\.0" -and
    $cargoIdentity -match "commit-hash: c980f4866141969fab6254a680546a277789d6f0"
) "WRB1 pinned Rust/Cargo toolchain is not active"

if ($PreflightOnly) {
    Assert-WrbExact (-not $VerifyTwoRoot) (
        "WRB1 -PreflightOnly cannot be combined with -VerifyTwoRoot"
    )
    Write-Host (
        "WINDOWS_RUST_REPRODUCIBLE_BUILD_PREFLIGHT_PASS worlds=0 " +
        "toolchain=rustc-1.97.0 roots=2 raw_byte_equality=True " +
        "codegen_units_override=False content_addressed_store=True " +
        "physical_authority=False"
    )
    exit 0
}
Assert-WrbExact $VerifyTwoRoot "WRB1 actual execution requires -VerifyTwoRoot"

$head = Invoke-WrbGit @("rev-parse", "HEAD")
$tree = Invoke-WrbGit @("rev-parse", "HEAD^{tree}")
$origin = Invoke-WrbGit @("rev-parse", "origin/main")
$status = Invoke-WrbGit @("status", "--short")
$remoteLine = Invoke-WrbGit @("ls-remote", "origin", "refs/heads/main")
$live = if ([string]::IsNullOrWhiteSpace($remoteLine)) {
    ""
} else { ($remoteLine -split "\s+")[0] }
Assert-WrbExact (
    [string]::IsNullOrWhiteSpace($status) -and
    $head -ceq $origin -and
    $head -ceq $live
) "WRB1 two-root execution requires clean pushed live source"

$evidenceRoot = Get-SporeSporeArtifactEvidenceRoot -RepoRoot $repoRoot
if ([string]::IsNullOrWhiteSpace($OutputRoot)) {
    $OutputRoot = Join-Path $evidenceRoot (
        "windows-rust-reproducible-build-" +
        [DateTime]::UtcNow.ToString("yyyyMMddTHHmmssZ")
    )
}
$resolvedOutput = [System.IO.Path]::GetFullPath($OutputRoot)
$evidencePrefix = $evidenceRoot.TrimEnd('\', '/') +
    [System.IO.Path]::DirectorySeparatorChar
Assert-WrbExact (
    $resolvedOutput.StartsWith(
        $evidencePrefix,
        [System.StringComparison]::OrdinalIgnoreCase
    ) -and
    -not (Test-Path -LiteralPath $resolvedOutput)
) "WRB1 output must be a new directory inside $evidenceRoot"
[void][System.IO.Directory]::CreateDirectory($resolvedOutput)

$archive = Join-Path $resolvedOutput "source.zip"
& git -C $repoRoot archive --format=zip --output=$archive $head
Assert-WrbExact ($LASTEXITCODE -eq 0) "WRB1 source archive failed"
$sourceA = Join-Path $resolvedOutput "source-a"
$sourceB = Join-Path $resolvedOutput "source-b"
Expand-Archive -LiteralPath $archive -DestinationPath $sourceA
Expand-Archive -LiteralPath $archive -DestinationPath $sourceB
$sourceEpoch = (Invoke-WrbGit @("show", "-s", "--format=%ct", $head)).Trim()
$cargoHome = Join-Path ([Environment]::GetFolderPath("UserProfile")) ".cargo"
$rustSysroot = (@(& rustc --print sysroot 2>&1) -join "`n").Trim()
$buildA = Invoke-WrbBuild `
    -SourceRoot $sourceA `
    -TargetRoot (Join-Path $resolvedOutput "target-a") `
    -LogPath (Join-Path $resolvedOutput "build-a.log") `
    -SourceDateEpoch $sourceEpoch `
    -CargoHome $cargoHome `
    -RustSysroot $rustSysroot
$buildB = Invoke-WrbBuild `
    -SourceRoot $sourceB `
    -TargetRoot (Join-Path $resolvedOutput "target-b") `
    -LogPath (Join-Path $resolvedOutput "build-b.log") `
    -SourceDateEpoch $sourceEpoch `
    -CargoHome $cargoHome `
    -RustSysroot $rustSysroot
$pathReceipt = Get-WrbBinaryPathReceipt ([string]$buildA.artifact_path)
Assert-WrbExact (
    [string]$buildA.raw_sha256 -ceq [string]$buildB.raw_sha256 -and
    [long]$buildA.byte_length -eq [long]$buildB.byte_length -and
    [int]$pathReceipt.windows_absolute_path_marker_count -eq 0 -and
    -not [bool]$pathReceipt.contains_user_profile_path -and
    [bool]$pathReceipt.contains_bare_pdb_name
) "WRB1 two-clean-root raw-byte or path-independence gate failed"

# Store the proven bytes before any consumer process can use them. The mutable
# Cargo target remains a build cache, never evidence authority.
$stored = Publish-SporeSporeContentAddressedArtifact `
    -RepoRoot $repoRoot `
    -ArtifactPath ([string]$buildA.artifact_path) `
    -MediaType "application/vnd.microsoft.portable-executable"
$receipt = [ordered]@{
    schema_version = "sporespore_windows_rust_reproducible_build_receipt_v1"
    contract_id = "WRB1"
    completed_utc = [DateTime]::UtcNow.ToString("o")
    source = [ordered]@{
        commit = $head
        tree_git_oid = $tree
        origin_main = $origin
        live_github_main = $live
        clean_pushed_live = $true
        commit_epoch = [long]$sourceEpoch
        archive_raw_sha256 = "sha256:$(Get-WrbRawSha256 $archive)"
    }
    toolchain = [ordered]@{
        rustc = $rustcIdentity
        cargo = $cargoIdentity
        rust_sysroot_remapped = $true
        cargo_home_remapped = $true
    }
    build_a = $buildA
    build_b = $buildB
    raw_byte_equality = $true
    differing_byte_count = 0
    path_receipt = $pathReceipt
    codegen_units_override = $false
    content_addressed_artifact = $stored
    physical_worlds = 0
    physical_acceptance_authority = $false
    mv6_artifact_recovered = $false
    mv6_substitution = $false
    release_authorized = $false
}
$receiptPath = Join-Path $resolvedOutput "receipt.json"
[System.IO.File]::WriteAllText(
    $receiptPath,
    ($receipt | ConvertTo-Json -Depth 32) + [Environment]::NewLine,
    [System.Text.UTF8Encoding]::new($false)
)
Write-Host (
    "WINDOWS_RUST_REPRODUCIBLE_BUILD_PASS worlds=0 roots=2 " +
    "sha256=$([string]$stored.sha256) bytes=$([long]$stored.byte_length) " +
    "diff_bytes=0 absolute_paths=0 codegen_units_override=False " +
    "content_addressed=True mv6_substitution=False physical_authority=False " +
    "receipt=$receiptPath"
)
