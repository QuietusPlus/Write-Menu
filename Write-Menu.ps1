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

        .PARAMETER Items
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

    # Clear screen
    Clear-Host

    <#
        Checks
    #>

    # Parameter: Entries
    if ($Entries -like $null) {
        Write-Error "Missing -Entries parameter!"
        return
    }

    # Parameter: Page
    if ($Page -like $null) {
        $Page = 0
    }

    # Parameter: Title
    if ($Title -notlike $null) {
        $menuTitle = "`n $Title`n" # Display title
        $pageListSize = ($host.UI.RawUI.WindowSize.Height - 7) # Set menu height
    } else {
        $menuTitle = ''  # Skip title display
        $pageListSize = ($host.UI.RawUI.WindowSize.Height - 5) # Set menu height
    }

    # Make sure host is console window
    if ($host.Name -ne 'ConsoleHost') {
        Write-Error "[$($host.Name)] Cannot run inside host, please use a console window instead!"
        return
    }

    <#
        Colours
    #>

    # Set colours, modify this to change colours
    $colorForeground = [System.Console]::ForegroundColor
    $colorBackground = [System.Console]::BackgroundColor

    # Set inverted colours
    $colorForegroundSelected = $colorBackground
    $colorBackgroundSelected = $colorForeground

    <#
        Initialisation
    #>

    # Get entries type
    $entriesType = ($Entries | ForEach-Object { $_.PSObject.TypeNames[0] } | Select-Object -First 1)

    # Amount of entries in total + Preparation for page conversion
    $entriesToPage = @()
    switch ($entriesType) {
        System.String {
            $entriesTotal = $Entries.Length
            foreach ($i in 0..$($entriesTotal - 1)) {
                $entriesToPage += New-Object PSObject -Property @{
                    Command = $null
                    Name = $($Entries)[$i]
                    Selected = $false
                }; $i++
            }
        }
        System.Collections.Hashtable {
            $entriesTotal = $Entries.Count
            foreach ($i in 0..$($entriesTotal - 1)) {
                $entriesToPage += New-Object PSObject -Property @{
                    Command = $($Entries.Values)[$i]
                    Name = $($Entries.Keys)[$i]
                    Selected = $false
                }; $i++
            }
        }
    }

    # -Sort entries
    if ($Sort -eq $true) { $entriesToPage = $entriesToPage | Sort-Object -Property Name}

    # Total pages
    $pageTotal = [math]::Ceiling((($entriesTotal - $pageListSize) / $pageListSize))

    # Get entries for current page
    function Get-PageEntries {
        # Write title
        [System.Console]::WriteLine($menuTitle)

        # First entry of page (location within entire array)
        $script:pageFirstEntry = ($pageListSize * $Page)

        # Amount of page entries
        if ($Page -eq $pageTotal) { # Last page
            $script:pageEntriesCount = ($entriesTotal - ($pageListSize * $pageTotal))
        } else { # Fully populated page
            $script:pageEntriesCount = $pageListSize
        }

        # Position within console
        $script:positionCurrent = 0
        $script:positionSelected = 0
        $script:positionTotal = 0
        $script:positionTop = [System.Console]::CursorTop
    }
    Get-PageEntries

    <#
        Write Page
    #>

    do {
        $menuLoop = $true
        [System.Console]::CursorTop = ($positionTop - $positionTotal)

        # Write entries
        for ($positionCurrent = 0; $positionCurrent -le ($pageEntriesCount - 1); $positionCurrent++) {
            # Move to beginning of line
            [System.Console]::Write("`r")

            # If selected, invert colours
            if ($positionCurrent -eq $positionSelected) {
                [System.Console]::BackgroundColor = $colorBackgroundSelected
                [System.Console]::ForegroundColor = $colorForegroundSelected
            }

            # Define checkbox
            if ($MultiSelect) {
                switch ($entriesToPage[($pageFirstEntry + $positionCurrent)].Selected) {
                    $true {
                        $pageEntrySelected = '[X] '
                    }
                	Default {
                        $pageEntrySelected = '[ ] '
                    }
                }
            }

            # Write entry
            [System.Console]::Write('  ' + $pageEntrySelected + $entriesToPage[($pageFirstEntry + $positionCurrent)].Name + '  ')

            # Reset colours
            [System.Console]::ForegroundColor = $colorForeground
            [System.Console]::BackgroundColor = $colorBackground

            # Empty line
            [System.Console]::WriteLine('')
        }

        # Write page indicator
        [System.Console]::WriteLine("`n Page $($Page + 1) / $($pageTotal + 1)`n")

        <#
            User Input
        #>

        # Read key input
        $menuInput = [System.Console]::ReadKey($true)

        # Selected entry
        $entrySelected = $entriesToPage[($pageFirstEntry + $positionSelected)]

        # Key actions
        switch ($menuInput.Key) {
            'DownArrow' { # Next entry
                if ($positionSelected -lt ($pageEntriesCount - 1)) { # Check if bottom of list
                    $positionSelected++
                }
            }
            'UpArrow' { # Previous entry
                if ($positionSelected -gt 0) { # Check if top of list
                    $positionSelected--
                }
            }
            'Home' { # Move to top entry
                $positionSelected = 0
            }
            'End' { # Move to bottom entry
                $positionSelected = ($pageEntriesCount - 1)
            }
            {$_ -in 'LeftArrow','PageUp'} { # Previous page
                if ($Page -ne 0) { # Check if on first page
                    $Page--
                    $positionSelected = 0
                    Clear-Host
                    Get-PageEntries
                }
            }
            {$_ -in 'RightArrow','PageDown'} { # Next page
                if ($Page -ne $pageTotal) { # Check if on last page
                    $Page++
                    $positionSelected = 0
                    Clear-Host
                    Get-PageEntries
                }
            }
            {$_ -in 'Escape','Backspace'} { # Exit menu
                $menuLoop = $false
                Clear-Host
                return $false
            }
            'Spacebar' { # Check selection
                switch ($entrySelected.Selected) {
                    $true { $entrySelected.Selected = $false }
                	$false { $entrySelected.Selected = $true }
                }
            }
            'Enter' { # Confirm selection
                $menuLoop = $false
                Clear-Host
                switch ($MultiSelect) {
                    $true {
                        $entriesToPage | ForEach-Object {
                            if ($_.Selected) {
                                if ($_.Command -notlike $null) {
                                    Invoke-Expression -Command $_.Command
                                } else {
                                    return $_.Name
                                }
                            }
                        }
                    }
                    $false {
                        if ($entrySelected.Command -notlike $null) {
                            Invoke-Expression -Command $entrySelected.Command
                        } else {
                            return $entrySelected.Name
                        }
                    }
                }
            }
        }
    } while ($menuLoop)
}
