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

function Set-ColorInverted {
    [CmdletBinding(SupportsShouldProcess = $true)]

    param(
        [Parameter()]
        [switch]$Force
    )

    begin {
        $PSBoundParameters.Remove('Force') | Out-Null
        $PSBoundParameters.Confirm = $false
    }

    process {
        if ($Force -or $PSCmdlet.ShouldProcess('Invert foreground and background color', $host)) {
            # Get current colours
            $colorForeground = [System.Console]::ForegroundColor
            $colorBackground = [System.Console]::BackgroundColor
            # Invert colours
            [System.Console]::ForegroundColor = $colorBackground
            [System.Console]::BackgroundColor = $colorForeground
        }
    }
}

function Write-Menu {
    <#
        .NOTES
            Write-Menu by QuietusPlus (inspired by "Simple Textbased Powershell Menu" [Michael Albert])

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
            Array / hashtable containing menu entries.

        .PARAMETER Title
            Title shown at the top of the menu.

        .PARAMETER Sort
            Sort entries before they are displayed.

        .PARAMETER MultiSelect
            Use space to check a selected entry, all checked entries will be invoked / returned upon confirmation.

        .PARAMETER IgnoreNested
            Do not check entries for nested hashtables or arrays.

        .EXAMPLE
            PS C:\>$menuReturn = Write-Menu -Title 'Menu Title' -Entries @('Menu Option 1', 'Menu Option 2', 'Menu Option 3', 'Menu Option 4')

            Output:

             Menu Title

              Menu Option 1
              Menu Option 2
              Menu Option 3
              Menu Option 4

             Page 1 / 1

        .EXAMPLE
            PS C:\>$menuReturn = Write-Menu -Title 'AppxPackages' -Entries (Get-AppxPackage).Name -Sort

            This example uses Write-Menu to sort and list app packages (Windows Store/Modern Apps) that are installed for the current profile.

        .EXAMPLE
            PS C:\>$menuReturn = Write-Menu -Title 'Advanced Menu' -Sort -Entries $menuEntries

            $menuEntries = @{
                'AppxPackages' = '(Get-AppxPackage).Name' # Nested menu using a command
                'Nested Hashtable' = @{ # Manually defined nested menu
                    'Custom Entry' = 'Write-Output "Custom Command"' # Command entry
                    'Variables' = '(Get-Variable).Name' # Nested menu using a command
                }
            }

            This example generates an advanced/nested menu using multiple hashtables and arrays.

        .LINK
            https://quietusplus.github.io/Write-Menu

        .LINK
            https://github.com/QuietusPlus/Write-Menu
    #>

    [CmdletBinding()]

    <#
        Parameters
    #>

    param (
        [Parameter(ValueFromPipeline = $true)]
        [Alias('Items')]
        $Entries,

        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [Alias('Name')]
        $Title,

        [Parameter()]
        [switch]$Sort,

        [Parameter()]
        [switch]$MultiSelect,

        [Parameter()]
        [switch]$IgnoreNested
    )

    <#
        Functions
    #>

    function Get-Menu($script:inputEntries) {
        # Set title if provided, adjust menu height accordingly
        if ($Title -notlike $null) {
            $host.UI.RawUI.WindowTitle = $Title
            $script:menuTitle = "`n $Title`n"
            $script:pageSize = ($host.UI.RawUI.WindowSize.Height - 7)
        } else {
            $script:menuTitle = ''
            $script:pageSize = ($host.UI.RawUI.WindowSize.Height - 5)
        }

        # Get entries type
        $inputType = ($inputEntries | ForEach-Object {
            $_.PSObject.TypeNames[0]
        } | Select-Object -First 1)

        # Convert entries to object
        $script:menuEntries = @()
        switch ($inputType) {
            System.String {
                $script:menuEntryTotal = $inputEntries.Length
                foreach ($i in 0..$($menuEntryTotal - 1)) {
                    $script:menuEntries += New-Object PSObject -Property @{
                        Command = $null
                        Name = $($inputEntries)[$i]
                        Selected = $false
                        Nested = ""
                    }; $i++
                }
            }
            System.Collections.Hashtable {
                $script:menuEntryTotal = $inputEntries.Count
                foreach ($i in 0..$($menuEntryTotal - 1)) {
                    # Check for -IgnoreNested and -MultiSelect
                    if ((-not $IgnoreNested) -and (-not $MultiSelect)) {
                        # Check if entry is nested hashtable
                        if ($($inputEntries.Values)[$i].GetType().Name -eq 'Hashtable') {
                            $iNested = $($inputEntries.Values)[$i]
                        # Check if entry is nested array
                        } elseif ((($entryInvoke = $(Invoke-Expression -Command $($inputEntries.Values)[$i])).GetType().BaseType).Name -eq 'Array') {
                            $iNested = $entryInvoke
                        # Otherwise return empty string
                        } else {
                            $iNested = ""
                        }
                    }

                    $script:menuEntries += New-Object PSObject -Property @{
                        Command = $($inputEntries.Values)[$i]
                        Name = $($inputEntries.Keys)[$i]
                        Selected = $false
                        Nested = $iNested
                    }; $i++
                }
            }
        }

        # Sort entries
        if ($Sort -eq $true) {
            $script:menuEntries = $menuEntries | Sort-Object -Property Name
        }

        # Set current page + get total pages + sort entries
        $script:pageCurrent = 0
        $script:pageTotal = [math]::Ceiling((($menuEntryTotal - $pageSize) / $pageSize))
    }

    function Get-Page {
        # Write title
        [System.Console]::WriteLine("$menuTitle")

        # Get index of first entry
        $script:pageEntryFirst = ($pageSize * $pageCurrent)

        # Get amount of entries for last page + fully populated page
        if ($pageCurrent -eq $pageTotal) {
            $script:pageEntryTotal = ($menuEntryTotal - ($pageSize * $pageTotal))
        } else {
            $script:pageEntryTotal = $pageSize
        }

        # Set position within console
        $script:lineCurrent = 0
        $script:lineSelected = 0
        $script:lineTotal = 0
        $script:lineTop = [System.Console]::CursorTop
    }

    <#
        Initialisation
    #>

    # Clear console
    Clear-Host

    # Check dependencies
    if ($Entries -like $null) { Write-Error "Missing -Entries parameter!"; return } # Entries is defined
    if ($host.Name -ne 'ConsoleHost') { # Host is console
        Write-Error "[$($host.Name)] Cannot run inside host, please use a console window instead!"; return
    }

    # Get menu and page + Declare nested hashtable
    Get-Menu $Entries; Get-Page
    $menuNested = [ordered]@{}

    # Start looping through menu
    do { $menuLoop = $true; [System.Console]::CursorTop = ($lineTop - $lineTotal)

        <#
            Write page
        #>

        for ($lineCurrent = 0; $lineCurrent -le ($pageEntryTotal - 1); $lineCurrent++) {
            # Check if entry should be highlighted
            $lineHighlight = ($lineCurrent -eq $lineSelected)

            # Define checkbox when -MultiSelect is enabled
            if ($MultiSelect -and ($menuEntries[($pageEntryFirst + $lineCurrent)].Selected)) {
                $pageEntryCheck = ' [X]'
            } elseif ($MultiSelect) {
                $pageEntryCheck = ' [ ]'
            }

            # Invert colours if selected + Write entry + Reset colours + New line
            if ($lineHighlight) { Set-ColorInverted -Force }
            [System.Console]::Write("`r  " + $pageEntryCheck + $menuEntries[($pageEntryFirst + $lineCurrent)].Name + '  ')
            if ($lineHighlight) { Set-ColorInverted -Force }
            [System.Console]::WriteLine('')
        }

        # Write page indicator + Define selected entry
        [System.Console]::WriteLine("`n Page $($pageCurrent + 1) / $($pageTotal + 1)`n")
        $entrySelected = $menuEntries[($pageEntryFirst + $lineSelected)]

        <#
            User Input
        #>

        # Loop through user input until valid key has been pressed
        do { $inputLoop = $true;  $menuInput = [System.Console]::ReadKey($true)
            switch ($menuInput.Key) {
                # Exit or return
                { $_ -in 'Escape','Backspace' } {
                    Clear-Host
                    # Return to parent if current menu is nested
                    if ($menuNested.Count -ne 0) {
                        $lineSelected = 0; $pageCurrent = 0
                        $Title = $($menuNested.GetEnumerator())[$menuNested.Count - 1].Name
                        Get-Menu $($menuNested.GetEnumerator())[$menuNested.Count - 1].Value; Get-Page
                        $menuNested.RemoveAt($menuNested.Count - 1) | Out-Null
                    # Otherwise exit and return $null
                    } else { $menuLoop = $false; return $null }
                    $inputLoop = $false; break
                }

                # Next and previous entry
                'DownArrow' { if ($lineSelected -lt ($pageEntryTotal - 1)) { $lineSelected++ }; $inputLoop = $false; break }
                'UpArrow' { if ($lineSelected -gt 0) { $lineSelected-- }; $inputLoop = $false; break}

                # Jump to top and bottom of list
                'Home' { $lineSelected = 0; $inputLoop = $false; break}
                'End' { $lineSelected = ($pageEntryTotal - 1); $inputLoop = $false; break }

                # Next page
                { $_ -in 'RightArrow','PageDown' } {
                    if ($pageCurrent -ne $pageTotal) { $pageCurrent++; $lineSelected = 0; Clear-Host; Get-Page }; $inputLoop = $false; break
                }

                # Previous page
                { $_ -in 'LeftArrow','PageUp' } {
                    if ($pageCurrent -ne 0) { $pageCurrent--; $lineSelected = 0; Clear-Host; Get-Page }; $inputLoop = $false; break
                }

                # Check selection (-MultiSelect)
                'Spacebar' {
                    switch ($entrySelected.Selected) {
                        $true { $entrySelected.Selected = $false }
                        $false { $entrySelected.Selected = $true }
                    }; $inputLoop = $false; break
                }


                # Confirm selection
                'Enter' {
                    Clear-Host
                    switch ($entrySelected) {
                        # Check if -MultiSelect has been defined
                        { $MultiSelect } {
                            $menuLoop = $false # Exit menu
                            $menuEntries | ForEach-Object {
                                # Entry contains command, invoke it
                                if (($_.Selected) -and ($_.Command -notlike $null)) {
                                    Invoke-Expression -Command $_.Command
                                # Return name, entry does not contain command
                                } elseif ($_.Selected) { return $_.Name }
                            }; $inputLoop = $false; break
                        }
                        # Check if entry is nested menu
                        { $entrySelected.Nested -notlike $null } {
                            $menuNested.$Title = $inputEntries
                            $Title = $_.Name; $lineSelected = 0
                            Get-Menu $($_.Nested); Get-Page; $inputLoop = $false; break
                        }
                        # Entry has command associated with it, invoke it
                        { $_.Command -notlike $null } { Invoke-Expression -Command $_.Command; $menuLoop = $false; $inputLoop = $false; break }
                        # Return entry name
                        Default { $menuLoop = $false; return $_.Name }
                    }
                }
            }
        } while ($inputLoop)
    } while ($menuLoop)
}
