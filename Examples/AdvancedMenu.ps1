<#
    Example: AdvancedMenu
#>

. ..\Write-Menu.ps1

$menuReturn = Write-Menu -Title 'Advanced Menu' -Sort -Entries @{
    'Command Entry' = '(Get-AppxPackage).Name'
    'Invoke Entry' = '@(Get-AppxPackage).Name'
    'Hashtable Entry' = @{
        'Array Entry' = "@('Menu Option 1', 'Menu Option 2', 'Menu Option 3', 'Menu Option 4')"
    }
}

Write-Output $menuReturn
