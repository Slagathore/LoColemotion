function Assert-QuadrupedPackagePathspecs {
    param([Parameter(Mandatory = $true)][string[]]$Pathspecs)
    if ($Pathspecs.Count -eq 0 -or @($Pathspecs | Select-Object -Unique).Count -ne $Pathspecs.Count) {
        throw 'Package source pathspecs are empty or duplicated'
    }
    foreach ($pathspec in $Pathspecs) {
        # Exclusions narrow the declared SDK population. Validate the same
        # anchored path after removing this one supported Git magic prefix.
        $path = $pathspec
        if ($path.StartsWith(':(exclude)', [StringComparison]::Ordinal)) { $path = $path.Substring(10) }
        if ($path -cnotmatch '^sdk/[A-Za-z0-9_./*?-]+$' -or $path -match '(^|/)\.\.?(/|$)') {
            throw "Unsafe package source pathspec: $pathspec"
        }
    }
}
