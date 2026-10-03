#requires -Version 7.0
# Dot-sourcing loads a pure in-memory serializer; it opens no world or evidence.
if (-not ('SporeSpore.ProcessTransport.ExactJsonV1' -as [type])) {
    Add-Type -Path (Join-Path $PSScriptRoot 'process/ExactJsonV1.cs')
}

function ConvertTo-SporeSporeExactJson {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][AllowNull()][object]$Value,
        [ValidateRange(1, 128)][int]$Depth = 100,
        [switch]$Indented
    )
    # Exactly one string is emitted; internal append/write methods return void.
    return [SporeSpore.ProcessTransport.ExactJsonV1]::Serialize($Value, $Depth, $Indented.IsPresent)
}
