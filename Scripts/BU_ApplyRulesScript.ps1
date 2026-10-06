<#
.SYNOPSIS
    Applies configurable cleanup rules to all .template files in a working
    folder, before they get copied over the real Unreal Engine templates.

.DESCRIPTION
    Reads every *.template file under ..\CleanTemplates\ (relative to this
    script's own location) whose base name is in $AllowedBaseNames, and
    applies the rules defined below, in order.

    Each rule is its own clearly labeled function. To disable a rule,
    comment out its call inside the "RULE PIPELINE" section near the
    bottom of this file. To add a new rule, write a new function following
    the same pattern (take $Lines in, return modified $Lines out) and add
    a call to it in the pipeline.

.NOTES
    This script overwrites files in place. It is meant to run on your own
    working copies under CleanTemplates, not directly on the engine's
    Templates folder - a separate script handles copying the final result
    over the real Unreal Templates path.
#>

try {

    # -----------------------------------------------------------------
    # FILE FILTER
    # Only files whose base name (without ".h"/".cpp"/".template") is in
    # this list get processed. Everything else in the folder is left
    # untouched. Add or remove names here to change which files are
    # affected.
    # -----------------------------------------------------------------

    $AllowedBaseNames = @(
        "ActorClass"
        "ActorComponentClass"
        "CharacterClass"
        "EmptyClass"
        "InterfaceClass"
        "PawnClass"
    )

    # -----------------------------------------------------------------
    # RULE: remove %COPYRIGHT_LINE% and the blank lines that follow it
    # Only triggers if %COPYRIGHT_LINE% is the very first line of the
    # file. Removes it, then keeps skipping forward past any empty
    # lines right after it, stopping at the first real content.
    # -----------------------------------------------------------------
    function Remove-CopyrightLine {
        param([string[]]$Lines)

        if ($Lines.Count -eq 0 -or $Lines[0].Trim() -ne "%COPYRIGHT_LINE%") {
            return $Lines
        }

        $result = New-Object System.Collections.Generic.List[string]
        $i = 1

        while ($i -lt $Lines.Count -and $Lines[$i].Length -eq 0) {
            $i++
        }

        while ($i -lt $Lines.Count) {
            $result.Add($Lines[$i])
            $i++
        }

        return $result.ToArray()
    }

    # -----------------------------------------------------------------
    # RULE: remove the %PCH_INCLUDE_DIRECTIVE% line
    # Only relevant to .cpp templates, but harmless to run on every
    # file - it simply does nothing if the line is not present.
    # -----------------------------------------------------------------
    function Remove-PchIncludeDirective {
        param([string[]]$Lines)

        return $Lines | Where-Object { $_.Trim() -ne "%PCH_INCLUDE_DIRECTIVE%" }
    }

    # -----------------------------------------------------------------
    # Comment lines that must survive Remove-Comments below, because
    # they carry useful information rather than boilerplate. Add more
    # exact lines here (matched after trimming) to protect them too.
    # -----------------------------------------------------------------
    $PreservedCommentLines = @(
        "// This class does not need to be modified."
        "// Add default functionality here for any I%UNPREFIXED_CLASS_NAME% functions that are not pure virtual."
    )

    # -----------------------------------------------------------------
    # RULE: remove comments
    # Removes full-line "//" comments, and multi-line "/* ... */" style
    # block comments (including the common "/**" doxygen-style form
    # some templates use), except for the lines listed in
    # $PreservedCommentLines above, which are kept as-is. Does not
    # touch code that merely contains // or /* inside a string - these
    # template files never do that, so a simple line-based check is
    # safe here.
    # -----------------------------------------------------------------
    function Remove-Comments {
        param([string[]]$Lines)

        $result = New-Object System.Collections.Generic.List[string]
        $insideBlockComment = $false

        foreach ($line in $Lines) {
            $trimmed = $line.Trim()

            if ($insideBlockComment) {
                if ($trimmed -match "\*/\s*$") {
                    $insideBlockComment = $false
                }
                continue
            }

            if ($PreservedCommentLines -contains $trimmed) {
                $result.Add($line)
                continue
            }

            if ($trimmed -match "^//") {
                continue
            }

            if ($trimmed -match "^/\*") {
                if ($trimmed -match "\*/\s*$") {
                    # single-line block comment, e.g. "/** comment */"
                    continue
                }
                $insideBlockComment = $true
                continue
            }

            $result.Add($line)
        }

        return $result.ToArray()
    }

    # -----------------------------------------------------------------
    # RULE: remove the %CURSORFOCUSLOCATION% placeholder line
    # Removes the line entirely when it is the only thing on that line.
    # -----------------------------------------------------------------
    function Remove-CursorFocusLocationLine {
        param([string[]]$Lines)

        return $Lines | Where-Object { $_.Trim() -ne "%CURSORFOCUSLOCATION%" }
    }

    # -----------------------------------------------------------------
    # RULE: remove the PrimaryActorTick.bCanEverTick = true; line
    # -----------------------------------------------------------------
    function Remove-PrimaryActorTickLine {
        param([string[]]$Lines)

        return $Lines | Where-Object { $_.Trim() -ne "PrimaryActorTick.bCanEverTick = true;" }
    }

    # -----------------------------------------------------------------
    # RULE: remove blank line(s) sitting directly before a closing brace
    # Turns a function body like "{ \n\n }" into "{ \n }". Only removes
    # blank lines immediately before a line that is just "}" - blank
    # lines between functions are untouched.
    # -----------------------------------------------------------------
    function Remove-BlankLinesBeforeClosingBrace {
        param([string[]]$Lines)

        $result = New-Object System.Collections.Generic.List[string]

        for ($i = 0; $i -lt $Lines.Count; $i++) {
            $isBlank = ($Lines[$i].Length -eq 0)
            $nextIsClosingBrace = ($i + 1 -lt $Lines.Count -and $Lines[$i + 1].Trim() -eq "}")

            if ($isBlank -and $nextIsClosingBrace) {
                continue
            }

            $result.Add($Lines[$i])
        }

        return $result.ToArray()
    }

    # -----------------------------------------------------------------
    # RULE: merge class members into a single "protected:" section
    # Looks for the region between the GENERATED_BODY() line and the
    # first placeholder line (one starting with "%") or the closing
    # "};". Inside that region it drops every fully-empty line and
    # every "public:"/"protected:"/"private:" label, then re-inserts a
    # single "protected:" label right before the first real
    # declaration. A whitespace-only line directly after
    # GENERATED_BODY() (Unreal's own spacer line, containing just a
    # tab) is preserved as-is rather than treated as blank.
    # Does nothing if the file has no GENERATED_BODY() line (.cpp files,
    # interfaces without it, etc).
    # -----------------------------------------------------------------
    function Merge-ProtectedSection {
        param([string[]]$Lines)

        $startIndex = -1
        for ($i = 0; $i -lt $Lines.Count; $i++) {
            if ($Lines[$i] -match "GENERATED_BODY\(\)") {
                $startIndex = $i + 1
                break
            }
        }

        if ($startIndex -eq -1) {
            return $Lines
        }

        $endIndex = $Lines.Count
        for ($i = $startIndex; $i -lt $Lines.Count; $i++) {
            $trimmed = $Lines[$i].Trim()
            # Only a line that is ENTIRELY a bare placeholder (like
            # "%CLASS_FUNCTION_DECLARATIONS%") marks the end of the
            # region - a declaration that merely contains a placeholder,
            # like "%PREFIXED_CLASS_NAME%();", must not match here.
            if ($trimmed -match "^%[A-Za-z0-9_]+%$" -or $trimmed -eq "};") {
                $endIndex = $i
                break
            }
        }

        # PowerShell's ".." range operator counts DOWNWARD when the left
        # number is greater than the right one, instead of yielding an
        # empty range like most languages do. When the region is empty
        # (endIndex equals startIndex, e.g. an empty UINTERFACE shell
        # where GENERATED_BODY() is immediately followed by "};"), that
        # quirk would otherwise pull in unrelated lines - so it must be
        # special-cased here.
        if ($endIndex -gt $startIndex) {
            $region = $Lines[$startIndex..($endIndex - 1)]
        }
        else {
            $region = @()
        }

        # Blank here means Trim() -eq "" (covers both fully empty lines
        # and Unreal's whitespace/tab-only spacer line) - both get
        # dropped, since a single clean blank line is always inserted
        # fresh below instead.
        $kept = New-Object System.Collections.Generic.List[string]
        foreach ($line in $region) {
            if ($line.Trim() -eq "") { continue }
            if ($line.Trim() -in @("public:", "protected:", "private:")) { continue }
            $kept.Add($line)
        }

        $rebuilt = New-Object System.Collections.Generic.List[string]

        if ($kept.Count -gt 0) {
            # One blank line, then a single protected: label, then every
            # real declaration with no blank lines between them. If the
            # region had no real declarations at all (an empty
            # UINTERFACE shell, for example), nothing is inserted here -
            # no blank line and no protected: label.
            $rebuilt.Add("")
            $rebuilt.Add("protected:")
            foreach ($line in $kept) {
                $rebuilt.Add($line)
            }
        }

        $newLines = New-Object System.Collections.Generic.List[string]
        for ($i = 0; $i -lt $startIndex; $i++) { $newLines.Add($Lines[$i]) }
        foreach ($line in $rebuilt) { $newLines.Add($line) }
        for ($i = $endIndex; $i -lt $Lines.Count; $i++) { $newLines.Add($Lines[$i]) }

        return $newLines.ToArray()
    }

    # -----------------------------------------------------------------
    # RULE: collapse 2+ consecutive blank lines down to 1
    # Safety net applied last, in case any earlier rule leaves a double
    # blank line behind elsewhere in the file. Never removes a single
    # blank line.
    # -----------------------------------------------------------------
    function Collapse-BlankLines {
        param([string[]]$Lines)

        $result = New-Object System.Collections.Generic.List[string]
        $previousBlank = $false

        foreach ($line in $Lines) {
            $isBlank = ($line.Trim() -eq "")
            if ($isBlank -and $previousBlank) {
                continue
            }
            $result.Add($line)
            $previousBlank = $isBlank
        }

        return $result.ToArray()
    }

    # -----------------------------------------------------------------
    # RULE PIPELINE
    # Order matters: comments and placeholder lines are removed before
    # the brace/blank-line cleanup rules run, so those rules only see
    # real code. Comment out any line below to disable that rule.
    # -----------------------------------------------------------------
    function Invoke-Rules {
        param([string[]]$Lines)

        $Lines = Remove-CopyrightLine $Lines
        $Lines = Remove-PchIncludeDirective $Lines
        $Lines = Remove-Comments $Lines
        $Lines = Remove-CursorFocusLocationLine $Lines
        $Lines = Remove-PrimaryActorTickLine $Lines
        $Lines = Remove-BlankLinesBeforeClosingBrace $Lines
        $Lines = Merge-ProtectedSection $Lines
        $Lines = Collapse-BlankLines $Lines

        return $Lines
    }

    # -----------------------------------------------------------------
    # ENGINE - should not need editing just to add, remove, or reorder
    # a rule above
    # -----------------------------------------------------------------

    $ScriptDir = $PSScriptRoot
    $TargetDir = Join-Path $ScriptDir "..\CleanTemplates"

    if (-not (Test-Path -LiteralPath $TargetDir -PathType Container)) {
        Write-Host "Error: folder not found: $TargetDir"
        exit 1
    }

    $allFiles = Get-ChildItem -LiteralPath $TargetDir -Filter "*.template" -File -Recurse

    $files = $allFiles | Where-Object {
        $baseName = $_.Name -replace "\.(h|cpp)\.template$", ""
        $AllowedBaseNames -contains $baseName
    }

    if ($files.Count -eq 0) {
        Write-Host "No matching .template files found under: $TargetDir"
        exit 0
    }

    foreach ($file in $files | Sort-Object FullName) {
        $originalText = Get-Content -LiteralPath $file.FullName -Raw -Encoding UTF8
        $lines = $originalText -split "`r?`n"

        $lines = Invoke-Rules $lines

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
