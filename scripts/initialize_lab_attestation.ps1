#requires -Version 7.0

<#
.SYNOPSIS
Creates the local root of trust used to attest locomotion-lab evidence.

.DESCRIPTION
Production initialization always uses:

    %LOCALAPPDATA%\SporeSpore\LabTrust\v1

The active HMAC key is 32 cryptographically random bytes stored as a raw file.
The key is never written to JSON or emitted by this script. The public pointer
contains only the algorithm, SHA-256 key fingerprint, and validated relative
key filename.

Initialization is deliberately create-once:

- an already-valid active key is reported without changing its bytes;
- existing verification keys are retained;
- an orphaned key, malformed pointer, or malformed key file is refused;
- neither the key file nor active pointer is silently overwritten.

Production ACLs are fail-closed. The trust directories and files are protected
from inherited access and grant full control only to the current Windows owner
and LocalSystem. A test trust-root override exists only behind the explicit
combination `-TestMode -TrustRoot <child-of-system-temp>`.
#>

[CmdletBinding()]
param(
    [string]$TrustRoot,
    [switch]$TestMode
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$script:ActivePointerSchema = "sporespore.lab_attestation.active_key.v1"
$script:Algorithm = "hmac-sha256"
$script:KeyByteCount = 32
$script:CurrentOwnerSid = $null
$script:SystemSid = [System.Security.Principal.SecurityIdentifier]::new(
    "S-1-5-18"
)

function Get-NormalizedDirectoryPath {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Path
    )

    return [System.IO.Path]::GetFullPath($Path).TrimEnd(
        [System.IO.Path]::DirectorySeparatorChar,
        [System.IO.Path]::AltDirectorySeparatorChar
    )
}

function Test-PathContains {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Parent,
        [Parameter(Mandatory = $true)]
        [string]$Candidate
    )

    $normalizedParent = Get-NormalizedDirectoryPath -Path $Parent
    $normalizedCandidate = Get-NormalizedDirectoryPath -Path $Candidate
    if (
        [string]::Equals(
            $normalizedParent,
            $normalizedCandidate,
            [System.StringComparison]::OrdinalIgnoreCase
        )
    ) {
        return $true
    }

    $prefix = $normalizedParent + [System.IO.Path]::DirectorySeparatorChar
    return $normalizedCandidate.StartsWith(
        $prefix,
        [System.StringComparison]::OrdinalIgnoreCase
    )
}

