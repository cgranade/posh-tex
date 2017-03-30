#!/usr/bin/env powershell
##
# TeX.ps1: Cmdlets for interacting with MiKTeX, TeX Live, etc.
##
# © 2017 Christopher Granade (cgranade@cgranade.com)
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are
# met:
#
# 1. Redistributions of source code must retain the above copyright notice,
#    this list of conditions and the following disclaimer.
#
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
#
# 3. Neither the name of PoShTeX nor the names
#    of its contributors may be used to endorse or promote products derived
#    from this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
# "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
# LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A
# PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
# HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
# SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
# LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
# DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
# THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
##

## ENUMS ##

try {
    Add-Type -TypeDefinition @"
       public enum TeXDistributions {
          MiKTeX, TeXLive, Other, None
       }
"@
} catch {}

## COMMANDS ##

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
                    # The [int] here is a workaround for a bug in PowerShell 6.0.0-alpha:
                    # https://github.com/PowerShell/PowerShell/issues/3137
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

    Invoke-TeXBuildEngine $dtxName;

}


function Invoke-TeXBuildEngine {
    # TODO: needs to switch PDF/DVI.
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)] [string]
        $Name,

        [System.Nullable``1[[TeXDistributions]]]
        $TeXDist = $null
    )

    if (!($TeXDist)) {
        $TeXDist = Get-TeXDistribution;
    }

    switch ($TeXDist) {
        "MiKTeX" {
            $preferredCommand = "texify";
            $args = "--pdf";
        }

        "TeXLive" {
            $preferredCommand = "latexmk";
            $args = "-pdf";
        }

        default {
            $preferredCommand = $null;
            $args = "";
        }
    }
    
    if ($preferredCommand -and (Get-Command $preferredCommand -ErrorAction SilentlyContinue)) {
        Write-Host -ForegroundColor Blue "Building $Name using $preferredCommand..."
        & "$preferredCommand" $args $Name
    } else {
        Write-Host -ForegroundColor Blue "Building $Name manually using pdflatex and bibtex..."
        pdflatex $Name
        pdflatex $Name
        bibtex $Name
        pdflatex $Name
    }

}