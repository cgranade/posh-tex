## PoShTeX ##

PowerShell utilities for working with TeX and friends.

Currently experimental, but planned support for the following common
yet annoying TeX tasks:

- Writing installers for TeX and LaTeX packages, Pandoc templates, and LyX layouts.
- Making ZIP archives for CTAN packages and arXiv papers.

I guess that's about it? Oh, it should also be cross-platform.

Importantly, the following are ***not*** goals of PoShTeX, as they are already
handled better by other projects:

- Managing how many times to run BibTeX, LaTeX, etc.
- Editor integration.
- Reference management.
- Obtaining good parameter estimates from data in a paper draft.

### Installing ###

To install released versions of PoShTeX, simply use PowerShellGet (built in to
PowerShell for Windows 10, macOS / OS X and Linux; download
[PackageManagement](https://www.microsoft.com/en-us/download/details.aspx?id=49186)
to use PowerShellGet on Windows 7 and 8.1).

```powershell
PS> Install-Module -Name posh-tex -Scope CurrentUser
```

#### Using Without Installing ####

You can always use ``Import-Module`` directly on the included PowerShell description (``*.psd1``) to use unreleased or development versions of PoShTeX without installing them.

```powershell
PS> Import-Module src/posh-tex.psd1
```

If you make changes after importing, use ``Import-Module -Force`` to make those changes available in your PowerShell session.

#### Manual Installation ####

To manually install released or development versions of PoShTeX, we must copy the files comprising PoShTeX to a directory matching PowerShell's naming conventions.
In particular, by default, PowerShell looks for PoShTeX version 0.1.6 in the following folders:

- **Windows**: ``~\Documents\WindowsPowerShell\Modules\posh-tex\0.1.6``
- **Linux**: ``~/.local/share/powershell/Modules/posh-tex/0.1.6``
- **macOS / OS X**: TODO

Unfortunately, there's not currently an easy-to-use automated way to find the appropriate path, but for now, so modify the instructions below as needed if you have changed your ``$Env:PSModulePath`` environment variable to look somewhere other than the defaults above.

```
PS> Copy-Item -Recurse src/ ~/.local/share/powershell/Modules/posh-tex/0.1.6
```

**NB**: If the version number in your installation path does not match the version number in ``src/posh-tex.psd1``, PowerShell will silently ignore your installation when you run ``Import-Module posh-tex``.

### Using PoShTeX to Write Installers ###

The following example demonstrates how an installer
could be written for [``{revquantum}``](https://github.com/cgranade/revquantum).

```powershell
#region Bootstrap PoShTeX
if (!(Get-Module -ListAvailable -Name posh-tex -ErrorAction SilentlyContinue)) {
    Install-Module posh-tex -Scope CurrentUser
}
Import-Module posh-tex
#endregion

Out-TeXStyle revquantum
Out-TeXStyleDocumentation revquantum

Install-TeXUserResource tex/latex/revquantum revquantum.sty, revquantum.pdf

Install-PandocUserResource templates pandoc/templates/revquantum.latex -ErrorAction Continue
```

The first few lines install PoShTeX if it is not already available, and should be
included in any install script. The remaining lines specify that ``revquantum.dtx``
should be compiled into ``revquantum.sty`` using the associated ``revquantum.ins``
file, that the documentation PDF should be compiled, and that both of these
resources should be installed into the current user's TeX root. The installer
closes by attempting to also install the associated Pandoc template.

### Using PoShTeX to Specify arXiv Manifests ###

PoShTeX also allows for creating arXiv-ready ZIP files with simple manifest
scripts. Since arXiv only allows TeX projects that use folders to be uploaded as a ZIP,
this can help authors organize their manuscript projects without sacrificing arXiv
support. For instance, the following manifest might be used to produce a
ZIP file for a paper on metalearning problems.

```powershell
#region Bootstrap PoShTeX
if (!(Get-Module -ListAvailable -Name posh-tex -ErrorAction SilentlyContinue)) {
    Install-Module posh-tex -Scope CurrentUser
}
Import-Module posh-tex
#endregion

Export-ArXivArchive @{
    ProjectName = "mlp";
    TeXMain = "mlp.tex";
    AdditionalFiles = @{
        "fig/*.pdf" = $null;
        "revquantum.sty" = $null;
        "quantumarticle.cls" = $null;
    };
    Notebooks = @(
        "nb/paper-figures.ipynb"
    )
}
```

The resulting ZIP archive will contain all of the following files:

- ``mlp.tex``
- ``mlp.bbl``
- ``revquantum.sty``
- ``quantumarticle.cls``
- ``anc/paper-figures.ipynb``
- ``fig/`*.pdf``

To ensure that everything works correctly, this manifest script will also recompile the manuscript.
