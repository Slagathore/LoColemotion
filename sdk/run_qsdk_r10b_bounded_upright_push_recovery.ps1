#requires -Version 7.0

[CmdletBinding()]
param(
    [ValidateSet("ZeroWorld", "AuthorityCheck", "Physical")]
    [string]$Mode = "ZeroWorld",
    [ValidateSet("development_route_ghost", "held_out_finite_decision")]
    [string]$CampaignRole = "development_route_ghost",
    [string]$Godot = (
        "C:\Users\Cole\CodeStuff\Misc\Godot\" +
        "Godot_v4.7-stable_mono_win64_console.exe"
    ),
    [string]$StageFreeze = "",
    [string]$ExecutionAuthority = "",
    [string]$Output = "",
    [ValidateRange(60, 1200)]
    [int]$CellTimeoutSeconds = 600
)

$ErrorActionPreference = "Stop"
$repoRoot = [System.IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$sdkRoot = [System.IO.Path]::GetFullPath($PSScriptRoot)
$godotPath = [System.IO.Path]::GetFullPath($Godot)
$expectedRemote = "https://github.com/Slagathore/sporespore.git"
$worker = "res://tests/test_sdk_qsdk_r10b_bounded_upright_push_recovery_worker.gd"
$sourceTest = "res://tests/test_sdk_qsdk_r10b_bounded_upright_push_recovery_source.gd"
$sourceMarker = "QSDK_R10B_BOUNDED_UPRIGHT_PUSH_RECOVERY_SOURCE_ZERO_WORLD "
$contractMarker = "QSDK_R10B_WORKER_CONTRACT_ZERO_WORLD "
$preflightMarker = "QSDK_R10B_WORKER_ENTRYPOINT_ZERO_WORLD "
$cellMarker = "QSDK_R10B_PHYSICAL_CELL "
$pairMarker = "QSDK_R10B_PAIR_EVALUATION_ZERO_WORLD "
$designSha256 = "sha256:f5738803e65d25b3225c0b054ced5f21613650f2a5aa1d79e76b700ad7d36f66"
$l2SuccessorDesignSha256 = "sha256:5acc66edbc274616898b25ede236207ff77ca92e596ffbf171472ca9dfc7a478"
$l3SuccessorDesignSha256 = "sha256:ad8d147ee5a508aee3104fb346dcedde692568a9f9093a73e3bdbca638901f76"
$consumedL1PhysicalInvalidClosureSha256 = "sha256:b9f8304e229d1a897137bafcce51ee6089b11b15742f624ccf38d202b8fe35a1"
$consumedL2PhysicalInvalidClosureSha256 = "sha256:5f6242e2cab9658a54c673717596c7649fac785136d29d8798192bfc0f60babb"
$attemptSchema = "sporespore_qsdk_r10b_physical_attempt_v4"
$authoritySchema = "sporespore_qsdk_r10b_execution_authority_v4"
$stageFreezeSchema = "sporespore_qsdk_r10b_stage_freeze_v4"
$qualifiedSourcePathCount = 85
$qualifiedSourcePathSha256 = "sha256:4bfe0e8a7cbdb920655cb3082b6e2a7182f4f05ac76e24142a73acca640a7a8d"
$campaign = if ($CampaignRole -ceq "development_route_ghost") {
    [ordered]@{
        id = "QSDK-R10B-BOUNDED-UPRIGHT-PUSH-RECOVERY-ROUTE-GHOST"
        question_class = "development"
        seeds = @(50300)
        maximum_world_count = 2
        operation_role = "physical_development"
    }
} else {
    [ordered]@{
        id = "QSDK-R10B-BOUNDED-UPRIGHT-PUSH-RECOVERY-VALIDATION"
        question_class = "finite decision"
        seeds = @(50301, 50302, 50303)
        maximum_world_count = 6
        operation_role = "physical"
    }
}
$armOrder = @("matched_no_impulse_control", "lateral_upright_impulse")
$stageFreezeRelativePath = if ($CampaignRole -ceq "development_route_ghost") {
    "sdk/qsdk_r10b_development_route_ghost_zero_world_qualification_closure_v4.json"
} else {
    "sdk/qsdk_r10b_held_out_finite_decision_zero_world_qualification_closure_v4.json"
}
$executionAuthorityRelativePath = if ($CampaignRole -ceq "development_route_ghost") {
    "sdk/qsdk_r10b_development_route_ghost_execution_authority_v4.json"
} else {
    "sdk/qsdk_r10b_held_out_finite_decision_execution_authority_v4.json"
}
$authorityCheckRefusalRelativePath = (
    "sdk/qsdk_r10b_development_route_ghost_authority_check_refusal_v1.json"
)
$l1PhysicalInvalidClosureRelativePath = (
    "sdk/qsdk_r10b_l1_development_route_ghost_physical_invalid_closure_v1.json"
)
$l2PhysicalInvalidClosureRelativePath = (
    "sdk/qsdk_r10b_l2_development_route_ghost_physical_invalid_closure_v1.json"
)
$evidenceRoot = [System.IO.Path]::GetFullPath(
    "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence"
)
$operationLockPath = Join-Path $sdkRoot "locomotion_operation_lock.ps1"
if (-not (Test-Path -LiteralPath $godotPath -PathType Leaf)) {
    throw "Godot executable is missing: $godotPath"
}
if (-not (Test-Path -LiteralPath $operationLockPath -PathType Leaf)) {
    throw "The shared locomotion operation lock is missing"
}
. $operationLockPath

function Write-Utf8NoBom {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][AllowEmptyString()][string]$Text
    )
    [System.IO.File]::WriteAllText(
        $Path,
        $Text,
        [System.Text.UTF8Encoding]::new($false)
    )
}

function Get-PrefixedSha256 {
    param([Parameter(Mandatory)][string]$Path)
    return "sha256:" + (
        Get-FileHash -LiteralPath $Path -Algorithm SHA256
    ).Hash.ToLowerInvariant()
}

function Get-TextSha256 {
    param([Parameter(Mandatory)][AllowEmptyString()][string]$Text)
    $bytes = [Text.UTF8Encoding]::new($false).GetBytes($Text)
    $digest = [Security.Cryptography.SHA256]::HashData($bytes)
    return "sha256:" + [Convert]::ToHexString($digest).ToLowerInvariant()
}

