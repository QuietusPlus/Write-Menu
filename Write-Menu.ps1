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

        .PARAMETER Page
            Page to display.

        .PARAMETER Sort
            Sort entries before they are added to the menu.

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

        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [System.Int16]$Page,

        [Parameter()]
        [switch]$Sort
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
        [System.Console]::WriteLine("`n " + $Title + "`n") # Display title
        $pageListSize = ($host.UI.RawUI.WindowSize.Height - 7) # Set menu height
    } else {
        [System.Console]::WriteLine('')  # Skip title display
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
                }; $i++
            }
        }
        System.Collections.Hashtable {
            $entriesTotal = $Entries.Count
            foreach ($i in 0..$($entriesTotal - 1)) {
                $entriesToPage += New-Object PSObject -Property @{
                    Command = $($Entries.Values)[$i]
                    Name = $($Entries.Keys)[$i]
                }; $i++
            }
        }
    }

    # -Sort entries
    if ($Sort -eq $true) { $entriesToPage = $entriesToPage | Sort-Object -Property Name}

    # First entry of page (location within entire array)
    $pageFirstEntry = ($pageListSize * $Page)

    # Total pages
    $pageTotal = [math]::Ceiling((($entriesTotal - $pageListSize) / $pageListSize))

    # Amount of page entries
    if ($Page -eq $pageTotal) { # Last page
        $pageEntriesCount = ($entriesTotal - ($pageListSize * $pageTotal))
    } else { # Fully populated page
        $pageEntriesCount = $pageListSize
    }

    # Position within console
    $positionCurrent = 0
    $positionSelected = 0
    $positionTotal = 0
    $positionTop = [System.Console]::CursorTop

    # Get entries for current page
    $pageEntries = @()
    foreach ($i in 0..$pageListSize) {
        $pageEntries += New-Object PSObject -Property @{
            Command = $entriesToPage[($pageFirstEntry + $i)].Command
            Name = $entriesToPage[($pageFirstEntry + $i)].Name
        }
    }

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

            # Write entry
            [System.Console]::Write('  ' + $pageEntries[$positionCurrent].Name + '  ')

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

        switch ($menuInput.Key) {
            # Next entry
            'DownArrow' {
                if ($positionSelected -lt ($pageEntriesCount - 1)) { # Check if bottom of list
                    $positionSelected++
                }
            }

            # Previous entry
            'UpArrow' {
                if ($positionSelected -gt 0) { # Check if top of list
                    $positionSelected--
                }
            }

            # Move to top entry
            'Home' {
                $positionSelected = 0
            }

            # Move to bottom entry
            'End' {
                $positionSelected = ($pageEntriesCount - 1)
            }

            # Previous page
            {$_ -in 'LeftArrow','PageUp'} {
                if ($Page -ne 0) { # Check if on first page
                    $menuLoop = $false
                    $Page--
                    Write-Menu -Entries $Entries -Page $Page -Title $Title
                }
            }

            # Next page
            {$_ -in 'RightArrow','PageDown'} { # Check if on last page
                if ($Page -ne $pageTotal) {
                    $menuLoop = $false
                    $Page++
                    Write-Menu -Entries $Entries -Page $Page -Title $Title
                }
            }

            # Exit menu
            {$_ -in 'Escape','Backspace'} {
                $menuLoop = $false
                Clear-Host
                return $false
            }

            # Confirm selection
            'Enter' {
                $menuLoop = $false
                Clear-Host
                if ($pageEntries[$positionSelected].Command -notlike $null) { # Selected entry: Invoke command
                    Invoke-Expression -Command $pageEntries[$positionSelected].Command
                } else { # Selected entry: Return entry name
                    return $pageEntries[$positionSelected].Name
                }
            }
        }
    } while ($menuLoop)
}
