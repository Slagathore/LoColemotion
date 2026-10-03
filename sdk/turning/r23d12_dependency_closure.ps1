#requires -Version 7.0

Set-StrictMode -Version Latest

function Assert-R23D12DependencyCondition {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}
function Get-R23D12RawSha256 {
    param([Parameter(Mandatory)][string]$Path)
    return "sha256:" + (
        Get-FileHash -LiteralPath $Path -Algorithm SHA256
    ).Hash.ToLowerInvariant()
}

function Get-R23D12DependencyManifest {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$RepoRoot,
        [string]$DeclarationPath = ""
    )

    $repo = [IO.Path]::GetFullPath($RepoRoot).TrimEnd("\", "/")
    if ([string]::IsNullOrWhiteSpace($DeclarationPath)) {
        $DeclarationPath = Join-Path $repo (
            "sdk\turning\r23d12_physical_implementation_contract_v1.json"
        )
    }
    $declarationFile = [IO.Path]::GetFullPath($DeclarationPath)
    Assert-R23D12DependencyCondition (
        (git -C $repo rev-parse --show-toplevel).Trim().Replace("/", "\") -ceq
            $repo -and
        (git -C $repo remote get-url origin).Trim() -ceq
            "https://github.com/Slagathore/sporespore.git" -and
        (Test-Path -LiteralPath $declarationFile -PathType Leaf)
    ) "QSDK-R23D12 dependency composer repository or declaration mismatch"

    $declaration = Get-Content -Raw -LiteralPath $declarationFile |
        ConvertFrom-Json -AsHashtable -Depth 100
    $contract = $declaration.dependency_closure
    $workerIds = @($contract.declared_worker_ids)
    Assert-R23D12DependencyCondition (
        [string]$declaration.schema_version -ceq
            "sporespore_qsdk_r23d12_physical_implementation_contract_v1" -and
        [string]$contract.manifest_schema_version -ceq
            "sporespore_qsdk_r23d12_worker_dependency_manifest_v1" -and
        ($workerIds -join "|") -ceq "mujoco|rapier_parry|godot_jolt"
    ) "QSDK-R23D12 dependency manifest identity changed"

    $pathsByWorker = [ordered]@{}
    $union = [Collections.Generic.List[string]]::new()
    foreach ($workerId in $workerIds) {
        Assert-R23D12DependencyCondition (
            $contract.required_dependency_paths_by_worker.ContainsKey($workerId)
        ) "QSDK-R23D12 dependency manifest worker missing: $workerId"
        $paths = @($contract.required_dependency_paths_by_worker[$workerId])
        Assert-R23D12DependencyCondition ($paths.Count -gt 0) (
            "QSDK-R23D12 dependency manifest worker is empty: $workerId"
        )
        foreach ($pathValue in $paths) {
            $path = [string]$pathValue
            Assert-R23D12DependencyCondition (
                -not [string]::IsNullOrWhiteSpace($path) -and
                -not [IO.Path]::IsPathRooted($path) -and
                -not $path.Contains("\") -and
                -not $path.Contains("*") -and
                -not $path.Contains("?") -and
                $path -ceq $path.Trim()
            ) "QSDK-R23D12 dependency path is not exact: $workerId`: $path"
            $union.Add($path)
        }
        Assert-R23D12DependencyCondition (
            @($paths | Group-Object -CaseSensitive | Where-Object Count -gt 1).Count -eq 0
        ) "QSDK-R23D12 dependency manifest contains a duplicate: $workerId"
        $pathsByWorker[$workerId] = @($paths)
    }
    $unionPaths = @($union | Sort-Object -Unique -CaseSensitive)
    Assert-R23D12DependencyCondition (
        $unionPaths.Count -eq [int]$contract.declared_unique_dependency_count -and
        $unionPaths.Count -gt 0
    ) (
        "QSDK-R23D12 dependency union changed: $($unionPaths.Count)"
    )

    return [ordered]@{
        schema_version = "sporespore_qsdk_r23d12_worker_dependency_manifest_v1"
        declaration_path = $declarationFile
        declaration_raw_sha256 = Get-R23D12RawSha256 $declarationFile
        ordered_worker_ids = @($workerIds)
        required_paths_by_worker = $pathsByWorker
        union_paths = @($unionPaths)
        unique_dependency_count = $unionPaths.Count
    }
}

function New-R23D12DependencyReceipts {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$RepoRoot,
        [Parameter(Mandatory)]$Manifest
    )

    $repo = [IO.Path]::GetFullPath($RepoRoot).TrimEnd("\", "/")
    $tracked = @(& git -C $repo ls-files)
    Assert-R23D12DependencyCondition ($LASTEXITCODE -eq 0) (
        "QSDK-R23D12 could not enumerate tracked dependency paths"
    )
    $trackedSet = [Collections.Generic.HashSet[string]]::new(
        [StringComparer]::Ordinal
    )
    foreach ($path in $tracked) { [void]$trackedSet.Add([string]$path) }

    $receipts = [Collections.Generic.List[object]]::new()
    foreach ($relative in @($Manifest.union_paths)) {
        Assert-R23D12DependencyCondition ($trackedSet.Contains([string]$relative)) (
            "QSDK-R23D12 dependency is not tracked with exact case: $relative"
        )
        $path = Join-Path $repo ([string]$relative).Replace("/", "\")
        Assert-R23D12DependencyCondition (
            Test-Path -LiteralPath $path -PathType Leaf
        ) "QSDK-R23D12 dependency file is missing: $relative"
        $receipts.Add([ordered]@{
            path = [string]$relative
            raw_sha256 = Get-R23D12RawSha256 $path
        })
    }
    return @($receipts)
}

function Test-R23D12DependencyReceiptClosure {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]$Manifest,
        [Parameter(Mandatory)][AllowEmptyCollection()][object[]]$RequiredReceipts,
        [Parameter(Mandatory)][AllowEmptyCollection()][object[]]$SourceBindings,
        [string]$WorkerId = ""
    )

    $knownWorkers = @($Manifest.ordered_worker_ids)
    if (-not [string]::IsNullOrWhiteSpace($WorkerId) -and
        $knownWorkers -cnotcontains $WorkerId) {
        return [ordered]@{
            ok = $false
            failure_code = "R23D12_DEPENDENCY_UNKNOWN_WORKER"
            missing_paths = @()
            mismatched_paths = @()
        }
    }
    $requiredPaths = @(
        if ([string]::IsNullOrWhiteSpace($WorkerId)) {
            @($Manifest.union_paths)
        } else {
            @($Manifest.required_paths_by_worker[$WorkerId])
        }
    )
    if ($requiredPaths.Count -eq 0) {
        return [ordered]@{
            ok = $false
            failure_code = "R23D12_DEPENDENCY_EMPTY_REQUIRED_SET"
            missing_paths = @()
            mismatched_paths = @()
        }
    }

    $shaPattern = '^sha256:[0-9a-f]{64}$'
    $requiredByPath = [Collections.Generic.Dictionary[string, string]]::new(
        [StringComparer]::Ordinal
    )
    foreach ($receiptValue in $RequiredReceipts) {
        $path = [string]$receiptValue.path
        $digest = [string]$receiptValue.raw_sha256
        if ($requiredByPath.ContainsKey($path) -or $digest -cnotmatch $shaPattern) {
            return [ordered]@{
                ok = $false
                failure_code = "R23D12_DEPENDENCY_REQUIRED_RECEIPTS_INVALID"
                missing_paths = @()
                mismatched_paths = @($path)
            }
        }
        $requiredByPath.Add($path, $digest)
    }
    $observedByPath = [Collections.Generic.Dictionary[string, string]]::new(
        [StringComparer]::Ordinal
    )
    foreach ($bindingValue in $SourceBindings) {
        $path = [string]$bindingValue.path
        $digest = [string]$bindingValue.raw_sha256
        if ($observedByPath.ContainsKey($path) -or $digest -cnotmatch $shaPattern) {
            return [ordered]@{
                ok = $false
                failure_code = "R23D12_DEPENDENCY_SOURCE_BINDINGS_INVALID"
                missing_paths = @()
                mismatched_paths = @($path)
            }
        }
        $observedByPath.Add($path, $digest)
    }

    $missing = [Collections.Generic.List[string]]::new()
    $mismatched = [Collections.Generic.List[string]]::new()
    foreach ($pathValue in $requiredPaths) {
        $path = [string]$pathValue
        if (-not $requiredByPath.ContainsKey($path) -or
            -not $observedByPath.ContainsKey($path)) {
            $missing.Add($path)
        } elseif ($observedByPath[$path] -cne $requiredByPath[$path]) {
            $mismatched.Add($path)
        }
    }
    $ok = $missing.Count -eq 0 -and $mismatched.Count -eq 0
    return [ordered]@{
        ok = $ok
        failure_code = if ($ok) { "" } else { "R23D12_DEPENDENCY_CLOSURE_INVALID" }
        missing_paths = @($missing)
        mismatched_paths = @($mismatched)
    }
}
