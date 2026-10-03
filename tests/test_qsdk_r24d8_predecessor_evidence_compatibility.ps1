#requires -Version 7.0

[CmdletBinding()]
param(
    [string]$GodotRepositoryRoot = (
        "C:\Users\Cole\CodeStuff\dependencies\godot-sporespore-4.7"
    ),
    [string]$ScratchRoot = ""
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$expectedRepoRoot = "C:\Users\Cole\CodeStuff\games\SporeSpore"
$expectedRepoRemote = "https://github.com/Slagathore/sporespore.git"
$expectedGodotRoot = (
    "C:\Users\Cole\CodeStuff\dependencies\godot-sporespore-4.7"
)
$expectedGodotRemote = "https://github.com/godotengine/godot.git"
$expectedGodotCommit = "5b4e0cb0fd279832bbdd69fed5354d4e5ad26f88"
$expectedEvidenceRoot = (
    "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence"
)
$closureRelative = (
    "sdk/recovery/" +
    "r24d7_godot_jolt_one_hinge_telemetry_physical_failure_closure_v1.json"
)
$historicalAuditRelative = (
    "tests/test_qsdk_r24d7_one_hinge_telemetry_physical_failure_closure.ps1"
)
$expectedClosureHash = (
    "6a71d1051bea9d1b47cb6b4b9ecc5550ef38e0f49cde2495f1815e5f83b27702"
)
$expectedHistoricalAuditHash = (
    "f715f3a9e44abcd660db4fb0900c921c39b7de6bac5e0fd3d3b3167cff288cb3"
)
$historicalMarkerPrefix = "QSDK_R24D7_PHYSICAL_FAILURE_CLOSURE_PASS "

function Assert-R24D8PredecessorCompatibility {
    param([bool]$Condition, [string]$Code)
    if (-not $Condition) {
        throw "QSDK-R24D8 predecessor evidence compatibility: $Code"
    }
}

function Get-R24D8CompatibilitySha256 {
    param([Parameter(Mandatory)][string]$Path)
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).
        Hash.ToLowerInvariant()
}

function Invoke-R24D8CompatibilityGit {
    param(
        [Parameter(Mandatory)][string]$Root,
        [Parameter(Mandatory)][string[]]$Arguments,
        [Parameter(Mandatory)][string]$Code
    )
    $output = @(& git -C $Root @Arguments 2>&1)
    Assert-R24D8PredecessorCompatibility ($LASTEXITCODE -eq 0) (
        "$Code`:$($output -join '|')"
    )
    return @($output)
}

$repoTop = @(
    Invoke-R24D8CompatibilityGit `
        -Root $repoRoot `
        -Arguments @("rev-parse", "--show-toplevel") `
        -Code "repository_top"
)[0].ToString().Trim()
$repoRemote = @(
    Invoke-R24D8CompatibilityGit `
        -Root $repoRoot `
        -Arguments @("remote", "get-url", "origin") `
        -Code "repository_remote"
)[0].ToString().Trim()
Assert-R24D8PredecessorCompatibility (
    [IO.Path]::GetFullPath($repoTop) -ceq $expectedRepoRoot -and
    $repoRoot -ceq $expectedRepoRoot -and
    $repoRemote -ceq $expectedRepoRemote
) "repository_identity"

