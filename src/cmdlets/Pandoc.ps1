#!/usr/bin/env powershell
##
# Pandoc.ps1: Cmdlets for interacting with Pandoc installations.
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