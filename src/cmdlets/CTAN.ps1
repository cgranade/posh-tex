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

function Format-CTANManifestItem {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string] $Path,

        [string[]] $Targets = @("CTAN","TDS"),
        [string] $TDSPath = $null
    )

    [pscustomobject]@{Path=$Path; TDSPath=$TDSPath; Targets=$Targets} | Write-Output;
}

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
            Format-CTANManifestItem -Path $name -Targets CTAN, TDS

            $contents = Get-Content $name;

            # We follow a strategy similar to that of ctanify
            # and search *.ins files for any \file commands, adding
            # them to our TDS manifest, similarly adding the
            # targets of \from commands to both the "outer" and TDS
            # archives.

            # Find \from targets.
            $contents | Search-TeXCommandTargets -CmdName file | % {
                Format-CTANManifestItem -Path $_ -Targets TDS
            }
            $contents | Search-TeXCommandTargets -CmdName from | % {
                Format-CTANManifestItem -Path $_ -Targets CTAN, TDS
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
        $doc = "doc/latex/$PackageName";
        $src = "source/latex/$PackageName";
        $bin = "scripts/$PackageName";
        $tex = "tex/latex/$PackageName";

        $tdsRootsByExtension = @{
            # LaTeX Packages #
            ".sty" = $tex;

            # DocStrip Package Sources #
            ".ins" = $src;
            ".dtx" = $src;

            # Compiled and Plain-Text Documentation #
            ".pdf" = $doc;
            ".md" = $doc;

            # Scripts and Executables #
            ".ps1" = $bin;
            ".py" = $bin;
            ".sh" = $bin;
            ".pl" = $bin;
        };
    }

    process {
        foreach ($tdsItem in $TDSManifest) {
            if (!$tdsItem.TDSPath -and $tdsItem.Targets.Contains("TDS")) {
                $ext = [IO.Path]::GetExtension($tdsItem.Path);
                
                if ($tdsRootsByExtension.ContainsKey($ext)) {
                    $tdsItem.TDSPath = $tdsRootsByExtension[$ext];               
                }
            }
            
            $tdsItem | Write-Output;
        }
    }
}

function Format-CTANManifest {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true, Position=0)]
        [string] $PackageName,

        [Parameter(Mandatory=$true, Position=1, ValueFromPipeline=$true)]
        [string[]] $Path        
    )

    process {
        $Path | % {
            switch -Wildcard ($_) {
                "*[/\]Install.ps1" {
                    # We want installers to be provided only in the CTAN zip,
                    # not in the TDS folder structure.
                    Format-CTANManifestItem -Path $_ -Targets CTAN | Write-Output;
                }

                "*.ins" {
                    Search-INSFile $_ | Write-Output;
                }

                default {
                    Format-CTANManifestItem -Path $_ -Targets CTAN, TDS | Write-Output;
                }
            }
        } | Format-TDSPath -PackageName $PackageName | Write-Output
    }

}

##
# .SYNOPSIS
##
function Export-CTANArchive {
    # [CmdletBinding()]
    param(
        [string] $PackageName,

        [Parameter(Mandatory=$true)]
        [CTANArchiveLayout] $ArchiveLayout,
        
        [Parameter(Position=0, Mandatory=$true,ValueFromPipeline=$true)]
        [string[]] $Path
    );    

    begin {
        # Check if $PackageName is defined, and if not,
        # default to the base name of the first path argument.
        if (!$PackageName) {
            $PackageName = [IO.Path]::GetFileNameWithoutExtension($Path[0]);
        }
    }

    process {
        # Actually build the manifest.
        $Manifest = $Path | Format-CTANManifest -PackageName $PackageName;
    }

    end {
        # If the $ArchiveLayout parameter tells us we need to include
        # a *.tds.zip, then we write that now.
        if ($ArchiveLayout -eq [CTANArchiveLayout]::TDS) {
            $tdsZipName = "$PackageName.tds.zip";

            # Pack up the TDS ZIP.
            $Manifest | ? {$_.Targets.Contains("TDS")} | % {
                @{Src=$_.Path; Dest=Join-Path $_.TDSPath ([IO.Path]::GetFileName($_.Path))}
            } | Compress-ArchiveWithSubfolders -ArchivePath $tdsZipName;

            $Manifest = $Manifest + @((Format-CTANManifestItem -Path $tdsZipName -Targets CTAN));
        }

        $ctanZipName = "$PackageName.zip";

        # Finally, write the CTAN zip itself.
        $Manifest | ? {$_.Targets.Contains("CTAN")} | % {
            @{Src=$_.Path; Dest=Join-Path $PackageName ([IO.Path]::GetFileName($_.Path))}
        } | Compress-ArchiveWithSubfolders -ArchivePath $ctanZipName;
        
    }

}
