<#
    Example: AppxPackages
#>

# Include
Import-Module ..\Write-Menu.psm1

$menuReturn = Write-Menu -Title 'AppxPackages' -Entries (Get-AppxPackage).Name
Write-Host $menuReturn
