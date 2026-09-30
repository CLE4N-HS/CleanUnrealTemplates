<#
.SYNOPSIS
    Applies configurable cleanup rules to all .template files in a working
    folder, before they get copied over the real Unreal Engine templates.

.DESCRIPTION
    Reads every *.template file under ..\CleanTemplates\ (relative to this
    script's own location) and applies the rules defined in the $Rules
    array below, in order. Add, remove, or edit entries in $Rules to change
    what gets cleaned - nothing below that list should need to change for
    a new rule.

.NOTES
    This script overwrites files in place. It is meant to run on your own
    working copies under CleanTemplates, not directly on the engine's
    Templates folder - a separate script handles copying the final result
    over the real Unreal Templates path.
#>

try {

    # -----------------------------------------------------------------
    # RULES
    # Each rule is a script block that receives the file's lines (an
    # array of strings) and must return the modified array of lines.
    # Rules run in the order listed below, each one working on the
    # previous rule's output.
    # -----------------------------------------------------------------

    $Rules = @(

        # Rule: remove the %COPYRIGHT_LINE% token if it is the first
        # line, then remove every blank line that follows it, up to
        # the next non-empty line.
        {
            param([string[]]$Lines)

            if ($Lines.Count -eq 0) {
                return $Lines
            }

            if ($Lines[0].Trim() -ne "%COPYRIGHT_LINE%") {
                return $Lines
            }

            $result = New-Object System.Collections.Generic.List[string]
            $i = 1  # skip the copyright line itself

            while ($i -lt $Lines.Count -and $Lines[$i].Trim() -eq "") {
                $i++
            }

            while ($i -lt $Lines.Count) {
                $result.Add($Lines[$i])
                $i++
            }

            return $result.ToArray()
        }

        # Add more rules here as separate script blocks in this array.

    )

    # -----------------------------------------------------------------
    # ENGINE - should not need editing just to add or remove a rule
    # -----------------------------------------------------------------

    $ScriptDir = $PSScriptRoot
    $TargetDir = Join-Path $ScriptDir "..\CleanTemplates"

    if (-not (Test-Path -LiteralPath $TargetDir -PathType Container)) {
        Write-Host "Error: folder not found: $TargetDir"
        exit 1
    }

    $files = Get-ChildItem -LiteralPath $TargetDir -Filter "*.template" -File -Recurse

    if ($files.Count -eq 0) {
        Write-Host "No .template files found under: $TargetDir"
        exit 0
    }

    foreach ($file in $files | Sort-Object FullName) {
        $originalText = Get-Content -LiteralPath $file.FullName -Raw -Encoding UTF8
        $lines = $originalText -split "`r?`n"

        foreach ($rule in $Rules) {
            $lines = & $rule $lines
        }

        $newText = ($lines -join "`r`n")
        if (-not $newText.EndsWith("`r`n")) {
            $newText += "`r`n"
        }

        if ($newText -eq $originalText) {
            Write-Host "[unchanged] $($file.FullName)"
        }
        else {
            Set-Content -LiteralPath $file.FullName -Value $newText -NoNewline -Encoding UTF8
            Write-Host "[updated]   $($file.FullName)"
        }
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
