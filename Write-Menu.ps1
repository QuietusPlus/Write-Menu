# https://raw.githubusercontent.com/QuietusPlus/Write-Menu/master/Write-Menu.ps1
<#
    The MIT License (MIT)

    Copyright (c) 2016 QuietusPlus

    Permission is hereby granted, free of charge, to any person obtaining a copy
    of this software and associated documentation files (the "Software"), to deal
    in the Software without restriction, including without limitation the rights
    to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
    copies of the Software, and to permit persons to whom the Software is
    furnished to do so, subject to the following conditions:

    The above copyright notice and this permission notice shall be included in all
    copies or substantial portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
    IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
    AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
    LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
    OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
    SOFTWARE.
#>

FUNCTION Write-Menu {
<#
    .SYNOPSIS
        Outputs a command-line menu which can be navigated using the keyboard.
    
    .DESCRIPTION
        Outputs a command-line menu which can be navigated using the keyboard.
        
        * Automatically creates multiple pages if the entries cannot fit on-screen.
        * Supports nested menus using a combination of hashtables and arrays.
        * No entry / page limitations (apart from device performance).
        * Sort entries using the -Sort parameter.
        * -MultiSelect: Use space to check a selected entry, all checked entries will be invoked / returned upon confirmation.
        * Jump to the top / bottom of the page using the "Home" and "End" keys.
        * "Scrolling" list effect by automatically switching pages when reaching the top/bottom.
        * Nested menu indicator next to entries.
        * Remembers parent menus: Opening three levels of nested menus means you have to press "Esc" three times.
        
        Controls             Description
        --------             -----------
        Up                   Previous entry
        Down                 Next entry
        Left / PageUp        Previous page
        Right / PageDown     Next page
        Home                 Jump to top
        End                  Jump to bottom
        Space                Check selection (-MultiSelect only)
        Enter                Confirm selection
        Esc / Backspace      Exit / Previous menu
    
    .PARAMETER Entries
        Array or hashtable containing the menu entries
    
    .PARAMETER Title
        Title shown at the top of the menu.
    
    .PARAMETER Sort
        Sort entries before they are displayed.
    
    .PARAMETER MultiSelect
        Select multiple menu entries using space, each selected entry will then get invoked (this will disable nested menu's).
    
    .PARAMETER NameProperty
        A description of the NameProperty parameter.
    
    .PARAMETER ReturnProperty
        A description of the ReturnProperty parameter.
    
    .EXAMPLE
        PS C:\>$menuReturn = Write-Menu -Title 'Menu Title' -Entries @('Menu Option 1', 'Menu Option 2', 'Menu Option 3', 'Menu Option 4')
        
        Output:
        
        Menu Title
        
        Menu Option 1
        Menu Option 2
        Menu Option 3
        Menu Option 4
    
    .EXAMPLE
        PS C:\>$menuReturn = Write-Menu -Title 'AppxPackages' -Entries (Get-AppxPackage).Name -Sort
        
        This example uses Write-Menu to sort and list app packages (Windows Store/Modern Apps) that are installed for the current profile.
    
    .EXAMPLE
        PS C:\>$menuReturn = Write-Menu -Title 'Advanced Menu' -Sort -Entries @{
        'Command Entry' = '(Get-AppxPackage).Name'
        'Invoke Entry' = '@(Get-AppxPackage).Name'
        'Hashtable Entry' = @{
        'Array Entry' = "@('Menu Option 1', 'Menu Option 2', 'Menu Option 3', 'Menu Option 4')"
        }
        }
        
        This example includes all possible entry types:
        
        Command Entry     Invoke without opening as nested menu (does not contain any prefixes)
        Invoke Entry      Invoke and open as nested menu (contains the "@" prefix)
        Hashtable Entry   Opened as a nested menu
        Array Entry       Opened as a nested menu
    
    .NOTES
        Write-Menu by QuietusPlus (inspired by "Simple Textbased Powershell Menu" [Michael Albert])
    
    .LINK
        https://quietusplus.github.io/Write-Menu
    
    .LINK
        https://github.com/QuietusPlus/Write-Menu
#>
    
    [CmdletBinding()]
    PARAM
    (
        [Parameter(Mandatory = $true,
                ValueFromPipeline = $true)]
        [ValidateNotNullOrEmpty()]
        [Alias('InputObject')]
        $Entries,
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [Alias('Name')]
        [string]$Title,
        [switch]$Sort,
        [switch]$MultiSelect,
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [string]$NameProperty = 'Name',
        [ValidateSet('Name', 'Value')]
        [string]$ReturnProperty = 'Name'
    )
    
    BEGIN {
        <#
        Configuration
    #>
        
        $script:WriteMenuConfiguration = New-Object System.Management.Automation.PSObject -Property @{            
            # Entry prefix, suffix and padding
            Prefix          = ' '
            Padding         = 2
            Suffix          = ' '
            Nested          = ' >'
            
            # Minimum page width
            Width           = 30
            entryWidth      = $null
            pageWidth       = $null
            
            # Save initial colours
            ForegroundColor = [System.Console]::ForegroundColor
            BackgroundColor = [System.Console]::BackgroundColor
            
            # Save initial window title
            InitialWindowTitle = $host.UI.RawUI.WindowTitle
            WindowTitle = $Title
            # Set menu height
            pageSize        = ($host.UI.RawUI.WindowSize.Height - 5)
            pageTotal = $null
            
            pageCurrent     = 0
            menuEntries     = $null
            menuEntryTotal = $null
        }
        Set-Variable -Scope script -Name WriteMenuConfiguration -Visibility Private        
        
        # Hide cursor        
        [System.Console]::CursorVisible = $false
        
        
        FUNCTION Invoke-CleanUp {
            [System.Console]::CursorVisible = $true
            $host.UI.RawUI.WindowTitle = $script:WriteMenuConfiguration.InitialWindowTitle
        }
        
    <#
        Checks
    #>        
        # Check if entries has been passed
        IF ($null -eq $Entries) {
            Invoke-CleanUp
            THROW "Missing -Entries parameter!"
        }
        
        # Check if host is console
        IF ($host.Name -ne 'ConsoleHost') {
            Invoke-CleanUp
            THROW "[$($host.Name)] Cannot run inside current host, please use a console window instead!"
        }
        
        
    <#
        Set-Color
    #>
        
        FUNCTION Set-Color ([switch]$Inverted) {
            SWITCH ($Inverted) {
                $true {
                    [System.Console]::ForegroundColor = $script:WriteMenuConfiguration.BackgroundColor
                    [System.Console]::BackgroundColor = $script:WriteMenuConfiguration.ForegroundColor
                }
                DEFAULT {
                    [System.Console]::ForegroundColor = $script:WriteMenuConfiguration.ForegroundColor
                    [System.Console]::BackgroundColor = $script:WriteMenuConfiguration.BackgroundColor
                }
            }
        }
        
    <#
        Get-Menu
    #>
        
        FUNCTION Get-Menu ($script:inputEntries) {
            # Clear console
            Clear-Host
            
            # Check if -Title has been provided, if so set window title, otherwise set default.
            IF ($Title -notlike $null) {
                $script:WriteMenuConfiguration.WindowTitle = $Title
                $host.UI.RawUI.WindowTitle = $script:WriteMenuConfiguration.WindowTitle
            } ELSE {
                $script:WriteMenuConfiguration.WindowTitle = 'Menu'
            }
            
            # Convert entries to object
            $script:WriteMenuConfiguration.menuEntries = @()
            SWITCH ($inputEntries.GetType().Name) {
                'String' {
                    # Set total entries
                    $script:WriteMenuConfiguration.menuEntryTotal = 1
                    $script:menuEntryTotal = 1
                    # Create object
                    $script:WriteMenuConfiguration.menuEntries = New-Object PSObject -Property @{
                        Command   = ''
                        Name      = $inputEntries
                        Value     = $inputEntries
                        Selected  = $false
                        onConfirm = 'Name'
                    }; BREAK
                }
                'Object[]' {
                    # Get total entries
                    $script:WriteMenuConfiguration.menuEntryTotal = $inputEntries.Length
                    # Loop through array
                    FOREACH ($i IN 0 .. $($script:WriteMenuConfiguration.menuEntryTotal - 1)) {
                        # Create object
                        $script:WriteMenuConfiguration.menuEntries += New-Object PSObject -Property @{
                            Command = ''
                            Name    = $($inputEntries)[$i].($NameProperty)
                            Value   = $($inputEntries)[$i]
                            Selected = $false
                            onConfirm = 'Name'
                        }; $i++
                    }; BREAK
                }
                'Hashtable' {
                    # Get total entries
                    $script:WriteMenuConfiguration.menuEntryTotal = $inputEntries.Count
                    # Loop through hashtable
                    FOREACH ($i IN 0 .. ($script:WriteMenuConfiguration.menuEntryTotal - 1)) {
                        # Check if hashtable contains a single entry, copy values directly if true
                        IF ($script:WriteMenuConfiguration.menuEntryTotal -eq 1) {
                            $tempName = $($inputEntries.Keys)
                            $tempCommand = $($inputEntries.Values)
                        } ELSE {
                            $tempName = $($inputEntries.Keys)[$i]
                            $tempCommand = $($inputEntries.Values)[$i]
                        }
                        
                        # Check if command contains nested menu
                        IF ($tempCommand.GetType().Name -eq 'Hashtable') {
                            $tempAction = 'Hashtable'
                        } ELSEIF ($tempCommand.Substring(0, 1) -eq '@') {
                            $tempAction = 'Invoke'
                        } ELSE {
                            $tempAction = 'Command'
                        }
                        
                        # Create object
                        $script:WriteMenuConfiguration.menuEntries += New-Object PSObject -Property @{
                            Name      = $tempName
                            Value     = $tempName
                            Command   = $tempCommand
                            Selected  = $false
                            onConfirm = $tempAction
                        }; $i++
                    }; BREAK
                }
                DEFAULT {
                    THROW "Type `"$($inputEntries.GetType().Name)`" not supported, please use an array or hashtable."
                }
            }
            
            # Sort entries
            IF ($Sort -eq $true) {
                $script:WriteMenuConfiguration.menuEntries = $script:WriteMenuConfiguration.menuEntries | Sort-Object -Property Name
            }
            
            # Get longest entry
            $script:WriteMenuConfiguration.entryWidth = ($script:WriteMenuConfiguration.menuEntries.Name | Measure-Object -Maximum -Property Length).Maximum
            
            # Widen if -MultiSelect is enabled
            IF ($MultiSelect) { $script:WriteMenuConfiguration.entryWidth += 4 }
            # Set minimum entry width
            IF ($script:WriteMenuConfiguration.entryWidth -lt $script:WriteMenuConfiguration.Width) { $script:WriteMenuConfiguration.entryWidth = $script:WriteMenuConfiguration.Width }
            # Set page width
            $script:WriteMenuConfiguration.pageWidth = $script:WriteMenuConfiguration.Prefix.Length + $script:WriteMenuConfiguration.Padding + $script:WriteMenuConfiguration.entryWidth + $script:WriteMenuConfiguration.Padding + $script:WriteMenuConfiguration.Suffix.Length
            
            # Set current + total pages
            $script:WriteMenuConfiguration.pageCurrent = 0
            $script:WriteMenuConfiguration.pageTotal = [math]::Ceiling((($script:WriteMenuConfiguration.menuEntryTotal - $script:WriteMenuConfiguration.pageSize) / $script:WriteMenuConfiguration.pageSize))
            
            # Insert new line
            [System.Console]::WriteLine("")
            
            # Save title line location + write title
            $script:lineTitle = [System.Console]::CursorTop
            [System.Console]::WriteLine("  $($script:WriteMenuConfiguration.WindowTitle)" + "`n")
            
            # Save first entry line location
            $script:lineTop = [System.Console]::CursorTop
        }
        
    <#
        Get-Page
    #>
        
        FUNCTION Get-Page {
            # Update header if multiple pages
            IF ($script:WriteMenuConfiguration.pageTotal -ne 0) { Update-Header }
            
            # Clear entries
            FOR ($i = 0; $i -le $script:WriteMenuConfiguration.pageSize; $i++) {
                # Overwrite each entry with whitespace
                [System.Console]::WriteLine("".PadRight($script:WriteMenuConfiguration.pageWidth) + ' ')
            }
            
            # Move cursor to first entry
            [System.Console]::CursorTop = $lineTop
            
            # Get index of first entry
            $script:pageEntryFirst = ($script:WriteMenuConfiguration.pageSize * $script:WriteMenuConfiguration.pageCurrent)
            
            # Get amount of entries for last page + fully populated page
            IF ($script:WriteMenuConfiguration.pageCurrent -eq $script:WriteMenuConfiguration.pageTotal) {
                $script:pageEntryTotal = ($script:WriteMenuConfiguration.menuEntryTotal - ($script:WriteMenuConfiguration.pageSize * $script:WriteMenuConfiguration.pageTotal))
            } ELSE {
                $script:pageEntryTotal = $script:WriteMenuConfiguration.pageSize
            }
            
            # Set position within console
            $script:lineSelected = 0
            
            # Write all page entries
            FOR ($i = 0; $i -le ($pageEntryTotal - 1); $i++) {
                Write-Entry $i
            }
        }
        
    <#
        Write-Entry
    #>
        
        FUNCTION Write-Entry ([int16]$Index, [switch]$Update) {
            # Check if entry should be highlighted
            SWITCH ($Update) {
                $true { $lineHighlight = $false; BREAK }
                DEFAULT { $lineHighlight = ($Index -eq $lineSelected) }
            }
            
            # Page entry name
            $pageEntry = $script:WriteMenuConfiguration.menuEntries[($pageEntryFirst + $Index)].Name
            
            # Prefix checkbox if -MultiSelect is enabled
            IF ($MultiSelect) {
                SWITCH ($script:WriteMenuConfiguration.menuEntries[($pageEntryFirst + $Index)].Selected) {
                    $true { $pageEntry = "[X] $pageEntry"; BREAK }
                    DEFAULT { $pageEntry = "[ ] $pageEntry" }
                }
            }
            
            # Full width highlight + Nested menu indicator
            SWITCH ($script:WriteMenuConfiguration.menuEntries[($pageEntryFirst + $Index)].onConfirm -in 'Hashtable', 'Invoke') {
                $true { $pageEntry = "$pageEntry".PadRight($script:WriteMenuConfiguration.entryWidth) + "$($script:WriteMenuConfiguration.Nested)"; BREAK }
                DEFAULT { $pageEntry = "$pageEntry".PadRight($script:WriteMenuConfiguration.entryWidth + $script:WriteMenuConfiguration.Nested.Length) }
            }
            
            # Write new line and add whitespace without inverted colours
            [System.Console]::Write("`r" + $script:WriteMenuConfiguration.Prefix)
            # Invert colours if selected
            IF ($lineHighlight) { Set-Color -Inverted }
            # Write page entry
            [System.Console]::Write("".PadLeft($script:WriteMenuConfiguration.Padding) + $pageEntry + "".PadRight($script:WriteMenuConfiguration.Padding))
            # Restore colours if selected
            IF ($lineHighlight) { Set-Color }
            # Entry suffix
            [System.Console]::Write($script:WriteMenuConfiguration.Suffix + "`n")
        }
        
    <#
        Update-Entry
    #>
        
        FUNCTION Update-Entry ([int16]$Index) {
            # Reset current entry
            [System.Console]::CursorTop = ($lineTop + $lineSelected)
            Write-Entry $lineSelected -Update
            
            # Write updated entry
            $script:lineSelected = $Index
            [System.Console]::CursorTop = ($lineTop + $Index)
            Write-Entry $lineSelected
            
            # Move cursor to first entry on page
            [System.Console]::CursorTop = $lineTop
        }
        
    <#
        Update-Header
    #>
        
        FUNCTION Update-Header {
            # Set corrected page numbers
            $pCurrent = ($script:WriteMenuConfiguration.pageCurrent + 1)
            $pTotal = ($script:WriteMenuConfiguration.pageTotal + 1)
            
            # Calculate offset
            $pOffset = ($pTotal.ToString()).Length
            
            # Build string, use offset and padding to right align current page number
            $script:pageNumber = "{0,-$pOffset}{1,0}" -f "$("$pCurrent".PadLeft($pOffset))", "/$pTotal"
            
            # Move cursor to title
            [System.Console]::CursorTop = $lineTitle
            # Move cursor to the right
            [System.Console]::CursorLeft = ($script:WriteMenuConfiguration.pageWidth - ($pOffset * 2) - 1)
            # Write page indicator
            [System.Console]::WriteLine("$pageNumber")
        }
    }
    PROCESS {
        <#
        Initialisation
    #>
        
        # Get menu
        Get-Menu $Entries
        
        # Get page
        Get-Page
        
        # Declare hashtable for nested entries
        $menuNested = [ordered]@{ }
        
    <#
        User Input
    #>
        
        # Loop through user input until valid key has been pressed
        TRY {
            DO {
                $inputLoop = $true
                
                # Move cursor to first entry and beginning of line
                [System.Console]::CursorTop = $lineTop
                [System.Console]::Write("`r")
                
                # Get pressed key
                $menuInput = [System.Console]::ReadKey($false)
                
                # Define selected entry
                $entrySelected = $script:WriteMenuConfiguration.menuEntries[($pageEntryFirst + $lineSelected)]
                
                # Check if key has function attached to it
                SWITCH ($menuInput.Key) {
                    # Exit / Return
                    { $_ -in 'Escape', 'Backspace' } {
                        # Return to parent if current menu is nested
                        IF ($menuNested.Count -ne 0) {
                            $script:WriteMenuConfiguration.pageCurrent = 0
                            $Title = $($menuNested.GetEnumerator())[$menuNested.Count - 1].Name
                            Get-Menu $($menuNested.GetEnumerator())[$menuNested.Count - 1].Value
                            Get-Page
                            $menuNested.RemoveAt($menuNested.Count - 1) | Out-Null
                            # Otherwise exit and return $null
                        } ELSE {
                            Clear-Host
                            $inputLoop = $false
                            Invoke-CleanUp
                            RETURN $null
                        }; BREAK
                    }
                    
                    # Next entry
                    'DownArrow' {
                        IF ($lineSelected -lt ($pageEntryTotal - 1)) {
                            # Check if entry isn't last on page
                            Update-Entry ($lineSelected + 1)
                        } ELSEIF ($script:WriteMenuConfiguration.pageCurrent -ne $script:WriteMenuConfiguration.pageTotal) {
                            # Switch if not on last page
                            $script:WriteMenuConfiguration.pageCurrent++
                            Get-Page
                        }; BREAK
                    }
                    
                    # Previous entry
                    'UpArrow' {
                        IF ($lineSelected -gt 0) {
                            # Check if entry isn't first on page
                            Update-Entry ($lineSelected - 1)
                        } ELSEIF ($script:WriteMenuConfiguration.pageCurrent -ne 0) {
                            # Switch if not on first page
                            $script:WriteMenuConfiguration.pageCurrent--
                            Get-Page
                            Update-Entry ($pageEntryTotal - 1)
                        }; BREAK
                    }
                    
                    # Select top entry
                    'Home' {
                        IF ($lineSelected -ne 0) {
                            # Check if top entry isn't already selected
                            Update-Entry 0
                        } ELSEIF ($script:WriteMenuConfiguration.pageCurrent -ne 0) {
                            # Switch if not on first page
                            $script:WriteMenuConfiguration.pageCurrent--
                            Get-Page
                            Update-Entry ($pageEntryTotal - 1)
                        }; BREAK
                    }
                    
                    # Select bottom entry
                    'End' {
                        IF ($lineSelected -ne ($pageEntryTotal - 1)) {
                            # Check if bottom entry isn't already selected
                            Update-Entry ($pageEntryTotal - 1)
                        } ELSEIF ($script:WriteMenuConfiguration.pageCurrent -ne $script:WriteMenuConfiguration.pageTotal) {
                            # Switch if not on last page
                            $script:WriteMenuConfiguration.pageCurrent++
                            Get-Page
                        }; BREAK
                    }
                    
                    # Next page
                    { $_ -in 'RightArrow', 'PageDown' } {
                        IF ($script:WriteMenuConfiguration.pageCurrent -lt $script:WriteMenuConfiguration.pageTotal) {
                            # Check if already on last page
                            $script:WriteMenuConfiguration.pageCurrent++
                            Get-Page
                        }; BREAK
                    }
                    
                    # Previous page
                    { $_ -in 'LeftArrow', 'PageUp' } {
                        # Check if already on first page
                        IF ($script:WriteMenuConfiguration.pageCurrent -gt 0) {
                            $script:WriteMenuConfiguration.pageCurrent--
                            Get-Page
                        }; BREAK
                    }
                    
                    # Select/check entry if -MultiSelect is enabled
                    'Spacebar' {
                        IF ($MultiSelect) {
                            SWITCH ($entrySelected.Selected) {
                                $true { $entrySelected.Selected = $false }
                                $false { $entrySelected.Selected = $true }
                            }
                            Update-Entry ($lineSelected)
                        }; BREAK
                    }
                    
                    # Select all if -MultiSelect has been enabled
                    'Insert' {
                        IF ($MultiSelect) {
                            $script:WriteMenuConfiguration.menuEntries | ForEach-Object {
                                $_.Selected = $true
                            }
                            Get-Page
                        }; BREAK
                    }
                    
                    # Select none if -MultiSelect has been enabled
                    'Delete' {
                        IF ($MultiSelect) {
                            $script:WriteMenuConfiguration.menuEntries | ForEach-Object {
                                $_.Selected = $false
                            }
                            Get-Page
                        }; BREAK
                    }
                    
                    # Confirm selection
                    'Enter' {
                        # Check if -MultiSelect has been enabled
                        IF ($MultiSelect) {
                            Clear-Host
                            # Process checked/selected entries
                            $script:WriteMenuConfiguration.menuEntries | ForEach-Object {
                                # Entry contains command, invoke it
                                IF (($_.Selected) -and ($_.Command -notlike $null) -and ($entrySelected.Command.GetType().Name -ne 'Hashtable')) {
                                    Invoke-Expression -Command $_.Command
                                    # Return name, entry does not contain command
                                } ELSEIF ($_.Selected) {
                                    Invoke-CleanUp
                                    RETURN $_.($ReturnProperty)
                                }
                            }
                            # Exit and re-enable cursor
                            $inputLoop = $false
                            [System.Console]::CursorVisible = $true
                            BREAK
                        }
                        
                        # Use onConfirm to process entry
                        SWITCH ($entrySelected.onConfirm) {
                            # Return hashtable as nested menu
                            'Hashtable' {
                                $menuNested.$Title = $inputEntries
                                $Title = $entrySelected.Name
                                Get-Menu $entrySelected.Command
                                Get-Page
                                BREAK
                            }
                            
                            # Invoke attached command and return as nested menu
                            'Invoke' {
                                $menuNested.$Title = $inputEntries
                                $Title = $entrySelected.Name
                                Get-Menu $(Invoke-Expression -Command $entrySelected.Command.Substring(1))
                                Get-Page
                                BREAK
                            }
                            
                            # Invoke attached command and exit
                            'Command' {
                                Clear-Host
                                Invoke-Expression -Command $entrySelected.Command
                                $inputLoop = $false
                                BREAK
                            }
                            
                            # Return name and exit
                            'Name' {
                                Clear-Host
                                $inputLoop = $false
                                Invoke-CleanUp
                                RETURN $entrySelected.($ReturnProperty)
                            }
                        }
                    }
                }
            } WHILE ($inputLoop)
        } CATCH {
            THROW $_
        } FINALLY {
            Invoke-CleanUp
        }
        
    }
    END {
    }
}
# SIG # Begin signature block
# MIIdUQYJKoZIhvcNAQcCoIIdQjCCHT4CAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCBqgqC4Mr1sxrhx
# Ve5pT61xkZLOOMhtFhn1BnxL587PWqCCF9cwggQVMIIC/aADAgECAgsEAAAAAAEx
# icZQBDANBgkqhkiG9w0BAQsFADBMMSAwHgYDVQQLExdHbG9iYWxTaWduIFJvb3Qg
# Q0EgLSBSMzETMBEGA1UEChMKR2xvYmFsU2lnbjETMBEGA1UEAxMKR2xvYmFsU2ln
# bjAeFw0xMTA4MDIxMDAwMDBaFw0yOTAzMjkxMDAwMDBaMFsxCzAJBgNVBAYTAkJF
# MRkwFwYDVQQKExBHbG9iYWxTaWduIG52LXNhMTEwLwYDVQQDEyhHbG9iYWxTaWdu
# IFRpbWVzdGFtcGluZyBDQSAtIFNIQTI1NiAtIEcyMIIBIjANBgkqhkiG9w0BAQEF
# AAOCAQ8AMIIBCgKCAQEAqpuOw6sRUSUBtpaU4k/YwQj2RiPZRcWVl1urGr/SbFfJ
# MwYfoA/GPH5TSHq/nYeer+7DjEfhQuzj46FKbAwXxKbBuc1b8R5EiY7+C94hWBPu
# TcjFZwscsrPxNHaRossHbTfFoEcmAhWkkJGpeZ7X61edK3wi2BTX8QceeCI2a3d5
# r6/5f45O4bUIMf3q7UtxYowj8QM5j0R5tnYDV56tLwhG3NKMvPSOdM7IaGlRdhGL
# D10kWxlUPSbMQI2CJxtZIH1Z9pOAjvgqOP1roEBlH1d2zFuOBE8sqNuEUBNPxtyL
# ufjdaUyI65x7MCb8eli7WbwUcpKBV7d2ydiACoBuCQIDAQABo4HoMIHlMA4GA1Ud
# DwEB/wQEAwIBBjASBgNVHRMBAf8ECDAGAQH/AgEAMB0GA1UdDgQWBBSSIadKlV1k
# sJu0HuYAN0fmnUErTDBHBgNVHSAEQDA+MDwGBFUdIAAwNDAyBggrBgEFBQcCARYm
# aHR0cHM6Ly93d3cuZ2xvYmFsc2lnbi5jb20vcmVwb3NpdG9yeS8wNgYDVR0fBC8w
# LTAroCmgJ4YlaHR0cDovL2NybC5nbG9iYWxzaWduLm5ldC9yb290LXIzLmNybDAf
# BgNVHSMEGDAWgBSP8Et/qC5FJK5NUPpjmove4t0bvDANBgkqhkiG9w0BAQsFAAOC
# AQEABFaCSnzQzsm/NmbRvjWek2yX6AbOMRhZ+WxBX4AuwEIluBjH/NSxN8RooM8o
# agN0S2OXhXdhO9cv4/W9M6KSfREfnops7yyw9GKNNnPRFjbxvF7stICYePzSdnno
# 4SGU4B/EouGqZ9uznHPlQCLPOc7b5neVp7uyy/YZhp2fyNSYBbJxb051rvE9ZGo7
# Xk5GpipdCJLxo/MddL9iDSOMXCo4ldLA1c3PiNofKLW6gWlkKrWmotVzr9xG2wSu
# kdduxZi61EfEVnSAR3hYjL7vK/3sbL/RlPe/UOB74JD9IBh4GCJdCC6MHKCX8x2Z
# faOdkdMGRE4EbnocIOM28LZQuTCCBLkwggOhoAMCAQICEEAaxGQhsxMhAw675BIa
# xR0wDQYJKoZIhvcNAQELBQAwgb0xCzAJBgNVBAYTAlVTMRcwFQYDVQQKEw5WZXJp
# U2lnbiwgSW5jLjEfMB0GA1UECxMWVmVyaVNpZ24gVHJ1c3QgTmV0d29yazE6MDgG
# A1UECxMxKGMpIDIwMDggVmVyaVNpZ24sIEluYy4gLSBGb3IgYXV0aG9yaXplZCB1
# c2Ugb25seTE4MDYGA1UEAxMvVmVyaVNpZ24gVW5pdmVyc2FsIFJvb3QgQ2VydGlm
# aWNhdGlvbiBBdXRob3JpdHkwHhcNMDgwNDAyMDAwMDAwWhcNMzcxMjAxMjM1OTU5
# WjCBvTELMAkGA1UEBhMCVVMxFzAVBgNVBAoTDlZlcmlTaWduLCBJbmMuMR8wHQYD
# VQQLExZWZXJpU2lnbiBUcnVzdCBOZXR3b3JrMTowOAYDVQQLEzEoYykgMjAwOCBW
# ZXJpU2lnbiwgSW5jLiAtIEZvciBhdXRob3JpemVkIHVzZSBvbmx5MTgwNgYDVQQD
# Ey9WZXJpU2lnbiBVbml2ZXJzYWwgUm9vdCBDZXJ0aWZpY2F0aW9uIEF1dGhvcml0
# eTCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBAMdhN16xATTbYtcVm/9Y
# WowjI9ZgjpHXkJiDeuZYGTiMxfblZIW0onH77b252s1NALTILXOlx2lxlR85PLJE
# B5zoDvpNSsQh3ylhjzIiYYLFhx9ujHxfFiBRRNFwT1fq4xzjzHnuWNgOwrNFk8As
# 55oXK3sAN3pBM3jhM+LzEBp/hyy+9vX3QuLlv4diiV8AS9/F3eR1RDJBOh5xbmnL
# C3VGCNHK0iuV0M/7uUBrZIxXTfwTEXmE7V5U9jSfCAHzECUGF0ra8R16ZmuYYGak
# 2e/SLoLx8O8J6kTJFWriA24z06yfVQDH9ghqlLlf3OAz8YRg+VsnEbT8FvK7VmqA
# JY0CAwEAAaOBsjCBrzAPBgNVHRMBAf8EBTADAQH/MA4GA1UdDwEB/wQEAwIBBjBt
# BggrBgEFBQcBDARhMF+hXaBbMFkwVzBVFglpbWFnZS9naWYwITAfMAcGBSsOAwIa
# BBSP5dMahqyNjmvDz4Bq1EgYLHsZLjAlFiNodHRwOi8vbG9nby52ZXJpc2lnbi5j
# b20vdnNsb2dvLmdpZjAdBgNVHQ4EFgQUtnf6aUhHn1MS1cLqBzJ2B9GXBxkwDQYJ
# KoZIhvcNAQELBQADggEBAEr4+LAD5ixne+SUd2PMbkz5fQ4N3Mi5NblwT2P6JPps
# g4xHnTtj85r5djKVkbF3vKyavrHkMSHGgZVWWg6xwtSxplms8WPLuEwdWZBK75AW
# KB9arhD7gVA4DGzM8T3D9WPjs+MhySQ56f0VZkb0GxHQTXOjfUb5Pe2oX2LU8T/4
# 4HRXKxidgbTEKNqUl6Vw66wdvgcR8NXb3eWM8NUysIPmV+KPv76hqr89HbXUOOrX
# sFw6T2o/j8BmbGOq6dmkFvSB0ZUUDn3NlTTZ0o9wc4F7nH69mGHYRYeYkMXrhjDG
# Nb/w/8NViINL7wWSBnHyuJiTt+zNgmHxOOZPl5gqWo0wggTGMIIDrqADAgECAgwk
# VLh/HhRTrTf6oXgwDQYJKoZIhvcNAQELBQAwWzELMAkGA1UEBhMCQkUxGTAXBgNV
# BAoTEEdsb2JhbFNpZ24gbnYtc2ExMTAvBgNVBAMTKEdsb2JhbFNpZ24gVGltZXN0
# YW1waW5nIENBIC0gU0hBMjU2IC0gRzIwHhcNMTgwMjE5MDAwMDAwWhcNMjkwMzE4
# MTAwMDAwWjA7MTkwNwYDVQQDDDBHbG9iYWxTaWduIFRTQSBmb3IgTVMgQXV0aGVu
# dGljb2RlIGFkdmFuY2VkIC0gRzIwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEK
# AoIBAQDZeGGhlq4S/6P/J/ZEYHtqVi1n41+fMZIqSO35BYQObU4iVsrYmZeOacqf
# ew8IyCoraNEoYSuf5Cbuurj3sOxeahviWLW0vR0J7c3oPdRm/74iIm02Js8ReJfp
# VQAow+k3Tr0Z5ReESLIcIa3sc9LzqKfpX+g1zoUTpyKbrILp/vFfxBJasfcMQObS
# oOBNaNDtDAwQHY8FX2RV+bsoRwYM2AY/N8MmNiWMew8niFw4MaUB9l5k3oPAFFzg
# 59JezI3qI4AZKrNiLmDHqmfWs0DuUn9WDO/ZBdeVIF2FFUDPXpGVUZ5GGheRvsHA
# B3WyS/c2usVUbF+KG/sNKGHIifAVAgMBAAGjggGoMIIBpDAOBgNVHQ8BAf8EBAMC
# B4AwTAYDVR0gBEUwQzBBBgkrBgEEAaAyAR4wNDAyBggrBgEFBQcCARYmaHR0cHM6
# Ly93d3cuZ2xvYmFsc2lnbi5jb20vcmVwb3NpdG9yeS8wCQYDVR0TBAIwADAWBgNV
# HSUBAf8EDDAKBggrBgEFBQcDCDBGBgNVHR8EPzA9MDugOaA3hjVodHRwOi8vY3Js
# Lmdsb2JhbHNpZ24uY29tL2dzL2dzdGltZXN0YW1waW5nc2hhMmcyLmNybDCBmAYI
# KwYBBQUHAQEEgYswgYgwSAYIKwYBBQUHMAKGPGh0dHA6Ly9zZWN1cmUuZ2xvYmFs
# c2lnbi5jb20vY2FjZXJ0L2dzdGltZXN0YW1waW5nc2hhMmcyLmNydDA8BggrBgEF
# BQcwAYYwaHR0cDovL29jc3AyLmdsb2JhbHNpZ24uY29tL2dzdGltZXN0YW1waW5n
# c2hhMmcyMB0GA1UdDgQWBBTUh7iN5uVAPJ1aBmPGRYTZ3bscwzAfBgNVHSMEGDAW
# gBSSIadKlV1ksJu0HuYAN0fmnUErTDANBgkqhkiG9w0BAQsFAAOCAQEAJHJQpQy8
# QAmmwfTVgmpOQV/Ox4g50+R8+SJsOHi49Lr3a+Ek6518zUisi+y1dkyP3IJpCJbn
# uuFntvCmvxgIQuHrzRlYOaURYSPWGdcA6bvS+V9B+wQ+/oogYAzRTyNaGRoY79jG
# 3tZfVKF6k+G2d4XA+7FGxAmuL1P7lZyOJuJK5MTmPDXvusbZucXNzQebY7s9D2G8
# VXwjELWMiqPSaEWxQLqg3TwbFUC4SXhv5ZTAbVZLPPYSKtSF80gTBeG7MEUKQbd8
# km6+TpJggspbZOZV09IH3p1fm6EB7Zvww127GfAYDJqgHOlqCAs96WaXp3UeD78o
# 1wkjDeIW+rrzNDCCBOgwggPQoAMCAQICEAOTNgSa1j+rIxxh+gL6tRcwDQYJKoZI
# hvcNAQELBQAwgYQxCzAJBgNVBAYTAlVTMR0wGwYDVQQKExRTeW1hbnRlYyBDb3Jw
# b3JhdGlvbjEfMB0GA1UECxMWU3ltYW50ZWMgVHJ1c3QgTmV0d29yazE1MDMGA1UE
# AxMsU3ltYW50ZWMgQ2xhc3MgMyBTSEEyNTYgQ29kZSBTaWduaW5nIENBIC0gRzIw
# HhcNMTcwNzA3MDAwMDAwWhcNMjAwNzA2MjM1OTU5WjB6MQswCQYDVQQGEwJVUzET
# MBEGA1UECAwKQ2FsaWZvcm5pYTEOMAwGA1UEBwwFQ2hpY28xIjAgBgNVBAoMGVNp
# ZXJyYSBOZXZhZGEgQnJld2luZyBDby4xIjAgBgNVBAMMGVNpZXJyYSBOZXZhZGEg
# QnJld2luZyBDby4wggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQDQX54y
# UyAtP+Ri2PM6/g4lzIDwD8AwlEUDVH0Gl2VMXpy2SMG6pc25vrxUlPrq6hl+5xBB
# TrFdgimnfKczk4FTIXNtiUcvihw+kwcBwuwnD+/qCQhl+LGMlkv1fg+3mRglaEe2
# lzb//jYCknRujR16kM9Vba99ygN6LagkKlWPCA1ZIBwccJn9Zod0C2wR2V6e8kdC
# MMQTXwR6JB1xGwVPAstxQ/dG5vLpaqK2OV9UIyww5/a4h0nJZ2W2vrhvxMbAceBL
# 3kkxgKCojqgWDRq5CXULFSd4Y8Tnw+WntIiQ0Ktdm1m2KtxGZyBEW241198StJm/
# wbPTzmlhMsCWqQazAgMBAAGjggFdMIIBWTAJBgNVHRMEAjAAMA4GA1UdDwEB/wQE
# AwIHgDArBgNVHR8EJDAiMCCgHqAchhpodHRwOi8vcmIuc3ltY2IuY29tL3JiLmNy
# bDBhBgNVHSAEWjBYMFYGBmeBDAEEATBMMCMGCCsGAQUFBwIBFhdodHRwczovL2Qu
# c3ltY2IuY29tL2NwczAlBggrBgEFBQcCAjAZDBdodHRwczovL2Quc3ltY2IuY29t
# L3JwYTATBgNVHSUEDDAKBggrBgEFBQcDAzBXBggrBgEFBQcBAQRLMEkwHwYIKwYB
# BQUHMAGGE2h0dHA6Ly9yYi5zeW1jZC5jb20wJgYIKwYBBQUHMAKGGmh0dHA6Ly9y
# Yi5zeW1jYi5jb20vcmIuY3J0MB8GA1UdIwQYMBaAFNTABiJJ6zlL3ZPiXKG4R3YJ
# cgNYMB0GA1UdDgQWBBTFMjWJBWwwkUE0EPhUDR6g4X691TANBgkqhkiG9w0BAQsF
# AAOCAQEAS1hnQhGpjLWyPDffafcXLl2eISntgPkX6nknE7PBSG4RUMRlk5J3i9JK
# loVscSnY5OwSOjFXxTPUvPPGT31mYHdyMAGcj0y1Oe83FRMlk2etB+MVW7K/AbR0
# EliGRRmydbop2JG69Rv1EHcIDSyXeMxrDW7rdiPDWiRMBZCSV37NpkJF4HFEb9WP
# 3cnjQhdNEcaHIF/D335Pxa4rtX6H1U+XOTRrorx8xDKDhP6hBAr1wDoX9CdklySr
# aOnex+uNrlN10IVBQjLaTnArdt3pus/+F8eu6fOuZkPybjINJ40ducyDOXt68TR8
# oxAwrE6M7q7ikr4YzT+CPQqQ24CG5jCCBUcwggQvoAMCAQICEHwbNTVK59t050Ff
# EWnKa6gwDQYJKoZIhvcNAQELBQAwgb0xCzAJBgNVBAYTAlVTMRcwFQYDVQQKEw5W
# ZXJpU2lnbiwgSW5jLjEfMB0GA1UECxMWVmVyaVNpZ24gVHJ1c3QgTmV0d29yazE6
# MDgGA1UECxMxKGMpIDIwMDggVmVyaVNpZ24sIEluYy4gLSBGb3IgYXV0aG9yaXpl
# ZCB1c2Ugb25seTE4MDYGA1UEAxMvVmVyaVNpZ24gVW5pdmVyc2FsIFJvb3QgQ2Vy
# dGlmaWNhdGlvbiBBdXRob3JpdHkwHhcNMTQwNzIyMDAwMDAwWhcNMjQwNzIxMjM1
# OTU5WjCBhDELMAkGA1UEBhMCVVMxHTAbBgNVBAoTFFN5bWFudGVjIENvcnBvcmF0
# aW9uMR8wHQYDVQQLExZTeW1hbnRlYyBUcnVzdCBOZXR3b3JrMTUwMwYDVQQDEyxT
# eW1hbnRlYyBDbGFzcyAzIFNIQTI1NiBDb2RlIFNpZ25pbmcgQ0EgLSBHMjCCASIw
# DQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBANeVQ9Tc32euOftSpLYmMQRw6beO
# Wyq6N2k1lY+7wDDnhthzu9/r0XY/ilaO6y1L8FcYTrGNpTPTC3Uj1Wp5J92j0/cO
# h2W13q0c8fU1tCJRryKhwV1LkH/AWU6rnXmpAtceSbE7TYf+wnirv+9SrpyvCNk5
# 5ZpRPmlfMBBOcWNsWOHwIDMbD3S+W8sS4duMxICUcrv2RZqewSUL+6McntimCXBx
# 7MBHTI99w94Zzj7uBHKOF9P/8LIFMhlM07Acn/6leCBCcEGwJoxvAMg6ABFBekGw
# p4qRBKCZePR3tPNgKuZsUAS3FGD/DVH0qIuE/iHaXF599Sl5T7BEdG9tcv8CAwEA
# AaOCAXgwggF0MC4GCCsGAQUFBwEBBCIwIDAeBggrBgEFBQcwAYYSaHR0cDovL3Mu
# c3ltY2QuY29tMBIGA1UdEwEB/wQIMAYBAf8CAQAwZgYDVR0gBF8wXTBbBgtghkgB
# hvhFAQcXAzBMMCMGCCsGAQUFBwIBFhdodHRwczovL2Quc3ltY2IuY29tL2NwczAl
# BggrBgEFBQcCAjAZGhdodHRwczovL2Quc3ltY2IuY29tL3JwYTA2BgNVHR8ELzAt
# MCugKaAnhiVodHRwOi8vcy5zeW1jYi5jb20vdW5pdmVyc2FsLXJvb3QuY3JsMBMG
# A1UdJQQMMAoGCCsGAQUFBwMDMA4GA1UdDwEB/wQEAwIBBjApBgNVHREEIjAgpB4w
# HDEaMBgGA1UEAxMRU3ltYW50ZWNQS0ktMS03MjQwHQYDVR0OBBYEFNTABiJJ6zlL
# 3ZPiXKG4R3YJcgNYMB8GA1UdIwQYMBaAFLZ3+mlIR59TEtXC6gcydgfRlwcZMA0G
# CSqGSIb3DQEBCwUAA4IBAQB/68qn6ot2Qus+jiBUMOO3udz6SD4Wxw9FlRDNJ4aj
# ZvMC7XH4qsJVl5Fwg/lSflJpPMnx4JRGgBi7odSkVqbzHQCR1YbzSIfgy8Q0aCBe
# tMv5Be2cr3BTJ7noPn5RoGlxi9xR7YA6JTKfRK9uQyjTIXW7l9iLi4z+qQRGBIX3
# FZxLEY3ELBf+1W5/muJWkvGWs60t+fTf2omZzrI4RMD3R3vKJbn6Kmgzm1By3qif
# 1M0sCzS9izB4QOCNjicbkG8avggVgV3rL+JR51EeyXgp5x5lvzjvAUoBCSQOFsQU
# ecFBNzTQPZFSlJ3haO8I8OJpnGdukAsak3HUJgLDwFojMYIE0DCCBMwCAQEwgZkw
# gYQxCzAJBgNVBAYTAlVTMR0wGwYDVQQKExRTeW1hbnRlYyBDb3Jwb3JhdGlvbjEf
# MB0GA1UECxMWU3ltYW50ZWMgVHJ1c3QgTmV0d29yazE1MDMGA1UEAxMsU3ltYW50
# ZWMgQ2xhc3MgMyBTSEEyNTYgQ29kZSBTaWduaW5nIENBIC0gRzICEAOTNgSa1j+r
# Ixxh+gL6tRcwDQYJYIZIAWUDBAIBBQCgTDAZBgkqhkiG9w0BCQMxDAYKKwYBBAGC
# NwIBBDAvBgkqhkiG9w0BCQQxIgQgv3zFMtV04eFqkoEya0K2iasGT3/gD5md6pRX
# BzvhGJ4wDQYJKoZIhvcNAQEBBQAEggEAnicARaBv5bfMFJBL99WtDgZDGFkzN+Xq
# g/C7bJERgjFigYZBMMqRyfFsx633ettKl4nd9jzeQKH+y2/eyeqfrVgnK5jabNtO
# b56qArKeL/ydi2pSqTAAEoLvottYRgCJ3C7s50g/Q26whhzhdzx3RLXKfO2l0QQU
# 7FTiipM2e0sUeneijI9F6yAYjUfdXqk4bVl21+L1+k5U97TebkQGfBt4v977KFGY
# +49zg79bYEjS9JvHbshXfUU8z2jwbL0rPbtczYMz0NC8AvwhWcxJrN1FcxYRwBFR
# RgCMZtB8R/gY+akN22PeE5agbn64+mvQaqSURanYJ6lypIEvbMi7qKGCArkwggK1
# BgkqhkiG9w0BCQYxggKmMIICogIBATBrMFsxCzAJBgNVBAYTAkJFMRkwFwYDVQQK
# ExBHbG9iYWxTaWduIG52LXNhMTEwLwYDVQQDEyhHbG9iYWxTaWduIFRpbWVzdGFt
# cGluZyBDQSAtIFNIQTI1NiAtIEcyAgwkVLh/HhRTrTf6oXgwDQYJYIZIAWUDBAIB
# BQCgggEMMBgGCSqGSIb3DQEJAzELBgkqhkiG9w0BBwEwHAYJKoZIhvcNAQkFMQ8X
# DTE5MDIxNDIzMzQ0OFowLwYJKoZIhvcNAQkEMSIEIGUBhOY7B6DT7abWS/bTE+aF
# yrHunBZyuZ6eBDlNDjVBMIGgBgsqhkiG9w0BCRACDDGBkDCBjTCBijCBhwQUPsdm
# 1dTUcuIbHyFDUhwxt5DZS2gwbzBfpF0wWzELMAkGA1UEBhMCQkUxGTAXBgNVBAoT
# EEdsb2JhbFNpZ24gbnYtc2ExMTAvBgNVBAMTKEdsb2JhbFNpZ24gVGltZXN0YW1w
# aW5nIENBIC0gU0hBMjU2IC0gRzICDCRUuH8eFFOtN/qheDANBgkqhkiG9w0BAQEF
# AASCAQCl2YcJIpRaSL0WPOk33K6+DP0MQRV9OpBeCceOKp9t6K89ok9aFvbOtXbC
# qh3A+m4UxROW2V+8AFoKwCYjfpC8pfXdb9R02ZIMc+hIFAgp4atpm+36KqnuMSAK
# oVa4FcAy95NOAyl4/XB4T7BK5y963rnW1ZOzEw2+H4bnzlydeuvOChaXlSAX7zNF
# InNeygyj18wT5KPwgmoj+/7n4p8quN9j0xdnlAirvEsnoVS7aCdAO46T5cRKY4GY
# gVika0qd0XgSkiqACRbr3cY1nTd/+EMbgFGc8K+yMolUNx/nFnE5vUa3HGgLeLJe
# IzToAh1kqqPoIc17rXXa4XXwINzs
# SIG # End signature block
