#requires -Version 7.0

<#
.SYNOPSIS
Exercises the lab-attestation key initializer without touching production.

.DESCRIPTION
Every child invocation passes both -TestMode and an explicit trust root below
the system temporary directory. The self-test deletes those roots on success
or failure, and never emits or persists the raw test-key bytes in a report.
#>

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$script:AssertionCount = 0

$initializerPath = Join-Path $PSScriptRoot "initialize_lab_attestation.ps1"
if (-not (Test-Path -LiteralPath $initializerPath -PathType Leaf)) {
    throw "Attestation initializer not found: $initializerPath"
}

$powerShellExecutable = Join-Path $PSHOME "pwsh.exe"
if (-not (Test-Path -LiteralPath $powerShellExecutable -PathType Leaf)) {
    throw "PowerShell 7 executable not found: $powerShellExecutable"
}

function Invoke-Initializer {
    param(
        [Parameter(Mandatory = $true)]
        [string]$TestTrustRoot,
        [switch]$WithoutTestMode
    )

    $startInfo = [System.Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = $powerShellExecutable
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $arguments = [System.Collections.Generic.List[string]]::new()
    foreach ($argument in @(
        "-NoLogo",
        "-NoProfile",
        "-NonInteractive",
        "-File",
        $initializerPath
    )) {
        [void]$arguments.Add($argument)
    }
    if (-not $WithoutTestMode) {
        [void]$arguments.Add("-TestMode")
    }
    [void]$arguments.Add("-TrustRoot")
    [void]$arguments.Add($TestTrustRoot)
    foreach ($argument in $arguments) {
        [void]$startInfo.ArgumentList.Add($argument)
    }

    $process = [System.Diagnostics.Process]::new()
    $process.StartInfo = $startInfo
    try {
        if (-not $process.Start()) {
            throw "Could not start the initializer child process."
        }
        $stdoutTask = $process.StandardOutput.ReadToEndAsync()
        $stderrTask = $process.StandardError.ReadToEndAsync()
        if (-not $process.WaitForExit(30000)) {
            $process.Kill($true)
            throw "Attestation initializer exceeded its 30-second test limit."
        }
        $process.WaitForExit()
        return [pscustomobject]@{
            ExitCode = $process.ExitCode
            Stdout = $stdoutTask.GetAwaiter().GetResult()
            Stderr = $stderrTask.GetAwaiter().GetResult()
        }
    } finally {
        $process.Dispose()
    }
}

function Assert-True {
    param(
        [Parameter(Mandatory = $true)]
        [bool]$Condition,
        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    if (-not $Condition) {
        throw $Message
    }
    $script:AssertionCount += 1
}

function Assert-NoRawSecret {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Text,
        [Parameter(Mandatory = $true)]
        [byte[]]$Secret,
        [Parameter(Mandatory = $true)]
        [string]$Context
    )

    $rawHex = [System.Convert]::ToHexString($Secret).ToLowerInvariant()
    $rawBase64 = [System.Convert]::ToBase64String($Secret)
    Assert-True `
        -Condition (-not $Text.Contains(
            $rawHex,
            [System.StringComparison]::OrdinalIgnoreCase
        )) `
        -Message "$Context exposed the raw key as hexadecimal."
    Assert-True `
        -Condition (-not $Text.Contains(
            $rawBase64,
            [System.StringComparison]::Ordinal
        )) `
        -Message "$Context exposed the raw key as base64."
}

function Assert-OwnerSystemOnlyAcl {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $currentSid = (
        [System.Security.Principal.WindowsIdentity]::GetCurrent().User.Value
    )
    $systemSid = "S-1-5-18"
    $acl = Get-Acl -LiteralPath $Path
    Assert-True `
        -Condition $acl.AreAccessRulesProtected `
        -Message "ACL inherited access rules: $Path"
    Assert-True `
        -Condition (
            $acl.GetOwner(
                [System.Security.Principal.SecurityIdentifier]
            ).Value -eq $currentSid
        ) `
        -Message "ACL had an unexpected owner: $Path"

    $rightsBySid = @{}
    $rules = @($acl.GetAccessRules(
        $true,
        $true,
        [System.Security.Principal.SecurityIdentifier]
    ))
    foreach ($rule in $rules) {
        Assert-True `
            -Condition (
                $rule.IdentityReference.Value -in @(
                    $currentSid,
                    $systemSid
                ) -and
                -not $rule.IsInherited -and
                $rule.AccessControlType -eq (
                    [System.Security.AccessControl.AccessControlType]::Allow
                )
            ) `
            -Message "ACL exposed an unexpected principal: $Path"
        if (-not $rightsBySid.ContainsKey($rule.IdentityReference.Value)) {
            $rightsBySid[$rule.IdentityReference.Value] = [int64]0
        }
        $rightsBySid[$rule.IdentityReference.Value] = (
            [int64]$rightsBySid[$rule.IdentityReference.Value] -bor
            [int64]$rule.FileSystemRights
        )
    }

    $fullControl = [int64](
        [System.Security.AccessControl.FileSystemRights]::FullControl
    )
    foreach ($sid in @($currentSid, $systemSid)) {
        Assert-True `
            -Condition (
                $rightsBySid.ContainsKey($sid) -and
                (
                    [int64]$rightsBySid[$sid] -band $fullControl
                ) -eq $fullControl
            ) `
            -Message "ACL omitted required full control: $Path"
    }
}

$suiteRoot = Join-Path ([System.IO.Path]::GetTempPath()) (
    "sporespore_lab_attestation_initializer_test_" +
    [guid]::NewGuid().ToString("N")
)
$validRoot = Join-Path $suiteRoot "valid"
$malformedRoot = Join-Path $suiteRoot "malformed"

try {
    [void][System.IO.Directory]::CreateDirectory($suiteRoot)

    # 1. First initialization creates exactly one 32-byte key and a public
    # pointer, and returns only the declared safe metadata fields.
    $first = Invoke-Initializer -TestTrustRoot $validRoot
    Assert-True `
        -Condition ($first.ExitCode -eq 0) `
        -Message "First initialization failed: $($first.Stderr)"
    $firstResult = $first.Stdout | ConvertFrom-Json
    $expectedResultFields = @(
        "active_key_pointer",
        "fingerprint",
        "key_id",
        "key_path",
        "receipts_directory",
        "trust_root"
    )
    $actualResultFields = @(
        $firstResult.PSObject.Properties.Name | Sort-Object
    )
    Assert-True `
        -Condition (
            @(
                Compare-Object `
                    $expectedResultFields `
                    $actualResultFields
            ).Count -eq 0
        ) `
        -Message "Initializer output contained an unexpected field."
    Assert-True `
        -Condition ($firstResult.key_id -ceq (
            "sha256:" + $firstResult.fingerprint
        )) `
        -Message "Initializer key_id did not match its public fingerprint."
    Assert-True `
        -Condition (
            $firstResult.fingerprint -cmatch '^[0-9a-f]{64}$'
        ) `
        -Message "Initializer fingerprint was not canonical lowercase SHA-256."

    $keyPath = [string]$firstResult.key_path
    $pointerPath = [string]$firstResult.active_key_pointer
    Assert-True `
        -Condition (Test-Path -LiteralPath $keyPath -PathType Leaf) `
        -Message "First initialization did not create its key file."
    Assert-True `
        -Condition (Test-Path -LiteralPath $pointerPath -PathType Leaf) `
        -Message "First initialization did not create its public pointer."
    $firstKeyBytes = [System.IO.File]::ReadAllBytes($keyPath)
    $firstPointerBytes = [System.IO.File]::ReadAllBytes($pointerPath)
    Assert-True `
        -Condition ($firstKeyBytes.Length -eq 32) `
        -Message "Generated key was not exactly 32 bytes."
    Assert-NoRawSecret `
        -Text ($first.Stdout + $first.Stderr) `
        -Secret $firstKeyBytes `
        -Context "First initialization output"
    $pointerText = [System.IO.File]::ReadAllText($pointerPath)
    Assert-NoRawSecret `
        -Text $pointerText `
        -Secret $firstKeyBytes `
        -Context "Active-key pointer"
    foreach ($securedPath in @(
        $validRoot,
        (Join-Path $validRoot "keys"),
        (Join-Path $validRoot "receipts"),
        $keyPath,
        $pointerPath
    )) {
        Assert-OwnerSystemOnlyAcl -Path $securedPath
    }

    # 2. A second invocation is idempotent: it reports the same public state
    # without regenerating or rewriting either key or pointer bytes.
    $second = Invoke-Initializer -TestTrustRoot $validRoot
    Assert-True `
        -Condition ($second.ExitCode -eq 0) `
        -Message "Idempotent initialization failed: $($second.Stderr)"
    $secondKeyBytes = [System.IO.File]::ReadAllBytes($keyPath)
    $secondPointerBytes = [System.IO.File]::ReadAllBytes($pointerPath)
    Assert-True `
        -Condition (
            [System.Linq.Enumerable]::SequenceEqual[byte](
                $firstKeyBytes,
                $secondKeyBytes
            )
        ) `
        -Message "Idempotent initialization changed active key bytes."
    Assert-True `
        -Condition (
            [System.Linq.Enumerable]::SequenceEqual[byte](
                $firstPointerBytes,
                $secondPointerBytes
            )
        ) `
        -Message "Idempotent initialization changed pointer bytes."
    Assert-NoRawSecret `
        -Text ($second.Stdout + $second.Stderr) `
        -Secret $firstKeyBytes `
        -Context "Idempotent initialization output"

    # 3. Valid historical verification keys are preserved. Initialization
    # validates and secures them, but never rewrites or deletes their bytes.
    $oldKeyBytes = [byte[]]::new(32)
    do {
        [System.Security.Cryptography.RandomNumberGenerator]::Fill(
            $oldKeyBytes
        )
        $oldFingerprint = [System.Convert]::ToHexString(
            [System.Security.Cryptography.SHA256]::HashData($oldKeyBytes)
        ).ToLowerInvariant()
        $oldKeyPath = Join-Path (
            Split-Path -Parent $keyPath
        ) "$oldFingerprint.key"
    } while (Test-Path -LiteralPath $oldKeyPath)
    [System.IO.File]::WriteAllBytes($oldKeyPath, $oldKeyBytes)
    $withOldKey = Invoke-Initializer -TestTrustRoot $validRoot
    Assert-True `
        -Condition ($withOldKey.ExitCode -eq 0) `
        -Message "Historical verification-key validation failed."
    $oldKeyAfter = [System.IO.File]::ReadAllBytes($oldKeyPath)
    Assert-True `
        -Condition (
            [System.Linq.Enumerable]::SequenceEqual[byte](
                $oldKeyBytes,
                $oldKeyAfter
            )
        ) `
        -Message "Initializer changed historical verification-key bytes."
    Assert-True `
        -Condition (
            @(
                Get-ChildItem `
                    -LiteralPath (Split-Path -Parent $keyPath) `
                    -Filter "*.key" `
                    -File
            ).Count -eq 2
        ) `
        -Message "Initializer did not retain both verification keys."
    Assert-NoRawSecret `
        -Text ($withOldKey.Stdout + $withOldKey.Stderr) `
        -Secret $oldKeyBytes `
        -Context "Historical-key validation output"

    # 4. A malformed existing pointer is refused. The initializer must not
    # silently replace the existing key or manufacture a new one.
    $malformedFirst = Invoke-Initializer -TestTrustRoot $malformedRoot
    Assert-True `
        -Condition ($malformedFirst.ExitCode -eq 0) `
        -Message "Malformed-state fixture setup failed."
    $malformedResult = $malformedFirst.Stdout | ConvertFrom-Json
    $malformedKeyPath = [string]$malformedResult.key_path
    $malformedPointerPath = [string]$malformedResult.active_key_pointer
    $malformedKeyBytes = [System.IO.File]::ReadAllBytes($malformedKeyPath)
    [System.IO.File]::WriteAllText(
        $malformedPointerPath,
        '{"schema_version":"wrong"}',
        [System.Text.UTF8Encoding]::new($false)
    )
    $malformed = Invoke-Initializer -TestTrustRoot $malformedRoot
    Assert-True `
        -Condition ($malformed.ExitCode -ne 0) `
        -Message "Malformed existing state was not refused."
    $malformedKeyAfter = [System.IO.File]::ReadAllBytes($malformedKeyPath)
    Assert-True `
        -Condition (
            [System.Linq.Enumerable]::SequenceEqual[byte](
                $malformedKeyBytes,
                $malformedKeyAfter
            )
        ) `
        -Message "Malformed-state refusal changed existing key bytes."
    $malformedKeyFiles = @(
        Get-ChildItem `
            -LiteralPath (Join-Path $malformedRoot "keys") `
            -Filter "*.key" `
            -File
    )
    Assert-True `
        -Condition ($malformedKeyFiles.Count -eq 1) `
        -Message "Malformed-state refusal generated an additional key."
    Assert-NoRawSecret `
        -Text (
            $malformedFirst.Stdout +
            $malformedFirst.Stderr +
            $malformed.Stdout +
            $malformed.Stderr
        ) `
        -Secret $malformedKeyBytes `
        -Context "Malformed-state output"

    # 5. Test-only path controls cannot be used to redirect production
    # initialization, and the real production trust root was never invoked.
    $outsideTempRoot = Join-Path (
        Split-Path -Parent $PSScriptRoot
    ) ("forbidden-test-trust-root-" + [guid]::NewGuid().ToString("N"))
    $outsideAttempt = Invoke-Initializer -TestTrustRoot $outsideTempRoot
    Assert-True `
        -Condition ($outsideAttempt.ExitCode -ne 0) `
        -Message "Test mode accepted a trust root outside system temp."
    Assert-True `
        -Condition (-not (Test-Path -LiteralPath $outsideTempRoot)) `
        -Message "Rejected test override created a repository trust root."
    $productionOverrideRoot = Join-Path $suiteRoot "production-override"
    $productionOverrideAttempt = Invoke-Initializer `
        -TestTrustRoot $productionOverrideRoot `
        -WithoutTestMode
    Assert-True `
        -Condition ($productionOverrideAttempt.ExitCode -ne 0) `
        -Message "Production mode accepted a trust-root override."
    Assert-True `
        -Condition (-not (Test-Path -LiteralPath $productionOverrideRoot)) `
        -Message "Rejected production override created a trust root."

    Write-Host (
        "LAB_ATTESTATION_INITIALIZER_SELF_TEST " +
        "pass=true assertions=$script:AssertionCount " +
        "production_store_touched=false"
    )
} finally {
    if ($null -ne (Get-Variable firstKeyBytes -ErrorAction SilentlyContinue)) {
        [System.Security.Cryptography.CryptographicOperations]::ZeroMemory(
            $firstKeyBytes
        )
    }
    if (
        $null -ne (
            Get-Variable malformedKeyBytes -ErrorAction SilentlyContinue
        )
    ) {
        [System.Security.Cryptography.CryptographicOperations]::ZeroMemory(
            $malformedKeyBytes
        )
    }
    if ($null -ne (Get-Variable oldKeyBytes -ErrorAction SilentlyContinue)) {
        [System.Security.Cryptography.CryptographicOperations]::ZeroMemory(
            $oldKeyBytes
        )
    }
    if (Test-Path -LiteralPath $suiteRoot) {
        Remove-Item -LiteralPath $suiteRoot -Recurse -Force
    }
}
