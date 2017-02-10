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

We'll have instructions at some point for how to install development
(unreleased) versions.

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

**TODO**


