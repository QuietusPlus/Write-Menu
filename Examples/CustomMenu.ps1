<#
    Example: CustomMenu
#>

# Include
Import-Module ..\Write-Menu.psm1

$menuReturn = Write-Menu -Title 'Custom Menu' -Entries @(
    'Menu Option 1'
    'Menu Option 2'
    'Menu Option 3'
    'Menu Option 4'
)
Write-Host $menuReturn
