<#
    Write-Menu: Outputs a command-line menu which can be navigated using the keyboard.
    Copyright (C) 2016 QuietusPlus

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.
#>

function Write-Menu {
    <#
        .NOTES
            Write-Menu
            by QuietusPlus

            Based on "Simple Textbased Powershell Menu" by Michael Albert [info@michlstechblog.info]

        .SYNOPSIS
            Outputs a command-line menu, which can be navigated using the keyboard.

        .DESCRIPTION
            Outputs a command-line menu, which can be navigated using the keyboard.

            Controls             Description
            --------             -----------
            Arrow Up + Down      Change selection
            Arrow Left + Right   Switch pages
            Enter                Confirm selection
            Escape               Exit menu

        .PARAMETER Entries
            Menu entries.

        .PARAMETER Title
            Title shown at the top.

        .PARAMETER Sort
            Sort entries before they are added to the menu.

        .PARAMETER MultiSelect
            Select multiple entries using spacebar. Confirm returns or executes all checked entries.

        .EXAMPLE
            PS > $menuReturn = Write-Menu -Title 'Menu Title' -Entries @('Menu Option 1', 'Menu Option 2', 'Menu Option 3', 'Menu Option 4')

             Menu Title

              Menu Option 1
              Menu Option 2
              Menu Option 3
              Menu Option 4

             Page 1 / 1

        .EXAMPLE
            PS > $menuReturn = Write-Menu -Title 'AppxPackages' -Entries (Get-AppxPackage).Name -Sort

            This example uses Write-Menu to sort and list app packages (Windows Store/Modern Apps) that are installed for the current profile.

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
        [switch]$MultiSelect
    )

    <#
        Get menu data
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
                    }; $i++
                }
            }
            System.Collections.Hashtable {
                $script:menuEntryTotal = $inputEntries.Count
                foreach ($i in 0..$($menuEntryTotal - 1)) {
                    $script:menuEntries += New-Object PSObject -Property @{
                        Command = $($inputEntries.Values)[$i]
                        Name = $($inputEntries.Keys)[$i]
                        Selected = $false
                    }; $i++
                }
            }
        }

        # Sort entries
        if ($Sort -eq $true) {
            $global:menuEntries = $menuEntries | Sort-Object -Property Name
        }

        # Set current page + get total pages + sort entries
        $script:pageCurrent = 0
        $script:pageTotal = [math]::Ceiling((($menuEntryTotal - $pageSize) / $pageSize))
    }

    <#
        Get page data
    #>

    function Get-Page {
        # Write title
        [System.Console]::WriteLine($menuTitle)

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

    # Clear screen
    Clear-Host

    # Parameter: Entries
    if ($Entries -like $null) {
        Write-Error "Missing -Entries parameter!"
        return
    }

    # Make sure host is console window
    if ($host.Name -ne 'ConsoleHost') {
        Write-Error "[$($host.Name)] Cannot run inside host, please use a console window instead!"
        return
    }

    # Set colours, modify to change colours
    $colorForeground = [System.Console]::ForegroundColor
    $colorBackground = [System.Console]::BackgroundColor

    # Set inverted colours
    $colorForegroundSelected = $colorBackground
    $colorBackgroundSelected = $colorForeground

    # First run
    Get-Menu $Entries
    Get-Page

    # Get menu root
    $menuNested = [ordered]@{}

    <#
        Write page
    #>

    do {
        $menuLoop = $true
        [System.Console]::CursorTop = ($lineTop - $lineTotal)

        # Write entries
        for ($lineCurrent = 0; $lineCurrent -le ($pageEntryTotal - 1); $lineCurrent++) {
            # Move to beginning of line
            [System.Console]::Write("`r")

            # If selected, invert colours
            if ($lineCurrent -eq $lineSelected) {
                [System.Console]::BackgroundColor = $colorBackgroundSelected
                [System.Console]::ForegroundColor = $colorForegroundSelected
            }

            # Define checkbox
            if ($MultiSelect) {
                switch ($menuEntries[($pageEntryFirst + $lineCurrent)].Selected) {
                    $true {
                        $pageEntryCheck = '[X] '
                    }
                	Default {
                        $pageEntryCheck = '[ ] '
                    }
                }
            }

            # Write entry
            [System.Console]::Write('  ' + $pageEntryCheck + $menuEntries[($pageEntryFirst + $lineCurrent)].Name + '  ')

            # Reset colours
            [System.Console]::ForegroundColor = $colorForeground
            [System.Console]::BackgroundColor = $colorBackground

            # Empty line
            [System.Console]::WriteLine('')
        }

        # Write page indicator
        [System.Console]::WriteLine("`n Page $($pageCurrent + 1) / $($pageTotal + 1)`n")

        # Selected entry
        $entrySelected = $menuEntries[($pageEntryFirst + $lineSelected)]

        <#
            User Input
        #>

        $menuInput = [System.Console]::ReadKey($true) # Pressed key
        switch ($menuInput.Key) {

            # Exit
            {$_ -in 'Escape','Backspace'} {
                Clear-Host
                if ($menuNested.Count -ne 0) {
                    $lineSelected = 0
                    $Title = $($menuNested.GetEnumerator())[$menuNested.Count - 1].Name
                    Get-Menu $($menuNested.GetEnumerator())[$menuNested.Count - 1].Value
                    Get-Page
                    $menuNested.RemoveAt($menuNested.Count - 1) | Out-Null
                } else {
                    $menuLoop = $false; return $false
                }; break
            }
            # Next + previous entry
            'DownArrow' { if ($lineSelected -lt ($pageEntryTotal - 1)) { $lineSelected++ }; break }
            'UpArrow' { if ($lineSelected -gt 0) { $lineSelected-- }; break }

            # Jump to top + bottom
            'Home' { $lineSelected = 0; break }
            'End' { $lineSelected = ($pageEntryTotal - 1); break }

            # Next + previous page
            {$_ -in 'RightArrow','PageDown'} {
                if ($pageCurrent -ne $pageTotal) {
                    $pageCurrent++; $lineSelected = 0; Clear-Host; Get-Page
                }; break
            }
            {$_ -in 'LeftArrow','PageUp'} {
                if ($pageCurrent -ne 0) {
                    $pageCurrent--; $lineSelected = 0; Clear-Host; Get-Page
                }; break
            }

            # MultiSelect - Check selection
            'Spacebar' {
                switch ($entrySelected.Selected) {
                    $true { $entrySelected.Selected = $false }
                	$false { $entrySelected.Selected = $true }
                }; break
            }

            # Confirm selection
            'Enter' {
                Clear-Host
                # Check if -MultiSelect has been defined
                if ($MultiSelect) {
                    $menuLoop = $false # Exit menu
                    $menuEntries | ForEach-Object {
                        # Entry contains command, invoke it
                        if (($_.Selected) -and ($_.Command -notlike $null)) {
                            Invoke-Expression -Command $_.Command
                        # Return name, entry does not contain command
                        } elseif ($_.Selected) {
                            return $_.Name
                        }
                    }
                } else {
                    # Entry contains a command
                    if ($entrySelected.Command -notlike $null) {
                        # Hashtable
                        if ((($entrySelected.Command).GetType()) -like 'Hashtable') {
                            $menuNested.$Title = $inputEntries; $Title = $entrySelected.Name; $lineSelected = 0
                            Get-Menu $($entrySelected.Command); Get-Page
                        # Invoke, see if type is array
                        } elseif ((($entryInvoke = Invoke-Expression -Command $entrySelected.Command).GetType().BaseType) -like 'Array') {
                            $menuNested.$Title = $inputEntries; $Title = $entrySelected.Name; $lineSelected = 0
                            Get-Menu $entryInvoke; Get-Page
                        } else { # Not a submenu, invoke and exit instead
                            $menuLoop = $false
                            Invoke-Expression -Command $entrySelected.Command
                        }
                    } else { # Return name and exit
                        $menuLoop = $false
                        return $entrySelected.Name
                    }
                }; break
            }
        }
    } while ($menuLoop)
}
