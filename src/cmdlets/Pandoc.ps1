#!/usr/bin/env powershell

## COMMANDS ##

##
# .SYNOPSIS
#     Finds the user data directory for Pandoc if it is installed.
##
function Get-PandocUserDir {
    [CmdletBinding()]
    param(
    );

    if (!(Get-Command pandoc -ErrorAction SilentlyContinue)) {
        return $null;
    }

    $pandocVersionReport = pandoc -v;

    foreach ($reportLine in $pandocVersionReport.Split([environment]::NewLine)) {
        if ($reportLine.Contains("Default user data directory:")) {
            # The [int] here is a workaround for a bug in PowerShell 6.0.0-alpha.
            $description, $value = $reportLine.Split(":", [int]2);
            return $value.Trim();            
        }
    }
}

##
# .SYNOPSIS
#
##
function Install-PandocUserResource {
    [CmdletBinding(
        SupportsShouldProcess=$true,
        ConfirmImpact='Medium'
    )]
    param(
        [string] $PandocPath = "",
        [string[]] $ResourcePath,
        [string] $PandocUserDir = $null
    );

    if (!($PandocUserDir)) {
        $PandocUserDir = Get-PandocUserDir;
    }

    (
        Install-Resources `
            -PathAtDestination $PandocPath `
            -ResourcePath $ResourcePath `
            -DestinationRoot $PandocUserDir `
            -Prompt "Install Pandoc user resource?" `
    )

}