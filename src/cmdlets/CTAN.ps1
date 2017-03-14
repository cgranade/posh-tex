#!/usr/bin/env powershell
##
# CTAN.ps1: Cmdlets for building CTAN-ready ZIP archives.
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
       public enum CTANArchiveLayout {
          Simple, TDS
       }
"@
} catch {}

## COMMANDS ##

function Search-TeXCommandTargets {
    [CmdletBinding()]
    param(
        [string]
        $CmdName,
        
        [Parameter(ValueFromPipeline)]
        [string]
        $Contents
    )

    begin {
        $pattern = "\\$CmdName\{([^\\\}]+)\}";
    }

    process {
        $Contents | Select-String -AllMatches -Pattern $pattern | % {
            foreach ($match in $_.Matches) {
                $match.groups[1]
                # [pscustomobject]@{Path=$match.groups[1]; TDSOnly=$true}
            }
        }
    }
}


##
# .SYNOPSIS
##
function Search-INSFile {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline=$true)]
        [string[]]
        $FileName
    )

    process {
        foreach ($name in $FileName) {
            # Write out the INS file itself.
            [pscustomobject]@{Path=$name; TDSPath=$null; TDSOnly=$false} | Write-Output;

            $contents = Get-Content $name;

            # We follow a strategy similar to that of ctanify
            # and search *.ins files for any \file commands, adding
            # them to our TDS manifest, similarly adding the
            # targets of \from commands to both the "outer" and TDS
            # archives.

            # Find \from targets.
            $contents | Search-TeXCommandTargets -CmdName file | % {
                [pscustomobject]@{Path=$_;TDSPath=$null; TDSOnly=$true}
            }
            $contents | Search-TeXCommandTargets -CmdName from | % {
                [pscustomobject]@{Path=$_; TDSPath=$null; TDSOnly=$false}
            }

        }
    }
}

function Format-TDSPath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]
        $PackageName,

        [Parameter(ValueFromPipeline=$true)]
        [PSCustomObject[]]
        $TDSManifest
    )

    begin {
        $tdsRootsByExtension = @{
            ".ins" = "source/latex/$PackageName";
            ".sty" = "tex/latex/$PackageName";
            ".pdf" = "doc/latex/$PackageName";
            ".dtx" = "source/latex/$PackageName";
        };
    }

    process {
        foreach ($tdsItem in $TDSManifest) {
            if ($tdsItem.TDSPath -eq $null) {
                $ext = [IO.Path]::GetExtension($tdsItem.Path);
                
                if ($tdsRootsByExtension.ContainsKey($ext)) {
                    $tdsItem.TDSPath = $tdsRootsByExtension[$ext];               
                }
            }
            
            $tdsItem | Write-Output;
        }
    }
}

##
# .SYNOPSIS
##
# function Export-CTANArchive {
#     [CmdletBinding()]
#     param(
#         [Parameter(Mandatory=$true)] [CTANArchiveLayout] $ArchiveLayout,
#         [Parameter(Mandatory=$true)] [hashtable] $Manifest
#     );

#     $ExpandedManifest = Expand-ArXivManifest $Manifest;

#     Invoke-TeXBuildEngine $ExpandedManifest.TeXMain;
#     if ($RunNotebooks -and $ExpandedManifest.Notebooks.Count -ge 0) {
#         $ExpandedManifest.Notebooks | Update-JupyterNotebook
#     }
    
#     $tempDir = Copy-ArXivArchive $ExpandedManifest;
    
#     # TODO: Rewrite LaTeX commands in temporary directory.

#     $archiveName = "./$($ExpandedManifest["ProjectName"]).zip"
    
#     # We make the final ZIP file using the native zip command
#     # on POSIX in lieu of
#     # https://github.com/PowerShell/Microsoft.PowerShell.Archive/issues/26.
#     if (Test-IsPOSIX) {
#         if (Get-ChildItem $archiveName -ErrorAction SilentlyContinue) {
#             Remove-Item $archiveName
#         }
#         pushd .
#         cd $tempDir
#         zip -r $archiveName .
#         popd
#         mv (Join-Path $tempDir $archiveName) .
#     } else {
#         Compress-Archive -Force -Path (Join-Path $tempDir "*") -DestinationPath $archiveName
#     }
#     Write-Host -ForegroundColor Blue "Wrote arXiv archive to $archiveName."

#     Remove-Item -Force -Recurse $tempDir;

# }

# ## EXAMPLE MANIFEST ##

# $ExampleManifest = @{
#     ProjectName = "foo";
#     TeXMain = "tex/foo.tex";
#     AdditionalFiles = @{
#         "fig/*.pdf" = $null;
#         "fig/*.png" = $null;
#         "tex/*.sty" = "/";
#         "fig/*.mp4" = "anc/";
#     };
# }