function Assert-NotReparsePoint {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $item = Get-Item -LiteralPath $Path -Force
    if (
        ($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0
    ) {
        throw "Trust-store paths cannot be reparse points: $Path"
    }
}

function Assert-NoReparseAncestor {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $probe = [System.IO.DirectoryInfo]::new(
        (Get-NormalizedDirectoryPath -Path $Path)
    )
    while ($null -ne $probe) {
        if ($probe.Exists) {
            if (
                ($probe.Attributes -band (
                    [System.IO.FileAttributes]::ReparsePoint
                )) -ne 0
            ) {
                throw (
                    "Trust-store paths cannot traverse a reparse point: " +
                    $probe.FullName
                )
            }
        }
        $probe = $probe.Parent
    }
}

function Get-OwnerSystemDirectorySecurity {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    # Start from the existing descriptor so Set-Acl updates only the owner/DACL
    # sections already available to an ordinary process. Constructing a blank
    # descriptor can make Windows request SeSecurityPrivilege for an unrelated
    # SACL write.
    $security = Get-Acl -LiteralPath $Path
    $actualOwner = $security.GetOwner(
        [System.Security.Principal.SecurityIdentifier]
    )
    if ($actualOwner.Value -ne $script:CurrentOwnerSid.Value) {
        throw "Trust-store path is not owned by the current user: $Path"
    }
    [void]$security.SetAccessRuleProtection($true, $false)
    foreach ($existingRule in @($security.Access)) {
        [void]$security.RemoveAccessRuleSpecific($existingRule)
    }
    $inheritance = (
        [System.Security.AccessControl.InheritanceFlags]::ContainerInherit -bor
        [System.Security.AccessControl.InheritanceFlags]::ObjectInherit
    )
    foreach ($sid in @($script:CurrentOwnerSid, $script:SystemSid)) {
        $rule = [System.Security.AccessControl.FileSystemAccessRule]::new(
            $sid,
            [System.Security.AccessControl.FileSystemRights]::FullControl,
            $inheritance,
            [System.Security.AccessControl.PropagationFlags]::None,
            [System.Security.AccessControl.AccessControlType]::Allow
        )
        [void]$security.AddAccessRule($rule)
    }
    return $security
}

function Get-OwnerSystemFileSecurity {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $security = Get-Acl -LiteralPath $Path
    $actualOwner = $security.GetOwner(
        [System.Security.Principal.SecurityIdentifier]
    )
    if ($actualOwner.Value -ne $script:CurrentOwnerSid.Value) {
        throw "Trust-store file is not owned by the current user: $Path"
    }
    [void]$security.SetAccessRuleProtection($true, $false)
    foreach ($existingRule in @($security.Access)) {
        [void]$security.RemoveAccessRuleSpecific($existingRule)
    }
    foreach ($sid in @($script:CurrentOwnerSid, $script:SystemSid)) {
        $rule = [System.Security.AccessControl.FileSystemAccessRule]::new(
            $sid,
            [System.Security.AccessControl.FileSystemRights]::FullControl,
            [System.Security.AccessControl.AccessControlType]::Allow
        )
        [void]$security.AddAccessRule($rule)
    }
    return $security
}

function Assert-OwnerSystemAcl {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $acl = Get-Acl -LiteralPath $Path
    if (-not $acl.AreAccessRulesProtected) {
        throw "Trust-store ACL still inherits access rules: $Path"
    }

    $actualOwner = $acl.GetOwner(
        [System.Security.Principal.SecurityIdentifier]
    )
    if ($actualOwner.Value -ne $script:CurrentOwnerSid.Value) {
        throw "Trust-store ACL has an unexpected owner: $Path"
    }

    $rightsBySid = @{}
    $rules = @($acl.GetAccessRules(
        $true,
        $true,
        [System.Security.Principal.SecurityIdentifier]
    ))
    foreach ($rule in $rules) {
        $sidValue = $rule.IdentityReference.Value
        if (
            $sidValue -notin @(
                $script:CurrentOwnerSid.Value,
                $script:SystemSid.Value
            ) -or
            $rule.AccessControlType -ne (
                [System.Security.AccessControl.AccessControlType]::Allow
            ) -or
            $rule.IsInherited
        ) {
            throw "Trust-store ACL grants an unexpected principal: $Path"
        }

        if (-not $rightsBySid.ContainsKey($sidValue)) {
            $rightsBySid[$sidValue] = [int64]0
        }
        $rightsBySid[$sidValue] = (
            [int64]$rightsBySid[$sidValue] -bor
            [int64]$rule.FileSystemRights
        )
    }

    $fullControl = [int64](
        [System.Security.AccessControl.FileSystemRights]::FullControl
    )
    foreach ($requiredSid in @(
        $script:CurrentOwnerSid.Value,
        $script:SystemSid.Value
    )) {
        if (
            -not $rightsBySid.ContainsKey($requiredSid) -or
            (
                [int64]$rightsBySid[$requiredSid] -band $fullControl
            ) -ne $fullControl
        ) {
            throw "Trust-store ACL is missing required full control: $Path"
        }
    }
}

function Test-OwnerSystemAcl {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    try {
        Assert-OwnerSystemAcl -Path $Path
        return $true
    } catch {
        return $false
    }
}

function Set-SecureDirectory {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    [void][System.IO.Directory]::CreateDirectory($Path)
    Assert-NotReparsePoint -Path $Path
    if (Test-OwnerSystemAcl -Path $Path) {
        return
    }
    $security = Get-OwnerSystemDirectorySecurity -Path $Path
    try {
        Set-Acl -LiteralPath $Path -AclObject $security
    } catch {
        throw (
            "Could not secure trust-store directory '$Path': " +
            $_.Exception.Message
        )
    }
    Assert-OwnerSystemAcl -Path $Path
}

function Set-SecureFile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "Expected trust-store file does not exist: $Path"
    }
    Assert-NotReparsePoint -Path $Path
    if (Test-OwnerSystemAcl -Path $Path) {
        return
    }
    $security = Get-OwnerSystemFileSecurity -Path $Path
    try {
        Set-Acl -LiteralPath $Path -AclObject $security
    } catch {
        throw (
            "Could not secure trust-store file '$Path': " +
            $_.Exception.Message
        )
    }
    Assert-OwnerSystemAcl -Path $Path
}

