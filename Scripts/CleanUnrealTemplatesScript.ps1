<#
.SYNOPSIS
    Replaces all .template files in the selected Unreal Engine Templates
    directory with the corresponding files from ../CleanTemplates.

.DESCRIPTION
    Opens a Windows folder picker. After selecting the Unreal Engine
    Templates directory, the script looks for a "CleanTemplates" folder
    one level above the selected directory.

    If the selected folder has no .template files in it, a warning is
    shown and the folder picker reopens, remembering the last selected
    path. Otherwise, the user is asked whether to back up the selected
    folder's existing .template files into a sibling "BackupTemplates"
    folder before they get overwritten - unless BackupTemplates already
    exists, in which case this prompt is skipped entirely.

    Every .template file found directly in CleanTemplates is then copied
    to the selected directory, replacing the existing file with the same
    name.
#>

try {
    Add-Type -AssemblyName System.Windows.Forms

    # An invisible, always-on-top window used only as the "owner" of the
    # dialogs below. Without an owner, a dialog launched from a console
    # process can open behind other windows instead of coming to the
    # front. This form is never shown to the user.
    $ownerForm = New-Object System.Windows.Forms.Form
    $ownerForm.TopMost = $true
    $ownerForm.StartPosition = "Manual"
    $ownerForm.Location = New-Object System.Drawing.Point(-2000, -2000)
    $ownerForm.Size = New-Object System.Drawing.Size(0, 0)
    $ownerForm.ShowInTaskbar = $false
    $ownerForm.Show()
    $ownerForm.Hide()

    # Default starting location the very first time the dialog opens.
    # Once a folder has been picked, $lastSelectedPath takes over so the
    # dialog reopens wherever the user last was, instead of resetting.
    $epicGamesPath = "C:\Program Files\Epic Games"
    if (Test-Path -Path $epicGamesPath -PathType Container) {
        $lastSelectedPath = $epicGamesPath
    }
    else {
        $lastSelectedPath = [System.IO.Path]::GetPathRoot((Get-Location).Path)
    }

    $selectedPath = $null
    $readyToProceed = $false

    while (-not $readyToProceed) {

        $folderBrowser = New-Object System.Windows.Forms.FolderBrowserDialog
        $folderBrowser.Description = "Select the Unreal Engine Templates folder`nBy default on `"C:\Program Files\Epic Games\UE_[Version]\Engine\Content\Editor\Templates`"`n"
        $folderBrowser.ShowNewFolderButton = $false
        $folderBrowser.SelectedPath = $lastSelectedPath

        $result = $folderBrowser.ShowDialog($ownerForm)

        if ($result -ne [System.Windows.Forms.DialogResult]::OK) {
            Write-Host "No folder was selected."
            break
        }

        $selectedPath = $folderBrowser.SelectedPath
        $lastSelectedPath = $selectedPath

        Write-Host ""
        Write-Host "Selected folder:"
        Write-Host "  $selectedPath"

        # Files currently in the selected folder - these are the ones
        # that would be overwritten, and what gets backed up if the
        # user chooses to.
        $existingTemplateFiles = @(Get-ChildItem -Path $selectedPath -Filter "*.template" -File)

        if ($existingTemplateFiles.Count -eq 0) {
            [System.Windows.Forms.MessageBox]::Show(
                $ownerForm,
                "No .template files were found in the selected folder.`n`nPlease choose a different folder.",
                "No template files found",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Warning
            ) | Out-Null
            continue
        }

        # Backup folder sits next to the selected Templates folder, not
        # inside it - e.g. ...\Editor\Templates -> ...\Editor\BackupTemplates
        $parentDir = Split-Path -Parent $selectedPath
        $backupFolder = Join-Path $parentDir "BackupTemplates"

        if (Test-Path -LiteralPath $backupFolder -PathType Container) {
            # A backup already exists from a previous run - skip the
            # prompt entirely and just proceed, same as choosing "No".
            Write-Host "BackupTemplates already exists, skipping option to backup."
            $readyToProceed = $true
            continue
        }

        $message = "$($existingTemplateFiles.Count) .template file(s) in this folder are about to be overwritten.`n`nCreate a copy in a Backup folder first?"
        $choice = [System.Windows.Forms.MessageBox]::Show(
            $ownerForm,
            $message,
            "Backup before continuing?",
            [System.Windows.Forms.MessageBoxButtons]::YesNoCancel,
            [System.Windows.Forms.MessageBoxIcon]::Question
        )

        switch ($choice) {
            ([System.Windows.Forms.DialogResult]::Cancel) {
                # Go back to the folder selection dialog.
                continue
            }
            ([System.Windows.Forms.DialogResult]::No) {
                $readyToProceed = $true
            }
            ([System.Windows.Forms.DialogResult]::Yes) {
                New-Item -ItemType Directory -Path $backupFolder -Force | Out-Null

                foreach ($file in $existingTemplateFiles) {
                    $destinationPath = Join-Path $backupFolder $file.Name
                    Copy-Item -LiteralPath $file.FullName -Destination $destinationPath -Force
                }

                Write-Host "Backup created at: $backupFolder"
                $readyToProceed = $true
            }
        }
    }

    if ($readyToProceed -and $selectedPath) {

        # CleanTemplates is relative to the script location.
        $cleanTemplatesPath = [System.IO.Path]::GetFullPath(
            (Join-Path -Path $PSScriptRoot -ChildPath "..\CleanTemplates")
        )

        if (-not (Test-Path -Path $cleanTemplatesPath -PathType Container)) {
            throw "CleanTemplates folder was not found: $cleanTemplatesPath"
        }

        Write-Host ""
        Write-Host "Source folder:"
        Write-Host "  $cleanTemplatesPath"

        # Find every .template file directly in CleanTemplates.
        $templateFiles = @(Get-ChildItem -Path $cleanTemplatesPath -Filter "*.template" -File)

        if ($templateFiles.Count -eq 0) {
            Write-Host ""
            Write-Host "No .template files were found in CleanTemplates."
        }
        else {
            Write-Host ""
            Write-Host "Replacing $($templateFiles.Count) .template file(s)..."

            foreach ($sourceFile in $templateFiles) {
                $destinationFile = Join-Path -Path $selectedPath -ChildPath $sourceFile.Name

                # Replace the destination file.
                Copy-Item -Path $sourceFile.FullName -Destination $destinationFile -Force

                Write-Host "  Replaced: $($sourceFile.Name)"
            }

            Write-Host ""
            Write-Host "All .template files have been replaced successfully."
        }
    }

    $ownerForm.Dispose()
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
