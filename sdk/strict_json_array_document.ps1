#requires -Version 7.0

Set-StrictMode -Version Latest

function ConvertTo-SporeSporeJsonArrayDocument {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [AllowNull()]
        [object[]]$Items,
        [ValidateRange(1, 100)]
        [int]$Depth = 100,
        [switch]$Compress
    )

    # PowerShell enumerates pipeline input before ConvertTo-Json sees it. A
    # one-element collection therefore becomes a JSON scalar when written as
    # `$items | ConvertTo-Json`. -InputObject crosses that boundary as one
    # explicitly typed array and preserves [], [x], and [x,y] distinctly.
    $arrayDocument = [object[]]@($Items)
    if ($Compress) {
        return ConvertTo-Json -InputObject $arrayDocument -Depth $Depth -Compress
    }
    return ConvertTo-Json -InputObject $arrayDocument -Depth $Depth
}

function Write-SporeSporeNewJsonArrayDocument {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path,
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [AllowNull()]
        [object[]]$Items,
        [ValidateRange(1, 100)]
        [int]$Depth = 100,
        [switch]$Compress
    )

    $resolved = [IO.Path]::GetFullPath($Path)
    if (Test-Path -LiteralPath $resolved) {
        throw "SporeSpore refuses to overwrite JSON array document: $resolved"
    }
    [void][IO.Directory]::CreateDirectory((Split-Path -Parent $resolved))
    $json = ConvertTo-SporeSporeJsonArrayDocument -Items $Items -Depth $Depth `
        -Compress:$Compress
    [IO.File]::WriteAllText(
        $resolved,
        $json + [Environment]::NewLine,
        [Text.UTF8Encoding]::new($false)
    )
    return $resolved
}
