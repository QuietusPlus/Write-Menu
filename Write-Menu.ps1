function Write-Menu {
    <#
        .NOTES
            Write-Menu (v1.0)
            by QuietusPlus

            Based (but heavily modified) on "Simple Textbased Powershell Menu" by Michael Albert [info@michlstechblog.info]

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

        .EXAMPLE
            PS > $choice = Write-Menu -Title 'Test Menu' -Entries @('Test Object 1', 'Test Object 2', 'Test Object 3', 'Test Object 4')

             Menu Title

              Menu Option 1
              Menu Option 2
              Menu Option 3
              Menu Option 4

             Page 1 / 1

        .LINK
            https://gist.github.com/QuietusPlus/59d8612ec13ea929704542eb0bd8d52c
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
        [System.Int16]$Page
    )

    # Clear screen
    Clear-Host

    # Check if parameters have been passed
    if ($Entries -like $null) { return }
    if ($Page -like $null) { $Page = 0 }
    if ($Title -notlike $null) {
        [System.Console]::WriteLine("`n " + $Title + "`n") # Display title
        $pageListSize = ($host.UI.RawUI.WindowSize.Height - 7) # Set menu height
    } else {
        [System.Console]::WriteLine('') # Skip title display
        $pageListSize = ($host.UI.RawUI.WindowSize.Height - 5) # Set menu height
    }

    <#
        Colours
    #>

    $colorForegroundSaved = [System.Console]::ForegroundColor; $colorBackgroundSaved = [System.Console]::BackgroundColor # Save original colours
    $colorForeground = $colorForegroundSaved; $colorBackground = $colorBackgroundSaved # Set colours, modify this to change colours
    $colorForegroundSelected = $colorBackground; $colorBackgroundSelected = $colorForeground # Set inverted colours

    <#
        Initialisation
    #>

    # Amount of entries in total
    $entriesTotal = $Entries.Length
    # First entry of page (location within entire array)
    $pageFirstEntry = ($pageListSize * $Page)
    # Total pages
    $pageTotal = [math]::Ceiling((($entriesTotal - $pageListSize) / $pageListSize))
    # Amount of entries on last page
    if ($Page -eq $pageTotal) { $pageEntriesCount = ($entriesTotal - ($pageListSize * $pageTotal))
    # Amount of entries on fully populated page
    } else { $pageEntriesCount = $pageListSize }

    # Position within console
    $positionCurrent = 0
    $positionSelected = 0
    $positionTotal = 0
    $positionTop = [System.Console]::CursorTop

    # Get entries for current page
    $pageEntries = @()
    foreach ($i in 0..$pageListSize) {
        $pageEntries += $Entries[($pageFirstEntry + $i)]
    }

    <#
        Write Page
    #>

    do {
        $menuLoop = $true
        [System.Console]::CursorTop = ($positionTop - $positionTotal)
        for ($positionCurrent = 0; $positionCurrent -le ($pageEntriesCount - 1); $positionCurrent++) {
            # Replace previous line
            [System.Console]::Write("`r")
            # If selected, invert colours
            if ($positionCurrent -eq $positionSelected) { [System.Console]::BackgroundColor = $colorBackgroundSelected; [System.Console]::ForegroundColor = $colorForegroundSelected }
            # Write entry
            [System.Console]::Write(' ' + $pageEntries[$positionCurrent] + ' ')
            # Reset colours
            [System.Console]::BackgroundColor = $colorBackground; [System.Console]::ForegroundColor = $colorForeground
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

        # Arrow down
        if (($menuInput.Key -eq 'DownArrow') -and ($positionSelected -lt ($pageEntriesCount - 1))) { $positionSelected++
        # Arrow up
        } elseif (($menuInput.Key -eq 'UpArrow') -and ($positionSelected -gt 0)) { $positionSelected--
        # Enter
        } elseif ($menuInput.Key -eq 'Enter') { $menuLoop = $false
        # Escape
        } elseif ($menuInput.Key -eq 'Escape') { $menuLoop = $false
        # Arrow left
        } elseif ($menuInput.Key -eq 'LeftArrow') { if ($Page -ne 0) { $Page--; $menuLoop = $false }
        # Arrow right
        } elseif ($menuInput.Key -eq 'RightArrow') { if ($Page -ne $pageTotal) { $Page++; $menuLoop = $false } }

    } while ($menuLoop)

    # Finish operations for pressed key
    if ($menuInput.Key -eq 'Escape') {
        Clear-Host; return
    } elseif ($menuInput.Key -eq 'Enter') {
        Clear-Host; return ($pageEntries[$positionSelected])
    } elseif (($menuInput.Key -eq 'LeftArrow') -or ($menuInput.Key -eq 'RightArrow')) {
        Clear-Host
        if ($Title -notlike $null) { # Check if title has previously been passed
            Write-Menu -Entries $Entries -Page $Page -Title $Title
        } else { # If not, skip title
            Write-Menu -Entries $Entries -Page $Page
        }
    }
}
