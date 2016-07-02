# Example: AdvancedMenu

This example generates an advanced/nested menu using multiple hashtables and arrays.

## Input

```powershell
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
```

## Console Output

### Main Menu

```
 Advanced Menu

  AppxPackages
  Nested Hashtable

 Page 1 / 1
```

### AppxPackages

```
 AppxPackages

  Microsoft.NET.Native.Framework.1.1
  Microsoft.NET.Native.Framework.1.1
  Microsoft.NET.Native.Runtime.1.1
  Microsoft.Appconnector
  Microsoft.NET.Native.Runtime.1.1
  Microsoft.WindowsStore
  windows.immersivecontrolpanel
  Microsoft.Windows.ShellExperienceHost
  Microsoft.Windows.Cortana
  Microsoft.AAD.BrokerPlugin

 Page 1 / 3
```

### Nested Hashtable

```
 Nested Hashtable

  Variables
  Custom Entry

 Page 1 / 1
```

###  Variables

```
 Variables

  $
  ?
  ^
  _
  args
  colorBackground
  colorBackgroundSelected
  colorForeground
  colorForegroundSelected
  ConfirmPreference
  ConsoleFileName
  DebugPreference

 Page 1 / 4
```

## Function Output

Returns the selected menu entry.