#requires -Version 7.0

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
. (Join-Path $repoRoot "sdk\strict_json_array_document.ps1")

function Assert-ArrayDocument([object[]]$Items, [string]$Expected) {
    $serialized = ConvertTo-SporeSporeJsonArrayDocument -Items $Items -Compress
    if ($serialized -cne $Expected) {
        throw "JSON array document mismatch: expected=$Expected actual=$serialized"
    }
    $roundTrip = ConvertFrom-Json -InputObject $serialized -NoEnumerate
    if ($roundTrip -isnot [Array] -or $roundTrip.Count -ne $Items.Count) {
        throw "JSON array document lost its array shape: $serialized"
    }
}

Assert-ArrayDocument -Items @() -Expected '[]'
Assert-ArrayDocument -Items @('alpha') -Expected '["alpha"]'
Assert-ArrayDocument -Items @('alpha', 'beta') -Expected '["alpha","beta"]'

$pipelineTrap = @('alpha') | ConvertTo-Json -Compress
$strictSingle = ConvertTo-SporeSporeJsonArrayDocument -Items @('alpha') -Compress
if ($pipelineTrap -cne '"alpha"' -or $strictSingle -cne '["alpha"]') {
    throw "The one-element pipeline-enumeration negative control did not discriminate"
}

$nested = @([ordered]@{ id = "cell"; values = @(1, 2) })
$nestedJson = ConvertTo-SporeSporeJsonArrayDocument -Items $nested -Compress
$nestedRoundTrip = ConvertFrom-Json -InputObject $nestedJson -NoEnumerate
if (
    $nestedRoundTrip -isnot [Array] -or
    $nestedRoundTrip.Count -ne 1 -or
    $nestedRoundTrip[0].id -cne "cell" -or
    @($nestedRoundTrip[0].values).Count -ne 2
) {
    throw "Nested JSON array content did not survive round trip"
}

$testRoot = [IO.Path]::GetFullPath((
    Join-Path $repoRoot ".tmp-strict-json-array-$([Guid]::NewGuid().ToString('N'))"
))
$relativeTestRoot = [IO.Path]::GetRelativePath($repoRoot, $testRoot)
if (
    [IO.Path]::IsPathFullyQualified($relativeTestRoot) -or
    $relativeTestRoot -eq ".." -or
    $relativeTestRoot.StartsWith("..$([IO.Path]::DirectorySeparatorChar)")
) {
    throw "Test cleanup root escaped the repository: $testRoot"
}
try {
    $path = Join-Path $testRoot "terminal-paths.json"
    $written = Write-SporeSporeNewJsonArrayDocument -Path $path -Items @('only') `
        -Compress
    if ([IO.Path]::GetFullPath($written) -cne [IO.Path]::GetFullPath($path)) {
        throw "Writer returned the wrong path"
    }
    $bytes = [IO.File]::ReadAllBytes($path)
    $expectedBytes = [Text.UTF8Encoding]::new($false).GetBytes(
        '["only"]' + [Environment]::NewLine
    )
    if (-not [Linq.Enumerable]::SequenceEqual[byte]($bytes, $expectedBytes)) {
        throw "Writer bytes, newline, or UTF-8 encoding are not exact"
    }

    $overwriteRejected = $false
    try {
        Write-SporeSporeNewJsonArrayDocument -Path $path -Items @('replacement') `
            -Compress | Out-Null
    } catch {
        $overwriteRejected = $_.Exception.Message -like (
            "SporeSpore refuses to overwrite JSON array document:*"
        )
    }
    if (-not $overwriteRejected) {
        throw "Writer did not fail closed on an existing document"
    }
} finally {
    if (Test-Path -LiteralPath $testRoot) {
        Remove-Item -LiteralPath $testRoot -Recurse -Force
    }
}

Write-Host (
    "STRICT_JSON_ARRAY_DOCUMENT_TEST_PASS shapes=3 nested=1 " +
    "pipeline_negative=1 overwrite_negative=1"
)