function Get-KeyFingerprint {
    param(
        [Parameter(Mandatory = $true)]
        [byte[]]$KeyBytes
    )

    return [System.Convert]::ToHexString(
        [System.Security.Cryptography.SHA256]::HashData($KeyBytes)
    ).ToLowerInvariant()
}

function Read-AndValidateKeyFile {
    param(
        [Parameter(Mandatory = $true)]
        [System.IO.FileInfo]$KeyFile
    )

    if ($KeyFile.Name -notmatch '^(?<fingerprint>[0-9a-f]{64})\.key$') {
        throw "Unexpected key filename in trust store: $($KeyFile.Name)"
    }

    Set-SecureFile -Path $KeyFile.FullName
    $keyBytes = [System.IO.File]::ReadAllBytes($KeyFile.FullName)
    try {
        if ($keyBytes.Length -ne $script:KeyByteCount) {
            throw "Attestation keys must be exactly 32 bytes: $($KeyFile.Name)"
        }
        $actualFingerprint = Get-KeyFingerprint -KeyBytes $keyBytes
        if ($actualFingerprint -ne $Matches.fingerprint) {
            throw "Attestation key fingerprint does not match its filename."
        }
        return $actualFingerprint
    } finally {
        [System.Security.Cryptography.CryptographicOperations]::ZeroMemory(
            $keyBytes
        )
    }
}

function Get-ValidatedActiveState {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Root,
        [Parameter(Mandatory = $true)]
        [string]$KeysDirectory,
        [Parameter(Mandatory = $true)]
        [string]$ReceiptsDirectory,
        [Parameter(Mandatory = $true)]
        [string]$ActivePointerPath
    )

    Set-SecureFile -Path $ActivePointerPath
    try {
        $pointerText = [System.IO.File]::ReadAllText(
            $ActivePointerPath,
            [System.Text.Encoding]::UTF8
        )
        $pointer = $pointerText | ConvertFrom-Json -Depth 4
    } catch {
        throw "Active attestation-key pointer is not valid JSON."
    }

    $expectedProperties = @(
        "algorithm",
        "key_file",
        "key_id",
        "schema_version"
    )
    $actualProperties = @(
        $pointer.PSObject.Properties.Name | Sort-Object
    )
    if (
        @(
            Compare-Object $expectedProperties $actualProperties
        ).Count -ne 0
    ) {
        throw "Active attestation-key pointer has an unexpected shape."
    }
    if (
        $pointer.schema_version -isnot [string] -or
        $pointer.schema_version -ne $script:ActivePointerSchema -or
        $pointer.algorithm -isnot [string] -or
        $pointer.algorithm -ne $script:Algorithm -or
        $pointer.key_id -isnot [string] -or
        $pointer.key_file -isnot [string]
    ) {
        throw "Active attestation-key pointer has invalid metadata."
    }
    if ($pointer.key_id -notmatch '^sha256:(?<fingerprint>[0-9a-f]{64})$') {
        throw "Active attestation-key pointer has an invalid key_id."
    }

    $fingerprint = $Matches.fingerprint
    $expectedRelativeKeyFile = "keys/$fingerprint.key"
    if ($pointer.key_file -cne $expectedRelativeKeyFile) {
        throw "Active attestation-key pointer has an invalid key_file."
    }
    $canonicalPointerText = (
        [ordered]@{
            schema_version = $script:ActivePointerSchema
            algorithm = $script:Algorithm
            key_id = "sha256:$fingerprint"
            key_file = $expectedRelativeKeyFile
        } | ConvertTo-Json -Compress
    )
    if ($pointerText -cne $canonicalPointerText) {
        throw "Active attestation-key pointer is not canonical JSON."
    }

    $keyEntries = @(
        Get-ChildItem -LiteralPath $KeysDirectory -Force |
            Sort-Object Name
    )
    if ($keyEntries.Count -eq 0) {
        throw "Active attestation-key pointer exists without any key files."
    }
    foreach ($entry in $keyEntries) {
        if ($entry.PSIsContainer -or $entry.Extension -cne ".key") {
            throw "Unexpected entry in attestation key directory: $($entry.Name)"
        }
        [void](Read-AndValidateKeyFile -KeyFile $entry)
    }

    $activeKeyPath = Join-Path $Root (
        $expectedRelativeKeyFile.Replace(
            "/",
            [System.IO.Path]::DirectorySeparatorChar
        )
    )
    if (-not (Test-Path -LiteralPath $activeKeyPath -PathType Leaf)) {
        throw "Active attestation key file is missing."
    }

    return [ordered]@{
        key_id = "sha256:$fingerprint"
        fingerprint = $fingerprint
        trust_root = $Root
        key_path = $activeKeyPath
        active_key_pointer = $ActivePointerPath
        receipts_directory = $ReceiptsDirectory
    }
}