function Get-GitText {
    param(
        [Parameter(Mandatory)][string[]]$Arguments,
        [Parameter(Mandatory)][string]$Label,
        [switch]$AllowEmpty
    )
    $lines = @(& git -C $repoRoot @Arguments 2>&1)
    if ($LASTEXITCODE -ne 0) {
        throw "QSDK-R10B Git check failed: $Label"
    }
    $value = (($lines | ForEach-Object { [string]$_ }) -join "`n").Trim()
    if (-not $AllowEmpty -and [string]::IsNullOrWhiteSpace($value)) {
        throw "QSDK-R10B Git check was empty: $Label"
    }
    return $value
}

function Test-LowerHex {
    param([string]$Value, [int]$Length)
    return $Value.Length -eq $Length -and $Value -cmatch "^[0-9a-f]+$"
}

function Test-ExactStringArray {
    param([object[]]$Actual, [string[]]$Expected)
    if ($Actual.Count -ne $Expected.Count) { return $false }
    for ($index = 0; $index -lt $Expected.Count; $index++) {
        if ([string]$Actual[$index] -cne $Expected[$index]) { return $false }
    }
    return $true
}

function Test-StrictOrdinalStringOrder {
    param([object[]]$Values)
    for ($index = 1; $index -lt $Values.Count; $index++) {
        if (
            [StringComparer]::Ordinal.Compare(
                [string]$Values[$index - 1],
                [string]$Values[$index]
            ) -ge 0
        ) {
            return $false
        }
    }
    return $true
}

function Get-CellId {
    param([string]$ArmId, [int]$Seed)
    $prefix = if ($ArmId -ceq "matched_no_impulse_control") {
        "baseline"
    } else { "push" }
    return "${prefix}_s${Seed}"
}

function Get-OrderedCellIds {
    $ids = [System.Collections.Generic.List[string]]::new()
    foreach ($seed in $campaign.seeds) {
        foreach ($arm in $armOrder) {
            $ids.Add((Get-CellId -ArmId $arm -Seed ([int]$seed)))
        }
    }
    return @($ids)
}

function Invoke-GodotCaptured {
    param(
        [Parameter(Mandatory)][string[]]$Arguments,
        [Parameter(Mandatory)][string]$WorkerRoot,
        [Parameter(Mandatory)][int]$TimeoutSeconds,
        [hashtable]$AdditionalEnvironment = @{}
    )
    $appData = Join-Path $WorkerRoot "appdata"
    $localAppData = Join-Path $WorkerRoot "localappdata"
    [void][System.IO.Directory]::CreateDirectory($appData)
    [void][System.IO.Directory]::CreateDirectory($localAppData)
    $start = [System.Diagnostics.ProcessStartInfo]::new()
    $start.FileName = $godotPath
    $start.WorkingDirectory = $repoRoot
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    $start.Environment["APPDATA"] = $appData
    $start.Environment["LOCALAPPDATA"] = $localAppData
    foreach ($name in $AdditionalEnvironment.Keys) {
        $start.Environment[[string]$name] = [string]$AdditionalEnvironment[$name]
    }
    foreach ($argument in $Arguments) {
        [void]$start.ArgumentList.Add($argument)
    }
    $process = [System.Diagnostics.Process]::new()
    $process.StartInfo = $start
    $startedUtc = [DateTime]::UtcNow
    if (-not $process.Start()) { throw "Failed to start Godot" }
    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()
    $timedOut = -not $process.WaitForExit($TimeoutSeconds * 1000)
    $killedTree = $false
    if ($timedOut) {
        try {
            $process.Kill($true)
            $killedTree = $true
        } catch {
            $killedTree = $false
        }
        [void]$process.WaitForExit(10000)
    }
    $stdout = $stdoutTask.GetAwaiter().GetResult()
    $stderr = $stderrTask.GetAwaiter().GetResult()
    $exitCode = if ($process.HasExited) { $process.ExitCode } else { -1 }
    $process.Dispose()
    return [ordered]@{
        exit_code = $exitCode
        timed_out = $timedOut
        killed_process_tree = $killedTree
        started_utc = $startedUtc.ToString("o")
        completed_utc = [DateTime]::UtcNow.ToString("o")
        stdout = $stdout
        stderr = $stderr
    }
}

function Get-SingleMarkerJson {
    param(
        [Parameter(Mandatory)][string]$Stdout,
        [Parameter(Mandatory)][string]$Marker
    )
    $lines = @(
        $Stdout -split "`r?`n" |
            Where-Object { $_.StartsWith($Marker, [StringComparison]::Ordinal) }
    )
    if ($lines.Count -ne 1) {
        throw "Expected one '$Marker' line; observed $($lines.Count)"
    }
    return (
        $lines[0].Substring($Marker.Length) |
            ConvertFrom-Json -AsHashtable -Depth 100
    )
}

function Assert-ZeroWorldReceipt {
    param([hashtable]$Receipt, [string]$Label)
    $exact = (
        [bool]$Receipt.ok -and
        [int]$Receipt.model_construction_count -eq 0 -and
        [int]$Receipt.world_attempt_count -eq 0 -and
        [int]$Receipt.world_build_count -eq 0 -and
        [int]$Receipt.scene_tree_insertion_count -eq 0 -and
        [int]$Receipt.native_readback_count -eq 0 -and
        [int]$Receipt.solver_step_count -eq 0 -and
        -not [bool]$Receipt.physics_state_modified -and
        -not [bool]$Receipt.physical_acceptance_authority
    )
    if (-not $exact) {
        throw "$Label did not remain an exact zero-world receipt"
    }
}

