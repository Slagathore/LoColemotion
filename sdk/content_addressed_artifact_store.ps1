#requires -Version 7.0

$script:SporeSporeArtifactManifestSchema =
    "sporespore_content_addressed_artifact_manifest_v1"

function Get-SporeSporeArtifactRawSha256 {
    param([Parameter(Mandatory)][string]$Path)
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).
        Hash.ToLowerInvariant()
}

function Get-SporeSporeArtifactEvidenceRoot {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$RepoRoot)
    $root = [System.IO.Path]::GetFullPath($RepoRoot).TrimEnd('\', '/')
    return [System.IO.Path]::GetFullPath(
        (Join-Path (Split-Path -Parent $root) "SporeSpore_Evidence")
    )
}

function Test-SporeSporeStoredArtifact {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Directory,
        [Parameter(Mandatory)][string]$ExpectedSha256,
        [Parameter(Mandatory)][long]$ExpectedByteLength
    )
    $payload = Join-Path $Directory "payload.bin"
    $manifestPath = Join-Path $Directory "manifest.json"
    if (-not (Test-Path -LiteralPath $payload -PathType Leaf) -or
        -not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
        return $false
    }
    try {
        $manifest = Get-Content -Raw -LiteralPath $manifestPath |
            ConvertFrom-Json -AsHashtable -Depth 16
        return (
            [string]$manifest.schema_version -ceq
                $script:SporeSporeArtifactManifestSchema -and
            [string]$manifest.algorithm -ceq "sha256" -and
            [string]$manifest.sha256 -ceq "sha256:$ExpectedSha256" -and
            [long]$manifest.byte_length -eq $ExpectedByteLength -and
            [string]$manifest.payload_name -ceq "payload.bin" -and
            (Get-Item -LiteralPath $payload).Length -eq $ExpectedByteLength -and
            (Get-SporeSporeArtifactRawSha256 $payload) -ceq $ExpectedSha256
        )
    } catch { return $false }
}

