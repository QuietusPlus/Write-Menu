# Example: CustomMenu

This example generates a custom menu by manually specifying each entry.

##Input

#####Option 1

```powershell
# Include
. ..\Write-Menu.ps1

$menuReturn = Write-Menu -Title 'Custom Menu' -Entries @('Menu Option 1', 'Menu Option 2', 'Menu Option 3', 'Menu Option 4')
Write-Host $menuReturn
```

#####Option 2

```powershell
# Include
. ..\Write-Menu.ps1

$menuReturn = Write-Menu -Title 'Custom Menu' -Entries @(
    'Menu Option 1'
    'Menu Option 2'
    'Menu Option 3'
    'Menu Option 4'
)
Write-Host $menuReturn
```

##Console Output

```
 Custom Menu

  Menu Option 1
  Menu Option 2
  Menu Option 3
  Menu Option 4

 Page 1 / 1
```

##Function Output

Returns the selected menu entry. For example:

```powershell
Menu Option 3
```