if (-not $IsWindows) {
    throw (
        "Lab attestation initialization requires Windows ACL support and " +
        "fails closed when that support is unavailable."
    )
}

$script:CurrentOwnerSid = (
    [System.Security.Principal.WindowsIdentity]::GetCurrent().User
)
if ($null -eq $script:CurrentOwnerSid) {
    throw "Could not determine the current Windows owner SID."
}

$repositoryRoot = Get-NormalizedDirectoryPath -Path (
    Split-Path -Parent $PSScriptRoot
)
$trustRootWasOverridden = $PSBoundParameters.ContainsKey("TrustRoot")
if ($TestMode) {
    if (
        -not $trustRootWasOverridden -or
        [string]::IsNullOrWhiteSpace($TrustRoot)
    ) {
        throw "Test mode requires an explicit -TrustRoot."
    }
    $resolvedTrustRoot = Get-NormalizedDirectoryPath -Path $TrustRoot
    $systemTempRoot = Get-NormalizedDirectoryPath -Path (
        [System.IO.Path]::GetTempPath()
    )
    if (
        -not (Test-PathContains `
            -Parent $systemTempRoot `
            -Candidate $resolvedTrustRoot) -or
        [string]::Equals(
            $systemTempRoot,
            $resolvedTrustRoot,
            [System.StringComparison]::OrdinalIgnoreCase
        )
    ) {
        throw "Test trust roots must be explicit children of the system temp."
    }
} else {
    if ($trustRootWasOverridden) {
        throw "A trust-root override is permitted only with -TestMode."
    }
    if ([string]::IsNullOrWhiteSpace($env:LOCALAPPDATA)) {
        throw "LOCALAPPDATA is required for the production trust root."
    }
    $resolvedTrustRoot = Get-NormalizedDirectoryPath -Path (
        [System.IO.Path]::Combine(
            $env:LOCALAPPDATA,
            "SporeSpore",
            "LabTrust",
            "v1"
        )
    )
}

# Reject either direction of containment. Securing a repository ancestor would
# be as dangerous as storing the secret inside the repository itself.
if (
    (Test-PathContains `
        -Parent $repositoryRoot `
        -Candidate $resolvedTrustRoot) -or
    (Test-PathContains `
        -Parent $resolvedTrustRoot `
        -Candidate $repositoryRoot)
) {
    throw "The lab trust root must be isolated from the repository tree."
}
Assert-NoReparseAncestor -Path $resolvedTrustRoot

$keysDirectory = Join-Path $resolvedTrustRoot "keys"
$receiptsDirectory = Join-Path $resolvedTrustRoot "receipts"
$activePointerPath = Join-Path $resolvedTrustRoot "active_key.json"
$initializationLockPath = Join-Path $resolvedTrustRoot ".initialize.lock"

Set-SecureDirectory -Path $resolvedTrustRoot
Assert-NoReparseAncestor -Path $resolvedTrustRoot
Set-SecureDirectory -Path $keysDirectory
Set-SecureDirectory -Path $receiptsDirectory

