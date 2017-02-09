#!/usr/bin/env powershell

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
