#!/usr/bin/env powershell

## ENUMS ##

try {
    Add-Type -TypeDefinition @"
       public enum TeXDistributions {
          MiKTeX, TeXLive, Other, None
       }
"@
} catch {}

## COMMANDS ##

##
# .SYNOPSIS
#     Detects which TeX distribution is installed by running
#     "tex" and checking the reported version.
##
function Get-TeXDistribution {
    [CmdletBinding()]
    param(
    );

    if (Get-Command tex -ErrorAction SilentlyContinue) {

        $versionOutput = tex --version;
        $versionHeader =  $versionOutput.Split([environment]::NewLine)[0];

        if ($versionHeader.Contains("MiKTeX")) {
            return [TeXDistributions]::MiKTeX;
        } elseif ($versionHeader.Contains("TeX Live")) {
            return [TeXDistributions]::TeXLive;
        } else {
            return [TeXDistributions]::Other;
        }

    } else {
        return [TeXDistributions]::None;
    }

}

##
# .SYNOPSIS
#     Returns the default user directory for the current TeX
#     distribution.
##
function Get-TeXUserDir {
    [CmdletBinding()]
    param(
        [System.Nullable``1[[TeXDistributions]]] $TeXDist = $null
    )

    if (!($TeXDist)) {
        $TeXDist = Get-TeXDistribution;
    }

    switch ($TeXDist) {
        "MiKTeX" {
            $MiKTeXReport = initexmf --report;

            foreach ($reportLine in $MiKTeXReport.Split([environment]::NewLine)) {
                if ($reportLine.Contains(":")) {
                    # The [int] here is a workaround for a bug in PowerShell 6.0.0-alpha.
                    $key, $value = $reportLine.Split(":", [int]2);
                    if ($key.ToLower().Trim() -eq "userinstall") {
                        return $value.Trim();
                    }
                }
            }

            throw [System.IO.FileNotFoundException] "No MiKTeX user install directory found.";
        }

        "TeXLive" {
            return kpsewhich --expand-var='$TEXMFHOME';
        }

        "Other" {
            # Make a resonable guess if we can't figure out otherwise.
            return Resolve-Path "~/texmf";
        }
    }

}

##
# .SYNOPSIS
#     Refreshes the TeX hash to reflect newly installed resources.
##
function Update-TeXHash {
    [CmdletBinding()]
    param(
        [System.Nullable``1[[TeXDistributions]]] $TeXDist = $null
    )

    if (!($TeXDist)) {
        $TeXDist = Get-TeXDistribution;
    }

    switch ($TeXDist) {
        "MiKTeX" {
            initexmf --update-fndb
        }

        "TeXLive" {
            texhash
        }

        "Other" {
            texhash
        }
    }
}

##
# .SYNOPSIS
#     Installs a given TeX resource into the current
#     distribution's user directory.
##
function Install-TeXUserResource {
    [CmdletBinding(
        SupportsShouldProcess=$true,
        ConfirmImpact='Medium'
    )]
    param(
        [string] $TDSPath,
        [string[]] $ResourcePath,
        [string] $TeXUserDir = $null
    )

    if (!($TeXUserDir)) {
        $TeXUserDir = Get-TeXUserDir;
    }

    (
        Install-Resources `
            -PathAtDestination $TDSPath `
            -ResourcePath $ResourcePath `
            -DestinationRoot $TeXUserDir `
            -Prompt "Install TeX user resource?" `
    )

    Update-TeXHash

}


##
# .SYNOPSIS
#     
##
function Out-TeXStyle {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)] [string] $StyleName
    );

    if (get-extension $StyleName) {
        $insName = set-extension $StyleName "ins";
    } else {
        $insName = "$StyleName.ins";
    }

    if (!(Get-Item $insName -ErrorAction SilentlyContinue)) {
        Write-Error -Message "INS file $insName not found." -Category ObjectNotFound
    }

    latex $insName;

}

function Out-TeXStyleDocumentation {
    # FIXME: copypasta with previous cmdlet.
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)] [string] $StyleName
    );

    if (get-extension $StyleName) {
        $dtxName = set-extension $StyleName "dtx";
    } else {
        $dtxName = "$StyleName.dtx";
    }

    if (!(Get-Item $dtxName -ErrorAction SilentlyContinue)) {
        Write-Error -Message "DocStrip file $dtxName not found." -Category ObjectNotFound
    }

    # FIXME: check for proper PDF LaTeX build system (texify, latexmk, etc.).
    pdflatex $dtxName;
}
