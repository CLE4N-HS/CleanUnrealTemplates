<#
.SYNOPSIS
    Minimal example: opens a native Explorer folder picker and prints the
    chosen path.

.DESCRIPTION
    Double-click this file (or right-click > Run with PowerShell) to open
    a standard Windows "Browse For Folder" dialog. Whatever folder you pick
    gets printed to the console window. This is a starting point to build
    the template-cleaning tool on top of later.
#>

try {
    Add-Type -AssemblyName System.Windows.Forms

    $folderBrowser = New-Object System.Windows.Forms.FolderBrowserDialog
    $folderBrowser.Description = "Select the Unreal Engine Templates folder`nBy default on `"C:\Program Files\Epic Games\UE_[Version]\Engine\Content\Editor\Templates`"`n"
    $folderBrowser.ShowNewFolderButton = $false

    $result = $folderBrowser.ShowDialog()

    if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
        $selectedPath = $folderBrowser.SelectedPath
        Write-Host "You chose: $selectedPath"
    }
    else {
        Write-Host "No folder was selected."
    }
}
catch {
    Write-Host ""
    Write-Host "An error occurred:"
    Write-Host $_.Exception.Message
}
finally {
    Write-Host ""
    Write-Host "Press Enter to close..."
    Read-Host | Out-Null
}
