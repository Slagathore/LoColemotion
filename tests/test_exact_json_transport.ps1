#requires -Version 7.5
param(
    [ValidateSet('Serialize', 'ProductionWrite', 'ProductionPublish', 'SourceStringWrite', 'Refusals')]
    [string]$Mode = 'Serialize',
    [string]$OutputPath = '',
    [string]$InputPath = '',
    [switch]$Indented
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
# This helper's stdin/stdout protocol is UTF-8 even without an attached console.
[Console]::InputEncoding = [Text.UTF8Encoding]::new($false, $true)
[Console]::OutputEncoding = [Text.UTF8Encoding]::new($false, $true)
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
. (Join-Path $root 'sdk/exact_json_transport.ps1')
if ($Mode -ceq 'Refusals') {
    $refused = 0
    foreach ($bad in @([double]::NaN, [double]::PositiveInfinity, [double]::NegativeInfinity,
                       [DateTime]::UtcNow, [decimal]1, @{1='not-a-string-key'}, [string][char]0xD800)) {
        try { $null = ConvertTo-SporeSporeExactJson -Value $bad }
        catch { $refused++; continue }
        throw 'EXACT_JSON_BAD_VALUE_ACCEPTED'
    }
    $cycle = @{}; $cycle['self'] = $cycle
    try { $null = ConvertTo-SporeSporeExactJson -Value $cycle -Depth 4 }
    catch { $refused++ }
    if ($refused -ne 8) { throw 'EXACT_JSON_REFUSAL_COUNT' }
    Write-Output ('EXACT_JSON_REFUSALS_PASS ' + $refused)
    exit 0
}
if ($Mode -ceq 'SourceStringWrite') {
    $value = @{stdout=[IO.File]::ReadAllText($InputPath, [Text.UTF8Encoding]::new($false, $true));
        stderr=''; physical_acceptance_authority=$false; release_authority=$false}
} else {
    $inputText = [Console]::In.ReadToEnd()
    $value = ConvertFrom-Json -InputObject $inputText -AsHashtable -Depth 100 -DateKind String -NoEnumerate
}
if ($Mode -ceq 'Serialize') {
    $values = @(ConvertTo-SporeSporeExactJson -Value $value -Indented:$Indented)
    if ($values.Count -ne 1 -or $values[0] -isnot [string]) { throw 'EXACT_JSON_NOT_SINGLE_STRING' }
    Write-Output $values[0]
    exit 0
}
# Extract the actual production functions, without its physical entrypoint.
$tokens = $null; $errors = $null
$ast = [Management.Automation.Language.Parser]::ParseFile(
    (Join-Path $root 'sdk/run_qsdk_r10f_continuous_passive_recovery.ps1'), [ref]$tokens, [ref]$errors)
if ($errors.Count) { throw 'PRODUCTION_SOURCE_PARSE' }
. (Join-Path $root 'sdk/qsdk_r10f_l15_launch_relationship.ps1')
foreach ($name in @('Assert-R10f', 'Get-PrefixedSha256', 'Write-Utf8CreateNew', 'Write-JsonCreateNew',
                    'Get-R10fRetainedFileBinding', 'Publish-L15SupervisorResult')) {
    $nodes = @($ast.FindAll({param($node)
        $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -ceq $name
    }, $false))
    if ($nodes.Count -ne 1) { throw ('PRODUCTION_FUNCTION:' + $name) }
    . ([scriptblock]::Create($nodes[0].Extent.Text))
}
if ([string]::IsNullOrEmpty($OutputPath)) { throw 'OUTPUT_PATH_REQUIRED' }
$null = Write-JsonCreateNew -Path $OutputPath -Value $value
if ($Mode -in @('ProductionWrite', 'SourceStringWrite')) { Write-Output 'PRODUCTION_JSON_WRITE_PASS'; exit 0 }
if ([IO.Path]::GetFileName($OutputPath) -cne 'supervisor_result.json') { throw 'PRIMARY_PATH_REQUIRED' }
$script:PhysicalAttemptRoot = [IO.Path]::GetDirectoryName($OutputPath)
$script:L15PrimaryMarkerPublished = $false
$script:L15PrimaryReportWriteCompleted = $true
$script:L15PrimaryReportBinding = Get-R10fRetainedFileBinding $OutputPath
$script:PhysicalMarker = 'DEVELOPMENT_INTERFACE_PUBLICATION '
$returned = @(Publish-L15SupervisorResult -Supervisor $value)
if ($returned.Count -ne 1 -or $returned[0] -isnot [string]) { throw 'PUBLICATION_RETURN_COUNT' }
Write-Output $returned[0]
