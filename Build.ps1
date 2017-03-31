#region Bootstrap playPS
if (!(Get-Module -ListAvailable platyPS)) {
    Install-Module -Scope CurrentUser platyPS
}
#endregion

Import-Module platyPS
New-ExternalHelp -Force .\docs\cmdlets -OutputPath .\src\en-US

mkdocs build
