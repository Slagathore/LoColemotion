#requires -Version 7.0

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
. (Join-Path $repoRoot "sdk\locomotion_terminal_execution_projection.ps1")

function Assert-TerminalProjection([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "TERMINAL EXECUTION PROJECTION: $Message" }
}

$successSchema = "sporespore_qsdk_r23d52_engine_cell_report_v1"
$workerFailureSchema = "sporespore_qsdk_r23d52_worker_failure_v1"
$supervisorFailureSchema = "sporespore_qsdk_r23d52_supervisor_failure_v1"
$successSchemas = @($successSchema)
$failureSchemas = @($workerFailureSchema, $supervisorFailureSchema)

$success = [ordered]@{
    schema_version = $successSchema
    execution = [ordered]@{
        integrity_passed = $true
        world_attempt_count = 1
        world_build_count = 1
    }
}
$successProjection = Get-SporeSporeTerminalExecutionProjection `
    -Terminal $success -SuccessSchemas $successSchemas -FailureSchemas $failureSchemas
Assert-TerminalProjection (
    [string]$successProjection.projection_source -ceq "execution" -and
    [int]$successProjection.world_attempt_count -eq 1 -and
    [int]$successProjection.world_build_count -eq 1 -and
    [bool]$successProjection.world_build_count_exact -and
    [int]$successProjection.world_build_count_lower_bound -eq 1 -and
    [int]$successProjection.world_build_count_upper_bound -eq 1
) "schema-valid success terminal did not project nested execution counts"

$workerFailure = [ordered]@{
    schema_version = $workerFailureSchema
    world_attempt_count = 1
    world_build_count = 1
}
$workerFailureProjection = Get-SporeSporeTerminalExecutionProjection `
    -Terminal $workerFailure -SuccessSchemas $successSchemas -FailureSchemas $failureSchemas
Assert-TerminalProjection (
    [string]$workerFailureProjection.projection_source -ceq "terminal_root_failure" -and
    [int]$workerFailureProjection.world_attempt_count -eq 1 -and
    [int]$workerFailureProjection.world_build_count -eq 1 -and
    [bool]$workerFailureProjection.world_build_count_exact
) "worker-failure terminal did not project root counts"

$supervisorFailure = [ordered]@{
    schema_version = $supervisorFailureSchema
    world_attempt_count = 1
    world_build_count = 0
    world_build_count_exact = $false
    world_build_count_lower_bound = 0
    world_build_count_upper_bound = 1
}
$supervisorFailureProjection = Get-SporeSporeTerminalExecutionProjection `
    -Terminal $supervisorFailure -SuccessSchemas $successSchemas `
    -FailureSchemas $failureSchemas
Assert-TerminalProjection (
    [string]$supervisorFailureProjection.projection_source -ceq
        "terminal_root_failure" -and
    [int]$supervisorFailureProjection.world_attempt_count -eq 1 -and
    [int]$supervisorFailureProjection.world_build_count -eq 0 -and
    -not [bool]$supervisorFailureProjection.world_build_count_exact -and
    [int]$supervisorFailureProjection.world_build_count_lower_bound -eq 0 -and
    [int]$supervisorFailureProjection.world_build_count_upper_bound -eq 1
) "supervisor-failure uncertainty bounds did not survive projection"

$mutations = @(
    { $value = $success.Clone(); $value.Remove("execution"); $value },
    { $value = $success.Clone(); $value["world_build_count"] = 1; $value },
    {
        $value = $success.Clone()
        $value["execution"] = ([ordered]@{ world_attempt_count = 1 })
        $value
    },
    {
        $value = $success.Clone()
        $value["execution"] = ([ordered]@{
            world_attempt_count = "1"
            world_build_count = 1
        })
        $value
    },
    {
        $value = $success.Clone()
        $value["execution"] = ([ordered]@{
            world_attempt_count = 0
            world_build_count = 1
        })
        $value
    },
    { $value = $workerFailure.Clone(); $value["execution"] = @{}; $value },
    {
        [ordered]@{
            schema_version = "sporespore_unknown_terminal_v1"
            world_attempt_count = 0
            world_build_count = 0
        }
    },
    {
        $value = $supervisorFailure.Clone()
        $value["world_build_count_exact"] = "false"
        $value
    },
    {
        $value = $supervisorFailure.Clone()
        $value["world_build_count_lower_bound"] = 1
        $value
    },
    {
        $value = $supervisorFailure.Clone()
        $value["world_build_count_upper_bound"] = 2
        $value
    }
)
$rejected = 0
foreach ($mutation in $mutations) {
    try {
        $value = & $mutation
        $null = Get-SporeSporeTerminalExecutionProjection `
            -Terminal $value -SuccessSchemas $successSchemas -FailureSchemas $failureSchemas
    } catch {
        $rejected++
    }
}
Assert-TerminalProjection ($rejected -eq $mutations.Count) (
    "expected $($mutations.Count) rejected mutations, observed $rejected"
)

Write-Host (
    "LOCOMOTION_TERMINAL_EXECUTION_PROJECTION_PASS positive=1 failures=2 " +
    "rejected=$rejected models=0 worlds=0 physical_authority=False"
)