function Publish-SporeSporeContentAddressedArtifact {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$RepoRoot,
        [Parameter(Mandatory)][string]$ArtifactPath,
        [string]$MediaType = "application/octet-stream",
        [string]$EvidenceRootOverride = "",
        [switch]$TestOnly
    )
    $repo = [System.IO.Path]::GetFullPath($RepoRoot).TrimEnd('\', '/')
    $artifact = [System.IO.Path]::GetFullPath($ArtifactPath)
    if (-not (Test-Path -LiteralPath $artifact -PathType Leaf)) {
        throw "Content-addressed artifact input is missing: $artifact"
    }
    $productionEvidence = Get-SporeSporeArtifactEvidenceRoot -RepoRoot $repo
    $evidence = if ([string]::IsNullOrWhiteSpace($EvidenceRootOverride)) {
        $productionEvidence
    } else { [System.IO.Path]::GetFullPath($EvidenceRootOverride) }
    if (-not $TestOnly -and $evidence -cne $productionEvidence) {
        throw "Production artifact storage must use $productionEvidence"
    }
    $digest = Get-SporeSporeArtifactRawSha256 $artifact
    $length = (Get-Item -LiteralPath $artifact).Length
    $storeRoot = Join-Path $evidence "artifacts\sha256"
    $finalDirectory = Join-Path $storeRoot $digest
    if (Test-Path -LiteralPath $finalDirectory) {
        if (-not (Test-SporeSporeStoredArtifact `
            -Directory $finalDirectory `
            -ExpectedSha256 $digest `
            -ExpectedByteLength $length)) {
            throw "Content-addressed artifact collision or corruption: $finalDirectory"
        }
        return [ordered]@{
            schema_version = "sporespore_content_addressed_artifact_receipt_v1"
            sha256 = "sha256:$digest"
            byte_length = $length
            payload_path = (Join-Path $finalDirectory "payload.bin")
            manifest_path = (Join-Path $finalDirectory "manifest.json")
            already_present = $true
            test_only = [bool]$TestOnly
            physical_acceptance_authority = $false
        }
    }
    [void][System.IO.Directory]::CreateDirectory($storeRoot)
    $staging = Join-Path $storeRoot (".staging-" + [guid]::NewGuid().ToString("N"))
    [void][System.IO.Directory]::CreateDirectory($staging)
    $publishedByPeer = $false
    try {
        $stagedPayload = Join-Path $staging "payload.bin"
        Copy-Item -LiteralPath $artifact -Destination $stagedPayload
        if ((Get-SporeSporeArtifactRawSha256 $stagedPayload) -cne $digest -or
            (Get-Item -LiteralPath $stagedPayload).Length -ne $length) {
            throw "Staged artifact did not reproduce its source bytes."
        }
        $manifest = [ordered]@{
            schema_version = $script:SporeSporeArtifactManifestSchema
            algorithm = "sha256"
            sha256 = "sha256:$digest"
            byte_length = $length
            payload_name = "payload.bin"
            media_type = $MediaType
        }
        [System.IO.File]::WriteAllText(
            (Join-Path $staging "manifest.json"),
            ($manifest | ConvertTo-Json -Depth 8) + [Environment]::NewLine,
            [System.Text.UTF8Encoding]::new($false)
        )
        # Windows indexers and antivirus scanners can briefly hold a freshly
        # written directory open. Keep the atomic same-volume rename, but give
        # that transient lock a tightly bounded retry window. A destination
        # created by another publisher is accepted only after full digest and
        # length verification; every other condition still fails closed.
        $moveAttempt = 0
        while ($true) {
            $moveAttempt += 1
            try {
                [System.IO.Directory]::Move($staging, $finalDirectory)
                break
            } catch {
                if (Test-Path -LiteralPath $finalDirectory) {
                    if (-not (Test-SporeSporeStoredArtifact `
                        -Directory $finalDirectory `
                        -ExpectedSha256 $digest `
                        -ExpectedByteLength $length)) {
                        throw (
                            "Content-addressed artifact collision or corruption " +
                            "during atomic publication: $finalDirectory"
                        )
                    }
                    $publishedByPeer = $true
                    break
                }
                if ($moveAttempt -ge 12) {
                    throw (
                        "Content-addressed artifact atomic publication failed " +
                        "after $moveAttempt attempts: $($_.Exception.Message)"
                    )
                }
                $delayMilliseconds = [Math]::Min(
                    250,
                    10 * [Math]::Pow(2, $moveAttempt - 1)
                )
                Start-Sleep -Milliseconds ([int]$delayMilliseconds)
            }
        }
    } finally {
        if (Test-Path -LiteralPath $staging) {
            $resolvedStaging = [System.IO.Path]::GetFullPath($staging)
            $resolvedStore = [System.IO.Path]::GetFullPath($storeRoot).TrimEnd('\', '/')
            if (-not $resolvedStaging.StartsWith(
                $resolvedStore + [System.IO.Path]::DirectorySeparatorChar,
                [System.StringComparison]::OrdinalIgnoreCase
            ) -or (Split-Path -Leaf $resolvedStaging) -notlike ".staging-*") {
                throw "Refusing unsafe artifact-store staging cleanup: $resolvedStaging"
            }
            Remove-Item -LiteralPath $resolvedStaging -Recurse -Force
        }
    }
    if (-not (Test-SporeSporeStoredArtifact `
        -Directory $finalDirectory `
        -ExpectedSha256 $digest `
        -ExpectedByteLength $length)) {
        throw "Published content-addressed artifact failed verification."
    }
    return [ordered]@{
        schema_version = "sporespore_content_addressed_artifact_receipt_v1"
        sha256 = "sha256:$digest"
        byte_length = $length
        payload_path = (Join-Path $finalDirectory "payload.bin")
        manifest_path = (Join-Path $finalDirectory "manifest.json")
        already_present = $publishedByPeer
        test_only = [bool]$TestOnly
        physical_acceptance_authority = $false
    }
}
