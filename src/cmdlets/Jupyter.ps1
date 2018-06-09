#!/usr/bin/env powershell
##
# Jupyter.ps1: Cmdlets for working with Jupyter notebooks.
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

function Invoke-Python {
    [CmdletBinding()]
    param(
        [string] $Source,
        [hashtable] $Variables = @{},
        [hashtable] $Import = @{}
    );

    $headerLines = @(
        # Set the encoding to match what we'll specify when we
        # call Out-File below.
        "# -*- coding: utf-8 -*-",
        # Future proof to make this cmdlet more 2/3 agnostic.
        "from __future__ import division, print_function"
    )

    # Possibly handle additional variables.
    if ($Variables.Count) {
        # We'll pass variables as JSON.
        $headerLines += "from json import loads"

        foreach ($item in $Variables.GetEnumerator()) {
            $jsonPayload = ($item | ConvertTo-Json);
            $headerLines += "$($item.Name) = loads(r`'`'`'$jsonPayload`'`'`')['Value']"
        }
        
        # Remove the side effect of having imported json.loads.
        $headerLines += "del loads"
    }
    
    # Possibly import additional modules.
    if ($Import.Count) {
        foreach ($item in $Import.GetEnumerator()) {
            if ($item.Value -eq $null) {
                $headerLines += "import $($item.Name)"
            } else {
                $headerLines += "import $($item.Name) as $($item.Value)"
            }
        }
    }

    if ($DebugPreference) {
        Write-Host ([System.String]::Join("`n", $headerLines));
    }

    $tempFile = [System.IO.Path]::GetTempFileName();
    ($headerLines + $Source) | Out-File -FilePath $tempFile -Encoding utf8;

    python $tempFile | Write-Output;

    Remove-Item $tempFile | Out-Null;

}

function Update-JupyterNotebook {
    [CmdletBinding()]
    param(
        [Parameter(
            Position=0,
            Mandatory=$true,
            ValueFromPipeline=$true
        )]
        [string[]]
        $Path,

        $NotebookKernel = $null
    )

    begin {
        $script = @"
from nbconvert.preprocessors import ExecutePreprocessor

try:
    import nb_conda_kernels

    # Now monkey patch the conda KernelSpecManager into
    # jupyter_client into jupyter_client.kernelspec, as used by
    # jupyter_client.manager, as used in turn by nbconvert.
    import jupyter_client.kernelspec
    jupyter_client.kernelspec.KernelSpecManager = nb_conda_kernels.CondaKernelSpecManager
    print("Successfully loaded Anaconda extensions.")
except ImportError as ex:
    print(ex)

if notebook_kernel:
    ep = ExecutePreprocessor(kernel_name=notebook_kernel)
else:
    ep = ExecutePreprocessor()

with open(notebook_path, 'r', encoding='utf-8') as notebook_file:
    nb = nbformat.read(notebook_file, as_version=4)

ep.preprocess(nb, {'metadata': {
    'path': os.path.split(notebook_path)[0]
}})

with open(notebook_path, 'w') as notebook_file:
    nbformat.write(nb, notebook_file)
"@
    }

    process {
        foreach ($notebookPath in $Path) {
            Invoke-Python -Import @{
                "sys" = $null; "os" = $null;
                "nbformat" = $null;
            } -Variables @{
                notebook_kernel = $NotebookKernel;
                notebook_path = $notebookPath;
            } -Source $script
        }
    }
}
