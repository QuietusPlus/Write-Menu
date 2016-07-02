<#
    Example: AdvancedMenu
#>

# Include
. ..\Write-Menu.ps1

$menuReturn = Write-Menu -Title 'Advanced Menu' -Sort -Entries @{
    'AppxPackages' = '(Get-AppxPackage).Name' # Nested menu using a command
    'Nested Hashtable' = @{ # Manually defined nested menu
        'Custom Entry' = 'Write-Output "Custom Command"' # Command entry
        'Variables' = '(Get-Variable).Name' # Nested menu using a command
    }
}
Write-Host $menuReturn
