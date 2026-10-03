#requires -Version 7.0

# Source-only reproducible runtime recipe for QSDK-R23D3. Dot-sourcing this
# file performs no build. The supervisor supplies the already verified clean,
# pushed source commit; its commit timestamp becomes SOURCE_DATE_EPOCH.

function Invoke-SporeSporeR23D3PinnedCargo {
    param(
        [Parameter(Mandatory)][string]$RepoRoot,
        [Parameter(Mandatory)][string]$SourceCommit,
        [Parameter(Mandatory)][string[]]$CargoArguments,
        [string]$TargetRoot = "",
        [string]$SourceAuthorityRepoRoot = ""
    )
    $resolvedRepo = [IO.Path]::GetFullPath($RepoRoot)
    $resolvedSourceAuthority = if ([string]::IsNullOrWhiteSpace(
        $SourceAuthorityRepoRoot
    )) {
        $resolvedRepo
    } else {
        [IO.Path]::GetFullPath($SourceAuthorityRepoRoot)
    }
    if ($SourceCommit -cnotmatch '^[0-9a-f]{40}$') {
        throw "QSDK-R23D3 source commit must be 40 lowercase hexadecimal characters"
    }
    $cargoHome = [IO.Path]::GetFullPath((Join-Path $env:USERPROFILE ".cargo"))
    $rustSysrootLines = @(& rustc --print sysroot 2>&1)
    if ($LASTEXITCODE -ne 0) {
        throw (
            "QSDK-R23D3 could not resolve the pinned Rust sysroot: " +
            ($rustSysrootLines -join ' ')
        )
    }
    $rustSysroot = ($rustSysrootLines -join "`n").Trim()
    $sourceEpochLines = @(
        & git -C $resolvedSourceAuthority show -s --format=%ct $SourceCommit 2>&1
    )
    if ($LASTEXITCODE -ne 0 -or
        ($sourceEpochLines -join "`n").Trim() -notmatch '^\d+$') {
        throw "QSDK-R23D3 could not resolve the verified source epoch"
    }
    $sourceEpoch = ($sourceEpochLines -join "`n").Trim()
    $resolvedTargetRoot = if ([string]::IsNullOrWhiteSpace($TargetRoot)) {
        ""
    } else {
        [IO.Path]::GetFullPath($TargetRoot)
    }
    $flags = @(
        "--remap-path-prefix=$resolvedRepo=/sporespore",
        "--remap-path-prefix=$cargoHome=/cargo-home",
        "--remap-path-prefix=$rustSysroot=/rust-sysroot",
        "-Clink-arg=/Brepro",
        "-Clink-arg=/PDBALTPATH:%_PDB%"
    )
    if (-not [string]::IsNullOrWhiteSpace($resolvedTargetRoot)) {
        # Last matching remap wins. Keep the nested target-root mapping after
        # the repository mapping so two arbitrary build roots project to the
        # same virtual path.
        $flags += "--remap-path-prefix=$resolvedTargetRoot=/sporespore-target"
    }
    $values = [ordered]@{
        CARGO_INCREMENTAL = "0"
        SOURCE_DATE_EPOCH = $sourceEpoch
        CARGO_ENCODED_RUSTFLAGS = ($flags -join [char]0x1f)
        RUSTFLAGS = ""
    }
    if (-not [string]::IsNullOrWhiteSpace($resolvedTargetRoot)) {
        $values.CARGO_TARGET_DIR = $resolvedTargetRoot
    }
    $prior = @{}
    $processEnvironment = [Environment]::GetEnvironmentVariables(
        [EnvironmentVariableTarget]::Process
    )
    foreach ($name in $values.Keys) {
        $prior[$name] = [ordered]@{
            existed = $processEnvironment.Contains([string]$name)
            value = [Environment]::GetEnvironmentVariable(
                [string]$name,
                [EnvironmentVariableTarget]::Process
            )
        }
        [Environment]::SetEnvironmentVariable(
            [string]$name,
            [string]$values[$name],
            [EnvironmentVariableTarget]::Process
        )
    }
    try {
        $lines = @(& cargo @CargoArguments 2>&1)
        $exitCode = $LASTEXITCODE
        if ($exitCode -ne 0) {
            throw (
                "QSDK-R23D3 pinned Cargo command failed with exit code " +
                "$exitCode`: cargo $($CargoArguments -join ' ')`n" +
                ($lines -join [Environment]::NewLine)
            )
        }
        return [ordered]@{
            exit_code = 0
            output = $lines
            source_commit = $SourceCommit
            source_authority_repo_root = $resolvedSourceAuthority
            build_source_root = $resolvedRepo
            build_source_root_is_git_blob_materialization = (
                $resolvedRepo -cne $resolvedSourceAuthority
            )
            source_date_epoch = [long]$sourceEpoch
            cargo_incremental = $false
            remapped_path_count = if (
                [string]::IsNullOrWhiteSpace($resolvedTargetRoot)
            ) { 3 } else { 4 }
            cargo_target_root_remapped_to_constant_virtual_prefix = -not (
                [string]::IsNullOrWhiteSpace($resolvedTargetRoot)
            )
            msvc_brepro = $true
            pdb_alt_path_bare_name = $true
            codegen_units_forced = $false
        }
    } finally {
        foreach ($name in $values.Keys) {
            if ([bool]$prior[$name].existed) {
                [Environment]::SetEnvironmentVariable(
                    [string]$name,
                    [string]$prior[$name].value,
                    [EnvironmentVariableTarget]::Process
                )
            } else {
                [Environment]::SetEnvironmentVariable(
                    [string]$name,
                    [System.Management.Automation.Language.NullString]::Value,
                    [EnvironmentVariableTarget]::Process
                )
            }
        }
    }
}

