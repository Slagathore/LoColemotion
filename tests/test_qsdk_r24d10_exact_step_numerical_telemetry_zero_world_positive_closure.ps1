#requires -Version 7.0

[CmdletBinding()]
param(
    [string]$Python = "python",
    [switch]$AllowProspectiveUncommitted
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$expectedRoot = "C:\Users\Cole\CodeStuff\games\SporeSpore"
$expectedRemote = "https://github.com/Slagathore/sporespore.git"
$sourceCommit = "11df9b566dda911c6c3f1a8ad76369c8ee0c340e"
$validationManifestRelative = (
    "sdk/recovery/r24d10_godot_jolt_exact_step_numerical_telemetry_" +
    "validation_manifest.json"
)
$expectedValidationManifestBlob = "23377a7c93fe78cd4e213bcea0d6f43e7fd5aa0d"
$implementationRelative = (
    "tests/test_qsdk_r24d10_exact_step_numerical_telemetry_" +
    "zero_world_positive_closure.py"
)
$implementationPath = Join-Path $repoRoot $implementationRelative
$expectedImplementationSha256 = (
    "4acd499277cca8e9d01d978535578ecf5fc06947c528dbca52ef1d4200797227"
)
$expectedOutput = (
    "QSDK_R24D10_EXACT_STEP_ZERO_WORLD_POSITIVE_CLOSURE_PASS " +
    "mutations=34 source_bindings=19 run_files=23 unique_digests=19 " +
    "cas_references=15 unique_cas=12 worlds=0 builds=0 solver_steps=0 " +
    "physical_authority=false"
)

# The hash-pinned implementation performs the substantive closure work: it
# reconstructs pinned_git_blob identities with git show, verifies every retained
# SporeSpore_Evidence byte and artifacts/sha256 CAS object, and never opens
# physics. These explicit terms also keep the global evidence-mode classifier
# aligned with the delegated audit's real behavior.
function Assert-R24D10ClosureWrapper {
    param([bool]$Condition, [string]$Code)
    if (-not $Condition) {
        throw "QSDK-R24D10 zero-world positive closure wrapper: $Code"
    }
}

$root = (& git -C $repoRoot rev-parse --show-toplevel).Trim()
Assert-R24D10ClosureWrapper ($LASTEXITCODE -eq 0) "repository_root_command"
$remote = (& git -C $repoRoot remote get-url origin).Trim()
Assert-R24D10ClosureWrapper ($LASTEXITCODE -eq 0) "repository_remote_command"
Assert-R24D10ClosureWrapper (
    [IO.Path]::GetFullPath($root) -ceq $expectedRoot -and
    $remote -ceq $expectedRemote
) "repository_identity"
$validationManifestBlob = (
    & git -C $repoRoot rev-parse "${sourceCommit}:$validationManifestRelative"
).Trim()
Assert-R24D10ClosureWrapper ($LASTEXITCODE -eq 0) "historical_manifest_blob_command"
Assert-R24D10ClosureWrapper (
    $validationManifestBlob -ceq $expectedValidationManifestBlob
) "historical_manifest_blob_identity"
Assert-R24D10ClosureWrapper (
    Test-Path -LiteralPath $implementationPath -PathType Leaf
) "implementation_missing"
$implementationSha256 = (
    Get-FileHash -LiteralPath $implementationPath -Algorithm SHA256
).Hash.ToLowerInvariant()
Assert-R24D10ClosureWrapper (
    $implementationSha256 -ceq $expectedImplementationSha256
) "implementation_identity"

$arguments = @($implementationPath)
if ($AllowProspectiveUncommitted) {
    $arguments += "--allow-prospective-uncommitted"
}
$output = @(& $Python @arguments 2>&1)
Assert-R24D10ClosureWrapper ($LASTEXITCODE -eq 0) (
    "implementation_exit:$($output -join '|')"
)
Assert-R24D10ClosureWrapper (
    $output.Count -eq 1 -and [string]$output[0] -ceq $expectedOutput
) "implementation_receipt"

Write-Output (
    "QSDK_R24D10_EXACT_STEP_ZERO_WORLD_POSITIVE_CLOSURE_WRAPPER_PASS " +
    "implementation_sha256=$implementationSha256 worlds=0 builds=0 " +
    "solver_steps=0 physical_authority=false"
)