function Invoke-ZeroWorldMode {
    param([string]$TempRoot)
    $ordinalPathOrderControlPassed = (
        (Test-StrictOrdinalStringOrder -Values @(
            "sdk/Cargo.lock",
            "sdk/adapters/godot/Cargo.toml"
        )) -and
        -not (Test-StrictOrdinalStringOrder -Values @(
            "sdk/adapters/godot/Cargo.toml",
            "sdk/Cargo.lock"
        )) -and
        -not (Test-StrictOrdinalStringOrder -Values @(
            "sdk/Cargo.lock",
            "sdk/Cargo.lock"
        ))
    )
    if (-not $ordinalPathOrderControlPassed) {
        throw "R10B strict ordinal source-path ordering controls failed"
    }
    $source = Invoke-GodotCaptured -Arguments @(
        "--headless", "--path", $repoRoot, "--script", $sourceTest
    ) -WorkerRoot (Join-Path $TempRoot "source") -TimeoutSeconds 120
    if ($source.exit_code -ne 0 -or $source.timed_out) {
        throw "R10B source gate failed: $($source.stderr)"
    }
    $sourceReceipt = Get-SingleMarkerJson -Stdout $source.stdout -Marker $sourceMarker
    Assert-ZeroWorldReceipt -Receipt $sourceReceipt -Label "source gate"

    $contract = Invoke-GodotCaptured -Arguments @(
        "--headless", "--path", $repoRoot, "--script", $worker, "--", "contract"
    ) -WorkerRoot (Join-Path $TempRoot "contract") -TimeoutSeconds 120
    if ($contract.exit_code -ne 0 -or $contract.timed_out) {
        throw "R10B worker contract failed: $($contract.stderr)"
    }
    $contractReceipt = Get-SingleMarkerJson -Stdout $contract.stdout -Marker $contractMarker
    Assert-ZeroWorldReceipt -Receipt $contractReceipt -Label "worker contract"

    $preflightReceipts = [System.Collections.Generic.List[object]]::new()
    foreach ($role in @("development_route_ghost", "held_out_finite_decision")) {
        $preflight = Invoke-GodotCaptured -Arguments @(
            "--headless", "--path", $repoRoot, "--script", $worker,
            "--", "preflight", $role
        ) -WorkerRoot (Join-Path $TempRoot "preflight-$role") -TimeoutSeconds 120
        if ($preflight.exit_code -ne 0 -or $preflight.timed_out) {
            throw "R10B $role entrypoint preflight failed: $($preflight.stderr)"
        }
        $receipt = Get-SingleMarkerJson -Stdout $preflight.stdout -Marker $preflightMarker
        Assert-ZeroWorldReceipt -Receipt $receipt -Label "$role entrypoint preflight"
        $preflightReceipts.Add($receipt)
    }

    $bypass = Invoke-GodotCaptured -Arguments @(
        "--headless", "--path", $repoRoot, "--script", $worker,
        "--", "physical", "development_route_ghost",
        "matched_no_impulse_control", "50300"
    ) -WorkerRoot (Join-Path $TempRoot "blocked-bypass") -TimeoutSeconds 120
    if ($bypass.exit_code -eq 0 -or $bypass.timed_out) {
        throw "The direct physical worker bypass was not refused"
    }
    $bypassReceipt = Get-SingleMarkerJson -Stdout $bypass.stdout -Marker $cellMarker
    if (
        [bool]$bypassReceipt.ok -or
        [string]$bypassReceipt.failure_code -cne "QSDK_R10B_PHYSICAL_AUTHORIZATION_REQUIRED" -or
        [int]$bypassReceipt.model_construction_count -ne 0 -or
        [int]$bypassReceipt.world_attempt_count -ne 0 -or
        [int]$bypassReceipt.world_build_count -ne 0 -or
        [int]$bypassReceipt.solver_step_count -ne 0
    ) {
        throw "The direct physical bypass refusal was not exact"
    }
    $receipt = [ordered]@{
        schema_version = "sporespore_qsdk_r10b_supervisor_zero_world_v4"
        gate_id = "QSDK-R10B"
        ok = $true
        failure_code = ""
        source_gate = $sourceReceipt
        worker_contract = $contractReceipt
        entrypoint_preflights = @($preflightReceipts)
        direct_physical_bypass_refused = $true
        ordinal_path_order_control_passed = $true
        ordinal_path_order_negative_control_count = 2
        physical_execution_authorized = $false
        locomotion_outcome_exposure_count = 0
        model_construction_count = 0
        world_attempt_count = 0
        world_build_count = 0
        scene_tree_insertion_count = 0
        native_readback_count = 0
        solver_step_count = 0
        physics_state_modified = $false
        physical_acceptance_authority = $false
    }
    Write-Output (
        "QSDK_R10B_SUPERVISOR_ZERO_WORLD_PASS " +
        ($receipt | ConvertTo-Json -Depth 100 -Compress)
    )
}

function Get-RepositoryIdentity {
    $top = Get-GitText -Arguments @("rev-parse", "--show-toplevel") -Label "root"
    $remote = Get-GitText -Arguments @("remote", "get-url", "origin") -Label "remote"
    $branch = Get-GitText -Arguments @("branch", "--show-current") -Label "branch"
    $status = Get-GitText -Arguments @(
        "status", "--porcelain=v1", "--untracked-files=all"
    ) -Label "status" -AllowEmpty
    $head = Get-GitText -Arguments @("rev-parse", "HEAD") -Label "HEAD"
    $parent = Get-GitText -Arguments @("rev-parse", "HEAD^") -Label "HEAD parent"
    $tree = Get-GitText -Arguments @("rev-parse", "HEAD^{tree}") -Label "HEAD tree"
    $origin = Get-GitText -Arguments @("rev-parse", "origin/main") -Label "origin/main"
    $liveLine = Get-GitText -Arguments @(
        "ls-remote", "origin", "refs/heads/main"
    ) -Label "live main"
    $liveParts = @($liveLine -split "\s+" | Where-Object { $_ })
    if ($liveParts.Count -ne 2 -or [string]$liveParts[1] -cne "refs/heads/main") {
        throw "Could not resolve live origin/main"
    }
    $live = [string]$liveParts[0]
    if (
        [System.IO.Path]::GetFullPath($top) -cne $repoRoot -or
        $remote -cne $expectedRemote -or
        $branch -cne "main" -or
        -not [string]::IsNullOrEmpty($status) -or
        -not (Test-LowerHex -Value $head -Length 40) -or
        -not (Test-LowerHex -Value $parent -Length 40) -or
        -not (Test-LowerHex -Value $tree -Length 40) -or
        $head -cne $origin -or
        $head -cne $live
    ) {
        throw "Physical source must be clean and equal to local, cached, and live main"
    }
    return [ordered]@{
        root = $repoRoot
        remote = $remote
        branch = $branch
        authorization_commit = $head
        authorization_parent_commit = $parent
        authorization_tree = $tree
        origin_main_commit = $origin
        live_main_commit = $live
        clean = $true
    }
}

