# Example: AdvancedMenu

This example includes all possible entry types:

```
Command Entry     Invoke without opening as nested menu (does not contain any prefixes)
Invoke Entry      Invoke and open as nested menu (contains the "@" prefix)
Hashtable Entry   Opened as a nested menu
Array Entry       Opened as a nested menu
```

## Input

```powershell
. ..\Write-Menu.ps1

$menuReturn = Write-Menu -Title 'Advanced Menu' -Sort -Entries @{
    'Command Entry' = '(Get-AppxPackage).Name'
    'Invoke Entry' = '@(Get-AppxPackage).Name'
    'Hashtable Entry' = @{
        'Array Entry' = "@('Menu Option 1', 'Menu Option 2', 'Menu Option 3', 'Menu Option 4')"
    }
}

Write-Output $menuReturn
```

## Console Output

### Main Menu

```

  Advanced Menu

   Command Entry
   Hashtable Entry                >
   Invoke Entry                   >

```

### Command

```
...
Microsoft.MicrosoftSolitaireCollection
Microsoft.Advertising.Xaml
Microsoft.BingFinance
Microsoft.BingNews
Microsoft.BingWeather
Microsoft.WindowsMaps
Microsoft.ZuneVideo
Microsoft.WindowsCalculator
Microsoft.XboxApp
...
```

###  Hashtable and Array

```

  Hashtable Entry

   Array Entry                    >

```

```

  Array Entry

   Menu Option 1
   Menu Option 2
   Menu Option 3
   Menu Option 4

```

### Invoke

```

  Invoke Entry                                 2/6

   Microsoft.CommsPhone
   Microsoft.ConnectivityStore
   Microsoft.Getstarted
   Microsoft.LockApp
   Microsoft.Messaging
   Microsoft.MicrosoftEdge
   Microsoft.MicrosoftOfficeHub
   Microsoft.MicrosoftSolitaireCollection
   Microsoft.NET.Native.Framework.1.0
   Microsoft.NET.Native.Framework.1.0
   Microsoft.NET.Native.Framework.1.1
   Microsoft.NET.Native.Framework.1.1
   Microsoft.NET.Native.Framework.1.3

```

## Function Output

Returns the selected menu entry.