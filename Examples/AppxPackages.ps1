<#
    Example: AppxPackages
#>

# Include
. ..\Write-Menu.ps1

$menuReturn = Write-Menu -Title 'AppxPackages' -Entries (Get-AppxPackage).Name
Write-Host $menuReturn
