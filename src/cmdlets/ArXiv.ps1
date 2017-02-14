#!/usr/bin/env powershell
##
# ArXiv.ps1: Cmdlets for building arXix-ready ZIP archives.
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
##
function Expand-ArXivManifest {
    # [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)] [hashtable] $Manifest
    );

    # Begin by making a new hashtable to accumulate build files.
    # Each entry in the hashtable will identify a particular file
    # and its destination within the eventual ZIP file.
    $buildFiles = @{};

    # Put the TeXMain file in the root by isolating its basename
    # (that is, without the path) and making that the destination
    # for the actual file pointed to by TeXMain.
    $texMain = $Manifest["TeXMain"];
    $texMainLocation = Split-Path $texMain;
    if ($texMainLocation.Length -eq 0) {
        $texMainLocation = ".";
    }
    $texMainBase = Split-Path $texMain -Leaf;
    $buildFiles[($texMain | Resolve-Path)] = Join-Path "." $texMainBase;
    
    # Next, add the BBL.
    $bblBase = set-extension -Path $texMainBase -newExtension "bbl";
    $buildFiles[(
        Join-Path -Path $texMainLocation -ChildPath $bblBase | Resolve-Path
    )] = Join-Path "." $bblBase;

    # Next, loop through the AdditionalFiles and add each to
    # the build files accordingly.
    $Manifest["AdditionalFiles"].GetEnumerator() | % {
        $glob = $_.Key;
        $targetDir = $_.Value;

        if (!($targetDir)) {
            # Check if the target is left implicit. If so, resolve
            # the glob and add each.
            Resolve-Path $glob -Relative | % {
                $buildFiles[(Resolve-Path $_)] = $_;
            } | Out-Null
        } elseif ($targetDir.EndsWith("/") -or $targetDir.EndsWith("\")) {
            # Next, check if the target is a directory. If so, each
            # item matching the glob gets added to the same directory.
            Resolve-Path $glob -Relative | % {
                $buildFiles[(Resolve-Path $_)] = (Join-Path $targetDir -ChildPath (Split-Path $_ -Leaf));
            } | Out-Null
        } else { 
            # If we're here, then the target was an explicit name, so we
            # don't need to glob it up.
            $buildFiles[$glob] = $targetDir;
        }
    } | Out-Null

    # Add any Notebooks to anc/. We'll possibly rerun them in a later build
    # stage.
    $Manifest["Notebooks"] | % {
        $buildFiles[(Resolve-Path $_)] = Join-Path "./anc" (Split-Path -Leaf $_)
    } | Out-Null

    # Finish by attaching the hashtable of build files to the manifest
    # and returning it.
    $expandedManifest = $Manifest.Clone();
    $expandedManifest["BuildFiles"] = $buildFiles;
    
    $expandedManifest

}

function Copy-ArXivArchive {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)] [hashtable]
        $ExpandedManifest
    )

    $tempDirName = [System.IO.Path]::GetTempFileName();
    Remove-Item $tempDirName;
    New-Item -ItemType Directory -Path $tempDirName | Out-Null;

    Write-Host -ForegroundColor Blue "Copying arXiv build files to $tempDirName."

    $ExpandedManifest["BuildFiles"].GetEnumerator() | % {
        
        $target = Join-Path $tempDirName $_.Value;
        $targetDir = Split-Path $target;

        # Make the target directory if it doesn't exist.
        if (!(Get-Item $targetDir -ErrorAction SilentlyContinue)) {
            New-Item -ItemType Directory $targetDir
        }
        write-host "Copying $($_.Key) -> $target"
        Copy-Item $_.Key $target

    } | Out-Null;

    $tempDirName

}

##
# .SYNOPSIS
##
function Export-ArXivArchive {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)] [hashtable] $Manifest,
        [switch] $RunNotebooks
    );

    $ExpandedManifest = Expand-ArXivManifest $Manifest;

    Invoke-TeXBuildEngine $ExpandedManifest.TeXMain;
    if ($RunNotebooks -and $ExpandedManifest.Notebooks.Count -ge 0) {
        $ExpandedManifest.Notebooks | Update-JupyterNotebook
    }
    
    $tempDir = Copy-ArXivArchive $ExpandedManifest;
    
    # TODO: Rewrite LaTeX commands in temporary directory.

    $archiveName = "./$($ExpandedManifest["ProjectName"]).zip"
    
    # We make the final ZIP file using the native zip command
    # on POSIX in lieu of
    # https://github.com/PowerShell/Microsoft.PowerShell.Archive/issues/26.
    if (Test-IsPOSIX) {
        if (Get-ChildItem $archiveName -ErrorAction SilentlyContinue) {
            Remove-Item $archiveName
        }
        pushd .
        cd $tempDir
        zip -r $archiveName .
        popd
        mv (Join-Path $tempDir $archiveName) .
    } else {
        Compress-Archive -Force -Path (Join-Path $tempDir "*") -DestinationPath $archiveName
    }
    Write-Host -ForegroundColor Blue "Wrote arXiv archive to $archiveName."

    Remove-Item -Force -Recurse $tempDir;

}

## EXAMPLE MANIFEST ##

$ExampleManifest = @{
    ProjectName = "foo";
    TeXMain = "tex/foo.tex";
    AdditionalFiles = @{
        "fig/*.pdf" = $null;
        "fig/*.png" = $null;
        "tex/*.sty" = "/";
        "fig/*.mp4" = "anc/";
    };
}
