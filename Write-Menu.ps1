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
			Prefix		    = ' '
			Padding		    = 2
			Suffix		    = ' '
			Nested		    = ' >'
			
			# Minimum page width
			Width		    = 30
			entryWidth	    = $null
			pageWidth	    = $null
			
			# Save initial colours
			ForegroundColor = [System.Console]::ForegroundColor
			BackgroundColor = [System.Console]::BackgroundColor
			
			# Save initial window title
			InitialWindowTitle = $host.UI.RawUI.WindowTitle
			WindowTitle	    = $Title
			# Set menu height
			pageSize	    = ($host.UI.RawUI.WindowSize.Height - 5)
			pageTotal	    = $null
			
			pageCurrent	    = 0
			menuEntries	    = $null
			menuEntryTotal  = $null
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
						Name	  = $inputEntries
						Value	  = $inputEntries
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
							Name	  = $tempName
							Value	  = $tempName
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