function Get-QualifiedPhysicalAuthority {
    param([hashtable]$RepositoryIdentity)
    if (
        [string]::IsNullOrWhiteSpace($StageFreeze) -or
        [string]::IsNullOrWhiteSpace($ExecutionAuthority)
    ) {
        throw "Physical mode requires -StageFreeze and -ExecutionAuthority"
    }
    $freezePath = [System.IO.Path]::GetFullPath($StageFreeze)
    $authorityPath = [System.IO.Path]::GetFullPath($ExecutionAuthority)
    $expectedFreezePath = [System.IO.Path]::GetFullPath(
        (Join-Path $repoRoot $stageFreezeRelativePath)
    )
    $expectedAuthorityPath = [System.IO.Path]::GetFullPath(
        (Join-Path $repoRoot $executionAuthorityRelativePath)
    )
    if (
        $freezePath -cne $expectedFreezePath -or
        $authorityPath -cne $expectedAuthorityPath -or
        -not (Test-Path -LiteralPath $freezePath -PathType Leaf) -or
        -not (Test-Path -LiteralPath $authorityPath -PathType Leaf)
    ) {
        throw "The stage freeze or execution authority is missing"
    }
    $freeze = Get-Content -LiteralPath $freezePath -Raw |
        ConvertFrom-Json -AsHashtable -Depth 100
    $authority = Get-Content -LiteralPath $authorityPath -Raw |
        ConvertFrom-Json -AsHashtable -Depth 100
    $expectedCells = @(Get-OrderedCellIds)
    $sourceCommit = [string]$authority.source_commit
    $qualificationParentCommit = [string]$authority.qualification_parent_commit
    $qualificationCommit = [string]$authority.authorization_parent_commit
    $authorizationCommit = [string]$RepositoryIdentity.authorization_commit
    $qualificationCommitParent = if (Test-LowerHex -Value $qualificationCommit -Length 40) {
        Get-GitText -Arguments @("rev-parse", "$qualificationCommit^") `
            -Label "qualification parent"
    } else { "" }
    $qualificationChangedPaths = if (Test-LowerHex -Value $qualificationCommit -Length 40) {
        @(Get-GitText -Arguments @(
            "diff-tree", "--no-commit-id", "--name-only", "-r", $qualificationCommit
        ) -Label "qualification changed paths" -AllowEmpty) -split "`n"
    } else { @() }
    $authorizationChangedPaths = @(
        (Get-GitText -Arguments @(
            "diff-tree", "--no-commit-id", "--name-only", "-r", $authorizationCommit
        ) -Label "authorization changed paths" -AllowEmpty) -split "`n"
    )
    $stageFreezeBlob = if (Test-LowerHex -Value $qualificationCommit -Length 40) {
        Get-GitText -Arguments @(
            "rev-parse", "${qualificationCommit}:$stageFreezeRelativePath"
        ) -Label "qualification closure blob"
    } else { "" }
    $currentStageFreezeBlob = Get-GitText -Arguments @(
        "rev-parse", "${authorizationCommit}:$stageFreezeRelativePath"
    ) -Label "current qualification closure blob"
    $currentAuthorityBlob = Get-GitText -Arguments @(
        "rev-parse", "${authorizationCommit}:$executionAuthorityRelativePath"
    ) -Label "current execution authority blob"
    $authorityOutputRoot = [string]$authority.output_root
    $authorizedOutputPath = if ([string]::IsNullOrWhiteSpace($authorityOutputRoot)) {
        ""
    } else {
        [System.IO.Path]::GetFullPath($authorityOutputRoot)
    }
    $outputInsideEvidenceRoot = (
        -not [string]::IsNullOrWhiteSpace($authorizedOutputPath) -and
        $authorizedOutputPath.StartsWith(
            $evidenceRoot + [System.IO.Path]::DirectorySeparatorChar,
            [StringComparison]::OrdinalIgnoreCase
        )
    )
    $refusalBindingExact = $false
    $refusalBinding = $freeze.superseded_authority_check_refusal
    if ($refusalBinding -is [System.Collections.IDictionary]) {
        $refusalPath = [System.IO.Path]::GetFullPath(
            (Join-Path $repoRoot $authorityCheckRefusalRelativePath)
        )
        $refusalSourceBlob = Get-GitText -Arguments @(
            "rev-parse", "${sourceCommit}:$authorityCheckRefusalRelativePath"
        ) -Label "pre-physics authority refusal source binding"
        $refusalCurrentBlob = Get-GitText -Arguments @(
            "rev-parse", "${authorizationCommit}:$authorityCheckRefusalRelativePath"
        ) -Label "pre-physics authority refusal current binding"
        $refusalBindingExact = (
            [string]$refusalBinding.path -ceq $authorityCheckRefusalRelativePath -and
            [string]$refusalBinding.status -ceq "closed_infrastructure_invalid_pre_physics" -and
            [string]$refusalBinding.repair_id -ceq "QSDK-R10B-L1" -and
            -not [bool]$refusalBinding.physical_attempt_identity_consumed -and
            (Test-Path -LiteralPath $refusalPath -PathType Leaf) -and
            [int64]$refusalBinding.byte_length -eq [int64](Get-Item -LiteralPath $refusalPath).Length -and
            [string]$refusalBinding.raw_sha256 -ceq (Get-PrefixedSha256 $refusalPath) -and
            [string]$refusalBinding.git_blob_oid -ceq $refusalSourceBlob -and
            [string]$refusalBinding.git_blob_oid -ceq $refusalCurrentBlob
        )
    }
    $l1InvalidBindingExact = $false
    $l1InvalidBinding = $freeze.consumed_l1_physical_invalid_closure
    if ($l1InvalidBinding -is [System.Collections.IDictionary]) {
        $l1InvalidPath = [System.IO.Path]::GetFullPath(
            (Join-Path $repoRoot $l1PhysicalInvalidClosureRelativePath)
        )
        $l1InvalidSourceBlob = Get-GitText -Arguments @(
            "rev-parse", "${sourceCommit}:$l1PhysicalInvalidClosureRelativePath"
        ) -Label "consumed L1 physical-invalid source binding"
        $l1InvalidCurrentBlob = Get-GitText -Arguments @(
            "rev-parse", "${authorizationCommit}:$l1PhysicalInvalidClosureRelativePath"
        ) -Label "consumed L1 physical-invalid current binding"
        $l1InvalidBindingExact = (
            [string]$l1InvalidBinding.path -ceq $l1PhysicalInvalidClosureRelativePath -and
            [string]$l1InvalidBinding.status -ceq `
                "closed_consumed_infrastructure_invalid_baseline_trace_quaternion_projection" -and
            [string]$l1InvalidBinding.repair_id -ceq "QSDK-R10B-L1" -and
            [string]$l1InvalidBinding.closure_id -ceq "QSDK-R10B-L1-P1" -and
            [bool]$l1InvalidBinding.physical_identity_consumed -and
            -not [bool]$l1InvalidBinding.same_identity_rerun_permitted -and
            [string]$l1InvalidBinding.selected_successor_id -ceq "QSDK-R10B-L2" -and
            (Test-Path -LiteralPath $l1InvalidPath -PathType Leaf) -and
            [int64]$l1InvalidBinding.byte_length -eq `
                [int64](Get-Item -LiteralPath $l1InvalidPath).Length -and
            [string]$l1InvalidBinding.raw_sha256 -ceq `
                $consumedL1PhysicalInvalidClosureSha256 -and
            [string]$l1InvalidBinding.raw_sha256 -ceq `
                (Get-PrefixedSha256 $l1InvalidPath) -and
            [string]$l1InvalidBinding.git_blob_oid -ceq $l1InvalidSourceBlob -and
            [string]$l1InvalidBinding.git_blob_oid -ceq $l1InvalidCurrentBlob
        )
    }
    $l2InvalidBindingExact = $false
    $l2InvalidBinding = $freeze.consumed_l2_physical_invalid_closure
    if ($l2InvalidBinding -is [System.Collections.IDictionary]) {
        $l2InvalidPath = [System.IO.Path]::GetFullPath(
            (Join-Path $repoRoot $l2PhysicalInvalidClosureRelativePath)
        )
        $l2InvalidSourceBlob = Get-GitText -Arguments @(
            "rev-parse", "${sourceCommit}:$l2PhysicalInvalidClosureRelativePath"
        ) -Label "consumed L2 physical-invalid source binding"
        $l2InvalidCurrentBlob = Get-GitText -Arguments @(
            "rev-parse", "${authorizationCommit}:$l2PhysicalInvalidClosureRelativePath"
        ) -Label "consumed L2 physical-invalid current binding"
        $l2InvalidBindingExact = (
            [string]$l2InvalidBinding.path -ceq $l2PhysicalInvalidClosureRelativePath -and
            [string]$l2InvalidBinding.status -ceq `
                "closed_consumed_infrastructure_invalid_compound_trace_representation_validation" -and
            [string]$l2InvalidBinding.repair_id -ceq "QSDK-R10B-L2" -and
            [string]$l2InvalidBinding.closure_id -ceq "QSDK-R10B-L2-P1" -and
            [bool]$l2InvalidBinding.physical_identity_consumed -and
            -not [bool]$l2InvalidBinding.same_identity_rerun_permitted -and
            [string]$l2InvalidBinding.selected_successor_id -ceq "QSDK-R10B-L3" -and
            (Test-Path -LiteralPath $l2InvalidPath -PathType Leaf) -and
            [int64]$l2InvalidBinding.byte_length -eq `
                [int64](Get-Item -LiteralPath $l2InvalidPath).Length -and
            [string]$l2InvalidBinding.raw_sha256 -ceq `
                $consumedL2PhysicalInvalidClosureSha256 -and
            [string]$l2InvalidBinding.raw_sha256 -ceq `
                (Get-PrefixedSha256 $l2InvalidPath) -and
            [string]$l2InvalidBinding.git_blob_oid -ceq $l2InvalidSourceBlob -and
            [string]$l2InvalidBinding.git_blob_oid -ceq $l2InvalidCurrentBlob
        )
    }
    $freezeBindings = @($freeze.qualified_source_bindings)
    $bindingPaths = @($freezeBindings | ForEach-Object { [string]$_.path })
    $bindingsOrdinallySorted = Test-StrictOrdinalStringOrder -Values $bindingPaths
    $bindingsExact = (
        $freezeBindings.Count -eq $qualifiedSourcePathCount -and
        $bindingsOrdinallySorted -and
        (Get-TextSha256 -Text ($bindingPaths -join "`n")) -ceq $qualifiedSourcePathSha256
    )
    if ($bindingsExact) {
        foreach ($binding in $freezeBindings) {
            $relativePath = [string]$binding.path
            $absolutePath = [System.IO.Path]::GetFullPath((Join-Path $repoRoot $relativePath))
            $sourceBlob = Get-GitText -Arguments @(
                "rev-parse", "${sourceCommit}:$relativePath"
            ) -Label "source binding $relativePath"
            $currentBlob = Get-GitText -Arguments @(
                "rev-parse", "${authorizationCommit}:$relativePath"
            ) -Label "current binding $relativePath"
            if (
                [System.IO.Path]::IsPathRooted($relativePath) -or
                $relativePath.Contains("\") -or
                $absolutePath -cne [System.IO.Path]::GetFullPath(
                    (Join-Path $repoRoot $relativePath.Replace("/", [IO.Path]::DirectorySeparatorChar))
                ) -or
                -not $absolutePath.StartsWith(
                    $repoRoot + [IO.Path]::DirectorySeparatorChar,
                    [StringComparison]::OrdinalIgnoreCase
                ) -or
                -not (Test-Path -LiteralPath $absolutePath -PathType Leaf) -or
                -not (Test-LowerHex -Value ([string]$binding.git_blob_oid) -Length 40) -or
                $sourceBlob -cne [string]$binding.git_blob_oid -or
                $currentBlob -cne [string]$binding.git_blob_oid -or
                (Get-PrefixedSha256 $absolutePath) -cne [string]$binding.raw_sha256 -or
                [int64](Get-Item -LiteralPath $absolutePath).Length -ne [int64]$binding.byte_length
            ) {
                $bindingsExact = $false
                break
            }
        }
    }
    if (
        [string]$freeze.schema_version -cne $stageFreezeSchema -or
        [string]$freeze.status -cne "closed_passing_official_zero_world_qualification" -or
        [string]$freeze.gate_id -cne "QSDK-R10B" -or
        [string]$freeze.campaign_id -cne [string]$campaign.id -or
        [string]$freeze.campaign_role -cne $CampaignRole -or
        [string]$freeze.question_class -cne [string]$campaign.question_class -or
        [string]$freeze.source_commit -cne $sourceCommit -or
        [string]$freeze.qualification_parent_commit -cne $qualificationParentCommit -or
        [int]$freeze.qualified_source_path_count -ne $qualifiedSourcePathCount -or
        [string]$freeze.qualified_source_path_sha256 -cne $qualifiedSourcePathSha256 -or
        [string]$freeze.r10a_design_sha256 -cne $designSha256 -or
        [string]$freeze.l2_successor_design_sha256 -cne $l2SuccessorDesignSha256 -or
        [string]$freeze.l3_successor_design_sha256 -cne $l3SuccessorDesignSha256 -or
        [int]$freeze.maximum_world_count -ne [int]$campaign.maximum_world_count -or
        -not [bool]$freeze.official_zero_world_qualification_passed -or
        [bool]$freeze.physical_execution_authorized_by_freeze -or
        [bool]$freeze.physical_acceptance_authority -or
        [bool]$freeze.release_authority -or
        -not $refusalBindingExact -or
        -not $l1InvalidBindingExact -or
        -not $l2InvalidBindingExact -or
        -not $bindingsExact -or
        -not (Test-ExactStringArray -Actual @($freeze.ordered_cell_ids) -Expected $expectedCells)
    ) {
        throw "The QSDK-R10B stage freeze does not match this exact source and role"
    }
    if (
        [string]$authority.schema_version -cne $authoritySchema -or
        [string]$authority.status -cne "authorized_single_use_unconsumed" -or
        [string]$authority.gate_id -cne "QSDK-R10B" -or
        [string]$authority.campaign_id -cne [string]$campaign.id -or
        [string]$authority.campaign_role -cne $CampaignRole -or
        [string]$authority.question_class -cne [string]$campaign.question_class -or
        -not [bool]$authority.authorization_commit_derived_from_current_head -or
        [string]$authority.authorization_parent_commit -cne `
            [string]$RepositoryIdentity.authorization_parent_commit -or
        [string]$authority.qualification_parent_commit -cne $qualificationParentCommit -or
        [string]$authority.source_commit -cne $sourceCommit -or
        [string]$authority.qualification_closure_path -cne $stageFreezeRelativePath -or
        [string]$authority.r10a_design_sha256 -cne $designSha256 -or
        [string]$authority.l2_successor_design_sha256 -cne $l2SuccessorDesignSha256 -or
        [string]$authority.l3_successor_design_sha256 -cne $l3SuccessorDesignSha256 -or
        [string]$authority.stage_freeze_sha256 -cne (Get-PrefixedSha256 $freezePath) -or
        [string]$authority.stage_freeze_git_blob_oid -cne $stageFreezeBlob -or
        [string]$authority.superseded_authority_check_refusal_sha256 -cne `
            [string]$refusalBinding.raw_sha256 -or
        [string]$authority.consumed_l1_physical_invalid_closure_sha256 -cne `
            [string]$l1InvalidBinding.raw_sha256 -or
        [string]$authority.consumed_l2_physical_invalid_closure_sha256 -cne `
            [string]$l2InvalidBinding.raw_sha256 -or
        [int]$authority.qualified_source_path_count -ne $qualifiedSourcePathCount -or
        [string]$authority.qualified_source_path_sha256 -cne $qualifiedSourcePathSha256 -or
        -not [bool]$authority.zero_world_qualification_passed -or
        -not [bool]$authority.physical_execution_authorized -or
        [bool]$authority.physical_identity_consumed -or
        [bool]$authority.same_identity_rerun_permitted -or
        [int]$authority.maximum_world_count -ne [int]$campaign.maximum_world_count -or
        [int]$authority.maximum_campaign_attempt_count -ne 1 -or
        $authorityOutputRoot -cne $authorizedOutputPath -or
        -not $outputInsideEvidenceRoot -or
        (Test-Path -LiteralPath $authorizedOutputPath) -or
        [bool]$authority.physical_acceptance_authority -or
        [bool]$authority.release_authority -or
        -not (Test-ExactStringArray -Actual $qualificationChangedPaths `
            -Expected @($stageFreezeRelativePath)) -or
        -not (Test-ExactStringArray -Actual $authorizationChangedPaths `
            -Expected @($executionAuthorityRelativePath)) -or
        $qualificationCommitParent -cne $qualificationParentCommit -or
        $stageFreezeBlob -cne $currentStageFreezeBlob -or
        -not (Test-LowerHex -Value $currentAuthorityBlob -Length 40) -or
        -not (Test-ExactStringArray -Actual @($authority.ordered_cell_ids) -Expected $expectedCells)
    ) {
        throw "The QSDK-R10B execution authority is not exact and unconsumed"
    }
    if ($CampaignRole -ceq "development_route_ghost") {
        if (
            $qualificationParentCommit -cne $sourceCommit -or
            $null -ne $freeze.prerequisite_development_route_ghost
        ) {
            throw "The QSDK-R10B development qualification parent is not the source freeze"
        }
    } else {
        $prerequisite = $freeze.prerequisite_development_route_ghost
        if (
            $prerequisite -isnot [System.Collections.IDictionary] -or
            [string]$prerequisite.path -cne `
                "sdk/qsdk_r10b_development_route_ghost_physical_closure_v1.json" -or
            -not [bool]$prerequisite.route_execution_valid -or
            -not [bool]$prerequisite.physical_identity_consumed -or
            [bool]$prerequisite.same_identity_rerun_permitted
        ) {
            throw "The held-out authority lacks the consumed valid development route prerequisite"
        }
        $prerequisitePath = Join-Path $repoRoot ([string]$prerequisite.path)
        $prerequisiteBlob = Get-GitText -Arguments @(
            "rev-parse", "${qualificationParentCommit}:$([string]$prerequisite.path)"
        ) -Label "development route prerequisite blob"
        if (
            -not (Test-Path -LiteralPath $prerequisitePath -PathType Leaf) -or
            $prerequisiteBlob -cne [string]$prerequisite.git_blob_oid -or
            (Get-PrefixedSha256 $prerequisitePath) -cne [string]$prerequisite.raw_sha256
        ) {
            throw "The held-out development route prerequisite bytes do not match"
        }
    }
    return [ordered]@{
        source_commit = $sourceCommit
        qualification_parent_commit = $qualificationParentCommit
        qualification_commit = $qualificationCommit
        authorization_commit = $authorizationCommit
        stage_freeze_path = $freezePath
        stage_freeze_sha256 = Get-PrefixedSha256 $freezePath
        execution_authority_path = $authorityPath
        execution_authority_sha256 = Get-PrefixedSha256 $authorityPath
        output_root = $authorizedOutputPath
        document = $authority
    }
}

function Invoke-AuthorityCheckMode {
    $identity = Get-RepositoryIdentity
    $qualifiedAuthority = Get-QualifiedPhysicalAuthority -RepositoryIdentity $identity
    $receipt = [ordered]@{
        schema_version = "sporespore_qsdk_r10b_authority_check_zero_world_v4"
        gate_id = "QSDK-R10B"
        campaign_id = [string]$campaign.id
        campaign_role = $CampaignRole
        question_class = [string]$campaign.question_class
        ok = $true
        failure_code = ""
        source_commit = [string]$qualifiedAuthority.source_commit
        qualification_parent_commit = [string]$qualifiedAuthority.qualification_parent_commit
        qualification_commit = [string]$qualifiedAuthority.qualification_commit
        authorization_commit = [string]$qualifiedAuthority.authorization_commit
        stage_freeze_sha256 = [string]$qualifiedAuthority.stage_freeze_sha256
        execution_authority_sha256 = [string]$qualifiedAuthority.execution_authority_sha256
        output_root = [string]$qualifiedAuthority.output_root
        output_root_absent = -not (Test-Path -LiteralPath ([string]$qualifiedAuthority.output_root))
        physical_execution_authorized_for_later_separate_invocation = $true
        physical_execution_started = $false
        locomotion_outcome_exposure_count = 0
        model_construction_count = 0
        world_attempt_count = 0
        world_build_count = 0
        scene_tree_insertion_count = 0
        native_readback_count = 0
        solver_step_count = 0
        physics_state_modified = $false
        physical_acceptance_authority = $false
        release_authority = $false
    }
    Write-Output (
        "QSDK_R10B_AUTHORITY_CHECK_ZERO_WORLD_PASS " +
        ($receipt | ConvertTo-Json -Depth 100 -Compress)
    )
}

function Invoke-PhysicalMode {
    param([string]$TempRoot)
    $identity = Get-RepositoryIdentity
    $qualifiedAuthority = Get-QualifiedPhysicalAuthority -RepositoryIdentity $identity
    $operationLock = Enter-SporeSporeLocomotionOperationLock `
        -Role ([string]$campaign.operation_role) -TimeoutMilliseconds 0
    if (-not [bool]$operationLock.acquired) {
        throw "Another physical locomotion operation owns the serial lock"
    }
    try {
        $operationLockPublic = Get-SporeSporeLocomotionOperationLockPublicReceipt `
            -Receipt $operationLock
        $outputPath = [string]$qualifiedAuthority.output_root
        if (
            -not [string]::IsNullOrWhiteSpace($Output) -and
            [System.IO.Path]::GetFullPath($Output) -cne $outputPath
        ) {
            throw "-Output must exactly match the execution authority output_root"
        }
        if (-not $outputPath.StartsWith(
            $evidenceRoot + [System.IO.Path]::DirectorySeparatorChar,
            [StringComparison]::OrdinalIgnoreCase
        )) {
            throw "Physical output must be inside the durable SporeSpore_Evidence root"
        }
        if (Test-Path -LiteralPath $outputPath) {
            throw "Refusing to overwrite an existing physical evidence directory"
        }
        [void][System.IO.Directory]::CreateDirectory($outputPath)
        $cellRecords = [System.Collections.Generic.List[object]]::new()
        $pairRecords = [System.Collections.Generic.List[object]]::new()
        $worldAttemptCount = 0
        foreach ($seedValue in $campaign.seeds) {
            $seed = [int]$seedValue
            $cellPaths = [ordered]@{}
            foreach ($arm in $armOrder) {
                $cellId = Get-CellId -ArmId $arm -Seed $seed
                $cellRoot = Join-Path $outputPath $cellId
                [void][System.IO.Directory]::CreateDirectory($cellRoot)
                $attemptToken = [Guid]::NewGuid().ToString("N")
                $attemptPath = Join-Path $cellRoot "attempt.json"
                $attempt = [ordered]@{
                    schema_version = $attemptSchema
                    authorization_token = $attemptToken
                    campaign_id = [string]$campaign.id
                    gate_id = "QSDK-R10B"
                    campaign_role = $CampaignRole
                    arm_id = $arm
                    campaign_seed = $seed
                    cell_id = $cellId
                    source_commit = [string]$qualifiedAuthority.source_commit
                    authorization_commit = [string]$qualifiedAuthority.authorization_commit
                    authorization_parent_commit = [string]$qualifiedAuthority.qualification_commit
                    qualification_parent_commit = [string]$qualifiedAuthority.qualification_parent_commit
                    r10a_design_sha256 = $designSha256
                    l2_successor_design_sha256 = $l2SuccessorDesignSha256
                    l3_successor_design_sha256 = $l3SuccessorDesignSha256
                    consumed_l1_physical_invalid_closure_sha256 = `
                        $consumedL1PhysicalInvalidClosureSha256
                    consumed_l2_physical_invalid_closure_sha256 = `
                        $consumedL2PhysicalInvalidClosureSha256
                    stage_freeze_path = [string]$qualifiedAuthority.stage_freeze_path
                    stage_freeze_sha256 = [string]$qualifiedAuthority.stage_freeze_sha256
                    execution_authority_path = [string]$qualifiedAuthority.execution_authority_path
                    execution_authority_sha256 = [string]$qualifiedAuthority.execution_authority_sha256
                    output_root = $outputPath
                    synthetic_authorization_preflight = $false
                    supervisor_physical_authorized = $true
                    maximum_world_attempt_count = 1
                    maximum_world_build_count = 1
                    world_attempt_count_before_worker = 0
                    world_build_count_before_worker = 0
                    same_identity_rerun_permitted = $false
                    operation_lock = $operationLockPublic
                    physical_acceptance_authority = $false
                }
                Write-Utf8NoBom -Path $attemptPath -Text (
                    $attempt | ConvertTo-Json -Depth 50 -Compress
                )
                $worldAttemptCount++
                $execution = Invoke-GodotCaptured -Arguments @(
                    "--headless", "--path", $repoRoot,
                    "--log-file", (Join-Path $cellRoot "godot.log"),
                    "--script", $worker, "--", "physical",
                    $CampaignRole, $arm, ([string]$seed)
                ) -WorkerRoot (Join-Path $cellRoot "runtime") `
                    -TimeoutSeconds $CellTimeoutSeconds -AdditionalEnvironment @{
                        SPORESPORE_QSDK_R10B_ATTEMPT = $attemptPath
                        SPORESPORE_QSDK_R10B_TOKEN = $attemptToken
                    }
                Write-Utf8NoBom -Path (Join-Path $cellRoot "stdout.log") `
                    -Text ([string]$execution.stdout)
                Write-Utf8NoBom -Path (Join-Path $cellRoot "stderr.log") `
                    -Text ([string]$execution.stderr)
                if ($execution.timed_out -or $execution.exit_code -ne 0) {
                    throw "Physical cell $cellId failed or timed out; identity is consumed"
                }
                $cellReceipt = Get-SingleMarkerJson `
                    -Stdout ([string]$execution.stdout) -Marker $cellMarker
                if (
                    -not [bool]$cellReceipt.evidence_valid -or
                    -not [bool]$cellReceipt.outcome_complete -or
                    [int]$cellReceipt.world_build_count -ne 1 -or
                    [int]$cellReceipt.world_reset_count -ne 0
                ) {
                    throw "Physical cell $cellId returned invalid or incomplete evidence"
                }
                $cellPath = Join-Path $cellRoot "cell.json"
                Write-Utf8NoBom -Path $cellPath -Text (
                    $cellReceipt | ConvertTo-Json -Depth 100 -Compress
                )
                $cellPaths[$arm] = $cellPath
                $cellRecords.Add([ordered]@{
                    cell_id = $cellId
                    arm_id = $arm
                    campaign_seed = $seed
                    path = $cellPath
                    raw_sha256 = Get-PrefixedSha256 $cellPath
                    behavior_passed = [bool]$cellReceipt.behavior_passed
                    evidence_valid = [bool]$cellReceipt.evidence_valid
                })
            }
            $pairExecution = Invoke-GodotCaptured -Arguments @(
                "--headless", "--path", $repoRoot, "--script", $worker,
                "--", "pair-evaluate",
                ([string]$cellPaths["matched_no_impulse_control"]),
                ([string]$cellPaths["lateral_upright_impulse"])
            ) -WorkerRoot (Join-Path $outputPath "pair-s$seed-runtime") `
                -TimeoutSeconds 120
            if ($pairExecution.timed_out -or $pairExecution.exit_code -ne 0) {
                throw "Pair evaluation for seed $seed was invalid"
            }
            $pairReceipt = Get-SingleMarkerJson `
                -Stdout ([string]$pairExecution.stdout) -Marker $pairMarker
            if (
                -not [bool]$pairReceipt.evidence_valid -or
                -not [bool]$pairReceipt.outcome_complete -or
                -not [bool]$pairReceipt.native_effect_confirmed
            ) {
                throw "Pair seed $seed did not establish the native impulse path"
            }
            $pairPath = Join-Path $outputPath "pair-s$seed.json"
            Write-Utf8NoBom -Path $pairPath -Text (
                $pairReceipt | ConvertTo-Json -Depth 100 -Compress
            )
            $pairRecords.Add([ordered]@{
                campaign_seed = $seed
                path = $pairPath
                raw_sha256 = Get-PrefixedSha256 $pairPath
                behavior_passed = [bool]$pairReceipt.behavior_passed
                native_effect_confirmed = [bool]$pairReceipt.native_effect_confirmed
            })
        }
        $complete = (
            $worldAttemptCount -eq [int]$campaign.maximum_world_count -and
            $cellRecords.Count -eq [int]$campaign.maximum_world_count -and
            $pairRecords.Count -eq @($campaign.seeds).Count
        )
        $behaviorPassed = $complete
        foreach ($record in $pairRecords) {
            $behaviorPassed = $behaviorPassed -and [bool]$record.behavior_passed
        }
        $report = [ordered]@{
            schema_version = "sporespore_qsdk_r10b_physical_report_v4"
            gate_id = "QSDK-R10B"
            campaign_id = [string]$campaign.id
            campaign_role = $CampaignRole
            question_class = [string]$campaign.question_class
            status = if ($behaviorPassed) {
                "complete_valid_positive"
            } elseif ($complete) {
                "complete_valid_finite_negative"
            } else { "invalid_or_incomplete" }
            source = [ordered]@{
                source_freeze_commit = [string]$qualifiedAuthority.source_commit
                qualification_parent_commit = [string]$qualifiedAuthority.qualification_parent_commit
                qualification_commit = [string]$qualifiedAuthority.qualification_commit
                authorization_commit = [string]$qualifiedAuthority.authorization_commit
                authorization_tree = [string]$identity.authorization_tree
                branch = [string]$identity.branch
                remote = [string]$identity.remote
                origin_main_commit = [string]$identity.origin_main_commit
                live_main_commit = [string]$identity.live_main_commit
                clean = [bool]$identity.clean
            }
            stage_freeze_sha256 = [string]$qualifiedAuthority.stage_freeze_sha256
            execution_authority_sha256 = [string]$qualifiedAuthority.execution_authority_sha256
            l2_successor_design_sha256 = $l2SuccessorDesignSha256
            l3_successor_design_sha256 = $l3SuccessorDesignSha256
            consumed_l1_physical_invalid_closure_sha256 = `
                $consumedL1PhysicalInvalidClosureSha256
            consumed_l2_physical_invalid_closure_sha256 = `
                $consumedL2PhysicalInvalidClosureSha256
            output_root = $outputPath
            ordered_cell_ids = @(Get-OrderedCellIds)
            world_attempt_count = $worldAttemptCount
            world_build_count = $cellRecords.Count
            expected_world_count = [int]$campaign.maximum_world_count
            pair_count = $pairRecords.Count
            complete = $complete
            behavior_passed = $behaviorPassed
            cells = @($cellRecords)
            pairs = @($pairRecords)
            same_identity_rerun_permitted = $false
            physical_acceptance_authority = $false
            release_authority = $false
        }
        $reportPath = Join-Path $outputPath "report.json"
        Write-Utf8NoBom -Path $reportPath -Text (
            $report | ConvertTo-Json -Depth 100
        )
        Write-Output (
            "QSDK_R10B_PHYSICAL_COMPLETE " +
            ([ordered]@{
                report_path = $reportPath
                report_sha256 = Get-PrefixedSha256 $reportPath
                output_root = $outputPath
                status = [string]$report.status
                world_attempt_count = $worldAttemptCount
                world_build_count = $cellRecords.Count
                behavior_passed = $behaviorPassed
                same_identity_rerun_permitted = $false
            } | ConvertTo-Json -Compress)
        )
    } finally {
        Exit-SporeSporeLocomotionOperationLock -Receipt $operationLock
    }
}

$tempBase = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath())
$tempRoot = Join-Path $tempBase (
    "sporespore-qsdk-r10b-" + [Guid]::NewGuid().ToString("N")
)
[void][System.IO.Directory]::CreateDirectory($tempRoot)
try {
    if ($Mode -ceq "ZeroWorld") {
        Invoke-ZeroWorldMode -TempRoot $tempRoot
    } elseif ($Mode -ceq "AuthorityCheck") {
        Invoke-AuthorityCheckMode
    } else {
        Invoke-PhysicalMode -TempRoot $tempRoot
    }
} finally {
    $resolvedTemp = [System.IO.Path]::GetFullPath($tempRoot)
    if (
        (Test-Path -LiteralPath $resolvedTemp) -and
        $resolvedTemp.StartsWith(
            $tempBase,
            [System.StringComparison]::OrdinalIgnoreCase
        ) -and
        $resolvedTemp.Length -gt ($tempBase.Length + 24)
    ) {
        Remove-Item -LiteralPath $resolvedTemp -Recurse -Force
    }
}