$godotRoot = [IO.Path]::GetFullPath($GodotRepositoryRoot)
Assert-R24D8PredecessorCompatibility (
    $godotRoot -ceq $expectedGodotRoot
) "godot_repository_substitution_forbidden"
$godotTop = @(
    Invoke-R24D8CompatibilityGit `
        -Root $godotRoot `
        -Arguments @("rev-parse", "--show-toplevel") `
        -Code "godot_top"
)[0].ToString().Trim()
$godotRemote = @(
    Invoke-R24D8CompatibilityGit `
        -Root $godotRoot `
        -Arguments @("remote", "get-url", "origin") `
        -Code "godot_remote"
)[0].ToString().Trim()
$godotHead = @(
    Invoke-R24D8CompatibilityGit `
        -Root $godotRoot `
        -Arguments @("rev-parse", "HEAD") `
        -Code "godot_head"
)[0].ToString().Trim()
Assert-R24D8PredecessorCompatibility (
    [IO.Path]::GetFullPath($godotTop) -ceq $expectedGodotRoot -and
    $godotRemote -ceq $expectedGodotRemote -and
    $godotHead -ceq $expectedGodotCommit
) "godot_repository_identity"

$closurePath = [IO.Path]::GetFullPath((Join-Path $repoRoot $closureRelative))
$historicalAuditPath = [IO.Path]::GetFullPath(
    (Join-Path $repoRoot $historicalAuditRelative)
)
Assert-R24D8PredecessorCompatibility (
    (Test-Path -LiteralPath $closurePath -PathType Leaf) -and
    (Test-Path -LiteralPath $historicalAuditPath -PathType Leaf) -and
    (Get-R24D8CompatibilitySha256 $closurePath) -ceq $expectedClosureHash -and
    (Get-R24D8CompatibilitySha256 $historicalAuditPath) -ceq
        $expectedHistoricalAuditHash
) "immutable_r24d7_authority_bytes"

$closure = Get-Content -Raw -LiteralPath $closurePath |
    ConvertFrom-Json -AsHashtable -Depth 100
$patchBinding = [hashtable]$closure.diagnosis.instrumentation_patch
$patchPath = [IO.Path]::GetFullPath(
    (Join-Path $repoRoot ([string]$patchBinding.path))
)
Assert-R24D8PredecessorCompatibility (
    [string]$closure.schema_version -ceq
        "sporespore_qsdk_r24d7_one_hinge_telemetry_physical_failure_closure_v1" -and
    [string]$closure.closure_id -ceq "QSDK-R24D7-PH1-CLOSURE" -and
    [string]$closure.status -ceq
        "zero_world_passed_physical_attempt_implementation_invalid_callback_outside_stepping_window" -and
    [string]$closure.runtime.godot_source_commit -ceq $expectedGodotCommit -and
    [string]$patchBinding.raw_sha256 -ceq
        "sha256:$(Get-R24D8CompatibilitySha256 $patchPath)" -and
    [long]$patchBinding.byte_length -eq
        (Get-Item -LiteralPath $patchPath).Length
) "r24d7_historical_source_binding"

$patchPaths = @(
    & git -C $repoRoot apply --numstat -- $patchPath 2>&1 |
        ForEach-Object {
            $parts = ([string]$_) -split "`t"
            if ($parts.Count -eq 3) { $parts[2].Replace("\", "/") }
        }
)
Assert-R24D8PredecessorCompatibility (
    $LASTEXITCODE -eq 0 -and
    $patchPaths.Count -eq 7 -and
    @($patchPaths | Sort-Object -Unique).Count -eq 7
) "r24d7_patch_path_inventory"
$sparsePaths = @(
    $patchPaths +
    @($closure.diagnosis.pinned_upstream_source_bindings | ForEach-Object {
        [string]$_.path
    }) |
    Sort-Object -Unique
)
Assert-R24D8PredecessorCompatibility (
    $sparsePaths.Count -eq 10
) "historical_sparse_path_count"

$scratchBase = [IO.Path]::GetFullPath(
    (Join-Path $expectedEvidenceRoot "qualification-scratch")
)
if ([string]::IsNullOrWhiteSpace($ScratchRoot)) {
    $ScratchRoot = Join-Path $scratchBase (
        "r24d8-r24d7-$PID-$([Guid]::NewGuid().ToString('N'))"
    )
}
$historicalSourceRoot = [IO.Path]::GetFullPath($ScratchRoot)
Assert-R24D8PredecessorCompatibility (
    $historicalSourceRoot.StartsWith(
        $scratchBase + [IO.Path]::DirectorySeparatorChar,
        [StringComparison]::OrdinalIgnoreCase
    ) -and
    -not (Test-Path -LiteralPath $historicalSourceRoot)
) "historical_source_scratch_boundary"
[void][IO.Directory]::CreateDirectory($scratchBase)

$worktreeAdded = $false
$historicalAuditReceipt = $null
$historicalAuditOutput = @()
$worktreeCountBefore = @(
    & git -C $godotRoot worktree list --porcelain |
        Where-Object { ([string]$_).StartsWith("worktree ") }
).Count
Assert-R24D8PredecessorCompatibility (
    $LASTEXITCODE -eq 0 -and $worktreeCountBefore -ge 1
) "godot_worktree_inventory_before"

try {
    [void](Invoke-R24D8CompatibilityGit `
        -Root $godotRoot `
        -Arguments @(
            "worktree", "add", "--detach", "--no-checkout",
            $historicalSourceRoot, $expectedGodotCommit
        ) `
        -Code "historical_worktree_add")
    $worktreeAdded = $true

    [void](Invoke-R24D8CompatibilityGit `
        -Root $historicalSourceRoot `
        -Arguments (@("sparse-checkout", "set", "--no-cone") + $sparsePaths) `
        -Code "historical_sparse_checkout")
    [void](Invoke-R24D8CompatibilityGit `
        -Root $historicalSourceRoot `
        -Arguments @("checkout", "--force", $expectedGodotCommit) `
        -Code "historical_checkout")
    [void](Invoke-R24D8CompatibilityGit `
        -Root $historicalSourceRoot `
        -Arguments @("apply", "--whitespace=nowarn", "--", $patchPath) `
        -Code "historical_patch_apply")

    # Cole's global Windows checkout policy materializes CRLF even though the
    # historical R24D7 external source observation was retained as raw LF.
    # Normalize only the seven generated patch targets inside this disposable
    # historical view. Git blob identity alone is insufficient here because
    # the immutable audit also binds the exact raw working-tree bytes.
    $normalizedCrLfFileCount = 0
    foreach ($relative in $patchPaths) {
        $generatedPath = Join-Path $historicalSourceRoot $relative
        $generatedText = [IO.File]::ReadAllText($generatedPath)
        if ($generatedText.Contains("`r`n", [StringComparison]::Ordinal)) {
            [IO.File]::WriteAllText(
                $generatedPath,
                $generatedText.Replace("`r`n", "`n"),
                [Text.UTF8Encoding]::new($false)
            )
            $normalizedCrLfFileCount += 1
        }
    }
    Assert-R24D8PredecessorCompatibility (
        $normalizedCrLfFileCount -eq 7
    ) "historical_raw_lf_projection_count"

    $historicalStatus = @(
        & git -C $historicalSourceRoot status --short 2>&1
    )
    Assert-R24D8PredecessorCompatibility ($LASTEXITCODE -eq 0) (
        "historical_status:$($historicalStatus -join '|')"
    )
    $historicalStatusPaths = @($historicalStatus | ForEach-Object {
        ([string]$_).Substring(3).Replace("\", "/")
    })
    Assert-R24D8PredecessorCompatibility (
        (($historicalStatusPaths | Sort-Object) -join "|") -ceq
        (($patchPaths | Sort-Object) -join "|")
    ) "historical_patch_exact_path_set"

    $patchedServer = [hashtable]$closure.diagnosis.patched_server_live_source
    $patchedServerPath = Join-Path $historicalSourceRoot ([string]$patchedServer.path)
    $patchedServerHash = Get-R24D8CompatibilitySha256 $patchedServerPath
    $patchedServerBytes = (Get-Item -LiteralPath $patchedServerPath).Length
    $patchedServerBlob = @(
        Invoke-R24D8CompatibilityGit `
            -Root $historicalSourceRoot `
            -Arguments @("hash-object", "--", $patchedServerPath) `
            -Code "historical_patched_server_blob"
    )[0].ToString().Trim()
    Assert-R24D8PredecessorCompatibility (
        "sha256:$patchedServerHash" -ceq [string]$patchedServer.raw_sha256 -and
        $patchedServerBytes -eq [long]$patchedServer.byte_length -and
        $patchedServerBlob -ceq [string]$patchedServer.git_blob_oid
    ) (
        "historical_patched_server_identity:" +
        "hash=$patchedServerHash;bytes=$patchedServerBytes;blob=$patchedServerBlob"
    )

    $pwsh = (Get-Command -Name "pwsh" -CommandType Application |
        Select-Object -First 1).Source
    $historicalAuditOutput = @(
        & $pwsh -NoLogo -NoProfile -File $historicalAuditPath `
            -GodotSourceRoot $historicalSourceRoot 2>&1
    )
    Assert-R24D8PredecessorCompatibility ($LASTEXITCODE -eq 0) (
        "historical_audit_exit:$($historicalAuditOutput -join '|')"
    )
    $markers = @($historicalAuditOutput | Where-Object {
        ([string]$_).StartsWith(
            $historicalMarkerPrefix,
            [StringComparison]::Ordinal
        )
    })
    Assert-R24D8PredecessorCompatibility (
        $markers.Count -eq 1
    ) "historical_audit_marker_count"
    $historicalAuditReceipt = ([string]$markers[0]).Substring(
        $historicalMarkerPrefix.Length
    ) | ConvertFrom-Json -AsHashtable -Depth 100
    Assert-R24D8PredecessorCompatibility (
        [bool]$historicalAuditReceipt.ok -and
        [string]$historicalAuditReceipt.closure_id -ceq
            "QSDK-R24D7-PH1-CLOSURE" -and
        [bool]$historicalAuditReceipt.same_source_rerun_forbidden -and
        [bool]$historicalAuditReceipt.distinct_successor_required -and
        -not [bool]$historicalAuditReceipt.turning_claim_changed -and
        -not [bool]$historicalAuditReceipt.prone_to_standing_world_opened -and
        -not [bool]$historicalAuditReceipt.physical_acceptance_authority -and
        -not [bool]$historicalAuditReceipt.release_authority
    ) "historical_audit_receipt"
} finally {
    if ($worktreeAdded) {
        $removeOutput = @(
            & git -C $godotRoot worktree remove --force -- $historicalSourceRoot 2>&1
        )
        Assert-R24D8PredecessorCompatibility ($LASTEXITCODE -eq 0) (
            "historical_worktree_remove:$($removeOutput -join '|')"
        )
    }
}

Assert-R24D8PredecessorCompatibility (
    -not (Test-Path -LiteralPath $historicalSourceRoot)
) "historical_source_scratch_not_removed"
$worktreeCountAfter = @(
    & git -C $godotRoot worktree list --porcelain |
        Where-Object { ([string]$_).StartsWith("worktree ") }
).Count
Assert-R24D8PredecessorCompatibility (
    $LASTEXITCODE -eq 0 -and
    $worktreeCountAfter -eq $worktreeCountBefore
) "godot_worktree_inventory_after"

foreach ($line in $historicalAuditOutput) {
    Write-Output ([string]$line)
}
Write-Output (
    "QSDK_R24D8_PREDECESSOR_EVIDENCE_COMPATIBILITY_PASS " +
    ([ordered]@{
        ok = $true
        gate_id = "QSDK-R24D8"
        question_class = "non_physical_source_conformance"
        result = "immutable_r24d7_audit_passed_in_exact_historical_source_view"
        r24d7_closure_raw_sha256 = "sha256:$expectedClosureHash"
        r24d7_audit_raw_sha256 = "sha256:$expectedHistoricalAuditHash"
        godot_source_commit = $expectedGodotCommit
        historical_patch_raw_sha256 = [string]$patchBinding.raw_sha256
        historical_patch_file_count = $patchPaths.Count
        historical_raw_lf_projection_count = $normalizedCrLfFileCount
        historical_source_view_file_count = $sparsePaths.Count
        historical_source_view_removed = $true
        godot_worktree_count_before = $worktreeCountBefore
        godot_worktree_count_after = $worktreeCountAfter
        world_attempt_count = 0
        world_build_count = 0
        solver_step_count = 0
        physical_acceptance_authority = $false
        release_authority = $false
    } | ConvertTo-Json -Depth 30 -Compress)
)
