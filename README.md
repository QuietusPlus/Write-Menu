#Write-Menu

![AppxPackages](Examples/AppxPackages.gif)

##Description

Outputs a command-line menu which can be navigated using the keyboard. Automatically creates multiple pages if the entries cannot fit on screen.

## Parameters

 | Parameter | Example
:-- | :-- | :--
Required | -Entries (-Items) | -Entries @('Entry 1', 'Entry 2', 'Entry 3')
Optional | -Title (-Name) | -Title 'Example Title'
Optional | -Page | -Page 1
Optional | -Sort | -Sort

## Controls

Key | Description
:-- | :--
Arrow Down | Select next
Arrow Up | Select previous
Arrow Right | Next page
Arrow Left | Previous page
Enter | Confirm selection
Escape | Exit menu

## Examples

Example | Description
:-- | :--
[AppxPackages](Examples/AppxPackages.md) | Uses Write-Menu to list app packages (Windows Store/Modern Apps)
[CustomMenu](Examples/CustomMenu.md) | Generates a custom menu by manually specifying each entry