$lockStream = $null
$outputJson = $null
$createdKeyPath = $null
$createdPointerPath = $false
$temporaryPointerPath = $null
try {
    try {
        $lockStream = [System.IO.FileStream]::new(
            $initializationLockPath,
            [System.IO.FileMode]::CreateNew,
            [System.IO.FileAccess]::ReadWrite,
            [System.IO.FileShare]::None
        )
    } catch [System.IO.IOException] {
        throw (
            "Attestation initialization is already active or a stale " +
            "initialization lock requires inspection."
        )
    }

    $activePointerExists = Test-Path `
        -LiteralPath $activePointerPath `
        -PathType Leaf
    $keyEntries = @(
        Get-ChildItem -LiteralPath $keysDirectory -Force
    )
    if ($activePointerExists) {
        $result = Get-ValidatedActiveState `
            -Root $resolvedTrustRoot `
            -KeysDirectory $keysDirectory `
            -ReceiptsDirectory $receiptsDirectory `
            -ActivePointerPath $activePointerPath
    } else {
        if ($keyEntries.Count -ne 0) {
            throw (
                "Attestation keys exist without an active pointer; refusing " +
                "silent regeneration."
            )
        }

        $secret = [byte[]]::new($script:KeyByteCount)
        try {
            [System.Security.Cryptography.RandomNumberGenerator]::Fill($secret)
            $fingerprint = Get-KeyFingerprint -KeyBytes $secret
            $createdKeyPath = Join-Path $keysDirectory "$fingerprint.key"
            $keyStream = $null
            try {
                $keyStream = [System.IO.FileStream]::new(
                    $createdKeyPath,
                    [System.IO.FileMode]::CreateNew,
                    [System.IO.FileAccess]::Write,
                    [System.IO.FileShare]::None
                )
                $keyStream.Write($secret, 0, $secret.Length)
                $keyStream.Flush($true)
            } finally {
                if ($null -ne $keyStream) {
                    $keyStream.Dispose()
                }
            }
        } finally {
            [System.Security.Cryptography.CryptographicOperations]::ZeroMemory(
                $secret
            )
        }

        Set-SecureFile -Path $createdKeyPath
        $pointer = [ordered]@{
            schema_version = $script:ActivePointerSchema
            algorithm = $script:Algorithm
            key_id = "sha256:$fingerprint"
            key_file = "keys/$fingerprint.key"
        }
        $pointerBytes = [System.Text.UTF8Encoding]::new($false).GetBytes(
            ($pointer | ConvertTo-Json -Compress)
        )
        $temporaryPointerPath = Join-Path $resolvedTrustRoot (
            ".active_key.$([guid]::NewGuid().ToString('N')).tmp"
        )
        try {
            $pointerStream = $null
            try {
                $pointerStream = [System.IO.FileStream]::new(
                    $temporaryPointerPath,
                    [System.IO.FileMode]::CreateNew,
                    [System.IO.FileAccess]::Write,
                    [System.IO.FileShare]::None
                )
                $pointerStream.Write(
                    $pointerBytes,
                    0,
                    $pointerBytes.Length
                )
                $pointerStream.Flush($true)
            } finally {
                if ($null -ne $pointerStream) {
                    $pointerStream.Dispose()
                }
            }
            Set-SecureFile -Path $temporaryPointerPath
            [System.IO.File]::Move(
                $temporaryPointerPath,
                $activePointerPath,
                $false
            )
            $temporaryPointerPath = $null
            $createdPointerPath = $true
        } finally {
            [System.Security.Cryptography.CryptographicOperations]::ZeroMemory(
                $pointerBytes
            )
        }

        $result = Get-ValidatedActiveState `
            -Root $resolvedTrustRoot `
            -KeysDirectory $keysDirectory `
            -ReceiptsDirectory $receiptsDirectory `
            -ActivePointerPath $activePointerPath
    }

    # JSON is an intentional stable machine-readable interface. It contains
    # only the public key identifier/fingerprint and safe filesystem paths.
    # Hold it until lock cleanup succeeds, so an apparent success record can
    # never precede a failed finalization.
    $outputJson = $result | ConvertTo-Json -Compress
} catch {
    if (
        $null -ne $temporaryPointerPath -and
        (Test-Path -LiteralPath $temporaryPointerPath)
    ) {
        Remove-Item -LiteralPath $temporaryPointerPath -Force
    }
    if (
        $createdPointerPath -and
        (Test-Path -LiteralPath $activePointerPath)
    ) {
        Remove-Item -LiteralPath $activePointerPath -Force
    }
    if (
        $null -ne $createdKeyPath -and
        (Test-Path -LiteralPath $createdKeyPath)
    ) {
        Remove-Item -LiteralPath $createdKeyPath -Force
    }
    throw
} finally {
    if ($null -ne $lockStream) {
        $lockStream.Dispose()
        if (Test-Path -LiteralPath $initializationLockPath) {
            Remove-Item -LiteralPath $initializationLockPath -Force
        }
    }
}

Write-Output $outputJson