function Initialize-SporeSporeR23D3AttemptRuntimeArtifacts {
    param(
        [Parameter(Mandatory)][string]$RepoRoot,
        [Parameter(Mandatory)][string]$SourceCommit,
        [string]$TargetRoot = ""
    )
    $resolvedRepo = [IO.Path]::GetFullPath($RepoRoot)
    $sdkRoot = Join-Path $resolvedRepo "sdk"
    $manifest = Join-Path $sdkRoot "Cargo.toml"
    $resolvedTargetRoot = if ([string]::IsNullOrWhiteSpace($TargetRoot)) {
        Join-Path $sdkRoot "target"
    } else {
        [IO.Path]::GetFullPath($TargetRoot)
    }
    $builds = [ordered]@{}
    $builds.locomotion_core = Invoke-SporeSporeR23D3PinnedCargo `
        -RepoRoot $resolvedRepo `
        -SourceCommit $SourceCommit `
        -TargetRoot $resolvedTargetRoot `
        -CargoArguments @(
            "build", "--quiet", "--release", "--locked", "--offline",
            "--manifest-path", $manifest,
            "--package", "sporespore-locomotion-core"
        )
    $builds.godot_adapter = Invoke-SporeSporeR23D3PinnedCargo `
        -RepoRoot $resolvedRepo `
        -SourceCommit $SourceCommit `
        -TargetRoot $resolvedTargetRoot `
        -CargoArguments @(
            "build", "--quiet", "--locked", "--offline",
            "--manifest-path", $manifest,
            "--package", "sporespore-godot-adapter"
        )
    $rapierManifest = Join-Path $sdkRoot "adapters\rapier\Cargo.toml"
    $builds.rapier_worker = Invoke-SporeSporeR23D3PinnedCargo `
        -RepoRoot $resolvedRepo `
        -SourceCommit $SourceCommit `
        -TargetRoot $resolvedTargetRoot `
        -CargoArguments @(
            "build", "--quiet", "--locked", "--offline",
            "--manifest-path", $rapierManifest,
            "--bin", "qsdk_r23d3_phase_balanced"
        )
    $artifacts = [ordered]@{
        locomotion_core = Join-Path $resolvedTargetRoot (
            "release\sporespore_locomotion_core.dll"
        )
        godot_adapter = Join-Path $resolvedTargetRoot (
            "debug\sporespore_godot_adapter.dll"
        )
        rapier_worker = Join-Path $resolvedTargetRoot (
            "debug\qsdk_r23d3_phase_balanced.exe"
        )
    }
    foreach ($artifact in $artifacts.Values) {
        if (-not (Test-Path -LiteralPath $artifact -PathType Leaf)) {
            throw "QSDK-R23D3 materialized runtime artifact is missing: $artifact"
        }
    }
    return [ordered]@{
        builds = $builds
        artifacts = $artifacts
        source_commit = $SourceCommit
        target_root = $resolvedTargetRoot
        physical_acceptance_authority = $false
    }
}
