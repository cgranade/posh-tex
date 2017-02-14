#!/usr/bin/env powershell
##
# Core.ps1: Cmdlets common across PoShTeX.
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

## FUNCTIONS ##

function set-extension {
    param(
        [Parameter(Mandatory=$true)] [string] $path,
        [Parameter(Mandatory=$true)] [string] $newExtension
    );

    return [System.IO.Path]::ChangeExtension($path, $newExtension);
}

function get-extension {
    param(
        [Parameter(Mandatory=$true)] [string] $path
    )

    return [System.IO.Path]::GetExtension($path);
}


function Test-IsPOSIX {
    if (!(Get-Command uname -ErrorAction SilentlyContinue)) {
        return $false;
    }

    $uname = uname;
    if ($uname.Trim() -eq "Linux" -or $uname.Trim() -eq "Darwin") {
        return $true;
    }

    return $false;
}

function Test-CommandExists {
    param([string] $Name);

    if (Get-Command -Name $Name -ErrorAction SilentlyContinue) {
        return $true;
    } else {
        return $false;
    }
}

## COMMANDS ##

function Install-Resources {
    [CmdletBinding(
        SupportsShouldProcess=$true,
        ConfirmImpact='Medium'
    )]
    param(
        [string] $PathAtDestination,
        [string[]] $ResourcePath,
        [string] $DestinationRoot,
        [string] $Prompt = "Install resources?"
    )

    $dest = Join-Path -Path $DestinationRoot -ChildPath $PathAtDestination;

    if ($PSCmdlet.ShouldProcess($dest, $Prompt)) {

        # First make sure the destination path exists.
        New-Item -ItemType Directory -Path $dest -ErrorAction Ignore;

        # Next, copy the files into the target directory.
        foreach ($resource in $ResourcePath) {
            Copy-Item -Path $resource -Destination $dest;
        }

    } elseif ($WhatIfPreference.IsPresent) {
        Write-Host ("Would create directory at {0}." -f $dest);
        foreach ($resource in $ResourcePath) {
            Write-Host ("Would install {0} to {1}." -f $resource, $dest);
        }
    }

}
