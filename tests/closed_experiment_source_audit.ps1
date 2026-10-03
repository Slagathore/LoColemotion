#requires -Version 7.0

Set-StrictMode -Version Latest

function Get-SporeGitBlobBytes {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$RepositoryRoot,
        [Parameter(Mandatory)][string]$Commit,
        [Parameter(Mandatory)][string]$Path
    )

    $start = [System.Diagnostics.ProcessStartInfo]::new()
    $start.FileName = "git"
    $start.WorkingDirectory = $RepositoryRoot
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    foreach (
        $argument in @(
            "-C",
            $RepositoryRoot,
            "cat-file",
            "blob",
            "${Commit}:$Path"
        )
    ) {
        [void]$start.ArgumentList.Add($argument)
    }

    $process = [System.Diagnostics.Process]::new()
    $process.StartInfo = $start
    if (-not $process.Start()) {
        throw "Failed to start Git historical-source audit"
    }
    $memory = [System.IO.MemoryStream]::new()
    try {
        $process.StandardOutput.BaseStream.CopyTo($memory)
        $stderr = $process.StandardError.ReadToEnd()
        $process.WaitForExit()
        if ($process.ExitCode -ne 0) {
            throw (
                "Git historical-source audit failed for ${Commit}:$Path`: " +
                $stderr
            )
        }
        return ,$memory.ToArray()
    } finally {
        $memory.Dispose()
        $process.Dispose()
    }
}

function Get-SporeByteSha256 {
    [CmdletBinding()]
    param([Parameter(Mandatory)][byte[]]$Bytes)

    return (
        [Convert]::ToHexString(
            [Security.Cryptography.SHA256]::HashData($Bytes)
        ).ToLowerInvariant()
    )
}

function Convert-SporeLfBlobToCrlfBytes {
    [CmdletBinding()]
    param([Parameter(Mandatory)][byte[]]$Bytes)

    # Experiment runners historically hashed checked-out Windows bytes. Git
    # retains the canonical LF blob, so also reconstruct the CRLF checkout
    # representation. This is byte-based and does not depend on locale or a
    # text decoder.
    $converted = [System.IO.MemoryStream]::new()
    try {
        for ($index = 0; $index -lt $Bytes.Length; $index += 1) {
            $value = $Bytes[$index]
            if (
                $value -eq 0x0A -and
                ($index -eq 0 -or $Bytes[$index - 1] -ne 0x0D)
            ) {
                $converted.WriteByte(0x0D)
            }
            $converted.WriteByte($value)
        }
        return ,$converted.ToArray()
    } finally {
        $converted.Dispose()
    }
}

function Test-SporeHistoricalSourceSha256 {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$RepositoryRoot,
        [Parameter(Mandatory)][string]$Commit,
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$ExpectedSha256
    )

    $expected = $ExpectedSha256.Replace("sha256:", "").ToLowerInvariant()
    $blob = Get-SporeGitBlobBytes `
        -RepositoryRoot $RepositoryRoot `
        -Commit $Commit `
        -Path $Path
    if ((Get-SporeByteSha256 -Bytes $blob) -ceq $expected) {
        return $true
    }
    $crlf = Convert-SporeLfBlobToCrlfBytes -Bytes $blob
    return (Get-SporeByteSha256 -Bytes $crlf) -ceq $expected
}

function Test-SporeWorkingOrHistoricalSourceSha256 {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$RepositoryRoot,
        [Parameter(Mandatory)][string]$Commit,
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$ExpectedSha256
    )

    # Closed campaigns may cite both external binary artifacts that were never
    # Git blobs (the retained paper PDFs) and living, versioned repository
    # documents. Preserve the strongest available check without making an old
    # result depend on today's documentation bytes.
    $workingPath = [System.IO.Path]::GetFullPath(
        (Join-Path $RepositoryRoot $Path)
    )
    if (-not (Test-Path -LiteralPath $workingPath -PathType Leaf)) {
        return $false
    }
    $expected = $ExpectedSha256.Replace("sha256:", "").ToLowerInvariant()
    $working = (
        Get-FileHash -LiteralPath $workingPath -Algorithm SHA256
    ).Hash.ToLowerInvariant()
    if ($working -ceq $expected) {
        return $true
    }
    try {
        return Test-SporeHistoricalSourceSha256 `
            -RepositoryRoot $RepositoryRoot `
            -Commit $Commit `
            -Path $Path `
            -ExpectedSha256 $ExpectedSha256
    } catch {
        return $false
    }
}

function Test-SporeHistoricalSourceAvailable {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$RepositoryRoot,
        [Parameter(Mandatory)][string]$Commit,
        [Parameter(Mandatory)][string]$Path
    )

    # A report can contain a raw Windows-checkout hash that differs from both
    # Git's canonical LF blob and a uniform CRLF checkout when the historical
    # working file had mixed line endings. The immutable report continues to
    # pin that raw receipt. This separate check proves that the named semantic
    # source is retained at the report's clean source commit.
    try {
        [void](Get-SporeGitBlobBytes `
            -RepositoryRoot $RepositoryRoot `
            -Commit $Commit `
            -Path $Path)
        return $true
    } catch {
        return $false
    }
}
