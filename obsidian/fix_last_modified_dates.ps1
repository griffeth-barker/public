<#
.SYNOPSIS
  This script sets the Last Modified datetime of notes in your Obsidian Vault.
.DESCRIPTION
  This script will get a list of all the notes in your Obsidian Vault and iterate through
  that list, getting the "Last Updated" property from the YAML frontmatter of the note, and
  setting it as the LastWriteTime property of the note's file in your Vault folder. 
  
  This script can be helpful for fixing a common issue when migrating to Obsidian where the
  "Last Modified" date in File Explorer is the date that you exported your notes from your
  last platform. This script will restore the appropriate "Last Modified" date, if available,
  from your notes' frontmatter properties.
.PARAMETER <Parameter_Name>
  None
.INPUTS
  None
.OUTPUTS
  None
.NOTES
  Author:         Barker, Griffeth (barkergriffeth@gmail.com)
  Creation Date:  2023-10-28
  Purpose/Change: Initial script development

  Change the $vault variable to reflect the path to the root folder of your Obsidian Vault
  and you should be good to go.

  This script does assume you do actually have Last Update and Creation Date properties in the
  frontmatter of all your notes in your vault.

  As always, this script is provided with no guarantee nor warranty. You should always fully
  understand what a command or script does before running it on any computer.
.EXAMPLE
  .\fix_exported_notes_lastwritetime.ps1
#>

# CHANGE THIS: Path to your vault's root folder
$vault = ""

# Get list of notes in vault
$notes = @(Get-ChildItem -Path "$vault\*.md" -Recurse | Select-Object -ExpandProperty FullName)

# Interate through the notes in your vault
foreach ($note in $notes) {

    # Get LastWriteTime of the note from the YAML properties in the frontmatter of the note
    $last_write_time = (Get-Content -path "$note" | Select-String "Last Update" -SimpleMatch | Out-String).split(" ")[2]

    # Set the LastWriteTime of the note to the value we got from the properties inside the note
    (Get-Item -Path "$note").LastWriteTime = $last_write_time
    
}
