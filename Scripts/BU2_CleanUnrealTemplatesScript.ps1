<#
.SYNOPSIS
    Replaces all .template files in the selected Unreal Engine Templates
    directory with the corresponding files from ../CleanTemplates.

.DESCRIPTION
    Opens a Windows folder picker. After selecting the Unreal Engine
    Templates directory, the script looks for a "CleanTemplates" folder
    one level above the selected directory.

    Every .template file found in CleanTemplates (including subdirectories)
    is copied to the selected directory, replacing the existing file with
    the same relative path.
#>

try {
    Add-Type -AssemblyName System.Windows.Forms

    $folderBrowser = New-Object System.Windows.Forms.FolderBrowserDialog
    $folderBrowser.Description = "Select the Unreal Engine Templates folder`nBy default on `"C:\Program Files\Epic Games\UE_[Version]\Engine\Content\Editor\Templates`"`n"
    $folderBrowser.ShowNewFolderButton = $false

    # Start the folder picker in the Epic Games directory if it exists.
    # Otherwise, start at the root of the current drive.
    $epicGamesPath = "C:\Program Files\Epic Games"

    if (Test-Path -Path $epicGamesPath -PathType Container) {
        $folderBrowser.SelectedPath = $epicGamesPath
    }
    else {
        $folderBrowser.SelectedPath = [System.IO.Path]::GetPathRoot((Get-Location).Path)
    }

    $result = $folderBrowser.ShowDialog()

    if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
        $selectedPath = $folderBrowser.SelectedPath

        Write-Host ""
        Write-Host "Selected folder:"
        Write-Host "  $selectedPath"

        # ../CleanTemplates relative to the selected directory
        $parentPath = Split-Path -Path $selectedPath -Parent
        $cleanTemplatesPath = Join-Path -Path $parentPath -ChildPath "CleanTemplates"

        if (-not (Test-Path -Path $cleanTemplatesPath -PathType Container)) {
            throw "CleanTemplates folder was not found: $cleanTemplatesPath"
        }

        Write-Host ""
        Write-Host "Source folder:"
        Write-Host "  $cleanTemplatesPath"

        # Find every .template file recursively in CleanTemplates.
        $templateFiles = @(Get-ChildItem -Path $cleanTemplatesPath -Filter "*.template" -File -Recurse)

        if ($templateFiles.Count -eq 0) {
            Write-Host ""
            Write-Host "No .template files were found in CleanTemplates."
        }
        else {
            Write-Host ""
            Write-Host "Replacing $($templateFiles.Count) .template file(s)..."

            foreach ($sourceFile in $templateFiles) {
                # Preserve the directory structure relative to CleanTemplates.
                $relativePath = $sourceFile.FullName.Substring(
                    $cleanTemplatesPath.Length
                ).TrimStart('\', '/')

                $destinationFile = Join-Path -Path $selectedPath -ChildPath $relativePath
                $destinationDirectory = Split-Path -Path $destinationFile -Parent

                # Create the destination subdirectory if necessary.
                if (-not (Test-Path -Path $destinationDirectory -PathType Container)) {
                    New-Item -ItemType Directory -Path $destinationDirectory -Force | Out-Null
                }

                # Replace the destination file.
                Copy-Item -Path $sourceFile.FullName -Destination $destinationFile -Force

                Write-Host "  Replaced: $relativePath"
            }

            Write-Host ""
            Write-Host "Done. All .template files have been replaced."
        }
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
