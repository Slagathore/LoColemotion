#requires -Version 7.0

# Source-only helper for QSDK-R23D2. It intentionally performs no work when
# dot-sourced; callers choose which frozen artifacts to materialize.

function Invoke-SporeSporeR23D2PinnedCargo {
    param(
        [Parameter(Mandatory)][string]$RepoRoot,
        [Parameter(Mandatory)][string[]]$CargoArguments,
        [string]$TargetRoot = ""
    )
    $resolvedRepo = [IO.Path]::GetFullPath($RepoRoot)
    $cargoHome = [IO.Path]::GetFullPath((Join-Path $env:USERPROFILE ".cargo"))
    $rustSysrootLines = @(& rustc --print sysroot 2>&1)
    if ($LASTEXITCODE -ne 0) {
        throw "QSDK-R23D2 could not resolve the pinned Rust sysroot: $($rustSysrootLines -join ' ')"
    }
    $rustSysroot = ($rustSysrootLines -join "`n").Trim()
    $sourceCommit = "d9303df0e16dbbbdb35983f9632b5cfd0ff3061f"
    $sourceEpochLines = @(
        & git -C $resolvedRepo show -s --format=%ct $sourceCommit 2>&1
    )
    if ($LASTEXITCODE -ne 0 -or
        ($sourceEpochLines -join "`n").Trim() -notmatch '^\d+$') {
        throw "QSDK-R23D2 could not resolve the stage-zero source epoch"
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
        # rustc gives the last matching remap precedence. Keep this nested
        # target-root mapping after the broader repository mapping.
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
                "QSDK-R23D2 pinned Cargo command failed with exit code " +
                "$exitCode`: cargo $($CargoArguments -join ' ')`n" +
                ($lines -join [Environment]::NewLine)
            )
        }
        return [ordered]@{
            exit_code = 0
            output = $lines
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

function Initialize-SporeSporeR23D2AttemptRuntimeArtifacts {
    param(
        [Parameter(Mandatory)][string]$RepoRoot,
        [string]$TargetRoot = ""
    )
    $resolvedRepo = [IO.Path]::GetFullPath($RepoRoot)
    $sdkRoot = Join-Path $resolvedRepo "sdk"
    $manifest = Join-Path $sdkRoot "Cargo.toml"
    $resolvedTargetRoot = if ([string]::IsNullOrWhiteSpace($TargetRoot)) {
        Join-Path $sdkRoot "target"
    } else { [IO.Path]::GetFullPath($TargetRoot) }
    $builds = [ordered]@{}
    $builds.locomotion_core = Invoke-SporeSporeR23D2PinnedCargo `
        -RepoRoot $resolvedRepo `
        -TargetRoot $resolvedTargetRoot `
        -CargoArguments @(
            "build", "--quiet", "--release", "--locked", "--offline",
            "--manifest-path", $manifest,
            "--package", "sporespore-locomotion-core"
        )
    $builds.godot_adapter = Invoke-SporeSporeR23D2PinnedCargo `
        -RepoRoot $resolvedRepo `
        -TargetRoot $resolvedTargetRoot `
        -CargoArguments @(
            "build", "--quiet", "--locked", "--offline",
            "--manifest-path", $manifest,
            "--package", "sporespore-godot-adapter"
        )
    $rapierManifest = Join-Path $sdkRoot "adapters\rapier\Cargo.toml"
    $builds.rapier_worker = Invoke-SporeSporeR23D2PinnedCargo `
        -RepoRoot $resolvedRepo `
        -TargetRoot $resolvedTargetRoot `
        -CargoArguments @(
            "build", "--quiet", "--locked", "--offline",
            "--manifest-path", $rapierManifest,
            "--bin", "qsdk_r23d2_heading_response"
        )
    foreach ($artifact in @(
        (Join-Path $resolvedTargetRoot "release\sporespore_locomotion_core.dll"),
        (Join-Path $resolvedTargetRoot "debug\sporespore_godot_adapter.dll"),
        (Join-Path $resolvedTargetRoot "debug\qsdk_r23d2_heading_response.exe")
    )) {
        if (-not (Test-Path -LiteralPath $artifact -PathType Leaf)) {
            throw "QSDK-R23D2 materialized runtime artifact is missing: $artifact"
        }
    }
    return $builds
}
